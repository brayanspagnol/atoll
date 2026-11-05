import QtQuick
Text {
    property int size: 15
    property bool dim: false
    property bool mono: false
    property bool strong: false
    color: dim ? Theme.muted : Theme.ink
    font.family: mono ? Theme.mono : Theme.sans
    font.pixelSize: size
    font.weight: strong ? Font.DemiBold : Font.Normal
    font.features: mono ? {} : { "tnum": 1 }
    textFormat: Text.PlainText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
