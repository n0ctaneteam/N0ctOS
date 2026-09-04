import QtQuick

FocusScope {
    id: root

    property string moduleId: ""
    property string modulePath: ""
    property var metadata: ({})
    property bool active: false
    property bool focused: false
    property bool autoFocusOnActivate: true
    property string lifecycleState: "idle"
    property alias item: loader.item
    property alias status: loader.status
    readonly property string displayName: String(metadata.name || moduleId)

    signal activated()
    signal deactivated()
    signal focusAcquired()
    signal focusReleased()
    signal closeRequested()
    signal loadFailed(string error)

    function activate(requestFocus: bool = root.autoFocusOnActivate): void {
        root.active = true;
        root.lifecycleState = "activating";
        if (requestFocus) {
            root.focusModule();
        }
    }

    function deactivate(): void {
        root.focused = false;
        root.focus = false;
        root.active = false;
        root.lifecycleState = "deactivating";
        loader.source = "";
        root.moduleId = "";
        root.modulePath = "";
        root.metadata = ({});
        root.lifecycleState = "idle";
        root.deactivated();
    }

    function focusModule(): void {
        root.focused = true;
        root.focus = true;
        if (loader.item) {
            loader.item.forceActiveFocus();
        } else {
            focusAfterLoad.start();
        }
        root.focusAcquired();
    }

    function releaseFocus(): void {
        root.focused = false;
        root.focus = false;
        root.focusReleased();
    }

    function close(): void {
        root.closeRequested();
    }

    Keys.priority: Keys.BeforeItem
    Keys.onEscapePressed: event => {
        if (root.active) {
            event.accepted = true;
            root.closeRequested();
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        asynchronous: false
        active: root.active && root.modulePath.length > 0
        source: root.modulePath.length > 0 ? root.modulePath : ""

        onStatusChanged: {
            if (status === Loader.Ready) {
                root.lifecycleState = root.active ? "active" : "idle";
                activatedIfNeeded.start();
            } else if (status === Loader.Error) {
                root.lifecycleState = "error";
                root.loadFailed(loader.item ? "unknown loader error" : "failed to create module");
            }
        }
    }

    Timer {
        id: activatedIfNeeded
        interval: 0
        repeat: false
        onTriggered: {
            if (root.active && root.autoFocusOnActivate && root.focused && loader.item) {
                loader.item.forceActiveFocus();
            }
            root.activated();
        }
    }

    Timer {
        id: focusAfterLoad
        interval: 0
        repeat: false
        onTriggered: {
            if (root.active && root.focused && loader.item) {
                loader.item.forceActiveFocus();
            }
        }
    }
}
