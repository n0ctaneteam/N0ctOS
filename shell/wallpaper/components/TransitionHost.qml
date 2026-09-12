import QtQuick
import Quickshell
import qs.wallpaper.components
import qs.wallpaper.lib

Item {
    id: root

    required property var screen

    property var definition: ({})

    property bool busy: false
    property real progress: 0

    property var currentDefinition: null

    property Item activeSlot: slotA
    property Item pendingSlot: null
    property var pendingDefinition: null

    property var transition: null
    property var transitionComponent: null
    property var transitionEntry: null

    property int generation: 0

    /*
     * Safety limits.
     *
     * These do NOT represent video length or full-file buffering.
     */
    property int wallpaperTimeoutMs: 30000
    property int transitionTimeoutMs: 15000

    anchors.fill: parent
    clip: true

    function inactiveSlot() {
        return root.activeSlot === slotA
            ? slotB
            : slotA
    }

    function sameDefinition(a, b) {
        if (!a || !b)
            return false

        return (
            String(a.source || "") ===
                String(b.source || "") &&

            String(a.type || "image") ===
                String(b.type || "image") &&

            String(a.fitting || "crop") ===
                String(b.fitting || "crop")
        )
    }

    function incomingFrameReady() {
        return (
            root.pendingSlot &&
            root.pendingSlot.wallpaper &&
            root.pendingSlot.wallpaper.frameReady
        )
    }

    /*
     * Release the media held by an inactive slot.
     *
     * We keep the slot Item itself because it is our stable A/B
     * container, but clearing the WallpaperLayer definition causes
     * its Image/GIF/Video source to be released.
     */
    function releaseSlot(slot) {
        if (!slot)
            return

        if (slot.wallpaper) {
            try {
                slot.wallpaper.freeze()
            } catch (e) {
            }
        }

        slot.visible = false
        slot.opacity = 1
        slot.scale = 1
        slot.rotation = 0
        slot.x = 0
        slot.y = 0
        slot.z = 1

        slot.definition = ({})
    }

    function resetSlot(slot) {
        if (!slot)
            return

        slot.visible = false
        slot.opacity = 1
        slot.scale = 1
        slot.rotation = 0
        slot.x = 0
        slot.y = 0
        slot.z = 1

        slot.definition = ({})
    }

    function destroyTransition() {
        componentTimer.stop()
        transitionTimer.stop()

        var object =
            root.transition

        root.transition = null
        root.transitionComponent = null
        root.transitionEntry = null

        if (!object)
            return

        try {
            object.complete()
        } catch (e) {
        }

        try {
            object.destroy()
        } catch (e) {
            console.warn(
                "[TransitionHost] transition destroy error:",
                e
            )
        }
    }

    /*
     * Abandon only the incoming wallpaper.
     *
     * Current wallpaper remains untouched and visible.
     */
    function cancelPendingWallpaper() {
        root.generation++

        wallpaperTimer.stop()
        mediaPollTimer.stop()
        componentTimer.stop()
        transitionTimer.stop()
        frameTimer.stop()

        root.destroyTransition()

        if (root.pendingSlot)
            root.releaseSlot(
                root.pendingSlot
            )

        root.pendingSlot = null
        root.pendingDefinition = null

        root.busy = false
        root.progress = 0
    }

    /*
     * Startup/fallback hard switch.
     */
    function hardSwitch(definition) {
        root.generation++

        wallpaperTimer.stop()
        mediaPollTimer.stop()
        componentTimer.stop()
        transitionTimer.stop()
        frameTimer.stop()

        root.destroyTransition()

        var incoming =
            root.inactiveSlot()

        if (!incoming)
            return

        var old =
            root.activeSlot

        incoming.definition =
            Object.assign(
                {},
                definition || ({})
            )

        incoming.visible = true
        incoming.opacity = 1
        incoming.scale = 1
        incoming.rotation = 0
        incoming.x = 0
        incoming.y = 0
        incoming.z = 20

        old.visible = false
        old.z = 1

        root.activeSlot =
            incoming

        root.currentDefinition =
            incoming.definition

        root.pendingSlot = null
        root.pendingDefinition = null

        root.busy = false
        root.progress = 1

        /*
         * Release the old media after promotion.
         */
        Qt.callLater(function() {
            root.releaseSlot(old)
        })
    }

    function requestDefinition(definition) {
        var next =
            definition || ({})

        /*
         * Initial wallpaper.
         */
        if (!root.currentDefinition) {
            root.activeSlot.definition =
                Object.assign(
                    {},
                    next
                )

            root.activeSlot.visible = true
            root.activeSlot.opacity = 1
            root.activeSlot.z = 20

            root.currentDefinition =
                root.activeSlot.definition

            root.busy = false
            root.progress = 1

            return
        }

        /*
         * Same wallpaper.
         */
        if (
            root.sameDefinition(
                root.currentDefinition,
                next
            )
        )
            return

        /*
         * Latest request wins while a transition runs.
         */
        if (root.busy) {
            root.pendingDefinition =
                Object.assign(
                    {},
                    next
                )

            return
        }

        root.beginTransition(next)
    }

    /*
     * Prepare the incoming wallpaper.
     */
    function beginTransition(definition) {
        var incoming =
            root.inactiveSlot()

        if (!incoming)
            return

        var generation =
            ++root.generation

        wallpaperTimer.stop()
        mediaPollTimer.stop()
        componentTimer.stop()
        transitionTimer.stop()
        frameTimer.stop()

        root.destroyTransition()

        root.busy = true
        root.progress = 0

        root.pendingSlot =
            incoming

        root.pendingDefinition = null

        /*
         * Freeze the CURRENT wallpaper immediately.
         *
         * Video stops now and remains on its current frame.
         */
        if (
            root.activeSlot &&
            root.activeSlot.wallpaper
        ) {
            root.activeSlot.wallpaper.freeze()
        }

        /*
         * Make absolutely sure the inactive slot is clean before
         * reusing it.
         */
        root.resetSlot(incoming)

        incoming.definition =
            Object.assign(
                {},
                definition || ({})
            )

        /*
         * Incoming is in the scene graph so its media can load,
         * but it remains below the outgoing wallpaper.
         */
        incoming.visible = true
        incoming.opacity = 1
        incoming.scale = 1
        incoming.rotation = 0
        incoming.x = 0
        incoming.y = 0
        incoming.z = 10

        /*
         * Current wallpaper remains dominant.
         */
        root.activeSlot.visible = true
        root.activeSlot.opacity = 1
        root.activeSlot.z = 20

        /*
         * Load the transition plugin while media initializes.
         */
        loadTransitionComponent(
            generation
        )

        wallpaperTimer.restart()
        mediaPollTimer.restart()
    }

    function checkIncomingFrame() {
        if (!root.busy)
            return

        if (
            root.incomingFrameReady()
        ) {
            mediaPollTimer.stop()

            /*
             * Let the scene graph consume the ready frame first.
             */
            frameTimer.restart()

            return
        }

        mediaPollTimer.restart()
    }

    function loadTransitionComponent(generation) {
        if (
            generation !==
            root.generation
        )
            return

        var id =
            String(
                TransitionManager.id ||
                "none"
            )

        /*
         * No transition configured.
         */
        if (
            id === "none" ||
            !TransitionManager.available
        ) {
            root.transitionEntry = null
            return
        }

        var entry =
            TransitionManager.get(id)

        if (
            !entry ||
            !entry.componentUrl
        ) {
            console.warn(
                "[TransitionHost] transition unavailable:",
                id
            )

            root.transitionEntry = null
            return
        }

        root.transitionEntry =
            entry

        var component = null

        try {
            component =
                Qt.createComponent(
                    entry.componentUrl,
                    Component.Asynchronous
                )
        } catch (e) {
            console.warn(
                "[TransitionHost] transition create error:",
                e
            )

            root.transitionComponent = null
            return
        }

        if (!component) {
            console.warn(
                "[TransitionHost] transition component creation failed:",
                entry.componentUrl
            )

            root.transitionComponent = null
            return
        }

        root.transitionComponent =
            component

        if (
            component.status ===
            Component.Error
        ) {
            console.warn(
                "[TransitionHost] transition load error:",
                component.errorString()
            )

            root.transitionComponent = null
            root.transitionEntry = null

            return
        }

        if (
            component.status ===
            Component.Ready
        ) {
            tryCreateTransition(
                generation
            )

            return
        }

        componentTimer.restart()
        transitionTimer.restart()
    }

    function checkTransitionComponent() {
        if (!root.busy) {
            componentTimer.stop()
            return
        }

        var component =
            root.transitionComponent

        if (!component) {
            componentTimer.stop()
            return
        }

        if (
            component.status ===
            Component.Ready
        ) {
            componentTimer.stop()

            tryCreateTransition(
                root.generation
            )

            return
        }

        if (
            component.status ===
            Component.Error
        ) {
            componentTimer.stop()
            transitionTimer.stop()

            console.warn(
                "[TransitionHost] transition load error:",
                component.errorString()
            )

            root.transitionComponent = null
            root.transitionEntry = null

            if (
                root.incomingFrameReady()
            ) {
                commitWithoutTransition()
            }
        }
    }

    /*
     * Create transition only after incoming media has an actual
     * usable frame.
     */
    function tryCreateTransition(generation) {
        if (
            generation !==
            root.generation
        )
            return

        if (!root.busy)
            return

        if (
            !root.incomingFrameReady()
        )
            return

        var component =
            root.transitionComponent

        var entry =
            root.transitionEntry

        var outgoing =
            root.activeSlot

        var incoming =
            root.pendingSlot

        if (
            !component ||
            !entry
        ) {
            commitWithoutTransition()
            return
        }

        if (
            !outgoing ||
            !incoming
        ) {
            cancelPendingWallpaper()
            return
        }

        if (
            component.status !==
            Component.Ready
        )
            return

        try {
            root.transition =
                component.createObject(
                    root,
                    {
                        oldItem:
                            outgoing,

                        newItem:
                            incoming,

                        duration:
                            TransitionManager.duration,

                        parameters:
                            Object.assign(
                                {},
                                TransitionManager.parameters
                            ),

                        mode:
                            String(
                                entry.type ||
                                "qml"
                            )
                    }
                )
        } catch (e) {
            console.warn(
                "[TransitionHost] transition creation error:",
                e
            )

            commitWithoutTransition()
            return
        }

        if (!root.transition) {
            console.warn(
                "[TransitionHost] transition object creation failed"
            )

            commitWithoutTransition()
            return
        }

        root.transition.z = 100
        root.transition.visible = false

        /*
         * Let ShaderEffect / ShaderEffectSource and bindings settle.
         */
        frameTimer.restart()
    }

    function startPreparedTransition() {
        if (!root.busy)
            return

        if (
            !root.incomingFrameReady()
        )
            return

        /*
         * No transition object.
         */
        if (!root.transition) {
            if (
                root.transitionEntry === null
            ) {
                commitWithoutTransition()
            }

            return
        }

        /*
         * The transition is the first thing that is now allowed to
         * appear above the outgoing wallpaper.
         */
        root.transition.visible = true

        try {
            root.transition.start()
        } catch (e) {
            console.warn(
                "[TransitionHost] transition start error:",
                e
            )

            commitWithoutTransition()
        }
    }

    /*
     * Safe direct promotion.
     */
    function commitWithoutTransition() {
        var incoming =
            root.pendingSlot

        if (!incoming)
            return

        if (
            !root.incomingFrameReady()
        )
            return

        var outgoing =
            root.activeSlot

        var queued =
            root.pendingDefinition

        wallpaperTimer.stop()
        mediaPollTimer.stop()
        componentTimer.stop()
        transitionTimer.stop()
        frameTimer.stop()

        /*
         * Incoming first.
         */
        incoming.visible = true
        incoming.opacity = 1
        incoming.scale = 1
        incoming.rotation = 0
        incoming.x = 0
        incoming.y = 0
        incoming.z = 30

        root.activeSlot =
            incoming

        root.currentDefinition =
            incoming.definition

        /*
         * Outgoing disappears.
         */
        outgoing.visible = false
        outgoing.opacity = 1
        outgoing.scale = 1
        outgoing.rotation = 0
        outgoing.x = 0
        outgoing.y = 0
        outgoing.z = 1

        root.pendingSlot = null
        root.pendingDefinition = null

        root.busy = false
        root.progress = 1

        root.destroyTransition()

        /*
         * Release old media after the new wallpaper is already
         * active.
         */
        Qt.callLater(function() {
            root.releaseSlot(outgoing)

            if (queued) {
                if (
                    !root.sameDefinition(
                        root.currentDefinition,
                        queued
                    )
                ) {
                    root.beginTransition(
                        queued
                    )
                }
            }
        })
    }

    /*
     * Transition reaches progress == 1.
     *
     * Transition.qml deliberately remains alive until we promote the
     * incoming wallpaper.
     */
    function commitTransition() {
        var incoming =
            root.pendingSlot

        var outgoing =
            root.activeSlot

        if (
            !incoming ||
            !outgoing
        )
            return

        var queued =
            root.pendingDefinition

        wallpaperTimer.stop()
        mediaPollTimer.stop()
        componentTimer.stop()
        transitionTimer.stop()
        frameTimer.stop()

        /*
         * IMPORTANT ORDER:
         *
         * 1. Incoming is promoted.
         * 2. Outgoing is hidden.
         * 3. Transition is completed.
         * 4. Transition is hidden.
         * 5. Old media is released.
         */
        incoming.visible = true
        incoming.opacity = 1
        incoming.scale = 1
        incoming.rotation = 0
        incoming.x = 0
        incoming.y = 0
        incoming.z = 200

        root.activeSlot =
            incoming

        root.currentDefinition =
            incoming.definition

        outgoing.visible = false
        outgoing.opacity = 1
        outgoing.scale = 1
        outgoing.rotation = 0
        outgoing.x = 0
        outgoing.y = 0
        outgoing.z = 1

        root.pendingSlot = null
        root.pendingDefinition = null

        root.progress = 1
        root.busy = false

        /*
         * The incoming wallpaper is now active.
         *
         * It is safe to make the shader disappear.
         */
        if (root.transition) {
            try {
                root.transition.complete()
            } catch (e) {
                console.warn(
                    "[TransitionHost] transition complete error:",
                    e
                )
            }

            root.transition.visible = false
        }

        /*
         * Let the compositor/scene graph get one clean frame of the
         * final wallpaper before destroying anything.
         */
        Qt.callLater(function() {
            var finishedTransition =
                root.transition

            root.transition = null
            root.transitionComponent = null
            root.transitionEntry = null

            /*
             * Destroy transition first.
             */
            if (finishedTransition) {
                try {
                    finishedTransition.destroy()
                } catch (e) {
                    console.warn(
                        "[TransitionHost] transition destroy error:",
                        e
                    )
                }
            }

            /*
             * NOW release old wallpaper media.
             *
             * This clears:
             *     Image.source
             *     AnimatedImage.source
             *     Video.source
             *
             * through WallpaperLayer.definition = ({})
             */
            root.releaseSlot(outgoing)

            /*
             * Process the latest queued request, if any.
             */
            if (queued) {
                if (
                    !root.sameDefinition(
                        root.currentDefinition,
                        queued
                    )
                ) {
                    root.beginTransition(
                        queued
                    )
                }
            }
        })
    }

    function failTransition(reason) {
        console.warn(
            "[TransitionHost] transition failed:",
            String(
                reason ||
                "unknown error"
            )
        )

        if (
            root.incomingFrameReady()
        ) {
            commitWithoutTransition()
        } else {
            cancelPendingWallpaper()
        }
    }

    onDefinitionChanged: {
        if (!root.definition)
            return

        Qt.callLater(function() {
            root.requestDefinition(
                root.definition
            )
        })
    }

    /*
     * SLOT A
     */
    Item {
        id: slotA

        property var definition: ({})

        property alias wallpaper:
            wallpaperA

        anchors.fill: parent

        visible: false
        z: 1

        WallpaperLayer {
            id: wallpaperA

            anchors.fill: parent
            definition:
                slotA.definition
        }
    }

    /*
     * SLOT B
     */
    Item {
        id: slotB

        property var definition: ({})

        property alias wallpaper:
            wallpaperB

        anchors.fill: parent

        visible: false
        z: 1

        WallpaperLayer {
            id: wallpaperB

            anchors.fill: parent
            definition:
                slotB.definition
        }
    }

    /*
     * Poll incoming media.
     */
    Timer {
        id: mediaPollTimer

        interval: 16
        repeat: false

        onTriggered: {
            root.checkIncomingFrame()
        }
    }

    /*
     * One Qt event-loop turn after:
     *
     * - media becomes frameReady
     * - transition object is created
     */
    Timer {
        id: frameTimer

        interval: 0
        repeat: false

        onTriggered: {
            if (!root.busy)
                return

            /*
             * Transition exists:
             * start it after its initialization frame.
             */
            if (root.transition) {
                root.startPreparedTransition()
                return
            }

            /*
             * Media is ready and transition component is ready.
             */
            if (
                root.incomingFrameReady() &&
                root.transitionComponent &&
                root.transitionComponent.status ===
                    Component.Ready
            ) {
                root.tryCreateTransition(
                    root.generation
                )

                return
            }

            /*
             * No transition configured.
             */
            if (
                root.incomingFrameReady() &&
                (
                    !root.transitionEntry ||
                    !TransitionManager.available ||
                    TransitionManager.id === "none"
                )
            ) {
                root.commitWithoutTransition()
            }
        }
    }

    /*
     * Media safety timeout.
     *
     * We never expose the pending layer on timeout.
     */
    Timer {
        id: wallpaperTimer

        interval:
            root.wallpaperTimeoutMs

        repeat: false

        onTriggered: {
            if (!root.busy)
                return

            if (
                root.incomingFrameReady()
            )
                return

            console.warn(
                "[TransitionHost] wallpaper load timeout; keeping current wallpaper"
            )

            root.cancelPendingWallpaper()
        }
    }

    /*
     * Transition component safety timeout.
     */
    Timer {
        id: transitionTimer

        interval:
            root.transitionTimeoutMs

        repeat: false

        onTriggered: {
            if (!root.busy)
                return

            console.warn(
                "[TransitionHost] transition load timeout; using safe switch"
            )

            if (
                root.incomingFrameReady()
            ) {
                root.commitWithoutTransition()
            } else {
                root.cancelPendingWallpaper()
            }
        }
    }

    /*
     * Async transition Component watcher.
     */
    Timer {
        id: componentTimer

        interval: 16
        repeat: true

        onTriggered: {
            root.checkTransitionComponent()
        }
    }

    /*
     * Transition lifecycle.
     */
    Connections {
        target:
            root.transition

        function onFinished() {
            root.commitTransition()
        }

        function onFailed(reason) {
            root.failTransition(
                reason
            )
        }

        function onProgressChanged() {
            if (root.transition) {
                root.progress =
                    root.transition.progress
            }
        }
    }

    Component.onCompleted: {
        console.log(
            "[TransitionHost] READY:",
            root.screen
                ? root.screen.name
                : "(null)"
        )

        if (root.definition) {
            Qt.callLater(function() {
                root.requestDefinition(
                    root.definition
                )
            })
        }
    }
}