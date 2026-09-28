#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

remove="${REMOVE_SECURITY_SSHD_UNDER_TEST:-$ROOT/bin/omarchy-remove-security-sshd}"
test_dir=$(mktemp -d)
stub_bin="$test_dir/bin"
mkdir -p "$stub_bin"
trap 'rm -rf "$test_dir"' EXIT

cat >"$stub_bin/omarchy-cmd-present" <<'STUB'
#!/bin/bash
[[ $1 == "firewall-cmd" && ${FIREWALLD_PRESENT:-1} == 1 ]]
STUB

# firewalld's permanent config as one "kind value" line per entry. Queries exit
# 1 for an absent entry, as firewall-cmd does.
cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
set -euo pipefail

printf '%s\n' "$*" >>"${CALL_LOG:?}"
[[ $1 == "systemctl" ]] && exit 0
[[ $1 == "firewall-cmd" ]] || exit 97
shift

if [[ $* == "--reload" ]]; then
  operation=reload
elif [[ $1 == "--permanent" && $2 =~ ^--(query|remove)-(rich-rule|service|port)=(.*)$ ]]; then
  operation=${BASH_REMATCH[1]}
  entry="${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
else
  exit 97
fi

case "${entry:-}" in
  "rich-rule rule service name=\"ssh\" limit value=\"25/minute\" accept") name=limit ;;
  "service ssh") name=service ;;
  "port 22/tcp") name=port ;;
  "") name=reload ;;
  *) exit 97 ;;
esac

if [[ ${FAIL_FIREWALLD:-} == "$operation-$name" || ${FAIL_FIREWALLD:-} == "$name" ]]; then
  printf 'injected firewalld failure: %s\n' "${FAIL_FIREWALLD}" >&2
  exit 252
fi

case $operation in
  reload) exit 0 ;;
  query) grep -Fxq "$entry" "${FIREWALLD_STATE:?}" ;;
  remove)
    grep -Fxq "$entry" "$FIREWALLD_STATE" || { echo "Warning: NOT_ENABLED" >&2; exit 0; }
    next="$FIREWALLD_STATE.next"
    grep -Fxv "$entry" "$FIREWALLD_STATE" >"$next" || true
    mv "$next" "$FIREWALLD_STATE"
    ;;
esac
STUB

cat >"$stub_bin/gum" <<'STUB'
#!/bin/bash
exit 1
STUB

chmod +x "$stub_bin"/*

prepare_case() {
  local name="$1"
  case_dir="$test_dir/$name"
  home="$case_dir/home"
  calls="$case_dir/calls"
  state="$case_dir/firewalld-state"
  mkdir -p "$home/.ssh"
  printf 'ssh-ed25519 fake-key test@example\n' >"$home/.ssh/authorized_keys"
  : >"$calls"
  printf '%s\n' 'rich-rule rule service name="ssh" limit value="25/minute" accept' 'service ssh' 'port 22/tcp' 'service https' >"$state"
}

run_remove() {
  local failure="${1:-}"
  set +e
  output=$(env HOME="$home" PATH="$stub_bin:$ROOT/bin:/usr/bin:/bin" \
    CALL_LOG="$calls" FIREWALLD_STATE="$state" FIREWALLD_PRESENT="${FIREWALLD_PRESENT:-1}" FAIL_FIREWALLD="$failure" \
    bash "$remove" 2>&1)
  status=$?
  set -e
}

assert_no_success_claim() {
  if grep -Eiq 'firewall[^[:cntrl:]]*(closed|removed)|((closed|removed)[^[:cntrl:]]*firewall)' <<<"$output"; then
    fail "output does not claim firewall success" "$output"
  fi
}

prepare_case standard
run_remove
(( status == 0 )) || fail "removal succeeds with standard SSH rules" "$output"
[[ $(<"$state") == 'service https' ]] || fail "removal deletes only standard SSH rules" "$(cat "$state")"
[[ -s $home/.ssh/authorized_keys ]] || fail "declined key removal preserves authorized keys"

: >"$calls"
run_remove
(( status == 0 )) || fail "repeated removal accepts absent rules" "$output"
[[ $(<"$state") == 'service https' ]] || fail "repeated removal preserves unrelated rules"
! grep -q -- '--remove-' "$calls" || fail "repeated removal only queries absent rules" "$(cat "$calls")"
! grep -q 'NOT_ENABLED' <<<"$output" || fail "repeated removal stays quiet" "$output"
pass "removal deletes all standard SSH rules, preserves HTTPS, and is idempotent"

for failure in query-limit remove-limit query-service remove-service query-port remove-port reload; do
  prepare_case "$failure"
  run_remove "$failure"
  (( status != 0 )) || fail "$failure failure makes removal fail" "$output"
  grep -Fq "injected firewalld failure: $failure" <<<"$output" ||
    fail "$failure stderr reaches the caller" "$output"
  assert_no_success_claim
  [[ -s $home/.ssh/authorized_keys ]] || fail "$failure preserves authorized keys"
done
pass "each firewalld query, removal, and reload failure is returned without false success"

prepare_case no-firewalld
FIREWALLD_PRESENT=0 run_remove
(( status == 0 )) || fail "removal succeeds without firewalld" "$output"
! grep -q '^firewall-cmd ' "$calls" || fail "no-firewalld removal does not invoke firewall-cmd" "$(cat "$calls")"
assert_no_success_claim
[[ -s $home/.ssh/authorized_keys ]] || fail "no-firewalld removal preserves authorized keys"
pass "no-firewalld removal does not claim firewall success"
