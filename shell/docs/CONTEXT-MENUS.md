# N0ctOS Context Menu

This directory contains the reusable Context Menu components used by N0ctOS.

The Context Menu system is designed to provide a consistent, animated, extensible contextual UI for any N0ctOS surface.

A context menu can be used by:

* Desktop
* Widgets
* Future file managers
* Future applications or shell components
* Any other component that owns a `ContextMenu` instance

The system is intentionally **not globally singleton-based**.

A surface creates one `ContextMenu` instance and shares that instance with the components that belong to that surface.

---

# 1. Architecture

The Context Menu system consists of two core components:

```text
core/ui/
├── ContextMenu.qml
└── ContextMenuObj.qml
```

Their responsibilities are intentionally separate.

```text
ContextMenu
    │
    ├── positioning
    ├── animations
    ├── content replacement
    ├── submenu management
    ├── cursor tracking
    ├── screen clamping
    └── menu lifecycle
             │
             ▼
      ContextMenuObj
             │
             ├── text
             ├── icon
             ├── actions
             ├── submenu
             └── custom content
```

`ContextMenu.qml` is the menu controller and visual shell.

`ContextMenuObj.qml` is the reusable menu object/item that provides text, actions, submenus, and custom content.

---

# 2. Ownership model

A `ContextMenu` is a normal QML component.

It is **not** a global application singleton.

A UI surface creates one instance:

```qml
ContextMenu {
    id: contextMenu
}
```

For Desktop:

```text
Desktop
│
├── ContextMenu
│
└── WidgetLayer
    ├── Widget
    ├── Widget
    └── Widget
```

The Desktop's widgets use the Desktop-owned Context Menu instance.

A future file manager can independently create its own:

```text
FileManager
│
├── ContextMenu
└── FileView
```

This means each surface owns its own menu state, animation state, submenu tree, and content.

---

# 3. Why it is not a singleton

The Context Menu component is intentionally reusable across different UI surfaces.

A global singleton would cause unrelated surfaces to share:

```text
open/closed state
position
current content
submenus
animation state
```

That is undesirable.

Instead:

```text
Desktop
    → ContextMenu instance A

FileManager
    → ContextMenu instance B

Another surface
    → ContextMenu instance C
```

Each instance operates independently.

---

# 4. Basic usage

A surface creates one Context Menu instance:

```qml
import "."

Item {
    ContextMenu {
        id: contextMenu
    }
}
```

A component belonging to that surface can request the menu:

```qml
contextMenu.open(myMenuComponent)
```

The requester does not need to provide:

```text
source object
cursor position
screen
```

The Context Menu determines these automatically.

---

# 5. `ContextMenu.qml`

`ContextMenu.qml` is responsible for the actual menu container.

Its responsibilities include:

```text
menu visibility
menu positioning
cursor tracking
screen detection
screen clamping
content loading
content replacement
content crossfading
size animation
position animation
submenu management
menu closing
```

The component itself is intentionally unaware of what a particular menu contains.

The caller supplies a `Component`.

---

# 6. Opening a menu

The primary API is:

```qml
contextMenu.open(component)
```

The supplied value must be a QML `Component`.

Example:

```qml
Component {
    id: applicationMenu

    Column {
        spacing: 2

        ContextMenuObj {
            text: "Open"
            icon: "󰆍"
        }

        ContextMenuObj {
            text: "Settings"
            icon: ""
        }
    }
}
```

Then:

```qml
contextMenu.open(applicationMenu)
```

The menu system handles everything else.

---

# 7. Automatic source detection

The `open()` API does not receive a root object.

The Context Menu determines the source automatically.

The current source is exposed through:

```qml
contextMenu.sourceItem
```

The current pointer position is exposed through:

```qml
contextMenu.cursorPosition
```

This allows menu content to determine which object initiated the request without requiring every caller to manually pass itself.

---

# 8. Cursor tracking

