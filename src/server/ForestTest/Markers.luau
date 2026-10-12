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
	posts: { BasePart },
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

local stats = { posts = 0, refused = 0, reads = 0, lastMaxDelta = 0, rings = 0, lastRingSegments = 0 }

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
-- WHY TWENTY BOXES AND NOT ONE PART: there is no ring primitive. A Cylinder is a disc, a torus needs
-- a mesh (nothing is uploaded for this), and a decal needs an image. Twenty chords of a 12-stud
-- circle are 3.8 studs each and read as a circle from standing height; each one is placed on its own
-- ground reading, so the ring follows the lane instead of floating over it.
Markers.RING_PREFIX = "StandRing"

Markers.RING = {
	-- Twenty chords: the gap between a chord's middle and the true circle is r*(1-cos(pi/20)) =
	-- 0.15 studs at r=12, which is less than the ring's own thickness, so the shape does not read as
	-- a polygon.
	SEGMENTS = 20,
	THICKNESS_STUDS = 0.5,
	HEIGHT_STUDS = 0.12,
	-- Just clear of the ground, so z-fighting cannot make it flicker as the camera moves.
	LIFT_STUDS = 0.08,
	-- SUBTLE, which is the dispatch's word: a line you notice when you look down and not a fence.
	TRANSPARENCY = 0.45,
	-- Neon so it reads in the wood's shade without a light. A muted hunting-orange, the colour this
	-- game already uses for "this is yours" (the beater's vest, the hunter's cap).
	COLOR = Color3.fromRGB(235, 150, 60),
}

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
	ground: ((number, number) -> number?)?,
	canopy: ((number, number) -> number?)?
): number
	local groundReader = ground or defaultGround
	local canopyReader = canopy or defaultCanopy
	Markers.clearRing(standIndex)
	if radiusStuds <= 0 then
		return 0
	end
	local home = Data.standPosition(standIndex)
	local config = Markers.RING
	local step = 2 * math.pi / config.SEGMENTS
	-- The chord between two adjacent points ON the circle, so consecutive segments share an endpoint
	-- exactly and the ring cannot gap however `SEGMENTS` is changed (`Horn.pieces`' own rule).
	local chord = 2 * radiusStuds * math.sin(step / 2)
	local folder: Folder? = nil
	local placed = 0
	for index = 1, config.SEGMENTS do
		local a = (index - 1) * step
		local b = index * step
		local from = Vector2.new(home.X + math.cos(a) * radiusStuds, home.Z + math.sin(a) * radiusStuds)
		local to = Vector2.new(home.X + math.cos(b) * radiusStuds, home.Z + math.sin(b) * radiusStuds)
		local midX, midZ = (from.X + to.X) / 2, (from.Y + to.Y) / 2
		local y = Markers.groundFor(midX, midZ, groundReader, canopyReader)
		if y ~= nil then
			if folder == nil then
				local made = Instance.new("Folder")
				made.Name = Markers.ringName(standIndex)
				made.Parent = ensureFolder()
				folder = made
			end
			local part = Instance.new("Part")
			part.Name = string.format("Seg%d", index)
			part.Size = Vector3.new(chord, config.HEIGHT_STUDS, config.THICKNESS_STUDS)
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
			-- Lying along the chord: the box's own X is its length, so the frame looks along the
			-- chord and then turns a quarter turn, exactly as `Horn.pieces` lays its tube sections.
			local centre = Vector3.new(midX, (y :: number) + config.LIFT_STUDS, midZ)
			local along = Vector3.new(to.X - from.X, 0, to.Y - from.Y)
			part.CFrame = CFrame.lookAt(centre, centre + along.Unit, Vector3.yAxis) * CFrame.Angles(0, math.pi / 2, 0)
			part.Parent = folder
			placed += 1
		end
	end
	stats.rings += 1
	stats.lastRingSegments = placed
	return placed
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
function Markers.build(
	standX: number,
	ground: ((number, number) -> number?)?,
	canopy: ((number, number) -> number?)?
): Set
	local groundReader = ground or defaultGround
	local canopyReader = canopy or defaultCanopy

	Markers.clear()
	stats.reads += 1
	stats.refused = 0
	stats.lastMaxDelta = 0

	local folder: Folder? = nil
	local posts: { BasePart } = {}

	-- SORTED BY X ASCENDING, which `Match.Markers.read` guarantees too (`byX`): post n is stand n,
	-- always, so `ForestTest.standIndexFor` can name a stand by its index.
	for index = 1, Data.STAND_COUNT do
		local stand = Data.standPosition(index)
		local y, delta = Markers.groundFor(stand.X, stand.Z, groundReader, canopyReader)
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
			table.insert(
				posts,
				marker(
					string.format("Stand%d", index),
					Vector3.new(stand.X, y, stand.Z),
					Markers.POST_SIZE,
					folder :: Folder
				)
			)
		end
	end
	stats.posts = #posts

	-- THE DRIVE LINE IS A TABLE, NOT A PART, because nothing in this world needs a line part: the
	-- weapon's safety arc reads the NORMAL only (`SafetyArc.isForbidden` is a dot product against
	-- `line.normal`), and the only reader of `line.position` is the Studio-only quick test, which is
	-- off and releases nothing here.
	--
	-- x = CENTRE.X is where the road's sine is exactly 0, so this position is ON the road, and the
	-- normal is +Z -- the meaning `Match.Markers.read` gives the field: *"the part's -Z faces the
	-- drivers"*, i.e. its LookVector points at them. The beaters are north of every point of this
	-- road (the curve's tangent swings only +-23 degrees), so one plane is the right answer here and
	-- the design measures why (section 6.1).
	-- THE LINE'S OWN READING COUNTS TOWARD `lastMaxDelta` TOO (round 1 note): a disagreement over
	-- the line or over the beater pad can make `complete` false on its own, and a console number that
	-- folded in only the nine posts would be silent about exactly that.
	local lineY, lineDelta = Markers.groundFor(Data.CENTRE.X, Data.roadZ(Data.CENTRE.X), groundReader, canopyReader)
	if lineDelta ~= nil then
		stats.lastMaxDelta = math.max(stats.lastMaxDelta, lineDelta)
	end
	local line = if lineY ~= nil
		then table.freeze({
			position = Vector3.new(Data.CENTRE.X, lineY, Data.roadZ(Data.CENTRE.X)),
			normal = Vector3.zAxis,
		})
		else nil

	local flatStart = Data.beaterStart(standX, 0)
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
		table.insert(missing, string.format("forest:stands (0 of %d)", Data.STAND_COUNT))
	end
	if line == nil then
		table.insert(missing, "forest:line")
	end
	if driverStart == nil then
		table.insert(missing, "forest:beater-start")
	end

	return table.freeze({
		posts = table.freeze(posts),
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
		complete = #posts >= 1 and line ~= nil and driverStart ~= nil,
		missing = table.freeze(missing),
	})
end

return Markers
