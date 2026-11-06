import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "weather.js" as W

// The forecast, dropping from the island's weather chip like the music card. Scrolls when the screen is short.
Item {
    id: card
    property bool open: false
    property real maxHeight: 800
    readonly property var d: Weather.data
    height: open && d ? Math.min(flick.contentHeight, maxHeight) : 0
    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    clip: true

    function deg(v) { return v === null || v === undefined ? "–" : v + "°" }
    function rain(v) { return v >= 20 ? v + "%" : "" }
    function dayName(day, index, format) {
        if (index === 0) return Tr.t("Today")
        const s = Tr.date(W.localDate(day.date), format).replace(/\./g, "")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    component Caption: Tx { size: 12; dim: true; font.weight: Font.Bold; font.letterSpacing: 1; font.capitalization: Font.AllUppercase; Layout.topMargin: 4; Accessible.role: Accessible.Heading; Accessible.name: text }
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property string value: ""
        implicitWidth: pillRow.implicitWidth + 24; implicitHeight: 34; radius: 17
        color: Theme.hover
        Accessible.role: Accessible.StaticText
        Accessible.name: label + ": " + value
        RowLayout {
            id: pillRow; anchors.centerIn: parent; spacing: 6
            Ic { name: pill.icon; size: 16; color: Theme.muted }
            Tx { text: pill.label; dim: true; size: 14 }
            Tx { text: pill.value; strong: true; size: 14 }
        }
    }

    Flickable {
        id: flick
        width: parent.width; height: Math.min(contentHeight, card.maxHeight)
        contentWidth: width
        contentHeight: body.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff; width: 6 }
        ColumnLayout {
            id: body
            x: 20; y: 20; width: flick.width - 40
            spacing: 14

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Ic { name: "mapPin"; size: 18; color: Theme.muted }
                Tx { text: card.d?.place ?? ""; strong: true; size: 17; Layout.fillWidth: true }
                Btn {
                    variant: "solid"; icon: "sliders"; implicitWidth: 38; implicitHeight: 38
                    a11y: Tr.t("Location and units")
                    onClicked: Ui.show("clima")
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 16
                Accessible.role: Accessible.StaticText
                Accessible.name: card.deg(card.d?.temp) + ", " + Tr.t(card.d?.label ?? "")
                Ic { name: card.d?.icon ?? ""; size: 64 }
                Tx { text: card.deg(card.d?.temp); size: 72; font.weight: Font.Bold }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Tx { text: Tr.t(card.d?.label ?? ""); size: 17; strong: true; Layout.fillWidth: true }
                    Tx { text: Tr.t("Feels like %1").arg(card.deg(card.d?.feels)); dim: true; Layout.fillWidth: true }
                    Tx { text: Tr.t("High %1 · Low %2").arg(card.deg(card.d?.high)).arg(card.deg(card.d?.low)); dim: true; Layout.fillWidth: true }
                }
            }

            Flow {
                Layout.fillWidth: true; spacing: 8
                Pill { icon: "droplet"; label: Tr.t("Humidity"); value: card.d?.humidity == null ? "–" : card.d.humidity + "%" }
                Pill { icon: "wind"; label: Tr.t("Wind"); value: card.d?.wind == null ? "–" : card.d.wind + (card.d.unit === "f" ? " mph" : " km/h") }
            }

            Caption { text: Tr.t("Next hours"); visible: (card.d?.hours ?? []).length > 0 }
            Rectangle {
                visible: (card.d?.hours ?? []).length > 0
                Layout.fillWidth: true; implicitHeight: hours.implicitHeight + 24; radius: Theme.radiusSmall
                color: Theme.hover
                Row {
                    id: hours
                    x: 6; width: parent.width - 12; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: card.d?.hours ?? []
                        ColumnLayout {
                            id: hour
                            required property var modelData
                            required property int index
                            readonly property string name: index === 0 ? Tr.t("Now") : Tr.date(W.localDate(modelData.time), "h AP")
                            width: hours.width / Math.max(1, card.d?.hours.length ?? 1)
                            spacing: 6
                            Accessible.role: Accessible.StaticText
                            Accessible.name: name + ": " + Tr.t(modelData.label) + ", " + card.deg(modelData.temp) + (card.rain(modelData.rain) ? ", " + Tr.t("rain %1%").arg(modelData.rain) : "")
                            Tx { text: hour.name; size: 13; dim: true; Layout.alignment: Qt.AlignHCenter }
                            Ic { name: hour.modelData.icon; size: 22; Layout.alignment: Qt.AlignHCenter }
                            Tx { text: card.deg(hour.modelData.temp); size: 15; strong: true; Layout.alignment: Qt.AlignHCenter }
                            Tx { text: card.rain(hour.modelData.rain); size: 12; color: Theme.accent; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }

            Caption { text: Tr.t("7 days"); visible: (card.d?.days ?? []).length > 0 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Repeater {
                    model: card.d?.days ?? []
                    RowLayout {
                        id: day
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true; Layout.preferredHeight: 36
                        spacing: 10
                        Accessible.role: Accessible.StaticText
                        Accessible.name: Tr.t("%1: %2, low %3, high %4").arg(card.dayName(modelData, index, "dddd")).arg(Tr.t(modelData.label)).arg(card.deg(modelData.low)).arg(card.deg(modelData.high))
                            + (card.rain(modelData.rain) ? ", " + Tr.t("rain %1%").arg(modelData.rain) : "")
                        Tx { text: card.dayName(day.modelData, day.index, "ddd"); Layout.preferredWidth: 64 }
                        Ic { name: day.modelData.icon; size: 20 }
                        Tx { text: card.rain(day.modelData.rain); size: 12; color: Theme.accent; Layout.preferredWidth: 34 }
                        Tx { text: card.deg(day.modelData.low); dim: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 30 }
                        Item {
                            Layout.fillWidth: true; implicitHeight: 6
                            Rectangle { anchors.fill: parent; radius: 3; color: Theme.line }
                            Rectangle {
                                width: Math.max(6, parent.width * (day.modelData.to - day.modelData.from)); height: 6; radius: 3
                                x: Math.min(parent.width * day.modelData.from, parent.width - width)
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Theme.accent }
                                    GradientStop { position: 1; color: "#F5D38C" }
                                }
                            }
                        }
                        Tx { text: card.deg(day.modelData.high); strong: true; Layout.preferredWidth: 30 }
                    }
                }
            }

            Tx { text: Tr.t("Data: Open-Meteo"); dim: true; size: 12; Layout.alignment: Qt.AlignRight }
        }
    }
}
