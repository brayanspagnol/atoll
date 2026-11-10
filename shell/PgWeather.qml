import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "weather.js" as W
import "pins.js" as Pins

Page {
    id: pg
    title: Tr.t("Weather")
    subtitle: Tr.t("Forecast in the island")
    property var results: []
    property string status: "" // "", "done" or "failed", for the last search

    component Line: RowLayout {
        property string label: ""
        property string hint: ""
        Layout.fillWidth: true; spacing: 16
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: label; Layout.fillWidth: true }
            Tx { visible: hint; text: hint; dim: true; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
    }
    component Place: Rowi {
        id: row
        property var place: null
        implicitHeight: 54
        selected: W.same(place, Weather.place)
        a11y: place ? [place.name, W.where(place)].filter(s => s).join(", ") : ""
        Ic { name: "mapPin"; color: row.selected ? Theme.accent : Theme.muted }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: row.place?.name ?? ""; strong: true; Layout.fillWidth: true }
            Tx { text: W.where(row.place); visible: !!text; dim: true; size: 13; Layout.fillWidth: true }
        }
        Ic { visible: row.selected; name: "check"; color: Theme.accent }
    }

    function find() {
        const q = search.text.trim()
        lookup.running = false
        status = ""
        if (q.length < 2) { results = []; return }
        lookup.command = W.geocodeCommand(q, Tr.code)
        lookup.running = true
    }
    Process {
        id: lookup
        stdout: StdioCollector { onStreamFinished: pg.results = W.geocode(text) }
        onExited: code => pg.status = code === 0 ? "done" : "failed"
    }
    Timer { id: typing; interval: 400; onTriggered: pg.find() }

    Sec { title: Tr.t("City") }
    Place { visible: !!Weather.place && !pg.results.length; clickable: false; place: Weather.place }
    Fld {
        id: search
        Layout.fillWidth: true
        placeholderText: Tr.t("Search city")
        Accessible.name: Tr.t("Search city")
        onTextEdited: typing.restart()
    }
    Tx { visible: pg.status === "done" && !pg.results.length; text: Tr.t("Nothing found."); dim: true }
    Tx { visible: pg.status === "failed"; text: Tr.t("Couldn't reach the weather service."); color: Theme.danger }
    Repeater {
        model: pg.results
        Place {
            required property var modelData
            place: modelData
            onClicked: {
                Cfg.v.weatherPlace = W.place(modelData)
                Cfg.v.weatherAuto = false
                search.text = ""
                pg.status = ""
                pg.results = [] // last: this row goes with it
            }
        }
    }
    Line {
        label: Tr.t("Automatic by IP")
        hint: Tr.t("Sends your IP address to an outside service (ipapi.co) to find your city.")
        Swt { a11y: Tr.t("Automatic by IP"); checked: Cfg.v.weatherAuto; onToggled: Cfg.v.weatherAuto = checked }
    }

    Sec { title: Tr.t("Display") }
    Line {
        label: Tr.t("Unit")
        Seg { options: ["°C", "°F"]; current: Cfg.v.weatherUnit === "f" ? 1 : 0; onPicked: i => Cfg.v.weatherUnit = i ? "f" : "c" }
    }
    Line {
        label: Tr.t("Show in the island")
        Swt { a11y: Tr.t("Show in the island"); checked: Cfg.island.includes("weather"); onToggled: Cfg.v.island = Pins.set(Cfg.island, "weather", checked) }
    }
}
