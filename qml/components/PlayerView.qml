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

    function start(item) {
        media = item
        visible = true
        forceActiveFocus()
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
        closeRequested()
    }

    visible: false
    focus: visible
    Keys.onSpacePressed: player.togglePause()
    Keys.onLeftPressed: player.seekRelative(-10)
    Keys.onRightPressed: player.seekRelative(10)
    Keys.onEscapePressed: root.fullscreen ? root.fullscreenRequested() : root.stopPlayback()

    Rectangle { anchors.fill: parent; color: "black" }

    MpvPlayer {
        id: player
        anchors.fill: parent
        onPlaybackEnded: root.stopPlayback()
        onMpvError: function(message) {
            errorText.text = message
            errorToast.open()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPositionChanged: {
            root.controlsVisible = true
            controlsTimer.restart()
        }
        onClicked: player.togglePause()
        onDoubleClicked: root.fullscreenRequested()
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 112
        opacity: root.controlsVisible ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0; color: "#c9000000" }
            GradientStop { position: 1; color: "#00000000" }
        }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            ToolButton {
                text: "←"
                font.pixelSize: 24
                onClicked: root.stopPlayback()
                contentItem: Text { text: parent.text; color: "white"; font: parent.font; horizontalAlignment: Text.AlignHCenter }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: root.media.name || player.mediaTitle; color: "white"; font.pixelSize: 17; font.weight: Font.DemiBold }
                Text { text: root.media.seriesName || root.media.subtitle || ""; color: "#b3ac99"; font.pixelSize: 12 }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 148
        opacity: root.controlsVisible ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 1; color: "#e6000000" }
        }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            spacing: 7

            Slider {
                id: timeline
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, player.duration)
                value: pressed ? value : player.position
                onMoved: player.position = value
                background: Rectangle {
                    x: timeline.leftPadding
                    y: timeline.topPadding + timeline.availableHeight / 2 - height / 2
                    width: timeline.availableWidth
                    height: 4
                    radius: 2
                    color: "#5a5342"
                    Rectangle { width: timeline.visualPosition * parent.width; height: parent.height; radius: 2; color: "#d8b45e" }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ToolButton {
                    text: player.paused ? "▶" : "Ⅱ"
                    font.pixelSize: 19
                    onClicked: player.togglePause()
                    contentItem: Text { text: parent.text; color: "white"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                ToolButton { text: "↶ 10"; onClicked: player.seekRelative(-10); contentItem: Text { text: parent.text; color: "white"; font: parent.font } }
                ToolButton { text: "10 ↷"; onClicked: player.seekRelative(10); contentItem: Text { text: parent.text; color: "white"; font: parent.font } }
                Text { text: formatTime(player.position) + " / " + formatTime(player.duration); color: "#d6d6dc"; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                ToolButton { text: "音轨"; onClicked: player.cycleAudio(); contentItem: Text { text: parent.text; color: "white"; font: parent.font } }
                ToolButton { text: "字幕"; onClicked: player.cycleSubtitle(); contentItem: Text { text: parent.text; color: "white"; font: parent.font } }
                Text { text: "♩"; color: "white"; font.pixelSize: 16 }
                Slider {
                    Layout.preferredWidth: 88
                    from: 0; to: 100; value: player.volume
                    onMoved: player.volume = value
                }
                ToolButton {
                    text: root.fullscreen ? "↙" : "↗"
                    font.pixelSize: 20
                    onClicked: root.fullscreenRequested()
                    contentItem: Text { text: parent.text; color: "white"; font: parent.font }
                }
            }
        }
    }

    Timer {
        id: controlsTimer
        interval: 2600
        onTriggered: if (!player.paused) root.controlsVisible = false
    }
    Timer {
        interval: 10000
        repeat: true
        running: root.visible && player.playing
        onTriggered: if (root.media.id) emby.reportPlaybackProgress(root.media.id, player.position, player.paused)
    }

    Popup {
        id: errorToast
        anchors.centerIn: parent
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#e6332639"; radius: 12; border.color: "#b85b6c" }
        contentItem: Text { id: errorText; color: "white"; wrapMode: Text.Wrap; width: 360; padding: 14 }
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0) return "00:00"
        const total = Math.floor(seconds)
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = total % 60
        return (h > 0 ? String(h).padStart(2, "0") + ":" : "")
             + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }
}
