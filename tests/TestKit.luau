-- TestKit: the one implementation of the test gate, spec loading, TestEZ run and report, shared by
-- ServerScriptService.TestRunner (server specs) and StarterPlayerScripts.ClientTestRunner (client specs).
-- Pattern: TestEZ TestBootstrap + TextReporter (https://roblox.github.io/testez/, Apache-2.0, archived upstream),
-- gated by a harness-written sync token. Full description of the test system: tools/studio_mcp.py docstring.
-- Note: docs/research/2026-09-24-toolchain.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TestKit = {}

-- Seconds a harness token stays valid. Stale tokens (for example after a harness crash) never open the gate.
TestKit.TOKEN_MAX_AGE = 120

-- Seconds a runner waits for the harness to open the gate before giving up (Task 34).
-- A one-player `test` writes the token BEFORE Play, so the wait is over on the first check. A local
-- Clients-and-Servers test cannot work that way: measured on 2026-09-25, the place those processes
-- start from carries every Rojo-synced SCRIPT but NOT the token StringValue's value (it was empty in
-- all three processes while the editor held a fresh token), and Rojo does not patch them afterwards.
-- So the harness writes the token INTO the running server process instead, and the runners have to
-- still be listening when it lands.
TestKit.TOKEN_WAIT = 60

-- Returns the fresh harness token, or nil if tests must not run (not Studio, no token, or stale token).
function TestKit.openToken(): string?
	if not RunService:IsStudio() then
		return nil
	end
	local tokenValue = ReplicatedStorage:FindFirstChild("TestSyncToken")
	local token = if tokenValue and tokenValue:IsA("StringValue") then tokenValue.Value else ""
	local issuedAt = tonumber(string.match(token, ":(%d+)$"))
	if not issuedAt or os.time() - issuedAt > TestKit.TOKEN_MAX_AGE then
		return nil
	end
	return token
end

-- Waits up to `timeout` seconds (default TOKEN_WAIT) for a token that opens the gate, and returns it
-- or nil. The GATE ITSELF IS UNCHANGED and just as strict: Studio only, and a token under
-- TOKEN_MAX_AGE seconds old. This only changes WHEN it is read -- once at startup could never see a
-- token that a two-player run can only deliver after the processes exist. Outside Studio it returns
-- nil at once, so a published place never waits.
function TestKit.awaitToken(timeout: number?): string?
	if not RunService:IsStudio() then
		return nil
	end
	local deadline = os.clock() + (timeout or TestKit.TOKEN_WAIT)
	repeat
		local token = TestKit.openToken()
		if token then
			return token
		end
		task.wait(0.5)
	until os.clock() >= deadline
	return TestKit.openToken()
end

-- THE TOKEN THIS RUN OPENED WITH, for as long as the run lasts. `openToken` answers "may a runner
-- START now", which is deliberately time-limited (TOKEN_MAX_AGE), and a long suite outlives it -- so
-- a seam that a spec uses at the END of a run cannot ask that question and get a useful answer
-- (Task 41: Match.advanceForTests was refused 200 s into a run for exactly that). This answers the
-- other question, "is a gated test run in progress", and only TestKit.run sets it.
local activeToken: string? = nil

function TestKit.activeToken(): string?
	return activeToken
end

-- WHICH STAGE OF A RUN IS LIVE, for the harness when no report ever arrives (task 328t). Every stop
-- between `run` being entered and the report being written used to be silent. The RUNNER publishes
-- it, because nothing in here owns ServerStorage; TestKit only says where it got to.
TestKit.onStage = nil :: ((string) -> ())?

function TestKit.stage(name: string)
	local hook = TestKit.onStage
	if hook then
		pcall(hook, name)
	end
end

-- Notes a spec wants the HARNESS to see, whatever happens to the console.
--
-- Studio's console comes back truncated from a long session -- every two-player run so far lost the
-- head of it, which is where a print from the middle of a suite lives (Task 34). A note goes into
-- the report instead, which is JSON on an attribute the harness reads whole, so the numbers that
-- explain a failure arrive with the failure.
local notes: { string } = {}
-- ...and of those, the ones that say a claim could not be exercised (task 367, TASKS.md 285).
local notProven: { string } = {}

