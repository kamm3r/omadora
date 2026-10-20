echo "Preserve Voxtype as the default for existing dictation users"

backend_config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/defaults/dictation"
# Voxtype comes from the Omadora COPR as voxtype-bin, or from voxtype.io's own
# RPM named voxtype, so look for the command rather than one package name.
if [[ ! -e $backend_config ]] && omarchy-cmd-present voxtype; then
  mkdir -p "${backend_config%/*}"
  temporary=$(mktemp "$backend_config.XXXXXX")
  printf '%s\n' voxtype > "$temporary"
  mv -f "$temporary" "$backend_config"
fi
