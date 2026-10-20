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
-- THE FOUR FUNCTIONS BELOW ARE THE WHOLE RULE, and `Roster.assign` is DELIBERATELY NOT TOUCHED:
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

-- PURE. WHOSE PRIVILEGE THE BALANCE RULE OVERRULED: the always-hunters whose FINAL team is
-- `Drivers`.
--
-- A man who paid $2000 for the hunter's place and starts a drive with a horn, with no explanation,
-- reads the purchase as broken and says so. This is the list the drive publishes so the Hud can
-- tell him why -- and it is computed from the assignment that was actually made, so it can never
-- disagree with the team he is on.
--
-- A LIST, SORTED, so the wire is a dense array -- the shape `tied` and `through` already have.
function Roster.overruled(assignment: Assignment, always: { [number]: boolean }?): { number }
	local out: { number } = {}
	if always == nil then
		return out
	end
	for userId, bought in pairs(always) do
		if bought == true and assignment[userId] == DRIVERS then
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

-- Splits `userIds` into two teams differing by at most one.
--
-- `previous` is the LAST drive's assignment -- or, since task 217, the SYNTHETIC one
-- `Roster.previousFrom` builds from it plus each player's stored turn -- and is honoured only to
-- swap roles
-- (SWAP_TEAMS_EACH_DRIVE): everybody who drove shoots next, which is why it is on by default --
-- everyone wants to shoot, and fixed roles make half the players tourists. Sizes still balance,
-- because a swap of a balanced split is a balanced split.
function Roster.assign(userIds: { number }, previous: Assignment?, config): Assignment
	local ids = sorted(userIds)
	local assignment: Assignment = {}

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
