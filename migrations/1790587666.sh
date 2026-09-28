echo "Build kernel boot images at their /boot path on Limine installs"

# In the /boot layout that migration 1790575242 pins, Fedora's
# 50-dracut.install hands dracut an empty output path, and dracut then picks
# <ESP>/<machine-id>/<kver>/initrd, a directory that does not exist once
# limine-entry-tool has made the machine-id one. Every kernel install stopped
# there, before its Limine entry. Replace that plugin with one that names the
# image, then finish the kernel installs it stopped.
limine_config=/etc/default/limine
dracut_plugin=/etc/kernel/install.d/50-dracut.install
modules_dir=/usr/lib/modules
boot_dir=/boot
install_command=/usr/bin/install
kernel_install_command=/usr/bin/kernel-install

as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

# Only a Limine install has the machine-id directory that misleads dracut.
[[ -f $limine_config ]] || exit 0

as_root "$install_command" -D -m 0755 "$OMARCHY_PATH/install/fedora/dracut.install" "$dracut_plugin"

for kernel_image in "$modules_dir"/*/vmlinuz; do
  [[ -f $kernel_image ]] || continue
  kernel_version=${kernel_image%/vmlinuz}
  kernel_version=${kernel_version##*/}
  [[ -f $boot_dir/initramfs-$kernel_version.img ]] && continue
  echo "Finishing the install of kernel $kernel_version"
  as_root "$kernel_install_command" add "$kernel_version" "$kernel_image"
done
