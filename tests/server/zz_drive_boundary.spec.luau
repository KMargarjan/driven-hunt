-- zz_drive_boundary.spec: the drive's own boundary, on the REAL production Match, in seconds.
--
-- WHY THE `zz_` PREFIX, AND WHY THIS WAITS. A drive is 600 seconds long, so until Task 41 nothing in
-- the suite had ever seen Running -> Scoring -> the next drive, and six queued notes sat behind that
-- one fact (TASKS.md 38a(i)). `Match.advanceForTests` moves this owner's own clock forward, gated on
-- Studio plus a fresh harness token, so the machine takes exactly the transitions it would have taken
-- ten minutes later -- with the real numbers, the real effects and the real players.
--
-- Crossing a boundary is not free: Scoring clears every boar and frees every tied player, and the
-- next Assigning RESPAWNS everybody and re-grants their guns. Doing that while a client suite is
-- still running would break it -- "a spec that revoked this gun mid-session broke exactly this
-- window, and was withdrawn" (tests/client/weapon_client.spec.luau, Task 34). So this spec runs LAST
-- (the prefix) and, before it touches anything, WAITS for every player's client to have written its
-- TestReport attribute, which is the one observable "that client is finished".
--
-- WHAT DISTINGUISHES THE PRE-FIX BEHAVIOUR is the board at the boundary, so the sharpest assertions
-- here need a drive with something on it -- which is the TWO-PLAYER run, where the shooter really is
-- tied by a real shot and really does carry -50. The one-player run asserts the same shape with an
-- empty board. Both are stated rather than hidden.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 4.1, 8.4, 9.1)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- A PLAYER'S COINS (task 170), read here for one claim: the drive paid, on this edge, exactly once.
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
-- One fact, for one question: is the Tool in this player's hands a GUN? (task 152)
local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Weapons"))

-- How long to wait for every client to finish before disturbing the drive. Generous: a two-player
-- client suite runs for minutes, and waiting costs a passing run nothing.
local CLIENTS_DONE_TIMEOUT = 240
local PHASE_TIMEOUT = 20

-- Every award the drive published, from require time, so a violation's -50 is recorded whenever it
-- happens rather than only if this spec is watching at that moment (TASKS.md 35b(b)).
local awards = {}
Match.Scored:Connect(function(award)
	table.insert(awards, award)
end)

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

-- THE HARNESS SAYS WHEN, and it has to, because the clients cannot: a LocalPlayer attribute written
-- on the client does NOT replicate to the server (measured, Task 41 -- the first version of this spec
-- waited 240 s for a TestReport attribute that had been set on the client 200 s earlier), and this
-- system has no inbound remote by design. So the harness sets ServerStorage's `ClientsFinished` to
-- this run's own token once every client of the run has reported.
local function clientsFinished(): boolean
	if #Players:GetPlayers() == 0 then
		return true
	end
	return ServerStorage:GetAttribute("ClientsFinished") == TestKit.activeToken()
end

local function ropes(): number
	local folder = Workspace:FindFirstChild("DriveMarkers")
	return if folder then #folder:GetChildren() else 0
end

-- THE RESULTS SCENE, COUNTED OFF THE WORLD (task 159): how many lamps and how many animals are
-- standing in `Workspace.DriveScene` right now. It reads the folder the drive actually built rather
-- than `Scene.stats()`, because a counter that says "I built four" is not the same claim as four
-- lamps being in the world.
local function sceneCounts(): (number, number)
	local folder = Match.Scene.folder()
	if not folder then
		return 0, 0
	end
	local lamps, bodies = 0, 0
	for _, child in ipairs(folder:GetChildren()) do
		if string.find(child.Name, Match.Scene.LIGHT_PREFIX, 1, true) == 1 then
			lamps += 1
		elseif string.find(child.Name, Match.Scene.ANIMAL_PREFIX, 1, true) == 1 then
			bodies += 1
		end
	end
	return lamps, bodies
end

local function totalPoints(snapshot): number
	local sum = 0
	for _, row in ipairs(snapshot.rows) do
		sum += math.abs(row.points) + row.kills + row.violations
	end
	return sum
end

