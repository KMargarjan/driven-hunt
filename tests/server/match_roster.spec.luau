-- match_roster.spec: who is on which team, with no players, no Instances and no clock.
-- Match.Roster is pure and keys by userId -- it never knows what a Player is -- so every roster size
-- from 2 to 16 is checked here in microseconds.
--
-- The numbers are written out rather than imported, following tests/server/test_arena.spec.luau, so
-- a config that drifts from the design is a finding and not a tautology.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 5.2, 12.2), docs/design/role-rotation.md (section 11.1)
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

-- THE TEMPLATE'S OWN DEFAULT for a player with no turn stored (`Store.TEMPLATE.nextTeam`), named
-- rather than written inline so the case below reads as the fact it is testing.
local EMPTY: any = ""

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

	-- ---------------------------------------------------------------- the stored turn (task 217)
	--
	-- KAREN, 2026-10-11: *"ROLES ROTATE: you start as a hunter, next round you are a beater; it is
	-- REMEMBERED across logout/login (no cheating back to hunter)"*.
	--
	-- THE WHOLE PURE RULE IS HERE, and `Roster.assign` itself is untouched -- the 2..16 sweep above
	-- is the regression that says so.
	-- Design: docs/design/role-rotation.md (sections 4.1, 7, 11.1)
	describe("the role a player is OWED", function()
		it("has exactly one other side, and answers nil for anything that is not a team", function()
			expect(Roster.other("Drivers")).to.equal("Shooters")
			expect(Roster.other("Shooters")).to.equal("Drivers")
			-- nil IN, nil OUT, and it is load-bearing rather than polite: the input is sometimes a
			-- value that came off a DataStore key, so a corrupted row must DROP rather than invent a
			-- team. Karen's own words are not team names either, and must not become one here.
			expect(Roster.other(nil)).to.equal(nil)
			expect(Roster.other("hunter" :: any)).to.equal(nil)
			expect(Roster.other("beater" :: any)).to.equal(nil)
			expect(Roster.other(EMPTY)).to.equal(nil)
			expect(Roster.other(7 :: any)).to.equal(nil)
		end)

		it("inverts a whole assignment into a new table, leaving the frozen input alone", function()
			local played = table.freeze({ [101] = "Drivers" :: any, [102] = "Shooters", [103] = "Shooters" })
			local owed = Roster.invert(played)
			expect(owed[101]).to.equal("Shooters")
			expect(owed[102]).to.equal("Drivers")
			expect(owed[103]).to.equal("Drivers")
			-- A NEW table, not the input: `enterScoring` hands `state.assignment` in, and
			-- `Phase.freezeState` has frozen it.
			expect(owed).never.to.equal(played)
			expect(played[101]).to.equal("Drivers")
		end)

		it("drops a row that is not a team rather than carrying it into the record", function()
			local owed = Roster.invert({ [101] = "Drivers" :: any, [102] = "hunter" :: any })
			expect(owed[101]).to.equal("Shooters")
			expect(owed[102]).to.equal(nil)
		end)

		-- THE FLAG-OFF IDENTITY, asserted on the RAW TABLE rather than by a deep compare, because
		-- identity is the whole claim: with no economy in the build this is the same table
		-- `Roster.assign` was handed before task 217, so nothing can have moved (design section 7).
		it("hands `previous` back BY IDENTITY when nobody is owed anything", function()
			local previous = table.freeze({ [101] = "Drivers" :: any, [102] = "Shooters" })
			expect(Roster.previousFrom(previous, nil)).to.equal(previous)
			expect(Roster.previousFrom(previous, {})).to.equal(previous)
			expect(Roster.previousFrom(nil, nil)).to.equal(nil)
			expect(Roster.previousFrom(nil, {})).to.equal(nil)
		end)

		it("and the split is then byte-for-byte today's, for every size from 2 to 16", function()
			for n = 2, 16 do
				local previous = Roster.assign(ids(n), nil, config())
				local before = Roster.assign(ids(n), previous, config())
				local after = Roster.assign(ids(n), Roster.previousFrom(previous, nil), config())
				for userId, team in pairs(before) do
					expect(after[userId]).to.equal(team)
				end
				expect(assignedCount(after)).to.equal(n)
			end
		end)

		-- THE INVERSION, END TO END, and it is the one trap in this design: `assign`'s swap gives a
		-- player the OPPOSITE of his `previous` row, so the synthetic row must be the other one. A
		-- spec that asserted only `previousFrom`'s output would pass with the inversion backwards.
		it("lands a player on the team he is owed, through assign's own swap", function()
			local synthetic = Roster.previousFrom(nil, { [7] = "Drivers" :: any })
			expect((synthetic :: any)[7]).to.equal("Shooters") -- the INVERSE is what is fed in
			expect(Roster.assign({ 7 }, synthetic, config())[7]).to.equal("Drivers") -- ...and he plays what he is owed
		end)

		it("honours the turn of a rejoiner who has no previous row at all", function()
			-- The point of the feature: 101 and 102 played the last drive, 103 has just come back
			-- from a logout owing a beater's turn and is UNKNOWN to `previousAssignment`.
			local previous = { [101] = "Drivers" :: any, [102] = "Shooters" }
			local synthetic = Roster.previousFrom(previous, { [103] = "Drivers" :: any })
			local assignment = Roster.assign({ 101, 102, 103 }, synthetic, config())
			expect(assignment[103]).to.equal("Drivers")
			local counts = countOf(assignment)
			expect(math.abs(counts.Drivers - counts.Shooters) <= 1).to.equal(true)
		end)

		it("writes neither of its inputs, both of which arrive frozen in production", function()
			local previous = table.freeze({ [101] = "Drivers" :: any })
			local owed = table.freeze({ [102] = "Shooters" :: any })
			local out = Roster.previousFrom(previous, owed)
			expect((out :: any)[101]).to.equal("Drivers")
			expect((out :: any)[102]).to.equal("Drivers") -- the inverse of what 102 is owed
			expect(previous[101]).to.equal("Drivers")
			expect(owed[102]).to.equal("Shooters")
		end)

		-- KAREN'S OLDER RULE WINS (the Director, 2026-10-20): equal teams beat rotation. Four
		-- players all owed the SAME side cannot all have it, so `assign`'s balance check discards
		-- the whole swap and the plain split decides -- and NOTHING IS CONSUMED, because the only
		-- thing that ever writes a turn is the drive's end (design section 5.3).
		it("lets the balance rule overrule the turn, and still splits the teams equally", function()
			local owed = { [101] = "Drivers" :: any, [102] = "Drivers", [103] = "Drivers", [104] = "Drivers" }
			local assignment = Roster.assign(ids(4), Roster.previousFrom(nil, owed), config())
			local counts = countOf(assignment)
			expect(counts.Drivers).to.equal(2)
			expect(counts.Shooters).to.equal(2)
			-- ...AND THE TURN IS PAID THE NEXT DRIVE. The two who were refused are written
			-- `other(what they played)` = `Drivers` again at the drive's end (`Roster.invert`), so
			-- the second drive honours them: this is the arithmetic the design's worked case states.
			local nextOwed = Roster.invert(assignment)
			local second = Roster.assign(ids(4), Roster.previousFrom(assignment, nextOwed), config())
			for userId, team in pairs(assignment) do
				expect(second[userId]).never.to.equal(team)
			end
			local secondCounts = countOf(second)
			expect(secondCounts.Drivers).to.equal(2)
			expect(secondCounts.Shooters).to.equal(2)
		end)

		it("keeps the teams equal to within one for every size from 2 to 16, whatever is owed", function()
			-- The sweep above, run again with EVERY player owed the same side -- the worst input the
			-- rotation can hand the balance rule.
			for n = 2, 16 do
				local owed = {}
				for _, userId in ipairs(ids(n)) do
					owed[userId] = "Drivers"
				end
				local assignment = Roster.assign(ids(n), Roster.previousFrom(nil, owed), config())
				local counts = countOf(assignment)
				expect(assignedCount(assignment)).to.equal(n)
				expect(math.abs(counts.Drivers - counts.Shooters) <= 1).to.equal(true)
			end
		end)
	end)

	describe("a player who joins a drive that is already running", function()
		it("gets the team he is owed when the sides are LEVEL, which costs the balance nothing", function()
			expect(Roster.joinTeam({ Drivers = 2, Shooters = 2 }, "Drivers", config())).to.equal("Drivers")
			expect(Roster.joinTeam({ Drivers = 2, Shooters = 2 }, "Shooters", config())).to.equal("Shooters")
			expect(Roster.joinTeam({ Drivers = 0, Shooters = 0 }, "Drivers", config())).to.equal("Drivers")
		end)

		it("gets the SMALLER team when the sides are not level, and the turn is not consumed", function()
			expect(Roster.joinTeam({ Drivers = 1, Shooters = 2 }, "Shooters", config())).to.equal("Drivers")
			expect(Roster.joinTeam({ Drivers = 3, Shooters = 1 }, "Drivers", config())).to.equal("Shooters")
		end)

		-- NO OWED TEAM IS `smallerTeam` EXACTLY, which is this question before task 217 -- including
		-- the tie, which goes to ODD_PLAYER_TEAM and not to a turn nobody has.
		it("is `smallerTeam` exactly when nothing is owed", function()
			expect(Roster.joinTeam({ Drivers = 2, Shooters = 2 }, nil, config())).to.equal("Shooters")
			expect(Roster.joinTeam({ Drivers = 2, Shooters = 2 }, nil, config({ ODD_PLAYER_TEAM = "Drivers" }))).to.equal(
				"Drivers"
			)
			expect(Roster.joinTeam({ Drivers = 1, Shooters = 2 }, nil, config())).to.equal("Drivers")
		end)

		-- THE ASYMMETRY, ASSERTED ON ONE VALUE (design hazard 9): `previousFrom` INVERTS because
		-- `assign` swaps, and `joinTeam` does NOT because it places a man directly. One owed value,
		-- both directions, so a copy-paste of either into the other fails here.
		it("is placed directly, where previousFrom is inverted -- the same owed value, both ways", function()
			expect((Roster.previousFrom(nil, { [7] = "Drivers" :: any }) :: any)[7]).to.equal("Shooters")
			expect(Roster.joinTeam({ Drivers = 1, Shooters = 1 }, "Drivers", config())).to.equal("Drivers")
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

	-- ---------------------------------------------------------------- the bought place (task 221)
	--
	-- KAREN, 2026-10-20: *"Posibility to be a hunter always"*. A strong PREFERENCE and not an
	-- exemption: a drive with eight hunters and no beaters is not a drive, so `Roster.assign`'s
	-- balance rule still wins -- and when it does, the man who paid is TOLD WHY.
	describe("always-hunter", function()
		local CONFIG = Match.CONFIG

		it("is the game before this task when nobody bought it", function()
			-- BY IDENTITY, which IS the flag-off story: the same table comes back, not a copy of
			-- it, so nothing is allocated and nothing can differ.
			local owed = { [1] = "Shooters" }
			expect(Roster.owedWith(owed, nil)).to.equal(owed)
			expect(Roster.owedWith(owed, {})).to.equal(owed)
			expect(Roster.owedWith(nil, nil)).to.equal(nil)
			expect(#Roster.overruled({ [1] = "Drivers" }, nil)).to.equal(0)
			expect(#Roster.overruled({ [1] = "Drivers" }, {})).to.equal(0)
		end)

		it("writes the hunter's place over whatever turn he was owed", function()
			local owed = { [1] = "Drivers", [2] = "Drivers" }
			local wanted = Roster.owedWith(owed, { [1] = true })
			expect(wanted).never.to.equal(owed)
			expect((wanted :: any)[1]).to.equal("Shooters")
			-- ...AND LEAVES EVERYBODY ELSE'S TURN ALONE.
			expect((wanted :: any)[2]).to.equal("Drivers")
			-- NEITHER INPUT IS WRITTEN: `owed` is the economy's frozen memo.
			expect(owed[1]).to.equal("Drivers")
			-- IT DOES NOT INVERT. The inversion is `previousFrom`'s and lives only there.
			expect(Roster.owedWith(nil, { [7] = true })[7]).to.equal("Shooters")
		end)

		it("beats the stored turn, which is what being bought means", function()
			-- HIS TURN SAID DRIVE AND HE PAID NOT TO. The turn arrives as the synthetic previous
			-- (task 217) and the privilege arrives as `always` (task 221 round 3); the privilege is
			-- placed first, so it wins.
			local previous = { [1] = "Drivers", [2] = "Drivers", [3] = "Shooters", [4] = "Shooters" }
			local always = { [1] = true }
			local synthetic = Roster.previousFrom(previous, { [1] = "Drivers" })
			expect(Roster.assign({ 1, 2, 3, 4 }, synthetic, CONFIG)[1]).to.equal("Drivers")
			local assignment = Roster.assign({ 1, 2, 3, 4 }, synthetic, CONFIG, always)
			expect(assignment[1]).to.equal("Shooters")
			-- THE SPLIT IS STILL BALANCED: a privilege that unbalanced the drive would be the thing
			-- the balance rule exists to refuse.
			local counts = Roster.counts(assignment)
			expect(math.abs((counts.Drivers or 0) - (counts.Shooters or 0)) <= 1).to.equal(true)
			-- ...AND NOBODY WAS OVERRULED, because the teams came out even.
			expect(#Roster.overruled(assignment, always)).to.equal(0)
		end)

		-- THE DIRECTOR OVERRULED THE SEAM ON 2026-10-20 (task 221 round 3): *"ALWAYS-HUNTER MUST
		-- WORK when bought ... a paid privilege that is overruled 'every time' on even rosters is a
		-- broken product"*. Round 2 measured exactly that: folding the privilege into the synthetic
		-- `previous` moved the SWAPPED counts by two, `Roster.assign` discarded the whole swap, and
		-- the plain split put a low userId on the beaters every drive. So `assign` places the men who
		-- bought it FIRST and the rotation fills what is left.
		it("gives every always-hunter the hunters' side on an even roster", function()
			local always = { [1] = true }
			-- THE CASE ROUND 2 FAILED: he already held `Shooters`, and the swap would have taken it
			-- away. Now he keeps it and the teams are still even.
			local previous = { [1] = "Shooters", [2] = "Shooters", [3] = "Drivers", [4] = "Drivers" }
			local assignment = Roster.assign({ 1, 2, 3, 4 }, previous, CONFIG, always)
			expect(assignment[1]).to.equal("Shooters")
			local counts = Roster.counts(assignment)
			expect(counts.Shooters).to.equal(2)
			expect(counts.Drivers).to.equal(2)
			-- NOBODY IS OVERRULED, so nobody is told anything.
			expect(#Roster.overruled(assignment, always)).to.equal(0)
			-- ...AND THE ROTATION STILL ROTATES OVER WHAT IS LEFT: of the other three, the two who
			-- DROVE last drive are the ones owed the hunters' side, and there is one slot for them.
			expect(assignment[2]).to.equal("Drivers") -- he shot last drive
			expect(assignment[3] == "Shooters" or assignment[4] == "Shooters").to.equal(true)
			-- HE KEEPS IT DRIVE AFTER DRIVE, which is the whole of what Karen is selling.
			local second = Roster.assign({ 1, 2, 3, 4 }, assignment, CONFIG, always)
			expect(second[1]).to.equal("Shooters")
			local third = Roster.assign({ 1, 2, 3, 4 }, second, CONFIG, always)
			expect(third[1]).to.equal("Shooters")
		end)

		it("gives every always-hunter the hunters' side on an odd roster too", function()
			-- FIVE PLAYERS AND `ODD_PLAYER_TEAM` IS `Shooters`, so there are three hunter slots. Two
			-- men bought the place and both get it, with one slot left for the rotation.
			local always = { [2] = true, [4] = true }
			local previous = { [1] = "Shooters", [2] = "Shooters", [3] = "Shooters", [4] = "Drivers", [5] = "Drivers" }
			local assignment = Roster.assign({ 1, 2, 3, 4, 5 }, previous, CONFIG, always)
			expect(assignment[2]).to.equal("Shooters")
			expect(assignment[4]).to.equal("Shooters")
			local counts = Roster.counts(assignment)
			expect(counts.Shooters).to.equal(3)
			expect(counts.Drivers).to.equal(2)
			expect(#Roster.overruled(assignment, always)).to.equal(0)
			-- THE LAST HUNTER SLOT GOES TO A MAN THE ROTATION OWES ONE -- player 5 drove last drive,
			-- and 1 and 3 shot.
			expect(assignment[5]).to.equal("Shooters")
			expect(assignment[1]).to.equal("Drivers")
			expect(assignment[3]).to.equal("Drivers")
		end)

		it("overrules only when the paid men outnumber the hunter slots, and takes turns doing it", function()
			-- ALL FOUR BOUGHT IT AND THERE ARE TWO SLOTS, so two must drive -- a drive with four
			-- hunters and no beaters is not a drive. THE ONES WHO JUST HAD IT YIELD.
			local always = { [1] = true, [2] = true, [3] = true, [4] = true }
			local previous = { [1] = "Shooters", [2] = "Shooters", [3] = "Drivers", [4] = "Drivers" }
			local first = Roster.assign({ 1, 2, 3, 4 }, previous, CONFIG, always)
			local counts = Roster.counts(first)
			expect(counts.Shooters).to.equal(2)
			expect(counts.Drivers).to.equal(2)
			-- 1 and 2 shot last drive, so they yield; 3 and 4 drove, so it is their turn.
			expect(first[3]).to.equal("Shooters")
			expect(first[4]).to.equal("Shooters")
			expect(first[1]).to.equal("Drivers")
			expect(first[2]).to.equal("Drivers")
			-- ...AND THE TWO WHO YIELDED ARE THE TWO WHO ARE TOLD WHY.
			local told = Roster.overruled(first, always)
			expect(#told).to.equal(2)
			expect(told[1]).to.equal(1)
			expect(told[2]).to.equal(2)

			-- IT CANNOT STARVE, and that is the whole reason the yield order is by RECENCY rather than
			-- by a count of drives served: a man who yields is a DRIVER, so next drive he is the one
			-- whose turn it is. Four drives, and every man gets it twice.
			local served = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
			local state = previous
			for _ = 1, 4 do
				state = Roster.assign({ 1, 2, 3, 4 }, state, CONFIG, always)
				for userId, team in pairs(state) do
					if team == "Shooters" then
						served[userId] += 1
					end
				end
			end
			for userId = 1, 4 do
				expect(served[userId]).to.equal(2)
			end
		end)

		it("is the game before this task when nobody bought the place, at every roster size", function()
			-- THE IDENTITY, and it is what lets `assign` be rewritten at all: with `always` nil or
			-- empty, not one branch of the new code runs and every answer is the old function's.
			for n = 2, 16 do
				local roster = ids(n)
				local plain = Roster.assign(roster, nil, CONFIG)
				expect(Roster.assign(roster, nil, CONFIG, nil)).never.to.equal(nil)
				for _, userId in ipairs(roster) do
					expect(Roster.assign(roster, nil, CONFIG, {})[userId]).to.equal(plain[userId])
				end
				-- ...AND WITH A PREVIOUS SPLIT, which is the swap path rather than the plain one.
				local swapped = Roster.assign(roster, plain, CONFIG)
				for _, userId in ipairs(roster) do
					expect(Roster.assign(roster, plain, CONFIG, {})[userId]).to.equal(swapped[userId])
				end
			end
		end)

		it("counts the hunter slots the way the plain split does", function()
			-- THE SAME ARITHMETIC NAMED ONCE: the always-hunter pass has to know the number before it
			-- deals anybody, and two copies of "how many hunters fit" is how the two halves of this
			-- function would come to disagree.
			for n = 0, 16 do
				local slots = Roster.shooterSlots(n, CONFIG)
				expect(slots).to.equal(math.ceil(n / 2)) -- ODD_PLAYER_TEAM is Shooters
				expect(math.abs((n - slots) - slots) <= 1).to.equal(true)
			end
			local driversOdd = config({ ODD_PLAYER_TEAM = "Drivers" })
			expect(Roster.shooterSlots(5, driversOdd)).to.equal(2)
		end)

		it("reaches a man who walks onto a truck pad mid-drive", function()
			-- SINCE TASKS 177 AND 209 THIS IS THE NORMAL WAY INTO A DRIVE, so the privilege has to
			-- reach it -- and `joinTeam`'s own rule still holds: the owed team wins only off a tie,
			-- so the balance still beats the privilege here as well.
			local wanted = Roster.owedWith(nil, { [5] = true })
			expect(Roster.joinTeam({ Drivers = 2, Shooters = 2 }, (wanted :: any)[5], CONFIG)).to.equal("Shooters")
			-- OFF A TIE THE SMALLER SIDE WINS AND THE PRIVILEGE IS SIMPLY NOT CONSUMED.
			expect(Roster.joinTeam({ Drivers = 1, Shooters = 3 }, (wanted :: any)[5], CONFIG)).to.equal("Drivers")
		end)
	end)
end
