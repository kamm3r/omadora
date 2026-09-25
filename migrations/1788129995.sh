echo "Replace Satty and Tensaku with Omasnap"

# Fedora port: omasnap has no RPM yet (tracked as #omasnap in
# install/omarchy-base.packages until an omadora COPR ships it). Install where
# available, otherwise leave the screenshot tooling for the source build.
if dnf list --quiet available omasnap 2>/dev/null | awk 'NR>1 {found=1} END {exit !found}'; then
  omarchy-pkg-add omasnap
fi

# The old source installer left a NoDisplay entry that overrides the packaged launcher.
rm -f "$HOME/.local/share/applications/omasnap.desktop"

imv_config="$HOME/.config/imv/config"
if [[ -f $imv_config ]]; then
  sed -i --follow-symlinks \
    -e 's/^# Edit the current image in Tensaku and quit the viewer$/# Edit the current image in Omasnap and quit the viewer/' \
    -e 's/^# Edit the current image in Satty and quit the viewer$/# Edit the current image in Omasnap and quit the viewer/' \
    -e 's|^<Ctrl+e> = exec tensaku-edit "$imv_current_file" & ; quit$|<Ctrl+e> = exec omasnap "$imv_current_file" \& ; quit|' \
    -e 's|^<Ctrl+e> = exec satty --filename "$imv_current_file" & ; quit$|<Ctrl+e> = exec omasnap "$imv_current_file" \& ; quit|' \
    "$imv_config"
fi

# satty/tensaku have no Fedora RPMs; drop where present, ignore where absent.
if ! omarchy-pkg-missing satty tensaku; then
  omarchy-pkg-drop satty tensaku || true
fi
