// Dashboard home: clock, date, weather and app search across the top; two columns of cards (controls, system,
// lighting | calendar, safety) with Now playing across both under them; notifications down the right, straight on
// the dim. Gaps between cards are the dim: a click there closes the dashboard.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../services"
import "../panel"
import "../calendar"
import "../notifications"
import "reveal.js" as Reveal

Item {
    id: home
    signal allApps
    property real reveal: 1                         // 0..1, set by Dashboard (reveal.js)
    property alias focusItem: search.focusItem

    readonly property int marginX: 64
    readonly property int marginY: 40
    readonly property int gap: 12
    readonly property int searchWidth: 420
    readonly property int searchFieldHeight: 36    // panel/Search.qml's field
    readonly property int nowPlayingMaxHeight: 360
    readonly property real colWidth: (width - 2 * marginX - 2 * gap) / 3

    // ── clock, weather, sun ──────────────────────────────────
    property date now: new Date()
    Timer { interval: 5000; running: Panel.open; repeat: true; triggeredOnStart: true; onTriggered: home.now = new Date() }
    // ~/.local/bin/weather (the bar's module) and themes/sun.py keep these caches
    FileView { id: weather; path: Quickshell.env("HOME") + "/.cache/weather.json"; printErrors: false; watchChanges: true; onFileChanged: reload() }
    FileView { id: sun; path: Quickshell.env("HOME") + "/.cache/theme-sun"; printErrors: false; watchChanges: true; onFileChanged: reload() }
    readonly property string weatherText: { try { return JSON.parse(weather.text()).text || "" } catch (e) { return "" } }
    readonly property var sunTimes: (sun.text().trim().split(/\s+/)).slice(1)          // "DATE SUNRISE SUNSET"
    readonly property string dateLine: [Qt.formatDate(now, "dddd d MMMM"), weatherText,
        sunTimes.length === 2 ? "sunrise " + sunTimes[0] + " · sunset " + sunTimes[1] : ""].filter(s => s !== "").join("  ·  ")

    ColumnLayout {
        anchors { fill: parent; leftMargin: home.marginX; rightMargin: home.marginX; topMargin: home.marginY; bottomMargin: home.marginY }
        spacing: home.gap

        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: home.gap

            // ── left two columns ─────────────────────────────
            ColumnLayout {
                Layout.preferredWidth: 2 * home.colWidth + home.gap
                Layout.fillHeight: true
                spacing: home.gap

                // header: clock + date line, search on the right (its results drop over the cards)
                Item {
                    Layout.fillWidth: true
                    implicitHeight: clockCol.implicitHeight
                    z: 2
                    opacity: Reveal.stage(home.reveal, 0); transform: Translate { y: Reveal.offset(home.reveal, 0) }
                    Swallow {}
                    Column {
                        id: clockCol
                        anchors.left: parent.left
                        spacing: 6
                        Text { text: Qt.formatTime(home.now, "HH:mm"); color: Theme.text; font { family: Theme.fontDisplay; pixelSize: 96 } }
                        Text { text: home.dateLine; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 16; weight: Font.DemiBold } }
                    }
                    Rectangle {
                        // pinned by the field's top, level with the date line: results grow downwards
                        anchors { right: parent.right; top: parent.bottom; topMargin: -home.searchFieldHeight }
                        width: home.searchWidth
                        height: search.implicitHeight + (search.results.length > 0 ? 12 : 0)
                        color: search.results.length > 0 ? Theme.glassPanel : "transparent"
                        border.width: search.results.length > 0 ? 1 : 0; border.color: Theme.overlay
                        Swallow {}
                        Search { id: search; anchors { left: parent.left; right: parent.right; top: parent.top } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: home.gap
                    ColumnLayout {
                        Layout.preferredWidth: home.colWidth
                        opacity: Reveal.stage(home.reveal, 1); transform: Translate { y: Reveal.offset(home.reveal, 1) }
                        Layout.alignment: Qt.AlignTop
                        spacing: home.gap
                        Section { title: "Controls"; Toggles { Layout.fillWidth: true } }
                        Section { title: "System"; System { Layout.fillWidth: true } }
                        Section { title: "Lighting"; Lighting { Layout.fillWidth: true } }
                    }
                    ColumnLayout {
                        Layout.preferredWidth: home.colWidth
                        opacity: Reveal.stage(home.reveal, 2); transform: Translate { y: Reveal.offset(home.reveal, 2) }
                        Layout.alignment: Qt.AlignTop
                        spacing: home.gap
                        Section {
                            title: "Calendar"
                            Widgets.Tile {
                                Layout.fillWidth: true
                                implicitHeight: month.implicitHeight + 20
                                Month { id: month; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 } }
                            }
                        }
                        Section { title: "Safety"; ClamAV { Layout.fillWidth: true }  Safeguards { Layout.fillWidth: true } }
                    }
                }

                NowPlaying {
                    id: nowPlaying
                    opacity: Reveal.stage(home.reveal, 4); transform: Translate { y: Reveal.offset(home.reveal, 4) }
                    visible: player !== null
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.maximumHeight: home.nowPlayingMaxHeight
                }
                Item { Layout.fillHeight: true; visible: !nowPlaying.visible }

                // the way down to All apps
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: downRow.implicitWidth + 24; implicitHeight: 30
                    color: dm.containsMouse ? Theme.glassCard : "transparent"
                    border.width: 1; border.color: dm.containsMouse ? Theme.overlay : "transparent"
                    Row {
                        id: downRow
                        anchors.centerIn: parent
                        spacing: 8
                        Glyph { text: "\u{F0140}"; color: Theme.subtext; size: 14 }          // chevron-down
                        Text { text: "All apps  ·  Tab"; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
                    }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; onClicked: home.allApps() }
                }
            }

            // ── notifications ────────────────────────────────
            Item {
                Layout.preferredWidth: home.colWidth
                opacity: Reveal.stage(home.reveal, 3); transform: Translate { y: Reveal.offset(home.reveal, 3) }
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text: "Notifications" + (Notifs.unread > 0 ? "  ·  " + Notifs.unread : "")
                            color: Theme.text
                            font { family: Theme.fontDisplay; pixelSize: 16; weight: Font.Bold }
                        }
                        Text { text: "Do not disturb"; color: Theme.subtext; font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold } }
                        Widgets.Switch { on: Notifs.dnd; onClicked: Notifs.setDnd(!Notifs.dnd) }
                        Widgets.Button { label: "Read all"; visible: Notifs.unread > 0; onClicked: Notifs.markAllRead() }
                        Widgets.Button { label: "Clear"; visible: Notifs.groups.length > 0; onClicked: Notifs.clearAll() }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Flickable {
                            anchors.fill: parent
                            contentHeight: list.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height     // otherwise the wheel slides the views
                            ColumnLayout {
                                id: list
                                width: parent.width
                                spacing: 10
                                Repeater {
                                    model: Notifs.groups
                                    Group { required property var modelData; g: modelData; Layout.fillWidth: true }
                                }
                            }
                        }
                        Text {                        // outside the Flickable: its content item is 0 px tall when empty
                            anchors.centerIn: parent
                            visible: Notifs.groups.length === 0
                            text: "Nothing here"
                            color: Theme.muted
                            font { family: Theme.fontUi; pixelSize: Theme.fontSize }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Panel
        function onOpenChanged() { if (Panel.open) { month.shown = new Date(); month.today = new Date() } }
    }

    // a section heading over its cards
    component Section: Item {
        id: section
        property string title
        default property alias content: sectionCol.data
        Layout.fillWidth: true
        implicitHeight: sectionCol.implicitHeight
        Swallow {}
        ColumnLayout {
            id: sectionCol
            width: parent.width
            spacing: 6
            Widgets.Heading { text: section.title.toUpperCase() }
        }
    }
    // clicks on a card never reach the closer underneath
    component Swallow: MouseArea { anchors.fill: parent; z: -1 }
}
