#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/home/.local/state/omarchy"
export CALL_LOG="$test_dir/calls"

cat >"$test_dir/bin/dnf" <<'SH'
#!/bin/bash
printf 'dnf %s\n' "$*" >>"$CALL_LOG"
if [[ $1 == "-q" && $2 == "repolist" ]]; then
  echo 'repo id repo name'
  if [[ ${OMADORA_TEST_REPO_ENABLED:-0} == 1 ]]; then
    echo 'copr:copr.fedorainfracloud.org:kammer:omadora Copr repo for Omadora'
  fi
fi
SH

cat >"$test_dir/bin/sudo" <<'SH'
#!/bin/bash
printf 'sudo %s\n' "$*" >>"$CALL_LOG"
exit "${OMADORA_TEST_ENABLE_STATUS:-0}"
SH

cat >"$test_dir/bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
printf 'pkg %s\n' "$*" >>"$CALL_LOG"
SH

chmod +x "$test_dir/bin/"*

run_migration() {
  : >"$CALL_LOG"
  env HOME="$test_dir/home" OMARCHY_PATH="$ROOT" PATH="$test_dir/bin:$PATH" "$@" \
    bash -euo pipefail "$ROOT/migrations/1790599223.sh" >"$test_dir/output" 2>&1
}

run_migration
grep -qxF 'sudo dnf copr enable -y kammer/omadora' "$CALL_LOG" || fail "migration enables Omadora COPR"
grep -qxF 'pkg aether owe owe-lockfeed tobi-try ttfx' "$CALL_LOG" || fail "migration installs packaged base tools"
grep -qxF 'pkg hype monologue omacalc omacut omawrite' "$CALL_LOG" || fail "migration installs packaged apps for current preinstalls"
pass "migration enables the repository and installs the new base tools"

run_migration OMADORA_TEST_REPO_ENABLED=1
! grep -q '^sudo ' "$CALL_LOG" || fail "migration re-enables an enabled repository"
pass "migration leaves an enabled repository alone"

touch "$test_dir/home/.local/state/omarchy/preinstalls-removed"
run_migration OMADORA_TEST_REPO_ENABLED=1
! grep -qxF 'pkg hype monologue omacalc omacut omawrite' "$CALL_LOG" || fail "migration reinstalls removed preinstalled apps"
pass "migration respects removed preinstalls"

if run_migration OMADORA_TEST_ENABLE_STATUS=1; then
  fail "migration continues after repository enable fails"
fi
! grep -q '^pkg ' "$CALL_LOG" || fail "migration installs packages without its repository"
pass "repository failure keeps the migration pending"
