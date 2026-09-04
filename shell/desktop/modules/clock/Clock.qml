import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string moduleId: "clock"
    property var blob: null

    property bool popupVisible: false
    property string popupText: ""
    property int popupDuration: 4000
    property string timeText: Qt.formatTime(new Date(), "hh:mm:ss")

    implicitWidth: 180
    implicitHeight: 80

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered:
            root.timeText = Qt.formatTime(new Date(), "hh:mm:ss")
    }

    Timer {
        id: popupTimer
        repeat: false
        onTriggered:
            root.hidePopup()
    }

    function showPopup(message, duration) {
        root.popupText = message || "Clock popup"
        root.popupVisible = true

        const ms = Number(duration) || 0

        if (root.blob && typeof root.blob.showBlobFor === "function") {
            if (ms > 0) {
                root.popupDuration = ms
                root.blob.showBlobFor(ms)
            } else {
                root.blob.showBlob()
            }
        }

        if (ms > 0) {
            popupTimer.interval = ms
            popupTimer.restart()
        } else {
            popupTimer.stop()
        }
    }

    function hidePopup() {
        popupTimer.stop()
        root.popupVisible = false

        if (root.blob && typeof root.blob.hideBlob === "function")
            root.blob.hideBlob()
    }

    function togglePopup(message, duration) {
        if (root.popupVisible) {
            root.hidePopup()
            return
        }

        const ms = Number(duration) || root.popupDuration
        root.showPopup(message || "Clock popup", ms)
    }

    IpcHandler {
        target: "n0ctos-clock"

        function popup(message: string, duration: int): void {
            root.showPopup(message, duration)
        }

        function show(message: string): void {
            root.showPopup(message, 0)
        }

        function hide(): void {
            root.hidePopup()
        }

        function toggle(message: string, duration: int): void {
            root.togglePopup(message, duration)
        }

        function pulse(): void {
            root.showPopup("Hello from Clock", 3000)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#10151d"
        border.width: 1
        border.color:
            root.popupVisible
                ? "#2acfff"
                : "#253241"

        Text {
            anchors.centerIn: parent

            text:
                root.popupVisible
                    ? root.popupText
                    : root.timeText

            color: "white"
            font.pixelSize:
                root.popupVisible
                    ? 16
                    : 26

            font.family: "Symbols Nerd Font"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8

            visible: !root.popupVisible

            text: "CLOCK"
            color: "#7f8b99"
            font.pixelSize: 9
        }
    }
}