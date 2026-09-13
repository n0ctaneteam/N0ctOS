pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property list<string> searchPaths: [Quickshell.shellPath("desktop/widgets")]

    readonly property var registry: _registry
    readonly property int widgetCount: Object.keys(_registry).length

    property var _registry: ({})
    property var _jobs: []

    // ============================================================
    // DISCOVERY
    // ============================================================

    function discoverWidgets() {
        console.log(
            "[WidgetRegistry] discoverWidgets:",
            JSON.stringify(root.searchPaths)
        )

        root._jobs.forEach(function(job) {
            if (job)
                job.destroy()
        })

        root._jobs = []
        root._registry = ({ })

        for (const path of root.searchPaths) {
            if (!path)
                continue

            root._crawl(path)
        }
    }

    function get(id) {
        return root._registry[id] || null
    }

    function has(id) {
        return !!root._registry[id]
    }

    function _crawl(path) {
        if (!path || !path.length)
            return

        console.log(
            "[WidgetRegistry] crawl:",
            path
        )

        const process =
            crawlComponent.createObject(root, {
                crawlPath: path
            })

        if (!process) {
            console.warn(
                "[WidgetRegistry] failed to create Process:",
                path
            )
            return
        }

        root._jobs.push(process)
        process.running = true
    }

    function _loadManifest(path) {
        console.log(
            "[WidgetRegistry] loading:",
            path
        )

        const file =
            manifestComponent.createObject(root, {
                manifestPath: path,
                path: path
            })

        if (!file) {
            console.warn(
                "[WidgetRegistry] failed to create manifest reader:",
                path
            )
            return
        }

        root._jobs.push(file)
    }

    // ============================================================
    // MANIFEST
    // ============================================================

    function _manifestLoaded(file) {
        const path = file.manifestPath

        try {
            const data = JSON.parse(file.text())

            console.log(
                "[WidgetRegistry] manifest:",
                path,
                "|",
                JSON.stringify(data)
            )

            // ----------------------------------------------------
            // REQUIRED FIELDS
            // ----------------------------------------------------

            if (
                !data.id ||
                !data.name ||
                !data.description ||
                !data.author ||
                !data.widget ||
                !data.preview
            ) {
                throw new Error(
                    "manifest requires " +
                    "id, name, description, author, widget and preview"
                )
            }

            // ----------------------------------------------------
            // TYPE VALIDATION
            // ----------------------------------------------------

            if (typeof data.id !== "string")
                throw new Error("manifest field 'id' must be a string")

            if (typeof data.name !== "string")
                throw new Error("manifest field 'name' must be a string")

            if (typeof data.description !== "string")
                throw new Error(
                    "manifest field 'description' must be a string"
                )

            if (typeof data.author !== "string")
                throw new Error(
                    "manifest field 'author' must be a string"
                )

            if (typeof data.widget !== "string")
                throw new Error(
                    "manifest field 'widget' must be a string"
                )

            if (typeof data.preview !== "string")
                throw new Error(
                    "manifest field 'preview' must be a string"
                )

            if (
                data.service !== undefined &&
                data.service !== null &&
                typeof data.service !== "string"
            ) {
                throw new Error(
                    "manifest field 'service' must be a string"
                )
            }

            if (
                data.category !== undefined &&
                data.category !== null &&
                typeof data.category !== "string"
            ) {
                throw new Error(
                    "manifest field 'category' must be a string"
                )
            }

            // ----------------------------------------------------
            // PATHS
            // ----------------------------------------------------

            const lastSlash = path.lastIndexOf("/")

            if (lastSlash === -1)
                throw new Error("invalid manifest path")

            const base =
                path.substring(0, lastSlash)

            const entry = {
                id: data.id,
                name: data.name,
                description: data.description,
                author: data.author,

                category:
                    data.category !== undefined
                        ? data.category
                        : "",

                widgetPath:
                    base + "/" + data.widget,

                previewPath:
                    base + "/" + data.preview,

                servicePath:
                    data.service
                        ? base + "/" + data.service
                        : "",

                fullPath: base,
                manifestPath: path
            }

            // ----------------------------------------------------
            // DUPLICATES
            //
            // Earlier search paths have priority because the first
            // registered entry is retained.
            // ----------------------------------------------------

            if (root._registry[data.id]) {
                console.warn(
                    "[WidgetRegistry] duplicate:",
                    data.id,
                    "| keeping existing entry:",
                    root._registry[data.id].manifestPath
                )

                file.destroy()
                return
            }

            const next =
                Object.assign({}, root._registry)

            next[data.id] = entry

            root._registry = next

            console.log(
                "[WidgetRegistry] REGISTERED:",
                data.id,
                "| widget:", entry.widgetPath,
                "| preview:", entry.previewPath,
                "| service:",
                entry.servicePath || "<none>",
                "| category:",
                entry.category || "<none>"
            )
        } catch (e) {
            console.warn(
                "[WidgetRegistry] manifest error:",
                path,
                "|",
                e
            )
        }

        file.destroy()
    }

    function _manifestFailed(file, error) {
        console.warn(
            "[WidgetRegistry] manifest read failed:",
            file.manifestPath,
            "|",
            error
        )

        file.destroy()
    }

    // ============================================================
    // CRAWLER
    // ============================================================

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
                    "[WidgetRegistry] find exited:",
                    crawlPath,
                    "| code:",
                    exitCode
                )

                if (err.text.trim()) {
                    console.warn(
                        "[WidgetRegistry] find stderr:",
                        err.text.trim()
                    )
                }

                if (out.text.trim()) {
                    const manifests =
                        out.text.trim().split("\n")

                    console.log(
                        "[WidgetRegistry] found",
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
                        "[WidgetRegistry] no manifests found in:",
                        crawlPath
                    )
                }

                const index =
                    root._jobs.indexOf(process)

                if (index !== -1)
                    root._jobs.splice(index, 1)

                Qt.callLater(function() {
                    process.destroy()
                })
            }
        }
    }

    // ============================================================
    // MANIFEST READER
    // ============================================================

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

    // ============================================================
    // LIFECYCLE
    // ============================================================

    Component.onCompleted: {
        console.log("[WidgetRegistry] started")
        root.discoverWidgets()
    }

    onRegistryChanged: {
        console.log(
            "[WidgetRegistry] registry changed | count:",
            root.widgetCount,
            "| ids:",
            JSON.stringify(
                Object.keys(root._registry)
            )
        )
    }
}