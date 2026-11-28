// The dashboard: a full-screen overlay over the dimmed, blurred desktop. The station's hub (Enter on it) or the bar's anchor opens it;
// Esc or a click on the dim closes it. Three views stacked vertically: Music (the song visualiser, above), Home
// (clock, calendar, controls, media, system, lighting, safety, notifications) and All apps (A-Z). The scroll wheel
// moves one view along that column; Tab toggles Home and All apps; the Now playing card opens
// Music, and Tab leaves it for Home.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../services"
import "reveal.js" as Reveal

Scope {
    id: root
    readonly property int  slideMs: 220
    readonly property int  wheelStep: 120       // one mouse-wheel notch; a touchpad swipe sums to it
    readonly property int  wheelPauseMs: 450    // one swipe switches the view once
    readonly property int  hideMs: 160

    // Hyprland fades the layer (dim and blur) in and out; the content rises in on top of that (reveal.js) and
    // drops out before the window unmaps
    readonly property bool showing: Panel.open && !Panel.releaseKeyboard
    property bool mapped: false
    property real reveal: 0
    onShowingChanged: {
        if (showing) {
            mapped = true; hide.stop()
            if (Panel.instant) { show.stop(); reveal = 1 } else show.restart()
        }
        else { show.stop(); hide.restart() }
    }
    NumberAnimation { id: show; target: root; property: "reveal"; to: 1; duration: Reveal.TOTAL_MS }
    NumberAnimation { id: hide; target: root; property: "reveal"; to: 0; duration: root.hideMs; easing.type: Easing.InCubic
                      onFinished: if (!root.showing) root.mapped = false }

    // a theme switch rewrites Theme.qml and Quickshell reloads the whole shell: keep the dashboard and its view
    PersistentProperties {
        id: keep
        reloadableId: "dashboard"
        property bool open: false
        property int view: 0                    // 0 Home, 1 All apps, 2 Music
        property bool lyricsSide: false         // Music: lyrics down the right (true) or along the bottom
        property bool parked: false             // hidden while a window it opened is up (Panel.parkDashboard)
        onLoaded: { if (open) Panel.setOpen(true); else if (parked) Panel.dashboardParked = true }
    }
    Connections {
        target: Panel
        function onOpenChanged() {
            if (Panel.open && !keep.open && !Panel.resuming) keep.view = 0
            keep.open = Panel.open
        }
        function onDashboardParkedChanged() { keep.parked = Panel.dashboardParked }
    }
    function setView(v) { keep.view = v }
    function toggleView() { setView(keep.view === 0 ? 1 : 0) }
    // the views top to bottom; one wheel step moves to the next one down or up, and stops at the ends
    readonly property var column: [2, 0, 1]
    function neighbour(view, down) {
        const at = column.indexOf(view) + (down ? 1 : -1)
        return column[Math.max(0, Math.min(column.length - 1, at))]
    }

    IpcHandler {
        target: "dashboard"
        function apps(): void { Panel.setOpen(true); root.setView(1) }
        function home(): void { Panel.setOpen(true); root.setView(0) }
        function music(): void { Panel.setOpen(true); root.setView(2) }
        function lyrics(where: string): void { keep.lyricsSide = where === "side" }     // on the Music screen: side or bottom
    }

    // Hidden while a widget waits on a password prompt (Panel.releaseKeyboard): the prompt is an ordinary
    // window, and this layer would cover it. It comes back when the prompt closes either way.
    PanelWindow {
        id: win
        visible: root.mapped
        anchors { top: true; bottom: true; left: true; right: true }
        // over the bar: the Overlay layer, ignoring its exclusive zone, so the bar sits under the dim and blur
        exclusionMode: ExclusionMode.Ignore
        color: Theme.scrim          // over 20% alpha, so Hyprland blurs it (layers.lua)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-dashboard"
        WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: Panel.setOpen(false) }

        Item {
            id: body
            anchors.fill: parent
            clip: true
            focus: true
            Keys.onEscapePressed: Panel.setOpen(false)
            Keys.onTabPressed: root.toggleView()
            Keys.onBacktabPressed: root.toggleView()
            Keys.onLeftPressed: event => { if (keep.view === 2) Panel.cycleViz(-1); else event.accepted = false }
            Keys.onRightPressed: event => { if (keep.view === 2) Panel.cycleViz(1); else event.accepted = false }

            property real acc: 0
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (pause.running) return
                    body.acc += event.angleDelta.y
                    if (Math.abs(body.acc) < root.wheelStep) return
                    root.setView(root.neighbour(keep.view, body.acc < 0))
                    body.acc = 0
                    pause.restart()
                }
            }
            Timer { id: pause; interval: root.wheelPauseMs; onTriggered: body.acc = 0 }

            Item {
                id: track
                width: parent.width; height: parent.height * 3
                readonly property int slot: keep.view === 2 ? 0 : keep.view + 1     // Music, Home, All apps from the top
                y: -slot * body.height
                Behavior on y { NumberAnimation { duration: root.slideMs; easing.type: Easing.OutCubic } }

                Music {
                    id: music
                    active: Panel.open && keep.view === 2     // the view outlives the dashboard: closing it must release cava
                    lyricsSide: keep.lyricsSide
                    onLyricsClicked: keep.lyricsSide = !keep.lyricsSide
                    width: body.width; height: body.height
                }
                Home {
                    id: home
                    reveal: root.reveal
                    active: keep.view === 0
                    y: body.height
                    width: body.width; height: body.height
                    onAllApps: root.setView(1)
                    onMusic: root.setView(2)
                }
                AllApps {
                    id: apps
                    reveal: root.reveal
                    y: 2 * body.height
                    width: body.width; height: body.height
                    onBack: root.setView(0)
                }
            }
        }

        // the shown view's field takes the typing
        function focusView() {
            if (!visible) return
            if (keep.view === 0) home.focusItem.forceActiveFocus()
            else if (keep.view === 1) apps.focusItem.forceActiveFocus()
            else body.forceActiveFocus()
        }
        onVisibleChanged: focusView()
        Connections { target: keep; function onViewChanged() { win.focusView() } }
    }
}
