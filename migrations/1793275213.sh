echo "Use Omarchy's power-profile drivers with Fedora service integration"

if omarchy-pkg-missing omarchy-power-profiles-daemon; then
  power_profiles_active=0
  power_profiles_enabled=0
  if systemctl is-active --quiet power-profiles-daemon.service; then
    power_profiles_active=1
  fi
  if systemctl is-enabled --quiet power-profiles-daemon.service; then
    power_profiles_enabled=1
  fi

  omarchy-pkg-add omarchy-power-profiles-daemon

  if (( power_profiles_enabled )); then
    sudo systemctl enable power-profiles-daemon.service
  fi
  if (( power_profiles_active )); then
    sudo systemctl restart power-profiles-daemon.service
  fi
fi
