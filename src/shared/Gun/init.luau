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
	-- WHERE A MESH GOES INSTEAD, when this piece is one Karen uploaded (`Gun.WOOD_KEYS`). It exists
	-- because a drawn part's offset may carry a SHAPE rotation that is not the mesh's: a Cylinder's
	-- length runs along its own X, so the forend part is turned a quarter turn to lie along the gun,
	-- and composing `Gun.WOOD_ROTATION_DEG` on top of that would cancel the turn the MESH needs.
	-- nil means the two are the same, which is true of every piece whose shape is a Block.
	woodOffset: CFrame?,
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
local BARREL_Y = 0.12 -- the bore line. The action's top is the WATER TABLE, half a tube below it
local RIB_WIDTH = 0.072
local RIB_THICK = 0.022
-- THE BORE, FAKED, SAID TO BE FAKED, AND ON THE OUTSIDE OF THE TUBE (round 2, finding 1). A Cylinder
-- is solid, so the opening is a near-black disc -- four in all, one at each end of each tube. Rounds
-- 1 and 2 both put the disc INSIDE the end face, and the Reviewer measured what that costs: a Roblox
-- Part is an opaque closed solid, so a smaller part wholly contained in a larger one is never drawn.
-- Four invisible parts, two flat blued end caps where the openings should be, and the seated shell
-- hidden with them.
--
-- SO THE DISC STANDS PROUD OF THE FACE, which is how a real gun reads anyway -- the muzzle of a
-- barrel is the darkest thing on it, with a thin bright ring of steel around that dark. The disc is
-- `BORE_FRACTION` of the tube, so that ring is what shows around it: a wall, then the hole. It is
-- still not a hole. `gun.spec` asserts BY SIGN that each disc's outer face is outside its tube's end
-- face -- a magnitude cannot say it, since 0.002 in and 0.002 out are the same distance and only one
-- of them can be seen -- and that nothing in the barrel group, THE TUBE INCLUDED, stands in front of
-- one.
local BORE_PROUD = 0.002 -- how far the disc's outer face stands out of the end face
-- ...and how far it reaches back INTO the tube. It is there so that no two drawn faces are coplanar:
-- the disc's inner face is buried in the tube rather than sharing a plane with its end cap.
local BORE_BITE = 0.001
local BORE_THICK = BORE_PROUD + BORE_BITE
local BORE_FRACTION = 0.72 -- of the tube's diameter: a wall, then the hole

-- THE ACTION'S PROPORTIONS, AND THEY WERE MEASURED OFF THE BERETTA SIDE PHOTO rather than guessed
-- (task 100). `references/Beretta Parrelo Shutgun/Social_1_1-2500 (5).jpeg`, segmented by colour --
-- blued tubes, walnut forend, silver action, walnut stock -- gives, in pixels of a 2,348 px gun:
--   muzzle 85, forend front 1008, action front 1412, action/stock joint 1572, butt 2432;
--   barrel pair 40 px deep; action top strap to belly 101 px.
-- So the three ratios that matter, against the BARRELS:
--   action length / barrel length   0.121   (ours was 0.226 -- 1.9x too long)
--   action+breech height / barrels  2.53 D  (ours was 1.90 D -- it was never too TALL)
--   action body width / barrel pair --      (ours was 1.01: the action was as wide as the tubes)
-- What made it read as a slab was the LENGTH and the fact that its top face sat on the BORE LINE,
-- so the body stood up between the two tubes. It now stops at the WATER TABLE, which is where a
-- real gun's barrels lie, and the standing breech is what rises behind them.
local ACTION_LENGTH = 0.36 -- 0.131 of the barrels, against the photo's 0.121
local ACTION_WIDTH = 0.255 -- 0.86 of the barrel pair's outer width: the tubes overhang the body
-- THE BARRELS LIE **ON** THE WATER TABLE, which is their own underside -- not half sunk into the
-- action, which is what `ACTION_TOP = BARREL_Y` (the bore CENTRE) actually drew.
local WATER_TABLE_Y = BARREL_Y - BARREL_DIAMETER / 2
-- ...AND THE BELLY DOES NOT MOVE. `Gun.hinge` is measured up from it, and the dispatch forbids
-- moving the hinge axis, so the action gets shallower from the TOP and this number is the one that
-- is held fixed. It is what `ACTION_TOP - ACTION_HEIGHT` was before: 0.12 - 0.26.
local ACTION_BOTTOM = -0.14
local ACTION_HEIGHT = WATER_TABLE_Y - ACTION_BOTTOM
local ACTION_TOP = WATER_TABLE_Y
-- THE TOP STRAP / TANG: the strip that runs back from the breech over the grip, carrying the top
-- lever and the safety. It sits just ABOVE the bore line and well under the rib, so it is a line
-- along the gun rather than a block in the sight picture.
local TANG_Y = BARREL_Y + 0.01
local TANG_LENGTH = 0.25
local TANG_THICK = 0.022
local STANDING_BREECH_THICK = 0.055 -- the upright face the two chambers close against
-- ...and it stops at the tang, a hair above the bore line. See the piece for the screenshot that
-- bought this number: taller than this and it hides the barrels in the aimed view.
local STANDING_BREECH_HEIGHT = TANG_Y - ACTION_BOTTOM
-- THE FENCES: the two ROUND walls that wrap the chamber ends, and the one shape that stops the
-- breech reading as a sawn-off box. They sit INSIDE the standing breech's own thickness, behind the
-- tubes, so they hide nothing the standing breech was not already hiding.
local FENCE_CLEARANCE = 0.014 -- how far a fence stands proud of the tube it wraps
local FLAT_BAR_LENGTH = 0.30 -- the bars that run FORWARD under the barrels, into the forend
local HINGE_PIN_DIAMETER = 0.07

