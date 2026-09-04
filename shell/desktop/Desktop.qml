import QtQuick
import Quickshell
import Quickshell.Wayland

import "components"
import "lib"
 
Scope {
    id: root
    // ============================================================
    // SCREEN FRAME
    // ============================================================
// 
    ScreenFrame {
        id: frame
// 
        frameLayer:
            WlrLayer.Top
// 
        frameWidth:
            5
// 
        frameColor:
            "#01080c"
// 
        borderWidth:
            2
// 
        borderColor:
            "#2acfff"
// 
        blobAnimationDuration:
            200
// 
        cut:
            30
// 
        shadows: ({
            intensity: 30,
            color: "#2acfff",
            blur: 1.0,
            opacity: 1
        })
    }
}