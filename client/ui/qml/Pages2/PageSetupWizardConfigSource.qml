pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

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
    property string emailText: ""
    property string statusText: ""
    property string toastText: ""
    property string searchText: ""
    property string backendUrlText: AppApiController.baseUrl

    readonly property string pocAuthCode: "TEST123"
    readonly property bool authScreenVisible: !AppApiController.authenticated && !guestMode
    readonly property bool realApiMode: AppApiController.authenticated && !AppApiController.mockMode
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
        color: "#050907"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#0F2D22"
            }
            GradientStop {
                position: 0.42
                color: "#07110D"
            }
            GradientStop {
                position: 1
                color: "#050907"
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
                width: Math.min(parent.width - 48, 440)
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 48
                spacing: 22

                Image {
                    width: Math.min(parent.width, 230)
                    height: 74
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "qrc:/images/loxleyvpnLogoLockup.png"
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        width: parent.width
                        text: "Добро пожаловать"
                        color: "#F4FFF8"
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: "Войдите по email, чтобы получить свои серверы LoxleyVPN."
                        color: "#A8B9AF"
                        font.pixelSize: 15
                        lineHeight: 1.18
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: "Email"
                        color: "#D7E8DE"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    LoxleyTextField {
                        width: parent.width
                        text: root.emailText
                        placeholderText: "name@example.com"
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
                        text: "Продолжая, вы соглашаетесь с правилами сервиса и политикой приватности LoxleyVPN."
                        color: "#7F9389"
                        font.pixelSize: 12
                        lineHeight: 1.18
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    LoxleyButton {
                        width: parent.width
                        text: "Пропустить"
                        secondary: true
                        onClicked: root.enterGuestMode()
                    }
                }

                Text {
                    width: parent.width
                    text: root.statusText
                    visible: text.length > 0
                    color: "#7FF0B4"
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
            contentWidth: width
            contentHeight: pageColumn.implicitHeight + 120
            clip: true
            bottomMargin: 96

            Column {
                id: pageColumn
                width: Math.min(parent.width - 32, 520)
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 30
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
            width: Math.min(parent.width - 32, 520)
            height: 74
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            radius: 26
            color: "#0D1712"
            border.color: "#20382C"
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 8
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
        width: Math.min(parent.width - 40, 420)
        height: Math.max(46, toastMessage.implicitHeight + 24)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 104
        radius: 16
        color: "#17241D"
        border.color: "#31C989"
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
            spacing: 20

            Row {
                width: parent.width
                spacing: 12

                Image {
                    width: 150
                    height: 44
                    source: "qrc:/images/loxleyvpnLogoLockup.png"
                    fillMode: Image.PreserveAspectFit
                }

                Item {
                    width: parent.width - 162
                    height: 44
                }
            }

            Rectangle {
                width: parent.width
                radius: 26
                color: "#0F1D16"
                border.color: "#1F4E3B"
                border.width: 1
                implicitHeight: statusColumn.implicitHeight + 34

                Column {
                    id: statusColumn
                    width: parent.width - 34
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        width: parent.width
                        text: AppApiController.authenticated ? "Профиль активен" : "Гостевой режим"
                        color: "#7FF0B4"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: AppApiController.authenticated ? "Выберите локацию и включите защищённое соединение." : "Войдите в профиль, чтобы включить VPN."
                        color: "#F3FFF7"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        lineHeight: 1.12
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: root.connectionStateLabel()
                        color: "#9CAFA5"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 22
                color: "#0C1511"
                border.color: "#20382C"
                implicitHeight: locationRow.implicitHeight + 30

                Row {
                    id: locationRow
                    width: parent.width - 30
                    anchors.centerIn: parent
                    spacing: 14

                    Rectangle {
                        width: 52
                        height: 52
                        radius: 18
                        color: "#153B2A"

                        Image {
                            width: 25
                            height: 25
                            anchors.centerIn: parent
                            source: "qrc:/images/controls/map-pin.svg"
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.9
                        }
                    }

                    Column {
                        width: parent.width - 160
                        spacing: 4

                        Text {
                            width: parent.width
                            text: root.selectedServer().title || "Выберите локацию"
                            color: "#F3FFF7"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.selectedServerDescription()
                            color: "#94A79D"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    LoxleyChip {
                        width: 86
                        text: "Сменить"
                        onClicked: root.currentTab = root.tabLocations
                    }
                }
            }

            Rectangle {
                width: 188
                height: 188
                anchors.horizontalCenter: parent.horizontalCenter
                radius: width / 2
                color: "#11291F"
                border.color: "#31C989"
                border.width: 2

                Rectangle {
                    width: 136
                    height: 136
                    anchors.centerIn: parent
                    radius: width / 2
                    color: "#22D58E"

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 22
                        text: "VPN"
                        color: "#062014"
                        font.pixelSize: 30
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.connectSelectedServer()
                }
            }

            LoxleyButton {
                width: parent.width
                text: AppApiController.authenticated ? "Включить VPN" : "Войти и включить VPN"
                onClicked: {
                    if (!AppApiController.authenticated) {
                        root.requireAuth()
                    } else {
                        root.connectSelectedServer()
                    }
                }
            }

            LoxleyButton {
                width: parent.width
                text: "Выключить VPN"
                secondary: true
                onClicked: ConnectionController.closeConnection()
            }

            Text {
                width: parent.width
                text: root.statusText
                visible: text.length > 0
                color: "#83E9B2"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Component {
        id: locationsScreen

        Column {
            width: parent.width
            spacing: 18

            ScreenHeader {
                width: parent.width
                title: "Локации"
                subtitle: "Выберите страну для защищённого подключения."
            }

            Row {
                width: parent.width
                spacing: 10

                LoxleyTextField {
                    width: parent.width - 58
                    text: root.searchText
                    placeholderText: "Поиск"
                    onTextChanged: root.searchText = text
                }

                Rectangle {
                    width: 48
                    height: 48
                    radius: 16
                    color: "#13231A"
                    border.color: "#284939"

                    Image {
                        width: 22
                        height: 22
                        anchors.centerIn: parent
                        source: "qrc:/images/controls/settings.svg"
                        opacity: 0.9
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Repeater {
                    model: root.filteredServers()

                    delegate: Rectangle {
                        required property var modelData

                        width: parent.width
                        radius: 20
                        color: root.serverIndexById(modelData.id) === root.selectedServerIndex ? "#173D2D" : "#0D1712"
                        border.color: root.serverIndexById(modelData.id) === root.selectedServerIndex ? "#31C989" : "#20382C"
                        border.width: 1
                        implicitHeight: serverRow.implicitHeight + 28

                        Row {
                            id: serverRow
                            width: parent.width - 28
                            anchors.centerIn: parent
                            spacing: 12

                            Rectangle {
                                width: 46
                                height: 46
                                radius: 16
                                color: "#102C20"

                                Text {
                                    anchors.centerIn: parent
                                    text: root.countryInitial(modelData.country)
                                    color: "#9AF2C2"
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                }
                            }

                            Column {
                                width: parent.width - 146
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    color: "#F3FFF7"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.city + " · " + root.protocolLabel(modelData.protocol)
                                    color: "#95A99E"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            QualityBars {
                                width: 42
                                height: 26
                                quality: modelData.quality || root.qualityForStatus(modelData.status)
                            }

                            Text {
                                width: 42
                                text: modelData.latency || ""
                                color: "#7F9389"
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }
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

    Component {
        id: profileScreen

        Column {
            width: parent.width
            spacing: 18

            ScreenHeader {
                width: parent.width
                title: "Профиль"
                subtitle: AppApiController.authenticated ? "Ваш аккаунт LoxleyVPN подключён." : "Войдите, чтобы включить VPN и управлять подпиской."
            }

            Rectangle {
                width: parent.width
                radius: 24
                color: "#0F1D16"
                border.color: "#20382C"
                implicitHeight: profileColumn.implicitHeight + 34

                Column {
                    id: profileColumn
                    width: parent.width - 34
                    anchors.centerIn: parent
                    spacing: 14

                    Rectangle {
                        width: 76
                        height: 76
                        radius: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#153B2A"

                        Image {
                            width: 34
                            height: 34
                            anchors.centerIn: parent
                            source: AppApiController.authenticated ? "qrc:/images/controls/app.svg" : "qrc:/images/controls/mail.svg"
                            opacity: 0.92
                        }
                    }

                    Text {
                        width: parent.width
                        text: AppApiController.authenticated ? "Профиль активен" : "Вы не авторизованы"
                        color: "#F3FFF7"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: AppApiController.authenticated ? root.subscriptionSummary() : "Гостевой режим позволяет посмотреть приложение, но подключение VPN доступно только после входа."
                        color: "#9CAFA5"
                        font.pixelSize: 14
                        lineHeight: 1.18
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    LoxleyButton {
                        width: parent.width
                        text: AppApiController.authenticated ? "Выйти из профиля" : "Войти в профиль"
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
                subtitle: "Протоколы, исключения и тестовый backend"
                onClicked: root.currentTab = root.tabSettings
            }

            MenuRow {
                width: parent.width
                iconSource: "qrc:/images/controls/help-circle.svg"
                title: "Помощь"
                subtitle: "Инструкции и ответы на частые вопросы"
                onClicked: root.showToast("Раздел помощи появится в следующей версии")
            }

            MenuRow {
                width: parent.width
                iconSource: "qrc:/images/controls/info.svg"
                title: "Спросить"
                subtitle: "Связь с поддержкой LoxleyVPN"
                onClicked: root.showToast("Поддержка будет подключена позже")
            }

            Text {
                width: parent.width
                text: "LoxleyVPN Android PoC"
                color: "#66786F"
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
                        color: index === root.protocolIndex ? "#173D2D" : "#0D1712"
                        border.color: index === root.protocolIndex ? "#31C989" : "#20382C"
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
                                border.color: index === root.protocolIndex ? "#31C989" : "#53685E"
                                border.width: 2

                                Rectangle {
                                    width: 10
                                    height: 10
                                    radius: 5
                                    anchors.centerIn: parent
                                    color: "#31C989"
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
                color: "#0D1712"
                border.color: "#20382C"
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

                    Switch {
                        checked: root.russianBypass
                        onToggled: root.russianBypass = checked
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 20
                color: "#0D1712"
                border.color: "#20382C"
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
        root.statusText = "Гостевой режим"
        root.showToast("VPN доступен после входа в профиль")
    }

    function requireAuth() {
        root.statusText = "Авторизируйтесь для доступа к VPN"
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
        return (server.city || server.country || "Локация") + " · " + root.protocolLabel(server.protocol)
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

    function countryInitial(country) {
        if (!country || country.length === 0) {
            return "VPN"
        }
        return country.substring(0, 1).toUpperCase()
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
        if (ConnectionController.connectionStateText && ConnectionController.connectionStateText.length > 0) {
            return "Статус соединения: " + ConnectionController.connectionStateText
        }
        return "VPN выключен"
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

    component LoxleyButton: Rectangle {
        id: buttonRoot

        property string text: ""
        property bool secondary: false
        property bool enabled: true
        signal clicked()

        height: 52
        radius: 18
        color: secondary ? "#112017" : "#23D58C"
        border.color: secondary ? "#284939" : "#23D58C"
        border.width: 1
        opacity: enabled ? 1 : 0.45

        Text {
            anchors.centerIn: parent
            width: parent.width - 28
            text: buttonRoot.text
            color: buttonRoot.secondary ? "#CDEDDD" : "#061F14"
            font.pixelSize: 15
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
        color: "#153B2A"
        border.color: "#31C989"

        Text {
            anchors.centerIn: parent
            text: chipRoot.text
            color: "#A8F3C9"
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

        height: 50
        radius: 17
        color: "#0B1510"
        border.color: input.activeFocus ? "#31C989" : "#284939"
        border.width: 1

        TextField {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            color: "#F3FFF7"
            placeholderText: fieldRoot.placeholderText
            placeholderTextColor: "#6F8278"
            font.pixelSize: 15
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

        spacing: 6

        Text {
            width: parent.width
            text: headerRoot.title
            color: "#F3FFF7"
            font.pixelSize: 28
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: headerRoot.subtitle
            color: "#9CAFA5"
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

        radius: 20
        color: root.currentTab === tabIndex || (root.currentTab === root.tabSettings && tabIndex === root.tabProfile) ? "#173D2D" : "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 3

            Image {
                width: 22
                height: 22
                anchors.horizontalCenter: parent.horizontalCenter
                source: navRoot.iconSource
                fillMode: Image.PreserveAspectFit
                opacity: root.currentTab === navRoot.tabIndex || (root.currentTab === root.tabSettings && navRoot.tabIndex === root.tabProfile) ? 1 : 0.65
            }

            Text {
                text: navRoot.label
                color: root.currentTab === navRoot.tabIndex || (root.currentTab === root.tabSettings && navRoot.tabIndex === root.tabProfile) ? "#A8F3C9" : "#83968C"
                font.pixelSize: 11
                font.weight: Font.Medium
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
                anchors.bottom: parent.bottom
                color: index < barsRoot.quality ? "#31C989" : "#30463A"
            }
        }
    }

    component MenuRow: Rectangle {
        id: menuRoot

        property string iconSource: ""
        property string title: ""
        property string subtitle: ""
        signal clicked()

        radius: 18
        color: "#0D1712"
        border.color: "#20382C"
        implicitHeight: menuContent.implicitHeight + 24

        Row {
            id: menuContent
            width: parent.width - 26
            anchors.centerIn: parent
            spacing: 12

            Rectangle {
                width: 42
                height: 42
                radius: 14
                color: "#153B2A"

                Image {
                    width: 22
                    height: 22
                    anchors.centerIn: parent
                    source: menuRoot.iconSource
                    opacity: 0.9
                }
            }

            Column {
                width: parent.width - 54
                spacing: 4

                Text {
                    width: parent.width
                    text: menuRoot.title
                    color: "#F3FFF7"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: menuRoot.subtitle
                    color: "#93A79D"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: menuRoot.clicked()
        }
    }
}