The Context Menu tracks the pointer position without consuming pointer input.

When `open()` is called, the current cursor position becomes the requested anchor.

The initial desired position is:

```text
menu top-left = cursor position
```

The menu then applies screen constraints.

---

# 9. Screen detection

The Context Menu determines the screen containing the cursor.

This is especially important for multi-monitor Desktop layouts.

The same Context Menu instance can therefore operate using the coordinate space of its owning surface while still selecting the correct screen bounds.

---

# 10. Menu positioning

The first placement attempt is:

```text
cursor
  └── top-left corner of menu
```

If the menu would leave the screen, it is adjusted.

The placement system prefers the normal cursor position first.

If insufficient space exists, it may use the opposite direction around the cursor before finally clamping.

The final menu must always remain inside the usable screen area.

Conceptually:

```text
0 <= x <= screenWidth  - menuWidth
0 <= y <= screenHeight - menuHeight
```

---

# 11. Opening animation

When the menu is closed and a new menu is requested:

```text
closed
  │
  ▼
fade in
  │
  ▼
opened
```

The menu does not appear by abruptly snapping its opacity.

---

# 12. Replacing an open menu

Calling:

```qml
contextMenu.open(otherComponent)
```

while a menu is already open does not close the entire menu and recreate it abruptly.

Instead the existing menu transitions to the new request.

The following can happen simultaneously:

```text
old content
    │
    ├── crossfade ──► new content
    │
    ├── width morph ─► new width
    │
    ├── height morph → new height
    │
    └── position morph → new position
```

This allows the context menu to smoothly travel around the screen.

---

# 13. Animation retargeting

A new request can arrive while the previous request is still animating.

The current animation should not have to finish first.

Instead, animated properties are retargeted toward the latest destination.

For example:

```text
Menu A
   │
   ├── moving toward B
   │
   └── new request C
          │
          ▼
     smoothly retarget C
```

The latest request wins.

---

# 14. Content replacement

When replacing menu content, the existing content remains alive temporarily so the system can crossfade between the two states.

Conceptually:

```text
old content
opacity 1.0
      │
      ▼
crossfade
      │
      ▼
new content
opacity 1.0
```

After the transition completes, the old content is destroyed.

This avoids visual popping while the menu's dimensions are also changing.

---

# 15. Menu size

The Context Menu uses the size of its supplied content.

The content should provide a valid:

```qml
implicitWidth
implicitHeight
```

or an explicit:

```qml
width
height
```

The Context Menu then incorporates its internal padding.

When new content has a different size:

```text
old size
   │
   ▼
smooth morph
   │
   ▼
new size
```

Width and height are animated independently.

---

# 16. Context Menu padding

The Context Menu is built around `CutBox.qml`.

The menu provides configurable minimum padding.

Padding is constrained by the active CutBox corner geometry.

The intended rule is:

```qml
Math.min(
    minPadding,
    cutOrRound * 0.2
)
```

This prevents a large minimum padding value from becoming visually incompatible with small cut/round corners.

---

# 17. `ContextMenuObj.qml`

`ContextMenuObj` is the basic reusable menu object.

It is a real visual QML item and can be used directly inside a menu.

Example:

```qml
ContextMenuObj {
    text: "Open"
}
```

Its default visual form is a clickable menu row.

---

# 18. Text

Each `ContextMenuObj` exposes:

```qml
property string text: ""
```

The text is rendered as the primary menu label.

Example:

```qml
ContextMenuObj {
    text: "Open Terminal"
}
```

---

# 19. Icons

Menu objects support Nerd Font icons.

Example:

```qml
ContextMenuObj {
    text: "Open Terminal"
    icon: ""
}
```

The icon appears alongside the text.

If no icon is supplied, the text layout remains valid without reserving unnecessary icon space.

---

# 20. Enabled state

Menu objects can be disabled:

```qml
ContextMenuObj {
    text: "Unavailable"
    enabled: false
}
```

A disabled object:

