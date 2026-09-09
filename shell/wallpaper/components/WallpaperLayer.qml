import QtQuick
import QtMultimedia
import "../lib"

Item {
    id: root

    property var definition: null

    anchors.fill: parent

    property string source:
        root.definition &&
        root.definition.source
            ? String(root.definition.source)
            : ""

    property string type:
        root.definition &&
        root.definition.type
            ? String(root.definition.type)
            : "image"

    property string fitting:
        root.definition &&
        root.definition.fitting
            ? String(root.definition.fitting)
            : "crop"

    property string resolvedSource:
        WallpaperManager.toUrl(root.source)

    property string resolvedPath:
        WallpaperManager.expandPath(root.source)

    property bool isGif:
        root.type === "gif" ||
        root.resolvedPath.toLowerCase().endsWith(".gif")

    property bool isVideo:
        root.type === "video" ||
        root.resolvedPath.toLowerCase().endsWith(".mp4") ||
        root.resolvedPath.toLowerCase().endsWith(".mkv") ||
        root.resolvedPath.toLowerCase().endsWith(".webm") ||
        root.resolvedPath.toLowerCase().endsWith(".avi") ||
        root.resolvedPath.toLowerCase().endsWith(".mov") ||
        root.resolvedPath.toLowerCase().endsWith(".m4v") ||
        root.resolvedPath.toLowerCase().endsWith(".mpg") ||
        root.resolvedPath.toLowerCase().endsWith(".mpeg") ||
        root.resolvedPath.toLowerCase().endsWith(".ogv")

    property bool ready: false

    function imageFillMode() {
        switch (root.fitting) {
        case "stretch":
            return Image.Stretch
        case "contain":
            return Image.PreserveAspectFit
        default:
            return Image.PreserveAspectCrop
        }
    }

    function videoFillMode() {
        switch (root.fitting) {
        case "stretch":
            return VideoOutput.Stretch
        case "contain":
            return VideoOutput.PreserveAspectFit
        default:
            return VideoOutput.PreserveAspectCrop
        }
    }

    function updateReady() {
        if (!root.source) {
            root.ready = true
            return
        }

        if (root.isVideo) {
            root.ready =
                wallpaperVideo.playbackState ===
                MediaPlayer.Playing
            return
        }

        if (root.isGif) {
            root.ready =
                wallpaperGif.status ===
                AnimatedImage.Ready
            return
        }

        root.ready =
            wallpaperImage.status ===
            Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Image {
        id: wallpaperImage

        anchors.fill: parent

        visible:
            !root.isVideo &&
            !root.isGif

        source:
            !root.isVideo &&
            !root.isGif
                ? root.resolvedSource
                : ""

        fillMode:
            root.imageFillMode()

        asynchronous: true
        cache: true

        onStatusChanged: {
            root.updateReady()

            if (status === Image.Error) {
                console.warn(
                    "[WallpaperLayer] IMAGE ERROR:",
                    root.resolvedSource
                )
            }
        }
    }

    AnimatedImage {
        id: wallpaperGif

        anchors.fill: parent

        visible:
            !root.isVideo &&
            root.isGif

        source:
            !root.isVideo &&
            root.isGif
                ? root.resolvedSource
                : ""

        fillMode:
            root.imageFillMode()

        asynchronous: true
        cache: true

        onStatusChanged: {
            root.updateReady()

            if (status === AnimatedImage.Error) {
                console.warn(
                    "[WallpaperLayer] GIF ERROR:",
                    root.resolvedSource
                )
            }
        }
    }

    Video {
        id: wallpaperVideo

        anchors.fill: parent

        visible:
            root.isVideo

        source:
            root.isVideo
                ? root.resolvedSource
                : ""

        fillMode:
            root.videoFillMode()

        loops: MediaPlayer.Infinite
        muted: true
        autoPlay: true

        onSourceChanged: {
            root.ready = false

            if (source)
                play()
            else
                root.updateReady()
        }

        onPlaybackStateChanged: {
            root.updateReady()
        }

        onErrorChanged: {
            if (error !== MediaPlayer.NoError) {
                console.warn(
                    "[WallpaperLayer] VIDEO ERROR:",
                    error,
                    errorString
                )
            }
        }
    }

    onSourceChanged: {
        root.ready = false
        Qt.callLater(root.updateReady)
    }

    onTypeChanged: {
        root.ready = false
        Qt.callLater(root.updateReady)
    }

    Component.onCompleted: {
        Qt.callLater(root.updateReady)
    }
}