--!strict
-- Gun: the FIRST-PERSON shotgun's exact geometry, as data. Pure -- it creates no Instance, reads no
-- service and holds no state, so a spec asserts every proportion with no Tool, no character and no
-- camera. `Camera.Viewmodel` is the one thing that builds it (CLAUDE.md rule 3).
--
-- WHY IT EXISTS (task 99). Karen, 2026-10-01: "shooting, weapon, reload, all has to be perfect".
-- The gun on screen was one AI-generated mesh cut in two, so the break-open frame showed a torn
-- breech, a shell loose in the gap and a left hand on nothing. Meshy is weak on machined metal --
-- its barrels came back faceted and wavy along the top, which is the one surface a player looks
-- ALONG when aiming. So the METAL is exact geometry and the WOOD stays Meshy's (Karen's decision,
-- 2026-10-01).
--
-- WHY PARTS AND NOT A GENERATED MESH: `docs/research/2026-10-01-exact-metal-gun.md`, section 3. The
-- short of it -- a Roblox Cylinder is ANALYTICALLY round, so there is no facet count at which the
-- barrel stops being round, and a part gun is numbers in a file the Director can change and the
-- Reviewer can read rather than an upload.
--
-- Pattern: a pure piece list plus one builder, which this repo already does twice --
-- `Weapon.Shape` + `Weapon.Hardware` for the world gun, `MapGen.Layout` + `MapGen.Props` for the
-- furniture (rule 2: borrow the pattern that is here).
--   Roblox part shapes: https://create.roblox.com/docs/reference/engine/enums/PartType
--   Beretta 486 Parallelo, the gun Karen asked for -- barrel 28 in of 45 in overall, single
--   trigger, round-bodied action, 8 mm concave rib:
--   https://www.gunmart.net/gun-reviews/shotguns/side-by-side-shotgun/beretta-a486-parallelo
--
-- IT MOVES NO NUMBER A SHOT DEPENDS ON. `Shotgun.CONFIG.HANDLE_SIZE`, `MUZZLE_OFFSET`, `GRIP` and
-- the hitbox are untouched; this is what is DRAWN under `workspace.CurrentCamera` for one player.
--
-- Note: docs/research/2026-10-01-exact-metal-gun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Gun = {}

-- WHICH GROUP A PIECE BELONGS TO, and it is the whole of the break-open. "body" is bolted to the
-- action and never moves; "barrels" swings down about the hinge pin, and everything in it goes with
-- it -- the two tubes, the rib, the bead, the bores and the wooden forend, exactly as on a real gun
-- where the forend is bolted to the barrels.
export type Group = "body" | "barrels"

export type Piece = {
	name: string,
	group: Group,
	size: Vector3,
	offset: CFrame, -- in the Handle's own frame: -Z is the muzzle, +X right, +Y up
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType,
	reflectance: number?,
}

-- ---------------------------------------------------------------- the numbers

-- THE ONE FRACTION FROM THE SPEC SHEET: 28 in of barrel in a 45 in gun. Everything else below is a
-- stud measurement in the Handle's frame, and every one of them is the Director's to change.
Gun.BARREL_FRACTION = 28 / 45

-- SLIMMER THAN THE OLD PART GUN (0.17): the uploaded mesh reads thick in first person and Karen's
-- reference is a game shotgun whose two tubes are a narrow pair. 0.145 at 2x life size still reads
-- as a 12-gauge pair at 3.65 studs.
local BARREL_DIAMETER = 0.145
local BARREL_GAP = 0.152 -- centre to centre: the two tubes touch, so they read as ONE pair
local BARREL_Y = 0.12 -- the bore line, and the action's top face
local RIB_WIDTH = 0.072
local RIB_THICK = 0.022
-- THE BORE, FAKED AND SAID TO BE FAKED. A Cylinder is solid, so the opening is a near-black disc
-- inset into each end of each tube -- four in all. At the aiming distance (3.65 studs) an unlit disc
-- inside a blued tube reads as a hole, which is what requirement 2 of the note asks for; it is not
-- one, and `Gun.spec` asserts only that each disc sits inside its tube's radius.
local BORE_INSET = 0.012 -- how far inside the tube's end face the disc sits
local BORE_FRACTION = 0.72 -- of the tube's diameter: a wall, then the hole

