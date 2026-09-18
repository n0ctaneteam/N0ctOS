import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.wallpaper.components
import qs.wallpaper.lib

PanelWindow {
    id: root

    property bool isDebug: false

    property var definition:
        WallpaperManager.definitionFor(root.screen)

    readonly property string source:
        root.definition && root.definition.source !== undefined
            ? String(root.definition.source)
            : ""

    readonly property string type:
        root.definition && root.definition.type !== undefined
            ? String(root.definition.type)
            : "image"

    readonly property string fitting:
        root.definition && root.definition.fitting !== undefined
            ? String(root.definition.fitting)
            : "crop"


    WlrLayershell.layer: WlrLayer.Background
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "black"

    TransitionHost {
        id: transitionHost
        anchors.fill: parent
        screen: root.screen
        definition: root.definition
    }

    Rectangle {
        anchors.fill: parent
        z: 1000
        color: "#ff1493"
        opacity: root.isDebug ? 0.18 : 0
    }

    Rectangle {
        visible: root.isDebug
        z: 1100
        anchors {
            top: parent.top
            left: parent.left
            margins: 20
        }

        width: debugText.implicitWidth + 40
        height: debugText.implicitHeight + 32
        radius: 8
        color: "#111111"
        opacity: 0.94
        border.width: 1
        border.color: "#ffffff"

        Text {
            id: debugText
            anchors.centerIn: parent
            color: "white"
            font.family: "monospace"
            font.pixelSize: 14
            font.bold: true

            text:
                "WALLPAPER DEBUG\n" +
                "══════════════════════════════\n" +
                "Monitor    : " +
                    (root.screen ? root.screen.name : "(null)") +
                    "\n" +
                "Size       : " +
                    Math.round(root.width) +
                    " × " +
                    Math.round(root.height) +
                    "\n" +
                "Type       : " +
                    root.type +
                    "\n" +
                "Source     : " +
                    (root.source || "(none)") +
                    "\n" +
                "Resolved   : " +
                    (
                        root.source
                            ? (WallpaperManager.expandPath(root.source) || "(none)")
                            : "(none)"
                    ) +
                    "\n" +
                "Fitting    : " +
                    root.fitting +
                    "\n" +
                "Transition : " +
                    TransitionManager.id +
                    "\n" +
                "Duration   : " +
                    TransitionManager.duration +
                    " ms\n" +
                "Running    : " +
                    (transitionHost.busy ? "true" : "false") +
                    "\n" +
                "Current    : " +
                    (
                        transitionHost.currentDefinition
                            ? String(
                                transitionHost.currentDefinition.source || "(none)"
                              )
                            : "(none)"
                    ) +
                    "\n" +
                "Progress   : " +
                    transitionHost.progress.toFixed(3) +
                    "\n" +
                "Running    : " +
                    (transitionHost.busy ? "true" : "false") +
                    "\n"
        }
    }

    Connections {
        target: WallpaperManager

        function onWallpaperChanged(monitorName) {
            if (!root.screen || root.screen.name !== monitorName)
                return

            console.log(
                "[Wallpaper]",
                monitorName,
                "definition changed"
            )

            root.definition =
                WallpaperManager.definitionFor(root.screen)
        }
    }

    Component.onCompleted: {
        console.log(
            "[Wallpaper]",
            root.screen
                ? root.screen.name
                : "(null)",
            "CREATED"
        )
    }
}
