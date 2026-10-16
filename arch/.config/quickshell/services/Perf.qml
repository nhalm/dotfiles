pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpu: 0
    property var cores: []
    property var history: []
    property var memHistory: []
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real uptime: 0
    property string load: ""
    property real diskUsed: 0
    property real diskTotal: 0
    property var processes: []
    property string sort: "cpu"
    property bool detailed: false

    property var prev: []

    function parse(text) {
        const lines = text.split("\n").filter(l => l.trim() !== "");
        const samples = [];
        const mem = {};
        for (const l of lines) {
            if (l.startsWith("cpu")) {
                const n = l.trim().split(/\s+/).slice(1, 9).map(Number);
                samples.push({ idle: n[3] + n[4], total: n.reduce((a, b) => a + b, 0) });
                continue;
            }
            const m = /^(\w+):\s+(\d+) kB/.exec(l);
            if (m)
                mem[m[1]] = Number(m[2]) * 1024;
        }

        if (root.prev.length === samples.length) {
            const usage = samples.map((s, i) => {
                const dt = s.total - root.prev[i].total;
                return dt > 0 ? (1 - (s.idle - root.prev[i].idle) / dt) * 100 : 0;
            });
            root.cpu = usage[0];
            root.cores = usage.slice(1);
            root.history = root.history.concat([usage[0]]).slice(-60);
        }
        root.prev = samples;

        root.memTotal = mem.MemTotal ?? 0;
        root.memUsed = root.memTotal - (mem.MemAvailable ?? 0);
        root.swapTotal = mem.SwapTotal ?? 0;
        root.swapUsed = root.swapTotal - (mem.SwapFree ?? 0);
        if (root.memTotal)
            root.memHistory = root.memHistory.concat([root.memUsed / root.memTotal * 100]).slice(-60);
        root.uptime = parseFloat(lines[lines.length - 2]) || 0;
        root.load = lines[lines.length - 1].split(" ").slice(0, 3).join(" ");
    }

    Process {
        id: stat
        command: ["cat", "/proc/stat", "/proc/meminfo", "/proc/uptime", "/proc/loadavg"]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: stat.running = true
    }

    Process {
        id: top
        command: ["top", "-b", "-n", "2", "-d", "0.5", "-e", "k", "-w", "512", "-o", root.sort === "cpu" ? "%CPU" : "%MEM"]
        stdout: StdioCollector {
            onStreamFinished: {
                const blocks = this.text.split(/^top - /m);
                const rows = blocks[blocks.length - 1].split("\n");
                const head = rows.findIndex(r => r.trim().startsWith("PID"));
                root.processes = rows.slice(head + 1).filter(r => r.trim() !== "").slice(0, 6).map(r => {
                    const f = r.trim().split(/\s+/);
                    return { name: f.slice(11).join(" "), cpu: Number(f[8]), memory: Number(f[5]) * 1024 };
                });
            }
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split("\n").pop().trim().split(/\s+/);
                root.diskUsed = Number(f[0]);
                root.diskTotal = Number(f[1]);
            }
        }
    }

    onSortChanged: if (detailed) top.running = true
    onDetailedChanged: if (detailed) { df.running = true; top.running = true; }

    Timer {
        interval: 3000
        running: root.detailed
        repeat: true
        onTriggered: top.running = true
    }
}
