--!strict
-- Match.Roster: who is on which team. PURE: no services, no Instances, no clock, no Random, and it
-- never knows what a Player is -- it keys by userId, exactly as Weapon.Registry does
-- (docs/design/shotgun.md section 5.3). That is what lets tests/server/match_roster.spec.luau check
-- every roster size from 2 to 16 in microseconds with no players at all.
--
-- DETERMINISTIC BY CONSTRUCTION: the userIds are sorted before they are split, so the same roster
-- gives the same assignment on every server and in every spec run. A Random here would make the one
-- rule Karen cares about ("equal teams") unreproducible in a bug report.
--
-- Design: docs/design/drive.md (section 5.2), docs/design/role-rotation.md (section 4.1)
-- Note:   docs/research/2026-09-25-drive.md, docs/research/2026-10-20-role-rotation.md
local Roster = {}

export type TeamName = "Drivers" | "Shooters"
export type Assignment = { [number]: TeamName }

local DRIVERS: TeamName = "Drivers"
local SHOOTERS: TeamName = "Shooters"

function Roster.counts(assignment: Assignment): { [string]: number }
	local counts = { Drivers = 0, Shooters = 0 }
	for _, team in pairs(assignment) do
		counts[team] += 1
	end
	return counts
end

-- The team that needs the next player. A tie goes to ODD_PLAYER_TEAM, which is what makes a
-- two-player drive one driver and one shooter rather than two of anything.
function Roster.smallerTeam(counts: { [string]: number }, config): TeamName
	local drivers = counts.Drivers or 0
	local shooters = counts.Shooters or 0
	if drivers < shooters then
		return DRIVERS
	elseif shooters < drivers then
		return SHOOTERS
	end
	return config.ODD_PLAYER_TEAM
end

-- ---------------------------------------------------------------- the stored turn (task 217)
--
-- KAREN, 2026-10-11: *"ROLES ROTATE: you start as a hunter, next round you are a beater; it is
-- REMEMBERED across logout/login (no cheating back to hunter)"*.
--
-- THE FOUR FUNCTIONS BELOW ARE TASK 217'S. `Roster.assign` WAS left untouched by that task, and
-- task 221 round 3 rewrote it at the Director's decision -- see its own header for the
-- measurement that overruled the argument this sentence used to make:
-- its algorithm, its `|Drivers - Shooters| <= 1` balance check and its plain-split fallback are
-- what tests/server/match_roster.spec.luau pins at every roster size from 2 to 16, and rewriting a
-- pinned pure function to add a feature is a bigger change than the feature. The stored turn is
-- folded in as a SYNTHETIC `previous` instead.
--
-- Design: docs/design/role-rotation.md (sections 4.1, 5.3)
-- Note:   docs/research/2026-10-20-role-rotation.md

-- PURE. The other side. nil in, nil out -- and that is load-bearing, not politeness: the input is
-- sometimes a value that came off a DataStore key, so a corrupted row must DROP rather than invent
-- a team.
function Roster.other(team: TeamName?): TeamName?
	if team == DRIVERS then
		return SHOOTERS
	elseif team == SHOOTERS then
		return DRIVERS
	end
	return nil
end

-- PURE. Every row flipped, as a NEW table. The input is never written: it is usually
-- `state.assignment`, which `Phase.freezeState` has frozen.
--
-- IT IS WHAT THE END OF A DRIVE STORES (design section 5.2, edge 2): the role he is owed next is the
-- other one from the role he ACTUALLY played, which is what makes "the turn is not consumed when the
-- balance rule overrules it" structural rather than bookkeeping -- a man owed beater who was made a
-- hunter is written beater again, with no second field and no "was it honoured" flag to get wrong.
function Roster.invert(assignment: Assignment): Assignment
	local out: Assignment = {}
	for userId, team in pairs(assignment) do
		local other = Roster.other(team)
		if other then
			out[userId] = other
		end
	end
	return out
end

