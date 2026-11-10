pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "weather.js" as W

// The forecast for the island's chip and card, from Open-Meteo. The city is the profile's, or found by IP when asked to.
Singleton {
    id: root
    readonly property bool auto: Cfg.v.weatherAuto
    readonly property string unit: Cfg.v.weatherUnit === "f" ? "f" : "c"
    property var ipPlace: null
    // The profile can hold anything (a hand edit, a backup), so it is checked like remote data.
    readonly property var place: auto ? ipPlace : W.place(Cfg.v.weatherPlace)
    // The last good forecast: a failed fetch keeps it.
    property var data: null
    readonly property bool shown: !!data && Cfg.island.includes("weather")

    property real lastTry: 0
    property real lastOk: 0
    property real lastLocate: 0
    property var asked: null
    function refresh() {
        if (!Cfg.ready) return
        lastTry = Date.now()
        asked = place
        if (!place) {
            data = null
            if (auto && Date.now() - lastLocate > 1800000) locate()
            return
        }
        fetch.running = false
        fetch.unit = unit
        fetch.name = place.name
        fetch.command = W.forecastCommand(place, unit)
        fetch.running = true
    }
    function locate() {
        lastLocate = Date.now()
        locator.running = false
        locator.running = true
    }
    // Wall-clock time, so a wake from suspend counts the time asleep; while failing, it retries every 2 minutes.
    Timer {
        interval: 60000; repeat: true; running: Cfg.ready
        onTriggered: if (Date.now() - root.lastOk > 1800000 && Date.now() - root.lastTry > 120000) root.refresh()
    }
    Connections { target: Cfg; function onReadyChanged() { root.refresh() } }
    Component.onCompleted: refresh()
    // Any profile write reloads the place, so only a different one fetches again.
    onPlaceChanged: if (!W.same(place, asked)) refresh()
    onUnitChanged: refresh()
    onAutoChanged: { lastLocate = 0; ipPlace = null; refresh() }

    Process {
        id: fetch
        property string unit: "c"
        property string name: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const d = W.forecast(text, fetch.unit, fetch.name)
                if (!d) return
                root.data = d
                root.lastOk = Date.now()
            }
        }
    }
    Process {
        id: locator
        command: W.ipCommand
        stdout: StdioCollector { onStreamFinished: { const p = W.ipPlace(text); if (p) root.ipPlace = p } }
    }
}
