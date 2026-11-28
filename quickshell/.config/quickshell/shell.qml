// Quickshell — "Harbour" shell: notification server + popups, and the dashboard.
//   qs ipc call notifs dnd|clear|status
//   qs ipc call panel  toggle|open|close|mediabar|status   (the dashboard, SUPER+A, the bar's anchor)
//   qs ipc call dashboard home|apps                (open the dashboard on Home or All apps)
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
import "dashboard"
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
    Dashboard {}
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
