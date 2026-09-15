import QtQuick
import QtQuick.Layouts
import qs.desktop.components

Widget {
    id: root

    widgetId: "meter"

    implicitWidth: 280
    implicitHeight: 130

    draggable: true
    resizable: true
    canIntersect: false
    allowMultiple: true

    minimumWidth: 200
    minimumHeight: 100

    maximumWidth: 520
    maximumHeight: 260

    property real value: 0.64

    Timer {
        interval: 80
        repeat: true
        running: true

        onTriggered: {
            root.value =
                0.55 +
                (
                    Math.sin(
                        Date.now() / 900
                    ) + 1
                ) * 0.22
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16

        spacing: 10

        Text {
            Layout.fillWidth: true

            color: "#dffaff"

            text: "System Meter"

            font.pixelSize: 16
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            radius: 9

            color: "#111b23"

            border.width: 1
            border.color: "#29343d"

            Rectangle {
                width:
                    parent.width *
                    root.value

                height: parent.height

                radius: parent.radius

                color: "#2acfff"
            }
        }

        Text {
            color: "#7f919e"

            text:
                Math.round(
                    root.value * 100
                ) + "% simulated load"
        }
    }
}
