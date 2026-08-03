pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: root

    property var media: ({})
    property int currentIndex: 0
    property int itemCount: 0
    property var resume: []

    signal playRequested
    signal previousRequested
    signal nextRequested
    signal indexRequested(int index)
    signal resumePlayRequested(var item)

    clip: true

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "00:00";
        const total = Math.floor(seconds);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        return (h > 0 ? String(h).padStart(2, "0") + ":" : "") + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
    }

    Item {
        id: heroSection
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(390, parent.height * 0.63)
        clip: true

        Rectangle {
            anchors.fill: parent
            color: "#080806"
        }

        Image {
            id: heroBlur
            anchors.fill: parent
            source: (root.media.backdrop || root.media.image) ? "image://cached/" + encodeURIComponent(root.media.backdrop || root.media.image) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: heroBlur
            blur: 1
            blurMax: 64
            saturation: 0
            brightness: -0.35
            visible: heroImage.status === Image.Ready

            Behavior on visible {
                NumberAnimation {
                    duration: 320
                }
            }
        }

        Image {
            id: heroImage
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width * 0.8625
            source: (root.media.backdrop || root.media.image) ? "image://cached/" + encodeURIComponent(root.media.backdrop || root.media.image) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "#ff080806"
                }
                GradientStop {
                    position: 0.36
                    color: "#f2080806"
                }
                GradientStop {
                    position: 0.62
                    color: "#62080806"
                }
                GradientStop {
                    position: 0.84
                    color: "#12080806"
                }
                GradientStop {
                    position: 1
                    color: "#05080806"
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#12080806"
                }
                GradientStop {
                    position: 0.48
                    color: "#00080806"
                }
                GradientStop {
                    position: 0.79
                    color: "#70080806"
                }
                GradientStop {
                    position: 1
                    color: "#ff080806"
                }
            }
        }

        Column {
            id: heroCopy
            anchors.left: parent.left
            anchors.leftMargin: Math.max(38, root.width * 0.046)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(42, heroSection.height * 0.1)
            width: Math.min(620, root.width * 0.52)
            spacing: 14

            Row {
                spacing: 10

                Text {
                    text: "首页推荐"
                    color: "#d5aa4c"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 2.2
                }

                Text {
                    text: "·"
                    color: "#857c68"
                    font.pixelSize: 11
                }

                Text {
                    text: String(root.currentIndex + 1).padStart(2, "0") + " / " + String(Math.max(1, root.itemCount)).padStart(2, "0")
                    color: "#d8d4cb"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }
            }

            Text {
                width: parent.width
                text: root.media.name || (emby.connected ? "正在抵达你的媒体宇宙" : "尚未连接服务器 · 前往设置添加")
                color: "#f8f5ed"
                font.pixelSize: Math.min(58, Math.max(36, root.width * 0.047))
                font.weight: Font.Bold
                lineHeight: 0.94
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Row {
                visible: root.itemCount > 0
                spacing: 10

                Text {
                    text: root.media.subtitle || ""
                    color: "#ded9cd"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "·"
                    color: "#8c8168"
                    font.pixelSize: 12
                }

                Text {
                    text: root.media.type === "Movie" ? "电影" : root.media.type === "Series" ? "剧集" : root.media.type === "Episode" ? "剧集" : (root.media.type || "影视")
                    color: "#c9c2b2"
                    font.pixelSize: 12
                }

                Text {
                    visible: Number(root.media.communityRating || 0) > 0
                    text: "·"
                    color: "#8c8168"
                    font.pixelSize: 12
                }

                Row {
                    visible: Number(root.media.communityRating || 0) > 0
                    spacing: 5

                    LucideIcon {
                        width: 13
                        height: 13
                        anchors.verticalCenter: parent.verticalCenter
                        name: "star"
                        color: "#e2b74f"
                    }

                    Text {
                        text: Number(root.media.communityRating || 0).toFixed(1)
                        color: "#e2b74f"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                visible: root.itemCount > 0
                width: parent.width
                text: root.media.overview || "暂无简介"
                color: "#c9c5bb"
                font.pixelSize: 13
                lineHeight: 1.45
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Button {
                id: playButton
                visible: root.itemCount > 0
                width: 144
                height: 46
                text: "立即播放"
                hoverEnabled: true

                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        LucideIcon {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            name: "play"
                            color: "#17140e"
                        }

                        Text {
                            text: playButton.text
                            color: "#17140e"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }
                }

                background: Rectangle {
                    radius: 10
                    color: playButton.down ? "#b38c3f" : playButton.hovered ? "#e3c36e" : "#d6ad50"
                    border.width: 1
                    border.color: playButton.hovered ? "#f0d38a" : "#d6ad50"

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                }

                onClicked: root.playRequested()
            }
        }

        Column {
            visible: root.itemCount > 1
            anchors.right: parent.right
            anchors.rightMargin: Math.max(34, root.width * 0.038)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(38, heroSection.height * 0.085)
            spacing: 15

            Row {
                anchors.right: parent.right
                spacing: 8

                Repeater {
                    model: 2

                    delegate: Button {
                        id: arrowButton
                        required property int index
                        width: 42
                        height: 42
                        hoverEnabled: true
                        text: index === 0 ? "上一项" : "下一项"

                        contentItem: Item {
                            LucideIcon {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                name: arrowButton.index === 0 ? "chevron-left" : "chevron-right"
                                color: arrowButton.hovered ? "#f4d484" : "#ddd8ca"
                            }
                        }

                        background: Rectangle {
                            radius: 10
                            color: arrowButton.hovered ? "#282318" : "#a6161511"
                            border.width: 1
                            border.color: arrowButton.hovered ? "#8c7441" : "#49453b"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        onClicked: index === 0 ? root.previousRequested() : root.nextRequested()
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 7

                Repeater {
                    model: root.itemCount

                    delegate: Rectangle {
                        id: progressSegment
                        required property int index
                        width: root.currentIndex === index ? 42 : 16
                        height: 3
                        radius: 2
                        color: root.currentIndex === index ? "#d6a744" : "#4a473f"

                        Behavior on width {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }

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

    Item {
        id: resumeSection
        anchors.top: heroSection.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Rectangle {
            anchors.fill: parent
            color: "#0a0a08"
        }

        Column {
            anchors.fill: parent
            anchors.topMargin: 22
            anchors.leftMargin: Math.max(38, root.width * 0.046)
            anchors.rightMargin: Math.max(38, root.width * 0.046)
            spacing: 13

            Row {
                spacing: 10

                Text {
                    text: "继续观看"
                    color: "#eee7d6"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Text {
                    visible: root.resume.length > 0
                    text: root.resume.length + " 项"
                    color: "#827962"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ListView {
                id: resumeList
                width: parent.width
                height: parent.height - 46
                orientation: ListView.Horizontal
                spacing: 16
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar {}
                model: root.resume

                delegate: Item {
                    required property var modelData
                    width: 270
                    height: resumeList.height

                    Rectangle {
                        id: resumePoster
                        width: 270
                        height: Math.min(152, resumeList.height - 52)
                        radius: 10
                        color: "#14120c"
                        clip: true
                        scale: resumeMouse.containsMouse ? 0.985 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }

                        Image {
                            anchors.fill: parent
                            source: modelData.image ? "image://cached/" + encodeURIComponent(modelData.image) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: modelData.image
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.42
                                    color: "#00000000"
                                }
                                GradientStop {
                                    position: 1
                                    color: "#ad080806"
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 11
                            anchors.bottomMargin: 11
                            text: root.formatTime(modelData.duration || 0)
                            color: "#e8e4da"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            style: Text.Outline
                            styleColor: "#66000000"
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 3
                            color: "#4a4331"
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            height: 3
                            radius: 2
                            color: "#d6a744"
                            width: {
                                const duration = Number(modelData.duration || 0);
                                const position = Number(modelData.position || 0);
                                return duration > 0 ? parent.width * Math.min(1, position / duration) : 0;
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        anchors.top: resumePoster.bottom
                        anchors.topMargin: 8
                        text: modelData.name || "未知标题"
                        color: resumeMouse.containsMouse ? "#e7c979" : "#eee7d6"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        anchors.top: resumePoster.bottom
                        anchors.topMargin: 27
                        text: {
                            const duration = Number(modelData.duration || 0);
                            const position = Number(modelData.position || 0);
                            if (duration > 0 && position > 0)
                                return "剩余 " + root.formatTime(duration - position);
                            return modelData.type === "Movie" ? "电影" : modelData.type === "Series" ? "剧集" : (modelData.type || "影视");
                        }
                        color: "#8d7d5d"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: resumeMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.resumePlayRequested(modelData)
                    }
                }
            }

            Text {
                visible: root.resume.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: 80
                text: emby.connected ? "暂无继续观看内容" : "尚未连接服务器"
                color: "#776846"
                font.pixelSize: 12
            }
        }
    }
}
