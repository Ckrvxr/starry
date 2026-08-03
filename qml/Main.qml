import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: window
    width: 1360
    height: 820
    x: Math.round((Screen.desktopAvailableWidth - width) / 2)
    y: Math.round((Screen.desktopAvailableHeight - height) / 2)
    minimumWidth: 980
    minimumHeight: 640
    visible: true
    title: "Starry"
    color: "#0b0b09"
    flags: Qt.Window | Qt.FramelessWindowHint

    property int selectedNav: 0
    property bool settingsVisible: false
    property string selectedLibraryName: ""
    property int homeHeroIndex: 0
    property bool detailVisible: false
    property var detailMedia: ({})
    property bool pageTransitionActive: false
    readonly property string activePageKey: settingsVisible ? "settings" : detailVisible ? "detail:" + String(detailMedia.id || "") : selectedNav === 0 ? "home" : "library:" + String(selectedNav)
    readonly property var homeHeroItems: emby.hotItems.length > 0 ? emby.hotItems : emby.items
    readonly property int homeHeroCount: Math.min(5, homeHeroItems.length)
    readonly property var homeHero: homeHeroCount > 0 ? homeHeroItems[Math.min(homeHeroIndex, homeHeroCount - 1)] : ({})
    property bool isFullscreen: visibility === Window.FullScreen

    onActivePageKeyChanged: {
        pageTransitionActive = true;
        pageTransitionTimer.restart();
    }

    Timer {
        id: pageTransitionTimer
        interval: 380
        onTriggered: window.pageTransitionActive = false
    }

    function serverNameFromUrl(value) {
        const host = String(value || "").replace(/^https?:\/\//, "").replace(/\/.*$/, "");
        return host.length > 0 ? host : "Emby Server";
    }

    function stepHomeHero(step) {
        if (homeHeroCount < 1)
            return;
        homeHeroIndex = (homeHeroIndex + step + homeHeroCount) % homeHeroCount;
    }

    function openDetail(item) {
        detailMedia = item;
        detailVisible = true;
        emby.loadItem(item.id);
        if (item.type === "Series")
            emby.loadEpisodes(item.id);
    }

    function closeDetail() {
        detailVisible = false;
        detailMedia = ({});
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

        Item {
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "#070706"
                    }
                    GradientStop {
                        position: 0.48
                        color: "#0d0c09"
                    }
                    GradientStop {
                        position: 1
                        color: "#171207"
                    }
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
                    {
                        "x": 0.24,
                        "y": 0.09,
                        "s": 2,
                        "o": 0.24
                    },
                    {
                        "x": 0.49,
                        "y": 0.16,
                        "s": 1,
                        "o": 0.32
                    },
                    {
                        "x": 0.73,
                        "y": 0.08,
                        "s": 2,
                        "o": 0.2
                    },
                    {
                        "x": 0.91,
                        "y": 0.31,
                        "s": 1,
                        "o": 0.26
                    },
                    {
                        "x": 0.64,
                        "y": 0.7,
                        "s": 2,
                        "o": 0.18
                    },
                    {
                        "x": 0.38,
                        "y": 0.86,
                        "s": 1,
                        "o": 0.28
                    },
                    {
                        "x": 0.84,
                        "y": 0.91,
                        "s": 2,
                        "o": 0.2
                    }
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
                            {
                                "x": 25,
                                "y": 96,
                                "s": 2,
                                "o": 0.55
                            },
                            {
                                "x": 207,
                                "y": 122,
                                "s": 2,
                                "o": 0.38
                            },
                            {
                                "x": 226,
                                "y": 242,
                                "s": 1,
                                "o": 0.56
                            },
                            {
                                "x": 18,
                                "y": 334,
                                "s": 2,
                                "o": 0.28
                            },
                            {
                                "x": 216,
                                "y": 468,
                                "s": 2,
                                "o": 0.4
                            },
                            {
                                "x": 28,
                                "y": 596,
                                "s": 1,
                                "o": 0.5
                            },
                            {
                                "x": 201,
                                "y": 690,
                                "s": 1,
                                "o": 0.42
                            }
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

                            LucideIcon {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                name: "sparkles"
                                color: "#f0ca72"
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 49
                            anchors.verticalCenter: parent.verticalCenter
                            text: "STARRY"
                            color: "#f7eed9"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            font.letterSpacing: 2.2
                        }

                        Rectangle {
                            id: settingsButton
                            width: 34
                            height: 34
                            radius: 17
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: settingsMouse.containsMouse || window.settingsVisible ? "#272014" : "transparent"
                            border.width: 0

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            LucideIcon {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                name: "settings"
                                color: settingsMouse.containsMouse || window.settingsVisible ? "#edc86d" : "#8f7c58"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                id: settingsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: "设置"
                                onClicked: {
                                    window.settingsVisible = true;
                                    window.closeDetail();
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: homeCard
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: brandHeader.bottom
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.topMargin: 10
                        height: 66
                        radius: 16
                        color: homeMouse.containsMouse ? "#211b11" : window.selectedNav === 0 ? "#272014" : "#17140e"
                        border.width: 0

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: window.selectedNav === 0 ? "#3a2f19" : "#2b2314"
                            border.width: 0

                            LucideIcon {
                                anchors.centerIn: parent
                                width: 17
                                height: 17
                                name: "house"
                                color: window.selectedNav === 0 ? "#edc86d" : "#f0cf83"
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 54
                            anchors.verticalCenter: parent.verticalCenter
                            text: "首页"
                            color: window.selectedNav === 0 ? "#f6edd8" : "#f1e7d3"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        Rectangle {
                            width: 7
                            height: 7
                            radius: 4
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            color: window.selectedNav === 0 ? "#e5bd69" : "#4a3d28"
                        }

                        MouseArea {
                            id: homeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: "首页"
                            onClicked: {
                                window.closeDetail();
                                window.settingsVisible = false;
                                window.selectedNav = 0;
                                window.selectedLibraryName = "";
                                window.homeHeroIndex = 0;
                                emby.loadItems();
                            }
                        }
                    }

                    Flickable {
                        id: serversFlick
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: homeCard.bottom
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.topMargin: 10
                        anchors.bottomMargin: 18
                        contentHeight: serversColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: serversColumn
                            width: serversFlick.width
                            spacing: 8

                            Repeater {
                                model: emby.servers

                                delegate: ServerLibraryGroup {
                                    width: parent.width
                                    serverName: modelData.displayName && modelData.displayName.length > 0 ? modelData.displayName : window.serverNameFromUrl(modelData.url)
                                    serverAddress: modelData.userName + " · EMBY"
                                    logoUrl: modelData.url
                                    libraries: emby.serverUrl === modelData.url ? emby.libraries : []
                                    active: emby.serverUrl === modelData.url
                                    expanded: emby.serverUrl === modelData.url
                                    selectedLibrary: emby.serverUrl === modelData.url && window.selectedNav >= 10 ? window.selectedNav - 10 : -1

                                    onLibraryClicked: function (index, libraryId, libraryName) {
                                        window.closeDetail();
                                        window.settingsVisible = false;
                                        window.selectedNav = 10 + index;
                                        window.selectedLibraryName = libraryName;
                                        emby.loadItems(libraryId);
                                    }

                                    onActivateRequested: {
                                        window.closeDetail();
                                        window.settingsVisible = false;
                                        window.selectedNav = 0;
                                        window.selectedLibraryName = "";
                                        emby.switchServer(modelData.url);
                                    }
                                }
                            }

                            Text {
                                visible: emby.servers.length === 0
                                width: parent.width
                                height: 40
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "尚未连接服务器"
                                color: "#766848"
                                font.pixelSize: 11
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
                        visible: !window.settingsVisible && window.selectedNav === 0
                        media: window.homeHero
                        currentIndex: window.homeHeroIndex
                        itemCount: window.homeHeroCount
                        resume: emby.resumeItems

                        onPlayRequested: playerLayer.start(window.homeHero)
                        onResumePlayRequested: function (item) {
                            playerLayer.start(item);
                        }
                        onPreviousRequested: window.stepHomeHero(-1)
                        onNextRequested: window.stepHomeHero(1)
                        onIndexRequested: function (index) {
                            window.homeHeroIndex = index;
                        }

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
                        visible: !window.settingsVisible && window.selectedNav !== 0
                        contentHeight: contentColumn.height + 60
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}

                        Column {
                            id: contentColumn
                            x: 34
                            y: 24
                            width: contentFlick.width - 68
                            spacing: 26

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: window.selectedLibraryName || "媒体库"
                                    color: "#f3eddd"
                                    font.pixelSize: 25
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                }
                                TextField {
                                    id: searchField
                                    Layout.preferredWidth: 280
                                    Layout.preferredHeight: 42
                                    placeholderText: "搜索电影、剧集…"
                                    color: "#f4efdf"
                                    placeholderTextColor: "#77705f"
                                    leftPadding: 16
                                    background: Rectangle {
                                        color: "#1a1811"
                                        radius: 21
                                        border.color: searchField.activeFocus ? "#c9a85b" : "#393326"
                                    }
                                    Timer {
                                        interval: 350
                                        running: searchField.text.length > 0
                                        onTriggered: emby.search(searchField.text)
                                    }
                                    onTextEdited: if (text.length === 0)
                                        emby.loadItems()
                                    onAccepted: emby.search(text)
                                }
                                BusyIndicator {
                                    running: emby.busy
                                    visible: running
                                    implicitWidth: 28
                                    implicitHeight: 28
                                }
                            }

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: searchField.text.length > 0 ? "搜索结果" : "最近添加"
                                    color: "#eee7d6"
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: emby.items.length + " 项"
                                    color: "#827962"
                                    font.pixelSize: 12
                                }
                            }

                            GridView {
                                id: mediaGrid
                                property int columnCount: Math.max(1, Math.floor(width / 218))
                                property real cardWidth: Math.min(220, cellWidth - 28)
                                property real cardHeight: Math.round(cardWidth * 1.48) + 58

                                width: parent.width
                                height: Math.ceil(emby.items.length / columnCount) * cellHeight
                                interactive: false
                                cellWidth: width / columnCount
                                cellHeight: cardHeight + 30
                                model: emby.items

                                delegate: Item {
                                    id: cardCell
                                    required property var modelData
                                    width: mediaGrid.cellWidth
                                    height: mediaGrid.cellHeight

                                    MediaCard {
                                        width: mediaGrid.cardWidth
                                        height: mediaGrid.cardHeight
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        media: cardCell.modelData
                                        onClicked: window.openDetail(cardCell.modelData)
                                    }
                                }
                            }
                        }
                    }

                    MediaDetailView {
                        id: mediaDetailPage
                        anchors.fill: parent
                        z: 20
                        visible: window.detailVisible
                        media: emby.currentItem.id === window.detailMedia.id ? emby.currentItem : window.detailMedia
                        loading: emby.busy && emby.currentItem.id !== window.detailMedia.id
                        episodes: emby.episodes
                        loadingEpisodes: window.detailMedia.type === "Series" && emby.busy && emby.episodes.length === 0

                        onBackRequested: window.closeDetail()
                        onPlayRequested: function (media) {
                            playerLayer.start(media);
                        }
                    }

                    SettingsView {
                        id: settingsPage
                        anchors.fill: parent
                        visible: window.settingsVisible

                        onSwitchRequested: function (url) {
                            window.settingsVisible = false;
                            window.closeDetail();
                            window.selectedNav = 0;
                            window.selectedLibraryName = "";
                            emby.switchServer(url);
                        }
                    }

                    PageLoadingOverlay {
                        anchors.fill: parent
                        z: 80
                        active: window.pageTransitionActive || emby.busy
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
        onCloseRequested: if (window.isFullscreen)
            window.showNormal()
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
                width: 14
                height: 14
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
                width: 14
                height: 14
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
                width: 14
                height: 14
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
        function onLoginSucceeded() {
            searchField.clear();
        }
        function onItemsChanged() {
            if (window.homeHeroIndex >= window.homeHeroCount)
                window.homeHeroIndex = 0;
        }
    }
}
