# Omadora runtime package: commands, install and migration scripts, themes, and
# the Quickshell desktop. See docs/file-layout.md for the repo-to-system map and
# packaging/README.md for how the COPR builds it.
#
# Build inputs (all optional):
#   omarchy_version  RPM version; defaults to the checkout's version file
#   omarchy_release  RPM release; defaults to 1
#   dev_suffix       "-dev" builds the development variant, omarchy-dev
#   OMARCHY_SRC      environment: build from this checkout instead of Source0

%global local_src %{getenv:OMARCHY_SRC}
%if "%{local_src}" != ""
%{!?omarchy_version:%global omarchy_version %(sed -E 's/[.-]([a-z])/~\\1/' "%{local_src}/version")}
%endif
%{!?omarchy_version:%global omarchy_version 0}
%{!?omarchy_release:%global omarchy_release 1}

# Everything here is interpreted code or data; nothing to compile or strip.
%global __brp_python_bytecompile %{nil}
%global debug_package %{nil}

# Commands that must exist before this package does, or that run the
# passwordless-sudo expiry, belong to omarchy-settings.
%global settings_commands omarchy-debug omarchy-debug-idle omarchy-upload-log omarchy-sudo-passwordless omarchy-security-functions

Name:           omarchy%{?dev_suffix}
Version:        %{omarchy_version}
Release:        %{omarchy_release}%{?dist}
Summary:        Omadora, an Omarchy Hyprland desktop for Fedora
# omadora-sync is a modified copy of nobara-updater (GPL-3.0-or-later).
License:        MIT AND GPL-3.0-or-later
URL:            https://github.com/kamm3r/omadora
Source0:        omarchy-%{omarchy_version}.tar.gz
BuildArch:      noarch

Requires:       omarchy-settings%{?dev_suffix} = %{version}-%{release}
Requires:       bash
Requires:       sudo
Requires:       systemd
Requires:       dnf5
Requires:       python3
Requires:       python3-libdnf5
Requires:       gum
Requires:       jq
Requires:       util-linux

%if "%{?dev_suffix}" != ""
Provides:       omarchy = %{version}-%{release}
Conflicts:      omarchy
%else
Conflicts:      omarchy-dev
%endif

%description
The Omadora runtime: every omarchy command and omadora-sync, the install,
hardware, and migration scripts, the stock themes, and the Quickshell desktop,
installed under /usr/share/omarchy with the commands in /usr/bin.

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
install -d %{buildroot}%{_bindir} "$share/bin"

: >%{name}.files
for command in bin/*; do
  [[ -f $command ]] || continue
  name=${command##*/}
  case " %{settings_commands} " in
    *" $name "*) continue ;;
  esac
  install -m "$(stat -c '%a' "$command")" "$command" %{buildroot}%{_bindir}/"$name"
  # The canonical entrypoint is /usr/bin; OMARCHY_PATH/bin points back at it
  # so security checks that resolve the running command still match.
  ln -s %{_bindir}/"$name" "$share/bin/$name"
  printf '%%s\n' "%{_bindir}/$name" "%{_datadir}/omarchy/bin/$name" >>%{name}.files
done

cp -a install migrations themes shell version "$share/"
install -d "$share/default"
cp -a default/omadora-sync "$share/default/"

# New users start with every shipped migration already applied.
install -d %{buildroot}%{_sysconfdir}/skel/.local/state/omarchy/migrations
for migration in migrations/*.sh; do
  : >%{buildroot}%{_sysconfdir}/skel/.local/state/omarchy/migrations/"${migration##*/}"
done

%files -f %{name}.files
%license LICENSE
%license default/omadora-sync/LICENSE
%doc README.md FEDORA.md
%dir %{_datadir}/omarchy
%dir %{_datadir}/omarchy/bin
%{_datadir}/omarchy/install
%{_datadir}/omarchy/migrations
%{_datadir}/omarchy/themes
%{_datadir}/omarchy/shell
%{_datadir}/omarchy/version
%dir %{_datadir}/omarchy/default
%{_datadir}/omarchy/default/omadora-sync
%dir %{_sysconfdir}/skel/.local
%dir %{_sysconfdir}/skel/.local/state
%dir %{_sysconfdir}/skel/.local/state/omarchy
%config(noreplace) %{_sysconfdir}/skel/.local/state/omarchy/migrations

%changelog
* Sun Sep 27 2026 kamm3r - %{omarchy_version}-%{omarchy_release}
- Package the Omadora runtime for Fedora.
