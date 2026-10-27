-- zz_pad_restart.spec: the LIVE door Karen's pad step goes through (task 287), on the real Match.
--
-- WHY THE `zz_` PREFIX AND WHY IT IS THE LAST FILE IN THE SUITE. A restart is a drive boundary: it
-- respawns everybody and re-grants their guns, and `Match.advanceForTests` has to be used to get
-- inside a drive first. MEASURED, with the case in `match_live.spec` instead (2026-10-27): at
-- `618aa228` it left the gun in the Backpack and `weapon_shot.spec:476` read the muzzle AT THE EYE;
-- at `df3e726e`, with the team, the phase and the same gun restored, `weapon_shot.spec:476` still
-- failed AND `zz_drive_boundary.spec` broke on `Match.testSeconds() == 0`, because the test clock is
-- shared state no restoration can give back. `zz_drive_boundary`'s own header already says why such
-- a case runs last; this is that rule applied to this one.
--
-- IT WAITS FOR EVERY CLIENT exactly as `zz_drive_boundary` does, for the reason that file measured.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (section 4), docs/design/lobby.md (section 4.2)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))

local CLIENTS_DONE_TIMEOUT = 240

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

-- THE HARNESS SAYS WHEN: a client-side attribute does not replicate to the server, so
-- `ServerStorage.ClientsFinished` carrying this run's token is the one observable that every client
-- has reported (`zz_drive_boundary.spec`'s own measurement, task 41).
local function clientsFinished(): boolean
	if #Players:GetPlayers() == 0 then
		return true
	end
	return ServerStorage:GetAttribute("ClientsFinished") == TestKit.activeToken()
end

local function toolIn(where: Instance?): string
	if where == nil then
		return "none"
	end
	local tool = where:FindFirstChildWhichIsA("Tool")
	return if tool then tool.Name else "none"
end

return function()
	describe("the pad's own door into a fresh drive (task 287)", function()
		it("starts a NEW drive when the man it let go of comes back to an empty one", function()
			local player = Players:GetPlayers()[1]
			if player == nil then
				-- NOT A SKIP and not silent: with no player there is no roster to empty, so the
				-- claim is made against the pure rule instead -- which is where it is driven at
				-- every boundary (`match_phase.spec`).
				TestKit.note("task287: no player in this run, so the live door was not driven")
				expect(Match.enrolRefused(-999)).to.equal(false)
				return
			end
			expect(waitUntil(CLIENTS_DONE_TIMEOUT, clientsFinished)).to.equal(true)
			-- INSIDE A DRIVE FIRST, and `advanceForTests` is this suite's own seam for it. Nothing
			-- runs after this file, which is why it may be spent here (see the header).
			expect(waitUntil(60, function()
				if Match.phase() == "Running" or Match.phase() == "Assigning" then
					return true
				end
				Match.advanceForTests(2)
				return false
			end)).to.equal(true)
			local wasDrive = Match.driveNumber()
			local wasTeam = Match.assignmentOf(player.UserId)
			local wasHeld = toolIn(player.Character)
			local hadRestarts = Match.stats().restarts
			-- HE RESPAWNS OUT OF A LIVE DRIVE (task 248's rule), which empties this roster: he is
			-- the only player in the DEV place.
			expect(Match.isParticipant(player.UserId)).to.equal(true)
			expect(Match.withdraw(player)).to.equal(true)
			expect(Match.isParticipant(player.UserId)).to.equal(false)
			-- ...AND NOW THE DOOR. It would refuse a REJOIN (`Phase.barredFromRejoin`) and it does
			-- not refuse him, because there is nobody left in the drive to refuse him on behalf of.
			expect(Match.enrolRefused(player.UserId)).to.equal(false)
			expect(Match.enrol(player)).to.equal(true)
			expect(Match.isParticipant(player.UserId)).to.equal(true)
			expect(Match.stats().restarts).to.equal(hadRestarts + 1)
			-- A NEW DRIVE, FROM THE BEGINNING -- the whole of Karen's sentence, live.
			expect(Match.driveNumber()).to.equal(wasDrive + 1)
			expect(Match.phase()).to.equal("Assigning")
			-- ...AND ONE RESTART, NOT TWO: he is in the roster now, so a second pad step is the
			-- idempotent door and nothing else.
			expect(Match.enrol(player)).to.equal(true)
			expect(Match.stats().restarts).to.equal(hadRestarts + 1)
			expect(Match.driveNumber()).to.equal(wasDrive + 1)
			-- AND THE SIDE HE WAS ON COMES BACK THROUGH THE STORED TURN, which is the mechanism
			-- task 261 chose for *"I need to be same role"* -- read, not assumed: in a world with no
			-- economy there is nothing owed and the fresh roster decides, so this is a NOTE and the
			-- assertion that belongs to this file is the drive, not the rotation.
			local gunBack = waitUntil(12, function()
				return toolIn(player.Character) ~= "none"
			end)
			TestKit.note(
				string.format(
					"task287 live restart: drive %d -> %d, team %s -> %s, held %s -> %s, restarts %d -> %d",
					wasDrive,
					Match.driveNumber(),
					tostring(wasTeam),
					tostring(Match.assignmentOf(player.UserId)),
					wasHeld,
					toolIn(player.Character),
					hadRestarts,
					Match.stats().restarts
				)
			)
			expect(gunBack).to.equal(true)
		end)
	end)
end
