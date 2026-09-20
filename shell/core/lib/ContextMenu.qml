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

    function open(
        component,
        layer
    ) {
        internalRoot.open(
            component,
            layer
        )
    }

    function close() {
        internalRoot.close()
    }

    function notifyHovered(
        object
    ) {
        if (!object)
            return

        internalRoot.objectHovered(
            object,
            object.contextMenuDepth
        )
    }

    function notifyExited(
        object
    ) {
        if (!object)
            return

        internalRoot.objectExited(
            object,
            object.contextMenuDepth
        )
    }

    function notifyClicked(
        object
    ) {
        if (!object)
            return

        internalRoot.objectClicked(
            object
        )
    }

    function isSubmenuVisibleFor(
        object
    ) {
        return internalRoot.isSubmenuVisibleFor(
            object
        )
    }

    // ============================================================
    // FIXED LAYER HOSTS
    // ============================================================

    PanelWindow {
        id: overlayWindow

        screen:
            internalRoot.targetScreen

        visible:
            internalRoot.menuOpen &&
            internalRoot.targetScreen !== null &&
            internalRoot.requestedLayer ===
                WlrLayer.Overlay

        color:
            internalRoot.windowColor

        exclusionMode:
            ExclusionMode.Ignore

        WlrLayershell.layer:
            WlrLayer.Overlay

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            id: overlayHost

            anchors.fill:
                parent
        }
    }

    PanelWindow {
        id: topWindow

        screen:
            internalRoot.targetScreen

        visible:
            internalRoot.menuOpen &&
            internalRoot.targetScreen !== null &&
            internalRoot.requestedLayer ===
                WlrLayer.Top

        color:
            internalRoot.windowColor

        exclusionMode:
            ExclusionMode.Ignore

        WlrLayershell.layer:
            WlrLayer.Top

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            id: topHost

            anchors.fill:
                parent
        }
    }

    PanelWindow {
        id: bottomWindow

        screen:
            internalRoot.targetScreen

        visible:
            internalRoot.menuOpen &&
            internalRoot.targetScreen !== null &&
            internalRoot.requestedLayer ===
                WlrLayer.Bottom

        color:
            internalRoot.windowColor

        exclusionMode:
            ExclusionMode.Ignore

        WlrLayershell.layer:
            WlrLayer.Bottom

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            id: bottomHost

            anchors.fill:
                parent
        }
    }

    PanelWindow {
        id: backgroundWindow

        screen:
            internalRoot.targetScreen

        visible:
            internalRoot.menuOpen &&
            internalRoot.targetScreen !== null &&
            internalRoot.requestedLayer ===
                WlrLayer.Background

        color:
            internalRoot.windowColor

        exclusionMode:
            ExclusionMode.Ignore

        WlrLayershell.layer:
            WlrLayer.Background

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            id: backgroundHost

            anchors.fill:
                parent
        }
    }

    // ============================================================
    // INTERNAL ROOT
    // ============================================================

    Item {
        id: internalRoot

        parent:
            overlayHost

        anchors.fill:
            parent

        // ========================================================
        // OPEN STATE
        // ========================================================

        property bool menuOpen:
            false

        property Component requestedComponent:
            null

        property var requestedLayer:
            WlrLayer.Overlay

        property int requestGeneration:
            0

        // ========================================================
        // CURSOR / MONITOR
        // ========================================================

        property point cursorGlobal:
            Qt.point(0, 0)

        property var targetMonitor:
            null

        property var targetScreen:
            null

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

        // ========================================================
        // HYPRLAND QUERY STATE
        // ========================================================

        property bool cursorResultReady:
            false

        property bool monitorResultReady:
            false

        property int cursorResultGeneration:
            0

        property int monitorResultGeneration:
            0

        property var monitorResult:
            null

        // ========================================================
        // RESERVED SPACE
        // ========================================================

        property real reservedTop:
            0

        property real reservedBottom:
            0

        property real reservedLeft:
            0

        property real reservedRight:
            0

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

        // ========================================================
        // SIZE
        // ========================================================

        property real screenMargin:
            10

        property real maximumScreenFraction:
            0.80

        property real minimumWidth:
            180

        property int menuPadding:
            4

        // --------------------------------------------------------
        // SCROLLBAR SPACE
        // --------------------------------------------------------

        property real scrollbarWidth:
            5

        property real scrollbarGap:
            7

        property real scrollbarMargin:
            4

        property real scrollbarMinHandleHeight:
            24

        readonly property real scrollbarReservation:
            scrollbarWidth +
            scrollbarGap

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

        // ========================================================
        // THEME COLORS
        // ========================================================
        //
        // Inject your N0ctOS theme here later.
        //
        // No menu visual should need hard-coded color values
        // elsewhere in this file.
        // ========================================================

        property color windowColor:
            "transparent"

        property color menuBackgroundColor:
            "#090d12"

        property color menuBorderColor:
            "#263541"

        property color scrollbarTrackColor:
            "#26354155"

        property color scrollbarHandleColor:
            "#2acfffcc"

        property color overflowFadeColor:
            menuBackgroundColor

        /*
         * Separate control for fade strength.
         *
         * 0.0 = invisible
         * 1.0 = fully opaque
         */
        property real overflowFadeIntensity:
            0.90

        /*
         * Separate control for fade size.
         */
        property real overflowFadeHeight:
            30

        readonly property color overflowFadeOpaqueColor:
            Qt.rgba(
                overflowFadeColor.r,
                overflowFadeColor.g,
                overflowFadeColor.b,

                Math.max(
                    0,

                    Math.min(
                        1,
                        overflowFadeIntensity
                    )
                )
            )

        readonly property color overflowFadeTransparentColor:
            Qt.rgba(
                overflowFadeColor.r,
                overflowFadeColor.g,
                overflowFadeColor.b,
                0
            )

        property int borderWidth:
            1

        property real radius:
            8

        // ========================================================
        // ANIMATION
        // ========================================================

        property int animationDuration:
            180

        property int positionAnimationDuration:
            180

        property int submenuCloseDelay:
            110

        // ========================================================
        // SUBMENUS
        // ========================================================

        property int maxDepth:
            16

        property int submenuGap:
            3

        property var submenuPinned:
            []

        property var parentHovered:
            []

        property var submenuHovered:
            []

        property var submenuParents:
            []

        property var submenuGeneration:
            []

        // ========================================================
        // HELPERS
        // ========================================================

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

        // ========================================================
        // LAYER
        // ========================================================

        function normalizeLayer(
            layer
        ) {
            if (
                layer === WlrLayer.Background ||
                layer === WlrLayer.Bottom ||
                layer === WlrLayer.Top ||
                layer === WlrLayer.Overlay
            ) {
                return layer
            }

            return WlrLayer.Overlay
        }

        function hostForLayer(
            layer
        ) {
            if (
                layer === WlrLayer.Background
            ) {
                return backgroundHost
            }

            if (
                layer === WlrLayer.Bottom
            ) {
                return bottomHost
            }

            if (
                layer === WlrLayer.Top
            ) {
                return topHost
            }

            return overlayHost
        }

        function attachToLayer(
            layer
        ) {
            const normalized =
                internalRoot.normalizeLayer(
                    layer
                )

            internalRoot.requestedLayer =
                normalized

            internalRoot.parent =
                internalRoot.hostForLayer(
                    normalized
                )
        }

        // ========================================================
        // OPEN
        // ========================================================

        function open(
            component,
            layer
        ) {
            if (!component) {
                console.warn(
                    "[ContextMenu] open(): no component"
                )

                return
            }

            internalRoot.requestGeneration +=
                1

            internalRoot.requestedComponent =
                component

            internalRoot.attachToLayer(
                layer === undefined ||
                layer === null
                    ? WlrLayer.Overlay
                    : layer
            )

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

            const rootLevel =
                internalRoot.levelAt(0)

            if (rootLevel) {
                rootLevel.prepareForOpen(
                    component,
                    internalRoot.menuOpen
                )
            }

            internalRoot.resetSubmenuState()

            if (
                !internalRoot.menuOpen
            ) {
                internalRoot.menuOpen =
                    true
            }

            cursorProcess.exec([
                "hyprctl",
                "-j",
                "cursorpos"
            ])

            monitorProcess.exec([
                "hyprctl",
                "-j",
                "monitors"
            ])
        }

        // ========================================================
        // RESET
        // ========================================================

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

        // ========================================================
        // CURSOR PROCESS
        // ========================================================

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

        // ========================================================
        // MONITOR PROCESS
        // ========================================================

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

            internalRoot.monitorResult =
                parsed

            internalRoot.monitorResultReady =
                true

            internalRoot.tryResolveOpen()
        }

        // ========================================================
        // RESOLVE
        // ========================================================

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

            if (!level.activeItem)
                return

            level.refreshGeometry()

            const animate =
                Boolean(
                    level.wasEverVisible
                )

            level.positionRoot(
                animate
            )

            level.openVisible()
        }

        // ========================================================
        // MONITOR LOOKUP
        // ========================================================

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

        // ========================================================
        // SCREEN MATCH
        // ========================================================

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

        // ========================================================
        // RESERVED SPACE
        // ========================================================

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

        // ========================================================
        // SIZE HELPERS
        // ========================================================

        function contentVerticallyOverflows(
            naturalHeight
        ) {
            if (
                !internalRoot.targetScreen
            ) {
                return false
            }

            const desiredHeight =
                Math.max(
                    1,

                    Number(naturalHeight) +
                    internalRoot.menuPadding * 2
                )

            return Boolean(
                desiredHeight >
                internalRoot.maximumHeight +
                0.5
            )
        }

        function scrollbarSpaceForHeight(
            naturalHeight
        ) {
            return internalRoot.contentVerticallyOverflows(
                naturalHeight
            )
                ? internalRoot.scrollbarReservation
                : 0
        }

        function calculateLevelWidth(
            naturalWidth,
            naturalHeight
        ) {
            const scrollbarSpace =
                internalRoot.scrollbarSpaceForHeight(
                    naturalHeight === undefined
                        ? 1
                        : naturalHeight
                )

            const desired =
                Math.max(
                    1,

                    Number(naturalWidth) +
                    internalRoot.menuPadding * 2 +
                    scrollbarSpace
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

        function contentWidthForMenu(
            menuWidth,
            naturalHeight
        ) {
            const scrollbarSpace =
                internalRoot.scrollbarSpaceForHeight(
                    naturalHeight
                )

            return Math.max(
                1,

                Number(menuWidth) -
                internalRoot.menuPadding * 2 -
                scrollbarSpace
            )
        }

        // ========================================================
        // LEVELS
        // ========================================================

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

                    property bool positionAnimationEnabled:
                        false

                    property Component currentComponent:
                        null

                    property alias loader:
                        loader

                    readonly property Item activeItem:
                        loader.item

                    property real naturalContentWidth:
                        1

                    property real naturalContentHeight:
                        1

                    readonly property real scrollbarReservation:
                        internalRoot.scrollbarSpaceForHeight(
                            level.naturalContentHeight
                        )

                    width:
                        internalRoot.calculateLevelWidth(
                            level.naturalContentWidth,
                            level.naturalContentHeight
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
                        internalRoot.menuBackgroundColor

                    borderWidth:
                        internalRoot.borderWidth

                    borderColor:
                        internalRoot.menuBorderColor

                    interactive:
                        Boolean(
                            internalRoot.menuOpen
                        )

                    // =================================================
                    // FLICKABLE
                    // =================================================

                    Flickable {
                        id: flick

                        anchors.fill:
                            parent

                        anchors.leftMargin:
                            internalRoot.menuPadding

                        anchors.topMargin:
                            internalRoot.menuPadding

                        anchors.bottomMargin:
                            internalRoot.menuPadding

                        /*
                         * IMPORTANT:
                         *
                         * When overflow exists, this consumes:
                         *
                         *     scrollbar gap
                         *     scrollbar width
                         *
                         * The scrollbar therefore does not overlap
                         * the menu objects.
                         */
                        anchors.rightMargin:
                            internalRoot.menuPadding +
                            level.scrollbarReservation

                        clip:
                            true

                        flickableDirection:
                            Flickable.VerticalFlick

                        boundsBehavior:
                            Flickable.StopAtBounds

                        /*
                         * We drive contentY ourselves from the
                         * wheel catcher below.
                         *
                         * Keeping this false avoids another input
                         * handler competing for the same wheel event.
                         */
                        interactive:
                            false

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
                                flick.height +
                                0.5
                            )

                        readonly property real scrollRange:
                            Math.max(
                                0,

                                flick.contentHeight -
                                flick.height
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

                    // =================================================
                    // WHEEL CAPTURE
                    // =================================================
                    //
                    // This MouseArea intentionally accepts NO mouse
                    // buttons, but handles wheel events.
                    //
                    // It sits above ContextMenuObj MouseAreas, so
                    // their click handling cannot consume the wheel.
                    // =================================================

                    MouseArea {
                        id: wheelCapture

                        anchors.fill:
                            flick

                        enabled:
                            flick.overflowing

                        acceptedButtons:
                            Qt.NoButton

                        hoverEnabled:
                            false

                        z:
                            1300

                        onWheel: function(wheel) {
                            if (
                                !flick.overflowing
                            ) {
                                wheel.accepted =
                                    false

                                return
                            }

                            let delta =
                                Number(
                                    wheel.pixelDelta.y
                                )

                            /*
                             * Mouse wheels generally expose
                             * angleDelta in multiples of 120.
                             *
                             * Touchpads may expose pixelDelta.
                             */
                            if (
                                !Number.isFinite(delta) ||
                                Math.abs(delta) < 0.01
                            ) {
                                delta =
                                    (
                                        Number(
                                            wheel.angleDelta.y
                                        ) /
                                        120
                                    ) *
                                    48
                            }

                            if (
                                !Number.isFinite(
                                    delta
                                )
                            ) {
                                wheel.accepted =
                                    false

                                return
                            }

                            if (
                                wheel.inverted
                            ) {
                                delta =
                                    -delta
                            }

                            flick.contentY =
                                Math.max(
                                    0,

                                    Math.min(
                                        flick.scrollRange,

                                        flick.contentY -
                                        delta
                                    )
                                )

                            /*
                             * IMPORTANT:
                             *
                             * Explicitly consume the wheel event so
                             * it does not continue down to the
                             * ContextMenuObj MouseAreas.
                             */
                            wheel.accepted =
                                true
                        }
                    }

                    // =================================================
                    // TOP FADE
                    // =================================================

                    Rectangle {
                        id: topOverflowFade

                        visible:
                            flick.overflowing &&
                            flick.contentY >
                                0.5

                        x:
                            flick.x

                        y:
                            flick.y

                        width:
                            flick.width

                        height:
                            Math.min(
                                internalRoot.overflowFadeHeight,

                                flick.height
                            )

                        z:
                            1400

                        color:
                            internalRoot.overflowFadeColor

                        opacity:
                            internalRoot.overflowFadeIntensity

                        gradient:
                            Gradient {
                                GradientStop {
                                    position:
                                        0

                                    color:
                                        internalRoot.overflowFadeOpaqueColor
                                }

                                GradientStop {
                                    position:
                                        1

                                    color:
                                        internalRoot.overflowFadeTransparentColor
                                }
                            }

                        /*
                         * Never interfere with wheel/click input.
                         */
                        enabled:
                            false
                    }

                    // =================================================
                    // BOTTOM FADE
                    // =================================================

                    Rectangle {
                        id: bottomOverflowFade

                        visible:
                            flick.overflowing &&
                            (
                                flick.contentY <
                                flick.scrollRange -
                                0.5
                            )

                        x:
                            flick.x

                        y:
                            flick.y +
                            flick.height -
                            Math.min(
                                internalRoot.overflowFadeHeight,

                                flick.height
                            )

                        width:
                            flick.width

                        height:
                            Math.min(
                                internalRoot.overflowFadeHeight,

                                flick.height
                            )

                        z:
                            1400

                        color:
                            internalRoot.overflowFadeColor

                        opacity:
                            internalRoot.overflowFadeIntensity

                        gradient:
                            Gradient {
                                GradientStop {
                                    position:
                                        0

                                    color:
                                        internalRoot.overflowFadeTransparentColor
                                }

                                GradientStop {
                                    position:
                                        1

                                    color:
                                        internalRoot.overflowFadeOpaqueColor
                                }
                            }

                        enabled:
                            false
                    }

                    // =================================================
                    // SCROLLBAR
                    // =================================================

                    Rectangle {
                        id: scrollbarTrack

                        visible:
                            flick.overflowing

                        x:
                            level.width -
                            internalRoot.menuPadding -
                            width

                        y:
                            internalRoot.menuPadding +
                            internalRoot.scrollbarMargin

                        width:
                            internalRoot.scrollbarWidth

                        height:
                            Math.max(
                                1,

                                level.height -
                                internalRoot.menuPadding * 2 -
                                internalRoot.scrollbarMargin * 2
                            )

                        radius:
                            width * 0.5

                        color:
                            internalRoot.scrollbarTrackColor

                        z:
                            1500

                        readonly property real handleHeight:
                            Math.max(
                                internalRoot.scrollbarMinHandleHeight,

                                scrollbarTrack.height *
                                flick.height /
                                Math.max(
                                    1,
                                    flick.contentHeight
                                )
                            )

                        readonly property real travel:
                            Math.max(
                                0,

                                scrollbarTrack.height -
                                scrollbarTrack.handleHeight
                            )

                        readonly property real progress:
                            flick.scrollRange > 0
                                ? Math.max(
                                    0,

                                    Math.min(
                                        1,

                                        flick.contentY /
                                        flick.scrollRange
                                    )
                                )
                                : 0

                        Rectangle {
                            id: scrollbarHandle

                            x:
                                0

                            width:
                                parent.width

                            height:
                                parent.handleHeight

                            y:
                                parent.travel *
                                parent.progress

                            radius:
                                width * 0.5

                            color:
                                internalRoot.scrollbarHandleColor

                            opacity:
                                scrollbarMouseArea.pressed
                                    ? 1
                                    : 0.82
                        }

                        MouseArea {
                            id: scrollbarMouseArea

                            anchors.fill:
                                parent

                            property real dragOffset:
                                0

                            function updateFromMouse(
                                mouseY
                            ) {
                                const travel =
                                    scrollbarTrack.travel

                                if (
                                    travel <= 0
                                ) {
                                    return
                                }

                                const desiredY =
                                    Math.max(
                                        0,

                                        Math.min(
                                            travel,

                                            Number(mouseY) -
                                            scrollbarMouseArea.dragOffset
                                        )
                                    )

                                const progress =
                                    desiredY /
                                    travel

                                flick.contentY =
                                    progress *
                                    flick.scrollRange
                            }

                            onPressed: function(mouse) {
                                if (
                                    !flick.overflowing
                                ) {
                                    return
                                }

                                const handleTop =
                                    scrollbarHandle.y

                                const handleBottom =
                                    handleTop +
                                    scrollbarHandle.height

                                if (
                                    mouse.y >= handleTop &&
                                    mouse.y <= handleBottom
                                ) {
                                    dragOffset =
                                        mouse.y -
                                        handleTop
                                } else {
                                    dragOffset =
                                        scrollbarHandle.height *
                                        0.5
                                }

                                updateFromMouse(
                                    mouse.y
                                )

                                mouse.accepted =
                                    true
                            }

                            onPositionChanged: function(mouse) {
                                if (
                                    !pressed
                                ) {
                                    return
                                }

                                updateFromMouse(
                                    mouse.y
                                )

                                mouse.accepted =
                                    true
                            }

                            onReleased:
                                mouse.accepted =
                                    true
                        }
                    }

                    // =================================================
                    // SUBMENU LEVEL HOVER
                    // =================================================

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

                    // =================================================
                    // CLOSE DELAY
                    // =================================================

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

                    // =================================================
                    // PREPARE
                    // =================================================

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
                         * Every new submenu/root component starts
                         * from the top.
                         */
                        flick.contentY =
                            0

                        level.loader.sourceComponent =
                            null

                        level.loader.sourceComponent =
                            component
                    }

                    // =================================================
                    // MEASURE
                    // =================================================

                    function refreshGeometry() {
                        if (!level.activeItem)
                            return

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

                        const outerWidth =
                            internalRoot.calculateLevelWidth(
                                level.naturalContentWidth,
                                level.naturalContentHeight
                            )

                        /*
                         * Give ContextMenuObj the ACTUAL content
                         * viewport width.
                         *
                         * The scrollbar reservation is already
                         * accounted for here.
                         */
                        internalRoot.assignMenuWidth(
                            level.activeItem,

                            internalRoot.contentWidthForMenu(
                                outerWidth,
                                level.naturalContentHeight
                            )
                        )
                    }

                    // =================================================
                    // ROOT POSITION
                    // =================================================

                    function positionRoot(
                        animate
                    ) {
                        if (
                            !internalRoot.targetScreen ||
                            !internalRoot.targetMonitor
                        ) {
                            return
                        }

                        const menuWidth =
                            internalRoot.calculateLevelWidth(
                                level.naturalContentWidth,
                                level.naturalContentHeight
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

                        if (
                            px >
                            maxX
                        ) {
                            px =
                                internalRoot.cursorX -
                                menuWidth
                        }

                        if (
                            py >
                            maxY
                        ) {
                            py =
                                internalRoot.cursorY -
                                menuHeight
                        }

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

                    // =================================================
                    // SUBMENU POSITION
                    // =================================================

                    function positionSubmenu(
                        parentObject
                    ) {
                        if (
                            !parentObject ||
                            !internalRoot.targetScreen
                        ) {
                            return
                        }

                        level.positionAnimationEnabled =
                            false

                        const menuWidth =
                            internalRoot.calculateLevelWidth(
                                level.naturalContentWidth,
                                level.naturalContentHeight
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

                        if (
                            rightX <=
                            maxX
                        ) {
                            px =
                                rightX
                        } else {
                            px =
                                leftX
                        }

                        let py =
                            mapped.y

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

                        level.x =
                            px

                        level.y =
                            py
                    }

                    // =================================================
                    // OPEN / CLOSE
                    // =================================================

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

                    // =================================================
                    // ROOT POSITION ANIMATION
                    // =================================================

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

                    // =================================================
                    // SIZE ANIMATION
                    // =================================================

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

                    // =================================================
                    // FADE
                    // =================================================

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

        // ========================================================
        // ASSIGN MENU WIDTH
        // ========================================================

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

        // ========================================================
        // CONTAINS MENU OBJECT
        // ========================================================

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

        // ========================================================
        // MEASURE WIDTH
        // ========================================================

        function measureWidth(
            item
        ) {
            if (!item)
                return 1

            /*
             * ContextMenuObj:
             *
             * intrinsic width only.
             *
             * Never use rendered width.
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

            const children =
                item.children

            /*
             * Container containing menu objects.
             *
             * Do NOT use its rendered width because the container
             * can already be stretched to the previous menu width.
             */
            if (
                children &&
                children.length > 0 &&
                internalRoot.containsMenuObject(
                    item
                )
            ) {
                let result =
                    0

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
            let result =
                0

            if (
                item.implicitWidth !==
                undefined
            ) {
                const implicitWidth =
                    Number(
                        item.implicitWidth
                    )

                if (
                    Number.isFinite(
                        implicitWidth
                    ) &&
                    implicitWidth > 0
                ) {
                    result =
                        Math.max(
                            result,
                            implicitWidth
                        )
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

            if (
                item.width !==
                undefined
            ) {
                const explicitWidth =
                    Number(
                        item.width
                    )

                const parentWidth =
                    item.parent &&
                    item.parent.width !== undefined
                        ? Number(
                            item.parent.width
                        )
                        : NaN

                const mirrorsParent =
                    Number.isFinite(
                        explicitWidth
                    ) &&
                    Number.isFinite(
                        parentWidth
                    ) &&
                    Math.abs(
                        explicitWidth -
                        parentWidth
                    ) < 0.5

                if (
                    Number.isFinite(
                        explicitWidth
                    ) &&
                    explicitWidth > 0 &&
                    !mirrorsParent
                ) {
                    result =
                        Math.max(
                            result,
                            explicitWidth
                        )
                }
            }

            return Math.max(
                1,
                result
            )
        }

        // ========================================================
        // MEASURE HEIGHT
        // ========================================================

        function measureHeight(
            item
        ) {
            if (!item)
                return 1

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

            const children =
                item.children

            if (
                children &&
                children.length > 0 &&
                internalRoot.containsMenuObject(
                    item
                )
            ) {
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

            if (
                item.implicitHeight !==
                undefined
            ) {
                const implicitHeight =
                    Number(
                        item.implicitHeight
                    )

                if (
                    Number.isFinite(
                        implicitHeight
                    ) &&
                    implicitHeight > 0
                ) {
                    result =
                        Math.max(
                            result,
                            implicitHeight
                        )
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

            if (
                item.height !==
                undefined
            ) {
                const explicitHeight =
                    Number(
                        item.height
                    )

                const parentHeight =
                    item.parent &&
                    item.parent.height !== undefined
                        ? Number(
                            item.parent.height
                        )
                        : NaN

                const mirrorsParent =
                    Number.isFinite(
                        explicitHeight
                    ) &&
                    Number.isFinite(
                        parentHeight
                    ) &&
                    Math.abs(
                        explicitHeight -
                        parentHeight
                    ) < 0.5

                if (
                    Number.isFinite(
                        explicitHeight
                    ) &&
                    explicitHeight > 0 &&
                    !mirrorsParent
                ) {
                    result =
                        Math.max(
                            result,
                            explicitHeight
                        )
                }
            }

            return Math.max(
                1,
                result
            )
        }

        // ========================================================
        // TREE BINDING
        // ========================================================

        function bindTree(
            item,
            depth,
            parentObject
        ) {
            if (!item)
                return

            let nearestParent =
                parentObject || null

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

        // ========================================================
        // SUBMENU VISIBILITY
        // ========================================================

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

        // ========================================================
        // OBJECT HOVER
        // ========================================================

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

            let parents =
                internalRoot.submenuParents.slice()

            parents[submenuDepth] =
                object.hasSubmenu
                    ? object
                    : null

            internalRoot.submenuParents =
                parents

            let parentHover =
                internalRoot.parentHovered.slice()

            parentHover[submenuDepth] =
                Boolean(
                    object.hasSubmenu
                )

            internalRoot.parentHovered =
                parentHover

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

            internalRoot.openSubmenu(
                object,
                false
            )
        }

        // ========================================================
        // OBJECT EXIT
        // ========================================================

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

        // ========================================================
        // OBJECT CLICK
        // ========================================================

        function objectClicked(
            object
        ) {
            if (
                !object ||
                !object.enabled
            ) {
                return
            }

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

            object.activate()

            if (
                object.closeOnClick
            ) {
                internalRoot.close()
            }
        }

        // ========================================================
        // SUBMENU OPEN
        // ========================================================

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

            let parents =
                internalRoot.submenuParents.slice()

            parents[depth] =
                parentObject

            internalRoot.submenuParents =
                parents

            let pins =
                internalRoot.submenuPinned.slice()

            pins[depth] =
                Boolean(
                    pinned === true
                )

            internalRoot.submenuPinned =
                pins

            let parentHover =
                internalRoot.parentHovered.slice()

            parentHover[depth] =
                true

            internalRoot.parentHovered =
                parentHover

            level.cancelScheduledClose()

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

                    if (
                        internalRoot.parentAt(
                            depth
                        ) !==
                        parentObject
                    ) {
                        return
                    }

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

                    level.positionSubmenu(
                        parentObject
                    )

                    level.openVisible()

                    internalRoot.clearDeeperState(
                        depth
                    )
                }
            )
        }

        // ========================================================
        // LEVEL ENTER
        // ========================================================

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

        // ========================================================
        // LEVEL EXIT
        // ========================================================

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

        // ========================================================
        // OPEN DESCENDANT
        // ========================================================

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

        // ========================================================
        // BRANCH ACTIVE
        // ========================================================

        function isBranchActive(
            depth
        ) {
            if (
                internalRoot.boolAt(
                    internalRoot.submenuPinned,
                    depth
                )
            ) {
                return true
            }

            if (
                internalRoot.boolAt(
                    internalRoot.parentHovered,
                    depth
                )
            ) {
                return true
            }

            if (
                internalRoot.boolAt(
                    internalRoot.submenuHovered,
                    depth
                )
            ) {
                return true
            }

            if (
                internalRoot.hasOpenDescendant(
                    depth
                )
            ) {
                return true
            }

            return false
        }

        // ========================================================
        // SUBMENU LIFETIME
        // ========================================================

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

        // ========================================================
        // CLEAR DEEPER STATE
        // ========================================================

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

        // ========================================================
        // CLOSE FROM DEPTH
        // ========================================================

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

        // ========================================================
        // CLOSE
        // ========================================================

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

        // ========================================================
        // RIGHT-CLICK RECALL
        // ========================================================

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
             * Below actual menu levels.
             *
             * The menu levels have z >= 1000.
             */
            z:
                1

            hoverEnabled:
                false

            onPressed: function(mouse) {
                internalRoot.open(
                    internalRoot.requestedComponent,

                    internalRoot.requestedLayer
                )

                mouse.accepted =
                    true
            }
        }

        // ========================================================
        // OUTSIDE CLICK
        // ========================================================

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

            hoverEnabled:
                false

            onPressed: function(mouse) {
                internalRoot.close()

                mouse.accepted =
                    true
            }
        }

        // ========================================================
        // CLOSE CLEANUP
        // ========================================================

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

                internalRoot.parent =
                    overlayHost

                internalRoot.requestedLayer =
                    WlrLayer.Overlay
            }
        }
    }
}