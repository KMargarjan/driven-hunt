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
	-- WHICH POCKETS DO NOT GO DOWN (task 221). Karen, 2026-10-20: *"Unlimited amunition"*.
	--
	-- IT IS THE POCKET AND NOT THE GUN. The barrels still hold two, he still breaks the action and
	-- he still loads: nothing in `Fire`, `Break` or `Close` reads this, because a reload that no
	-- longer costs a keypress would change the FEEL of the weapon, and that is Karen's to judge.
	--
	-- `{}` BY DEFAULT, which is every state in a build where nobody bought it. The ALLOWANCE is
	-- `Shop.startFor`'s -- it says which kinds he may be issued at all -- and this is only the
	-- consequence inside the one owner of a weapon state.
	unlimited: { [string]: boolean },
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
	-- WHICH POCKETS DO NOT GO DOWN (task 221). ABSENT, not an empty table, when nobody in this build
	-- bought it -- so a snapshot in such a build is byte-identical to the one before this task.
	unlimited: { [string]: boolean }?,
	reserve: { [string]: number },
	busyFor: number,
	-- The step the server's own sequence is running (task 142): "Magazine", "Break", "Close",
	-- "Load", or nil when nothing is. The client draws from this instead of guessing it.
	action: string?,
	notice: string?, -- one short line for the Hud ("NO BUCK"); nil most of the time
	-- WHY THE LAST TRIGGER PULL DID NOTHING (task 171): one of `Weapon.Rules.REASON`, or nil, which
	-- is almost always. It is on the wire because the client cannot infer it -- a refused shot leaves
	-- the state exactly as it was, which is also what the replica sees when nobody pulled the trigger
	-- at all. The client turns it into one dry click; `notice` is the line on the readout.
	refused: string?,
	-- THE GATE THAT **WOULD** REFUSE HIM, ASKED BECAUSE HE AIMED (task 238) -- one of
	-- `Weapon.Rules.REASON`, or nil, which is almost always.
	--
	-- IT IS A DIFFERENT FACT FROM `refused` ABOVE AND MUST NEVER SHARE ITS FIELD. `refused` is *"the
	-- trigger you pulled did nothing"*, and `CameraBoot.client.luau` is already wired to play one
	-- dry click on every arriving snapshot that carries one. `advice` is *"if you pulled the trigger
	-- now, this is what would stop you"* -- nobody pulled anything, so nothing clicks, nothing is
	-- spent and the readout's `notice` stays empty. Putting the aim answer in `refused` would click
	-- the gun dry for merely looking at a deer.
	--
	-- Karen, 2026-10-21: *"if you dont have a license when you aim and what to shoot it shows popup
	-- you dont have license"*. Note: docs/research/2026-10-22-licence-popup-and-robux.md section 3.2
	advice: string?,
	-- WHICH WEAPON THIS STATE BELONGS TO (task 140). The readout follows the STATE, and the drawn
	-- gun follows the Instance -- the two routes and the boundary between them are design 5.2.
	weapon: string?,
}

