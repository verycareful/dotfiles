// Quickshell — "Harbour" shell. Currently: the notification server, popups and the
// notification centre (replaced swaync). The widget panel will live here too.
//   qs ipc call notifs toggle|open|close|dnd|clear|status
import Quickshell
import "notifications"

ShellRoot {
    Popups {}
    Center {}
}
