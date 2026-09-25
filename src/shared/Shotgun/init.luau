--!strict
-- Shotgun: the one frozen table of every shotgun number, the system's shared types, and the three
-- pure helpers both sides need. It has NO writer (CLAUDE.md rule 3): CONFIG is deep-frozen at the
-- bottom of this file and nothing in the repo may assign to it.
--
-- Pattern: a single frozen config module plus pure converters, the shape src/server/Boar/init.luau
-- already uses for CONFIG. Every angle here is in DEGREES and its field name says FULL or HALF, and
-- the ONLY conversion to radians is at the call site named in the design (section 4) -- the Task 19
-- defect (a half-angle row beside a full-angle row) made unrepeatable.
--   Luau table.freeze  https://luau.org/library#table-library -- shallow, hence deepFreeze below
--   Roblox RemoteEvent https://create.roblox.com/docs/reference/engine/classes/RemoteEvent
--   Roblox units       https://create.roblox.com/docs/physics/units  (1 stud = 0.28 m)
--
-- Design: docs/design/shotgun.md (sections 4, 5.1, 5.2, 11)
-- Note:   docs/research/2026-09-24-shotgun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = {}

export type AmmoKind = "Slug" | "Buck"
export type AmmoLoad = "Slug" | "Buck" | "None" -- "None" is a VALUE, never a hole: a sparse array
-- does not cross a RemoteEvent faithfully (design section 2.3).
export type BarrelState = "Empty" | "Live" | "Spent"

export type WeaponState = {
	equipped: boolean,
	open: boolean,
	barrels: { BarrelState },
	loaded: { AmmoLoad },
	selected: number,
	ammo: AmmoKind,
	-- Shells are carried PER TYPE (Karen, 2026-09-25): X switches type and reloads to it, and "no
	-- reserve of the new type" has to mean something.
	reserve: { [string]: number },
	busyUntil: number,
	epoch: number,
}

export type WeaponSnapshot = {
	equipped: boolean,
	open: boolean,
	barrels: { BarrelState },
	loaded: { AmmoLoad },
	selected: number,
	ammo: AmmoKind,
	reserve: { [string]: number },
	busyFor: number,
	notice: string?, -- one short line for the Hud ("NO BUCK"); nil most of the time
}

export type ActionKind = "Fire" | "Break" | "Load" | "Close" | "SelectAmmo"
export type Action = { kind: ActionKind, ammo: AmmoKind? }
export type RequestKind = "Reload" | "SelectAmmo"
export type ShotRequest = { origin: Vector3, direction: Vector3 }

export type ZoneTally = { [string]: number }
export type HitReport = {
	shooter: Player,
	target: Instance,
	zone: string,
	zones: ZoneTally,
	pellets: number,
	nearest: number,
	position: Vector3,
	normal: Vector3,
	ammo: AmmoKind,
	at: number,
}
export type ShotPayload = {
	shooterUserId: number,
	muzzle: Vector3,
	impacts: { Vector3 },
	ammo: AmmoKind,
}

export type DriveLine = { position: Vector3, normal: Vector3 }
export type DriveLineProvider = () -> DriveLine?
export type Impact = { instance: Instance, position: Vector3, normal: Vector3, distance: number }
export type CastFn = (origin: Vector3, direction: Vector3, ignore: { Instance }) -> Impact?

-- table.freeze is SHALLOW (Luau library reference): freezing CONFIG leaves CONFIG.SPREAD_FULL_DEG
-- writable, and freezing a state leaves state.barrels writable. That was defect (b) of the Task 23
-- review. Recurses over table values only; numbers, strings, Vector3, CFrame, Color3 and functions
-- are immutable or not ours to freeze.
function Shotgun.deepFreeze<T>(value: T): T
	if type(value) == "table" then
		for _, inner in pairs(value :: any) do
			if type(inner) == "table" then
				Shotgun.deepFreeze(inner)
			end
		end
		if not table.isfrozen(value :: any) then
			table.freeze(value :: any)
		end
	end
	return value
end

-- The one converter from server state to what crosses the wire: a deadline becomes a duration,
-- because os.clock() on the server means nothing on a client (design section 5.1).
function Shotgun.snapshot(state: WeaponState, now: number, notice: string?): WeaponSnapshot
	return Shotgun.deepFreeze({
		equipped = state.equipped,
		open = state.open,
		barrels = table.clone(state.barrels),
		loaded = table.clone(state.loaded),
		selected = state.selected,
		ammo = state.ammo,
		reserve = table.clone(state.reserve),
		busyFor = math.max(0, state.busyUntil - now),
		notice = notice,
	})
end

-- The one place the remote paths are spelled, so no caller hard-codes them twice.
function Shotgun.remotes()
	local folder = ReplicatedStorage:WaitForChild("Shotgun"):WaitForChild("Remotes")
	return {
		FireRequest = folder:WaitForChild("FireRequest") :: RemoteEvent,
		ActionRequest = folder:WaitForChild("ActionRequest") :: RemoteEvent,
		StateChanged = folder:WaitForChild("StateChanged") :: RemoteEvent,
		ShotFired = folder:WaitForChild("ShotFired") :: RemoteEvent,
		-- One way, server -> the shooter alone: "your pellets landed on something", and "it died".
		-- The client never fires it (hit-zones design section 14, Director item C).
		HitMarker = folder:WaitForChild("HitMarker") :: RemoteEvent,
	}
