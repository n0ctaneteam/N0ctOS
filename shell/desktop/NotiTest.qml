import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.services

Item {
    id: root

    // ============================================================
    // STATE
    // ============================================================

    property bool isHubOpen:
        false

    property bool isHubWindowVisible:
        false

    property string hubPage:
        "active"

    property string testApp:
        "N0ctOS Test"

    property color accent:
        "#2acfff"

    property color background:
        "#090d12"

    property color panel:
        "#101720"

    property color panel2:
        "#141d26"

    property color border:
        "#263541"

    property color textPrimary:
        "#f3f7fb"

    property color textSecondary:
        "#91a1b2"

    // ============================================================
    // TEST SCREEN
    // ============================================================

    readonly property var testScreen:
        Quickshell.screens.length > 0
            ? Quickshell.screens[0]
            : null

    // ============================================================
    // CLOCK FOR TIMER BARS
    // ============================================================

    property real now:
        Date.now()

    Timer {
        interval:
            33

        repeat:
            true

        running:
            root.visible

        onTriggered:
            root.now = Date.now()
    }

    // ============================================================
    // HUB OPEN / CLOSE ANIMATION
    // ============================================================

    Timer {
        id: hubHideTimer

        interval:
            260

        repeat:
            false

        onTriggered: {
            if (!root.isHubOpen)
                root.isHubWindowVisible =
                    false
        }
    }

    onIsHubOpenChanged: {
        if (root.isHubOpen) {
            hubHideTimer.stop()
            root.isHubWindowVisible = true

            /*
             * Your rule:
             *
             * opening the notification hub marks all current
             * notifications as read.
             */
            Notifications.markAllRead()
        } else {
            hubHideTimer.restart()
        }
    }

    // ============================================================
    // TEST HELPERS
    // ============================================================

    function sendNotification(args) {
        const command =
            [
                "notify-send"
            ]

        for (
            let i = 0;
            i < args.length;
            ++i
        ) {
            command.push(
                String(args[i])
            )
        }

        Quickshell.execDetached(
            command
        )
    }

    function sendLow() {
        root.sendNotification([
            "-a",
            root.testApp,

            "-u",
            "low",

            "Low notification",

            "This is a low urgency notification."
        ])
    }

    function sendNormal() {
        root.sendNotification([
            "-a",
            root.testApp,

            "-u",
            "normal",

            "Normal notification",

            "This notification should appear as a timed popup."
        ])
    }

    function sendCritical() {
        root.sendNotification([
            "-a",
            root.testApp,

            "-u",
            "critical",

            "Critical notification",

            "This popup must stay until you manually close it."
        ])
    }

    function sendActionNotification() {
        root.sendNotification([
            "-a",
            root.testApp,

            "-u",
            "normal",

            "-A",
            "default=Open",

            "-A",
            "secondary=Secondary",

            "Action test",

            "This notification contains actions."
        ])
    }

    function sendReplyNotification() {
        root.sendNotification([
            "-a",
            root.testApp,

            "-u",
            "normal",

            "-A",
            "inline-reply=Reply",

            "-A",
            "default=Open",

            "Inline reply test",

            "This notification advertises the inline reply action."
        ])
    }

    function sendLongNotification() {
        root.sendNotification([
            "-a",
            root.testApp,

            "-u",
            "normal",

            "Long notification",

            "This is deliberately long notification text so that wrapping, popup height, action layout and the animated stack can all be tested properly."
        ])
    }

    function sendMultiTest() {
        root.sendLow()
        root.sendNormal()
        root.sendCritical()
    }

    /*
     * Simulate the separate Game Mode service.
     *
     * Notifications does NOT own this state.
     *
     * This test UI only changes the config key so you can verify
     * the notification policy.
     */
    function toggleGameModeForTest() {
        const current =
            Boolean(
                Config.get(
                    "isGameMode",
                    false
                )
            )

        Config.set(
            "isGameMode",
            !current
        )
    }

    function clearAllActiveForTest() {
        const list =
            Notifications.active.values

        for (
            let i = list.length - 1;
            i >= 0;
            --i
        ) {
            if (
                list[i] &&
                list[i].dismiss
            ) {
                list[i].dismiss()
            }
        }
    }

    function activeNotificationList() {
        return Notifications.active.values
    }

    function historyList() {
        return Notifications.history
    }

    // ============================================================
    // POPUP WINDOW
    // ============================================================

    PanelWindow {
        id: popupWindow

        screen:
            root.testScreen

        visible:
            Notifications.popupCount > 0

        color:
            "transparent"

        exclusionMode:
            ExclusionMode.Ignore

        WlrLayershell.layer:
            WlrLayer.Overlay

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        anchors {
            top: true
            right: true
        }

        implicitWidth:
            430

        implicitHeight:
            Math.min(
                popupList.contentHeight + 16,
                840
            )

        margins {
            top: 18
            right: 18
        }

        Item {
            anchors.fill:
                parent

            ListView {
                id: popupList

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                spacing:
                    10

                clip:
                    false

                model:
                    Notifications.popups

                delegate:
                    Rectangle {
                        id: popupCard

                        required property var modelData

                        width:
                            popupList.width

                        implicitHeight:
                            popupContent.implicitHeight +
                            32

                        radius:
                            14

                        color:
                            root.panel

                        border.width:
                            1

                        border.color:
                            root.border

                        opacity:
                            1

                        layer.enabled:
                            true

                        /*
                         * Entry / update animation.
                         */
                        Behavior on opacity {
                            NumberAnimation {
                                duration:
                                    180
                            }
                        }

                        /*
                         * Critical = manual.
                         * Timed = remaining progress.
                         */
                        readonly property bool isManual:
                            Number(
                                modelData.timeout
                            ) <= 0

                        readonly property real remaining:
                            isManual
                                ? 1
                                : Math.max(
                                    0,
                                    Math.min(
                                        1,
                                        (
                                            Number(
                                                modelData.expiresAt
                                            ) -
                                            root.now
                                        ) /
                                        (
                                            Number(
                                                modelData.timeout
                                            ) * 1000
                                        )
                                    )
                                )

                        ColumnLayout {
                            id: popupContent

                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }

                            anchors.margins:
                                16

                            spacing:
                                10

                            // =================================================
                            // HEADER
                            // =================================================

                            RowLayout {
                                Layout.fillWidth:
                                    true

                                spacing:
                                    10

                                Image {
                                    Layout.preferredWidth:
                                        38

                                    Layout.preferredHeight:
                                        38

                                    fillMode:
                                        Image.PreserveAspectFit

                                    source: {
                                        const n =
                                            popupCard.modelData.notification

                                        if (
                                            n &&
                                            n.image &&
                                            String(
                                                n.image
                                            ).length > 0
                                        ) {
                                            return n.image
                                        }

                                        if (
                                            n &&
                                            n.appIcon &&
                                            String(
                                                n.appIcon
                                            ).length > 0
                                        ) {
                                            return Quickshell.iconPath(
                                                n.appIcon
                                            )
                                        }

                                        return ""
                                    }

                                    asynchronous:
                                        true
                                }

                                ColumnLayout {
                                    Layout.fillWidth:
                                        true

                                    spacing:
                                        1

                                    Text {
                                        Layout.fillWidth:
                                            true

                                        text:
                                            popupCard.modelData
                                                .notification
                                                ? (
                                                    popupCard
                                                        .modelData
                                                        .notification
                                                        .appName ||
                                                    "Application"
                                                )
                                                : "Notification"

                                        color:
                                            root.textSecondary

                                        font.pixelSize:
                                            12

                                        elide:
                                            Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth:
                                            true

                                        text:
                                            popupCard.modelData
                                                .notification
                                                ? (
                                                    popupCard
                                                        .modelData
                                                        .notification
                                                        .summary ||
                                                    "Notification"
                                                )
                                                : "Notification"

                                        color:
                                            root.textPrimary

                                        font.pixelSize:
                                            16

                                        font.bold:
                                            true

                                        elide:
                                            Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth:
                                        28

                                    Layout.preferredHeight:
                                        28

                                    radius:
                                        8

                                    color:
                                        "#17212b"

                                    Text {
                                        anchors.centerIn:
                                            parent

                                        text:
                                            "󰅖"

                                        color:
                                            root.textSecondary

                                        font.family:
                                            "Symbols Nerd Font"

                                        font.pixelSize:
                                            16
                                    }

                                    MouseArea {
                                        anchors.fill:
                                            parent

                                        onClicked:
                                            Notifications.dismiss(
                                                popupCard.modelData.notificationId
                                            )
                                    }
                                }
                            }

                            // =================================================
                            // BODY
                            // =================================================

                            Text {
                                Layout.fillWidth:
                                    true

                                text:
                                    popupCard.modelData
                                        .notification
                                        ? (
                                            popupCard
                                                .modelData
                                                .notification
                                                .body ||
                                            ""
                                        )
                                        : ""

                                color:
                                    root.textSecondary

                                font.pixelSize:
                                    13

                                wrapMode:
                                    Text.WordWrap

                                textFormat:
                                    Text.AutoText

                                maximumLineCount:
                                    8
                            }

                            // =================================================
                            // ACTIONS
                            // =================================================

                            RowLayout {
                                Layout.fillWidth:
                                    true

                                spacing:
                                    6

                                visible:
                                    popupCard.modelData
                                        .notification &&
                                    popupCard.modelData
                                        .notification
                                        .actions &&
                                    popupCard.modelData
                                        .notification
                                        .actions
                                        .length > 0

                                Repeater {
                                    model:
                                        popupCard.modelData
                                            .notification
                                            ? popupCard
                                                .modelData
                                                .notification
                                                .actions
                                            : []

                                    delegate:
                                        Rectangle {
                                            required property var modelData

                                            Layout.fillWidth:
                                                true

                                            Layout.preferredHeight:
                                                34

                                            radius:
                                                9

                                            color:
                                                "#17212b"

                                            border.width:
                                                1

                                            border.color:
                                                root.border

                                            Text {
                                                anchors.centerIn:
                                                    parent

                                                text:
                                                    modelData.text

                                                color:
                                                    root.textPrimary

                                                font.pixelSize:
                                                    12
                                            }

                                            MouseArea {
                                                anchors.fill:
                                                    parent

                                                onClicked:
                                                    modelData.invoke()
                                            }
                                        }
                                }
                            }

                            // =================================================
                            // INLINE REPLY
                            // =================================================

                            RowLayout {
                                Layout.fillWidth:
                                    true

                                spacing:
                                    6

                                visible:
                                    popupCard.modelData
                                        .notification &&
                                    popupCard.modelData
                                        .notification
                                        .hasInlineReply

                                Rectangle {
                                    Layout.fillWidth:
                                        true

                                    Layout.preferredHeight:
                                        36

                                    radius:
                                        9

                                    color:
                                        "#0d141b"

                                    border.width:
                                        1

                                    border.color:
                                        root.border

                                    TextInput {
                                        id: replyInput

                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                        }

                                        anchors.leftMargin:
                                            10

                                        anchors.rightMargin:
                                            10

                                        color:
                                            root.textPrimary

                                        font.pixelSize:
                                            12

                                        clip:
                                            true

                                        selectByMouse:
                                            true

                                        Text {
                                            anchors.fill:
                                                parent

                                            visible:
                                                replyInput.text.length === 0

                                            text:
                                                popupCard.modelData
                                                    .notification
                                                    .inlineReplyPlaceholder ||
                                                "Reply…"

                                            color:
                                                root.textSecondary

                                            font.pixelSize:
                                                12

                                            verticalAlignment:
                                                Text.AlignVCenter

                                            elide:
                                                Text.ElideRight
                                        }

                                        Keys.onReturnPressed:
                                            function(event) {
                                                Notifications.reply(
                                                    popupCard.modelData
                                                        .notificationId,
                                                    replyInput.text
                                                )

                                                replyInput.clear()

                                                event.accepted =
                                                    true
                                            }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth:
                                        70

                                    Layout.preferredHeight:
                                        36

                                    radius:
                                        9

                                    color:
                                        root.accent

                                    Text {
                                        anchors.centerIn:
                                            parent

                                        text:
                                            "Send"

                                        color:
                                            "#061018"

                                        font.bold:
                                            true

                                        font.pixelSize:
                                            12
                                    }

                                    MouseArea {
                                        anchors.fill:
                                            parent

                                        onClicked: {
                                            Notifications.reply(
                                                popupCard.modelData
                                                    .notificationId,
                                                replyInput.text
                                            )

                                            replyInput.clear()
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // TIMER BAR
                        // =====================================================

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }

                            height:
                                3

                            radius:
                                2

                            color:
                                "#1b2630"

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    bottom: parent.bottom
                                }

                                width:
                                    parent.width *
                                    popupCard.remaining

                                radius:
                                    2

                                color:
                                    popupCard.isManual
                                        ? "#ff5c7a"
                                        : root.accent

                                Behavior on width {
                                    NumberAnimation {
                                        duration:
                                            60

                                        easing.type:
                                            Easing.Linear
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // URGENCY BADGE
                        // =====================================================

                        Rectangle {
                            anchors {
                                top: parent.top
                                right: parent.right
                            }

                            anchors.topMargin:
                                10

                            anchors.rightMargin:
                                44

                            height:
                                18

                            width:
                                72

                            radius:
                                9

                            color:
                                popupCard.isManual
                                    ? "#31161f"
                                    : "#14232c"

                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    popupCard.isManual
                                        ? "CRITICAL"
                                        : (
                                            root.formatUrgency(
                                                popupCard.modelData
                                                    .notification
                                            ).toUpperCase()
                                        )

                                color:
                                    popupCard.isManual
                                        ? "#ff8aa0"
                                        : root.accent

                                font.pixelSize:
                                    8

                                font.bold:
                                    true
                            }
                        }
                    }

                add:
                    Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                property:
                                    "x"

                                from:
                                    popupList.width + 50

                                to:
                                    0

                                duration:
                                    320

                                easing.type:
                                    Easing.OutCubic
                            }

                            NumberAnimation {
                                property:
                                    "opacity"

                                from:
                                    0

                                to:
                                    1

                                duration:
                                    220

                                easing.type:
                                    Easing.OutCubic
                            }
                        }
                    }

                remove:
                    Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                property:
                                    "x"

                                to:
                                    popupList.width + 50

                                duration:
                                    250

                                easing.type:
                                    Easing.InCubic
                            }

                            NumberAnimation {
                                property:
                                    "opacity"

                                to:
                                    0

                                duration:
                                    180
                            }
                        }
                    }

                displaced:
                    Transition {
                        NumberAnimation {
                            properties:
                                "y"

                            duration:
                                260

                            easing.type:
                                Easing.OutCubic
                        }
                    }
            }
        }
    }

    // ============================================================
    // TEST CONTROLS WINDOW
    // ============================================================

    PanelWindow {
        id: controlsWindow

        screen:
            root.testScreen

        visible:
            true

        color:
            "transparent"

        exclusionMode:
            ExclusionMode.Ignore

        WlrLayershell.layer:
            WlrLayer.Overlay

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        anchors {
            left: true
            bottom: true
        }

        implicitWidth:
            510

        implicitHeight:
            208

        margins {
            left: 18
            bottom: 18
        }

        Rectangle {
            anchors.fill:
                parent

            radius:
                16

            color:
                "#091016"

            border.width:
                1

            border.color:
                root.border

            ColumnLayout {
                anchors.fill:
                    parent

                anchors.margins:
                    14

                spacing:
                    8

                RowLayout {
                    Layout.fillWidth:
                        true

                    Text {
                        text:
                            "N0ctOS Notification Test"

                        color:
                            root.textPrimary

                        font.pixelSize:
                            15

                        font.bold:
                            true
                    }

                    Item {
                        Layout.fillWidth:
                            true
                    }

                    Text {
                        text:
                            Notifications.activeCount +
                            " active  •  " +
                            Notifications.historyCount +
                            " history"

                        color:
                            root.textSecondary

                        font.pixelSize:
                            10
                    }
                }

                RowLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        6

                    TestButton {
                        label:
                            "Low"

                        onClicked:
                            root.sendLow()
                    }

                    TestButton {
                        label:
                            "Normal"

                        onClicked:
                            root.sendNormal()
                    }

                    TestButton {
                        label:
                            "Critical"

                        accentColor:
                            "#ff5c7a"

                        onClicked:
                            root.sendCritical()
                    }

                    TestButton {
                        label:
                            "Actions"

                        onClicked:
                            root.sendActionNotification()
                    }

                    TestButton {
                        label:
                            "Reply"

                        onClicked:
                            root.sendReplyNotification()
                    }
                }

                RowLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        6

                    TestButton {
                        label:
                            "Long"

                        onClicked:
                            root.sendLongNotification()
                    }

                    TestButton {
                        label:
                            "Burst"

                        onClicked:
                            root.sendMultiTest()
                    }

                    TestButton {
                        label:
                            Notifications.isDnd
                                ? "DND ON"
                                : "DND OFF"

                        accentColor:
                            Notifications.isDnd
                                ? "#ffb454"
                                : root.accent

                        onClicked:
                            Notifications.toggleDnd()
                    }

                    TestButton {
                        label:
                            Notifications.isGameMode
                                ? "GAME ON"
                                : "GAME OFF"

                        accentColor:
                            Notifications.isGameMode
                                ? "#ff5c7a"
                                : root.accent

                        onClicked:
                            root.toggleGameModeForTest()
                    }
                }

                RowLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        6

                    TestButton {
                        label:
                            "Hub"

                        accentColor:
                            "#ffffff"

                        onClicked:
                            root.isHubOpen =
                                !root.isHubOpen
                    }

                    TestButton {
                        label:
                            "Mark Read"

                        onClicked:
                            Notifications.markAllRead()
                    }

                    TestButton {
                        label:
                            "Dismiss All"

                        accentColor:
                            "#ff8aa0"

                        onClicked:
                            root.clearAllActiveForTest()
                    }

                    Item {
                        Layout.fillWidth:
                            true
                    }

                    ColumnLayout {
                        spacing:
                            0

                        Text {
                            text:
                                "UNSEEN"

                            color:
                                root.textSecondary

                            font.pixelSize:
                                8
                        }

                        Text {
                            text:
                                String(
                                    Notifications.unseenCount
                                )

                            color:
                                root.accent

                            font.pixelSize:
                                16

                            font.bold:
                                true
                        }
                    }
                }

                Text {
                    Layout.fillWidth:
                        true

                    text:
                        "Game mode is read from Config.isGameMode and is not owned by Notifications."

                    color:
                        root.textSecondary

                    opacity:
                        0.8

                    font.pixelSize:
                        9

                    elide:
                        Text.ElideRight
                }
            }
        }
    }

    // ============================================================
    // NOTIFICATION HUB
    // ============================================================

    PanelWindow {
        id: hubWindow

        screen:
            root.testScreen

        visible:
            root.isHubWindowVisible

        color:
            "transparent"

        exclusionMode:
            ExclusionMode.Ignore

        WlrLayershell.layer:
            WlrLayer.Overlay

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            right: true
            bottom: true
        }

        implicitWidth:
            520

        margins {
            top: 18
            right: 18
            bottom: 18
        }

        Rectangle {
            id: hubSurface

            anchors.fill:
                parent

            radius:
                18

            color:
                root.background

            border.width:
                1

            border.color:
                root.border

            opacity:
                root.isHubOpen
                    ? 1
                    : 0

            scale:
                root.isHubOpen
                    ? 1
                    : 0.96

            Behavior on opacity {
                NumberAnimation {
                    duration:
                        220

                    easing.type:
                        Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration:
                        240

                    easing.type:
                        Easing.OutCubic
                }
            }

            ColumnLayout {
                anchors.fill:
                    parent

                anchors.margins:
                    16

                spacing:
                    10

                // =========================================================
                // HEADER
                // =========================================================

                RowLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        10

                    ColumnLayout {
                        Layout.fillWidth:
                            true

                        spacing:
                            1

                        Text {
                            text:
                                "Notifications"

                            color:
                                root.textPrimary

                            font.pixelSize:
                                20

                            font.bold:
                                true
                        }

                        Text {
                            text:
                                Notifications.unseenCount +
                                " unseen"

                            color:
                                root.textSecondary

                            font.pixelSize:
                                11
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth:
                            34

                        Layout.preferredHeight:
                            34

                        radius:
                            9

                        color:
                            "#17212b"

                        Text {
                            anchors.centerIn:
                                parent

                            text:
                                "󰌑"

                            color:
                                root.textSecondary

                            font.family:
                                "Symbols Nerd Font"

                            font.pixelSize:
                                17
                        }

                        MouseArea {
                            anchors.fill:
                                parent

                            onClicked:
                                root.isHubOpen =
                                    false
                        }
                    }
                }

                // =========================================================
                // NAVIGATION
                // =========================================================

                RowLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        5

                    HubTab {
                        label:
                            "Active"

                        selected:
                            root.hubPage === "active"

                        onClicked:
                            root.hubPage = "active"
                    }

                    HubTab {
                        label:
                            "History"

                        selected:
                            root.hubPage === "history"

                        onClicked:
                            root.hubPage = "history"
                    }

                    HubTab {
                        label:
                            "Apps"

                        selected:
                            root.hubPage === "apps"

                        onClicked:
                            root.hubPage = "apps"
                    }

                    HubTab {
                        label:
                            "Dates"

                        selected:
                            root.hubPage === "dates"

                        onClicked:
                            root.hubPage = "dates"
                    }

                    HubTab {
                        label:
                            "Urgency"

                        selected:
                            root.hubPage === "urgency"

                        onClicked:
                            root.hubPage = "urgency"
                    }
                }

                // =========================================================
                // PAGE
                // =========================================================

                Item {
                    Layout.fillWidth:
                        true

                    Layout.fillHeight:
                        true

                    // =====================================================
                    // ACTIVE PAGE
                    // =====================================================

                    ListView {
                        id: activeList

                        anchors.fill:
                            parent

                        visible:
                            root.hubPage === "active"

                        spacing:
                            8

                        clip:
                            true

                        model:
                            Notifications.active

                        delegate:
                            ActiveHubCard {
                                width:
                                    activeList.width

                                notification:
                                    modelData
                            }

                        add:
                            Transition {
                                NumberAnimation {
                                    property:
                                        "x"

                                    from:
                                        activeList.width + 40

                                    to:
                                        0

                                    duration:
                                        260

                                    easing.type:
                                        Easing.OutCubic
                                }

                                NumberAnimation {
                                    property:
                                        "opacity"

                                    from:
                                        0

                                    to:
                                        1

                                    duration:
                                        180
                                }
                            }

                        remove:
                            Transition {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property:
                                            "x"

                                        to:
                                            activeList.width + 40

                                        duration:
                                            220
                                    }

                                    NumberAnimation {
                                        property:
                                            "opacity"

                                        to:
                                            0

                                        duration:
                                            160
                                    }
                                }
                            }

                        displaced:
                            Transition {
                                NumberAnimation {
                                    properties:
                                        "y"

                                    duration:
                                        220

                                    easing.type:
                                        Easing.OutCubic
                                }
                            }
                    }

                    // =====================================================
                    // HISTORY PAGE
                    // =====================================================

                    ListView {
                        id: historyListView

                        anchors.fill:
                            parent

                        visible:
                            root.hubPage === "history"

                        spacing:
                            8

                        clip:
                            true

                        model:
                            Notifications.history

                        delegate:
                            HistoryHubCard {
                                width:
                                    historyListView.width

                                itemData:
                                    modelData
                            }
                    }

                    // =====================================================
                    // GROUPED PAGE
                    // =====================================================

                    ListView {
                        id: groupList

                        anchors.fill:
                            parent

                        visible:
                            root.hubPage === "apps" ||
                            root.hubPage === "dates" ||
                            root.hubPage === "urgency"

                        spacing:
                            10

                        clip:
                            true

                        model: {
                            if (
                                root.hubPage === "apps"
                            ) {
                                return Notifications.groupedByApps
                            }

                            if (
                                root.hubPage === "dates"
                            ) {
                                return Notifications.groupedByDate
                            }

                            return Notifications.groupedByUrgency
                        }

                        delegate:
                            Rectangle {
                                required property var modelData

                                width:
                                    groupList.width

                                implicitHeight:
                                    groupColumn.implicitHeight +
                                    24

                                radius:
                                    12

                                color:
                                    root.panel

                                border.width:
                                    1

                                border.color:
                                    root.border

                                ColumnLayout {
                                    id: groupColumn

                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                    }

                                    anchors.margins:
                                        12

                                    spacing:
                                        7

                                    RowLayout {
                                        Layout.fillWidth:
                                            true

                                        Text {
                                            Layout.fillWidth:
                                                true

                                            text:
                                                modelData.label

                                            color:
                                                root.textPrimary

                                            font.pixelSize:
                                                14

                                            font.bold:
                                                true
                                        }

                                        Text {
                                            text:
                                                String(
                                                    modelData.count
                                                )

                                            color:
                                                root.accent

                                            font.pixelSize:
                                                11

                                            font.bold:
                                                true
                                        }
                                    }

                                    Repeater {
                                        model:
                                            modelData.items

                                        delegate:
                                            Rectangle {
                                                required property var modelData

                                                Layout.fillWidth:
                                                    true

                                                implicitHeight:
                                                    58

                                                radius:
                                                    9

                                                color:
                                                    root.panel2

                                                RowLayout {
                                                    anchors.fill:
                                                        parent

                                                    anchors.margins:
                                                        9

                                                    spacing:
                                                        8

                                                    Image {
                                                        Layout.preferredWidth:
                                                            28

                                                        Layout.preferredHeight:
                                                            28

                                                        fillMode:
                                                            Image.PreserveAspectFit

                                                        source: {
                                                            if (
                                                                modelData.image &&
                                                                String(
                                                                    modelData.image
                                                                ).length > 0
                                                            ) {
                                                                return modelData.image
                                                            }

                                                            if (
                                                                modelData.appIcon &&
                                                                String(
                                                                    modelData.appIcon
                                                                ).length > 0
                                                            ) {
                                                                return Quickshell.iconPath(
                                                                    modelData.appIcon
                                                                )
                                                            }

                                                            return ""
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth:
                                                            true

                                                        spacing:
                                                            1

                                                        Text {
                                                            Layout.fillWidth:
                                                                true

                                                            text:
                                                                modelData.summary ||
                                                                "Notification"

                                                            color:
                                                                root.textPrimary

                                                            font.pixelSize:
                                                                11

                                                            elide:
                                                                Text.ElideRight
                                                        }

                                                        Text {
                                                            Layout.fillWidth:
                                                                true

                                                            text:
                                                                modelData.body ||
                                                                modelData.appName ||
                                                                ""

                                                            color:
                                                                root.textSecondary

                                                            font.pixelSize:
                                                                9

                                                            elide:
                                                                Text.ElideRight
                                                        }
                                                    }

                                                    Text {
                                                        text:
                                                            root.formatUrgencyValue(
                                                                modelData.urgency
                                                            )

                                                        color:
                                                            root.accent

                                                        font.pixelSize:
                                                            9
                                                    }
                                                }
                                            }
                                    }
                                }
                            }
                    }
                }

                // =========================================================
                // FOOTER
                // =========================================================

                RowLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        7

                    Rectangle {
                        Layout.fillWidth:
                            true

                        Layout.preferredHeight:
                            38

                        radius:
                            10

                        color:
                            Notifications.isDnd
                                ? "#302516"
                                : "#15222b"

                        Text {
                            anchors.centerIn:
                                parent

                            text:
                                Notifications.isDnd
                                    ? "DND • critical only"
                                    : "DND off • all popups"

                            color:
                                Notifications.isDnd
                                    ? "#ffb454"
                                    : root.textSecondary

                            font.pixelSize:
                                10

                            font.bold:
                                true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth:
                            105

                        Layout.preferredHeight:
                            38

                        radius:
                            10

                        color:
                            root.accent

                        Text {
                            anchors.centerIn:
                                parent

                            text:
                                "Mark all read"

                            color:
                                "#061018"

                            font.pixelSize:
                                10

                            font.bold:
                                true
                        }

                        MouseArea {
                            anchors.fill:
                                parent

                            onClicked:
                                Notifications.markAllRead()
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // INLINE COMPONENTS
    // ============================================================

    component TestButton: Rectangle {
        property string label:
            ""

        property color accentColor:
            root.accent

        signal clicked()

        Layout.fillWidth:
            true

        Layout.preferredHeight:
            31

        radius:
            8

        color:
            "#141e27"

        border.width:
            1

        border.color:
            root.border

        Text {
            anchors.centerIn:
                parent

            text:
                parent.label

            color:
                parent.accentColor

            font.pixelSize:
                10

            font.bold:
                true
        }

        MouseArea {
            anchors.fill:
                parent

            onClicked:
                parent.clicked()
        }
    }

    component HubTab: Rectangle {
        property string label:
            ""

        property bool selected:
            false

        signal clicked()

        Layout.fillWidth:
            true

        Layout.preferredHeight:
            32

        radius:
            8

        color:
            selected
                ? root.accent
                : "#121b23"

        Text {
            anchors.centerIn:
                parent

            text:
                parent.label

            color:
                parent.selected
                    ? "#061018"
                    : root.textSecondary

            font.pixelSize:
                10

            font.bold:
                true
        }

        MouseArea {
            anchors.fill:
                parent

            onClicked:
                parent.clicked()
        }
    }

    component ActiveHubCard: Rectangle {
        required property var notification

        implicitHeight:
            activeColumn.implicitHeight +
            28

        radius:
            13

        color:
            root.panel

        border.width:
            1

        border.color:
            root.border

        ColumnLayout {
            id: activeColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            anchors.margins:
                13

            spacing:
                8

            RowLayout {
                Layout.fillWidth:
                    true

                spacing:
                    9

                Image {
                    Layout.preferredWidth:
                        34

                    Layout.preferredHeight:
                        34

                    fillMode:
                        Image.PreserveAspectFit

                    source: {
                        if (
                            notification &&
                            notification.image &&
                            String(
                                notification.image
                            ).length > 0
                        ) {
                            return notification.image
                        }

                        if (
                            notification &&
                            notification.appIcon &&
                            String(
                                notification.appIcon
                            ).length > 0
                        ) {
                            return Quickshell.iconPath(
                                notification.appIcon
                            )
                        }

                        return ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        1

                    Text {
                        text:
                            notification
                                ? (
                                    notification.appName ||
                                    "Application"
                                )
                                : "Application"

                        color:
                            root.textSecondary

                        font.pixelSize:
                            10
                    }

                    Text {
                        Layout.fillWidth:
                            true

                        text:
                            notification
                                ? (
                                    notification.summary ||
                                    "Notification"
                                )
                                : "Notification"

                        color:
                            root.textPrimary

                        font.pixelSize:
                            14

                        font.bold:
                            true

                        elide:
                            Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.preferredWidth:
                        30

                    Layout.preferredHeight:
                        30

                    radius:
                        8

                    color:
                        "#17212b"

                    Text {
                        anchors.centerIn:
                            parent

                        text:
                            "󰅖"

                        color:
                            root.textSecondary

                        font.family:
                            "Symbols Nerd Font"

                        font.pixelSize:
                            16
                    }

                    MouseArea {
                        anchors.fill:
                            parent

                        onClicked:
                            Notifications.dismiss(
                                notification.id
                            )
                    }
                }
            }

            Text {
                Layout.fillWidth:
                    true

                text:
                    notification
                        ? (
                            notification.body ||
                            ""
                        )
                        : ""

                color:
                    root.textSecondary

                font.pixelSize:
                    11

                wrapMode:
                    Text.WordWrap

                maximumLineCount:
                    6
            }

            RowLayout {
                Layout.fillWidth:
                    true

                visible:
                    notification &&
                    notification.actions &&
                    notification.actions.length > 0

                spacing:
                    6

                Repeater {
                    model:
                        notification
                            ? notification.actions
                            : []

                    delegate:
                        Rectangle {
                            required property var modelData

                            Layout.fillWidth:
                                true

                            Layout.preferredHeight:
                                32

                            radius:
                                8

                            color:
                                "#16212a"

                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    modelData.text

                                color:
                                    root.textPrimary

                                font.pixelSize:
                                    10
                            }

                            MouseArea {
                                anchors.fill:
                                    parent

                                onClicked:
                                    modelData.invoke()
                            }
                        }
                }
            }

            RowLayout {
                Layout.fillWidth:
                    true

                visible:
                    notification &&
                    notification.hasInlineReply

                spacing:
                    6

                Rectangle {
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        34

                    radius:
                        8

                    color:
                        "#0d141b"

                    border.width:
                        1

                    border.color:
                        root.border

                    TextInput {
                        id: activeReplyInput

                        anchors.fill:
                            parent

                        anchors.margins:
                            8

                        color:
                            root.textPrimary

                        font.pixelSize:
                            11

                        clip:
                            true

                        Text {
                            anchors.fill:
                                parent

                            visible:
                                activeReplyInput.text.length === 0

                            text:
                                notification
                                    .inlineReplyPlaceholder ||
                                "Reply…"

                            color:
                                root.textSecondary

                            font.pixelSize:
                                11
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth:
                        62

                    Layout.preferredHeight:
                        34

                    radius:
                        8

                    color:
                        root.accent

                    Text {
                        anchors.centerIn:
                            parent

                        text:
                            "Send"

                        color:
                            "#061018"

                        font.pixelSize:
                            10

                        font.bold:
                            true
                    }

                    MouseArea {
                        anchors.fill:
                            parent

                        onClicked: {
                            Notifications.reply(
                                notification.id,
                                activeReplyInput.text
                            )

                            activeReplyInput.clear()
                        }
                    }
                }
            }
        }
    }

    component HistoryHubCard: Rectangle {
        required property var itemData

        implicitHeight:
            historyColumn.implicitHeight +
            26

        radius:
            12

        color:
            root.panel

        border.width:
            1

        border.color:
            root.border

        ColumnLayout {
            id: historyColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            anchors.margins:
                12

            spacing:
                7

            RowLayout {
                Layout.fillWidth:
                    true

                Image {
                    Layout.preferredWidth:
                        30

                    Layout.preferredHeight:
                        30

                    fillMode:
                        Image.PreserveAspectFit

                    source: {
                        if (
                            itemData.image &&
                            String(
                                itemData.image
                            ).length > 0
                        ) {
                            return itemData.image
                        }

                        if (
                            itemData.appIcon &&
                            String(
                                itemData.appIcon
                            ).length > 0
                        ) {
                            return Quickshell.iconPath(
                                itemData.appIcon
                            )
                        }

                        return ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        1

                    Text {
                        text:
                            itemData.appName ||
                            itemData.desktopEntry ||
                            "Application"

                        color:
                            root.textSecondary

                        font.pixelSize:
                            9
                    }

                    Text {
                        Layout.fillWidth:
                            true

                        text:
                            itemData.summary ||
                            "Notification"

                        color:
                            root.textPrimary

                        font.pixelSize:
                            12

                        font.bold:
                            true

                        elide:
                            Text.ElideRight
                    }
                }

                Text {
                    text:
                        itemData.isClosed
                            ? "CLOSED"
                            : "ACTIVE"

                    color:
                        itemData.isClosed
                            ? root.textSecondary
                            : root.accent

                    font.pixelSize:
                        8

                    font.bold:
                        true
                }
            }

            Text {
                Layout.fillWidth:
                    true

                text:
                    itemData.body ||
                    ""

                color:
                    root.textSecondary

                font.pixelSize:
                    10

                wrapMode:
                    Text.WordWrap

                maximumLineCount:
                    4
            }

            RowLayout {
                Layout.fillWidth:
                    true

                Text {
                    text:
                        "ID " +
                        itemData.notificationId

                    color:
                        root.textSecondary

                    font.pixelSize:
                        8
                }

                Text {
                    Layout.fillWidth:
                        true

                    text:
                        root.formatUrgencyValue(
                            itemData.urgency
                        )

                    color:
                        root.accent

                    font.pixelSize:
                        8
                }

                Text {
                    text:
                        itemData.closeReason ||
                        (
                            itemData.isClosed
                                ? "closed"
                                : "still active"
                        )

                    color:
                        root.textSecondary

                    font.pixelSize:
                        8
                }
            }
        }
    }

    // ============================================================
    // DISPLAY HELPERS
    // ============================================================

    function formatUrgency(notification) {
        if (!notification)
            return "normal"

        if (
            Notifications.isCritical(
                notification
            )
        ) {
            return "critical"
        }

        if (
            Notifications.isLow(
                notification
            )
        ) {
            return "low"
        }

        return "normal"
    }

    function formatUrgencyValue(value) {
        switch (
            Number(value)
        ) {
        case 0:
            return "low"

        case 2:
            return "critical"

        default:
            return "normal"
        }
    }
}