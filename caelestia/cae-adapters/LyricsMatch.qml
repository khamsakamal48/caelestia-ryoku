pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Services

// Fallback for Caelestia's lyrics lookup on messy metadata. Caelestia's Lyrics
// service matches LRCLIB/NetEase by artist and title, which works for music
// players but not for browsers playing YouTube: they report the channel as the
// artist ("Universal Music India") and the whole video title ("SONG (with X)
// ARTIST | CREDITS | ... Lyrical"). When Caelestia's own lookup ends with
// nothing, this searches LRCLIB once with the cleaned title, takes the synced
// result whose length is closest to the track's, and hands that clean
// artist/title back to Caelestia's Lyrics, so its loading, cache, offsets and
// candidate picker all work as usual. Only the cleaned title is sent, to the
// same LRCLIB that Caelestia already queries. Matches are kept in
// $XDG_STATE_HOME/caelestia/lyrics_match.json, so a known track resolves at once
// instead of waiting for Caelestia's own lookup to fail first.
Singleton {
    id: root

    property string rawKey
    property string rawTitle
    property real rawLength
    property bool fallbackTried
    // rawKey -> clean match (persisted), or null when the search found nothing (this session only).
    property var resolved: ({})

    // Called from inside Caelestia's LyricList binding; defer so this function's
    // own property reads and writes aren't recorded as that binding's dependencies.
    function setTrack(artist: string, title: string, album: string, length: real): void {
        Qt.callLater(root.apply, artist, title, album, length);
    }

    function clearTrack(): void {
        Qt.callLater(root.clear);
    }

    function apply(artist: string, title: string, album: string, length: real): void {
        const key = `${artist}\u0000${title}`;
        if (key === rawKey)
            return; // the caller re-binds on any metadata change; keep a resolved match
        rawKey = key;
        rawTitle = title;
        rawLength = length;
        const hit = resolved[key];
        fallbackTried = hit !== undefined;
        if (hit)
            Lyrics.setTrack(hit.artist, hit.title, hit.album, hit.duration);
        else
            Lyrics.setTrack(artist, title, album, length);
    }

    function clear(): void {
        rawKey = "";
        Lyrics.clearTrack();
    }

    // Strip YouTube-style decoration: credit lists after " | ", tags such as
    // (Official Video) / [Lyrical], and trailing "Lyrical", "Lyrics", "Audio"...
    function clean(title: string): string {
        let t = title.split(" | ")[0];
        t = t.replace(/[\(\[][^\)\]]*(official|lyric|video|audio|visuali[sz]er|full song|4k|hd)[^\)\]]*[\)\]]/gi, "");
        t = t.replace(/\b(official (music )?video|lyrical|lyric video|lyrics|full (video )?song|audio)\b/gi, "");
        return t.replace(/\s+/g, " ").replace(/^[\s|-]+|[\s|-]+$/g, "");
    }

    function search(key: string, attempt: int): void {
        const query = clean(rawTitle);
        if (!query)
            return;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || key !== root.rawKey)
                return;
            if (xhr.status === 503 || xhr.status === 429) {
                // LRCLIB sheds load with 503; one retry.
                if (attempt === 0)
                    retry.start();
                return;
            }
            let results = [];
            try {
                results = xhr.status === 200 ? JSON.parse(xhr.responseText) : [];
            } catch (e) {}
            const synced = results.filter(r => r.syncedLyrics);
            const gap = r => Math.abs((r.duration ?? 0) - root.rawLength);
            const best = synced.sort((a, b) => gap(a) - gap(b))[0];
            // Without a known length take the top hit; with one, insist on a close match.
            const ok = best && (!(root.rawLength > 0) || gap(best) <= 5);
            const hit = ok ? {
                artist: best.artistName,
                title: best.trackName,
                album: best.albumName ?? "",
                duration: best.duration
            } : null;
            const next = Object.assign({}, root.resolved);
            next[key] = hit;
            root.resolved = next;
            if (hit) {
                Lyrics.setTrack(hit.artist, hit.title, hit.album, hit.duration);
                root.save();
            }
        };
        xhr.open("GET", `https://lrclib.net/api/search?q=${encodeURIComponent(query)}`);
        xhr.send();
    }

    function save(): void {
        const keep = {};
        for (const [k, v] of Object.entries(root.resolved))
            if (v)
                keep[k] = v;
        store.setText(JSON.stringify(keep));
    }

    FileView {
        id: store

        path: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/caelestia/lyrics_match.json`
        printErrors: false
        blockLoading: true // known matches must be there before the first lookup
        onLoaded: {
            try {
                root.resolved = Object.assign(JSON.parse(text()), root.resolved);
            } catch (e) {}
            // A track requested before the file was read still gets its match.
            const hit = root.rawKey ? root.resolved[root.rawKey] : undefined;
            if (hit && !Lyrics.hasLyrics) {
                root.fallbackTried = true;
                Lyrics.setTrack(hit.artist, hit.title, hit.album, hit.duration);
            }
        }
    }

    Timer {
        id: retry

        interval: 2000
        onTriggered: root.search(root.rawKey, 1)
    }

    Connections {
        target: Lyrics

        function onLoadingChanged(): void {
            if (Lyrics.loading || Lyrics.hasLyrics || root.fallbackTried || !root.rawKey)
                return;
            root.fallbackTried = true;
            root.search(root.rawKey, 0);
        }
    }
}