return function()
	describe("the drive's boundary, driven by the owner's own clock", function()
		local before, drivePayload

		it("has a seam that is open here and shut everywhere else", function()
			-- The gate is TestKit's, not a second copy: Studio, plus a gated run in progress. A
			-- playtest is never given a token so TestKit.run never starts and activeToken stays nil,
			-- and a published place has no TestKit at all -- so a shortened drive cannot happen
			-- outside a harness run.
			expect(TestKit.activeToken()).to.be.ok()
			expect(Match.testSeconds()).to.equal(0) -- nothing has moved this clock yet
			expect(Match.advanceForTests(0)).to.equal(true)
		end)

		it("waits for every client to finish before it disturbs anything", function()
			-- Scoring clears the boars and frees the tied; Assigning respawns everybody and re-grants
			-- their guns. Both would break a client suite that is still asserting.
			local done = waitUntil(CLIENTS_DONE_TIMEOUT, clientsFinished)
			-- WHAT THE LIVE DRIVE ACTUALLY DID, printed EVERY run and not only when something breaks
			-- (Task 79). When `shoot-the-boar` could not stage -- "no BasePart inside Workspace.Boars
			-- after 60 s" -- there was no way to tell from the outside whether the drive had never
			-- reached a release, had released and the scenario missed it, or had tried and failed:
			-- `releasesDeferred` is the third case, and `applySpawnSounder` hands a refused sounder
			-- back to be retried, so a spawn that cannot succeed defers forever and silently.
			local live = Match.stats()
			local boars = Workspace:FindFirstChild("Boars")
			TestKit.note(
				string.format(
					"zz_drive_boundary: drive live -- phase=%s releases=%d deferred=%d boars=%d alive=%d "
						.. "firstReleaseAfter=%.1fs testSeconds=%d",
					Match.phase(),
					live.releases,
					live.releasesDeferred,
					live.boarsReleased,
					if boars then #boars:GetChildren() else -1,
					live.firstReleaseAfterSeconds,
					live.testSeconds
				)
			)
			if not done then
				TestKit.note("zz_drive_boundary: a client never reported; the drive was left alone")
			end
			expect(done).to.equal(true)
		end)

		it("falls back to the weapon's own rule when the drive's policy errors (32a(d))", function()
			-- The weapon asks an INJECTED policy who may carry a gun, inside a pcall, and falls back
			-- to Shotgun.CONFIG.shouldArm when it throws -- so a broken drive can neither disarm
			-- everybody nor arm everybody. Untested until now because it needs the live owner; it is
			-- here, after every client has finished, because it hands a gun to a driver for the two
			-- seconds before the policy is put back, and a client asserting "no Tool at any point"
			-- must not be watching.
			-- THE POLICY IS RESTORED BEFORE ANYTHING IS ASSERTED (audit-004 F1). It used to be put
			-- back four `expect`s later, in this same `it` -- and TestEZ abandons an `it` at the first
			-- failed `expect`, including the `pcall(Weapon.refreshArming, player)` below, which is the
			-- falsifying case this test exists for. One genuine failure would have left the LIVE
			-- server holding a policy that throws: every later `refreshArming` falls through the pcall
			-- to Shotgun.CONFIG.shouldArm and arms everybody, and the three specs after this one
			-- assert gun state and tie state. One failure became four.
			--
			-- So: gather the observations while the broken policy is installed, put the real one back
			-- unconditionally, and only then assert. The `pcall` around the gathering means even a
			-- raise leaves the restore reachable.
			local raised, armedUnderBrokenPolicy = false, {}
			Weapon.setArmingPolicy(function()
				error("the drive's policy is broken")
			end)
			local ok = pcall(function()
				for _, player in ipairs(Players:GetPlayers()) do
					-- Without the pcall inside mayArm this raises, which is the falsifying case.
					if not pcall(Weapon.refreshArming, player) then
						raised = true
					end
				end
				task.wait(0.2)
				for _, player in ipairs(Players:GetPlayers()) do
					table.insert(armedUnderBrokenPolicy, Weapon.mayArmForTests(player))
				end
			end)
			Weapon.setArmingPolicy(Match.mayCarryWeapon)
			for _, player in ipairs(Players:GetPlayers()) do
				Weapon.refreshArming(player)
			end

			expect(ok).to.equal(true)
			expect(raised).to.equal(false)
			expect(#armedUnderBrokenPolicy > 0).to.equal(true)
			for _, armed in ipairs(armedUnderBrokenPolicy) do
				-- The fallback is the weapon's own default, which arms everybody.
				expect(armed).to.equal(true)
			end
			for _, player in ipairs(Players:GetPlayers()) do
				expect(Weapon.mayArmForTests(player)).to.equal(Match.mayCarryWeapon(player))
			end
		end)

		it("leaves the live owner holding the drive's own policy, whatever happened above", function()
			-- The guarantee the restore above buys, asserted separately so it survives a failure in
			-- the test that makes it: whatever the policy test did, the server is back on the drive's
			-- rule before the three specs after it look at gun state.
			for _, player in ipairs(Players:GetPlayers()) do
				Weapon.refreshArming(player)
				expect(Weapon.mayArmForTests(player)).to.equal(Match.mayCarryWeapon(player))
			end
		end)

		-- THE HORN'S DOOR, PAYING SOMEBODY, THROUGH THE REAL OWNER (round 1 finding 1). Every other
		-- assertion about `Match.creditPush` in the suite is a REFUSAL, so `function Match.creditPush()
		-- return 0 end` passed the whole gate and the lines that actually pay a beater were never run.
		-- This is the live half: a real drive, a real player really made a beater, real boar ids in,
		-- credit out -- and then the credit read back through the very function `onDowned` hands to
		-- `Score.kill`, so the chain is proved where the game reads it and not beside it.
		--
		-- IT IS LAST OF THE `Running` CASES on purpose: `Phase`'s `team` branch emits `placePlayers`,
		-- which respawns him, and the three gun cases above must not meet that. The side is put back
		-- before this case ends.
		it("pays a beater through the live owner, and the credit is where Score.kill will read it", function()
			expect(Match.phase()).to.equal("Running")
			local player = Players:GetPlayers()[1]
			if not player then
				TestKit.note("zz_drive_boundary: no player; the horn's credit door was not driven live")
				return
			end
			local was = Match.assignmentOf(player.UserId)
			local userId = player.UserId
			-- A HUNTER EARNS NO BEATER POINTS, asserted through the OWNER and not only through the pure
			-- predicate: this is the `state.assignment` read, which nothing reached before.
			if was ~= "Drivers" then
				expect(Match.creditPush(userId, { "zzBoarA" })).to.equal(0)
				expect(Match.requestTeam(player, "Drivers")).to.equal(true)
			end
			expect(Match.assignmentOf(userId)).to.equal("Drivers")

			-- TWO ANIMALS AND ONE PIECE OF RUBBISH: the list comes off a signal payload through a
			-- composition root, so a non-string id is skipped and never indexes the table with nil
			-- (task 83's "table index is nil", which took out every step of every quick-test session).
			local creditsBefore = Match.stats().hornCredits
			expect(Match.creditPush(userId, { "zzBoarA", "zzBoarB", 7 })).to.equal(2)
			expect(Match.stats().hornCredits - creditsBefore).to.equal(2)

			-- WHERE `Score.kill` WILL LOOK: `Match.pushCreditFor` IS `creditFor`, the function `onDowned`
			-- passes straight into `Score.kill`. So this is the real read of the real write.
			local credit = Match.pushCreditFor("zzBoarA")
			expect(type(credit[userId])).to.equal("number")
			expect(next(Match.pushCreditFor("zzBoarB"))).to.be.ok()
			expect(next(Match.pushCreditFor("zzBoarNeverTouched"))).to.equal(nil)

			-- ...AND IT REALLY TURNS INTO POINTS. The same board, the same scoring function the drive
			-- calls, with the credit this door just wrote: the beater is paid `BEATER_PUSH` for an animal
			-- a DIFFERENT player shot. This is the sentence the whole beater half of task 160 is.
			local board = Match.Score.join(Match.Score.new(), userId, player.Name, "Drivers")
			local record = {
				id = "zzBoarA",
				at = 1,
				kind = "male",
				killingZone = "chest",
				killedByUserId = userId + 1,
				killedByName = "somebody else",
				contributors = {},
			}
			board = (Match.Score.kill(board, record, credit, Match.CONFIG))
			expect(board.rows[userId].points).to.equal(Match.CONFIG.POINTS.BEATER_PUSH)
			expect(board.rows[userId].pushes).to.equal(1)
			TestKit.note(
				string.format(
					"zz_drive_boundary: horn credit -> 2 animal(s), hornCredits +%d, beater paid %d point(s)",
					Match.stats().hornCredits - creditsBefore,
					board.rows[userId].points
				)
			)

			-- A SECOND BLAST AT THE SAME ANIMAL IS STILL ONE CREDIT (round 1, note 4): the write is
			-- idempotent, so the tally must not say two.
			local again = Match.stats().hornCredits
			expect(Match.creditPush(userId, { "zzBoarA" })).to.equal(0)
			expect(Match.stats().hornCredits).to.equal(again)

			-- PUT HIM BACK on the side the drive gave him, so the cases after this see the player they
			-- expect. The ids above are not a boar's and no boar will ever be downed under them, so the
			-- credit they left behind can never pay anybody.
			if was ~= "Drivers" and was ~= nil then
				Match.requestTeam(player, was)
				expect(Match.assignmentOf(userId)).to.equal(was)
				expect(waitUntil(PHASE_TIMEOUT, function()
					return Match.Body.teamOf(player) == was
				end)).to.equal(true)
			end
		end)

		it("ends the drive: Running -> Scoring, every tie freed and every rope gone", function()
			expect(Match.phase()).to.equal("Running")
			before = Match.snapshot()
			local tiedBefore = #before.tied
			-- BEFORE the clock moves, so "it rose by exactly one" is a measurement and not a guess.
			local paidBefore = Economy.stats().drivesPaid
			TestKit.note(
				string.format(
					"zz_drive_boundary: drive %d had %d row(s), %d tied, %d point-unit(s), %d rope(s)",
					before.driveNumber,
					#before.rows,
					tiedBefore,
					totalPoints(before),
					ropes()
				)
			)

			-- Straight past the end of Running. Nothing is skipped: the machine still takes one
			-- transition per step, from its own phaseEndsAt.
			expect(Match.advanceForTests(Match.CONFIG.DRIVE_SECONDS + 1)).to.equal(true)
			expect(waitUntil(PHASE_TIMEOUT, function()
				return Match.phase() == "Scoring"
			end)).to.equal(true)

			-- THE TIE LASTS UNTIL THE DRIVE ENDS, and then it does not (design section 8.4,
			-- TIE_UNTIL_DRIVE_END). In the two-player run a shooter really is tied here, so this is
			-- the release of a real tie; with one player the set was already empty.
			expect(#Match.snapshot().tied).to.equal(0)
			expect(ropes()).to.equal(0)
			for _, player in ipairs(Players:GetPlayers()) do
				expect(Match.isTied(player.UserId)).to.equal(false)
			end

			-- The score screen still shows what the drive did: Scoring is where the board is READ.
			expect(Match.snapshot().driveNumber).to.equal(before.driveNumber)
			expect(#Match.snapshot().rows).to.equal(#before.rows)

			-- ...AND THE DRIVE PAID, ON THIS EDGE, EXACTLY ONCE (task 170). This is the only place in the
			-- suite where the pay-out is driven by the REAL production path -- `Match`'s own dispatch, on
			-- the `Scoring` edge, with whatever `Economy` the composition root wired. `economy.spec` owns
			-- the arithmetic; what this owns is "it happened, here, and not twice".
			--
			-- IT IS CONDITIONAL ON THE FLAG, and the condition is read rather than assumed: `COINS` is
			-- born OFF (task 170), so on a default build the honest assertion is that NOTHING was paid
			-- and no row carries a coin -- which is "off is the game before this task" measured at the
			-- one boundary that could break it.
			local paidAfter = Economy.stats().drivesPaid
			if Economy.isEnabled() then
				expect(paidAfter).to.equal(paidBefore + 1)
				expect(Economy.stats().duplicatePayouts).to.equal(0)
				expect(Economy.lastPaidDrive()).to.equal(before.driveNumber)
				-- THE FORCED SNAPSHOT OF THE RESULTS SCENE ALREADY CARRIES IT, which is why the pay-out
				-- is on the edge BEFORE `applyEffects` (TASKS.md 32a(c) in a new place): a pay-out after
				-- the effects would leave Karen reading `--` for up to STATE_HEARTBEAT seconds.
				local sent = Match.lastSent()
				expect(sent).to.be.ok()
				for _, scoreRow in ipairs(sent.rows) do
					expect(type(scoreRow.earned)).to.equal("number")
					expect(type(scoreRow.coins)).to.equal("number")
				end
				TestKit.note(
					string.format("zz_drive_boundary: drive %d paid %d row(s)", before.driveNumber, #sent.rows)
				)
			else
				expect(paidAfter).to.equal(0)
				for _, scoreRow in ipairs(Match.snapshot().rows) do
					expect(scoreRow.earned).to.equal(nil)
					expect(scoreRow.coins).to.equal(nil)
				end
				TestKit.note("zz_drive_boundary: COINS is off, so the boundary paid nothing and no row carries one")
			end
		end)

		it("built the results scene: four lamps, this drive's animals, everybody held round them", function()
			-- THE SCENE KAREN ASKED FOR, in the world, at the real boundary (task 159): *"all they
			-- standing around the animals there is light on 4 corners"*. Nothing here is a pure
			-- layout -- match_scene.spec owns the arithmetic; this is the claim that the drive
			-- actually built it and actually moved the players who were standing in it.
			expect(Match.phase()).to.equal("Scoring")
			local lamps, bodies = sceneCounts()
			local kills = Match.driveKills()
			-- `Match.gatherSpot` AND NOT `gatherSpotFor` SINCE TASK 191: the live owner's own choice
			-- between the world's spot and the drive's. In the DEV place there is no lobby at all
			-- (`Lobby.anchorFor` has no `map:v1` row), so `world.gatherSpot` is absent, the drive's
			-- own rule must answer, and `sceneWorldSpots` must be 0 -- which is the fallback proved
			-- on the real production owner rather than on a hand-written reader.
			local spot, _facing, fromWorld = Match.gatherSpot()
			TestKit.note(
				string.format(
					"zz_drive_boundary: scene lamps=%d animals=%d kills=%d spot=%s fromWorld=%s"
						.. " | scenes=%d moved=%d nowhere=%d worldSpots=%d",
					lamps,
					bodies,
					#kills,
					tostring(spot),
					tostring(fromWorld),
					Match.stats().scenes,
					Match.stats().sceneMoved,
					Match.stats().scenesNowhere,
					Match.stats().sceneWorldSpots
				)
			)
			expect(fromWorld).to.equal(false)
			expect(Match.stats().sceneWorldSpots).to.equal(0)
			-- THE DEV MAP HAS STANDS, so there is somewhere to gather and the scene must exist. A
			-- world with no stands is the `scenesNowhere` branch, and forest_markers.spec is where
			-- that case lives.
			expect(spot).to.be.ok()
			expect(Match.stats().scenesNowhere).to.equal(0)
			expect(Match.stats().scenes >= 1).to.equal(true)
			expect(Match.Scene.folder()).to.be.ok()
			expect(lamps).to.equal(4)
			-- THE ROW IS THIS DRIVE'S OWN KILLS, capped -- not a number of its own. With one player
			-- and no staged kill that is zero animals and four lamps, which is still the scene.
			expect(bodies).to.equal(math.min(#kills, Match.CONFIG.SCENE.MAX_ANIMALS))

			-- EVERYBODY IS HELD AND STANDING ROUND THE ANIMALS, which is the dispatch's item 3: the
			-- hold is the SAME freeze task 158 built, so `isHeld` is the fact and the ring is where.
			local radius = Match.CONFIG.SCENE.RING_RADIUS_STUDS
			for _, player in ipairs(Players:GetPlayers()) do
				expect(Match.isHeld(player.UserId)).to.equal(true)
				local character = player.Character
				local root = character and character.PrimaryPart
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					expect(humanoid.WalkSpeed).to.equal(0)
				end
				if root then
					expect(root.Anchored).to.equal(true)
					-- ON THE RING, measured flat: the y is the drive's own stand height above the
					-- gathering spot and the character's own root height on top of it, so the
					-- horizontal distance is the honest assertion.
					local flat = Vector3.new(root.Position.X - spot.X, 0, root.Position.Z - spot.Z)
					TestKit.note(
						string.format(
							"zz_drive_boundary: %s stands %.1f studs from the gathering spot (ring %d)",
							player.Name,
							flat.Magnitude,
							radius
						)
					)
					-- A stud of tolerance either side: the character is anchored at the CFrame
					-- `Scene.ringLayout` chose, and `Body.standCharacter` pivots the model's pivot.
					expect(math.abs(flat.Magnitude - radius) <= 2).to.equal(true)
				end
			end
			expect(Match.Body.stood() >= #Players:GetPlayers()).to.equal(true)
		end)

		it("starts the next drive, and TELLS the clients the new drive's rows", function()
			expect(Match.advanceForTests(Match.CONFIG.SCORE_SECONDS + 1)).to.equal(true)
			-- WAIT FOR THE PUSH, not just for the phase. `Phase.step` sets the phase and the owner
			-- then APPLIES the effects, and one of them -- placePlayers -> Body.place ->
			-- LoadCharacter -- yields, so `Match.phase()` reads "Assigning" a moment before the
			-- broadcast that announces it goes out. Measured here, Task 41.
			expect(waitUntil(PHASE_TIMEOUT, function()
				local sent = Match.lastSent()
				return Match.phase() == "Assigning" and sent ~= nil and sent.driveNumber == before.driveNumber + 1
			end)).to.equal(true)
			expect(Match.snapshot().driveNumber).to.equal(before.driveNumber + 1)

			-- THE PAYLOAD, NOT THE SNAPSHOT (TASKS.md 32a(c)). The drive-start broadcast used to be
			-- built before the new drive's board was, so it carried the PREVIOUS drive's points, and
			-- every client showed them until the next event or the 5-second heartbeat -- while
			-- snapshot() read correctly a quarter of a second later, which is why this asserts on
			-- what the clients were actually sent.
			drivePayload = Match.lastSent()
			expect(drivePayload).to.be.ok()
			expect(drivePayload.driveNumber).to.equal(before.driveNumber + 1)
			-- ...and it really was a PUSH, not the snapshot read back: a phase entry forces one past
			-- STATE_MIN_INTERVAL, which is what stopped this one vanishing (match_phase.spec).
			expect(Match.stats().broadcasts > 0).to.equal(true)
			local who = {}
			for _, row in ipairs(drivePayload.rows) do
				table.insert(who, string.format("%s=%d", row.name, row.points))
			end
			TestKit.note(
				string.format(
					"zz_drive_boundary: drive-start payload carried %d point-unit(s) (was %d): %s",
					totalPoints(drivePayload),
					totalPoints(before),
					table.concat(who, ", ")
				)
			)
			for _, row in ipairs(drivePayload.rows) do
				expect(row.points).to.equal(0)
				expect(row.kills).to.equal(0)
				expect(row.violations).to.equal(0)
				expect(row.left).to.equal(false)
			end
			-- EVERY PLAYER IS ON IT, which is the claim; the row COUNT is not, because a board also
			-- carries a row for any userId that contributed damage, and a spec's synthetic shooter
			-- id reaches the production board that way (it is visible in
			-- .screenshots/task35-score-screen.png, measured again here).
			local named = {}
			for _, row in ipairs(drivePayload.rows) do
				named[row.userId] = true
			end
			for _, player in ipairs(Players:GetPlayers()) do
				expect(named[player.UserId]).to.equal(true)
			end
		end)

		it("took the scene down before the next drive, and let everybody go", function()
			-- The other half of the scene (task 159): `Phase.enterAssigning` emits `clearScene` and
			-- `free` BEFORE anybody is placed, so the next drive does not start in last drive's
			-- lamplight and nobody walks to a stand frozen.
			--
			-- MEASURED BEFORE IT IS ASSERTED, and the reason is in this case's own history: the
			-- Director's two-player run failed here (`[harness2] FAIL 33/35 @ 7ea945f`) and the
			-- failure said only "false, expected true" for one of two players. A drive has TWO
			-- representations of a side -- `Player.Team`, which the engine replicates, and the
			-- drive's own `state.assignment` -- and three freezes that could be involved, so the row
			-- below prints all of them for every player first. A failure now names which.
			expect(Match.phase()).to.equal("Assigning")
			expect(Match.Scene.folder()).to.equal(nil)
			local lamps, bodies = sceneCounts()
			expect(lamps).to.equal(0)
			expect(bodies).to.equal(0)
			expect(Match.stats().scenesCleared >= 1).to.equal(true)
			local rows = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				table.insert(
					rows,
					string.format(
						"%s team=%s drive=%s held=%s holding=%s tied=%s ws=%s",
						player.Name,
						tostring(Match.Body.teamOf(player)),
						tostring(Match.assignmentOf(player.UserId)),
						tostring(Match.isHeld(player.UserId)),
						tostring(Match.Body.isHolding(player.UserId)),
						tostring(Match.isTied(player.UserId)),
						tostring(humanoid and humanoid.WalkSpeed)
					)
				)
			end
			TestKit.note(
				string.format(
					"zz_drive_boundary: at drive %d's countdown -- %s | holds=%d reapplied=%d",
					Match.snapshot().driveNumber,
					table.concat(rows, " | "),
					Match.stats().holds,
					Match.stats().holdsReapplied
				)
			)
			for _, player in ipairs(Players:GetPlayers()) do
				-- A BEATER IS HELD AGAIN -- at the START LINE, which is task 158's hold and lasts the
				-- countdown; a hunter is free to walk to his stand. So the claim is not "nobody is
				-- held", it is "nobody is held who should not be".
				local team = Match.Body.teamOf(player)
				-- THE TWO REPRESENTATIONS AGREE, which is the other half of the diagnosis: if they
				-- ever disagree, the line below would be asserting against the wrong one.
				expect(Match.assignmentOf(player.UserId)).to.equal(team)
				expect(Match.isHeld(player.UserId)).to.equal(team == Match.CONFIG.START_HOLD_TEAM)
			end
		end)

		it("never shows a beater who is not yet held, mid-respawn (the two-player failure)", function()
			-- THE ONE-PLAYER REPRODUCTION OF WHAT THE TWO-PLAYER RUN CAUGHT (task 159). The `hold`
			-- effect used to be emitted AFTER `placePlayers`, whose owner YIELDS in
			-- `Player:LoadCharacter` -- so for the length of a respawn the drive said "this player is
			-- a beater" while `Match.isHeld` said no, and the Heartbeat broadcast that drive to every
			-- client inside that window. The Director's run found it
			-- (`[harness2] FAIL 33/35 @ 7ea945f`) because with TWO players the roster makes one of
			-- them a beater at every boundary; the case above cannot see it, because it reads the
			-- drive only once, after the window has closed.
			--
			-- `Match.requestTeam` is the existing seam (task 157) and goes through the SAME branch of
			-- the same machine, with the same `placePlayers`. Run from its own coroutine it yields
			-- exactly where the drive does, so this samples the live owner from the outside and states
			-- the invariant the fix buys:
			--
			--   WHILE THE COUNTDOWN RUNS, THE DRIVE NEVER CALLS SOMEBODY A BEATER WITHOUT HOLDING HIM.
			--
			-- With the old order this fails by several hundred milliseconds of samples; with the hold
			-- emitted first there is no yield between the two facts and nothing can land between them.
			local player = Players:GetPlayers()[1]
			if not player or Match.phase() ~= "Assigning" then
				TestKit.note("zz_drive_boundary: no player or not in the countdown; the hold window was not sampled")
				return
			end
			local beaters = Match.CONFIG.START_HOLD_TEAM
			local hunters = if beaters == "Drivers" then "Shooters" else "Drivers"
			local was = Match.assignmentOf(player.UserId)

			-- HE HAS TO START ON THE OTHER SIDE, or the request is a no-op and samples nothing: the
			-- machine's `team` branch only acts when the side actually changes. With one player the
			-- roster's swap makes him a beater at drive 2, which is exactly the case that was being
			-- missed -- so this moves him off it first, and waits for that respawn to finish.
			if was == beaters then
				Match.requestTeam(player, hunters)
				expect(waitUntil(PHASE_TIMEOUT, function()
					return Match.assignmentOf(player.UserId) == hunters and not Match.isHeld(player.UserId)
				end)).to.equal(true)
			end
			expect(Match.assignmentOf(player.UserId)).to.equal(hunters)

			local done, samples, gaps = false, 0, {}
			task.spawn(function()
				Match.requestTeam(player, beaters)
				done = true
			end)
			local started = os.clock()
			-- `done` IS CHECKED AFTER A SAMPLE, not before: the spawned coroutine runs until its first
			-- yield before this loop starts, so testing it first would skip the whole window.
			repeat
				samples += 1
				-- ONLY INSIDE THE COUNTDOWN: in `Running` nobody is held at all, which is the rule and
				-- not a gap (`Phase`'s `team` branch holds only in `Assigning`).
				if
					Match.phase() == "Assigning"
					and Match.assignmentOf(player.UserId) == beaters
					and not Match.isHeld(player.UserId)
				then
					table.insert(gaps, string.format("%.3fs", os.clock() - started))
				end
				task.wait()
			until done or os.clock() - started > 10
			TestKit.note(
				string.format(
					"zz_drive_boundary: sampled the hold window %d time(s) over %.2fs -- %d gap(s)%s",
					samples,
					os.clock() - started,
					#gaps,
					if #gaps > 0 then " at " .. table.concat(gaps, ", ") else ""
				)
			)
			expect(done).to.equal(true)
			-- IT REALLY SAMPLED ACROSS THE YIELD: a respawn takes frames, so a sampler that saw one
			-- frame saw nothing and this case would be vacuous.
			expect(samples > 1).to.equal(true)
			expect(#gaps).to.equal(0)
			-- ...and the request was honoured, so this was the real branch and not a no-op.
			expect(Match.assignmentOf(player.UserId)).to.equal(beaters)
			expect(Match.isHeld(player.UserId)).to.equal(true)

			-- THE OTHER DIRECTION, AND THE TIDY-UP IN ONE: put back on the side the drive had given
			-- him, he is RELEASED (or held) to match, and the cases after this see the player they
			-- expect.
			Match.requestTeam(player, was)
			expect(Match.assignmentOf(player.UserId)).to.equal(was)
			expect(Match.isHeld(player.UserId)).to.equal(was == beaters)
			expect(waitUntil(PHASE_TIMEOUT, function()
				return Match.Body.teamOf(player) == was
			end)).to.equal(true)
		end)

		it("gives the guns back, because the tie went with the drive", function()
			-- The other half of "until the drive ends": Assigning re-places and re-arms, so a shooter
			-- who spent the last drive tied to a tree is carrying a gun again.
			for _, player in ipairs(Players:GetPlayers()) do
				expect(waitUntil(PHASE_TIMEOUT, function()
					return player.Team ~= nil
				end)).to.equal(true)
				-- A GUN, NOT JUST A TOOL (task 152). The beater's horn is a `Tool` too, and in a drive
				-- the DRIVER -- the player who must NOT be armed -- is exactly the one who carries one,
				-- so `FindFirstChildOfClass("Tool")` answered "he has a gun" for a man holding a horn.
				-- MEASURED: this assertion failed on the first gate run of task 152.
				local function holdsGun(): boolean
					for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
						for _, child in ipairs(if container then container:GetChildren() else {}) do
							if Weapons.isWeaponTool(child) then
								return true
							end
						end
					end
					return false
				end
				local expected = Match.mayCarryWeapon(player)
				expect(waitUntil(if expected then PHASE_TIMEOUT else 2, function()
					return holdsGun() == expected
				end)).to.equal(true)
			end
			TestKit.note(
				string.format(
					"zz_drive_boundary: weapon granted=%d revoked=%d",
					Weapon.stats().granted,
					Weapon.stats().revoked
				)
			)
		end)

		it("published the penalty as an award, like every other (35b(b))", function()
			-- A violation costs SAFETY_PENALTY points, and Score.violation returns that award --
			-- which the owner used to drop on the floor, so Match.Scored carried kills and escapes
			-- and never a penalty. There is a violation to see only when somebody was tied, which is
			-- the two-player run; with one player nothing fires this and the count is the assertion.
			local safety = {}
			for _, award in ipairs(awards) do
				if award.reason == "safety" then
					table.insert(safety, award)
				end
			end
			TestKit.note(string.format("zz_drive_boundary: %d award(s), %d of them safety", #awards, #safety))
			expect(#safety).to.equal(Match.stats().violations)
			for _, award in ipairs(safety) do
				expect(award.points).to.equal(Match.CONFIG.POINTS.SAFETY_PENALTY)
			end
		end)

		it("counted the test time it was given, and nothing else moved the clock", function()
			expect(Match.testSeconds()).to.equal(Match.stats().testSeconds)
			expect(Match.testSeconds() >= Match.CONFIG.DRIVE_SECONDS).to.equal(true)
		end)
	end)
end
