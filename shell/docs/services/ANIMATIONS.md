# Animations Service

`Animations.qml` is N0ctOS's centralized animation configuration and profile service.

It gives every shell component one consistent place to read and write animation settings without touching configuration files directly.

The service supports global animation profiles, per-component animation data, temporary/global overrides, automatic defaults, and profile composition.

The normal usage pattern is:

```text
Component
    │
    ▼
Animations
    │
    ├── active profile
    ├── overrides
    └── resolved animation data
    │
    ▼
Config
    │
    ▼
homeConfig
```

---

# 1. What does it do?

`Animations.qml` stores and resolves animation settings for the shell.

A profile can contain simple values:

```json
{
    "launcher": {
        "enabled": true
    }
}
```

or detailed component-specific settings:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 200,
        "opacityDuration": 300
    }
}
```

Profiles can then be selected globally:

```json
{
    "animations": {
        "profile": "full"
    }
}
```

and temporary overrides can change individual settings without modifying the profile itself:

```json
{
    "animations": {
        "overrides": {
            "cxtmenu": {
                "fadeDuration": 100
            }
        }
    }
}
```

The effective value is resolved in this order:

```text
override
    ↓
active profile
    ↓
fallback
```

So a component can simply do:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    200
)
```

and not care where the value came from.

If that property does not exist, the fallback is returned **and written into the active profile**.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

| How to call                                       | What does it do                                                                                            |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `Animations.get(path, fallback, scope)`           | Reads value. override + active profile. If missing, returns and writes `fallback` into the active profile. |
| `Animations.set(path, value, scope, profileName)` | Creates or updates a value. Missing objects are created automatically.                                     |
| `Animations.remove(path, scope, profileName)`     | Deletes a value from a profile or override.                                                                |
| `Animations.isEnabled(component, fallback)`       | Convenience wrapper for `<component>.enabled`.                                                             |
| `Animations.selectProfile(name)`                  | Changes the active global profile.                                                                         |
| `Animations.resolve(name)`                        | Returns a profile with the current overrides merged into it.                                               |
| `Animations.setProfileFrom(source, target)`       | Creates/updates a profile from another profile plus the current overrides.                                 |
| `Animations.getStatus()`                          | Returns service/configuration state.                                                                       |

|Example                                                   |
|--------------------------------------------------------- |
|`Animations.get("cxtmenu.fadeDuration", 500, "resolved")` |
|`Animations.set("cxtmenu.fadeDuration", 250)`             |
|`Animations.remove("cxtmenu.fadeDuration")`               |
|`Animations.isEnabled("cxtmenu", true)`                   |
|`Animations.selectProfile("minimal")`                     |
|`Animations.resolve("full")`                              |
|`Animations.setProfileFrom("full", "myFull")`             |
|`Animations.getStatus()`                                  |

## Scopes

The third argument of `get()`, and the third argument of `set()`/`remove()`, controls where the data comes from or is written.

| Scope        | Meaning                                                                                |
| ------------ | -------------------------------------------------------------------------------------- |
| `"resolved"` | Use override first, then active profile. This is the default for `get()`.              |
| `"profile"`  | Read/write the selected profile, or a specific profile when `profileName` is supplied. |
| `"override"` | Read/write the global override layer only.                                             |

For example:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    500,
    "resolved"
)
```

reads:

```text
animations.overrides.cxtmenu.fadeDuration
        ↓
animations.profiles.<active>.cxtmenu.fadeDuration
        ↓
500
```

while:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    500,
    "profile"
)
```

ignores the override layer.

### Typical component usage

```qml
readonly property bool animate:
    Animations.isEnabled(
        "cxtmenu",
        true
    )

readonly property int fadeDuration:
    Animations.get(
        "cxtmenu.fadeDuration",
        200
    )

readonly property int opacityDuration:
    Animations.get(
        "cxtmenu.opacityDuration",
        300
    )
```

That is the intended everyday usage.

Components normally should not need to know how profiles, overrides, or JSON persistence work.

---

# 3. IPC API

IPC target:

```text
n0ctos-animations
```

## Core CRUD

| How to call                           | What does it do                                                                           | 
| ------------------------------------- | ----------------------------------------------------------------------------------------- | 
| `get <path> [fallback-json] [scope]`  | Reads an animation value. Return and write fallback into the active profile when missing. |
| `set <path> <json> [scope] [profile]` | Creates or updates a value.                                                               | 
| `remove <path> [scope] [profile]`     | Deletes a value.                                                                          | 

