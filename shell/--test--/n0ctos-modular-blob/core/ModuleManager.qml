import QtQuick
import Quickshell
Scope {
    id: root

    required property QtObject registry
    property var blobs: []
    property string activeModuleId: ""
    property string activeBlobId: ""
    readonly property var activeModule: activeBlobId.length > 0 ? (blobForId(activeBlobId) ? blobForId(activeBlobId).moduleInstance : null) : null

    signal moduleActivated(string moduleId, string blobId)
    signal moduleDeactivated(string moduleId, string blobId)
    signal activationFailed(string moduleId, string reason)

    function registerBlob(blob: QtObject): void {
        if (!blob || !blob.blobId) return;
        for (let i = 0; i < root.blobs.length; ++i) {
            if (root.blobs[i] === blob) return;
            if (root.blobs[i].blobId === blob.blobId) {
                root.blobs[i] = blob;
                root.blobs = root.blobs.slice();
                return;
            }
        }
        const next = root.blobs.slice();
        next.push(blob);
        root.blobs = next;

        blob.moduleClosed.connect(function(moduleId) {
            if (root.activeBlobId === blob.blobId && root.activeModuleId === moduleId) {
                root.activeModuleId = "";
                root.activeBlobId = "";
                root.moduleDeactivated(moduleId, blob.blobId);
            }
        });
    }

    function unregisterBlob(blob: QtObject): void {
        const wasActive = blob && root.activeBlobId === blob.blobId;
        const activeId = root.activeModuleId;
        const next = root.blobs.filter(function(entry) { return entry !== blob; });
        root.blobs = next;
        if (wasActive) {
            root.activeModuleId = "";
            root.activeBlobId = "";
            if (activeId) root.moduleDeactivated(activeId, blob.blobId);
        }
    }

    function blobForId(blobId): var {
        for (let i = 0; i < root.blobs.length; ++i) {
            if (root.blobs[i].blobId === blobId) return root.blobs[i];
        }
        return null;
    }

    function findBlobForModule(moduleId): var {
        const owners = [];
        for (let i = 0; i < root.blobs.length; ++i) {
            const blob = root.blobs[i];
            if (blob && blob.hasConfiguredModule(moduleId)) {
                owners.push(blob);
            }
        }

        if (owners.length > 1) {
            console.warn("N0ctOS: module", moduleId, "is assigned to multiple blobs; using", owners[0].blobId);
        }
        return owners.length > 0 ? owners[0] : null;
    }

    function activate(moduleId, requestFocus= true): bool {
        if (!root.registry.has(moduleId)) {
            root.activationFailed(moduleId, "module is not registered");
            return false;
        }

        const blob = root.findBlobForModule(moduleId);
        if (!blob) {
            root.activationFailed(moduleId, "module is not assigned to any blob");
            return false;
        }

        return root.activateIn(moduleId, blob.blobId, requestFocus);
    }

    function activateIn(moduleId, blobId, requestFocus=true): bool {
        const blob = root.blobForId(blobId);
        if (!blob) {
            root.activationFailed(moduleId, "blob not found: " + blobId);
            return false;
        }
        if (!blob.hasConfiguredModule(moduleId)) {
            root.activationFailed(moduleId, "module is not configured for blob " + blobId);
            return false;
        }

        // Deactivate the previous global module first. A blob can decide how its own transition is rendered.
        if (root.activeBlobId.length > 0 && (root.activeBlobId !== blobId || root.activeModuleId !== moduleId)) {
            root.deactivateActive();
        }

        if (!blob.activateModule(moduleId, requestFocus, "direct")) {
            root.activationFailed(moduleId, "blob rejected activation");
            return false;
        }

        root.activeModuleId = moduleId;
        root.activeBlobId = blobId;
        root.moduleActivated(moduleId, blobId);
        return true;
    }

    function deactivate(moduleId = root.activeModuleId): bool {
        if (!moduleId) return false;
        const blob = root.findBlobForModule(moduleId);
        if (!blob) return false;

        const wasActive = moduleId === root.activeModuleId && blob.blobId === root.activeBlobId;
        const result = blob.deactivateModule(moduleId);
        if (result && !wasActive) {
            root.moduleDeactivated(moduleId, blob.blobId);
        }
        return result;
    }

    function deactivateActive(): bool {
        if (!root.activeModuleId || !root.activeBlobId) return false;
        return root.deactivate(root.activeModuleId);
    }

    function toggle(moduleId): bool {
        if (moduleId === root.activeModuleId) {
            return root.deactivateActive();
        }
        return root.activate(moduleId, true);
    }

    function focus(moduleId = root.activeModuleId): bool {
        if (!moduleId) return false;
        const blob = root.findBlobForModule(moduleId);
        return !!blob && blob.focusModule(moduleId);
    }

    function isActive(moduleId): bool {
        return root.activeModuleId === moduleId;
    }
}
