pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string serverName: "Emby Server"
    property string serverAddress: "已连接"
    property string logoUrl: ""
    property var libraries: []
    property int selectedLibrary: -1
    property bool active: false
    property bool expanded: true

    signal libraryClicked(int index, string libraryId, string libraryName)
    signal activateRequested()

    implicitWidth: 204
    implicitHeight: serverHeader.height + libraryViewport.height + 8

    Rectangle {
        id: serverHeader
        width: parent.width
        height: 66
        radius: 16
        color: serverMouse.containsMouse ? "#211b11"
              : root.active ? "#1b1710" : "#17140e"
        border.width: root.active ? 1 : 0
        border.color: "#3a3322"

        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width: 32
            height: 32
            radius: 10
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "#2b2314"
            border.width: 0
            clip: true

            Image {
                id: serverLogo
                anchors.fill: parent
                anchors.margins: 6
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                source: root.logoUrl.length
                        ? "image://cached/" + encodeURIComponent(root.logoUrl + "/emby/Web/Logo.png")
                        : ""

                onStatusChanged: {
                    if (status === Image.Error)
                        source = root.logoUrl + "/web/Logo.png"
                }
            }

            Text {
                anchors.centerIn: parent
                text: "✦"
                color: "#f0cf83"
                font.pixelSize: 15
                visible: serverLogo.status !== Image.Ready
            }

            Rectangle {
                width: 7
                height: 7
                radius: 4
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -1
                anchors.bottomMargin: -1
                color: "#78d6ad"
                border.width: 2
                border.color: "#17140e"
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 54
            anchors.right: chevron.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: root.serverName
                color: "#f1e7d3"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.serverAddress
                color: "#8d7d5d"
                font.pixelSize: 9
                font.letterSpacing: 0.5
                elide: Text.ElideMiddle
            }
        }

        Text {
            id: chevron
            width: 20
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: serverMouse.containsMouse ? "#e6ca82"
                  : root.active ? "#c9a85b" : "#95815a"
            font.pixelSize: 21
            horizontalAlignment: Text.AlignHCenter
            rotation: root.expanded ? 90 : 0

            Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: serverMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: root.serverName + (root.expanded ? "，已展开" : "，已折叠")
            onClicked: {
                if (!root.active)
                    root.activateRequested()
                else
                    root.expanded = !root.expanded
            }
        }
    }

    Item {
        id: libraryViewport
        anchors.top: serverHeader.bottom
        anchors.topMargin: 5
        width: parent.width
        height: root.expanded ? libraryColumn.implicitHeight + 4 : 0
        clip: true

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            visible: libraryColumn.implicitHeight > 0
            x: 27
            y: 0
            width: 1
            height: Math.max(0, libraryColumn.implicitHeight - 13)
            color: "#493b23"
        }

        Column {
            id: libraryColumn
            width: parent.width
            spacing: 2

            Repeater {
                model: root.libraries

                delegate: Button {
                    id: libraryButton
                    required property var modelData
                    required property int index

                    width: libraryColumn.width
                    height: 38
                    text: modelData.name
                    leftPadding: 44
                    rightPadding: 10
                    hoverEnabled: true

                    contentItem: Text {
                        text: libraryButton.text
                        color: root.selectedLibrary === libraryButton.index ? "#f2e5bd"
                              : libraryButton.hovered ? "#ddd1ba" : "#9f9279"
                        font.pixelSize: 12
                        font.weight: root.selectedLibrary === libraryButton.index ? Font.DemiBold : Font.Normal
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    background: Rectangle {
                        radius: 10
                        color: root.selectedLibrary === libraryButton.index ? "#2b2315"
                              : libraryButton.hovered ? "#18150f" : "transparent"

                        Rectangle {
                            width: 7
                            height: 7
                            radius: 4
                            x: 24
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.selectedLibrary === libraryButton.index ? "#e5bd69" : "#5d4e32"
                            border.width: root.selectedLibrary === libraryButton.index ? 2 : 0
                            border.color: "#66562f"
                        }
                    }

                    onClicked: root.libraryClicked(index, String(modelData.id), String(modelData.name))
                }
            }

            Text {
                visible: !root.libraries || root.libraries.length === 0
                width: parent.width
                height: visible ? 34 : 0
                leftPadding: 44
                text: "正在同步星图…"
                color: "#766848"
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
