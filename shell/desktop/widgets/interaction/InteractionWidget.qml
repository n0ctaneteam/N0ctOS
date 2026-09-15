import QtQuick
import QtQuick.Layouts
import qs.desktop.components

Widget {
    id: root

    widgetId: "interaction"

    implicitWidth: 300
    implicitHeight: 170

    draggable: true
    resizable: true
    canIntersect: true
    allowMultiple: false

    minimumWidth: 220
    minimumHeight: 120

    property int clicks: 0
    property bool hoveredNow: false

    interaction: ({
        click: true,
        rightClick: true,
        hover: true,
        focus: true,
        passMouseEvents: false
    })

    bgColor: "#101820"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16

        spacing: 8

        Text {
            color: "#dffaff"

            text: "Interaction Test"

            font.pixelSize: 17
            font.bold: true
        }

        Text {
            color: "#7f919e"

            text:
                "clicks: " +
                root.clicks +
                "\nhover: " +
                root.hoveredNow +
                "\nfocus: " +
                root.activeFocus
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            radius: 7

            color:
                root.hoveredNow
                    ? "#17394a"
                    : "#121a22"

            border.width: 1
            border.color:
                root.hoveredNow
                    ? "#2acfff"
                    : "#29343d"

            Text {
                anchors.centerIn: parent

                color: "#dffaff"

                text: "Click me"
            }

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    root.clicks++
                }
            }
        }
    }

    onHovered:
        root.hoveredNow = true

    onExited:
        root.hoveredNow = false

    onClicked:
        root.clicks++
}
