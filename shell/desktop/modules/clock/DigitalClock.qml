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

    Text {
        anchors.centerIn: parent
        text: Qt.formatTime(root.now, "HH:mm:ss")
        font.pixelSize: 24
        color: "white"
    }
}