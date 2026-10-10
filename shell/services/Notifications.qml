pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property var active:
        notificationServer.trackedNotifications

    readonly property var activeList:
        notificationServer.trackedNotifications.values

    readonly property int activeCount:
        notificationServer.trackedNotifications.values.length

    readonly property var history:
        root._history

    readonly property int historyCount:
        root._history.length

    readonly property var popups:
        root._popups

    readonly property int popupCount:
        root._popups.length

    readonly property int unseenCount:
        root._unseenCount

    readonly property bool hasUnseen:
        root._unseenCount > 0

    readonly property bool isDnd:
        root._isDnd

    /*
     * Game mode belongs to another service.
     *
     * Notifications only READ this config state.
     * Notifications never expose a setGameMode() API and never
     * claim ownership of this state.
     */
    readonly property bool isGameMode: {
        const revision = root._configRevision
        return root._toBool(
            Config.get(
                "isGameMode",
                false
            ),
            false
        )
    }

    readonly property bool groupingEnabled:
        root._groupingEnabled

    readonly property int historySize:
        root._historySize

    readonly property real lowPopupTimeout:
        root._lowPopupTimeout

    readonly property real normalPopupTimeout:
        root._normalPopupTimeout

    /*
     * Critical popups are intentionally permanent.
     *
     * 0 = manual close required.
     */
    readonly property real criticalPopupTimeout:
        0

    readonly property var groupedByApps:
        root._groupHistoryBy(
            "app"
        )

    readonly property var groupedByDate:
        root._groupHistoryBy(
            "date"
        )

    readonly property var groupedByUrgency:
        root._groupHistoryBy(
            "urgency"
        )

    // ============================================================
    // INTERNAL CONFIG STATE
    // ============================================================

    property bool _isDnd:
        false

    property int _historySize:
        100

    property real _lowPopupTimeout:
        3

    property real _normalPopupTimeout:
        5

    property bool _groupingEnabled:
        true

    property int _configRevision:
        0

    // ============================================================
    // INTERNAL HISTORY STATE
    // ============================================================

    property var _history:
        []

    property int _unseenCount:
        0

    property bool _historyLoaded:
        false

    property bool _historyLoading:
        false

    // ============================================================
    // INTERNAL POPUP STATE
    // ============================================================

    /*
     * Every object in _popups has the form:
     *
     * {
     *     notification: Notification,
     *     notificationId: int,
     *     timeout: real,
     *     startedAt: number,
     *     expiresAt: number
     * }
     *
     * timeout is expressed in seconds.
     *
     * timeout === 0 means:
     *
     *     manual close
     */
    property var _popups:
        []

    // ============================================================
    // INTERNAL OBSERVERS
    // ============================================================

    /*
     * One Connections object per live notification.
     *
     * This is important because replacement notifications do NOT
     * emit NotificationServer.notification again. Instead,
     * Quickshell updates the existing Notification object in place.
     *
     * Watching its property signals means:
     *
     *     popup delegate remains the same object
     *     history entry remains the same entry
     *     metadata updates reactively
     *
     * This matches the required replacement semantics.
     */
    property var _observers:
        ({})

    // ============================================================
    // NATIVE NOTIFICATION SERVER
    // ============================================================

    NotificationServer {
        id: notificationServer

        /*
         * We completely own notification reception here.
         *
         * No UI component should create its own NotificationServer.
         */
        actionsSupported:
            true

        bodySupported:
            true

        bodyHyperlinksSupported:
            true

        bodyMarkupSupported:
            true

        bodyImagesSupported:
            true

        imageSupported:
            true

        actionIconsSupported:
            true

        inlineReplySupported:
            true

        persistenceSupported:
            true

        /*
         * Re-emit notifications from the previous generation.
         *
         * lastGeneration is exposed on Notification so the service
         * can avoid duplicating history/unseen/popup handling.
         */
        keepOnReload:
            true

        onNotification:
            function(notification) {
                root._receiveNotification(
                    notification
                )
            }
    }

    // ============================================================
    // PERSISTENT HISTORY FILE
    // ============================================================

    FileView {
        id: historyFile

        path:
            Quickshell.dataPath(
                "notifications.json"
            )

        blockLoading:
            true

        printErrors:
            true

        watchChanges:
            false

        onLoadedChanged: {
            if (!loaded)
                return

            root._loadHistory()
        }
    }

    // ============================================================
    // CONFIG REACTIVITY
    // ============================================================

    Connections {
        target:
            Config

        function onExternalReload() {
            root._syncConfig()
        }
    }

    readonly property int _observedConfigRevision:
        Config.revision

    on_ObservedConfigRevisionChanged: {
        if (!Config.isReady)
            return

        root._syncConfig()
    }

    // ============================================================
    // POPUP EXPIRATION CLOCK
    // ============================================================

    /*
     * This is NOT system polling.
     *
     * It only exists while popup timing needs to be evaluated.
     *
     * The timer drives expiry of our UI popup descriptors.
     * It NEVER calls Notification.expire().
     *
     * Therefore:
     *
     *     popup disappears
     *     notification remains active
     */
    Timer {
        id: popupExpiryTimer

        interval:
            100

        repeat:
            true

        running:
            root._hasTimedPopups()

        onTriggered:
            root._expirePopups()
    }

    // ============================================================
    // STARTUP
    // ============================================================

    Component.onCompleted: {
        root._syncConfig()

        /*
         * blockLoading=true allows the persistent history to be
         * synchronously consumed once the FileView is ready.
         */
        root._loadHistory()
    }

    onIsGameModeChanged: {
        root._applyPopupPolicy()
    }

    onIsDndChanged: {
        root._applyPopupPolicy()
    }

    // ============================================================
    // BASIC HELPERS
    // ============================================================

    function _toBool(value, fallback) {
        if (typeof value === "boolean")
            return value

        if (value === 1 || value === 0)
            return value === 1

        const text =
            String(
                value === undefined ||
                value === null
                    ? ""
                    : value
            )
            .trim()
            .toLowerCase()

        if (
            text === "true" ||
            text === "yes" ||
            text === "on" ||
            text === "1"
        ) {
            return true
        }

        if (
            text === "false" ||
            text === "no" ||
            text === "off" ||
            text === "0"
        ) {
            return false
        }

        return fallback
    }

    function _number(value, fallback) {
        const n =
            Number(value)

        return isFinite(n)
            ? n
            : fallback
    }

    function _integer(value, fallback) {
        const n =
            Number(value)

        return isFinite(n)
            ? Math.round(n)
            : fallback
    }

    function _clamp(value, minimum, maximum) {
        return Math.max(
            minimum,
            Math.min(
                maximum,
                value
            )
        )
    }

    function _now() {
        return Date.now()
    }

    // ============================================================
    // URGENCY
    // ============================================================

    /*
     * Quickshell exposes exactly three standard notification
     * urgencies:
     *
     *     0 = Low
     *     1 = Normal
     *     2 = Critical
     *
     * We intentionally do not invent a fourth native urgency.
     */
    function isLow(notification) {
        return (
            root._urgency(
                notification
            ) === 0
        )
    }

    function isNormal(notification) {
        return (
            root._urgency(
                notification
            ) === 1
        )
    }

    function isCritical(notification) {
        return (
            root._urgency(
                notification
            ) === 2
        )
    }

    function urgencyName(notification) {
        return root._urgencyName(
            root._urgency(
                notification
            )
        )
    }

    function _urgency(notification) {
        if (!notification)
            return 1

        const value =
            Number(
                notification.urgency
            )

        if (
            value === 0 ||
            value === 1 ||
            value === 2
        ) {
            return value
        }

        return 1
    }

    function _urgencyName(value) {
        switch (Number(value)) {
        case 0:
            return "low"

        case 2:
            return "critical"

        default:
            return "normal"
        }
    }

    // ============================================================
    // CONFIG READ
    // ============================================================

    function _syncConfig() {
        if (!Config.isReady)
            return

        const raw =
            Config.get(
                "notifications",
                {}
            )

        const config =
            raw &&
            typeof raw === "object"
                ? raw
                : {}

        const popup =
            config.popupTimeout &&
            typeof config.popupTimeout === "object"
                ? config.popupTimeout
                : {}

        const grouping =
            config.grouping &&
            typeof config.grouping === "object"
                ? config.grouping
                : {}

        const nextDnd =
            root._toBool(
                config.dnd,
                false
            )

        const nextHistorySize =
            Math.max(
                1,
                Math.min(
                    5000,
                    root._integer(
                        config.historySize,
                        100
                    )
                )
            )

        const nextLowTimeout =
            Math.max(
                0.1,
                root._number(
                    popup.low,
                    3
                )
            )

        const nextNormalTimeout =
            Math.max(
                0.1,
                root._number(
                    popup.normal,
                    5
                )
            )

        const nextGroupingEnabled =
            root._toBool(
                grouping.enabled,
                true
            )

        const dndChanged =
            root._isDnd !==
            nextDnd

        const historySizeChanged =
            root._historySize !==
            nextHistorySize

        const lowChanged =
            root._lowPopupTimeout !==
            nextLowTimeout

        const normalChanged =
            root._normalPopupTimeout !==
            nextNormalTimeout

        const groupingChanged =
            root._groupingEnabled !==
            nextGroupingEnabled

        root._isDnd =
            nextDnd

        root._historySize =
            nextHistorySize

        root._lowPopupTimeout =
            nextLowTimeout

        root._normalPopupTimeout =
            nextNormalTimeout

        root._groupingEnabled =
            nextGroupingEnabled

        if (
            historySizeChanged &&
            root._history.length >
                root._historySize
        ) {
            root._history =
                root._history.slice(
                    0,
                    root._historySize
                )

            root._saveHistory()
        }

        if (
            dndChanged ||
            groupingChanged ||
            lowChanged ||
            normalChanged
        ) {
            root._applyPopupPolicy()
        }
    }

    function _writeConfig(next) {
        if (!Config.isReady)
            return false

        const currentRaw =
            Config.get(
                "notifications",
                {}
            )

        const current =
            currentRaw &&
            typeof currentRaw === "object"
                ? currentRaw
                : {}

        const merged =
            JSON.parse(
                JSON.stringify(
                    current
                )
            )

        if (!merged.popupTimeout)
            merged.popupTimeout = {}

        if (!merged.grouping)
            merged.grouping = {}

        if (
            next &&
            next.dnd !== undefined
        ) {
            merged.dnd =
                Boolean(next.dnd)
        }

        if (
            next &&
            next.historySize !== undefined
        ) {
            merged.historySize =
                Math.max(
                    1,
                    Math.min(
                        5000,
                        Math.round(
                            Number(
                                next.historySize
                            )
                        )
                    )
                )
        }

        if (
            next &&
            next.lowPopupTimeout !== undefined
        ) {
            merged.popupTimeout.low =
                Math.max(
                    0.1,
                    Number(
                        next.lowPopupTimeout
                    )
                )
        }

        if (
            next &&
            next.normalPopupTimeout !== undefined
        ) {
            merged.popupTimeout.normal =
                Math.max(
                    0.1,
                    Number(
                        next.normalPopupTimeout
                    )
                )
        }

        if (
            next &&
            next.groupingEnabled !== undefined
        ) {
            merged.grouping.enabled =
                Boolean(
                    next.groupingEnabled
                )
        }

        return Config.set(
            "notifications",
            merged
        )
    }

    // ============================================================
    // PERSISTENT HISTORY
    // ============================================================

    function _loadHistory() {
        if (
            root._historyLoaded ||
            root._historyLoading
        ) {
            return
        }

        if (!historyFile.loaded)
            return

        root._historyLoading =
            true

        try {
            const raw =
                historyFile.text()

            if (
                !raw ||
                !String(raw).trim()
            ) {
                root._history = []
                root._unseenCount = 0
                root._historyLoaded = true
                root._historyLoading = false
                return
            }

            const data =
                JSON.parse(
                    raw
                )

            if (
                data &&
                Array.isArray(
                    data.items
                )
            ) {
                root._history =
                    data.items.slice(
                        0,
                        root._historySize
                    )
            } else {
                root._history = []
            }

            root._unseenCount =
                Math.max(
                    0,
                    root._integer(
                        data
                            ? data.unseenCount
                            : 0,
                        0
                    )
                )
        } catch (error) {
            console.warn(
                "[Notifications] history parse failed:",
                error
            )

            root._history = []
            root._unseenCount = 0
        }

        root._historyLoaded =
            true

        root._historyLoading =
            false
    }

    function _saveHistory() {
        if (
            !root._historyLoaded ||
            root._historyLoading
        ) {
            return false
        }

        const payload = {
            version: 1,
            unseenCount:
                root._unseenCount,
            items:
                root._history.slice(
                    0,
                    root._historySize
                )
        }

        try {
            historyFile.setText(
                JSON.stringify(
                    payload,
                    null,
                    2
                )
            )

            return true
        } catch (error) {
            console.warn(
                "[Notifications] history save failed:",
                error
            )

            return false
        }
    }

    // ============================================================
    // ACTION SNAPSHOTS
    // ============================================================

    function _snapshotActions(notification) {
        const result = []

        if (!notification)
            return result

        const actions =
            notification.actions

        if (!Array.isArray(actions))
            return result

        for (
            let i = 0;
            i < actions.length;
            ++i
        ) {
            const action =
                actions[i]

            if (!action)
                continue

            result.push({
                identifier:
                    String(
                        action.identifier ||
                        ""
                    ),

                text:
                    String(
                        action.text ||
                        ""
                    )
            })
        }

        return result
    }

    // ============================================================
    // NOTIFICATION SNAPSHOT
    // ============================================================

    function _snapshot(
        notification,
        receivedAt,
        previous
    ) {
        const old =
            previous || {}

        return {
            notificationId:
                Number(
                    notification.id
                ),

            receivedAt:
                old.receivedAt !== undefined
                    ? Number(
                        old.receivedAt
                    )
                    : Number(
                        receivedAt
                    ),

            closedAt:
                old.closedAt !== undefined
                    ? old.closedAt
                    : null,

            isClosed:
                old.isClosed !== undefined
                    ? Boolean(
                        old.isClosed
                    )
                    : false,

            closeReason:
                old.closeReason || "",

            closeReasonCode:
                old.closeReasonCode !== undefined
                    ? Number(
                        old.closeReasonCode
                    )
                    : 0,

            lastGeneration:
                Boolean(
                    notification.lastGeneration
                ),

            appName:
                String(
                    notification.appName ||
                    ""
                ),

            appIcon:
                String(
                    notification.appIcon ||
                    ""
                ),

            desktopEntry:
                String(
                    notification.desktopEntry ||
                    ""
                ),

            summary:
                String(
                    notification.summary ||
                    ""
                ),

            body:
                String(
                    notification.body ||
                    ""
                ),

            image:
                String(
                    notification.image ||
                    ""
                ),

            urgency:
                root._urgency(
                    notification
                ),

            expireTimeout:
                Number(
                    notification.expireTimeout ||
                    0
                ),

            resident:
                Boolean(
                    notification.resident
                ),

            transient:
                Boolean(
                    notification.transient
                ),

            hasInlineReply:
                Boolean(
                    notification.hasInlineReply
                ),

            inlineReplyPlaceholder:
                String(
                    notification.inlineReplyPlaceholder ||
                    ""
                ),

            actions:
                root._snapshotActions(
                    notification
                )
        }
    }

    // ============================================================
    // HISTORY INDEX
    // ============================================================

    function _historyIndex(notificationId) {
        const target =
            Number(
                notificationId
            )

        for (
            let i = 0;
            i < root._history.length;
            ++i
        ) {
            if (
                Number(
                    root._history[i]
                        .notificationId
                ) === target
            ) {
                return i
            }
        }

        return -1
    }

    // ============================================================
    // CREATE / UPDATE HISTORY ENTRY
    // ============================================================

    function _upsertHistory(
        notification,
        incrementUnseen
    ) {
        if (!notification)
            return

        const id =
            Number(
                notification.id
            )

        const index =
            root._historyIndex(
                id
            )

        const now =
            root._now()

        if (index < 0) {
            root._history.unshift(
                root._snapshot(
                    notification,
                    now,
                    null
                )
            )

            if (
                incrementUnseen &&
                !notification.lastGeneration
            ) {
                root._unseenCount += 1
            }
        } else {
            const old =
                root._history[index]

            const updated =
                root._snapshot(
                    notification,
                    now,
                    old
                )

            root._history[index] =
                updated
        }

        if (
            root._history.length >
            root._historySize
        ) {
            root._history =
                root._history.slice(
                    0,
                    root._historySize
                )
        }

        /*
         * Force the array binding to reevaluate.
         */
        root._history =
            root._history.slice()

        root._saveHistory()
    }

    // ============================================================
    // NOTIFICATION CLOSED
    // ============================================================

    function _notificationClosed(
        notification,
        reason
    ) {
        if (!notification)
            return

        const id =
            Number(
                notification.id
            )

        /*
         * The notification object is still valid while this signal
         * handler executes, so snapshot all properties now.
         */
        let closeReason = ""
        let closeReasonCode =
            Number(reason)

        switch (closeReasonCode) {
        case 1:
            closeReason = "expired"
            break

        case 2:
            closeReason = "dismissed"
            break

        case 3:
            closeReason = "close-requested"
            break

        default:
            closeReason = "unknown"
            break
        }

        const index =
            root._historyIndex(
                id
            )

        const now =
            root._now()

        if (index < 0) {
            const item =
                root._snapshot(
                    notification,
                    now,
                    null
                )

            item.closedAt =
                now

            item.isClosed =
                true

            item.closeReason =
                closeReason

            item.closeReasonCode =
                closeReasonCode

            root._history.unshift(
                item
            )
        } else {
            const old =
                root._history[index]

            const item =
                root._snapshot(
                    notification,
                    now,
                    old
                )

            item.closedAt =
                now

            item.isClosed =
                true

            item.closeReason =
                closeReason

            item.closeReasonCode =
                closeReasonCode

            root._history[index] =
                item
        }

        root._removePopup(
            id
        )

        root._history =
            root._history.slice(
                0,
                root._historySize
            )

        root._saveHistory()

        /*
         * Destroy the observer after processing the close signal.
         */
        root._destroyObserver(
            id
        )
    }

    // ============================================================
    // LIVE NOTIFICATION UPDATE
    // ============================================================

    function _notificationUpdated(notification) {
        if (!notification)
            return

        /*
         * Replacement IDs update this same object.
         *
         * The history entry is updated in place conceptually:
         * same notificationId, same history position.
         */
        root._upsertHistory(
            notification,
            false
        )
    }

    // ============================================================
    // OBSERVER COMPONENT
    // ============================================================

    Component {
        id: observerComponent

        Connections {
            property var observedNotification:
                null

            target:
                observedNotification

            function onClosed(reason) {
                root._notificationClosed(
                    observedNotification,
                    reason
                )
            }

            function onExpireTimeoutChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onAppNameChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onAppIconChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onSummaryChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onBodyChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onUrgencyChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onActionsChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onHasActionIconsChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onResidentChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onTransientChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onDesktopEntryChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onImageChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onHasInlineReplyChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onInlineReplyPlaceholderChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }

            function onHintsChanged() {
                root._notificationUpdated(
                    observedNotification
                )
            }
        }
    }

    // ============================================================
    // OBSERVER MANAGEMENT
    // ============================================================

    function _observeNotification(
        notification
    ) {
        if (!notification)
            return

        const id =
            String(
                notification.id
            )

        if (
            root._observers[id] !== undefined &&
            root._observers[id] !== null
        ) {
            return
        }

        const observer =
            observerComponent.createObject(
                root,
                {
                    observedNotification:
                        notification
                }
            )

        if (!observer) {
            console.warn(
                "[Notifications] failed to create observer for:",
                id
            )

            return
        }

        const nextObservers =
            Object.assign(
                {},
                root._observers
            )

        nextObservers[id] =
            observer

        root._observers =
            nextObservers
    }

    function _destroyObserver(
        notificationId
    ) {
        const id =
            String(
                notificationId
            )

        const observer =
            root._observers[id]

        if (!observer)
            return

        const nextObservers =
            Object.assign(
                {},
                root._observers
            )

        delete nextObservers[id]

        root._observers =
            nextObservers

        observer.destroy()
    }

    // ============================================================
    // RECEIVE
    // ============================================================

    function _receiveNotification(
        notification
    ) {
        if (!notification)
            return

        /*
         * CRITICAL:
         *
         * Quickshell explicitly requires tracked=true from the
         * notification handler, otherwise the notification is
         * immediately discarded.
         */
        notification.tracked =
            true

        root._observeNotification(
            notification
        )

        /*
         * Every notification enters history.
         *
         * lastGeneration notifications are restored state, so they
         * must not increment unseen count or create a fresh popup.
         */
        root._upsertHistory(
            notification,
            !notification.lastGeneration
        )

        if (
            notification.lastGeneration
        ) {
            console.info(
                "[Notifications] restored:",
                notification.id
            )

            return
        }

        console.info(
            "[Notifications] received:",
            notification.id,
            notification.appName,
            root.urgencyName(
                notification
            )
        )

        if (
            root._shouldPopup(
                notification
            )
        ) {
            root._addPopup(
                notification
            )
        }
    }

    // ============================================================
    // POPUP POLICY
    // ============================================================

    function _shouldPopup(notification) {
        if (!notification)
            return false

        /*
         * 1. Game mode always wins.
         */
        if (root.isGameMode)
            return false

        /*
         * 2. DND permits ONLY critical notifications.
         */
        if (root.isDnd)
            return root.isCritical(
                notification
            )

        /*
         * 3. Normal mode: everything.
         */
        return true
    }

    // ============================================================
    // POPUP TIMEOUT
    // ============================================================

    function _popupTimeout(notification) {
        if (
            root.isCritical(
                notification
            )
        ) {
            /*
             * Critical popup:
             *
             * no automatic expiry
             * user must dismiss manually
             */
            return 0
        }

        if (
            root.isLow(
                notification
            )
        ) {
            return root._lowPopupTimeout
        }

        return root._normalPopupTimeout
    }

    // ============================================================
    // ADD POPUP
    // ============================================================

    function _addPopup(notification) {
        if (!notification)
            return

        if (
            !root._shouldPopup(
                notification
            )
        ) {
            return
        }

        const id =
            Number(
                notification.id
            )

        /*
         * A replacement notification uses the same native ID.
         * Never create a second popup for it.
         */
        for (
            let i = 0;
            i < root._popups.length;
            ++i
        ) {
            if (
                Number(
                    root._popups[i]
                        .notificationId
                ) === id
            ) {
                return
            }
        }

        const timeout =
            root._popupTimeout(
                notification
            )

        const startedAt =
            root._now()

        const entry = {
            notification:
                notification,

            notificationId:
                id,

            timeout:
                timeout,

            startedAt:
                startedAt,

            expiresAt:
                timeout > 0
                    ? startedAt +
                      timeout * 1000
                    : 0
        }

        const next =
            root._popups.slice()

        /*
         * Newest notifications appear first.
         */
        next.unshift(
            entry
        )

        root._popups =
            next
    }

    // ============================================================
    // POPUP REMOVE
    // ============================================================

    function _removePopup(
        notificationId
    ) {
        const target =
            Number(
                notificationId
            )

        const next = []

        for (
            let i = 0;
            i < root._popups.length;
            ++i
        ) {
            const entry =
                root._popups[i]

            if (
                Number(
                    entry.notificationId
                ) !== target
            ) {
                next.push(
                    entry
                )
            }
        }

        if (
            next.length !==
            root._popups.length
        ) {
            root._popups =
                next
        }
    }

    // ============================================================
    // POPUP TIMER
    // ============================================================

    function _hasTimedPopups() {
        for (
            let i = 0;
            i < root._popups.length;
            ++i
        ) {
            if (
                Number(
                    root._popups[i].timeout
                ) > 0
            ) {
                return true
            }
        }

        return false
    }

    function _expirePopups() {
        if (
            root._popups.length === 0
        ) {
            return
        }

        const now =
            root._now()

        const next = []

        for (
            let i = 0;
            i < root._popups.length;
            ++i
        ) {
            const entry =
                root._popups[i]

            /*
             * Critical = permanent popup.
             */
            if (
                Number(
                    entry.timeout
                ) <= 0
            ) {
                next.push(
                    entry
                )

                continue
            }

            if (
                Number(
                    entry.expiresAt
                ) > now
            ) {
                next.push(
                    entry
                )

                continue
            }

            /*
             * Popup expired.
             *
             * IMPORTANT:
             *
             * We DO NOT call notification.expire().
             *
             * The notification remains active.
             */
        }

        if (
            next.length !==
            root._popups.length
        ) {
            root._popups =
                next
        }
    }

    // ============================================================
    // APPLY CURRENT POPUP POLICY
    // ============================================================

    function _applyPopupPolicy() {
        if (
            root._popups.length === 0
        ) {
            return
        }

        const next = []

        for (
            let i = 0;
            i < root._popups.length;
            ++i
        ) {
            const entry =
                root._popups[i]

            if (
                !entry.notification
            ) {
                continue
            }

            if (
                root._shouldPopup(
                    entry.notification
                )
            ) {
                next.push(
                    entry
                )
            }
        }

        root._popups =
            next
    }

    // ============================================================
    // ACTIVE LOOKUP
    // ============================================================

    function _findActive(
        notificationId
    ) {
        const target =
            Number(
                notificationId
            )

        const list =
            notificationServer
                .trackedNotifications
                .values

        for (
            let i = 0;
            i < list.length;
            ++i
        ) {
            const notification =
                list[i]

            if (
                notification &&
                Number(
                    notification.id
                ) === target
            ) {
                return notification
            }
        }

        return null
    }

    // ============================================================
    // ACTIVE SNAPSHOT API
    // ============================================================

    function _activeSnapshot(
        notification
    ) {
        if (!notification)
            return null

        return root._snapshot(
            notification,
            root._now(),
            null
        )
    }

    // ============================================================
    // GROUPING
    // ============================================================

    function _groupHistoryBy(
        type
    ) {
        if (!root.groupingEnabled)
            return []

        const buckets = ({})

        for (
            let i = 0;
            i < root._history.length;
            ++i
        ) {
            const item =
                root._history[i]

            let key = ""
            let label = ""

            if (type === "app") {
                key =
                    item.appName ||
                    item.desktopEntry ||
                    "Unknown"

                label =
                    key
            } else if (type === "date") {
                const timestamp =
                    Number(
                        item.receivedAt
                    )

                const date =
                    new Date(
                        isFinite(timestamp)
                            ? timestamp
                            : root._now()
                    )

                key =
                    date
                        .toISOString()
                        .slice(
                            0,
                            10
                        )

                label =
                    key
            } else {
                key =
                    root._urgencyName(
                        item.urgency
                    )

                label =
                    key
            }

            if (
                !buckets[key]
            ) {
                buckets[key] = {
                    key: key,
                    label: label,
                    count: 0,
                    items: []
                }
            }

            buckets[key].items.push(
                item
            )

            buckets[key].count += 1
        }

        const result = []

        const keys =
            Object.keys(
                buckets
            )

        for (
            let i = 0;
            i < keys.length;
            ++i
        ) {
            result.push(
                buckets[
                    keys[i]
                ]
            )
        }

        return result
    }

    // ============================================================
    // DND API
    // ============================================================

    function setDnd(value) {
        const next =
            Boolean(value)

        if (
            root.isDnd === next
        ) {
            return true
        }

        root._isDnd =
            next

        root._writeConfig({
            dnd: next
        })

        root._applyPopupPolicy()

        return true
    }

    function toggleDnd() {
        return root.setDnd(
            !root.isDnd
        )
    }

    // ============================================================
    // UNSEEN API
    // ============================================================

    function markAllRead() {
        if (
            root._unseenCount === 0
        ) {
            return
        }

        root._unseenCount =
            0

        root._saveHistory()
    }

    // ============================================================
    // DISMISS
    // ============================================================

    function dismiss(
        notificationId
    ) {
        const notification =
            root._findActive(
                notificationId
            )

        if (!notification)
            return false

        root._removePopup(
            notificationId
        )

        notification.dismiss()

        return true
    }

    // ============================================================
    // EXPIRE
    // ============================================================

    function expire(
        notificationId
    ) {
        const notification =
            root._findActive(
                notificationId
            )

        if (!notification)
            return false

        root._removePopup(
            notificationId
        )

        notification.expire()

        return true
    }

    // ============================================================
    // ACTION API
    // ============================================================

    function invokeAction(
        notificationId,
        identifier
    ) {
        const notification =
            root._findActive(
                notificationId
            )

        if (!notification)
            return false

        const target =
            String(
                identifier || ""
            )

        if (!target)
            return false

        const actions =
            notification.actions

        if (!Array.isArray(actions))
            return false

        for (
            let i = 0;
            i < actions.length;
            ++i
        ) {
            const action =
                actions[i]

            if (!action)
                continue

            if (
                String(
                    action.identifier
                ) === target
            ) {
                action.invoke()
                return true
            }
        }

        return false
    }

    function invokeDefaultAction(
        notificationId
    ) {
        const notification =
            root._findActive(
                notificationId
            )

        if (!notification)
            return false

        const actions =
            notification.actions

        if (!Array.isArray(actions))
            return false

        /*
         * Prefer the standard "default" action.
         */
        for (
            let i = 0;
            i < actions.length;
            ++i
        ) {
            const action =
                actions[i]

            if (
                action &&
                String(
                    action.identifier
                ) === "default"
            ) {
                action.invoke()
                return true
            }
        }

        /*
         * Fallback:
         *
         * first available action.
         */
        for (
            let i = 0;
            i < actions.length;
            ++i
        ) {
            const action =
                actions[i]

            if (action) {
                action.invoke()
                return true
            }
        }

        return false
    }

    // ============================================================
    // INLINE REPLY
    // ============================================================

    function reply(
        notificationId,
        replyText
    ) {
        const notification =
            root._findActive(
                notificationId
            )

        if (!notification)
            return false

        if (
            !notification.hasInlineReply
        ) {
            return false
        }

        notification.sendInlineReply(
            String(
                replyText || ""
            )
        )

        return true
    }

    // ============================================================
    // POPUP CONTROL
    // ============================================================

    function removePopup(
        notificationId
    ) {
        const before =
            root._popups.length

        root._removePopup(
            notificationId
        )

        return (
            root._popups.length <
            before
        )
    }

    // ============================================================
    // HISTORY / DATA API
    // ============================================================

    function getStatus() {
        return {
            isDnd:
                root.isDnd,

            isGameMode:
                root.isGameMode,

            activeCount:
                root.activeCount,

            historyCount:
                root.historyCount,

            popupCount:
                root.popupCount,

            unseenCount:
                root.unseenCount,

            hasUnseen:
                root.hasUnseen,

            groupingEnabled:
                root.groupingEnabled,

            historySize:
                root.historySize,

            lowPopupTimeout:
                root.lowPopupTimeout,

            normalPopupTimeout:
                root.normalPopupTimeout,

            criticalPopupTimeout:
                0
        }
    }

    function activeData() {
        const result = []

        const list =
            notificationServer
                .trackedNotifications
                .values

        for (
            let i = 0;
            i < list.length;
            ++i
        ) {
            const item =
                root._activeSnapshot(
                    list[i]
                )

            if (item)
                result.push(
                    item
                )
        }

        return result
    }

    function historyData() {
        return root._history.slice()
    }

    function popupData() {
        const result = []

        for (
            let i = 0;
            i < root._popups.length;
            ++i
        ) {
            const entry =
                root._popups[i]

            result.push({
                notificationId:
                    Number(
                        entry.notificationId
                    ),

                timeout:
                    Number(
                        entry.timeout
                    ),

                startedAt:
                    Number(
                        entry.startedAt
                    ),

                expiresAt:
                    Number(
                        entry.expiresAt
                    )
            })
        }

        return result
    }

    function groupsData(type) {
        switch (
            String(type || "")
                .toLowerCase()
        ) {
        case "apps":
        case "app":
            return root.groupedByApps

        case "dates":
        case "date":
            return root.groupedByDate

        case "urgencies":
        case "urgency":
            return root.groupedByUrgency

        default:
            return []
        }
    }

    // ============================================================
    // CONFIGURATION API
    // ============================================================

    function setHistorySize(
        size
    ) {
        const value =
            Math.max(
                1,
                Math.min(
                    5000,
                    Math.round(
                        Number(size)
                    )
                )
            )

        root._historySize =
            value

        root._writeConfig({
            historySize: value
        })

        if (
            root._history.length >
            value
        ) {
            root._history =
                root._history.slice(
                    0,
                    value
                )

            root._saveHistory()
        }

        return value
    }

    function setPopupTimeout(
        urgency,
        seconds
    ) {
        const name =
            String(
                urgency || ""
            )
            .trim()
            .toLowerCase()

        /*
         * Critical is deliberately immutable:
         *
         * critical popup = manual close.
         */
        if (name === "critical")
            return 0

        const value =
            Math.max(
                0.1,
                Number(seconds)
            )

        if (
            name === "low"
        ) {
            root._lowPopupTimeout =
                value

            root._writeConfig({
                lowPopupTimeout:
                    value
            })

            return value
        }

        if (
            name === "normal"
        ) {
            root._normalPopupTimeout =
                value

            root._writeConfig({
                normalPopupTimeout:
                    value
            })

            return value
        }

        return -1
    }

    function setGroupingEnabled(
        enabled
    ) {
        const value =
            Boolean(enabled)

        root._groupingEnabled =
            value

        root._writeConfig({
            groupingEnabled:
                value
        })

        return value
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target:
            "n0ctos-notifications"

        function getStatus(): string {
            return JSON.stringify(
                root.getStatus()
            )
        }

        function active(): string {
            return JSON.stringify(
                root.activeData()
            )
        }

        function history(): string {
            return JSON.stringify(
                root.historyData()
            )
        }

        function popups(): string {
            return JSON.stringify(
                root.popupData()
            )
        }

        function groups(
            type: string
        ): string {
            return JSON.stringify(
                root.groupsData(
                    type
                )
            )
        }

        function dnd(): bool {
            return root.isDnd
        }

        function setDnd(
            value: bool
        ): bool {
            return root.setDnd(
                value
            )
        }

        function toggleDnd(): bool {
            return root.toggleDnd()
        }

        function markAllRead(): void {
            root.markAllRead()
        }

        function dismiss(
            notificationId: int
        ): bool {
            return root.dismiss(
                notificationId
            )
        }

        function expire(
            notificationId: int
        ): bool {
            return root.expire(
                notificationId
            )
        }

        function invokeAction(
            notificationId: int,
            identifier: string
        ): bool {
            return root.invokeAction(
                notificationId,
                identifier
            )
        }

        function invokeDefaultAction(
            notificationId: int
        ): bool {
            return root.invokeDefaultAction(
                notificationId
            )
        }

        function reply(
            notificationId: int,
            text: string
        ): bool {
            return root.reply(
                notificationId,
                text
            )
        }

        function removePopup(
            notificationId: int
        ): bool {
            return root.removePopup(
                notificationId
            )
        }

        function setHistorySize(
            size: int
        ): int {
            return root.setHistorySize(
                size
            )
        }

        function setPopupTimeout(
            urgency: string,
            seconds: real
        ): real {
            return root.setPopupTimeout(
                urgency,
                seconds
            )
        }

        function setGroupingEnabled(
            enabled: bool
        ): bool {
            return root.setGroupingEnabled(
                enabled
            )
        }
    }
}