function TestKit.note(text: string)
	table.insert(notes, text)
	-- A CLAIM THIS RUN COULD NOT EXERCISE, counted here so the gate's own page carries the number
	-- (task 367, TASKS.md 285). `TestKit.NOT_PROVEN` is declared below, and the comment there says
	-- why the marker is read out of the text rather than passed in.
	if string.find(text, TestKit.NOT_PROVEN, 1, true) ~= nil then
		table.insert(notProven, text)
	end
	print("[note] " .. text)
	-- A note is also the furthest point a run is KNOWN to have reached, and it is the only signal
	-- TestEZ's own run emits from inside (task 328t): its reporter speaks once, at the end.
	TestKit.stage("note:" .. string.sub(text, 1, 80))
end

-- RUN `fn`, AND KEEP THE LINE THAT ACTUALLY BROKE (task 367).
--
-- Thirty-two cases -- 21 client, 11 server -- are wrapped in `local ok, why = pcall(body)` ...
-- `error(why, 0)`, so that the live viewmodel, camera, cursor or asset seam is always put back. `error(why, 0)` rethrows the MESSAGE, and
-- TestEZ then reports the rethrow site -- which is why `semiauto_client.spec:93` is the line in
-- TASKS.md 281a(k) and `gun_client.spec:393` in this task's own run 4: both are the `error(why, 0)`
-- in the wrapper, the same line for every case in the file, and neither says which claim failed.
-- `debug.traceback` captures the stack WHERE the error happened, so the rethrown text still carries
-- the real `*.spec:<line>` frame and `TestKit.compactFailure` finds it.
--   debug.traceback  https://create.roblox.com/docs/reference/engine/libraries/debug#traceback
function TestKit.tracedCall(fn: () -> ()): (boolean, string?)
	local ok, why = xpcall(fn, function(err)
		return tostring(err) .. "\n" .. debug.traceback(nil, 2)
	end)
	return ok, if ok then nil else tostring(why)
end

-- A CASE THAT COULD NOT RUN SAYS SO WHERE THE GATE CAN COUNT IT (task 367, TASKS.md 285).
--
-- Several live cases need something only a Play session can provide -- a player holding a loaded
-- gun, an animal in range -- and when it is not there they print a line and assert the arithmetic
-- instead. That is honest, and it still counted toward "34/34" with nothing on the gate's own page
-- to say a claim had gone unproven: `weapon_shot.spec`'s self-block case ran in 2 of 5 runs on
-- task 281's head and the report said PASS either way (TASKS.md 285). A `notProven` note is an
-- ordinary note -- so nothing about pass or fail changes -- plus a COUNT the harness prints on its
-- own line, so the Builder reads how much of the run was actually exercised.
-- THE WORDS THE SPECS ALREADY USE. Ten lines in two files end their fallback with "NOT PROVEN in
-- this run" -- nine in `tests/server/weapon_shot.spec.luau` and one in `range.spec.luau` -- so the
-- marker is read out of the note rather than requiring every one of them to be rewritten, and
-- `TestKit.notProven` (two callers so far, both in `weapon_shot.spec`) is the explicit way to say it
-- for a new case. A note about a case that RAN and BROKE must not carry the marker: the count means
-- "could not be exercised", not "failed" (round 2 note).
TestKit.NOT_PROVEN = "NOT PROVEN"

function TestKit.notProven(text: string)
	TestKit.note(TestKit.NOT_PROVEN .. ": " .. text)
end

-- HOW MANY FAILURES THE REPORT NAMES. Was 5 (task 34); twelve, because a run with six or more
-- failures is exactly the run whose console is longest and least likely to survive, and each
-- compacted entry below is ~200 characters rather than 400.
TestKit.FAILURES_REPORTED = 12

-- ONE FAILURE, AS "<message> | <spec>:<line>" (task 367).
--
-- A TestEZ failure is a message plus a stack whose spec frame sits under three or four
-- `testez.Expectation` / `testez.TestRunner` lines of ~80 characters each, so truncating the raw
-- text cut the only part that says WHICH spec broke (TASKS.md 362b). The frames are dropped here,
-- where the whole text exists, and the message is what gets shortened.
function TestKit.compactFailure(failure: any): string
	local text = tostring(failure)
	local message, where = nil, nil
	for line in string.gmatch(text, "[^\r\n]+") do
		local trimmed = string.match(line, "^%s*(.-)%s*$") or line
		if trimmed ~= "" then
			if message == nil then
				-- THE MESSAGE IS THE FIRST LINE AND IT IS NEVER READ AS A FRAME. TestEZ puts its
				-- own position in front of the text, so a message can itself contain `.spec:<line>`
				-- -- and taking that as the frame printed the WRAPPER's line twice and never the
				-- stack's own (measured: `semiauto_client.spec:84 ... | ...spec:84`, task 367).
				message = trimmed
			elseif where == nil and string.find(trimmed, ".spec:", 1, true) ~= nil then
				-- The INNERMOST frame inside a spec file: `debug.traceback` lists them from where
				-- the error was raised outwards, so the first one is the claim that broke rather
				-- than the `error(why, 0)` that rethrew it.
				where = trimmed
			end
		end
	end
	message = string.sub(message or text, 1, 300)
	if where == nil then
		return message
	end
	return message .. " | " .. where
