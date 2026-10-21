# Notifications Service

`Notifications.qml` is N0ctOS's centralized desktop notification service.

It gives every shell component one consistent place to receive, track, store, and present desktop notifications without creating its own notification server.

The service supports live active notifications, persistent history snapshots, timed popup presentation, Do Not Disturb and Game Mode policy, unseen tracking, actions and inline replies, grouping, and high-level IPC control.

The normal usage pattern is:

```text
Application
    │
    ▼
Notifications
    │
    ├── active
    ├── history
    └── popups
    │
    ▼
Top Bar / Popup UI / Notification Hub
```

---

# 1. What does it do?

`Notifications.qml` sits between applications and the N0ctOS shell.

An application can send:

```bash
notify-send "Download complete" "Your file is ready."
```

The service receives that notification and makes it available through three main views:

```text
active
    Notifications that are currently alive.

history
    Notifications that have been recorded for the notification hub.

popups
    Notifications that are currently being presented as popups.
```

These are intentionally different.

A notification can be in all three at the same time.

For example:

```text
Notification arrives
        │
        ├── active   ✓
        ├── history  ✓
        └── popup    ✓
                     │
                     │ popup timeout ends
                     ▼
                  popup ✗

active is still ✓
history is still ✓
```

So a popup disappearing does **not** mean the notification itself was dismissed.

The notification remains active until it is actually closed, dismissed, or expired.

The effective presentation is resolved in this order:

```text
isGameMode?
    ↓
isDnd?
    ↓
urgency
    ↓
popup or silent
```

So a component can simply do:

```qml
model: Notifications.popups
```

and not care whether Game Mode, DND, or urgency filtering was involved.

If the notification should not popup, it is still stored in `active` and `history`.

## Popup policy

Popups follow this order:

```text
                         Notification
                              │
                              ▼
                        isGameMode?
                         /       \
                       yes        no
                       │           │
                   no popup     isDnd?
                                /    \
                              yes     no
                              │        │
                         critical   everything
                            only
```

### Game Mode

When `Config.get("isGameMode")` is `true` (read via `Notifications.isGameMode`):

```text
notification received  → yes
active                 → yes
history                → yes
unseen                 → yes
popup                  → no
```

Game Mode is owned by another service.

Notifications only reads the state. It does not provide a `setGameMode()` API.

### DND

When Game Mode is off and DND is enabled:

```text
Low       → no popup
Normal    → no popup
Critical  → popup
```

The notification is still received and stored even when it does not become a popup.

### Normal mode

When both Game Mode and DND are off:

```text
Low       → popup
Normal    → popup
Critical  → popup
```

## Critical notifications

Critical notifications do not have a popup timeout.

Their popup entry uses:

```text
timeout = 0
```

which means:

```text
critical notification
        ↓
popup appears
        ↓
stays visible
        ↓
user manually closes it
```

The service does not automatically expire or dismiss the underlying notification when its popup presentation ends.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

| How to call                                     | What does it do                                                                                     |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `Notifications.active`                          | Live Quickshell `Notification` objects that are currently tracked.                                  |
| `Notifications.activeList`                      | Same active notifications as a plain JavaScript array for iteration.                                |
| `Notifications.activeCount`                     | Number of currently active notifications.                                                           |
| `Notifications.history`                         | Persistent plain-data snapshots for the notification hub.                                           |
| `Notifications.historyCount`                    | Number of stored history entries, limited by `historySize`.                                         |
| `Notifications.popups`                          | Popup descriptors UI should consume for popup presentation.                                         |
| `Notifications.popupCount`                      | Number of current popup descriptors.                                                                |
| `Notifications.unseenCount`                     | Shell-level counter since the hub was last marked read.                                             |
| `Notifications.hasUnseen`                       | Convenience wrapper for `unseenCount > 0`.                                                          |
| `Notifications.isDnd`                           | Current Do Not Disturb state.                                                                       |
| `Notifications.isGameMode`                      | Read-only view of `Config.get("isGameMode")`.                                                       |
| `Notifications.groupingEnabled`                 | Whether grouped views are built from history.                                                       |
| `Notifications.historySize`                     | Maximum number of stored history entries, `1` to `5000`.                                            |
| `Notifications.lowPopupTimeout`                 | Popup lifetime for low urgency in seconds.                                                          |
| `Notifications.normalPopupTimeout`              | Popup lifetime for normal urgency in seconds.                                                       |
| `Notifications.criticalPopupTimeout`            | Always `0`, meaning manual close.                                                                   |
| `Notifications.groupedByApps`                   | History grouped by application.                                                                     |
| `Notifications.groupedByDate`                   | History grouped by received date.                                                                   |
| `Notifications.groupedByUrgency`                | History grouped by urgency.                                                                         |
| `Notifications.isLow(notification)`             | Returns true when urgency is `0`.                                                                   |
| `Notifications.isNormal(notification)`          | Returns true when urgency is `1`.                                                                   |
| `Notifications.isCritical(notification)`        | Returns true when urgency is `2`.                                                                   |
| `Notifications.urgencyName(notification)`       | Returns `"low"`, `"normal"`, or `"critical"`.                                                       |
| `Notifications.setDnd(value)`                   | Sets DND explicitly and persists it.                                                                |
| `Notifications.toggleDnd()`                     | Flips the current DND state.                                                                        |
| `Notifications.markAllRead()`                   | Resets `unseenCount` to `0` without dismissing anything.                                            |
| `Notifications.dismiss(notificationId)`         | Closes the live notification.                                                                       |
| `Notifications.expire(notificationId)`          | Explicitly expires the live notification.                                                           |
| `Notifications.invokeAction(id, identifier)`    | Invokes the action with the given identifier.                                                       |
| `Notifications.invokeDefaultAction(id)`         | Invokes `default` action, or first action as fallback.                                              |
| `Notifications.reply(id, text)`                 | Sends an inline reply when supported.                                                               |
| `Notifications.removePopup(notificationId)`     | Removes only the popup descriptor, leaves notification alive.                                       |
| `Notifications.getStatus()`                     | Returns service, count, and configuration state.                                                    |
| `Notifications.activeData()`                    | Returns active notifications as serializable snapshots.                                             |
| `Notifications.historyData()`                   | Returns a copy of the history array.                                                                |
| `Notifications.popupData()`                     | Returns popup descriptors without live objects.                                                     |
| `Notifications.groupsData(type)`                | Returns grouped history for `"apps"`, `"dates"`, or `"urgency"`.                                    |
| `Notifications.setHistorySize(size)`            | Changes the persistent history limit.                                                               |
| `Notifications.setPopupTimeout(urgency, secs)`  | Changes `low` or `normal` popup timeout.                                                            |
| `Notifications.setGroupingEnabled(enabled)`     | Enables or disables grouped views.                                                                  |

