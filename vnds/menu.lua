-- ============================================================================
--  vnds/menu.lua
--  Authentic PlayStation UI: Functional Left Sidebar + Right Novel List/Browsing.
-- ============================================================================

local menu = {}

local i18n = require("vnds.i18n")
local audio = require("vnds.audio")

local SCREEN_W, SCREEN_H = 480, 272

-- build a Color from a {r,g,b} or {r,g,b,a} table
local function C(v)
    if not v then return Color.new(0, 0, 0) end
    return Color.new(v[1], v[2], v[3], v[4] or 255)
end

-- Launcher themes. _G.theme holds the selected index into this list.
local themes = {
    {
        name = "t_blue",
        bgTop    = {18, 52, 100}, bgBot   = {3, 12, 30}, bgBlob = {90, 170, 255},
        wave     = {80, 160, 255},
        header   = {10, 24, 58},  headerA = {70, 130, 220},
        panel    = {14, 28, 62},  panelA  = 210, glow = {60, 120, 210}, sheen = {120, 160, 230},
        border   = {80, 160, 255}, bDim   = {100, 160, 255, 150},
        pillTop  = {60, 140, 255}, pillBot = {30, 70, 150}, pillBTop = {170, 230, 255}, pillBBot = {90, 160, 255}, pillAcc = {180, 235, 255},
        selHi    = {50, 110, 210}, selFill = {28, 64, 145}, selRow = {24, 60, 140, 240},
        rowFill  = {18, 36, 76, 200}, selB = {150, 225, 255}, selB2 = {70, 140, 230}, selGlow = {120, 200, 255, 60},
        thumb    = {30, 45, 80},  trk = {40, 70, 120}, thFill = {140, 200, 255}, thGlow = {180, 230, 255, 120},
        txtBright = {255, 255, 255}, txtMuted = {180, 200, 230}, txtSub = {150, 180, 220},
        txtVal = {140, 220, 255}, txtHint = {150, 175, 205}, txtDanger = {255, 120, 120},
        title = {240, 245, 255}, sub = {180, 205, 255}, sep = {60, 110, 190}, sepHi = {120, 180, 255, 120},
        bar  = {6, 14, 34}, barA = {70, 130, 220}, barGlow = {120, 180, 255, 80},
    },
    {
        name = "t_night",
        bgTop    = {40, 26, 78},  bgBot   = {6, 6, 20},  bgBlob = {140, 90, 220},
        wave     = {120, 80, 200},
        header   = {22, 16, 46},  headerA = {120, 80, 200},
        panel    = {24, 18, 48},  panelA  = 215, glow = {90, 60, 170}, sheen = {120, 100, 190},
        border   = {130, 90, 220}, bDim   = {130, 90, 220, 150},
        pillTop  = {110, 70, 200}, pillBot = {48, 28, 100}, pillBTop = {200, 170, 255}, pillBBot = {110, 70, 190}, pillAcc = {210, 180, 255},
        selHi    = {100, 60, 180}, selFill = {62, 38, 130}, selRow = {60, 38, 120, 240},
        rowFill  = {34, 24, 66, 200}, selB = {200, 170, 255}, selB2 = {110, 70, 200}, selGlow = {170, 140, 255, 60},
        thumb    = {44, 30, 80},  trk = {70, 50, 120}, thFill = {180, 150, 255}, thGlow = {210, 190, 255, 120},
        txtBright = {255, 255, 255}, txtMuted = {200, 185, 230}, txtSub = {170, 150, 210},
        txtVal = {200, 170, 255}, txtHint = {170, 155, 205}, txtDanger = {255, 130, 130},
        title = {245, 240, 255}, sub = {190, 175, 240}, sep = {110, 70, 190}, sepHi = {170, 140, 255, 120},
        bar  = {16, 12, 36}, barA = {120, 80, 200}, barGlow = {170, 140, 255, 80},
    },
    {
        name = "t_light",
        bgTop    = {190, 210, 245}, bgBot = {120, 145, 200}, bgBlob = {255, 255, 255},
        wave     = {140, 175, 240},
        header   = {70, 100, 170}, headerA = {110, 140, 210},
        panel    = {240, 245, 255}, panelA = 235, glow = {120, 150, 220}, sheen = {255, 255, 255},
        border   = {90, 120, 200}, bDim   = {90, 120, 200, 150},
        pillTop  = {120, 155, 230}, pillBot = {70, 100, 180}, pillBTop = {255, 255, 255}, pillBBot = {110, 140, 210}, pillAcc = {255, 255, 255},
        selHi    = {150, 180, 240}, selFill = {110, 140, 220}, selRow = {120, 150, 230, 240},
        rowFill  = {210, 220, 245, 230}, selB = {255, 255, 255}, selB2 = {110, 140, 210}, selGlow = {255, 255, 255, 90},
        thumb    = {180, 195, 230}, trk = {150, 165, 210}, thFill = {90, 120, 200}, thGlow = {60, 90, 180, 120},
        txtBright = {25, 35, 70}, txtMuted = {70, 85, 130}, txtSub = {90, 105, 150},
        txtVal = {40, 80, 150}, txtHint = {90, 105, 150}, txtDanger = {200, 60, 60},
        title = {25, 35, 70}, sub = {70, 90, 150}, sep = {120, 140, 200}, sepHi = {255, 255, 255, 160},
        bar  = {160, 175, 210}, barA = {90, 120, 200}, barGlow = {255, 255, 255, 120},
    },
    {
        name = "t_green",
        bgTop    = {16, 70, 70},  bgBot   = {3, 20, 24},  bgBlob = {70, 200, 160},
        wave     = {70, 180, 140},
        header   = {8, 40, 44},   headerA = {60, 160, 130},
        panel    = {10, 44, 48},  panelA  = 212, glow = {50, 150, 120}, sheen = {90, 180, 150},
        border   = {70, 180, 140}, bDim   = {70, 180, 140, 150},
        pillTop  = {60, 170, 130}, pillBot = {24, 84, 70}, pillBTop = {170, 255, 220}, pillBBot = {70, 170, 130}, pillAcc = {180, 255, 225},
        selHi    = {50, 150, 115}, selFill = {26, 90, 74}, selRow = {24, 84, 70, 240},
        rowFill  = {16, 54, 50, 200}, selB = {170, 255, 220}, selB2 = {60, 150, 115}, selGlow = {140, 240, 190, 60},
        thumb    = {26, 70, 62},  trk = {36, 90, 80}, thFill = {130, 220, 170}, thGlow = {170, 250, 205, 120},
        txtBright = {255, 255, 255}, txtMuted = {190, 225, 210}, txtSub = {160, 200, 180},
        txtVal = {150, 230, 190}, txtHint = {150, 195, 180}, txtDanger = {255, 130, 120},
        title = {240, 255, 248}, sub = {180, 220, 200}, sep = {60, 150, 120}, sepHi = {150, 240, 190, 120},
        bar  = {5, 28, 30}, barA = {60, 160, 130}, barGlow = {150, 240, 190, 80},
    },
}

