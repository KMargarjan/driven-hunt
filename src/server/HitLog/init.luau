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
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
-- PURE DATA AND ONE PREDICATE (task 304): which folder the lobby range's own animals live in. The
-- range is scored by nothing (docs/design/shooting-range.md section 1), so a hit on one is not a row.
local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
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
-- THE LAST CARD THIS MODULE BUILT, so a spec can read what `recordHit` ACTUALLY sent rather than
-- rebuilding it beside the code and asserting on its own arithmetic (the Reviewer's note, round 1:
-- *"the `recordHit` call ... never reads the card `recordHit` actually built"*). One payload, no
-- history: it is a window onto the last call, not a second record.
local lastCard: Report.CardPayload? = nil

-- ---------------------------------------------------------------- the hit log (task 278)
--
-- **EVERY SERVER-CONFIRMED HIT, WHERE IT LANDED, READABLE BY A PROBE.** The dispatch, after Karen
-- tested live on 2026-10-26 and found the card's mark in empty space twice: *"This is how the
-- Director and Karen check each shot from now on."*
--
-- IT IS STUDIO ONLY AND IT IS NOT A FEATURE. `RunService:IsStudio()` gates both the `print` and the
-- attribute, so a published server writes nothing and costs nothing -- the same rule the test
-- runners already live by (`tools/studio_mcp.py`: "inert outside Studio"). It is an INSTRUMENT, and
-- an instrument that ships is a leak.
--
-- ONE ATTRIBUTE AND NOT TEN, for the reason `tools/pose.py`'s own override is one: a Roblox
-- attribute name cannot be indexed, so ten numbered attributes would be ten reads and ten places
-- for a stale one to survive. `DHLastHits` is the last `TRACE_KEEP` lines, newline-separated,
-- newest LAST -- so `tail` reads like a console.
--
-- `DHLastHits` AND NOT `DHFlag_*`: `tools/studio_mcp.py` owns that prefix and `test`/`test2` refuse
-- to start while one is set. This one is a reading, never an override, and nothing refuses it.
local TRACE_KEEP = 10
local trace: { string } = {}

local function traceOn(): boolean
	return RunService:IsStudio()
end

local function writeTrace(line: string)
	if not traceOn() then
		return
	end
	print("[hitlog] " .. line)
	table.insert(trace, line)
	while #trace > TRACE_KEEP do
		table.remove(trace, 1)
	end
	ServerStorage:SetAttribute("DHLastHits", table.concat(trace, "\n"))
end

-- What the probe reads back without going through the attribute, so a spec checks the ring and not
-- a round trip through Studio.
function HitLog.lastHits(): { string }
	return table.clone(trace)
end

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
	-- THE HIT CARD (task 198): how many went out, and how many hits were NOT worth one. A hit on
	-- something that is not an animal, or by nobody, is counted here rather than guessed at in a
	-- playtest -- the same idiom `unmatchedDowns` and `droppedDots` already set.
	cards = 0,
	cardlessHits = 0,
	cardFatals = 0,
	-- ...AND HOW MANY OF THEM WERE THE RANGE'S (task 304): a card with no row behind it, counted
	-- separately so "the range wrote nothing" is a reading and not a belief.
	rangeCards = 0,
	-- ...AND HOW MANY HITS WERE REFUSED A ROW FOR BEING THE RANGE'S (task 304).
	rangeHits = 0,
	-- HOW MANY LINES THE HIT LOG HAS WRITTEN THIS DRIVE (task 278). It is also the `#n` in the line
	-- itself, so the ring can be read for a gap: three clicks and two numbers means a shot that
	-- never reached the server, which is exactly the confusion this log exists to end.
	traced = 0,
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

