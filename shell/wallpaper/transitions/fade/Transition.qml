import QtQuick
import qs.wallpaper.components

Transition {
    onProgressChanged: {
        if (!initialized || !from || !to)
            return

        from.x = 0
        from.y = 0
        from.scale = 1
        from.rotation = 0
        from.opacity = 1 - progress

        to.x = 0
        to.y = 0
        to.scale = 1
        to.rotation = 0
        to.opacity = progress

        if (fromViewport)
            fromViewport.opacity = 1

        if (toViewport)
            toViewport.opacity = 1
    }

    function initialize() {
        if (!from || !to)
            return

        from.x = 0
        from.y = 0
        from.scale = 1
        from.rotation = 0
        from.opacity = 1
        from.z = 0

        to.x = 0
        to.y = 0
        to.scale = 1
        to.rotation = 0
        to.opacity = 0
        to.z = 1

        if (fromViewport) {
            fromViewport.x = 0
            fromViewport.y = 0
            fromViewport.width = width
            fromViewport.height = height
            fromViewport.opacity = 1
            fromViewport.clip = true
        }

        if (toViewport) {
            toViewport.x = 0
            toViewport.y = 0
            toViewport.width = width
            toViewport.height = height
            toViewport.opacity = 1
            toViewport.clip = true
        }

        initialized = true
    }

    function finish() {
        if (from) {
            from.x = 0
            from.y = 0
            from.scale = 1
            from.rotation = 0
            from.opacity = 0
        }

        if (to) {
            to.x = 0
            to.y = 0
            to.scale = 1
            to.rotation = 0
            to.opacity = 1
        }
    }

    function cancel() {
        if (from) {
            from.x = 0
            from.y = 0
            from.scale = 1
            from.rotation = 0
            from.opacity = 1
        }

        if (to) {
            to.x = 0
            to.y = 0
            to.scale = 1
            to.rotation = 0
            to.opacity = 0
        }
    }
}