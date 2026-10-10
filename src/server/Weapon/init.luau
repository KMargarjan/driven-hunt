--!strict
-- Weapon: the owner of every player's authoritative weapon state, of every granted Tool, and of the
-- five RemoteEvents (CLAUDE.md rule 3; the fifth, HitMarker, arrived with Milestone 1.5's hit
-- marker: one way, server -> the shooter, and the Hud is what draws it). It writes no boar state -- it publishes HitReported and the
-- boar's own owner decides what a hit means (docs/design/shotgun.md section 6) -- and it writes no
-- camera: the client reads workspace.CurrentCamera.CFrame for the aim ray and nothing more.
--
-- Pattern: one module-level owner over a pure core, the shape src/server/Boar/init.luau uses. The
-- pure modules (StateMachine, Validator, Limits, Registry, Pattern, Hits, SafetyArc) take `now`,
-- `rng`, `cast` and `ignore` as parameters, so the whole authoritative path is testable with no
-- Studio, no input harness and no boar. Cast is the only caller of Workspace:Raycast.
--   RemoteEvent security  https://create.roblox.com/docs/scripting/events/remote
--     "never trust the client": the client sends {origin, direction} and NOTHING else, so there is
--     no claimed target to reconcile and no tolerance to tune (design section 5.7).
--   BindableEvent         https://create.roblox.com/docs/reference/engine/classes/BindableEvent
--     signals, the choice docs/design/boar-ai.md already made for Despawned
--
-- Nothing happens on require: only WeaponBoot calls start(), so a spec can require this module and
-- drive the pure core with no game running.
--
-- Design: docs/design/shotgun.md (sections 3.1, 5.4, 5.5)
-- Note:   docs/research/2026-09-24-shotgun.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local Cast = require(script.Cast)
local Hardware = require(script.Hardware)
local Hits = require(script.Hits)
local Limits = require(script.Limits)
local Pattern = require(script.Pattern)
local Registry = require(script.Registry)
local SafetyArc = require(script.SafetyArc)
local Shapes = require(script.Shapes)
local StateMachine = require(script.StateMachine)
local Validator = require(script.Validator)

type WeaponState = Shotgun.WeaponState
type HitReport = Shotgun.HitReport

local Weapon = {}

-- Exported for specs only, exactly as src/server/Boar/init.luau exports Boar.Brain.
Weapon.StateMachine = StateMachine
Weapon.Validator = Validator
Weapon.Limits = Limits
Weapon.Registry = Registry
Weapon.Pattern = Pattern
Weapon.Hits = Hits
-- The weapon table and the world shape map, exported for the specs: the same reason every module
-- above is here, and the reason `rifle.spec` can drive two weapons with no Studio.
Weapon.Weapons = Weapons
Weapon.Shapes = Shapes
Weapon.SafetyArc = SafetyArc
Weapon.Cast = Cast
Weapon.Hardware = Hardware
Weapon.Shape = Shapes.BY_ID.shotgun

local CONFIG = Shotgun.CONFIG

local registry = Registry.new()
-- ONE TOOL PER WEAPON PER PLAYER (task 140). Two Tools, because the engine's own hotbar is then the
-- switch: `1` and `2` are its keys, a switch changes `Tool.Parent` and nothing on the server runs
-- but the `sync()` that already watches exactly that signal. The alternative -- one Tool rebuilt on
-- a keypress -- puts a remote into `Hardware.equip`, which is the most expensive path in the system
-- and the one that produced "the gun is in the Backpack" in tasks 34, 123, 129 and 133.
local tools: { [Player]: { [string]: Tool } } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local toolWatchers: { [Player]: { [string]: RBXScriptConnection } } = {}
-- One per player: the connection that notices the granted Tool being destroyed (Task 34).
local toolLifeWatchers: { [Player]: { [string]: RBXScriptConnection } } = {}
local stats = {
	shots = 0,
	reports = 0,
	rateDropped = 0,
	badRequests = 0,
	granted = 0,
	grantsMissed = 0, -- a tool built for a player with no Backpack: nothing recorded, tried again later
	revoked = 0,
	armingRepairs = 0, -- a sweep found a player who should be holding a gun and was not
	-- HOW EVERY EQUIP ENDED (task 129): see `Hardware.equipStats`. Copied out in `Weapon.stats`
	-- rather than kept here, because the equip itself is Hardware's.
	armingSweeps = 0, -- passes of the sweep below: 0 in a running server means it is not running
	meshUpgrades = 0, -- guns that were wearing the parts fallback when the mesh arrived (Task 76)
	meshUpgradeFails = 0, -- passes of that upgrade that ERRORED, so a silent one cannot look like a no-op
	emptySwaps = 0,
	markers = 0,
}

-- Seconds between arming sweeps. EDGE-TRIGGERED ARMING MISSES, and a miss is permanent: the drive
-- calls refreshArming on its own transitions and the weapon grants on CharacterAdded, so if the
-- answer to "may this player carry a gun" changes between two edges -- or a grant lands in the
-- Backpack a placement is about to destroy while the drive is still mid-transition -- nothing asks
-- again and the player stands in a whole drive empty-handed. Measured in a two-player drive, twice,
-- with mayCarryWeapon saying the shooter was armed (Task 34). The sweep is the level: it asks the
-- same question the same way, grants nothing a refreshArming would not, and costs one table scan.
local ARMING_SWEEP_SECONDS = 2

local hitSignal = Instance.new("BindableEvent")
local safetySignal = Instance.new("BindableEvent")
local shotSignal = Instance.new("BindableEvent")
Weapon.HitReported = hitSignal.Event
-- ({ shooterUserId: number, muzzle: Vector3, ammo: string }) -- A SHOT WAS FIRED, hit or miss, and
-- before this there was no server-side way to know that: `HitReported` is per hit and the client
-- remote below is per client. Fired once per ACCEPTED shot, so a rate-limited, invalid or unarmed
-- click publishes nothing. The name deliberately matches the remote: one fact, two audiences,
-- exactly as `HitReported` sits beside the `HitMarker` remote.
--
-- Its one listener is `MatchBoot`, which calls `Boar`'s `runtime:hearShot(muzzle, at)`: every boar
-- inside either of `SENSE`'s two radii sprints. Neither owner requires the other.
-- Design: docs/design/boar-behaviour.md section 4.5
Weapon.ShotFired = shotSignal.Event
-- (player, aim: Vector3 unit, muzzle: Vector3, stopAt: number) -- stopAt is studs from the muzzle to
-- where the shot stopped, or the ammo's range when it hit nothing. The drive needs it to tell a shot
-- that went past a driver from one that stopped in the boar in front of him (Task 35).
Weapon.SafetyViolated = safetySignal.Event

