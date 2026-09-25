// Quickshell — "Harbour" shell: notification server + centre, and the widget panel.
//   qs ipc call notifs toggle|open|close|dnd|clear|status
//   qs ipc call panel  toggle|open|close|mediabar|status
//   qs ipc call switcher next|prev|apply|cancel   (Alt-Tab)
//   qs ipc call dns open|close|toggle             (DNS settings window)
import Quickshell
import "notifications"
import "panel"
import "switcher"
import "dns"

ShellRoot {
    Popups {}
    Center {}
    Panel {}
    Switcher {}
    DnsWindow {}
}
