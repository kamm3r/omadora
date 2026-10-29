#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_quickshell "plugin registry contract test"

run_qml_fixture plugin-registry "plugin registry contract checks pass" services Commons

# Slow process startup must not leave an unwatched gap after the first scan.
qml_fixture_scratch
mkdir -p "$QML_FIXTURE_TMP/home/.config/omarchy/plugins/test.watch"
printf '%s\n' '{"schemaVersion":1,"id":"test.watch","name":"Before","version":"1","kinds":["overlay"],"entryPoints":{"overlay":"Overlay.qml"}}' \
  >"$QML_FIXTURE_TMP/home/.config/omarchy/plugins/test.watch/manifest.json"
cat >"$QML_FIXTURE_TMP/bin/inotifywait" <<'STUB'
#!/bin/bash
sleep 0.3
exec /usr/bin/inotifywait "$@"
STUB
chmod +x "$QML_FIXTURE_TMP/bin/inotifywait"
run_qml_fixture plugin-registry-watch "plugin edits after the initial scan are watched" services Commons
