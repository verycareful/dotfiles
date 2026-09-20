// Notification server + model. One group per app; each group keeps a collapsed flag;
// each notification carries read/unread. Popups are a separate short-lived list.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    // ── config ───────────────────────────────────────────────
    readonly property var  ignoredApps:   [/spotify/i]       // never shown anywhere
    readonly property int  popupTimeout:  8000
    readonly property int  popupTimeoutLow: 5000
    readonly property int  maxPopups:     5

    // ── state ────────────────────────────────────────────────
    property var  groups: []          // [Group], newest app first
    property var  popups: []          // [Entry], newest last
    property bool centerOpen: false
    property bool dnd: false
    property int  unread: 0
    property date now: new Date()

    component Entry: QtObject {
        required property var n           // the Notification
        property bool read: false
        property date time: new Date()
        property bool popupShown: false
        property string replyText: ""
    }
    component Group: QtObject {
        required property string app
        property string icon: ""
        property bool collapsed: false
        property var items: []            // [Entry], newest first
        readonly property int count: items.length
        readonly property int unreadCount: items.filter(i => !i.read).length
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: false
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: n => {
            if (root.ignoredApps.some(re => re.test(n.appName) || re.test(n.desktopEntry))) return
            n.tracked = true
            const item = itemComp.createObject(root, { n: n, read: n.lastGeneration })   // re-emitted after a reload: no popup, keep quiet
            n.closed.connect(() => root.remove(item))

            let g = root.groups.find(g => g.app === root.appKey(n))
            if (!g) {
                g = groupComp.createObject(root, { app: root.appKey(n), icon: root.iconName(n) })
                root.groups = [g].concat(root.groups)
            } else {
                // newest group to the top, keep its collapsed state
                root.groups = [g].concat(root.groups.filter(x => x !== g))
            }
            g.items = [item].concat(g.items)
            if (!g.icon) g.icon = root.iconName(n)

            if (!root.dnd && !root.centerOpen && !n.lastGeneration) {
                item.popupShown = true
                root.popups = root.popups.concat([item]).slice(-root.maxPopups)
            }
            root.refresh()
        }
    }
    Component { id: itemComp; Entry {} }
    Component { id: groupComp; Group {} }

    function appKey(n) { return n.appName || n.desktopEntry || "app" }
    // icon name for a notification: what it sent, else its desktop entry, else its name (firefox, spotify…)
    function iconName(n) {
        for (const c of [n.appIcon, n.desktopEntry, (n.appName || "").toLowerCase()])
            if (c && Quickshell.hasThemeIcon(c)) return c
        return n.appIcon || "dialog-information"      // may be a path
    }
    function iconFor(n) { return Quickshell.iconPath(iconName(n), "dialog-information") }

    // ── actions ──────────────────────────────────────────────
    function markRead(item) {
        if (!item.read) { item.read = true; refresh() }
    }
    function dismiss(item) {          // right/middle click, or the app closed it
        remove(item)
        item.n.dismiss()
    }
    function remove(item) {
        for (const g of groups) {
            if (g.items.includes(item)) {
                g.items = g.items.filter(x => x !== item)
                break
            }
        }
        groups = groups.filter(g => g.items.length > 0)
        hidePopup(item)
        refresh()
    }
    function hidePopup(item) {
        if (popups.includes(item)) popups = popups.filter(x => x !== item)
    }
    function closeGroup(g) {
        const items = g.items.slice()
        g.items = []
        groups = groups.filter(x => x !== g)
        for (const i of items) { hidePopup(i); i.n.dismiss() }
        refresh()
    }
    function toggleGroup(g) { g.collapsed = !g.collapsed }
    function clearAll() {
        for (const g of groups.slice()) closeGroup(g)
    }
    function markAllRead() {
        for (const g of groups) for (const i of g.items) i.read = true
        refresh()
    }
    function invoke(item, action) {   // action button: run it, keep the notification
        action.invoke()
        markRead(item)
    }
    function reply(item, text) {
        if (text.length === 0) return
        item.n.sendInlineReply(text)
        item.replyText = ""
        markRead(item)
    }

    function toggleCenter() { setCenter(!centerOpen) }
    function setCenter(open) {
        if (open) Panel.setOpen(false)
        centerOpen = open
        if (open) popups = []          // the centre shows everything; popups are redundant
    }
    function setDnd(on) {
        dnd = on
        if (on) popups = []
        dndFile.setText(on ? "1" : "0")
        refresh()
    }

    function refresh() {
        let u = 0
        for (const g of groups) for (const i of g.items) if (!i.read) u++
        unread = u
        groups = groups.slice()        // new array → views re-evaluate
        barSignal.restart()
    }

    // ── bar + persistence + clock ────────────────────────────
    // waybar's custom/notifications module re-runs `qs ipc call notifs status` on RTMIN+9
    Timer { id: barSignal; interval: 50; onTriggered: Quickshell.execDetached(["pkill", "-RTMIN+9", "waybar"]) }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = new Date() }

    FileView {
        id: dndFile
        path: Quickshell.statePath("dnd")     // $XDG_STATE_HOME/quickshell/…
        blockLoading: true
        printErrors: false
        onLoaded: root.dnd = text().trim() === "1"
    }

    function status() {
        const state = dnd ? (unread > 0 ? "dnd-unread" : "dnd") : (unread > 0 ? "unread" : "none")
        return JSON.stringify({
            text: unread > 0 ? String(unread) : "",
            alt: state, class: state,
            tooltip: (dnd ? "Do not disturb · " : "") + unread + " unread"
        })
    }

    IpcHandler {
        target: "notifs"
        function toggle(): void { root.toggleCenter() }
        function open(): void   { root.setCenter(true) }
        function close(): void  { root.setCenter(false) }
        function dnd(): void    { root.setDnd(!root.dnd) }
        function clear(): void  { root.clearAll() }
        function status(): string { return root.status() }
    }

    function relTime(t) {
        const s = Math.max(0, Math.round((now - t) / 1000))
        if (s < 60) return "Now"
        if (s < 3600) return Math.floor(s / 60) + " min"
        if (s < 86400) return Math.floor(s / 3600) + " h"
        return Qt.formatDate(t, "d MMM")
    }
}