local started = false
local remotes = nil -- resolved once in start(); Shotgun.remotes() is five WaitForChild calls
local rng = Random.new()
local castFn: Shotgun.CastFn = Cast.world
local driveLineProvider: Shotgun.DriveLineProvider? = nil
-- Injected by the drive at the composition root (docs/design/drive.md section 8.5). The THIRD
-- injected provider on this owner, beside setCast and setDriveLineProvider -- the established idiom,
-- not a new mechanism. nil restores Shotgun.CONFIG.shouldArm, which is what a server with no Match
-- uses, so every tests/server/weapon_*.spec.luau is untouched.
local armingPolicy: ((Player) -> boolean)? = nil

function Weapon.setCast(cast: Shotgun.CastFn?)
	castFn = cast or Cast.world
end

function Weapon.setDriveLineProvider(provider: Shotgun.DriveLineProvider?)
	driveLineProvider = provider
end

function Weapon.setArmingPolicy(policy: ((Player) -> boolean)?)
	armingPolicy = policy
end

local function mayArm(player: Player): boolean
	if armingPolicy then
		local ok, allowed = pcall(armingPolicy, player)
		-- A policy that errors must not leave a player permanently unarmed AND must not silently
		-- arm everybody: fall back to the weapon's own default, which is what a server with no
		-- Match uses anyway.
		if ok then
			return allowed == true
		end
	end
	return CONFIG.shouldArm(player)
end

-- A Tool belongs to whatever it is parented to, and a respawn destroys both: the Backpack it is
-- sitting in AND the character it is equipped on. MEASURED in a two-player drive (Task 34): the
-- drive places players by respawning them (Match.Body.place -> LoadCharacter), the grant lands in
-- the Backpack that respawn is about to replace, and the gun dies with it a frame later. Without
-- this the record outlives the Tool, refreshArming believes the player is armed, and nobody is
-- ever granted anything again -- a Shooter walked a whole ten-minute drive with empty hands.
local function toolsOfPlayer(player: Player): { [string]: Tool }
	local held = tools[player]
	if held == nil then
		held = {}
		tools[player] = held
	end
	return held
end

local function watchTool(player: Player, tool: Tool, id: string)
	-- ONE per weapon per player, replaced at each grant rather than appended: a player who is granted
	-- every few seconds would otherwise leave a dead connection behind every time, for the session.
	local watchers = toolLifeWatchers[player]
	if watchers == nil then
		watchers = {}
		toolLifeWatchers[player] = watchers
	end
	local previous = watchers[id]
	if previous then
		previous:Disconnect()
	end
	watchers[id] = tool.AncestryChanged:Connect(function()
		-- ...AND "LOST" IS NOT ONLY `Parent == nil` (task 144). A respawn DETACHES the old Backpack
		-- -- sets its own Parent to nil -- without destroying it, so a Tool sitting in it keeps a
		-- perfectly non-nil Parent and this handler used to return here for ever. `Weapon.reachable`
		-- asks the question that matters instead: can the PLAYER get at it.
		if Weapon.reachable(tool, player) then
			return -- equipping moves it Backpack -> Character; that is not losing it
		end
		if toolsOfPlayer(player)[id] == tool then
			toolsOfPlayer(player)[id] = nil
		end
	end)
end

-- CAN THE PLAYER ACTUALLY GET AT THIS TOOL? PURE, and public so a spec can drive the one shape no
-- session reproduces on demand (task 144).
--
-- "HAS A PARENT" IS NOT THE SAME QUESTION, AND THE DIFFERENCE COST A HUNTER HIS SHOTGUN. Measured in
-- the Forest Test, 10 double-deaths: die once, then again inside `AUTO_EQUIP_DELAY_SECONDS`, and the
-- player comes back with `bag=[Rifle,RifleOpen]` and EMPTY HANDS (that trace is from task 144,
-- when the loadout still had the open-sighted rifle in it) -- and stays that way through the
-- next respawn and the one after. A census of the whole DataModel found only TWO of our Tools: the
-- shotgun was not under `game` at all. That is the shape. A respawn DETACHES the old Backpack --
-- `Parent = nil` on the Backpack, which takes it out of the tree -- but does not DESTROY it, so the
-- Tool inside keeps a non-nil Parent indefinitely. The old rule read that as "he is holding it", the
-- grant was skipped, and `watchTool`'s `Parent ~= nil` guard meant the record was never cleared
-- either. Nothing re-granted until the engine got round to destroying the detached Backpack, which
-- is why Task 141 saw it only in a long session and could not reproduce it on a fresh one.
--
-- THE LIVE CONTAINERS ARE THE ANSWER, and they are the same two `Hardware.toolsOf` already walks:
-- the Backpack the player has NOW and the character they are wearing NOW. Nothing else can be
-- reached, whatever its Parent says.
function Weapon.reachable(tool: Instance?, player: Player): boolean
	if tool == nil then
		return false
	end
	local parent = (tool :: Instance).Parent
	if parent == nil then
		return false
	end
	return parent == player:FindFirstChildOfClass("Backpack") or parent == player.Character
end

-- Does this player HOLD a gun, rather than: is one recorded against their name? A Tool goes with
-- the character it is equipped on, so a respawn -- which the drive performs on every placement --
-- destroys it, and a Tool that never reached a Backpack is parented to nil from the start. Since
-- task 144 it also goes with a Backpack that was merely DETACHED. Every one of those is a stale
-- record, and believing it leaves the player unarmed with nothing ever re-granting (Task 34).
--
-- THE RECORD IS CORRECTED ON EVERY READ, which is what makes the arming sweep a repair rather than
-- a re-statement of the same wrong answer: drop it here and the next `armingAction` says "grant".
local function holdsTool(player: Player, id: string): boolean
	local tool = toolsOfPlayer(player)[id]
	if tool == nil then
		return false
	end
	if not Weapon.reachable(tool, player) then
		toolsOfPlayer(player)[id] = nil
		return false
	end
	return true
