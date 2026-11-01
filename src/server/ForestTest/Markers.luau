--!strict
-- ForestTest.Markers: THE FOREST'S OWN MARKER SET, and the only writer of `Workspace.ForestMarkers`.
--
-- The real drive (`ServerScriptService.Match`) reads its geometry as a `Match.Markers.MarkerSet` --
-- nine shooter posts, one drive line, a driver start, the boar spawns, the tie trees -- and in the
-- DEV place that set comes from five `CollectionService` tags the generated map placed. This place
-- has no such tags and never will (one `GetTagged` must never be able to answer for two worlds,
-- which is the inverse of the Task 79 hazard). So this module BUILDS the set from the forest's own
-- data and hands it over through `world.markers`.
--
-- WHY PARTS AND NOT POSITIONS: `Match.Body` consumes them as `BasePart`s and is the one writer of
-- where a character stands -- `placementFor` reads `post.Position` and `post.Size.Y`, `anchorFor`
-- scans the list, `tiePointFor` reads a trunk's `Size`. Nine invisible parts cost nine instances and
-- change no interface; a position-based `MarkerSet` would change `Markers`, `Body` and DEV's own
-- path.
--
-- Pattern: THE WORLD PLACES THE ENTITIES THE GAME MODE QUERIES -- Valve's `info_player_terrorist`
-- (the map's entities are the mode's contract, and their COUNT caps the team) and Unreal's
-- `PlayerStart` actors found by `AGameModeBase::FindPlayerStart`. Their worst property is removed:
-- a missing marker here is a named `missing` string that keeps the drive in `Waiting`, never a
-- silent spawn at the world origin.
--   info_player_(counter)terrorist https://developer.valvesoftware.com/wiki/De/Info_player_counterterrorist
--   FindPlayerStart https://docs.unrealengine.com/5.1/en-US/API/Runtime/Engine/GameFramework/AGameModeBase/FindPlayerStart/
--
-- IT RUNS ONLY IN THE FOREST TEST PLACE. `ForestTestBoot` returns early anywhere else, so the DEV
-- place -- where the harness runs -- never sees the folder at all. `Workspace` is not Rojo-owned and
-- the harness compares the EDIT-mode DataModel, so a run-time Part cannot dirty a run: the same
-- property `Workspace.DriveMarkers`, `Workspace.WeaponEffects` and `Workspace.Boars` already have.
--
-- Design: docs/design/forest-drive.md (section 4.1)
-- Note:   docs/research/2026-10-11-forest-drive.md
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))

local Markers = {}

Markers.FOLDER_NAME = "ForestMarkers"

-- THE GENERATED MAP'S OWN POST (`docs/design/map-generator.md` section 15.1: 6 x 1 x 6), so
-- `Match.CONFIG.STAND_HEIGHT_STUDS` means the same thing in both worlds and a hunter stands the same
-- height above the ground here as she does there.
Markers.POST_SIZE = Vector3.new(6, 1, 6)
-- The beater pad. Nothing in production reads it -- the forest answers for a beater through
-- `world.placement` -- but `Match.Markers.MarkerSet` has the field, `Body.placementFor` would use it
-- for a driver, and a nil there is a nil `CFrame`, which is how a player gets teleported to the
-- origin. It exists so no path can produce one.
Markers.START_SIZE = Vector3.new(60, 1, 20)

