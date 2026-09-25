-- match_roster.spec: who is on which team, with no players, no Instances and no clock.
-- Match.Roster is pure and keys by userId -- it never knows what a Player is -- so every roster size
-- from 2 to 16 is checked here in microseconds.
--
-- The numbers are written out rather than imported, following tests/server/test_arena.spec.luau, so
-- a config that drifts from the design is a finding and not a tautology.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 5.2, 12.2)
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Roster = Match.Roster

-- This spec's own config, so it can flip a flag without touching production's.
local function config(overrides)
	local merged = {
		ODD_PLAYER_TEAM = "Shooters",
		SWAP_TEAMS_EACH_DRIVE = true,
	}
	for key, value in pairs(overrides or {}) do
		merged[key] = value
	end
	return merged
end

local function ids(n: number, offset: number?): { number }
	local out = {}
	for index = 1, n do
		table.insert(out, (offset or 100) + index)
	end
	return out
end

local function countOf(assignment)
	return Roster.counts(assignment)
end

local function assignedCount(assignment): number
	local n = 0
	for _ in pairs(assignment) do
		n += 1
	end
	return n
end

return function()
	describe("splitting a roster", function()
		it("keeps the teams equal to within one, for every size from 2 to 16", function()
			for n = 2, 16 do
				local assignment = Roster.assign(ids(n), nil, config())
				local counts = countOf(assignment)
				expect(assignedCount(assignment)).to.equal(n) -- everybody, exactly once
				expect(math.abs(counts.Drivers - counts.Shooters) <= 1).to.equal(true)
				expect(counts.Drivers + counts.Shooters).to.equal(n)
			end
		end)

		it("gives one driver and one shooter with two players, which is the whole point", function()
			local counts = countOf(Roster.assign(ids(2), nil, config()))
			expect(counts.Drivers).to.equal(1)
			expect(counts.Shooters).to.equal(1)
		end)

		it("puts the odd player on ODD_PLAYER_TEAM, and flipping the config flips the result", function()
			local shooters = countOf(Roster.assign(ids(5), nil, config({ ODD_PLAYER_TEAM = "Shooters" })))
			expect(shooters.Shooters).to.equal(3)
			expect(shooters.Drivers).to.equal(2)

			local drivers = countOf(Roster.assign(ids(5), nil, config({ ODD_PLAYER_TEAM = "Drivers" })))
			expect(drivers.Drivers).to.equal(3)
			expect(drivers.Shooters).to.equal(2)
		end)

		it("puts a lone player on ODD_PLAYER_TEAM: with MIN_PLAYERS = 1 that is the harness's player", function()
			-- Director decision F / audit-003 must-fix 1: a solo player is a SHOOTER, so the one
			-- player in a harness Play session keeps a gun and the weapon specs stay green.
			local assignment = Roster.assign(ids(1), nil, config({ ODD_PLAYER_TEAM = "Shooters" }))
			expect(assignment[101]).to.equal("Shooters")
		end)

		it("is deterministic: the same roster in a different order gives the same teams", function()
			local forwards = Roster.assign({ 7, 3, 11, 5 }, nil, config())
			local backwards = Roster.assign({ 11, 5, 3, 7 }, nil, config())
			for userId, team in pairs(forwards) do
				expect(backwards[userId]).to.equal(team)
			end
		end)
	end)

	describe("swapping roles between drives", function()
		it("puts everybody on the other side, and still balances", function()
			local first = Roster.assign(ids(6), nil, config())
			local second = Roster.assign(ids(6), first, config())
			for userId, team in pairs(first) do
				expect(second[userId]).never.to.equal(team)
			end
			local counts = countOf(second)
			expect(math.abs(counts.Drivers - counts.Shooters) <= 1).to.equal(true)
		end)

		it("does not swap when the flag is off", function()
			local first = Roster.assign(ids(6), nil, config())
			local second = Roster.assign(ids(6), first, config({ SWAP_TEAMS_EACH_DRIVE = false }))
			-- A plain split of the same sorted ids is the same split.
			for userId, team in pairs(first) do
				expect(second[userId]).to.equal(team)
			end
		end)

		it("fills the smaller side with anyone who joined since the last drive", function()
			local first = Roster.assign(ids(4), nil, config())
			local withJoiner = Roster.assign(ids(5), first, config())
			expect(assignedCount(withJoiner)).to.equal(5)
			local counts = countOf(withJoiner)
			expect(math.abs(counts.Drivers - counts.Shooters) <= 1).to.equal(true)
		end)

		it("falls back to a plain split when the previous drive was lopsided", function()
			-- Somebody left between drives, so swapping the survivors would carry the imbalance
			-- forward. A 3-1 previous split must not become a 1-3 one.
			local lopsided = { [101] = "Drivers", [102] = "Drivers", [103] = "Drivers", [104] = "Shooters" }
			local counts = countOf(Roster.assign(ids(4), lopsided, config()))
			expect(math.abs(counts.Drivers - counts.Shooters) <= 1).to.equal(true)
		end)
	end)

	describe("the smaller team", function()
		it("is the one with fewer players, and ODD_PLAYER_TEAM on a tie", function()
			expect(Roster.smallerTeam({ Drivers = 2, Shooters = 3 }, config())).to.equal("Drivers")
			expect(Roster.smallerTeam({ Drivers = 4, Shooters = 1 }, config())).to.equal("Shooters")
			expect(Roster.smallerTeam({ Drivers = 2, Shooters = 2 }, config())).to.equal("Shooters")
			expect(Roster.smallerTeam({ Drivers = 2, Shooters = 2 }, config({ ODD_PLAYER_TEAM = "Drivers" }))).to.equal(
				"Drivers"
			)
		end)
	end)

	describe("the numbers this spec asserts", function()
		it("are the numbers production ships", function()
			-- The loop closed the other way: every other assertion here is against this file's own
			-- config, so a broken production config cannot make them pass.
			expect(Match.CONFIG.ODD_PLAYER_TEAM).to.equal("Shooters")
			expect(Match.CONFIG.SWAP_TEAMS_EACH_DRIVE).to.equal(true)
			expect(Match.CONFIG.MIN_PLAYERS).to.equal(1) -- Milestone 1 only; see the design delta
			expect(Match.CONFIG.MAX_PLAYERS).to.equal(16)
		end)
	end)
end
