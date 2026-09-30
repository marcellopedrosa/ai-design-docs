// Deliberately small YAML subset for the V6 manifest and registries. Unsupported
// syntax fails closed instead of being silently reinterpreted.
export function parseYamlSubset(source, label = '<yaml>') {
  const lines = source.split(/\r?\n/).map((raw, index) => ({ raw, number: index + 1 }))
    .filter(({ raw }) => raw.trim() && !raw.trim().startsWith('#'));
  if (lines.length === 0) throw new Error(`${label}: empty YAML`);
  const root = {};
  const stack = [{ indent: -1, value: root }];
  const scalar = (text, line) => {
    if (text === '[]') return [];
    if (text === '{}') return {};
    if (text === 'true') return true;
    if (text === 'false') return false;
    if (/^-?\d+$/.test(text)) return Number(text);
    if (text.startsWith('"')) {
      try { return JSON.parse(text); } catch { throw new Error(`${label}:${line}: invalid quoted scalar`); }
    }
    if (text.startsWith("'")) {
      if (!text.endsWith("'") || text.length < 2) throw new Error(`${label}:${line}: invalid quoted scalar`);
      return text.slice(1, -1).replaceAll("''", "'");
    }
    if (/^(?:[\[\]{},&*!|>]|<<:)/.test(text) || /\s#/.test(text)) {
      throw new Error(`${label}:${line}: unsupported YAML scalar`);
    }
    return text;
  };
  const put = (obj, key, rawValue, current, next) => {
    if (!/^[A-Za-z][A-Za-z0-9_-]*$/.test(key)) throw new Error(`${label}:${current.number}: invalid key ${key}`);
    if (Object.hasOwn(obj, key)) throw new Error(`${label}:${current.number}: duplicate key ${key}`);
    if (rawValue) {
      obj[key] = scalar(rawValue, current.number);
    } else {
      if (!next || next.indent <= current.indent) throw new Error(`${label}:${current.number}: empty value for ${key}`);
      obj[key] = next.text.startsWith('- ') ? [] : {};
      stack.push({ indent: current.indent, value: obj[key] });
    }
  };
  const prepared = lines.map(({ raw, number }) => {
    if (raw.includes('\t')) throw new Error(`${label}:${number}: tabs not supported`);
    const indent = raw.length - raw.trimStart().length;
    if (indent % 2) throw new Error(`${label}:${number}: indentation must use two spaces`);
    return { indent, text: raw.trim(), number };
  });
  for (let i = 0; i < prepared.length; i++) {
    const current = prepared[i];
    while (stack.length > 1 && current.indent <= stack.at(-1).indent) stack.pop();
    const parent = stack.at(-1).value;
    const next = prepared[i + 1];
    if (current.text.startsWith('- ')) {
      if (!Array.isArray(parent)) throw new Error(`${label}:${current.number}: list item outside array`);
      const body = current.text.slice(2).trim();
      const pair = body.match(/^([A-Za-z][A-Za-z0-9_-]*):(?:\s+(.*))?$/);
      if (pair) {
        const obj = {};
        parent.push(obj);
        stack.push({ indent: current.indent, value: obj });
        put(obj, pair[1], pair[2] ?? '', { ...current, indent: current.indent + 2 }, next);
      } else {
        parent.push(scalar(body, current.number));
      }
      continue;
    }
    if (Array.isArray(parent)) throw new Error(`${label}:${current.number}: mapping item outside object`);
    const pair = current.text.match(/^([A-Za-z][A-Za-z0-9_-]*):(?:\s+(.*))?$/);
    if (!pair) throw new Error(`${label}:${current.number}: unsupported YAML syntax`);
    put(parent, pair[1], pair[2] ?? '', current, next);
  }
  return root;
}
