import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.desktop.components
import qs.core.lib
import qs.services

Item {
    id: root

    required property var screen

    anchors.fill: parent

    WidgetLayer {
        // isDebug:true
        // editMode: true
        _screen: root.screen
        WlrLayershell.layer:
            WlrLayer.Background
    }

    // NotiTest{}
    // TrayTest{}

    ScreenFrame {
        id: frame

        screen: root.screen
        frameLayer: WlrLayer.Top
        frameWidth: 5
        frameColor: "#01080c"
        borderWidth: 2
        borderColor: "#2acfff"
        blobAnimationDuration: 300
        cut: 30

        shadows: ({
            intensity: 30,
            color: "#2acfff",
            blur: 1.0,
            opacity: 1
        })

        isPrimaryScreen:
            ScreenManager.primaryScreenName === root.screen.name
    }

    Component.onCompleted: {
        console.log(
            "[Desktop]",
            root.screen ? root.screen.name : "(null)",
            "CREATED"
        )
    }
}
