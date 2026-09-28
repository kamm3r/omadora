echo "Keep kernel-install on /boot and register every kernel with Limine"

# limine-entry-tool keeps its kernel copies in <ESP>/<machine-id>/, and without
# a layout kernel-install reads that directory as a Boot Loader Specification
# layout on the ESP. New kernels then skip /boot, where Limine's image rebuilds
# look for them, and fill the ESP with copies nothing boots. Pin Fedora's /boot
# layout, register kernels with Limine from kernel-install, and clear what the
# ESP layout already left there.
limine_config=/etc/default/limine
machine_id_file=/etc/machine-id
kernel_install_conf=/etc/kernel/install.conf
limine_plugin=/etc/kernel/install.d/96-limine.install
install_command=/usr/bin/install
rm_command=/usr/bin/rm
cmp_command=/usr/bin/cmp

as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

# Only a Limine install has the machine-id directory that misleads kernel-install.
[[ -f $limine_config ]] || exit 0

shipped_conf="$OMARCHY_PATH/install/fedora/kernel-install.conf"
if [[ -e $kernel_install_conf ]] && ! "$cmp_command" -s "$shipped_conf" "$kernel_install_conf"; then
  echo "Leaving your $kernel_install_conf in place. Limine needs layout=other and BOOT_ROOT=/boot there."
else
  as_root "$install_command" -D -m 0644 "$shipped_conf" "$kernel_install_conf"
fi
as_root "$install_command" -D -m 0755 "$OMARCHY_PATH/install/fedora/limine.install" "$limine_plugin"

esp=$(sed -n 's/^ESP_PATH=["'\'']\?\([^"'\'']*\).*/\1/p' "$limine_config" | tail -n 1)
machine_id=$(<"$machine_id_file")
if [[ $esp != /* || ! $machine_id =~ ^[0-9a-f]{32}$ || ! -d $esp/$machine_id ]]; then
  exit 0
fi

# Per-version entry directories and the rescue image hold a BLS "linux" image.
# Limine's own kernel-* copies and limine_history beside them stay.
for entry_dir in "$esp/$machine_id"/*/; do
  entry_dir=${entry_dir%/}
  [[ ${entry_dir##*/} != kernel-* && -f $entry_dir/linux && ! -L $entry_dir ]] || continue
  as_root "$rm_command" -rf -- "$entry_dir"
done

# When the ESP is /boot itself, loader/entries is where Fedora's GRUB reads its
# entries, so only an ESP mounted elsewhere drops the ones kernel-install wrote.
if [[ $esp != /boot ]]; then
  for loader_entry in "$esp/loader/entries/$machine_id-"*.conf; do
    [[ -f $loader_entry && ! -L $loader_entry ]] || continue
    as_root "$rm_command" -f -- "$loader_entry"
  done
fi
