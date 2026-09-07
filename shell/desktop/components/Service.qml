import QtQuick

QtObject {
    id: root

    required property string moduleId
    required property var moduleInfo
    required property var serviceManager

    function start() {
        console.log("[Service]", moduleId, "started")
    }

    function stop() {
        console.log("[Service]", moduleId, "stopped")
    }
}