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

    /*
     * ready:
     *
     * The media has successfully initialized or completed an attempt.
     *
     * frameReady:
     *
     * The layer is safe for the transition system to use.
     */
    property bool ready: false
    property bool frameReady: false

    /*
     * We intentionally do NOT wait for the complete video.
     *
     * This is only the initial decoder warm-up.
     */
    property int videoWarmupMs: 250
    property bool videoWarmupStarted: false

    property bool frozen: false

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

    function resetReadiness() {
        root.ready = false
        root.frameReady = false
        root.videoWarmupStarted = false

        videoWarmupTimer.stop()
    }

    function updateReadiness() {
        if (!root.source) {
            root.ready = true
            root.frameReady = true
            return
        }

        /*
         * IMAGE
         */
        if (!root.isVideo && !root.isGif) {
            root.ready =
                wallpaperImage.status ===
                Image.Ready

            root.frameReady =
                root.ready

            return
        }

        /*
         * GIF
         */
        if (root.isGif) {
            root.ready =
                wallpaperGif.status ===
                AnimatedImage.Ready

            root.frameReady =
                root.ready

            return
        }

        /*
         * VIDEO
         *
         * Do not require PlayingState.
         *
         * Some multimedia backends can successfully initialize the
         * decoder and begin rendering before the QML playback state
         * observed by this object changes in the way we expect.
         */
        if (root.isVideo) {
            var state =
                wallpaperVideo.playbackState

            if (
                state === MediaPlayer.Playing ||
                state === MediaPlayer.Paused
            ) {
                root.ready = true

                if (!root.videoWarmupStarted) {
                    root.videoWarmupStarted = true
                    videoWarmupTimer.restart()
                }

                return
            }

            /*
             * Still loading. Don't claim frameReady yet.
             */
            root.ready = false
            root.frameReady = false

            if (!root.videoWarmupStarted) {
                root.videoWarmupStarted = true
                videoWarmupTimer.restart()
            }
        }
    }

    /*
     * Immediately stop playback of the currently displayed video.
     *
     * The Video item remains visible, so its current frame stays
     * frozen on screen while the incoming media prepares.
     */
    function freeze() {
        root.frozen = true

        if (
            root.isVideo &&
            wallpaperVideo.playbackState ===
            MediaPlayer.Playing
        ) {
            try {
                wallpaperVideo.pause()
            } catch (e) {
                console.warn(
                    "[WallpaperLayer] video pause error:",
                    e
                )
            }
        }
    }

    function unfreeze() {
        root.frozen = false

        if (
            root.isVideo &&
            root.source
        ) {
            try {
                wallpaperVideo.play()
            } catch (e) {
                console.warn(
                    "[WallpaperLayer] video resume error:",
                    e
                )
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    /*
     * IMAGE
     */
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
            root.updateReadiness()

            if (
                status === Image.Error
            ) {
                console.warn(
                    "[WallpaperLayer] IMAGE ERROR:",
                    root.resolvedSource
                )

                root.ready = true
                root.frameReady = false
            }
        }
    }

    /*
     * GIF
     */
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
            root.updateReadiness()

            if (
                status ===
                AnimatedImage.Error
            ) {
                console.warn(
                    "[WallpaperLayer] GIF ERROR:",
                    root.resolvedSource
                )

                root.ready = true
                root.frameReady = false
            }
        }
    }

    /*
     * VIDEO
     */
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

        loops:
            MediaPlayer.Infinite

        muted: true
        autoPlay: true

        onSourceChanged: {
            root.ready = false
            root.frameReady = false
            root.videoWarmupStarted = false

            videoWarmupTimer.stop()

            if (source) {
                try {
                    play()
                } catch (e) {
                    console.warn(
                        "[WallpaperLayer] video play error:",
                        e
                    )
                }

                /*
                 * Start the bounded first-frame warm-up immediately.
                 */
                root.videoWarmupStarted = true
                videoWarmupTimer.restart()
            }
        }

        onPlaybackStateChanged: {
            root.updateReadiness()
        }

        onErrorChanged: {
            if (
                error !==
                MediaPlayer.NoError
            ) {
                console.warn(
                    "[WallpaperLayer] VIDEO ERROR:",
                    error,
                    errorString
                )

                /*
                 * The media failed. It is not frameReady.
                 */
                root.ready = true
                root.frameReady = false

                videoWarmupTimer.stop()
            }
        }
    }

    /*
     * Bounded decoder warm-up.
     *
     * This does NOT wait for the whole video.
     *
     * Once this expires, we allow the transition system to proceed
     * even if playbackState has not reflected Playing yet.
     *
     * The old wallpaper is still covering this layer at this point,
     * so there is no visible black frame during preparation.
     */
    Timer {
        id: videoWarmupTimer

        interval:
            root.videoWarmupMs

        repeat: false

        onTriggered: {
            if (!root.isVideo)
                return

            /*
             * If an actual playable state was observed, great.
             */
            if (
                wallpaperVideo.playbackState ===
                    MediaPlayer.Playing ||
                wallpaperVideo.playbackState ===
                    MediaPlayer.Paused
            ) {
                root.ready = true
                root.frameReady = true
                return
            }

            /*
             * Backend hasn't exposed Playing/Paused yet.
             *
             * Still permit the transition after the bounded warm-up.
             *
             * The Video object itself is already attached to the scene
             * and its source has been handed to the decoder.
             */
            root.ready = true
            root.frameReady = true
        }
    }

    onDefinitionChanged: {
        root.resetReadiness()
        root.frozen = false

        Qt.callLater(
            root.updateReadiness
        )
    }

    onSourceChanged: {
        root.resetReadiness()

        Qt.callLater(
            root.updateReadiness
        )
    }

    onTypeChanged: {
        root.resetReadiness()

        Qt.callLater(
            root.updateReadiness
        )
    }

    Component.onCompleted: {
        Qt.callLater(
            root.updateReadiness
        )
    }
}