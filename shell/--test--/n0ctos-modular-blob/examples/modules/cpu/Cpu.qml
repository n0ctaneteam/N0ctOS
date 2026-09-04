import QtQuick
import QtQuick.Controls

FocusScope {
    anchors.fill: parent
    focus: true

    Column {
        anchors.centerIn: parent
        spacing: 4

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CPU"
            color: "white"
            font.pixelSize: 22
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Demo module"
            color: "#99ffffff"
        }
    }
}