-- HOW FAR THE TWO READINGS OF THE GROUND MAY DISAGREE before a stand is refused.
--
-- `Data.groundAt` excludes `OurForest`, `Foliage` and `Boars` -- and that is NOT every tree in this
-- place: 831 more live in two Studio-built folders both called `Session` (measured in task 153, and
-- quoted in `ForestTest.terrainYAt`'s header), so a downward ray can stop on a canopy. Over the cut
-- road lane it must not. A disagreement there is evidence that this is not the place we think it is,
-- not a number to average, so the stand is refused and counted.
Markers.GROUND_TOLERANCE_STUDS = 1

export type Set = {
	-- WHICH DRIVE LAYOUT THIS SET WAS MEASURED ON (task 179). A console line, the boot's `markers:`
	-- report and any later reader can then SAY which world the drive is standing on instead of
	-- assuming there is only one.
	layout: string,
	posts: { BasePart },
	-- THE MAIN LINE'S POSTS, AND ONLY THEM (task 327b, design 6.4). `posts` is every stand of the
	-- cell in index order, which is what the map, the pick and the placement want. THIS is what
	-- answers "where is the hunters' LINE" -- a question about the drive's AXIS -- and a flank post
	-- is 340 studs up the cell, so it would answer it wrong by exactly that much and end the drive
	-- at ~90 s. nil-safe: with no `sides` it IS `posts`.
	linePosts: { BasePart },
	line: { position: Vector3, normal: Vector3 }?,
	lineParts: number,
	driverStart: BasePart?,
	boarSpawns: { Vector3 },
	spawnRadius: number,
	trees: { BasePart },
	complete: boolean,
	missing: { string },
}

-- THE TWO READINGS OF THE GROUND, INJECTED BY THE PARENT AT LOAD TIME (`ForestTest`'s last lines).
--
-- A DEVIATION FROM THE DESIGN'S WORDING, AND THE REASON IS A CYCLE: the design has `build` default
-- these to `ForestTest.terrainYAt` and `Data.groundAt` directly, but this module is a CHILD of
-- `ForestTest` and requiring the parent from here would be a cyclic require. Writing a third copy of
-- the two rays would be worse -- two definitions of "where is the ground" is this project's named
-- failure mode -- so the parent hands its own functions over once, and `build` still takes both as
-- parameters so a spec drives the whole rule with hand-written numbers.
local defaultGround: ((number, number) -> number?)? = nil
local defaultCanopy: ((number, number) -> number?)? = nil

function Markers.setReaders(ground: ((number, number) -> number?)?, canopy: ((number, number) -> number?)?)
	defaultGround, defaultCanopy = ground, canopy
end

-- WHERE A STAND'S DECK IS, INJECTED (task 218). The `setReaders` shape and the same reason: this
-- module is a child of `ForestTest` and requiring the parent from here would be a cyclic require.
-- `nil` is "no seats in this world", which is every world but the Forest Test.
local defaultSeats: ((number) -> number?)? = nil

function Markers.setSeatSource(fn: ((number) -> number?)?)
	defaultSeats = fn
end

local stats =
	{ posts = 0, refused = 0, reads = 0, lastMaxDelta = 0, rings = 0, lastRingSegments = 0, lastRingFallbacks = 0 }

-- What the last build measured: how many stands it placed, how many it refused, how many builds
-- there have been, and the worst disagreement between the two ground readings. The console prints it
-- (a tool that requires this module over StudioMCP gets a sandboxed copy with empty state -- measured
-- in task 122 -- so the server's own print is the only honest channel).
function Markers.stats()
	return table.clone(stats)
end

function Markers.folder(): Folder?
	local existing = Workspace:FindFirstChild(Markers.FOLDER_NAME)
	return if existing and existing:IsA("Folder") then existing :: Folder else nil
end

-- Destroys the folder and everything in it. The ONE destroyer, so "the folder holds exactly ten
-- parts" is structural rather than a cleanup path.
function Markers.clear()
	local folder = Markers.folder()
	if folder then
		folder:Destroy()
	end
end

local function ensureFolder(): Folder
	local folder = Markers.folder()
	if folder then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = Markers.FOLDER_NAME
	made.Parent = Workspace
	return made
end

-- One marker. `CanQuery = false` IS LOAD-BEARING and not tidiness: a slab that stops a pellet changes
-- what the shot hit, and what the shot hit is what the weapon reports and `Penalty.judge` reads. The
-- rope in `Match.Body` and the outfit's plates are set the same way for the same reason.
local function marker(name: string, position: Vector3, size: Vector3, parent: Folder): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- ---------------------------------------------------------------- the stand's edge (task 166)
--
-- KAREN, 2026-10-12: *"we need boundries but not put back where it started"*. A boundary a player
-- cannot see is a wall in the dark, so the circle he may walk in is DRAWN -- one thin ring laid on
-- the ground at exactly `ForestTest.PICK.standRadiusStuds`, which is the same number
-- `ForestTest.boundaryPoint` clamps to, passed in rather than read here because this module decides
-- nothing (the discipline `build` already follows with `standX`).
--
-- WHY THIS MODULE DRAWS IT: it is the one writer of `Workspace.ForestMarkers` (rule 3), the stands
-- themselves are its parts, and it already owns the two ground readers a ring has to sit on. The
-- boot says WHEN -- one ring when a pick locks, all of them cleared when the next intermission drops
-- the picks -- and that is the same split the markers have.
--
-- WHY BOXES AND NOT ONE PART: there is no ring primitive. A Cylinder is a disc, a torus needs a mesh
-- (nothing is uploaded for this), and a decal needs an image. So the circle is a POLYLINE LAID ON
-- THE GROUND: short boxes end to end, each one tilted to the slope it crosses.
--
-- KAREN, 2026-10-18 ~14:20, looking at stand 6 of the road line: *"and this is not circle is broken
-- one"*. Task 166 drew twenty 3.8-stud chords, each one LEVEL and sitting at the ground reading
-- under its own MIDDLE. On a slope a level 3.8-stud slab cannot touch the ground at both ends, so
-- its uphill half went under the hill and its downhill half hung in the air, and two neighbours met
-- at a vertical STEP. MEASURED over all 25 stands of the four layouts, in Karen's own place
-- (2026-10-19, before this change): worst slab buried 1.06 studs, worst slab floating 1.56 studs,
-- and the worst joint between two neighbours 2.48 studs apart -- all three at road stand 6, which is
-- the stand her screenshot was taken on. That is the picture: separate slabs with gaps between them.
--
-- WHAT MAKES IT ONE LINE AGAIN, and each part of it is load-bearing:
--
--   * THE GROUND IS READ AT THE VERTICES, NOT AT THE MIDDLES. Two neighbouring segments share a
--     vertex, so they share ONE reading of the ground there and meet at the same height. The step
--     between them is not made small, it is made IMPOSSIBLE -- the same trick `Horn.pieces` uses to
--     stop its tube gapping, and the reason the chord is measured in 3D here rather than taken from
--     `2r sin(pi/n)`.
--   * EACH SEGMENT IS TILTED along its own chord (`CFrame.fromMatrix`'s X axis is the chord), and
--     ROLLED to the cross-slope measured either side of its middle. A tilted box lies on the hill
--     instead of cutting into it, which is what removes the burying and the floating.
--   * 48 SEGMENTS, NOT 20. At r = 12 that is a chord of 1.57 studs, and the error between a chord
--     and the true circle is r*(1-cos(pi/48)) = 0.026 studs -- a thirtieth of the ring's own width,
--     so no corner can show at eye height. 48 parts per ring, at most one ring per hunter
--     (`ForestTestBoot` draws one when a pick locks and `clearRings` takes them all down at the next
--     intermission), so the worst case is 48 x 9 = 432 invisible-to-a-pellet parts on the road line.
--     64 WAS MEASURED TOO, on the same 25 stands: worst buried 0.17 against 48's 0.21 and worst
--     floating 0.20 against 0.16. What is left at 48 is not the chord's sag, it is a 24-degree
--     CREASE in the terrain at road stand 6, which no number of segments removes -- so the extra 16
--     parts a ring bought nothing and 48 is the number.
--   * THE NEIGHBOURS OVERLAP by `OVERLAP_STUDS`, half at each end, so the wedge a bend leaves on the
--     outside of a joint is covered rather than merely small.
--   * A GROUND THE TWO READERS DISAGREE ON NO LONGER DELETES THE SEGMENT (`ringGroundFor`): it falls
--     back to the TERRAIN reader and counts it. `build` keeps its refusal -- a stand nobody can
--     measure must not be stood on -- but the ring stops no pellet and decides nothing, and a hole
--     in the circle is the very defect this task is about.
Markers.RING_PREFIX = "StandRing"

Markers.RING = table.freeze({
	SEGMENTS = 48,
	THICKNESS_STUDS = 0.5,
	HEIGHT_STUDS = 0.12,
	-- Just clear of the ground, so z-fighting cannot make it flicker as the camera moves.
	LIFT_STUDS = 0.08,
	-- HOW FAR NEIGHBOURS OVERLAP, half of it at each end of every segment. 0.12 is a fifth of the
	-- ring's own width and a quarter of its thickness: enough to cover the outside of a bend
	-- (0.25 * tan(3.75 deg) = 0.016 studs at 48 segments) many times over, and far too little to
	-- read as a bulge.
	OVERLAP_STUDS = 0.12,
	-- SUBTLE, which is the dispatch's word: a line you notice when you look down and not a fence.
	TRANSPARENCY = 0.45,
	-- Neon so it reads in the wood's shade without a light. A muted hunting-orange, the colour this
	-- game already uses for "this is yours" (the beater's vest, the hunter's cap).
	COLOR = Color3.fromRGB(235, 150, 60),
})

-- The ring's container name for one stand, so no caller spells it twice.
function Markers.ringName(standIndex: number): string
	return string.format("%s%d", Markers.RING_PREFIX, standIndex)
end

-- One stand's ring, gone. Returns whether there was one, so the owner can count it.
function Markers.clearRing(standIndex: number): boolean
	local folder = Markers.folder()
	local existing = folder and folder:FindFirstChild(Markers.ringName(standIndex))
	if existing == nil then
		return false
	end
	existing:Destroy()
	return true
end

-- Every ring, gone. Returns how many there were.
function Markers.clearRings(): number
	local folder = Markers.folder()
	if folder == nil then
		return 0
	end
	local removed = 0
	for _, child in ipairs(folder:GetChildren()) do
		if string.match(child.Name, "^" .. Markers.RING_PREFIX .. "%d+$") then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

-- DRAWS ONE STAND'S EDGE, replacing whatever was there (the `Body.OUTFIT_NAME` discipline, so a
-- re-lock cannot leave two rings on one stand). Returns how many segments it placed: `SEGMENTS` on
-- clear ground, fewer where the two ground readings disagree, and 0 for a stand whose own ground
-- cannot be read at all -- which is the same refusal `build` makes, counted rather than guessed at.
function Markers.ring(
	standIndex: number,
	radiusStuds: number,
	layout: any,
	ground: ((number, number) -> number?)?,
	canopy: ((number, number) -> number?)?
): number
	local groundReader = ground or defaultGround
	local canopyReader = canopy or defaultCanopy
	Markers.clearRing(standIndex)
	if radiusStuds <= 0 then
		return 0
	end
	local home = Data.standPosition(standIndex, layout)
	local config = Markers.RING
	local count = config.SEGMENTS
	local step = 2 * math.pi / count
	-- THE VERTICES FIRST, AND THAT ORDER IS THE WHOLE FIX. Every point on the circle is measured
	-- once, at its own x,z, and the two segments that meet there both end at that one height -- so a
	-- step between neighbours cannot be produced, on any ground.
	local points: { Vector3? } = {}
	local fallbacks = 0
	for index = 1, count do
		local a = (index - 1) * step
		local x, z = home.X + math.cos(a) * radiusStuds, home.Z + math.sin(a) * radiusStuds
		local y, fellBack = Markers.ringGroundFor(x, z, groundReader, canopyReader)
		if fellBack then
			fallbacks += 1
		end
		points[index] = if y ~= nil then Vector3.new(x, y + config.LIFT_STUDS, z) else nil
	end
	local folder: Folder? = nil
	local placed = 0
	for index = 1, count do
		local from, to = points[index], points[(index % count) + 1]
		local span = if from and to then to - from else nil
		if from and to and span and span.Magnitude > 1e-4 then
			if folder == nil then
				local made = Instance.new("Folder")
				made.Name = Markers.ringName(standIndex)
				made.Parent = ensureFolder()
				folder = made
			end
			local part = Instance.new("Part")
			part.Name = string.format("Seg%d", index)
			-- OVERLAPPING ITS NEIGHBOURS: the box is longer than the gap it bridges, by half the
			-- overlap at each end.
			part.Size = Vector3.new(span.Magnitude + config.OVERLAP_STUDS, config.HEIGHT_STUDS, config.THICKNESS_STUDS)
			part.Anchored = true
			-- `CanQuery = false` IS LOAD-BEARING here for the same reason it is on every other marker
			-- in this file: a slab that stops a pellet changes what the shot hit.
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Color = config.COLOR
			part.Transparency = config.TRANSPARENCY
			local middle = (from + to) / 2
			local along = span.Unit
			part.CFrame = CFrame.fromMatrix(middle, along, Markers.ringUp(middle, along, groundReader, canopyReader))
			part.Parent = folder
			placed += 1
		end
	end
	-- COUNTED ONLY WHEN THERE IS A RING (round 1's note): a build that could read no ground drew
	-- nothing, and a counter that moved anyway would count attempts under a name that says rings.
	if placed > 0 then
		stats.rings += 1
	end
	stats.lastRingSegments = placed
	stats.lastRingFallbacks = fallbacks
	return placed
end

-- WHICH WAY IS UP FOR ONE SEGMENT, so the box lies ON the hill instead of cutting across it.
--
-- The ground is read at `THICKNESS_STUDS / 2` either side of the segment's middle, ACROSS its own
-- chord: that is the one slope the chord's two endpoints cannot already describe, and it is the
-- difference between a 0.5-stud strip whose downhill edge is buried and one that is not. The up
-- vector is then made square to the chord, because the chord's own tilt is already decided by the
-- two vertices and must not be moved.
--
-- The fallback is straight up -- a reading that cannot be taken must not tilt anything.
function Markers.ringUp(middle: Vector3, along: Vector3, ground, canopy): Vector3
	local up = Vector3.yAxis
	local across = along:Cross(Vector3.yAxis)
	if across.Magnitude > 1e-4 then
		across = across.Unit
		local half = Markers.RING.THICKNESS_STUDS / 2
		local high = Markers.ringGroundFor(middle.X + across.X * half, middle.Z + across.Z * half, ground, canopy)
		local low = Markers.ringGroundFor(middle.X - across.X * half, middle.Z - across.Z * half, ground, canopy)
		if high ~= nil and low ~= nil then
			-- TWO TANGENTS, AND THE NORMAL IS THEIR CROSS PRODUCT. `along` is the surface's tangent
			-- down the chord -- it joins two points measured ON the ground -- and
			-- `across + yAxis * slope` is its tangent across it. The cross product of the two is the
			-- surface itself, exactly, rather than a vector that is only square to one of them.
			local slope = ((high :: number) - (low :: number)) / Markers.RING.THICKNESS_STUDS
			local normal = (across + Vector3.yAxis * slope):Cross(along)
			up = if normal.Y < 0 then -normal else normal
		end
	end
	local square = up - along * up:Dot(along)
	return if square.Magnitude > 1e-4 then square.Unit else Vector3.yAxis
end

-- WHERE A RING SITS, AND IT NEVER LEAVES A HOLE WHERE THE TWO READERS DISAGREE. Returns the height
-- and whether it had to fall back.
--
-- `build` refuses such a point and that stays right: a stand nobody can measure must not be stood
-- on, and the refusal is a named `missing` string rather than a silent guess. A RING IS NOT A STAND.
-- It stops no pellet (`CanQuery = false`), decides nothing, and is read by nobody but the player's
-- eye -- so where the canopy reader argues with the terrain reader, the TERRAIN is what a line drawn
-- on the ground should follow, and a missing segment is the exact defect Karen named.
function Markers.ringGroundFor(x: number, z: number, ground, canopy): (number?, boolean)
	local agreed = Markers.groundFor(x, z, ground, canopy)
	if agreed ~= nil then
		return agreed, false
	end
	local terrain = if ground then ground(x, z) else nil
	return terrain, terrain ~= nil
end

-- HOW FAR FROM A SEATED STAND'S OWN POINT A READING IS STILL "UNDER THAT SEAT". It is
-- `HighSeats.DIMS.FOOTPRINT_RADIUS_STUDS` rounded up by half a stud of margin, written here rather
-- than required, because this module is a child of `ForestTest` and already takes everything it
-- knows about seats through one injected function. `high_seats.spec` asserts it covers the real
-- footprint radius, so the two cannot drift apart.
Markers.SEAT_COVER_STUDS = 5.6

-- IS THIS POINT UNDER ONE OF THE SEATS THIS BUILD PLACED? Flat, because a seat's footprint is flat.
function Markers.seatCovers(x: number, z: number, seated: { Vector3 }?): boolean
	if seated == nil then
		return false
	end
	for _, stand in ipairs(seated) do
		local dx, dz = x - stand.X, z - stand.Z
		if dx * dx + dz * dz <= Markers.SEAT_COVER_STUDS * Markers.SEAT_COVER_STUDS then
			return true
		end
	end
	return false
end

-- WHERE THE DRIVE LINE'S GROUND IS. `groundFor` everywhere, except under a seat we built ourselves,
-- where the TERRAIN reader answers alone -- see `build`'s own comment for the live run that found
-- it. Returns the height and the disagreement, exactly as `groundFor` does, so the caller's
-- `lastMaxDelta` arithmetic is unchanged; under a seat there is no disagreement to report.
function Markers.lineGroundFor(x: number, z: number, ground, canopy, seated: { Vector3 }?): (number?, number?)
	if Markers.seatCovers(x, z, seated) then
		return (if ground then ground(x, z) else nil), nil
	end
	return Markers.groundFor(x, z, ground, canopy)
end

-- WHERE THE GROUND IS, OR NIL, asking both readers and refusing a disagreement. Pure given its two
-- readers, which is what makes the refusal testable without a forest.
function Markers.groundFor(x: number, z: number, ground, canopy): (number?, number?)
	local y = if ground then ground(x, z) else nil
	local c = if canopy then canopy(x, z) else nil
	if y == nil or c == nil then
		return nil, nil
	end
	local delta = math.abs(y - c)
	if delta > Markers.GROUND_TOLERANCE_STUDS then
		return nil, delta
	end
	return y, delta
end

-- BUILDS THE SET, destroying and rebuilding the folder (the `Body.OUTFIT_NAME` discipline), so the
-- folder holds exactly `#posts + 1` parts at all times and never twenty.
--
-- `standX` is where the drive is aiming its waves (`ForestTest.hunterStandX()`), and it is passed in
-- rather than read here because the beater start is derived from it and this module decides nothing.
-- `layout` IS THE SECOND, REQUIRED PARAMETER (task 179), and required on purpose: an un-updated
-- caller then errors on `layout.centre` instead of silently measuring the road's nine stands into a
-- drive that is being held on a five-stand ride 500 studs away.
-- `seats` IS THE FIFTH AND OPTIONAL PARAMETER (task 218): "where is this stand's deck, or nil". A
-- stand with a seat is measured ONCE, on clean ground, by the seat's own owner before this runs
-- (`ForestTest.Seats.ensure`, design section 9.3), and its post goes ON THE DECK -- which is exactly
-- what `Body.placementFor` needs and the whole reason `placementFor` needs no change at all.
function Markers.build(
	standX: number,
	layout: any,
	ground: ((number, number) -> number?)?,
	canopy: ((number, number) -> number?)?,
	seats: ((number) -> number?)?
): Set
	local groundReader = ground or defaultGround
	local canopyReader = canopy or defaultCanopy
	local seatSource = seats or defaultSeats

	Markers.clear()
	stats.reads += 1
	stats.refused = 0
	stats.lastMaxDelta = 0

	local folder: Folder? = nil
	local posts: { BasePart } = {}

	-- SORTED BY X ASCENDING, which `Match.Markers.read` guarantees too (`byX`): post n is stand n,
	-- always, so `ForestTest.standIndexFor` can name a stand by its index.
	-- WHERE A SEAT STANDS, collected as it goes. The LINE's own reading has to know (`seatCovers`
	-- below), and this loop is the one place that already asks the seat source.
	local seated: { Vector3 } = {}
	-- HOW MANY OF THE FIRST INDICES ARE THE MAIN LINE (design 6.2: main first, 1..7). With no
	-- `sides` every stand is on the line, so `linePosts` IS `posts` and nothing downstream moves.
	local mainCount = if layout.sides ~= nil then layout.sides.main.count else layout.standCount
	local linePosts: { BasePart } = {}
	for index = 1, layout.standCount do
		local stand = Data.standPosition(index, layout)
		local y, delta
		local deck = if seatSource ~= nil then seatSource(index) else nil
		if deck ~= nil then
			table.insert(seated, stand)
		end
		if deck ~= nil then
			-- A STAND WITH A HIGH SEAT IS NOT MEASURED HERE, AND THAT IS THE WHOLE OF THE CALL
			-- ORDER (design section 7.2). `Data.groundAt` asked from the sky would see the DECK
			-- 12.5 studs over the terrain, disagree with the terrain reader by far more than
			-- `GROUND_TOLERANCE_STUDS`, and refuse this stand -- `WAITING forest:stands (0 of n)`
			-- for ever. The seat's owner measured this column once, on clean ground, before any
			-- seat stood on it; the post goes ON THE DECK, which is what `Body.placementFor` reads.
			-- Nothing here contributes to `lastMaxDelta` or to `refused`: there was no reading to
			-- disagree about.
			y = deck
		else
			y, delta = Markers.groundFor(stand.X, stand.Z, groundReader, canopyReader)
		end
		if delta ~= nil then
			stats.lastMaxDelta = math.max(stats.lastMaxDelta, delta)
		end
		if y == nil then
			-- A REFUSED STAND IS A COUNTER AND A CONSOLE LINE, NOT A `missing` STRING: one branch
			-- hanging over the lane must not stop a playtest. All nine refused is a different
			-- answer, and it is `complete = false` below.
			stats.refused += 1
		else
			folder = folder or ensureFolder()
			local post = marker(
				string.format("Stand%d", index),
				Vector3.new(stand.X, y, stand.Z),
				Markers.POST_SIZE,
				folder :: Folder
			)
			table.insert(posts, post)
			if index <= mainCount then
				table.insert(linePosts, post)
			end
		end
	end
	stats.posts = #posts

	-- THE DRIVE LINE IS A TABLE, NOT A PART, because nothing in this world needs a line part: the
	-- weapon's safety arc reads the NORMAL only (`SafetyArc.isForbidden` is a dot product against
	-- `line.normal`), and the only reader of `line.position` is the Studio-only quick test, which is
	-- off and releases nothing here.
	--
	-- x = `layout.centre.X` is where the sine is exactly 0 -- and a straight layout (amplitude 0) has
	-- no sine at all, so for the edge and the ride it is exactly on the line by construction rather
	-- than by arithmetic. The normal is +Z -- the meaning `Match.Markers.read` gives the field: *"the part's -Z faces the
	-- drivers"*, i.e. its LookVector points at them. The beaters are north of every point of this
	-- road (the curve's tangent swings only +-23 degrees), so one plane is the right answer here and
	-- the design measures why (section 6.1).
	-- THE LINE'S OWN READING COUNTS TOWARD `lastMaxDelta` TOO (round 1 note): a disagreement over
	-- the line or over the beater pad can make `complete` false on its own, and a console number that
	-- folded in only the nine posts would be silent about exactly that.
	--
	-- ...AND THE LINE'S OWN POINT CAN BE UNDER A HIGH SEAT, WHICH WAS MEASURED AND NOT REASONED
	-- ABOUT (task 218). The line is read at `layout.centre.X`, and for a layout with an ODD stand
	-- count that x IS the middle stand's x -- `standX(middle)` is `centre.X + 0` -- and its z is the
	-- same `roadZ`. On the `edge` layout the middle stand is stand 3, stand 3 carries a seat, and
	-- the FIRST live run of this task came back `WAITING forest:line`: the canopy reader, asked from
	-- 600 studs up, hit the deck at 193.26 against the terrain's 179.89 -- a 13.37-stud disagreement
	-- against a tolerance of 1 -- so the line was refused and the drive could never start.
	--
	-- THE FIX IS THE TERRAIN READER ALONE, AND ONLY UNDER A SEAT. `Markers.lineGroundFor` asks
	-- `groundFor` as before everywhere else, and where the point lies inside a seat's footprint it
	-- takes the TERRAIN reading -- which by construction cannot see a deck, a canopy or a trunk. It
	-- is the same judgement `Markers.ringGroundFor` already makes for the stand ring, and it costs
	-- the canopy check only at the one point in the world we ourselves put a roof over.
	local lineY, lineDelta =
		Markers.lineGroundFor(layout.centre.X, Data.roadZ(layout.centre.X, layout), groundReader, canopyReader, seated)
	if lineDelta ~= nil then
		stats.lastMaxDelta = math.max(stats.lastMaxDelta, lineDelta)
	end
	local line = if lineY ~= nil
		then table.freeze({
			position = Vector3.new(layout.centre.X, lineY, Data.roadZ(layout.centre.X, layout)),
			normal = Vector3.zAxis,
		})
		else nil

	local flatStart = Data.beaterStart(standX, 0, layout)
	local startY, startDelta = Markers.groundFor(flatStart.X, flatStart.Z, groundReader, canopyReader)
	if startDelta ~= nil then
		stats.lastMaxDelta = math.max(stats.lastMaxDelta, startDelta)
	end
	local driverStart: BasePart? = nil
	if startY ~= nil then
		folder = folder or ensureFolder()
		driverStart =
			marker("BeaterStart", Vector3.new(flatStart.X, startY, flatStart.Z), Markers.START_SIZE, folder :: Folder)
	end

	local missing = {}
	if #posts == 0 then
		table.insert(missing, string.format("forest:stands (0 of %d)", layout.standCount))
	end
	-- NO MAIN-LINE POST IS NOT A LINE (task 327b round 3, round-2 note). On a cell `posts` can hold
	-- flank posts only, and `ForestTest.linePostsOf` would then hand `lineReferenceFor` an empty
	-- list, so the drive would measure every crossing against the line PLANE instead of the stands.
	if #linePosts == 0 then
		table.insert(missing, string.format("forest:line-posts (0 of %d)", #posts))
	end
	if line == nil then
		table.insert(missing, "forest:line")
	end
	if driverStart == nil then
		table.insert(missing, "forest:beater-start")
	end

	return table.freeze({
		layout = layout.name,
		posts = table.freeze(posts),
		linePosts = table.freeze(linePosts),
		line = line,
		lineParts = if line ~= nil then 1 else 0,
		driverStart = driverStart,
		-- EMPTY, DELIBERATELY, AND THE SET IS STILL `complete` (design section 4.1.4). `Markers.read`
		-- calls an empty spawn list missing; in this world the drive releases NOTHING
		-- (`BOARS_PER_DRIVE = 0`, the animals are `ForestTest`'s), so requiring a spawn marker would
		-- make the drive refuse to start over a thing it must never use.
		boarSpawns = table.freeze({}),
		spawnRadius = Data.REST.spreadStuds,
		-- ...AND SO IS THIS ONE: the forest tags no trunks (its trees are Studio content this repo
		-- did not write), and `Body.anchorFor` falls back to the posts -- so a punished hunter is
		-- roped to her own stand. `Markers.read` does not require trees either. The deviation from
		-- Karen's *"tied to a tree"* is named in the design (section 6.3) and is one line to change.
		trees = table.freeze({}),
		-- `#linePosts >= 1` IS PART OF IT, or the `missing` entry above would be a string nobody
		-- acts on: `Phase.waitingFor` reads `missing` only while `markersComplete` is false.
		complete = #posts >= 1 and #linePosts >= 1 and line ~= nil and driverStart ~= nil,
		missing = table.freeze(missing),
	})
end

return Markers
