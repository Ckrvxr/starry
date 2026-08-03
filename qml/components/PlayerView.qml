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

    signal closeRequested
    signal fullscreenRequested

    function revealControls() {
        controlsVisible = true;
        controlsTimer.restart();
    }

    function start(item) {
        media = item;
        visible = true;
        controlsVisible = true;
        forceActiveFocus();
        player.applySettings(settings.hwdec, settings.alang, settings.slang);
        player.play(emby.playbackUrl(item.id), item.position || 0);
        emby.reportPlaybackStart(item.id);
        controlsTimer.restart();
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
    Keys.onEscapePressed: root.fullscreen ? root.fullscreenRequested() : root.stopPlayback()

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    MpvPlayer {
        id: player
        anchors.fill: parent

        onPausedChanged: {
            if (paused) {
                root.controlsVisible = true;
                controlsTimer.stop();
            } else {
                root.revealControls();
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
            onHoveredChanged: if (hovered)
                root.revealControls()
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

        HoverHandler {
            onHoveredChanged: if (hovered)
                root.revealControls()
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
                Layout.preferredWidth: 42
                text: root.formatTime(player.position)
                color: "#bcb6aa"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }

            Slider {
                id: timeline
                Layout.fillWidth: true
                Layout.minimumWidth: 150
                Layout.preferredHeight: 32
                from: 0
                to: Math.max(1, player.duration)
                value: pressed ? value : player.position
                hoverEnabled: true

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
                Layout.preferredWidth: 42
                text: root.formatTime(player.duration)
                color: "#8f8a80"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
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

    TrackSelectionPopup {
        id: audioTrackPopup
        parent: root
        x: Math.max(12, Math.min(root.width - width - 12, audioButton.mapToItem(root, audioButton.width / 2, 0).x - width / 2))
        y: Math.max(12, controlDock.y - height - 10)
        heading: "选择音轨"
        tracks: player.audioTracks
        emptyText: "没有可用音轨"

        onOpened: controlsTimer.stop()
        onClosed: if (!player.paused)
            controlsTimer.restart()
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
        onClosed: if (!player.paused)
            controlsTimer.restart()
        onTrackSelected: function (trackId) {
            player.selectSubtitleTrack(trackId);
            close();
        }
    }

    Timer {
        id: controlsTimer
        interval: 2400
        onTriggered: if (!player.paused)
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
