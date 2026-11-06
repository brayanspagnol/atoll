import QtQuick
import QtQuick.Shapes

// The focus timer's ring: value is the part left, 0 to 1, drawn clockwise from the top.
Shape {
    id: ring
    property real value: 1
    property int size: 136
    property int stroke: 12
    property color track: Theme.line
    implicitWidth: size; implicitHeight: size
    preferredRendererType: Shape.CurveRenderer
    Accessible.ignored: true
    readonly property real r: (size - stroke) / 2
    ShapePath {
        strokeColor: ring.track; strokeWidth: ring.stroke; fillColor: "transparent"
        PathAngleArc { centerX: ring.size / 2; centerY: ring.size / 2; radiusX: ring.r; radiusY: ring.r; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
        strokeColor: ring.value > 0 ? Theme.accent : "transparent"; strokeWidth: ring.stroke; fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: ring.size / 2; centerY: ring.size / 2; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: 360 * Math.min(1, Math.max(0, ring.value)) }
    }
}
