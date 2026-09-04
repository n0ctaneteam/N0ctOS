import QtQuick

FocusScope {
    id: root

    property string moduleId: ""
    property Item focusTarget: null
    property var variant: null
    readonly property Item variantItem: variantLoader.item
    readonly property bool moduleFocused: root.activeFocus
    readonly property bool childFocused: root.Window && root.Window.activeFocusItem ? root.containsFocus(root.Window.activeFocusItem) : false

    readonly property Item parentBlob: {
        let p = root.parent
        while (p) {
            if (p.hasOwnProperty("blobId")) return p
            p = p.parent
        }
        return null
    }

    readonly property bool isVertical: root.parentBlob ? !!root.parentBlob.isVertical : false

    signal activated()
    signal deactivated()

    function containsFocus(item) {
        let p = item
        while (p) {
            if (p === root) return true
            p = p.parent
        }
        return false
    }

    function focusModule() {
        if (root.focusTarget && typeof root.focusTarget.forceActiveFocus === "function") {
            root.focusTarget.forceActiveFocus()
            return
        }
        root.forceActiveFocus()
    }

    function activate() {
        root.activated()
        if (root.focusTarget) Qt.callLater(root.focusModule)
    }

    function deactivate() {
        root.deactivated()
    }

    function loadVariant(value, component) {
        if (root.variant === value && variantLoader.sourceComponent === component) return
        root.variant = value
        variantLoader.sourceComponent = component
    }

    function clearVariant() {
        root.variant = null
        variantLoader.sourceComponent = null
    }

    Loader {
        id: variantLoader
        onLoaded: if (root.focusTarget) Qt.callLater(root.focusModule)
    }

    implicitWidth: variantLoader.item
        ? Number(variantLoader.item.implicitWidth || variantLoader.item.width || root.childrenRect.width)
        : root.childrenRect.width

    implicitHeight: variantLoader.item
        ? Number(variantLoader.item.implicitHeight || variantLoader.item.height || root.childrenRect.height)
        : root.childrenRect.height

    onFocusTargetChanged: if (root.focusTarget) Qt.callLater(root.focusModule)
}