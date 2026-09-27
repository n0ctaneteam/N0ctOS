# N0ctOS Context Menu

The N0ctOS Context Menu system provides a reusable, singleton-driven context menu for the Quickshell desktop shell.

It supports:

* Normal menu items
* Arbitrary inline QML content inside menu objects
* Nested submenus
* Hover-open and click-pinned submenus
* Multi-level submenu trees
* Automatic cursor positioning
* Multi-monitor support
* Compositor-reserved-space awareness
* Automatic edge flipping
* Maximum menu dimensions
* Vertical scrolling for overflowing menus
* Scrollbar support
* Overflow fade effects
* Root-menu reposition animation
* Submenu fade-in/fade-out
* Multiple Wayland layers
* Theme-configurable colors
* Menu actions through JavaScript functions or `Process`

The system is split into two components:

```text
core/
├── lib/
│   └── ContextMenu.qml
│
└── ui/
    └── ContextMenuObj.qml
```

`ContextMenu.qml` is the menu controller and rendering system.

`ContextMenuObj.qml` is the reusable menu-item component used to construct menu content.

---

# 1. Architecture

The system consists of one singleton controller and dynamically loaded menu content.

```text
                 ContextMenu
                      │
                      │ open(Component)
                      ▼
              ┌───────────────┐
              │  Menu Level 0 │
              │    Loader     │
              └───────────────┘
                      │
                      ▼
              ContextMenuObj
                 │       │
                 │       └── submenu
                 │
                 ▼
              Menu Level 1
                      │
                      ▼
              ContextMenuObj
                      │
                      └── submenu
                             │
                             ▼
                         Menu Level 2
```

The important distinction is:

```text
ContextMenu
    = controller / window / positioning / submenu state

ContextMenuObj
    = actual menu item / row
```

Menu content is supplied to the singleton as a `Component`.

Example:

```qml
Component {
    Column {
        ContextMenuObj {
            text: "Open"
        }

        ContextMenuObj {
            text: "Delete"
        }
    }
}
```

Then:

```qml
ContextMenu.open(
    myMenu
)
```

---

# 2. Public API

`ContextMenu` is a singleton.

No instance needs to be created manually.

Import it through the N0ctOS core library:

```qml
import qs.core.lib
```

The primary API is:

```qml
ContextMenu.open(component)
ContextMenu.open(component, layer)
ContextMenu.close()
```

The singleton also exposes:

```qml
ContextMenu.isOpen
ContextMenu.menuOpen
```

---

# 3. Opening a menu

The basic form is:

```qml
ContextMenu.open(
    myMenu
)
```

The argument must be a `Component`.

Example:

```qml
Component {
    id: myMenu

    Column {
        ContextMenuObj {
            text: "Open"
        }

        ContextMenuObj {
            text: "Rename"
        }

        ContextMenuObj {
            text: "Delete"
        }
    }
}
```

Then:

```qml
ContextMenu.open(
    myMenu
)
```

The context menu automatically determines:

* Current cursor position
* Current monitor
* Matching Quickshell screen
* Compositor-reserved space
* Final menu position
* Whether the menu should flip left/right
* Whether the menu should flip up/down
* Final menu size

The caller does not need to provide cursor coordinates.

---

# 4. Re-opening an already-open menu

Calling `open()` while the menu is already visible is valid.

There is intentionally no:

```qml
if (menuOpen)
    return
```

guard.

Calling:

```qml
ContextMenu.open(
    anotherMenu
)
```

while a menu is already open replaces the root menu content.

The root menu is repositioned using the current cursor location.

Every opening snaps into place: the tight host is parked at the computed menu origin.

There is no position animation on re-open; the menu repositions instantly.

Submenus do not use position animation either.

---

# 5. Menu layers

The second `open()` argument is optional.

```qml
ContextMenu.open(
    myMenu,
    layer
)
```

The accepted layers are the Wayland `WlrLayer` values:

```qml
WlrLayer.Background
WlrLayer.Bottom
WlrLayer.Top
WlrLayer.Overlay
```

Import:

```qml
import Quickshell.Wayland
```

## Default layer

When no layer is supplied:

```qml
ContextMenu.open(
    myMenu
)
```

the menu opens in:

```qml
WlrLayer.Overlay
```

which is the default behavior.

## Explicit layer

Example:

```qml
ContextMenu.open(
    myMenu,
    WlrLayer.Top
)
```

Another example:

```qml
ContextMenu.open(
    myMenu,
    WlrLayer.Bottom
)
```

The Context Menu maintains a single menu-sized `PanelWindow` parked at the computed menu origin. It is never fullscreen, so it can never block underlying input: hover, clicks, scrolls and drags outside the menus pass through to whatever is below.

Outside clicks never reach the shell (the window owns only menu pixels), so dismissal comes from: item activation, gap clicks inside the window, `Escape`, clicks on shell surfaces that snoop-and-release (e.g. WidgetLayer empty area), Hyprland `activewindow`-follow (focus moving to a client window closes the menu), or opening another menu (replaces content in place). Clicks landing on client-app windows are invisible to the shell, so the menu persists while you work below until one of the above dismisses it.

The host layer is bound per `open()` call, so the menu surface lands on the requested layer without extra surfaces.

---

# 6. Checking menu state

The singleton exposes:

```qml
ContextMenu.isOpen
```

and:

