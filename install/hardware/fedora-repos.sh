# Hardware-specific third-party repository extensions. Runs at the end of both
# the hardware and post-install phases so repo files survive earlier steps.
#
# T2 MacBooks (Apple vendor 106b, devices 1801/1802) have no in-distro Fedora
# support; the community t2linux project is the place to look for a current
# Fedora COPR or kernel build. Nothing is enabled automatically: an untrusted
# kernel repo must be the owner's explicit choice.
if lspci -nn | grep "106b:180[12]" >/dev/null; then
  echo "T2 Mac detected: see https://github.com/t2linux/fedora-kernel for community Fedora support." >&2
fi
