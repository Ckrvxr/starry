pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var media: ({})
    property var episodes: []
    property bool loading: false
    property bool loadingEpisodes: false
    property int selectedSeason: 1

    readonly property color pageColor: "#070706"
    readonly property color surfaceColor: "#0d0d0b"
    readonly property color textColor: "#f5f2e9"
    readonly property color mutedColor: "#aaa396"
    readonly property color accentColor: "#d9b45d"
    readonly property color hairlineColor: "#28241a"
    readonly property real pageMargin: Math.max(34, Math.min(64, width * 0.055))

    readonly property var seasons: {
        const values = []
        for (let i = 0; i < root.episodes.length; ++i) {
            const season = Math.max(1, Number(root.episodes[i].seasonNumber || 1))
            if (values.indexOf(season) < 0)
                values.push(season)
        }
        return values.sort(function(a, b) { return a - b })
    }

    readonly property var visibleEpisodes: {
        const values = []
        for (let i = 0; i < root.episodes.length; ++i) {
            const episode = root.episodes[i]
            if (Math.max(1, Number(episode.seasonNumber || 1)) === root.selectedSeason)
                values.push(episode)
        }
        return values.sort(function(a, b) {
            return Number(a.indexNumber || 0) - Number(b.indexNumber || 0)
        })
    }

    readonly property var playbackEpisode: {
        let firstUnplayed = null
        for (let i = 0; i < root.episodes.length; ++i) {
            const episode = root.episodes[i]
            if (Number(episode.position || 0) > 0 && !episode.played)
                return episode
            if (firstUnplayed === null && !episode.played)
                firstUnplayed = episode
        }
        return firstUnplayed || (root.episodes.length > 0 ? root.episodes[0] : ({}))
    }

    readonly property bool hasSeriesProgress: {
        for (let i = 0; i < root.episodes.length; ++i) {
            if (root.episodes[i].played || Number(root.episodes[i].position || 0) > 0)
                return true
        }
        return false
    }

    signal backRequested()
    signal playRequested(var media)

    function formatDuration(seconds) {
        const totalMinutes = Math.max(0, Math.round(Number(seconds || 0) / 60))
        if (totalMinutes < 1)
            return ""
        const hours = Math.floor(totalMinutes / 60)
        const minutes = totalMinutes % 60
        if (hours > 0)
            return hours + "小时" + (minutes > 0 ? " " + minutes + "分钟" : "")
        return minutes + "分钟"
    }

    function typeLabel(type) {
        if (type === "Movie") return "电影"
        if (type === "Series" || type === "Episode") return "剧集"
        return type || "影视"
    }

    function metaLine() {
        const values = []
        if (root.media.year)
            values.push(root.media.year)
        values.push(root.typeLabel(root.media.type))
        if (root.media.genre)
            values.push(root.media.genre)
        const duration = root.formatDuration(root.media.duration)
        if (duration.length > 0)
            values.push(duration)
        return values.join("  ·  ")
    }

    function progressPercent(item) {
        const duration = Number(item.duration || 0)
        if (duration <= 0)
            return 0
        return Math.min(100, Math.round(Number(item.position || 0) / duration * 100))
    }

    function episodeTitle(item, fallbackIndex) {
        const number = Number(item.indexNumber || fallbackIndex + 1)
        const prefix = "第 " + number + " 集"
        const compactPrefix = "第" + number + "集"
        const name = String(item.name || "").trim()
        if (name.length === 0 || name === prefix || name === compactPrefix)
            return prefix
        return prefix + "    " + name
    }

    function playButtonText() {
        if (root.media.type === "Series") {
            if (root.loadingEpisodes)
                return "正在准备…"
            return root.hasSeriesProgress ? "继续播放" : "开始播放"
        }
        return Number(root.media.position || 0) > 0 ? "继续播放" : "开始播放"
    }

    function playbackHint() {
        const item = root.media.type === "Series" ? root.playbackEpisode : root.media
        if (!item || !item.id)
            return ""
        const percent = root.progressPercent(item)
        if (root.media.type === "Series") {
            const episodeNumber = Number(item.indexNumber || 1)
            if (percent > 0)
                return "第 " + episodeNumber + " 集  ·  已观看 " + percent + "%"
            if (root.hasSeriesProgress)
                return "接着观看第 " + episodeNumber + " 集"
            return "从第 " + episodeNumber + " 集开始"
        }
        return percent > 0 ? "已观看 " + percent + "%" : ""
    }

    focus: visible
    Keys.onEscapePressed: root.backRequested()
    onVisibleChanged: if (visible) forceActiveFocus()
    onMediaChanged: {
        selectedSeason = 1
        detailScroller.contentY = 0
    }
    onEpisodesChanged: Qt.callLater(function() {
        if (root.seasons.length > 0 && root.seasons.indexOf(root.selectedSeason) < 0)
            root.selectedSeason = root.seasons[0]
    })

    Rectangle {
        anchors.fill: parent
        color: root.pageColor
    }

    Flickable {
        id: detailScroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: root.media.type === "Series"
                       ? episodeSheet.y + episodeSheet.height
                       : heroSection.height
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: detailScrollBar
            width: 3
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                radius: width / 2
                color: root.accentColor
                opacity: detailScrollBar.active ? 0.75 : 0.28
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }

        Item {
            id: heroSection
            width: detailScroller.width
            height: root.media.type === "Series"
                    ? Math.max(560, root.height * 0.79)
                    : root.height

            Rectangle {
                anchors.fill: parent
                color: root.pageColor
            }

            Image {
                id: backdrop
                anchors.fill: parent
                source: (root.media.backdrop || root.media.image)
                        ? "image://cached/" + encodeURIComponent(root.media.backdrop || root.media.image)
                        : ""
                fillMode: Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignRight
                asynchronous: true
                cache: true
                opacity: status === Image.Ready ? 0.92 : 0
                scale: status === Image.Ready ? 1 : 1.025

                Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                anchors.fill: parent
                visible: backdrop.status !== Image.Ready
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#12110d" }
                    GradientStop { position: 1; color: "#211b10" }
                }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ff070706" }
                    GradientStop { position: 0.24; color: "#ef070706" }
                    GradientStop { position: 0.52; color: "#92070706" }
                    GradientStop { position: 0.78; color: "#2b070706" }
                    GradientStop { position: 1; color: "#30070706" }
                }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#16070706" }
                    GradientStop { position: 0.55; color: "#06070706" }
                    GradientStop { position: 0.82; color: "#99070706" }
                    GradientStop { position: 1; color: "#ff070706" }
                }
            }

            Repeater {
                model: [
                    { "x": 0.09, "y": 0.2, "s": 2, "o": 0.3 },
                    { "x": 0.37, "y": 0.1, "s": 1, "o": 0.4 },
                    { "x": 0.72, "y": 0.18, "s": 2, "o": 0.25 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    x: heroSection.width * modelData.x
                    y: heroSection.height * modelData.y
                    width: modelData.s
                    height: modelData.s
                    radius: width / 2
                    color: "#f0ce78"
                    opacity: modelData.o
                }
            }

            Column {
                id: heroCopy
                anchors.left: parent.left
                anchors.leftMargin: root.pageMargin
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.media.type === "Series" ? 86 : 68
                width: Math.min(700, root.width * 0.63)
                spacing: 14

                Row {
                    height: 27
                    spacing: 12

                    Row {
                        height: parent.height
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✦"
                            color: root.accentColor
                            font.pixelSize: 12
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "STARRY  /  " + root.typeLabel(root.media.type).toUpperCase()
                            color: "#d7c393"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                        }
                    }

                    Rectangle {
                        visible: Number(root.media.communityRating || 0) > 0
                        width: ratingText.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: "#1cffffff"
                        border.width: 1
                        border.color: "#26ffffff"

                        Text {
                            id: ratingText
                            anchors.centerIn: parent
                            text: "★  " + Number(root.media.communityRating || 0).toFixed(1)
                            color: "#f0cf79"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root.media.name || "加载中…"
                    color: root.textColor
                    font.pixelSize: Math.min(62, Math.max(39, root.width * 0.052))
                    font.weight: Font.Bold
                    font.letterSpacing: -0.5
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.metaLine()
                    color: "#d0cabd"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.media.overview || "暂无简介"
                    color: "#bdb7aa"
                    font.pixelSize: 14
                    lineHeight: 1.48
                    wrapMode: Text.Wrap
                    maximumLineCount: root.media.type === "Series" ? 4 : 5
                    elide: Text.ElideRight
                }

                Item { width: 1; height: 2 }

                Row {
                    height: 50
                    spacing: 16

                    Button {
                        id: primaryPlayButton
                        width: Math.max(152, playButtonLabel.implicitWidth + 58)
                        height: 50
                        enabled: !root.loading
                                 && (root.media.type !== "Series"
                                     ? Boolean(root.media.id)
                                     : !root.loadingEpisodes && Boolean(root.playbackEpisode.id))
                        hoverEnabled: true

                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▶"
                                color: "#17130b"
                                font.pixelSize: 13
                            }

                            Text {
                                id: playButtonLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.playButtonText()
                                color: "#17130b"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }

                        background: Rectangle {
                            radius: 25
                            color: !primaryPlayButton.enabled ? "#6c624c"
                                 : primaryPlayButton.down ? "#c19b45"
                                 : primaryPlayButton.hovered ? "#efd080" : root.accentColor
                            border.width: 1
                            border.color: primaryPlayButton.hovered ? "#f7dfa3" : "#e1c477"

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }
                        }

                        onClicked: root.playRequested(root.media.type === "Series"
                                                      ? root.playbackEpisode : root.media)
                    }

                    Text {
                        visible: text.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.playbackHint()
                        color: "#8f887b"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Item {
            id: episodeSheet
            visible: root.media.type === "Series"
            x: 0
            y: heroSection.height - 28
            width: detailScroller.width
            height: visible ? episodesColumn.implicitHeight + 92 : 0

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: "#f60b0b09"
                border.width: 1
                border.color: "#312b1e"
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 28
                anchors.bottom: parent.bottom
                color: root.surfaceColor
            }

            Column {
                id: episodesColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: root.pageMargin
                anchors.rightMargin: root.pageMargin
                anchors.topMargin: 50
                spacing: 0

                Item {
                    width: parent.width
                    height: 46

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 54
                        anchors.verticalCenter: parent.verticalCenter
                        text: "第 " + root.selectedSeason + " 季"
                        color: root.textColor
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.visibleEpisodes.length + " 集"
                        color: "#837d71"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }
                }

                Flickable {
                    visible: root.seasons.length > 1
                    width: parent.width
                    height: visible ? 48 : 0
                    contentWidth: seasonTabs.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: seasonTabs
                        height: parent.height
                        spacing: 8

                        Repeater {
                            model: root.seasons

                            delegate: Button {
                                id: seasonTab
                                required property var modelData
                                width: 78
                                height: 34
                                anchors.verticalCenter: parent.verticalCenter
                                text: "第 " + modelData + " 季"
                                hoverEnabled: true

                                contentItem: Text {
                                    text: seasonTab.text
                                    color: root.selectedSeason === Number(seasonTab.modelData)
                                           ? "#17130b" : "#aaa397"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    radius: 17
                                    color: root.selectedSeason === Number(seasonTab.modelData)
                                           ? root.accentColor
                                           : seasonTab.hovered ? "#19ffffff" : "transparent"
                                    border.width: root.selectedSeason === Number(seasonTab.modelData) ? 0 : 1
                                    border.color: "#28251e"

                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }

                                onClicked: root.selectedSeason = Number(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.hairlineColor
                }

                Item {
                    visible: root.loadingEpisodes || root.visibleEpisodes.length === 0
                    width: parent.width
                    height: visible ? 190 : 0

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: root.loadingEpisodes
                        visible: running
                        implicitWidth: 32
                        implicitHeight: 32
                    }

                    Column {
                        visible: !root.loadingEpisodes
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "✦"
                            color: "#65573a"
                            font.pixelSize: 18
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "这一季暂时没有内容"
                            color: "#777064"
                            font.pixelSize: 12
                        }
                    }
                }

                Repeater {
                    model: root.loadingEpisodes ? [] : root.visibleEpisodes

                    delegate: Item {
                        id: episodeRow
                        required property var modelData
                        required property int index
                        width: episodesColumn.width
                        height: 148

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            radius: 16
                            color: episodeMouse.containsMouse ? "#12ffffff" : "transparent"

                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        Text {
                            width: 40
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(Number(episodeRow.modelData.indexNumber || episodeRow.index + 1)).padStart(2, "0")
                            color: episodeMouse.containsMouse ? "#d9bd78" : "#625d54"
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8

                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        Rectangle {
                            id: episodeStill
                            width: Math.min(210, Math.max(166, root.width * 0.2))
                            height: Math.round(width * 0.5625)
                            radius: 9
                            clip: true
                            anchors.left: parent.left
                            anchors.leftMargin: 50
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#17150f"

                            Image {
                                anchors.fill: parent
                                source: episodeRow.modelData.image
                                        ? "image://cached/" + encodeURIComponent(episodeRow.modelData.image)
                                        : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "#3d000000"
                                opacity: episodeMouse.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 130 } }
                            }

                            Rectangle {
                                visible: (episodeRow.modelData.position || 0) > 0
                                         && (episodeRow.modelData.duration || 0) > 0
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 3
                                color: "#594f39"

                                Rectangle {
                                    height: parent.height
                                    width: parent.width * Math.min(1, Number(episodeRow.modelData.position || 0)
                                                                    / Number(episodeRow.modelData.duration || 1))
                                    color: root.accentColor
                                }
                            }
                        }

                        Column {
                            anchors.left: episodeStill.right
                            anchors.leftMargin: 20
                            anchors.right: playAffordance.left
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                width: parent.width
                                text: root.episodeTitle(episodeRow.modelData, episodeRow.index)
                                color: episodeMouse.containsMouse ? "#f5e5b7" : root.textColor
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight

                                Behavior on color { ColorAnimation { duration: 130 } }
                            }

                            Row {
                                spacing: 11

                                Text {
                                    text: root.formatDuration(episodeRow.modelData.duration)
                                    color: "#817b70"
                                    font.pixelSize: 11
                                }

                                Text {
                                    visible: text.length > 0
                                    text: episodeRow.modelData.premiereDate || ""
                                    color: "#716b61"
                                    font.pixelSize: 11
                                }

                                Text {
                                    visible: episodeRow.modelData.played || false
                                    text: "✓  已看"
                                    color: "#b99b55"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            Text {
                                width: parent.width
                                text: episodeRow.modelData.overview || "暂无简介"
                                color: "#958f84"
                                font.pixelSize: 12
                                lineHeight: 1.35
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            id: playAffordance
                            width: 38
                            height: 38
                            radius: 19
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: episodeMouse.containsMouse ? root.accentColor : "#12ffffff"
                            border.width: 1
                            border.color: episodeMouse.containsMouse ? "#e5c980" : "#24ffffff"

                            Behavior on color { ColorAnimation { duration: 130 } }

                            Text {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 1
                                text: "▶"
                                color: episodeMouse.containsMouse ? "#17130b" : "#d0c9bc"
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: root.hairlineColor
                        }

                        MouseArea {
                            id: episodeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.playRequested(episodeRow.modelData)
                        }
                    }
                }

                Item { width: 1; height: 40 }
            }
        }
    }

    Button {
        id: backButton
        z: 20
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 26
        anchors.topMargin: 26
        width: 44
        height: 44
        text: "←"
        hoverEnabled: true

        contentItem: Text {
            text: backButton.text
            color: backButton.hovered ? "#f3d88d" : "#e5dfd2"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 22
            color: backButton.hovered ? "#d92b271d" : "#b51a1915"
            border.width: 1
            border.color: backButton.hovered ? "#806a3b" : "#3c382f"

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        ToolTip.visible: hovered
        ToolTip.text: "返回浏览"
        ToolTip.delay: 500
        onClicked: root.backRequested()
    }

    BusyIndicator {
        z: 20
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 28
        running: root.loading
        visible: running
        implicitWidth: 28
        implicitHeight: 28
    }
}
