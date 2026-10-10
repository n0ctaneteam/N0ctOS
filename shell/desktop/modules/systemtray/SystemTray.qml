import QtQuick
import QtQuick.Controls
import Quickshell.Widgets

import qs.services
import qs.desktop.components

/*
 * SystemTray module.
 *
 * Renders the native StatusNotifier / AppIndicator items owned by the
 * qs.services SystemTray singleton.
 *
 * Tray-item menus are NOT built here. SystemTray.openMenu() converts the
 * native QsMenuEntry (DBus) tree into ContextMenuObj rows and opens them
 * through the shared ContextMenu controller:
 *
 *     trayItem.openMenu()
 *
 * Click routing mirrors desktop/TrayTest.qml:
 *
 *     right  -> menu, else secondary action
 *     left   -> activate, else menu (onlyMenu items always menu)
 *     middle -> secondary action
 *     wheel  -> scroll (when supported)
 *
 * NOTE: Blob.qml stacks its right-click shield BELOW module content, so
 * tray icons receive right-clicks first and only right-clicks nothing in
 * the module handles fall through to the blob module switcher.
 * Press-and-hold is kept as an extra touch-friendly way to open a menu.
 */
Module {
    id: root

    moduleId: "systemtray"
    focusTarget: null

    property int itemSize: 34
    property int itemSpacing: 6
    property int cardPadding: 12
    property bool showHidden: false

    implicitWidth: mainCard.implicitWidth
    implicitHeight: mainCard.implicitHeight

    // Explicit size so `anchors.fill: parent` children work whether or
    // not the host Loader resizes the loaded item to its implicit size.
    width: implicitWidth
    height: implicitHeight

    onDeactivated: {
        if (SystemTray.isMenuOpen)
            SystemTray.closeMenu()
    }

    function tooltipFor(item) {
        if (!item)
            return ""

        if (item.tooltip && String(item.tooltip).length > 0)
            return String(item.tooltip)

        if (item.title && String(item.title).length > 0)
            return String(item.title)

        return String(item.id || "")
    }

    function handleLeftClick(item) {
        if (!item)
            return

        if (item.onlyMenu && item.hasMenu) {
            item.openMenu()
        } else if (item.hasActivate) {
            item.activate()
        } else if (item.hasMenu) {
            item.openMenu()
        }
    }

    function handleRightClick(item) {
        if (!item)
            return

        if (item.hasMenu) {
            item.openMenu()
        } else if (item.hasSecondaryActivate) {
            item.secondaryActivate()
        }
    }

    function handleMiddleClick(item) {
        if (!item)
            return

        if (item.hasSecondaryActivate)
            item.secondaryActivate()
    }

    function handleWheel(item, angleDelta) {
        if (!item || !item.hasScroll)
            return false

        const dx = Number(angleDelta.x) || 0
        const dy = Number(angleDelta.y) || 0

        if (Math.abs(dx) > Math.abs(dy) && dx !== 0) {
            item.scroll(dx, true)
        } else if (dy !== 0) {
            item.scroll(dy, false)
        } else {
            return false
        }

        return true
    }

    Rectangle {
        id: mainCard

        implicitWidth: mainColumn.implicitWidth + root.cardPadding * 2
        implicitHeight: mainColumn.implicitHeight + root.cardPadding * 2
        width: implicitWidth
        height: implicitHeight

        radius: 14
        color: "#10151d"
        border.width: 1
        border.color: "#253241"

        Column {
            id: mainColumn

            anchors.centerIn: parent
            spacing: 8

            // ====================================================
            // HEADER
            // ====================================================

            Row {
                id: headerRow

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                height: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TRAY"
                    color: "#7f8b99"
                    font.pixelSize: 9
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SystemTray.count > 0
                    text: SystemTray.pinnedCount + " / " + SystemTray.count
                    color: "#45525c"
                    font.pixelSize: 9
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SystemTray.hasAttention
                    width: 8
                    height: 8
                    radius: 4
                    color: "#2acfff"
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SystemTray.hiddenCount > 0
                    width: hiddenToggleText.implicitWidth + 14
                    height: 18
                    radius: 6
                    color: hiddenToggleMouse.containsMouse ? "#1a3039" : "#18232c"

                    Text {
                        id: hiddenToggleText

                        anchors.centerIn: parent
                        text: (root.showHidden ? "󰁌 " : "󰁍 ") + SystemTray.hiddenCount
                        color: "#2acfff"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: hiddenToggleMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.showHidden = !root.showHidden
                    }
                }
            }

            // ====================================================
            // PINNED ITEMS
            // ====================================================

            Row {
                id: pinnedRow

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.itemSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SystemTray.pinnedCount === 0
                    text: "No tray items"
                    color: "#4b5963"
                    font.pixelSize: 12
                    font.family: "Symbols Nerd Font"
                }

                Repeater {
                    model: SystemTray.pinnedItems

                    delegate: Rectangle {
                        required property var modelData
                        property var trayItem: modelData

                        width: root.itemSize
                        height: root.itemSize
                        radius: 8
                        color: trayMouse.containsMouse ? "#1a3039" : "transparent"
                        opacity: trayItem && trayItem.isPassive ? 0.85 : 1.0

                        Behavior on color {
                            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        IconImage {
                            anchors.fill: parent
                            anchors.margins: 5
                            source: trayItem ? (trayItem.icon || "") : ""
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !trayItem || String(trayItem.icon || "").length === 0
                            text: trayItem ? String(trayItem.title || trayItem.id || "?").substring(0, 1).toUpperCase() : "?"
                            color: "#d7e2e8"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                        }

                        Rectangle {
                            visible: trayItem ? trayItem.isAttention : false
                            width: 8
                            height: 8
                            radius: 4
                            color: "#2acfff"
                            border.color: "#090d12"
                            border.width: 1
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 2
                            anchors.topMargin: 2
                        }

                        MouseArea {
                            id: trayMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            ToolTip.visible: trayMouse.containsMouse && tooltipText.length > 0
                            ToolTip.delay: 500
                            ToolTip.text: tooltipText

                            readonly property string tooltipText: root.tooltipFor(trayItem)

                            onClicked: function(mouse) {
                                if (!trayItem)
                                    return

                                if (mouse.button === Qt.RightButton) {
                                    root.handleRightClick(trayItem)
                                } else if (mouse.button === Qt.MiddleButton) {
                                    root.handleMiddleClick(trayItem)
                                } else {
                                    root.handleLeftClick(trayItem)
                                }
                            }

                            // Touch-friendly extra: a long press opens the
                            // same native item menu as right-click.
                            onPressAndHold: function(mouse) {
                                if (!trayItem)
                                    return

                                if (trayItem.hasMenu)
                                    trayItem.openMenu()
                            }

                            onWheel: function(wheel) {
                                if (!trayItem)
                                    return

                                wheel.accepted = root.handleWheel(trayItem, wheel.angleDelta)
                            }
                        }
                    }
                }
            }

            // ====================================================
            // HIDDEN ITEMS (overflow, dimmed)
            // ====================================================

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.itemSpacing
                visible: root.showHidden && SystemTray.hiddenCount > 0

                Repeater {
                    model: SystemTray.hiddenItems

                    delegate: Rectangle {
                        required property var modelData
                        property var trayItem: modelData

                        width: root.itemSize
                        height: root.itemSize
                        radius: 8
                        color: hiddenTrayMouse.containsMouse ? "#1a3039" : "transparent"
                        opacity: 0.55

                        IconImage {
                            anchors.fill: parent
                            anchors.margins: 5
                            source: trayItem ? (trayItem.icon || "") : ""
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !trayItem || String(trayItem.icon || "").length === 0
                            text: trayItem ? String(trayItem.title || trayItem.id || "?").substring(0, 1).toUpperCase() : "?"
                            color: "#d7e2e8"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: hiddenTrayMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            ToolTip.visible: hiddenTrayMouse.containsMouse && tooltipText.length > 0
                            ToolTip.delay: 500
                            ToolTip.text: tooltipText

                            readonly property string tooltipText: root.tooltipFor(trayItem)

                            onClicked: function(mouse) {
                                if (!trayItem)
                                    return

                                if (mouse.button === Qt.RightButton) {
                                    root.handleRightClick(trayItem)
                                } else if (mouse.button === Qt.MiddleButton) {
                                    root.handleMiddleClick(trayItem)
                                } else {
                                    root.handleLeftClick(trayItem)
                                }
                            }

                            onPressAndHold: function(mouse) {
                                if (!trayItem)
                                    return

                                if (trayItem.hasMenu)
                                    trayItem.openMenu()
                            }

                            onWheel: function(wheel) {
                                if (!trayItem)
                                    return

                                wheel.accepted = root.handleWheel(trayItem, wheel.angleDelta)
                            }
                        }
                    }
                }
            }
        }
    }
}
