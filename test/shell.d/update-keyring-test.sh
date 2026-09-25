#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
log_file="$test_tmp/keyring.log"
mkdir -p "$stub_bin"

# Behavior is driven by env vars so each case can pick its failure point:
# KEYRING_TEST_INSTALL_STATUS  exit status of the fedora-gpg-keys install (default 0)
# KEYRING_TEST_RPM_Q_STATUS    exit status of rpm -q fedora-gpg-keys (default 0)
# KEYRING_TEST_NO_PUBKEY       when set, rpm -qa lists no gpg-pubkey entries
cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash

printf 'sudo' >>"$KEYRING_TEST_LOG"
for arg in "$@"; do
  printf '\t%s' "$arg" >>"$KEYRING_TEST_LOG"
done
printf '\n' >>"$KEYRING_TEST_LOG"

if [[ $1 == "dnf" ]]; then
  exit "${KEYRING_TEST_INSTALL_STATUS:-0}"
fi

exit 0
SH
chmod +x "$stub_bin/sudo"

cat >"$stub_bin/rpm" <<'SH'
#!/bin/bash

if [[ $1 == "-q" ]]; then
  exit "${KEYRING_TEST_RPM_Q_STATUS:-0}"
fi

if [[ $1 == "-qa" ]]; then
  if [[ -z ${KEYRING_TEST_NO_PUBKEY:-} ]]; then
    printf 'gpg-pubkey 38ab71f4\n'
  fi
  exit 0
fi

echo "Unexpected rpm call: $*" >&2
exit 99
SH
chmod +x "$stub_bin/rpm"

run_keyring() {
  KEYRING_TEST_LOG="$log_file" \
    PATH="$stub_bin:$PATH" \
    "$ROOT/bin/omarchy-update-keyring" "$@"
}

# Everything healthy: the install works and the keys verify.
: >"$log_file"
run_keyring >"$test_tmp/ok.out"

grep -F "Keys are correct" "$test_tmp/ok.out" >/dev/null ||
  fail "update-keyring reports success when the keyring is healthy" "$(cat "$test_tmp/ok.out")"
pass "update-keyring reports success when the keyring is healthy"

grep -Eq $'^sudo\tdnf\tinstall\t-y\tfedora-gpg-keys$' "$log_file" ||
  fail "update-keyring still reinstalls fedora-gpg-keys" "$(cat "$log_file")"
pass "update-keyring still reinstalls fedora-gpg-keys"

# A failed install must stop the script, not end in "Keys are correct".
: >"$log_file"
if KEYRING_TEST_INSTALL_STATUS=1 run_keyring >"$test_tmp/install.out" 2>&1; then
  fail "update-keyring fails when the key install fails"
fi
if grep -F "Keys are correct" "$test_tmp/install.out" >/dev/null; then
  fail "update-keyring fails when the key install fails" "$(cat "$test_tmp/install.out")"
fi
pass "update-keyring fails when the key install fails"

# A missing fedora-gpg-keys package must not end in success either.
: >"$log_file"
if KEYRING_TEST_RPM_Q_STATUS=1 run_keyring >"$test_tmp/verify.out" 2>&1; then
  fail "update-keyring fails when the key package check fails"
fi
if grep -F "Keys are correct" "$test_tmp/verify.out" >/dev/null; then
  fail "update-keyring fails when the key package check fails" "$(cat "$test_tmp/verify.out")"
fi
pass "update-keyring fails when the key package check fails"

# No imported pubkeys: the closing check is what backs the success line.
: >"$log_file"
if KEYRING_TEST_NO_PUBKEY=1 run_keyring >"$test_tmp/pubkey.out" 2>&1; then
  fail "update-keyring fails when no signing keys are present"
fi
if grep -F "Keys are correct" "$test_tmp/pubkey.out" >/dev/null; then
  fail "update-keyring fails when no signing keys are present" "$(cat "$test_tmp/pubkey.out")"
fi
pass "update-keyring fails when no signing keys are present"
