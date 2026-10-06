import fs from 'node:fs';
import path from 'node:path';

const [collection, type] = process.argv.slice(2);
if (!collection || !type) {
  console.error('Usage: node scripts/next-id.mjs <collection> <TYPE>');
  process.exit(2);
}

const absolute = path.resolve(collection);
if (absolute.split(path.sep).includes('specs')) {
  console.error('BLOCKED: document sequencing never applies inside docs/specs.');
  process.exit(3);
}
if (!fs.existsSync(absolute) || !fs.statSync(absolute).isDirectory()) {
  console.error(`Not a directory: ${absolute}`);
  process.exit(2);
}

const pattern = new RegExp(`^${type}-([0-9]{5})-[^/]+\\.md$`);
const numbers = fs.readdirSync(absolute).flatMap((name) => {
  const match = name.match(pattern);
  return match ? [Number(match[1])] : [];
});
const next = numbers.length ? Math.max(...numbers) + 1 : 1;
console.log(`${type}-${String(next).padStart(5, '0')}`);
