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
        controlsVisible = true
        controlsTimer.restart()
    }

    function start(item) {
        media = item
        visible = true
        controlsVisible = true
        forceActiveFocus()
        player.applySettings(settings.hwdec, settings.alang, settings.slang)
        player.play(emby.playbackUrl(item.id), item.position || 0)
        emby.reportPlaybackStart(item.id)
        controlsTimer.restart()
    }

    function stopPlayback() {
        if (!visible)
            return
        if (media.id)
            emby.reportPlaybackStopped(media.id, player.position)
        player.stop()
        visible = false
        controlsVisible = true
        closeRequested()
    }

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

    visible: false
    focus: visible

    Keys.onSpacePressed: {
        player.togglePause()
        root.revealControls()
    }
    Keys.onLeftPressed: {
        player.seekRelative(-10)
        root.revealControls()
    }
    Keys.onRightPressed: {
        player.seekRelative(10)
        root.revealControls()
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
                root.controlsVisible = true
                controlsTimer.stop()
            } else {
                root.revealControls()
            }
        }
        onPlaybackEnded: root.stopPlayback()
        onMpvError: function(message) {
            errorText.text = message
            errorToast.open()
        }
    }

    // 设置页修改 mpv 选项时，对已初始化的播放器即时生效
    Connections {
        target: settings
        function onHwdecChanged() { player.applySettings(settings.hwdec, settings.alang, settings.slang) }
        function onAlangChanged() { player.applySettings(settings.hwdec, settings.alang, settings.slang) }
        function onSlangChanged() { player.applySettings(settings.hwdec, settings.alang, settings.slang) }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.controlsVisible ? Qt.ArrowCursor : Qt.BlankCursor

        onPositionChanged: root.revealControls()
        onClicked: {
            player.togglePause()
            root.revealControls()
        }
        onDoubleClicked: root.fullscreenRequested()
    }

    Rectangle {
        id: infoDock
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 22
        anchors.topMargin: 22
        width: Math.min(430, root.width - 44)
        height: 54
        radius: 27
        color: "#d9141412"
        border.width: 1
        border.color: "#35ffffff"
        opacity: root.controlsVisible ? 1 : 0
        scale: root.controlsVisible ? 1 : 0.97
        enabled: root.controlsVisible

        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

        HoverHandler {
            onHoveredChanged: if (hovered) root.revealControls()
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
            text: "←"

            contentItem: Text {
                text: closeButton.text
                color: closeButton.hovered ? "#f1cf78" : "#f2eee5"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                radius: 21
                color: closeButton.hovered ? "#20ffffff" : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
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
                width: parent.width
                text: root.media.name || player.mediaTitle || "正在播放"
                color: "#f5f2ea"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
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
        width: Math.min(780, root.width - 48)
        height: 116
        radius: 27
        color: "#e6141412"
        border.width: 1
        border.color: "#3cffffff"
        opacity: root.controlsVisible ? 1 : 0
        scale: root.controlsVisible ? 1 : 0.97
        enabled: root.controlsVisible

        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

        HoverHandler {
            onHoveredChanged: if (hovered) root.revealControls()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.revealControls()
        }

        RowLayout {
            id: timelineRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 13
            height: 28
            spacing: 10

            Text {
                Layout.preferredWidth: 44
                text: root.formatTime(player.position)
                color: "#bcb6aa"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
            }

            Slider {
                id: timeline
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                from: 0
                to: Math.max(1, player.duration)
                value: pressed ? value : player.position
                hoverEnabled: true

                onMoved: {
                    player.position = value
                    root.revealControls()
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

                    Behavior on width { NumberAnimation { duration: 100 } }
                }
            }

            Text {
                Layout.preferredWidth: 44
                text: root.formatTime(player.duration)
                color: "#8f8a80"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: timelineRow.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Row {
                id: transportControls
                anchors.centerIn: parent
                spacing: 8

                Button {
                    id: rewindButton
                    width: 42
                    height: 42
                    hoverEnabled: true
                    text: "↶10"

                    contentItem: Text {
                        text: rewindButton.text
                        color: rewindButton.hovered ? "#f0ce79" : "#ddd8ce"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 21
                        color: rewindButton.hovered ? "#18ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "后退 10 秒"
                    ToolTip.delay: 450
                    onClicked: {
                        player.seekRelative(-10)
                        root.revealControls()
                    }
                }

                Button {
                    id: playPauseButton
                    width: 48
                    height: 48
                    anchors.verticalCenter: parent.verticalCenter
                    hoverEnabled: true
                    text: player.paused ? "▶" : "Ⅱ"

                    contentItem: Text {
                        text: playPauseButton.text
                        color: "#17130b"
                        font.pixelSize: player.paused ? 16 : 17
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 24
                        color: playPauseButton.down ? "#bd9847"
                             : playPauseButton.hovered ? "#f0d183" : "#d9b45d"
                        border.width: 1
                        border.color: playPauseButton.hovered ? "#f8e1a9" : "#e7c979"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    onClicked: {
                        player.togglePause()
                        root.revealControls()
                    }
                }

                Button {
                    id: forwardButton
                    width: 42
                    height: 42
                    hoverEnabled: true
                    text: "10↷"

                    contentItem: Text {
                        text: forwardButton.text
                        color: forwardButton.hovered ? "#f0ce79" : "#ddd8ce"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 21
                        color: forwardButton.hovered ? "#18ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "前进 10 秒"
                    ToolTip.delay: 450
                    onClicked: {
                        player.seekRelative(10)
                        root.revealControls()
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Button {
                    id: audioButton
                    width: 48
                    height: 36
                    hoverEnabled: true
                    text: "音轨"

                    contentItem: Text {
                        text: audioButton.text
                        color: audioButton.hovered ? "#f0ce79" : "#aaa499"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 18
                        color: audioButton.hovered ? "#16ffffff" : "transparent"
                    }
                    onClicked: {
                        player.cycleAudio()
                        root.revealControls()
                    }
                }

                Button {
                    id: subtitleButton
                    width: 48
                    height: 36
                    hoverEnabled: true
                    text: "字幕"

                    contentItem: Text {
                        text: subtitleButton.text
                        color: subtitleButton.hovered ? "#f0ce79" : "#aaa499"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 18
                        color: subtitleButton.hovered ? "#16ffffff" : "transparent"
                    }
                    onClicked: {
                        player.cycleSubtitle()
                        root.revealControls()
                    }
                }

                Button {
                    id: fullscreenButton
                    width: 38
                    height: 38
                    hoverEnabled: true
                    text: root.fullscreen ? "↙" : "↗"

                    contentItem: Text {
                        text: fullscreenButton.text
                        color: fullscreenButton.hovered ? "#f0ce79" : "#d2ccc1"
                        font.pixelSize: 17
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 19
                        color: fullscreenButton.hovered ? "#16ffffff" : "transparent"
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: root.fullscreen ? "退出全屏" : "进入全屏"
                    ToolTip.delay: 450
                    onClicked: {
                        root.fullscreenRequested()
                        root.revealControls()
                    }
                }
            }
        }
    }

    Timer {
        id: controlsTimer
        interval: 2400
        onTriggered: if (!player.paused) root.controlsVisible = false
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