-- PURE. THE STORED TURN, FOLDED IN AS A SYNTHETIC `previous`.
--
--   * `owed` nil or EMPTY -> `previous` is returned BY IDENTITY. Nothing is allocated, and the game
--     is bit-for-bit what it was before this task: that identity IS the flag-off story (design
--     section 7) and a spec asserts the raw table equality rather than a deep compare.
--   * otherwise -> a NEW table: `previous`'s rows, with `other(owed[u])` written over the row of
--     every player who is owed a turn. `previous` may be nil, and then the result holds only the
--     owed rows -- which is what makes the FIRST drive after a rejoin honour the turn, because a
--     rejoiner has no previous row by definition.
--
-- THE INVERSION IS HERE AND ONLY HERE, AND IT IS THE ONE TRAP IN THIS DESIGN (design section 4.1,
-- hazard 9): `Roster.assign`'s swap gives a player the OPPOSITE of his `previous` row, so to land
-- him on the team he is OWED the synthetic row must be the other one. `Roster.joinTeam` below does
-- NOT invert, because it places a man directly.
function Roster.previousFrom(previous: Assignment?, owed: { [number]: TeamName }?): Assignment?
	if owed == nil or next(owed) == nil then
		return previous
	end
	-- A CLONE, so neither input is written: `previous` is usually `state.previousAssignment`, which
	-- `Phase.freezeState` has frozen, and `owed` is the economy's frozen memo.
	local out: Assignment = table.clone(previous or {})
	for userId, team in pairs(owed) do
		local synthetic = Roster.other(team)
		if synthetic then
			out[userId] = synthetic
		end
	end
	return out
end

-- PURE. WHICH TEAM A LATE ARRIVAL GETS. `Roster.smallerTeam` unless the two sides are EQUAL, in
-- which case the owed team costs the balance nothing and wins -- the result differs by one either
-- way. Off a tie the smaller team wins and the turn is simply not consumed.
--
-- `owed` nil answers `smallerTeam` EXACTLY, which is this question before task 217.
--
-- IT MATTERS MORE THAN IT LOOKS: since tasks 177 and 209 a player walks onto a truck pad during the
-- intermission, so the `join` branch is now the NORMAL way into a drive rather than an edge case
-- (design section 8.5).
function Roster.joinTeam(counts: { [string]: number }, owed: TeamName?, config): TeamName
	if owed ~= nil and (counts.Drivers or 0) == (counts.Shooters or 0) then
		return owed
	end
	return Roster.smallerTeam(counts, config)
end

-- ---------------------------------------------------------------- the bought preference (task 221)
--
-- KAREN, 2026-10-20: *"Posibility to be a hunter always"*.
--
-- PURE. The team each player WANTS: his stored turn with the privilege written over it.
--
-- IT IS NOT A THIRD ARGUMENT TO `Roster.previousFrom`, and the reason is that `previousFrom`'s
-- whole job is *the stored TURN folded in as a synthetic previous* -- it carries the one trap in
-- task 217 (the inversion) and adding the privilege to it would make one function answer two
-- questions. Two separable facts stay separable, which is also what lets `Roster.overruled` tell
-- the man WHY when the balance beats him.
--
--   * `always` nil or EMPTY -> `owed` is returned BY IDENTITY. Nothing is allocated and the game is
--     bit-for-bit what it was before this task, which IS the flag-off story -- the same device
--     `Roster.previousFrom` uses, and a spec asserts the raw table equality.
--   * otherwise -> a NEW table: `owed`'s rows, with `Shooters` written over every always-hunter.
--     `owed` may be nil, and then the result holds only the bought rows.
--
-- IT DOES NOT INVERT. The inversion is `previousFrom`'s and stays there, and only there: this
-- answers the team he WANTS, and `previousFrom` is what turns that into the synthetic previous row
-- `Roster.assign`'s swap needs.
function Roster.owedWith(owed: { [number]: TeamName }?, always: { [number]: boolean }?): { [number]: TeamName }?
	if always == nil or next(always) == nil then
		return owed
	end
	local out: { [number]: TeamName } = table.clone(owed or {})
	for userId, bought in pairs(always) do
		if bought == true then
			out[userId] = SHOOTERS
		end
	end
	return out
end

