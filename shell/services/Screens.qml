pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============================================================
    // INTERNAL STATE
    // ============================================================

    property var _screenNames: []
    property var _connectedByName: ({})
    property var _connectedNames: []

    property bool _refreshing: false

    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property bool ready:
        Config.ready

    /*
     * Remembered screen priority.
     *
     * Disconnected screens intentionally remain here so their
     * priority is preserved when they are reconnected later.
     */
    readonly property var names:
        root._screenNames.slice()

    /*
     * Live ShellScreen objects currently exposed by Quickshell.
     */
    readonly property var screens:
        Quickshell.screens

    /*
     * Names of currently connected screens.
     */
    readonly property var connectedNames:
        root._connectedNames.slice()

    readonly property int count:
        Quickshell.screens.length

    /*
     * Currently resolved primary screen.
     *
     * This is always selected from the current Quickshell.screens
     * list. We never intentionally retain a disconnected screen.
     */
    property var primaryScreen: null

    readonly property string primaryScreenName:
        root.primaryScreen
            ? String(root.primaryScreen.name || "")
            : ""

    // ============================================================
    // SIGNALS
    // ============================================================

    signal screenDiscovered(string name)
    signal configurationChanged()
    signal refreshed()

    // ============================================================
    // CONFIG REACTIVITY
    // ============================================================

    Connections {
        target: Config

        /*
         * Covers external config-file changes.
         */
        function onExternalReload() {
            root.syncFromConfig()
            root.refresh()
        }

        /*
         * Covers all Config mutations, including local writes.
         *
         * A config revision can change without the physical screen
         * topology changing, so only primary resolution is needed.
         */
        function onRevisionChanged() {
            if (!root.ready)
                return

            root.syncFromConfig()
            root.resolvePrimary()
        }
    }

    // ============================================================
    // QUICKSHELL SCREEN CHANGES
    // ============================================================

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.refresh()
        }
    }

    // ============================================================
    // STARTUP
    // ============================================================

    Component.onCompleted: {
        root.syncFromConfig()
        root.refresh()
    }

    onReadyChanged: {
        if (!root.ready)
            return

        root.syncFromConfig()
        root.refresh()
    }

    // ============================================================
    // CONFIGURATION
    // ============================================================

    function syncFromConfig() {
        if (!Config.ready)
            return

        const stored =
            Config.get(
                "screens",
                []
            )

        const normalized = []

        if (Array.isArray(stored)) {
            for (
                let i = 0;
                i < stored.length;
                ++i
            ) {
                const value = stored[i]

                if (
                    value === null ||
                    value === undefined
                ) {
                    continue
                }

                const name =
                    String(value)

                if (
                    name.length === 0 ||
                    normalized.indexOf(name) !== -1
                ) {
                    continue
                }

                normalized.push(name)
            }
        }

        const oldNames =
            root._screenNames

        let changed =
            oldNames.length !==
            normalized.length

        if (!changed) {
            for (
                let i = 0;
                i < normalized.length;
                ++i
            ) {
                if (
                    oldNames[i] !==
                    normalized[i]
                ) {
                    changed = true
                    break
                }
            }
        }

        if (!changed)
            return false

        root._screenNames =
            normalized

        root.configurationChanged()

        return true
    }

    function saveNames(names) {
        if (!Config.ready)
            return false

        return Config.set(
            "screens",
            names.slice()
        )
    }

    // ============================================================
    // SCREEN REFRESH
    // ============================================================

    function refresh() {
        if (!Config.ready)
            return

        if (root._refreshing)
            return

        root._refreshing = true

        const connected =
            Quickshell.screens

        /*
         * Use a prototype-less object because connector names are
         * arbitrary strings.
         *
         * This avoids collisions with Object.prototype keys.
         */
        const map =
            Object.create(null)

        const connectedNames = []

        let updatedNames =
            root._screenNames.slice()

        const discoveredNames = []

        // --------------------------------------------------------
        // BUILD LIVE SCREEN INDEX
        // --------------------------------------------------------

        for (
            let i = 0;
            i < connected.length;
            ++i
        ) {
            const screen =
                connected[i]

            if (
                !screen ||
                !screen.name
            ) {
                continue
            }

            const name =
                String(screen.name)

            map[name] =
                screen

            connectedNames.push(name)

            /*
             * Preserve configured ordering.
             * New screens are appended.
             */
            if (
                updatedNames.indexOf(name) === -1
            ) {
                updatedNames.push(name)
                discoveredNames.push(name)
            }
        }

        root._connectedByName =
            map

        root._connectedNames =
            connectedNames

        // --------------------------------------------------------
        // COMMIT DISCOVERED SCREENS
        // --------------------------------------------------------

        if (
            discoveredNames.length > 0
        ) {
            root._screenNames =
                updatedNames

            root.saveNames(
                updatedNames
            )

            root.configurationChanged()

            /*
             * Emit only after the public state has been updated.
             * Consumers can safely inspect Screen/screen names from
             * inside the signal handler.
             */
            for (
                let i = 0;
                i < discoveredNames.length;
                ++i
            ) {
                const name =
                    discoveredNames[i]

                root.screenDiscovered(
                    name
                )

                console.info(
                    "[Screens] discovered:",
                    name
                )
            }

            console.info(
                "[Screens] updated order:",
                JSON.stringify(
                    updatedNames
                )
            )
        }

        // --------------------------------------------------------
        // PRIMARY RESOLUTION
        // --------------------------------------------------------

        root.resolvePrimary()

        root._refreshing = false

        root.refreshed()
    }

    // ============================================================
    // PRIMARY SCREEN
    // ============================================================

    function resolvePrimary() {
        const connected =
            root._connectedByName

        let resolved = null

        /*
         * Priority rules:
         *
         * 1. Walk remembered screen names in order.
         * 2. Select the first one currently connected.
         * 3. If none are connected, use the first live screen.
         */

        for (
            let i = 0;
            i < root._screenNames.length;
            ++i
        ) {
            const name =
                root._screenNames[i]

            const screen =
                connected[name]

            if (screen) {
                resolved =
                    screen

                break
            }
        }

        if (
            !resolved &&
            Quickshell.screens.length > 0
        ) {
            resolved =
                Quickshell.screens[0]
        }

        const oldName =
            root.primaryScreenName

        root.primaryScreen =
            resolved

        const newName =
            root.primaryScreenName

        if (
            oldName !== newName
        ) {
            console.info(
                "[Screens] primary:",
                newName || "(none)"
            )
        }
    }

    // ============================================================
    // LOOKUP
    // ============================================================

    function screenForName(name) {
        if (
            !name ||
            String(name).length === 0
        ) {
            return null
        }

        const key =
            String(name)

        return (
            root._connectedByName[key] ||
            null
        )
    }

    function isConnected(name) {
        return (
            root.screenForName(name) !== null
        )
    }

    // ============================================================
    // PRIMARY CONFIGURATION
    // ============================================================

    function setPrimary(name) {
        const target =
            String(name || "")

        if (target.length === 0)
            return false

        if (!root.isConnected(target)) {
            console.warn(
                "[Screens] screen is not connected:",
                target
            )

            return false
        }

        const index =
            root._screenNames.indexOf(target)

        if (index === -1) {
            console.warn(
                "[Screens] screen is not present in remembered order:",
                target
            )

            return false
        }

        if (index > 0) {
            const updated =
                root._screenNames.slice()

            updated.splice(
                index,
                1
            )

            updated.unshift(
                target
            )

            root._screenNames =
                updated

            root.saveNames(
                updated
            )

            root.configurationChanged()
        }

        root.resolvePrimary()

        return (
            root.primaryScreenName ===
            target
        )
    }

    // ============================================================
    // SCREEN INFORMATION
    // ============================================================

    function _screenInfo(screen) {
        if (!screen)
            return {}

        return {
            name:
                String(
                    screen.name || ""
                ),

            model:
                String(
                    screen.model || ""
                ),

            serialNumber:
                String(
                    screen.serialNumber || ""
                ),

            x:
                Number(
                    screen.x || 0
                ),

            y:
                Number(
                    screen.y || 0
                ),

            width:
                Number(
                    screen.width || 0
                ),

            height:
                Number(
                    screen.height || 0
                ),

            devicePixelRatio:
                Number(
                    screen.devicePixelRatio || 1
                ),

            logicalPixelDensity:
                Number(
                    screen.logicalPixelDensity || 0
                ),

            physicalPixelDensity:
                Number(
                    screen.physicalPixelDensity || 0
                )
        }
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-screens"

        function count(): int {
            return root.count
        }

        function primary(): string {
            return root.primaryScreenName
        }

        function names(): string {
            return JSON.stringify(
                root._screenNames
            )
        }

        function connected(): string {
            return JSON.stringify(
                root._connectedNames
            )
        }

        function isConnected(
            name: string
        ): bool {
            return root.isConnected(
                name
            )
        }

        function list(): string {
            const result = []

            const connected =
                Quickshell.screens

            for (
                let i = 0;
                i < connected.length;
                ++i
            ) {
                const screen =
                    connected[i]

                if (
                    !screen ||
                    !screen.name
                ) {
                    continue
                }

                result.push(
                    root._screenInfo(
                        screen
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }

        function get(
            name: string
        ): string {
            const screen =
                root.screenForName(name)

            if (!screen)
                return ""

            return JSON.stringify(
                root._screenInfo(
                    screen
                )
            )
        }

        function getPrimary(): string {
            if (
                !root.primaryScreen
            ) {
                return ""
            }

            return JSON.stringify(
                root._screenInfo(
                    root.primaryScreen
                )
            )
        }

        function setPrimary(
            name: string
        ): bool {
            return root.setPrimary(
                name
            )
        }

        function refresh(): void {
            root.refresh()
        }
    }
}