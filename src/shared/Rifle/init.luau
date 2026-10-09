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
export type Reticle = {
	kind: string,
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

export type Scope = {
	aimFovDeg: number,
	magnification: number,
	sway: { ampDeg: number, periodSeconds: number },
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
	-- Ten rounds, not the shotgun's 24: a ten-minute drive is one shot per animal, and a box nobody
	-- empties is a number that means nothing.
	START_RESERVE = { Slug = 10 },

	-- ---------------------------------------------------------------- the action
	BARRELS = 1,
	-- The trigger's own dwell before the bolt starts, shorter than the shotgun's 0.25 because there
	-- is no second barrel to pick.
	BARREL_DELAY = 0.12,
	-- THE CYCLE IS AUTOMATIC, and that is a dial rather than a belief: with one chamber a manual
	-- cycle means pressing R after EVERY shot, which is a reload and not a bolt. `AUTO_CYCLE = false`
	-- makes R the cycle and both branches are reachable by parameter (design 8.1, Karen's to change).
	AUTO_CYCLE = true,
	-- "Open, eject, feed, close" with one chamber is three of the five primitives
	-- `StateMachine.apply` already has -- so the rifle adds no state, only this list.
	CYCLE = {
		{ kind = "Break" :: Shotgun.ActionKind, wait = 0.30 },
		{ kind = "Load" :: Shotgun.ActionKind, wait = 0.35 },
		{ kind = "Close" :: Shotgun.ActionKind, wait = 0.25 },
	} :: { CycleStep },
	CYCLE_TOTAL = 0.90, -- the sum; `rifle.spec` asserts it against the list

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
		barrel = Color3.fromRGB(58, 60, 64),
		action = Color3.fromRGB(78, 79, 82),
		wood = Color3.fromRGB(104, 64, 38),
		scope = Color3.fromRGB(42, 43, 46),
	},

	-- The manifest keys this weapon wears, in wear order (`ServerStorage.Assets`).
	ASSET_KEYS = { "rifle.stock", "rifle.action", "rifle.bolt", "rifle.scope" },

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
		reticle = {
			kind = "duplex",
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
