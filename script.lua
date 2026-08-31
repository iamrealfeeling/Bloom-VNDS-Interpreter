-- ============================================================================
--  VNDS - Visual Novel interpreter for PSP (LuaPlayerYT)
--  Main entry point. LuaPlayerYT loads "script.lua" on boot.
-- ============================================================================

-- Make require work relative to the executable directory
package.path = "./?.lua;./vnds/?.lua;" .. (package.path or "")

local core = require("vnds.core")



-- Run the engine. This never returns until the user quits the app.
core.run()
