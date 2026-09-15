# N0ctOS Context Menu

This directory contains the reusable Context Menu components used by N0ctOS.

The Context Menu system provides animated, extensible contextual UI for any N0ctOS surface.

It can be used by:

```text
Desktop
Widgets
File Manager
Settings
Future applications
Any custom N0ctOS component
```

The system is designed around two components:

```text
core/ui/
├── ContextMenu.qml
└── ContextMenuObj.qml
```

`ContextMenu.qml` owns the menu itself.

`ContextMenuObj.qml` defines the objects displayed inside that menu.

The system is intentionally **not globally singleton-based**.

One surface creates one `ContextMenu` instance and shares that instance with the components belonging to that surface.

---

# 1. Design Philosophy

The Context Menu system separates:

```text
WHAT the menu contains
        │
        ▼
ContextMenuObj
```

from:

```text
HOW the menu is presented
        │
        ▼
ContextMenu
```

Therefore:

```text
ContextMenu
├── positioning
├── screen clamping
├── animation
├── content replacement
├── submenu management
└── lifecycle

ContextMenuObj
├── text
├── actions
├── submenu
└── custom content
```

A caller should normally only define the menu contents.

The Context Menu handles presentation.

---

# 2. Component Structure

```text
core/ui/
├── ContextMenu.qml
└── ContextMenuObj.qml
```

## `ContextMenu.qml`

Responsible for:

```text
menu lifecycle
cursor tracking
source detection
screen detection
positioning
screen clamping
opening animation
closing animation
content replacement
content crossfade
size morphing
submenu creation
submenu positioning
submenu cleanup
```

## `ContextMenuObj.qml`

Responsible for:

```text
menu item presentation
text
hover state
click handling
function actions
Process actions
submenu declarations
custom child content
close behavior
```

---

# 3. Ownership Model

`ContextMenu.qml` is a normal component.

It is **not** a singleton.

A surface creates one instance.

Example:

```qml
ContextMenu {
    id: contextMenu
}
```

A Desktop may therefore have:

```text
Desktop
├── ContextMenu
└── WidgetLayer
    ├── Widget
    ├── Widget
    └── Widget
```

All widgets use the Desktop-owned instance.

A future File Manager can independently create:

```text
FileManager
├── ContextMenu
└── FileView
```

These instances do not share menu state.

---

# 4. Why ContextMenu Is Not a Singleton

Different UI surfaces may need independent menu state.

A global singleton would cause unrelated surfaces to share:

```text
current menu
current position
open/closed state
submenu tree
transition state
```

Instead:

```text
Desktop
    → ContextMenu A

FileManager
    → ContextMenu B
```

Each surface owns its own menu.

This also makes the component reusable outside Desktop.

---

# 5. Basic Usage

Create one Context Menu:

```qml
ContextMenu {
    id: contextMenu
}
```

Then define a menu `Component`:

```qml
Component {
    id: menu

    Column {
        spacing: 2

        ContextMenuObj {
            text: "Open"
        }

        ContextMenuObj {
            text: "Delete"
        }
    }
}
```

Open it:

```qml
contextMenu.open(menu)
```

The caller does not manually supply:

```text
source object
mouse coordinates
screen
```

The Context Menu determines those automatically.

---

# 6. `ContextMenu.open()`

The primary API is:

```qml
contextMenu.open(component)
```

The argument must be a QML `Component`.

Example:

```qml
Component {
    id: applicationMenu

    Column {
        spacing: 2

        ContextMenuObj {
            text: "󰈹  Firefox"
        }

        ContextMenuObj {
            text: "󰆍  Terminal"
        }
    }
}
```

Then:

```qml
contextMenu.open(applicationMenu)
```

---

# 7. Automatic Source Detection

The `open()` call does not accept a root object.

The Context Menu automatically determines the item currently under the pointer.

The result is exposed through:

```qml
contextMenu.sourceItem
```

The current cursor position is exposed through:

```qml
contextMenu.cursorPosition
```