|Example                                                              |Result                                                        |
|--------------------------------------------------------------------|--------------------------------------------------------------|
|`Notifications.dismiss(42)`                                           |`true`, notification 42 closed                                 |
|`Notifications.expire(42)`                                           |`true`, notification 42 expired                                |
|`Notifications.invokeAction(42, "default")`                           |`true` when the action exists                                 |
|`Notifications.invokeDefaultAction(42)`                               |`true`, `default` action or first action runs                 |
|`Notifications.reply(42, "Thanks!")`                                  |`true` when inline reply is supported                         |
|`Notifications.removePopup(42)`                                       |`true`, popup removed, notification stays alive               |
|`Notifications.groupsData("apps")`                                    |`[{key, label, count, items}]` grouped history array (see §6.29)|
|`Notifications.setPopupTimeout("low", 3)`                             |`3`, low-urgency timeout becomes 3 s                          |

## Three models

The second concept after the Core API is which model a component should consume.

| Model     | Meaning                                                                        |
| --------- | ------------------------------------------------------------------------------ |
| `active`  | Live native objects. Use for lists that act on notifications.                  |
| `history` | Plain persistent snapshots. Use for hubs that survive restarts.                |
| `popups`  | Presentation descriptors. Use for transient popup UI only.                     |

For example:

```qml
model: Notifications.active
```

reads:

```text
NotificationServer.trackedNotifications
        ↓
live Notification objects
```

while:

```qml
model: Notifications.history
```

reads:

```text
_history snapshots
        ↓
plain JSON-safe data
```

while:

```qml
model: Notifications.popups
```

reads:

```text
_popup descriptors
        ↓
notification + timeout + startedAt + expiresAt
```

A popup descriptor has the form:

```qml
{
    notification: notification,
    notificationId: 42,
    timeout: 5,
    startedAt: 1760000000000,
    expiresAt: 1760000005000
}
```

`timeout` is in seconds.

`timeout === 0` means manual close.

### Typical component usage

```qml
readonly property int count:
    Notifications.activeCount

readonly property bool silenced:
    Notifications.isDnd

readonly property bool hasNew:
    Notifications.hasUnseen
```

That is the intended everyday usage.

Components normally should not need to know how the native server, observers, history file, or popup timer work.

---

# 3. IPC API

IPC target:

```text
n0ctos-notifications
```

## Core CRUD

| How to call          | What does it do                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------- |
| `getStatus`          | Shows DND, Game Mode, counts, grouping, history size, and popup timeouts.                |
| `active`             | Returns active notifications as serializable snapshots.                                  |
| `history`            | Returns persistent history snapshots.                                                    |
| `popups`             | Returns popup descriptors without live objects.                                          |
| `groups <type>`      | Returns grouped history for `apps`, `dates`, or `urgency`.                               |
| `dnd`                | Reads the current DND boolean.                                                           |

| Example                                               | Result                                  |
| ----------------------------------------------------- | --------------------------------------- |
| `qs ipc call n0ctos-notifications getStatus`          | JSON status object (see below)          |
| `qs ipc call n0ctos-notifications active`             | JSON array of active snapshots          |
| `qs ipc call n0ctos-notifications history`            | JSON array of history snapshots         |
| `qs ipc call n0ctos-notifications popups`             | JSON array of popup descriptors         |
| `qs ipc call n0ctos-notifications groups apps`        | JSON history grouped by app             |
| `qs ipc call n0ctos-notifications dnd`                | `true` or `false`                       |

Read the current state:

```bash
qs ipc call n0ctos-notifications getStatus
```

Example result:

```json
{
    "isDnd": false,
    "isGameMode": false,
    "activeCount": 3,
    "historyCount": 17,
    "popupCount": 2,
    "unseenCount": 3,
    "hasUnseen": true,
    "groupingEnabled": true,
    "historySize": 100,
    "lowPopupTimeout": 3,
    "normalPopupTimeout": 5,
    "criticalPopupTimeout": 0
}
```

Get active notifications:

```bash
qs ipc call n0ctos-notifications active
```

Get history:

```bash
qs ipc call n0ctos-notifications history
```

Get popup state:

```bash
qs ipc call n0ctos-notifications popups
```

Get grouped data:

```bash
qs ipc call n0ctos-notifications groups apps
```

```bash
qs ipc call n0ctos-notifications groups dates
```

```bash
qs ipc call n0ctos-notifications groups urgency
```

Read DND:

```bash
qs ipc call n0ctos-notifications dnd
```

## Other operations

