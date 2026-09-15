import QtQuick

import qs.desktop.components

Widget {
    id: root

    /*
     * This is only a reference widget for testing the complete
     * WidgetLayer -> Registry -> Loader pipeline.
     */

    widgetId: "debug"
    canIntersect: true
    allowMultiple: true
    resizable: true

    bgColor: "#16111f"

    round: ({
        topLeft: 10,
        topRight: 10,
        bottomLeft: 10,
        bottomRight: 10
    })

    borderWidth: 1
    borderColor: "#8c4dff"

    default property alias contentData:
        content.data

    Item {
        id: content

        anchors.fill: parent

        Text {
            anchors.centerIn: parent

            text:
                "N0ctOS Widget\n" +
                root.instanceId

            color: "#e9ddff"

            font.family:
                "monospace"

            font.pixelSize: 14

            horizontalAlignment:
                Text.AlignHCenter
        }
    }
}