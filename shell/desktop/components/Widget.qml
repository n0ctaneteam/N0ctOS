import QtQuick
import qs.core.ui

CutBox {
    id: root

    /*
     * ============================================================
     * IDENTITY
     * ============================================================
     */

    property string widgetId: ""
    property string instanceId: ""
    property string screenName: ""

    /*
     * Per-widget configuration.
     *
     * This is the instance's config object.
     * Global widget settings are separate and can be layered later.
     */
    property var config: ({})
    property var definition: ({})

    /*
     * ============================================================
     * BASE CAPABILITIES
     * ============================================================
     *
     * These are defaults for the currently selected/default variant.
     *
     * A variant may override any of them through:
     *
     * variantCapabilities: ({
     *     compact: {
     *         draggable: true,
     *         resizable: false,
     *         canIntersect: false,
     *         allowMultiple: true
     *     },
     *
     *     free: {
     *         draggable: true,
     *         resizable: true,
     *         canIntersect: true
     *     }
     * })
     */

    property bool draggable: true
    property bool resizable: false
    property bool canIntersect: false
    property bool allowMultiple: false

    property real minimumWidth: 32
    property real minimumHeight: 32

    property real maximumWidth: Infinity
    property real maximumHeight: Infinity

    property var interaction: ({
        click: true,
        rightClick: true,
        hover: false,
        focus: false,
        passMouseEvents: false
    })

    /*
     * ============================================================
     * VARIANTS
     * ============================================================
     */

    property string variant: ""
    property string defaultVariant: ""

    /*
     * Variant presentation components.
     *
     * Example:
     *
     * variantComponents: ({
     *     compact: compactVariant,
     *     full: fullVariant
     * })
     */
    property var variantComponents: ({})

    /*
     * Per-variant capability overrides.
     */
    property var variantCapabilities: ({})

    readonly property string effectiveVariant:
        root.variant !== "" &&
        root.variantComponents &&
        root.variantComponents[root.variant] !== undefined
            ? root.variant
            : root.defaultVariant

    readonly property var effectiveVariantCapabilities:
        root.variantCapabilities &&
        root.variantCapabilities[root.effectiveVariant] !== undefined
            ? root.variantCapabilities[root.effectiveVariant]
            : ({})

    function capability(name, fallback) {
        const caps = root.effectiveVariantCapabilities

        if (caps && caps[name] !== undefined)
            return caps[name]

        return fallback
    }

    /*
     * LIVE capability values.
     *
     * WidgetLayer uses these.
     */
    readonly property bool effectiveDraggable:
        Boolean(root.capability(
            "draggable",
            root.draggable
        ))

    readonly property bool effectiveResizable:
        Boolean(root.capability(
            "resizable",
            root.resizable
        ))

    readonly property bool effectiveCanIntersect:
        Boolean(root.capability(
            "canIntersect",
            root.canIntersect
        ))

    readonly property bool effectiveAllowMultiple:
        Boolean(root.capability(
            "allowMultiple",
            root.allowMultiple
        ))

    readonly property var effectiveInteraction:
        root.capability(
            "interaction",
            root.interaction
        )

    readonly property bool acceptsClick:
        root.effectiveInteraction &&
        Boolean(root.effectiveInteraction.click)

    readonly property bool acceptsRightClick:
        root.effectiveInteraction &&
        Boolean(root.effectiveInteraction.rightClick)

    readonly property bool acceptsHover:
        root.effectiveInteraction &&
        Boolean(root.effectiveInteraction.hover)

    readonly property bool acceptsFocus:
        root.effectiveInteraction &&
        Boolean(root.effectiveInteraction.focus)

    readonly property bool passMouseEvents:
        root.effectiveInteraction &&
        Boolean(root.effectiveInteraction.passMouseEvents)

    /*
     * ============================================================
     * EDIT STATE
     * ============================================================
     */

    property bool editMode: false
    property bool selected: false
    property bool dragging: false
    property bool resizing: false

    /*
     * ============================================================
     * VARIANT LOADING
     * ============================================================
     */

    readonly property Item variantItem: variantLoader.item
    readonly property bool variantLoaded:
        variantLoader.status === Loader.Ready &&
        variantLoader.item !== null

    /*
     * ============================================================
     * SIGNALS
     * ============================================================
     */

    signal configurationChanged()

    signal requestEdit()
    signal requestRemove()
    signal requestResize(string handle)
    signal interactionRequested(string type, var mouse)

    signal contextMenuRequested(
        Component component,
        var mouse
    )

    signal activated()
    signal deactivated()

    /*
     * ============================================================
     * CONFIGURATION
     * ============================================================
     */

    function applyConfig(value) {
        root.config =
            value && typeof value === "object"
                ? value
                : {}

        root.configurationChanged()
    }

    function configValue(key, fallback) {
        if (!root.config)
            return fallback

        if (root.config[key] === undefined)
            return fallback

        return root.config[key]
    }

    /*
     * ============================================================
     * VARIANT HELPERS
     * ============================================================
     */

    function hasVariant(name) {
        return root.variantComponents &&
               root.variantComponents[name] !== undefined
    }

    function setVariant(name) {
        if (!root.hasVariant(name))
            return false

        root.variant = name
        root.configurationChanged()

        return true
    }

    function clearVariant() {
        root.variant = ""
        root.configurationChanged()
    }

    /*
     * ============================================================
     * GEOMETRY HELPERS
     * ============================================================
     */

    function clampWidth(value) {
        let result = Number(value)

        if (!isFinite(result))
            result = root.minimumWidth

        result = Math.max(
            root.minimumWidth,
            result
        )

        if (isFinite(root.maximumWidth))
            result = Math.min(
                root.maximumWidth,
                result
            )

        return result
    }

    function clampHeight(value) {
        let result = Number(value)

        if (!isFinite(result))
            result = root.minimumHeight

        result = Math.max(
            root.minimumHeight,
            result
        )

        if (isFinite(root.maximumHeight))
            result = Math.min(
                root.maximumHeight,
                result
            )

        return result
    }

    function setWidgetSize(newWidth, newHeight) {
        root.width = root.clampWidth(newWidth)
        root.height = root.clampHeight(newHeight)
    }

    function initializeInstance(
        instanceValue,
        widgetIdValue,
        screenNameValue,
        configValueValue,
        variantValue,
        definitionValue
    ) {
        root.instanceId = instanceValue || ""
        root.widgetId = widgetIdValue || ""
        root.screenName = screenNameValue || ""
        root.definition =
            definitionValue || {}

        root.applyConfig(
            configValueValue || {}
        )

        if (
            variantValue &&
            root.hasVariant(variantValue)
        ) {
            root.variant = variantValue
        }

        root.width =
            root.clampWidth(
                root.width > 0
                    ? root.width
                    : root.implicitWidth
            )

        root.height =
            root.clampHeight(
                root.height > 0
                    ? root.height
                    : root.implicitHeight
            )
    }

    function activate() {
        if (root.selected)
            return

        root.selected = true
        root.activated()
    }

    function deactivate() {
        if (!root.selected)
            return

        root.selected = false
        root.deactivated()
    }

    function focusWidget() {
        if (!root.visible)
            return

        root.forceActiveFocus()
    }

    /*
     * Context menu component supplied by the widget.
     */
    property Component contextMenuComponent: null

    /*
     * ============================================================
     * POINTER INTERACTION
     * ============================================================
     */

    interactive:
        !root.passMouseEvents &&
        (
            root.acceptsClick ||
            root.acceptsRightClick ||
            root.acceptsHover
        )

    onClicked: function(mouse) {
        if (root.acceptsClick)
            root.interactionRequested(
                "click",
                mouse
            )
    }

    onRightClicked: function(mouse) {
        if (root.acceptsRightClick)
            root.interactionRequested(
                "rightClick",
                mouse
            )

        if (root.contextMenuComponent)
            root.contextMenuRequested(
                root.contextMenuComponent,
                mouse
            )
    }

    onHovered: {
        if (root.acceptsHover)
            root.interactionRequested(
                "hover",
                null
            )
    }

    onExited: {
        if (root.acceptsHover)
            root.interactionRequested(
                "exit",
                null
            )
    }

    /*
     * ============================================================
     * VARIANT CONTENT
     * ============================================================
     */

    Loader {
        id: variantLoader

        anchors.fill: parent

        asynchronous: false

        sourceComponent:
            root.hasVariant(
                root.effectiveVariant
            )
                ? root.variantComponents[
                    root.effectiveVariant
                ]
                : null

        onLoaded: {
            if (!item)
                return

            if ("widget" in item)
                item.widget = root

            if ("parentWidget" in item)
                item.parentWidget = root
        }
    }
}