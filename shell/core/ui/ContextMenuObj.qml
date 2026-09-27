import QtQuick
import Quickshell.Io
import Quickshell.Widgets

import qs.core.lib

CutBox {
    id: root

    // ============================================================
    // PUBLIC
    // ============================================================

    property string text:
        ""

    /*
     * Optional leading icon.
     *
     * Normal ContextMenu users can leave this empty.
     */
    property string icon:
        ""

    /*
     * Optional leading Nerd Font glyph.
     *
     * Used by SystemTray for checkbox/radio indicators.
     */
    property string leadingContent:
        ""

    /*
     * Separator mode.
     *
     * A separator is rendered as a thin line and is not
     * interactive.
     */
    property bool isSeparator:
        false

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
     * Assigned by ContextMenu.
     *
     * 0 = natural width.
     * >0 = explicit rendered menu width.
     */
    property real menuWidth:
        0

    property bool hoveredState:
        false

    readonly property bool isContextMenuObject:
        true

    readonly property bool hasSubmenu:
        root.submenu !== null &&
        !root.isSeparator

    default property alias contentData:
        body.data

    // ============================================================
    // CONTENT SIZE
    // ============================================================

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

    // ============================================================
    // NATURAL SIZE
    // ============================================================

    readonly property real naturalWidth:
        root.isSeparator
            ? 180
            : Math.max(
                header.naturalWidth,

                root.contentWidth +
                root.horizontalPadding * 2
            )

    readonly property real naturalHeight:
        root.isSeparator
            ? Math.max(
                1,
                root.headerHeight
            )
            : root.headerHeight +
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
        root.enabled &&
        !root.isSeparator

    bgColor:
        root.hoveredState &&
        !root.isSeparator
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
        id:
            layout

        anchors.fill:
            parent

        spacing:
            0

        // ========================================================
        // HEADER
        // ========================================================

        Item {
            id:
                header

            width:
                root.width

            height:
                root.isSeparator
                    ? 9
                    : root.headerHeight

            readonly property real naturalWidth: {
                if (
                    root.isSeparator
                ) {
                    return 180
                }

                let value =
                    root.horizontalPadding * 2

                if (
                    leadingItem.visible
                ) {
                    value +=
                        leadingItem.width +
                        root.spacing
                }

                if (
                    iconItem.visible
                ) {
                    value +=
                        iconItem.width +
                        root.spacing
                }

                value +=
                    textItem.implicitWidth

                if (
                    root.hasSubmenu
                ) {
                    value +=
                        root.spacing +
                        submenuIndicator.implicitWidth
                }

                return value
            }

            // ----------------------------------------------------
            // SEPARATOR
            // ----------------------------------------------------

            Rectangle {
                anchors.centerIn:
                    parent

                width:
                    Math.max(
                        0,
                        parent.width - 16
                    )

                height:
                    1

                visible:
                    root.isSeparator

                color:
                    "#263541"
            }

            // ----------------------------------------------------
            // LEADING GLYPH
            // ----------------------------------------------------

            Text {
                id:
                    leadingItem

                width:
                    18

                anchors.left:
                    parent.left

                anchors.leftMargin:
                    root.horizontalPadding

                anchors.verticalCenter:
                    parent.verticalCenter

                visible:
                    !root.isSeparator &&
                    root.leadingContent.length > 0

                text:
                    root.leadingContent

                color:
                    !root.enabled
                        ? root.disabledTextColor
                        : root.hoveredState
                            ? root.hoverTextColor
                            : root.normalTextColor

                font.family:
                    "Symbols Nerd Font"

                font.pixelSize:
                    15

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

            // ----------------------------------------------------
            // ICON
            // ----------------------------------------------------

            IconImage {
                id:
                    iconItem

                width:
                    18

                height:
                    18

                anchors.left:
                    leadingItem.visible
                        ? leadingItem.right
                        : parent.left

                anchors.leftMargin:
                    leadingItem.visible
                        ? root.spacing
                        : root.horizontalPadding

                anchors.verticalCenter:
                    parent.verticalCenter

                visible:
                    !root.isSeparator &&
                    root.icon.length > 0

                source:
                    root.icon

                asynchronous:
                    true
            }

            // ----------------------------------------------------
            // TEXT
            // ----------------------------------------------------

            Text {
                id:
                    textItem

                anchors.left:
                    iconItem.visible
                        ? iconItem.right
                        : leadingItem.visible
                            ? leadingItem.right
                            : parent.left

                anchors.leftMargin:
                    (
                        iconItem.visible ||
                        leadingItem.visible
                    )
                        ? root.spacing
                        : root.horizontalPadding

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
                        : root.hoveredState
                            ? root.hoverTextColor
                            : root.normalTextColor

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

            // ----------------------------------------------------
            // SUBMENU ARROW
            // ----------------------------------------------------

            Text {
                id:
                    submenuIndicator

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
            id:
                body

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
                root.hasContent &&
                !root.isSeparator
        }
    }
}