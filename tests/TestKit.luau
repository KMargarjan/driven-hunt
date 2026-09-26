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

-- Notes a spec wants the HARNESS to see, whatever happens to the console.
--
-- Studio's console comes back truncated from a long session -- every two-player run so far lost the
-- head of it, which is where a print from the middle of a suite lives (Task 34). A note goes into
-- the report instead, which is JSON on an attribute the harness reads whole, so the numbers that
-- explain a failure arrive with the failure.
local notes: { string } = {}

function TestKit.note(text: string)
	table.insert(notes, text)
	print("[note] " .. text)
end

-- Runs every *.spec ModuleScript under specsFolder and returns the report table.
-- side is "server" or "client"; it is echoed in the report and the [tests:<side>] line.
function TestKit.run(side: string, token: string, specsFolder: Instance?)
	activeToken = token
	local report = {
		side = side,
		token = token,
		placeId = game.PlaceId,
		specs = {}, -- full names of every spec module found; the harness matches these to *.spec.* files
		notes = notes, -- whatever the specs asked the harness to see (TestKit.note)
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
	for _, module in specsFolder:GetDescendants() do
		if module:IsA("ModuleScript") and string.match(module.Name, "%.spec$") then
			table.insert(report.specs, module:GetFullName())
			local ok, err = pcall(require, module)
			if not ok then
				report.message = string.format("failed to load %s: %s", module:GetFullName(), tostring(err))
				return finish()
			end
		end
	end

	local ok, resultsOrErr = pcall(function()
		local TestEZ = require(devPackages.TestEZ)
		return TestEZ.TestBootstrap:run({ specsFolder }, TestEZ.Reporters.TextReporter)
	end)
	if not ok then
		report.message = "TestEZ run threw: " .. tostring(resultsOrErr)
		return finish()
	end

	local results = resultsOrErr
	-- THE FAILURES THEMSELVES, in the report. Studio's console comes back truncated from a long
	-- session and takes the failure list with it: a two-player run said "13 failed" and nothing
	-- about which 13 (Task 34). Five is enough to name the spec and the line; the console still has
	-- the rest when it survives.
	for index, failure in ipairs(results.errors) do
		if index > 5 then
			break
		end
		table.insert(report.failures, string.sub(tostring(failure), 1, 400))
	end
	report.successCount = results.successCount
	report.failureCount = results.failureCount
	report.skippedCount = results.skippedCount
	report.errorCount = #results.errors
	-- Zero passing tests is a failure: it means nothing ran, not that everything is fine.
	-- Any skipped test is a failure too: SKIP/itSKIP/describeSKIP skip tests directly, and
	-- FOCUS/itFOCUS/describeFOCUS skip every unfocused test. Neither may reach main.
	report.status = if results.failureCount == 0
			and report.errorCount == 0
			and results.skippedCount == 0
			and results.successCount > 0
		then "PASS"
		else "FAIL"
	return finish()
end

return TestKit
