pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: root

    property var episodes: []
    property string seriesName: ""
    property bool loading: false
    property int selectedSeason: seasons.length > 0 ? seasons[0] : 1

    readonly property var seasons: {
        const values = []
        for (let i = 0; i < episodes.length; ++i) {
            const season = Math.max(1, Number(episodes[i].seasonNumber || 1))
            if (values.indexOf(season) < 0)
                values.push(season)
        }
        return values.sort(function(a, b) { return a - b })
    }

    readonly property var visibleEpisodes: {
        const values = []
        for (let i = 0; i < episodes.length; ++i) {
            const episode = episodes[i]
            if (Math.max(1, Number(episode.seasonNumber || 1)) === selectedSeason)
                values.push(episode)
        }
        return values.sort(function(a, b) {
            return Number(a.indexNumber || 0) - Number(b.indexNumber || 0)
        })
    }

    signal playRequested(var media)
    signal backRequested()

    function formatDuration(seconds) {
        const minutes = Math.max(0, Math.round(Number(seconds || 0) / 60))
        if (minutes < 1)
            return ""
        const hours = Math.floor(minutes / 60)
        const remaining = minutes % 60
        return hours > 0 ? hours + "小时" + (remaining > 0 ? " " + remaining + "分钟" : "")
                         : minutes + "分钟"
    }

    Rectangle {
        anchors.fill: parent
        color: "#070706"
        opacity: 0.96
    }

    Column {
        id: headerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 36
        anchors.rightMargin: 36
        anchors.topMargin: 26
        spacing: 10

        Row {
            width: parent.width
            height: 42
            spacing: 13

            Rectangle {
                width: 3
                height: 30
                radius: 2
                color: "#d7a744"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "剧集列表"
                color: "#f1ede4"
                font.pixelSize: 24
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: (root.seriesName.length > 0 ? root.seriesName + "  ·  " : "")
                      + root.seasons.length + " 季"
                color: "#8e8677"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                id: backButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 98
                height: 34
                text: "‹  返回剧集"
                hoverEnabled: true

                contentItem: Text {
                    text: backButton.text
                    color: backButton.hovered ? "#edcb77" : "#aaa18f"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 17
                    color: backButton.hovered ? "#241e13" : "#12110e"
                }
                onClicked: root.backRequested()
            }
        }

        Rectangle {
            width: parent.width
            height: 54
            radius: 14
            color: "#10100e"

            Flickable {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                contentWidth: seasonRow.width
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: seasonRow
                    height: parent.height
                    spacing: 8

                    Repeater {
                        model: root.seasons

                        delegate: Button {
                            id: seasonButton
                            required property var modelData
                            width: 82
                            height: 34
                            anchors.verticalCenter: parent.verticalCenter
                            text: "第 " + modelData + " 季"
                            hoverEnabled: true

                            contentItem: Text {
                                text: seasonButton.text
                                color: root.selectedSeason === Number(seasonButton.modelData) ? "#15110a" : "#b2aa9b"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 17
                                color: root.selectedSeason === Number(seasonButton.modelData) ? "#d9a747"
                                      : seasonButton.hovered ? "#26231d" : "#1a1916"
                            }
                            onClicked: root.selectedSeason = Number(modelData)
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 54
            radius: 14
            color: "#10100e"

            Flickable {
                id: episodeNavigator
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                contentWidth: episodeNumberRow.width
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: episodeNumberRow
                    height: parent.height
                    spacing: 7

                    Repeater {
                        model: root.visibleEpisodes

                        delegate: Button {
                            id: episodeNumberButton
                            required property var modelData
                            required property int index
                            width: 38
                            height: 34
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(Number(modelData.indexNumber || index + 1))
                            hoverEnabled: true

                            contentItem: Text {
                                text: episodeNumberButton.text
                                color: episodeNumberButton.hovered ? "#edca75" : "#c4beb2"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 10
                                color: episodeNumberButton.hovered ? "#2b2519" : "#1a1916"
                            }
                            onClicked: episodeList.positionViewAtIndex(index, ListView.Beginning)
                        }
                    }
                }
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: root.loading
        visible: running
        implicitWidth: 36
        implicitHeight: 36
    }

    Text {
        anchors.centerIn: parent
        visible: !root.loading && root.visibleEpisodes.length === 0
        text: "暂无剧集"
        color: "#776f60"
        font.pixelSize: 13
    }

    ListView {
        id: episodeList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerColumn.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 36
        anchors.rightMargin: 36
        anchors.topMargin: 16
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        model: root.loading ? [] : root.visibleEpisodes
        ScrollBar.vertical: ScrollBar { }

        delegate: Item {
            id: episodeRow
            required property var modelData
            required property int index
            width: episodeList.width
            height: 164

            Rectangle {
                anchors.fill: parent
                color: rowMouse.containsMouse ? "#0e0d0a" : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                width: 48
                height: 42
                radius: 11
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: "#141310"

                Text {
                    anchors.centerIn: parent
                    text: String(Number(episodeRow.modelData.indexNumber || episodeRow.index + 1)).padStart(2, "0")
                    color: "#c9c2b3"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                }
            }

            Item {
                id: stillFrame
                width: 224
                height: 126
                anchors.left: parent.left
                anchors.leftMargin: 68
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: episodeStill
                    anchors.fill: parent
                    source: episodeRow.modelData.image
                        ? "image://cached/" + encodeURIComponent(episodeRow.modelData.image)
                        : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: ShaderEffectSource {
                            sourceItem: Rectangle {
                                width: episodeStill.width
                                height: episodeStill.height
                                radius: 9
                                color: "white"
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: "#4f000000"
                    opacity: rowMouse.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        color: "white"
                        font.pixelSize: 19
                    }
                }
            }

            Column {
                anchors.left: stillFrame.right
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Row {
                    spacing: 12

                    Text {
                        text: "第 " + Number(episodeRow.modelData.indexNumber || episodeRow.index + 1) + " 集"
                        color: "#f0ece3"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    Text {
                        text: root.formatDuration(episodeRow.modelData.duration)
                        color: "#948b7a"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: episodeRow.modelData.premiereDate || ""
                        color: "#756e61"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    text: episodeRow.modelData.overview || episodeRow.modelData.name || "暂无简介"
                    color: "#aaa396"
                    font.pixelSize: 12
                    lineHeight: 1.35
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#171612"
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playRequested(episodeRow.modelData)
            }
        }
    }
}
