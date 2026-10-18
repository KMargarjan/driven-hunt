--!strict
-- Weapon.Horn: THE BEATER'S HORN -- the only writer of the horn `Tool`, the only thing that grants
-- or destroys one, and the only thing that plays its voice. Task 152, the beater kit part 2.
--
-- WHY IT LIVES UNDER `ServerScriptService.Weapon` AND NOT UNDER `Match.Body`: the design says so in
-- one sentence, and the sentence is the rule -- *"the horn is CARRIED, not worn, so its owner is
-- `ServerScriptService.Weapon` ... never `Match.Body`. Worn is Body's; carried is Weapon's"*
-- (docs/design/beater-kit.md section 16 item 1). It is its own file rather than lines in
-- `Weapon/init.luau` because a horn shares nothing with a gun's state: no ammo, no cycle, no safety
-- arc, no aim, no remote, no client module. It borrows exactly two things from its neighbours,
-- `Hardware.addPiece` and `Hardware.give`, which are generic over any Tool.
--
-- IT NEVER TOUCHES A BOAR, AND IT NEVER TOUCHES A BRAIN. A blast is published as `Horn.Blown` and
-- the composition root -- `MatchBoot` in the drive, `ForestTestBoot` in the playtest world -- wires
-- it to the boar runtime's own door, exactly as `Weapon.ShotFired` is wired to `runtime:hearShot`.
-- Neither owner requires the other (docs/design/shotgun.md section 6.3).
--
-- WHO MAY CARRY ONE IS NOT THIS MODULE'S DECISION EITHER: `Horn.setCarryPolicy` is injected at the
-- composition root, the same shape as `Weapon.setArmingPolicy(Match.mayCarryWeapon)`. With no policy
-- injected NOBODY gets a horn, so a world that has not wired it hands out none rather than arming
-- everybody.
--
-- Data:   src/shared/Horn/init.luau (every number, and why)
-- Note:   docs/research/2026-10-11-beater-kit.md (section 5)
-- Design: docs/design/beater-kit.md (section 16 item 1)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("Horn"))

local Hardware = require(script.Parent.Hardware)

local Horn = {}

-- The sound's Instance name, and the only child of the Handle that is not a piece of the horn.
Horn.SOUND_NAME = "Blast"

-- THE WORN MESH'S Instance NAME (task 169), and `Hardware.MODEL_NAME`'s own value for the gun's --
-- so "does this Handle wear the uploaded horn" is one `FindFirstChild` and one name, which is what
-- `addMesh`, `upgradeLook` and the spec all ask.
Horn.MESH_NAME = Hardware.MODEL_NAME

-- ({ blowerUserId: number, at: Vector3 }) -- A HORN WAS BLOWN, and where. Fired once per ACCEPTED
-- blast, so a click inside the cooldown, from a player holding nothing, or from a horn whose Handle
-- has gone publishes nothing. The same contract as `Weapon.ShotFired`: one fact, and the owner that
-- cares about animals decides what it means.
--
-- `at` IS THE HORN'S OWN HANDLE, never a character's approximate position and never a phantom: the
-- research note's one requirement for this stimulus (section 5.3).
local blownSignal = Instance.new("BindableEvent")
Horn.Blown = blownSignal.Event

local carryPolicy: ((Player) -> boolean)? = nil
-- MAY THIS HORN SOUND AT ALL? (task 168). KAREN, 2026-10-12 ~21:45: *"when beater cross the line of
-- hunter it's done for him cant use sound anymore"*.
--
-- THE SAME SHAPE AS `carryPolicy` RIGHT ABOVE IT, and for the same reason: WHO may blow is not this
-- module's decision -- it is the drive's, because "has he crossed the hunters' line" is a fact about
-- the drive's own geometry (`Match.mayBlowHorn`). Injected at the composition root; with no policy
-- injected EVERYBODY may blow, which is this file before task 168 by every branch and is what keeps
-- every existing spec and the Forest Test's own `/beater` honest.
--
-- IT IS KEYED, NOT PLAYER'D, so one policy covers a player and a bot: the key is `Horn.keyFor(userId)`
-- for a person and the bot's own slot id for a rig, which is exactly how the one cooldown table is
-- keyed. A bot that has walked through the line therefore falls silent by the same predicate.
local blowPolicy: ((string) -> boolean)? = nil
local started = false
-- One horn per player. The Tool is the state -- these tables are a record of it, and every read
-- below corrects itself off the live Instance (`Horn.held`), which is the lesson Task 34 and Task
-- 144 both paid for on the gun: a respawn destroys the character's Tool and merely DETACHES the
-- Backpack, so "has a Parent" is not "the player can reach it".
local tools: { [Player]: Tool } = {}
-- KEYED BY A STRING, NOT BY A userId (task 161). A player's key is `tostring(player.UserId)` and a
-- bot's is its own slot id ("bot-beater-3"), so ONE cooldown table holds everybody who can sound a
-- horn and a bot is held to the real `Horn.CONFIG.COOLDOWN` by the same row a player is. A second
-- table for the bots would be a second answer to "is this horn ready", which is this project's named
-- failure mode.
local lastBlast: { [string]: number } = {}
local lifeWatchers: { [Player]: RBXScriptConnection } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}

