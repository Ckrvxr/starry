import QtQuick
import QtQuick.Controls

Button {
    id: control
    property color accentColor: "#c9a85b"
    property string iconName: ""

    implicitWidth: Math.max(112, contentItem.implicitWidth + 36)
    implicitHeight: 44
    font.pixelSize: 14
    font.weight: Font.DemiBold

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: control.iconName.length > 0 ? 7 : 0

            LucideIcon {
                visible: control.iconName.length > 0
                width: visible ? 15 : 0
                height: 15
                anchors.verticalCenter: parent.verticalCenter
                name: control.iconName
                color: "white"
            }

            Text {
                text: control.text
                color: "white"
                font: control.font
            }
        }
    }

    background: Rectangle {
        radius: 12
        color: control.down ? Qt.darker(control.accentColor, 1.18) : control.hovered ? Qt.lighter(control.accentColor, 1.08) : control.accentColor
        opacity: control.enabled ? 1 : 0.45
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
}
