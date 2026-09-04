import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property var modules
    signal selected(string moduleId)

    implicitWidth: row.implicitWidth + 20
    implicitHeight: row.implicitHeight + 14

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "#e61b1b1b"
        border.width: 1
        border.color: "#3affffff"
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.modules

            delegate: Button {
                required property var modelData
                text: String(modelData.name || modelData.id)
                implicitHeight: 32
                padding: 12

                onClicked: root.selected(String(modelData.id))
            }
        }
    }
}
