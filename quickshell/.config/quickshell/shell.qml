// Quickshell — "Harbour" shell: notification server + centre, and the widget panel.
//   qs ipc call notifs toggle|open|close|dnd|clear|status
//   qs ipc call panel  toggle|open|close|mediabar|status
//   qs ipc call panel  viz | vizmode off|compact|wide|full   (song visualiser, SUPER+Shift+V cycles)
//   qs ipc call switcher next|prev|apply|cancel   (Alt-Tab)
//   qs ipc call dns open|close|toggle             (DNS settings window)
//   qs ipc call perms open|close|toggle           (permissions window)
//   qs ipc call themes open|close|toggle          (theme window, SUPER+Shift+T)
//   qs ipc call settings open [PAGE]|close|toggle  (settings window, SUPER+comma, the bar's gear)
//   ThemeAuto runs `theme auto tick` every 5 min (follow the sun while `theme auto` is on)
//   qs ipc call tray open|close|toggle            (windows hidden to the tray, SUPER+Shift+M)
//   qs ipc call calendar open|close|toggle        (calendar popup, the bar's date)
//   qs ipc call osd caps|brightness               (on-screen display; volume and mic follow PipeWire)
import Quickshell
import "notifications"
import "panel"
import "switcher"
import "dns"
import "perms"
import "themes"
import "tray"
import "calendar"
import "osd"
import "viz"
import "settings"

ShellRoot {
    Popups {}
    Center {}
    Panel {}
    Switcher {}
    DnsWindow {}
    PermsWindow {}
    ThemeWindow {}
    ThemeAuto {}
    SettingsWindow {}
    TrayWindow {}
    CalendarPopup {}
    Osd {}
    BarViz {}
}
