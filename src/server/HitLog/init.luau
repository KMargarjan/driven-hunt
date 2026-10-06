--!strict
-- HitLog: THE ONE WRITER of "who hit what, where, and did it die" (CLAUDE.md rule 3).
--
-- Karen, 2026-10-05: *"we need to show when is killed logg or something similar / we need to indicate
-- a hit / and we need to show on the end what has been killed where was the hit / so after drive we
-- can see how much I killed compairing others and I can click on details or similar and see boars
-- where was the hit"*.
--
-- IT ADDS NO SOURCE OF TRUTH. It is fed by the two signals that already exist and already carry
-- everything but the dot:
--   `Weapon.HitReported` -- one report per (shot, target), already grouped: "nine pellets on one boar
--     are one report with pellets = 9, never nine reports" (`Weapon.Hits.group`).
--   `Boar.Runtime.Downed`  -- exactly once per animal: "the Brain reports `downed` on the tick it
--     enters DOWN and never again" (`src/server/Boar/init.luau`).
-- Both are wired at the composition root of each world, beside the lines that are already there, so
-- neither owner grows a reference to the other -- the direction the damage seam already runs in.
--
-- NO SECOND SCORE. `Match` keeps owning points, penalties and the roster; this owns PLACEMENT. In a
-- world with no `Match` (the Forest Test) the record stands alone and the panel simply has no points
-- column.
--
-- Design: docs/design/drive-report.md (sections 3, 6)
-- Note:   docs/research/2026-10-05-drive-report.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shape = require(script.Shape)

local HitLog = {}
HitLog.Shape = Shape

local CONFIG = Report.CONFIG

-- The drives this server still remembers, newest last. Two of them: the current one, and the previous
-- one -- because a drive closes, the panel opens, and in the DEV world the next drive begins while
-- the player is still reading it. Keeping one would blank the panel under her.
local drives: { any } = {}
local current: any = nil

local remotes = nil
local lastRequestAt: { [Player]: number } = {}

local stats = {
	hits = 0,
	downs = 0,
	-- A `Downed` whose id has no record. The join between the two signals is a MEASURED number and
	-- not a belief: this is the repo's own degradation idiom (`tallylessHits`, `unknownZoneHits`,
	-- `meshUpgradeFails`) -- a number in a report instead of a feeling in a playtest.
	unmatchedDowns = 0,
	-- A kill whose killing shot could not be matched to a dot, so the last dot by that shooter was
	-- marked instead.
	unmatchedFatal = 0,
	droppedDots = 0,
	droppedAnimals = 0,
	drivesOpened = 0,
	requestsDropped = 0,
}

local function channel()
	if remotes == nil then
		remotes = Report.remotes()
	end
	return remotes
end

-- EVERY `at` ON THE WIRE IS SECONDS SINCE THE DRIVE OPENED, never a server clock: an `os.clock` from
-- one machine means nothing on another.
local function sinceOpen(now: number): number
	if current == nil then
		return 0
	end
	return math.max(0, now - current.openedAt)
end

local function broadcast(event: Report.Event)
	channel().ReportEvent:FireAllClients(event)
end

-- ---------------------------------------------------------------- the drive window

-- Opening and closing is a COMPOSITION-ROOT job, because only the root knows which world it is in:
-- `MatchBoot` reads `Match.PhaseChanged`, `ForestTestBoot` latches on its own period index. Both
-- broadcast, so no client has to infer a drive boundary from a phase it may never be sent.
function HitLog.openDrive(number: number, now: number)
	if current ~= nil then
		HitLog.closeDrive(now)
	end
	current = {
		number = number,
		openedAt = now,
		closedAt = nil :: number?,
		animals = {},
		order = {},
		animalCount = 0,
		droppedAnimals = 0,
	}
	table.insert(drives, current)
	-- OLDER DRIVES GO WHOLE. A partial drive is a report with a hole in it, which is worse than no
	-- report: the player cannot tell which half they are looking at.
	while #drives > CONFIG.DRIVES_KEPT do
		table.remove(drives, 1)
	end
	stats.drivesOpened += 1
	broadcast({ kind = "driveOpened", drive = number, at = 0 })
end

-- Idempotent: a second call is a no-op, because a phase signal and a period latch can both fire for
-- the same boundary and neither should have to know about the other.
function HitLog.closeDrive(now: number)
	if current == nil or current.closedAt ~= nil then
		return
	end
	current.closedAt = now
	broadcast({ kind = "driveClosed", drive = current.number, at = sinceOpen(now) })
end

function HitLog.currentDrive()
	return current
end

function HitLog.stats()
	local out = table.clone(stats)
	out.drivesKept = #drives
	return out
end

-- Only for a spec and for a world that restarts: there is no DataStore and nothing persists.
function HitLog.clear()
	drives = {}
	current = nil
	lastRequestAt = {}
	for key in pairs(stats) do
		stats[key] = 0
	end
end

-- ---------------------------------------------------------------- the record

