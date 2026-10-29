# Install the Limine bootloader stack on Fedora.
#
# The bootloader and generic Fedora integration come from kammer/limine.
# Omadora owns only its defaults, branding, and dracut policy.
set -e

if (( EUID != 0 )); then
  echo "Re-run as root (or via omarchy provisioning)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMADORA_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

# Select the dedicated repository explicitly; Terra may also offer Limine.
dnf copr enable -y kammer/limine
dnf install -y --from-repo=copr:copr.fedorainfracloud.org:kammer:limine \
  limine limine-entry-tool limine-snapper-sync limine-dracut

# 1. Ship the default limine config and entry-tool defaults on first install.
if [[ ! -f /boot/limine.conf ]]; then
  install -m 0644 "$OMADORA_ROOT/default/limine/limine.conf" /boot/limine.conf
fi
mkdir -p /etc/limine-entry-tool.d
install -m 0644 "$OMADORA_ROOT/etc/limine-entry-tool.d/omarchy-defaults.conf" /etc/limine-entry-tool.d/omarchy-defaults.conf

# 2. Base dracut config (plymouth, btrfs, systemd initramfs defaults).
mkdir -p /etc/dracut.conf.d
install -m 0644 "$OMADORA_ROOT/etc/dracut.conf.d/omarchy.conf" /etc/dracut.conf.d/omarchy.conf

# 3. Snapper integration service (unit files ship with the RPM).
systemctl enable --now snapper-cleanup.timer limine-snapper-sync.service >/dev/null 2>&1 || true

/usr/bin/limine-mkinitcpio
