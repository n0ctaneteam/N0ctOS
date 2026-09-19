import QtQuick
import Quickshell.Io

import qs.core.lib

CutBox {
    id: root

    // ============================================================
    // PUBLIC
    // ============================================================

    property string text:
        ""

    property bool enabled:
        true

    property var functionAction:
        null

    property Process process:
        null

    property Component submenu:
        null

    property bool closeOnClick:
        true

    property string submenuIcon:
        ""

    // ============================================================
    // STYLE
    // ============================================================

    property color normalTextColor:
        "#e8edf0"

    property color disabledTextColor:
        "#4b5963"

    property color hoverBackground:
        "#1a3039"

    property color hoverTextColor:
        "#2acfff"

    property color backgroundColor:
        "transparent"

    property int headerHeight:
        36

    property int horizontalPadding:
        10

    property int spacing:
        8

    property int animationDuration:
        140

    // ============================================================
    // CONTEXT MENU INTERNALS
    // ============================================================

    property var contextMenuInstance:
        null

    property int contextMenuDepth:
        -1

    property var parentMenuObject:
        null

    /*
     * Set by ContextMenu.assignMenuWidth().
     *
     * 0 = natural width.
     *
     * IMPORTANT:
     * naturalWidth does NOT depend on this property.
     */
    property real menuWidth:
        0

    property bool hoveredState:
        false

    readonly property bool isContextMenuObject:
        true

    readonly property bool hasSubmenu:
        root.submenu !== null

    default property alias contentData:
        body.data

    // ============================================================
    // NATURAL CONTENT SIZE
    // ============================================================

    /*
     * Explicitly boolean.
     *
     * This fixes:
     *
     *     Unable to assign [undefined] to bool
     */
    readonly property bool hasContent:
        Boolean(
            body &&
            body.children &&
            body.children.length > 0
        )

    readonly property real contentWidth:
        body
            ? Number(
                body.childrenRect.width
            ) || 0
            : 0

    readonly property real contentHeight:
        body
            ? Number(
                body.childrenRect.height
            ) || 0
            : 0

    /*
     * These DO NOT reference root.width/root.height.
     *
     * That is the critical binding-loop fix.
     */
    readonly property real naturalWidth:
        Math.max(
            header.naturalWidth,

            root.contentWidth +
            root.horizontalPadding * 2
        )

    readonly property real naturalHeight:
        root.headerHeight +
        (
            root.hasContent
                ? root.contentHeight
                : 0
        )

    readonly property real preferredWidth:
        Math.max(
            1,
            root.naturalWidth
        )

    readonly property real preferredHeight:
        Math.max(
            1,
            root.naturalHeight
        )

    // ============================================================
    // RENDERED SIZE
    // ============================================================

    /*
     * Rendering width may be assigned by ContextMenu after
     * natural measurement.
     */
    width:
        root.menuWidth > 0
            ? root.menuWidth
            : root.preferredWidth

    height:
        root.preferredHeight

    // ============================================================
    // VISUAL
    // ============================================================

    interactive:
        root.enabled

    bgColor:
        root.hoveredState
            ? root.hoverBackground
            : root.backgroundColor

    borderWidth:
        0

    borderColor:
        "transparent"

    borderGlow:
        0

    cut:
        ({})

    round:
        ({
            topLeft: 7,
            topRight: 7,
            bottomRight: 7,
            bottomLeft: 7
        })

    // ============================================================
    // ACTION
    // ============================================================

    function activate() {
        if (!root.enabled)
            return

        if (
            root.functionAction !==
            null
        ) {
            if (
                typeof root.functionAction ===
                "function"
            ) {
                try {
                    root.functionAction()
                } catch (error) {
                    console.warn(
                        "[ContextMenuObj]",
                        root.text,
                        "functionAction failed:",
                        error
                    )
                }
            } else {
                console.warn(
                    "[ContextMenuObj]",
                    root.text,
                    "functionAction is not a function"
                )
            }
        }

        if (root.process) {
            if (
                !root.process.running
            ) {
                root.process.running =
                    true
            }
        }
    }

    // ============================================================
    // HOVER
    // ============================================================

    onHovered: {
        root.hoveredState =
            true

        if (
            root.contextMenuInstance
        ) {
            root.contextMenuInstance.objectHovered(
                root,
                root.contextMenuDepth
            )
        }
    }

    onExited: {
        root.hoveredState =
            false

        if (
            root.contextMenuInstance
        ) {
            root.contextMenuInstance.objectExited(
                root,
                root.contextMenuDepth
            )
        }
    }

    // ============================================================
    // CLICK
    // ============================================================

    onClicked: function(mouse) {
        if (
            mouse.button !==
            Qt.LeftButton
        ) {
            return
        }

        if (!root.enabled)
            return

        if (
            root.contextMenuInstance
        ) {
            root.contextMenuInstance.objectClicked(
                root
            )
        }
    }

    // ============================================================
    // LAYOUT
    // ============================================================

    Column {
        id: layout

        anchors.fill:
            parent

        spacing:
            0

        // ========================================================
        // HEADER
        // ========================================================

        Item {
            id: header

            width:
                root.width

            height:
                root.headerHeight

            readonly property real naturalWidth: {
                let value =
                    textItem.implicitWidth +
                    root.horizontalPadding * 2

                if (
                    root.hasSubmenu
                ) {
                    value +=
                        root.spacing +
                        submenuIndicator.implicitWidth
                }

                return value
            }

            Text {
                id: textItem

                anchors.left:
                    parent.left

                anchors.leftMargin:
                    root.horizontalPadding

                anchors.right:
                    root.hasSubmenu
                        ? submenuIndicator.left
                        : parent.right

                anchors.rightMargin:
                    root.hasSubmenu
                        ? root.spacing
                        : root.horizontalPadding

                anchors.verticalCenter:
                    parent.verticalCenter

                text:
                    root.text

                color:
                    !root.enabled
                        ? root.disabledTextColor
                        : (
                            root.hoveredState
                                ? root.hoverTextColor
                                : root.normalTextColor
                        )

                font.family:
                    "Symbols Nerd Font"

                font.pixelSize:
                    12

                horizontalAlignment:
                    Text.AlignLeft

                verticalAlignment:
                    Text.AlignVCenter

                elide:
                    Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration:
                            root.animationDuration

                        easing.type:
                            Easing.OutCubic
                    }
                }
            }

            Text {
                id: submenuIndicator

                visible:
                    root.hasSubmenu

                anchors.right:
                    parent.right

                anchors.rightMargin:
                    root.horizontalPadding

                anchors.verticalCenter:
                    parent.verticalCenter

                text:
                    root.submenuIcon

                color:
                    root.hoveredState
                        ? root.hoverTextColor
                        : root.normalTextColor

                font.family:
                    "Symbols Nerd Font"

                font.pixelSize:
                    11

                horizontalAlignment:
                    Text.AlignHCenter

                verticalAlignment:
                    Text.AlignVCenter

                Behavior on color {
                    ColorAnimation {
                        duration:
                            root.animationDuration

                        easing.type:
                            Easing.OutCubic
                    }
                }
            }
        }

        // ========================================================
        // OPTIONAL INLINE BODY
        // ========================================================

        Column {
            id: body

            x:
                root.horizontalPadding

            width:
                Math.max(
                    0,

                    root.width -
                    root.horizontalPadding * 2
                )

            spacing:
                4

            visible:
                root.hasContent
        }
    }
}