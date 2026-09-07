import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var moduleRegistry

    property string configPath: Quickshell.shellPath("config.json")

    readonly property var services: _services
    readonly property var loadedModuleIds: Object.keys(_services)

    property var _services: ({})
    property var _selectedModuleIds: ({})
    property var _pendingComponents: ({})

    function get(moduleId) {
        return _services[moduleId] || null
    }

    function has(moduleId) {
        return !!_services[moduleId]
    }

    function _readConfig() {
        try {
            const data = JSON.parse(configFile.text())
            const blobs = data.blobs || {}
            const selected = {}

            for (const blobId of Object.keys(blobs)) {
                const modules = blobs[blobId]

                if (!Array.isArray(modules))
                    continue

                for (const moduleId of modules) {
                    if (moduleId)
                        selected[moduleId] = true
                }
            }

            _selectedModuleIds = selected

            console.log(
                "[ServiceManager] selected modules:",
                JSON.stringify(Object.keys(_selectedModuleIds))
            )

            _syncServices()
        } catch (e) {
            console.warn(
                "[ServiceManager] config parse error:",
                e
            )
        }
    }

    function _syncServices() {
        if (!moduleRegistry)
            return

        const selected = Object.keys(_selectedModuleIds)

        for (const moduleId of selected) {
            if (_services[moduleId])
                continue

            const info = moduleRegistry.get(moduleId)

            if (!info) {
                console.log(
                    "[ServiceManager] waiting for module:",
                    moduleId
                )
                continue
            }

            if (!info.servicePath) {
                console.log(
                    "[ServiceManager] no Service.qml:",
                    moduleId
                )
                continue
            }

            _createService(moduleId, info)
        }

        for (const moduleId of Object.keys(_services)) {
            if (!_selectedModuleIds[moduleId])
                _destroyService(moduleId)
        }
    }

    function _createService(moduleId, info) {
        if (_services[moduleId])
            return

        const url = info.servicePath

        console.log(
            "[ServiceManager] creating service:",
            moduleId,
            "|",
            url
        )

        const component = Qt.createComponent(url)

        if (component.status === Component.Error) {
            console.warn(
                "[ServiceManager] Service.qml error:",
                moduleId,
                "|",
                component.errorString()
            )
            component.destroy()
            return
        }

        if (component.status === Component.Loading) {
            _pendingComponents[moduleId] = component

            component.statusChanged.connect(function() {
                if (component.status !== Component.Ready &&
                    component.status !== Component.Error)
                    return

                delete _pendingComponents[moduleId]

                if (component.status === Component.Error) {
                    console.warn(
                        "[ServiceManager] Service.qml load error:",
                        moduleId,
                        "|",
                        component.errorString()
                    )
                    component.destroy()
                    return
                }

                root._instantiateService(moduleId, info, component)
            })

            return
        }

        _instantiateService(moduleId, info, component)
    }

    function _instantiateService(moduleId, info, component) {
        if (_services[moduleId]) {
            component.destroy()
            return
        }

        const service = component.createObject(root, {
            moduleId: moduleId,
            moduleInfo: info,
            serviceManager: root
        })

        if (!service) {
            console.warn(
                "[ServiceManager] failed to create service:",
                moduleId
            )
            component.destroy()
            return
        }

        const next = Object.assign({}, _services)
        next[moduleId] = service
        _services = next

        console.log(
            "[ServiceManager] SERVICE LOADED:",
            moduleId
        )

        if (typeof service.start === "function")
            service.start()
    }

    function _destroyService(moduleId) {
        const service = _services[moduleId]

        if (!service)
            return

        console.log(
            "[ServiceManager] destroying service:",
            moduleId
        )

        if (typeof service.stop === "function")
            service.stop()

        service.destroy()

        const next = Object.assign({}, _services)
        delete next[moduleId]
        _services = next
    }

    FileView {
        id: configFile
        path: root.configPath
        blockLoading: true
        printErrors: true

        onLoadedChanged: {
            if (!loaded)
                return

            root._readConfig()
        }

        onLoadFailed: function(error) {
            console.warn(
                "[ServiceManager] config load failed:",
                error
            )
        }
    }

    Connections {
        target: root.moduleRegistry

        function onRegistryChanged() {
            root._syncServices()
        }
    }

    Component.onCompleted: {
        console.log("[ServiceManager] started")
    }

    Component.onDestruction: {
        for (const moduleId of Object.keys(_services))
            _destroyService(moduleId)

        for (const moduleId of Object.keys(_pendingComponents)) {
            const component = _pendingComponents[moduleId]

            if (component)
                component.destroy()
        }
    }
}