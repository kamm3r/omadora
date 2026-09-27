#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

# Builds the omarchy and omarchy-settings RPMs from this checkout into a
# temporary tree and checks what they contain. Nothing is installed: the
# settings scriptlet runs against a fake root.
if ! command -v rpmbuild >/dev/null || ! command -v rpm2cpio >/dev/null; then
  skip "rpm-build is not installed; skipping RPM packaging checks"
  exit 0
fi

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

build() {
  local spec=$1
  shift
  OMARCHY_SRC="$ROOT" rpmbuild -bb --define "_topdir $test_tmp/build" --define "omarchy_release 0.test" \
    --define "_binary_payload w0.ufdio" "$@" "$ROOT/packaging/rpm/$spec/$spec.spec" >"$test_tmp/$spec.log" 2>&1 ||
    fail "$spec builds from the checkout" "$(grep -E '^(error|  *Installed \(but unpackaged\)|   /)' "$test_tmp/$spec.log" | head -20)"
}

build omarchy-settings
build omarchy
rpms="$test_tmp/build/RPMS/noarch"
settings=$(ls "$rpms"/omarchy-settings-[0-9]*.rpm)
runtime=$(ls "$rpms"/omarchy-[0-9]*.rpm)
rpm -qlp "$settings" | sort >"$test_tmp/settings.list"
rpm -qlp "$runtime" | sort >"$test_tmp/runtime.list"
pass "omarchy and omarchy-settings build with every installed file packaged"

version=$(rpm -qp --qf '%{VERSION}' "$runtime")
[[ $version == "$(sed -E 's/[.-]([a-z])/~\1/' "$ROOT/version")" ]] || fail "the RPM version follows the version file" "$version"
[[ $(rpm -qp --requires "$runtime") == *"omarchy-settings = $version-0.test"* ]] || fail "omarchy requires its own omarchy-settings"
pass "the RPM version follows the version file, with a pre-release sorting before the release"

