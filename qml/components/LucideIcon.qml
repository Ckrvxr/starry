pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property string name: ""
    property color color: "#ffffff"
    readonly property int codepoint: {
        const codepoints = {
            "arrow-left": 57416,
            "check": 57452,
            "chevron-down": 57453,
            "chevron-left": 57454,
            "chevron-right": 57455,
            "house": 57589,
            "loader-circle": 57610,
            "maximize": 57618,
            "minimize": 57626,
            "pause": 57646,
            "play": 57660,
            "plus": 57661,
            "rotate-ccw": 57672,
            "rotate-cw": 57673,
            "server": 57683,
            "settings": 57684,
            "star": 57718,
            "trash-2": 57742,
            "pencil": 57849,
            "captions": 58276,
            "sparkles": 58386,
            "audio-lines": 58714
        };
        return codepoints[root.name] || 0;
    }

    implicitWidth: 24
    implicitHeight: 24

    FontLoader {
        id: lucideFont
        source: Qt.resolvedUrl("../fonts/lucide.ttf")
    }

    Text {
        anchors.fill: parent
        text: root.codepoint > 0 ? String.fromCodePoint(root.codepoint) : ""
        color: root.color
        font.family: lucideFont.name
        font.pixelSize: Math.max(1, Math.min(width, height))
        font.hintingPreference: Font.PreferNoHinting
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }
}
