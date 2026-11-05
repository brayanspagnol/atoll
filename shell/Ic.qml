import QtQuick
import QtQuick.Shapes

Item {
    id: r
    property string name: ""
    property int size: 20
    property color color: Theme.ink
    property bool filled: false
    implicitWidth: size
    implicitHeight: size
    Accessible.ignored: true
    Shape {
        width: 24; height: 24
        scale: r.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: r.color
            strokeWidth: 1.8
            fillColor: r.filled ? r.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.p[r.name] ?? "" }
        }
    }
}
