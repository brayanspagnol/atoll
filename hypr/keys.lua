-- Atoll's default shortcuts, as data: binds.lua binds them and the shortcut editor reads them.
-- One per line, S("id", "KEYS", "group", "Label", dispatcher). The editor reads only the four strings,
-- so keep each call on one line with literal strings. %1 in a label is the number that ends the id.
-- Groups: atoll, windows, workspaces, apps, shots. This file returns the list and binds nothing.
local scripts = "$HOME/.local/share/atoll/scripts/"
local qs = "qs -c atoll ipc call "
local lock = "pidof hyprlock || hyprlock -c $HOME/.config/atoll/hyprlock.conf"
local terminal = "kitty"
local browser = "xdg-open https://"
local fileManager = "xdg-open ~"
local shot = scripts .. "screenshot"
local exec, focus, move = hl.dsp.exec_cmd, hl.dsp.focus, hl.dsp.window.move
local function screen(page) return exec(qs .. "ui toggle " .. page) end

local list = {}
local function S(id, keys, group, label, act) list[#list + 1] = { id = id, keys = keys, group = group, label = label, act = act } end

S("terminal", "SUPER + Return", "apps", "Terminal", exec(terminal))
S("terminal-q", "SUPER + Q", "apps", "Terminal", exec(terminal))
S("files", "SUPER + E", "apps", "Files", exec(fileManager))
S("browser", "SUPER + B", "apps", "Browser", exec(browser))

S("launcher", "SUPER + R", "atoll", "Launcher", exec(qs .. "ui launcher"))
S("sound-n", "SUPER + N", "atoll", "Sound", screen("som"))
S("sound-w", "SUPER + W", "atoll", "Sound", screen("som"))
S("settings-d", "SUPER + D", "atoll", "Settings", screen("ajustes"))
S("power-e", "SUPER + SHIFT + E", "atoll", "Power", screen("energia"))
S("dock", "SUPER + Z", "atoll", "Dock", exec(qs .. "ui dock"))
S("page-som", "SUPER + ALT + A", "atoll", "Sound", screen("som"))
S("page-rede", "SUPER + ALT + I", "atoll", "Network", screen("rede"))
S("page-bt", "SUPER + ALT + B", "atoll", "Bluetooth", screen("bt"))
S("page-perf", "SUPER + ALT + D", "atoll", "Performance", screen("perf"))
S("page-cal", "SUPER + ALT + C", "atoll", "Calendar", screen("cal"))
S("page-avisos", "SUPER + ALT + V", "atoll", "Notifications", screen("avisos"))
S("page-ajustes", "SUPER + ALT + J", "atoll", "Settings", screen("ajustes"))
S("page-energia", "SUPER + ALT + E", "atoll", "Power", screen("energia"))
S("page-monitor", "SUPER + ALT + M", "atoll", "Screens", screen("monitor"))
S("page-sobre", "SUPER + ALT + O", "atoll", "About", screen("sobre"))
S("page-atalhos", "SUPER + ALT + K", "atoll", "Shortcuts", screen("atalhos"))
S("page-apps", "SUPER + ALT + N", "atoll", "Default apps", screen("apps"))
S("page-regras", "SUPER + ALT + R", "atoll", "Window rules", screen("regras"))
S("page-backup", "SUPER + ALT + U", "atoll", "Backup", screen("backup"))
S("restart", "SUPER + SHIFT + R", "atoll", "Restart Atoll", exec("pkill -x qs"))
S("lock", "SUPER + L", "atoll", "Lock screen", exec(lock))
S("layout", "SUPER + SPACE", "atoll", "Keyboard layout", exec(scripts .. "kb-layout"))
S("clipboard", "SUPER + SHIFT + V", "atoll", "Clipboard history", exec(qs .. "ui clipboard"))
S("emoji", "SUPER + period", "atoll", "Emoji", exec(qs .. "ui emoji"))
S("overview", "SUPER + O", "atoll", "Overview", exec(qs .. "ui overview"))

S("close", "SUPER + C", "windows", "Close window", hl.dsp.window.close())
S("minimize", "SUPER + M", "windows", "Minimize", move({ workspace = "special:minimized" }))
S("minimized", "SUPER + SHIFT + M", "windows", "Minimized windows", hl.dsp.workspace.toggle_special("minimized"))
S("float", "SUPER + V", "windows", "Float", hl.dsp.window.float({ action = "toggle" }))
S("split", "SUPER + T", "windows", "Toggle split", hl.dsp.layout("togglesplit"))
S("pseudo", "SUPER + ALT + P", "windows", "Pseudotile", hl.dsp.window.pseudo())
S("fullscreen", "SUPER + F", "windows", "Fullscreen", hl.dsp.window.fullscreen({}))
S("group", "SUPER + G", "windows", "Group", hl.dsp.group.toggle())
S("focus-h", "SUPER + H", "windows", "Focus left", focus({ direction = "left" }))
S("focus-j", "SUPER + J", "windows", "Focus down", focus({ direction = "down" }))
S("next", "SUPER + TAB", "windows", "Next window", hl.dsp.window.cycle_next())
S("previous", "SUPER + SHIFT + TAB", "windows", "Previous window", hl.dsp.window.cycle_next({ next = false }))
S("focus-left", "SUPER + left", "windows", "Focus left", focus({ direction = "l" }))
S("focus-right", "SUPER + right", "windows", "Focus right", focus({ direction = "r" }))
S("focus-up", "SUPER + up", "windows", "Focus up", focus({ direction = "u" }))
S("focus-down", "SUPER + down", "windows", "Focus down", focus({ direction = "d" }))
S("move-left", "SUPER + SHIFT + left", "windows", "Move left", move({ direction = "left" }))
S("move-right", "SUPER + SHIFT + right", "windows", "Move right", move({ direction = "right" }))
S("move-up", "SUPER + SHIFT + up", "windows", "Move up", move({ direction = "up" }))
S("move-down", "SUPER + SHIFT + down", "windows", "Move down", move({ direction = "down" }))
S("center", "SUPER + SHIFT + C", "windows", "Center", hl.dsp.window.center())

S("scratchpad", "SUPER + S", "workspaces", "Scratchpad", hl.dsp.workspace.toggle_special("magic"))
S("to-scratchpad", "SUPER + ALT + S", "workspaces", "Move to scratchpad", move({ workspace = "special:magic" }))
S("empty", "SUPER + CTRL + down", "workspaces", "Empty workspace", focus({ workspace = "empty" }))
S("ws1", "SUPER + 1", "workspaces", "Workspace %1", focus({ workspace = 1 }))
S("ws2", "SUPER + 2", "workspaces", "Workspace %1", focus({ workspace = 2 }))
S("ws3", "SUPER + 3", "workspaces", "Workspace %1", focus({ workspace = 3 }))
S("ws4", "SUPER + 4", "workspaces", "Workspace %1", focus({ workspace = 4 }))
S("ws5", "SUPER + 5", "workspaces", "Workspace %1", focus({ workspace = 5 }))
S("ws6", "SUPER + 6", "workspaces", "Workspace %1", focus({ workspace = 6 }))
S("ws7", "SUPER + 7", "workspaces", "Workspace %1", focus({ workspace = 7 }))
S("ws8", "SUPER + 8", "workspaces", "Workspace %1", focus({ workspace = 8 }))
S("ws9", "SUPER + 9", "workspaces", "Workspace %1", focus({ workspace = 9 }))
S("ws10", "SUPER + 0", "workspaces", "Workspace %1", focus({ workspace = 10 }))
S("move1", "SUPER + SHIFT + 1", "workspaces", "Move to %1", move({ workspace = 1, follow = true }))
S("move2", "SUPER + SHIFT + 2", "workspaces", "Move to %1", move({ workspace = 2, follow = true }))
S("move3", "SUPER + SHIFT + 3", "workspaces", "Move to %1", move({ workspace = 3, follow = true }))
S("move4", "SUPER + SHIFT + 4", "workspaces", "Move to %1", move({ workspace = 4, follow = true }))
S("move5", "SUPER + SHIFT + 5", "workspaces", "Move to %1", move({ workspace = 5, follow = true }))
S("move6", "SUPER + SHIFT + 6", "workspaces", "Move to %1", move({ workspace = 6, follow = true }))
S("move7", "SUPER + SHIFT + 7", "workspaces", "Move to %1", move({ workspace = 7, follow = true }))
S("move8", "SUPER + SHIFT + 8", "workspaces", "Move to %1", move({ workspace = 8, follow = true }))
S("move9", "SUPER + SHIFT + 9", "workspaces", "Move to %1", move({ workspace = 9, follow = true }))
S("move10", "SUPER + SHIFT + 0", "workspaces", "Move to %1", move({ workspace = 10, follow = true }))
S("send1", "SUPER + CTRL + 1", "workspaces", "Send to %1", move({ workspace = 1, follow = false }))
S("send2", "SUPER + CTRL + 2", "workspaces", "Send to %1", move({ workspace = 2, follow = false }))
S("send3", "SUPER + CTRL + 3", "workspaces", "Send to %1", move({ workspace = 3, follow = false }))
S("send4", "SUPER + CTRL + 4", "workspaces", "Send to %1", move({ workspace = 4, follow = false }))
S("send5", "SUPER + CTRL + 5", "workspaces", "Send to %1", move({ workspace = 5, follow = false }))
S("send6", "SUPER + CTRL + 6", "workspaces", "Send to %1", move({ workspace = 6, follow = false }))
S("send7", "SUPER + CTRL + 7", "workspaces", "Send to %1", move({ workspace = 7, follow = false }))
S("send8", "SUPER + CTRL + 8", "workspaces", "Send to %1", move({ workspace = 8, follow = false }))
S("send9", "SUPER + CTRL + 9", "workspaces", "Send to %1", move({ workspace = 9, follow = false }))
S("send10", "SUPER + CTRL + 0", "workspaces", "Send to %1", move({ workspace = 10, follow = false }))

S("shot-print", "PRINT", "shots", "Area to file", exec(shot .. " region-file"))
S("shot-print-full", "SHIFT + PRINT", "shots", "Screen to file", exec(shot .. " full-file"))
S("shot-area", "SUPER + SHIFT + A", "shots", "Area to file", exec(shot .. " region-file"))
S("shot-clip", "SUPER + SHIFT + P", "shots", "Area to clipboard", exec(shot .. " region-clip"))
S("shot-full", "SUPER + SHIFT + W", "shots", "Screen to file", exec(shot .. " full-file"))

return list
