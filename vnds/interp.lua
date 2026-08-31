-- ============================================================================
--  vnds/interp.lua
--  Interpreter for the ".scr" visual-novel script format (NScripter-like).
--
--  Commands understood:
--    bgload <file>            -- set background image (relative to novel dir)
--    text <string>            -- show dialogue text
--    sound <file> <mode>      -- play a voice/sfx (mode -1 once, 1 keep)
--    music <file>             -- play/stop background music ("~" stops)
--    setvar <name> <value>    -- set a local-ish variable
--    gsetvar <name> = <value> -- set a global variable (persists in save)
--    choice a|b|c             -- present choices, result in `selected`
--    jump <file>              -- jump to another script
--    if <cond> ... fi         -- conditional block (nestable)
--    label <name>             -- (optional) named label
--    goto <name>              -- (optional) jump to label
-- ============================================================================

local interp = {}

-------------------------------------------------------------------------------
-- Split a string on a literal separator, respecting quoted parts loosely.
-------------------------------------------------------------------------------
local function split(str, sep)
    local out = {}
    local pat = "[^" .. sep .. "]+"
    for piece in str:gmatch(pat) do
        out[#out + 1] = piece
    end
    return out
end

-------------------------------------------------------------------------------
-- Tokenize one command line: first word is the command, rest is the argument
-- (kept as a single string so quotes are preserved).
-------------------------------------------------------------------------------
-- Lua 5.1 compatible whitespace helpers (no %s / %S classes).
-------------------------------------------------------------------------------
local function trim(s)
    local a = s:match("^[ \t]*")
    local b = s:match("[ \t]*$")
    if a then s = s:sub(#a + 1) end
    if b then s = s:sub(1, #s - #b) end
    return s
end

local function parseLine(line)
    -- skip leading spaces/tabs (Saya-style indented if/label blocks)
    local cmd, arg = line:match("^[ \t]*([^ \t]+)[ \t]*(.*)$")
    if not cmd then return nil end
    arg = trim(arg)
    cmd = cmd:lower()
    -- Nscripter: *label_name → label label_name
    if cmd:sub(1, 1) == "*" then
        return "label", cmd:sub(2) .. (arg ~= "" and (" " .. arg) or "")
    end
    -- Nscripter: !sd, !s50, !w N, !w1000 → convert to dispatchable commands
    if cmd:sub(1, 1) == "!" then
        local inner = cmd:sub(2)
        if inner:sub(1, 1) == "w" then
            -- !w N or !wN (no space)
            local ms = inner:match("^w(.+)")
            if ms and ms ~= "" then
                return "wait", ms
            end
            return "wait", arg
        else
            return inner, arg
        end
    end
    return cmd, arg
end

-------------------------------------------------------------------------------
-- Evaluate a condition expression like "ending >= 1" or "selected == 2".
-- Lua 5.1 compatible (no %s class). Operators: == ~= >= <= > <
-------------------------------------------------------------------------------
local function evalCond(expr, vars)
    expr = trim(expr)
    -- capture name, operator, value (value is greedy up to end of line)
    local name, op, val = expr:match("^([%w_]+) *([=~><!]+) *(.+)$")
    if name and op and val then
        local a
        if tonumber(name) then
            a = tonumber(name)
        else
            a = vars[name]
            if a == nil then a = 0 end
        end
        local b
        if tonumber(val) then
            b = tonumber(val)
        else
            b = vars[val]
            if b == nil then b = val end
        end
        -- numeric compare when both sides are numbers
        local an, bn = tonumber(a), tonumber(b)
        if op == "==" then return (an or a) == (bn or b) end
        if op == "~=" or op == "!=" then return (an or a) ~= (bn or b) end
        if an and bn then
            if op == ">=" then return an >= bn end
            if op == "<=" then return an <= bn end
            if op == ">"  then return an >  bn end
            if op == "<"  then return an <  bn end
        end
    end
    -- bare variable: true when not nil/false/0/empty
    local v = vars[expr]
    if v == nil then v = 0 end
    return (v and v ~= 0 and v ~= "")
end

-------------------------------------------------------------------------------
-- Coerce a value (number when possible, else string).
-------------------------------------------------------------------------------
local function coerce(v)
    if tonumber(v) ~= nil then return tonumber(v) end
    if type(v) == "string" then
        if v:sub(1, 1) == '"' and v:sub(-1) == '"' then
            return v:sub(2, -2)
        end
    end
    return v
end

-------------------------------------------------------------------------------
-- Evaluate an expression (supports arithmetic +, -, *, /, random/rnd, variables).
-------------------------------------------------------------------------------
local function evalExpr(expr, vars)
    expr = trim(expr)
    if tonumber(expr) ~= nil then return tonumber(expr) end
    if expr:sub(1, 1) == '"' and expr:sub(-1) == '"' then
        return expr:sub(2, -2)
    end
    -- random / rnd function: random(min, max) or rnd(max)
    local rMin, rMax = expr:match("^random%s*%(%s*(%d+)%s*,%s*(%d+)%s*%)$")
    if not rMin then rMax = expr:match("^rnd%s*%(%s*(%d+)%s*%)$") end
    if rMax then
        if rMin then
            return math.random(tonumber(rMin), tonumber(rMax))
        else
            return math.random(0, tonumber(rMax) - 1)
        end
    end
    -- variable lookup
    if vars[expr] ~= nil then return vars[expr] end
    -- basic math evaluation if contains operators
    local a, op, b = expr:match("^([%w_]+)%s*([%+%-*/])%s*(.+)$")
    if a and op and b then
        local va = tonumber(vars[a]) or tonumber(a) or 0
        local vb = tonumber(vars[b]) or tonumber(b) or 0
        if op == "+" then return va + vb end
        if op == "-" then return va - vb end
        if op == "*" then return va * vb end
        if op == "/" then return vb ~= 0 and math.floor(va / vb) or 0 end
    end
    return expr
end

-------------------------------------------------------------------------------
-- Substitute {$var} occurrences in a string with the variable's value.
-- Used by Nscripter-style scripts (e.g. jump main-ep{$ep}.scr).
-------------------------------------------------------------------------------
function interp:subst(s)
    if not s then return s end
    -- Replace {$var} / {var} with the variable's value.
    -- Implemented manually (no gsub/capture) for maximum compatibility
    -- with the Lua build used by this engine.
    local res = ""
    local i = 1
    local n = #s
    while i <= n do
        local oc = s:find("{", i)   -- '{' is not a magic pattern char -> literal
        if not oc then
            res = res .. s:sub(i)
            break
        end
        res = res .. s:sub(i, oc - 1)
        local cc = s:find("}", oc + 1)
        if not cc then
            res = res .. s:sub(oc)
            break
        end
        local inner = s:sub(oc + 1, cc - 1)
        -- variable name: strip an optional leading '$'
        local key = inner
        if key:sub(1, 1) == "$" then key = key:sub(2) end
        key = trim(key)
        local v = self.vars[key]
        if v ~= nil then
            res = res .. tostring(v)
        else
            res = res .. ""
        end
        i = cc + 1
    end
    return res
end

-------------------------------------------------------------------------------
-- Create a new interpreter state bound to a novel directory root.
-- root: absolute path to the novel folder (e.g. "novels/Saya/")
-- vars: shared variable table (persists across scripts / saves)
-------------------------------------------------------------------------------
function interp.new(root, vars, scriptDir)
    -- script folder: "script" (Nscripter) or "Scripts" (VNDS/Vita)
    local sd = scriptDir
    if not sd then
        if System.isDir(root .. "Scripts") then sd = "Scripts"
        elseif System.isDir(root .. "script") then sd = "script"
        else sd = "script" end
    end
    -- load persistent gsetvar from disk (survives app restarts)
    local gPath = root .. "saves" .. "/" .. "global.vnds"
    local gVars = {}
    pcall(function()
        local f = io.open(gPath, "r")
        if f then
            for line in f:lines() do
                local k, v = line:match("^(.-)=(.*)$")
                if k then gVars[k] = tonumber(v) or v end
            end
            f:close()
        end
    end)
    -- merge gsetvar globals into vars (globals override locals)
    for k, v in pairs(gVars) do vars[k] = v end

    local self = {
        root = root,
        _gPath = gPath,
        scriptDir = sd .. "/",
        isVNDS = true,
        vars = vars or {},
        scriptCache = {},   -- filename -> array of lines
        pc = 0,             -- program counter (1-based index into lines)
        lines = nil,        -- current script lines
        curFile = nil,
        bg = nil,           -- current background image object
        bgName = nil,
        imageCache = {},    -- path -> loaded Image
        cacheOrder = {},    -- LRU: array of paths, oldest first
        sprites = {},       -- foreground character sprites (layered)
        text = nil,           -- current dialogue text
        textMode = nil,       -- "@" system / "!" wait / normal / nil
        choices = nil,        -- pending choice list
        selected = nil,
        finished = false,
        history = {},         -- backlog of spoken lines (session-only)
        windowVisible = true, -- dialogue box visibility (window show/hide)
    }
    return setmetatable(self, { __index = interp })
end

-------------------------------------------------------------------------------
-- Load a script file into the cache (returns array of trimmed lines).
-------------------------------------------------------------------------------
function interp:loadScript(file)
    if self.scriptCache[file] then return self.scriptCache[file] end
    
    local candidatePaths = {
        self.root .. self.scriptDir .. file,
        self.root .. "script/" .. file,
        self.root .. "Scripts/" .. file,
        self.root .. file,
        self.root .. "script/" .. file:lower(),
        self.root .. "Scripts/" .. file:lower(),
    }
    local base, ext = file:match("^(.*)%.(%w+)$")
    if base and ext then
        candidatePaths[#candidatePaths + 1] = self.root .. self.scriptDir .. base .. "." .. ext:upper()
        candidatePaths[#candidatePaths + 1] = self.root .. "script/" .. base .. "." .. ext:lower()
        candidatePaths[#candidatePaths + 1] = self.root .. "Scripts/" .. base .. "." .. ext:lower()
    end

    local path = nil
    for _, cp in ipairs(candidatePaths) do
        if System.isFile(cp) then
            path = cp
            break
        end
    end

    -- If still not found, do a safe directory scan wrapped in pcall
    if not path then
        for _, sDir in ipairs({ self.scriptDir, "script/", "Scripts/", "" }) do
            local dirScanPath = self.root .. sDir
            local okList, list = pcall(function() return System.listDir(dirScanPath) end)
            if okList and list then
                for _, entry in ipairs(list) do
                    if entry.name and entry.name:lower() == file:lower() then
                        path = dirScanPath .. entry.name
                        break
                    end
                end
            end
            if path then break end
        end
    end

    if not path then
        return nil, "скрипт не найден: " .. self.root .. self.scriptDir .. file
    end
    pcall(function() System.PowerTick() end)
    local okDump, dump = pcall(function() return System.fileDumpCreate(path) end)
    if not okDump or not dump then return nil, "cannot read: " .. path end
    local count = dump.linesCount
    local handle = dump.pointer
    local lines = {}
    for i = 1, count do
        local okLine, l = pcall(function() return System.fileDumpGetLine(handle, i) end)
        if l then
            l = l:gsub("\r", "")
            if l ~= "" and l:sub(1, 1) ~= ";" then
                lines[#lines + 1] = l
            end
        end
        -- yield every 256 lines so the OS stays alive during large file reads
        if i % 256 == 0 then
            pcall(function() System.PowerTick() end)
        end
    end
    System.fileDumpRemove(handle, count)
    self.scriptCache[file] = lines
    return lines
end

-------------------------------------------------------------------------------
-- Jump to another script (or restart current file). Keeps variable state.
-------------------------------------------------------------------------------
function interp:jump(file, targetLabel)
    pcall(function() System.PowerTick() end)
    -- stop voice channels before script switch to prevent audio channel
    -- conflicts (the new script may start playing different voices immediately)
    pcall(function() require("vnds.audio").stopAllVoice() end)
    local lines, err = self:loadScript(file)
    if not lines then
        self.finished = true
        self.error = err
        return
    end
    self.lines = lines
    self.curFile = file
    self.pc = 1

    -- PSP-1000 (32 MB): free all cached scripts except the current one to save RAM
    self.scriptCache = { [file] = lines }
    pcall(collectgarbage, "step", 50)

    if targetLabel then
        self:gotoLabel(targetLabel)
    end

    -- auto-play opening.pmp on first r01.scr load
    if file:lower():match("r01%.scr$") and not self._openingPlayed then
        self._openingPlayed = true
        local oPath = self.root .. "background/output_saya.pmp"
        if System.isFile(oPath) then
            pcall(function() require("vnds.audio").stopAll() end)
            LUA.sleep(100)
            pcall(function() PMP.play(oPath, nil, nil, nil, buttons.cross) end)
            pcall(function()
                screen.clear(Color.new(0, 0, 0))
                screen.flip()
                screen.clear(Color.new(0, 0, 0))
                screen.flip()
            end)
            LUA.sleep(200)
        end
    end
end

-------------------------------------------------------------------------------
-- Begin execution at a script file.
-------------------------------------------------------------------------------
function interp:start(file)
    self:jump(file)
end

-------------------------------------------------------------------------------
-- Find the matching `fi` for an `if` at index i, accounting for nesting.
-- Returns the index of the fi line, or nil.
-------------------------------------------------------------------------------
local function findFi(lines, i)
    local depth = 1
    for j = i + 1, #lines do
        local first = lines[j]:match("^[ \t]*([^ \t]+)")
        if first then
            local cmd = first:lower()
            if cmd == "if" then
                depth = depth + 1
            elseif cmd == "fi" then
                depth = depth - 1
                if depth == 0 then return j end
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Advance the interpreter by ONE command, performing its effect.
-- Returns a status table describing what happened, or {wait=true} when the
-- engine should pause and let the user read/click.
--
-- The engine calls this in a loop. Text commands set self.text and return
-- {wait=true} so the caller shows the line and waits for a button press.
-------------------------------------------------------------------------------
function interp:step()
    if self.finished then return {finished = true} end
    if not self.lines or self.pc > #self.lines then
        self.finished = true
        return {finished = true}
    end

    -- Guard against runaway loops (e.g. missing fi/label). Blank lines are
    -- pre-filtered by loadScript so the loop is now much faster.
    local guard = 0
    while true do
        guard = guard + 1
        if guard > 10000 then
            self.finished = true
            self.error = "слишком много неизвестных строк подряд"
            return {finished = true}
        end

        if self.pc > #self.lines then
            self.finished = true
            return {finished = true}
        end

        local raw = self.lines[self.pc]
        self.pc = self.pc + 1

        if require("vnds.audio").DEBUG then
            require("vnds.audio").dbg("STEP [" .. (self.curFile or "?") .. ":" .. (self.pc - 1) .. "] " .. raw:sub(1, 80))
        end

        local cmd, arg = parseLine(raw)
        if cmd then
            return self:dispatch(cmd, arg)
        end
        -- unknown line: try next
    end
end

-------------------------------------------------------------------------------
-- Dispatch a parsed command. Split out from step() so step() can loop over
-- blank/skipped lines without recursing.
-------------------------------------------------------------------------------
function interp:dispatch(cmd, arg)
    -- Track consecutive setimg for expression/pose changes.
    -- A setimg after another setimg ADDS a sprite (multi-character scenes).
    -- A setimg after bgload or text REPLACES the last sprite (expression change).
    if cmd ~= "setimg" and cmd ~= "spriteload" and cmd ~= "cg" then
        self._lastCmd = nil
    end
    if cmd == "bgload" then
        -- free Lua garbage before heavy VRAM allocation to avoid OOM on PSP
        pcall(collectgarbage, "step", 100)
        pcall(function() System.PowerTick() end)
        -- Nscripter: bgload file.jpg,N (strip transition speed parameter)
        local bgarg = self:subst(arg):match("^([^,]+)")
        self:setBackground(bgarg)
        pcall(collectgarbage, "step", 50)
        return {action = "bgload"}

    elseif cmd == "spriteload" or cmd == "cg" or cmd == "setimg" then
        pcall(function() System.PowerTick() end)
        -- setimg <file> [at] [left|right/center/num] [y]  (Nscripter: setimg file x y)
        -- Substitute {$var} first (e.g. dynamic sprite names).
        local sarg = self:subst(arg)
        local rest = sarg:match("^([^ \t]+)[ \t]*(.*)$")
        local name = rest or sarg
        local tail = (rest and sarg:sub(#rest + 1)) or ""
        -- drop a leading "at"
        tail = tail:gsub("^[ \t]*at[ \t]*", "")
        local pos = tail:match("^[ \t]*(%w+)[ \t]*")
        local ynum = tail:match("(%d+)%s*$")
        local px = "center"
        if pos then
            local p = pos:lower()
            if p == "left" or p == "right" or p == "center" then
                px = p
            else
                local n = tonumber(pos)
                if n then px = n end
            end
        end
        self:addSprite(name, px, ynum and tonumber(ynum) or nil)
        return {action = "spriteload"}

    elseif cmd == "spriteclear" or cmd == "cgclear" or cmd == "clrimg" or cmd == "cl" then
        self:clearSprites()
        return {action = "spriteclear"}

    elseif cmd == "windowhide" or cmd == "window hide" then
        self.windowVisible = false
        return {action = "windowhide"}

    elseif cmd == "windowshow" or cmd == "window show" then
        self.windowVisible = true
        return {action = "windowshow"}

    elseif cmd == "music" then
        pcall(function() System.PowerTick() end)
        local ok, err = self:playMusic(self:subst(arg))
        if not ok and err then self.lastAudioError = err end
        return {action = "music"}

    elseif cmd == "sound" then
        pcall(function() System.PowerTick() end)
        local sarg = self:subst(arg)
        local file, mode = sarg:match("^(%S+)%s*(.-)$")
        mode = tonumber(mode) or -1
        self:playSound(file, mode)
        return {action = "sound"}

    elseif cmd == "text" then
        return self:doText(arg)

    elseif cmd == "cleartext" then
        self.text = nil
        self.textMode = nil
        return {action = "text-clear"}

    elseif cmd == "delay" then
        local ms = tonumber((arg or ""):match("^(%d+)")) or 0
        return {action = "delay", ms = ms}

    elseif cmd == "setvar" or cmd == "gsetvar" or cmd == "mov" then
        -- Supports: setvar name = val, setvar name val, mov %name,val, setvar name += val
        local name, op, val
        if cmd == "mov" then
            name, val = arg:match("^%%?(%S+)%s*,%s*(.+)$")
            op = "="
        else
            name, op, val = arg:match("^(%S+)%s*([%+%-*/]?=)%s*(.-)$")
            if not name then
                name, val = arg:match("^(%S+)%s+(.-)$")
                op = "="
            end
        end
        if name then
            if name == "~" then
                self.vars = {}
                pcall(function()
                    local f = io.open(self._gPath, "r")
                    if f then
                        for line in f:lines() do
                            local k, v = line:match("^(.-)=(.*)$")
                            if k then self.vars[k] = tonumber(v) or v end
                        end
                        f:close()
                    end
                end)
            else
                val = trim(val or "")
                local rhs = evalExpr(val, self.vars)
                local curVal = self.vars[name] or 0
                local v = rhs
                if op == "+=" then v = (tonumber(curVal) or 0) + (tonumber(rhs) or 0)
                elseif op == "-=" then v = (tonumber(curVal) or 0) - (tonumber(rhs) or 0)
                elseif op == "*=" then v = (tonumber(curVal) or 0) * (tonumber(rhs) or 0)
                elseif op == "/=" then
                    local denom = (tonumber(rhs) or 1)
                    v = denom ~= 0 and math.floor((tonumber(curVal) or 0) / denom) or 0
                end
                self.vars[name] = coerce(v)
                if cmd == "gsetvar" then
                    pcall(function()
                        pcall(function() System.createDir(self.root .. "saves") end)
                        local f = io.open(self._gPath, "r")
                        local lines = {}
                        if f then
                            for line in f:lines() do
                                local k = line:match("^(.-)=")
                                if k and k ~= name then lines[#lines + 1] = line end
                            end
                            f:close()
                        end
                        lines[#lines + 1] = name .. "=" .. tostring(self.vars[name])
                        local wf = io.open(self._gPath, "w")
                        if wf then
                            wf:write(table.concat(lines, "\n"))
                            wf:close()
                        end
                    end)
                end
            end
        end
        return {action = "setvar"}

    elseif cmd == "choice" then
        return self:doChoice(arg)

    elseif cmd == "jump" then
        local targetArg = self:subst(arg)
        -- VNDS / Nscripter jump supports optional label: jump file.scr label_name
        local jFile, jLab = targetArg:match("^(%S+)%s+(%S+)$")
        if not jFile then jFile = targetArg:match("^(%S+)") end
        if jLab and jLab:sub(1, 1) == "*" then jLab = jLab:sub(2) end
        self:jump(jFile, jLab)
        return {action = "jump"}

    elseif cmd == "video" then
        -- video <file> — plays PMP with cross to skip
        pcall(function() System.PowerTick() end)
        local vfile = self:subst(arg):match("^(%S+)")
        if vfile then
            local vpath = self.root .. vfile
            if not System.isFile(vpath) then
                vpath = self.root .. "novels/" .. vfile
            end
            if System.isFile(vpath) then
                pcall(function() require("vnds.audio").stopAll() end)
                LUA.sleep(100)
                pcall(function() PMP.play(vpath, nil, nil, nil, buttons.cross) end)
                pcall(function()
                    screen.clear(Color.new(0, 0, 0))
                    screen.flip()
                    screen.clear(Color.new(0, 0, 0))
                    screen.flip()
                end)
                LUA.sleep(200)
            end
        end
        return {action = "video"}

    elseif cmd == "if" then
        if evalCond(arg, self.vars) then
            return {action = "if-true"}
        else
            local fi = findFi(self.lines, self.pc - 1)
            if fi then
                self.pc = fi + 1
            else
                -- no matching fi: skip to end of script rather than loop forever
                self.pc = #self.lines + 1
                self.error = "if без fi: " .. arg
            end
            return {action = "if-false"}
        end

    elseif cmd == "fi" then
        return {action = "fi"}

    elseif cmd == "label" then
        return {action = "label"}

    elseif cmd == "gotoLabel" or cmd == "goto" then
        return self:gotoLabel(arg)

    elseif cmd == "wait" then
        -- Nscripter: wait N (milliseconds)
        local ms = tonumber(arg:match("^(%d+)")) or 0
        return {action = "delay", ms = ms}

    elseif cmd == "erasetextwindow" or cmd == "textclear" or cmd == "tclear" then
        local val = tonumber(arg:match("^(%d+)")) or 0
        if cmd == "erasetextwindow" then
            self.windowVisible = (val == 0)
        else
            self.text = nil
            self.textMode = nil
        end
        return {action = "text-clear"}

    elseif cmd == "stop" or cmd == "doggestop" or cmd == "doggeloop"
        or cmd == "mp3fadeout" or cmd == "setwindow" or cmd == "textbtn"
        or cmd == "btndef" or cmd == "caption" or cmd == "version"
        or cmd == "game" or cmd == "quad" or cmd == "effect"
        or cmd == "defsub" or cmd == "return" or cmd == "gosub"
        or cmd == "selectcolor" or cmd == "nsa" or cmd == "humanorder"
        or cmd == "luacall" or cmd == "blt" or cmd == "print"
        or cmd == "strsp" or cmd == "lsph" or cmd == "lsp"
        or cmd == "csp" or cmd == "vsp" or cmd == "ld"
        or cmd == "sd" or cmd:match("^s%d") then
        -- Nscripter / VNDS: extended or no-op/handled commands
        return {action = "unknown", cmd = cmd}

    elseif cmd == "mp3" then
        -- Nscripter: mp3 filename (same as music)
        pcall(function() System.PowerTick() end)
        local ok, err = self:playMusic(self:subst(arg))
        if not ok and err then self.lastAudioError = err end
        return {action = "music"}

    elseif cmd == "click" then
        -- Nscripter: click (wait for click)
        return {action = "text", wait = true, keep = true}

    else
        -- unknown command: ignore
        return {action = "unknown", cmd = cmd}
    end
end

-------------------------------------------------------------------------------
-- Helper for jumping to labeled script points
-------------------------------------------------------------------------------
function interp:gotoLabel(arg)
    local target = self:subst(arg):match("^(%S+)")
    if target and target:sub(1, 1) == "*" then target = target:sub(2) end
    local found = false
    for i = 1, #self.lines do
        local c, a = parseLine(self.lines[i])
        if c == "label" and a == target then
            self.pc = i + 1
            found = true
            break
        end
    end
    if not found then
        self.error = "goto: метка не найдена: " .. tostring(target)
    end
    return {action = "goto"}
end

-------------------------------------------------------------------------------
-- Handle a `text` command. Modes:
--   text ~            -> clear the text box (no wait)
--   text @something   -> system/narration line (shown, waits)
--   text !            -> advance marker (waits for click, no new text)
--   text "quoted"     -> exact string
--   text something    -> normal dialogue line (waits)
-------------------------------------------------------------------------------
function interp:doText(arg)
    arg = arg or ""
    if arg == "~" then
        self.text = nil
        self.textMode = nil
        return {action = "text-clear"}
    end
    if arg == "!" then
        -- wait-for-click marker; keep current text visible
        return {action = "text", wait = true, keep = true}
    end
    local mode = nil
    local body = arg
    if body:sub(1, 1) == "@" then
        mode = "@"
        body = body:sub(2)
    end
    -- strip surrounding quotes if present
    if body:sub(1, 1) == '"' and body:sub(-1) == '"' then
        body = body:sub(2, -2)
    end
    -- trim whitespace (VNDS indents text heavily)
    body = trim(body)
    -- drop a trailing backslash (VNDS soft line-break marker)
    if body:sub(-1) == "\\" then body = trim(body:sub(1, -2)) end
    self.text = body
    self.textMode = mode
    -- record into backlog (skip empty / duplicate consecutive lines)
    if body and body ~= "" then
        local h = self.history
        if #h == 0 or h[#h] ~= body then
            h[#h + 1] = body
            if #h > 100 then table.remove(h, 1) end
        end
    end
    return {action = "text", wait = true, text = body, mode = mode}
end

-------------------------------------------------------------------------------
-- Background handling. `bgload title.jpg` or `bgload cg/03_1.jpg`.
-- The file may live under background/ or be given with a subfolder.
-------------------------------------------------------------------------------
-- Image cache: load each file at most once and reuse the texture. This avoids
-- the VRAM leak that happened when every bgload/spriteload called Image.load
-- + Image.unload on the PSP (unload did not free memory promptly).
-------------------------------------------------------------------------------
-- Maximum cached textures before oldest are evicted. Each 480x272 RGBA
-- texture costs ~520 KB; on PSP-1000 (32 MB total) keep it small.
local IMG_CACHE_MAX = 6

function interp:getImage(path)
    if self.imageCache[path] then
        -- touch LRU: move to end of cacheOrder
        local order = self.cacheOrder
        for i = 1, #order do
            if order[i] == path then
                table.remove(order, i)
                break
            end
        end
        order[#order + 1] = path
        return self.imageCache[path]
    end
    -- evict oldest if cache is full
    local order = self.cacheOrder
    local evictAttempts = 0
    while #order >= IMG_CACHE_MAX and evictAttempts < IMG_CACHE_MAX do
        evictAttempts = evictAttempts + 1
        local oldPath = order[1]
        local oldImg = self.imageCache[oldPath]
        if oldImg and oldPath ~= self.bgName then
            local inUse = false
            -- check if oldImg is current background
            if self.bg == oldImg then inUse = true end
            -- check if oldImg is in active sprites
            if not inUse and self.sprites then
                for _, sp in ipairs(self.sprites) do
                    if sp.img == oldImg then inUse = true; break end
                end
            end
            if not inUse then
                table.remove(order, 1)
                pcall(function() Image.unload(oldImg) end)
                self.imageCache[oldPath] = nil
                pcall(collectgarbage, "step", 20)
            else
                table.remove(order, 1)
                order[#order + 1] = oldPath
            end
        else
            table.remove(order, 1)
            order[#order + 1] = oldPath
        end
    end
    pcall(function() System.PowerTick() end)
    local ok, img = pcall(function() return Image.load(path) end)
    if ok and img then
        self.imageCache[path] = img
        order[#order + 1] = path
        return img
    end
    return nil
end

function interp:setBackground(raw)
    -- Nscripter allows an optional fade argument: bgload file.jpg 60
    local name = (raw or ""):match("^(%S+)") or raw
    if not name or name == "" or name == "~" then
        self.bg = nil
        self.bgName = nil
        self:clearSprites()
        return
    end
    -- a new background replaces the previous scene: drop character sprites
    self:clearSprites()
    -- try several candidate locations
    local candidates = {
        self.root .. "background/" .. name,
        self.root .. name,
        self.root .. "background/cg/" .. (name:match("^cg/(.+)$") or name),
        self.root .. "CG/" .. name,
        self.root .. "CGAlt/" .. name,
        self.root .. "cg/" .. name,
    }
    local found
    for _, c in ipairs(candidates) do
        if System.isFile(c) then found = c; break end
    end
    if not found then
        self.lastBgError = "фон не найден: " .. name
        return
    end
    -- reuse a cached texture so we never leak VRAM on repeated bgload
    local img = self:getImage(found)
    if img then
        self.bg = img
        self.bgName = name
    end
end

-------------------------------------------------------------------------------
-- Foreground character sprites. `setimg sprite0056.png 10 0` adds a sprite.
-- The script provides DS coordinates (256x192 canvas); core.lua scales them
-- to PSP (480x272). Multi-character scenes use different x values set by
-- the scriptwriters — we NEVER override them.
--
-- Consecutive setimg (no text/bgload between) = multi-character scene, both
-- sprites coexist. setimg after text = expression change, replaces last sprite.
-------------------------------------------------------------------------------
function interp:addSprite(name, x, y)
    if not name or name == "" or name == "~" then return end
    local candidates = {
        self.root .. "foreground/" .. name,
        self.root .. name,
        self.root .. "foreground/" .. (name:match("^cg/(.+)$") or name),
        self.root .. "CG/" .. name,
        self.root .. "CGAlt/" .. name,
        self.root .. "cg/" .. name,
    }
    local found
    for _, c in ipairs(candidates) do
        if System.isFile(c) then found = c; break end
    end
    if not found then
        self.lastSpriteError = "спрайт не найден: " .. name
        return
    end
    -- Expression/pose change: if the previous command was NOT setimg (i.e.
    -- bgload or text separated them), the character's expression changed —
    -- replace the last sprite. Consecutive setimg commands ADD sprites
    -- (multi-character scenes like r01.scr L249-L250).
    if self._lastCmd ~= "setimg" and #self.sprites > 0 then
        table.remove(self.sprites, #self.sprites)
    end
    self._lastCmd = "setimg"
    local img = self:getImage(found)
    if img then
        self.sprites[#self.sprites + 1] = {img = img, x = x, y = y, name = name}
    end
end

function interp:clearSprites()
    -- sprites reference cached textures; just drop the references (no unload)
    self.sprites = {}
end

-------------------------------------------------------------------------------
-- Unload every cached texture (called when leaving the novel).
-------------------------------------------------------------------------------
function interp:clearImages()
    for _, img in pairs(self.imageCache) do
        pcall(function() Image.unload(img) end)
    end
    self.imageCache = {}
    self.cacheOrder = {}
    self.sprites = {}
    self.bg = nil
    self.bgName = nil
    pcall(collectgarbage, "collect")
end

-------------------------------------------------------------------------------
-- Music handling.
-------------------------------------------------------------------------------
function interp:playMusic(name)
    local audio = require("vnds.audio")
    if not name or name == "~" or name == "" then
        self.curMusic = nil
        audio.dbg("MUSIC stop")
        return audio.playBGM(nil)
    end
    -- remember the original name so save/load can restore it
    self.curMusic = name
    -- music paths may be "music/s02.mp3" (Saya) or just "lsys20.mp3" (Higurashi /
    -- Lunar Princess). Resolve candidates through audio.resolvePath so the
    -- .mp3 / .aac originals are remapped to the playable .ogg/.wav forms
    -- we ship alongside them.
    local base = name:match("^music/(.+)$") or name
    local cand = {
        name,
        self.root .. name,
        self.root .. "sound/" .. name,
        self.root .. "sound/music/" .. base,
        self.root .. "music/" .. base,
    }
    local path
    for _, c in ipairs(cand) do
        if c and audio.resolvePath(c) then path = c; break end
    end
    path = path or (self.root .. name)
    audio.dbg("MUSIC req=", name, "-> path=", path, "root=", self.root)
    return audio.playBGM(path)
end

-------------------------------------------------------------------------------
-- Voice / sfx handling.
-------------------------------------------------------------------------------
function interp:playSound(name, mode)
    local audio = require("vnds.audio")
    if not name or name == "~" or name == "" then
        audio.dbg("SOUND stop")
        audio.stopAllVoice()
        return
    end
    -- Try extended candidate bases including voices/ subfolders
    local bases = {
        name,
        self.root .. name,
        self.root .. "sound/" .. name,
        self.root .. "sound/voices/" .. name,
        self.root .. "voices/" .. name,
        self.root .. "sound/voice/" .. name,
        self.root .. "voice/" .. name,
        "sound/" .. name,
        "sound/voices/" .. name,
        "voices/" .. name,
    }
    local path
    for _, b in ipairs(bases) do
        if audio.resolvePath(b) then path = b; break end
    end
    path = path or name
    audio.dbg("SOUND req=", name, "-> path=", path, "root=", self.root, "mode=", mode)
    audio.playVoice(path, mode)
end

-------------------------------------------------------------------------------
-- Present a choice. Two syntaxes are supported:
--   choice A|B|C                      -- plain labels, result in `selected`
--   choice A > a.scr | B > b.scr | * C -- `>` jumps to a script; `*` marks the
--                                         default (auto-selected on timeout)
-- Each side may also carry a hint after a second `|`:
--   choice A > a.scr | Help text       -> {label, target?, hint?}
-- The result table is cached so the engine can render it directly.
-------------------------------------------------------------------------------
function interp:doChoice(arg)
    local choices = {}
    for part in arg:gmatch("[^|]+") do
        local raw = trim(part)
        local label, rest = raw:match("^(.-)%s*>%s*(.*)$")
        local target, hint
        if rest then
            target, hint = rest:match("^(%S+)%s*(.*)$")
            if hint == "" then hint = nil end
        else
            label = raw
        end
        local isDefault = false
        if label:sub(1, 1) == "*" then
            isDefault = true
            label = trim(label:sub(2))
        end
        -- strip wrapping quotes (VNDS uses "label")
        if label:sub(1, 1) == '"' and label:sub(-1) == '"' then
            label = label:sub(2, -2)
        end
        local entry = {label = label, target = target, hint = hint, default = isDefault}
        choices[#choices + 1] = entry
    end
    self.choices = choices
    self.choiceDefault = nil
    for i, c in ipairs(choices) do
        if c.default then self.choiceDefault = i; break end
    end
    return {action = "choice", choices = choices, default = self.choiceDefault}
end

-------------------------------------------------------------------------------
-- Apply a choice selection (called by the engine after the user picks).
-------------------------------------------------------------------------------
function interp:choose(index)
    local list = self.choices
    self.selected = index
    self.vars.selected = index
    self.choices = nil
    self.choiceDefault = nil
    if list and list[index] and list[index].target then
        -- jump straight to the branch's script
        self:jump(list[index].target)
    end
end

-------------------------------------------------------------------------------
-- Serialize the current execution state for saving.
-------------------------------------------------------------------------------
function interp:saveState()
    local sprites = {}
    for _, s in ipairs(self.sprites or {}) do
        sprites[#sprites + 1] = { name = s.name, x = s.x, y = s.y }
    end
    return {
        curFile = self.curFile,
        pc = self.pc,
        bgName = self.bgName,
        text = self.text,
        textMode = self.textMode,
        selected = self.selected,
        vars = self.vars,
        sprites = sprites,
        curMusic = self.curMusic,
    }
end

-------------------------------------------------------------------------------
-- Return the dialogue backlog (list of strings, oldest first).
-------------------------------------------------------------------------------
function interp:getHistory()
    return self.history or {}
end

function interp:restoreState(s)
    if not s then return end
    self.vars = s.vars or self.vars
    -- deep-copy vars so save data and interpreter don't share the same table
    -- (corrupted shared state was a source of post-load crashes)
    if s.vars then
        local copy = {}
        for k, v in pairs(s.vars) do copy[k] = v end
        self.vars = copy
    end
    self.error = nil
    self.finished = false
    self.choices = nil
    self.choiceDefault = nil
    if s.curFile then
        -- load the script lines directly (jump() no longer clears the cache,
        -- so this is a cheap operation that keeps loaded textures alive)
        local lines = self:loadScript(s.curFile)
        if lines then
            self.lines = lines
            self.curFile = s.curFile
            self.pc = s.pc or 1
        else
            self:jump(s.curFile)
            self.pc = s.pc or 1
        end
    end
    self.bgName = s.bgName
    if s.bgName then pcall(function() self:setBackground(s.bgName) end) end
    -- restore character sprites
    self.sprites = {}
    if s.sprites then
        for _, sp in ipairs(s.sprites) do
            pcall(function() self:addSprite(sp.name, sp.x, sp.y) end)
        end
    end
    -- restore background music
    if s.curMusic then pcall(function() self:playMusic(s.curMusic) end) end
    self.text = s.text
    self.textMode = s.textMode
    self.selected = s.selected
end

return interp
