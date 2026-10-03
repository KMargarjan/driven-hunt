-- match_teams.spec: the one assertion that needs real players -- everybody in this session gets a
-- team from the drive, and the two teams are equal to within one.
--
-- It is written to be TRUE FOR WHATEVER NUMBER OF PLAYERS IS THERE, which is what lets it run in
-- both harness modes: `test` (one player, the default) and `test2` (a local Clients-and-Servers test
-- with two). With one player it says "the lone player is a Shooter and is armed" -- Director
-- decision F; with two it says what ROADMAP 1.6 wanted a second client for: both are assigned, and
-- one drives while the other shoots.
--
-- It asserts on the REAL drive, which MatchBoot started, for the same reason match_live.spec does:
-- Match is a singleton, and a spec that started its own would be testing a stub of the thing the
-- players are standing in.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 5.1, 5.2, 12.6)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local ASSIGN_TIMEOUT = 30 -- the drive assigns on entering Assigning, which follows the first join

local function waitUntil(timeout: number, predicate: () -> boolean): boolean
	local started = os.clock()
	while os.clock() - started < timeout do
		if predicate() then
			return true
		end
		task.wait(0.1)
	end
	return predicate()
end

local function everyoneAssigned(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in ipairs(players) do
		if player.Team == nil then
			return false
		end
	end
	return true
end

local function counts(): (number, number, { string })
	local drivers, shooters, names = 0, 0, {}
	for _, player in ipairs(Players:GetPlayers()) do
		local team = player.Team and player.Team.Name
		if team == "Drivers" then
			drivers += 1
		elseif team == "Shooters" then
			shooters += 1
		end
		table.insert(names, string.format("%s=%s", player.Name, tostring(team)))
	end
	return drivers, shooters, names
end

return function()
	describe("the drive's teams, with however many players are here", function()
		it("gives every player in the session a team", function()
			local assigned = waitUntil(ASSIGN_TIMEOUT, everyoneAssigned)
			local drivers, shooters, names = counts()
			print(
				string.format(
					"[match_teams] %d player(s): %s | drivers=%d shooters=%d phase=%s",
					#Players:GetPlayers(),
					table.concat(names, ", "),
					drivers,
					shooters,
					Match.phase()
				)
			)
			expect(assigned).to.equal(true)
			expect(drivers + shooters).to.equal(#Players:GetPlayers())
		end)

		it("keeps the two teams equal to within one, which is the rule for every size", function()
			expect(waitUntil(ASSIGN_TIMEOUT, everyoneAssigned)).to.equal(true)
			local drivers, shooters = counts()
			expect(math.abs(drivers - shooters) <= 1).to.equal(true)
		end)

		it("splits two players into one driver and one shooter, and arms only the shooter", function()
			local players = Players:GetPlayers()
			if #players < 2 then
				-- ONE player: the Milestone 1 rule (Director decision F). This branch is not a
				-- skipped test -- it asserts the one-player invariant, which is the thing that keeps
				-- the rest of the client suite armed and green.
				expect(#players).to.equal(1)
				expect(waitUntil(ASSIGN_TIMEOUT, everyoneAssigned)).to.equal(true)
				expect(players[1].Team.Name).to.equal("Shooters")
				expect(Match.mayCarryWeapon(players[1])).to.equal(true)
				return
			end

			-- TWO players: what ROADMAP 1.6 wanted a second client for.
			expect(waitUntil(ASSIGN_TIMEOUT, everyoneAssigned)).to.equal(true)
			local drivers, shooters = counts()
			expect(drivers).to.equal(1)
			expect(shooters).to.equal(1)
			local tiedCount = 0
			for _, player in ipairs(players) do
				-- A shooter carries a gun and a driver does not: DRIVERS_MAY_SHOOT is false, and
				-- that is the whole difference between the two roles in 1.7a.
				--
				-- ...AND THE TIE IS A THIRD RULE, which this case did not allow for and which is
				-- armed ON PURPOSE in every `test2` run. The LAST scenario in
				-- `tests/client/input_scenarios.txt` is `tie-the-driver` (Task 35), and it exists
				-- FOR `tests/client/zz_tie_to_a_tree.spec.luau`: it ties the SHOOTER for shooting
				-- across a driver, `TIE_UNTIL_DRIVE_END` keeps him tied for the rest of the drive,
				-- and `Match.mayCarryWeapon` refuses a tied player whatever his team is. This
				-- assertion was written in Task 34, one task BEFORE that scenario existed, and it
				-- only fails when the server suite reaches this case AFTER the tie lands at ~55 s --
				-- which is the same creep `ESCALATE.md`'s Task 112 entry predicted ("the next task
				-- pushes it further whatever it changes"), there on the client suite and here on the
				-- server's. Task 118's live boar spec is ~20 s of that push.
				--
				-- Reading `Match.isTied` is the SAME FACT `mayCarryWeapon` reads, so this says what
				-- it always meant to say and nothing weaker: a shooter who is free carries a gun.
				local shooter = player.Team.Name == "Shooters"
				local tied = Match.isTied(player.UserId)
				if tied then
					tiedCount += 1
				end
				expect(Match.mayCarryWeapon(player)).to.equal(shooter and not tied)
				-- A DRIVER IS REFUSED FOR HIS TEAM AND FOR NOTHING ELSE. Only a shooter can be tied
				-- (a tie is a penalty for shooting, and DRIVERS_MAY_SHOOT is false), so this is what
				-- keeps the ROLE difference asserted even on a run where the shooter is tied: his
				-- `false` can never be explained away by a tie.
				if not shooter then
					expect(tied).to.equal(false)
				end
			end
			TestKit.note(
				string.format(
					"match_teams: %d driver(s), %d shooter(s), %d tied at the time of the check",
					drivers,
					shooters,
					tiedCount
				)
			)
		end)
	end)
end
