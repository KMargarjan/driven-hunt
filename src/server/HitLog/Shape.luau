--!strict
-- HitLog.Shape: the ARITHMETIC of the hit record. Pure -- no Instance, no clock, no remote, no
-- service -- so every rule below is drivable by a spec with no world, no boar and no gun.
--
-- It is the same division `Boar.Brain`/`Boar.Body` and `Match.Phase`/`Match` already use: the decisions
-- live where they can be tested, and the module that owns the state does the talking.
--
-- Design: docs/design/drive-report.md (sections 6.2, 6.3, 6.5, 7)
local Report = require(game:GetService("ReplicatedStorage"):WaitForChild("Report"))

local Shape = {}

-- WHERE A SHOT LANDED, IN THE ANIMAL'S OWN FRAME. The one function that makes the silhouette
-- possible, and the reason the record is worth keeping at all.
--
-- `cframe` and `size` are the TRUNK's; `impact` is the world point. Returns the dot in a unit square
-- over the animal's side, plus which flank it hit.
--
--   u = 0 at the NOSE, 1 at the TAIL. "A Part's LookVector is its -Z" (`Boar.CONFIG.BODY_SIZE`), so
--       -Z is the front and `f.Z + 0.5` runs front-to-back.
--   v = 0 at the BACK, 1 at the BELLY, because screen y grows downward and the panel draws it that way.
--   side = -1 or 1, which flank the pellet came in on.
--
-- IT DIVIDES BY THE PART'S OWN SIZE, SO IT KNOWS NOTHING ABOUT BOARS. A cub's trunk is the male's
-- scaled by `geometry.clipScale`, and a hit high on a cub's shoulder has to land at the same (u, v)
-- as the same hit on a male -- which it does, because the only thing this reads is the box it was
-- handed. `HitLog` therefore requires neither `Boar` nor its config.
--
-- THE CLAMP IS NOT TIDINESS. Zone parts stand `PROTRUSION` studs proud of the trunk by design, so a
-- surface impact can be a few hundredths outside the box; a nose shot should read u = 0 and not
-- -0.01.
function Shape.dot(cframe: CFrame, size: Vector3, impact: Vector3): (number, number, number)
	local local_ = cframe:PointToObjectSpace(impact)
	-- Component by component: `Vector3 / Vector3` is not a thing, and dividing by a scalar would make
	-- the answer depend on which axis happened to be longest.
	local fx = if size.X > 1e-6 then local_.X / size.X else 0
	local fy = if size.Y > 1e-6 then local_.Y / size.Y else 0
	local fz = if size.Z > 1e-6 then local_.Z / size.Z else 0
	local u = math.clamp(fz + 0.5, 0, 1)
	local v = math.clamp(0.5 - fy, 0, 1)
	local side = if fx < 0 then -1 else 1
	return u, v, side
end

-- ONE ZONE BOX, PROJECTED INTO THE SILHOUETTE'S UNIT SQUARE. The same mapping `Shape.dot` uses, run
-- over a BOX instead of a point, so the rectangles the panel draws and the dots it puts on them come
-- out of one piece of arithmetic and cannot drift apart.
--
-- `size` and `offset` are the zone part's, in the trunk's frame (`Boar.CONFIG.ZONES[zone]`); `body` is
-- the trunk's own size. Pure, and it knows nothing about boars for the same reason `dot` does not.
--
-- `tests/server/report_silhouette.spec.luau` runs this over `Boar.CONFIG.ZONES` and compares the
-- answer with the constants in `Report.CONFIG.SILHOUETTE`, so a zone box that moves fails the harness
-- instead of quietly mispainting the report.
function Shape.rectOf(size: Vector3, offset: Vector3, body: Vector3): { u0: number, u1: number, v0: number, v1: number }
	local halfLength = if body.Z > 1e-6 then body.Z / 2 else 0
	local halfHeight = if body.Y > 1e-6 then body.Y / 2 else 0
	local function u(z: number): number
		return if body.Z > 1e-6 then math.clamp((z + halfLength) / body.Z, 0, 1) else 0
	end
	-- v grows DOWNWARD, so the box's TOP (+y) is v0 and its bottom is v1.
	local function v(y: number): number
		return if body.Y > 1e-6 then math.clamp((halfHeight - y) / body.Y, 0, 1) else 0
	end
	return {
		u0 = u(offset.Z - size.Z / 2),
		u1 = u(offset.Z + size.Z / 2),
		v0 = v(offset.Y + size.Y / 2),
		v1 = v(offset.Y - size.Y / 2),
	}
end

