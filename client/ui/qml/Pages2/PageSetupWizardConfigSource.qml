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

    property bool guestMode: false
    property bool russianBypass: IpSplitTunnelingController.russianServicesBypassEnabled
    property bool sortAscending: true
    property string authStep: "email"
    property string emailText: ""
    property string pendingEmail: ""
    property string codeText: ""
    property string statusText: ""
    property string toastText: ""
    property bool toastIsError: false
    property string accountBlockTitle: ""
    property string accountBlockMessage: ""
    property bool accountBlockVisible: false
    property string searchText: ""
    property string backendUrlText: AppApiController.baseUrl
    property bool emailError: false
    property bool codeError: false
    property bool codeErrorCleared: false
    property int emailShakeOffset: 0
    property int codeShakeOffset: 0
    property bool profileMenuOpen: false
    property bool vpnActionPending: false
    property bool vpnObservedConnectionProgress: false
    property string vpnActionText: ""
    property var pendingVpnAction: null

    readonly property bool authScreenVisible: !AppApiController.authenticated && !guestMode
    readonly property bool realApiMode: AppApiController.authenticated && !AppApiController.mockMode
    readonly property bool vpnBusy: vpnActionPending || ConnectionController.isConnectionInProgress
    readonly property int bottomNavHeight: Qt.platform.os === "android" ? 58 : 66
    readonly property int topSafeMargin: Qt.platform.os === "ios" ? Math.max(PageController.safeAreaTopMargin, 44) : (Qt.platform.os === "android" ? Math.max(PageController.safeAreaTopMargin, 34) : PageController.safeAreaTopMargin)
    readonly property int bottomNavSafeMargin: Qt.platform.os === "ios" ? Math.max(10, PageController.safeAreaBottomMargin + 2) : (Qt.platform.os === "android" ? Math.max(PageController.safeAreaBottomMargin, 48) : 8)
    readonly property color glassFill: Qt.rgba(1, 1, 1, 0.082)
    readonly property color glassFillStrong: Qt.rgba(1, 1, 1, 0.13)
    readonly property color glassLine: Qt.rgba(0.78, 0.98, 0.62, 0.27)
    readonly property color glassLineStrong: Qt.rgba(0.82, 1, 0.68, 0.45)
    readonly property color guardoAccent: "#B7F36F"
    readonly property color guardoAccentSoft: "#8AD56A"
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
            root.refreshServersIfNeeded()
        })
    }

    Component.onCompleted: Qt.callLater(function() {
        if (AppApiController.authenticated) {
            root.guestMode = false
            AppApiController.fetchMe()
            AppApiController.fetchServers()
        }
        root.refreshServersIfNeeded()
    })

    Connections {
        target: AppApiController

        function onLoginSucceeded() {
            Qt.inputMethod.hide()
            if (Qt.platform.os === "ios") {
                AppApiController.setOneTimeCodeAutofillActive(false)
            }
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
            if (root.isAccountBlockingMessage(message || "")) {
                root.resetCodeError()
                root.showAccountBlock(message || "Вход сейчас недоступен")
                return
            }

            if (root.authStep === "code") {
                root.showCodeError(message || "Код неверный или устарел")
            } else {
                root.statusText = message || "Не удалось войти"
                root.showToast(root.statusText, true)
            }
        }

        function onAuthenticatedChanged() {
            if (AppApiController.authenticated) {
                root.guestMode = false
                AppApiController.fetchMe()
                AppApiController.fetchServers()
            } else {
                root.profileMenuOpen = false
            }
            root.refreshServersIfNeeded()
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

        function onOneTimeCodeReceived(code) {
            if (root.authStep !== "code") {
                return
            }

            var digits = (code || "").replace(/\D/g, "").slice(0, 6)
            if (digits.length === 0) {
                return
            }

            root.codeText = digits
        }

        function onEmailCodeRequestFailed(message) {
            root.statusText = message || "Не удалось отправить код"
            root.emailError = true
            root.showToast(root.statusText, true)
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
            if (!root.authScreenVisible) {
                root.showToast(root.statusText)
            }
        }

        function onServersFailed(message) {
            root.statusText = message || "Ошибка запроса"
            if (!root.authScreenVisible) {
                root.showToast(root.statusText)
            }
        }

        function onConfigFetched(serverId, protocol, config, fakeConfig) {
            if (fakeConfig) {
                root.finishVpnAction()
                root.statusText = "Тестовый сервер доступен. Реальный туннель не создаётся."
                root.showToast(root.statusText)
                return
            }

            var server = root.serverById(serverId)
            root.statusText = "Конфигурация получена"
            root.importAndConnectConfig(config, server.title || "GuardoVPN")
        }

        function onConfigFailed(serverId, message, statusCode) {
            root.finishVpnAction()
            if (statusCode === 501) {
                root.statusText = "Резервный протокол пока не включён"
            } else {
                root.statusText = message || "Не удалось получить конфигурацию"
            }
            root.showToast(root.statusText)
        }

        function onAccountLinkFailed(message) {
            root.showToast(message || "Не удалось открыть кабинет")
        }
    }

    Connections {
        target: ImportController

        function onImportErrorOccurred(errorCode, unusedHomeRedirect) {
            root.finishVpnAction()
            root.statusText = "Ошибка импорта конфигурации"
            root.showToast(root.statusText)
        }

        function onImportFinished() {
            root.statusText = "Профиль VPN готов"
        }
    }

    Connections {
        target: ConnectionController

        function onConnectionStateChanged() {
            if (ConnectionController.isConnected) {
                root.finishVpnAction()
            } else if (ConnectionController.isConnectionInProgress) {
                root.vpnObservedConnectionProgress = true
                root.vpnActionPending = false
                vpnPendingFallbackTimer.stop()
            } else if (root.vpnObservedConnectionProgress) {
                root.finishVpnAction()
            }
        }

        function onConnectionErrorOccurred(errorCode) {
            root.finishVpnAction()
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
            anchors.bottomMargin: Math.max(100 + PageController.safeAreaBottomMargin, PageController.imeHeight > 0 ? PageController.imeHeight + 12 : 0)
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
                topPadding: 18 + root.topSafeMargin
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
                    height: root.authStep === "code" ? 22 : 28
                }

                Column {
                    width: parent.width
                    spacing: 0

                    GuardoTextField {
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

                        GuardoCodeInput {
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

                    GuardoButton {
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
                        color: root.guardoAccent
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter

                        MouseArea {
                            anchors.fill: parent
                        onClicked: {
                            if (Qt.platform.os === "ios") {
                                AppApiController.setOneTimeCodeAutofillActive(false)
                            }
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
                        text: "Нажимая «Продолжить», вы соглашаетесь с условиями использования и политикой конфиденциальности GuardoVPN."
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
                    visible: false
                    color: "#BDEB7B"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        GuardoButton {
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
        visible: root.accountBlockVisible
        z: 90

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.48)
        }

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            width: Math.min(parent.width - 42, 390)
            anchors.centerIn: parent
            radius: 28
            color: Qt.rgba(0.08, 0.13, 0.10, 0.94)
            border.color: root.glassLineStrong
            border.width: 1
            implicitHeight: accountBlockContent.implicitHeight + 36

            Column {
                id: accountBlockContent
                width: parent.width - 36
                anchors.centerIn: parent
                spacing: 16

                Rectangle {
                    width: 48
                    height: 48
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 24
                    color: Qt.rgba(0.72, 0.95, 0.44, 0.14)
                    border.color: root.guardoAccent
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        color: root.guardoAccent
                        font.pixelSize: 25
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    width: parent.width
                    text: root.accountBlockTitle
                    color: "#F4FFF6"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: root.accountBlockMessage
                    color: "#B9C8BF"
                    font.pixelSize: 14
                    lineHeight: 1.2
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                GuardoButton {
                    width: Math.min(parent.width, 260)
                    height: 48
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Изменить email"
                    labelPixelSize: 15
                    onClicked: {
                        root.accountBlockVisible = false
                        root.resetAuthForm()
                        root.statusText = ""
                        Qt.callLater(function() {
                            emailInput.focusInput()
                        })
                    }
                }

                Text {
                    width: parent.width
                    text: "Понятно"
                    color: root.guardoAccent
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.accountBlockVisible = false
                    }
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
            anchors.topMargin: 34 + root.topSafeMargin
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
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.bottomNavSafeMargin
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
        readonly property bool showAtTop: root.authScreenVisible

        width: Math.min(parent.width - 38, 440)
        height: Math.max(58, toastMessage.implicitHeight + 28)
        anchors.horizontalCenter: parent.horizontalCenter
        y: showAtTop ? root.topSafeMargin + 12 : parent.height - height - root.bottomNavHeight - root.bottomNavSafeMargin - 12
        radius: 18
        color: root.toastIsError ? Qt.rgba(0.38, 0.10, 0.11, 0.96) : "#2E6F4E"
        border.color: root.toastIsError ? Qt.rgba(1, 0.43, 0.45, 0.58) : "#87C86C"
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
            color: root.toastIsError ? "#FFE4E5" : "#E9FFF1"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Popup {
        id: deleteProfileConfirmPopup

        parent: Overlay.overlay
        width: Math.min(336, parent.width - 32)
        height: deleteProfileConfirmCard.implicitHeight
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        Overlay.modal: Rectangle {
            color: Qt.rgba(0.01, 0.03, 0.02, 0.62)
        }

        background: Rectangle {
            id: deleteProfileConfirmCard

            radius: 24
            color: Qt.rgba(0.11, 0.16, 0.15, 0.97)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            implicitHeight: confirmDeleteContent.implicitHeight + 28

            Column {
                id: confirmDeleteContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 14

                Rectangle {
                    width: 50
                    height: 50
                    radius: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(0.42, 0.14, 0.16, 0.26)
                    border.color: Qt.rgba(1, 0.45, 0.47, 0.18)
                    border.width: 1

                    Image {
                        id: deleteProfileConfirmIcon

                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        source: "qrc:/images/controls/trash.svg"
                        visible: false
                    }

                    ColorOverlay {
                        anchors.fill: deleteProfileConfirmIcon
                        source: deleteProfileConfirmIcon
                        color: "#FF8A8D"
                        opacity: 0.96
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width
                        text: "Удалить профиль?"
                        color: "#F7FBFF"
                        font.family: "sans-serif-medium"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: "Профиль удаляется только в личном кабинете. После подтверждения откроем нужный раздел на сайте."
                        color: "#B7C8BF"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: 48
                        radius: 16
                        color: confirmDeleteCancelTap.pressed ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(0.70, 0.90, 0.55, 0.26)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Нет"
                            color: "#D8E8DD"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: confirmDeleteCancelTap

                            anchors.fill: parent
                            onClicked: deleteProfileConfirmPopup.close()
                        }
                    }

                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: 48
                        radius: 16
                        color: confirmDeleteAcceptTap.pressed ? Qt.rgba(0.34, 0.11, 0.13, 0.96) : Qt.rgba(0.22, 0.08, 0.10, 0.92)
                        border.color: Qt.rgba(1, 0.47, 0.49, 0.26)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Да"
                            color: "#FF9EA0"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: confirmDeleteAcceptTap

                            anchors.fill: parent
                            onClicked: {
                                deleteProfileConfirmPopup.close()
                                root.confirmDeleteProfile()
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 3200
    }

    Timer {
        id: vpnPendingFallbackTimer

        interval: 30000
        repeat: false
        onTriggered: {
            if (!ConnectionController.isConnected && !ConnectionController.isConnectionInProgress && root.vpnActionPending) {
                root.finishVpnAction()
                root.statusText = "VPN не запустился"
                root.showToast("Попробуйте подключиться ещё раз")
            }
        }
    }

    Timer {
        id: vpnActionStartTimer

        interval: 90
        repeat: false
        onTriggered: {
            var action = root.pendingVpnAction
            root.pendingVpnAction = null
            if (action) {
                action()
            }
        }
    }

    Component {
        id: homeScreen

        Column {
            id: homeColumn

            width: parent.width
            spacing: 12

            Column {
                id: homeMainContent

                width: parent.width
                spacing: homeColumn.spacing

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
                    radius: 26
                    color: root.glassFillStrong
                    opacity: 0.96
                    border.color: root.glassLineStrong
                    border.width: 1
                    implicitHeight: locationRow.implicitHeight + 24

                    Row {
                        id: locationRow
                        width: parent.width - 30
                        anchors.centerIn: parent
                        spacing: 14

                        FlagBadge {
                            width: 46
                            height: 46
                            server: root.selectedServer()
                        }

                        Column {
                            width: parent.width - 60
                            spacing: 4

                            Text {
                                width: parent.width
                                text: "Выбранная локация"
                                color: "#C5D7BF"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.serverDisplayTitle(root.selectedServer())
                                color: "#F7FBFF"
                                font.pixelSize: 20
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
                    height: Math.max(84, Math.min(136, appScroll.height * 0.15))
                }

                Text {
                    width: parent.width
                    text: ConnectionController.isConnected ? "Вы подключены" : "Вы не подключены"
                    color: "#F7FBFF"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

                VpnToggle {
                    width: Math.min(parent.width - 74, 318)
                    anchors.horizontalCenter: parent.horizontalCenter
                    connected: ConnectionController.isConnected
                    busy: root.vpnBusy
                    busyText: root.vpnActionText
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

            Item {
                width: parent.width
                height: Math.max(16, appScroll.height - homeMainContent.implicitHeight - homeRecommendedCard.height - homeColumn.spacing * 2 - 34)
                visible: homeRecommendedCard.visible
            }

            RecommendedServerCard {
                id: homeRecommendedCard

                width: parent.width
                visible: root.currentServers().length > 0
                server: root.recommendedServer()
                compact: false
                onClicked: {
                    var server = root.recommendedServer()
                    if (server && server.id) {
                        root.selectedServerIndex = root.serverIndexById(server.id)
                    }
                }
            }
        }
    }

    Component {
        id: locationsScreen

        Column {
            width: parent.width
            spacing: 13

            Text {
                width: parent.width
                text: "Локации"
                color: "#F7FBFF"
                font.family: "sans-serif-medium"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                maximumLineCount: 1
            }

            RecommendedServerCard {
                width: parent.width
                visible: root.currentServers().length > 0
                server: root.recommendedServer()
                compact: true
                onClicked: {
                    var server = root.recommendedServer()
                    if (server && server.id) {
                        root.selectedServerIndex = root.serverIndexById(server.id)
                        root.currentTab = root.tabHome
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 11

                Rectangle {
                    width: parent.width - 72
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
                        anchors.leftMargin: 50
                        anchors.rightMargin: 18
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
                    width: 56
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
                        width: 20
                        height: 21
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
                height: root.filteredServers().length > 0 ? root.filteredServers().length * 56 + 10 : 104
                radius: 20
                color: root.glassFill
                border.color: Qt.rgba(1, 1, 1, 0.075)
                border.width: 1
                opacity: 0.96
                implicitHeight: height

                Column {
                    id: locationsList
                    width: parent.width - 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 5

                    Repeater {
                        model: root.filteredServers()

                        delegate: Item {
                            required property int index
                            required property var modelData

                            width: parent.width
                            height: 56

                            Row {
                                id: serverRow
                                width: parent.width
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                FlagBadge {
                                    width: 34
                                    height: 34
                                    server: modelData
                                }

                                Text {
                                    width: parent.width - 88
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.serverDisplayTitle(modelData)
                                    color: root.serverIndexById(modelData.id) === root.selectedServerIndex ? root.guardoAccent : "#F7FBFF"
                                    font.family: "sans-serif-medium"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Item {
                                    width: 42
                                    height: 32

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        QualityBars {
                                            width: 28
                                            height: 16
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            quality: modelData.quality || root.qualityForStatus(modelData.status)
                                        }

                                        Text {
                                            width: 42
                                            text: modelData.latency || ""
                                            color: "#AABBB0"
                                            font.pixelSize: 8
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
            spacing: 10

            Text {
                id: profileTitle

                width: parent.width
                text: "Профиль"
                color: "#F7FBFF"
                font.family: "sans-serif-medium"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                maximumLineCount: 1
            }

            Item {
                width: parent.width
                height: AppApiController.authenticated ? 34 : 0
                visible: AppApiController.authenticated
                z: 20

                Row {
                    id: profileIdentityRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        id: profileEmailText

                        width: Math.min(implicitWidth, profileRoot.width - profileActionsButton.width - profileIdentityRow.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.profileEmail()
                        color: "#F7FBFF"
                        font.family: "sans-serif-medium"
                        font.pixelSize: 14
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }

                    Rectangle {
                        id: profileActionsButton

                        width: 30
                        height: 30
                        radius: 11
                        color: profileMenuTap.pressed ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        Image {
                            id: profileMoreIcon

                            width: 15
                            height: 15
                            anchors.centerIn: parent
                            source: "qrc:/images/controls/more-vertical.svg"
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: profileMoreIcon
                            source: profileMoreIcon
                            color: "#F3FFF7"
                            opacity: 0.92
                        }

                        MouseArea {
                            id: profileMenuTap
                            anchors.fill: parent
                            onClicked: {
                                root.profileMenuOpen = !root.profileMenuOpen
                                if (root.profileMenuOpen) {
                                    profileActionsPopup.open()
                                } else {
                                    profileActionsPopup.close()
                                }
                            }
                        }
                    }
                }

                Popup {
                    id: profileActionsPopup

                    width: Math.min(206, parent.width - 24)
                    height: 73
                    x: Math.max(0, Math.min(profileIdentityRow.x + profileActionsButton.x + profileActionsButton.width - width, parent.width - width))
                    y: profileIdentityRow.y + profileActionsButton.y + profileActionsButton.height + 8
                    padding: 0
                    modal: false
                    focus: true
                    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
                    onClosed: root.profileMenuOpen = false
                    onOpened: root.profileMenuOpen = true

                    background: Rectangle {
                        radius: 14
                        color: Qt.rgba(0.16, 0.24, 0.23, 0.96)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                    }

                    contentItem: Column {

                        ProfileMenuItem {
                            width: profileActionsPopup.width
                            height: 36
                            text: "Удалить профиль"
                            danger: true
                            onClicked: {
                                profileActionsPopup.close()
                                root.deleteProfileRequested()
                            }
                        }

                        Rectangle {
                            width: profileActionsPopup.width
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.09)
                        }

                        ProfileMenuItem {
                            width: profileActionsPopup.width
                            height: 36
                            text: "Выйти из профиля"
                            danger: false
                            onClicked: {
                                profileActionsPopup.close()
                                root.logoutProfile()
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: subscriptionCard

                width: parent.width
                radius: 20
                color: root.glassFillStrong
                border.color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                implicitHeight: 76

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                }

                Row {
                    id: subscriptionCardRow
                    width: parent.width - 24
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.appUserCanConnect() ? Qt.rgba(0.72, 0.95, 0.42, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: root.appUserCanConnect() ? Qt.rgba(0.78, 0.98, 0.62, 0.32) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1

                        Image {
                            id: subscriptionStatusIcon

                            width: 22
                            height: 22
                            anchors.centerIn: parent
                            source: "qrc:/images/controls/shield-check.svg"
                            visible: false
                            smooth: true
                        }

                        ColorOverlay {
                            anchors.fill: subscriptionStatusIcon
                            source: subscriptionStatusIcon
                            color: root.appUserCanConnect() ? "#B9F36E" : "#DDE8DF"
                            opacity: root.appUserCanConnect() ? 0.98 : 0.62
                        }
                    }

                    Column {
                        width: parent.width - 36 - subscriptionActionButton.width - 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            width: parent.width
                            text: AppApiController.authenticated ? root.profileAccessTitle() : "Вы не авторизованы"
                            color: "#F7FBFF"
                            font.family: "sans-serif-medium"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Row {
                            width: parent.width
                            height: 16
                            visible: root.profileDeviceText().length > 0

                            Text {
                                width: parent.width
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.profileDeviceText()
                                color: "#AFC1B2"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    GuardoButton {
                        id: subscriptionActionButton

                        width: AppApiController.authenticated && root.appUserCanConnect() ? 82 : 94
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: AppApiController.authenticated ? (root.appUserCanConnect() ? "Кабинет" : "Оформить") : "Войти"
                        secondary: AppApiController.authenticated && root.appUserCanConnect()
                        labelPixelSize: 12
                        onClicked: {
                            if (!AppApiController.authenticated) {
                                root.guestMode = false
                                return
                            }
                            root.openAccountUrl(root.appUserCanConnect() ? "/account" : "/account/plans")
                        }
                    }
                }
            }

            Item {
                id: profileActionsSpacer

                readonly property real profileFreeSpace: Math.max(160, appScroll.height - profileTitle.implicitHeight - (AppApiController.authenticated ? 34 : 0) - subscriptionCard.implicitHeight - profileSettingsRow.implicitHeight - profileHelpRow.implicitHeight - profileAskButton.height - versionLabel.implicitHeight - copyrightLabel.implicitHeight - profileRoot.spacing * 10 - 44)

                width: parent.width
                height: Math.max(104, Math.min(220, profileFreeSpace * 0.52))
            }

            MenuRow {
                id: profileSettingsRow

                width: parent.width
                iconSource: "qrc:/images/controls/settings-2.svg"
                title: "Настройки"
                subtitle: ""
                onClicked: {
                    root.profileMenuOpen = false
                    root.currentTab = root.tabSettings
                }
            }

            MenuRow {
                id: profileHelpRow

                width: parent.width
                iconSource: "qrc:/images/controls/help-circle.svg"
                trailingIconSource: "qrc:/images/controls/external-link.svg"
                title: "Справочный центр"
                subtitle: ""
                onClicked: root.openAccountUrl("/support")
            }

            Item {
                width: parent.width
                height: 6
            }

            Rectangle {
                id: profileAskButton

                width: Math.min(parent.width * 0.52, 224)
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 24
                color: Qt.rgba(1, 1, 1, 0.13)
                border.color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/images/controls/help-circle.svg"
                        opacity: 0.9
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Задать вопрос"
                        color: "#F7FBFF"
                        font.family: "sans-serif-medium"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.openAccountUrl("/account/support?topic=app&context=android")
                }
            }

            Item {
                id: profileFooterSpacer

                width: parent.width
                height: Math.max(24, Math.min(190, profileActionsSpacer.profileFreeSpace - profileActionsSpacer.height - 18))
            }

            Text {
                id: versionLabel

                width: parent.width
                text: "v0.1"
                color: "#6F8174"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                id: copyrightLabel

                width: parent.width
                text: "© 2026 GuardoVPN"
                color: "#6F8174"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Component {
        id: settingsScreen

        Column {
            id: settingsRoot

            width: parent.width
            spacing: 14

            Row {
                id: settingsHeader

                width: parent.width
                height: 34
                spacing: 10

                Rectangle {
                    width: 30
                    height: 30
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: settingsBackTap.pressed ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    Image {
                        id: settingsBackIcon

                        width: 16
                        height: 16
                        anchors.centerIn: parent
                        source: "qrc:/images/controls/arrow-left.svg"
                        visible: false
                    }

                    ColorOverlay {
                        anchors.fill: settingsBackIcon
                        source: settingsBackIcon
                        color: "#EAF5ED"
                        opacity: 0.9
                    }

                    MouseArea {
                        id: settingsBackTap
                        anchors.fill: parent
                        onClicked: root.currentTab = root.tabProfile
                    }
                }

                Text {
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Настройки"
                    color: "#F7FBFF"
                    font.family: "sans-serif-medium"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Rectangle {
                id: settingsBypassCard

                width: parent.width
                radius: 20
                color: root.glassFillStrong
                border.color: Qt.rgba(1, 1, 1, 0.075)
                border.width: 1
                implicitHeight: bypassRow.implicitHeight + 24

                Row {
                    id: bypassRow
                    width: parent.width - 24
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(0.72, 0.95, 0.42, 0.10)
                        border.color: Qt.rgba(0.78, 0.98, 0.62, 0.20)
                        border.width: 1

                        Image {
                            id: bypassIcon

                            width: 16
                            height: 16
                            anchors.centerIn: parent
                            source: "qrc:/images/controls/settings-2.svg"
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: bypassIcon
                            source: bypassIcon
                            color: "#DCEED2"
                            opacity: 0.95
                        }
                    }

                    Column {
                        width: parent.width - 34 - 56 - 28
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            width: parent.width
                            text: "Открывать российские сервисы без VPN"
                            color: "#F3FFF7"
                            font.family: "sans-serif-medium"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "Банки, госуслуги и маркетплейсы будут открываться напрямую, если функция включена."
                            color: "#93A79D"
                            font.pixelSize: 11
                            lineHeight: 1.15
                            wrapMode: Text.WordWrap
                        }
                    }

                    MiniToggle {
                        checked: root.russianBypass
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.setRussianBypass(!root.russianBypass)
                    }
                }
            }

            Item {
                id: settingsBackSpacer

                readonly property real settingsFreeSpace: Math.max(120, appScroll.height - settingsHeader.height - settingsBypassCard.implicitHeight - settingsBackButton.height - settingsVersionLabel.implicitHeight - settingsCopyrightLabel.implicitHeight - settingsRoot.spacing * 6 - 24)

                width: parent.width
                height: Math.max(74, Math.min(210, settingsFreeSpace * 0.68))
            }

            GuardoButton {
                id: settingsBackButton

                width: Math.min(parent.width * 0.52, 210)
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Назад в профиль"
                secondary: true
                labelPixelSize: 13
                onClicked: root.currentTab = root.tabProfile
            }

            Item {
                width: parent.width
                height: Math.max(10, Math.min(90, settingsBackSpacer.settingsFreeSpace - settingsBackSpacer.height - 16))
            }

            Text {
                id: settingsVersionLabel

                width: parent.width
                text: "v0.1"
                color: "#6F8174"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                id: settingsCopyrightLabel

                width: parent.width
                text: "© 2026 GuardoVPN"
                color: "#6F8174"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    function requestEmailCode() {
        var trimmedEmail = root.emailText.trim()
        if (trimmedEmail.length === 0 || !root.isValidEmail(trimmedEmail)) {
            root.emailError = true
            root.statusText = ""
            root.showToast("Введите корректный email", true)
            emailInput.focusInput()
            emailShakeAnimation.restart()
            return
        }

        root.emailError = false
        root.resetCodeError()
        root.accountBlockVisible = false
        if (root.backendUrlText.trim().length > 0) {
            AppApiController.baseUrl = root.backendUrlText.trim()
        }

        root.pendingEmail = trimmedEmail
        root.statusText = "Отправляем код"
        AppApiController.requestEmailCode(trimmedEmail, AppApiController.deviceUuid, "", "android")
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
        if (Qt.platform.os === "ios") {
            AppApiController.setOneTimeCodeAutofillActive(false)
        }
        Qt.inputMethod.hide()
        root.forceActiveFocus()
        AppApiController.verifyEmailCode(root.pendingEmail || root.emailText.trim(), trimmedCode, AppApiController.deviceUuid, "", "android")
    }

    function showCodeError(message, clearAfterShake) {
        if (clearAfterShake === undefined) {
            clearAfterShake = true
        }

        codeErrorClearTimer.stop()
        codeErrorResetTimer.stop()
        root.statusText = message || "Код неверный или устарел"
        root.showToast(root.statusText, true)
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
        root.showToast("Оформите доступ на сайте GuardoVPN или в Telegram-боте")
        root.currentTab = root.tabProfile
    }

    function isAccountBlockingMessage(message) {
        return message.indexOf("Лимит устройств") === 0
            || message.indexOf("Подписка не активна") === 0
            || message.indexOf("Оформите доступ") !== -1
    }

    function showAccountBlock(message) {
        var safeMessage = message || "Вход сейчас недоступен"
        var separatorIndex = safeMessage.indexOf(". ")

        root.accountBlockTitle = separatorIndex > 0 ? safeMessage.substring(0, separatorIndex) : safeMessage
        root.accountBlockMessage = separatorIndex > 0 ? safeMessage.substring(separatorIndex + 2) : "Проверьте доступ или напишите в поддержку."
        root.statusText = ""
        root.toastText = ""
        toastTimer.stop()
        if (Qt.platform.os === "ios") {
            AppApiController.setOneTimeCodeAutofillActive(false)
        }
        Qt.inputMethod.hide()
        root.forceActiveFocus()
        root.accountBlockVisible = true
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
        root.accountBlockVisible = false
        if (Qt.platform.os === "ios") {
            AppApiController.setOneTimeCodeAutofillActive(false)
        }
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

    function refreshServersIfNeeded() {
        if (root.currentTab !== root.tabLocations) {
            return
        }
        if (!AppApiController.authenticated || AppApiController.mockMode || AppApiController.busy) {
            return
        }
        if (!AppApiController.servers || AppApiController.servers.length === 0) {
            AppApiController.fetchServers()
        }
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

    function serverLatencyMs(server) {
        var value = server && server.latency ? String(server.latency) : ""
        var match = value.match(/\d+/)
        if (match && match.length > 0) {
            return parseInt(match[0], 10)
        }
        return 999999
    }

    function recommendedServer() {
        var servers = root.currentServers()
        if (!servers || servers.length === 0) {
            return {}
        }

        var best = servers[0]
        var bestScore = 9999999
        for (var i = 0; i < servers.length; i++) {
            var server = servers[i]
            if (!server || !server.id) {
                continue
            }
            var reservePenalty = (server.status === "reserve" || server.protocol === "xray_vless_reality") ? 500000 : 0
            var qualityPenalty = (3 - root.qualityForStatus(server.status)) * 10000
            var score = reservePenalty + qualityPenalty + root.serverLatencyMs(server)
            if (score < bestScore) {
                bestScore = score
                best = server
            }
        }
        return best || {}
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
        return root.serverDisplayTitle(server)
    }

    function serverDisplayTitle(server) {
        if (!server || !server.id) {
            return "Выберите локацию"
        }
        var country = root.localizedCountryName(server)
        if (country.length > 0) {
            return country
        }
        if (server.title && server.title.length > 0) {
            return server.title
        }
        return "Локация"
    }

    function localizedCountryName(server) {
        if (!server) {
            return ""
        }
        var raw = (server.country && server.country.length > 0 ? server.country : server.title || "").trim()
        var code = raw.toUpperCase()
        var id = (server.id || "").toLowerCase()
        var city = (server.city || "").toLowerCase()
        var text = raw.toLowerCase()

        if (code === "NL" || id.indexOf("nl") === 0 || text.indexOf("нидер") !== -1 || text.indexOf("nether") !== -1) {
            return "Нидерланды"
        }
        if (code === "DE" || id.indexOf("de") === 0 || text.indexOf("герм") !== -1 || text.indexOf("german") !== -1 || city.indexOf("berlin") !== -1) {
            return "Германия"
        }
        if (code === "RU" || id.indexOf("ru") === 0 || text.indexOf("рос") !== -1 || text.indexOf("russia") !== -1) {
            return "Россия"
        }
        if (code === "KZ" || id.indexOf("kz") === 0 || text.indexOf("каз") !== -1 || text.indexOf("kazakh") !== -1) {
            return "Казахстан"
        }
        if (code === "UA" || id.indexOf("ua") === 0 || text.indexOf("укра") !== -1 || text.indexOf("ukraine") !== -1) {
            return "Украина"
        }
        return raw
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
            return "GuardoWG"
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
        if (country.indexOf("лит") !== -1 || country.indexOf("lithuan") !== -1 || serverId.indexOf("lt") === 0) {
            return "LT"
        }
        if (country.indexOf("поль") !== -1 || country.indexOf("poland") !== -1 || serverId.indexOf("pl") === 0) {
            return "PL"
        }
        if (country.indexOf("фин") !== -1 || country.indexOf("finland") !== -1 || serverId.indexOf("fi") === 0) {
            return "FI"
        }
        if (country.indexOf("швец") !== -1 || country.indexOf("sweden") !== -1 || serverId.indexOf("se") === 0) {
            return "SE"
        }
        if (country.indexOf("дани") !== -1 || country.indexOf("denmark") !== -1 || serverId.indexOf("dk") === 0) {
            return "DK"
        }
        if (country.indexOf("норв") !== -1 || country.indexOf("norway") !== -1 || serverId.indexOf("no") === 0) {
            return "NO"
        }
        if (country.indexOf("исп") !== -1 || country.indexOf("spain") !== -1 || serverId.indexOf("es") === 0) {
            return "ES"
        }
        if (country.indexOf("фран") !== -1 || country.indexOf("france") !== -1 || serverId.indexOf("fr") === 0) {
            return "FR"
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
        var deviceText = ""
        if (user.devices_used !== undefined && user.device_limit !== undefined) {
            deviceText = " · устройства " + user.devices_used + "/" + user.device_limit
        }
        if (!canConnect) {
            return prefix + "подписка не активна"
        }
        if (user.expires_at && user.expires_at.length > 0) {
            return prefix + "активна до " + root.shortDate(user.expires_at) + deviceText
        }
        if (status === "active") {
            return prefix + "подписка активна" + deviceText
        }
        return prefix + status
    }

    function profileEmail() {
        var user = AppApiController.user || {}
        if (user.email && user.email.length > 0) {
            return user.email
        }
        if (root.pendingEmail && root.pendingEmail.length > 0) {
            return root.pendingEmail
        }
        if (root.emailText && root.emailText.length > 0) {
            return root.emailText
        }
        return "Профиль"
    }

    function profileAccessTitle() {
        if (!AppApiController.user) {
            return "Проверяем подписку"
        }
        if (root.appUserCanConnect()) {
            return "Подписка активна"
        }
        return "У вас нет активной подписки"
    }

    function profileDeviceText() {
        if (!AppApiController.authenticated || !AppApiController.user) {
            return ""
        }
        var user = AppApiController.user || {}
        if (user.devices_used === undefined || user.device_limit === undefined) {
            return ""
        }
        return "Устройства " + user.devices_used + "/" + user.device_limit
    }

    function profileAccessSubtitle() {
        var user = AppApiController.user || {}
        var deviceText = ""
        if (user.devices_used !== undefined && user.device_limit !== undefined) {
            deviceText = "Устройства: " + user.devices_used + "/" + user.device_limit
        }
        if (root.appUserCanConnect()) {
            if (user.expires_at && user.expires_at.length > 0) {
                return "Доступ активен до " + root.shortDate(user.expires_at) + (deviceText.length > 0 ? "\n" + deviceText : "")
            }
            return deviceText.length > 0 ? deviceText : "Можно подключаться к VPN."
        }
        return "Оформите доступ на сайте GuardoVPN или в Telegram-боте."
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

    function beginVpnAction(message) {
        root.vpnActionText = message || "Подключаем VPN"
        root.vpnActionPending = true
        root.vpnObservedConnectionProgress = false
        root.statusText = root.vpnActionText
        vpnPendingFallbackTimer.restart()
    }

    function finishVpnAction() {
        root.vpnActionPending = false
        root.vpnObservedConnectionProgress = false
        root.vpnActionText = ""
        vpnPendingFallbackTimer.stop()
    }

    function runVpnActionAfterPaint(action) {
        root.pendingVpnAction = action
        vpnActionStartTimer.restart()
    }

    function openAccountUrl(path) {
        AppApiController.openAccountPath(path || "/account")
    }

    function logoutProfile() {
        root.profileMenuOpen = false
        root.guestMode = false
        root.resetAuthForm()
        root.statusText = ""
        AppApiController.clearSession()
    }

    function deleteProfileRequested() {
        root.profileMenuOpen = false
        deleteProfileConfirmPopup.open()
    }

    function confirmDeleteProfile() {
        root.showToast("Удалить профиль можно в личном кабинете")
        root.openAccountUrl("/account/profile")
    }

    function toggleSelectedServer() {
        if (root.vpnActionPending && !ConnectionController.isConnected) {
            return
        }

        if (!AppApiController.authenticated) {
            root.requireAuth()
            return
        }

        if (!root.appUserCanConnect()) {
            root.requireActiveSubscription()
            return
        }

        if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress) {
            root.beginVpnAction("Отключаем защиту")
            root.runVpnActionAfterPaint(function() {
                ConnectionController.closeConnection()
            })
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
            root.finishVpnAction()
            root.showToast("Выберите локацию")
            return
        }

        if (server.status === "reserve" || server.protocol === "xray_vless_reality") {
            root.finishVpnAction()
            root.statusText = "Резервный протокол пока не включён"
            root.showToast(root.statusText)
            return
        }

        root.beginVpnAction("Запускаем защиту")
        root.runVpnActionAfterPaint(function() {
            root.configureRussianBypass()
            AppApiController.fetchConfig(server.id)
        })
    }

    function setRussianBypass(enabled) {
        root.russianBypass = enabled
        root.configureRussianBypass()
        if (ConnectionController.isConnected) {
            root.showToast("Изменение применится после переподключения")
        }
    }

    function configureRussianBypass() {
        IpSplitTunnelingController.configureRussianServicesBypass(root.russianBypass)
    }

    function importAndConnectConfig(configText, serverTitle) {
        if (!configText || configText.length === 0) {
            root.finishVpnAction()
            root.statusText = "Пустая конфигурация"
            root.showToast(root.statusText)
            return
        }

        if (!ImportController.extractConfigFromData(configText)) {
            root.finishVpnAction()
            root.statusText = "Ошибка импорта конфигурации"
            root.showToast(root.statusText)
            return
        }
        root.beginVpnAction("Подключаем VPN")
        root.runVpnActionAfterPaint(function() {
            ImportController.importConfig()
            ConnectionController.openConnection()
        })
    }

    function showToast(message, isError) {
        root.toastText = message || ""
        root.toastIsError = isError === true
        toastTimer.restart()
    }

    component AppLogoHeader: Item {
        height: 88

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 88
            height: 88
            source: "qrc:/images/guardovpnLogoLockup.png"
            sourceClipRect: Qt.rect(0, 0, 300, 310)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    component VpnToggle: Rectangle {
        id: vpnToggleRoot

        property bool connected: false
        property bool busy: false
        property string busyText: ""
        signal clicked()

        height: 74
        radius: height / 2
        color: "transparent"
        border.color: connected ? Qt.rgba(0.75, 1, 0.54, 0.62) : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Rectangle {
            id: toggleGlow
            anchors.centerIn: parent
            width: parent.width + 14
            height: parent.height + 14
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
            width: 60
            height: 60
            radius: 30
            anchors.verticalCenter: parent.verticalCenter
            x: vpnToggleRoot.connected ? vpnToggleRoot.width - width - 7 : 7
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

            Image {
                id: vpnPowerIcon

                width: 27
                height: 27
                anchors.centerIn: parent
                source: "qrc:/images/controls/power.svg"
                visible: false
                smooth: true
            }

            ColorOverlay {
                anchors.fill: vpnPowerIcon
                source: vpnPowerIcon
                color: vpnToggleRoot.connected ? "#183318" : "#27302B"
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: vpnToggleRoot.connected ? parent.left : toggleThumb.right
            anchors.right: vpnToggleRoot.connected ? toggleThumb.left : parent.right
            anchors.leftMargin: vpnToggleRoot.connected ? 22 : 16
            anchors.rightMargin: vpnToggleRoot.connected ? 16 : 22
            text: vpnToggleRoot.busy ? (vpnToggleRoot.busyText.length > 0 ? vpnToggleRoot.busyText : "Запускаем защиту") : (vpnToggleRoot.connected ? "Защита включена" : "Включить защиту")
            color: vpnToggleRoot.connected ? "#10210E" : "#F3FFF7"
            font.family: "sans-serif-medium"
            font.pixelSize: 16
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
            onPressed: vpnToggleRoot.clicked()
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
            color: miniToggleRoot.checked ? root.guardoAccent : "#B8C9B3"

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

    component SortGlyph: Canvas {
        id: sortGlyphRoot

        property bool ascending: true
        property color activeColor: root.guardoAccent
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

    component GuardoButton: Rectangle {
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

    component GuardoChip: Rectangle {
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

    component GuardoTextField: Rectangle {
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

    component GuardoCodeInput: Item {
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
            inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhPreferNumbers
            onAccepted: {
                if (text.length === 6 && !codeRoot.submittedFullCode) {
                    codeRoot.submittedFullCode = true
                    codeRoot.accepted(text)
                }
            }
            onActiveFocusChanged: {
                if (Qt.platform.os === "ios" && activeFocus) {
                    AppApiController.setOneTimeCodeAutofillActive(activeFocus)
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
            if (Qt.platform.os === "ios") {
                AppApiController.setOneTimeCodeAutofillActive(true)
            }
            Qt.inputMethod.show()
        }

        function clearInput() {
            codeRoot.submittedFullCode = false
            hiddenInput.clear()
        }

        Component.onDestruction: {
            if (Qt.platform.os === "ios") {
                AppApiController.setOneTimeCodeAutofillActive(false)
            }
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
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Qt.platform.os === "android" ? 4 : 8
            spacing: 1

            Item {
                width: 22
                height: 22
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
                    color: navRoot.active ? root.guardoAccent : "#7E8F82"
                    opacity: navRoot.active ? 1 : 0.78
                }
            }

            Text {
                text: navRoot.label
                color: navRoot.active ? "#F3FFF7" : "#91A095"
                font.pixelSize: 13
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

        spacing: 2
        layoutDirection: Qt.LeftToRight

        Repeater {
            model: 3

            Rectangle {
                required property int index

                width: 5
                height: 8 + index * 4
                radius: 3
                y: barsRoot.height - height
                color: index < barsRoot.quality ? root.guardoAccent : "#4E5F53"
            }
        }
    }

    component LightningIcon: Item {
        id: lightningRoot

        Canvas {
            anchors.fill: parent
            antialiasing: true
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = root.guardoAccent
                ctx.lineWidth = 1.55
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(width * 0.58, height * 0.08)
                ctx.lineTo(width * 0.23, height * 0.52)
                ctx.lineTo(width * 0.48, height * 0.52)
                ctx.lineTo(width * 0.34, height * 0.92)
                ctx.lineTo(width * 0.78, height * 0.40)
                ctx.lineTo(width * 0.53, height * 0.40)
                ctx.lineTo(width * 0.58, height * 0.08)
                ctx.stroke()
            }

            Component.onCompleted: requestPaint()
        }
    }

    component RecommendedServerCard: Rectangle {
        id: recommendedRoot

        property var server: ({})
        property bool compact: false
        signal clicked()

        height: compact ? 44 : 48
        radius: compact ? 18 : 20
        color: Qt.rgba(1, 1, 1, 0.082)
        border.color: Qt.rgba(0.78, 0.98, 0.62, 0.18)
        border.width: 1
        opacity: recommendedTap.pressed ? 0.82 : 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.075)
            border.width: 1
        }

        Row {
            width: parent.width - 24
            anchors.centerIn: parent
            spacing: compact ? 9 : 11

            Rectangle {
                width: compact ? 27 : 30
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0.75, 1.0, 0.50, 0.13)
                border.color: Qt.rgba(0.86, 1.0, 0.68, 0.22)
                border.width: 1

                Image {
                    width: compact ? 15 : 16
                    height: width
                    anchors.centerIn: parent
                    source: "qrc:/images/controls/lightning.svg"
                    smooth: true
                    mipmap: true
                }
            }

            Text {
                width: parent.width - 30 - recommendBadge.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                text: root.serverDisplayTitle(recommendedRoot.server)
                color: "#F7FBFF"
                font.family: "sans-serif-medium"
                font.pixelSize: compact ? 15 : 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Rectangle {
                id: recommendBadge

                width: Math.max(compact ? 96 : 102, recommendBadgeText.implicitWidth + 24)
                height: compact ? 27 : 28
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0.73, 0.98, 0.47, 0.12)
                border.color: Qt.rgba(0.84, 1.0, 0.66, 0.20)
                border.width: 1

                Text {
                    id: recommendBadgeText

                    anchors.centerIn: parent
                    text: "Рекомендуем"
                    color: "#D7F2CA"
                    font.pixelSize: compact ? 11 : 11
                    font.weight: Font.Medium
                    maximumLineCount: 1
                }
            }
        }

        MouseArea {
            id: recommendedTap

            anchors.fill: parent
            onClicked: recommendedRoot.clicked()
        }
    }

    component MenuRow: Rectangle {
        id: menuRoot

        property string iconSource: ""
        property string trailingIconSource: "qrc:/images/controls/chevron-right.svg"
        property string title: ""
        property string subtitle: ""
        signal clicked()

        radius: 18
        color: Qt.rgba(1, 1, 1, 0.074)
        border.color: Qt.rgba(1, 1, 1, 0.075)
        border.width: 1
        implicitHeight: 54

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
            width: parent.width - 26
            anchors.centerIn: parent
            spacing: 11

            Rectangle {
                width: 34
                height: 34
                radius: 13
                color: Qt.rgba(0.72, 0.95, 0.42, 0.10)
                border.color: Qt.rgba(0.78, 0.98, 0.62, 0.20)
                border.width: 1

                Image {
                    id: menuIcon

                    width: 16
                    height: 16
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
                width: parent.width - 76
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: menuRoot.title
                    color: "#F7FBFF"
                    font.family: "sans-serif-medium"
                    font.pixelSize: 15
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
                    source: menuRoot.trailingIconSource
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

    component ProfileMenuItem: Rectangle {
        id: profileMenuItemRoot

        property string text: ""
        property bool danger: false
        signal clicked()

        color: profileMenuMouseArea.pressed ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        Text {
            width: parent.width - 28
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: profileMenuItemRoot.text
            color: profileMenuItemRoot.danger ? "#FF7272" : "#F2FFF7"
            font.pixelSize: 13
            font.weight: Font.Normal
            elide: Text.ElideRight
        }

        MouseArea {
            id: profileMenuMouseArea

            anchors.fill: parent
            onClicked: profileMenuItemRoot.clicked()
        }
    }
}
