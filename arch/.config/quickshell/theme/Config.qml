pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string layout: "centered"
    property var modules: ({
        left: ["Workspaces"],
        center: ["Volume", "Battery", "Clock"],
        right: ["Tray", "Notifications", "PowerMenu"]
    })

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/bar.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const cfg = JSON.parse(text());
                if (cfg.layout) root.layout = cfg.layout;
                if (cfg.modules) root.modules = cfg.modules;
            } catch (e) {
                console.log("Config: bad bar.json: " + e);
            }
        }
    }
}
