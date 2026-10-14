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
	-- THE ONE LINE THAT TURNS IT OFF (task 146). Karen asked for the dot and her reference has
	-- none, so this is a data toggle rather than an argument: nil or true draws it.
	enabled: boolean?,
}

-- EVERY FIELD BUT THE FIRST THREE IS OPTIONAL SINCE TASK 146, and that is how the two reticles
-- this game has ever drawn both stay expressible: a field left out is an element not drawn. Karen's
-- own reference (`<assets-dir>/references/rifle/karen-scope-target.jpg`) has no ring and no posts,
-- so her scope simply does not carry `ringOuterDeg` or `postThickDeg` -- rather than carrying a zero
-- that every reader then has to know means "off".
export type Reticle = {
	kind: string,
	crossThickDeg: number,
	color: Color3,
	-- THE CROSS SPANS THE WHOLE LENS when this is true (task 146): the arms are computed from the
	-- EYEPIECE, so a change to the glass moves the hairs with it and the two can never disagree.
	-- Without it the arms are `crossGapDeg`/`crossArmDeg`, which is the duplex task 141 drew.
	spanLens: boolean?,
	dot: Dot?,
	ringOuterDeg: number?,
	ringThickDeg: number?,
	crossGapDeg: number?,
	crossArmDeg: number?,
	postArmDeg: number?,
	postThickDeg: number?,
	strokeColor: Color3?,
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
	-- HOW MUCH OF THE WORLD SURVIVES OUTSIDE THE TUBE (task 146). Karen: *"scope aiming has to be
	-- different cross look at the exaple I attached"* -- and in that frame the forest outside the
	-- scope body is dark but PRESENT, not painted out. 0 is the solid black task 141 shipped.
	maskTransparency: number?,
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
	-- 800 STUDS, AND 450 WAS THE BUG KAREN FELT (task 183). She asked for a hit that is *"precist
	-- and on 200m acurat"*, and 200 m is 714 studs at 0.28 m/stud: the old 450 is 126 m, so a shot
	-- at the distance she named never arrived at all. MEASURED in Play before the change, with the
	-- real rifle on a plate placed on the reticle centre: 440 studs hit, 455 studs and 470 studs
	-- produced NO IMPACT, which is the range cap and nothing else. 800 is 224 m -- 200 m plus the
	-- margin a shot taken slightly uphill needs -- and `Hits.resolve` casts exactly this far from
	-- the muzzle, so it is the one number that decides whether a long shot exists.
	--
	-- WHAT IT DOES NOT MOVE: `Match.CONFIG.SAFETY_RANGE_STUDS` is still 330, so the safety penalty's
	-- reach down the drive line is unchanged by this. That is queued (TASKS.md 183a) rather than
	-- changed here, because `src/server/Match/` is a TWO_PLAYER_PATH and this task is the weapon.
	RANGE_STUDS = { Slug = 800 }, -- 224 m at 0.28 m/stud, against the slug's 330
	PELLETS = { Slug = 1 },
	-- ZERO. A SCOPED RIFLE PUTS THE BULLET ON THE DOT (task 183), because that is what Karen asked
	-- for and because any cone at all is the error she would feel first: 0.05 degrees FULL is a
	-- 0.025-degree radius, which is 0.31 studs -- 8.7 cm -- at 714 studs, and the target is 5 cm.
	-- MEASURED before the change, scoped, three shots at 100 m: 4.97, 4.14 and 3.69 cm off the
	-- reticle centre, all of it this cone (0.025 degrees at 357 studs is 4.4 cm at the rim).
	--
	-- IT IS A DIAL AND IT IS DATA, so a hair of dispersion is one line: 0.02 full is 1.2 MOA, a real
	-- hunting rifle's group, and 3.5 cm at 714 studs -- inside the target. Zero is shipped because
	-- "precise" is what was asked and because a number nobody can predict is the wrong place to put
	-- character. `Pattern.directions` needs no branch for it: `cos(0)` is 1, so the one pellet comes
	-- out exactly along `aim`.
	--
	-- (The old comment claimed 0.05 full was "about 1.5 MOA". 1 MOA is 0.0167 degrees, so 0.05 full
	-- is 3 MOA -- the 1.5 was the half-angle. Corrected here rather than carried.)
	SPREAD_FULL_DEG = { Slug = 0 },
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
		-- "Gun Retort 1 (SFX)", ProSoundEffects -- *"Gun Retort, Weapon, Sharp Gun Shots,
		-- Reverberant Blasts"*, Guns - Handling. loaded=true 4.95 s (measured in Play, 2026-10-14).
		--
		-- IT REPLACES THE BARRETT (task 183). Karen, having heard that one: *"sound has to be harder
		-- like strong caliber"*. Her brief is a deep report with a sharp crack and a rolling tail in
		-- the open, and this is the ONE sample in Roblox's licensed catalogue whose own store record
		-- is that sentence -- every search for a hunting rifle returns user re-uploads of Call of
		-- Duty, Fortnite and CS:GO audio, none of it ours to ship. The whole Guns family was swept
		-- and measured; the note's section 4 lists what was rejected and why.
		--
		-- MEASURED, ALL OF IT: shotgun 0.92 s, the Barrett this replaces 3.36 s, this 4.95 s. So the
		-- tail is 5.4x the shotgun's and 1.5x the gun it replaces, which IS the roll.
		--
		-- `pitch = 0.88` IS THE CALIBRE. Dropping the sample two semitones moves the whole report
		-- down: a bigger bore is a lower, slower bang, and this is the one dial that makes a sample
		-- sound like more gun than it was recorded from.
		--
		-- `cut = 2.0, fade = 0.8` AND THE PLURAL IS WHY. "Gun Shot*s*" and "Blast*s*" are a TAKE,
		-- not a round, exactly as the Barrett's "Single Shot*s*" was: a 4.95 s clip from a gunfire
		-- library may hold more than one bang. At this pitch 2.0 s of playback is 1.76 s of source,
		-- and the last 0.8 s of it is already going quiet -- so the crack and its roll are heard in
		-- full and anything behind them arrives under a fade. The Barrett was cut at 1.6 s and
		-- nobody heard a doublet, so this is the same window plus the tail.
		--
		-- NOBODY HERE HAS HEARD IT. The Builder cannot play audio. KAREN'S EARS DECIDE, and every
		-- number in this line is one line: the Barrett is `9118173739` and the alternatives measured
		-- beside this one are in the note.
		shot = { id = "rbxassetid://9114725315", cut = 2.0, fade = 0.8, pitch = 0.88 },
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
		-- sight picture is the other thing: the gun is gone, the world outside the tube is darkened
		-- down (task 146: Karen's reference keeps it visible), and the magnified world sits in a
		-- circle with the reticle on it.
		--
		-- `diameterDeg` IS THE OUTER CIRCLE, AND THE GLASS IS WHAT IS LEFT INSIDE THE TUBE. The rim is
		-- drawn INWARD from this edge (`Hud.layoutScope`: `inner = diameter - 2 * rimPx`), so the
		-- clear lens is `diameterDeg - 2 * rimThickDeg` -- and that, not this number, is what has to
		-- match the reference. Round 1 of task 146 missed it: at the hairline `rimThickDeg = 0.45`
		-- the two were nearly the same number, and at 1.69 they are not (the Reviewer's finding 1).
		--
		-- MEASURED off Karen's own frame (`<assets-dir>/references/rifle/karen-scope-target.jpg`):
		-- the clear glass is 960 px of a 1080-high frame, 0.889 of the height, and the tube around it
		-- is 92 px. So the glass wants 0.889 * 19.87 = 17.66 degrees and the whole circle wants that
		-- plus both walls: 17.66 + 2 * 1.69 = 21.04.
		--
		--   glass = 21.0 - 2 * 1.69 = 17.62 deg = 0.887 of the height   (hers: 0.889)
		--
		-- THE TUBE THEREFORE RUNS OFF THE TOP AND BOTTOM OF THE SCREEN, which is exactly what her
		-- frame shows -- the scope body is cut by the frame edge, not floating inside it.
		-- `Hud.layoutScope` bounds the GLASS to the screen's short side rather than the whole
		-- circle, so this stays true at any aspect ratio.
		--
		-- `atBlend` IS 0.98 AS A TOLERANCE, NOT AS A THRESHOLD, and round 2's comment here had the
		-- reason wrong (the Reviewer caught it): `Mode.step` raises the blend LINEARLY --
		-- `math.min(1, blend + dt / seconds)` -- so it reaches exactly 1 and 0.98 is never a sample
		-- at 60 fps. What the hundredth buys is a frame rate low enough to step past it, and the
		-- predicates compare with `>=`, so the picture arrives on the frame the raise finishes
		-- either way. The Director asked for "snaps in when blend ~ 1" and that is what it does.
		eyepiece = {
			atBlend = 0.98,
			diameterDeg = 21.0,
			-- THE TUBE IS THICK, AND THAT IS THE SECOND THING HER FRAME SHOWS. The scope body around
			-- the glass is 92 px of 1080 in it -- 0.085 of the height, which at this FOV is 1.69
			-- degrees. Task 141's 0.45 was a hairline bevel, not a scope body.
			rimThickDeg = 1.69,
			-- NEAR-BLACK (task 147), AND TASK 146 PUT IT AT 60/60/62 FOR A REASON THAT DID NOT SURVIVE
			-- THE SCREEN: "a black ring against a black mask is one shape". That was true of task
			-- 141's OPAQUE mask and is not true of this one -- the surround is 0.45 transparent now,
			-- so it is dark WORLD rather than black, and the tube reads against it.
			--
			-- THE DIRECTOR ASKED FOR IT, NOT KAREN: her note of 2026-10-10 ~11:30 is the rings and
			-- the bolt, and says nothing about the tube (`PLAYTEST.md`). The dispatch's words are
			-- "near-black like Karen's reference, not light grey". Sampled off that reference again,
			-- in the SHADOWED part of the body rather than the lit top edge: a scope is a dark object
			-- with a highlight on it, and one flat UI colour has to pick the body.
			--
			-- IT MAY NOW BE TOO DARK -- `t147-ship-scope.png` has the tube nearly merging with the
			-- darkened surround, which is the cost of having no highlight. Karen's eye owns that.
			rimColor = Color3.fromRGB(22, 22, 24),
			maskColor = Color3.fromRGB(0, 0, 0),
			-- THE WORLD OUTSIDE SURVIVES (task 146). In her frame the grass and trunks past the tube
			-- are plainly there, just dark. 0.45 keeps about half of them; 0 is task 141's solid
			-- black. ROBLOX UI CANNOT BLUR, so "softened" is darkened here and nothing else -- said
			-- out loud because it is the one half of her note this cannot do.
			maskTransparency = 0.45,
		},
		-- KAREN'S CROSS (task 146), verbatim: *"scope aiming has to be different cross look at the
		-- exaple I attached"*. Her reference is two black hairlines running the FULL width and
		-- height of the glass, edge to edge, with no ring and no duplex posts -- so the ring and the
		-- posts are simply not in this table any more, and `Hud.layoutReticle` draws what it finds.
		--
		-- THE DOT IS STILL HERE AND IT IS A TOGGLE. She asked for a red dot on 2026-10-09 and her
		-- example has none; `enabled` is the one line that settles it either way. It defaults ON and
		-- SMALL -- 0.085 degrees is about 4.6 px on a 1080-high viewport -- so it reads as a lit dot
		-- sitting on the cross rather than as a blob covering the animal.
		reticle = {
			kind = "crosshair",
			spanLens = true,
			-- THE RED DOT. 0.085 degrees at this scope's 19.87 is about 4.6 px on a 1080-high
			-- viewport: a dot you can hold on a boar's chest at 150 studs, and not a blob that
			-- hides it. The halo is three times it at 0.55 transparency -- enough of an edge to
			-- read against sky, snow or a pale trunk, which a bare red square does not.
			dot = {
				enabled = true,
				deg = 0.085,
				color = Color3.fromRGB(255, 48, 36),
				haloDeg = 0.26,
				haloColor = Color3.fromRGB(120, 0, 0),
				haloTransparency = 0.55,
			},
			-- 0.06 degrees is 3.3 px on a 1080-high viewport at this FOV, which is what the lines
			-- in her reference measure. There is no gap and no arm length: `spanLens` runs them from
			-- the inside of the tube, through the centre, to the inside of the tube.
			crossThickDeg = 0.06,
			color = Color3.fromRGB(10, 10, 10),
		},
	} :: Scope,
}

Shotgun.deepFreeze(Rifle.CONFIG)

return Rifle