```text
does not activate
does not execute actions
does not open submenus
```

and is rendered using its disabled appearance.

---

# 21. Actions

A `ContextMenuObj` can contain multiple action types.

The supported action types are:

```text
JS function
Quickshell Process
submenu Component
```

The function and process actions are executable actions.

A submenu is visual/navigation state rather than a second executable action.

---

# 22. JavaScript actions

A JavaScript function can be supplied directly.

Example:

```qml
ContextMenuObj {
    text: "Refresh"
    icon: "󰑓"

    functionAction: function() {
        refresh()
    }
}
```

When the object is activated, the function runs.

---

# 23. Process actions

The process action uses an actual Quickshell `Process`.

Example:

```qml
ContextMenuObj {
    text: "Open Kitty"
    icon: ""

    process: Process {
        command: [
            "kitty"
        ]
    }
}
```

The Context Menu does not recreate process handling internally.

The caller supplies the `Process` object.

---

# 24. Multiple actions

Multiple action types may be present on the same `ContextMenuObj`.

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

The defined executable actions are both part of the same menu object.

The menu item does not require different wrapper objects for different action types.

---

# 25. Action close behavior

`ContextMenuObj` exposes:

```qml
property bool closeOnClick: true
```

This controls whether activation closes the menu.

Example:

```qml
ContextMenuObj {
    text: "Refresh"
    closeOnClick: false
}
```

The caller therefore controls whether a normal action dismisses the menu.

Submenu navigation is handled separately.

---

# 26. Arbitrary content

A `ContextMenuObj` may contain arbitrary QML children.

Example:

```qml
ContextMenuObj {
    text: "Volume"
    icon: ""

    Slider {
        width: 180
        value: 50
    }
}
```

The default text/header remains at the top-left.

Custom children appear below it and are aligned to the left.

This allows menu entries to contain things such as:

```text
sliders
toggles
labels
progress bars
buttons
custom controls
custom layouts
```

The menu item does not need to know what those children are.

---

# 27. Child interaction

Custom children remain normal QML objects.

They may therefore receive their own mouse/keyboard interaction where appropriate.

For example:

```qml
ContextMenuObj {
    text: "Volume"

    Slider {
        activeFocusOnTab: true
    }
}
```

The `ContextMenuObj` should not blindly capture all input that belongs to a child control.

---

# 28. Submenus

A `ContextMenuObj` may define:

```qml
property Component submenu
```

The submenu is a normal QML `Component`.

It can contain:

```text
ContextMenuObj
```

or arbitrary QML content.

Example:

```qml
ContextMenuObj {
    text: "Appearance"
    icon: "󰔎"

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

---

# 29. Submenu opening

Submenus open immediately when their owning object is hovered.

No delayed hover timer is required.

Conceptually:

```text
hover "Appearance"
        │
        ▼
open submenu immediately
```

Clicking the object can also request the submenu.

---

# 30. Submenu positioning

Submenus behave like cascading desktop menus.

Example:

```text
┌─────────────────┐
│ Open            │
│ Edit         ───┼───┐
│ Appearance    ▶ │   │
│ Settings        │   │
└─────────────────┘   │
                      │
                      └── submenu
```

The Context Menu finds the nearest usable side of the parent menu item.

It prefers the right side when sufficient space is available.

If the right side does not fit, it checks the left side.

The final submenu is still clamped to the screen.

---

# 31. Nested submenus

Submenus can contain `ContextMenuObj` objects which themselves define more submenus.

This allows arbitrary nesting:

```text
Main Menu
└── Appearance
    └── Theme
        └── Accent
            └── Cyan
```

Each submenu is positioned relative to its parent object.

---

# 32. Closing a submenu action

A submenu item may be configured:

```qml
closeOnClick: true
```

When that item is activated:

```text
clicked item
      │
      ▼
its submenu closes
      │
      ▼
parent submenus close
      │
      ▼
