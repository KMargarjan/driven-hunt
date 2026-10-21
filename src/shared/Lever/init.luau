--!strict
-- Lever: every number the lever-action rifle has, frozen, with no writer -- the shape
-- `src/shared/Rifle/init.luau` already is, and a sibling of it rather than a second table inside it
-- for the reason that file's own header gives: *"the file that holds [Karen's accepted numbers] must
-- not become the file everybody edits"*. **The two rifles share no number. They share the
-- machinery.**
--
-- Karen, 2026-10-20: *"so you have things to do / deer / weapons / make it work like we have now"*,
-- and she bought the model herself (Jeick, "Lever action rifle" on Fab: a Ruger-made Marlin 1895 SBL
-- in .45-70). Her standing bar is that shooting, weapon and reload must be perfect.
--
-- EVERY NUMBER HERE IS A DIAL, and the ones that are Karen's say so. Nobody here has heard a sound
-- or felt a kick.
--
-- Design: docs/design/lever-rifle.md (sections 5.1, 6, 9, 10)
-- Note:   docs/research/2026-10-20-lever-action.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Lever = {}

export type CycleStep = { kind: Shotgun.ActionKind, wait: number }

Lever.CONFIG = {
	-- ---------------------------------------------------------------- ballistics
	-- 600 STUDS IS 168 m, against the scoped rifle's 800 (224 m) and the slug's 330 (92 m). The
	-- Director's brief asks for "~150 m practical", and this is that plus the margin a shot taken
	-- slightly uphill needs. It is the one number that decides whether a long shot exists at all:
	-- `Weapon.Flight` retires the projectile when `travelled` reaches it.
	--
	-- WHAT THIS GUN IS FOR. A .45-70 carbine is a 150-metre gun with a heavy bullet, and the whole
	-- trade against the Rigby is written in these three lines: it reaches three quarters as far, it
	-- carries five instead of three, and it cycles half a second faster.
	RANGE_STUDS = { Slug = 600 },
	PELLETS = { Slug = 1 },
	-- NO CONE, and the reason is `Rifle.CONFIG.SPREAD_FULL_DEG`'s own: *"a number nobody can predict
	-- is the wrong place to put character"*. This gun's character is its reach, its drop and its
	-- cycle. `Pattern.directions` needs no branch for it -- `cos(0)` is 1, so the one bullet comes
	-- out exactly along `aim`.
	SPREAD_FULL_DEG = { Slug = 0 },
	-- THE CARTRIDGE IS A .45-70, AND THESE ARE HORNADY'S OWN PUBLISHED FIGURES for the load a Marlin
	-- 1895 is sold for: LEVERevolution 325 gr FTX, 2050 / 1729 / 1450 / 1225 fps at 0 / 100 / 200 /
	-- 300 yd from a 24-inch barrel (research note section 3; two independent retail pages compared,
	-- so a typo on one cannot become this gun's muzzle velocity).
	--
	-- 2050 fps = 624.84 m/s, and at 0.28 m per stud that is 2231.6.
	MUZZLE_STUDS_PER_S = { Slug = 2232 },
	-- QUADRATIC DRAG AS ONE COEFFICIENT, per STUD: `v(s) = v0*exp(-k*s)`, task 185's own model.
	-- FITTED TO THE 100 yd POINT ONLY (326.57 studs): `ln(2050/1729) / 326.57` = 5.214e-4. It then
	-- PREDICTS 1459 fps at 200 yd against the published 1450 (+0.6%) and 1231 at 300 yd against 1225
	-- (+0.5%), with nothing fitted to either. That is the whole justification for one number instead
	-- of a G1 drag table -- and it fits this cartridge BETTER than it fits the .416, whose own
	-- prediction is 0.9% high.
	DRAG_PER_STUD = { Slug = 5.21e-4 },
	-- 357 STUDS IS 100 m, WHICH IS WHERE AN IRON-SIGHTED .45-70 IS ZEROED. The trajectory crosses
	-- the sight line exactly here, so a still target at 100 m is hit dead centre
	-- (`Ballistics.launchDirection`). The scoped rifle is zeroed at 200 m because it is a 200 m gun;
	-- this one is not.
	ZERO_STUDS = { Slug = 357 },
	-- HOW MUCH OF REAL GRAVITY THIS BULLET FALLS AT, AND IT IS KAREN'S DIAL.
	--
	-- AT 1.0 -- real gravity, which is what `Ballistics.CONFIG.GRAVITY_STUDS_PER_S2` is -- this
	-- bullet off a 100 m zero is +4.14 cm at 50 m, dead on at 100 m and **-14.84 cm at 150 m**. That
	-- is real, and it is also exactly the complaint task 189 was raised for (Karen, 2026-10-15: *"it
	-- has to be acurat 100% 100m 150m"*).
	--
	-- BOTH TERMS OF THE DEVIATION ARE EXACTLY PROPORTIONAL TO g (`Ballistics.dropAt` multiplies by it
	-- and nothing else does), so this scales the whole band and moves nothing else. At 0.35 the band
	-- is **+1.45 / 0.00 / -5.19 cm** at 50 / 100 / 150 m -- inside any zone on a boar -- while the
	-- bullet still VISIBLY falls past 150 m, where the scoped rifle's 0.12 does not. That difference
	-- is the point: the two guns should not shoot flat in the same way.
	--
	-- AND IT DOES NOT TOUCH THE LEAD. `Ballistics.timeToRange` never reads gravity, so every stud of
	-- lead on a running boar is bit-for-bit what it would be at 1.0. Both directions are reachable by
	-- parameter (`Ballistics.dropAt` takes `g`), which is why this ships without a feature flag --
	-- the same call as 185a(h) and 189.
	GRAVITY_SCALE = { Slug = 0.35 },
	AMMO_KINDS = { "Slug" },
	-- THE WIRE WORD STAYS `Slug` ON ALL THREE GUNS, because `Boar.Wound.damageFor` branches
	-- `if ammo == "Slug"` and any new string would be charged as a buckshot PELLET. The word on
	-- screen is `AMMO_LABEL`'s business and the Hud's alone (`Hud.readoutFor`).
	AMMO_LABEL = { Slug = ".45-70" },
	INITIAL_AMMO = "Slug" :: Shotgun.AmmoKind,
	-- TEN IN THE POCKET: two tubes' worth. Enough that the gate reload is something that happens in a
	-- drive rather than a thing you read about, and not so many that the allowance stops meaning
	-- anything. Karen's dial.
	START_RESERVE = { Slug = 10 },

	-- ---------------------------------------------------------------- the action
	-- FIVE ROUNDS, AND IT IS MEASURED OFF THE MODEL'S OWN TUBE. The magazine tube spans 1.147 of the
	-- gun's 4.905 units in the bought file = 9.5 inches of a 40.5-inch rifle, which is 3.7 cartridges
	-- of 2.55 inches: FOUR IN THE TUBE AND ONE IN THE CHAMBER, which is what a 22-inch Marlin 1895
	-- holds. `barrels` in the reducer is already an array of Live/Spent/Empty, so a tube of five IS
	-- that array with five entries.
	BARRELS = 5,
	MAGAZINE = 5, -- what the gun holds; `BARRELS` is the same number and says why
	-- The trigger's own dwell before the lever starts. The rifle's, because there is no second
	-- barrel to pick on either gun.
	BARREL_DELAY = 0.12,
	-- THE CYCLE IS AUTOMATIC. A lever gun that needed `R` after every shot would not be a lever gun;
	-- both branches stay reachable by parameter (`AUTO_CYCLE = false` makes `R` the cycle).
	AUTO_CYCLE = true,
	-- ONE THROW IS TWO STEPS, and the source says which two: Hunter-Ed's *"eject, feed, cock"*. Down
	-- and forward EJECTS (`Break`), back FEEDS AND CHAMBERS (`Close`). There is no `Load` here --
	-- nothing is fed by hand during a cycle, which is the same reason the bolt rifle's `CYCLE` has
	-- none, and it is why this weapon adds no primitive to the reducer.
	--
	-- 1.10 s TOTAL, BRACKETED BY TWO NUMBERS THIS REPO HAS MEASURED ON SCREEN. Faster than the bolt's
	-- 1.62 -- which is KAREN'S OWN number from task 184 (*"I think it reloads to fast has to be 1 s
	-- slower"*, and, asked which sequence, *"Bolt after each shot"*) -- because a lever throw is one
	-- continuous motion of the hand that is already on the grip (Gun Digest, note 4.2) and a lever
	-- cycles faster than a bolt (Ranger Point, note 4.3). Slower than the 0.62 s the bolt first
	-- shipped at, which read as too fast on screen.
	--
	-- THE SPLIT IS THE BOLT'S OWN RATIO (0.68 / 0.94 = 42% / 58%), so the out-stroke is the shorter
	-- half and only the pace changed. It is a dial and it is Karen's.
	CYCLE = {
		{ kind = "Break" :: Shotgun.ActionKind, wait = 0.46 },
		{ kind = "Close" :: Shotgun.ActionKind, wait = 0.64 },
	} :: { CycleStep },
	CYCLE_TOTAL = 1.10, -- the sum; `lever.spec` asserts it against the list
	-- WHAT OPENING THE ACTION THROWS AWAY: the fired case, and nothing else. The shotgun's `"all"`
	-- would dump four live rounds down the hill after every shot. This is the direct consequence of
	-- "eject" meaning the spent case in a tube gun (note 4.1).
	CYCLE_EJECTS = "spent",
	-- THE RELOAD IS CARTRIDGES THROUGH THE LOADING GATE, ONE AT A TIME, and it adds no primitive
	-- either: `StateMachine.apply`'s `Load` fills EXACTLY ONE empty chamber from the pocket per step,
	-- which is precisely one cartridge through one gate. The shape is the shotgun's own reload with
	-- the tube's count instead of two barrels.
	--
	-- 2.90 s AGAINST THE RIFLE'S 1.97 s MAGAZINE CHANGE, AND THAT IS THE TRADE. Filling a tube one
	-- round at a time is slow; that is the price of carrying five instead of three. A PARTIAL top-up
	-- is correspondingly shorter -- `Weapon.cycleRefusal` answers `"finish"` when the tube fills, so
	-- two rounds cost 0.40 + 2 * 0.42 + 0.40 = 1.64 s rather than the full 2.90.
	--
	-- `Break` IS 0.40 HERE AND 0.46 IN `CYCLE`, DELIBERATELY: thumbing the gate open is not throwing
	-- the lever. `StateMachine.waitFor` is told which list is being run (task 184), so each sequence
	-- is charged its own window.
	RELOAD = {
		{ kind = "Break" :: Shotgun.ActionKind, wait = 0.40 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.42 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.42 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.42 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.42 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.42 },
		{ kind = "Close" :: Shotgun.ActionKind, wait = 0.40 },
	} :: { CycleStep },
	RELOAD_TOTAL = 2.90,
	-- AN EMPTY RIFLE FILLS ITSELF, like the bolt gun. A dial, because a reload nobody asked for is
	-- the kind of thing that is right until it is not.
	AUTO_RELOAD_WHEN_EMPTY = true,
	-- The Hud shows ROUNDS LEFT over capacity -- `5/5` -- rather than one glyph per chamber, which
	-- for five chambers is not what any repeater shows anybody.
	READOUT = "magazine",

	-- ---------------------------------------------------------------- the hardware
	-- 4.0 STUDS, NOT THE OTHER TWO GUNS' 4.4, AND IT IS A FACT ABOUT THE GUNS. A Rigby stalking rifle
	-- and a Beretta 486 are both about 45 inches, which is where 4.4 came from; a Marlin 1895 is
	-- about 40.5, so 40.5 / 45 * 4.4 = 3.96. A lever carbine is VISIBLY shorter and that is half of
	-- what it looks like. Everything downstream is per-row data and this gun's poses are authored
	-- fresh either way, so the shorter gun costs nothing and buys its silhouette.
	HANDLE_SIZE = Vector3.new(0.4, 0.5, 4.0),
	HANDLE_TRANSPARENCY = 1, -- the Handle is the envelope, not the gun (Shotgun.CONFIG's own rule)
	-- The rifle's 1.4 scaled by 4.0 / 4.4. The Handle's -Z is the muzzle, so the barrel points away.
	GRIP = CFrame.new(0, 0, 1.27),
	MUZZLE_OFFSET = Vector3.new(0, 0, -2.0), -- half of HANDLE_SIZE.Z: the muzzle

	-- THE WORLD GUN'S FALLBACK COLOURS (`Weapon.ShapeLever`) -- what is drawn before the uploads
	-- load, and never on top of them. They are THIS model's own: an 1895 SBL is a STAINLESS rifle
	-- with a GREY LAMINATE stock, which is why none of these is the Rigby's blued steel and walnut.
	-- Sampled off the prepped previews; above the albedo floor task 22 measured.
	LOOK = {
		barrel = Color3.fromRGB(150, 152, 156),
		action = Color3.fromRGB(168, 170, 173),
		-- The finger lever is the same stainless as the receiver it pins into.
		lever = Color3.fromRGB(168, 170, 173),
		-- "wood" by name, grey laminate in fact: the row's `HANDLE_COLOR` reads this key, as the
		-- rifle's does, so the name is the slot rather than a claim about the material.
		wood = Color3.fromRGB(76, 74, 72),
	},

	-- THE MANIFEST KEYS ARE NOT HERE, and that is deliberate -- the Reviewer's round-1 note on the
	-- rifle. A third copy of them, read by nothing and possibly in a different order from the two
	-- that ARE read (`Weapons.ROWS.lever.ASSET_KEYS` for the world Tool and `Lever.Geometry.
	-- ASSET_KEYS` for the drawn gun), is a trap: the order decides which key is worn as `Model`.

	-- ---------------------------------------------------------------- the voice
	-- NO AUDIO IS UPLOADED (the Director's rule for this task). Every id here is Roblox-provided
	-- licensed library audio that `Rifle.CONFIG.SOUND` already ships and that this repo has MEASURED
	-- to load in the Forest Test with `ContentProvider:PreloadAsync`
	-- (docs/research/2026-10-10-rifle-bolt-magazine-sound.md section 4).
	--
	-- NOBODY HERE HAS HEARD ANY OF THEM. The Builder cannot play audio. KAREN'S EARS DECIDE, and
	-- every number in these three lines is one line.
	SOUND = {
		-- The rifle's own report, PITCHED DOWN from its 0.88. A .45-70 is a bigger, slower,
		-- lower-pressure bore than a .416 Rigby: a boom where the Rigby is a crack, and dropping the
		-- sample is the one dial that makes a recording sound like more gun than it was taken from.
		-- `cut`/`fade` are the rifle's, because it is the rifle's 4.95 s sample and "Gun Shot*s*" is
		-- a TAKE and not a round.
		shot = { id = "rbxassetid://9114725315", cut = 2.0, fade = 0.8, pitch = 0.80 },
		-- The rifle's clack, BELOW its own 1.15 and a hair longer: a lever throw is a heavier, duller
		-- piece of steel moving further than a bolt handle. Played on both edges of the action by
		-- `CameraBoot`, which is already how a weapon with a `bolt` voice is handled.
		bolt = { id = "rbxassetid://9117889191", cut = 0.40, fade = 0.10, pitch = 0.95 },
		-- ONE CARTRIDGE THROUGH THE GATE (task 224). "Shotgun Handle 1 (SFX)", ProSoundEffects,
		-- "Grab, Handle" -- a short handling click, which is what pushing a round past a spring cover
		-- is. THE KEY IS NEW AND THE NAME IS WHY: the rifle's `magazine` voice would put the word
		-- *magazine* on a gun that has none, which is the naming drift this repo keeps paying for.
		-- A row without this key is silent at the gate, and both shipped guns are exactly that.
		load = { id = "rbxassetid://9119115171", cut = 0.30, fade = 0.08, pitch = 0.85 },
	},
}

Shotgun.deepFreeze(Lever.CONFIG)

return Lever
