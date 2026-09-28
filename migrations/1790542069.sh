echo "Install Hype, the Markdown presentation app"

# Fedora port: hype has no RPM yet (tracked as #hype in
# install/omarchy-base.packages until an omadora COPR ships it). Install where
# available, otherwise leave it for the source build.
if [[ ! -f $HOME/.local/state/omarchy/preinstalls-removed ]] &&
  dnf list --quiet available hype 2>/dev/null | awk 'NR>1 {found=1} END {exit !found}'; then
  omarchy-pkg-add hype
fi
