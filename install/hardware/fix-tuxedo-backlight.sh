# Install Tuxedo drivers for keyboard backlighting on Tuxedo laptops and
# compatible devices like the Slimbook Executive (Clevo/Tuxedo chassis).
if cat /sys/class/dmi/id/sys_vendor 2>/dev/null | grep -qi "TUXEDO\|Slimbook"; then
  # tuxedo-drivers has no Fedora RPM; Tuxedo publishes its own Fedora
  # repository (see https://www.tuxedocomputers.com/en/Infos/Help-and-Support).
  # The blacklist below still applies once their driver is installed.
  echo "Tuxedo/Slimbook detected: install tuxedo-drivers from the vendor Fedora repo for keyboard backlighting." >&2

  # Blacklist the legacy clevo_xsm_wmi module which conflicts with the tuxedo-drivers
  # clevo_wmi module. When clevo_xsm_wmi loads first, it grabs the Clevo WMI GUIDs,
  # preventing tuxedo-drivers from initializing the keyboard backlight properly.
  mkdir -p /etc/modprobe.d
  echo "blacklist clevo_xsm_wmi" > /etc/modprobe.d/blacklist-clevo-xsm-wmi.conf

  # Remove any orphaned clevo_xsm_wmi module files not managed by a package
  for f in /lib/modules/*/extra/clevo-xsm-wmi.ko; do
    if [[ -f $f ]]; then
      rm "$f"
    fi
  done
fi
