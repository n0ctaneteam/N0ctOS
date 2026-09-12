import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "qml"

    property real amount: Number(root.param("amount", 0.12))

    function prepare() {
        if (root.oldItem) {
            root.oldItem.visible = true
            root.oldItem.opacity = 1.0
            root.oldItem.scale = 1.0
        }
        if (root.newItem) {
            root.newItem.visible = true
            root.newItem.opacity = 0.0
            root.newItem.scale = 1.0 + root.amount
        }
    }

    onProgressChanged: {
        if (!root.running)
            return

        const p = root.progress
        const a = root.amount

        if (root.oldItem) {
            root.oldItem.opacity = 1.0 - p
            root.oldItem.scale = 1.0 + p * a
        }

        if (root.newItem) {
            root.newItem.opacity = p
            root.newItem.scale = 1.0 + (1.0 - p) * a
        }
    }
}
