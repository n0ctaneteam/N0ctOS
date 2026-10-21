# Power Service

`Power.qml` is N0ctOS's centralized power and session-action service.

It gives every shell component one consistent place to trigger shutdown, reboot, suspend, hibernate, lock, and logout without invoking `systemctl` / `loginctl` directly.

The service supports system power actions, session lock and logout, session identity (`sessionId`, `user`), detached command execution, a logout guard for missing sessions, and a full IPC interface.

The normal usage pattern is:

```text
Component
    │
    ▼
Power
    │
    ├── session info
    ├── power actions
    └── session actions
    │
    ▼
systemctl / loginctl
    │
    ▼
system / session
```

---

# 1. What does it do?

`Power.qml` maps simple function calls to system commands.

A component can read session identity:

```qml
Power.sessionId
```

```qml
Power.user
```

or trigger an action:

```qml
Power.shutdown()
```

```qml
Power.lock()
```

The mapping is fixed:

```text
Power.shutdown()  -> systemctl poweroff
Power.reboot()    -> systemctl reboot
Power.suspend()   -> systemctl suspend
Power.hibernate() -> systemctl hibernate
Power.lock()      -> loginctl lock-session
Power.logout()    -> loginctl terminate-session <sessionId>
```

So a component can simply do:

```qml
Power.suspend()
```

and not care which command runs underneath.

All actions launch detached and return `true` when the command was launched. `logout()` is the only exception: it returns `false` with a warning when `XDG_SESSION_ID` is unavailable, because there is no session to terminate.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

| How to call | What does it do |
| ----------- | --------------- |
| `Power.sessionId` | Current session id from `XDG_SESSION_ID`, `""` when missing. |
| `Power.user` | Current user from `USER`, `""` when missing. |
| `Power.shutdown()` | Runs `systemctl poweroff`. Returns `true` when launched. |
| `Power.reboot()` | Runs `systemctl reboot`. Returns `true` when launched. |
| `Power.suspend()` | Runs `systemctl suspend`. Returns `true` when launched. |
| `Power.hibernate()` | Runs `systemctl hibernate`. Returns `true` when launched. |
| `Power.lock()` | Runs `loginctl lock-session`. Returns `true` when launched. |
| `Power.logout()` | Runs `loginctl terminate-session <sessionId>`. Returns `false` with a warning when `sessionId` is empty, otherwise `true` when launched. |

`_run(command)` exists as an internal helper. Components should call the named actions above, not `_run()` directly.

### Typical component usage

```qml
Row {
    spacing: 8

    Button {
        text: "Lock"

        onClicked:
            Power.lock()
    }

    Button {
        text: "Suspend"

        onClicked:
            Power.suspend()
    }

    Button {
        text: "Shutdown"

        onClicked:
            Power.shutdown()
    }
}
```

That is the intended everyday usage.

Components normally should not need to know how `systemctl`, `loginctl`, session ids, or detached execution work.

---

# 3. IPC API

IPC target:

```text
n0ctos-power
```

## Core actions

| How to call | What does it do |
| ----------- | --------------- |
| `shutdown` | Runs `systemctl poweroff`. Returns `true` when launched. |
| `reboot` | Runs `systemctl reboot`. Returns `true` when launched. |
| `suspend` | Runs `systemctl suspend`. Returns `true` when launched. |
| `hibernate` | Runs `systemctl hibernate`. Returns `true` when launched. |
| `lock` | Runs `loginctl lock-session`. Returns `true` when launched. |
| `logout` | Runs `loginctl terminate-session <sessionId>`. Returns `false` when `sessionId` is empty, otherwise `true`. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-power shutdown` | `true`, system powers off |
| `qs ipc call n0ctos-power reboot` | `true`, system reboots |
| `qs ipc call n0ctos-power suspend` | `true`, system suspends |
| `qs ipc call n0ctos-power hibernate` | `true`, system hibernates |
| `qs ipc call n0ctos-power lock` | `true`, session locks |
| `qs ipc call n0ctos-power logout` | `true` when `XDG_SESSION_ID` is set, `false` with `[Power] XDG_SESSION_ID is unavailable` warning when missing |

For example:

```bash
qs ipc call n0ctos-power lock
```

returns:

```text
true
```

```bash
qs ipc call n0ctos-power shutdown
```

returns:

```text
true
```

```bash
qs ipc call n0ctos-power logout
```

returns:

```text
true
```

when a session id exists, or:

```text
false
```

with a shell warning when `XDG_SESSION_ID` is unavailable.

---

# 4. Features / limitations

## Features

### Single entry point for power actions

All power and session actions go through:

```text
Power.qml
```

instead of each panel, menu, or keybinding invoking:

```text
systemctl
loginctl
```

directly.

### Detached execution

Every action uses:

```qml
Quickshell.execDetached({
    command: command
})
```

The shell does not block waiting for the power command to finish.

### Session identity

The service exposes:

```text
sessionId <- XDG_SESSION_ID
user      <- USER
```

Both fall back to `""` when the environment variable is missing, so bindings never see `undefined`.

### Logout guard

`logout()` checks:

```text
sessionId empty -> warn + return false
sessionId set   -> terminate-session <sessionId>
```

This avoids running `loginctl terminate-session` with an empty argument.

---

## Limitations

### No confirmation or inhibition handling

The service does not ask for confirmation, check inhibitors, or delay the action.

Calling:

```qml
Power.shutdown()
```

immediately launches:

```text
systemctl poweroff
```

Any confirmation UI must live in the calling component.

### Logout requires `XDG_SESSION_ID`

If the session id is missing:

```qml
Power.logout()
```

returns:

```text
false
```

and logs:

```text
[Power] XDG_SESSION_ID is unavailable
```

It cannot guess which session to terminate.

### `lock()` does not pass a session id

`lock()` runs:

```text
loginctl lock-session
```

with no arguments. It locks the current session as resolved by `loginctl` itself. It does not target `sessionId` explicitly.

### No status or capability queries

The service reports only whether the command was launched (`true` / `false`).

There is no:

```text
canSuspend
canHibernate
isLocked
```

Components cannot ask Power whether suspend or hibernate is supported by the system.

---

# 5. Example use cases

## 5.1 A power menu

Each button maps directly to one service call:

```qml
import QtQuick
import Quickshell

