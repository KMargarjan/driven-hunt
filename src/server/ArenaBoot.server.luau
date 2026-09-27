-- ArenaBoot: builds the grey-box test area at server start (ROADMAP.md step 1.1).
-- The whole layout and the only writes to Workspace.TestArena live in TestArena.luau (rule 3).
-- This script is just the boot line, so the arena has exactly one owner.
--
-- SINCE TASK 79 IT CAN DECLINE TO BUILD AT ALL (map-generator design section 17). When the world is
-- the generated map, the grey box is not built: not hidden, not moved, not built. The design wrote
-- this early return against a committed string; the Director made the switch a FLAG, because
-- CLAUDE.md lists the map switch as feel-critical and feel-critical work merges dark. So this is the
-- flag's read AT THIS OWNER'S BOUNDARY, and the decision itself is `Map.worldFor`, which is pure and
-- takes the boolean as an argument -- the shape that lets a spec drive both worlds while the flag
-- sits off.
--
-- IT CANNOT BE HALF-ON and it does not sniff Workspace: a predicate like that lies the moment a run
-- half-finishes. `TestArena` keeps its owner and its file while it is still the rollback; section 17
-- step 9 archives it only after Karen accepts the map.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Map = require(ReplicatedStorage:WaitForChild("Map"))

if Map.worldFor(Flags.isOn("MAP_V1")) ~= "arena" then
	print("[ArenaBoot] the world is " .. Map.WORLD_WHEN_ON .. ": the grey box is not built")
	return
end

local TestArena = require(ServerScriptService:WaitForChild("TestArena"))

TestArena.build()
