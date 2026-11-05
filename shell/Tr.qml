pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Translations. English is the source language: its strings are the keys, so a missing translation shows English.
Singleton {
    id: tr
    readonly property var languages: [
        { code: "en", name: "English" },
        { code: "pt-BR", name: "Português (Brasil)" },
        { code: "es", name: "Español" },
        { code: "fr", name: "Français" },
        { code: "de", name: "Deutsch" },
        { code: "ru", name: "Русский" },
        { code: "zh-CN", name: "简体中文" }
    ]
    // "auto" follows the system language, falling back to English.
    readonly property string code: {
        const chosen = Cfg.v.language
        if (chosen && chosen !== "auto") return chosen
        const system = Qt.locale().name.split("_")[0]
        return languages.find(l => l.code.split("-")[0] === system)?.code ?? "en"
    }
    readonly property var locale: Qt.locale(code.replace("-", "_"))
    property var dict: ({})

    function t(text) { return dict[text] ?? text }
    function date(when, format) { return locale.toString(when, t(format)) }

    onCodeChanged: if (code === "en") dict = {}
    FileView {
        path: tr.code === "en" ? "" : Quickshell.shellPath("i18n/" + tr.code + ".json")
        blockLoading: true
        onLoaded: tr.dict = JSON.parse(text())
    }
}
