import QtQuick
import Quickshell.Io
import Quickshell

Scope {
    id: root

    property string path: ""
    property bool watch: true
    readonly property var data: _data
    readonly property bool valid: _valid
    readonly property string error: _error

    property var _data: ({})
    property bool _valid: false
    property string _error: ""

    signal loaded()
    signal failed(string reason)

    function reload(): void {
        _load();
    }

    function modulesFor(blobId: string): var {
        const blobs = root._data && typeof root._data === "object" ? root._data.blobs : null;
        if (!blobs || typeof blobs !== "object") return [];
        const value = blobs[blobId];
        return Array.isArray(value) ? value.slice() : [];
    }

    function _load(): void {
        root._valid = false;
        root._error = "";
        if (!root.path) {
            root._data = ({});
            root._valid = true;
            root.loaded();
            return;
        }

        try {
            const text = file.text();
            const parsed = JSON.parse(text || "{}");
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
                throw new Error("configuration root must be a JSON object");
            }
            root._data = parsed;
            root._valid = true;
            root.loaded();
        } catch (error) {
            root._data = ({});
            root._error = String(error);
            root.failed(root._error);
        }
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: root.watch
        printErrors: true

        onFileChanged: file.reload()
        onLoaded: root._load()
    }
}
