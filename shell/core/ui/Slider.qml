import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

import qs.core.ui


Item {

    id: root

    anchors.fill: parent
    anchors.margins: 5


    // ============================================================
    // PUBLIC API
    // ============================================================

    property string orientation: "horizontal"


    property var range: ({
        min: 0,
        max: 100,
        default: 50,
        step: 1
    })


    property real value:
        _round2(
            _number(
                range.default,
                0
            )
        )


    /*
        Example:

        formatValue: function(value) {
            return value * 100 / 169 + "%"
        }
    */
    property var formatValue:
        function(value) {
            return value + "%"
        }


    /*
        0 = automatic sizing.

        > 0 = requested maximum font size.
        Text.Fit can still shrink it when necessary.
    */
    property real fontSizeOverride: 0


    /*
        Enables / disables ALL Slider interaction.

        false:
            - bar cannot be clicked / dragged
            - control cannot be dragged
            - scroll is disabled
            - +/- buttons are disabled
            - hold timers are stopped

        Visual rendering remains active.
    */
    property bool interactive: true


    property var bar: ({})

    property var button: ({})

    property var control: ({})


    /*
        Buttons are hidden by default.

        When false:
            - buttons are invisible
            - button axis-space is removed
            - bar expands into that space
    */
    property bool btnsEnabled: false


    property int animationDuration: 140


    /*
        Button hold:

            immediate step
            ↓
            wait 1 second
            ↓
            repeat every 200 ms
    */
    property int buttonHoldThreshold: 1000
    property int buttonHoldRepeat: 200


    /*
        Scroll:

            scrollThreshold
                controls CutBox wheel-event rate limiting

            scrollStrength
                controls how many slider steps one emitted
                wheel event changes
    */
    property int scrollThreshold: 100

    property real scrollStrength: 1.0


    // ============================================================
    // INTERNAL STATE
    // ============================================================

    readonly property bool horizontal:
        orientation === "horizontal"


    readonly property bool vertical:
        orientation === "vertical"


    property bool dragging: false


    /*
        Cursor position inside control when drag begins.
    */
    property real dragOffsetX: 0
    property real dragOffsetY: 0


    property bool buttonHolding: false
    property int buttonDirection: 0


    // ============================================================
    // IMPLICIT SIZE
    // ============================================================

    implicitWidth:
        horizontal
            ? 360
            : 48


    implicitHeight:
        horizontal
            ? 48
            : 360


    // ============================================================
    // BASIC HELPERS
    // ============================================================

    function _number(value, fallback) {

        var n =
            Number(value)

        return isFinite(n)
            ? n
            : fallback
    }


    function _round2(value) {

        return Math.round(
            Number(value) * 100
        ) / 100
    }


    function _clamp(
        value,
        minimum,
        maximum
    ) {

        return Math.max(
            minimum,
            Math.min(
                maximum,
                value
            )
        )
    }


    function _min() {

        return _number(
            range.min,
            0
        )
    }


    function _max() {

        return _number(
            range.max,
            100
        )
    }


    function _default() {

        return _number(
            range.default,
            _min()
        )
    }


    function _step() {

        return Math.abs(
            _number(
                range.step,
                1
            )
        )
    }


    // ============================================================
    // FORMATTED VALUE
    // ============================================================

    /*
        formatValue() may perform arbitrary calculations.

        Example:

            formatValue: function(value) {
                return value * 100 / 169 + "%"
            }

        The first numeric portion of the resulting string
        is restricted to exactly two decimal places.

        Non-numeric strings such as:

            ☀
            ◐
            VOL

        remain unchanged.
    */

    function _formattedValue() {

        var formatted =
            String(
                formatValue(
                    value
                )
            )


        return formatted.replace(
            /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/,
            function(numberText) {

                return Number(
                    numberText
                ).toFixed(2)
            }
        )
    }


    // ============================================================
    // INTERACTION STATE RESET
    // ============================================================

    function _stopInteraction() {

        dragging =
            false


        buttonDirection =
            0

        buttonHolding =
            false


        buttonHoldThresholdTimer.stop()

        buttonRepeatTimer.stop()
    }


    onInteractiveChanged: {

        if (!root.interactive)
            _stopInteraction()
    }


    // ============================================================
    // VALUE
    // ============================================================

    function setValue(nextValue) {

        var minimum =
            _min()

        var maximum =
            _max()

        var step =
            _step()


        if (maximum < minimum) {

            var swap =
                minimum

            minimum =
                maximum

            maximum =
                swap
        }


        var next =
            _number(
                nextValue,
                value
            )


        next =
            _clamp(
                next,
                minimum,
                maximum
            )


        if (step > 0) {

            next =
                minimum +
                Math.round(
                    (
                        next -
                        minimum
                    ) /
                    step
                ) *
                step
        }


        next =
            _clamp(
                _round2(next),
                minimum,
                maximum
            )


        if (
            Math.abs(
                value -
                next
            ) > 0.000001
        ) {

            value =
                next
        }
    }


    // ============================================================
    // NORMALIZED VALUE
    // ============================================================

    readonly property real normalizedValue: {

        var minimum =
            _min()

        var maximum =
            _max()

        var span =
            maximum -
            minimum


        if (span <= 0)
            return 0


        return _clamp(
            (
                value -
                minimum
            ) /
            span,
            0,
            1
        )
    }


    // ============================================================
    // GEOMETRY
    // ============================================================

    readonly property real barThickness:
        horizontal
            ? root.height * 0.5
            : root.width * 0.5


    readonly property real buttonSize:
        barThickness * 1.4


    readonly property real spacing:
        buttonSize * 0.1


    /*
        Button-space only exists when buttons are enabled.
    */

    readonly property real effectiveButtonSize:
        btnsEnabled
            ? buttonSize
            : 0


    readonly property real effectiveSpacing:
        btnsEnabled
            ? spacing
            : 0


    /*
        Horizontal:

            width  = root.height * 1.5
            height = root.height

        Vertical:

            width  = root.width
            height = root.width * 1.5
    */

    readonly property real controlWidth:
        horizontal
            ? root.height * 1.5
            : root.width


    readonly property real controlHeight:
        horizontal
            ? root.height
            : root.width * 1.5


    /*
        Full available axis.
    */

    readonly property real barLength:
        horizontal
            ? Math.max(
                0,
                root.width -
                effectiveButtonSize * 2 -
                effectiveSpacing * 2
            )
            : Math.max(
                0,
                root.height -
                effectiveButtonSize * 2 -
                effectiveSpacing * 2
            )


    readonly property real controlTravel:
        horizontal
            ? Math.max(
                0,
                barLength -
                controlWidth
            )
            : Math.max(
                0,
                barLength -
                controlHeight
            )


    // ============================================================
    // BAR POSITION
    // ============================================================

    readonly property real barX:
        horizontal
            ? effectiveButtonSize +
              effectiveSpacing
            : (
                root.width -
                barThickness
            ) / 2


    readonly property real barY:
        horizontal
            ? (
                root.height -
                barThickness
            ) / 2
            : effectiveButtonSize +
              effectiveSpacing


    // ============================================================
    // CONTROL POSITION
    // ============================================================

    readonly property real controlX:
        horizontal
            ? barX +
              normalizedValue *
              controlTravel
            : (
                root.width -
                controlWidth
            ) / 2


    readonly property real controlY:
        horizontal
            ? (
                root.height -
                controlHeight
            ) / 2
            : barY +
              (
                  1 -
                  normalizedValue
              ) *
              controlTravel


    // ============================================================
    // FILL LENGTH
    // ============================================================

    readonly property real fillLength:

        horizontal

            ? Math.max(
                0,
                controlX -
                barX +
                controlWidth / 2
            )

            : Math.max(
                0,
                (
                    barY +
                    barLength
                ) -
                (
                    controlY +
                    controlHeight / 2
                )
            )


    // ============================================================
    // BAR STYLE
    // ============================================================

    function _barBackground() {

        if (
            bar &&
            bar.background !== undefined
        )

            return bar.background


        return "#0b1018"
    }


    function _barBorderColor() {

        if (
            bar &&
            bar.border &&
            bar.border.color !== undefined
        )

            return bar.border.color


        return "transparent"
    }


    function _barBorderWidth() {

        if (
            bar &&
            bar.border &&
            bar.border.width !== undefined
        )

            return Number(
                bar.border.width
            )


        return 0
    }


    function _barBorderGlow() {

        if (
            !bar ||
            !bar.border
        )

            return 0


        return (
            _number(
                bar.border.width,
                0
            ) *
            _number(
                bar.border.glow,
                0
            ) *
            barThickness *
            0.01
        )
    }


    // ============================================================
    // CONTROL STYLE
    // ============================================================

    function _controlBackground() {

        if (
            control &&
            control.bgColor !== undefined
        )

            return control.bgColor


        return "#101b2a"
    }


    function _controlBorderColor() {

        if (
            control &&
            control.borderColor !== undefined
        )

            return control.borderColor


        return "#00eaff"
    }


    function _controlBorderWidth() {

        if (
            control &&
            control.borderWidth !== undefined
        )

            return Number(
                control.borderWidth
            )


        return 0
    }


    function _controlBorderGlow() {

        var width =
            _controlBorderWidth()

        var glow =
            control &&
            control.borderGlow !== undefined
                ? Number(
                    control.borderGlow
                )
                : 0


        var dimension =
            horizontal
                ? controlHeight
                : controlWidth


        return (
            width *
            glow *
            dimension *
            0.01
        )
    }


    // ============================================================
    // GRADIENT COLORS
    // ============================================================

    function _gradientCount() {

        if (
            !bar ||
            !Array.isArray(bar.fill)
        )

            return 0


        return bar.fill.length
    }


    function _gradientColor(index) {

        var count =
            _gradientCount()


        if (count <= 0)
            return "transparent"


        if (index >= count)
            return bar.fill[count - 1]


        return bar.fill[index]
    }


    function _gradientPosition(index) {

        var count =
            _gradientCount()


        if (count <= 1)
            return 0


        return Math.max(
            0,
            Math.min(
                1,
                index /
                (count - 1)
            )
        )
    }


    function _gradientMiddleColor() {

        var count =
            _gradientCount()


        if (count <= 0)
            return "transparent"


        if (count === 1)
            return _gradientColor(0)


        return _gradientColor(
            Math.floor(
                (count - 1) / 2
            )
        )
    }


    // ============================================================
    // BAR MOUSE -> VALUE
    // ============================================================

    function _valueFromMouse(
        mouse,
        sourceItem
    ) {

        if (!sourceItem)
            return value


        var local =
            sourceItem.mapToItem(
                barBox,
                mouse.x,
                mouse.y
            )


        var t


        if (horizontal) {

            if (
                controlTravel <= 0
            )

                return _min()


            t =
                (
                    local.x -
                    controlWidth / 2
                ) /
                controlTravel

        } else {

            if (
                controlTravel <= 0
            )

                return _min()


            t =
                1 -
                (
                    (
                        local.y -
                        controlHeight / 2
                    ) /
                    controlTravel
                )
        }


        t =
            _clamp(
                t,
                0,
                1
            )


        return (
            _min() +
            (
                _max() -
                _min()
            ) *
            t
        )
    }


    // ============================================================
    // BAR DRAG
    // ============================================================

    function _beginBarDrag(mouse) {

        if (!root.interactive)
            return


        dragging =
            true


        setValue(
            _valueFromMouse(
                mouse,
                barBox
            )
        )
    }


    function _dragBar(mouse) {

        if (
            !root.interactive ||
            !dragging
        )

            return


        setValue(
            _valueFromMouse(
                mouse,
                barBox
            )
        )
    }


    // ============================================================
    // CONTROL DRAG
    // ============================================================

    function _beginControlDrag(mouse) {

        if (!root.interactive)
            return


        dragging =
            true


        dragOffsetX =
            mouse.x

        dragOffsetY =
            mouse.y
    }


    function _dragControl(mouse) {

        if (
            !root.interactive ||
            !dragging
        )

            return


        var local =
            controlBox.mapToItem(
                barBox,
                mouse.x,
                mouse.y
            )


        var t


        if (horizontal) {

            if (
                controlTravel <= 0
            ) {

                setValue(
                    _min()
                )

                return
            }


            var targetLeft =
                local.x -
                dragOffsetX


            t =
                targetLeft /
                controlTravel

        } else {

            if (
                controlTravel <= 0
            ) {

                setValue(
                    _min()
                )

                return
            }


            var targetTop =
                local.y -
                dragOffsetY


            t =
                1 -
                (
                    targetTop /
                    controlTravel
                )
        }


        t =
            _clamp(
                t,
                0,
                1
            )


        setValue(
            _min() +
            (
                _max() -
                _min()
            ) *
            t
        )
    }


    function _endDrag() {

        dragging =
            false
    }


    // ============================================================
    // SCROLL
    // ============================================================

    function _scrollValue(scrollStep) {

        if (!root.interactive)
            return


        var step =
            _step()


        if (step <= 0)
            return


        var strength =
            Math.max(
                0,
                Number(
                    root.scrollStrength
                )
            )


        if (strength <= 0)
            return


        setValue(
            value +
            scrollStep *
            step *
            strength
        )
    }


    // ============================================================
    // BUTTONS
    // ============================================================

    function _buttonStep(direction) {

        if (!root.interactive)
            return


        var step =
            _step()


        if (step <= 0)
            return


        setValue(
            value +
            direction *
            step
        )
    }


    Timer {

        id: buttonHoldThresholdTimer

        interval:
            root.buttonHoldThreshold

        repeat:
            false


        onTriggered: {

            if (
                !root.interactive ||
                root.buttonDirection === 0
            )

                return


            root.buttonHolding =
                true


            buttonRepeatTimer.start()
        }
    }


    Timer {

        id: buttonRepeatTimer

        interval:
            root.buttonHoldRepeat

        repeat:
            true

        running:
            false


        onTriggered: {

            if (
                !root.interactive ||
                root.buttonDirection === 0 ||
                !root.buttonHolding
            ) {

                stop()

                return
            }


            root._buttonStep(
                root.buttonDirection
            )
        }
    }


    function _buttonPressed(direction) {

        if (!root.interactive)
            return


        buttonHoldThresholdTimer.stop()

        buttonRepeatTimer.stop()


        buttonHolding =
            false

        buttonDirection =
            direction


        _buttonStep(
            direction
        )


        buttonHoldThresholdTimer.start()
    }


    function _buttonReleased(direction) {

        if (
            buttonDirection !==
            direction
        )

            return


        buttonDirection =
            0

        buttonHolding =
            false


        buttonHoldThresholdTimer.stop()

        buttonRepeatTimer.stop()
    }


    // ============================================================
    // BAR
    // ============================================================

    CutBox {

        id: barBox


        /*
            This is the actual interaction owner.

            Item.enabled propagates to its MouseArea child,
            so interactive:false disables the CutBox input
            without modifying CutBox.qml.
        */

        enabled:
            root.interactive


        x:
            root.barX

        y:
            root.barY

        width:
            root.horizontal
                ? root.barLength
                : root.barThickness

        height:
            root.horizontal
                ? root.barThickness
                : root.barLength


        z:
            0


        interactive:
            true


        cut: ({
            topLeft:
                root.barThickness * 0.45,

            bottomRight:
                root.barThickness * 0.45
        })


        bgColor:
            root._barBackground()


        borderWidth:
            root._barBorderWidth()

        borderColor:
            root._barBorderColor()

        borderGlow:
            root._barBorderGlow()


        onPressed:
            function(mouse) {

                root._beginBarDrag(
                    mouse
                )
            }


        onPositionChanged:
            function(mouse) {

                root._dragBar(
                    mouse
                )
            }


        onReleased:
            function(mouse) {

                root._endDrag()
            }


        scrollThreshold:
            root.scrollThreshold


        onScroll:
            function(scrollStep) {

                root._scrollValue(
                    scrollStep
                )
            }
    }


    // ============================================================
    // FILL
    //
    // FULL BAR = gradient source
    // MASK      = value geometry
    //
    // gradientSource is intentionally hidden.
    // Only maskedFill is rendered.
    // ============================================================

    Item {

        id: fillLayer


        x:
            root.barX

        y:
            root.barY

        width:
            root.horizontal
                ? root.barLength
                : root.barThickness

        height:
            root.horizontal
                ? root.barThickness
                : root.barLength


        z:
            1


        // ========================================================
        // FULL BAR GRADIENT SOURCE
        // ========================================================

        Rectangle {

            id: gradientSource


            visible:
                false


            anchors.fill:
                parent


            color:
                "transparent"


            layer.enabled:
                true

            layer.smooth:
                true


            /*
                Horizontal:
                    first -> last

                Vertical:
                    last -> first

                Gradient.Vertical itself runs top -> bottom,
                while our logical vertical axis is bottom -> top.
            */

            Rectangle {

                anchors.fill:
                    parent


                visible:
                    root.horizontal


                color:
                    "transparent"


                gradient:
                    Gradient {

                        orientation:
                            Gradient.Horizontal


                        GradientStop {

                            position:
                                0.0

                            color:
                                root._gradientColor(
                                    0
                                )
                        }


                        GradientStop {

                            position:
                                0.5

                            color:
                                root._gradientMiddleColor()
                        }


                        GradientStop {

                            position:
                                1.0

                            color:
                                root._gradientColor(
                                    root._gradientCount() - 1
                                )
                        }
                    }
            }


            Rectangle {

                anchors.fill:
                    parent


                visible:
                    root.vertical


                color:
                    "transparent"


                gradient:
                    Gradient {

                        orientation:
                            Gradient.Vertical


                        GradientStop {

                            position:
                                0.0

                            color:
                                root._gradientColor(
                                    root._gradientCount() - 1
                                )
                        }


                        GradientStop {

                            position:
                                0.5

                            color:
                                root._gradientMiddleColor()
                        }


                        GradientStop {

                            position:
                                1.0

                            color:
                                root._gradientColor(
                                    0
                                )
                        }
                    }
            }
        }


        // ========================================================
        // VALUE MASK
        // ========================================================

        Shape {

            id: fillMask


            anchors.fill:
                parent


            antialiasing:
                true


            layer.enabled:
                true

            layer.smooth:
                true


            ShapePath {

                fillColor:
                    "#ffffff"

                strokeColor:
                    "transparent"

                strokeWidth:
                    0


                fillRule:
                    ShapePath.WindingFill


                PathSvg {

                    path: {

                        var thickness =
                            root.barThickness


                        var length =
                            root.barLength


                        var fill =
                            root._clamp(
                                root.fillLength,
                                0,
                                length
                            )


                        if (fill <= 0)
                            return ""


                        /*
                            Horizontal fill:
                            top-left + bottom-right
                        */

                        if (
                            root.horizontal
                        ) {

                            var tl =
                                Math.min(
                                    thickness * 0.45,
                                    fill / 2
                                )


                            var br =
                                Math.min(
                                    thickness * 0.45,
                                    fill / 2
                                )


                            return (

                                "M 0 " +
                                tl +

                                " L " +
                                tl +
                                " 0" +

                                " L " +
                                (
                                    fill - br
                                ) +
                                " 0" +

                                " L " +
                                fill +
                                " " +
                                br +

                                " L " +
                                fill +
                                " " +
                                (
                                    thickness - br
                                ) +

                                " L " +
                                (
                                    fill - br
                                ) +
                                " " +
                                thickness +

                                " L 0 " +
                                thickness +

                                " Z"
                            )
                        }


                        /*
                            Vertical fill:

                            bottom -> top

                            Same physical corner rule:
                                top-left
                                bottom-right
                        */

                        var top =
                            length -
                            fill


                        var vtl =
                            Math.min(
                                thickness * 0.45,
                                fill / 2
                            )


                        var vbr =
                            Math.min(
                                thickness * 0.45,
                                fill / 2
                            )


                        return (

                            "M 0 " +
                            (
                                top + vtl
                            ) +

                            " L " +
                            vtl +
                            " " +
                            top +

                            " L " +
                            thickness +
                            " " +
                            top +

                            " L " +
                            thickness +
                            " " +
                            (
                                length - vbr
                            ) +

                            " L " +
                            (
                                thickness - vbr
                            ) +
                            " " +
                            length +

                            " L 0 " +
                            length +

                            " Z"
                        )
                    }
                }
            }
        }


        // ========================================================
        // MASKED GRADIENT
        // ========================================================

        MultiEffect {

            id: maskedFill


            anchors.fill:
                parent


            source:
                gradientSource


            maskEnabled:
                true


            maskSource:
                fillMask


            maskInverted:
                false


            maskThresholdMin:
                0.01

            maskThresholdMax:
                1.0


            maskSpreadAtMin:
                0.0

            maskSpreadAtMax:
                0.0


            autoPaddingEnabled:
                false


            paddingRect:
                Qt.rect(
                    0,
                    0,
                    0,
                    0
                )
        }
    }


    // ============================================================
    // CONTROL
    // ============================================================

    CutBox {

        id: controlBox


        enabled:
            root.interactive


        x:
            root.controlX

        y:
            root.controlY

        width:
            root.controlWidth

        height:
            root.controlHeight


        z:
            3


        interactive:
            true


        cut: ({

            topLeft:
                root.horizontal
                    ? root.controlHeight * 0.25
                    : root.controlWidth * 0.25,

            bottomRight:
                root.horizontal
                    ? root.controlHeight * 0.25
                    : root.controlWidth * 0.25
        })


        bgColor:
            root._controlBackground()


        borderWidth:
            root._controlBorderWidth()

        borderColor:
            root._controlBorderColor()

        borderGlow:
            root._controlBorderGlow()


        onPressed:
            function(mouse) {

                root._beginControlDrag(
                    mouse
                )
            }


        onPositionChanged:
            function(mouse) {

                root._dragControl(
                    mouse
                )
            }


        onReleased:
            function(mouse) {

                root._endDrag()
            }


        scrollThreshold:
            root.scrollThreshold


        onScroll:
            function(scrollStep) {

                root._scrollValue(
                    scrollStep
                )
            }


        // ========================================================
        // CONTROL TEXT
        //
        // The text is placed inside a container whose dimensions
        // are swapped in vertical mode BEFORE rotation.
        //
        // Therefore Text.Fit measures the text in its actual
        // post-rotation available space.
        // ========================================================

        Item {

            id: controlTextContainer


            anchors.centerIn:
                parent


            /*
                Horizontal:
                    width  = control width
                    height = control height

                Vertical:
                    width  = control height
                    height = control width

                The container then rotates as one unit.
            */

            width:
                root.vertical
                    ? controlBox.height - 10
                    : controlBox.width - 10


            height:
                root.vertical
                    ? controlBox.width - 8
                    : controlBox.height - 8


            rotation:
                root.vertical
                    ? -90
                    : 0


            Text {

                id: controlText


                anchors.fill:
                    parent


                text:
                    root._formattedValue()


                color:
                    root.control &&
                    root.control.textColor !== undefined
                        ? root.control.textColor
                        : "#ffffff"


                /*
                    fontSizeOverride is the maximum/start size.

                    Text.Fit then shrinks the font when the actual
                    formatted string needs more room.
                */

                font.pixelSize:
                    root.fontSizeOverride > 0
                        ? root.fontSizeOverride
                        : Math.min(
                            controlTextContainer.width,
                            controlTextContainer.height
                        ) * 0.55


                fontSizeMode:
                    Text.Fit


                minimumPixelSize:
                    6


                font.bold:
                    true


                horizontalAlignment:
                    Text.AlignHCenter

                verticalAlignment:
                    Text.AlignVCenter


                wrapMode:
                    Text.NoWrap


                elide:
                    Text.ElideNone


                renderType:
                    Text.NativeRendering
            }
        }


        // ========================================================
        // CONTROL ANIMATION
        // ========================================================

        Behavior on x {

            NumberAnimation {

                duration:
                    70

                easing.type:
                    Easing.OutCubic
            }
        }


        Behavior on y {

            NumberAnimation {

                duration:
                    70

                easing.type:
                    Easing.OutCubic
            }
        }
    }


    // ============================================================
    // MINUS BUTTON
    // ============================================================

    Button {

        id: minusButton


        visible:
            root.btnsEnabled


        enabled:
            root.interactive &&
            root.btnsEnabled


        button:
            root.button


        text:
            "−"


        width:
            root.buttonSize

        height:
            root.buttonSize


        x:
            root.horizontal
                ? 0
                : (
                    root.width -
                    root.buttonSize
                ) / 2


        y:
            root.horizontal
                ? (
                    root.height -
                    root.buttonSize
                ) / 2
                : (
                    root.height -
                    root.buttonSize
                )


        z:
            4


        onPressed:
            function(mouse) {

                root._buttonPressed(
                    -1
                )
            }


        onReleased:
            function(mouse) {

                root._buttonReleased(
                    -1
                )
            }
    }


    // ============================================================
    // PLUS BUTTON
    // ============================================================

    Button {

        id: plusButton


        visible:
            root.btnsEnabled


        enabled:
            root.interactive &&
            root.btnsEnabled


        button:
            root.button


        text:
            "+"


        width:
            root.buttonSize

        height:
            root.buttonSize


        x:
            root.horizontal
                ? (
                    root.width -
                    root.buttonSize
                )
                : (
                    root.width -
                    root.buttonSize
                ) / 2


        y:
            root.horizontal
                ? (
                    root.height -
                    root.buttonSize
                ) / 2
                : 0


        z:
            4


        onPressed:
            function(mouse) {

                root._buttonPressed(
                    1
                )
            }


        onReleased:
            function(mouse) {

                root._buttonReleased(
                    1
                )
            }
    }


    // ============================================================
    // INITIAL VALUE
    // ============================================================

    Component.onCompleted: {

        setValue(
            _default()
        )
    }
}