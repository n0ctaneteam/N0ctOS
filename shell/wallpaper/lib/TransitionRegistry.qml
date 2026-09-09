pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property list<string> searchPaths: [
        Quickshell.shellPath(
            "wallpaper/transitions"
        ),
        "/usr/share/N0ctOS/local/plugins/transitions",
        Quickshell.env("HOME") +
            "/.config/N0ctOS/plugin/transitions"
    ]

    readonly property var registry:
        _registry

    readonly property int transitionCount:
        Object.keys(_registry).length

    property var _registry: ({})
    property var _jobs: []

    function expandPath(path) {
        if (!path)
            return ""

        var value =
            String(path).trim()

        if (value === "~")
            return Quickshell.env("HOME") || value

        if (value.startsWith("~/"))
            return (
                Quickshell.env("HOME") || ""
            ) + value.slice(1)

        return value
    }

    function toUrl(path) {
        if (!path)
            return ""

        var value =
            root.expandPath(path)

        if (value.startsWith("file://") ||
            value.startsWith("http://") ||
            value.startsWith("https://"))
            return value

        if (value.startsWith("/"))
            return "file://" + value

        return value
    }

    function get(id) {
        return _registry[id] || null
    }

    function has(id) {
        return !!_registry[id]
    }

    function ids() {
        return Object.keys(_registry)
    }

    function discover() {
        console.log(
            "[TransitionRegistry] DISCOVER"
        )

        _jobs.forEach(function(job) {
            if (job)
                job.destroy()
        })

        _jobs = []
        _registry = ({})

        for (var i = 0;
             i < searchPaths.length;
             ++i) {

            var path =
                root.expandPath(
                    searchPaths[i]
                )

            if (!path)
                continue

            console.log(
                "[TransitionRegistry] PATH",
                i,
                ":",
                path
            )

            _crawl(path, i)
        }
    }

    function _crawl(path, priority) {
        var process =
            crawlComponent.createObject(
                root,
                {
                    crawlPath: path,
                    priority: priority
                }
            )

        if (!process) {
            console.warn(
                "[TransitionRegistry] failed to create crawler:",
                path
            )

            return
        }

        _jobs.push(process)
        process.running = true
    }

    function _loadManifest(path, priority) {
        var file =
            manifestComponent.createObject(
                root,
                {
                    manifestPath: path,
                    priority: priority,
                    path: path
                }
            )

        if (!file) {
            console.warn(
                "[TransitionRegistry] failed to create manifest reader:",
                path
            )

            return
        }

        _jobs.push(file)
    }

    function _manifestLoaded(file) {
        var path =
            file.manifestPath

        try {
            var data =
                JSON.parse(
                    file.text()
                )

            if (!data.id ||
                !data.name ||
                !data.author ||
                !data.version ||
                !data.type ||
                !data.path) {

                throw new Error(
                    "manifest requires id, name, author, version, type and path"
                )
            }

            var base =
                path.substring(
                    0,
                    path.lastIndexOf("/")
                )

            var existing =
                _registry[data.id]

            /*
             * Higher priority means later in searchPaths.
             * This comparison is based on the declared path
             * priority rather than manifest loading order.
             */
            if (existing &&
                existing.priority > file.priority) {

                console.log(
                    "[TransitionRegistry] IGNORE",
                    data.id,
                    "| lower priority",
                    file.priority,
                    "<",
                    existing.priority
                )

                file.destroy()
                return
            }

            var componentPath =
                root.expandPath(
                    base + "/" + data.path
                )

            var entry = {
                id: data.id,
                name: data.name,
                author: data.author,
                version: data.version,
                type: data.type,
                icon: data.icon || "",
                description:
                    data.description || "",

                componentPath:
                    componentPath,

                componentUrl:
                    root.toUrl(
                        componentPath
                    ),

                fullPath:
                    base,

                manifestPath:
                    path,

                parameters:
                    data.parameters &&
                    typeof data.parameters === "object" &&
                    !Array.isArray(data.parameters)
                        ? Object.assign(
                            {},
                            data.parameters
                        )
                        : {},

                priority:
                    file.priority
            }

            var next =
                Object.assign(
                    {},
                    _registry
                )

            next[data.id] = entry
            _registry = next

            console.log(
                "[TransitionRegistry] REGISTERED",
                data.id,
                "|",
                entry.componentPath,
                "| priority:",
                entry.priority
            )
        } catch (e) {
            console.warn(
                "[TransitionRegistry] manifest error:",
                path,
                "|",
                e
            )
        }

        file.destroy()
    }

    function _manifestFailed(file, error) {
        console.warn(
            "[TransitionRegistry] manifest read failed:",
            file.manifestPath,
            "|",
            error
        )

        file.destroy()
    }

    Component {
        id: crawlComponent

        Process {
            property string crawlPath: ""
            property int priority: 0

            command: [
                "/usr/bin/find",
                root.expandPath(crawlPath),
                "-mindepth", "2",
                "-maxdepth", "2",
                "-type", "f",
                "-name", "manifest.json"
            ]

            stdout: StdioCollector {
                id: output
            }

            stderr: StdioCollector {
                id: errors
            }

            onExited: function(exitCode, exitStatus) {
                if (errors.text.trim()) {
                    console.warn(
                        "[TransitionRegistry] find stderr:",
                        errors.text.trim()
                    )
                }

                if (exitCode !== 0) {
                    console.warn(
                        "[TransitionRegistry] find failed:",
                        crawlPath,
                        "| code:",
                        exitCode
                    )
                }

                if (output.text.trim()) {
                    var manifests =
                        output.text
                            .trim()
                            .split("\n")

                    for (var i = 0;
                         i < manifests.length;
                         ++i) {

                        var manifest =
                            manifests[i].trim()

                        if (manifest)
                            root._loadManifest(
                                manifest,
                                priority
                            )
                    }
                }

                var index =
                    root._jobs.indexOf(this)

                if (index !== -1)
                    root._jobs.splice(
                        index,
                        1
                    )

                Qt.callLater(function() {
                    this.destroy()
                }.bind(this))
            }
        }
    }

    Component {
        id: manifestComponent

        FileView {
            property string manifestPath: ""
            property int priority: 0

            blockLoading: true
            printErrors: true

            onLoadedChanged: {
                if (loaded)
                    root._manifestLoaded(this)
            }

            onLoadFailed: function(error) {
                root._manifestFailed(
                    this,
                    error
                )
            }
        }
    }

    Component.onCompleted: {
        console.log(
            "[TransitionRegistry] START"
        )

        root.discover()
    }

    onRegistryChanged: {
        console.log(
            "[TransitionRegistry] REGISTRY:",
            transitionCount,
            JSON.stringify(ids())
        )
    }
}