import QtQuick
import Quickshell

PanelWindow {
    id: bottomCenterPanel

    // 1. Wayland Layer Shell positioning:
    // Attaching ONLY to the bottom naturally centers the window on the X axis.
    anchors {
        bottom: true
        left: false   // Omitted by default, but explicitly false for clarity
        right: false
        top: false
    }

    // 2. Add some spacing from the screen edge so it "floats"
    margins {
        bottom: 16
    }
    
    // (Optional) Reserve space so maximized windows don't overlap it.
    // exclusiveZone: height + margins.bottom 

    // 3. Define the actual size of the panel window
    width: 400
    height: 60

    // 4. The visual container for your panel
    Rectangle {
        anchors.fill: parent
        color: "#282a36" // Dark background
        radius: 20       // Rounded corners
        
        border.color: "#bd93f9"
        border.width: 2

        // 5. Your panel's inner content
        Row {
            anchors.centerIn: parent
            spacing: 32

            Text { 
                text: "Dashboard"
                color: "#f8f8f2"
                font.pixelSize: 16
                font.bold: true
            }
            
            Text { 
                text: "Launchpad"
                color: "#f8f8f2"
                font.pixelSize: 16
                font.bold: true
            }
            
            Text { 
                text: "Settings"
                color: "#f8f8f2"
                font.pixelSize: 16
                font.bold: true
            }
        }
    }
}