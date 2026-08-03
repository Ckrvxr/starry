pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Item {
    id: root
    property var media: ({})
    signal clicked

    function formatDuration(seconds) {
        const totalMinutes = Math.max(0, Math.round(Number(seconds || 0) / 60))
        if (totalMinutes < 1)
            return ""
        const hours = Math.floor(totalMinutes / 60)
        const minutes = totalMinutes % 60
        if (hours > 0)
            return hours + "小时" + (minutes > 0 ? " " + minutes + "分" : "")
        return minutes + "分钟"
    }

    function typeLabel(type) {
        if (type === "Movie") return "电影"
        if (type === "Series" || type === "Episode") return "剧集"
        return type || "影视"
    }

    implicitWidth: 200
    implicitHeight: Math.round(width * 1.48) + 58

    Rectangle {
        id: posterFrame
        width: parent.width
        height: Math.round(width * 1.48)
        radius: 14
        color: "#17140e"
        clip: true
        scale: mouse.containsMouse ? 1.018 : 1
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

        Image {
            id: poster
            anchors.fill: parent
            source: (root.media.image || root.media.backdrop)
                    ? "image://cached/" + encodeURIComponent(root.media.image || root.media.backdrop)
                    : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        width: poster.width
                        height: poster.height
                        radius: posterFrame.radius
                        color: "white"
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: poster.status !== Image.Ready
            radius: posterFrame.radius
            gradient: Gradient {
                GradientStop { position: 0; color: "#2e2718" }
                GradientStop { position: 1; color: "#100e0a" }
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
            radius: 2
            color: "#4a4331"
            Rectangle {
                height: parent.height
                width: parent.width * Math.min(1, (root.media.position || 0) / root.media.duration)
                radius: 2
                color: "#d8b45e"
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: posterFrame.radius
            color: "#52000000"
            opacity: mouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        Rectangle {
            width: 92
            height: 36
            radius: 18
            anchors.centerIn: parent
            color: "#e61b1812"
            border.width: 1
            border.color: "#a68b55"
            opacity: mouse.containsMouse ? 1 : 0
            scale: mouse.containsMouse ? 1 : 0.8
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
            Text {
                anchors.centerIn: parent
                text: "查看详情  ›"
                color: "#f5f0e5"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    Text {
        anchors.top: posterFrame.bottom
        anchors.topMargin: 10
        width: parent.width
        text: root.media.name || "未命名"
        color: mouse.containsMouse ? "#e7c979" : "#f2eee3"
        font.pixelSize: 15
        font.weight: Font.DemiBold
        elide: Text.ElideRight

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        anchors.top: posterFrame.bottom
        anchors.topMargin: 36
        width: parent.width
        height: 18
        spacing: 5
        clip: true

        Text {
            text: root.media.year || root.media.subtitle || ""
            color: "#918a7b"
            font.pixelSize: 11
        }

        Text {
            visible: text.length > 0
            text: root.media.genre || root.typeLabel(root.media.type)
            color: "#918a7b"
            font.pixelSize: 11
            leftPadding: 7

            Rectangle {
                width: 2; height: 2; radius: 1
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: "#716957"
            }
        }

        Text {
            visible: Number(root.media.communityRating || 0) > 0
            text: Number(root.media.communityRating || 0).toFixed(1)
            color: "#d8ad4d"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            leftPadding: 7

            Rectangle {
                width: 2; height: 2; radius: 1
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: "#716957"
            }
        }

        Text {
            visible: text.length > 0
            text: root.formatDuration(root.media.duration)
            color: "#918a7b"
            font.pixelSize: 11
            leftPadding: 7

            Rectangle {
                width: 2; height: 2; radius: 1
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: "#716957"
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
