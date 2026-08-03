pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// 服务器添加/编辑共用的模态对话框。
// serverUrl 为空 = 添加模式；非空 = 编辑模式（密码留空表示不重新认证）。
Popup {
    id: dialog
    modal: true
    focus: true
    width: 440
    padding: 0
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape

    property string dialogTitle: "添加服务器"
    property string serverUrl: ""
    property string displayName: ""
    property string userName: ""
    property string confirmText: "添加并连接"

    signal accepted(string displayName, string url, string user, string password)
    signal cancelled()

    onOpened: {
        nameField.text = dialog.displayName
        urlField.text = dialog.serverUrl
        urlField.readOnly = dialog.serverUrl.length > 0
        userField.text = dialog.userName
        passwordField.text = ""
        passwordField.forceActiveFocus()
        dialog.cancelError()
    }

    function cancelError() {
        errorText.visible = false
    }

    background: Rectangle {
        radius: 18
        color: "#17140e"
        border.width: 1
        border.color: "#3a3322"
    }

    contentItem: Column {
        width: dialog.width
        spacing: 0

        Text {
            text: dialog.dialogTitle
            color: "#f3eddd"
            font.pixelSize: 17
            font.weight: Font.Bold
            leftPadding: 24
            topPadding: 20
            bottomPadding: 14
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#262115"
        }

        Column {
            width: parent.width
            spacing: 12
            leftPadding: 24
            rightPadding: 24
            topPadding: 18

            TextField {
                id: nameField
                width: parent.width
                height: 38
                placeholderText: "显示名称（可选）"
                placeholderTextColor: "#77705f"
                color: "#f1e7d3"
                font.pixelSize: 12
                leftPadding: 12
                selectByMouse: true
                background: Rectangle {
                    radius: 10
                    color: nameField.hovered ? "#211b11" : "#1a1811"
                    border.width: 1
                    border.color: nameField.activeFocus ? "#c9a85b" : "#393326"
                }
            }

            TextField {
                id: urlField
                width: parent.width
                height: 38
                placeholderText: "服务器地址"
                placeholderTextColor: "#77705f"
                color: "#f1e7d3"
                font.pixelSize: 12
                leftPadding: 12
                selectByMouse: true
                onTextEdited: dialog.cancelError()
                background: Rectangle {
                    radius: 10
                    color: urlField.hovered ? "#211b11" : "#1a1811"
                    border.width: 1
                    border.color: urlField.activeFocus ? "#c9a85b" : "#393326"
                }
            }

            TextField {
                id: userField
                width: parent.width
                height: 38
                placeholderText: "用户名"
                placeholderTextColor: "#77705f"
                color: "#f1e7d3"
                font.pixelSize: 12
                leftPadding: 12
                selectByMouse: true
                onTextEdited: dialog.cancelError()
                background: Rectangle {
                    radius: 10
                    color: userField.hovered ? "#211b11" : "#1a1811"
                    border.width: 1
                    border.color: userField.activeFocus ? "#c9a85b" : "#393326"
                }
            }

            TextField {
                id: passwordField
                width: parent.width
                height: 38
                placeholderText: dialog.serverUrl.length > 0 ? "密码（留空表示不重新认证）" : "密码"
                placeholderTextColor: "#77705f"
                color: "#f1e7d3"
                font.pixelSize: 12
                leftPadding: 12
                echoMode: TextInput.Password
                selectByMouse: true
                onTextEdited: dialog.cancelError()
                onAccepted: confirmButton.clicked()
                background: Rectangle {
                    radius: 10
                    color: passwordField.hovered ? "#211b11" : "#1a1811"
                    border.width: 1
                    border.color: passwordField.activeFocus ? "#c9a85b" : "#393326"
                }
            }

            Text {
                id: errorText
                visible: false
                width: parent.width
                color: "#d9857b"
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }

        Item {
            width: parent.width
            height: 12
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#262115"
        }

        Row {
            width: parent.width
            spacing: 10
            rightPadding: 24
            leftPadding: 24
            topPadding: 14
            bottomPadding: 18
            layoutDirection: Qt.RightToLeft

            AccentButton {
                id: confirmButton
                width: 160
                height: 40
                text: dialog.confirmText
                enabled: urlField.text.length > 0 && userField.text.length > 0
                onClicked: dialog.accepted(nameField.text, urlField.text, userField.text, passwordField.text)
            }

            AccentButton {
                width: 110
                height: 40
                text: "取消"
                accentColor: "#4a4232"
                onClicked: {
                    dialog.cancelled()
                    dialog.close()
                }
            }
        }
    }

    // 连接失败时由外部调用 showError() 显示错误并保持窗口打开
    function showError(message) {
        errorText.text = message
        errorText.visible = true
    }
}
