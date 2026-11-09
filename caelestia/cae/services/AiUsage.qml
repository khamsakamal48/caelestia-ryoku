pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import "../utils"

// AI usage for the dashboard's "AI usage" tab, from one of two sources
// (settings.source):
//   "local"  the cache Ryoku's ryoku-ai-usage collector (systemd timer, every
//            5 min) writes to ~/.cache/claude-usage.json for this machine's
//            Claude Code login;
//   "dario"  a dario proxy (github.com/askalf/dario): GET /accounts for every
//            seat in its pool, /analytics for the last hour, /analytics/ledger
//            for tokens per day. /accounts needs the proxy's API key
//            (DARIO_API_KEY); its read-only analytics token is refused there.
// Settings live in ~/.config/caelestia/ai-usage.json: Caelestia's own config
// schema is compiled into its plugin and cannot take new keys.
Singleton {
    id: root

    readonly property alias settings: settingsAdapter
    readonly property bool useDario: settingsAdapter.source === "dario"
    readonly property string darioBase: settingsAdapter.darioUrl.trim().replace(/\/+$/, "")

    // Parsed ~/.cache/claude-usage.json, or null before the first collector run.
    property var local: null

    // dario: the raw /accounts, /analytics and /analytics/ledger replies (null
    // until read), the error of the last refresh ("" when it went through) and
    // when the last good /accounts read landed.
    property var darioAccounts: null
    property var darioAnalytics: null
    property var darioLedger: null
    property string darioError: ""
    property date darioUpdated
    property int darioPending: 0
    property int darioGeneration: 0

    // dario's aliases as of the last read. Reassigned only when they change, so the
    // settings page's name fields are not rebuilt (and an edit cut short) on every poll.
    property var darioAliases: []
    // The aliases the settings page lists: dario's, or with no reading yet, the ones already named.
    readonly property var nameAliases: darioAliases.length ? darioAliases : Object.keys(settingsAdapter.darioNames ?? {})
    readonly property bool hasDarioNames: Object.keys(settingsAdapter.darioNames ?? {}).length > 0

    // One seat per row: { alias, name, email, tier, status, action, claim, util5h, util7d, resetAt (ms), requests, ageMs }.
    readonly property var accounts: (darioAccounts?.accounts ?? []).map(a => ({
                alias: a.alias,
                name: displayName(a.alias),
                email: a.accountEmail ?? "",
                tier: tierName(a.seatTier ?? a.rateLimitTier ?? ""),
                status: a.status ?? "unknown",
                action: a.action ?? "none",
                claim: a.claim ?? "",
                util5h: pct(a.util5h),
                util7d: pct(a.util7d),
                resetAt: a.resetAt ?? 0,
                requests: a.requestCount ?? 0,
                ageMs: a.utilAgeMs
            }))

    // Seats that are the same subscription under another alias count once in the pool figures.
    readonly property var distinctAccounts: {
        const seen = new Set();
        return (darioAccounts?.accounts ?? []).filter(a => {
            if (seen.has(a.alias))
                return false;
            (a.sameAccountAs ?? []).forEach(p => seen.add(p));
            return true;
        });
    }

    // What the tab and tile read, the same shape for both sources: the local
    // cache as is, or the dario pool folded into it (each limit as the mean use
    // across distinct accounts, i.e. how much of the pool's room is spent).
    readonly property var claude: useDario ? darioView : local
    readonly property bool claudeStale: useDario ? darioError !== "" && darioAccounts !== null : local?._source === "stale"
    readonly property var darioView: {
        if (!darioAccounts)
            return null;
        const accs = distinctAccounts;
        const mean = key => accs.length ? accs.reduce((s, a) => s + pct(a[key]), 0) / accs.length : 0;
        // Each seat states one reset: the window its last reply was measured against.
        const soonest = prefix => {
            const ts = accs.filter(a => (a.claim ?? "").startsWith(prefix) && a.resetAt > Date.now()).map(a => a.resetAt);
            return ts.length ? Math.floor(Math.min(...ts) / 1000) : 0;
        };
        return {
            "5h-utilization": mean("util5h"),
            "7d-utilization": mean("util7d"),
            "5h-reset": soonest("five_hour"),
            "7d-reset": soonest("seven_day"),
            updated_at: Qt.formatTime(darioUpdated, "hh:mm:ss"),
            _recent_days: ledgerDays(darioLedger)
        };
    }

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

    // The name shown for a dario account: the user's (Nexus > Dashboard > Account names) or dario's alias.
    function displayName(alias: string): string {
        return settingsAdapter.darioNames?.[alias] || alias;
    }

    // An empty name drops the entry, so the account shows its alias again.
    function setDarioName(alias: string, name: string): void {
        const names = Object.assign({}, settingsAdapter.darioNames ?? {});
        name = name.trim();
        if (name && name !== alias)
            names[alias] = name;
        else
            delete names[alias];
        if (JSON.stringify(names) !== JSON.stringify(settingsAdapter.darioNames ?? {}))
            settingsAdapter.darioNames = names;
    }

    // Forgets every custom name (including those of accounts dario no longer has)
    // and reads dario again, so the list is exactly its current aliases.
    function resetDarioNames(): void {
        settingsAdapter.darioNames = {};
        darioReset();
    }

    function formatCost(usd: real): string {
        return usd >= 100 ? `$${Math.round(usd)}` : `$${(usd || 0).toFixed(2)}`;
    }

    // "team_standard" -> "Team standard"; "default_claude_max_20x" -> "Max 20x".
    function tierName(tier: string): string {
        const t = tier.replace(/^default_(claude_)?/, "").replace(/_/g, " ").trim();
        return t ? t[0].toUpperCase() + t.slice(1) : "";
    }

    // The ledger's per-day table as the local cache's _recent_days: the last 7
    // UTC days, oldest first, all token kinds summed (thinking is part of output).
    function ledgerDays(ledger: var): var {
        const days = ledger?.days ?? {};
        const out = [];
        for (let i = 6; i >= 0; i--) {
            const date = new Date(Date.now() - i * 86400000).toISOString().slice(0, 10);
            let tokens = 0;
            for (const model of Object.values(days[date] ?? {}))
                for (const b of Object.values(model))
                    tokens += (b.inputTokens || 0) + (b.outputTokens || 0) + (b.cacheReadTokens || 0) + (b.cacheCreateTokens || 0);
            out.push({
                date,
                tokens
            });
        }
        return out;
    }

    // Local: runs the collector now instead of waiting for its timer; the cache
    // watch picks up the result. dario: reads the proxy now.
    function refresh(): void {
        if (useDario)
            darioRefresh();
        else
            collector.running = true;
    }

    function darioGet(path: string, gen: int, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || gen !== root.darioGeneration)
                return;
            let body = null, err = "";
            if (xhr.status === 200) {
                try {
                    body = JSON.parse(xhr.responseText);
                } catch (e) {
                    err = Tr.tr("not a dario reply");
                }
            } else {
                err = xhr.status === 0 ? Tr.tr("can't reach %1").arg(root.darioBase) : xhr.status === 401 || xhr.status === 403 ? Tr.tr("token refused (needs the API key)") : xhr.status === 404 ? Tr.tr("not found") : `HTTP ${xhr.status}`;
            }
            done(body, err);
            if (--root.darioPending === 0)
                root.now = Date.now();
        };
        xhr.open("GET", root.darioBase + path);
        const token = settingsAdapter.darioToken.trim();
        if (token)
            xhr.setRequestHeader("Authorization", `Bearer ${token}`);
        xhr.send();
    }

    function darioRefresh(): void {
        if (!darioBase) {
            darioError = Tr.tr("no proxy URL set");
            return;
        }
        // A newer refresh (or a changed URL/token) drops the replies of an older one.
        const gen = ++darioGeneration;
        darioPending = 3;
        darioGet("/accounts", gen, (body, err) => {
            root.darioError = err;
            if (body) {
                const aliases = (body.accounts ?? []).map(a => a.alias);
                if (aliases.join("\n") !== root.darioAliases.join("\n"))
                    root.darioAliases = aliases;
                root.darioAccounts = body;
                root.darioUpdated = new Date();
            }
        });
        // Optional extras: an older dario, or one started with --no-ledger, lacks them.
        darioGet("/analytics", gen, body => {
            if (body)
                root.darioAnalytics = body;
        });
        darioGet("/analytics/ledger", gen, body => {
            if (body)
                root.darioLedger = body;
        });
    }

    function protectSettings(): void {
        if (settingsAdapter.darioToken)
            chmod.running = true;
    }

    function darioReset(): void {
        darioGeneration++;
        darioAccounts = darioAnalytics = darioLedger = null;
        darioAliases = [];
        darioError = "";
        if (useDario)
            darioRefresh();
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // Reading dario costs it nothing upstream: these routes serve what it already holds.
    Timer {
        interval: Math.max(15, root.settings.darioInterval) * 1000
        running: root.useDario
        repeat: true
        triggeredOnStart: true
        onTriggered: root.darioRefresh()
    }

    Connections {
        target: settingsAdapter

        function onSourceChanged(): void {
            root.darioReset();
        }
        function onDarioUrlChanged(): void {
            root.darioReset();
        }
        function onDarioTokenChanged(): void {
            root.darioReset();
        }
    }

    Process {
        id: chmod

        command: ["chmod", "600", `${Paths.config}/ai-usage.json`]
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
                root.local = JSON.parse(text());
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
        // With a token in it the file holds a secret: keep it to this user (each save
        // replaces the file, and an editor may have written it).
        onSaved: root.protectSettings()
        onLoaded: root.protectSettings()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settingsAdapter

            // Dashboard badge beside the photo: the user's full name instead of the window manager.
            property bool showFullName: false
            property bool showTab: true
            property bool showTile: true
            property bool showSession: true
            property bool showWeekly: true
            property bool showDaily: true
            property bool showCountdown: true
            property int warnThreshold: 80
            // "local" (this machine's Claude Code) or "dario" (a dario proxy's account pool).
            property string source: "local"
            property string darioUrl: "http://localhost:3456"
            // The proxy's DARIO_API_KEY; sent as a bearer token. Empty for an unkeyed proxy.
            property string darioToken: ""
            // Seconds between reads of the proxy.
            property int darioInterval: 60
            // Display names for dario accounts, keyed by dario's alias: { "login": "Ops" }.
            property var darioNames: ({})
            // Tab sections only shown for dario.
            property bool showPoolStats: true
            property bool showAccounts: true
        }
    }
}
