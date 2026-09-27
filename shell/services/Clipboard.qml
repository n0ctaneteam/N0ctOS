pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============================================================
    // PATHS
    // ============================================================

    readonly property string homeDir:
        String(
            Quickshell.env("HOME") || ""
        )

    readonly property string dataBase:
        String(
            Quickshell.env("XDG_DATA_HOME") ||
            (
                root.homeDir +
                "/.local/share"
            )
        )

    readonly property string dataDir:
        root.dataBase +
        "/N0ctOS/clipboard"

    readonly property string itemsDir:
        root.dataDir +
        "/items"

    readonly property string historyPath:
        root.dataDir +
        "/history.json"

    // ============================================================
    // STATE
    // ============================================================

    property var _history: []

    property bool _storageReady: false
    property bool _historyLoaded: false
    property bool _historySaving: false
    property bool _historyWritePending: false
    property bool _watchStarted: false
    property bool _available: false

    property int _sequence: 0

    readonly property bool available:
        root._available

    readonly property bool watching:
        root._watchStarted &&
        clipboardWatcher.running

    // ============================================================
    // PUBLIC HISTORY
    // ============================================================

    readonly property var items:
        root._history

    readonly property int count:
        root._history.length

    readonly property var current:
        root.count > 0
            ? root._history[0]
            : null

    // ============================================================
    // CONFIG
    // ============================================================

    readonly property int historySize:
        root.normalizeHistorySize(
            Config.get(
                "clipboard.historySize",
                50
            )
        )

    readonly property int _configRevision:
        Config.revision

    on_ConfigRevisionChanged: {
        root.trimHistory()

        if (root._historyLoaded)
            root.scheduleHistorySave()
    }

    onHistorySizeChanged: {
        root.trimHistory()

        if (root._historyLoaded)
            root.scheduleHistorySave()
    }

    // ============================================================
    // SIGNALS
    // ============================================================

    signal itemAdded(var item)
    signal itemRemoved(var item)
    signal historyCleared()
    signal availabilityChangedExternally()

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-clipboard"

        function count(): int {
            return root.count
        }

        function historySize(): int {
            return root.historySize
        }

        function watching(): bool {
            return root.watching
        }

        function list(): string {
            return JSON.stringify(
                root.items
            )
        }

        function current(): string {
            if (!root.current)
                return ""

            return JSON.stringify(
                root.current
            )
        }

        function copy(
            index: int
        ): bool {
            return root.copy(index)
        }

        function remove(
            index: int
        ): bool {
            return root.remove(index)
        }

        function clear(): bool {
            return root.clear()
        }

        function copyText(
            value: string
        ): bool {
            return root.copyText(value)
        }

        function setHistorySize(
            value: int
        ): bool {
            return root.setHistorySize(value)
        }
    }

    // ============================================================
    // DEPENDENCY CHECK
    // ============================================================

    Process {
        id: dependencyCheck

        command: [
            "sh",
            "-c",
            "command -v wl-paste >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1"
        ]

        onExited: function(exitCode) {
            root._available =
                exitCode === 0

            if (!root._available) {
                console.error(
                    "[Clipboard] wl-clipboard is required."
                )

                console.error(
                    "[Clipboard] Install it with:",
                    "sudo pacman -S wl-clipboard"
                )

                return
            }

            root._startWatcherIfReady()
        }
    }

    // ============================================================
    // STORAGE CREATION
    // ============================================================

    Process {
        id: createStorage

        command: [
            "mkdir",
            "-p",
            root.itemsDir
        ]

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.error(
                    "[Clipboard] failed to create:",
                    root.itemsDir
                )

                return
            }

            root._storageReady = true

            historyFile.reload()
        }
    }

    // ============================================================
    // HISTORY FILE
    // ============================================================

    FileView {
        id: historyFile

        path:
            root.historyPath

        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            root._loadHistory()
        }

        onFileChanged: {
            if (root._historySaving)
                return

            historyFile.reload()
        }

        onSaved: {
            root._historySaving = false

            if (
                root._historyWritePending
            ) {
                root.scheduleHistorySave()
            }
        }

        onSaveFailed: function(error) {
            root._historySaving = false

            console.error(
                "[Clipboard] history save failed:",
                FileViewError.toString(error)
            )

            /*
             * Keep the data in memory.
             * Another change will retry the write.
             */
            root._historyWritePending = true
        }

        onLoadFailed: function(error) {
            if (
                error ===
                FileViewError.FileNotFound
            ) {
                if (!root._storageReady)
                    return

                root._history = []
                root._historyLoaded = true

                root.scheduleHistorySave()
                root._startWatcherIfReady()

                return
            }

            console.error(
                "[Clipboard] history load failed:",
                FileViewError.toString(error)
            )

            /*
             * Do not overwrite a corrupt history file
             * automatically.
             */
            root._historyLoaded = true
            root._startWatcherIfReady()
        }
    }

    // ============================================================
    // WATCHER
    // ============================================================

    Process {
        id: clipboardWatcher

        command: [
            "wl-paste",
            "--watch",
            "sh",
            "-c",
            root.watchScript,
            "n0ctos-clipboard",
            root.itemsDir
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                root._handleWatchRecord(
                    String(data).trim()
                )
            }
        }

        onStarted: {
            root._watchStarted = true

            console.info(
                "[Clipboard] watcher started"
            )
        }

        onExited: function(exitCode) {
            root._watchStarted = false

            console.warn(
                "[Clipboard] watcher exited:",
                exitCode
            )

            if (
                root._available &&
                root._storageReady
            ) {
                restartWatcher.start()
            }
        }
    }

    Timer {
        id: restartWatcher

        interval: 1500
        repeat: false

        onTriggered: {
            root._startWatcherIfReady()
        }
    }

    /*
     * This script receives the clipboard contents on stdin.
     *
     * It stores the bytes first, then identifies the most useful
     * MIME type from the types offered by the clipboard.
     *
     * Output:
     *
     * path <TAB> mime <TAB> kind <TAB> size
     */
    readonly property string watchScript:
        'set -eu\n' +

        'base="$1"\n' +

        'file="$(mktemp "$base/entry-XXXXXXXX")"\n' +

        'cat > "$file"\n' +

        'size="$(wc -c < "$file" | tr -d " " | tr -d "\\n")"\n' +

        'types="$(wl-paste --list-types 2>/dev/null || true)"\n' +

        'mime=""\n' +

        'kind="binary"\n' +

        'if printf "%s\\n" "$types" | grep -Fxq "text/uri-list"; then\n' +
        '    mime="text/uri-list"\n' +
        '    kind="files"\n' +
        'elif printf "%s\\n" "$types" | grep -Fxq "x-special/gnome-copied-files"; then\n' +
        '    mime="x-special/gnome-copied-files"\n' +
        '    kind="files"\n' +
        'else\n' +
        '    imageMime="$(printf "%s\\n" "$types" | grep -E "^image/" | head -n 1 || true)"\n' +

        '    if [ -n "$imageMime" ]; then\n' +
        '        mime="$imageMime"\n' +
        '        kind="image"\n' +
        '    else\n' +
        '        textMime="$(printf "%s\\n" "$types" | grep -E "^text/plain($|;)" | head -n 1 || true)"\n' +

        '        if [ -n "$textMime" ]; then\n' +
        '            mime="$textMime"\n' +
        '            kind="text"\n' +
        '        else\n' +
        '            genericText="$(printf "%s\\n" "$types" | grep -E "^text/" | head -n 1 || true)"\n' +

        '            if [ -n "$genericText" ]; then\n' +
        '                mime="$genericText"\n' +
        '                kind="text"\n' +
        '            else\n' +
        '                mime="$(printf "%s\\n" "$types" | head -n 1)"\n' +
        '                [ -n "$mime" ] || mime="application/octet-stream"\n' +
        '            fi\n' +
        '        fi\n' +
        '    fi\n' +
        'fi\n' +

        'printf "%s\\t%s\\t%s\\t%s\\n" "$file" "$mime" "$kind" "$size"\n'

    // ============================================================
    // STARTUP
    // ============================================================

    Component.onCompleted: {
        createStorage.running = true
        dependencyCheck.running = true
    }

    // ============================================================
    // START WATCHER
    // ============================================================

    function _startWatcherIfReady() {
        if (
            !root._available ||
            !root._storageReady ||
            !root._historyLoaded ||
            root._watchStarted
        ) {
            return
        }

        root._watchStarted = true

        clipboardWatcher.running = true
    }

    // ============================================================
    // HISTORY LOAD
    // ============================================================

    function _loadHistory() {
        let parsed

        try {
            const raw =
                historyFile.text()

            if (
                !raw ||
                raw.trim().length === 0
            ) {
                parsed = []
            } else {
                parsed = JSON.parse(raw)
            }

            if (!Array.isArray(parsed)) {
                throw new Error(
                    "history root must be an array"
                )
            }
        } catch (error) {
            console.error(
                "[Clipboard] invalid history:",
                error
            )

            root._history = []
            root._historyLoaded = true
            root._startWatcherIfReady()

            return
        }

        const valid = []

        for (
            let i = 0;
            i < parsed.length;
            ++i
        ) {
            const item =
                parsed[i]

            if (
                !item ||
                typeof item !== "object"
            ) {
                continue
            }

            if (
                !item.path ||
                !item.mime
            ) {
                continue
            }

            valid.push(item)
        }

        root._history =
            valid

        root._historyLoaded =
            true

        root.trimHistory()

        root._startWatcherIfReady()
    }

    // ============================================================
    // WATCH RECORD
    // ============================================================

    function _handleWatchRecord(
        line
    ) {
        if (!line)
            return

        const parts =
            line.split("\t")

        if (parts.length < 4) {
            console.warn(
                "[Clipboard] malformed watcher record:",
                line
            )

            return
        }

        const path =
            parts[0]

        const mime =
            parts[1]

        const kind =
            parts[2]

        const size =
            Math.max(
                0,
                Number(parts[3]) || 0
            )

        /*
         * Only accept files created inside the clipboard
         * storage directory.
         */
        const allowedPrefix =
            root.itemsDir + "/"

        if (
            path.indexOf(
                allowedPrefix
            ) !== 0
        ) {
            console.warn(
                "[Clipboard] rejected path:",
                path
            )

            return
        }

        root._sequence += 1

        const item = {
            id:
                String(
                    Date.now()
                ) +
                "-" +
                String(
                    root._sequence
                ),

            path:
                path,

            mime:
                mime,

            kind:
                kind,

            size:
                size,

            timestamp:
                Date.now()
        }

        root._history =
            [
                item,
                ...root._history
            ]

        root.trimHistory()

        root.itemAdded(item)

        root.scheduleHistorySave()
    }

    // ============================================================
    // HISTORY TRIMMING
    // ============================================================

    function trimHistory() {
        if (!root._historyLoaded)
            return

        const limit =
            root.historySize

        while (
            root._history.length >
            limit
        ) {
            const removed =
                root._history.pop()

            if (
                removed &&
                removed.path
            ) {
                Quickshell.execDetached({
                    command: [
                        "rm",
                        "-f",
                        String(
                            removed.path
                        )
                    ]
                })

                root.itemRemoved(
                    removed
                )
            }
        }
    }

    // ============================================================
    // HISTORY SAVE
    // ============================================================

    Timer {
        id: historySaveTimer

        interval: 50
        repeat: false

        onTriggered: {
            root._writeHistory()
        }
    }

    function scheduleHistorySave() {
        if (!root._historyLoaded)
            return

        root._historyWritePending = true

        historySaveTimer.restart()
    }

    function _writeHistory() {
        if (
            !root._storageReady ||
            !root._historyLoaded
        ) {
            return
        }

        if (root._historySaving)
            return

        root._historyWritePending = false
        root._historySaving = true

        historyFile.setText(
            JSON.stringify(
                root._history,
                null,
                2
            ) + "\n"
        )
    }

    // ============================================================
    // COPY
    // ============================================================

    function copy(index) {
        if (
            index < 0 ||
            index >= root._history.length
        ) {
            return false
        }

        const item =
            root._history[index]

        if (
            !item ||
            !item.path ||
            !item.mime
        ) {
            return false
        }

        return root.copyFile(
            item.path,
            item.mime
        )
    }

    function copyFile(
        path,
        mime
    ) {
        if (
            !path ||
            !mime
        ) {
            return false
        }

        Quickshell.execDetached({
            command: [
                "sh",
                "-c",
                'exec wl-copy --type "$1" < "$2"',
                "n0ctos-clipboard-copy",
                String(mime),
                String(path)
            ]
        })

        return true
    }

    function copyText(value) {
        const text =
            String(value)

        Quickshell.execDetached({
            command: [
                "sh",
                "-c",
                'printf "%s" "$1" | wl-copy --type text/plain',
                "n0ctos-clipboard-text",
                text
            ]
        })

        return true
    }

    // ============================================================
    // REMOVE
    // ============================================================

    function remove(index) {
        if (
            index < 0 ||
            index >= root._history.length
        ) {
            return false
        }

        const next =
            root._history.slice()

        const removed =
            next.splice(
                index,
                1
            )[0]

        root._history =
            next

        if (
            removed &&
            removed.path
        ) {
            Quickshell.execDetached({
                command: [
                    "rm",
                    "-f",
                    String(
                        removed.path
                    )
                ]
            })
        }

        root.itemRemoved(
            removed
        )

        root.scheduleHistorySave()

        return true
    }

    // ============================================================
    // CLEAR
    // ============================================================

    function clear() {
        for (
            let i = 0;
            i < root._history.length;
            ++i
        ) {
            const item =
                root._history[i]

            if (
                item &&
                item.path
            ) {
                Quickshell.execDetached({
                    command: [
                        "rm",
                        "-f",
                        String(item.path)
                    ]
                })
            }
        }

        root._history = []

        root.historyCleared()

        root.scheduleHistorySave()

        return true
    }

    // ============================================================
    // CONFIG
    // ============================================================

    function normalizeHistorySize(
        value
    ) {
        let size =
            Number(value)

        if (!isFinite(size))
            size = 50

        size =
            Math.floor(size)

        /*
         * 1..500 is enough for a normal desktop clipboard
         * history without accidentally creating a giant store.
         */
        return Math.max(
            1,
            Math.min(
                500,
                size
            )
        )
    }

    function setHistorySize(
        value
    ) {
        const normalized =
            root.normalizeHistorySize(
                value
            )

        return Config.set(
            "clipboard.historySize",
            normalized
        )
    }
}