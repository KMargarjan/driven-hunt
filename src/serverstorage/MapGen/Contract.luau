--!strict
-- MapGen.Contract: HOW THE GENERATOR GETS THE MAP CONTRACT, and the only module that answers that
-- question. It returns `ReplicatedStorage.Map` -- the same frozen table every other system reads --
-- but at EDIT TIME it requires a fresh clone of that script instead of the session's cached copy.
--
-- WHY, MEASURED 2026-09-26. Studio's require cache survives between `execute_luau` calls, and Rojo
-- replacing a ModuleScript's Source does NOT reload an already-required module. `tools/mapgen.py`
-- works around that for the generator itself by requiring a parentless clone of `ServerStorage.MapGen`
-- every call -- but the contract is reached by ABSOLUTE PATH from inside Config, Markers and init, so
-- those requires would still hand back whatever the session loaded hours ago. That is not a
-- theoretical risk: it silently built a map from a `Map.STREAMING` the file no longer said, and the
-- only other cure is closing and reopening the place, which is a click no tool can make.
--
-- At RUN TIME (a real server, or a Play session including the harness's) this is exactly
-- `require(ReplicatedStorage.Map)` and nothing else: one contract table, shared, as CLAUDE.md rule 3
-- requires. The clone exists only in the Edit session that generates a map, where there is no game
-- running to share a table with.
--
--   RunService:IsRunning https://create.roblox.com/docs/reference/engine/classes/RunService#IsRunning
--
-- Design: docs/design/map-generator.md (section 4; this module is an addition to section 2.2's list,
-- made necessary by the measurement above and reported with it)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local module = ReplicatedStorage:WaitForChild("Map")
local editTime = RunService:IsStudio() and not RunService:IsRunning()

return require(if editTime then module:Clone() else module)
