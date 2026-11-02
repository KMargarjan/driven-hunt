--!strict
-- GridCensus: DOES EVERY PLANTED TREE STAND ON THE GROUND? The instrument, and only the instrument.
--
-- Task 199's lesson, verbatim: *the thing which places a tree may not be the thing that certifies
-- it.* So this module SHARES THE THRESHOLDS AND SHARES NO MEASUREMENT. It requires `TreeGround` for
-- `TOLERANCE_STUDS`, `sinkFor` and `junctionY` -- three constants and one line of arithmetic -- and
-- it never calls `Places.trunkBox` or `Places.groundsUnder`. It finds each part's own bottom face
-- and its caller hands it a FRESH ground reader.
--
-- Design: docs/design/grid-terrain.md section 9.4 ("The census -- ServerStorage.GridCensus").
-- Nothing in `src/` calls it, the way `Places.junctionGap` has no `src/` caller: its two callers are
-- `tests/server/grid_ground.spec.luau` and a live probe in the Forest Test.
--
-- WHAT IT COUNTS AND WHAT IT REFUSES TO COUNT. Five rows of design 9.4 name geometry no task has
-- built yet (the verge, the ditch, the ride, the tower deck, the beater path) and two name a surface
-- share the bake has not painted. Those read `UNMEASURED`, never 0 -- design 12.2: no gate may cite
-- one of them as evidence before its task measures it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreeGround = require(ReplicatedStorage:WaitForChild("TreeGround"))
local Plan = require(ReplicatedStorage:WaitForChild("Places"))
local Grid = require(ReplicatedStorage:WaitForChild("Grid"))

local GridCensus = {}

-- A PART THIS TRANSPARENT IS NOT WHAT KAREN SEES, so it is not what the census measures. The
-- planter's own number, for the same reason it needed one (the birches' invisible pad).
GridCensus.INVISIBLE_AT = 0.95

-- LEANING. Design 9.4: `up . Y < cos 2`. Kept as the cosine so the comparison is one dot product.
GridCensus.TILT_COS = math.cos(math.rad(2))

-- LYING IS THE AUDIT'S NUMBER AND NOT ONE OF OURS: `Plan.AUDIT_LYING_DEGREES` (5), reached through
-- `brokenReason` below. Leaning is this module's own 2 degrees, above.

-- A FOLIAGE PART IS IN THE GROUND WHEN ITS BOTTOM IS THIS FAR BELOW IT (design 9.4).
GridCensus.FOLIAGE_SINK_STUDS = 0.5

-- HOW CLOSE TO A STAND COUNTS AS "IN" IT. `Grid`'s own clearance, which is what the planter's lane
-- rule keeps clear.
GridCensus.STAND_CLEAR_STUDS = 8

-- THE ROWS THIS TASK CANNOT MEASURE, each named with the task that builds the thing it is about.
GridCensus.UNMEASURED = table.freeze({
	inVerge = "328e (the verge is not cut)",
	inDitch = "328e (the ditch is not dug)",
	inRide = "328f (the rides are not cut)",
	inTower = "328h (the tower decks are not built)",
	inBeaterPath = "328h (the beater paths are not cut)",
	rockPct = "328d (the bake paints no material yet)",
	mudPct = "328d (the bake paints no material yet)",
})

