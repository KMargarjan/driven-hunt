--!strict
-- Weapon: the owner of every player's authoritative weapon state, of every granted Tool, and of the
-- four RemoteEvents (CLAUDE.md rule 3). It writes no boar state -- it publishes HitReported and the
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
local stats = { shots = 0, reports = 0, rateDropped = 0, badRequests = 0, granted = 0, revoked = 0 }

local hitSignal = Instance.new("BindableEvent")
local safetySignal = Instance.new("BindableEvent")
Weapon.HitReported = hitSignal.Event
Weapon.SafetyViolated = safetySignal.Event

local started = false
local remotes = nil -- resolved once in start(); Shotgun.remotes() is five WaitForChild calls
local rng = Random.new()
local castFn: Shotgun.CastFn = Cast.world
local driveLineProvider: Shotgun.DriveLineProvider? = nil

function Weapon.setCast(cast: Shotgun.CastFn?)
	castFn = cast or Cast.world
end

function Weapon.setDriveLineProvider(provider: Shotgun.DriveLineProvider?)
	driveLineProvider = provider
end

function Weapon.stats()
	return table.clone(stats)
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
local function publish(player: Player, state: WeaponState, force: boolean?)
	local now = os.clock()
	if not force then
		local allowed, bucket = Limits.allow(registry:bucket(player, "state"), now, CONFIG.STATE_RATE_LIMIT)
		registry:setBucket(player, "state", bucket)
		if not allowed then
			return
		end
	end
	local channel = remotes or Shotgun.remotes()
	channel.StateChanged:FireClient(player, Shotgun.snapshot(state, now))
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

function Weapon.grant(player: Player): Tool
	Hardware.destroy(tools[player])
	local previous = stateOf(player)
	local state = StateMachine.initial(CONFIG)
	if previous then
		local bumped = table.clone(state) :: any
		bumped.epoch = previous.epoch + 1
		state = Shotgun.deepFreeze(bumped)
	end
	setState(player, state)

	local tool = Hardware.build()
	tools[player] = tool
	connections[player] = connections[player] or {}
	Hardware.give(tool, player)
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
		setState(player, Shotgun.deepFreeze(state))
		stats.revoked += 1
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
	end

	if driveLineProvider then
		local line = driveLineProvider()
		-- `aim`, not the camera direction: a published violation must match where the pellets went.
		if line and SafetyArc.isForbidden(aim, line, CONFIG.SAFETY_ARC_HALF_DEG) then
			safetySignal:Fire(player, aim, muzzle)
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
			publish(player, state)
			return
		end
		setState(player, next)
		publish(player, next, true)
		task.wait(step.wait)
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

	if kind == "SelectAmmo" then
		local next = StateMachine.apply(state, { kind = "SelectAmmo", ammo = ammo }, now)
		setState(player, next)
		publish(player, next, true)
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
		if CONFIG.shouldArm(player) then
			Weapon.grant(player)
		end
	end
	table.insert(connections[player], player.CharacterAdded:Connect(onCharacter))
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
	Players.PlayerRemoving:Connect(function(player)
		Weapon.forget(player)
	end)
end

return Weapon