end

-- Seconds of non-yielding execution after which the suite yields one frame.
--
-- THE ENGINE KILLS A THREAD THAT NEVER YIELDS -- "Script timeout: exhausted allowed execution
-- time" -- and that is what had been failing the gate (MEASURED, task 328t): ~2,800 synchronous
-- tests, a stretch of pure-maths specs with no wait in them, and the runner's thread is terminated
-- MID-TEST. It is not catchable, so there is no report at any window: 300, 900 and 2400 s all
-- failed identically. A yield at a test boundary resets the engine's budget.
TestKit.YIELD_AFTER = 2

-- WHAT HAPPENS AT EVERY TEST BOUNDARY: the yield above, and the stage that names the test.
-- TestEZ's reporter speaks once, at the end, so a run that never finishes named nothing at all; its
-- node walk recurses through a plain table field, so it is wrapped once (0.4.1 is archived upstream
-- and cannot drift under us). An `it` never reaches `runPlanNode` -- only a describe does -- but
-- every node is pushed on the session, which is where the test's own name is.
function TestKit.atEveryNode(TestEZ)
	if TestEZ.TestRunner.dhNodeSeam then
		return
	end
	TestEZ.TestRunner.dhNodeSeam = true
	local inner = TestEZ.TestRunner.runPlanNode
	local lastYield = os.clock()
	TestEZ.TestRunner.runPlanNode = function(session, planNode, hooks)
		if not session.dhNodeSeam then
			session.dhNodeSeam = true
			local push = session.pushNode
			session.pushNode = function(self, node)
				TestKit.stage("node:" .. tostring(node.phrase))
				if os.clock() - lastYield > TestKit.YIELD_AFTER then
					task.wait()
					lastYield = os.clock()
				end
				return push(self, node)
			end
		end
		return inner(session, planNode, hooks)
	end
end

