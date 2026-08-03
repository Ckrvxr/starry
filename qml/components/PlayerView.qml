pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Starry

Item {
    id: root

    property var media: ({})
    property bool controlsVisible: true
    property bool fullscreen: false
    readonly property bool progressReady: player.playing && isFinite(player.duration) && player.duration > 0

    signal closeRequested
    signal fullscreenRequested

    function revealControls() {
        if (!player.playing) {
            controlsTimer.stop();
            return;
        }
        controlsVisible = true;
        if (infoDockHover.hovered || connectionDockHover.hovered || controlDockHover.hovered || volumePopup.visible || audioTrackPopup.visible || subtitleTrackPopup.visible)
            controlsTimer.stop();
        else
            controlsTimer.restart();
    }

    function formatLoadRate(bytesPerSecond) {
        const rate = Number(bytesPerSecond || 0);
        if (!isFinite(rate) || rate <= 0)
            return "0 KB/s";
        if (rate >= 1000000)
            return (rate / 1000000).toFixed(rate >= 10000000 ? 1 : 2) + " MB/s";
        return Math.round(rate / 1000) + " KB/s";
    }

    function start(item) {
        media = item;
        visible = true;
        controlsVisible = true;
        forceActiveFocus();
        player.applySettings(settings.hwdec, settings.alang, settings.slang);
        player.play(emby.playbackUrl(item.id), item.position || 0);
        emby.reportPlaybackStart(item.id);
        controlsTimer.stop();
    }

    function stopPlayback() {
        if (!visible)
            return;
        if (media.id)
            emby.reportPlaybackStopped(media.id, player.position);
        player.stop();
        visible = false;
        controlsVisible = true;
        closeRequested();
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "00:00";
        const total = Math.floor(seconds);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        return (h > 0 ? String(h).padStart(2, "0") + ":" : "") + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
    }

    function adjustVolume(step) {
        player.volume = Math.max(0, Math.min(100, player.volume + step));
        root.revealControls();
    }

    visible: false
    focus: visible

    Keys.onSpacePressed: {
        player.togglePause();
        root.revealControls();
    }
    Keys.onLeftPressed: {
        player.seekRelative(-10);
        root.revealControls();
    }
    Keys.onRightPressed: {
        player.seekRelative(10);
        root.revealControls();
    }
    Keys.onUpPressed: root.adjustVolume(5)
    Keys.onDownPressed: root.adjustVolume(-5)
    Keys.onEscapePressed: root.fullscreen ? root.fullscreenRequested() : root.stopPlayback()

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    MpvPlayer {
        id: player
        anchors.fill: parent

        onPausedChanged: root.revealControls()
        onPlayingChanged: {
            if (playing) {
                root.controlsVisible = true;
                root.revealControls();
            } else {
                controlsTimer.stop();
                volumePopup.close();
                audioTrackPopup.close();
                subtitleTrackPopup.close();
            }
        }
        onPlaybackEnded: root.stopPlayback()
        onMpvError: function (message) {
            errorText.text = message;
            errorToast.open();
        }
    }

    // 设置页修改 mpv 选项时，对已初始化的播放器即时生效
    Connections {
        target: settings
        function onHwdecChanged() {
            player.applySettings(settings.hwdec, settings.alang, settings.slang);
        }
        function onAlangChanged() {
            player.applySettings(settings.hwdec, settings.alang, settings.slang);
        }
        function onSlangChanged() {
            player.applySettings(settings.hwdec, settings.alang, settings.slang);
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.controlsVisible ? Qt.ArrowCursor : Qt.BlankCursor

        onPositionChanged: root.revealControls()
        onClicked: {
            player.togglePause();
            root.revealControls();
        }
        onDoubleClicked: root.fullscreenRequested()
    }

    Rectangle {
        id: infoDock
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 22
        anchors.topMargin: 22
        readonly property real naturalWidth: Math.max(mediaTitleMetrics.advanceWidth, mediaSubtitleText.visible ? mediaSubtitleMetrics.advanceWidth : 0) + 92
        width: Math.min(root.width - 44, Math.max(210, Math.min(620, naturalWidth)))
        height: 54
        radius: 27
        color: "#d9141412"
        border.width: 1
        border.color: "#35ffffff"
        opacity: root.controlsVisible ? 1 : 0
        scale: root.controlsVisible ? 1 : 0.97
        enabled: root.controlsVisible

        Behavior on opacity {
            NumberAnimation {
                duration: 170
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 190
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        TextMetrics {
            id: mediaTitleMetrics
            font: mediaTitleText.font
            text: mediaTitleText.text
        }

        TextMetrics {
            id: mediaSubtitleMetrics
            font: mediaSubtitleText.font
            text: mediaSubtitleText.text
        }

        HoverHandler {
            id: infoDockHover
            onHoveredChanged: {
                if (hovered) {
                    root.controlsVisible = true;
                    controlsTimer.stop();
                } else {
                    root.revealControls();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.revealControls()
        }

        Button {
            id: closeButton
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            hoverEnabled: true
            text: "退出播放"

            contentItem: Item {
                LucideIcon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    name: "arrow-left"
                    color: closeButton.hovered ? "#f1cf78" : "#f2eee5"
                }
            }

            background: Rectangle {
                radius: 21
                color: closeButton.hovered ? "#20ffffff" : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            ToolTip.visible: hovered
            ToolTip.text: "退出播放"
            ToolTip.delay: 450
            onClicked: root.stopPlayback()
        }

        Rectangle {
            anchors.left: closeButton.right
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: "#32ffffff"
        }

        Column {
            anchors.left: closeButton.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                id: mediaTitleText
                width: parent.width
                text: root.media.name || player.mediaTitle || "正在播放"
                color: "#f5f2ea"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                id: mediaSubtitleText
                width: parent.width
                visible: text.length > 0
                text: root.media.seriesName || root.media.subtitle || ""
                color: "#918b80"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        id: connectionDock
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 22
        anchors.topMargin: 22
        readonly property real requiredLoadRate: Math.max(0, (player.videoBitrate + player.audioBitrate) / 8)
        readonly property int qualityLevel: {
            if (!emby.connected || player.buffering)
                return 0;
            if (!player.cacheIdle && player.instantLoadRate <= 0)
                return 0;
            if (player.averageLoadRate <= 0 || requiredLoadRate <= 0)
                return player.cacheIdle || player.instantLoadRate > 0 ? 2 : 1;
            const averageRatio = player.averageLoadRate / requiredLoadRate;
            const instantRatio = player.cacheIdle ? averageRatio : player.instantLoadRate / requiredLoadRate;
            if (averageRatio < 0.75 || instantRatio < 0.55)
                return 0;
            if (averageRatio < 1.35 || instantRatio < 0.95)
                return 1;
            return 2;
        }
        readonly property real naturalWidth: Math.max(connectionTitleMetrics.advanceWidth, connectionAverageMetrics.advanceWidth) + 58
        width: Math.max(170, Math.min(300, root.width - infoDock.width - 66, naturalWidth))
        height: 54
        radius: 27
        color: "#d9141412"
        border.width: 1
        border.color: "#35ffffff"
        opacity: root.controlsVisible ? 1 : 0
        scale: root.controlsVisible ? 1 : 0.97
        enabled: root.controlsVisible

        Behavior on opacity {
            NumberAnimation {
                duration: 170
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 190
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        TextMetrics {
            id: connectionTitleMetrics
            font: connectionTitleText.font
            text: connectionTitleText.text
        }

        TextMetrics {
            id: connectionAverageMetrics
            font: connectionAverageText.font
            text: connectionAverageText.text
        }

        HoverHandler {
            id: connectionDockHover
            onHoveredChanged: {
                if (hovered) {
                    root.controlsVisible = true;
                    controlsTimer.stop();
                } else {
                    root.revealControls();
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: connectionStateDot.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                id: connectionTitleText
                width: parent.width
                text: root.formatLoadRate(player.instantLoadRate)
                color: "#f5f2ea"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                id: connectionAverageText
                width: parent.width
                text: "Avg. " + root.formatLoadRate(player.averageLoadRate) + " / Need. " + root.formatLoadRate(connectionDock.requiredLoadRate)
                color: "#918b80"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: connectionStateDot
            anchors.right: parent.right
            anchors.rightMargin: 17
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 4
            color: connectionDock.qualityLevel === 0 ? "#ef6a5b" : connectionDock.qualityLevel === 1 ? "#e6a34a" : "#55d99a"
            border.width: 1
            border.color: "#44110f0a"
        }
    }

    Rectangle {
        id: controlDock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: Math.min(900, root.width - 48)
        height: 72
        radius: 27
        color: "#e6141412"
        border.width: 1
        border.color: "#3cffffff"
        opacity: player.playing && root.controlsVisible ? 1 : 0
        scale: player.playing && root.controlsVisible ? 1 : 0.97
        enabled: player.playing && root.controlsVisible

        Behavior on opacity {
            NumberAnimation {
                duration: 170
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 190
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: controlDockHover
            onHoveredChanged: {
                if (hovered) {
                    root.controlsVisible = true;
                    controlsTimer.stop();
                } else {
                    root.revealControls();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.revealControls()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 8

            Button {
                id: playPauseButton
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                text: player.paused ? "播放" : "暂停"

                contentItem: Item {
                    LucideIcon {
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        name: player.paused ? "play" : "pause"
                        color: "#17130b"
                    }
                }
                background: Rectangle {
                    radius: 24
                    color: playPauseButton.down ? "#bd9847" : playPauseButton.hovered ? "#f0d183" : "#d9b45d"
                    border.width: 1
                    border.color: playPauseButton.hovered ? "#f8e1a9" : "#e7c979"
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }
                ToolTip.visible: hovered
                ToolTip.text: playPauseButton.text
                ToolTip.delay: 450
                onClicked: {
                    player.togglePause();
                    root.revealControls();
                }
            }

            Text {
                id: currentTimeText
                Layout.preferredWidth: 42
                text: root.formatTime(player.position)
                color: "#bcb6aa"
                opacity: root.progressReady ? 1 : 0
                font.pixelSize: 10
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                    }
                }
            }

            Slider {
                id: timeline
                Layout.fillWidth: true
                Layout.minimumWidth: 150
                Layout.preferredHeight: 32
                from: 0
                to: Math.max(1, player.duration)
                value: pressed ? value : Math.min(player.position, Math.max(1, player.duration))
                hoverEnabled: true
                enabled: root.progressReady
                opacity: root.progressReady ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                    }
                }

                onMoved: {
                    player.position = value;
                    root.revealControls();
                }

                background: Rectangle {
                    x: timeline.leftPadding
                    y: timeline.topPadding + timeline.availableHeight / 2 - height / 2
                    width: timeline.availableWidth
                    height: 3
                    radius: 2
                    color: "#4b4842"

                    Rectangle {
                        width: timeline.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: "#d9b45d"
                    }

                    Repeater {
                        model: player.chapters

                        delegate: Item {
                            required property var modelData
                            readonly property real chapterTime: Number(modelData.time || 0)
                            readonly property string chapterTitle: String(modelData.title || "")
                            visible: player.duration > 0 && chapterTime > 0.05 && chapterTime < player.duration
                            x: Math.max(1, Math.min(parent.width - 1, parent.width * chapterTime / player.duration)) - width / 2
                            y: -6
                            width: 12
                            height: 15
                            z: 2

                            Rectangle {
                                anchors.centerIn: parent
                                width: 2
                                height: 9
                                radius: 1
                                color: player.position >= chapterTime ? "#f0d184" : "#8f8775"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            HoverHandler {
                                id: chapterHover
                            }

                            ToolTip.visible: chapterHover.hovered && chapterTitle.length > 0
                            ToolTip.text: chapterTitle
                            ToolTip.delay: 220
                        }
                    }
                }

                handle: Rectangle {
                    x: timeline.leftPadding + timeline.visualPosition * (timeline.availableWidth - width)
                    y: timeline.topPadding + timeline.availableHeight / 2 - height / 2
                    width: timeline.pressed || timeline.hovered ? 12 : 8
                    height: width
                    radius: width / 2
                    color: "#f0d184"
                    border.width: 1
                    border.color: "#f7e2ae"

                    Behavior on width {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }
            }

            Text {
                id: durationText
                Layout.preferredWidth: 42
                text: root.formatTime(player.duration)
                color: "#8f8a80"
                opacity: root.progressReady ? 1 : 0
                font.pixelSize: 10
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                    }
                }
            }

            Button {
                id: volumeButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                text: "音量"

                contentItem: Item {
                    LucideIcon {
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        name: player.volume <= 0 ? "volume-x" : player.volume < 50 ? "volume-1" : "volume-2"
                        color: volumeButton.hovered || volumePopup.visible ? "#f0ce79" : "#aaa499"
                    }
                }
                background: Rectangle {
                    radius: 20
                    color: volumeButton.hovered || volumePopup.visible ? "#16ffffff" : "transparent"
                }
                ToolTip.visible: hovered && !volumePopup.visible
                ToolTip.text: "音量 " + Math.round(player.volume) + "%"
                ToolTip.delay: 450
                onClicked: {
                    audioTrackPopup.close();
                    subtitleTrackPopup.close();
                    root.revealControls();
                    volumePopup.open();
                }
            }

            Button {
                id: audioButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                text: "音轨"

                contentItem: Item {
                    LucideIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        name: "audio-lines"
                        color: audioButton.hovered ? "#f0ce79" : "#aaa499"
                    }
                }
                background: Rectangle {
                    radius: 20
                    color: audioButton.hovered ? "#16ffffff" : "transparent"
                }
                ToolTip.visible: hovered && !audioTrackPopup.visible
                ToolTip.text: "选择音轨"
                ToolTip.delay: 450
                onClicked: {
                    volumePopup.close();
                    subtitleTrackPopup.close();
                    root.revealControls();
                    audioTrackPopup.open();
                }
            }

            Button {
                id: subtitleButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                text: "字幕"

                contentItem: Item {
                    LucideIcon {
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        name: "captions"
                        color: subtitleButton.hovered ? "#f0ce79" : "#aaa499"
                    }
                }
                background: Rectangle {
                    radius: 20
                    color: subtitleButton.hovered ? "#16ffffff" : "transparent"
                }
                ToolTip.visible: hovered && !subtitleTrackPopup.visible
                ToolTip.text: "选择字幕"
                ToolTip.delay: 450
                onClicked: {
                    volumePopup.close();
                    audioTrackPopup.close();
                    root.revealControls();
                    subtitleTrackPopup.open();
                }
            }

            Button {
                id: fullscreenButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                text: root.fullscreen ? "退出全屏" : "进入全屏"

                contentItem: Item {
                    LucideIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        name: root.fullscreen ? "minimize" : "maximize"
                        color: fullscreenButton.hovered ? "#f0ce79" : "#d2ccc1"
                    }
                }
                background: Rectangle {
                    radius: 20
                    color: fullscreenButton.hovered ? "#16ffffff" : "transparent"
                }
                ToolTip.visible: hovered
                ToolTip.text: fullscreenButton.text
                ToolTip.delay: 450
                onClicked: {
                    root.fullscreenRequested();
                    root.revealControls();
                }
            }
        }
    }

    Popup {
        id: volumePopup
        parent: root
        x: Math.max(12, Math.min(root.width - width - 12, volumeButton.mapToItem(root, volumeButton.width / 2, 0).x - width / 2))
        y: Math.max(12, controlDock.y - height - 10)
        width: 76
        height: 190
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 120
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.94
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        exit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 90
                }
                NumberAnimation {
                    property: "scale"
                    from: 1
                    to: 0.97
                    duration: 90
                }
            }
        }

        background: Rectangle {
            radius: 18
            color: "#f2171612"
            border.width: 1
            border.color: "#62563c"
        }

        contentItem: Item {
            Text {
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(player.volume) + "%"
                color: "#f0d58d"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Slider {
                id: volumeSlider
                anchors.top: parent.top
                anchors.topMargin: 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                width: 36
                orientation: Qt.Vertical
                from: 0
                to: 100
                value: player.volume
                stepSize: 1
                hoverEnabled: true

                onMoved: {
                    player.volume = value;
                    root.revealControls();
                }

                background: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.availableWidth / 2 - width / 2
                    y: volumeSlider.topPadding
                    width: 3
                    height: volumeSlider.availableHeight
                    radius: 2
                    color: "#4b4842"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: volumeSlider.position * parent.height
                        radius: 2
                        color: "#d9b45d"
                    }
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.availableWidth / 2 - width / 2
                    y: volumeSlider.topPadding + (1 - volumeSlider.position) * (volumeSlider.availableHeight - height)
                    width: volumeSlider.pressed || volumeSlider.hovered ? 12 : 9
                    height: width
                    radius: width / 2
                    color: "#f0d184"
                    border.width: 1
                    border.color: "#f7e2ae"

                    Behavior on width {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }
            }
        }

        onOpened: controlsTimer.stop()
        onClosed: root.revealControls()
    }

    TrackSelectionPopup {
        id: audioTrackPopup
        parent: root
        x: Math.max(12, Math.min(root.width - width - 12, audioButton.mapToItem(root, audioButton.width / 2, 0).x - width / 2))
        y: Math.max(12, controlDock.y - height - 10)
        heading: "选择音轨"
        tracks: player.audioTracks
        emptyText: "没有可用音轨"

        onOpened: controlsTimer.stop()
        onClosed: root.revealControls()
        onTrackSelected: function (trackId) {
            player.selectAudioTrack(trackId);
            close();
        }
    }

    TrackSelectionPopup {
        id: subtitleTrackPopup
        parent: root
        x: Math.max(12, Math.min(root.width - width - 12, subtitleButton.mapToItem(root, subtitleButton.width / 2, 0).x - width / 2))
        y: Math.max(12, controlDock.y - height - 10)
        heading: "选择字幕"
        tracks: player.subtitleTracks
        allowOff: true
        emptyText: "没有可用字幕"

        onOpened: controlsTimer.stop()
        onClosed: root.revealControls()
        onTrackSelected: function (trackId) {
            player.selectSubtitleTrack(trackId);
            close();
        }
    }

    Timer {
        id: controlsTimer
        interval: 3000
        onTriggered: if (!infoDockHover.hovered && !connectionDockHover.hovered && !controlDockHover.hovered && !volumePopup.visible && !audioTrackPopup.visible && !subtitleTrackPopup.visible)
            root.controlsVisible = false
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.visible && player.playing
        onTriggered: if (root.media.id)
            emby.reportPlaybackProgress(root.media.id, player.position, player.paused)
    }

    Popup {
        id: errorToast
        anchors.centerIn: parent
        modal: false
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#ec211b1b"
            radius: 18
            border.width: 1
            border.color: "#754444"
        }

        contentItem: Text {
            id: errorText
            width: 360
            padding: 16
            color: "#f6eded"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
}
