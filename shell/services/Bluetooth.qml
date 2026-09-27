pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Singleton {
    id: root

    // ============================================================
    // BACKEND
    // ============================================================

    readonly property var adapters:
        Bluetooth.adapters

    readonly property var adapterList:
        Bluetooth.adapters.values

    readonly property int adapterCount:
        Bluetooth.adapters.values.length

    readonly property var defaultAdapter:
        Bluetooth.defaultAdapter

    readonly property bool isAvailable:
        root.adapterCount > 0 &&
        !!root.defaultAdapter

    readonly property bool isEnabled:
        !!root.defaultAdapter &&
        root.defaultAdapter.enabled

    readonly property bool isPowered:
        root.isEnabled

    readonly property bool isBlocked:
        !!root.defaultAdapter &&
        root.defaultAdapter.state ===
            BluetoothAdapterState.Blocked

    readonly property bool isEnabling:
        !!root.defaultAdapter &&
        root.defaultAdapter.state ===
            BluetoothAdapterState.Enabling

    readonly property bool isDisabling:
        !!root.defaultAdapter &&
        root.defaultAdapter.state ===
            BluetoothAdapterState.Disabling

    readonly property string stateName:
        root.defaultAdapter
            ? BluetoothAdapterState.toString(
                  root.defaultAdapter.state
              )
            : "Disabled"

    // ============================================================
    // DEFAULT ADAPTER
    // ============================================================

    readonly property string adapterName:
        root.defaultAdapter
            ? String(
                  root.defaultAdapter.name || ""
              )
            : ""

    readonly property string adapterId:
        root.defaultAdapter
            ? String(
                  root.defaultAdapter.adapterId || ""
              )
            : ""

    readonly property string adapterDbusPath:
        root.defaultAdapter
            ? String(
                  root.defaultAdapter.dbusPath || ""
              )
            : ""

    readonly property bool isDiscoverable:
        !!root.defaultAdapter &&
        root.defaultAdapter.discoverable

    readonly property bool isDiscovering:
        !!root.defaultAdapter &&
        root.defaultAdapter.discovering

    readonly property bool isPairable:
        !!root.defaultAdapter &&
        root.defaultAdapter.pairable

    readonly property int discoverableTimeout:
        root.defaultAdapter
            ? Number(
                  root.defaultAdapter.discoverableTimeout
              )
            : 0

    readonly property int pairableTimeout:
        root.defaultAdapter
            ? Number(
                  root.defaultAdapter.pairableTimeout
              )
            : 0

    // ============================================================
    // ALL DEVICES
    // ============================================================

    /*
     * Bluetooth.devices is the global ObjectModel of tracked
     * BlueZ Device1 objects across all adapters.
     */
    readonly property var devices:
        Bluetooth.devices

    readonly property var deviceList:
        Bluetooth.devices.values

    readonly property int deviceCount:
        Bluetooth.devices.values.length

    // ============================================================
    // CONNECTED DEVICES
    // ============================================================

    ScriptModel {
        id: connectedDeviceModel

        values:
            root.deviceList.filter(
                function(device) {
                    return (
                        !!device &&
                        device.connected
                    )
                }
            )
    }

    readonly property var connectedDevices:
        connectedDeviceModel

    readonly property var connectedDeviceList:
        connectedDeviceModel.values

    readonly property int connectedDeviceCount:
        connectedDeviceModel.values.length

    // ============================================================
    // PAIRED DEVICES
    // ============================================================

    ScriptModel {
        id: pairedDeviceModel

        values:
            root.deviceList.filter(
                function(device) {
                    return (
                        !!device &&
                        device.paired
                    )
                }
            )
    }

    readonly property var pairedDevices:
        pairedDeviceModel

    readonly property var pairedDeviceList:
        pairedDeviceModel.values

    readonly property int pairedDeviceCount:
        pairedDeviceModel.values.length

    // ============================================================
    // BONDED DEVICES
    // ============================================================

    ScriptModel {
        id: bondedDeviceModel

        values:
            root.deviceList.filter(
                function(device) {
                    return (
                        !!device &&
                        device.bonded
                    )
                }
            )
    }

    readonly property var bondedDevices:
        bondedDeviceModel

    readonly property var bondedDeviceList:
        bondedDeviceModel.values

    readonly property int bondedDeviceCount:
        bondedDeviceModel.values.length

    // ============================================================
    // BATTERY DEVICES
    // ============================================================

    ScriptModel {
        id: batteryDeviceModel

        values:
            root.deviceList.filter(
                function(device) {
                    return (
                        !!device &&
                        device.batteryAvailable
                    )
                }
            )
    }

    readonly property var batteryDevices:
        batteryDeviceModel

    readonly property var batteryDeviceList:
        batteryDeviceModel.values

    readonly property int batteryDeviceCount:
        batteryDeviceModel.values.length

    // ============================================================
    // CONNECTED BATTERY DEVICES
    // ============================================================

    ScriptModel {
        id: connectedBatteryDeviceModel

        values:
            root.deviceList.filter(
                function(device) {
                    return (
                        !!device &&
                        device.connected &&
                        device.batteryAvailable
                    )
                }
            )
    }

    readonly property var connectedBatteryDevices:
        connectedBatteryDeviceModel

    readonly property var connectedBatteryDeviceList:
        connectedBatteryDeviceModel.values

    readonly property int connectedBatteryDeviceCount:
        connectedBatteryDeviceModel.values.length

    // ============================================================
    // ACTIVE DEVICE
    // ============================================================

    readonly property var activeDevice:
        root.findFirstConnectedDevice()

    readonly property string activeDeviceName:
        root.activeDevice
            ? root.displayName(
                  root.activeDevice
              )
            : ""

    readonly property string activeDeviceAddress:
        root.activeDevice
            ? String(
                  root.activeDevice.address || ""
              )
            : ""

    readonly property bool isDeviceConnected:
        !!root.activeDevice

    readonly property bool hasDeviceBattery:
        !!root.activeDevice &&
        root.activeDevice.batteryAvailable

    readonly property real activeDeviceBattery:
        root.hasDeviceBattery
            ? root.batteryPercent(
                  root.activeDevice
              )
            : 0

    readonly property int activeDeviceBatteryRounded:
        Math.round(
            root.activeDeviceBattery
        )

    readonly property string activeDeviceBatteryText:
        root.hasDeviceBattery
            ? String(
                  root.activeDeviceBatteryRounded
              ) + "%"
            : ""

    // ============================================================
    // ICON
    // ============================================================

    readonly property string icon:
        root.iconForState()

    readonly property string iconKey:
        root.iconKeyForState()

    // ============================================================
    // SIGNALS
    // ============================================================

    signal adapterAdded(var adapter)
    signal adapterRemoved(var adapter)

    signal deviceAdded(var device)
    signal deviceRemoved(var device)

    signal stateChangedExternally()
    signal adapterListUpdated()
    signal deviceListUpdated()

    // ============================================================
    // ADAPTER MODEL TRACKING
    // ============================================================

    Connections {
        target: Bluetooth

        function onDefaultAdapterChanged() {
            root.stateChangedExternally()
            root.adapterListUpdated()
        }
    }

    Connections {
        target: Bluetooth.adapters

        function onObjectInsertedPost(
            adapter,
            index
        ) {
            root.adapterAdded(adapter)
            root.adapterListUpdated()
            root.stateChangedExternally()
        }

        function onObjectRemovedPost(
            adapter,
            index
        ) {
            root.adapterRemoved(adapter)
            root.adapterListUpdated()
            root.stateChangedExternally()
        }
    }

    // ============================================================
    // DEVICE MODEL TRACKING
    // ============================================================

    Connections {
        target: Bluetooth.devices

        function onObjectInsertedPost(
            device,
            index
        ) {
            root.deviceAdded(device)
            root.deviceListUpdated()
            root.stateChangedExternally()
        }

        function onObjectRemovedPost(
            device,
            index
        ) {
            root.deviceRemoved(device)
            root.deviceListUpdated()
            root.stateChangedExternally()
        }
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-bluetooth"

        // --------------------------------------------------------
        // ADAPTER
        // --------------------------------------------------------

        function getStatus(): string {
            return JSON.stringify(
                root.statusInfo()
            )
        }

        function getState(): string {
            return root.stateName
        }

        function getIcon(): string {
            return root.icon
        }

        function getAdapter(): string {
            return root.adapterName
        }

        function getAdapterId(): string {
            return root.adapterId
        }

        function getEnabled(): string {
            return root.isEnabled
                ? "true"
                : "false"
        }

        function setEnabled(
            enabled: bool
        ) {
            root.setEnabled(
                enabled
            )
        }

        function toggle() {
            root.setEnabled(
                !root.isEnabled
            )
        }

        // --------------------------------------------------------
        // DISCOVERY
        // --------------------------------------------------------

        function getDiscovering(): string {
            return root.isDiscovering
                ? "true"
                : "false"
        }

        function startDiscovery() {
            root.startDiscovery()
        }

        function stopDiscovery() {
            root.stopDiscovery()
        }

        // --------------------------------------------------------
        // DISCOVERABLE
        // --------------------------------------------------------

        function getDiscoverable(): string {
            return root.isDiscoverable
                ? "true"
                : "false"
        }

        function setDiscoverable(
            enabled: bool
        ) {
            root.setDiscoverable(
                enabled
            )
        }

        function setDiscoverableTimeout(
            seconds: int
        ) {
            root.setDiscoverableTimeout(
                seconds
            )
        }

        // --------------------------------------------------------
        // PAIRABLE
        // --------------------------------------------------------

        function getPairable(): string {
            return root.isPairable
                ? "true"
                : "false"
        }

        function setPairable(
            enabled: bool
        ) {
            root.setPairable(
                enabled
            )
        }

        function setPairableTimeout(
            seconds: int
        ) {
            root.setPairableTimeout(
                seconds
            )
        }

        // --------------------------------------------------------
        // DEVICES
        // --------------------------------------------------------

        function getDevices(): string {
            const result = []

            for (
                let i = 0;
                i < root.deviceList.length;
                ++i
            ) {
                result.push(
                    root.deviceInfo(
                        root.deviceList[i]
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }

        function getConnectedDevices(): string {
            const result = []

            for (
                let i = 0;
                i <
                    root.connectedDeviceList.length;
                ++i
            ) {
                result.push(
                    root.deviceInfo(
                        root.connectedDeviceList[i]
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }

        function getPairedDevices(): string {
            const result = []

            for (
                let i = 0;
                i < root.pairedDeviceList.length;
                ++i
            ) {
                result.push(
                    root.deviceInfo(
                        root.pairedDeviceList[i]
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }

        // --------------------------------------------------------
        // DEVICE LOOKUP / CONNECTION
        // --------------------------------------------------------

        function connect(
            address: string
        ) {
            root.connectDevice(
                address
            )
        }

        function disconnect(
            address: string
        ) {
            root.disconnectDevice(
                address
            )
        }

        function pair(
            address: string
        ) {
            root.pairDevice(
                address
            )
        }

        function cancelPair(
            address: string
        ) {
            root.cancelPairDevice(
                address
            )
        }

        function forget(
            address: string
        ) {
            root.forgetDevice(
                address
            )
        }

        // --------------------------------------------------------
        // DEVICE POLICY
        // --------------------------------------------------------

        function setTrusted(
            address: string,
            trusted: bool
        ) {
            root.setDeviceTrusted(
                address,
                trusted
            )
        }

        function setBlocked(
            address: string,
            blocked: bool
        ) {
            root.setDeviceBlocked(
                address,
                blocked
            )
        }

        function setWakeAllowed(
            address: string,
            allowed: bool
        ) {
            root.setDeviceWakeAllowed(
                address,
                allowed
            )
        }

        function setName(
            address: string,
            name: string
        ) {
            root.setDeviceName(
                address,
                name
            )
        }
    }

    // ============================================================
    // PUBLIC ADAPTER CONTROL
    // ============================================================

    function setEnabled(
        enabled
    ) {
        const adapter =
            root.defaultAdapter

        if (!adapter)
            return

        adapter.enabled =
            Boolean(enabled)
    }

    function startDiscovery() {
        const list =
            root.adapterList

        for (
            let i = 0;
            i < list.length;
            ++i
        ) {
            const adapter =
                list[i]

            if (!adapter)
                continue

            if (!adapter.enabled)
                continue

            adapter.discovering =
                true
        }
    }

    function stopDiscovery() {
        const list =
            root.adapterList

        for (
            let i = 0;
            i < list.length;
            ++i
        ) {
            const adapter =
                list[i]

            if (!adapter)
                continue

            adapter.discovering =
                false
        }
    }

    function setDiscoverable(
        enabled
    ) {
        const adapter =
            root.defaultAdapter

        if (!adapter)
            return

        adapter.discoverable =
            Boolean(enabled)
    }

    function setDiscoverableTimeout(
        seconds
    ) {
        const adapter =
            root.defaultAdapter

        if (!adapter)
            return

        adapter.discoverableTimeout =
            Math.max(
                0,
                Number(seconds)
            )
    }

    function setPairable(
        enabled
    ) {
        const adapter =
            root.defaultAdapter

        if (!adapter)
            return

        adapter.pairable =
            Boolean(enabled)
    }

    function setPairableTimeout(
        seconds
    ) {
        const adapter =
            root.defaultAdapter

        if (!adapter)
            return

        adapter.pairableTimeout =
            Math.max(
                0,
                Number(seconds)
            )
    }

    // ============================================================
    // DEVICE LOOKUP
    // ============================================================

    function findDevice(
        address
    ) {
        const wanted =
            String(
                address || ""
            )

        if (wanted === "")
            return null

        for (
            let i = 0;
            i < root.deviceList.length;
            ++i
        ) {
            const device =
                root.deviceList[i]

            if (
                device &&
                String(
                    device.address || ""
                ).toLowerCase() ===
                    wanted.toLowerCase()
            ) {
                return device
            }
        }

        return null
    }

    function findDeviceByName(
        name
    ) {
        const wanted =
            String(
                name || ""
            ).toLowerCase()

        if (wanted === "")
            return null

        for (
            let i = 0;
            i < root.deviceList.length;
            ++i
        ) {
            const device =
                root.deviceList[i]

            if (!device)
                continue

            if (
                root.displayName(
                    device
                ).toLowerCase() ===
                    wanted
            ) {
                return device
            }
        }

        return null
    }

    // ============================================================
    // DEVICE CONNECTION CONTROL
    // ============================================================

    function connectDevice(
        address
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        if (
            device.blocked
        ) {
            return
        }

        device.connect()
    }

    function disconnectDevice(
        address
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        device.disconnect()
    }

    function pairDevice(
        address
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        if (device.paired)
            return

        if (device.pairing)
            return

        device.pair()
    }

    function cancelPairDevice(
        address
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        if (!device.pairing)
            return

        device.cancelPair()
    }

    function forgetDevice(
        address
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        device.forget()
    }

    // ============================================================
    // DEVICE POLICY CONTROL
    // ============================================================

    function setDeviceTrusted(
        address,
        trusted
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        device.trusted =
            Boolean(trusted)
    }

    function setDeviceBlocked(
        address,
        blocked
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        device.blocked =
            Boolean(blocked)
    }

    function setDeviceWakeAllowed(
        address,
        allowed
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        device.wakeAllowed =
            Boolean(allowed)
    }

    function setDeviceName(
        address,
        name
    ) {
        const device =
            root.findDevice(
                address
            )

        if (!device)
            return

        device.name =
            String(name || "")
    }

    // ============================================================
    // ACTIVE DEVICE
    // ============================================================

    function findFirstConnectedDevice() {
        for (
            let i = 0;
            i < root.deviceList.length;
            ++i
        ) {
            const device =
                root.deviceList[i]

            if (
                device &&
                device.connected
            ) {
                return device
            }
        }

        return null
    }

    // ============================================================
    // DISPLAY / BATTERY HELPERS
    // ============================================================

    function displayName(
        device
    ) {
        if (!device)
            return ""

        const alias =
            String(
                device.name || ""
            ).trim()

        if (alias !== "")
            return alias

        return String(
            device.deviceName || ""
        )
    }

    /*
     * Quickshell exposes BluetoothDevice.battery as
     * 0.0 -> 1.0, so convert it to the public 0 -> 100 range.
     */
    function batteryPercent(
        device
    ) {
        if (
            !device ||
            !device.batteryAvailable
        ) {
            return 0
        }

        const value =
            Number(
                device.battery
            )

        if (
            !isFinite(value)
        ) {
            return 0
        }

        return Math.max(
            0,
            Math.min(
                100,
                value * 100
            )
        )
    }

    // ============================================================
    // DEVICE STATE
    // ============================================================

    function deviceStateName(
        device
    ) {
        if (!device)
            return "Unknown"

        return BluetoothDeviceState.toString(
            device.state
        )
    }

    function isDeviceConnecting(
        device
    ) {
        return (
            !!device &&
            device.state ===
                BluetoothDeviceState.Connecting
        )
    }

    function isDeviceDisconnecting(
        device
    ) {
        return (
            !!device &&
            device.state ===
                BluetoothDeviceState.Disconnecting
        )
    }

    // ============================================================
    // DEVICE ICONS
    // ============================================================

    function deviceIconKey(
        device
    ) {
        if (!device)
            return "bluetooth"

        const source =
            (
                String(
                    device.icon || ""
                ) +
                " " +
                root.displayName(
                    device
                )
            ).toLowerCase()

        if (
            source.indexOf("headset") >= 0 ||
            source.indexOf("headphone") >= 0 ||
            source.indexOf("earbud") >= 0
        ) {
            return "headphones"
        }

        if (
            source.indexOf("speaker") >= 0
        ) {
            return "speaker"
        }

        if (
            source.indexOf("keyboard") >= 0
        ) {
            return "keyboard"
        }

        if (
            source.indexOf("mouse") >= 0
        ) {
            return "mouse"
        }

        if (
            source.indexOf("gamepad") >= 0 ||
            source.indexOf("joystick") >= 0
        ) {
            return "gamepad"
        }

        if (
            source.indexOf("phone") >= 0 ||
            source.indexOf("smartphone") >= 0
        ) {
            return "phone"
        }

        if (
            source.indexOf("tablet") >= 0
        ) {
            return "tablet"
        }

        if (
            source.indexOf("computer") >= 0 ||
            source.indexOf("laptop") >= 0
        ) {
            return "laptop"
        }

        if (
            source.indexOf("printer") >= 0
        ) {
            return "printer"
        }

        if (
            source.indexOf("camera") >= 0
        ) {
            return "camera"
        }

        if (
            source.indexOf("tv") >= 0 ||
            source.indexOf("display") >= 0
        ) {
            return "television"
        }

        return "bluetooth"
    }

    function deviceIcon(
        device
    ) {
        const key =
            root.deviceIconKey(
                device
            )

        switch (key) {
        case "headphones":
            return "󰋋"

        case "speaker":
            return "󰓃"

        case "keyboard":
            return "󰌌"

        case "mouse":
            return "󰍽"

        case "gamepad":
            return "󰊖"

        case "phone":
            return "󰄜"

        case "tablet":
            return "󰓶"

        case "laptop":
            return "󰌢"

        case "printer":
            return "󰐪"

        case "camera":
            return "󰄀"

        case "television":
            return "󰟛"

        default:
            return "󰂯"
        }
    }

    // ============================================================
    // ADAPTER ICONS
    // ============================================================

    function iconForState() {
        if (!root.isAvailable)
            return "󰂲"

        if (root.isBlocked)
            return "󰂲"

        if (
            root.isDisabling
        ) {
            return "󰂲"
        }

        if (
            root.isEnabling
        ) {
            return "󰂯"
        }

        if (
            root.isDiscovering
        ) {
            return "󰂯"
        }

        if (
            root.connectedDeviceCount > 0
        ) {
            return "󰂱"
        }

        if (root.isEnabled)
            return "󰂯"

        return "󰂲"
    }

    function iconKeyForState() {
        if (!root.isAvailable)
            return "bluetooth-off"

        if (root.isBlocked)
            return "bluetooth-blocked"

        if (root.isDiscovering)
            return "bluetooth-discovering"

        if (
            root.connectedDeviceCount > 0
        ) {
            return "bluetooth-connected"
        }

        if (root.isEnabled)
            return "bluetooth"

        return "bluetooth-off"
    }

    // ============================================================
    // DEVICE SERIALIZATION
    // ============================================================

    function deviceInfo(
        device
    ) {
        if (!device)
            return {}

        const hasBattery =
            !!device.batteryAvailable

        const battery =
            hasBattery
                ? root.batteryPercent(
                      device
                  )
                : 0

        const adapter =
            device.adapter

        return {
            name:
                root.displayName(
                    device
                ),

            deviceName:
                String(
                    device.deviceName || ""
                ),

            address:
                String(
                    device.address || ""
                ),

            dbusPath:
                String(
                    device.dbusPath || ""
                ),

            adapter:
                adapter
                    ? String(
                          adapter.adapterId || ""
                      )
                    : "",

            adapterName:
                adapter
                    ? String(
                          adapter.name || ""
                      )
                    : "",

            state:
                root.deviceStateName(
                    device
                ),

            isConnected:
                !!device.connected,

            isConnecting:
                root.isDeviceConnecting(
                    device
                ),

            isDisconnecting:
                root.isDeviceDisconnecting(
                    device
                ),

            isPaired:
                !!device.paired,

            isBonded:
                !!device.bonded,

            isPairing:
                !!device.pairing,

            isTrusted:
                !!device.trusted,

            isBlocked:
                !!device.blocked,

            isWakeAllowed:
                !!device.wakeAllowed,

            isBatteryAvailable:
                hasBattery,

            battery:
                hasBattery
                    ? battery
                    : null,

            batteryRounded:
                hasBattery
                    ? Math.round(
                          battery
                      )
                    : null,

            batteryText:
                hasBattery
                    ? Math.round(
                          battery
                      ) + "%"
                    : "",

            icon:
                root.deviceIcon(
                    device
                ),

            iconKey:
                root.deviceIconKey(
                    device
                )
        }
    }

    // ============================================================
    // ADAPTER SERIALIZATION
    // ============================================================

    function adapterInfo(
        adapter
    ) {
        if (!adapter)
            return {}

        const devices =
            adapter.devices.values

        const connected = []

        for (
            let i = 0;
            i < devices.length;
            ++i
        ) {
            const device =
                devices[i]

            if (
                device &&
                device.connected
            ) {
                connected.push(
                    root.deviceInfo(
                        device
                    )
                )
            }
        }

        return {
            name:
                String(
                    adapter.name || ""
                ),

            adapterId:
                String(
                    adapter.adapterId || ""
                ),

            dbusPath:
                String(
                    adapter.dbusPath || ""
                ),

            state:
                BluetoothAdapterState.toString(
                    adapter.state
                ),

            isEnabled:
                !!adapter.enabled,

            isDiscoverable:
                !!adapter.discoverable,

            isDiscovering:
                !!adapter.discovering,

            isPairable:
                !!adapter.pairable,

            discoverableTimeout:
                Number(
                    adapter.discoverableTimeout
                ),

            pairableTimeout:
                Number(
                    adapter.pairableTimeout
                ),

            deviceCount:
                devices.length,

            connectedDeviceCount:
                connected.length,

            connectedDevices:
                connected
        }
    }

    // ============================================================
    // COMPLETE STATUS
    // ============================================================

    function statusInfo() {
        return {
            isAvailable:
                root.isAvailable,

            isEnabled:
                root.isEnabled,

            isPowered:
                root.isPowered,

            isBlocked:
                root.isBlocked,

            isEnabling:
                root.isEnabling,

            isDisabling:
                root.isDisabling,

            state:
                root.stateName,

            adapter:
                root.adapterName,

            adapterId:
                root.adapterId,

            isDiscoverable:
                root.isDiscoverable,

            isDiscovering:
                root.isDiscovering,

            isPairable:
                root.isPairable,

            discoverableTimeout:
                root.discoverableTimeout,

            pairableTimeout:
                root.pairableTimeout,

            adapterCount:
                root.adapterCount,

            deviceCount:
                root.deviceCount,

            connectedDeviceCount:
                root.connectedDeviceCount,

            pairedDeviceCount:
                root.pairedDeviceCount,

            bondedDeviceCount:
                root.bondedDeviceCount,

            batteryDeviceCount:
                root.batteryDeviceCount,

            activeDevice:
                root.activeDeviceName,

            activeDeviceAddress:
                root.activeDeviceAddress,

            hasDeviceBattery:
                root.hasDeviceBattery,

            activeDeviceBattery:
                root.hasDeviceBattery
                    ? root.activeDeviceBatteryRounded
                    : null,

            icon:
                root.icon,

            iconKey:
                root.iconKey
        }
    }
}