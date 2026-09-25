if omarchy-hw-framework16; then
  # qmk-hid (Framework 16 RGB control) has no Fedora RPM; fetch the upstream
  # binary from https://github.com/FrameworkComputer/qmk_hid. The udev rules
  # in install/hardware/framework/qmk-hid.sh still apply once it is installed.
  echo "Framework 16 detected: install qmk-hid from upstream for keyboard RGB control." >&2
fi
