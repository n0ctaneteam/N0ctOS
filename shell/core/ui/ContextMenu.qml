import QtQuick
import QtQuick.Controls

import "."

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    /*
     * The ContextMenu instance is owned by a surface:
     *
     *     Desktop -> one ContextMenu
     *     FileManager -> one ContextMenu
     *
     * It is NOT a global application singleton.
     */

    property bool opened: false

    property int animationDuration: 180

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

    /*
     * Requested minimum padding.
     *
     * Actual padding is additionally constrained by the current
     * CutBox corner geometry.
     */
    property real minPadding: 8

    readonly property real padding: {
        let largest = 0

        const shapes = [
            root.cut || {},
            root.round || {}
        ]

        for (const shape of shapes) {
            for (const key of [
                "topLeft",
                "topRight",
                "bottomRight",
                "bottomLeft"
            ]) {
                if (shape[key] !== undefined)
                    largest = Math.max(
                        largest,
                        Number(shape[key]) || 0
                    )
            }
        }

        return Math.min(
            root.minPadding,
            largest * 0.2
        )
    }

    readonly property Item sourceItem: _sourceItem
    readonly property point cursorPosition: _cursorPosition

    readonly property Item currentContent:
        _activeLoader && _activeLoader.item
            ? _activeLoader.item
            : null

    // ============================================================
    // INTERNAL STATE
    // ============================================================

    property Item _sourceItem: null
    property point _cursorPosition: Qt.point(0, 0)

    property int _activeIndex: 0
    property int _pendingIndex: -1

    property Component _requestedComponent: null

    property real _targetWidth: 0
    property real _targetHeight: 0
    property real _targetX: 0
    property real _targetY: 0

    property var _submenuEntries: []

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

        if (!root.opened) {
            root._openInitial(component)
            return true
        }

        root._replace(component)
        return true
    }

    function close() {
        if (!root.opened)
            return

        submenuCloseTimer.stop()

        root._closeAllSubmenus()

        root.opened = false

        menuHideTimer.restart()
    }

    // ============================================================
    // OPEN INITIAL
    // ============================================================

    function _openInitial(component) {
        root._requestedComponent = component

        root._activeIndex = 0
        root._pendingIndex = -1

        contentLoaderB.sourceComponent = null
        contentLoaderB.opacity = 0

        contentLoaderA.opacity = 0
        contentLoaderA.sourceComponent = component
    }

    function _initialLoaded(loader) {
        if (!loader.item)
            return

        root._prepareContent(loader.item)

        const size = root._componentSize(loader.item)

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

        root._targetX = position.x
        root._targetY = position.y

        root.opened = true

        menuShell.opacity = 0

        Qt.callLater(function() {
            menuShell.opacity = 1
            contentLoaderA.opacity = 1
        })
    }

    // ============================================================
    // REPLACEMENT
    // ============================================================

    function _replace(component) {
        if (!component)
            return

        /*
         * If an earlier replacement is still transitioning,
         * promote the incoming content to the active side first.
         *
         * This lets a new request interrupt an existing animation
         * instead of waiting for it to finish.
         */
        if (root._pendingIndex !== -1)
            root._promotePending()

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

        loader.sourceComponent = component
    }

    function _replacementLoaded(index, loader) {
        if (
            index !== root._pendingIndex ||
            !loader.item
        ) {
            return
        }

        root._prepareContent(loader.item)

        const size = root._componentSize(loader.item)

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

        root._targetX = position.x
        root._targetY = position.y

        loader.opacity = 1

        root._activeLoader.opacity = 0

        replacementTimer.restart()
    }

    function _promotePending() {
        if (root._pendingIndex === -1)
            return

        const oldIndex = root._activeIndex

        root._activeIndex = root._pendingIndex
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

        const oldIndex = root._activeIndex

        root._activeIndex = root._pendingIndex
        root._pendingIndex = -1

        const oldLoader =
            oldIndex === 0
                ? contentLoaderA
                : contentLoaderB

        oldLoader.opacity = 0
        oldLoader.sourceComponent = null
    }

    // ============================================================
    // CONTENT PREPARATION
    // ============================================================

    function _prepareContent(item) {
        if (!item)
            return

        root._bindMenuObjects(
            item,
            0
        )
    }

    function _bindMenuObjects(item, depth) {
        if (!item)
            return

        if (
            item.hasOwnProperty("contextMenuInstance")
        ) {
            item.contextMenuInstance = root
            item.contextMenuDepth = depth
        }

        for (const child of item.children)
            root._bindMenuObjects(
                child,
                depth
            )
    }

    // ============================================================
    // SUBMENUS
    // ============================================================

    function openSubmenu(component, sourceObject, depth) {
        if (!component || !sourceObject)
            return

        /*
         * Remove every submenu at this depth or deeper.
         */
        root._closeSubmenusFrom(depth + 1)

        const entry = {
            owner: sourceObject,
            depth: depth + 1,
            loader: null
        }

        const loader =
            submenuLoaderComponent.createObject(
                cascadeLayer,
                {
                    menuComponent: component,
                    menuOwner: sourceObject,
                    menuDepth: depth + 1
                }
            )

        if (!loader) {
            console.warn(
                "[ContextMenu] failed to create submenu"
            )
            return
        }

        entry.loader = loader

        root._submenuEntries.push(entry)

        loader.loaded.connect(function() {
            root._prepareSubmenu(
                loader,
                entry
            )
        })

        loader.sourceComponent = component
    }

    function _prepareSubmenu(loader, entry) {
        if (!loader.item)
            return

        root._bindSubmenuObjects(
            loader.item,
            entry.depth,
            entry.owner
        )

        const size =
            root._componentSize(
                loader.item
            )

        loader.width = size.width
        loader.height = size.height

        const position =
            root._submenuPosition(
                entry.owner,
                loader.width,
                loader.height
            )

        loader.x = position.x
        loader.y = position.y

        loader.opacity = 0

        submenuShowAnimation.restart()
    }

    function _bindSubmenuObjects(
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
            root._bindSubmenuObjects(
                child,
                depth,
                parentObject
            )
        }
    }

    function _closeSubmenusFrom(depth) {
        for (let i = root._submenuEntries.length - 1; i >= 0; --i) {
            const entry =
                root._submenuEntries[i]

            if (entry.depth < depth)
                continue

            if (entry.loader)
                entry.loader.destroy()

            root._submenuEntries.splice(i, 1)
        }
    }

    function _closeAllSubmenus() {
        for (
            let i = root._submenuEntries.length - 1;
            i >= 0;
            --i
        ) {
            const entry =
                root._submenuEntries[i]

            if (entry.loader)
                entry.loader.destroy()
        }

        root._submenuEntries = []
    }

    // ============================================================
    // POINTER / SOURCE DETECTION
    // ============================================================

    function _capturePointerContext() {
        /*
         * HoverHandler keeps the current pointer position without
         * consuming the mouse event.
         */
        root._cursorPosition =
            Qt.point(
                pointerTracker.point.position.x,
                pointerTracker.point.position.y
            )

        root._sourceItem =
            root._findSourceItem()
    }

    function _findSourceItem() {
        const contentRoot =
            root.Window
                ? root.Window.contentItem
                : root.parent

        if (!contentRoot)
            return null

        const point =
            contentRoot.mapFromItem(
                root,
                root._cursorPosition
            )

        /*
         * Temporarily hide ourselves so childAt() sees the actual
         * component under the cursor.
         */
        const oldVisible = root.visible
        root.visible = false

        const found =
            root._deepestItemAt(
                contentRoot,
                point
            )

        root.visible = oldVisible

        return found
    }

    function _deepestItemAt(item, point) {
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
    // GEOMETRY
    // ============================================================

    function _componentSize(item) {
        return {
            width: Math.max(
                1,
                Number(
                    item.implicitWidth ||
                    item.width ||
                    item.childrenRect.width ||
                    1
                )
            ),

            height: Math.max(
                1,
                Number(
                    item.implicitHeight ||
                    item.height ||
                    item.childrenRect.height ||
                    1
                )
            )
        }
    }

    function _mainMenuPosition(point, width, height) {
        let x = point.x
        let y = point.y

        /*
         * Prefer cursor -> top-left.
         *
         * If the menu would leave the screen, flip around the
         * cursor in the conventional context-menu direction.
         */
        if (x + width > root.width)
            x = point.x - width

        if (y + height > root.height)
            y = point.y - height

        x = Math.max(
            0,
            Math.min(
                x,
                Math.max(0, root.width - width)
            )
        )

        y = Math.max(
            0,
            Math.min(
                y,
                Math.max(0, root.height - height)
            )
        )

        return Qt.point(x, y)
    }

    function _submenuPosition(
        sourceObject,
        width,
        height
    ) {
        const topLeft =
            sourceObject.mapToItem(
                root,
                0,
                0
            )

        const sourceRight =
            topLeft.x +
            sourceObject.width

        const rightSpace =
            root.width -
            sourceRight

        const leftSpace =
            topLeft.x

        let x

        if (rightSpace >= width) {
            x = sourceRight
        } else if (leftSpace >= width) {
            x = topLeft.x - width
        } else if (rightSpace >= leftSpace) {
            x = sourceRight
        } else {
            x = topLeft.x - width
        }

        let y = topLeft.y

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

        return Qt.point(x, y)
    }

    // ============================================================
    // MAIN MENU SHELL
    // ============================================================

    Item {
        id: menuShell

        x: root._targetX
        y: root._targetY

        width: root._targetWidth
        height: root._targetHeight

        visible: root.opened
        opacity: 0

        Behavior on x {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        CutBox {
            anchors.fill: parent

            cut: root.cut
            round: root.round

            bgColor: root.backgroundColor
            borderColor: root.borderColor
            borderWidth: root.borderWidth
            borderGlow: root.borderGlow

            interactive: false

            Item {
                id: contentArea

                anchors.fill: parent
                anchors.margins: root.padding
                clip: false

                Loader {
                    id: contentLoaderA

                    anchors.centerIn: parent

                    onLoaded:
                        root._initialLoaded(this)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.animationDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Loader {
                    id: contentLoaderB

                    anchors.centerIn: parent

                    opacity: 0

                    onLoaded:
                        root._replacementLoaded(
                            1,
                            this
                        )

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.animationDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // SUBMENU OVERLAY
    // ============================================================

    Item {
        id: cascadeLayer

        anchors.fill: parent
        z: menuShell.z + 1
    }

    Component {
        id: submenuLoaderComponent

        Loader {
            property Component menuComponent: null
            property Item menuOwner: null
            property int menuDepth: 0

            asynchronous: false
        }
    }

    // ============================================================
    // POINTER TRACKER
    // ============================================================

    HoverHandler {
        id: pointerTracker

        enabled: true
        blocking: false

        onPointChanged: {
            root._cursorPosition =
                point.position
        }
    }

    // ============================================================
    // ANIMATION TIMERS
    // ============================================================

    Timer {
        id: replacementTimer

        interval:
            root.animationDuration

        repeat: false

        onTriggered:
            root._finishReplacement()
    }

    Timer {
        id: menuHideTimer

        interval:
            root.animationDuration

        repeat: false

        onTriggered: {
            menuShell.opacity = 0

            if (!root.opened) {
                contentLoaderA.sourceComponent = null
                contentLoaderB.sourceComponent = null
            }
        }
    }

    Timer {
        id: submenuCloseTimer
        interval: 0
        repeat: false
    }

    SequentialAnimation {
        id: submenuShowAnimation

        NumberAnimation {
            target: {
                const entries =
                    root._submenuEntries

                if (!entries.length)
                    return null

                const last =
                    entries[entries.length - 1]

                return last.loader
            }

            property: "opacity"

            from: 0
            to: 1

            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: {
        console.log(
            "[ContextMenu] created"
        )
    }
}