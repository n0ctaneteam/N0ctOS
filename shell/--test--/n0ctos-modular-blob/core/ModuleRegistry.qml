import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Ordered from highest precedence to lowest precedence.
    // The first module registered for a given ID wins.
    property list<string> scanPaths: []
    property string manifestFileName: "manifest.json"
    property int minSearchDepth: 2
    property int maxSearchDepth: 2
    property list<string> requiredManifestFields: ["id", "name", "version", "author", "module"]

    readonly property bool scanning: _scanning
    readonly property var modules: _modules
    readonly property var moduleList: _moduleList

    property bool _scanning: false
    property var _modules: ({})
    property var _moduleList: []
    property var _manifestQueue: []
    property int _rootIndex: 0
    property int _manifestIndex: 0

    signal scanStarted()
    signal scanFinished()
    signal moduleRegistered(string id, var descriptor)
    signal moduleRejected(string manifestPath, string reason)
    signal scanError(string path, string error)

    function scan(): void {
        if (root._scanning) {
            return;
        }

        root._scanning = true;
        root._rootIndex = 0;
        root._manifestIndex = 0;
        root._manifestQueue = [];
        root._modules = ({});
        root._moduleList = [];
        scanStarted();

        if (root.scanPaths.length === 0) {
            root._finishScan();
            return;
        }

        root._scanNextRoot();
    }

    function reload(): void {
        scan();
    }

    function has(id: string): bool {
        return !!id && Object.prototype.hasOwnProperty.call(root._modules, id);
    }

    function get(id: string): var {
        return has(id) ? root._modules[id] : null;
    }

    function all(): var {
        return root._moduleList.slice();
    }

    function pathFor(id: string): string {
        const descriptor = get(id);
        return descriptor ? descriptor.modulePath : "";
    }

    function _scanNextRoot(): void {
        if (root._rootIndex >= root.scanPaths.length) {
            root._scanManifests();
            return;
        }

        const path = _normalizePath(root.scanPaths[root._rootIndex]);
        root._rootIndex += 1;

        if (!path) {
            root._scanNextRoot();
            return;
        }

        findProcess.exec([
            "find",
            path,
            "-mindepth", String(root.minSearchDepth),
            "-maxdepth", String(root.maxSearchDepth),
            "-type", "f",
            "-name", root.manifestFileName,
            "-print"
        ]);
    }

    function _onRootProcessExited(exitCode: int): void {
        const output = findStdout.text;
        const lines = output.split("\n");

        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim();
            if (line.length > 0) {
                root._manifestQueue.push(line);
            }
        }

        if (exitCode !== 0) {
            const completedRoot = root.scanPaths[Math.max(0, root._rootIndex - 1)];
            root.scanError(completedRoot || "", "find exited with code " + exitCode);
        }

        root._scanNextRoot();
    }

    function _scanManifests(): void {
        // Deduplicate manifest paths before parsing.
        const unique = {};
        const deduped = [];
        for (let i = 0; i < root._manifestQueue.length; ++i) {
            const path = root._manifestQueue[i];
            if (!unique[path]) {
                unique[path] = true;
                deduped.push(path);
            }
        }
        deduped.sort();
        root._manifestQueue = deduped;
        root._manifestIndex = 0;

        root._readNextManifest();
    }

    function _readNextManifest(): void {
        if (root._manifestIndex >= root._manifestQueue.length) {
            root._finishScan();
            return;
        }

        const path = root._manifestQueue[root._manifestIndex];
        root._manifestIndex += 1;
        manifestProcess.exec(["cat", path]);
    }

    function _onManifestProcessExited(exitCode: int): void {
        const manifestPath = root._manifestQueue[Math.max(0, root._manifestIndex - 1)] || "";

        if (exitCode !== 0) {
            root.moduleRejected(manifestPath, "could not read manifest");
            root._readNextManifest();
            return;
        }

        root._registerManifest(manifestPath, manifestStdout.text);
        root._readNextManifest();
    }

    function _registerManifest(manifestPath: string, text: string): void {
        let manifest;

        try {
            manifest = JSON.parse(text);
        } catch (error) {
            root.moduleRejected(manifestPath, "invalid JSON: " + error);
            return;
        }

        if (!manifest || typeof manifest !== "object" || Array.isArray(manifest)) {
            root.moduleRejected(manifestPath, "manifest root must be a JSON object");
            return;
        }

        for (let i = 0; i < root.requiredManifestFields.length; ++i) {
            const field = root.requiredManifestFields[i];
            if (!Object.prototype.hasOwnProperty.call(manifest, field) ||
                (typeof manifest[field] === "string" && manifest[field].trim().length === 0) ||
                manifest[field] === null || manifest[field] === undefined) {
                root.moduleRejected(manifestPath, "missing/invalid manifest field '" + field + "'");
                return;
            }
        }

        if (typeof manifest.id !== "string" || typeof manifest.module !== "string") {
            root.moduleRejected(manifestPath, "'id' and 'module' must be strings");
            return;
        }

        if (manifest.module.indexOf("/") !== -1 || manifest.module.indexOf("\\") !== -1) {
            root.moduleRejected(manifestPath, "'module' must be a sibling QML filename, not a path");
            return;
        }

        if (!manifest.module.toLowerCase().endsWith(".qml")) {
            root.moduleRejected(manifestPath, "'module' must point to a .qml file");
            return;
        }

        if (root.has(manifest.id)) {
            // Earlier scan paths have higher precedence.
            return;
        }

        const moduleDir = _dirname(manifestPath);
        const modulePath = _joinPath(moduleDir, manifest.module.trim());

        if (!_isDescendant(moduleDir, modulePath)) {
            root.moduleRejected(manifestPath, "'module' escapes the manifest directory");
            return;
        }

        const descriptor = {};
        for (const key in manifest) {
            descriptor[key] = manifest[key];
        }

        // Runtime metadata. Any new fields in manifest.json automatically survive parsing.
        descriptor.manifestPath = manifestPath;
        descriptor.moduleDir = moduleDir;
        descriptor.modulePath = modulePath;

        root._modules[manifest.id] = descriptor;
        root._moduleList.push(descriptor);
        root.moduleRegistered(manifest.id, descriptor);
    }

    function _finishScan(): void {
        root._moduleList.sort(function(a, b) {
            const an = String(a.name || a.id).toLowerCase();
            const bn = String(b.name || b.id).toLowerCase();
            if (an < bn) return -1;
            if (an > bn) return 1;
            return String(a.id).localeCompare(String(b.id));
        });

        root._scanning = false;
        scanFinished();
    }

    function _normalizePath(path: string): string {
        if (!path) return "";
        let value = String(path).trim();
        while (value.length > 1 && value.endsWith("/")) {
            value = value.slice(0, -1);
        }
        return value;
    }

    function _dirname(path: string): string {
        const normalized = _normalizePath(path);
        const index = normalized.lastIndexOf("/");
        return index <= 0 ? "/" : normalized.slice(0, index);
    }

    function _joinPath(base: string, child: string): string {
        const cleanBase = _normalizePath(base);
        let cleanChild = String(child);
        while (cleanChild.startsWith("/")) cleanChild = cleanChild.slice(1);
        return cleanBase === "/" ? "/" + cleanChild : cleanBase + "/" + cleanChild;
    }

    function _isDescendant(base: string, candidate: string): bool {
        const baseClean = _normalizePath(base);
        const candidateClean = _normalizePath(candidate);
        return candidateClean === baseClean || candidateClean.indexOf(baseClean + "/") === 0;
    }

    Process {
        id: findProcess
        stdout: StdioCollector { id: findStdout }
        onExited: (exitCode, exitStatus) => root._onRootProcessExited(exitCode)
    }

    Process {
        id: manifestProcess
        stdout: StdioCollector { id: manifestStdout }
        onExited: (exitCode, exitStatus) => root._onManifestProcessExited(exitCode)
    }
}
