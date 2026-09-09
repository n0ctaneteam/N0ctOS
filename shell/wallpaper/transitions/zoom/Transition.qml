import QtQuick
import qs.wallpaper.components

Transition {
    property real startScale:
        Number(parameter("startScale", 1.08))

    property real fadeFrom:
        Number(parameter("fadeFrom", 1))

    onProgressChanged: {
        if (!initialized || !from || !to)
            return

        from.x = 0
        from.y = 0
        from.scale = 1
        from.opacity = 1 - progress

        to.x = 0
        to.y = 0
        to.scale =
            startScale -
            ((startScale - 1) * progress)

        to.opacity = progress
    }

    function initialize() {
        if (!from || !to)
            return

        from.transformOrigin = Item.Center
        to.transformOrigin = Item.Center

        from.x = 0
        from.y = 0
        from.scale = 1
        from.opacity = 1
        from.z = 0

        to.x = 0
        to.y = 0
        to.scale = startScale
        to.opacity = 0
        to.z = 1

        initialized = true
    }

    function finish() {
        if (from) {
            from.x = 0
            from.y = 0
            from.scale = 1
            from.opacity = 0
        }

        if (to) {
            to.x = 0
            to.y = 0
            to.scale = 1
            to.opacity = 1
        }
    }

    function cancel() {
        if (from) {
            from.x = 0
            from.y = 0
            from.scale = 1
            from.opacity = 1
        }

        if (to) {
            to.x = 0
            to.y = 0
            to.scale = startScale
            to.opacity = 0
        }
    }
}