-- ArenaBoot: builds the grey-box test area at server start (ROADMAP.md step 1.1).
-- The whole layout and the only writes to Workspace.TestArena live in TestArena.luau (rule 3).
-- This script is just the boot line, so the arena has exactly one owner.
local ServerScriptService = game:GetService("ServerScriptService")

local TestArena = require(ServerScriptService:WaitForChild("TestArena"))

TestArena.build()