root ContextMenu closes
```

The entire menu tree is dismissed.

It does not leave ancestor menus open.

---

# 33. Context Menu closing

The public close API is:

```qml
contextMenu.close()
```

Closing the root menu also removes all active submenus.

The Context Menu remains instantiated and can immediately be reused later.

---

# 34. Reusing the same ContextMenu

A single instance can be reused indefinitely.

For example:

```qml
contextMenu.open(widgetMenu)
```

later:

```qml
contextMenu.open(desktopMenu)
```

later:

```qml
contextMenu.open(otherMenu)
```

Each request simply replaces the current content.

There is no requirement to create and destroy a Context Menu instance for every right-click.

---

# 35. Context menus from widgets

A Desktop Widget can request the Desktop-owned Context Menu.

The Widget itself does not create a second menu.

Conceptually:

```text
Desktop
│
├── ContextMenu
│
└── WidgetLayer
      │
      ├── Clock
      ├── CPU
      └── Weather
```

A widget requests:

```text
Desktop ContextMenu
```

and provides its own menu component.

---

# 36. Context menus from the Desktop

The Desktop itself can also provide a menu.

For example:

```text
Right-click empty desktop
        │
        ▼
Desktop menu
        │
        ├── Add Widget
        ├── Edit Widgets
        ├── Presets
        └── ...
```

This uses the exact same Context Menu instance as widgets.

---

# 37. Context Menu ownership by future surfaces

Any future surface can adopt the same architecture.

Example:

```text
FileManager.qml
│
├── ContextMenu
│
├── file grid
└── sidebar
```

The file manager's children reuse that instance.

This makes Context Menu a reusable UI infrastructure component rather than a Desktop-specific implementation.

---

# 38. CutBox integration

`ContextMenu.qml` derives its visual shell from:

```text
core/ui/CutBox.qml
```

This means it inherits the same visual language as the rest of N0ctOS.

The Context Menu can therefore use:

```text
cut
round
bgColor
borderColor
borderWidth
borderGlow
shadow
```

where appropriate.

The Context Menu itself does not need to reimplement cut/round geometry.

---

# 39. Input behavior

The Context Menu's pointer tracking must not interfere with the rest of the surface.

The pointer-position tracking layer is passive.

Actual interaction occurs through menu content and menu objects.

This is important because N0ctOS widgets can already contain nested interactive Qt Quick controls.

The Context Menu should not introduce an unnecessary full-screen input blocker merely to know where the pointer is.

---

# 40. Recommended component template

A typical menu can look like:

```qml
Component {
    id: menu

    Column {
        spacing: 2

        ContextMenuObj {
            text: "Open"
            icon: "󰆍"

            functionAction: function() {
                openItem()
            }
        }

        ContextMenuObj {
            text: "Open With"
            icon: "󰏖"

            submenu: Component {
                Column {
                    spacing: 2

                    ContextMenuObj {
                        text: "Kitty"

                        process: Process {
                            command: ["kitty"]
                        }
                    }

                    ContextMenuObj {
                        text: "Neovim"

                        functionAction: function() {
                            openWithNeovim()
                        }
                    }
                }
            }
        }

        ContextMenuObj {
            text: "Delete"
            icon: "󰆴"

            functionAction: function() {
                deleteItem()
            }

            closeOnClick: true
        }
    }
}
```

Then:

```qml
contextMenu.open(menu)
```

---

# 41. Important design rules

The Context Menu system must preserve these rules.

### Rule 1 — one owner, one instance

A surface owns one Context Menu instance and shares it with its descendants.

Do not create a new Context Menu for every widget or menu request.

### Rule 2 — no global ContextMenu singleton

`ContextMenu.qml` is reusable, but each surface owns its own instance.

### Rule 3 — callers provide Components

Menu content belongs to the caller.

The Context Menu owns presentation and lifecycle, not application-specific menu logic.

### Rule 4 — source detection is automatic

Callers do not pass their root object or cursor position.

### Rule 5 — menu always stays on screen

All main menus and submenus are clamped to their owning screen.

### Rule 6 — latest request wins

A new menu request can interrupt an existing transition and retarget it.

### Rule 7 — old content survives only for transition

Old content may remain temporarily for crossfade, then must be destroyed.

### Rule 8 — submenu close propagates

Closing a configured submenu item closes the complete Context Menu tree.

---

# 42. Common mistakes

### Creating one menu per widget

Do not do:

```qml
Widget {
    ContextMenu {}
}
```

for every widget.

Instead the owning surface should create one Context Menu and provide it to its widgets.

---

### Making ContextMenu a singleton

Do not declare:

```qml
pragma Singleton
```

for `ContextMenu.qml`.

Different surfaces must be able to own independent instances.

---

### Passing the source manually

Avoid APIs such as:

```qml
contextMenu.open(component, root, mouse)
```

The Context Menu is responsible for determining:

```text
sourceItem
cursorPosition
screen
```

---

### Manually implementing CutBox geometry

Do not duplicate CutBox's geometry implementation.

Use:

```qml
CutBox {
    ...
}
```

and configure it.

---

### Destroying the whole menu for every request

Do not recreate the Context Menu instance every time.

The intended behavior is:

```text
existing menu
      ↓
