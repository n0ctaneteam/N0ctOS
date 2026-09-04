import QtQuick
import Quickshell
import Quickshell.Io
import "core" as Core
import "components" as Components

ShellRoot {
    id: shell

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string xdgConfigHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")

    // Change this one array to add/remove/reorder module roots.
    // Earlier paths have higher precedence for duplicate module IDs.
    property list<string> moduleScanPaths: [
        home + "/.config/N0ctOS/addons/modules",
        "/usr/share/N0ctOS/local/addons/modules",
        "/usr/share/N0ctOS/shell/modules",
        "/usr/share/N0ctOS/shell/--test--/n0ctos-modular-blob/example/modules"
    ]

    readonly property string layoutConfigPath: xdgConfigHome + "/N0ctOS/blobs.json"

    Core.ModuleRegistry {
        id: registry
        scanPaths: shell.moduleScanPaths

        onScanFinished: console.log("N0ctOS: registered", moduleList.length, "modules")
        onModuleRejected: (path, reason) => console.warn("N0ctOS: rejected", path, "-", reason)
    }

    Core.LayoutConfig {
        id: layout
        path: shell.layoutConfigPath
        onFailed: reason => console.warn("N0ctOS: layout config:", reason)
    }

    Core.ModuleManager {
        id: moduleManager
        registry: registry
    }

    Core.ModuleIPC {
        manager: moduleManager
        registry: registry
    }

    Component.onCompleted: registry.scan()

    PanelWindow {
        id: panel
        anchors.left: true
        anchors.right: true
        anchors.top: true
        anchors.bottom: true
        color: "transparent"
        focusable: true
        exclusionMode: ExclusionMode.Ignore

        Grid {
            id: blobGrid
            anchors.centerIn: parent
            columns: 4
            rows: 2
            rowSpacing: 18
            columnSpacing: 18

            Components.Blob {
                id: blob1
                blobId: "blob1"
                width: 180
                height: 140
                registry: registry
                moduleManager: moduleManager
                configuredModuleIds: layout.modulesFor(blobId)
            }

            Components.Blob {
                id: blob2
                blobId: "blob2"
                width: 180
                height: 140
                registry: registry
                moduleManager: moduleManager
                configuredModuleIds: layout.modulesFor(blobId)
            }

            Components.Blob {
                id: blob3
                blobId: "blob3"
                width: 180
                height: 140
                registry: registry
                moduleManager: moduleManager
                configuredModuleIds: layout.modulesFor(blobId)
            }

            Components.Blob {
                id: blob4
                blobId: "blob4"
                width: 180
                height: 140
                registry: registry
                moduleManager: moduleManager
                configuredModuleIds: layout.modulesFor(blobId)
            }

            Components.Blob {
                id: blob5
                blobId: "blob5"
                width: 180
                height: 140
                registry: registry
                moduleManager: moduleManager
                configuredModuleIds: layout.modulesFor(blobId)
            }

            Components.Blob {
                id: blob6
                blobId: "blob6"
                width: 180
                height: 140
                registry: registry
                moduleManager: moduleManager
                configuredModuleIds: layout.modulesFor(blobId)
            }

            Components.Blob {
                id: blob7
                blobId: "blob7"
                width: 180
                height: 140
                registry: registry
                moduleManager: moduleManager
                configuredModuleIds: layout.modulesFor(blobId)
            }

            Components.Blob {
                id: blob8
                blobId: "blob8"
                width: 180
                height: 140
                registry: registry
                moduleManager: moduleManager
                configuredModuleIds: layout.modulesFor(blobId)
            }
        }
    }
}
