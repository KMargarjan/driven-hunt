-- zz_pad_restart.spec: the LIVE door Karen's pad step goes through (task 287), on the real Match.
--
-- WHY THE `zz_` PREFIX. A restart is a drive boundary -- it respawns everybody and re-grants their
-- guns -- so driving it from the middle of the suite broke `weapon_shot.spec:476` and
-- `zz_drive_boundary.spec` (measured 2026-10-27 at `618aa228` and `df3e726e`). This file runs last
-- and waits for `ClientsFinished`, which is `zz_drive_boundary.spec`'s own arrangement.
--
-- **IT TAKES THE BRANCH THE LIVE ROSTER DICTATES, AND BOTH BRANCHES REALLY RUN.** The first cut
-- asserted the solo branch unconditionally and FAILED the two-player gate --
-- `[harness2] FAIL: 34/36 @ 187c23cf`, `zz_pad_restart.spec:91`, *"Expected false, got true"*
-- (the Director) -- because with two players the OTHER man is still a participant, so
-- `Match.enrolRefused` is TRUE and that is the multi-player rule this task builds, not a defect.
-- So: the one-player harness exercises the SOLO door and `test2` exercises the MULTI-PLAYER door,
-- and each says in a note which branch it took and why.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (section 4), docs/design/lobby.md (section 4.2)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

