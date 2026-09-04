import QtQuick
import Quickshell.Io
import Quickshell

Scope {
    id: root

    required property QtObject manager
    required property QtObject registry

    IpcHandler {
        target: "n0ctos"

        function activate(moduleId: string): bool {
            return root.manager.activate(moduleId, true);
        }

        function activateIn(moduleId: string, blobId: string): bool {
            return root.manager.activateIn(moduleId, blobId, true);
        }

        function deactivate(moduleId: string): bool {
            return root.manager.deactivate(moduleId);
        }

        function toggle(moduleId: string): bool {
            return root.manager.toggle(moduleId);
        }

        function focus(moduleId: string): bool {
            return root.manager.focus(moduleId);
        }

        function reloadModules(): bool {
            root.registry.reload();
            return true;
        }

        function listModules(): string {
            return JSON.stringify(root.registry.all());
        }

        function info(moduleId: string): string {
            const data = root.registry.get(moduleId);
            return data ? JSON.stringify(data) : "";
        }
    }
}
