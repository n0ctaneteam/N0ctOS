import QtQuick
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property string text: ""
    property string icon: ""

    property bool enabled: true

    /*
     * All non-visual actions may coexist.
     *
     * functionAction + process
     *     -> both execute
     *
     * submenu
     *     -> visual submenu only
     */
    property var functionAction: null
    property Process process: null
    property Component submenu: null

    /*
     * Normal action:
     *     true  -> action closes menu
     *     false -> menu stays open
     *
     * A submenu itself does not close merely because it was
     * opened; it is handled as a visual submenu.
     */
    property bool closeOnClick: true

    property string submenuIcon: ""

    property color normalTextColor: "#e8edf0"
    property color disabledTextColor: "#4b5963"
    property color hoverBackground: "#1a3039"
    property color hoverTextColor: "#2acfff"

    property int headerHeight: 36
    property int horizontalPadding: 10
    property int iconWidth: 24
    property int spacing: 8

    property int animationDuration: 140

    // Assigned automatically by ContextMenu.
    property var contextMenuInstance: null
    property int contextMenuDepth: 0
    property Item parentMenuObject: null

    readonly property bool hasSubmenu:
        root.submenu !== null

    readonly property bool hasContent:
        body.children.length > 0

    default property alias contentData: body.data

    // ============================================================
    // SIZE
    // ============================================================

    implicitWidth:
        Math.max(
            header.implicitWidth,
            body.implicitWidth
        ) +
        root.horizontalPadding * 2

    implicitHeight:
        header.height +
        (
            root.hasContent
                ? body.implicitHeight
                : 0
        )

    // ============================================================
    // ACTION
    // ============================================================

    function activate() {
        if (!root.enabled)
            return

        /*
         * Run every non-visual action that exists.
         */

        if (root.functionAction !== null) {
            if (typeof root.functionAction === "function") {
                try {
                    root.functionAction()
                } catch (e) {
                    console.warn(
                        "[ContextMenuObj] function failed:",
                        e
                    )
                }
            }
        }

        if (root.process) {
            if (!root.process.running)
                root.process.running = true
        }

        /*
         * A submenu is visual/navigation state rather than an
         * action. Do not execute it here.
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

        Item {
            id: header

            width: Math.max(
                root.width,
                root.implicitWidth
            )

            height: root.headerHeight

            implicitWidth:
                iconArea.width +
                root.spacing +
                textItem.implicitWidth +
                (
                    root.hasSubmenu
                        ? root.spacing +
                          submenuIndicator.width
                        : 0
                ) +
                root.horizontalPadding * 2

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

            Rectangle {
                id: iconArea

                x: root.horizontalPadding
                y: (height - iconSize) / 2

                width: root.iconWidth
                height: iconSize

                color: "transparent"

                readonly property real iconSize:
                    root.icon !== ""
                        ? 17
                        : 0

                Text {
                    anchors.centerIn: parent

                    text: root.icon

                    visible:
                        root.icon !== ""

                    color:
                        root.enabled
                            ? (
                                headerHover.hovered
                                    ? root.hoverTextColor
                                    : root.normalTextColor
                            )
                            : root.disabledTextColor

                    font.family:
                        "Symbols Nerd Font"

                    font.pixelSize:
                        iconArea.iconSize

                    Behavior on color {
                        ColorAnimation {
                            duration:
                                root.animationDuration
                        }
                    }
                }
            }

            Text {
                id: textItem

                x:
                    root.horizontalPadding +
                    (
                        root.icon !== ""
                            ? root.iconWidth +
                              root.spacing
                            : 0
                    )

                anchors.verticalCenter:
                    parent.verticalCenter

                text: root.text

                color:
                    root.enabled
                        ? (
                            headerHover.hovered
                                ? root.hoverTextColor
                                : root.normalTextColor
                        )
                        : root.disabledTextColor

                font.pixelSize: 12

                elide:
                    Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration:
                            root.animationDuration
                    }
                }
            }

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
                        ? "#657681"
                        : root.disabledTextColor

                font.family:
                    "Symbols Nerd Font"

                font.pixelSize: 12
            }

            HoverHandler {
                id: headerHover

                enabled: root.enabled
                blocking: false

                onHoveredChanged: {
                    if (hovered)
                        root.openSubmenu()
                }
            }

            MouseArea {
                anchors.fill: parent

                enabled: root.enabled

                acceptedButtons:
                    Qt.LeftButton

                onClicked: {
                    if (root.hasSubmenu) {
                        root.openSubmenu()
                        return
                    }

                    root.activate()
                }
            }
        }

        Column {
            id: body

            width: Math.max(
                root.width,
                childrenRect.width
            )

            spacing: 4

            visible:
                root.hasContent

            implicitWidth:
                childrenRect.width

            implicitHeight:
                childrenRect.height
        }
    }

    // ============================================================
    // RESIZE
    // ============================================================

    onWidthChanged:
        header.width = Math.max(
            width,
            root.implicitWidth
        )

    Component.onCompleted: {
        console.log(
            "[ContextMenuObj]",
            root.text,
            "created"
        )
    }
}