-- THE SEATED SHELL'S BRASS RIM, which is the whole of "this chamber is loaded" (round 2, finding 1).
-- On a real gun the rim sits ON the breech face with the body down the chamber out of sight, so the
-- rim is the ONE part of a shell that may not be inside the tube: brass at the mouth loaded, the
-- dark bore disc empty, and those two pictures are what the break-open frame exists to show.
Gun.SHELL_RIM_THICK = 0.003
-- A HAIR WIDER THAN THE BORE, so it COVERS the dark disc instead of sitting in it.
Gun.SHELL_RIM_DIAMETER = BARREL_DIAMETER * BORE_FRACTION + 0.006
-- ...and it must stand in FRONT of that disc, which is itself `BORE_PROUD` out of the face. Two
-- discs ending on the same plane z-fight, so the rim clears it rather than meeting it.
Gun.SHELL_RIM_PROUD = BORE_PROUD + 0.003

local TRIGGER_GUARD_RADIUS = 0.085
local TOP_LEVER_LENGTH = 0.17

-- THE WOOD'S ENVELOPES. The two wooden pieces are Karen's Meshy models when they are loaded
-- (`Gun.WOOD_KEYS`); these sizes are what the MeshPart is scaled to, and what the fallback part is
-- when no mesh arrived -- so the gun has a forend and a stock either way and the silhouette is the
-- same. A gun with no wood is a real state (the load failed), not a reason to draw nothing.
-- A SPLINTER FOREND, IN TWO ROUND LENGTHS (task 100). The photo's forend runs 1008..1410 px of a
-- 1,327 px barrel -- 0.30 of it -- and TAPERS: about 1.0 barrel-diameters deep at the rear and 0.4
-- at the front. One box could be neither round nor tapered, so the wood is the thicker rear length
-- plus `ForendTip`, a thinner one ahead of it, both CYLINDERS: no box edge anywhere on it.
-- `FOREND_SIZE` is still the envelope Karen's forend mesh would be scaled into if one is ever
-- uploaded (there is none today -- TASKS.md 99a(a)), and `buildNewGun` drops the tip when it is.
local FOREND_SIZE = Vector3.new(0.185, 0.15, 0.60)
local FOREND_TIP_SIZE = Vector3.new(0.125, 0.105, 0.24)
local STOCK_SIZE = Vector3.new(0.235, 0.30, 1.32)
local STOCK_DROP_DEG = 8 -- 2.25 in of drop over a 14.5 in pull
-- WHERE THE COMB IS, and it is measured from the BORE LINE rather than from the action's centre
-- (task 100). It is the same 0.095 the action-relative expression gave before this task, so the
-- stock did not move -- but the action got shallower, and a comb that follows the action's centre
-- would have dropped out of the aimed view with it. The comb is a fact about where a cheek goes.
local STOCK_COMB_Y = BARREL_Y - 0.025