-- `Magazine` IS TASK 142'S ONE NEW PRIMITIVE, and it is one because a magazine change is ONE
-- movement: the left hand takes the empty box out from under the action and puts a full one in.
-- Feeding three rounds through `Load` would be a stripper clip, which is a different gun.
-- `Refill` IS TASK 171'S: the drive putting `START_RESERVE` back in the pocket at the start of a
-- drive. Server-side only -- `Validator.checkRequest` accepts "Reload" and "SelectAmmo" and nothing
-- else over the wire -- and it touches the pocket, never what is in the gun.
export type ActionKind = "Fire" | "Break" | "Load" | "Close" | "SelectAmmo" | "Magazine" | "Refill"
-- `reserve` IS THE PLAYER'S OWN PER-DRIVE POCKET (task 178), read ONLY by the `Refill` branch of
-- `StateMachine.apply`. It is safe at the wire BY CONSTRUCTION: `Validator.checkRequest` accepts
-- only "Reload" and "SelectAmmo" from a client, so no client can send a `Refill` at all, let alone
-- one naming its own reserve. nil means the weapon's own `START_RESERVE`.
-- `ejects` OVERRIDES `CYCLE_EJECTS` FOR ONE `Break` (task 244), and it exists for exactly one
-- caller: the reload that a SHELL-TYPE SWAP runs. Working the bolt after a shot throws the fired
-- case and leaves the rest of the magazine alone (`"spent"`); deliberately CHANGING the
-- ammunition has to empty the gun of the old kind first, or a tube already full of buckshot takes
-- no slugs and the gun goes on firing buck with SLUG on the readout -- which is Karen's
-- 2026-10-22 defect, measured in `weapon_ammo.spec`. nil keeps the weapon's own rule, which is
-- every caller written before this.
export type Action = { kind: ActionKind, ammo: AmmoKind?, reserve: { [string]: number }?, ejects: ("all" | "spent")? }
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
	-- WHICH GUN MADE THIS HIT (task 140): a `Weapons.WeaponId`, carried as a plain string so this
	-- module keeps requiring nothing. nil is legal and means "a record from before the rifle".
	weapon: string?,
	-- WHERE EVERY PELLET OF THIS SHOT STRUCK THIS TARGET (task 198), in the order they landed.
	-- The report itself is still ONE per (shot, target) and `position` above is still the NEAREST
	-- impact; this is the detail underneath it, and it is what the hit card draws a red dot per.
	-- Optional, because a report written by anything older than task 198 carries none.
	points: { { position: Vector3, zone: string } }?,
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
-- `material` IS THE SURFACE THE PELLET LANDED ON (task 249) and it is OPTIONAL, because a spec
-- that hands `Flight` its own cast function has always built these tables by hand and must keep
-- working unchanged.
export type Impact = {
	instance: Instance,
	position: Vector3,
	normal: Vector3,
	distance: number,
	material: Enum.Material?,
}
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
-- `action` IS THE STEP THE SERVER IS RUNNING RIGHT NOW (task 142), nil when it is running none.
--
-- IT IS ON THE WIRE BECAUSE IT CANNOT BE INFERRED. The magazine change applies at the START of its
-- own window -- the chambers are full for the whole 1.35 s the hands are still swapping the box --
-- so a client watching the replica sees a full gun and a `busyFor`, which is also what the first
-- moments of a bolt cycle look like. The first build of this guessed from "no live rounds, action
-- shut, still busy" and the condition could never be true: measured in the Forest Test, the drawn
-- magazine never moved once. What the client is drawing is the SERVER's action, so the server says
-- which one it is.
function Shotgun.snapshot(
	state: WeaponState,
	now: number,
	notice: string?,
	weapon: string?,
	action: string?,
	refused: string?,
	-- LAST, so every call written before task 238 is unchanged and passes nil (see `advice` on
	-- `WeaponSnapshot`).
	advice: string?
): WeaponSnapshot
	return Shotgun.deepFreeze({
		action = action,
		refused = refused,
		advice = advice,
		equipped = state.equipped,
		open = state.open,
		barrels = table.clone(state.barrels),
		loaded = table.clone(state.loaded),
		selected = state.selected,
		ammo = state.ammo,
		reserve = table.clone(state.reserve),
		-- ONLY WHEN THERE IS ONE (task 221): `nil` rather than `{}` in a build where nobody bought
		-- unlimited ammunition, so the snapshot is byte-identical to the one before this task and a
		-- client that never heard of the field reads exactly what it always did.
		unlimited = if state.unlimited ~= nil and next(state.unlimited) ~= nil
			then table.clone(state.unlimited)
			else nil,
		busyFor = math.max(0, state.busyUntil - now),
		notice = notice,
		weapon = weapon,
	})
end

-- ---------------------------------------------------------------- WHAT THE GUN NEEDS (task 248)
--
-- KAREN, 2026-10-23: *"when magazine is empty we need to show reload R letter higlight / also if no
-- rounds at all tell no ammo"*. Two different states that look identical on today's readout -- a gun
-- you can fill and a gun you cannot -- so this is the ONE answer to which of the three a weapon is
-- in, read by BOTH SIDES: the server publishes the notice from it (`Weapon.onFireRequest`'s
-- `barrel-empty` branch) and the Hud highlights the rail's R and prints the chip from it
-- (`Hud.ammoChipFor`). Two readers, one definition -- or the screen and the gun would disagree about
-- whether there is anything left to load, which is the shape of defect `docs/PROJECT_CONTEXT.md`
-- opens with.
--
-- PURE, AND IT TAKES A `WeaponState` **OR** A `WeaponSnapshot`: it reads `barrels`, `reserve` and
-- `unlimited`, which both carry with the same meaning (that is what the snapshot is FOR).
Shotgun.AMMO_NEED = table.freeze({
	-- There is something in the gun to fire. Nothing is said and nothing is highlighted: Karen's
	-- rule is a clear screen.
	OK = "ok",
	-- NOTHING IN THE GUN AND SOMETHING IN THE POCKET: press R. This is the state the highlight is
	-- for, and it ends the moment the reload starts.
	RELOAD = "reload",
	-- NOTHING IN THE GUN AND NOTHING ANYWHERE: `NO AMMO`. Pressing R would do nothing at all, which
	-- is exactly why the player has to be told something else.
	EMPTY = "empty",
})

