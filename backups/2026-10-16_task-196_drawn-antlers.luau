-- ONE TAPERED LENGTH OF ANTLER, laid from `from` along `dir` in the MOUNT'S OWN FRAME, and it
-- answers where it ended so the next one starts there. A Part cannot taper, so a beam is a chain of
-- cylinders that each lose a fifth of the last one's thickness -- which is what makes a row of these
-- read as antlers at ten studs instead of as a bundle of sticks.
--
-- A cylinder's own length is its X, so the frame is turned a quarter turn after it is aimed: the
-- same correction `post`, `Horn.pieces` and `Markers.ring` all make.
local function antlerPiece(
	folder: Instance,
	name: string,
	face: CFrame,
	from: Vector3,
	dir: Vector3,
	length: number,
	thick: number,
	colour: Color3
): Vector3
	local unit = dir.Unit
	local mid = from + unit * (length / 2)
	local piece = part(
		name,
		Vector3.new(length, thick, thick),
		face * CFrame.lookAt(mid, mid + unit, Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.pi / 2, 0),
		colour,
		Enum.Material.SmoothPlastic,
		false,
		folder
	)
	piece.Shape = Enum.PartType.Cylinder
	return from + unit * length
end

-- ONE BEAM AND ITS TINES. The beam leaves the skull leaning outward and straightens as it rises,
-- which is the shape of a roe buck's; the tines come off the joints, forward and up.
local function antlerBeam(folder: Instance, name: string, face: CFrame, root: Vector3, side: number, spec, bone: Color3)
	local at = root
	local thick = spec.THICK
	local dir = Vector3.new(side * spec.SPREAD, 1, -0.14)
	for index = 1, spec.SEGMENTS do
		at = antlerPiece(folder, string.format("%sB%d", name, index), face, at, dir, spec.SEGMENT_STUDS, thick, bone)
		thick *= 0.82
		dir = Vector3.new(dir.X + side * spec.CURVE, dir.Y, dir.Z - 0.06)
		if index <= spec.TINES then
			antlerPiece(
				folder,
				string.format("%sT%d", name, index),
				face,
				at,
				Vector3.new(side * 0.18, 1, -0.55),
				spec.TINE_STUDS,
				thick * 0.78,
				bone
			)
		end
	end
end

-- THE SHIELD EVERY TROPHY HANGS ON: a Central-European `Trophaeenschild` is a small dark wooden
-- shield, taller than it is wide, with the skull plate screwed to the middle of it -- "plaque length
-- of 22 cm, width of 10 cm, antler length of 10.5 cm" on the measured example in the note, which is
-- the 2.2 : 1 proportion used here and the reason the antlers are about half the plaque's height.
--
-- `face` lies on the WALL with its LookVector pointing INTO the room, so `-Z` is "out from the
-- wall" for everything below.


-- A ROE OR RED-DEER MOUNT: the shield, the skull plate, two beams.
local function antlerMount(folder: Instance, name: string, face: CFrame, spec, cfg)
	local front = shield(folder, name, face, spec.PLAQUE, cfg)
	local bone = cfg.TROPHIES.BONE_COLOR
	part(
		string.format("%sSkull", name),
		Vector3.new(spec.PLAQUE.X * 0.42, spec.PLAQUE.Y * 0.3, spec.PLAQUE.Z * 1.1),
		front * CFrame.new(0, spec.PLAQUE.Y * 0.14, -spec.PLAQUE.Z * 0.55),
		bone,
		Enum.Material.SmoothPlastic,
		false,
		folder
	)
	local root = Vector3.new(0, spec.PLAQUE.Y * 0.26, -spec.PLAQUE.Z * 0.6)
	for _, side in ipairs({ -1, 1 }) do
		antlerBeam(
			folder,
			string.format("%s%s", name, if side < 0 then "W" else "E"),
			front,
			root + Vector3.new(side * spec.PLAQUE.X * 0.1, 0, 0),
			side,
			spec,
			bone
		)
	end
end

