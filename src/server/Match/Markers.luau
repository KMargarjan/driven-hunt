--!strict
-- Match.Markers: READ-ONLY. It reads the five DrivenHunt.* CollectionService tags and returns one
-- frozen table of posts, drive line, driver start, boar spawns and trees. It writes nothing,
-- anywhere, ever -- TestArena places and tags them, and the Milestone 2 map generator will place the
-- same tags without this system changing.
--
--   CollectionService https://create.roblox.com/docs/reference/engine/classes/CollectionService
--     GetTagged answers "give me every post" in one call, with no Workspace walk and no naming
--     convention. The page carries no caveats about replication or names, so what this module infers
--     about tags is inference, not documentation (docs/research/2026-09-25-drive.md source C).
--
-- A TAG IS A STRING WITH NO SCHEMA, so a typo yields an empty list and a silently dead rule. That is
-- what `missing` and `complete` are for: the match refuses to leave Waiting against an incomplete
-- map and the Hud says which tag produced nothing. TWO drive lines is also incomplete -- an
-- ambiguous line is worse than none, because the safety rule would use whichever the engine returned
-- first.
--
-- Design: docs/design/drive.md (sections 6.1, 6.2)
-- Note:   docs/research/2026-09-25-drive.md
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage:WaitForChild("Map"))

local Markers = {}

-- THE STRINGS LIVE IN THE CONTRACT (`src/shared/Map/init.luau`, Map.TAGS), not here: before Task 43
-- "DrivenHunt.ShooterPost" was written out in TestArena, in this file and in the map generator --
-- three copies of one fact, where a typo yields an empty list and a silently dead rule. The key names
-- stay this module's own, because they are what the drive calls the things it reads.
Markers.TAGS = table.freeze({
	post = Map.TAGS.shooterPost,
	line = Map.TAGS.driveLine,
	driverStart = Map.TAGS.driverStart,
	boarSpawn = Map.TAGS.boarSpawn,
	tree = Map.TAGS.tree,
})

export type DriveLine = { position: Vector3, normal: Vector3 }

export type MarkerSet = {
	posts: { BasePart },
	line: DriveLine?,
	lineParts: number,
	driverStart: BasePart?,
	boarSpawns: { Vector3 },
	trees: { BasePart },
	complete: boolean,
	missing: { string },
}

local function taggedParts(service, tag: string): { BasePart }
	local out = {}
	for _, instance in ipairs(service:GetTagged(tag)) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(game) then
			table.insert(out, instance)
		end
	end
	return out
end

-- Sorted by X, so post 1 is always the same post and shooter 1 always stands in the same place.
local function byX(parts: { BasePart }): { BasePart }
	local sorted = table.clone(parts)
	table.sort(sorted, function(a, b)
		if a.Position.X ~= b.Position.X then
			return a.Position.X < b.Position.X
		end
		return a.Name < b.Name
	end)
	return sorted
end

function Markers.read(service: any?): MarkerSet
	local collection = service or CollectionService
	local posts = byX(taggedParts(collection, Markers.TAGS.post))
	local lines = taggedParts(collection, Markers.TAGS.line)
	local starts = taggedParts(collection, Markers.TAGS.driverStart)
	local spawnParts = byX(taggedParts(collection, Markers.TAGS.boarSpawn))
	local trees = taggedParts(collection, Markers.TAGS.tree)

	local missing = {}
	if #posts == 0 then
		table.insert(missing, Markers.TAGS.post)
	end
	if #lines ~= 1 then
		table.insert(missing, string.format("%s (%d found, want 1)", Markers.TAGS.line, #lines))
	end
	if #starts == 0 then
		table.insert(missing, Markers.TAGS.driverStart)
	end
	if #spawnParts == 0 then
		table.insert(missing, Markers.TAGS.boarSpawn)
	end

	local boarSpawns = {}
	for _, part in ipairs(spawnParts) do
		table.insert(boarSpawns, part.Position)
	end

	local line: DriveLine? = nil
	if #lines == 1 then
		-- The part's -Z faces the drivers, which is the meaning the weapon's SafetyArc gives the
		-- field (docs/design/shotgun.md section 5.1). test_arena.spec asserts the direction, because
		-- a line pointing the wrong way makes the safety rule fire on exactly the wrong shots.
		line = table.freeze({ position = lines[1].Position, normal = lines[1].CFrame.LookVector })
	end

	return table.freeze({
		posts = table.freeze(posts),
		line = line,
		lineParts = #lines,
		driverStart = starts[1],
		boarSpawns = table.freeze(boarSpawns),
		trees = table.freeze(trees),
		complete = #missing == 0,
		missing = table.freeze(missing),
	})
end

return Markers