local function currentTheme()
    local t = themes[math.floor(_G.theme or 1)]
    if not t then t = themes[1] end
    return t
end

-------------------------------------------------------------------------------
-- Draw PS4 Dynamic Blue Wave Background
-------------------------------------------------------------------------------
local function drawBackground(animTick)
    local th = currentTheme()
    local top, bot = th.bgTop, th.bgBot
    screen.clear(Color.new(bot[1], bot[2], bot[3]))
    local bands = 24
    for i = 1, bands do
        local t = i / bands
        local r = math.floor(top[1] + (bot[1] - top[1]) * t)
        local g = math.floor(top[2] + (bot[2] - top[2]) * t)
        local b = math.floor(top[3] + (bot[3] - top[3]) * t)
        screen.filledRect(0, math.floor((i - 1) * SCREEN_H / bands), SCREEN_W,
            math.floor(SCREEN_H / bands) + 1, Color.new(r, g, b))
    end
    -- gentle animated light blobs for depth
    local pulse = 0.5 + 0.5 * math.sin((animTick or 0) * 0.02)
    screen.filledRect(60, 20, 200, 200, Color.new(th.bgBlob[1], th.bgBlob[2], th.bgBlob[3], math.floor(8 + 6 * pulse)))
    screen.filledRect(340, 90, 160, 160, Color.new(th.bgBlob[1], th.bgBlob[2], th.bgBlob[3], math.floor(6 + 4 * pulse)))
    local wave = math.sin((animTick or 0) * 0.03) * 35
    for i = 1, 4 do
        local a = 12 - i * 2
        screen.filledRect(100 + wave + i * 15, 50 + i * 20, 280 + i * 15, 80 + i * 15, Color.new(th.wave[1], th.wave[2], th.wave[3], a))
    end
    -- subtle vignette
    screen.filledRect(0, 0, SCREEN_W, 3, Color.new(0, 0, 0, 70))
    screen.filledRect(0, SCREEN_H - 4, SCREEN_W, 4, Color.new(0, 0, 0, 80))
end

