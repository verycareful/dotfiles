// Quickshell — "Harbour" shell: notification server + centre, and the widget panel.
//   qs ipc call notifs toggle|open|close|dnd|clear|status
//   qs ipc call panel  toggle|open|close|mediabar|status
//   qs ipc call switcher next|prev|apply|cancel   (Alt-Tab)
import Quickshell
import "notifications"
import "panel"
import "switcher"

ShellRoot {
    Popups {}
    Center {}
    Panel {}
    Switcher {}
}
