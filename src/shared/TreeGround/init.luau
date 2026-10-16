--!strict
-- TreeGround: WHERE A TREE MEETS THE GROUND, as arithmetic and nothing else.
--
-- WHY IT EXISTS. Task 196 part 3e fixed the LOBBY's trees: a birch's root flare is a set of ARCHED
-- CLAWS, so seating the claw TIPS on the ground leaves daylight under every arch, and to the eye
-- that is a floating tree. The rule it settled on is: plant the tree so the TRUNK/ROOT JUNCTION --
-- the height at which the base stops being claws and becomes trunk -- is at or below the LOWEST
-- ground anywhere under the trunk's own footprint, and let the claws bury themselves on the high
-- side.
--
-- Task 199 is the same defect in `Workspace.OurForest` (Karen, 2026-10-16, with a frame of three
-- birches standing on their claws by a forest road: *"look at the trees wtf"*). That forest is
-- STUDIO CONTENT, not built by any script here, so it is re-seated by `tools/forest_ground.py`
-- instead -- and the Director asked for ONE RULE, ideally one function both use (lesson L-031,
-- *"verify the task actually calls the lobby's existing settle function rather than writing a
-- second parallel ground-fit implementation"*). This is that function, in the one place both can
-- reach it:
--
--   * `Lobby.Build` requires it (`ReplicatedStorage.TreeGround`) from `treePlan` and
--     `settleOnGround`;
--   * `tools/forest_ground.py` READS THIS FILE and injects its source into the Luau it sends to
--     Studio, because Karen's Forest Test place is a different place and Rojo does not serve it.
--     The tool therefore cannot drift from the lobby: there is one copy of the arithmetic and the
--     tool carries it rather than restating it.
--
-- EVERYTHING HERE IS PURE AND TAKES PLAIN NUMBERS. No Instance, no service, no raycast: the caller
-- measures the world (that is the part only the world can answer) and hands the measurements in, so
-- `tests/server/tree_ground.spec.luau` can assert which trees move and by how much with no world at
-- all. That split is exactly why part 3d's version could be wrong for rounds at a time -- the
-- arithmetic and the measuring were one lump of code and neither could be checked alone.
--
-- Research note: docs/research/2026-10-17-forest-trees-on-the-ground.md

local TreeGround = {}

-- A PART'S AXIS-ALIGNED REACH, as plain numbers. The caller projects the part's own rotated size
-- (`Build.worldBoxOf` does it with the CFrame components) and hands the result in.
export type Box = {
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

-- ONE GROUND READING UNDER ONE CONTACT POINT: how high the ground is there, and how low the thing
-- standing on it reaches at that point. `Lobby.Build`'s settler already speaks in exactly this pair.
export type Contact = { ground: number, bottom: number }

-- HOW FAR BELOW THE SURFACE THE JUNCTION GOES, so the tree is planted in the ground rather than
-- balanced on it. The lobby's own `TREELINE.SINK_STUDS`.
TreeGround.SINK_STUDS = 0.6

-- A TREE IS "FLOATING" WHEN ITS JUNCTION IS THIS FAR ABOVE THE GROUND. 0.2 is the number task 196
-- measured the lobby's 38 trees against and the number this task's target is written in.
TreeGround.TOLERANCE_STUDS = 0.2

-- WHICH PARTS COUNT AS REACHING THE GROUND: the ones whose own bottom is within this band of the
-- model's lowest point. A fraction of the model's height so it survives a per-tree random scale,
-- with a floor in studs so a fern (2.8 studs tall) does not get a 0.06-stud band.
TreeGround.GROUND_BAND = 0.02
TreeGround.GROUND_BAND_FLOOR = 0.5

-- GROUND UNDER ONE FOOTPRINT THAT VARIES MORE THAN THIS IS A CLIFF EDGE, AND THE TREE IS LISTED
-- RATHER THAN MOVED (the Director's own instruction for this task). Measured on the live forest:
-- the spread under a trunk footprint is 0.23 studs at the median and 2.10 at the ninetieth
-- percentile, so 4.0 lets every ordinary slope through and stops only the genuine edge cases.
TreeGround.CLIFF_STUDS = 4.0

-- THE UNION OF SEVERAL BOXES. Returns nil for an empty list rather than a zero box at the origin:
-- a model with no visible part is a thing to report, not a thing to plant at y = 0.
function TreeGround.bounds(boxes: { Box }): Box?
	local out: Box? = nil
	for _, box in ipairs(boxes) do
		if out == nil then
			out = {
				minX = box.minX,
				minY = box.minY,
				minZ = box.minZ,
				maxX = box.maxX,
				maxY = box.maxY,
				maxZ = box.maxZ,
			}
		else
			local o = out :: Box
			o.minX, o.minY, o.minZ = math.min(o.minX, box.minX), math.min(o.minY, box.minY), math.min(o.minZ, box.minZ)
			o.maxX, o.maxY, o.maxZ = math.max(o.maxX, box.maxX), math.max(o.maxY, box.maxY), math.max(o.maxZ, box.maxZ)
		end
	end
	return out
end

-- THE BAND, IN STUDS, FOR A MODEL OF THIS HEIGHT.
function TreeGround.groundBand(height: number): number
	return math.max(TreeGround.GROUND_BAND * height, TreeGround.GROUND_BAND_FLOOR)
end

-- WHICH OF THE BOXES REACH THE GROUND -- their indices, in the order given. The canopy is what this
-- throws away, and throwing it away is the whole point: a birch's crown is twenty-five studs across
-- and its root flare is eight, so a grid over the WHOLE bounding box reads the ground under the
-- CANOPY -- twelve studs from the trunk, down a bank or off the edge of the terrain -- and settles
-- the tree to that. Task 196 part 3c made exactly that mistake and reported zero floating trees.
function TreeGround.groundReaching(boxes: { Box }, whole: Box): { number }
	local band = TreeGround.groundBand(whole.maxY - whole.minY)
	local out = {}
	for index, box in ipairs(boxes) do
		if box.minY <= whole.minY + band then
			table.insert(out, index)
		end
	end
	return out
end

-- HOW WIDE A ROOT FLARE CAN BE, as a fraction of the tree's height and never less than this many
-- studs. The lobby wrote the number down in words while fixing the same defect -- *"a birch's crown
-- is twenty-five studs across and its root flare is eight"* -- and eight studs across on a
-- seventy-five-stud birch is 0.053 of its height each side. 0.08 leaves room above that.
TreeGround.FLARE_FRACTION = 0.08
TreeGround.FLARE_FLOOR = 2.0

-- THE FOOTPRINT TO SAMPLE THE GROUND UNDER, which is NOT simply the trunk part's box.
--
-- MEASURED ON THE LIVE FOREST, AND THIS IS WHY IT EXISTS: some of these models' "Trunk" meshes are
-- the whole lower tree -- `LarchTree_Var02`'s is 15.6 studs across -- so sampling to its corners
-- reads the ground SEVEN STUDS FROM THE TRUNK, down a bank, which is the canopy mistake wearing a
-- different hat. It made the ground under nineteen larches look like a cliff and left every one of
-- them floating thirty studs in the air. Beyond the flare, the ground is not what the tree stands
-- on.
--
-- IT ONLY EVER SHRINKS, AND ALWAYS ABOUT THE FOOTPRINT'S OWN CENTRE, so a narrow trunk is returned
-- untouched.
--
-- `Lobby.Build` DOES NOT CALL IT, and that is a measurement rather than a preference. I added it
-- there too, claiming it was inert for the lobby's two templates because their trunk parts are 3.7
-- and 2.0 studs across -- and `lobby.spec`'s "buries each tree's root claws" case FAILED: that case
-- reads the ground across the whole model box on a slope, so narrowing the sampled strip raises the
-- lowest reading and every lobby tree sinks less than the 0.6 studs it is held to. The lobby does
-- not need the guard anyway: its footprint is already the union of the parts that REACH THE GROUND,
-- and on those templates the near-ground parts ARE the flare.
function TreeGround.flareFootprint(box: Box, height: number): Box
	local reach = math.max(TreeGround.FLARE_FRACTION * height, TreeGround.FLARE_FLOOR)
	local midX, midZ = (box.minX + box.maxX) / 2, (box.minZ + box.maxZ) / 2
	return {
		minX = math.max(box.minX, midX - reach),
		minY = box.minY,
		minZ = math.max(box.minZ, midZ - reach),
		maxX = math.min(box.maxX, midX + reach),
		maxY = box.maxY,
		maxZ = math.min(box.maxZ, midZ + reach),
	}
end

-- A GRID PLUS THE CORNERS, over a footprint. The corners matter most, because that is where the
-- root tips are (lesson L-024: *"ground height must be sampled at each tree's actual footprint
-- corners, not one point reused for the whole model"*). `steps` is the number of GAPS, so 4 gives
-- a 5 x 5 grid whose outermost samples sit exactly on the footprint's edges.
--
-- `Build.footprintSamples` is this function; it delegates here so there is one grid in the repo.
function TreeGround.samples(
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	steps: number
): { { x: number, z: number } }
	local out = {}
	local n = math.max(2, steps)
	for ix = 0, n do
		for iz = 0, n do
			table.insert(out, { x = minX + (maxX - minX) * ix / n, z = minZ + (maxZ - minZ) * iz / n })
		end
	end
	return out
end

-- WHERE THE TRUNK STOPS BEING CLAWS, IN THE WORLD. `clawFraction` is a property of the MESH,
-- measured once per model and kept as data -- a fraction of the model's HEIGHT so it survives the
-- per-tree random scale. The lobby keeps its two in `Lobby.CONFIG.TREELINE.SPECIES`; the forest's
-- fifty-one are in `tools/forest_claws.json`, measured by `forest_ground.py species`.
function TreeGround.junctionY(minY: number, maxY: number, clawFraction: number): number
	return minY + (maxY - minY) * clawFraction
end

-- HOW DEEP TO BURY THE JUNCTION FOR A MODEL OF THIS HEIGHT. `SINK_STUDS` is sized for a sixty-stud
-- tree; on a 2.8-stud fern it would be a fifth of the plant, so it is also capped at a tenth of the
-- height. A tree is never affected by the cap and a fern always is, which is the intent written as
-- one line rather than as two code paths.
function TreeGround.sinkFor(height: number): number
	return math.min(TreeGround.SINK_STUDS, 0.1 * height)
end

-- THE PLANTING RULE, AND THE ONE LINE THAT MOVES ANYTHING: drop until NO contact is left in the
-- air -- the LOWEST ground under the footprint wins -- and then a little further.
--
-- A truck is the other way round (lift until no wheel is buried, which is `max`); that is why
-- `Lobby.Build.settleOnGround` keeps its own `max` branch and calls this one for `toLowest`.
function TreeGround.liftTo(contacts: { Contact }, sink: number): number?
	if #contacts == 0 then
		return nil
	end
	local lift = math.huge
	for _, contact in ipairs(contacts) do
		lift = math.min(lift, contact.ground - contact.bottom)
	end
	return lift - sink
end

-- HOW MUCH THE GROUND UNDER ONE FOOTPRINT VARIES. A tree on a cliff edge has a big number here, and
-- sinking it to the lowest reading would bury it to the crown on the high side.
function TreeGround.spread(grounds: { number }): number
	if #grounds == 0 then
		return 0
	end
	local low, high = math.huge, -math.huge
	for _, y in ipairs(grounds) do
		low, high = math.min(low, y), math.max(high, y)
	end
	return high - low
end

export type Verdict = {
	-- WHAT WOULD BE DONE, and nothing is done by this function: it returns the decision.
	move: boolean,
	-- HOW FAR DOWN. Negative; nil when nothing should move.
	lift: number?,
	-- THE JUNCTION ABOVE THE LOWEST GROUND UNDER THE FOOTPRINT. This is the number the task's target
	-- is written in -- "0 trees with the junction more than 0.2 above the terrain".
	clawGap: number,
	-- THE LOWEST VISIBLE GEOMETRY ABOVE THE LOWEST GROUND: task 196's own metric, and the one that
	-- is NOT the setter echoed back, because nothing here sets a model's lowest point (lessons
	-- L-028 and L-086).
	bottomGap: number,
	spread: number,
	-- WHY, in one word, for the dry run's listing: "ok", "cliff", "seated", "no-ground".
	reason: string,
}

-- ONE TREE, DECIDED. Everything it needs has already been measured off the world by the caller.
--
-- IT ONLY EVER SINKS A TREE (the Director's *"it changes only the vertical position of trees whose
-- claws show; it never moves a tree sideways, never deletes one"*). A tree that is already deep in
-- the ground is left exactly where it is and reported as `seated` -- raising it is a different
-- question and nobody has asked it.
function TreeGround.decide(minY: number, maxY: number, clawFraction: number, grounds: { number }): Verdict
	if #grounds == 0 then
		return { move = false, lift = nil, clawGap = 0, bottomGap = 0, spread = 0, reason = "no-ground" }
	end
	local spread = TreeGround.spread(grounds)
	local lowest = math.huge
	for _, y in ipairs(grounds) do
		lowest = math.min(lowest, y)
	end
	local junction = TreeGround.junctionY(minY, maxY, clawFraction)
	local clawGap, bottomGap = junction - lowest, minY - lowest
	if clawGap <= TreeGround.TOLERANCE_STUDS then
		return {
			move = false,
			lift = nil,
			clawGap = clawGap,
			bottomGap = bottomGap,
			spread = spread,
			reason = "seated",
		}
	end
	if spread > TreeGround.CLIFF_STUDS then
		return { move = false, lift = nil, clawGap = clawGap, bottomGap = bottomGap, spread = spread, reason = "cliff" }
	end
	local contacts: { Contact } = {}
	for _, y in ipairs(grounds) do
		table.insert(contacts, { ground = y, bottom = junction })
	end
	local lift = TreeGround.liftTo(contacts, TreeGround.sinkFor(maxY - minY))
	return { move = true, lift = lift, clawGap = clawGap, bottomGap = bottomGap, spread = spread, reason = "ok" }
end

return TreeGround
