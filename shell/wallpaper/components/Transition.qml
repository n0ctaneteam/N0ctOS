import QtQuick

Item {
    id: root

    /*
     * ==============================================================
     * N0ctOS TRANSITION BASE
     * ==============================================================
     *
     * This is the base component used by every wallpaper transition.
     *
     * A transition receives two wallpaper items:
     *
     *     oldItem  -> currently displayed wallpaper
     *     newItem  -> incoming wallpaper
     *
     * Animation progress:
     *
     *     0.0 -> transition start
     *     1.0 -> transition end
     *
     * IMPORTANT:
     *
     * The Transition object owns the animation state.
     * TransitionHost owns wallpaper lifetime and final promotion.
     *
     * Plugins should NOT:
     *
     *     - change WallpaperManager
     *     - change wallpaper definitions
     *     - destroy themselves
     *     - manually switch wallpapers
     *
     * Plugins should only implement the visual effect.
     * ==============================================================
     */

    /*
     * --------------------------------------------------------------
     * Public plugin properties
     * --------------------------------------------------------------
     */

    property Item oldItem: null
    property Item newItem: null

    property real progress: 0
    property int duration: 500

    property string mode: "qml"

    property var parameters: ({})

    /*
     * running:
     *
     * True while the transition is alive and allowed to render.
     *
     * IMPORTANT:
     *
     * finish() does NOT set this to false.
     *
     * TransitionHost needs the transition to remain alive until it
     * has promoted the new wallpaper.
     */
    property bool running: false

    /*
     * True once the animation has reached its end.
     *
     * This is separate from running.
     */
    property bool finishedState: false

    property bool failedState: false

    /*
     * Prevents start() from being called after completion.
     */
    property bool completedState: false

    /*
     * Signals consumed by TransitionHost.
     */
    signal finished()
    signal failed(string reason)

    anchors.fill: parent

    /*
     * --------------------------------------------------------------
     * Parameter helper
     * --------------------------------------------------------------
     *
     * Example:
     *
     *     property real amount:
     *         Number(root.param("amount", 0.12))
     * --------------------------------------------------------------
     */
    function param(name, fallback) {
        if (
            root.parameters &&
            typeof root.parameters === "object" &&
            Object.prototype.hasOwnProperty.call(
                root.parameters,
                name
            )
        ) {
            return root.parameters[name]
        }

        return fallback
    }

    /*
     * --------------------------------------------------------------
     * Generic utility
     * --------------------------------------------------------------
     */
    function clamp(value, minimum, maximum) {
        return Math.max(
            minimum,
            Math.min(
                maximum,
                value
            )
        )
    }

    /*
     * --------------------------------------------------------------
     * prepare()
     * --------------------------------------------------------------
     *
     * Called immediately before animation begins.
     *
     * Plugins may override this function.
     *
     * The default implementation simply makes both wallpaper items
     * available to the transition.
     */
    function prepare() {
        if (root.oldItem)
            root.oldItem.visible = true

        if (root.newItem)
            root.newItem.visible = true
    }

    /*
     * --------------------------------------------------------------
     * setProperty()
     * --------------------------------------------------------------
     *
     * Safe convenience helper for QML transition plugins.
     *
     * Example:
     *
     *     root.setProperty(
     *         root.newItem,
     *         "opacity",
     *         root.progress
     *     )
     *
     * This is intentionally a plain property assignment rather than
     * a QML Binding.
     *
     * That distinction matters:
     *
     *     Binding
     *         can restore an old property value when disabled
     *
     *     setProperty()
     *         simply writes the current value
     *
     * Prefer this for one-shot/final state changes.
     */
    function setProperty(item, propertyName, value) {
        if (!item)
            return

        try {
            item[propertyName] = value
        } catch (e) {
            console.warn(
                "[Transition] property write failed:",
                propertyName,
                e
            )
        }
    }

    /*
     * --------------------------------------------------------------
     * setFinalState()
     * --------------------------------------------------------------
     *
     * Convenience helper for a transition to explicitly place the
     * two wallpaper items in their final visual state.
     *
     * Plugins may override this if required.
     */
    function setFinalState() {
        if (root.oldItem) {
            root.oldItem.opacity = 0
            root.oldItem.scale = 1
            root.oldItem.rotation = 0
            root.oldItem.x = 0
            root.oldItem.y = 0
        }

        if (root.newItem) {
            root.newItem.opacity = 1
            root.newItem.scale = 1
            root.newItem.rotation = 0
            root.newItem.x = 0
            root.newItem.y = 0
        }
    }

    /*
     * --------------------------------------------------------------
     * start()
     * --------------------------------------------------------------
     *
     * Starts the transition.
     *
     * There is deliberately one Qt event-loop turn between:
     *
     *     prepare()
     *
     * and:
     *
     *     animation.start()
     *
     * This is useful for ShaderEffect and ShaderEffectSource plugins.
     */
    function start() {
        if (root.running)
            return

        if (root.completedState)
            return

        root.progress = 0
        root.finishedState = false
        root.failedState = false
        root.completedState = false

        root.prepare()

        root.running = true

        Qt.callLater(function() {
            if (!root.running)
                return

            if (root.completedState)
                return

            /*
             * Zero-duration transitions still go through the normal
             * finish path so TransitionHost gets a finished signal.
             */
            if (root.duration <= 0) {
                root.progress = 1

                Qt.callLater(function() {
                    if (
                        root.running &&
                        !root.completedState
                    ) {
                        root.finish()
                    }
                })

                return
            }

            animation.restart()
        })
    }

    /*
     * --------------------------------------------------------------
     * finish()
     * --------------------------------------------------------------
     *
     * Called when progress reaches 1.0.
     *
     * IMPORTANT:
     *
     * running remains TRUE.
     *
     * This is intentional.
     *
     * For shader transitions:
     *
     *     running == true
     *
     * keeps the ShaderEffect alive while TransitionHost promotes
     * the incoming wallpaper.
     *
     * TransitionHost then calls:
     *
     *     complete()
     *
     * which actually ends the transition lifecycle.
     */
    function finish() {
        if (!root.running)
            return

        if (root.finishedState)
            return

        root.finishedState = true

        animation.stop()

        root.progress = 1

        /*
         * Allow the plugin to establish its explicit final state.
         *
         * This is NOT done automatically because shader plugins do
         * not necessarily want their wallpaper items modified.
         */
        if (root.mode === "qml")
            root.setFinalState()

        root.finished()
    }

    /*
     * --------------------------------------------------------------
     * complete()
     * --------------------------------------------------------------
     *
     * Called by TransitionHost AFTER:
     *
     *     - incoming wallpaper became active
     *     - outgoing wallpaper was hidden
     *     - transition is no longer needed
     *
     * This ends the transition lifecycle.
     */
    function complete() {
        animation.stop()

        root.progress = 1

        /*
         * Mark this completed before disabling running.
         *
         * This prevents any queued start/finish callback from
         * restarting the animation.
         */
        root.completedState = true
        root.finishedState = true

        root.running = false
    }

    /*
     * --------------------------------------------------------------
     * abort()
     * --------------------------------------------------------------
     *
     * Used when a transition must be cancelled before completion.
     */
    function abort() {
        animation.stop()

        root.running = false

        root.finishedState = false
        root.failedState = false
        root.completedState = false

        root.progress = 0
    }

    /*
     * --------------------------------------------------------------
     * fail()
     * --------------------------------------------------------------
     *
     * Safely aborts the animation and informs TransitionHost.
     */
    function fail(reason) {
        if (root.failedState)
            return

        root.failedState = true

        animation.stop()

        root.running = false

        root.failed(
            String(
                reason ||
                "transition failed"
            )
        )
    }

    /*
     * --------------------------------------------------------------
     * Main animation
     * --------------------------------------------------------------
     *
     * The base owns ONLY progress.
     *
     * Plugins decide what progress means visually.
     */
    NumberAnimation {
        id: animation

        target:
            root

        property:
            "progress"

        from:
            0

        to:
            1

        duration:
            Math.max(
                0,
                root.duration
            )

        easing.type:
            Easing.InOutCubic

        onFinished: {
            root.finish()
        }
    }
}