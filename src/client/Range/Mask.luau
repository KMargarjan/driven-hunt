--!strict
-- Range.Mask: THE ONE WRITER of `LocalTransparencyModifier` on parts under
-- `Workspace.RangeTargets` (CLAUDE.md rule 3; design 9.5). Each man sees ONE animal: his own
-- station's, and only while it is inside his own station's window.
--
-- The property is client-local and NOT replicated, which is why a client can hide a server-drawn
-- part with no round trip. The window predicate is the SHIPPED `RangeData.inWindow`, the same one
-- `Range.ignoredFor` reads, so the shot's door and the picture ask one question.
--   https://create.roblox.com/docs/reference/engine/classes/BasePart
-- Note: docs/design/shooting-range-lobby.md sections 4.4, 9.5, 11.3
--
-- OWNER BOUNDARY: `Camera.Rig` is the only writer of that property ON THE LOCAL CHARACTER, and the
-- two sets are disjoint BY CONSTRUCTION -- this module never looks outside `root`, the range's own
-- targets folder. `range_mask.spec` asserts that rather than describing it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RangeData = require(ReplicatedStorage:WaitForChild("Range"))

local Mask = {}

-- HIDDEN IS 1 AND SHOWN IS WHATEVER THE PART ALREADY HAD. A shown part is RESTORED, never written
-- to 0: a target may ship a modifier of its own, so "shown" means "as the range drew it".
Mask.HIDDEN = 1

type State = {
	started: boolean,
	root: Instance?,
	player: any?,
	now: (() -> number)?,
	alsoTransparency: boolean,
	mine: Instance?,
	-- THE IDS THE SERVER NAMED (task 321 (e)): `Body.create` names a trunk after the animal's id, so
	-- a NAME resolves on this client's own sweep whether or not the Instance had replicated when the
	-- payload arrived. The live target and his carcass are both in it.
	mineIds: { [string]: boolean },
	minX: number?,
	maxX: number?,
	written: { [BasePart]: number },
	original: { [BasePart]: number },
	originalTransparency: { [BasePart]: number },
	targets: number,
	hidden: number,
	shown: number,
	writes: number,
	refused: number,
	sweeps: number,
	lastStepAt: number,
}

local state: State = {
	started = false,
	root = nil,
	player = nil,
	now = nil,
	alsoTransparency = false,
	mine = nil,
	mineIds = {},
	minX = nil,
	maxX = nil,
	written = {},
	original = {},
	originalTransparency = {},
	targets = 0,
	hidden = 0,
	shown = 0,
	writes = 0,
	refused = 0,
	sweeps = 0,
	lastStepAt = 0,
}

-- IS THIS PART THE LOCAL MAN'S OWN BODY? `Camera.Rig` is the only writer of the modifier there
-- (design 10), so a part under his character is REFUSED and counted, never written. The folder
-- makes the two sets disjoint by construction; this makes the boundary enforced as well as stated.
local function isLocalBody(part: BasePart): boolean
	local player = state.player
	if player == nil then
		return false
	end
	local character = (player :: any).Character
	if typeof(character) ~= "Instance" then
		return false
	end
	return part == character or part:IsDescendantOf(character :: Instance)
end

