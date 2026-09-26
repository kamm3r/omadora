#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
source "$SHELL_TEST_DIR/fixtures/passwordless-sudo-test.sh"

quarantine="$test_tmp/var/lib/omarchy/sudoers-quarantine"
quarantined_policy() {
  local entry
  for entry in "$quarantine"/*/; do
    if [[ $(cat "$entry/name") == "$1" ]]; then
      cat "$entry/policy"
      return 0
    fi
  done
  return 1
}
# The old writer accepted any $USER, so a basename can sit just under NAME_MAX.
long_suffix=$(printf 'l%.0s' {1..223})
(
  source "$library"
  printf 'deleteduser ALL=(ALL) NOPASSWD: ALL\n' >"$(rule_file 1000)"
  printf 'buildbot$ ALL=(ALL) NOPASSWD: ALL\n' >"$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-buildbot$"
  # The legacy command never validated the account name, so a manual or NSS
  # account outside the current policy still has its exact old grant removed.
  printf 'Alice ALL=(ALL) NOPASSWD: ALL\n' >"$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-Alice"
  # The legacy writer produced the body with echo. Under BASH_ENV with
  # xpg_echo, USER='ali\0143e' yields this filename with an 'alice' rule, so
  # a suffix/body mismatch does not prove administrator authorship.
  printf 'alice ALL=(ALL) NOPASSWD: ALL\n' >"$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-ali\\0143e"
  printf 'alice ALL=(ALL) NOPASSWD: ALL\n' >"$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-$long_suffix"
  printf 'admin ALL=(ALL) NOPASSWD: /usr/bin/true\n' >"$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-custom"
  TEST_DELETE_FAIL=1 assert_status 1 cleanup_all_locked
  [[ -e $(rule_file 1000) ]]
  cleanup_all_locked
  ! compgen -G "$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-*"
  [[ $(stat -c '%a' "$quarantine") == 700 ]]
  [[ $(quarantined_policy '99-omarchy-nopasswd-ali\0143e') == 'alice ALL=(ALL) NOPASSWD: ALL' ]]
  [[ $(quarantined_policy "99-omarchy-nopasswd-$long_suffix") == 'alice ALL=(ALL) NOPASSWD: ALL' ]]
  [[ $(quarantined_policy 99-omarchy-nopasswd-custom) == 'admin ALL=(ALL) NOPASSWD: /usr/bin/true' ]]
  (( $(ls -A "$quarantine" | wc -l) == 3 ))
)
pass "legacy cleanup removes generated rules for any account and quarantines everything else in the prefix"

# Run the actual migration queue for separate temporary homes. Sudo only calls
# the mapped helper and can be refused without requesting host authorization.
mkdir -p "$test_tmp/source/migrations"
sed "s|/usr/bin/omarchy-sudo-passwordless|$test_tmp/omarchy-sudo-passwordless|g" \
  "$ROOT/migrations/1788163635.sh" >"$test_tmp/source/migrations/1788163635.sh"
printf 'echo "later migration ran"\n' >"$test_tmp/source/migrations/1788163636.sh"
run_migrations() {
  TEST_MIGRATION=1 OMARCHY_PATH="$test_tmp/source" OMARCHY_MIGRATION_STATE="$test_tmp/$1" \
    PATH="$test_tmp/bin:$PATH" /usr/bin/bash "$ROOT/bin/omarchy-migrate" >"$test_tmp/migrations.log" 2>&1
}
marker="$test_tmp/var/lib/omarchy/migrations/1788163635"
(
  source "$library"
  # A quarantine that cannot be trusted keeps the migration pending.
  printf 'alice ALL=(ALL) NOPASSWD: ALL\n' >"$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-mismatch"
  TEST_BAD_PATH="$test_tmp/var/lib/omarchy" assert_status 1 run_migrations first
  [[ ! -e $marker && -e $test_tmp/etc/sudoers.d/99-omarchy-nopasswd-mismatch ]]
  printf 'audituser ALL=(ALL) NOPASSWD: ALL\n' >"$(rule_file 1000)"
  printf 'Alice ALL=(ALL) NOPASSWD: ALL\n' >"$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-Alice"
  TEST_DELETE_FAIL=1 assert_status 1 run_migrations first
  [[ ! -e $marker && ! -e $test_tmp/first/1788163636.sh ]]
  run_migrations first
  [[ -f $marker && -f $test_tmp/first/1788163636.sh ]]
  ! compgen -G "$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-*"
  [[ $(quarantined_policy 99-omarchy-nopasswd-mismatch) == 'alice ALL=(ALL) NOPASSWD: ALL' ]]
  enable_locked 1000 15
  cp "$(rule_file 1000)" "$test_tmp/renewed"
  : >"$test_tmp/commands"
  TEST_NO_SUDO=1 run_migrations second
  [[ -f $test_tmp/second/1788163636.sh ]]
  ! grep -q '^sudo ' "$test_tmp/commands"
  cmp "$(rule_file 1000)" "$test_tmp/renewed"
)
pass "migration completion is machine-wide, retryable, and needs no sudo for later users"

(
  source "$library"
  TEST_BAD_PATH="$marker" assert_status 1 migration_complete
  rm "$marker"
  ln -s "$test_tmp/renewed" "$marker"
  assert_status 1 migration_complete
  assert_status 1 migrate_locked
  [[ -L $marker ]]
  rm "$marker"
)
pass "migration checks marker ownership and rejects symlinks"

# Checkout-only installs have no packaged helper, so the migration falls back
# to the checkout's copy and legacy grants are still removed.
sed "s|/usr/bin/omarchy-sudo-passwordless|$test_tmp/absent/omarchy-sudo-passwordless|g" \
  "$ROOT/migrations/1788163635.sh" >"$test_tmp/source/migrations/1788163635.sh"
mkdir -p "$test_tmp/source/bin"
ln -s "$test_tmp/omarchy-sudo-passwordless" "$test_tmp/source/bin/omarchy-sudo-passwordless"
(
  source "$library"
  rm -f "$marker" "$(rule_file 1000)"
  printf 'audituser ALL=(ALL) NOPASSWD: ALL\n' >"$(rule_file 1000)"
  run_migrations third
  [[ -f $marker && -f $test_tmp/third/1788163636.sh ]]
  ! compgen -G "$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-*"
)
pass "migration falls back to the checkout helper when no packaged copy exists"

# The omarchy-settings RPM calls these helper actions from %pre, %preun, and
# %posttrans, so the whole package contract lives in the helper. As root, run
# the packaged helper itself the way a scriptlet does.
package_action() {
  TEST_EUID=0 /usr/bin/bash -p "$test_tmp/omarchy-sudo-passwordless" "$1"
}
reset_grant
(
  source "$library"
  # Erase: %preun revokes, and a failure aborts the erase with publication
  # refused until a clean retry.
  enable_locked 1000 15
  TEST_DELETE_FAIL=1 assert_status 1 package_action __package-removing
  [[ -e $REMOVAL_BLOCKER && -e $(rule_file 1000) ]]
  assert_status 1 enable_locked 1000 15
  package_action __package-removing
  [[ ! -e $(rule_file 1000) && -e $REMOVAL_BLOCKER ]]
  # Install completes through %posttrans, which lifts the blocker.
  package_action __package-installed
  [[ ! -e $REMOVAL_BLOCKER ]]
  # Upgrade: the new package's %pre revokes before its files land, then
  # %posttrans finishes the transaction.
  enable_locked 1000 15
  package_action __package-removing && package_action __package-installed
  [[ ! -e $(rule_file 1000) && ! -e $REMOVAL_BLOCKER ]]
  # A failed %pre skips the package, and a %posttrans that cannot sweep must
  # not lift the blocker while a rule remains; a clean retry recovers.
  enable_locked 1000 15
  TEST_DELETE_FAIL=1 assert_status 1 package_action __package-removing
  TEST_DELETE_FAIL=1 assert_status 1 package_action __package-installed
  [[ -e $REMOVAL_BLOCKER && -e $(rule_file 1000) ]]
  assert_status 1 enable_locked 1000 15
  package_action __package-installed
  [[ ! -e $(rule_file 1000) && ! -e $REMOVAL_BLOCKER ]]
  # A stranded blocker plus a live rule from an interrupted removal is
  # cleaned by the next completed installation, not merely unblocked.
  enable_locked 1000 15
  : >"$REMOVAL_BLOCKER"
  package_action __package-installed
  [[ ! -e $(rule_file 1000) && ! -e $REMOVAL_BLOCKER ]]
  # A fresh install has no %pre of its own to have set the blocker, so
  # completion holds it while it sweeps: a leftover rule it cannot remove
  # leaves publication refused rather than merely reporting an error.
  enable_locked 1000 15
  rm -f "$REMOVAL_BLOCKER"
  TEST_DELETE_FAIL=1 assert_status 1 package_action __package-installed
  [[ -e $REMOVAL_BLOCKER && -e $(rule_file 1000) ]]
  assert_status 1 enable_locked 1000 15
  package_action __package-installed
  [[ ! -e $(rule_file 1000) && ! -e $REMOVAL_BLOCKER ]]
  # The sweep must not depend on the glob state a scriptlet shell inherits.
  enable_locked 1000 15
  GLOBIGNORE='*' package_action __package-installed
  [[ ! -e $(rule_file 1000) && ! -e $REMOVAL_BLOCKER ]]
  # A failure before the lock is even taken, such as an untrusted lock
  # directory, must still leave publication refused.
  enable_locked 1000 15
  rm -f "$REMOVAL_BLOCKER"
  TEST_BAD_PATH="$test_tmp/run/lock" assert_status 1 package_action __package-installed
  [[ -e $REMOVAL_BLOCKER && -e $(rule_file 1000) ]]
  TEST_BAD_PATH="$test_tmp/run/lock" assert_status 1 package_action __package-removing
  [[ -e $REMOVAL_BLOCKER ]]
  package_action __package-installed
  [[ ! -e $(rule_file 1000) && ! -e $REMOVAL_BLOCKER ]]
  # Completion requires boot cleanup before lifting the blocker.
  enable_locked 1000 15
  mv "$BOOT_CLEANUP_FILE" "$test_tmp/saved-boot-cleanup"
  assert_status 1 package_action __package-installed
  [[ -e $REMOVAL_BLOCKER && ! -e $(rule_file 1000) ]]
  mv "$test_tmp/saved-boot-cleanup" "$BOOT_CLEANUP_FILE"
  package_action __package-installed
  [[ ! -e $REMOVAL_BLOCKER ]]
  # Only root reaches the package actions.
  assert_status 1 /usr/bin/bash -p "$test_tmp/omarchy-sudo-passwordless" __package-removing
  assert_status 1 /usr/bin/bash -p "$test_tmp/omarchy-sudo-passwordless" __package-installed
)
pass "package scriptlet actions revoke grants, block publication, and recover on installation only with the namespace empty"

reset_grant
# Hold the source lock, then start package removal. A native flock on the
# mapped file must serialize the publisher and the removal action.
cat >"$test_tmp/worker" <<'WORKER'
#!/bin/bash
set -euo pipefail
source "$TEST_LIBRARY"
critical() {
  touch "$TEST_GRANT_ROOT/entered"
  for (( attempt=0; attempt<500; attempt++ )); do
    [[ ! -e $TEST_GRANT_ROOT/release ]] || break
    sleep 0.01
  done
  [[ -e $TEST_GRANT_ROOT/release ]] || return 1
  enable_locked 1000 15
}
with_root_lock critical
WORKER
TEST_LIBRARY="$library" /usr/bin/bash "$test_tmp/worker" >"$test_tmp/publisher.log" 2>&1 &
publisher=$!
children+=("$publisher")
for (( attempt=0; attempt<200; attempt++ )); do
  [[ ! -e $test_tmp/entered ]] || break
  sleep 0.01
done
[[ -f $test_tmp/entered ]] || fail "publisher failed to acquire the lock"
package_action __package-removing >"$test_tmp/removal.log" 2>&1 &
removal=$!
children+=("$removal")
# The removal announces itself before waiting for the lock, so a publisher
# still holding it is refused rather than allowed to publish a rule that the
# removal would delete a moment later.
for (( attempt=0; attempt<200; attempt++ )); do
  [[ ! -f $test_tmp/run/omarchy-sudo-passwordless-package-removing ]] || break
  sleep 0.01
done
[[ -f $test_tmp/run/omarchy-sudo-passwordless-package-removing ]] || fail "removal did not announce itself before waiting for the lock"
touch "$test_tmp/release"
if wait "$publisher"; then fail "publisher was allowed to publish after removal announced itself" "$(cat "$test_tmp/publisher.log")"; fi
wait "$removal" || fail "removal failed" "$(cat "$test_tmp/removal.log")"
children=()
[[ ! -e $test_tmp/etc/sudoers.d/99-omarchy-nopasswd-1000 ]]
[[ -f $test_tmp/run/omarchy-sudo-passwordless-package-removing ]]
pass "an announced package removal refuses a waiting publisher and clears the namespace"

# systemd-tmpfiles operates on an explicit disposable root, never the host.
reset_grant
: >"$test_tmp/etc/sudoers.d/99-omarchy-nopasswd-1000"
: >"$test_tmp/etc/sudoers.d/unrelated"
# The shipped rule file itself, not an inline copy: Fedora's systemd-tmpfiles
# has no --inline, and this keeps the test on the file the package installs.
rule="$ROOT/etc/tmpfiles.d/omarchy-nopasswd-sudo.conf"
/usr/bin/systemd-tmpfiles --root="$test_tmp" --remove "$rule"
[[ -f $test_tmp/etc/sudoers.d/99-omarchy-nopasswd-1000 ]] || fail "routine tmpfiles shortened a live grant"
/usr/bin/systemd-tmpfiles --root="$test_tmp" --remove --boot "$rule"
[[ ! -e $test_tmp/etc/sudoers.d/99-omarchy-nopasswd-1000 && -f $test_tmp/etc/sudoers.d/unrelated ]] || fail "boot cleanup boundary"
pass "native boot cleanup removes grants while routine tmpfiles preserves them"
