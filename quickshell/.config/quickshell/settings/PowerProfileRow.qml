// The power profile (power-profiles-daemon through UPower).
import QtQuick
import Quickshell.Services.UPower

SettingRow {
    first: true
    title: "Power profile"
    detail: "Balanced suits everyday use; performance holds higher clocks."
    Choice {
        options: ["power-saver", "balanced", "performance"]
        labels: ["Power saver", "Balanced", "Performance"]
        value: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
             : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
        onPicked: v => PowerProfiles.profile = v === "power-saver" ? PowerProfile.PowerSaver
                                             : v === "performance" ? PowerProfile.Performance : PowerProfile.Balanced
    }
}
