# N0ctOS Wallpaper Transitions

This directory contains custom wallpaper transition plugins for N0ctOS.

A transition controls **how the current wallpaper becomes the next wallpaper**.

N0ctOS supports two transition types:

* **QML transitions** — normal Qt Quick effects such as fade, zoom, slide, rotate, etc.
* **Shader transitions** — GPU effects such as glitch, RGB split, distortion, pixelation, noise, CRT effects, etc.

The transition system handles wallpaper loading, transition timing, plugin discovery, error recovery, and final wallpaper handoff.

A plugin only needs to implement the **visual effect**.

---

# 1. How the system works

When a wallpaper changes:

```text
Current Wallpaper
       │
       │ stays alive
       ▼
┌─────────────────────────────┐
│       TransitionHost        │
│                             │
│  old WallpaperLayer         │
│  new WallpaperLayer         │
│                             │
│  transition plugin          │
└─────────────────────────────┘
              │
              ▼
          animation
              │
              ▼
       new wallpaper
```

The transition receives:

```qml
oldItem
newItem
progress
duration
parameters
```

`progress` goes from:

```text
0.0 ───────────────────── 1.0
OLD                      NEW
```

The host controls when the transition starts and when it is destroyed.

Do **not** manually switch wallpapers from a transition plugin.

---

# 2. Plugin structure

Every transition is a directory containing:

```text
transition-name/
├── manifest.json
└── Transition.qml
```

A shader transition usually has:

```text
transition-name/
├── manifest.json
├── Transition.qml
├── effect.frag
└── effect.frag.qsb
```

The registry discovers plugins automatically.

You do **not** manually register a plugin.

---

# 3. `manifest.json`

Every plugin requires a manifest.

Minimal example:

```json
{
    "id": "fade",
    "name": "Fade",
    "author": "N0ctOS",
    "version": "1.0.0",
    "type": "qml",
    "path": "Fade.qml"
}
```

## Required fields

### `id`

Unique machine-readable ID.

Use lowercase kebab-case:

```text
fade
zoom
channel-split
crt-glitch
pixel-dissolve
```

Do not use duplicate IDs.

### `name`

Human-readable name:

```json
"name": "Channel Split"
```

### `author`

```json
"author": "Your Name"
```

### `version`

```json
"version": "1.0.0"
```

### `type`

Use exactly one of:

```text
qml
shader
```

QML:

```json
"type": "qml"
```

Shader:

```json
"type": "shader"
```

### `path`

Path to the transition QML component, relative to the plugin directory:

```json
"path": "Fade.qml"
```

Do not use:

```json
"path": "/Fade.qml"
```

---

# 4. Optional manifest fields

You may add:

```json
{
    "id": "zoom",
    "name": "Zoom",
    "author": "N0ctOS",
    "version": "1.0.0",
    "type": "qml",
    "path": "Zoom.qml",
    "description": "Zooming wallpaper transition",
    "icon": "icon.svg",
    "parameters": {
        "amount": 0.12
    }
}
```

Parameters are available in the plugin through:

```qml
root.parameters
```

or, preferably:

```qml
root.param("amount", 0.12)
```

The second argument is the fallback value.

---

# 5. The `Transition` base component

Every plugin must inherit:

```qml
import QtQuick
import qs.wallpaper.components

Transition {
    id: root
}
```

The base component provides:

```qml
root.oldItem
root.newItem
root.progress
root.duration
root.parameters
```

and:

```qml
root.start()
root.finish()
root.complete()
root.abort()
root.fail()
```

It also provides:

```qml
root.param(name, fallback)
root.clamp(value, min, max)
root.setProperty(item, property, value)
root.setFinalState()
```

---

# 6. Transition lifecycle

You normally only implement the visual effect.

The lifecycle is:

```text
Transition created
       │
       ▼
prepare()
       │
       ▼
start()
       │
       ▼
progress: 0 → 1
       │
       ▼
finish()
       │
       ▼
TransitionHost promotes new wallpaper
       │
       ▼
complete()
       │
       ▼
destroyed
```

### Important

`finish()` does **not** mean the transition object is destroyed.

It only means the animation reached `progress == 1`.

`TransitionHost` must first make the incoming wallpaper active.

Only then is `complete()` called.

This is important for shader transitions.

---

# 7. QML transitions

QML transitions manipulate normal Qt Quick properties on:

```qml
root.oldItem
root.newItem
```

Common properties include:

```qml
opacity
scale
rotation
x
y
width
height
```

## IMPORTANT: do not use persistent `Binding`s for animation

Do **not** write transitions like:

```qml
Binding {
    target: root.newItem
    property: "opacity"
    value: root.progress
    when: root.running
}
```

This can cause the binding to be removed at the end of the transition and restore an old property state.