-- ------------------------------------------------------- the one-drive opt-out (task 229)
--
-- KAREN, 2026-10-21: *"we also need to have posibility to choose once you have a card always hunter
-- maybe sometimes I want to be a beater we need to find a way to do that"*.
--
-- PURE. The team each player WANTS, with a ONE-DRIVE `BEATER` wish written over the privilege.
--
-- IT IS THE MIRROR OF `Roster.owedWith` AND IS APPLIED AFTER IT, so the three facts stack in the
-- order that reads as a sentence: the stored TURN is what the rotation owes him, the bought PLACE
-- beats that, and his own WISH beats the thing he bought -- because he is the one who bought it.
--
--   * `wishes` nil or EMPTY -> `owed` is returned BY IDENTITY. Nothing is allocated and the game is
--     bit-for-bit what it was before this task, which IS the switch-off story (design section 12):
--     the same device `Roster.previousFrom` and `Roster.owedWith` already use, and a spec asserts
--     the raw table equality rather than a deep compare.
--   * otherwise -> a NEW table: `owed`'s rows with `Drivers` written over every wisher. `owed` may
--     be nil, and then the result holds only the wishers' rows.
--
-- IT DOES NOT CHECK OWNERSHIP, and it must not: this is `Roster`, which is pure and keys by userId,
-- and whether a man owns `ALWAYS HUNTER` is a fact only the server's own door can measure
-- (`Lobby.onRoleRequest` check 4). A wish for a man who owns nothing simply never reaches here.
--
-- IT DOES NOT INVERT, for `owedWith`'s own stated reason: the inversion is `previousFrom`'s and
-- stays there.
function Roster.wishedWith(owed: { [number]: TeamName }?, wishes: { [number]: boolean }?): { [number]: TeamName }?
	if wishes == nil or next(wishes) == nil then
		return owed
	end
	local out: { [number]: TeamName } = table.clone(owed or {})
	for userId, asked in pairs(wishes) do
		if asked == true then
			out[userId] = DRIVERS
		end
	end
	return out
end

-- PURE. WHICH OF THESE WISHES THE ASSIGNMENT ACTUALLY SEATED, folded into what is already recorded.
--
-- IT EXISTS BECAUSE THE WISH IS SPENT BY THE VERY ASSIGNMENT IT IS ABOUT (review round 1, finding
-- 1). `Lobby.wishFor` answers `HUNTER` the moment `Match.assignmentOf` names a team, so the live
-- memo is EMPTY one lobby scan (0.1 s) after `enterAssigning` -- while `Roster.overruled` is asked
-- again on every dispatch for the whole 15 s intermission. Reading the live memo there told the man
-- who had just pressed BEATER *"TEAMS MUST BE EVEN - you beat this drive"*, which is the exact
-- opposite of what the third argument is for.
--
-- SO THE ANSWER IS PINNED TO THE ASSIGNMENT IT IS ABOUT, and the rule is here rather than in the
-- owner because it is pure and because a spec can then drive the one sequence that matters: seat
-- him while the memo still holds him, then hand it the EMPTY memo and see the record stand.
--
-- IT IS WRITTEN IN PLACE AND RETURNED. `Match.dispatch` calls it on every event, which while
-- TASKS.md 214a(a) is open can be ~15x `MATCH_STEP_HZ`, so a new table per call would be the churn
-- `Economy.alwaysHunters`' memo exists to avoid. The caller owns the table's LIFETIME (one drive);
-- this owns only what goes in it.
--
-- IT ONLY EVER ADDS, and that is the point: a mid-drive `join` assigns ONE man off a memo that no
-- longer holds the wishes already spent at `enterAssigning`, so a rule that replaced the record
-- would hand every earlier wisher back to `Roster.overruled` one scan later.
--
-- `wishes` nil or EMPTY ADDS NOTHING, so a build with no lobby never writes a row.
function Roster.recordSeated(
	record: { [number]: boolean },
	wishes: { [number]: boolean }?,
	assignment: Assignment
): { [number]: boolean }
	if wishes == nil then
		return record
	end
	for userId, asked in pairs(wishes) do
		-- SEATED, not merely asked: a wisher the roster has not dealt yet is not a man anything can
		-- say was or was not overruled.
		if asked == true and assignment[userId] ~= nil then
			record[userId] = true
		end
	end
	return record
end

