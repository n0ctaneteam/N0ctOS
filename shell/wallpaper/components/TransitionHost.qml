import QtQuick
import qs.wallpaper.lib

Item {
    id: root

    property var screen: null
    property var definition: null

    property var currentDefinition: null
    property var queuedDefinition: null

    property string state: "idle"
    property real transitionProgress: 0

    readonly property bool busy: state !== "idle"
    readonly property real progress: transitionProgress

    property Item activeLayer: null
    property Item stagingLayer: null
    property Item activeContent: null
    property Item stagingContent: null
    property Item activeViewport: null
    property Item stagingViewport: null

    property bool initialized: false
    property bool waitingForReady: false

    anchors.fill: parent

    function cloneDefinition(def) {
        if (!def || typeof def !== "object")
            return null

        var copy = {}

        for (var key in def)
            copy[key] = def[key]

        return copy
    }

    function sameDefinition(a, b) {
        if (a === b)
            return true

        if (!a || !b)
            return false

        return String(a.source || "") === String(b.source || "") &&
               String(a.type || "image") === String(b.type || "image") &&
               String(a.fitting || "crop") === String(b.fitting || "crop")
    }

    function contentForLayer(layer) {
        return layer === layerA ? contentA : contentB
    }

    function viewportForLayer(layer) {
        return layer === layerA ? viewportA : viewportB
    }

    function resetContent(content) {
        if (!content)
            return

        content.x = 0
        content.y = 0
        content.scale = 1
        content.rotation = 0
        content.opacity = 1
    }

    function resetViewport(viewport) {
        if (!viewport)
            return

        viewport.x = 0
        viewport.y = 0
        viewport.width = root.width
        viewport.height = root.height
        viewport.opacity = 1
        viewport.clip = true
    }

    function hideViewport(viewport) {
        if (!viewport)
            return

        viewport.visible = false
        viewport.opacity = 0
        viewport.x = 0
        viewport.y = 0
        viewport.width = root.width
        viewport.height = root.height
        viewport.clip = true
    }

    function request(def) {
        var requested = root.cloneDefinition(def)

        if (!requested)
            return

        if (!root.initialized) {
            root.currentDefinition = requested
            return
        }

        if (root.state !== "idle") {
            if (root.stagingLayer &&
                root.sameDefinition(
                    requested,
                    root.stagingLayer.definition))
                return

            if (root.sameDefinition(
                    requested,
                    root.currentDefinition))
                return

            root.queuedDefinition = requested

            console.log(
                "[TransitionHost]",
                root.screen ? root.screen.name : "(null)",
                "QUEUED:",
                String(requested.source || "(none)")
            )

            return
        }

        if (root.sameDefinition(
                requested,
                root.currentDefinition))
            return

        root.begin(requested)
    }

    function begin(requested) {
        var oldLayer = root.activeLayer
        var newLayer = root.stagingLayer
        var oldViewport = root.activeViewport
        var newViewport = root.stagingViewport

        root.state = "preparing"
        root.transitionProgress = 0
        root.queuedDefinition = null
        root.waitingForReady = true

        /*
         * OLD stays untouched.
         */
        oldLayer.visible = true
        oldLayer.opacity = 1

        oldViewport.visible = true
        oldViewport.opacity = 1
        oldViewport.x = 0
        oldViewport.y = 0
        oldViewport.width = root.width
        oldViewport.height = root.height
        oldViewport.clip = true
        oldViewport.z = 0

        /*
         * NEW gets the incoming definition.
         *
         * Its viewport remains hidden until the media is ready.
         * This prevents a black flash during preparation.
         */
        resetContent(
            root.contentForLayer(newLayer)
        )

        newLayer.definition =
            root.cloneDefinition(requested)

        newLayer.visible = true
        newLayer.opacity = 1

        newViewport.visible = false
        newViewport.opacity = 0
        newViewport.x = 0
        newViewport.y = 0
        newViewport.width = root.width
        newViewport.height = root.height
        newViewport.clip = true
        newViewport.z = 1

        console.log(
            "[TransitionHost]",
            root.screen ? root.screen.name : "(null)",
            "BEGIN",
            "old =",
            String(root.currentDefinition?.source || "(none)"),
            "new =",
            String(requested.source || "(none)")
        )

        if (newLayer.ready)
            root.startPreparedTransition()
    }

    function startPreparedTransition() {
        if (root.state !== "preparing")
            return

        var newLayer = root.stagingLayer
        var newViewport = root.stagingViewport

        if (!newLayer || !newLayer.ready)
            return

        root.waitingForReady = false

        /*
         * Reveal the prepared incoming wallpaper.
         */
        newViewport.visible = true
        newViewport.opacity = 1
        newViewport.x = 0
        newViewport.y = 0
        newViewport.width = root.width
        newViewport.height = root.height
        newViewport.clip = true
        newViewport.z = 1

        var transitionId =
            String(TransitionManager.id || "none")

        if (transitionId === "none") {
            root.instantCommit()
            return
        }

        var transitionDefinition =
            TransitionManager.definition

        if (!transitionDefinition ||
            !transitionDefinition.componentUrl) {

            console.warn(
                "[TransitionHost]",
                "TRANSITION COMPONENT MISSING:",
                transitionId
            )

            root.instantCommit()
            return
        }

        root.state = "running"

        transitionLoader.source =
            transitionDefinition.componentUrl

        console.log(
            "[TransitionHost]",
            root.screen ? root.screen.name : "(null)",
            "LOADING:",
            transitionId
        )
    }

    function setupTransition() {
        if (root.state !== "running")
            return

        var t = transitionLoader.item

        if (!t) {
            console.warn(
                "[TransitionHost]",
                "TRANSITION ITEM IS NULL"
            )

            root.instantCommit()
            return
        }

        var fromContent =
            root.contentForLayer(root.activeLayer)

        var toContent =
            root.contentForLayer(root.stagingLayer)

        t.from = fromContent
        t.to = toContent

        t.fromViewport =
            root.activeViewport

        t.toViewport =
            root.stagingViewport

        t.fromSource = null
        t.toSource = null

        t.progress = 0

        t.duration =
            Math.max(
                0,
                Number(
                    TransitionManager.duration
                )
            )

        t.parameters =
            TransitionManager.parameters || {}

        t.initialized = false

        /*
         * Both wallpaper contents are full-size.
         * Viewports perform clipping only.
         */
        fromContent.x = 0
        fromContent.y = 0
        fromContent.width = root.width
        fromContent.height = root.height

        toContent.x = 0
        toContent.y = 0
        toContent.width = root.width
        toContent.height = root.height

        root.activeViewport.visible = true
        root.activeViewport.opacity = 1

        root.stagingViewport.visible = true
        root.stagingViewport.opacity = 1

        t.initialize()

        if (!t.initialized)
            t.initialized = true

        console.log(
            "[TransitionHost]",
            root.screen ? root.screen.name : "(null)",
            "TRANSITION READY",
            "duration =",
            t.duration
        )

        t.start()

        if (t.duration <= 0) {
            root.transitionProgress = 1
            root.finishTransition()
            return
        }

        progressAnimation.duration =
            Number(t.duration)

        progressAnimation.restart()
    }

    function finishTransition() {
        if (root.state !== "running")
            return

        progressAnimation.stop()

        var t = transitionLoader.item

        root.transitionProgress = 1

        if (t)
            t.progress = 1

        if (t)
            t.finish()

        var oldLayer = root.activeLayer
        var newLayer = root.stagingLayer

        var oldViewport = root.activeViewport
        var newViewport = root.stagingViewport

        /*
         * Ensure the NEW wallpaper is completely visible.
         */
        newViewport.x = 0
        newViewport.y = 0
        newViewport.width = root.width
        newViewport.height = root.height
        newViewport.clip = true
        newViewport.opacity = 1
        newViewport.visible = true
        newViewport.z = 1

        newLayer.visible = true
        newLayer.opacity = 1

        /*
         * OLD disappears only now.
         */
        oldViewport.visible = false
        oldViewport.opacity = 0

        oldLayer.visible = false
        oldLayer.opacity = 0

        /*
         * Commit definition.
         */
        root.currentDefinition =
            root.cloneDefinition(
                newLayer.definition
            )

        /*
         * Physical role swap.
         */
        root.activeLayer = newLayer
        root.stagingLayer = oldLayer

        root.activeViewport = newViewport
        root.stagingViewport = oldViewport

        root.activeContent =
            root.contentForLayer(
                root.activeLayer
            )

        root.stagingContent =
            root.contentForLayer(
                root.stagingLayer
            )

        /*
         * Recycle the old side.
         */
        root.resetViewport(root.stagingViewport)
        root.hideViewport(root.stagingViewport)
        root.resetContent(root.stagingContent)

        root.waitingForReady = false
        root.transitionProgress = 1
        root.state = "idle"

        transitionLoader.source = ""

        console.log(
            "[TransitionHost]",
            root.screen ? root.screen.name : "(null)",
            "COMMITTED:",
            String(
                root.currentDefinition?.source ||
                "(none)"
            )
        )

        root.processQueue()
    }

    function instantCommit() {
        progressAnimation.stop()

        var oldLayer = root.activeLayer
        var newLayer = root.stagingLayer

        var oldViewport = root.activeViewport
        var newViewport = root.stagingViewport

        newViewport.x = 0
        newViewport.y = 0
        newViewport.width = root.width
        newViewport.height = root.height
        newViewport.clip = true
        newViewport.opacity = 1
        newViewport.visible = true
        newViewport.z = 1

        newLayer.visible = true
        newLayer.opacity = 1

        oldViewport.visible = false
        oldViewport.opacity = 0

        oldLayer.visible = false
        oldLayer.opacity = 0

        root.currentDefinition =
            root.cloneDefinition(
                newLayer.definition
            )

        root.activeLayer = newLayer
        root.stagingLayer = oldLayer

        root.activeViewport = newViewport
        root.stagingViewport = oldViewport

        root.activeContent =
            root.contentForLayer(
                root.activeLayer
            )

        root.stagingContent =
            root.contentForLayer(
                root.stagingLayer
            )

        root.resetViewport(root.stagingViewport)
        root.hideViewport(root.stagingViewport)
        root.resetContent(root.stagingContent)

        root.transitionProgress = 1
        root.waitingForReady = false
        root.state = "idle"

        transitionLoader.source = ""

        console.log(
            "[TransitionHost]",
            root.screen ? root.screen.name : "(null)",
            "INSTANT COMMIT:",
            String(
                root.currentDefinition?.source ||
                "(none)"
            )
        )

        root.processQueue()
    }

    function processQueue() {
        var next =
            root.queuedDefinition

        root.queuedDefinition = null

        if (next &&
            !root.sameDefinition(
                next,
                root.currentDefinition)) {

            root.begin(next)
            return
        }

        /*
         * Catch changes made by WallpaperManager while busy.
         */
        if (!root.sameDefinition(
                root.definition,
                root.currentDefinition)) {

            root.begin(
                root.cloneDefinition(
                    root.definition
                )
            )
        }
    }

    Item {
        id: viewportA

        width: root.width
        height: root.height
        x: 0
        y: 0
        clip: true
        visible: true
        opacity: 1
        z: 1

        Item {
            id: contentA

            width: root.width
            height: root.height
            x: 0
            y: 0

            WallpaperLayer {
                id: layerA
                anchors.fill: parent
            }
        }
    }

    Item {
        id: viewportB

        width: root.width
        height: root.height
        x: 0
        y: 0
        clip: true
        visible: false
        opacity: 0
        z: 0

        Item {
            id: contentB

            width: root.width
            height: root.height
            x: 0
            y: 0

            WallpaperLayer {
                id: layerB
                anchors.fill: parent
            }
        }
    }

    Loader {
        id: transitionLoader

        active: true
        asynchronous: false

        onStatusChanged: {
            if (status === Loader.Ready) {
                console.log(
                    "[TransitionHost]",
                    root.screen ? root.screen.name : "(null)",
                    "TRANSITION LOADED:",
                    source
                )

                root.setupTransition()
                return
            }

            if (status === Loader.Error) {
                console.warn(
                    "[TransitionHost]",
                    root.screen ? root.screen.name : "(null)",
                    "TRANSITION LOAD FAILED:",
                    source
                )

                root.instantCommit()
            }
        }
    }

    NumberAnimation {
        id: progressAnimation

        target: root
        property: "transitionProgress"

        from: 0
        to: 1

        onFinished: {
            root.finishTransition()
        }
    }

    Connections {
        target: layerA

        function onReadyChanged() {
            if (root.state !== "preparing")
                return

            if (!root.waitingForReady)
                return

            if (root.stagingLayer === layerA &&
                layerA.ready) {

                root.startPreparedTransition()
            }
        }
    }

    Connections {
        target: layerB

        function onReadyChanged() {
            if (root.state !== "preparing")
                return

            if (!root.waitingForReady)
                return

            if (root.stagingLayer === layerB &&
                layerB.ready) {

                root.startPreparedTransition()
            }
        }
    }

    onTransitionProgressChanged: {
        var t = transitionLoader.item

        if (root.state !== "running" || !t)
            return

        t.progress =
            root.transitionProgress
    }

    onDefinitionChanged: {
        if (!root.initialized)
            return

        root.request(root.definition)
    }

    onWidthChanged: {
        viewportA.width = root.width
        viewportB.width = root.width
        contentA.width = root.width
        contentB.width = root.width
    }

    onHeightChanged: {
        viewportA.height = root.height
        viewportB.height = root.height
        contentA.height = root.height
        contentB.height = root.height
    }

    Component.onCompleted: {
        root.activeLayer = layerA
        root.stagingLayer = layerB

        root.activeContent = contentA
        root.stagingContent = contentB

        root.activeViewport = viewportA
        root.stagingViewport = viewportB

        root.currentDefinition =
            root.cloneDefinition(
                root.definition
            )

        layerA.definition =
            root.cloneDefinition(
                root.currentDefinition
            )

        layerA.visible = true
        layerA.opacity = 1

        layerB.visible = false
        layerB.opacity = 0

        viewportA.visible = true
        viewportA.opacity = 1
        viewportA.z = 1

        viewportB.visible = false
        viewportB.opacity = 0
        viewportB.z = 0

        root.initialized = true

        console.log(
            "[TransitionHost]",
            root.screen ? root.screen.name : "(null)",
            "INITIALIZED:",
            String(
                root.currentDefinition?.source ||
                "(none)"
            )
        )
    }
}