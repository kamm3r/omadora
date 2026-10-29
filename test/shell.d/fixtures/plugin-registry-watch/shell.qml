import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
  id: root
  property bool edited: false

  function finish(ok) {
    result.setText(JSON.stringify({ ok: ok }))
  }

  FileView { id: result; path: Quickshell.env("OMARCHY_QML_TEST_RESULT"); printErrors: false }

  PluginRegistry {
    id: registry
    onScanFinished: {
      var plugin = installedPlugins["test.watch"]
      if (plugin && plugin.name === "After") {
        root.finish(true)
      } else if (!root.edited) {
        root.edited = true
        edit.running = true
      }
    }
    onLocalPluginChanged: rescan()
  }

  // Edit immediately after the initial scan, before a slow watcher could
  // attach. Watch readiness must precede the scan advertised to callers.
  Process {
    id: edit
    command: ["bash", "-c", 'sed s/Before/After/ "$1/manifest.json" >"$1/next" && mv "$1/next" "$1/manifest.json"',
              "_", registry.pluginsDir + "/test.watch"]
  }

  Timer { interval: 2500; running: true; onTriggered: root.finish(false) }
}
