// One station tile: a live preview of a workspace (or a single hidden or shot window), its key badge and name.
// The hub tile shows the dashboard's Home view, scaled down. Hover arrows sit just outside the free sides.
import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../dashboard"

Item {
    id: tile
    required property var info                 // a model tile, or null for the hub
    required property bool selected
    required property bool live                // previews update only while the station shows
    property real chrome: 1                    // 1 normal, 0 while the tile grows to the screen: frame, badge and name fade
    property var freeSides: []                 // "left" | "right" | "up" | "down": where a hover arrow may show
    signal clicked
    signal branchTo(string side)

    readonly property bool hub: info === null
    readonly property bool hidden: !hub && info.branch === "hidden"
    readonly property int arrowGap: 14         // distance of a hover arrow from the tile edge
    readonly property int arrowReach: 44       // how far outside the tile the pointer still counts as near

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 10 * tile.chrome
        color: Theme.glassCard
        clip: true
        border.width: (tile.selected ? 3 : (tile.hub ? 2 : 1)) * tile.chrome
        border.color: tile.selected ? Theme.accent : (tile.hub ? Theme.text : Theme.overlay)
        opacity: tile.hidden ? 0.72 : 1

        // The hub: Home at full screen size, scaled into the tile.
        Loader {
            active: tile.hub
            anchors.fill: parent
            sourceComponent: Item {
                clip: true
                Home {
                    width: Screen.width; height: Screen.height
                    scale: parent.width / Screen.width
                    transformOrigin: Item.TopLeft
                    enabled: false
                    active: false
                }
            }
        }

        // Workspaces: one live capture per window, side by side (a Mix shows its branches next to each other).
        Row {
            visible: !tile.hub
            anchors { fill: parent; margins: 6 }
            spacing: 4
            Repeater {
                model: tile.hub ? [] : tile.info.windows.slice(0, 3)
                ScreencopyView {
                    required property var modelData
                    width: (parent.width - (Math.min(tile.info.windows.length, 3) - 1) * 4) / Math.min(tile.info.windows.length, 3)
                    height: parent.height
                    captureSource: modelData.toplevel ? modelData.toplevel.wayland : null
                    live: tile.live
                    paintCursor: false
                }
            }
        }
        Text {
            visible: !tile.hub && tile.info.windows.length === 0
            anchors.centerIn: parent
            text: "Empty"
            color: Theme.subtext
            font { family: Theme.fontUi; pixelSize: 14 }
        }

        // key badge
        Rectangle {
            visible: !tile.hub && tile.info.key !== null
            opacity: tile.chrome
            anchors { left: parent.left; top: parent.top; margins: 8 }
            width: Math.max(24, keyText.implicitWidth + 12); height: 24; radius: 6
            color: tile.selected ? Theme.accent : Theme.text
            Text {
                id: keyText
                anchors.centerIn: parent
                text: tile.hub ? "" : (tile.info.key || "")
                color: tile.selected ? Theme.textOnAccent : Theme.base
                font { family: Theme.fontIcon; pixelSize: 13; weight: Font.Bold }
            }
        }
        // name strip
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 26
            opacity: tile.chrome
            color: Theme.glassPanel
            Text {
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10 }
                elide: Text.ElideRight
                text: tile.hub ? "Dashboard" : (tile.info.branch === "mix" ? tile.info.windows.map(w => w.name).join(" + ") : (tile.info.name || "Empty"))
                color: Theme.text
                font { family: Theme.fontUi; pixelSize: 13; weight: Font.DemiBold }
            }
        }
    }

    MouseArea {
        id: near
        anchors { fill: parent; margins: -tile.arrowReach }
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: mouse => {
            if (mouse.x >= tile.arrowReach && mouse.x <= tile.arrowReach + tile.width
                && mouse.y >= tile.arrowReach && mouse.y <= tile.arrowReach + tile.height) tile.clicked()
        }
    }

    // hover arrows on free sides
    Repeater {
        model: near.containsMouse ? tile.freeSides : []
        Text {
            required property string modelData
            readonly property var place: ({
                right: [tile.width + tile.arrowGap, tile.height / 2 - 14, 0],
                left:  [-tile.arrowGap - 16, tile.height / 2 - 14, 180],
                up:    [tile.width / 2 - 8, -tile.arrowGap - 28, -90],
                down:  [tile.width / 2 - 8, tile.height + tile.arrowGap, 90],
            })[modelData]
            x: place[0]; y: place[1]; rotation: place[2]
            text: "›"
            color: Theme.accent
            font { family: Theme.fontUi; pixelSize: 28; weight: Font.Bold }
            MouseArea {
                anchors { fill: parent; margins: -6 }
                onClicked: tile.branchTo(parent.modelData)
            }
        }
    }
}