import qs.services

Column {
    spacing: 8

    Button {
        text: "Shutdown"

        onClicked:
            Power.shutdown()
    }

    Button {
        text: "Reboot"

        onClicked:
            Power.reboot()
    }

    Button {
        text: "Suspend"

        onClicked:
            Power.suspend()
    }

    Button {
        text: "Hibernate"

        onClicked:
            Power.hibernate()
    }
}
```

Each call returns `true` when the detached command was launched.

---

## 5.2 Session lock and logout

Lock needs no session id, logout does:

```qml
import QtQuick

import qs.services

Row {
    spacing: 8

    Button {
        text: "Lock"

        onClicked:
            Power.lock()
    }

    Button {
        text: "Logout"

        enabled:
            Power.sessionId !== ""

        onClicked:
            Power.logout()
    }

    Text {
        visible:
            Power.sessionId === ""

        text:
            "Logout unavailable: no session"
    }
}
```

The result is:

```text
sessionId set   -> logout enabled, returns true
sessionId empty -> logout disabled, would return false
```

---

## 5.3 Terminal workflow

Lock the session:

```bash
qs ipc call n0ctos-power lock
```

Suspend:

```bash
qs ipc call n0ctos-power suspend
```

Reboot:

```bash
qs ipc call n0ctos-power reboot
```

Shut down:

```bash
qs ipc call n0ctos-power shutdown
```

Log out the current session:

```bash
qs ipc call n0ctos-power logout
```

---

# 6. Detailed architecture

This section is for developers working on `Power.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a thin action layer over `systemctl` and `loginctl`:

```text
N0ctOS Component / Service
            │
            ▼
        Power.qml
            │
     ┌──────┼────────┐
     │      │        │
     ▼      ▼        ▼
 session  power   session
 info    actions  actions
     │      │        │
     └──────┴────────┘
            │
            ▼
 Quickshell.execDetached
            │
            ▼
 systemctl / loginctl
            │
            ▼
  system / session
```

There are effectively two responsibilities:

```text
Power
    maps intent to a command

systemd / logind
    executes the power or session change
```

Power should not duplicate the policy already provided by systemd and logind.

---

## 6.2 Command execution

All public actions funnel through one helper:

```text
shutdown / reboot / suspend / hibernate / lock / logout
                        │
                        ▼
                    _run(command)
                        │
                        ▼
              Quickshell.execDetached
```

`_run()` is a guard plus a launch:

```text
command missing or empty -> return false
otherwise                 -> execDetached + return true
```

Because every public action passes a hardcoded non-empty array, they normally return `true`. The `false` path only matters for `logout()` with a missing session, which returns before reaching `_run()`, and for direct `_run()` misuse.

---

## 6.3 Logout guard

Logout is the only action with a precondition:

```text
sessionId = XDG_SESSION_ID or ""

sessionId empty?
    yes -> warn "[Power] XDG_SESSION_ID is unavailable"
           return false
    no  -> _run(["loginctl", "terminate-session", sessionId])
           return true
```

The session id is read once as a reactive property:

```qml
readonly property string sessionId:
    String(
        Quickshell.env(
            "XDG_SESSION_ID"
        ) || ""
    )
```

Callers can therefore disable logout UI with:

```qml
Power.sessionId !== ""
```

instead of handling the `false` return after the fact.

---

## 6.4 IPC architecture

IPC is a thin external interface over the same service functions.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-power
   │
   ▼
Power.qml
   │
   ▼
systemctl / loginctl
```

For example:

```bash
qs ipc call n0ctos-power shutdown
```

becomes conceptually:

```qml
Power.shutdown()
```

and:

```bash
qs ipc call n0ctos-power logout
```

becomes conceptually:

```qml
Power.logout()
```

The IPC layer returns the same `bool` the QML function returns.

---

## 6.5 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ function call
                            ▼
                    ┌─────────────────┐
                    │      Power      │
                    │                 │
                    │ sessionId/user  │
                    │ power actions   │
                    │ session actions │
                    │ _run() helper   │
                    └────────┬────────┘
                             │
                             │ execDetached
                             ▼
                    ┌─────────────────┐
                    │ systemd/logind  │
                    │                 │
                    │ systemctl       │
                    │ loginctl        │
                    └────────┬────────┘
                             │
                             ▼
                       system / session
```

The core rule is:

> **Components request what power action they need; `Power.qml` decides which `systemctl` / `loginctl` command runs it; the system handles how the action is executed.**
