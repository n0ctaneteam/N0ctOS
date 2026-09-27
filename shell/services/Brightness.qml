pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============================================================
    // INTERNAL STATE
    // ============================================================

    property var _devices: []
    property var _discoveryLines: []

    property bool _available: false
    property bool _discovering: false

    /*
     * Runtime-only selected device.
     *
     * This is intentionally not persisted yet.
     */
    property string _selectedKey: ""

    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property bool isAvailable:
        root._available

    readonly property bool isDiscovering:
        root._discovering

    readonly property var devices:
        root._devices.slice()

    readonly property var backlights:
        root._devices.filter(
            function(device) {
                return (
                    device &&
                    device.isBacklight
                )
            }
        )

    readonly property var leds:
        root._devices.filter(
            function(device) {
                return (
                    device &&
                    device.isLed
                )
            }
        )

    readonly property int count:
        root._devices.length

    readonly property int backlightCount:
        root.backlights.length

    readonly property int ledCount:
        root.leds.length

    /*
     * Default device:
     *
     *   1. First backlight
     *   2. Otherwise first available brightness device
     */
    readonly property var defaultDevice:
        root.findDefaultDevice()

    /*
     * Active device:
     *
     *   selected device if it still exists
     *   otherwise default device
     */
    readonly property var device:
        root._selectedKey.length > 0
            ? (
                root.deviceForKey(
                    root._selectedKey
                ) ||
                root.defaultDevice
            )
            : root.defaultDevice

    readonly property bool hasDevice:
        !!root.device

    readonly property real value:
        root.device
            ? root.device.value
            : 0

    readonly property real max:
        root.device
            ? root.device.max
            : 0

    readonly property real percent:
        root.device
            ? root.device.percent
            : 0

    readonly property int percentRounded:
        Math.round(
            root.percent
        )

    readonly property string percentText:
        String(
            root.percentRounded
        ) + "%"

    readonly property string deviceName:
        root.device
            ? root.device.name
            : ""

    readonly property string deviceKey:
        root.device
            ? root.device.key
            : ""

    // ============================================================
    // DEVICE DISCOVERY
    // ============================================================

    Process {
        id: discovery

        command: [
            "brightnessctl",
            "--list",
            "--machine-readable"
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                const line =
                    String(data).trim()

                if (line.length === 0)
                    return

                root._discoveryLines.push(
                    line
                )
            }
        }

        onStarted: {
            root._discovering = true
            root._discoveryLines = []
        }

        onExited: function(exitCode) {
            root._discovering = false

            if (exitCode !== 0) {
                root._available = false

                console.warn(
                    "[Brightness] brightnessctl discovery failed:",
                    exitCode
                )

                return
            }

            root._available = true

            root.applyDiscovery(
                root._discoveryLines
            )
        }
    }

    // ============================================================
    // DYNAMIC DEVICE
    // ============================================================
    //
    // IMPORTANT:
    // This object intentionally has NO child FileViews.
    //
    // FileViews are created explicitly with createObject() and
    // assigned to currentFile / maxFile.
    // ============================================================

    Component {
        id: deviceComponent

        QtObject {
            id: device

            // --------------------------------------------------------
            // Identity
            // --------------------------------------------------------

            property string deviceId: ""
            property string deviceClass: ""

            readonly property string key:
                device.deviceClass +
                ":" +
                device.deviceId

            readonly property string sysfsPath:
                "/sys/class/" +
                device.deviceClass +
                "/" +
                device.deviceId

            readonly property string name:
                device.deviceId

            readonly property string className:
                device.deviceClass

            readonly property string type:
                device.isBacklight
                    ? "backlight"
                    : "led"

            readonly property bool isBacklight:
                device.deviceClass ===
                "backlight"

            readonly property bool isLed:
                device.deviceClass ===
                "leds"

            readonly property string displayName:
                device.deviceId

            // --------------------------------------------------------
            // Runtime resources
            // --------------------------------------------------------

            property var currentFile: null
            property var maxFile: null

            // --------------------------------------------------------
            // Runtime values
            // --------------------------------------------------------

            property int value: 0
            property int max: 0

            readonly property bool isPresent:
                !!device.currentFile &&
                device.currentFile.loaded

            readonly property real percent:
                device.max > 0
                    ? Math.max(
                          0,
                          Math.min(
                              100,
                              (
                                  device.value *
                                  100
                              ) /
                              device.max
                          )
                      )
                    : 0

            readonly property int percentRounded:
                Math.round(
                    device.percent
                )

            readonly property string percentText:
                String(
                    device.percentRounded
                ) + "%"

            // --------------------------------------------------------
            // Internal update functions
            // --------------------------------------------------------

            function updateCurrentValue() {
                if (!device.currentFile)
                    return

                device.value =
                    root.readInteger(
                        device.currentFile.text()
                    )
            }

            function updateMaxValue() {
                if (!device.maxFile)
                    return

                device.max =
                    root.readInteger(
                        device.maxFile.text()
                    )
            }

            // --------------------------------------------------------
            // Public convenience controls
            // --------------------------------------------------------

            function set(value) {
                return root.set(
                    device,
                    value
                )
            }

            function increase(amount) {
                return root.increase(
                    device,
                    amount
                )
            }

            function decrease(amount) {
                return root.decrease(
                    device,
                    amount
                )
            }

            function refresh() {
                if (
                    device.currentFile &&
                    device.currentFile.loaded
                ) {
                    device.currentFile.reload()
                }

                if (
                    device.maxFile &&
                    device.maxFile.loaded
                ) {
                    device.maxFile.reload()
                }
            }
        }
    }

    // ============================================================
    // CURRENT BRIGHTNESS FILE
    // ============================================================

    Component {
        id: currentFileComponent

        FileView {
            property var ownerDevice: null

            blockLoading: true
            watchChanges: true
            printErrors: false

            /*
             * FileView does not automatically reload its content
             * when watchChanges emits fileChanged().
             */
            onFileChanged: {
                reload()
            }

            onLoaded: {
                if (ownerDevice)
                    ownerDevice.updateCurrentValue()
            }

            onLoadFailed: function(error) {
                console.warn(
                    "[Brightness] failed to load brightness file:",
                    path,
                    FileViewError.toString(error)
                )
            }
        }
    }

    // ============================================================
    // MAX BRIGHTNESS FILE
    // ============================================================

    Component {
        id: maxFileComponent

        FileView {
            property var ownerDevice: null

            blockLoading: true
            watchChanges: false
            printErrors: false

            onLoaded: {
                if (ownerDevice)
                    ownerDevice.updateMaxValue()
            }

            onLoadFailed: function(error) {
                console.warn(
                    "[Brightness] failed to load max-brightness file:",
                    path,
                    FileViewError.toString(error)
                )
            }
        }
    }

    // ============================================================
    // CONTROL PROCESS
    // ============================================================

    /*
     * Each brightness operation gets its own short-lived Process.
     *
     * This gives us a completion callback so we can reload the
     * sysfs value immediately after brightnessctl finishes,
     * without polling.
     */

    Component {
        id: controlProcessComponent

        Process {
            property var targetDevice: null
            property string targetValue: ""

            command: [
                "brightnessctl",
                "--quiet",
                "--class",
                targetDevice
                    ? targetDevice.className
                    : "",
                "--device",
                targetDevice
                    ? targetDevice.deviceId
                    : "",
                "set",
                targetValue
            ]

            onExited: function(exitCode) {
                if (
                    exitCode !== 0 &&
                    targetDevice
                ) {
                    console.warn(
                        "[Brightness] brightnessctl operation failed:",
                        targetDevice.key,
                        exitCode
                    )
                }

                if (targetDevice) {
                    targetDevice.refresh()
                }

                destroy()
            }
        }
    }

    // ============================================================
    // STARTUP
    // ============================================================

    Component.onCompleted: {
        root.refresh()
    }

    // ============================================================
    // DISCOVERY
    // ============================================================

    function refresh() {
        if (root._discovering)
            return

        discovery.running = true
    }

    function applyDiscovery(lines) {
        const discovered = []
        const seen = Object.create(null)

        /*
         * brightnessctl -m output:
         *
         * DEVICE,CLASS,CURRENT,PERCENT,MAX
         */

        for (
            let i = 0;
            i < lines.length;
            ++i
        ) {
            const line =
                String(lines[i]).trim()

            if (line.length === 0)
                continue

            const parts =
                line.split(",")

            if (parts.length < 5)
                continue

            const deviceId =
                String(
                    parts[0]
                ).trim()

            const deviceClass =
                String(
                    parts[1]
                ).trim()

            if (
                deviceId.length === 0 ||
                deviceClass.length === 0
            ) {
                continue
            }

            const key =
                deviceClass +
                ":" +
                deviceId

            if (seen[key])
                continue

            seen[key] = true

            discovered.push({
                id:
                    deviceId,

                className:
                    deviceClass,

                key:
                    key
            })
        }

        // --------------------------------------------------------
        // Existing device lookup
        // --------------------------------------------------------

        const existing =
            Object.create(null)

        for (
            let i = 0;
            i < root._devices.length;
            ++i
        ) {
            const existingDevice =
                root._devices[i]

            if (!existingDevice)
                continue

            existing[
                existingDevice.key
            ] = existingDevice
        }

        const nextDevices = []

        // --------------------------------------------------------
        // Create / retain devices
        // --------------------------------------------------------

        for (
            let i = 0;
            i < discovered.length;
            ++i
        ) {
            const info =
                discovered[i]

            let device =
                existing[info.key]

            if (!device) {
                device =
                    deviceComponent.createObject(
                        root,
                        {
                            deviceId:
                                info.id,

                            deviceClass:
                                info.className
                        }
                    )

                if (!device) {
                    console.warn(
                        "[Brightness] failed to create:",
                        info.key
                    )

                    continue
                }

                // ------------------------------------------------
                // Explicit FileView creation.
                // ------------------------------------------------

                const currentFile =
                    currentFileComponent.createObject(
                        device,
                        {
                            path:
                                device.sysfsPath +
                                "/brightness",

                            ownerDevice:
                                device
                        }
                    )

                const maxFile =
                    maxFileComponent.createObject(
                        device,
                        {
                            path:
                                device.sysfsPath +
                                "/max_brightness",

                            ownerDevice:
                                device
                        }
                    )

                if (!currentFile) {
                    console.warn(
                        "[Brightness] failed to create current watcher:",
                        device.key
                    )
                }

                if (!maxFile) {
                    console.warn(
                        "[Brightness] failed to create max watcher:",
                        device.key
                    )
                }

                device.currentFile =
                    currentFile

                device.maxFile =
                    maxFile
            }

            nextDevices.push(
                device
            )
        }

        // --------------------------------------------------------
        // Remove devices that disappeared
        // --------------------------------------------------------

        for (
            let i = 0;
            i < root._devices.length;
            ++i
        ) {
            const oldDevice =
                root._devices[i]

            if (!oldDevice)
                continue

            if (
                nextDevices.indexOf(
                    oldDevice
                ) === -1
            ) {
                const removedKey =
                    oldDevice.key

                /*
                 * FileViews are QObject children of the device,
                 * so destroying the device destroys them too.
                 */
                oldDevice.destroy()

                console.info(
                    "[Brightness] removed:",
                    removedKey
                )
            }
        }

        // --------------------------------------------------------
        // Commit state
        // --------------------------------------------------------

        root._devices =
            nextDevices

        // --------------------------------------------------------
        // Preserve selected device only while it exists.
        // --------------------------------------------------------

        if (
            root._selectedKey.length > 0 &&
            !root.deviceForKey(
                root._selectedKey
            )
        ) {
            root._selectedKey = ""
        }
    }

    // ============================================================
    // CLEAR
    // ============================================================

    function clearDevices() {
        for (
            let i = 0;
            i < root._devices.length;
            ++i
        ) {
            const device =
                root._devices[i]

            if (device)
                device.destroy()
        }

        root._devices = []
        root._selectedKey = ""
    }

    // ============================================================
    // LOOKUP
    // ============================================================

    function deviceForKey(key) {
        if (
            key === undefined ||
            key === null
        ) {
            return null
        }

        const target =
            String(key)

        if (target.length === 0)
            return null

        for (
            let i = 0;
            i < root._devices.length;
            ++i
        ) {
            const device =
                root._devices[i]

            if (
                device &&
                device.key === target
            ) {
                return device
            }
        }

        return null
    }

    function deviceFor(
        className,
        deviceId
    ) {
        return root.deviceForKey(
            String(className) +
            ":" +
            String(deviceId)
        )
    }

    function findDefaultDevice() {
        /*
         * Prefer an actual backlight.
         */

        for (
            let i = 0;
            i < root._devices.length;
            ++i
        ) {
            const device =
                root._devices[i]

            if (
                device &&
                device.isBacklight
            ) {
                return device
            }
        }

        /*
         * Otherwise use the first brightness device.
         */

        return root._devices.length > 0
            ? root._devices[0]
            : null
    }

    function resolveDevice(value) {
        if (
            value === undefined ||
            value === null
        ) {
            return null
        }

        if (
            typeof value === "object"
        ) {
            /*
             * Only accept a device belonging to this service.
             *
             * This prevents an arbitrary QML object with a `key`
             * property from being sent to brightnessctl.
             */
            if (
                value.key === undefined ||
                value.key === null
            ) {
                return null
            }

            return root.deviceForKey(
                value.key
            )
        }

        return root.deviceForKey(
            String(value)
        )
    }

    // ============================================================
    // OPERATION PROCESS
    // ============================================================

    function runOperation(
        device,
        value
    ) {
        if (!device)
            return false

        const process =
            controlProcessComponent.createObject(
                root,
                {
                    targetDevice:
                        device,

                    targetValue:
                        String(value)
                }
            )

        if (!process) {
            console.warn(
                "[Brightness] failed to create control process:",
                device.key
            )

            return false
        }

        process.running = true

        return true
    }

    // ============================================================
    // SET
    // ============================================================

    function set(
        device,
        value
    ) {
        const target =
            root.resolveDevice(
                device
            )

        if (!target)
            return false

        let percent =
            Number(value)

        if (!isFinite(percent))
            return false

        percent =
            Math.max(
                0,
                Math.min(
                    100,
                    percent
                )
            )

        return root.runOperation(
            target,
            String(percent) + "%"
        )
    }

    // ============================================================
    // INCREASE
    // ============================================================

    function increase(
        device,
        amount
    ) {
        const target =
            root.resolveDevice(
                device
            )

        if (!target)
            return false

        let step =
            Number(amount)

        if (
            !isFinite(step) ||
            step <= 0
        ) {
            step = 5
        }

        return root.runOperation(
            target,
            "+" + String(step) + "%"
        )
    }

    // ============================================================
    // DECREASE
    // ============================================================

    function decrease(
        device,
        amount
    ) {
        const target =
            root.resolveDevice(
                device
            )

        if (!target)
            return false

        let step =
            Number(amount)

        if (
            !isFinite(step) ||
            step <= 0
        ) {
            step = 5
        }

        return root.runOperation(
            target,
            "-" + String(step) + "%"
        )
    }

    // ============================================================
    // DEVICE SELECTION
    // ============================================================

    function setDevice(key) {
        const target =
            root.deviceForKey(
                key
            )

        if (!target)
            return false

        root._selectedKey =
            target.key

        return true
    }

    function resetDevice() {
        root._selectedKey = ""

        return true
    }

    // ============================================================
    // SERIALIZATION
    // ============================================================

    function deviceInfo(device) {
        if (!device)
            return {}

        return {
            key:
                device.key,

            id:
                device.deviceId,

            class:
                device.deviceClass,

            name:
                device.name,

            displayName:
                device.displayName,

            type:
                device.type,

            isBacklight:
                device.isBacklight,

            isLed:
                device.isLed,

            isPresent:
                device.isPresent,

            value:
                device.value,

            max:
                device.max,

            percent:
                device.percentRounded,

            percentText:
                device.percentText,

            sysfsPath:
                device.sysfsPath,

            selected:
                root.device === device
        }
    }

    // ============================================================
    // VALUE HELPERS
    // ============================================================

    function readInteger(value) {
        const result =
            parseInt(
                String(value).trim(),
                10
            )

        if (!isFinite(result))
            return 0

        return Math.max(
            0,
            result
        )
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-brightness"

        // --------------------------------------------------------
        // STATE
        // --------------------------------------------------------

        function isAvailable(): bool {
            return root.isAvailable
        }

        function isDiscovering(): bool {
            return root.isDiscovering
        }

        function hasDevice(): bool {
            return root.hasDevice
        }

        function count(): int {
            return root.count
        }

        function get(): string {
            return root.percentText
        }

        function getValue(): real {
            return root.value
        }

        function getMax(): real {
            return root.max
        }

        function getDeviceName(): string {
            return root.deviceName
        }

        function getDeviceKey(): string {
            return root.deviceKey
        }

        function getDefault(): string {
            return root.defaultDevice
                ? root.defaultDevice.key
                : ""
        }

        function getDevice(): string {
            return root.device
                ? JSON.stringify(
                      root.deviceInfo(
                          root.device
                      )
                  )
                : ""
        }

        // --------------------------------------------------------
        // DEVICE LISTS
        // --------------------------------------------------------

        function list(): string {
            const result = []

            for (
                let i = 0;
                i < root._devices.length;
                ++i
            ) {
                result.push(
                    root.deviceInfo(
                        root._devices[i]
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }

        function backlights(): string {
            return JSON.stringify(
                root.backlights.map(
                    function(device) {
                        return root.deviceInfo(
                            device
                        )
                    }
                )
            )
        }

        function leds(): string {
            return JSON.stringify(
                root.leds.map(
                    function(device) {
                        return root.deviceInfo(
                            device
                        )
                    }
                )
            )
        }

        // --------------------------------------------------------
        // CURRENT DEVICE
        // --------------------------------------------------------

        function set(
            percent: real
        ): bool {
            return root.set(
                root.device,
                percent
            )
        }

        function increase(
            percent: real
        ): bool {
            return root.increase(
                root.device,
                percent
            )
        }

        function decrease(
            percent: real
        ): bool {
            return root.decrease(
                root.device,
                percent
            )
        }

        // --------------------------------------------------------
        // SPECIFIC DEVICE
        // --------------------------------------------------------

        function setDevice(
            key: string
        ): bool {
            return root.setDevice(
                key
            )
        }

        function resetDevice(): bool {
            return root.resetDevice()
        }

        function setDeviceValue(
            key: string,
            percent: real
        ): bool {
            return root.set(
                root.deviceForKey(
                    key
                ),
                percent
            )
        }

        function increaseDevice(
            key: string,
            percent: real
        ): bool {
            return root.increase(
                root.deviceForKey(
                    key
                ),
                percent
            )
        }

        function decreaseDevice(
            key: string,
            percent: real
        ): bool {
            return root.decrease(
                root.deviceForKey(
                    key
                ),
                percent
            )
        }

        // --------------------------------------------------------
        // DISCOVERY
        // --------------------------------------------------------

        function refresh(): void {
            root.refresh()
        }
    }
}