That can leave the final wallpaper invisible or otherwise incorrectly configured.

### Instead, directly assign the properties.

Use:

```qml
onProgressChanged: {
    if (!root.running)
        return

    if (root.oldItem)
        root.oldItem.opacity =
            1.0 - root.progress

    if (root.newItem)
        root.newItem.opacity =
            root.progress
}
```

This leaves the final value in place.

---

# 8. QML Fade example

## `manifest.json`

```json
{
    "id": "fade",
    "name": "Fade",
    "author": "N0ctOS",
    "version": "1.0.0",
    "type": "qml",
    "path": "Fade.qml"
}
```

## `Fade.qml`

```qml
import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "qml"

    function prepare() {
        if (root.oldItem)
            root.oldItem.opacity = 1

        if (root.newItem)
            root.newItem.opacity = 0
    }

    onProgressChanged: {
        if (!root.running)
            return

        if (root.oldItem)
            root.oldItem.opacity =
                1.0 - root.progress

        if (root.newItem)
            root.newItem.opacity =
                root.progress
    }
}
```

At the beginning:

```text
progress = 0
old opacity = 1
new opacity = 0
```

At the end:

```text
progress = 1
old opacity = 0
new opacity = 1
```

---

# 9. QML Zoom example

```qml
import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "qml"

    property real amount:
        Number(
            root.param(
                "amount",
                0.12
            )
        )

    function prepare() {
        if (root.oldItem) {
            root.oldItem.opacity = 1
            root.oldItem.scale = 1
        }

        if (root.newItem) {
            root.newItem.opacity = 0
            root.newItem.scale =
                1.0 + root.amount
        }
    }

    onProgressChanged: {
        if (!root.running)
            return

        if (root.oldItem) {
            root.oldItem.opacity =
                1.0 - root.progress

            root.oldItem.scale =
                1.0 +
                root.progress *
                root.amount
        }

        if (root.newItem) {
            root.newItem.opacity =
                root.progress

            root.newItem.scale =
                1.0 +
                (1.0 - root.progress) *
                root.amount
        }
    }
}
```

Manifest:

```json
{
    "id": "zoom",
    "name": "Zoom",
    "author": "N0ctOS",
    "version": "1.0.0",
    "type": "qml",
    "path": "Zoom.qml",
    "parameters": {
        "amount": 0.12
    }
}
```

---

# 10. QML final state

For simple transitions, it is good practice to explicitly put the incoming wallpaper into a valid final state.

For example:

```qml
function finishState() {
    if (root.oldItem)
        root.oldItem.opacity = 0

    if (root.newItem) {
        root.newItem.opacity = 1
        root.newItem.scale = 1
        root.newItem.rotation = 0
    }
}
```

The base `Transition` also provides:

```qml
root.setFinalState()
```

which resets the standard properties:

```text
old opacity = 0
old scale = 1
old rotation = 0
old x = 0
old y = 0

new opacity = 1
new scale = 1
new rotation = 0
new x = 0
new y = 0
```

---

# 11. Shader transitions

Shader transitions render both wallpapers through `ShaderEffectSource` and then combine them using `ShaderEffect`.

Conceptually:

```text
old WallpaperLayer ──► old texture ──┐
                                     │
                                     ▼
                                ShaderEffect
                                     ▲
                                     │
new WallpaperLayer ──► new texture ──┘
```

A shader transition is useful for:

```text
glitch
RGB/channel split
pixelation
distortion
wave
noise dissolve
CRT
scanlines
chromatic aberration
digital corruption
```

---

# 12. Supported shader type

The current transition system uses **fragment shaders** with Qt 6 `ShaderEffect`.

Runtime shader files should be:

```text
.qsb
```

The normal development flow is:

```text
effect.frag
     │
     ▼
    qsb
     │
     ▼
effect.frag.qsb
     │
     ▼
ShaderEffect
```

Do not load raw `.frag` files at runtime.

---

# 13. Shader plugin structure

Example:

```text
channel-split/
├── manifest.json
├── ChannelSplit.qml
├── channel_split.frag
└── channel_split.frag.qsb
```

The `.frag` file is the editable source.

The `.qsb` file is the runtime shader.

---

# 14. Shader QML wrapper

A basic shader transition looks like:

```qml
import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "shader"

    ShaderEffectSource {
        id: oldSource

        anchors.fill: parent

        sourceItem:
            root.oldItem

        live: true
        recursive: true

        visible: false
    }

    ShaderEffectSource {
        id: newSource

        anchors.fill: parent

        sourceItem:
            root.newItem

        live: true
        recursive: true

        visible: false
    }

    ShaderEffect {
        anchors.fill: parent

        visible:
            root.running

        property var fromTexture:
            oldSource

        property var toTexture:
            newSource

        property real progress:
            root.progress

        fragmentShader:
            Qt.resolvedUrl(
                "effect.frag.qsb"
            )
    }
}
```

