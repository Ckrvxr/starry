pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var media: ({})
    property int currentIndex: 0
    property int itemCount: 0

    signal playRequested()
    signal previousRequested()
    signal nextRequested()
    signal indexRequested(int index)

    clip: true

    Rectangle {
        anchors.fill: parent
        color: "#080806"
    }

    Image {
        id: heroImage
        anchors.fill: parent
        source: root.media.backdrop || root.media.image || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: status === Image.Ready ? 0.88 : 0

        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#fa070706" }
            GradientStop { position: 0.3; color: "#c7070706" }
            GradientStop { position: 0.62; color: "#30070706" }
            GradientStop { position: 1; color: "#4d070706" }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#4d070706" }
            GradientStop { position: 0.38; color: "#00070706" }
            GradientStop { position: 0.7; color: "#8a070706" }
            GradientStop { position: 1; color: "#fc070706" }
        }
    }

    Rectangle {
        width: 160
        height: parent.height
        anchors.right: parent.right
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#00070706" }
            GradientStop { position: 1; color: "#bf070706" }
        }
    }

    Column {
        id: heroCopy
        anchors.left: parent.left
        anchors.leftMargin: Math.max(42, root.width * 0.045)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(48, root.height * 0.07)
        width: Math.min(650, root.width * 0.58)
        spacing: 15

        Row {
            spacing: 9

            Text {
                text: "首页推荐"
                color: "#d5aa4c"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.4
            }

            Text {
                text: "·"
                color: "#857c68"
                font.pixelSize: 11
            }

            Text {
                text: String(root.currentIndex + 1).padStart(2, "0")
                      + " / " + String(Math.max(1, root.itemCount)).padStart(2, "0")
                color: "#d8d4cb"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
            }
        }

        Text {
            width: parent.width
            text: root.media.name || "正在抵达你的媒体宇宙"
            color: "#f8f5ed"
            font.pixelSize: Math.min(62, Math.max(42, root.width * 0.052))
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Row {
            visible: root.itemCount > 0
            spacing: 10

            Text {
                text: root.media.subtitle || ""
                color: "#ded9cd"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text { text: "·"; color: "#8c8168"; font.pixelSize: 13 }

            Text {
                text: root.media.type === "Movie" ? "电影"
                    : root.media.type === "Series" ? "剧集"
                    : root.media.type === "Episode" ? "剧集" : (root.media.type || "影视")
                color: "#c9c2b2"
                font.pixelSize: 13
            }

            Text {
                visible: Number(root.media.communityRating || 0) > 0
                text: "·"
                color: "#8c8168"
                font.pixelSize: 13
            }

            Text {
                visible: Number(root.media.communityRating || 0) > 0
                text: "★  " + Number(root.media.communityRating || 0).toFixed(1)
                color: "#e2b74f"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        Text {
            visible: root.itemCount > 0
            width: parent.width
            text: root.media.overview || "暂无简介"
            color: "#c9c5bb"
            font.pixelSize: 14
            lineHeight: 1.45
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Item { width: 1; height: 2 }

        Button {
            id: playButton
            visible: root.itemCount > 0
            width: 144
            height: 46
            text: "▶  立即播放"
            hoverEnabled: true

            contentItem: Text {
                text: playButton.text
                color: "#f6f1e6"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                radius: 23
                color: playButton.down ? "#3c321d" : playButton.hovered ? "#302817" : "#211d15"
                border.width: 1
                border.color: playButton.hovered ? "#b8954e" : "#615335"

                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }
            }

            onClicked: root.playRequested()
        }
    }

    Column {
        visible: root.itemCount > 1
        anchors.right: parent.right
        anchors.rightMargin: Math.max(36, root.width * 0.04)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(38, root.height * 0.055)
        spacing: 17

        Row {
            anchors.right: parent.right
            spacing: 10

            Repeater {
                model: 2

                delegate: Button {
                    id: arrowButton
                    required property int index
                    width: 44
                    height: 44
                    hoverEnabled: true
                    text: index === 0 ? "‹" : "›"

                    contentItem: Text {
                        text: arrowButton.text
                        color: arrowButton.hovered ? "#f4d484" : "#ddd8ca"
                        font.pixelSize: 25
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 22
                        color: arrowButton.hovered ? "#282318" : "#161511"
                        border.width: 1
                        border.color: arrowButton.hovered ? "#8c7441" : "#49453b"
                    }

                    onClicked: index === 0 ? root.previousRequested() : root.nextRequested()
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            Repeater {
                model: root.itemCount

                delegate: Rectangle {
                    id: progressSegment
                    required property int index
                    width: root.currentIndex === index ? 48 : 28
                    height: 3
                    radius: 2
                    color: root.currentIndex === index ? "#d6a744" : "#4a473f"

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -7
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.indexRequested(progressSegment.index)
                    }
                }
            }
        }
    }
}
