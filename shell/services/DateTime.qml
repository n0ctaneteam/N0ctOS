pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============================================================
    // CLOCK
    // ============================================================

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ============================================================
    // CONFIGURATION
    // ============================================================

    readonly property string firstDay:
        normalizeFirstDay(
            Config.get(
                "datetime.firstDay",
                "sun"
            )
        )

    readonly property int firstDayOfWeek:
        root.firstDay === "mon"
            ? Qt.Monday
            : Qt.Sunday

    readonly property string timeFormat:
        normalizeTimeFormat(
            Config.get(
                "datetime.timeFormat",
                "24h"
            )
        )

    readonly property string dateFormat:
        normalizeDateFormat(
            Config.get(
                "datetime.dateFormat",
                "dd/MM/yyyy"
            )
        )

    // ============================================================
    // CURRENT DATE/TIME
    // ============================================================

    readonly property date now:
        clock.date

    readonly property int year:
        clock.date.getFullYear()

    readonly property int month:
        clock.date.getMonth() + 1

    readonly property int day:
        clock.date.getDate()

    readonly property int dayOfWeek:
        clock.date.getDay()

    readonly property int hour:
        clock.date.getHours()

    readonly property int minute:
        clock.date.getMinutes()

    readonly property int second:
        clock.date.getSeconds()

    // ============================================================
    // NAMES
    // ============================================================

    readonly property string monthName:
        Qt.formatDateTime(
            clock.date,
            "MMMM"
        )

    readonly property string monthShortName:
        Qt.formatDateTime(
            clock.date,
            "MMM"
        )

    readonly property string weekdayName:
        Qt.formatDateTime(
            clock.date,
            "dddd"
        )

    readonly property string weekdayShortName:
        Qt.formatDateTime(
            clock.date,
            "ddd"
        )

    // ============================================================
    // PATTERNS
    // ============================================================

    readonly property string timePattern:
        root.timeFormat === "12h"
            ? "hh:mm AP"
            : "HH:mm"

    readonly property string timePatternWithSeconds:
        root.timeFormat === "12h"
            ? "hh:mm:ss AP"
            : "HH:mm:ss"

    readonly property string datetimePattern:
        root.dateFormat +
        " " +
        root.timePattern

    readonly property string datetimePatternWithSeconds:
        root.dateFormat +
        " " +
        root.timePatternWithSeconds

    // ============================================================
    // READY-TO-USE OUTPUT
    // ============================================================

    readonly property string time:
        formatTime()

    readonly property string timeWithSeconds:
        formatTimeWithSeconds()

    readonly property string date:
        formatDate()

    readonly property string datetime:
        formatDateTime()

    readonly property string datetimeWithSeconds:
        formatDateTimeWithSeconds()

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-datetime"

        function getTime(): string {
            return root.time
        }

        function getDate(): string {
            return root.date
        }

        function getDateTime(): string {
            return root.datetime
        }

        function getTimeFormat(): string {
            return root.timeFormat
        }

        function getFirstDay(): string {
            return root.firstDay
        }

        function getDateFormat(): string {
            return root.dateFormat
        }

        function setTimeFormat(
            value: string
        ): bool {
            return Config.set(
                "datetime.timeFormat",
                root.normalizeTimeFormat(value)
            )
        }

        function setFirstDay(
            value: string
        ): bool {
            return Config.set(
                "datetime.firstDay",
                root.normalizeFirstDay(value)
            )
        }

        function setDateFormat(
            value: string
        ): bool {
            return Config.set(
                "datetime.dateFormat",
                root.normalizeDateFormat(value)
            )
        }
    }

    // ============================================================
    // NORMALIZATION
    // ============================================================

    function normalizeFirstDay(value) {
        const normalized =
            String(value).toLowerCase()

        if (
            normalized === "sun" ||
            normalized === "sunday"
        ) {
            return "sun"
        }

        if (
            normalized === "mon" ||
            normalized === "monday"
        ) {
            return "mon"
        }

        return "sun"
    }

    function normalizeTimeFormat(value) {
        const normalized =
            String(value).toLowerCase()

        if (
            normalized === "12" ||
            normalized === "12h" ||
            normalized === "12-hour"
        ) {
            return "12h"
        }

        return "24h"
    }

    function normalizeDateFormat(value) {
        const format =
            String(value)

        if (format.length === 0)
            return "dd/MM/yyyy"

        return format
    }

    // ============================================================
    // FORMAT
    // ============================================================

    function format(pattern) {
        if (
            pattern === undefined ||
            pattern === null ||
            pattern === ""
        ) {
            return root.datetime
        }

        switch (String(pattern)) {
        case "time":
        case "<time>":
            return root.time

        case "timeWithSeconds":
        case "<timeWithSeconds>":
            return root.timeWithSeconds

        case "date":
        case "<date>":
            return root.date

        case "datetime":
        case "<datetime>":
            return root.datetime

        case "datetimeWithSeconds":
        case "<datetimeWithSeconds>":
            return root.datetimeWithSeconds

        default:
            return Qt.formatDateTime(
                root.now,
                String(pattern)
            )
        }
    }

    // ============================================================
    // FORMATTERS
    // ============================================================

    function formatTime(value) {
        const input =
            value === undefined ||
            value === null
                ? root.now
                : value

        return Qt.formatDateTime(
            input,
            root.timePattern
        )
    }

    function formatTimeWithSeconds(value) {
        const input =
            value === undefined ||
            value === null
                ? root.now
                : value

        return Qt.formatDateTime(
            input,
            root.timePatternWithSeconds
        )
    }

    function formatDate(value) {
        const input =
            value === undefined ||
            value === null
                ? root.now
                : value

        return Qt.formatDateTime(
            input,
            root.dateFormat
        )
    }

    function formatDateTime(value) {
        const input =
            value === undefined ||
            value === null
                ? root.now
                : value

        return Qt.formatDateTime(
            input,
            root.datetimePattern
        )
    }

    function formatDateTimeWithSeconds(value) {
        const input =
            value === undefined ||
            value === null
                ? root.now
                : value

        return Qt.formatDateTime(
            input,
            root.datetimePatternWithSeconds
        )
    }

    // ============================================================
    // CALENDAR
    // ============================================================

    function startOfWeek(value) {
        const input =
            value === undefined ||
            value === null
                ? root.now
                : value

        const result =
            new Date(input.getTime())

        result.setHours(
            0,
            0,
            0,
            0
        )

        const currentDay =
            result.getDay()

        const first =
            root.firstDay === "mon"
                ? 1
                : 0

        const offset =
            (
                currentDay -
                first +
                7
            ) % 7

        result.setDate(
            result.getDate() -
            offset
        )

        return result
    }

    function endOfWeek(value) {
        const result =
            root.startOfWeek(value)

        result.setDate(
            result.getDate() + 6
        )

        result.setHours(
            23,
            59,
            59,
            999
        )

        return result
    }

    function isToday(value) {
        if (
            value === undefined ||
            value === null
        ) {
            return false
        }

        return (
            value.getFullYear() ===
                root.year &&
            value.getMonth() ===
                root.now.getMonth() &&
            value.getDate() ===
                root.day
        )
    }

    // ============================================================
    // CONFIG WRITERS
    // ============================================================

    function setTimeFormat(value) {
        return Config.set(
            "datetime.timeFormat",
            normalizeTimeFormat(value)
        )
    }

    function setFirstDay(value) {
        return Config.set(
            "datetime.firstDay",
            normalizeFirstDay(value)
        )
    }

    function setDateFormat(value) {
        return Config.set(
            "datetime.dateFormat",
            normalizeDateFormat(value)
        )
    }
}