```qml
ContextMenu.menuOpen
```

Both represent the current menu-open state.

Example:

```qml
visible:
    ContextMenu.isOpen
```

You can also use the state in logic:

```qml
if (
    ContextMenu.menuOpen
) {
    console.log(
        "Context menu is open"
    )
}
```

---

# 7. Creating menu items

The basic menu-item type is:

```qml
ContextMenuObj
```

Example:

```qml
Column {
    ContextMenuObj {
        text: "Open"
    }

    ContextMenuObj {
        text: "Rename"
    }

    ContextMenuObj {
        text: "Delete"
    }
}
```

Each object automatically becomes part of the currently loaded menu tree.

The Context Menu discovers these objects after the component is loaded.

---

# 8. `ContextMenuObj` properties

## `text`

The label displayed in the menu item.

```qml
ContextMenuObj {
    text: "Open"
}
```

Default:

```text
""
```

---

## `enabled`

Controls whether the menu item can be activated.

```qml
ContextMenuObj {
    text: "Delete"

    enabled:
        false
}
```

Default:

```text
true
```

Disabled objects use their disabled text color and do not activate their action.

---

## `functionAction`

JavaScript function executed when the item is activated.

```qml
ContextMenuObj {
    text: "Refresh"

    functionAction:
        function() {
            console.log(
                "Refreshing..."
            )
        }
}
```

The function is only executed when the item is enabled.

The implementation verifies that the value is actually a function.

For example:

```qml
functionAction:
    function() {
        doSomething()
    }
```

is valid.

A non-function value produces a warning.

---

# 9. Using `Process`

A menu item can also start a Quickshell `Process`.

Import:

```qml
import Quickshell.Io
```

Example:

```qml
ContextMenuObj {
    text: "Open Terminal"

    process:
        Process {
            command: [
                "kitty"
            ]
        }
}
```

When the object activates, the process is started if it is not already running.

The menu item does not automatically construct the process itself.

The caller supplies the `Process` object.

---

# 10. Combining `functionAction` and `Process`

An object may define both:

```qml
functionAction
```

and:

```qml
process
```

Example:

```qml
ContextMenuObj {
    text: "Launch"

    functionAction:
        function() {
            console.log(
                "Launching..."
            )
        }

    process:
        Process {
            command: [
                "kitty"
            ]
        }
}
```

When activated:

1. `functionAction` is executed.
2. The configured process is started if it is not already running.
3. If `closeOnClick` is enabled, the menu closes.

---

# 11. `closeOnClick`

Controls whether the entire context menu closes after a normal item activation.

```qml
ContextMenuObj {
    text: "Refresh"

    closeOnClick:
        true
}
```

Default:

```text
true
```

For an action that should leave the menu open:

```qml
ContextMenuObj {
    text: "Toggle Option"

    closeOnClick:
        false

    functionAction:
        function() {
            toggleOption()
        }
}
```

This is especially useful for menus containing toggles or repeated actions.

---

# 12. Submenus

A submenu is declared through:

```qml
property Component submenu
```

Example:

```qml
ContextMenuObj {
    text: "Settings"

    submenu:
        Component {
            Column {
                ContextMenuObj {
                    text: "Display"
                }

                ContextMenuObj {
                    text: "Audio"
                }

                ContextMenuObj {
                    text: "Network"
                }
            }
        }
}
```

The parent item displays the submenu indicator.

By default:

```text

```

is used as the submenu icon.

---

# 13. Custom submenu icon

The icon can be changed through:

```qml
submenuIcon
```

Example:

```qml
ContextMenuObj {
    text: "Settings"

    submenuIcon:
        "󰅂"

    submenu:
        Component {
            Column {
                ContextMenuObj {
                    text: "Display"
                }
            }
        }
}
```

The value is rendered using the configured Nerd Font:

```text
Symbols Nerd Font
```

---

# 14. Submenu interaction

Submenus support two interaction modes.

### Hover

Hovering over an item with a submenu opens it automatically.

```text
Hover parent
     │
     ▼
submenu opens
```

### Click

Clicking the submenu parent pins its submenu open.

```text
Click parent
     │
     ▼
submenu becomes pinned
```

Clicking the same submenu parent again unpins and closes that branch.

This allows both mouse-navigation behavior and persistent submenu behavior.

---

# 15. Nested submenus

Submenus can contain objects that themselves have submenus.

Example:

```qml
Component {
    Column {

        ContextMenuObj {
            text: "Settings"

            submenu:
                Component {
                    Column {

                        ContextMenuObj {
                            text: "Display"

                            submenu:
                                Component {
                                    Column {

                                        ContextMenuObj {
                                            text: "Brightness"
                                        }

                                        ContextMenuObj {
                                            text: "Night Light"
                                        }
                                    }
                                }
                        }

                        ContextMenuObj {
                            text: "Audio"
                        }
                    }
                }
        }
    }
}
```

This produces:

```text
Settings
   └── Display
        ├── Brightness
        └── Night Light
```

The implementation supports multiple submenu levels up to:

```qml
maxDepth
```

whose default is:

```text
16
```

---

# 16. Submenu positioning

Submenus are positioned relative to their parent menu object.

The system:

1. Prefers opening to the right.
2. Checks the usable screen boundary.
3. Opens to the left when there is insufficient space.
4. Clamps the submenu to the usable region.
5. Vertically aligns the submenu with its parent item.

