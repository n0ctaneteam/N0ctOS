import QtQuick
import qs.wallpaper.components

Transition {
    property string direction:
        String(parameter("direction", "left"))

    property real distance:
        Number(parameter("distance", 1))

    onProgressChanged: {
        if (!initialized || !from || !to)
            return

        var dx = width * distance
        var dy = height * distance

        from.opacity = 1
        to.opacity = 1
        from.scale = 1
        to.scale = 1

        switch (direction) {
        case "right":
            from.x = dx * progress
            from.y = 0
            to.x = -dx + dx * progress
            to.y = 0
            break

        case "up":
            from.x = 0
            from.y = -dy * progress
            to.x = 0
            to.y = dy - dy * progress
            break

        case "down":
            from.x = 0
            from.y = dy * progress
            to.x = 0
            to.y = -dy + dy * progress
            break

        default:
            from.x = -dx * progress
            from.y = 0
            to.x = dx - dx * progress
            to.y = 0
            break
        }
    }

    function initialize() {
        if (!from || !to)
            return

        from.x = 0
        from.y = 0
        from.opacity = 1
        from.scale = 1
        from.rotation = 0
        from.z = 0

        to.opacity = 1
        to.scale = 1
        to.rotation = 0
        to.z = 1

        switch (direction) {
        case "right":
            to.x = -width * distance
            to.y = 0
            break

        case "up":
            to.x = 0
            to.y = height * distance
            break

        case "down":
            to.x = 0
            to.y = -height * distance
            break

        default:
            to.x = width * distance
            to.y = 0
            break
        }

        initialized = true
    }

    function finish() {
        if (from) {
            from.x = 0
            from.y = 0
            from.opacity = 0
        }

        if (to) {
            to.x = 0
            to.y = 0
            to.opacity = 1
        }
    }

    function cancel() {
        if (from) {
            from.x = 0
            from.y = 0
            from.opacity = 1
        }

        if (to) {
            to.x = 0
            to.y = 0
            to.opacity = 0
        }
    }
}