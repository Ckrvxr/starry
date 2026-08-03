pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Popup {
    id: root

    property string heading: "选择轨道"
    property var tracks: []
    property bool allowOff: false
    property string emptyText: "没有可用轨道"
    readonly property bool hasSelectedTrack: {
        for (let index = 0; index < tracks.length; ++index) {
            if (tracks[index].selected)
                return true;
        }
        return false;
    }
    readonly property var options: {
        const result = [];
        if (allowOff)
            result.push({
                "id": -1,
                "title": "关闭字幕",
                "selected": !hasSelectedTrack,
                "off": true
            });
        for (let index = 0; index < tracks.length; ++index)
            result.push(tracks[index]);
        return result;
    }

    signal trackSelected(int trackId)

    function trackLabel(track, index) {
        if (track.off)
            return track.title;
        const values = [];
        if (track.title)
            values.push(String(track.title));
        if (track.language && values.indexOf(String(track.language)) < 0)
            values.push(String(track.language).toUpperCase());
        if (track.codec)
            values.push(String(track.codec).toUpperCase());
        return values.length > 0 ? values.join(" · ") : "轨道 " + (index + 1);
    }

    width: 268
    height: Math.min(292, 50 + Math.max(48, options.length * 44) + 8)
    padding: 0
    modal: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 130
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.96
                to: 1
                duration: 150
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
                duration: 100
            }
            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.98
                duration: 100
            }
        }
    }

    background: Rectangle {
        radius: 16
        color: "#f2171612"
        border.width: 1
        border.color: "#62563c"
    }

    contentItem: Column {
        width: root.width

        Text {
            width: parent.width
            height: 50
            leftPadding: 16
            text: root.heading
            color: "#eee9de"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
        }

        ListView {
            width: parent.width
            height: root.height - 58
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.options

            delegate: ItemDelegate {
                id: trackItem
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 44
                hoverEnabled: true

                contentItem: Item {
                    LucideIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15
                        height: 15
                        name: "check"
                        color: "#e0bd67"
                        visible: Boolean(trackItem.modelData.selected)
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 42
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.trackLabel(trackItem.modelData, trackItem.index)
                        color: trackItem.modelData.selected ? "#f0d58d" : trackItem.hovered ? "#f2eee5" : "#b2aa9b"
                        font.pixelSize: 11
                        font.weight: trackItem.modelData.selected ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                }

                background: Rectangle {
                    color: trackItem.hovered ? "#18ffffff" : "transparent"
                }

                onClicked: root.trackSelected(Number(modelData.id))
            }

            Text {
                anchors.centerIn: parent
                visible: root.options.length === 0
                text: root.emptyText
                color: "#817969"
                font.pixelSize: 11
            }
        }
    }
}