-- THE FRAME THE REPORT'S POINTS ARE IN (task 308 bug 3). `Weapon.Rewind` reports a rewound impact
-- WHERE THE SHOOTER DREW THE ANIMAL and `Hits.group` carries that CFrame on the report, so dividing
-- the point down by the trunk's CFrame as read HERE -- flight time plus replication later -- put a
-- nose shot on the rump at a walk and in the white space behind the rump at a run (measured in
-- Karen's place, check305c/check305d). nil is the present, which is every static impact.
local function frameOf(part: BasePart, report: any): CFrame
	local carried = if type(report) == "table" then report.targetCFrame else nil
	return if typeof(carried) == "CFrame" then carried :: CFrame else part.CFrame
end

-- THE HIT CARD GOES TO ONE PLAYER: the one who fired the shot (task 198). It is the only thing this
-- module sends to a single client rather than to everybody, and it is on `ReportEvent` beside the
-- kill line for the reason that line is there at all -- one writer, one remote, one client path in
-- both worlds (`recordDown`'s own comment).
local function toShooter(player: Player, event: Report.CardPayload)
	channel().ReportEvent:FireClient(player, event)
end

-- THE CARD ITSELF, BUILT ONCE (task 304). `recordHit` and `HitLog.sendCard` both go through this,
-- so the hunt's card and the range's are the same payload off the same projection -- `Shape.cardDots`
-- against the trunk's CFrame at the instant of the hit. Pure: no stat, no send, no record.
local function buildCard(part: BasePart, report: any, drive: number, at: number): Report.CardPayload
	local row = Weapons.row(report.weapon)
	local fired = if row ~= nil and report.ammo ~= nil then row.PELLETS[report.ammo] else nil
	local zone = tostring(report.zone or "unknown")
	return {
		kind = "hit",
		drive = drive,
		animal = part.Name,
		animalKind = part:GetAttribute("Kind") :: string?,
		weapon = report.weapon,
		ammo = report.ammo,
		hits = report.pellets or 1,
		fired = fired,
		distance = report.nearest or 0,
		at = at,
		dots = Shape.cardDots(frameOf(part, report), part.Size, report.points, report.position or part.Position, zone),
	}
end

-- WHETHER A HIT EARNS A ROW (task 304). HERE AND NOT IN A ROOT, for `cardWorthy`'s own stated
-- reason -- *"a guard spread over two call sites is two answers"*: `ForestTestBoot` and `MatchBoot`
-- both feed this module, a third world would be a third place to forget it, and in Karen's place a
-- lane hit with a drive open was written a drive row AND a hunt card.
function HitLog.rowWorthy(part: BasePart?): boolean
	return not RangeData.isTarget(part)
end

-- WHETHER A HIT EARNS A CARD. One line, one place, because the dispatch names two things it must
-- never draw for -- a beater and scenery -- and a guard spread over two call sites is two answers.
--
-- `Damageable` IS THE ONE DEFINITION OF AN ANIMAL THIS GAME HAS. It is the attribute
-- `Weapon.Hits.targetOf` walks for, published by the target's own owner (`Boar.Body.create`), and
-- today nothing but an animal carries it -- a beater is a player character and a tree is a tree, so
-- neither is ever the target of a `HitReport` at all. If a player or a prop is ever made damageable,
-- THIS is the line that needs a kind check, exactly as `recordHit`'s own guard says.
function HitLog.cardWorthy(part: BasePart?, shooter: Player?): boolean
	if shooter == nil or part == nil then
		return false
	end
	return part:GetAttribute("Damageable") == true
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

-- The card `recordHit` built last, or nil. `HitLog.clear` forgets it with everything else.
function HitLog.lastCard(): Report.CardPayload?
	return lastCard
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
	lastCard = nil
	table.clear(trace)
	if traceOn() then
		ServerStorage:SetAttribute("DHLastHits", nil)
	end
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
	-- THE LOBBY RANGE IS NOT THE HUNT (task 304). Its card comes from `HitLog.sendCard`, which
	-- writes nothing; this records no row, no dot and no kill for it.
	if not HitLog.rowWorthy(part) then
		stats.rangeHits += 1
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
	local frame = frameOf(part, report)
	local u, v, side = Shape.dot(frame, part.Size, report.position or part.Position)
	local dot = {
		userId = if shooter then shooter.UserId else nil,
		name = if shooter then shooter.Name else nil,
		zone = tostring(report.zone or "unknown"),
		-- WHICH GUN MADE IT (task 140). Copied, never derived -- exactly as `zone` is -- and nil for
		-- a record from before the rifle, which is a legal value on the wire.
		weapon = report.weapon,
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
	-- ...AND THE LOG LINE, HERE, WHERE EVERY NUMBER IN IT IS ALREADY IN HAND (task 278). It divides
	-- down by `frame` -- the report's own tense (task 308), not `part.CFrame` -- so the LOCAL OFFSET
	-- is the same reading as the `(u, v)` beside it.
	stats.traced += 1
	writeTrace(Shape.traceLine({
		index = stats.traced,
		at = sinceOpen(at),
		kind = part:GetAttribute("Kind") or animal.kind,
		id = part.Name,
		zone = dot.zone,
		offset = frame:PointToObjectSpace(report.position or part.Position),
		u = u,
		v = v,
		distance = dot.distance,
		weapon = report.weapon,
		ammo = report.ammo,
		pellets = dot.pellets,
		fatal = false,
	}))
	-- THE NEWEST IS DROPPED, NOT THE OLDEST: the first shots on an animal are the ones that tell the
	-- story of how it died, and a ninth pellet-group on the same carcass tells nobody anything.
	while #animal.dots > CONFIG.HITS_PER_ANIMAL do
		table.remove(animal.dots)
		animal.droppedDots += 1
		stats.droppedDots += 1
	end
	stats.hits += 1

	-- ...AND THE CARD, STRAIGHT BACK TO WHOEVER FIRED (task 198). Karen, 2026-10-16: *"so once we
	-- hit boar we can show where it has been hitted / red dot will indicate so if shells then
	-- several of them / so somewhere in corner after hit we indicate where it landed"*.
	--
	-- IT IS SENT HERE AND NOT FROM A SECOND LISTENER, because this is the one function that holds
	-- both halves at once: the report's per-pellet points, and the frame they were measured in
	-- (task 308). A listener wired beside this one would read the CFrame a frame later again.
	if HitLog.cardWorthy(part, shooter) and shooter ~= nil then
		-- THE SHOT'S OWN CLOCK, THROUGH `sinceOpen` LIKE EVERY OTHER `at` THIS MODULE SENDS (the
		-- Reviewer's blocking finding, round 1): *"an `os.clock` from one machine means nothing on
		-- another"*. It is also what keeps the fatal mark joinable -- `recordDown` sends the same
		-- quantity through the same function, so `HitCard.markFatal`'s match still holds.
		local card = buildCard(part, report, current.number, sinceOpen(at))
		stats.cards += 1
		lastCard = card
		toShooter(shooter, card)
	else
		stats.cardlessHits += 1
	end
	return true
end

-- THE CARD WITHOUT A RECORD (task 304). Karen, 2026-10-28, shooting the lobby range: *"hit card will
-- be usefull"*. THE RANGE IS FREE (docs/design/shooting-range.md section 1), so this writes no drive
-- row, no money and no report entry -- it is `buildCard` plus `toShooter`, and nothing else.
--
-- `drive = 0` AND `at = 0` because there is no drive: `sinceOpen` would answer 0 with none open, and
-- the card's own client reads neither field (`HitCard.show` / `HitCard.textFor` touch `animalKind`,
-- `weapon`, `ammo`, `hits`, `fired`, `distance` and `dots`). No `hitFatal` ever follows one.
function HitLog.sendCard(report: any): boolean
	local part = if type(report) == "table" then report.target else nil
	if typeof(part) ~= "Instance" or not (part :: Instance):IsA("BasePart") then
		return false
	end
	local shooter = report.shooter
	if shooter == nil or not HitLog.cardWorthy(part :: BasePart, shooter) then
		stats.cardlessHits += 1
		return false
	end
	local card = buildCard(part :: BasePart, report, 0, 0)
	stats.cards += 1
	stats.rangeCards += 1
	lastCard = card
	toShooter(shooter, card)
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
		-- ...AND THE LOG SAYS SO (task 278). A SECOND LINE and never an edit of the first: the ring
		-- is what happened in the order it happened, and a hit line that silently becomes fatal
		-- three seconds later would hide the gap between the shot and the death -- which is the one
		-- thing a flight-distance argument needs to see.
		writeTrace(Shape.traceLine({
			index = stats.traced,
			at = sinceOpen(at),
			kind = animal.kind,
			id = animal.id,
			zone = record.killingZone,
			offset = Vector3.zero,
			u = animal.dots[index].u,
			v = animal.dots[index].v,
			distance = record.killingDistance or 0,
			weapon = animal.dots[index].weapon,
			ammo = "DOWN",
			pellets = 0,
			fatal = true,
		}))
		-- ...AND THE CARD THAT IS PROBABLY STILL ON HIS SCREEN LEARNS IT (task 198). The card goes out
		-- at the instant of the HIT and the animal goes down on the Brain's NEXT tick, so at the
		-- moment it was drawn nobody -- server included -- knew yet whether that shot killed. Rather
		-- than hold the card back for a tick, the mark follows it: one small event naming the animal
		-- and the shot's own clock, which is the pair the card already carries.
		--
		-- THE SAME JOIN THE RECORD USES, so the card and the report cannot disagree about which shot
		-- was the fatal one: `at` here is `animal.dots[index].at`, which IS the `report.at` the card
		-- was built with.
		local killer = if record.killedByUserId then Players:GetPlayerByUserId(record.killedByUserId) else nil
		if killer ~= nil then
			stats.cardFatals += 1
			toShooter(killer, {
				kind = "hitFatal",
				drive = current.number,
				animal = animal.id,
				animalKind = animal.kind,
				hits = 0,
				distance = record.killingDistance or 0,
				-- The card's own clock, converted exactly as the card's was: seconds since the
				-- drive opened (the Reviewer's blocking finding, round 1).
				at = sinceOpen(animal.dots[index].at),
				dots = {},
			})
		end
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
		-- WHICH GUN KILLED IT (task 140): the FATAL dot's weapon, which is the shot that did it
		-- rather than the last one that landed. nil when the join failed or the record predates the
		-- rifle, and the kill line prints nothing for it rather than the word "nil".
		weapon = if index ~= nil then animal.dots[index].weapon else nil,
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
					weapon = dot.weapon, -- task 140: the wire carries the id, the panel the word
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
				-- THE GUN THE BEST (or fatal) SHOT CAME FROM, so the animal's own row can name it
				-- without the panel searching the dots (task 140).
				weapon = (best and best.weapon) or nil,
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
