//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell

ShellRoot {
    Variants { model: Quickshell.screens; Wallpaper {} }
    Variants { model: Quickshell.screens; Island {} }
    Variants { model: Quickshell.screens; Dock {} }
    Central {}
    Launcher {}
    Overview {}
    Clipboard {}
    DockEditor {}
    Variants { model: Quickshell.screens; DisplayOverlay {} }
    Variants { model: Quickshell.screens; Sheet {} }
    Component.onCompleted: { Theme.accent; Notifs.all; Events.list; Sys.cpu; Osd.shown; Night.wanted } // Night applies itself once the profile loads
}
