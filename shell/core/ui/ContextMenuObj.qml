import QtQuick
import Quickshell.Io

import qs.core.ui

CutBox {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property string text: ""

    property bool enabled: true

    /*
     * Optional executable actions.
     *
     * More than one may be supplied.
     *
     *     functionAction + process
     *
     * are both executed.
     */
    property var functionAction: null
    property Process process: null

    /*
     * A Component containing the submenu.
     */
    property Component submenu: null

    /*
     * Leaf actions close the complete ContextMenu by default.
     */
    property bool closeOnClick: true

    /*
     * Nerd Font submenu arrow.
     */
    property string submenuIcon: ""

    // ============================================================
    // VISUAL
    // ============================================================

    property color normalTextColor:
        "#e8edf0"

    property color disabledTextColor:
        "#4b5963"

    property color hoverBackground:
        "#1a3039"

    property color hoverTextColor:
        "#2acfff"

    property color arrowColor:
        "#657681"

    property color arrowHoverColor:
        "#2acfff"

    property int rowHeight: 34

    property int horizontalPadding: 10

    property int textArrowSpacing: 8

    property int menuAnimationDuration: 140

    // ============================================================
    // CONTEXT MENU CONNECTION
    // ============================================================

    /*
     * ContextMenu injects these automatically.
     */
    property var contextMenuInstance: null

    property int contextMenuDepth: 0

    property Item parentMenuObject: null

    readonly property bool hasSubmenu:
        root.submenu !== null

    // ============================================================
    // CUTBOX
    // ============================================================

    /*
     * ContextMenuObj is itself a CutBox.
     *
     * The surface handles:
     *
     *     hovered
     *     exited
     *     clicked
     *     pressed
     *     released
     *
     * through the reusable CutBox interaction layer.
     */
    interactive:
        root.enabled

    bgColor:
        root.enabled && root.hoveredState
            ? root.hoverBackground
            : "transparent"

    borderWidth:
        0

    cut: ({
        })

    round: ({
        })

    // ============================================================
    // HOVER STATE
    // ============================================================

    /*
     * CutBox's signal is `hovered()`.
     *
     * Keep a separate state property because the ContextMenu needs
     * a persistent boolean to know whether this particular object
     * is currently under the pointer.
     */
    property bool hoveredState: false

    onHovered: {
        root.hoveredState = true

        if (
            root.contextMenuInstance &&
            root.hasSubmenu
        ) {
            root.contextMenuInstance.objectHovered(
                root,
                root.contextMenuDepth
            )
        }
    }

    onExited: {
        root.hoveredState = false

        if (
            root.contextMenuInstance &&
            root.hasSubmenu
        ) {
            root.contextMenuInstance.objectExited(
                root,
                root.contextMenuDepth
            )
        }
    }

    // ============================================================
    // ACTIVATION
    // ============================================================

    function runActions() {
        if (!root.enabled)
            return

        // --------------------------------------------------------
        // FUNCTION
        // --------------------------------------------------------

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
                } catch (e) {
                    console.warn(
                        "[ContextMenuObj]",
                        root.text,
                        "function failed:",
                        e
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

        // --------------------------------------------------------
        // PROCESS
        // --------------------------------------------------------

        if (root.process) {
            if (!root.process.running)
                root.process.running = true
        }
    }

    onClicked: function(mouse) {
        if (!root.enabled)
            return

        /*
         * A submenu item has two distinct interaction modes:
         *
         * hover:
         *     temporary submenu
         *
         * click:
         *     pinned submenu
         */
        if (root.hasSubmenu) {
            root.runActions()

            if (
                root.contextMenuInstance
            ) {
                root.contextMenuInstance.openSubmenu(
                    root,
                    true
                )
            }

            return
        }

        root.runActions()

        if (
            root.closeOnClick &&
            root.contextMenuInstance
        ) {
            root.contextMenuInstance.close()
        }
    }

    // ============================================================
    // SIZE
    // ============================================================

    /*
     * Text and arrow remain inside the same row.
     */
    readonly property real naturalWidth:
        textItem.implicitWidth +
        root.horizontalPadding * 2 +
        (
            root.hasSubmenu
                ? (
                    root.textArrowSpacing +
                    arrow.implicitWidth
                )
                : 0
        )

    readonly property real naturalHeight:
        root.rowHeight

    /*
     * Custom content can still be supplied.
     *
     * It appears below the normal menu row.
     */
    default property alias contentData:
        contentColumn.data

    // ============================================================
    // CONTENT
    // ============================================================

    Item {
        id: menuContent

        anchors.left:
            parent.left

        anchors.right:
            parent.right

        anchors.top:
            parent.top

        height:
            root.rowHeight

        // --------------------------------------------------------
        // TEXT
        // --------------------------------------------------------

        Text {
            id: textItem

            anchors.left:
                parent.left

            anchors.leftMargin:
                root.horizontalPadding

            anchors.right:
                root.hasSubmenu
                    ? arrow.left
                    : parent.right

            anchors.rightMargin:
                root.hasSubmenu
                    ? root.textArrowSpacing
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

            verticalAlignment:
                Text.AlignVCenter

            horizontalAlignment:
                Text.AlignLeft

            elide:
                Text.ElideRight

            Behavior on color {
                ColorAnimation {
                    duration:
                        root.menuAnimationDuration

                    easing.type:
                        Easing.OutCubic
                }
            }
        }

        // --------------------------------------------------------
        // ARROW
        // --------------------------------------------------------

        Text {
            id: arrow

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
                root.enabled
                    ? (
                        root.hoveredState
                            ? root.arrowHoverColor
                            : root.arrowColor
                    )
                    : root.disabledTextColor

            font.family:
                "Symbols Nerd Font"

            font.pixelSize:
                12

            horizontalAlignment:
                Text.AlignRight

            verticalAlignment:
                Text.AlignVCenter
        }
    }

    // ============================================================
    // OPTIONAL CUSTOM CONTENT
    // ============================================================

    Column {
        id: contentColumn

        anchors.left:
            parent.left

        anchors.right:
            parent.right

        anchors.top:
            menuContent.bottom

        spacing:
            4

        visible:
            children.length > 0
    }

    // ============================================================
    // GEOMETRY
    // ============================================================

    width:
        parent
            ? parent.width
            : root.naturalWidth

    height:
        root.rowHeight +
        (
            contentColumn.visible
                ? contentColumn.childrenRect.height
                : 0
        )
}
