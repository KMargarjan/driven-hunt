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
-- Design: docs/design/drive.md (section 5.2)
-- Note:   docs/research/2026-09-25-drive.md
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

local function sorted(userIds: { number }): { number }
	local out = table.clone(userIds)
	table.sort(out)
	return out
end

-- Splits `userIds` into two teams differing by at most one.
--
-- `previous` is the LAST drive's assignment and is honoured only to swap roles
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
