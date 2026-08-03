pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property bool active: false

    visible: opacity > 0
    enabled: active
    opacity: active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.active ? 110 : 220
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#b3070706"
    }

    Item {
        anchors.centerIn: parent
        width: 112
        height: 92

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 52
            height: 52
            radius: 18
            color: "#e817140e"
            border.width: 1
            border.color: "#5f4f30"

            LucideIcon {
                anchors.centerIn: parent
                width: 25
                height: 25
                name: "loader-circle"
                color: "#e0bd67"

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1050
                    loops: Animation.Infinite
                    running: root.active
                    easing.type: Easing.InOutCubic
                }

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.active
                    NumberAnimation {
                        to: 0.78
                        duration: 520
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 520
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: "正在加载"
            color: "#b8aa8d"
            font.pixelSize: 11
            font.letterSpacing: 1.6
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active
    }
}
