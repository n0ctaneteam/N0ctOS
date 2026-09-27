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
    property bool debugLogging: true

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

    /*
     * Logical key -> resolved physical path.
     *
     * homeConfig is always present.
     */
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

    /*
     * Incremented whenever the registered path/controller set
     * changes.
     *
     * This gives functions such as _controllerFor() and pathFor()
     * an explicit reactive dependency.
     */
    property int _registryRevision: 0

    // ============================================================
    // REACTIVE DOCUMENT STATE
    // ============================================================

    /*
     * fileKey -> document
     */
    property var _documents: ({
        homeConfig: {}
    })

    readonly property var documents:
        root._documents

    /*
     * Backwards-compatible default document.
     *
     * QML automatically generates documentChanged() for this
     * property. Therefore the store MUST NOT declare a custom
     * documentChanged signal.
     */
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
     *     dirty: bool,
     *     revision: int
     * }
     */
    property var _fileStates: ({
        homeConfig: {
            ready: false,
            writing: false,
            dirty: false,
            revision: 0
        }
    })

    // ============================================================
    // DEFAULT FILE STATE
    // ============================================================

    readonly property bool ready:
        root.readyFor(
            root.defaultFileKey
        )

    readonly property bool writing:
        root.writingFor(
            root.defaultFileKey
        )

    readonly property bool dirty:
        root.dirtyFor(
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

    /*
     * fileKey -> controller
     *
     * The actual FileView / timer / Process objects live inside
     * these controllers.
     */
    property var _controllers: ({})

    // ============================================================
    // SIGNALS
    // ============================================================

    /*
     * Do NOT rename documentUpdated() to documentChanged().
     *
     * "documentChanged" already belongs to the `document` property.
     */
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

            /*
             * Invisible resource container.
             *
             * Item is intentionally used instead of QtObject because
             * this delegate contains Timer, Process and FileView
             * children.
             */
            visible: false
            width: 0
            height: 0

            // ====================================================
            // IDENTITY
            // ====================================================

            required property var modelData

            readonly property string fileKey:
                String(modelData)

            readonly property string filePath:
                root._paths[controller.fileKey] ||
                root.defaultHomeConfigPath

            // ====================================================
            // DIRECTORY STATE
            // ====================================================

            property bool directoryReady:
                false

            // ====================================================
            // WRITE STATE
            // ====================================================

            property string writeText:
                ""

            property string queuedWriteText:
                ""

            // ====================================================
            // EXTERNAL RELOAD DEBOUNCE
            // ====================================================

            Timer {
                id: reloadDebounce

                interval: 80
                repeat: false

                onTriggered: {
                    if (
                        root.writingFor(
                            controller.fileKey
                        )
                    ) {
                        root._debug(
                            "WATCH",
                            "Reload suppressed while writing:",
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

            // ====================================================
            // DIRECTORY CREATION
            // ====================================================

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

                        /*
                         * Preserve the newest pending document.
                         *
                         * If a newer queued write exists, do not replace
                         * it with the older active write.
                         */
                        if (
                            controller.queuedWriteText.length === 0 &&
                            controller.writeText.length > 0
                        ) {
                            controller.queuedWriteText =
                                controller.writeText
                        }

                        controller.writeText =
                            ""

                        root._setFileState(
                            controller.fileKey,
                            {
                                writing: false,
                                dirty: true
                            }
                        )

                        root.saveError(
                            controller.fileKey,
                            "failed to create parent directory"
                        )

                        return
                    }

                    controller.directoryReady =
                        true

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

            // ====================================================
            // FILE
            // ====================================================

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
                    root._debug(
                        "LOAD",
                        "File loaded:",
                        controller.fileKey,
                        "->",
                        controller.filePath
                    )

                    root._handleLoaded(
                        controller,
                        configFile
                    )
                }

                // ------------------------------------------------
                // FILE WATCHER
                // ------------------------------------------------

                onFileChanged: {
                    root._debug(
                        "WATCH",
                        "Filesystem change detected:",
                        controller.fileKey,
                        "->",
                        controller.filePath
                    )

                    /*
                     * Ignore changes caused by our own write while
                     * the write pipeline is still active.
                     */
                    if (
                        root.writingFor(
                            controller.fileKey
                        )
                    ) {
                        root._debug(
                            "WATCH",
                            "Ignoring watcher event from active write:",
                            controller.fileKey
                        )

                        return
                    }

                    /*
                     * Coalesce rapid editor / atomic-write events.
                     */
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
                    root._debug(
                        "WRITE",
                        "Write completed:",
                        controller.fileKey,
                        "->",
                        controller.filePath
                    )

                    root._setFileState(
                        controller.fileKey,
                        {
                            ready: true,
                            writing: false
                        }
                    )

                    controller.writeText =
                        ""

                    /*
                     * A newer document may have been produced while
                     * the previous write was active.
                     */
                    if (
                        controller.queuedWriteText.length > 0
                    ) {
                        const nextText =
                            controller.queuedWriteText

                        controller.queuedWriteText =
                            ""

                        root._debug(
                            "WRITE",
                            "Writing queued latest state:",
                            controller.fileKey
                        )

                        controller._startWrite(
                            nextText
                        )

                        return
                    }

                    root._setFileState(
                        controller.fileKey,
                        {
                            ready: true,
                            writing: false,
                            dirty: false
                        }
                    )
                }

                // ------------------------------------------------
                // SAVE FAILURE
                // ------------------------------------------------

                onSaveFailed:
                    function(error) {

                    const reason =
                        FileViewError.toString(
                            error
                        )

                    root._warn(
                        "WRITE",
                        "Write failed:",
                        controller.fileKey,
                        "->",
                        controller.filePath,
                        reason
                    )

                    /*
                     * NEVER overwrite a newer queued state with the
                     * older state that was being written.
                     */
                    if (
                        controller.queuedWriteText.length === 0 &&
                        controller.writeText.length > 0
                    ) {
                        controller.queuedWriteText =
                            controller.writeText
                    }

                    controller.writeText =
                        ""

                    root._setFileState(
                        controller.fileKey,
                        {
                            writing: false,
                            dirty: true
                        }
                    )

                    root.saveError(
                        controller.fileKey,
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
                    root.writingFor(
                        controller.fileKey
                    )
                ) {
                    /*
                     * Replace the queued state with the latest state.
                     */
                    controller.queuedWriteText =
                        text

                    root._setFileState(
                        controller.fileKey,
                        {
                            dirty: true
                        }
                    )

                    root._debug(
                        "WRITE",
                        "Write already active; latest state queued:",
                        controller.fileKey
                    )

                    return true
                }

                if (
                    !controller.directoryReady
                ) {
                    controller.queuedWriteText =
                        text

                    root._setFileState(
                        controller.fileKey,
                        {
                            dirty: true
                        }
                    )

                    root._debug(
                        "WRITE",
                        "Directory missing; write queued:",
                        controller.fileKey,
                        "->",
                        controller.filePath
                    )

                    if (
                        !createDirectory.running
                    ) {
                        root._debug(
                            "WRITE",
                            "Creating config directory:",
                            controller.fileKey
                        )

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
                        dirty: true
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
                    root.writingFor(
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

                if (
                    root.writingFor(
                        controller.fileKey
                    )
                ) {
                    controller.queuedWriteText =
                        serialized

                    root._setFileState(
                        controller.fileKey,
                        {
                            dirty: true
                        }
                    )

                    root._debug(
                        "WRITE",
                        "Save queued behind active write:",
                        controller.fileKey
                    )

                    return true
                }

                return controller._startWrite(
                    serialized
                )
            }

            function forceReload() {
                reloadDebounce.stop()

                if (
                    root.writingFor(
                        controller.fileKey
                    )
                ) {
                    root._warn(
                        "LOAD",
                        "Reload rejected while writing:",
                        controller.fileKey
                    )

                    return false
                }

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

            /*
             * A write may have happened before the controller was
             * instantiated. If so, make sure it gets persisted.
             */
            const state =
                root._stateFor(key)

            if (
                state.dirty
            ) {
                root._debug(
                    "WRITE",
                    "Controller inherited pending dirty state:",
                    key
                )

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

            if (
                nextControllers[key] !== undefined
            ) {
                delete nextControllers[key]
            }

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
            return root.ready
        }

        function isWriting(): bool {
            return root.writing
        }

        function isDirty(): bool {
            return root.dirty
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
            return root.readyFor(
                fileKey
            )
        }

        function isWritingAt(
            fileKey: string
        ): bool {
            return root.writingFor(
                fileKey
            )
        }

        function isDirtyAt(
            fileKey: string
        ): bool {
            return root.dirtyFor(
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
            path: string
        ): bool {
            return root.registerPath(
                fileKey,
                path
            )
        }

        function updatePath(
            fileKey: string,
            path: string
        ): bool {
            return root.updatePath(
                fileKey,
                path
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
            path: string
        ): string {
            return root._ipcGet(
                path,
                root.defaultFileKey
            )
        }

        function getAt(
            path: string,
            fileKey: string
        ): string {
            return root._ipcGet(
                path,
                fileKey
            )
        }

        function has(
            path: string
        ): bool {
            return root.has(
                path,
                root.defaultFileKey
            )
        }

        function hasAt(
            path: string,
            fileKey: string
        ): bool {
            return root.has(
                path,
                fileKey
            )
        }

        // --------------------------------------------------------
        // Write
        // --------------------------------------------------------

        function setJson(
            path: string,
            json: string
        ): bool {
            return root._ipcSetJson(
                path,
                json,
                root.defaultFileKey
            )
        }

        function setJsonAt(
            path: string,
            json: string,
            fileKey: string
        ): bool {
            return root._ipcSetJson(
                path,
                json,
                fileKey
            )
        }

        function updateJson(
            section: string,
            json: string
        ): bool {
            return root._ipcUpdateJson(
                section,
                json,
                root.defaultFileKey
            )
        }

        function updateJsonAt(
            section: string,
            json: string,
            fileKey: string
        ): bool {
            return root._ipcUpdateJson(
                section,
                json,
                fileKey
            )
        }

        function remove(
            path: string
        ): bool {
            return root.remove(
                path,
                root.defaultFileKey
            )
        }

        function removeAt(
            path: string,
            fileKey: string
        ): bool {
            return root.remove(
                path,
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

    function _normalizeFileKey(fileKey) {
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

    function _resolveFileKey(fileKey) {
        const paths =
            root._paths

        if (
            fileKey === undefined ||
            fileKey === null
        ) {
            return root.defaultFileKey
        }

        const key =
            String(fileKey).trim()

        if (key.length === 0)
            return root.defaultFileKey

        if (
            paths[key] === undefined
        ) {
            /*
             * IMPORTANT:
             * Configuration operations intentionally fall back to
             * homeConfig for unknown keys.
             *
             * Registry CRUD does NOT use this function.
             */
            return root.defaultFileKey
        }

        return key
    }

    function _controllerFor(fileKey) {
        /*
         * Explicitly depend on the registry revision so bindings
         * reevaluate when a controller is added/removed.
         */
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

    function _directoryFor(path) {
        const value =
            String(path || "")

        const slash =
            value.lastIndexOf("/")

        if (slash <= 0)
            return "/"

        return value.slice(
            0,
            slash
        )
    }

    function _expandPath(path) {
        let value =
            String(path || "").trim()

        if (value.length === 0)
            return ""

        if (value === "~")
            return root.homeDir

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

        /*
         * Non-absolute paths are resolved relative to HOME.
         */
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

    function _isObject(value) {
        return (
            value !== null &&
            typeof value === "object" &&
            !Array.isArray(value)
        )
    }

    function _copyObject(value) {
        const result = {}
        const source =
            value || {}

        const keys =
            Object.keys(source)

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

    function _clone(value) {
        if (value === undefined)
            return undefined

        if (value === null)
            return null

        try {
            return JSON.parse(
                JSON.stringify(value)
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

    function _equivalent(
        left,
        right
    ) {
        try {
            return (
                JSON.stringify(left) ===
                JSON.stringify(right)
            )
        } catch (error) {
            return false
        }
    }

    // ============================================================
    // STATE HELPERS
    // ============================================================

    function _defaultFileState() {
        return {
            ready: false,
            writing: false,
            dirty: false,
            revision: 0
        }
    }

    function _stateFor(fileKey) {
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
        dirty,
        emitExternal
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        const normalized =
            root._isObject(value)
                ? root._clone(value)
                : {}

        const oldDocument =
            root._documents[key]

        const state =
            root._stateFor(key)

        const wasReady =
            state.ready

        const changed =
            !root._equivalent(
                oldDocument,
                normalized
            )

        if (
            changed ||
            !wasReady
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
                        state.revision + 1,
                    dirty:
                        dirty
                            ? true
                            : false
                }
            )

            root._debug(
                "DATA",
                "Document replaced:",
                key,
                "revision:",
                state.revision + 1,
                "changed:",
                changed
            )

            root.documentUpdated(
                key
            )
        } else {
            root._setFileState(
                key,
                {
                    ready: true,
                    dirty:
                        dirty
                            ? true
                            : false
                }
            )
        }

        if (
            emitExternal &&
            wasReady &&
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

    /*
     * CREATE
     */
    function registerPath(
        fileKey,
        path
    ) {
        const key =
            root._normalizeFileKey(
                fileKey
            )

        if (key.length === 0) {
            root._warn(
                "PATH",
                "Refusing registerPath() with empty key."
            )

            return false
        }

        const expandedPath =
            root._expandPath(
                path
            )

        if (expandedPath.length === 0) {
            root._warn(
                "PATH",
                "Refusing empty path for:",
                key
            )

            return false
        }

        /*
         * Same key + same path is idempotent.
         */
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

        /*
         * Prevent two logical keys from pointing to the same file.
         * That would create two watchers for one physical file.
         */
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

    /*
     * CREATE MANY
     */
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

        let success = true

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

    /*
     * READ
     *
     * This is registry lookup and intentionally does NOT fall back.
     */
    function hasPath(
        fileKey
    ) {
        const key =
            root._normalizeFileKey(
                fileKey
            )

        if (key.length === 0)
            return false

        return (
            root._paths[key] !== undefined
        )
    }

    /*
     * READ
     */
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

    /*
     * UPDATE
     */
    function updatePath(
        fileKey,
        path
    ) {
        const key =
            root._normalizeFileKey(
                fileKey
            )

        if (key.length === 0) {
            root._warn(
                "PATH",
                "Refusing updatePath() with empty key."
            )

            return false
        }

        /*
         * homeConfig is the permanent fallback.
         */
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
                path
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

        /*
         * Never move a file while its current state is in flight.
         */
        if (
            root.writingFor(key) ||
            root.dirtyFor(key)
        ) {
            root._warn(
                "PATH",
                "Refusing path update while file is dirty/writing:",
                key
            )

            return false
        }

        /*
         * Prevent duplicate physical paths.
         */
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

        /*
         * The document belongs to the old file, so do not reuse it
         * as the initial state of the new file.
         */
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

        const controller =
            root._controllerFor(key)

        if (controller) {
            controller.directoryReady =
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

    /*
     * DELETE
     */
    function removePath(
        fileKey
    ) {
        const key =
            root._normalizeFileKey(
                fileKey
            )

        if (key.length === 0) {
            root._warn(
                "PATH",
                "Refusing removePath() with empty key."
            )

            return false
        }

        /*
         * The default path is permanent.
         */
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
            root.writingFor(key) ||
            root.dirtyFor(key)
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

        /*
         * Remove the document/state immediately.
         *
         * Instantiator will destroy the corresponding controller
         * when the model updates.
         */
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
            return documents[key]
        }

        return {}
    }

    function readyFor(
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

    function writingFor(
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

    function dirtyFor(
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
                ? !!state.dirty
                : false
        )
    }

    function revisionFor(
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
                ? state.revision
                : 0
        )
    }

    // ============================================================
    // LOAD HANDLING
    // ============================================================

    function _handleLoaded(
        controller,
        fileView
    ) {
        const key =
            controller.fileKey

        const state =
            root._stateFor(key)

        root._debug(
            "LOAD",
            "Processing loaded file:",
            key,
            "->",
            controller.filePath
        )

        /*
         * A local mutation occurred before the initial file load
         * completed.
         *
         * Preserve local state and save it instead of allowing the
         * disk copy to overwrite it.
         */
        if (
            state.dirty
        ) {
            root._debug(
                "LOAD",
                "Skipping disk document because local state is dirty:",
                key
            )

            root._setFileState(
                key,
                {
                    ready: true
                }
            )

            controller.directoryReady =
                true

            controller.queueSave()

            return
        }

        let parsed

        try {
            const text =
                fileView.text()

            if (
                !text ||
                text.trim().length === 0
            ) {
                parsed = {}
            } else {
                parsed =
                    JSON.parse(
                        text
                    )
            }

            if (
                !root._isObject(parsed)
            ) {
                throw new Error(
                    "config root must be a JSON object"
                )
            }
        } catch (error) {
            root._warn(
                "LOAD",
                "Invalid JSON:",
                key,
                "->",
                controller.filePath,
                error
            )

            /*
             * Preserve an existing valid in-memory document.
             */
            if (
                !state.ready
            ) {
                root._setDocument(
                    key,
                    {},
                    false,
                    false
                )
            }

            return
        }

        controller.directoryReady =
            true

        const changed =
            root._setDocument(
                key,
                parsed,
                false,
                true
            )

        root._debug(
            "LOAD",
            "Document refresh complete:",
            key,
            "changed:",
            changed,
            "revision:",
            root.revisionFor(key)
        )
    }

    function _handleLoadFailed(
        controller,
        error
    ) {
        const key =
            controller.fileKey

        const state =
            root._stateFor(key)

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

            /*
             * Initial missing file.
             */
            if (
                !state.ready
            ) {
                controller.directoryReady =
                    false

                root._setDocument(
                    key,
                    {},
                    false,
                    false
                )

                /*
                 * Preserve old behavior for homeConfig:
                 * automatically create the default file.
                 */
                if (
                    key ===
                    root.defaultFileKey
                ) {
                    root._debug(
                        "WRITE",
                        "Default config missing; creating:",
                        controller.filePath
                    )

                    controller.queueSave()
                }

                return
            }

            /*
             * Existing file disappeared externally.
             *
             * Preserve local state if dirty.
             */
            if (
                !state.dirty
            ) {
                root._debug(
                    "LOAD",
                    "Loaded file disappeared externally:",
                    key,
                    "->",
                    controller.filePath
                )

                root._setDocument(
                    key,
                    {},
                    false,
                    true
                )
            }

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

        /*
         * Never destroy a valid in-memory document because of a
         * temporary IO error.
         */
        if (
            !state.ready
        ) {
            root._setDocument(
                key,
                {},
                false,
                false
            )
        }
    }

    // ============================================================
    // READ API
    // ============================================================

    function get(
        path,
        fallbackValue,
        fileKey
    ) {
        /*
         * Explicit dependency on _documents and _registryRevision
         * keeps this function reactive when either the document or
         * file registration changes.
         */
        const documents =
            root._documents

        const registryRevision =
            root._registryRevision

        const key =
            root._resolveFileKey(
                fileKey
            )

        if (
            !path ||
            String(path).length === 0
        ) {
            return fallbackValue
        }

        let current =
            documents[key]

        if (
            current === undefined
        ) {
            return fallbackValue
        }

        const parts =
            String(path).split(".")

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
        path,
        fileKey
    ) {
        const missing = {}

        return (
            root.get(
                path,
                missing,
                fileKey
            ) !== missing
        )
    }

    // ============================================================
    // WRITE API
    // ============================================================

    function set(
        path,
        value,
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        if (
            !path ||
            String(path).length === 0
        ) {
            root._warn(
                "WRITE",
                "Refusing empty set() path."
            )

            return false
        }

        /*
         * JSON has no undefined value.
         *
         * Accept null, but reject undefined so in-memory state never
         * differs from the serialized document.
         */
        if (
            value === undefined
        ) {
            root._warn(
                "WRITE",
                "Refusing set() with undefined value:",
                key,
                "->",
                path
            )

            return false
        }

        const currentDocument =
            root.documentFor(
                key
            )

        const nextDocument =
            root._clone(
                currentDocument
            )

        let current =
            nextDocument

        const parts =
            String(path).split(".")

        for (
            let i = 0;
            i < parts.length - 1;
            ++i
        ) {
            const part =
                parts[i]

            if (
                current[part] === null ||
                typeof current[part] !== "object" ||
                Array.isArray(
                    current[part]
                )
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

        /*
         * Avoid needless revision increments and file writes.
         */
        if (
            root._equivalent(
                currentDocument,
                nextDocument
            )
        ) {
            root._debug(
                "WRITE",
                "set() is a no-op:",
                key,
                "->",
                path
            )

            return true
        }

        const nextDocuments =
            root._copyObject(
                root._documents
            )

        nextDocuments[key] =
            nextDocument

        root._documents =
            nextDocuments

        const state =
            root._stateFor(key)

        root._setFileState(
            key,
            {
                dirty: true,
                revision:
                    state.revision + 1
            }
        )

        root._debug(
            "WRITE",
            "set():",
            key,
            "->",
            path,
            "revision:",
            state.revision + 1
        )

        root.documentUpdated(
            key
        )

        const controller =
            root._controllerFor(
                key
            )

        /*
         * The controller may not exist yet while an Instantiator
         * object is still being created.
         *
         * The dirty state remains in the store. Once the controller
         * appears, onObjectAdded() will queue the save.
         */
        if (!controller) {
            root._debug(
                "WRITE",
                "Controller not ready; save deferred:",
                key
            )

            return true
        }

        return controller.queueSave()
    }

    function update(
        section,
        patch,
        fileKey
    ) {
        if (
            !section ||
            String(section).length === 0
        ) {
            root._warn(
                "WRITE",
                "Refusing empty update() section."
            )

            return false
        }

        if (
            !root._isObject(
                patch
            )
        ) {
            root._warn(
                "WRITE",
                "update() requires an object."
            )

            return false
        }

        const key =
            root._resolveFileKey(
                fileKey
            )

        root._debug(
            "WRITE",
            "update():",
            key,
            "->",
            section
        )

        const current =
            root.get(
                section,
                {},
                key
            )

        const merged =
            root._deepMerge(
                root._isObject(
                    current
                )
                    ? root._clone(
                        current
                    )
                    : {},
                patch
            )

        return root.set(
            section,
            merged,
            key
        )
    }

    function remove(
        path,
        fileKey
    ) {
        const key =
            root._resolveFileKey(
                fileKey
            )

        if (
            !path ||
            String(path).length === 0
        ) {
            root._warn(
                "WRITE",
                "Refusing empty remove() path."
            )

            return false
        }

        const currentDocument =
            root.documentFor(
                key
            )

        const nextDocument =
            root._clone(
                currentDocument
            )

        let current =
            nextDocument

        const parts =
            String(path).split(".")

        for (
            let i = 0;
            i < parts.length - 1;
            ++i
        ) {
            const part =
                parts[i]

            if (
                current === null ||
                typeof current !== "object" ||
                !(part in current)
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
            typeof current !== "object" ||
            !(finalKey in current)
        ) {
            return false
        }

        delete current[finalKey]

        const nextDocuments =
            root._copyObject(
                root._documents
            )

        nextDocuments[key] =
            nextDocument

        root._documents =
            nextDocuments

        const state =
            root._stateFor(key)

        root._setFileState(
            key,
            {
                dirty: true,
                revision:
                    state.revision + 1
            }
        )

        root._debug(
            "WRITE",
            "remove():",
            key,
            "->",
            path,
            "revision:",
            state.revision + 1
        )

        root.documentUpdated(
            key
        )

        const controller =
            root._controllerFor(
                key
            )

        if (!controller) {
            root._debug(
                "WRITE",
                "Controller not ready; removal save deferred:",
                key
            )

            return true
        }

        return controller.queueSave()
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

        const controller =
            root._controllerFor(
                key
            )

        if (!controller) {
            root._warn(
                "WRITE",
                "save() has no controller:",
                key
            )

            return false
        }

        const state =
            root._stateFor(
                key
            )

        if (
            !state.ready &&
            !state.dirty
        ) {
            root._warn(
                "WRITE",
                "save() requested before configuration is ready:",
                key
            )

            return false
        }

        root._debug(
            "WRITE",
            "Manual save requested:",
            key,
            "->",
            controller.filePath
        )

        return controller.queueSave()
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

        if (!controller) {
            root._warn(
                "LOAD",
                "reload() has no controller:",
                key
            )

            return false
        }

        if (
            root.writingFor(key)
        ) {
            root._warn(
                "LOAD",
                "Reload rejected while writing:",
                key
            )

            return false
        }

        /*
         * Explicit reload intentionally discards local unsaved
         * state.
         */
        controller.writeText =
            ""

        controller.queuedWriteText =
            ""

        root._setFileState(
            key,
            {
                dirty: false
            }
        )

        root._debug(
            "LOAD",
            "Manual reload requested:",
            key,
            "->",
            controller.filePath
        )

        return controller.forceReload()
    }

    function reloadAll() {
        const keys =
            root._pathKeys

        let success =
            true

        root._debug(
            "LOAD",
            "Manual reload requested for all registered files."
        )

        for (
            let i = 0;
            i < keys.length;
            ++i
        ) {
            const key =
                keys[i]

            if (
                root.writingFor(key)
            ) {
                root._warn(
                    "LOAD",
                    "Skipping reload while writing:",
                    key
                )

                success = false

                continue
            }

            const controller =
                root._controllerFor(
                    key
                )

            if (!controller) {
                root._warn(
                    "LOAD",
                    "No controller during reloadAll():",
                    key
                )

                success = false

                continue
            }

            controller.writeText =
                ""

            controller.queuedWriteText =
                ""

            root._setFileState(
                key,
                {
                    dirty: false
                }
            )

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
        path,
        fileKey
    ) {
        const value =
            root.get(
                path,
                undefined,
                fileKey
            )

        if (value === undefined)
            return ""

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
        path,
        json,
        fileKey
    ) {
        try {
            const value =
                JSON.parse(
                    json
                )

            return root.set(
                path,
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
        section,
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
                section,
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

    // ============================================================
    // LOGGING
    // ============================================================

    function _debug() {
        if (
            !root.debugLogging
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