-- sync.spec: asserts that the Rojo sync delivered disk content into the running server.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-09-24-toolchain.md
-- The harness (tools/studio_mcp.py) also compares every synced script's Source with disk before Play.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local DEV_PLACE_ID = 136410205938347 -- default.project.json servePlaceIds

return function()
	-- THE REPORT'S OWN COMPACTION (task 367, round 2 note). `TestKit.compactFailure` is what puts
	-- the failing spec's name into the report, and `describe_failure` in tools/studio_mcp.py reads
	-- the `" | "` it writes. That contract was pinned only by a literal transcribed into the Python
	-- selftest, so the Luau half could drift and degrade silently back to the hole TASKS.md 362b
	-- fell into: a failure printed with no spec and no line. This file is the harness seam, so the
	-- contract is asserted here.
	describe("the report names the spec that failed", function()
		it("keeps the innermost spec frame, whatever the message contains", function()
			local message =
				'TestService: X.testez.TestRunner:86: Expected value "nil" (nil), got "no-range" (string) instead'
			local compact = TestKit.compactFailure(
				message
					.. "\nX.testez.Expectation:47 function equal"
					.. "\nServerStorage.Tests.licence_popup.spec:367"
					.. "\nServerStorage.Tests.weapon_shot.spec:1"
			)
			-- THE SEPARATOR `describe_failure` SPLITS ON, and the INNERMOST frame, not the last.
			expect(string.find(compact, " | ServerStorage.Tests.licence_popup.spec:367", 1, true)).to.be.ok()
			expect(string.find(compact, "weapon_shot.spec:1", 1, true)).to.equal(nil)
			-- THE MESSAGE IS NEVER READ AS A FRAME: TestEZ puts its own position in front of the
			-- text, and taking that as the frame printed the wrapper's line twice and never the
			-- stack's own.
			local ownPosition = TestKit.compactFailure(
				'ReplicatedStorage.ClientTests.semiauto_client.spec:84: Expected value "true", got "false"'
					.. "\nReplicatedStorage.ClientTests.semiauto_client.spec:262"
			)
			expect(string.find(ownPosition, " | ReplicatedStorage.ClientTests.semiauto_client.spec:262", 1, true)).to.be.ok()
			-- A FAILURE WITH NO FRAME AT ALL still carries its message, and gains no separator.
			local bare = TestKit.compactFailure("nothing recognisable here")
			expect(bare).to.equal("nothing recognisable here")
			-- AND THE 400-CHARACTER TRUNCATION THAT CAUSED 362b CANNOT COME BACK: a long message
			-- used to push the frame past the cut, so the frame is kept and the MESSAGE is what
			-- gets shortened.
			local long = TestKit.compactFailure(string.rep("x", 900) .. "\nServerStorage.Tests.deer_hitbox.spec:528")
			expect(string.find(long, " | ServerStorage.Tests.deer_hitbox.spec:528", 1, true)).to.be.ok()
			expect(#long < 400).to.equal(true)
		end)
	end)

	describe("Rojo sync", function()
		it("runs in the Driven Hunt DEV place", function()
			expect(game.PlaceId).to.equal(DEV_PLACE_ID)
		end)

		it("delivered the harness sync token from tests/sync-token.txt", function()
			local tokenValue = ReplicatedStorage:FindFirstChild("TestSyncToken")
			expect(tokenValue).to.be.ok()
			expect(tokenValue.ClassName).to.equal("StringValue")
			expect(string.match(tokenValue.Value, "^%x+:%d+$")).to.be.ok()
		end)

		it("names the token this run is using, and never blocks to answer", function()
			-- awaitToken is what both runners call (Task 34): with a valid token already present it
			-- returns immediately, which is every one-player run. That this spec is running at all
			-- is the proof it returned a token.
			--
			-- IT USED TO ASSERT `awaitToken(0) == token.Value` AND THAT WAS A LATENT FAULT IN THIS
			-- SPEC, surfaced by task 155 and reported rather than worked around (rule 6: a harness
			-- fault is a bug). `openToken` answers *"may a runner START now"*, which `TestKit`'s own
			-- header says is *"deliberately time-limited (TOKEN_MAX_AGE)"* and that *"a long suite
			-- outlives it"* -- 120 s, against a one-player run whose server tail already sat near
			-- that line. Task 155 added one client spec and one input scenario, the suite grew by a
			-- couple of seconds, and this case failed on a run in which NOTHING was wrong: 898
			-- server assertions passed and the token was present and correct.
			--
			-- SO THE TWO QUESTIONS ARE ASKED SEPARATELY, which is what `TestKit` was built for:
			-- `activeToken` is *"the token this run opened with, for as long as the run lasts"* and
			-- is the one a spec may ask late in a suite; `awaitToken(0)` is pinned on what it
			-- promises at any age -- that it RETURNS AT ONCE -- and on its value only while the gate
			-- is still open, since a stale gate answering nil is the correct answer and not a fault.
			-- AND THE BOUND IS THE ONE THE CODE ACTUALLY PROMISES. A first attempt asserted it
			-- returns in under 0.5 s and that was wrong about `awaitToken`, not about the run:
			-- it is a `repeat ... until`, so with `timeout = 0` and a CLOSED gate the body runs once
			-- and costs exactly one `task.wait(0.5)` before the condition is tested. What "without
			-- waiting for it" really means is that it does not sit out `TOKEN_WAIT` (60 s), and
			-- that is what is pinned.
			local tokenValue = ReplicatedStorage:FindFirstChild("TestSyncToken")
			expect(TestKit.activeToken()).to.equal(tokenValue.Value)
			local startedAt = os.clock()
			local answer = TestKit.awaitToken(0)
			expect(os.clock() - startedAt < 2).to.equal(true)
			expect(os.clock() - startedAt < TestKit.TOKEN_WAIT / 4).to.equal(true)
			if answer ~= nil then
				expect(answer).to.equal(tokenValue.Value)
				expect(TestKit.openToken()).to.equal(tokenValue.Value)
			else
				TestKit.note(
					string.format(
						"sync: the START gate had already closed by this point in the suite (TOKEN_MAX_AGE %d s); activeToken still names %s",
						TestKit.TOKEN_MAX_AGE,
						tokenValue.Value
					)
				)
			end
		end)

		it("delivered src/server/SyncCheck.server.luau and the server ran it", function()
			local syncCheck = ServerScriptService:FindFirstChild("SyncCheck")
			expect(syncCheck).to.be.ok()
			expect(syncCheck.ClassName).to.equal("Script")
			-- Script start order is not guaranteed, so give SyncCheck up to 5 s.
			local deadline = os.clock() + 5
			while not syncCheck:GetAttribute("Ran") and os.clock() < deadline do
				task.wait(0.1)
			end
			expect(syncCheck:GetAttribute("Ran")).to.equal(true)
		end)
	end)
end
