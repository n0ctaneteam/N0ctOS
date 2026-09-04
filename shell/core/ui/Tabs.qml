import QtQuick

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    /*
        tabs: [
            { label: "Overview", content: Component { ... } },
            { label: "System",   content: Component { ... } }
        ]
    */
    property var tabs: []

    property int currentIndex: 0

    /*
        tabStyle drives every tab button. Either:

            tabStyle: Button.Style.CutGlow

        or a props object fed into each Button:

            tabStyle: {
                style: Button.Style.CutGlow,
                cut: { topLeft: 10 },
                textColor: "#fff"
            }
    */
    property var tabStyle: Button.Style.Default

    property int barHeight: 44
    property real buttonSpacing: 8
    property int buttonInset: 6
    property int contentPadding: 12
    property int contentGap: 8

    // ============================================================
    // BAR UNDERLINE
    // ============================================================

    property bool barLineVisible: true
    property color barLineColor: "#2a3342"
    property int barLineHeight: 3


    // ============================================================
    // SLIDE ANIMATION
    // ============================================================

    property int slideDuration: 300
    property int slideFadeDuration: 260


    // ============================================================
    // SCROLL THROTTLE
    //
    // Mirrors CutBox.scrollThreshold so the bar scroll catcher
    // rate-limits like the container does.
    // ============================================================

    property int scrollThreshold: 500
    property real lastScrollTime: -Infinity


    /*
        Injected into the container CutBox.
    */
    property var cut
    property var round
    property var bgColor
    property var borderWidth
    property var borderColor
    property var borderGlow
    property var disableBorder
    property var shadow


    // ============================================================
    // SIGNAL API
    // ============================================================

    signal tabActivated(int index)
    signal doubleClicked(var mouse)


    readonly property var currentTab:
        root.tabs[root.currentIndex] !== undefined
            ? root.tabs[root.currentIndex]
            : null


    // ============================================================
    // CONTAINER
    //
    // Scroll anywhere on the panel switches tabs.
    //
    // Clicks are left to the individual tab buttons, which are
    // rendered ABOVE this surface.
    // ============================================================

    CutBox {
        id: container

        anchors.fill: parent

        cut:
            root.cut ?? ({})

        round:
            root.round ?? ({})

        bgColor:
            root.bgColor ?? "#070b10"

        borderWidth:
            root.borderWidth ?? 2

        borderColor:
            root.borderColor ?? "#2a3342"

        borderGlow:
            root.borderGlow ?? 8

        disableBorder:
            root.disableBorder ?? ({})

        shadow:
            root.shadow ?? ({})


        onScroll: function(step) {

            root._switchOnScroll(step)
        }


        onDoubleClicked:
            root.doubleClicked(mouse)
    }


    // ============================================================
    // TAB BAR
    //
    // Buttons expand to fill the available width evenly.
    // ============================================================

    Item {
        id: bar

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        height: root.barHeight


        Row {
            id: buttonRow

            anchors {
                left: bar.left
                right: bar.right
                top: bar.top
                leftMargin: root.contentPadding
                rightMargin: root.contentPadding
            }

            height: root.barHeight

            spacing: root.buttonSpacing

            topPadding: root.buttonInset
            bottomPadding: root.buttonInset


            Repeater {
                id: buttonRepeater

                model: root.tabs

                delegate: Button {
                    id: tabButton

                    text: modelData.label

                    active:
                        index === root.currentIndex

                    height:
                        root.barHeight -
                        root.buttonInset * 2

                    width:

                        buttonRepeater.count > 0
                            ? (
                                buttonRow.width -
                                buttonRow.spacing *
                                    (buttonRepeater.count - 1)
                            ) /
                            buttonRepeater.count
                            : 0

                    onClicked:
                        root.switchTo(index)

                    Component.onCompleted:
                        root._applyTabStyle(tabButton)
                }
            }
        }
    }


    // ============================================================
    // BAR SCROLL CATCHER
    //
    // Each tab button is a Button primitive whose own mouse area
    // consumes wheel events, so scrolling over the bar never
    // reached the container below.
    //
    // This overlay is a sibling ABOVE the bar. It captures wheel
    // input over the whole bar and feeds it into the same tab
    // switch path. acceptedButtons: Qt.NoButton keeps clicks
    // passing through to the buttons beneath.
    // ============================================================

    MouseArea {
        id: barScroll

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        height: root.barHeight

        hoverEnabled: true

        acceptedButtons: Qt.NoButton

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

            root._switchOnScroll(
                delta > 0 ? 1 : -1
            )

            wheel.accepted = true
        }
    }


    // ============================================================
    // BAR UNDERLINE
    // ============================================================

    Rectangle {
        id: barLine

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: root.barHeight
            leftMargin: root.contentPadding
            rightMargin: root.contentPadding
        }

        height: root.barLineHeight

        visible: root.barLineVisible

        color: root.barLineColor
    }


    // ============================================================
    // CONTENT
    //
    // Two loaders alternate so the outgoing tab can slide out
    // while the incoming tab slides in from the matching side.
    // ============================================================

    Item {
        id: contentArea

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: parent.top
            topMargin:
                root.barHeight +
                root.barLineHeight +
                root.contentGap
            leftMargin: root.contentPadding
            rightMargin: root.contentPadding
            bottomMargin: root.contentPadding
        }

        clip: true


        Loader {
            id: contentA

            anchors.fill: parent

            visible: false

            Behavior on x {
                enabled: root._animating

                NumberAnimation {
                    duration: root.slideDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                enabled: root._animating

                NumberAnimation {
                    duration: root.slideFadeDuration
                    easing.type: Easing.OutQuad
                }
            }

            onLoaded: {

                if (contentA.item === null)
                    return

                if (contentA.item.anchors === undefined)
                    return

                contentA.item.anchors.fill = contentA
            }
        }


        Loader {
            id: contentB

            anchors.fill: parent

            visible: false

            Behavior on x {
                enabled: root._animating

                NumberAnimation {
                    duration: root.slideDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                enabled: root._animating

                NumberAnimation {
                    duration: root.slideFadeDuration
                    easing.type: Easing.OutQuad
                }
            }

            onLoaded: {

                if (contentB.item === null)
                    return

                if (contentB.item.anchors === undefined)
                    return

                contentB.item.anchors.fill = contentB
            }
        }
    }


    // ============================================================
    // SLIDE STATE
    // ============================================================

    property bool _animating: false

    property var _showLoader: null
    property var _hideLoader: null
    property var _pendingHide: null
    property int _prevIndex: -1


    Timer {
        id: _hideTimer

        interval: root.slideDuration + 40

        onTriggered: {

            if (root._pendingHide === null)
                return

            root._pendingHide.visible = false
            root._pendingHide.sourceComponent = null
            root._pendingHide.x = 0
            root._pendingHide.opacity = 1
            root._pendingHide = null
        }
    }


    Component.onCompleted: {

        root._showLoader = contentA
        root._hideLoader = contentB
        root._prevIndex = root.currentIndex

        root._present(0)
    }


    onCurrentIndexChanged: {

        var direction =
            root.currentIndex > root._prevIndex
                ? 1
                : -1

        root._present(direction)

        root._prevIndex = root.currentIndex

        root.tabActivated(root.currentIndex)
    }


    // ============================================================
    // PRESENTATION
    // ============================================================

    function _present(direction) {

        var from = root._showLoader
        var to = root._hideLoader

        // --------------------------------------------------------
        // Clear any stale outgoing loader.
        // --------------------------------------------------------

        _hideTimer.stop()

        if (root._pendingHide !== null) {

            root._pendingHide.visible = false
            root._pendingHide.sourceComponent = null
            root._pendingHide.x = 0
            root._pendingHide.opacity = 1
            root._pendingHide = null
        }


        to.sourceComponent =
            root.currentTab !== null
                ? root.currentTab.content
                : null

        to.visible = true


        // --------------------------------------------------------
        // Initial mount: snap into place without animating.
        // --------------------------------------------------------

        if (direction === 0) {

            to.x = 0
            to.opacity = 1

            root._finalize(from, to)

            return
        }


        // --------------------------------------------------------
        // Position the incoming loader off-screen (no animation).
        // --------------------------------------------------------

        root._animating = false

        to.x =
            direction > 0
                ? contentArea.width
                : -contentArea.width

        to.opacity = 0
        to.visible = true


        // --------------------------------------------------------
        // Slide in / slide out.
        // --------------------------------------------------------

        root._animating = true

        to.x = 0
        to.opacity = 1

        if (from.item !== null) {

            from.x =
                direction > 0
                    ? -contentArea.width
                    : contentArea.width

            from.opacity = 0
        }

        root._pendingHide = from

        _hideTimer.start()

        root._showLoader = to
        root._hideLoader = from
    }


    function _finalize(from, to) {

        if (
            from !== to &&
            from.item !== null
        ) {

            from.visible = false
            from.sourceComponent = null
            from.x = 0
            from.opacity = 1
        }

        root._showLoader = to
        root._hideLoader = from
    }


    // ============================================================
    // TAB STYLE INJECTION
    // ============================================================

    function _applyTabStyle(btn) {

        var s = root.tabStyle

        if (s === undefined || s === null)
            return

        if (typeof s === "object") {

            for (var key in s) {

                if (!s.hasOwnProperty(key))
                    continue

                if (
                    key === "text" ||
                    key === "active" ||
                    key === "width" ||
                    key === "height"
                ) {
                    continue
                }

                btn[key] = s[key]
            }

        } else {

            btn.style = s
        }
    }


    onTabStyleChanged: {

        for (var i = 0; i < buttonRepeater.count; i++) {

            var btn = buttonRepeater.itemAt(i)

            if (btn !== null)
                root._applyTabStyle(btn)
        }
    }


    // ============================================================
    // NAVIGATION
    // ============================================================

    function switchTo(index) {

        if (index < 0)
            index = root.tabs.length - 1

        if (index >= root.tabs.length)
            index = 0

        if (index === root.currentIndex)
            return

        root.currentIndex = index
    }


    /*
        Shared by the container CutBox and the bar scroll catcher.

        +1 = scroll up  -> previous tab
        -1 = scroll down -> next tab
    */

    function _switchOnScroll(step) {

        root.switchTo(
            root.currentIndex +
            (step > 0 ? -1 : 1)
        )
    }
}