The main shader inputs are:

```qml
fromTexture
toTexture
progress
```

---

# 15. Do not hide source wallpapers

Do **not** use:

```qml
hideSource: true
```

for these transition sources.

The transition host controls the wallpaper layers.

The plugin should only sample them.

Correct:

```qml
ShaderEffectSource {
    sourceItem: root.oldItem
    live: true
    recursive: true
}
```

and:

```qml
ShaderEffectSource {
    sourceItem: root.newItem
    live: true
    recursive: true
}
```

---

# 16. Shader example: Channel Split

A fragment shader receives:

```text
fromTexture
toTexture
progress
```

Example:

```glsl
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float intensity;
};

layout(binding = 1) uniform sampler2D fromTexture;
layout(binding = 2) uniform sampler2D toTexture;

void main()
{
    vec2 uv =
        qt_TexCoord0;

    float p =
        clamp(
            progress,
            0.0,
            1.0
        );

    float offset =
        intensity *
        (1.0 - p) *
        (1.0 - p);

    float red =
        texture(
            fromTexture,
            uv + vec2(offset, 0.0)
        ).r;

    float green =
        texture(
            fromTexture,
            uv
        ).g;

    float blue =
        texture(
            fromTexture,
            uv - vec2(offset, 0.0)
        ).b;

    vec3 oldColor =
        vec3(
            red,
            green,
            blue
        );

    vec3 newColor =
        texture(
            toTexture,
            uv
        ).rgb;

    vec3 result =
        mix(
            oldColor,
            newColor,
            smoothstep(
                0.0,
                1.0,
                p
            )
        );

    fragColor =
        vec4(
            result,
            1.0
        ) *
        qt_Opacity;
}
```

The important rule is:

```text
progress = 0
    → mostly old wallpaper

progress = 1
    → new wallpaper
```

---

# 17. Shader wrapper with parameters

```qml
import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "shader"

    property real intensity:
        Number(
            root.param(
                "intensity",
                0.018
            )
        )

    ShaderEffectSource {
        id: oldSource

        anchors.fill: parent

        sourceItem:
            root.oldItem

        live: true
        recursive: true

        visible: false
    }

    ShaderEffectSource {
        id: newSource

        anchors.fill: parent

        sourceItem:
            root.newItem

        live: true
        recursive: true

        visible: false
    }

    ShaderEffect {
        anchors.fill: parent

        visible:
            root.running

        property var fromTexture:
            oldSource

        property var toTexture:
            newSource

        property real progress:
            root.progress

        property real intensity:
            root.intensity

        fragmentShader:
            Qt.resolvedUrl(
                "channel_split.frag.qsb"
            )

        onStatusChanged: {
            if (
                status ===
                ShaderEffect.Error
            ) {
                root.fail(
                    "Shader error: " +
                    String(
                        log ||
                        "unknown shader error"
                    )
                )
            }
        }
    }
}
```

Manifest:

```json
{
    "id": "channel-split",
    "name": "Channel Split",
    "author": "N0ctOS",
    "version": "1.0.0",
    "type": "shader",
    "path": "ChannelSplit.qml",
    "parameters": {
        "intensity": 0.018
    }
}
```

---

# 18. Shader uniforms

The QML wrapper exposes values to the shader.

For example:

```qml
property real intensity:
    root.intensity
```

Then the shader must have a matching uniform:

```glsl
float intensity;
```

Common custom parameters:

```text
intensity
amount
distortion
noise
speed
scale
direction
```

Keep parameter names consistent between the manifest, QML wrapper, and shader.

---

# 19. `progress` is the animation clock

Do not normally create another animation timer.

Use:

```qml
root.progress
```

or shader:

```glsl
progress
```

It moves from:

```text
0.0 → 1.0
```

You can transform it:

```glsl
float p =
    smoothstep(
        0.0,
        1.0,
        progress
    );
```

or:

```glsl
float p =
    progress * progress;
```

or:

```glsl
float p =
    1.0 -
    pow(
        1.0 - progress,
        3.0
    );
```

---

# 20. Shader final-state rule

At:

```text
progress = 1.0
```

the shader must render the new wallpaper correctly.

For example:

```glsl
vec3 result =
    mix(
        oldColor,
        newColor,
        progress
    );
```

At `progress == 1`:

```text
result = newColor
```

Do not intentionally output black at the end.

The host promotes the new wallpaper immediately after the transition reports completion.

---

# 21. Compile a shader

Use Qt's `qsb` tool:

```bash
qsb \
    --qt6 \
    channel_split.frag \
    -o channel_split.frag.qsb
```

You should have:

```text
channel_split.frag
channel_split.frag.qsb
```

