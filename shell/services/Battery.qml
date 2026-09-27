pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    // ============================================================
    // CONSTANTS
    // ============================================================

    readonly property real lowThreshold:
        20

    readonly property real criticalThreshold:
        10

    // ============================================================
    // PRIMARY DISPLAY DEVICE
    // ============================================================

    /*
     * UPower.displayDevice is the aggregate desktop device.
     * It is the correct source for the overall battery state,
     * charge percentage, charging state, time estimates, etc.
     */
    readonly property var device:
        UPower.displayDevice

    readonly property bool isReady:
        !!root.device &&
        root.device.ready

    // ============================================================
    // PHYSICAL LAPTOP BATTERY
    // ============================================================

    /*
     * Health belongs to the actual physical battery device,
     * not the aggregate displayDevice.
     *
     * batteryModel only contains actual laptop batteries.
     */
    readonly property var primaryBattery:
        root.batteryList.length > 0
            ? root.batteryList[0]
            : null

    readonly property bool isPresent:
        !!root.primaryBattery &&
        root.primaryBattery.isPresent

    // ============================================================
    // POWER STATE
    // ============================================================

    readonly property bool isOnBattery:
        UPower.onBattery

    readonly property bool isPluggedIn:
        root.isPresent &&
        !root.isOnBattery

    readonly property bool isCharging:
        root.isReady &&
        (
            root.device.state ===
                UPowerDeviceState.Charging ||
            root.device.state ===
                UPowerDeviceState.PendingCharge
        )

    readonly property bool isDischarging:
        root.isReady &&
        (
            root.device.state ===
                UPowerDeviceState.Discharging ||
            root.device.state ===
                UPowerDeviceState.PendingDischarge
        )

    readonly property bool isFull:
        root.isReady &&
        (
            root.device.state ===
                UPowerDeviceState.FullyCharged ||
            root.percent >= 99
        )

    readonly property bool isLow:
        root.isPresent &&
        !root.isCharging &&
        root.percent <= root.lowThreshold &&
        !root.isCritical

    readonly property bool isCritical:
        root.isPresent &&
        !root.isCharging &&
        root.percent <= root.criticalThreshold

    // ============================================================
    // PRIMARY VALUES
    // ============================================================

    /*
     * Quickshell exposes UPowerDevice.percentage as 0.0 -> 1.0.
     * Convert it to the public N0ctOS API range of 0 -> 100.
     */
    readonly property real percent:
        root.isReady
            ? Math.max(
                  0,
                  Math.min(
                      100,
                      Number(root.device.percentage) * 100
                  )
              )
            : 0

    readonly property int percentRounded:
        Math.round(root.percent)

    readonly property string percentText:
        String(root.percentRounded) + "%"

    readonly property real energy:
        root.isReady
            ? Number(root.device.energy)
            : 0

    readonly property real energyCapacity:
        root.isReady
            ? Number(root.device.energyCapacity)
            : 0

    readonly property real changeRate:
        root.isReady
            ? Number(root.device.changeRate)
            : 0

    // ============================================================
    // TIME ESTIMATES
    // ============================================================

    readonly property real timeToEmpty:
        root.isReady
            ? Number(root.device.timeToEmpty)
            : 0

    readonly property real timeToFull:
        root.isReady
            ? Number(root.device.timeToFull)
            : 0

    readonly property real timeRemaining:
        root.isCharging
            ? root.timeToFull
            : root.timeToEmpty

    readonly property string timeRemainingText:
        root.formatDuration(
            root.timeRemaining
        )

    // ============================================================
    // HEALTH
    // ============================================================

    /*
     * IMPORTANT:
     *
     * Do NOT use:
     *
     *     UPower.displayDevice.healthPercentage
     *
     * displayDevice is an aggregate device and may not provide
     * physical battery Capacity information.
     *
     * Use the real laptop battery from UPower.devices instead.
     */
    readonly property bool isHealthSupported:
        !!root.primaryBattery &&
        root.primaryBattery.ready &&
        root.primaryBattery.healthSupported

    readonly property real health:
        root.isHealthSupported
            ? Math.max(
                  0,
                  Math.min(
                      100,
                      Number(
                          root.primaryBattery.healthPercentage
                      )
                  )
              )
            : 0

    readonly property int healthRounded:
        Math.round(root.health)

    readonly property string healthText:
        root.isHealthSupported
            ? String(root.healthRounded) + "%"
            : ""

    // ============================================================
    // STATE
    // ============================================================

    readonly property var state:
        root.isReady
            ? root.device.state
            : UPowerDeviceState.Unknown

    readonly property string stateName:
        UPowerDeviceState.toString(
            root.state
        )

    readonly property string model:
        root.isReady
            ? String(
                  root.device.model || ""
              )
            : ""

    readonly property string nativePath:
        root.isReady
            ? String(
                  root.device.nativePath || ""
              )
            : ""

    // ============================================================
    // ICON
    // ============================================================

    readonly property string icon:
        root.iconFor(
            root.percent,
            root.isCharging,
            root.isCritical,
            root.isFull
        )

    readonly property string iconKey:
        root.iconKeyFor(
            root.percent,
            root.isCharging,
            root.isCritical,
            root.isFull
        )

    // ============================================================
    // BATTERY LIST
    // ============================================================

    ScriptModel {
        id: batteryModel

        values:
            UPower.devices.values.filter(
                function(device) {
                    return (
                        !!device &&
                        device.isLaptopBattery
                    )
                }
            )
    }

    /*
     * QML model:
     *
     *     ListView {
     *         model: Battery.batteries
     *     }
     */
    readonly property var batteries:
        batteryModel

    /*
     * Normal JavaScript list:
     *
     *     for (...)
     */
    readonly property var batteryList:
        batteryModel.values

    readonly property int batteryCount:
        batteryModel.values.length

    // ============================================================
    // SIGNALS
    // ============================================================

    signal stateChangedExternally()
    signal deviceAdded(var device)
    signal deviceRemoved(var device)

    // ============================================================
    // UPOWER MODEL CHANGE TRACKING
    // ============================================================

    Connections {
        target: UPower.devices

        function onObjectInsertedPost(
            device,
            index
        ) {
            root.deviceAdded(device)
        }

        function onObjectRemovedPost(
            device,
            index
        ) {
            root.deviceRemoved(device)
        }
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-battery"

        function getPercent(): string {
            return root.percentText
        }

        function getState(): string {
            return root.stateName
        }

        function getTimeRemaining(): string {
            return root.timeRemainingText
        }

        function getHealth(): string {
            return root.healthText
        }

        function getIcon(): string {
            return root.icon
        }

        function getStatus(): string {
            return JSON.stringify({
                isPresent:
                    root.isPresent,

                isReady:
                    root.isReady,

                isOnBattery:
                    root.isOnBattery,

                isPluggedIn:
                    root.isPluggedIn,

                isCharging:
                    root.isCharging,

                isDischarging:
                    root.isDischarging,

                isFull:
                    root.isFull,

                isLow:
                    root.isLow,

                isCritical:
                    root.isCritical,

                isHealthSupported:
                    root.isHealthSupported,

                percent:
                    root.percentRounded,

                state:
                    root.stateName,

                timeRemaining:
                    root.timeRemaining,

                timeRemainingText:
                    root.timeRemainingText,

                health:
                    root.isHealthSupported
                        ? root.health
                        : null,

                healthText:
                    root.healthText,

                icon:
                    root.icon
            })
        }

        function getDevices(): string {
            const result = []

            for (
                let i = 0;
                i < root.batteryList.length;
                ++i
            ) {
                result.push(
                    root.deviceInfo(
                        root.batteryList[i]
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }
    }

    // ============================================================
    // HELPERS
    // ============================================================

    function percentBucket(percent) {
        if (percent <= 0)
            return 0

        if (percent < 10)
            return 0

        if (percent < 20)
            return 10

        if (percent < 30)
            return 20

        if (percent < 40)
            return 30

        if (percent < 50)
            return 40

        if (percent < 60)
            return 50

        if (percent < 70)
            return 60

        if (percent < 80)
            return 70

        if (percent < 90)
            return 80

        if (percent < 100)
            return 90

        return 100
    }

    function iconFor(
        percent,
        charging,
        critical,
        full
    ) {
        if (critical)
            return "󰥇"

        if (full)
            return "󰂅"

        const bucket =
            root.percentBucket(
                percent
            )

        if (charging) {
            switch (bucket) {
            case 0:
                return "󰢟"

            case 10:
                return "󰢜"

            case 20:
                return "󰂆"

            case 30:
                return "󰂇"

            case 40:
                return "󰂈"

            case 50:
                return "󰢝"

            case 60:
                return "󰂉"

            case 70:
                return "󰢞"

            case 80:
                return "󰂊"

            case 90:
                return "󰂋"

            default:
                return "󰂅"
            }
        }

        switch (bucket) {
        case 0:
            return "󰂎"

        case 10:
            return "󰁺"

        case 20:
            return "󰁻"

        case 30:
            return "󰁼"

        case 40:
            return "󰁽"

        case 50:
            return "󰁾"

        case 60:
            return "󰁿"

        case 70:
            return "󰂀"

        case 80:
            return "󰂁"

        case 90:
            return "󰂂"

        default:
            return "󰁹"
        }
    }

    function iconKeyFor(
        percent,
        charging,
        critical,
        full
    ) {
        if (critical)
            return "battery-alert"

        if (full)
            return "battery-charging-100"

        const bucket =
            root.percentBucket(
                percent
            )

        if (charging) {
            return (
                bucket === 0
                    ? "battery-charging-outline"
                    : "battery-charging-" +
                      String(bucket)
            )
        }

        return (
            bucket === 0
                ? "battery-outline"
                : bucket === 100
                    ? "battery"
                    : "battery-" +
                      String(bucket)
        )
    }

    function formatDuration(seconds) {
        const value =
            Number(seconds)

        if (
            !isFinite(value) ||
            value <= 0
        ) {
            return ""
        }

        const totalMinutes =
            Math.floor(
                value / 60
            )

        const hours =
            Math.floor(
                totalMinutes / 60
            )

        const minutes =
            totalMinutes % 60

        if (hours > 0) {
            return (
                String(hours) +
                "h " +
                String(minutes) +
                "m"
            )
        }

        return (
            String(minutes) +
            "m"
        )
    }

    function deviceInfo(device) {
        if (!device)
            return {}

        const isCharging =
            device.state ===
                UPowerDeviceState.Charging ||
            device.state ===
                UPowerDeviceState.PendingCharge

        const isDischarging =
            device.state ===
                UPowerDeviceState.Discharging ||
            device.state ===
                UPowerDeviceState.PendingDischarge

        const hasHealth =
            device.ready &&
            device.healthSupported

        return {
            nativePath:
                String(
                    device.nativePath || ""
                ),

            model:
                String(
                    device.model || ""
                ),

            type:
                UPowerDeviceType.toString(
                    device.type
                ),

            isReady:
                !!device.ready,

            isPresent:
                !!device.isPresent,

            isLaptopBattery:
                !!device.isLaptopBattery,

            isHealthSupported:
                !!hasHealth,

            percent:
                Math.round(
                    Math.max(
                        0,
                        Math.min(
                            100,
                            Number(
                                device.percentage
                            ) * 100
                        )
                    )
                ),

            health:
                hasHealth
                    ? Math.max(
                          0,
                          Math.min(
                              100,
                              Number(
                                  device.healthPercentage
                              )
                          )
                      )
                    : null,

            isCharging:
                isCharging,

            isDischarging:
                isDischarging,

            state:
                UPowerDeviceState.toString(
                    device.state
                ),

            energy:
                Number(
                    device.energy
                ),

            energyCapacity:
                Number(
                    device.energyCapacity
                ),

            changeRate:
                Number(
                    device.changeRate
                ),

            timeToEmpty:
                Number(
                    device.timeToEmpty
                ),

            timeToFull:
                Number(
                    device.timeToFull
                )
        }
    }
}