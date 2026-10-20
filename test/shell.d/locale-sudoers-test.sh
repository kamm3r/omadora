#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

generator="$ROOT/bin/omarchy-locale-generate"
language="$ROOT/bin/omarchy-language"
sudoers_file="$ROOT/etc/sudoers.d/omarchy-locale-generate"
registry="$ROOT/default/i18n/locales.json"

# Exactly one rule, naming each registry code as the whole argument. A code
# missing would prompt again for that language; the command with its argument
# dropped, which sudoers reads as "any arguments", would widen the grant.
expected="%wheel ALL=(root) NOPASSWD: $(jq -r 'keys | sort | map("/usr/bin/omarchy-locale-generate " + .) | join(", ")' "$registry")"
rules=$(grep -vE '^[[:space:]]*(#|$)' "$sudoers_file")
[[ $rules == "$expected" ]] ||
  fail "locale sudoers file carries exactly one rule naming each registry code" "got: $rules"

if command -v visudo >/dev/null; then
  visudo -cf "$sudoers_file" >/dev/null || fail "locale sudoers rule parses"
fi
pass "locale sudoers rule is scoped to the registry's languages"

grep -Fx 'generator=/usr/bin/omarchy-locale-generate' "$language" >/dev/null ||
  fail "omarchy-language elevates the path the sudoers rule names"
# `sudo -l` alone says whether a command is permitted, which Omarchy's blanket
# %wheel rule answers yes to; only the long listing prints the entry's tags.
grep -E 'sudo -n -l -l' "$language" >/dev/null ||
  fail "omarchy-language reads the grant from the long sudo listing"
pass "omarchy-language asks sudo for the grant before prompting"

# Root resolves bare helpers under sudo's secure_path, which a dev link
# prepends a user-writable checkout bin/ to, so the helper pins PATH to system
# directories once it holds root, and only then.
gated=$(grep -A1 -E '^if \(\( EUID == 0 \)\); then$' "$generator" || true)
[[ $gated == *"export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin"* ]] ||
  fail "omarchy-locale-generate gates the trusted-PATH pin on holding root"
# The test overrides must never reach root: root reads the packaged registry
# and the real locale.gen.
overrides=$(sed -n '/^if (( EUID != 0 )); then$/,/^fi$/p' "$generator")
[[ $overrides == *'OMARCHY_LOCALE_REGISTRY'* ]] ||
  fail "omarchy-locale-generate honors its test overrides only without root"
pass "omarchy-locale-generate pins PATH and its files when it holds root"

# Stub dnf so the helper's package selection is exercised without changing the host.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat >"$work/bin/dnf" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$LOCALE_PACKAGE_LOG"
exit "${LOCALE_PACKAGE_STATUS:-0}"
STUB
chmod +x "$work/bin/dnf"
export LOCALE_PACKAGE_LOG=$work/packages.log OMARCHY_LOCALE_REGISTRY=$registry
run() { PATH="$work/bin:$PATH" bash "$generator" "$@"; }

for pair in 'sv sv' 'fil fil' 'pt-BR pt' 'zh-TW zh' 'no nb'; do
  read -r code package <<<"$pair"
  : >"$LOCALE_PACKAGE_LOG"
  run "$code" || fail "the locale helper installs $code"
  [[ $(cat "$LOCALE_PACKAGE_LOG") == "install -y glibc-langpack-$package" ]] ||
    fail "the locale helper selects the Fedora package for $code" "$(cat "$LOCALE_PACKAGE_LOG")"
done
pass "locale installation maps regional and Norwegian UI codes to Fedora packages"

for bad in "" "xx" "../da" "da;id" "da sv" "DA"; do
  : >"$LOCALE_PACKAGE_LOG"
  if run "$bad" 2>/dev/null; then fail "the locale helper rejects '$bad'"; fi
  [[ ! -s $LOCALE_PACKAGE_LOG ]] || fail "a rejected code installs nothing"
done
if run da sv 2>/dev/null; then fail "the locale helper takes exactly one code"; fi
pass "the locale helper rejects anything but one registry code"

printf '{"da": {"locale": "da_DK.UTF-8 --allowerasing"}}\n' >"$work/registry.json"
: >"$LOCALE_PACKAGE_LOG"
if OMARCHY_LOCALE_REGISTRY=$work/registry.json run da 2>/dev/null; then fail "the locale helper rejects malformed registry locales"; fi
[[ ! -s $LOCALE_PACKAGE_LOG ]] || fail "a malformed registry locale installs nothing"
if LOCALE_PACKAGE_STATUS=1 run sv 2>/dev/null; then fail "a failed package installation fails locale setup"; fi
pass "invalid locales and failed package installations cannot complete locale setup"
