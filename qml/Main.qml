import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: window
    width: 1360
    height: 820
    minimumWidth: 980
    minimumHeight: 640
    visible: true
    title: "Starry"
    color: "#0b0b09"
    flags: Qt.Window | Qt.FramelessWindowHint

    property int selectedNav: 0
    property bool isFullscreen: visibility === Window.FullScreen

    Rectangle {
        id: windowSurface
        z: -100
        anchors.fill: parent
        radius: 18
        color: "#0b0b09"
        antialiasing: true
    }

    StackLayout {
        anchors.fill: parent
        // macOS 原生窗口已提供透明标题栏区域，内容从窗口顶端铺满，避免出现第二条空标题栏。
        anchors.topMargin: Qt.platform.os === "osx" ? 0 : titleBar.height
        currentIndex: emby.connected ? 1 : 0

        Item {
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#0b0b09" }
                    GradientStop { position: 0.6; color: "#18150e" }
                    GradientStop { position: 1; color: "#2a2110" }
                }
            }
            Rectangle {
                width: 440; height: 440; radius: 220
                x: parent.width * 0.68; y: -170
                color: "#c49b3d"; opacity: 0.14
            }
            Column {
                anchors.centerIn: parent
                width: 390
                spacing: 18
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Text { text: "✦"; color: "#e0bd63"; font.pixelSize: 38 }
                    Text { text: "Starry"; color: "white"; font.pixelSize: 38; font.weight: Font.Bold }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "连接你的 Emby 服务器"
                    color: "#a39b88"; font.pixelSize: 14
                }
                Item { width: 1; height: 8 }
                TextField {
                    id: serverField
                    width: parent.width; height: 50
                    placeholderText: "服务器地址，例如 192.168.1.10:8096"
                    color: "#f4efdf"; placeholderTextColor: "#77705f"
                    leftPadding: 16
                    background: Rectangle { color: "#1b1912"; radius: 12; border.color: serverField.activeFocus ? "#c9a85b" : "#393326" }
                }
                TextField {
                    id: usernameField
                    width: parent.width; height: 50
                    placeholderText: "用户名"
                    color: "#f4efdf"; placeholderTextColor: "#77705f"; leftPadding: 16
                    background: Rectangle { color: "#1b1912"; radius: 12; border.color: usernameField.activeFocus ? "#c9a85b" : "#393326" }
                }
                TextField {
                    id: passwordField
                    width: parent.width; height: 50
                    placeholderText: "密码"
                    echoMode: TextInput.Password
                    color: "#f4efdf"; placeholderTextColor: "#77705f"; leftPadding: 16
                    onAccepted: loginButton.clicked()
                    background: Rectangle { color: "#1b1912"; radius: 12; border.color: passwordField.activeFocus ? "#c9a85b" : "#393326" }
                }
                Text {
                    width: parent.width
                    visible: emby.error.length > 0
                    text: emby.error
                    color: "#ff8c9a"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
                AccentButton {
                    id: loginButton
                    width: parent.width
                    text: emby.busy ? "正在连接…" : "进入 Starry"
                    enabled: !emby.busy && serverField.text.length > 0 && usernameField.text.length > 0
                    onClicked: emby.login(serverField.text, usernameField.text, passwordField.text)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "凭据仅保存在这台设备上"
                    color: "#807963"; font.pixelSize: 11
                }
            }
        }

        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.preferredWidth: 216
                    Layout.fillHeight: true
                    color: "#12120f"
                    border.color: "#29261b"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 8
                        Row {
                            height: 64; spacing: 9
                            Text { text: "✦"; color: "#d8b45e"; font.pixelSize: 28; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Starry"; color: "white"; font.pixelSize: 22; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        }
                        SidebarButton {
                            text: "首页"; glyph: "⌂"; selected: window.selectedNav === 0
                            onClicked: { window.selectedNav = 0; emby.loadItems() }
                        }
                        SidebarButton {
                            text: "电影"; glyph: "▶"; selected: window.selectedNav === 1
                            onClicked: { window.selectedNav = 1; emby.loadItems("", "Movie") }
                        }
                        SidebarButton {
                            text: "剧集"; glyph: "▣"; selected: window.selectedNav === 2
                            onClicked: { window.selectedNav = 2; emby.loadItems("", "Series") }
                        }
                        Text { text: "媒体库"; color: "#827962"; font.pixelSize: 11; topPadding: 20; leftPadding: 14 }
                        Repeater {
                            model: emby.libraries
                            delegate: SidebarButton {
                                required property var modelData
                                required property int index
                                text: modelData.name
                                glyph: "◇"
                                onClicked: { window.selectedNav = 10 + index; emby.loadItems(modelData.id) }
                            }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 20
                        spacing: 3
                        Text { text: emby.userName; color: "#eee6d2"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Button {
                            text: "退出登录"
                            flat: true
                            leftPadding: 0
                            contentItem: Text { text: parent.text; color: "#817962"; font.pixelSize: 11 }
                            onClicked: emby.logout()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        id: contentFlick
                        anchors.fill: parent
                        contentHeight: contentColumn.height + 60
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }

                        Column {
                            id: contentColumn
                            x: 34; y: 24
                            width: contentFlick.width - 68
                            spacing: 26

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: window.selectedNav === 0 ? "晚上好，" + emby.userName
                                         : window.selectedNav === 1 ? "电影"
                                         : window.selectedNav === 2 ? "剧集" : "媒体库"
                                    color: "#f3eddd"; font.pixelSize: 25; font.weight: Font.Bold
                                    Layout.fillWidth: true
                                }
                                TextField {
                                    id: searchField
                                    Layout.preferredWidth: 280; Layout.preferredHeight: 42
                                    placeholderText: "搜索电影、剧集…"
                                    color: "#f4efdf"; placeholderTextColor: "#77705f"; leftPadding: 16
                                    background: Rectangle { color: "#1a1811"; radius: 21; border.color: searchField.activeFocus ? "#c9a85b" : "#393326" }
                                    Timer {
                                        interval: 350; running: searchField.text.length > 0; onTriggered: emby.search(searchField.text)
                                    }
                                    onTextEdited: if (text.length === 0) emby.loadItems()
                                    onAccepted: emby.search(text)
                                }
                                BusyIndicator { running: emby.busy; visible: running; implicitWidth: 28; implicitHeight: 28 }
                            }

                            Rectangle {
                                visible: window.selectedNav === 0 && emby.items.length > 0
                                width: parent.width; height: 290; radius: 20; clip: true
                                color: "#211d14"
                                property var hero: emby.items.length > 0 ? emby.items[0] : ({})
                                Image { anchors.fill: parent; source: parent.hero.backdrop || parent.hero.image || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                Rectangle {
                                    anchors.fill: parent
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: "#ed171611" }
                                        GradientStop { position: 0.65; color: "#7a171611" }
                                        GradientStop { position: 1; color: "#1116110d" }
                                    }
                                }
                                Column {
                                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 30
                                    width: Math.min(570, parent.width * 0.6); spacing: 10
                                    Text { text: parent.parent.hero.name || ""; color: "white"; font.pixelSize: 30; font.weight: Font.Bold }
                                    Text { width: parent.width; text: parent.parent.hero.overview || ""; color: "#c6bda6"; font.pixelSize: 13; maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.Wrap }
                                    AccentButton { text: "▶  立即播放"; onClicked: playerLayer.start(parent.parent.hero) }
                                }
                            }

                            RowLayout {
                                width: parent.width
                                Text { text: searchField.text.length > 0 ? "搜索结果" : "最近添加"; color: "#eee7d6"; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.fillWidth: true }
                                Text { text: emby.items.length + " 项"; color: "#827962"; font.pixelSize: 12 }
                            }

                            GridView {
                                id: mediaGrid
                                width: parent.width
                                height: Math.ceil(emby.items.length / Math.max(1, Math.floor(width / 194))) * 316
                                interactive: false
                                cellWidth: 194
                                cellHeight: 316
                                model: emby.items
                                delegate: MediaCard {
                                    required property var modelData
                                    width: 174; height: 292
                                    media: modelData
                                    onClicked: { emby.loadItem(modelData.id); detailPopup.open() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: detailPopup
        anchors.centerIn: Overlay.overlay
        width: Math.min(880, window.width - 80)
        height: Math.min(610, window.height - 80)
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: "#b0000000" }
        background: Rectangle { color: "#1c1912"; radius: 20; border.color: "#4a4028" }
        contentItem: Item {
            clip: true
            Image { anchors.fill: parent; source: emby.currentItem.backdrop || ""; fillMode: Image.PreserveAspectCrop; opacity: 0.38 }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#3a2a2414" }
                    GradientStop { position: 0.58; color: "#e812100b" }
                    GradientStop { position: 1; color: "#ff0b0a08" }
                }
            }
            Button {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
                text: "×"; flat: true; font.pixelSize: 24
                contentItem: Text { text: parent.text; color: "white"; font: parent.font; horizontalAlignment: Text.AlignHCenter }
                onClicked: detailPopup.close()
            }
            Column {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 34
                spacing: 14
                Text { text: emby.currentItem.name || "加载中…"; color: "white"; font.pixelSize: 32; font.weight: Font.Bold }
                Row { spacing: 14
                    Text { text: emby.currentItem.subtitle || emby.currentItem.type || ""; color: "#b8ad92"; font.pixelSize: 13 }
                    Text { visible: (emby.currentItem.communityRating || 0) > 0; text: "★ " + Number(emby.currentItem.communityRating || 0).toFixed(1); color: "#f0ca6d"; font.pixelSize: 13 }
                }
                Text { width: Math.min(700, parent.width); text: emby.currentItem.overview || "暂无简介"; color: "#b7b5c0"; font.pixelSize: 14; lineHeight: 1.35; wrapMode: Text.Wrap; maximumLineCount: 5; elide: Text.ElideRight }
                Row { spacing: 12
                    AccentButton {
                        visible: emby.currentItem.type !== "Series"
                        text: (emby.currentItem.position || 0) > 0 ? "▶  继续播放" : "▶  立即播放"
                        onClicked: { const item = emby.currentItem; detailPopup.close(); playerLayer.start(item) }
                    }
                    AccentButton {
                        visible: emby.currentItem.type === "Series"
                        text: "查看剧集"
                        onClicked: {
                            const id = emby.currentItem.id
                            detailPopup.close()
                            window.selectedNav = 2
                            emby.loadItems(id, "Episode")
                        }
                    }
                    Button {
                        text: "关闭"; implicitHeight: 44; implicitWidth: 90
                        contentItem: Text { text: parent.text; color: "#dedde6"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 12; color: parent.hovered ? "#3c3949" : "#302e3b" }
                        onClicked: detailPopup.close()
                    }
                }
            }
        }
    }

    PlayerView {
        id: playerLayer
        anchors.fill: parent
        z: 100
        fullscreen: window.isFullscreen
        onFullscreenRequested: window.isFullscreen ? window.showNormal() : window.showFullScreen()
        onCloseRequested: if (window.isFullscreen) window.showNormal()
    }

    // 自绘标题栏：无边框窗口下保留原生窗口的拖动和系统操作能力。
    Rectangle {
        id: titleBar
        z: 1000
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 34
        visible: !playerLayer.visible && Qt.platform.os !== "osx"
        color: "transparent"
        border.width: 0

        MouseArea {
            id: titleDragArea
            anchors.left: windowButtons.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            acceptedButtons: Qt.LeftButton
            onPressed: window.startSystemMove()
            onDoubleClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
        }

        Row {
            id: windowButtons
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            height: 14
            spacing: 8

            Button {
                width: 14; height: 14
                hoverEnabled: true
                onClicked: Qt.quit()
                background: Rectangle {
                    radius: width / 2
                    color: parent.hovered ? "#ff756e" : "#ff5f57"
                    border.color: "#d84840"
                    border.width: 0.5
                }
            }

            Button {
                width: 14; height: 14
                hoverEnabled: true
                onClicked: window.showMinimized()
                background: Rectangle {
                    radius: width / 2
                    color: parent.hovered ? "#ffd35b" : "#febc2e"
                    border.color: "#d49a20"
                    border.width: 0.5
                }
            }

            Button {
                width: 14; height: 14
                hoverEnabled: true
                onClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
                background: Rectangle {
                    radius: width / 2
                    color: parent.hovered ? "#44d85d" : "#28c840"
                    border.color: "#1e9e31"
                    border.width: 0.5
                }
            }
        }
    }

    Connections {
        target: emby
        function onLoginSucceeded() { searchField.clear() }
    }
}
