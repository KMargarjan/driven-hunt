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

local Cast = require(script.Cast)
local Hardware = require(script.Hardware)
local Hits = require(script.Hits)
local Limits = require(script.Limits)
local Pattern = require(script.Pattern)
local Registry = require(script.Registry)
local SafetyArc = require(script.SafetyArc)
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
Weapon.SafetyArc = SafetyArc
Weapon.Cast = Cast
Weapon.Hardware = Hardware

local CONFIG = Shotgun.CONFIG

local registry = Registry.new()
local tools: { [Player]: Tool } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local toolWatchers: { [Player]: RBXScriptConnection } = {}
-- One per player: the connection that notices the granted Tool being destroyed (Task 34).
local toolLifeWatchers: { [Player]: RBXScriptConnection } = {}
local stats = {
	shots = 0,
	reports = 0,
	rateDropped = 0,
	badRequests = 0,
	granted = 0,
	grantsMissed = 0, -- a tool built for a player with no Backpack: nothing recorded, tried again later
	revoked = 0,
	armingRepairs = 0, -- a sweep found a player who should be holding a gun and was not
	armingSweeps = 0, -- passes of the sweep below: 0 in a running server means it is not running
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
Weapon.HitReported = hitSignal.Event
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
local function watchTool(player: Player, tool: Tool)
	-- ONE per player, replaced at each grant rather than appended: a player who is granted every few
	-- seconds would otherwise leave a dead connection behind every time, for the whole session.
	local previous = toolLifeWatchers[player]
	if previous then
		previous:Disconnect()
	end
	toolLifeWatchers[player] = tool.AncestryChanged:Connect(function()
		if tool.Parent ~= nil then
			return -- equipping moves it Backpack -> Character; that is not losing it
		end
		if tools[player] == tool then
			tools[player] = nil
		end
	end)
end

-- Does this player HOLD a gun, rather than: is one recorded against their name? A Tool goes with
-- the character it is equipped on, so a respawn -- which the drive performs on every placement --
-- destroys it, and a Tool that never reached a Backpack is parented to nil from the start. Either
-- way the record is stale, and believing it leaves the player unarmed for the rest of the drive
-- with nothing ever re-granting (Task 34).
local function holdsTool(player: Player): boolean
	local tool = tools[player]
	if tool == nil then
		return false
	end
	if tool.Parent == nil then
		tools[player] = nil
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
function Weapon.refreshArming(player: Player)
	local action = Weapon.armingAction(mayArm(player), holdsTool(player))
	if action == "grant" then
		Weapon.grant(player)
	elseif action == "revoke" then
		Weapon.revoke(player)
	end
end

function Weapon.stats()
	return table.clone(stats)
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

local function stateOf(player: Player): WeaponState?
	return registry:get(player)
end

function Weapon.getSnapshot(player: Player): Shotgun.WeaponSnapshot?
	local state = stateOf(player)
	return if state then Shotgun.snapshot(state, os.clock()) else nil
end

-- Publishing is rate-limited per player, so a spammer cannot make the server flood its own client.
local function publish(player: Player, state: WeaponState, force: boolean?, notice: string?)
	local now = os.clock()
	if not force then
		local allowed, bucket = Limits.allow(registry:bucket(player, "state"), now, CONFIG.STATE_RATE_LIMIT)
		registry:setBucket(player, "state", bucket)
		if not allowed then
			return
		end
	end
	local channel = remotes or Shotgun.remotes()
	channel.StateChanged:FireClient(player, Shotgun.snapshot(state, now, notice))
end

local function setState(player: Player, state: WeaponState)
	registry:set(player, state)
end

-- `equipped` is derived from the Tool's Parent, never from a client claim and never from
-- Tool.Equipped on the server (design section 5.4).
local function watchEquipped(player: Player, tool: Tool)
	local function sync()
		local state = stateOf(player)
		if not state then
			return
		end
		local equipped = tool.Parent ~= nil and tool.Parent == player.Character
		local next = StateMachine.setEquipped(state, equipped)
		if next ~= state then
			setState(player, next)
			publish(player, next, true)
		end
	end
	-- One watcher per player: grant() runs again on every respawn, and the old Tool's connection
	-- would otherwise live until the player left (round 1 note).
	local previous = toolWatchers[player]
	if previous then
		previous:Disconnect()
	end
	toolWatchers[player] = tool:GetPropertyChangedSignal("Parent"):Connect(sync)
	sync()
end

function Weapon.grant(player: Player): Tool?
	Hardware.destroy(tools[player])
	local previous = stateOf(player)
	local state = StateMachine.initial(CONFIG)
	if previous then
		local bumped = table.clone(state) :: any
		bumped.epoch = previous.epoch + 1
		state = Shotgun.deepFreeze(bumped)
	end
	setState(player, state)

	-- ONE TOOL PER PLAYER, enforced. A stray Shotgun -- one this owner lost track of, or one a
	-- caller produced while an older grant was in flight -- would survive a revoke, because revoke
	-- destroys the RECORDED tool. Nothing between build and the record below yields, so no second
	-- grant can start inside this one.
	for _, stray in Hardware.toolsOf(player) do
		Hardware.destroy(stray)
	end

	local tool = Hardware.build()
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
	tools[player] = tool
	watchTool(player, tool)
	watchEquipped(player, tool)
	if CONFIG.AUTO_EQUIP then
		Hardware.equip(tool, player)
	end
	stats.granted += 1
	publish(player, stateOf(player) :: WeaponState, true)
	return tool
end

function Weapon.revoke(player: Player)
	Hardware.destroy(tools[player])
	tools[player] = nil
	local previous = stateOf(player)
	if previous then
		local state = table.clone(StateMachine.initial(CONFIG)) :: any
		state.epoch = previous.epoch + 1
		local reset = Shotgun.deepFreeze(state)
		setState(player, reset)
		stats.revoked += 1
		-- AND TELL THE CLIENT (TASKS.md 35b(a)). Resetting the state without publishing it left the
		-- replica holding the snapshot from before the gun was taken, so a player tied to a tree
		-- kept an ammo readout on screen for a gun that no longer exists -- visible in
		-- .screenshots/task35-tied-to-a-tree.png. grant() publishes; revoke has to as well, or the
		-- two halves of the same owner disagree about what the player is holding.
		publish(player, reset, true)
	end
end

-- After this, NO table in this system is keyed by that player. That is defect (c), and
-- weapon_state.spec asserts it through Registry:count().
function Weapon.forget(player: Player)
	Weapon.revoke(player)
	registry:forget(player)
	if toolWatchers[player] then
		toolWatchers[player]:Disconnect()
		toolWatchers[player] = nil
	end
	if toolLifeWatchers[player] then
		toolLifeWatchers[player]:Disconnect()
		toolLifeWatchers[player] = nil
	end
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
local function onFireRequest(player: Player, req: any)
	local now = os.clock()
	local allowed, bucket = Limits.allow(registry:bucket(player, "fire"), now, CONFIG.FIRE_RATE_LIMIT)
	registry:setBucket(player, "fire", bucket)
	if not allowed then
		stats.rateDropped += 1
		return
	end

	local state = stateOf(player)
	if not state then
		return
	end

	local ok = Validator.checkShot(req, rootPositionOf(player), CONFIG)
	if not ok then
		stats.badRequests += 1
		publish(player, state)
		return
	end

	local fired, reason = StateMachine.apply(state, { kind = "Fire" }, now)
	if reason then
		publish(player, state)
		return
	end
	local ammo = state.loaded[state.selected]
	setState(player, fired)

	local tool = tools[player]
	local muzzle = tool and Hardware.muzzlePosition(tool)
	if not muzzle then
		publish(player, fired)
		return
	end

	local range = CONFIG.RANGE_STUDS[ammo]
	local ignore = ignoreFor(player)
	local aimImpact = castFn(req.origin, req.direction * range, ignore)
	local aimPoint = if aimImpact then aimImpact.position else req.origin + req.direction * range

	local toAim = aimPoint - muzzle
	local aim = if toAim.Magnitude < CONFIG.MIN_AIM_DISTANCE then req.direction else toAim.Unit

	local impacts = Hits.resolve(muzzle, Pattern.directions(ammo, aim, rng, CONFIG), range, castFn, ignore)
	local reports = Hits.group(player, impacts, ammo, now)
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

	publish(player, fired, true)

	local points = {}
	for _, impact in ipairs(impacts) do
		table.insert(points, impact.position)
	end
	local channel = remotes or Shotgun.remotes()
	channel.ShotFired:FireAllClients({
		shooterUserId = player.UserId,
		muzzle = muzzle,
		impacts = points,
		ammo = ammo,
	})
end

-- Break/Load/Close are never reachable from here: Validator.checkRequest accepts only "Reload" and
-- "SelectAmmo" (defect d). The reload sequence below is the only caller of the primitives.
-- Break -> Load -> Load -> Close, the 2.0 s window both R and X run through. Uninterruptibility is
-- the reducer's, not a flag: from the first Break until Close, a second Reload is refused "is-open"
-- and every Fire is refused "is-open" (design section 5.5).
local function runReload(player: Player, epoch: number)
	local steps = {
		{ kind = "Break" :: Shotgun.ActionKind, wait = CONFIG.RELOAD_BREAK },
		{ kind = "Load" :: Shotgun.ActionKind, wait = CONFIG.RELOAD_SHELL },
		{ kind = "Load" :: Shotgun.ActionKind, wait = CONFIG.RELOAD_SHELL },
		{ kind = "Close" :: Shotgun.ActionKind, wait = CONFIG.RELOAD_CLOSE },
	}
	for _, step in ipairs(steps) do
		local state = stateOf(player)
		if not state or state.epoch ~= epoch then
			return -- the player respawned, was revoked, or left: abandon the sequence
		end
		local next, reason = StateMachine.apply(state, { kind = step.kind }, os.clock())
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
				local closed, refused = StateMachine.apply(state, { kind = "Close" }, os.clock())
				if not refused then
					setState(player, closed)
				end
			end
			-- BREAK, NOT RETURN: the trailing publish below is what clears the Hud's "R" once the
			-- last window has elapsed, and an abort needs it exactly as much as a finished sequence.
			break
		end
		setState(player, next)
		publish(player, next, true)
		task.wait(step.wait)
	end
	-- One last publish once the final window has elapsed. Without it the newest snapshot a client
	-- ever sees is the one made at Close, whose busyFor is RELOAD_CLOSE, so the Hud keeps its "R"
	-- until something else changes the state -- which a player would read as a gun stuck reloading.
	local state = stateOf(player)
	if state and state.epoch == epoch then
		publish(player, state, true)
	end
end

local function onActionRequest(player: Player, kind: any, ammo: any)
	local now = os.clock()
	local allowed, bucket = Limits.allow(registry:bucket(player, "action"), now, CONFIG.ACTION_RATE_LIMIT)
	registry:setBucket(player, "action", bucket)
	if not allowed then
		stats.rateDropped += 1
		return
	end

	local state = stateOf(player)
	if not state then
		return
	end

	local ok = Validator.checkRequest(kind, ammo)
	if not ok then
		stats.badRequests += 1
		publish(player, state)
		return
	end

	-- X, since Karen's playtest of 2026-09-25: switching the type RELOADS to it. Break returns the
	-- unfired shells of the old type to their own pocket, two of the new type go in, and the gun
	-- closes -- the same 2.0 s uninterruptible window as R, and no firing during it. An empty pocket
	-- of the new type does nothing at all, and says so on the Hud.
	if kind == "SelectAmmo" then
		if not state.equipped or state.open or now < state.busyUntil then
			publish(player, state)
			return
		end
		if (state.reserve[ammo] or 0) <= 0 then
			stats.emptySwaps += 1
			publish(player, state, true, "NO " .. string.upper(ammo))
			return
		end
		local swapped = StateMachine.apply(state, { kind = "SelectAmmo", ammo = ammo }, now)
		setState(player, swapped)
		publish(player, swapped, true)
		task.spawn(runReload, player, swapped.epoch)
		return
	end

	-- "Reload": one thread per player. A second Reload while the action is open is rejected by the
	-- reducer's own "is-open", which is what makes the 2.0 s window uninterruptible (feel default 2).
	if not state.equipped or state.open or now < state.busyUntil then
		publish(player, state)
		return
	end
	local epoch = state.epoch
	task.spawn(runReload, player, epoch)
end

local function watchPlayer(player: Player)
	connections[player] = connections[player] or {}
	local function onCharacter()
		if mayArm(player) then
			Weapon.grant(player)
		end
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
				if wanted and not holdsTool(player) then
					stats.armingRepairs += 1
				end
				pcall(Weapon.refreshArming, player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Weapon.forget(player)
	end)
end

return Weapon
