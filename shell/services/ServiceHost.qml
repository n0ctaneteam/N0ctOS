import QtQuick
import Quickshell

QtObject {
    id: root

    /*
     * ============================================================
     * N0ctOS SERVICE HOST
     *
     * This object exists exactly once from the shell entry point.
     *
     * Services placed in eagerServices are deliberately touched
     * here so their singleton instances are created immediately.
     *
     * Services NOT listed here remain naturally lazy.
     * ============================================================
     */

     property list<QtObject> eagerServices: [
             ConfigStore,
             Config,
             DateTime,
             Screens,
             Clipboard,
             Power,
             Audio,
             Battery,
             Brightness,
             Network,
             Bluetooth,
             Media,
             Notifications,
             SystemTray,
             Animations
         ]

    Component.onCompleted: {
        console.info(
            "[N0ctOS Services] ServiceHost started"
        )

        console.info(
            "[N0ctOS Services] Eager services:",
            eagerServices.length
        ) 
    }
}