-- PURE. WHOSE PRIVILEGE THE BALANCE RULE OVERRULED: the always-hunters whose FINAL team is
-- `Drivers`.
--
-- A man who paid $2000 for the hunter's place and starts a drive with a horn, with no explanation,
-- reads the purchase as broken and says so. This is the list the drive publishes so the Hud can
-- tell him why -- and it is computed from the assignment that was actually made, so it can never
-- disagree with the team he is on.
--
-- A LIST, SORTED, so the wire is a dense array -- the shape `tied` and `through` already have.
--
-- `wishes` IS THE MEN WHO ASKED TO BEAT (task 229), AND IT IS A CORRECTION THIS FEATURE WOULD
-- OTHERWISE HAVE NEEDED LATER. A wisher is in `always` and finishes on `Drivers`, so without this
-- argument his name would go on the wire and his own Hud would tell him the balance rule beat the
-- place he paid for -- when in fact he asked for it, on this screen, half a minute ago. The whole
-- point of this list is to say WHY, so a wrong why is worse than no list.
--
-- `wishes` nil answers today's question BY IDENTITY, which is the switch-off story again.
function Roster.overruled(
	assignment: Assignment,
	always: { [number]: boolean }?,
	wishes: { [number]: boolean }?
): { number }
	local out: { number } = {}
	if always == nil then
		return out
	end
	for userId, bought in pairs(always) do
		if bought == true and assignment[userId] == DRIVERS and not (wishes ~= nil and wishes[userId] == true) then
			table.insert(out, userId)
		end
	end
	table.sort(out)
	return out
end

local function sorted(userIds: { number }): { number }
	local out = table.clone(userIds)
	table.sort(out)
	return out
end

-- HOW MANY OF THIS ROSTER MAY BE HUNTERS. PURE. The split differs by at most one, and the odd man
-- goes to `ODD_PLAYER_TEAM` -- so this is the same arithmetic the plain split below does, named
-- once because the always-hunter pass has to know the number before it deals anybody.
function Roster.shooterSlots(total: number, config): number
	local count = math.max(0, math.floor(total))
	if config.ODD_PLAYER_TEAM == SHOOTERS then
		return math.ceil(count / 2)
	end
	return math.floor(count / 2)
end