Example:

```text
┌───────────────┐
│ Settings    > │──────┐
│ Display      │       │
│ Audio        │       │
└───────────────┘       │
                        ▼
                 ┌────────────┐
                 │ Display    │
                 │ Audio      │
                 └────────────┘
```

When the right side is unavailable:

```text
              ┌──────────────┐
       ┌──────│ Settings    >│
       │      │ Display      │
       │      │ Audio        │
       ▼      └──────────────┘
┌────────────┐
│ Display    │
│ Audio      │
└────────────┘
```

Submenus do not slide between positions.

They are positioned while invisible and then fade in.

This prevents the visible `0,0 → target` movement that can happen when a submenu is dynamically created.

---

# 17. Submenu hover behavior

The menu tracks:

```text
parent hover
submenu hover
deeper submenu state
pinned state
```

A short close delay is used while navigating from a parent item into its submenu.

Default:

```qml
submenuCloseDelay:
    110
```

This gives the pointer enough time to travel across the parent/submenu gap without immediately destroying the submenu.

The system also tracks deeper open descendants so that a parent branch remains alive while the pointer is navigating through deeper submenu levels.

---

# 18. ContextMenuObj inline content

`ContextMenuObj` has a default property:

```qml
default property alias contentData:
    body.data
```

This means a `ContextMenuObj` can contain arbitrary instantiated QML children.

For example:

```qml
ContextMenuObj {
    text: "Volume"

    Rectangle {
        width: 100
        height: 20

        Text {
            anchors.centerIn:
                parent

            text:
                "Custom Content"
        }
    }
}
```

The child is treated as inline body content of the menu object.

This is **not** a submenu.

---

# 19. Inline content vs submenu

These are different concepts.

### Inline content

```qml
ContextMenuObj {
    text: "Volume"

    Rectangle {
        width: 100
        height: 20
    }
}
```

The `Rectangle` belongs to that menu object itself.

### Submenu

```qml
ContextMenuObj {
    text: "Volume"

    submenu:
        Component {
            Column {
                ContextMenuObj {
                    text: "50%"
                }

                ContextMenuObj {
                    text: "100%"
                }
            }
        }
}
```

The `Column` becomes a separate menu level.

Conceptually:

```text
ContextMenuObj
├── header
└── inline body
    └── arbitrary QML
```

versus:

```text
ContextMenuObj
└── submenu Component
    └── new menu level
```

---

# 20. `Component` vs actual child object

A `ContextMenuObj` can hold actual QML child objects through its default property.

For example:

```qml
ContextMenuObj {
    text: "Example"

    Rectangle {
        width: 100
        height: 20
    }
}
```

This works because the `Rectangle` is instantiated.

A raw:

```qml
Component {
    Rectangle {
        width: 100
        height: 20
    }
}
```

is different.

`Component` is a component definition. It does not automatically become visible content.

To display such a component, instantiate it through something such as:

```qml
Loader {
    sourceComponent:
        myComponent
}
```

Therefore:

```text
QML object
    → actual child content

Component
    → reusable definition
```

---

# 21. Inline content sizing

`ContextMenuObj` calculates its natural width from:

```text
header width
inline body width
```

Its natural width is based on the body's `childrenRect`.

Similarly, its natural height is based on:

```text
header height
+
inline body height
```

Example:

```qml
ContextMenuObj {
    text: "Custom"

    Rectangle {
        width: 160
        height: 40
    }
}
```

The menu system can measure the inline content and incorporate it into the object's preferred dimensions.

---

# 22. Menu sizing

The Context Menu has two different concepts:

```text
natural content size
        ↓
rendered menu size
```

The system first measures the content.

It then calculates the actual menu size using:

```qml
menuPadding
minimumWidth
maximumWidth
maximumHeight
screenMargin
```

For a normal menu:

```text
natural content width
        +
left/right menu padding
        =
outer menu width
```

The outer menu width is not fed back into natural-width measurement.

This prevents repeated `open()` calls from progressively increasing the menu width.

---

# 23. Maximum menu size

The menu is limited to:

```qml
maximumScreenFraction:
    0.80
```

This means the menu can use at most approximately:

```text
80% of the screen width
80% of the screen height
```

The actual limit is also constrained by the available compositor-free area.

---

# 24. Minimum width

The default minimum width is:

```qml
minimumWidth:
    180
```

The menu will not normally become narrower than that unless the usable screen width itself is smaller than the requested minimum.

Example:

```text
small content

┌───────────────────────┐
│ Open                  │
│ Rename                │
└───────────────────────┘

minimumWidth = 180
```

---

# 25. Screen margin

The menu keeps a default:

```qml
screenMargin:
    10
```

pixel margin from the usable screen boundary.

For example:

```text
screen edge
│
│ 10px
│
┌──────────────┐
│ Context Menu │
└──────────────┘
```

This applies after compositor-reserved space has been accounted for.

---

# 26. Compositor-reserved space

The menu does not reserve screen space itself.

It uses:

```qml
ExclusionMode.Ignore
```

and instead reads monitor reservation information from Hyprland.

Reserved space is used for menu positioning.

For example, if the shell reserves:

```text
top = 40
```

then the context menu's usable area begins below that region.

Conceptually:

```text
┌──────────────────────────────┐
│       reserved shell         │
├──────────────────────────────┤
│                              │
│       usable area            │
│                              │
└──────────────────────────────┘
```