local ACTION_LENGTH = 0.62
local ACTION_WIDTH = 0.30 -- SHALLOW AND WIDE, which is what a side-by-side action is
local ACTION_HEIGHT = 0.26
local ACTION_TOP = BARREL_Y -- the barrels lie ON the water table; the rib is the highest line
local STANDING_BREECH_THICK = 0.055 -- the upright face the two chambers close against
local FLAT_BAR_LENGTH = 0.30 -- the bars that run FORWARD under the barrels, into the forend
local HINGE_PIN_DIAMETER = 0.07

local TRIGGER_GUARD_RADIUS = 0.085
local TOP_LEVER_LENGTH = 0.17

-- THE WOOD'S ENVELOPES. The two wooden pieces are Karen's Meshy models when they are loaded
-- (`Gun.WOOD_KEYS`); these sizes are what the MeshPart is scaled to, and what the fallback part is
-- when no mesh arrived -- so the gun has a forend and a stock either way and the silhouette is the
-- same. A gun with no wood is a real state (the load failed), not a reason to draw nothing.
local FOREND_SIZE = Vector3.new(0.20, 0.145, 0.78)
local STOCK_SIZE = Vector3.new(0.235, 0.30, 1.32)
local STOCK_DROP_DEG = 8 -- 2.25 in of drop over a 14.5 in pull

-- THE NAMES THE VIEWMODEL LOOKS FOR, so neither side carries a literal the other could disagree
-- with (the reason `HandAssets` and `Assets.KEYS` exist).
Gun.BODY_NAME = "GunBody"
Gun.BARRELS_NAME = "Barrels" -- the SAME name the old mesh gun's barrel piece has, so
-- `Camera.Viewmodel.hinge` and the left hand's parent rule are one rule for both guns.
Gun.FOREND_NAME = "Forend"
Gun.STOCK_NAME = "Stock"
Gun.WOOD_KEYS = table.freeze({ [Gun.FOREND_NAME] = "gun.forend", [Gun.STOCK_NAME] = "gun.stock" })

-- The colours. Blued steel is dark blue-black and METALLIC with some gloss; the action is a
-- case-hardened silver-grey, which is the contrast that makes a side-by-side read as one.
Gun.LOOK = table.freeze({
	blued = Color3.fromRGB(34, 38, 46),
	action = Color3.fromRGB(176, 178, 182),
	bore = Color3.fromRGB(9, 9, 11),
	bead = Color3.fromRGB(198, 158, 82),
	wood = Color3.fromRGB(86, 52, 32),
})

-- ---------------------------------------------------------------- the layout

-- WHERE EVERYTHING IS, along the gun's own axis, for a Handle of `config.HANDLE_SIZE`. One table, so
-- the pieces below and the three public answers (`hinge`, `chamber`, `sight`) are built from the
-- SAME arithmetic rather than from two copies of it -- the rule the bead's `Shape.beadOffset`
-- introduced in task 90.
function Gun.layout(config)
	local total = (config and config.HANDLE_SIZE or Shotgun.CONFIG.HANDLE_SIZE).Z
	local half = total / 2
	local barrelLength = total * Gun.BARREL_FRACTION
	local muzzleZ = -half
	local breechZ = muzzleZ + barrelLength
	local actionZ = breechZ + ACTION_LENGTH / 2
	return table.freeze({
		total = total,
		half = half,
		barrelLength = barrelLength,
		muzzleZ = muzzleZ,
		breechZ = breechZ,
		barrelZ = (muzzleZ + breechZ) / 2,
		barrelRadius = BARREL_DIAMETER / 2,
		ribY = BARREL_Y + BARREL_DIAMETER / 2 + RIB_THICK / 2,
		actionZ = actionZ,
		actionY = ACTION_TOP - ACTION_HEIGHT / 2,
		actionBottom = ACTION_TOP - ACTION_HEIGHT,
		breechFaceZ = breechZ + STANDING_BREECH_THICK / 2,
		triggerZ = actionZ + ACTION_LENGTH / 2 - 0.12,
		stockZ = actionZ + ACTION_LENGTH / 2 + STOCK_SIZE.Z / 2,
	})