-------------------------------------------------------------------------------
-- Scan novels/ folder
-------------------------------------------------------------------------------
function menu.scanNovels(base)
    base = base or "novels/"
    local list = System.listDir(base)
    if not list then return {} end

    local novels = {}
    for _, entry in ipairs(list) do
        local name = entry.name
        if name ~= "." and name ~= ".." then
            local root = base .. name .. "/"
            local scriptDir = nil
            if System.isDir(root .. "script") then scriptDir = "script"
            elseif System.isDir(root .. "Scripts") then scriptDir = "Scripts" end
            if System.isDir(root) and scriptDir then
                local novel = { name = name, root = root, scriptDir = scriptDir, title = name, icon = nil, size = "150 МБ" }

                local infoPath = root .. "info.txt"
                if System.isFile(infoPath) then
                    local f = io.open(infoPath, "r")
                    if f then
                        for l in f:lines() do
                            local t = l:match("^title=%s*(.-)%s*$")
                            if t then novel.title = t
                            elseif l:match("%S") and novel.title == name then
                                novel.title = l:match("^%s*(.-)%s*$")
                            end
                        end
                        f:close()
                    end
                end

                local iconPath = root .. "icon.png"
                if not System.isFile(iconPath) then iconPath = root .. "thumbnail.png" end
                if System.isFile(iconPath) then
                    local ok, img = pcall(function() return Image.load(iconPath) end)
                    if ok and img then novel.icon = img end
                end

                novels[#novels + 1] = novel
            end
        end
    end
    return novels
end

-------------------------------------------------------------------------------
-- Run launcher loop with interactive Sidebar & Content focus
-------------------------------------------------------------------------------
function menu.run(onPick)
    -- Defaults
    _G.autoReadDelay = _G.autoReadDelay or 3
    _G.fontScale = _G.fontScale or 1.25
    _G.textColor = _G.textColor or 1      -- index into textColors palette
    _G.textShadow = _G.textShadow or 1    -- 0=off, 1=on (shadowed text)
    -- extended UI
    _G.boxAlpha = _G.boxAlpha or 180      -- dialogue box opacity 0..255
    _G.boxColor = _G.boxColor or 1        -- index into boxColors palette
    _G.borderColor = _G.borderColor or 1  -- index into borderColors palette
    _G.language = _G.language or "ru"
    _G.theme = _G.theme or 1
    if _G.launcherMode == nil then _G.launcherMode = true end
    _G.defaultNovel = _G.defaultNovel or ""
    if _G.devMode == nil then _G.devMode = false end

    -- Read config first thing to respect launchermode
    local cfgPath = "novels/config.vnds"
    pcall(function()
        local f = io.open(cfgPath, "r")
        if f then
            for l in f:lines() do
                local k, v = l:match("^(.-)=(.*)$")
                if k and v then
                    k = k:match("^%s*(.-)%s*$"):lower()
                    v = v:match("^%s*(.-)%s*$")
                    if k == "autoreaddelay" and tonumber(v) then _G.autoReadDelay = tonumber(v)
                    elseif k == "fontscale" and tonumber(v) then _G.fontScale = tonumber(v)
                    elseif k == "textcolor" and tonumber(v) then _G.textColor = tonumber(v)
                    elseif k == "textshadow" and tonumber(v) then _G.textShadow = tonumber(v)
                    elseif k == "boxalpha" and tonumber(v) then _G.boxAlpha = tonumber(v)
                    elseif k == "boxcolor" and tonumber(v) then _G.boxColor = tonumber(v)
                    elseif k == "bordercolor" and tonumber(v) then _G.borderColor = tonumber(v)
                    elseif k == "language" and type(v) == "string" and v ~= "" then _G.language = v
                    elseif k == "theme" and tonumber(v) then _G.theme = tonumber(v)
                    elseif k == "launchermode" or k == "launcher_mode" then
                        local vl = v:lower()
                        _G.launcherMode = (vl ~= "0" and vl ~= "false" and vl ~= "off")
                    elseif k == "devmode" then
                        local vl = v:lower()
                        _G.devMode = (vl ~= "0" and vl ~= "false" and vl ~= "off")
                    elseif (k == "defaultnovel" or k == "default_novel" or k == "novel") and type(v) == "string" then
                        _G.defaultNovel = v
                    end
                end
            end
            f:close()
        end
    end)
    i18n.setLanguage(_G.language)

    local novels = menu.scanNovels("novels/")
    if #novels == 0 then
        menu.showEmpty()
        return nil
    end

    -- If launcher mode is disabled, bypass launcher and start default novel immediately
    if _G.launcherMode == false then
        local target = novels[1]
        if _G.defaultNovel and _G.defaultNovel ~= "" then
            for _, nov in ipairs(novels) do
                if nov.name:lower() == _G.defaultNovel:lower() or nov.title:lower() == _G.defaultNovel:lower() then
                    target = nov
                    break
                end
            end
        end
        print("BYPASS LAUNCHER: launching novel ->", target and target.name)
        onPick(target)
        return target
    end

    local focus = "list"   -- "sidebar" or "list" or "settings" or "help"
    local sbSel = 1        -- Selected sidebar item (1..5)
    local novSel = 1       -- Selected novel index (1..#novels)
    local settingsSel = 1  -- Selected settings row
    local helpSel = 1      -- Selected help row (scrollable)
    local langCodes = {}   -- ordered language codes for the Language setting
    for _, l in ipairs(i18n.langList()) do langCodes[#langCodes + 1] = l.code end
    local animTick = 0
    if _G.launcherMode == nil then _G.launcherMode = true end
    _G.defaultNovel = _G.defaultNovel or ""

    -- UI customization palettes (display name = translation key)
    local fontScales = { 0.75, 1.0, 1.25, 1.5, 1.75, 2.0 }
    local textColors = {
        { 255, 255, 255, "col_white" },
        { 255, 240, 170, "col_cream" },
        { 255, 150, 120, "col_peach" },
        { 150, 220, 130, "col_salad" },
        { 130, 210, 255, "col_sky" },
        { 255, 180, 110, "col_orange" },
    }
    local boxColors = {
        { 0,   0,   0,   "bcol_black" },
        { 10,  10,  34,  "bcol_navy" },
        { 22,  28,  52,  "bcol_slate" },
        { 38,  38,  42,  "bcol_gray" },
        { 70,  28,  28,  "bcol_brown" },
    }
    local borderColors = {
        { 120, 140, 220, "rcol_blue" },
        { 255, 255, 255, "rcol_white" },
        { 180, 210, 255, "rcol_sky" },
        { 255, 220, 120, "rcol_gold" },
        { 255, 120, 120, "rcol_red" },
        { 120, 255, 160, "rcol_green" },
    }
    local boxAlphaSteps = { 90, 130, 160, 200, 240 }   -- opacity steps

    i18n.setLanguage(_G.language)

    -- clamp loaded values to valid ranges
    local function nearest(list, v)
        local best, bd = list[1], 1e9
        for _, x in ipairs(list) do
            if math.abs(x - v) < bd then best, bd = x, math.abs(x - v) end
        end
        return best
    end
    _G.fontScale = nearest(fontScales, _G.fontScale)
    _G.textColor = ((_G.textColor - 1) % #textColors) + 1
    _G.boxColor = ((_G.boxColor - 1) % #boxColors) + 1
    _G.borderColor = ((_G.borderColor - 1) % #borderColors) + 1
    _G.boxAlpha = nearest(boxAlphaSteps, _G.boxAlpha)
    _G.textShadow = (_G.textShadow == 0) and 0 or 1
    _G.theme = ((math.floor(_G.theme or 1) - 1) % #themes) + 1

    -- localized labels now that the language is loaded
    local sbItems = {
        { name = i18n.t("sb_launch"), desc = i18n.t("d_launch") },
        { name = i18n.t("sb_recents"), desc = i18n.t("d_recents") },
        { name = i18n.t("sb_settings"), desc = i18n.t("d_settings") },
        { name = i18n.t("sb_about"), desc = i18n.t("d_about") },
        { name = i18n.t("sb_exit"), desc = i18n.t("d_exit") },
    }

    local settingsItems = {
        { key = "autoReadDelay", label = "set_autodelay", group = "grp_reading" },
        { key = "fontScale",     label = "set_fontsize", group = "grp_font" },
        { key = "textColor",     label = "set_textcolor", group = "grp_font" },
        { key = "textShadow",    label = "set_textshadow", group = "grp_font" },
        { key = "boxAlpha",      label = "set_boxalpha", group = "grp_box" },
        { key = "boxColor",      label = "set_boxcolor", group = "grp_box" },
        { key = "borderColor",   label = "set_bordercolor", group = "grp_box" },
        { key = "theme",         label = "set_theme", group = "grp_system" },
        { key = "language",      label = "set_language", group = "grp_system" },
    }

    -- About/Help panel rows (scrollable like settings)
    local helpItems = {
        { type = "head",  text = "hlp_controls" },
        { type = "row",   text = "hlp_cross" },
        { type = "row",   text = "hlp_r" },
        { type = "row",   text = "hlp_select" },
        { type = "row",   text = "hlp_square" },
        { type = "row",   text = "hlp_triangle" },
        { type = "row",   text = "hlp_l" },
        { type = "row",   text = "hlp_choice" },
        { type = "head",  text = "hlp_credits" },
        { type = "row",   text = "hlp_made" },
        { type = "row",   text = "hlp_dev" },
    }
    local function helpText(item)
        return i18n.t(item.text)
    end

    local function saveConfig()
        pcall(function()
            local f = io.open(cfgPath, "w")
            if f then
                f:write("autoReadDelay=" .. tostring(_G.autoReadDelay) .. "\n")
                f:write("fontScale=" .. (_G.fontScale or 1.25) .. "\n")
                f:write("textColor=" .. (_G.textColor or 1) .. "\n")
                f:write("textShadow=" .. (_G.textShadow or 1) .. "\n")
                f:write("boxAlpha=" .. (_G.boxAlpha or 180) .. "\n")
                f:write("boxColor=" .. (_G.boxColor or 1) .. "\n")
                f:write("borderColor=" .. (_G.borderColor or 1) .. "\n")
                f:write("theme=" .. (_G.theme or 1) .. "\n")
                f:write("language=" .. tostring(_G.language or "ru") .. "\n")
                f:write("launchermode=" .. (_G.launcherMode ~= false and "1" or "0") .. "\n")
                f:write("defaultnovel=" .. (_G.defaultNovel or "") .. "\n")
                f:write("devmode=" .. (_G.devMode and "1" or "0") .. "\n")
                f:close()
            end
        end)
    end

    local recentNovels = {}
    local recentPath = "novels/recent.vnds"
    pcall(function()
        local f = io.open(recentPath, "r")
        if f then
            for l in f:lines() do
                l = l:match("^%s*(.-)%s*$")
                if l ~= "" then recentNovels[#recentNovels + 1] = l end
            end
            f:close()
        end
    end)

    if _G.launcherMode == false then
        local novels = menu.scanNovels("novels/")
        if #novels > 0 then
            local target = novels[1]
            if _G.defaultNovel and _G.defaultNovel ~= "" then
                for _, nov in ipairs(novels) do
                    if nov.name:lower() == _G.defaultNovel:lower() or nov.title:lower() == _G.defaultNovel:lower() then
                        target = nov
                        break
                    end
                end
            end
            onPick(target)
            return target
        end
    end

    while true do
        buttons.read()
        animTick = animTick + 1

        -- UI click feedback (launcher menus only)
        if buttons.pressed(buttons.up) or buttons.pressed(buttons.down)
           or buttons.pressed(buttons.left) or buttons.pressed(buttons.right)
           or buttons.pressed(buttons.cross) or buttons.pressed(buttons.circle) then
            audio.playClick()
        end

        local activeList = novels
        if sbSel == 2 then
            activeList = {}
            for _, rName in ipairs(recentNovels) do
                for _, n in ipairs(novels) do
                    if n.name == rName then activeList[#activeList + 1] = n end
                end
            end
            if #activeList == 0 then activeList = novels end
        end

        if focus == "sidebar" then
            if buttons.pressed(buttons.up) then
                sbSel = sbSel - 1
                if sbSel < 1 then sbSel = #sbItems end
                novSel = 1
            elseif buttons.pressed(buttons.down) then
                sbSel = sbSel + 1
                if sbSel > #sbItems then sbSel = 1 end
                novSel = 1
            elseif buttons.pressed(buttons.right) then
                if sbSel <= 2 then
                    focus = "list"
                elseif sbSel == 3 then
                    focus = "settings"
                elseif sbSel == 4 then
                    focus = "help"
                end
            elseif buttons.pressed(buttons.cross) then
                if sbSel <= 2 then
                    focus = "list"
                elseif sbSel == 3 then
                    focus = "settings"
                elseif sbSel == 5 then
                    for _, nov in ipairs(novels) do
                        if nov.icon then pcall(function() Image.unload(nov.icon) end); nov.icon = nil end
                    end
                    LUA.exit()
                    return nil
                end
            end
        elseif focus == "settings" then
            if buttons.pressed(buttons.up) then
                settingsSel = settingsSel - 1
                if settingsSel < 1 then settingsSel = #settingsItems end
            elseif buttons.pressed(buttons.down) then
                settingsSel = settingsSel + 1
                if settingsSel > #settingsItems then settingsSel = 1 end
            elseif buttons.pressed(buttons.right) or buttons.pressed(buttons.left) then
                local dir = buttons.pressed(buttons.right) and 1 or -1
                local item = settingsItems[settingsSel]
                if item.key == "autoReadDelay" then
                    _G.autoReadDelay = math.max(1, math.min(15, (_G.autoReadDelay or 3) + dir))
                elseif item.key == "fontScale" then
                    local idx
                    for i, v in ipairs(fontScales) do
                        if v == _G.fontScale then idx = i end
                    end
                    idx = idx or 3
                    idx = ((idx - 1 + dir) % #fontScales) + 1
                    _G.fontScale = fontScales[idx]
                elseif item.key == "textColor" then
                    _G.textColor = ((_G.textColor - 1 + dir) % #textColors) + 1
                elseif item.key == "textShadow" then
                    _G.textShadow = (_G.textShadow == 1) and 0 or 1
                elseif item.key == "boxAlpha" then
                    local idx
                    for i, v in ipairs(boxAlphaSteps) do
                        if v == _G.boxAlpha then idx = i end
                    end
                    idx = idx or 3
                    idx = ((idx - 1 + dir) % #boxAlphaSteps) + 1
                    _G.boxAlpha = boxAlphaSteps[idx]
                elseif item.key == "boxColor" then
                    _G.boxColor = ((_G.boxColor - 1 + dir) % #boxColors) + 1
                elseif item.key == "borderColor" then
                    _G.borderColor = ((_G.borderColor - 1 + dir) % #borderColors) + 1
                elseif item.key == "theme" then
                    _G.theme = ((math.floor(_G.theme or 1) - 1 + dir) % #themes) + 1
                elseif item.key == "language" then
                    local idx
                    for i, code in ipairs(langCodes) do
                        if code == (_G.language or "ru") then idx = i end
                    end
                    idx = idx or 1
                    idx = ((idx - 1 + dir) % #langCodes) + 1
                    _G.language = langCodes[idx]
                    i18n.setLanguage(_G.language)
                    -- refresh sidebar labels immediately
                    sbItems[1].name = i18n.t("sb_launch")
                    sbItems[2].name = i18n.t("sb_recents")
                    sbItems[3].name = i18n.t("sb_settings")
                    sbItems[4].name = i18n.t("sb_about")
                    sbItems[5].name = i18n.t("sb_exit")
                end
                saveConfig()
            elseif buttons.pressed(buttons.circle) then
                focus = "sidebar"
            end
        elseif focus == "help" then
            if buttons.pressed(buttons.up) then
                helpSel = helpSel - 1
                if helpSel < 1 then helpSel = #helpItems end
            elseif buttons.pressed(buttons.down) then
                helpSel = helpSel + 1
                if helpSel > #helpItems then helpSel = 1 end
            elseif buttons.pressed(buttons.circle) then
                focus = "sidebar"
            end
        else
            if buttons.pressed(buttons.up) then
                novSel = novSel - 1
                if novSel < 1 then novSel = #activeList end
            elseif buttons.pressed(buttons.down) then
                novSel = novSel + 1
                if novSel > #activeList then novSel = 1 end
            elseif buttons.pressed(buttons.left) then
                focus = "sidebar"
            elseif buttons.pressed(buttons.cross) then
                if #activeList > 0 then
                    local n = activeList[novSel]
                    local newRecents = { n.name }
                    for _, r in ipairs(recentNovels) do
                        if r ~= n.name then newRecents[#newRecents + 1] = r end
                    end
                    pcall(function()
                        local wf = io.open(recentPath, "w")
                        if wf then
                            wf:write(table.concat(newRecents, "\n"))
                            wf:close()
                        end
                    end)

                    for _, nov in ipairs(novels) do
                        if nov.icon then pcall(function() Image.unload(nov.icon) end); nov.icon = nil end
                    end
                    onPick(n)
                    return n
                end
            end
        end

        if buttons.pressed(buttons.triangle) then
            for _, nov in ipairs(novels) do
                if nov.icon then pcall(function() Image.unload(nov.icon) end); nov.icon = nil end
            end
            LUA.exit()
            return nil
        end

        local uiPalettes = {
            textColors = textColors,
            boxColors = boxColors,
            borderColors = borderColors,
            boxAlphaSteps = boxAlphaSteps,
        }
        menu.draw(activeList, novSel, sbSel, focus, animTick, sbItems, settingsItems, settingsSel, uiPalettes, helpItems, helpText, helpSel)
        screen.flip()
    end
end

-------------------------------------------------------------------------------
-- Draw PS4 UI
-------------------------------------------------------------------------------
function menu.draw(novels, novSel, sbSel, focus, animTick, sbItems, settingsItems, settingsSel, uiPalettes, helpItems, helpText, helpSel)
    drawBackground(animTick)
    local th = currentTheme()

    -- Top Header bar
    screen.filledRect(0, 0, SCREEN_W, 28, Color.new(th.header[1], th.header[2], th.header[3], 235))
    screen.filledRect(0, 27, SCREEN_W, 1, C(th.headerA))
    screen.filledRect(0, 28, SCREEN_W, 1, Color.new(th.headerA[1], th.headerA[2], th.headerA[3], 90))
    intraFont.print(16, 3, "Bloom VNDS Interpreter", C(th.txtBright), nil, 1.3)

    -- Left Sidebar Menu Box
    local sbX, sbY, sbW, sbH = 8, 32, 160, 212
    -- soft outer glow frame
    screen.filledRect(sbX - 3, sbY - 3, sbW + 6, sbH + 6, Color.new(th.glow[1], th.glow[2], th.glow[3], 26))
    screen.filledRect(sbX, sbY, sbW, sbH, Color.new(th.panel[1], th.panel[2], th.panel[3], th.panelA))
    local sbColor = (focus == "sidebar") and C(th.border) or C(th.bDim)
    screen.filledRect(sbX, sbY, sbW, 2, sbColor)
    screen.filledRect(sbX, sbY + sbH - 2, sbW, 2, sbColor)
    screen.filledRect(sbX, sbY, 2, sbH, sbColor)
    screen.filledRect(sbX + sbW - 2, sbY, 2, sbH, sbColor)
    -- inner top sheen
    screen.filledRect(sbX + 2, sbY + 2, sbW - 4, 1, Color.new(th.sheen[1], th.sheen[2], th.sheen[3], 70))

    for i, item in ipairs(sbItems) do
        local iy = sbY + 12 + (i - 1) * 40
        local isSel = (i == sbSel)
        if isSel then
            -- gradient pill: lighter top, deeper bottom
            screen.filledRect(sbX + 4, iy - 5, sbW - 8, 18, (focus == "sidebar") and C(th.pillTop) or C(th.pillBot))
            screen.filledRect(sbX + 4, iy + 13, sbW - 8, 18, C(th.pillBot))
            screen.filledRect(sbX + 4, iy - 5, sbW - 8, 2, C(th.pillBTop))
            screen.filledRect(sbX + 4, iy + 29, sbW - 8, 2, C(th.pillBBot))
            -- left accent bar
            screen.filledRect(sbX, iy - 5, 3, 36, C(th.pillAcc))
        end
        intraFont.print(sbX + 14, iy + 6, item.name, isSel and C(th.txtBright) or C(th.txtMuted), nil, 1.05)
    end

    -- Right Content Area Box
    local cX, cY, cW, cH = 176, 32, 296, 212
    local cColor = (focus == "list" or focus == "settings" or focus == "help") and C(th.border) or C(th.bDim)
    screen.filledRect(cX - 3, cY - 3, cW + 6, cH + 6, Color.new(th.glow[1], th.glow[2], th.glow[3], 26))
    screen.filledRect(cX, cY, cW, cH, Color.new(th.panel[1], th.panel[2], th.panel[3], th.panelA))
    screen.filledRect(cX, cY, cW, 2, cColor)
    screen.filledRect(cX, cY + cH - 2, cW, 2, cColor)
    screen.filledRect(cX, cY, 2, cH, cColor)
    screen.filledRect(cX + cW - 2, cY, 2, cH, cColor)
    screen.filledRect(cX + 2, cY + 2, cW - 4, 1, Color.new(th.sheen[1], th.sheen[2], th.sheen[3], 70))

    -- Content Header based on Sidebar selection
    local headerTitle = i18n.t("h_choose")
    if sbSel == 2 then headerTitle = i18n.t("h_recents")
    elseif sbSel == 3 then headerTitle = i18n.t("h_settings")
    elseif sbSel == 4 then headerTitle = i18n.t("h_about")
    elseif sbSel == 5 then headerTitle = i18n.t("h_exit")
    end

    -- header accent underline gradient
    screen.filledRect(cX + 10, cY + 30, cW - 20, 2, C(th.sep))
    screen.filledRect(cX + 10, cY + 30, cW - 20, 1, C(th.sepHi))
    intraFont.print(cX + 14, cY + 6, headerTitle, C(th.title), nil, 1.2)

    if sbSel <= 2 then
        if #novels == 0 then
            intraFont.print(cX + 20, cY + 70, i18n.t("no_novels"), C(th.txtDanger), nil, 1.2)
        else
            local listStartY = cY + 38
            local itemH = 50
            local maxShow = 3
            local scrollIdx = 0
            if #novels > maxShow and novSel > maxShow then
                scrollIdx = novSel - maxShow
            end

            for i = 1, math.min(#novels, maxShow) do
                local nIdx = i + scrollIdx
                if nIdx <= #novels then
                    local nov = novels[nIdx]
                    local iy = listStartY + (i - 1) * (itemH + 6)
                    local isSel = (nIdx == novSel and focus == "list")

                    screen.filledRect(cX + 8, iy, cW - 16, itemH, isSel and C(th.selRow) or C(th.rowFill))

                    if isSel then
                        screen.filledRect(cX + 8, iy, cW - 16, 2, C(th.selB))
                        screen.filledRect(cX + 8, iy + itemH - 2, cW - 16, 2, C(th.selB2))
                        screen.filledRect(cX + 8, iy, 2, itemH, C(th.selB))
                        screen.filledRect(cX + cW - 10, iy, 2, itemH, C(th.selB))
                        -- soft outer glow on the selected row
                        screen.filledRect(cX + 6, iy - 2, cW - 12, 2, C(th.selGlow))
                    end

                    local thumbW, thumbH = 72, itemH - 8
                    local thumbX = cX + 12
                    local thumbY = iy + 4
                    screen.filledRect(thumbX, thumbY, thumbW, thumbH, C(th.thumb))
                    if nov.icon then
                        pcall(function() Image.draw(nov.icon, thumbX, thumbY, thumbW, thumbH, nil) end)
                    end

                    intraFont.printColumn(thumbX + thumbW + 12, iy + 7, nov.title, cW - thumbW - 30,
                        isSel and C(th.txtBright) or C(th.txtMuted), nil, 1.1, 0)
                    intraFont.print(thumbX + thumbW + 12, iy + 32, i18n.t("list_folder") .. ": " .. nov.name, C(th.txtSub), nil, 1.0)
                end
            end
        end
    elseif sbSel == 3 then
        -- Interactive Settings Menu with multiple configurable rows (scrolling)
        local isFocus = (focus == "settings")
        local TC = uiPalettes.textColors
        local BXC = uiPalettes.boxColors
        local BRC = uiPalettes.borderColors

        local rowH = 40
        local gap = 4
        local rowStride = rowH + gap
        local maxVisible = math.floor(190 / rowStride)  -- rows that fit in content box
        if maxVisible < 1 then maxVisible = 1 end
        local top = 1
        local N = #settingsItems
        if N > maxVisible then
            top = settingsSel - math.floor((maxVisible - 1) / 2)
            if top < 1 then top = 1 end
            if top + maxVisible - 1 > N then top = N - maxVisible + 1 end
        end

        -- two-line rows: label on top, value below (larger fonts for readability)
        local startY = cY + 36
        local prevGroup = nil
        for i = top, math.min(N, top + maxVisible - 1) do
            local item = settingsItems[i]
            local ry = startY + (i - top) * rowStride
            local selRow = (i == settingsSel and isFocus)

            if prevGroup ~= item.group then
                if i > top then
                    screen.filledRect(cX + 14, ry - gap, cW - 28, 1, C(th.sep))
                end
                prevGroup = item.group
            end

            screen.filledRect(cX + 12, ry, cW - 24, rowH, selRow and C(th.selFill) or C(th.rowFill))
            if selRow then
                screen.filledRect(cX + 12, ry, cW - 24, 14, C(th.selHi))
                screen.filledRect(cX + 12, ry, cW - 24, 2, C(th.selB))
                screen.filledRect(cX + 12, ry + rowH - 2, cW - 24, 2, C(th.selB2))
                screen.filledRect(cX + 12, ry, 2, rowH, C(th.selB))
            end
            if selRow then
                intraFont.print(cX + 4, ry + 3, "»", C(th.pillBTop), nil, 1.05)
            end
            intraFont.print(cX + 18, ry + 3, i18n.t(item.label), selRow and C(th.txtBright) or C(th.txtMuted), nil, 1.0)

            local valStr
            local valColor
            if item.key == "autoReadDelay" then
                valStr = tostring(_G.autoReadDelay or 3) .. " " .. i18n.t("sec")
                valColor = C(th.txtVal)
            elseif item.key == "fontScale" then
                valStr = string.format("%.2f", _G.fontScale or 1.25)
                valColor = C(th.txtVal)
            elseif item.key == "textColor" then
                local c = TC[_G.textColor] or TC[1]
                valStr = i18n.t(c[4])
                valColor = Color.new(c[1], c[2], c[3])
            elseif item.key == "textShadow" then
                valStr = (_G.textShadow == 1) and i18n.t("val_on") or i18n.t("val_off")
                valColor = (_G.textShadow == 1) and C(th.txtVal) or C(th.txtHint)
            elseif item.key == "boxAlpha" then
                valStr = math.floor((_G.boxAlpha or 180) / 2.55) .. "%"
                valColor = C(th.txtVal)
            elseif item.key == "boxColor" then
                local c = BXC[_G.boxColor] or BXC[1]
                valStr = i18n.t(c[4])
                valColor = Color.new(c[1], c[2], c[3])
            elseif item.key == "borderColor" then
                local c = BRC[_G.borderColor] or BRC[1]
                valStr = i18n.t(c[4])
                valColor = Color.new(c[1], c[2], c[3])
            elseif item.key == "theme" then
                local t = currentTheme()
                valStr = i18n.t(t.name)
                valColor = Color.new(t.selHi[1], t.selHi[2], t.selHi[3])
            elseif item.key == "language" then
                valStr = i18n.langName(_G.language or "ru")
                valColor = C(th.txtVal)
            end
            valStr = "◀ " .. valStr .. " ▶"
            -- value on its own line, left-aligned at a fixed x (even column)
            intraFont.print(cX + 18, ry + 24, valStr, valColor, nil, 1.0)
        end

        -- scroll indicator if the list overflows
        if N > maxVisible then
            local barY = cY + 36
            local barH = maxVisible * rowStride
            local thumbH = math.max(14, math.floor(barH * maxVisible / N))
            local thumbY = barY + math.floor((barH - thumbH) * (top - 1) / (N - maxVisible))
            screen.filledRect(cX + cW - 8, barY, 3, barH, C(th.trk))
            screen.filledRect(cX + cW - 8, thumbY, 3, thumbH, C(th.thFill))
            screen.filledRect(cX + cW - 10, thumbY, 1, thumbH, C(th.thGlow))
        end

        intraFont.print(cX + 12, cY + 238, i18n.t("hint_settings"),
            C(th.txtHint), nil, 0.8)
    elseif sbSel == 4 then
        local isFocus = (focus == "help")
        -- fixed brand title line (full inner width, wraps if needed)
        intraFont.printColumn(cX + 10, cY + 40, "Bloom VNDS Interpreter 1.0.0",
            cW - 20, C(th.txtBright), nil, 1.1, 0)
        screen.filledRect(cX + 10, cY + 68, cW - 20, 2, C(th.sep))

        local rowH = 34
        local gap = 4
        local rowStride = rowH + gap
        local maxVisible = math.floor((cH - 90) / rowStride)
        if maxVisible < 1 then maxVisible = 1 end
        local N = #helpItems
        local top = 1
        if N > maxVisible then
            top = helpSel - math.floor((maxVisible - 1) / 2)
            if top < 1 then top = 1 end
            if top + maxVisible - 1 > N then top = N - maxVisible + 1 end
        end

        local startY = cY + 76
        for i = top, math.min(N, top + maxVisible - 1) do
            local item = helpItems[i]
            local ry = startY + (i - top) * rowStride
            local selRow = (i == helpSel and isFocus)
            local txt = helpText(item)

            if item.type == "head" then
                intraFont.print(cX + 14, ry + 5, txt, C(th.txtBright), nil, 1.05)
            else
                if selRow then
                    screen.filledRect(cX + 8, ry, cW - 16, 14, C(th.selHi))
                    screen.filledRect(cX + 8, ry, cW - 16, rowH, C(th.selFill))
                    screen.filledRect(cX + 8, ry, 2, rowH, C(th.selB))
                    screen.filledRect(cX + 8, ry + rowH - 1, cW - 16, 1, C(th.selB2))
                end
                intraFont.printColumn(cX + 16, ry + 4, txt, cW - 40,
                    C(th.txtBright), nil, 1.1, 0)
            end
        end

        if N > maxVisible then
            local barY = startY
            local barH = maxVisible * rowStride
            local thumbH = math.max(12, math.floor(barH * maxVisible / N))
            local thumbY = barY + math.floor((barH - thumbH) * (top - 1) / (N - maxVisible))
            screen.filledRect(cX + cW - 8, barY, 3, barH, C(th.trk))
            screen.filledRect(cX + cW - 8, thumbY, 3, thumbH, C(th.thFill))
            screen.filledRect(cX + cW - 10, thumbY, 1, thumbH, C(th.thGlow))
        end

        intraFont.print(cX + 12, cY + cH - 14, i18n.t("hlp_hint"),
            C(th.txtBright), nil, 0.8)
    elseif sbSel == 5 then
        -- exit confirmation text removed (empty panel)
    end

    -- Bottom Action Prompt Bar (Removed hints)
    screen.filledRect(0, SCREEN_H - 16, SCREEN_W, 16, Color.new(th.bar[1], th.bar[2], th.bar[3], 240))
    screen.filledRect(0, SCREEN_H - 16, SCREEN_W, 1, C(th.barA))
    screen.filledRect(0, SCREEN_H - 15, SCREEN_W, 1, C(th.barGlow))
end

-------------------------------------------------------------------------------
-- Shown when no novels are present.
-------------------------------------------------------------------------------
function menu.showEmpty()
    while true do
        buttons.read()
        if buttons.pressed(buttons.triangle) or buttons.pressed(buttons.cross) then
            LUA.exit()
            return
        end
        drawBackground(0)
        intraFont.print(40, 104, i18n.t("empty_1"), Color.new(255, 120, 120), nil, 1.3)
        intraFont.print(40, 148, i18n.t("empty_2"), Color.new(200, 225, 255), nil, 1.05)
        intraFont.print(40, 200, i18n.t("exit_btn"), Color.new(160, 200, 255), nil, 0.95)
        screen.flip()
    end
end

return menu
