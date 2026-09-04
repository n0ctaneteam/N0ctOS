import QtQuick

Item {
    id: root

    // ============================================================
    // STYLE ENUM
    //
    // Values map 1:1 onto the _styles array (index = enum value).
    // Add a preset by appending an enum member + a table entry.
    // ============================================================

    enum Style {
        Default,
        CutGlow,
        Rounded,
        Outline,
        Flat
    }


    // ============================================================
    // PUBLIC API
    // ============================================================

    property string text: ""

    property var textColor
    property var fontPixelSize

    property int padding: 12

    /*
        Highlights the button with the style's "active" preset.
        Used by Tabs to mark the open tab.
    */
    property bool active: false

    property int style: Button.Style.Default


    /*
        The following properties are injected into the CutBox.

        undefined = "not set by the user", in which case the
        style preset is used instead.

        Resolution priority:
            1. explicit user value
            2. style "active" preset
            3. style base preset
            4. CutBox default
    */
    /*
        Optional complete button configuration object.
    
        Example:
    
            button: ({
                style: Button.Style.CutGlow,
                textColor: "#ffffff",
                fontPixelSize: 20,
                bgColor: "#101820"
            })
    
        Individual Button properties still have priority over
        values supplied through this object.
    */
    property var button: ({})

    property var cut
    property var round
    property var bgColor
    property var borderWidth
    property var borderColor
    property var borderGlow
    property var disableBorder
    property var shadow


    // ============================================================
    // SIGNAL API
    //
    // scroll / doubleClicked / rightClicked are intentionally
    // NOT forwarded from CutBox.
    // ============================================================

    signal clicked(var mouse)
    signal hovered()
    signal exited()
    signal pressed(var mouse)
    signal released(var mouse)


    // ============================================================
    // STYLE TABLE
    // ============================================================

    readonly property var _styles: [

        // --------------------------------------------------------
        // DEFAULT
        // --------------------------------------------------------

        {
            round: {
                topLeft: 10,
                topRight: 10,
                bottomLeft: 10,
                bottomRight: 10
            },

            bgColor: "#10151d",

            borderWidth: 1,
            borderColor: "#2a3342",
            borderGlow: 0,

            textColor: "#c6cfdd",

            active: {
                bgColor: "#16233a",
                borderColor: "#4aa8ff",
                borderGlow: 10,

                shadow: {
                    in: {
                        color: "#4aa8ff",
                        intensity: 10,
                        opacity: 0.3
                    }
                }
            }
        },


        // --------------------------------------------------------
        // CUT GLOW
        // --------------------------------------------------------

        {
            cut: {
                topLeft: 12,
                topRight: 12,
                bottomLeft: 12,
                bottomRight: 12
            },

            bgColor: "#081018",

            borderWidth: 2,
            borderColor: "#00eaff",
            borderGlow: 14,

            shadow: {
                out: {
                    color: "#00eaff",
                    intensity: 18,
                    opacity: 0.5
                },

                in: {
                    color: "#00eaff",
                    intensity: 12,
                    opacity: 0.5
                }
            },

            textColor: "#b8f4ff",

            active: {
                bgColor: "#0a1f2b",
                borderGlow: 20,

                shadow: {
                    in: {
                        color: "#00eaff",
                        intensity: 18,
                        opacity: 0.6
                    }
                }
            }
        },


        // --------------------------------------------------------
        // ROUNDED
        // --------------------------------------------------------

        {
            round: {
                topLeft: 22,
                topRight: 22,
                bottomLeft: 22,
                bottomRight: 22
            },

            bgColor: "#14101f",

            borderWidth: 1,
            borderColor: "#7c5cff",
            borderGlow: 8,

            shadow: {
                in: {
                    color: "#7c5cff",
                    intensity: 8,
                    opacity: 0.35
                }
            },

            textColor: "#e0d4ff",

            active: {
                bgColor: "#1f1633",
                borderColor: "#a585ff",
                borderGlow: 14
            }
        },


        // --------------------------------------------------------
        // OUTLINE
        // --------------------------------------------------------

        {
            round: {
                topLeft: 8,
                topRight: 8,
                bottomLeft: 8,
                bottomRight: 8
            },

            bgColor: "transparent",

            borderWidth: 2,
            borderColor: "#5a6b7c",
            borderGlow: 6,

            textColor: "#aeb8c8",

            active: {
                borderColor: "#00ff9c",
                borderGlow: 14,
                textColor: "#00ff9c"
            }
        },


        // --------------------------------------------------------
        // FLAT
        // --------------------------------------------------------

        {
            round: {
                topLeft: 6,
                topRight: 6,
                bottomLeft: 6,
                bottomRight: 6
            },

            bgColor: "#0c1118",

            borderWidth: 0,
            borderGlow: 0,

            textColor: "#8a94a6",

            active: {
                bgColor: "#1a2333",
                textColor: "#ffffff",

                shadow: {
                    in: {
                        color: "#3b82f6",
                        intensity: 10,
                        opacity: 0.4
                    }
                }
            }
        }
    ]


    readonly property var _cfg:
        _styles[root.style] !== undefined
            ? _styles[root.style]
            : _styles[0]


    // ============================================================
    // RESOLVERS
    // ============================================================

    function _from(key) {
    
        // ------------------------------------------------------------
        // 1. Explicit individual property
        // ------------------------------------------------------------
    
        if (root[key] !== undefined)
            return root[key]
    
    
        // ------------------------------------------------------------
        // 2. Complete button:{} configuration
        // ------------------------------------------------------------
    
        if (
            root.button &&
            root.button[key] !== undefined
        )
            return root.button[key]
    
    
        // ------------------------------------------------------------
        // 3. Active style preset
        // ------------------------------------------------------------
    
        if (
            root.active &&
            _cfg.active !== undefined &&
            _cfg.active[key] !== undefined
        )
            return _cfg.active[key]
    
    
        // ------------------------------------------------------------
        // 4. Base style preset
        // ------------------------------------------------------------
    
        if (_cfg[key] !== undefined)
            return _cfg[key]
    
    
        return undefined
    }


    readonly property var _resolvedCut: _from("cut")
    readonly property var _resolvedRound: _from("round")
    readonly property var _resolvedBg: _from("bgColor")
    readonly property var _resolvedBorderWidth: _from("borderWidth")
    readonly property var _resolvedBorderColor: _from("borderColor")
    readonly property var _resolvedBorderGlow: _from("borderGlow")
    readonly property var _resolvedDisableBorder: _from("disableBorder")
    readonly property var _resolvedShadow: _from("shadow")
    readonly property var _resolvedTextColor: _from("textColor")
    readonly property var _resolvedFontPixelSize: _from("fontPixelSize")


    // ============================================================
    // SIZING
    // ============================================================

    implicitWidth:
        label.implicitWidth +
        root.padding * 2

    implicitHeight:
        label.implicitHeight +
        root.padding * 2


    // ============================================================
    // SURFACE
    // ============================================================

    CutBox {
        id: cutbox

        anchors.fill: parent

        cut:
            root._resolvedCut ?? ({})

        round:
            root._resolvedRound ?? ({})

        bgColor:
            root._resolvedBg ?? "transparent"

        borderWidth:
            root._resolvedBorderWidth ?? 0

        borderColor:
            root._resolvedBorderColor ?? "transparent"

        borderGlow:
            root._resolvedBorderGlow ?? 0

        disableBorder:
            root._resolvedDisableBorder ?? ({})

        shadow:
            root._resolvedShadow ?? ({})


        // --------------------------------------------------------
        // SIGNAL FORWARDING
        // --------------------------------------------------------

        onClicked:
            root.clicked(mouse)

        onHovered:
            root.hovered()

        onExited:
            root.exited()

        onPressed:
            root.pressed(mouse)

        onReleased:
            root.released(mouse)
    }


    // ============================================================
    // LABEL
    // ============================================================

    Text {
        id: label

        anchors.centerIn: parent

        text: root.text

        color:
            root._resolvedTextColor ?? "#ffffff"

        font.pixelSize:
            root._resolvedFontPixelSize ?? 15

        font.bold: true

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