| Example                                                               |
| --------------------------------------------------------------------- |
| `qs ipc call n0ctos-animations get cxtmenu.fadeDuration 500 resolved` |
| `qs ipc call n0ctos-animations set cxtmenu.fadeDuration 250 profile`  |
| `qs ipc call n0ctos-animations remove cxtmenu.fadeDuration profile`   |

`<json>` must be valid JSON.

For example:

```bash
qs ipc call n0ctos-animations set \
    cxtmenu \
    '{"enabled":true,"fadeDuration":250}'
```

Boolean:

```bash
qs ipc call n0ctos-animations set \
    cxtmenu.enabled \
    true
```

Number:

```bash
qs ipc call n0ctos-animations set \
    cxtmenu.fadeDuration \
    250
```

String:

```bash
qs ipc call n0ctos-animations set \
    launcher.easing \
    '"OutCubic"'
```

## Other operations

| How to call                        | What does it do                                                                    |
| ---------------------------------- | ---------------------------------------------------------------------------------- |
| `getStatus`                        | Shows service state, current profile, revision, profile count, and override count. |
| `isEnabled <component>`            | Reads `<component>.enabled` from the resolved configuration.                       |
| `selectProfile <name>`             | Changes the globally selected animation profile.                                   |
| `resolve <name>`                   | Returns the requested profile with current overrides merged into it.               |
| `setProfileFrom <source> <target>` | Creates/updates a target profile from a source profile plus current overrides.     |

| Example                                                        |
|  -------------------------------------------------------------- |
|  `qs ipc call n0ctos-animations getStatus`                      |
|  `qs ipc call n0ctos-animations isEnabled cxtmenu`              |
|  `qs ipc call n0ctos-animations selectProfile minimal`          |
|  `qs ipc call n0ctos-animations resolve full`                   |
|  `qs ipc call n0ctos-animations setProfileFrom full customFull` |

---

# 4. Features / limitations

## Features

### Global profiles

Profiles allow the entire shell to switch between predefined animation configurations:

```text
none
minimal
full
```

The built-in profiles are only defaults. User-created profiles are supported.

### Nested component configuration

Animation data is not limited to a single boolean.

A component can store whatever settings it needs:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 200,
        "opacityDuration": 300,
        "easing": "OutCubic"
    }
}
```

### Automatic defaults

Components can safely request a value with a fallback:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    200
)
```

If the value does not exist, `200` is returned and written into the active profile.

This lets profiles gradually acquire component-specific defaults without a giant predefined schema.

### Overrides

Overrides allow one setting to temporarily take precedence over the active profile.

```qml
Animations.set(
    "cxtmenu.fadeDuration",
    100,
    "override"
)
```

The profile remains unchanged.

Removing the override:

```qml
Animations.remove(
    "cxtmenu.fadeDuration",
    "override"
)
```

causes the component to fall back to the profile value again.

### Deep merge

Nested objects are merged recursively.

For example:

```text
profile:
cxtmenu:
    enabled: true
    fadeDuration: 200
    opacityDuration: 300

override:
cxtmenu:
    fadeDuration: 100
```

results in:

```text
resolved:
cxtmenu:
    enabled: true
    fadeDuration: 100
    opacityDuration: 300
```

The override changes only the property it actually contains.

### Config integration

The service does not implement its own JSON persistence.

All configuration is handled through `Config`.

Animation data is stored in:

```text
homeConfig
```

which is the normal N0ctOS user configuration file.

### Reactive configuration

Changing the active profile, profile data, or overrides updates the service's reactive state.

Components using `Animations.get()` can therefore reevaluate when configuration changes.

### No polling

The service does not repeatedly check the configuration file.

It relies on `Config`'s reactive document and persistence system.

---

## Limitations

### Animation keys are convention-based

The service does not maintain a hardcoded schema for every N0ctOS component.

A component can define:

```text
cxtmenu
launcher
hyprland
panel
notifications
```

and whatever properties it requires.

Consistency of names is therefore a N0ctOS development convention.

### Missing values default to fallback

If a component does not provide a fallback:

```qml
Animations.get(
    "cxtmenu.fadeDuration"
)
```

the service returns `undefined` when the value is missing.

For normal component settings, providing a sensible fallback is recommended.

### Overrides are global

The override layer applies to the resolved configuration regardless of which profile is active.

If an override exists for:

```text
cxtmenu.fadeDuration
```

switching from `minimal` to `full` does not remove that override.

### Profile values are arbitrary JSON

The service expects profiles to contain objects, but component data itself is intentionally flexible.

This gives developers freedom, but also means malformed or inconsistent component data is ultimately a configuration problem.

---

# 5. Example use cases

## 5.1 A component reading its animation setup

