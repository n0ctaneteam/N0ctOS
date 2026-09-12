import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "shader"

    // Wipe tuning from manifest.json
    property real wipeFeather: Number(root.param("feather", 0.02))
    property string wipeDirection: String(root.param("direction", "left"))

    // 0 = left, 1 = right, 2 = top/up, 3 = bottom/down
    readonly property real wipeDirCode: {
        const d = root.wipeDirection.toLowerCase().trim()
        if (d === "right") return 1.0
        if (d === "up" || d === "top") return 2.0
        if (d === "down" || d === "bottom") return 3.0
        return 0.0
    }

    ShaderEffectSource {
        id: srcOld
        anchors.fill: parent
        sourceItem: root.oldItem
        live: true
        recursive: true
        visible: false
    }

    ShaderEffectSource {
        id: srcNew
        anchors.fill: parent
        sourceItem: root.newItem
        live: true
        recursive: true
        visible: false
    }

    ShaderEffect {
        id: wipeEffect
        anchors.fill: parent
        visible: root.running

        property var fromTexture: srcOld
        property var toTexture: srcNew
        property real progress: root.progress
        property real feather: root.wipeFeather
        property real direction: root.wipeDirCode

        fragmentShader: Qt.resolvedUrl("wipe.frag.qsb")

        onStatusChanged: {
            if (status === ShaderEffect.Error)
                root.fail("Wipe shader error: " + String(log || "unknown"))
        }
    }

    function prepare() {
        if (root.oldItem) {
            root.oldItem.visible = true
            root.oldItem.opacity = 1.0
        }
        if (root.newItem) {
            root.newItem.visible = true
            root.newItem.opacity = 1.0
        }
    }
}
