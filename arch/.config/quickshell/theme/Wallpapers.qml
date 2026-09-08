pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: Quickshell.env("WALLPAPER_DIR") || (home + "/Pictures/Wallpapers")
    readonly property string script: home + "/.local/scripts/wallpaper.sh"

    property list<string> paths: []
    property string current: ""
    property string mode: "dark"
    property string previewTarget: ""

    function displayName(path: string): string {
        return path.slice(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "");
    }

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    function set(path: string): void {
        root.current = path;
        Quickshell.execDetached([root.script, path]);
    }

    function setRandom(): void {
        Quickshell.execDetached([root.script, "--random"]);
    }

    // Renders the palette the wallpaper would produce without writing any of
    // matugen's templates, so the picker can repaint itself as you scroll.
    function previewColours(path: string): void {
        if (path === root.previewTarget)
            return;
        root.previewTarget = path;
        previewProc.running = false;
        previewProc.command = ["matugen", "image", path, "-m", root.mode, "--source-color-index", "0", "--dry-run", "--json", "hex"];
        previewProc.running = true;
    }

    function stopPreview(): void {
        root.holdPreview();
        Theme.clearPreview();
    }

    // Leaves the previewed palette on screen: the wallpaper being applied will
    // regenerate the same colours, so reverting first only causes a flash.
    function holdPreview(): void {
        root.previewTarget = "";
        previewProc.running = false;
    }

    Process {
        id: lister
        command: ["bash", "-c", `find -L '${root.dir}' -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                const next = out === "" ? [] : out.split("\n");
                // Only publish a genuinely different list: reassigning the model
                // resets any view bound to it.
                if (next.length !== root.paths.length || next.some((p, i) => p !== root.paths[i]))
                    root.paths = next;
            }
        }
    }

    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    const flat = {};
                    for (const key in data.colors)
                        flat[key] = data.colors[key].default.color;
                    Theme.applyPreview(flat);
                } catch (e) {
                    console.log("Wallpapers: bad matugen preview: " + e);
                }
            }
        }
    }

    FileView {
        path: root.home + "/.local/state/wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.current = text().trim()
    }

    FileView {
        path: root.home + "/.local/state/matugen/mode"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.mode = text().trim() || "dark"
    }

    Component.onCompleted: refresh()
}
