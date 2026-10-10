pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import QtQml.Models

Singleton {
    id: root

    // ============================================================
    // DEBUG
    // ============================================================

    /*
     * Set to false when debug logging is no longer needed.
     *
     * Warnings and errors are always emitted.
     */
    property bool isDebugLogging: true

    // ============================================================
    // PATHS
    // ============================================================

    readonly property string homeDir:
        String(
            Quickshell.env("HOME") || ""
        )

    readonly property string xdgConfigHome:
        String(
            Quickshell.env("XDG_CONFIG_HOME") ||
            (root.homeDir + "/.config")
        )

    readonly property string defaultFileKey:
        "homeConfig"

    readonly property string defaultHomeConfigPath:
        root.xdgConfigHome + "/N0ctOS/config.json"

    // ============================================================
    // PATH REGISTRY
    // ============================================================

    property var _paths: ({
        homeConfig:
            root.defaultHomeConfigPath
    })

    property var _pathKeys: [
        root.defaultFileKey
    ]

    readonly property var paths:
        root._paths

    readonly property var pathKeys:
        root._pathKeys

    property int _registryRevision: 0

    property var _warnedUnknownKeys: ({})

    // ============================================================
    // REACTIVE DOCUMENT STATE
    // ============================================================

    property var _documents: ({
        homeConfig: {}
    })

    readonly property var documents:
        root._documents

    readonly property var document:
        root.documentFor(
            root.defaultFileKey
        )

    // ============================================================
    // PER-FILE STATE
    // ============================================================

    /*
     * fileKey -> {
     *     ready: bool,
     *     writing: bool,
     *     writePending: bool,
     *     revision: int
     * }
     */
    property var _fileStates: ({
        homeConfig: {
            ready: false,
            writing: false,
            writePending: false,
            revision: 0
        }
    })

    // ============================================================
    // UNDO HISTORY
    // ============================================================

    /*
     * Maximum history entries per file.
     * The limit applies to past + future together.
     */
    readonly property int historyLimit:
        100

    /*
     * fileKey -> { past: [], future: [] }
     *
     * Each entry is a compact forward delta.
     */
    property var _history: ({
        homeConfig: {
            past: [],
            future: []
        }
    })

    /*
     * fileKey -> clean baseline.
     */
    property var _baselines: ({
        homeConfig: {}
    })

    // ============================================================
    // DEFAULT FILE STATE
    // ============================================================

    readonly property bool isReady:
        root.isReadyFor(
            root.defaultFileKey
        )

    readonly property bool isWriting:
        root.isWritingFor(
            root.defaultFileKey
        )

    readonly property bool isDirty:
        root.isDirtyFor(
            root.defaultFileKey
        )

    readonly property int revision:
        root.revisionFor(
            root.defaultFileKey
        )

    readonly property string configPath:
        root.pathFor(
            root.defaultFileKey
        )

    // ============================================================
    // CONTROLLER REGISTRY
    // ============================================================

    property var _controllers: ({})

    // ============================================================
    // SIGNALS
    // ============================================================

    signal externalReload(string fileKey)
    signal saveError(string fileKey, string reason)
    signal documentUpdated(string fileKey)

    // ============================================================
    // FILE CONTROLLERS
    // ============================================================

    Instantiator {
        id: fileControllers

        model:
            root._pathKeys

        delegate: Item {
            id: controller

            visible: false
            width: 0
            height: 0

            required property var modelData

            readonly property string fileKey:
                String(modelData)

            readonly property string filePath:
                root._paths[controller.fileKey] ||
                root.defaultHomeConfigPath

            property bool isDirectoryReady:
                false

            /*
             * writeText = write currently owned by FileView.
             * queuedWriteText = newest state waiting behind it.
             */
            property string writeText:
                ""

            property string queuedWriteText:
                ""

            /*
             * save() sets this. A mutation after save()
             * cancels it.
             */
            property bool completeSaveWhenIdle:
                false

            /*
             * Set on any failed disk write, cleared on success.
             * Lets save() know when disk is stale and a forced
             * rewrite is required instead of a sync checkpoint.
             */
            property bool writeFailed:
                false

            /*
             * Consumed by the next load result.
             * Distinguishes explicit reload() from watcher reloads.
             */
            property bool explicitReloadPending:
                false

            Timer {
                id: reloadDebounce

                interval: 80
                repeat: false

                onTriggered: {
                    if (
                        root._isWritePending(
                            controller.fileKey
                        )
                    ) {
                        root._debug(
                            "WATCH",
                            "Reload suppressed while write pipeline is active:",
                            controller.fileKey
                        )

                        return
                    }

                    root._debug(
                        "WATCH",
                        "Reloading changed file:",
                        controller.fileKey,
                        "->",
                        controller.filePath
                    )

                    configFile.reload()
                }
            }

            Process {
                id: createDirectory

                command: [
                    "mkdir",
                    "-p",
                    root._directoryFor(
                        controller.filePath
                    )
                ]

                onExited:
                    function(exitCode, exitStatus) {

                    if (exitCode !== 0) {
                        root._warn(
                            "WRITE",
                            "Failed to create config directory:",
                            controller.fileKey,
                            "->",
                            root._directoryFor(
                                controller.filePath
                            )
                        )

                        controller.writeText = ""
                        controller.queuedWriteText = ""
                        controller.completeSaveWhenIdle = false
                        controller.writeFailed = true

                        root._setFileState(
                            controller.fileKey,
                            {
                                ready: true,
                                writing: false,
                                writePending: false
                            }
                        )

                        root.saveError(
                            controller.fileKey,
                            "failed to create parent directory"
                        )

                        return
                    }

                    controller.isDirectoryReady = true

                    root._debug(
                        "WRITE",
                        "Config directory ready:",
                        controller.fileKey,
                        "->",
                        root._directoryFor(
                            controller.filePath
                        )
                    )

                    controller._flushQueuedWrite()
                }
            }

            FileView {
                id: configFile

                path:
                    controller.filePath

                watchChanges:
                    true

                atomicWrites:
                    true

                // ------------------------------------------------
                // LOAD
                // ------------------------------------------------

                onLoaded: {
                    root._handleLoaded(
                        controller,
                        configFile
                    )
                }

                // ------------------------------------------------
                // WATCHER
                // ------------------------------------------------

                onFileChanged: {
                    if (
                        root._isWritePending(
                            controller.fileKey
                        )
                    ) {
                        root._debug(
                            "WATCH",
                            "Ignoring watcher event from local write:",
                            controller.fileKey
                        )

                        return
                    }

                    reloadDebounce.restart()
                }

                // ------------------------------------------------
                // LOAD FAILURE
                // ------------------------------------------------

                onLoadFailed:
                    function(error) {

                    root._handleLoadFailed(
                        controller,
                        error
                    )
                }

                // ------------------------------------------------
                // SAVE SUCCESS
                // ------------------------------------------------

                onSaved: {
                    const key =
                        controller.fileKey

                    root._debug(
                        "WRITE",
                        "Write completed:",
                        key,
                        "->",
                        controller.filePath
                    )

                    controller.writeText = ""
                    controller.writeFailed = false

                    root._setFileState(
                        key,
                        {
                            ready: true,
                            writing: false,
                            writePending: false
                        }
                    )

                    /*
                     * Newer state exists. It must be written before
                     * save() may establish the clean baseline.
                     */
                    if (
                        controller.queuedWriteText.length > 0
                    ) {
                        const nextText =
                            controller.queuedWriteText

                        controller.queuedWriteText = ""

                        controller._startWrite(
                            nextText
                        )

                        return
                    }

                    /*
                     * Only an explicit save() can establish a new
                     * clean baseline.
                     */
                    if (
                        controller.completeSaveWhenIdle
                    ) {
                        controller.completeSaveWhenIdle = false

                        root._setBaseline(
                            key,
                            root.documentFor(key)
                        )

                        root._clearHistory(
                            key
                        )

                        root._debug(
                            "WRITE",
                            "Explicit save completed; baseline/history reset:",
                            key
                        )
                    }
                }

                // ------------------------------------------------
                // SAVE FAILURE
                // ------------------------------------------------

                onSaveFailed:
                    function(error) {

                    const key =
                        controller.fileKey

                    const reason =
                        FileViewError.toString(
                            error
                        )

                    root._warn(
                        "WRITE",
                        "Write failed:",
                        key,
                        "->",
                        controller.filePath,
                        reason
                    )

                    /*
                     * Never retain stale serialized data after a
                     * failed write. A later save() serializes the
                     * current in-memory document again.
                     */
                    controller.writeText = ""
                    controller.queuedWriteText = ""
                    controller.completeSaveWhenIdle = false
                    controller.writeFailed = true

                    root._setFileState(
                        key,
                        {
                            ready: true,
                            writing: false,
                            writePending: false
                        }
                    )

                    root.saveError(
                        key,
                        reason
                    )
                }
            }

            // ====================================================
            // WRITE HELPERS
            // ====================================================

            function _serializeDocument() {
                const document =
                    root.documentFor(
                        controller.fileKey
                    )

                try {
                    return (
                        JSON.stringify(
                            document,
                            null,
                            2
                        ) + "\n"
                    )
                } catch (error) {
                    root._warn(
                        "WRITE",
                        "Failed to serialize document:",
                        controller.fileKey,
                        error
                    )

                    root.saveError(
                        controller.fileKey,
                        String(error)
                    )

                    return ""
                }
            }

            function _startWrite(text) {
                if (
                    !text ||
                    text.length === 0
                ) {
                    return false
                }

                if (
                    root.isWritingFor(
                        controller.fileKey
                    )
                ) {
                    controller.queuedWriteText =
                        text

                    root._setFileState(
                        controller.fileKey,
                        {
                            writePending: true
                        }
                    )

                    return true
                }

                if (
                    !controller.isDirectoryReady
                ) {
                    controller.queuedWriteText =
                        text

                    root._setFileState(
                        controller.fileKey,
                        {
                            writePending: true
                        }
                    )

                    if (
                        !createDirectory.running
                    ) {
                        createDirectory.running =
                            true
                    }

                    return true
                }

                controller.writeText =
                    text

                root._setFileState(
                    controller.fileKey,
                    {
                        ready: true,
                        writing: true,
                        writePending: true
                    }
                )

                root._debug(
                    "WRITE",
                    "Writing config:",
                    controller.fileKey,
                    "->",
                    controller.filePath
                )

                configFile.setText(
                    controller.writeText
                )

                return true
            }

            function _flushQueuedWrite() {
                if (
                    root.isWritingFor(
                        controller.fileKey
                    )
                ) {
                    return false
                }

                if (
                    controller.queuedWriteText.length === 0
                ) {
                    return false
                }

                const nextText =
                    controller.queuedWriteText

                controller.queuedWriteText =
                    ""

                return controller._startWrite(
                    nextText
                )
            }

            function queueSave() {
                const serialized =
                    controller._serializeDocument()

                if (!serialized)
                    return false

                return controller._startWrite(
                    serialized
                )
            }

            function forceReload() {
                reloadDebounce.stop()

                if (
                    root._isWritePending(
                        controller.fileKey
                    )
                ) {
                    root._warn(
                        "LOAD",
                        "Reload rejected while write pipeline is active:",
                        controller.fileKey
                    )

                    return false
                }

                controller.explicitReloadPending =
                    true

                root._debug(
                    "LOAD",
                    "Forcing reload:",
                    controller.fileKey,
                    "->",
                    controller.filePath
                )

                configFile.reload()

                return true
            }
        }

        // ========================================================
        // CONTROLLER ADDED
        // ========================================================

        onObjectAdded:
            function(index, object) {

            if (!object)
                return

            const key =
                String(object.fileKey)

            const nextControllers =
                root._copyObject(
                    root._controllers
                )

            nextControllers[key] =
                object

            root._controllers =
                nextControllers

            root._registryRevision += 1

            root._debug(
                "PATH",
                "Controller created:",
                key,
                "->",
                object.filePath
            )

            const state =
                root._stateFor(key)

            if (
                state.writePending ||
                object.queuedWriteText.length > 0
            ) {
                object.queueSave()
            }
        }

        // ========================================================
        // CONTROLLER REMOVED
        // ========================================================

        onObjectRemoved:
            function(index, object) {

            if (!object)
                return

            const key =
                String(object.fileKey)

            const nextControllers =
                root._copyObject(
                    root._controllers
                )

            delete nextControllers[key]

            root._controllers =
                nextControllers

            root._registryRevision += 1

            root._debug(
                "PATH",
                "Controller removed:",
                key
            )
        }
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-config"

        // --------------------------------------------------------
        // Default file state
        // --------------------------------------------------------

        function isReady(): bool {
            return root.isReady
        }

        function isWriting(): bool {
            return root.isWriting
        }

        function isDirty(): bool {
            return root.isDirty
        }

        function getPath(): string {
            return root.configPath
        }

        function getRevision(): int {
            return root.revision
        }

        // --------------------------------------------------------
        // File-specific state
        // --------------------------------------------------------

        function isReadyAt(
            fileKey: string
        ): bool {
            return root.isReadyFor(
                fileKey
            )
        }

        function isWritingAt(
            fileKey: string
        ): bool {
            return root.isWritingFor(
                fileKey
            )
        }

        function isDirtyAt(
            fileKey: string
        ): bool {
            return root.isDirtyFor(
                fileKey
            )
        }

        function getPathAt(
            fileKey: string
        ): string {
            return root.pathFor(
                fileKey
            )
        }

        function getRevisionAt(
            fileKey: string
        ): int {
            return root.revisionFor(
                fileKey
            )
        }

        // --------------------------------------------------------
        // Registry CRUD
        // --------------------------------------------------------

        function hasPath(
            fileKey: string
        ): bool {
            return root.hasPath(
                fileKey
            )
        }

        function getPaths(): string {
            try {
                return JSON.stringify(
                    root.paths
                )
            } catch (error) {
                return ""
            }
        }

        function registerPath(
            fileKey: string,
            fsPath: string
        ): bool {
            return root.registerPath(
                fileKey,
                fsPath
            )
        }

        function updatePath(
            fileKey: string,
            fsPath: string
        ): bool {
            return root.updatePath(
                fileKey,
                fsPath
            )
        }

        function removePath(
            fileKey: string
        ): bool {
            return root.removePath(
                fileKey
            )
        }

        // --------------------------------------------------------
        // Read
        // --------------------------------------------------------

        function get(
            dataPath: string
        ): string {
            return root._ipcGet(
                dataPath,
                root.defaultFileKey
            )
        }

        function getAt(
            dataPath: string,
            fileKey: string
        ): string {
            return root._ipcGet(
                dataPath,
                fileKey
            )
        }

        function getDocument(): string {
            return root._ipcGetDocument(
                root.defaultFileKey
            )
        }

        function getDocumentAt(
            fileKey: string
        ): string {
            return root._ipcGetDocument(
                fileKey
            )
        }

        function history(): string {
            return root._ipcHistory(
                root.defaultFileKey
            )
        }

        function historyAt(
            fileKey: string
        ): string {
            return root._ipcHistory(
                fileKey
            )
        }

        function has(
            dataPath: string
        ): bool {
            return root.has(
                dataPath,
                root.defaultFileKey
            )
        }

        function hasAt(
            dataPath: string,
            fileKey: string
        ): bool {
            return root.has(
                dataPath,
                fileKey
            )
        }

        // --------------------------------------------------------
        // Write
        // --------------------------------------------------------

        function setJson(
            dataPath: string,
            json: string
        ): bool {
            return root._ipcSetJson(
                dataPath,
                json,
                root.defaultFileKey
            )
        }

        function setJsonAt(
            dataPath: string,
            json: string,
            fileKey: string
        ): bool {
            return root._ipcSetJson(
                dataPath,
                json,
                fileKey
            )
        }

        function updateJson(
            dataPath: string,
            json: string
        ): bool {
            return root._ipcUpdateJson(
                dataPath,
                json,
                root.defaultFileKey
            )
        }

        function updateJsonAt(
            dataPath: string,
            json: string,
            fileKey: string
        ): bool {
            return root._ipcUpdateJson(
                dataPath,
                json,
                fileKey
            )
        }

        function remove(
            dataPath: string
        ): bool {
            return root.remove(
                dataPath,
                root.defaultFileKey
            )
        }

        function removeAt(
            dataPath: string,
            fileKey: string
        ): bool {
            return root.remove(
                dataPath,
                fileKey
            )
        }

        // --------------------------------------------------------
        // Undo history
        // --------------------------------------------------------

        function undo(): bool {
            return root.undo(
                root.defaultFileKey
            )
        }

        function undoAt(
            fileKey: string
        ): bool {
            return root.undo(
                fileKey
            )
        }

        function redo(): bool {
            return root.redo(
                root.defaultFileKey
            )
        }

        function redoAt(
            fileKey: string
        ): bool {
            return root.redo(
                fileKey
            )
        }

        function revert(): bool {
            return root.revert(
                root.defaultFileKey
            )
        }

        function revertAt(
            fileKey: string
        ): bool {
            return root.revert(
                fileKey
            )
        }

        // --------------------------------------------------------
        // File control
        // --------------------------------------------------------

        function save(): bool {
            return root.save(
                root.defaultFileKey
            )
        }

        function saveAt(
            fileKey: string
        ): bool {
            return root.save(
                fileKey
            )
        }

        function reload(): bool {
            return root.reload(
                root.defaultFileKey
            )
        }

        function reloadAt(
            fileKey: string
        ): bool {
            return root.reload(
                fileKey
            )
        }

        function reloadAll(): bool {
            return root.reloadAll()
        }
    }

    // ============================================================
    // PATH HELPERS
    // ============================================================

    function _normalizeFileKey(
        fileKey
    ) {
        if (
            fileKey === undefined ||
            fileKey === null
        ) {
            return ""
        }

        return String(
            fileKey
        ).trim()
    }

    function _resolveFileKey(
        fileKey
    ) {
        const paths =
            root._paths

        if (
            fileKey === undefined ||
            fileKey === null
        ) {
            return root.defaultFileKey
        }

        const key =
            String(
                fileKey
            ).trim()

        if (
            key.length === 0
        ) {
            return root.defaultFileKey
        }

        if (
            paths[key] === undefined
        ) {
            if (
                root._warnedUnknownKeys[key] === undefined
            ) {
                const nextWarned =
                    root._copyObject(
                        root._warnedUnknownKeys
                    )

                nextWarned[key] = true

                root._warnedUnknownKeys =
                    nextWarned

                root._warn(
                    "PATH",
                    "Unknown fileKey, falling back to",
                    root.defaultFileKey + ":",
                    key
                )
            }

            return root.defaultFileKey
        }

        return key
    }

    function _controllerFor(
        fileKey
    ) {
        const registryRevision =
            root._registryRevision

        const key =
            root._resolveFileKey(
                fileKey
            )

        const controllers =
            root._controllers

        return (
            controllers[key] ||
            null
        )
    }

    function _directoryFor(
        path
    ) {
        const value =
            String(
                path || ""
            )

        const slash =
            value.lastIndexOf("/")

        if (
            slash <= 0
        ) {
            return "/"
        }

        return value.slice(
            0,
            slash
        )
    }

    function _expandPath(
        path
    ) {
        let value =
            String(
                path || ""
            ).trim()

        if (
            value.length === 0
        ) {
            return ""
        }

        if (
            value === "~"
        ) {
            return root.homeDir
        }

        if (
            value.indexOf("~/") === 0
        ) {
            value =
                root.homeDir +
                value.slice(1)
        }

        value =
            value.replace(
                /\$HOME(?=\/|$)/g,
                root.homeDir
            )

        value =
            value.replace(
                /\$\{HOME\}(?=\/|$)/g,
                root.homeDir
            )

        value =
            value.replace(
                /\$XDG_CONFIG_HOME(?=\/|$)/g,
                root.xdgConfigHome
            )

        value =
            value.replace(
                /\$\{XDG_CONFIG_HOME\}(?=\/|$)/g,
                root.xdgConfigHome
            )

        if (
            value.charAt(0) !== "/"
        ) {
            value =
                root.homeDir +
                "/" +
                value
        }

        return value
    }

    // ============================================================
    // OBJECT HELPERS
    // ============================================================

    function _isObject(
        value
    ) {
        return (
            value !== null &&
            typeof value === "object" &&
            !Array.isArray(value)
        )
    }

    function _copyObject(
        value
    ) {
        const result = {}
        const source =
            value || {}

        const keys =
            Object.keys(
                source
            )

        for (
            let i = 0;
            i < keys.length;
            ++i
        ) {
            const key =
                keys[i]

            result[key] =
                source[key]
        }

        return result
    }

    function _clone(
        value
    ) {
        if (
            value === undefined
        ) {
            return undefined
        }

        if (
            value === null
        ) {
            return null
        }

        try {
            return JSON.parse(
                JSON.stringify(
                    value
                )
            )
        } catch (error) {
            root._warn(
                "DATA",
                "Failed to clone value:",
                error
            )

            return value
        }
    }

    function _deepMerge(
        target,
        patch
    ) {
        if (
            !root._isObject(
                target
            )
        ) {
            target = {}
        }

        if (
            !root._isObject(
                patch
            )
        ) {
            return target
        }

        const keys =
            Object.keys(
                patch
            )

        for (
            let i = 0;
            i < keys.length;
            ++i
        ) {
            const key =
                keys[i]

            const patchValue =
                patch[key]

            if (
                root._isObject(
                    patchValue
                ) &&
                root._isObject(
                    target[key]
                )
            ) {
                target[key] =
                    root._deepMerge(
                        target[key],
                        patchValue
                    )
            } else {
                target[key] =
                    root._clone(
                        patchValue
                    )
            }
        }

        return target
    }

    /*
     * Semantic equality:
     * object key insertion order does not matter,
     * array order does matter.
     */
    function _equivalent(
        left,
        right
    ) {
        if (
            left === right
        ) {
            return true
        }

        if (
            left === null ||
            right === null ||
            left === undefined ||
            right === undefined
        ) {
            return false
        }

        if (
            typeof left !== "object" ||
            typeof right !== "object"
        ) {
            return left === right
        }

        const leftArray =
            Array.isArray(left)

        const rightArray =
            Array.isArray(right)

        if (
            leftArray !== rightArray
        ) {
            return false
        }

        if (
            leftArray
        ) {
            if (
                left.length !==
                right.length
            ) {
                return false
            }

            for (
                let i = 0;
                i < left.length;
                ++i
            ) {
                if (
                    !root._equivalent(
                        left[i],
                        right[i]
                    )
                ) {
                    return false
                }
            }

            return true
        }

        const leftKeys =
            Object.keys(
                left
            )

        const rightKeys =
            Object.keys(
                right
            )

        if (
            leftKeys.length !==
            rightKeys.length
        ) {
            return false
        }

        for (
            let i = 0;
            i < leftKeys.length;
            ++i
        ) {
            const key =
                leftKeys[i]

            if (
                !Object.prototype.hasOwnProperty.call(
                    right,
                    key
                )
            ) {
                return false
            }

            if (
                !root._equivalent(
                    left[key],
                    right[key]
                )
            ) {
                return false
            }
        }

        return true
    }

    // ============================================================
    // STATE HELPERS
    // ============================================================

    function _defaultFileState() {
        return {
            ready: false,
            writing: false,
            writePending: false,
            revision: 0
        }
    }

    function _stateFor(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const states =
            root._fileStates

        return (
            states[key] ||
            root._defaultFileState()
        )
    }

    /*
     * True when a local IO operation may still modify the file.
     */
    function _isWritePending(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const state =
            root._stateFor(
                key
            )

        const controller =
            root._controllerFor(
                key
            )

        return !!(
            state.writing ||
            state.writePending ||
            (
                controller &&
                (
                    controller.writeText.length > 0 ||
                    controller.queuedWriteText.length > 0
                )
            )
        )
    }

    function _isWriteDirty(
        fileKey
    ) {
        return root._isWritePending(
            fileKey
        )
    }

    function _setFileState(
        fileKey,
        patch
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const nextStates =
            root._copyObject(
                root._fileStates
            )

        const current =
            nextStates[key] ||
            root._defaultFileState()

        const nextState =
            root._copyObject(
                current
            )

        const patchKeys =
            Object.keys(
                patch || {}
            )

        for (
            let i = 0;
            i < patchKeys.length;
            ++i
        ) {
            const patchKey =
                patchKeys[i]

            nextState[patchKey] =
                patch[patchKey]
        }

        nextStates[key] =
            nextState

        root._fileStates =
            nextStates
    }

    function _setDocument(
        fileKey,
        value,
        ignoredDirty,
        emitExternal
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const normalized =
            root._isObject(
                value
            )
                ? root._clone(
                    value
                )
                : {}

        const state =
            root._stateFor(
                key
            )

        const oldDocument =
            root._documents[key]

        const changed =
            !root._equivalent(
                oldDocument,
                normalized
            )

        if (
            changed ||
            !state.ready
        ) {
            const nextDocuments =
                root._copyObject(
                    root._documents
                )

            nextDocuments[key] =
                normalized

            root._documents =
                nextDocuments

            root._setFileState(
                key,
                {
                    ready: true,
                    revision:
                        state.revision + 1
                }
            )

            root.documentUpdated(
                key
            )
        } else {
            root._setFileState(
                key,
                {
                    ready: true
                }
            )
        }

        if (
            emitExternal &&
            state.ready &&
            changed
        ) {
            root.externalReload(
                key
            )
        }

        return changed
    }

    // ============================================================
    // PATH REGISTRY CRUD
    // ============================================================

    function registerPath(
        fileKey,
        fsPath
    ) {
        const key =
            root._normalizeFileKey(
                fileKey
            )

        if (
            key.length === 0
        ) {
            root._warn(
                "PATH",
                "Refusing registerPath() with empty key."
            )

            return false
        }

        const expandedPath =
            root._expandPath(
                fsPath
            )

        if (
            expandedPath.length === 0
        ) {
            root._warn(
                "PATH",
                "Refusing empty path for:",
                key
            )

            return false
        }

        if (
            root._paths[key] !== undefined
        ) {
            if (
                root._paths[key] ===
                expandedPath
            ) {
                root._debug(
                    "PATH",
                    "Path already registered:",
                    key,
                    "->",
                    expandedPath
                )

                return true
            }

            root._warn(
                "PATH",
                "File key already exists with a different path:",
                key,
                "\nExisting:",
                root._paths[key],
                "\nRequested:",
                expandedPath
            )

            return false
        }

        const existingKeys =
            Object.keys(
                root._paths
            )

        for (
            let i = 0;
            i < existingKeys.length;
            ++i
        ) {
            const existingKey =
                existingKeys[i]

            if (
                root._paths[existingKey] ===
                expandedPath
            ) {
                root._warn(
                    "PATH",
                    "Physical path already registered:",
                    existingKey,
                    "->",
                    expandedPath
                )

                return false
            }
        }

        const nextPaths =
            root._copyObject(
                root._paths
            )

        nextPaths[key] =
            expandedPath

        root._paths =
            nextPaths

        root._pathKeys =
            Object.keys(
                nextPaths
            )

        const nextDocuments =
            root._copyObject(
                root._documents
            )

        nextDocuments[key] =
            {}

        root._documents =
            nextDocuments

        const nextStates =
            root._copyObject(
                root._fileStates
            )

        nextStates[key] =
            root._defaultFileState()

        root._fileStates =
            nextStates

        root._setHistory(
            key,
            [],
            []
        )

        root._setBaseline(
            key,
            {}
        )

        root._registryRevision += 1

        root._debug(
            "PATH",
            "Path registered:",
            key,
            "->",
            expandedPath
        )

        return true
    }

    function registerPaths(
        pathTable
    ) {
        if (
            !root._isObject(
                pathTable
            )
        ) {
            root._warn(
                "PATH",
                "registerPaths() requires an object."
            )

            return false
        }

        let success =
            true

        const keys =
            Object.keys(
                pathTable
            )

        for (
            let i = 0;
            i < keys.length;
            ++i
        ) {
            const key =
                keys[i]

            if (
                !root.registerPath(
                    key,
                    pathTable[key]
                )
            ) {
                success = false
            }
        }

        return success
    }

    function hasPath(
        fileKey
    ) {
        const key =
            root._normalizeFileKey(
                fileKey
            )

        if (
            key.length === 0
        ) {
            return false
        }

        return (
            root._paths[key] !== undefined
        )
    }

    function pathFor(
        fileKey
    ) {
        const paths =
            root._paths

        const registryRevision =
            root._registryRevision

        const key =
            root._resolveFileKey(
                fileKey
            )

        return (
            paths[key] ||
            root.defaultHomeConfigPath
        )
    }

    function updatePath(
        fileKey,
        fsPath
    ) {
        const key =
            root._normalizeFileKey(
                fileKey
            )

        if (
            key.length === 0
        ) {
            root._warn(
                "PATH",
                "Refusing updatePath() with empty key."
            )

            return false
        }

        if (
            key === root.defaultFileKey
        ) {
            root._warn(
                "PATH",
                "Refusing to update reserved default key:",
                key
            )

            return false
        }

        if (
            root._paths[key] === undefined
        ) {
            root._warn(
                "PATH",
                "Cannot update unregistered key:",
                key
            )

            return false
        }

        const expandedPath =
            root._expandPath(
                fsPath
            )

        if (
            expandedPath.length === 0
        ) {
            root._warn(
                "PATH",
                "Refusing empty path for:",
                key
            )

            return false
        }

        if (
            root._paths[key] ===
            expandedPath
        ) {
            root._debug(
                "PATH",
                "Path update is a no-op:",
                key,
                "->",
                expandedPath
            )

            return true
        }

        if (
            root.isWritingFor(key) ||
            root._isWriteDirty(key)
        ) {
            root._warn(
                "PATH",
                "Refusing path update while file is dirty/writing:",
                key
            )

            return false
        }

        const existingKeys =
            Object.keys(
                root._paths
            )

        for (
            let i = 0;
            i < existingKeys.length;
            ++i
        ) {
            const existingKey =
                existingKeys[i]

            if (
                existingKey !== key &&
                root._paths[existingKey] ===
                expandedPath
            ) {
                root._warn(
                    "PATH",
                    "Physical path already registered:",
                    existingKey,
                    "->",
                    expandedPath
                )

                return false
            }
        }

        const oldPath =
            root._paths[key]

        const nextPaths =
            root._copyObject(
                root._paths
            )

        nextPaths[key] =
            expandedPath

        root._paths =
            nextPaths

        const nextDocuments =
            root._copyObject(
                root._documents
            )

        nextDocuments[key] =
            {}

        root._documents =
            nextDocuments

        const nextStates =
            root._copyObject(
                root._fileStates
            )

        nextStates[key] =
            root._defaultFileState()

        root._fileStates =
            nextStates

        root._setHistory(
            key,
            [],
            []
        )

        root._setBaseline(
            key,
            {}
        )

        const controller =
            root._controllerFor(
                key
            )

        if (
            controller
        ) {
            controller.isDirectoryReady =
                false

            controller.writeText =
                ""

            controller.queuedWriteText =
                ""

            controller.forceReload()
        }

        root._registryRevision += 1

        root._debug(
            "PATH",
            "Path updated:",
            key,
            "\nOld:",
            oldPath,
            "\nNew:",
            expandedPath
        )

        return true
    }

    function removePath(
        fileKey
    ) {
        const key =
            root._normalizeFileKey(
                fileKey
            )

        if (
            key.length === 0
        ) {
            root._warn(
                "PATH",
                "Refusing removePath() with empty key."
            )

            return false
        }

        if (
            key === root.defaultFileKey
        ) {
            root._warn(
                "PATH",
                "Refusing to remove reserved default key:",
                key
            )

            return false
        }

        if (
            root._paths[key] === undefined
        ) {
            root._warn(
                "PATH",
                "Cannot remove unregistered key:",
                key
            )

            return false
        }

        if (
            root.isWritingFor(key) ||
            root._isWriteDirty(key)
        ) {
            root._warn(
                "PATH",
                "Refusing path removal while file is dirty/writing:",
                key
            )

            return false
        }

        const oldPath =
            root._paths[key]

        const nextPaths =
            root._copyObject(
                root._paths
            )

        delete nextPaths[key]

        root._paths =
            nextPaths

        root._pathKeys =
            Object.keys(
                nextPaths
            )

        const nextDocuments =
            root._copyObject(
                root._documents
            )

        delete nextDocuments[key]

        root._documents =
            nextDocuments

        const nextStates =
            root._copyObject(
                root._fileStates
            )

        delete nextStates[key]

        root._fileStates =
            nextStates

        const nextHistory =
            root._copyObject(
                root._history
            )

        delete nextHistory[key]

        root._history =
            nextHistory

        const nextBaselines =
            root._copyObject(
                root._baselines
            )

        delete nextBaselines[key]

        root._baselines =
            nextBaselines

        root._registryRevision += 1

        root._debug(
            "PATH",
            "Path removed:",
            key,
            "->",
            oldPath
        )

        return true
    }

    // ============================================================
    // DOCUMENT / STATE API
    // ============================================================

    function documentFor(
        fileKey
    ) {
        const documents =
            root._documents

        const registryRevision =
            root._registryRevision

        const key =
            root._resolveFileKey(
                fileKey
            )

        if (
            documents[key] !== undefined
        ) {
            /*
             * Return a snapshot so callers cannot mutate the store
             * without going through set()/update()/remove()/
             * undo()/redo()/revert() (history + revision + write).
             */
            return root._clone(
                documents[key]
            ) || {}
        }

        return {}
    }

    function isReadyFor(
        fileKey
    ) {
        const states =
            root._fileStates

        const registryRevision =
            root._registryRevision

        const key =
            root._resolveFileKey(
                fileKey
            )

        const state =
            states[key]

        return (
            state
                ? !!state.ready
                : false
        )
    }

    function isWritingFor(
        fileKey
    ) {
        const states =
            root._fileStates

        const registryRevision =
            root._registryRevision

        const key =
            root._resolveFileKey(
                fileKey
            )

        const state =
            states[key]

        return (
            state
                ? !!state.writing
                : false
        )
    }

    function isDirtyFor(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        return !root._equivalent(
            root.documentFor(
                key
            ),
            root._baselineFor(
                key
            )
        )
    }

    function revisionFor(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const state =
            root._fileStates[key]

        return (
            state
                ? state.revision
                : 0
        )
    }

    // ============================================================
    // LOAD HANDLING
    // ============================================================

    function _parseLoadedDocument(
        fileView
    ) {
        const text =
            fileView.text()

        if (
            !text ||
            text.trim().length === 0
        ) {
            return {}
        }

        const parsed =
            JSON.parse(
                text
            )

        if (
            !root._isObject(
                parsed
            )
        ) {
            throw new Error(
                "config root must be a JSON object"
            )
        }

        return parsed
    }

    function _handleLoaded(
        controller,
        fileView
    ) {
        const key =
            controller.fileKey

        const state =
            root._stateFor(
                key
            )

        const isExplicit =
            controller.explicitReloadPending

        controller.explicitReloadPending =
            false

        if (
            !isExplicit &&
            root._isWritePending(
                key
            )
        ) {
            root._debug(
                "LOAD",
                "Ignoring load while local write pipeline is active:",
                key
            )

            return
        }

        let parsed

        try {
            parsed =
                root._parseLoadedDocument(
                    fileView
                )
        } catch (error) {
            root._warn(
                "LOAD",
                "Invalid JSON:",
                key,
                "->",
                controller.filePath,
                error
            )

            if (
                !state.ready
            ) {
                root._setDocument(
                    key,
                    {},
                    false,
                    false
                )

                root._setBaseline(
                    key,
                    {}
                )

                root._clearHistory(
                    key
                )
            }

            return
        }

        controller.isDirectoryReady =
            true

        const oldDocument =
            root.documentFor(
                key
            )

        /*
         * First successful load:
         * disk becomes clean baseline.
         */
        if (
            !state.ready
        ) {
            root._setDocument(
                key,
                parsed,
                false,
                false
            )

            root._setBaseline(
                key,
                parsed
            )

            root._clearHistory(
                key
            )

            return
        }

        /*
         * Explicit reload:
         * discard local state and trust disk.
         */
        if (
            isExplicit
        ) {
            root._setDocument(
                key,
                parsed,
                false,
                false
            )

            root._setBaseline(
                key,
                parsed
            )

            root._clearHistory(
                key
            )

            return
        }

        /*
         * Watcher reload.
         *
         * If the file is byte/semantically identical,
         * do nothing.
         *
         * A real external change becomes a history entry.
         * The baseline stays where it was.
         */
        if (
            root._equivalent(
                oldDocument,
                parsed
            )
        ) {
            return
        }

        const entry =
            root._makeHistoryEntry(
                oldDocument,
                parsed,
                "externalReload",
                ""
            )

        root._pushHistoryEntry(
            key,
            entry
        )

        root._setDocument(
            key,
            parsed,
            false,
            true
        )
    }

    function _handleLoadFailed(
        controller,
        error
    ) {
        const key =
            controller.fileKey

        const state =
            root._stateFor(
                key
            )

        const isExplicit =
            controller.explicitReloadPending

        controller.explicitReloadPending =
            false

        if (
            error ===
            FileViewError.FileNotFound
        ) {
            root._debug(
                "LOAD",
                "Config file not found:",
                key,
                "->",
                controller.filePath
            )

            if (
                !state.ready
            ) {
                controller.isDirectoryReady =
                    false

                root._setDocument(
                    key,
                    {},
                    false,
                    false
                )

                root._setBaseline(
                    key,
                    {}
                )

                root._clearHistory(
                    key
                )

                if (
                    key === root.defaultFileKey
                ) {
                    controller.queueSave()
                }

                return
            }

            if (
                isExplicit
            ) {
                controller.isDirectoryReady =
                    false

                root._setDocument(
                    key,
                    {},
                    false,
                    false
                )

                root._setBaseline(
                    key,
                    {}
                )

                root._clearHistory(
                    key
                )

                return
            }

            /*
             * Existing file disappeared externally.
             */
            const oldDocument =
                root.documentFor(
                    key
                )

            if (
                root._equivalent(
                    oldDocument,
                    {}
                )
            ) {
                return
            }

            const entry =
                root._makeHistoryEntry(
                    oldDocument,
                    {},
                    "externalReload",
                    ""
                )

            root._pushHistoryEntry(
                key,
                entry
            )

            controller.isDirectoryReady =
                false

            root._setDocument(
                key,
                {},
                false,
                true
            )

            return
        }

        const reason =
            FileViewError.toString(
                error
            )

        root._warn(
            "LOAD",
            "Failed to load:",
            key,
            "->",
            controller.filePath,
            reason
        )

        if (
            !state.ready
        ) {
            root._setDocument(
                key,
                {},
                false,
                false
            )

            root._setBaseline(
                key,
                {}
            )

            root._clearHistory(
                key
            )
        }
    }

    // ============================================================
    // READ API
    // ============================================================

    function get(
        dataPath,
        fallbackValue,
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        if (
            !dataPath ||
            String(
                dataPath
            ).length === 0
        ) {
            return fallbackValue
        }

        let current =
            root.documentFor(
                key
            )

        const parts =
            String(
                dataPath
            ).split(".")

        for (
            let i = 0;
            i < parts.length;
            ++i
        ) {
            const part =
                parts[i]

            if (
                current === null ||
                current === undefined ||
                typeof current !== "object" ||
                !(part in current)
            ) {
                return fallbackValue
            }

            current =
                current[part]
        }

        return current
    }

    function has(
        dataPath,
        fileKey
    ) {
        const missing = {}

        return (
            root.get(
                dataPath,
                missing,
                fileKey
            ) !== missing
        )
    }

    // ============================================================
    // PATH VALUE HELPERS
    // ============================================================

    function _valueAt(
        value,
        dataPath
    ) {
        if (
            !dataPath ||
            String(
                dataPath
            ).length === 0
        ) {
            return {
                exists: true,
                value: value
            }
        }

        let current =
            value

        const parts =
            String(
                dataPath
            ).split(".")

        for (
            let i = 0;
            i < parts.length;
            ++i
        ) {
            const part =
                parts[i]

            if (
                current === null ||
                current === undefined ||
                typeof current !== "object" ||
                !Object.prototype.hasOwnProperty.call(
                    current,
                    part
                )
            ) {
                return {
                    exists: false,
                    value: undefined
                }
            }

            current =
                current[part]
        }

        return {
            exists: true,
            value: current
        }
    }

    function _setPathValue(
        document,
        dataPath,
        value
    ) {
        if (
            !dataPath ||
            String(
                dataPath
            ).length === 0
        ) {
            return false
        }

        const parts =
            String(
                dataPath
            ).split(".")

        let current =
            document

        for (
            let i = 0;
            i < parts.length - 1;
            ++i
        ) {
            const part =
                parts[i]

            if (
                current[part] === null ||
                current[part] === undefined ||
                typeof current[part] !== "object"
            ) {
                current[part] = {}
            }

            current =
                current[part]
        }

        current[
            parts[
                parts.length - 1
            ]
        ] =
            root._clone(
                value
            )

        return true
    }

    function _removePathValue(
        document,
        dataPath
    ) {
        if (
            !dataPath ||
            String(
                dataPath
            ).length === 0
        ) {
            return false
        }

        const parts =
            String(
                dataPath
            ).split(".")

        let current =
            document

        for (
            let i = 0;
            i < parts.length - 1;
            ++i
        ) {
            const part =
                parts[i]

            if (
                current === null ||
                current === undefined ||
                typeof current !== "object" ||
                !Object.prototype.hasOwnProperty.call(
                    current,
                    part
                )
            ) {
                return false
            }

            current =
                current[part]
        }

        const finalKey =
            parts[
                parts.length - 1
            ]

        if (
            current === null ||
            current === undefined ||
            typeof current !== "object" ||
            !Object.prototype.hasOwnProperty.call(
                current,
                finalKey
            )
        ) {
            return false
        }

        delete current[
            finalKey
        ]

        return true
    }

    // ============================================================
    // HISTORY DIFFS
    // ============================================================

    function _pushDiffChange(
        changes,
        path,
        beforeState,
        afterState
    ) {
        changes.push({
            path: path,

            beforeExists:
                !!beforeState.exists,

            beforeValue:
                beforeState.exists
                    ? root._clone(
                        beforeState.value
                    )
                    : undefined,

            afterExists:
                !!afterState.exists,

            afterValue:
                afterState.exists
                    ? root._clone(
                        afterState.value
                    )
                    : undefined
        })
    }

    function _collectDiff(
        before,
        after,
        path,
        changes
    ) {
        if (
            root._equivalent(
                before,
                after
            )
        ) {
            return
        }

        const beforeObject =
            root._isObject(
                before
            )

        const afterObject =
            root._isObject(
                after
            )

        if (
            beforeObject &&
            afterObject
        ) {
            const keys = {}

            const beforeKeys =
                Object.keys(
                    before
                )

            const afterKeys =
                Object.keys(
                    after
                )

            for (
                let i = 0;
                i < beforeKeys.length;
                ++i
            ) {
                keys[
                    beforeKeys[i]
                ] = true
            }

            for (
                let i = 0;
                i < afterKeys.length;
                ++i
            ) {
                keys[
                    afterKeys[i]
                ] = true
            }

            const allKeys =
                Object.keys(
                    keys
                )

            for (
                let i = 0;
                i < allKeys.length;
                ++i
            ) {
                const key =
                    allKeys[i]

                const childPath =
                    path.length > 0
                        ? path + "." + key
                        : key

                const beforeState =
                    Object.prototype.hasOwnProperty.call(
                        before,
                        key
                    )
                        ? {
                            exists: true,
                            value: before[key]
                        }
                        : {
                            exists: false,
                            value: undefined
                        }

                const afterState =
                    Object.prototype.hasOwnProperty.call(
                        after,
                        key
                    )
                        ? {
                            exists: true,
                            value: after[key]
                        }
                        : {
                            exists: false,
                            value: undefined
                        }

                if (
                    beforeState.exists &&
                    afterState.exists &&
                    root._isObject(
                        beforeState.value
                    ) &&
                    root._isObject(
                        afterState.value
                    )
                ) {
                    root._collectDiff(
                        beforeState.value,
                        afterState.value,
                        childPath,
                        changes
                    )
                } else if (
                    !beforeState.exists ||
                    !afterState.exists ||
                    !root._equivalent(
                        beforeState.value,
                        afterState.value
                    )
                ) {
                    root._pushDiffChange(
                        changes,
                        childPath,
                        beforeState,
                        afterState
                    )
                }
            }

            return
        }

        root._pushDiffChange(
            changes,
            path || "$",
            {
                exists: true,
                value: before
            },
            {
                exists: true,
                value: after
            }
        )
    }

    function _makeHistoryEntry(
        beforeDocument,
        afterDocument,
        op,
        dataPath
    ) {
        let changes = []

        if (
            dataPath &&
            String(
                dataPath
            ).length > 0
        ) {
            root._pushDiffChange(
                changes,
                String(
                    dataPath
                ),
                root._valueAt(
                    beforeDocument,
                    dataPath
                ),
                root._valueAt(
                    afterDocument,
                    dataPath
                )
            )
        } else {
            root._collectDiff(
                beforeDocument,
                afterDocument,
                "",
                changes
            )
        }

        return {
            op:
                String(
                    op || ""
                ),

            dataPath:
                String(
                    dataPath || ""
                ),

            changeCount:
                changes.length,

            changes:
                changes
        }
    }

    function _describeEntry(
        entry
    ) {
        if (
            !entry
        ) {
            return {
                op: "",
                dataPath: "",
                changeCount: 0,
                changes: []
            }
        }

        const changes = []
        const source =
            entry.changes || []

        for (
            let i = 0;
            i < source.length;
            ++i
        ) {
            const change =
                source[i]

            changes.push({
                path:
                    String(
                        change.path || ""
                    ),

                beforeExists:
                    !!change.beforeExists,

                beforeValue:
                    change.beforeExists
                        ? root._clone(
                            change.beforeValue
                        )
                        : undefined,

                afterExists:
                    !!change.afterExists,

                afterValue:
                    change.afterExists
                        ? root._clone(
                            change.afterValue
                        )
                        : undefined
            })
        }

        return {
            op:
                String(
                    entry.op || ""
                ),

            dataPath:
                String(
                    entry.dataPath || ""
                ),

            changeCount:
                changes.length,

            changes:
                changes
        }
    }

    function _historyFor(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const history =
            root._history[key]

        return {
            past:
                history &&
                history.past
                    ? history.past
                    : [],

            future:
                history &&
                history.future
                    ? history.future
                    : []
        }
    }

    function _setHistory(
        fileKey,
        past,
        future
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const nextHistory =
            root._copyObject(
                root._history
            )

        nextHistory[key] = {
            past:
                (
                    past ||
                    []
                ).slice(),

            future:
                (
                    future ||
                    []
                ).slice()
        }

        root._history =
            nextHistory
    }

    function _trimHistory(
        past,
        future
    ) {
        let nextPast =
            (
                past ||
                []
            ).slice()

        let nextFuture =
            (
                future ||
                []
            ).slice()

        const limit =
            Math.max(
                1,
                root.historyLimit
            )

        while (
            nextPast.length +
            nextFuture.length >
            limit
        ) {
            /*
             * Preserve redo: discard the oldest undo first.
             * Only when past is empty may future be trimmed.
             */
            if (
                nextPast.length > 0
            ) {
                nextPast.shift()
            } else {
                nextFuture.shift()
            }
        }

        return {
            past:
                nextPast,

            future:
                nextFuture
        }
    }

    function _pushHistoryEntry(
        fileKey,
        entry
    ) {
        const slots =
            root._historyFor(
                fileKey
            )

        const past =
            slots.past.slice()

        past.push(
            entry
        )

        /*
         * New mutation invalidates redo.
         */
        const trimmed =
            root._trimHistory(
                past,
                []
            )

        root._setHistory(
            fileKey,
            trimmed.past,
            trimmed.future
        )
    }

    function _clearHistory(
        fileKey
    ) {
        root._setHistory(
            fileKey,
            [],
            []
        )
    }

    function _baselineFor(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const baselines =
            root._baselines

        if (
            baselines[key] === undefined
        ) {
            return {}
        }

        return root._clone(
            baselines[key]
        )
    }

    function _setBaseline(
        fileKey,
        document
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const nextBaselines =
            root._copyObject(
                root._baselines
            )

        nextBaselines[key] =
            root._clone(
                document
            ) || {}

        root._baselines =
            nextBaselines
    }

    function historyAt(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const slots =
            root._historyFor(
                key
            )

        const past = []
        const future = []

        for (
            let i = 0;
            i < slots.past.length;
            ++i
        ) {
            past.push(
                root._describeEntry(
                    slots.past[i]
                )
            )
        }

        /*
         * The next redo is the first public future item.
         */
        for (
            let i =
                slots.future.length - 1;
            i >= 0;
            --i
        ) {
            future.push(
                root._describeEntry(
                    slots.future[i]
                )
            )
        }

        return {
            past:
                past,

            future:
                future,

            canUndo:
                slots.past.length > 0,

            canRedo:
                slots.future.length > 0,

            count:
                slots.past.length +
                slots.future.length,

            limit:
                root.historyLimit,

            isDirty:
                root.isDirtyFor(
                    key
                )
        }
    }

    function historyFor(
        fileKey
    ) {
        return root.historyAt(
            fileKey
        )
    }

    function _applyHistoryEntry(
        document,
        entry,
        useBefore
    ) {
        const result =
            root._clone(
                document
            )

        const changes =
            entry &&
            entry.changes
                ? entry.changes
                : []

        for (
            let i = 0;
            i < changes.length;
            ++i
        ) {
            const change =
                changes[i]

            const exists =
                useBefore
                    ? !!change.beforeExists
                    : !!change.afterExists

            const value =
                useBefore
                    ? change.beforeValue
                    : change.afterValue

            if (
                change.path === "$" &&
                !exists
            ) {
                return {}
            }

            if (
                change.path === "$" &&
                exists
            ) {
                return (
                    root._clone(
                        value
                    ) || {}
                )
            }

            if (
                exists
            ) {
                root._setPathValue(
                    result,
                    change.path,
                    value
                )
            } else {
                root._removePathValue(
                    result,
                    change.path
                )
            }
        }

        return result
    }

    // ============================================================
    // DOCUMENT COMMIT / MUTATION
    // ============================================================

    function _commitDocument(
        key,
        nextDocument,
        label,
        dataPath
    ) {
        const current =
            root.documentFor(
                key
            )

        const normalized =
            root._isObject(
                nextDocument
            )
                ? root._clone(
                    nextDocument
                )
                : {}

        if (
            root._equivalent(
                current,
                normalized
            )
        ) {
            return true
        }

        const controller =
            root._controllerFor(
                key
            )

        /*
         * Any mutation after save() cancels the pending
         * clean-baseline commit.
         */
        if (
            controller
        ) {
            controller.completeSaveWhenIdle =
                false
        }

        const state =
            root._stateFor(
                key
            )

        root._setFileState(
            key,
            {
                writePending: true
            }
        )

        const nextDocuments =
            root._copyObject(
                root._documents
            )

        nextDocuments[key] =
            normalized

        root._documents =
            nextDocuments

        root._setFileState(
            key,
            {
                ready: true,
                revision:
                    state.revision + 1
            }
        )

        root._debug(
            "WRITE",
            label,
            key,
            "->",
            dataPath,
            "revision:",
            state.revision + 1
        )

        root.documentUpdated(
            key
        )

        if (
            !controller
        ) {
            return true
        }

        const queued =
            controller.queueSave()

        if (
            !queued
        ) {
            root._setFileState(
                key,
                {
                    writePending: false
                }
            )
        }

        return queued
    }

    function set(
        dataPath,
        value,
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        if (
            !dataPath ||
            String(
                dataPath
            ).length === 0
        ) {
            root._warn(
                "WRITE",
                "Refusing empty set() path."
            )

            return false
        }

        if (
            value === undefined
        ) {
            root._warn(
                "WRITE",
                "Refusing set() with undefined value:",
                key,
                "->",
                dataPath
            )

            return false
        }

        const before =
            root.documentFor(
                key
            )

        const after =
            root._clone(
                before
            )

        if (
            !root._setPathValue(
                after,
                dataPath,
                value
            )
        ) {
            return false
        }

        if (
            root._equivalent(
                before,
                after
            )
        ) {
            return true
        }

        root._pushHistoryEntry(
            key,
            root._makeHistoryEntry(
                before,
                after,
                "set",
                dataPath
            )
        )

        return root._commitDocument(
            key,
            after,
            "set()",
            dataPath
        )
    }

    function update(
        dataPath,
        value,
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        if (
            !dataPath ||
            String(
                dataPath
            ).length === 0
        ) {
            root._warn(
                "WRITE",
                "Refusing empty update() path."
            )

            return false
        }

        if (
            !root._isObject(
                value
            )
        ) {
            root._warn(
                "WRITE",
                "update() requires an object."
            )

            return false
        }

        const before =
            root.documentFor(
                key
            )

        const currentValue =
            root._valueAt(
                before,
                dataPath
            )

        const merged =
            root._deepMerge(
                currentValue.exists &&
                root._isObject(
                    currentValue.value
                )
                    ? root._clone(
                        currentValue.value
                    )
                    : {},
                value
            )

        const after =
            root._clone(
                before
            )

        if (
            !root._setPathValue(
                after,
                dataPath,
                merged
            )
        ) {
            return false
        }

        if (
            root._equivalent(
                before,
                after
            )
        ) {
            return true
        }

        root._pushHistoryEntry(
            key,
            root._makeHistoryEntry(
                before,
                after,
                "update",
                dataPath
            )
        )

        return root._commitDocument(
            key,
            after,
            "update()",
            dataPath
        )
    }

    function remove(
        dataPath,
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        if (
            !dataPath ||
            String(
                dataPath
            ).length === 0
        ) {
            root._warn(
                "WRITE",
                "Refusing empty remove() path."
            )

            return false
        }

        const before =
            root.documentFor(
                key
            )

        const after =
            root._clone(
                before
            )

        if (
            !root._removePathValue(
                after,
                dataPath
            )
        ) {
            return false
        }

        root._pushHistoryEntry(
            key,
            root._makeHistoryEntry(
                before,
                after,
                "remove",
                dataPath
            )
        )

        return root._commitDocument(
            key,
            after,
            "remove()",
            dataPath
        )
    }

    // ============================================================
    // UNDO / REDO / REVERT
    // ============================================================

    function undo(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const state =
            root._stateFor(
                key
            )

        if (
            !state.ready
        ) {
            root._warn(
                "WRITE",
                "undo() requested before configuration is ready:",
                key
            )

            return false
        }

        const slots =
            root._historyFor(
                key
            )

        if (
            slots.past.length === 0
        ) {
            return false
        }

        const current =
            root.documentFor(
                key
            )

        /*
         * Compute first so a no-op undo still advances the
         * stack without touching disk/revision.
         */
        const entry =
            slots.past[
                slots.past.length - 1
            ]

        const nextDocument =
            root._applyHistoryEntry(
                current,
                entry,
                true
            )

        const past =
            slots.past.slice()

        const future =
            slots.future.slice()

        /*
         * This exact entry is moved to future.
         */
        past.pop()

        future.push(
            entry
        )

        const trimmed =
            root._trimHistory(
                past,
                future
            )

        root._setHistory(
            key,
            trimmed.past,
            trimmed.future
        )

        const controller =
            root._controllerFor(
                key
            )

        if (
            controller
        ) {
            controller.completeSaveWhenIdle =
                false
        }

        /*
         * No-op undo: history already advanced, disk already
         * matches, no revision/signal/write needed.
         */
        if (
            root._equivalent(
                current,
                nextDocument
            )
        ) {
            return true
        }

        return root._commitDocument(
            key,
            nextDocument,
            "undo()",
            entry.dataPath
        )
    }

    function redo(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const state =
            root._stateFor(
                key
            )

        if (
            !state.ready
        ) {
            root._warn(
                "WRITE",
                "redo() requested before configuration is ready:",
                key
            )

            return false
        }

        const slots =
            root._historyFor(
                key
            )

        if (
            slots.future.length === 0
        ) {
            return false
        }

        const current =
            root.documentFor(
                key
            )

        /*
         * Compute first so a no-op redo still advances the
         * stack without touching disk/revision.
         */
        const entry =
            slots.future[
                slots.future.length - 1
            ]

        const nextDocument =
            root._applyHistoryEntry(
                current,
                entry,
                false
            )

        const past =
            slots.past.slice()

        const future =
            slots.future.slice()

        /*
         * This exact entry is moved back to past.
         */
        future.pop()

        past.push(
            entry
        )

        const trimmed =
            root._trimHistory(
                past,
                future
            )

        root._setHistory(
            key,
            trimmed.past,
            trimmed.future
        )

        const controller =
            root._controllerFor(
                key
            )

        if (
            controller
        ) {
            controller.completeSaveWhenIdle =
                false
        }

        /*
         * No-op redo: history already advanced, disk already
         * matches, no revision/signal/write needed.
         */
        if (
            root._equivalent(
                current,
                nextDocument
            )
        ) {
            return true
        }

        return root._commitDocument(
            key,
            nextDocument,
            "redo()",
            entry.dataPath
        )
    }

    function revert(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const state =
            root._stateFor(
                key
            )

        if (
            !state.ready
        ) {
            root._warn(
                "WRITE",
                "revert() requested before configuration is ready:",
                key
            )

            return false
        }

        const slots =
            root._historyFor(
                key
            )

        const current =
            root.documentFor(
                key
            )

        const baseline =
            root._baselineFor(
                key
            )

        const dirty =
            !root._equivalent(
                current,
                baseline
            )

        /*
         * Nothing to undo and already clean:
         * true no-op, no IO, no revision, no signals.
         * Still wipe any stray future (undo-to-clean case is
         * handled below).
         */
        if (
            slots.past.length === 0 &&
            !dirty
        ) {
            if (
                slots.future.length === 0
            ) {
                return false
            }

            /*
             * Undone-to-clean with redo available:
             * revert is a true checkpoint wipe, no disk write.
             */
            root._clearHistory(
                key
            )

            const controllerForWipe =
                root._controllerFor(
                    key
                )

            if (
                controllerForWipe
            ) {
                controllerForWipe.completeSaveWhenIdle =
                    false
            }

            return true
        }

        /*
         * Revert logic is undo-all:
         * applying every past before-value in reverse yields
         * the clean state. Walk it explicitly so the result
         * matches N sequential undo() calls.
         *
         * Coalesced to a single commit for a single write
         * and single revision. Baseline is authoritative when
         * history was trimmed (walk would only partially
         * revert).
         */
        let restored =
            root._clone(
                current
            )

        for (
            let i =
                slots.past.length - 1;
            i >= 0;
            --i
        ) {
            restored =
                root._applyHistoryEntry(
                    restored,
                    slots.past[i],
                    true
                )
        }

        if (
            !root._equivalent(
                restored,
                baseline
            )
        ) {
            restored =
                root._clone(
                    baseline
                )
        }

        /*
         * Revert must kill the undo/redo graph immediately
         * and cancels any pending save checkpoint.
         */
        root._clearHistory(
            key
        )

        const controller =
            root._controllerFor(
                key
            )

        if (
            controller
        ) {
            controller.completeSaveWhenIdle =
                false
        }

        /*
         * History wiped but document already clean
         * (e.g. dirty flag came only from history):
         * checkpoint without IO.
         */
        if (
            root._equivalent(
                current,
                restored
            )
        ) {
            return true
        }

        return root._commitDocument(
            key,
            restored,
            "revert()",
            ""
        )
    }

    // ============================================================
    // FILE CONTROL
    // ============================================================

    function save(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const state =
            root._stateFor(
                key
            )

        if (
            !state.ready
        ) {
            root._warn(
                "WRITE",
                "save() requested before configuration is ready:",
                key
            )

            return false
        }

        const current =
            root.documentFor(
                key
            )

        const baseline =
            root._baselineFor(
                key
            )

        const dirty =
            !root._equivalent(
                current,
                baseline
            )

        /*
         * True checkpoint: when already clean, never touch disk.
         * Still wipe any leftover undo/redo graph (e.g. undo-to-clean
         * leaves redo available) so save() is a full checkpoint.
         */
        if (
            !dirty
        ) {
            const slots =
                root._historyFor(
                    key
                )

            if (
                slots.past.length === 0 &&
                slots.future.length === 0
            ) {
                return true
            }

            root._clearHistory(
                key
            )

            return true
        }

        const controller =
            root._controllerFor(
                key
            )

        if (
            !controller
        ) {
            root._warn(
                "WRITE",
                "save() has no controller:",
                key
            )

            return false
        }

        /*
         * Dirty from here. Autosave already queued a write for the
         * current document via _commitDocument.
         *
         * - Pipeline active: checkpoint when idle. The queued newest
         *   write wins; baseline/history reset in onSaved.
         * - Idle + last write failed: disk is stale, force rewrite.
         * - Idle + disk already matches: checkpoint synchronously
         *   with no IO. A same-content FileView.setText may never
         *   emit onSaved, which would strand writing=true forever.
         */
        if (
            root._isWritePending(
                key
            )
        ) {
            controller.completeSaveWhenIdle =
                true

            const pendingResult =
                controller.queueSave()

            if (
                !pendingResult
            ) {
                controller.completeSaveWhenIdle =
                    false
            }

            return pendingResult
        }

        if (
            controller.writeFailed
        ) {
            controller.completeSaveWhenIdle =
                true

            const retryResult =
                controller.queueSave()

            if (
                !retryResult
            ) {
                controller.completeSaveWhenIdle =
                    false

                root._setFileState(
                    key,
                    {
                        writePending: false
                    }
                )
            }

            return retryResult
        }

        root._setBaseline(
            key,
            current
        )

        root._clearHistory(
            key
        )

        root._debug(
            "WRITE",
            "Save checkpoint (no write needed):",
            key
        )

        return true
    }

    function reload(
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const controller =
            root._controllerFor(
                key
            )

        if (
            !controller
        ) {
            root._warn(
                "LOAD",
                "reload() has no controller:",
                key
            )

            return false
        }

        if (
            root._isWritePending(
                key
            )
        ) {
            root._warn(
                "LOAD",
                "Reload rejected while write pipeline is active:",
                key
            )

            return false
        }

        controller.completeSaveWhenIdle =
            false

        controller.explicitReloadPending =
            true

        return controller.forceReload()
    }

    function reloadAll() {
        const keys =
            root._pathKeys

        let success =
            true

        for (
            let i = 0;
            i < keys.length;
            ++i
        ) {
            const key =
                keys[i]

            const controller =
                root._controllerFor(
                    key
                )

            if (
                !controller
            ) {
                success = false
                continue
            }

            if (
                root._isWritePending(
                    key
                )
            ) {
                root._warn(
                    "LOAD",
                    "Skipping reload while write pipeline is active:",
                    key
                )

                success = false
                continue
            }

            controller.completeSaveWhenIdle =
                false

            controller.explicitReloadPending =
                true

            if (
                !controller.forceReload()
            ) {
                success = false
            }
        }

        return success
    }

    // ============================================================
    // IPC HELPERS
    // ============================================================

    function _ipcGet(
        dataPath,
        fileKey
    ) {
        const value =
            root.get(
                dataPath,
                undefined,
                fileKey
            )

        if (
            value === undefined
        ) {
            return ""
        }

        try {
            return JSON.stringify(
                value
            )
        } catch (error) {
            root._warn(
                "IPC",
                "Failed to serialize IPC result:",
                error
            )

            return ""
        }
    }

    function _ipcSetJson(
        dataPath,
        json,
        fileKey
    ) {
        try {
            const value =
                JSON.parse(
                    json
                )

            return root.set(
                dataPath,
                value,
                fileKey
            )
        } catch (error) {
            root._warn(
                "IPC",
                "Invalid JSON in setJson():",
                error
            )

            return false
        }
    }

    function _ipcUpdateJson(
        dataPath,
        json,
        fileKey
    ) {
        try {
            const value =
                JSON.parse(
                    json
                )

            if (
                value === null ||
                typeof value !== "object" ||
                Array.isArray(value)
            ) {
                root._warn(
                    "IPC",
                    "updateJson() requires a JSON object."
                )

                return false
            }

            return root.update(
                dataPath,
                value,
                fileKey
            )
        } catch (error) {
            root._warn(
                "IPC",
                "Invalid JSON in updateJson():",
                error
            )

            return false
        }
    }

    function _ipcGetDocument(
        fileKey
    ) {
        const document =
            root.documentFor(
                fileKey
            )

        try {
            return JSON.stringify(
                document
            )
        } catch (error) {
            root._warn(
                "IPC",
                "Failed to serialize document:",
                error
            )

            return ""
        }
    }

    function _ipcHistory(
        fileKey
    ) {
        try {
            return JSON.stringify(
                root.historyAt(
                    fileKey
                )
            )
        } catch (error) {
            root._warn(
                "IPC",
                "Failed to serialize history:",
                error
            )

            return ""
        }
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

    // ============================================================
    // STARTUP
    // ============================================================

    Component.onCompleted: {
        root._debug(
            "LOAD",
            "ConfigStore initialized.",
            "default:",
            root.defaultFileKey,
            "->",
            root.defaultHomeConfigPath
        )
    }
}