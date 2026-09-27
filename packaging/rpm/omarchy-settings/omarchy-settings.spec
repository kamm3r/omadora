# Omadora settings package: everything that must be on the system before the
# omarchy package, and before the first user is created. /etc drop-ins, the
# /etc/skel defaults new users start from, package-owned files under /usr,
# fonts, the Plymouth and SDDM themes, branding, and the passwordless-sudo
# helper with its expiry support. See docs/file-layout.md and
# packaging/README.md.
#
# Build inputs (all optional):
#   omarchy_version  RPM version; defaults to the checkout's version file
#   omarchy_release  RPM release; defaults to 1
#   dev_suffix       "-dev" builds the development variant, omarchy-settings-dev
#   OMARCHY_SRC      environment: build from this checkout instead of Source0

%global local_src %{getenv:OMARCHY_SRC}
%if "%{local_src}" != ""
%{!?omarchy_version:%global omarchy_version %(sed -E 's/[.-]([a-z])/~\\1/' "%{local_src}/version")}
%endif
%{!?omarchy_version:%global omarchy_version 0}
%{!?omarchy_release:%global omarchy_release 1}

%global __brp_python_bytecompile %{nil}
%global debug_package %{nil}

%global settings_commands omarchy-debug omarchy-debug-idle omarchy-upload-log omarchy-sudo-passwordless omarchy-security-functions

# /etc files other Fedora packages own. They ship under etc-overrides and are
# copied into place on install and upgrade (docs/file-layout.md).
%global etc_overrides cups/cups-browsed.conf cups/cups-files.conf plymouth/plymouthd.conf security/faillock.conf
# Kept in the repo but not shipped: mkinitcpio is the Arch reference dracut
# replaced, and authselect generates nsswitch.conf on Fedora (%%post enables its
# mDNS feature instead).
%global etc_unshipped mkinitcpio.conf.d nsswitch.conf

Name:           omarchy-settings%{?dev_suffix}
Version:        %{omarchy_version}
Release:        %{omarchy_release}%{?dist}
Summary:        System files and user defaults for Omadora
License:        MIT
URL:            https://github.com/kamm3r/omadora
Source0:        omarchy-%{omarchy_version}.tar.gz
BuildArch:      noarch

Requires:       bash
Requires:       sudo
Requires:       systemd
Requires:       gum
Requires(pre):  coreutils
Requires(post): coreutils
Requires(post): fontconfig

%if "%{?dev_suffix}" != ""
Provides:       omarchy-settings = %{version}-%{release}
Conflicts:      omarchy-settings
%else
Conflicts:      omarchy-settings-dev
%endif

%description
System configuration and user defaults for Omadora: drop-ins under /etc, the
/etc/skel tree every new user starts from, systemd user units, fonts, the
Plymouth and SDDM themes, branding, and the temporary passwordless-sudo helper
with its boot-time cleanup.

%prep
%if "%{local_src}" != ""
rm -rf %{name}-src
mkdir %{name}-src
tar -C "%{local_src}" --exclude=.git --exclude=.claude --exclude=__pycache__ -cf - . | tar -C %{name}-src -xf -
%setup -q -T -D -n %{name}-src
%else
%setup -q -n omarchy-%{omarchy_version}
%endif

%build
# Nothing to build.

%install
share=%{buildroot}%{_datadir}/omarchy
skel=%{buildroot}%{_sysconfdir}/skel

# Commands needed before the omarchy package installs, and the passwordless
# helper, which must be the package's own copy (docs/passwordless-sudo.md).
install -d %{buildroot}%{_bindir} "$share/bin"
for name in %{settings_commands}; do
  install -m 0755 "bin/$name" %{buildroot}%{_bindir}/"$name"
  ln -s %{_bindir}/"$name" "$share/bin/$name"
done

