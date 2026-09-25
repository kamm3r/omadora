# Driver for the Motorcomm YT6801 ethernet adapter used by the Slimbook Executive.
#
# yt6801-dkms has no Fedora RPM; check whether the running kernel already
# drives the adapter before reviving this (out-of-tree DKMS from upstream
# GitHub as a last resort, built against kernel-devel).
#
# if lspci | grep -i "YT6801\|Motorcomm.*Ethernet"; then
#   omarchy-pkg-add kernel-devel yt6801-dkms
# fi
true
