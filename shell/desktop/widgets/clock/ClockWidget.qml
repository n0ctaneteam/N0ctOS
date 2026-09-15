import QtQuick
import QtQuick.Layouts
import qs.desktop.components

Widget {
    id: root

    widgetId: "clock"

    implicitWidth: 260
    implicitHeight: 110

    draggable: true
    resizable: true
    canIntersect: false
    allowMultiple: true

    minimumWidth: 180
    minimumHeight: 80

    maximumWidth: 500
    maximumHeight: 240

    defaultVariant: "large"

    variant:
        configValue(
            "variant",
            "large"
        )

    variantCapabilities: ({
        large: {
            draggable: true,
            resizable: true,
            canIntersect: false
        },

        minimal: {
            draggable: true,
            resizable: false,
            canIntersect: false
        }
    })

    variantComponents: ({
        large: largeVariant,
        minimal: minimalVariant
    })

    property string timeText: ""
    property string dateText: ""

    function updateClock() {
        const now = new Date()

        timeText =
            Qt.formatTime(
                now,
                "hh:mm:ss"
            )

        dateText =
            Qt.formatDate(
                now,
                "ddd • dd MMM yyyy"
            )
    }

    Timer {
        interval: 1000
        repeat: true
        running: true

        onTriggered:
            root.updateClock()
    }

    Component.onCompleted:
        root.updateClock()

    Component {
        id: largeVariant

        ColumnLayout {
            anchors.centerIn: parent

            spacing: 2

            Text {
                color: "#dffaff"

                font.pixelSize: 38
                font.bold: true

                text: root.timeText
            }

            Text {
                color: "#7f919e"

                font.pixelSize: 12

                text: root.dateText
            }
        }
    }

    Component {
        id: minimalVariant

        Text {
            anchors.centerIn: parent

            color: "#dffaff"

            font.pixelSize: 30
            font.bold: true

            text:
                Qt.formatTime(
                    new Date(),
                    "hh:mm"
                )
        }
    }
}