This prevents the menu from intentionally positioning itself underneath exclusive shell regions.

---

# 27. Automatic edge flipping

The root menu initially attempts to open at the cursor.

The computed screen position flips to the left of the cursor when there is not enough room to the right, and upward when there is not enough room below. The result is then clamped to the usable area (compositor-reserved space + screen margin).

That final position parks the tight host window; the root level always sits at the host origin.

```text
cursor
   ▼
┌───────────────┐
│ menu          │
└───────────────┘
```

Submenu side choice (prefer right, fall back left, clamp vertically) runs in host coordinates against the same usable-area bounds, and the tight host grows to fit the resulting union.

---

# 28. Scrolling

When menu content exceeds the maximum available height, the menu becomes scrollable.

The content is displayed inside a vertical `Flickable`.

The menu does not display a scrollbar when content fits.

When content overflows:

```text
┌────────────────────┐
│ Item 1             │
│ Item 2             │
│ Item 3             │
│ Item 4             │
│ Item 5             │
│ Item 6          █  │
│ Item 7          █  │
│                 ▓  │
└────────────────────┘
```

The menu supports vertical scrolling with the mouse wheel.

---

# 29. Scrollbar

An overflowed menu reserves dedicated horizontal space for its scrollbar.

The scrollbar consists of:

```text
track
handle
```

The handle size represents the visible portion of the content.

Conceptually:

```text
content:
████████████████████████████
████████████████████████████
████████████████

viewport:
████████████

scrollbar:
████       ← handle
████
```

The scrollbar can be dragged with the mouse.

Dragging updates the menu's scroll position directly.

---

# 30. Scrollbar width reservation

Scrollbar space is defined by:

```qml
scrollbarWidth:
    5

scrollbarGap:
    7
```

Together:

```qml
scrollbarReservation:
    scrollbarWidth +
    scrollbarGap
```

The content viewport reserves this space so that the scrollbar does not overlap menu objects.

When no overflow exists, this space is not required.

---

# 31. Overflow fade

Overflowing menus also display a fade at the visible edges.

There is a top fade when content exists above the current scroll position.

There is a bottom fade when more content exists below the current scroll position.

Conceptually:

```text
┌──────────────────────┐
│      fade            │
│ Item 8               │
│ Item 9               │
│ Item 10              │
│ Item 11              │
│ Item 12              │
│      fade            │
└──────────────────────┘
```

This visually indicates that additional content exists outside the viewport.

---

# 32. Overflow fade configuration

The fade has two independent controls.

## Height

```qml
overflowFadeHeight:
    30
```

Controls how far the fade extends into the menu.

Larger value:

```text
larger fade region
```

Smaller value:

```text
smaller fade region
```

## Intensity

```qml
overflowFadeIntensity:
    0.90
```

Controls the opacity/intensity of the fade.

Range:

```text
0.0 = invisible
1.0 = fully opaque
```

Example:

```qml
overflowFadeIntensity:
    0.50
```

for a subtle fade.

Or:

```qml
overflowFadeIntensity:
    1.0
```

for a strong fade.

---

# 33. Theme colors

All menu-level colors are exposed as properties on the internal menu controller.

The current defaults are:

```qml
property color windowColor:
    "transparent"

property color menuBackgroundColor:
    "#090d12"

property color menuBorderColor:
    "#263541"

property color scrollbarTrackColor:
    "#26354155"

property color scrollbarHandleColor:
    "#2acfffcc"

property color overflowFadeColor:
    menuBackgroundColor
```

The intention is that these values can later be replaced by the N0ctOS theme system.

The overflow fade derives transparent/opaque variants from:

```qml
overflowFadeColor
```

and:

```qml
overflowFadeIntensity
```

---

# 34. `ContextMenuObj` theme colors

`ContextMenuObj` has its own visual properties.

```qml
property color normalTextColor:
    "#e8edf0"

property color disabledTextColor:
    "#4b5963"

property color hoverBackground:
    "#1a3039"

property color hoverTextColor:
    "#2acfff"

property color backgroundColor:
    "transparent"
```

These control the item itself.

For example:

```qml
ContextMenuObj {
    text:
        "Open"

    normalTextColor:
        "#ffffff"

    hoverTextColor:
        "#2acfff"
}
```

---

# 35. Menu object dimensions

The current default row height is:

```qml
headerHeight:
    36
```

Horizontal item padding:

```qml
horizontalPadding:
    10
```

Text/submenu spacing:

```qml
spacing:
    8
```

These affect the natural width and height of a `ContextMenuObj`.

---

# 36. Menu object appearance

`ContextMenuObj` currently uses:

```text
rounded corners
no border
transparent normal background
hover background
hover text color
```

The corner radius is:

```qml
topLeft: 7
topRight: 7
bottomRight: 7
bottomLeft: 7
```

The visual implementation is based on `CutBox`.

---

# 37. Menu object actions

The activation sequence for a normal object is conceptually:

```text
click
  │
  ├── disabled?
  │      └── stop
  │
  ├── submenu?
  │      └── pin/unpin submenu
  │
  └── normal item
         │
         ├── functionAction
         ├── Process
         └── closeOnClick
```

This means submenu parents do not behave like ordinary action items when clicked.

Clicking them controls the submenu state instead.

