import QtQuick
import QtQuick.Controls

Item {
    id: root
    property var media: ({})
    signal clicked

    implicitWidth: 174
    implicitHeight: 292

    Rectangle {
        id: posterFrame
        width: parent.width
        height: 244
        radius: 14
        color: "#211f18"
        clip: true
        scale: mouse.containsMouse ? 1.025 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Image {
            id: poster
            anchors.fill: parent
            source: root.media.image || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            visible: poster.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: "#3a3322" }
                GradientStop { position: 1; color: "#171611" }
            }
            Text {
                anchors.centerIn: parent
                text: "✦"
                color: "#88764a"
                font.pixelSize: 34
            }
        }

        Rectangle {
            visible: (root.media.position || 0) > 0 && (root.media.duration || 0) > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 4
            color: "#4a4331"
            Rectangle {
                height: parent.height
                width: parent.width * Math.min(1, (root.media.position || 0) / root.media.duration)
                color: "#d8b45e"
            }
        }

        Rectangle {
            width: 48
            height: 48
            radius: 24
            anchors.centerIn: parent
            color: "#d8b45e"
            opacity: mouse.containsMouse ? 1 : 0
            scale: mouse.containsMouse ? 1 : 0.8
            Behavior on opacity { NumberAnimation { duration: 130 } }
            Behavior on scale { NumberAnimation { duration: 130 } }
            Text { anchors.centerIn: parent; text: "▶"; color: "white"; font.pixelSize: 17 }
        }
    }

    Text {
        anchors.top: posterFrame.bottom
        anchors.topMargin: 10
        width: parent.width
        text: root.media.name || "未命名"
        color: "#f2eee3"
        font.pixelSize: 14
        font.weight: Font.Medium
        elide: Text.ElideRight
    }
    Text {
        anchors.bottom: parent.bottom
        width: parent.width
        text: root.media.seriesName || root.media.subtitle || root.media.type || ""
        color: "#938d7b"
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
