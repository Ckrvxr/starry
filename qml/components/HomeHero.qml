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

    signal playRequested()
    signal previousRequested()
    signal nextRequested()
    signal indexRequested(int index)
    signal resumePlayRequested(var item)

    clip: true

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "00:00"
        const total = Math.floor(seconds)
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = total % 60
        return (h > 0 ? String(h).padStart(2, "0") + ":" : "")
             + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }

    // ── 上半：海报 hero ──────────────────────────────
    Item {
        id: heroSection
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.5

        Rectangle {
            anchors.fill: parent
            color: "#080806"
        }

        // 背景层：模糊版海报铺满
        Image {
            id: heroBlur
            anchors.fill: parent
            source: (root.media.backdrop || root.media.image)
                    ? "image://cached/" + encodeURIComponent(root.media.backdrop || root.media.image)
                    : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: heroBlur
            blur: 0.9
            blurMax: 48
            visible: heroImage.status === Image.Ready

            Behavior on visible { NumberAnimation { duration: 300 } }
        }

        // 前景层：清晰海报下移 1/4
        Image {
            id: heroImage
            width: parent.width
            height: parent.height
            y: parent.height * 0.25
            source: (root.media.backdrop || root.media.image)
                    ? "image://cached/" + encodeURIComponent(root.media.backdrop || root.media.image)
                    : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#e6070706" }
                GradientStop { position: 0.3; color: "#8f070706" }
                GradientStop { position: 0.62; color: "#18070706" }
                GradientStop { position: 1; color: "#12070706" }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#18070706" }
                GradientStop { position: 0.38; color: "#00070706" }
                GradientStop { position: 0.7; color: "#42070706" }
                GradientStop { position: 1; color: "#c4070706" }
            }
        }

        Column {
            id: heroCopy
            anchors.left: parent.left
            anchors.leftMargin: Math.max(42, root.width * 0.045)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(36, heroSection.height * 0.1)
            width: Math.min(650, root.width * 0.58)
            spacing: 13

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
                text: root.media.name
                      || (emby.connected ? "正在抵达你的媒体宇宙"
                                         : "尚未连接服务器 · 点击右上角 ⚙ 添加")
                color: "#f8f5ed"
                font.pixelSize: Math.min(48, Math.max(34, root.width * 0.042))
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
                font.pixelSize: 13
                lineHeight: 1.4
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Button {
                id: playButton
                visible: root.itemCount > 0
                width: 132
                height: 42
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
                    radius: 21
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
            anchors.bottomMargin: Math.max(34, heroSection.height * 0.09)
            spacing: 14

            Row {
                anchors.right: parent.right
                spacing: 10

                Repeater {
                    model: 2

                    delegate: Button {
                        id: arrowButton
                        required property int index
                        width: 40
                        height: 40
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
                            radius: 20
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

    // ── 下半：继续观看 ──────────────────────────────
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
            anchors.topMargin: 26
            anchors.leftMargin: Math.max(42, root.width * 0.045)
            anchors.rightMargin: Math.max(42, root.width * 0.045)
            spacing: 16

            Row {
                spacing: 10

                Text {
                    text: "继续观看"
                    color: "#eee7d6"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                Text {
                    visible: root.resume.length > 0
                    text: root.resume.length + " 项"
                    color: "#827962"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ListView {
                id: resumeList
                width: parent.width
                height: parent.height - 52
                orientation: ListView.Horizontal
                spacing: 18
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar { }
                model: root.resume

                delegate: Item {
                    required property var modelData
                    width: 252
                    height: resumeList.height

                    Rectangle {
                        id: resumePoster
                        width: 252
                        height: Math.min(142, resumeList.height - 56)
                        radius: 12
                        color: "#14120c"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: modelData.image
                                    ? "image://cached/" + encodeURIComponent(modelData.image)
                                    : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }

                        // 顶部遮罩
                        Rectangle {
                            anchors.fill: parent
                            visible: modelData.image
                            gradient: Gradient {
                                GradientStop { position: 0.55; color: "#00000000" }
                                GradientStop { position: 1; color: "#99000000" }
                            }
                        }

                        // 播放时长
                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 10
                            anchors.bottomMargin: 10
                            text: root.formatTime(modelData.duration || 0)
                            color: "#e8e4da"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            style: Text.Outline
                            styleColor: "#66000000"
                        }

                        // 进度条
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 4
                            color: "#00000000"
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            height: 4
                            radius: 2
                            color: "#d6a744"
                            width: {
                                const duration = Number(modelData.duration || 0)
                                const position = Number(modelData.position || 0)
                                return duration > 0 ? parent.width * Math.min(1, position / duration) : 0
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        anchors.top: resumePoster.bottom
                        anchors.topMargin: 8
                        text: modelData.name || "未知标题"
                        color: "#eee7d6"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        anchors.top: resumePoster.bottom
                        anchors.topMargin: 27
                        text: {
                            const duration = Number(modelData.duration || 0)
                            const position = Number(modelData.position || 0)
                            if (duration > 0 && position > 0)
                                return "剩余 " + root.formatTime(duration - position)
                            return modelData.type === "Movie" ? "电影"
                                 : modelData.type === "Series" ? "剧集" : (modelData.type || "影视")
                        }
                        color: "#8d7d5d"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    MouseArea {
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
