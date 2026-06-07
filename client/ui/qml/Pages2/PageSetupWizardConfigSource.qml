pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import "../Controls2"

PageType {
    id: root

    property int tabHome: 0
    property int tabLocations: 1
    property int tabProfile: 2
    property int tabSettings: 3
    property int currentTab: tabHome
    property int selectedServerIndex: 0
    property int protocolIndex: 0

    property bool guestMode: false
    property bool russianBypass: true
    property bool sortAscending: true
    property string emailText: ""
    property string statusText: ""
    property string toastText: ""
    property string searchText: ""
    property string backendUrlText: AppApiController.baseUrl

    readonly property string pocAuthCode: "TEST123"
    readonly property bool authScreenVisible: !AppApiController.authenticated && !guestMode
    readonly property bool realApiMode: AppApiController.authenticated && !AppApiController.mockMode
    readonly property int bottomNavHeight: 70
    readonly property int bottomNavSafeMargin: Math.max(12, PageController.safeAreaBottomMargin + 2)
    readonly property var fallbackServers: [
        {
            "id": "nl-awg-1",
            "title": "Нидерланды 1",
            "country": "Нидерланды",
            "city": "Амстердам",
            "protocol": "amnezia_wg",
            "mode": "stable_mobile",
            "status": "online",
            "quality": 3,
            "latency": "31 ms"
        },
        {
            "id": "de-awg-1",
            "title": "Германия 1",
            "country": "Германия",
            "city": "Франкфурт",
            "protocol": "amnezia_wg",
            "mode": "stable_mobile",
            "status": "online",
            "quality": 2,
            "latency": "44 ms"
        },
        {
            "id": "reserve-xray-1",
            "title": "Резервный сервер",
            "country": "Европа",
            "city": "Xray / VLESS",
            "protocol": "xray_vless_reality",
            "mode": "reserve",
            "status": "reserve",
            "quality": 1,
            "latency": "резерв"
        }
    ]
    readonly property var protocolModes: [
        {
            "title": "Auto",
            "description": "Клиент сам выбирает основной или резервный протокол."
        },
        {
            "title": "LoxleyWG",
            "description": "Основной режим для LoxleyVPN v0.1."
        },
        {
            "title": "LoxleyWG Extra",
            "description": "Усиленный WireGuard-профиль для нестабильных сетей."
        },
        {
            "title": "Xray",
            "description": "Резервный протокол для сетей с жёсткой фильтрацией."
        },
        {
            "title": "Xray Extra",
            "description": "Резервный режим с дополнительной маскировкой."
        }
    ]

    Connections {
        target: AppApiController

        function onLoginSucceeded() {
            root.guestMode = false
            root.statusText = "Профиль подключён"
            root.currentTab = root.tabHome
            AppApiController.fetchMe()
            AppApiController.fetchServers()
        }

        function onLoginFailed(message) {
            root.statusText = message || "Не удалось войти"
            root.showToast(root.statusText)
        }

        function onMeFetched() {
            root.statusText = "Подписка активна"
        }

        function onServersFetched() {
            if (root.selectedServerIndex >= root.currentServers().length) {
                root.selectedServerIndex = 0
            }
        }

        function onMeFailed(message) {
            root.statusText = message || "Ошибка запроса"
            root.showToast(root.statusText)
        }

        function onServersFailed(message) {
            root.statusText = message || "Ошибка запроса"
            root.showToast(root.statusText)
        }

        function onConfigFetched(serverId, protocol, config, fakeConfig) {
            if (fakeConfig) {
                root.statusText = "Тестовый сервер доступен. Реальный туннель не создаётся."
                root.showToast(root.statusText)
                return
            }

            var server = root.serverById(serverId)
            root.statusText = "Конфигурация получена"
            root.importAndConnectConfig(config, server.title || "LoxleyVPN")
        }

        function onConfigFailed(serverId, message, statusCode) {
            if (statusCode === 501) {
                root.statusText = "Резервный протокол пока не включён"
            } else {
                root.statusText = message || "Не удалось получить конфигурацию"
            }
            root.showToast(root.statusText)
        }
    }

    Connections {
        target: ImportController

        function onImportErrorOccurred(errorCode, unusedHomeRedirect) {
            root.statusText = "Ошибка импорта конфигурации"
            root.showToast(root.statusText)
        }

        function onImportFinished() {
            root.statusText = "Профиль VPN готов"
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#103F2E"
            }
            GradientStop {
                position: 0.48
                color: "#0C2A22"
            }
            GradientStop {
                position: 1
                color: "#061016"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: 0.34
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "#07120F"
            }
            GradientStop {
                position: 0.58
                color: "#163F2B"
            }
            GradientStop {
                position: 1
                color: "#244E35"
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.authScreenVisible

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: authColumn.implicitHeight + 96
            clip: true

            Column {
                id: authColumn
                width: Math.min(parent.width - 56, 440)
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 72 + PageController.safeAreaTopMargin
                spacing: 24

                AppLogoHeader {
                    width: parent.width
                }

                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        width: parent.width
                        text: "Добро пожаловать"
                        color: "#F7FBFF"
                        font.pixelSize: 33
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: "Войдите или зарегистрируйтесь"
                        color: "#B7C1D0"
                        font.pixelSize: 19
                        lineHeight: 1.18
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    width: parent.width
                    spacing: 12

                    LoxleyTextField {
                        width: parent.width
                        text: root.emailText
                        placeholderText: "Введите email"
                        inputMethodHints: Qt.ImhEmailCharactersOnly

                        onTextChanged: root.emailText = text
                        onAccepted: root.loginWithEmail()
                    }

                    LoxleyButton {
                        width: parent.width
                        text: AppApiController.busy ? "Подключаем профиль..." : "Продолжить"
                        enabled: !AppApiController.busy
                        onClicked: root.loginWithEmail()
                    }

                    Text {
                        width: parent.width
                        text: "Нажимая «Продолжить», вы соглашаетесь с условиями использования и политикой конфиденциальности LoxleyVPN."
                        color: "#C1CAD7"
                        font.pixelSize: 14
                        lineHeight: 1.26
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    LoxleyButton {
                        width: Math.min(parent.width, 190)
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Позже"
                        secondary: true
                        onClicked: root.enterGuestMode()
                    }
                }

                Text {
                    width: parent.width
                    text: root.statusText
                    visible: text.length > 0
                    color: "#BDEB7B"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.authScreenVisible

        Flickable {
            id: appScroll
            anchors.fill: parent
            anchors.topMargin: 42 + PageController.safeAreaTopMargin
            anchors.bottomMargin: root.bottomNavHeight + root.bottomNavSafeMargin
            contentWidth: width
            contentHeight: pageColumn.implicitHeight + 34
            clip: true
            bottomMargin: 18

            Column {
                id: pageColumn
                width: Math.min(parent.width - 32, 520)
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 0
                spacing: 18

                Loader {
                    width: parent.width
                    sourceComponent: {
                        if (root.currentTab === root.tabLocations) {
                            return locationsScreen
                        }
                        if (root.currentTab === root.tabProfile) {
                            return profileScreen
                        }
                        if (root.currentTab === root.tabSettings) {
                            return settingsScreen
                        }
                        return homeScreen
                    }
                }
            }
        }

        Rectangle {
            id: bottomNav
            width: parent.width
            height: root.bottomNavHeight + root.bottomNavSafeMargin
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            radius: 0
            color: "#0D1816"
            border.color: "transparent"
            border.width: 0

            Row {
                width: Math.min(parent.width - 32, 520)
                height: root.bottomNavHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 8

                NavItem {
                    width: (parent.width - 16) / 3
                    height: parent.height
                    tabIndex: root.tabHome
                    label: "Главная"
                    iconSource: "qrc:/images/controls/home.svg"
                }

                NavItem {
                    width: (parent.width - 16) / 3
                    height: parent.height
                    tabIndex: root.tabLocations
                    label: "Локации"
                    iconSource: "qrc:/images/controls/globe-2.svg"
                }

                NavItem {
                    width: (parent.width - 16) / 3
                    height: parent.height
                    tabIndex: root.tabProfile
                    label: "Профиль"
                    iconSource: "qrc:/images/controls/app.svg"
                }
            }
        }
    }

    Rectangle {
        width: Math.min(parent.width - 38, 440)
        height: Math.max(58, toastMessage.implicitHeight + 28)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomNavHeight + root.bottomNavSafeMargin + 12
        radius: 18
        color: "#2E6F4E"
        border.color: "#87C86C"
        opacity: toastTimer.running ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }

        Text {
            id: toastMessage
            anchors.fill: parent
            anchors.margins: 12
            text: root.toastText
            color: "#E9FFF1"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Timer {
        id: toastTimer
        interval: 3200
    }

    Component {
        id: homeScreen

        Column {
            width: parent.width
            spacing: 18

            Item {
                width: parent.width
                height: 30

                Row {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, warningIcon.width + connectionWarning.implicitWidth + 10)
                    height: parent.height
                    spacing: 10

                    Image {
                        id: warningIcon
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/images/controls/map-pin.svg"
                        opacity: 0.9
                    }

                    Text {
                        id: connectionWarning
                        width: parent.width - warningIcon.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: ConnectionController.isConnected ? "VPN включён" : "Без VPN соединение не защищено"
                        color: ConnectionController.isConnected ? "#83F2BF" : "#FF8B8B"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 30
                color: "#173326"
                opacity: 0.96
                border.color: "#496D4C"
                border.width: 1
                implicitHeight: locationRow.implicitHeight + 30

                Row {
                    id: locationRow
                    width: parent.width - 34
                    anchors.centerIn: parent
                    spacing: 16

                    FlagBadge {
                        width: 52
                        height: 52
                        server: root.selectedServer()
                    }

                    Column {
                        width: parent.width - 68
                        spacing: 4

                        Text {
                            width: parent.width
                            text: "Выбранная локация"
                            color: "#C5D7BF"
                            font.pixelSize: 15
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.serverDisplayTitle(root.selectedServer())
                            color: "#F7FBFF"
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.currentTab = root.tabLocations
                }
            }

            Item {
                width: parent.width
                height: 116
            }

            Text {
                width: parent.width
                text: ConnectionController.isConnected ? "Вы подключены" : "Вы не подключены"
                color: "#F7FBFF"
                font.pixelSize: 21
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            VpnToggle {
                width: Math.min(parent.width - 74, 318)
                anchors.horizontalCenter: parent.horizontalCenter
                connected: ConnectionController.isConnected
                busy: ConnectionController.isConnectionInProgress
                onClicked: root.toggleSelectedServer()
            }

            Text {
                width: parent.width
                text: "При первом подключении устройство запросит разрешение на VPN-соединение."
                visible: AppApiController.authenticated
                color: "#B9C7B2"
                font.pixelSize: 14
                lineHeight: 1.22
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Component {
        id: locationsScreen

        Column {
            width: parent.width
            spacing: 22

            ScreenHeader {
                width: parent.width
                title: "Локации"
                subtitle: ""
            }

            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: parent.width - 66
                    height: 50
                    radius: 25
                    color: "#10221B"
                    border.color: "#3F6545"
                    border.width: 1

                    Image {
                        width: 21
                        height: 21
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/images/controls/search.svg"
                        opacity: 0.68
                    }

                    TextField {
                        anchors.fill: parent
                        anchors.leftMargin: 54
                        anchors.rightMargin: 18
                        text: root.searchText
                        placeholderText: "Поиск"
                        placeholderTextColor: "#9AAFA0"
                        color: "#F7FBFF"
                        font.pixelSize: 17
                        background: null
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.searchText = text
                    }
                }

                Rectangle {
                    width: 56
                    height: 50
                    radius: 25
                    color: "#10221B"
                    border.color: "#3F6545"
                    border.width: 1

                    SortGlyph {
                        anchors.centerIn: parent
                        width: 25
                        height: 28
                        ascending: root.sortAscending
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.sortAscending = !root.sortAscending
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 24
                color: "#142A21"
                opacity: 0.96
                implicitHeight: locationsList.implicitHeight + 18

                Column {
                    id: locationsList
                    width: parent.width - 36
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 9

                    Repeater {
                        model: root.filteredServers()

                        delegate: Item {
                            required property int index
                            required property var modelData

                            width: parent.width
                            height: 78

                            Row {
                                id: serverRow
                                width: parent.width
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 16

                                FlagBadge {
                                    width: 48
                                    height: 48
                                    server: modelData
                                }

                                Text {
                                    width: parent.width - 126
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.serverDisplayTitle(modelData)
                                    color: root.serverIndexById(modelData.id) === root.selectedServerIndex ? "#B6EA6E" : "#F7FBFF"
                                    font.pixelSize: 20
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Item {
                                    width: 62
                                    height: 48

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3

                                        QualityBars {
                                            width: 42
                                            height: 22
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            quality: modelData.quality || root.qualityForStatus(modelData.status)
                                        }

                                        Text {
                                            width: 62
                                            text: modelData.latency || ""
                                            color: "#AEBFA9"
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                anchors.bottom: parent.bottom
                                color: "#30483A"
                                opacity: 0.72
                                visible: index < root.filteredServers().length - 1
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedServerIndex = root.serverIndexById(modelData.id)
                                    root.currentTab = root.tabHome
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: profileScreen

        Column {
            width: parent.width
            spacing: 20

            ScreenHeader {
                width: parent.width
                title: "Профиль"
                subtitle: ""
            }

            Item {
                width: parent.width
                height: 286

                Column {
                    id: profileColumn
                    width: parent.width
                    anchors.centerIn: parent
                    spacing: 22

                    Rectangle {
                        width: 96
                        height: 96
                        radius: 48
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#1A2E24"

                        ProfileGlyph {
                            width: 46
                            height: 46
                            anchors.centerIn: parent
                            color: "#DCEED2"
                        }
                    }

                    Text {
                        width: parent.width
                        text: AppApiController.authenticated ? "Профиль активен" : "Вход не выполнен"
                        color: "#F7FBFF"
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    LoxleyButton {
                        width: Math.min(parent.width - 52, 390)
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: AppApiController.authenticated ? "Выйти" : "Войти"
                        secondary: AppApiController.authenticated
                        onClicked: {
                            if (AppApiController.authenticated) {
                                AppApiController.clearSession()
                                root.guestMode = true
                                root.statusText = "Профиль отключён"
                            } else {
                                root.guestMode = false
                            }
                        }
                    }
                }
            }

            MenuRow {
                width: parent.width
                iconSource: "qrc:/images/controls/settings-2.svg"
                title: "Настройки"
                subtitle: ""
                onClicked: root.currentTab = root.tabSettings
            }

            MenuRow {
                width: parent.width
                iconSource: "qrc:/images/controls/help-circle.svg"
                title: "Справочный центр"
                subtitle: ""
                onClicked: root.showToast("Раздел помощи появится в следующей версии")
            }

            Text {
                width: parent.width
                text: "v0.1"
                color: "#8AA18E"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Component {
        id: settingsScreen

        Column {
            width: parent.width
            spacing: 18

            ScreenHeader {
                width: parent.width
                title: "Настройки"
                subtitle: "Выберите протокол и правила маршрутизации."
            }

            Column {
                width: parent.width
                spacing: 10

                Repeater {
                    model: root.protocolModes

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        width: parent.width
                        radius: 18
                        color: index === root.protocolIndex ? "#203B29" : "#14241D"
                        border.color: index === root.protocolIndex ? "#7FAB55" : "transparent"
                        implicitHeight: protocolRow.implicitHeight + 24

                        Row {
                            id: protocolRow
                            width: parent.width - 26
                            anchors.centerIn: parent
                            spacing: 12

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: "transparent"
                                border.color: index === root.protocolIndex ? "#A8D85E" : "#7A8B78"
                                border.width: 2

                                Rectangle {
                                    width: 10
                                    height: 10
                                    radius: 5
                                    anchors.centerIn: parent
                                    color: "#A8D85E"
                                    visible: index === root.protocolIndex
                                }
                            }

                            Column {
                                width: parent.width - 34
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    color: "#F3FFF7"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.description
                                    color: "#93A79D"
                                    font.pixelSize: 12
                                    lineHeight: 1.15
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.protocolIndex = index
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 20
                color: "#14241D"
                border.color: "transparent"
                implicitHeight: bypassRow.implicitHeight + 28

                Row {
                    id: bypassRow
                    width: parent.width - 28
                    anchors.centerIn: parent
                    spacing: 14

                    Column {
                        width: parent.width - 72
                        spacing: 5

                        Text {
                            width: parent.width
                            text: "Открывать российские сервисы без VPN"
                            color: "#F3FFF7"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "Маршрутизация останется быстрее для локальных банков, госуслуг и маркетплейсов."
                            color: "#93A79D"
                            font.pixelSize: 12
                            lineHeight: 1.15
                            wrapMode: Text.WordWrap
                        }
                    }

                    MiniToggle {
                        checked: root.russianBypass
                        onClicked: root.russianBypass = !root.russianBypass
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 20
                color: "#14241D"
                border.color: "transparent"
                implicitHeight: backendColumn.implicitHeight + 28

                Column {
                    id: backendColumn
                    width: parent.width - 28
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        width: parent.width
                        text: "Тестовый backend"
                        color: "#F3FFF7"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: "Поле нужно только для PoC-сборки. В релизе адрес будет задан приложением."
                        color: "#93A79D"
                        font.pixelSize: 12
                        lineHeight: 1.15
                        wrapMode: Text.WordWrap
                    }

                    LoxleyTextField {
                        width: parent.width
                        text: root.backendUrlText
                        placeholderText: "http://127.0.0.1:8000"
                        onTextChanged: {
                            root.backendUrlText = text
                            AppApiController.baseUrl = text
                        }
                    }
                }
            }

            LoxleyButton {
                width: parent.width
                text: "Назад в профиль"
                secondary: true
                onClicked: root.currentTab = root.tabProfile
            }
        }
    }

    function loginWithEmail() {
        var trimmedEmail = root.emailText.trim()
        if (trimmedEmail.length === 0) {
            root.statusText = "Введите email"
            root.showToast(root.statusText)
            return
        }

        if (root.backendUrlText.trim().length > 0) {
            AppApiController.baseUrl = root.backendUrlText.trim()
        }

        root.statusText = "Подключаем профиль"
        AppApiController.login(root.pocAuthCode, AppApiController.deviceUuid, trimmedEmail, "android")
    }

    function enterGuestMode() {
        root.guestMode = true
        root.currentTab = root.tabHome
        root.statusText = ""
    }

    function requireAuth() {
        root.statusText = "Авторизуйтесь для доступа к VPN"
        root.showToast(root.statusText)
        root.guestMode = false
    }

    function currentServers() {
        if (root.realApiMode && AppApiController.servers && AppApiController.servers.length > 0) {
            return AppApiController.servers
        }
        return root.fallbackServers
    }

    function filteredServers() {
        var q = root.searchText.trim().toLowerCase()
        var source = root.currentServers()
        var result = []
        for (var i = 0; i < source.length; i++) {
            var item = source[i]
            var haystack = ((item.title || "") + " " + (item.country || "") + " " + (item.city || "") + " " + (item.protocol || "")).toLowerCase()
            if (q.length === 0 || haystack.indexOf(q) !== -1) {
                result.push(item)
            }
        }
        result.sort(function(a, b) {
            var left = root.serverDisplayTitle(a).toLowerCase()
            var right = root.serverDisplayTitle(b).toLowerCase()
            if (left === right) {
                return 0
            }
            return root.sortAscending ? (left < right ? -1 : 1) : (left > right ? -1 : 1)
        })
        return result
    }

    function selectedServer() {
        var servers = root.currentServers()
        if (!servers || servers.length === 0) {
            return {}
        }
        var index = Math.max(0, Math.min(root.selectedServerIndex, servers.length - 1))
        return servers[index]
    }

    function selectedServerDescription() {
        var server = root.selectedServer()
        if (!server || !server.id) {
            return "Нет выбранного сервера"
        }
        return server.country || server.city || "Локация"
    }

    function serverDisplayTitle(server) {
        if (!server || !server.id) {
            return "Выберите локацию"
        }
        if (server.country && server.country.length > 0) {
            return server.country
        }
        if (server.title && server.title.length > 0) {
            return server.title
        }
        return "Локация"
    }

    function serverById(serverId) {
        var servers = root.currentServers()
        for (var i = 0; i < servers.length; i++) {
            if (servers[i].id === serverId) {
                return servers[i]
            }
        }
        return {}
    }

    function serverIndexById(serverId) {
        var servers = root.currentServers()
        for (var i = 0; i < servers.length; i++) {
            if (servers[i].id === serverId) {
                return i
            }
        }
        return 0
    }

    function protocolLabel(protocol) {
        if (protocol === "amnezia_wg") {
            return "LoxleyWG"
        }
        if (protocol === "xray_vless_reality") {
            return "Xray"
        }
        return protocol || "Auto"
    }

    function qualityForStatus(status) {
        if (status === "online" || status === "active") {
            return 3
        }
        if (status === "reserve") {
            return 1
        }
        return 2
    }

    function countryCode(server) {
        var country = (server && server.country ? server.country : "").toLowerCase()
        var city = (server && server.city ? server.city : "").toLowerCase()
        var serverId = (server && server.id ? server.id : "").toLowerCase()

        if (country.indexOf("нидер") !== -1 || country.indexOf("nether") !== -1 || serverId.indexOf("nl") === 0) {
            return "NL"
        }
        if (country.indexOf("герман") !== -1 || country.indexOf("german") !== -1 || serverId.indexOf("de") === 0) {
            return "DE"
        }
        if (country.indexOf("европа") !== -1 || country.indexOf("europe") !== -1 || city.indexOf("vless") !== -1) {
            return "EU"
        }
        return "EU"
    }

    function flagSource(server) {
        return "qrc:/countriesFlags/images/flagKit/" + root.countryCode(server) + ".svg"
    }

    function subscriptionSummary() {
        if (!AppApiController.user) {
            return "Подписка LoxleyVPN активна"
        }
        var subscription = AppApiController.user.subscription || {}
        var plan = subscription.plan || "LoxleyVPN"
        var status = subscription.status || "active"
        return plan + " · " + status
    }

    function connectionStateLabel() {
        if (ConnectionController.isConnected) {
            return "VPN подключён"
        }
        if (ConnectionController.isConnectionInProgress) {
            return "VPN подключается"
        }
        if (ConnectionController.connectionStateText === "Disconnecting...") {
            return "VPN отключается"
        }
        return "VPN выключен"
    }

    function vpnButtonLabel() {
        if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress) {
            return "СТОП"
        }
        return "VPN"
    }

    function toggleSelectedServer() {
        if (!AppApiController.authenticated) {
            root.requireAuth()
            return
        }

        if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress) {
            root.statusText = "Отключаем VPN"
            ConnectionController.closeConnection()
            return
        }

        root.connectSelectedServer()
    }

    function connectSelectedServer() {
        if (!AppApiController.authenticated) {
            root.requireAuth()
            return
        }

        var server = root.selectedServer()
        if (!server || !server.id) {
            root.showToast("Выберите локацию")
            return
        }

        if (server.status === "reserve" || server.protocol === "xray_vless_reality") {
            root.statusText = "Резервный протокол пока не включён"
            root.showToast(root.statusText)
            return
        }

        root.statusText = "Получаем конфигурацию"
        AppApiController.fetchConfig(server.id)
    }

    function importAndConnectConfig(configText, serverTitle) {
        if (!configText || configText.length === 0) {
            root.statusText = "Пустая конфигурация"
            root.showToast(root.statusText)
            return
        }

        if (!ImportController.extractConfigFromData(configText)) {
            root.statusText = "Ошибка импорта конфигурации"
            root.showToast(root.statusText)
            return
        }
        ImportController.importConfig()
        root.statusText = "Подключаем VPN"
        Qt.callLater(ConnectionController.openConnection)
    }

    function showToast(message) {
        root.toastText = message || ""
        toastTimer.restart()
    }

    component AppLogoHeader: Item {
        height: 96

        Rectangle {
            width: 82
            height: 82
            radius: 24
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            color: "#D8EBC9"

            Canvas {
                anchors.centerIn: parent
                width: 50
                height: 50

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = "#07141B"
                    ctx.fillStyle = "#07141B"
                    ctx.lineWidth = 5
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    ctx.beginPath()
                    ctx.moveTo(width / 2, 4)
                    ctx.lineTo(width - 8, 14)
                    ctx.lineTo(width - 8, 30)
                    ctx.quadraticCurveTo(width - 8, 39, width / 2, 46)
                    ctx.quadraticCurveTo(8, 39, 8, 30)
                    ctx.lineTo(8, 14)
                    ctx.closePath()
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.moveTo(width / 2, 19)
                    ctx.lineTo(width / 2, 42)
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.moveTo(width / 2, 19)
                    ctx.quadraticCurveTo(16, 20, 16, 33)
                    ctx.stroke()
                }
            }
        }
    }

    component VpnToggle: Rectangle {
        id: vpnToggleRoot

        property bool connected: false
        property bool busy: false
        signal clicked()

        height: 74
        radius: height / 2
        color: connected ? "#203D2B" : "#0D1614"
        border.color: connected ? "#A8D85E" : "#3D5E45"
        border.width: 1.2

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }

        Rectangle {
            id: toggleThumb
            width: 58
            height: 58
            radius: 29
            anchors.verticalCenter: parent.verticalCenter
            x: vpnToggleRoot.connected ? vpnToggleRoot.width - width - 8 : 8
            color: vpnToggleRoot.connected ? "#A8D85E" : "#294538"

            Behavior on x {
                NumberAnimation {
                    duration: 190
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }

            PowerGlyph {
                anchors.centerIn: parent
                width: 27
                height: 27
                color: vpnToggleRoot.connected ? "#08140D" : "#E8F3E3"
                strokeWidth: 3
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: vpnToggleRoot.connected ? parent.left : toggleThumb.right
            anchors.right: vpnToggleRoot.connected ? toggleThumb.left : parent.right
            anchors.leftMargin: vpnToggleRoot.connected ? 28 : 16
            anchors.rightMargin: vpnToggleRoot.connected ? 16 : 28
            text: vpnToggleRoot.busy ? "Подключаем" : (vpnToggleRoot.connected ? "Отключить" : "Подключить")
            color: vpnToggleRoot.connected ? "#DFF6B8" : "#F3FFF7"
            font.family: "sans-serif-medium"
            font.pixelSize: 18
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: vpnToggleRoot.clicked()
        }
    }

    component MiniToggle: Rectangle {
        id: miniToggleRoot

        property bool checked: false
        signal clicked()

        width: 56
        height: 34
        radius: 17
        color: checked ? "#A8D85E" : "#203127"
        border.color: checked ? "#A8D85E" : "#4E6552"
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        Rectangle {
            width: 26
            height: 26
            radius: 13
            anchors.verticalCenter: parent.verticalCenter
            x: miniToggleRoot.checked ? parent.width - width - 4 : 4
            color: miniToggleRoot.checked ? "#07140B" : "#B8C9B3"

            Behavior on x {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: miniToggleRoot.clicked()
        }
    }

    component PowerGlyph: Canvas {
        id: powerGlyphRoot

        property color color: "#F7FBFF"
        property real strokeWidth: 3

        onColorChanged: requestPaint()
        onStrokeWidthChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = powerGlyphRoot.color
            ctx.lineWidth = powerGlyphRoot.strokeWidth
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.arc(width / 2, height / 2 + 3, Math.min(width, height) * 0.34, Math.PI * 0.72, Math.PI * 2.28)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(width / 2, 2)
            ctx.lineTo(width / 2, height * 0.48)
            ctx.stroke()
        }
    }

    component SortGlyph: Canvas {
        id: sortGlyphRoot

        property bool ascending: true
        property color activeColor: "#A8D85E"
        property color inactiveColor: "#789184"

        onAscendingChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.lineWidth = 2.4
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            ctx.strokeStyle = sortGlyphRoot.ascending ? sortGlyphRoot.activeColor : sortGlyphRoot.inactiveColor
            ctx.beginPath()
            ctx.moveTo(width * 0.34, height * 0.78)
            ctx.lineTo(width * 0.34, height * 0.22)
            ctx.lineTo(width * 0.18, height * 0.38)
            ctx.moveTo(width * 0.34, height * 0.22)
            ctx.lineTo(width * 0.50, height * 0.38)
            ctx.stroke()

            ctx.strokeStyle = sortGlyphRoot.ascending ? sortGlyphRoot.inactiveColor : sortGlyphRoot.activeColor
            ctx.beginPath()
            ctx.moveTo(width * 0.66, height * 0.22)
            ctx.lineTo(width * 0.66, height * 0.78)
            ctx.lineTo(width * 0.50, height * 0.62)
            ctx.moveTo(width * 0.66, height * 0.78)
            ctx.lineTo(width * 0.82, height * 0.62)
            ctx.stroke()
        }
    }

    component ProfileGlyph: Canvas {
        id: profileGlyphRoot

        property color color: "#DCEED2"

        onColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = profileGlyphRoot.color
            ctx.lineWidth = 3.2
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.arc(width / 2, height * 0.33, width * 0.19, 0, Math.PI * 2)
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(width / 2, height * 0.86, width * 0.35, Math.PI * 1.08, Math.PI * 1.92)
            ctx.stroke()
        }
    }

    component FlagBadge: Item {
        id: flagBadgeRoot

        property var server

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#102C20"
        }

        Image {
            id: flagImage
            anchors.fill: parent
            source: root.flagSource(flagBadgeRoot.server)
            fillMode: Image.PreserveAspectCrop
            visible: false
            smooth: true
        }

        Rectangle {
            id: flagMask
            anchors.fill: parent
            radius: width / 2
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: flagImage
            maskSource: flagMask
        }
    }

    component LoxleyButton: Rectangle {
        id: buttonRoot

        property string text: ""
        property bool secondary: false
        property bool enabled: true
        signal clicked()

        height: 58
        radius: height / 2
        color: secondary ? "transparent" : "#A8D85E"
        border.color: secondary ? "#5D7A4B" : "#A8D85E"
        border.width: secondary ? 1.5 : 0
        opacity: enabled ? 1 : 0.45

        Text {
            anchors.centerIn: parent
            width: parent.width - 28
            text: buttonRoot.text
            color: buttonRoot.secondary ? "#C8EFA0" : "#07140B"
            font.family: "sans-serif-medium"
            font.pixelSize: 17
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            anchors.fill: parent
            enabled: buttonRoot.enabled
            onClicked: buttonRoot.clicked()
        }
    }

    component LoxleyChip: Rectangle {
        id: chipRoot

        property string text: ""
        signal clicked()

        height: 36
        radius: 14
        color: "#203B29"
        border.color: "#7FAB55"

        Text {
            anchors.centerIn: parent
            text: chipRoot.text
            color: "#D8F6B4"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent
            onClicked: chipRoot.clicked()
        }
    }

    component LoxleyTextField: Rectangle {
        id: fieldRoot

        property alias text: input.text
        property string placeholderText: ""
        property int inputMethodHints: Qt.ImhNone
        signal accepted()

        height: 58
        radius: height / 2
        color: "#12211B"
        border.color: input.activeFocus ? "#BDEB7B" : "#526A50"
        border.width: 1.3

        TextField {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            color: "#F7FBFF"
            placeholderText: fieldRoot.placeholderText
            placeholderTextColor: "#9EAF9B"
            font.family: "sans-serif"
            font.pixelSize: 17
            inputMethodHints: fieldRoot.inputMethodHints
            background: null
            verticalAlignment: TextInput.AlignVCenter
            onAccepted: fieldRoot.accepted()
        }
    }

    component ScreenHeader: Column {
        id: headerRoot

        property string title: ""
        property string subtitle: ""

        spacing: headerRoot.subtitle.length > 0 ? 7 : 0

        Text {
            width: parent.width
            text: headerRoot.title
            color: "#F7FBFF"
            font.family: "sans-serif-medium"
            font.pixelSize: 29
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: headerRoot.subtitle
            visible: headerRoot.subtitle.length > 0
            color: "#AEBFA9"
            font.pixelSize: 14
            lineHeight: 1.16
            wrapMode: Text.WordWrap
        }
    }

    component NavItem: Rectangle {
        id: navRoot

        property int tabIndex: 0
        property string label: ""
        property string iconSource: ""

        radius: 0
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 3

            Image {
                width: 25
                height: 25
                anchors.horizontalCenter: parent.horizontalCenter
                source: navRoot.iconSource
                fillMode: Image.PreserveAspectFit
                opacity: root.currentTab === navRoot.tabIndex || (root.currentTab === root.tabSettings && navRoot.tabIndex === root.tabProfile) ? 1 : 0.68
            }

            Text {
                text: navRoot.label
                color: root.currentTab === navRoot.tabIndex || (root.currentTab === root.tabSettings && navRoot.tabIndex === root.tabProfile) ? "#F7FBFF" : "#A8B6A5"
                font.pixelSize: 15
                font.weight: root.currentTab === navRoot.tabIndex || (root.currentTab === root.tabSettings && navRoot.tabIndex === root.tabProfile) ? Font.DemiBold : Font.Normal
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.currentTab = navRoot.tabIndex
        }
    }

    component QualityBars: Row {
        id: barsRoot

        property int quality: 2

        spacing: 3
        layoutDirection: Qt.LeftToRight

        Repeater {
            model: 3

            Rectangle {
                required property int index

                width: 6
                height: 10 + index * 5
                radius: 3
                y: barsRoot.height - height
                color: index < barsRoot.quality ? "#A8D85E" : "#4E5F53"
            }
        }
    }

    component MenuRow: Rectangle {
        id: menuRoot

        property string iconSource: ""
        property string title: ""
        property string subtitle: ""
        signal clicked()

        radius: 22
        color: "#14241D"
        border.color: "transparent"
        implicitHeight: menuContent.implicitHeight + 28

        Row {
            id: menuContent
            width: parent.width - 28
            anchors.centerIn: parent
            spacing: 16

            Rectangle {
                width: 46
                height: 46
                radius: 18
                color: "#203729"

                Image {
                    width: 22
                    height: 22
                    anchors.centerIn: parent
                    source: menuRoot.iconSource
                    opacity: 0.9
                }
            }

            Column {
                width: parent.width - 96
                spacing: 4

                Text {
                    width: parent.width
                    text: menuRoot.title
                    color: "#F7FBFF"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: menuRoot.subtitle
                    visible: menuRoot.subtitle.length > 0
                    color: "#AEBFA9"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Image {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/images/controls/chevron-right.svg"
                opacity: 0.76
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: menuRoot.clicked()
        }
    }
}
