--!strict
-- SemiAuto: every number the semi-automatic shotgun has, frozen, with no writer -- the shape
-- `src/shared/Lever/init.luau` and `src/shared/Rifle/init.luau` already are, and a sibling of them
-- rather than a second table inside either.
--
-- Karen, 2026-10-20: *"so you have things to do / deer / weapons / make it work like we have now"*,
-- and she bought the model herself (PStudio, "Semi-Automatic Shotgun" on Fab: an MP-153-pattern
-- 12 gauge with a rail and a red-dot sight). Her standing bar is that shooting, weapon and reload
-- must be perfect.
--
-- THE ONE PLACE THIS FILE DELIBERATELY DOES NOT HOLD ITS OWN NUMBERS IS THE AMMUNITION, and that is
-- the opposite of `Lever`'s rule for a reason both files should be read together for. The two
-- RIFLES share no number because they fire different cartridges. The two SHOTGUNS fire the SAME
-- 12-gauge shell, and a 12-gauge shell does not change because the gun that fires it has a gas
-- piston -- so a second copy of `RANGE_STUDS` here would be a second answer to "how far does a slug
-- go", which is the defect and not the protection. Those rows are read from `Shotgun.CONFIG` by
-- reference, and `semiauto.spec` asserts the IDENTITY of the tables rather than their values.
--
-- EVERY OTHER NUMBER HERE IS A DIAL, and the ones that are Karen's say so. Nobody here has heard a
-- sound or felt a kick.
--
-- Design: docs/design/semiauto-shotgun.md (sections 5.1, 6, 8, 9, 10)
-- Note:   docs/research/2026-10-20-semiauto-shotgun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local SemiAuto = {}

export type CycleStep = { kind: Shotgun.ActionKind, wait: number }