A component should normally expose its animation settings as properties:

```qml
import QtQuick
import Quickshell

import qs.services

Item {
    readonly property bool animate:
        Animations.isEnabled(
            "cxtmenu",
            true
        )

    readonly property int fadeDuration:
        Animations.get(
            "cxtmenu.fadeDuration",
            200
        )

    readonly property int opacityDuration:
        Animations.get(
            "cxtmenu.opacityDuration",
            300
        )
}
```

The component does not need to know whether these values came from:

```text
full
minimal
none
an override
a newly materialized fallback
```

It only receives the effective value.

---

## 5.2 A component with multiple animation settings

A component can keep all of its settings under its own namespace:

```qml
readonly property var animation:
    ({
        enabled:
            Animations.isEnabled(
                "launcher",
                true
            ),

        openDuration:
            Animations.get(
                "launcher.openDuration",
                220
            ),

        closeDuration:
            Animations.get(
                "launcher.closeDuration",
                180
            ),

        scale:
            Animations.get(
                "launcher.scale",
                0.96
            ),

        easing:
            Animations.get(
                "launcher.easing",
                "OutCubic"
            )
    })
```

The resulting configuration may become:

```json
{
    "launcher": {
        "enabled": true,
        "openDuration": 220,
        "closeDuration": 180,
        "scale": 0.96,
        "easing": "OutCubic"
    }
}
```

---

## 5.3 Providing a fallback that automatically becomes part of the profile

Suppose the active profile currently contains:

```json
{
    "cxtmenu": {
        "enabled": true
    }
}
```

A component asks for:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    200
)
```

Because `fadeDuration` does not exist, the service:

```text
does not find the property
        ↓
returns 200
        ↓
writes:
cxtmenu.fadeDuration = 200
```

The profile becomes:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 200
    }
}
```

The component therefore only needs to define a fallback once.

---

## 5.4 Creating/updating profile-specific values

A specific profile can be modified without selecting it first.

For example:

```qml
Animations.set(
    "cxtmenu.fadeDuration",
    250,
    "profile",
    "full"
)
```

This targets:

```text
animations.profiles.full.cxtmenu.fadeDuration
```

If `full` does not already exist, the service creates the missing profile object automatically.

For example:

```qml
Animations.set(
    "cxtmenu",
    {
        enabled: true,
        fadeDuration: 250,
        opacityDuration: 300
    },
    "profile",
    "myProfile"
)
```

creates or updates:

```json
{
    "myProfile": {
        "cxtmenu": {
            "enabled": true,
            "fadeDuration": 250,
            "opacityDuration": 300
        }
    }
}
```

---

## 5.5 Adding a temporary override

Suppose the active `full` profile contains:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 250
    }
}
```

A component or shell control can override only the duration:

```qml
Animations.set(
    "cxtmenu.fadeDuration",
    100,
    "override"
)
```

The resolved configuration becomes:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 100
    }
}
```

The profile itself still contains:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 250
    }
}
```

Removing the override:

```qml
Animations.remove(
    "cxtmenu.fadeDuration",
    "override"
)
```

restores the profile's `250`.

---

## 5.6 Switching profiles

Use:

```qml
Animations.selectProfile(
    "minimal"
)
```

The active profile changes to:

```text
minimal
```

All components that consume `Animations` automatically begin resolving against that profile.

A typical shell profile switcher might look like:

```qml
Row {
    spacing: 8

    Repeater {
        model: [
            "none",
            "minimal",
            "full"
        ]

        delegate: Rectangle {
            required property string modelData

            width: 90
            height: 34

            radius: 8

            color:
                Animations.profile ===
                    modelData
                    ? "#2acfff"
                    : "#141d26"

            Text {
                anchors.centerIn:
                    parent

                text:
                    parent.modelData

                color:
                    Animations.profile ===
                        parent.modelData
                        ? "#061018"
                        : "#ffffff"
            }

            MouseArea {
                anchors.fill:
                    parent

                onClicked:
                    Animations.selectProfile(
                        parent.modelData
                    )
            }
        }
    }
}
```

---

## 5.7 Checking the final resolved configuration

A developer can inspect the active resolved data:

```qml
Text {
    text:
        JSON.stringify(
            Animations.resolved,
            null,
            2
        )
}
```

For example:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 100,
        "opacityDuration": 300
    },

    "hyprland": {
        "enabled": true
    },

    "launcher": {
        "enabled": false
    }
}
```

This is useful when debugging profile/override behavior.

---

## 5.8 Creating a profile from a customized setup

Suppose:

```text
active profile = full
```

and the current overrides are:

