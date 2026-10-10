--!strict
-- Rifle: every number the bolt-action rifle has, frozen, with no writer -- the shape
-- `src/shared/Shotgun/init.luau` already is, and the reason it is a sibling rather than a second
-- table inside that file: `Shotgun.CONFIG` holds numbers Karen accepted on 2026-10-09 (*"gun is
-- ok"*), and the file that holds them must not become the file everybody edits.
--
-- Karen, 2026-10-09: *"afther this fixes we need to add rifle with scope and with aimpoint"*, and she
-- picked the model herself because *"it's already with scope"*. The separate Aimpoint is a later
-- task (the Director's cut).
--
-- EVERY NUMBER HERE IS A DIAL, and the ones that are not mine say whose they are. The scope's
-- magnification arithmetic is the research note's: a magnification `m` is `tan(70/2) / tan(fov/2)`,
-- which is the same formula `Camera.Mode.sensitivityScale` uses to slow the mouse down -- so 4x IS
-- 19.87 degrees and nothing has to be told twice.
--
-- Design: docs/design/rifle.md (sections 4.2, 4.4, 7, 8, 12)
-- Note:   docs/research/2026-10-09-rifle-scope.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Rifle = {}

export type CycleStep = { kind: Shotgun.ActionKind, wait: number }

-- THE RETICLE IS IN DEGREES, EVERY FIELD, and that is what makes one duplex true at any screen size
-- and at any magnification: Roblox's field of view is VERTICAL, so `px = deg / fovDeg * viewportY`
-- is exact and the Hud converts once (`Hud.reticleDegToPx`). Change `aimFovDeg` from 19.87 to 13.31
-- and every element of the sight picture grows by exactly the magnification, as a real scope's does.
-- AN ILLUMINATED DOT AT THE CENTRE (task 142). Karen: *"we need a dot in scope center red dot"*.
-- In DEGREES like every other length here, and with a HALO as well as a core, because a 4.6-pixel
-- red square on a sunlit birch is a red square on a sunlit birch: the halo is a second, softer ring
-- around it that gives the dot an edge against a bright background, which is what an illuminated
-- reticle does with glass.
export type Dot = {
	deg: number,
	color: Color3,
	haloDeg: number,
	haloColor: Color3,
	haloTransparency: number,
}

export type Reticle = {
	kind: string,
	dot: Dot,
	ringOuterDeg: number,
	ringThickDeg: number,
	crossGapDeg: number,
	crossArmDeg: number,
	crossThickDeg: number,
	postArmDeg: number,
	postThickDeg: number,
	color: Color3,
	strokeColor: Color3,
}

-- THE SIGHT PICTURE (task 141). Every length here is in DEGREES for the same reason the reticle's
-- are: Roblox's field of view is vertical, so one number is true at any screen size and grows by
-- exactly the magnification when `aimFovDeg` changes.
export type Eyepiece = {
	-- At what blend the sight picture SNAPS IN: the gun rises first and the overlay arrives at the
	-- top of the swing, which is what the eye does when it comes to a scope.
	atBlend: number,
	diameterDeg: number,
	rimThickDeg: number,
	rimColor: Color3,
	maskColor: Color3,
}

-- WHAT A BOLT CYCLE DOES TO THE SIGHT PICTURE (task 142). `leaveScope` true drops the view out of
-- the scope while the server is running a cycle step and puts it back when the step ends; false
-- keeps the picture up. Both branches are reachable by this one number and never by an edit.
export type Cycle = {
	leaveScope: boolean,
}

export type Scope = {
	aimFovDeg: number,
	cycle: Cycle,
	magnification: number,
	sway: { ampDeg: number, periodSeconds: number },
	eyepiece: Eyepiece,
	reticle: Reticle,
}

Rifle.CONFIG = {
	-- ---------------------------------------------------------------- ballistics
	-- ONE AMMO KIND, AND IT IS "Slug" ON THE WIRE (design 4.4). `Boar.Wound.damageFor` branches
	-- `if ammo == "Slug" then zoneRow.Slug else zoneRow.Pellet`, so any new string would be charged
	-- as a buckshot PELLET and the rifle would hit softer than the shotgun's slug until the boar's
	-- own damage table grew a column -- a change inside the animal Karen accepted, and outside this
	-- task. The word on screen is `AMMO_LABEL`'s business and the Hud's alone.
	RANGE_STUDS = { Slug = 450 }, -- 126 m at 0.28 m/stud, against the slug's 330
	PELLETS = { Slug = 1 },
	-- DEGREES, FULL cone, like the shotgun's and halved in the same one place (`Pattern.directions`).
	-- 1 MOA is 0.0167 degrees and a hunting rifle is 1-2 MOA, so 0.05 full is about 1.5 MOA: 0.39
	-- studs across at 450 studs, which is inside a boar's chest zone.
	SPREAD_FULL_DEG = { Slug = 0.05 },
	AMMO_KINDS = { "Slug" },
	-- The word the Hud prints for the kind. ".416" is the Rigby's own cartridge; the WIRE still says
	-- Slug, and these two facts meet in exactly one place (`Hud.readoutFor`).
	AMMO_LABEL = { Slug = ".416" },
	INITIAL_AMMO = "Slug" :: Shotgun.AmmoKind,
	-- NINE IN THE POCKET: three spare magazines of three, which is what makes the magazine change
	-- something that happens in a drive rather than a thing you read about. Karen's dial.
	START_RESERVE = { Slug = 9 },

	-- ---------------------------------------------------------------- the action
	-- THREE CHAMBERS, BECAUSE THE MAGAZINE HOLDS THREE (task 142). Karen: *"in magazine 3 shells
	-- then it changes with left hand magazine"*. `barrels` in the reducer is already an array of
	-- Live/Spent/Empty, so a box magazine of three IS that array with three entries -- see the note
	-- (docs/research/2026-10-10-rifle-bolt-magazine-sound.md section 3) for why that is the smaller
	-- change than a second ammo model.
	BARRELS = 3,
	MAGAZINE = 3, -- what one full magazine holds; `BARRELS` is the same number and says why
	-- The trigger's own dwell before the bolt starts, shorter than the shotgun's 0.25 because there
	-- is no second barrel to pick.
	BARREL_DELAY = 0.12,
	-- THE CYCLE IS AUTOMATIC, and that is a dial rather than a belief: with one chamber a manual
	-- cycle means pressing R after EVERY shot, which is a reload and not a bolt. `AUTO_CYCLE = false`
	-- makes R the cycle and both branches are reachable by parameter (design 8.1, Karen's to change).
	AUTO_CYCLE = true,
	-- "Open, eject, feed, close" with one chamber is three of the five primitives
	-- `StateMachine.apply` already has -- so the rifle adds no state, only this list.
	-- WORKING THE BOLT IS TWO STEPS, NOT THREE (task 142): back (the fired case goes), forward (the
	-- next round from the magazine). There is no `Load` because there is nothing to feed BY HAND --
	-- the magazine already holds the rounds, which is the whole difference between a magazine rifle
	-- and the shotgun.
	--
	-- 0.62 s TOTAL, AND THE NOTE'S SOURCE 3 IS WHY: a shooter who learned on an SMLE Mk III, against
	-- a request for a slower animation -- *"Can cycle that bolt every bit has fast. Hard and fast."*
	-- A bolt that takes a second reads as a jam.
	CYCLE = {
		{ kind = "Break" :: Shotgun.ActionKind, wait = 0.26 },
		{ kind = "Close" :: Shotgun.ActionKind, wait = 0.36 },
	} :: { CycleStep },
	CYCLE_TOTAL = 0.62, -- the sum; `rifle.spec` asserts it against the list
	-- WHAT OPENING THE ACTION THROWS AWAY: the fired case, and nothing else. See
	-- `StateMachine.apply`'s `Break` -- the shotgun's `"all"` would dump two live rounds every shot.
	CYCLE_EJECTS = "spent",
	-- THE MAGAZINE CHANGE, AND THEN A BOLT CYCLE TO CHAMBER. Karen: *"then the right hand cycles the
	-- bolt to chamber"*. 1.35 s for the swap is slower than the bolt on purpose: it is two hands and
	-- a part that leaves the gun.
	RELOAD = {
		{ kind = "Magazine" :: Shotgun.ActionKind, wait = 1.35 },
		{ kind = "Break" :: Shotgun.ActionKind, wait = 0.26 },
		{ kind = "Close" :: Shotgun.ActionKind, wait = 0.36 },
	} :: { CycleStep },
	RELOAD_TOTAL = 1.97,
	-- AN EMPTY RIFLE RELOADS ITSELF. Karen: *"when empty (or on R)"*. A dial, because a reload
	-- nobody asked for is the kind of thing that is right until it is not.
	AUTO_RELOAD_WHEN_EMPTY = true,
	-- The Hud shows ROUNDS LEFT over capacity -- `3/3` -- rather than the shotgun's one glyph per
	-- chamber, which for three chambers is not what a magazine rifle shows anybody.
	READOUT = "magazine",

	-- ---------------------------------------------------------------- the hardware
	-- 4.4 STUDS, AND IT IS THE MESH'S OWN LENGTH RATHER THAN THE DESIGN'S 4.1. The design proposed
	-- 4.1 (a 24-inch sporter) before the asset existed; the four groups were prepped, uploaded and
	-- moderated at 4.4 -- `tools/gltf_split.py`'s `rigby` plan bakes the gun's length into the
	-- geometry and both guns are about 45 inches in life, which is why the plan used the shotgun's
	-- number. A handle shorter than its own mesh would put the muzzle attachment inside the barrel.
	-- Re-prepping four uploads to move a drawn gun 0.3 studs is not a trade worth making.
	HANDLE_SIZE = Vector3.new(0.4, 0.5, 4.4),
	HANDLE_TRANSPARENCY = 1, -- the Handle is the envelope, not the gun (Shotgun.CONFIG's own rule)
	GRIP = CFrame.new(0, 0, 1.4), -- the Handle's -Z is the muzzle, so the barrel points away
	MUZZLE_OFFSET = Vector3.new(0, 0, -2.2), -- half of HANDLE_SIZE.Z: the muzzle

	-- The WORLD rifle's fallback colours (`Weapon.ShapeRifle`), above the albedo floor task 22
	-- measured, exactly as the shotgun's are.
	LOOK = {
		-- The drawn magazine (task 142): darker than the barrel, so the box reads as a separate
		-- thing bolted under the action rather than as more of the same steel.
		magazine = Color3.fromRGB(38, 39, 42),
		-- The open-sighted rifle's drawn front sight (task 143): brass, like the shotgun's, because a
		-- bead's whole job is to catch the light and be seen against a dark animal.
		bead = Color3.fromRGB(214, 176, 96),
		barrel = Color3.fromRGB(58, 60, 64),
		action = Color3.fromRGB(78, 79, 82),
		wood = Color3.fromRGB(104, 64, 38),
		scope = Color3.fromRGB(42, 43, 46),
	},

	-- THE MANIFEST KEYS ARE NOT HERE, and that is deliberate (the Reviewer's note, round 1). A
	-- third copy of them lived here, read by nothing and in a DIFFERENT ORDER from the two that
	-- are read -- `Weapons.ROWS.rifle.ASSET_KEYS` (the world Tool) and `Rifle.Geometry.ASSET_KEYS`
	-- (the drawn gun). The order decides which key is worn as `Model`, which is the one fact
	-- `MESH_NAMES`' own comment says nothing may change, so a copy that disagrees is a trap.

	-- ---------------------------------------------------------------- the voice
	-- ITS OWN GUNSHOT (task 142). Karen: *"for rifle has to be another gun fire sound"*. The shotgun
	-- was the only voice in the game and both guns used it, because `Camera.Config.SOUND_SHOT_ID`
	-- was one id for everything; the ids are per WEAPON now and this is the rifle's.
	--
	-- EVERY ID IS ROBLOX-PROVIDED LICENSED LIBRARY AUDIO, verified by name and creator through the
	-- public asset-details endpoint and MEASURED TO LOAD in the Forest Test with
	-- `ContentProvider:PreloadAsync` -- the procedure task 124 used for the hit ticks. Nothing is
	-- uploaded to Karen's account, so no `assets/uploads.json` row, exactly as the shotgun's needed
	-- none. The measurements are in docs/research/2026-10-10-rifle-bolt-magazine-sound.md section 4.
	--
	-- A .50 BMG FOR A .416, AND THE MEASUREMENT IS THE ARGUMENT: the shotgun's sample is 0.92 s and
	-- this one is 3.36 s, which IS the longer tail the Director asked for. The nearest thing in the
	-- licensed catalogue to a big-bore rifle; everything the search turns up for "hunting rifle" is
	-- a user re-upload of Call of Duty, Fortnite or CS:GO audio, none of it ours to ship.
	--
	-- EVERY SAMPLE IS CUT, and that is not optional: "Single Shot*s*" is a TAKE, not a round, so a
	-- 3.36 s clip from a gunfire library may well hold three bangs. `cut` plays the first seconds and
	-- `fade` takes the last of those down to nothing -- the mechanism `Boar.CONFIG.SOUND`'s own
	-- `cut = 0.6` already uses for the death squeal.
	--
	-- NOBODY HERE HAS HEARD ANY OF THEM. The Builder cannot play audio. KAREN'S EARS DECIDE, and
	-- every one of these is one line.
	SOUND = {
		-- "Rifle Single Shots 1 (SFX)", ProSoundEffects, Barrett M82 .50 Cal. loaded=true 3.36 s
		shot = { id = "rbxassetid://9118173739", cut = 1.6, fade = 0.4, pitch = 1.0 },
		-- "Ppsh Burp Gun 7 (SFX)", ProSoundEffects, "Cocking and Loading, Dull Metal Movements,
		-- Clicks". loaded=true 2.45 s -- a bolt is a short hard clack, so it is cut hard and pitched
		-- up a little.
		bolt = { id = "rbxassetid://9117889191", cut = 0.35, fade = 0.08, pitch = 1.15 },
		-- "Shotgun Handle 1 (SFX)", ProSoundEffects, "Grab, Handle". loaded=true 0.58 s.
		magazine = { id = "rbxassetid://9119115171", cut = 0.45, fade = 0.1, pitch = 0.9 },
	},

	-- ---------------------------------------------------------------- the optics
	-- THE ONE NUMBER THE CAMERA IS TOLD is `aimFovDeg`. Everything else here is drawn by the Hud or
	-- applied by `Camera.Mode`, and neither of them learns what a rifle is.
	scope = {
		-- 4x. `tan(rad(70)/2) / tan(rad(19.87)/2)` = 4.000 to three decimals, and `rifle.spec`
		-- asserts exactly that -- so a hand-typed FOV that does not match the stated magnification
		-- fails the harness instead of shipping as a lie. 6x is 13.31 and one number.
		aimFovDeg = 19.87,
		magnification = 4,
		-- A FIGURE-EIGHT, vertical at 1x and horizontal at 0.5x, scaled to zero in the hip view.
		-- Arma 3's OPREP gives the SHAPE (two predictable forces, breathing and grip) and states no
		-- numbers at all, so these are mine: 0.25 degrees at 150 studs is 0.65 studs of wander,
		-- which is inside a boar's chest zone. `ampDeg = 0` turns it off.
		sway = { ampDeg = 0.25, periodSeconds = 4.0 },
		-- THE VIEW COMES OUT OF THE SCOPE TO WORK THE BOLT, and the note's section 2 is the argument:
		-- PUBG's own community asks how to STAY scoped through a bolt cycle, which is evidence that
		-- the default is to leave it; Battlefield 1 requires coming out of the sight to get a grip on
		-- the rifle. For THIS game it is not close, for a reason those sources need not supply --
		-- our sight picture is a full-screen black mask with the gun hidden behind it (task 141), so
		-- "stay scoped" means watching a black circle while the thing Karen asked to see happens
		-- behind it. Set it false and the picture stays up: one number, no edit.
		cycle = { leaveScope = true },
		-- WHAT A SCOPE ACTUALLY LOOKS LIKE (task 141). The Director, testing task 140 in the Forest
		-- Test: the drawn scope's own tube was in front of the eye with the reticle painted over it,
		-- which is what you see when you hold a rifle up to your face and look PAST the glass. A
		-- sight picture is the other thing: the gun is gone, everything outside the eyepiece is
		-- black, and the magnified world sits in a circle with the duplex on it.
		--
		-- 17 degrees of the 19.87 the scope renders is 0.86 of the screen's height -- a circle with
		-- the ground visible past its edge, which is what looking through a scope held correctly
		-- gives you.
		--
		-- `atBlend` IS 0.98 AS A TOLERANCE, NOT AS A THRESHOLD, and round 2's comment here had the
		-- reason wrong (the Reviewer caught it): `Mode.step` raises the blend LINEARLY --
		-- `math.min(1, blend + dt / seconds)` -- so it reaches exactly 1 and 0.98 is never a sample
		-- at 60 fps. What the hundredth buys is a frame rate low enough to step past it, and the
		-- predicates compare with `>=`, so the picture arrives on the frame the raise finishes
		-- either way. The Director asked for "snaps in when blend ~ 1" and that is what it does.
		eyepiece = {
			atBlend = 0.98,
			diameterDeg = 17.0,
			rimThickDeg = 0.45,
			rimColor = Color3.fromRGB(26, 26, 28),
			maskColor = Color3.fromRGB(0, 0, 0),
		},
		reticle = {
			kind = "duplex",
			-- THE RED DOT. 0.085 degrees at this scope's 19.87 is about 4.6 px on a 1080-high
			-- viewport: a dot you can hold on a boar's chest at 150 studs, and not a blob that
			-- hides it. The halo is three times it at 0.55 transparency -- enough of an edge to
			-- read against sky, snow or a pale trunk, which a bare red square does not.
			dot = {
				deg = 0.085,
				color = Color3.fromRGB(255, 48, 36),
				haloDeg = 0.26,
				haloColor = Color3.fromRGB(120, 0, 0),
				haloTransparency = 0.55,
			},
			-- 4.0 degrees at FOV 19.87 is a fifth of the screen height: a ring you look THROUGH.
			ringOuterDeg = 4.0,
			ringThickDeg = 0.10,
			-- 0.055 degrees is 1.2 px at 1080p and this FOV -- a hair, which is what a thin
			-- crosshair is. The thick outer posts are four times it, which is what makes a duplex
			-- read as a duplex.
			crossGapDeg = 0.35,
			crossArmDeg = 1.30,
			crossThickDeg = 0.055,
			postArmDeg = 1.50,
			postThickDeg = 0.22,
			color = Color3.fromRGB(16, 16, 16),
			strokeColor = Color3.fromRGB(235, 235, 235),
		},
	} :: Scope,
}

Shotgun.deepFreeze(Rifle.CONFIG)

return Rifle