export type Box = {
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

-- ONE PART'S AXIS-ALIGNED BOTTOM AND REACH, from its own CFrame. The census's own copy of the
-- projection, deliberately: see the header.
local function boxOf(part: BasePart): Box
	local size = part.Size
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
	local hx = 0.5 * (math.abs(r00) * size.X + math.abs(r01) * size.Y + math.abs(r02) * size.Z)
	local hy = 0.5 * (math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z)
	local hz = 0.5 * (math.abs(r20) * size.X + math.abs(r21) * size.Y + math.abs(r22) * size.Z)
	local at = part.Position
	return {
		minX = at.X - hx,
		minY = at.Y - hy,
		minZ = at.Z - hz,
		maxX = at.X + hx,
		maxY = at.Y + hy,
		maxZ = at.Z + hz,
	}
end

local function union(boxes: { Box }): Box?
	local out: Box? = nil
	for _, box in ipairs(boxes) do
		if out == nil then
			out =
				{ minX = box.minX, minY = box.minY, minZ = box.minZ, maxX = box.maxX, maxY = box.maxY, maxZ = box.maxZ }
		else
			local o = out :: Box
			o.minX, o.minY, o.minZ = math.min(o.minX, box.minX), math.min(o.minY, box.minY), math.min(o.minZ, box.minZ)
			o.maxX, o.maxY, o.maxZ = math.max(o.maxX, box.maxX), math.max(o.maxY, box.maxY), math.max(o.maxZ, box.maxZ)
		end
	end
	return out
end

export type Measured = {
	name: string,
	-- THE TRUNK: the union of the boxes of the parts that are NOT foliage by name. A name, not a
	-- band, because `Places.isFoliageName` is already asserted to match no trunk name and the
	-- census must not re-derive the planter's own footprint rule.
	trunk: Box?,
	whole: Box?,
	crown: Box?,
	parts: number,
	tiltCos: number,
	-- WHERE THE GROUND IS, under EVERY footprint sample -- the worst case over all of them, never
	-- one point (standing rule E, lesson L-086).
	lowGround: number?,
	highGround: number?,
	foliageLow: number?,
}

-- ONE MODEL, MEASURED OFF THE DRAWN PARTS. `groundAt` is the caller's: the probe hands a downward
-- ray filtered to `Workspace.Terrain`, a spec hands a fake hillside and no world is needed.
function GridCensus.measure(model: Model, groundAt: (number, number) -> number?): Measured
	local out: Measured = {
		name = model.Name,
		trunk = nil,
		whole = nil,
		crown = nil,
		parts = 0,
		tiltCos = 1,
		lowGround = nil,
		highGround = nil,
		foliageLow = nil,
	}
	local all: { Box }, trunks: { Box }, crowns: { Box } = {}, {}, {}
	local lowest: BasePart? = nil
	local lowestY = math.huge
	for _, thing in ipairs(model:GetDescendants()) do
		if thing:IsA("BasePart") and thing.Transparency < GridCensus.INVISIBLE_AT then
			local box = boxOf(thing)
			out.parts += 1
			table.insert(all, box)
			if Plan.isFoliageName(thing.Name) then
				table.insert(crowns, box)
				out.foliageLow = math.min(out.foliageLow or math.huge, box.minY)
			else
				table.insert(trunks, box)
				if box.minY < lowestY then
					lowest, lowestY = thing, box.minY
				end
			end
		end
	end
	out.whole = union(all)
	out.trunk = union(trunks) or out.whole
	out.crown = union(crowns)
	if lowest ~= nil then
		out.tiltCos = (lowest :: BasePart).CFrame.UpVector:Dot(Vector3.yAxis)
	end
	local trunk = out.trunk
	if trunk ~= nil then
		-- THE WHOLE FOOTPRINT, 5 x 5 AND THE CORNERS. `TreeGround.samples` is arithmetic, not a
		-- measurement, so sharing it is sharing the grid and not sharing the reading.
		for _, point in ipairs(TreeGround.samples(trunk.minX, trunk.minZ, trunk.maxX, trunk.maxZ, 4)) do
			local y = groundAt(point.x, point.z)
			if y ~= nil then
				out.lowGround = math.min(out.lowGround or math.huge, y)
				out.highGround = math.max(out.highGround or -math.huge, y)
			end
		end
	end
	return out
end

-- IS THE DRAWN MODEL STILL THE TEMPLATE IT WAS CLONED FROM? Design 9.3's audit, run AFTER planting,
-- which is what design 9.4 calls `broken`. **THE RULE IS `Plan.auditReason` AND NOT A SECOND COPY OF
-- IT**: the planter audits the template and this audits the clone, so the two differ only in what
-- they measure (design 9.1's whole point).
function GridCensus.brokenReason(measured: Measured, dims: any?, scale: number): string?
	return Plan.auditReason({
		name = measured.name,
		parts = measured.parts,
		tiltCos = measured.tiltCos,
		trunk = measured.trunk,
		whole = measured.whole,
		crown = measured.crown,
	}, dims, scale)
end

export type Report = { [string]: any }

-- THE WHOLE CELL, COUNTED. `folder` holds one model per tree; everything the world can answer is a
-- parameter, so `grid_ground.spec` drives this with a fake hillside and synthetic models.
--
-- `refused` IS THE PLANTER'S OWN NUMBER, handed in rather than re-derived -- design 9.4 reports it
-- in 328b and gates it from 328f.
function GridCensus.survey(
	folder: Instance?,
	cellId: string,
	groundAt: (number, number) -> number?,
	clawOf: (string) -> number,
	refused: { cliff: number, skipped: number, wanted: number }?
): Report
	local report: Report = {
		cell = cellId,
		trees = 0,
		parts = 0,
		floating = 0,
		sunk = 0,
		foliageInGround = 0,
		tilted = 0,
		broken = 0,
		noGround = 0,
		inRoad = 0,
		inStand = 0,
		inLane = 0,
		onCliff = 0,
		crownOverRoad = 0,
		worstHigh = -math.huge,
		worstSink = -math.huge,
		brokenBy = {},
		crownUnmeasured = 0,
	}
	for key, why in pairs(GridCensus.UNMEASURED) do
		report[key] = "UNMEASURED: " .. why
	end
	if folder == nil then
		report.reason = "no-folder"
		return report
	end
	local stands: { Vector3 } = {}
	if Grid.cellOf(cellId) ~= nil then
		for index = 1, Grid.standCount(cellId) do
			table.insert(stands, Grid.standPosition(cellId, index))
		end
	end
	local plan = Plan.cellPlanFor(cellId)
	local laneHalf = if plan ~= nil then Plan.laneHalfWidth(plan) else 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			local model = child :: Model
			report.trees += 1
			local measured = GridCensus.measure(model, groundAt)
			report.parts += measured.parts
			local trunk, whole = measured.trunk, measured.whole
			local scale = model:GetScale()
			local dims = Plan.dimsFor(model.Name)
			local broken = GridCensus.brokenReason(measured, dims, scale)
			if broken ~= nil then
				report.broken += 1
				report.brokenBy[broken] = (report.brokenBy[broken] or 0) + 1
			end
			if measured.tiltCos < GridCensus.TILT_COS then
				report.tilted += 1
			end
			if trunk == nil or whole == nil or measured.lowGround == nil then
				report.noGround += 1
			else
				local low = measured.lowGround :: number
				local high = measured.highGround :: number
				local height = whole.maxY - whole.minY
				local junction = TreeGround.junctionY(trunk.minY, whole.maxY, clawOf(model.Name))
				local gap = junction - low
				if gap > TreeGround.TOLERANCE_STUDS then
					report.floating += 1
				end
				if low - junction > TreeGround.sinkFor(height) + TreeGround.TOLERANCE_STUDS then
					report.sunk += 1
				end
				if
					measured.foliageLow ~= nil
					and (measured.foliageLow :: number) < low - GridCensus.FOLIAGE_SINK_STUDS
				then
					report.foliageInGround += 1
				end
				if high - low > Plan.stepAllowanceStuds(height) then
					report.onCliff += 1
				end
				report.worstHigh = math.max(report.worstHigh, gap)
				report.worstSink = math.max(report.worstSink, low - junction)
			end
			-- WHERE IT STANDS. The trunk's own centre and never the model pivot: a free model's
			-- pivot is its bounding-box centre, which for a wide crown is studs from the foot.
			local atX = if trunk ~= nil then (trunk.minX + trunk.maxX) / 2 else model:GetPivot().Position.X
			local atZ = if trunk ~= nil then (trunk.minZ + trunk.maxZ) / 2 else model:GetPivot().Position.Z
			if not Plan.clearOfEveryRoad(atX, atZ) then
				report.inRoad += 1
			end
			if not Plan.clearOfEveryLane(atX, atZ) then
				report.inLane += 1
			end
			for _, spot in ipairs(stands) do
				local dx, dz = atX - spot.X, atZ - spot.Z
				if dx * dx + dz * dz < GridCensus.STAND_CLEAR_STUDS * GridCensus.STAND_CLEAR_STUDS then
					report.inStand += 1
					break
				end
			end
			-- THE CROWN OVER A ROAD. `UNMEASURED` for a template with no `TEMPLATE_DIMS` row, and
			-- counted for every one that has one (design 9.4's row, now that 9.2's table exists).
			if dims == nil then
				report.crownUnmeasured += 1
			else
				local reach = dims.crownHalfWidthStuds * (scale / math.max(dims.scale, 1e-6))
				if not Plan.clearOfEveryRoad(atX, atZ, reach) then
					report.crownOverRoad += 1
				end
			end
		end
	end
	if report.trees == 0 then
		report.worstHigh, report.worstSink = 0, 0
	end
	report.laneHalf = laneHalf
	if refused ~= nil then
		report.refusedCliff, report.refusedSkipped, report.refusedWanted =
			refused.cliff, refused.skipped, refused.wanted
		local wanted = math.max(refused.wanted, 1)
		report.refusedPct = 100 * (refused.cliff + refused.skipped) / wanted
	end
	return report
end

-- THE ONE PASTEABLE LINE (design 9.4). `epoch` is the caller's: today the commit it ran at.
function GridCensus.line(report: Report, epoch: string?): string
	local unmeasured = {}
	for key in pairs(GridCensus.UNMEASURED) do
		table.insert(unmeasured, key)
	end
	table.sort(unmeasured)
	return string.format(
		"[census] %s epoch=%s trees=%d parts=%d floating=%d sunk=%d foliageInGround=%d tilted=%d broken=%d"
			.. " noGround=%d inRoad=%d inStand=%d inLane=%d onCliff=%d crownOverRoad=%d crownUnmeasured=%d"
			.. " refused=%s worstHigh=%.2f worstSink=%.2f UNMEASURED=%s",
		tostring(report.cell),
		tostring(epoch or "?"),
		report.trees,
		report.parts,
		report.floating,
		report.sunk,
		report.foliageInGround,
		report.tilted,
		report.broken,
		report.noGround,
		report.inRoad,
		report.inStand,
		report.inLane,
		report.onCliff,
		report.crownOverRoad,
		report.crownUnmeasured,
		if report.refusedPct ~= nil
			then string.format(
				"%d+%d/%d=%.1f%%",
				report.refusedCliff,
				report.refusedSkipped,
				report.refusedWanted,
				report.refusedPct
			)
			else "not-handed-in",
		report.worstHigh,
		report.worstSink,
		table.concat(unmeasured, ",")
	)
end

-- WHERE A PROBE CAN READ IT BACK, in a later session and after the console has scrolled (V293b): one
-- attribute per count, on the instance the caller names.
function GridCensus.publish(target: Instance, report: Report, epoch: string?): number
	local written = 0
	for key, value in pairs(report) do
		if typeof(value) == "number" or typeof(value) == "string" or typeof(value) == "boolean" then
			target:SetAttribute("Census_" .. key, value)
			written += 1
		end
	end
	target:SetAttribute("Census_epoch", epoch or "?")
	target:SetAttribute("Census_line", GridCensus.line(report, epoch))
	return written + 2
end

return GridCensus
