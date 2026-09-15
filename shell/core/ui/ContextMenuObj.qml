import QtQuick
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    /*
     * The menu label.
     *
     * The icon, when wanted, is part of this same text value.
     *
     * Example:
     *
     *     text: "󰈹  Firefox"
     *
     * There is intentionally NO separate icon property.
     */
    property string text: ""

    property bool enabled: true

    /*
     * Executable actions.
     *
     * Multiple actions may coexist.
     *
     *     functionAction + process
     *
     * Both are executed when the object is activated.
     *
     * submenu is visual/navigation content and is handled separately.
     */
    property var functionAction: null
    property Process process: null
    property Component submenu: null

    /*
     * Normal action items close the complete ContextMenu by default.
     *
     * This is ignored when the object is being used only as a
     * submenu-opening object.
     */
    property bool closeOnClick: true

    /*
     * Arrow shown on submenu objects.
     */
    property string submenuIcon: ""

    // ============================================================
    // VISUAL
    // ============================================================

    property color normalTextColor: "#e8edf0"
    property color disabledTextColor: "#4b5963"

    property color hoverBackground: "#1a3039"
    property color hoverTextColor: "#2acfff"

    property int headerHeight: 36
    property int horizontalPadding: 10
    property int spacing: 8

    property int animationDuration: 140

    // ============================================================
    // CONTEXT MENU CONNECTION
    // ============================================================

    /*
     * These are assigned automatically by ContextMenu.
     *
     * Callers do NOT need to set them manually.
     */
    property var contextMenuInstance: null
    property int contextMenuDepth: 0
    property Item parentMenuObject: null

    readonly property bool hasSubmenu:
        root.submenu !== null

    readonly property bool hasContent:
        body.children.length > 0

    /*
     * Allow arbitrary QML children below the text row.
     */
    default property alias contentData: body.data

    // ============================================================
    // SIZE
    // ============================================================

    /*
     * Width is based only on the natural contents.
     *
     * The parent ContextMenu will stretch this object to the
     * available menu width at runtime.
     */
    readonly property real naturalWidth:
        Math.max(
            header.naturalWidth,
            body.implicitWidth
        ) +
        root.horizontalPadding * 2

    readonly property real naturalHeight:
        root.headerHeight +
        (
            root.hasContent
                ? root.body.implicitHeight
                : 0
        )

    implicitWidth:
        Math.max(
            1,
            root.naturalWidth
        )

    implicitHeight:
        Math.max(
            1,
            root.naturalHeight
        )

    width:
        parent
            ? parent.width
            : root.implicitWidth

    height:
        root.naturalHeight

    // ============================================================
    // ACTIONS
    // ============================================================

    function activate() {
        if (!root.enabled)
            return

        // --------------------------------------------------------
        // FUNCTION
        // --------------------------------------------------------

        if (root.functionAction !== null) {
            if (typeof root.functionAction === "function") {
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

        // --------------------------------------------------------
        // CLOSE
        // --------------------------------------------------------

        /*
         * Submenus are navigation.
         *
         * If this object has a submenu, the submenu remains open
         * after the object is activated.
         *
         * Normal leaf actions use closeOnClick.
         */
        if (
            !root.hasSubmenu &&
            root.closeOnClick &&
            root.contextMenuInstance
        ) {
            root.contextMenuInstance.close()
        }
    }

    function openSubmenu() {
        if (
            !root.enabled ||
            !root.hasSubmenu ||
            !root.contextMenuInstance
        ) {
            return
        }

        root.contextMenuInstance.openSubmenu(
            root.submenu,
            root,
            root.contextMenuDepth
        )
    }

    // ============================================================
    // LAYOUT
    // ============================================================

    Column {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        spacing: 0

        // ========================================================
        // HEADER / CLICKABLE MENU ITEM
        // ========================================================

        Item {
            id: header

            width:
                root.width > 0
                    ? root.width
                    : root.implicitWidth

            height:
                root.headerHeight

            readonly property real naturalWidth: {
                let value =
                    textItem.implicitWidth +
                    root.horizontalPadding * 2

                if (root.hasSubmenu)
                    value +=
                        root.spacing +
                        submenuIndicator.implicitWidth

                return value
            }

            // ----------------------------------------------------
            // HOVER BACKGROUND
            // ----------------------------------------------------

            Rectangle {
                anchors.fill: parent

                radius: 7

                color:
                    root.enabled &&
                    headerHover.hovered
                        ? root.hoverBackground
                        : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration:
                            root.animationDuration
                    }
                }
            }

            // ----------------------------------------------------
            // TEXT
            // ----------------------------------------------------

            Text {
                id: textItem

                x:
                    root.horizontalPadding

                anchors.left:
                    parent.left

                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.right:
                    root.hasSubmenu
                        ? submenuIndicator.left
                        : parent.right

                anchors.rightMargin:
                    root.hasSubmenu
                        ? root.spacing
                        : root.horizontalPadding

                text:
                    root.text

                color:
                    !root.enabled
                        ? root.disabledTextColor
                        : headerHover.hovered
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
                            root.animationDuration
                    }
                }
            }

            // ----------------------------------------------------
            // SUBMENU ARROW
            // ----------------------------------------------------

            Text {
                id: submenuIndicator

                anchors.right:
                    parent.right

                anchors.rightMargin:
                    root.horizontalPadding

                anchors.verticalCenter:
                    parent.verticalCenter

                text:
                    root.hasSubmenu
                        ? root.submenuIcon
                        : ""

                visible:
                    root.hasSubmenu

                color:
                    root.enabled
                        ? (
                            headerHover.hovered
                                ? root.hoverTextColor
                                : "#657681"
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

            // ----------------------------------------------------
            // HOVER
            // ----------------------------------------------------

            HoverHandler {
                id: headerHover

                enabled:
                    root.enabled

                blocking: false

                onHoveredChanged: {
                    if (hovered)
                        root.openSubmenu()
                }
            }

            // ----------------------------------------------------
            // CLICK
            // ----------------------------------------------------

            MouseArea {
                anchors.fill: parent

                enabled:
                    root.enabled

                acceptedButtons:
                    Qt.LeftButton

                onClicked: {
                    root.activate()

                    if (root.hasSubmenu)
                        root.openSubmenu()
                }
            }
        }

        // ========================================================
        // CUSTOM CONTENT
        // ========================================================

        Column {
            id: body

            width:
                root.width > 0
                    ? root.width
                    : root.implicitWidth

            spacing:
                4

            visible:
                root.hasContent

            implicitWidth:
                childrenRect.width

            implicitHeight:
                childrenRect.height
        }
    }

    // ============================================================
    // DEBUG
    // ============================================================

    Component.onCompleted: {
        console.log(
            "[ContextMenuObj]",
            root.text,
            "created"
        )
    }
}