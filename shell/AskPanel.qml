import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell

// The assistant's bar and conversation, inside Ask's window. The bar grows out of the island; the answer drops below it.
Item {
    id: panel
    property bool shown: false
    property bool settled: false // after the opening: items arriving now drop in one by one, not in a cascade
    // The screen's width, from the window: right after the window shows again its own width can still be 0,
    // and a bar sized from that grew to nothing.
    property real span: 0
    property real islandWidth: 430 // the island on this screen: where the bar starts and ends
    readonly property real barWidth: Math.min(1000, Math.max(width, span) - 80)
    readonly property real listWidth: Math.min(760, barWidth - 40)
    // The visible pieces, for the window's input mask, and the text field.
    readonly property Item barItem: bar
    readonly property Item bodyItem: body
    readonly property Item input: field
    readonly property bool ready: Assistant.providers.some(p => p.installed)
    readonly property var current: Assistant.providers.find(p => p.id === Assistant.provider) ?? null
    property var expanded: ({}) // runs of steps opened past their last three, by key
    readonly property Item menuItem: menu
    property bool menuOpen: false // the model and effort menu, under the pill that says who answers
    property bool past: false // the past conversations in place of this one
    property string pastQuery: ""
    readonly property var pastShown: {
        const q = pastQuery.trim().toLowerCase()
        return (Assistant.history ?? []).filter(h => !q || h.title.toLowerCase().includes(q))
    }
    // The conversation on screen belongs to another tool than the one that would answer now.
    readonly property bool stale: !!Assistant.session && !!Assistant.sessionProvider && Assistant.sessionProvider !== Assistant.provider

    function openMenu() {
        const at = who.mapToItem(panel, who.width, who.height)
        menu.x = Math.max(8, at.x - menu.width)
        menu.y = at.y + 10
        Assistant.listModels()
        menuOpen = true
        menu.first().forceActiveFocus()
    }
    function closeMenu() { menuOpen = false; who.forceActiveFocus() }
    function openPast(id) {
        Assistant.open(id)
        past = false
        expanded = {}
        list.stick = true
        field.forceActiveFocus()
    }
    // "5 min ago", "Yesterday", "Nov 3"
    function ago(ms) {
        const min = Math.floor((Date.now() - ms) / 60000)
        if (min < 1) return Tr.t("Just now")
        if (min < 60) return Tr.t("%1 min ago").arg(min)
        if (min < 24 * 60) return Tr.t("%1 h ago").arg(Math.floor(min / 60))
        if (min < 48 * 60) return Tr.t("Yesterday")
        if (min < 7 * 24 * 60) return Tr.t("%1 days ago").arg(Math.floor(min / 1440))
        return Tr.date(new Date(ms), "MMM d").replace(/\./g, "")
    }

    function send() {
        const q = field.text.trim()
        if (!q || Assistant.busy || !ready) return
        Assistant.ask(q)
        field.text = ""
        list.stick = true
    }
    // Whatever the answer holds, only two kinds of action: open a screen of the control center, or launch an app by its desktop id.
    function actionsOf(card) {
        const acts = Array.isArray(card?.actions) ? card.actions : []
        return acts.filter(a => a && typeof a.label === "string" && a.label.trim() !== ""
            && (typeof a.page === "string" ? Ui.pages.some(p => p.id === a.page) : typeof a.app === "string" && /^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(a.app))).slice(0, 3)
    }
    function run(a) {
        if (typeof a.page === "string") Ui.show(a.page) // the control center takes the screen, which closes this
        else { Quickshell.execDetached(["gtk-launch", a.app]); Ui.askOpen = false }
    }
    // The items as drawn: a long run of steps keeps its last three, behind a chip that opens the rest.
    readonly property var view: {
        const items = Assistant.items ?? [], s = Assistant.session, rows = [], map = {}
        const add = r => { rows.push(r); map[r.key] = r }
        let lastDenied = -1
        items.forEach((it, i) => { if (it?.kind === "denied") lastDenied = i })
        for (let i = 0; i < items.length; i++) {
            const kind = items[i]?.kind ?? ""
            if (kind !== "step") { add({ key: s + ":" + i, i, kind, live: i === lastDenied }); continue }
            let end = i
            while (end + 1 < items.length && items[end + 1]?.kind === "step") end++
            const run = s + ":" + i, open = !!expanded[run], extra = end - i + 1 - 3
            if (extra > 0) add({ key: s + ":more" + i, kind: "more", run, count: extra, open })
            for (let j = extra > 0 && !open ? end - 2 : i; j <= end; j++) add({ key: s + ":" + j, i: j, kind: "step", running: Assistant.busy && j === items.length - 1 })
            i = end
        }
        return { rows, map }
    }

    onShownChanged: if (shown) { leave.stop(); grow.restart(); field.forceActiveFocus() } else { grow.stop(); leave.restart(); menuOpen = false }
    // Opening: the bar appears exactly over the island and cross-fades with it, then grows; the conversation
    // waits until the bar has nearly settled, so nothing outruns its background.
    SequentialAnimation {
        id: grow
        PropertyAction { target: bar; property: "width"; value: panel.islandWidth }
        PropertyAction { target: bar; property: "y"; value: 14 }
        PropertyAction { target: bar; property: "height"; value: 56 }
        ParallelAnimation {
            NumberAnimation { target: bar; property: "opacity"; to: 1; duration: 160; easing.type: Easing.InOutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 60 }
                ParallelAnimation {
                    NumberAnimation { target: bar; property: "width"; to: panel.barWidth; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    NumberAnimation { target: bar; property: "y"; to: 12; duration: 400; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bar; property: "height"; to: 60; duration: 400; easing.type: Easing.OutCubic }
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 300 }
                NumberAnimation { target: barRow; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 520 }
                ParallelAnimation {
                    NumberAnimation { target: body; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bodyShift; property: "y"; from: -16; to: 0; duration: 420; easing.type: Easing.OutCubic }
                }
            }
        }
        ScriptAction { script: { bar.width = Qt.binding(() => panel.barWidth); panel.settled = true } }
    }
    // Closing, the same way back: the conversation lifts away, the bar shrinks into the island's exact shape,
    // and only then do the two cross-fade (Island.qml waits for it).
    ParallelAnimation {
        id: leave
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InOutCubic }
        NumberAnimation { target: bodyShift; property: "y"; to: -12; duration: 240; easing.type: Easing.InOutCubic }
        NumberAnimation { target: barRow; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InOutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            ParallelAnimation {
                NumberAnimation { target: bar; property: "width"; to: panel.islandWidth; duration: 360; easing.type: Easing.InOutCubic }
                NumberAnimation { target: bar; property: "y"; to: 14; duration: 360; easing.type: Easing.InOutCubic }
                NumberAnimation { target: bar; property: "height"; to: 56; duration: 360; easing.type: Easing.InOutCubic }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 400 }
            NumberAnimation { target: bar; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InOutQuad }
        }
    }

    Keys.onEscapePressed: Ui.askOpen = false

    // ── Pieces ──────────────────────────────────────────────────────────────

    // Plain text only, selectable: an answer can quote anything, and none of it may style itself or link out.
    component Body: TextEdit {
        readOnly: true
        selectByMouse: true
        textFormat: TextEdit.PlainText
        wrapMode: TextEdit.Wrap
        color: Theme.ink
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentInk
        font.family: Theme.sans
        font.pixelSize: 16
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    component Spinner: Shape {
        implicitWidth: 16; implicitHeight: 16
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.accent; strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 8; centerY: 8; radiusX: 6.5; radiusY: 6.5; startAngle: 0; sweepAngle: 270 }
        }
        RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite }
    }
    // A card unfolds from the top: its height opens over its content. The list's entry animation drives reveal.
    component Card: Frost {
        id: card
        default property alias content: inner.data
        property real reveal: 1
        radius: 28
        clip: true
        height: (inner.implicitHeight + 48) * reveal
        ColumnLayout { id: inner; x: 28; y: 24; width: card.width - 56; spacing: 18 }
    }
    component Pill: Btn {
        radius: 22; implicitHeight: 44
        color: variant === "solid" ? (pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent) : hovered ? Theme.raisedHover : Theme.raised
    }

    component UserBubble: Item {
        id: u
        property var item
        height: bubble.height
        Frost {
            id: bubble
            anchors.right: parent.right
            width: Math.min(u.width * 0.78, said.implicitWidth + 36)
            height: said.implicitHeight + 24
            radius: 22
            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.accentSoft }
            Body {
                id: said
                x: 18; y: 12; width: bubble.width - 36
                text: u.item?.text ?? ""
            }
        }
    }

    component Step: Item {
        id: st
        property var item
        property bool running: false
        height: 40
        Frost {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(st.width, stepRow.implicitWidth + 32)
            height: 40; radius: 20
            Accessible.role: Accessible.StaticText
            Accessible.name: stepText.text + (st.item?.detail ? ", " + stepDetail.text : "")
            RowLayout {
                id: stepRow
                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 18; spacing: 10
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28; radius: 14
                    color: st.running ? Theme.raised : Qt.rgba(Theme.good.r, Theme.good.g, Theme.good.b, 0.18)
                    Ic { anchors.centerIn: parent; visible: !st.running; name: "check"; size: 14; color: Theme.good }
                    Spinner { anchors.centerIn: parent; visible: st.running }
                }
                Tx { id: stepText; text: Tr.t(st.item?.text ?? ""); size: 14; Layout.maximumWidth: implicitWidth }
                Tx {
                    id: stepDetail
                    visible: !!st.item?.detail
                    text: String(st.item?.detail ?? "").replace(/\s+/g, " ").trim()
                    mono: true; dim: true; size: 12
                    Layout.fillWidth: true; Layout.maximumWidth: implicitWidth
                }
            }
        }
    }

    component More: Item {
        id: mo
        property var row
        height: 32
        Rectangle {
            id: chip
            anchors.horizontalCenter: parent.horizontalCenter
            width: moreRow.implicitWidth + 24; height: 32; radius: 16
            color: mm.containsMouse ? Theme.raisedHover : Theme.raised
            border.width: activeFocus ? 2 : 0; border.color: Theme.ink
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: moreText.text
            Accessible.onPressAction: toggle()
            Keys.onSpacePressed: toggle()
            Keys.onReturnPressed: toggle()
            function toggle() { panel.expanded = Object.assign({}, panel.expanded, { [mo.row.run]: !mo.row.open }) }
            RowLayout {
                id: moreRow; anchors.centerIn: parent; spacing: 6
                Tx { id: moreText; text: mo.row?.open ? Tr.t("Fewer steps") : Tr.t("%1 steps").arg(mo.row?.count ?? 0); size: 13; dim: true }
                Ic { name: mo.row?.open ? "up" : "down"; size: 14; color: Theme.muted }
            }
            MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.toggle() }
        }
    }

    component Answer: Card {
        id: an
        property var item
        Body { Layout.fillWidth: true; text: an.item?.text ?? "" }
    }

    component Visual: Card {
        id: vis
        property var item
        readonly property var c: item?.card ?? ({})
        readonly property var acts: panel.actionsOf(c)
        readonly property var bars: (Array.isArray(c.bars) ? c.bars : []).slice(0, 6)
        readonly property real ringValue: clamp(c.ring?.value)
        // A label with a number ("57%", "9 GB") is the ring's big text; a word ("memory") goes under the percentage.
        readonly property string ringLabel: c.ring?.label ?? ""
        readonly property bool ringSays: /\d/.test(ringLabel)
        property real grow: 0 // ring and bars fill once the card has opened
        function clamp(v) { return Math.max(0, Math.min(1, Number(v) || 0)) }
        function tone(v) { return v > 0.6 ? Theme.warn : Theme.accent }
        readonly property bool open: reveal > 0.4 // ring, bars and buttons start once the card has mostly unfolded
        SequentialAnimation on grow {
            running: vis.open
            PauseAnimation { duration: 150 }
            NumberAnimation { from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }
        }
        Body { visible: !!vis.item?.text; Layout.fillWidth: true; text: vis.item?.text ?? "" }
        RowLayout {
            Layout.fillWidth: true; spacing: 24
            Item {
                visible: !!vis.c.ring
                implicitWidth: 116; implicitHeight: 116
                Accessible.role: Accessible.ProgressBar
                Accessible.name: vis.ringSays ? vis.ringLabel : vis.ringLabel + " " + Math.round(vis.ringValue * 100) + "%"
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.raised; strokeWidth: 12; fillColor: "transparent"
                        PathAngleArc { centerX: 58; centerY: 58; radiusX: 48; radiusY: 48; startAngle: -90; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: vis.tone(vis.ringValue); strokeWidth: 12; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 58; centerY: 58; radiusX: 48; radiusY: 48; startAngle: -90; sweepAngle: 360 * vis.ringValue * vis.grow }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    opacity: Math.min(1, vis.grow * 3)
                    Tx { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, 90); text: vis.ringSays ? vis.ringLabel : Math.round(vis.ringValue * vis.grow * 100) + "%"; size: vis.ringSays && vis.ringLabel.length > 4 ? 20 : 28; strong: true; horizontalAlignment: Text.AlignHCenter }
                    Tx { anchors.horizontalCenter: parent.horizontalCenter; visible: !vis.ringSays && !!text; width: Math.min(implicitWidth, 84); text: vis.ringLabel; size: 12; dim: true; horizontalAlignment: Text.AlignHCenter }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                // The title, with a light that passes over it now and then.
                Item {
                    Layout.fillWidth: true; implicitHeight: title.implicitHeight
                    Tx {
                        id: title; width: parent.width
                        text: vis.c.title ?? ""; size: 28; strong: true; wrapMode: Text.Wrap; maximumLineCount: 3
                        Accessible.role: Accessible.Heading; Accessible.name: text
                    }
                    Item {
                        id: band
                        property real sweep: -90
                        x: sweep; width: 90; height: parent.height
                        clip: true
                        Tx {
                            x: -band.x; width: title.width
                            text: title.text; size: 28; strong: true; wrapMode: Text.Wrap; maximumLineCount: 3
                            color: Qt.tint(Theme.ink, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7))
                            Accessible.ignored: true
                        }
                        SequentialAnimation on sweep {
                            running: panel.shown; loops: Animation.Infinite
                            PauseAnimation { duration: 1500 }
                            NumberAnimation { from: -90; to: title.width; duration: 1500; easing.type: Easing.InOutSine }
                            PauseAnimation { duration: 2500 }
                        }
                    }
                }
                Tx { visible: !!vis.c.subtitle; text: vis.c.subtitle ?? ""; dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
        }
        ColumnLayout {
            visible: vis.bars.length > 0
            Layout.fillWidth: true; spacing: 11
            Repeater {
                model: vis.bars
                RowLayout {
                    id: meter
                    required property var modelData
                    required property int index
                    readonly property real value: vis.clamp(modelData?.value)
                    property real fill: 0
                    SequentialAnimation on fill {
                        running: vis.open
                        PauseAnimation { duration: 250 + meter.index * 110 }
                        NumberAnimation { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
                    }
                    Layout.fillWidth: true; spacing: 14
                    Accessible.role: Accessible.StaticText
                    Accessible.name: (modelData?.label ?? "") + ", " + (modelData?.text ?? "")
                    Tx { text: meter.modelData?.label ?? ""; strong: true; Layout.preferredWidth: 170 }
                    Item {
                        Layout.fillWidth: true; implicitHeight: 10
                        Rectangle { anchors.fill: parent; radius: 5; color: Theme.raised }
                        Rectangle {
                            visible: meter.fill > 0 && meter.value > 0
                            width: Math.max(10, parent.width * meter.value * meter.fill); height: 10; radius: 5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.darker(vis.tone(meter.value), 1.25) }
                                GradientStop { position: 1; color: vis.tone(meter.value) }
                            }
                        }
                    }
                    Tx { text: meter.modelData?.text ?? ""; strong: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 80 }
                }
            }
        }
        Flow {
            visible: vis.acts.length > 0
            Layout.fillWidth: true; spacing: 10
            Repeater {
                model: vis.acts
                Pill {
                    required property var modelData
                    required property int index
                    readonly property var action: modelData
                    text: modelData.label
                    variant: index === 0 ? "solid" : "quiet"
                    onClicked: panel.run(modelData)
                    transform: Translate { NumberAnimation on y { running: vis.open; from: 10; to: 0; duration: 400; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    component Denied: Card {
        id: dn
        property var item
        property bool live: false
        readonly property var asks: (Array.isArray(item?.denials) ? item.denials : []).slice(0, 4)
        function said(v) { return v === undefined || v === null ? "" : typeof v === "string" ? v : JSON.stringify(v) }
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Ic { name: "alert"; size: 22; color: Theme.warn }
            Tx { text: Tr.t("Lagu needs your OK"); size: 18; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
        }
        Body { visible: !!dn.item?.text; Layout.fillWidth: true; text: dn.item?.text ?? "" }
        Repeater {
            model: dn.asks
            Rectangle {
                id: ask
                required property var modelData
                readonly property string tool: typeof modelData === "string" ? modelData : dn.said(modelData?.tool)
                readonly property string input: typeof modelData === "string" ? "" : dn.said(modelData?.input).replace(/\s+/g, " ")
                Layout.fillWidth: true; implicitHeight: askCol.implicitHeight + 20; radius: 14
                color: Theme.raised
                Accessible.role: Accessible.StaticText
                Accessible.name: tool + " " + input
                ColumnLayout {
                    id: askCol
                    x: 14; y: 10; width: parent.width - 28; spacing: 2
                    Tx { text: ask.tool; mono: true; strong: true; size: 13; Layout.fillWidth: true }
                    Tx { visible: !!ask.input; text: ask.input; mono: true; dim: true; size: 13; Layout.fillWidth: true }
                }
            }
        }
        RowLayout {
            visible: dn.live
            spacing: 10
            Pill { text: Tr.t("Allow"); variant: "solid"; onClicked: Assistant.allow() }
            Pill { text: Tr.t("Deny"); variant: "quiet"; onClicked: Assistant.deny() }
        }
    }

    component Failure: Card {
        id: fl
        property var item
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Ic { name: "alert"; size: 22; color: Theme.danger }
            Body { Layout.fillWidth: true; text: fl.item?.text || Tr.t("Something went wrong.") }
        }
        Tx { visible: !!fl.item?.detail; text: String(fl.item?.detail ?? ""); mono: true; dim: true; size: 12; wrapMode: Text.Wrap; maximumLineCount: 4; Layout.fillWidth: true }
        Pill { visible: !!fl.item?.login; text: Tr.t("Log in"); variant: "solid"; onClicked: Assistant.login(Assistant.provider) }
    }

    // ── The bar, where the island was ───────────────────────────────────────

    Frost {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        width: 430; height: 60; radius: height / 2
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
        RowLayout {
            id: barRow
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
            spacing: 10
            opacity: 0
            Lagu {
                size: 46
                mood: !panel.ready ? "sleeping" : !Assistant.busy && field.activeFocus && field.text ? "listening" : Assistant.mood
                animate: panel.shown
            }
            TextInput {
                id: field
                Layout.fillWidth: true
                readOnly: !panel.ready
                color: Theme.ink; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                font.family: Theme.sans; font.pixelSize: 17
                clip: true
                focus: true
                Accessible.role: Accessible.EditableText
                Accessible.name: Tr.t("Ask the assistant")
                Component.onCompleted: forceActiveFocus()
                Keys.onReturnPressed: panel.send()
                Keys.onEnterPressed: panel.send()
                Keys.onEscapePressed: Ui.askOpen = false
                Tx {
                    visible: !field.text; size: 17; dim: true; anchors.verticalCenter: parent.verticalCenter
                    width: field.width
                    text: panel.ready ? Tr.t("Ask anything about this computer…") : Tr.t("No assistant installed yet")
                }
            }
            // The past conversations, in place of this one.
            Rectangle {
                id: pastBtn
                visible: panel.ready
                function swap() { panel.past = !panel.past; search.text = ""; if (panel.past && search.visible) search.forceActiveFocus(); else if (!panel.past) field.forceActiveFocus() }
                implicitWidth: 36; implicitHeight: 36; radius: 18
                color: panel.past ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, hm.containsMouse ? 0.3 : 0.2) : hm.containsMouse ? Theme.raisedHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("History")
                Accessible.checkable: true
                Accessible.checked: panel.past
                Accessible.onPressAction: swap()
                Keys.onSpacePressed: swap()
                Keys.onReturnPressed: swap()
                Ic { anchors.centerIn: parent; name: "history"; size: 18; color: panel.past ? Theme.accent : Theme.muted }
                MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pastBtn.swap() }
            }
            // Who answers, and with which model; opens the model and effort menu.
            Rectangle {
                id: who
                visible: !!panel.current
                implicitWidth: whoRow.implicitWidth + 20; implicitHeight: 30; radius: 15
                color: wm.containsMouse || panel.menuOpen ? Theme.raisedHover : Theme.raised
                border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                activeFocusOnTab: true
                Accessible.role: Accessible.ButtonMenu
                Accessible.name: Tr.t("Answered by %1").arg(whoText.text)
                Accessible.onPressAction: panel.openMenu()
                Keys.onSpacePressed: panel.openMenu()
                Keys.onReturnPressed: panel.openMenu()
                RowLayout {
                    id: whoRow; anchors.centerIn: parent; spacing: 6
                    Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: panel.current?.installed ? Theme.good : Theme.muted }
                    Tx { id: whoText; text: (panel.current?.name ?? "") + (Assistant.modelName ? " · " + Assistant.modelName : ""); size: 13; dim: true; Layout.maximumWidth: 260 }
                    Ic { name: "down"; size: 14; color: Theme.muted }
                }
                MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.menuOpen ? panel.closeMenu() : panel.openMenu() }
            }
            // Send, or stop while it works.
            Rectangle {
                id: go
                visible: panel.ready
                readonly property bool stopping: Assistant.busy
                readonly property bool can: stopping || (panel.ready && field.text.trim() !== "")
                implicitWidth: 44; implicitHeight: 44; radius: 22
                color: stopping ? (gm.containsMouse ? Theme.raisedHover : Theme.raised) : gm.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
                opacity: can ? 1 : 0.45
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: stopping ? Tr.t("Stop") : Tr.t("Send")
                Accessible.onPressAction: press()
                Keys.onSpacePressed: press()
                Keys.onReturnPressed: press()
                function press() { if (stopping) Assistant.stop(); else panel.send() }
                Ic { anchors.centerIn: parent; name: go.stopping ? "stop" : "arrowUp"; filled: go.stopping; size: 18; color: go.stopping ? Theme.ink : Theme.accentInk }
                MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: go.press() }
            }
        }
    }

    // ── Below it: the conversation, or how to get an assistant ──────────────

    Column {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.y + bar.height + 12
        width: panel.listWidth
        spacing: 10
        opacity: 0
        transform: Translate { id: bodyShift; y: -12 }

        Card {
            visible: !panel.ready
            width: parent.width
            SequentialAnimation on reveal {
                PauseAnimation { duration: 260 }
                NumberAnimation { from: 0; to: 1; duration: 620; easing.type: Easing.OutQuint }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 18
                Lagu { size: 56; mood: "sleeping"; animate: panel.shown }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Tx { text: Tr.t("No assistant installed yet"); size: 20; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
                    Tx {
                        text: Tr.t("Lagu answers with the Claude Code, Cursor or Codex command line already logged in on this computer. No API keys.")
                        dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                }
            }
            Pill { text: Tr.t("Set up the assistant"); variant: "solid"; onClicked: Ui.show("ia") }
        }

        // The conversation, or the past ones: the two cross-fade and slide a little while the space between them
        // resizes to the one coming in. mix goes from 0 (the conversation) to 1 (the history).
        Item {
            id: stage
            property real mix: panel.past ? 1 : 0
            Behavior on mix { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            readonly property real roomFor: Math.max(160, panel.height - body.y - foot.height - 60)
            width: parent.width
            height: (list.count > 0 ? list.height : 0) * (1 - mix) + pastView.height * mix
            visible: height > 0
            clip: mix > 0 && mix < 1

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, stage.roomFor - (panel.stale ? 30 : 0))
            visible: count > 0 && stage.mix < 1
            opacity: 1 - stage.mix
            transform: Translate { y: -16 * stage.mix }
            clip: true
            spacing: 10
            cacheBuffer: 4000
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Accessible.role: Accessible.List
            Accessible.name: Tr.t("Conversation")
            ScrollBar.vertical: ScrollBar { policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff; width: 6 }
            // Follows the newest item, unless scrolled up to read.
            property bool stick: true
            onMovementEnded: stick = atYEnd
            onContentHeightChanged: if (stick) positionViewAtEnd()
            onHeightChanged: if (stick) positionViewAtEnd()
            model: ScriptModel { values: panel.view.rows; objectProp: "key" }
            delegate: Item {
                id: d
                required property var modelData
                required property int index
                // A kept entry's modelData goes stale, so the fresh row and item come from the key.
                readonly property var row: panel.view.map[modelData.key] ?? modelData
                readonly property var item: Assistant.items[row.i] ?? ({})
                property real unfold: 0
                width: ListView.view.width
                height: ld.item ? ld.item.height : 0
                opacity: 0
                transform: Translate { id: drop }
                Component.onCompleted: enter.start()
                SequentialAnimation {
                    id: enter
                    PauseAnimation { duration: panel.settled ? 0 : 280 + Math.min(d.index, 10) * 50 }
                    ParallelAnimation {
                        NumberAnimation { target: d; property: "opacity"; to: 1; duration: 220 }
                        NumberAnimation { target: drop; property: "y"; from: -18; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                        NumberAnimation { target: d; property: "scale"; from: 0.94; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                        NumberAnimation { target: d; property: "unfold"; from: 0; to: 1; duration: 620; easing.type: Easing.OutQuint }
                    }
                }
                Loader {
                    id: ld
                    sourceComponent: ({ user: userC, step: stepC, more: moreC, text: textC, card: cardC, denied: deniedC, error: errorC })[d.row.kind] ?? null
                }
                Component { id: userC; UserBubble { width: d.width; item: d.item } }
                Component { id: stepC; Step { width: d.width; item: d.item; running: d.row.running ?? false } }
                Component { id: moreC; More { width: d.width; row: d.row } }
                Component { id: textC; Answer { width: d.width; item: d.item; reveal: d.unfold } }
                Component { id: cardC; Visual { width: d.width; item: d.item; reveal: d.unfold } }
                Component { id: deniedC; Denied { width: d.width; item: d.item; reveal: d.unfold; live: (Assistant.pending?.length ?? 0) > 0 && (d.row.live ?? false) } }
                Component { id: errorC; Failure { width: d.width; item: d.item; reveal: d.unfold } }
            }
        }

        // Past conversations, newest first: open one to read it and go on, or take it off the list.
        Frost {
            id: pastView
            width: parent.width
            height: pastCol.implicitHeight + 32
            radius: 28
            visible: stage.mix > 0
            opacity: stage.mix
            transform: Translate { y: 16 * (1 - stage.mix) }
            ColumnLayout {
                id: pastCol
                x: 16; y: 16; width: parent.width - 32; spacing: 8
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 12; spacing: 12
                    Tx { text: Tr.t("History"); size: 18; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
                    Fld {
                        id: search
                        visible: (Assistant.history?.length ?? 0) > 3
                        Layout.preferredWidth: 260
                        placeholderText: Tr.t("Search conversations")
                        Accessible.name: Tr.t("Search conversations")
                        onTextChanged: panel.pastQuery = text
                        Keys.onEscapePressed: panel.past = false
                    }
                }
                Tx {
                    visible: !panel.pastShown.length
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.bottomMargin: 6
                    text: (Assistant.history?.length ?? 0) ? Tr.t("No conversation matches.") : Tr.t("No conversations yet. They are kept here once Lagu answers.")
                    dim: true; wrapMode: Text.Wrap
                }
                ListView {
                    id: pastList
                    visible: count > 0
                    Layout.fillWidth: true
                    implicitHeight: Math.min(contentHeight, stage.roomFor - 90)
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    Accessible.role: Accessible.List
                    Accessible.name: Tr.t("History")
                    ScrollBar.vertical: ScrollBar { policy: pastList.contentHeight > pastList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff; width: 6 }
                    model: ScriptModel { values: panel.pastShown; objectProp: "id" }
                    delegate: Rectangle {
                        id: pr
                        required property var modelData
                        readonly property string sub: [Assistant.info(modelData.provider)?.name ?? modelData.provider, modelData.model, panel.ago(modelData.updated)].filter(s => s).join(" · ")
                        function pick() { panel.openPast(modelData.id) }
                        width: ListView.view.width; height: 60; radius: 16
                        color: prm.containsMouse || activeFocus ? Theme.raised : modelData.id === Assistant.session ? Theme.hover : "transparent"
                        border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title + ", " + sub
                        Accessible.onPressAction: pick()
                        Keys.onReturnPressed: pick()
                        Keys.onSpacePressed: pick()
                        Keys.onDeletePressed: Assistant.forget(modelData.id)
                        MouseArea { id: prm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pr.pick() }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8; spacing: 12
                            Ic { name: "chat"; size: 18; color: Theme.muted }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Tx { text: pr.modelData.title; strong: true; Layout.fillWidth: true }
                                Tx { text: pr.sub; dim: true; size: 13; Layout.fillWidth: true }
                            }
                            Btn {
                                variant: "quiet"; icon: "trash"; iconSize: 16; implicitWidth: 36; implicitHeight: 36; radius: 18
                                a11y: Tr.t("Remove “%1” from the history").arg(pr.modelData.title)
                                onClicked: Assistant.forget(pr.modelData.id)
                            }
                        }
                    }
                }
            }
        }
        }

        // The conversation on screen was with another tool than the one picked now.
        Tx {
            visible: panel.stale && !panel.past
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Tr.t("This conversation was with %1. Your next question starts a new one with %2.")
                .arg(Assistant.info(Assistant.sessionProvider)?.name ?? "").arg(panel.current?.name ?? "")
            dim: true; size: 13; wrapMode: Text.Wrap
        }

        // A fresh start, once there is something to clear.
        Frost {
            id: foot
            visible: panel.ready && !panel.past && (Assistant.items?.length ?? 0) > 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: footRow.implicitWidth + 28; height: 40; radius: 20
            RowLayout {
                id: footRow
                anchors.centerIn: parent; spacing: 12
                Btn {
                    variant: "quiet"; implicitHeight: 30; radius: 15
                    icon: "plus"; text: Tr.t("New conversation")
                    onClicked: { Assistant.reset(); panel.expanded = {}; panel.past = false; field.forceActiveFocus() }
                }
            }
        }
    }

    // ── The model and effort menu, under the pill ───────────────────────────
    // Drawn in this window, not a popup: the window's own click-outside grab would take a popup's clicks as outside.

    // A click anywhere else on the bar or the conversation closes it first.
    MouseArea { anchors.fill: parent; z: 9; enabled: panel.menuOpen; onClicked: panel.closeMenu() }
    component Choice: Rectangle {
        id: ch
        property string text: ""
        property string icon: ""
        property bool on: false
        signal picked()
        implicitHeight: 40; radius: 12
        color: cm.containsMouse || activeFocus ? Theme.raised : "transparent"
        border.width: activeFocus ? 2 : 0; border.color: Theme.ink
        activeFocusOnTab: visible
        Accessible.role: Accessible.MenuItem
        Accessible.name: text
        Accessible.checkable: !icon
        Accessible.checked: on
        Accessible.onPressAction: picked()
        Keys.onReturnPressed: picked()
        Keys.onEnterPressed: picked()
        Keys.onSpacePressed: picked()
        Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()
        Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
            Ic { name: ch.icon || "check"; size: 16; color: ch.icon ? Theme.muted : Theme.accent; opacity: ch.icon || ch.on ? 1 : 0 }
            Tx { text: ch.text; strong: ch.on; Layout.fillWidth: true }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.picked() }
    }
    Rectangle {
        id: menu
        function first() { return modelList.itemAtIndex(Math.max(0, Assistant.modelChoices.findIndex(c => c.id === Assistant.model))) ?? settingsRow }
        z: 10
        width: 300
        height: menuCol.implicitHeight + 16
        radius: 20
        color: Theme.glassStrong
        border.width: 1; border.color: Theme.line
        transformOrigin: Item.TopRight
        scale: panel.menuOpen ? 1 : 0.92
        opacity: panel.menuOpen ? 1 : 0
        visible: opacity > 0
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Accessible.role: Accessible.PopupMenu
        Accessible.name: panel.current?.name ?? ""
        Keys.onEscapePressed: panel.closeMenu()
        MouseArea { anchors.fill: parent } // clicks between rows stay in the menu
        ColumnLayout {
            id: menuCol
            x: 8; y: 8; width: parent.width - 16
            spacing: 2
            Tx { text: Tr.t("Model"); size: 12; strong: true; dim: true; Layout.leftMargin: 12; Layout.topMargin: 4; Layout.bottomMargin: 2 }
            ListView {
                id: modelList
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 40 * 7.5) // a long list (Cursor's) scrolls, with half a row showing it does
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: modelList.contentHeight > modelList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff; width: 6 }
                model: Assistant.modelChoices
                delegate: Choice {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    text: modelData.name
                    on: modelData.id === Assistant.model
                    onActiveFocusChanged: if (activeFocus) ListView.view.positionViewAtIndex(index, ListView.Contain)
                    onPicked: { Assistant.setModel(modelData.id); panel.closeMenu() }
                }
            }
            Tx {
                visible: Assistant.provider === "cursor" && !Assistant.cursorModels.length
                text: Tr.t("Loading the models…"); size: 13; dim: true; Layout.leftMargin: 12
            }
            Tx { visible: Assistant.provider === "claude"; text: Tr.t("Effort"); size: 12; strong: true; dim: true; Layout.leftMargin: 12; Layout.topMargin: 8; Layout.bottomMargin: 2 }
            Repeater {
                model: Assistant.provider === "claude" ? Assistant.effortChoices : []
                Choice {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.name
                    on: modelData.id === Assistant.effort
                    onPicked: { Assistant.setEffort(modelData.id); panel.closeMenu() }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.topMargin: 4; Layout.bottomMargin: 4; implicitHeight: 1; color: Theme.line }
            Choice {
                id: settingsRow
                Layout.fillWidth: true
                icon: "ajustes"
                text: Tr.t("Assistant settings")
                onPicked: { panel.menuOpen = false; Ui.show("ia") }
            }
        }
    }
}
