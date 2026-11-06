import QtQuick
import QtQuick.Layouts
import "parse.js" as P

// Export one profile or all of them; import in three steps: file, destination, a line-by-line review.
Page {
    id: pg
    title: Tr.t("Backup")
    subtitle: Tr.t("Your profiles and this computer's settings in one file, to keep or to take to another computer.")
    Component.onCompleted: Backup.estimate()

    readonly property var info: Backup.info
    readonly property var r: Backup.review
    readonly property var c: Backup.chosen
    readonly property var archived: Object.keys(info?.profiles ?? {})
    readonly property string curName: Profiles.list.find(p => p.id === Profiles.active)?.name ?? Profiles.active
    readonly property string fromName: info?.profiles?.[Backup.from]?.name ?? Backup.from
    readonly property bool withImages: Object.keys(info?.manifest?.images ?? {}).length > 0
    readonly property string never: Tr.t("Never in a file: clipboard, liked songs, notifications, Wi-Fi and Bluetooth.")
    property var opened: ({})
    function numbered(text, all) {
        const lines = text.replace(/\n$/, "").split("\n")
        return lines.slice(0, all ? lines.length : 6).map((l, i) => String(i + 1).padStart(3) + "  " + l).join("\n")
    }

    component Chk: Rectangle {
        id: box
        property bool checked: false
        property string a11y: ""
        signal toggled(bool on)
        implicitWidth: 22; implicitHeight: 22; radius: 6
        color: checked ? Theme.accent : Theme.field
        border.width: activeFocus ? 2 : 1
        border.color: activeFocus ? Theme.ink : checked ? Theme.accent : Theme.lineStrong
        activeFocusOnTab: true
        Accessible.role: Accessible.CheckBox
        Accessible.name: a11y
        Accessible.checkable: true
        Accessible.checked: checked
        Accessible.onToggleAction: toggled(!checked)
        Accessible.onPressAction: toggled(!checked)
        Keys.onSpacePressed: toggled(!checked)
        Ic { anchors.centerIn: parent; visible: box.checked; name: "check"; size: 16; color: Theme.accentInk }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: box.toggled(!box.checked) }
    }
    component Wrap: Tx { Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone }
    component Note: Rectangle {
        property string text: ""
        property color tone: Theme.good
        Layout.fillWidth: true
        visible: !!text
        implicitHeight: noteText.implicitHeight + 24
        radius: Theme.radiusSmall
        color: Theme.raised
        border.width: 1; border.color: tone
        Tx { id: noteText; x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter; text: parent.text; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
    component Field: RowLayout {
        property string label: ""
        Layout.fillWidth: true; spacing: 16
        Tx { text: parent.label; Layout.preferredWidth: 200 }
    }
    // One setting: as it is here, and after importing. A skipped one is struck through, with the reason.
    component Line: Rowi {
        id: line
        property var row
        readonly property bool on: !row.skip && Backup.picked[row.id] !== false
        clickable: false
        a11y: row.label + ": " + row.before + ", " + (row.skip ? row.skip : row.after)
        Chk { visible: !line.row.skip; checked: line.on; a11y: Tr.t("Import") + ": " + line.row.label; onToggled: on => Backup.pick(line.row.id, on) }
        Ic { visible: !!line.row.skip; name: "ban"; size: 22; color: Theme.muted }
        Tx { text: line.row.label; font.strikeout: !!line.row.skip; dim: !line.on; Layout.preferredWidth: 180 }
        Wrap { text: line.row.before; dim: true; Layout.preferredWidth: 1 }
        Ic { name: "arrowRight"; size: 16; color: Theme.muted }
        Wrap {
            text: line.row.same ? line.row.after + " · " + Tr.t("same") : line.row.after
            dim: !line.on || line.row.same
            color: line.row.skip ? Theme.warn : dim ? Theme.muted : Theme.ink
            Layout.preferredWidth: 1
        }
    }
    // A file that runs programs: shown as code, and only imported after an explicit yes.
    component Code: Rectangle {
        id: code
        property var row
        readonly property bool all: !!pg.opened[row.id]
        readonly property bool yes: Backup.picked[row.id] === true
        Layout.fillWidth: true
        implicitHeight: codeCol.implicitHeight + 28
        radius: Theme.radiusSmall
        color: Theme.raised
        border.width: 1; border.color: yes ? Theme.accent : Theme.warn
        ColumnLayout {
            id: codeCol
            x: 14; y: 14; width: parent.width - 28
            spacing: 10
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Ic { name: "alert"; color: Theme.warn }
                Wrap { text: Tr.t("%1 is code, not a setting").arg(code.row.label); strong: true }
                Tx { text: code.row.before + "  →  " + code.row.after; dim: true; size: 13 }
            }
            Wrap { text: Tr.t("It runs inside Hyprland as you, with your files and permissions. Read all of it before you accept it."); dim: true }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: codeText.implicitHeight + 20
                radius: Theme.radiusSmall - 4
                color: Theme.field
                border.width: 1; border.color: Theme.line
                Tx { id: codeText; x: 12; y: 10; width: parent.width - 24; mono: true; size: 13; text: pg.numbered(code.row.text, code.all); wrapMode: Text.WrapAnywhere; elide: Text.ElideNone; Accessible.name: code.row.label; Accessible.role: Accessible.StaticText }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Chk { id: accept; checked: code.yes; a11y: Tr.t("I read the code and want to import it"); onToggled: on => Backup.pick(code.row.id, on) }
                Tx { text: Tr.t("I read the code and want to import it"); Layout.fillWidth: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Backup.pick(code.row.id, !code.yes) } }
                Btn {
                    visible: code.row.lines > 6
                    text: code.all ? Tr.t("Show less") : Tr.t("Show all %1 lines").arg(code.row.lines)
                    onClicked: pg.opened = Object.assign({}, pg.opened, { [code.row.id]: !code.all })
                }
            }
        }
    }

    // Start: export, or pick a file to import.
    ColumnLayout {
        visible: Backup.step === ""
        Layout.fillWidth: true; spacing: 10
        Sec { title: Tr.t("Export") }
        Field {
            label: Tr.t("What goes")
            Cmb {
                a11y: Tr.t("What goes")
                textRole: "name"
                model: [{ id: "all", name: Tr.t("All profiles") }].concat(Profiles.list)
                currentIndex: Math.max(0, model.findIndex(o => o.id === Backup.which))
                onActivated: i => Backup.which = model[i].id
            }
        }
        Field {
            label: Tr.t("Pictures")
            Seg {
                readonly property var s: Backup.size
                options: [Tr.t("Without images") + (s ? " · " + P.bytes(s.base) : ""), Tr.t("With images") + (s ? " · " + P.bytes(s.base + s.images) : "")]
                current: Backup.images ? 1 : 0
                onPicked: i => Backup.images = i === 1
            }
        }
        Wrap { visible: !!Backup.size?.files?.length; text: Tr.t("Also goes, from this computer: %1").arg((Backup.size?.files ?? []).join(", ")); dim: true }
        Wrap { text: pg.never; dim: true }
        RowLayout {
            Btn { text: Tr.t("Export…"); icon: "download"; variant: "solid"; enabledB: !Backup.busy; onClicked: Backup.chooseExport() }
        }
        Note { text: Backup.saved ? Tr.t("Saved to %1").arg(Backup.saved) : "" }

        Sec { title: Tr.t("Import") }
        Wrap { text: Tr.t("Choose a file made by Atoll, here or on another computer. Nothing changes until you review it."); dim: true }
        RowLayout {
            Btn { text: Tr.t("Choose a file…"); icon: "upload"; variant: "solid"; enabledB: !Backup.busy; onClicked: Backup.chooseImport() }
        }
    }

    // Import: the steps, then the chosen file.
    ColumnLayout {
        visible: Backup.step !== ""
        Layout.fillWidth: true; spacing: 12
        RowLayout {
            spacing: 10
            Repeater {
                model: [Tr.t("File"), Tr.t("Destination"), Tr.t("Review")]
                RowLayout {
                    id: stepItem
                    required property string modelData
                    required property int index
                    readonly property int at: ({ target: 1, review: 2, done: 3 })[Backup.step] ?? 0
                    spacing: 8
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData + (index < at ? ", " + Tr.t("done") : index === at ? ", " + Tr.t("current step") : "")
                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: stepItem.index < stepItem.at ? Theme.good : stepItem.index === stepItem.at ? Theme.accent : Theme.raised
                        Ic { anchors.centerIn: parent; visible: stepItem.index < stepItem.at; name: "check"; size: 16; color: Theme.accentInk }
                        Tx { anchors.centerIn: parent; visible: stepItem.index >= stepItem.at; text: stepItem.index + 1; size: 13; strong: true; color: stepItem.index === stepItem.at ? Theme.accentInk : Theme.ink }
                    }
                    Tx { text: stepItem.modelData; strong: stepItem.index === stepItem.at; dim: stepItem.index !== stepItem.at }
                    Rectangle { visible: stepItem.index < 2; implicitWidth: 32; implicitHeight: 1; color: Theme.lineStrong }
                }
            }
        }
        Rowi {
            clickable: false
            a11y: Backup.file
            Ic { name: "archive"; size: 24 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Tx { text: Backup.file.split("/").pop(); strong: true; Layout.fillWidth: true }
                Tx {
                    Layout.fillWidth: true; dim: true; size: 13
                    text: [P.bytes(pg.info?.bytes ?? 0),
                        pg.archived.length === 1 ? Tr.t("profile %1").arg(pg.info.profiles[pg.archived[0]].name ?? pg.archived[0]) : Tr.t("Profiles: %1").arg(pg.archived.length),
                        pg.info?.manifest?.host ? Tr.t("from %1").arg(pg.info.manifest.host) : "",
                        pg.info?.manifest?.created ? Tr.locale.toString(new Date(pg.info.manifest.created), Locale.ShortFormat) : ""].filter(Boolean).join(" · ")
                }
            }
            Tx { text: pg.withImages ? Tr.t("With images") : Tr.t("Without images"); dim: true; size: 13 }
            Btn { text: Tr.t("Change"); enabledB: !Backup.busy && Backup.step !== "done"; onClicked: Backup.chooseImport() }
        }

        // Step 2: which profile of the file, and where it goes.
        ColumnLayout {
            visible: Backup.step === "target"
            Layout.fillWidth: true; spacing: 10
            Sec { title: Tr.t("Destination") }
            Field {
                visible: pg.archived.length > 1
                label: Tr.t("Profile in the file")
                Cmb {
                    a11y: Tr.t("Profile in the file")
                    textRole: "name"
                    model: pg.archived.map(id => ({ id, name: pg.info.profiles[id].name ?? id }))
                    currentIndex: Math.max(0, model.findIndex(o => o.id === Backup.from))
                    onActivated: i => Backup.from = model[i].id
                }
            }
            Field {
                visible: pg.archived.length > 0
                label: Tr.t("Import as")
                Seg {
                    options: [Tr.t("A new profile"), Tr.t("Replace %1").arg(pg.curName)]
                    current: Backup.into === "replace" ? 1 : 0
                    onPicked: i => Backup.into = i ? "replace" : "new"
                }
            }
            Wrap {
                dim: true
                text: pg.archived.length === 0 ? Tr.t("This file has no profile, only settings files of a computer.")
                    : Backup.into === "replace" ? Tr.t("The current %1 is saved as a copy first, next to the file you chose.").arg(pg.curName)
                    : Tr.t("%1 stays as it is. The new profile starts from it and becomes the active one.").arg(pg.curName)
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Btn { text: Tr.t("Back"); onClicked: Backup.back() }
                Btn { text: Tr.t("Next"); variant: "solid"; onClicked: Backup.next() }
            }
        }

        // Step 3: line by line.
        ColumnLayout {
            visible: Backup.step === "review" && !!pg.r
            Layout.fillWidth: true; spacing: 4
            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 8; spacing: 12
                Item { implicitWidth: 22 }
                Tx { text: Tr.t("Setting"); dim: true; size: 13; Layout.preferredWidth: 180 }
                Tx { text: Tr.t("On this computer"); dim: true; size: 13; Layout.fillWidth: true; Layout.preferredWidth: 1 }
                Item { implicitWidth: 16 }
                Tx { text: Tr.t("After importing"); dim: true; size: 13; Layout.fillWidth: true; Layout.preferredWidth: 1 }
            }
            Sec { visible: (pg.r?.profile ?? []).length > 0; title: Backup.into === "replace" ? Tr.t("Profile %1").arg(pg.curName) : Tr.t("New profile %1").arg(pg.fromName); Layout.topMargin: 8 }
            Repeater { model: pg.r?.profile ?? []; Line { required property var modelData; row: modelData } }
            Sec { visible: (pg.r?.files ?? []).length + (pg.r?.code ?? []).length > 0; title: Tr.t("Files of this computer"); Layout.topMargin: 8 }
            Repeater { model: pg.r?.files ?? []; Line { required property var modelData; row: modelData } }
            Repeater { model: pg.r?.code ?? []; Code { required property var modelData; row: modelData; Layout.topMargin: 6 } }
            Rectangle {
                Layout.fillWidth: true; Layout.topMargin: 14
                implicitHeight: foot.implicitHeight + 28
                radius: Theme.radiusSmall
                color: Theme.raised
                RowLayout {
                    id: foot
                    x: 14; y: 14; width: parent.width - 28
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Wrap { strong: true; text: Tr.t("Changes to %1: %2 · Files of this computer: %3").arg(Backup.into === "replace" ? pg.curName : pg.fromName).arg(pg.c?.changes ?? 0).arg(pg.c?.changedFiles ?? 0) }
                        Wrap { dim: true; size: 13; text: (Backup.into === "replace" || (pg.c?.files ?? []).length ? Tr.t("What gets replaced is saved as a copy first.") + " " : "") + pg.never }
                    }
                    Btn { text: Tr.t("Back"); onClicked: Backup.back() }
                    Btn {
                        text: pg.archived.length === 0 ? Tr.t("Import files") : Backup.into === "replace" ? Tr.t("Replace %1").arg(pg.curName) : Tr.t("Import as a new profile")
                        variant: "solid"; icon: "download"
                        enabledB: !Backup.busy && !!pg.c && (pg.c.keys.length > 0 || pg.c.files.length > 0)
                        onClicked: Backup.apply()
                    }
                }
            }
        }

        // Done.
        ColumnLayout {
            visible: Backup.step === "done"
            Layout.fillWidth: true; spacing: 10
            Note {
                text: Tr.t("Imported.") + (Backup.saved ? " " + Tr.t("What it replaced was saved in %1.").arg(Backup.saved) : "")
                    + (Backup.importedFiles.length ? " " + Tr.t("Keyboard, screens and user.lua take effect the next time you log in.") : "")
            }
            RowLayout { Btn { text: Tr.t("Done"); variant: "solid"; onClicked: Backup.reset() } }
        }
    }
    Note { text: Backup.error; tone: Theme.danger }
    Tx { visible: Backup.busy; text: Tr.t("Working…"); dim: true }
}