```json
{
    "cxtmenu": {
        "fadeDuration": 100
    },

    "launcher": {
        "enabled": false
    }
}
```

The developer can bake those changes into another profile:

```qml
Animations.setProfileFrom(
    "full",
    "myFull"
)
```

The result is effectively:

```text
full
+
current overrides
        ↓
myFull
```

The new profile can then be selected normally:

```qml
Animations.selectProfile(
    "myFull"
)
```

---

## 5.9 Terminal workflow

Read the active cxtmenu duration:

```bash
qs ipc call n0ctos-animations get \
    cxtmenu.fadeDuration \
    200 \
    resolved
```

Set it in the active profile:

```bash
qs ipc call n0ctos-animations set \
    cxtmenu.fadeDuration \
    250 \
    profile
```

Create an override:

```bash
qs ipc call n0ctos-animations set \
    cxtmenu.fadeDuration \
    100 \
    override
```

Remove that override:

```bash
qs ipc call n0ctos-animations remove \
    cxtmenu.fadeDuration \
    override
```

Inspect the complete service:

```bash
qs ipc call n0ctos-animations getStatus
```

---

# 6. Detailed architecture

This section is for developers working on `Animations.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a configuration layer built on top of N0ctOS's existing `Config` service.

```text
N0ctOS Component / Service
            │
            ▼
      Animations.qml
            │
     ┌──────┼────────┐
     │      │        │
     ▼      ▼        ▼
  Profile Overrides Resolved
     │      │        │
     └──────┴────────┘
            │
            ▼
         Config
            │
            ▼
       homeConfig
```

There are effectively two responsibilities:

```text
Animations
    animation-specific logic

Config
    configuration persistence and reactivity
```

Animations should not duplicate the functionality already provided by Config.

---

## 6.2 Configuration structure

The service owns the `animations` section of `homeConfig`.

The structure is:

```json
{
    "animations": {
        "profile": "full",

        "profiles": {
            "none": {},
            "minimal": {},
            "full": {}
        },

        "overrides": {}
    }
}
```

A real configuration might look like:

```json
{
    "animations": {
        "profile": "full",

        "profiles": {
            "none": {
                "cxtmenu": {
                    "enabled": false
                },

                "hyprland": {
                    "enabled": false
                },

                "launcher": {
                    "enabled": false
                }
            },

            "minimal": {
                "cxtmenu": {
                    "enabled": false
                },

                "hyprland": {
                    "enabled": true,
                    "duration": 180
                },

                "launcher": {
                    "enabled": false
                }
            },

            "full": {
                "cxtmenu": {
                    "enabled": true,
                    "fadeDuration": 200,
                    "opacityDuration": 300
                },

                "hyprland": {
                    "enabled": true,
                    "duration": 250
                },

                "launcher": {
                    "enabled": true,
                    "openDuration": 220
                }
            }
        },

        "overrides": {
            "cxtmenu": {
                "fadeDuration": 100
            }
        }
    }
}
```

The service itself does not require every component to contain the same properties.

Profiles are intentionally flexible.

---

## 6.3 The three layers

Animation state has three logical layers:

```text
profile
   │
   ▼
active profile data
   │
   ▼
overrides
   │
   ▼
resolved configuration
```

The active profile is selected using:

```text
animations.profile
```

Its data comes from:

```text
animations.profiles.<profile>
```

Overrides come from:

```text
animations.overrides
```

The resolved configuration is generated in memory and is not stored as a fourth JSON section.

---

## 6.4 Resolution order

For a property:

```text
cxtmenu.fadeDuration
```

the service checks:

```text
1. animations.overrides.cxtmenu.fadeDuration

2. animations.profiles.<active>.cxtmenu.fadeDuration

3. fallback supplied by get()
```

If the override exists:

```text
override wins
```

If there is no override but the profile has the property:

```text
profile wins
```

If neither exists:

```text
fallback wins
```

When a fallback is supplied, that fallback is also written into the active profile.

Therefore:

```text
missing property
      ↓
fallback returned
      ↓
fallback materialized in profile
```

This makes future reads use the stored value instead of repeatedly requiring the fallback.

---

## 6.5 Why overrides are separate

Overrides are not profile mutations.

For example:

```text
full:
    cxtmenu.fadeDuration = 200

override:
    cxtmenu.fadeDuration = 100
```

The resolved value is:

```text
100
```

but the profile remains:

```text
200
```

This is important because switching profiles or removing the override should restore the original profile data.

Overrides are therefore best thought of as:

```text
"change the effective value"
```

rather than:

```text
"modify the profile"
```

---

## 6.6 Deep merge

Animation data is nested, so a shallow merge is not enough.

Given:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 200,
        "opacityDuration": 300
    }
}
```

