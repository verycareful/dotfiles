// Tray window: the windows hidden with SUPER+M (special:tray), one row each with a close button on the right.
// Click or Enter brings a window to the current workspace and focuses it; the close button or Delete closes it
// where it is, without bringing it forward. Up/Down move, Escape closes the window.
//   qs ipc call tray open|close|toggle   (SUPER+Shift+M)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."
import "../panel"

Scope {
    id: root
    readonly property var hidden: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.name === "special:tray")
    property int cursor: 0
    onHiddenChanged: cursor = Math.max(0, Math.min(cursor, hidden.length - 1))

    // class names arrive with the IPC refresh; keep them fresh while the window is open
    Connections {
        target: Hyprland
        enabled: win.visible
        function onRawEvent(e) { if (["openwindow", "closewindow", "movewindow", "windowtitle"].includes(e.name)) Hyprland.refreshToplevels() }
    }

    function addr(t) { return "address:0x" + String(t.address).replace(/^0x/, "") }
    function className(t) { return t.lastIpcObject && t.lastIpcObject.class ? t.lastIpcObject.class : (t.wayland ? t.wayland.appId : "") }
    function restore(t) {
        win.visible = false
        Quickshell.execDetached(["sh", "-c",
            'ws=$(hyprctl activeworkspace -j | jq -r .id); ' +
            'hdsp "hl.dsp.window.move({ workspace = $ws, window = \\"$1\\", follow = true })" movetoworkspace "$ws,$1" && ' +
            'hdsp "hl.dsp.focus({ window = \\"$1\\" })" focuswindow "$1"', "sh", addr(t)])
    }
    function close(t) { Quickshell.execDetached(["hdsp", `hl.dsp.window.close({ window = "${addr(t)}" })`, "closewindow", addr(t)]) }
    function show() {
        Hyprland.refreshToplevels()
        cursor = 0
        win.visible = true
    }

    IpcHandler {
        target: "tray"
        function open(): void   { root.show() }
        function close(): void  { win.visible = false }
        function toggle(): void { if (win.backingWindowVisible) win.visible = false; else root.show() }
    }

    FloatingWindow {
        id: win
        visible: false          // set, not bound: the compositor can close it too
        onClosed: visible = false
        title: "Tray"
        implicitWidth: 520
        implicitHeight: body.implicitHeight + 36
        color: Theme.base
        // Hyprland keeps a floating window at the size it mapped with, so the height is pushed to it on
        // every change (rows arriving with the refresh, a row closed)
        onImplicitHeightChanged: if (visible) fit.restart()
        onVisibleChanged: if (visible) fit.restart()
        Timer {
            id: fit
            interval: 50
            onTriggered: {
                const w = "title:^(Tray)$", x = win.implicitWidth, y = Math.round(win.implicitHeight)
                Quickshell.execDetached(["hdsp", `hl.dsp.window.resize({ x = ${x}, y = ${y}, window = "${w}" })`,
                                         "resizewindowpixel", `exact ${x} ${y},${w}`])
            }
        }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 10
            focus: true
            Keys.onEscapePressed: win.visible = false
            Keys.onPressed: e => {
                const t = root.hidden[root.cursor]
                if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
                    root.cursor = Math.max(0, Math.min(root.hidden.length - 1, root.cursor + (e.key === Qt.Key_Up ? -1 : 1)))
                    e.accepted = true
                } else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && t) { root.restore(t); e.accepted = true }
                else if (e.key === Qt.Key_Delete && t) { root.close(t); e.accepted = true }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                Text { text: "Tray"; color: Theme.text; font { family: Theme.fontDisplay; pixelSize: 18; weight: Font.Bold; letterSpacing: 1 } }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.hidden.length + " hidden"
                    color: Theme.subtext
                    font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
                }
            }
            Text {
                visible: root.hidden.length === 0
                Layout.topMargin: 6; Layout.bottomMargin: 6
                text: "Nothing hidden. SUPER+M hides the focused window here."
                color: Theme.muted
                font { family: Theme.fontUi; pixelSize: 12 }
            }
            Repeater {
                model: root.hidden
                Entry { required property var modelData; required property int index; toplevel: modelData; at: index }
            }
            Text {
                Layout.topMargin: 4
                text: "Click or Enter restores · Delete or \u{F0156} closes · arrows move"
                color: Theme.muted
                font { family: Theme.fontUi; pixelSize: 11 }
            }
        }
    }

    // one hidden window: icon, class and title; the close button sits on the right
    component Entry: Rectangle {
        id: row
        property var toplevel
        property int at
        readonly property bool selected: at === root.cursor
        Layout.fillWidth: true
        implicitHeight: 44
        color: selected ? Qt.alpha(Theme.primary, 0.45) : Theme.surface
        border.width: selected ? 2 : 1
        border.color: selected ? Theme.primaryBright : Theme.overlay

        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.cursor = row.at
            onClicked: root.restore(row.toplevel)
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
            spacing: 10
            Image {
                Layout.preferredWidth: 20; Layout.preferredHeight: 20
                source: Quickshell.iconPath(root.className(row.toplevel).toLowerCase(), "application-x-executable")
                sourceSize: Qt.size(20, 20)
            }
            Text {
                text: root.className(row.toplevel)
                color: row.selected ? Theme.text : Theme.subtext
                font { family: Theme.fontUi; pixelSize: 12; weight: Font.Bold }
            }
            Text {
                Layout.fillWidth: true
                text: row.toplevel.title
                color: row.selected ? Theme.text : Theme.subtext
                elide: Text.ElideRight
                font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
            }
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                color: closeHover.containsMouse ? Qt.alpha(Theme.red, 0.25) : "transparent"
                border.width: closeHover.containsMouse ? 1 : 0; border.color: Theme.red
                Text {
                    anchors.centerIn: parent
                    text: "\u{F0156}"
                    color: closeHover.containsMouse ? Theme.red : (row.selected ? Theme.text : Theme.muted)
                    font { family: Theme.fontIcon; pixelSize: 16 }
                }
                MouseArea {
                    id: closeHover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.cursor = row.at
                    onClicked: root.close(row.toplevel)
                }
            }
        }
    }
}