end

-- Every number the system has (design section 11). Derived at 1 stud = 0.28 m.
Shotgun.CONFIG = {
	BARRELS = 2,

	-- ballistics, keyed by AmmoKind so nothing branches on ammo
	RANGE_STUDS = { Slug = 330, Buck = 100 }, -- note: 100 yd and 30 yd MPR
	PELLETS = { Slug = 1, Buck = 9 }, -- note: 00 buck
	-- DEGREES, FULL cone, both of them. Halved exactly once, in Pattern.directions.
	SPREAD_FULL_DEG = { Slug = 0.16, Buck = 1.6 },
	SLUG_CAST_RADIUS = 0, -- a pure raycast; Spherecast forgiveness is Karen's dial if she misses

	-- timings, all feel numbers
	BARREL_DELAY = 0.25,
	RELOAD_BREAK = 0.5,
	RELOAD_SHELL = 0.45,
	RELOAD_CLOSE = 0.6,
	RELOAD_TOTAL = 2.0, -- BREAK + 2 * SHELL + CLOSE; weapon_state.spec asserts the sum

	-- Per ammo type, and 24 of each is ~12 reloads of that type in a 10-minute drive. One pocket
	-- per type is what makes X ("switch and reload to it") refusable when that pocket is empty.
	START_RESERVE = { Slug = 24, Buck = 24 },
	INITIAL_AMMO = "Slug" :: AmmoKind,
	AUTO_EQUIP = true, -- a grey-box playtest should not start by hunting for the hotbar

	-- validation
	CAMERA_ORIGIN_TOLERANCE = 30, -- studs from HumanoidRootPart; the stock camera sits behind you
	MIN_AIM_DISTANCE = 4, -- below this the muzzle->aim vector is degenerate
	DIR_UNIT_TOLERANCE = 1e-3,
	SAFETY_ARC_HALF_DEG = 45, -- DEGREES, HALF angle: a different quantity from a spread cone

	-- rates, per player
	FIRE_RATE_LIMIT = 6, -- received requests/s
	ACTION_RATE_LIMIT = 10,
	STATE_RATE_LIMIT = 20,

	-- the hardware
	HANDLE_SIZE = Vector3.new(0.4, 0.5, 4.4), -- 4.4 studs ~ 1.23 m
	-- Grey-box wood-brown, and the design said to check it on screen. I did: RGB(70, 55, 45) read
	-- near-black in the Play screenshot against the arena's near-white floor -- the same albedo x
	-- ambient trap Task 22 fixed for the boar (an unlit face gets Lighting.Ambient alone, 0.275
	-- here). Raised so the gun reads as a warm brown object in the hand. Karen's dial.
	HANDLE_COLOR = Color3.fromRGB(190, 145, 95),
	GRIP = CFrame.new(0, 0, 1.4), -- the Handle's -Z is the muzzle, so the barrel points away
	MUZZLE_OFFSET = Vector3.new(0, 0, -2.2), -- half of HANDLE_SIZE.Z: the barrel tip

	-- cosmetics
	TRACER_LIFETIME = 0.06,
	IMPACT_LIFETIME = 1.0,
	FLASH_LIFETIME = 0.05,
	EFFECT_MAX_PER_SHOT = 24, -- a hard cap, so a bug cannot flood Workspace

	-- the Hud
	-- The hit marker (Director decision, 2026-09-25, on hit-zones design section 14 item C): Karen's
	-- playtest said she could not tell whether she was hitting anything. A short tick on a confirmed
	-- hit, a longer red one on a kill. No sound yet. Karen's dials.
	HIT_MARK_ENABLED = true,
	HIT_MARK_ARM_PX = 9,
	HIT_MARK_GAP_PX = 6,
	HIT_MARK_THICK_PX = 2,
	HIT_MARK_COLOR = Color3.fromRGB(255, 255, 255),
	HIT_MARK_KILL_COLOR = Color3.fromRGB(235, 70, 55),
	HIT_MARK_SECONDS = 0.15,
	HIT_MARK_KILL_SECONDS = 0.45,

	CROSSHAIR_ENABLED = true,
	CROSSHAIR_ARM_PX = 8,
	CROSSHAIR_GAP_PX = 5,
	CROSSHAIR_THICK_PX = 2,
	CROSSHAIR_COLOR = Color3.fromRGB(255, 255, 255),
	HUD_TEXT_SIZE = 18,

	CAMERA_DRIFT_TOLERANCE = 0.5, -- studs the camera may drift relative to its subject (13.3)

	-- The one function that decides who carries a gun, mirroring Boar.CONFIG.isThreat.
	-- ROADMAP 1.7 makes this `player.Team == Teams.Shooters` and touches nothing else.
	shouldArm = function(_player: Player): boolean
		return true
	end,
}

Shotgun.deepFreeze(Shotgun.CONFIG)

return Shotgun