| How to call                                | What does it do                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------------------- |
| `setDnd <bool>`                            | Sets DND explicitly.                                                            |
| `toggleDnd`                                | Flips the current DND state.                                                    |
| `markAllRead`                              | Resets `unseenCount` to `0`.                                                    |
| `dismiss <id>`                             | Dismisses the live notification.                                                |
| `expire <id>`                              | Expires the live notification.                                                  |
| `invokeAction <id> <identifier>`           | Invokes the named action.                                                       |
| `invokeDefaultAction <id>`                 | Invokes `default` action or first action.                                       |
| `reply <id> <text>`                        | Sends an inline reply when supported.                                           |
| `removePopup <id>`                         | Removes only the popup presentation.                                            |
| `setHistorySize <int>`                     | Changes history limit, `1` to `5000`.                                           |
| `setPopupTimeout <urgency> <seconds>`      | Changes `low` or `normal` timeout.                                              |
| `setGroupingEnabled <bool>`                | Enables or disables grouping.                                                   |

| Example                                                              | Result                                            |
| -------------------------------------------------------------------- | ------------------------------------------------- |
| `qs ipc call n0ctos-notifications setDnd true`                        | `true`, DND turns on                              |
| `qs ipc call n0ctos-notifications toggleDnd`                          | `true`, DND flips                                 |
| `qs ipc call n0ctos-notifications markAllRead`                        | unseen counter resets to `0`                      |
| `qs ipc call n0ctos-notifications dismiss 42`                         | `true`, notification 42 closed                    |
| `qs ipc call n0ctos-notifications expire 42`                          | `true`, notification 42 expired                   |
| `qs ipc call n0ctos-notifications invokeAction 42 default`            | `true` when the action exists                     |
| `qs ipc call n0ctos-notifications invokeDefaultAction 42`             | `true`, default or first action runs              |
| `qs ipc call n0ctos-notifications reply 42 "Thanks!"`                 | `true` when inline reply is supported             |
| `qs ipc call n0ctos-notifications removePopup 42`                     | `true`, popup removed, notification stays alive   |
| `qs ipc call n0ctos-notifications setHistorySize 200`                 | `200`, history limit becomes 200                  |
| `qs ipc call n0ctos-notifications setPopupTimeout low 3`              | `3`, low-urgency timeout becomes 3 s              |
| `qs ipc call n0ctos-notifications setGroupingEnabled true`            | `true`, grouping turns on                         |

Set DND:

```bash
qs ipc call n0ctos-notifications setDnd true
```

```bash
qs ipc call n0ctos-notifications setDnd false
```

Dismiss a notification:

```bash
qs ipc call n0ctos-notifications dismiss 42
```

Send an inline reply:

```bash
qs ipc call n0ctos-notifications reply 42 "Thanks!"
```

Remove only the popup:

```bash
qs ipc call n0ctos-notifications removePopup 42
```

Configure history size:

```bash
qs ipc call n0ctos-notifications setHistorySize 200
```

Configure popup timeout:

```bash
qs ipc call n0ctos-notifications setPopupTimeout low 3
```

```bash
qs ipc call n0ctos-notifications setPopupTimeout normal 5
```

Critical urgency intentionally has no configurable timer:

```text
critical = manual close
```

---

# 4. Features / limitations

## Features

### Centralized notification ownership

There is one `NotificationServer` owned by `Notifications.qml`.

UI components do not create their own notification servers.

```qml
NotificationServer {
    id: notificationServer
}
```

### Active notifications

The service keeps live notifications available through:

```qml
Notifications.active
```

For JavaScript iteration:

```qml
Notifications.activeList
```

For counts only:

```qml
Notifications.activeCount
```

### Persistent history

Notifications are stored as snapshots so they remain available to the notification hub even after the original notification is closed.

```qml
Notifications.history
```

```qml
Notifications.historyCount
```

The stored structure is conceptually:

```json
{
    "version": 1,
    "unseenCount": 3,
    "items": [
        {
            "notificationId": 12,
            "appName": "Discord",
            "summary": "New message",
            "body": "Hello"
        }
    ]
}
```

### Popup system

Notifications can become temporary popups without changing their actual lifetime.

```qml
Notifications.popups
```

Each popup entry contains:

```text
notification
notificationId
timeout
startedAt
expiresAt
```

Removing a popup:

```qml
Notifications.removePopup(
    notificationId
)
```

leaves:

```text
popup      → removed
active     → unchanged
history    → unchanged
```

### Critical popups

Critical notifications remain visible until manually closed.

```text
timeout = 0
```

Their popup entry never expires automatically.

### DND

DND allows:

```text
all notifications stored
critical notifications shown as popups
everything else kept silent
```

Set explicitly:

```qml
Notifications.setDnd(
    true
)
```

Toggle:

```qml
Notifications.toggleDnd()
```

### Game Mode integration

Game Mode can suppress all popups while notifications continue being received and stored.

```qml
Notifications.isGameMode
```

is a read-only view of `Config.get("isGameMode")` (via `Notifications.isGameMode`):

```text
Config.get("isGameMode")
```

### Unseen counter

The service tracks the number of notifications since the notification hub was last marked read.

```qml
Notifications.unseenCount
```

```qml
Notifications.hasUnseen
```

The intended interaction is:

```text
notification arrives
        ↓
unseenCount increases
        ↓
user opens notification hub
        ↓
markAllRead()
        ↓
unseenCount = 0
```

### Grouping

History can be grouped by:

```text
application
date
urgency
```

Each group has the general structure:

```qml
{
    key: "Discord",
    label: "Discord",
    count: 4,
    items: [...]
}
```

Grouping is derived from one source:

```text
_history
   │
   ├── groupedByApps
   ├── groupedByDate
   └── groupedByUrgency
```

### Actions

Notifications can expose multiple actions.

The native actions are available through:

```qml
notification.actions
```

The service also provides:

```qml
Notifications.invokeAction(
    notificationId,
    identifier
)
```

Default action routing:

```qml
Notifications.invokeDefaultAction(
    notification.id
)
```

prefers `default`, then falls back to the first available action.

### Inline replies

Notifications supporting inline replies can be replied to through the service.

Check:

```qml
notification.hasInlineReply
```

and read the suggested placeholder:

```qml
notification.inlineReplyPlaceholder
```

Reply:

```qml
Notifications.reply(
    notification.id,
    replyInput.text
)
```

