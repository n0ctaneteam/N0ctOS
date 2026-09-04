import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    property var frameLayer: WlrLayer.Bottom
    // ============================================================
    // PUBLIC API
    // ============================================================
    property var frameWidth: 5
    property var cut: ({})
    property var round: ({})
    property color frameColor: "#101820"
    property int borderWidth: 0
    property color borderColor: "white"
    property var shadows: ({
        intensity: 20,
        color: "#00ffff",
        blur: 1.0,
        opacity: 0.6
    })
    property real hoverDetectionSize:8
    property real extendedHoverDetectionSize:20
    property real blobWidth: 300
    property real blobHeight: 100
    property real blobMinMargin: 0
    property real blobAnimationDuration: 3000
    property var blobAnimationEasing: Easing.InOutExpo

    required property var moduleRegistry
    required property var blobManager
    required property var focusManager
    // ============================================================
    // SIGNAL API
    // ============================================================

    signal hoveredBLBlob() ; onHoveredBLBlob: {root.isBlBlobActive = true}
    signal hoveredBCBlob() ; onHoveredBCBlob: {root.isBcBlobActive = true}
    signal hoveredBRBlob() ; onHoveredBRBlob: {root.isBrBlobActive = true}
    signal hoveredTLBlob() ; onHoveredTLBlob: {root.isTlBlobActive = true}
    signal hoveredTCBlob() ; onHoveredTCBlob: {root.isTcBlobActive = true}
    signal hoveredTRBlob() ; onHoveredTRBlob: {root.isTrBlobActive = true}
    signal hoveredLEFTBlob() ; onHoveredLEFTBlob: {root.isLeftBlobActive = true}
    signal hoveredRIGHTBlob() ; onHoveredRIGHTBlob: {root.isRightBlobActive = true}

    signal exitedBLBlob() ; onExitedBLBlob: {root.isBlBlobActive = false}
    signal exitedBCBlob() ; onExitedBCBlob: {root.isBcBlobActive = false}
    signal exitedBRBlob() ; onExitedBRBlob: {root.isBrBlobActive = false}
    signal exitedTLBlob() ; onExitedTLBlob: {root.isTlBlobActive = false}
    signal exitedTCBlob() ; onExitedTCBlob: {root.isTcBlobActive = false}
    signal exitedTRBlob() ; onExitedTRBlob: {root.isTrBlobActive = false}
    signal exitedLEFTBlob() ; onExitedLEFTBlob: {root.isLeftBlobActive = false}
    signal exitedRIGHTBlob() ; onExitedRIGHTBlob: {root.isRightBlobActive = false}


    // ============================================================
    // BLOB STATE
    // ============================================================
    property real blBlobProgress: root.isBlBlobActive | root.isBlBlobAlwaysActive ? 1 : 0
    property real bcBlobProgress: root.isBcBlobActive | root.isBcBlobAlwaysActive ? 1 : 0
    property real brBlobProgress: root.isBrBlobActive | root.isBrBlobAlwaysActive ? 1 : 0
    property real trBlobProgress: root.isTrBlobActive | root.isTrBlobAlwaysActive ? 1 : 0
    property real tcBlobProgress: root.isTcBlobActive | root.isTcBlobAlwaysActive ? 1 : 0
    property real tlBlobProgress: root.isTlBlobActive | root.isTlBlobAlwaysActive ? 1 : 0
    property real leftBlobProgress: root.isLeftBlobActive | root.isLeftBlobAlwaysActive ? 1 : 0
    property real rightBlobProgress: root.isRightBlobActive | root.isRightBlobAlwaysActive ? 1 : 0

    property bool isBrBlobActive:false;    property bool isBrBlobAlwaysActive:false;    property bool isBrBlobShouldActive:false;
    property bool isBcBlobActive:false;    property bool isBcBlobAlwaysActive:false;    property bool isBcBlobShouldActive:false;
    property bool isBlBlobActive:false;    property bool isBlBlobAlwaysActive:false;    property bool isBlBlobShouldActive:false;
    property bool isTrBlobActive:false;    property bool isTrBlobAlwaysActive:false;    property bool isTrBlobShouldActive:false;
    property bool isTcBlobActive:false;    property bool isTcBlobAlwaysActive:false;    property bool isTcBlobShouldActive:false;
    property bool isTlBlobActive:false;    property bool isTlBlobAlwaysActive:false;    property bool isTlBlobShouldActive:false;
    property bool isLeftBlobActive:false;    property bool isLeftBlobAlwaysActive:false;    property bool isLeftBlobShouldActive:false;
    property bool isRightBlobActive:false;    property bool isRightBlobAlwaysActive:false;    property bool isRightBlobShouldActive:false;

    property bool shouldBrBlobReserveSpace:false;
    property bool shouldBcBlobReserveSpace:false;
    property bool shouldBlBlobReserveSpace:false;
    property bool shouldTrBlobReserveSpace:true;
    property bool shouldTcBlobReserveSpace:false;
    property bool shouldTlBlobReserveSpace:true;
    property bool shouldLeftBlobReserveSpace:false;
    property bool shouldRightBlobReserveSpace:false;

    // ================================
    // ANIMATION EASING
    // ================================
    Behavior on blBlobProgress {
        NumberAnimation {
            duration: root.blobAnimationDuration
            easing.type: root.blobAnimationEasing || Easing.InOutExpo
        }
    }
    Behavior on brBlobProgress{
        NumberAnimation {
            duration: root.blobAnimationDuration
            easing.type: Easing.InOutExpo
        }
    }
    Behavior on bcBlobProgress {
        NumberAnimation {
            duration: root.blobAnimationDuration
            easing.type: root.blobAnimationEasing || Easing.InOutExpo
        }
    }
    Behavior on tlBlobProgress {
        NumberAnimation {
            duration: root.blobAnimationDuration
            easing.type: root.blobAnimationEasing || Easing.InOutExpo
        }
    }
    Behavior on tcBlobProgress {
        NumberAnimation {
            duration: root.blobAnimationDuration
            easing.type: root.blobAnimationEasing || Easing.InOutExpo
        }
    }
    Behavior on trBlobProgress {
        NumberAnimation {
            duration: root.blobAnimationDuration
            easing.type: root.blobAnimationEasing || Easing.InOutExpo
        }
    }
    Behavior on leftBlobProgress {
        NumberAnimation {
            duration: root.blobAnimationDuration
            easing.type: root.blobAnimationEasing || Easing.InOutExpo
        }
    }
    Behavior on rightBlobProgress {
        NumberAnimation {
            duration: root.blobAnimationDuration
            easing.type: root.blobAnimationEasing || Easing.InOutExpo
        }
    }

    // ============================================================
    // VALUE HELPERS
    // ============================================================

    function sideValue(value, side) {

        if (typeof value === "number")
            return Math.max(
                0,
                Number(value)
            )


        if (
            value &&
            typeof value === "object" &&
            value[side] !== undefined
        ) {
            return Math.max(
                0,
                Number(value[side])
            )
        }


        return 0
    }
    function frameSide(side) {
        return sideValue(
            root.frameWidth,
            side
        )
    }

    // ============================================================
    // CORNER HELPERS
    // ============================================================
    function cornerExists(value, corner) {

        if (typeof value === "number")
            return true

        return (
            value &&
            typeof value === "object" &&
            value[corner] !== undefined
        )
    }
    function cornerType(corner) {

        /*
            round overrides cut.
        */

        if (
            cornerExists(
                root.round,
                corner
            )
        )
            return "round"


        if (
            cornerExists(
                root.cut,
                corner
            )
        )
            return "cut"


        return "none"
    }
    function cornerSize(corner) {

        if (
            typeof root.round === "number"
        ) {

            return Math.max(
                1,
                Number(root.round)
            )
        }


        if (
            root.round &&
            root.round[corner] !== undefined
        ) {

            return Math.max(
                1,
                Number(root.round[corner])
            )
        }


        if (
            typeof root.cut === "number"
        ) {

            return Math.max(
                1,
                Number(root.cut)
            )
        }


        if (
            root.cut &&
            root.cut[corner] !== undefined
        ) {

            return Math.max(
                1,
                Number(root.cut[corner])
            )
        }


        return 1
    }

    // ============================================================
    // INNER GEOMETRY
    // ============================================================
    function innerGeometry() {

        var left =
            frameSide("left")

        var right =
            frameSide("right")

        var top =
            frameSide("top")

        var bottom =
            frameSide("bottom")


        var w =
            Math.max(
                1,
                frameWindow.width -
                left -
                right
            )


        var h =
            Math.max(
                1,
                frameWindow.height -
                top -
                bottom
            )


        var tl =
            Math.min(
                cornerSize("topLeft"),
                w / 2,
                h / 2
            )

        var tr =
            Math.min(
                cornerSize("topRight"),
                w / 2,
                h / 2
            )

        var br =
            Math.min(
                cornerSize("bottomRight"),
                w / 2,
                h / 2
            )

        var bl =
            Math.min(
                cornerSize("bottomLeft"),
                w / 2,
                h / 2
            )


        /*
            Prevent neighboring corners
            from overlapping.
        */

        var horizontal =
            tl + tr

        if (horizontal > w) {

            var fx =
                w / horizontal

            tl *= fx
            tr *= fx
        }


        horizontal =
            bl + br

        if (horizontal > w) {

            var fb =
                w / horizontal

            bl *= fb
            br *= fb
        }


        var vertical =
            tl + bl

        if (vertical > h) {

            var fy =
                h / vertical

            tl *= fy
            bl *= fy
        }


        vertical =
            tr + br

        if (vertical > h) {

            var fr =
                h / vertical

            tr *= fr
            br *= fr
        }


        return {
            x: left,
            y: top,

            width: w,
            height: h,

            tl: tl,
            tr: tr,
            br: br,
            bl: bl
        }
    }

    // ============================================================
    // INNER PATH
    // ============================================================
    function innerPath() {
        var g =
            innerGeometry()
        var x =
            g.x
        var y =
            g.y
        var w =
            g.width
        var h =
            g.height
        var tl =
            g.tl
        var tr =
            g.tr
        var br =
            g.br
        var bl =
            g.bl
        var right =
            x + w
        var bottom =
            y + h


        // ========================================================
        // BLOB GEOMETRY
        // ========================================================
        // Bottom Right Blob
        var brNewRSlidingCorner = br * (1 - 0.5 * root.brBlobProgress)
        var brNewRInnerCorner =  Math.min(Math.max(0, Math.min(brBlobContent.width*0.5, br * 0.5)), (Math.max(brNewRSlidingCorner*root.brBlobProgress/2 , root.blobMinMargin*root.brBlobProgress)+brBlobContent.height)*0.5)
        var brNewREdgeCorner =  Math.min(Math.max(0, Math.min(brBlobContent.width*0.5, br * 0.5)), (Math.max(brNewRSlidingCorner*root.brBlobProgress/2 , root.blobMinMargin*root.brBlobProgress)+brBlobContent.height)*0.5)
        var brWidth = brBlobContent.width + Math.max(brNewRSlidingCorner*root.brBlobProgress/2 , root.blobMinMargin*root.brBlobProgress) - brNewRSlidingCorner*root.brBlobProgress*2
        var brHeight = brBlobContent.height + Math.max(brNewRSlidingCorner*root.brBlobProgress/2 , root.blobMinMargin*root.brBlobProgress)
        // Bottom left blob
        var blNewRSlidingCorner = bl * (1 - 0.5 * root.blBlobProgress)
        var blNewRInnerCorner =  Math.min(Math.max(0, Math.min(blBlobContent.width*0.5, bl * 0.5)), (Math.max(blNewRSlidingCorner*root.blBlobProgress/2 , root.blobMinMargin*root.blBlobProgress)+blBlobContent.height)*0.5)
        var blNewREdgeCorner =  Math.min(Math.max(0, Math.min(blBlobContent.width*0.5, bl * 0.5)), (Math.max(blNewRSlidingCorner*root.blBlobProgress/2 , root.blobMinMargin*root.blBlobProgress)+blBlobContent.height)*0.5)
        var blWidth = blBlobContent.width + Math.max(blNewRSlidingCorner*root.blBlobProgress/2 , root.blobMinMargin*root.blBlobProgress) - blNewRSlidingCorner*root.blBlobProgress
        var blHeight = blBlobContent.height + Math.max(blNewRSlidingCorner*root.blBlobProgress/2 , root.blobMinMargin*root.blBlobProgress)
        // Top Right Blob
        var trNewRSlidingCorner = tr * (1 - 0.5 * root.trBlobProgress)
        var trNewRInnerCorner =  Math.min(Math.max(0, Math.min(trBlobContent.width*0.5, tr * 0.5)), (Math.max(trNewRSlidingCorner*root.trBlobProgress/2 , root.blobMinMargin*root.trBlobProgress)+trBlobContent.height)*0.5)
        var trNewREdgeCorner =  Math.min(Math.max(0, Math.min(trBlobContent.width*0.5, tr * 0.5)), (Math.max(trNewRSlidingCorner*root.trBlobProgress/2 , root.blobMinMargin*root.trBlobProgress)+trBlobContent.height)*0.5)
        var trWidth = trBlobContent.width + Math.max(trNewRSlidingCorner*root.trBlobProgress/2 , root.blobMinMargin*root.trBlobProgress) - trNewRSlidingCorner*root.trBlobProgress
        var trHeight = trBlobContent.height + Math.max(trNewRSlidingCorner*root.trBlobProgress/2 , root.blobMinMargin*root.trBlobProgress)
        // Top Left Blob
        var tlNewRSlidingCorner = tl * (1 - 0.5 * root.tlBlobProgress)
        var tlNewRInnerCorner =  Math.min(Math.max(0, Math.min(tlBlobContent.width*0.5, tl * 0.5)), (Math.max(tlNewRSlidingCorner*root.tlBlobProgress/2 , root.blobMinMargin*root.tlBlobProgress)+tlBlobContent.height)*0.5)
        var tlNewREdgeCorner =  Math.min(Math.max(0, Math.min(tlBlobContent.width*0.5, tl * 0.5)), (Math.max(tlNewRSlidingCorner*root.tlBlobProgress/2 , root.blobMinMargin*root.tlBlobProgress)+tlBlobContent.height)*0.5)
        var tlWidth = tlBlobContent.width + Math.max(tlNewRSlidingCorner*root.tlBlobProgress/2 , root.blobMinMargin*root.tlBlobProgress) - tlNewRSlidingCorner*root.tlBlobProgress*2
        var tlHeight = tlBlobContent.height + Math.max(tlNewRSlidingCorner*root.tlBlobProgress/2 , root.blobMinMargin*root.tlBlobProgress)
        // Right Blob
        var rightStaticHeight = rightBlobContent.height / root.rightBlobProgress
        var rightStaticWidth = rightBlobContent.width / root.rightBlobProgress
        var rightAvgMargin = (Math.max(Math.max(0,Math.min(rightBlobContent.height*0.5,tr/4))+Math.max(0,Math.min(rightBlobContent.height*0.5,tl/4)),root.blobMinMargin)/2)*root.rightBlobProgress
        var rightNewRBottomCorners =Math.min(bl/2 , (rightAvgMargin + rightBlobContent.width)/2)
        var rightNewRTopCorners =  Math.min(tl/2 , (rightAvgMargin + rightBlobContent.width)/2)
        var rightWidth = rightBlobContent.width
        var rightHeight = rightBlobContent.height
        // Bottom Blob
        var bcStaticHeight=bcBlobContent.height/root.bcBlobProgress
        var bcStaticWidth=bcBlobContent.width/root.bcBlobProgress
        var bcAvgMargin=(Math.max(Math.max(0,Math.min(bcBlobContent.height*0.5,br/4))+Math.max(0,Math.min(bcBlobContent.height*0.5,bl/4)),root.blobMinMargin)/2)*root.bcBlobProgress
        var bcNewRRightCorners=Math.min(br/2 , (bcAvgMargin + bcBlobContent.height)/2)
        var bcNewRLeftCorners= Math.min(bl/2 , (bcAvgMargin + bcBlobContent.height)/2)
        var bcHeight=bcBlobContent.height
        var bcWidth=bcBlobContent.width
        // left Blob
        var leftStaticHeight = leftBlobContent.height / root.leftBlobProgress
        var leftStaticWidth = leftBlobContent.width / root.leftBlobProgress
        var leftAvgMargin = (Math.max(Math.max(0,Math.min(leftBlobContent.height*0.5,tr/4))+Math.max(0,Math.min(leftBlobContent.height*0.5,tl/4)),root.blobMinMargin)/2)*root.leftBlobProgress
        var leftNewRBottomCorners =Math.min(bl/2 , (leftAvgMargin + leftBlobContent.width)/2)
        var leftNewRTopCorners =  Math.min(tl/2 , (leftAvgMargin + leftBlobContent.width)/2)
        var leftWidth = leftBlobContent.width
        var leftHeight = leftBlobContent.height
        // Top Blob
        var tcStaticHeight=tcBlobContent.height/root.tcBlobProgress
        var tcStaticWidth=tcBlobContent.width/root.tcBlobProgress
        var tcAvgMargin=(Math.max(Math.max(0,Math.min(tcBlobContent.height*0.5,tr/4))+Math.max(0,Math.min(tcBlobContent.height*0.5,tl/4)),root.blobMinMargin)/2)*root.tcBlobProgress
        var tcNewRRightCorners=Math.min(tr/2 , (tcAvgMargin + tcBlobContent.height)/2)
        var tcNewRLeftCorners= Math.min(tl/2 , (tcAvgMargin + tcBlobContent.height)/2)
        var tcHeight=tcBlobContent.height
        var tcWidth=tcBlobContent.width


        var p = ""


        // ========================================================
        // START
        // ========================================================
        p +=
            "M " +
            (x + tl + tlWidth + tlNewRSlidingCorner) +
            " " +
            y +
            " "

        // =======================================================
        // TOP
        // =======================================================
          if(root.tcBlobProgress > 0){
            // come to start from right side
            p +=
              "L " +
              (x + (w - tcWidth)/2 -tcAvgMargin - tcNewRLeftCorners) +
              " " +
              y +
              " "
            // right to bottom corner
            if (cornerType("topLeft") ==="cut") {
              p +=
                  "l " +
                  tcNewRLeftCorners +
                  " " +
                  (tcNewRLeftCorners ) +
                  " "
            } 
            else {
              p +=
                  "a " +
                  tcNewRLeftCorners +
                  " " +
                  tcNewRLeftCorners  +
                  " 0 0 1 " +
                  tcNewRLeftCorners +
                  " " +
                  ( tcNewRLeftCorners ) +
                  " "
            }
            // left edge
            p +=
              "l " +
              0 +
              " " +
              (tcHeight - (tcNewRLeftCorners*4)/2 + tcAvgMargin) +
              " "
            // down to right corner
            if (cornerType("topLeft") ==="cut") {
              p +=
                  "l " +
                  tcNewRLeftCorners +
                  " " +
                  ( tcNewRLeftCorners ) +
                  " "
            } 
            else {
              p +=
                  "a " +
                  tcNewRLeftCorners +
                  " " +
                  tcNewRLeftCorners  +
                  " 0 0 0 " +
                  tcNewRLeftCorners +
                  " " +
                  ( tcNewRLeftCorners ) +
                  " "
            }
            // inner bottom edge
            p +=
                "l " +
                (tcAvgMargin*2 + tcWidth - tcNewRLeftCorners - tcNewRRightCorners) +
                " " +
                0 +
                " "
            // right to top corner
            if (cornerType("topRight") ==="cut") {
                p +=
                    "l " +
                    tcNewRRightCorners +
                    " " +
                    (- tcNewRRightCorners ) +
                    " "
            } 
            else {
                p +=
                    "a " +
                    tcNewRRightCorners +
                    " " +
                    tcNewRRightCorners  +
                    " 0 0 0 " +
                    tcNewRRightCorners +
                    " " +
                    ( -tcNewRRightCorners ) +
                    " "
            }
            // right edge
            p +=
                "l " +
                0 +
                " " +
                -(tcHeight - tcNewRRightCorners*2 + tcAvgMargin) +
                " "
            // top to right corner
            if (cornerType("topRight") ==="cut") {
                p +=
                    "l " +
                    tcNewRRightCorners +
                    " " +
                    ( -tcNewRRightCorners ) +
                    " "
            } 
            else {
                p +=
                    "a " +
                    tcNewRRightCorners +
                    " " +
                    tcNewRRightCorners  +
                    " 0 0 1 " +
                    tcNewRRightCorners +
                    " " +
                    ( -tcNewRRightCorners ) +
                    " "
            }
          }

        p +=
            "L " +
            (right - trWidth - trNewRSlidingCorner  - trNewRInnerCorner) +
            " " +
            (y) +
            " "

        // ========================================================
        // TOP RIGHT
        // ========================================================
            // top-bottom turn
            if (cornerType("topRight") ==="cut") {

            p +=
                "l " +
                (trNewREdgeCorner) +
                " " +
                trNewREdgeCorner +
                " "

            }
            else {
              
                p +=
                    "a " +
                    trNewREdgeCorner +
                    " " +
                    trNewREdgeCorner +
                    " 0 0 1 " +
                    trNewREdgeCorner +
                    " " +
                    trNewREdgeCorner +
                    " "
            }
            // left edge
            p +=
                "l " +
                0 +
                " " +
                (trHeight-trNewREdgeCorner-trNewRInnerCorner) +
                " "
            // inner corner
            if (cornerType("topRight") ==="cut") {
              
              p +=
                "l " +
                trNewRInnerCorner +
                " " +
                trNewRInnerCorner +
                " "
              
            } else {
              
              p +=
                "a " +
                trNewRInnerCorner +
                " " +
                trNewRInnerCorner +
                " 0 0 0 " +
                trNewRInnerCorner +
                " " +
                trNewRInnerCorner +
                " "
            }
            // bottom edge
            p +=
                "l " +
                (trWidth - trNewRInnerCorner) +
                " " +
                0 +
                " "
            // right to bottom turn
            if (cornerType("topRight") ==="cut") {
              
              p +=
                "l " +
                trNewRSlidingCorner +
                " " +
                trNewRSlidingCorner +
                " "
              
            } else {
              
              p +=
                "a " +
                trNewRSlidingCorner  +
                " " +
                trNewRSlidingCorner  +
                " 0 0 1 " +
                trNewRSlidingCorner +
                " " +
                trNewRSlidingCorner 
            }

        // =======================================================
        // RIGHT
        // =======================================================
          if(root.rightBlobProgress > 0){
            // come from top to start
            p +=
              "L " +
              right +
              " " +
              (y + (h - rightHeight)/2 - rightAvgMargin - rightNewRTopCorners) +
              " "
            // top to left corner
            if (cornerType("topRight") ==="cut") {
              p +=
                  "l " +
                  ( -rightNewRTopCorners ) +
                  " " +
                  rightNewRTopCorners +
                  " "
            } 
            else {
              p +=
                  "a " +
                  rightNewRTopCorners  +
                  " " +
                  rightNewRTopCorners +
                  " 0 0 1 " +
                  ( -rightNewRTopCorners ) +
                  " " +
                  rightNewRTopCorners +
                  " "
            }
            // top edge
            p +=
              "l " +
              -(rightWidth - (rightNewRTopCorners*2) + rightAvgMargin) +
              " " +
              0 +
              " "
            // right to down corner
            if (cornerType("topRight") ==="cut") {
              p +=
                  "l " +
                  ( -rightNewRTopCorners ) +
                  " " +
                  rightNewRTopCorners +
                  " "
            } 
            else {
              p +=
                  "a " +
                  rightNewRTopCorners  +
                  " " +
                  rightNewRTopCorners +
                  " 0 0 0 " +
                  ( -rightNewRTopCorners ) +
                  " " +
                  rightNewRTopCorners +
                  " "
            }
            // inner left edge
            p +=
                "l " +
                0 +
                " " +
                (rightHeight - rightNewRBottomCorners - rightNewRTopCorners + rightAvgMargin*2) +
                " "
            // down to right corner
            if (cornerType("bottomRight") ==="cut") {
                p +=
                    "l " +
                    ( rightNewRBottomCorners ) +
                    " " +
                    rightNewRBottomCorners +
                    " "
            } 
            else {
                p +=
                    "a " +
                    rightNewRBottomCorners  +
                    " " +
                    rightNewRBottomCorners +
                    " 0 0 0 " +
                    ( rightNewRBottomCorners ) +
                    " " +
                    rightNewRBottomCorners +
                    " "
            }
            // Bottom edge
            p +=
                "l " +
                (rightWidth - rightNewRBottomCorners*2 + rightAvgMargin) +
                " " +
                0 +
                " "
            // right to down corner
            if (cornerType("bottomRight") ==="cut") {
                p +=
                    "l " +
                    ( rightNewRBottomCorners ) +
                    " " +
                    rightNewRBottomCorners +
                    " "
            } 
            else {
                p +=
                    "a " +
                    rightNewRBottomCorners  +
                    " " +
                    rightNewRBottomCorners +
                    " 0 0 1 " +
                    ( rightNewRBottomCorners ) +
                    " " +
                    rightNewRBottomCorners +
                    " "
            }
          }
          
        p +=
            "L " +
            right +
            " " +
            (bottom - brHeight - brNewRSlidingCorner) +
            " "
          

        // ========================================================
        // BOTTOM RIGHT
        // ========================================================
          // top-left turn
          if (cornerType("bottomRight") ==="cut") {
            p +=
              "l " +
              (-brNewRSlidingCorner) +
              " " +
              (brNewRSlidingCorner) +
              " "
          }
          else {
            
              p +=
                  "a " +
                  brNewRSlidingCorner +
                  " " +
                  brNewRSlidingCorner +
                  " 0 0 1 " +
                  (-brNewRSlidingCorner) +
                  " " +
                  (brNewRSlidingCorner) +
                  " "
          }
          // top edge
          p +=
              "l " +
              -(brWidth) +
              " " +
              0 +
              " "
          // inner corner
          if (cornerType("bottomRight") ==="cut") {
            
            p +=
              "l " +
              -brNewRInnerCorner +
              " " +
              brNewRInnerCorner +
              " "
            
          } else {
            
            p +=
              "a " +
              brNewRInnerCorner +
              " " +
              brNewRInnerCorner +
              " 0 0 0 " +
              -brNewRInnerCorner +
              " " +
              brNewRInnerCorner +
              " "
          }
          // left edge
          p +=
              "l " +
              0 +
              " " +
              (brHeight - brNewREdgeCorner - brNewRInnerCorner) +
              " "
          // top to bottom turn
          if (cornerType("bottomRight") ==="cut") {
            
            p +=
              "l " +
              -brNewREdgeCorner +
              " " +
              brNewREdgeCorner +
              " "
            
          } else {
            
            p +=
              "a " +
              brNewREdgeCorner  +
              " " +
              brNewREdgeCorner  +
              " 0 0 1 " +
              -brNewREdgeCorner +
              " " +
              brNewREdgeCorner +
              " "
          }

        // =======================================================
        // BOTTOM
        // =======================================================
          if(root.bcBlobProgress > 0){
            // come to start from right side
            p +=
              "L " +
              (x + (w + bcWidth)/2 + bcAvgMargin + bcNewRRightCorners) +
              " " +
              bottom +
              " "
            // left to top corner
            if (cornerType("bottomRight") ==="cut") {
              p +=
                  "l " +
                  -bcNewRRightCorners +
                  " " +
                  ( -bcNewRRightCorners ) +
                  " "
            } 
            else {
              p +=
                  "a " +
                  -bcNewRRightCorners +
                  " " +
                  bcNewRRightCorners  +
                  " 0 0 1 " +
                  -bcNewRRightCorners +
                  " " +
                  ( -bcNewRRightCorners ) +
                  " "
            }
            // right edge
            p +=
              "l " +
              0 +
              " " +
              -(bcHeight - (bcNewRLeftCorners*4)/2 + bcAvgMargin) +
              " "
            // top to left corner
            if (cornerType("bottomRight") ==="cut") {
              p +=
                  "l " +
                  -bcNewRRightCorners +
                  " " +
                  ( -bcNewRRightCorners ) +
                  " "
            } 
            else {
              p +=
                  "a " +
                  bcNewRRightCorners +
                  " " +
                  bcNewRRightCorners  +
                  " 0 0 0 " +
                  -bcNewRRightCorners +
                  " " +
                  ( -bcNewRRightCorners ) +
                  " "
            }
            // inner top edge
            p +=
                "l " +
                 -(bcAvgMargin*2 + bcWidth - bcNewRLeftCorners - bcNewRRightCorners) +
                " " +
                0 +
                " "
            // left to down corner
            if (cornerType("bottomLeft") ==="cut") {
                p +=
                    "l " +
                    -bcNewRLeftCorners +
                    " " +
                    ( bcNewRLeftCorners ) +
                    " "
            } 
            else {
                p +=
                    "a " +
                    bcNewRLeftCorners +
                    " " +
                    bcNewRLeftCorners  +
                    " 0 0 0 " +
                    -bcNewRLeftCorners +
                    " " +
                    ( bcNewRLeftCorners ) +
                    " "
            }
            // Left edge
            p +=
                "l " +
                0 +
                " " +
                (bcHeight - bcNewRLeftCorners*2+ bcAvgMargin) +
                " "
            // down to right corner
            if (cornerType("bottomLeft") ==="cut") {
                p +=
                    "l " +
                    -bcNewRLeftCorners +
                    " " +
                    ( bcNewRLeftCorners ) +
                    " "
            } 
            else {
                p +=
                    "a " +
                    bcNewRLeftCorners +
                    " " +
                    bcNewRLeftCorners  +
                    " 0 0 1 " +
                    -bcNewRLeftCorners +
                    " " +
                    ( bcNewRLeftCorners ) +
                    " "
            }
          }

        p +=
            "L " +
            (x + blWidth + blNewRSlidingCorner + blNewRInnerCorner) +
            " " +
            (bottom) +
            " "
        // ========================================================
        // BOTTOM LEFT
        // ========================================================
          // left to top corner
          if (cornerType("bottomLeft") ==="cut") {
            
              p +=
                  "l " +
                  -blNewREdgeCorner +
                  " " +
                  -blNewREdgeCorner +
                  " "
            
          }
          else {
            
              p +=
                  "a " +
                  blNewREdgeCorner +
                  " " +
                  blNewREdgeCorner +
                  " 0 0 1 " +
                  -blNewREdgeCorner +
                  " " +
                  -blNewREdgeCorner +
                  " "
          }
          // right edge
          p +=
              "l " +
              0 +
              " " +
              -(blHeight-blNewREdgeCorner-blNewRInnerCorner) +
              " "
          // top to left inner corner
          if (cornerType("bottomLeft") ==="cut") {
              p +=
                  "l " +
                  (-blNewRInnerCorner) +
                  " " +
                  (-blNewRInnerCorner) +
                  " "
          }
          else {
              p +=
                  "a " +
                  blNewRInnerCorner +
                  " " +
                  blNewRInnerCorner +
                  " 0 0 0 " +
                  (-blNewRInnerCorner) +
                  " " +
                  (-blNewRInnerCorner) +
                  " "
          }
          // top edge
          p +=
              "l " +
              -(blWidth - blNewRInnerCorner) +
              " " +
              0 +
              " "
          // left to top edge corner
          if (cornerType("bottomLeft") ==="cut") {
              p +=
                  "l " +
                  (-blNewRSlidingCorner) +
                  " " +
                  (-blNewRSlidingCorner) +
                  " "
          }
          else {
              p +=
                  "a " +
                  blNewRSlidingCorner +
                  " " +
                  blNewRSlidingCorner +
                  " 0 0 1 " +
                  (-blNewRSlidingCorner) +
                  " " +
                  (-blNewRSlidingCorner) +
                  " "
          }

        // =======================================================
        // LEFT
        // =======================================================
          if(root.leftBlobProgress > 0){
            // come from bottom to start
            p +=
              "L " +
              x +
              " " +
              (bottom - (h - leftHeight)/2 + leftAvgMargin + (leftNewRBottomCorners)) +
              " "
            // bottom to right corner
            if (cornerType("bottomLeft") ==="cut") {
              p +=
                  "l " +
                  ( leftNewRBottomCorners ) +
                  " " +
                  -leftNewRBottomCorners +
                  " "
            } 
            else {
              p +=
                  "a " +
                  leftNewRBottomCorners  +
                  " " +
                  leftNewRBottomCorners +
                  " 0 0 1 " +
                  ( leftNewRBottomCorners ) +
                  " " +
                  -leftNewRBottomCorners +
                  " "
            }
            // bottom edge
            p +=
              "l " +
              (leftWidth - (leftNewRBottomCorners*2) + leftAvgMargin) +
              " " +
              0 +
              " "
            // right to up corner
            if (cornerType("bottomLeft") ==="cut") {
              p +=
                  "l " +
                  ( leftNewRBottomCorners ) +
                  " " +
                  -leftNewRBottomCorners +
                  " "
            } 
            else {
              p +=
                  "a " +
                  leftNewRBottomCorners  +
                  " " +
                  leftNewRBottomCorners +
                  " 0 0 0 " +
                  ( leftNewRBottomCorners ) +
                  " " +
                  -leftNewRBottomCorners +
                  " "
            }
            // inner right edge
            p +=
                "l " +
                0 +
                " " +
                -(leftHeight - leftNewRTopCorners - leftNewRBottomCorners + leftAvgMargin*2) +
                " "
            // up to left corner
            if (cornerType("topLeft") ==="cut") {
                p +=
                    "l " +
                    ( -leftNewRTopCorners ) +
                    " " +
                    -leftNewRTopCorners +
                    " "
            } 
            else {
                p +=
                    "a " +
                    leftNewRTopCorners  +
                    " " +
                    leftNewRTopCorners +
                    " 0 0 0 " +
                    (-leftNewRTopCorners ) +
                    " " +
                    -leftNewRTopCorners +
                    " "
            }
            // top edge
            p +=
                "l " +
                -(leftWidth - leftNewRTopCorners*2 + leftAvgMargin) +
                " " +
                0 +
                " "
            // left to down corner
            if (cornerType("topLeft") ==="cut") {
                p +=
                    "l " +
                    (-leftNewRTopCorners ) +
                    " " +
                    -leftNewRTopCorners +
                    " "
            } 
            else {
                p +=
                    "a " +
                    leftNewRTopCorners  +
                    " " +
                    leftNewRTopCorners +
                    " 0 0 1 " +
                    (-leftNewRTopCorners ) +
                    " " +
                    -leftNewRTopCorners +
                    " "
            }
          }

        p +=
          "L " +
          (x) +
          " " +
          (y + tlHeight + tlNewRSlidingCorner) +
          " "

        // =======================================================
        // TOP LEFT
        // =======================================================
          // top to right turn
          if (cornerType("topLeft") ==="cut") {
            
            p +=
              "l " +
              tlNewRSlidingCorner +
              " " +
              -tlNewRSlidingCorner +
              " "
            
          } else {
            
            p +=
              "a " +
              tlNewRSlidingCorner  +
              " " +
              tlNewRSlidingCorner  +
              " 0 0 1 " +
              tlNewRSlidingCorner +
              " " +
              -tlNewRSlidingCorner 
          }
          // bottom edge
          p +=
              "l " +
              (tlWidth + tlNewREdgeCorner) +
              " " +
              0 +
              " "
          // inner corner
          if (cornerType("topLeft") ==="cut") {
            
            p +=
              "l " +
              tlNewRInnerCorner +
              " " +
              -tlNewRInnerCorner +
              " "
            
          } else {
            
            p +=
              "a " +
              tlNewRInnerCorner +
              " " +
              tlNewRInnerCorner +
              " 0 0 0 " +
              tlNewRInnerCorner +
              " " +
              -tlNewRInnerCorner +
              " "
          }
          // right edge
          p +=
              "l " +
              0 +
              " " +
              -(tlHeight-tlNewREdgeCorner-tlNewRInnerCorner) +
              " "
          // top-bottom turn
          if (cornerType("topLeft") ==="cut") {
            p +=
              "l " +
              (tlNewREdgeCorner) +
              " " +
              -tlNewREdgeCorner +
              " "
          }
          else {
            p +=
              "a " +
              tlNewREdgeCorner +
              " " +
              tlNewREdgeCorner +
              " 0 0 1 " +
              tlNewREdgeCorner +
              " " +
              -tlNewREdgeCorner +
              " "
          }


        
        p +=
            "L " +
            (x + tl + tlWidth + tlNewRSlidingCorner) +
            " " +
            (y) +
            " "


        p += "Z"

        return p
    }

    // ============================================================
    // FULL FRAME RING
    // ============================================================
    function framePath() {

        var inner =
            innerGeometry()


        /*
            Outer rectangle is the physical
            screen rectangle.

            Inner path becomes the hole.
        */

        var outer =
            "M 0 0 " +
            "L " +
            frameWindow.width +
            " 0 " +
            "L " +
            frameWindow.width +
            " " +
            frameWindow.height +
            " " +
            "L 0 " +
            frameWindow.height +
            " " +
            "Z"


        return (
            outer +
            " " +
            innerPath()
        )
    }

    // ============================================================
    // RESERVATION WINDOWS
    //
    // These are separate from the visual frame.
    //
    // Their ONLY job is to tell the compositor:
    //
    // "keep normal windows away from this edge."
    // ============================================================

    property real topReservationValue: {
        let validHeights = [];
        
        if (root.shouldTlBlobReserveSpace) validHeights.push(tlBlobContent.height);
        if (root.shouldTrBlobReserveSpace) validHeights.push(trBlobContent.height);
        if (root.shouldTcBlobReserveSpace) validHeights.push(tcBlobContent.height);
        
        return validHeights.length > 0 ? Math.max(...validHeights) + root.frameSide("top"): 0 + root.frameSide("top");
    }

    
    PanelWindow {
        id: topReservation

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight:
            root.topReservationValue

        exclusiveZone:
            implicitHeight

        color: "transparent"

        WlrLayershell.layer:
            WlrLayer.Bottom

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None
    }
    PanelWindow {
        id: bottomReservation

        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight:
            root.frameSide("bottom")

        exclusiveZone:
            implicitHeight

        color: "transparent"

        WlrLayershell.layer:
            WlrLayer.Bottom

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None
    }
    PanelWindow {
        id: leftReservation

        anchors {
            top: true
            bottom: true
            left: true
        }

        implicitWidth:
            root.frameSide("left")

        exclusiveZone:
            implicitWidth

        color: "transparent"

        WlrLayershell.layer:
            WlrLayer.Bottom

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None
    }
    PanelWindow {
        id: rightReservation

        anchors {
            top: true
            bottom: true
            right: true
        }

        implicitWidth:
            root.frameSide("right")

        exclusiveZone:
            implicitWidth

        color: "transparent"

        WlrLayershell.layer:
            WlrLayer.Bottom

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None
    }

    // ============================================================
    // FRAME WINDOW
    // ============================================================
    PanelWindow {
        id: frameWindow

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        exclusionMode:
            ExclusionMode.Ignore

        WlrLayershell.layer:
            frameLayer

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        // ========================================================
        // FRAME
        // ========================================================
        Shape {
            id: frameShape

            anchors.fill: parent

            antialiasing: true

            containsMode: Shape.FillContains

            layer.enabled:
                root.shadows &&
                root.shadows.intensity !== undefined


            layer.effect:
                MultiEffect {

                    shadowEnabled: true

                    shadowColor:
                        root.shadows.color !== undefined
                            ? root.shadows.color
                            : "#000000"

                    shadowOpacity:
                        root.shadows.opacity !== undefined
                            ? Number(
                                root.shadows.opacity
                            )
                            : 0.5

                    shadowBlur:
                        root.shadows.blur !== undefined
                            ? Number(
                                root.shadows.blur
                            )
                            : 1.0

                    blurMax:
                        root.shadows.intensity !== undefined
                            ? Math.max(
                                1,
                                Number(
                                    root.shadows.intensity
                                )
                            )
                            : 16

                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0

                    autoPaddingEnabled: true
                }


            ShapePath {

                fillColor:
                    root.frameColor

                strokeColor:
                    "transparent"

                strokeWidth: 0

                fillRule:
                    ShapePath.OddEvenFill


                PathSvg {
                    path:
                        root.framePath()
                }
            }
        }

        // ========================================================
        // INNER BORDER
        // ========================================================
        Shape {
            id: innerBorder

            anchors.fill: parent

            visible:
                root.borderWidth > 0

            antialiasing: true


            ShapePath {

                fillColor:
                    "transparent"

                strokeColor:
                    root.borderColor

                strokeWidth:
                    root.borderWidth

                joinStyle:
                    ShapePath.RoundJoin

                capStyle:
                    ShapePath.FlatCap


                PathSvg {
                    path:
                        root.innerPath()
                }
            }
        }

        // ========================================================
        // HOVER MOUSE AREAS
        // ========================================================
        // bottom left
        MouseArea {
            id: blBlobMouseArea
            Rectangle{color:"#3fffffff";visible:true;anchors.fill:parent}


            x: 0

            y: frameWindow.height - height

            width: root.isBlBlobActive || root.blBlobProgress > 0?
                    root.innerGeometry().bl*0.5 +
                    root.frameSide("left") +
                    blBlobContent.width + root.extendedHoverDetectionSize
                  : root.hoverDetectionSize

            height: root.isBlBlobActive || root.blBlobProgress > 0?
                root.innerGeometry().bl*0.5 +
                root.frameSide("bottom") +
                blBlobContent.height  + root.extendedHoverDetectionSize
                  : root.hoverDetectionSize

            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            /*
                Keep the MouseArea alive while the blob is being
                animated out.
            */
            enabled:
                root.blBlobProgress > 0.001 ||
                containsMouse

            // Child hover areas on the side and bottom
            property real _length:frameWindow.height - Math.min(
              Math.min(frameWindow.height * 0.89 , frameWindow.width * 0.89) ,
              Math.max(
                Math.max(root.innerGeometry().y , root.hoverDetectionSize) + root.innerGeometry().height - (1.5 * root.innerGeometry().bl),
                Math.max(root.innerGeometry().y , root.hoverDetectionSize) + root.innerGeometry().height - (15 + root.innerGeometry().bl),
              )
            )
            // left side
            MouseArea{
              Rectangle{color:"#3f0000ff";visible:true;anchors.fill:parent}
              x:0
              y: parent.height - height
              height: parent._length
              width:root.hoverDetectionSize
              hoverEnabled:true
              onEntered: parent.onEntered()
            }
            // bottom
            MouseArea{
              Rectangle{color:"#3fff0000";visible:true;anchors.fill:parent}
              x:0
              y: parent.height - height
              height: root.hoverDetectionSize
              width: parent._length
              hoverEnabled:true
              onEntered: parent.onEntered()
            }

            onEntered: {
              root.onHoveredBLBlob()
            }

            onExited: {
              root.onExitedBLBlob()
            }
        }
        // bottom right
        MouseArea {
            id: brBlobMouseArea
            Rectangle{color:"#3fffffff";visible:true;anchors.fill:parent}
            x: frameWindow.width - width
            y: frameWindow.height - height
            width: root.isBrBlobActive || root.brBlobProgress > 0?
                    root.innerGeometry().br*0.5 +
                    root.frameSide("right") +
                    brBlobContent.width + root.extendedHoverDetectionSize
                  : root.hoverDetectionSize
            height: root.isBrBlobActive || root.brBlobProgress > 0?
            root.innerGeometry().br*0.5 +
                root.frameSide("bottom") +
                brBlobContent.height + root.extendedHoverDetectionSize
                  : root.hoverDetectionSize
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled:
                root.brBlobProgress > 0.001 ||
                containsMouse

            // Child hover areas on the side and bottom
            property real _length:frameWindow.height - Math.min(
              // normal frame based calculations
              Math.min(frameWindow.height * 0.89 , frameWindow.width * 0.89) ,
              // in case of very big corner sizes
              Math.max(
                Math.max(root.innerGeometry().y , root.hoverDetectionSize) + root.innerGeometry().height - (1.5 * root.innerGeometry().br),
                Math.max(root.innerGeometry().y , root.hoverDetectionSize) + root.innerGeometry().height - (15 + root.innerGeometry().br),
              )
            )
            // right side
            MouseArea{
              Rectangle{color:"#3f0000ff";visible:true;anchors.fill:parent}
              x: parent.width - width
              y: parent.height - height
              height: parent._length
              width:root.hoverDetectionSize
              hoverEnabled:true
              onEntered: parent.onEntered()
            }
            // bottom
            MouseArea{
              Rectangle{color:"#3fff0000";visible:true;anchors.fill:parent}
              x:parent.width - width
              y: parent.height - height
              height: root.hoverDetectionSize
              width: parent._length
              hoverEnabled:true
              onEntered: parent.onEntered()
            }

            onEntered: {
              root.onHoveredBRBlob()
            }

            onExited: {
              root.onExitedBRBlob()
            }
        }
        // bottom center
        MouseArea {
            id: bcBlobMouseArea
            Rectangle{color:"#3fffffff";visible:true;anchors.fill:parent}
            x: root.innerGeometry().x + (root.innerGeometry().width - width) * 0.5
            y: frameWindow.height - height
            width: root.isBcBlobActive || root.bcBlobProgress > 0?
                    (Math.max(Math.max(0, Math.min(bcBlobContent.width*0.5, root.cornerSize("bottomLeft") * 0.5)) + Math.max(0, Math.min(bcBlobContent.width*0.5, root.cornerSize("bottomRight") * 0.5)), 2*root.blobMinMargin)/2)*root.bcBlobProgress +
                    bcBlobContent.width + root.extendedHoverDetectionSize/2
                  : _length
            height: root.isBcBlobActive || root.bcBlobProgress > 0?
                    (Math.max(Math.max(0, Math.min(bcBlobContent.width*0.5, root.cornerSize("bottomLeft") * 0.5)) + Math.max(0, Math.min(bcBlobContent.width*0.5, root.cornerSize("bottomRight") * 0.5)), 2*root.blobMinMargin)/2)*root.bcBlobProgress +
                    root.frameSide("bottom") +
                    bcBlobContent.height + root.extendedHoverDetectionSize/4
                  : root.hoverDetectionSize
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled:
                root.bcBlobProgress > 0.001 ||
                containsMouse

            // Child hover areas on the side and bottom
            property real _length:
                      Math.min(frameWindow.height * 0.50 , frameWindow.width * 0.50, 400)
                      // bottom
            MouseArea{
              Rectangle{color:"#3fff0000";visible:true;anchors.fill:parent}
              x:(parent.width - width) / 2
              y: parent.height - height
              height:root.hoverDetectionSize
              width: parent._length
              hoverEnabled:true
              onEntered: parent.onEntered()
              onExited: if(! parent.containsMouse) parent.onExited()
            }

            onEntered: {
              root.onHoveredBCBlob()
            }

            onExited: {
              root.onExitedBCBlob()
            }
        }
        // top left
        MouseArea {
            id: tlBlobMouseArea
            Rectangle{color:"#3fffffff";visible:true;anchors.fill:parent}
            x: 0
            y: 0
            width: root.isTlBlobActive || root.tlBlobProgress > 0?
                    root.innerGeometry().tl*0.5 +
                    root.frameSide("left") +
                    tlBlobContent.width + root.extendedHoverDetectionSize
                  : root.innerGeometry().x
            height: root.isTlBlobActive || root.tlBlobProgress > 0?
                      root.innerGeometry().tl*0.5 +
                      root.frameSide("top") +
                      tlBlobContent.height + root.extendedHoverDetectionSize
                    : root.frameSide("top")
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled:
                root.tlBlobProgress > 0.001 ||
                containsMouse

            // Child hover areas on the side and top
            property real _length:frameWindow.height - Math.min(
              Math.min(frameWindow.height * 0.89 , frameWindow.width * 0.89) ,
              Math.max(
                Math.max(root.innerGeometry().y , root.hoverDetectionSize) + root.innerGeometry().height - (1.5 * root.innerGeometry().tl),
                Math.max(root.innerGeometry().y , root.hoverDetectionSize) + root.innerGeometry().height - (15 + root.innerGeometry().tl),
              )
            )
            // left side
            MouseArea{
              Rectangle{color:"#3f0000ff";visible:true;anchors.fill:parent}
              x:0
              y: 0
              height: parent._length
              width:Math.max(root.innerGeometry().x , root.hoverDetectionSize)
              hoverEnabled:true
              onEntered: parent.onEntered()
            }
            // top
            MouseArea{
              Rectangle{color:"#3fff0000";visible:true;anchors.fill:parent}
              x:0
              y: 0
              height: root.hoverDetectionSize
              width: parent._length
              hoverEnabled:true
              onEntered: parent.onEntered()
            }

            onEntered: {
              root.onHoveredTLBlob()
            }

            onExited: {
              root.onExitedTLBlob()
            }
        }
        // top right
        MouseArea {
            id: trBlobMouseArea
            Rectangle{color:"#3fffffff";visible:true;anchors.fill:parent}
            x: frameWindow.width - width
            y: 0
            width: root.isTrBlobActive || root.trBlobProgress > 0?
                    root.innerGeometry().tr*0.5 +
                    root.frameSide("right") +
                    trBlobContent.width + root.extendedHoverDetectionSize
                  : root.hoverDetectionSize
            height: root.isTrBlobActive || root.trBlobProgress > 0?
                      root.innerGeometry().tr*0.5 +
                      root.frameSide("top") +
                      trBlobContent.height + root.extendedHoverDetectionSize
                    : root.hoverDetectionSize
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled:
                root.trBlobProgress > 0.001 ||
                containsMouse

            // Child hover areas on the side and top
            property real _length:frameWindow.height - Math.min(
              // normal frame based calculations
              Math.min(frameWindow.height * 0.89 , frameWindow.width * 0.89) ,
              // in case of very big corner sizes
              Math.max(
                Math.max(root.innerGeometry().y , root.hoverDetectionSize) + root.innerGeometry().height - (1.5 * root.innerGeometry().tr),
                Math.max(root.innerGeometry().y , root.hoverDetectionSize) + root.innerGeometry().height - (15 + root.innerGeometry().tr),
              )
            )
            // right side
            MouseArea{
              Rectangle{color:"#3f0000ff";visible:true;anchors.fill:parent}
              x: parent.width - width
              y: 0
              height: parent._length
              width:root.hoverDetectionSize
              hoverEnabled:true
              onEntered: parent.onEntered()
            }
            // top
            MouseArea{
              Rectangle{color:"#3fff0000";visible:true;anchors.fill:parent}
              x:parent.width - width
              y: 0
              height: root.hoverDetectionSize
              width: parent._length
              hoverEnabled:true
              onEntered: parent.onEntered()
            }

            onEntered: {
              root.onHoveredTRBlob()
            }

            onExited: {
              root.onExitedTRBlob()
            }
        }
        // top center
        MouseArea {
            id: tcBlobMouseArea
            Rectangle{color:"#3fffffff";visible:true;anchors.fill:parent}
            x: root.innerGeometry().x + (root.innerGeometry().width - width) * 0.5
            y: 0
            width: root.isTcBlobActive || root.tcBlobProgress > 0?
                  (Math.max(Math.max(0, Math.min(tcBlobContent.width*0.5, root.cornerSize("topLeft") * 0.5)) + Math.max(0, Math.min(tcBlobContent.width*0.5, root.cornerSize("topRight") * 0.5)), 2*root.blobMinMargin)/2)*root.tcBlobProgress +
                  tcBlobContent.width + root.extendedHoverDetectionSize 
                : _length
            height: root.isTcBlobActive || root.tcBlobProgress > 0?
                  (Math.max(Math.max(0, Math.min(tcBlobContent.width*0.5, root.cornerSize("topLeft") * 0.5)) + Math.max(0, Math.min(tcBlobContent.width*0.5, root.cornerSize("topRight") * 0.5)), 2*root.blobMinMargin)/2)*root.tcBlobProgress +
                    root.frameSide("top") +
                    tcBlobContent.height + root.extendedHoverDetectionSize / 2
                  : root.hoverDetectionSize
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled:
                root.tcBlobProgress > 0.001 ||
                containsMouse

            // Child hover areas on the side and top
            property real _length:
                      Math.min(frameWindow.height * 0.50 , frameWindow.width * 0.50, 400)
            // top
            MouseArea{
              Rectangle{color:"#3fff0000";visible:true;anchors.fill:parent}
              x:(parent.width - width) / 2
              y: 0
              height: root.hoverDetectionSize
              width: parent._length
              hoverEnabled:true
              onEntered: parent.onEntered()
              onExited: if(! parent.containsMouse) parent.onExited()
            }

            onEntered: {
              root.onHoveredTCBlob()
            }

            onExited: {
              root.onExitedTCBlob()
            }
        }
        // left
        MouseArea {
            id: leftBlobMouseArea
            Rectangle{color:"#3fffffff";visible:true;anchors.fill:parent}
            x: 0
            y: root.innerGeometry().y + (root.innerGeometry().height - height) * 0.5
            height: root.isLeftBlobActive || root.leftBlobProgress > 0?
                    (Math.max(Math.max(0, Math.min(leftBlobContent.width*0.5, root.cornerSize("bottomLeft") * 0.5)) + Math.max(0, Math.min(leftBlobContent.width*0.5, root.cornerSize("topLeft") * 0.5)), 2*root.blobMinMargin)/2)*root.leftBlobProgress +
                    leftBlobContent.height + root.extendedHoverDetectionSize
                  : _length
            width: root.isLeftBlobActive || root.leftBlobProgress > 0?
                    (Math.max(Math.max(0, Math.min(leftBlobContent.width*0.5, root.cornerSize("bottomLeft") * 0.5)) + Math.max(0, Math.min(leftBlobContent.width*0.5, root.cornerSize("topLeft") * 0.5)), 2*root.blobMinMargin)/2)*root.leftBlobProgress +
                    root.frameSide("left") +
                    leftBlobContent.width + root.extendedHoverDetectionSize / 2
                  : root.hoverDetectionSize
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled:
                root.leftBlobProgress > 0.001 ||
                containsMouse

            // Child hover areas on the side
            property real _length:
                      Math.min(frameWindow.height * 0.50 , frameWindow.width * 0.50, 400)
            // side
            MouseArea{
              Rectangle{color:"#3fff0000";visible:true;anchors.fill:parent}
              x: 0
              y: (parent.height - height) / 2
              height: parent._length
              width: root.hoverDetectionSize
              hoverEnabled:true
              onEntered: parent.onEntered()
              onExited: if(! parent.containsMouse) parent.onExited()
            }

            onEntered: {
              root.onHoveredLEFTBlob()
            }

            onExited: {
              root.onExitedLEFTBlob()
            }
        }
        // right
        MouseArea {
            id: rightBlobMouseArea
            Rectangle{color:"#3fffffff";visible:true;anchors.fill:parent}
            x: frameWindow.width - width
            y: root.innerGeometry().y + (root.innerGeometry().height - height) * 0.5
            height: root.isRightBlobActive || root.rightBlobProgress > 0?
                    (Math.max(Math.max(0, Math.min(rightBlobContent.width*0.5, root.cornerSize("bottomRight") * 0.5)) + Math.max(0, Math.min(rightBlobContent.width*0.5, root.cornerSize("topRight") * 0.5)), 2*root.blobMinMargin)/2)*root.rightBlobProgress +
                    rightBlobContent.height + root.extendedHoverDetectionSize
                  : _length
            width: root.isRightBlobActive || root.rightBlobProgress > 0?
                      root.frameSide("right") +
                      (Math.max(Math.max(0, Math.min(rightBlobContent.width*0.5, root.cornerSize("bottomRight") * 0.5)) + Math.max(0, Math.min(rightBlobContent.width*0.5, root.cornerSize("topRight") * 0.5)), 2*root.blobMinMargin)/2)*root.rightBlobProgress +
                      rightBlobContent.width + root.extendedHoverDetectionSize / 2
                    : root.hoverDetectionSize
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled:
                root.rightBlobProgress > 0.001 ||
                containsMouse

            // Child hover areas on the side
            property real _length:
                      Math.min(frameWindow.height * 0.50 , frameWindow.width * 0.50, 400)
            // side
            MouseArea{
              Rectangle{color:"#3fff0000";visible:true;anchors.fill:parent}
              x: parent.width - width
              y: (parent.height - height) / 2
              height: parent._length
              width: root.hoverDetectionSize
              hoverEnabled:true
              onEntered: parent.onEntered()
              onExited: if(! parent.containsMouse) parent.onExited()
            }

            onEntered: {
              root.onHoveredRIGHTBlob()
            }

            onExited: {
              root.onExitedRIGHTBlob()
            }
        }


        //======================
        // BLOB CONTAINERS
        // =====================
        // bottom left
        Blob {
            id: blBlobContent
            blobId: "bl"
            moduleRegistry:
                root.moduleRegistry
            moduleIds:
                root.blobManager.blobs.bl || []
            focusManager:
                root.focusManager
            visible:
                root.isBlBlobActive ||
                root.blBlobProgress > 0
            opacity:
                root.blBlobProgress
            scale:
                root.blBlobProgress
            x:
                root.frameSide("left")
            y:
                frameWindow.height -
                root.frameSide("bottom") -
                height
        }
        // bottom right
        Blob {
            id: brBlobContent
            blobId: "br"
            moduleRegistry:
                root.moduleRegistry
            moduleIds:
                root.blobManager.blobs.br || []
            focusManager:
                root.focusManager
            visible:
                root.isBrBlobActive ||
                root.brBlobProgress > 0
            opacity:
                root.brBlobProgress
            scale:
                root.brBlobProgress
            x:
                frameWindow.width -
                width -
                root.frameSide("right")
            y:
                frameWindow.height -
                root.frameSide("bottom") -
                height
        }
        // bottom center
        Blob {
            id: bcBlobContent
            blobId: "bc"
            moduleRegistry:
                root.moduleRegistry
            moduleIds:
                root.blobManager.blobs.bc || []
            focusManager:
                root.focusManager
            visible:
                root.isBcBlobActive ||
                root.bcBlobProgress > 0
            opacity:
                root.bcBlobProgress
            scale:
                root.bcBlobProgress
            x:
                root.innerGeometry().x +
                (root.innerGeometry().width - width) * 0.5
            y:
                frameWindow.height -
                root.frameSide("bottom") -
                height
        }
        // top left
        Blob {
            id: tlBlobContent
            blobId: "tl"
            moduleRegistry:
                root.moduleRegistry
            moduleIds:
                root.blobManager.blobs.tl || []
            focusManager:
                root.focusManager
            visible:
                root.isTlBlobActive ||
                root.tlBlobProgress > 0
            opacity:
                root.tlBlobProgress
            scale:
                root.tlBlobProgress
            x:
                root.frameSide("left")
            y:
                root.frameSide("top")
        }
        // top right
        Blob {
            id: trBlobContent
            blobId: "tr"
            moduleRegistry:
                root.moduleRegistry
            moduleIds:
                root.blobManager.blobs.tr || []
            focusManager:
                root.focusManager
            visible:
                root.isTrBlobActive ||
                root.trBlobProgress > 0
            opacity:
                root.trBlobProgress
            scale:
                root.trBlobProgress
            x:
                frameWindow.width -
                width -
                root.frameSide("right")
            y:
                root.frameSide("top")
        }
        // top center
        Blob {
            id: tcBlobContent
            blobId: "tc"
            moduleRegistry:
                root.moduleRegistry
            moduleIds:
                root.blobManager.blobs.tc || []
            focusManager:
                root.focusManager
            visible:
                root.isTcBlobActive ||
                root.tcBlobProgress > 0
            opacity:
                root.tcBlobProgress
            scale:
                root.tcBlobProgress
            x:
                root.innerGeometry().x +
                (root.innerGeometry().width - width) * 0.5
            y:
                root.frameSide("top")
        }
        // left
        Blob {
            id: leftBlobContent
            blobId: "left"
            moduleRegistry:
                root.moduleRegistry
            moduleIds:
                root.blobManager.blobs.left || []
            focusManager:
                root.focusManager
            visible:
                root.isLeftBlobActive ||
                root.leftBlobProgress > 0
            opacity:
                root.leftBlobProgress
            scale:
                root.leftBlobProgress
            x:
                root.frameSide("left")
            y:
                root.innerGeometry().y +
                (root.innerGeometry().height - height) * 0.5
        }
        // right
        Blob {
            id: rightBlobContent
            blobId: "right"
            moduleRegistry:
                root.moduleRegistry
            moduleIds:
                root.blobManager.blobs.right || []
            focusManager:
                root.focusManager
            visible:
                root.isRightBlobActive ||
                root.rightBlobProgress > 0
            opacity:
                root.rightBlobProgress
            scale:
                root.rightBlobProgress
            x:
                frameWindow.width -
                width -
                root.frameSide("right")
            y:
                root.innerGeometry().y +
                (root.innerGeometry().height - height) * 0.5
        }

        // ==================================
        // ==========  MASKING  =============
        // ==================================
        mask: Region{
          // start with full screen
          x: 0; y:0; width: Screen.width; height: Screen.height

          // now substract the hollow area
          // reserve 5px if the frameWidth is very low
          Region{
            x: Math.max(root.innerGeometry().x , root.hoverDetectionSize)
            y: Math.max(root.innerGeometry().y , root.hoverDetectionSize)
            height: Math.min(root.innerGeometry().height , frameWindow.height - (root.hoverDetectionSize * 2))
            width: Math.min(root.innerGeometry().width , frameWindow.width - (root.hoverDetectionSize * 2))
            intersection:Intersection.Subtract
          }
          // now just add all the blob mouseAreas
          Region{item:blBlobMouseArea}
          Region{item:brBlobMouseArea}
          Region{item:bcBlobMouseArea}
          Region{item:trBlobMouseArea}
          Region{item:tlBlobMouseArea}
          Region{item:tcBlobMouseArea}
          Region{item:leftBlobMouseArea}
          Region{item:rightBlobMouseArea}
        }
    }
}