local function animalFor(id: string, kind: string?, now: number)
	local animal = current.animals[id]
	if animal ~= nil then
		if kind ~= nil then
			animal.kind = kind
		end
		return animal
	end
	animal = {
		id = id,
		kind = kind,
		firstAt = now,
		lastAt = now,
		dots = {},
		droppedDots = 0,
		hits = 0,
		-- "WOUNDED" IS WHERE A RECORD STARTS AND ONLY A `Downed` EVER LEAVES IT. An animal with hits
		-- and no `Downed` IS Karen's wounded-lost; it needs no third signal.
		result = "wounded",
	}
	current.animals[id] = animal
	table.insert(current.order, id)
	current.animalCount += 1
	while #current.order > CONFIG.ANIMALS_PER_DRIVE_KEPT do
		local oldest = table.remove(current.order, 1)
		current.animals[oldest] = nil
		current.droppedAnimals += 1
		stats.droppedAnimals += 1
	end
	return animal
end

-- ONE HIT. `report` is `Weapon.HitReported`'s, unchanged and unwrapped.
--
-- THE ONE GUARD ON WHAT IS RECORDED is that the target is a `BasePart`, because only animals carry
-- `Damageable == true` today (`Boar.Body.create`; `Weapon.Hits.targetOf` finds nothing else). If a
-- player or a prop ever becomes damageable, THIS is the line that needs a kind check.
function HitLog.recordHit(report, now: number?)
	if current == nil then
		return false
	end
	local part = report and report.target
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return false
	end
	-- THE DOT'S CLOCK IS THE SHOT'S OWN (task 124 round 2, the Reviewer's blocking finding). It used
	-- to be a fresh `os.clock()` taken on THIS side of the signal, while the wound the kill is joined
	-- to carries `report.at` from `Weapon.Hits.group` -- two different samples of the same instant,
	-- so `Shape.fatalDot`'s `|dot.at - at| < 1e-6` could never match and the X on the silhouette was
	-- always the shooter's LAST hit rather than the one that killed.
	local at = report.at or now or os.clock()
	-- THE ID IS THE PART'S NAME, and that is a fact with a grep behind it: `Body.create` sets
	-- `part.Name = id` and nothing in `Body.luau` ever reassigns it, and `Wound.killRecord` is called
	-- with the same `entry.id`. Keyed by the string and never by the Instance -- an Instance key pins
	-- a part that is about to be destroyed.
	local animal = animalFor(part.Name, part:GetAttribute("Kind") :: string?, at)
	local shooter = report.shooter
	local u, v, side = Shape.dot(part.CFrame, part.Size, report.position or part.Position)
	local dot = {
		userId = if shooter then shooter.UserId else nil,
		name = if shooter then shooter.Name else nil,
		zone = tostring(report.zone or "unknown"),
		u = u,
		v = v,
		side = side,
		distance = report.nearest or 0,
		pellets = report.pellets or 1,
		at = at,
		fatal = false,
	}
	table.insert(animal.dots, dot)
	animal.hits += 1
	animal.lastAt = at
	-- THE NEWEST IS DROPPED, NOT THE OLDEST: the first shots on an animal are the ones that tell the
	-- story of how it died, and a ninth pellet-group on the same carcass tells nobody anything.
	while #animal.dots > CONFIG.HITS_PER_ANIMAL do
		table.remove(animal.dots)
		animal.droppedDots += 1
		stats.droppedDots += 1
	end
	stats.hits += 1
	return true
end

-- ONE DEATH. `record` is `Wound.killRecord`'s, which already carries the kind, the killer, the
-- killing zone and distance -- so this marks the record down and says so to everybody.
function HitLog.recordDown(record, now: number?)
	if current == nil or type(record) ~= "table" then
		return false
	end
	local at = now or os.clock()
	local animal = current.animals[record.id]
	if animal == nil then
		-- A death with no hits on the books: the animal was hit before this drive opened, or its
		-- record was dropped by the cap. Counted rather than invented.
		stats.unmatchedDowns += 1
		return false
	end
	stats.downs += 1
	animal.result = "down"
	animal.downedAt = at
	animal.killedByUserId = record.killedByUserId
	animal.killingZone = record.killingZone
	animal.instant = record.instant
	if record.kind ~= nil then
		animal.kind = record.kind
	end
	-- THE MORTAL WOUND, NOT THE LAST ONE (task 124 round 2). `Wound` latches the mortal wound --
	-- "later pellets into a dying animal do not steal the kill" -- and `killRecord` already carries
	-- it as `record.at` and `record.killingZone`; `record.wounds[#record.wounds]` is simply the most
	-- recent pellet group, which on a carcass that was shot twice is the wrong one.
	local index = Shape.fatalDot(animal.dots, record.killingZone, record.at, record.killedByUserId)
	if index ~= nil then
		animal.dots[index].fatal = true
		-- ...AND THE MISS IS COUNTED WHERE IT HAPPENS. `fatalDot` falls back to the shooter's last
		-- dot, and the fallback used to be invisible from here: `unmatchedFatal` only rose when the
		-- killer had NO dot at all, so design section 12's "`unmatchedFatal == 0` after a live kill"
		-- measured nothing. It now rises whenever the join itself failed.
		if Shape.fatalDot(animal.dots, record.killingZone, record.at, nil) == nil then
			stats.unmatchedFatal += 1
		end
	else
		stats.unmatchedFatal += 1
	end

	-- THE KILL LINE, FOR EVERYBODY, OVER THIS SYSTEM'S OWN REMOTE IN BOTH WORLDS. It cannot go over
	-- `Match`'s feed: `Drive.remotes()` is documented as having no inbound remote and exactly two
	-- outbound ones (a client spec asserts the count), `Match.publishFeed` is the only writer of
	-- `MatchEvent`, and in the Forest Test `Match.start` is never called so nobody owns it there at
	-- all. One writer, one remote, one client path in both worlds.
	broadcast({
		kind = "kill",
		drive = current.number,
		userId = record.killedByUserId,
		name = record.killedByName,
		animalKind = animal.kind,
		zone = record.killingZone,
		distance = record.killingDistance,
		at = sinceOpen(at),
	})
	return true
end

-- ---------------------------------------------------------------- the panel's data

local function listPayload(drive): Report.ListPayload
	local rows, truncated = Shape.hunterRows(drive, CONFIG.HUNTER_ROWS)
	return {
		view = "list",
		drive = drive.number,
		openedAt = 0,
		seconds = math.max(0, (drive.closedAt or os.clock()) - drive.openedAt),
		closed = drive.closedAt ~= nil,
		rows = rows,
		animals = drive.animalCount,
		truncated = truncated,
	}
end

local function detailPayload(drive, userId: number, page: number): Report.DetailPayload
	local mine: { Report.AnimalRow } = {}
	local name = tostring(userId)
	for _, id in ipairs(drive.order) do
		local animal = drive.animals[id]
		local touched, best = false, nil
		if animal ~= nil then
			for _, dot in ipairs(animal.dots) do
				if dot.userId == userId then
					touched = true
					name = dot.name or name
					if best == nil or dot.fatal then
						best = dot
					end
				end
			end
		end
		if touched and animal ~= nil then
			local wire: { Report.WireDot } = {}
			for _, dot in ipairs(animal.dots) do
				table.insert(wire, {
					userId = dot.userId,
					name = dot.name,
					zone = dot.zone,
					u = dot.u,
					v = dot.v,
					side = dot.side,
					distance = dot.distance,
					pellets = dot.pellets,
					at = math.max(0, dot.at - drive.openedAt),
					fatal = dot.fatal,
				})
			end
			table.insert(mine, {
				id = animal.id,
				kind = animal.kind,
				result = animal.result,
				zone = tostring(animal.killingZone or (best and best.zone) or "unknown"),
				distance = (best and best.distance) or 0,
				hits = animal.hits,
				droppedHits = animal.droppedDots,
				at = math.max(0, animal.firstAt - drive.openedAt),
				dots = wire,
			})
		end
	end
	local per = CONFIG.ANIMALS_PER_PAGE
	local pages = math.max(1, math.ceil(#mine / per))
	page = math.clamp(page, 1, pages)
	local rows: { Report.AnimalRow } = {}
	for index = (page - 1) * per + 1, math.min(#mine, page * per) do
		table.insert(rows, mine[index])
	end
	return {
		view = "detail",
		drive = drive.number,
		userId = userId,
		name = name,
		page = page,
		pages = pages,
		rows = rows,
	}
end

local function driveByNumber(number: number)
	for _, drive in ipairs(drives) do
		if drive.number == number then
			return drive
		end
	end
	return current
end

-- THE ONLY INBOUND SURFACE: three optional numbers, resolved against what the server actually holds
-- and never trusted. A client cannot name an animal, cannot ask for a drive this server has dropped,
-- and cannot ask for more rows than the cap -- because the cap is the server's.
function HitLog.onRequest(player: Player, request)
	if current == nil then
		return
	end
	local now = os.clock()
	local last = lastRequestAt[player]
	if last ~= nil and now - last < CONFIG.REQUEST_MIN_INTERVAL then
		stats.requestsDropped += 1
		return
	end
	lastRequestAt[player] = now
	local numbers = {}
	for _, drive in ipairs(drives) do
		table.insert(numbers, drive.number)
	end
	local number, hunter, page = Shape.resolveRequest(request, numbers, current.number)
	local drive = driveByNumber(number)
	local payload: any
	if hunter ~= nil then
		payload = detailPayload(drive, hunter, page)
	else
		payload = listPayload(drive)
	end
	channel().ReportData:FireClient(player, payload)
end

local started = false

-- Wired by a composition root, once. It binds the inbound remote and forgets a player's throttle when
-- they leave; it opens no drive of its own, because which world this is and when a drive begins is
-- the root's fact and not this module's.
function HitLog.start()
	if started then
		return
	end
	started = true
	channel().ReportRequest.OnServerEvent:Connect(function(player, request)
		HitLog.onRequest(player, request)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
end

return HitLog
