import QtQuick
import QtQuick.Layouts
import Quickshell
import "displays.js" as D

Item {
    id: root
    Component.onCompleted: { if (!Displays.dirty && !Displays.confirming) Displays.refresh(); Bright.refresh() }
    readonly property var cur: Displays.current
    readonly property var curMode: cur?.modes.find(o => o.res === cur.w + "x" + cur.h) ?? null
    readonly property int externalIndex: Displays.monitors.filter(m => !m.laptop).findIndex(m => m.name === cur?.name)

    component Chips: Flow {
        property string label: ""
        property var options: []  // [{ text, on, pick }]
        Layout.fillWidth: true; Layout.preferredWidth: 1
        spacing: 6
        Repeater {
            model: parent.options
            Btn {
                required property var modelData
                text: modelData.text
                variant: modelData.on ? "solid" : "ghost"
                onClicked: modelData.pick()
            }
        }
    }
    component Group: ColumnLayout {
        property string label: ""
        default property alias content: slot.data
        Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
        spacing: 8
        Tx { text: parent.label; dim: true; size: 13; Layout.fillWidth: true }
        ColumnLayout { id: slot; Layout.fillWidth: true; spacing: 0 }
    }
    component Line: RowLayout {
        property string label: ""
        property string hint: ""
        Layout.fillWidth: true; Layout.minimumHeight: 44; spacing: 16
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: label; Layout.fillWidth: true }
            Tx { visible: !!hint; text: hint; dim: true; size: 13; Layout.fillWidth: true }
        }
    }

    Page {
        anchors { fill: parent; bottomMargin: bar.visible ? bar.height + 12 : 0 }
        title: Tr.t("Monitor")
        subtitle: Tr.t("Drag the screens to position them. Click one to configure it.")

        Sec {
            title: Tr.t("Layout")
            Btn { text: Tr.t("Identify screens"); onClicked: Displays.identify() }
        }
        Rectangle {
            id: map
            Layout.fillWidth: true
            implicitHeight: 300
            radius: 18
            color: Theme.field
            border.width: activeFocus ? 2 : 1
            border.color: activeFocus ? Theme.ink : Theme.line
            clip: true
            activeFocusOnTab: true
            Accessible.role: Accessible.Graphic
            Accessible.name: Tr.t("Layout")
            // Arrow keys do what dragging does, for the selected screen.
            function nudge(dx, dy) {
                if (!root.cur?.on || root.cur.mirror) return
                Displays.patch(root.cur.name, { x: root.cur.x + dx, y: root.cur.y + dy })
            }
            Keys.onLeftPressed: nudge(-100, 0)
            Keys.onRightPressed: nudge(100, 0)
            Keys.onUpPressed: nudge(0, -100)
            Keys.onDownPressed: nudge(0, 100)

            readonly property var placed: D.placed(Displays.monitors)
            readonly property var fit: {
                if (!placed.length) return { k: 1, ox: 0, oy: 0 }
                const left = Math.min(...placed.map(m => m.x)), top = Math.min(...placed.map(m => m.y))
                const right = Math.max(...placed.map(m => m.x + D.sizeOf(m)[0])), bottom = Math.max(...placed.map(m => m.y + D.sizeOf(m)[1]))
                const k = Math.min((width - 80) / (right - left), (height - 60) / (bottom - top))
                return { k, ox: (width - (right - left) * k) / 2 - left * k, oy: (height - (bottom - top) * k) / 2 - top * k }
            }
            // Keeps the scale still during a drag, or the screen would run away from the pointer.
            property var dragFit: null
            readonly property var view: dragFit ?? fit

            Repeater {
                model: map.placed
                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool sel: modelData.name === root.cur?.name
                    readonly property var size: D.sizeOf(modelData)
                    x: modelData.x * map.view.k + map.view.ox
                    y: modelData.y * map.view.k + map.view.oy
                    width: size[0] * map.view.k
                    height: size[1] * map.view.k
                    radius: 10
                    color: sel ? Theme.accentSoft : Theme.raised
                    border.width: 2
                    border.color: sel ? Theme.accent : Theme.lineStrong
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 2
                        Tx { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Displays.monitors.findIndex(m => m.name === tile.modelData.name) + 1; size: 30; strong: true }
                        Tx { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Displays.labelOf(tile.modelData); size: 13; strong: true }
                        Tx { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: tile.modelData.w + "×" + tile.modelData.h + " · " + tile.modelData.rate.replace(/\.00$/, "") + " Hz"; size: 11; mono: true }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: pressedName ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property string pressedName: ""
                property real startX: 0
                property real startY: 0
                property real fromX: 0
                property real fromY: 0
                onPressed: mouse => {
                    map.forceActiveFocus()
                    const v = map.view
                    const hit = map.placed.slice().reverse().find(m => {
                        const [w, h] = D.sizeOf(m), x = m.x * v.k + v.ox, y = m.y * v.k + v.oy
                        return mouse.x >= x && mouse.x <= x + w * v.k && mouse.y >= y && mouse.y <= y + h * v.k
                    })
                    if (!hit) return
                    Displays.selected = hit.name
                    map.dragFit = v
                    pressedName = hit.name
                    startX = mouse.x; startY = mouse.y
                    fromX = hit.x; fromY = hit.y
                }
                onPositionChanged: mouse => {
                    if (!pressedName) return
                    Displays.patch(pressedName, { x: Math.round(fromX + (mouse.x - startX) / map.view.k), y: Math.round(fromY + (mouse.y - startY) / map.view.k) }, false)
                }
                onReleased: {
                    if (!pressedName) return
                    Displays.patch(pressedName, {})
                    pressedName = ""
                    map.dragFit = null
                }
            }
        }
        Flow {
            Layout.fillWidth: true; spacing: 8
            visible: Displays.monitors.length > 1
            Btn { text: Tr.t("Extend"); onClicked: Displays.preset("extend") }
            Btn { visible: Displays.hasLaptop; text: Tr.t("External only"); onClicked: Displays.preset("external") }
            Btn { visible: Displays.hasLaptop; text: Tr.t("Laptop only"); onClicked: Displays.preset("laptop") }
            Btn { text: Tr.t("Mirror"); onClicked: Displays.preset("mirror") }
        }

        Sec { title: Tr.t("Selected screen") }
        Flow {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: Displays.monitors
                Btn {
                    required property var modelData
                    required property int index
                    readonly property string state_: !modelData.on ? " · " + Tr.t("off") : modelData.mirror ? " · " + Tr.t("mirrored") : modelData.parked ? " · " + Tr.t("lid closed") : ""
                    text: (index + 1) + ". " + Displays.labelOf(modelData) + state_
                    variant: modelData.name === root.cur?.name ? "solid" : "ghost"
                    onClicked: Displays.selected = modelData.name
                }
            }
        }
        Tx { visible: !!root.cur; text: root.cur ? root.cur.name + (root.cur.on && !root.cur.mirror ? " · " + root.cur.x + ", " + root.cur.y : "") : ""; mono: true; size: 13; dim: true }

        Line {
            label: Tr.t("Screen on")
            hint: Tr.t("Turning it off moves its windows to another screen")
            Swt {
                a11y: Tr.t("Screen on")
                checked: root.cur?.on ?? false
                enabled: !root.cur?.on || Displays.count_on > 1
                onToggled: Displays.setOn(root.cur.name, checked)
            }
        }
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 24; rowSpacing: 18
            visible: root.cur?.on ?? false
            Group {
                label: Tr.t("Resolution")
                Chips {
                    options: (root.cur?.modes ?? []).map(o => ({ text: o.res.replace("x", "×"), on: o.res === root.cur.w + "x" + root.cur.h, pick: () => {
                        const [w, h] = o.res.split("x").map(Number)
                        Displays.patch(root.cur.name, { w, h, rate: o.rates[0] })
                    } }))
                }
            }
            Group {
                label: Tr.t("Refresh rate")
                Chips {
                    options: (root.curMode?.rates ?? []).map(r => ({ text: r.replace(/\.00$/, "") + " Hz", on: r === root.cur.rate, pick: () => Displays.patch(root.cur.name, { rate: r }) }))
                }
            }
            Group {
                label: Tr.t("Scale")
                Chips {
                    options: [1, 1.25, 1.5, 1.75, 2].map(v => ({ text: (v * 100) + "%", on: v === root.cur?.scale, pick: () => Displays.patch(root.cur.name, { scale: v }) }))
                }
            }
            Group {
                label: Tr.t("Rotation")
                Chips {
                    options: [0, 1, 2, 3].map(v => ({ text: (v * 90) + "°", on: v === root.cur?.rot, pick: () => Displays.patch(root.cur.name, { rot: v }) }))
                }
            }
            Group {
                visible: Displays.monitors.length > 1
                label: Tr.t("Mirror")
                Chips {
                    options: [{ text: Tr.t("No"), on: !root.cur?.mirror, pick: () => Displays.patch(root.cur.name, { mirror: "" }) }].concat(
                        Displays.monitors.filter(m => m.name !== root.cur?.name && m.on).map(m => ({ text: Displays.labelOf(m), on: root.cur?.mirror === m.name, pick: () => Displays.patch(root.cur.name, { mirror: m.name }) })))
                }
            }
            Group {
                label: Tr.t("Workspaces on this screen")
                Chips {
                    options: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(n => ({ text: String(n), on: Displays.workspaces[n] === root.cur?.name, pick: () => Displays.assign(String(n), root.cur.name) }))
                }
            }
        }
        Line {
            visible: root.cur?.on ?? false
            label: Tr.t("Variable refresh rate (VRR)")
            Swt { a11y: Tr.t("Variable refresh rate (VRR)"); checked: root.cur?.vrr ?? false; onToggled: Displays.patch(root.cur.name, { vrr: checked }, false) }
        }
        Line {
            visible: root.cur?.on ?? false
            label: Tr.t("10-bit color")
            Swt { a11y: Tr.t("10-bit color"); checked: root.cur?.bit ?? false; onToggled: Displays.patch(root.cur.name, { bit: checked }, false) }
        }
        Line {
            // shortcut: DDC reaches the first external monitor only; map outputs to DDC displays when someone has two.
            visible: (root.cur?.on ?? false) && (root.cur.laptop ? Bright.panel >= 0 : root.externalIndex === 0 && Bright.external >= 0)
            label: Tr.t("Brightness")
            Sld {
                Layout.preferredWidth: 260; a11y: Tr.t("Brightness"); from: 1; to: 100; stepSize: root.cur?.laptop ? 1 : 5
                value: root.cur?.laptop ? Bright.panel : Bright.external
                onPressedChanged: if (!pressed && !root.cur.laptop) Bright.setExternal(value)
                onMoved: if (root.cur.laptop) Bright.setPanel(Math.round(value))
            }
            Tx { mono: true; text: (root.cur?.laptop ? Bright.panel : Bright.external) + "%"; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
        }

        Sec { visible: Displays.hasLaptop; title: Tr.t("Laptop") }
        Line {
            visible: Displays.hasLaptop
            label: Tr.t("When closing the lid")
            hint: Tr.t("With an external monitor connected")
            Chips {
                Layout.fillWidth: false
                Layout.preferredWidth: 360
                options: [["off", Tr.t("Turn off screen")], ["suspend", Tr.t("Suspend")], ["none", Tr.t("Nothing")]].map(o => ({ text: o[1], on: Displays.lid === o[0], pick: () => Displays.lid = o[0] }))
            }
        }
    }

    Rectangle {
        id: bar
        visible: Displays.dirty && !Displays.confirming
        anchors { left: parent.left; right: parent.right; rightMargin: 14; bottom: parent.bottom }
        height: 64
        radius: 16
        color: Theme.glassStrong
        border.width: 1; border.color: Theme.lineStrong
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12
            spacing: 10
            Tx { text: Tr.t("Changes not applied yet"); dim: true; Layout.fillWidth: true }
            Btn { text: Tr.t("Undo"); onClicked: Displays.revert() }
            Btn { text: Tr.t("Apply"); variant: "solid"; onClicked: Displays.apply() }
        }
    }
}
