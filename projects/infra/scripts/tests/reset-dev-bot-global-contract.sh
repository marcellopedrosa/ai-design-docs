#!/usr/bin/env bash

test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
fixture="$test_root/project"
fake_bin="$test_root/bin"
log="$test_root/docker.log"
output="$test_root/output.log"
mkdir -p "$fixture/infra/scripts/lib" "$fake_bin" "$fixture/.dev-secrets"
cp "$REPOSITORY_ROOT/reset-dev-bot.sh" "$fixture/reset-dev-bot.sh"
cp "$REPOSITORY_ROOT/infra/scripts/lib/development-docker-access.sh" \
    "$fixture/infra/scripts/lib/development-docker-access.sh"
chmod 700 "$fixture/reset-dev-bot.sh"
printf 'synthetic-local-config\n' > "$fixture/.env"
printf 'synthetic-local-secret\n' > "$fixture/.dev-secrets/sentinel"
printf '#!/usr/bin/env bash\nprintf "start invoked\\n" >> "$FAKE_DOCKER_LOG"\n' \
    > "$fixture/start-dev-bot.sh"
chmod 700 "$fixture/start-dev-bot.sh"

cat > "$fake_bin/docker" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
case "$1 $2" in
    'context inspect') printf '%s\n' "${FAKE_ENDPOINT:-unix:///var/run/docker.sock}" ;;
    'info '|'compose version') exit "${FAKE_PREFLIGHT_EXIT:-0}" ;;
    'ps -aq') printf 'container-a\ncontainer-b\n' ;;
    'image ls') printf 'image-a\nimage-b\n' ;;
    'rm -f') exit "${FAKE_RM_EXIT:-0}" ;;
    'rmi image-a') exit "${FAKE_RMI_EXIT:-0}" ;;
    'system prune') exit "${FAKE_SYSTEM_EXIT:-0}" ;;
    'volume prune') exit "${FAKE_VOLUME_EXIT:-0}" ;;
esac
MOCK
chmod 700 "$fake_bin/docker"
export PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$log"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_no_mutation() {
    if grep -Eq '^(rm -f|rmi |system prune|volume prune|start invoked)' "$log"; then
        fail "$1"
    fi
}
run_pty() {
    local confirmation="$1"
    printf '%s\n' "$confirmation" | SHELL=/bin/bash script --quiet --return \
        --command "$fixture/reset-dev-bot.sh" /dev/null > "$output" 2>&1
}

: > "$log"
if DOCKER_HOST=tcp://remote.example.invalid:2376 "$fixture/reset-dev-bot.sh" \
    > "$output" 2>&1; then
    fail 'remote DOCKER_HOST was accepted'
fi
[[ ! -s "$log" ]] || fail 'remote DOCKER_HOST reached Docker'

: > "$log"
if DOCKER_HOST=unix:///tmp/other.sock "$fixture/reset-dev-bot.sh" \
    > "$output" 2>&1; then
    fail 'noncanonical local socket was accepted'
fi
[[ ! -s "$log" ]] || fail 'noncanonical socket reached Docker'

: > "$log"
if FAKE_ENDPOINT=ssh://remote.example.invalid "$fixture/reset-dev-bot.sh" \
    > "$output" 2>&1; then
    fail 'remote Docker context was accepted'
fi
assert_no_mutation 'remote Docker context mutated resources'

: > "$log"
if FAKE_PREFLIGHT_EXIT=1 "$fixture/reset-dev-bot.sh" > "$output" 2>&1; then
    fail 'unavailable direct Docker access was accepted'
fi
assert_no_mutation 'failed Docker preflight mutated resources'

: > "$log"
if CONFIRM_RESET_DEV_BOT=DELETE "$fixture/reset-dev-bot.sh" \
    < /dev/null > "$output" 2>&1; then
    fail 'environment confirmation or nonterminal input was accepted'
fi
assert_no_mutation 'unconfirmed reset mutated resources'

: > "$log"
if run_pty ERRADO; then
    fail 'incorrect interactive confirmation was accepted'
fi
assert_no_mutation 'incorrect confirmation mutated resources'

: > "$log"
run_pty LIMPAR || fail 'literal confirmation failed'
grep -Fq 'afeta todo o Docker' "$output" || fail 'global warning is absent'
grep -Fq 'não apenas o projeto' "$output" || fail 'cross-project warning is absent'
expected="$test_root/expected.log"
cat > "$expected" <<'EXPECTED'
context inspect --format {{.Endpoints.docker.Host}}
info
compose version
context inspect --format {{.Endpoints.docker.Host}}
ps -aq
rm -f container-a container-b
image ls -q
rmi image-a image-b
system prune -a -f
volume prune -a -f
EXPECTED
cmp -s "$expected" "$log" || fail 'global cleanup order or scope changed'
cmp -s <(printf 'synthetic-local-config\n') "$fixture/.env" \
    || fail 'local env was changed'
cmp -s <(printf 'synthetic-local-secret\n') "$fixture/.dev-secrets/sentinel" \
    || fail 'local secret fixture was changed'

: > "$log"
if FAKE_RM_EXIT=44 run_pty LIMPAR; then
    fail 'container removal failure was hidden'
fi
grep -Fq 'rm -f container-a container-b' "$log" \
    || fail 'container removal was not attempted'
if grep -Eq '^(rmi |system prune|volume prune)' "$log"; then
    fail 'cleanup continued after container removal failed'
fi

: > "$log"
FAKE_RMI_EXIT=45 run_pty LIMPAR || fail 'image removal warning stopped prune'
grep -Fq 'algumas imagens não foram removidas' "$output" \
    || fail 'image removal warning is absent'
grep -Fq 'volume prune -a -f' "$log" \
    || fail 'volume prune was skipped after image warning'

: > "$log"
if FAKE_SYSTEM_EXIT=46 run_pty LIMPAR; then
    fail 'system prune failure was hidden'
fi
if grep -Fq 'volume prune -a -f' "$log"; then
    fail 'volume prune ran after system prune failed'
fi

: > "$log"
if FAKE_VOLUME_EXIT=47 run_pty LIMPAR; then
    fail 'volume prune failure was hidden'
fi

printf 'PASS: global Docker reset is local-only, confirmed, ordered and hermetic\n'
