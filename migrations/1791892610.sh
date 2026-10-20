echo "Update the Fedora Limine initramfs helper for restricted privileged paths"

helper=/usr/local/bin/limine-mkinitcpio
source="$OMARCHY_PATH/install/fedora/limine-mkinitcpio"

if [[ -f $helper ]] && ! cmp -s "$source" "$helper"; then
  sudo install -m 0755 "$source" "$helper"
fi
