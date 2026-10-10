import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

import qs.core.lib
import qs.core.ui
import qs.services

PanelWindow {
    id: trayPanel

    anchors {
        bottom: true
        left: false
        right: false
    }
    margins.bottom: 12
    width: mainLayout.implicitWidth + 24
    height: 48
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: "#090d12"
        radius: 8
        border.color: "#263541"
        border.width: 1

        RowLayout {
            id: mainLayout
            anchors.centerIn: parent
            spacing: 16

            // ==========================================
            // 1. YOUR WIDGETS (Uses N0ctOS Menu)
            // ==========================================
            Rectangle {
                width: 32; height: 32; radius: 6
                color: "#1a3039"

                Text { anchors.centerIn: parent; text: "⚙️" }

                // Define N0ctOS Menu for your own widgets
                Component {
                    id: mySettingsMenu
                    Column {
                        ContextMenuObj {
                            text: "Shell Settings"
                            functionAction: function() { console.log("Settings clicked") }
                        }
                        ContextMenuObj {
                            text: "Restart Shell"
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: ContextMenu.open(mySettingsMenu)
                }
            }

            // Separator
            Rectangle { width: 1; height: 24; color: "#263541" }

            // ==========================================
            // 2. SYSTEM TRAY (Uses N0ctOS ContextMenu)
            //
            // No QsMenuAnchor here. Menus are owned by the
            // qs.services SystemTray singleton, which converts
            // the native DBus (QsMenuEntry) tree into
            // ContextMenuObj rows and opens them via:
            //
            //     ContextMenu.open(component, WlrLayer.Overlay)
            //
            // This delegate only routes clicks / scroll to the
            // service adapter:
            //
            //     trayItem.openMenu()
            //     trayItem.activate()
            //     trayItem.secondaryActivate()
            //     trayItem.scroll(delta, horizontal)
            // ==========================================
            RowLayout {
                spacing: 6

                // Empty state — service has no items yet
                Text {
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

                        width: 32; height: 32; radius: 6
                        color: trayMouse.containsMouse ? "#1a3039" : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        IconImage {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: trayItem ? (trayItem.icon || "") : ""
                            asynchronous: true
                        }

                        // Attention dot (NeedsAttention status)
                        Rectangle {
                            visible: trayItem ? trayItem.isAttention : false
                            width: 8; height: 8; radius: 4
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

                            // Tooltip via accessible name — hover shows title/tooltip
                            // (kept lightweight for TrayTest; a real bar would
                            //  use a floating tooltip window)
                            ToolTip.visible: trayMouse.containsMouse && tooltipText.length > 0
                            ToolTip.delay: 500
                            ToolTip.text: tooltipText

                            readonly property string tooltipText: {
                                if (!trayItem)
                                    return ""
                                if (trayItem.tooltip && trayItem.tooltip.length > 0)
                                    return trayItem.tooltip
                                if (trayItem.title && trayItem.title.length > 0)
                                    return trayItem.title
                                return trayItem.id || ""
                            }

                            onClicked: (mouse) => {
                                if (!trayItem)
                                    return

                                if (mouse.button === Qt.RightButton) {
                                    if (trayItem.hasMenu) {
                                        trayItem.openMenu()
                                    } else if (trayItem.hasSecondaryActivate) {
                                        trayItem.secondaryActivate()
                                    }
                                } else if (mouse.button === Qt.LeftButton) {
                                    if (trayItem.onlyMenu && trayItem.hasMenu) {
                                        trayItem.openMenu()
                                    } else if (trayItem.hasActivate) {
                                        trayItem.activate()
                                    } else if (trayItem.hasMenu) {
                                        trayItem.openMenu()
                                    }
                                } else if (mouse.button === Qt.MiddleButton) {
                                    if (trayItem.hasSecondaryActivate) {
                                        trayItem.secondaryActivate()
                                    }
                                }
                            }

                            onWheel: (wheel) => {
                                if (!trayItem || !trayItem.hasScroll) {
                                    wheel.accepted = false
                                    return
                                }

                                const dx = Number(wheel.angleDelta.x) || 0
                                const dy = Number(wheel.angleDelta.y) || 0

                                if (Math.abs(dx) > Math.abs(dy) && dx !== 0) {
                                    trayItem.scroll(dx, true)
                                } else if (dy !== 0) {
                                    trayItem.scroll(dy, false)
                                } else {
                                    wheel.accepted = false
                                    return
                                }

                                wheel.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}
