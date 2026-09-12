pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string id:
        String(
            WallpaperManager.transitionConfig &&
            WallpaperManager.transitionConfig.id
                ? WallpaperManager.transitionConfig.id
                : "none"
        )

    readonly property int duration:
        Math.max(
            0,
            Number(
                WallpaperManager.transitionConfig &&
                WallpaperManager.transitionConfig.duration !== undefined
                    ? WallpaperManager.transitionConfig.duration
                    : 500
            )
        )

    readonly property var parameters:
        WallpaperManager.transitionConfig &&
        WallpaperManager.transitionConfig.parameters &&
        typeof WallpaperManager.transitionConfig.parameters === "object"
            ? WallpaperManager.transitionConfig.parameters
            : {}

    readonly property var definition:
        TransitionRegistry.get(root.id)

    readonly property string type:
        root.definition
            ? String(root.definition.type || "qml")
            : "none"

    readonly property bool available:
        root.id !== "none" &&
        !!root.definition

    readonly property bool isShader:
        root.available &&
        root.type.toLowerCase() === "shader"

    readonly property bool isQml:
        root.available &&
        !root.isShader

    signal transitionChanged()

    function get(id) {
        return TransitionRegistry.get(
            String(id || "none")
        )
    }

    function has(id) {
        return TransitionRegistry.has(
            String(id || "")
        )
    }

    function ids() {
        return TransitionRegistry.ids()
    }

    function create(id, parent, properties) {
        var entry =
            root.get(id)

        if (!entry) {
            console.warn(
                "[TransitionManager] transition not found:",
                id
            )

            return null
        }

        if (!entry.componentUrl) {
            console.warn(
                "[TransitionManager] transition has no component:",
                id
            )

            return null
        }

        var component =
            Qt.createComponent(
                entry.componentUrl,
                Component.Asynchronous
            )

        if (!component) {
            console.warn(
                "[TransitionManager] failed creating component:",
                entry.componentUrl
            )

            return null
        }

        return {
            component: component,
            entry: entry
        }
    }

    function current() {
        return {
            id: root.id,
            duration: root.duration,
            type: root.type,
            parameters: Object.assign(
                {},
                root.parameters
            )
        }
    }

    Component.onCompleted: {
        console.log(
            "[TransitionManager] START"
        )
    }

    Connections {
        target: WallpaperManager

        function onTransitionChanged() {
            root.transitionChanged()
        }
    }

    Connections {
        target: TransitionRegistry

        function onRegistryChanged() {
            root.transitionChanged()
        }
    }

    IpcHandler {
        target: "n0ctos-transition"
    
        function set(id: string): bool {
            return root.setTransition(id)
        }
    
        function duration(ms: int): bool {
            return root.setDuration(ms)
        }
    
        function setConfig(id: string, ms: int): bool {
            return root.setConfig(id, ms)
        }
    
        function status(): string {
            return root.status()
        }
    
        function list(): string {
            return root.list()
        }
    
        function get(): string {
            return root.id
        }
    
        function getDuration(): int {
            return root.duration
        }
    }

    function setTransition(id) {
        id = String(id || "none")
    
        if (id !== "none" && !TransitionRegistry.has(id)) {
            console.warn(
                "[TransitionManager] transition not found:",
                id
            )
            return false
        }
    
        return WallpaperManager.setTransitionConfig(
            id,
            root.duration,
            root.parameters
        )
    }
    
    function setDuration(ms) {
        ms = Math.max(0, Number(ms))
    
        return WallpaperManager.setTransitionConfig(
            root.id,
            ms,
            root.parameters
        )
    }
    
    function setConfig(id, ms) {
        id = String(id || "none")
        ms = Math.max(0, Number(ms))
    
        if (id !== "none" && !TransitionRegistry.has(id)) {
            console.warn(
                "[TransitionManager] transition not found:",
                id
            )
            return false
        }
    
        return WallpaperManager.setTransitionConfig(
            id,
            ms,
            root.parameters
        )
    }
    
    function status() {
        var entry = root.definition
    
        return JSON.stringify({
            id: root.id,
            duration: root.duration,
            type: root.type,
            available: root.available,
            parameters: root.parameters,
            name: entry ? String(entry.name || root.id) : ""
        })
    }
    
    function list() {
        var ids = TransitionRegistry.ids()
    
        if (!ids.length)
            return "(no transitions discovered)"
    
        var lines = []
    
        for (var i = 0; i < ids.length; ++i) {
            var id = ids[i]
            var entry = TransitionRegistry.get(id)
    
            if (!entry)
                continue
    
            lines.push(
                id +
                " : " +
                String(entry.name || id) +
                " [" +
                String(entry.type || "qml") +
                "]"
            )
        }
    
        return lines.length
            ? lines.join("\n")
            : "(no transitions discovered)"
    }
}