-- THE NAMES THE VIEWMODEL LOOKS FOR, so neither side carries a literal the other could disagree
-- with (the reason `HandAssets` and `Assets.KEYS` exist).
Gun.BODY_NAME = "GunBody"
Gun.BARRELS_NAME = "Barrels" -- the SAME name the old mesh gun's barrel piece has, so
-- `Camera.Viewmodel.hinge` and the left hand's parent rule are one rule for both guns.
Gun.FOREND_NAME = "Forend"
-- The taper ahead of the forend. It is NOT a wood key: it exists only while there is no forend mesh
-- (TASKS.md 99a(a)), and `Camera.Viewmodel` drops it the day one is published.
Gun.FOREND_TIP_NAME = "ForendTip"
Gun.STOCK_NAME = "Stock"
Gun.WOOD_KEYS = table.freeze({ [Gun.FOREND_NAME] = "gun.forend", [Gun.STOCK_NAME] = "gun.stock" })
-- WHERE THE SERVER PARKS THE WOOD for the client to clone, the same arrangement the hands have
-- (`HandAssets.FOLDER_NAME`): `InsertService:LoadAsset` is server-only, so the server loads and
-- publishes and `Camera.Viewmodel` clones. Created at RUN TIME, never on disk -- ReplicatedStorage
-- is Rojo-owned and a folder parked there in Edit would be deleted at the next Connect.
Gun.FOLDER_NAME = "ViewmodelGun"
-- HOW LONG EACH WOODEN PIECE IS ON THIS GUN. The uploaded mesh is scaled UNIFORMLY so its long axis
-- is this, and its other two sizes are whatever the wood's own proportions give (design 6.1's rule,
-- and the reason the squashed boar is in it). `ServerStorage.Assets` reads these to work out each
-- row's `sizeStuds`, so the gun's geometry decides the scale rather than a number in the manifest.
-- HOW WIDE A WOODEN PIECE IS ON THIS GUN, where its own proportions are not the answer (task 102).
-- MEASURED: Karen's stock mesh is 190.153 x 69.262 x 17.743 in its own units, so scaled uniformly to
-- 1.32 studs long it is 0.481 tall and **0.123 wide** -- and a real stock IS about that narrow
-- relative to its length (a 486's butt is about 1.6 in across a 45 in gun). The trouble is that the
-- METAL of this gun is not at life size: `BARREL_DIAMETER` is 0.145 where life size at this length
-- would be about 0.089, because a life-size pair is unreadable at arm's length in first person. So
-- the gun is drawn at about 1.65x in cross-section and the stock arrived at 1.0x -- which is why the
-- aimed capture showed a comb spanning ~15% of the half-frame's width against the video target's
-- ~50%. It is widened to the ACTION's width, which is the Director's rule for a side-by-side's
-- stock: as wide as the action at the head. 0.255 / 0.1231 = 2.07x, on that one axis only.
Gun.WOOD_WIDTH_STUDS = table.freeze({ [Gun.STOCK_NAME] = ACTION_WIDTH })

-- The forend's length is the SPLINTER'S WHOLE length -- the body plus the tapered tip -- because a
-- mesh forend replaces both (`Gun.FOREND_TIP_NAME`).
Gun.WOOD_LENGTH_STUDS = table.freeze({
	[Gun.FOREND_NAME] = FOREND_SIZE.Z + FOREND_TIP_SIZE.Z,
	[Gun.STOCK_NAME] = STOCK_SIZE.Z,
})
-- HOW THE MESH IS TURNED to lie on this gun. Both models arrive with their LONG AXIS ALONG X
-- (measured by `tools/asset_prep.py`: "long axis X, front at its minimum"), and this gun's long axis
-- is Z with -Z the muzzle -- so a quarter turn about Y lays it down. MINUS ninety, not plus: that
-- takes the mesh's +X to the gun's +Z, which puts the model's own FRONT -- its minimum X, the flat
-- face the action fits against -- toward the action. Plus ninety would seat the butt in the breech.
Gun.WOOD_ROTATION_DEG = table.freeze({ [Gun.FOREND_NAME] = -90, [Gun.STOCK_NAME] = -90 })

-- `Enum.Material.Metal` IS THE REASON THE GUN WAS BLUE, AND IT IS MEASURED (task 100, rule 5).
-- Roblox's `Metal` is a conductor: its specular response is the ENVIRONMENT multiplied by the
-- albedo, and over an open field the environment is the sky. In `20261001T215631Z-compare-carry.png`
-- the tube pixels came back with a median of (10, 26, 57) and a 90th percentile of (48, 79, 112) --
-- blue three times red -- while the same frame's video target reads (56, 53, 48), (69, 64, 62):
-- NEUTRAL near-black. Lowering the albedo could not fix it, because what is blue is the reflection
-- and not the paint.
--
-- SO THE STEEL IS A DIELECTRIC. `SmoothPlastic` keeps a narrow white specular lobe -- which on a
-- Cylinder is exactly the thin highlight that runs along the top of a blued barrel -- and does not
-- mirror the sky across the whole tube. It is the material, not the colour, that was the defect.
local STEEL_MATERIAL = Enum.Material.SmoothPlastic

-- The colours. Blued steel is near-black with the faintest cool cast; the action is a case-hardened
-- silver-grey, which is the contrast that makes a side-by-side read as one.
Gun.LOOK = table.freeze({
	-- NEUTRAL, NOT BLUE (task 100). The old (34, 38, 46) was a blue-biased albedo under a material
	-- that multiplied the sky by it. The target frame's barrels are a flat dark grey, so this is
	-- one: a 4-point cool cast, no more.
	blued = Color3.fromRGB(26, 27, 30),
	-- 118, NOT 140 OR 176, AND THE SCREENSHOT IS WHY (rule 5). At 176 the action rendered near-WHITE;
	-- at 140 with `Metal` and 0.04 reflectance it still measured (139, 148, 165) in the break-open
	-- capture -- a pale blue-grey slab, which is what the Director called "a Roblox block". With the
	-- sky reflection gone (`STEEL_MATERIAL`) this stays a mid grey in sun, which is what
	-- case-hardened steel is.
	action = Color3.fromRGB(118, 120, 122),
	bore = Color3.fromRGB(9, 9, 11),
	bead = Color3.fromRGB(198, 158, 82),
	-- WALNUT, matched to Karen's own stock mesh rather than guessed: the stock's lit pixels in
	-- `20261002T012118Z-pose-reload.png` measure (144, 79, 49) and (153, 96, 66), so the forend
	-- beside it -- which has no mesh and never will until one is uploaded -- is the same wood.
	wood = Color3.fromRGB(104, 64, 38),
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
		actionBottom = ACTION_BOTTOM,
		actionTop = ACTION_TOP,
		tangY = TANG_Y,
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

-- WHERE A SEATED SHELL'S RIM GOES: the chamber MOUTH -- on that tube's own bore line, a hair proud
-- of its breech face (round 2, finding 1). It is the mouth and not a point down the chamber because
-- a shell seated INSIDE an opaque tube is a shell nobody can see, which is what rounds 1 and 2 both
-- drew. The body follows it into the tube and is unseen, exactly as on a real gun.
--
-- `Gun.barrelOffset` is the one definition of this gun's bore line, so this module still does not
-- learn that the right barrel is +X; and `Gun.shellLayout` is the one definition of how far behind
-- its rim a shell's pivot sits, so the caller that PLACES the shell and the builder that DRAWS it
-- cannot disagree about where the rim ended up.
function Gun.chamber(barrel: number, config): CFrame
	local at = Gun.layout(config)
	local across = Gun.barrelOffset(barrel, config)
	return CFrame.new(across.X, across.Y, at.breechZ + Gun.SHELL_RIM_PROUD)
end

-- ONE SHELL'S OWN LAYOUT along its length, in the shell's local frame: the red body, the brass base
-- behind it, and the brass rim behind that. Pure arithmetic over the two numbers the CAMERA owns
-- (`Camera.Config.SHELL_SIZE_STUDS` and `SHELL_BASE_FRACTION`), passed in rather than read, because
-- a shared module cannot require a client one.
--
-- X IS THE SHELL'S LENGTH, with the MOUTH forward at +X: `Camera.Viewmodel.makeShell` builds the
-- parts as cylinders (whose length is their own X) and turns the finished model a quarter turn, which
-- takes -X to the gun's +Z -- the breech. `back` is the one number that seats it: how far BEHIND the
-- model's pivot (its Body part, which is what `PivotTo` places) the rim's outer face is.
function Gun.shellLayout(sizeStuds: Vector3, baseFraction: number)
	local baseLength = sizeStuds.Z * baseFraction
	local bodyLength = sizeStuds.Z - baseLength
	return table.freeze({
		bodyLength = bodyLength,
		baseLength = baseLength,
		diameter = sizeStuds.X,
		rimThick = Gun.SHELL_RIM_THICK,
		rimDiameter = Gun.SHELL_RIM_DIAMETER,
		-- Offsets from the SHELL'S centre, which is the frame the three parts are built in.
		bodyX = baseLength / 2,
		baseX = -bodyLength / 2,
		rimX = -(sizeStuds.Z / 2 + Gun.SHELL_RIM_THICK / 2),
		-- ...and from the PIVOT, which is the Body: half the shell, plus the half base the body is
		-- offset forward by, plus the rim itself.
		back = sizeStuds.Z / 2 + baseLength / 2 + Gun.SHELL_RIM_THICK,
	})
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

-- WHERE THIS GUN'S OWN BORE LINE IS, per barrel, in the Handle's frame -- and it is the ONE
-- definition of it (round 1, finding 2). `Shotgun.barrelMuzzleOffset` answers the same question for
-- the MESH gun, whose tubes are `BARREL_HALF_GAP_STUDS` = 0.09 apart and ride
-- `BARREL_RISE_STUDS` = 0.12 above the Handle's axis; this gun's tubes are `BARREL_GAP / 2` = 0.076
-- apart and ride `BARREL_Y`. The SIGN still comes from `Shotgun`, so "which tube is barrel 1" has
-- one owner in the whole repo and this module does not learn that the right barrel is +X.
function Gun.barrelOffset(barrel: number?, config): Vector3
	local sign = if Shotgun.barrelMuzzleOffset(barrel, config or Shotgun.CONFIG).X >= 0 then 1 else -1
	return Vector3.new(sign * BARREL_GAP / 2, BARREL_Y, 0)
end

-- THE `Muzzle` ATTACHMENT, ON THE HANDLE'S AXIS, exactly where `Weapon.Hardware` puts it on every
-- other gun (`CFrame.new(config.MUZZLE_OFFSET)`). It is NOT on the bore line, and that is the whole
-- of round 1's finding 2: `Camera.Viewmodel.muzzle` adds the barrel's own rise to whatever this
-- attachment says, so a bore-line attachment counted the rise twice and drew the first-person flash
-- 0.12 studs above the barrels -- off the top of the rib rather than out of a tube.
function Gun.muzzle(config): CFrame
	local at = Gun.layout(config)
	return CFrame.new(0, 0, at.muzzleZ)
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
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Cylinder,
			-- NO REFLECTANCE AT ALL, and the screenshot is why (rule 5). Task 72 shipped "blued
			-- barrels" that were mirror chrome; 0.06 was meant to be a highlight and instead the
			-- tubes mirrored the sky and read as bright BLUE plastic in the carry capture. Roblox's
			-- `Metal` already carries a specular response, and a blued barrel is a dark matte-ish
			-- surface with a sheen along its length, not a mirror.
			reflectance = 0,
		})
		-- THE TWO OPENINGS AT EACH END (requirement 2 of the note), each one PROUD of the end face it
		-- belongs to -- see `BORE_PROUD`: a disc inside a solid Cylinder is drawn nowhere. The breech
		-- pair is what the player sees with the gun broken open, which is the frame this task exists
		-- to fix; the muzzle pair is what he looks at down the rib.
		--
		-- EACH SPANS [face - BORE_PROUD, face + BORE_BITE] in the direction of its own opening, so the
		-- sign is the only difference between the two ends.
		for _, end_ in ipairs({
			{ suffix = "Muzzle", z = at.muzzleZ - BORE_PROUD + BORE_THICK / 2 },
			{ suffix = "Breech", z = at.breechZ + BORE_PROUD - BORE_THICK / 2 },
		}) do
			add({
				name = side.name .. "Bore" .. end_.suffix,
				group = "barrels",
				size = Vector3.new(BORE_THICK, BARREL_DIAMETER * BORE_FRACTION, BARREL_DIAMETER * BORE_FRACTION),
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
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Block,
	})

	-- THE BEAD KEEPS `Metal`, and it is the one piece that should. Task 92 measured why it is not
	-- Neon (a bead is brass, not a light), and the reason `Metal` ruined the BARRELS -- it mirrors
	-- the sky -- is the reason it suits a 0.034-stud ball whose whole job is to catch the light and
	-- be seen. A dull bead is a sight you cannot find.
	add({
		name = "Bead",
		group = "barrels",
		size = Vector3.new(0.034, 0.034, 0.034),
		offset = CFrame.new(Gun.beadOffset(config)),
		color = Gun.LOOK.bead,
		material = Enum.Material.Metal,
		shape = Enum.PartType.Ball,
	})

	-- THERE IS NO BREECH PLATE, AND THAT IS THE FIX (round 1, finding 1). A `BreechFace` block the
	-- width of both tubes was added here to be "the flat breech face"; the Reviewer measured what it
	-- actually did -- it spanned z 0.524 to 0.544 across both tube ends, so it BURIED both breech
	-- bore discs (z-fighting their front faces into the bargain) and the fed shells slid straight
	-- through it and out of sight. That is precisely the frame this task exists to fix.
	--
	-- The requirement it was meant to meet is still met, by the tubes themselves: a Cylinder's rear
	-- end IS a flat face and the two are coplanar at `breechZ`. What each one SHOWS is the near-black
	-- disc standing proud of it, or the brass rim of a seated shell standing proud of that (round 2,
	-- finding 1). A real monobloc is two flat-ended tubes side by side, which is what this is.

	-- THE HINGE HOOK: the lug under the breech end of the tubes that drops onto the pin. It is what
	-- a player sees rotate when the gun opens, so it belongs to the barrel group.
	--
	-- IT NOW REACHES THE PIN (TASKS.md 99a(f)). The Reviewer measured a 0.0275-stud air gap between
	-- the hook's underside and the top of the pin it is said to drop onto: a hook hanging above its
	-- own hinge. It runs from the tubes' underside DOWN TO THE AXIS, so the two touch by
	-- construction and `gun.spec` asserts it rather than a number that could drift from the pin's.
	local hookTop = BARREL_Y - at.barrelRadius + 0.01
	local hookBottom = Gun.hinge(config).Y
	add({
		name = "HingeHook",
		group = "barrels",
		size = Vector3.new(ACTION_WIDTH * 0.7, hookTop - hookBottom, 0.12),
		offset = CFrame.new(0, (hookTop + hookBottom) / 2, at.breechZ - 0.06),
		color = Gun.LOOK.blued,
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Block,
	})

	-- ---------------- the body: the action and everything bolted to it
	--
	-- A ROUND-BODIED ACTION, IN TWO PIECES, because the 486 Parallelo's is round-bodied (the review
	-- link in the header says so) and because what the break-open capture showed was "a flat
	-- near-white box with hard corners". The flat top -- the water table, which the barrels lie on --
	-- is a block; the BELLY is a Cylinder of the action's own width lying along the gun, so the
	-- bottom and both lower edges are one curve and there is no corner anywhere below the barrels.
	-- The two meet at the cylinder's own centre line, so the silhouette is continuous.
	-- The belly is an ELLIPTICAL cylinder -- a Roblox Cylinder's two cross-section axes are its own
	-- Y and Z and they need not match -- so it is the action's full width and exactly its full
	-- height, and its upper half is covered by the block to the stud. Nothing bulges above the water
	-- table, which a circular belly of the action's width would have done by 0.067 studs: a round
	-- hump standing up between the two tubes.
	add({
		name = "Action",
		group = "body",
		size = Vector3.new(ACTION_WIDTH, ACTION_HEIGHT / 2, ACTION_LENGTH),
		offset = CFrame.new(0, (ACTION_TOP + at.actionY) / 2, at.actionZ),
		color = Gun.LOOK.action,
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Block,
	})

	add({
		name = "ActionBelly",
		group = "body",
		size = Vector3.new(ACTION_LENGTH, ACTION_HEIGHT, ACTION_WIDTH),
		offset = CFrame.new(0, at.actionY, at.actionZ) * LYING,
		color = Gun.LOOK.action,
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Cylinder,
	})

	-- THE STANDING BREECH: the upright face the two chambers close against. It reaches from the
	-- action's bottom up to the TANG, a hair above the bore line, and no further -- MEASURED ON
	-- SCREEN (rule 5): the first build made it `ACTION_HEIGHT + BARREL_DIAMETER` tall and centred it
	-- half a barrel above the action, which put its top 0.11 studs ABOVE the rib. In the aimed view
	-- that is a pale box filling the middle of the screen with the barrels hidden behind it -- a gun
	-- you cannot aim. It is also NARROWER than the barrel pair, so from the shooter's eye the tubes
	-- overhang it and nothing square shows beside them.
	add({
		name = "StandingBreech",
		group = "body",
		size = Vector3.new(ACTION_WIDTH, STANDING_BREECH_HEIGHT, STANDING_BREECH_THICK),
		offset = CFrame.new(0, at.actionBottom + STANDING_BREECH_HEIGHT / 2, at.breechFaceZ),
		color = Gun.LOOK.action,
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Block,
	})

	-- THE FENCES: the two round walls that wrap the chamber ends. They are what a side-by-side has
	-- instead of a square breech, and they are Cylinders along the gun's own axis, one per tube,
	-- sitting INSIDE the standing breech's thickness. So they add a curve around each chamber and
	-- hide nothing: with the gun shut the standing breech is already behind the bore discs, and with
	-- it broken open the barrels -- and the discs and any seated shell with them -- have swung away.
	for _, side in ipairs({ { name = "FenceLeft", x = -BARREL_GAP / 2 }, { name = "FenceRight", x = BARREL_GAP / 2 } }) do
		local fenceDiameter = BARREL_DIAMETER + FENCE_CLEARANCE * 2
		add({
			name = side.name,
			group = "body",
			-- A HAIR SHORTER THAN THE BREECH IT SITS IN, so neither end face is coplanar with the
			-- standing breech's -- the same reason `BORE_BITE` exists. Two coplanar drawn faces
			-- z-fight, and the fence shows above and beside the breech where it would be seen.
			size = Vector3.new(STANDING_BREECH_THICK - 0.004, fenceDiameter, fenceDiameter),
			offset = CFrame.new(side.x, BARREL_Y, at.breechFaceZ) * LYING,
			color = Gun.LOOK.action,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Cylinder,
		})
	end

	-- THE TOP STRAP: the tang that runs back from the breech over the grip and carries the top lever
	-- and the safety. In the photo it is a third of the action's whole length again, and it is what
	-- the shooter actually looks across on the way to the rib -- so it is a slim strip well below the
	-- rib rather than another face of the action block.
	add({
		name = "TopStrap",
		group = "body",
		size = Vector3.new(ACTION_WIDTH * 0.72, TANG_THICK, TANG_LENGTH),
		offset = CFrame.new(0, TANG_Y - TANG_THICK / 2, at.breechFaceZ + STANDING_BREECH_THICK / 2 + TANG_LENGTH / 2),
		color = Gun.LOOK.action,
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Block,
	})

	-- THE FLAT BARS: they run FORWARD from the action under the barrels, which is the shape that
	-- says "side-by-side" at a glance and what the forend wood is screwed to.
	--
	-- BELOW THE BORE, NOT INSIDE IT (TASKS.md 99a(f)). While the action's top was the bore LINE these
	-- sat at y 0.1025..0.1375 -- wholly inside two tubes that span 0.0475..0.1925 -- so they were an
	-- invisible part. They now hang under the water table, where a real gun's flats are, and they are
	-- the action's own width so the forend has something to sit on.
	add({
		name = "FlatBars",
		group = "body",
		size = Vector3.new(ACTION_WIDTH, 0.035, FLAT_BAR_LENGTH),
		offset = CFrame.new(0, ACTION_TOP - 0.0175, at.breechZ - FLAT_BAR_LENGTH / 2),
		color = Gun.LOOK.action,
		material = STEEL_MATERIAL,
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
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Cylinder,
	})

	-- ON THE TOP STRAP, which is where a player looks for them: the lever first, thumbed to the side
	-- to open the gun, then the safety behind it. Both lie ON the tang, so their tops are
	-- `TANG_Y + their own thickness`: 0.148 for the lever, which is 0.0445 clear of the rib's
	-- underside at 0.1925 -- and the aimed view may have nothing square inside that.
	add({
		name = "TopLever",
		group = "body",
		size = Vector3.new(0.05, 0.018, TOP_LEVER_LENGTH),
		offset = CFrame.new(0, TANG_Y + 0.009, at.breechFaceZ + STANDING_BREECH_THICK / 2 + TOP_LEVER_LENGTH / 2),
		color = Gun.LOOK.action,
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Block,
	})

	add({
		name = "Safety",
		group = "body",
		size = Vector3.new(0.034, 0.014, 0.055),
		offset = CFrame.new(0, TANG_Y + 0.007, at.breechFaceZ + STANDING_BREECH_THICK / 2 + TOP_LEVER_LENGTH + 0.04),
		color = Gun.LOOK.blued,
		material = STEEL_MATERIAL,
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
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Cylinder,
	})
	-- ...and the strap that joins the bow to the action, so it hangs from something.
	add({
		name = "GuardStrap",
		group = "body",
		size = Vector3.new(0.05, 0.03, 0.20),
		offset = CFrame.new(0, at.actionBottom - 0.012, at.triggerZ + 0.06),
		color = Gun.LOOK.action,
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Block,
	})

	-- ONE trigger: the 486 has a single trigger and the brief says so.
	add({
		name = "Trigger",
		group = "body",
		size = Vector3.new(0.022, 0.065, 0.022),
		offset = CFrame.new(0, at.actionBottom - 0.038, at.triggerZ) * CFrame.Angles(math.rad(14), 0, 0),
		color = Gun.LOOK.action,
		material = STEEL_MATERIAL,
		shape = Enum.PartType.Block,
	})

	-- ---------------- the wood. These two are REPLACED BY KAREN'S MESHES when they are published
	-- (`Gun.WOOD_KEYS`); the size and the place are the same either way, so the silhouette does not
	-- depend on whether an upload loaded.
	-- A SPLINTER, UNDER THE TUBES, IN TWO ROUND LENGTHS (task 100). The forend hangs from the flat
	-- bars, so its rear is where they end; its top touches the tubes' underside, which is the water
	-- table line, so no wood stands up beside the barrels.
	local forendRearZ = at.breechZ - FLAT_BAR_LENGTH
	local forendY = WATER_TABLE_Y - FOREND_SIZE.Y / 2
	add({
		name = Gun.FOREND_NAME,
		group = "barrels", -- bolted to the barrels: it swings with them, and the left hand holds it
		size = Vector3.new(FOREND_SIZE.Z, FOREND_SIZE.Y, FOREND_SIZE.X),
		offset = CFrame.new(0, forendY, forendRearZ - FOREND_SIZE.Z / 2) * LYING,
		-- A MESH IS NOT A CYLINDER: it keeps the position and loses the quarter turn. Centred on the
		-- whole splinter, tip included, because a mesh replaces that too.
		woodOffset = CFrame.new(0, forendY, forendRearZ - Gun.WOOD_LENGTH_STUDS[Gun.FOREND_NAME] / 2),
		color = Gun.LOOK.wood,
		material = Enum.Material.Wood,
		shape = Enum.PartType.Cylinder,
	})

	-- ...AND ITS TAPER. The photo's forend is about 1.0 barrel-diameters deep at the rear and 0.4 at
	-- the front, so the front third is its own thinner length rather than the same box carried on.
	-- `buildNewGun` DROPS THIS PIECE if a forend mesh is ever published, because the mesh is then the
	-- whole shape (TASKS.md 99a(a): there is no forend mesh today and `A-barrels.glb` cannot give one).
	add({
		name = Gun.FOREND_TIP_NAME,
		group = "barrels",
		size = Vector3.new(FOREND_TIP_SIZE.Z, FOREND_TIP_SIZE.Y, FOREND_TIP_SIZE.X),
		offset = CFrame.new(
			0,
			WATER_TABLE_Y - FOREND_TIP_SIZE.Y / 2,
			forendRearZ - FOREND_SIZE.Z - FOREND_TIP_SIZE.Z / 2
		) * LYING,
		color = Gun.LOOK.wood,
		material = Enum.Material.Wood,
		shape = Enum.PartType.Cylinder,
	})

	add({
		name = Gun.STOCK_NAME,
		group = "body",
		size = STOCK_SIZE,
		-- THE COMB IS MEASURED FROM THE BORE LINE, not from the action (task 100): a cheek goes where
		-- the eye has to end up, which is a fact about the barrels. It is the same 0.095 that
		-- `at.actionY - 0.045` gave before this task -- measured on screen with the stock mesh in,
		-- where the action's own centre put the comb ABOVE the bore line and filled the bottom half
		-- of the aimed view -- so the stock has not moved; it is simply no longer tied to a number
		-- this task changed.
		offset = CFrame.new(0, STOCK_COMB_Y - STOCK_SIZE.Y / 2, at.stockZ)
			* CFrame.Angles(math.rad(STOCK_DROP_DEG), 0, 0),
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
