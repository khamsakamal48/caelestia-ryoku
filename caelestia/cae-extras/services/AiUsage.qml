pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../utils"

// AI usage for the dashboard's "AI usage" tab. Data comes from the caches that
// Ryoku's ryoku-ai-usage collector (systemd timer, every 5 min) writes to
// ~/.cache/<provider>-usage.json; only Claude Code is read so far. Settings live
// in ~/.config/caelestia/ai-usage.json: Caelestia's own config schema is compiled
// into its plugin and cannot take new keys.
Singleton {
    id: root

    readonly property alias settings: settingsAdapter
    // Parsed ~/.cache/claude-usage.json, or null before the first collector run.
    property var claude: null
    readonly property bool claudeStale: claude?._source === "stale"
    property real now: Date.now()

    function pct(utilization: var): real {
        return Math.max(0, Math.min(1, parseFloat(utilization) || 0));
    }

    // "2d 4h", "3h 12m", "12m"; empty once the reset time has passed.
    function untilReset(resetTs: var): string {
        const s = (parseInt(resetTs) || 0) - now / 1000;
        if (s <= 0)
            return "";
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${Math.max(1, m)}m`;
    }

    function formatTokens(n: real): string {
        if (n >= 1e9)
            return `${(n / 1e9).toFixed(2)}B`;
        if (n >= 1e6)
            return `${(n / 1e6).toFixed(1)}M`;
        if (n >= 1e3)
            return `${(n / 1e3).toFixed(1)}k`;
        return String(Math.round(n));
    }

    // Runs the collector now instead of waiting for its timer; the cache watch picks up the result.
    function refresh(): void {
        collector.running = true;
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Process {
        id: collector

        command: ["systemctl", "--user", "start", "ryoku-ai-usage.service"]
    }

    FileView {
        path: `${Paths.home}/.cache/claude-usage.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.claude = JSON.parse(text());
            } catch (e) {
                // A half-written cache keeps the last good numbers on screen.
            }
        }
    }

    FileView {
        path: `${Paths.config}/ai-usage.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settingsAdapter

            property bool showTab: true
            property bool showSession: true
            property bool showWeekly: true
            property bool showDaily: true
            property bool showCountdown: true
            property int warnThreshold: 80
        }
    }
}