### Images and icons

The service preserves notification image and icon information required by the UI and persistent history.

Important fields include:

```text
appIcon
image
desktopEntry
```

Live UI uses native properties. Persistent history uses stored snapshot values.

### Replacement notifications

When an application updates a notification using its existing notification ID, the service keeps the same logical notification instead of treating it as an entirely new notification.

This is especially useful for:

```text
download progress
media state
battery status
message updates
progress notifications
```

The history entry is updated in place. No second popup is created. No second unseen increment occurs.

### Config integration

Notification configuration lives under:

```json
{
    "notifications": {
        "historySize": 100,
        "dnd": false,
        "popupTimeout": {
            "low": 3,
            "normal": 5
        },
        "grouping": {
            "enabled": true
        }
    }
}
```

Game Mode is separate:

```json
{
    "isGameMode": false
}
```

That separation is intentional.

### No polling for notification state

Notification changes are handled through native signals and observers.

The popup timer only checks timed popup descriptors every `100ms` while timed popups exist.

It is not a polling loop over applications.

---

## Limitations

### Only standard notification urgencies

Quickshell's native notification urgency model provides:

```text
Low
Normal
Critical
```

N0ctOS does not invent another native urgency level.

Use:

```qml
Notifications.isLow(notification)
Notifications.isNormal(notification)
Notifications.isCritical(notification)
```

or:

```qml
Notifications.urgencyName(
    notification
)
```

### Popup lifetime is separate from notification lifetime

A popup timing out does not dismiss the underlying notification.

```text
popup → gone
notification → alive
```

To actually close a notification, use:

```qml
Notifications.dismiss(
    notificationId
)
```

or:

```qml
Notifications.expire(
    notificationId
)
```

### No notification sounds

Notification sound handling is not part of this service.

A future `Sfx.qml` service can own notification sound behavior.

### Game Mode is external

Notifications reads (via `Notifications.isGameMode`):

```qml
Config.get("isGameMode")
```

but does not own that state.

Do not try to change Game Mode through Notifications.

### No per-notification read state

There is one service-level unseen counter rather than an `isRead` value on every notification.

```text
_unseenCount += 1
        ↓
markAllRead()
        ↓
_unseenCount = 0
```

### History stores snapshots

History does not retain live `Notification` objects indefinitely.

This is intentional so persistent data remains simple and safe to serialize.

```text
active
    live notification object

history
    plain persistent snapshot
```

### IPC cannot return live objects

The terminal caller does not receive the live `Notification` object itself.

The actual live object is only available to QML code through:

```qml
Notifications.active
Notifications.popups
```

IPC returns serializable snapshots through `activeData()`, `historyData()`, and `popupData()`.

### Critical timeout is immutable

`setPopupTimeout` accepts only:

```text
low
normal
```

`critical` always returns:

```text
0
```

Unknown urgency names return:

```text
-1
```

---

# 5. Example use cases

## 5.1 Basic notification list

A normal notification list can be implemented entirely from `Notifications.active`.

```qml
import QtQuick
import Quickshell

import qs.services

ListView {
    anchors.fill: parent

    spacing: 8

    model:
        Notifications.active

    delegate: Rectangle {
        required property var modelData

        width:
            ListView.view.width

        height:
            92

        radius:
            12

        color:
            "#101720"

        border.width:
            1

        border.color:
            "#263541"

        Column {
            anchors.fill:
                parent

            anchors.margins:
                12

            spacing:
                4

            Text {
                text:
                    modelData.appName ||
                    "Application"

                color:
                    "#91a1b2"

                font.pixelSize:
                    10
            }

            Text {
                text:
                    modelData.summary ||
                    "Notification"

                color:
                    "#ffffff"

                font.pixelSize:
                    14

                font.bold:
                    true
            }

            Text {
                width:
                    parent.width

                text:
                    modelData.body ||
                    ""

                color:
                    "#91a1b2"

                font.pixelSize:
                    11

                wrapMode:
                    Text.WordWrap

                maximumLineCount:
                    3
            }
        }
    }
}
```

`modelData` is the live Quickshell `Notification` object.

---

## 5.2 Notification badge in a top bar

A top bar can show an indicator whenever something unseen exists.

```qml
import QtQuick
import Quickshell

import qs.services

Item {
    width: 32
    height: 32

    Text {
        anchors.centerIn:
            parent

        text:
            "󰂚"

        color:
            Notifications.hasUnseen
                ? "#2acfff"
                : "#91a1b2"

        font.family:
            "Symbols Nerd Font"

        font.pixelSize:
            19
    }

    Rectangle {
        visible:
            Notifications.hasUnseen

        width:
            Notifications.unseenCount > 9
                ? 20
                : 8

        height:
            18

        radius:
            9

        anchors {
            right: parent.right
            top: parent.top
        }

        color:
            "#2acfff"

        Text {
            visible:
                Notifications.unseenCount > 9

            anchors.centerIn:
                parent

            text:
                Notifications.unseenCount > 99
                    ? "99+"
                    : String(
                        Notifications.unseenCount
                    )

            color:
                "#061018"

            font.pixelSize:
                8

            font.bold:
                true
        }
    }
}
```

---

## 5.3 Opening the notification hub

The usual interaction is:

```text
user clicks notification icon
        ↓
hub opens
        ↓
markAllRead()
```

Example:

```qml
MouseArea {
    anchors.fill:
        parent

    onClicked: {
        notificationHub.visible = true

        Notifications.markAllRead()
    }
}
```

This does not clear the notifications.

It only clears the unseen counter.

---

## 5.4 DND button

