import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    color:"red"
    implicitWidth: 180
    implicitHeight: 56

    property real usage: 0
    property var previous: null

    Process {
        id: proc

        command: ["cat", "/proc/stat"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.update(text)
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    function update(text) {
        const line = text.split("\n")[0]

        if (!line.startsWith("cpu "))
            return

        const v = line.trim().split(/\s+/).slice(1).map(Number)

        const idle = v[3] + (v[4] || 0)
        const total = v.reduce((a, b) => a + b, 0)

        if (previous) {
            const dt = total - previous.total
            const di = idle - previous.idle

            if (dt > 0)
                usage = Math.max(0, Math.min(100, (1 - di / dt) * 100))
        }

        previous = {
            total: total,
            idle: idle
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#20242c"
        border.width: 1
        border.color: "#4b5363"

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Text {
                width: 30
                height: parent.height
                text: "󰻠"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 23
                color: "#ffffff"
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                spacing: 4

                Text {
                    text: "CPU  " + root.usage.toFixed(1) + "%"
                    color: "#ffffff"
                    font.pixelSize: 14
                }

                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 3
                    color: "#343a46"

                    Rectangle {
                        width: parent.width * root.usage / 100
                        height: parent.height
                        radius: parent.radius
                        color: "#ffffff"

                        Behavior on width {
                            NumberAnimation {
                                duration: 200
                            }
                        }
                    }
                }
            }
        }
    }

    function activate() {
        console.log("[CPU] activate")
    }

    function deactivate() {
        console.log("[CPU] deactivate")
    }

    Component.onCompleted: {
        console.log("[CPU] loaded")
    }
}