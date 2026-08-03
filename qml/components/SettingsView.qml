pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Item {
    id: root

    signal switchRequested(string url)

    // 添加服务器对话框
    ServerDialog {
        id: addDialog
        onAccepted: function(displayName, url, user, password) {
            emby.login(url, user, password, displayName)
        }
    }

    // 编辑服务器对话框（地址只读，改凭据则重新认证，否则仅改显示名称）
    ServerDialog {
        id: editDialog
        onAccepted: function(displayName, url, user, password) {
            if (url !== editDialog.serverUrl || user !== editDialog.userName || password.length > 0)
                emby.login(url, user, password, displayName)
            else
                emby.renameServer(editDialog.serverUrl, displayName)
        }
    }

    Connections {
        target: emby
        function onErrorChanged() {
            if (emby.error.length > 0 && addDialog.opened)
                addDialog.showError(emby.error)
            else if (emby.error.length > 0 && editDialog.opened)
                editDialog.showError(emby.error)
        }
        function onLoginSucceeded() {
            addDialog.close()
            editDialog.close()
        }
    }

    function hostOf(value) {
        return String(value || "").replace(/^https?:\/\//, "").replace(/\/.*$/, "")
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
        ScrollBar.vertical: ScrollBar { }

        Column {
            id: column
            x: 34; y: 24
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

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✦"
                                        color: emby.serverUrl === modelData.url ? "#edc86d" : "#8f7c58"
                                        font.pixelSize: 12
                                    }
                                }

                                Text {
                                    width: parent.width - 24 - 10 - 260
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        const display = modelData.displayName
                                        const name = display && display.length > 0
                                                  ? display : root.hostOf(modelData.url)
                                        return name + " · " + modelData.userName + " · " + modelData.url
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
                                    accentColor: "#4a4232"
                                    onClicked: {
                                        editDialog.dialogTitle = "编辑服务器"
                                        editDialog.confirmText = "保存"
                                        editDialog.serverUrl = modelData.url
                                        editDialog.displayName = modelData.displayName
                                        editDialog.userName = modelData.userName
                                        editDialog.open()
                                    }
                                }

                                AccentButton {
                                    width: 62
                                    height: 30
                                    text: "删除"
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
                        text: "＋ 添加服务器"
                        onClicked: {
                            addDialog.dialogTitle = "添加服务器"
                            addDialog.confirmText = "添加并连接"
                            addDialog.serverUrl = ""
                            addDialog.displayName = ""
                            addDialog.userName = ""
                            addDialog.open()
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

            // ── mpv设置 ────────────────────────────────
            SectionCard {
                height: 236

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    SectionHeader {
                        sectionTitle: "mpv设置"
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#262115"
                    }

                    Row {
                        width: parent.width
                        spacing: 12

                        Text {
                            text: "硬解模式"
                            color: "#c9bda2"
                            font.pixelSize: 12
                            width: 100
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ComboBox {
                            id: hwdecBox
                            width: 220
                            implicitHeight: 36
                            model: ["auto-safe", "auto", "no"]
                            currentIndex: {
                                const idx = model.indexOf(settings.hwdec)
                                return idx >= 0 ? idx : 0
                            }

                            onActivated: settings.setHwdec(currentText)

                            contentItem: Text {
                                text: hwdecBox.displayText
                                color: "#f1e7d3"
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12
                            }

                            background: Rectangle {
                                radius: 10
                                color: hwdecBox.hovered ? "#211b11" : "#1a1811"
                                border.width: 1
                                border.color: hwdecBox.activeFocus ? "#c9a85b" : "#393326"
                            }

                            indicator: Text {
                                text: "▾"
                                color: "#8d7d5d"
                                font.pixelSize: 11
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            popup: Popup {
                                y: hwdecBox.height + 4
                                width: hwdecBox.width
                                padding: 4
                                background: Rectangle {
                                    radius: 10
                                    color: "#1d1910"
                                    border.width: 1
                                    border.color: "#3a3322"
                                }
                                contentItem: ListView {
                                    implicitHeight: contentHeight
                                    clip: true
                                    model: hwdecBox.popup.visualModel
                                    delegate: ItemDelegate {
                                        width: parent.width
                                        height: 36
                                        contentItem: Text {
                                            text: model.text
                                            color: hwdecBox.currentIndex === index ? "#f2e5bd" : "#c9bda2"
                                            font.pixelSize: 12
                                            leftPadding: 12
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            radius: 8
                                            color: parent.hovered ? "#272014" : "transparent"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 12

                        Text {
                            text: "音轨语言"
                            color: "#c9bda2"
                            font.pixelSize: 12
                            width: 100
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TextField {
                            id: alangField
                            width: 220
                            height: 36
                            text: settings.alang
                            color: "#f1e7d3"
                            font.pixelSize: 12
                            leftPadding: 12
                            selectByMouse: true
                            onEditingFinished: settings.setAlang(text)
                            background: Rectangle {
                                radius: 10
                                color: alangField.hovered ? "#211b11" : "#1a1811"
                                border.width: 1
                                border.color: alangField.activeFocus ? "#c9a85b" : "#393326"
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 12

                        Text {
                            text: "字幕语言"
                            color: "#c9bda2"
                            font.pixelSize: 12
                            width: 100
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TextField {
                            id: slangField
                            width: 220
                            height: 36
                            text: settings.slang
                            color: "#f1e7d3"
                            font.pixelSize: 12
                            leftPadding: 12
                            selectByMouse: true
                            onEditingFinished: settings.setSlang(text)
                            background: Rectangle {
                                radius: 10
                                color: slangField.hovered ? "#211b11" : "#1a1811"
                                border.width: 1
                                border.color: slangField.activeFocus ? "#c9a85b" : "#393326"
                            }
                        }
                    }

                    Text {
                        text: "硬解切换与语言偏好对之后播放的媒体生效"
                        color: "#776846"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
