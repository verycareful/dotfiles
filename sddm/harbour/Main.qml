// Login screen. Colours/fonts come from theme.conf (rendered by `theme`), the background is
// the active wallpaper pre-blurred and dimmed (also rendered by `theme`), so this file is static.
import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 2560; height: 1440
    color: config.Base

    readonly property string fontUi: config.FontUi
    readonly property string fontDisplay: config.FontDisplay
    readonly property string fontIcon: config.FontIcon
    property int sessionIndex: sessionModel.lastIndex
    property string userName: userModel.lastUser !== "" ? userModel.lastUser
                              : (userModel.rowCount() > 0 ? (userModel.data(userModel.index(0, 0), Qt.UserRole + 1) || config.User) : config.User)
    property bool failed: false
    property bool busy: false

    Image { anchors.fill: parent; source: config.Background; fillMode: Image.PreserveAspectCrop; asynchronous: false }

    // ── clock ────────────────────────────────────────────────
    Column {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.17 }
        spacing: 2
        Text { id: time; anchors.horizontalCenter: parent.horizontalCenter; color: config.Text; text: Qt.formatTime(new Date(), "HH:mm"); font { family: root.fontDisplay; pixelSize: 112; bold: true } }
        Text { id: date; anchors.horizontalCenter: parent.horizontalCenter; color: config.Subtext; text: Qt.formatDate(new Date(), "dddd, d MMMM"); font { family: root.fontDisplay; pixelSize: 22 } }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: { time.text = Qt.formatTime(new Date(), "HH:mm"); date.text = Qt.formatDate(new Date(), "dddd, d MMMM") } }

    // ── card ─────────────────────────────────────────────────
    Rectangle {
        id: card
        width: 460; height: col.implicitHeight + 56
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: parent.height * 0.12 }
        color: Qt.rgba(colorOf(config.Mantle).r, colorOf(config.Mantle).g, colorOf(config.Mantle).b, 0.78)
        border.width: 1; border.color: config.Overlay
        function colorOf(s) { return Qt.color(s) }
        Rectangle { width: 3; height: parent.height; color: root.failed ? config.Red : config.Accent }   // side bar, like the notification cards

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28; leftMargin: 32 }
            spacing: 14
            Row {
                spacing: 10
                Text { text: "\u{F0004}"; color: config.Muted; anchors.verticalCenter: parent.verticalCenter; font { family: root.fontIcon; pixelSize: 18 } }   // account
                Text { text: root.userName; color: config.Text; anchors.verticalCenter: parent.verticalCenter; font { family: root.fontUi; pixelSize: 20; bold: true } }
            }
            Rectangle {                                          // password field
                width: parent.width; height: 46
                color: Qt.rgba(card.colorOf(config.Base).r, card.colorOf(config.Base).g, card.colorOf(config.Base).b, 0.6)
                border.width: 1; border.color: pw.activeFocus ? config.PrimaryBright : config.Overlay
                TextInput {
                    id: pw
                    anchors { fill: parent; leftMargin: 14; rightMargin: 44 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: config.Text
                    font { family: root.fontUi; pixelSize: 16; letterSpacing: 3 }
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    focus: true
                    clip: true
                    onAccepted: root.tryLogin()
                    Keys.onEscapePressed: text = ""
                    Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: pw.text === "" && !root.busy; text: "password"; color: config.Muted; font { family: root.fontUi; pixelSize: 15; letterSpacing: 0 } }
                }
                Text {                                           // caps lock
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    visible: keyboard.capsLock
                    text: "\u{F0630}"; color: config.Accent; font { family: root.fontIcon; pixelSize: 16 }
                }
            }
            Rectangle {                                          // login button
                width: parent.width; height: 42
                color: root.busy ? config.Muted : (loginArea.containsMouse ? config.PrimaryBright : config.Accent)
                Text { anchors.centerIn: parent; text: root.busy ? "…" : "login"; color: loginArea.containsMouse ? config.Text : config.Base; font { family: root.fontUi; pixelSize: 15; bold: true; letterSpacing: 2 } }
                MouseArea { id: loginArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.tryLogin() }
            }
            Text { visible: root.failed; text: "wrong password"; color: config.Red; font { family: root.fontUi; pixelSize: 12 } }
        }
    }
    SequentialAnimation {                                        // shake on failure
        id: shake
        NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -10; duration: 40 }
        NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 10; duration: 60 }
        NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -6; duration: 50 }
        NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
    }

    function tryLogin() {
        if (root.busy || pw.text === "") return
        root.busy = true; root.failed = false
        sddm.login(root.userName, pw.text, root.sessionIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() { root.busy = false; root.failed = true; pw.text = ""; shake.start(); pw.forceActiveFocus() }
        function onLoginSucceeded() { root.busy = true }
    }

    // ── session (bottom-left) ────────────────────────────────
    Rectangle {
        anchors { left: parent.left; bottom: parent.bottom; margins: 36 }
        width: sessRow.implicitWidth + 28; height: 38
        color: Qt.rgba(card.colorOf(config.Mantle).r, card.colorOf(config.Mantle).g, card.colorOf(config.Mantle).b, 0.7)
        border.width: 1; border.color: sessArea.containsMouse ? config.Accent : config.Overlay
        Row {
            id: sessRow
            anchors.centerIn: parent; spacing: 10
            Text { text: "\u{F0A5A}"; color: config.Subtext; anchors.verticalCenter: parent.verticalCenter; font { family: root.fontIcon; pixelSize: 15 } }   // monitor
            Text { text: sessionName(); color: config.Subtext; anchors.verticalCenter: parent.verticalCenter; font { family: root.fontUi; pixelSize: 13; bold: true } }
            Text { text: "\u{F0140}"; color: config.Muted; anchors.verticalCenter: parent.verticalCenter; font { family: root.fontIcon; pixelSize: 13 } }
        }
        MouseArea { id: sessArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount() }
    }
    function sessionName() {
        const idx = sessionModel.index(root.sessionIndex, 0)
        return sessionModel.data(idx, Qt.UserRole + 4) || ("session " + root.sessionIndex)   // NameRole
    }

    // ── power (bottom-right) ─────────────────────────────────
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 36 }
        spacing: 8
        PowerButton { glyph: "\u{F0709}"; tip: "restart";  enabled: sddm.canReboot;   onClicked: sddm.reboot() }
        PowerButton { glyph: "\u{F0425}"; tip: "shut down"; enabled: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }
    component PowerButton: Rectangle {
        property string glyph
        property string tip
        signal clicked
        width: 38; height: 38
        visible: enabled
        color: Qt.rgba(card.colorOf(config.Mantle).r, card.colorOf(config.Mantle).g, card.colorOf(config.Mantle).b, 0.7)
        border.width: 1; border.color: pa.containsMouse ? config.Accent : config.Overlay
        Text { anchors.centerIn: parent; text: parent.glyph; color: pa.containsMouse ? config.Accent : config.Subtext; font { family: root.fontIcon; pixelSize: 17 } }
        MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }
}
