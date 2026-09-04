import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

Module {
    id: root

    moduleId: "launcher"
    implicitWidth: 620
    implicitHeight: 430
    focusTarget: searchField

    property int selectedIndex: 0
    property string query: ""
    property string category: "All"

    ListModel {
        id: apps
        ListElement { name: "Firefox"; icon: "󰈹"; category: "Internet"; description: "Web browser" }
        ListElement { name: "VS Code"; icon: "󰨞"; category: "Development"; description: "Code editor" }
        ListElement { name: "Kitty"; icon: "󰄛"; category: "Terminal"; description: "GPU accelerated terminal" }
        ListElement { name: "Dolphin"; icon: "󰉋"; category: "Files"; description: "File manager" }
        ListElement { name: "Spotify"; icon: "󰓇"; category: "Media"; description: "Music player" }
        ListElement { name: "Steam"; icon: "󰓓"; category: "Games"; description: "Game launcher" }
        ListElement { name: "Discord"; icon: "󰙯"; category: "Internet"; description: "Chat application" }
        ListElement { name: "Neovim"; icon: ""; category: "Development"; description: "Terminal editor" }
    }

    function visibleApps() {
        const out = []
        const q = root.query.toLowerCase().trim()

        for (let i = 0; i < apps.count; ++i) {
            const a = apps.get(i)
            if (root.category !== "All" && a.category !== root.category) continue
            if (q && !a.name.toLowerCase().includes(q) && !a.description.toLowerCase().includes(q)) continue
            out.push(i)
        }

        return out
    }

    function resetSelection() {
        const list = root.visibleApps()
        root.selectedIndex = list.length ? list[0] : -1
    }

    function moveSelection(delta) {
        const list = root.visibleApps()
        if (!list.length) return

        let p = list.indexOf(root.selectedIndex)
        if (p < 0) p = 0

        p = (p + delta + list.length) % list.length
        root.selectedIndex = list[p]
        appList.positionViewAtIndex(p, ListView.Contain)
    }

    function launchSelected() {
        if (root.selectedIndex < 0 || root.selectedIndex >= apps.count) return
        console.log("[Launcher] launch:", apps.get(root.selectedIndex).name)
    }

    onQueryChanged: root.resetSelection()
    onCategoryChanged: root.resetSelection()

    onActivated: console.log("[Launcher] activated")
    onDeactivated: console.log("[Launcher] deactivated")

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "#10161d"
        border.width: 1
        border.color: "#26323c"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 10
                color: "#18232c"

                Text {
                    anchors.centerIn: parent
                    text: "󰀻"
                    color: "#2acfff"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "LAUNCHER"
                    color: "#f4f7f9"
                    font.pixelSize: 17
                    font.bold: true
                }

                Text {
                    text: "Applications & commands"
                    color: "#63717d"
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 24
                radius: 7
                color: "#151d24"

                Text {
                    anchors.centerIn: parent
                    text: "ESC"
                    color: "#63717d"
                    font.pixelSize: 9
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 11
            color: searchField.activeFocus ? "#182730" : "#141b22"
            border.width: searchField.activeFocus ? 1 : 0
            border.color: "#2acfff"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 9

                Text {
                    text: "󰍉"
                    color: searchField.activeFocus ? "#2acfff" : "#687681"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 18
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    background: null
                    color: "#e9eef1"
                    placeholderText: "Search applications..."
                    placeholderTextColor: "#56646f"
                    font.pixelSize: 13
                    activeFocusOnTab: true

                    onTextChanged: root.query = text

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down) {
                            event.accepted = true
                            root.moveSelection(1)
                        } else if (event.key === Qt.Key_Up) {
                            event.accepted = true
                            root.moveSelection(-1)
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true
                            root.launchSelected()
                        }
                    }
                }

                Text {
                    text: "⌘"
                    color: "#45515b"
                    font.pixelSize: 12
                }
            }
        }

        Row {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: ["All", "Internet", "Development", "Media", "Games"]

                delegate: Button {
                    required property string modelData

                    text: modelData
                    activeFocusOnTab: true
                    flat: true

                    implicitWidth: contentItem.implicitWidth + 20
                    implicitHeight: 28

                    background: Rectangle {
                        radius: 8
                        color: root.category === modelData ? "#1c3039" : "#141b22"
                        border.width: root.category === modelData ? 1 : 0
                        border.color: "#2acfff"
                    }

                    contentItem: Text {
                        text: parent.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: root.category === modelData ? "#2acfff" : "#73818c"
                        font.pixelSize: 10
                    }

                    onClicked: root.category = modelData
                }
            }
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: root.visibleApps()
            activeFocusOnTab: true

            delegate: Rectangle {
                required property int modelData

                width: appList.width
                height: 52
                radius: 10
                color: root.selectedIndex === modelData ? "#1a2c35" : "#131a20"
                border.width: root.selectedIndex === modelData ? 1 : 0
                border.color: "#2acfff"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 9
                        color: "#1b252d"

                        Text {
                            anchors.centerIn: parent
                            text: apps.get(modelData).icon
                            color: "#d7e2e8"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 17
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: apps.get(modelData).name
                            color: "#e8edf0"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            text: apps.get(modelData).description
                            color: "#63717b"
                            font.pixelSize: 9
                        }
                    }

                    Text {
                        text: apps.get(modelData).category
                        color: "#45525c"
                        font.pixelSize: 9
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedIndex = modelData
                        root.launchSelected()
                    }
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Down) {
                    event.accepted = true
                    root.moveSelection(1)
                } else if (event.key === Qt.Key_Up) {
                    event.accepted = true
                    root.moveSelection(-1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true
                    root.launchSelected()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text { text: "↑↓"; color: "#2acfff"; font.pixelSize: 10 }
            Text { text: "Navigate"; color: "#596772"; font.pixelSize: 9 }
            Text { text: "Tab"; color: "#2acfff"; font.pixelSize: 10 }
            Text { text: "Focus"; color: "#596772"; font.pixelSize: 9 }

            Item { Layout.fillWidth: true }

            Text {
                text: root.visibleApps().length + " apps"
                color: "#45525c"
                font.pixelSize: 9
            }
        }
    }
}