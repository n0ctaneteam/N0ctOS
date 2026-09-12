import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "qml"

    function prepare() {
        if (root.oldItem) {
            root.oldItem.visible = true
            root.oldItem.opacity = 1.0
        }
        if (root.newItem) {
            root.newItem.visible = true
            root.newItem.opacity = 0.0
        }
    }

    onProgressChanged: {
        if (!root.running)
            return

        const p = root.progress

        if (root.oldItem)
            root.oldItem.opacity = 1.0 - p

        if (root.newItem)
            root.newItem.opacity = p
    }
}
