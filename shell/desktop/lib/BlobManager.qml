import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property list<string> configPaths: []

    property var blobs: ({
        tr: [],
        tl: [],
        tc: [],
        br: [],
        bl: [],
        bc: [],
        left: [],
        right: []
    })

    readonly property string activeConfigPath: _activePath

    property string _activePath: ""
    property var _configData: ({})
    property var _jobs: []

    function loadConfig() {
        console.log("[BlobManager] loadConfig()")
        console.log("[BlobManager] paths:", JSON.stringify(configPaths))

        _jobs.forEach(j => j.destroy())
        _jobs = []
        _activePath = ""
        _configData = ({})

        _tryConfig(0)
    }

    function _tryConfig(index) {
        if (index >= configPaths.length) {
            console.warn("[BlobManager] no valid config found")
            return
        }

        const path = configPaths[index]

        if (!path) {
            _tryConfig(index + 1)
            return
        }

        console.log("[BlobManager] checking:", path)

        const f = configComponent.createObject(root, {
            configIndex: index,
            configPath: path,
            path: path
        })

        if (!f) {
            console.warn("[BlobManager] failed to create config reader:", path)
            _tryConfig(index + 1)
            return
        }

        _jobs.push(f)
    }

    function _configLoaded(file) {
        const path = file.configPath

        try {
            const text = file.text()
            console.log("[BlobManager] loaded:", path)
            console.log("[BlobManager] raw:", text)

            const data = JSON.parse(text)

            if (!data || typeof data !== "object")
                throw new Error("config is not an object")

            if (!data.blobs || typeof data.blobs !== "object")
                throw new Error("missing blobs object")

            _activePath = path
            _configData = data

            const next = {}
            const blobIds = [
                "tr", "tl", "tc",
                "br", "bl", "bc",
                "left", "right"
            ]

            for (const id of blobIds) {
                next[id] = Array.isArray(data.blobs[id])
                    ? data.blobs[id].filter(v => typeof v === "string")
                    : []
            }

            blobs = next

            console.log("[BlobManager] ACTIVE:", path)
            console.log("[BlobManager] BLOBS:", JSON.stringify(blobs))

            file.destroy()
        } catch (e) {
            console.warn(
                "[BlobManager] invalid config:",
                path,
                "|", e
            )

            file.destroy()
            _tryConfig(file.configIndex + 1)
        }
    }

    function _configFailed(file, error) {
        console.warn(
            "[BlobManager] config read failed:",
            file.configPath,
            "|", error
        )

        const nextIndex = file.configIndex + 1
        file.destroy()
        _tryConfig(nextIndex)
    }

    function modules(blobId) {
        return blobs[blobId] || []
    }

    function blobOf(moduleId) {
        console.log("[BlobManager] blobOf:", moduleId)

        for (const blobId of Object.keys(blobs)) {
            const list = blobs[blobId] || []

            if (list.indexOf(moduleId) !== -1) {
                console.log("[BlobManager] found:", moduleId, "=>", blobId)
                return blobId
            }
        }

        console.log("[BlobManager] not found:", moduleId)
        return ""
    }

    function setBlob(blobId, moduleIds) {
        if (!blobs.hasOwnProperty(blobId)) {
            console.warn("[BlobManager] invalid blob:", blobId)
            return
        }

        if (!Array.isArray(moduleIds))
            return

        const next = Object.assign({}, blobs)
        next[blobId] = moduleIds.filter(v => typeof v === "string")
        blobs = next

        save()
    }

    function save() {
        if (!_activePath) {
            console.warn("[BlobManager] save skipped: no active config")
            return
        }

        const data = JSON.parse(JSON.stringify(_configData))

        data.blobs = {
            tr: blobs.tr,
            tl: blobs.tl,
            tc: blobs.tc,
            br: blobs.br,
            bl: blobs.bl,
            bc: blobs.bc,
            left: blobs.left,
            right: blobs.right
        }

        const f = writerComponent.createObject(root, {
            path: _activePath
        })

        if (!f) {
            console.warn("[BlobManager] failed to create writer")
            return
        }

        const text = JSON.stringify(data, null, 4)

        console.log("[BlobManager] saving:", _activePath)
        console.log("[BlobManager] new blob config:", JSON.stringify(data.blobs))

        f.setText(text)
    }

    Component {
        id: configComponent

        FileView {
            property int configIndex: -1
            property string configPath: ""

            blockLoading: true
            printErrors: false

            onLoadedChanged: {
                if (loaded)
                    root._configLoaded(this)
            }

            onLoadFailed: function(error) {
                root._configFailed(this, error)
            }
        }
    }

    Component {
        id: writerComponent

        FileView {
            property string targetPath: ""

            atomicWrites: true
            printErrors: true

            onSaved: {
                console.log("[BlobManager] saved:", path)
                destroy()
            }

            onSaveFailed: function(error) {
                console.warn("[BlobManager] save failed:", path, "|", error)
                destroy()
            }
        }
    }

    Component.onCompleted: {
        console.log("[BlobManager] started")
        loadConfig()
    }

    onBlobsChanged: {
        console.log("[BlobManager] blobsChanged:", JSON.stringify(blobs))
    }
}