local stats = {
	built = 0,
	granted = 0,
	revoked = 0,
	grantsMissed = 0, -- a horn built for a player with no Backpack: nothing recorded, tried again
	blasts = 0,
	refusedCooldown = 0,
	refusedNoHorn = 0,
	refusedThrough = 0, -- blasts refused because the blower is through the hunters' line (task 168)
	raised = 0, -- how many times an arm went up to the mouth (task 168)
	raisesMissed = 0, -- ...and how many times there was no clip or no Animator to do it with
	carried = 0, -- how many times the horn-at-the-side pose started (task 206)
	carryMissed = 0, -- ...and how many times there was no clip or no Animator to do it with
	equippedNow = 0,
	equippedLate = 0,
	equipGaveUp = 0,
	sweeps = 0,
	repairs = 0,
	wearsMesh = 0, -- horns built wearing the uploaded model (task 169)
	wearsParts = 0, -- ...and horns built out of `Data.pieces` because it was not there yet
	upgraded = 0, -- ...and parts horns the mesh reached later, in the hand they were already in
	bodyHorns = 0, -- horns handed to a character that is NOT a player's (a bot beater), task 172
}

-- EVERY HORN THIS MODULE HAS PUT IN A HAND THAT IS NOT A PLAYER'S (task 172). KAREN, 2026-10-13
-- ~09:20: *"all beaters has to have same horn"*.
--
-- THE BUILDER WAS ALREADY ONE (`Horn.build`, through `Horn.giveTo`), SO THE MODEL WAS NEVER THE
-- DIFFERENCE -- measured in Karen's own live session before a line of this task was written: all
-- four bot beaters' Handles carried `MeshPart:Model`, the uploaded horn of task 169, at the same
-- `Grip`. WHAT WAS NOT SHARED IS THE UPGRADE: `Horn.upgradeLook` walks `Players:GetPlayers()`, and
-- a bot is not a player, so a bot handed its horn in the window before the asset preloaded -- which
-- is exactly the window `WeaponBoot` leaves open on purpose, and the window that cost the gun its
-- own `upgradeLook` -- would carry the parts horn for the whole session with nothing able to notice.
--
-- SO THE HORNS THEMSELVES ARE THE REGISTRY, and it lives here because `Horn.giveTo` is the one door
-- a bot's horn comes through. A plain list, swept on the same beat as the players': an entry whose
-- Tool has been destroyed or re-parented out of a character is dropped, so a bot that dies, a drive
-- that ends and a rig that is deleted all clean up without this module watching anything.
local bodyTools: { Tool } = {}

-- Seconds between carry sweeps. THE SAME NUMBER AND THE SAME MEASURED REASON AS THE GUN'S
-- `ARMING_SWEEP_SECONDS`: edge-triggered granting misses, and a miss is permanent -- a beater stands
-- a whole drive with empty hands. The drive respawns players to place them, so the grant that landed
-- in the Backpack a placement is about to destroy has to be noticed by something that asks again.
-- The sweep is the level: it grants nothing `refreshCarry` would not, and costs one table scan.
local CARRY_SWEEP_SECONDS = 2
-- How long to wait for the Humanoid before giving up on putting the horn in the hand. TASK 129'S
-- LESSON, and the number is its number: `CharacterAdded` fires while the model is still being
-- assembled, so `FindFirstChildOfClass("Humanoid")` answers nil, the equip silently does nothing,
-- and the player stands there with the tool in his Backpack for the rest of the drive.
local EQUIP_WAIT_SECONDS = 10

-- The policy, injected. Hands back the one it is replacing, so a caller that needs it for the length
-- of one test can put the real one back without knowing who installed it (the shape
-- `Weapon.setArmingPolicy` took in Task 150).
function Horn.setCarryPolicy(policy: ((Player) -> boolean)?): ((Player) -> boolean)?
	local previous = carryPolicy
	carryPolicy = policy
	return previous
end

-- WITH NO POLICY, NOBODY CARRIES. A world that has not wired one gets no horns rather than one per
-- player, and a policy that errors is a "no" for that player alone -- never a swallowed error that
-- arms everybody and never one that leaves a beater permanently empty-handed without saying so.
function Horn.mayCarry(player: Player): boolean
	local policy = carryPolicy
	if policy == nil then
		return false
	end
	local ok, allowed = pcall(policy, player)
	if not ok then
		return false
	end
	return allowed == true
end

-- THE CARRY DECISION, as a pure function of the two facts it depends on, so it can be asserted
-- without taking a live beater's horn away.
--
-- IT IS `Weapon.armingAction`'S TWIN, DELIBERATELY WRITTEN OUT RATHER THAN REQUIRED (rule 2 wants a
-- reason, so here it is): `Weapon.armingAction` lives in `Weapon/init.luau`, which is this module's
-- PARENT. A child requiring its parent module is a require cycle waiting for the first line of
-- `init.luau` that wants a horn, and it would drag the whole gun -- its remotes, its registry, its
-- cast -- into every spec that only wants to ask this question. Two lines, no coupling.
function Horn.carryAction(allowed: boolean, holding: boolean): string?
	if allowed and not holding then
		return "grant"
	elseif not allowed and holding then
		return "revoke"
	end
	return nil
end

-- Can the player actually reach this Tool? The live containers are the answer -- the Backpack they
-- have NOW and the character they are wearing NOW -- and nothing else, whatever its Parent says.
-- `Weapon.reachable`'s rule, for the same measured reason (Task 144).
local function reachable(tool: Instance?, player: Player): boolean
	if tool == nil then
		return false
	end
	local parent = (tool :: Instance).Parent
	if parent == nil then
		return false
	end
	return parent == player:FindFirstChildOfClass("Backpack") or parent == player.Character
end

-- Every horn this player is carrying, Backpack and character both, found BY NAME off the live tree.
-- One per player is the rule, and this is how it is enforced rather than assumed.
function Horn.toolsOf(player: Player): { Tool }
	local found = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and Data.isToolName(child.Name) then
					table.insert(found, child)
				end
			end
		end
	end
	return found
