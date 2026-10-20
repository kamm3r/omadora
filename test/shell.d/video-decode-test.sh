#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
export OMARCHY_PATH="$ROOT"
export PATH="$scratch/bin:$ROOT/bin:$PATH"
export OMARCHY_TEST_QUALCOMM="$scratch/is-qualcomm"
cat >"$scratch/bin/omarchy-hw-aarch64-qualcomm" <<'STUB'
#!/bin/bash
[[ -f $OMARCHY_TEST_QUALCOMM ]]
STUB
chmod +x "$scratch/bin/omarchy-hw-aarch64-qualcomm"

new_home() {
  export HOME="$scratch/$1"
  mkdir -p "$HOME/.config/mpv"
  conf="$HOME/.config/mpv/mpv.conf"
}

helper="$ROOT/bin/omarchy-install-video-decode"
hwdec='hwdec=auto-safe,v4l2m2m-copy'
new_home other
bash "$helper"
[[ ! -e $conf ]] || fail "other platforms keep their mpv defaults"
pass "other platforms keep their mpv defaults"

touch "$OMARCHY_TEST_QUALCOMM"
new_home qualcomm
printf '%s\n' '--use-angle=vulkan' >"$HOME/.config/chromium-flags.conf"
bash "$helper"
bash "$helper"
[[ $(grep -cFx "$hwdec" "$conf") == "1" ]] || fail "Snapdragon fallback is installed once"
[[ $(cat "$HOME/.config/chromium-flags.conf") == '--use-angle=vulkan' ]] || fail "Fedora Chromium flags stay unchanged"
pass "Snapdragon gets the mpv fallback once and preserves Fedora Chromium flags"

for choice in 'hwdec = no' $'[software]\nhwdec=no\n[default] # global\nhwdec=auto'; do
  printf '%s\n' "$choice" >"$conf"
  bash "$helper"
  [[ $(cat "$conf") == "$choice" ]] || fail "the user's global hwdec choice is preserved"
done
pass "global hardware-decoding choices are preserved, including after default profiles"

for profile in '[software]' '[software] # on request'; do
  printf '%s\n' "$profile" 'hwdec=no' >"$conf"
  bash "$helper"
  mapfile -t lines <"$conf"
  [[ ${lines[1]} == "$hwdec" && ${lines[2]} == "$profile" && ${lines[3]} == 'hwdec=no' ]] || fail "fallback stays outside profiles"
done
pass "profile-specific choices are preserved and the fallback goes outside profiles"

new_home symlink
printf '%s\n' 'volume=80' >"$scratch/mpv.conf"
ln -s "$scratch/mpv.conf" "$conf"
bash "$helper"
[[ -L $conf ]] || fail "mpv config symlinks survive"
grep -Fxq "$hwdec" "$scratch/mpv.conf" || fail "the symlink target receives the fallback"
pass "symlinks are preserved and their targets receive the fallback"

new_home unwritable
mkdir -p "$conf/blocked"
if bash "$helper" 2>/dev/null; then
  fail "an unwritable mpv configuration reports failure"
fi
pass "an unwritable mpv configuration reports failure"

new_home migration
bash -euo pipefail "$ROOT/migrations/1792202836.sh"
grep -Fxq "$hwdec" "$conf" || fail "existing installs receive the fallback through migration"
grep -Fxq 'run_logged "$OMARCHY_INSTALL/user/hardware/qualcomm/video-decode.sh"' "$ROOT/install/user/all.sh" || fail "fresh installs run the hardware setup"
grep -Fxq 'omarchy-install-video-decode' "$ROOT/bin/omarchy-reinstall-configs" || fail "config reinstalls restore the hardware setting"
pass "fresh installs, existing installs, and config reinstalls are wired to the helper"
