pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as R

// Adapter: Caelestia's Notifs interface over Ryoku's notification server.
// Only one process can own org.freedesktop.Notifications and Ryoku's shell
// already does, so instead of starting Caelestia's server this mirrors every
// notification Ryoku tracks into Caelestia's own NotifData (the sidebar's
// model). Dismissing one here dismisses it in Ryoku too (NotifData.close()
// calls notification.dismiss()). Popups stay Ryoku's, so `popup` is never set.
Singleton {
    id: root

    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed)
    readonly property list<NotifData> popups: []
    readonly property bool loaded: true

    // Do not disturb is Ryoku's flag.
    property bool dnd: R.Flags.dnd
    onDndChanged: if (R.Flags.dnd !== dnd) R.Flags.dnd = dnd

    function sync(): void {
        const wrapped = new Set(root.list.map(n => n.notification));
        const added = [];
        for (const n of R.Notifs.tracked) {
            if (!n || wrapped.has(n))
                continue;
            const at = R.Notifs.arrivalMs[n.id];
            added.push(notifComp.createObject(root, {
                notification: n,
                time: at ? new Date(at) : new Date()
            }));
        }
        if (added.length)
            root.list = [...added.sort((a, b) => b.time - a.time), ...root.list];
    }

    Component.onCompleted: sync()

    Connections {
        target: R.Notifs
        function onTrackedChanged(): void {
            root.sync();
        }
    }

    Component {
        id: notifComp

        NotifData {}
    }
}
