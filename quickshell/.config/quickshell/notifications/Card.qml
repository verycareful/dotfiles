// One notification. Used by both the centre and the popups.
//   left click  → mark read (popup: also hide the popup)
//   right/middle click → dismiss just this one
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."
import "../services"

Rectangle {
    id: card
    required property var entry            // Notifs.Entry
    property bool popup: false
    readonly property var n: entry.n
    readonly property bool critical: n.urgency === 2
    readonly property color mark: critical ? Theme.red : (entry.read ? Theme.muted : Theme.accent)

    implicitHeight: body.implicitHeight + 20
    color: Theme.glassCard
    border.width: 1
    border.color: Theme.overlay

    Rectangle { width: 3; height: parent.height; color: card.mark }   // read/unread bar

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) { Notifs.markRead(card.entry); if (card.popup) Notifs.hidePopup(card.entry) }
            else Notifs.dismiss(card.entry)
        }
    }

    RowLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 12; topMargin: 10 }
        spacing: 10

        // image (screenshot, album art) or the app icon
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40; implicitHeight: 40
            // entry.image is the notification's image only after Notifs verified it (file-path
            // hints may point at temp files that are already gone — Satty); else the app icon.
            Image {
                id: img
                anchors.fill: parent
                visible: card.entry.image !== "" && status === Image.Ready
                source: card.entry.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            IconImage {
                anchors.fill: parent
                visible: card.entry.image === "" || img.status !== Image.Ready
                source: Notifs.iconFor(card.n)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: card.n.summary
                    color: Theme.text
                    font { family: Theme.fontUi; pixelSize: Theme.fontSize; weight: Font.Bold }
                    elide: Text.ElideRight
                }
                Text {
                    text: Notifs.relTime(card.entry.time)
                    color: Theme.muted
                    font { family: Theme.fontUi; pixelSize: 11 }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.n.body
                textFormat: Text.StyledText
                color: Theme.subtext
                font { family: Theme.fontUi; pixelSize: Theme.fontSize }
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 12
                elide: Text.ElideRight
                linkColor: Theme.primaryBright
                onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
            }

            // action buttons ("Open", "Mark as read", …) — run, but keep the notification
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: card.n.actions.length > 0
                Repeater {
                    model: card.n.actions
                    Rectangle {
                        required property var modelData
                        implicitWidth: alabel.implicitWidth + 18; implicitHeight: 24
                        color: ahover.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
                        border.width: 1; border.color: Theme.overlay
                        Text {
                            id: alabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: ahover.containsMouse ? Theme.text : Theme.subtext
                            font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
                        }
                        MouseArea { id: ahover; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.invoke(card.entry, parent.modelData) }
                    }
                }
            }

            // inline reply (apps that offer it: chat clients etc.)
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: card.n.hasInlineReply
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 26
                    color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.6)
                    border.width: 1; border.color: reply.activeFocus ? Theme.primaryBright : Theme.overlay
                    TextInput {
                        id: reply
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font { family: Theme.fontUi; pixelSize: 12 }
                        text: card.entry.replyText
                        onTextEdited: card.entry.replyText = text
                        onAccepted: Notifs.reply(card.entry, text)
                        clip: true
                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            visible: reply.text === "" && !reply.activeFocus
                            text: card.n.inlineReplyPlaceholder || "Reply…"
                            color: Theme.muted; font: reply.font
                        }
                    }
                }
                Rectangle {
                    implicitWidth: 26; implicitHeight: 26
                    color: shover.containsMouse ? Theme.accent : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
                    border.width: 1; border.color: Theme.overlay
                    Text { anchors.centerIn: parent; text: "\u{F048A}"; color: shover.containsMouse ? Theme.base : Theme.subtext; font { family: Theme.fontIcon; pixelSize: 14 } }   // send
                    MouseArea { id: shover; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.reply(card.entry, reply.text) }
                }
            }
        }
    }
}
