import QtQuick

Item {
    id: root

    property date now: new Date()

    anchors.fill: parent

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(root.width, root.height)
        height: width
        radius: width / 2
        color: "red"
        border.width: 2
        border.color: "#2acfff"

        Text {
            anchors.centerIn: parent
            text: Qt.formatTime(root.now, "HH:mm")
            color: "white"
            font.pixelSize: 22
        }
    }
}