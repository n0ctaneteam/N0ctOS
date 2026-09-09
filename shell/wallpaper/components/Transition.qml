import QtQuick

Item {
    id: root

    property Item from: null
    property Item to: null

    property Item fromViewport: null
    property Item toViewport: null

    property ShaderEffectSource fromSource: null
    property ShaderEffectSource toSource: null

    property real progress: 0
    property int duration: 500
    property var parameters: ({})
    property string type: "qml"
    property bool initialized: false

    signal finished()

    function parameter(name, fallback) {
        if (parameters &&
            parameters[name] !== undefined)
            return parameters[name]

        return fallback
    }

    function initialize() {}
    function start() {}
    function finish() {}
    function cancel() {}
}