and:

```json
{
    "cxtmenu": {
        "fadeDuration": 100
    }
}
```

a shallow replacement would incorrectly produce:

```json
{
    "cxtmenu": {
        "fadeDuration": 100
    }
}
```

The service instead performs a recursive merge:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 100,
        "opacityDuration": 300
    }
}
```

Objects merge recursively.

Primitive values and arrays replace the previous value.

---

## 6.7 Path-based data access

The service uses dotted paths:

```text
cxtmenu.fadeDuration
```

instead of forcing components to manipulate nested objects manually.

The path:

```text
cxtmenu.fadeDuration
```

is internally interpreted as:

```text
cxtmenu
    └── fadeDuration
```

This allows a component to request only the property it needs.

---

## 6.8 `set()` semantics

`set()` is the single write primitive.

It is intentionally an upsert:

```text
set
 ├── property exists → update
 └── property missing → create
```

For example:

```qml
Animations.set(
    "cxtmenu.fadeDuration",
    250
)
```

If the active profile is:

```json
{
    "cxtmenu": {
        "enabled": true
    }
}
```

the service creates:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 250
    }
}
```

Missing intermediate objects are created automatically.

For example:

```qml
Animations.set(
    "launcher.motion.openDuration",
    220
)
```

can create:

```json
{
    "launcher": {
        "motion": {
            "openDuration": 220
        }
    }
}
```

The caller does not have to construct those parent objects first.

---

## 6.9 Profile-targeted `set()`

The optional `profileName` argument allows a write to target a profile other than the active one.

Example:

```qml
Animations.set(
    "cxtmenu.fadeDuration",
    250,
    "profile",
    "minimal"
)
```

This writes to:

```text
animations.profiles.minimal.cxtmenu.fadeDuration
```

If `minimal` does not yet exist as an object, the missing profile object is created.

This means profile construction is naturally handled by the same write primitive.

---

## 6.10 Override-targeted `set()`

With:

```qml
Animations.set(
    "cxtmenu.fadeDuration",
    100,
    "override"
)
```

the value goes to:

```text
animations.overrides.cxtmenu.fadeDuration
```

This never modifies the selected profile.

---

## 6.11 `get()` semantics

`get()` is the single read primitive.

The basic form:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    200
)
```

uses the default scope:

```text
resolved
```

which means:

```text
override → active profile → fallback
```

The explicit form is useful when a component needs a specific layer:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    200,
    "profile"
)
```

or:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    undefined,
    "override"
)
```

---

## 6.12 Fallback materialization

Fallback behavior is a deliberate part of the design.

For:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    200
)
```

if the property is missing:

```text
return 200
     +
write 200 into active profile
```

This lets components define defaults locally.

For example, a newly introduced feature can ship with:

```qml
Animations.get(
    "newWidget.animationDuration",
    180
)
```

without requiring the developer to modify every built-in profile immediately.

The first use materializes:

```json
{
    "newWidget": {
        "animationDuration": 180
    }
}
```

into the active profile.

---

## 6.13 Override fallback behavior

An important exception is the override scope.

For:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    100,
    "override"
)
```

a missing override does **not** create:

```json
"overrides": {
    "cxtmenu": {
        "fadeDuration": 100
    }
}
```

because a missing override means:

```text
"No override exists."
```

It should not automatically become an override just because a fallback was provided.

Fallback materialization therefore applies to profile/resolved reads, not override-only reads.

---

## 6.14 `remove()` semantics

`remove()` deletes a nested property.

For the active profile:

```qml
Animations.remove(
    "cxtmenu.fadeDuration"
)
```

the property is removed from:

```text
animations.profiles.<active>.cxtmenu
```

For an override:

```qml
Animations.remove(
    "cxtmenu.fadeDuration",
    "override"
)
```

the property is removed from:

```text
animations.overrides.cxtmenu
```

Empty parent objects can then be cleaned up.

---

## 6.15 Removing an override

This is the normal way to return a component to profile-controlled behavior:

```text
profile:
    fadeDuration = 200

override:
    fadeDuration = 100

remove override

resolved:
    fadeDuration = 200
```

The profile itself never needed to be rewritten.

---

## 6.16 Profile selection

The selected global profile is stored at:

```text
animations.profile
```

The service exposes:

```qml
Animations.profile
```

for reading and:

```qml
Animations.selectProfile(
    "minimal"
)
```

for changing it.

The selected name is not itself part of the component animation data.

It is global profile-selection state.

---

## 6.17 `activeProfile`

`Animations.activeProfile` is the selected profile's raw data.

For example:

```qml
Animations.activeProfile
```

may contain:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 200
    },

    "launcher": {
        "enabled": true
    }
}
```