```qml
Rectangle {
    width: 180
    height: 44

    radius: 10

    color:
        Notifications.isDnd
            ? "#302516"
            : "#15222b"

    Text {
        anchors.centerIn:
            parent

        text:
            Notifications.isDnd
                ? "󰂛  Do Not Disturb"
                : "󰂚  Notifications"

        color:
            Notifications.isDnd
                ? "#ffb454"
                : "#ffffff"

        font.family:
            "Symbols Nerd Font"

        font.pixelSize:
            12
    }

    MouseArea {
        anchors.fill:
            parent

        onClicked:
            Notifications.toggleDnd()
    }
}
```

For explicit control:

```qml
Notifications.setDnd(
    !Notifications.isDnd
)
```

---

## 5.5 Popup UI

A popup UI should use:

```qml
Notifications.popups
```

rather than trying to determine popup eligibility itself.

```qml
ListView {
    width: 420

    spacing: 10

    model:
        Notifications.popups

    delegate: Rectangle {
        required property var modelData

        width:
            ListView.view.width

        implicitHeight:
            contentColumn.implicitHeight +
            28

        radius:
            14

        color:
            "#101720"

        border.width:
            1

        border.color:
            "#263541"

        Column {
            id: contentColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            anchors.margins:
                14

            spacing:
                7

            Text {
                text:
                    modelData.notification.appName ||
                    "Application"

                color:
                    "#91a1b2"

                font.pixelSize:
                    10
            }

            Text {
                text:
                    modelData.notification.summary ||
                    "Notification"

                color:
                    "#ffffff"

                font.pixelSize:
                    14

                font.bold:
                    true
            }

            Text {
                width:
                    parent.width

                text:
                    modelData.notification.body ||
                    ""

                color:
                    "#91a1b2"

                font.pixelSize:
                    11

                wrapMode:
                    Text.WordWrap
            }
        }
    }
}
```

The popup component does not decide:

```text
whether DND is active
whether Game Mode is active
whether the urgency is allowed
how long the popup should live
```

The service has already made those decisions.

---

## 5.6 Actions and inline replies

A notification may contain actions.

```qml
Row {
    spacing: 6

    Repeater {
        model:
            notification.actions

        delegate: Rectangle {
            required property var modelData

            width: 100
            height: 34

            radius: 8
            color: "#17212b"

            Text {
                anchors.centerIn: parent

                text:
                    modelData.text

                color: "white"
            }

            MouseArea {
                anchors.fill: parent

                onClicked:
                    modelData.invoke()
            }
        }
    }
}
```

Or use identifiers:

```qml
Notifications.invokeAction(
    notification.id,
    "default"
)
```

For the common open behavior:

```qml
Notifications.invokeDefaultAction(
    notification.id
)
```

For inline replies:

```qml
Row {
    visible:
        notification.hasInlineReply

    spacing: 6

    TextField {
        id: replyInput

        width: 260

        placeholderText:
            notification.inlineReplyPlaceholder ||
            "Reply..."
    }

    Button {
        text: "Send"

        onClicked: {
            Notifications.reply(
                notification.id,
                replyInput.text
            )

            replyInput.clear()
        }
    }
}
```

---

## 5.7 Grouped history hub

A hub can combine history, grouping, and DND controls.

```qml
ListView {
    anchors.fill: parent

    model:
        Notifications.groupedByApps

    delegate: Column {
        required property var modelData

        Text {
            text:
                modelData.label +
                " (" +
                modelData.count +
                ")"
        }

        Repeater {
            model:
                modelData.items

            delegate: Text {
                required property var modelData

                text:
                    modelData.summary
            }
        }
    }
}
```

The available groupings are:

```qml
Notifications.groupedByApps
Notifications.groupedByDate
Notifications.groupedByUrgency
```

The terminal equivalents are:

```bash
qs ipc call n0ctos-notifications groups apps
```

```bash
qs ipc call n0ctos-notifications groups dates
```

```bash
qs ipc call n0ctos-notifications groups urgency
```

---

## 5.8 Testing DND behavior

Send a normal notification:

```bash
notify-send -u normal "Normal" "This should popup when DND is off."
```

Enable DND:

```bash
qs ipc call n0ctos-notifications setDnd true
```

Send another normal notification:

```bash
notify-send -u normal "Normal" "This should not popup."
```

Send a critical notification:

```bash
notify-send -u critical "Critical" "This should still popup."
```

The expected result is:

```text
normal #1
    active ✓
    history ✓
    popup ✓

normal #2
    active ✓
    history ✓
    popup ✗

critical
    active ✓
    history ✓
    popup ✓
```

Test critical persistence:

```bash
notify-send \
    -u critical \
    "Critical Test" \
    "This popup should stay until manually closed."
```

Then inspect:

```bash
qs ipc call n0ctos-notifications getStatus
```

The popup entry should have:

```text
timeout = 0
```

---

## 5.9 Terminal workflow

Read the service state:

```bash
qs ipc call n0ctos-notifications getStatus
```

Read active snapshots:

```bash
qs ipc call n0ctos-notifications active
```

Read history:

```bash
qs ipc call n0ctos-notifications history
```

Read popups:

```bash
qs ipc call n0ctos-notifications popups
```

Enable DND:

```bash
qs ipc call n0ctos-notifications setDnd true
```

Dismiss notification `42`:

```bash
qs ipc call n0ctos-notifications dismiss 42
```

Remove only its popup:

```bash
qs ipc call n0ctos-notifications removePopup 42
```

Mark everything read:

```bash
qs ipc call n0ctos-notifications markAllRead
```

Inspect the complete service again:

```bash
qs ipc call n0ctos-notifications getStatus
```

---

# 6. Detailed architecture

This section is for developers working on `Notifications.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is the single notification owner for N0ctOS.

```text
Applications
    │
    │ org.freedesktop.Notifications
    ▼
NotificationServer
    │
    ▼
Notifications.qml
    │
    ├── Active notifications
    ├── Persistent history
    ├── Popup policy
    ├── Popup lifetime
    ├── Unseen state
    ├── Actions
    ├── Inline replies
    ├── Grouping
    ├── DND
    └── IPC
    │
    ▼
