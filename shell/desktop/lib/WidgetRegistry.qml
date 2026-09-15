pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // SEARCH PATHS
    // ============================================================

    /*
     * Priority:
     *
     *     0 = highest priority
     *
     * Earlier paths win when duplicate widget IDs are found.
     *
     * Built-in:
     *     /usr/share/N0ctOS/desktop/widgets
     *
     * System-local:
     *     /usr/share/N0ctOS/local/widgets
     *
     * User:
     *     ~/.config/N0ctOS/widgets
     *
     * This also makes local/user widgets capable of overriding
     * manifests from lower-priority locations simply by placing
     * them earlier in this list when desired.
     */
    property list<string> searchPaths: [
        Quickshell.shellPath("desktop/widgets"),
        "/usr/share/N0ctOS/local/widgets",
        Quickshell.env("HOME") + "/.config/N0ctOS/widgets"
    ]

    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property var registry:
        root._registry

    readonly property int widgetCount:
        Object.keys(root._registry).length

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
            try {
                job.destroy()
            } catch (e) {
            }
        })

        root._jobs = []
        root._registry = ({})

        /*
         * Paths are processed in priority order.
         *
         * _registerEntry() keeps the first ID it encounters.
         */
        for (const path of root.searchPaths) {
            if (!path)
                continue

            root._crawl(path)
        }
    }

    function get(id) {
        if (!id)
            return null

        return root._registry[String(id)] || null
    }

    function has(id) {
        return !!root.get(id)
    }

    function ids() {
        return Object.keys(root._registry)
    }

    // ============================================================
    // DIRECTORY CRAWLER
    // ============================================================

    function _crawl(path) {
        if (!path || !path.length)
            return

        const process =
            crawlComponent.createObject(
                root,
                {
                    crawlPath: path
                }
            )

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

    function _crawlFinished(process, output) {
        const path =
            process.crawlPath

        console.log(
            "[WidgetRegistry] crawl finished:",
            path
        )

        const manifests =
            output.trim()
                ? output.trim().split("\n")
                : []

        for (const manifest of manifests) {
            const value =
                String(manifest).trim()

            if (value.length)
                root._loadManifest(value)
        }
    }

    // ============================================================
    // MANIFEST READER
    // ============================================================

    function _loadManifest(path) {
        console.log(
            "[WidgetRegistry] loading:",
            path
        )

        const file =
            manifestComponent.createObject(
                root,
                {
                    manifestPath: path,
                    path: path
                }
            )

        if (!file) {
            console.warn(
                "[WidgetRegistry] failed to create manifest reader:",
                path
            )
            return
        }

        root._jobs.push(file)
    }

    function _manifestLoaded(file) {
        const manifestPath =
            file.manifestPath

        try {
            const data =
                JSON.parse(file.text())

            root._validateManifest(
                manifestPath,
                data
            )

            const base =
                manifestPath.substring(
                    0,
                    manifestPath.lastIndexOf("/")
                )

            const entry = {
                // ------------------------------------------------
                // Identity
                // ------------------------------------------------

                id:
                    String(data.id),

                name:
                    String(data.name),

                description:
                    String(data.description || ""),

                author:
                    String(data.author || ""),

                category:
                    String(
                        data.category ||
                        data.catagory ||
                        "general"
                    ),

                icon:
                    String(data.icon || ""),

                previewPath:
                    data.preview
                        ? base + "/" + String(data.preview)
                        : "",

                // ------------------------------------------------
                // Main component
                // ------------------------------------------------

                widgetPath:
                    base + "/" + String(data.widget),

                // ------------------------------------------------
                // Optional service
                // ------------------------------------------------

                servicePath:
                    data.service
                        ? base + "/" + String(data.service)
                        : "",

                // ------------------------------------------------
                // Manifest metadata
                // ------------------------------------------------

                canIntersect:
                    data.canIntersect !== undefined
                        ? Boolean(data.canIntersect)
                        : false,

                allowMultiple:
                    data.allowMultiple !== undefined
                        ? Boolean(data.allowMultiple)
                        : false,

                resizable:
                    data.resizable !== undefined
                        ? Boolean(data.resizable)
                        : false,

                interaction:
                    data.interaction &&
                    typeof data.interaction === "object"
                        ? Object.assign(
                            {},
                            data.interaction
                        )
                        : ({
                            click: true,
                            rightClick: true,
                            hover: false,
                            focus: false,
                            passMouseEvents: false
                        }),

                variants:
                    Array.isArray(data.variants)
                        ? data.variants.slice()
                        : [],

                // ------------------------------------------------
                // Paths
                // ------------------------------------------------

                basePath:
                    base,

                manifestPath:
                    manifestPath
            }

            /*
             * First registration wins.
             *
             * Because search paths are processed in order,
             * earlier paths have higher priority.
             */
            if (root._registry[entry.id]) {
                console.warn(
                    "[WidgetRegistry] duplicate:",
                    entry.id,
                    "| keeping:",
                    root._registry[entry.id].manifestPath,
                    "| ignoring:",
                    manifestPath
                )

                file.destroy()
                return
            }

            const next =
                Object.assign(
                    {},
                    root._registry
                )

            next[entry.id] =
                entry

            root._registry =
                next

            console.log(
                "[WidgetRegistry] REGISTERED:",
                entry.id,
                "| widget:",
                entry.widgetPath
            )
        } catch (e) {
            console.warn(
                "[WidgetRegistry] manifest error:",
                manifestPath,
                "|",
                e
            )
        }

        file.destroy()
    }

    function _validateManifest(path, data) {
        if (!data || typeof data !== "object")
            throw new Error(
                "manifest is not an object"
            )

        if (!data.id)
            throw new Error(
                "manifest requires id"
            )

        if (!data.name)
            throw new Error(
                "manifest requires name"
            )

        if (!data.description)
            throw new Error(
                "manifest requires description"
            )

        if (!data.author)
            throw new Error(
                "manifest requires author"
            )

        if (!data.widget)
            throw new Error(
                "manifest requires widget"
            )

        if (!data.preview)
            throw new Error(
                "manifest requires preview"
            )

        const id =
            String(data.id).trim()

        if (!id.length)
            throw new Error(
                "manifest id cannot be empty"
            )

        if (
            id.indexOf("/") !== -1 ||
            id.indexOf("\\") !== -1
        )
            throw new Error(
                "manifest id cannot contain path separators"
            )

        const widget =
            String(data.widget).trim()

        if (!widget.length)
            throw new Error(
                "manifest widget path cannot be empty"
            )

        /*
         * Prevent absolute component paths from escaping the
         * plugin directory.
         */
        if (
            widget.startsWith("/") ||
            widget.startsWith("\\")
        )
            throw new Error(
                "widget path must be relative to plugin directory"
            )

        console.log(
            "[WidgetRegistry] VALID:",
            path
        )
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
    // CRAWL PROCESS
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

            onExited: function(
                exitCode,
                exitStatus
            ) {
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
                        out.text
                            .trim()
                            .split("\n")

                    console.log(
                        "[WidgetRegistry] found",
                        manifests.length,
                        "manifest(s)"
                    )

                    for (
                        const manifest
                        of manifests
                    ) {
                        const path =
                            manifest.trim()

                        if (path.length)
                            root._loadManifest(
                                path
                            )
                    }
                } else {
                    console.log(
                        "[WidgetRegistry] no manifests found in:",
                        crawlPath
                    )
                }

                const index =
                    root._jobs.indexOf(
                        process
                    )

                if (index !== -1)
                    root._jobs.splice(
                        index,
                        1
                    )

                Qt.callLater(function() {
                    process.destroy()
                })
            }
        }
    }

    // ============================================================
    // FILE READER
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

                root._manifestLoaded(
                    this
                )
            }

            onLoadFailed:
                function(error) {
                    root._manifestFailed(
                        this,
                        error
                    )
                }
        }
    }

    // ============================================================
    // SIGNALS / LIFECYCLE
    // ============================================================

    onRegistryChanged: {
        console.log(
            "[WidgetRegistry] registry changed:",
            Object.keys(
                root._registry
            ).length,
            "| ids:",
            JSON.stringify(
                Object.keys(
                    root._registry
                )
            )
        )
    }

    Component.onCompleted: {
        console.log(
            "[WidgetRegistry] started"
        )

        root.discoverWidgets()
    }
}