SemiAuto.CONFIG = {
	-- ---------------------------------------------------------------- ballistics
	-- THE SAME SHELL, BY REFERENCE AND NOT BY COPY (design section 9). Every one of these seven rows
	-- is `Shotgun.CONFIG`'s own table, so there is exactly one answer in the game to what a slug and
	-- a buckshot load do, and a change Karen makes to one gun's shell reaches both guns -- which is
	-- what "the same ammunition" means.
	RANGE_STUDS = Shotgun.CONFIG.RANGE_STUDS,
	PELLETS = Shotgun.CONFIG.PELLETS,
	SPREAD_FULL_DEG = Shotgun.CONFIG.SPREAD_FULL_DEG,
	MUZZLE_STUDS_PER_S = Shotgun.CONFIG.MUZZLE_STUDS_PER_S,
	DRAG_PER_STUD = Shotgun.CONFIG.DRAG_PER_STUD,
	ZERO_STUDS = Shotgun.CONFIG.ZERO_STUDS,
	GRAVITY_SCALE = Shotgun.CONFIG.GRAVITY_SCALE,
	AMMO_KINDS = Shotgun.CONFIG.AMMO_KINDS,
	AMMO_LABEL = Shotgun.CONFIG.AMMO_LABEL,
	AMMO_GLYPH = Shotgun.CONFIG.AMMO_GLYPH,
	-- BUCKSHOT IS WHAT IT COMES LOADED WITH, where the side-by-side starts on slugs. The shop gives
	-- this gun its buckshot free (`Shop.BASE_AMMO.semiauto`) and the slug is still the ladder's
	-- first rung, so starting on the free load is the honest readout.
	INITIAL_AMMO = "Buck" :: Shotgun.AmmoKind,
	-- TWO TUBES OF EACH: enough that the port reload is something that happens in a drive rather
	-- than a thing you read about. Karen's dial.
	START_RESERVE = { Slug = 10, Buck = 10 },

	-- ---------------------------------------------------------------- the action
	-- FOUR IN THE TUBE AND ONE IN THE CHAMBER, AND IT IS MEASURED TWICE. The tube runs 0.3546 of the
	-- model's own units from the receiver face to the magazine cap, which at the scale section 10.1
	-- derives (1 file unit = 882.9 mm, anchored on the 710 mm barrel) is 313 mm = 4.1 shells of
	-- 76 mm. The manufacturer's own figure for the 12/76 shell is 4+1. The measurement and the
	-- published number agree, which is a stronger statement than either alone.
	BARRELS = 5,
	MAGAZINE = 5, -- what the gun holds; `BARRELS` is the same number and says why
	-- The trigger's own dwell before the bolt starts. The rifle's 0.12 and not the side-by-side's
	-- 0.25, because there is no second barrel to pick on this gun either.
	BARREL_DELAY = 0.12,
	-- THE GUN WORKS ITSELF. Hunter-Ed, in one sentence: *"As each shot is fired manually, the case of
	-- the cartridge or shotshell is ejected automatically and the chamber is reloaded
	-- automatically"*, and *"the trigger must be pulled each time a shot is fired"* (note 4.1). Both
	-- branches stay reachable by parameter (`AUTO_CYCLE = false` makes `R` the cycle).
	AUTO_CYCLE = true,
	-- ONE STROKE, READ AS TWO STEPS: back EJECTS (`Break`), forward FEEDS AND LOCKS (`Close`). There
	-- is no `Load` here -- nothing is fed by hand during a cycle -- which is why this weapon adds no
	-- primitive to the reducer, exactly as the bolt rifle's and the lever's cycles do not.
	--
	-- 0.30 s TOTAL, BRACKETED BY TWO NUMBERS THIS REPO HAS MEASURED ON SCREEN. Far faster than the
	-- lever's 1.10 and the bolt's 1.62 -- those are a HAND's work and this is a gas piston's, and
	-- the shooter does nothing at all. And NOT ZERO: the bolt has to be visibly back for a frame or
	-- the gun does not read as a gun that cycled. The split is 40/60, the out-stroke the shorter
	-- half, which is the ratio both other repeaters use.
	--
	-- WITH `BARREL_DELAY` THIS IS 0.42 s BETWEEN SHOTS -- five rounds in 1.68 s after the first.
	-- That rate is the gun's whole character and it is KAREN'S DIAL.
	CYCLE = {
		{ kind = "Break" :: Shotgun.ActionKind, wait = 0.12 },
		{ kind = "Close" :: Shotgun.ActionKind, wait = 0.18 },
	} :: { CycleStep },
	CYCLE_TOTAL = 0.30, -- the sum; `semiauto.spec` asserts it against the list
	-- WHAT THE STROKE THROWS AWAY: the fired hull, and nothing else. The side-by-side's `"all"`
	-- would dump four live rounds out of the tube after every shot. This is what "ejected
	-- automatically" means on a magazine gun (note 4.1).
	CYCLE_EJECTS = "spent",
	-- THE RELOAD IS SINGLE SHELLS THROUGH THE LOADING PORT UNDER THE RECEIVER, and it adds no
	-- primitive either: `StateMachine.apply`'s `Load` fills EXACTLY ONE empty chamber from the
	-- pocket per step, which is precisely one shell through one port.
	--
	-- `Break` AND `Close` DO NOT OPEN ANYTHING ON THIS GUN, and the words are the reducer's rather
	-- than this gun's: `Break` is the hand leaving the grip for the port and `Close` is it coming
	-- back. Said out loud because a reader who knows the side-by-side will read them as a hinge.
	--
	-- 2.60 s FULL: slower than the side-by-side's 2.0, which is the price of five rounds, and
	-- QUICKER than the lever's 2.90 -- 0.38 per shell against its 0.42, because a shotgun's port
	-- is a bigger hole than a rifle's gate. (The design's 6.2 calls this the slowest reload in
	-- the game. It is not: `semiauto.spec` measures both comparisons rather than repeating it.)
	-- A PARTIAL top-up is correspondingly shorter: `Weapon.cycleRefusal` answers `"finish"` when the
	-- tube fills, so two shells cost 0.35 + 2 * 0.38 + 0.35 = 1.46 s rather than the full 2.60.
	RELOAD = {
		{ kind = "Break" :: Shotgun.ActionKind, wait = 0.35 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.38 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.38 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.38 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.38 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.38 },
		{ kind = "Close" :: Shotgun.ActionKind, wait = 0.35 },
	} :: { CycleStep },
	RELOAD_TOTAL = 2.60,
	-- AN EMPTY GUN FILLS ITSELF, like both repeaters. A dial.
	AUTO_RELOAD_WHEN_EMPTY = true,
	-- The Hud shows ROUNDS LEFT over capacity -- `5/5` -- rather than one glyph per chamber.
	READOUT = "magazine",

	-- ---------------------------------------------------------------- the hardware
	-- 4.9 STUDS, THE LONGEST GUN IN THE GAME, AND IT IS A FACT ABOUT THE GUN. The scale was anchored
	-- on the BARREL -- 710 mm, a listed length, and the one dimension a shotgun is actually
	-- specified by -- which puts 1 file unit at 882.9 mm. At that scale the model's overall length
	-- is 1254 mm against a published 1250, its receiver 37.7 mm against 38, and its tube 4.1 shells
	-- of 76 mm against a published 4+1: THREE independent checks inside 1 %, none of them fitted.
	-- 1254 mm is 49.4 inches, and at the repo's own 3.87 studs/m (the side-by-side is 4.4 studs for
	-- ~45 in, the lever 4.0 for 40.5) that is 4.85, shipped at 4.9.
	HANDLE_SIZE = Vector3.new(0.4, 0.5, 4.9),
	HANDLE_TRANSPARENCY = 1, -- the Handle is the envelope, not the gun (Shotgun.CONFIG's own rule)
	-- WHERE THE HAND HOLDS IT, AND THIS ONE IS MEASURED RATHER THAN SCALED. Both other rifles carry
	-- the side-by-side's 1.4 scaled by their own length; this gun's pistol grip was measured off the
	-- model at z +1.52 (`Geometry.gripOffset`), and a scaled 1.56 would have been a number that
	-- happens to be close. The Handle's -Z is the muzzle, so the barrel points away.
	GRIP = CFrame.new(0, 0, 1.52),
	MUZZLE_OFFSET = Vector3.new(0, 0, -2.45), -- half of HANDLE_SIZE.Z: the muzzle

	-- THE WORLD GUN'S FALLBACK COLOURS (`Weapon.ShapeSemiAuto`) -- what is drawn before the uploads
	-- load, and never on top of them. Every one is SAMPLED off this model's own prepped previews
	-- (`asset_prep`'s `render_three-quarter.png`, the subject pixels' median or upper quartile), so
	-- they are this gun and not a guess: BLUED steel and WALNUT, where the lever is stainless and
	-- grey laminate.
	LOOK = {
		-- The blued barrel. Darker than the receiver, which is what a blued tube beside a
		-- parkerised receiver looks like, and the pair `model-b` already ships (34,36,42 against
		-- 78,79,82).
		barrel = Color3.fromRGB(42, 43, 47),
		action = Color3.fromRGB(71, 69, 69),
		-- THE BOLT IS THE BRIGHT ONE, and that is the single most useful fallback colour on this
		-- gun: it is the piece that MOVES, so a player watching the action cycle is watching this
		-- colour travel. Measured at RGB(190,191,192) -- bare, unblued steel.
		bolt = Color3.fromRGB(190, 191, 192),
		lifter = Color3.fromRGB(160, 160, 160),
		sight = Color3.fromRGB(69, 70, 70),
		-- WALNUT. The row's `HANDLE_COLOR` reads this key, as both other rifles' do, so the name is
		-- the slot rather than a claim about the material -- but on this gun it is also true.
		wood = Color3.fromRGB(111, 73, 60),
		-- THE DOT ITSELF. Drawn, because `SurfaceAppearance` has NO emission channel and the
		-- artist's `M_Sight01_Emissive.png` therefore renders as nothing at all (note 4.3).
		dot = Color3.fromRGB(255, 40, 30),
	},

	-- WHICH SIGHT THE ROW CARRIES. `"reddot"` and no `scope` block at all, which is what makes
	-- aiming the side-by-side's path -- the gun and both gloves left in the view -- rather than the
	-- Rigby's full-screen mask. That is what a red dot is for, and it is Karen's own polish target
	-- (*"bead aiming with hands and no crosshair"*).
	SIGHT = "reddot",

	-- THE MANIFEST KEYS ARE NOT HERE, deliberately -- the Reviewer's round-1 note on the rifle, kept
	-- by the lever. A third copy of them, read by nothing and possibly in a different order from the
	-- two that ARE read, is a trap: the order decides which key is worn as `Model`.

	-- ---------------------------------------------------------------- the voice
	-- NO AUDIO IS UPLOADED (the Director's rule for this task). Every id here is Roblox-provided
	-- licensed library audio that this repo already ships and has MEASURED to load in the Forest
	-- Test with `ContentProvider:PreloadAsync`.
	--
	-- NOBODY HERE HAS HEARD ANY OF THEM. The Builder cannot play audio. KAREN'S EARS DECIDE, and
	-- every number in these three lines is one line.
	SOUND = {
		-- THE SIDE-BY-SIDE'S OWN REPORT, because it is the same shell out of the same bore. Pitched
		-- a hair DOWN from 1.0: a 710 mm barrel is longer than the double's and a gas gun's muzzle
		-- blast is softer, which reads as a deeper report rather than a sharper one.
		shot = { id = "rbxassetid://9114725315", cut = 2.0, fade = 0.8, pitch = 0.94 },
		-- THE BOLT SLAMMING HOME. The lever's clack, SHORTER and HIGHER than its 0.95, because a gas
		-- bolt is a lighter, faster piece of steel travelling a shorter distance than a lever throw.
		-- Played on both edges of the action by `CameraBoot`, which is already how a weapon with a
		-- `bolt` voice is handled.
		bolt = { id = "rbxassetid://9117889191", cut = 0.28, fade = 0.08, pitch = 1.20 },
		-- ONE SHELL THROUGH THE PORT. The lever's gate click, which is already a shell-handling
		-- sample ("Shotgun Handle 1 (SFX)", ProSoundEffects) -- and on this gun it is literally a
		-- shotgun shell being handled. A row without this key is silent at the port, and both
		-- break-action and magazine guns written before task 224 are exactly that.
		load = { id = "rbxassetid://9119115171", cut = 0.30, fade = 0.08, pitch = 1.0 },
	},
}

Shotgun.deepFreeze(SemiAuto.CONFIG)

return SemiAuto
