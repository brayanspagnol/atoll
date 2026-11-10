.pragma library

// The two token sets Theme.qml switches between. Colors are "#RRGGBB" or "#AARRGGBB", as QML reads them.
// Both must have the same keys; tests/test.mjs checks that and the text contrast on the glass.
var dark = {
    accentInk: "#08131D",
    ground: "#0D151F",
    surface: "#990C121A",     // the glass: rgba(12, 18, 26, 0.6)
    glassStrong: "#F00C121A", // popovers, tooltips, bars over content: 0.94
    scrim: "#8F080E16",       // dims what is behind a full-screen view: rgba(8, 14, 22, 0.56)
    raised: "#1FFFFFFF",
    raisedHover: "#29FFFFFF",
    hover: "#14FFFFFF",
    line: "#29FFFFFF",
    lineStrong: "#42FFFFFF",
    sheen: "#1AFFFFFF",
    field: "#38000000",
    ink: "#F3F7FB",
    muted: "#D5DDE6",
    danger: "#FF9A8F",
    holiday: "#FFB4A8",
    good: "#8FD9B6",
    warn: "#E9C46A",
    inactiveBorder: "ffffff24", // Hyprland rgba(), no #
    accents: { gelo: "#8CC8F5", areia: "#E8CFA6", hortela: "#8FD9B6", coral: "#FF9F87" }
}

// "Gelo fosco": cool frosted white. Accents are darker so they read on the white glass, with white text on them.
var light = {
    accentInk: "#FFFFFF",
    ground: "#DCE4EC",
    surface: "#D6F4F7FA",     // rgba(244, 247, 250, 0.84)
    glassStrong: "#F5F6F8FB",
    scrim: "#99ECF2F8",       // lifts what is behind instead of dimming it
    raised: "#8CFFFFFF",
    raisedHover: "#CCFFFFFF",
    hover: "#B8FFFFFF",
    line: "#1F0E1A26",
    lineStrong: "#2E0E1A26",
    sheen: "#59FFFFFF",
    field: "#0F0E1A26",
    ink: "#0E1A26",
    muted: "#3D4A58",
    danger: "#9E2018",
    holiday: "#962A22",
    good: "#13603F",
    warn: "#6E4E12",
    inactiveBorder: "0e1a2630",
    accents: { gelo: "#1D6BAE", areia: "#85601F", hortela: "#1C7552", coral: "#B9432C" }
}
