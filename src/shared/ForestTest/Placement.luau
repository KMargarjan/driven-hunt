--!strict
-- Placement: WHERE EVERY ANIMAL OF A DRIVE IS STANDING BEFORE ANYBODY CAN SEE IT (task 345, T1).
--
-- Karen, 2026-11-10: *"animals has to be in palces not just apear magically"* and *"we need to have
-- them not magically apearing it has to be there then it spooked or it walkks towards"*.
--
-- Pattern: a RECORD is the truth and a BODY is a view of it -- Luanti's static/active object split,
-- with Left 4 Dead's "never spawn inside the visible set" as the promotion gate.
-- Design: docs/design/animal-placement.md (sections 4, 5.2, 6, 8.1, 13.1)
-- Note:   docs/research/2026-11-10-animal-placement.md
--
-- PURE: no Instance, no raycast, no os.clock, no RunService, and **no `require` at all**. Every fact
-- comes in as a table, a number or a function belonging to its own owner (`deps`), so each rule is
-- drivable from a spec with hand-written numbers and this file can never become a second writer of
-- anything. It owns no state: the roster it returns is written only by
-- `src/server/ForestTest/init.luau`.
--
-- SINCE T2 `src/server/ForestTest/init.luau` READS IT BEHIND `PLACEMENT_IN_PLACE`, which is still
-- born OFF: with the flag off the drive is today's drive and this file decides nothing (design 11).

local Placement = {}

export type RowState = "record" | "bedded" | "awake" | "gone"
export type WakeReason = "beaters" | "slot" | "shot" | "horn"
export type SkipReason = "budget" | "nobed" | "inview" | "behindline"

export type RosterRow = {
	id: string, -- "g<drive>-s<slot>", stable for the drive, printed in every line
	slot: number, -- the schedule row's slot (0 = a staged release)
	act: number,
	row: any, -- the frozen schedule row: species, party/composition, route, pace...
	size: number, -- nominal members
	composition: any, -- the composition the group IS, decided once at plan time
	kinds: { string }, -- decided once, at plan time, in march order
	bedNorth: number, -- dz north of the road: WHERE IT STANDS
	bedOffsetX: number, -- studs from the stand the drive aims at, after the gap sweep
	laneOffset: number, -- which beater lane this bed belongs to
	zones: { number }?, -- the cell's restZones, or nil for "any legal spot"
	walker: boolean, -- true for this drive's walkersPerDrive shallowest groups
	wakeAtSeconds: number, -- a walker's slot clock; math.huge for a group the line must find
	reachAtSeconds: number, -- when the line is expected to reach this bed
	state: RowState, -- written ONLY by src/server/ForestTest/init.luau
	at: Vector3?, -- the bed actually found
	ids: { string }, -- the live Boar ids, once it has bodies
	lineId: string?, -- its row in state.lines, once it is awake
	skipped: SkipReason?,
	-- WRITTEN BY `ForestTest.stepPlacement`, and they are LATCHES AND NOT STATE: each one stops a
	-- counter that would otherwise be read every Heartbeat instead of once per group (task 345 T5).
	atNorth: number?, -- where the group actually lies, off the member nearest the line (T4)
	wokeAs: string?, -- "band" / "walk" / "horn" / "slot": what woke it, first claim only
	slotDue: boolean?, -- its slot clock has been counted once
}

-- WHAT THE OWNERS ANSWER, HANDED IN. Every entry is one owner's own function or one owner's own
-- derived number, so no rule here is a second copy of one of theirs (rule 3).
export type Deps = {
	-- `Data.noticeAheadStuds(spook, layout)` -- the notice BAND's depth. It is a derivation
	-- (`sqrt(reach^2 - (laneSpacing/2)^2)`, floored) and `src/shared/ForestTest/init.luau` owns it,
	-- so the NUMBER comes in. That is this repo's own precedent, in that file: *"it is a plain
	-- number, which is what makes 'how far apart is a lane' ONE answer"* (`bandDepth`).
	noticeAheadStuds: number,
	-- `Data.laneSpacing(layout)` -- the lane lattice's pitch, for classifying a bed into a lane.
	laneSpacingStuds: number,
	-- `Data.slotAt(slot, density, schedule)` -- THE WHOLE OF THE DENSITY DIAL. Asked, never copied.
	slotAt: (number, string?, any) -> any?,
	-- `Data.slotSeconds(slot, schedule)` -- WHEN THE SCRIPT SAYS THIS SLOT MOVES. It is the drive
	-- script's own clock and it is what the bed depths are measured off (`Placement.bedNorth`), so
	-- the roster's clock and the metronome's cannot be two clocks.
	slotSeconds: (number, any) -> number,
	-- `Boar.compositionSize(composition, config)` -- how many animals a composition is.
	compositionSize: (any, any) -> number,
	-- `Boar.deerComposition(roll, pick, config, wanted)` -- which party a `reddeer` row names.
	deerComposition: (number, number, any, any?) -> any?,
	-- `Boar.sounderKinds(size, rolls, config, composition)` -- optional. With a composition it draws
	-- nothing, so the rolls are a formality; without this the row's `kinds` is empty and T2 fills it.
	sounderKinds: ((number, { number }, any, any?) -> { string })?,
}