-- Runs every *.spec ModuleScript under specsFolder and returns the report table.
-- side is "server" or "client"; it is echoed in the report and the [tests:<side>] line.
function TestKit.run(side: string, token: string, specsFolder: Instance?)
	activeToken = token
	TestKit.stage("run-entered")
	local report = {
		side = side,
		token = token,
		placeId = game.PlaceId,
		specs = {}, -- full names of every spec module found; the harness matches these to *.spec.* files
		notes = notes, -- whatever the specs asked the harness to see (TestKit.note)
		-- The claims this run could not exercise (TestKit.notProven); the harness prints the count.
		notProven = notProven,
		failures = {}, -- the first few failure messages, so a truncated console cannot hide them
		successCount = 0,
		failureCount = 0,
		skippedCount = 0,
		errorCount = 0,
		status = "ERROR",
		message = "",
	}

	local function finish()
		-- THE SEAM CLOSES WITH THE RUN (audit-004 F5). `activeToken` is what `Match.advanceForTests`
		-- asks "is a gated test run in progress"; leaving it set after the last spec left the drive's
		-- clock seam open for the rest of the session, in a Studio session a human is about to play in.
		-- Every exit from `run` goes through here, including the early returns above.
		activeToken = nil
		TestKit.stage("finish:" .. report.status)
		local line = if report.status == "ERROR"
			then string.format("[tests:%s] ERROR: %s", side, report.message)
			else string.format(
				"[tests:%s] %s: %d passed, %d failed, %d skipped, %d errors, %d spec files",
				side,
				report.status,
				report.successCount,
				report.failureCount,
				report.skippedCount,
				report.errorCount,
				#report.specs
			)
		if report.status == "PASS" then
			print(line)
		else
			warn(line)
		end
		return report
	end

	local devPackages = ReplicatedStorage:FindFirstChild("DevPackages")
	if not specsFolder or not devPackages or not devPackages:FindFirstChild("TestEZ") then
		report.message =
			"specs folder or ReplicatedStorage.DevPackages.TestEZ missing (run `wally install`, check Rojo)"
		return finish()
	end

	-- Load every spec under pcall first. TestEZ's TestBootstrap requires specs unprotected, so a spec with
	-- a syntax or runtime error would otherwise kill the runner with no summary. require caches, so
	-- TestEZ gets the same function afterwards.
	--
	-- ...AND EACH ONE IS TIMED (task 221 round 4). A spec's top-level code runs HERE, inside this
	-- `require` -- so an unbounded `WaitForChild` for something that has not replicated to this
	-- client blocks the WHOLE suite before TestEZ has started, and the only symptom upstream is a
	-- runner that reports at its deadline with no clue which file ate the time. That is exactly what
	-- a two-player run showed at 606f83c: the driver reported after 6 s and the shooter after 299 s,
	-- against a 300 s bound, with the input replay unchanged. Three numbers in a note cost nothing
	-- and name the file next time.
	local slowest: { { name: string, ms: number } } = {}
	for _, module in specsFolder:GetDescendants() do
		if module:IsA("ModuleScript") and string.match(module.Name, "%.spec$") then
			table.insert(report.specs, module:GetFullName())
			TestKit.stage("spec-load:" .. module.Name)
			local startedAt = os.clock()
			local ok, err = pcall(require, module)
			table.insert(slowest, { name = module.Name, ms = (os.clock() - startedAt) * 1000 })
			if not ok then
				report.message = string.format("failed to load %s: %s", module:GetFullName(), tostring(err))
				return finish()
			end
		end
	end
	table.sort(slowest, function(a, b)
		return a.ms > b.ms
	end)
	local worst = {}
	for index = 1, math.min(3, #slowest) do
		table.insert(worst, string.format("%s %.0f ms", slowest[index].name, slowest[index].ms))
	end
	if #worst > 0 then
		TestKit.note("spec load, slowest three: " .. table.concat(worst, ", "))
	end

	TestKit.stage("testez-starting")
	local ok, resultsOrErr = pcall(function()
		local TestEZ = require(devPackages.TestEZ)
		TestKit.atEveryNode(TestEZ)
		return TestEZ.TestBootstrap:run({ specsFolder }, TestEZ.Reporters.TextReporter)
	end)
	if not ok then
		report.message = "TestEZ run threw: " .. tostring(resultsOrErr)
		return finish()
	end

	TestKit.stage("testez-returned")
	local results = resultsOrErr
	-- THE FAILURES THEMSELVES, in the report. Studio's console comes back truncated from a long
	-- session and takes the failure list with it: a two-player run said "13 failed" and nothing
	-- about which 13 (Task 34). The console still has the rest when it survives.
	--
	-- THE SPEC FRAME IS KEPT, NOT THE FIRST 400 CHARACTERS (task 367). A `expect(...)` failure is a
	-- message plus a TestEZ stack, and the frame that names the spec sits BELOW three or four
	-- `testez.Expectation`/`testez.TestRunner` lines of ~80 characters each -- so a blind
	-- `string.sub(..., 400)` cut the name off whenever the message was long, and `describe_failure`
	-- in tools/studio_mcp.py then printed a failure with no spec and no line (TASKS.md 362b, where
	-- a failing client spec's name was lost). `failureFrames` throws the TestEZ frames away and
	-- keeps the first frame inside a spec, so the name cannot be cut off by a long message.
	for index, failure in ipairs(results.errors) do
		if index > TestKit.FAILURES_REPORTED then
			break
		end
		table.insert(report.failures, TestKit.compactFailure(failure))
	end
	report.successCount = results.successCount
	report.failureCount = results.failureCount
	report.skippedCount = results.skippedCount
	report.errorCount = #results.errors
	-- Zero passing tests is a failure: it means nothing ran, not that everything is fine.
	-- Any skipped test is a failure too: SKIP/itSKIP/describeSKIP skip tests directly, and
	-- FOCUS/itFOCUS/describeFOCUS skip every unfocused test. Neither may reach main.
	TestKit.stage("report-built")
	report.status = if results.failureCount == 0
			and report.errorCount == 0
			and results.skippedCount == 0
			and results.successCount > 0
		then "PASS"
		else "FAIL"
	return finish()
end

return TestKit