It does **not** include overrides.

That distinction is important.

---

## 6.18 `resolved`

`Animations.resolved` is the final merged configuration:

```text
activeProfile
      +
overrides
      ↓
resolved
```

For example:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 100
    },

    "launcher": {
        "enabled": false
    }
}
```

when the selected profile contains:

```json
{
    "cxtmenu": {
        "enabled": true,
        "fadeDuration": 200
    },

    "launcher": {
        "enabled": true
    }
}
```

and the overrides contain:

```json
{
    "cxtmenu": {
        "fadeDuration": 100
    },

    "launcher": {
        "enabled": false
    }
}
```

---

## 6.19 `resolve()`

`resolve(profileName)` is useful when developers need to inspect or generate a resolved configuration for a profile other than the active one.

```qml
Animations.resolve(
    "minimal"
)
```

conceptually performs:

```text
minimal profile
      +
current global overrides
      ↓
resolved minimal configuration
```

The currently selected global profile is not changed.

---

## 6.20 Profile composition

`setProfileFrom()` provides profile baking.

Example:

```qml
Animations.setProfileFrom(
    "full",
    "myFull"
)
```

performs:

```text
full profile
      +
current overrides
      ↓
myFull
```

This is useful when a user or developer has customized an existing profile and wants to turn that customized result into a standalone profile.

The operation does not need to modify the original profile.

---

## 6.21 Built-in profiles

The service provides baseline profiles such as:

```text
none
minimal
full
```

They are initialization defaults.

They are not intended to prevent users from defining additional profiles.

For example:

```text
full
minimal
none

myFull
gaming
presentation
power-save
```

can all coexist.

---

## 6.22 Why profiles are flexible

The service does not maintain a giant hardcoded list such as:

```text
cxtmenu.fadeDuration
launcher.openDuration
panel.slideDuration
...
```

Instead, components define their own namespaces.

For example:

```text
cxtmenu.*
launcher.*
hyprland.*
notifications.*
panel.*
wallpaper.*
```

This allows a new component to add animation settings without requiring the central animation service to be modified.

The service only needs to know how to:

```text
read
write
remove
merge
persist
```

the data.

---

## 6.23 Config integration

`Animations.qml` uses the existing `Config` service.

It should not create its own:

```qml
FileView
```

and should not directly write:

```text
~/.config/N0ctOS/config.json
```

Instead it operates through:

```qml
Config.get(...)
Config.set(...)
```

The normal target is:

```text
homeConfig
```

which is N0ctOS's primary configuration document. `Config` already handles document state, watching, saving, atomic writes, and write queuing.

---

## 6.24 Reactive state

The service consumes the reactive `Config` document.

Conceptually:

```text
config file changes
        │
        ▼
Config document changes
        │
        ▼
Animations state reevaluates
        │
        ▼
component bindings reevaluate
```

A component does not need to manually reload animation configuration.

For example:

```qml
readonly property int duration:
    Animations.get(
        "launcher.openDuration",
        220
    )
```

can react to configuration changes through the service.

The same reactive model is used by the existing Config service.

---

## 6.25 Persistence

Writes flow through Config:

```text
Animations.set()
        │
        ▼
Config.set()
        │
        ▼
configuration document changes
        │
        ▼
Config save queue
        │
        ▼
homeConfig written
```

Animations does not need to implement:

```text
atomic writes
write queue
directory creation
external file watching
reload debounce
```

because those are already responsibilities of Config.

---

## 6.26 External configuration changes

The same rule applies when a user edits the configuration externally.

For example:

```text
editor changes config.json
        │
        ▼
Config detects change
        │
        ▼
Config reloads document
        │
        ▼
Animations sees new document
        │
        ▼
resolved animation state changes
```

Animations therefore remains a consumer of configuration state rather than a second configuration engine.

---

## 6.27 JSON cloning

Animation profiles and overrides are returned through cloned JavaScript data.

This prevents consumers from accidentally mutating the service's internal structures without going through the service API.

For example:

```qml
Animations.resolved
```

is intended as data for reading and UI construction.

To change it, use:

```qml
Animations.set(...)
Animations.remove(...)
```

rather than attempting to mutate:

```qml
Animations.resolved.cxtmenu.enabled = false
```

---

## 6.28 Why direct mutation is undesirable

Direct mutation would bypass:

```text
path validation
override rules
profile selection
Config.set()
persistence
reactivity
```

For example, this:

```qml
Animations.resolved.cxtmenu.enabled = false
```

does not represent a controlled configuration operation.

The correct operation is:

```qml
Animations.set(
    "cxtmenu.enabled",
    false
)
```

That gives the service a clear path for determining where and how the change is stored.

---

## 6.29 IPC architecture

IPC is a thin external interface over the same service API.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-animations
   │
   ▼
Animations.qml
   │
   ▼
Config
```

