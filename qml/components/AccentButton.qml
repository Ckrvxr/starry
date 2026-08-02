import QtQuick
import QtQuick.Controls

Button {
    id: control
    property color accentColor: "#c9a85b"

    implicitWidth: Math.max(112, contentItem.implicitWidth + 36)
    implicitHeight: 44
    font.pixelSize: 14
    font.weight: Font.DemiBold

    contentItem: Text {
        text: control.text
        color: "white"
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 12
        color: control.down ? Qt.darker(control.accentColor, 1.18)
                            : control.hovered ? Qt.lighter(control.accentColor, 1.08)
                                              : control.accentColor
        opacity: control.enabled ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