content replacement
      ↓
crossfade + size morph + movement
```

---

# 43. Minimal API reference

## `ContextMenu`

```qml
open(component)
close()
```

Properties:

```qml
opened
sourceItem
cursorPosition

animationDuration

backgroundColor
borderColor
borderWidth
borderGlow

cut
round
minPadding
```

Internal responsibilities include:

```text
submenu management
position calculation
screen clamping
content transitions
```

---

## `ContextMenuObj`

Properties:

```qml
text
icon
enabled

functionAction
process
submenu

closeOnClick

submenuIcon
```

Content:

```qml
default property alias contentData
```

Context Menu integration is assigned automatically when the object is loaded into a menu.

---

# 44. Testing checklist

```text
[ ] ContextMenu can be instantiated normally
[ ] ContextMenu is not a singleton
[ ] One surface can own one menu instance
[ ] ContextMenu.open(Component) works
[ ] sourceItem is detected automatically
[ ] cursorPosition is captured
[ ] correct screen is determined
[ ] menu stays inside screen bounds
[ ] initial opening fades in
[ ] replacing content crossfades
[ ] width morphs
[ ] height morphs
[ ] position morphs
[ ] animations can be interrupted
[ ] old content is eventually destroyed

[ ] ContextMenuObj renders text
[ ] Nerd Font icon renders
[ ] disabled object works
[ ] JS function action works
[ ] Process action works
[ ] multiple actions can coexist
[ ] closeOnClick works
[ ] custom child content works

[ ] submenu opens on hover
[ ] submenu opens immediately
[ ] submenu chooses available side
[ ] submenu stays on screen
[ ] nested submenu works
[ ] submenu replacement works
[ ] closing submenu item closes entire menu tree

[ ] Desktop can use ContextMenu
[ ] Widgets can reuse Desktop's ContextMenu
[ ] Future surfaces can create independent instances
```

---

# 45. The rule to remember

A Context Menu should answer:

> **"How should contextual UI be presented and navigated?"**

The component requesting the menu answers:

> **"What should this contextual UI contain?"**

The separation is:

```text
Caller
    │
    │ Component
    ▼
ContextMenu
    │
    ├── position
    ├── screen bounds
    ├── animation
    ├── replacement
    ├── submenu tree
    └── lifecycle
            │
            ▼
    ContextMenuObj
            │
            ├── text
            ├── icon
            ├── function
            ├── Process
            ├── submenu
            └── custom content
```

Keep the Context Menu generic.

Keep the menu contents owned by the caller.

That separation is what allows the same system to work for Desktop today and completely different N0ctOS surfaces in the future.
