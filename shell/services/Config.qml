pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // ============================================================
    // DEBUG
    // ============================================================

    readonly property bool isDebugLogging:
        ConfigStore.isDebugLogging

    // ============================================================
    // DEFAULT FILE
    // ============================================================

    readonly property string defaultFileKey:
        ConfigStore.defaultFileKey

    readonly property string configPath:
        ConfigStore.configPath

    // ============================================================
    // REACTIVE DATA
    // ============================================================

    readonly property var data:
        ConfigStore.document

    readonly property var documents:
        ConfigStore.documents

    readonly property bool isReady:
        ConfigStore.isReady

    readonly property bool isWriting:
        ConfigStore.isWriting

    readonly property bool isDirty:
        ConfigStore.isDirty

    readonly property int revision:
        ConfigStore.revision

    // ============================================================
    // REGISTERED PATHS
    // ============================================================

    readonly property var paths:
        ConfigStore.paths

    readonly property var pathKeys:
        ConfigStore.pathKeys

    // ============================================================
    // SIGNALS
    // ============================================================

    signal externalReload()
    signal saveError(string reason)

    signal externalReloadFor(string fileKey)
    signal saveErrorFor(
        string fileKey,
        string reason
    )

    signal documentChanged(
        string fileKey
    )

    // ============================================================
    // STORE SIGNALS
    // ============================================================

    Connections {
        target: ConfigStore

        function onExternalReload(
            fileKey
        ) {
            root._debug(
                "RELOAD",
                "External reload completed:",
                fileKey,
                "->",
                ConfigStore.pathFor(
                    fileKey
                )
            )

            root.externalReload()

            root.externalReloadFor(
                fileKey
            )
        }

        function onSaveError(
            fileKey,
            reason
        ) {
            root._warn(
                "SAVE",
                "Save failed:",
                fileKey,
                "->",
                reason
            )

            root.saveError(
                reason
            )

            root.saveErrorFor(
                fileKey,
                reason
            )
        }

        function onDocumentUpdated(
            fileKey
        ) {
            root._debug(
                "DATA",
                "Document updated:",
                fileKey,
                "revision:",
                ConfigStore.revisionFor(
                    fileKey
                )
            )

            root.documentChanged(
                fileKey
            )
        }
    }

    // ============================================================
    // PATH REGISTRY
    // ============================================================

    function registerPath(
        fileKey,
        fsPath
    ) {
        root._debug(
            "PATH",
            "Registering path:",
            fileKey,
            "->",
            fsPath
        )

        const result =
            ConfigStore.registerPath(
                fileKey,
                fsPath
            )

        if (
            !result
        ) {
            root._warn(
                "PATH",
                "Failed to register path:",
                fileKey,
                "->",
                fsPath
            )
        } else {
            root._debug(
                "PATH",
                "Path registered:",
                fileKey,
                "->",
                ConfigStore.pathFor(
                    fileKey
                )
            )
        }

        return result
    }

    function registerPaths(
        pathTable
    ) {
        root._debug(
            "PATH",
            "Registering path table:",
            JSON.stringify(
                pathTable || {}
            )
        )

        const result =
            ConfigStore.registerPaths(
                pathTable
            )

        if (
            !result
        ) {
            root._warn(
                "PATH",
                "One or more paths failed to register."
            )
        }

        return result
    }

    function hasPath(
        fileKey
    ) {
        return ConfigStore.hasPath(
            fileKey
        )
    }

    function pathFor(
        fileKey
    ) {
        return ConfigStore.pathFor(
            fileKey
        )
    }

    function updatePath(
        fileKey,
        fsPath
    ) {
        root._debug(
            "PATH",
            "Updating path:",
            fileKey,
            "->",
            fsPath
        )

        const result =
            ConfigStore.updatePath(
                fileKey,
                fsPath
            )

        if (
            !result
        ) {
            root._warn(
                "PATH",
                "Failed to update path:",
                fileKey,
                "->",
                fsPath
            )
        } else {
            root._debug(
                "PATH",
                "Path updated:",
                fileKey,
                "->",
                ConfigStore.pathFor(
                    fileKey
                )
            )
        }

        return result
    }

    function removePath(
        fileKey
    ) {
        root._debug(
            "PATH",
            "Removing path:",
            fileKey
        )

        const result =
            ConfigStore.removePath(
                fileKey
            )

        if (
            !result
        ) {
            root._warn(
                "PATH",
                "Failed to remove path:",
                fileKey
            )
        } else {
            root._debug(
                "PATH",
                "Path removed:",
                fileKey
            )
        }

        return result
    }

    // ============================================================
    // READ
    // ============================================================

    function get(
        dataPath,
        fallbackValue,
        fileKey
    ) {
        return ConfigStore.get(
            dataPath,
            fallbackValue,
            fileKey
        )
    }

    function has(
        dataPath,
        fileKey
    ) {
        return ConfigStore.has(
            dataPath,
            fileKey
        )
    }

    function documentFor(
        fileKey
    ) {
        return ConfigStore.documentFor(
            fileKey
        )
    }

    function historyAt(
        fileKey
    ) {
        return ConfigStore.historyAt(
            fileKey
        )
    }

    function historyFor(
        fileKey
    ) {
        return root.historyAt(
            fileKey
        )
    }

    function isReadyFor(
        fileKey
    ) {
        return ConfigStore.isReadyFor(
            fileKey
        )
    }

    function isWritingFor(
        fileKey
    ) {
        return ConfigStore.isWritingFor(
            fileKey
        )
    }

    function isDirtyFor(
        fileKey
    ) {
        return ConfigStore.isDirtyFor(
            fileKey
        )
    }

    function revisionFor(
        fileKey
    ) {
        return ConfigStore.revisionFor(
            fileKey
        )
    }

    // ============================================================
    // WRITE
    // ============================================================

    function set(
        dataPath,
        value,
        fileKey
    ) {
        root._debug(
            "WRITE",
            "set():",
            fileKey ||
            root.defaultFileKey,
            "->",
            dataPath
        )

        const result =
            ConfigStore.set(
                dataPath,
                value,
                fileKey
            )

        if (
            !result
        ) {
            root._warn(
                "WRITE",
                "set() failed:",
                fileKey ||
                root.defaultFileKey,
                "->",
                dataPath
            )
        }

        return result
    }

    function update(
        dataPath,
        value,
        fileKey
    ) {
        root._debug(
            "WRITE",
            "update():",
            fileKey ||
            root.defaultFileKey,
            "->",
            dataPath
        )

        const result =
            ConfigStore.update(
                dataPath,
                value,
                fileKey
            )

        if (
            !result
        ) {
            root._warn(
                "WRITE",
                "update() failed:",
                fileKey ||
                root.defaultFileKey,
                "->",
                dataPath
            )
        }

        return result
    }

    function remove(
        dataPath,
        fileKey
    ) {
        root._debug(
            "WRITE",
            "remove():",
            fileKey ||
            root.defaultFileKey,
            "->",
            dataPath
        )

        const result =
            ConfigStore.remove(
                dataPath,
                fileKey
            )

        if (
            !result
        ) {
            root._warn(
                "WRITE",
                "remove() failed:",
                fileKey ||
                root.defaultFileKey,
                "->",
                dataPath
            )
        }

        return result
    }

    // ============================================================
    // UNDO HISTORY
    // ============================================================

    function undo(
        fileKey
    ) {
        root._debug(
            "WRITE",
            "undo():",
            fileKey ||
            root.defaultFileKey
        )

        const result =
            ConfigStore.undo(
                fileKey
            )

        if (
            !result
        ) {
            root._debug(
                "WRITE",
                "undo(): nothing to undo:",
                fileKey ||
                root.defaultFileKey
            )
        }

        return result
    }

    function redo(
        fileKey
    ) {
        root._debug(
            "WRITE",
            "redo():",
            fileKey ||
            root.defaultFileKey
        )

        const result =
            ConfigStore.redo(
                fileKey
            )

        if (
            !result
        ) {
            root._debug(
                "WRITE",
                "redo(): nothing to redo:",
                fileKey ||
                root.defaultFileKey
            )
        }

        return result
    }

    function revert(
        fileKey
    ) {
        root._debug(
            "WRITE",
            "revert():",
            fileKey ||
            root.defaultFileKey
        )

        const result =
            ConfigStore.revert(
                fileKey
            )

        if (
            !result
        ) {
            root._warn(
                "WRITE",
                "revert() failed:",
                fileKey ||
                root.defaultFileKey
            )
        }

        return result
    }

    // ============================================================
    // FILE CONTROL
    // ============================================================

    function save(
        fileKey
    ) {
        const key =
            fileKey ||
            root.defaultFileKey

        root._debug(
            "WRITE",
            "save():",
            key,
            "->",
            ConfigStore.pathFor(
                key
            )
        )

        const result =
            ConfigStore.save(
                fileKey
            )

        if (
            !result
        ) {
            root._warn(
                "WRITE",
                "save() failed:",
                key
            )
        }

        return result
    }

    function reload(
        fileKey
    ) {
        const key =
            fileKey ||
            root.defaultFileKey

        root._debug(
            "LOAD",
            "Manual reload requested:",
            key,
            "->",
            ConfigStore.pathFor(
                key
            )
        )

        const result =
            ConfigStore.reload(
                fileKey
            )

        if (
            !result
        ) {
            root._warn(
                "LOAD",
                "reload() failed:",
                key
            )
        }

        return result
    }

    function reloadAll() {
        root._debug(
            "LOAD",
            "Manual reload requested for all registered files."
        )

        const result =
            ConfigStore.reloadAll()

        if (
            !result
        ) {
            root._warn(
                "LOAD",
                "reloadAll() completed with one or more failures."
            )
        }

        return result
    }

    // ============================================================
    // LOGGING
    // ============================================================

    function _debug() {
        if (
            !root.isDebugLogging
        ) {
            return
        }

        const args =
            Array.prototype.slice.call(
                arguments
            )

        console.debug(
            "[N0ctOS Config]",
            ...args
        )
    }

    function _warn() {
        const args =
            Array.prototype.slice.call(
                arguments
            )

        console.warn(
            "[N0ctOS Config]",
            ...args
        )
    }
} 