-- WHICH DOT WAS THE KILLING ONE. `Wound.killRecord` carries the mortal wound's `zone` and `at`, and
-- the dots carry the same two from the same reports -- so the join is on the pair and not on an
-- identity nothing preserved.
--
-- Returns the index, or nil. A caller that gets nil falls back to the last dot by that shooter and
-- counts the miss (`stats.unmatchedFatal`), because a kill whose dot nobody can find is a number in
-- the harness report rather than a feeling in a playtest -- the idiom `tallylessHits` and
-- `unknownZoneHits` already set.
function Shape.fatalDot(dots, zone: string?, at: number?, shooterUserId: number?): number?
	if zone ~= nil and at ~= nil then
		for index, dot in ipairs(dots) do
			if dot.zone == zone and math.abs(dot.at - at) < 1e-6 then
				return index
			end
		end
	end
	if shooterUserId == nil then
		return nil
	end
	local last = nil
	for index, dot in ipairs(dots) do
		if dot.userId == shooterUserId then
			last = index
		end
	end
	return last
end

-- ONE HUNTER'S ROW IN THE LIST, from one drive's animals. Pure: the drive record in, the rows out,
-- sorted, capped.
--
-- WHOSE KILL IS WHOSE. `kills` counts animals that went DOWN with this hunter named as the killer;
-- `lost` counts animals this hunter HIT that were still "wounded" when the drive closed -- which is
-- Karen's *"wounded-lost"* and needs no third signal, because "wounded" is simply the state a record
-- starts in and only a `Downed` ever leaves.
--
-- A hit on an animal somebody else killed stays in the record under its own shooter's dots, so two
-- hunters can both have a row for one animal and the detail view says whose dot is whose.
function Shape.hunterRows(drive, cap: number): ({ Report.HunterRow }, boolean)
	local byUser: { [number]: Report.HunterRow } = {}
	local order: { number } = {}

	local function rowFor(userId: number, name: string?): Report.HunterRow
		local row = byUser[userId]
		if row == nil then
			row = {
				userId = userId,
				name = name or tostring(userId),
				kills = 0,
				lost = 0,
				hits = 0,
				animals = 0,
				-- ALL FOUR KEYS, ALWAYS, AS NUMBERS: a dictionary with a hole does not survive the
				-- wire faithfully (`Drive`'s own rule for `ScoreRow`).
				byKind = { male = 0, female = 0, cub = 0, unknown = 0 },
			}
			byUser[userId] = row
			table.insert(order, userId)
		elseif name ~= nil then
			row.name = name
		end
		return row
	end

	for _, id in ipairs(drive.order) do
		local animal = drive.animals[id]
		if animal ~= nil then
			local touched: { [number]: boolean } = {}
			for _, dot in ipairs(animal.dots) do
				if dot.userId ~= nil then
					local row = rowFor(dot.userId, dot.name)
					row.hits += 1
					if not touched[dot.userId] then
						touched[dot.userId] = true
						row.animals += 1
					end
				end
			end
			if animal.result == "down" and animal.killedByUserId ~= nil then
				local row = rowFor(animal.killedByUserId, nil)
				row.kills += 1
				local kind = animal.kind
				if kind == "male" or kind == "female" or kind == "cub" then
					row.byKind[kind] += 1
				else
					row.byKind.unknown += 1
				end
			else
				for user in pairs(touched) do
					byUser[user].lost += 1
				end
			end
		end
	end

	local rows = {}
	for _, userId in ipairs(order) do
		table.insert(rows, byUser[userId])
	end
	-- Sorted by what Karen asked to compare -- kills first -- then by hits, then by id so the order is
	-- the same every time it is drawn.
	table.sort(rows, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		if a.hits ~= b.hits then
			return a.hits > b.hits
		end
		return a.userId < b.userId
	end)
	local truncated = #rows > cap
	while #rows > cap do
		table.remove(rows)
	end
	return rows, truncated
end

-- THE CLIENT'S THREE NUMBERS, RESOLVED AGAINST WHAT THE SERVER ACTUALLY HOLDS. It never errors, never
-- yields and never trusts a number: an unknown drive becomes the current one, a hunter with no row
-- becomes the list, a page outside 1..pages is clamped. That is the whole inbound surface.
function Shape.resolveRequest(request, driveNumbers: { number }, current: number): (number, number?, number)
	local wanted = if type(request) == "table" and type(request.drive) == "number" then request.drive else current
	local drive = current
	for _, number in ipairs(driveNumbers) do
		if number == wanted then
			drive = wanted
		end
	end
	local hunter = if type(request) == "table" and type(request.hunter) == "number" then request.hunter else nil
	local page = if type(request) == "table" and type(request.page) == "number" then math.floor(request.page) else 1
	if page < 1 then
		page = 1
	end
	return drive, hunter, page
end

return Shape
