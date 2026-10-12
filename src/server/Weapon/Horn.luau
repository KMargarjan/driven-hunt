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
	equippedNow = 0,
	equippedLate = 0,
	equipGaveUp = 0,
	sweeps = 0,
	repairs = 0,
}

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

	for _, piece in ipairs(Data.pieces(config)) do
		Hardware.addPiece(handle, piece)
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
	tool.Grip = config.GRIP_BLOW
	task.delay(config.BLOW_SECONDS, function()
		if tool.Parent ~= nil and tool.Grip == config.GRIP_BLOW then
			tool.Grip = config.GRIP
		end
	end)

	blownSignal:Fire({ blowerUserId = blowerUserId, at = where })
	return true
end

-- THE PLAYER'S DOOR INTO THE ONE BLAST ABOVE. Its behaviour is unchanged: the horn she is holding,
-- her own cooldown row, her own userId on the signal.
function Horn.blow(player: Player, now: number?): boolean
	return Horn.blowTool(Horn.held(player), Horn.keyFor(player.UserId), player.UserId, now)
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
