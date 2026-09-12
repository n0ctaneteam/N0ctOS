import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "shader"

    property real glitchIntensity: Number(root.param("intensity", 0.08))

    ShaderEffectSource {
        id: texOld
        anchors.fill: parent
        sourceItem: root.oldItem
        live: true
        recursive: true
        visible: false
    }

    ShaderEffectSource {
        id: texNew
        anchors.fill: parent
        sourceItem: root.newItem
        live: true
        recursive: true
        visible: false
    }

    ShaderEffect {
        id: glitchEffect
        anchors.fill: parent
        visible: root.running

        property var fromTexture: texOld
        property var toTexture: texNew
        property real progress: root.progress
        property real intensity: root.glitchIntensity

        fragmentShader: Qt.resolvedUrl("glitch.frag.qsb")

        onStatusChanged: {
            if (status === ShaderEffect.Error)
                root.fail("Glitch shader error: " + String(log || "unknown"))
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
