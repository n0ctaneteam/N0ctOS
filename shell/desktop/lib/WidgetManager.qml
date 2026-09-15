pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // CONFIG
    // ============================================================

    readonly property string configPath:
        Quickshell.env("HOME") +
        "/.config/N0ctOS/widgets.json"

    // ============================================================
    // PUBLIC STATE
    // ============================================================

    /*
     * Configuration owned exclusively by WidgetManager.
     *
     * IMPORTANT:
     * This is NOT named "data" because Item already exposes
     * a read-only data property.
     */
    property var configData: ({
        version: 1,
        screens: ({})
    })

    readonly property bool loaded:
        root._loaded

    readonly property bool saving:
        root._saving

    readonly property int instanceCount:
        root._instanceCount

    // ============================================================
    // SIGNALS
    // ============================================================

    /*
     * Emitted whenever the live widget instance model changes.
     *
     * WidgetLayer listens to this and asks for its screen snapshot.
     */
    signal instancesChanged(string screenName)

    signal configurationLoaded()

    signal configurationSaved()

    // ============================================================
    // INTERNAL STATE
    // ============================================================

    property bool _loaded: false
    property bool _saving: false

    readonly property int _instanceCount:
        root._countInstances(
            root.configData
        )

    // ============================================================
    // CONFIG NORMALIZATION
    // ============================================================

    function _emptyConfig() {
        return {
            version: 1,
            screens: ({})
        }
    }

    function _normalizeConfig(value) {
        const result =
            _emptyConfig()

        if (
            value &&
            typeof value === "object"
        ) {
            if (
                value.version !== undefined
            ) {
                const version =
                    Number(value.version)

                if (
                    Number.isFinite(version) &&
                    version > 0
                )
                    result.version =
                        version
            }

            if (
                value.screens &&
                typeof value.screens === "object"
            ) {
                const sourceScreens =
                    value.screens

                const screens = ({})

                for (
                    const name
                    of Object.keys(
                        sourceScreens
                    )
                ) {
                    const screen =
                        sourceScreens[name]

                    if (
                        !screen ||
                        typeof screen !== "object"
                    )
                        continue

                    screens[name] = {
                        widgets:
                            Array.isArray(
                                screen.widgets
                            )
                                ? screen.widgets.slice()
                                : []
                    }
                }

                result.screens =
                    screens
            }
        }

        return result
    }

    // ============================================================
    // SCREEN API
    // ============================================================

    function screenConfig(screenName) {
        const name =
            String(screenName || "").trim()

        if (!name)
            return {
                widgets: []
            }

        if (
            !root.configData.screens ||
            typeof root.configData.screens !==
                "object"
        )
            return {
                widgets: []
            }

        const value =
            root.configData.screens[name]

        if (
            !value ||
            typeof value !== "object"
        )
            return {
                widgets: []
            }

        return {
            widgets:
                Array.isArray(value.widgets)
                    ? value.widgets
                    : []
        }
    }

    /*
     * Returns a fresh snapshot.
     *
     * WidgetLayer must treat this as read-only.
     */
    function instancesForScreen(screenName) {
        const screen =
            root.screenConfig(
                screenName
            )

        return screen.widgets.map(
            function(instance) {
                return root._cloneInstance(
                    instance
                )
            }
        )
    }

    // ============================================================
    // INSTANCE API
    // ============================================================

    function getInstance(
        screenName,
        instanceId
    ) {
        const widgets =
            root.screenConfig(
                screenName
            ).widgets

        const id =
            String(instanceId || "")

        for (
            const instance
            of widgets
        ) {
            if (
                String(
                    instance.instanceId ||
                    ""
                ) === id
            )
                return root._cloneInstance(
                    instance
                )
        }

        return null
    }

    function hasInstance(
        screenName,
        instanceId
    ) {
        return !!root.getInstance(
            screenName,
            instanceId
        )
    }

    function addInstance(
        screenName,
        instance
    ) {
        const name =
            String(screenName || "").trim()

        if (!name) {
            console.warn(
                "[WidgetManager] addInstance: empty screen"
            )
            return false
        }

        if (
            !instance ||
            typeof instance !== "object"
        ) {
            console.warn(
                "[WidgetManager] addInstance: invalid instance"
            )
            return false
        }

        const normalized =
            root._normalizeInstance(
                instance,
                name
            )

        if (!normalized)
            return false

        const current =
            root.screenConfig(name).widgets

        if (
            current.some(
                function(item) {
                    return String(
                        item.instanceId
                    ) === normalized.instanceId
                }
            )
        ) {
            console.warn(
                "[WidgetManager] instance already exists:",
                normalized.instanceId
            )

            return false
        }

        const nextWidgets =
            current
                .map(
                    root._cloneInstance
                )

        nextWidgets.push(
            normalized
        )

        root._writeScreenWidgets(
            name,
            nextWidgets
        )

        root._save()

        return true
    }

    function removeInstance(
        screenName,
        instanceId
    ) {
        const name =
            String(screenName || "").trim()

        const id =
            String(instanceId || "")

        if (!name || !id)
            return false

        const current =
            root.screenConfig(name).widgets

        const next =
            current.filter(
                function(instance) {
                    return String(
                        instance.instanceId
                    ) !== id
                }
            )

        if (
            next.length ===
            current.length
        )
            return false

        root._writeScreenWidgets(
            name,
            next
        )

        root._save()

        return true
    }

    /*
     * Replace only one instance.
     *
     * This is the foundation for later drag/resize persistence.
     */
    function updateInstance(
        screenName,
        instanceId,
        patch
    ) {
        const name =
            String(screenName || "").trim()

        const id =
            String(instanceId || "")

        if (
            !name ||
            !id ||
            !patch ||
            typeof patch !== "object"
        )
            return false

        const current =
            root.screenConfig(name).widgets

        let found = false

        const next =
            current.map(
                function(instance) {
                    if (
                        String(
                            instance.instanceId
                        ) !== id
                    )
                        return root._cloneInstance(
                            instance
                        )

                    found = true

                    return root._mergeInstance(
                        instance,
                        patch,
                        name
                    )
                }
            )

        if (!found)
            return false

        root._writeScreenWidgets(
            name,
            next
        )

        root._save()

        return true
    }

    // ============================================================
    // SCREEN REPLACEMENT
    // ============================================================

    function setScreenWidgets(
        screenName,
        widgets
    ) {
        const name =
            String(screenName || "").trim()

        if (!name)
            return false

        const source =
            Array.isArray(widgets)
                ? widgets
                : []

        const next =
            []

        for (
            const instance
            of source
        ) {
            const normalized =
                root._normalizeInstance(
                    instance,
                    name
                )

            if (normalized)
                next.push(
                    normalized
                )
        }

        root._writeScreenWidgets(
            name,
            next
        )

        root._save()

        return true
    }

    function ensureScreen(
        screenName
    ) {
        const name =
            String(screenName || "").trim()

        if (!name)
            return false

        if (
            root.configData.screens &&
            root.configData.screens[name]
        )
            return false

        root._writeScreenWidgets(
            name,
            []
        )

        root._save()

        return true
    }

    // ============================================================
    // INTERNAL INSTANCE HELPERS
    // ============================================================

    function _normalizeInstance(
        value,
        screenName
    ) {
        if (
            !value ||
            typeof value !== "object"
        )
            return null

        const widgetId =
            String(
                value.widgetId ||
                value.type ||
                ""
            ).trim()

        if (!widgetId) {
            console.warn(
                "[WidgetManager] instance missing widgetId"
            )
            return null
        }

        let instanceId =
            String(
                value.instanceId ||
                value.id ||
                ""
            ).trim()

        if (!instanceId) {
            instanceId =
                root._generateInstanceId(
                    widgetId,
                    screenName
                )
        }

        /*
         * Geometry is always normalized.
         */
        const x =
            root._number(
                value.x,
                0
            )

        const y =
            root._number(
                value.y,
                0
            )

        const width =
            Math.max(
                1,
                root._number(
                    value.width,
                    1
                )
            )

        const height =
            Math.max(
                1,
                root._number(
                    value.height,
                    1
                )
            )

        /*
         * Only instance state belongs here.
         *
         * Registry/manifests remain authoritative for capabilities
         * such as canIntersect/resizable.
         */
        return {
            instanceId:
                instanceId,

            widgetId:
                widgetId,

            screenName:
                String(screenName),

            x: x,
            y: y,

            width: width,
            height: height,

            z:
                root._number(
                    value.z,
                    0
                ),

            variant:
                String(
                    value.variant || ""
                ),

            config:
                value.config &&
                typeof value.config === "object"
                    ? root._cloneObject(
                        value.config
                    )
                    : ({})
        }
    }

    function _mergeInstance(
        oldValue,
        patch,
        screenName
    ) {
        const merged =
            Object.assign(
                {},
                oldValue,
                patch
            )

        if (
            patch.config !== undefined
        ) {
            merged.config =
                patch.config &&
                typeof patch.config ===
                    "object"
                    ? root._cloneObject(
                        patch.config
                    )
                    : ({})
        }

        return root._normalizeInstance(
            merged,
            screenName
        )
    }

    function _cloneInstance(
        value
    ) {
        if (
            !value ||
            typeof value !== "object"
        )
            return null

        return {
            instanceId:
                String(
                    value.instanceId || ""
                ),

            widgetId:
                String(
                    value.widgetId || ""
                ),

            screenName:
                String(
                    value.screenName || ""
                ),

            x:
                Number(value.x || 0),

            y:
                Number(value.y || 0),

            width:
                Math.max(
                    1,
                    Number(value.width || 1)
                ),

            height:
                Math.max(
                    1,
                    Number(value.height || 1)
                ),

            z:
                Number(value.z || 0),

            variant:
                String(
                    value.variant || ""
                ),

            config:
                value.config &&
                typeof value.config === "object"
                    ? root._cloneObject(
                        value.config
                    )
                    : ({})
        }
    }

    function _cloneObject(
        value
    ) {
        if (
            value === null ||
            value === undefined
        )
            return value

        if (
            typeof value !== "object"
        )
            return value

        if (
            Array.isArray(value)
        )
            return value.map(
                root._cloneObject
            )

        const result = ({})

        for (
            const key
            of Object.keys(value)
        ) {
            result[key] =
                root._cloneObject(
                    value[key]
                )
        }

        return result
    }

    function _number(
        value,
        fallback
    ) {
        const n =
            Number(value)

        return Number.isFinite(n)
            ? n
            : fallback
    }

    function _generateInstanceId(
        widgetId,
        screenName
    ) {
        const base =
            String(widgetId)
                .replace(
                    /[^a-zA-Z0-9_-]/g,
                    "-"
                )

        let index = 1

        while (
            root.hasInstance(
                screenName,
                base + "-" + index
            )
        )
            ++index

        return (
            base +
            "-" +
            index
        )
    }

    function _writeScreenWidgets(
        screenName,
        widgets
    ) {
        const next =
            root._normalizeConfig(
                root.configData
            )

        const screens =
            Object.assign(
                {},
                next.screens
            )

        screens[screenName] = {
            widgets:
                Array.isArray(widgets)
                    ? widgets.map(
                        root._cloneInstance
                    )
                    : []
        }

        next.screens =
            screens

        root.configData =
            next

        root.instancesChanged(
            screenName
        )
    }

    function _countInstances(
        config
    ) {
        if (
            !config ||
            !config.screens ||
            typeof config.screens !==
                "object"
        )
            return 0

        let count = 0

        for (
            const name
            of Object.keys(
                config.screens
            )
        ) {
            const screen =
                config.screens[name]

            if (
                screen &&
                Array.isArray(
                    screen.widgets
                )
            )
                count +=
                    screen.widgets.length
        }

        return count
    }

    // ============================================================
    // PERSISTENCE
    // ============================================================

    function _load() {
        if (!root.configPath)
            return

        configFile.path =
            root.configPath
    }

    function _applyLoadedConfig(
        value
    ) {
        root.configData =
            root._normalizeConfig(
                value
            )

        root._loaded = true

        console.log(
            "[WidgetManager] LOADED:",
            root.configPath,
            "| screens:",
            Object.keys(
                root.configData.screens
            ).length,
            "| instances:",
            root.instanceCount
        )

        root.configurationLoaded()

        /*
         * Tell current screens that the snapshot is now valid.
         */
        for (
            const name
            of Object.keys(
                root.configData.screens
            )
        )
            root.instancesChanged(
                name
            )
    }

    function _save() {
        if (!root._loaded) {
            console.warn(
                "[WidgetManager] refusing save before initial load"
            )
            return
        }

        root._saving = true

        const serialized =
            JSON.stringify(
                root.configData,
                null,
                4
            )

        configFile.setText(
            serialized
        )

        root._saving = false

        console.log(
            "[WidgetManager] SAVED:",
            root.configPath
        )

        root.configurationSaved()
    }

    // ============================================================
    // FILE VIEW
    // ============================================================

    FileView {
        id: configFile

        blockLoading: true
        printErrors: true

        atomicWrites: true

        onLoadedChanged: {
            if (!loaded)
                return

            try {
                const parsed =
                    JSON.parse(
                        text()
                    )

                root._applyLoadedConfig(
                    parsed
                )
            } catch (e) {
                console.warn(
                    "[WidgetManager] config parse failed:",
                    e
                )

                root._applyLoadedConfig(
                    root._emptyConfig()
                )
            }
        }

        onLoadFailed:
            function(error) {
                console.warn(
                    "[WidgetManager] config load failed:",
                    root.configPath,
                    "|",
                    error
                )

                /*
                 * First boot:
                 *
                 * There is no widgets.json yet.
                 *
                 * Create a clean configuration in memory and persist it.
                 */
                root._applyLoadedConfig(
                    root._emptyConfig()
                )

                root._save()
            }
    }

    // ============================================================
    // LIFECYCLE
    // ============================================================

    Component.onCompleted: {
        console.log(
            "[WidgetManager] STARTED:",
            root.configPath
        )

        root._load()
    }
}