# Every command ships from exactly one package, from /usr/bin, with
# OMARCHY_PATH/bin pointing back at it.
while IFS= read -r command; do
  name=${command##*/}
  in_runtime=0 in_settings=0
  grep -qxF "/usr/bin/$name" "$test_tmp/runtime.list" && in_runtime=1
  grep -qxF "/usr/bin/$name" "$test_tmp/settings.list" && in_settings=1
  (( in_runtime + in_settings == 1 )) || fail "bin/$name ships from exactly one package"
done < <(find "$ROOT/bin" -maxdepth 1 -type f ! -name '*.pyc')
for name in omarchy-sudo-passwordless omarchy-security-functions omarchy-upload-log; do
  grep -qxF "/usr/bin/$name" "$test_tmp/settings.list" || fail "$name ships with omarchy-settings"
done
link=$(rpm -qlvp "$runtime" | awk '$NF == "/usr/bin/omarchy-update" && $(NF-2) == "/usr/share/omarchy/bin/omarchy-update" {print}')
[[ -n $link ]] || fail "OMARCHY_PATH/bin links back to /usr/bin"
pass "every command ships from exactly one package, with OMARCHY_PATH/bin linking to /usr/bin"

# The passwordless-sudo helper refuses to publish a grant unless the settings
# package revokes grants around its own changes (docs/passwordless-sudo.md).
[[ $(rpm -qp --qf '%{PREIN}' "$settings") == *"/usr/bin/omarchy-sudo-passwordless __package-removing"* ]] &&
  [[ $(rpm -qp --qf '%{PREUN}' "$settings") == *"/usr/bin/omarchy-sudo-passwordless __package-removing"* ]] &&
  [[ $(rpm -qp --qf '%{POSTTRANS}' "$settings") == *"/usr/bin/omarchy-sudo-passwordless __package-installed"* ]] ||
  fail "omarchy-settings carries the passwordless-sudo scriptlets"
grep -qxF /etc/tmpfiles.d/omarchy-nopasswd-sudo.conf "$test_tmp/settings.list" || fail "omarchy-settings ships the boot cleanup rule"
pass "omarchy-settings carries the passwordless-sudo scriptlets and boot cleanup"

markers=$(grep -c '^/etc/skel/\.local/state/omarchy/migrations/.*\.sh$' "$test_tmp/runtime.list")
(( markers == $(find "$ROOT/migrations" -maxdepth 1 -name '*.sh' | wc -l) )) || fail "new users start with every migration applied"
pass "new users start with every migration applied"

if grep -E '/libalpm/|/default/pacman/|/mkinitcpio\.conf\.d/|^/etc/nsswitch\.conf$|__pycache__|/\.git/' "$test_tmp/runtime.list" "$test_tmp/settings.list"; then
  fail "no Arch-only or generated files ship"
fi
grep -qxF /usr/share/omarchy/default/omadora-sync/omadora_sync/dnf.py "$test_tmp/runtime.list" || fail "omadora-sync ships with omarchy"
pass "no Arch-only or generated files ship, and omadora-sync is runtime"

# The settings scriptlet copies the files Fedora packages own into place and
# leaves nsswitch.conf to authselect. Run it against a fake root.
root="$test_tmp/root"
mkdir -p "$root/bin" "$root/etc/cups" "$root/etc/plymouth" "$root/etc/security"
(cd "$root" && rpm2cpio "$settings" | cpio -idm --quiet 2>/dev/null)
overrides=(cups/cups-browsed.conf cups/cups-files.conf plymouth/plymouthd.conf security/faillock.conf)
for file in "${overrides[@]}"; do echo "fedora default" >"$root/etc/$file"; done
: >"$root/etc/cups/cups-files.conf.rpmnew"
for command in authselect systemctl getent chgrp chmod; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\n' "$command" "$root" >"$root/bin/$command"
  chmod +x "$root/bin/$command"
done
rpm -qp --qf '%{POSTIN}' "$settings" |
  sed -e "s#/usr/share/omarchy#$root/usr/share/omarchy#g" -e "s#/etc/#$root/etc/#g" >"$test_tmp/post.sh"
PATH="$root/bin:$PATH" sh -e "$test_tmp/post.sh" || fail "the settings scriptlet runs"
for file in "${overrides[@]}"; do
  cmp -s "$root/etc/$file" "$ROOT/etc/$file" || fail "the settings scriptlet installs /etc/$file"
done
[[ ! -e $root/etc/cups/cups-files.conf.rpmnew ]] || fail "the settings scriptlet clears a stale .rpmnew"
cmp -s "$root/etc/skel/.bashrc" "$ROOT/default/bashrc" || fail "the settings scriptlet seeds /etc/skel/.bashrc"
grep -qxF 'authselect enable-feature with-mdns4' "$root/calls" || fail "the settings scriptlet enables mDNS through authselect"
[[ ! -e $root/etc/nsswitch.conf ]] || fail "the settings scriptlet leaves nsswitch.conf to authselect"
pass "the settings scriptlet installs the /etc files Fedora packages own and leaves nsswitch.conf to authselect"

build omarchy-settings --define "dev_suffix -dev"
dev=$(ls "$rpms"/omarchy-settings-dev-[0-9]*.rpm)
[[ $(rpm -qp --provides "$dev") == *"omarchy-settings = "* && $(rpm -qp --conflicts "$dev") == "omarchy-settings" ]] ||
  fail "the -dev variant replaces the release package"
pass "the -dev variant provides and replaces the release package"

# COPR's make-srpm step: the source RPM must carry its version and release,
# since COPR rebuilds it without this checkout.
git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1 || { skip "not a git checkout; skipping the COPR source RPM check"; exit 0; }
make -s -f "$ROOT/.copr/Makefile" srpm outdir="$test_tmp/srpm" spec=packaging/rpm/omarchy-settings/omarchy-settings.spec >"$test_tmp/srpm.log" 2>&1 ||
  fail "the COPR Makefile builds a source RPM" "$(<"$test_tmp/srpm.log")"
srpm=$(ls "$test_tmp"/srpm/*.src.rpm)
[[ $(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$srpm") == "$version-0.$(git -C "$ROOT" rev-list --count HEAD).git$(git -C "$ROOT" rev-parse --short HEAD)"* ]] ||
  fail "the COPR source RPM records its version and release" "$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$srpm")"
head -2 "$test_tmp/srpm/omarchy-settings.spec" | grep -q '^%global omarchy_release 0\.' || fail "the COPR spec carries its release"
pass "the COPR source RPM carries its version and a per-commit release"
