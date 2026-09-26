--!strict
-- Weapon.Shape: WHAT THE GUN LOOKS LIKE, as data. Pure: it creates no Instance, reads no service and
-- holds no state, so a spec can assert every proportion with no Tool, no character and no physics.
--
-- THE DIVISION IS THE ONE THIS REPO ALREADY USES TWICE: a pure list plus one builder.
-- `MapGen.Layout.furniture` returns pieces and `MapGen.Props.furniture` builds what it is handed
-- (Task 66); here `Shape.pieces` returns the gun and `Weapon.Hardware` -- still the only writer of
-- Tool Instances (docs/design/shotgun.md section 3.1) -- builds and welds them. Nothing else may
-- draw a shotgun: the ADS viewmodel CLONES the built Handle (docs/design/camera.md section 3.2), so
-- the first-person gun and the third-person gun are the same object by construction rather than by
-- two lists agreeing.
--
-- WHY PARTS AND NOT A MESH. Two Meshy text-to-3D previews (40 credits, runs
-- shotgun.handle_v1-20260926T1850Z and _v2-20260926T1917Z) both came back an over-under with short
-- barrels and a pistol grip, from two different prompts; the Director stopped buying text for this
-- model. `.rbxm` is banned outright (CLAUDE.md) and typed values in `.model.json` are refused by the
-- harness, so a gun in this repo is built in code from numbers or it does not exist.
--
-- EVERY PROPORTION IS THE REAL GUN'S, AND EVERY ONE IS PUBLISHED. Beretta 486 Parallelo, the gun
-- Karen asked for (docs/asset-briefs/shotgun.handle_v2.brief.json): barrel 28 in, overall 45.0 in,
-- length of pull 14.5 in, single trigger, round-bodied action, 8 mm concave rib.
--   https://www.gunmart.net/gun-reviews/shotguns/side-by-side-shotgun/beretta-a486-parallelo
-- DIMENSIONS ONLY: no engraving, lettering, logo or maker mark is modelled, and the brief forbids
-- them anyway. Roblox's own Weapons Kit is the structural pattern (a Tool whose gun is "a Model made
-- up of one or more BaseParts ... with one designated as the PrimaryPart", plus a handle and a tip
-- attachment), under Roblox's Limited Use License; nothing is copied from it.
--   https://github.com/Roblox/creator-docs/blob/main/content/en-us/resources/weapons-kit.md
--
-- Note:   docs/research/2026-09-26-shotgun-model.md
-- Design: docs/design/shotgun.md (sections 3.1, 8)
local Shape = {}

export type Piece = {
	name: string,
	size: Vector3,
	offset: CFrame, -- relative to the Handle's centre; -Z is the muzzle, as GRIP assumes
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType,
}

-- THE THREE PUBLISHED FRACTIONS, and nothing else about the length is a guess. They are fractions
-- rather than studs because the gun's absolute length is `HANDLE_SIZE.Z`, which this task may not
-- change: MUZZLE_OFFSET and GRIP are built on it. 28 + 14.5 = 42.5 of 45 leaves 2.5 inches from the
-- breech face to the trigger, which is what a break action has, so the three numbers agree with each
-- other -- the check that the spec sheet was read right.
Shape.BARREL_FRACTION = 28 / 45
Shape.BREECH_TO_TRIGGER_FRACTION = 2.5 / 45
Shape.PULL_FRACTION = 14.5 / 45

-- SHAPE NUMBERS THAT ARE NOT ON THE SPEC SHEET: the Director's pick, changeable (Karen's rule,
-- 2026-09-26 -- styling never blocks). Studs, in the Handle's own frame.
local BARREL_DIAMETER = 0.17 -- ~2x life size: 12-gauge tubes at true scale are 0.08 studs and would
local BARREL_GAP = 0.18 -- centre to centre, so the two tubes touch and read as ONE pair
local BARREL_Y = 0.12 -- the bore line, above the action's centre
local RIB_THICK = 0.03 -- the real rib is 8 mm and concave; at this thickness that is sub-pixel
local ACTION_LENGTH = 0.55 -- the body, which the barrels sit into and the trigger hangs under
local ACTION_SIZE = Vector3.new(0.36, 0.34, ACTION_LENGTH)
-- THE ACTION HANGS BELOW THE BORE LINE, AND THE SCREENSHOT IS WHY (rule 5). The first build centred
-- it on the bore, which put its top face level with the top of the barrels -- and in ADS the camera
-- looks down the gun from behind, so the near action box hid the whole barrel pair and the bead
-- behind it: a first-person shotgun with no barrels and nothing to aim with. On a real break gun the
-- barrels lie ON the action's water table and the rib is the highest line on the gun, which is what
-- makes a bead sight work at all. So the action's TOP is the bore line: the barrels sit half into it,
-- and everything above the bore -- the upper half of each tube, the rib, the bead -- is clear.
local ACTION_TOP = 0.12 -- = BARREL_Y
local FOREND_SIZE = Vector3.new(0.22, 0.14, 0.8) -- SPLINTER: slim and short, not a beaver tail
local STOCK_SIZE = Vector3.new(0.26, 0.3, 1.3)
-- STRAIGHT ENGLISH STOCK: one straight piece, no pistol grip, nose-up so the butt drops below the
-- bore line. The real gun's drop at heel is about 2.25 in over a 14.5 in pull, which is 8.8 degrees.
local STOCK_DROP_DEG = 8

