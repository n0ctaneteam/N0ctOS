//@ pragma UseQApplication

import QtQuick
import Quickshell

import qs.desktop
import qs.wallpaper
import qs.core.ui
import qs.services 

ShellRoot {
    id: root

    ServiceHost {
        id: serviceHost
    } 

    Variants {
        model: Quickshell.screens
        delegate: Wallpaper {
              required property var modelData
                screen: modelData
            }
            Component.onCompleted: {
                console.log(
                    "VARIANT CREATED:",
                    modelData.name
                )
            }
    }
    
    
    Variants {
        model: Quickshell.screens
        delegate: Desktop {
              required property var modelData
                screen: modelData
            }
            Component.onCompleted: {
                console.log(
                    "VARIANT CREATED:",
                    modelData.name
                )
            }
        }


    // Component.onCompleted: {
        // console.log("[shell] START")
        // console.log(
            // "[shell] Quickshell.screens:",
            // Quickshell.screens.length
        // )
    // }

    Component.onCompleted: {
        console.log("=== SHELL DEBUG ===")
        console.log("screens:", Quickshell.screens.length)
    
        for (const s of Quickshell.screens) {
            console.log(
                "screen:",
                s.name,
                "x:", s.x,
                "y:", s.y,
                "width:", s.width,
                "height:", s.height
            )
        }
    }
}