---

# 38. Hover handling

Each `ContextMenuObj` reports hover state to its bound context-menu controller.

The controller receives:

```text
objectHovered
objectExited
objectClicked
```

The object itself therefore does not need to know how the entire submenu tree works.

This keeps the menu-item component reusable.

---

# 39. Context menu tree binding

When content is loaded, `ContextMenu` walks the QML object tree.

For every object exposing:

```qml
contextMenuInstance
```

it assigns:

```qml
contextMenuInstance
contextMenuDepth
parentMenuObject
```

This allows `ContextMenuObj` instances to communicate with the singleton.

The result is:

```text
ContextMenu
     │
     ▼
menu tree
     │
     ├── ContextMenuObj
     ├── ContextMenuObj
     │      └── submenu
     │
     └── ContextMenuObj
```

The caller does not have to manually wire these properties.

---

# 40. Creating reusable menu components

A good pattern is to define the menu in a `Component`.

Example:

```qml
Component {
    id: fileMenu

    Column {
        ContextMenuObj {
            text: "Open"

            functionAction:
                function() {
                    openFile()
                }
        }

        ContextMenuObj {
            text: "Rename"

            functionAction:
                function() {
                    renameFile()
                }
        }

        ContextMenuObj {
            text: "Delete"

            functionAction:
                function() {
                    deleteFile()
                }
        }
    }
}
```

Then:

```qml
ContextMenu.open(
    fileMenu
)
```

This makes the menu definition reusable.

---

# 41. Example: basic context menu

```qml
import QtQuick
import Quickshell.Io

import qs.core.lib
import qs.core.ui

Component {
    id: contextMenu

    Column {

        ContextMenuObj {
            text:
                "Open"

            functionAction:
                function() {
                    console.log(
                        "Open"
                    )
                }
        }

        ContextMenuObj {
            text:
                "Refresh"

            functionAction:
                function() {
                    console.log(
                        "Refresh"
                    )
                }
        }

        ContextMenuObj {
            text:
                "Exit"

            functionAction:
                function() {
                    console.log(
                        "Exit"
                    )
                }
        }
    }
}
```

Open it with:

```qml
ContextMenu.open(
    contextMenu
)
```

---

# 42. Example: disabled item

```qml
Component {
    id: contextMenu

    Column {

        ContextMenuObj {
            text:
                "Open"

            enabled:
                true
        }

        ContextMenuObj {
            text:
                "Paste"

            enabled:
                false
        }
    }
}
```

---

# 43. Example: process action

```qml
Component {
    id: contextMenu

    Column {

        ContextMenuObj {
            text:
                "Open Terminal"

            process:
                Process {
                    command: [
                        "kitty"
                    ]
                }
        }
    }
}
```

---

# 44. Example: function action

```qml
Component {
    id: contextMenu

    Column {

        ContextMenuObj {
            text:
                "Reload Shell"

            functionAction:
                function() {
                    console.log(
                        "Reload requested"
                    )
                }
        }
    }
}
```

---

# 45. Example: submenu

```qml
Component {
    id: contextMenu

    Column {

        ContextMenuObj {
            text:
                "Appearance"

            submenu:
                Component {
                    Column {

                        ContextMenuObj {
                            text:
                                "Dark"
                        }

                        ContextMenuObj {
                            text:
                                "Light"
                        }

                        ContextMenuObj {
                            text:
                                "System"
                        }
                    }
                }
        }
    }
}
```

---

# 46. Example: nested submenu

```qml
Component {
    id: contextMenu

    Column {

        ContextMenuObj {
            text:
                "Settings"

            submenu:
                Component {
                    Column {

                        ContextMenuObj {
                            text:
                                "Display"

                            submenu:
                                Component {
                                    Column {

                                        ContextMenuObj {
                                            text:
                                                "Brightness"
                                        }

                                        ContextMenuObj {
                                            text:
                                                "Night Light"
                                        }
                                    }
                                }
                        }

                        ContextMenuObj {
                            text:
                                "Audio"
                        }
                    }
                }
        }
    }
}
```

This produces:

```text
Settings
└── Display
    ├── Brightness
    └── Night Light
└── Audio
```

---

# 47. Example: inline custom content

Because `ContextMenuObj` has a default content property, it can contain custom QML.

Example:

```qml
Component {
    id: contextMenu

    Column {

        ContextMenuObj {
            text:
                "Status"

            Rectangle {
                width:
                    120

                height:
                    24

                radius:
                    5

                color:
                    "#14232b"

                Text {
                    anchors.centerIn:
                        parent

                    text:
                        "Connected"

                    color:
                        "#2acfff"

                    font.pixelSize:
                        11
                }
            }
        }
    }
}
```

This is inline content, not a submenu.

---

# 48. Example: custom content with a Loader

A reusable `Component` can also be instantiated as inline content through a `Loader`.

Example:

```qml
Component {
    id: statusContent

    Rectangle {
        width:
            140

        height:
            28

        color:
            "#14232b"

        Text {
            anchors.centerIn:
                parent

            text:
                "Custom Content"
        }
    }
}

Component {
    id: contextMenu

    Column {

        ContextMenuObj {
            text:
                "Status"

            Loader {
                sourceComponent:
                    statusContent
            }
        }
    }
}
```

This distinction is important:

```text
Component
    = definition

Loader
    = creates the definition as an object
```