N0ctOS UI
```

There are effectively two responsibilities:

```text
Notifications
    notification logic and presentation policy

Config + FileView
    configuration persistence and history persistence
```

Notifications should not duplicate functionality already provided by those persistence systems.

---

## 6.2 Native notification server

The service contains one:

```qml
NotificationServer {
    id: notificationServer
}
```

The server advertises the notification capabilities required by N0ctOS:

```qml
actionsSupported: true
bodySupported: true
bodyHyperlinksSupported: true
bodyMarkupSupported: true
bodyImagesSupported: true
imageSupported: true
actionIconsSupported: true
inlineReplySupported: true
persistenceSupported: true
keepOnReload: true
```

The notification server receives notifications through:

```qml
onNotification: function(notification) {
    root._receiveNotification(
        notification
    )
}
```

---

## 6.3 The `tracked = true` requirement

One of the most important details in the whole service is:

```qml
notification.tracked = true
```

This must happen when a notification is received.

Conceptually:

```text
notification arrives
        │
        ▼
onNotification
        │
        ▼
tracked = true
        │
        ▼
notification remains alive
```

Without tracking it, the notification can be discarded by the native notification server after the callback returns.

Therefore `_receiveNotification()` must make tracking the first important operation.

---

## 6.4 Active is native state

The service does not maintain a second JavaScript copy of active notifications.

Instead:

```qml
Notifications.active
```

maps directly to:

```qml
notificationServer.trackedNotifications
```

This matters because `trackedNotifications` contains the live native `Notification` objects.

The UI therefore receives real objects rather than stale copies.

The conceptual model is:

```text
NotificationServer
        │
        ▼
trackedNotifications
        │
        ├── Notification A
        ├── Notification B
        └── Notification C
```

For JavaScript processing:

```qml
Notifications.activeList
```

exposes:

```text
trackedNotifications.values
```

For counts only:

```qml
Notifications.activeCount
```

exposes:

```text
trackedNotifications.values.length
```

---

## 6.5 History is separate from active

Active notifications cannot simply be written directly to disk because native notification objects are not the persistent representation we want.

History therefore uses snapshots:

```text
live Notification
       │
       ▼
snapshot object
       │
       ▼
JSON
```

This gives the service two clear representations:

```text
active
    live

history
    persistent snapshot
```

---

## 6.6 History storage

The persistent file uses:

```qml
Quickshell.dataPath(
    "notifications.json"
)
```

The file is owned by the service.

The UI never writes to it.

The stored structure is conceptually:

```json
{
    "version": 1,
    "unseenCount": 3,
    "items": [
        {
            "notificationId": 12,
            "appName": "Discord",
            "summary": "New message",
            "body": "Hello"
        }
    ]
}
```

The service can change its internal representation in the future by increasing the version.

The file uses:

```qml
blockLoading: true
watchChanges: false
```

so history can be synchronously consumed once the `FileView` is ready.

---

## 6.7 History entries are lifecycle records

A history entry does not disappear merely because a popup expires.

For example:

```text
notification arrives
        │
        ├── history created
        ├── active created
        └── popup created
```

Then:

```text
popup expires
        │
        └── popup removed

history → still present
active  → still present
```

Only when the actual notification closes does history become marked as closed.

This gives the hub enough information to distinguish:

```text
currently active
previously closed
```

A history entry contains information such as:

```json
{
    "notificationId": 42,
    "receivedAt": 1760000000000,
    "closedAt": null,
    "isClosed": false,
    "closeReason": "",
    "closeReasonCode": 0,
    "appName": "Discord",
    "summary": "New message",
    "body": "Someone sent you a message.",
    "urgency": 1,
    "resident": false,
    "transient": false,
    "hasInlineReply": false,
    "actions": []
}
```

---

## 6.8 Snapshot update strategy

When a notification is received:

```text
find history entry by notification ID
```

If it does not exist:

```text
create one
```

If it already exists:

```text
update the existing entry
```

That second case is important for replacement notifications.

The notification ID is therefore the stable identity used by the service.

New entries are inserted newest-first:

```text
_history.unshift(snapshot)
```

and trimmed to:

```text
_history.slice(0, historySize)
```

---

## 6.9 Replacement notifications

Applications are allowed to send another notification using an existing notification ID.

Conceptually:

```text
first notification
    ID = 42
       │
       ▼
history entry #42
active object #42
popup #42
```

Application sends replacement:

```text
second notification
    ID = 42
       │
       ▼
same native Notification
updated
```

The service should not intentionally create:

```text
notification #43
```

just because the content changed.

Instead:

```text
ID 42
 │
 ├── summary changes
 ├── body changes
 ├── actions change
 └── image changes
```

The UI delegate can therefore remain associated with the same notification object.

---

## 6.10 Notification observers

The service creates lightweight `Connections` objects for the live notification objects.

Their job is to notice changes such as:

```text
summary
body
appName
appIcon
urgency
actions
image
inline reply state
close signal
```

The general flow is:

```text
Notification object changes
        │
        ▼
observer signal
        │
        ▼
service updates snapshot
        │
        ▼
history remains synchronized
```

This avoids polling.

The service does not repeatedly ask every notification whether something changed.

---

## 6.11 Observer lifetime

Observers exist only while the notification is alive.

The lifecycle is:

```text
notification created
        │
        ▼
observer created
        │
        ▼
notification changes
        │
        ▼
observer reacts
        │
        ▼
notification closes
        │
        ▼
observer released
```

This is important because retaining observer objects forever would create unnecessary resource usage.

---

## 6.12 Close signal

Native notifications provide a `closed(reason)` signal.

When it fires, the service:

```text
1. identifies the notification
2. records the close reason
3. records the close time
4. marks its history entry closed
5. removes its popup
6. saves history
7. releases the observer
```

The service keeps both:

```text
closeReason
closeReasonCode
```

so the UI can use readable text while the underlying numeric value remains available.

---

## 6.13 Close reasons

The native notification system provides reasons such as:

```text
Expired
Dismissed
CloseRequested
```

The service converts these into readable strings:

```text
expired
dismissed
close-requested
```

Unknown values are represented safely as:

```text
unknown
```

---

## 6.14 Popup state is presentation state

The service deliberately keeps popup state separate from active state.

This is one of the central architectural rules.

```text
active
    = actual notification

