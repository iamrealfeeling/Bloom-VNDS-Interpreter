-- ============================================================================
--  vnds/save.lua
--  Save / load system for VNDS.
--
--  We store saves as plain files under  <novel>/saves/slotN.vnds  so there is
--  no 512-byte limit (the PSP System.SaveData dialog caps data at 512 bytes).
--  Each save also captures a screenshot (SAVE.PNG-style) for the XMB-style
--  save list.
-- ============================================================================

local save = {}

local SAVE_VERSION = 1

-------------------------------------------------------------------------------
-- Compact serializer for the variable table + interpreter state.
-- Produces a small, line-oriented text format that is easy to parse back.
-------------------------------------------------------------------------------
local function serialize(state)
    local out = {}
    out[#out + 1] = "VNDS" .. SAVE_VERSION
    out[#out + 1] = "file=" .. (state.curFile or "")
    out[#out + 1] = "pc=" .. (state.pc or 1)
    out[#out + 1] = "bg=" .. (state.bgName or "")
    out[#out + 1] = "text=" .. (state.text or ""):gsub("\n", "\\n")
    out[#out + 1] = "music=" .. (state.curMusic or "")
    out[#out + 1] = "sprites=" .. #(state.sprites or {})
    for _, s in ipairs(state.sprites or {}) do
        out[#out + 1] = "sprite " .. s.name .. " " .. (s.x or 0) .. " " .. (s.y or 0)
    end
    out[#out + 1] = "vars"
    for k, v in pairs(state.vars or {}) do
        -- escape = and newlines
        local key = tostring(k):gsub("=", "\\=")
        local val = tostring(v):gsub("\n", "\\n"):gsub("=", "\\=")
        out[#out + 1] = key .. "=" .. val
    end
    out[#out + 1] = "endvars"
    return table.concat(out, "\n")
end

-------------------------------------------------------------------------------
-- Parse the serialized save back into a state table.
-------------------------------------------------------------------------------
local function deserialize(text)
    local lines = {}
    for l in text:gmatch("[^\n]+") do lines[#lines + 1] = l end
    local state = { vars = {} }
    local inVars = false
    for _, l in ipairs(lines) do
        if l:sub(1, 4) == "VNDS" then
            -- version marker
        elseif l == "vars" then
            inVars = true
        elseif l == "endvars" then
            inVars = false
        elseif inVars then
            local k, v = l:match("^(.-)=(.*)$")
            if k then
                k = k:gsub("\\=", "=")
                v = v:gsub("\\n", "\n"):gsub("\\=", "=")
                state.vars[k] = v
            end
        else
            local key, val = l:match("^(%w+)=(.*)$")
            if key then
                if key == "file" then state.curFile = (val == "") and nil or val
                elseif key == "pc" then state.pc = tonumber(val)
                elseif key == "bg" then state.bgName = (val == "") and nil or val
                elseif key == "text" then state.text = (val == "") and nil or val:gsub("\\n", "\n")
                elseif key == "music" then state.curMusic = (val == "") and nil or val
                elseif key == "sprites" then state._spriteCount = tonumber(val) or 0
                end
            end
        end
    end
    -- parse sprite lines
    state.sprites = {}
    for _, l in ipairs(lines) do
        local name, x, y = l:match("^sprite%s+(%S+)%s+(-?%d+)%s+(-?%d+)$")
        if name then
            state.sprites[#state.sprites + 1] = { name = name, x = tonumber(x), y = tonumber(y) }
        end
    end
    return state
end

-------------------------------------------------------------------------------
-- Build the save directory path for a novel.
-------------------------------------------------------------------------------
local function saveDir(novelRoot)
    return novelRoot .. "saves/"
end

-------------------------------------------------------------------------------
-- Write a save to a slot (1..N). Captures a screenshot thumbnail.
-- Returns true on success.
-------------------------------------------------------------------------------
function save.write(novelRoot, slot, interpState, title)
    local dir = saveDir(novelRoot)
    pcall(function() System.createDir(dir) end)

    local ok, data = pcall(serialize, interpState)
    if not ok then return false, "serialize failed" end
    local path = dir .. "slot" .. slot .. ".vnds"
    local f = io.open(path, "w")
    if not f then return false, "cannot open save file" end
    local wok, werr = pcall(function() f:write(data) end)
    pcall(function() f:close() end)
    if not wok then return false, "write failed: " .. tostring(werr) end

    -- capture a small screenshot for the save list
    pcall(function()
        LUA.screenshot(dir .. "slot" .. slot .. ".png", 160, 90)
    end)

    return true
end

-------------------------------------------------------------------------------
-- Read a save slot. Returns a state table or nil.
-------------------------------------------------------------------------------
function save.read(novelRoot, slot)
    local path = saveDir(novelRoot) .. "slot" .. slot .. ".vnds"
    if not System.isFile(path) then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    if not text or text == "" then return nil end
    return deserialize(text)
end

-------------------------------------------------------------------------------
-- Does a save exist in this slot?
-------------------------------------------------------------------------------
function save.exists(novelRoot, slot)
    return System.isFile(saveDir(novelRoot) .. "slot" .. slot .. ".vnds")
end

-------------------------------------------------------------------------------
-- Delete a save slot.
-------------------------------------------------------------------------------
function save.delete(novelRoot, slot)
    pcall(function() System.removeFile(saveDir(novelRoot) .. "slot" .. slot .. ".vnds") end)
    pcall(function() System.removeFile(saveDir(novelRoot) .. "slot" .. slot .. ".png") end)
end

-------------------------------------------------------------------------------
-- Path to a slot's thumbnail (may not exist).
-------------------------------------------------------------------------------
function save.thumbPath(novelRoot, slot)
    return saveDir(novelRoot) .. "slot" .. slot .. ".png"
end

return save
