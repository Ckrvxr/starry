import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string glyph: ""
    property bool selected: false

    implicitWidth: 204
    implicitHeight: 44
    leftPadding: 12
    rightPadding: 12
    hoverEnabled: true

    contentItem: Row {
        spacing: 10

        Rectangle {
            width: 28
            height: 28
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            color: control.selected ? "#3a2f19" : control.hovered ? "#272116" : "transparent"

            Text {
                anchors.centerIn: parent
                text: control.glyph
                color: control.selected ? "#edc86d" : "#938360"
                font.pixelSize: control.glyph === "⌂" ? 17 : 14
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Text {
            text: control.text
            color: control.selected ? "#f6edd8" : control.hovered ? "#dfd5c1" : "#a99c82"
            font.pixelSize: 13
            font.weight: control.selected ? Font.DemiBold : Font.Normal
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    background: Rectangle {
        radius: 13
        color: control.selected ? "#272014" : control.hovered ? "#17140e" : "transparent"
        border.width: 0

        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            visible: control.selected
            width: 36
            height: 22
            radius: 11
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "#100e09"

            Text {
                anchors.centerIn: parent
                text: "•••"
                color: "#79663d"
                font.pixelSize: 10
                font.letterSpacing: 1
            }
        }
    }
}