popup
    = current presentation of notification
```

A popup descriptor therefore contains a reference to the live notification:

```qml
{
    notification: notification,
    notificationId: notification.id,

    timeout: 5,

    startedAt: ...,
    expiresAt: ...
}
```

The descriptor is not itself the notification.

---

## 6.15 Popup creation

After receiving the notification, the service performs:

```text
receive
   │
   ├── track
   ├── observe
   ├── history
   ├── unseen
   │
   ▼
popup policy
```

If the policy says the notification should popup:

```text
_addPopup(notification)
```

creates the descriptor.

If not:

```text
no popup descriptor is created
```

The notification is still retained in active/history.

Newest popups appear first:

```text
_popups.unshift(entry)
```

A replacement ID never creates a second popup for the same notification.

---

## 6.16 Exact popup policy

The policy is intentionally simple:

```qml
function _shouldPopup(notification) {
    if (root.isGameMode)
        return false

    if (root.isDnd)
        return root.isCritical(
            notification
        )

    return true
}
```

That means there is no complicated priority system hidden inside the popup decision.

The result is exactly:

```text
Game Mode
    → no popups

Game Mode off + DND on
    → critical only

Game Mode off + DND off
    → all
```

---

## 6.17 Why Game Mode is checked first

Game Mode is an absolute popup suppression state.

Therefore:

```text
Game Mode = true
DND = false
critical = true
```

still results in:

```text
no popup
```

Game Mode wins because it is intended to completely suppress popup presentation.

---

## 6.18 Why DND does not suppress storage

DND is a presentation policy.

It should not change the notification intake pipeline.

Therefore when DND is enabled:

```text
notification arrives
        │
        ├── active ✓
        ├── history ✓
        ├── unseen ✓
        └── popup?
                │
                ├── critical → yes
                └── other    → no
```

This means the user can later open the notification hub and see what arrived while DND was active.

---

## 6.19 Popup timeouts

Low and normal popup timeout values are configurable.

The defaults are:

```text
low      = 3 seconds
normal   = 5 seconds
critical = 0
```

Critical uses zero because:

```text
0
```

means:

```text
no automatic popup expiration
```

The service never uses the critical timeout as a countdown.

`low` and `normal` have a minimum of:

```text
0.1 seconds
```

---

## 6.20 Popup expiration is not notification expiration

This is an important distinction.

When a normal popup expires:

```text
popupExpiryTimer
        │
        ▼
remove popup descriptor
```

The service does **not** call:

```qml
notification.expire()
```

Therefore:

```text
popup → gone
notification → alive
```

This allows active notifications to remain in the notification hub after their popup disappears.

---

## 6.21 Popup timer implementation

The service uses one lightweight timer to check timed popup descriptors.

```qml
Timer {
    interval: 100
    repeat: true

    running:
        root._hasTimedPopups()

    onTriggered:
        root._expirePopups()
}
```

The timer is only active if a popup has:

```text
timeout > 0
```

A critical popup has:

```text
timeout = 0
```

so it does not need automatic timeout checking.

This timer is only for popup presentation.

It is not a polling loop over applications or the notification system.

---

## 6.22 Dynamic popup policy changes

The popup list must also respond when policy changes.

For example:

```text
popup visible
       │
       ▼
Game Mode enabled
       │
       ▼
popup policy becomes "none"
       │
       ▼
popup removed
```

Similarly, when DND becomes enabled:

```text
normal popup
       │
       ▼
DND ON
       │
       ▼
normal no longer allowed
       │
       ▼
popup removed
```

The underlying notification remains active.

This is why `_applyPopupPolicy()` operates on popup descriptors rather than modifying active notifications.

---

## 6.23 Unseen state

The service keeps:

```qml
property int _unseenCount
```

rather than attaching an `isRead` property to each notification.

When a new notification arrives:

```text
_unseenCount += 1
```

When the hub marks everything read:

```text
_unseenCount = 0
```

This keeps the read-state model extremely simple.

`lastGeneration` restorations do not increment unseen.

---

## 6.24 Reload handling

The server uses:

```qml
keepOnReload: true
```

so notifications can survive Quickshell reloads.

Restored notifications can be identified using:

```qml
notification.lastGeneration
```

The service does not treat them like fresh events.

For a restored notification:

```text
active
    restored

history
    retained/updated

unseen
    not incremented

popup
    not recreated as a new popup
```

This avoids notification spam whenever the shell reloads.

---

## 6.25 Action routing

The service provides a high-level action API:

```qml
Notifications.invokeAction(
    id,
    identifier
)
```

Internally it:

```text
1. finds the active notification
2. searches its actions
3. finds the requested identifier
4. invokes the action
```

The UI does not need to know how the active notification is located.

Empty identifiers and missing actions return:

```text
false
```

---

## 6.26 Default action routing

`invokeDefaultAction()` first searches for:

```text
default
```

If present:

```text
invoke it
```

Otherwise the service may use the first available action.

This makes simple popup cards easy to implement because they can simply offer:

```text
Open
```

without duplicating action lookup logic.

---

## 6.27 Inline reply routing

The inline reply API follows the same principle.

UI code calls:

```qml
Notifications.reply(
    id,
    text
)
```

The service:

```text
finds live notification
        ↓
checks inline reply support
        ↓