This allows menu content to know which surface/component triggered the request without requiring an explicit source argument.

---

# 8. Cursor Position

The Context Menu continuously tracks the pointer without intentionally consuming it.

When `open()` is called, the current cursor position is used as the requested anchor.

The initial requested position is:

```text
menu top-left = cursor position
```

The position is then adjusted to remain inside the owning screen.

---

# 9. Screen Detection

The Context Menu determines the screen associated with the current pointer position.

This allows one Context Menu instance to operate correctly across a multi-monitor Desktop.

The menu therefore does not require callers to manually choose a monitor for every request.

---

# 10. Main Menu Positioning

The initial requested location is:

```text
cursor
└── menu top-left
```

If that would place the menu outside the screen, the menu attempts a conventional flip.

Conceptually:

```text
Normal:

cursor ┌───────────────┐
       │ menu          │
       └───────────────┘


Near right edge:

┌───────────────┐ cursor
│ menu          │
└───────────────┘
```

The final position is always clamped to the screen.

---

# 11. Opening Animation

When the Context Menu is closed and `open()` is called:

```text
closed
   │
   ▼
snap to target position
   │
   ├── size animation
   └── fade animation
   │
   ▼
opened
```

The menu must **not slide from the previous menu position**.

This distinction is intentional.

---

# 12. Replacing an Open Menu

When a menu is already open:

```qml
contextMenu.open(anotherMenu)
```

does not abruptly destroy the current menu.

Instead:

```text
old content
    │
    ├── crossfade
    │
    ▼
new content
```

At the same time:

```text
old width  → new width
old height → new height
old pos    → new pos
```

all transition smoothly.

---

# 13. Animation Retargeting

If a new request arrives while an existing transition is still running:

```text
A
 ↓
B requested
 ↓
C requested
```

the menu does not need to finish moving to B first.

It retargets directly toward C.

The latest request wins.

---

# 14. Closing Animation

`close()` is animated.

```qml
contextMenu.close()
```

causes:

```text
opened
   │
   ├── fade out
   └── size collapse
   │
   ▼
closed
```

The menu remains alive during the transition.

After the close animation completes, the loaded menu content is released.

---

# 15. Reopening During Close

A new `open()` request may arrive while the menu is fading out.

The menu should recover into an open state rather than waiting for the old close operation to complete.

The new request becomes the active request.

---

# 16. Menu Size

Menu size is derived from the supplied content.

Content should preferably provide:

```qml
implicitWidth
implicitHeight
```

or valid explicit dimensions.

The Context Menu adds its configured internal padding.

Width and height are animated when the menu changes size.

---

# 17. CutBox Integration

The visual menu shell uses the N0ctOS `CutBox` component.

This means the Context Menu follows the same geometry and styling system as the rest of the N0ctOS UI.

The shell can use:

```text
cut
round
bgColor
borderColor
borderWidth
borderGlow
```

without duplicating CutBox geometry.

---

# 18. Context Menu Padding

The menu exposes:

```qml
property real minPadding
```

The effective padding is constrained by the active corner geometry.

The intended relationship is:

```qml
Math.min(
    minPadding,
    corner * 0.2
)
```

This keeps the padding visually appropriate for cut/rounded corners.

---

# 19. `ContextMenuObj`

`ContextMenuObj` is the standard visual object used inside a menu.

Example:

```qml
ContextMenuObj {
    text: "Open"
}
```

It provides:

```text
text
enabled
functionAction
process
submenu
closeOnClick
custom child content
```

---

# 20. Text and Icons

There is intentionally **no separate icon property**.

Icons are part of the `text` string.

Example:

```qml
ContextMenuObj {
    text: "󰈹  Firefox"
}
```

This keeps icon and label alignment under one text layout.

Nerd Font glyphs can therefore be used directly:

```qml
text: "󰆍  Open Terminal"
```

---

# 21. Enabled State

A menu object can be disabled:

```qml
ContextMenuObj {
    text: "Unavailable"
    enabled: false
}
```

Disabled objects:

