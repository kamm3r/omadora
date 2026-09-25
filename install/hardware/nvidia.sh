if lspci | grep -qi 'nvidia'; then
  # Fedora builds NVIDIA modules with akmods against kernel-devel (RPM Fusion
  # prerequisite; see install/fedora/repos.sh).
  omarchy-pkg-add kernel-devel

  if omarchy-hw-nvidia-gsp; then
    PACKAGES=(akmod-nvidia xorg-x11-drv-nvidia-libs libva-nvidia-driver)
  elif omarchy-hw-nvidia-without-gsp; then
    # Legacy branch for pre-GSP GPUs.
    PACKAGES=(akmod-nvidia-470xx xorg-x11-drv-nvidia-470xx-libs)
  fi

  # Bail if no supported GPU
  if [[ -z ${PACKAGES+x} ]]; then
    echo "No compatible driver for your NVIDIA GPU. See: https://rpmfusion.org/Howto/NVIDIA"
    exit 0
  fi

  omarchy-pkg-add "${PACKAGES[@]}"

  # Per-session Hyprland NVIDIA env vars are handled by default/hypr/nvidia.lua.

  # Configure modprobe for early KMS
  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
EOF

  # Configure dracut for early loading (rebuilt by limine-mkinitcpio).
  mkdir -p /etc/dracut.conf.d
  cat > /etc/dracut.conf.d/nvidia.conf <<'EOF'
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF
fi
