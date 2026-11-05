import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Apps and system screens in one search. Super+R.
LazyLoader {
    active: Ui.launcher && !!Ui.screen
    PanelWindow {
        id: win
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "atoll-palette"
        color: "transparent"
        property int sel: 0
        readonly property var results: {
            const q = field.text.trim().toLowerCase()
            const pages = Ui.pages.map(p => ({ name: p.label, kind: Tr.t("screen"), icon: p.icon, hay: (p.label + " " + p.kw).toLowerCase(), run: () => Ui.show(p.id) }))
            const apps = [...DesktopEntries.applications.values].filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
                .map(a => ({ name: a.name, kind: Tr.t("app"), app: a, hay: (a.name + " " + a.genericName + " " + a.keywords.join(" ")).toLowerCase(), run: () => { a.execute(); Ui.launcher = false } }))
            if (!q) return pages.concat(apps).slice(0, 40)
            const score = r => r.name.toLowerCase().startsWith(q) ? 0 : 1
            return pages.concat(apps).filter(r => r.hay.includes(q)).sort((a, b) => score(a) - score(b)).slice(0, 40)
        }
        function run(r) { if (r) r.run() }
        MouseArea { anchors.fill: parent; onClicked: Ui.launcher = false }
        Frost {
            width: 760
            height: 12 + 52 + 8 + Math.max(60, Math.min(8, win.results.length) * 46) + 12
            anchors.horizontalCenter: parent.horizontalCenter
            y: 190
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 52; radius: Theme.radiusSmall; color: "transparent"
                    border.width: 1; border.color: Theme.accent
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        Ic { name: "search"; color: Theme.muted }
                        TextInput {
                            id: field
                            Layout.fillWidth: true
                            color: Theme.ink; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                            font.family: Theme.sans; font.pixelSize: 18
                            focus: true
                            Accessible.name: Tr.t("Search apps and commands")
                            Component.onCompleted: forceActiveFocus()
                            onTextChanged: { win.sel = 0; list.positionViewAtBeginning() }
                            Keys.onEscapePressed: Ui.launcher = false
                            Keys.onDownPressed: { win.sel = Math.min(win.sel + 1, win.results.length - 1); list.positionViewAtIndex(win.sel, ListView.Contain) }
                            Keys.onUpPressed: { win.sel = Math.max(win.sel - 1, 0); list.positionViewAtIndex(win.sel, ListView.Contain) }
                            Keys.onReturnPressed: win.run(win.results[win.sel])
                            Keys.onEnterPressed: win.run(win.results[win.sel])
                            Tx { visible: !field.text; text: Tr.t("Open an app or setting…"); size: 18; dim: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; model: win.results; spacing: 2
                    delegate: Rowi {
                        id: it
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        implicitHeight: 44
                        selected: index === win.sel
                        a11y: modelData.name
                        activeFocusOnTab: false
                        onClicked: win.run(modelData)
                        Ic { visible: !it.modelData.app; name: it.modelData.icon ?? ""; color: Theme.muted }
                        IconImage { visible: !!it.modelData.app; implicitSize: 20; source: it.modelData.app ? Quickshell.iconPath(it.modelData.app.icon, true) : "" }
                        Tx { text: it.modelData.name; Layout.fillWidth: true }
                        Tx { text: it.modelData.kind; dim: true; size: 13; mono: true }
                    }
                    Tx { anchors.centerIn: parent; visible: win.results.length === 0; text: Tr.t("Nothing found. Try “wifi”, “volume” or “suspend”."); dim: true }
                }
            }
        }
    }
}