```text
do not execute actions
do not open submenus
do not activate
```

and use their disabled visual state.

---

# 22. JavaScript Function Actions

A menu object can execute a JavaScript function.

Example:

```qml
ContextMenuObj {
    text: "Refresh"

    functionAction: function() {
        refresh()
    }
}
```

The function is executed when the object is activated.

---

# 23. Process Actions

The `process` property contains an actual Quickshell `Process`.

Example:

```qml
ContextMenuObj {
    text: "Open Terminal"

    process: Process {
        command: [
            "kitty"
        ]
    }
}
```

The Context Menu does not replace Quickshell's process system.

The caller supplies the `Process`.

---

# 24. Multiple Actions

A single `ContextMenuObj` may define multiple executable actions.

For example:

```qml
ContextMenuObj {
    text: "Restart"

    functionAction: function() {
        prepareRestart()
    }

    process: Process {
        command: [
            "systemctl",
            "--user",
            "restart",
            "example.service"
        ]
    }
}
```

The function and process are both valid parts of the same object.

---

# 25. `closeOnClick`

Normal action objects expose:

```qml
property bool closeOnClick: true
```

Example:

```qml
ContextMenuObj {
    text: "Refresh"
    closeOnClick: false
}
```

If `closeOnClick` is enabled, activating the object requests closure of the owning Context Menu.

The close behavior is configurable per object.

---

# 26. Custom Content

A `ContextMenuObj` may contain arbitrary QML children.

Example:

```qml
ContextMenuObj {
    text: "Volume"
    
    Slider {
        width: 180
        value: 50
    }
}
```

The structure is:

```text
┌───────────────────────────┐
│ Volume                    │
│                           │
│ [ slider                 ]│
└───────────────────────────┘
```

The text/header stays at the top.

Custom child content is placed underneath and aligned to the left.

---

# 27. Interactive Child Content

Custom children remain normal QML objects.

Controls such as:

```text
Slider
Switch
Button
TextField
custom widgets
```

can therefore retain their normal input behavior.

The `ContextMenuObj` should not blindly prevent child controls from receiving their own input.

---

# 28. Submenus

A `ContextMenuObj` can expose a submenu:

```qml
ContextMenuObj {
    text: "Appearance"

    submenu: Component {
        Column {
            spacing: 2

            ContextMenuObj {
                text: "Dark"
            }

            ContextMenuObj {
                text: "Light"
            }
        }
    }
}
```

The submenu is itself a QML `Component`.

It can contain `ContextMenuObj` objects or arbitrary QML content.

---

# 29. Submenu Indicator

Objects containing a submenu display a right-side arrow.

The arrow is anchored to the **right edge of the parent menu item**.

Conceptually:

```text
┌──────────────────────────────┐
│ Appearance                  │
└──────────────────────────────┘
```

The label remains on the left.

The indicator remains on the right.

---

# 30. Submenu Opening

Hovering a submenu object opens its submenu immediately.

Clicking it can also request the submenu.

The submenu remains associated with its parent menu object.

---

# 31. Submenu Positioning

Submenus use conventional cascading-menu behavior.

The preferred placement is:

```text
main menu → submenu
```

If there is insufficient space on the right:

```text
submenu ← main menu
```

The submenu is then clamped to the owning screen.

Conceptually:

```text
┌──────────────────┐
│ Appearance      ├──────┐
│ Settings         │      │
└──────────────────┘      │
                          │ submenu
                          └──────
```

or, near the right edge:

```text
┌──────┐
│      │
│submenu├─────┐
│      │ menu │
└──────┘      │
              └──────
```

---

# 32. Nested Submenus

Submenus can contain objects with further submenus.

Example:

```text
Main Menu
└── Appearance
    └── Theme
        └── Accent
            └── Cyan
```

The Context Menu manages the entire submenu tree.

---

# 33. Closing a Menu Tree

When a leaf object has:

```qml
closeOnClick: true
```

and is activated from a submenu:

