import QtQuick
import QtQuick.Controls

FocusScope {
    anchors.fill: parent
    focus: true

    TextField {
        id: query
        anchors.centerIn: parent
        width: Math.min(parent.width - 30, 300)
        placeholderText: "Type to search..."
        focus: true
    }

    Keys.onEscapePressed: event => {
        event.accepted = true;
    }
}
