import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Page {
    id: pg
    title: "Ajustes"
    Component.onCompleted: Bright.refresh()
    property var walls: []
    readonly property var monitors: Hyprland.monitors.values

    Process {
        running: true
        command: ["find", Quickshell.env("HOME") + "/.local/share/atoll/wallpapers", Quickshell.env("HOME") + "/Pictures/Wallpapers", "-maxdepth", "2", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")"]
        stderr: StdioCollector {}
        stdout: StdioCollector { onStreamFinished: pg.walls = text.trim().split("\n").filter(Boolean).sort() }
    }

    component Line: RowLayout {
        property string label: ""
        property string hint: ""
        Layout.fillWidth: true; spacing: 16
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: label; Layout.fillWidth: true }
            Tx { visible: hint; text: hint; dim: true; size: 13; Layout.fillWidth: true }
        }
    }

    Sec { title: "Aparência" }
    Line {
        label: "Cor de destaque"
        Repeater {
            model: Object.keys(Theme.accents)
            Rectangle {
                required property string modelData
                implicitWidth: 32; implicitHeight: 32; radius: 16
                color: Theme.accents[modelData].hex
                border.width: Cfg.v.accent === modelData || activeFocus ? 2 : 0
                border.color: Theme.ink
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: Theme.accents[modelData].name
                Accessible.checked: Cfg.v.accent === modelData
                Keys.onSpacePressed: Cfg.v.accent = modelData
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.accent = parent.modelData }
            }
        }
    }
    Tx { text: "Papel de parede"; Layout.topMargin: 6 }
    Tx { visible: pg.walls.length === 0; text: "Coloque imagens em ~/Pictures/Wallpapers"; dim: true }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: pg.walls
            Rectangle {
                required property string modelData
                width: 268; height: 120; radius: Theme.radiusSmall; clip: true
                color: Theme.raised
                border.width: Cfg.v.wallpaper === modelData || activeFocus ? 2 : 0
                border.color: Theme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Papel de parede " + modelData.split("/").pop()
                Keys.onSpacePressed: Cfg.v.wallpaper = modelData
                Image { anchors.fill: parent; anchors.margins: 2; source: "file://" + parent.modelData; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(536, 240); asynchronous: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.wallpaper = parent.modelData }
            }
        }
        Rectangle {
            width: 268; height: 120; radius: Theme.radiusSmall; color: Theme.ground
            border.width: !Cfg.v.wallpaper || activeFocus ? 2 : 1
            border.color: !Cfg.v.wallpaper || activeFocus ? Theme.accent : Theme.line
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Sem imagem, cor sólida"
            Keys.onSpacePressed: Cfg.v.wallpaper = ""
            Tx { anchors.centerIn: parent; text: "Cor sólida"; dim: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.wallpaper = "" }
        }
    }

    Sec { title: "Tela" }
    Repeater {
        model: pg.monitors
        Line {
            required property var modelData
            label: modelData.name
            hint: modelData.width + "×" + modelData.height + " · " + Math.round(modelData.lastIpcObject?.refreshRate ?? 0) + " Hz · escala " + modelData.scale
        }
    }
    Line {
        visible: Bright.external >= 0
        label: "Brilho do monitor externo"
        hint: "Via DDC/CI"
        Sld { Layout.preferredWidth: 260; a11y: "Brilho externo"; from: 0; to: 100; stepSize: 5; value: Bright.external; onPressedChanged: if (!pressed) Bright.setExternal(value) }
        Tx { mono: true; text: Bright.external + "%"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
    }
    Line {
        visible: Bright.panel >= 0
        label: "Brilho da tela do notebook"
        Sld { Layout.preferredWidth: 260; a11y: "Brilho do notebook"; from: 1; to: 100; value: Bright.panel; onMoved: Bright.setPanel(Math.round(value)) }
        Tx { mono: true; text: Bright.panel + "%"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
    }
    Line {
        label: "Luz noturna"
        hint: "Tela mais quente, menos azul"
        Sld { visible: Cfg.v.nightOn; Layout.preferredWidth: 180; a11y: "Temperatura da luz noturna"; from: 2500; to: 6000; stepSize: 100; value: Cfg.v.nightK; onMoved: { Cfg.v.nightK = value; Night.apply() } }
        Tx { visible: Cfg.v.nightOn; mono: true; text: Cfg.v.nightK + " K"; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
        Swt { a11y: "Luz noturna"; checked: Cfg.v.nightOn; onToggled: { Cfg.v.nightOn = checked; Night.apply() } }
    }

    Sec {
        title: "Tempo ocioso (minutos, 0 = nunca)"
        Btn { text: "Aplicar"; variant: "solid"; onClicked: { Idle.apply(); applied.visible = true } }
    }
    Tx { id: applied; visible: false; text: "Aplicado."; color: Theme.good }
    GridLayout {
        Layout.fillWidth: true; columns: 4; columnSpacing: 16; rowSpacing: 8
        Item { implicitWidth: 1 }
        Tx { text: "Bloquear"; dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: "Apagar tela"; dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: "Suspender"; dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: "Na tomada" }
        Mins { key: "lockAc" } Mins { key: "dpmsAc" } Mins { key: "sleepAc" }
        Tx { text: "Na bateria" }
        Mins { key: "lockBat" } Mins { key: "dpmsBat" } Mins { key: "sleepBat" }
    }
    component Mins: Fld {
        property string key: ""
        Layout.fillWidth: true
        font.family: Theme.mono
        text: Cfg.v[key]
        validator: IntValidator { bottom: 0; top: 240 }
        Accessible.name: key
        onTextEdited: if (acceptableInput) Cfg.v[key] = Number(text)
    }

    Sec { title: "Atalhos" }
    GridLayout {
        Layout.fillWidth: true; columns: 2; columnSpacing: 28; rowSpacing: 6
        Repeater {
            model: [["Super + R", "Aplicativos e comandos"], ["Super + Z", "Mostrar a barra de baixo"],
                    ["Super + Alt + A", "Som"], ["Super + Alt + I", "Internet"], ["Super + Alt + B", "Bluetooth"], ["Super + Alt + D", "Desempenho"],
                    ["Super + Alt + C", "Calendário"], ["Super + Alt + V", "Avisos"], ["Super + Alt + J", "Ajustes"], ["Super + Alt + E", "Energia"],
                    ["Super + L", "Bloquear"], ["Super + Enter", "Terminal"], ["Super + B", "Navegador"], ["Super + E", "Arquivos"],
                    ["Super + C", "Fechar janela"], ["Super + Shift + V", "Histórico de cópias"], ["Print", "Captura de área"], ["Super + Espaço", "Trocar layout do teclado"]]
            RowLayout {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 8
                Tx { text: parent.modelData[1]; dim: true; Layout.fillWidth: true }
                Tx { text: parent.modelData[0]; mono: true; size: 13 }
            }
        }
    }

    Sec { title: "Sobre" }
    FileView { id: versionFile; path: Quickshell.env("HOME") + "/.local/share/atoll/VERSION"; blockLoading: true }
    Line {
        label: "Atoll " + (versionFile.text().trim() || "dev")
        hint: "Software livre sob a licença MIT"
        Btn { text: "Abrir no GitHub"; onClicked: Qt.openUrlExternally("https://github.com/brayanspagnol/atoll") }
    }
}