---

# 49. Custom layer example

To open a menu on the top layer:

```qml
import Quickshell.Wayland

ContextMenu.open(
    contextMenu,
    WlrLayer.Top
)
```

To explicitly use Overlay:

```qml
ContextMenu.open(
    contextMenu,
    WlrLayer.Overlay
)
```

The latter is equivalent to:

```qml
ContextMenu.open(
    contextMenu
)
```

because Overlay is the default.

---

# 50. Outside dismissal and re-open

The menu lives in a tight menu-sized host window, so outside clicks never reach the shell at all: the compositor routes them to the underlying window.

This means an outside click lands in the app underneath — and, where the click hits a shell surface with a menu handler (another widget, the tray), it opens that menu, replacing the current one in place. Right-clicking another item therefore swaps menus instead of stranding the old one.

Clicks landing in the tiny gaps between menu levels hit a background catcher and close the menu. `Escape` also closes it. Clicks on client-app windows are invisible to the shell, so the menu stays up while you work below until item activation, a gap click, `Escape`, a shell-surface click, an `activewindow` focus change, or a fresh `open()` dismisses it.

Calling `open()` while a menu is already open is still valid: content is replaced and the host re-parks at the new cursor position. Re-open repositions instantly.

---

# 51. Closing the menu

Close it through:

```qml
ContextMenu.close()
```

Example:

```qml
ContextMenuObj {
    text:
        "Close Menu"

    functionAction:
        function() {
            ContextMenu.close()
        }
}
```

Closing hides all active menu levels and resets the submenu state.

After the close animation finishes, the loaded components are cleared.

---

# 52. Menu lifecycle

A simplified lifecycle looks like:

```text
ContextMenu.open(component)
          │
          ▼
request generation++
          │
          ▼
capture cursor
          │
          ▼
query monitors
          │
          ▼
find monitor
          │
          ▼
find Quickshell screen
          │
          ▼
read reservations
          │
          ▼
load Component
          │
          ▼
measure content
          │
          ▼
calculate final size
          │
          ▼
position root
          │
          ▼
show menu
```

For a submenu:

```text
ContextMenuObj.hover
        │
        ▼
open submenu Component
        │
        ▼
measure submenu
        │
        ▼
position submenu
        │
        ▼
fade in
```

---

# 53. Menu query generation

Every call to:

```qml
ContextMenu.open(...)
```

increments an internal request generation.

This prevents stale asynchronous `hyprctl` results from an earlier request from overriding a newer open request.

The cursor and monitor queries are associated with the current generation.

This matters particularly when the user rapidly reopens or recalls a menu.

---

# 54. Multi-monitor support

The menu obtains the cursor position through:

```text
hyprctl -j cursorpos
```

and monitor information through:

```text
hyprctl -j monitors
```

These live behind the `cursorBackend` provider seam (`"hyprland"` for now). Future backends (niri, kde, ...) slot into `queryCursorAndMonitors()` without touching the open/resolve flow.

The current cursor is matched against the monitor geometry.

The corresponding Quickshell `ShellScreen` is then selected.

The menu therefore does not require callers to identify the monitor manually.

---

# 55. Coordinate conversion

Hyprland monitor geometry and Quickshell screen dimensions may differ when output scaling is involved.

The menu therefore computes:

```qml
scaleX
scaleY
```

and converts the Hyprland global cursor position into the target screen's local coordinates.

This allows positioning to remain correct under scaled outputs.

---

# 56. Scrolling geometry

When content overflows vertically:

```text
natural height
       │
       ▼
maximum height exceeded
       │
       ├── menu gets capped
       │
       ├── Flickable becomes scrollable
       │
       ├── scrollbar space is reserved
       │
       └── overflow fades appear
```

The actual visible content viewport is narrower when the scrollbar is active.

This prevents menu objects from being rendered underneath the scrollbar.

---

# 57. Menu width and object width

The Context Menu distinguishes between:

```text
outer menu width
```

and:

```text
ContextMenuObj content width
```

For example:

```text
┌─────────────────────────────────┐
│ outer menu                      │
│  ┌───────────────────────────┐  │
│  │ ContextMenuObj            │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

The `ContextMenuObj` receives the width available inside the menu's padded content area.

This prevents the object from extending underneath the outer menu padding or scrollbar.

---

# 58. Stable repeated opening

The menu's natural measurement deliberately avoids using a previously assigned rendered `ContextMenuObj.width` as its natural width.

This is important because menu rows receive their rendered width after measurement.

Without this separation, the following feedback loop could occur:

```text
rendered width
    ↓
measured width
    ↓
larger rendered width
    ↓
measured width again
    ↓
even larger width
```

The current implementation instead uses:

```text
intrinsic/preferred width
        ↓
menu geometry
        ↓
