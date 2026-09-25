#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

run_guard() {
  OMARCHY_DNF_CMDLINE="$1" "$ROOT/bin/omarchy-update-pacman-guard"
}

if run_guard "dnf upgrade -y" >"$test_tmp/direct.out" 2>"$test_tmp/direct.err"; then
  fail "dnf guard blocks direct system upgrades"
fi
grep -q 'omarchy update' "$test_tmp/direct.err" || fail "dnf guard explains omarchy update entrypoint"
pass "dnf guard blocks direct dnf upgrade"

if run_guard "dnf distro-sync -y" >"$test_tmp/long.out" 2>"$test_tmp/long.err"; then
  fail "dnf guard blocks distro-sync system upgrades"
fi
pass "dnf guard blocks dnf distro-sync"

OMARCHY_UPDATE_DNF=1 run_guard "dnf upgrade -y" >"$test_tmp/omarchy.out" 2>"$test_tmp/omarchy.err"
[[ ! -s $test_tmp/omarchy.err ]] || fail "dnf guard stays quiet for omarchy update dnf call"
pass "dnf guard allows omarchy update dnf call"

# Legacy pacman-era env vars keep working for old hooks.
OMARCHY_UPDATE_PACMAN=1 run_guard "dnf upgrade -y" >"$test_tmp/legacy.out" 2>"$test_tmp/legacy.err"
[[ ! -s $test_tmp/legacy.err ]] || fail "dnf guard honors the legacy update marker"
pass "dnf guard honors the legacy update marker"

OMARCHY_ALLOW_DIRECT_DNF=1 run_guard "dnf upgrade -y" >"$test_tmp/override.out" 2>"$test_tmp/override.err"
[[ ! -s $test_tmp/override.err ]] || fail "dnf guard stays quiet for explicit direct dnf override"
pass "dnf guard allows explicit direct dnf override"

OMARCHY_ALLOW_DIRECT_PACMAN=1 run_guard "dnf upgrade -y" >"$test_tmp/legacy-override.out" 2>"$test_tmp/legacy-override.err"
[[ ! -s $test_tmp/legacy-override.err ]] || fail "dnf guard honors the legacy direct override"
pass "dnf guard honors the legacy direct override"

run_guard "dnf install firefox" >"$test_tmp/install.out" 2>"$test_tmp/install.err"
[[ ! -s $test_tmp/install.err ]] || fail "dnf guard stays quiet for non-upgrade dnf command"
pass "dnf guard ignores non-system-upgrade transactions"
