// Quickshell — "Harbour" shell: notification server + centre, and the widget panel.
//   qs ipc call notifs toggle|open|close|dnd|clear|status
//   qs ipc call panel  toggle|open|close|mediabar|status
import Quickshell
import "notifications"
import "panel"

ShellRoot {
    Popups {}
    Center {}
    Panel {}
}