end

-- The whole arming decision, as a pure function of the two facts it depends on. Exported so it can
-- be asserted without taking a live player's gun away: a spec that did that broke three client
-- specs, which were right to complain (Task 34).
function Weapon.armingAction(allowed: boolean, holding: boolean): string?
	if allowed and not holding then
		return "grant"
	elseif not allowed and holding then
		return "revoke"
	end
	return nil
end

-- Re-evaluate now, and grant or revoke to match. The drive calls this when a team is assigned after
-- the character already spawned -- the join-mid-drive race -- and the weapon still does the writing.
-- ...FOR EVERY WEAPON IN THE LOADOUT (task 140). `armingAction` stays pure and per weapon: a
-- hunter either carries this gun or does not, and the rifle is simply a second answer to the same
-- question. With the `RIFLE` flag off the loadout is one weapon and this is what it always was.
-- MUST THE PRIMARY'S EQUIP WAIT FOR THE ENGINE'S OWN BACKPACK GUI? PURE, public, and a function
-- of the loadout alone -- which is what makes both answers reachable in a spec while the `RIFLE`
-- flag sits at one of them (CLAUDE.md, feature flags: "a flagged path must be reachable by
-- parameter as well as by flag, or its two states cannot be tested").
--
-- ONLY WHEN MORE THAN ONE TOOL IS HANDED OVER. The hotbar bug needs two: the GUI numbers a slot the
-- first time it sees a Tool, so equipping inside the grant hides the shotgun from it and the rifle
-- takes slot 1. With ONE weapon there is no order to get wrong, and a spawn in the shipped build is
-- then bit-for-bit what it was before the rifle existed -- no half second of empty hands for a bug
-- that cannot happen (the Reviewer's note, round 1).
function Weapon.equipDelayFor(wanted: { string }): number
	return if #wanted > 1 then CONFIG.AUTO_EQUIP_DELAY_SECONDS else 0
end

-- `wanted` IS A PARAMETER WITH A DEFAULT (task 141, the Reviewer's note round 2), and it is the
-- same medicine as `Weapon.equipDelayFor` one level up: the flag's two worlds must both be
-- reachable without the flag, or the ORDER this function exists to get right can only be tested in
-- whichever world the gate happens to run in. Production passes nothing and gets `Weapons.loadout()`
-- -- the one flag read in the whole weapon system, still at that one boundary.
function Weapon.refreshArming(player: Player, loadout: { string }?)
	local allowed = mayArm(player)
	local wanted = loadout or Weapons.loadout()
	-- IN `Weapons.ORDER`, AND THE ORDER IS THE HOTBAR (task 141): see `Weapon.grant`. The engine
	-- numbers a Backpack slot by the order the Tool arrives, so granting in order IS the fix, and it
	-- only works because nothing equips in the middle of this loop any more.
	local granted = 0
	for _, id in ipairs(wanted) do
		local action = Weapon.armingAction(allowed, holdsTool(player, id))
		if action == "grant" then
			if Weapon.grant(player, id) ~= nil then
				granted += 1
			end
		elseif action == "revoke" then
			Weapon.revoke(player, id)
		end
	end
	-- THE PRIMARY GOES IN THE HAND, ONCE THE WHOLE LOADOUT IS IN THE BAG -- and only when this pass
	-- actually handed something over and the player is holding nothing. The narrow rule is
	-- deliberate, and it is the same one `Weapon.upgradeLook` follows: `AUTO_EQUIP` is about the
	-- GRANT, so a sweep must never take the rifle out of the hands of a player who chose it, and
	-- must never undo a holster.
	if CONFIG.AUTO_EQUIP and granted > 0 and Weapon.heldId(player) == nil then
		local primary = toolsOfPlayer(player)[Weapons.PRIMARY]
		if primary ~= nil then
			local delay = Weapon.equipDelayFor(wanted)
			if delay <= 0 then
				-- ONE WEAPON: no hotbar order to protect, so the spawn is exactly what it was.
				Hardware.equip(primary, player)
			else
				-- NOT IN THIS FRAME: see `Weapon.equipDelayFor` and
				-- `Shotgun.CONFIG.AUTO_EQUIP_DELAY_SECONDS`. The guards are re-read when the delay
				-- fires rather than captured: a player who picked up the rifle, holstered, died or
				-- left in that half second must not have a shotgun pushed into their hands, and the
				-- Tool itself may be gone by then.
				task.delay(delay, function()
					if primary.Parent == nil or toolsOfPlayer(player)[Weapons.PRIMARY] ~= primary then
						return
					end
					if Weapon.heldId(player) ~= nil then
						return
					end
					Hardware.equip(primary, player)
				end)
			end
		end
	end
	-- ...AND ANY WEAPON THAT IS NO LONGER IN IT GOES. Turning the flag off mid-session must take the
	-- rifle away rather than leave an unreachable Tool in the Backpack.
	for _, id in ipairs(Weapons.ids()) do
		local inLoadout = false
		for _, want in ipairs(wanted) do
			if want == id then
				inLoadout = true
				break
			end
		end
		if not inLoadout and holdsTool(player, id) then
			Weapon.revoke(player, id)
		end
	end
end

-- HOW MANY LIVE ROUNDS ARE IN THE GUN. PURE and public: the owner asks it to decide whether an
-- empty rifle should change its own magazine, and a spec asks it without a session (task 142).
function Weapon.roundsLeft(state): number
	local live = 0
	for _, chamber in ipairs(state.barrels) do
		if chamber == "Live" then
			live += 1
		end
	end
	return live
end

function Weapon.stats()
	local out = table.clone(stats)
	-- ...AND HOW THE EQUIPS ENDED, which is Hardware's own tally (task 129).
	out.equipNow = Hardware.equipStats.now
	out.equipNoCharacter = Hardware.equipStats.noCharacter
	out.equipDeferred = Hardware.equipStats.deferred
	out.equipLate = Hardware.equipStats.late
	out.equipGaveUp = Hardware.equipStats.gaveUp
	return out
end

-- Tells ONE player that something of theirs landed. One way, server -> that client only, and it
-- carries no state: the Hud decides what to draw and the weapon never draws anything (rule 3).
--
-- The weapon does not know what a boar is and does not learn here: it sends "hit" because its own
-- cast found a damageable target, and BoarBoot -- the composition root that already knows both
-- systems -- calls this again with "kill" when the BOAR's runtime says the animal died. That is the
-- same direction the damage seam already runs in (design section 6.3), so neither owner grows a
-- reference to the other.
function Weapon.markHit(player: Player, kind: string?, zone: string?)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return -- a spec's stand-in shooter, or a player who left mid-shot
	end
	local channel = remotes or Shotgun.remotes()
	stats.markers += 1
	channel.HitMarker:FireClient(player, { kind = kind or "hit", zone = zone, at = os.clock() })
end

-- The arming answer this owner actually uses, exposed so a spec can assert the pcall fallback rather
-- than infer it from whether a Tool appeared (TASKS.md 32a(d)). It decides nothing and writes
-- nothing: refreshArming is still the only thing that grants or revokes.
function Weapon.mayArmForTests(player: Player): boolean
	return mayArm(player)
end

function Weapon.trackedPlayers(): number
	return registry:count()
end

-- ONE ENTRY PER PLAYER, HOLDING ONE STATE PER WEAPON (task 140). `Registry` still keys by player
-- and still has one `forget`, which is what defect (c)'s leak assertion reads -- what changed is the
-- VALUE it holds.
type PlayerWeapons = {
	held: string?,
	states: { [string]: WeaponState },
}

local function entryOf(player: Player): PlayerWeapons
	local entry = registry:get(player) :: PlayerWeapons?
	if entry == nil then
		entry = { held = nil, states = {} }
		registry:set(player, entry)
	end
	return entry :: PlayerWeapons
end

local function stateOf(player: Player, id: string?): WeaponState?
	local entry = registry:get(player) :: PlayerWeapons?
	if entry == nil then
		return nil
	end
	return entry.states[id or entry.held or Weapons.PRIMARY]
end

-- WHICH WEAPON THIS PLAYER IS HOLDING, derived from the Tool's Parent and never stored by anybody
-- else (design 5.2). `watchEquipped`'s `sync()` is its one writer, and it writes `equipped` in the
-- same breath, so the two cannot disagree.
function Weapon.heldId(player: Player): string?
	local entry = registry:get(player) :: PlayerWeapons?
	return if entry then entry.held else nil
end

-- The row of the weapon in the player's hands, or the primary's when their hands are empty: the
-- fire path has to validate against SOMETHING, and a request from a player holding nothing is
-- refused by the reducer's own `not-equipped` a line later.
local function rowOf(player: Player)
	return Weapons.row(Weapon.heldId(player)) or Weapons.ROWS[Weapons.PRIMARY]
end
Weapon.rowOf = rowOf

function Weapon.getSnapshot(player: Player): Shotgun.WeaponSnapshot?
	local id = Weapon.heldId(player) or Weapons.PRIMARY
	local state = stateOf(player, id)
	return if state then Shotgun.snapshot(state, os.clock(), nil, id) else nil
end

-- Publishing is rate-limited per player, so a spammer cannot make the server flood its own client.
-- `bucket` NAMES WHICH BUDGET THIS PUBLISH SPENDS (task 140). nil is the old behaviour: the
-- `state` bucket at `STATE_RATE_LIMIT`, or nothing at all when `force` is set. A switch publishes
-- through the `equip` bucket instead, because the Parent-change publish used to be forced past
-- every limit and a player mashing 1/2 would flood `StateChanged` at input rate.
local function publish(
	player: Player,
	id: string,
	state: WeaponState,
	force: boolean?,
	notice: string?,
	bucket: string?,
	-- The sequence step being run right now (task 142), so the client draws the server's action
	-- instead of inferring it from a state that looks the same for two different steps.
	action: string?
)
	local now = os.clock()
	if not force or bucket ~= nil then
		local name = bucket or "state"
		local limit = if name == "equip" then CONFIG.EQUIP_RATE_LIMIT else CONFIG.STATE_RATE_LIMIT
		local allowed, next = Limits.allow(registry:bucket(player, name), now, limit)
		registry:setBucket(player, name, next)
		if not allowed then
			return
		end
	end
	local channel = remotes or Shotgun.remotes()
	channel.StateChanged:FireClient(player, Shotgun.snapshot(state, now, notice, id, action))
end

local function setState(player: Player, id: string, state: WeaponState)
	entryOf(player).states[id] = state
end

-- `equipped` is derived from the Tool's Parent, never from a client claim and never from
-- Tool.Equipped on the server (design section 5.4).
local function watchEquipped(player: Player, tool: Tool, id: string)
	local function sync()
		local entry = entryOf(player)
		local state = entry.states[id]
		if not state then
			return
		end
		local equipped = tool.Parent ~= nil and tool.Parent == player.Character
		-- ...AND WHICH WEAPON IS IN THE HAND, written by the same function in the same frame (task
		-- 140, design 5.2). Two fields that cannot disagree, because one `sync()` writes both.
		if equipped then
			entry.held = id
		elseif entry.held == id then
			entry.held = nil
		end
		local next = StateMachine.setEquipped(state, equipped)
		if next ~= state then
			setState(player, id, next)
			-- THROUGH THE `equip` BUCKET rather than forced: see `publish`.
			publish(player, id, next, true, nil, "equip")
		end
	end
	-- One watcher per weapon per player: grant() runs again on every respawn, and the old Tool's
	-- connection would otherwise live until the player left (round 1 note).
	local watchers = toolWatchers[player]
	if watchers == nil then
		watchers = {}
		toolWatchers[player] = watchers
	end
	local previous = watchers[id]
	if previous then
		previous:Disconnect()
	end
	watchers[id] = tool:GetPropertyChangedSignal("Parent"):Connect(sync)
	sync()
end

-- `id` IS WHICH WEAPON (task 140); nil is the primary, which is what every caller written before
-- the rifle means.
function Weapon.grant(player: Player, id: string?): Tool?
	local weaponId = id or Weapons.PRIMARY
	local row = Weapons.row(weaponId)
	if row == nil then
		return nil
	end
	Hardware.destroy(toolsOfPlayer(player)[weaponId])
	local previous = stateOf(player, weaponId)
	local state = StateMachine.initial(row)
	if previous then
		local bumped = table.clone(state) :: any
		bumped.epoch = previous.epoch + 1
		state = Shotgun.deepFreeze(bumped)
	end
	setState(player, weaponId, state)

	-- ONE TOOL PER PLAYER, enforced. A stray Shotgun -- one this owner lost track of, or one a
	-- caller produced while an older grant was in flight -- would survive a revoke, because revoke
	-- destroys the RECORDED tool. Nothing between build and the record below yields, so no second
	-- grant can start inside this one.
	for _, stray in Hardware.toolsOf(player, weaponId) do
		Hardware.destroy(stray)
	end

	local tool = Hardware.build(row)
	connections[player] = connections[player] or {}
	if not Hardware.give(tool, player) then
		-- No Backpack at this instant: the character is still coming, or the player is leaving.
		-- Record NOTHING and return nil, so the next refreshArming tries again instead of counting
		-- a tool that is parented to nil (Task 34: that is what left a two-player drive's shooter
		-- without a gun). The Backpack hook in watchPlayer fires when it does arrive.
		Hardware.destroy(tool)
		stats.grantsMissed += 1
		return nil
	end
	toolsOfPlayer(player)[weaponId] = tool
	watchTool(player, tool, weaponId)
	watchEquipped(player, tool, weaponId)
	-- THE EQUIP IS NOT HERE ANY MORE (task 141), and that is the whole of the hotbar-order bug.
	-- Measured by the Director in the Forest Test: the hotbar read `1 Rifle, 2 Shotgun`, against the
	-- design and against Karen's own words. The engine's Backpack numbers its slots in the order
	-- Tools ARRIVE in it, and this equipped the shotgun the instant it was granted -- which moved it
	-- OUT of the Backpack before the rifle was ever put in. So the rifle arrived into an empty
	-- Backpack and took slot 1, and the shotgun came back to slot 2 the first time it was holstered.
	--
	-- `Weapon.refreshArming` grants the whole loadout in `Weapons.ORDER` and equips the primary
	-- AFTERWARDS, so both Tools reach the Backpack in order and the hotbar is the order of the list.
	stats.granted += 1
	publish(player, weaponId, stateOf(player, weaponId) :: WeaponState, true)
	return tool
end

-- EVERY GUN'S LOOK BROUGHT UP TO DATE, AND EVERY ONE OF THEM BACK IN ITS HAND (task 123 round 9).
--
-- KAREN, playing: *"There is no weapon something is broken"*. Measured in her session, in this
-- order: the barrels template was missing when the gun was built, the handle mesh landed at 416 ms,
-- the barrels at 2096 ms, and then "upgraded 1 gun(s)". The upgrade put the mesh on and left the
-- Tool in the BACKPACK, so she stood at the stand with empty hands.
--
-- IT IS A RACE, NOT A FOREST-TEST FACT: `WeaponBoot` starts the weapon system BEFORE the preload
-- finishes, deliberately (task 74, review round 1: a stalled `LoadAsset` must not mean a gunless
-- player), so any place whose barrels asset is slow on the day hits it -- DEV included. This is the
-- one path both callers use, so both are fixed by it.
--
-- RE-EQUIPPED ONLY ON THE FRAME THE LOOK CHANGED, which is the narrow rule on purpose: a sweep that
-- re-equipped every tick would make putting the gun away impossible, and `AUTO_EQUIP` is about the
-- grant, not about overriding a player who holstered.
function Weapon.upgradeLook(): number
	return Hardware.upgradeAll(function(player: Player, tool: Tool)
		if not CONFIG.AUTO_EQUIP then
			return
		end
		local character = player.Character
		if character == nil or tool.Parent == character then
			return
		end
		-- ...AND ONLY THE WEAPON THE PLAYER IS ACTUALLY CARRYING IN THEIR HANDS (task 140). With two
		-- Tools this sweep would otherwise put BOTH in the character -- whichever upgraded last
		-- winning -- and a player who picked the shotgun would find a rifle in their hands when a
		-- mesh landed. MEASURED in the first live session of this task: the rifle ended up equipped
		-- at the spawn, against `AUTO_EQUIP`'s own rule that the PRIMARY is what goes in the hand.
		--
		-- The rule is the narrow one: re-equip the weapon that was already held, and when the
		-- player holds nothing, only the primary.
		local id = Weapons.idForToolName(tool.Name)
		local held = Weapon.heldId(player)
		if id ~= (held or Weapons.PRIMARY) then
			return
		end
		Hardware.equip(tool, player)
	end)
end

-- `id` IS WHICH WEAPON; **nil is every weapon**, which is what `Match` means when it takes a
-- player's gun away at a tie and is therefore the behaviour that must not change (task 140).
function Weapon.revoke(player: Player, id: string?)
	if id == nil then
		for _, each in ipairs(Weapons.ids()) do
			Weapon.revoke(player, each)
		end
		return
	end
	local weaponId = id
	local row = Weapons.row(weaponId)
	if row == nil then
		return
	end
	Hardware.destroy(toolsOfPlayer(player)[weaponId])
	toolsOfPlayer(player)[weaponId] = nil
	local previous = stateOf(player, weaponId)
	if previous then
		local state = table.clone(StateMachine.initial(row)) :: any
		state.epoch = previous.epoch + 1
		local reset = Shotgun.deepFreeze(state)
		setState(player, weaponId, reset)
		stats.revoked += 1
		-- AND TELL THE CLIENT (TASKS.md 35b(a)). Resetting the state without publishing it left the
		-- replica holding the snapshot from before the gun was taken, so a player tied to a tree
		-- kept an ammo readout on screen for a gun that no longer exists -- visible in
		-- .screenshots/task35-tied-to-a-tree.png. grant() publishes; revoke has to as well, or the
		-- two halves of the same owner disagree about what the player is holding.
		publish(player, weaponId, reset, true)
	end
end

-- After this, NO table in this system is keyed by that player. That is defect (c), and
-- weapon_state.spec asserts it through Registry:count().
function Weapon.forget(player: Player)
	Weapon.revoke(player)
	registry:forget(player)
	for _, watcher in pairs(toolWatchers[player] or {}) do
		watcher:Disconnect()
	end
	toolWatchers[player] = nil
	for _, watcher in pairs(toolLifeWatchers[player] or {}) do
		watcher:Disconnect()
	end
	toolLifeWatchers[player] = nil
	tools[player] = nil
	for _, connection in ipairs(connections[player] or {}) do
		connection:Disconnect()
	end
	connections[player] = nil
end

local function rootPositionOf(player: Player): Vector3?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root.Position
end

-- The ignore list for one shot: the shooter's character (which contains the equipped Tool, so the
-- gun's own Handle goes with it), plus the client effects folder IF one exists server-side, which
-- normally it does not -- client-created Instances do not replicate up (design section 2.3 item 7).
local function ignoreFor(player: Player): { Instance }
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local effects = Workspace:FindFirstChild("WeaponEffects")
	if effects then
		table.insert(ignore, effects)
	end
	return ignore
end

-- The whole server flow for one FireRequest (design section 5.5).
--
-- IT RETURNS ITS OWN DECISION (Task 80, round 2): nil when the shot was taken, otherwise the reason
-- it was not. `OnServerEvent:Connect` discards the return, so nothing about the game changes -- but a
-- caller now gets a per-call answer instead of having to infer one from a counter. That distinction
-- cost a two-player run: the first version of the handler spec asserted `stats.shots` had not moved
-- across its own window, and `stats` is ONE module-level table for the whole server, so the shooter's
-- legitimate replayed click landed in the spec's numbers and read as a forged request being accepted.
-- A return value belongs to one call and one player and cannot be raced by anybody.
-- FORWARD: the fire path starts the bolt and the sequence runner is defined below, so the name has
-- to exist first. `local` here and `function runCycle` below means the assignment lands on THIS
-- local rather than creating a global.
local runCycle

local function onFireRequest(player: Player, req: any): string?
	local now = os.clock()
	local allowed, bucket = Limits.allow(registry:bucket(player, "fire"), now, CONFIG.FIRE_RATE_LIMIT)
	registry:setBucket(player, "fire", bucket)
	if not allowed then
		stats.rateDropped += 1
		return "rate-limited"
	end

	-- WHICH WEAPON THIS SHOT IS (task 140), and every ballistic number below comes from its row.
	-- The SYSTEM's numbers -- the arc, the origin tolerance, the rate limits -- stay in
	-- `Shotgun.CONFIG`, where they belong: a rule of the drive is not a property of a gun.
	local id = Weapon.heldId(player) or Weapons.PRIMARY
	local row = Weapons.row(id) or Weapons.ROWS[Weapons.PRIMARY]
	local state = stateOf(player, id)
	if not state then
		return "untracked"
	end

	local ok, why = Validator.checkShot(req, rootPositionOf(player), CONFIG)
	if not ok then
		stats.badRequests += 1
		publish(player, id, state)
		return why or "bad-request"
	end

	local fired, reason = StateMachine.apply(state, { kind = "Fire" }, now, row)
	if reason then
		publish(player, id, state)
		return reason
	end
	local ammo = state.loaded[state.selected]
	setState(player, id, fired)

	local tool = toolsOfPlayer(player)[id]
	local muzzle = tool and Hardware.muzzlePosition(tool)
	if not muzzle then
		publish(player, id, fired)
		return "no-muzzle"
	end

	local range = row.RANGE_STUDS[ammo]
	local ignore = ignoreFor(player)
	local aimImpact = castFn(req.origin, req.direction * range, ignore)
	local aimPoint = if aimImpact then aimImpact.position else req.origin + req.direction * range

	local toAim = aimPoint - muzzle
	local aim = if toAim.Magnitude < CONFIG.MIN_AIM_DISTANCE then req.direction else toAim.Unit

	local impacts = Hits.resolve(muzzle, Pattern.directions(ammo, aim, rng, row), range, castFn, ignore)
	local reports = Hits.group(player, impacts, ammo, now, id)
	stats.shots += 1
	stats.reports += #reports
	for _, report in ipairs(reports) do
		hitSignal:Fire(report)
		-- One marker per (shot, target), not one per pellet: nine pellets on one boar is one hit.
		Weapon.markHit(player, "hit", report.zone)
	end

	if driveLineProvider then
		local line = driveLineProvider()
		-- `aim`, not the camera direction: a published violation must match where the pellets went.
		if line and SafetyArc.isForbidden(aim, line, CONFIG.SAFETY_ARC_HALF_DEG) then
			-- HOW FAR THE SHOT GOT, which is the fourth argument the drive needs (Task 35): without
			-- it a clean kill on a boar 30 studs away ties the shooter because a driver stood 80
			-- studs behind it, in line -- the pellets never got near him.
			--
			-- It is the distance from the muzzle to the AIM POINT, not `report.nearest` as
			-- docs/design/drive.md section 8.2 proposed (reviews/task-35/DESIGN_DELTA.md): with
			-- buckshot the nearest impact of a nine-pellet pattern is whichever pellet clipped the
			-- ground first, which at long range is a few studs out and would mask every violation.
			-- The aim point is where the shot was actually going.
			local stopAt = if aimImpact then (aimPoint - muzzle).Magnitude else range
			safetySignal:Fire(player, aim, muzzle, stopAt)
		end
	end

	publish(player, id, fired, true)

	-- ...AND THE BOLT WORKS ITSELF (task 140). With one chamber a manual cycle means pressing R
	-- after EVERY shot, which is a reload and not a bolt, so a weapon whose row says `AUTO_CYCLE`
	-- runs its own sequence once the trigger's own dwell has elapsed. `runCycle` is the same
	-- function `R` runs, so there is one sequence runner in the system and not two.
	if row.AUTO_CYCLE then
		task.spawn(function()
			task.wait(row.BARREL_DELAY)
			local after = stateOf(player, id)
			if after and after.epoch == fired.epoch then
				runCycle(player, id, fired.epoch)
			end
		end)
	end

	-- THE SHOT AS A FACT, FOR THE SERVER (task 118). It goes out beside the client remote below so
	-- the two can never disagree about what counted as a shot.
	--
	-- ...AND IT CARRIES WHERE THE SHOT WENT (task 149b). Not the pellet pattern -- one point, the aim
	-- ray's own impact, or the end of the range when it hit nothing. A boar hears a bang at a place,
	-- and there are TWO places: the muzzle and the far end. Karen: *"I shoot and few run and next to
	-- them another group walk"* -- the group beside the animal she hit is at `at`, not at `muzzle`.
	shotSignal:Fire({ shooterUserId = player.UserId, muzzle = muzzle, at = aimPoint, ammo = ammo })

	local points = {}
	for _, impact in ipairs(impacts) do
		table.insert(points, impact.position)
	end
	local channel = remotes or Shotgun.remotes()
	-- WHICH PIPE FIRED, AND THE FRAME TO DRAW IT IN (task 92). `state.selected` is the barrel this
	-- shot came out of -- `fired.selected` has already moved to the other one -- and `muzzleCFrame` is
	-- that barrel's own muzzle, which is what a client needs to point a flash along the bore without
	-- re-deriving the gun's orientation from a position. `muzzle` stays exactly what it was: the
	-- ballistic origin every pellet came from.
	channel.ShotFired:FireAllClients({
		shooterUserId = player.UserId,
		muzzle = muzzle,
		impacts = points,
		ammo = ammo,
		barrel = state.selected,
		muzzleCFrame = Hardware.muzzleCFrame(tool, state.selected),
	})
	return nil -- the shot was taken
end

-- Break/Load/Close are never reachable from here: Validator.checkRequest accepts only "Reload" and
-- "SelectAmmo" (defect d). The reload sequence below is the only caller of the primitives.
-- Break -> Load -> Load -> Close, the 2.0 s window both R and X run through. Uninterruptibility is
-- the reducer's, not a flag: from the first Break until Close, a second Reload is refused "is-open"
-- and every Fire is refused "is-open" (design section 5.5).
-- ONE SEQUENCE RUNNER FOR BOTH WEAPONS (task 140). The steps are `row.CYCLE` -- the shotgun's
-- four, the rifle's three -- read from data instead of built in code, and everything else here is
-- what it was: the `"no-reserve"` exception, the `"is-open"` recovery that closes a gun it left
-- open, and the trailing publish that clears the Hud's R.
-- `steps` NAMES WHICH SEQUENCE (task 142), and nil is the weapon's own cycle. A magazine rifle has
-- TWO: working the bolt after a shot (`CYCLE` -- back, forward) and changing the magazine
-- (`RELOAD` -- the box, then a bolt cycle to chamber the first round). The shotgun has one, so its
-- row carries no `RELOAD` and both callers get the same four steps they always did.
function runCycle(player: Player, id: string, epoch: number, steps: { any }?)
	local row = Weapons.row(id) or Weapons.ROWS[Weapons.PRIMARY]
	local sequence = steps or row.CYCLE
	for _, step in ipairs(sequence) do
		local state = stateOf(player, id)
		if not state or state.epoch ~= epoch then
			return -- the player respawned, was revoked, or left: abandon the sequence
		end
		local next, reason = StateMachine.apply(state, { kind = step.kind }, os.clock(), row)
		-- An empty pocket is the ONE rejection this sequence walks past: closing a gun with one
		-- shell, or none, is correct. Any other reason means the world moved under it (round 1
		-- note), so it stops and republishes rather than closing a gun the player did not ask for.
		if reason and not (step.kind == "Load" and reason == "no-reserve") then
			-- A REFUSAL AFTER `Break` USED TO LEAVE THE GUN OPEN FOR EVER (TASKS.md 24a(a)): every
			-- later Reload is refused with "is-open" and every Fire with the same, so the player is
			-- carrying a brick until they respawn. Close it before giving up. The player asked for a
			-- reload; a closed gun is the state they asked to end in, and Close after the step's own
			-- window has elapsed is the same action the sequence would have taken itself.
			if state.open then
				-- A "busy" refusal is the one this has to wait out: StateMachine.apply rejects every
				-- action while `now < busyUntil`, so an immediate Close would be refused for the same
				-- reason the step was and the gun would stay open anyway. A fraction of a second is
				-- cheaper than a gun that cannot be reloaded or fired again.
				local remaining = state.busyUntil - os.clock()
				if remaining > 0 then
					task.wait(remaining)
				end
				local closed, refused = StateMachine.apply(state, { kind = "Close" }, os.clock(), row)
				if not refused then
					setState(player, id, closed)
				end
			end
			-- BREAK, NOT RETURN: the trailing publish below is what clears the Hud's "R" once the
			-- last window has elapsed, and an abort needs it exactly as much as a finished sequence.
			break
		end
		setState(player, id, next)
		publish(player, id, next, true, nil, nil, step.kind)
		task.wait(step.wait)
	end
	-- One last publish once the final window has elapsed. Without it the newest snapshot a client
	-- ever sees is the one made at Close, whose busyFor is RELOAD_CLOSE, so the Hud keeps its "R"
	-- until something else changes the state -- which a player would read as a gun stuck reloading.
	local state = stateOf(player, id)
	if state and state.epoch == epoch then
		publish(player, id, state, true)
	end
	-- AN EMPTY RIFLE CHANGES ITS OWN MAGAZINE. Karen: *"when empty (or on R)"*. Only after the
	-- weapon's own CYCLE -- never after a reload, which would be a loop -- and only when the row
	-- asks for it, so the shotgun is untouched.
	if steps == nil and row.AUTO_RELOAD_WHEN_EMPTY and row.RELOAD ~= nil and state and state.epoch == epoch then
		if Weapon.roundsLeft(state) == 0 and (state.reserve[state.ammo] or 0) > 0 then
			runCycle(player, id, epoch, row.RELOAD)
		end
	end
end

-- Same contract as `onFireRequest` above, and the same reason for it: nil when the request was
-- acted on, otherwise the reason it was not.
local function onActionRequest(player: Player, kind: any, ammo: any): string?
	local now = os.clock()
	local allowed, bucket = Limits.allow(registry:bucket(player, "action"), now, CONFIG.ACTION_RATE_LIMIT)
	registry:setBucket(player, "action", bucket)
	if not allowed then
		stats.rateDropped += 1
		return "rate-limited"
	end

	local id = Weapon.heldId(player) or Weapons.PRIMARY
	local row = Weapons.row(id) or Weapons.ROWS[Weapons.PRIMARY]
	local state = stateOf(player, id)
	if not state then
		return "untracked"
	end

	-- THE AMMO WHITELIST IS THIS WEAPON'S (task 140): `X` on a rifle with one kind is a
	-- `bad-request` at the wire, counted like any other, with no new branch below.
	local ok, why = Validator.checkRequest(kind, ammo, row)
	if not ok then
		stats.badRequests += 1
		publish(player, id, state)
		return why or "bad-request"
	end

	-- X, since Karen's playtest of 2026-09-25: switching the type RELOADS to it. Break returns the
	-- unfired shells of the old type to their own pocket, two of the new type go in, and the gun
	-- closes -- the same 2.0 s uninterruptible window as R, and no firing during it. An empty pocket
	-- of the new type does nothing at all, and says so on the Hud.
	if kind == "SelectAmmo" then
		if not state.equipped or state.open or now < state.busyUntil then
			publish(player, id, state)
			return "not-ready"
		end
		if (state.reserve[ammo] or 0) <= 0 then
			stats.emptySwaps += 1
			publish(player, id, state, true, "NO " .. string.upper(ammo))
			return "empty-pocket"
		end
		local swapped = StateMachine.apply(state, { kind = "SelectAmmo", ammo = ammo }, now, row)
		setState(player, id, swapped)
		publish(player, id, swapped, true)
		task.spawn(runCycle, player, id, swapped.epoch, row.RELOAD)
		return nil -- the swap was accepted
	end

	-- "Reload": one thread per player. A second Reload while the action is open is rejected by the
	-- reducer's own "is-open", which is what makes the 2.0 s window uninterruptible (feel default 2).
	if not state.equipped or state.open or now < state.busyUntil then
		publish(player, id, state)
		return "not-ready"
	end
	local epoch = state.epoch
	-- R IS THE MAGAZINE CHANGE ON A WEAPON THAT HAS ONE (task 142), and the break-open sequence on
	-- one that does not: `row.RELOAD` is the whole of the difference.
	task.spawn(runCycle, player, id, epoch, row.RELOAD)
	return nil -- the reload was accepted
end

local function watchPlayer(player: Player)
	connections[player] = connections[player] or {}
	local function onCharacter()
		-- EVERY WEAPON IN THE LOADOUT, not just the primary (task 140). `refreshArming` grants what
		-- is missing and revokes what is no longer allowed, so it is idempotent and is the one path
		-- that knows how many guns a hunter carries.
		Weapon.refreshArming(player)
	end
	table.insert(connections[player], player.CharacterAdded:Connect(onCharacter))
	-- A NEW BACKPACK IS A NEW CHANCE. A respawn replaces it, and whichever order the engine
	-- delivers CharacterAdded and the new Backpack in, this is the moment a player who lost their
	-- gun with the old one can be given another (Task 34). refreshArming grants only if they are
	-- allowed one and are not already holding it, so this is idempotent.
	table.insert(
		connections[player],
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				Weapon.refreshArming(player)
			end
		end)
	)
	if player.Character then
		onCharacter()
	end
end

-- THE SEAM A FORGED REQUEST ARRIVES THROUGH, reachable by parameter as well as by remote (Task 80).
-- `OnServerEvent` can only be raised by a client, so until now the only way to test "the server
-- ignores a request it must not accept" was from a Play client, watching this player's published
-- state for a change. That test could never be sound: THIS module is the only writer of that state
-- and it rewrites it on its own schedule -- `Weapon.grant` resets it and auto-equips, the arming
-- sweep calls grant again, a Reload is a multi-step cycle -- so "the state changed" and "the forged
-- request was accepted" are the same observation from the client. Task 80 measured a client run
-- failing for the first reason and reading as the second.
--
-- These two are the SAME functions `Weapon.start` connects to the remotes, not a copy: one owner, one
-- implementation, and a spec can hand them a player and a forged payload with nothing in flight.
-- `Weapon.stats().badRequests` is the counter that says the whitelist refused it.
Weapon.onActionRequest = onActionRequest
Weapon.onFireRequest = onFireRequest

function Weapon.start()
	assert(not started, "Weapon.start() called twice")
	started = true

	remotes = Shotgun.remotes()
	remotes.FireRequest.OnServerEvent:Connect(onFireRequest)
	remotes.ActionRequest.OnServerEvent:Connect(onActionRequest)

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	-- The sweep (above). It is the only thing here that is not edge-driven, and it exists because
	-- every edge in this system has now been seen to miss.
	task.spawn(function()
		while true do
			task.wait(ARMING_SWEEP_SECONDS)
			stats.armingSweeps += 1
			for _, player in ipairs(Players:GetPlayers()) do
				local wanted = mayArm(player)
				if wanted then
					-- ...AND IT IS COUNTED PER WEAPON (task 140, the Reviewer's finding 1). This read
					-- `holdsTool(player)` with no weapon id after that function became per weapon, so
					-- the table read answered nil, the call answered false, and the counter rose on
					-- EVERY sweep for EVERY armable player -- which would have destroyed the one
					-- instrument this repo has for "a player who should be holding a gun and is
					-- not" (`reviews/task-34/REQUEST.md`: *"armingRepairs has been 0 in every run
					-- since"*).
					for _, id in ipairs(Weapons.loadout()) do
						if not holdsTool(player, id) then
							stats.armingRepairs += 1
						end
					end
				end
				pcall(Weapon.refreshArming, player)
			end
			-- AND THE LOOK, for a gun granted before the mesh landed (TASKS.md row 75a(h)).
			-- `WeaponBoot` upgrades once, the moment the preload returns; this is the same net the
			-- sweep above is -- the asset can arrive LATER than the preload budget, because a load
			-- that timed out is late rather than lost (`Loader` adopts it), and there is no signal
			-- for that. `Hardware.upgrade` is idempotent and never yields, so a pass that has
			-- nothing to do costs one child lookup per carried Tool.
			local ok, upgraded = pcall(Weapon.upgradeLook)
			if ok then
				stats.meshUpgrades += upgraded
			else
				-- COUNTED AND SAID ONCE, NOT SWALLOWED. A pcall whose failure goes nowhere is how a
				-- sweep that repairs nothing looks exactly like a sweep with nothing to repair.
				stats.meshUpgradeFails += 1
				if stats.meshUpgradeFails == 1 then
					warn(string.format("[Weapon] the mesh upgrade sweep failed: %s", tostring(upgraded)))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Weapon.forget(player)
	end)
end

return Weapon
