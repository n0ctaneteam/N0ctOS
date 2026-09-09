import QtQuick
import Quickshell

import qs.desktop
import qs.wallpaper

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: Item {
            id: screenDelegate

            required property var modelData
            property var screen: modelData

            Wallpaper {
                screen: screenDelegate.screen
            }

            Desktop {
                screen: screenDelegate.screen
            }

            Component.onCompleted: {
                console.log(
                    "[shell] SCREEN CLONE:",
                    screen ? screen.name : "(null)"
                )
            }
        }
    }

    Component.onCompleted: {
        console.log("[shell] START")
        console.log(
            "[shell] Quickshell.screens:",
            Quickshell.screens.length
        )
    }
}