import QtQuick
import QtQuick.Layouts
import qs.desktop.components

Widget {
    id: root

    widgetId: "variant-test"

    implicitWidth: 300
    implicitHeight: 170

    draggable: true
    resizable: true
    canIntersect: false
    allowMultiple: true

    minimumWidth: 180
    minimumHeight: 100

    maximumWidth: 700
    maximumHeight: 500

    defaultVariant: "full"

    variant:
        configValue(
            "variant",
            "full"
        )

    /*
     * Each presentation variant may have different
     * editing capabilities.
     */
    variantCapabilities: ({
        compact: {
            draggable: true,
            resizable: false,
            canIntersect: false,
            allowMultiple: true,

            interaction: ({
                click: true,
                rightClick: true,
                hover: true,
                focus: false,
                passMouseEvents: false
            })
        },

        full: {
            draggable: true,
            resizable: true,
            canIntersect: false,
            allowMultiple: true,

            interaction: ({
                click: true,
                rightClick: true,
                hover: true,
                focus: true,
                passMouseEvents: false
            })
        },

        floating: {
            draggable: true,
            resizable: true,
            canIntersect: true,
            allowMultiple: true,

            interaction: ({
                click: true,
                rightClick: true,
                hover: true,
                focus: true,
                passMouseEvents: false
            })
        }
    })

    variantComponents: ({
        compact: compactVariant,
        full: fullVariant,
        floating: floatingVariant
    })

    borderWidth:
        root.selected
            ? 1
            : 0

    bgColor: "#0d141c"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14

        spacing: 8

        Text {
            Layout.fillWidth: true

            color: "#d9f8ff"

            font.pixelSize: 17
            font.bold: true

            text: "Variant Widget"
        }

        Text {
            Layout.fillWidth: true

            color: "#7f919e"

            font.pixelSize: 12

            text:
                "Variant: " +
                root.effectiveVariant
        }

        Text {
            Layout.fillWidth: true

            color: "#8ea1ad"

            wrapMode: Text.WordWrap

            text:
                "drag=" +
                root.effectiveDraggable +
                "  resize=" +
                root.effectiveResizable +
                "  intersect=" +
                root.effectiveCanIntersect
        }

        RowLayout {
            Layout.fillWidth: true

            spacing: 6

            Repeater {
                model: [
                    "compact",
                    "full",
                    "floating"
                ]

                delegate: Rectangle {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    radius: 5

                    color:
                        root.effectiveVariant ===
                        modelData
                            ? "#17394a"
                            : "#121a22"

                    border.width: 1

                    border.color:
                        root.effectiveVariant ===
                        modelData
                            ? "#2acfff"
                            : "#29343d"

                    Text {
                        anchors.centerIn: parent

                        color: "#dffaff"

                        text:
                            parent.modelData

                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked:
                            root.setVariant(
                                parent.modelData
                            )
                    }
                }
            }
        }
    }

    Component {
        id: compactVariant

        Rectangle {
            color: "transparent"

            Text {
                anchors.centerIn: parent

                color: "#7f919e"

                text: "COMPACT"
            }
        }
    }

    Component {
        id: fullVariant

        Item {
            Text {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }

                color: "#2acfff"

                text: "FULL"
            }
        }
    }

    Component {
        id: floatingVariant

        Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: 8

                radius: 8

                color:
                    Qt.rgba(
                        0.17,
                        0.8,
                        1.0,
                        0.06
                    )

                border.width: 1
                border.color: "#2acfff"
            }

            Text {
                anchors.centerIn: parent

                color: "#dffaff"

                text: "FLOATING / INTERSECTABLE"
            }
        }
    }
}