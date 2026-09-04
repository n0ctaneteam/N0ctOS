import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var blobManager
    required property var blobs

    visible: false
    width: 0
    height: 0

    IpcHandler {
        target: "n0ctos-blob"

        function activate(moduleId: string): void {
            console.log("[BlobIPC] activate:", moduleId)

            const blobId = blobManager.blobOf(moduleId)

            if (!blobId || !blobs[blobId]) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            console.log(
                "[BlobIPC] ->",
                blobId,
                "openModule",
                moduleId
            )

            blobs[blobId].openModule(moduleId)
        }

        function deactivate(moduleId: string): void {
            console.log("[BlobIPC] deactivate:", moduleId)

            const blobId = blobManager.blobOf(moduleId)

            if (!blobId || !blobs[blobId]) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            console.log(
                "[BlobIPC] ->",
                blobId,
                "deactivateModule",
                moduleId
            )

            blobs[blobId].deactivateModule(moduleId)
        }

        function toggle(moduleId: string): void {
            console.log("[BlobIPC] toggle:", moduleId)

            const blobId = blobManager.blobOf(moduleId)

            if (!blobId || !blobs[blobId]) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            console.log(
                "[BlobIPC] ->",
                blobId,
                "toggleModule",
                moduleId
            )

            blobs[blobId].toggleModule(moduleId)
        }

        function focus(blobId: string): void {
            console.log("[BlobIPC] focus:", blobId)

            if (!blobs[blobId]) {
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

            blobs[blobId].focusBlob()
        }
    }

    Component.onCompleted: {
        console.log(
            "[BlobIPC] registered: n0ctos-blob"
        )
    }
}