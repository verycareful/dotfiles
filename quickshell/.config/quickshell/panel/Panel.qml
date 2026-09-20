// The widget panel: dropdown under the bar, top-left. SUPER+A / the anchor button / Esc / click outside.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

Scope {
    // click-catcher: everything except the panel's own rectangle
    PanelWindow {
        visible: Panel.open
        anchors { top: true; bottom: true; left: true; right: true }
        margins { left: 600 }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-panel-catcher"
        MouseArea { anchors.fill: parent; onClicked: Panel.setOpen(false) }
    }
    PanelWindow {
        visible: Panel.open
        anchors { top: true; bottom: true; left: true }
        margins { top: panelBody.implicitHeight + 24 < screen.height ? 0 : 0 }
        implicitWidth: 600
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-panel"
        WlrLayershell.keyboardFocus: Panel.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // the catcher covers below the panel too, so clicks under it close the panel
        mask: Region { item: panelBody }

        Rectangle {
            id: panelBody
            anchors { top: parent.top; left: parent.left; right: parent.right }
            implicitHeight: col.implicitHeight + 28
            color: Theme.glassPanel
            border.width: 1; border.color: Theme.overlay
            focus: true
            Keys.onEscapePressed: Panel.setOpen(false)

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 12
                Search { id: search; Layout.fillWidth: true }
                Toggles { Layout.fillWidth: true }
                Thermal  { Layout.fillWidth: true }
                Media    { Layout.fillWidth: true }
                System   { Layout.fillWidth: true }
                ClamAV   { Layout.fillWidth: true }
                Calendar { Layout.fillWidth: true }
            }
            Connections { target: Panel; function onOpenChanged() { if (Panel.open) search.focusItem.forceActiveFocus() } }
        }
    }
}
