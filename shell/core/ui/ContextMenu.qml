import QtQuick

import qs.core.ui

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property bool menuOpen: false

    property bool outsideClickCloses: true

    property var sourceItem: null

    /*
     * Cursor position in this ContextMenu's coordinate space.
     */
    property real cursorX: 0
    property real cursorY: 0

    // ============================================================
    // GEOMETRY
    // ============================================================

    property int menuPadding: 4

    property int menuGap: 6

    property int submenuGap: 3

    property int screenMargin: 8

    property int minimumWidth: 180

    property int maximumWidth: 420

    property int maximumHeight: 640

    // ============================================================
    // ANIMATION
    // ============================================================

    property int animationDuration: 180

    /*
     * Main menu and submenu use the same opening animation.
     *
     * IMPORTANT:
     *
     * x/y are positioned BEFORE opacity becomes visible.
     *
     * There is therefore no "remember old position → slide to new"
     * behavior when a submenu opens.
     */
    property int positionAnimationDuration:
        180

    // ============================================================
    // SUBMENU
    // ============================================================

    property int maxDepth: 8

    /*
     * For a submenu at depth N:
     *
     * submenuPinned[N] = true
     *
     * means it was clicked and should remain open.
     */
    property var submenuPinned: []

    /*
     * parentHovered[N]
     *
     * submenuHovered[N]
     */
    property var parentHovered: []
    property var submenuHovered: []

    /*
     * Current submenu parent for every depth.
     */
    property var submenuParents: []

    // ============================================================
    // VISUAL
    // ============================================================

    property color backgroundColor:
        "#090d12"

    property color borderColor:
        "#263541"

    property int borderWidth:
        1

    property real radius:
        8

    // ============================================================
    // POSITION TRACKING
    // ============================================================

    HoverHandler {
        id: cursorTracker

        blocking:
            false

        onPointChanged: {
            const p =
                point.position

            root.cursorX =
                p.x

            root.cursorY =
                p.y
        }
    }

    // ============================================================
    // OUTSIDE CLICK
    // ============================================================

    MouseArea {
        anchors.fill:
            parent

        enabled:
            root.menuOpen &&
            root.outsideClickCloses

        acceptedButtons:
            Qt.AllButtons

        z:
            -10000

        onPressed: {
            root.close()

            mouse.accepted =
                true
        }
    }

    // ============================================================
    // HELPERS
    // ============================================================

    function boolAt(
        array,
        index
    ) {
        return (
            array &&
            index >= 0 &&
            index < array.length &&
            array[index] === true
        )
    }

    function levelAt(depth) {
        return levelRepeater.itemAt(
            depth
        )
    }

    function parentAt(depth) {
        if (
            depth < 0 ||
            depth >= root.submenuParents.length
        ) {
            return null
        }

        return (
            root.submenuParents[depth] ||
            null
        )
    }

    // ============================================================
    // ROOT OPEN
    // ============================================================

    function open(component) {
        if (!component)
            return

        /*
         * Reset all submenu state.
         */
        root.submenuPinned =
            []

        root.parentHovered =
            []

        root.submenuHovered =
            []

        root.submenuParents =
            []

        root.sourceItem =
            root.parent || root

        root.menuOpen =
            true

        const level =
            root.levelAt(0)

        if (!level)
            return

        level.prepareForOpen(
            component
        )

        /*
         * IMPORTANT:
         *
         * Position first.
         *
         * The level is still invisible.
         */
        level.positionRoot()

        level.snapPosition()

        /*
         * Now animate only opacity/size.
         */
        level.openVisible()
    }

    // ============================================================
    // SUBMENU OPEN
    // ============================================================

    function openSubmenu(
        parentObject,
        pinned
    ) {
        if (
            !root.menuOpen ||
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
            depth < 1 ||
            depth >= root.maxDepth
        ) {
            return
        }

        /*
         * A different object on the same parent level replaces
         * the previous hover submenu.
         *
         * A clicked submenu remains pinned.
         */
        const oldParent =
            root.parentAt(depth)

        const sameParent =
            oldParent === parentObject

        if (
            !sameParent
        ) {
            root.closeFromDepth(
                depth
            )
        }

        let pinnedState =
            root.submenuPinned.slice(0)

        pinnedState[depth] =
            pinned === true

        root.submenuPinned =
            pinnedState

        let parentState =
            root.parentHovered.slice(0)

        parentState[depth] =
            true

        root.parentHovered =
            parentState

        let parents =
            root.submenuParents.slice(0)

        parents[depth] =
            parentObject

        root.submenuParents =
            parents

        const level =
            root.levelAt(depth)

        if (!level)
            return

        level.prepareForOpen(
            parentObject.submenu
        )

        /*
         * VERY IMPORTANT:
         *
         * The submenu is positioned while invisible.
         *
         * Therefore it NEVER starts at its previous position and
         * slides to its new position.
         */
        level.positionSubmenu(
            parentObject
        )

        level.snapPosition()

        level.openVisible()

        root.clearDeeperState(
            depth
        )
    }

    // ============================================================
    // OBJECT HOVER
    // ============================================================

    function objectHovered(
        object,
        parentDepth
    ) {
        if (!root.menuOpen)
            return

        const depth =
            Number(parentDepth)

        /*
         * Hovering another object on a menu level means the
         * temporary submenu belonging to that level should be
         * replaced.
         *
         * A clicked/pinned submenu is left alone.
         */
        if (depth >= 0) {
            const submenuDepth =
                depth + 1

            if (
                !root.boolAt(
                    root.submenuPinned,
                    submenuDepth
                )
            ) {
                root.closeFromDepth(
                    submenuDepth
                )
            }

            let state =
                root.parentHovered.slice(0)

            state[submenuDepth] =
                true

            root.parentHovered =
                state
        }

        /*
         * A submenu-opening object opens its submenu on hover.
         */
        if (object.hasSubmenu)
            root.openSubmenu(
                object,
                false
            )
    }

    // ============================================================
    // OBJECT EXIT
    // ============================================================

    function objectExited(
        object,
        parentDepth
    ) {
        if (!root.menuOpen)
            return

        const submenuDepth =
            Number(parentDepth) + 1

        let state =
            root.parentHovered.slice(0)

        state[submenuDepth] =
            false

        root.parentHovered =
            state

        /*
         * Click-opened submenu is pinned.
         */
        if (
            root.boolAt(
                root.submenuPinned,
                submenuDepth
            )
        ) {
            return
        }

        root.checkSubmenuLifetime(
            submenuDepth
        )
    }

    // ============================================================
    // SUBMENU HOVER
    // ============================================================

    function levelHovered(
        depth
    ) {
        let state =
            root.submenuHovered.slice(0)

        state[depth] =
            true

        root.submenuHovered =
            state
    }

    function levelExited(
        depth
    ) {
        let state =
            root.submenuHovered.slice(0)

        state[depth] =
            false

        root.submenuHovered =
            state

        root.checkSubmenuLifetime(
            depth
        )
    }

    // ============================================================
    // SUBMENU LIFETIME
    // ============================================================

    function checkSubmenuLifetime(
        depth
    ) {
        if (
            depth < 1 ||
            !root.menuOpen
        ) {
            return
        }

        /*
         * Clicked submenu:
         *
         * ignore hover exit completely.
         */
        if (
            root.boolAt(
                root.submenuPinned,
                depth
            )
        ) {
            return
        }

        /*
         * Desired hover behavior:
         *
         * parent hovered OR submenu hovered
         *     = stay
         *
         * neither
         *     = close
         */
        const parentIsHovered =
            root.boolAt(
                root.parentHovered,
                depth
            )

        const submenuIsHovered =
            root.boolAt(
                root.submenuHovered,
                depth
            )

        if (
            parentIsHovered ||
            submenuIsHovered
        ) {
            return
        }

        root.closeFromDepth(
            depth
        )
    }

    // ============================================================
    // CLOSE BRANCH
    // ============================================================

    function clearDeeperState(
        depth
    ) {
        let pinned =
            root.submenuPinned.slice(0)

        let parents =
            root.parentHovered.slice(0)

        let hovered =
            root.submenuHovered.slice(0)

        for (
            let i = depth + 1;
            i < root.maxDepth;
            ++i
        ) {
            pinned[i] =
                false

            parents[i] =
                false

            hovered[i] =
                false
        }

        root.submenuPinned =
            pinned

        root.parentHovered =
            parents

        root.submenuHovered =
            hovered
    }

    function closeFromDepth(
        depth
    ) {
        if (
            depth < 1
        ) {
            return
        }

        for (
            let i = depth;
            i < root.maxDepth;
            ++i
        ) {
            const level =
                root.levelAt(i)

            if (level)
                level.closeVisible()
        }

        /*
         * State is cleared immediately so a new hover can open
         * another submenu without waiting for the animation.
         */
        let pinned =
            root.submenuPinned.slice(0)

        let parents =
            root.parentHovered.slice(0)

        let hovered =
            root.submenuHovered.slice(0)

        let parentObjects =
            root.submenuParents.slice(0)

        for (
            let i = depth;
            i < root.maxDepth;
            ++i
        ) {
            pinned[i] =
                false

            parents[i] =
                false

            hovered[i] =
                false

            parentObjects[i] =
                null
        }

        root.submenuPinned =
            pinned

        root.parentHovered =
            parents

        root.submenuHovered =
            hovered

        root.submenuParents =
            parentObjects
    }

    // ============================================================
    // COMPLETE CLOSE
    // ============================================================

    function close() {
        if (!root.menuOpen)
            return

        root.menuOpen =
            false

        for (
            let i = 0;
            i < root.maxDepth;
            ++i
        ) {
            const level =
                root.levelAt(i)

            if (level)
                level.closeVisible()
        }

        closeTimer.restart()
    }

    // ============================================================
    // LEVEL REPEATER
    // ============================================================

    Repeater {
        id: levelRepeater

        model:
            root.maxDepth

        delegate: CutBox {
            id: level

            property int depth:
                index

            property bool opened:
                false

            property bool opening:
                false

            property bool closing:
                false

            property Component currentComponent:
                null

            readonly property Item activeItem:
                loader.item

            readonly property real naturalContentWidth:
                root.measureWidth(
                    level.activeItem
                )

            readonly property real naturalContentHeight:
                root.measureHeight(
                    level.activeItem
                )

            // ----------------------------------------------------
            // CUTBOX SURFACE
            // ----------------------------------------------------

            cut: ({})

            round: ({
                topLeft: level.radius,
                topRight: level.radius,
                bottomRight: level.radius,
                bottomLeft: level.radius
            })

            bgColor:
                root.backgroundColor

            borderWidth:
                root.borderWidth

            borderColor:
                root.borderColor

            interactive:
                root.menuOpen

            // ----------------------------------------------------
            // SIZE
            // ----------------------------------------------------

            width:
                Math.min(
                    root.maximumWidth,

                    Math.max(
                        root.minimumWidth,

                        level.naturalContentWidth +
                        root.menuPadding * 2
                    )
                )

            height:
                Math.min(
                    root.maximumHeight,

                    Math.max(
                        1,

                        level.naturalContentHeight +
                        root.menuPadding * 2
                    )
                )

            // ----------------------------------------------------
            // VISIBILITY
            // ----------------------------------------------------

            opacity:
                level.opened
                    ? 1
                    : 0

            visible:
                opacity > 0.001

            z:
                1000 +
                level.depth

            // ----------------------------------------------------
            // INTERNAL CONTENT
            // ----------------------------------------------------

            Item {
                anchors.fill:
                    parent

                anchors.margins:
                    root.menuPadding

                Loader {
                    id: loader

                    anchors.fill:
                        parent

                    asynchronous:
                        false

                    onLoaded: {
                        if (!item)
                            return

                        root.bindTree(
                            item,
                            level.depth,
                            root.parentAt(
                                level.depth
                            )
                        )
                    }
                }
            }

            // ----------------------------------------------------
            // SUBMENU HOVER
            // ----------------------------------------------------

            onHovered: {
                if (level.depth > 0)
                    root.levelHovered(
                        level.depth
                    )
            }

            onExited: {
                if (level.depth > 0)
                    root.levelExited(
                        level.depth
                    )
            }

            // ----------------------------------------------------
            // CONTENT
            // ----------------------------------------------------

            function prepareForOpen(
                component
            ) {
                if (!component)
                    return

                level.currentComponent =
                    component

                level.opened =
                    false

                level.opacity =
                    0

                loader.sourceComponent =
                    component
            }

            // ----------------------------------------------------
            // POSITION
            // ----------------------------------------------------

            function positionRoot() {
                let px =
                    root.cursorX +
                    root.menuGap

                let py =
                    root.cursorY +
                    root.menuGap

                /*
                 * Horizontal flip.
                 */
                if (
                    px +
                        level.width +
                        root.screenMargin >
                    root.width
                ) {
                    px =
                        root.cursorX -
                        level.width -
                        root.menuGap
                }

                /*
                 * Vertical flip.
                 */
                if (
                    py +
                        level.height +
                        root.screenMargin >
                    root.height
                ) {
                    py =
                        root.cursorY -
                        level.height -
                        root.menuGap
                }

                root.clampPosition(
                    level,
                    px,
                    py
                )
            }

            function positionSubmenu(
                parentObject
            ) {
                if (!parentObject)
                    return

                const mapped =
                    parentObject.mapToItem(
                        root,
                        0,
                        0
                    )

                const rightX =
                    mapped.x +
                    parentObject.width +
                    root.submenuGap

                const leftX =
                    mapped.x -
                    level.width -
                    root.submenuGap

                let px

                /*
                 * Prefer right.
                 *
                 * If right does not fit,
                 * use left.
                 */
                if (
                    rightX +
                        level.width +
                        root.screenMargin <=
                    root.width
                ) {
                    px =
                        rightX
                } else {
                    px =
                        leftX
                }

                let py =
                    mapped.y

                /*
                 * Keep the submenu attached to the parent
                 * vertically, then clamp it to the screen.
                 */
                root.clampPosition(
                    level,
                    px,
                    py
                )
            }

            function snapPosition() {
                level.animatePosition =
                    false

                /*
                 * x/y already contain the final position.
                 *
                 * Nothing is animated here.
                 */
            }

            function openVisible() {
                /*
                 * The level is already positioned.
                 */
                level.animatePosition =
                    false

                level.opened =
                    true

                level.opacity =
                    1

                /*
                 * Only size/opacity are animated.
                 */
            }

            function closeVisible() {
                level.opened =
                    false

                level.opacity =
                    0
            }

            // ----------------------------------------------------
            // ANIMATION
            // ----------------------------------------------------

            property bool animatePosition:
                false

            Behavior on x {
                enabled:
                    level.animatePosition

                NumberAnimation {
                    duration:
                        root.positionAnimationDuration

                    easing.type:
                        Easing.OutCubic
                }
            }

            Behavior on y {
                enabled:
                    level.animatePosition

                NumberAnimation {
                    duration:
                        root.positionAnimationDuration

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
    // TREE BINDING
    // ============================================================

    function bindTree(
        item,
        depth,
        parentObject
    ) {
        if (!item)
            return

        /*
         * ContextMenuObj exposes contextMenuInstance.
         */
        if (
            item.contextMenuInstance !==
            undefined
        ) {
            item.contextMenuInstance =
                root

            item.contextMenuDepth =
                depth

            item.parentMenuObject =
                parentObject || null
        }

        /*
         * Recurse into arbitrary QML content.
         */
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

            const nextParent =
                child.contextMenuInstance !==
                    undefined
                    ? child
                    : parentObject

            root.bindTree(
                child,
                depth,
                nextParent
            )
        }
    }

    // ============================================================
    // MEASUREMENT
    // ============================================================

    function measureWidth(item) {
        if (!item)
            return root.minimumWidth

        if (
            item.naturalWidth !==
                undefined
        ) {
            const value =
                Number(
                    item.naturalWidth
                )

            if (
                Number.isFinite(value) &&
                value > 0
            ) {
                return value
            }
        }

        if (
            item.width !==
                undefined &&
            Number(item.width) > 0
        ) {
            return Number(
                item.width
            )
        }

        if (
            item.childrenRect &&
            Number(
                item.childrenRect.width
            ) > 0
        ) {
            return Number(
                item.childrenRect.width
            )
        }

        return root.minimumWidth
    }

    function measureHeight(item) {
        if (!item)
            return 1

        if (
            item.naturalHeight !==
                undefined
        ) {
            const value =
                Number(
                    item.naturalHeight
                )

            if (
                Number.isFinite(value) &&
                value > 0
            ) {
                return value
            }
        }

        if (
            item.height !==
                undefined &&
            Number(item.height) > 0
        ) {
            return Number(
                item.height
            )
        }

        if (
            item.childrenRect &&
            Number(
                item.childrenRect.height
            ) > 0
        ) {
            return Number(
                item.childrenRect.height
            )
        }

        return 1
    }

    // ============================================================
    // POSITION CLAMP
    // ============================================================

    function clampPosition(
        level,
        px,
        py
    ) {
        px =
            Math.max(
                root.screenMargin,

                Math.min(
                    px,

                    Math.max(
                        root.screenMargin,

                        root.width -
                            level.width -
                            root.screenMargin
                    )
                )
            )

        py =
            Math.max(
                root.screenMargin,

                Math.min(
                    py,

                    Math.max(
                        root.screenMargin,

                        root.height -
                            level.height -
                            root.screenMargin
                    )
                )
            )

        level.x =
            px

        level.y =
            py
    }

    // ============================================================
    // CLOSE FINALIZATION
    // ============================================================

    Timer {
        id: closeTimer

        interval:
            root.animationDuration + 25

        repeat:
            false

        onTriggered: {
            if (root.menuOpen)
                return

            for (
                let i = 0;
                i < root.maxDepth;
                ++i
            ) {
                const level =
                    root.levelAt(i)

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
            }

            root.submenuPinned =
                []

            root.parentHovered =
                []

            root.submenuHovered =
                []

            root.submenuParents =
                []
        }
    }
}
