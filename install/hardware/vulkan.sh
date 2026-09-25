# Install Vulkan drivers matching detected GPU hardware
# (NVIDIA Vulkan is handled by nvidia.sh via nvidia-utils)

declare -A VULKAN_DRIVERS=(
  [Intel]=mesa-vulkan-drivers
  [AMD]=mesa-vulkan-drivers
)

PACKAGES=()

for vendor in "${!VULKAN_DRIVERS[@]}"; do
  if lspci | grep -iE "(VGA|Display).*$vendor" > /dev/null; then
    PACKAGES+=("${VULKAN_DRIVERS[$vendor]}")
  fi
done

# Deduplicate: Intel and AMD share the mesa-vulkan-drivers package on Fedora.
# (Apple/Asahi GPUs are aarch64-only, covered by the Fedora Asahi remix.)

if (( ${#PACKAGES[@]} > 0 )); then
  omarchy-pkg-add "${PACKAGES[@]}"
fi