-- WHO GIVES UP THE HUNTER'S PLACE FIRST when more men bought it than there are hunter slots. PURE.
-- The front of this list yields.
--
-- THE KEY IS "DID HE HAVE IT LAST DRIVE", and that is a deliberate reading of the Director's
-- *"fewest drives as always-hunter yield first"* rather than the literal one. Taken literally --
-- order by a count of drives served as an always-hunter, lowest first -- the man at the bottom
-- NEVER accumulates, because yielding is exactly what stops him serving: he would be overruled
-- every drive for ever, which is the starvation this whole change exists to remove. So the order
-- is by RECENCY, which is the same fairness without the trap:
--
--   1. he held `Shooters` in the previous drive      -> yields FIRST (he has just had it)
--   2. he has no previous row at all (he just arrived) -> yields next
--   3. he drove last drive                            -> yields LAST (it is his turn)
--   ...and ties by userId, which is stable and total.
--
-- IT CANNOT STARVE, and that is provable rather than hoped: a man who yields is a DRIVER this
-- drive, so next drive he is in group 3 and has priority over everybody who just held it.
--
-- `previous` IS THE ONLY INPUT IT NEEDS, which is why there is no new state, no new profile field
-- and nothing added to `Phase.freezeState`: the rotation's own memory already records who held
-- what. Join time is NOT used -- a pure function cannot see it, and carrying it would mean a new
-- field in the frozen state for a tie-break that userId already settles deterministically.
function Roster.yieldOrder(holders: { number }, previous: Assignment?): { number }
	local out = table.clone(holders)
	local function rank(userId: number): number
		local was = if previous ~= nil then previous[userId] else nil
		if was == SHOOTERS then
			return 1
		elseif was == nil then
			return 2
		end
		return 3
	end
	table.sort(out, function(a: number, b: number): boolean
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	return out
end

-- Splits `userIds` into two teams differing by at most one.
--
-- `previous` is the LAST drive's assignment -- or, since task 217, the SYNTHETIC one
-- `Roster.previousFrom` builds from it plus each player's stored turn -- and is honoured only to
-- swap roles
-- (SWAP_TEAMS_EACH_DRIVE): everybody who drove shoots next, which is why it is on by default --
-- everyone wants to shoot, and fixed roles make half the players tourists. Sizes still balance,
-- because a swap of a balanced split is a balanced split.
--
-- `always` IS THE MEN WHO BOUGHT THE HUNTER'S PLACE (task 221, round 3), and it is why this
-- function changed at all. Its own header used to argue that *"rewriting a pinned pure function to
-- add a feature is a bigger change than the feature"*, and the DIRECTOR OVERRULED THAT on
-- 2026-10-20 with a measurement: folding the privilege into the synthetic `previous` moved the
-- SWAPPED counts by two, so on an even roster the balance check discarded the whole swap and the
-- plain split put a low userId on the beaters EVERY drive. *"A paid privilege that is overruled
-- every time on even rosters is a broken product."*
--
-- SO THE PRIVILEGE IS PLACED FIRST AND THE ROTATION FILLS WHAT IS LEFT:
--   1. the hunter slots are counted (`Roster.shooterSlots`);
--   2. every always-hunter takes one, in `Roster.yieldOrder` from the BACK, so if there are more
--      of them than slots the ones who just had it are the ones overruled;
--   3. everybody else fills the remaining hunter slots and then the beaters' side, preferring the
--      men the rotation owes a turn -- whoever DROVE last drive goes first.
-- The result is balanced BY CONSTRUCTION rather than by a check that can discard the whole thing.
--
-- `always` nil or EMPTY TAKES THE OLD PATH, UNTOUCHED, and that is the identity `match_roster.spec`
-- pins at every roster size from 2 to 16: a build where nobody bought it is the game before this
-- task, line for line.
function Roster.assign(
	userIds: { number },
	previous: Assignment?,
	config,
	always: { [number]: boolean }?,
	beaters: { [number]: boolean }?
): Assignment
	local ids = sorted(userIds)
	local assignment: Assignment = {}

	-- ---------------------------------------------------------------- the bought place (task 221)
	--
	-- ...AND THE ONE-DRIVE OPT-OUT (task 229), WHICH IS A FIFTH ARGUMENT AND NOT A FILTERED
	-- `always`, for two measured reasons (design section 7):
	--   * FILTERING ALONE IS NOT THE FEATURE. Drop a wisher out of `always` and he lands in `rest`
	--     below, ordered by `owedRank` -- the ordinary rotation, which seats him as a hunter about
	--     half the time. *"One without the other is not the feature."*
	--   * FILTERING PLUS A SYNTHETIC `owed` ROW INHERITS A DEFECT THIS FILE ALREADY RECORDS. The
	--     header above carries the Director's 2026-10-20 overrule: folding the privilege into the
	--     synthetic `previous` moved the SWAPPED counts by two, the balance check discarded the whole
	--     swap, and a low userId drove every drive. A wish fed through `owed` is the same device.
	-- A fifth argument deals against the same `Roster.shooterSlots` arithmetic the fourth does, so
	-- the result is balanced BY CONSTRUCTION. The proof is in the design, and `match_roster.spec`
	-- asserts `|Drivers - Shooters| <= 1` at every size from 2 to 16 rather than trusting it.
	local holders: { number } = {}
	local wishers: { number } = {}
	if always ~= nil then
		for _, userId in ipairs(ids) do
			if always[userId] == true then
				-- A WISHER IS AN OWNER WHO ASKED, so he leaves the privilege pass entirely and is
				-- dealt a driver's place first instead. A wish from a man who owns nothing is not
				-- read here at all: he is in neither list and takes the rotation's own path.
				if beaters ~= nil and beaters[userId] == true then
					table.insert(wishers, userId)
				else
					table.insert(holders, userId)
				end
			end
		end
	end
	-- `beaters` nil or EMPTY MAKES THIS LIST EMPTY AND `holders` TODAY'S `holders`, so every branch
	-- below is the line it was before this task, value for value -- the identity
	-- `match_roster.spec` pins at every roster size.
	if #wishers > 0 then
		local driverSlots = #ids - Roster.shooterSlots(#ids, config)
		-- THE WISHERS TAKE DRIVER PLACES FIRST, up to the number of driver places there are. By
		-- userId, which is deterministic and total -- this module's own tie-break everywhere else.
		--
		-- A WISHER BEYOND `driverSlots` IS NOT HONOURED and goes back into `holders`: he owns the
		-- hunter's place and did not get what he asked for, so he gets what he PAID for. No second
		-- branch, and no man is ever left without a side.
		--
		-- AT ONE PLAYER `driverSlots` IS 0 (`ODD_PLAYER_TEAM` is `Shooters`), so nobody is honoured
		-- and the solo man is a hunter. That is the whole of the `1 / 1` rule and it is ARITHMETIC
		-- rather than a guard: `docs/design/bots.md` fills both sides with rigs but says twice that
		-- no bot shoots, so a solo beater is a drive in which nothing can be shot.
		for index, userId in ipairs(wishers) do
			if index <= driverSlots then
				assignment[userId] = DRIVERS
			else
				table.insert(holders, userId)
			end
		end
		table.sort(holders)
	end
	-- EITHER LIST IS ENOUGH TO TAKE THIS BRANCH (task 229), and it has to be: with ONE owner who has
	-- asked to beat, `holders` is empty and `wishers` is not -- and falling through to the plain
	-- split below would deal every id again and clobber the driver's place he was just given.
	if #holders > 0 or #wishers > 0 then
		local slots = Roster.shooterSlots(#ids, config)
		local order = Roster.yieldOrder(holders, previous)
		local keep = math.min(#order, slots)
		local yielding = #order - keep
		local shooters = 0
		for index, userId in ipairs(order) do
			if index <= yielding then
				-- OVERRULED: there are more paid hunters than hunter slots, and he just had it.
				-- `Roster.overruled` is what puts his name on the wire so his own screen says why.
				assignment[userId] = DRIVERS
			else
				assignment[userId] = SHOOTERS
				shooters += 1
			end
		end
		-- ...AND EVERYBODY ELSE, THE ROTATION FIRST. A man the swap owes a turn (he drove last
		-- drive) takes a remaining hunter slot before a man who just shot -- so the rotation still
		-- rotates over whatever the privilege leaves, instead of being thrown away whole.
		local rest: { number } = {}
		for _, userId in ipairs(ids) do
			if assignment[userId] == nil then
				table.insert(rest, userId)
			end
		end
		local function owedRank(userId: number): number
			local was = if previous ~= nil then previous[userId] else nil
			if was == DRIVERS then
				return 1 -- he drove: the swap owes him the hunter's side
			elseif was == nil then
				return 2 -- he was not here
			end
			return 3 -- he shot last drive: his turn to drive
		end
		table.sort(rest, function(a: number, b: number): boolean
			local ra, rb = owedRank(a), owedRank(b)
			if ra ~= rb then
				return ra < rb
			end
			return a < b
		end)
		local remaining = math.max(0, slots - shooters)
		for index, userId in ipairs(rest) do
			assignment[userId] = if index <= remaining then SHOOTERS else DRIVERS
		end
		return assignment
	end

	if previous and config.SWAP_TEAMS_EACH_DRIVE then
		local swapped, unknown = {}, {}
		local counts = { Drivers = 0, Shooters = 0 }
		for _, userId in ipairs(ids) do
			local was = previous[userId]
			if was == DRIVERS then
				swapped[userId] = SHOOTERS
				counts.Shooters += 1
			elseif was == SHOOTERS then
				swapped[userId] = DRIVERS
				counts.Drivers += 1
			else
				table.insert(unknown, userId) -- joined since the last drive
			end
		end
		-- Anyone new fills the smaller side, so a joiner cannot unbalance the swap.
		for _, userId in ipairs(unknown) do
			local team = Roster.smallerTeam(counts, config)
			swapped[userId] = team
			counts[team] += 1
		end
		-- The swap only balances if the previous split did. If it did not -- a player left between
		-- drives, say -- fall through to a plain split rather than carry the imbalance forward.
		if math.abs(counts.Drivers - counts.Shooters) <= 1 then
			return swapped
		end
	end

	-- The plain split: the odd player goes to ODD_PLAYER_TEAM.
	local total = #ids
	local first = math.floor(total / 2)
	local odd = total % 2 == 1
	local firstTeam: TeamName = if config.ODD_PLAYER_TEAM == DRIVERS then SHOOTERS else DRIVERS
	local secondTeam: TeamName = config.ODD_PLAYER_TEAM
	if odd then
		-- the extra one lands in the second half, which is ODD_PLAYER_TEAM's
		first = math.floor(total / 2)
	end
	for index, userId in ipairs(ids) do
		assignment[userId] = if index <= first then firstTeam else secondTeam
	end
	return assignment
end

return Roster
