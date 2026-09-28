echo "Install Monologue, the webcam recorder"

# Fedora port: monologue has no RPM yet (tracked as #monologue in
# install/omarchy-base.packages until an omadora COPR ships it). Install where
# available, otherwise leave it for the source build.
if [[ ! -f $HOME/.local/state/omarchy/preinstalls-removed ]] &&
  dnf list --quiet available monologue 2>/dev/null | awk 'NR>1 {found=1} END {exit !found}'; then
  omarchy-pkg-add monologue
fi
