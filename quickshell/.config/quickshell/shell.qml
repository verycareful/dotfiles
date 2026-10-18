// Quickshell — "Harbour" shell: notification server + centre, and the widget panel.
//   qs ipc call notifs toggle|open|close|dnd|clear|status
//   qs ipc call panel  toggle|open|close|mediabar|status
//   qs ipc call switcher next|prev|apply|cancel   (Alt-Tab)
//   qs ipc call dns open|close|toggle             (DNS settings window)
//   qs ipc call perms open|close|toggle           (permissions window)
//   qs ipc call osd caps|brightness               (on-screen display; volume and mic follow PipeWire)
import Quickshell
import "notifications"
import "panel"
import "switcher"
import "dns"
import "perms"
import "osd"

ShellRoot {
    Popups {}
    Center {}
    Panel {}
    Switcher {}
    DnsWindow {}
    PermsWindow {}
    Osd {}
}