For example:

```bash
qs ipc call n0ctos-animations set \
    cxtmenu.fadeDuration \
    250
```

becomes conceptually:

```qml
Animations.set(
    "cxtmenu.fadeDuration",
    250
)
```

The IPC layer serializes JSON values for terminal use.

---

## 6.30 Why IPC stays high-level

IPC should expose useful configuration operations, not the internal implementation.

External callers do not need to know about:

```text
raw config object
deep merge implementation
path traversal helper
clone helper
Config document internals
```

They only need:

```text
get
set
remove
resolve
selectProfile
getStatus
```

This keeps the IPC interface stable even if the internal implementation changes.

---

## 6.31 Performance model

Animations is intended to be extremely cheap during normal UI operation.

A component read such as:

```qml
Animations.get(
    "cxtmenu.fadeDuration",
    200
)
```

does not perform filesystem I/O.

The filesystem is handled by Config.

The animation service operates on the already-loaded reactive configuration document.

Normal runtime work is therefore:

```text
QML binding
    ↓
Animations
    ↓
in-memory object lookup
```

rather than:

```text
QML binding
    ↓
filesystem
    ↓
JSON parsing
    ↓
lookup
```

---

## 6.32 No polling

Animations does not use a polling timer to detect changes.

There is no:

```qml
Timer {
    interval: 1000
    repeat: true

    onTriggered:
        reloadAnimations()
}
```

Changes are propagated through Config's existing reactive/watch infrastructure.

This avoids unnecessary CPU activity.

---

## 6.33 Service boundaries

The responsibilities are intentionally divided:

```text
Animations
    animation profiles
    animation overrides
    animation resolution
    animation defaults
    animation data API

Config
    configuration documents
    file watching
    persistence
    atomic writes
    save queue
    external reloads
```

Animations should not duplicate Config's file-management responsibilities.

---

## 6.34 Data ownership

Animations owns:

```text
animations.profile
animations.profiles
animations.overrides
```

Inside the profile objects, the component namespace belongs conceptually to the component that defines it.

For example:

```text
animations.profiles.full.cxtmenu.*
```

belongs to Context Menu behavior.

The central service does not need to understand what every property means.

---

## 6.35 Component convention

A component should keep all of its animation settings under one namespace.

Good:

```text
cxtmenu.enabled
cxtmenu.fadeDuration
cxtmenu.opacityDuration
cxtmenu.easing
```

Also good:

```text
launcher.enabled
launcher.openDuration
launcher.closeDuration
launcher.scale
```

Avoid scattering component settings across unrelated names such as:

```text
fadeDuration
launcherDuration
launcherOpen
menuFade
```

because the component namespace is what keeps profiles understandable.

---

## 6.36 Recommended component pattern

A reusable component can expose animation configuration locally:

```qml
Item {
    readonly property bool animationEnabled:
        Animations.isEnabled(
            "launcher",
            true
        )

    readonly property int openDuration:
        Animations.get(
            "launcher.openDuration",
            220
        )

    readonly property int closeDuration:
        Animations.get(
            "launcher.closeDuration",
            180
        )

    readonly property string easing:
        Animations.get(
            "launcher.easing",
            "OutCubic"
        )
}
```

The rest of the component can then use:

```qml
Behavior on opacity {
    enabled:
        animationEnabled

    NumberAnimation {
        duration:
            openDuration

        easing.type:
            Easing.OutCubic
    }
}
```

This keeps animation lookup separate from the component's actual visual logic.

---

## 6.37 Complete resolution lifecycle

The complete lifecycle of a component read is:

```text
Component requests:
    cxtmenu.fadeDuration
          │
          ▼
Animations.get()
          │
          ▼
check override
          │
      ┌───┴───┐
     yes      no
      │        │
      ▼        ▼
   return   check profile
               │
           ┌───┴───┐
          yes      no
           │        │
           ▼        ▼
        return    fallback?
                       │
                   ┌───┴───┐
                  yes      no
                   │        │
                   ▼        ▼
                return    undefined
                   │
                   ▼
         materialize fallback
          into active profile
```

---

## 6.38 Complete write lifecycle

A write follows:

