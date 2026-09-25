echo "Enable Dell XPS 13 sidecar speaker amplifiers"

if omarchy-hw-dell-xps13-sidecar-amps; then
  # Fedora port: dell-xps13-sidecar-amps has no RPM yet, so only run where the
  # package is actually installable. The hardware leaf applies the same guard.
  if dnf list --quiet available dell-xps13-sidecar-amps 2>/dev/null | awk 'NR>1 {found=1} END {exit !found}'; then
    source "$OMARCHY_PATH/install/hardware/dell-xps13-sidecar-amps.sh"
    omarchy-state set reboot-required
  fi
fi
