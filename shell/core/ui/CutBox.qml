import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property var cut: ({})
    property var round: ({})

    property color bgColor: "transparent"

    property int borderWidth: 0
    property color borderColor: "transparent"
    property int borderGlow: 0

    property var disableBorder: ({})

    property bool interactive: true
    /*
        Minimum time between emitted scroll signals.

        500  = max ~2 emitted scrolls/sec
        1000 = max 1 emitted scroll/sec
        250  = max ~4 emitted scrolls/sec
    */
    property int scrollThreshold: 500
    property real lastScrollTime: -Infinity

    /*
        Example:

        shadow: ({
            out: {
                color: "#000000",
                intensity: 16,
                opacity: 0.45
            },

            in: {
                color: "#ffffff",
                intensity: 10,
                opacity: 0.35
            }
        })
    */

    property var shadow: ({})


    // ============================================================
    // ANIMATION
    //
    // Duration for every color / glow / shadow transition.
    // Consumers toggle values freely (hover, active, mode) and
    // the change eases instead of snapping.
    // ============================================================

    property int animationDuration: 180


    // ============================================================
    // CONTENT
    // ============================================================

    // ============================================================
    // CONTENT
    // ============================================================

    default property alias contentData: content.data


    // ============================================================
    // SIGNAL API
    // ============================================================

    signal clicked(var mouse)
    signal rightClicked(var mouse)
    signal doubleClicked(var mouse)

    signal hovered()
    signal exited()

    signal pressed(var mouse)
    signal released(var mouse)

    /*
        +1 = scroll up
        -1 = scroll down
    */
    signal scroll(int scroll)

    signal positionChanged(var mouse)

    // ============================================================
    // CORNER HELPERS
    // ============================================================

    function hasCut(corner) {
        return cut &&
               cut[corner] !== undefined
    }

    function hasRound(corner) {
        return round &&
               round[corner] !== undefined
    }

    /*
        round overrides cut.
    */

    function cornerType(corner) {

        if (hasRound(corner))
            return "round"

        if (hasCut(corner))
            return "cut"

        return "none"
    }


    function cornerSize(corner) {

        if (hasRound(corner))
            return Math.max(
                0,
                Number(round[corner])
            )

        if (hasCut(corner))
            return Math.max(
                0,
                Number(cut[corner])
            )

        return 0
    }


    function borderDisabled(side) {

        if (!disableBorder)
            return false


        if (Array.isArray(disableBorder))
            return disableBorder.indexOf(side) !== -1


        if (typeof disableBorder === "string")
            return disableBorder === side


        if (typeof disableBorder === "object")
            return disableBorder[side] === true


        return false
    }


    /*
        A corner transition belongs to exactly one active side.
    */

    function ownsCorner(side, corner) {

        if (corner === "topLeft") {

            if (!borderDisabled("top"))
                return side === "top"

            if (!borderDisabled("left"))
                return side === "left"

            return false
        }


        if (corner === "topRight") {

            if (!borderDisabled("right"))
                return side === "right"

            if (!borderDisabled("top"))
                return side === "top"

            return false
        }


        if (corner === "bottomRight") {

            if (!borderDisabled("bottom"))
                return side === "bottom"

            if (!borderDisabled("right"))
                return side === "right"

            return false
        }


        if (corner === "bottomLeft") {

            if (!borderDisabled("left"))
                return side === "left"

            if (!borderDisabled("bottom"))
                return side === "bottom"

            return false
        }


        return false
    }


    /*
        Generates the corner transition in clockwise order.
    */

    function cornerTransition(corner, g) {

        var size = 0


        if (corner === "topLeft")
            size = g.tl

        else if (corner === "topRight")
            size = g.tr

        else if (corner === "bottomRight")
            size = g.br

        else if (corner === "bottomLeft")
            size = g.bl


        if (size <= 0)
            return ""


        var type = cornerType(corner)


        // --------------------------------------------------------
        // TOP LEFT
        // --------------------------------------------------------

        if (corner === "topLeft") {

            if (type === "cut") {

                return (
                    "L " +
                    size +
                    " 0 "
                )
            }


            if (type === "round") {

                return (
                    "A " +
                    size +
                    " " +
                    size +
                    " 0 0 1 " +
                    size +
                    " 0 "
                )
            }
        }


        // --------------------------------------------------------
        // TOP RIGHT
        // --------------------------------------------------------

        if (corner === "topRight") {

            if (type === "cut") {

                return (
                    "L " +
                    width +
                    " " +
                    size +
                    " "
                )
            }


            if (type === "round") {

                return (
                    "A " +
                    size +
                    " " +
                    size +
                    " 0 0 1 " +
                    width +
                    " " +
                    size +
                    " "
                )
            }
        }


        // --------------------------------------------------------
        // BOTTOM RIGHT
        // --------------------------------------------------------

        if (corner === "bottomRight") {

            if (type === "cut") {

                return (
                    "L " +
                    (width - size) +
                    " " +
                    height +
                    " "
                )
            }


            if (type === "round") {

                return (
                    "A " +
                    size +
                    " " +
                    size +
                    " 0 0 1 " +
                    (width - size) +
                    " " +
                    height +
                    " "
                )
            }
        }


        // --------------------------------------------------------
        // BOTTOM LEFT
        // --------------------------------------------------------

        if (corner === "bottomLeft") {

            if (type === "cut") {

                return (
                    "L 0 " +
                    (height - size) +
                    " "
                )
            }


            if (type === "round") {

                return (
                    "A " +
                    size +
                    " " +
                    size +
                    " 0 0 1 0 " +
                    (height - size) +
                    " "
                )
            }
        }


        return ""
    }


    // ============================================================
    // GEOMETRY
    // ============================================================

    function geometry() {

        var tl = cornerSize("topLeft")
        var tr = cornerSize("topRight")
        var br = cornerSize("bottomRight")
        var bl = cornerSize("bottomLeft")


        tl = Math.min(
            tl,
            width / 2,
            height / 2
        )

        tr = Math.min(
            tr,
            width / 2,
            height / 2
        )

        br = Math.min(
            br,
            width / 2,
            height / 2
        )

        bl = Math.min(
            bl,
            width / 2,
            height / 2
        )


        var top = tl + tr

        if (top > width) {

            var ft = width / top

            tl *= ft
            tr *= ft
        }


        var bottom = bl + br

        if (bottom > width) {

            var fb = width / bottom

            bl *= fb
            br *= fb
        }


        var left = tl + bl

        if (left > height) {

            var fl = height / left

            tl *= fl
            bl *= fl
        }


        var right = tr + br

        if (right > height) {

            var fr = height / right

            tr *= fr
            br *= fr
        }


        return {
            tl: tl,
            tr: tr,
            br: br,
            bl: bl
        }
    }


    // ============================================================
    // MAIN CUTBOX PATH
    //
    // offsetX / offsetY are used only when a copy of the
    // geometry needs to be placed inside another coordinate space.
    // ============================================================

    function makePath(offsetX, offsetY) {

        offsetX =
            offsetX === undefined
                ? 0
                : offsetX

        offsetY =
            offsetY === undefined
                ? 0
                : offsetY


        var g = geometry()

        var tl = g.tl
        var tr = g.tr
        var br = g.br
        var bl = g.bl


        var ox = offsetX
        var oy = offsetY


        var p = ""


        // --------------------------------------------------------
        // TOP LEFT
        // --------------------------------------------------------

        if (cornerType("topLeft") === "none") {

            p +=
                "M " +
                ox +
                " " +
                oy +
                " "

        } else {

            p +=
                "M " +
                (ox + tl) +
                " " +
                oy +
                " "
        }


        // --------------------------------------------------------
        // TOP EDGE
        // --------------------------------------------------------

        if (cornerType("topRight") === "none") {

            p +=
                "L " +
                (ox + width) +
                " " +
                oy +
                " "

        } else {

            p +=
                "L " +
                (ox + width - tr) +
                " " +
                oy +
                " "
        }


        // --------------------------------------------------------
        // TOP RIGHT
        // --------------------------------------------------------

        if (cornerType("topRight") === "cut") {

            p +=
                "L " +
                (ox + width) +
                " " +
                (oy + tr) +
                " "

        } else if (
            cornerType("topRight") === "round"
        ) {

            p +=
                "A " +
                tr +
                " " +
                tr +
                " 0 0 1 " +
                (ox + width) +
                " " +
                (oy + tr) +
                " "

        } else {

            p +=
                "L " +
                (ox + width) +
                " " +
                oy +
                " "
        }


        // --------------------------------------------------------
        // RIGHT EDGE
        // --------------------------------------------------------

        if (
            cornerType("bottomRight") === "none"
        ) {

            p +=
                "L " +
                (ox + width) +
                " " +
                (oy + height) +
                " "

        } else {

            p +=
                "L " +
                (ox + width) +
                " " +
                (oy + height - br) +
                " "
        }


        // --------------------------------------------------------
        // BOTTOM RIGHT
        // --------------------------------------------------------

        if (
            cornerType("bottomRight") === "cut"
        ) {

            p +=
                "L " +
                (ox + width - br) +
                " " +
                (oy + height) +
                " "

        } else if (
            cornerType("bottomRight") === "round"
        ) {

            p +=
                "A " +
                br +
                " " +
                br +
                " 0 0 1 " +
                (ox + width - br) +
                " " +
                (oy + height) +
                " "

        } else {

            p +=
                "L " +
                (ox + width) +
                " " +
                (oy + height) +
                " "
        }


        // --------------------------------------------------------
        // BOTTOM EDGE
        // --------------------------------------------------------

        if (
            cornerType("bottomLeft") === "none"
        ) {

            p +=
                "L " +
                ox +
                " " +
                (oy + height) +
                " "

        } else {

            p +=
                "L " +
                (ox + bl) +
                " " +
                (oy + height) +
                " "
        }


        // --------------------------------------------------------
        // BOTTOM LEFT
        // --------------------------------------------------------

        if (
            cornerType("bottomLeft") === "cut"
        ) {

            p +=
                "L " +
                ox +
                " " +
                (oy + height - bl) +
                " "

        } else if (
            cornerType("bottomLeft") === "round"
        ) {

            p +=
                "A " +
                bl +
                " " +
                bl +
                " 0 0 1 " +
                ox +
                " " +
                (oy + height - bl) +
                " "

        } else {

            p +=
                "L " +
                ox +
                " " +
                (oy + height) +
                " "
        }


        // --------------------------------------------------------
        // LEFT EDGE
        // --------------------------------------------------------

        if (
            cornerType("topLeft") === "none"
        ) {

            p +=
                "L " +
                ox +
                " " +
                oy +
                " "

        } else {

            p +=
                "L " +
                ox +
                " " +
                (oy + tl) +
                " "
        }


        // --------------------------------------------------------
        // TOP LEFT
        // --------------------------------------------------------

        if (
            cornerType("topLeft") === "cut"
        ) {

            p +=
                "L " +
                (ox + tl) +
                " " +
                oy +
                " "

        } else if (
            cornerType("topLeft") === "round"
        ) {

            p +=
                "A " +
                tl +
                " " +
                tl +
                " 0 0 1 " +
                (ox + tl) +
                " " +
                oy +
                " "

        } else {

            p +=
                "L " +
                ox +
                " " +
                oy +
                " "
        }


        p += "Z"

        return p
    }


    // ============================================================
    // EXPANDED PATH
    //
    // Used ONLY by the inner-shadow source.
    //
    // The actual CutBox is still width x height.
    // No margin is added to root.
    //
    // The expanded contour is outside the real shape.
    // ============================================================

    function makeExpandedPath(pad) {

        var g = geometry()


        /*
            Expanded dimensions.

            The shadow source lives in the same coordinate space
            as root, so it is allowed to extend beyond 0..width
            and 0..height.
        */

        var x0 = -pad
        var y0 = -pad

        var w = width + pad * 2
        var h = height + pad * 2


        /*
            Rounded corners naturally grow with the offset.
        */

        var tl = g.tl + pad
        var tr = g.tr + pad
        var br = g.br + pad
        var bl = g.bl + pad


        /*
            Prevent pathological geometry.
        */

        tl = Math.min(
            tl,
            w / 2,
            h / 2
        )

        tr = Math.min(
            tr,
            w / 2,
            h / 2
        )

        br = Math.min(
            br,
            w / 2,
            h / 2
        )

        bl = Math.min(
            bl,
            w / 2,
            h / 2
        )


        var p = ""


        // --------------------------------------------------------
        // TOP LEFT
        // --------------------------------------------------------

        if (cornerType("topLeft") === "none") {

            p +=
                "M " +
                x0 +
                " " +
                y0 +
                " "

        } else {

            p +=
                "M " +
                (x0 + tl) +
                " " +
                y0 +
                " "
        }


        // --------------------------------------------------------
        // TOP
        // --------------------------------------------------------

        if (cornerType("topRight") === "none") {

            p +=
                "L " +
                (x0 + w) +
                " " +
                y0 +
                " "

        } else {

            p +=
                "L " +
                (x0 + w - tr) +
                " " +
                y0 +
                " "
        }


        // --------------------------------------------------------
        // TOP RIGHT
        // --------------------------------------------------------

        if (cornerType("topRight") === "cut") {

            p +=
                "L " +
                (x0 + w) +
                " " +
                (y0 + tr) +
                " "

        } else if (
            cornerType("topRight") === "round"
        ) {

            p +=
                "A " +
                tr +
                " " +
                tr +
                " 0 0 1 " +
                (x0 + w) +
                " " +
                (y0 + tr) +
                " "

        } else {

            p +=
                "L " +
                (x0 + w) +
                " " +
                y0 +
                " "
        }


        // --------------------------------------------------------
        // RIGHT
        // --------------------------------------------------------

        if (
            cornerType("bottomRight") === "none"
        ) {

            p +=
                "L " +
                (x0 + w) +
                " " +
                (y0 + h) +
                " "

        } else {

            p +=
                "L " +
                (x0 + w) +
                " " +
                (y0 + h - br) +
                " "
        }


        // --------------------------------------------------------
        // BOTTOM RIGHT
        // --------------------------------------------------------

        if (
            cornerType("bottomRight") === "cut"
        ) {

            p +=
                "L " +
                (x0 + w - br) +
                " " +
                (y0 + h) +
                " "

        } else if (
            cornerType("bottomRight") === "round"
        ) {

            p +=
                "A " +
                br +
                " " +
                br +
                " 0 0 1 " +
                (x0 + w - br) +
                " " +
                (y0 + h) +
                " "

        } else {

            p +=
                "L " +
                (x0 + w) +
                " " +
                (y0 + h) +
                " "
        }


        // --------------------------------------------------------
        // BOTTOM
        // --------------------------------------------------------

        if (
            cornerType("bottomLeft") === "none"
        ) {

            p +=
                "L " +
                x0 +
                " " +
                (y0 + h) +
                " "

        } else {

            p +=
                "L " +
                (x0 + bl) +
                " " +
                (y0 + h) +
                " "
        }


        // --------------------------------------------------------
        // BOTTOM LEFT
        // --------------------------------------------------------

        if (
            cornerType("bottomLeft") === "cut"
        ) {

            p +=
                "L " +
                x0 +
                " " +
                (y0 + h - bl) +
                " "

        } else if (
            cornerType("bottomLeft") === "round"
        ) {

            p +=
                "A " +
                bl +
                " " +
                bl +
                " 0 0 1 " +
                x0 +
                " " +
                (y0 + h - bl) +
                " "

        } else {

            p +=
                "L " +
                x0 +
                " " +
                (y0 + h) +
                " "
        }


        // --------------------------------------------------------
        // LEFT
        // --------------------------------------------------------

        if (
            cornerType("topLeft") === "none"
        ) {

            p +=
                "L " +
                x0 +
                " " +
                y0 +
                " "

        } else {

            p +=
                "L " +
                x0 +
                " " +
                (y0 + tl) +
                " "
        }


        // --------------------------------------------------------
        // CLOSE
        // --------------------------------------------------------

        if (
            cornerType("topLeft") === "cut"
        ) {

            p +=
                "L " +
                (x0 + tl) +
                " " +
                y0 +
                " "

        } else if (
            cornerType("topLeft") === "round"
        ) {

            p +=
                "A " +
                tl +
                " " +
                tl +
                " 0 0 1 " +
                (x0 + tl) +
                " " +
                y0 +
                " "

        } else {

            p +=
                "L " +
                x0 +
                " " +
                y0 +
                " "
        }


        p += "Z"

        return p
    }


    // ============================================================
    // BORDER PATH
    // ============================================================

    function borderPath(side) {

        if (borderDisabled(side))
            return ""


        var g = geometry()

        var tl = g.tl
        var tr = g.tr
        var br = g.br
        var bl = g.bl

        var p = ""


        // ========================================================
        // TOP
        // ========================================================

        if (side === "top") {

            var ownTL =
                ownsCorner(
                    "top",
                    "topLeft"
                )

            var ownTR =
                ownsCorner(
                    "top",
                    "topRight"
                )


            if (ownTL) {

                p =
                    "M 0 " +
                    tl +
                    " "

                p +=
                    cornerTransition(
                        "topLeft",
                        g
                    )

            } else {

                p =
                    "M " +
                    tl +
                    " 0 "
            }


            p +=
                "L " +
                (width - tr) +
                " 0 "


            if (ownTR) {

                p +=
                    cornerTransition(
                        "topRight",
                        g
                    )
            }


            return p
        }


        // ========================================================
        // RIGHT
        // ========================================================

        if (side === "right") {

            var ownTRight =
                ownsCorner(
                    "right",
                    "topRight"
                )

            var ownBRight =
                ownsCorner(
                    "right",
                    "bottomRight"
                )


            if (ownTRight) {

                p =
                    "M " +
                    (width - tr) +
                    " 0 "

                p +=
                    cornerTransition(
                        "topRight",
                        g
                    )

            } else {

                p =
                    "M " +
                    width +
                    " " +
                    tr +
                    " "
            }


            p +=
                "L " +
                width +
                " " +
                (height - br) +
                " "


            if (ownBRight) {

                p +=
                    cornerTransition(
                        "bottomRight",
                        g
                    )
            }


            return p
        }


        // ========================================================
        // BOTTOM
        // ========================================================

        if (side === "bottom") {

            var ownBR =
                ownsCorner(
                    "bottom",
                    "bottomRight"
                )

            var ownBL =
                ownsCorner(
                    "bottom",
                    "bottomLeft"
                )


            if (ownBR) {

                p =
                    "M " +
                    width +
                    " " +
                    (height - br) +
                    " "

                p +=
                    cornerTransition(
                        "bottomRight",
                        g
                    )

            } else {

                p =
                    "M " +
                    (width - br) +
                    " " +
                    height +
                    " "
            }


            p +=
                "L " +
                bl +
                " " +
                height +
                " "


            if (ownBL) {

                p +=
                    cornerTransition(
                        "bottomLeft",
                        g
                    )
            }


            return p
        }


        // ========================================================
        // LEFT
        // ========================================================

        if (side === "left") {

            var ownBLft =
                ownsCorner(
                    "left",
                    "bottomLeft"
                )

            var ownTLft =
                ownsCorner(
                    "left",
                    "topLeft"
                )


            if (ownBLft) {

                p =
                    "M " +
                    bl +
                    " " +
                    height +
                    " "

                p +=
                    cornerTransition(
                        "bottomLeft",
                        g
                    )

            } else {

                p =
                    "M 0 " +
                    (height - bl) +
                    " "
            }


            p +=
                "L 0 " +
                tl +
                " "


            if (ownTLft) {

                p +=
                    cornerTransition(
                        "topLeft",
                        g
                    )
            }


            return p
        }


        return ""
    }


    // ============================================================
    // OUTER SHADOW
    // ============================================================

    Shape {
        id: outerShadow

        anchors.fill: parent

        visible:
            root.shadow &&
            root.shadow.out !== undefined

        layer.enabled: visible

        layer.effect: MultiEffect {

            shadowEnabled: true

            shadowColor:
                root.shadow.out.color !== undefined
                    ? root.shadow.out.color
                    : "#000000"

            shadowOpacity:
                root.shadow.out.opacity !== undefined
                    ? Number(
                        root.shadow.out.opacity
                    )
                    : 0.5

            shadowBlur: 1.0

            blurMax:
                root.shadow.out.intensity !== undefined
                    ? Math.max(
                        1,
                        Number(
                            root.shadow.out.intensity
                        )
                    )
                    : 16

            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0

            autoPaddingEnabled: true


            Behavior on shadowColor {
                ColorAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.OutCubic
                }
            }


            Behavior on shadowOpacity {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.OutCubic
                }
            }


            Behavior on blurMax {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.OutCubic
                }
            }
        }


        ShapePath {

            fillColor:
                root.bgColor

            strokeColor:
                "transparent"

            PathSvg {
                path:
                    root.makePath()
            }
        }
    }


    // ============================================================
    // MAIN SURFACE
    // ============================================================

    Shape {
        id: shape

        anchors.fill: parent

        antialiasing: true

        layer.enabled: true

        ShapePath {
            id: shapePath

            fillColor:
                root.bgColor

            strokeColor:
                "transparent"

            strokeWidth: 0

            joinStyle:
                ShapePath.RoundJoin

            PathSvg {
                path:
                    root.makePath()
            }
        }
    }


    // ============================================================
    // INNER SHADOW
    //
    // IMPORTANT:
    //
    // The source is an OUTER RING.
    //
    //       ┌───────────────────┐
    //       │ █████████████████ │
    //       │ █ ┌─────────────┐ │
    //       │ █ │   CUTBOX    │ │
    //       │ █ └─────────────┘ │
    //       │ █████████████████ │
    //       └───────────────────┘
    //
    // The source itself never occupies the real CutBox interior.
    //
    // MultiEffect therefore has no visible source to leak into
    // the component. Its blurred shadow from the INNER edge of
    // the ring travels inward.
    //
    // The final output is additionally masked by "shape".
    //
    // No margin is added to root.
    // ============================================================

    // ============================================================
    // INNER SHADOW / INNER GLOW
    // ============================================================
    
    Item {
        id: innerShadow
    
        anchors.fill: parent
    
        visible:
            root.shadow &&
            root.shadow["in"] !== undefined
    
        readonly property real shadowSize:
            root.shadow["in"] &&
            root.shadow["in"].intensity !== undefined
                ? Math.max(
                    1,
                    Number(root.shadow["in"].intensity)
                )
                : 8
    
        readonly property color shadowColor:
            root.shadow["in"] &&
            root.shadow["in"].color !== undefined
                ? root.shadow["in"].color
                : "#ffffff"
    
        readonly property real shadowOpacity:
            root.shadow["in"] &&
            root.shadow["in"].opacity !== undefined
                ? Math.max(
                    0,
                    Math.min(
                        1,
                        Number(root.shadow["in"].opacity)
                    )
                )
                : 0.35
    
    
        // ========================================================
        // INVISIBLE EDGE SOURCE
        //
        // IMPORTANT:
        // This is NOT the visible border.
        //
        // It is only a 1px alpha source for MultiEffect.
        // The source itself is invisible.
        //
        // Because it follows makePath(), the shadow follows
        // the exact CutBox geometry.
        // ========================================================
    
        Shape {
            id: innerShadowSource
        
            anchors.fill: parent
        
            visible: false
        
            antialiasing: true
        
            // ========================================================
            // TOP
            // ========================================================
        
            ShapePath {
                fillColor: "transparent"
        
                strokeColor: "#ffffff"
                strokeWidth: 2
        
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
        
                PathSvg {
                    path: root.borderPath("top")
                }
            }
        
        
            // ========================================================
            // RIGHT
            // ========================================================
        
            ShapePath {
                fillColor: "transparent"
        
                strokeColor: "#ffffff"
                strokeWidth: 2
        
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
        
                PathSvg {
                    path: root.borderPath("right")
                }
            }
        
        
            // ========================================================
            // BOTTOM
            // ========================================================
        
            ShapePath {
                fillColor: "transparent"
        
                strokeColor: "#ffffff"
                strokeWidth: 2
        
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
        
                PathSvg {
                    path: root.borderPath("bottom")
                }
            }
        
        
            // ========================================================
            // LEFT
            // ========================================================
        
            ShapePath {
                fillColor: "transparent"
        
                strokeColor: "#ffffff"
                strokeWidth: 2
        
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
        
                PathSvg {
                    path: root.borderPath("left")
                }
            }
        }
    
    
        // ========================================================
        // INNER SHADOW EFFECT
        // ========================================================
    
        MultiEffect {
            id: innerShadowEffect
    
            anchors.fill: parent
    
            source: innerShadowSource
    
            visible: innerShadow.visible
    
    
            // ----------------------------------------------------
            // Shadow
            // ----------------------------------------------------
    
            shadowEnabled: true
    
            shadowColor:
                innerShadow.shadowColor
    
            shadowOpacity:
                innerShadow.shadowOpacity
    
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
    
    
            /*
             * This controls the thickness of the cloud.
             *
             * Small intensity:
             *     thin / sharp inner glow
             *
             * Large intensity:
             *     wide / soft inner glow
             */
            shadowBlur: 1.0
    
            blurMax:
                innerShadow.shadowSize
    
    
            // ----------------------------------------------------
            // Shadow transitions
            // ----------------------------------------------------
    
            Behavior on shadowColor {
                ColorAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.OutCubic
                }
            }
    
    
            Behavior on shadowOpacity {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.OutCubic
                }
            }
    
    
            Behavior on blurMax {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.OutCubic
                }
            }
    
    
            // ----------------------------------------------------
            // MASK TO ACTUAL CUTBOX
            // ----------------------------------------------------
    
            maskEnabled: true
    
            maskSource: shape
    
            maskInverted: false
    
            maskThresholdMin: 0.0
            maskThresholdMax: 1.0
    
            maskSpreadAtMin: 0.0
            maskSpreadAtMax: 0.0
    
    
            // ----------------------------------------------------
            // DO NOT LET THE EFFECT EXPAND THE ITEM
            // ----------------------------------------------------
    
            autoPaddingEnabled: false
    
            paddingRect: Qt.rect(
                0,
                0,
                0,
                0
            )
        }
    }


    // ============================================================
    // BORDER + BORDER GLOW
    //
    // Rendered after inner shadow.
    // ============================================================

    Shape {
        id: borderGlowShape

        anchors.fill: parent

        visible:
            root.borderWidth > 0

        antialiasing: true


        layer.enabled:
            visible &&
            root.borderGlow > 0


        layer.effect: MultiEffect {

            shadowEnabled:
                root.borderGlow > 0

            shadowColor:
                root.borderColor

            shadowOpacity:
                1.0

            shadowBlur:
                1.0

            blurMax:
                Math.max(
                    1,
                    root.borderGlow
                )

            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0

            autoPaddingEnabled: true
        }


        // ========================================================
        // TOP
        // ========================================================

        ShapePath {

            fillColor:
                "transparent"

            strokeColor:
                root.borderColor

            strokeWidth:
                root.borderWidth

            capStyle:
                ShapePath.FlatCap

            joinStyle:
                ShapePath.RoundJoin

            PathSvg {
                path:
                    root.borderPath("top")
            }
        }


        // ========================================================
        // RIGHT
        // ========================================================

        ShapePath {

            fillColor:
                "transparent"

            strokeColor:
                root.borderColor

            strokeWidth:
                root.borderWidth

            capStyle:
                ShapePath.FlatCap

            joinStyle:
                ShapePath.RoundJoin

            PathSvg {
                path:
                    root.borderPath("right")
            }
        }


        // ========================================================
        // BOTTOM
        // ========================================================

        ShapePath {

            fillColor:
                "transparent"

            strokeColor:
                root.borderColor

            strokeWidth:
                root.borderWidth

            capStyle:
                ShapePath.FlatCap

            joinStyle:
                ShapePath.RoundJoin

            PathSvg {
                path:
                    root.borderPath("bottom")
            }
        }


        // ========================================================
        // LEFT
        // ========================================================

        ShapePath {

            fillColor:
                "transparent"

            strokeColor:
                root.borderColor

            strokeWidth:
                root.borderWidth

            capStyle:
                ShapePath.FlatCap

            joinStyle:
                ShapePath.RoundJoin

            PathSvg {
                path:
                    root.borderPath("left")
            }
        }
    }


    // ============================================================
    // CONTENT
    // ============================================================

    Item {
        id: content

        anchors.fill: parent
    }


    // ============================================================
    // INPUT
    // ============================================================

    MouseArea {
        id: mouseArea
    
        anchors.fill: parent
    
        /*
            IMPORTANT
    
            The MouseArea belongs below the CutBox content.
    
            This allows nested interactive components
            such as Slider / Button to receive the mouse.
    
            A standalone CutBox still works because its
            MouseArea remains the only interactive child.
        */
        z: -1
    
        enabled:
            root.interactive
    
        hoverEnabled: true
    
        preventStealing: true
    
        acceptedButtons:
            Qt.LeftButton |
            Qt.RightButton
    
    
        onEntered: {
            root.hovered()
        }
    
    
        onExited: {
            root.exited()
        }
    
    
        onPressed: function(mouse) {
            root.pressed(mouse)
        }
    
    
        onReleased: function(mouse) {
            root.released(mouse)
        }
    
    
        onPositionChanged: function(mouse) {
            root.positionChanged(mouse)
        }
    
    
        onClicked: function(mouse) {
    
            if (
                mouse.button ===
                Qt.RightButton
            ) {
    
                root.rightClicked(mouse)
    
            } else {
    
                root.clicked(mouse)
            }
        }
    
    
        onDoubleClicked: function(mouse) {
            root.doubleClicked(mouse)
        }
    
    
        onWheel: function(wheel) {
    
            var delta =
                wheel.angleDelta.y
    
    
            if (delta === 0)
                delta =
                    wheel.pixelDelta.y
    
    
            if (delta === 0)
                return
    
    
            var now =
                Date.now()
    
    
            if (
                now -
                root.lastScrollTime <
                Math.max(
                    0,
                    root.scrollThreshold
                )
            ) {
    
                wheel.accepted = true
    
                return
            }
    
    
            root.lastScrollTime =
                now
    
    
            var step =
                delta > 0
                    ? 1
                    : -1
    
    
            root.scroll(step)
    
            wheel.accepted = true
        }
    }


    // ============================================================
    // COLOR / GLOW TRANSITIONS
    //
    // The shape, border and glow effects all bind to the animated
    // property, so they follow the eased value frame by frame.
    // ============================================================

    Behavior on bgColor {
        ColorAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }


    Behavior on borderColor {
        ColorAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }


    Behavior on borderGlow {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }


    Behavior on borderWidth {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }


    // ============================================================
    // GEOMETRY UPDATES
    // ============================================================

    function updateGeometry() {

        /*
            The PathSvg binds directly to root.makePath(), so the
            path already tracks width / height / cut / round through
            the binding engine.

            QQuickShapePath.pathChanged() is not callable from JS
            in Qt 6.11, so there is nothing to force here.
        */
    }


    onWidthChanged:
        updateGeometry()

    onHeightChanged:
        updateGeometry()

    onCutChanged:
        updateGeometry()

    onRoundChanged:
        updateGeometry()

    onBgColorChanged:
        updateGeometry()

    onBorderColorChanged:
        updateGeometry()

    onBorderWidthChanged:
        updateGeometry()
}