sends reply
```

The service owns this routing; the UI owns only the text field and presentation.

Replies to notifications without `hasInlineReply` return:

```text
false
```

---

## 6.28 Images and icons

Notification snapshots preserve the information needed to reproduce the notification later.

Important fields include:

```text
appIcon
image
desktopEntry
```

Live notification UI can use the corresponding native properties.

Persistent history uses the stored snapshot values.

The service does not create a separate image cache or media subsystem.

That keeps notification storage focused on notification data.

---

## 6.29 Grouping implementation

Grouping is derived from one source:

```text
_history
```

The service does not maintain three independent data stores.

Instead:

```text
_history
   │
   ├── groupedByApps
   ├── groupedByDate
   └── groupedByUrgency
```

Each grouping operation builds temporary buckets.

For example:

```qml
{
    key: "Discord",
    label: "Discord",
    count: 4,
    items: [
        ...
    ]
}
```

When grouping is disabled:

```text
groupedByApps = []
groupedByDate = []
groupedByUrgency = []
```

This keeps history as the single source of truth.

---

## 6.30 Configuration

Notification configuration lives under:

```json
{
    "notifications": {
        "historySize": 100,

        "dnd": false,

        "popupTimeout": {
            "low": 3,
            "normal": 5
        },

        "grouping": {
            "enabled": true
        }
    }
}
```

Game Mode is separate:

```json
{
    "isGameMode": false
}
```

That separation is intentional.

`historySize` is clamped to:

```text
1 … 5000
```

Popup timeouts are clamped to a minimum of:

```text
0.1
```

---

## 6.31 Configuration ownership

The service owns notification settings such as:

```text
historySize
dnd
popupTimeout
grouping
```

Another service owns:

```text
isGameMode
```

Therefore Notifications should not write:

```text
isGameMode
```

when changing its own state.

It only reads it.

Writes flow through:

```qml
Config.set(
    "notifications",
    merged
)
```

---

## 6.32 Reactive state

The service consumes the reactive `Config` document.

Conceptually:

```text
config file changes
        │
        ▼
Config document changes
        │
        ▼
Notifications state reevaluates
        │
        ▼
component bindings reevaluate
```

A component does not need to manually reload notification configuration.

For example:

```qml
readonly property bool silenced:
    Notifications.isDnd
```

can react to configuration changes through the service.

Changing `historySize` trims history immediately and persists the result.

---

## 6.33 IPC architecture

IPC sits above the service API.

The flow is:

```text
terminal / shell module
        │
        ▼
n0ctos-notifications
        │
        ▼
Notifications.qml
```

The IPC functions translate simple external arguments into service operations.

Example:

```text
IPC:

dismiss 42

        ↓

Notifications.dismiss(42)
```

This keeps the external interface simple while allowing the internal service to evolve.

Serialization follows:

```text
QML objects → snapshots → JSON strings
```

for `active`, `history`, `popups`, and `groups`.

---

## 6.34 Why IPC should stay high-level

IPC callers should not have to understand:

```text
NotificationServer
trackedNotifications
observer objects
history JSON
popup descriptors
timer state
```

Those are implementation details.

A caller should only need:

```text
dismiss
expire
reply
toggleDnd
getStatus
```

This preserves a clean service boundary.

---

## 6.35 Complete notification lifecycle

The full lifecycle is:

```text
Application
    │
    │ notify-send / D-Bus
    ▼
NotificationServer
    │
    │ onNotification
    ▼
_receiveNotification()
    │
    ├── tracked = true
    │
    ├── observer created
    │
    ├── history inserted/updated
    │
    ├── unseen incremented
    │
    ▼
_shouldPopup()
    │
    ├── Game Mode
    │      └── no popup
    │
    ├── DND
    │      └── critical only
    │
    └── normal
           └── all
    │
    ▼
_addPopup()
    │
    ├── timed popup
    │
    └── critical popup
    │
    ▼
UI consumes Notifications.popups
    │
    ├── timer expires
    │      └── popup removed
    │
    └── user closes
           └── dismiss / expire
    │
    ▼
actual notification close
    │
    ▼
closed(reason)
    │
    ├── history finalized
    ├── popup removed
    ├── history persisted
    └── observer destroyed
```

---

## 6.36 The three-model design

The most important mental model for developers is:

```text
                    Notification
                         │
             ┌───────────┼───────────┐
             │           │           │
             ▼           ▼           ▼
          active      history      popup
           live       snapshot    descriptor
```

### `active`

Answers:

> What notifications are alive right now?

### `history`

Answers:

> What notifications has the shell recorded?

### `popups`

Answers:

> What notifications should currently be presented as popup UI?

None of these should be collapsed into one model.

---

## 6.37 What UI / service code should not do

UI components should not:

```text
create NotificationServer

track notifications independently

implement their own DND logic

check Game Mode themselves to decide popup eligibility

write notifications.json

implement replacement-ID handling

implement notification persistence

poll notification state

manually maintain popup timeout state

call the native notification API when a Notifications API exists
```

Instead, UI code should use the service.

For example:

```qml
// Good

model:
    Notifications.popups
```

rather than:

```qml
// Bad

NotificationServer {
    ...
}
```

Likewise:

```qml
// Good

Notifications.dismiss(
    notification.id
)
```

rather than building another notification-closing abstraction in every UI component.

---

## 6.38 Final architecture summary

At the highest level:

```text
                 ┌──────────────────────┐
                 │      Applications    │
                 └──────────┬───────────┘
                            │
                            │ D-Bus
                            ▼
                 ┌──────────────────────┐
                 │  NotificationServer  │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │ Notifications.qml    │
                 │                      │
                 │  active              │
                 │  history             │
                 │  popups              │
                 │  unseen              │
                 │  DND                 │
                 │  actions             │
                 │  replies             │
                 │  grouping            │
                 │  IPC                 │
                 └──────────┬───────────┘
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
          Top Bar       Popup UI       Notification Hub
```

The core rule is:

> **Receive notifications once, keep their state centralized, decide when they should be presented, and expose a clean reactive API to the rest of N0ctOS.**
