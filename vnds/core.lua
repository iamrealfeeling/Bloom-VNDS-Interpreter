-- ============================================================================
--  vnds/core.lua
--  Main VNDS engine: ties together the XMB launcher, the .scr interpreter,
--  text/sprite rendering, choices, and the save/load system.
-- ============================================================================

local core = {}

local menu = require("vnds.menu")
local interp = require("vnds.interp")
local audio = require("vnds.audio")
local save = require("vnds.save")
local i18n = require("vnds.i18n")

local SCREEN_W, SCREEN_H = 480, 272

-- shared variable table across scripts/sessions
local globalVars = {}

-- last interpreter instance (so we can free its GPU textures on re-entry)
local _lastIt = nil

-------------------------------------------------------------------------------
-- Forward declarations of helper screens and loops.
-------------------------------------------------------------------------------
local doSave, doLoad, doPause, doChoice, doHistory

-------------------------------------------------------------------------------
-- Text pagination: split long text into pages that fit the dialogue box.
-- Chars per page scale down as the configured dialogue font grows.
-------------------------------------------------------------------------------
local function splitTextPages(text)
    local fs = _G.fontScale or 1.25
    local CHARS_PER_PAGE = math.floor(80 * 3.3 / math.max(fs, 0.5))
    if not text or #text <= CHARS_PER_PAGE then
        return nil  -- no pagination needed
    end
    local pages = {}
    local remaining = text
    while #remaining > 0 do
        if #remaining <= CHARS_PER_PAGE then
            pages[#pages + 1] = remaining
            break
        end
        -- find last space before the limit
        local cut = CHARS_PER_PAGE
        local sp = remaining:sub(1, cut):match(".*()%s")
        if sp and sp > 1 then
            cut = sp
        end
        pages[#pages + 1] = remaining:sub(1, cut)
        remaining = remaining:sub(cut + 1):match("^%s*(.*)$")
    end
    return #pages > 1 and pages or nil
end
-- Show the dialogue box + current background + choice/continue prompt.
-------------------------------------------------------------------------------
local function drawGame(state, interp)
    screen.clear(Color.new(0, 0, 0))

    -- background (scaled to fit the screen; src size defaults to texture size)
    if state.bg then
        pcall(function()
            Image.draw(state.bg, 0, 0, SCREEN_W, SCREEN_H, nil)
        end)
    end

    -- foreground character sprites (layered on top of the background)
    if state.sprites then
        for _, s in ipairs(state.sprites) do
            if s.img then
                pcall(function()
                    local sw = Image.W(s.img)
                    local sh = Image.H(s.img)
                    if not sw or not sh or sw <= 0 or sh <= 0 then return end
                    local dw, dh, x, y
                    if interp.isVNDS then
                        local sc = math.min(SCREEN_W / sw, SCREEN_H / sh)
                        dw = math.floor(sw * sc)
                        dh = math.floor(sh * sc)
                        local margin = 12
                        if s.x == "left" then
                            x = margin
                        elseif s.x == "right" then
                            x = SCREEN_W - dw - margin
                        elseif type(s.x) == "number" then
                            x = math.floor(s.x * SCREEN_W / 256)
                        else
                            x = math.floor((SCREEN_W - dw) / 2)
                        end
                        y = SCREEN_H - dh
                        if x < 0 then x = 0 end
                        if y < 0 then y = 0 end
                        if y + dh > SCREEN_H then y = SCREEN_H - dh end
                    else
                        -- Proper proportional scaling and positioning for NScripter / VNDS sprites
                        local scale = SCREEN_H / sh
                        dw = math.floor(sw * scale)
                        dh = math.floor(sh * scale)

                        if s.x == "left" then
                            x = math.floor(SCREEN_W * 0.20) - math.floor(dw / 2)
                        elseif s.x == "right" then
                            x = math.floor(SCREEN_W * 0.80) - math.floor(dw / 2)
                        elseif s.x == "center" then
                            x = math.floor((SCREEN_W - dw) / 2)
                        elseif type(s.x) == "number" then
                            if s.x <= 256 then
                                x = math.floor(s.x * SCREEN_W / 256)
                            else
                                x = math.floor(s.x * SCREEN_W / 480)
                            end
                        else
                            x = math.floor((SCREEN_W - dw) / 2)
                        end

                        if s.y and type(s.y) == "number" then
                            if s.y <= 192 then
                                y = math.floor(s.y * SCREEN_H / 192)
                            else
                                y = s.y
                            end
                        else
                            y = SCREEN_H - dh
                        end
                    end
                    Image.draw(s.img, x, y, dw, dh, nil)
                end)
            end
        end
    end

    -- dialogue box
    if state.windowVisible and state.text and state.text ~= "" then
        local fs = _G.fontScale or 1.25
        -- font color palette (index)
        local tcDefs = {
            { 255, 255, 255 }, { 255, 240, 170 }, { 255, 150, 120 },
            { 150, 220, 130 }, { 130, 210, 255 }, { 255, 180, 110 },
        }
        local col = tcDefs[(((_G.textColor or 1) - 1) % #tcDefs) + 1]
        -- box background color palette
        local boxDefs = {
            { 0, 0, 0 }, { 10, 10, 34 }, { 22, 28, 52 }, { 38, 38, 42 }, { 70, 28, 28 },
        }
        -- border color palette
        local brdDefs = {
            { 120, 140, 220 }, { 255, 255, 255 }, { 180, 210, 255 },
            { 255, 220, 120 }, { 255, 120, 120 }, { 120, 255, 160 },
        }
        local bc = boxDefs[(((_G.boxColor or 1) - 1) % #boxDefs) + 1]
        local brc = brdDefs[(((_G.borderColor or 1) - 1) % #brdDefs) + 1]
        local boxA = _G.boxAlpha or 180

        local boxTop = 186
        local boxH = 82
        if fs > 1.25 then
            -- taller box and adjusted baseline for larger fonts
            boxH = math.max(88, math.floor(70 * fs))
            boxTop = 272 - boxH - 4
        end
        screen.filledRect(10, boxTop, SCREEN_W - 20, boxH,
            Color.new(bc[1], bc[2], bc[3], boxA))
        screen.filledRect(10, boxTop, SCREEN_W - 20, 2, Color.new(brc[1], brc[2], brc[3]))
        screen.filledRect(10, boxTop + boxH - 2, SCREEN_W - 20, 2, Color.new(brc[1], brc[2], brc[3]))
        local shadowOn = (_G.textShadow ~= 0)
        if shadowOn then
            -- drop shadow offset by 2px for readability
            intraFont.printColumn(26, boxTop + 10, state.text, SCREEN_W - 48,
                Color.new(0, 0, 0), nil, fs, 0)
        end
        intraFont.printColumn(24, boxTop + 8, state.text, SCREEN_W - 48,
            Color.new(col[1], col[2], col[3]), nil, fs, 0)
        -- show ▼ if there are more pages OR as usual continue indicator
        intraFont.print(SCREEN_W - 36, SCREEN_H - 18, "▼", Color.new(200, 200, 255), nil, 0.8)
    end

    -- choices (Ren'Py-style: vertical list of buttons centered on screen,
    -- scrollable when there are more choices than fit on screen)
    if state.choices then
        local n = #state.choices
        local bw = SCREEN_W - 80
        local bx = 40
        local bh = 40
        local gap = 10
        local pitch = bh + gap
        local maxVisible = math.max(1, math.floor((SCREEN_H + 3) / pitch))
        -- keep a window of choices centered around the cursor when they overflow
        local start, shown
        if n <= maxVisible then
            start = 1
            shown = n
        else
            start = state.choiceCursor - math.floor((maxVisible - 1) / 2)
            if start < 1 then start = 1 end
            if start + maxVisible - 1 > n then start = n - maxVisible + 1 end
            shown = maxVisible
        end
        local totalH = shown * bh + (shown - 1) * gap
        local by = math.floor((SCREEN_H - totalH) / 2)
        local last = start + shown - 1
        for i = start, last do
            local c = state.choices[i]
            local cy = by + (i - start) * pitch
            local selc = (i == state.choiceCursor)
            -- button background + border (Ren'Py look)
            screen.filledRect(bx, cy, bw, bh,
                selc and Color.new(70, 90, 170) or Color.new(25, 25, 45))
            screen.filledRect(bx, cy, bw, 2, Color.new(150, 170, 255))
            screen.filledRect(bx, cy + bh - 2, bw, 2, Color.new(60, 70, 120))
            if selc then
                -- highlighted arrow on the left
                intraFont.print(bx + 10, cy + bh / 2 - 13, ">", Color.new(220, 230, 255), nil, 1.1)
            end
            intraFont.printColumn(bx + 28, cy + 11, c.label, bw - 40,
                Color.new(255, 255, 255), nil, 1.1, 0)
            if c.default then
                intraFont.print(bx + bw - 22, cy + 4, "*", Color.new(180, 200, 255), nil, 0.7)
            end
        end
        -- scroll indicators when there are hidden choices above/below
        if n > maxVisible then
            if start > 1 then
                intraFont.print(math.floor(SCREEN_W / 2) - 4, by - 12, "▲", Color.new(255, 210, 80), nil, 0.8)
            end
            if last < n then
                intraFont.print(math.floor(SCREEN_W / 2) - 4, by + totalH + 2, "▼", Color.new(255, 210, 80), nil, 0.8)
            end
        end
    end

    -- Persistent Auto indicator in the top right corner
    if _G.autoPlay then
        intraFont.print(SCREEN_W - 90, 14, i18n.t("auto_label"), Color.new(120, 255, 120), nil, 0.9)
    end

    -- small footer hint removed


end

-------------------------------------------------------------------------------
-- Show a fatal/diagnostic message on screen for a few seconds (so the user can
-- see why the engine bailed out instead of just being kicked to the menu).
-------------------------------------------------------------------------------
local function showFatal(msg)
    local t0 = os.time and os.time() or 0
    for _ = 1, 180 do
        buttons.read()
        screen.clear(Color.new(20, 0, 0))
        intraFont.print(16, 16, i18n.t("err_engine"), Color.new(255, 120, 120), nil, 1.1)
        intraFont.printColumn(16, 44, msg, SCREEN_W - 32, Color.new(255, 220, 220), nil, 0.85, 0)
        intraFont.print(16, SCREEN_H - 24, i18n.t("err_to_menu"), Color.new(200, 200, 255), nil, 0.8)
        screen.flip()
        if buttons.pressed(buttons.cross) or buttons.pressed(buttons.circle) then break end
        LUA.sleep(16)
    end
end

-------------------------------------------------------------------------------
-- Run the actual visual-novel game loop for a chosen novel.
-------------------------------------------------------------------------------
local function playNovel(novel)
    -- reset audio + state
    audio.stopAll()
    globalVars = globalVars or {}

    -- free any previously loaded GPU textures before (re)starting
    pcall(function()
        if _lastIt and _lastIt.clearImages then _lastIt:clearImages() end
    end)
    pcall(collectgarbage, "collect")

    local it = interp.new(novel.root, globalVars, novel.scriptDir)
    _lastIt = it
    it:start("main.scr")

    local state = {
        bg = nil,
        sprites = nil,
        text = nil,
        textPages = nil,   -- array of text pages for overflow
        textPage = 1,      -- current page index
        choices = nil,
        choiceCursor = 1,
        default = nil,
        windowVisible = true,
    }

    -- helper to sync interpreter visual state into `state`
    local function syncVisual()
        state.bg = it.bg
        state.sprites = it.sprites
        state.text = it.text
        state.windowVisible = it.windowVisible
    end

    while true do
        buttons.read()

        -- global shortcuts
        if buttons.pressed(buttons.triangle) then
            -- back to launcher (stop audio)
            audio.stopAll()
            pcall(function() it:clearImages() end)
            pcall(function() audio.closeLog() end)
            return
        elseif buttons.pressed(buttons.select) then
            local res = doPause(novel, it, state, syncVisual)
            if res == "exit" then return
            elseif res == "restart" then
                audio.stopAll()
                pcall(function() it:clearImages() end)
                pcall(function() audio.closeLog() end)
                return playNovel(novel)
            end
            syncVisual()
        elseif buttons.pressed(buttons.square) then
            doHistory(it)
        elseif buttons.pressed(buttons.l) then
            local loaded = doLoad(novel, it, state)
            if loaded then syncVisual() end
        end

        -- pending choice?
        if state.choices then
            doChoice(state, it)
            drawGame(state, it)
            screen.flip()
        else
            -- advance the script until we need to wait for the user
            state.text = nil          -- clear stale text so intermediate draws
                                     -- never flash the previous dialogue line
            local waiting = false
            local stepCount = 0
            while not waiting do
                local okStep, r = pcall(function() return it:step() end)
                stepCount = stepCount + 1
                if not okStep then
                    require("vnds.audio").dbg("STEP CRASH: " .. tostring(r) .. " at pc=" .. (it.pc or "?"))
                    audio.stopAll()
                    pcall(function() it:clearImages() end)
                    showFatal(i18n.t("err_step") .. tostring(r) .. i18n.t("err_in_file") .. tostring(it.curFile) .. " pc=" .. tostring(it.pc))
                    return
                end
                if r.finished then
                    audio.stopAll()
                    pcall(function() it:clearImages() end)
                    if it.error then
                        showFatal(i18n.t("err_finish") .. tostring(it.error)
                            .. i18n.t("err_in_file") .. tostring(it.curFile))
                    end
                    return
                elseif r.action == "text" and r.wait then
                    local txt = r.text or it.text
                    local pages = splitTextPages(txt)
                    if pages then
                        state.textPages = pages
                        state.textPage = 1
                        state.text = pages[1]
                    else
                        state.textPages = nil
                        state.textPage = 1
                        state.text = txt
                    end
                    waiting = true
                elseif r.action == "choice" then
                    state.choices = r.choices
                    state.choiceCursor = r.default or 1
                    state.default = r.default
                    waiting = true
                elseif r.action == "bgload" then
                    syncVisual()
                elseif r.action == "spriteload" or r.action == "spriteclear" then
                    syncVisual()
                elseif r.action == "windowhide" or r.action == "windowshow" then
                    syncVisual()
                    waiting = true
                elseif r.action == "delay" then
                    drawGame(state, it)
                    screen.flip()
                    pcall(function() LUA.sleep(math.min(r.ms or 0, 3000)) end)
                end
                -- yield to OS: after heavy ops OR every 32 steps to prevent
                -- watchdog resets during long logic chains (if/setvar/goto/jump)
                if r.action == "bgload" or r.action == "music" or r.action == "sound"
                   or stepCount % 32 == 0 then
                    pcall(function() System.PowerTick() end)
                end
                -- aggressive GC on PSP-1000 (32 MB): every bgload and every 16 steps
                if r.action == "bgload" or r.action == "spriteload"
                   or stepCount % 16 == 0 then
                    pcall(collectgarbage, "step", 50)
                end
            end

            -- wait for the user to press cross / circle to continue
            if not state.choices then
                -- Полностью убираем сложную и багованную анимацию печати текста,
                -- возвращаем стабильный вывод текста. При нажатии крестика/круга/R
                -- диалог штатно завершается без проскока реплик и скачков.
                drawGame(state, it)
                screen.flip()

                _G.autoPlay = _G.autoPlay or false
                local cont = false

                while not cont do
                    buttons.read()

                    if buttons.pressed(buttons.triangle) then
                        _G.autoPlay = not _G.autoPlay
                    elseif buttons.held(buttons.r) or buttons.pressed(buttons.cross) or buttons.pressed(buttons.circle) then
                        if state.textPages and state.textPage < #state.textPages then
                            state.textPage = state.textPage + 1
                            state.text = state.textPages[state.textPage]
                            drawGame(state, it)
                            screen.flip()
                        else
                            cont = true
                        end
                    elseif buttons.pressed(buttons.select) then
                        local res = doPause(novel, it, state, syncVisual)
                        if res == "exit" then return
                        elseif res == "restart" then
                            audio.stopAll()
                            pcall(function() it:clearImages() end)
                            pcall(function() audio.closeLog() end)
                            return playNovel(novel)
                        end
                        syncVisual()
                        drawGame(state, it)
                        screen.flip()
                    elseif buttons.pressed(buttons.square) then
                        doHistory(it)
                        drawGame(state, it)
                        screen.flip()
                    elseif buttons.pressed(buttons.l) then
                        local loaded = doLoad(novel, it, state)
                        if loaded then syncVisual() end
                        drawGame(state, it)
                        screen.flip()
                    elseif _G.autoPlay then
                        local pauseTime = (_G.autoReadDelay or 3) * 1000
                        local tStart = os.clock and (os.clock() * 1000) or 0
                        local interrupted = false
                        while (os.clock and (os.clock() * 1000) or 0) - tStart < pauseTime do
                            buttons.read()
                            if buttons.pressed(buttons.cross) or buttons.pressed(buttons.circle) or buttons.pressed(buttons.triangle) or buttons.held(buttons.r) or buttons.pressed(buttons.select) or buttons.pressed(buttons.square) then
                                interrupted = true
                                if buttons.pressed(buttons.triangle) then
                                    _G.autoPlay = not _G.autoPlay
                                end
                                break
                            end
                            LUA.sleep(10)
                        end
                        if not interrupted then
                            if state.textPages and state.textPage < #state.textPages then
                                state.textPage = state.textPage + 1
                                state.text = state.textPages[state.textPage]
                                drawGame(state, it)
                                screen.flip()
                            else
                                cont = true
                            end
                        else
                            if buttons.held(buttons.r) or buttons.pressed(buttons.cross) or buttons.pressed(buttons.circle) then
                                if state.textPages and state.textPage < #state.textPages then
                                    state.textPage = state.textPage + 1
                                    state.text = state.textPages[state.textPage]
                                    drawGame(state, it)
                                    screen.flip()
                                else
                                    cont = true
                                end
                            end
                        end
                    end

                    drawGame(state, it)
                    screen.flip()
                    LUA.sleep(buttons.held(buttons.r) and 1 or 16)
                end

                -- after a line is dismissed, clear the text box
                state.text = nil
                state.textPages = nil
                state.textPage = 1
            else
                -- a choice is pending: let the outer `if state.choices` handler
                -- take it (avoids consuming the selection press as "continue").
                drawGame(state, it)
                screen.flip()
            end
        end

        System.PowerTick()

        -- periodic diagnostics: texture cache size + voice channel (real signals)
        memTick = (memTick or 0) + 1
        if memTick % 40 == 0 then
            pcall(collectgarbage, "step", 150)
        end
    end
end

-------------------------------------------------------------------------------
-- Save flow: pick a slot (1..5), write state + screenshot.
-------------------------------------------------------------------------------
function doSave(novel, it, state)
    -- simple slot picker: use Up/Down to choose, Cross to confirm
    local slot = 1
    while true do
        buttons.read()
        if buttons.pressed(buttons.up) then slot = slot - 1; if slot < 1 then slot = 5 end end
        if buttons.pressed(buttons.down) then slot = slot + 1; if slot > 5 then slot = 1 end end
        if buttons.pressed(buttons.cross) then
            local st = it:saveState()
            -- io.open/write to Memory Stick can stall/crash on PSP;
            -- wrap everything so a failed save doesn't kill the game.
            pcall(function()
                save.write(novel.root, slot, st, novel.title)
            end)
            -- brief confirmation
            screen.clear(Color.new(0, 0, 0))
            intraFont.print(40, 130, i18n.t("saved_slot") .. slot, Color.new(120, 255, 120), nil, 1.2)
            screen.flip()
            LUA.sleep(600)
            return
        end
        if buttons.pressed(buttons.circle) or buttons.pressed(buttons.triangle) then
            return
        end
        screen.clear(Color.new(10, 10, 25))
        intraFont.print(20, 20, i18n.t("save_title"), Color.new(255, 255, 255), nil, 1.2)
        for s = 1, 5 do
            local y = 60 + (s - 1) * 30
            local isSel = (s == slot)
            screen.filledRect(40, y, 400, 26, isSel and Color.new(80, 100, 180) or Color.new(30, 30, 50))
            local label = i18n.t("slot") .. s .. (save.exists(novel.root, s) and i18n.t("taken") or "")
            intraFont.print(55, y + 2, label, Color.new(255, 255, 255), nil, 1.05)
        end
        intraFont.print(20, 238, i18n.t("ok_cancel"), Color.new(160, 160, 190), nil, 0.85)
        screen.flip()
        LUA.sleep(16)
    end
end

-------------------------------------------------------------------------------
-- Load flow.
-------------------------------------------------------------------------------
function doLoad(novel, it, state)
    local slot = 1
    while true do
        buttons.read()
        if buttons.pressed(buttons.up) then slot = slot - 1; if slot < 1 then slot = 5 end end
        if buttons.pressed(buttons.down) then slot = slot + 1; if slot > 5 then slot = 1 end end
        if buttons.pressed(buttons.cross) then
            if save.exists(novel.root, slot) then
                local st = save.read(novel.root, slot)
                if st then
                    local ok, err = pcall(function() it:restoreState(st) end)
                    if not ok then
                        -- corrupted save: show brief error, don't crash
                        screen.clear(Color.new(20, 0, 0))
                        intraFont.print(40, 130, i18n.t("load_err") .. tostring(err), Color.new(255, 120, 120), nil, 0.9)
                        screen.flip()
                        LUA.sleep(1200)
                        return false
                    end
                    return true
                end
            end
            return false
        end
        if buttons.pressed(buttons.circle) or buttons.pressed(buttons.triangle) then
            return false
        end
        screen.clear(Color.new(10, 10, 25))
        intraFont.print(20, 20, i18n.t("load_title"), Color.new(255, 255, 255), nil, 1.2)
        for s = 1, 5 do
            local y = 60 + (s - 1) * 30
            local isSel = (s == slot)
            screen.filledRect(40, y, 400, 26, isSel and Color.new(80, 100, 180) or Color.new(30, 30, 50))
            local label = i18n.t("slot") .. s .. (save.exists(novel.root, s) and i18n.t("taken") or i18n.t("empty"))
            intraFont.print(55, y + 2, label, Color.new(255, 255, 255), nil, 1.05)
        end
        intraFont.print(20, 238, i18n.t("ok_cancel"), Color.new(160, 160, 190), nil, 0.85)
        screen.flip()
        LUA.sleep(16)
    end
end

-------------------------------------------------------------------------------
-- Pause menu (opened with Select). Options: Save / Load / Main menu.
-------------------------------------------------------------------------------
function doPause(novel, it, state, syncVisual)
    local items = {
        { label = "act_save",  act = "save" },
        { label = "act_load",  act = "load" },
        { label = "act_menu",  act = "menu" },
    }
    local sel = 1
    while true do
        buttons.read()
        if buttons.pressed(buttons.up) then
            sel = ((sel - 2) % #items) + 1
        elseif buttons.pressed(buttons.down) then
            sel = (sel % #items) + 1
        elseif buttons.pressed(buttons.cross) then
            local a = items[sel].act
            if a == "save" then
                doSave(novel, it, state)
                return
            elseif a == "load" then
                local loaded = doLoad(novel, it, state)
                if loaded and syncVisual then syncVisual() end
                return
            elseif a == "menu" then
                audio.stopAll()
                pcall(function() it:clearImages() end)
                pcall(function() audio.closeLog() end)
                -- signal the caller to bail out of playNovel
                if _G.launcherMode == false then
                    return "restart"
                else
                    return "exit"
                end
            end
        elseif buttons.pressed(buttons.circle) or buttons.pressed(buttons.select) then
            return
        end
        screen.clear(Color.new(0, 0, 0))
        screen.filledRect(120, 70, 240, 150, Color.new(15, 15, 35))
        screen.filledRect(120, 70, 240, 2, Color.new(150, 170, 255))
        intraFont.print(180, 78, i18n.t("pause_title"), Color.new(255, 255, 255), nil, 1.2)
        for i, it2 in ipairs(items) do
            local y = 114 + (i - 1) * 34
            local selc = (i == sel)
            screen.filledRect(140, y, 200, 28,
                selc and Color.new(70, 90, 170) or Color.new(30, 30, 50))
            if selc then
                intraFont.print(146, y + 5, ">", Color.new(220, 230, 255), nil, 1.1)
            end
            intraFont.print(162, y + 6, i18n.t(it2.label), Color.new(255, 255, 255), nil, 1.05)
        end
        intraFont.print(130, 216, i18n.t("bt_select"), Color.new(160, 160, 190), nil, 0.85)
        screen.flip()
        LUA.sleep(16)
    end
end

-------------------------------------------------------------------------------
-- Choice handler. Navigation: L / R (dpad up/down also work on working pads).
-------------------------------------------------------------------------------
function doChoice(state, it)
    local n = #state.choices
    while true do
        buttons.read()
        if buttons.pressed(buttons.l) or buttons.pressed(buttons.up) then
            state.choiceCursor = ((state.choiceCursor - 2) % n) + 1
        elseif buttons.pressed(buttons.r) or buttons.pressed(buttons.down) then
            state.choiceCursor = (state.choiceCursor % n) + 1
        elseif buttons.pressed(buttons.cross) then
            it:choose(state.choiceCursor)
            state.choices = nil
            state.choiceCursor = 1
            return
        elseif buttons.pressed(buttons.circle) and state.default then
            it:choose(state.default)
            state.choices = nil
            state.choiceCursor = 1
            return
        end
        drawGame(state, it)
        screen.flip()
        LUA.sleep(16)
    end
end

-------------------------------------------------------------------------------
-- Dialogue backlog viewer (opened with Square). Scroll up/down with dpad.
-------------------------------------------------------------------------------
function doHistory(it)
    local hist = it:getHistory()
    if #hist == 0 then
        screen.clear(Color.new(0, 0, 0))
        intraFont.print(40, 130, i18n.t("hist_empty"), Color.new(200, 200, 220), nil, 1.0)
        screen.flip()
        LUA.sleep(700)
        return
    end
    local offset = 0  -- 0 = show newest at bottom
    local VISIBLE = 8
    while true do
        buttons.read()
        if buttons.pressed(buttons.up) then
            offset = offset + 1
            if offset > #hist - 1 then offset = #hist - 1 end
        elseif buttons.pressed(buttons.down) then
            offset = offset - 1
            if offset < 0 then offset = 0 end
        elseif buttons.pressed(buttons.cross) or buttons.pressed(buttons.circle)
            or buttons.pressed(buttons.square) then
            return
        end
        screen.clear(Color.new(0, 0, 0))
        screen.filledRect(10, 10, SCREEN_W - 20, SCREEN_H - 20, Color.new(10, 10, 25, 220))
        intraFont.print(24, 18, i18n.t("hist_title"), Color.new(255, 255, 255), nil, 1.2)
        intraFont.print(SCREEN_W - 170, 18, i18n.t("hist_back"), Color.new(160, 160, 190), nil, 1.0)
        local start = #hist - VISIBLE - offset + 1
        if start < 1 then start = 1 end
        local endI = start + VISIBLE - 1
        if endI > #hist then endI = #hist end
        for i = start, endI do
            local y = 48 + (i - start) * 32
            intraFont.printColumn(24, y, hist[i], SCREEN_W - 48,
                Color.new(230, 230, 255), nil, 1.0, 0)
        end
        screen.flip()
        LUA.sleep(16)
    end
end

-------------------------------------------------------------------------------
-- Engine entry point.
-------------------------------------------------------------------------------
function core.run()
    -- set a comfortable CPU clock
    pcall(function() scePowerSetClockFrequency(333, 333, 166) end)

    -- launch the XMB menu / launcher
    while true do
        local novel = menu.run(function(n) playNovel(n) end)
        if not novel then break end
        if _G.launcherMode == false then
            break
        end
    end
    pcall(function() LUA.exit() end)
end

return core
