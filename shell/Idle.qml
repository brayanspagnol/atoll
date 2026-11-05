pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// hypridle stays a separate process on purpose: idle lock must survive a shell crash.
Singleton {
    id: idle
    readonly property string path: Quickshell.env("HOME") + "/.config/atoll/hypridle.conf"
    function listener(min, onAc, cmd) {
        if (min <= 0) return ""
        const test = "$HOME/.local/share/atoll/scripts/on-ac"
        const on = onAc ? `${test} && ${cmd}` : `${test} || ${cmd}`
        return `listener {\n    timeout = ${min * 60}\n    on-timeout = ${on}\n    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'\n}\n`
    }
    function render() {
        const v = Cfg.v, lock = "loginctl lock-session", off = `hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'`, sl = "systemctl suspend"
        return `general {\n    lock_cmd = pidof hyprlock || hyprlock -c $HOME/.config/atoll/hyprlock.conf\n    before_sleep_cmd = loginctl lock-session\n    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'\n}\n`
            + listener(v.lockAc, true, lock) + listener(v.dpmsAc, true, off) + listener(v.sleepAc, true, sl)
            + listener(v.lockBat, false, lock) + listener(v.dpmsBat, false, off) + listener(v.sleepBat, false, sl)
    }
    function apply() {
        file.setText(render())
        Quickshell.execDetached(["sh", "-c", `pkill -x hypridle; sleep 0.2; setsid hypridle -c "${path}" >/dev/null 2>&1 &`])
    }
    FileView { id: file; path: idle.path; atomicWrites: true }
}