-- THE TRIGGER PULLED ON A GUN WITH NOTHING ANYWHERE (task 248), as two wire values spelled once.
-- The server puts them on the refusal publish and the client reads them back: `refused` is what
-- makes one dry click (`CameraBoot`) and the centre line (`Hud.calloutFor`), and the NOTICE is the
-- words. Both sides read THESE, so the readout, the centre line and the server cannot disagree
-- about what an empty gun is called.
--
-- IT IS NOT A `Weapon.Rules.REASON` AND THAT IS DELIBERATE: those are rules of the DRIVE (a beater
-- in the ray, a stand, a licence, the safety lock) and this is the MECHANICAL state of a gun -- the
-- distinction `onFireRequest` already makes by asking the reducer before the rules.
Shotgun.REFUSED_NO_AMMO = "no-ammo"
Shotgun.NOTICE_NO_AMMO = "NO AMMO"

-- THE SAFETY LOCK'S WIRE VALUE LIVES HERE TOO (task 248), and `Weapon.Rules.REASON.UNSAFE` IS this
-- string -- that file reads it from here rather than spelling it a second time. It is here because
-- the CLIENT has to name it: `Weapon.Rules` is `ServerScriptService.Weapon.Rules` and no client can
-- require it, so without this the Hud would have to carry its own copy of a wire value -- which is
-- the two-definitions defect this module exists to prevent (`Shotgun.CONFIG`'s own rule about the
-- gun's numbers).
--
-- WHAT IT IS FOR, on the client: `Hud.calloutFor` draws the centre line off it. The WORDS still come
-- from the server, in the snapshot's `notice` -- `Rules.NOTICE` owns those -- so this is the REASON
-- and never the sentence.
Shotgun.REFUSED_UNSAFE = "unsafe-line"

-- `NOTHING IN THE GUN` IS "NO CHAMBER IS LIVE" AND NOT "THE SELECTED CHAMBER IS EMPTY", and that is
-- a decision: a side-by-side with one barrel left can still be fired, and a HUD that nagged about a
-- half-full gun would be lit for most of a drive. The highlight means *"the trigger will do nothing
-- until you reload"*.
--
-- `NOTHING ANYWHERE` IS EVERY KIND AND NOT THE SELECTED ONE, because `R` on an empty pocket of slugs
-- with buckshot still in the belt is a reload that works (the readout's own `NO SLUG` notice is what
-- covers the per-kind case, and it has since Karen's playtest of 2026-09-25). An UNLIMITED pocket
-- (task 221) is never empty, whatever the number beside it says.
function Shotgun.ammoNeed(state: any?, row: any?): string
	if state == nil then
		return Shotgun.AMMO_NEED.OK -- no gun is not an empty gun: there is nothing to say
	end
	for _, barrel in ipairs(state.barrels or {}) do
		if barrel == "Live" then
			return Shotgun.AMMO_NEED.OK
		end
	end
	local reserve = state.reserve or {}
	local unlimited = state.unlimited
	-- THE KINDS THIS WEAPON HAS, or whatever the state happens to carry when no row was handed in
	-- (every caller before a `Weapons.Row` existed, and every spec that builds a state by hand).
	local kinds = if row ~= nil and row.AMMO_KINDS ~= nil then row.AMMO_KINDS else nil
	if kinds ~= nil then
		for _, kind in ipairs(kinds) do
			if (reserve[kind] or 0) > 0 or (unlimited ~= nil and unlimited[kind] == true) then
				return Shotgun.AMMO_NEED.RELOAD
			end
		end
	else
		for kind, count in pairs(reserve) do
			if count > 0 or (unlimited ~= nil and unlimited[kind] == true) then
				return Shotgun.AMMO_NEED.RELOAD
			end
		end
	end
	return Shotgun.AMMO_NEED.EMPTY
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
		-- WHERE THE SHOT LANDED, once the bullet got there (task 185). One way, server -> all
		-- clients, fired by `ServerScriptService.Weapon` alone, and it carries nothing but the
		-- shooter and the impact points: no target, no zone, no damage, no state. It is where the
		-- DUST goes. The flash, the smoke, the sound and the recoil stay on `ShotFired`, at the
		-- trigger -- the bang is now and the dust is when the bullet arrives, which is the one thing
		-- on screen that says a shot takes time (design section 7).
		ShotLanded = folder:WaitForChild("ShotLanded") :: RemoteEvent,
		-- One way, server -> the shooter alone: "your pellets landed on something", and "it died".
		-- The client never fires it (hit-zones design section 14, Director item C).
		HitMarker = folder:WaitForChild("HitMarker") :: RemoteEvent,
	}
end

-- ONE SOURCE FOR THE DRIVE'S SHELLS (task 171), because a table literal cannot read its own
-- field: `DRIVE_SHELLS` below and both pockets of `START_RESERVE` are this local, so the number
-- cannot be changed in one place and left in the other. The idiom `Boar.CONFIG`'s `WALK_MAX_RATE`
-- already uses.
local DRIVE_SHELLS = 12

-- Every number the system has (design section 11). Derived at 1 stud = 0.28 m.
Shotgun.CONFIG = {
	BARRELS = 2,

	-- ballistics, keyed by AmmoKind so nothing branches on ammo
	RANGE_STUDS = { Slug = 330, Buck = 100 }, -- note: 100 yd and 30 yd MPR
	PELLETS = { Slug = 1, Buck = 9 }, -- note: 00 buck
	-- DEGREES, FULL cone, both of them. Halved exactly once, in Pattern.directions.
	SPREAD_FULL_DEG = { Slug = 0.16, Buck = 1.6 },
	SLUG_CAST_RADIUS = 0, -- a pure raycast; Spherecast forgiveness is Karen's dial if she misses

	-- HOW FAST THE SHOT LEAVES, HOW FAST IT SLOWS, AND WHERE IT IS ZEROED (task 185). Karen,
	-- 2026-10-14: *"when I shoot in running animal I need to aim a bit in front based on speed
	-- distance ect"*, and then *"same with s/s"* -- so the side-by-side flies too. Keyed by
	-- `AmmoKind` like every other ballistic number here, and the unit is in the name.
	--
	-- REAL CARTRIDGES (research note section 2C): the 12 ga rifled slug leaves at 1610 fps =
	-- 490.7 m/s = 1752 studs/s, and 00 buckshot at 1325 fps = 403.9 m/s = 1442 studs/s. The slug
	-- leaves at two thirds of the rifle's speed and loses it four times as fast, which is WHY a
	-- crossing boar needs ~60% more lead with the shotgun than with the rifle -- the content of
	-- Karen's second sentence.
	MUZZLE_STUDS_PER_S = { Slug = 1752, Buck = 1442 },
	-- QUADRATIC DRAG AS ONE COEFFICIENT PER AMMO: `v(s) = v0*exp(-k*s)`, per STUD. Fitted to the
	-- published remaining velocities (slug 1610 -> 1139 fps over 100 yd; 00 buck 1325 -> ~940 fps
	-- over 40 yd). A lead sphere sheds speed fast, which is why buckshot's coefficient is six times
	-- the rifle's. `Ballistics` is the one place this is integrated.
	DRAG_PER_STUD = { Slug = 1.059e-3, Buck = 2.631e-3 },
	-- WHERE THE TRAJECTORY CROSSES THE SIGHT LINE, so a STILL target at that distance is hit dead
	-- centre. 180 studs is 50 m -- the standard rifled-slug zero -- and 70 studs is 20 m, inside
	-- buckshot's 30 yd MPR. The slug then prints 11.4 cm low at 92 m against Federal's published
	-- 14.5 cm at 100 yd for one specific load quoted from a sight line 1.5 in above the bore, which
	-- this model does not have: the same shot to about 3 cm, against a number nothing here was
	-- fitted to. Buckshot's drop over its whole 100-stud reach is 1 cm -- it needs no holdover.
	ZERO_STUDS = { Slug = 180, Buck = 70 },
	-- REAL GRAVITY, UNCHANGED (task 189). The rifle's bullet is flattened to 0.12 because Karen asked
	-- for a standing shot that is dead on at 100 and 150 m (`Rifle.CONFIG.GRAVITY_SCALE`); she asked
	-- that of THE RIFLE, and a shotgun is a short-range gun whose drop is part of what it is -- the
	-- slug is 11.4 cm low at the end of its own 330-stud range, and buck 4.2 cm at 42 m. Changing it
	-- here would be changing a feel nobody complained about. 1.0 is what every shot flew at before
	-- this field existed, so the two shotgun ammos are bit-for-bit task 185's.
	GRAVITY_SCALE = { Slug = 1.0, Buck = 1.0 },

	-- timings, all feel numbers
	BARREL_DELAY = 0.25,
	RELOAD_BREAK = 0.5,
	RELOAD_SHELL = 0.45,
	RELOAD_CLOSE = 0.6,
	RELOAD_TOTAL = 2.0, -- BREAK + 2 * SHELL + CLOSE; weapon_state.spec asserts the sum

	-- HOW MANY SHELLS A DRIVE GIVES YOU (task 171). KAREN, 2026-10-10: *"Rifle they has to purchase
	-- default is double barrel shotgun with limited ammon per round"*. 12 is her number, read off the
	-- dispatch, and it is **per ammo type**: the reducer carries one pocket per type (which is what
	-- makes X -- "switch and reload to it" -- refusable when that pocket is empty), so a pool of 12
	-- shared between Slug and Buck would change what `state.reserve` MEANS to the Hud's readout, to
	-- the rifle's row and to the reducer's three reserve sites. A hunter shoots one kind at a time;
	-- 12 is six double loads, and the drive refills it once (`Weapon.refillForDrive`, keyed by the
	-- drive number so dying is not a resupply). A single pool is Karen's to ask for.
	--
	-- It was 24 of each from task 24 until today: the number that made ammunition effectively
	-- unlimited (~12 reloads of a type in a 10-minute drive), which is what she has now asked to end.
	DRIVE_SHELLS = DRIVE_SHELLS,
	START_RESERVE = { Slug = DRIVE_SHELLS, Buck = DRIVE_SHELLS },
	-- WHAT THE READOUT PRINTS WHERE THE POCKET COUNT WOULD BE, for a pocket that does not go down
	-- (task 221, `WeaponState.unlimited`). Three ASCII characters, in the slot the two-digit count
	-- already occupies, so no width moves.
	--
	-- DELIBERATELY NOT `--`: in this repo `--` means UNKNOWN (`Money.UNKNOWN`, and the balance of a
	-- player whose profile did not open), and an unlimited pocket is the opposite of unknown.
	-- Karen's to change (docs/design/economy-v1.md section 17, K-2); the mechanism is settled
	-- either way. It lives here because the readout is the WEAPON's.
	POCKET_UNLIMITED_TEXT = "INF",
	-- WHAT THE 12-GAUGE SHELL IS -- WHICH LOADS EXIST, WHAT EACH IS CALLED ON SCREEN, AND WHICH
	-- GLYPH DRAWS IT. These three were literals inside `Weapons.ROWS.shotgun` until task 225, which
	-- was right while one gun fired this shell and wrong the moment a second did: they are facts
	-- about the CARTRIDGE and not about the gun, so they live beside the cartridge's ballistics and
	-- both shotgun rows read them. No value moved.
	--
	-- THE WIRE WORD IS `Slug` ON ALL FOUR GUNS, because `Boar.Wound.damageFor` branches
	-- `if ammo == "Slug"` and any new string would be charged as a buckshot PELLET. The word on
	-- screen is `AMMO_LABEL`'s business and the Hud's alone (`Hud.readoutFor`).
	AMMO_KINDS = { "Slug", "Buck" },
	AMMO_LABEL = { Slug = "SLUG", Buck = "BUCK" },
	-- THE ONLY SHELL IN THE GAME THAT HAS TWO LOADS, so the only ammunition that carries this (task
	-- 204). It sits beside `AMMO_LABEL` for the same reason: the wire says `Slug` for the rifles too,
	-- so a glyph keyed off the wire word alone would draw a shotgun shell for a .416 Rigby cartridge.
	AMMO_GLYPH = { Slug = "slug", Buck = "buck" },
	INITIAL_AMMO = "Slug" :: AmmoKind,
	AUTO_EQUIP = true, -- a grey-box playtest should not start by hunting for the hotbar
	-- ...AND NOT IN THE SAME FRAME AS THE GRANT (task 141). THE HOTBAR'S ORDER IS NOT OURS: the
	-- engine's own Backpack GUI numbers a slot the first time it SEES a Tool, and once numbered the
	-- slot is stable -- MEASURED: unequipping a weapon left both slots exactly where they were. At a
	-- spawn that GUI is still being built when the grant lands, so it learns the loadout by
	-- enumerating what it finds: the Backpack first, and the equipped Tool after. Equipping the
	-- shotgun in the grant's own frame therefore put it in the CHARACTER before the GUI looked, so
	-- the rifle took slot 1 and the shotgun slot 2 -- against the design and against Karen, who
	-- asked for 1 = shotgun, 2 = rifle.
	--
	-- Half a second is after the GUI's own enumeration and far inside the time a player takes to
	-- look at anything. It is a SYSTEM number, not a weapon's: every weapon is granted by the same
	-- sweep into the same hotbar.
	--
	-- IT IS ONLY SPENT WHEN THERE IS MORE THAN ONE TOOL (`Weapon.equipDelayFor`): with one weapon
	-- there is no slot order to get wrong, and a spawn in the shipped build must stay bit-for-bit
	-- what it was before the rifle existed.
	AUTO_EQUIP_DELAY_SECONDS = 0.5,

	-- validation
	CAMERA_ORIGIN_TOLERANCE = 30, -- studs from HumanoidRootPart; the stock camera sits behind you
	MIN_AIM_DISTANCE = 4, -- below this the muzzle->aim vector is degenerate
	DIR_UNIT_TOLERANCE = 1e-3,
	SAFETY_ARC_HALF_DEG = 45, -- DEGREES, HALF angle: a different quantity from a spread cone

	-- HOW THE SERVER INTEGRATES A FLIGHT (task 185). These four are the SYSTEM's, not a gun's, and
	-- they are here for the reason `src/shared/Weapons/init.luau`'s header already states: the
	-- safety arc, the origin tolerance and the rate limits are rules of the DRIVE and of the
	-- PROTOCOL, not properties of a weapon. How finely the server steps, and how many projectiles
	-- it will carry at once, are properties of the SERVER -- a per-weapon step cap would let a new
	-- gun buy itself more server time, the same way a per-weapon arc would widen its own licence.
	--
	-- 1/30 IS HALF A FRAME OF A 60 Hz SERVER'S WORST NORMAL FRAME, and it is sized against two
	-- things: the chord-instead-of-arc error inside one step (0.019 studs at this cap) and the time
	-- resolution against a moving animal (a boar at `SPRINT_SPEED` 38 studs/s moves 1.27 studs,
	-- which is a third of its own trunk). A longer step cannot tunnel through a wall -- the cast is
	-- of the SEGMENT -- it just meets the animal a little late.
	FLIGHT_STEP_MAX_SECONDS = 1 / 30,
	-- HOW MUCH CATCH-UP ONE HEARTBEAT MAY BUY: 8 sub-steps, 0.267 s. Past that the remainder is
	-- DISCARDED, so a hitch makes a projectile arrive slightly late rather than making the server
	-- cast hundreds of rays in one frame. A stated degradation, and it cannot leak a projectile
	-- because `travelled` still rises on every sub-step.
	FLIGHT_MAX_SUBSTEPS = 8,
	-- THE HARD CEILING, so nothing can leak. The longest legitimate flight is 0.365 s (the rifle at
	-- its 800-stud cap), so this is 5.5x the real worst case: nothing in the game reaches it, and a
	-- non-zero `flightTimeouts` is therefore a bug said out loud rather than a flight swallowed.
	FLIGHT_MAX_SECONDS = 2.0,
	-- THE GLOBAL CAP ON LIVE PROJECTILES. The absolute burst the game can produce is 16 shooters
	-- firing both barrels of buckshot inside one flight time: 16 * 9 * 2 = 288. 512 is above that
	-- and can never be reached by play -- it is the guard against a loop, not a budget.
	FLIGHT_MAX_LIVE_PELLETS = 512,
	-- ---------------------------------------------------------- LAG COMPENSATION (task 256)
	--
	-- KAREN, 2026-10-24: *"we need to aim ahead to hit animal when running"* and *"it seems there is
	-- a bit off"*. The lead the game demands is the TRUE lead -- `Ballistics.timeToRange` times the
	-- animal's speed -- PLUS the round trip to the server, because the player aims at the animal his
	-- client drew one trip ago and the server resolves the shot against where it is one trip later.
	-- MEASURED (research note section 5.3): at 60 ms one way, a boar at `SPRINT_SPEED` wants 64 cm of
	-- extra lead on top of a true 91 cm at 60 m. **The ping is 70 % of the lead again.**
	--
	-- THE MECHANISM IS FORWARD PREDICTION, NOT A REWIND (Unreal's projectile `NetPredictionTime`;
	-- research note source C). Valve's hitbox rewind is the textbook answer and is REFUSED: it needs
	-- a position history per animal, which is a second store of a fact `Boar.Body` owns -- the
	-- overlapping-owner failure `docs/PROJECT_CONTEXT.md` is a document about. Forward prediction
	-- needs no history at all: `Flight.advance` already steps a projectile over an INJECTED `dt`
	-- through an INJECTED segment cast, so "catch this shot up by L" is the step this system already
	-- takes, taken once more at launch -- same sub-step cap, same segment casts, so it still cannot
	-- tunnel through a wall and still cannot skip a target.
	--
	-- THE BOUND IS THE WHOLE SAFETY ARGUMENT. Unbounded, a 400 ms client reaches a third of a second
	-- into the future and gets a free body length of lead that other players would see as a shot
	-- which hit nothing. 0.15 s covers a bad connection and caps the reach at 5.7 studs on a
	-- sprinting boar -- about one body length, the most a mistake here may ever be worth. It also
	-- fits the EXISTING budget rather than widening it: 0.15 s plus a 1/60 heartbeat is 5 of the 8
	-- `FLIGHT_MAX_SUBSTEPS`, and 0.15 is far under `FLIGHT_MAX_SECONDS`, so nothing above moves.
	FLIGHT_CATCHUP_MAX_SECONDS = 0.15,
	-- WHAT `Player:GetNetworkPing()` MEANS, AS A DIAL. The engine's docs say only *"the network ping
	-- in seconds"* and do NOT say whether that is the round trip or one way, and section 5.1 shows
	-- the correction wanted is the ROUND TRIP. So the one genuinely uncertain number in this block is
	-- a DATA ROW and not a literal, for the reason `GRAVITY_SCALE` already is one: a constant that
	-- can only be read at one value cannot be tested at another -- and this one can only be
	-- CONFIRMED against a real server, because a Studio Play session has no network and reads ~0.
	--
	-- 1.0 IS THE CONSERVATIVE READING (treat the engine's number as the round trip): over-correcting
	-- hands out free lead, while under-correcting merely leaves some of today's error in place. 2.0
	-- is the value if it turns out to be one way. Karen's dial, and the Director's to confirm live.
	FLIGHT_CATCHUP_PING_FACTOR = 1.0,

	-- rates, per player
	FIRE_RATE_LIMIT = 6, -- received requests/s
	ACTION_RATE_LIMIT = 10,
	STATE_RATE_LIMIT = 20,
	-- A SWITCH HAS NO REMOTE (task 140) -- the engine's own hotbar moves the Tool -- but it does have
	-- a PUBLISH, and that publish used to be forced past `STATE_RATE_LIMIT` because it rides the same
	-- `sync()` as a grant. A player mashing 1/2 would flood `StateChanged` at input rate, so the
	-- Parent-change publish takes its own bucket. Eight a second is instant to a human.
	EQUIP_RATE_LIMIT = 8,

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
	-- WHAT A BULLET LANDING LOOKS LIKE (task 249). KAREN, 2026-10-23, with a frame of it:
	-- *"after shoot remianing this ? what is that ?"* -- a bright yellow cube hanging over the grass
	-- where her buckshot landed. MEASURED in her own place before anything was written: nine
	-- `Impact` parts, each a **0.30-stud `Neon` BLOCK at 255,170,90, transparency 0**, all at the
	-- one point a buck pattern lands on -- so nine of them stacked and bloomed read as one glowing
	-- box, for the whole `IMPACT_LIFETIME` second.
	--
	-- SO THE PART STOPS BEING THE PICTURE AND BECOMES THE HOST. It is invisible now, and what the
	-- player sees is one short burst from a `ParticleEmitter` on it -- soft, matte, gone in under a
	-- second, with no hard edge to read as a cube.
	--   ParticleEmitter:Emit  https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter#Emit
	-- `Emit` rather than `Enabled = true` for a moment: a burst is a COUNT, not a window, so one
	-- call puts exactly `COUNT` grains in the air whatever the frame rate is.
	--
	-- THE TEXTURE IS A STOCK CLIENT ASSET (`rbxasset://`, shipped with every Roblox client), so this
	-- needs no upload and no moderation round trip -- and it is a SOFT round puff, which is the
	-- whole difference from the default emitter's own hard white square. A square particle would be
	-- the same defect one size down.
	IMPACT = {
		-- how long the host part lives. Longer than the grains themselves (`LIFETIME` below), so
		-- Debris never takes the emitter away mid-puff.
		HOST_LIFETIME = 0.75,
		TEXTURE = "rbxasset://textures/particles/smoke_main.dds",
		-- A GRAIN'S OWN LIFE. Karen's word is *"short"*: 0.35 s is a quarter of the smoke that
		-- hangs at the muzzle (`SMOKE_LIFETIME` 1.1) and about a fifth of the old cube's second.
		LIFETIME = { 0.22, 0.38 },
		COUNT = 7, -- per impact point, so a nine-pellet pattern is a spray and not a wall
		SIZE = { 0.35, 0.9 }, -- studs, start -> end: it opens as it fades
		SPEED = { 2.5, 5.0 },
		SPREAD_DEG = 38,
		-- NOT GLOWING, which is the other half of Karen's complaint. A `ParticleEmitter` has no
		-- material; what made the cube glow was `Neon`, and nothing here is `Neon`. `LightEmission`
		-- 0 is this emitter's own way of saying the same thing, written down rather than defaulted.
		LIGHT_EMISSION = 0,
		TRANSPARENCY = { 0.35, 1 }, -- it fades out rather than popping
		-- WHAT THE GROUND IS MADE OF, AS TWO CLASSES AND A DEFAULT. The server now sends the
		-- surface's `Material` with each landing point, and these are the only two answers the
		-- picture needs: dry soil kicked off the floor, and pale splinters off a trunk.
		DUST_COLOR = Color3.fromRGB(150, 133, 108),
		WOOD_COLOR = Color3.fromRGB(146, 107, 68),
		-- The woods in `WOOD`: everything else is dust, which is the safe way round -- an unknown
		-- surface gets the puff that suits grass, rock and dirt, and this map is almost all of those.
		WOOD = {
			Wood = true,
			WoodPlanks = true,
		},
	},
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
	-- THE MARKER'S OWN COLOURS LEFT THIS TABLE IN TASK 201 E. `HIT_MARK_COLOR` (white) and
	-- `CROSSHAIR_COLOR` (white) are gone: the Designer's design system, 2026-10-17 §5 surfaces 18
	-- and 19 make both marks `Style`'s -- `PAPER` for a hit, `PINE_TEXT` for a kill, `CLAY` for a
	-- wound -- and `Style.hitMarkColor` is the one mapping. Archived with their values and the way
	-- back in `backups/2026-10-19_hit-mark-colours.txt` (rule 7).
	--
	-- `HIT_MARK_KILL_COLOR` STAYS, AND IT IS NO LONGER THE HIT MARKER'S. It is the FATAL DOT on the
	-- boar plate -- `Hud.BoarArt`'s `dot.fatal` pip and `Hud.HitCard`'s lead mark, both of which
	-- draw a wound POSITION on a bone-coloured silhouette, where red reads as blood and the
	-- marker's green would not. The name is kept because `docs/design/drive-report.md` and
	-- `docs/research/2026-10-17-hit-card.md` both name it and those are the Architect's files, not
	-- the Builder's (CLAUDE.md roles); renaming it is queued for the Director.
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
	-- NO `CROSSHAIR_COLOR` (task 201 E): see `HIT_MARK_KILL_COLOR` above. The crosshair is `PAPER`
	-- with a drop line now, and `src/client/Hud/Style.luau` is where that is written.
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
