import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Style 1.0

import "../Config"
import "../Controls2"
import "../Controls2/TextTypes"

Rectangle {
    id: root

    property real contentHeight: content.implicitHeight + content.anchors.topMargin + content.anchors.bottomMargin
    property bool isFocusable: true
    property bool hasRemotePromotion: ServersUiController.isAdVisible
                                      && ServersUiController.adHeader !== ""
                                      && ServersUiController.serverAdEndpoint(ServersUiController.defaultServerId) !== ""
    property string promotionTitle: hasRemotePromotion
                                      ? ServersUiController.adHeader
                                      : qsTr("Invite a friend — get +7 days")
    property string promotionDescription: hasRemotePromotion
                                            ? ServersUiController.adDescription
                                            : qsTr("Your friend gets 30 days free. Send a card in Telegram or publish it to your story.")
    property string promotionUrl: hasRemotePromotion
                                    ? ServersUiController.serverAdEndpoint(ServersUiController.defaultServerId)
                                    : "https://t.me/onvixx_vpn_bot"

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: AmneziaStyle.color.translucentSlateGray }
        GradientStop { position: 1.0; color: AmneziaStyle.color.translucentOnyxBlack }
    }
    border.width: 1
    border.color: AmneziaStyle.color.onyxBlack
    radius: 13

    visible: SettingsController.isHomeAdLabelVisible
             && ServersUiController.isDefaultServerFromApi
             && !ConnectionController.isConnectionInProgress

    Keys.onTabPressed: {
        FocusController.nextKeyTabItem()
    }

    Keys.onBacktabPressed: {
        FocusController.previousKeyTabItem()
    }

    Keys.onUpPressed: {
        FocusController.nextKeyUpItem()
    }

    Keys.onDownPressed: {
        FocusController.nextKeyDownItem()
    }

    Keys.onLeftPressed: {
        FocusController.nextKeyLeftItem()
    }

    Keys.onRightPressed: {
        FocusController.nextKeyRightItem()
    }

    Keys.onEnterPressed: {
        Qt.openUrlExternally(promotionUrl)
    }

    Keys.onReturnPressed: {
        Qt.openUrlExternally(promotionUrl)
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 52
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 12

        Image {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            source: "qrc:/images/controls/telegram-brand.svg"
            sourceSize: Qt.size(36, 36)
            fillMode: Image.PreserveAspectFit
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            CaptionTextType {
                Layout.fillWidth: true
                text: root.promotionTitle
                color: AmneziaStyle.color.paleGray
                font.pixelSize: 14
                font.weight: 700
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
            }

            CaptionTextType {
                Layout.fillWidth: true
                text: root.promotionDescription
                color: AmneziaStyle.color.mutedGray
                wrapMode: Text.WordWrap
                lineHeight: 18
                lineHeightMode: Text.FixedHeight
                font.pixelSize: 14

                visible: text !== ""
            }
        }

    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onEntered: {
            root.border.color = AmneziaStyle.color.slateGray
        }

        onExited: {
            root.border.color = AmneziaStyle.color.onyxBlack
        }

        onPressedChanged: {
            root.opacity = pressed ? 0.78 : 1
        }

        onClicked: function() {
            root.forceActiveFocus()
            Qt.openUrlExternally(root.promotionUrl)
        }
    }

    ImageButtonType {
        id: closeButton

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        width: 36
        height: 36
        z: 2

        image: "qrc:/images/controls/close.svg"
        imageColor: AmneziaStyle.color.mutedGray
        icon.width: 18
        icon.height: 18

        Accessible.name: qsTr("Hide referral offer")

        onClicked: {
            SettingsController.disableHomeAdLabel()
        }
    }
}
