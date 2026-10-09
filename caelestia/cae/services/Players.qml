pragma Singleton

import QtQml
import Quickshell
import Quickshell.Services.Mpris
import Caelestia.Config
import shell.services as R

// Adapter: Caelestia's Players minus its global shortcuts, IPC handler and
// now-playing toasts (Ryoku owns media keys and notifications). The default
// player is the one Ryoku's bar shows, so the panel and the bar agree.
Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: manualActive ?? list.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? R.Media.player ?? list[0] ?? null
    property MprisPlayer manualActive

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.values.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;

        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            // Fallback for youtube
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }
}
