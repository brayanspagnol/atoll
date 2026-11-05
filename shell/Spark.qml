import QtQuick

// Single-series area chart with crosshair. Title names the series, so no legend (single series).
Item {
    id: c
    property var values: []
    property real max: 100
    property int capacity: 150
    property var fmt: v => Math.round(v) + "%"
    property string title: ""
    property string value: ""
    property int stepSeconds: 2
    implicitHeight: 118
    Accessible.role: Accessible.Chart
    Accessible.name: title + ": " + value
    readonly property real peak: Math.max(max, ...(values.length ? values : [0]))
    onValuesChanged: cv.requestPaint()
    Connections { target: Theme; function onAccentChanged() { cv.requestPaint() } function onLineChanged() { cv.requestPaint() } }
    Tx { id: tt; text: c.title; dim: true; size: 13 }
    Tx { anchors.right: parent.right; text: c.value; mono: true; size: 14; strong: true; anchors.verticalCenter: tt.verticalCenter }
    Canvas {
        id: cv
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: tt.bottom; topMargin: 6 }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const x = getContext("2d"), v = c.values, w = width, h = height
            x.reset()
            x.strokeStyle = Theme.line; x.lineWidth = 1
            x.beginPath(); x.moveTo(0, h - 0.5); x.lineTo(w, h - 0.5); x.stroke()
            if (v.length < 2) return
            const px = i => w - (v.length - 1 - i) * w / (c.capacity - 1)
            const py = n => h - 2 - (n / c.peak) * (h - 6)
            x.beginPath(); x.moveTo(px(0), py(v[0]))
            for (let i = 1; i < v.length; i++) x.lineTo(px(i), py(v[i]))
            x.strokeStyle = Theme.accent; x.lineWidth = 2; x.lineJoin = "round"; x.stroke()
            x.lineTo(w, h); x.lineTo(px(0), h); x.closePath()
            x.globalAlpha = 0.14; x.fillStyle = Theme.accent; x.fill(); x.globalAlpha = 1
        }
        MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true }
        readonly property int idx: {
            const n = c.values.length, i = n - 1 - Math.round((width - hov.mouseX) * (c.capacity - 1) / Math.max(1, width))
            return i >= 0 && i < n ? i : -1
        }
        Rectangle {
            visible: hov.containsMouse && cv.idx >= 0
            x: hov.mouseX; width: 1; height: parent.height; color: Theme.muted
        }
        Rectangle {
            visible: hov.containsMouse && cv.idx >= 0
            x: Math.min(hov.mouseX + 8, parent.width - width); y: 4
            width: tip.implicitWidth + 12; height: 22; radius: 4; color: Theme.raised
            Tx {
                id: tip; anchors.centerIn: parent; mono: true; size: 11
                text: cv.idx >= 0 ? c.fmt(c.values[cv.idx]) + " · há " + (c.values.length - 1 - cv.idx) * c.stepSeconds + " s" : ""
            }
        }
    }
}
