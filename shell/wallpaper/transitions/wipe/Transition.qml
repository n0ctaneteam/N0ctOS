import QtQuick
import qs.wallpaper.components

Transition {
    property string direction:
        String(parameter("direction", "left"))

    onProgressChanged: {
        if (!initialized || !from || !to)
            return

        var w = width
        var h = height

        /*
         * Wallpaper contents remain full-size.
         */
        from.x = 0
        from.y = 0
        from.width = w
        from.height = h
        from.opacity = 1

        to.x = 0
        to.y = 0
        to.width = w
        to.height = h
        to.opacity = 1

        /*
         * Only the incoming viewport is masked.
         */
        if (fromViewport) {
            fromViewport.x = 0
            fromViewport.y = 0
            fromViewport.width = w
            fromViewport.height = h
            fromViewport.clip = true
        }

        if (!toViewport)
            return

        toViewport.clip = true
        toViewport.opacity = 1

        switch (direction) {
        case "right":
            toViewport.x = w * (1 - progress)
            toViewport.y = 0
            toViewport.width = w * progress
            toViewport.height = h
            break

        case "up":
            toViewport.x = 0
            toViewport.y = h * (1 - progress)
            toViewport.width = w
            toViewport.height = h * progress
            break

        case "down":
            toViewport.x = 0
            toViewport.y = 0
            toViewport.width = w
            toViewport.height = h * progress
            break

        default:
            toViewport.x = 0
            toViewport.y = 0
            toViewport.width = w * progress
            toViewport.height = h
            break
        }
    }

    function initialize() {
        if (!from || !to)
            return

        from.x = 0
        from.y = 0
        from.width = width
        from.height = height
        from.opacity = 1
        from.z = 0

        to.x = 0
        to.y = 0
        to.width = width
        to.height = height
        to.opacity = 1
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
            toViewport.width = 0
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
            from.width = width
            from.height = height
            from.opacity = 0
        }

        if (to) {
            to.x = 0
            to.y = 0
            to.width = width
            to.height = height
            to.opacity = 1
        }

        if (fromViewport) {
            fromViewport.x = 0
            fromViewport.y = 0
            fromViewport.width = width
            fromViewport.height = height
        }

        if (toViewport) {
            toViewport.x = 0
            toViewport.y = 0
            toViewport.width = width
            toViewport.height = height
        }
    }

    function cancel() {
        if (from) {
            from.x = 0
            from.y = 0
            from.width = width
            from.height = height
            from.opacity = 1
        }

        if (to) {
            to.x = 0
            to.y = 0
            to.width = width
            to.height = height
            to.opacity = 0
        }

        if (fromViewport) {
            fromViewport.x = 0
            fromViewport.y = 0
            fromViewport.width = width
            fromViewport.height = height
        }

        if (toViewport) {
            toViewport.x = 0
            toViewport.y = 0
            toViewport.width = width
            toViewport.height = height
        }
    }
}