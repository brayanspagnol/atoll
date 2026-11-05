-- Monitors at their preferred mode, unless the Monitor screen saved a layout.
-- The saved file holds { lid, monitors, workspaces }. For anything else, use ~/.config/atoll/user.lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local path = os.getenv("HOME") .. "/.config/atoll/monitors.lua"

local function saved()
    local file = io.open(path, "r")
    if not file then
        return {}
    end
    file:close()
    local ok, data = pcall(dofile, path)
    return ok and type(data) == "table" and data or {}
end

local layout = saved()
for _, rule in ipairs(layout.monitors or {}) do
    hl.monitor(rule)
end
for workspace, monitor in pairs(layout.workspaces or {}) do
    hl.workspace_rule({ workspace = workspace, monitor = monitor })
end

local function is_laptop(name)
    return name:find("^eDP") or name:find("^LVDS") or name:find("^DSI")
end

local function lid_closed()
    local pipe = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
    if not pipe then
        return false
    end
    local state = pipe:read("a") or ""
    pipe:close()
    return state:find("closed", 1, true) ~= nil
end

local function screens()
    local laptop, external
    for _, mon in ipairs(hl.get_monitors()) do
        if is_laptop(mon.name) then
            laptop = mon
        elseif not mon.disabled then
            external = external or mon
        end
    end
    return laptop, external
end

-- A far away position, with no shared edge: the pointer cannot walk onto a closed lid, and disabling
-- the panel would modeset and blank the external monitor on some hardware.
local parked_at = -2000

local function sync()
    local laptop, external = screens()
    if not laptop then
        return
    end
    local wants_parked = external and lid_closed() and (saved().lid or "off") == "off"
    if wants_parked and not laptop.disabled and laptop.y ~= parked_at then
        hl.monitor({ output = laptop.name, position = "0x" .. parked_at })
        pcall(function()
            hl.dispatch(hl.dsp.focus({ monitor = external.name }))
        end)
    elseif not wants_parked and laptop.y == parked_at then
        for _, rule in ipairs(saved().monitors or {}) do
            if rule.output == laptop.name then
                hl.monitor(rule)
                return
            end
        end
        hl.monitor({ output = laptop.name, mode = "preferred", position = "auto", scale = 1 })
    end
    -- Never leave the machine without a lit screen.
    if not external and laptop.disabled then
        hl.monitor({ output = laptop.name, disabled = false, mode = "preferred", position = "auto", scale = 1 })
    end
end
atoll_sync_monitors = sync

-- Lid switches can bounce, so act on where the lid ended up, after a moment.
local generation = 0
local function later(delay, action)
    generation = generation + 1
    local mine = generation
    hl.timer(function()
        if mine == generation then
            action()
        end
    end, { timeout = delay, type = "oneshot" })
end

hl.bind("switch:Lid Switch", function()
    later(2000, function()
        local _, external = screens()
        if external and lid_closed() and saved().lid == "suspend" then
            hl.exec_cmd("systemctl suspend")
        else
            sync()
        end
    end)
end, { locked = true })

hl.on("monitor.removed", function()
    later(5000, sync)
end)
hl.on("config.reloaded", sync)
-- External monitors can appear a moment after the panel at startup.
hl.on("hyprland.start", function()
    later(3000, sync)
end)