rendered width
```

This keeps repeated recalls stable.

---

# 59. Configuration reference

## Context Menu

| Property                    | Default | Purpose                                 |
| --------------------------- | ------: | --------------------------------------- |
| `screenMargin`              |    `10` | Margin from usable screen boundaries    |
| `maximumScreenFraction`     |  `0.80` | Maximum width/height fraction of screen |
| `minimumWidth`              |   `180` | Minimum menu width                      |
| `menuPadding`               |     `4` | Outer menu padding                      |
| `scrollbarWidth`            |     `5` | Scrollbar width                         |
| `scrollbarGap`              |     `7` | Space between content and scrollbar     |
| `scrollbarMargin`           |     `4` | Scrollbar margin                        |
| `scrollbarMinHandleHeight`  |    `24` | Minimum scrollbar handle size           |
| `overflowFadeHeight`        |    `30` | Fade height                             |
| `overflowFadeIntensity`     |  `0.90` | Fade strength                           |
| `animationDuration`         |   `180` | General animation duration              |
| `positionAnimationDuration` |   `180` | Root menu movement duration             |
| `submenuCloseDelay`         |   `110` | Submenu close delay                     |
| `maxDepth`                  |    `16` | Maximum submenu depth                   |
| `submenuGap`                |     `3` | Parent/submenu gap                      |
| `borderWidth`               |     `1` | Menu border width                       |
| `radius`                    |     `8` | Menu corner radius                      |

---

# 60. Context Menu colors

| Property               | Default               | Purpose                 |
| ---------------------- | --------------------- | ----------------------- |
| `windowColor`          | `transparent`         | Tight host background |
| `menuBackgroundColor`  | `#090d12`             | Menu background         |
| `menuBorderColor`      | `#263541`             | Menu border             |
| `scrollbarTrackColor`  | `#26354155`           | Scrollbar track         |
| `scrollbarHandleColor` | `#2acfffcc`           | Scrollbar handle        |
| `overflowFadeColor`    | `menuBackgroundColor` | Fade source color       |

The fade strength is controlled independently through:

```qml
overflowFadeIntensity
```

---

# 61. ContextMenuObj configuration

| Property            | Default | Purpose                     |
| ------------------- | ------: | --------------------------- |
| `text`              |    `""` | Item text                   |
| `enabled`           |  `true` | Whether item is active      |
| `submenu`           |  `null` | Optional submenu Component  |
| `closeOnClick`      |  `true` | Close menu after activation |
| `submenuIcon`       |     `` | Submenu indicator           |
| `headerHeight`      |    `36` | Item height                 |
| `horizontalPadding` |    `10` | Horizontal text padding     |
| `spacing`           |     `8` | Text/indicator spacing      |
| `animationDuration` |   `140` | Item animation duration     |

---

# 62. ContextMenuObj colors

| Property            | Default       | Purpose           |
| ------------------- | ------------- | ----------------- |
| `normalTextColor`   | `#e8edf0`     | Normal text       |
| `disabledTextColor` | `#4b5963`     | Disabled text     |
| `hoverBackground`   | `#1a3039`     | Hover background  |
| `hoverTextColor`    | `#2acfff`     | Hover text        |
| `backgroundColor`   | `transparent` | Normal background |

---

# 63. Useful public functions

The singleton exposes:

```qml
ContextMenu.open(
    component
)
```

```qml
ContextMenu.open(
    component,
    layer
)
```

```qml
ContextMenu.close()
```

```qml
ContextMenu.notifyHovered(
    object
)
```

```qml
ContextMenu.notifyExited(
    object
)
```

```qml
ContextMenu.notifyClicked(
    object
)
```

```qml
ContextMenu.isSubmenuVisibleFor(
    object
)
```

The `notify*` functions are primarily used internally by `ContextMenuObj`.

Most consumers only need:

```qml
ContextMenu.open(...)
ContextMenu.close()
```

---

# 64. Typical integration

A widget or application can define its menu locally.

Example:

```qml
Component {
    id: widgetContextMenu

    Column {

        ContextMenuObj {
            text:
                "Open"

            functionAction:
                function() {
                    openApplication()
                }
        }

        ContextMenuObj {
            text:
                "Settings"

            submenu:
                Component {
                    Column {

                        ContextMenuObj {
                            text:
                                "Configure"
                        }

                        ContextMenuObj {
                            text:
                                "Reset"
                        }
                    }
                }
        }

        ContextMenuObj {
            text:
                "Remove"

            functionAction:
                function() {
                    removeWidget()
                }
        }
    }
}
```

Then:

```qml
ContextMenu.open(
    widgetContextMenu
)
```

---

# 65. Recommended menu organization

For simple menus:

```qml
Component {
    Column {
        ContextMenuObj { ... }
        ContextMenuObj { ... }
        ContextMenuObj { ... }
    }
}
```

For nested menus:

```qml
Component {
    Column {

        ContextMenuObj {
            submenu:
                Component {
                    Column {
                        ContextMenuObj { ... }
                        ContextMenuObj { ... }
                    }
                }
        }
    }
}
```

For custom item content:

```qml
ContextMenuObj {
    text:
        "Custom"

    Rectangle {
        ...
    }
}
```

Keep submenu components separate from inline item content.

---

# 66. Common mistakes

## Passing an object instead of a Component

Wrong:

```qml
Column {
    ContextMenuObj {
        ...
    }
}

ContextMenu.open(
    someColumn
)
```

The public API expects a `Component`.

Correct:

```qml
Component {
    id: someMenu

    Column {
        ContextMenuObj {
            ...
        }
    }
}

ContextMenu.open(
    someMenu
)
```

---

## Treating a submenu as inline content

Wrong:

```qml
ContextMenuObj {
    text:
        "Settings"

    ContextMenuObj {
        text:
            "Display"
    }
}
```

That creates inline child content, not a submenu.

Correct:

