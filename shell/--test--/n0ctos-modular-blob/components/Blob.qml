import QtQuick
import QtQuick.Controls
import "../core" as Core

Item {
    id: root

    required property string blobId
    required property QtObject registry
    required property QtObject moduleManager
    property var configuredModuleIds: []
    property bool singleModuleOpensOnHover: true
    property bool showPlaceholder: true
    property color surfaceColor: "#cc111318"
    property color borderColor: "#33ffffff"
    property real cornerRadius: 28

    readonly property var configuredModules: _resolveConfiguredModules()
    readonly property int moduleCount: configuredModules.length
    readonly property bool hovered: hoverArea.containsMouse
    readonly property string currentModuleId: moduleHost.moduleId
    readonly property bool hasActiveModule: moduleHost.active
    readonly property var moduleInstance: moduleHost.item

    signal moduleSelected(string moduleId)
    signal moduleClosed(string moduleId)

    function hasConfiguredModule(moduleId: string): bool {
        return configuredModuleIds.indexOf(moduleId) !== -1;
    }

    function activateModule(moduleId: string, requestFocus: bool = true, source: string = "selector"): bool {
        if (!hasConfiguredModule(moduleId)) return false;
        const descriptor = registry.get(moduleId);
        if (!descriptor) return false;

        root._activationSource = source;
        root._suppressSingleHover = false;
        moduleHost.moduleId = moduleId;
        moduleHost.modulePath = descriptor.modulePath;
        moduleHost.metadata = descriptor;
        moduleHost.activate(requestFocus);
        root.moduleSelected(moduleId);
        return true;
    }

    function selectModule(moduleId: string): bool {
        return moduleManager.activateIn(moduleId, root.blobId, true);
    }

    function focusModule(moduleId: string = root.currentModuleId): bool {
        if (!moduleId || root.currentModuleId !== moduleId) return false;
        moduleHost.focusModule();
        return true;
    }

    function deactivateModule(moduleId: string = root.currentModuleId): bool {
        if (!moduleId || root.currentModuleId !== moduleId) return false;
        moduleHost.deactivate();
        root._activationSource = "";
        root.moduleClosed(moduleId);
        return true;
    }

    function _resolveConfiguredModules(): var {
        const result = [];
        for (let i = 0; i < configuredModuleIds.length; ++i) {
            const id = String(configuredModuleIds[i]);
            const descriptor = registry.get(id);
            if (descriptor) result.push(descriptor);
        }
        return result;
    }

    property string _activationSource: ""
    property bool _suppressSingleHover: false

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.surfaceColor
        border.width: 1
        border.color: root.borderColor
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 1
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.margins: 8
        z: 2

        // The selector and module occupy exactly the same host.
        // The state change is intentionally animated as one piece instead of switching two separate panels.
        ModuleSelector {
            id: selector
            anchors.centerIn: parent
            modules: root.configuredModules
            visible: root.hovered && !root.hasActiveModule && root.moduleCount > 1
            opacity: visible ? 1 : 0
            scale: visible ? 1 : 0.92

            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            onSelected: root.selectModule(moduleId)
        }

        Item {
            anchors.fill: parent
            visible: root.hasActiveModule
            opacity: visible ? 1 : 0
            scale: visible ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

            Core.Module {
                id: moduleHost
                anchors.fill: parent
                autoFocusOnActivate: true
            }

            Connections {
                target: moduleHost
                function onCloseRequested() {
                    root.deactivateModule();
                }
                function onLoadFailed(error) {
                    console.warn("N0ctOS: module", root.currentModuleId, "failed to load:", error);
                    root.deactivateModule();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.showPlaceholder && !root.hasActiveModule && !root.hovered && root.moduleCount > 1
            text: root.blobId
            opacity: 0.28
            color: "white"
        }
    }

    Timer {
        id: singleModuleTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.hovered && root.moduleCount === 1 && root.singleModuleOpensOnHover && !root.hasActiveModule) {
                moduleManager.activateIn(String(root.configuredModules[0].id), root.blobId, false);
            }
        }
    }

    onHoveredChanged: {
        if (hovered && moduleCount === 1 && singleModuleOpensOnHover && !hasActiveModule) {
            singleModuleTimer.start();
        }
    }

    Component.onCompleted: moduleManager.registerBlob(root)
    Component.onDestruction: moduleManager.unregisterBlob(root)

}