# /etc drop-ins we own outright.
while IFS= read -r -d '' file; do
  relative=${file#etc/}
  case " %{etc_overrides} %{etc_unshipped} " in
    *" $relative "* | *" ${relative%%%%/*} "*) continue ;;
  esac
  mode=0644
  [[ $relative == sudoers.d/* ]] && mode=0440
  install -D -m "$mode" "$file" %{buildroot}%{_sysconfdir}/"$relative"
done < <(find etc -type f -print0)

# /etc files other packages own ship as sources the scriptlet copies in.
install -d "$share/etc-overrides"
for relative in %{etc_overrides}; do
  install -m 0644 "etc/$relative" "$share/etc-overrides/${relative//\//-}"
done
install -m 0644 default/bashrc "$share/etc-overrides/dot.bashrc"

# User defaults: seeded into new homes, and kept as the resync source.
install -d "$skel/.config" "$share/config"
cp -a config/. "$skel/.config/"
cp -a config/. "$share/config/"
install -d "$skel/.local/share/applications" "$share/applications"
install -m 0644 applications/*.desktop "$skel/.local/share/applications/"
install -m 0644 applications/*.desktop "$share/applications/"
install -d "$skel/.local/state/omarchy/toggles/hypr"
install -m 0644 default/hypr/toggles/*.lua "$skel/.local/state/omarchy/toggles/hypr/"
install -d "$skel/.local/share/nautilus-python/extensions"
install -m 0644 default/nautilus-python/extensions/*.py "$skel/.local/share/nautilus-python/extensions/"
install -d "$skel/.config/omarchy/branding"
install -m 0644 icon.txt "$skel/.config/omarchy/branding/about.txt"
install -m 0644 logo.txt "$skel/.config/omarchy/branding/screensaver.txt"

# The shared default tree. omadora-sync is runtime code and ships with omarchy;
# the Arch pacman and ALPM trees are reference only.
install -d "$share/default"
for entry in default/*; do
  case ${entry##*/} in
    omadora-sync | pacman | libalpm) continue ;;
  esac
  cp -a "$entry" "$share/default/"
done

