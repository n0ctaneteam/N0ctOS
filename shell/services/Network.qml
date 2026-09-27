pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    // ============================================================
    // BACKEND
    // ============================================================

    readonly property bool isAvailable:
        root.backend !== NetworkBackendType.None

    readonly property var backend:
        Networking.backend

    readonly property string backendName:
        NetworkBackendType.toString(
            root.backend
        )

    // ============================================================
    // WIFI
    // ============================================================

    readonly property bool isWifiSupported:
        root.wifiDeviceList.length > 0

    readonly property bool isWifiEnabled:
        Networking.wifiEnabled

    readonly property bool isWifiHardwareEnabled:
        Networking.wifiHardwareEnabled

    readonly property bool isWifiAvailable:
        root.isWifiSupported &&
        root.isWifiEnabled &&
        root.isWifiHardwareEnabled

    /*
     * Network-side airplane mode.
     *
     * This maps to NetworkManager's wireless radio state.
     * Bluetooth is intentionally not controlled here; Bluetooth
     * has its own service and will remain independently managed.
     */
    readonly property bool isAirplaneMode:
        root.isWifiSupported &&
        !root.isWifiEnabled

    // ============================================================
    // CONNECTIVITY
    // ============================================================

    readonly property bool canCheckConnectivity:
        Networking.canCheckConnectivity

    readonly property bool isConnectivityCheckEnabled:
        Networking.connectivityCheckEnabled

    readonly property var connectivity:
        Networking.connectivity

    readonly property string connectivityName:
        NetworkConnectivity.toString(
            root.connectivity
        )

    readonly property bool isConnectivityKnown:
        root.connectivity !==
            NetworkConnectivity.Unknown

    readonly property bool isNetworkConnected:
        root.connectedDeviceCount > 0

    readonly property bool isInternetAvailable:
        root.connectivity ===
            NetworkConnectivity.Full

    readonly property bool isCaptivePortal:
        root.connectivity ===
            NetworkConnectivity.Portal

    readonly property bool isLimitedConnectivity:
        root.connectivity ===
            NetworkConnectivity.Limited

    // ============================================================
    // RAW DEVICE MODEL
    // ============================================================

    /*
     * Quickshell exposes Networking.devices as an ObjectModel.
     *
     * Keep that model intact so consumers can use:
     *
     *     model: Network.devices
     */
    readonly property var devices:
        Networking.devices

    readonly property var deviceList:
        Networking.devices.values

    readonly property int deviceCount:
        Networking.devices.values.length

    // ============================================================
    // WIFI DEVICE MODEL
    // ============================================================

    ScriptModel {
        id: wifiDeviceModel

        values:
            root.deviceList.filter(
                function(device) {
                    return (
                        !!device &&
                        device.type ===
                            DeviceType.Wifi
                    )
                }
            )
    }

    readonly property var wifiDevices:
        wifiDeviceModel

    readonly property var wifiDeviceList:
        wifiDeviceModel.values

    readonly property int wifiDeviceCount:
        wifiDeviceModel.values.length

    // ============================================================
    // WIRED DEVICE MODEL
    // ============================================================

    ScriptModel {
        id: wiredDeviceModel

        values:
            root.deviceList.filter(
                function(device) {
                    return (
                        !!device &&
                        device.type ===
                            DeviceType.Wired
                    )
                }
            )
    }

    readonly property var wiredDevices:
        wiredDeviceModel

    readonly property var wiredDeviceList:
        wiredDeviceModel.values

    readonly property int wiredDeviceCount:
        wiredDeviceModel.values.length

    // ============================================================
    // CONNECTED DEVICE MODEL
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
    // WIFI NETWORK MODEL
    // ============================================================

    /*
     * Flatten every Wi-Fi device's ObjectModel into one convenient
     * model.
     *
     * The actual network objects remain the native Quickshell
     * WifiNetwork objects.
     */
    ScriptModel {
        id: wifiNetworkModel

        values:
            root.collectWifiNetworks()
    }

    readonly property var wifiNetworks:
        wifiNetworkModel

    readonly property var wifiNetworkList:
        wifiNetworkModel.values

    readonly property int wifiNetworkCount:
        wifiNetworkModel.values.length

    // ============================================================
    // CONNECTED NETWORK MODEL
    // ============================================================

    ScriptModel {
        id: connectedNetworkModel

        values:
            root.collectConnectedNetworks()
    }

    readonly property var connectedNetworks:
        connectedNetworkModel

    readonly property var connectedNetworkList:
        connectedNetworkModel.values

    readonly property int connectedNetworkCount:
        connectedNetworkModel.values.length

    // ============================================================
    // ACTIVE CONNECTIONS
    // ============================================================

    /*
     * First connected Wi-Fi network, if available.
     */
    readonly property var activeWifiNetwork:
        root.findActiveWifiNetwork()

    readonly property string activeWifiName:
        root.activeWifiNetwork
            ? String(
                  root.activeWifiNetwork.name || ""
              )
            : ""

    readonly property real activeWifiSignal:
        root.activeWifiNetwork
            ? root.signalPercent(
                  root.activeWifiNetwork
              )
            : 0

    readonly property int activeWifiSignalRounded:
        Math.round(
            root.activeWifiSignal
        )

    readonly property string activeWifiSignalText:
        root.activeWifiNetwork
            ? String(
                  root.activeWifiSignalRounded
              ) + "%"
            : ""

    /*
     * First connected wired network.
     */
    readonly property var activeWiredDevice:
        root.findActiveWiredDevice()

    readonly property string activeWiredName:
        root.activeWiredDevice
            ? String(
                  root.activeWiredDevice.name || ""
              )
            : ""

    readonly property int activeWiredLinkSpeed:
        root.activeWiredDevice &&
        root.activeWiredDevice.hasLink
            ? Number(
                  root.activeWiredDevice.linkSpeed
              )
            : 0

    /*
     * Primary network used by the shell.
     *
     * If both Wi-Fi and Ethernet are connected,
     * this follows the device ordering exposed by NetworkManager.
     */
    readonly property var activeNetwork:
        root.findActiveNetwork()

    readonly property string activeNetworkName:
        root.activeNetwork
            ? String(
                  root.activeNetwork.name || ""
              )
            : ""

    readonly property bool isWifiActive:
        !!root.activeWifiNetwork

    readonly property bool isWiredActive:
        !!root.activeWiredDevice &&
        root.activeWiredDevice.connected

    readonly property string activeConnectionType:
        root.getActiveConnectionType()

    readonly property string statusText:
        root.activeNetworkName !== ""
            ? root.activeNetworkName
            : root.isNetworkConnected
                ? root.connectivityName
                : "Disconnected"

    // ============================================================
    // SIGNAL ICON
    // ============================================================

    readonly property string icon:
        root.iconForState()

    readonly property string iconKey:
        root.iconKeyForState()

    // ============================================================
    // SIGNALS
    // ============================================================

    signal deviceAdded(var device)
    signal deviceRemoved(var device)

    /*
     * Emitted when the network/device topology changes.
     *
     * Individual native objects remain reactive themselves.
     */
    signal networkListUpdated()
    signal stateChangedExternally()

    // ============================================================
    // NETWORKING STATE TRACKING
    // ============================================================

    Connections {
        target: Networking

        function onWifiEnabledChanged() {
            root.stateChangedExternally()
        }

        function onWifiHardwareEnabledChanged() {
            root.stateChangedExternally()
        }

        function onConnectivityChanged() {
            root.stateChangedExternally()
        }

        function onConnectivityCheckEnabledChanged() {
            root.stateChangedExternally()
        }
    }

    Connections {
        target: Networking.devices

        function onObjectInsertedPost(
            device,
            index
        ) {
            root.deviceAdded(device)
            root.networkListUpdated()
            root.stateChangedExternally()
        }

        function onObjectRemovedPost(
            device,
            index
        ) {
            root.deviceRemoved(device)
            root.networkListUpdated()
            root.stateChangedExternally()
        }
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-network"

        // --------------------------------------------------------
        // STATUS
        // --------------------------------------------------------

        function getStatus(): string {
            return JSON.stringify(
                root.statusInfo()
            )
        }

        function getIcon(): string {
            return root.icon
        }

        function getState(): string {
            return root.statusText
        }

        function getConnectivity(): string {
            return root.connectivityName
        }

        // --------------------------------------------------------
        // WIFI
        // --------------------------------------------------------

        function getWifiEnabled(): string {
            return root.isWifiEnabled
                ? "true"
                : "false"
        }

        function setWifiEnabled(
            enabled: bool
        ) {
            root.setWifiEnabled(
                enabled
            )
        }

        function toggleWifi() {
            root.setWifiEnabled(
                !root.isWifiEnabled
            )
        }

        function getAirplaneMode(): string {
            return root.isAirplaneMode
                ? "true"
                : "false"
        }

        function setAirplaneMode(
            enabled: bool
        ) {
            root.setAirplaneMode(
                enabled
            )
        }

        // --------------------------------------------------------
        // SCANNING
        // --------------------------------------------------------

        function scan() {
            root.scan()
        }

        function isScanning(): string {
            return root.isScanning
                ? "true"
                : "false"
        }

        // --------------------------------------------------------
        // NETWORK CONNECTION
        // --------------------------------------------------------

        function connect(
            name: string
        ) {
            root.connectNetwork(
                name
            )
        }

        function connectPsk(
            name: string,
            psk: string
        ) {
            root.connectNetworkWithPsk(
                name,
                psk
            )
        }

        function disconnect(
            name: string
        ) {
            root.disconnectNetwork(
                name
            )
        }

        function forget(
            name: string
        ) {
            root.forgetNetwork(
                name
            )
        }

        // --------------------------------------------------------
        // DEVICE CONTROL
        // --------------------------------------------------------

        function disconnectDevice(
            name: string
        ) {
            root.disconnectDevice(
                name
            )
        }

        function setAutoconnect(
            name: string,
            enabled: bool
        ) {
            root.setDeviceAutoconnect(
                name,
                enabled
            )
        }

        function setManaged(
            name: string,
            managed: bool
        ) {
            root.setDeviceManaged(
                name,
                managed
            )
        }

        // --------------------------------------------------------
        // CONNECTIVITY CHECK
        // --------------------------------------------------------

        function checkConnectivity() {
            root.checkConnectivity()
        }

        function setConnectivityCheck(
            enabled: bool
        ) {
            root.setConnectivityCheckEnabled(
                enabled
            )
        }

        // --------------------------------------------------------
        // DATA
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

        function getWifiNetworks(): string {
            const result = []

            for (
                let i = 0;
                i < root.wifiNetworkList.length;
                ++i
            ) {
                result.push(
                    root.networkInfo(
                        root.wifiNetworkList[i]
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }

        function getConnectedNetworks(): string {
            const result = []

            for (
                let i = 0;
                i < root.connectedNetworkList.length;
                ++i
            ) {
                result.push(
                    root.networkInfo(
                        root.connectedNetworkList[i]
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }
    }

    // ============================================================
    // PUBLIC CONTROL API
    // ============================================================

    function setWifiEnabled(
        enabled
    ) {
        Networking.wifiEnabled =
            Boolean(enabled)
    }

    function setAirplaneMode(
        enabled
    ) {
        /*
         * Network-level airplane mode:
         * disable/enable NetworkManager's Wi-Fi radio.
         *
         * Bluetooth remains owned by Bluetooth.qml.
         */
        root.setWifiEnabled(
            !Boolean(enabled)
        )
    }

    function scan() {
        if (
            !root.isWifiSupported ||
            !root.isWifiHardwareEnabled ||
            !root.isWifiEnabled
        ) {
            return
        }

        for (
            let i = 0;
            i < root.wifiDeviceList.length;
            ++i
        ) {
            const device =
                root.wifiDeviceList[i]

            if (
                device &&
                !device.scannerEnabled
            ) {
                device.scannerEnabled =
                    true
            }
        }
    }

    function setConnectivityCheckEnabled(
        enabled
    ) {
        if (
            !root.canCheckConnectivity
        ) {
            return
        }

        Networking.connectivityCheckEnabled =
            Boolean(enabled)
    }

    function checkConnectivity() {
        if (
            !root.canCheckConnectivity
        ) {
            return
        }

        Networking.checkConnectivity()
    }

    function connectNetwork(
        name
    ) {
        const network =
            root.findNetwork(
                name
            )

        if (!network)
            return

        network.connect()
    }

    function connectNetworkWithPsk(
        name,
        psk
    ) {
        const network =
            root.findNetwork(
                name
            )

        if (!network)
            return

        /*
         * WifiNetwork.connectWithPsk() is only available for
         * Wi-Fi networks. Check for the function before calling it.
         */
        if (
            typeof network.connectWithPsk ===
            "function"
        ) {
            network.connectWithPsk(
                String(psk)
            )
        }
    }

    function disconnectNetwork(
        name
    ) {
        const network =
            root.findNetwork(
                name
            )

        if (!network)
            return

        network.disconnect()
    }

    function forgetNetwork(
        name
    ) {
        const network =
            root.findNetwork(
                name
            )

        if (!network)
            return

        network.forget()
    }

    function disconnectDevice(
        name
    ) {
        const device =
            root.findDevice(
                name
            )

        if (!device)
            return

        device.disconnect()
    }

    function setDeviceAutoconnect(
        name,
        enabled
    ) {
        const device =
            root.findDevice(
                name
            )

        if (!device)
            return

        device.autoconnect =
            Boolean(enabled)
    }

    function setDeviceManaged(
        name,
        managed
    ) {
        const device =
            root.findDevice(
                name
            )

        if (!device)
            return

        /*
         * nmManaged is NetworkManager-specific and exists in the
         * current Quickshell networking API.
         */
        if (
            root.hasProperty(
                device,
                "nmManaged"
            )
        ) {
            device.nmManaged =
                Boolean(managed)
        }
    }

    // ============================================================
    // LOOKUPS
    // ============================================================

    function findDevice(
        name
    ) {
        const wanted =
            String(name || "")

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
                String(device.name || "") ===
                    wanted
            ) {
                return device
            }
        }

        return null
    }

    function findNetwork(
        name
    ) {
        const wanted =
            String(name || "")

        if (wanted === "")
            return null

        /*
         * Prefer an already connected network.
         */
        for (
            let i = 0;
            i < root.wifiNetworkList.length;
            ++i
        ) {
            const network =
                root.wifiNetworkList[i]

            if (
                network &&
                network.connected &&
                String(network.name || "") ===
                    wanted
            ) {
                return network
            }
        }

        /*
         * Otherwise use the first matching SSID.
         */
        for (
            let i = 0;
            i < root.wifiNetworkList.length;
            ++i
        ) {
            const network =
                root.wifiNetworkList[i]

            if (
                network &&
                String(network.name || "") ===
                    wanted
            ) {
                return network
            }
        }

        /*
         * Wired networks are also searchable.
         */
        for (
            let i = 0;
            i < root.wiredDeviceList.length;
            ++i
        ) {
            const device =
                root.wiredDeviceList[i]

            if (
                !device ||
                !device.network
            ) {
                continue
            }

            const network =
                device.network

            if (
                String(network.name || "") ===
                    wanted
            ) {
                return network
            }
        }

        return null
    }

    // ============================================================
    // ACTIVE NETWORK HELPERS
    // ============================================================

    function findActiveWifiNetwork() {
        for (
            let i = 0;
            i < root.wifiNetworkList.length;
            ++i
        ) {
            const network =
                root.wifiNetworkList[i]

            if (
                network &&
                network.connected
            ) {
                return network
            }
        }

        return null
    }

    function findActiveWiredDevice() {
        for (
            let i = 0;
            i < root.wiredDeviceList.length;
            ++i
        ) {
            const device =
                root.wiredDeviceList[i]

            if (
                device &&
                device.connected
            ) {
                return device
            }
        }

        return null
    }

    function findActiveNetwork() {
        /*
         * Prefer the device ordering from NetworkManager.
         * This avoids pretending that N0ctOS knows routing priority
         * when Quickshell does not expose the default route.
         */
        for (
            let i = 0;
            i < root.deviceList.length;
            ++i
        ) {
            const device =
                root.deviceList[i]

            if (
                !device ||
                !device.connected
            ) {
                continue
            }

            if (
                device.type ===
                    DeviceType.Wifi
            ) {
                const networks =
                    device.networks.values

                for (
                    let j = 0;
                    j < networks.length;
                    ++j
                ) {
                    if (
                        networks[j] &&
                        networks[j].connected
                    ) {
                        return networks[j]
                    }
                }
            }

            if (
                device.type ===
                    DeviceType.Wired &&
                device.network
            ) {
                return device.network
            }
        }

        return null
    }

    function getActiveConnectionType() {
        const network =
            root.activeNetwork

        if (!network)
            return "none"

        const device =
            network.device

        if (!device)
            return "unknown"

        if (
            device.type ===
                DeviceType.Wifi
        ) {
            return "wifi"
        }

        if (
            device.type ===
                DeviceType.Wired
        ) {
            return "ethernet"
        }

        return "unknown"
    }

    // ============================================================
    // MODEL COLLECTION
    // ============================================================

    function collectWifiNetworks() {
        const result = []

        for (
            let i = 0;
            i < root.wifiDeviceList.length;
            ++i
        ) {
            const device =
                root.wifiDeviceList[i]

            if (!device)
                continue

            const networks =
                device.networks.values

            for (
                let j = 0;
                j < networks.length;
                ++j
            ) {
                const network =
                    networks[j]

                if (
                    network &&
                    result.indexOf(network) < 0
                ) {
                    result.push(
                        network
                    )
                }
            }
        }

        return result
    }

    function collectConnectedNetworks() {
        const result = []

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
                device.type ===
                    DeviceType.Wifi
            ) {
                const networks =
                    device.networks.values

                for (
                    let j = 0;
                    j < networks.length;
                    ++j
                ) {
                    const network =
                        networks[j]

                    if (
                        network &&
                        network.connected &&
                        result.indexOf(
                            network
                        ) < 0
                    ) {
                        result.push(
                            network
                        )
                    }
                }
            }

            if (
                device.type ===
                    DeviceType.Wired &&
                device.network &&
                device.network.connected &&
                result.indexOf(
                    device.network
                ) < 0
            ) {
                result.push(
                    device.network
                )
            }
        }

        return result
    }

    // ============================================================
    // SIGNAL HELPERS
    // ============================================================

    function signalPercent(
        network
    ) {
        if (!network)
            return 0

        const value =
            Number(
                network.signalStrength
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

    function signalBucket(
        network
    ) {
        const percent =
            root.signalPercent(
                network
            )

        if (percent >= 75)
            return 4

        if (percent >= 50)
            return 3

        if (percent >= 25)
            return 2

        if (percent > 0)
            return 1

        return 0
    }

    // ============================================================
    // ICON HELPERS
    // ============================================================

    function wifiIcon(
        signalPercent,
        connected,
        disabled
    ) {
        if (disabled)
            return "󰤭"

        if (!connected) {
            if (signalPercent >= 75)
                return "󰤨"

            if (signalPercent >= 50)
                return "󰤥"

            if (signalPercent >= 25)
                return "󰤢"

            if (signalPercent > 0)
                return "󰤟"

            return "󰤯"
        }

        if (signalPercent >= 75)
            return "󰤨"

        if (signalPercent >= 50)
            return "󰤥"

        if (signalPercent >= 25)
            return "󰤢"

        if (signalPercent > 0)
            return "󰤟"

        return "󰤯"
    }

    function iconForNetwork(
        network
    ) {
        if (!network)
            return "󰤯"

        const device =
            network.device

        if (
            device &&
            device.type ===
                DeviceType.Wired
        ) {
            return network.connected
                ? "󰈀"
                : "󰈀"
        }

        return root.wifiIcon(
            root.signalPercent(
                network
            ),
            network.connected,
            !root.isWifiEnabled
        )
    }

    function iconKeyForNetwork(
        network
    ) {
        if (!network)
            return "network-off"

        const device =
            network.device

        if (
            device &&
            device.type ===
                DeviceType.Wired
        ) {
            return "ethernet"
        }

        const bucket =
            root.signalBucket(
                network
            )

        if (bucket === 0)
            return "wifi-off"

        return "wifi-" +
            String(bucket)
    }

    function iconForState() {
        if (
            root.isAirplaneMode &&
            !root.isWiredActive
        ) {
            return "󰀝"
        }

        if (
            root.activeWifiNetwork
        ) {
            return root.wifiIcon(
                root.activeWifiSignal,
                true,
                false
            )
        }

        if (
            root.activeWiredDevice
        ) {
            return "󰈀"
        }

        if (
            root.isLimitedConnectivity
        ) {
            return "󰤯"
        }

        return "󰤯"
    }

    function iconKeyForState() {
        if (
            root.isAirplaneMode &&
            !root.isWiredActive
        ) {
            return "airplane-mode"
        }

        if (
            root.activeWifiNetwork
        ) {
            const bucket =
                root.signalBucket(
                    root.activeWifiNetwork
                )

            return bucket > 0
                ? "wifi-" +
                  String(bucket)
                : "wifi-off"
        }

        if (
            root.activeWiredDevice
        ) {
            return "ethernet"
        }

        return "network-off"
    }

    // ============================================================
    // TYPE / PROPERTY HELPERS
    // ============================================================

    function hasProperty(
        object,
        propertyName
    ) {
        if (!object)
            return false

        return (
            propertyName in
            object
        )
    }

    // ============================================================
    // STRING HELPERS
    // ============================================================

    function securityName(
        network
    ) {
        if (
            !network ||
            !hasProperty(
                network,
                "security"
            )
        ) {
            return ""
        }

        return WifiSecurityType.toString(
            network.security
        )
    }

    function stateName(
        object
    ) {
        if (!object)
            return "Unknown"

        if (
            !hasProperty(
                object,
                "state"
            )
        ) {
            return "Unknown"
        }

        return ConnectionState.toString(
            object.state
        )
    }

    // ============================================================
    // NETWORK SERIALIZATION
    // ============================================================

    function networkInfo(
        network
    ) {
        if (!network)
            return {}

        const device =
            network.device

        const isWifi =
            device &&
            device.type ===
                DeviceType.Wifi

        const signal =
            isWifi
                ? root.signalPercent(
                      network
                  )
                : 0

        const settings =
            []

        if (
            network.nmSettings
        ) {
            for (
                let i = 0;
                i <
                    network.nmSettings.length;
                ++i
            ) {
                const setting =
                    network.nmSettings[i]

                if (!setting)
                    continue

                settings.push({
                    id:
                        String(
                            setting.id || ""
                        ),

                    uuid:
                        String(
                            setting.uuid || ""
                        )
                })
            }
        }

        return {
            name:
                String(
                    network.name || ""
                ),

            connected:
                !!network.connected,

            known:
                !!network.known,

            state:
                root.stateName(
                    network
                ),

            stateChanging:
                !!network.stateChanging,

            isWifi:
                !!isWifi,

            deviceName:
                device
                    ? String(
                          device.name || ""
                      )
                    : "",

            signal:
                Math.round(
                    signal
                ),

            security:
                isWifi
                    ? root.securityName(
                          network
                      )
                    : "",

            icon:
                root.iconForNetwork(
                    network
                ),

            iconKey:
                root.iconKeyForNetwork(
                    network
                ),

            nmSettings:
                settings
        }
    }

    // ============================================================
    // DEVICE SERIALIZATION
    // ============================================================

    function deviceInfo(
        device
    ) {
        if (!device)
            return {}

        const isWifi =
            device.type ===
                DeviceType.Wifi

        const isWired =
            device.type ===
                DeviceType.Wired

        const networks = []

        if (
            device.networks
        ) {
            const list =
                device.networks.values

            for (
                let i = 0;
                i < list.length;
                ++i
            ) {
                if (
                    list[i]
                ) {
                    networks.push(
                        root.networkInfo(
                            list[i]
                        )
                    )
                }
            }
        }

        const info = {
            name:
                String(
                    device.name || ""
                ),

            address:
                String(
                    device.address || ""
                ),

            type:
                DeviceType.toString(
                    device.type
                ),

            isWifi:
                !!isWifi,

            isWired:
                !!isWired,

            isConnected:
                !!device.connected,

            state:
                root.stateName(
                    device
                ),

            isAutoconnect:
                !!device.autoconnect,

            isNmManaged:
                root.hasProperty(
                    device,
                    "nmManaged"
                )
                    ? !!device.nmManaged
                    : true,

            icon:
                isWifi
                    ? root.icon
                    : isWired
                        ? "󰈀"
                        : "󰖩",

            iconKey:
                isWifi
                    ? root.iconKeyForState()
                    : isWired
                        ? "ethernet"
                        : "network",

            networks:
                networks
        }

        if (isWifi) {
            info.scannerEnabled =
                !!device.scannerEnabled

            info.scanning =
                !!device.scannerEnabled
        }

        if (isWired) {
            info.hasLink =
                !!device.hasLink

            info.linkSpeed =
                Number(
                    device.linkSpeed
                )
        }

        return info
    }

    // ============================================================
    // COMPLETE STATUS
    // ============================================================

    function statusInfo() {
        return {
            isAvailable:
                root.isAvailable,

            backend:
                root.backendName,

            isNetworkConnected:
                root.isNetworkConnected,

            isInternetAvailable:
                root.isInternetAvailable,

            isCaptivePortal:
                root.isCaptivePortal,

            isLimitedConnectivity:
                root.isLimitedConnectivity,

            connectivity:
                root.connectivityName,

            isWifiSupported:
                root.isWifiSupported,

            isWifiEnabled:
                root.isWifiEnabled,

            isWifiHardwareEnabled:
                root.isWifiHardwareEnabled,

            isWifiAvailable:
                root.isWifiAvailable,

            isAirplaneMode:
                root.isAirplaneMode,

            wifiDeviceCount:
                root.wifiDeviceCount,

            wiredDeviceCount:
                root.wiredDeviceCount,

            deviceCount:
                root.deviceCount,

            connectedDeviceCount:
                root.connectedDeviceCount,

            wifiNetworkCount:
                root.wifiNetworkCount,

            connectedNetworkCount:
                root.connectedNetworkCount,

            isWifiActive:
                root.isWifiActive,

            isWiredActive:
                root.isWiredActive,

            activeConnectionType:
                root.activeConnectionType,

            activeNetwork:
                root.activeNetworkName,

            activeWifi:
                root.activeWifiName,

            activeWifiSignal:
                root.activeWifiSignalRounded,

            activeWired:
                root.activeWiredName,

            activeWiredLinkSpeed:
                root.activeWiredLinkSpeed,

            statusText:
                root.statusText,

            icon:
                root.icon,

            iconKey:
                root.iconKey
        }
    }

    // ============================================================
    // SCAN STATE
    // ============================================================

    readonly property bool isScanning:
        root.wifiDeviceList.some(
            function(device) {
                return (
                    device &&
                    device.scannerEnabled
                )
            }
        )
}