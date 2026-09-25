# Enable the temporary sidecar amplifier workaround on the exact Dell XPS 13 model that needs it.
#
# dell-xps13-sidecar-amps is an Omarchy-only package with no Fedora RPM yet.
# The workaround runs only where the package is actually installable; on stock
# Fedora the leaf (and the migration sourcing it) is a silent no-op, so check
# whether the stock kernel already drives the amps before reviving this.

if omarchy-hw-dell-xps13-sidecar-amps; then
  if dnf list --quiet available dell-xps13-sidecar-amps 2>/dev/null | awk 'NR>1 {found=1} END {exit !found}'; then
    omarchy-pkg-add dell-xps13-sidecar-amps &&
      sudo dell-xps13-sidecar-amps-apply
  fi
fi
