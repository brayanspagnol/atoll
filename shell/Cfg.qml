pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property alias v: adapter
    FileView {
        path: Quickshell.env("HOME") + "/.config/atoll/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: adapter
            property string accent: "gelo"
            property string wallpaper: Quickshell.env("HOME") + "/.local/share/atoll/wallpapers/atoll-dusk.jpg"
            property bool dnd: false
            property bool holidays: true // Brazilian national holidays in the calendar
            // Pinned apps. ids are lowercase Wayland app ids; icon is a key from Icons.qml.
            property var dock: [
                { label: "Terminal", icon: "term", ids: ["kitty"], cmd: "kitty" },
                { label: "Navegador", icon: "globe", ids: ["firefox", "brave-browser", "chromium", "google-chrome"], cmd: "xdg-open https://" },
                { label: "Código", icon: "code", ids: ["code", "code-oss"], cmd: "code" },
                { label: "Arquivos", icon: "folder", ids: ["org.gnome.nautilus", "thunar", "org.kde.dolphin"], cmd: "xdg-open ~" },
                { label: "Discord", icon: "chat", ids: ["discord", "vesktop"], cmd: "discord || vesktop" },
                { label: "Spotify", icon: "music", ids: ["spotify", "spotify-qt"], cmd: "spotify || spotify-qt" }
            ]
            property bool nightOn: false
            property int nightK: 4500
            // Minutes; 0 = never.
            property int lockAc: 5
            property int dpmsAc: 6
            property int sleepAc: 0
            property int lockBat: 1
            property int dpmsBat: 2
            property int sleepBat: 3
        }
    }
}
