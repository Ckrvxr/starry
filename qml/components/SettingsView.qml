pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Item {
    id: root

    signal switchRequested(string url)

    // 添加服务器对话框
    ServerDialog {
        id: addDialog
        onAccepted: function (displayName, url, user, password) {
            emby.login(url, user, password, displayName);
        }
    }

    // 编辑服务器对话框（地址只读，改凭据则重新认证，否则仅改显示名称）
    ServerDialog {
        id: editDialog
        onAccepted: function (displayName, url, user, password) {
            if (url !== editDialog.serverUrl || user !== editDialog.userName || password.length > 0)
                emby.login(url, user, password, displayName);
            else
                emby.renameServer(editDialog.serverUrl, displayName);
        }
    }

    Connections {
        target: emby
        function onErrorChanged() {
            if (emby.error.length > 0 && addDialog.opened)
                addDialog.showError(emby.error);
            else if (emby.error.length > 0 && editDialog.opened)
                editDialog.showError(emby.error);
        }
        function onLoginSucceeded() {
            addDialog.close();
            editDialog.close();
        }
    }

    function hostOf(value) {
        return String(value || "").replace(/^https?:\/\//, "").replace(/\/.*$/, "");
    }

    // 栏目卡片通用样式
    component SectionCard: Rectangle {
        width: parent.width
        radius: 16
        color: "#14120c"
        border.width: 1
        border.color: "#2b2517"
    }

    component SectionHeader: Row {
        property string sectionTitle

        width: parent.width
        spacing: 8

        Rectangle {
            width: 4
            height: 12
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: "#c9a85b"
        }

        Text {
            text: sectionTitle
            color: "#e8dcc0"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: column
            x: 34
            y: 24
            width: parent.width - 68
            spacing: 26

            Text {
                text: "设置"
                color: "#f3eddd"
                font.pixelSize: 25
                font.weight: Font.Bold
            }

            // ── 服务器管理 ──────────────────────────────
            SectionCard {
                height: serverColumn.implicitHeight + 40

                Column {
                    id: serverColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 12

                    SectionHeader {
                        sectionTitle: "服务器管理"
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#262115"
                    }

                    // 已保存的服务器列表
                    Repeater {
                        model: emby.servers

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 46
                            radius: 12
                            color: "#1a1811"
                            border.width: 1
                            border.color: emby.serverUrl === modelData.url ? "#c9a85b" : "#2b2517"

                            Row {
                                width: parent.width
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#2b2314"

                                    LucideIcon {
                                        anchors.centerIn: parent
                                        width: 13
                                        height: 13
                                        name: "server"
                                        color: emby.serverUrl === modelData.url ? "#edc86d" : "#8f7c58"
                                    }
                                }

                                Text {
                                    width: parent.width - 24 - 10 - 260
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        const display = modelData.displayName;
                                        const name = display && display.length > 0 ? display : root.hostOf(modelData.url);
                                        return name + " · " + modelData.userName + " · " + modelData.url;
                                    }
                                    color: "#f1e7d3"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                AccentButton {
                                    visible: emby.serverUrl !== modelData.url
                                    width: 68
                                    height: 30
                                    text: "切换"
                                    onClicked: root.switchRequested(modelData.url)
                                }

                                Text {
                                    visible: emby.serverUrl === modelData.url
                                    text: "当前"
                                    color: "#c9a85b"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                AccentButton {
                                    width: 62
                                    height: 30
                                    text: "编辑"
                                    iconName: "pencil"
                                    accentColor: "#4a4232"
                                    onClicked: {
                                        editDialog.dialogTitle = "编辑服务器";
                                        editDialog.confirmText = "保存";
                                        editDialog.serverUrl = modelData.url;
                                        editDialog.displayName = modelData.displayName;
                                        editDialog.userName = modelData.userName;
                                        editDialog.open();
                                    }
                                }

                                AccentButton {
                                    width: 62
                                    height: 30
                                    text: "删除"
                                    iconName: "trash-2"
                                    accentColor: "#8a4b3f"
                                    onClicked: emby.removeServer(modelData.url)
                                }
                            }
                        }
                    }

                    Text {
                        visible: emby.servers.length === 0
                        width: parent.width
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        text: "暂无已保存的服务器"
                        color: "#776846"
                        font.pixelSize: 11
                    }

                    AccentButton {
                        width: 160
                        height: 38
                        text: "添加服务器"
                        iconName: "plus"
                        onClicked: {
                            addDialog.dialogTitle = "添加服务器";
                            addDialog.confirmText = "添加并连接";
                            addDialog.serverUrl = "";
                            addDialog.displayName = "";
                            addDialog.userName = "";
                            addDialog.open();
                        }
                    }

                    Text {
                        visible: emby.error.length > 0
                        width: parent.width
                        text: emby.error
                        color: "#d9857b"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
            }

            // ── MPV 设置 ───────────────────────────────
            SectionCard {
                height: 650

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    SectionHeader {
                        sectionTitle: "MPV 设置"
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#262115"
                    }

                    Text {
                        width: parent.width
                        text: "按 mpv.conf 格式逐行编辑。前向缓存与后向缓存分别由 demuxer-max-bytes 和 demuxer-max-back-bytes 控制。"
                        color: "#9b8d70"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        id: configEditorFrame
                        width: parent.width
                        height: 450
                        radius: 12
                        color: "#0d0d0a"
                        border.width: 1
                        border.color: configEditor.activeFocus ? "#8f7440" : "#393326"
                        clip: true

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 2
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            TextArea {
                                id: configEditor
                                text: settings.mpvConfig
                                color: "#e8dcc0"
                                selectionColor: "#765c29"
                                selectedTextColor: "#fff7e3"
                                font.family: Qt.platform.os === "osx" ? "Menlo" : "monospace"
                                font.pixelSize: 12
                                wrapMode: TextEdit.NoWrap
                                selectByMouse: true
                                leftPadding: 12
                                rightPadding: 12
                                topPadding: 10
                                bottomPadding: 10
                                background: null
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        AccentButton {
                            width: 116
                            height: 36
                            text: "保存配置"
                            iconName: "check"
                            onClicked: {
                                settings.mpvConfig = configEditor.text;
                                saveStatus.text = "已保存，将应用于当前及之后播放的媒体";
                                saveStatus.opacity = 1;
                                saveStatusTimer.restart();
                            }
                        }

                        AccentButton {
                            width: 116
                            height: 36
                            text: "恢复默认"
                            iconName: "rotate-ccw"
                            accentColor: "#4a4232"
                            onClicked: {
                                configEditor.text = settings.defaultMpvConfig;
                                settings.mpvConfig = configEditor.text;
                                saveStatus.text = "已恢复默认配置";
                                saveStatus.opacity = 1;
                                saveStatusTimer.restart();
                            }
                        }

                        Text {
                            id: saveStatus
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#8fbf86"
                            font.pixelSize: 11
                            opacity: 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                }
                            }
                        }

                        Timer {
                            id: saveStatusTimer
                            interval: 2600
                            onTriggered: saveStatus.opacity = 0
                        }
                    }

                    Text {
                        width: parent.width
                        text: "注意：Qt 内嵌播放器必须保持 vo=libmpv，编辑器中的 vo 项会保留但不会应用；部分渲染初始化项需重启应用后生效。"
                        color: "#776846"
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
