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
-- WHERE THE FIRED BARREL'S MUZZLE IS, in the frame of the `Muzzle` attachment (task 92). One
-- definition, used by the server to tell every client where to draw the flash and by the client to
-- place it on the first-person gun, because two copies of "the right pipe is +0.09" is how the left
-- barrel ends up flashing on the right.
--
-- `barrel` is 1 (right) or 2 (left); anything else is the centre, which is what a gun with one barrel
-- or an unknown index should do rather than guessing a side.
function Shotgun.barrelMuzzleOffset(barrel: number?, config): Vector3
	local config_ = config or Shotgun.CONFIG
	local x = if barrel == 1
		then config_.BARREL_HALF_GAP_STUDS
		elseif barrel == 2 then -config_.BARREL_HALF_GAP_STUDS
		else 0
	return Vector3.new(x, config_.BARREL_RISE_STUDS, 0)
end

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

	-- THE HANDLE IS THE ENVELOPE, NOT THE GUN (Task 71). Since the gun is built from parts, the
	-- Handle's own box would be a slab through the middle of it, so it is invisible and keeps its two
	-- real jobs: it is what the hand grips (GRIP), what the Muzzle attachment hangs on, and the only
	-- part of the gun a ray can hit. Set this to 0 to see the envelope the parts are laid out in.
	HANDLE_TRANSPARENCY = 1,

	-- THE GUN'S COLOURS. Director's pick and Karen's to change (her rule, 2026-09-26: styling never
	-- blocks). EVERY ONE IS ABOVE THE ALBEDO FLOOR that Task 22 measured -- an unlit face renders at
	-- roughly 0.275 x albedo at this place's ambient, which is what turned the first HANDLE_COLOR
	-- (RGB 70, 55, 45) near-black on screen -- so "blued steel" is a light gunmetal rather than the
	-- near-black it is in life, and the walnut is warm rather than dark.
	-- Shapes and proportions: src/server/Weapon/Shape.luau. Note: docs/research/2026-09-26-shotgun-model.md
	LOOK = {
		barrel = Color3.fromRGB(96, 100, 108), -- blued steel: the barrels and the top rib
		action = Color3.fromRGB(178, 180, 184), -- the silver-grey action body, lever, guard, trigger
		wood = Color3.fromRGB(165, 112, 70), -- walnut: the splinter forend and the English stock
		bead = Color3.fromRGB(242, 238, 226), -- the one bright thing on the gun
	},

	-- cosmetics
	TRACER_LIFETIME = 0.06,
	IMPACT_LIFETIME = 1.0,
	FLASH_LIFETIME = 0.05,
	EFFECT_MAX_PER_SHOT = 24, -- a hard cap, so a bug cannot flood Workspace
	-- THE FLASH COMES OUT OF THE PIPE THAT FIRED (task 92). Karen, after playing S2, 2026-09-27:
	-- "when firing this animation where flies light has to be from pipes not from shoulder."
	--
	-- BARREL 1 IS THE RIGHT TUBE and barrel 2 the left, which is the order a side-by-side with one
	-- trigger fires in, and the order `Weapon.StateMachine.selected` walks. This is the lateral
	-- half-gap between the two bores: the same number `Shape`'s BarrelLeft/BarrelRight are laid out at
	-- (+-BARREL_GAP / 2 = +-0.09), and `tests/server/weapon_look.spec.luau` asserts they still agree
	-- rather than trusting two copies of 0.09.
	BARREL_HALF_GAP_STUDS = 0.09,
	-- How far above the Muzzle attachment the bores actually are: the attachment sits on the Handle's
	-- axis, the barrels ride above it (`Shape`'s BARREL_Y).
	BARREL_RISE_STUDS = 0.12,
	-- The smoke that follows the flash: bigger, slower, grey, and gone before the next shot. MEASURED
	-- RATHER THAN CHOSEN: at the first pick, 0.45 s, seventeen screenshots taken across two sessions
	-- caught it exactly never -- the harness's own capture grabs its frame seconds into the call, and
	-- a player firing a barrel sees about as much of it as the camera did. Real muzzle smoke from a
	-- 12-gauge hangs; 1.1 s is still short, and it is what makes "the light comes from the pipes"
	-- something Karen can actually watch. The FLASH stays at 0.05 s, because a flash is instant.
	SMOKE_LIFETIME = 1.1,

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
	-- 0.35 AND 0.80, NOT 0.15 AND 0.45 (task 124). 0.15 s is four frames at 30 fps: readable only if
	-- you were already looking at the centre of the screen, which during a crossing you are not.
	-- Karen: *"we need to indicate a hit"*. Design: docs/design/drive-report.md section 4.1.
	HIT_MARK_SECONDS = 0.35,
	HIT_MARK_KILL_SECONDS = 0.8,
	-- A SOFT TICK FOR THE SHOOTER ALONE, drawn beside the marker's other numbers because it is the
	-- same cue. EMPTY IDS PLAY NOTHING AND THAT IS NOT AN ERROR -- the rule `Weapon.Sound` already
	-- states for `SOUND_SHOT_ID`: "a gun that is silent is the gun this repo has had all along; a
	-- warn per shot would be worse than the silence". Picking the two ids is Karen's.
	-- THE TWO TICKS. Karen delegated the choice ("styling decisions are mine and I delegate this one
	-- to you; Karen tunes later"), so these are the Builder's pick and they are hers to change.
	--
	-- THEY ARE ENGINE ASSETS, NOT MARKETPLACE IDS, and that is the whole reason for choosing them: a
	-- `rbxasset://` path ships inside Roblox itself, so it cannot 404, cannot be moderated away and
	-- needs no upload and no `assets/uploads.json` row. MEASURED in this place on 2026-10-05 with
	-- `ContentProvider:PreloadAsync`, reading `IsLoaded` and `TimeLength` off the real Sound:
	--     sounds/switch.wav              loaded=true  0.24 s   <- the hit
	--     sounds/electronicpingshort.wav loaded=true  0.72 s   <- the kill
	--     sounds/clickfast.wav           loaded=true  0.29 s
	--     sounds/button.wav              loaded=true  0.58 s
	--     sounds/switch3.wav             loaded=true  0.37 s
	--     sounds/impact_generic.mp3      loaded=FALSE 0.00 s   <- does not exist; not used
	--     rbxassetid://9118823103        loaded=FALSE 0.00 s   <- does not exist; not used
	-- A hit is the shortest dry tick of the five; a kill is the one sound that is unmistakably a
	-- different event, because "it died" has to be audible without looking at the colour.
	HIT_MARK_SOUND_ID = "rbxasset://sounds/switch.wav",
	HIT_MARK_KILL_SOUND_ID = "rbxasset://sounds/electronicpingshort.wav",
	HIT_MARK_VOLUME = 0.35,

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
