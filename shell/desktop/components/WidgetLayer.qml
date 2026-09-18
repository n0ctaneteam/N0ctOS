import QtQuick
import QtQuick.Effects

import Quickshell
import Quickshell.Wayland

import qs.desktop.components
import qs.desktop.lib
import qs.core.ui
import qs.core.lib

PanelWindow {
    id: root

    // ============================================================
    // REQUIRED
    // ============================================================

    required property var _screen

    screen: root._screen

    readonly property string screenName:
        String(root.screen.name || "")

    // ============================================================
    // MODE
    // ============================================================

    property bool editMode: false
    property string selectedInstanceId: ""

    // ============================================================
    // DEBUG
    // ============================================================

    property bool isDebug: false

    property color debugLayerColor:
        "#1a261563"

    property color debugWidgetTint:
        "#1a1f8ad0"

    property color debugTextBackground:
        "#eb090a10"

    property color debugTextColor:
        "#f4dcff"

    property color debugNormalBorder:
        "#9b8aa8"

    property color debugSelectedBorder:
        "#38d9ff"

    property color debugInvalidBorder:
        "#ff405f"

    // ============================================================
    // FRAME RESERVATIONS
    // ============================================================

    property int reservedTop: 0
    property int reservedBottom: 0
    property int reservedLeft: 0
    property int reservedRight: 0

    // ============================================================
    // MODEL
    // ============================================================

    property var widgetEntries: []

    // ============================================================
    // MOTION
    // ============================================================

    property real followResponse: 120.0
    property real maxFrameTime: 0.033

    property int motionEasing:
        Easing.OutCubic

    // ============================================================
    // RELEASE SEARCH
    // ============================================================

    property real releaseSearchRadius: 180
    property real releaseSearchStep: 16
    property real releaseSnapGap: 2

    // ============================================================
    // SELECTED WIDGET EMPHASIS
    // ============================================================

    /*
     * Whole delegate z values.
     */
    property real normalWidgetZ: 0
    property real selectedWidgetZ: 10000
    property real activeWidgetZ: 20000

    /*
     * Centered selected-widget shadow.
     *
     * Size:
     *     extra size around the widget.
     *
     * Color:
     *     shadow color.
     *
     * Blur:
     *     MultiEffect blur amount.
     */
    property real selectedShadowSize: 3
    property color selectedShadowColor: "#000000"
    property real selectedShadowBlur: 5

    property real selectedShadowOpacity: 0.42

    // ============================================================
    // ACTIVE INTERACTION
    // ============================================================

    property string activeInteractionInstanceId: ""
    property string activeResizeHandle: ""

    property int pendingCommitCount: 0

    // ============================================================
    // RESIZE SESSION
    // ============================================================

    property real interactionStartX: 0
    property real interactionStartY: 0
    property real interactionStartWidth: 0
    property real interactionStartHeight: 0

    property real resizeStartPointerX: 0
    property real resizeStartPointerY: 0

    // ============================================================
    // LAYER
    // ============================================================

    WlrLayershell.layer:
        root.editMode
            ? WlrLayer.Overlay
            : WlrLayer.Bottom

    WlrLayershell.exclusionMode:
        ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        top: root.reservedTop
        bottom: root.reservedBottom
        left: root.reservedLeft
        right: root.reservedRight
    }

    color: "transparent"

    // ============================================================
    // CONTEXT MENU
    // ============================================================

    MouseArea {
        id: contextMenuMouseArea

        anchors.fill:
            widgetRoot

        enabled:
            !ContextMenu.isOpen

        acceptedButtons:
            Qt.RightButton

        z:
            -90

        onPressed: function(mouse) {
            ContextMenu.updatePointer(
                root,
                mouse.x,
                mouse.y
            )

            ContextMenu.open(
                root.editMode
                    ? editContextMenu
                    : runtimeContextMenu
            )

            mouse.accepted =
                true
        }
    }

    // ============================================================
    // HELPERS
    // ============================================================

    function widgetDefinition(widgetId) {
        return WidgetRegistry.get(
            String(widgetId || "")
        )
    }

    function widgetSource(widgetId) {
        const definition =
            root.widgetDefinition(widgetId)

        if (!definition)
            return ""

        return String(
            definition.widgetPath || ""
        )
    }

    function reloadWidgets() {
        if (
            root.pendingCommitCount > 0 ||
            root.activeInteractionInstanceId !== ""
        ) {
            return
        }

        root.widgetEntries =
            WidgetManager.instancesForScreen(
                root.screenName
            ) || []
    }

    function findDelegate(instanceId) {
        const id =
            String(instanceId || "")

        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const item =
                widgetRepeater.itemAt(i)

            if (
                item &&
                item.instanceId === id
            ) {
                return item
            }
        }

        return null
    }

    // ============================================================
    // SELECTION
    // ============================================================

    function selectWidget(instanceId) {
        if (!root.editMode)
            return

        root.selectedInstanceId =
            String(instanceId || "")

        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const item =
                widgetRepeater.itemAt(i)

            if (
                item &&
                item.widgetItem
            ) {
                item.widgetItem.selected =
                    item.instanceId ===
                    root.selectedInstanceId
            }
        }

        const selected =
            root.findDelegate(
                root.selectedInstanceId
            )

        if (
            selected &&
            selected.widgetItem &&
            typeof selected.widgetItem.focusWidget ===
                "function"
        ) {
            selected.widgetItem.focusWidget()
        }
    }

    function clearSelection() {
        root.selectedInstanceId = ""

        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const item =
                widgetRepeater.itemAt(i)

            if (
                item &&
                item.widgetItem
            ) {
                item.widgetItem.selected = false
            }
        }
    }

    // ============================================================
    // GEOMETRY
    // ============================================================

    function makeRect(
        x,
        y,
        width,
        height
    ) {
        return {
            x: Number(x),
            y: Number(y),
            width: Number(width),
            height: Number(height)
        }
    }

    function intersects(a, b) {
        return (
            a.x < b.x + b.width &&
            a.x + a.width > b.x &&
            a.y < b.y + b.height &&
            a.y + a.height > b.y
        )
    }

    function insideLayer(rect) {
        return (
            rect.x >= 0 &&
            rect.y >= 0 &&
            rect.x + rect.width <= root.width &&
            rect.y + rect.height <= root.height
        )
    }

    function distanceSquared(
        ax,
        ay,
        bx,
        by
    ) {
        const dx =
            ax - bx

        const dy =
            ay - by

        return (
            dx * dx +
            dy * dy
        )
    }

    function rectMovementSquared(
        a,
        b
    ) {
        return root.distanceSquared(
            a.x,
            a.y,
            b.x,
            b.y
        )
    }

    // ============================================================
    // INTERSECTION RULE
    // ============================================================

    function pairBlocks(a, b) {
        if (
            !a.widgetItem ||
            !b.widgetItem
        ) {
            return false
        }

        return (
            !a.widgetItem.effectiveCanIntersect &&
            !b.widgetItem.effectiveCanIntersect
        )
    }

    // ============================================================
    // CONFIG VALIDITY
    // ============================================================

    function isRectValid(
        delegate,
        rect
    ) {
        if (
            !root.insideLayer(rect)
        ) {
            return false
        }

        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const other =
                widgetRepeater.itemAt(i)

            if (!other)
                continue

            if (
                other.instanceId ===
                delegate.instanceId
            ) {
                continue
            }

            if (
                !root.pairBlocks(
                    delegate,
                    other
                )
            ) {
                continue
            }

            const otherRect =
                root.makeRect(
                    other.targetX,
                    other.targetY,
                    other.targetWidth,
                    other.targetHeight
                )

            if (
                root.intersects(
                    rect,
                    otherRect
                )
            ) {
                return false
            }
        }

        return true
    }

    // ============================================================
    // COLLISION STATE
    // ============================================================

    function clearCollisionState() {
        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const item =
                widgetRepeater.itemAt(i)

            if (item)
                item.colliding = false
        }
    }

    function updateCollisionState(
        delegate
    ) {
        if (!delegate)
            return

        const movingRect =
            root.makeRect(
                delegate.targetX,
                delegate.targetY,
                delegate.targetWidth,
                delegate.targetHeight
            )

        /*
         * Do not clear everybody if we're checking a released
         * widget against an existing multi-widget collision state.
         */
        root.clearCollisionState()

        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const other =
                widgetRepeater.itemAt(i)

            if (!other)
                continue

            if (
                other.instanceId ===
                delegate.instanceId
            ) {
                continue
            }

            if (
                !root.pairBlocks(
                    delegate,
                    other
                )
            ) {
                continue
            }

            const otherRect =
                root.makeRect(
                    other.targetX,
                    other.targetY,
                    other.targetWidth,
                    other.targetHeight
                )

            if (
                root.intersects(
                    movingRect,
                    otherRect
                )
            ) {
                delegate.colliding = true
                other.colliding = true
            }
        }
    }

    // ============================================================
    // DRAG
    // ============================================================

    function beginDrag(
        delegate,
        pointerX,
        pointerY
    ) {
        if (!root.editMode)
            return

        if (!delegate.widgetItem)
            return

        root.selectWidget(
            delegate.instanceId
        )

        if (
            !delegate.widgetItem
                .effectiveDraggable
        ) {
            return
        }

        root.activeInteractionInstanceId =
            delegate.instanceId

        /*
         * Exact local anchor.
         */
        delegate.grabOffsetX =
            pointerX -
            delegate.targetX

        delegate.grabOffsetY =
            pointerY -
            delegate.targetY

        delegate.dragPointerStartX =
            pointerX

        delegate.dragPointerStartY =
            pointerY

        delegate.dragTargetStartX =
            delegate.targetX

        delegate.dragTargetStartY =
            delegate.targetY

        delegate.dragging = true

        delegate.widgetItem.dragging =
            true

        delegate.pendingCommit =
            false

        root.updateCollisionState(
            delegate
        )
    }

    function moveDrag(
        delegate,
        pointerX,
        pointerY
    ) {
        if (
            root.activeInteractionInstanceId !==
            delegate.instanceId
        ) {
            return
        }

        /*
         * Absolute cursor → target calculation.
         *
         * The rendered delegate position is never used here.
         */
        const desiredX =
            delegate.dragTargetStartX +
            (
                pointerX -
                delegate.dragPointerStartX
            )

        const desiredY =
            delegate.dragTargetStartY +
            (
                pointerY -
                delegate.dragPointerStartY
            )

        const target =
            root.makeRect(
                Math.max(
                    0,
                    Math.min(
                        desiredX,
                        root.width -
                            delegate.targetWidth
                    )
                ),
                Math.max(
                    0,
                    Math.min(
                        desiredY,
                        root.height -
                            delegate.targetHeight
                    )
                ),
                delegate.targetWidth,
                delegate.targetHeight
            )

        delegate.targetX =
            target.x

        delegate.targetY =
            target.y

        /*
         * Collision only changes presentation while dragging.
         */
        root.updateCollisionState(
            delegate
        )
    }

    function endDrag(delegate) {
        if (
            root.activeInteractionInstanceId !==
            delegate.instanceId
        ) {
            return
        }

        root.activeInteractionInstanceId =
            ""

        delegate.dragging =
            false

        if (delegate.widgetItem) {
            delegate.widgetItem.dragging =
                false
        }

        const releasedRect =
            root.makeRect(
                delegate.targetX,
                delegate.targetY,
                delegate.targetWidth,
                delegate.targetHeight
            )

        /*
         * If valid, keep exactly the released target.
         */
        if (
            !root.isRectValid(
                delegate,
                releasedRect
            )
        ) {
            const placement =
                root.findReleasePlacement(
                    delegate
                )

            /*
             * Only change target when a suitable nearby placement
             * actually exists.
             */
            if (placement) {
                delegate.targetX =
                    placement.x

                delegate.targetY =
                    placement.y
            }
        }

        root.updateCollisionState(
            delegate
        )

        delegate.pendingCommit =
            true

        root.pendingCommitCount++
    }

    // ============================================================
    // RESIZE START
    // ============================================================

    function beginResize(
        delegate,
        handle,
        pointerX,
        pointerY
    ) {
        if (!root.editMode)
            return

        if (!delegate.widgetItem)
            return

        root.selectWidget(
            delegate.instanceId
        )

        if (
            !delegate.widgetItem
                .effectiveResizable
        ) {
            return
        }

        root.activeInteractionInstanceId =
            delegate.instanceId

        root.activeResizeHandle =
            handle

        root.interactionStartX =
            delegate.targetX

        root.interactionStartY =
            delegate.targetY

        root.interactionStartWidth =
            delegate.targetWidth

        root.interactionStartHeight =
            delegate.targetHeight

        root.resizeStartPointerX =
            pointerX

        root.resizeStartPointerY =
            pointerY

        delegate.resizing =
            true

        delegate.widgetItem.resizing =
            true

        delegate.pendingCommit =
            false

        root.updateCollisionState(
            delegate
        )
    }

    // ============================================================
    // RESIZE CALCULATION
    // ============================================================

    function calculateResizeRect(
        delegate,
        pointerX,
        pointerY
    ) {
        const widget =
            delegate.widgetItem

        if (!widget)
            return null

        const handle =
            root.activeResizeHandle

        const dx =
            pointerX -
            root.resizeStartPointerX

        const dy =
            pointerY -
            root.resizeStartPointerY

        let x =
            root.interactionStartX

        let y =
            root.interactionStartY

        let width =
            root.interactionStartWidth

        let height =
            root.interactionStartHeight

        const minWidth =
            Math.max(
                1,
                Number(
                    widget.minimumWidth
                )
            )

        const minHeight =
            Math.max(
                1,
                Number(
                    widget.minimumHeight
                )
            )

        const rawMaxWidth =
            Number(
                widget.maximumWidth
            )

        const rawMaxHeight =
            Number(
                widget.maximumHeight
            )

        const maxWidth =
            Number.isFinite(
                rawMaxWidth
            )
                ? Math.max(
                    minWidth,
                    rawMaxWidth
                )
                : Infinity

        const maxHeight =
            Number.isFinite(
                rawMaxHeight
            )
                ? Math.max(
                    minHeight,
                    rawMaxHeight
                )
                : Infinity

        const growsLeft =
            handle === "left" ||
            handle === "topLeft" ||
            handle === "bottomLeft"

        const growsRight =
            handle === "right" ||
            handle === "topRight" ||
            handle === "bottomRight"

        const growsTop =
            handle === "top" ||
            handle === "topLeft" ||
            handle === "topRight"

        const growsBottom =
            handle === "bottom" ||
            handle === "bottomLeft" ||
            handle === "bottomRight"

        if (growsLeft) {
            width =
                Math.max(
                    minWidth,
                    Math.min(
                        maxWidth,
                        root.interactionStartWidth -
                            dx
                    )
                )

            x =
                root.interactionStartX +
                root.interactionStartWidth -
                width
        }

        if (growsRight) {
            width =
                Math.max(
                    minWidth,
                    Math.min(
                        maxWidth,
                        root.interactionStartWidth +
                            dx
                    )
                )
        }

        if (growsTop) {
            height =
                Math.max(
                    minHeight,
                    Math.min(
                        maxHeight,
                        root.interactionStartHeight -
                            dy
                    )
                )

            y =
                root.interactionStartY +
                root.interactionStartHeight -
                height
        }

        if (growsBottom) {
            height =
                Math.max(
                    minHeight,
                    Math.min(
                        maxHeight,
                        root.interactionStartHeight +
                            dy
                    )
                )
        }

        return root.clampResizeRect(
            root.makeRect(
                x,
                y,
                width,
                height
            ),
            delegate
        )
    }

    function clampResizeRect(
        rect,
        delegate
    ) {
        const widget =
            delegate.widgetItem

        const minWidth =
            Math.max(
                1,
                Number(
                    widget.minimumWidth
                )
            )

        const minHeight =
            Math.max(
                1,
                Number(
                    widget.minimumHeight
                )
            )

        let x =
            rect.x

        let y =
            rect.y

        let width =
            Math.max(
                minWidth,
                rect.width
            )

        let height =
            Math.max(
                minHeight,
                rect.height
            )

        /*
         * Left bound.
         */
        if (x < 0) {
            const diff =
                -x

            if (
                root.activeResizeHandle ===
                    "left" ||
                root.activeResizeHandle ===
                    "topLeft" ||
                root.activeResizeHandle ===
                    "bottomLeft"
            ) {
                width -= diff
            }

            x = 0
        }

        /*
         * Top bound.
         */
        if (y < 0) {
            const diff =
                -y

            if (
                root.activeResizeHandle ===
                    "top" ||
                root.activeResizeHandle ===
                    "topLeft" ||
                root.activeResizeHandle ===
                    "topRight"
            ) {
                height -= diff
            }

            y = 0
        }

        width =
            Math.max(
                minWidth,
                Math.min(
                    width,
                    root.width - x
                )
            )

        height =
            Math.max(
                minHeight,
                Math.min(
                    height,
                    root.height - y
                )
            )

        /*
         * Right/bottom bound.
         */
        if (
            x + width >
            root.width
        ) {
            width =
                root.width - x
        }

        if (
            y + height >
            root.height
        ) {
            height =
                root.height - y
        }

        return root.makeRect(
            Math.max(0, x),
            Math.max(0, y),
            Math.max(minWidth, width),
            Math.max(minHeight, height)
        )
    }

    function moveResize(
        delegate,
        pointerX,
        pointerY
    ) {
        if (
            root.activeInteractionInstanceId !==
            delegate.instanceId
        ) {
            return
        }

        const rect =
            root.calculateResizeRect(
                delegate,
                pointerX,
                pointerY
            )

        if (!rect)
            return

        /*
         * During resizing we allow the target to become invalid.
         * The red collision state tells the user exactly that.
         */
        delegate.targetX =
            rect.x

        delegate.targetY =
            rect.y

        delegate.targetWidth =
            rect.width

        delegate.targetHeight =
            rect.height

        root.updateCollisionState(
            delegate
        )
    }

    function endResize(delegate) {
        if (
            root.activeInteractionInstanceId !==
            delegate.instanceId
        ) {
            return
        }

        root.activeInteractionInstanceId =
            ""

        root.activeResizeHandle =
            ""

        delegate.resizing =
            false

        if (delegate.widgetItem) {
            delegate.widgetItem.resizing =
                false
        }

        root.updateCollisionState(
            delegate
        )

        delegate.pendingCommit =
            true

        root.pendingCommitCount++
    }

    // ============================================================
    // RELEASE CANDIDATES
    // ============================================================

    function addCandidate(
        candidates,
        x,
        y,
        width,
        height,
        origin
    ) {
        const candidate =
            root.makeRect(
                x,
                y,
                width,
                height
            )

        /*
         * Do not allow out-of-layer candidates.
         *
         * Importantly, we DON'T clamp them because clamping destroys
         * exact edge relationships.
         */
        if (
            candidate.x < 0 ||
            candidate.y < 0 ||
            candidate.x +
                candidate.width >
                root.width ||
            candidate.y +
                candidate.height >
                root.height
        ) {
            return
        }

        const radius =
            root.releaseSearchRadius

        if (
            root.rectMovementSquared(
                candidate,
                origin
            ) >
            radius * radius
        ) {
            return
        }

        candidates.push(
            candidate
        )
    }

    // ============================================================
    // EXACT EDGE CANDIDATES
    // ============================================================

    function addEdgeCandidates(
        candidates,
        delegate,
        blocker,
        origin
    ) {
        const width =
            delegate.targetWidth

        const height =
            delegate.targetHeight

        const gap =
            Math.max(
                0,
                root.releaseSnapGap
            )

        /*
         * Important:
         *
         * Each axis gets three useful alignments:
         *
         *     origin
         *     blocker start
         *     blocker end - widget size
         *
         * This lets multiple overlapping widgets form a tight
         * solution rather than forcing the widget toward the center.
         */
        const yValues = [
            origin.y,
            blocker.y,
            blocker.y +
                blocker.height -
                height
        ]

        const xValues = [
            origin.x,
            blocker.x,
            blocker.x +
                blocker.width -
                width
        ]

        for (
            let i = 0;
            i < yValues.length;
            ++i
        ) {
            root.addCandidate(
                candidates,

                blocker.x -
                    width -
                    gap,

                yValues[i],

                width,
                height,

                origin
            )

            root.addCandidate(
                candidates,

                blocker.x +
                    blocker.width +
                    gap,

                yValues[i],

                width,
                height,

                origin
            )
        }

        for (
            let i = 0;
            i < xValues.length;
            ++i
        ) {
            root.addCandidate(
                candidates,

                xValues[i],

                blocker.y -
                    height -
                    gap,

                width,
                height,

                origin
            )

            root.addCandidate(
                candidates,

                xValues[i],

                blocker.y +
                    blocker.height +
                    gap,

                width,
                height,

                origin
            )
        }
    }

    // ============================================================
    // LOCAL FALLBACK SEARCH
    // ============================================================

    function addGridCandidates(
        candidates,
        origin
    ) {
        const radius =
            Math.max(
                0,
                root.releaseSearchRadius
            )

        const step =
            Math.max(
                4,
                root.releaseSearchStep
            )

        for (
            let distance = step;
            distance <= radius;
            distance += step
        ) {
            root.addCandidate(
                candidates,
                origin.x + distance,
                origin.y,
                origin.width,
                origin.height,
                origin
            )

            root.addCandidate(
                candidates,
                origin.x - distance,
                origin.y,
                origin.width,
                origin.height,
                origin
            )

            root.addCandidate(
                candidates,
                origin.x,
                origin.y + distance,
                origin.width,
                origin.height,
                origin
            )

            root.addCandidate(
                candidates,
                origin.x,
                origin.y - distance,
                origin.width,
                origin.height,
                origin
            )

            root.addCandidate(
                candidates,
                origin.x + distance,
                origin.y + distance,
                origin.width,
                origin.height,
                origin
            )

            root.addCandidate(
                candidates,
                origin.x - distance,
                origin.y + distance,
                origin.width,
                origin.height,
                origin
            )

            root.addCandidate(
                candidates,
                origin.x + distance,
                origin.y - distance,
                origin.width,
                origin.height,
                origin
            )

            root.addCandidate(
                candidates,
                origin.x - distance,
                origin.y - distance,
                origin.width,
                origin.height,
                origin
            )
        }
    }

    // ============================================================
    // RELEASE SOLVER
    // ============================================================

    function findReleasePlacement(
        delegate
    ) {
        const origin =
            root.makeRect(
                delegate.targetX,
                delegate.targetY,
                delegate.targetWidth,
                delegate.targetHeight
            )

        const candidates = []

        /*
         * First gather EVERY actual collision.
         */
        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const other =
                widgetRepeater.itemAt(i)

            if (!other)
                continue

            if (
                other.instanceId ===
                delegate.instanceId
            ) {
                continue
            }

            if (
                !root.pairBlocks(
                    delegate,
                    other
                )
            ) {
                continue
            }

            const blocker =
                root.makeRect(
                    other.targetX,
                    other.targetY,
                    other.targetWidth,
                    other.targetHeight
                )

            if (
                root.intersects(
                    origin,
                    blocker
                )
            ) {
                root.addEdgeCandidates(
                    candidates,
                    delegate,
                    blocker,
                    origin
                )
            }
        }

        /*
         * Only after all exact candidates exist do we add the
         * generic local search.
         */
        root.addGridCandidates(
            candidates,
            origin
        )

        let best = null
        let bestDistance = Infinity

        const seen = []

        for (
            let i = 0;
            i < candidates.length;
            ++i
        ) {
            const candidate =
                candidates[i]

            /*
             * Cheap duplicate rejection.
             */
            let duplicate = false

            for (
                let j = 0;
                j < seen.length;
                ++j
            ) {
                if (
                    Math.abs(
                        seen[j].x -
                        candidate.x
                    ) < 0.5 &&
                    Math.abs(
                        seen[j].y -
                        candidate.y
                    ) < 0.5
                ) {
                    duplicate = true
                    break
                }
            }

            if (duplicate)
                continue

            seen.push(candidate)

            /*
             * THIS is the important multi-widget test:
             *
             * candidate must fit against the whole layout.
             */
            if (
                !root.isRectValid(
                    delegate,
                    candidate
                )
            ) {
                continue
            }

            const distance =
                root.rectMovementSquared(
                    candidate,
                    origin
                )

            if (
                distance <
                bestDistance
            ) {
                bestDistance =
                    distance

                best =
                    candidate
            }
        }

        return best
    }

    // ============================================================
    // FOLLOWER
    // ============================================================

    FrameAnimation {
        id: follower

        running:
            root.editMode ||
            root.pendingCommitCount > 0

        onTriggered: {
            const dt =
                Math.min(
                    root.maxFrameTime,
                    Math.max(
                        0,
                        frameTime
                    )
                )

            if (dt <= 0)
                return

            const alpha =
                1 -
                Math.exp(
                    -root.followResponse *
                    dt
                )

            let pending = 0

            for (
                let i = 0;
                i < widgetRepeater.count;
                ++i
            ) {
                const item =
                    widgetRepeater.itemAt(i)

                if (!item)
                    continue

                item.x +=
                    (
                        item.targetX -
                        item.x
                    ) * alpha

                item.y +=
                    (
                        item.targetY -
                        item.y
                    ) * alpha

                item.width +=
                    (
                        item.targetWidth -
                        item.width
                    ) * alpha

                item.height +=
                    (
                        item.targetHeight -
                        item.height
                    ) * alpha

                const settled =
                    Math.abs(
                        item.targetX -
                        item.x
                    ) < 0.15 &&
                    Math.abs(
                        item.targetY -
                        item.y
                    ) < 0.15 &&
                    Math.abs(
                        item.targetWidth -
                        item.width
                    ) < 0.15 &&
                    Math.abs(
                        item.targetHeight -
                        item.height
                    ) < 0.15

                if (settled) {
                    item.x =
                        item.targetX

                    item.y =
                        item.targetY

                    item.width =
                        item.targetWidth

                    item.height =
                        item.targetHeight
                }

                if (
                    item.dragging ||
                    item.resizing ||
                    item.pendingCommit
                ) {
                    root.updateCollisionState(
                        item
                    )
                }

                if (
                    item.pendingCommit
                ) {
                    if (settled) {
                        item.pendingCommit =
                            false

                        WidgetManager.updateInstance(
                            root.screenName,
                            item.instanceId,
                            {
                                x:
                                    Math.round(
                                        item.targetX
                                    ),

                                y:
                                    Math.round(
                                        item.targetY
                                    ),

                                width:
                                    Math.round(
                                        item.targetWidth
                                    ),

                                height:
                                    Math.round(
                                        item.targetHeight
                                    ),

                                variant:
                                    item.variant
                            }
                        )
                    } else {
                        ++pending
                    }
                }
            }

            root.pendingCommitCount =
                pending
        }
    }

    // ============================================================
    // WIDGET TREE
    // ============================================================

    Item {
        id: widgetRoot

        anchors.fill: parent

        MouseArea {
            anchors.fill: parent

            visible:
                root.editMode

            enabled:
                root.editMode

            acceptedButtons:
                Qt.LeftButton

            z: -100

            onPressed: function(mouse) {
                root.clearSelection()
                mouse.accepted = true
            }
        }

        Repeater {
            id: widgetRepeater

            model:
                root.widgetEntries

            delegate: Item {
                id: delegate

                required property var modelData

                readonly property var instance:
                    delegate.modelData

                readonly property string instanceId:
                    String(
                        delegate.instance.instanceId ||
                        ""
                    )

                readonly property string widgetId:
                    String(
                        delegate.instance.widgetId ||
                        ""
                    )

                readonly property string variant:
                    String(
                        delegate.instance.variant ||
                        ""
                    )

                readonly property var definition:
                    root.widgetDefinition(
                        delegate.widgetId
                    )

                property Item widgetItem:
                    widgetLoader.item

                // =================================================
                // TARGET GEOMETRY
                // =================================================

                property real targetX:
                    Number(
                        delegate.instance.x
                    ) || 0

                property real targetY:
                    Number(
                        delegate.instance.y
                    ) || 0

                property real targetWidth:
                    Math.max(
                        1,
                        Number(
                            delegate.instance.width
                        ) || 240
                    )

                property real targetHeight:
                    Math.max(
                        1,
                        Number(
                            delegate.instance.height
                        ) || 120
                    )

                // =================================================
                // RENDERED GEOMETRY
                // =================================================

                x: 0
                y: 0
                width: 0
                height: 0

                Component.onCompleted: {
                    delegate.x =
                        delegate.targetX

                    delegate.y =
                        delegate.targetY

                    delegate.width =
                        delegate.targetWidth

                    delegate.height =
                        delegate.targetHeight
                }

                // =================================================
                // STATE
                // =================================================

                property bool dragging:
                    false

                property bool resizing:
                    false

                property bool colliding:
                    false

                property bool pendingCommit:
                    false

                readonly property bool isValidConfig:
                    root.isRectValid(
                        delegate,
                        root.makeRect(
                            delegate.targetX,
                            delegate.targetY,
                            delegate.targetWidth,
                            delegate.targetHeight
                        )
                    )

                // =================================================
                // DRAG ANCHOR
                // =================================================

                property real grabOffsetX:
                    0

                property real grabOffsetY:
                    0

                property real dragPointerStartX:
                    0

                property real dragPointerStartY:
                    0

                property real dragTargetStartX:
                    0

                property real dragTargetStartY:
                    0

                // =================================================
                // Z ORDER
                // =================================================

                /*
                 * The WHOLE selected delegate is elevated.
                 *
                 * pendingCommit keeps it elevated during release
                 * settling.
                 */
                z:
                    delegate.dragging ||
                    delegate.resizing ||
                    delegate.pendingCommit
                        ? root.activeWidgetZ
                        : (
                            delegate.instanceId ===
                                root.selectedInstanceId
                                ? root.selectedWidgetZ
                                : root.normalWidgetZ
                        )

                // =================================================
                // SELECTED SHADOW
                // =================================================

                RectangularShadow {
                    visible:
                        root.editMode &&
                        delegate.instanceId ===
                            root.selectedInstanceId

                    anchors.centerIn:
                        parent

                    width:
                        parent.width +
                        root.selectedShadowSize * 2

                    height:
                        parent.height +
                        root.selectedShadowSize * 2

                    radius: 7

                    color:
                        root.selectedShadowColor

                    blur:
                        root.selectedShadowBlur

                    spread:
                        root.selectedShadowSize

                    opacity:
                        root.selectedShadowOpacity

                    z: -100
                }

                // =================================================
                // WIDGET
                // =================================================

                Loader {
                    id: widgetLoader

                    anchors.fill:
                        parent

                    asynchronous:
                        false

                    source:
                        root.widgetSource(
                            delegate.widgetId
                        )

                    onLoaded: {
                        if (!item)
                            return

                        if (
                            typeof item.initializeInstance ===
                            "function"
                        ) {
                            item.initializeInstance(
                                delegate.instanceId,
                                delegate.widgetId,
                                root.screenName,
                                delegate.instance.config || {},
                                delegate.variant,
                                delegate.definition || {}
                            )
                        }

                        item.editMode =
                            root.editMode

                        item.selected =
                            root.selectedInstanceId ===
                            delegate.instanceId
                    }
                }

                // =================================================
                // EDIT OVERLAY
                // =================================================

                WidgetEditOverlay {
                    id: editOverlay

                    /*
                     * The overlay intentionally extends outside the
                     * widget. Its internal `bounds` item stays aligned
                     * with the widget itself.
                     */
                    z: 1000

                    editMode:
                        root.editMode

                    selected:
                        root.selectedInstanceId ===
                        delegate.instanceId

                    draggable:
                        delegate.widgetItem
                            ? delegate.widgetItem
                                .effectiveDraggable
                            : false

                    resizable:
                        delegate.widgetItem
                            ? delegate.widgetItem
                                .effectiveResizable
                            : false

                    invalid:
                        delegate.colliding

                    coordinateTarget:
                        widgetRoot

                    controlMargin:
                        18

                    handleSize:
                        10

                    handleHitboxSize:
                        34

                    normalBorderColor:
                        root.debugNormalBorder

                    selectedBorderColor:
                        root.debugSelectedBorder

                    invalidBorderColor:
                        root.debugInvalidBorder

                    normalFillColor:
                        root.isDebug
                            ? Qt.rgba(
                                0.35,
                                0.23,
                                0.50,
                                0.10
                            )
                            : Qt.rgba(
                                0,
                                0,
                                0,
                                0
                            )

                    selectedFillColor:
                        Qt.rgba(
                            0.16,
                            0.78,
                            1.0,
                            0.10
                        )

                    invalidFillColor:
                        Qt.rgba(
                            1.0,
                            0.12,
                            0.20,
                            0.07
                        )

                    onSelectedRequest: {
                        root.selectWidget(
                            delegate.instanceId
                        )
                    }

                    onDragStarted:
                        function(
                            pointerX,
                            pointerY
                        ) {
                            root.beginDrag(
                                delegate,
                                pointerX,
                                pointerY
                            )
                        }

                    onDragMoved:
                        function(
                            pointerX,
                            pointerY
                        ) {
                            root.moveDrag(
                                delegate,
                                pointerX,
                                pointerY
                            )
                        }

                    onDragFinished: {
                        root.endDrag(
                            delegate
                        )
                    }

                    onResizeStarted:
                        function(
                            handle,
                            pointerX,
                            pointerY
                        ) {
                            root.beginResize(
                                delegate,
                                handle,
                                pointerX,
                                pointerY
                            )
                        }

                    onResizeMoved:
                        function(
                            handle,
                            pointerX,
                            pointerY
                        ) {
                            root.moveResize(
                                delegate,
                                pointerX,
                                pointerY
                            )
                        }

                    onResizeFinished: {
                        root.endResize(
                            delegate
                        )
                    }
                }

                // =================================================
                // DEBUG BOUNDS
                // =================================================

                Rectangle {
                    anchors.fill:
                        parent

                    visible:
                        root.isDebug

                    z: 50

                    color:
                        root.debugWidgetTint

                    border.width:
                        delegate.colliding
                            ? 2
                            : 1

                    border.color:
                        delegate.colliding
                            ? root.debugInvalidBorder
                            : (
                                delegate.instanceId ===
                                    root.selectedInstanceId
                                    ? root.debugSelectedBorder
                                    : root.debugNormalBorder
                            )

                    radius: 4

                    enabled: false

                    Text {
                        anchors.centerIn:
                            parent

                        width:
                            Math.max(
                                0,
                                parent.width - 12
                            )

                        color:
                            root.debugTextColor

                        font.family:
                            "monospace"

                        font.pixelSize:
                            10

                        horizontalAlignment:
                            Text.AlignHCenter

                        wrapMode:
                            Text.Wrap

                        text:
                            delegate.widgetItem
                                ? (
                                    delegate.widgetId +
                                    "\n" +
                                    "instance=" +
                                    delegate.instanceId +
                                    "\n" +
                                    "variant=" +
                                    delegate.widgetItem
                                        .effectiveVariant +
                                    "\n" +
                                    "drag=" +
                                    delegate.widgetItem
                                        .effectiveDraggable +
                                    "  resize=" +
                                    delegate.widgetItem
                                        .effectiveResizable +
                                    "\n" +
                                    "canIntersect=" +
                                    delegate.widgetItem
                                        .effectiveCanIntersect +
                                    "\n" +
                                    "isValid=" +
                                    delegate.isValidConfig +
                                    "  collision=" +
                                    delegate.colliding +
                                    "\n" +
                                    "z=" +
                                    delegate.z +
                                    "\n" +
                                    "target=" +
                                    Math.round(
                                        delegate.targetX
                                    ) +
                                    "," +
                                    Math.round(
                                        delegate.targetY
                                    ) +
                                    "  " +
                                    Math.round(
                                        delegate.targetWidth
                                    ) +
                                    "x" +
                                    Math.round(
                                        delegate.targetHeight
                                    )
                                )
                                : (
                                    delegate.widgetId +
                                    "\nLOADER FAILED"
                                )
                    }
                }
            }
        }

        // ========================================================
        // DEBUG TINT
        // ========================================================

        Rectangle {
            anchors.fill: parent

            visible:
                root.isDebug

            z: 10

            color:
                root.debugLayerColor

            enabled: false
        }

        // ========================================================
        // DEBUG HUD
        // ========================================================

        Rectangle {
            visible:
                root.isDebug

            anchors {
                left: parent.left
                top: parent.top
                margins: 12
            }

            width: 440
            height: 120

            radius: 9

            color:
                root.debugTextBackground

            border.width:
                1

            border.color:
                root.debugNormalBorder

            z: 10000

            Column {
                anchors.fill:
                    parent

                anchors.margins:
                    10

                spacing:
                    4

                Text {
                    color:
                        root.debugTextColor

                    text:
                        "WIDGET LAYER DEBUG"
                }

                Text {
                    color:
                        "#b9a8c3"

                    text:
                        "screen: " +
                        root.screenName
                }

                Text {
                    color:
                        "#b9a8c3"

                    text:
                        "area: " +
                        Math.round(root.width) +
                        " × " +
                        Math.round(root.height)
                }

                Text {
                    color:
                        "#b9a8c3"

                    text:
                        "mode: " +
                        (
                            root.editMode
                                ? "EDIT"
                                : "RUNTIME"
                        ) +
                        "   selected: " +
                        (
                            root.selectedInstanceId ||
                            "none"
                        )
                }

                Text {
                    color:
                        "#b9a8c3"

                    text:
                        "follow: " +
                        root.followResponse +
                        "   search: " +
                        root.releaseSearchRadius +
                        "px"
                }
            }
        }
    }

    // ============================================================
    // EDIT MODE TOGGLE — always visible, CutBox reuse
    // ============================================================

    CutBox {
        id: editModeToggle
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12
        width: 148
        height: 36
        z: 5000
        interactive: true
        bgColor: root.editMode ? "#1a3039" : "#0b1117"
        borderColor: root.editMode ? "#2acfff" : "#273944"
        borderWidth: 1
        borderGlow: root.editMode ? 8 : 0
        cut: ({ topLeft: 8, topRight: 8, bottomRight: 8, bottomLeft: 8 })
        onClicked: function(mouse) {
            console.log("[WidgetLayer] editModeToggle clicked, before:", root.editMode)
            root.editMode = !root.editMode
            console.log("[WidgetLayer] editMode now:", root.editMode)
        }
        Text {
            anchors.centerIn: parent
            text: root.editMode ? "󰌑  Exit Edit" : "󰌑  Enter Edit"
            color: root.editMode ? "#2acfff" : "#e8edf0"
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
        }
    }

    // ============================================================
    // RUNTIME MENU — showcase: mandatory Obj, children, nested, 90% + fade
    // ============================================================

    Component {
        id: runtimeContextMenu
        Column {
            width: 260
            spacing: 0

            // header — disabled info
            ContextMenuObj {
                text: "󰇄  Desktop  •  " + root.screenName
                enabled: false
            }

            ContextMenuObj {
                text: "󰌑  Enter Edit Mode"
                functionAction: function() {
                    console.log("[WidgetLayer][Runtime] Enter Edit Mode")
                    root.editMode = true
                }
            }

            // showcase: parent with left-aligned children below text
            ContextMenuObj {
                text: "󰚟  Showcase — children below"
                // children are left-aligned below header, per spec
                ContextMenuObj { text: "  󰀻  Child A — left aligned"; functionAction: function(){ console.log("[Runtime] Child A") } }
                ContextMenuObj { text: "  󰀻  Child B — left aligned"; functionAction: function(){ console.log("[Runtime] Child B") } }
            }

            ContextMenuObj {
                text: "󰐕  Add Widget  — scroll/fade demo"
                submenu: widgetAddMenu
            }

            ContextMenuObj {
                text: "󰈙  Tools  — nested (no limit)"
                submenu: runtimeToolsMenu
            }

            ContextMenuObj {
                text: "󰦚  Deep Nest — 4 levels"
                submenu: deepLevel1
            }

            ContextMenuObj {
                text: "󰑓  Reload Widgets"
                functionAction: function() {
                    console.log("[WidgetLayer][Runtime] Reload")
                    root.reloadWidgets()
                }
            }

            ContextMenuObj {
                text: "󰈆  Close"
                closeOnClick: true
            }
        }
    }

    Component {
        id: widgetAddMenu
        Column {
            width: 260
            spacing: 0
            // many items to force 90% clamp + vertical fade
            ContextMenuObj { text: "󰃭  Clock"; functionAction: function(){ console.log("[Add] Clock") } }
            ContextMenuObj { text: "󰻠  CPU"; functionAction: function(){ console.log("[Add] CPU") } }
            ContextMenuObj { text: "󰖟  Weather"; functionAction: function(){ console.log("[Add] Weather") } }
            ContextMenuObj { text: "󰋩  Music"; functionAction: function(){ console.log("[Add] Music") } }
            ContextMenuObj { text: "󰎄  Calendar"; functionAction: function(){ console.log("[Add] Calendar") } }
            ContextMenuObj { text: "󰞉  System"; functionAction: function(){ console.log("[Add] System") } }
            ContextMenuObj { text: "󰇮  Network"; functionAction: function(){ console.log("[Add] Network") } }
            ContextMenuObj { text: "󰋜  Battery"; functionAction: function(){ console.log("[Add] Battery") } }
            ContextMenuObj { text: "󰓇  Volume"; functionAction: function(){ console.log("[Add] Volume") } }
            ContextMenuObj { text: "󰍹  Brightness"; functionAction: function(){ console.log("[Add] Brightness") } }
            ContextMenuObj { text: "󰀻  Launcher"; functionAction: function(){ console.log("[Add] Launcher") } }
            ContextMenuObj { text: "󰣖  Notes"; functionAction: function(){ console.log("[Add] Notes") } }
            ContextMenuObj { text: "󰟶  Todo"; functionAction: function(){ console.log("[Add] Todo") } }
            ContextMenuObj { text: "󰷈  Stocks"; functionAction: function(){ console.log("[Add] Stocks") } }
            ContextMenuObj { text: "󰨇  Gallery"; functionAction: function(){ console.log("[Add] Gallery") } }
            ContextMenuObj { text: "󰨞  Terminal"; functionAction: function(){ console.log("[Add] Terminal") } }
            ContextMenuObj { text: "󰆍  Files"; functionAction: function(){ console.log("[Add] Files") } }
            ContextMenuObj { text: "󰊻  Browser"; functionAction: function(){ console.log("[Add] Browser") } }
            ContextMenuObj { text: "󰢻  Chat"; functionAction: function(){ console.log("[Add] Chat") } }
            ContextMenuObj { text: "󰚰  Map"; functionAction: function(){ console.log("[Add] Map") } }
            // horizontal overflow demo — very long text forces 90% width + horizontal fade
            ContextMenuObj { text: "󰹑  Super long widget name that exceeds 90% width and should trigger horizontal fade — " + "x".repeat(40) }
        }
    }

    Component {
        id: runtimeToolsMenu
        Column {
            width: 240
            spacing: 0
            ContextMenuObj { text: "󰐕  Add Widget"; submenu: widgetAddMenu }
            ContextMenuObj { text: "󰋊  Presets"; submenu: presetsMenu }
            ContextMenuObj {
                text: "󰦪  Actions with children"
                ContextMenuObj { text: "  󰄬  Child action 1" }
                ContextMenuObj { text: "  󰄬  Child action 2" }
            }
        }
    }

    Component {
        id: presetsMenu
        Column {
            width: 220
            spacing: 0
            ContextMenuObj { text: "󰀻  Minimal" }
            ContextMenuObj { text: "󰀻  Gaming"; submenu: deepLevel1 }
            ContextMenuObj { text: "󰀻  Work" }
        }
    }

    Component { id: deepLevel1; Column { width: 220; spacing:0
        ContextMenuObj { text: "󰆍  Level 1 — A"; submenu: deepLevel2 }
        ContextMenuObj { text: "󰆍  Level 1 — B" }
    }}
    Component { id: deepLevel2; Column { width: 220; spacing:0
        ContextMenuObj { text: "󰆍  Level 2 — A"; submenu: deepLevel3 }
        ContextMenuObj { text: "󰆍  Level 2 — B" }
    }}
    Component { id: deepLevel3; Column { width: 220; spacing:0
        ContextMenuObj { text: "󰆍  Level 3 — A"; submenu: deepLevel4 }
        ContextMenuObj { text: "󰆍  Level 3 — B" }
    }}
    Component { id: deepLevel4; Column { width: 220; spacing:0
        ContextMenuObj { text: "󰄾  Level 4 — end (no limit demo)" }
        ContextMenuObj { text: "󰄾  Back to root"; submenu: deepLevel1 }
    }}

    // ============================================================
    // EDIT MENU — showcase + edit-specific
    // ============================================================

    Component {
        id: editContextMenu
        Column {
            width: 260
            spacing: 0

            ContextMenuObj {
                text: "󰌑  Exit Edit Mode"
                functionAction: function() {
                    console.log("[WidgetLayer][Edit] Exit Edit Mode")
                    root.editMode = false
                }
            }

            ContextMenuObj {
                text: "󰐕  Add Widget  — scroll/fade demo"
                submenu: widgetAddMenu
            }

            ContextMenuObj {
                text: "󰦪  Layer Tools"
                submenu: editToolsMenu
            }

            ContextMenuObj {
                text: "󰅖  Clear Selection"
                enabled: root.selectedInstanceId !== ""
                functionAction: function() {
                    console.log("[WidgetLayer][Edit] Clear Selection", root.selectedInstanceId)
                    root.clearSelection()
                }
            }

            // showcase selected widget with children
            ContextMenuObj {
                text: "󰄭  Selection: " + (root.selectedInstanceId || "none")
                enabled: false
                // children show details left-aligned below header
                ContextMenuObj { text: "  󰀻  ID: " + (root.selectedInstanceId || "—") ; enabled: false }
                ContextMenuObj { text: "  󰀻  Tap to focus"; functionAction: function(){
                    var d=root.findDelegate(root.selectedInstanceId); if(d&&d.widgetItem&&d.widgetItem.focusWidget) d.widgetItem.focusWidget()
                }}
            }

            ContextMenuObj {
                text: "󰦚  Deep Nest — edit"
                submenu: deepLevel1
            }

            ContextMenuObj {
                text: "󰈆  Close"
            }
        }
    }

    Component {
        id: editToolsMenu
        Column {
            width: 260
            spacing: 0
            ContextMenuObj { text: "󰆏  Save Layout"; functionAction: function(){ console.log("[WidgetLayer][Edit] Save Layout") } }
            ContextMenuObj { text: "󰉨  Save as Preset"; functionAction: function(){ console.log("[WidgetLayer][Edit] Save Preset") } }
            ContextMenuObj { text: "󰒓  Widget Settings"; submenu: widgetSettingsMenu }
            ContextMenuObj {
                text: "󰦪  Debug — toggle"
                // showcase children
                ContextMenuObj { text: "  󰀻  Debug: " + (root.isDebug ? "ON" : "OFF"); functionAction: function(){ root.isDebug = !root.isDebug; console.log("[WidgetLayer] isDebug", root.isDebug)} }
            }
        }
    }

    Component {
        id: widgetSettingsMenu
        Column {
            width: 240
            spacing: 0
            ContextMenuObj { text: "󰏃  Size: small"; functionAction: function(){ console.log("[WidgetLayer] size small") } }
            ContextMenuObj { text: "󰏃  Size: large"; functionAction: function(){ console.log("[WidgetLayer] size large") } }
            ContextMenuObj { text: "󰏃  Opacity"; submenu: deepLevel2 }
        }
    }

    // ============================================================
    // MANAGER
    // ============================================================

    Connections {
        target:
            WidgetManager

        function onInstancesChanged(
            changedScreen
        ) {
            if (
                changedScreen ===
                root.screenName &&
                root.pendingCommitCount === 0 &&
                root.activeInteractionInstanceId === ""
            ) {
                root.reloadWidgets()
            }
        }

        function onConfigurationLoaded() {
            if (
                root.pendingCommitCount === 0 &&
                root.activeInteractionInstanceId === ""
            ) {
                root.reloadWidgets()
            }
        }
    }

    // ============================================================
    // REGISTRY
    // ============================================================

    Connections {
        target:
            WidgetRegistry

        function onRegistryChanged() {
            root.reloadWidgets()
        }
    }

    // ============================================================
    // MODE
    // ============================================================

    onEditModeChanged: {
        root.activeInteractionInstanceId =
            ""

        root.activeResizeHandle =
            ""

        root.clearCollisionState()

        if (!root.editMode)
            root.clearSelection()

        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const delegate =
                widgetRepeater.itemAt(i)

            if (
                delegate &&
                delegate.widgetItem
            ) {
                delegate.widgetItem.editMode =
                    root.editMode

                delegate.widgetItem.selected =
                    delegate.instanceId ===
                    root.selectedInstanceId

                delegate.widgetItem.dragging =
                    false

                delegate.widgetItem.resizing =
                    false

                delegate.dragging =
                    false

                delegate.resizing =
                    false

                delegate.colliding =
                    false
            }
        }
    }

    // ============================================================
    // SELECTION
    // ============================================================

    onSelectedInstanceIdChanged: {
        for (
            let i = 0;
            i < widgetRepeater.count;
            ++i
        ) {
            const delegate =
                widgetRepeater.itemAt(i)

            if (
                delegate &&
                delegate.widgetItem
            ) {
                delegate.widgetItem.selected =
                    delegate.instanceId ===
                    root.selectedInstanceId
            }
        }
    }

    // ============================================================
    // SCREEN
    // ============================================================

    onScreenNameChanged:
        root.reloadWidgets()

    // ============================================================
    // STARTUP
    // ============================================================

    Component.onCompleted: {
        console.log(
            "[WidgetLayer] READY:",
            root.screenName
        )

        root.reloadWidgets()
    }
}