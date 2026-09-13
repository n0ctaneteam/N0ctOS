pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Singleton-safe defaults — ScreenFrame assigns `blobs` for visual binding.
    // `blobManager` defaults to the BlobManager singleton; assignment kept for compat.
    property var blobManager: BlobManager
    property var blobs: ({})

    IpcHandler {
        target: "n0ctos-blob"

        function activate(moduleId: string): void {
            console.log("[BlobIPC] activate:", moduleId)

            const mgr = root.blobManager || BlobManager
            const blobId = mgr.blobOf(moduleId)
            const target = root.blobs

            if (!blobId || !target[blobId]) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            console.log(
                "[BlobIPC] ->",
                blobId,
                "openModule",
                moduleId
            )

            target[blobId].openModule(moduleId)
        }

        function deactivate(moduleId: string): void {
            console.log("[BlobIPC] deactivate:", moduleId)

            const mgr = root.blobManager || BlobManager
            const blobId = mgr.blobOf(moduleId)
            const target = root.blobs

            if (!blobId || !target[blobId]) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            console.log(
                "[BlobIPC] ->",
                blobId,
                "deactivateModule",
                moduleId
            )

            target[blobId].deactivateModule(moduleId)
        }

        function toggle(moduleId: string): void {
            console.log("[BlobIPC] toggle:", moduleId)

            const mgr = root.blobManager || BlobManager
            const blobId = mgr.blobOf(moduleId)
            const target = root.blobs

            if (!blobId || !target[blobId]) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            console.log(
                "[BlobIPC] ->",
                blobId,
                "toggleModule",
                moduleId
            )

            target[blobId].toggleModule(moduleId)
        }

        function focus(blobId: string): void {
            console.log("[BlobIPC] focus:", blobId)

            const target = root.blobs

            if (!target[blobId]) {
                console.warn(
                    "[BlobIPC] invalid blob:",
                    blobId
                )
                return
            }

            console.log(
                "[BlobIPC] ->",
                blobId,
                "focusBlob"
            )

            target[blobId].focusBlob()
        }
    }

    Component.onCompleted: {
        console.log(
            "[BlobIPC] registered: n0ctos-blob"
        )
    }
}