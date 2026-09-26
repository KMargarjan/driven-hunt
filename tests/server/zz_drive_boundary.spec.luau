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

local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

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
			Weapon.setArmingPolicy(function()
				error("the drive's policy is broken")
			end)
			for _, player in ipairs(Players:GetPlayers()) do
				-- Without the pcall inside mayArm this raises, which is the falsifying case.
				expect(pcall(Weapon.refreshArming, player)).to.equal(true)
			end
			task.wait(0.2)
			for _, player in ipairs(Players:GetPlayers()) do
				-- The fallback is the weapon's own default, which arms everybody.
				expect(Weapon.mayArmForTests(player)).to.equal(true)
			end

			Weapon.setArmingPolicy(Match.mayCarryWeapon)
			for _, player in ipairs(Players:GetPlayers()) do
				Weapon.refreshArming(player)
				expect(Weapon.mayArmForTests(player)).to.equal(Match.mayCarryWeapon(player))
			end
		end)

		it("ends the drive: Running -> Scoring, every tie freed and every rope gone", function()
			expect(Match.phase()).to.equal("Running")
			before = Match.snapshot()
			local tiedBefore = #before.tied
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

		it("gives the guns back, because the tie went with the drive", function()
			-- The other half of "until the drive ends": Assigning re-places and re-arms, so a shooter
			-- who spent the last drive tied to a tree is carrying a gun again.
			for _, player in ipairs(Players:GetPlayers()) do
				expect(waitUntil(PHASE_TIMEOUT, function()
					return player.Team ~= nil
				end)).to.equal(true)
				local function holdsGun(): boolean
					local backpack = player:FindFirstChildOfClass("Backpack")
					if backpack and backpack:FindFirstChildOfClass("Tool") then
						return true
					end
					local character = player.Character
					return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
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
