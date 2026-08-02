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
    property string selectedLibraryName: ""
    property int homeHeroIndex: 0
    readonly property int homeHeroCount: Math.min(5, emby.items.length)
    readonly property var homeHero: homeHeroCount > 0
        ? emby.items[Math.min(homeHeroIndex, homeHeroCount - 1)] : ({})
    property bool isFullscreen: visibility === Window.FullScreen

    function serverNameFromUrl(value) {
        const host = String(value || "")
            .replace(/^https?:\/\//, "")
            .replace(/\/.*$/, "")
        return host.length > 0 ? host : "Emby Server"
    }

    function stepHomeHero(step) {
        if (homeHeroCount < 1)
            return
        homeHeroIndex = (homeHeroIndex + step + homeHeroCount) % homeHeroCount
    }

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
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#070706" }
                    GradientStop { position: 0.48; color: "#0d0c09" }
                    GradientStop { position: 1; color: "#171207" }
                }
            }

            Rectangle {
                width: 520
                height: 520
                radius: 260
                x: parent.width - 320
                y: -310
                color: "#c89732"
                opacity: 0.045
            }

            Rectangle {
                width: 380
                height: 380
                radius: 190
                x: parent.width * 0.35
                y: parent.height - 170
                color: "#8a6622"
                opacity: 0.025
            }

            Repeater {
                model: [
                    { "x": 0.24, "y": 0.09, "s": 2, "o": 0.24 },
                    { "x": 0.49, "y": 0.16, "s": 1, "o": 0.32 },
                    { "x": 0.73, "y": 0.08, "s": 2, "o": 0.2 },
                    { "x": 0.91, "y": 0.31, "s": 1, "o": 0.26 },
                    { "x": 0.64, "y": 0.7, "s": 2, "o": 0.18 },
                    { "x": 0.38, "y": 0.86, "s": 1, "o": 0.28 },
                    { "x": 0.84, "y": 0.91, "s": 2, "o": 0.2 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    x: parent.width * modelData.x
                    y: parent.height * modelData.y
                    width: modelData.s
                    height: modelData.s
                    radius: width / 2
                    color: "#e0bd67"
                    opacity: modelData.o
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    id: sidebarPanel
                    Layout.preferredWidth: 248
                    Layout.fillHeight: true
                    Layout.leftMargin: 12
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    radius: 26
                    clip: true
                    color: "transparent"
                    border.width: 0

                    Repeater {
                        model: [
                            { "x": 25, "y": 96, "s": 2, "o": 0.55 },
                            { "x": 207, "y": 122, "s": 2, "o": 0.38 },
                            { "x": 226, "y": 242, "s": 1, "o": 0.56 },
                            { "x": 18, "y": 334, "s": 2, "o": 0.28 },
                            { "x": 216, "y": 468, "s": 2, "o": 0.4 },
                            { "x": 28, "y": 596, "s": 1, "o": 0.5 },
                            { "x": 201, "y": 690, "s": 1, "o": 0.42 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            x: modelData.x
                            y: modelData.y
                            width: modelData.s
                            height: modelData.s
                            radius: width / 2
                            color: "#e4c36f"
                            opacity: modelData.o
                        }
                    }

                    Item {
                        id: brandHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.topMargin: 14
                        height: 66

                        Rectangle {
                            width: 38
                            height: 38
                            radius: 12
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#211b10"
                            border.width: 0

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                anchors.centerIn: parent
                                color: "#100e09"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "✦"
                                color: "#f0ca72"
                                font.pixelSize: 20
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 49
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "STARRY"
                                color: "#f7eed9"
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                font.letterSpacing: 2.2
                            }
                            Text {
                                text: "YOUR MEDIA UNIVERSE"
                                color: "#897856"
                                font.pixelSize: 7
                                font.letterSpacing: 1.25
                            }
                        }

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#d1aa54"
                        }
                    }

                    Column {
                        id: primaryNavigation
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: brandHeader.bottom
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.topMargin: 8
                        spacing: 4

                        SidebarButton {
                            text: "首页"; glyph: "⌂"; selected: window.selectedNav === 0
                            onClicked: {
                                window.selectedNav = 0
                                window.selectedLibraryName = ""
                                window.homeHeroIndex = 0
                                emby.loadItems()
                            }
                        }
                        SidebarButton {
                            text: "电影"; glyph: "◆"; selected: window.selectedNav === 1
                            onClicked: { window.selectedNav = 1; window.selectedLibraryName = ""; emby.loadItems("", "Movie") }
                        }
                        SidebarButton {
                            text: "剧集"; glyph: "▦"; selected: window.selectedNav === 2
                            onClicked: { window.selectedNav = 2; window.selectedLibraryName = ""; emby.loadItems("", "Series") }
                        }
                    }

                    Row {
                        id: serversSectionHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: primaryNavigation.bottom
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        anchors.topMargin: 18
                        height: 30

                        Text {
                            text: "媒体服务器"
                            color: "#8f7c58"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "1 ONLINE"
                            color: "#776846"
                            font.pixelSize: 8
                            font.letterSpacing: 0.8
                        }
                    }

                    Flickable {
                        id: serversFlick
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: serversSectionHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.topMargin: 4
                        anchors.bottomMargin: 18
                        contentHeight: serversColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: serversColumn
                            width: serversFlick.width

                            ServerLibraryGroup {
                                width: parent.width
                                serverName: window.serverNameFromUrl(emby.serverUrl)
                                serverAddress: "EMBY  ·  已连接"
                                libraries: emby.libraries
                                selectedLibrary: window.selectedNav >= 10 ? window.selectedNav - 10 : -1

                                onLibraryClicked: function(index, libraryId, libraryName) {
                                    window.selectedNav = 10 + index
                                    window.selectedLibraryName = libraryName
                                    emby.loadItems(libraryId)
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    HomeHero {
                        id: homeHeroPage
                        anchors.fill: parent
                        visible: window.selectedNav === 0
                        media: window.homeHero
                        currentIndex: window.homeHeroIndex
                        itemCount: window.homeHeroCount

                        onPlayRequested: playerLayer.start(window.homeHero)
                        onPreviousRequested: window.stepHomeHero(-1)
                        onNextRequested: window.stepHomeHero(1)
                        onIndexRequested: function(index) { window.homeHeroIndex = index }

                        Timer {
                            interval: 8000
                            repeat: true
                            running: homeHeroPage.visible && window.homeHeroCount > 1
                            onTriggered: window.stepHomeHero(1)
                        }
                    }

                    Flickable {
                        id: contentFlick
                        anchors.fill: parent
                        visible: window.selectedNav !== 0
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
                                    text: window.selectedNav === 1 ? "电影"
                                         : window.selectedNav === 2 ? "剧集"
                                         : window.selectedLibraryName || "媒体库"
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

                            RowLayout {
                                width: parent.width
                                Text { text: searchField.text.length > 0 ? "搜索结果" : "最近添加"; color: "#eee7d6"; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.fillWidth: true }
                                Text { text: emby.items.length + " 项"; color: "#827962"; font.pixelSize: 12 }
                            }

                            GridView {
                                id: mediaGrid
                                width: parent.width
                                height: Math.ceil(emby.items.length / Math.max(1, Math.floor(width / cellWidth))) * cellHeight
                                interactive: false
                                cellWidth: 218
                                cellHeight: 372
                                model: emby.items
                                delegate: MediaCard {
                                    required property var modelData
                                    width: 200; height: 354
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
        contentItem: Rectangle {
            radius: 20
            clip: true
            color: "transparent"
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
            Rectangle {
                anchors.fill: parent
                radius: 20
                color: "transparent"
                border.color: "#4a4028"
                border.width: 1
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
