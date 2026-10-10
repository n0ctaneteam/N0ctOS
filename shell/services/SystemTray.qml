pragma Singleton

import QtQuick
import QtQml

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

import Quickshell.Services.SystemTray as QsTray

import qs.core.ui
import qs.core.lib


Singleton {
    id:
        root


    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property bool isReady:
        Config.isReady

    readonly property int count:
        root._items.length

    /*
     * All currently connected tray items.
     *
     * These are N0ctOS wrapper objects.
     */
    readonly property var items:
        root._items

    /*
     * Items shown in the normal tray.
     *
     * Native/discovery order is preserved.
     */
    readonly property var pinnedItems:
        root._pinnedItems

    /*
     * Currently connected hidden items.
     */
    readonly property var hiddenItems:
        root._hiddenItems

    readonly property int pinnedCount:
        root._pinnedItems.length

    readonly property int hiddenCount:
        root._hiddenItems.length

    /*
     * Currently connected items in NeedsAttention state.
     */
    readonly property var attentionItems:
        root._attentionItems

    readonly property bool hasAttention:
        root._attentionItems.length > 0

    /*
     * Exactly one tray menu may be active.
     */
    readonly property bool isMenuOpen:
        root._menuBackend !==
            "none"

    readonly property string menuItemId:
        root._menuItemId

    readonly property string menuBackend:
        root._menuBackend


    // ============================================================
    // INTERNAL MODEL STATE
    // ============================================================

    property var _items:
        []

    property var _pinnedItems:
        []

    property var _hiddenItems:
        []

    property var _attentionItems:
        []

    property var _hiddenIds:
        []

    property var _configSection:
        ({})

    property bool _modelSyncScheduled:
        false


    // ============================================================
    // INTERNAL MENU STATE
    // ============================================================

    /*
     * none
     * pending
     * custom
     */
    property string _menuBackend:
        "none"

    property string _menuItemId:
        ""

    property var _activeAdapter:
        null

    property var _activeNativeItem:
        null

    /*
     * Invalidates old menu requests.
     *
     * This is mostly defensive because ContextMenu performs its
     * own asynchronous cursor/monitor work.
     */
    property int _menuGeneration:
        0


    // ============================================================
    // SIGNALS
    // ============================================================

    signal itemAdded(string id)
    signal itemRemoved(string id)
    signal itemChanged(string id)

    signal attentionChanged()
    signal configurationChanged()

    signal menuOpened(string id)
    signal menuClosed(string id)


    // ============================================================
    // CONFIG REACTIVITY
    // ============================================================

    Connections {
        target:
            Config


        function onExternalReload() {
            root.syncFromConfig()
        }
    }


    readonly property int _configRevision:
        Config.revision


    on_ConfigRevisionChanged: {
        if (!root.isReady)
            return

        root.syncFromConfig()
    }


    onIsReadyChanged: {
        if (!root.isReady)
            return

        root.syncFromConfig()
        root._scheduleModelSync()
    }


    // ============================================================
    // CONTEXT MENU REACTIVITY
    // ============================================================

    /*
     * ContextMenu owns its own window and can close itself.
     *
     * Keep SystemTray synchronized when that happens.
     */
    Connections {
        target:
            ContextMenu


        function onMenuOpenChanged() {
            if (
                root._menuBackend !==
                    "custom"
            ) {
                return
            }


            if (
                ContextMenu.menuOpen
            ) {
                return
            }


            root._clearMenuState(
                true
            )
        }
    }


    // ============================================================
    // CONFIG
    // ============================================================

    /*
     * Expected configuration:
     *
     * {
     *     "systemTray": {
     *         "hidden": []
     *     }
     * }
     *
     * Only "hidden" is owned by this service.
     *
     * Unknown keys in systemTray are preserved.
     */
    function syncFromConfig() {
        if (!Config.isReady)
            return


        const stored =
            Config.get(
                "systemTray",
                {}
            )


        if (
            stored &&
            typeof stored ===
                "object" &&
            !Array.isArray(stored)
        ) {
            root._configSection =
                stored
        } else {
            root._configSection =
                ({})
        }


        const hidden =
            stored &&
            Array.isArray(
                stored.hidden
            )
                ? stored.hidden
                : []


        const normalized =
            []


        for (
            let i = 0;
            i < hidden.length;
            ++i
        ) {
            const id =
                String(
                    hidden[i] || ""
                )


            if (
                id.length === 0 ||
                normalized.indexOf(
                    id
                ) !== -1
            ) {
                continue
            }


            normalized.push(
                id
            )
        }


        const oldJson =
            JSON.stringify(
                root._hiddenIds
            )


        const newJson =
            JSON.stringify(
                normalized
            )


        if (
            oldJson === newJson
        ) {
            return
        }


        root._hiddenIds =
            normalized


        root.configurationChanged()


        root._scheduleModelSync()
    }


    /*
     * Write ONLY systemTray.
     */
    function _saveHiddenIds(
        ids
    ) {
        if (!Config.isReady)
            return false


        const nextSection =
            {}


        for (
            const key in root._configSection
        ) {
            nextSection[key] =
                root._configSection[key]
        }


        nextSection.hidden =
            ids.slice()


        const ok =
            Config.set(
                "systemTray",
                nextSection
            )


        if (!ok)
            return false


        root._configSection =
            nextSection

        root._hiddenIds =
            ids.slice()


        root.configurationChanged()


        root._scheduleModelSync()


        return true
    }


    function _setHidden(
        id,
        hidden
    ) {
        const target =
            String(
                id || ""
            )


        if (
            target.length === 0
        ) {
            return false
        }


        const updated =
            root._hiddenIds.slice()


        const index =
            updated.indexOf(
                target
            )


        if (hidden) {
            if (
                index === -1
            ) {
                updated.push(
                    target
                )
            }
        } else {
            if (
                index !== -1
            ) {
                updated.splice(
                    index,
                    1
                )
            }
        }


        if (
            JSON.stringify(
                updated
            ) ===
            JSON.stringify(
                root._hiddenIds
            )
        ) {
            return true
        }


        return root._saveHiddenIds(
            updated
        )
    }


    // ============================================================
    // NATIVE SYSTEM TRAY
    // ============================================================

    /*
     * Quickshell's SystemTray.items is a live ObjectModel.
     *
     * Each native item receives one N0ctOS adapter.
     */
    Instantiator {
        id:
            nativeItemInstantiator


        model:
            QsTray.SystemTray.items


        asynchronous:
            false


        delegate:
            Component {
                Item {
                    id:
                        adapter


                    visible:
                        false

                    width:
                        0

                    height:
                        0


                    required property var modelData


                    // ====================================================
                    // NATIVE ITEM
                    // ====================================================

                    readonly property var _nativeItem:
                        modelData


                    // ====================================================
                    // IDENTITY
                    // ====================================================

                    readonly property string id:
                        modelData
                            ? String(
                                modelData.id ||
                                ""
                            )
                            : ""


                    // ====================================================
                    // DISPLAY
                    // ====================================================

                    readonly property string title:
                        modelData
                            ? String(
                                modelData.title ||
                                ""
                            )
                            : ""


                    readonly property string icon:
                        modelData
                            ? String(
                                modelData.icon ||
                                ""
                            )
                            : ""


                    readonly property string tooltipTitle:
                        modelData
                            ? String(
                                modelData.tooltipTitle ||
                                ""
                            )
                            : ""


                    readonly property string tooltipDescription:
                        modelData
                            ? String(
                                modelData.tooltipDescription ||
                                ""
                            )
                            : ""


                    readonly property string tooltip: {
                        const title =
                            adapter.tooltipTitle


                        const description =
                            adapter.tooltipDescription


                        if (
                            title &&
                            description
                        ) {
                            return (
                                title +
                                "\n" +
                                description
                            )
                        }


                        if (title)
                            return title


                        return description
                    }


                    // ====================================================
                    // STATUS
                    // ====================================================

                    readonly property int statusCode:
                        modelData
                            ? Number(
                                modelData.status
                            )
                            : QsTray.Status.Passive


                    readonly property string status:
                        adapter.statusCode ===
                            QsTray.Status.NeedsAttention
                            ? "attention"
                            : adapter.statusCode ===
                                QsTray.Status.Active
                                ? "active"
                                : "passive"


                    readonly property bool isPassive:
                        adapter.statusCode ===
                            QsTray.Status.Passive


                    readonly property bool isActive:
                        adapter.statusCode ===
                            QsTray.Status.Active


                    readonly property bool isAttention:
                        adapter.statusCode ===
                            QsTray.Status.NeedsAttention


                    // ====================================================
                    // PIN / HIDDEN
                    // ====================================================

                    readonly property bool isHidden:
                        root._hiddenIds.indexOf(
                            adapter.id
                        ) !== -1


                    readonly property bool isPinned:
                        !adapter.isHidden


                    // ====================================================
                    // CAPABILITIES
                    // ====================================================

                    readonly property bool onlyMenu:
                        modelData
                            ? Boolean(
                                modelData.onlyMenu
                            )
                            : false


                    readonly property bool hasMenu:
                        modelData
                            ? Boolean(
                                modelData.hasMenu
                            )
                            : false


                    readonly property bool hasActivate:
                        Boolean(
                            modelData &&
                            typeof modelData.activate ===
                                "function" &&
                            !adapter.onlyMenu
                        )


                    readonly property bool hasSecondaryActivate:
                        Boolean(
                            modelData &&
                            typeof modelData.secondaryActivate ===
                                "function"
                        )


                    readonly property bool hasScroll:
                        Boolean(
                            modelData &&
                            typeof modelData.scroll ===
                                "function"
                        )


                    // ====================================================
                    // CATEGORY
                    // ====================================================

                    readonly property string category:
                        modelData &&
                        modelData.category ===
                            QsTray.Category.Communications
                            ? "communications"
                            : modelData &&
                              modelData.category ===
                                QsTray.Category.Hardware
                                ? "hardware"
                                : modelData &&
                                  modelData.category ===
                                    QsTray.Category.SystemServices
                                    ? "system-services"
                                    : "application-status"


                    // ====================================================
                    // ITEM API
                    // ====================================================

                    function activate() {
                        return root.activate(
                            adapter.id
                        )
                    }


                    function secondaryActivate() {
                        return root.secondaryActivate(
                            adapter.id
                        )
                    }


                    function scroll(
                        delta,
                        horizontal
                    ) {
                        return root.scroll(
                            adapter.id,
                            delta,
                            horizontal
                        )
                    }


                    function openMenu() {
                        return root.openMenu(
                            adapter.id
                        )
                    }


                    function pin() {
                        return root.pin(
                            adapter.id
                        )
                    }


                    function unpin() {
                        return root.unpin(
                            adapter.id
                        )
                    }


                    function hide() {
                        return root.hide(
                            adapter.id
                        )
                    }


                    function show() {
                        return root.show(
                            adapter.id
                        )
                    }


                    function togglePin() {
                        return root.togglePin(
                            adapter.id
                        )
                    }


                    function toggleHidden() {
                        return root.toggleHidden(
                            adapter.id
                        )
                    }


                    function launch() {
                        return root.launch(
                            adapter.id
                        )
                    }


                    // ====================================================
                    // NATIVE PROPERTY WATCHERS
                    // ====================================================

                    Connections {
                        target:
                            adapter._nativeItem


                        function onIconChanged() {
                            root.itemChanged(
                                adapter.id
                            )
                        }


                        function onTitleChanged() {
                            root.itemChanged(
                                adapter.id
                            )
                        }


                        function onTooltipTitleChanged() {
                            root.itemChanged(
                                adapter.id
                            )
                        }


                        function onTooltipDescriptionChanged() {
                            root.itemChanged(
                                adapter.id
                            )
                        }


                        function onStatusChanged() {
                            root._refreshAttention()

                            root.itemChanged(
                                adapter.id
                            )
                        }


                        function onCategoryChanged() {
                            root.itemChanged(
                                adapter.id
                            )
                        }


                        function onHasMenuChanged() {
                            root.itemChanged(
                                adapter.id
                            )


                            if (
                                root._menuItemId ===
                                    adapter.id &&
                                !adapter.hasMenu
                            ) {
                                root.closeMenu()
                            }
                        }


                        function onMenuChanged() {
                            root.itemChanged(
                                adapter.id
                            )
                        }


                        function onOnlyMenuChanged() {
                            root.itemChanged(
                                adapter.id
                            )
                        }


                        function onIdChanged() {
                            if (
                                root._activeAdapter ===
                                    adapter
                            ) {
                                root.closeMenu()
                            }


                            root._scheduleModelSync()
                        }
                    }
                }
            }


        onObjectAdded:
            function(index, object) {
                root._scheduleModelSync()


                if (
                    object &&
                    object.id
                ) {
                    root.itemAdded(
                        String(
                            object.id
                        )
                    )
                }
            }


        onObjectRemoved:
            function(index, object) {
                if (
                    object &&
                    root._activeAdapter ===
                        object
                ) {
                    root.closeMenu()
                }


                root._scheduleModelSync()


                if (
                    object &&
                    object.id
                ) {
                    root.itemRemoved(
                        String(
                            object.id
                        )
                    )
                }
            }
    }


    // ============================================================
    // MODEL SYNCHRONIZATION
    // ============================================================

    function _scheduleModelSync() {
        if (
            root._modelSyncScheduled
        ) {
            return
        }


        root._modelSyncScheduled =
            true


        Qt.callLater(
            function() {
                root._modelSyncScheduled =
                    false

                root._syncModels()
            }
        )
    }


    function _syncModels() {
        const all =
            []


        for (
            let i = 0;
            i < nativeItemInstantiator.count;
            ++i
        ) {
            const item =
                nativeItemInstantiator.objectAt(
                    i
                )


            if (!item)
                continue


            all.push(
                item
            )
        }


        const pinned =
            []

        const hidden =
            []

        const attention =
            []


        for (
            let i = 0;
            i < all.length;
            ++i
        ) {
            const item =
                all[i]


            if (!item)
                continue


            if (
                item.isHidden
            ) {
                hidden.push(
                    item
                )
            } else {
                pinned.push(
                    item
                )
            }


            if (
                item.isAttention
            ) {
                attention.push(
                    item
                )
            }
        }


        root._items =
            all

        root._pinnedItems =
            pinned

        root._hiddenItems =
            hidden

        root._attentionItems =
            attention


        root.attentionChanged()
    }


    function _refreshAttention() {
        const attention =
            []


        for (
            let i = 0;
            i < root._items.length;
            ++i
        ) {
            const item =
                root._items[i]


            if (
                item &&
                item.isAttention
            ) {
                attention.push(
                    item
                )
            }
        }


        root._attentionItems =
            attention


        root.attentionChanged()
    }


    // ============================================================
    // LOOKUP
    // ============================================================

    function find(id) {
        const target =
            String(
                id || ""
            )


        if (
            target.length === 0
        ) {
            return null
        }


        for (
            let i = 0;
            i < root._items.length;
            ++i
        ) {
            const item =
                root._items[i]


            if (
                item &&
                item.id ===
                    target
            ) {
                return item
            }
        }


        return null
    }


    // ============================================================
    // PIN / HIDE API
    // ============================================================

    /*
     * Pinned = not in hidden[].
     */
    function pin(id) {
        return root._setHidden(
            id,
            false
        )
    }


    /*
     * Unpin = put the item into hidden[].
     */
    function unpin(id) {
        return root._setHidden(
            id,
            true
        )
    }


    function togglePin(id) {
        const item =
            root.find(id)


        if (!item)
            return false


        return item.isPinned
            ? root.unpin(id)
            : root.pin(id)
    }


    function hide(id) {
        return root._setHidden(
            id,
            true
        )
    }


    function show(id) {
        return root._setHidden(
            id,
            false
        )
    }


    function toggleHidden(id) {
        const item =
            root.find(id)


        if (!item)
            return false


        return item.isHidden
            ? root.show(id)
            : root.hide(id)
    }


    // ============================================================
    // TRAY ACTIONS
    // ============================================================

    function activate(id) {
        const item =
            root.find(id)


        if (!item)
            return false


        if (
            !item.hasActivate
        ) {
            return false
        }


        const native =
            item._nativeItem


        if (!native)
            return false


        try {
            native.activate()
        } catch (error) {
            console.warn(
                "[SystemTray] activate failed:",
                error
            )

            return false
        }


        return true
    }


    function secondaryActivate(id) {
        const item =
            root.find(id)


        if (!item)
            return false


        if (
            !item.hasSecondaryActivate
        ) {
            return false
        }


        const native =
            item._nativeItem


        if (!native)
            return false


        try {
            native.secondaryActivate()
        } catch (error) {
            console.warn(
                "[SystemTray] secondary activation failed:",
                error
            )

            return false
        }


        return true
    }


    function scroll(
        id,
        delta,
        horizontal
    ) {
        const item =
            root.find(id)


        if (!item)
            return false


        if (
            !item.hasScroll
        ) {
            return false
        }


        const native =
            item._nativeItem


        if (!native)
            return false


        try {
            native.scroll(
                Number(delta),
                Boolean(horizontal)
            )
        } catch (error) {
            console.warn(
                "[SystemTray] scroll failed:",
                error
            )

            return false
        }


        return true
    }


    // ============================================================
    // LAUNCH
    // ============================================================

    /*
     * First try an exact DesktopEntry lookup.
     *
     * If the tray item's ID does not correspond to a desktop entry,
     * fall back to normal tray activation.
     */
    function launch(id) {
        const item =
            root.find(id)


        if (!item)
            return false


        let desktopEntry =
            null


        try {
            desktopEntry =
                DesktopEntries.byId(
                    item.id
                )
        } catch (error) {
            desktopEntry =
                null
        }


        if (
            desktopEntry &&
            typeof desktopEntry.execute ===
                "function"
        ) {
            try {
                desktopEntry.execute()

                return true
            } catch (error) {
                console.warn(
                    "[SystemTray] desktop-entry launch failed:",
                    error
                )
            }
        }


        return root.activate(
            item.id
        )
    }


    // ============================================================
    // MENU OPEN
    // ============================================================

    function openMenu(id) {
        const item =
            root.find(id)


        if (!item) {
            console.warn(
                "[SystemTray] openMenu: unknown item:",
                id
            )

            return false
        }


        if (!item.hasMenu) {
            console.warn(
                "[SystemTray] openMenu: item has no menu:",
                item.id
            )

            return false
        }


        /*
         * Only one menu at a time.
         */
        root.closeMenu()


        root._activeAdapter =
            item

        root._activeNativeItem =
            item._nativeItem

        root._menuItemId =
            item.id

        root._menuBackend =
            "pending"

        root._menuGeneration++


        try {
            /*
             * IMPORTANT:
             *
             * ContextMenu owns cursor lookup, monitor lookup,
             * positioning, sizing, and submenu behavior.
             *
             * This is exactly the same API used by WidgetLayer.
             */
            ContextMenu.open(
                trayMenuComponent,
                WlrLayer.Overlay
            )
        } catch (error) {
            console.warn(
                "[SystemTray] ContextMenu.open failed:",
                error
            )


            root._clearMenuState(
                false
            )


            return false
        }


        /*
         * The current ContextMenu implementation switches menuOpen
         * synchronously when it accepts the component.
         */
        if (
            !ContextMenu.menuOpen
        ) {
            console.warn(
                "[SystemTray] ContextMenu rejected tray menu"
            )


            root._clearMenuState(
                false
            )


            return false
        }


        root._menuBackend =
            "custom"


        root.menuOpened(
            root._menuItemId
        )


        return true
    }


    // ============================================================
    // MENU CLOSE
    // ============================================================

    function closeMenu() {
        const hadMenu =
            root._menuBackend !==
                "none"


        const closedMenuId =
            root._menuItemId


        const backend =
            root._menuBackend


        root._menuGeneration++


        /*
         * Clear service state FIRST.
         *
         * ContextMenu's close notification will then see
         * backend === "none" and will not emit a second signal.
         */
        root._menuBackend =
            "none"

        root._menuItemId =
            ""

        root._activeAdapter =
            null

        root._activeNativeItem =
            null


        if (
            backend ===
                "custom" ||
            backend ===
                "pending"
        ) {
            try {
                ContextMenu.close()
            } catch (error) {
                console.warn(
                    "[SystemTray] ContextMenu.close failed:",
                    error
                )
            }
        }


        if (
            hadMenu
        ) {
            root.menuClosed(
                closedMenuId
            )
        }
    }


    /*
     * Clears service state after ContextMenu closed itself.
     *
     * No second close() call is made here.
     */
    function _clearMenuState(
        emitClosed
    ) {
        const hadMenu =
            root._menuBackend !==
                "none"


        const closedMenuId =
            root._menuItemId


        root._menuGeneration++


        root._menuBackend =
            "none"

        root._menuItemId =
            ""

        root._activeAdapter =
            null

        root._activeNativeItem =
            null


        if (
            emitClosed &&
            hadMenu
        ) {
            root.menuClosed(
                closedMenuId
            )
        }
    }


    // ============================================================
    // SERVICE-OWNED TRAY MENU
    // ============================================================

    /*
     * Developers never provide tray menu content.
     *
     * SystemTray converts the native QsMenuEntry tree into
     * ContextMenuObj objects and the N0ctOS ContextMenu owns the
     * actual interaction.
     */
    Component {
        id:
            trayMenuComponent


        Column {
            id:
                trayMenuColumn


            property var menuHandle:
                root._activeNativeItem
                    ? root._activeNativeItem.menu
                    : null


            /*
             * DBus menus load asynchronously: the menu opens
             * immediately, then re-measures when entries arrive
             * instead of staying incomplete on first open.
             *
             * The opener usually needs a few round trips, so
             * keep polling briefly until children arrive.
             */
            property int refreshAttempts:
                0

            property int maxRefreshAttempts:
                8

            function childCount() {
                try {
                    const kids =
                        rootMenuOpener.children

                    if (!kids)
                        return 0

                    if (
                        kids.count !==
                        undefined
                    ) {
                        return Number(
                            kids.count
                        ) || 0
                    }

                    return 0
                } catch (error) {
                    return 0
                }
            }

            Timer {
                id:
                    refreshTimer

                interval:
                    100

                repeat:
                    false

                onTriggered: {
                    try {
                        ContextMenu.refresh()
                    } catch (error) {
                        console.warn(
                            "[SystemTray] menu refresh failed:",
                            error
                        )
                    }

                    if (
                        trayMenuColumn.childCount() ===
                            0 &&
                        trayMenuColumn.refreshAttempts <
                            trayMenuColumn.maxRefreshAttempts
                    ) {
                        trayMenuColumn.refreshAttempts +=
                            1

                        refreshTimer.restart()
                    }
                }
            }


            function scheduleRefresh() {
                refreshTimer.restart()
            }


            function resetRefreshAttempts() {
                refreshAttempts =
                    0
            }


            onMenuHandleChanged: {
                resetRefreshAttempts()
                scheduleRefresh()
            }


            Component.onCompleted: {
                resetRefreshAttempts()
                scheduleRefresh()
            }


            // ========================================================
            // NATIVE APPLICATION MENU
            // ========================================================

            QsMenuOpener {
                id:
                    rootMenuOpener


                menu:
                    trayMenuColumn.menuHandle


                onChildrenChanged:
                    trayMenuColumn.scheduleRefresh()
            }


            Repeater {
                id:
                    rootMenuRepeater

                model:
                    rootMenuOpener.children


                delegate:
                    menuEntryComponent


                onItemAdded:
                    trayMenuColumn.scheduleRefresh()


                onItemRemoved:
                    trayMenuColumn.scheduleRefresh()
            }


            // ========================================================
            // N0ctOS SEPARATOR
            // ========================================================

            ContextMenuObj {

                headerHeight:
                    32

                isSeparator:
                    true

                visible:
                    root._activeNativeItem !==
                        null
            }


            // ========================================================
            // HIDE / SHOW
            // ========================================================

            ContextMenuObj {
                id:
                    hideItem



                headerHeight:
                    32

                text:
                    root._activeAdapter &&
                    root._activeAdapter.isHidden
                        ? "󰈈  Show"
                        : "󰈉  Hide"


                functionAction:
                    function() {
                        if (
                            !root._activeAdapter
                        ) {
                            return
                        }


                        const id =
                            root._activeAdapter.id


                        if (
                            root._activeAdapter.isHidden
                        ) {
                            root.show(id)
                        } else {
                            root.hide(id)
                        }
                    }
            }
        }
    }


    // ============================================================
    // NATIVE MENU ENTRY
    // ============================================================

    /*
     * Every native QsMenuEntry becomes a normal ContextMenuObj.
     *
     * There is intentionally NO custom mouse handler here.
     *
     * ContextMenuObj + ContextMenu already handle:
     *
     *     hover
     *     click
     *     submenu opening
     *     submenu pinning
     *     menu closing
     */
    Component {
        id:
            menuEntryComponent


        /*
         * Direct ContextMenuObj delegate (no wrapper Item).
         *
         * The old wrapper + custom body broke ContextMenu's
         * natural measurement (circular row.width bindings),
         * so menus never fit content width. Native
         * text/icon/leadingContent measure correctly.
         */
        ContextMenuObj {
            id:
                menuEntry


            required property var modelData


            readonly property var entry:
                modelData



            headerHeight:
                32


            horizontalPadding:
                8


            spacing:
                6


            /*
             * Separator uses ContextMenuObj's own line style.
             */
            isSeparator:
                Boolean(
                    entry &&
                    entry.isSeparator
                )


            text:
                entry &&
                !Boolean(
                    entry.isSeparator
                )
                    ? String(
                        entry.text ||
                        ""
                    )
                    : ""


            icon:
                entry &&
                !Boolean(
                    entry.isSeparator
                )
                    ? String(
                        entry.icon ||
                        ""
                    )
                    : ""


            /*
             * Checkbox / radio glyph via the native leading slot.
             */
            leadingContent: {
                if (
                    !entry ||
                    Boolean(
                        entry.isSeparator
                    )
                ) {
                    return ""
                }

                const buttonType =
                    Number(
                        entry.buttonType
                    )

                const checkState =
                    Number(
                        entry.checkState
                    )

                if (
                    buttonType ===
                        Number(
                            QsMenuButtonType.CheckBox
                        )
                ) {
                    if (
                        checkState ===
                            Qt.Checked
                    ) {
                        return "󰄲"
                    }

                    if (
                        checkState ===
                            Qt.PartiallyChecked
                    ) {
                        return "󰫃"
                    }

                    return "󰄱"
                }

                if (
                    buttonType ===
                        Number(
                            QsMenuButtonType.RadioButton
                        )
                ) {
                    if (
                        checkState ===
                            Qt.Checked
                    ) {
                        return "󰘛"
                    }

                    return "󰘚"
                }

                return ""
            }


                enabled:
                    Boolean(
                        entry &&
                        !Boolean(
                            entry.isSeparator
                        ) &&
                        (
                            entry.enabled ===
                                undefined
                                ? true
                                : Boolean(
                                    entry.enabled
                                )
                        )
                    )


                /*
                 * Checkable entries stay open so the toggled
                 * glyph is visible and can be flipped back.
                 */
                closeOnClick: {
                    if (
                        entry &&
                        Boolean(
                            entry.hasChildren
                        )
                    ) {
                        return false
                    }

                    if (!entry)
                        return true

                    const buttonType =
                        Number(
                            entry.buttonType
                        )

                    if (
                        buttonType ===
                            Number(
                                QsMenuButtonType.CheckBox
                            )
                    ) {
                        return false
                    }

                    if (
                        buttonType ===
                            Number(
                                QsMenuButtonType.RadioButton
                            )
                    ) {
                        return false
                    }

                    return true
                }


                /*
                 * Leaf action.
                 *
                 * QsMenuEntry.triggered() is the native action
                 * signal documented by Quickshell.
                 */
                functionAction:
                    function() {
                        if (!entry) {
                            console.warn(
                                "[SystemTray] tray menu entry trigger ignored: missing entry"
                            )

                            return
                        }

                        if (
                            Boolean(
                                entry.isSeparator
                            ) ||
                            Boolean(
                                entry.hasChildren
                            )
                        ) {
                            return
                        }


                        try {
                            entry.triggered()
                        } catch (error) {
                            console.warn(
                                "[SystemTray] tray menu entry trigger failed:",
                                error
                            )
                        }
                    }


                /*
                 * A submenu is handled by ContextMenu itself.
                 */
                submenu:
                    entry &&
                    Boolean(
                        entry.hasChildren
                    )
                        ? submenuComponent
                        : null




            // ====================================================
            // RECURSIVE SUBMENU
            // ====================================================

            /*
             * Nested resource Component: a raw Component never
             * renders as inline body content (only Items affect
             * body.childrenRect / ContextMenu measurement), it
             * only instantiates via Loader when ContextMenu opens
             * this entry's submenu.
             *
             * It captures menuEntry for THIS delegate instance,
             * so each submenu opens its own parent's children.
             */
            Component {
                id:
                    submenuComponent


                Column {
                    id:
                        submenuColumn


                    property var menuHandle:
                        menuEntry.entry


                    /*
                     * Submenu DBus children also arrive async:
                     * re-measure instead of showing an empty box.
                     *
                     * The root layout usually already contains the
                     * whole tree, but slow apps still need a few
                     * round trips, so poll briefly until children
                     * arrive.
                     *
                     * NOTE: lazily populated submenus (apps that
                     * only send children after AboutToShow for the
                     * submenu id) cannot load through QML at all:
                     * quickshell exposes no invokable to request
                     * them. Those stay empty by platform design.
                     */
                    property int refreshAttempts:
                        0

                    property int maxRefreshAttempts:
                        8

                    function childCount() {
                        try {
                            const kids =
                                submenuOpener.children

                            if (!kids)
                                return 0

                            if (
                                kids.count !==
                                undefined
                            ) {
                                return Number(
                                    kids.count
                                ) || 0
                            }

                            return 0
                        } catch (error) {
                            return 0
                        }
                    }

                    Timer {
                        id:
                            submenuRefreshTimer

                        interval:
                            100

                        repeat:
                            false

                        onTriggered: {
                            try {
                                ContextMenu.refresh()
                            } catch (error) {
                                console.warn(
                                    "[SystemTray] submenu refresh failed:",
                                    error
                                )
                            }

                            if (
                                submenuColumn.childCount() ===
                                    0 &&
                                submenuColumn.refreshAttempts <
                                    submenuColumn.maxRefreshAttempts
                            ) {
                                submenuColumn.refreshAttempts +=
                                    1

                                submenuRefreshTimer.restart()
                            }
                        }
                    }


                    function scheduleRefresh() {
                        submenuRefreshTimer.restart()
                    }


                    function resetRefreshAttempts() {
                        refreshAttempts =
                            0
                    }


                    onMenuHandleChanged: {
                        resetRefreshAttempts()
                        scheduleRefresh()
                    }


                    Component.onCompleted: {
                        resetRefreshAttempts()
                        scheduleRefresh()
                    }


                    QsMenuOpener {
                        id:
                            submenuOpener


                        menu:
                            submenuColumn.menuHandle


                        onChildrenChanged:
                            submenuColumn.scheduleRefresh()
                    }


                    Repeater {
                        model:
                            submenuOpener.children


                        delegate:
                            menuEntryComponent


                        onItemAdded:
                            submenuColumn.scheduleRefresh()


                        onItemRemoved:
                            submenuColumn.scheduleRefresh()
                    }
                }
            }
        }
    }


    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target:
            "n0ctos-tray"


        function getStatus(): string {
            return JSON.stringify({
                count:
                    root.count,

                pinnedCount:
                    root.pinnedCount,

                hiddenCount:
                    root.hiddenCount,

                attentionCount:
                    root.attentionItems.length,

                hasAttention:
                    root.hasAttention,

                menuOpen:
                    root.isMenuOpen,

                menuBackend:
                    root.menuBackend,

                menuItemId:
                    root.menuItemId
            })
        }


        function count(): int {
            return root.count
        }


        function list(): string {
            const result =
                []


            for (
                let i = 0;
                i < root._items.length;
                ++i
            ) {
                result.push(
                    root._snapshot(
                        root._items[i]
                    )
                )
            }


            return JSON.stringify(
                result
            )
        }


        function pinned(): string {
            const result =
                []


            for (
                let i = 0;
                i < root._pinnedItems.length;
                ++i
            ) {
                result.push(
                    root._snapshot(
                        root._pinnedItems[i]
                    )
                )
            }


            return JSON.stringify(
                result
            )
        }


        function hidden(): string {
            const connected =
                []


            for (
                let i = 0;
                i < root._hiddenItems.length;
                ++i
            ) {
                connected.push(
                    root._snapshot(
                        root._hiddenItems[i]
                    )
                )
            }


            return JSON.stringify({
                items:
                    connected,

                rememberedIds:
                    root._hiddenIds.slice()
            })
        }


        function attention(): string {
            const result =
                []


            for (
                let i = 0;
                i < root._attentionItems.length;
                ++i
            ) {
                result.push(
                    root._snapshot(
                        root._attentionItems[i]
                    )
                )
            }


            return JSON.stringify(
                result
            )
        }


        function get(
            id: string
        ): string {
            const item =
                root.find(id)


            if (!item)
                return ""


            return JSON.stringify(
                root._snapshot(
                    item
                )
            )
        }


        function pin(
            id: string
        ): bool {
            return root.pin(
                id
            )
        }


        function unpin(
            id: string
        ): bool {
            return root.unpin(
                id
            )
        }


        function togglePin(
            id: string
        ): bool {
            return root.togglePin(
                id
            )
        }


        function hide(
            id: string
        ): bool {
            return root.hide(
                id
            )
        }


        function show(
            id: string
        ): bool {
            return root.show(
                id
            )
        }


        function toggleHidden(
            id: string
        ): bool {
            return root.toggleHidden(
                id
            )
        }


        function activate(
            id: string
        ): bool {
            return root.activate(
                id
            )
        }


        function secondaryActivate(
            id: string
        ): bool {
            return root.secondaryActivate(
                id
            )
        }


        function scroll(
            id: string,
            delta: int,
            horizontal: bool
        ): bool {
            return root.scroll(
                id,
                delta,
                horizontal
            )
        }


        function launch(
            id: string
        ): bool {
            return root.launch(
                id
            )
        }


        function openMenu(
            id: string
        ): bool {
            return root.openMenu(
                id
            )
        }


        function closeMenu(): void {
            root.closeMenu()
        }


        function refresh(): void {
            root._syncModels()
        }
    }


    // ============================================================
    // IPC SNAPSHOT
    // ============================================================

    function _snapshot(
        item
    ) {
        if (!item)
            return ({ })


        return {
            id:
                item.id,

            title:
                item.title,

            icon:
                item.icon,

            tooltip:
                item.tooltip,

            tooltipTitle:
                item.tooltipTitle,

            tooltipDescription:
                item.tooltipDescription,

            status:
                item.status,

            statusCode:
                item.statusCode,

            isActive:
                item.isActive,

            isPassive:
                item.isPassive,

            isAttention:
                item.isAttention,

            isPinned:
                item.isPinned,

            isHidden:
                item.isHidden,

            hasMenu:
                item.hasMenu,

            hasActivate:
                item.hasActivate,

            hasSecondaryActivate:
                item.hasSecondaryActivate,

            hasScroll:
                item.hasScroll,

            onlyMenu:
                item.onlyMenu,

            category:
                item.category
        }
    }


    // ============================================================
    // STARTUP
    // ============================================================

    Component.onCompleted: {
        root.syncFromConfig()

        root._syncModels()


        console.info(
            "[SystemTray] initialized"
        )
    }
}