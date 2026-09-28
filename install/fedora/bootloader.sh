# Install the Limine bootloader stack on Fedora.
#
# Strategy (per project decision): limine itself comes from the terra repo;
# the companion tools have no RPMs and are built from source; initramfs images
# are built with dracut behind a limine-mkinitcpio compatibility shim, so
# every existing caller (`omarchy-hibernation-setup`, hardware quirks,
# `omarchy-refresh-limine`) keeps working unchanged.
set -e

if (( EUID != 0 )); then
  echo "Re-run as root (or via omarchy provisioning)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMADORA_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

# 1. Limine bootloader binaries from terra.
dnf install -y limine

# 2. dracut is the Fedora initramfs builder (already in @core, ensured here).
dnf install -y dracut

# 3. Companion tools built from source into /usr/local (no RPMs exist):
#      limine-entry-tool  - kernel cmdline drop-ins + ESP entry management
#      limine-snapper-sync - snapper snapshot -> limine boot entries
#    Upstream sources:
#      https://github.com/omacom/omarchy (limine-entry-tool.d format,
#        limine-snapper-* scripts under default/ and install/)
#    Build them with the same recipe used for this machine's working set and
#    verify each binary responds before continuing.
for tool in limine-entry-tool limine-snapper-sync limine-snapper-restore; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing $tool: build it from source into /usr/local/bin first (see FEDORA.md)." >&2
    exit 1
  fi
done

# 4. dracut-backed limine-mkinitcpio shim: same name and contract as the Arch
#    limine-mkinitcpio-hook helper (rebuild images, sync ESP, update entries),
#    implemented with dracut per installed kernel. Plus a limine-update shim
#    (re-deploy the bootloader binaries, like Arch's limine-entry-tool
#    package helper) so refresh/factory-reset/provisioning keep working.
#    kernel-install keeps Fedora's /boot layout, builds each image at its
#    /boot path, and registers every kernel it adds or removes with Limine,
#    the job the Arch hook does from pacman.
install -m 0755 "$OMADORA_ROOT/install/fedora/limine-mkinitcpio" /usr/local/bin/limine-mkinitcpio
install -m 0755 "$OMADORA_ROOT/install/fedora/limine-update" /usr/local/bin/limine-update
install -D -m 0644 "$OMADORA_ROOT/install/fedora/kernel-install.conf" /etc/kernel/install.conf
install -D -m 0755 "$OMADORA_ROOT/install/fedora/dracut.install" /etc/kernel/install.d/50-dracut.install
install -D -m 0755 "$OMADORA_ROOT/install/fedora/limine.install" /etc/kernel/install.d/96-limine.install

# 5. Ship the default limine config and entry-tool defaults on first install.
if [[ ! -f /boot/limine.conf ]]; then
  install -m 0644 "$OMADORA_ROOT/default/limine/limine.conf" /boot/limine.conf
fi
mkdir -p /etc/limine-entry-tool.d
install -m 0644 "$OMADORA_ROOT/etc/limine-entry-tool.d/omarchy-defaults.conf" /etc/limine-entry-tool.d/omarchy-defaults.conf

# 6. Base dracut config (plymouth, btrfs, systemd initramfs defaults).
mkdir -p /etc/dracut.conf.d
install -m 0644 "$OMADORA_ROOT/etc/dracut.conf.d/omarchy.conf" /etc/dracut.conf.d/omarchy.conf

# 7. Snapper integration service (unit files ship with the source-built tools).
systemctl enable --now snapper-cleanup.timer limine-snapper-sync.service >/dev/null 2>&1 || true

limine-mkinitcpio
