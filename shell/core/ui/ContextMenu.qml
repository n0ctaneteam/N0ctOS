import QtQuick
import QtQuick.Controls

import "."

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    /*
     * One ContextMenu instance belongs to one owner/surface.
     *
     * Example:
     *
     *     Desktop
     *         └── ContextMenu
     *
     *     Future FileManager
     *         └── ContextMenu
     *
     * It is intentionally NOT a singleton.
     */

    property bool opened: false

    property int animationDuration: 180

    // ------------------------------------------------------------
    // VISUAL
    // ------------------------------------------------------------

    property color backgroundColor: "#10161d"
    property color borderColor: "#26323c"

    property int borderWidth: 1
    property int borderGlow: 0

    property var cut: ({
        topLeft: 12,
        topRight: 12,
        bottomRight: 12,
        bottomLeft: 12
    })

    property var round: ({})

    property real minPadding: 10

    /*
     * This is intentionally:
     *
     *     min(minPadding, corner * 0.2)
     *
     * as requested.
     */
    readonly property real padding: {
        let largestCorner = 0

        const shapes = [
            root.cut || {},
            root.round || {}
        ]

        for (const shape of shapes) {
            for (const name of [
                "topLeft",
                "topRight",
                "bottomRight",
                "bottomLeft"
            ]) {
                if (shape[name] !== undefined)
                    largestCorner =
                        Math.max(
                            largestCorner,
                            Number(shape[name]) || 0
                        )
            }
        }

        if (largestCorner <= 0)
            return 0

        return Math.min(
            root.minPadding,
            largestCorner * 0.2
        )
    }

    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property Item sourceItem:
        root._sourceItem

    readonly property point cursorPosition:
        root._cursorPosition

    readonly property Item currentContent:
        root._activeLoader &&
        root._activeLoader.item
            ? root._activeLoader.item
            : null

    // ============================================================
    // INTERNAL STATE
    // ============================================================

    property Item _sourceItem: null
    property point _cursorPosition:
        Qt.point(0, 0)

    property bool _closing: false
    property bool _opening: false

    property int _activeIndex: 0
    property int _pendingIndex: -1

    property Component _requestedComponent: null

    property real _targetWidth: 0
    property real _targetHeight: 0
    property real _targetX: 0
    property real _targetY: 0

    property var _submenuEntries: []

    readonly property bool _visible:
        root.opened ||
        root._opening ||
        root._closing

    readonly property Item _activeLoader:
        root._activeIndex === 0
            ? contentLoaderA
            : contentLoaderB

    readonly property Item _pendingLoader:
        root._pendingIndex === 0
            ? contentLoaderA
            : root._pendingIndex === 1
                ? contentLoaderB
                : null

    // ============================================================
    // PUBLIC API
    // ============================================================

    function open(component) {
        if (!component) {
            console.warn(
                "[ContextMenu] open() requires a Component"
            )
            return false
        }

        root._capturePointerContext()

        if (!root.opened && !root._closing) {
            root._openInitial(component)
            return true
        }

        if (root._closing) {
            root._reopenWhileClosing(component)
            return true
        }

        root._replace(component)
        return true
    }

    function close() {
        if (
            !root.opened &&
            !root._opening &&
            !root._closing
        ) {
            return
        }

        root._closeAllSubmenus()

        /*
         * Keep the shell visible while opacity/size animate out.
         *
         * This is the part the previous implementation was missing:
         * `visible` is NOT bound directly to `opened`.
         */
        root.opened = false
        root._opening = false
        root._closing = true

        root._targetWidth = 0
        root._targetHeight = 0

        menuShell.opacity = 0

        closeCleanupTimer.restart()
    }

    // ============================================================
    // INITIAL OPEN
    // ============================================================

    function _openInitial(component) {
        root._requestedComponent = component

        root._activeIndex = 0
        root._pendingIndex = -1

        root._opening = true
        root._closing = false

        /*
         * CRITICAL:
         *
         * When opening from closed state, the position is assigned
         * DIRECTLY. No x/y animation is allowed here.
         */
        root._loadInitialComponent(component)
    }

    function _loadInitialComponent(component) {
        contentLoaderA.sourceComponent = null
        contentLoaderB.sourceComponent = null

        contentLoaderA.opacity = 0

        contentLoaderA.sourceComponent =
            component
    }

    function _initialContentLoaded(loader) {
        if (!loader.item)
            return

        root._prepareContent(
            loader.item,
            0,
            null
        )

        const size =
            root._measureContent(
                loader.item
            )

        root._targetWidth =
            size.width +
            root.padding * 2

        root._targetHeight =
            size.height +
            root.padding * 2

        const position =
            root._mainMenuPosition(
                root._cursorPosition,
                root._targetWidth,
                root._targetHeight
            )

        /*
         * SNAP position.
         *
         * No position animation on initial opening.
         */
        root._targetX = position.x
        root._targetY = position.y

        menuShell.x = root._targetX
        menuShell.y = root._targetY

        /*
         * Start from zero size and zero opacity.
         *
         * Width/height and opacity animate in.
         * x/y do not.
         */
        menuShell.width = 0
        menuShell.height = 0
        menuShell.opacity = 0

        root.opened = true

        Qt.callLater(function() {
            if (!root.opened)
                return

            root._opening = false

            /*
             * `Behavior` handles width/height and opacity.
             */
            menuShell.width =
                root._targetWidth

            menuShell.height =
                root._targetHeight

            menuShell.opacity = 1

            loader.opacity = 1
        })
    }

    // ============================================================
    // REOPEN WHILE CLOSING
    // ============================================================

    function _reopenWhileClosing(component) {
        closeCleanupTimer.stop()

        root._closing = false
        root._opening = true
        root.opened = false

        root._closeAllSubmenus()

        root._activeIndex = 0
        root._pendingIndex = -1

        root._capturePointerContext()

        contentLoaderA.sourceComponent = null
        contentLoaderB.sourceComponent = null
        contentLoaderA.opacity = 0

        root._requestedComponent = component

        contentLoaderA.sourceComponent = component
    }

    // ============================================================
    // REPLACEMENT
    // ============================================================

    function _replace(component) {
        if (!root.opened)
            return

        if (root._pendingIndex !== -1)
            root._promotePending()

        root._capturePointerContext()

        const nextIndex =
            root._activeIndex === 0
                ? 1
                : 0

        const loader =
            nextIndex === 0
                ? contentLoaderA
                : contentLoaderB

        loader.sourceComponent = null
        loader.opacity = 0

        root._pendingIndex = nextIndex
        root._requestedComponent = component

        loader.sourceComponent =
            component
    }

    function _replacementLoaded(
        index,
        loader
    ) {
        if (
            index !== root._pendingIndex ||
            !loader.item
        ) {
            return
        }

        root._prepareContent(
            loader.item,
            0,
            null
        )

        const size =
            root._measureContent(
                loader.item
            )

        root._targetWidth =
            size.width +
            root.padding * 2

        root._targetHeight =
            size.height +
            root.padding * 2

        const position =
            root._mainMenuPosition(
                root._cursorPosition,
                root._targetWidth,
                root._targetHeight
            )

        /*
         * EXISTING OPEN MENU:
         *
         * Position is allowed to animate.
         */
        root._targetX = position.x
        root._targetY = position.y

        /*
         * The x/y Behavior is only enabled during replacement.
         */
        menuShell.animatePosition = true

        loader.opacity = 1
        root._activeLoader.opacity = 0

        replacementCleanupTimer.restart()
    }

    function _promotePending() {
        if (root._pendingIndex === -1)
            return

        const oldIndex =
            root._activeIndex

        root._activeIndex =
            root._pendingIndex

        root._pendingIndex = -1

        const oldLoader =
            oldIndex === 0
                ? contentLoaderA
                : contentLoaderB

        oldLoader.opacity = 0
        oldLoader.sourceComponent = null
    }

    function _finishReplacement() {
        if (root._pendingIndex === -1)
            return

        const oldIndex =
            root._activeIndex

        root._activeIndex =
            root._pendingIndex

        root._pendingIndex = -1

        const oldLoader =
            oldIndex === 0
                ? contentLoaderA
                : contentLoaderB

        oldLoader.opacity = 0
        oldLoader.sourceComponent = null

        /*
         * Leave the menu in its stable state.
         *
         * A subsequent opening from the closed state will snap
         * position again.
         */
        menuShell.animatePosition = false
    }

    // ============================================================
    // CONTENT
    // ============================================================

    function _prepareContent(
        item,
        depth,
        parentObject
    ) {
        if (!item)
            return

        root._bindContextObjects(
            item,
            depth,
            parentObject
        )

        /*
         * Force the supplied content to use the actual menu width
         * after the outer shell has determined it.
         */
        root._applyContentWidth(
            item,
            Math.max(
                0,
                root._targetWidth -
                root.padding * 2
            )
        )
    }

    function _bindContextObjects(
        item,
        depth,
        parentObject
    ) {
        if (!item)
            return

        if (
            item.hasOwnProperty(
                "contextMenuInstance"
            )
        ) {
            item.contextMenuInstance = root
            item.contextMenuDepth = depth
            item.parentMenuObject = parentObject
        }

        for (const child of item.children) {
            root._bindContextObjects(
                child,
                depth,
                parentObject
            )
        }
    }

    function _applyContentWidth(
        item,
        width
    ) {
        if (!item)
            return

        if (
            item.hasOwnProperty(
                "width"
            )
        ) {
            if (
                item.hasOwnProperty(
                    "naturalWidth"
                )
            ) {
                item.width = width
            } else if (
                item.children &&
                item.children.length
            ) {
                item.width = width
            }
        }

        for (const child of item.children)
            root._applyContentWidth(
                child,
                width
            )
    }

    function _measureContent(item) {
        if (!item)
            return {
                width: 1,
                height: 1
            }

        let width = 0
        let height = 0

        width = Math.max(
            width,
            Number(
                item.implicitWidth ||
                item.width ||
                0
            )
        )

        height = Math.max(
            height,
            Number(
                item.implicitHeight ||
                item.height ||
                0
            )
        )

        /*
         * ContextMenuObj exposes natural dimensions.
         */
        if (
            item.hasOwnProperty(
                "naturalWidth"
            )
        ) {
            width = Math.max(
                width,
                Number(
                    item.naturalWidth
                ) || 0
            )

            height = Math.max(
                height,
                Number(
                    item.naturalHeight
                ) || 0
            )
        }

        /*
         * Inspect children as a fallback for arbitrary QML
         * Components.
         */
        let childMaxRight = 0
        let childMaxBottom = 0

        for (const child of item.children) {
            if (!child.visible)
                continue

            const childWidth =
                Math.max(
                    Number(child.width) || 0,
                    Number(child.implicitWidth) || 0
                )

            const childHeight =
                Math.max(
                    Number(child.height) || 0,
                    Number(child.implicitHeight) || 0
                )

            childMaxRight =
                Math.max(
                    childMaxRight,
                    Number(child.x) +
                    childWidth
                )

            childMaxBottom =
                Math.max(
                    childMaxBottom,
                    Number(child.y) +
                    childHeight
                )
        }

        const rectWidth =
            Number(
                item.childrenRect.width
            ) || 0

        const rectHeight =
            Number(
                item.childrenRect.height
            ) || 0

        width = Math.max(
            width,
            childMaxRight,
            rectWidth
        )

        height = Math.max(
            height,
            childMaxBottom,
            rectHeight
        )

        return {
            width: Math.max(1, width),
            height: Math.max(1, height)
        }
    }

    // ============================================================
    // SUBMENUS
    // ============================================================

    function openSubmenu(
        component,
        sourceObject,
        depth
    ) {
        if (
            !component ||
            !sourceObject
        ) {
            return
        }

        /*
         * Remove every deeper branch before opening the requested
         * submenu.
         */
        root._closeSubmenusFrom(
            depth + 1
        )

        const existing =
            root._submenuEntries.find(
                function(entry) {
                    return (
                        entry.owner === sourceObject &&
                        entry.depth === depth + 1
                    )
                }
            )

        if (existing)
            return

        const surface =
            submenuSurfaceComponent.createObject(
                cascadeLayer,
                {
                    menuComponent: component,
                    menuOwner: sourceObject,
                    menuDepth: depth + 1,
                    contextMenuRoot: root
                }
            )

        if (!surface) {
            console.warn(
                "[ContextMenu]",
                "failed to create submenu"
            )
            return
        }

        root._submenuEntries.push({
            owner: sourceObject,
            depth: depth + 1,
            surface: surface
        })

        surface.showMenu()
    }

    function _prepareSubmenu(
        surface,
        content
    ) {
        if (!content)
            return

        root._bindContextObjects(
            content,
            surface.menuDepth,
            surface.menuOwner
        )
    }

    function _closeSubmenusFrom(
        depth
    ) {
        for (
            let i =
                root._submenuEntries.length - 1;
            i >= 0;
            --i
        ) {
            const entry =
                root._submenuEntries[i]

            if (entry.depth < depth)
                continue

            if (entry.surface)
                entry.surface.closeMenu()

            root._submenuEntries.splice(
                i,
                1
            )
        }
    }

    function _closeAllSubmenus() {
        for (
            let i =
                root._submenuEntries.length - 1;
            i >= 0;
            --i
        ) {
            const entry =
                root._submenuEntries[i]

            if (entry.surface)
                entry.surface.closeMenu()
        }

        root._submenuEntries = []
    }

    function _removeSubmenuSurface(surface) {
        for (
            let i =
                root._submenuEntries.length - 1;
            i >= 0;
            --i
        ) {
            if (
                root._submenuEntries[i].surface ===
                surface
            ) {
                root._submenuEntries.splice(
                    i,
                    1
                )
            }
        }
    }

    // ============================================================
    // POINTER / SOURCE
    // ============================================================

    function _capturePointerContext() {
        root._cursorPosition =
            pointerTracker.point.position

        root._sourceItem =
            root._findSourceItem()
    }

    function _findSourceItem() {
        const surface =
            root.parent ||
            (
                root.Window
                    ? root.Window.contentItem
                    : null
            )

        if (!surface)
            return null

        const point =
            surface.mapFromItem(
                root,
                root._cursorPosition
            )

        const wasVisible =
            root.visible

        /*
         * Hide the menu itself while resolving the item beneath it.
         */
        root.visible = false

        const found =
            root._deepestItemAt(
                surface,
                point
            )

        root.visible = wasVisible

        return found === surface
            ? null
            : found
    }

    function _deepestItemAt(
        item,
        point
    ) {
        if (!item)
            return null

        const child =
            item.childAt(
                point.x,
                point.y
            )

        if (!child)
            return item

        const childPoint =
            item.mapToItem(
                child,
                point
            )

        const deeper =
            root._deepestItemAt(
                child,
                childPoint
            )

        return deeper || child
    }

    // ============================================================
    // POSITIONING
    // ============================================================

    function _mainMenuPosition(
        point,
        menuWidth,
        menuHeight
    ) {
        let x = point.x
        let y = point.y

        /*
         * First choice:
         * top-left exactly at cursor.
         */

        /*
         * Horizontal flip if needed.
         */
        if (
            x + menuWidth >
            root.width
        ) {
            x =
                point.x -
                menuWidth
        }

        /*
         * Vertical flip if needed.
         */
        if (
            y + menuHeight >
            root.height
        ) {
            y =
                point.y -
                menuHeight
        }

        /*
         * Final hard clamp.
         */
        x = Math.max(
            0,
            Math.min(
                x,
                Math.max(
                    0,
                    root.width - menuWidth
                )
            )
        )

        y = Math.max(
            0,
            Math.min(
                y,
                Math.max(
                    0,
                    root.height - menuHeight
                )
            )
        )

        return Qt.point(x, y)
    }

    function _submenuPosition(
        sourceObject,
        width,
        height
    ) {
        const sourceTopLeft =
            sourceObject.mapToItem(
                root,
                0,
                0
            )

        const sourceRight =
            sourceTopLeft.x +
            sourceObject.width

        const rightSpace =
            root.width -
            sourceRight

        const leftSpace =
            sourceTopLeft.x

        let x

        /*
         * Native-style cascading behavior:
         *
         * right if possible
         * otherwise left
         * otherwise clamp
         */
        if (rightSpace >= width) {
            x = sourceRight
        } else if (leftSpace >= width) {
            x =
                sourceTopLeft.x -
                width
        } else if (
            rightSpace >= leftSpace
        ) {
            x = sourceRight
        } else {
            x =
                sourceTopLeft.x -
                width
        }

        let y =
            sourceTopLeft.y

        /*
         * Clamp vertically.
         */
        y = Math.max(
            0,
            Math.min(
                y,
                Math.max(
                    0,
                    root.height - height
                )
            )
        )

        /*
         * Clamp horizontally too.
         */
        x = Math.max(
            0,
            Math.min(
                x,
                Math.max(
                    0,
                    root.width - width
                )
            )
        )

        return Qt.point(
            x,
            y
        )
    }

    // ============================================================
    // MAIN MENU SHELL
    // ============================================================

    Item {
        id: menuShell

        property bool animatePosition: false

        x:
            root._targetX

        y:
            root._targetY

        width:
            root._targetWidth

        height:
            root._targetHeight

        visible:
            root._visible

        opacity: 0

        /*
         * Width / height always animate.
         */
        Behavior on width {
            NumberAnimation {
                duration:
                    root.animationDuration

                easing.type:
                    Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration:
                    root.animationDuration

                easing.type:
                    Easing.OutCubic
            }
        }

        /*
         * Position ONLY animates while an already-open menu is
         * being replaced.
         *
         * Initial opening snaps x/y directly.
         */
        Behavior on x {
            enabled:
                menuShell.animatePosition

            NumberAnimation {
                duration:
                    root.animationDuration

                easing.type:
                    Easing.OutCubic
            }
        }

        Behavior on y {
            enabled:
                menuShell.animatePosition

            NumberAnimation {
                duration:
                    root.animationDuration

                easing.type:
                    Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration:
                    root.animationDuration

                easing.type:
                    Easing.OutCubic
            }
        }

        CutBox {
            anchors.fill: parent

            cut:
                root.cut

            round:
                root.round

            bgColor:
                root.backgroundColor

            borderColor:
                root.borderColor

            borderWidth:
                root.borderWidth

            borderGlow:
                root.borderGlow

            interactive: false

            // ----------------------------------------------------
            // MAIN CONTENT
            // ----------------------------------------------------

            Item {
                id: contentArea

                anchors.fill: parent

                anchors.margins:
                    root.padding

                clip: true

                Loader {
                    id: contentLoaderA

                    anchors.fill: parent

                    asynchronous: true

                    opacity: 0

                    onLoaded: {
                        if (!item)
                            return

                        if (
                            root._pendingIndex === -1 &&
                            root._opening
                        ) {
                            root._initialContentLoaded(
                                this
                            )
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration:
                                root.animationDuration

                            easing.type:
                                Easing.OutCubic
                        }
                    }
                }

                Loader {
                    id: contentLoaderB

                    anchors.fill: parent

                    asynchronous: true

                    opacity: 0

                    onLoaded: {
                        if (!item)
                            return

                        if (
                            root._pendingIndex === 1
                        ) {
                            root._replacementLoaded(
                                1,
                                this
                            )
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration:
                                root.animationDuration

                            easing.type:
                                Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // SUBMENU LAYER
    // ============================================================

    Item {
        id: cascadeLayer

        anchors.fill: parent

        z:
            1000
    }

    // ============================================================
    // POINTER TRACKER
    // ============================================================

    HoverHandler {
        id: pointerTracker

        enabled: true
        blocking: false

        onPointChanged:
            root._cursorPosition =
                point.position
    }

    // ============================================================
    // SUBMENU SURFACE COMPONENT
    // ============================================================

    Component {
        id: submenuSurfaceComponent

        Item {
            id: surface

            property Component menuComponent: null
            property Item menuOwner: null
            property int menuDepth: 0
            property Item contextMenuRoot: null

            property bool closing: false
            property bool shown: false

            property real naturalWidth: 1
            property real naturalHeight: 1

            width:
                naturalWidth

            height:
                naturalHeight

            opacity: 0

            /*
             * The submenu is positioned only after its content has
             * loaded and its natural size is known.
             */
            function showMenu() {
                if (!surface.menuComponent)
                    return

                submenuLoader.sourceComponent =
                    surface.menuComponent
            }

            function prepareContent(item) {
                if (!item)
                    return

                root._prepareSubmenu(
                    surface,
                    item
                )

                const size =
                    root._measureContent(
                        item
                    )

                surface.naturalWidth =
                    Math.max(
                        1,
                        size.width +
                        root.padding * 2
                    )

                surface.naturalHeight =
                    Math.max(
                        1,
                        size.height +
                        root.padding * 2
                    )

                /*
                 * Content receives the actual menu width.
                 */
                root._applyContentWidth(
                    item,
                    Math.max(
                        0,
                        surface.naturalWidth -
                        root.padding * 2
                    )
                )

                const position =
                    root._submenuPosition(
                        surface.menuOwner,
                        surface.width,
                        surface.height
                    )

                surface.x =
                    position.x

                surface.y =
                    position.y

                surface.closing = false
                surface.shown = true

                surface.opacity = 0

                Qt.callLater(function() {
                    if (!surface.shown)
                        return

                    surface.opacity = 1
                })
            }

            function closeMenu() {
                if (surface.closing)
                    return

                surface.closing = true
                surface.shown = false

                surface.opacity = 0

                destroyTimer.restart()
            }

            CutBox {
                anchors.fill: parent

                cut:
                    root.cut

                round:
                    root.round

                bgColor:
                    root.backgroundColor

                borderColor:
                    root.borderColor

                borderWidth:
                    root.borderWidth

                borderGlow:
                    root.borderGlow

                interactive: false

                Item {
                    anchors.fill: parent

                    anchors.margins:
                        root.padding

                    clip: true

                    Loader {
                        id: submenuLoader

                        anchors.fill:
                            parent

                        asynchronous: true

                        onLoaded: {
                            if (!item)
                                return

                            surface.prepareContent(
                                item
                            )
                        }
                    }
                }
            }

            Timer {
                id: destroyTimer

                interval:
                    root.animationDuration

                repeat: false

                onTriggered: {
                    root._removeSubmenuSurface(
                        surface
                    )

                    surface.destroy()
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration:
                        root.animationDuration

                    easing.type:
                        Easing.OutCubic
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration:
                        root.animationDuration

                    easing.type:
                        Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration:
                        root.animationDuration

                    easing.type:
                        Easing.OutCubic
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration:
                        root.animationDuration

                    easing.type:
                        Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration:
                        root.animationDuration

                    easing.type:
                        Easing.OutCubic
                }
            }
        }
    }

    // ============================================================
    // CLEANUP TIMERS
    // ============================================================

    Timer {
        id: replacementCleanupTimer

        interval:
            root.animationDuration

        repeat: false

        onTriggered:
            root._finishReplacement()
    }

    Timer {
        id: closeCleanupTimer

        interval:
            root.animationDuration

        repeat: false

        onTriggered: {
            contentLoaderA.sourceComponent = null
            contentLoaderB.sourceComponent = null

            contentLoaderA.opacity = 0
            contentLoaderB.opacity = 0

            root._requestedComponent = null

            root.opened = false
            root._opening = false
            root._closing = false

            root._targetWidth = 0
            root._targetHeight = 0

            menuShell.opacity = 0
        }
    }

    // ============================================================
    // DEBUG
    // ============================================================

    Component.onCompleted: {
        console.log(
            "[ContextMenu] created"
        )
    }
}