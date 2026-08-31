-- ============================================================================
--  vnds/save.lua
--  System-level Save / load system using PSP native SaveData dialogs
--  (matching RenPSP / Ren'Py standards).
-- ============================================================================

local save = {}

local SAVE_VERSION = 1

-------------------------------------------------------------------------------
-- Compact serializer for the interpreter state.
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
        local key = tostring(k):gsub("=", "\\=")
        local val = tostring(v):gsub("\n", "\\n"):gsub("=", "\\=")
        out[#out + 1] = key .. "=" .. val
    end
    out[#out + 1] = "endvars"
    return table.concat(out, "\n")
end

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
    state.sprites = {}
    for _, l in ipairs(lines) do
        local name, x, y = l:match("^sprite%s+(%S+)%s+(-?%d+)%s+(-?%d+)$")
        if name then
            state.sprites[#state.sprites + 1] = { name = name, x = tonumber(x), y = tonumber(y) }
        end
    end
    return state
end

local function saveDir(novelRoot)
    return novelRoot .. "saves/"
end

-------------------------------------------------------------------------------
-- System Save using PSP native SaveData dialog (RenPSP style)
-------------------------------------------------------------------------------
function save.systemSave(novelRoot, interpState, title)
    local dir = saveDir(novelRoot)
    pcall(function() System.createDir(dir) end)
    pcall(function() System.createDir(dir .. "res") end)

    local ok, data = pcall(serialize, interpState)
    if not ok then return false, "serialize failed" end

    -- Use cached pure gameplay frame or fallback to clean draw
    local saveBg = dir .. "res/savebg.png"
    local pureFrame = dir .. "pure_frame.png"
    pcall(function()
        if System.isFile(pureFrame) then
            local f = io.open(pureFrame, "rb")
            if f then
                local b = f:read("*a")
                f:close()
                local df = io.open(saveBg, "wb")
                if df then
                    df:write(b)
                    df:close()
                end
            end
        else
            screen.clear(Color.new(0, 0, 0))
            if _lastIt then
                drawGame({ bg = _lastIt.bg, sprites = _lastIt.sprites, text = _lastIt.text }, _lastIt)
            end
            screen.flip()
            LUA.screenshot(saveBg, 144, 80)
            LUA.sleep(30)
        end
    end)

    local isRu = (_G.language == "ru")
    local saveTitle = isRu and "Сохранение игры" or "Game Save"
    local desc = isRu and ("Новелла: " .. (title or "Visual Novel")) or ("Novel: " .. (title or "Visual Novel"))

    local iconPath = saveBg
    if not System.isFile(iconPath) then
        iconPath = saveBg
    end

	local rez = nil
    pcall(function()
        rez = System.SaveData(saveTitle, "Save Slot", desc, dir .. "res", iconPath, nil)
    end)

    if rez then
        local slotId = tostring(rez)
        local path = dir .. "save_" .. slotId .. ".save"
        local f = io.open(path, "w")
        if f then
            f:write(data)
            f:close()
        end
        return true
    end
    return false, "system save cancelled or failed"
end

-------------------------------------------------------------------------------
-- System Load using PSP native LoadData dialog (RenPSP style)
-------------------------------------------------------------------------------
function save.systemLoad(novelRoot)
    local dir = saveDir(novelRoot)
    local rez = nil
    pcall(function()
        rez = System.LoadData(nil)
    end)

    if rez and rez.id then
        local path = dir .. "save_" .. tostring(rez.id) .. ".save"
        if System.isFile(path) then
            local f = io.open(path, "r")
            if f then
                local text = f:read("*a")
                f:close()
                if text and text ~= "" then
                    return deserialize(text)
                end
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- System Save with custom clean thumbnail
-------------------------------------------------------------------------------
function save.systemSaveCustom(novelRoot, interpState, title, thumbPath)
    local dir = saveDir(novelRoot)
    pcall(function() System.createDir(dir) end)
    pcall(function() System.createDir(dir .. "res") end)

    local ok, data = pcall(serialize, interpState)
    if not ok then return false, "serialize failed" end

	local iconPath = dir..'res/saveBg.png'

    pcall(function()
        screen.clear(Color.new(0, 0, 0))
        screen.flip()
        LUA.screenshot(iconPath, 144, 80)
    end)

    local isRu = (_G.language == "ru")
    local saveTitle = isRu and "Сохранение игры" or "Game Save"
    local desc = isRu and ("Новелла: " .. (title or "Visual Novel")) or ("Novel: " .. (title or "Visual Novel"))
    
    if not System.isFile(iconPath) then
        iconPath = "vnds/savelogo.jpg"
    end
    if not System.isFile(iconPath) then
        iconPath = thumbPath or dir .. "res/savebg.png"
    end

    local rez = nil
    pcall(function()
        rez = System.SaveData(saveTitle, "Save Slot", desc, dir .. "res", iconPath, dir .. "res/savebg.png")
    end)

    if rez then
        local slotId = tostring(rez)
        local path = dir .. "save_" .. slotId .. ".save"
        local f = io.open(path, "w")
        if f then
            f:write(data)
            f:close()
        end
        return true
    end
    return false, "system save cancelled or failed"
end

return save