-- A BOAR'S TUSK MOUNT: the shield, the lower jaw plate, and the two tusks curling up and out. Karen
-- asked for *"head of boar"* in task 180 and this is the lodge-wall version of it -- the classic
-- `Gewaff` plate, which is what hangs on a European wall between the antlers.
local function boarMount(folder: Instance, name: string, face: CFrame, spec, cfg)
	local front = shield(folder, name, face, spec.PLAQUE, cfg)
	local bone = cfg.TROPHIES.BONE_COLOR
	part(
		string.format("%sJaw", name),
		Vector3.new(spec.PLAQUE.X * 0.55, spec.PLAQUE.Y * 0.26, spec.PLAQUE.Z * 1.4),
		front * CFrame.new(0, 0, -spec.PLAQUE.Z * 0.7),
		Color3.fromRGB(212, 202, 180),
		Enum.Material.SmoothPlastic,
		false,
		folder
	)
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "W" else "E"
		local at = Vector3.new(side * spec.PLAQUE.X * 0.16, -spec.PLAQUE.Y * 0.06, -spec.PLAQUE.Z * 0.8)
		at = antlerPiece(
			folder,
			string.format("%sTusk%sA", name, tag),
			front,
			at,
			Vector3.new(side * 0.5, 1, -0.2),
			spec.TUSK_STUDS,
			spec.THICK,
			bone
		)
		antlerPiece(
			folder,
			string.format("%sTusk%sB", name, tag),
			front,
			at,
			Vector3.new(side * 1, 0.35, -0.15),
			spec.TUSK_STUDS * 0.8,
			spec.THICK * 0.75,
			bone
		)
	end
end



-- the exterior pair, from `lodge()`:
	-- WHAT HANGS OUTSIDE, AND THE TWO PLACES THERE REALLY ARE TO HANG IT (round 3).
	--
	-- THE SOUTH FRONT IS AN EAVES WALL, NOT A GABLE. The ridge runs along x, so the gables are the
	-- WEST and EAST ends -- which is why the chimney goes up the west one. Over the door there is a
	-- band only three studs tall: the lintel's top below, and above it the south slope's own
	-- underside, which a 44-degree roof puts BELOW the wall top at the wall plane. A stag with four
	-- segments of antler was hung at `doorTop + 5.2` and went straight through that slope, facing
	-- into the roof void -- and nothing in the suite could see it, because this folder is not
	-- `Trophies`.
	--
	-- So: a SMALL mount over the door, sized to the band and then MEASURED into it, which is what
	-- Karen asked for in task 177 and what a lodge really carries over its door; and the big stag on
	-- the EAST GABLE, under the barge boards, facing the truck pads every player walks in from --
	-- the one wall on this building that is tall, flat, empty and seen.
	--
	-- `yaw` IS OUTWARD-FACING FOR BOTH, in `shield`'s own convention (its `-Z` is "out from the
	-- wall"): 0 looks south, -pi/2 east.
	local over = Instance.new("Folder")
	over.Name = "Antlers"
	over.Parent = folder
	local pitch = math.atan2(origin.Y + cfg.LODGE.RIDGE_STUDS - wallTop, halfZ)
	local underEave = wallTop - cfg.LODGE.ROOF.THICK / 2 / math.cos(pitch)
	local doorMount = Instance.new("Folder")
	doorMount.Name = "OverTheDoor"
	doorMount.Parent = over
	antlerMount(
		doorMount,
		"DoorStag",
		CFrame.new(origin.X, (doorTop + cfg.LODGE.DOOR.LINTEL_STUDS + underEave) / 2, origin.Z - halfZ - 0.1),
		cfg.TROPHIES.DOOR,
		cfg
	)
	fitBetween(doorMount, doorTop + 0.2, underEave - 0.2)
	local gableMount = Instance.new("Folder")
	gableMount.Name = "EastGable"
	gableMount.Parent = over
	antlerMount(
		gableMount,
		"GableStag",
		CFrame.new(origin.X + halfX + 0.1, wallTop + cfg.LODGE.GABLE_MOUNT_STUDS, origin.Z)
			* CFrame.Angles(0, -math.pi / 2, 0),
		cfg.TROPHIES.GABLE,
		cfg
	)
	fitBetween(gableMount, wallTop + 0.4, origin.Y + cfg.LODGE.RIDGE_STUDS - 1.2)

