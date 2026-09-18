import QtQuick
import QtQuick.Layouts
import qs.desktop.components

Widget {
    id: root

    widgetId: "color"

    implicitWidth: 240
    implicitHeight: 150

    draggable: true
    resizable: false
    canIntersect: true
    allowMultiple: true

    minimumWidth: 180
    minimumHeight: 110

    property int colorIndex:
        Number(
            configValue(
                "colorIndex",
                0
            )
        )

    readonly property var palette: [
        "#2acfff",
        "#a66cff",
        "#ff4f8b",
        "#7dffb2",
        "#ffd166"
    ]

    readonly property color currentColor:
        palette[
            Math.max(
                0,
                Math.min(
                    palette.length - 1,
                    colorIndex
                )
            )
        ]

    bgColor:
        Qt.rgba(
            currentColor.r,
            currentColor.g,
            currentColor.b,
            0.10
        )

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14

        spacing: 8

        Text {
            color: "#dffaff"

            text: "Color / Config"

            font.pixelSize: 16
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: 8

            color: root.currentColor

            opacity: 0.82
        }

        Text {
            color: "#7f919e"

            text:
                "index = " +
                root.colorIndex
        }
    }

    MouseArea {
        anchors.fill: parent

        acceptedButtons:
            Qt.LeftButton

        onClicked: function(mouse) {
            root.colorIndex =
                (
                    root.colorIndex + 1
                ) %
                root.palette.length

            root.config.colorIndex =
                root.colorIndex

            root.configurationChanged()
        }
    }
}
