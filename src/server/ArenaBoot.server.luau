-- ArenaBoot: builds the grey-box test area at server start (ROADMAP.md step 1.1).
-- The whole layout and the only writes to Workspace.TestArena live in TestArena.luau (rule 3).
-- This script is just the boot line, so the arena has exactly one owner.
--
-- SINCE M2.8e IT CAN DECLINE TO BUILD AT ALL (map-generator design section 17). When
-- `Map.EXPECTED_WORLD` is not "arena" the generated map is the world and the grey box is not built:
-- not hidden, not moved, not built.
--
-- IT CANNOT BE HALF-ON and it does not sniff Workspace: a predicate like that lies the moment a run
-- half-finishes. `TestArena` keeps its owner and its file while it is still the rollback; section 17
-- step 9 archives it only after Karen accepts the map.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Map = require(ReplicatedStorage:WaitForChild("Map"))

if Map.EXPECTED_WORLD ~= "arena" then
	print("[ArenaBoot] the world is " .. Map.EXPECTED_WORLD .. ": the grey box is not built")
	return
end

local TestArena = require(ServerScriptService:WaitForChild("TestArena"))

TestArena.build()
