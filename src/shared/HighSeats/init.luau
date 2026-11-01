--!strict
-- HighSeats: A WOODEN HIGH SEAT (a Central-European *Hochsitz*), AS ARITHMETIC AND NOTHING ELSE.
--
-- KAREN, 2026-10-10: *"hunter part is good for now, we just will improve standing places, maybe
-- will add towers where they can stand"*; 2026-10-12, the stand is the circle and *"tree stands
-- later count as part of the stand"*. Her reference is `karen-ref-7.png` (outside the repo): a
-- hunter on an open raised wooden stand at the side of a forest road -- four posts, a plank deck, a
-- single weathered board round it at a seated man's chest, a ladder, and no roof. Task 218.
--
-- WHERE THE SPLIT IS, and it is the split `Places` already makes. `ForestTest` says WHERE THE LINE
-- IS. This module says WHAT A SEAT IS and WHICH STANDS CARRY ONE -- and it is PURE: no Instance, no
-- service, no raycast, no `Workspace`. `ServerScriptService.ForestTest.Seats` is the only thing that
-- measures the ground and builds parts, and it is the one writer of `Workspace.HighSeats`.
--
-- THE SEAM IS ONE DIRECTION ONLY, exactly as `Places` -> `ForestTest` is: this module requires
-- `ForestTest` for the layout names and the stand count, and nothing in `ForestTest` mentions this
-- one. No field is added to the `Layout` record (`docs/design/drive-places.md` section 1.2.1): which
-- stands carry a seat is a SECOND SYSTEM THAT READS A LAYOUT.
--
-- Pattern: THE LADDER IS THE ENGINE'S OWN. A `TrussPart` is climbed by a Humanoid with no script, no
-- key and no new input owner -- so this works on a thumbstick and on a phone (brief D4). Its size is
-- constrained to 2 x 2 x n, which is why `LADDER_SIZE_STUDS` is 2 and not a number we chose.
--   TrussPart              https://create.roblox.com/docs/reference/engine/classes/TrussPart
--   HumanoidStateType      https://create.roblox.com/docs/reference/engine/enums/HumanoidStateType
-- Luanti's `climbable` node property is the same idea in another engine: climbing is a property of
-- the WORLD, not a control the player learns (https://api.luanti.org/node-definition/, LGPL-2.1+).
--
-- Pattern: DROP TO FLOOR, PER FOOTPRINT CORNER. Valve's `UTIL_DropToFloor` never authors a Y; this
-- reads the ground at EACH of five footprint samples and cuts each leg to its own, which is lesson
-- L-024/L-025 (task 207's ring, task 196's trees) written as a rule rather than as care.
--   https://github.com/ValveSoftware/source-sdk-2013   (game/server/util.cpp, SDK licence)
--
-- Design: docs/design/high-seats.md
-- Note:   docs/research/2026-10-20-high-seats.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
-- THE GRID'S EIGHT CELLS (task 327b). `Grid` requires neither this file nor `ForestTest`, so this is
-- the same one-way seam `ForestTest` itself has (design 4.6).
local Grid = require(ReplicatedStorage:WaitForChild("Grid"))

local HighSeats = {}

-- THE TIMBER, AND IT IS WEATHERED GREY-BROWN BECAUSE THE FIRST ONE WAS LOOKED AT AND FAILED.
--
-- ROUND 1 USED THE LODGE'S OWN LOG TONE (`Lobby.CONFIG.LODGE.LOG_COLOR_ALT`, #58432D) on the
-- reasoning that a seat should be built of the same wood as the house Karen chose. LOOKED AT in the
-- live place -- `<runs-dir>/218-edge-seat2.png`, from a player's eye 11.5 studs south of the seat --
-- it read NEAR BLACK against bright grass, because a dark log standing in the shade of its own deck
-- has nothing left to reflect, and the Director's verdict was that the thing read as a STEEL PYLON
-- rather than as ref-7's wooden hunter's seat. The lodge's logs are varnished and under a roof; a
-- Drueckjagdbock stands out in the weather for years and goes silver-grey. So these are NOT the
-- lodge's numbers and must not be re-unified with them later.
--
-- THREE TONES, EACH WITH A JOB. `TIMBER` is what you see most of -- the four legs and the rail
-- boards. `DECK` is a shade lighter because planks seen face-on catch the sky. `JOINT` is the only
-- dark one and is used ONLY where the structure is already in its own shadow: the girt and the two
-- braces, under the deck. Named here rather than required from `Lobby`, because this module is
-- shared and the lobby is a server system.
HighSeats.COLORS = table.freeze({
	TIMBER = Color3.fromRGB(120, 104, 86),
	DECK = Color3.fromRGB(138, 120, 98),
	JOINT = Color3.fromRGB(96, 82, 66),
})

-- EVERY DIMENSION, IN STUDS, WITH ITS METRES AT `Report.CONFIG.METRES_PER_STUD` 0.28.
-- Design section 4.1. The real-world numbers these answer to are in the research note: a
-- Druckjagdbock sits at 2.50-3.50 m, its platform is at least 1 x 1 m, and UVV wants a rail.
HighSeats.DIMS = table.freeze({
	-- 3.50 m. The deck's TOP FACE above the seat's WORST footprint ground (section 5.1). At the top
	-- of the real 2.50-3.50 m band, because these stands look over a drive rather than into a wood.
	DECK_RISE_STUDS = 12.5,
	-- 1.68 m square, 0.14 thick. 6 x 6 IS `Markers.POST_SIZE`'s footprint, so the post-top
	-- arithmetic `Body.placementFor` already does lands in the middle of the deck with 2 studs clear
	-- all round a 2-stud-wide character. A real deck is 1.2 m; a Roblox body needs the extra.
	DECK_SIZE = Vector3.new(6, 0.5, 6),
	LEG_SECTION_STUDS = 0.5, -- 0.14 m, a real Kantholz of 10-14 cm
	-- Leg CENTRES at (+-2.5, +-2.5), so their outer faces are at 2.75 and sit inside the deck's 3.0.
	LEG_INSET_STUDS = 2.5,
	-- Each foot sunk this far into the voxel surface, so no daylight shows under it. `TreeGround`'s
	-- claw idiom, and the reason rule E's claim has a lower bound as well as an upper one.
	FOOT_EMBED_STUDS = 0.3,
	GIRT_RISE_STUDS = 6.0, -- 1.68 m: the horizontal girt, about half way up
	GIRT_SECTION_STUDS = 0.4,
	BRACE_SECTION_STUDS = 0.35,
	-- The rail board's TOP above the deck top. 0.67 m: it is a SHOOTING REST, not a guard rail, and
	-- section 5.3 is the arithmetic of the one band of shots it blocks. The German guard-rail height
	-- (1.00 m, ASR A2.1) is the deviation, and it is deliberate -- see the note.
	RAIL_RISE_STUDS = 2.4,
	RAIL_BOARD_TALL_STUDS = 0.6, -- a rough board, 0.17 m
	RAIL_BOARD_THICK_STUDS = 0.3,
	-- The board's own centre plane: the leg's outer face at 2.75 plus half the board's 0.15.
	RAIL_PLANE_STUDS = 2.9,
	-- `TrussPart`'s own constrained cross-section (2 x 2 x n). A real ladder is 0.40-0.50 m and this
	-- is 0.56, so the constraint costs nothing.
	LADDER_SIZE_STUDS = 2,
	-- The south face, centred: the ladder is BEHIND the hunter, who faces the drive at +Z.
	LADDER_OFFSET_STUDS = -4.0,
	LADDER_OVER_DECK_STUDS = 1.0, -- the truss runs a stud past the deck so a climber can step off
	-- The opening in the south rail a 2-stud character climbs through.
	LADDER_GAP_STUDS = 2.6,
	-- The furthest footprint point from the stand point: the ladder's own outer corner at (+-1, -5),
	-- which is sqrt(26) = 5.099. `Places.LANE_STUDS` (12) clears it with 6.9 studs to spare, and
	-- `high_seats.spec` asserts that identity rather than describing it.
	FOOTPRINT_RADIUS_STUDS = 5.1,
})

-- HOW MANY PARTS ONE SEAT IS: four legs, ONE girt, two braces, the deck, five rail boards, the
-- ladder. Named so the spec counts against a number this module states rather than against itself.
--
-- 17 -> 14 AFTER THE DIRECTOR'S LOOK (2026-10-20). Round 1 put a girt on all four faces; with the
-- two diagonals and the truss's own default lattice the thing read as a steel pylon rather than as
-- ref-7, which is four posts, a ladder and a platform you can see straight through. The three
-- girts that are gone were the three you could not have seen anyway: the two side ones sit behind
-- the braces and the north one faces the drive, where the ref shows nothing at all. This is a
-- DEVIATION from `docs/design/high-seats.md` section 4.2's seventeen, made on the Director's look.
HighSeats.PARTS_PER_SEAT = 14

-- HOW HIGH A ROBLOX CHARACTER JUMPS. `StarterPlayer.CharacterJumpHeight`'s default, and MEASURED in
-- Karen's Forest Test on 2026-10-20: `CharacterJumpHeight = 7.2`, `CharacterUseJumpPower = false`.
-- It is here because the whole platform rule rests on it (section 5.2): a man on the ground under
-- the seat must not be able to reach `minY` at the top of a jump. `high_seats.spec` asserts
-- `DECK_RISE_STUDS - Match.CONFIG.STAND_HEIGHT_STUDS >= MAX_JUMP_STUDS` (9.0 >= 7.2), so LOWERING
-- THE DECK TRIPS A SPEC instead of silently opening the rule.
HighSeats.MAX_JUMP_STUDS = 7.2

-- HOW FAR APART THE FIVE FOOTPRINT GROUNDS MAY BE before a seat is refused. Over 4 studs one leg is
-- visibly twice its neighbour and the deck is a table on a cliff; the stand then stays a GROUND
-- stand, which is a state this game already has.
HighSeats.MAX_FOOT_SPREAD_STUDS = 4.0

-- WHAT A STAND MUST BUY TO BE WORTH A TOWER (section 6.2). 60 studs is 17 m of extra sight, which at
-- `Boar.CONFIG.PACE`'s trot is about 3.3 s more warning that something is crossing.
HighSeats.MIN_GAIN_STUDS = 60

-- The eye the sight measurement is taken from, and the rise of the AIM ORIGIN above the deck (root
-- +3.5 plus 1.5 to the eye). `AIM_RISE_STUDS` is what section 5.3's blocked band is computed at, and
-- it is MEASURED live rather than assumed -- see the task report.
HighSeats.EYE_STUDS = 5.0
HighSeats.AIM_RISE_STUDS = 5.0

-- WHICH STANDS CARRY A SEAT, PER LAYOUT. FROZEN, so the world is a pure function of the commit --
-- the rule `Places` and `ForestTest.LAYOUTS` already follow.
--
-- MEASURED, NOT CHOSEN (design section 6.2). In Karen's Forest Test on 2026-10-20, every one of the
-- 25 stands of the four layouts was measured: how far a fan of seven rays north reaches from a
-- ground eye against from a deck eye 12.5 studs higher (`gain`), the spread of the five footprint
-- grounds (`spread`), and the relief of the terrain round the stand circle (`relief`). The stands
-- are then ranked by `gain` and taken while the count is under `capFor`, no two are adjacent,
-- `gain >= MIN_GAIN_STUDS`, `spread <= MAX_FOOT_SPREAD_STUDS` and `relief <= JUMP_RELIEF_STUDS`.
--
-- IT WAS MEASURED IN A PLAY SESSION AND NOT IN EDIT, and that matters: the three dressed places are
-- planted at run time (`Workspace.DrivePlaces`, task 193), so an Edit-mode reading would have been
-- taken through a wood that is not there. The Edit run gave `DrivePlaces=ABSENT` and the Play run
-- `DrivePlaces=3`; `ride 3`'s gain moved +157 -> +149 and `track 4`'s +168 -> +125 between them.
--
-- THE GAIN PER ROW IS IN THE COMMENT, so the next reader can see what bought each tower. The spec
-- asserts the SHAPE of this table and never its values, which are Karen's to move.
--
-- SIX SEATS AND NOT NINE, AND THE REASON IS `relief` RATHER THAN TASTE. The cap allows 3/2/2/2; the
-- stands with the biggest gains in three of the four layouts sit on ground that rolls more than
-- `JUMP_RELIEF_STUDS` inside their own circle -- road 2 (gain +232, relief 3.68), edge 3 (+72,
-- 7.91), ride 3 (+149, 4.11), track 4 (+125, 2.44) -- so taking them would have put the platform
-- rule within a jump of the high side. EDGE IS THE ONE EXCEPTION AND IT IS DECLARED: no stand on
-- that line satisfies the relief test at all, so design section 6.2 rule 4 applies -- every place
-- gets a seat -- and `edge 3` is taken on its gain alone. `Seats.takeLine` prints that fact every
-- time it builds, rather than leaving it in this comment only.
--
-- THE EIGHT GRID CELLS ARE THE SAME MEASUREMENT AT A NEW WORLD (task 327b), taken in Karen's place
-- with the same instrument over all 120 stands. Their rows live in `Grid.CELLS[*].towers` -- one
-- writer for the grid's data, and `Grid.towerStands` is read here so this table and that one cannot
-- drift apart. They are keyed by CELL ID, so `Seats.ensure(Grid.layoutFor("A1"))` finds them by the
-- layout's own name exactly as the four shipped rows are found.
local STANDS: { [string]: { number } } = {
	road = table.freeze({ 1, 4, 7 }), -- gains +173, +138, +76 (relief 0.22, 0.32, 1.42)
	edge = table.freeze({ 3 }), -- gain +72; relief 7.91 -- the declared exception, see above
	ride = table.freeze({ 2 }), -- gain +87 (relief 1.22)
	track = table.freeze({ 1 }), -- gain +66 (relief 0.97)
}
for _, id in ipairs(Grid.cellIds()) do
	STANDS[id] = table.freeze(Grid.towerStands(id))
end
HighSeats.STANDS = table.freeze(STANDS)

-- THE LAYOUTS WHOSE SEAT WAS TAKEN WITH THE RELIEF TEST RELAXED (design section 6.2 rule 4). Named
-- as data so the console line and this table cannot drift apart, and so a later measurement that
-- finds a better stand on that line can empty it.
local RELAXED: { [string]: boolean } = { edge = true }
for _, id in ipairs(Grid.cellIds()) do
	-- THE WHOLE OF THE GRID'S ROW 2 (task 327b): 98-173 studs of spread per cell, and not one stand
	-- rolls less than `JUMP_RELIEF_STUDS` inside its own circle. `Grid.CELLS[*].towersRelaxed` is
	-- where the measurement says so; this table cannot drift from it.
	if Grid.towersRelaxed(id) then
		RELAXED[id] = true
	end
end
HighSeats.RELIEF_RELAXED = table.freeze(RELAXED)

-- HOW MUCH THE TERRAIN MAY RISE INSIDE THE STAND CIRCLE before a jump from the high side could read
-- as being on the platform (section 5.2). It is `DECK_RISE_STUDS - STAND_HEIGHT - MAX_JUMP`, which
-- is 12.5 - 3.5 - 7.2 = 1.8, written as its own number so the selection rule and the margin cannot
-- drift apart.
HighSeats.JUMP_RELIEF_STUDS = 1.8

-- HOW MANY SEATS A LAYOUT MAY HAVE. A third of its stands, rounded up: road 3, edge 2, ride 2,
-- track 2 -- so a hunter always has a ground neighbour and the line never reads as a row of towers.
function HighSeats.capFor(standCount: number): number
	return math.ceil(standCount / 3)
end

-- WHICH STANDS, for a layout name. A FRESH COPY, so a caller that sorts its own list cannot sort
-- this table -- the discipline `ForestTest.layoutNames` already follows.
function HighSeats.standsFor(layoutName: string): { number }
	local row = (HighSeats.STANDS :: any)[layoutName]
	if row == nil then
		return {}
	end
	return table.clone(row)
end

function HighSeats.hasSeat(layoutName: string, standIndex: number): boolean
	local row = (HighSeats.STANDS :: any)[layoutName]
	if row == nil then
		return false
	end
	for _, index in ipairs(row) do
		if index == standIndex then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- who gets which stand (task 221)
--
-- KAREN, 2026-10-20: *"Access to tree stand"* -- the high seats became a thing a player BUYS. So:
--
--   A hunter who does not own high-seat access is never placed on a seated stand while any stand
--   he is allowed on is free. He gets a ground stand instead.
--
-- THE WHOLE LINE IS DEALT AT ONCE, AND THAT IS FORCED RATHER THAN TIDY. `Match` places players ONE
-- AT A TIME (`world.placement(markers, team, index, cfg)`), and a per-player rule cannot be
-- collision-free: two hunters independently skipping the same seat land on the same ground stand.
-- So `Match` passes the LINE -- how many are being placed and which of them are entitled -- and
-- this function answers every hunter's stand in one pass (design section 6.2).
--
-- Pattern: SERIAL DICTATORSHIP from the house-allocation literature (Abdulkadiroglu and Sonmez,
-- Econometrica 66(3), 1998) -- agents in a fixed order each take their most preferred item among
-- those still unclaimed AND acceptable to them, which is collision-free by construction. "Not
-- acceptable" is exactly where the entitlement lives. The literature RANDOMISES the order for
-- fairness across draws and we deliberately do not: ours is `indexWithinTeam`'s sorted userIds, so
-- the same roster gets the same stands every drive.
--
-- WHAT IS INVENTED (rule 2): the three-tier fallback. No source assigns scarce PRIVILEGED positions
-- to a roster -- Quake III's `SelectSpawnPoint` family picks per player and tolerates telefrags,
-- which is the collision this must not have, and a general assignment solver is hundreds of lines
-- for a 9x8 problem whose only objective is *entitled first*. The greedy version is provably
-- collision-free (pass 2) and provably identical to today (`entitled == nil`), which a solver would
-- have to be tested into.
--
-- Design: docs/design/economy-v1.md sections 6.2-6.4
-- Note:   docs/research/2026-10-20-money-and-the-v1-catalogue.md
--
-- `walk`     the order stands are offered in: the caller's centre-out sequence over 1..standCount
--            (`ForestTest.standWalk()`), so there is no second walk to drift from `standIndexFor`.
-- `seated`   `seated[s] == true` when stand `s` carries a high seat.
-- `entitled` `entitled[i] ~= false` means "may be dealt a seated stand". nil ANYWHERE is "nobody
--            answered", which is entitled -- `Shop.grantsHighSeat`'s own nil rule, and what keeps
--            an un-wired world dealing exactly as it does today.
-- `count`    how many hunters to deal for.
-- `picks` IS WHAT EACH HUNTER TOOK ON THE MAP, BY LINE INDEX (task 323). nil at an index is "he took
-- nothing", which takes the three passes below exactly as they are. nil ENTIRELY -- the DEV place, a
-- spec, any caller written before this argument -- is today's deal, value for value.
function HighSeats.dealLine(
	walk: { number },
	seated: { [number]: boolean },
	entitled: { boolean? }?,
	count: number,
	picks: { number? }?
): { number }
	local taken: { [number]: boolean } = {}
	local out: { number } = {}
	-- AN EMPTY WALK IS NO LINE AT ALL (the Reviewer's round-1 note). Unreachable today -- every
	-- `ForestTest.LAYOUTS` row has `standCount >= 1` -- but the walk is a PARAMETER of a pure
	-- function, and without this pass 3 would index `walk[1]`, get nil, and throw *table index is
	-- nil* on the line below it.
	if #walk == 0 then
		return out
	end
	local total = math.max(0, math.floor(count))
	-- WHICH STANDS THE WALK ACTUALLY STATES, so a claim of a stand this layout does not have cannot
	-- enter the deal (the server refuses it at the request too; this is the belt `high-seats.md`
	-- section 5.2 already wears for the entitlement).
	local inWalk: { [number]: boolean } = {}
	for _, stand in ipairs(walk) do
		inWalk[stand] = true
	end
	-- SWEEP A: EVERY VALID PICK, IN LINE-INDEX ORDER, BEFORE ANYBODY TAKES ANYTHING BY FALLBACK
	-- (task 323, D4). Two sweeps and not one pass: with one pass, hunter 1 (no pick) takes `walk[1]`
	-- on his turn and hunter 3's claim of `walk[1]` is then refused by the fallback -- a claim losing
	-- to a man who claimed nothing, which is the inverse of the rule. Two sweeps make a pick
	-- STRICTLY STRONGER than the fallback, which is what "first request wins and the rest fill what
	-- is left" means.
	--
	-- THE ENTITLEMENT IS CHECKED HERE AS WELL AS AT THE REQUEST, on purpose: the request check is the
	-- one the player sees, this one is the one a forged `FireServer` meets.
	if picks ~= nil then
		for index = 1, total do
			local wanted = (picks :: { number? })[index]
			if wanted ~= nil and inWalk[wanted] and not taken[wanted] then
				local allowSeat = entitled == nil or entitled[index] ~= false
				if allowSeat or not seated[wanted] then
					taken[wanted] = true
					out[index] = wanted
				end
			end
		end
	end
	-- SWEEP B: TODAY'S THREE PASSES, over the indices sweep A did not fill. Unchanged, line for line.
	for index = 1, total do
		if out[index] ~= nil then
			continue
		end
		local allowSeat = entitled == nil or entitled[index] ~= false
		local got: number? = nil
		-- PASS 1: the first free stand he is ALLOWED on. With everybody entitled this is always
		-- `walk[index]`, which is `ForestTest.standIndexFor(index)` -- today's game, bit for bit.
		for _, stand in ipairs(walk) do
			if not taken[stand] and (allowSeat or not seated[stand]) then
				got = stand
				break
			end
		end
		-- PASS 2: the first free stand AT ALL. A hunter with no stand is worse than a hunter on a
		-- seat he did not pay for -- AND this is what makes "no new collisions" exact rather than
		-- approximate. MEASURED: without it, five unentitled hunters on `edge` (5 stands, the seat
		-- on 3) get 2, 4, 1, 5, 5 -- two men on one stand, where today all five fit. Eight shooters
		-- is reachable at `MAX_PLAYERS` 16, so that is a real new collision. With it the fifth man
		-- is given the seat instead: 2, 4, 1, 5, 3. The seat is given away rather than a stand
		-- shared, which is the design's own ordering.
		if got == nil then
			for _, stand in ipairs(walk) do
				if not taken[stand] then
					got = stand
					break
				end
			end
		end
		-- PASS 3: every stand is taken, so this is the wrap -- and it is TODAY'S ANSWER, because
		-- `walk` is `standIndexFor`'s sequence and `standIndexFor` wraps on the same modulo.
		if got == nil then
			got = walk[((index - 1) % math.max(1, #walk)) + 1]
		end
		taken[got :: number] = true
		out[index] = got :: number
	end
	return out
end

-- WHICH WAY THE SEAT IS TURNED, as a SIGN along Z and never a branch on a caller's name: +1 is the
-- shipped seat (the hunter faces +Z, the ladder and the rail's gap behind him at -Z) and -1 mirrors
-- the ladder, the rail's gap and the ladder's own ground sample to the other face -- AND NOTHING
-- ELSE. `Range.standFacing` is the one caller that passes -1 (design shooting-range-lobby 7.1):
-- the range's ladder must be UPRANGE, so the solid rail board is the shooting rest downrange.
function HighSeats.facingOf(facing: number?): number
	return if facing == -1 then -1 else 1
end

-- WHERE THE FIVE FOOTPRINT SAMPLES ARE, as flat offsets from the stand point: the four leg centres
-- and the ladder's own foot. PURE, so the reader loop has nothing to get wrong and the spec names
-- the same five points the build does. ORDER IS PART OF THE INTERFACE: `plan`'s `grounds` is in it.
-- The four legs are symmetric, so `facing` moves the FIFTH sample only.
function HighSeats.footprint(facing: number?): { { dx: number, dz: number } }
	local inset = HighSeats.DIMS.LEG_INSET_STUDS
	return {
		{ dx = -inset, dz = -inset },
		{ dx = -inset, dz = inset },
		{ dx = inset, dz = -inset },
		{ dx = inset, dz = inset },
		{ dx = 0, dz = HighSeats.facingOf(facing) * HighSeats.DIMS.LADDER_OFFSET_STUDS },
	}
end

function HighSeats.footprintRadiusStuds(): number
	return HighSeats.DIMS.FOOTPRINT_RADIUS_STUDS
end

-- THE WORST CORNER, AND IT IS LOAD-BEARING RATHER THAN TASTE. `TreeGround` plants a trunk at the
-- LOWEST ground under its footprint, because a tree with daylight under it is the defect it exists
-- to stop. A seat is the opposite case: the deck's Y is also the platform rule's own line
-- (`minYFor`), so referencing the HIGHEST foot makes "nobody standing under this seat is above the
-- line" arithmetic instead of hope.
--
-- IT WALKS BY INDEX AND NOT WITH `ipairs`, AND A SPEC CAUGHT THAT (the full run at `6b6999a`).
-- `ipairs` STOPS AT THE FIRST NIL, so `{140, 142, nil, 141, 143}` -- a world that could read four
-- of its five footprint samples -- answered `142 + 12.5` instead of nil, and `plan` then went on to
-- build a seat with a leg whose ground it never had. A hole in the readings is exactly the case
-- this function exists to refuse, so it has to be able to SEE one.
function HighSeats.deckTopFor(grounds: { number? }): number?
	local highest: number? = nil
	for index = 1, #HighSeats.footprint() do
		local y = grounds[index]
		if type(y) ~= "number" then
			return nil
		end
		if highest == nil or (y :: number) > (highest :: number) then
			highest = y
		end
	end
	if highest == nil then
		return nil
	end
	return (highest :: number) + HighSeats.DIMS.DECK_RISE_STUDS
end

-- BY INDEX, for `deckTopFor`'s reason: `ipairs` cannot see a hole, and a hole is the thing to
-- refuse.
function HighSeats.spreadOf(grounds: { number? }): number?
	local low: number?, high: number? = nil, nil
	for index = 1, #HighSeats.footprint() do
		local y = grounds[index]
		if type(y) ~= "number" then
			return nil
		end
		if low == nil or (y :: number) < (low :: number) then
			low = y
		end
		if high == nil or (y :: number) > (high :: number) then
			high = y
		end
	end
	if low == nil or high == nil then
		return nil
	end
	return (high :: number) - (low :: number)
end

-- WHERE THE PLATFORM RULE'S LINE IS: THE DECK'S OWN TOP FACE, with no margin (design section 5.2).
--
-- A MARGIN WAS PROPOSED AND IT IS WRONG. `reviews/task-218/BRIEF.md` D3 asks for `deckTop - 2` on
-- the reasoning that "a jump reaches about 4-5 studs". A Roblox character's jump is 7.2 studs
-- (`MAX_JUMP_STUDS`, measured), so a man standing in the seat's own footprint reaches
-- `footY + 3.5 + 7.2 = footY + 10.7` at his apex and a line at `footY + 10.5` is REACHED. The deck's
-- own face is at `footY + 12.5`: 1.8 studs clear of the apex, and 3.5 under a man standing on the
-- deck (root `deckTop + 3.5`). One number, one meaning -- *your root is above the deck you are
-- supposed to be standing on* -- with nothing to tune.
function HighSeats.minYFor(deckTopY: number): number
	return deckTopY
end

-- ---------------------------------------------------------------- the rail, and what it blocks
--
-- A hunter on the deck must be able to shoot OUT OVER the rail, which is what ref-7 shows. The rail
-- is a BOARD WITH OPEN SPACE UNDER IT, and that is what makes it work: a steep shot passes UNDER the
-- board, a flat shot passes OVER it, and only a narrow band of angles meets it. A real Hochsitz has
-- the same blind ring, for the same reason.
--
-- `aimRise` is the aim origin's height above the deck, `dropStuds` how far below the deck the target
-- is, `rangeStuds` the flat distance to it.
local function railTangents(aimRise: number): (number, number)
	local dims = HighSeats.DIMS
	local top = dims.RAIL_RISE_STUDS
	local bottom = dims.RAIL_RISE_STUDS - dims.RAIL_BOARD_TALL_STUDS
	local plane = dims.RAIL_PLANE_STUDS
	-- Shallower than this and the shot is OVER the board; steeper than the second and it is UNDER.
	return (aimRise - top) / plane, (aimRise - bottom) / plane
end

function HighSeats.clearsRail(aimRise: number, dropStuds: number, rangeStuds: number): boolean
	if rangeStuds <= 0 then
		return true -- straight down, inside the deck's own footprint: the board is not in the way
	end
	local over, under = railTangents(aimRise)
	local tangent = dropStuds / rangeStuds
	return tangent <= over or tangent >= under
end

-- THE ANNULUS THE RAIL BLOCKS, as (near, far) in studs. At the measured `AIM_RISE_STUDS` of 5.0 and
-- a 12.5-stud drop this is 11.3 to 13.9 -- 2.6 studs wide, 3.2 m to 3.9 m, directly beneath him.
-- Returns 0, 0 when the aim origin is at or below the board, which no seat produces.
function HighSeats.blockedBand(aimRise: number, dropStuds: number): (number, number)
	local over, under = railTangents(aimRise)
	if over <= 0 or under <= 0 then
		return 0, 0
	end
	return dropStuds / under, dropStuds / over
end

-- ---------------------------------------------------------------- the seat, as PARTS_PER_SEAT pieces

export type Piece = {
	name: string,
	class: string, -- "Part" | "TrussPart"
	size: Vector3,
	cframe: CFrame, -- WORLD, built from the stand point and the five measured grounds
	material: Enum.Material,
	color: Color3,
	canCollide: boolean,
	canQuery: boolean,
	castShadow: boolean,
	-- `TrussPart.Style` ONLY, and nil for every `Part`. See the ladder in `plan` for why it exists.
	style: Enum.Style?,
}

-- EVERY PIECE COLLIDES AND EVERY PIECE IS QUERYABLE, which is the deliberate opposite of every other
-- part this world builds -- and the two rules are the same rule.
--
-- `ForestTest.Markers.marker` and `Markers.ring` both set `CanQuery = false`, and their comments say
-- why: *"a slab that stops a pellet changes what the shot hit, and what the shot hit is what
-- `Penalty.judge` reads"*. A marker and a ring are REFERENCES, NOT THINGS: invisible, decided by
-- nobody's eye, and a pellet that stopped on one would have stopped on an idea. A DECK IS A THING.
-- A hunter stands on it, Karen looks at it, and a shot that passed through a 0.14 m timber deck
-- would be the same fault inverted -- the world telling the weapon that something she can see is not
-- there. `Lobby.Build` already makes this split: its cosmetics are `solid = false` and the lodge's
-- own shell is not.
local function piece(
	name: string,
	class: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3
): Piece
	return {
		name = name,
		class = class,
		size = size,
		cframe = cframe,
		material = material,
		color = color,
		canCollide = true,
		canQuery = true,
		castShadow = true,
		style = nil,
	}
end

-- A box from its own bottom face: the one place this module turns a ground reading into a centre, so
-- "the bottom of this post is at that ground" is written once.
local function upright(name: string, section: number, bottomY: number, topY: number, x: number, z: number): Piece
	local height = topY - bottomY
	return piece(
		name,
		"Part",
		Vector3.new(section, height, section),
		CFrame.new(x, bottomY + height / 2, z),
		Enum.Material.Wood,
		HighSeats.COLORS.TIMBER
	)
end

-- THE WHOLE SEAT. `grounds` is the five readings in `footprint()` order. Returns nil and a REASON
-- for a seat that must not be built -- a reading the world could not make, or a footprint spread
-- over the cap -- and never a partial seat: a seat with three legs is worse than no seat.
--
-- DETERMINISTIC: the same arguments twice give the same pieces, so a frame Karen judges
-- can be rebuilt from a commit and a defect can be bisected.
--
-- `facing` is `facingOf`'s sign: -1 mirrors the ladder, the rail's gap and the ladder's ground
-- sample, and nothing else. `grounds` is in `footprint(facing)` order, so the fifth reading is
-- always the ladder's own foot.
function HighSeats.plan(stand: Vector3, grounds: { number? }, facing: number?): ({ Piece }?, string?)
	-- NO `#grounds` GUARD. `#` on a table with a hole is not defined to be either count in Luau, so
	-- a list that is short and a list that is holed are the SAME question -- "is every one of the
	-- five samples a number" -- and `deckTopFor` is the one place that asks it.
	local deckTopY = HighSeats.deckTopFor(grounds)
	if deckTopY == nil then
		return nil, "ground: a footprint sample could not be read"
	end
	local spread = HighSeats.spreadOf(grounds)
	if spread == nil then
		return nil, "ground: a footprint sample could not be read"
	end
	if (spread :: number) > HighSeats.MAX_FOOT_SPREAD_STUDS then
		return nil, string.format("spread: %.2f studs over %.1f", spread, HighSeats.MAX_FOOT_SPREAD_STUDS)
	end

	local dims = HighSeats.DIMS
	local deck = deckTopY :: number
	local sign = HighSeats.facingOf(facing)
	local samples = HighSeats.footprint(facing)
	local embed = dims.FOOT_EMBED_STUDS
	-- The four legs are the rail posts as well, so they all end at ONE number and the deck is level
	-- by construction rather than by a tolerance.
	local legTopY = deck + dims.RAIL_RISE_STUDS
	-- The worst foot, which is what the girts and the braces are measured from: a girt referenced to
	-- each leg's own ground would be a sloping girt on sloping ground.
	local footY = deck - dims.DECK_RISE_STUDS
	local pieces: { Piece } = {}

	for index = 1, 4 do
		local offset = samples[index]
		local ground = grounds[index] :: number
		table.insert(
			pieces,
			upright(
				string.format("Leg%d", index),
				dims.LEG_SECTION_STUDS,
				ground - embed,
				legTopY,
				stand.X + offset.dx,
				stand.Z + offset.dz
			)
		)
	end

	-- THE GIRTS: one horizontal timber per side, about half way up, which is what stops four posts
	-- reading as four sticks. North and south span the full width; east and west butt inside them.
	local inset = dims.LEG_INSET_STUDS
	local girtY = footY + dims.GIRT_RISE_STUDS
	local girtSection = dims.GIRT_SECTION_STUDS
	local girtSpan = inset * 2 + dims.LEG_SECTION_STUDS
	-- ONE GIRT, ON THE SOUTH FACE, AND NOT FOUR (the Director's look, 2026-10-20). Round 1 put a
	-- horizontal on all four faces and a diagonal on two, and the result read as a LATTICE -- a
	-- steel pylon rather than ref-7's four posts. The ref has a frame you can see straight through.
	-- The south face is the one with the ladder against it, so a tie there is the one that reads as
	-- carpentry rather than as structure; `JOINT` because it sits in the seat's own shadow.
	table.insert(
		pieces,
		piece(
			"Girt",
			"Part",
			Vector3.new(girtSpan, girtSection, girtSection),
			CFrame.new(stand.X, girtY, stand.Z - inset),
			Enum.Material.Wood,
			HighSeats.COLORS.JOINT
		)
	)

	-- THE BRACES: one diagonal on each of the two side faces, placed with `CFrame.fromMatrix` along
	-- its own chord -- `Markers.ring`'s own idiom, so a sloping timber is drawn the one way this
	-- repo draws sloping timber.
	local braceLowY = footY + 1
	local braceHighY = footY + dims.DECK_RISE_STUDS - 1.5
	for _, row in ipairs({
		{ name = "BraceE", dx = inset },
		{ name = "BraceW", dx = -inset },
	}) do
		local from = Vector3.new(stand.X + row.dx, braceLowY, stand.Z - inset)
		local to = Vector3.new(stand.X + row.dx, braceHighY, stand.Z + inset)
		local span = to - from
		local along = span.Unit
		local across = Vector3.new(1, 0, 0)
		local up = along:Cross(across)
		table.insert(
			pieces,
			piece(
				row.name,
				"Part",
				Vector3.new(span.Magnitude, dims.BRACE_SECTION_STUDS, dims.BRACE_SECTION_STUDS),
				CFrame.fromMatrix((from + to) / 2, along, up.Unit),
				Enum.Material.Wood,
				HighSeats.COLORS.JOINT
			)
		)
	end

	-- THE DECK, whose TOP face is `deckTopY` -- the number `minYFor` reads and the number
	-- `Markers.build` puts the stand's post at.
	table.insert(
		pieces,
		piece(
			"Deck",
			"Part",
			dims.DECK_SIZE,
			CFrame.new(stand.X, deck - dims.DECK_SIZE.Y / 2, stand.Z),
			Enum.Material.WoodPlanks,
			HighSeats.COLORS.DECK
		)
	)

	-- THE RAIL: one board on each face, with a gap in the south one for the ladder. Its TOP is
	-- `RAIL_RISE_STUDS` above the deck, which is what `clearsRail` is computed from.
	local railCentreY = deck + dims.RAIL_RISE_STUDS - dims.RAIL_BOARD_TALL_STUDS / 2
	local plane = dims.RAIL_PLANE_STUDS
	local tall = dims.RAIL_BOARD_TALL_STUDS
	local thick = dims.RAIL_BOARD_THICK_STUDS
	local width = dims.DECK_SIZE.X
	table.insert(
		pieces,
		piece(
			"RailN",
			"Part",
			Vector3.new(width, tall, thick),
			CFrame.new(stand.X, railCentreY, stand.Z + sign * plane),
			Enum.Material.Wood,
			HighSeats.COLORS.TIMBER
		)
	)
	for _, row in ipairs({
		{ name = "RailE", dx = plane },
		{ name = "RailW", dx = -plane },
	}) do
		table.insert(
			pieces,
			piece(
				row.name,
				"Part",
				Vector3.new(thick, tall, width - thick * 2),
				CFrame.new(stand.X + row.dx, railCentreY, stand.Z),
				Enum.Material.Wood,
				HighSeats.COLORS.TIMBER
			)
		)
	end
	-- The two stubs of the LADDER'S OWN FACE, leaving `LADDER_GAP_STUDS` between them for a 2-stud
	-- character to climb through: each runs from the gap's edge to the deck's own edge. The names
	-- `RailN`/`RailS*` are the DEFAULT facing's compass; at `facing = -1` the pair swap faces with
	-- the ladder and the names describe their ROLE -- solid board, gapped board (design 7.1).
	local stubWidth = (width - dims.LADDER_GAP_STUDS) / 2
	local stubCentre = dims.LADDER_GAP_STUDS / 2 + stubWidth / 2
	for _, row in ipairs({
		{ name = "RailSE", dx = stubCentre },
		{ name = "RailSW", dx = -stubCentre },
	}) do
		table.insert(
			pieces,
			piece(
				row.name,
				"Part",
				Vector3.new(stubWidth, tall, thick),
				CFrame.new(stand.X + row.dx, railCentreY, stand.Z - sign * plane),
				Enum.Material.Wood,
				HighSeats.COLORS.TIMBER
			)
		)
	end

	-- THE LADDER: the engine's own, so there is no control to learn and nothing to write. Its top
	-- runs a stud past the deck so a climber can step off, and its foot is sunk like every other.
	--
	-- `Style = NoSupports`, AND THAT ONE PROPERTY IS MOST OF WHY ROUND 1 READ AS A PYLON.
	-- `TrussPart`'s default is `AlternatingSupports`, which draws a DIAGONAL X-LATTICE down every
	-- 2 x 2 x 2 section -- the look of a transmission tower or a scaffold, and the single loudest
	-- shape in `<runs-dir>/218-edge-seat2.png`. `NoSupports` draws the corner posts and the rungs
	-- and nothing else, which is a LADDER. The climb is unchanged: a Humanoid climbs a `TrussPart`
	-- because of its CLASS, not its style, so brief D4 still holds and no input owner moves.
	--   Enum.Style   https://create.roblox.com/docs/reference/engine/enums/Style
	local ladderFootY = (grounds[5] :: number) - embed
	local ladderTopY = deck + dims.LADDER_OVER_DECK_STUDS
	local ladder = piece(
		"Ladder",
		"TrussPart",
		Vector3.new(dims.LADDER_SIZE_STUDS, ladderTopY - ladderFootY, dims.LADDER_SIZE_STUDS),
		CFrame.new(stand.X, (ladderFootY + ladderTopY) / 2, stand.Z + sign * dims.LADDER_OFFSET_STUDS),
		Enum.Material.Wood,
		HighSeats.COLORS.TIMBER
	)
	ladder.style = Enum.Style.NoSupports
	table.insert(pieces, ladder)

	return pieces, nil
end

-- EVERY LAYOUT NAME THIS MODULE KNOWS, for a spec that wants to walk them without reaching into the
-- frozen table. `ForestTest.LAYOUT_ORDER` is the authority on what the four are.
function HighSeats.layoutNames(): { string }
	return Forest.layoutNames()
end

return HighSeats
