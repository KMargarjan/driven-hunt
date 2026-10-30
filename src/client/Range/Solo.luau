--!strict
-- Range.Solo: THE ONE WRITER of `LocalTransparencyModifier` on parts under ANOTHER PLAYER'S
-- Character (CLAUDE.md rule 3; design 6, 7). Karen, 2026-10-30: *"when I click E it will make that
-- I am alone in all shooting range"* -- so "alone" is literal, not only one animal.
--
-- Borrowed whole from `src/client/Range/Mask.luau`: the same sweep, the same level-triggered /
-- edge-written apply, the same restore. ONE predicate differs -- membership is "under a remote
-- player's character", not "under the range's targets folder".
--   https://create.roblox.com/docs/reference/engine/classes/BasePart
-- Note: docs/design/shooting-range-lobby.md sections 7, 11
--
-- OWNER BOUNDARY, as a partition and not a promise (design 7.2). Four writers of this property
-- exist: `Camera.Rig` (the LOCAL character), `Camera.Viewmodel` (the model it cloned under the
-- camera), `Range.Mask` (parts under `Workspace.RangeTargets`) and this one. Both of this module's
-- exclusions are CODE -- the local character and anything `RangeData.isTarget` answers true for --
-- so the folder wins over the character and no instance is ever in two sets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RangeData = require(ReplicatedStorage:WaitForChild("Range"))

local Solo = {}

-- HIDDEN IS 1 AND SHOWN IS WHATEVER THE PART ALREADY HAD, the same rule as `Mask`: a restored part
-- goes back to the value this module found, never to 0.
Solo.HIDDEN = 1

type State = {
	started: boolean,
	alone: boolean,
	players: (() -> { any })?,
	me: any?,
	isTarget: ((Instance) -> boolean)?,
	written: { [BasePart]: number },
	original: { [BasePart]: number },
	others: number,
	hidden: number,
	shown: number,
	writes: number,
	refused: number,
	sweeps: number,
}

local state: State = {
	started = false,
	alone = false,
	players = nil,
	me = nil,
	isTarget = nil,
	written = {},
	original = {},
	others = 0,
	hidden = 0,
	shown = 0,
	writes = 0,
	refused = 0,
	sweeps = 0,
}

local function listPlayers(): { any }
	local seam = state.players
	if seam == nil then
		return Players:GetPlayers()
	end
	local ok, list = pcall(seam)
	if not ok or type(list) ~= "table" then
		return {}
	end
	return list :: { any }
end

-- IS THIS PART A RANGE TARGET? `Mask` owns those, folder over character, so a character model
-- parented INTO the targets folder is REFUSED here and counted, never written.
local function isRangeTarget(part: BasePart): boolean
	local seam = state.isTarget
	if seam ~= nil then
		local ok, answer = pcall(seam, part)
		return ok and answer == true
	end
	return RangeData.isTarget(part)
end

function Solo.start(seams: {
	players: (() -> { any })?,
	me: any?,
	isTarget: ((Instance) -> boolean)?,
}?): boolean
	local given = seams or {}
	state.started = true
	state.alone = false
	state.players = given.players
	state.me = given.me or Players.LocalPlayer
	state.isTarget = given.isTarget
	state.written = {}
	state.original = {}
	state.others = 0
	state.hidden = 0
	state.shown = 0
	state.writes = 0
	state.refused = 0
	state.sweeps = 0
	return true
end

-- TOLD, never derived (design 9): the SERVER measures him at a station and resolves the flag, and
-- the board payload carries `record.alone`. A client that decided for itself would be a second
-- judge of the isolation, and the client reads no flag at all.
function Solo.setAlone(alone: boolean)
	state.alone = alone == true
end

local function partsOf(model: Instance, out: { BasePart })
	if model:IsA("BasePart") then
		table.insert(out, model :: BasePart)
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			table.insert(out, child :: BasePart)
		end
	end
end

-- THE WRITE, AND THE ONLY ONE. Level-triggered on the desired value, edge-triggered on the write,
-- so a step in which nothing changed costs one table read per part and no write (T12).
local function apply(part: BasePart, hide: boolean)
	if isRangeTarget(part) then
		state.refused += 1
		return
	end
	if state.original[part] == nil then
		state.original[part] = part.LocalTransparencyModifier
	end
	local wanted = if hide then Solo.HIDDEN else state.original[part] :: number
	if state.written[part] == wanted then
		return
	end
	part.LocalTransparencyModifier = wanted
	state.written[part] = wanted
	state.writes += 1
end

-- A LATE CHARACTER IS HANDLED BY THE SWEEP, NOT BY A SIGNAL (the same rule and the same reason as
-- `Mask`): the player list is read every step, so a man who joins, respawns or streams in is hidden
-- on the next frame and no `CharacterAdded` connection can leak or miss a respawn between frames.
function Solo.step(_dt: number?)
	if not state.started then
		return
	end
	state.sweeps += 1
	local me = state.me
	local others = 0
	local hidden = 0
	local shown = 0
	local seen: { [BasePart]: boolean } = {}
	for _, player in ipairs(listPlayers()) do
		if player == me then
			continue
		end
		local character = (player :: any).Character
		if typeof(character) ~= "Instance" then
			continue
		end
		others += 1
		local parts: { BasePart } = {}
		partsOf(character :: Instance, parts)
		for _, part in ipairs(parts) do
			seen[part] = true
			apply(part, state.alone)
		end
		if state.alone then
			hidden += 1
		else
			shown += 1
		end
	end
	-- A PART THAT LEFT IS FORGOTTEN, not written to: a respawned character's old model is
	-- destroyed, and a write to a destroyed instance is an error, not a restore.
	for part in pairs(state.written) do
		if not seen[part] then
			state.written[part] = nil
			state.original[part] = nil
		end
	end
	state.others = others
	state.hidden = hidden
	state.shown = shown
end

function Solo.stats(): {
	others: number,
	hidden: number,
	shown: number,
	writes: number,
	refused: number,
	sweeps: number,
}
	return {
		others = state.others,
		hidden = state.hidden,
		shown = state.shown,
		writes = state.writes,
		refused = state.refused,
		sweeps = state.sweeps,
	}
end

-- EVERY VALUE IT WROTE, PUT BACK. `stop` is the door out: nobody keeps a modifier this module put
-- on him, which is what makes the owner boundary reversible.
function Solo.stop()
	for part, original in pairs(state.original) do
		pcall(function()
			part.LocalTransparencyModifier = original
		end)
	end
	state.started = false
	state.alone = false
	state.written = {}
	state.original = {}
	state.others = 0
	state.hidden = 0
	state.shown = 0
end

return Solo