# Package-owned system files.
install -D -m 0644 default/uwsm/env.d/10-omarchy %{buildroot}%{_datadir}/uwsm/env.d/10-omarchy
install -d %{buildroot}%{_prefix}/lib/environment.d
install -m 0644 default/environment.d/*.conf %{buildroot}%{_prefix}/lib/environment.d/
install -D -m 0644 default/fontconfig/conf.avail/50-omarchy.conf %{buildroot}%{_datadir}/fontconfig/conf.avail/50-omarchy.conf
install -d %{buildroot}%{_sysconfdir}/fonts/conf.d
ln -s %{_datadir}/fontconfig/conf.avail/50-omarchy.conf %{buildroot}%{_sysconfdir}/fonts/conf.d/50-omarchy.conf
install -d %{buildroot}%{_datadir}/xdg-terminal-exec
install -m 0644 default/xdg-terminal-exec/*.list %{buildroot}%{_datadir}/xdg-terminal-exec/
install -D -m 0644 default/applications/mimeapps.list %{buildroot}%{_datadir}/applications/mimeapps.list
install -d %{buildroot}%{_userunitdir}
install -m 0644 default/systemd/user/*.service %{buildroot}%{_userunitdir}/
install -D -m 0644 default/systemd/user/app.slice.d/10-oomd.conf %{buildroot}%{_userunitdir}/app.slice.d/10-oomd.conf
install -D -m 0755 default/systemd/system-sleep/unmount-fuse %{buildroot}%{_prefix}/lib/systemd/system-sleep/unmount-fuse
install -D -m 0644 default/systemd/zram-generator.conf.d/90-omarchy.conf %{buildroot}%{_prefix}/lib/systemd/zram-generator.conf.d/90-omarchy.conf
install -D -m 0644 default/systemd/system/plocate-updatedb.service.d/10-omarchy.conf %{buildroot}%{_unitdir}/plocate-updatedb.service.d/10-omarchy.conf
install -D -m 0644 default/fonts/omarchy/omarchy.ttf %{buildroot}%{_datadir}/fonts/omarchy/omarchy.ttf
install -d %{buildroot}%{_datadir}/sddm/themes
cp -a default/sddm/omarchy %{buildroot}%{_datadir}/sddm/themes/omarchy
install -m 0644 default/sddm/hyprland.lua %{buildroot}%{_datadir}/sddm/hyprland.lua
install -D -m 0644 default/wayland-sessions/omarchy.desktop %{buildroot}%{_datadir}/wayland-sessions/omarchy.desktop
install -d %{buildroot}%{_datadir}/plymouth/themes
cp -a default/plymouth %{buildroot}%{_datadir}/plymouth/themes/omarchy
install -D -m 0644 default/snapper/root %{buildroot}%{_sysconfdir}/snapper/config-templates/omarchy

# Icons and branding.
for size in 48x48 256x256; do
  install -d %{buildroot}%{_datadir}/icons/hicolor/$size/apps
done
install -d %{buildroot}%{_datadir}/icons/hicolor/scalable/apps
while IFS= read -r -d '' icon; do
  case $icon in
    *.svg) install -m 0644 "$icon" %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/ ;;
    *) install -m 0644 "$icon" %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/ ;;
  esac
done < <(find applications/icons -type f -print0)
install -m 0644 logo.txt logo.svg icon.txt icon.png "$share/"
install -D -m 0644 icon.png %{buildroot}%{_datadir}/pixmaps/omarchy.png
install -m 0644 icon.png %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/omarchy.png

%pre
# Revoke temporary passwordless-sudo grants before this package's files change.
# A failure here stops the install or upgrade, like ALPM's AbortOnFail.
if [ -x /usr/bin/omarchy-sudo-passwordless ]; then
  /usr/bin/omarchy-sudo-passwordless __package-removing || exit 1
fi

%preun
/usr/bin/omarchy-sudo-passwordless __package-removing || exit 1

%post
# Files other packages own: copy the Omadora versions over them. User edits to
# these are replaced on every upgrade (docs/file-layout.md).
overrides=%{_datadir}/omarchy/etc-overrides
for relative in %{etc_overrides}; do
  source="$overrides/$(printf '%%s' "$relative" | tr / -)"
  target=/etc/$relative
  [ -e "$(dirname "$target")" ] || continue
  cp -f "$source" "$target"
  rm -f "$target.rpmnew"
done
if getent group cups >/dev/null 2>&1 && [ -f /etc/cups/cups-files.conf ]; then
  chgrp cups /etc/cups/cups-files.conf && chmod 0640 /etc/cups/cups-files.conf
fi
cp -f "$overrides/dot.bashrc" /etc/skel/.bashrc
# Fedora generates nsswitch.conf through authselect; enable its mDNS lookup
# rather than overwriting the file.
if command -v authselect >/dev/null 2>&1 && authselect current >/dev/null 2>&1; then
  authselect enable-feature with-mdns4 >/dev/null 2>&1 || :
fi
systemctl daemon-reload >/dev/null 2>&1 || :

%posttrans
fc-cache -f %{_datadir}/fonts/omarchy >/dev/null 2>&1 || :
# Lift the passwordless-sudo removal marker once no grant remains and boot
# cleanup is in place (docs/passwordless-sudo.md).
/usr/bin/omarchy-sudo-passwordless __package-installed

%files
%license LICENSE
%{_bindir}/omarchy-debug
%{_bindir}/omarchy-debug-idle
%{_bindir}/omarchy-upload-log
%{_bindir}/omarchy-sudo-passwordless
%{_bindir}/omarchy-security-functions
%dir %{_datadir}/omarchy
%dir %{_datadir}/omarchy/bin
%{_datadir}/omarchy/bin/omarchy-debug
%{_datadir}/omarchy/bin/omarchy-debug-idle
%{_datadir}/omarchy/bin/omarchy-upload-log
%{_datadir}/omarchy/bin/omarchy-sudo-passwordless
%{_datadir}/omarchy/bin/omarchy-security-functions
%{_datadir}/omarchy/etc-overrides
%{_datadir}/omarchy/config
%{_datadir}/omarchy/applications
%{_datadir}/omarchy/default
%{_datadir}/omarchy/logo.txt
%{_datadir}/omarchy/logo.svg
%{_datadir}/omarchy/icon.txt
%{_datadir}/omarchy/icon.png
%config(noreplace) %{_sysconfdir}/docker/daemon.json
%config(noreplace) %{_sysconfdir}/dracut.conf.d/omarchy.conf
%config(noreplace) %{_sysconfdir}/fastfetch/config.jsonc
%config(noreplace) %{_sysconfdir}/gnupg/dirmngr.conf
%config(noreplace) %{_sysconfdir}/limine-entry-tool.d/omarchy-defaults.conf
%config(noreplace) %{_sysconfdir}/limine-entry-tool.d/omarchy-uki.conf
%config(noreplace) %{_sysconfdir}/mise/conf.d/omarchy.toml
%config(noreplace) %{_sysconfdir}/modprobe.d/omarchy-usb-autosuspend.conf
%config(noreplace) %{_sysconfdir}/NetworkManager/conf.d/omarchy-wifi-powersave.conf
%config(noreplace) %{_sysconfdir}/profile.d/omarchy.sh
%config(noreplace) %{_sysconfdir}/sddm.conf.d/10-theme.conf
%config(noreplace) %{_sysconfdir}/sddm.conf.d/10-wayland.conf
%config(noreplace) %{_sysconfdir}/sudoers.d/omarchy-dns
%config(noreplace) %{_sysconfdir}/sudoers.d/omarchy-passwd-tries
%config(noreplace) %{_sysconfdir}/sudoers.d/omarchy-theme-browser
%config(noreplace) %{_sysconfdir}/sudoers.d/omarchy-tzupdate
%config(noreplace) %{_sysconfdir}/sysctl.d/90-omarchy-file-watchers.conf
%config(noreplace) %{_sysconfdir}/sysctl.d/99-omarchy-sysctl.conf
%config(noreplace) %{_sysconfdir}/systemd/logind.conf.d/10-ignore-power-button.conf
%config(noreplace) %{_sysconfdir}/systemd/logind.conf.d/20-inhibit-delay.conf
%config(noreplace) %{_sysconfdir}/systemd/oomd.conf.d/10-omarchy.conf
%config(noreplace) %{_sysconfdir}/systemd/resolved.conf.d/10-disable-multicast.conf
%config(noreplace) %{_sysconfdir}/systemd/resolved.conf.d/20-docker-dns.conf
%config(noreplace) %{_sysconfdir}/systemd/system.conf.d/10-faster-shutdown.conf
%config(noreplace) %{_sysconfdir}/systemd/system.conf.d/20-omarchy-nofile.conf
%config(noreplace) %{_sysconfdir}/systemd/system/cups-browsed.service.d/10-omarchy.conf
%config(noreplace) %{_sysconfdir}/systemd/system/docker.service.d/no-block-boot.conf
%config(noreplace) %{_sysconfdir}/systemd/system/plocate-updatedb.service.d/ac-only.conf
%config(noreplace) %{_sysconfdir}/systemd/system/user@.service.d/10-faster-shutdown.conf
%config(noreplace) %{_sysconfdir}/systemd/user.conf.d/20-omarchy-nofile.conf
%config(noreplace) %{_sysconfdir}/sysusers.d/omarchy-cups-browsed.conf
%config(noreplace) %{_sysconfdir}/tmpfiles.d/omarchy-nopasswd-sudo.conf
%config(noreplace) %{_sysconfdir}/tmpfiles.d/omarchy-zswap.conf
%config(noreplace) %{_sysconfdir}/udev/rules.d/60-omarchy-io-scheduler.rules
%config(noreplace) %{_sysconfdir}/xdg/kitty/kitty.conf
%config(noreplace) %{_sysconfdir}/snapper/config-templates/omarchy
%{_sysconfdir}/fonts/conf.d/50-omarchy.conf
%config(noreplace) %{_sysconfdir}/skel/.config
%config(noreplace) %{_sysconfdir}/skel/.local/share/applications
%config(noreplace) %{_sysconfdir}/skel/.local/share/nautilus-python
%config(noreplace) %{_sysconfdir}/skel/.local/state/omarchy/toggles
%dir %{_sysconfdir}/skel/.local
%dir %{_sysconfdir}/skel/.local/share
%dir %{_sysconfdir}/skel/.local/state
%dir %{_sysconfdir}/skel/.local/state/omarchy
%{_datadir}/uwsm/env.d/10-omarchy
%{_prefix}/lib/environment.d/*.conf
%{_datadir}/fontconfig/conf.avail/50-omarchy.conf
%{_datadir}/xdg-terminal-exec/*.list
%{_datadir}/applications/mimeapps.list
%{_userunitdir}/*.service
%{_userunitdir}/app.slice.d/10-oomd.conf
%{_prefix}/lib/systemd/system-sleep/unmount-fuse
%{_prefix}/lib/systemd/zram-generator.conf.d/90-omarchy.conf
%{_unitdir}/plocate-updatedb.service.d/10-omarchy.conf
%{_datadir}/fonts/omarchy
%{_datadir}/sddm/themes/omarchy
%{_datadir}/sddm/hyprland.lua
%{_datadir}/wayland-sessions/omarchy.desktop
%{_datadir}/plymouth/themes/omarchy
%{_datadir}/icons/hicolor/*/apps/*
%{_datadir}/pixmaps/omarchy.png

%changelog
* Sun Sep 27 2026 kamm3r - %{omarchy_version}-%{omarchy_release}
- Package Omadora's system files and user defaults for Fedora.
