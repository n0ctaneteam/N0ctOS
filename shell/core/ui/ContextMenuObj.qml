import QtQuick
import Quickshell.Io

import qs.core.lib

CutBox {
    id: root

    // ============================================================
    // PUBLIC — mandatory menu entry (icon+text via nerd font in text)
    // ============================================================

    property string text: ""
    property bool enabled: true
    property var functionAction: null
    property Process process: null
    property Component submenu: null
    property bool closeOnClick: true
    property string submenuIcon: ""

    // ============================================================
    // STYLE
    // ============================================================

    property color normalTextColor: "#e8edf0"
    property color disabledTextColor: "#4b5963"
    property color hoverBackground: "#1a3039"
    property color hoverTextColor: "#2acfff"
    property color backgroundColor: "transparent"
    property int headerHeight: 36
    property int horizontalPadding: 10
    property int spacing: 8
    property int animationDuration: 140

    // ============================================================
    // INTERNAL — set by ContextMenu.bindMenu
    // ============================================================

    property int contextMenuDepth: -1
    property bool hoveredState: false
    readonly property bool isContextMenuObject: true
    readonly property bool hasSubmenu: root.submenu !== null
    default property alias contentData: body.data

    // ============================================================
    // SIZE — natural via header + body, full-width after measure
    // ============================================================

    readonly property real naturalWidth: Math.max(header.naturalWidth, body.implicitWidth + root.horizontalPadding * 2)
    readonly property real naturalHeight: root.headerHeight + (root.hasContent ? root.body.implicitHeight : 0)
    readonly property real preferredWidth: Math.max(1, root.naturalWidth)
    readonly property real preferredHeight: Math.max(1, root.naturalHeight)
    readonly property bool hasContent: body.children.length > 0

    width: root.contextMenuDepth >= 0 && parent ? parent.width : root.preferredWidth
    height: root.preferredHeight

    // ============================================================
    // CUTBOX — reuse visual
    // ============================================================

    interactive: root.enabled
    bgColor: root.hoveredState ? root.hoverBackground : root.backgroundColor
    borderWidth: 0
    borderColor: "transparent"
    borderGlow: 0
    cut: ({ topLeft: 7, topRight: 7, bottomRight: 7, bottomLeft: 7 })

    // ============================================================
    // ACTIONS
    // ============================================================

    function activate() {
        if (!root.enabled) return
        if (root.functionAction !== null) {
            if (typeof root.functionAction === "function") {
                try { root.functionAction() } catch (error) {
                    console.warn("[ContextMenuObj]", root.text, "functionAction failed:", error)
                }
            } else {
                console.warn("[ContextMenuObj]", root.text, "functionAction is not a function")
            }
        }
        if (root.process) {
            if (!root.process.running) root.process.running = true
        }
    }

    // ============================================================
    // INPUT — mouse only, mandatory
    // ============================================================

    onHovered: {
        root.hoveredState = true
        ContextMenu.notifyHovered(root)
    }
    onExited: {
        root.hoveredState = false
        ContextMenu.notifyExited(root)
    }
    onClicked: function(mouse) {
        if (mouse.button !== Qt.LeftButton || !root.enabled) return
        ContextMenu.notifyClicked(root)
    }

    // ============================================================
    // CONTENT — text above, children left-aligned below
    // ============================================================

    Column {
        id: layout
        anchors.fill: parent
        spacing: 0

        Item {
            id: header
            width: root.width
            height: root.headerHeight
            readonly property real naturalWidth: {
                let v = textItem.implicitWidth + root.horizontalPadding * 2
                if (root.hasSubmenu) v += root.spacing + submenuIndicator.implicitWidth
                return v
            }
            Text {
                id: textItem
                anchors.left: parent.left
                anchors.leftMargin: root.horizontalPadding
                anchors.right: root.hasSubmenu ? submenuIndicator.left : parent.right
                anchors.rightMargin: root.hasSubmenu ? root.spacing : root.horizontalPadding
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: !root.enabled ? root.disabledTextColor : root.hoveredState ? root.hoverTextColor : root.normalTextColor
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
            }
            Text {
                id: submenuIndicator
                visible: root.hasSubmenu
                anchors.right: parent.right
                anchors.rightMargin: root.horizontalPadding
                anchors.verticalCenter: parent.verticalCenter
                text: root.submenuIcon
                color: root.hoveredState ? root.hoverTextColor : root.normalTextColor
                font.family: "Symbols Nerd Font"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Behavior on color { ColorAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
            }
        }

        Column {
            id: body
            x: root.horizontalPadding
            width: Math.max(0, root.width - root.horizontalPadding * 2)
            spacing: 4
            visible: root.hasContent
        }
    }
}
