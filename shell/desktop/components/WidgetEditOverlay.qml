import QtQuick

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property bool editMode: false
    property bool selected: false

    property bool draggable: false
    property bool resizable: false

    property Item coordinateTarget: null

    /*
     * Extra area around the actual widget bounds.
     *
     * The overlay itself becomes larger than the widget so that
     * resize handles have real input space both inside and outside
     * the widget.
     */
    property real controlMargin: 18

    // ============================================================
    // APPEARANCE
    // ============================================================

    property color normalBorderColor: "#9b8aa8"
    property color selectedBorderColor: "#38d9ff"
    property color invalidBorderColor: "#ff405f"

    property color normalFillColor:
        Qt.rgba(0, 0, 0, 0)

    property color selectedFillColor:
        Qt.rgba(0.16, 0.78, 1.0, 0.10)

    property color invalidFillColor:
        Qt.rgba(1.0, 0.12, 0.20, 0.07)

    /*
     * Visible knob.
     */
    property real handleSize: 10

    /*
     * Actual mouse hitbox.
     *
     * This is the size of the invisible-but-interactive square.
     */
    property real handleHitboxSize: 34

    property bool invalid: false

    // ============================================================
    // SIGNAL API
    // ============================================================

    signal selectedRequest()

    signal dragStarted(
        real pointerX,
        real pointerY
    )

    signal dragMoved(
        real pointerX,
        real pointerY
    )

    signal dragFinished()

    signal resizeStarted(
        string handle,
        real pointerX,
        real pointerY
    )

    signal resizeMoved(
        string handle,
        real pointerX,
        real pointerY
    )

    signal resizeFinished(
        string handle
    )

    // ============================================================
    // OVERLAY GEOMETRY
    // ============================================================

    /*
     * The overlay is larger than the widget itself.
     *
     * The actual widget bounds live at:
     *
     *     x = controlMargin
     *     y = controlMargin
     *
     * Therefore resize hitboxes can extend to both sides of the
     * widget boundary.
     */
    x:
        -root.controlMargin

    y:
        -root.controlMargin

    width:
        parent
            ? parent.width +
              root.controlMargin * 2
            : 0

    height:
        parent
            ? parent.height +
              root.controlMargin * 2
            : 0

    visible:
        root.editMode

    clip: false

    // ============================================================
    // POINTER MAPPING
    // ============================================================

    function pointerInTarget(
        item,
        localX,
        localY
    ) {
        if (!root.coordinateTarget) {
            return {
                x: localX,
                y: localY
            }
        }

        return item.mapToItem(
            root.coordinateTarget,
            localX,
            localY
        )
    }

    // ============================================================
    // ACTUAL WIDGET BOUNDS
    // ============================================================

    Item {
        id: bounds

        x:
            root.controlMargin

        y:
            root.controlMargin

        width:
            root.parent
                ? root.parent.width
                : 0

        height:
            root.parent
                ? root.parent.height
                : 0

        // ========================================================
        // BOUNDING BOX
        // ========================================================

        Rectangle {
            anchors.fill: parent

            color:
                root.invalid
                    ? root.invalidFillColor
                    : (
                        root.selected
                            ? root.selectedFillColor
                            : root.normalFillColor
                    )

            border.width:
                root.invalid
                    ? 2
                    : (
                        root.selected
                            ? 2
                            : 1
                    )

            border.color:
                root.invalid
                    ? root.invalidBorderColor
                    : (
                        root.selected
                            ? root.selectedBorderColor
                            : root.normalBorderColor
                    )

            radius: 5

            antialiasing: true

            z: 0
        }

        // ========================================================
        // DRAG INPUT
        // ========================================================

        MouseArea {
            id: dragArea

            anchors.fill: parent

            enabled:
                root.editMode &&
                root.draggable

            acceptedButtons:
                Qt.LeftButton

            hoverEnabled: true

            preventStealing: true

            z: 10

            onPressed: function(mouse) {
                const p =
                    root.pointerInTarget(
                        dragArea,
                        mouse.x,
                        mouse.y
                    )

                root.selectedRequest()

                root.dragStarted(
                    p.x,
                    p.y
                )

                mouse.accepted = true
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return

                const p =
                    root.pointerInTarget(
                        dragArea,
                        mouse.x,
                        mouse.y
                    )

                root.dragMoved(
                    p.x,
                    p.y
                )
            }

            onReleased:
                root.dragFinished()

            onCanceled:
                root.dragFinished()
        }
    }

    // ============================================================
    // HANDLE DEFINITIONS
    // ============================================================

    property var handleDefinitions: [
        {
            name: "topLeft",
            x: 0.0,
            y: 0.0,
            cursor: Qt.SizeFDiagCursor
        },

        {
            name: "top",
            x: 0.5,
            y: 0.0,
            cursor: Qt.SizeVerCursor
        },

        {
            name: "topRight",
            x: 1.0,
            y: 0.0,
            cursor: Qt.SizeBDiagCursor
        },

        {
            name: "right",
            x: 1.0,
            y: 0.5,
            cursor: Qt.SizeHorCursor
        },

        {
            name: "bottomRight",
            x: 1.0,
            y: 1.0,
            cursor: Qt.SizeFDiagCursor
        },

        {
            name: "bottom",
            x: 0.5,
            y: 1.0,
            cursor: Qt.SizeVerCursor
        },

        {
            name: "bottomLeft",
            x: 0.0,
            y: 1.0,
            cursor: Qt.SizeBDiagCursor
        },

        {
            name: "left",
            x: 0.0,
            y: 0.5,
            cursor: Qt.SizeHorCursor
        }
    ]

    // ============================================================
    // RESIZE HANDLES
    // ============================================================

    Repeater {
        model:
            root.editMode &&
            root.selected &&
            root.resizable
                ? root.handleDefinitions
                : []

        delegate: Item {
            id: handle

            required property var modelData

            readonly property string handleName:
                String(modelData.name)

            readonly property real anchorX:
                Number(modelData.x)

            readonly property real anchorY:
                Number(modelData.y)

            /*
             * The hitbox lives around the widget edge, not around
             * the oversized overlay edge.
             */
            width:
                root.handleHitboxSize

            height:
                root.handleHitboxSize

            x:
                root.controlMargin +
                anchorX * bounds.width -
                width * 0.5

            y:
                root.controlMargin +
                anchorY * bounds.height -
                height * 0.5

            z: 1000

            MouseArea {
                id: handleMouse

                anchors.fill: parent

                acceptedButtons:
                    Qt.LeftButton

                hoverEnabled: true

                preventStealing: true

                cursorShape:
                    modelData.cursor

                onPressed: function(mouse) {
                    const p =
                        root.pointerInTarget(
                            handleMouse,
                            mouse.x,
                            mouse.y
                        )

                    root.selectedRequest()

                    root.resizeStarted(
                        handle.handleName,
                        p.x,
                        p.y
                    )

                    mouse.accepted = true
                }

                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return

                    const p =
                        root.pointerInTarget(
                            handleMouse,
                            mouse.x,
                            mouse.y
                        )

                    root.resizeMoved(
                        handle.handleName,
                        p.x,
                        p.y
                    )
                }

                onReleased:
                    root.resizeFinished(
                        handle.handleName
                    )

                onCanceled:
                    root.resizeFinished(
                        handle.handleName
                    )
            }

            /*
             * The visible knob is centered in its larger hitbox.
             */
            Rectangle {
                anchors.centerIn: parent

                width:
                    root.handleSize

                height:
                    root.handleSize

                radius:
                    width * 0.5

                color:
                    root.invalid
                        ? root.invalidBorderColor
                        : root.selectedBorderColor

                border.width: 1
                border.color: "#e9fbff"

                enabled: false

                z: 10
            }
        }
    }
}