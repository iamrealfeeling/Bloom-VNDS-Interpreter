-- ============================================================================
--  vnds/audio.lua
--  Audio wrapper around LuaPlayerYT's sound.* API.
-- ============================================================================

local audio = {}
audio.__index = audio

audio.DEBUG = true
local dbgFile = nil
local function dbg(...)
    if not audio.DEBUG then return end
    local t = { ... }
    local msg = ""
    for i = 1, #t do msg = msg .. tostring(t[i]) .. "\t" end
    if not dbgFile then
        pcall(function() dbgFile = io.open("vnds_audio.log", "a") end)
    end
    if dbgFile then
        dbgFile:write(os.date("%H:%M:%S") .. "\t" .. msg .. "\n")
        pcall(function() dbgFile:flush() end)
    end
end
audio.dbg = dbg

function audio.closeLog()
    pcall(function() if dbgFile then dbgFile:close() end end)
    dbgFile = nil
end

audio.BGM_CHANNEL = 7     -- OGG_1
audio.VOICE_CHANNELS = { 18, 19, 20, 21 }

audio.CLICK_CHANNEL = 18  -- WAV_x slot (voices use 18-21); free in the launcher menus

-- Short UI click, used only in the launcher menus (never in gameplay).
function audio.playClick()
    pcall(function()
        -- try several candidate locations (runtime working dir is not guaranteed)
        local real = resolvePath("vnds/click.wav")
        if not real then real = resolvePath("click.wav") end
        if not real then real = resolvePath("../vnds/click.wav") end
        if not real then
            dbg("CLICK file not found")
            return
        end
        -- mirror the proven playVoice sequence: PSP audio needs time to release
        -- a channel (stop -> settle -> unload -> settle) before it can reload it.
        pcall(function() sound.stop(audio.CLICK_CHANNEL) end)
        pcall(function() LUA.sleep(8) end)
        pcall(function() sound.unload(audio.CLICK_CHANNEL) end)
        pcall(function() LUA.sleep(12) end)
        sound.cloud(real, audio.CLICK_CHANNEL, true)
        sound.play(audio.CLICK_CHANNEL, false)
        dbg("CLICK played file=", real)
    end)
end

audio.curVoice = nil
audio.curVoicePath = nil

local pathCache = {}
local function resolvePath(path)
    if not path or path == "" or path == "~" then return nil end
    if pathCache[path] ~= nil then return pathCache[path] end

    local function ret(v)
        pathCache[path] = v
        return v
    end

    local base, ext = path:match("^(.*)%.(%w+)$")
    if not ext then
        for _, e in ipairs({ ".ogg", ".wav", ".at3" }) do
            if System.isFile(path .. e) then return ret(path .. e) end
        end
        return ret(nil)
    end
    ext = ext:lower()

    if ext == "mp3" or ext == "aac" then
        local o = base .. ".ogg"
        if System.isFile(o) then return ret(o) end
        local w = base .. ".wav"
        if System.isFile(w) then return ret(w) end
        local a = base .. ".at3"
        if System.isFile(a) then return ret(a) end
        return ret(nil)
    end

    if System.isFile(path) then return ret(path) end
    if ext == "ogg" then
        local w = base .. ".wav"
        if System.isFile(w) then return ret(w) end
    end
    return ret(nil)
end

audio.resolvePath = resolvePath

function audio.playBGM(path)
    if not path or path == "" or path == "~" then
        pcall(function() sound.stop(audio.BGM_CHANNEL) end)
        pcall(function() sound.unload(audio.BGM_CHANNEL) end)
        return true
    end

    local real = resolvePath(path)
    if not real then
        dbg("BGM FAIL path=", path)
        return false, "музыка не найдена: " .. path
    end

    local ok, err = pcall(function()
        pcall(function() sound.stop(audio.BGM_CHANNEL) end)
        pcall(function() sound.unload(audio.BGM_CHANNEL) end)
        sound.cloud(real, audio.BGM_CHANNEL, false)
        sound.play(audio.BGM_CHANNEL, true)
        sound.volume(audio.BGM_CHANNEL, 80, 80)
    end)
    if not ok then dbg("BGM ERROR:", err); return false, err end
    dbg("BGM OK channel=", audio.BGM_CHANNEL, "file=", real)
    return true
end

function audio.playVoice(path, mode)
    if not path or path == "" or path == "~" then return nil end
    local real = resolvePath(path)
    if not real then return nil end

    mode = mode or -1
    local function isPlaying(ch)
        local playing = false
        pcall(function()
            local st = sound.state(ch)
            if st == "playing" then playing = true
            elseif type(st) == "table" and st.state == "playing" then playing = true end
        end)
        return playing
    end

    for _, c in ipairs(audio.VOICE_CHANNELS) do
        pcall(function() sound.stop(c) end)
    end
    pcall(function() LUA.sleep(8) end)
    for _, c in ipairs(audio.VOICE_CHANNELS) do
        pcall(function() sound.unload(c) end)
    end
    pcall(function() LUA.sleep(12) end)

    local ch = audio.VOICE_CHANNELS[1]
    pcall(function()
        sound.cloud(real, ch, true)
        sound.play(ch, false)
    end)
    audio.curVoice = ch
    audio.curVoicePath = real
    return ch
end

function audio.freeChannel(channel)
    pcall(function() sound.stop(channel) end)
    pcall(function() sound.unload(channel) end)
end

function audio.stopAll()
    pcall(function() sound.stop(audio.BGM_CHANNEL) end)
    for _, ch in ipairs(audio.VOICE_CHANNELS) do
        pcall(function() sound.stop(ch) end)
    end
    pcall(function() LUA.sleep(32) end)
    pcall(function() sound.unload(audio.BGM_CHANNEL) end)
    for _, ch in ipairs(audio.VOICE_CHANNELS) do
        pcall(function() sound.unload(ch) end)
    end
    audio.curVoice = nil
    audio.curVoicePath = nil
end

function audio.stopAllVoice()
    for _, ch in ipairs(audio.VOICE_CHANNELS) do
        pcall(function() sound.stop(ch) end)
    end
    pcall(function() LUA.sleep(24) end)
    for _, ch in ipairs(audio.VOICE_CHANNELS) do
        pcall(function() sound.unload(ch) end)
    end
    audio.curVoice = nil
    audio.curVoicePath = nil
end

function audio.isPlaying(channel)
    if not channel then return false end
    local ok, st = pcall(function() return sound.state(channel) end)
    if not ok then return false end
    if type(st) == "string" then return st == "playing" end
    if type(st) == "table" and st.state then return st.state == "playing" end
    return false
end

return audio
