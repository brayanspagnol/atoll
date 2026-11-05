-- Keyboard and pointer settings saved by the Settings screen.
local path = os.getenv("HOME") .. "/.config/atoll/input.lua"
local file = io.open(path, "r")
if file then
    file:close()
    local ok, data = pcall(dofile, path)
    if ok and type(data) == "table" then
        hl.config({ input = data })
    end
end
