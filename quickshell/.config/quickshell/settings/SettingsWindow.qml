// Settings: a glass window centred on the screen, a page list on the left and the page on the right.
// The rest of the screen stays clear; a click there or Esc closes it. Pages reuse the panel's widgets.
//   qs ipc call settings open [PAGE] | close | toggle   (SUPER+comma, the bar's gear, SUPER+X > Settings)
// PAGE is a page id (appearance, bar, notifications, network, performance, lighting, security, permissions).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../panel"
import "../services"

Scope {
    id: root
    readonly property int bodyWidth: 1040
    readonly property int bodyHeight: 680
    readonly property int navWidth: 210
    readonly property var pages: [
        { id: "appearance",    label: "Appearance",          glyph: "\u{F03D8}", page: appearance },
        { id: "bar",           label: "Bar & music",         glyph: "\u{F0EA2}", page: bar },
        { id: "notifications", label: "Notifications",       glyph: "\u{F009A}", page: notifications },
        { id: "network",       label: "Network & DNS",       glyph: "\u{F0200}", page: network },
        { id: "performance",   label: "Performance",         glyph: "\u{F0EE0}", page: performance },
        { id: "lighting",      label: "Lighting",            glyph: "\u{F0335}", page: lighting },
        { id: "security",      label: "Security & backup",   glyph: "\u{F0483}", page: security },
        { id: "permissions",   label: "Permissions",         glyph: "\u{F033E}", page: permissions }
    ]
    function pageIndex(id) { return Math.max(0, pages.findIndex(p => p.id === id)) }

    // Opening parks the dashboard if it shows; closing brings it back, unless Settings closes only to hand over to
    // another window (`toWindow`), which resumes it when that closes.
    function setOpen(o, page, toWindow) {
        const was = keep.open
        if (o) Panel.parkDashboard()
        if (page) keep.page = pageIndex(page)
        keep.open = o
        if (!o && was && !toWindow) Panel.resumeDashboard()
    }

    IpcHandler {
        target: "settings"
        function open(page: string): void { root.setOpen(true, page) }
        function close(): void  { root.setOpen(false) }
        function toggle(): void { root.setOpen(!keep.open) }
    }

    // a theme switch rewrites Theme.qml and Quickshell reloads the whole shell: keep the window and its page
    PersistentProperties {
        id: keep
        reloadableId: "settingsWindow"
        property bool open: false
        property int page: 0
        onOpenChanged: Panel.settingsOpen = open
        onLoaded: Panel.settingsOpen = open
    }
    Connections {
        target: Panel
        function onSettingsClose()  { root.setOpen(false, "", true) }
        function onSettingsReturn() { root.setOpen(true) }
    }

    // Hidden while a panel widget waits on a password prompt (Panel.releaseKeyboard): the prompt is an
    // ordinary window, and this layer would cover it. It comes back when the prompt closes either way.
    PanelWindow {
        visible: keep.open && !Panel.releaseKeyboard
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-settings"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // everything outside the window: transparent (so not blurred), closes on click
        MouseArea { anchors.fill: parent; onClicked: root.setOpen(false) }

        Rectangle {
            id: body
            anchors.centerIn: parent
            width: root.bodyWidth; height: root.bodyHeight
            color: Theme.glassPanel
            border.width: 1; border.color: Theme.overlay
            focus: true
            Keys.onEscapePressed: root.setOpen(false)
            Keys.onUpPressed:   keep.page = Math.max(0, keep.page - 1)
            Keys.onDownPressed: keep.page = Math.min(root.pages.length - 1, keep.page + 1)
            MouseArea { anchors.fill: parent }   // clicks inside never reach the closer underneath

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // page list
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: root.navWidth
                    color: "transparent"
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 2
                        Text {
                            text: "Settings"
                            color: Theme.text
                            font { family: Theme.fontDisplay; pixelSize: 18; weight: Font.Bold; letterSpacing: 1 }
                            Layout.bottomMargin: 12; Layout.leftMargin: 6
                        }
                        Repeater {
                            model: root.pages
                            Rectangle {
                                id: item
                                required property var modelData
                                required property int index
                                readonly property bool current: keep.page === index
                                Layout.fillWidth: true
                                implicitHeight: 34
                                color: current ? Theme.accent : (navHover.containsMouse ? Theme.glassCard : "transparent")
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    spacing: 10
                                    Glyph { text: item.modelData.glyph; color: item.current ? Theme.textOnAccent : Theme.subtext; size: 15 }
                                    Text { Layout.fillWidth: true; text: item.modelData.label; color: item.current ? Theme.textOnAccent : Theme.text
                                           font { family: Theme.fontUi; pixelSize: 13; weight: Font.DemiBold } }
                                }
                                MouseArea { id: navHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: keep.page = item.index }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                            text: "Esc closes · ↑ ↓ pages"
                            color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true; Layout.leftMargin: 6
                            font { family: Theme.fontUi; pixelSize: 11; weight: Font.DemiBold }
                        }
                    }
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.overlay }

                // the page, scrolling when it is taller than the window
                Flickable {
                    id: flick
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: pageCol.implicitHeight + 48
                    boundsBehavior: Flickable.StopAtBounds
                    ColumnLayout {
                        id: pageCol
                        x: 24; y: 22
                        width: flick.width - 48
                        spacing: 16
                        Text {
                            text: root.pages[keep.page].label
                            color: Theme.text
                            font { family: Theme.fontDisplay; pixelSize: 22; weight: Font.Bold; letterSpacing: 0.5 }
                        }
                        Loader {
                            Layout.fillWidth: true
                            sourceComponent: root.pages[keep.page].page
                            onLoaded: flick.contentY = 0
                        }
                    }
                }
            }
        }
    }

    // ── pages ────────────────────────────────────────────────
    Component { id: appearance; AppearancePage {} }
    Component { id: bar; BarPage {} }
    Component {
        id: notifications
        ColumnLayout {
            spacing: 0
            SettingRow {
                title: "Do not disturb"; detail: "Popups are held back; the bell still counts them."
                Widgets.Switch { on: Notifs.dnd; onClicked: Notifs.setDnd(!Notifs.dnd) }
            }
        }
    }
    Component { id: network; NetworkPage {} }
    Component {
        id: performance
        ColumnLayout {
            spacing: 14
            PowerProfileRow { Layout.fillWidth: true }
            System { Layout.fillWidth: true }
        }
    }
    Component { id: lighting; ColumnLayout { Lighting { Layout.fillWidth: true } } }
    Component {
        id: security
        ColumnLayout {
            spacing: 14
            ClamAV { Layout.fillWidth: true }
            Safeguards { Layout.fillWidth: true }
        }
    }
    Component {
        id: permissions
        ColumnLayout {
            spacing: 0
            SettingRow {
                title: "App permissions"; detail: "Camera, microphone, screen sharing and launch rules per app, in their own window."
                Widgets.Button { label: "Open permissions"; onClicked: Panel.openWindow("perms") }
            }
        }
    }
}
