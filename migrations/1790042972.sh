echo "Install Elsewhen, the world clock plugin"

# Fedora port: elsewhen has no RPM yet (tracked as #elsewhen in
# install/omarchy-base.packages). Install where available; the plugin-link and
# bar-placement steps below are safe to run regardless.
if dnf list --quiet available elsewhen 2>/dev/null | awk 'NR>1 {found=1} END {exit !found}'; then
  omarchy-pkg-add elsewhen
else
  echo "Elsewhen package not available on Fedora yet; configuring placement only."
fi

packaged_plugin="/usr/share/omarchy/shell/plugins/omacom.elsewhen"
user_plugin="$HOME/.config/omarchy/plugins/omacom.elsewhen"

# The package moved from plugins/ to shell/plugins/ once, stranding the link an
# earlier run made to the old path. A link the user made is left alone.
if [[ -L $user_plugin && ! -e $user_plugin && $(readlink "$user_plugin") == /usr/share/omarchy/* && -d $packaged_plugin ]]; then
  ln -sfn "$packaged_plugin" "$user_plugin"
fi

# Dev checkouts do not contain plugins installed by system packages.
if [[ ! $OMARCHY_PATH -ef /usr/share/omarchy && -d $packaged_plugin && ! -e $user_plugin && ! -L $user_plugin ]]; then
  mkdir -p "${user_plugin%/*}"
  ln -s "$packaged_plugin" "$user_plugin"
fi

# Best-effort, like the put below: an update whose shell cannot be asked still
# finishes, and restarts the shell once the migrations are through.
omarchy-shell -q shell rescanPlugins
omarchy-bar put omacom.elsewhen --before omarchy.clock
