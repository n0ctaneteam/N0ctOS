pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.core.ui

Singleton {
    id: root

    // ============================================================
    // PUBLIC API — simple open(Component) / close()
    // ============================================================

    readonly property bool isOpen: menuOpen
    property bool menuOpen: false

    property Component rootComponent: null
    property var targetScreen: null
    property point pointer: Qt.point(0,0)
    property var pointerScreen: null

    // ============================================================
    // CONFIG — keep current visuals, use CutBox
    // ============================================================

    property real edgeMargin: 8
    property real submenuGap: 4
    property real minimumWidth: 150
    property real maximumWidth: 420
    property int animationDuration: 140
    property int submenuCloseDelay: 70

    property color menuBackground: "#0b1117"
    property color menuBorder: "#273944"
    property real menuBorderWidth: 1
    property real menuBorderGlow: 0

    // dynamic depth — no hard limit, grows as needed
    property int maxDepth: 20
    property int levelCount: 1

    property var pendingCloseLevel: null

    // ============================================================
    // POINTER — merged from ContextMenuInput, mouse only
    // ============================================================

    function updatePointer(item, x, y) {
        console.log("[ContextMenu] updatePointer:", item, x, y)
        if (!item) {
            console.warn("[ContextMenu] updatePointer: no item")
            return
        }
        var win = item.QsWindow
        if (!win) {
            console.warn("[ContextMenu] updatePointer: no QsWindow")
            return
        }
        var screen = win.screen
        if (!screen) {
            console.warn("[ContextMenu] updatePointer: no screen")
            return
        }
        var pt = win.mapFromItem(item, Number(x), Number(y))
        root.pointer = Qt.point(Number(screen.x) + pt.x, Number(screen.y) + pt.y)
        root.pointerScreen = screen
        console.log("[ContextMenu] pointer:", root.pointer, "screen:", screen.name, screen.x, screen.y)
    }

    function notifyHovered(object) { console.log("[ContextMenu] notifyHovered:", object ? object.text : "null", "depth", object ? object.contextMenuDepth : -1); objectHovered(object) }
    function notifyExited(object) { console.log("[ContextMenu] notifyExited:", object ? object.text : "null", "depth", object ? object.contextMenuDepth : -1); objectExited(object) }
    function notifyClicked(object) { console.log("[ContextMenu] notifyClicked:", object ? object.text : "null", "depth", object ? object.contextMenuDepth : -1); objectClicked(object) }

    // ============================================================
    // WINDOW
    // ============================================================

    PanelWindow {
        id: menuWindow

        screen: root.targetScreen
        visible: root.menuOpen && root.targetScreen !== null
        color: "transparent"
        anchors { top:true; bottom:true; left:true; right:true }
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay

        CutBox {
            id: dismissSurface
            anchors.fill: parent
            z: -1000
            interactive: root.menuOpen
            bgColor: "transparent"
            borderWidth: 0
            borderColor: "transparent"
            borderGlow: 0
            cut: ({ topLeft:0, topRight:0, bottomRight:0, bottomLeft:0 })
            onClicked: { console.log("[ContextMenu] dismissSurface clicked → close()"); root.close() }
            onRightClicked: { console.log("[ContextMenu] dismissSurface rightClicked → close()"); root.close() }
        }

        Repeater {
            id: levelRepeater
            model: root.levelCount
            delegate: CutBox {
                id: level
                required property int index
                readonly property int depth: index
                property Item owner: null
                property bool pinned: false
                property bool inside: false
                property Item hoveredObject: null
                property bool animate: false
                property alias sourceComponent: levelLoader.sourceComponent
                property alias flick: flick

                x: 0; y: 0; width: 1; height: 1
                z: 1000 + depth
                visible: false
                interactive: level.visible
                bgColor: root.menuBackground
                borderWidth: root.menuBorderWidth
                borderColor: root.menuBorder
                borderGlow: root.menuBorderGlow
                cut: ({ topLeft:8, topRight:8, bottomRight:8, bottomLeft:8 })

                Behavior on opacity {
                    enabled: level.animate
                    NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    enabled: level.animate
                    NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
                }

                onHovered: {
                    console.log("[ContextMenu] level", level.depth, "hovered")
                    if (!root.menuOpen) return
                    level.inside = true
                    root.cancelClose()
                }
                onExited: {
                    console.log("[ContextMenu] level", level.depth, "exited")
                    if (!root.menuOpen) return
                    level.inside = false
                    if (level.depth > 0) root.scheduleClose(level)
                }

                // scroll container with fade
                Item {
                    id: scrollWrap
                    objectName: "scrollWrap"
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true

                    Flickable {
                        id: flick
                        objectName: "flick"
                        anchors.fill: parent
                        clip: true
                        contentWidth: levelLoader.item ? levelLoader.item.implicitWidth || levelLoader.item.width : 0
                        contentHeight: levelLoader.item ? levelLoader.item.implicitHeight || levelLoader.item.height : 0
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.AutoFlickIfNeeded
                        interactive: contentWidth > width || contentHeight > height

                        Loader {
                            id: levelLoader
                            asynchronous: false
                            onLoaded: {
                                console.log("[ContextMenu] level", level.depth, "loader loaded:", levelLoader.item)
                                root.finishLevel(level, levelLoader.item, flick)
                            }
                        }
                    }

                    // top fade
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 16
                        visible: flick.contentY > 1 && flick.contentHeight > flick.height
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.menuBackground }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        z: 10
                    }
                    // bottom fade
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 16
                        visible: flick.contentY < flick.contentHeight - flick.height - 1
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: root.menuBackground }
                        }
                        z: 10
                    }
                    // left fade
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 16
                        visible: flick.contentX > 1 && flick.contentWidth > flick.width
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.menuBackground }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        z: 10
                    }
                    // right fade
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 16
                        visible: flick.contentX < flick.contentWidth - flick.width - 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: root.menuBackground }
                        }
                        z: 10
                    }
                }
            }
        }

        Timer {
            id: closeTimer
            interval: root.submenuCloseDelay
            repeat: false
            onTriggered: {
                console.log("[ContextMenu] closeTimer triggered, pending:", root.pendingCloseLevel ? root.pendingCloseLevel.depth : "null")
                var lvl = root.pendingCloseLevel
                root.pendingCloseLevel = null
                root.tryClose(lvl)
            }
        }
    }

    // ============================================================
    // PUBLIC: OPEN / CLOSE
    // ============================================================

    function open(component) {
        console.log("[ContextMenu] open() called, component:", component, "pointer:", root.pointer, "screen:", root.pointerScreen ? root.pointerScreen.name : "null")
        if (!component) {
            console.warn("[ContextMenu] open: no component")
            return
        }
        var screen = root.pointerScreen
        if (!screen && Quickshell.screens.length > 0) {
            screen = Quickshell.screens[0]
            console.log("[ContextMenu] open: no pointerScreen, fallback to", screen.name)
        }
        if (!screen) {
            console.warn("[ContextMenu] open: no screen")
            return
        }

        cancelClose()
        clearLevels()
        if (root.levelCount < 1) root.levelCount = 1

        root.targetScreen = screen
        root.rootComponent = component
        root.menuOpen = true
        console.log("[ContextMenu] open: targetScreen", screen.name, "menuOpen", root.menuOpen)

        var level = levelRepeater.itemAt(0)
        if (!level) {
            console.warn("[ContextMenu] open: no level 0")
            return
        }
        mountLevel(level, component, null, false)
    }

    function close() {
        console.log("[ContextMenu] close() called, wasOpen:", root.menuOpen)
        cancelClose()
        root.menuOpen = false
        root.rootComponent = null
        clearLevels()
        console.log("[ContextMenu] closed")
    }

    // ============================================================
    // LEVEL MOUNT
    // ============================================================

    function mountLevel(level, component, owner, pinned) {
        console.log("[ContextMenu] mountLevel depth", level ? level.depth : "null", "owner", owner ? owner.text : "null", "pinned", pinned, "component", component)
        if (!level || !component) {
            console.warn("[ContextMenu] mountLevel: missing level/component")
            return
        }
        closeBranch(level.depth + 1)
        if (level.depth >= root.levelCount) root.levelCount = level.depth + 1
        if (root.levelCount > root.maxDepth) root.maxDepth = root.levelCount

        level.animate = false
        level.visible = false
        level.owner = owner
        level.pinned = pinned
        level.inside = false
        level.hoveredObject = null
        level.opacity = 0
        level.scale = 0.96
        if (level.flick) { level.flick.contentX = 0; level.flick.contentY = 0 }
        level.sourceComponent = null
        level.sourceComponent = component
        console.log("[ContextMenu] mountLevel done, level", level.depth, "source set")
    }

    // ============================================================
    // LEVEL LOAD — measure, clamp to 90%, position, animate
    // ============================================================

    function finishLevel(level, item, flick) {
        console.log("[ContextMenu] finishLevel depth", level ? level.depth : "null", "item", item, "flick", flick)
        if (!level || !item || !root.menuOpen) {
            console.warn("[ContextMenu] finishLevel abort", !level, !item, !root.menuOpen)
            return
        }
        if (!flick) flick = level.flick

        var size = measure(item)
        console.log("[ContextMenu] finishLevel measure", size.width, "x", size.height, "for level", level.depth)
        var screenW = Number(root.targetScreen.width)
        var screenH = Number(root.targetScreen.height)
        var edge = root.edgeMargin

        var widthLimit = Math.max(1, Math.min(root.maximumWidth, screenW * 0.9, screenW - edge*2))
        var heightLimit = Math.max(1, Math.min(screenH * 0.9, screenH - edge*2))

        var targetW = Math.min(Math.max(root.minimumWidth, size.width), widthLimit)
        var targetH = Math.min(Math.max(1, size.height), heightLimit)
        console.log("[ContextMenu] finishLevel limits", widthLimit, heightLimit, "target", targetW, targetH, "screen", screenW, screenH)

        level.width = targetW
        level.height = targetH

        if (flick) {
            flick.contentWidth = Math.max(size.width, targetW - 8)
            flick.contentHeight = Math.max(size.height, targetH - 8)
            item.width = flick.contentWidth
            flick.contentX = 0
            flick.contentY = 0
            console.log("[ContextMenu] finishLevel flick content", flick.contentWidth, flick.contentHeight, "scroll needed", flick.contentHeight > flick.height || flick.contentWidth > flick.width)
        } else {
            item.width = targetW
        }

        bindMenu(item, level.depth)
        positionLevel(level)

        level.opacity = 0
        level.scale = 0.96
        level.visible = true
        level.animate = true
        level.opacity = 1
        level.scale = 1
        console.log("[ContextMenu] finishLevel done, level", level.depth, "visible", level.visible, "pos", level.x, level.y)
    }

    function findFlick(node) {
        if (!node || !node.children) return null
        for (var i=0;i<node.children.length;++i) {
            var ch = node.children[i]
            if (ch && ch.objectName === "flick") return ch
            if (ch && ch.contentWidth !== undefined && ch.contentHeight !== undefined && ch.contentX !== undefined) return ch
            var found = findFlick(ch)
            if (found) return found
        }
        return null
    }

    // ============================================================
    // POSITION — cursor flip, clamp to edge
    // ============================================================

    function positionLevel(level) {
        console.log("[ContextMenu] positionLevel depth", level.depth, "owner", level.owner ? level.owner.text : "root")
        if (!level || !root.targetScreen) {
            console.warn("[ContextMenu] positionLevel no level/screen")
            return
        }
        var screenW = Number(root.targetScreen.width)
        var screenH = Number(root.targetScreen.height)
        var edge = root.edgeMargin
        var maxX = Math.max(edge, screenW - level.width - edge)
        var maxY = Math.max(edge, screenH - level.height - edge)

        if (!level.owner) {
            var p = root.pointer
            level.x = Math.max(edge, Math.min(maxX, p.x - Number(root.targetScreen.x)))
            level.y = Math.max(edge, Math.min(maxY, p.y - Number(root.targetScreen.y)))
            console.log("[ContextMenu] positionLevel root at", level.x, level.y, "pointer", p, "screen", root.targetScreen.x, root.targetScreen.y, "max", maxX, maxY)
            return
        }
        var parent = level.owner
        var parentPoint = menuWindow.mapFromItem(parent, 0, 0)
        var rightX = parentPoint.x + parent.width + root.submenuGap
        var leftX = parentPoint.x - level.width - root.submenuGap
        var rightSpace = screenW - rightX - edge
        var leftSpace = leftX - edge
        var x
        if (rightSpace >= 0) x = rightX
        else if (leftSpace >= 0) x = leftX
        else x = rightSpace >= leftSpace ? rightX : leftX
        level.x = Math.max(edge, Math.min(maxX, x))
        level.y = Math.max(edge, Math.min(maxY, parentPoint.y))
        console.log("[ContextMenu] positionLevel submenu at", level.x, level.y, "parentPoint", parentPoint, "right", rightX, "left", leftX)
    }

    // ============================================================
    // HOVER / EXIT / CLICK — hybrid, parent stays highlighted
    // ============================================================

    function isSubmenuVisibleFor(object) {
        if (!object || !object.hasSubmenu) return false
        var depth = Number(object.contextMenuDepth)
        var child = levelRepeater.itemAt(depth+1)
        return !!(child && child.visible && child.owner === object)
    }

    function objectHovered(object) {
        console.log("[ContextMenu] objectHovered", object ? object.text : "null", "depth", object ? object.contextMenuDepth : -1)
        if (!root.menuOpen || !object) return
        var depth = Number(object.contextMenuDepth)
        if (depth < 0 || depth >= root.levelCount) {
            console.warn("[ContextMenu] objectHovered bad depth", depth)
            return
        }
        var level = levelRepeater.itemAt(depth)
        if (!level) return
        cancelClose()
        level.hoveredObject = object
        var child = levelRepeater.itemAt(depth+1)
        if (child && child.visible && !child.pinned && child.owner !== object) {
            console.log("[ContextMenu] objectHovered closing sibling branch", depth+1)
            closeBranch(depth+1)
        }
        if (object.hasSubmenu) {
            console.log("[ContextMenu] objectHovered has submenu → showSubmenu")
            showSubmenu(object, false)
        }
    }

    function objectExited(object) {
        console.log("[ContextMenu] objectExited", object ? object.text : "null", "depth", object ? object.contextMenuDepth : -1)
        if (!root.menuOpen || !object) return
        var depth = Number(object.contextMenuDepth)
        var level = levelRepeater.itemAt(depth)
        if (!level || level.hoveredObject !== object) return
        level.hoveredObject = null
        var child = levelRepeater.itemAt(depth+1)
        if (child && child.owner === object && !child.pinned) {
            if (child.visible && (child.inside || child.hoveredObject)) {
                console.log("[ContextMenu] objectExited keep parent highlighted for submenu")
                object.hoveredState = true
            }
            scheduleClose(child)
        }
    }

    function objectClicked(object) {
        console.log("[ContextMenu] objectClicked", object ? object.text : "null", "depth", object ? object.contextMenuDepth : -1)
        if (!root.menuOpen || !object) return
        var before = root.rootComponent
        object.activate()
        console.log("[ContextMenu] objectClicked after activate, menuOpen", root.menuOpen)
        if (!root.menuOpen || root.rootComponent !== before) return
        if (object.hasSubmenu) {
            console.log("[ContextMenu] objectClicked has submenu → pin")
            showSubmenu(object, true)
            return
        }
        if (object.closeOnClick) {
            console.log("[ContextMenu] objectClicked closeOnClick → close()")
            close()
        }
    }

    function showSubmenu(object, pin) {
        console.log("[ContextMenu] showSubmenu", object ? object.text : "null", "pin", pin)
        var parentDepth = Number(object.contextMenuDepth)
        var depth = parentDepth + 1
        if (depth < 1) return
        if (depth >= root.levelCount) root.levelCount = depth + 1
        if (depth >= root.maxDepth) root.maxDepth = depth + 1
        var level = levelRepeater.itemAt(depth)
        if (!level) {
            console.warn("[ContextMenu] showSubmenu no level", depth)
            return
        }
        cancelClose()
        if (level.visible && level.owner === object) {
            if (pin) {
                console.log("[ContextMenu] showSubmenu already visible, pinning")
                level.pinned = true
            }
            object.hoveredState = true
            return
        }
        if (level.visible && level.pinned) {
            console.log("[ContextMenu] showSubmenu blocked by pinned")
            return
        }
        closeBranch(depth)
        level.owner = object
        level.pinned = pin
        object.hoveredState = true
        mountLevel(level, object.submenu, object, pin)
    }

    // ============================================================
    // CLOSE CONTROL
    // ============================================================

    function scheduleClose(level) {
        console.log("[ContextMenu] scheduleClose depth", level ? level.depth : "null", "pinned", level ? level.pinned : "?")
        if (!level || level.depth < 1 || level.pinned) return
        root.pendingCloseLevel = level
        closeTimer.restart()
    }
    function cancelClose() {
        if (root.pendingCloseLevel) console.log("[ContextMenu] cancelClose was pending", root.pendingCloseLevel.depth)
        root.pendingCloseLevel = null
        closeTimer.stop()
    }
    function tryClose(level) {
        console.log("[ContextMenu] tryClose depth", level ? level.depth : "null", "visible", level ? level.visible : "?", "inside", level ? level.inside : "?", "hovered", level ? (level.hoveredObject ? level.hoveredObject.text : "null") : "?")
        if (!root.menuOpen || !level || !level.visible || level.pinned) return
        if (level.inside || level.hoveredObject) {
            console.log("[ContextMenu] tryClose abort: inside/hovered")
            return
        }
        if (level.owner && level.owner.hoveredState) {
            console.log("[ContextMenu] tryClose abort: owner still hovered")
            return
        }
        console.log("[ContextMenu] tryClose → closeBranch", level.depth)
        closeBranch(level.depth)
    }

    function closeBranch(depth) {
        console.log("[ContextMenu] closeBranch", depth)
        if (depth < 0 || depth >= root.levelCount) return
        for (var i=depth;i<root.levelCount;++i) {
            var lvl = levelRepeater.itemAt(i)
            if (!lvl) continue
            if (lvl.pinned) {
                console.log("[ContextMenu] closeBranch skip pinned", i)
                continue
            }
            if (lvl.owner) {
                var owner = lvl.owner
                var parentLvl = levelRepeater.itemAt(lvl.depth - 1)
                var stillHovered = parentLvl && parentLvl.hoveredObject === owner
                if (!stillHovered) {
                    console.log("[ContextMenu] closeBranch clear owner highlight", owner.text)
                    owner.hoveredState = false
                }
            }
            lvl.visible = false
            lvl.animate = false
            lvl.sourceComponent = null
            lvl.owner = null
            lvl.hoveredObject = null
            lvl.inside = false
        }
    }

    function clearLevels() {
        console.log("[ContextMenu] clearLevels")
        for (var i=0;i<root.levelCount;++i) {
            var lvl = levelRepeater.itemAt(i)
            if (!lvl) continue
            lvl.animate = false
            lvl.visible = false
            lvl.sourceComponent = null
            lvl.owner = null
            lvl.pinned = false
            lvl.inside = false
            lvl.hoveredObject = null
            lvl.opacity = 0
            lvl.scale = 0.96
        }
    }

    // ============================================================
    // BIND — mandatory ContextMenuObj only
    // ============================================================

    function bindMenu(node, depth) {
        console.log("[ContextMenu] bindMenu depth", depth, "node", node)
        if (!node) return
        if (node.isContextMenuObject === true) {
            node.contextMenuDepth = depth
            console.log("[ContextMenu] bind depth", depth, "to", node.text)
        }
        var children = node.children
        if (!children) return
        for (var i=0;i<children.length;++i) bindMenu(children[i], depth)
    }

    // ============================================================
    // MEASURE — mandatory ContextMenuObj only, 90% clamp handled in finishLevel
    // ============================================================

    function measure(node) {
        if (!node) return Qt.size(1,1)
        if (node.isContextMenuObject === true) {
            var s = Qt.size(Math.max(1, Number(node.preferredWidth)), Math.max(1, Number(node.preferredHeight)))
            console.log("[ContextMenu] measure isObj", node.text, s)
            return s
        }
        var children = node.children || []
        var width = Number(node.menuWidth || 0)
        var height = Number(node.menuHeight || 0)
        var visibleCount = 0
        for (var i=0;i<children.length;++i) {
            var ch = children[i]
            if (ch.visible === false) continue
            if (ch.isContextMenuObject !== true) {
                console.log("[ContextMenu] measure skip non-obj", ch)
                continue
            }
            var cs = measure(ch)
            width = Math.max(width, cs.width)
            height += cs.height
            ++visibleCount
        }
        if (visibleCount > 1 && node.spacing !== undefined) height += Number(node.spacing)*(visibleCount-1)
        if (children.length === 0) {
            width = Math.max(width, Number(node.implicitWidth||0), Number(node.width||0))
            height = Math.max(height, Number(node.implicitHeight||0), Number(node.height||0))
        }
        var res = Qt.size(Math.max(1,width), Math.max(1,height))
        console.log("[ContextMenu] measure container", node, res)
        return res
    }
}