```text
leaf activated
      │
      ▼
leaf submenu closes
      │
      ▼
parent submenu closes
      │
      ▼
all ancestor submenus close
      │
      ▼
root ContextMenu closes
```

The entire context-menu tree is dismissed.

It must not leave ancestor submenus floating on screen.

---

# 34. Context Menu Reuse

The same instance can be reused indefinitely.

```qml
contextMenu.open(menuA)
```

then:

```qml
contextMenu.open(menuB)
```

then:

```qml
contextMenu.open(menuC)
```

There is no need to create a new `ContextMenu` for every request.

---

# 35. ContextMenuObj API

The important public properties are:

```qml
property string text
property bool enabled

property var functionAction
property Process process
property Component submenu

property bool closeOnClick
property string submenuIcon
```

Visual configuration includes:

```qml
normalTextColor
disabledTextColor
hoverBackground
hoverTextColor

headerHeight
horizontalPadding
iconWidth
spacing

animationDuration
```

Context Menu integration fields are managed automatically by `ContextMenu`.

---

# 36. ContextMenu API

Primary public functions:

```qml
contextMenu.open(component)
contextMenu.close()
```

Useful exposed state:

```qml
contextMenu.opened
contextMenu.sourceItem
contextMenu.cursorPosition
contextMenu.currentContent
```

Internal submenu management is handled by the Context Menu itself.

---

# 37. What Callers Should Not Do

A caller should not manually:

```text
calculate screen bounds
position the menu
animate menu movement
fade menu content
create submenu shells
manage submenu lifetime
destroy old menu content
track cursor position
```

Those responsibilities belong to `ContextMenu`.

---

# 38. What ContextMenuObj Should Not Do

`ContextMenuObj` should not:

```text
manage the entire menu tree
position itself relative to the screen
create the root ContextMenu
track global cursor position
perform screen detection
manage sibling objects
```

It describes one piece of the menu.

The parent Context Menu owns the overall structure.

---

# 39. Interaction Model

The overall relationship is:

```text
Caller
   │
   │ provides Component
   ▼
ContextMenu
   │
   ├── positions menu
   ├── animates menu
   ├── loads content
   └── manages submenu tree
          │
          ▼
    ContextMenuObj
          │
          ├── text
          ├── function
          ├── Process
          ├── submenu
          └── custom QML
```

---

# 40. Example — Simple Menu

```qml
Component {
    id: simpleMenu

    Column {
        spacing: 2

        ContextMenuObj {
            text: "󰈹  Open Browser"

            process: Process {
                command: ["firefox"]
            }
        }

        ContextMenuObj {
            text: "󰆍  Open Terminal"

            process: Process {
                command: ["kitty"]
            }
        }

        ContextMenuObj {
            text: "󰑓  Refresh"

            functionAction: function() {
                refresh()
            }
        }
    }
}
```

Open it:

```qml
contextMenu.open(simpleMenu)
```

---

# 41. Example — Submenu

```qml
Component {
    id: appearanceMenu

    Column {
        spacing: 2

        ContextMenuObj {
            text: "󰔎  Appearance"

            submenu: Component {
                Column {
                    spacing: 2

                    ContextMenuObj {
                        text: "󰔎  Dark"

                        functionAction: function() {
                            setTheme("dark")
                        }
                    }

                    ContextMenuObj {
                        text: "󰔎  Light"

                        functionAction: function() {
                            setTheme("light")
                        }
                    }
                }
            }
        }
    }
}
```

---

# 42. Example — Custom Content

```qml
Component {
    id: volumeMenu

    Column {
        spacing: 2

        ContextMenuObj {
            text: "  Volume"

            Slider {
                width: 220

                from: 0
                to: 100
                value: 50
            }
        }
    }
}
```

---

# 43. Example — Multiple Actions

```qml
ContextMenuObj {
    text: "Restart Service"

    functionAction: function() {
        console.log("Preparing restart")
    }

    process: Process {
        command: [
            "systemctl",
            "--user",
            "restart",
            "example.service"
        ]
    }

    closeOnClick: true
}
```