The QML plugin loads:

```qml
fragmentShader:
    Qt.resolvedUrl(
        "channel_split.frag.qsb"
    )
```

---

# 22. What plugins must NOT do

A transition plugin must not:

```text
modify WallpaperManager
modify wallpaper definitions
call WallpaperManager.setWallpaper()
destroy itself
destroy oldItem
destroy newItem
control plugin discovery
change TransitionHost state
```

The transition is only a visual effect.

---

# 23. Testing a transition

List installed transitions:

```bash
qs ipc call n0ctos-transition list
```

Select one:

```bash
qs ipc call n0ctos-transition set fade
```

or:

```bash
qs ipc call n0ctos-transition set glitch
```

Set duration:

```bash
qs ipc call n0ctos-transition duration 800
```

Check configuration:

```bash
qs ipc call n0ctos-transition status
```

Then change the wallpaper:

```bash
qs ipc call n0ctos-wall set \
    eDP-1 \
    /path/to/wallpaper.jpg
```

---

# 24. Debugging

If the plugin does not appear:

```bash
qs ipc call n0ctos-transition list
```

Check:

```text
manifest exists
ID is unique
type is exactly qml/shader
path is correct
QML file exists
```

If a plugin fails to load, check the Quickshell log for:

```text
[TransitionHost] transition load error:
```

The host reports the component's actual QML error.

For shader errors, `ShaderEffect` reports its error through the plugin.

---

# 25. Common mistakes

### Wrong type

Wrong:

```json
"type": "shader-effect"
```

Correct:

```json
"type": "shader"
```

### Wrong path

Wrong:

```json
"path": "/Fade.qml"
```

Correct:

```json
"path": "Fade.qml"
```

### Loading raw GLSL

Wrong:

```qml
fragmentShader:
    Qt.resolvedUrl(
        "effect.frag"
    )
```

Correct:

```qml
fragmentShader:
    Qt.resolvedUrl(
        "effect.frag.qsb"
    )
```

### Using `Binding` for QML animation

Avoid:

```qml
Binding {
    target: root.newItem
    property: "opacity"
    value: root.progress
}
```

Prefer:

```qml
onProgressChanged: {
    if (root.newItem)
        root.newItem.opacity =
            root.progress
}
```

### Hiding source items in shader plugins

Do not use:

```qml
hideSource: true
```

The host controls wallpaper visibility.

### Destroying the transition

Do not call:

```qml
root.destroy()
```

The host owns the transition lifecycle.

---

# 26. Minimal QML template

```qml
import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "qml"

    function prepare() {
        if (root.oldItem)
            root.oldItem.opacity = 1

        if (root.newItem)
            root.newItem.opacity = 0
    }

    onProgressChanged: {
        if (!root.running)
            return

        if (root.oldItem)
            root.oldItem.opacity =
                1.0 - root.progress

        if (root.newItem)
            root.newItem.opacity =
                root.progress
    }
}
```

---

# 27. Minimal shader template

```qml
import QtQuick
import qs.wallpaper.components

Transition {
    id: root

    mode: "shader"

    ShaderEffectSource {
        id: oldSource

        anchors.fill: parent

        sourceItem:
            root.oldItem

        live: true
        recursive: true

        visible: false
    }

    ShaderEffectSource {
        id: newSource

        anchors.fill: parent

        sourceItem:
            root.newItem

        live: true
        recursive: true

        visible: false
    }

    ShaderEffect {
        anchors.fill: parent

        visible:
            root.running

        property var fromTexture:
            oldSource

        property var toTexture:
            newSource

        property real progress:
            root.progress

        fragmentShader:
            Qt.resolvedUrl(
                "effect.frag.qsb"
            )
    }
}
```

---

# 28. Plugin checklist

```text
[ ] Plugin directory exists
[ ] manifest.json exists
[ ] Unique ID
[ ] name exists
[ ] author exists
[ ] version exists
[ ] type is "qml" or "shader"
[ ] path is correct
[ ] QML component exists
[ ] Component inherits Transition
[ ] mode is correct
[ ] QML animations do NOT use persistent Binding objects
[ ] Shader plugins use .qsb
[ ] Shader outputs the new wallpaper at progress = 1
[ ] Shader does not use hideSource: true
[ ] Plugin does not modify WallpaperManager
[ ] Plugin does not modify WallpaperLayer
[ ] Plugin does not destroy itself
[ ] Plugin appears in:

    qs ipc call n0ctos-transition list
```

---

# 29. The rule to remember

A transition plugin should only answer:

> **How should the old wallpaper visually become the new wallpaper?**

For QML:

```qml
oldItem
newItem
progress
```

For shaders:

```qml
fromTexture
toTexture
progress
```

Everything else is handled by N0ctOS.
