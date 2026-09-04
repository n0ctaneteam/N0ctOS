import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../core/ui"

FocusScope {
    id: root

    required property string blobId
    required property var moduleRegistry
    required property var moduleIds
    required property var focusManager

    property string configPath: Quickshell.shellPath("config.json")
    property string activeModule: ""
    property string selectionModule: ""

    // Logical blob state. This is NOT Qt activeFocus.
    property bool blobFocused: false
    property bool hovered: false

    readonly property bool isBlobFocused: root.blobFocused
    readonly property bool moduleSpecified: root.activeModule !== ""
    readonly property bool showHoverSelector:
        root.hovered &&
        !root.moduleSpecified &&
        root.moduleIds.length > 1
    readonly property bool selectorOpen:
        root.switching ||
        root.mouseSelector ||
        root.showHoverSelector
    readonly property bool showSelector:
        root.moduleIds.length > 1 && root.selectorOpen

    property bool switching: false
    property bool mouseSelector: false
    property bool modifierHeld: false
    property bool switchImmediate: false

    property bool isVertical: false
    property real switcherSize: 56
    property real switcherMinMultiplier: 3
    property real progress: 1

    property color bgColor: "transparent"
    property color borderColor: "transparent"
    property int borderWidth: 0
    property var cut: ({})
    property var round: ({})
    property var shadow: ({})

    property color switcherActiveBG: "#2acfff"
    property color switcherActiveBorder: "#2acfff"
    property string switcherCornerType: "cut"
    property real switcherCornerRadius: 8
    property int animationDuration: 180

    property string switchModifierName: "Super"
    property string switchNextName: "J"
    property string switchPreviousName: "K"
    property int switchModifier: Qt.MetaModifier
    property int switchNextKey: Qt.Key_J
    property int switchPreviousKey: Qt.Key_K

    property var focusItems: []

    readonly property string nextShortcut:
        root.switchModifierName + "+" + root.switchNextName
    readonly property string previousShortcut:
        root.switchModifierName + "+" + root.switchPreviousName
    readonly property string nextQtShortcut:
        (root.switchModifier === Qt.MetaModifier ? "Meta" : root.switchModifierName) +
        "+" + root.switchNextName
    readonly property string previousQtShortcut:
        (root.switchModifier === Qt.MetaModifier ? "Meta" : root.switchModifierName) +
        "+" + root.switchPreviousName

    readonly property var activeInfo:
        root.activeModule ? root.moduleRegistry.get(root.activeModule) : null
    readonly property var activeItem: moduleLoader.item
    readonly property Item focusedItem:
        root.Window ? root.Window.activeFocusItem : null

    readonly property real moduleWidth: {
        if (!moduleLoader.item)
            return root.switcherSize
        return Math.max(
            root.switcherSize,
            Number(moduleLoader.item.implicitWidth ||
                   moduleLoader.item.width ||
                   root.switcherSize)
        )
    }

    readonly property real moduleHeight: {
        if (!moduleLoader.item)
            return root.switcherSize
        return Math.max(
            root.switcherSize,
            Number(moduleLoader.item.implicitHeight ||
                   moduleLoader.item.height ||
                   root.switcherSize)
        )
    }

    implicitWidth: root.showSelector
        ? (root.isVertical
            ? root.switcherSize * 1.2
            : (root.switcherSize * root.switcherMinMultiplier +
               root.switcherSize * 0.6))
        : root.moduleWidth

    implicitHeight: root.showSelector
        ? (root.isVertical
            ? root.switcherSize * root.switcherMinMultiplier
            : root.switcherSize * 1.2)
        : root.moduleHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    signal moduleSelected(string moduleId)
    signal moduleClosed(string moduleId)
    signal blobFocused()
    signal blobUnfocused()

    function resolveModifier(value) {
        const name = String(value || "").trim().toLowerCase()
        const map = {
            none: Qt.NoModifier,
            ctrl: Qt.ControlModifier,
            control: Qt.ControlModifier,
            shift: Qt.ShiftModifier,
            alt: Qt.AltModifier,
            meta: Qt.MetaModifier,
            super: Qt.MetaModifier,
            win: Qt.MetaModifier,
            windows: Qt.MetaModifier
        }
        return map[name] !== undefined ? map[name] : Qt.NoModifier
    }

    function resolveKey(value) {
        const name = String(value || "").trim().toUpperCase()
        if (!name)
            return Qt.Key_unknown

        if (name.length === 1) {
            const c = name.charCodeAt(0)
            if (c >= 65 && c <= 90)
                return Qt.Key_A + c - 65
            if (c >= 48 && c <= 57)
                return Qt.Key_0 + c - 48
        }

        const map = {
            TAB: Qt.Key_Tab,
            SPACE: Qt.Key_Space,
            ENTER: Qt.Key_Return,
            RETURN: Qt.Key_Return,
            ESC: Qt.Key_Escape,
            ESCAPE: Qt.Key_Escape,
            BACKSPACE: Qt.Key_Backspace,
            DELETE: Qt.Key_Delete,
            INSERT: Qt.Key_Insert,
            HOME: Qt.Key_Home,
            END: Qt.Key_End,
            UP: Qt.Key_Up,
            DOWN: Qt.Key_Down,
            LEFT: Qt.Key_Left,
            RIGHT: Qt.Key_Right,
            PAGEUP: Qt.Key_PageUp,
            PAGEDOWN: Qt.Key_PageDown
        }

        if (map[name] !== undefined)
            return map[name]

        if (/^F([1-9]|1[0-2])$/.test(name))
            return Qt.Key_F1 + parseInt(name.substring(1)) - 1

        return Qt.Key_unknown
    }

    function loadConfig() {
        if (root.configPath)
            keybindFile.path = root.configPath
    }

    function applyKeybindConfig(data) {
        if (!data || typeof data !== "object")
            return

        const bind = data.blobSwitch
        if (!bind || typeof bind !== "object")
            return

        const modifierValue =
            bind.modifier !== undefined
                ? bind.modifier
                : root.switchModifierName
        const nextValue =
            bind.next !== undefined
                ? bind.next
                : root.switchNextName
        const previousValue =
            bind.previous !== undefined
                ? bind.previous
                : root.switchPreviousName

        const modifier = root.resolveModifier(modifierValue)
        const nextKey = root.resolveKey(nextValue)
        const previousKey = root.resolveKey(previousValue)

        if (nextKey === Qt.Key_unknown ||
            previousKey === Qt.Key_unknown) {
            console.warn(
                "[Blob]",
                root.blobId,
                "invalid keybind:",
                JSON.stringify(bind)
            )
            return
        }

        root.switchModifierName = String(modifierValue)
        root.switchNextName = String(nextValue)
        root.switchPreviousName = String(previousValue)
        root.switchModifier = modifier
        root.switchNextKey = nextKey
        root.switchPreviousKey = previousKey
    }

    function hasModule(id) {
        return root.moduleIds.indexOf(id) !== -1
    }

    function containsFocus(item) {
        let p = item
        while (p) {
            if (p === root)
                return true
            p = p.parent
        }
        return false
    }

    // ============================================================
    // HOVER API
    // ============================================================

    function enterHover() {
        root.hovered = true

        // An already selected module means this blob is already
        // specified. Hovering it must NOT open the selector.
        if (!root.moduleSpecified)
            root.selectionModule = ""
    }

    function leaveHover() {
        root.hovered = false

        // Empty + unfocused blob was only temporarily opened by hover.
        if (!root.moduleSpecified && !root.blobFocused)
            root.closeBlob()
    }

    // ============================================================
    // MODULE / FOCUS
    // ============================================================

    function focusModule() {
        if (!moduleLoader.item) {
            root.forceActiveFocus()
            return
        }

        if (typeof moduleLoader.item.focusModule === "function") {
            moduleLoader.item.focusModule()
            return
        }

        moduleLoader.item.forceActiveFocus()
    }

    function focusBlob() {
        const previous =
            root.focusManager
                ? root.focusManager.focusedBlob
                : null

        if (previous &&
            previous !== root &&
            typeof previous.unfocusBlob === "function") {
            previous.unfocusBlob()
        }

        root.blobFocused = true

        if (root.focusManager)
            root.focusManager.focusedBlob = root

        root.forceActiveFocus()

        Qt.callLater(function() {
            if (root.blobFocused &&
                root.moduleSpecified &&
                !root.selectorOpen) {
                root.focusModule()
            }
        })
    }

    function closeBlob() {
        const oldModule = root.activeModule
        const wasFocused = root.blobFocused

        root.blobFocused = false
        root.hovered = false
        root.switching = false
        root.mouseSelector = false
        root.modifierHeld = false
        root.selectionModule = ""

        if (root.focusManager &&
            root.focusManager.focusedBlob === root) {
            root.focusManager.focusedBlob = null
        }

        if (moduleLoader.item &&
            typeof moduleLoader.item.deactivate === "function") {
            moduleLoader.item.deactivate()
        }

        moduleLoader.source = ""
        root.activeModule = ""

        if (oldModule)
            root.moduleClosed(oldModule)

        if (wasFocused)
            root.blobUnfocused()
    }

    function unfocusBlob() {
        root.closeBlob()
    }

    // ============================================================
    // FOCUS CHAIN
    // ============================================================

    function collectFocusable(item, list) {
        if (!item || !item.visible || !item.enabled)
            return

        if (item !== root && item.activeFocusOnTab)
            list.push(item)

        for (let i = 0; i < item.children.length; ++i)
            root.collectFocusable(item.children[i], list)
    }

    function rebuildFocusChain() {
        const list = []
        root.collectFocusable(root, list)
        root.focusItems = list

        for (let i = 0; i < list.length; ++i)
            list[i].activeFocusOnTab = false
    }

    function focusInsideBlob(backward = false) {
        if (root.selectorOpen) {
            if (root.switching || root.mouseSelector)
                selector.forceActiveFocus()
            return
        }

        const list = root.focusItems

        if (!list.length) {
            root.focusModule()
            return
        }

        const current =
            root.Window
                ? root.Window.activeFocusItem
                : null

        let index = list.indexOf(current)

        if (index < 0)
            index = backward ? 0 : list.length - 1

        index = backward
            ? (index - 1 + list.length) % list.length
            : (index + 1) % list.length

        list[index].forceActiveFocus()
    }

    // ============================================================
    // MODULE CONTROL
    // ============================================================

    function activateModule(id) {
        if (!root.hasModule(id)) {
            console.warn(
                "[Blob]",
                root.blobId,
                "module not assigned:",
                id
            )
            return false
        }

        const info = root.moduleRegistry.get(id)

        if (!info) {
            console.log(
                "[Blob]",
                root.blobId,
                "waiting for registry:",
                id
            )
            return false
        }

        if (moduleLoader.item &&
            root.activeModule !== id &&
            typeof moduleLoader.item.deactivate === "function") {
            moduleLoader.item.deactivate()
        }

        root.activeModule = id
        root.selectionModule = id
        moduleLoader.source = info.modulePath
        root.moduleSelected(id)

        return true
    }

    function openModule(id) {
        if (!root.hasModule(id))
            return false

        if (!root.activateModule(id))
            return false

        root.hovered = false
        root.mouseSelector = false
        root.switching = false
        root.modifierHeld = false

        root.focusBlob()

        Qt.callLater(function() {
            if (root.blobFocused)
                root.focusModule()
        })

        return true
    }

    function deactivateModule(id = root.activeModule) {
        if (!id || root.activeModule !== id)
            return false

        if (moduleLoader.item &&
            typeof moduleLoader.item.deactivate === "function") {
            moduleLoader.item.deactivate()
        }

        moduleLoader.source = ""
        root.activeModule = ""
        root.selectionModule = ""

        root.blobFocused = false
        root.hovered = false
        root.switching = false
        root.mouseSelector = false
        root.modifierHeld = false

        if (root.focusManager &&
            root.focusManager.focusedBlob === root) {
            root.focusManager.focusedBlob = null
        }

        root.moduleClosed(id)
        root.blobUnfocused()

        return true
    }

    function toggleModule(id) {
        if (!root.hasModule(id))
            return false

        if (root.activeModule === id)
            return root.deactivateModule(id)

        return root.openModule(id)
    }

    // ============================================================
    // SWITCHING
    // ============================================================

    function beginSwitch() {
        if (!root.isBlobFocused ||
            root.moduleIds.length < 2) {
            return false
        }

        if (root.switching)
            return true

        root.switching = true
        root.modifierHeld = true
        root.selectionModule = root.activeModule

        Qt.callLater(function() {
            if (root.switching && root.isBlobFocused)
                selector.forceActiveFocus()
        })

        return true
    }

    function cycle(direction) {
        if (!root.isBlobFocused ||
            root.moduleIds.length < 2) {
            return
        }

        root.beginSwitch()

        let index = root.moduleIds.indexOf(root.selectionModule)

        if (index < 0)
            index = root.moduleIds.indexOf(root.activeModule)

        if (index < 0)
            index = 0

        index =
            (index + direction + root.moduleIds.length) %
            root.moduleIds.length

        root.selectionModule = root.moduleIds[index]

        if (root.switchImmediate &&
            root.selectionModule !== root.activeModule) {
            root.activateModule(root.selectionModule)
        }
    }

    function cycleNext() {
        root.cycle(1)
    }

    function cyclePrevious() {
        root.cycle(-1)
    }

    function commitSwitch() {
        if (!root.switching)
            return

        const selected = root.selectionModule

        root.switching = false
        root.modifierHeld = false
        root.mouseSelector = false

        if (!root.switchImmediate &&
            selected &&
            selected !== root.activeModule) {
            root.activateModule(selected)
        }

        root.selectionModule = root.activeModule

        Qt.callLater(function() {
            if (root.isBlobFocused)
                root.focusModule()
        })
    }

    function cancelSwitch() {
        if (!root.selectorOpen)
            return

        root.switching = false
        root.mouseSelector = false
        root.modifierHeld = false
        root.selectionModule = root.activeModule

        Qt.callLater(function() {
            if (root.isBlobFocused &&
                root.moduleSpecified) {
                root.focusModule()
            }
        })
    }

    function modifierReleased(event) {
        if (root.switchModifier === Qt.ControlModifier)
            return event.key === Qt.Key_Control

        if (root.switchModifier === Qt.ShiftModifier)
            return event.key === Qt.Key_Shift

        if (root.switchModifier === Qt.AltModifier)
            return event.key === Qt.Key_Alt

        if (root.switchModifier === Qt.MetaModifier)
            return event.key === Qt.Key_Meta

        return false
    }

    // ============================================================
    // MOUSE SELECTOR
    // ============================================================

    function openMouseSelector() {
        if (root.moduleIds.length < 2)
            return

        root.focusBlob()
        root.hovered = true
        root.mouseSelector = true
        root.switching = false
        root.modifierHeld = false
        root.selectionModule = root.activeModule
    }

    function mouseSelect(id) {
        if (!root.hasModule(id))
            return

        root.mouseSelector = false
        root.switching = false
        root.modifierHeld = false

        if (!root.activateModule(id))
            return

        root.selectionModule = id
        root.hovered = false
        root.focusBlob()

        Qt.callLater(function() {
            if (root.blobFocused)
                root.focusModule()
        })
    }

    // ============================================================
    // SWITCHER SHORTCUTS
    // ============================================================

    Shortcut {
        id: nextShortcut
        context: Qt.ApplicationShortcut
        enabled: root.isBlobFocused &&
                 root.moduleIds.length > 1
        sequence: root.nextQtShortcut
        autoRepeat: true
        onActivated: root.cycleNext()
    }

    Shortcut {
        id: previousShortcut
        context: Qt.ApplicationShortcut
        enabled: root.isBlobFocused &&
                 root.moduleIds.length > 1
        sequence: root.previousQtShortcut
        autoRepeat: true
        onActivated: root.cyclePrevious()
    }

    // ============================================================
    // BLOB-LOCAL TAB
    // ============================================================

    Shortcut {
        id: tabShortcut
        context: Qt.ApplicationShortcut
        enabled: root.isBlobFocused
        sequence: "Tab"
        autoRepeat: false
        onActivated: root.focusInsideBlob(false)
    }

    Shortcut {
        id: backtabShortcut
        context: Qt.ApplicationShortcut
        enabled: root.isBlobFocused
        sequence: "Shift+Tab"
        autoRepeat: false
        onActivated: root.focusInsideBlob(true)
    }

    Shortcut {
        id: escapeShortcut
        context: Qt.ApplicationShortcut
        enabled: root.isBlobFocused &&
                 root.selectorOpen
        sequence: "Escape"
        onActivated: root.cancelSwitch()
    }

    Keys.onReleased: function(event) {
        if (!root.isBlobFocused || !root.switching)
            return

        if (root.modifierReleased(event)) {
            event.accepted = true
            root.commitSwitch()
        }
    }

    // ============================================================
    // MODULE
    // ============================================================

    Item {
        id: moduleContent

        anchors.fill: parent
        z: 10

        visible:
            root.activeModule !== "" &&
            !root.showSelector

        opacity: root.showSelector ? 0 : 1
        scale: root.showSelector ? 0.90 : 1
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Loader {
            id: moduleLoader

            anchors.centerIn: parent
            asynchronous: true
            active: root.activeModule !== ""
            source:
                root.activeInfo
                    ? root.activeInfo.modulePath
                    : ""

            width:
                item
                    ? Number(
                        item.implicitWidth ||
                        item.width ||
                        0
                    )
                    : 0

            height:
                item
                    ? Number(
                        item.implicitHeight ||
                        item.height ||
                        0
                    )
                    : 0

            onStatusChanged:
                console.log(
                    "[Blob]",
                    root.blobId,
                    "LOADER:",
                    status,
                    root.activeModule
                )

            onLoaded: {
                if (!item)
                    return

                if (item.hasOwnProperty("moduleId"))
                    item.moduleId = root.activeModule

                if (typeof item.activate === "function")
                    item.activate()

                Qt.callLater(function() {
                    root.rebuildFocusChain()

                    if (root.isBlobFocused &&
                        root.moduleSpecified &&
                        !root.selectorOpen) {
                        root.focusModule()
                    }
                })
            }
        }
    }

    // ============================================================
    // SELECTOR
    // ============================================================

    FocusScope {
        id: selector

        anchors.fill: parent
        anchors.margins: 5
        z: 100

        visible: root.showSelector ||
                 root.switching ||
                 root.mouseSelector

        // Hover selector must NOT steal keyboard focus.
        focus: root.switching || root.mouseSelector
        activeFocusOnTab: false

        Keys.onReleased: function(event) {
            if (!root.switching)
                return

            if (root.modifierReleased(event)) {
                event.accepted = true
                root.commitSwitch()
            }
        }

        Row {
            id: rowSelector

            anchors.centerIn: parent
            spacing: root.switcherSize * 0.2
            visible: !root.isVertical

            Repeater {
                model: root.moduleIds

                delegate: CutBox {
                    required property string modelData

                    width: root.switcherSize
                    height: root.switcherSize
                    interactive: false

                    bgColor:
                        modelData === root.selectionModule
                            ? root.switcherActiveBG
                            : "transparent"

                    borderColor:
                        modelData === root.selectionModule
                            ? root.switcherActiveBorder
                            : "transparent"

                    borderWidth:
                        modelData === root.selectionModule
                            ? root.borderWidth
                            : 0

                    cut:
                        root.switcherCornerType === "cut"
                            ? ({
                                topLeft: root.switcherCornerRadius,
                                topRight: root.switcherCornerRadius,
                                bottomRight: root.switcherCornerRadius,
                                bottomLeft: root.switcherCornerRadius
                            })
                            : ({})

                    round:
                        root.switcherCornerType === "round"
                            ? ({
                                topLeft: root.switcherCornerRadius,
                                topRight: root.switcherCornerRadius,
                                bottomRight: root.switcherCornerRadius,
                                bottomLeft: root.switcherCornerRadius
                            })
                            : ({})

                    Text {
                        anchors.centerIn: parent

                        text: {
                            const info =
                                root.moduleRegistry.get(modelData)
                            return info ? info.icon : "?"
                        }

                        color:
                            modelData === root.selectionModule
                                ? "#081018"
                                : "#ffffff"

                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 17
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked:
                            root.mouseSelect(modelData)
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: root.isVertical

            Repeater {
                model: root.moduleIds

                delegate: CutBox {
                    required property string modelData

                    width: root.switcherSize
                    height: root.switcherSize
                    interactive: false

                    bgColor:
                        modelData === root.selectionModule
                            ? root.switcherActiveBG
                            : "transparent"

                    borderColor:
                        modelData === root.selectionModule
                            ? root.switcherActiveBorder
                            : "transparent"

                    borderWidth:
                        modelData === root.selectionModule
                            ? root.borderWidth
                            : 0

                    cut:
                        root.switcherCornerType === "cut"
                            ? ({
                                topLeft: root.switcherCornerRadius,
                                topRight: root.switcherCornerRadius,
                                bottomRight: root.switcherCornerRadius,
                                bottomLeft: root.switcherCornerRadius
                            })
                            : ({})

                    round:
                        root.switcherCornerType === "round"
                            ? ({
                                topLeft: root.switcherCornerRadius,
                                topRight: root.switcherCornerRadius,
                                bottomRight: root.switcherCornerRadius,
                                bottomLeft: root.switcherCornerRadius
                            })
                            : ({})

                    Text {
                        anchors.centerIn: parent

                        text: {
                            const info =
                                root.moduleRegistry.get(modelData)
                            return info ? info.icon : "?"
                        }

                        color:
                            modelData === root.selectionModule
                                ? "#081018"
                                : "#ffffff"

                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 17
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked:
                            root.mouseSelect(modelData)
                    }
                }
            }
        }
    }

    // ============================================================
    // LEFT CLICK INSIDE BLOB
    // ============================================================

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled:
            !root.showSelector &&
            !root.switching &&
            !root.mouseSelector

        onTapped:
            root.focusBlob()
    }

    // ============================================================
    // RIGHT CLICK
    // ============================================================

    MouseArea {
        id: rightClickShield

        anchors.fill: parent
        z: 200

        visible:
            !root.showSelector &&
            !root.switching &&
            !root.mouseSelector

        enabled: visible
        acceptedButtons: Qt.RightButton

        onPressed: function(mouse) {
            mouse.accepted = true
            root.openMouseSelector()
        }

        onReleased: function(mouse) {
            mouse.accepted = true
        }
    }

    // ============================================================
    // CONFIG
    // ============================================================

    FileView {
        id: keybindFile

        blockLoading: true
        printErrors: true

        onLoadedChanged: {
            if (!loaded)
                return

            try {
                root.applyKeybindConfig(JSON.parse(text()))
            } catch (e) {
                console.warn(
                    "[Blob]",
                    root.blobId,
                    "config parse failed:",
                    e
                )
            }
        }

        onLoadFailed: function(error) {
            console.warn(
                "[Blob]",
                root.blobId,
                "config failed:",
                error
            )
        }
    }

    Connections {
        target: root.moduleRegistry

        function onRegistryChanged() {
            // Do NOT auto-select the first module.
            // A blob stays unspecified until IPC or mouse selection.
        }
    }

    Component.onCompleted: {
        console.log(
            "[Blob]",
            root.blobId,
            "CREATED:",
            JSON.stringify(root.moduleIds)
        )

        root.loadConfig()
    }

    onModuleIdsChanged: {
        if (!root.moduleIds.length) {
            root.closeBlob()
            root.focusItems = []
            return
        }

        if (!root.moduleIds.includes(root.activeModule)) {
            root.closeBlob()
            return
        }

        if (!root.moduleIds.includes(root.selectionModule))
            root.selectionModule = root.activeModule
    }

    // IMPORTANT:
    // Qt focus is allowed to move away. That does NOT close the Blob.
    onActiveFocusChanged: {
        console.log(
            "[Blob]",
            root.blobId,
            "QT:",
            root.activeFocus,
            "LOGICAL:",
            root.blobFocused,
            "ITEM:",
            root.Window
                ? root.Window.activeFocusItem
                : null
        )
    }

    onActiveModuleChanged:
        console.log(
            "[Blob]",
            root.blobId,
            "ACTIVE:",
            root.activeModule
        )

    onSelectionModuleChanged:
        console.log(
            "[Blob]",
            root.blobId,
            "SELECTION:",
            root.selectionModule
        )

    onSwitchingChanged:
        console.log(
            "[Blob]",
            root.blobId,
            "SWITCHING:",
            root.switching
        )

    onMouseSelectorChanged:
        console.log(
            "[Blob]",
            root.blobId,
            "MOUSE_SELECTOR:",
            root.mouseSelector
        )

    onBlobFocusedChanged:
        console.log(
            "[Blob]",
            root.blobId,
            "LOGICAL FOCUS:",
            root.blobFocused
        )

    onHoveredChanged:
        console.log(
            "[Blob]",
            root.blobId,
            "HOVER:",
            root.hovered
        )
}