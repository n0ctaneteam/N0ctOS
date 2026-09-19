pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.core.ui

Singleton {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    readonly property bool isOpen:
        internalRoot.menuOpen

    readonly property bool menuOpen:
        internalRoot.menuOpen

    /*
     * Public contract:
     *
     *     ContextMenu.open(component)
     *     ContextMenu.close()
     *
     * Cursor position, monitor and compositor-reserved space are
     * resolved internally.
     */
    function open(component) {
        internalRoot.open(component)
    }

    function close() {
        internalRoot.close()
    }

    function notifyHovered(object) {
        if (!object)
            return

        internalRoot.objectHovered(
            object,
            object.contextMenuDepth
        )
    }

    function notifyExited(object) {
        if (!object)
            return

        internalRoot.objectExited(
            object,
            object.contextMenuDepth
        )
    }

    function notifyClicked(object) {
        if (!object)
            return

        internalRoot.objectClicked(
            object
        )
    }

    function isSubmenuVisibleFor(object) {
        return internalRoot.isSubmenuVisibleFor(
            object
        )
    }

    // ============================================================
    // MENU WINDOW
    // ============================================================

    PanelWindow {
        id: menuWindow

        screen:
            internalRoot.targetScreen

        visible:
            internalRoot.menuOpen &&
            internalRoot.targetScreen !== null

        color:
            "transparent"

        /*
         * The context menu itself does not reserve space.
         *
         * Reservations are read from Hyprland and applied manually
         * to the positioning rectangle.
         */
        exclusionMode:
            ExclusionMode.Ignore

        /*
         * Context menu belongs above the normal shell UI.
         */
        WlrLayershell.layer:
            WlrLayer.Overlay

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        /*
         * Opposite anchors make this surface the size of the
         * target screen. ([quickshell.org](https://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/?utm_source=chatgpt.com))
         */
        Item {
            id: internalRoot

            anchors.fill:
                parent

            // ====================================================
            // OPEN STATE
            // ====================================================

            property bool menuOpen:
                false

            property Component requestedComponent:
                null

            /*
             * Every open() call increments this.
             *
             * There is intentionally NO:
             *
             *     if (menuOpen) return
             */
            property int requestGeneration:
                0

            // ====================================================
            // CURSOR / MONITOR
            // ====================================================

            /*
             * Hyprland global-layout cursor coordinates.
             */
            property point cursorGlobal:
                Qt.point(0, 0)

            /*
             * Hyprland monitor JSON object.
             */
            property var targetMonitor:
                null

            /*
             * Matching Quickshell ShellScreen.
             */
            property var targetScreen:
                null

            /*
             * Monitor JSON and ShellScreen may differ under output
             * scaling, so map cursor/reservations between them.
             */
            readonly property real scaleX:
                targetMonitor &&
                targetScreen &&
                Number(targetMonitor.width) > 0
                    ? Number(targetScreen.width) /
                      Number(targetMonitor.width)
                    : 1

            readonly property real scaleY:
                targetMonitor &&
                targetScreen &&
                Number(targetMonitor.height) > 0
                    ? Number(targetScreen.height) /
                      Number(targetMonitor.height)
                    : 1

            /*
             * Cursor in target-screen local coordinates.
             */
            readonly property point cursorLocal:
                targetMonitor
                    ? Qt.point(
                        (
                            cursorGlobal.x -
                            Number(targetMonitor.x)
                        ) *
                        scaleX,

                        (
                            cursorGlobal.y -
                            Number(targetMonitor.y)
                        ) *
                        scaleY
                    )
                    : Qt.point(0, 0)

            readonly property real cursorX:
                cursorLocal.x

            readonly property real cursorY:
                cursorLocal.y

            // ====================================================
            // HYPRLAND QUERY STATE
            // ====================================================

            property bool cursorResultReady:
                false

            property bool monitorResultReady:
                false

            property int cursorResultGeneration:
                0

            property int monitorResultGeneration:
                0

            /*
             * Keep the complete monitor result.
             *
             * This prevents a race where monitorProcess finishes
             * before cursorProcess and accidentally resolves a
             * monitor using an old cursor position.
             */
            property var monitorResult:
                null

            // ====================================================
            // RESERVED SPACE
            // ====================================================

            property real reservedTop:
                0

            property real reservedBottom:
                0

            property real reservedLeft:
                0

            property real reservedRight:
                0

            /*
             * Screen-local compositor-free rectangle.
             */
            readonly property real availableX:
                reservedLeft

            readonly property real availableY:
                reservedTop

            readonly property real availableWidth:
                targetScreen
                    ? Math.max(
                        1,

                        Number(targetScreen.width) -
                        reservedLeft -
                        reservedRight
                    )
                    : 1

            readonly property real availableHeight:
                targetScreen
                    ? Math.max(
                        1,

                        Number(targetScreen.height) -
                        reservedTop -
                        reservedBottom
                    )
                    : 1

            readonly property real availableRight:
                availableX +
                availableWidth

            readonly property real availableBottom:
                availableY +
                availableHeight

            // ====================================================
            // MENU SIZE RULES
            // ====================================================

            property real screenMargin:
                10

            property real maximumScreenFraction:
                0.80

            property real minimumWidth:
                180

            property int menuPadding:
                4

            readonly property real maximumWidth:
                targetScreen
                    ? Math.max(
                        1,

                        Math.min(
                            Number(
                                targetScreen.width
                            ) *
                            maximumScreenFraction,

                            Math.max(
                                1,

                                availableWidth -
                                screenMargin * 2
                            )
                        )
                    )
                    : 1

            readonly property real maximumHeight:
                targetScreen
                    ? Math.max(
                        1,

                        Math.min(
                            Number(
                                targetScreen.height
                            ) *
                            maximumScreenFraction,

                            Math.max(
                                1,

                                availableHeight -
                                screenMargin * 2
                            )
                        )
                    )
                    : 1

            // ====================================================
            // ANIMATION
            // ====================================================

            property int animationDuration:
                180

            property int positionAnimationDuration:
                180

            /*
             * This only exists to make parent → submenu travel
             * tolerant enough for real pointer movement.
             */
            property int submenuCloseDelay:
                110

            // ====================================================
            // SUBMENUS
            // ====================================================

            property int maxDepth:
                16

            property int submenuGap:
                3

            /*
             * One state slot per submenu depth.
             */
            property var submenuPinned:
                []

            property var parentHovered:
                []

            property var submenuHovered:
                []

            property var submenuParents:
                []

            /*
             * Generation counter per depth.
             *
             * Delayed callbacks compare against this and abort if
             * they are stale.
             */
            property var submenuGeneration:
                []

            // ====================================================
            // VISUAL
            // ====================================================

            property color backgroundColor:
                "#090d12"

            property color borderColor:
                "#263541"

            property int borderWidth:
                1

            property real radius:
                8

            // ====================================================
            // CORE HELPERS
            // ============================================================

            function boolAt(
                array,
                index
            ) {
                const i =
                    Number(index)

                return Boolean(
                    array &&
                    Number.isFinite(i) &&
                    i >= 0 &&
                    i < array.length &&
                    array[i] === true
                )
            }

            function levelAt(
                depth
            ) {
                const index =
                    Number(depth)

                if (
                    !Number.isFinite(index) ||
                    index < 0
                ) {
                    return null
                }

                return levelRepeater.itemAt(
                    index
                )
            }

            function parentAt(
                depth
            ) {
                const index =
                    Number(depth)

                if (
                    !Number.isFinite(index) ||
                    index < 0 ||
                    index >=
                        internalRoot.submenuParents.length
                ) {
                    return null
                }

                return (
                    internalRoot.submenuParents[
                        index
                    ] || null
                )
            }

            // ====================================================
            // OPEN
            // ====================================================

            function open(component) {
                if (!component) {
                    console.warn(
                        "[ContextMenu] open(): no component"
                    )

                    return
                }

                /*
                 * EVERY open() call is accepted.
                 */
                internalRoot.requestGeneration +=
                    1

                internalRoot.requestedComponent =
                    component

                /*
                 * Fresh query state.
                 */
                internalRoot.cursorResultReady =
                    false

                internalRoot.monitorResultReady =
                    false

                internalRoot.cursorResultGeneration =
                    internalRoot.requestGeneration

                internalRoot.monitorResultGeneration =
                    internalRoot.requestGeneration

                internalRoot.monitorResult =
                    null

                /*
                 * Root menu replacement happens immediately.
                 *
                 * If already visible, the old surface remains visible
                 * until the new geometry is ready.
                 */
                const rootLevel =
                    internalRoot.levelAt(0)

                if (rootLevel) {
                    rootLevel.prepareForOpen(
                        component,
                        internalRoot.menuOpen
                    )
                }

                /*
                 * Reset every submenu branch.
                 */
                internalRoot.resetSubmenuState()

                /*
                 * Do NOT close an already-open menu.
                 */
                if (
                    !internalRoot.menuOpen
                ) {
                    internalRoot.menuOpen =
                        true
                }

                /*
                 * Request a fresh live pointer snapshot.
                 */
                cursorProcess.exec([
                    "hyprctl",
                    "-j",
                    "cursorpos"
                ])

                /*
                 * Request fresh monitor + reservation state.
                 */
                monitorProcess.exec([
                    "hyprctl",
                    "-j",
                    "monitors"
                ])
            }

            // ====================================================
            // RESET SUBMENU STATE
            // ====================================================

            function resetSubmenuState() {
                internalRoot.submenuPinned =
                    []

                internalRoot.parentHovered =
                    []

                internalRoot.submenuHovered =
                    []

                internalRoot.submenuParents =
                    []

                internalRoot.submenuGeneration =
                    []
            }

            // ====================================================
            // CURSOR PROCESS
            // ====================================================

            Process {
                id: cursorProcess

                stdout:
                    StdioCollector {
                        onStreamFinished: {
                            internalRoot.consumeCursor(
                                text
                            )
                        }
                    }
            }

            function consumeCursor(
                rawText
            ) {
                if (
                    internalRoot.cursorResultGeneration !==
                    internalRoot.requestGeneration
                ) {
                    return
                }

                let parsed

                try {
                    parsed =
                        JSON.parse(
                            String(
                                rawText || ""
                            )
                        )
                } catch (error) {
                    console.warn(
                        "[ContextMenu] cursorpos parse failed:",
                        error
                    )

                    return
                }

                const x =
                    Number(parsed.x)

                const y =
                    Number(parsed.y)

                if (
                    !Number.isFinite(x) ||
                    !Number.isFinite(y)
                ) {
                    console.warn(
                        "[ContextMenu] invalid cursor:",
                        rawText
                    )

                    return
                }

                internalRoot.cursorGlobal =
                    Qt.point(
                        x,
                        y
                    )

                internalRoot.cursorResultReady =
                    true

                internalRoot.tryResolveOpen()
            }

            // ====================================================
            // MONITOR PROCESS
            // ====================================================

            Process {
                id: monitorProcess

                stdout:
                    StdioCollector {
                        onStreamFinished: {
                            internalRoot.consumeMonitors(
                                text
                            )
                        }
                    }
            }

            function consumeMonitors(
                rawText
            ) {
                if (
                    internalRoot.monitorResultGeneration !==
                    internalRoot.requestGeneration
                ) {
                    return
                }

                let parsed

                try {
                    parsed =
                        JSON.parse(
                            String(
                                rawText || ""
                            )
                        )
                } catch (error) {
                    console.warn(
                        "[ContextMenu] monitors parse failed:",
                        error
                    )

                    return
                }

                if (
                    !Array.isArray(parsed)
                ) {
                    console.warn(
                        "[ContextMenu] monitors result is not an array"
                    )

                    return
                }

                /*
                 * Store the complete result.
                 *
                 * DO NOT resolve the monitor yet.
                 *
                 * We must use the cursor belonging to the SAME
                 * open() request.
                 */
                internalRoot.monitorResult =
                    parsed

                internalRoot.monitorResultReady =
                    true

                internalRoot.tryResolveOpen()
            }

            // ====================================================
            // RESOLVE CURRENT REQUEST
            // ====================================================

            function tryResolveOpen() {
                if (
                    internalRoot.cursorResultGeneration !==
                    internalRoot.requestGeneration
                ) {
                    return
                }

                if (
                    internalRoot.monitorResultGeneration !==
                    internalRoot.requestGeneration
                ) {
                    return
                }

                if (
                    !internalRoot.cursorResultReady ||
                    !internalRoot.monitorResultReady
                ) {
                    return
                }

                const monitors =
                    internalRoot.monitorResult

                if (
                    !Array.isArray(monitors)
                ) {
                    return
                }

                /*
                 * IMPORTANT:
                 *
                 * Resolve monitor ONLY after both cursor and monitor
                 * results belong to the current request.
                 */
                const monitor =
                    internalRoot.monitorAtCursor(
                        monitors,

                        internalRoot.cursorGlobal.x,
                        internalRoot.cursorGlobal.y
                    )

                if (!monitor) {
                    console.warn(
                        "[ContextMenu] no monitor at cursor:",
                        internalRoot.cursorGlobal
                    )

                    return
                }

                const screen =
                    internalRoot.screenForMonitor(
                        monitor
                    )

                if (!screen) {
                    console.warn(
                        "[ContextMenu] no Quickshell screen for:",
                        monitor.name
                    )

                    return
                }

                internalRoot.targetMonitor =
                    monitor

                internalRoot.targetScreen =
                    screen

                internalRoot.applyReservedSpace(
                    monitor,
                    screen
                )

                const level =
                    internalRoot.levelAt(0)

                if (!level)
                    return

                /*
                 * Content may still be loading.
                 *
                 * Loader.onLoaded() will call tryResolveOpen() again.
                 */
                if (!level.activeItem)
                    return

                /*
                 * Natural size is explicitly measured before any
                 * position calculation.
                 */
                level.refreshGeometry()

                /*
                 * Root:
                 *
                 * first visible open → snap
                 * repeated open → slide
                 */
                const animate =
                    Boolean(
                        level.wasEverVisible
                    )

                level.positionRoot(
                    animate
                )

                level.openVisible()
            }

            // ====================================================
            // MONITOR FIND
            // ====================================================

            function monitorAtCursor(
                monitors,
                x,
                y
            ) {
                let nearest =
                    null

                let nearestDistance =
                    Infinity

                for (
                    let i = 0;
                    i < monitors.length;
                    ++i
                ) {
                    const monitor =
                        monitors[i]

                    if (!monitor)
                        continue

                    const mx =
                        Number(monitor.x)

                    const my =
                        Number(monitor.y)

                    const mw =
                        Number(monitor.width)

                    const mh =
                        Number(monitor.height)

                    if (
                        !Number.isFinite(mx) ||
                        !Number.isFinite(my) ||
                        !Number.isFinite(mw) ||
                        !Number.isFinite(mh) ||
                        mw <= 0 ||
                        mh <= 0
                    ) {
                        continue
                    }

                    if (
                        x >= mx &&
                        x < mx + mw &&
                        y >= my &&
                        y < my + mh
                    ) {
                        return monitor
                    }

                    /*
                     * Boundary fallback.
                     */
                    const closestX =
                        Math.max(
                            mx,
                            Math.min(
                                x,
                                mx + mw
                            )
                        )

                    const closestY =
                        Math.max(
                            my,
                            Math.min(
                                y,
                                my + mh
                            )
                        )

                    const dx =
                        x - closestX

                    const dy =
                        y - closestY

                    const distance =
                        dx * dx +
                        dy * dy

                    if (
                        distance <
                        nearestDistance
                    ) {
                        nearestDistance =
                            distance

                        nearest =
                            monitor
                    }
                }

                return nearest
            }

            // ====================================================
            // SCREEN MATCH
            // ====================================================

            function screenForMonitor(
                monitor
            ) {
                if (!monitor)
                    return null

                const name =
                    String(
                        monitor.name || ""
                    )

                const screens =
                    Quickshell.screens

                for (
                    let i = 0;
                    i < screens.length;
                    ++i
                ) {
                    const screen =
                        screens[i]

                    if (
                        screen &&
                        String(screen.name) ===
                            name
                    ) {
                        return screen
                    }
                }

                /*
                 * Geometry fallback.
                 */
                for (
                    let i = 0;
                    i < screens.length;
                    ++i
                ) {
                    const screen =
                        screens[i]

                    if (!screen)
                        continue

                    const sx =
                        Number(screen.x)

                    const sy =
                        Number(screen.y)

                    const sw =
                        Number(screen.width)

                    const sh =
                        Number(screen.height)

                    if (
                        internalRoot.cursorGlobal.x >= sx &&
                        internalRoot.cursorGlobal.x < sx + sw &&
                        internalRoot.cursorGlobal.y >= sy &&
                        internalRoot.cursorGlobal.y < sy + sh
                    ) {
                        return screen
                    }
                }

                return null
            }

            // ====================================================
            // RESERVATIONS
            // ====================================================

            function applyReservedSpace(
                monitor,
                screen
            ) {
                internalRoot.reservedTop =
                    0

                internalRoot.reservedBottom =
                    0

                internalRoot.reservedLeft =
                    0

                internalRoot.reservedRight =
                    0

                if (
                    !monitor ||
                    !screen
                ) {
                    return
                }

                const raw =
                    monitor.reserved

                let top =
                    0

                let bottom =
                    0

                let left =
                    0

                let right =
                    0

                /*
                 * Hyprland monitor data:
                 *
                 *     reserved: [top, bottom, left, right]
                 *
                 * ([wiki.hypr.land](https://wiki.hypr.land/configuring/core/monitors/))
                 */
                if (
                    Array.isArray(raw)
                ) {
                    top =
                        Number(
                            raw[0]
                        ) || 0

                    bottom =
                        Number(
                            raw[1]
                        ) || 0

                    left =
                        Number(
                            raw[2]
                        ) || 0

                    right =
                        Number(
                            raw[3]
                        ) || 0
                } else if (
                    raw &&
                    typeof raw ===
                        "object"
                ) {
                    top =
                        Number(
                            raw.top
                        ) || 0

                    bottom =
                        Number(
                            raw.bottom
                        ) || 0

                    left =
                        Number(
                            raw.left
                        ) || 0

                    right =
                        Number(
                            raw.right
                        ) || 0
                }

                /*
                 * Map compositor dimensions into ShellScreen logical
                 * dimensions.
                 */
                const sx =
                    Number(monitor.width) > 0
                        ? Number(screen.width) /
                          Number(monitor.width)
                        : 1

                const sy =
                    Number(monitor.height) > 0
                        ? Number(screen.height) /
                          Number(monitor.height)
                        : 1

                internalRoot.reservedTop =
                    Math.max(
                        0,
                        top * sy
                    )

                internalRoot.reservedBottom =
                    Math.max(
                        0,
                        bottom * sy
                    )

                internalRoot.reservedLeft =
                    Math.max(
                        0,
                        left * sx
                    )

                internalRoot.reservedRight =
                    Math.max(
                        0,
                        right * sx
                    )

                /*
                 * Malformed reservation protection.
                 */
                if (
                    internalRoot.reservedTop +
                    internalRoot.reservedBottom >=
                    Number(screen.height)
                ) {
                    internalRoot.reservedTop =
                        0

                    internalRoot.reservedBottom =
                        0
                }

                if (
                    internalRoot.reservedLeft +
                    internalRoot.reservedRight >=
                    Number(screen.width)
                ) {
                    internalRoot.reservedLeft =
                        0

                    internalRoot.reservedRight =
                        0
                }
            }

            // ====================================================
            // LEVEL ACCESS
            // ====================================================

            /*
             * These are intentionally defined on internalRoot,
             * not on the Repeater delegate.
             */
            function getLevel(
                depth
            ) {
                return internalRoot.levelAt(
                    depth
                )
            }

            // ====================================================
            // SIZE
            // ============================================================

            function calculateLevelWidth(
                naturalWidth
            ) {
                const desired =
                    Math.max(
                        1,
                        Number(naturalWidth) +
                        internalRoot.menuPadding * 2
                    )

                if (
                    !internalRoot.targetScreen
                ) {
                    return desired
                }

                const minimum =
                    Math.min(
                        internalRoot.minimumWidth,
                        internalRoot.maximumWidth
                    )

                return Math.max(
                    minimum,

                    Math.min(
                        desired,
                        internalRoot.maximumWidth
                    )
                )
            }

            function calculateLevelHeight(
                naturalHeight
            ) {
                const desired =
                    Math.max(
                        1,
                        Number(naturalHeight) +
                        internalRoot.menuPadding * 2
                    )

                return Math.max(
                    1,

                    Math.min(
                        desired,
                        internalRoot.maximumHeight
                    )
                )
            }

            // ====================================================
            // MENU LEVELS
            // ============================================================

            Repeater {
                id: levelRepeater

                model:
                    internalRoot.maxDepth

                delegate:
                    CutBox {
                        id: level

                        property int depth:
                            index

                        property bool opened:
                            false

                        property bool wasEverVisible:
                            false

                        /*
                         * Only root menu uses position animation.
                         *
                         * Submenus ALWAYS keep this false.
                         */
                        property bool positionAnimationEnabled:
                            false

                        property Component currentComponent:
                            null

                        property alias loader:
                            loader

                        readonly property Item activeItem:
                            loader.item

                        /*
                         * Explicit cached natural dimensions.
                         *
                         * These are NEVER bindings to rendered width /
                         * height.
                         */
                        property real naturalContentWidth:
                            1

                        property real naturalContentHeight:
                            1

                        width:
                            internalRoot.calculateLevelWidth(
                                level.naturalContentWidth
                            )

                        height:
                            internalRoot.calculateLevelHeight(
                                level.naturalContentHeight
                            )

                        opacity:
                            level.opened
                                ? 1
                                : 0

                        visible:
                            opacity > 0.001

                        clip:
                            true

                        z:
                            1000 +
                            level.depth

                        cut:
                            ({})

                        round:
                            ({
                                topLeft:
                                    internalRoot.radius,

                                topRight:
                                    internalRoot.radius,

                                bottomRight:
                                    internalRoot.radius,

                                bottomLeft:
                                    internalRoot.radius
                            })

                        bgColor:
                            internalRoot.backgroundColor

                        borderWidth:
                            internalRoot.borderWidth

                        borderColor:
                            internalRoot.borderColor

                        interactive:
                            Boolean(
                                internalRoot.menuOpen
                            )

                        // ====================================================
                        // SCROLLER
                        // ====================================================

                        Flickable {
                            id: flick

                            anchors.fill:
                                parent

                            anchors.margins:
                                internalRoot.menuPadding

                            clip:
                                true

                            /*
                             * Vertical scrolling only.
                             *
                             * There is intentionally no scrollbar.
                             */
                            flickableDirection:
                                Flickable.VerticalFlick

                            boundsBehavior:
                                Flickable.StopAtBounds

                            contentWidth:
                                width

                            contentHeight:
                                Math.max(
                                    height,

                                    level.naturalContentHeight
                                )

                            readonly property bool overflowing:
                                Boolean(
                                    flick.contentHeight >
                                    flick.height
                                )

                            interactive:
                                Boolean(
                                    flick.overflowing
                                )

                            Item {
                                id: contentContainer

                                width:
                                    flick.width

                                height:
                                    Math.max(
                                        flick.height,

                                        level.naturalContentHeight
                                    )

                                Loader {
                                    id: loader

                                    anchors.left:
                                        parent.left

                                    anchors.top:
                                        parent.top

                                    width:
                                        parent.width

                                    height:
                                        Math.max(
                                            1,

                                            level.naturalContentHeight
                                        )

                                    asynchronous:
                                        false

                                    onLoaded: {
                                        if (!item)
                                            return

                                        internalRoot.bindTree(
                                            item,

                                            level.depth,

                                            internalRoot.parentAt(
                                                level.depth
                                            )
                                        )

                                        Qt.callLater(
                                            function() {
                                                if (
                                                    !level.activeItem
                                                ) {
                                                    return
                                                }

                                                level.refreshGeometry()

                                                /*
                                                 * Root may have been waiting
                                                 * for Loader completion.
                                                 */
                                                if (
                                                    level.depth === 0 &&
                                                    internalRoot.menuOpen
                                                ) {
                                                    internalRoot.tryResolveOpen()
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        // ====================================================
                        // SUBMENU LEVEL HOVER
                        // ====================================================

                        HoverHandler {
                            id: levelHover

                            onHoveredChanged: {
                                if (
                                    level.depth <= 0
                                ) {
                                    return
                                }

                                if (
                                    Boolean(
                                        levelHover.hovered
                                    )
                                ) {
                                    internalRoot.levelHovered(
                                        level.depth
                                    )
                                } else {
                                    internalRoot.levelExited(
                                        level.depth
                                    )
                                }
                            }
                        }

                        // ====================================================
                        // DELAYED SUBMENU CLOSE
                        // ====================================================

                        Timer {
                            id: closeDelayTimer

                            interval:
                                internalRoot.submenuCloseDelay

                            repeat:
                                false

                            onTriggered: {
                                internalRoot.checkSubmenuLifetime(
                                    level.depth
                                )
                            }
                        }

                        function scheduleClose() {
                            if (
                                level.depth <= 0
                            ) {
                                return
                            }

                            closeDelayTimer.restart()
                        }

                        function cancelScheduledClose() {
                            closeDelayTimer.stop()
                        }

                        // ====================================================
                        // PREPARE
                        // ====================================================

                        function prepareForOpen(
                            component,
                            preserveVisibility
                        ) {
                            if (!component)
                                return

                            level.cancelScheduledClose()

                            level.currentComponent =
                                component

                            const keepRootVisible =
                                Boolean(
                                    preserveVisibility
                                ) &&
                                level.depth === 0 &&
                                Boolean(
                                    level.wasEverVisible
                                )

                            /*
                             * Root:
                             *
                             * preserve visibility when replacing an
                             * already-open root menu.
                             *
                             * Submenu:
                             *
                             * ALWAYS invisible before positioning.
                             */
                            if (
                                !keepRootVisible
                            ) {
                                level.opened =
                                    false

                                level.opacity =
                                    0
                            }

                            if (
                                level.depth > 0
                            ) {
                                level.opened =
                                    false

                                level.opacity =
                                    0

                                level.naturalContentWidth =
                                    1

                                level.naturalContentHeight =
                                    1
                            }

                            /*
                             * Replace content.
                             */
                            level.loader.sourceComponent =
                                null

                            level.loader.sourceComponent =
                                component
                        }

                        // ====================================================
                        // MEASURE
                        // ====================================================

                        function refreshGeometry() {
                            if (!level.activeItem)
                                return

                            /*
                             * The measurement functions deliberately
                             * avoid rendered ContextMenuObj widths.
                             */
                            level.naturalContentWidth =
                                Math.max(
                                    1,

                                    internalRoot.measureWidth(
                                        level.activeItem
                                    )
                                )

                            level.naturalContentHeight =
                                Math.max(
                                    1,

                                    internalRoot.measureHeight(
                                        level.activeItem
                                    )
                                )

                            /*
                             * Final rendered menu width is applied AFTER
                             * natural dimensions have been measured.
                             */
                            internalRoot.assignMenuWidth(
                                level.activeItem,

                                internalRoot.calculateLevelWidth(
                                    level.naturalContentWidth
                                )
                            )
                        }

                        // ====================================================
                        // ROOT POSITION
                        // ====================================================

                        function positionRoot(
                            animate
                        ) {
                            if (
                                !internalRoot.targetScreen ||
                                !internalRoot.targetMonitor
                            ) {
                                return
                            }

                            /*
                             * IMPORTANT:
                             *
                             * Use freshly calculated dimensions here,
                             * NOT level.width/height.
                             *
                             * This makes first-open and reopen use the
                             * exact same flip logic.
                             */
                            const menuWidth =
                                internalRoot.calculateLevelWidth(
                                    level.naturalContentWidth
                                )

                            const menuHeight =
                                internalRoot.calculateLevelHeight(
                                    level.naturalContentHeight
                                )

                            const margin =
                                internalRoot.screenMargin

                            const minX =
                                internalRoot.availableX +
                                margin

                            const minY =
                                internalRoot.availableY +
                                margin

                            const maxX =
                                internalRoot.availableRight -
                                margin -
                                menuWidth

                            const maxY =
                                internalRoot.availableBottom -
                                margin -
                                menuHeight

                            let px =
                                internalRoot.cursorX

                            let py =
                                internalRoot.cursorY

                            /*
                             * Horizontal flip.
                             */
                            if (
                                px >
                                maxX
                            ) {
                                px =
                                    internalRoot.cursorX -
                                    menuWidth
                            }

                            /*
                             * Vertical flip.
                             */
                            if (
                                py >
                                maxY
                            ) {
                                py =
                                    internalRoot.cursorY -
                                    menuHeight
                            }

                            /*
                             * Clamp after flipping.
                             */
                            px =
                                Math.max(
                                    minX,

                                    Math.min(
                                        px,
                                        maxX
                                    )
                                )

                            py =
                                Math.max(
                                    minY,

                                    Math.min(
                                        py,
                                        maxY
                                    )
                                )

                            /*
                             * Root menu:
                             *
                             * first open   → snap
                             * reopen       → slide
                             */
                            level.positionAnimationEnabled =
                                Boolean(
                                    animate
                                )

                            level.x =
                                px

                            level.y =
                                py

                            level.wasEverVisible =
                                true
                        }

                        // ====================================================
                        // SUBMENU POSITION
                        // ====================================================

                        function positionSubmenu(
                            parentObject
                        ) {
                            if (
                                !parentObject ||
                                !internalRoot.targetScreen
                            ) {
                                return
                            }

                            /*
                             * HARD GUARANTEE:
                             *
                             * submenu x/y NEVER animate.
                             */
                            level.positionAnimationEnabled =
                                false

                            const menuWidth =
                                internalRoot.calculateLevelWidth(
                                    level.naturalContentWidth
                                )

                            const menuHeight =
                                internalRoot.calculateLevelHeight(
                                    level.naturalContentHeight
                                )

                            const mapped =
                                parentObject.mapToItem(
                                    internalRoot,
                                    0,
                                    0
                                )

                            const margin =
                                internalRoot.screenMargin

                            const minX =
                                internalRoot.availableX +
                                margin

                            const minY =
                                internalRoot.availableY +
                                margin

                            const maxX =
                                internalRoot.availableRight -
                                margin -
                                menuWidth

                            const maxY =
                                internalRoot.availableBottom -
                                margin -
                                menuHeight

                            const rightX =
                                mapped.x +
                                parentObject.width +
                                internalRoot.submenuGap

                            const leftX =
                                mapped.x -
                                menuWidth -
                                internalRoot.submenuGap

                            let px

                            /*
                             * Prefer right.
                             */
                            if (
                                rightX <=
                                maxX
                            ) {
                                px =
                                    rightX
                            } else {
                                /*
                                 * Flip left.
                                 */
                                px =
                                    leftX
                            }

                            /*
                             * Match parent row vertically.
                             */
                            let py =
                                mapped.y

                            /*
                             * Clamp.
                             */
                            px =
                                Math.max(
                                    minX,

                                    Math.min(
                                        px,
                                        maxX
                                    )
                                )

                            py =
                                Math.max(
                                    minY,

                                    Math.min(
                                        py,
                                        maxY
                                    )
                                )

                            /*
                             * Opacity is zero while these are assigned.
                             *
                             * Therefore no visible 0,0 → target slide.
                             */
                            level.x =
                                px

                            level.y =
                                py
                        }

                        // ====================================================
                        // OPEN/CLOSE
                        // ====================================================

                        function openVisible() {
                            level.opened =
                                true

                            level.opacity =
                                1

                            level.wasEverVisible =
                                true
                        }

                        function closeVisible() {
                            level.opened =
                                false

                            level.opacity =
                                0
                        }

                        // ====================================================
                        // ROOT POSITION ANIMATION ONLY
                        // ====================================================

                        Behavior on x {
                            enabled:
                                Boolean(
                                    level.positionAnimationEnabled
                                )

                            NumberAnimation {
                                duration:
                                    internalRoot.positionAnimationDuration

                                easing.type:
                                    Easing.OutCubic
                            }
                        }

                        Behavior on y {
                            enabled:
                                Boolean(
                                    level.positionAnimationEnabled
                                )

                            NumberAnimation {
                                duration:
                                    internalRoot.positionAnimationDuration

                                easing.type:
                                    Easing.OutCubic
                            }
                        }

                        // ====================================================
                        // SIZE ANIMATION
                        // ====================================================

                        Behavior on width {
                            NumberAnimation {
                                duration:
                                    internalRoot.animationDuration

                                easing.type:
                                    Easing.OutCubic
                            }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration:
                                    internalRoot.animationDuration

                                easing.type:
                                    Easing.OutCubic
                            }
                        }

                        // ====================================================
                        // FADE ANIMATION
                        // ====================================================

                        Behavior on opacity {
                            NumberAnimation {
                                duration:
                                    internalRoot.animationDuration

                                easing.type:
                                    Easing.OutCubic
                            }
                        }
                    }
            }

            // ====================================================
            // MENU WIDTH APPLICATION
            // ====================================================

            function assignMenuWidth(
                item,
                width
            ) {
                if (!item)
                    return

                if (
                    item.isContextMenuObject ===
                    true
                ) {
                    item.menuWidth =
                        Number(width)
                }

                const children =
                    item.children

                if (!children)
                    return

                for (
                    let i = 0;
                    i < children.length;
                    ++i
                ) {
                    const child =
                        children[i]

                    if (!child)
                        continue

                    internalRoot.assignMenuWidth(
                        child,
                        width
                    )
                }
            }

            // ====================================================
            // CONTAINER DETECTION
            // ====================================================

            function containsMenuObject(
                item
            ) {
                if (!item)
                    return false

                if (
                    item.isContextMenuObject ===
                    true
                ) {
                    return true
                }

                const children =
                    item.children

                if (!children)
                    return false

                for (
                    let i = 0;
                    i < children.length;
                    ++i
                ) {
                    const child =
                        children[i]

                    if (
                        internalRoot.containsMenuObject(
                            child
                        )
                    ) {
                        return true
                    }
                }

                return false
            }

            // ====================================================
            // NATURAL WIDTH
            // ====================================================

            function measureWidth(
                item
            ) {
                if (!item)
                    return 1

                /*
                 * ContextMenuObj:
                 *
                 * NEVER inspect rendered width.
                 */
                if (
                    item.isContextMenuObject ===
                    true
                ) {
                    if (
                        item.preferredWidth !==
                        undefined
                    ) {
                        const preferred =
                            Number(
                                item.preferredWidth
                            )

                        if (
                            Number.isFinite(
                                preferred
                            ) &&
                            preferred > 0
                        ) {
                            return preferred
                        }
                    }

                    return 1
                }

                let result =
                    0

                const children =
                    item.children

                /*
                 * For a container containing ContextMenuObjs,
                 * derive its width strictly from natural child widths.
                 *
                 * DO NOT use childrenRect here because those children
                 * may already have menuWidth assigned.
                 */
                if (
                    children &&
                    children.length > 0 &&
                    internalRoot.containsMenuObject(
                        item
                    )
                ) {
                    /*
                     * Explicit container width is legitimate.
                     */
                    if (
                        item.width !==
                        undefined
                    ) {
                        const explicitWidth =
                            Number(
                                item.width
                            )

                        if (
                            Number.isFinite(
                                explicitWidth
                            ) &&
                            explicitWidth > 0
                        ) {
                            result =
                                explicitWidth
                        }
                    }

                    for (
                        let i = 0;
                        i < children.length;
                        ++i
                    ) {
                        const child =
                            children[i]

                        if (!child)
                            continue

                        const naturalChildWidth =
                            internalRoot.measureWidth(
                                child
                            )

                        if (
                            Number.isFinite(
                                naturalChildWidth
                            )
                        ) {
                            result =
                                Math.max(
                                    result,
                                    naturalChildWidth
                                )
                        }
                    }

                    return Math.max(
                        1,
                        result
                    )
                }

                /*
                 * Arbitrary non-menu QML.
                 */
                if (
                    item.width !==
                    undefined
                ) {
                    const explicitWidth =
                        Number(
                            item.width
                        )

                    if (
                        Number.isFinite(
                            explicitWidth
                        ) &&
                        explicitWidth > 0
                    ) {
                        result =
                            explicitWidth
                    }
                }

                if (
                    item.childrenRect
                ) {
                    const rectWidth =
                        Number(
                            item.childrenRect.width
                        )

                    if (
                        Number.isFinite(
                            rectWidth
                        ) &&
                        rectWidth > 0
                    ) {
                        result =
                            Math.max(
                                result,
                                rectWidth
                            )
                    }
                }

                return Math.max(
                    1,
                    result
                )
            }

            // ====================================================
            // NATURAL HEIGHT
            // ====================================================

            function measureHeight(
                item
            ) {
                if (!item)
                    return 1

                /*
                 * ContextMenuObj:
                 *
                 * fixed natural height independent of assigned
                 * menu width.
                 */
                if (
                    item.isContextMenuObject ===
                    true
                ) {
                    if (
                        item.preferredHeight !==
                        undefined
                    ) {
                        const preferred =
                            Number(
                                item.preferredHeight
                            )

                        if (
                            Number.isFinite(
                                preferred
                            ) &&
                            preferred > 0
                        ) {
                            return preferred
                        }
                    }

                    return 1
                }

                let result =
                    0

                /*
                 * For menu containers, height is naturally determined
                 * by the child rows.
                 */
                const children =
                    item.children

                if (
                    children &&
                    children.length > 0 &&
                    internalRoot.containsMenuObject(
                        item
                    )
                ) {
                    /*
                     * Explicit container height.
                     */
                    if (
                        item.height !==
                        undefined
                    ) {
                        const explicitHeight =
                            Number(
                                item.height
                            )

                        if (
                            Number.isFinite(
                                explicitHeight
                            ) &&
                            explicitHeight > 0
                        ) {
                            result =
                                explicitHeight
                        }
                    }

                    /*
                     * childrenRect height is safe here because
                     * ContextMenuObj rows have fixed height and their
                     * menu width does not alter their row height.
                     */
                    if (
                        item.childrenRect
                    ) {
                        const rectHeight =
                            Number(
                                item.childrenRect.height
                            )

                        if (
                            Number.isFinite(
                                rectHeight
                            ) &&
                            rectHeight > 0
                        ) {
                            result =
                                Math.max(
                                    result,
                                    rectHeight
                                )
                        }
                    }

                    return Math.max(
                        1,
                        result
                    )
                }

                /*
                 * Arbitrary non-menu QML.
                 */
                if (
                    item.height !==
                    undefined
                ) {
                    const explicitHeight =
                        Number(
                            item.height
                        )

                    if (
                        Number.isFinite(
                            explicitHeight
                        ) &&
                        explicitHeight > 0
                    ) {
                        result =
                            explicitHeight
                    }
                }

                if (
                    item.childrenRect
                ) {
                    const rectHeight =
                        Number(
                            item.childrenRect.height
                        )

                    if (
                        Number.isFinite(
                            rectHeight
                        ) &&
                        rectHeight > 0
                    ) {
                        result =
                            Math.max(
                                result,
                                rectHeight
                            )
                    }
                }

                return Math.max(
                    1,
                    result
                )
            }

            // ====================================================
            // TREE BINDING
            // ====================================================

            function bindTree(
                item,
                depth,
                parentObject
            ) {
                if (!item)
                    return

                let nearestParent =
                    parentObject || null

                /*
                 * ContextMenuObj advertises contextMenuInstance.
                 */
                if (
                    item.contextMenuInstance !==
                    undefined
                ) {
                    item.contextMenuInstance =
                        internalRoot

                    item.contextMenuDepth =
                        Number(depth)

                    item.parentMenuObject =
                        parentObject || null

                    nearestParent =
                        item
                }

                const children =
                    item.children

                if (!children)
                    return

                for (
                    let i = 0;
                    i < children.length;
                    ++i
                ) {
                    const child =
                        children[i]

                    if (!child)
                        continue

                    internalRoot.bindTree(
                        child,
                        depth,
                        nearestParent
                    )
                }
            }

            // ====================================================
            // SUBMENU VISIBILITY
            // ====================================================

            function isSubmenuVisibleFor(
                object
            ) {
                if (!object)
                    return false

                const depth =
                    Number(
                        object.contextMenuDepth
                    ) + 1

                if (
                    !Number.isFinite(depth) ||
                    depth < 1 ||
                    depth >=
                        internalRoot.maxDepth
                ) {
                    return false
                }

                const level =
                    internalRoot.levelAt(
                        depth
                    )

                return Boolean(
                    level &&
                    level.opened &&
                    internalRoot.parentAt(
                        depth
                    ) === object
                )
            }

            // ====================================================
            // OBJECT HOVER
            // ====================================================

            function objectHovered(
                object,
                depth
            ) {
                if (
                    !internalRoot.menuOpen ||
                    !object
                ) {
                    return
                }

                const parentDepth =
                    Number(depth)

                if (
                    !Number.isFinite(
                        parentDepth
                    )
                ) {
                    return
                }

                const submenuDepth =
                    parentDepth + 1

                if (
                    submenuDepth >=
                    internalRoot.maxDepth
                ) {
                    return
                }

                const level =
                    internalRoot.levelAt(
                        submenuDepth
                    )

                if (level)
                    level.cancelScheduledClose()

                /*
                 * Record the currently active parent.
                 */
                let parents =
                    internalRoot.submenuParents.slice()

                parents[submenuDepth] =
                    object.hasSubmenu
                        ? object
                        : null

                internalRoot.submenuParents =
                    parents

                /*
                 * Record parent hover.
                 */
                let parentHover =
                    internalRoot.parentHovered.slice()

                parentHover[submenuDepth] =
                    Boolean(
                        object.hasSubmenu
                    )

                internalRoot.parentHovered =
                    parentHover

                /*
                 * Normal item:
                 *
                 * close any temporary submenu at this depth.
                 */
                if (
                    !object.hasSubmenu
                ) {
                    if (
                        !internalRoot.boolAt(
                            internalRoot.submenuPinned,
                            submenuDepth
                        )
                    ) {
                        internalRoot.closeFromDepth(
                            submenuDepth
                        )
                    }

                    return
                }

                /*
                 * Hover-show submenu.
                 */
                internalRoot.openSubmenu(
                    object,
                    false
                )
            }

            // ====================================================
            // OBJECT EXIT
            // ====================================================

            function objectExited(
                object,
                depth
            ) {
                if (
                    !internalRoot.menuOpen ||
                    !object
                ) {
                    return
                }

                const parentDepth =
                    Number(depth)

                if (
                    !Number.isFinite(
                        parentDepth
                    )
                ) {
                    return
                }

                const submenuDepth =
                    parentDepth + 1

                /*
                 * Ignore stale exits from an old sibling.
                 */
                if (
                    internalRoot.parentAt(
                        submenuDepth
                    ) !== object
                ) {
                    return
                }

                let parentHover =
                    internalRoot.parentHovered.slice()

                parentHover[submenuDepth] =
                    false

                internalRoot.parentHovered =
                    parentHover

                /*
                 * Pinned submenu does not care about hover exit.
                 */
                if (
                    internalRoot.boolAt(
                        internalRoot.submenuPinned,
                        submenuDepth
                    )
                ) {
                    return
                }

                const level =
                    internalRoot.levelAt(
                        submenuDepth
                    )

                if (level)
                    level.scheduleClose()
            }

            // ====================================================
            // OBJECT CLICK
            // ====================================================

            function objectClicked(
                object
            ) {
                if (
                    !object ||
                    !object.enabled
                ) {
                    return
                }

                /*
                 * Clicking a submenu parent pins/unpins it.
                 */
                if (
                    object.hasSubmenu
                ) {
                    const depth =
                        Number(
                            object.contextMenuDepth
                        ) + 1

                    if (
                        !Number.isFinite(depth) ||
                        depth < 1 ||
                        depth >=
                            internalRoot.maxDepth
                    ) {
                        return
                    }

                    const pinned =
                        internalRoot.boolAt(
                            internalRoot.submenuPinned,
                            depth
                        )

                    if (pinned) {
                        let state =
                            internalRoot.submenuPinned.slice()

                        state[depth] =
                            false

                        internalRoot.submenuPinned =
                            state

                        internalRoot.closeFromDepth(
                            depth
                        )
                    } else {
                        internalRoot.openSubmenu(
                            object,
                            true
                        )
                    }

                    return
                }

                /*
                 * Normal action.
                 */
                object.activate()

                if (
                    object.closeOnClick
                ) {
                    internalRoot.close()
                }
            }

            // ====================================================
            // SUBMENU OPEN
            // ====================================================

            function openSubmenu(
                parentObject,
                pinned
            ) {
                if (
                    !internalRoot.menuOpen ||
                    !parentObject ||
                    !parentObject.submenu
                ) {
                    return
                }

                const depth =
                    Number(
                        parentObject.contextMenuDepth
                    ) + 1

                if (
                    !Number.isFinite(depth) ||
                    depth < 1 ||
                    depth >=
                        internalRoot.maxDepth
                ) {
                    return
                }

                const level =
                    internalRoot.levelAt(
                        depth
                    )

                if (!level)
                    return

                /*
                 * Generate a new branch generation.
                 */
                let generations =
                    internalRoot.submenuGeneration.slice()

                const generation =
                    Number(
                        generations[depth] || 0
                    ) + 1

                generations[depth] =
                    generation

                internalRoot.submenuGeneration =
                    generations

                /*
                 * Replace a different sibling submenu.
                 */
                const previousParent =
                    internalRoot.parentAt(
                        depth
                    )

                if (
                    previousParent &&
                    previousParent !==
                        parentObject
                ) {
                    internalRoot.closeFromDepth(
                        depth
                    )
                }

                /*
                 * Parent state.
                 */
                let parents =
                    internalRoot.submenuParents.slice()

                parents[depth] =
                    parentObject

                internalRoot.submenuParents =
                    parents

                /*
                 * Pin state.
                 */
                let pins =
                    internalRoot.submenuPinned.slice()

                pins[depth] =
                    Boolean(
                        pinned === true
                    )

                internalRoot.submenuPinned =
                    pins

                /*
                 * Hover state.
                 */
                let parentHover =
                    internalRoot.parentHovered.slice()

                parentHover[depth] =
                    true

                internalRoot.parentHovered =
                    parentHover

                level.cancelScheduledClose()

                /*
                 * Submenus always start invisible.
                 */
                level.prepareForOpen(
                    parentObject.submenu,
                    false
                )

                Qt.callLater(
                    function() {
                        if (
                            !internalRoot.menuOpen
                        ) {
                            return
                        }

                        /*
                         * Stale callback?
                         */
                        if (
                            Number(
                                internalRoot.submenuGeneration[
                                    depth
                                ] || 0
                            ) !==
                            generation
                        ) {
                            return
                        }

                        /*
                         * Different parent?
                         */
                        if (
                            internalRoot.parentAt(
                                depth
                            ) !==
                            parentObject
                        ) {
                            return
                        }

                        /*
                         * Hover submenu must still have its parent
                         * hovered.
                         *
                         * Pinned submenu ignores this.
                         */
                        if (
                            pinned !== true &&
                            !internalRoot.boolAt(
                                internalRoot.parentHovered,
                                depth
                            )
                        ) {
                            return
                        }

                        if (
                            !level.activeItem
                        ) {
                            return
                        }

                        level.refreshGeometry()

                        /*
                         * Position while opacity == 0.
                         *
                         * No x/y animation.
                         */
                        level.positionSubmenu(
                            parentObject
                        )

                        /*
                         * Fade in.
                         */
                        level.openVisible()

                        /*
                         * Kill everything below this branch.
                         */
                        internalRoot.clearDeeperState(
                            depth
                        )
                    }
                )
            }

            // ====================================================
            // SUBMENU LEVEL ENTER
            // ====================================================

            function levelHovered(
                depth
            ) {
                if (
                    depth <= 0
                ) {
                    return
                }

                const level =
                    internalRoot.levelAt(
                        depth
                    )

                if (level)
                    level.cancelScheduledClose()

                let state =
                    internalRoot.submenuHovered.slice()

                state[depth] =
                    true

                internalRoot.submenuHovered =
                    state
            }

            // ====================================================
            // SUBMENU LEVEL EXIT
            // ====================================================

            function levelExited(
                depth
            ) {
                if (
                    depth <= 0
                ) {
                    return
                }

                let state =
                    internalRoot.submenuHovered.slice()

                state[depth] =
                    false

                internalRoot.submenuHovered =
                    state

                const level =
                    internalRoot.levelAt(
                        depth
                    )

                if (level)
                    level.scheduleClose()
            }

            // ====================================================
            // OPEN DESCENDANT
            // ====================================================

            function hasOpenDescendant(
                depth
            ) {
                for (
                    let i = depth + 1;
                    i < internalRoot.maxDepth;
                    ++i
                ) {
                    const level =
                        internalRoot.levelAt(i)

                    if (
                        level &&
                        Boolean(level.opened) &&
                        internalRoot.parentAt(i)
                    ) {
                        return true
                    }
                }

                return false
            }

            // ====================================================
            // BRANCH ACTIVE
            // ====================================================

            function isBranchActive(
                depth
            ) {
                /*
                 * Pinned.
                 */
                if (
                    internalRoot.boolAt(
                        internalRoot.submenuPinned,
                        depth
                    )
                ) {
                    return true
                }

                /*
                 * Parent item hovered.
                 */
                if (
                    internalRoot.boolAt(
                        internalRoot.parentHovered,
                        depth
                    )
                ) {
                    return true
                }

                /*
                 * Pointer inside this submenu.
                 */
                if (
                    internalRoot.boolAt(
                        internalRoot.submenuHovered,
                        depth
                    )
                ) {
                    return true
                }

                /*
                 * Pointer has entered a deeper submenu.
                 */
                if (
                    internalRoot.hasOpenDescendant(
                        depth
                    )
                ) {
                    return true
                }

                return false
            }

            // ====================================================
            // SUBMENU LIFETIME
            // ====================================================

            function checkSubmenuLifetime(
                depth
            ) {
                if (
                    depth < 1 ||
                    !internalRoot.menuOpen
                ) {
                    return
                }

                if (
                    internalRoot.isBranchActive(
                        depth
                    )
                ) {
                    return
                }

                internalRoot.closeFromDepth(
                    depth
                )
            }

            // ====================================================
            // CLEAR DEEPER STATE
            // ============================================================

            function clearDeeperState(
                depth
            ) {
                let pins =
                    internalRoot.submenuPinned.slice()

                let parentHover =
                    internalRoot.parentHovered.slice()

                let submenuHover =
                    internalRoot.submenuHovered.slice()

                let parents =
                    internalRoot.submenuParents.slice()

                let generations =
                    internalRoot.submenuGeneration.slice()

                for (
                    let i = depth + 1;
                    i < internalRoot.maxDepth;
                    ++i
                ) {
                    pins[i] =
                        false

                    parentHover[i] =
                        false

                    submenuHover[i] =
                        false

                    parents[i] =
                        null

                    generations[i] =
                        Number(
                            generations[i] || 0
                        ) + 1

                    const level =
                        internalRoot.levelAt(i)

                    if (level)
                        level.closeVisible()
                }

                internalRoot.submenuPinned =
                    pins

                internalRoot.parentHovered =
                    parentHover

                internalRoot.submenuHovered =
                    submenuHover

                internalRoot.submenuParents =
                    parents

                internalRoot.submenuGeneration =
                    generations
            }

            // ====================================================
            // CLOSE FROM DEPTH
            // ====================================================

            function closeFromDepth(
                depth
            ) {
                if (
                    depth < 1
                ) {
                    return
                }

                let pins =
                    internalRoot.submenuPinned.slice()

                let parentHover =
                    internalRoot.parentHovered.slice()

                let submenuHover =
                    internalRoot.submenuHovered.slice()

                let parents =
                    internalRoot.submenuParents.slice()

                let generations =
                    internalRoot.submenuGeneration.slice()

                for (
                    let i = depth;
                    i < internalRoot.maxDepth;
                    ++i
                ) {
                    const level =
                        internalRoot.levelAt(i)

                    if (level)
                        level.closeVisible()

                    pins[i] =
                        false

                    parentHover[i] =
                        false

                    submenuHover[i] =
                        false

                    parents[i] =
                        null

                    generations[i] =
                        Number(
                            generations[i] || 0
                        ) + 1
                }

                internalRoot.submenuPinned =
                    pins

                internalRoot.parentHovered =
                    parentHover

                internalRoot.submenuHovered =
                    submenuHover

                internalRoot.submenuParents =
                    parents

                internalRoot.submenuGeneration =
                    generations
            }

            // ====================================================
            // CLOSE EVERYTHING
            // ====================================================

            function close() {
                if (
                    !internalRoot.menuOpen
                ) {
                    return
                }

                internalRoot.menuOpen =
                    false

                internalRoot.resetSubmenuState()

                for (
                    let i = 0;
                    i < internalRoot.maxDepth;
                    ++i
                ) {
                    const level =
                        internalRoot.levelAt(i)

                    if (level)
                        level.closeVisible()
                }

                closeTimer.restart()
            }

            // ====================================================
            // RIGHT-CLICK RECALL
            // ============================================================

            /*
             * Since the menu is a fullscreen Overlay, the underlying
             * WidgetLayer cannot receive a second right click once the
             * menu is open.
             *
             * This catcher turns that right click into another public
             * open() request using the current component.
             */
            MouseArea {
                id: recallArea

                anchors.fill:
                    parent

                enabled:
                    Boolean(
                        internalRoot.menuOpen
                    )

                acceptedButtons:
                    Qt.RightButton

                /*
                 * Menu entries live at z >= 1000.
                 *
                 * Right click is not accepted by ContextMenuObj, so
                 * this area can sit above them safely.
                 */
                z:
                    2000

                onPressed: function(mouse) {
                    internalRoot.open(
                        internalRoot.requestedComponent
                    )

                    mouse.accepted =
                        true
                }
            }

            // ====================================================
            // OUTSIDE CLOSE
            // ============================================================

            MouseArea {
                id: outsideClick

                anchors.fill:
                    parent

                enabled:
                    Boolean(
                        internalRoot.menuOpen
                    )

                acceptedButtons:
                    Qt.LeftButton |
                    Qt.MiddleButton

                z:
                    0

                onPressed: function(mouse) {
                    internalRoot.close()

                    mouse.accepted =
                        true
                }
            }

            // ====================================================
            // CLOSE CLEANUP
            // ============================================================

            Timer {
                id: closeTimer

                interval:
                    internalRoot.animationDuration +
                    30

                repeat:
                    false

                onTriggered: {
                    if (
                        internalRoot.menuOpen
                    ) {
                        return
                    }

                    for (
                        let i = 0;
                        i < internalRoot.maxDepth;
                        ++i
                    ) {
                        const level =
                            internalRoot.levelAt(i)

                        if (!level)
                            continue

                        level.loader.sourceComponent =
                            null

                        level.currentComponent =
                            null

                        level.opened =
                            false

                        level.opacity =
                            0

                        level.wasEverVisible =
                            false

                        level.positionAnimationEnabled =
                            false

                        level.naturalContentWidth =
                            1

                        level.naturalContentHeight =
                            1

                        level.cancelScheduledClose()
                    }

                    internalRoot.requestedComponent =
                        null

                    internalRoot.targetMonitor =
                        null

                    internalRoot.targetScreen =
                        null

                    internalRoot.monitorResult =
                        null

                    internalRoot.cursorResultReady =
                        false

                    internalRoot.monitorResultReady =
                        false

                    internalRoot.resetSubmenuState()
                }
            }
        }
    }
}