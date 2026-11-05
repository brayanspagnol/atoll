pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Public holidays for the country chosen in Settings. Data comes from date.nager.at and stays cached.
Singleton {
    id: root
    // "off", "auto" (from the system locale) or a country code.
    readonly property string country: {
        const chosen = Cfg.v.holidays
        if (chosen === "off") return ""
        if (chosen && chosen !== "auto") return chosen
        return Qt.locale().name.split("_")[1] ?? ""
    }
    readonly property string script: Quickshell.env("HOME") + "/.local/share/atoll/scripts/holidays"
    property var names: ({})
    property bool failed: false
    property int year: 0
    property var countries: []

    // The grid of a month can show days of the neighbouring years.
    function load(y) {
        year = y
        fetch()
    }
    function listCountries() { if (!countries.length) listing.running = true }
    function fetch() {
        names = {}
        failed = false
        loader.running = false
        if (!country || !year) return
        loader.command = [script, country, String(year - 1), String(year), String(year + 1)]
        loader.running = true
    }
    onCountryChanged: fetch()
    Connections { target: Tr; function onCodeChanged() { root.fetch() } }

    Process {
        id: loader
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                if (!text.trim()) return
                const map = {}
                for (const h of JSON.parse(text)) map[h.date] = Tr.code === "en" ? h.name : h.localName
                root.names = map
            }
        }
        onExited: code => root.failed = code !== 0
    }
    Process {
        id: listing
        command: [root.script, "countries"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.countries = JSON.parse(text) }
    }
}