-- THE PAY-OUT, read for one claim: the drive a restart ABORTS is paid, here, and not twice
-- (`zz_drive_boundary.spec`'s arrangement for the `Scoring` edge).
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local Match = require(ServerScriptService:WaitForChild("Match"))
-- TWO DATA READS, for one fact: whether THIS PLACE can have a lobby at all. A world with no anchor
-- row has none (`ForestTestBoot` returns early), so the pad notice and the next-party enrolment
-- cannot be read here -- `lobby_live.spec` owns them. Said as a reading, not as a comment.
local LobbyData = require(game:GetService("ReplicatedStorage"):WaitForChild("Lobby"))
local Map = require(game:GetService("ReplicatedStorage"):WaitForChild("Map"))
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

-- WHO ELSE THE DRIVE HAS. The live roster, read off the owner one player at a time -- `isParticipant`
-- is the reader the lobby itself uses, and bots are not in this roster at all.
local function othersInDrive(me: Player): { string }
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= me and Match.isParticipant(player.UserId) then
			table.insert(out, player.Name)
		end
	end
	return out
end

return function()
	describe("the pad's own door after a respawn (task 287)", function()
		it("restarts the drive when he is alone in it, and refuses when he is not", function()
			local player = Players:GetPlayers()[1]
			if player == nil then
				-- NOT A SKIP and not silent: with no player there is no roster to empty, so the claim
				-- is made against the pure rule instead, which is where it is driven at every
				-- boundary (`match_phase.spec`).
				TestKit.note("task287: no player in this run, so neither live door was driven")
				expect(Match.enrolRefused(-999)).to.equal(false)
				return
			end
			expect(waitUntil(CLIENTS_DONE_TIMEOUT, clientsFinished)).to.equal(true)
			-- INSIDE A DRIVE FIRST, and `advanceForTests` is this suite's own seam for it. Nothing
			-- runs after this file, which is why it may be spent here.
			expect(waitUntil(60, function()
				if Match.phase() == "Running" or Match.phase() == "Assigning" then
					return true
				end
				Match.advanceForTests(2)
				return false
			end)).to.equal(true)
			local wasDrive = Match.driveNumber()
			local wasPhase = Match.phase()
			local wasTeam = Match.assignmentOf(player.UserId)
			local wasHeld = toolIn(player.Character)
			local hadRestarts = Match.stats().restarts
			local hadRefused = Match.stats().rejoinsRefused
			local paidBefore = Economy.stats().drivesPaid
			-- WHAT THE MAN HIMSELF HAS (task 299, finding 2): the drive he abandons must pay him no
			-- coins and count him no completed hunt, however many times he steps on a pad.
			local coinsBefore = Economy.balanceOf(player.UserId) or 0
			local huntsBefore = Economy.huntsOf(player.UserId) or 0
			local drivesBefore = Match.stats().drives
			-- HE RESPAWNS OUT OF A LIVE DRIVE (task 248's rule).
			expect(Match.isParticipant(player.UserId)).to.equal(true)
			expect(Match.withdraw(player)).to.equal(true)
			expect(Match.isParticipant(player.UserId)).to.equal(false)
			-- **AND THE BRANCH IS THE ROSTER'S, MEASURED AFTER THE WITHDRAWAL** -- which is when the
			-- question is asked in the game too: `Lobby.occupancy` asks it on the scan his pad is
			-- measured on, not when he reset.
			local others = othersInDrive(player)
			if #others == 0 then
				-- ---------------- SOLO: the clock of a drive nobody is in. His pad starts a new one.
				-- HE IS OUT OF THE DRIVE'S PAY (task 299, finding 2): `Match.withdraw` marks his
				-- board row `left`, which is what `Coins.forDrive` skips.
				local myRow
				for _, row in ipairs(Match.snapshot().rows or {}) do
					if row.userId == player.UserId then
						myRow = row
					end
				end
				expect(myRow).to.be.ok()
				expect(myRow.left).to.equal(true)
				expect(Match.enrolRefused(player.UserId)).to.equal(false)
				expect(Match.enrol(player)).to.equal(true)
				expect(Match.isParticipant(player.UserId)).to.equal(true)
				expect(Match.stats().restarts).to.equal(hadRestarts + 1)
				expect(Match.driveNumber()).to.equal(wasDrive + 1)
				expect(Match.phase()).to.equal("Assigning")
				-- THE PER-DRIVE WORK RAN FOR THE DRIVE THE RESTART DEALT (task 299, finding 3): the
				-- owner's block is keyed on the drive NUMBER now, so an `Assigning` -> `Assigning`
				-- restart -- which crosses no phase edge -- still counts a drive and rebuilds the
				-- board, and his row is a FRESH one rather than the `left` row above.
				expect(Match.stats().drives).to.equal(drivesBefore + 1)
				local freshRow
				for _, row in ipairs(Match.snapshot().rows or {}) do
					if row.userId == player.UserId then
						freshRow = row
					end
				end
				expect(freshRow).to.be.ok()
				expect(freshRow.left).to.equal(false)
				-- FOUR MORE PAD STEPS: he is in the roster, so each is the idempotent door and the
				-- drive number does not move again.
				for _ = 1, 4 do
					expect(Match.enrol(player)).to.equal(true)
				end
				expect(Match.stats().restarts).to.equal(hadRestarts + 1)
				expect(Match.driveNumber()).to.equal(wasDrive + 1)
				expect(Match.stats().drives).to.equal(drivesBefore + 1)
				-- NOT ONE COIN AND NOT ONE COMPLETED HUNT FOR THE DRIVE HE ABANDONED (finding 2 --
				-- the faucet). Conditional on the flag, read rather than assumed.
				expect(Economy.stats().duplicatePayouts).to.equal(0)
				if Economy.isEnabled() then
					expect(Economy.balanceOf(player.UserId) or 0).to.equal(coinsBefore)
					expect(Economy.huntsOf(player.UserId) or 0).to.equal(huntsBefore)
				end
				expect(Economy.stats().drivesPaid).to.equal(paidBefore)
				local gunBack = waitUntil(12, function()
					return toolIn(player.Character) ~= "none"
				end)
				TestKit.note(
					string.format(
						"task287 SOLO branch (nobody else in the drive): drive %d -> %d, phase %s -> %s, "
							.. "team %s -> %s, held %s -> %s, restarts %d -> %d, economy %s paid %d -> %d, "
							.. "his coins %d -> %d, his hunts %d -> %d, drives %d -> %d (5 pad steps)",
						wasDrive,
						Match.driveNumber(),
						wasPhase,
						Match.phase(),
						tostring(wasTeam),
						tostring(Match.assignmentOf(player.UserId)),
						wasHeld,
						toolIn(player.Character),
						hadRestarts,
						Match.stats().restarts,
						tostring(Economy.isEnabled()),
						paidBefore,
						Economy.stats().drivesPaid,
						coinsBefore,
						Economy.balanceOf(player.UserId) or 0,
						huntsBefore,
						Economy.huntsOf(player.UserId) or 0,
						drivesBefore,
						Match.stats().drives
					)
				)
				expect(gunBack).to.equal(true)
			else
				-- ---------------- MULTI-PLAYER: other men are still hunting. The door is SHUT, and
				-- the running drive is not his to be dropped back into (dispatch item 2).
				expect(Match.enrolRefused(player.UserId)).to.equal(true)
				expect(Match.enrol(player)).to.equal(false)
				expect(Match.isParticipant(player.UserId)).to.equal(false)
				-- NOTHING MOVED: no fresh drive, no clock reset, and no pay-out -- the drive the
				-- others are still in is untouched.
				expect(Match.driveNumber()).to.equal(wasDrive)
				expect(Match.phase()).to.equal(wasPhase)
				expect(Match.stats().restarts).to.equal(hadRestarts)
				expect(Match.stats().rejoinsRefused).to.equal(hadRefused + 1)
				expect(Economy.stats().drivesPaid).to.equal(paidBefore)
				-- WHAT HE GETS INSTEAD IS THE LOBBY'S, AND THIS PLACE HAS NO LOBBY -- read, not
				-- assumed: `Lobby.anchorFor` has no row for this world, which is why `ForestTestBoot`
				-- returns early here. So the `DHPadLate` notice and the next-party enrolment are
				-- asserted in `lobby_live.spec` (fake occupants, the real rule) and cannot be read in
				-- this place. Stated rather than silently skipped.
				--
				-- NOT `Lobby.stats()`: measured at `247b493b` under `test2`, `scans` was 1 -- the
				-- counters outlive `lobby_live.spec`'s own `start`/`stop`, so they are a fact about
				-- the SUITE and not about this place.
				local hasLobby = LobbyData.anchorFor(Map.EXPECTED_WORLD) ~= nil
				TestKit.note(
					string.format(
						"task287 MULTI-PLAYER branch (still in the drive: %s): refused=%s enrolled=%s "
							.. "drive %d (unchanged), phase %s, restarts %d (unchanged), rejoinsRefused %d -> %d, "
							.. "paid %d (unchanged); the pad notice and the next party are the LOBBY's and this "
							.. "place has a lobby = %s (world %s) -- see lobby_live.spec",
						table.concat(others, ", "),
						tostring(Match.enrolRefused(player.UserId)),
						tostring(Match.isParticipant(player.UserId)),
						Match.driveNumber(),
						Match.phase(),
						Match.stats().restarts,
						hadRefused,
						Match.stats().rejoinsRefused,
						Economy.stats().drivesPaid,
						tostring(hasLobby),
						tostring(Map.EXPECTED_WORLD)
					)
				)
				expect(hasLobby).to.equal(false)
			end
		end)
	end)
end