end

-- THE HINGE, and this is what makes the break-open real rather than a mesh tearing. The pin sits at
-- the action's lower FRONT -- the knuckle -- and the barrel group rotates about the line through it
-- that runs across the gun (the X axis in the Handle's frame).
function Gun.hinge(config): Vector3
	local at = Gun.layout(config)
	return Vector3.new(0, at.actionBottom + HINGE_PIN_DIAMETER / 2, at.breechZ - 0.02)
end

-- WHERE A CHAMBER IS: the breech end of one tube, ON its bore line, so a shell placed here is INSIDE
-- the barrel rather than floating in the gap beside it. `Shotgun.barrelMuzzleOffset` is still the one
-- definition of which tube is which, so this module does not learn that the right barrel is +X.
function Gun.chamber(barrel: number, config): CFrame
	local at = Gun.layout(config)
	local across = Shotgun.barrelMuzzleOffset(barrel, config or Shotgun.CONFIG)
	return CFrame.new(across.X, BARREL_Y, at.breechZ - 0.10)
end

-- WHERE THE BEAD SITS, and the ONE place that decides it: the rib lies on the tubes, the bead sits
-- on the rib at the muzzle end. The aimed pose is solved FROM this (`Camera.Mode.aimOffset`), so a
-- second copy of the arithmetic would let the mark a player follows and the point the camera lines
-- up drift apart.
function Gun.beadOffset(config): Vector3
	local at = Gun.layout(config)
	return Vector3.new(0, at.ribY + RIB_THICK / 2 + 0.016, at.muzzleZ + 0.05)
end

function Gun.sight(config): CFrame
	-- Identity rotation: in this frame (0, 0, -1) is already the muzzle direction, and the rib is
	-- level, so the sight looks exactly where the barrels point.
	return CFrame.new(Gun.beadOffset(config))
end

function Gun.muzzle(config): CFrame
	local at = Gun.layout(config)
	return CFrame.new(0, BARREL_Y, at.muzzleZ)
end

-- ---------------------------------------------------------------- the pieces

-- A cylinder's length runs along its own X, so anything tubular is turned a quarter turn to lie
-- along Z. ONE conversion, named, for the reason every angle in this repo is converted once.
local LYING = CFrame.Angles(0, math.pi / 2, 0)
-- A cylinder across the gun (the hinge pin, the trigger guard's bars) lies along X already.
local ACROSS = CFrame.Angles(0, 0, 0)

-- Every piece of the first-person gun, in build order. Pure.
function Gun.pieces(config): { Piece }
	local at = Gun.layout(config)
	local pieces: { Piece } = {}
	local function add(piece: Piece)
		table.insert(pieces, piece)
	end

	-- ---------------- the barrel group: everything that swings on the pin
	for _, side in ipairs({
		{ name = "BarrelLeft", x = -BARREL_GAP / 2 },
		{ name = "BarrelRight", x = BARREL_GAP / 2 },
	}) do
		add({
			name = side.name,
			group = "barrels",
			size = Vector3.new(at.barrelLength, BARREL_DIAMETER, BARREL_DIAMETER),
			offset = CFrame.new(side.x, BARREL_Y, at.barrelZ) * LYING,
			color = Gun.LOOK.blued,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
			-- SOME GLOSS, NOT A MIRROR. Task 72 shipped "blued barrels" that were mirror chrome on
			-- screen; 0.06 lifts a highlight along the top of each tube without turning it silver.
			reflectance = 0.06,
		})
		-- THE TWO OPENINGS AT EACH END (requirement 2 of the note). A near-black disc INSET into the
		-- tube: it is not a hole and the note says so, but at the aiming distance an unlit disc
		-- inside a blued tube is what a bore looks like. The breech pair is what the player sees
		-- with the gun broken open, which is the frame this task exists to fix.
		for _, end_ in ipairs({
			{ suffix = "Muzzle", z = at.muzzleZ + BORE_INSET },
			{ suffix = "Breech", z = at.breechZ - BORE_INSET },
		}) do
			add({
				name = side.name .. "Bore" .. end_.suffix,
				group = "barrels",
				size = Vector3.new(0.004, BARREL_DIAMETER * BORE_FRACTION, BARREL_DIAMETER * BORE_FRACTION),
				offset = CFrame.new(side.x, BARREL_Y, end_.z) * LYING,
				color = Gun.LOOK.bore,
				material = Enum.Material.SmoothPlastic,
				shape = Enum.PartType.Cylinder,
			})
		end
	end

	-- THE RIB: slim, flat-topped, running the whole length between the tubes. It is the highest line
	-- on the gun, which is what makes a bead sight work at all.
	add({
		name = "Rib",
		group = "barrels",
		size = Vector3.new(RIB_WIDTH, RIB_THICK, at.barrelLength),
		offset = CFrame.new(0, at.ribY, at.barrelZ),
		color = Gun.LOOK.blued,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	add({
		name = "Bead",
		group = "barrels",
		size = Vector3.new(0.034, 0.034, 0.034),
		offset = CFrame.new(Gun.beadOffset(config)),
		color = Gun.LOOK.bead,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Ball,
	})

	-- THE FLAT BREECH FACE: the end the chambers open at, which the standing breech closes against.
	add({
		name = "BreechFace",
		group = "barrels",
		size = Vector3.new(BARREL_GAP + BARREL_DIAMETER, BARREL_DIAMETER * 1.05, 0.02),
		offset = CFrame.new(0, BARREL_Y, at.breechZ - 0.004),
		color = Gun.LOOK.blued,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	-- THE HINGE HOOK: the lug under the breech end of the tubes that drops onto the pin. It is what
	-- a player sees rotate when the gun opens, so it belongs to the barrel group.
	add({
		name = "HingeHook",
		group = "barrels",
		size = Vector3.new(ACTION_WIDTH * 0.7, 0.10, 0.12),
		offset = CFrame.new(0, BARREL_Y - at.barrelRadius - 0.04, at.breechZ - 0.06),
		color = Gun.LOOK.blued,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	-- ---------------- the body: the action and everything bolted to it
	add({
		name = "Action",
		group = "body",
		size = Vector3.new(ACTION_WIDTH, ACTION_HEIGHT, ACTION_LENGTH),
		offset = CFrame.new(0, at.actionY, at.actionZ),
		color = Gun.LOOK.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
		reflectance = 0.04,
	})

	-- THE STANDING BREECH: the upright face the two chambers close against. Taller than the action
	-- body, because it has to cover both bores.
	add({
		name = "StandingBreech",
		group = "body",
		size = Vector3.new(ACTION_WIDTH, ACTION_HEIGHT + BARREL_DIAMETER, STANDING_BREECH_THICK),
		offset = CFrame.new(0, at.actionY + BARREL_DIAMETER / 2, at.breechFaceZ),
		color = Gun.LOOK.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
		reflectance = 0.04,
	})

	-- THE FLAT BARS: they run FORWARD from the action under the barrels, which is the shape that
	-- says "side-by-side" at a glance and what the forend wood is screwed to.
	add({
		name = "FlatBars",
		group = "body",
		size = Vector3.new(ACTION_WIDTH * 0.92, 0.035, FLAT_BAR_LENGTH),
		offset = CFrame.new(0, ACTION_TOP - 0.0175, at.breechZ - FLAT_BAR_LENGTH / 2),
		color = Gun.LOOK.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	-- THE HINGE PIN, centred EXACTLY on the axis the barrels turn about -- `Gun.hinge`, not a second
	-- number. A spec asserts those two are the same point, because a pin that is not on the axis is
	-- a pin the barrels visibly swing around rather than on.
	add({
		name = "HingePin",
		group = "body",
		size = Vector3.new(ACTION_WIDTH * 1.02, HINGE_PIN_DIAMETER, HINGE_PIN_DIAMETER),
		offset = CFrame.new(Gun.hinge(config)) * ACROSS,
		color = Gun.LOOK.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		reflectance = 0.05,
	})

	add({
		name = "TopLever",
		group = "body",
		size = Vector3.new(0.05, 0.022, TOP_LEVER_LENGTH),
		offset = CFrame.new(0, ACTION_TOP + 0.011, at.breechFaceZ + TOP_LEVER_LENGTH / 2),
		color = Gun.LOOK.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
		reflectance = 0.05,
	})

	add({
		name = "Safety",
		group = "body",
		size = Vector3.new(0.034, 0.016, 0.055),
		offset = CFrame.new(0, ACTION_TOP + 0.008, at.breechFaceZ + TOP_LEVER_LENGTH + 0.05),
		color = Gun.LOOK.blued,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	-- THE TRIGGER GUARD, as a ROUND bow: two uprights and a curved bar is three parts and reads as a
	-- rectangle; one flat cylinder lying across the gun's plane reads as the bow it is.
	add({
		name = "TriggerGuard",
		group = "body",
		size = Vector3.new(0.018, TRIGGER_GUARD_RADIUS * 2, TRIGGER_GUARD_RADIUS * 2),
		offset = CFrame.new(0, at.actionBottom - TRIGGER_GUARD_RADIUS * 0.55, at.triggerZ) * ACROSS,
		color = Gun.LOOK.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		reflectance = 0.04,
	})
	-- ...and the strap that joins the bow to the action, so it hangs from something.
	add({
		name = "GuardStrap",
		group = "body",
		size = Vector3.new(0.05, 0.03, 0.20),
		offset = CFrame.new(0, at.actionBottom - 0.012, at.triggerZ + 0.06),
		color = Gun.LOOK.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
	})

	-- ONE trigger: the 486 has a single trigger and the brief says so.
	add({
		name = "Trigger",
		group = "body",
		size = Vector3.new(0.022, 0.065, 0.022),
		offset = CFrame.new(0, at.actionBottom - 0.038, at.triggerZ) * CFrame.Angles(math.rad(14), 0, 0),
		color = Gun.LOOK.action,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Block,
		reflectance = 0.05,
	})

	-- ---------------- the wood. These two are REPLACED BY KAREN'S MESHES when they are published
	-- (`Gun.WOOD_KEYS`); the size and the place are the same either way, so the silhouette does not
	-- depend on whether an upload loaded.
	add({
		name = Gun.FOREND_NAME,
		group = "barrels", -- bolted to the barrels: it swings with them, and the left hand holds it
		size = FOREND_SIZE,
		offset = CFrame.new(
			0,
			BARREL_Y - at.barrelRadius - FOREND_SIZE.Y / 2 + 0.02,
			at.breechZ - 0.30 - FOREND_SIZE.Z / 2
		),
		color = Gun.LOOK.wood,
		material = Enum.Material.Wood,
		shape = Enum.PartType.Block,
	})

	add({
		name = Gun.STOCK_NAME,
		group = "body",
		size = STOCK_SIZE,
		offset = CFrame.new(0, at.actionY + 0.01, at.stockZ) * CFrame.Angles(math.rad(STOCK_DROP_DEG), 0, 0),
		color = Gun.LOOK.wood,
		material = Enum.Material.Wood,
		shape = Enum.PartType.Block,
	})

	return pieces
end

-- How many parts the drawn gun costs, counting the two envelopes the viewmodel adds (the Handle and
-- the barrel group's own). ASSERTED by `tests/server/gun.spec.luau`, so growth is a decision rather
-- than a drift (the note's section 4 budget).
function Gun.partCount(config): number
	return #Gun.pieces(config) + 2
end

return Gun
