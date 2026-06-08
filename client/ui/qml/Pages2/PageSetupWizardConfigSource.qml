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
    property string authStep: "email"
    property string emailText: ""
    property string pendingEmail: ""
    property string codeText: ""
    property string statusText: ""
    property string toastText: ""
    property string searchText: ""
    property string backendUrlText: AppApiController.baseUrl
    property bool emailError: false
    property bool codeError: false
    property bool codeErrorCleared: false
    property int emailShakeOffset: 0
    property int codeShakeOffset: 0

    readonly property bool authScreenVisible: !AppApiController.authenticated && !guestMode
    readonly property bool realApiMode: AppApiController.authenticated && !AppApiController.mockMode
    readonly property int bottomNavHeight: 66
    readonly property int bottomNavSafeMargin: Math.max(12, PageController.safeAreaBottomMargin + 2)
    readonly property color glassFill: Qt.rgba(1, 1, 1, 0.082)
    readonly property color glassFillStrong: Qt.rgba(1, 1, 1, 0.13)
    readonly property color glassLine: Qt.rgba(0.78, 0.98, 0.62, 0.27)
    readonly property color glassLineStrong: Qt.rgba(0.82, 1, 0.68, 0.45)
    readonly property color loxleyAccent: "#B7F36F"
    readonly property color loxleyAccentSoft: "#8AD56A"
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

    onAuthScreenVisibleChanged: {
        if (root.authScreenVisible) {
            root.resetAuthForm()
            root.statusText = ""
            Qt.callLater(function() {
                authScroll.contentY = 0
            })
        }
    }

    onCurrentTabChanged: {
        Qt.callLater(function() {
            if (!root.authScreenVisible) {
                appScroll.contentY = 0
            }
        })
    }

    Connections {
        target: AppApiController

        function onLoginSucceeded() {
            Qt.inputMethod.hide()
            root.guestMode = false
            root.statusText = "Профиль подключён"
            root.authStep = "email"
            root.codeText = ""
            root.pendingEmail = ""
            root.currentTab = root.tabHome
            AppApiController.fetchMe()
            AppApiController.fetchServers()
        }

        function onLoginFailed(message) {
            if (root.authStep === "code") {
                root.showCodeError(message || "Код неверный или устарел")
            } else {
                root.statusText = message || "Не удалось войти"
            }
        }

        function onEmailCodeRequested(email, message) {
            root.pendingEmail = email && email.length > 0 ? email : root.emailText.trim()
            root.authStep = "code"
            root.codeText = ""
            root.statusText = ""
            root.resetEmailError()
            root.resetCodeError()
            Qt.callLater(function() {
                codeInput.focusInput()
            })
        }

        function onEmailCodeRequestFailed(message) {
            root.statusText = message || "Не удалось отправить код"
            root.emailError = true
            emailShakeAnimation.restart()
            Qt.callLater(function() {
                emailInput.focusInput()
            })
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

    SequentialAnimation {
        id: emailShakeAnimation

        NumberAnimation {
            target: root
            property: "emailShakeOffset"
            to: -8
            duration: 45
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "emailShakeOffset"
            to: 8
            duration: 70
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "emailShakeOffset"
            to: -5
            duration: 60
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "emailShakeOffset"
            to: 0
            duration: 65
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: codeShakeAnimation

        NumberAnimation {
            target: root
            property: "codeShakeOffset"
            to: -8
            duration: 45
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "codeShakeOffset"
            to: 8
            duration: 70
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "codeShakeOffset"
            to: -5
            duration: 60
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "codeShakeOffset"
            to: 0
            duration: 65
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: codeErrorClearTimer
        interval: 650
        repeat: false
        onTriggered: {
            codeInput.clearInput()
            root.codeErrorCleared = true
            codeInput.focusInput()
            codeErrorResetTimer.restart()
        }
    }

    Timer {
        id: codeErrorResetTimer
        interval: 650
        repeat: false
        onTriggered: root.resetCodeError()
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#050807"
            }
            GradientStop {
                position: 0.46
                color: "#0B1511"
            }
            GradientStop {
                position: 1
                color: "#040608"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: 0.42
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "#040607"
            }
            GradientStop {
                position: 0.52
                color: "#113022"
            }
            GradientStop {
                position: 1
                color: "#112B25"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: 0.32
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#203D2E"
            }
            GradientStop {
                position: 0.34
                color: "#0A1411"
            }
            GradientStop {
                position: 1
                color: "#020304"
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height * 0.42
        opacity: 0.18
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#D8FFD1"
            }
            GradientStop {
                position: 1
                color: "#00FFFFFF"
            }
        }
    }

    Item {
        id: authRoot

        anchors.fill: parent
        visible: root.authScreenVisible

        Flickable {
            id: authScroll

            anchors.fill: parent
            anchors.bottomMargin: 100 + PageController.safeAreaBottomMargin
            contentWidth: width
            contentHeight: authColumn.implicitHeight + 56
            interactive: contentHeight > height + 1
            boundsBehavior: interactive ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds
            clip: true

            onContentHeightChanged: {
                if (!interactive) {
                    contentY = 0
                }
            }
            onHeightChanged: {
                if (!interactive) {
                    contentY = 0
                }
            }

            Column {
                id: authColumn
                width: Math.min(parent.width - 60, 440)
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 18 + PageController.safeAreaTopMargin
                spacing: 0

                AppLogoHeader {
                    width: parent.width
                }

                Item {
                    width: parent.width
                    height: 38
                }

                Column {
                    width: parent.width
                    spacing: 12

                    Text {
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.authStep === "code" ? "Введите код" : "Добро пожаловать"
                        color: "#F7FBFF"
                        font.family: "sans-serif-medium"
                        font.pixelSize: 36
                        font.weight: Font.DemiBold
                        lineHeight: 1
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 32
                    }

                    Text {
                        width: parent.width
                        text: root.authStep === "code" ? "Мы отправили 6 цифр на email" : "Войдите или зарегистрируйтесь"
                        color: "#B5C4BB"
                        font.pixelSize: 20
                        lineHeight: 1.18
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 17
                    }
                }

                Item {
                    width: parent.width
                    height: 42
                }

                Column {
                    width: parent.width
                    spacing: 0

                    LoxleyTextField {
                        id: emailInput
                        width: parent.width
                        height: 60
                        x: root.emailShakeOffset
                        visible: root.authStep === "email"
                        text: root.emailText
                        placeholderText: "Введите email"
                        hasError: root.emailError
                        inputMethodHints: Qt.ImhEmailCharactersOnly

                        onTextChanged: {
                            root.emailText = text
                            if (root.emailError && text.trim().length > 0) {
                                root.emailError = false
                            }
                        }
                        onAccepted: root.requestEmailCode()
                    }

                    Column {
                        width: parent.width
                        visible: root.authStep === "code"
                        spacing: 14

                        Text {
                            width: parent.width
                            text: root.pendingEmail
                            color: "#AEBFA9"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                        }

                        LoxleyCodeInput {
                            id: codeInput
                            width: parent.width
                            x: root.codeShakeOffset
                            text: root.codeText
                            hasError: root.codeError
                            errorCleared: root.codeErrorCleared

                            onTextChanged: {
                                root.codeText = text
                                if (root.codeError && text.length > 0) {
                                    root.resetCodeError()
                                }
                            }
                            onAccepted: function(code) {
                                root.verifyEmailCode(code)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 16
                    }

                    LoxleyButton {
                        width: root.authStep === "code" ? Math.min(parent.width, 300) : parent.width
                        height: 60
                        anchors.horizontalCenter: parent.horizontalCenter
                        labelPixelSize: 18
                        text: AppApiController.busy ? (root.authStep === "code" ? "Проверяем..." : "Отправляем код...") : (root.authStep === "code" ? "Войти" : "Продолжить")
                        enabled: !AppApiController.busy
                        onClicked: root.authStep === "code" ? root.verifyEmailCode() : root.requestEmailCode()
                    }

                    Item {
                        width: parent.width
                        height: root.authStep === "code" ? 18 : 0
                        visible: root.authStep === "code"
                    }

                    Text {
                        width: parent.width
                        visible: root.authStep === "code"
                        text: "Изменить email"
                        color: root.loxleyAccent
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.authStep = "email"
                                root.codeText = ""
                                root.resetCodeError()
                                root.statusText = ""
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 24
                    }

                    Text {
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Нажимая «Продолжить», вы соглашаетесь с условиями использования и политикой конфиденциальности LoxleyVPN."
                        color: "#B9C5BE"
                        font.pixelSize: 13
                        lineHeight: 1.18
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
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

        LoxleyButton {
            width: Math.min(parent.width - 96, 158)
            height: 42
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26 + PageController.safeAreaBottomMargin
            text: "Пропустить"
            secondary: true
            labelPixelSize: 14
            onClicked: root.enterGuestMode()
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.authScreenVisible

        Flickable {
            id: appScroll
            anchors.fill: parent
            anchors.topMargin: 34 + PageController.safeAreaTopMargin
            anchors.bottomMargin: root.bottomNavHeight + root.bottomNavSafeMargin
            contentWidth: width
            contentHeight: Math.max(height, pageColumn.implicitHeight)
            interactive: pageColumn.implicitHeight > height + 1
            boundsBehavior: interactive ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds
            clip: true

            onContentHeightChanged: {
                if (!interactive) {
                    contentY = 0
                }
            }
            onHeightChanged: {
                if (!interactive) {
                    contentY = 0
                }
            }

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
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#101A15"
                }
                GradientStop {
                    position: 1
                    color: "#07100D"
                }
            }
            border.color: "transparent"
            border.width: 0

            Rectangle {
                width: parent.width
                height: 1
                anchors.top: parent.top
                color: Qt.rgba(0.78, 0.98, 0.62, 0.13)
            }

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
                color: root.glassFillStrong
                opacity: 0.96
                border.color: root.glassLineStrong
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
                height: 68
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
                width: Math.min(parent.width - 54, 344)
                anchors.horizontalCenter: parent.horizontalCenter
                connected: ConnectionController.isConnected
                busy: ConnectionController.isConnectionInProgress
                onClicked: root.toggleSelectedServer()
            }

                Text {
                    width: parent.width
                    text: "При первом подключении устройство запросит разрешение на VPN-соединение."
                    visible: AppApiController.authenticated
                    color: "#AABBB0"
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

            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: parent.width - 64
                    height: 44
                    radius: 22
                    color: root.glassFill
                    border.color: searchInput.activeFocus ? root.glassLineStrong : root.glassLine
                    border.width: 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                    }

                    Image {
                        width: 18
                        height: 18
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/images/controls/search.svg"
                        opacity: 0.58
                    }

                    TextField {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 48
                        anchors.rightMargin: 16
                        text: root.searchText
                        placeholderText: "Поиск"
                        placeholderTextColor: "#9AAFA0"
                        color: "#F7FBFF"
                        font.pixelSize: 15
                        background: null
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.searchText = text
                    }
                }

                Rectangle {
                    width: 54
                    height: 44
                    radius: 22
                    color: root.glassFill
                    border.color: root.glassLine
                    border.width: 1
                    opacity: sortTap.pressed ? 0.76 : 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                    }

                    SortGlyph {
                        anchors.centerIn: parent
                        width: 23
                        height: 25
                        ascending: root.sortAscending
                    }

                    MouseArea {
                        id: sortTap
                        anchors.fill: parent
                        onClicked: root.sortAscending = !root.sortAscending
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 24
                color: root.glassFill
                border.color: Qt.rgba(1, 1, 1, 0.075)
                border.width: 1
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
                                    color: root.serverIndexById(modelData.id) === root.selectedServerIndex ? root.loxleyAccent : "#F7FBFF"
                                    font.family: "sans-serif-medium"
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
                                            color: "#AABBB0"
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

                    Item {
                        width: parent.width
                        height: 118
                        visible: root.filteredServers().length === 0

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            text: AppApiController.authenticated ? "Локации пока недоступны" : "Войдите, чтобы увидеть локации"
                            color: "#B4C3B9"
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    Component {
        id: profileScreen

            Column {
                id: profileRoot

                width: parent.width
                spacing: 16

                Text {
                    id: profileTitle

                    width: parent.width
                    text: "Профиль"
                    color: "#F7FBFF"
                    font.family: "sans-serif-medium"
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 30
                }

                Item {
                    id: profileHero

                    width: parent.width
                    height: 304

                    Column {
                        id: profileColumn
                        width: parent.width
                        anchors.centerIn: parent
                        spacing: 16

                        Rectangle {
                            width: 108
                            height: 108
                            radius: 54
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Qt.rgba(0.72, 0.95, 0.42, 0.09)
                            border.color: Qt.rgba(0.78, 0.98, 0.62, 0.28)
                            border.width: 1

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                radius: parent.radius - 5
                                color: "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.07)
                                border.width: 1
                            }

                            ShieldAvatarGlyph {
                                width: 66
                                height: 72
                                anchors.centerIn: parent
                                color: root.loxleyAccent
                                mutedColor: "#DCEED2"
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 8

                            Text {
                                width: parent.width
                                text: AppApiController.authenticated ? "Профиль активен" : "Вы не авторизованы"
                                color: "#F7FBFF"
                                font.family: "sans-serif-medium"
                                font.pixelSize: 29
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 25
                            }

                            Text {
                                width: Math.min(parent.width - 24, 430)
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: AppApiController.authenticated ? root.subscriptionSummary() : "Войдите, чтобы управлять подпиской и подключением"
                                color: "#AFC1B2"
                                font.pixelSize: 16
                                lineHeight: 1.18
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }

                    LoxleyButton {
                        width: Math.max(240, Math.min(parent.width * 0.76, 332))
                        height: 60
                        anchors.horizontalCenter: parent.horizontalCenter
                        labelPixelSize: 18
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
                id: profileSettingsRow

                width: parent.width
                iconSource: "qrc:/images/controls/settings-2.svg"
                title: "Настройки"
                subtitle: ""
                onClicked: root.currentTab = root.tabSettings
            }

            MenuRow {
                id: profileHelpRow

                width: parent.width
                iconSource: "qrc:/images/controls/help-circle.svg"
                title: "Справочный центр"
                subtitle: ""
                onClicked: root.showToast("Раздел помощи появится в следующей версии")
            }

            Item {
                width: parent.width
                height: Math.max(30, appScroll.height - profileTitle.implicitHeight - profileHero.height - profileSettingsRow.implicitHeight - profileHelpRow.implicitHeight - versionLabel.implicitHeight - profileRoot.spacing * 5 - 24)
            }

            Text {
                id: versionLabel

                width: parent.width
                text: "v0.1"
                color: "#6F8174"
                font.pixelSize: 11
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
                        color: index === root.protocolIndex ? Qt.rgba(0.72, 0.95, 0.42, 0.15) : root.glassFill
                        border.color: index === root.protocolIndex ? root.glassLineStrong : Qt.rgba(1, 1, 1, 0.06)
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
                                border.color: index === root.protocolIndex ? root.loxleyAccent : "#7A8B78"
                                border.width: 2

                                Rectangle {
                                    width: 10
                                    height: 10
                                    radius: 5
                                    anchors.centerIn: parent
                                    color: root.loxleyAccent
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
                color: root.glassFill
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
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
                color: root.glassFill
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
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

    function requestEmailCode() {
        var trimmedEmail = root.emailText.trim()
        if (trimmedEmail.length === 0 || !root.isValidEmail(trimmedEmail)) {
            root.emailError = true
            root.statusText = ""
            emailInput.focusInput()
            emailShakeAnimation.restart()
            return
        }

        root.emailError = false
        root.resetCodeError()
        if (root.backendUrlText.trim().length > 0) {
            AppApiController.baseUrl = root.backendUrlText.trim()
        }

        root.pendingEmail = trimmedEmail
        root.statusText = "Отправляем код"
        AppApiController.requestEmailCode(trimmedEmail, AppApiController.deviceUuid, "Android", "android")
    }

    function verifyEmailCode(codeValue) {
        if (AppApiController.busy) {
            return
        }

        var sourceCode = codeValue === undefined ? root.codeText : codeValue
        var trimmedCode = sourceCode.replace(/\D/g, "")
        if (trimmedCode.length !== 6) {
            root.showCodeError("Введите 6 цифр", false)
            return
        }

        root.codeError = false
        root.statusText = "Проверяем код"
        AppApiController.verifyEmailCode(root.pendingEmail || root.emailText.trim(), trimmedCode, AppApiController.deviceUuid, "Android", "android")
    }

    function showCodeError(message, clearAfterShake) {
        if (clearAfterShake === undefined) {
            clearAfterShake = true
        }

        codeErrorClearTimer.stop()
        codeErrorResetTimer.stop()
        root.statusText = message || "Код неверный или устарел"
        root.codeError = true
        root.codeErrorCleared = false
        codeShakeAnimation.restart()
        codeInput.focusInput()

        if (clearAfterShake) {
            codeErrorClearTimer.restart()
        }
    }

    function isValidEmail(value) {
        var email = value.trim()
        if (email.length < 6 || email.length > 320 || email.indexOf(" ") !== -1) {
            return false
        }
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    }

    function enterGuestMode() {
        root.guestMode = true
        root.currentTab = root.tabHome
        root.statusText = ""
        root.resetAuthForm()
    }

    function requireAuth() {
        root.statusText = "Авторизуйтесь для доступа к VPN"
        root.showToast(root.statusText)
        root.guestMode = false
    }

    function requireActiveSubscription() {
        root.statusText = "Подписка не активна"
        root.showToast("Оформите доступ на сайте LoxleyVPN или в Telegram-боте")
        root.currentTab = root.tabProfile
    }

    function resetEmailError() {
        root.emailError = false
        root.emailShakeOffset = 0
        emailShakeAnimation.stop()
    }

    function resetCodeError() {
        root.codeError = false
        root.codeErrorCleared = false
        root.codeShakeOffset = 0
        codeErrorClearTimer.stop()
        codeErrorResetTimer.stop()
        codeShakeAnimation.stop()
    }

    function resetAuthForm() {
        root.authStep = "email"
        root.codeText = ""
        root.pendingEmail = ""
        root.resetEmailError()
        root.resetCodeError()
    }

    function currentServers() {
        if (AppApiController.authenticated && AppApiController.servers && AppApiController.servers.length > 0) {
            return AppApiController.servers
        }
        if (AppApiController.mockMode) {
            return root.fallbackServers
        }
        return []
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
            return "Подписка не активна"
        }
        var user = AppApiController.user || {}
        var email = user.email || ""
        var status = user.subscription_status || "inactive"
        var canConnect = user.can_connect === true || user.can_connect === "true"
        var prefix = email.length > 0 ? email + " · " : ""
        if (!canConnect) {
            return prefix + "подписка не активна"
        }
        if (user.expires_at && user.expires_at.length > 0) {
            return prefix + "активна до " + root.shortDate(user.expires_at)
        }
        if (status === "active") {
            return prefix + "подписка активна"
        }
        return prefix + status
    }

    function shortDate(value) {
        var date = new Date(value)
        if (isNaN(date.getTime())) {
            return value
        }
        return Qt.formatDate(date, "dd.MM.yyyy")
    }

    function appUserCanConnect() {
        if (!AppApiController.authenticated) {
            return false
        }
        if (!AppApiController.user || AppApiController.user.can_connect === undefined) {
            return true
        }
        return AppApiController.user.can_connect === true || AppApiController.user.can_connect === "true"
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

        if (!root.appUserCanConnect()) {
            root.requireActiveSubscription()
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

        if (!root.appUserCanConnect()) {
            root.requireActiveSubscription()
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
        height: 88

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 88
            height: 88
            source: "qrc:/images/loxleyvpnLogoLockup.png"
            sourceClipRect: Qt.rect(0, 0, 300, 310)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    component VpnToggle: Rectangle {
        id: vpnToggleRoot

        property bool connected: false
        property bool busy: false
        signal clicked()

        height: 82
        radius: height / 2
        color: "transparent"
        border.color: connected ? Qt.rgba(0.75, 1, 0.54, 0.62) : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Rectangle {
            id: toggleGlow
            anchors.centerIn: parent
            width: parent.width + 18
            height: parent.height + 18
            radius: height / 2
            color: vpnToggleRoot.connected ? Qt.rgba(0.54, 0.94, 0.45, 0.22) : Qt.rgba(1, 1, 1, 0.04)
            opacity: vpnToggleRoot.busy ? 0.74 : (vpnToggleRoot.connected ? 0.48 : 0.2)
        }

        SequentialAnimation {
            running: vpnToggleRoot.busy
            loops: Animation.Infinite

            NumberAnimation {
                target: toggleGlow
                property: "opacity"
                to: 0.28
                duration: 520
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: toggleGlow
                property: "opacity"
                to: 0.78
                duration: 620
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: vpnToggleRoot.connected ? "#8BE35A" : "#182119"
                }
                GradientStop {
                    position: 0.52
                    color: vpnToggleRoot.connected ? "#B7F36F" : "#2B3D2D"
                }
                GradientStop {
                    position: 1
                    color: vpnToggleRoot.connected ? "#1B361F" : "#121712"
                }
            }
            opacity: vpnToggleRoot.connected ? 0.96 : 0.9
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: Qt.rgba(1, 1, 1, 0.045)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
        }

        Rectangle {
            id: toggleThumb
            width: 66
            height: 66
            radius: 33
            anchors.verticalCenter: parent.verticalCenter
            x: vpnToggleRoot.connected ? vpnToggleRoot.width - width - 8 : 8
            scale: vpnToggleRoot.busy ? 0.94 : 1
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: vpnToggleRoot.connected ? "#F0FFD8" : "#ECF4EA"
                }
                GradientStop {
                    position: 1
                    color: vpnToggleRoot.connected ? "#A6F46A" : "#AEB9AB"
                }
            }
            border.color: Qt.rgba(1, 1, 1, 0.48)
            border.width: 1

            Behavior on x {
                NumberAnimation {
                    duration: 230
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutQuad
                }
            }

            PowerGlyph {
                width: 31
                height: 31
                anchors.centerIn: parent
                color: vpnToggleRoot.connected ? "#183318" : "#27302B"
                strokeWidth: 3
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: vpnToggleRoot.connected ? parent.left : toggleThumb.right
            anchors.right: vpnToggleRoot.connected ? toggleThumb.left : parent.right
            anchors.leftMargin: vpnToggleRoot.connected ? 24 : 18
            anchors.rightMargin: vpnToggleRoot.connected ? 18 : 24
            text: vpnToggleRoot.busy ? "Запускаем защиту" : (vpnToggleRoot.connected ? "Защита включена" : "Включить защиту")
            color: vpnToggleRoot.connected ? "#10210E" : "#F3FFF7"
            font.family: "sans-serif-medium"
            font.pixelSize: 17
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
        color: checked ? Qt.rgba(0.72, 0.95, 0.42, 0.34) : Qt.rgba(1, 1, 1, 0.08)
        border.color: checked ? root.glassLineStrong : root.glassLine
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
            color: miniToggleRoot.checked ? root.loxleyAccent : "#B8C9B3"

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

            var size = Math.min(width, height)
            var centerX = width / 2
            var centerY = height / 2 + size * 0.06
            var radius = size * 0.31

            ctx.strokeStyle = powerGlyphRoot.color
            ctx.lineWidth = powerGlyphRoot.strokeWidth
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, Math.PI * -0.25, Math.PI * 1.25)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(centerX, size * 0.12)
            ctx.lineTo(centerX, centerY - radius * 0.28)
            ctx.stroke()
        }
    }

    component SortGlyph: Canvas {
        id: sortGlyphRoot

        property bool ascending: true
        property color activeColor: root.loxleyAccent
        property color inactiveColor: "#9AAFA0"

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

    component ShieldAvatarGlyph: Canvas {
        id: shieldAvatarRoot

        property color color: "#DCEED2"
        property color mutedColor: "#DCEED2"

        onColorChanged: requestPaint()
        onMutedColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var size = Math.min(width, height)
            var cx = width / 2
            var top = height * 0.08
            var shieldW = size * 0.78
            var left = cx - shieldW / 2
            var right = cx + shieldW / 2
            var bottom = height * 0.86

            ctx.lineWidth = Math.max(2.4, size * 0.046)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            ctx.globalAlpha = 0.18
            ctx.fillStyle = shieldAvatarRoot.color
            ctx.beginPath()
            ctx.moveTo(cx, top)
            ctx.quadraticCurveTo(right, top + size * 0.10, right - size * 0.04, top + size * 0.40)
            ctx.quadraticCurveTo(right - size * 0.07, bottom - size * 0.12, cx, bottom)
            ctx.quadraticCurveTo(left + size * 0.07, bottom - size * 0.12, left + size * 0.04, top + size * 0.40)
            ctx.quadraticCurveTo(left, top + size * 0.10, cx, top)
            ctx.fill()

            ctx.globalAlpha = 1
            ctx.strokeStyle = shieldAvatarRoot.color
            ctx.beginPath()
            ctx.moveTo(cx, top)
            ctx.quadraticCurveTo(right, top + size * 0.10, right - size * 0.04, top + size * 0.40)
            ctx.quadraticCurveTo(right - size * 0.07, bottom - size * 0.12, cx, bottom)
            ctx.quadraticCurveTo(left + size * 0.07, bottom - size * 0.12, left + size * 0.04, top + size * 0.40)
            ctx.quadraticCurveTo(left, top + size * 0.10, cx, top)
            ctx.stroke()

            ctx.strokeStyle = shieldAvatarRoot.mutedColor
            ctx.lineWidth = Math.max(2.2, size * 0.042)

            ctx.beginPath()
            ctx.arc(cx, height * 0.42, size * 0.13, 0, Math.PI * 2)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(cx - size * 0.24, height * 0.68)
            ctx.quadraticCurveTo(cx, height * 0.53, cx + size * 0.24, height * 0.68)
            ctx.stroke()

            ctx.strokeStyle = shieldAvatarRoot.color
            ctx.lineWidth = Math.max(2, size * 0.036)
            ctx.beginPath()
            ctx.moveTo(cx, height * 0.20)
            ctx.lineTo(cx, height * 0.27)
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
            sourceSize.width: width * 4
            sourceSize.height: height * 4
            source: root.flagSource(flagBadgeRoot.server)
            fillMode: Image.PreserveAspectCrop
            mipmap: true
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
        property int labelPixelSize: secondary ? 18 : 19
        signal clicked()

        height: 58
        radius: height / 2
        color: secondary ? Qt.rgba(1, 1, 1, 0.035) : "#78DC72"
        border.color: secondary ? Qt.rgba(0.70, 0.90, 0.55, 0.44) : "#9BEA79"
        border.width: 1
        opacity: enabled ? 1 : 0.45

        Text {
            anchors.centerIn: parent
            width: parent.width - 28
            text: buttonRoot.text
            color: buttonRoot.secondary ? "#CDEFB0" : "#06140A"
            font.family: "sans-serif"
            font.pixelSize: buttonRoot.labelPixelSize
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
        property bool hasError: false
        signal accepted()

        height: 58
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.062)
        border.color: hasError ? Qt.rgba(1, 0.33, 0.34, 0.68) : (input.activeFocus ? Qt.rgba(0.70, 0.92, 0.55, 0.52) : Qt.rgba(0.70, 0.90, 0.55, 0.26))
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.color: fieldRoot.hasError ? Qt.rgba(1, 0.45, 0.45, 0.24) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }

        TextField {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            color: "#F7FBFF"
            placeholderText: fieldRoot.placeholderText
            placeholderTextColor: fieldRoot.hasError ? "#FF8588" : "#9EAF9B"
            font.family: "sans-serif"
            font.pixelSize: 17
            font.weight: Font.Normal
            inputMethodHints: fieldRoot.inputMethodHints
            background: null
            verticalAlignment: TextInput.AlignVCenter
            onAccepted: fieldRoot.accepted()
        }

        function focusInput() {
            input.forceActiveFocus()
            Qt.inputMethod.show()
        }
    }

    component LoxleyCodeInput: Item {
        id: codeRoot

        property alias text: hiddenInput.text
        property bool hasError: false
        property bool errorCleared: false
        property bool submittedFullCode: false
        signal accepted(string code)

        height: 58

        Row {
            anchors.fill: parent
            spacing: 8

            Repeater {
                model: 6

                Rectangle {
                    required property int index

                    width: (codeRoot.width - 40) / 6
                    height: codeRoot.height
                    radius: 17
                    color: codeRoot.hasError && !codeRoot.errorCleared ? Qt.rgba(1, 0.28, 0.30, 0.88) : Qt.rgba(1, 1, 1, 0.062)
                    border.color: codeRoot.hasError ? Qt.rgba(1, 0.33, 0.34, 0.68) : (hiddenInput.activeFocus ? Qt.rgba(0.70, 0.92, 0.55, 0.52) : Qt.rgba(0.70, 0.90, 0.55, 0.26))
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: hiddenInput.text.length > index ? hiddenInput.text.charAt(index) : ""
                        color: "#F7FBFF"
                        font.family: "sans-serif-medium"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }
            }
        }

        TextInput {
            id: hiddenInput
            anchors.fill: parent
            opacity: 0.01
            color: "transparent"
            cursorVisible: false
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: 6
            validator: RegularExpressionValidator {
                regularExpression: /^[0-9]*$/
            }
            onAccepted: {
                if (text.length === 6 && !codeRoot.submittedFullCode) {
                    codeRoot.submittedFullCode = true
                    codeRoot.accepted(text)
                }
            }
            onTextChanged: {
                var sanitized = text.replace(/\D/g, "").slice(0, 6)
                if (text !== sanitized) {
                    text = sanitized
                    return
                }

                if (text.length < 6) {
                    codeRoot.submittedFullCode = false
                }

                if (text.length === 6 && !codeRoot.submittedFullCode) {
                    codeRoot.submittedFullCode = true
                    codeRoot.accepted(text)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: codeRoot.focusInput()
        }

        function focusInput() {
            hiddenInput.forceActiveFocus()
            Qt.inputMethod.show()
        }

        function clearInput() {
            codeRoot.submittedFullCode = false
            hiddenInput.clear()
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
            font.pixelSize: 30
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
        readonly property bool active: root.currentTab === navRoot.tabIndex || (root.currentTab === root.tabSettings && navRoot.tabIndex === root.tabProfile)

        radius: 0
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 2

            Item {
                width: 23
                height: 23
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    id: navIcon

                    anchors.fill: parent
                    source: navRoot.iconSource
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: parent
                    source: navIcon
                    color: navRoot.active ? root.loxleyAccent : "#7E8F82"
                    opacity: navRoot.active ? 1 : 0.78
                }
            }

            Text {
                text: navRoot.label
                color: navRoot.active ? "#F3FFF7" : "#91A095"
                font.pixelSize: 14
                font.weight: navRoot.active ? Font.DemiBold : Font.Normal
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
                color: index < barsRoot.quality ? root.loxleyAccent : "#4E5F53"
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
        color: Qt.rgba(1, 1, 1, 0.074)
        border.color: Qt.rgba(1, 1, 1, 0.075)
        border.width: 1
        implicitHeight: 78

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(0.78, 0.98, 0.62, 0.08)
            border.width: 1
        }

        Row {
            id: menuContent
            width: parent.width - 32
            anchors.centerIn: parent
            spacing: 16

            Rectangle {
                width: 46
                height: 46
                radius: 17
                color: Qt.rgba(0.72, 0.95, 0.42, 0.10)
                border.color: Qt.rgba(0.78, 0.98, 0.62, 0.20)
                border.width: 1

                Image {
                    id: menuIcon

                    width: 21
                    height: 21
                    anchors.centerIn: parent
                    source: menuRoot.iconSource
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: menuIcon
                    source: menuIcon
                    color: "#D4EBC8"
                    opacity: 0.9
                }
            }

            Column {
                width: parent.width - 98
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: menuRoot.title
                    color: "#F7FBFF"
                    font.family: "sans-serif-medium"
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

            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: menuChevron

                    anchors.fill: parent
                    source: "qrc:/images/controls/chevron-right.svg"
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: parent
                    source: menuChevron
                    color: "#849287"
                    opacity: 0.58
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: menuRoot.clicked()
        }
    }
}
