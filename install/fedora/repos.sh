# Enable the third-party dnf repositories Omadora needs on Fedora, then refresh
# metadata. Run before any omarchy-pkg-add step (install order: repos ->
# packages -> config -> hardware).
#
# Repos:
#   terra                      - limine, mise, usage-cli, usage-cli, localsend-bin,
#                                uwsm, golang-github-jesseduffield-lazygit,
#                                asusctl, broadcom-wl, akmod-wl, xpadneo,
#                                v4l2-relayd
#   lionheartp/Hyprland (COPR) - hyprland, hyprpicker, hyprsunset,
#                                hyprland-guiutils, xdg-desktop-portal-hyprland,
#                                quickshell
#   kammer/omadora (COPR)      - Omadora and ported Omarchy applications
#   RPM Fusion free + nonfree  - codecs/ffmpeg, obs-studio, intel-media-driver,
#                                akmod-nvidia, libva-intel-driver, sunshine,
#                                v4l2loopback (akmod)
set -e

if (( EUID != 0 )); then
  echo "Re-run as root (or via omarchy provisioning): dnf config-manager needs it." >&2
  exit 1
fi

dnf install -y dnf-plugins-core

# Terra (Fedora extra packages, signed)
if [[ ! -f /etc/yum.repos.d/terra.repo ]]; then
  dnf install -y --nogpgcheck \
    https://repos.fyralabs.com/terra$(rpm -E %fedora)/terra-release.rpm
fi

# Hyprland COPR (hyprland stack + quickshell)
if [[ ! -f /etc/yum.repos.d/_copr_copr.fedorainfracloud.org_lionheartp_Hyprland.repo ]]; then
  dnf copr enable -y lionheartp/Hyprland
fi

if [[ ! -f /etc/yum.repos.d/_copr_copr.fedorainfracloud.org_kammer_omadora.repo ]]; then
  dnf copr enable -y kammer/omadora
fi

# RPM Fusion (codecs, drivers). The release RPMs match the running Fedora
# version, so they keep working across upgrades.
if [[ ! -f /etc/yum.repos.d/rpmfusion-free.repo ]]; then
  dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

dnf makecache --refresh

# Flathub for per-user Flatpak installs. This is user state
# (~/.local/share/flatpak), so it must run as the login user, never root:
# when provisioning runs this script as root, drop to the target user.
flathub_user="${SUDO_USER:-$USER}"
if (( EUID == 0 )) && [[ -n ${SUDO_USER:-} ]]; then
  sudo -u "$flathub_user" flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
elif (( EUID != 0 )); then
  flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
else
  echo "Running as root with no SUDO_USER: skipping per-user Flathub remote (each user gets it on first Flatpak install)." >&2
fi
