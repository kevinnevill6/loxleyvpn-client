import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

PageType {
    id: root

    property int flowStep: 0
    property int selectedServerIndex: -1
    property string statusText: ""
    property string accessCodeText: ""

    readonly property string localConfigFileName: "test-awg-config.conf"
    readonly property var mockServers: [
        {
            "id": "nl-awg-1",
            "title": "Нидерланды 1",
            "country": "NL",
            "protocol": "amneziawg",
            "status": "online",
            "priority": 10
        },
        {
            "id": "de-awg-1",
            "title": "Германия 1",
            "country": "DE",
            "protocol": "amneziawg",
            "status": "online",
            "priority": 20
        },
        {
            "id": "reserve-xray-1",
            "title": "Резервный сервер",
            "country": "NL",
            "protocol": "vless_reality",
            "status": "online",
            "priority": 90
        }
    ]

    Connections {
        target: ImportController

        function onQrDecodingFinished() {
            if (Qt.platform.os === "ios") {
                PageController.closePage()
            }
            PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
        }
    }

    ListViewType {
        id: listView

        anchors.fill: parent
        model: 1

        header: ColumnLayout {
            width: listView.width
            spacing: 0

            HeaderTypeWithButton {
                Layout.fillWidth: true
                Layout.topMargin: 24 + PageController.safeAreaTopMargin
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("LoxleyVPN")
                actionButtonImage: flowStep === 0 ? "" : "qrc:/images/controls/arrow-left.svg"
                actionButtonFunction: function() {
                    if (flowStep === 2) {
                        flowStep = 1
                        statusText = ""
                    } else if (flowStep === 1) {
                        flowStep = 0
                        selectedServerIndex = -1
                        statusText = ""
                    }
                }
            }

            Image {
                property real logoWidth: Math.max(220, Math.min(listView.width - 64, 360))

                source: "qrc:/images/loxleyvpnLogoLockup.png"
                fillMode: Image.PreserveAspectFit
                visible: flowStep === 0

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 28
                Layout.preferredWidth: logoWidth
                Layout.preferredHeight: logoWidth / 3
            }

            ParagraphTextType {
                Layout.fillWidth: true
                Layout.topMargin: flowStep === 0 ? 32 : 24
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 16

                text: {
                    if (flowStep === 0) {
                        return qsTr("Введите тестовый код доступа. Для PoC подходит любой непустой код.")
                    }
                    if (flowStep === 1) {
                        return qsTr("Выберите сервер LoxleyVPN.")
                    }
                    return qsTr("Проверьте выбранный сервер и запустите тестовое подключение.")
                }
            }

            TextFieldWithHeaderType {
                id: accessCode

                visible: flowStep === 0
                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("Код доступа")
                textField.placeholderText: qsTr("Например: test")
                textField.onTextChanged: root.accessCodeText = textField.text
                rightButtonClickedOnEnter: true
                clickedFunc: function() {
                    root.login()
                }
            }

            BasicButtonType {
                visible: flowStep === 0
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                text: qsTr("Войти")
                clickedFunc: function() {
                    root.login()
                }
            }

            SmallTextType {
                visible: statusText !== ""
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                color: AmneziaStyle.color.vibrantRed
                wrapMode: Text.Wrap
                text: statusText
            }
        }

        delegate: ColumnLayout {
            width: listView.width
            spacing: 0

            Repeater {
                model: flowStep === 1 ? mockServers : []

                CardWithIconsType {
                    Layout.fillWidth: true
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16
                    Layout.bottomMargin: 16

                    headerText: modelData.title
                    bodyText: modelData.status === "online" ? qsTr("Онлайн") : qsTr("Недоступен")
                    footerText: modelData.country
                    leftImageSource: "qrc:/images/controls/globe-2.svg"
                    rightImageSource: "qrc:/images/controls/chevron-right.svg"

                    onClicked: {
                        root.selectServer(index)
                    }
                }
            }

            ColumnLayout {
                visible: flowStep === 2
                Layout.fillWidth: true
                spacing: 0

                CardWithIconsType {
                    Layout.fillWidth: true
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16
                    Layout.bottomMargin: 16

                    headerText: selectedServer().title
                    bodyText: selectedServer().status === "online" ? qsTr("Онлайн") : qsTr("Недоступен")
                    footerText: selectedServer().country
                    leftImageSource: "qrc:/images/controls/globe-2.svg"
                    rightImageSource: ""
                }

                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16

                    text: qsTr("Подключиться")
                    clickedFunc: function() {
                        root.connectSelectedServer()
                    }
                }

                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16

                    defaultColor: AmneziaStyle.color.transparent
                    hoveredColor: AmneziaStyle.color.translucentWhite
                    pressedColor: AmneziaStyle.color.sheerWhite
                    textColor: AmneziaStyle.color.paleGray
                    borderWidth: 1

                    text: qsTr("Отключиться")
                    clickedFunc: function() {
                        ConnectionController.closeConnection()
                    }
                }

                ParagraphTextType {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16

                    color: AmneziaStyle.color.mutedGray
                    text: qsTr("Статус: ") + ConnectionController.connectionStateText
                }

                DividerType {
                    Layout.topMargin: 24
                    Layout.bottomMargin: 8
                }

                ParagraphTextType {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16
                    Layout.bottomMargin: 16

                    color: AmneziaStyle.color.charcoalGray
                    text: qsTr("Ручной fallback для PoC")
                }

                TextFieldWithHeaderType {
                    id: manualKey

                    Layout.fillWidth: true
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16

                    headerText: qsTr("Ключ подключения")
                    buttonText: qsTr("Вставить")

                    clickedFunc: function() {
                        textField.text = ""
                        textField.paste()
                    }
                }

                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16
                    visible: manualKey.textField.text !== ""

                    text: qsTr("Импортировать ключ")
                    clickedFunc: function() {
                        if (ImportController.extractConfigFromData(manualKey.textField.text)) {
                            PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16
                    Layout.bottomMargin: 32
                    spacing: 12

                    BasicButtonType {
                        Layout.fillWidth: true
                        text: qsTr("Файл")
                        clickedFunc: function() {
                            const nameFilter = "Config files (*.vpn *.ovpn *.conf *.json)"
                            const fileName = SystemController.getFileName(qsTr("Open config file"), nameFilter)
                            if (fileName !== "" && ImportController.extractConfigFromFile(fileName)) {
                                PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
                            }
                        }
                    }

                    BasicButtonType {
                        Layout.fillWidth: true
                        text: qsTr("QR-код")
                        clickedFunc: function() {
                            ImportController.startDecodingQr()
                            if (Qt.platform.os === "ios") {
                                PageController.goToPage(PageEnum.PageSetupWizardQrReader)
                            }
                        }
                    }
                }
            }
        }
    }

    function login() {
        if (accessCodeText.trim() === "") {
            statusText = qsTr("Введите любой тестовый код")
            return
        }
        statusText = ""
        flowStep = 1
    }

    function selectServer(index) {
        selectedServerIndex = index
        statusText = ""
        flowStep = 2
        listView.positionViewAtBeginning()
    }

    function selectedServer() {
        if (selectedServerIndex < 0 || selectedServerIndex >= mockServers.length) {
            return {
                "id": "",
                "title": "",
                "country": "",
                "protocol": "",
                "status": "",
                "priority": 0
            }
        }
        return mockServers[selectedServerIndex]
    }

    function localConfigPaths() {
        const paths = [
            StandardPaths.writableLocation(StandardPaths.AppDataLocation) + "/" + localConfigFileName,
            StandardPaths.writableLocation(StandardPaths.DownloadLocation) + "/" + localConfigFileName,
            "/sdcard/Download/" + localConfigFileName,
            "/Users/igorbelocerkovec/projects/loxleyvpn-client-local/" + localConfigFileName
        ]
        return paths.filter(function(path) { return path !== "" && path !== "/" + localConfigFileName })
    }

    function connectSelectedServer() {
        const server = selectedServer()
        if (server.id === "") {
            statusText = qsTr("Сервер не выбран")
            return
        }

        if (server.status !== "online") {
            statusText = qsTr("Сервер сейчас недоступен")
            return
        }

        if (server.protocol !== "amneziawg") {
            statusText = qsTr("Резервный сервер есть в mock-списке. Подключение для него будет включено следующим этапом.")
            PageController.showNotificationMessage(statusText)
            return
        }

        let configData = ""
        const paths = localConfigPaths()
        for (let i = 0; i < paths.length; i++) {
            configData = ImportController.readTextFile(paths[i])
            if (configData !== "") {
                break
            }
        }

        if (configData === "") {
            statusText = qsTr("Тестовый config не найден. Положите файл test-awg-config.conf вне Git: в loxleyvpn-client-local или в Downloads на тестовом устройстве.")
            PageController.showNotificationMessage(statusText)
            return
        }

        if (!ImportController.extractConfigFromData(configData)) {
            statusText = qsTr("Тестовый config найден, но не распознан импортом Amnezia.")
            return
        }

        PageController.showBusyIndicator(true)
        const beforeCount = ServersUiController.getServersCount()
        ImportController.importConfig()
        const afterCount = ServersUiController.getServersCount()
        PageController.showBusyIndicator(false)

        if (afterCount <= beforeCount) {
            statusText = qsTr("Config не был добавлен. Возможно, такой профиль уже импортирован.")
            return
        }

        const importedServerId = ServersUiController.defaultServerId
        if (importedServerId !== "") {
            ServersUiController.editServerName(importedServerId, server.title)
        }

        statusText = ""
        PageController.goToPageHome()
        Qt.callLater(ConnectionController.openConnection)
    }
}
