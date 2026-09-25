# MIPI camera support for Intel IPU7 hardware.
#
# intel-ipu7-camera has no Fedora RPM; recent Fedora kernels carry in-tree IPU7
# support, so check the camera works before reviving this (out-of-tree DKMS
# from https://github.com/intel/ipu7-drivers as a last resort).
#
# if grep -q "OVTI08F4" /sys/bus/acpi/devices/*/hid 2>/dev/null; then
#   omarchy-pkg-add intel-ipu7-camera
# fi
true