---

# 44. Example — Desktop Integration

Desktop owns the Context Menu:

```qml
ContextMenu {
    id: contextMenu
}
```

The WidgetLayer and its widgets reuse that instance.

The Context Menu therefore becomes shared infrastructure for:

```text
Desktop
WidgetLayer
Widget
future Desktop components
```

without turning `ContextMenu.qml` into Desktop-specific code.

---

# 45. Future Integration

The same pattern can be used in another surface:

```text
FileManager
├── ContextMenu
├── FileList
└── FileItem
```

A file item can request:

```text
Open
Rename
Delete
Open With >
Properties
```

using exactly the same reusable Context Menu components.

Only the owner changes.

The menu implementation does not.

---

# 46. Testing Checklist

```text
[ ] ContextMenu instantiates normally
[ ] ContextMenu is not a singleton
[ ] One owner can share one instance
[ ] open(Component) works
[ ] close() works
[ ] sourceItem is detected
[ ] cursorPosition is detected
[ ] correct screen is detected

[ ] closed → open snaps to new position
[ ] closed → open fades in
[ ] closed → open morphs size
[ ] open → open animates position
[ ] open → open crossfades content
[ ] open → open morphs size
[ ] animations can be interrupted
[ ] close animates
[ ] reopen during closing works

[ ] ContextMenuObj renders full menu width
[ ] text renders correctly
[ ] Nerd Font glyphs align with text
[ ] disabled state works
[ ] function action works
[ ] Process action works
[ ] multiple actions work
[ ] closeOnClick works
[ ] custom children render underneath text
[ ] custom child controls remain interactive

[ ] submenu renders
[ ] submenu arrow is on right
[ ] submenu opens on hover
[ ] submenu opens on click
[ ] submenu chooses available side
[ ] submenu stays on screen
[ ] nested submenu works
[ ] submenu content can be arbitrary QML

[ ] closing submenu item closes its submenu
[ ] closing submenu item closes ancestor submenus
[ ] closing submenu item closes root ContextMenu

[ ] Desktop can own a ContextMenu
[ ] widgets can reuse Desktop's ContextMenu
[ ] another future surface can own another ContextMenu
```

---

# 47. Common Mistakes

### Creating a ContextMenu per widget

Do not do:

```qml
Widget {
    ContextMenu {}
}
```

for every widget.

The owning surface should provide the Context Menu instance.

---

### Making ContextMenu a singleton

Do not add:

```qml
pragma Singleton
```

The component is reusable, but its instances belong to their respective surfaces.

---

### Passing source or cursor manually

Avoid APIs such as:

```qml
contextMenu.open(component, root, mouse)
```

The Context Menu determines those values automatically.

---

### Using a separate icon property

Do not create:

```qml
icon: "󰈹"
text: "Firefox"
```

Use:

```qml
text: "󰈹  Firefox"
```

The label and icon are intentionally one text value.

---

### Reimplementing submenu positioning

A menu object should declare:

```qml
submenu: someComponent
```

and let `ContextMenu` determine where the submenu belongs.

---

# 48. Final Architecture

```text
                         Surface
                            │
                            ▼
                     ContextMenu
                            │
           ┌────────────────┼────────────────┐
           │                │                │
           ▼                ▼                ▼
    ContextMenuObj   ContextMenuObj   ContextMenuObj
           │                                │
           │                                └── submenu
           │                                      │
           ▼                                      ▼
      custom QML                         ContextMenuObj
      content                                  ...
```

The surface owns the `ContextMenu`.

The caller defines the menu `Component`.

`ContextMenu` manages presentation.

`ContextMenuObj` defines individual menu content and actions.

---

# 49. The Rule to Remember

The Context Menu system should answer:

> **How should contextual UI be presented, animated, positioned, and navigated?**

The caller answers:

> **What should this contextual UI contain and what should its items do?**

Keep those responsibilities separate.

That is what makes the same Context Menu system suitable for Desktop today and completely different N0ctOS surfaces in the future.