```qml
ContextMenuObj {
    text:
        "Settings"

    submenu:
        Component {
            Column {
                ContextMenuObj {
                    text:
                        "Display"
                }
            }
        }
}
```

---

## Putting a raw `Component` in inline content

A raw:

```qml
Component {
    Rectangle {
        ...
    }
}
```

is only a component definition.

Use a `Loader` when you want to instantiate that definition as inline content.

---

## Reusing `menuWidth` as natural width

`menuWidth` is the rendered width assigned by the Context Menu.

It should not be used to calculate natural width.

The system deliberately separates:

```text
naturalWidth
preferredWidth
menuWidth
```

to prevent measurement feedback loops.

---

## Manually positioning the menu

Do not calculate the menu's screen position in your widget.

The Context Menu determines:

```text
cursor
monitor
screen
reserved space
edge flipping
final position
```

automatically.

---

## Manually implementing submenu positioning

Do not manually assign submenu `x`/`y`.

The context-menu controller handles:

```text
parent mapping
right-side placement
left-side fallback
screen clamping
```

---

# 67. Example: complete menu

The following is a more complete example combining normal actions, a process, disabled state, inline content, and nested submenus.

```qml
import QtQuick
import Quickshell.Io

import qs.core.lib
import qs.core.ui

Component {
    id: completeMenu

    Column {

        // ========================================================
        // NORMAL ACTION
        // ========================================================

        ContextMenuObj {
            text:
                "Open"

            functionAction:
                function() {
                    console.log(
                        "Open"
                    )
                }
        }

        // ========================================================
        // PROCESS
        // ========================================================

        ContextMenuObj {
            text:
                "Open Terminal"

            process:
                Process {
                    command: [
                        "kitty"
                    ]
                }
        }

        // ========================================================
        // SUBMENU
        // ========================================================

        ContextMenuObj {
            text:
                "Appearance"

            submenu:
                Component {
                    Column {

                        ContextMenuObj {
                            text:
                                "Theme"

                            submenu:
                                Component {
                                    Column {

                                        ContextMenuObj {
                                            text:
                                                "Dark"
                                        }

                                        ContextMenuObj {
                                            text:
                                                "Light"
                                        }
                                    }
                                }
                        }

                        ContextMenuObj {
                            text:
                                "Wallpaper"

                            submenu:
                                Component {
                                    Column {

                                        ContextMenuObj {
                                            text:
                                                "Next"
                                        }

                                        ContextMenuObj {
                                            text:
                                                "Previous"
                                        }
                                    }
                                }
                        }
                    }
                }
        }

        // ========================================================
        // DISABLED
        // ========================================================

        ContextMenuObj {
            text:
                "Unavailable"

            enabled:
                false
        }

        // ========================================================
        // INLINE CUSTOM CONTENT
        // ========================================================

        ContextMenuObj {
            text:
                "Status"

            Rectangle {
                width:
                    120

                height:
                    24

                radius:
                    5

                color:
                    "#14232b"

                Text {
                    anchors.centerIn:
                        parent

                    text:
                        "Connected"

                    color:
                        "#2acfff"

                    font.pixelSize:
                        11
                }
            }
        }
    }
}
```

Open it:

```qml
ContextMenu.open(
    completeMenu
)
```

---

# 68. Example: using a specific layer

```qml
import Quickshell.Wayland

ContextMenu.open(
    completeMenu,
    WlrLayer.Top
)
```

Or simply:

```qml
ContextMenu.open(
    completeMenu
)
```

for the default Overlay layer.

---

# 69. Design philosophy

The context menu system intentionally separates responsibilities.

### `ContextMenu.qml`

Responsible for:

```text
tight host management
activewindow-follow dismissal
per-open layer assignment
cursor lookup
monitor lookup
screen selection
reserved space
positioning
sizing
scrolling
scrollbar
overflow fades
submenu state
submenu lifetime
menu loading
tree binding
```

### `ContextMenuObj.qml`

Responsible for:

```text
item appearance
item text
enabled state
item actions
process launching
submenu declaration
inline content
hover state
click notification
```

This keeps individual menu items simple while allowing the global controller to manage the entire menu tree.

---

# 70. Minimal template

The smallest useful context menu is:

```qml
Component {
    id: menu

    Column {

        ContextMenuObj {
            text:
                "Open"
        }

        ContextMenuObj {
            text:
                "Delete"
        }
    }
}
```

Then:

```qml
ContextMenu.open(
    menu
)
```

---

# 71. Minimal submenu template

```qml
ContextMenuObj {
    text:
        "More"

    submenu:
        Component {
            Column {

                ContextMenuObj {
                    text:
                        "Option 1"
                }

                ContextMenuObj {
                    text:
                        "Option 2"
                }
            }
        }
}
```

---

# 72. Final model

Think of the API as:

```text
ContextMenu.open(
    COMPONENT,
    OPTIONAL WLR LAYER
)
```

where the component contains:

```text
Column
├── ContextMenuObj
├── ContextMenuObj
│   └── submenu: Component
│       └── Column
│           ├── ContextMenuObj
│           └── ContextMenuObj
└── ContextMenuObj
```

The caller provides the **menu content**.

The Context Menu handles everything around it:

```text
cursor
monitor
screen
position
size
reserved space
scrolling
submenu behavior
layer
animation
```

The central rule is:

> **Define the menu. The Context Menu handles the rest.**