```text
Animations.set()
       │
       ▼
resolve target
       │
       ├── active profile
       │
       └── override layer
       │
       ▼
create missing objects
       │
       ▼
modify in-memory object
       │
       ▼
Config.set()
       │
       ▼
Config document changes
       │
       ▼
Config save queue
       │
       ▼
homeConfig
```

Animations itself does not perform the final file write.

---

## 6.39 Complete profile-switch lifecycle

When:

```qml
Animations.selectProfile(
    "minimal"
)
```

is called:

```text
animations.profile
        │
        ▼
Config.set()
        │
        ▼
Config document changes
        │
        ▼
Animations.profile changes
        │
        ▼
activeProfile changes
        │
        ▼
resolved changes
        │
        ▼
component bindings reevaluate
```

Existing overrides remain active because they belong to the global override layer.

---

## 6.40 Why overrides survive profile switching

Suppose:

```text
profile = full

full:
    cxtmenu.fadeDuration = 200

override:
    cxtmenu.fadeDuration = 100
```

Resolved:

```text
100
```

Now switch to:

```text
minimal
```

If minimal contains:

```text
cxtmenu.fadeDuration = 150
```

the result is still:

```text
100
```

because:

```text
override
    >
profile
```

Switching profiles does not clear overrides.

To restore profile control, the override must be removed.

---

## 6.41 Configuration fallback architecture

Fallback materialization solves a common problem in a growing shell.

Without it, every new animation property needs to be manually added to every profile.

With it:

```qml
Animations.get(
    "newComponent.duration",
    180
)
```

can introduce the value automatically.

The active profile gains:

```json
{
    "newComponent": {
        "duration": 180
    }
}
```

while older profiles can remain untouched until they actually need the value.

---

## 6.42 Why this is useful for N0ctOS

N0ctOS has many independent UI systems:

```text
Context Menu
Launcher
Panels
Hyprland interactions
Notifications
Wallpaper transitions
System tray
Quick settings
OSD
```

Each one may eventually need:

```text
enabled
duration
delay
easing
opacity
scale
slide
blur
```

Putting those settings into one generic animation service means the rest of the shell does not need separate configuration systems for each component.

---

## 6.43 Example final configuration

A realistic configuration can therefore look like:

```json
{
    "animations": {
        "profile": "full",

        "profiles": {
            "none": {
                "cxtmenu": {
                    "enabled": false
                },

                "launcher": {
                    "enabled": false
                },

                "hyprland": {
                    "enabled": false
                }
            },

            "minimal": {
                "cxtmenu": {
                    "enabled": false
                },

                "launcher": {
                    "enabled": false,
                    "openDuration": 0
                },

                "hyprland": {
                    "enabled": true,
                    "duration": 180
                }
            },

            "full": {
                "cxtmenu": {
                    "enabled": true,
                    "fadeDuration": 200,
                    "opacityDuration": 300,
                    "easing": "OutCubic"
                },

                "launcher": {
                    "enabled": true,
                    "openDuration": 220,
                    "closeDuration": 180,
                    "scale": 0.96
                },

                "hyprland": {
                    "enabled": true,
                    "duration": 250
                }
            }
        },

        "overrides": {
            "cxtmenu": {
                "fadeDuration": 100
            }
        }
    }
}
```

The resulting state is:

```text
Selected profile:
    full

Active profile:
    full.cxtmenu.fadeDuration = 200

Override:
    cxtmenu.fadeDuration = 100

Resolved:
    cxtmenu.fadeDuration = 100
```

---

## 6.44 What UI / service code should not do

Components should not:

```text
read config.json directly

create FileView objects for animation settings

implement animation-profile persistence

duplicate override handling

manually merge profile + override data

poll the configuration file

modify Animations.resolved directly

assume every component has the same animation properties

hardcode profile selection logic
```

Instead:

```qml
Animations.get(...)
Animations.set(...)
Animations.remove(...)
Animations.isEnabled(...)
```

should be the normal interface.

---

## 6.45 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ get()
                            ▼
                    ┌─────────────────┐
                    │   Animations    │
                    │                 │
                    │ profile         │
                    │ profiles        │
                    │ overrides       │
                    │ resolution      │
                    │ defaults        │
                    └────────┬────────┘
                             │
                             │ Config API
                             ▼
                    ┌─────────────────┐
                    │     Config      │
                    │                 │
                    │ reactive data   │
                    │ file watching   │
                    │ persistence     │
                    │ write queue     │
                    └────────┬────────┘
                             │
                             ▼
                         homeConfig
```

The core rule is:

> **Components define what animation settings they need; `Animations.qml` decides where those values come from and how they are resolved; `Config` handles how they are persisted.**
