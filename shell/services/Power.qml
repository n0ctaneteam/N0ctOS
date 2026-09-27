pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============================================================
    // SESSION
    // ============================================================

    readonly property string sessionId:
        String(
            Quickshell.env(
                "XDG_SESSION_ID"
            ) || ""
        )

    readonly property string user:
        String(
            Quickshell.env(
                "USER"
            ) || ""
        )

    // ============================================================
    // INTERNAL COMMAND
    // ============================================================

    function _run(command) {
        if (
            !command ||
            command.length === 0
        ) {
            return false
        }

        Quickshell.execDetached({
            command: command
        })

        return true
    }

    // ============================================================
    // POWER
    // ============================================================

    function shutdown() {
        return root._run([
            "systemctl",
            "poweroff"
        ])
    }

    function reboot() {
        return root._run([
            "systemctl",
            "reboot"
        ])
    }

    function suspend() {
        return root._run([
            "systemctl",
            "suspend"
        ])
    }

    function hibernate() {
        return root._run([
            "systemctl",
            "hibernate"
        ])
    }

    // ============================================================
    // SESSION
    // ============================================================

    function lock() {
        return root._run([
            "loginctl",
            "lock-session"
        ])
    }

    function logout() {
        if (
            !root.sessionId
        ) {
            console.warn(
                "[Power] XDG_SESSION_ID is unavailable"
            )

            return false
        }

        return root._run([
            "loginctl",
            "terminate-session",
            root.sessionId
        ])
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-power"

        function shutdown(): bool {
            return root.shutdown()
        }

        function reboot(): bool {
            return root.reboot()
        }

        function suspend(): bool {
            return root.suspend()
        }

        function hibernate(): bool {
            return root.hibernate()
        }

        function lock(): bool {
            return root.lock()
        }

        function logout(): bool {
            return root.logout()
        }
    }
}