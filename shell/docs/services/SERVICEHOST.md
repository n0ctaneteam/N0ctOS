# ServiceHost Infrastructure

`ServiceHost.qml` is N0ctOS's tiny startup helper that forces eager service creation.

It gives the shell entry point one place to touch singletons that must exist immediately instead of on first use.

Services listed in `eagerServices` are created at launch. Services not listed stay naturally lazy.

The normal usage pattern is:

```text
Shell entry point
    │
    ▼
ServiceHost
    │
    ├── eagerServices -> singleton instances created now
    └── all other services -> created on first use
```

---

# 1. What does it do?

`ServiceHost.qml` exists exactly once, created from the shell entry point.

It declares one property:

```qml
property list<QtObject> eagerServices: [
    ConfigStore,
    Config,
    DateTime,
    Screens,
    Clipboard,
    Power,
    Audio,
    Battery,
    Brightness,
    Network,
    Bluetooth,
    Media,
    Notifications,
    SystemTray,
    Animations
]
```

Referencing those singletons inside the list literal touches them, so their instances are created immediately at startup.

Any service not in that list is never touched here and remains lazily instantiated when first referenced elsewhere.

On completion it logs two lines:

```text
[N0ctOS Services] ServiceHost started
[N0ctOS Services] Eager services: 15
```

where `15` is the current `eagerServices.length`.

---

# 2. UI API

`ServiceHost` is not imported by components. It is instantiated once at startup. Components use the individual services directly.

## Core API

| How to read | What does it do |
| ----------- | --------------- |
| `<host>.eagerServices` | Ordered list of singleton instances to create eagerly at startup. |
| `<host>.eagerServices.length` | Number of eager services (currently `15`). Used only for the startup log. |

### Typical instantiation

The shell entry point creates one host:

```qml
ServiceHost {
}
```

No per-component import or per-component setup is needed. Once the host exists, the listed singletons exist too.

That is the intended everyday usage.

Components normally should not need to reference `ServiceHost` at all.

---

# 3. IPC API

`ServiceHost.qml` defines no IPC target, so there is no IPC API.

---

# 4. Features / limitations

## Features

### One place for eager startup

All eagerly-started services are visible in a single 15-entry list, in declaration order.

### Lazy by default

A service gains eager startup only by being added to the list. Everything else keeps Quickshell's natural lazy behavior with no extra code.

### Startup logging

`Component.onCompleted` emits two `console.info` lines confirming the host started and how many services were marked eager.

### No persistence or polling

The file holds no configuration, watches no files, and runs no timers. It only references singletons and logs.

---

## Limitations

### Eager set is static

Adding or removing an eager service requires editing `eagerServices` in `ServiceHost.qml`. There is no runtime call to register or unregister a service.

### Log-only observability

The host reports only the eager count. It does not check readiness, health, or load order, and exposes no ready signal.

### Entry-point owned

The "exactly once" guarantee comes from the entry point creating one instance. The file itself does not enforce singleton construction.

---

# 5. Example use cases

## 5.1 Start all core services at launch

Create the host once from the shell entry point:

```qml
ServiceHost {
}
```

`ConfigStore`, `Config`, `DateTime`, and the remaining listed singletons are then alive before any panel or widget binds to them.

---

## 5.2 Confirm eager startup in logs

After launch, expect:

```text
[N0ctOS Services] ServiceHost started
[N0ctOS Services] Eager services: 15
```

A missing first line means the host was never instantiated. A wrong count means the list was edited.

---

## 5.3 Make a service eager

Add its singleton to the list:

```qml
property list<QtObject> eagerServices: [
    ConfigStore,
    Config,
    // ...
    Animations,
    MyNewService
]
```

Remove an entry to return that service to lazy creation.

---

# 6. Detailed architecture

This section is for developers working on `ServiceHost.qml` and shell startup.

---

## 6.1 Overall architecture

The host is a thin reference holder between the entry point and the service singletons:

```text
Shell entry point
        │
        ▼
  ServiceHost.qml (QtObject, id: root)
        │
        ▼
  eagerServices: list<QtObject>
        │
        ├── ConfigStore, Config, DateTime, Screens
        ├── Clipboard, Power, Audio, Battery
        ├── Brightness, Network, Bluetooth, Media
        └── Notifications, SystemTray, Animations
```

There is one responsibility:

```text
ServiceHost
    touch listed singletons at startup + log count
```

It implements no service logic itself.

---

## 6.2 Eager vs lazy

The rule is:

```text
listed in eagerServices -> created when host is created
not listed              -> created on first reference elsewhere
```

The file contains no conditional logic, no loader, and no timer. Eagerness is purely "this list references it."

---

## 6.3 Startup logging

`Component.onCompleted` runs once after the host and its list are constructed:

```qml
Component.onCompleted: {
    console.info(
        "[N0ctOS Services] ServiceHost started"
    )

    console.info(
        "[N0ctOS Services] Eager services:",
        eagerServices.length
    )
}
```

The second line is a sanity count, not a per-service report.

The core rule is:

> **Shell entry points declare which services start eagerly; `ServiceHost.qml` holds that list and nothing else; each service handles how it initializes itself.**
