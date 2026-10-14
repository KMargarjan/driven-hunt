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
local Body = Match.Body
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

	-- ------------------------------------------------------------------ the beater's licence (178)
	--
	-- KAREN, 2026-10-10: a beater *"can purchase license to shoot in drive"*. The Reviewer's round-1
	-- finding was that this rule had no test that could fail, and it was right: the branch sat behind
	-- a DRIVER assignment, and the live drive in a one-player run has no driver at all.
	--
	-- WHY NOT THE DESIGN'S OWN CASE (section 12.2, *"with an economy injected at `Match.start`"*):
	-- `Match` IS A SINGLETON THAT `MatchBoot` HAS ALREADY STARTED and `Match.start` asserts *"called
	-- twice"* -- no spec in this repository starts one, and stopping the live drive would pull the
	-- floor out from under `match_live.spec` and this file's own cases in the same session. So the
	-- rule is proved the way this repo already proves a branch nobody can reach: it is a PURE
	-- exported function over a table of cases (`Match.unassignTargets`' own stated reason), with a
	-- second case that proves the LIVE `mayCarryWeapon` really asks.
	describe("a beater may carry a gun only with the licence", function()
		local CONFIG_OFF = { DRIVERS_MAY_SHOOT = false }
		local CONFIG_ON = { DRIVERS_MAY_SHOOT = true }
		local LICENCE = "licence.beater"

		it("refuses a driver who owns nothing, and arms the one who bought it", function()
			-- NOBODY ANSWERED: the game before task 178, and the one reader whose default is
			-- REFUSED -- a world that wired no economy must not arm every beater in it.
			expect(Match.mayCarryFor({ phase = "Running", team = "Drivers", owned = nil }, CONFIG_OFF)).to.equal(false)
			-- HE OWNS NOTHING: the same answer, and it is a different fact.
			expect(Match.mayCarryFor({ phase = "Running", team = "Drivers", owned = {} }, CONFIG_OFF)).to.equal(false)
			-- HE BOUGHT IT.
			expect(Match.mayCarryFor({ phase = "Running", team = "Drivers", owned = { [LICENCE] = true } }, CONFIG_OFF)).to.equal(
				true
			)
			-- A SET THAT HOLDS SOMETHING ELSE IS NOT A LICENCE.
			expect(
				Match.mayCarryFor({ phase = "Running", team = "Drivers", owned = { ["hat.red"] = true } }, CONFIG_OFF)
			).to.equal(false)
			-- `DRIVERS_MAY_SHOOT` STILL WINS FIRST: it arms every driver, licence or not, which is
			-- the branch this rule shares and does not replace.
			expect(Match.mayCarryFor({ phase = "Running", team = "Drivers", owned = nil }, CONFIG_ON)).to.equal(true)
			-- ...AND THE THREE RULES THAT COME BEFORE IT ARE UNCHANGED: no gun in `Waiting`, none for
			-- a tied man whatever he owns, and a shooter needs no licence.
			expect(Match.mayCarryFor({ phase = "Waiting", team = "Shooters" }, CONFIG_OFF)).to.equal(false)
			expect(
				Match.mayCarryFor(
					{ phase = "Running", tied = true, team = "Drivers", owned = { [LICENCE] = true } },
					CONFIG_OFF
				)
			).to.equal(false)
			expect(Match.mayCarryFor({ phase = "Running", team = "Shooters", owned = nil }, CONFIG_OFF)).to.equal(true)
			-- A PLAYER WITH NO TEAM AT ALL carries nothing, licence or not.
			expect(Match.mayCarryFor({ phase = "Running", team = nil, owned = { [LICENCE] = true } }, CONFIG_OFF)).to.equal(
				false
			)
		end)

		-- THE WIRING, AND THIS IS THE CASE THAT FAILS IF THE FEATURE IS DELETED: a tripwire provider
		-- in place of the economy's, and the live `Match.mayCarryWeapon` must ask it about THIS
		-- player. `Match.setOwnedProvider` hands back the one it replaces -- `Weapon.setArmingPolicy`'s
		-- own shape -- so the real one goes back afterwards whatever the assertion does.
		it("asks the economy what this player owns, every time it is asked", function()
			local player = Players:GetPlayers()[1]
			expect(player).to.be.ok()
			local asked = {}
			local previous = Match.setOwnedProvider(function(userId: number)
				table.insert(asked, userId)
				return nil
			end)
			local ok, answer = pcall(Match.mayCarryWeapon, player)
			Match.setOwnedProvider(previous)
			expect(ok).to.equal(true)
			expect(typeof(answer)).to.equal("boolean")
			expect(#asked).to.equal(1)
			expect(asked[1]).to.equal(player.UserId)
			-- ...AND A PROVIDER THAT THROWS LEAVES HIM EXACTLY AS HE WAS, which is the pcall rule
			-- every provider in this repo is held to.
			local threw = Match.setOwnedProvider(function()
				error("the economy is on fire")
			end)
			local okAgain, answerAgain = pcall(Match.mayCarryWeapon, player)
			Match.setOwnedProvider(threw)
			expect(okAgain).to.equal(true)
			expect(answerAgain).to.equal(answer)
		end)
	end)
	describe("the second pivot (task 157)", function()
		-- MEASURED IN THE FOREST TEST PLACE: a character placed by `Body.place` stayed where
		-- `LoadCharacter` had put it -- that place's own `SpawnLocation`, on the road -- while the
		-- drive's chosen point was 240 studs north; a direct `PivotTo` on the same character in the
		-- same session STUCK. So the move was being overwritten, inside the frame `CharacterAdded`
		-- runs in, which is the fact task 153's boot had already written down for its own write. The
		-- DEV place has no `SpawnLocation` (archived in task 22), which is why a hundred DEV drives
		-- never showed it.
		--
		-- NO PLAYER AND NO RESPAWN HERE: the rule is about a Model and a CFrame, so it is asserted on
		-- a Model and a CFrame.
		local function model(at: Vector3): Model
			local character = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			root.Anchored = true
			root.Position = at
			root.Parent = character
			character.PrimaryPart = root
			character.Parent = workspace
			return character
		end

		it("pivots again when something moved the character away", function()
			local target = CFrame.new(Vector3.new(0, 50, 0))
			local character = model(Vector3.new(0, 50, 0))
			local before = Body.settled()
			-- something else puts it back where it spawned
			local root = character.PrimaryPart :: BasePart
			root.Position = Vector3.new(0, 50, 240)
			Body.settle(character, target)
			task.wait(0.2)
			expect(root.Position.Z).to.be.near(0, 0.01)
			expect(Body.settled()).to.equal(before + 1)
			character:Destroy()
		end)

		it("does nothing when the character is where it was put", function()
			local target = CFrame.new(Vector3.new(0, 50, 0))
			local character = model(Vector3.new(0, 50, 0.25)) -- inside the one-stud tolerance
			local before = Body.settled()
			Body.settle(character, target)
			task.wait(0.2)
			local root = character.PrimaryPart :: BasePart
			expect(root.Position.Z).to.be.near(0.25, 0.01)
			expect(Body.settled()).to.equal(before)
			character:Destroy()
		end)

		it("does nothing for a character that has gone", function()
			local character = model(Vector3.new(0, 50, 240))
			local before = Body.settled()
			character:Destroy()
			Body.settle(character, CFrame.new(Vector3.new(0, 50, 0)))
			task.wait(0.2)
			expect(Body.settled()).to.equal(before)
		end)
	end)
end
