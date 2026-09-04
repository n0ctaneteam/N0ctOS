import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property list<string> searchPaths: []
    readonly property var registry: _registry
    readonly property int moduleCount: Object.keys(_registry).length

    property var _registry: ({})
    property var _jobs: []

    function discoverModules() {
        console.log("[ModuleRegistry] discoverModules:", JSON.stringify(searchPaths))

        _jobs.forEach(j => j.destroy())
        _jobs = []
        _registry = ({})

        for (const path of searchPaths) {
            if (!path)
                continue
            _crawl(path)
        }
    }

    function get(id) {
        return _registry[id] || null
    }

    function has(id) {
        return !!_registry[id]
    }

    function _crawl(path) {
        if (!path || !path.length)
            return
    
        console.log("[ModuleRegistry] crawl:", path)
    
        const p = crawlComponent.createObject(root, {
            crawlPath: path
        })
    
        if (!p) {
            console.warn("[ModuleRegistry] failed to create Process:", path)
            return
        }
    
        _jobs.push(p)
        p.running = true
    }

    

    function _crawlFinished(process, output) {
        const path = process.crawlPath

        console.log("[ModuleRegistry] crawl finished:", path)
        console.log("[ModuleRegistry] manifests:", JSON.stringify(output))

        const manifests = output.trim() ? output.trim().split("\n") : []

        for (const manifest of manifests) {
            if (manifest.trim())
                _loadManifest(manifest.trim())
        }
    }

    function _loadManifest(path) {
        console.log("[ModuleRegistry] loading:", path)

        const f = manifestComponent.createObject(root, {
            manifestPath: path,
            path: path
        })

        if (!f) {
            console.warn("[ModuleRegistry] failed to create manifest reader:", path)
            return
        }

        _jobs.push(f)
    }

    function _manifestLoaded(file) {
        const path = file.manifestPath
    
        try {
            const data = JSON.parse(file.text())
    
            console.log(
                "[ModuleRegistry] manifest:",
                path,
                "|",
                JSON.stringify(data)
            )
    
            if (!data.id || !data.name || !data.module || !data.settings)
                throw new Error("manifest requires id, name, module and settings")
    
            const base = path.substring(0, path.lastIndexOf("/"))
    
            const entry = {
                id: data.id,
                name: data.name,
                icon: data.icon || "",
                modulePath: base + "/" + data.module,
                settingsPath: base + "/" + data.settings,
                fullPath: base,
                manifestPath: path
            }
    
            if (_registry[data.id]) {
                console.warn(
                    "[ModuleRegistry] duplicate:",
                    data.id,
                    "| keeping existing entry"
                )
                file.destroy()
                return
            }
    
            const next = Object.assign({}, _registry)
            next[data.id] = entry
            _registry = next
    
            console.log(
                "[ModuleRegistry] REGISTERED:",
                data.id,
                "| module:",
                entry.modulePath
            )
        } catch (e) {
            console.warn(
                "[ModuleRegistry] manifest error:",
                path,
                "|",
                e
            )
        }
    
        file.destroy()
    }

    function _manifestFailed(file, error) {
        console.warn(
            "[ModuleRegistry] manifest read failed:",
            file.manifestPath,
            "|", error
        )
        file.destroy()
    }

    Component {
        id: crawlComponent
    
        Process {
            id: process
    
            property string crawlPath: ""
    
            command: [
                "/usr/bin/find",
                crawlPath,
                "-mindepth", "2",
                "-maxdepth", "2",
                "-type", "f",
                "-name", "manifest.json"
            ]
    
            stdout: StdioCollector {
                id: out
            }
    
            stderr: StdioCollector {
                id: err
            }
    
            onExited: function(exitCode, exitStatus) {
                console.log(
                    "[ModuleRegistry] find exited:",
                    crawlPath,
                    "| code:", exitCode
                )
    
                if (err.text.trim())
                    console.warn(
                        "[ModuleRegistry] find stderr:",
                        err.text.trim()
                    )
    
                if (out.text.trim()) {
                    const manifests = out.text.trim().split("\n")
    
                    console.log(
                        "[ModuleRegistry] found",
                        manifests.length,
                        "manifest(s):",
                        JSON.stringify(manifests)
                    )
    
                    for (const manifest of manifests) {
                        const p = manifest.trim()
    
                        if (p.length)
                            root._loadManifest(p)
                    }
                } else {
                    console.log(
                        "[ModuleRegistry] no manifests found in:",
                        crawlPath
                    )
                }
    
                const index = root._jobs.indexOf(process)
    
                if (index !== -1)
                    root._jobs.splice(index, 1)
    
                Qt.callLater(function() {
                    process.destroy()
                })
            }
        }
    }

    Component {
        id: manifestComponent
    
        FileView {
            property string manifestPath: ""
    
            blockLoading: true
            printErrors: true
    
            onLoadedChanged: {
                if (!loaded)
                    return
    
                root._manifestLoaded(this)
            }
    
            onLoadFailed: function(error) {
                root._manifestFailed(this, error)
            }
        }

        
    }

    Component.onCompleted: {
        console.log("[ModuleRegistry] started")
        discoverModules()
    }

    onRegistryChanged: {
        console.log(
            "[ModuleRegistry] registry changed | count:",
            moduleCount,
            "| ids:",
            JSON.stringify(Object.keys(_registry))
        )
    }
}