-- THE FOLDER, resolved at `start` and not searched again per frame: the range parents every trunk
-- into it (`Range.isTarget`'s own ancestor), so one `FindFirstChild` answers for all six.
function Mask.start(seams: {
	root: Instance?,
	player: any?,
	now: (() -> number)?,
	alsoTransparency: boolean?,
}?): boolean
	local given = seams or {}
	local root = given.root or Workspace:FindFirstChild(RangeData.TARGETS_FOLDER)
	if root == nil then
		return false
	end
	state.started = true
	state.root = root
	state.player = given.player
	state.now = given.now
	state.alsoTransparency = given.alsoTransparency == true
	state.mine = nil
	state.mineIds = {}
	state.minX = nil
	state.maxX = nil
	state.written = {}
	state.original = {}
	state.originalTransparency = {}
	state.targets = 0
	state.hidden = 0
	state.shown = 0
	state.writes = 0
	state.refused = 0
	state.sweeps = 0
	state.lastStepAt = 0
	return true
end

-- TOLD, never derived: the server measures which station he is on and names his own trunk on the
-- board payload (design 9.4). A client that guessed would be a second judge of the isolation.
-- ...AND BY NAME AS WELL AS BY REFERENCE (task 321 (e)). An Instance that had not replicated when
-- the payload arrived reads nil here, and with a NEW animal every pass that hid the man's own target
-- for the whole pass (319a(a)). The ids are the server's too -- the client still guesses nothing --
-- but a string survives the wire, so the trunk is resolved on the sweep that first sees it.
function Mask.setMine(target: Instance?, ids: { string }?)
	state.mine = if typeof(target) == "Instance" then target else nil
	local set = {}
	if type(ids) == "table" then
		for _, id in ipairs(ids :: { string }) do
			if type(id) == "string" and id ~= "" then
				set[id] = true
			end
		end
	end
	state.mineIds = set
end

function Mask.setWindow(minX: number?, maxX: number?)
	if type(minX) == "number" and type(maxX) == "number" then
		state.minX = minX
		state.maxX = maxX
	else
		state.minX = nil
		state.maxX = nil
	end
end

-- EVERY PART OF ONE TRUNK: the trunk and the zone parts welded under it, which is what the drawn
-- animal IS (`Boar.Body.create`). Walked per step, so a part that streams in late is masked on the
-- next one -- the sweep, not a signal (design 4.4).
local function partsOf(trunk: Instance, out: { BasePart })
	if trunk:IsA("BasePart") then
		table.insert(out, trunk :: BasePart)
	end
	for _, child in ipairs(trunk:GetDescendants()) do
		if child:IsA("BasePart") then
			table.insert(out, child :: BasePart)
		end
	end
end

-- THE WRITE, AND THE ONLY ONE. Level-triggered on the DESIRED value, edge-triggered on the write:
-- a step in which nothing changed costs one table read per part and no write, which is T12.
local function apply(part: BasePart, hide: boolean)
	if isLocalBody(part) then
		state.refused += 1
		return
	end
	if state.original[part] == nil then
		state.original[part] = part.LocalTransparencyModifier
		if state.alsoTransparency then
			state.originalTransparency[part] = part.Transparency
		end
	end
	-- SHOWN IS THE VALUE THIS MODULE FOUND, read here and not by the caller: resolving it outside
	-- `apply` read `original` BEFORE the first touch recorded it, which flattened a target that
	-- shipped its own modifier to 0 on the first step.
	local wanted = if hide then Mask.HIDDEN else state.original[part] :: number
	if state.written[part] == wanted then
		return
	end
	part.LocalTransparencyModifier = wanted
	-- THE FALLBACK, BY PARAMETER (design 4.4, section 14 item 8): that the modifier hides a SKINNED
	-- MeshPart is UNVERIFIED, and the stated fallback is a client-local `Transparency` write on the
	-- same parts. Off by default; T3's two screenshots decide whether it is needed.
	if state.alsoTransparency then
		local base = state.originalTransparency[part] or 0
		part.Transparency = if wanted >= 1 then 1 else base
	end
	state.written[part] = wanted
	state.writes += 1
end

-- WHAT THIS TRUNK SHOULD LOOK LIKE: 0 for his own inside his own window, `HIDDEN` for every other
-- station's and for his own outside it. PURE given the told state, which is what makes T12's
-- "nothing changed, nothing written" a property of `apply` alone.
local function isMine(trunk: Instance): boolean
	if trunk == state.mine then
		return true
	end
	return state.mineIds[trunk.Name] == true
end

local function wantedFor(trunk: Instance): number
	if not isMine(trunk) then
		return Mask.HIDDEN
	end
	local minX, maxX = state.minX, state.maxX
	if minX == nil or maxX == nil then
		-- NO WINDOW TOLD MEANS NO RULE: his own animal is shown. The other five stay hidden, which
		-- is the isolation; the window only ever narrows his own.
		return 0
	end
	local x: number? = nil
	if trunk:IsA("BasePart") then
		x = (trunk :: BasePart).Position.X
	else
		local pivot = trunk:FindFirstChildWhichIsA("BasePart")
		x = if pivot ~= nil then (pivot :: BasePart).Position.X else nil
	end
	return if RangeData.inWindow(minX, maxX, x) then 0 else Mask.HIDDEN
end

function Mask.step(_dt: number?)
	if not state.started then
		return
	end
	local root = state.root
	if root == nil then
		return
	end
	local clock = state.now
	if clock ~= nil then
		local ok, value = pcall(clock)
		if ok and type(value) == "number" then
			state.lastStepAt = value
		end
	end
	state.sweeps += 1
	local targets = 0
	local hidden = 0
	local shown = 0
	local seen: { [BasePart]: boolean } = {}
	for _, trunk in ipairs(root:GetChildren()) do
		targets += 1
		local wanted = wantedFor(trunk)
		local parts: { BasePart } = {}
		partsOf(trunk, parts)
		for _, part in ipairs(parts) do
			seen[part] = true
			apply(part, wanted ~= 0)
		end
		if wanted == 0 then
			shown += 1
		else
			hidden += 1
		end
	end
	-- A PART THAT LEFT THE FOLDER IS FORGOTTEN, not written to: a cleared carcass is destroyed, and
	-- a write to a destroyed instance is an error, not a restore.
	for part in pairs(state.written) do
		if not seen[part] then
			state.written[part] = nil
			state.original[part] = nil
			state.originalTransparency[part] = nil
		end
	end
	state.targets = targets
	state.hidden = hidden
	state.shown = shown
end

function Mask.stats(): {
	targets: number,
	writes: number,
	hidden: number,
	shown: number,
	refused: number,
	sweeps: number,
	lastStepAt: number,
}
	return {
		targets = state.targets,
		writes = state.writes,
		hidden = state.hidden,
		shown = state.shown,
		refused = state.refused,
		sweeps = state.sweeps,
		lastStepAt = state.lastStepAt,
	}
end

-- EVERY VALUE IT WROTE, PUT BACK. `stop` is the door out: nothing the range drew keeps a modifier
-- this module put on it, which is what makes the owner boundary reversible.
function Mask.stop()
	for part, original in pairs(state.original) do
		local base = state.originalTransparency[part]
		pcall(function()
			part.LocalTransparencyModifier = original
			if base ~= nil then
				part.Transparency = base
			end
		end)
	end
	state.started = false
	state.root = nil
	state.mine = nil
	state.mineIds = {}
	state.minX = nil
	state.maxX = nil
	state.written = {}
	state.original = {}
	state.originalTransparency = {}
	state.targets = 0
	state.hidden = 0
	state.shown = 0
end

return Mask
