#!/bin/bash
#
# The fingerprint setup installs libfprint, fprintd, and usbutils from Fedora.
# A rerun with everything installed must not touch dnf at all. The real
# omarchy-pkg-missing/omarchy-pkg-add run; rpm, dnf, and the privileged calls
# are stubbed.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
export CALL_LOG="$scratch/calls"
export PATH="$scratch/bin:$ROOT/bin:$PATH"

cat > "$scratch/bin/omarchy-hw-fingerprint" <<'STUB'
#!/bin/bash
exit "${HARDWARE_STATUS:-0}"
STUB
cat > "$scratch/bin/sudo" <<'STUB'
#!/bin/bash
case "$1" in
  dnf | fprintd-enroll) exec "$@" ;;
  *) echo "Unexpected privileged call: $*" >> "$CALL_LOG"; exit 99 ;;
esac
STUB
# INSTALLED lists the installed package names, one per line; an install adds
# its packages to INSTALLED_LOG so omarchy-pkg-add's follow-up query sees them.
cat > "$scratch/bin/rpm" <<'STUB'
#!/bin/bash
[[ $1 == "-q" ]] || { echo "Unexpected rpm call: $*" >> "$CALL_LOG"; exit 99; }
shift
[[ $1 == "--whatprovides" ]] && shift
[[ $1 == "--" ]] && shift
grep -qx -- "$1" <<< "${INSTALLED:-}" || grep -qx -- "$1" "$INSTALLED_LOG"
STUB
cat > "$scratch/bin/dnf" <<'STUB'
#!/bin/bash
printf 'dnf %s\n' "$*" >> "$CALL_LOG"
if [[ ${INSTALL_STATUS:-0} != 0 ]]; then
  exit 1
fi
for arg in "$@"; do
  [[ $arg == -* ]] || printf '%s\n' "$arg" >> "$INSTALLED_LOG"
done
STUB
cat > "$scratch/bin/fprintd-enroll" <<'STUB'
#!/bin/bash
# Stop before verification/PAM; no host authentication files may be changed.
echo enroll >> "$CALL_LOG"
exit 1
STUB
cat > "$scratch/bin/fprintd-verify" <<'STUB'
#!/bin/bash
echo verify >> "$CALL_LOG"
exit 1
STUB
chmod +x "$scratch/bin/"*
export INSTALLED_LOG="$scratch/installed"

run_setup() {
  : > "$CALL_LOG"
  : > "$INSTALLED_LOG"
  if "$ROOT/bin/omarchy-setup-security-fingerprint" > "$scratch/output" 2>&1; then
    fail "setup stops on the simulated enrollment or installation failure"
  fi
  if grep -q 'Unexpected privileged call' "$CALL_LOG"; then
    fail "setup does not change PAM after failed enrollment"
  fi
}

assert_installs() {
  grep -qx 'dnf install -y -- libfprint fprintd usbutils' "$CALL_LOG" || fail "$1"
  (( $(grep -c '^dnf ' "$CALL_LOG") == 1 )) || fail "$1: one dnf transaction"
}

run_setup
assert_installs "a fresh machine installs libfprint, fprintd and usbutils"
grep -qx enroll "$CALL_LOG" || fail "installation is followed by enrollment"
pass "a fresh machine installs libfprint and reaches enrollment"

INSTALLED=$'libfprint\nfprintd\nusbutils' run_setup
if grep -q '^dnf' "$CALL_LOG"; then
  fail "a rerun with everything installed does not touch dnf"
fi
grep -qx enroll "$CALL_LOG" || fail "a rerun with everything installed reaches enrollment"
pass "a rerun with everything installed goes straight to enrollment"

INSTALL_STATUS=1 run_setup
if grep -qx enroll "$CALL_LOG"; then
  fail "a failed package transaction prevents enrollment"
fi
pass "a failed installation stops before enrollment"

HARDWARE_STATUS=1 run_setup
[[ ! -s $CALL_LOG ]] || fail "missing hardware stops before package operations"
pass "missing hardware performs no package operations"
