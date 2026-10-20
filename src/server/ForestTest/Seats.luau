--!strict
-- ForestTest.Seats: THE ONE WRITER OF `Workspace.HighSeats`, and nothing else writes a seat.
--
-- Task 218. KAREN, 2026-10-10: *"maybe will add towers where they can stand"*. `ReplicatedStorage`'s
-- `HighSeats` says WHAT A SEAT IS and WHICH STANDS CARRY ONE, as pure arithmetic; this module
-- measures the ground under five footprint points and builds the seventeen parts. The split is the
-- one `Places` / `src/server/Places` already makes, and for the reason
-- `docs/research/2026-10-17-forest-trees-on-the-ground.md` gives: when the arithmetic and the
-- measuring were one lump, *"neither could be checked alone"*.
--
-- IT IS LEVEL-TRIGGERED, NOT EDGE-TRIGGERED, and that is the whole of the call order. `Seats.ensure`
-- is called from `ForestTestBoot`'s ONE `world.markers` closure -- which `Match` calls once a second
-- while `Waiting` and once on entering `Assigning` -- and it decides from the folder's own `Layout`
-- attribute whether anything needs doing. A rotation therefore cannot leave the road's seats
-- standing in the ride, and the proof is structural rather than a handler somebody has to remember
-- to connect. `Weapon.refreshArming` and `Horn.refreshCarry` are the same discipline, written down
-- there as *"every edge-triggered grant in this repo has been measured missing one"*.
--
-- THE ORDER INSIDE THE CLOSURE IS LOAD-BEARING (design section 9.3): `Seats.ensure` runs BEFORE
-- `Markers.build`, so the seats a stand may have exist before the markers are placed, and
-- `Markers.build` then asks `Seats.deckTopY` for a seat stand instead of asking the two ground
-- readers -- which, from the sky, would see the deck 12.5 studs over the terrain, disagree with the
-- terrain reader by more than `Markers.GROUND_TOLERANCE_STUDS` and REFUSE the stand for ever.
--
-- AND THE SEAT CANNOT MEASURE ITSELF. Every ground reading here starts `READ_ABOVE_TERRAIN_STUDS`
-- above the TERRAIN's own answer, never at the sky: a downward ray can only hit what is below its
-- origin (`ForestTest.groundAt`'s header, task 192 round 2), and a deck 12.5 studs up is above an
-- origin 2 studs up. That is lesson L-025 written as a rule instead of as care.
--
-- Pattern: THE WORLD PLACES THE ENTITIES THE GAME MODE QUERIES, the same one `ForestTest.Markers`
-- states (Valve's `info_player_*`, Unreal's `PlayerStart`), with the same worst property removed: a
-- seat that cannot be measured is a COUNTED REFUSAL and a console line, never a silent guess and
-- never a `missing` string that stops a playtest.
--
-- IT RUNS ONLY IN THE FOREST TEST PLACE. `ForestTestBoot` returns early anywhere else, so the DEV
-- place -- where the harness runs -- never sees the folder. `Workspace` is not Rojo-owned and the
-- harness compares the EDIT-mode DataModel, so a run-time Part cannot dirty a run: the property
-- `Workspace.ForestMarkers`, `DriveMarkers` and `Boars` already have.
--
-- Design: docs/design/high-seats.md (sections 5.1, 9.2, 9.3)
-- Note:   docs/research/2026-10-20-high-seats.md
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
local Plan = require(ReplicatedStorage:WaitForChild("HighSeats"))

local Seats = {}

Seats.FOLDER_NAME = "HighSeats"
-- Stamped on the folder LAST, so a half-built folder is rebuilt rather than trusted.
Seats.LAYOUT_ATTRIBUTE = "Layout"

-- HOW FAR ABOVE THE TERRAIN A GROUND READ STARTS. Two studs: enough to clear the voxel surface the
-- terrain reader itself returns, and far below any deck.
Seats.READ_ABOVE_TERRAIN_STUDS = 2

-- HOW FAR THE TWO READINGS MAY DISAGREE before a seat is refused. `Markers.GROUND_TOLERANCE_STUDS`'
-- own number, kept in step by `high_seats.spec` rather than by two constants agreeing: a seat and a
-- stand must accept exactly the same ground.
Seats.GROUND_TOLERANCE_STUDS = 1

-- THE TWO READINGS, INJECTED BY THE PARENT AT LOAD TIME (`ForestTest`'s last lines). A child module
-- cannot require its parent -- `Markers.setReaders`' own stated reason -- and a third copy of the
-- two rays would be the second answer to "where is the ground" this project is named after.
local defaultTerrain: ((number, number) -> number?)? = nil
local defaultGround: ((number, number, number?) -> number?)? = nil

function Seats.setReaders(terrain: ((number, number) -> number?)?, ground: ((number, number, number?) -> number?)?)
	defaultTerrain, defaultGround = terrain, ground
end

local stats = {
	built = 0,
	refused = 0,
	reads = 0,
	worstFootGapStuds = 0,
	worstSpreadStuds = 0,
}
local refusals: { string } = {}
local lastLayout: string? = nil

-- What the last build measured. The console prints it: a tool that requires this module over
-- StudioMCP gets a sandboxed copy with empty state (measured, task 122), so the server's own print
-- is the only honest channel -- `Markers.stats`' own note.
function Seats.stats()
	return table.clone(stats)
end

function Seats.folder(): Folder?
	local existing = Workspace:FindFirstChild(Seats.FOLDER_NAME)
	return if existing and existing:IsA("Folder") then existing :: Folder else nil
end

function Seats.seatName(standIndex: number): string
	return string.format("Seat%d", standIndex)
end

-- THE ONE DESTROYER, so "the folder holds exactly the seats this layout asks for" is structural
-- rather than a cleanup path -- `Markers.clear`'s own rule.
function Seats.clear()
	local folder = Seats.folder()
	if folder then
		folder:Destroy()
	end
	lastLayout = nil
end

-- WHERE THIS STAND'S DECK IS, read off the `Deck` part this module built; nil for a stand with no
-- seat, and nil in every world that has none.
--
-- THE FOLDER IS THE STATE. There is no remembered table of deck heights, and that is deliberate: a
-- second copy of a fact the world already holds can go stale against it (a destroyed seat, a layout
-- promoted twice), and an Instance property cannot. `Weapon.heldId`'s discipline -- *"derived, never
-- stored by anybody else, so the two cannot disagree"*.
function Seats.deckTopY(standIndex: number): number?
	local folder = Seats.folder()
	if folder == nil then
		return nil
	end
	local seat = folder:FindFirstChild(Seats.seatName(standIndex))
	if seat == nil then
		return nil
	end
	local deck = seat:FindFirstChild("Deck")
	if deck == nil or not deck:IsA("BasePart") then
		return nil
	end
	return (deck :: BasePart).Position.Y + (deck :: BasePart).Size.Y / 2
end

-- WHERE THE GROUND IS UNDER ONE FOOTPRINT POINT, or nil. The terrain first -- it CANNOT hit a deck,
-- a canopy, a trunk or a body, by construction (`ForestTest.terrainYAt` includes `Workspace.Terrain`
-- and nothing else) -- and then the world's own reader asked FROM JUST ABOVE IT, so the two answer
-- about the same column and neither can see anything overhead.
--
-- A disagreement is a REFUSAL and not a number to average: it is evidence that this is not the
-- ground we think it is, which is `Markers.groundFor`'s own rule and the same tolerance.
function Seats.footGroundAt(x: number, z: number, terrain, ground): number?
	local terrainReader = terrain or defaultTerrain
	local groundReader = ground or defaultGround
	local t = if terrainReader then terrainReader(x, z) else nil
	if type(t) ~= "number" then
		return nil
	end
	local g = if groundReader then groundReader(x, z, (t :: number) + Seats.READ_ABOVE_TERRAIN_STUDS) else nil
	if type(g) ~= "number" then
		return nil
	end
	if math.abs((g :: number) - (t :: number)) > Seats.GROUND_TOLERANCE_STUDS then
		return nil
	end
	return g
end

-- One part, from one `HighSeats.Piece`. The class is the plan's -- a `TrussPart` is what the
-- Humanoid climbs -- and every flag comes from the plan rather than from a default here, so the
-- "every piece collides and every piece is queryable" rule lives in exactly one place.
local function build(spec: any, parent: Instance): BasePart
	local part = Instance.new(spec.class) :: any
	part.Name = spec.name
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Anchored = true
	part.CanCollide = spec.canCollide
	part.CanQuery = spec.canQuery
	part.CanTouch = false
	part.CastShadow = spec.castShadow
	part.Color = spec.color
	part.Material = spec.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part :: BasePart
end

-- HOW FAR THE WORST FOOT IS FROM ITS OWN GROUND, as a signed number: positive is a bottom face
-- ABOVE the ground it was measured at (floating, which rule E forbids outright), negative is sunk.
-- Read off the PARTS that were built, not off the plan, so the claim is about what Karen sees.
local function footGapOf(seat: Instance, grounds: { number? }): number
	local worst = -math.huge
	local samples = Plan.footprint()
	for index = 1, 4 do
		local leg = seat:FindFirstChild(string.format("Leg%d", index))
		local ground = grounds[index]
		if leg and leg:IsA("BasePart") and type(ground) == "number" then
			local bottom = (leg :: BasePart).Position.Y - (leg :: BasePart).Size.Y / 2
			worst = math.max(worst, bottom - (ground :: number))
		end
	end
	local ladder = seat:FindFirstChild("Ladder")
	local ladderGround = grounds[#samples]
	if ladder and ladder:IsA("BasePart") and type(ladderGround) == "number" then
		local bottom = (ladder :: BasePart).Position.Y - (ladder :: BasePart).Size.Y / 2
		worst = math.max(worst, bottom - (ladderGround :: number))
	end
	return if worst == -math.huge then 0 else worst
end

-- EVERY SEAT THIS LAYOUT ASKS FOR, STANDING. Returns how many there are.
--
-- LEVEL-TRIGGERED: a folder already stamped with this layout and holding the right number of seats
-- is left exactly alone -- no ray is cast and nothing is written -- so `Match`'s once-a-second
-- `Waiting` read costs a `FindFirstChild`, an attribute read and a child count. Any other state is
-- destroyed and rebuilt, which is the `Markers.build` / `Body.OUTFIT_NAME` discipline: there is one
-- way for the world to become right, and it does not depend on what it was before.
function Seats.ensure(layout: any, terrain: any?, ground: any?): number
	local wanted = Plan.standsFor(layout.name)
	local folder = Seats.folder()
	if folder ~= nil and folder:GetAttribute(Seats.LAYOUT_ATTRIBUTE) == layout.name then
		local standing = 0
		for _, child in ipairs(folder:GetChildren()) do
			if string.match(child.Name, "^Seat%d+$") then
				standing += 1
			end
		end
		-- The refused seats of this layout are counted into the target, so a layout one of whose
		-- stands cannot be measured does not rebuild itself once a second for ever.
		if standing == #wanted - stats.refused or standing == #wanted then
			return standing
		end
	end

	Seats.clear()
	stats.reads += 1
	stats.built = 0
	stats.refused = 0
	stats.worstFootGapStuds = -math.huge
	stats.worstSpreadStuds = 0
	refusals = {}
	lastLayout = layout.name

	if #wanted == 0 then
		return 0
	end

	local made: Folder? = nil
	local samples = Plan.footprint()
	for _, index in ipairs(wanted) do
		if index >= 1 and index <= layout.standCount then
			local stand = Data.standPosition(index, layout)
			local grounds: { number? } = {}
			for sample, offset in ipairs(samples) do
				grounds[sample] = Seats.footGroundAt(stand.X + offset.dx, stand.Z + offset.dz, terrain, ground)
			end
			local pieces, reason = Plan.plan(stand, grounds)
			if pieces == nil then
				stats.refused += 1
				table.insert(refusals, string.format("%s/%d %s", layout.name, index, tostring(reason)))
			else
				if made == nil then
					local created = Instance.new("Folder")
					created.Name = Seats.FOLDER_NAME
					created.Parent = Workspace
					made = created
				end
				local seat = Instance.new("Folder")
				seat.Name = Seats.seatName(index)
				seat.Parent = made :: Folder
				for _, spec in ipairs(pieces :: { any }) do
					build(spec, seat)
				end
				stats.built += 1
				stats.worstFootGapStuds = math.max(stats.worstFootGapStuds, footGapOf(seat, grounds))
				local spread = Plan.spreadOf(grounds)
				if type(spread) == "number" then
					stats.worstSpreadStuds = math.max(stats.worstSpreadStuds, spread :: number)
				end
			end
		else
			stats.refused += 1
			table.insert(refusals, string.format("%s/%d not a stand of this layout", layout.name, index))
		end
	end
	if stats.worstFootGapStuds == -math.huge then
		stats.worstFootGapStuds = 0
	end
	-- STAMPED LAST, so a build that threw half way leaves a folder this function will rebuild.
	if made ~= nil then
		(made :: Folder):SetAttribute(Seats.LAYOUT_ATTRIBUTE, layout.name)
	end
	return stats.built
end

-- THE ONE LINE THE BOOT PRINTS. This module never prints: the composition root says when, exactly as
-- `Markers.stats` and the boot's own `markers:` line already divide it.
--
-- IT NAMES THE RELAXED LAYOUT OUT LOUD. Where no stand on a line satisfies the relief test, design
-- section 6.2 rule 4 takes its best stand anyway and the platform rule is defeatable at the top of a
-- jump from the high side of that circle. That is a real, accepted hole, and a hole nobody is told
-- about is the thing this repo measures rather than assumes.
function Seats.takeLine(): string?
	if lastLayout == nil then
		return nil
	end
	local line = string.format(
		"[seats] %s: %d built, %d refused, worst foot gap %+.2f studs, worst spread %.2f studs",
		tostring(lastLayout),
		stats.built,
		stats.refused,
		stats.worstFootGapStuds,
		stats.worstSpreadStuds
	)
	if (Plan.RELIEF_RELAXED :: any)[lastLayout] then
		line = line
			.. string.format(
				" | RELIEF RELAXED on %s: no stand there rolls less than %.1f studs inside its circle, so the platform rule is defeatable at a jump apex",
				tostring(lastLayout),
				Plan.JUMP_RELIEF_STUDS
			)
	end
	for _, refusal in ipairs(refusals) do
		line = line .. "\n[seats] refused " .. refusal
	end
	return line
end

return Seats