-- Every piece of the gun, in build order, for a Handle of `config.HANDLE_SIZE`. Pure.
function Shape.pieces(config): { Piece }
	local look = config.LOOK
	local total = config.HANDLE_SIZE.Z
	local half = total / 2

	-- The gun laid out along its own axis. -Z is the muzzle (docs/design/shotgun.md, the GRIP row),
	-- so the barrels run FORWARD from the muzzle end and the butt is at +half.
	local barrelLength = total * Shape.BARREL_FRACTION
	local muzzleZ = -half
	local breechZ = muzzleZ + barrelLength
	local triggerZ = breechZ + total * Shape.BREECH_TO_TRIGGER_FRACTION
	local barrelZ = (muzzleZ + breechZ) / 2

	local barrelRadius = BARREL_DIAMETER / 2
	local ribY = BARREL_Y + barrelRadius + RIB_THICK / 2
	local actionZ = breechZ + ACTION_LENGTH / 2 - 0.1 -- the barrels sit INTO the body
	local actionY = ACTION_TOP - ACTION_SIZE.Y / 2
	local actionTop = ACTION_TOP
	local actionBottom = actionY - ACTION_SIZE.Y / 2
	local stockZ = triggerZ + STOCK_SIZE.Z / 2 + 0.06

	-- A cylinder's length runs along its own X, so a barrel is turned a quarter turn to lie along Z.
	local lying = CFrame.Angles(0, math.pi / 2, 0)
	local pieces: { Piece } = {}
	local function add(piece: Piece)
		table.insert(pieces, piece)
	end

	for _, side in ipairs({ { name = "BarrelLeft", x = -BARREL_GAP / 2 }, { name = "BarrelRight", x = BARREL_GAP / 2 } }) do
		add({
			name = side.name,
			size = Vector3.new(barrelLength, BARREL_DIAMETER, BARREL_DIAMETER),
			offset = CFrame.new(side.x, BARREL_Y, barrelZ) * lying,
			color = look.barrel,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
	end

	add({
		name = "Rib",
		size = Vector3.new(BARREL_GAP - 0.06, RIB_THICK, barrelLength),
		offset = CFrame.new(0, ribY, barrelZ),
		color = look.barrel,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	-- THE BEAD: the one bright thing on the gun, and the only aiming mark a side-by-side has.
	add({
		name = "Bead",
		size = Vector3.new(0.05, 0.05, 0.05),
		offset = CFrame.new(0, ribY + RIB_THICK / 2 + 0.02, muzzleZ + 0.05),
		color = look.bead,
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
	})

	add({
		name = "Action",
		size = ACTION_SIZE,
		offset = CFrame.new(0, actionY, actionZ),
		color = look.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	-- The top lever, which is how anyone can tell a break action from a repeater at a glance.
	add({
		name = "TopLever",
		size = Vector3.new(0.06, 0.03, 0.2),
		offset = CFrame.new(0, actionTop + 0.015, actionZ - 0.06),
		color = look.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	add({
		name = "Forend",
		size = FOREND_SIZE,
		offset = CFrame.new(0, BARREL_Y - barrelRadius - FOREND_SIZE.Y / 2, breechZ - 0.35 - FOREND_SIZE.Z / 2),
		color = look.wood,
		material = Enum.Material.Wood,
		shape = Enum.PartType.Block,
	})

	add({
		name = "Stock",
		size = STOCK_SIZE,
		offset = CFrame.new(0, actionY + 0.02, stockZ) * CFrame.Angles(math.rad(STOCK_DROP_DEG), 0, 0),
		color = look.wood,
		material = Enum.Material.Wood,
		shape = Enum.PartType.Block,
	})

	add({
		name = "TriggerGuard",
		size = Vector3.new(0.1, 0.03, 0.3),
		offset = CFrame.new(0, actionBottom - 0.08, triggerZ),
		color = look.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	-- ONE trigger, because the 486 has a single trigger and the brief says so.
	add({
		name = "Trigger",
		size = Vector3.new(0.04, 0.06, 0.04),
		offset = CFrame.new(0, actionBottom - 0.03, triggerZ),
		color = look.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	return pieces
end

-- Where the barrels end, in the Handle's frame: the number `MUZZLE_OFFSET` has to agree with, so a
-- spec can say "the muzzle attachment is at the muzzle" rather than "both are -2.2".
function Shape.muzzleZ(config): number
	return -config.HANDLE_SIZE.Z / 2
end

return Shape