-- EVERY NUMBER OF THE DESIGN'S SECTIONS 5.2 AND 6.2, IN ONE FROZEN TABLE.
--
-- THE DERIVED ONES ARE PUBLISHED HERE AND DERIVED IN THE FUNCTIONS, and the spec asserts the two
-- agree -- the `NOTICE_M`/`NOTICE_STUDS` idiom this repo already uses. So a reader sees the shipped
-- value, and moving `SPOOK.NOTICE_STUDS` or `REST.nearRoadStuds` moves the rule rather than leaving
-- a literal behind.
Placement.CONFIG = table.freeze({
	-- = SPOOK.NOTICE_STUDS 125 + bedSpreadStuds 40 / 2. Inside the notice reach an animal would
	-- already be reacting to her, and half the bed spread is how far the nearest member of a group
	-- can be from the point that was tested.
	neverStuds = 145,
	-- = max(neverStuds, REST.nearRoadStuds 40), rounded up to BAND_NEAR_ROUND_STUDS. THE NEAR 150
	-- STUDS OF THE CELL THEREFORE HOLD NO BEDDED ANIMAL: that ground is crossed, not inhabited
	-- (Karen's K-3).
	bandNearStuds = 150,
	-- A GROUP LYING UP, not a released sounder's 90-stud spawn ring (`REST.spreadStuds`): 40 studs
	-- is 11 m, and it is what makes a 71-stud bed gap mean anything. Nine animals on it are 14
	-- studs apart, clear of `Boar.bodyAvoidRadius`.
	bedSpreadStuds = 40,
	-- = SPOOK.BEATER_STUDS 71. The fright latches, so two groups inside one flush circle both bolt
	-- on one approach -- `REST.groups`' own measured rule (min pair 101.3 studs over 45 pairs).
	bedGapStuds = 71,
	-- Of the 24 bodies the budget allows, at most this many are bedded-and-not-yet-reached.
	--
	-- 18 AND NOT THE DESIGN'S 12, BY THE DIRECTOR'S DECISION of 2026-11-11 ~01:45 (`ESCALATE.md`,
	-- deviation 5): *"ACCEPTED, as a change to D-1 ... This entry supersedes the '<= 12' rows in the
	-- design's sections 5.2 and 16"*. 12 was *"four groups of three"* and there is no group of three
	-- in `SCHEDULE.drive` (73 animals in 13 groups of 1 to 9), so it refused the third group of every
	-- drive -- 6 of 13 skipped on `budget` at C1. Two groups are in flight at once x the largest
	-- composition the script can ask for (9) = 18, still a SUB-cap of `Data.LIVE_CAP` 24, which is
	-- the arm that binds and which held at exactly 24.
	bedCap = 18,
	-- The line covers 62 studs in 20 s, well inside the 100-stud notice band, so a group always has
	-- a body before anything can notice it and no body exists more than 20 s before it is needed.
	leadSeconds = 20,
	-- Karen's K-2. More fills the opening and risks a wood walking out of itself (task 342's
	-- `settled` despawn); fewer means a quiet first 30 seconds.
	walkersPerDrive = 2,
	-- THE TEMPO, AS A DEPTH -- the Director's decision of 2026-11-10 ~13:50, and the ONE constant
	-- derived from the line's speed. Karen accepted a drive that moves a group every
	-- `SCHEDULE.intervalSeconds` 13 s, so two consecutive slots' beds are that many seconds of the
	-- line's walk apart:
	--
	--     13 s  x  Grid.CONFIG.beaterWalkStudsPerSecond 5.64 studs/s  =  73.32 studs
	--
	-- THE SPEED IS THE LIVE ONE (5.64 since task 327d2; it is also `Bots.CONFIG.WALK_SPEED`) AND NOT
	-- the 3.1 the design's section 4.2 table was computed at -- at 3.1 the same 13 s is 40 studs and
	-- the line would find a group every 7 s. `forest_placement.spec` asserts this against both
	-- owners' own numbers, so neither can move without the other.
	bedSpacingStuds = 73.32,
	-- At most one group materialised per Heartbeat: `Cells.begin`'s bite shape, for its measured
	-- reason (a whole-folder write cost 738 ms of frame in Karen's place, task 343).
	bitesPerStep = 1,
	-- HOW MANY RING SEARCHES ONE ROW MAY SPEND BEFORE IT IS PARKED (the Director's decision of
	-- 2026-11-11 ~04:55, after A2 spent **~2,940 searches re-trying three `inview` refusals** in one
	-- drive). A parked row stays a RECORD and is woken once more by the beaters or its slot clock
	-- (`Placement.reopenNow`), so it is never lost -- it just stops paying for the same refusal
	-- fifteen times a second. ARITHMETIC: 15 rows x 3 searches + 15 one-off reopens x 3 = **90**
	-- searches worst case per drive, against the Director's target of under 100.
	searchesPerWake = 3,
	-- WHEN A FILE IS JUDGED TO BE FORMED (design 12.1: *"median nose-to-nose <= 17 studs within 5 s
	-- of a break"*). A woken group is standing in a loose bed, so its followers walk UP to their
	-- stations; five seconds is the window the design gives them and the window the measurement is
	-- taken in. The 17 studs is `2 x LINE.spacingStuds` and belongs to `Data.LINE`, not here --
	-- `forest_placement.spec` asserts the two agree.
	fileFormedSeconds = 5,
	settleSeconds = 3,
})

-- The near edge is rounded up to a round number of studs so the band reads as a place and not as a
-- derivation's remainder: 145 becomes 150.
Placement.BAND_NEAR_ROUND_STUDS = 10
-- How finely the gap sweep walks sideways looking for a legal bed (design section 4.2; see
-- `Placement.clearX`). One stud is finer than anything the eye can judge and 191 candidates inside
-- `crossCapStuds` is nothing to walk.
Placement.GAP_SWEEP_STEP_STUDS = 1

-- ---------------------------------------------------------------- the band, the bed and the clock

local function minAheadOf(spook: any): number
	local sweep = (if type(spook) == "table" then spook.SWEEP else nil) or {}
	return tonumber(sweep.MIN_AHEAD_STUDS) or 0
end

local function noticeStudsOf(spook: any): number
	return (if type(spook) == "table" then tonumber(spook.NOTICE_STUDS) else nil) or 0
end

local function configOr(config: any): any
	return if type(config) == "table" then config else Placement.CONFIG
end

-- HOW CLOSE AN ANIMAL MAY BE CREATED TO A PLAYER. Derived, never written: the notice reach plus half
-- the bed spread, because the point tested is the bed's centre and a member can be that far from it.
function Placement.neverStuds(spook: any, config: any?): number
	local resolved = configOr(config)
	return noticeStudsOf(spook) + (tonumber(resolved.bedSpreadStuds) or 0) / 2
end

-- TWO BEDS CLOSER THAN THIS ARE ONE GROUP to a flush. It IS `SPOOK.BEATER_STUDS` and is read off it
-- rather than copied, so moving the flush circle moves the bed spacing.
function Placement.bedGapStuds(spook: any): number
	return (if type(spook) == "table" then tonumber(spook.BEATER_STUDS) else nil) or 0
end

-- THE NEAR EDGE OF THE BAND. The `max` with `neverStuds` is the WHOLE GUARANTEE that no bed is ever
-- planned inside a hunter's reach: delete that arm and the band starts at `REST.nearRoadStuds` 40,
-- which is 105 studs inside it (`forest_placement.spec`, "the band is derived, not written").
function Placement.bandNear(spook: any, rest: any, config: any?): number
	local never = Placement.neverStuds(spook, config)
	local road = (if type(rest) == "table" then tonumber(rest.nearRoadStuds) else nil) or 0
	local want = math.max(never, road)
	local step = Placement.BAND_NEAR_ROUND_STUDS
	return math.ceil(want / step) * step
end

-- THE FAR EDGE: as deep as a bed can be and still be found by a line that starts at `beaterNorth`.
-- The line must have the group inside its notice band while it is still sweeping forward, so the
-- deepest bed sits one notice band plus one sweep floor south of the muster.
function Placement.bandFar(beaterNorth: number, noticeAheadStuds: number, spook: any): number
	return beaterNorth - noticeAheadStuds - minAheadOf(spook)
end

-- HOW FAR APART TWO CONSECUTIVE SLOTS' BEDS ARE. The derivation of `CONFIG.bedSpacingStuds`, so
-- the published number cannot drift from the two it comes from.
function Placement.bedSpacingStuds(intervalSeconds: number, lineSpeed: number): number
	return (tonumber(intervalSeconds) or 0) * (tonumber(lineSpeed) or 0)
end

-- WHERE A GROUP LIES UP: **WHERE THE LINE WILL BE AT THE MOMENT THE SCRIPT SAYS THAT GROUP MOVES.**
--
-- ONE RULE, and it makes the roster's clock and the drive script's clock the SAME clock by
-- arithmetic rather than by hope (design 4.2). The line starts at `far` and walks south at
-- `lineSpeed`, so the bed it reaches at the slot's own `atSeconds` is `far - atSeconds * lineSpeed`.
-- Slot 1 is therefore the DEEPEST and the last slot the shallowest, which is also the only order a
-- line walking south can meet them in.
--
-- THE TEMPO IS THE SCRIPT'S OWN: consecutive slots are `intervalSeconds` apart in TIME, so their
-- beds are `bedSpacingStuds` apart in DEPTH, and a density that drops a slot leaves that slot's
-- depth EMPTY -- the same silence the metronome gave it. The even spread the design's section 4.2
-- wrote instead was measured in T1 and refused by the Director: it makes the interval a function of
-- the dial (6.2 s at `normal` in a cell), which is not the drive Karen accepted.
--
-- `near` IS A FLOOR AND THE SECOND RETURN SAYS IT BIT: a clamped bed shares its depth with the one
-- before it, so the caller must find it room sideways (`clearX`) or skip the group.
function Placement.bedNorth(far: number, atSeconds: number, lineSpeed: number, near: number): (number, boolean)
	local want = far - math.max(0, tonumber(atSeconds) or 0) * math.max(0, tonumber(lineSpeed) or 0)
	if want < near then
		return near, true
	end
	return want, false
end

-- THE BAND `ForestTest.restSpot`'S RING SEARCH MAY TAKE **THIS** BED FROM: the stocked wood's own
-- searcher with three of its numbers replaced by this bed's.
--
-- IT IS WHY A BED CAN BE DEEP AT ALL. `REST.farRoadStuds` 425 is the band a STOCKED group was spread
-- over; a cell's bandFar is 1,300, so every plan deeper than 425 would be refused by the very
-- searcher meant to find it. And `clearOfStartStuds` 30 goes to 0 because the extra margin is
-- already carried in DEPTH by `bandFar`'s own `SWEEP.MIN_AHEAD_STUDS` term -- what is left is the
-- NOTICE reach, which is the question that matters ("could this group already be reacting to her").
function Placement.searchBand(bedNorth: number, offsetX: number, laneOffset: number, rest: any, config: any?): any
	local resolved = configOr(config)
	local half = (tonumber(resolved.bedSpreadStuds) or 0) / 2
	local out = {}
	if type(rest) == "table" then
		for key, value in pairs(rest) do
			out[key] = value
		end
	end
	out.nearRoadStuds = math.max(0, bedNorth - half)
	out.farRoadStuds = bedNorth + half
	out.clearOfStartStuds = 0
	-- A group LYING UP, not a released sounder's 90-stud ring.
	out.spreadStuds = tonumber(resolved.bedSpreadStuds) or 0
	-- HOW FAR OFF ITS OWN BEATER LANE THIS BED IS ALLOWED TO BE: as far as the plan already put it,
	-- plus half its spread. `REST.laneSideStuds` 40 is the stocked rows' own ceiling and every one of
	-- them sits within 24 studs of its lane; a planned bed may be up to `crossCapStuds` 95 from the
	-- stand, which `laneOf` rounds to the lane 150 studs out -- so the stocked ceiling would refuse
	-- every candidate of a bed the plan itself wrote.
	out.laneSideStuds = math.abs((tonumber(offsetX) or 0) - (tonumber(laneOffset) or 0)) + half
	return out
end

-- WHEN THE LINE REACHES A BED, in seconds from the drive opening. `math.huge` for a line that is not
-- walking, which is an honest refusal rather than a division.
function Placement.lineReaches(bedNorth: number, far: number, walkSpeed: number): number
	if type(walkSpeed) ~= "number" or walkSpeed <= 0 then
		return math.huge
	end
	return math.max(0, (far - bedNorth) / walkSpeed)
end

-- IS THIS RECORD DUE A BODY? Level-triggered and read at the instant (L-029), never latched.
--
-- A SKIPPED ROW IS NEVER DUE AGAIN -- design must-not 3, task 172's rule: *"a wood is beaten once;
-- when it is empty it stays empty for this drive"*. A refused group must never come back inside the
-- drive, because the only place left to put it is in front of somebody.
-- ...AND A ROW THAT HAS SPENT ITS SEARCHES IS PARKED (the Director, 2026-11-11 ~04:55). It is NOT
-- skipped and NOT lost: `Placement.reopenNow` hands it one more window when the line reaches its bed
-- or its slot clock comes, and a row that beds in that window is in the hunt like any other.
function Placement.dueNow(row: any, elapsed: number, lead: number, searchCap: number?): boolean
	if type(row) ~= "table" or row.skipped ~= nil or row.state ~= "record" then
		return false
	end
	local cap = tonumber(searchCap) or tonumber(Placement.CONFIG.searchesPerWake) or math.huge
	if (tonumber(row.searchesSpent) or 0) >= cap then
		return false
	end
	local reach = tonumber(row.reachAtSeconds) or math.huge
	local wake = tonumber(row.wakeAtSeconds) or math.huge
	local at = math.min(reach, wake)
	if at == math.huge then
		return false
	end
	return at - elapsed <= (tonumber(lead) or 0)
end

-- THE BUDGET DOOR, read at the instant on the numbers handed in. Two independent arms, and the word
-- it returns names which one refused so a console line can say so.
function Placement.roomFor(
	bodies: number,
	bedded: number,
	size: number,
	cap: number,
	bedCap: number
): (boolean, string?)
	if bodies + size > cap then
		return false, "live"
	end
	if bedded + size > bedCap then
		return false, "bedded"
	end
	return true, nil
end

-- THE DISTANCE HALF OF "NEVER IN VIEW". 3-D AND NOT FLAT: a hunter on a high seat deck is 12.5
-- studs up and that distance is real. The second return is the nearest eye's distance, so a refusal
-- can say how far.
--
-- An eye exactly at `neverStuds` is allowed: the refusal is for a bed strictly inside the reach.
function Placement.clearOfEyes(spot: Vector3, eyes: { Vector3 }, neverStuds: number): (boolean, number)
	local nearest = math.huge
	for _, eye in ipairs(eyes or {}) do
		if typeof(eye) == "Vector3" then
			local distance = (eye - spot).Magnitude
			if distance < nearest then
				nearest = distance
			end
		end
	end
	return nearest >= neverStuds, nearest
end

-- WHAT MAKES A BEDDED GROUP MOVE, or nil for "it is still lying there".
--
-- TWO TRIGGERS AND THEY CANNOT REACH EACH OTHER'S ARM: a walker has a finite `wakeAtSeconds` and a
-- group the line must find has `math.huge`, so one row of data decides which rule applies. A shot
-- and the horn are the Boar runtime's own (`hearShot`, `hearHorn`) and need nothing here, because a
-- bedded animal is a real body in the world.
function Placement.wakeReason(
	row: any,
	elapsed: number,
	frontNorth: number?,
	noticeAheadStuds: number,
	leadStuds: number?
): WakeReason?
	if type(row) ~= "table" or row.state ~= "bedded" then
		return nil
	end
	if row.walker == true and elapsed >= (tonumber(row.wakeAtSeconds) or math.huge) then
		return "slot"
	end
	if type(frontNorth) ~= "number" then
		return nil
	end
	-- THE BED THAT WAS FOUND, NOT THE ONE THAT WAS PLANNED (T4). `searchBand` lets the ring search
	-- take a bed `bedSpreadStuds / 2` either side of the planned depth, so the two can be 20 studs
	-- apart -- 3.5 s of the line's walk, which is longer than `SPOOK.ALERT_SECONDS` 2.
	local bed = tonumber(row.atNorth) or tonumber(row.bedNorth) or math.huge
	-- ...AND THE WAKE LEADS THE NOTICE BY HALF A BED SPREAD, for `neverStuds`' own reason: the
	-- nearest MEMBER of a group can be half the spread in front of the point that was tested, and
	-- `spookNearBeaters` measures its band off each animal's live position. MEASURED, the first ON
	-- drive of task 345d at C1: with no lead, **3 of 4 woken groups were already flying** when
	-- `orderGroup` reached them (`345d-diag-mid.txt`, `flights=3 ordered=1`) -- the stand had run its
	-- two seconds and the flush had taken them, and a flying animal is never ordered. A group that
	-- bolts instead of filing out is Karen's *"it has to be there then it spooked"* half-built.
	-- No lower bound: a front that has already passed the bed is past it, and a group the line
	-- walked through is exactly the one that must move (`Data.sweepCatches` is the server's half).
	if frontNorth - bed <= noticeAheadStuds + (tonumber(leadStuds) or 0) then
		return "beaters"
	end
	return nil
end

-- HOW FAR THE WAKE LEADS THE NOTICE, in studs: half a bed spread, which is how far the nearest
-- member can be in front of the bed point the rule is written against.
function Placement.wakeLeadStuds(config: any?): number
	return (tonumber(configOr(config).bedSpreadStuds) or 0) / 2
end

-- THE BRIDGE IS GONE (T4). `Placement.bridgeMustRelease` -- the one case in which
-- `ForestTest.releaseLine` could still SPAWN a scheduled group on the flag-ON path -- is archived
-- with the spawn half it guarded: `backups/2026-11-11_task-345d_release-line-bridge.md`. A group the
-- wood refused is now a hole in the wood that is REPORTED (design 4.3), not one filled 25 studs off
-- the road.

-- MAY A PARKED ROW HAVE ONE MORE WINDOW? (the Director's retry cap, 2026-11-11 ~04:55.)
--
-- ONE REOPEN PER ROW PER DRIVE, whichever signal arrives first, and that bound is the whole of the
-- arithmetic in `CONFIG.searchesPerWake`: 3 searches, then parked, then 3 more when the drive
-- actually wants the group, then its refusal is final. Two signals and not three, because they are
-- the two that mean "the drive needs this group NOW": the line's notice band has reached its bed, or
-- its own slot clock has come (a walker). `row.reopened` is the latch, because the geometry arm is
-- level-triggered and would otherwise reopen the window on every step it is true.
function Placement.reopenNow(
	row: any,
	elapsed: number,
	frontNorth: number?,
	noticeAheadStuds: number,
	searchCap: number?
): WakeReason?
	if type(row) ~= "table" or row.skipped ~= nil or row.state ~= "record" or row.reopened == true then
		return nil
	end
	local cap = tonumber(searchCap) or tonumber(Placement.CONFIG.searchesPerWake) or math.huge
	if (tonumber(row.searchesSpent) or 0) < cap then
		return nil
	end
	if elapsed >= (tonumber(row.wakeAtSeconds) or math.huge) then
		return "slot"
	end
	if type(frontNorth) ~= "number" then
		return nil
	end
	if frontNorth - (tonumber(row.bedNorth) or math.huge) <= (tonumber(noticeAheadStuds) or 0) then
		return "beaters"
	end
	return nil
end

-- THE TRAIL A FILE IS BORN WITH, and it is a MEASURED fix rather than a tidy-up (task 127).
-- `Line.pointBack` answers nil until the leader has walked as far as the station being asked for, so
-- with an empty trail every follower is told "walk at the leader" for the first few seconds: the
-- measured nose-to-nose median came out **9.6 studs against a `spacingStuds` of 3**.
--
-- `toward` IS THE DIRECTION OF TRAVEL and the seed is laid BEHIND the origin along it, so station k
-- exists on the very first step. A released file hands in the approach's own direction; a WOKEN
-- group (T4) hands in the first leg of the route it has just been given, because it is standing in a
-- bed and not on an approach.
function Placement.seedTrail(origin: Vector3, toward: Vector3, members: number, spacing: number)
	local flat = Vector3.new(toward.X, 0, toward.Z)
	local unit = if flat.Magnitude > 1e-4 then flat.Unit else Vector3.new(0, 0, -1)
	local step = math.max(0.1, tonumber(spacing) or 1)
	local out = {}
	for back = math.ceil((math.max(1, math.floor(tonumber(members) or 1)) + 1) * step), 0, -1 do
		table.insert(out, { at = origin - unit * back, s = 0 })
	end
	for index = 2, #out do
		out[index].s = out[index - 1].s + (out[index].at - out[index - 1].at).Magnitude
	end
	return out
end

-- IS THIS SPOT CLEAR OF EVERY BED ALREADY LAID? 3-D, over the beds that still count: a skipped row
-- has no bed and a gone one has left.
function Placement.gapOk(rows: { any }, at: Vector3, gapStuds: number): boolean
	for _, row in ipairs(rows or {}) do
		if type(row) == "table" and row.skipped == nil and row.state ~= "gone" and typeof(row.at) == "Vector3" then
			if (row.at - at).Magnitude < gapStuds then
				return false
			end
		end
	end
	return true
end

-- WHICH LANE A BED BELONGS TO: the nearest lane of the lattice `Data.beaterLaneOffset` deals
-- (0, +-spacing, +-2*spacing...). A classification of a bed that already has an x, not a second
-- answer to where a lane is -- the pitch is the layout's and comes in.
function Placement.laneOf(offsetX: number, laneSpacingStuds: number): number
	if type(laneSpacingStuds) ~= "number" or laneSpacingStuds <= 0 then
		return 0
	end
	return math.round(offsetX / laneSpacingStuds) * laneSpacingStuds
end

-- WHERE THIS BED CAN ACTUALLY GO, SIDEWAYS, so no two beds are inside the flush circle.
--
-- THE DESIGN SAID THE WRITTEN OFFSETS ALREADY CARRIED THIS AND THEY DO NOT (research note section
-- 4): at `normal` the beds are 25 studs apart in depth and slots 4 and 6 sit at +45 and +95, which
-- is 55.9 studs in 3-D; at `busy` slots 5 and 8 are 67.3 apart. Both are inside 71. So the bed is
-- PLACED rather than asserted about: keep the row's depth, sweep outward from the x the script
-- wrote, in `GAP_SWEEP_STEP_STUDS` steps, and take the first x inside the cap that clears every bed
-- already laid. Nil means there is none, and the caller skips the group (`nobed`) rather than
-- bedding it on top of another -- design must-not 3.
function Placement.clearX(
	placed: { { x: number, z: number } },
	wantedX: number,
	bedNorth: number,
	capStuds: number,
	gapStuds: number
): number?
	local function clears(x: number): boolean
		for _, bed in ipairs(placed) do
			local dx, dz = x - bed.x, bedNorth - bed.z
			if math.sqrt(dx * dx + dz * dz) < gapStuds then
				return false
			end
		end
		return true
	end
	local step = Placement.GAP_SWEEP_STEP_STUDS
	local reach = math.ceil(2 * capStuds / step)
	for index = 0, reach do
		local out = index * step
		-- Outward from the written x, east then west, so the answer is the nearest legal bed to the
		-- one the script asked for and two identical plans are the same plan.
		for _, candidate in ipairs(if out == 0 then { wantedX } else { wantedX + out, wantedX - out }) do
			if candidate >= -capStuds and candidate <= capStuds and clears(candidate) then
				return candidate
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------- the roster

-- HOW MANY ROWS ARE IN EACH STATE. One walk, so `line` and a caller's stats cannot disagree.
function Placement.tally(rows: { any }): {
	placed: number,
	bedded: number,
	awake: number,
	gone: number,
	skipped: number,
	animals: number,
	walkers: number,
}
	local out = { placed = 0, bedded = 0, awake = 0, gone = 0, skipped = 0, animals = 0, walkers = 0 }
	for _, row in ipairs(rows or {}) do
		out.placed += 1
		out.animals += tonumber(row.size) or 0
		if row.walker == true then
			out.walkers += 1
		end
		if row.skipped ~= nil then
			out.skipped += 1
		elseif row.state == "bedded" then
			out.bedded += 1
		elseif row.state == "awake" then
			out.awake += 1
		elseif row.state == "gone" then
			out.gone += 1
		end
	end
	return out
end

function Placement.line(rows: { any }): string
	local t = Placement.tally(rows)
	return string.format(
		"placed %d / bedded %d / awake %d / gone %d / skipped %d",
		t.placed,
		t.bedded,
		t.awake,
		t.gone,
		t.skipped
	)
end

-- THE ROSTER: who is in this drive, and where each group lies up. Built ONCE, at the drive
-- boundary, pure, with no yield -- which is what lets it run inside `world.markers`, whose contract
-- is *"it MUST NOT YIELD"*.
--
-- `schedule` is `Data.cellSchedule()`'s table (its rows are already depth- and bias-adjusted for the
-- live cell), `animals` is `Grid.animalsOf(cell)`, and the second return is the lines that explain
-- what it did -- every refusal printed, never hidden (design must-not 11).
function Placement.plan(
	driveNumber: number,
	schedule: any,
	animals: any?,
	rest: any,
	spook: any,
	beaterNorth: number,
	walkSpeed: number,
	boarConfig: any,
	rng: Random,
	deps: Deps
): ({ RosterRow }, { string })
	local config = Placement.CONFIG
	local rows: { RosterRow } = {}
	local lines: { string } = {}
	assert(type(deps) == "table", "Placement.plan: the owners' answers must be handed in")

	local drive = (if type(schedule) == "table" then schedule.drive else nil) or {}
	local density = (if type(animals) == "table" then animals.density else nil)
		or (if type(schedule) == "table" then schedule.density else nil)

	-- WHO IS IN THE DRIVE. The dial is `Data.slotAt`'s and is ASKED, never copied: one slot per row
	-- of the script, so the repeat window past the end of the script is never reached (it is
	-- retired in T5 with the behaviour it bounded).
	local kept = {}
	for slot = 1, #drive do
		local row = deps.slotAt(slot, density, schedule)
		if row ~= nil then
			table.insert(kept, row)
		end
	end

	-- THE DEER CAP IS SPENT ONCE PER DRIVE, HERE, instead of fifteen times at fifteen releases.
	-- `Boar.deerGroupsAllowed`'s own two rules, read off the animal owner's table: a group cap, and
	-- a party of one animal gets `LONE_PARTY_EXTRA_GROUPS` more -- *"if MAX_GROUPS_ALIVE slips him,
	-- let the stag (only) be released even if one other group is alive, because he moves alone"*.
	local species = (if type(boarConfig) == "table" then boarConfig.SPECIES else nil) or {}
	local release = (if type(species.reddeer) == "table" then species.reddeer.RELEASE else nil) or {}
	local deerCap = tonumber(release.MAX_GROUPS_ALIVE) or 1
	local loneExtra = tonumber(release.LONE_PARTY_EXTRA_GROUPS) or 0
	local loneSize = tonumber(release.LONE_PARTY_SIZE) or 1
	local sounders = (
		if type(boarConfig) == "table" and type(boarConfig.SOUNDER) == "table"
			then boarConfig.SOUNDER.COMPOSITIONS
			else nil
	) or {}
	local deerGroups = 0

	-- WHO IS IN EACH GROUP, and the deer cap applied as the roster is built.
	local admitted = {}
	for _, row in ipairs(kept) do
		local composition, size = nil, 0
		if row.species == "reddeer" then
			local wanted = deps.deerComposition(0, 0, boarConfig, row.party)
			local wantedSize = if wanted ~= nil then deps.compositionSize(wanted, boarConfig) else math.huge
			local cap = if wantedSize <= loneSize then deerCap + loneExtra else deerCap
			if wanted == nil then
				table.insert(
					lines,
					string.format(
						"plan %d: slot %s names no deer party %q",
						driveNumber,
						tostring(row.slot),
						tostring(row.party)
					)
				)
			elseif deerGroups >= cap then
				table.insert(
					lines,
					string.format(
						"plan %d: slot %s wanted the %s and the deer cap refused -- %d group(s) already in this drive, cap %d",
						driveNumber,
						tostring(row.slot),
						tostring(row.party),
						deerGroups,
						cap
					)
				)
			else
				composition, size = wanted, wantedSize
				deerGroups += 1
			end
		else
			composition = sounders[row.composition]
			if composition == nil then
				-- PRINTED, NOT DROPPED (design must-not 11; round 1's note). No shipped row reaches
				-- this -- a boar row's `composition` indexes `SOUNDER.COMPOSITIONS` -- so it is a
				-- typo in the script, and a typo that silently removes a group from a drive is the
				-- kind of hole this module exists to close.
				table.insert(
					lines,
					string.format(
						"plan %d: slot %s names no sounder composition %s",
						driveNumber,
						tostring(row.slot),
						tostring(row.composition)
					)
				)
			else
				size = deps.compositionSize(composition, boarConfig)
			end
		end
		if composition ~= nil then
			table.insert(admitted, { row = row, composition = composition, size = size })
		end
	end

	-- WHERE THEY LIE UP.
	local far = Placement.bandFar(beaterNorth, deps.noticeAheadStuds, spook)
	local near = Placement.bandNear(spook, rest, config)
	local gap = Placement.bedGapStuds(spook)
	local capStuds = (if type(schedule) == "table" then tonumber(schedule.crossCapStuds) else nil) or 0
	local firstSlot = (if type(schedule) == "table" then tonumber(schedule.firstSlotSeconds) else nil) or 0
	local interval = (if type(schedule) == "table" then tonumber(schedule.intervalSeconds) else nil) or 0
	local groups = #admitted
	local walkers = math.clamp(tonumber(config.walkersPerDrive) or 0, 0, groups)
	local placed: { { x: number, z: number } } = {}

	for ordinal, entry in ipairs(admitted) do
		local row = entry.row
		-- THE SLOT'S OWN MOMENT IS THE BED'S DEPTH. `deps.slotSeconds` is the drive script's clock
		-- (`firstSlotSeconds` + (slot - 1) * `intervalSeconds`), so slot 1 lies where the line will be
		-- 10 s in and each later slot `bedSpacingStuds` shallower.
		local atSeconds = deps.slotSeconds(tonumber(row.slot) or ordinal, schedule)
		local bedNorth, clamped = Placement.bedNorth(far, atSeconds, walkSpeed, near)
		if clamped then
			table.insert(
				lines,
				string.format(
					"plan %d: slot %s is due at %.0f s, which is past the near edge of the band -- its bed is CLAMPED to dz %.0f",
					driveNumber,
					tostring(row.slot),
					atSeconds,
					near
				)
			)
		end
		local wantedX = math.clamp(tonumber(row.offsetX) or 0, -capStuds, capStuds)
		local x = Placement.clearX(placed, wantedX, bedNorth, capStuds, gap)
		local skipped: SkipReason? = nil
		if x == nil then
			skipped = "nobed"
			x = wantedX
			table.insert(
				lines,
				string.format(
					"plan %d: slot %s has no bed at dz %.1f clear of %d others by %.0f studs -- SKIPPED for this drive",
					driveNumber,
					tostring(row.slot),
					bedNorth,
					#placed,
					gap
				)
			)
		else
			table.insert(placed, { x = x, z = bedNorth })
		end

		-- THE WALKERS ARE THE SHALLOWEST BEDS: they stand up on the slot clock with nobody pushing
		-- them, and they are what the hunter sees in the first 30 seconds. The shallowest has the
		-- shortest walk, so it takes the first clock.
		local fromEnd = groups - ordinal -- 0 for the shallowest bed
		local isWalker = skipped == nil and fromEnd < walkers
		local wakeAt = if isWalker then firstSlot + fromEnd * interval else math.huge

		local kinds: { string } = {}
		if deps.sounderKinds ~= nil then
			local rolls = {}
			for _ = 1, math.max(0, entry.size) do
				table.insert(rolls, rng:NextNumber())
			end
			kinds = deps.sounderKinds(entry.size, rolls, boarConfig, entry.composition)
		end

		table.insert(rows, {
			id = string.format("g%d-s%s", driveNumber, tostring(row.slot)),
			slot = tonumber(row.slot) or ordinal,
			act = tonumber(row.act) or 0,
			row = row,
			size = entry.size,
			composition = entry.composition,
			kinds = kinds,
			bedNorth = bedNorth,
			bedOffsetX = x,
			laneOffset = Placement.laneOf(x, deps.laneSpacingStuds),
			zones = if type(animals) == "table" and type(animals.restZones) == "table" then animals.restZones else nil,
			walker = isWalker,
			wakeAtSeconds = wakeAt,
			reachAtSeconds = Placement.lineReaches(bedNorth, far, walkSpeed),
			state = "record" :: RowState,
			at = nil,
			ids = {},
			lineId = nil,
			skipped = skipped,
		})
	end

	local t = Placement.tally(rows)
	table.insert(
		lines,
		string.format(
			"plan %d: %s / %d animals / %d walkers, band dz %.0f..%.0f, %.1f studs per slot, at %s",
			driveNumber,
			Placement.line(rows),
			t.animals,
			t.walkers,
			near,
			far,
			Placement.bedSpacingStuds(interval, walkSpeed),
			tostring(density)
		)
	)
	return rows, lines
end

return Placement
