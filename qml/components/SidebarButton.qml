import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string glyph: ""
    property bool selected: false

    implicitWidth: 176
    implicitHeight: 46
    leftPadding: 14
    rightPadding: 14

    contentItem: Row {
        spacing: 12
        Text {
            width: 22
            text: control.glyph
            color: control.selected ? "#f1d58b" : "#928d7c"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: control.text
            color: control.selected ? "#f5e7bf" : "#aaa493"
            font.pixelSize: 14
            font.weight: control.selected ? Font.DemiBold : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    background: Rectangle {
        radius: 12
        color: control.selected ? "#3a301b" : control.hovered ? "#29251a" : "transparent"
        Rectangle {
            visible: control.selected
            width: 3
            height: 20
            radius: 2
            color: "#d8b45e"
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