end

-- The horn this player holds, or nil -- AND THE RECORD IS CORRECTED ON EVERY READ, which is what
-- makes the sweep a repair rather than a re-statement of the same wrong answer.
function Horn.held(player: Player): Tool?
	local recorded = tools[player]
	if recorded ~= nil and reachable(recorded, player) then
		return recorded
	end
	tools[player] = nil
	-- ...AND A HORN THIS MODULE NEVER RECORDED STILL COUNTS, because a server that reloaded, or a
	-- grant whose record was dropped, must not hand out a second one.
	local found = Horn.toolsOf(player)[1]
	if found ~= nil then
		tools[player] = found
		return found
	end
	return nil
end

-- ---------------------------------------------------------------- the hardware

-- THE HORN, BUILT FROM PARTS. Nothing is uploaded and nothing is loaded: `Data.pieces` is the pure
-- list and `Hardware.addPiece` -- which is generic over any Handle and any piece -- welds each one
-- on, so the geometry comes from numbers in a reviewable file and the weld carries the offset as
-- data (the property `Hardware.addPiece`'s own header establishes).
-- THE UPLOADED HORN, WELDED TO THE HANDLE (task 169). Returns false when there is nothing to wear,
-- which is not an error: the caller builds `Data.pieces` instead and the beater is never empty-handed.
--
-- IT BORROWS `Hardware.addPieceMesh` RATHER THAN REPEATING IT (rule 2). That function is already
-- generic over "one uploaded MeshPart, sized by the row, welded to a Handle at a pose" -- it is how
-- the shotgun wears its barrels and how the rifle wears its stock, bolt and scope -- and a horn is
-- exactly that and nothing more. What is NOT borrowed is the gun's seam either side of it: no
-- `Muzzle`, no sight, no second piece, no hinge.
--
-- THE THREE NUMBERS COME FROM THE MANIFEST ROW, never from this file: `sizeStuds` (the consumer sets
-- Size, design 6.1), `rotationDeg` and `offsetStuds`. They are stated in `Horn.MESH` and the row
-- reads them from there, so a screenshot that disagrees is one line in the horn's own data file.
function Horn.addMesh(handle: BasePart): boolean
	local provider = Hardware.getTemplateProvider()
	if provider == nil then
		return false
	end
	local _, report = provider(Data.ASSET_KEY)
	local row = if typeof(report) == "table" then report.row else nil
	if typeof(row) ~= "table" then
		return false
	end
	local size = if typeof(row.sizeStuds) == "Vector3" then row.sizeStuds else Data.MESH.SIZE_STUDS
	local rotation = if typeof(row.rotationDeg) == "Vector3" then row.rotationDeg else Vector3.zero
	local offset = if typeof(row.offsetStuds) == "Vector3" then row.offsetStuds else Vector3.zero
	local pose = CFrame.new(offset) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	local worn = Hardware.addPieceMesh(
		handle,
		Data.ASSET_KEY,
		Horn.MESH_NAME,
		size,
		pose,
		"the beater blows the parts horn instead"
	)
	if not worn then
		return false
	end
	-- THE ROW'S MEASURED COLOUR, AND ONLY WHEN THE TEXTURE IS NOT THERE. A `SurfaceAppearance` is
	-- what carries this model's ivory, and a MeshPart's `Color` under one of those does nothing; a
	-- clone that arrived WITHOUT one has lost its maps, and task 99's lesson is that the honest
	-- answer then is the thing's own measured colour rather than Roblox's default grey -- Karen saw
	-- that grey as a white glove and said so.
	local mesh = handle:FindFirstChild(Horn.MESH_NAME)
	if mesh and mesh:IsA("BasePart") and mesh:FindFirstChildOfClass("SurfaceAppearance") == nil then
		local fallback = row.fallbackColor
		if typeof(fallback) == "Color3" then
			mesh.Color = fallback
		end
	end
	return true
end

-- TASK 152'S HORN, AS ONE CALL, and `removeParts` below is its exact opposite -- the same pairing
-- `Hardware.addParts`/`Hardware.removeParts` has, and for its reason: what the parts horn is made of
-- is walked in ONE place, forwards and backwards, out of the one pure list.
function Horn.addParts(handle: BasePart)
	for _, piece in ipairs(Data.pieces(Data.CONFIG)) do
		Hardware.addPiece(handle, piece)
	end
end

-- THE FALLBACK COMES OFF, AND ONLY THE FALLBACK. By NAME, from the same one list `addParts` builds
-- from, so the Handle, the `Blast` sound and the worn mesh cannot be caught by it. Not a "destroy
-- every child but the sound" sweep: that would be a second, looser idea of what a horn is made of.
function Horn.removeParts(handle: BasePart): number
	local removed = 0
	for _, piece in ipairs(Data.pieces(Data.CONFIG)) do
		local part = handle:FindFirstChild(piece.name)
		if part and part:IsA("BasePart") then
			part:Destroy()
			removed += 1
		end
		local weld = handle:FindFirstChild(piece.name .. "Weld")
		if weld then
			weld:Destroy()
		end
	end
	return removed
end

-- EVERY HORN THAT WAS HANDED OUT BEFORE THE MESH LANDED, UPGRADED IN THE HAND IT IS ALREADY IN
-- (task 169). `WeaponBoot` starts the systems BEFORE it preloads -- deliberately, so a player who
-- joins in that window gets a horn rather than nothing -- and the gun needed exactly this call for
-- exactly this reason: Karen played a session where the barrels landed 2096 ms after the gun was
-- handed out. Idempotent: a horn already wearing the mesh is left alone, because `addPieceMesh`
-- answers true the moment the Handle has the child.
--
-- IT NEVER TOUCHES THE `Tool`, ONLY ITS HANDLE'S CHILDREN, so a horn in the hand stays in the hand
-- and a horn in the Backpack stays there -- which is the bug `Weapon.upgradeLook` was written to
-- stop being (task 123 round 9, *"There is no weapon something is broken"*).
local function upgradeOne(tool: Tool): boolean
	local handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return false
	end
	if handle:FindFirstChild(Horn.MESH_NAME) ~= nil then
		return false -- already wearing it
	end
	if not Horn.addMesh(handle) then
		return false
	end
	Horn.removeParts(handle)
	stats.upgraded += 1
	return true
end

-- EVERY HORN THIS MODULE HAS GIVEN TO A CHARACTER THAT IS NOT A PLAYER'S, still in a hand. Dropped
-- entries are pruned in the same pass, which is what keeps the registry from growing with every
-- drive's worth of retired bots.
function Horn.bodyTools(): { Tool }
	local live = {}
	for _, tool in ipairs(bodyTools) do
		local parent = tool.Parent
		if parent ~= nil and parent:FindFirstChildOfClass("Humanoid") ~= nil then
			table.insert(live, tool)
		end
	end
	bodyTools = live
	return live
end

function Horn.upgradeLook(): number
	local upgraded = 0
	for _, player in ipairs(Players:GetPlayers()) do
		for _, tool in ipairs(Horn.toolsOf(player)) do
			if upgradeOne(tool) then
				upgraded += 1
			end
		end
	end
	-- ...AND THE BOTS' (task 172), so "all beaters has to have same horn" is true of the LATE case
	-- too and not only of the one where the mesh was already there when the horn was built.
	for _, tool in ipairs(Horn.bodyTools()) do
		if upgradeOne(tool) then
			upgraded += 1
		end
	end
	return upgraded
end

function Horn.build(): Tool
	local config = Data.CONFIG
	local tool = Instance.new("Tool")
	tool.Name = Data.TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = config.GRIP
	-- The Hud has no horn readout yet; the tooltip is what a player sees in the hotbar slot.
	tool.ToolTip = "Signal horn -- click to blow"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = config.HANDLE_SIZE
	handle.Color = config.HANDLE_COLOR
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Anchored = false
	handle.Transparency = config.HANDLE_TRANSPARENCY
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	if Horn.addMesh(handle) then
		stats.wearsMesh += 1
	else
		Horn.addParts(handle)
		stats.wearsParts += 1
	end

	-- THE VOICE HANGS ON THE HANDLE, which is what makes it 3D: the engine positions a Sound by its
	-- parent BasePart, so everybody near the beater hears the blast from where he is standing and
	-- nobody has to be told where that was. Created at build time rather than at the blast so that
	-- the asset is resolved before it is first wanted.
	local sound = Instance.new("Sound")
	sound.Name = Horn.SOUND_NAME
	sound.SoundId = config.SOUND_ID
	sound.Volume = config.VOLUME
	sound.RollOffMode = config.ROLLOFF_MODE
	sound.RollOffMinDistance = config.ROLLOFF_MIN_STUDS
	sound.RollOffMaxDistance = config.ROLLOFF_MAX_STUDS
	sound.Looped = false
	sound.Parent = handle

	stats.built += 1
	return tool
end

-- INTO THE HAND, NOT INTO THE BACKPACK. Karen, 2026-10-10: *"so horn will be default tool for
-- beater"* -- a default tool is one he is already holding.
--
-- IT WAITS FOR THE HUMANOID RATHER THAN DECIDING ONCE (Task 129, measured on the gun: three grants,
-- "+2.5s hand, +75.9s backpack, +75.9s backpack" -- the two after the drive's placement respawn
-- never got equipped and the player stood at his stand empty-handed). In its own thread, so the
-- grant never blocks, and it gives up quietly if the character has been replaced in the meantime.
--
-- ITS OWN COUNTERS, NOT `Hardware.equipStats`: that table is the GUN's, `Weapon.stats()` publishes
-- it, and a horn inflating it would corrupt the one instrument this repo has for "a shooter whose
-- gun never reached his hand".
local function equip(tool: Tool, player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:EquipTool(tool)
		stats.equippedNow += 1
		return
	end
	task.spawn(function()
		local late = character:WaitForChild("Humanoid", EQUIP_WAIT_SECONDS)
		if late == nil or player.Character ~= character or tool.Parent == nil then
			stats.equipGaveUp += 1
			return
		end
		(late :: Humanoid):EquipTool(tool)
		stats.equippedLate += 1
	end)
end

function Horn.grant(player: Player): Tool?
	local existing = Horn.held(player)
	if existing ~= nil then
		return existing
	end
	local tool = Horn.build()
	if not Hardware.give(tool, player) then
		-- No Backpack yet. Destroy it rather than leave an orphan, record nothing, and let the
		-- sweep ask again -- the gun's rule, and `Hardware.give` never yields for the reason its own
		-- header gives.
		tool:Destroy()
		stats.grantsMissed += 1
		return nil
	end
	tools[player] = tool
	stats.granted += 1

	-- THE CLICK, AND IT IS READ ON THE SERVER. `Tool.Activated` fires on the server for the Tool the
	-- server owns, so a blast needs NO RemoteEvent, no client module and no input binding -- the
	-- smallest surface this feature can have. The client cannot forge anything but the click itself,
	-- and the cooldown in `Horn.blow` is the server's answer to that.
	--   https://create.roblox.com/docs/reference/engine/classes/Tool#Activated
	local activated = tool.Activated:Connect(function()
		Horn.blow(player)
	end)
	local list = connections[player]
	if list == nil then
		list = {}
		connections[player] = list
	end
	table.insert(list, activated)

	-- THE ARM GOES DOWN WHILE THE HORN IS IN THE HAND (task 206), and comes back to the stock pose
	-- when it leaves it. `Tool.Equipped` and `Tool.Unequipped` are the two moments the horn IS in
	-- the hand, they fire on the server for the Tool the server owns -- the same property
	-- `Tool.Activated` is read for, two lines up -- and they are per-Tool, so a respawn's new horn
	-- brings its own pair and the dead one's go with it through `connections`.
	--
	-- `player.Character` IS READ IN THE HANDLER, not captured here: the Tool outlives nothing, but
	-- the character it is equipped into at the moment of the event is the one whose Animator has to
	-- play the clip, and that is not necessarily the character this grant saw.
	table.insert(
		list,
		tool.Equipped:Connect(function()
			Horn.carryArm(player.Character, true)
		end)
	)
	table.insert(
		list,
		tool.Unequipped:Connect(function()
			Horn.carryArm(player.Character, false)
		end)
	)

	-- ONE life watcher per player, replaced at each grant rather than appended: a player granted
	-- every few seconds would otherwise leave a dead connection behind every time, for the session.
	local previous = lifeWatchers[player]
	if previous then
		previous:Disconnect()
	end
	lifeWatchers[player] = tool.AncestryChanged:Connect(function()
		if reachable(tool, player) then
			return -- equipping moves it Backpack -> Character; that is not losing it
		end
		if tools[player] == tool then
			tools[player] = nil
		end
	end)

	equip(tool, player)
	return tool
end

-- Every horn this player has, gone. Returns how many were destroyed, so a caller can assert it.
function Horn.revoke(player: Player): number
	local removed = 0
	for _, tool in ipairs(Horn.toolsOf(player)) do
		tool:Destroy()
		removed += 1
	end
	if removed > 0 then
		stats.revoked += removed
	end
	tools[player] = nil
	return removed
end

-- ---------------------------------------------------------------- who may still blow (task 168)

-- Returns the policy it replaced, exactly as `Horn.setCarryPolicy` does, so a spec can put the
-- world's own back when it is finished.
function Horn.setBlowPolicy(fn: ((string) -> boolean)?): ((string) -> boolean)?
	local previous = blowPolicy
	blowPolicy = fn
	return previous
end

-- MAY THE BODY HOLDING THIS KEY SOUND A HORN NOW? No policy means yes, which is this file before
-- task 168. A policy that throws is treated as a YES and says so in the console: a drive whose
-- predicate errored must not silence every horn in the wood, and a silent horn with no reason on
-- screen is the worst of the two failures (`Horn.mayCarry` makes the same call the other way, where
-- the conservative answer is "no horn").
function Horn.mayBlow(key: string): boolean
	local policy = blowPolicy
	if policy == nil then
		return true
	end
	local ok, answer = pcall(policy, key)
	if not ok then
		warn(string.format("[horn] blow policy errored for %s: %s", key, tostring(answer)))
		return true
	end
	return answer ~= false
end

-- ---------------------------------------------------------------- the arm raise (task 168)
--
-- THE HORN COMES UP TO THE MOUTH, ON WHOEVER BLEW IT. KAREN, 2026-10-12 ~21:45: *"we need when I am
-- playing beater to make animation when raising horn to face and blow"*.
--
-- THIS MODULE OWNS IT FOR A PLAYER and `Bots.Rig` owns it for a rig, which is one writer each of one
-- Animator each -- the pose, the sequence and the registered id are all `Horn.BLOW_POSE`'s, in
-- `src/shared/Horn`, so there is one definition of the gesture and two players of it. Everything
-- about WHY it is a registered `KeyframeSequence` is written down there.
--
-- A RIG IS LEFT ALONE HERE, AND THE CALLER IS WHAT DECIDES THAT -- not a test of the body. `Bots.Rig`
-- plays the clip itself off the bot's own `blowUntil` clock, so a raise started here as well would be
-- two tracks of one pose on one Animator. So only `Horn.blow`, the PLAYER's door, asks for the raise;
-- `Horn.blowTool`, which is what the bots call, does not.
--
-- ONE TRACK PER CHARACTER, CACHED, because `LoadAnimation` is a call per blast otherwise and a
-- beater blows every few seconds for ten minutes. The cache is dropped when the character goes
-- (`Horn.forget`, and a respawn makes a new Model so the old row is never found again).
-- WEAK-KEYED ON THE CHARACTER, so a row goes when the body does: a player who respawns twenty times
-- in a session leaves twenty dead Models behind otherwise, each holding a track.
--   https://create.roblox.com/docs/luau/metatables (`__mode = "k"`)
local raiseTracks: { [Model]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any
-- THE CARRY'S OWN CACHE (task 206), weak-keyed for `raiseTracks`' reason. Two tables and not one
-- row with two fields, because the two clips are loaded at different moments -- the blast at the
-- first blow, the carry at the first equip -- and a single row would have to carry "which half is
-- filled in" as a third fact.
local carryTracks: { [Model]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any

-- ONE CLIP ON ONE CHARACTER'S ANIMATOR, CACHED. Both of this module's two poses come through here
-- (task 206): they differ in which registered id they ask for and at what priority they play, and
-- everything else -- the cache, the Animator, the `LoadAnimation` guard -- was already identical.
local function trackFor(
	character: Model,
	cache: { [Model]: AnimationTrack },
	id: string?,
	priority: Enum.AnimationPriority
): AnimationTrack?
	-- CACHED PER CHARACTER, AND THE TEST IS THE CHARACTER'S OWN PARENT -- never the TRACK's.
	-- MEASURED in a live Play session (2026-10-12): `Animator:LoadAnimation` returns a track whose
	-- `Parent` is nil, so `existing.Parent ~= nil` was false on every blast and this loaded a second
	-- track for the same pose every time -- the live probe caught the same clip playing twice.
	local existing = cache[character]
	if existing ~= nil and character.Parent ~= nil then
		return existing
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or id == nil then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator");
		(animator :: Animator).Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	animation.Parent = humanoid
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or track == nil then
		animation:Destroy()
		return nil
	end
	-- THE PRIORITY OUTRANKS THE STOCK `Animate` SCRIPT'S WALK AND IDLE, which is the whole reason the
	-- arm moves at all: the player's own animator re-solves the shoulder from the playing tracks
	-- every frame, so only a higher-priority track can take it. Set here and not trusted to the
	-- registered sequence's stored priority, exactly as `Bots.Rig.loadClips` does not trust an
	-- asset's.
	pcall(function()
		(track :: AnimationTrack).Priority = priority
	end)
	cache[character] = track
	return track
end

local function raiseTrackFor(character: Model): AnimationTrack?
	return trackFor(character, raiseTracks, Data.blowAnimationId(Data.BLOW_POSE), Enum.AnimationPriority.Action)
end

-- THE HORN AT THE BEATER'S SIDE (task 206). KAREN, 2026-10-18: *"also horn is broken arm is wrong"*,
-- with a frame of a bot beater holding the horn straight out in front of itself.
--
-- WHY IT IS A CLIP AND NOT A GRIP. The horn was 2.30 studs in front of the chest because the ARM was
-- (measured, 2026-10-18: the arm ran 0.99 along the body's own forward on all three bot beaters) --
-- Roblox's `ToolNoneAnim`, which `Bots.Rig` plays at `Idle` and a player's own `Animate` script
-- plays for any Tool. `Tool.Grip` cannot answer that: it says where in the HAND the horn sits, so
-- moving it would pull the horn off a fist that is still out in front. The arm is what is wrong, so
-- the arm is what this changes. Every number is `Data.CARRY_POSE`'s, with its own measurements.
--
-- ON OR OFF, LEVEL-TRIGGERED, and it answers whether the pose is now playing -- so a caller counts
-- the state and not the attempt. Idempotent: `Play` on a playing track restarts the fade, which is
-- why the `IsPlaying` test is here and not in the two callers.
function Horn.carryArm(character: Model?, on: boolean): boolean
	if character == nil or character.Parent == nil then
		return false
	end
	local track =
		trackFor(character, carryTracks, Data.carryAnimationId(Data.CARRY_POSE), Enum.AnimationPriority.Movement)
	if track == nil then
		stats.carryMissed += 1
		return false
	end
	local fade = Data.CARRY_POSE.FADE_SECONDS
	if on then
		if not track.IsPlaying then
			track:Play(fade)
			stats.carried += 1
		end
		return true
	end
	if track.IsPlaying then
		track:Stop(fade)
	end
	return false
end

-- UP NOW, DOWN AFTER `seconds`. Returns whether the arm really went up, so the caller counts poses
-- and not attempts.
--
-- THE LOWER IS A `task.delay` AND IT CHECKS BEFORE IT ACTS, exactly as the `GRIP_BLOW` restore below
-- does and for the same reason: the cooldown is longer than a blast, so in practice nothing overlaps,
-- and the guard is what keeps that true if a shorter cooldown one day makes it untrue.
function Horn.raise(character: Model?, seconds: number?): boolean
	if character == nil or character.Parent == nil then
		return false
	end
	local track = raiseTrackFor(character)
	if track == nil then
		stats.raisesMissed += 1
		return false
	end
	local pose = Data.BLOW_POSE
	track:Play(pose.RAISE_SECONDS)
	stats.raised += 1
	task.delay(seconds or Data.CONFIG.BLOW_SECONDS, function()
		-- `IsPlaying` AND NOTHING ELSE, which is a MEASUREMENT and not a simplification: this line
		-- first read `track.Parent ~= nil and track.IsPlaying`, and in a live Play session of the
		-- Forest Test (2026-10-12) the arm stayed up for ever -- `Animator:LoadAnimation` returns a
		-- track whose `Parent` is nil, so the guard was false on every blast and the `Stop` never
		-- ran. The horn's own `GRIP` came back on time (that restore has no such guard), which is
		-- what made it look like a half-fixed pose rather than a dead line. `Bots.Rig.blow` never
		-- had the guard, which is why a bot's arm always came down.
		if track.IsPlaying then
			track:Stop(pose.LOWER_SECONDS)
		end
	end)
	return true
end

-- Re-evaluate now, and grant or revoke to match. Level-triggered: the Forest Test's `/beater` calls
-- it on the switch, the drive's own respawns are caught by the sweep, and calling it twice does
-- nothing the first call did not.
function Horn.refreshCarry(player: Player): string?
	local action = Horn.carryAction(Horn.mayCarry(player), Horn.held(player) ~= nil)
	if action == "grant" then
		Horn.grant(player)
	elseif action == "revoke" then
		Horn.revoke(player)
	end
	return action
end

-- ---------------------------------------------------------------- the blast

-- Is this player's horn off cooldown? PURE in its two arguments, so a spec can drive the boundary
-- without waiting three seconds.
function Horn.readyAt(lastAt: number?, now: number): boolean
	if lastAt == nil then
		return true
	end
	return now - lastAt >= Data.CONFIG.COOLDOWN
end

-- THE KEY A PLAYER'S COOLDOWN IS HELD UNDER. One function, so a userId is turned into a key in
-- exactly one place and `Horn.blow`, `Horn.ready` and `Horn.forget` cannot disagree about it.
function Horn.keyFor(userId: number): string
	return tostring(userId)
end

function Horn.ready(player: Player, now: number?): boolean
	return Horn.readyAt(lastBlast[Horn.keyFor(player.UserId)], now or os.clock())
end

-- ONE BLAST, FROM A TOOL AND A KEY -- the whole of what a blast IS, and the only place it is
-- written (task 161). `Horn.blow` below is the player's two-line door into it.
--
-- THE ORDER MATTERS AND IT IS: hold the blower to the cooldown, find out WHERE the horn is, then
-- sound it and publish. A blast that cannot be located is refused rather than published from the
-- character's root -- the note's one requirement for this stimulus is that it be REAL, from the
-- beater's own position, never a phantom (section 5.3).
--
-- WHY THIS EXISTS RATHER THAN A SECOND BLAST PATH FOR THE BOTS (docs/design/bots.md section 9.3):
-- `Horn.blow` takes a `Player` and a held `Tool`, and a bot beater has neither -- but what a blast
-- is must not be written twice. So there is ONE cooldown table, ONE measured 1.0 s cut of the asset,
-- ONE `GRIP_BLOW` tilt and ONE `Blown` signal, and a bot reaches all four through this function with
-- its own slot id as the key.
--
-- `blowerUserId` IS NIL FOR A BOT, and the drive already refuses it: `Match.creditPush(nil, ids)`
-- asks `Match.pushCreditable(nil, ...)`, whose first test is `type(userId) == "number"`. So a bot's
-- blast travels the exact wire Karen's own `/beater` blast travels, with the real reach, and pays
-- nobody.
function Horn.blowTool(tool: Tool?, key: string, blowerUserId: number?, now: number?): boolean
	if tool == nil then
		stats.refusedNoHorn += 1
		return false
	end
	local at = now or os.clock()
	if not Horn.readyAt(lastBlast[key], at) then
		stats.refusedCooldown += 1
		return false
	end
	-- HE IS THROUGH THE LINE: HIS DRIVE IS OVER AND SO IS HIS HORN (task 168). Karen: *"when beater
	-- cross the line of hunter it's done for him cant use sound anymore"*.
	--
	-- REFUSED HERE, which is the one door every blast comes through -- a player's click
	-- (`Horn.blow`), a bot's rhythm (`Bots.blowFor`) and a spec's call all land on this line, so
	-- "may he blow" cannot be answered in two places. AFTER the cooldown and BEFORE anything is
	-- written: a refused blast does not take the cooldown, does not sound, does not tilt the Tool
	-- and publishes no `Blown`, so it cannot move an animal either.
	if not Horn.mayBlow(key) then
		stats.refusedThrough += 1
		return false
	end
	local handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		stats.refusedNoHorn += 1
		return false
	end
	local where = (handle :: BasePart).Position

	lastBlast[key] = at
	stats.blasts += 1

	local sound = handle:FindFirstChild(Horn.SOUND_NAME)
	if sound ~= nil and sound:IsA("Sound") then
		-- ONE CALL OUT OF A SIXTY-SECOND RECORDING, and both numbers are measured off the asset's
		-- own loudness profile (the data file says how). From `SOUND_START` every time, so a second
		-- blast is a fresh signal and not the tail of the first; stopped at `SOUND_CUT`, which falls
		-- inside the clip's own silence, so the stop cannot click and the second call is never heard.
		sound.TimePosition = Data.CONFIG.SOUND_START
		sound:Play()
		task.delay(Data.playSeconds(Data.CONFIG), function()
			-- ONLY THIS BLAST'S STOP. `lastBlast` holds the instant this blast was accepted, so if
			-- another has been accepted since, that one owns the sound and this stop stands down.
			-- The cooldown is longer than the cut, so in practice nothing overlaps -- this is what
			-- makes that an invariant of the DATA rather than of the code.
			if lastBlast[key] == at and sound.Parent ~= nil then
				(sound :: Sound):Stop()
			end
		end)
	end

	-- RAISED TO THE MOUTH, as a tilt of the Tool's own Grip and nothing else (the data file says
	-- why). Restored after `BLOW_SECONDS`, and only if nothing else has moved it since -- the
	-- cooldown is longer than the blow, so in practice nothing can, and the guard is there so that a
	-- shorter cooldown one day cannot leave the horn stuck at the player's chin.
	local config = Data.CONFIG
	-- ...AND THE BLOWER'S OWN CAMERA IS TOLD, HERE AND NOWHERE ELSE (task 176). The first-person horn
	-- is drawn by `Camera.Viewmodel` in camera space, so it cannot see the `Grip` tilt below: what it
	-- needs is "a blast was ACCEPTED, now", and this is the one line in the game where that is true
	-- for a player and for a bot alike. An increasing number, never a time -- the reader starts its
	-- own clock on the change, so no clock has to be shared (`Horn.BLOW_ATTRIBUTE`'s own header).
	--
	-- ON THE `Tool`, NOT ON THE HANDLE OR THE PLAYER: the camera already holds the Tool (it walks up
	-- from the Handle its source hands it), the attribute replicates with it, and a Tool that goes
	-- back to the Backpack takes its own last blast with it.
	local stamped = tool:GetAttribute(Data.BLOW_ATTRIBUTE)
	tool:SetAttribute(Data.BLOW_ATTRIBUTE, (if type(stamped) == "number" then stamped else 0) + 1)
	tool.Grip = config.GRIP_BLOW
	task.delay(config.BLOW_SECONDS, function()
		if tool.Parent ~= nil and tool.Grip == config.GRIP_BLOW then
			tool.Grip = config.GRIP
		end
	end)

	blownSignal:Fire({ blowerUserId = blowerUserId, at = where })
	return true
end

-- THE PLAYER'S DOOR INTO THE ONE BLAST ABOVE: the horn she is holding, her own cooldown row, her own
-- userId on the signal.
--
-- ...AND HER ARM GOES UP WITH IT (task 168). Karen: *"we need when I am playing beater to make
-- animation when raising horn to face and blow"*. Only on an ACCEPTED blast -- a click inside the
-- cooldown, or one from a beater who is through the line, raises nothing -- and only here, because a
-- bot's raise is its own rig's (`Bots.Rig.blow`, off the same shared pose).
function Horn.blow(player: Player, now: number?): boolean
	if not Horn.blowTool(Horn.held(player), Horn.keyFor(player.UserId), player.UserId, now) then
		return false
	end
	Horn.raise(player.Character, Data.CONFIG.BLOW_SECONDS)
	return true
end

-- A HORN IN A BOT'S HAND (task 161). The Tool is the horn's and the body is `Bots.Rig`'s -- the same
-- split a player has, where `Match.Body` owns the character and this module owns the Tool in its
-- hand. No Backpack is involved, because a rig has none: `Humanoid:EquipTool` parents the Tool to
-- the character directly.
--   https://create.roblox.com/docs/reference/engine/classes/Humanoid#EquipTool
--
-- WHO MAY CARRY ONE IS NOT DECIDED HERE and is not a new rule: the caller asks `Data.carriesFor`,
-- the same pure function and the same single boundary read of the same `HORN` flag that decides for
-- a player, so with the flag off a bot beater carries nothing and blows nothing.
--
-- NO `Tool.Activated` CONNECTION, deliberately: a bot has no click, and its rhythm is `Bots`'s.
function Horn.giveTo(character: Model?): Tool?
	if character == nil or character.Parent == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	local existing = character:FindFirstChild(Data.TOOL_NAME)
	if existing ~= nil and existing:IsA("Tool") then
		return existing :: Tool
	end
	local tool = Horn.build()
	tool.Parent = character
	local worked = pcall(function()
		(humanoid :: Humanoid):EquipTool(tool)
	end)
	if not worked or tool.Parent == nil then
		tool:Destroy()
		stats.grantsMissed += 1
		return nil
	end
	stats.granted += 1
	-- REMEMBERED, so the look sweep can reach it (task 172). The registry is pruned on read, so a
	-- horn whose rig is destroyed costs one dead reference until the next sweep and nothing after it.
	table.insert(bodyTools, tool)
	stats.bodyHorns += 1
	return tool
end

-- ---------------------------------------------------------------- lifetime

function Horn.stats()
	return table.clone(stats)
end

function Horn.forget(player: Player)
	Horn.revoke(player)
	local watcher = lifeWatchers[player]
	if watcher then
		watcher:Disconnect()
	end
	lifeWatchers[player] = nil
	for _, connection in ipairs(connections[player] or {}) do
		connection:Disconnect()
	end
	connections[player] = nil
	tools[player] = nil
	lastBlast[Horn.keyFor(player.UserId)] = nil
	-- The raise track goes with the body it was loaded onto (task 168). A respawn makes a new Model,
	-- so the old row could never be found again anyway; this is what stops the table growing by one
	-- character per life for the session.
	local character = player.Character
	if character ~= nil then
		raiseTracks[character] = nil
	end
end

local function watchPlayer(player: Player)
	Horn.refreshCarry(player)
	local list = connections[player]
	if list == nil then
		list = {}
		connections[player] = list
	end
	-- A respawn destroys the character and the Tool with it, so every new character asks again.
	table.insert(
		list,
		player.CharacterAdded:Connect(function()
			Horn.refreshCarry(player)
		end)
	)
end

function Horn.start()
	assert(not started, "Horn.start() called twice")
	started = true

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		Horn.forget(player)
	end)

	-- The sweep (see `CARRY_SWEEP_SECONDS`). The only thing here that is not edge-driven, and it is
	-- here because every edge in the gun's version of this has been seen to miss.
	task.spawn(function()
		while started do
			task.wait(CARRY_SWEEP_SECONDS)
			stats.sweeps += 1
			-- ...AND THE LOOK, ON THE SAME BEAT (task 169). The mesh can land after the horns have
			-- been handed out -- `WeaponBoot` starts the systems before it preloads, on purpose --
			-- and `refreshCarry` would never notice, because the beater IS holding a horn. One call,
			-- and it does nothing at all once every horn wears the mesh.
			pcall(Horn.upgradeLook)
			for _, player in ipairs(Players:GetPlayers()) do
				-- COUNTED BEFORE IT IS FIXED: "a beater who should be holding a horn and is not" is
				-- the one number that says this system is failing, and a repair that is silently
				-- made is a repair nobody can see (Task 140's finding 1 on the gun's counter).
				if Horn.mayCarry(player) and Horn.held(player) == nil then
					stats.repairs += 1
				end
				pcall(Horn.refreshCarry, player)
			end
		end
	end)
end

-- For specs: stop the sweep and let the module be started again.
function Horn.stop()
	started = false
end

return Horn
