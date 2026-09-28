echo "Enable Omadora COPR and install the new Fedora base packages"

repo_id="copr:copr.fedorainfracloud.org:kammer:omadora"
if ! dnf -q repolist --enabled | awk -v id="$repo_id" 'NR > 1 && $1 == id { found = 1 } END { exit !found }'; then
  if (( EUID == 0 )); then
    dnf copr enable -y kammer/omadora
  else
    sudo dnf copr enable -y kammer/omadora
  fi
fi

omarchy-pkg-add aether owe owe-lockfeed tobi-try ttfx
if [[ ! -f $HOME/.local/state/omarchy/preinstalls-removed ]]; then
  omarchy-pkg-add hype monologue omacalc omacut omawrite
fi
