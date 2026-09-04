import QtQuick

FocusScope {
    anchors.fill: parent
    focus: true

    Text {
        anchors.centerIn: parent
        color: "white"
        font.pixelSize: Math.min(parent.width, parent.height) * 0.22
        text: Qt.formatTime(new Date(), "hh:mm")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: parent.forceActiveFocus()
    }
}
