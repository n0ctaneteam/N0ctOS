import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "shader"

    property real intensity:
        Number(
            root.param(
                "intensity",
                0.018
            )
        )

    /*
     * Old wallpaper texture.
     *
     * hideSource is intentionally NOT used.
     */
    ShaderEffectSource {
        id: oldSource

        anchors.fill: parent

        sourceItem:
            root.oldItem

        live: true
        recursive: true

        visible: false
    }

    /*
     * Incoming wallpaper texture.
     */
    ShaderEffectSource {
        id: newSource

        anchors.fill: parent

        sourceItem:
            root.newItem

        live: true
        recursive: true

        visible: false
    }

    ShaderEffect {
        id: effect

        anchors.fill: parent

        visible:
            root.running

        property var fromTexture:
            oldSource

        property var toTexture:
            newSource

        property real progress:
            root.progress

        property real intensity:
            root.intensity

        fragmentShader:
            Qt.resolvedUrl(
                "channel_split.frag.qsb"
            )

        onStatusChanged: {
            if (
                status ===
                ShaderEffect.Error
            ) {
                root.fail(
                    "ShaderEffect error: " +
                    String(
                        log ||
                        "unknown shader error"
                    )
                )
            }
        }
    }

    function prepare() {
        /*
         * Host owns actual layer visibility.
         *
         * Both sources remain alive for the complete transition.
         */
        if (root.oldItem) {
            root.oldItem.visible = true
            root.oldItem.opacity = 1
        }

        if (root.newItem) {
            root.newItem.visible = true
            root.newItem.opacity = 1
        }
    }

    Component.onCompleted: {
        console.log(
            "[ChannelSplit] READY"
        )
    }
}