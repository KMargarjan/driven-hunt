-- TestRunner: runs every *.spec module in ServerStorage.Tests with TestEZ, only when the harness asks.
-- Pattern: TestEZ TestBootstrap + TextReporter (https://roblox.github.io/testez/, Apache-2.0, archived upstream),
-- gated by a harness-written sync token. Note: docs/research/2026-09-24-toolchain.md
--
-- Gate: runs only in Studio AND when ServerStorage.TestSyncToken (synced by Rojo from
-- tests/sync-token.txt, written by tools/studio_mcp.py) holds a token younger than TOKEN_MAX_AGE.
-- Karen's normal playtests have no fresh token, so no tests run.
--
-- Output: one line "[tests] PASS|FAIL|ERROR: ..." and a JSON report in the ServerStorage attribute
-- "TestReport", which the harness reads from the Server DataModel.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local TOKEN_MAX_AGE = 120 -- seconds; stale tokens (for example after a harness crash) never open the gate

if not RunService:IsStudio() then
	return
end

local tokenValue = ServerStorage:FindFirstChild("TestSyncToken")
local token = if tokenValue and tokenValue:IsA("StringValue") then tokenValue.Value else ""
local issuedAt = tonumber(string.match(token, ":(%d+)$"))
if not issuedAt or os.time() - issuedAt > TOKEN_MAX_AGE then
	return
end

local report = {
	token = token,
	placeId = game.PlaceId,
	specCount = 0,
	successCount = 0,
	failureCount = 0,
	skippedCount = 0,
	errorCount = 0,
	status = "ERROR",
	message = "",
}

local function finish()
	local line = if report.status == "ERROR"
		then string.format("[tests] ERROR: %s", report.message)
		else string.format(
			"[tests] %s: %d passed, %d failed, %d skipped, %d errors, %d spec files",
			report.status,
			report.successCount,
			report.failureCount,
			report.skippedCount,
			report.errorCount,
			report.specCount
		)
	if report.status == "PASS" then
		print(line)
	else
		warn(line)
	end
	ServerStorage:SetAttribute("TestReport", HttpService:JSONEncode(report))
end

local testsFolder = ServerStorage:FindFirstChild("Tests")
local devPackages = ServerStorage:FindFirstChild("DevPackages")
if not testsFolder or not devPackages or not devPackages:FindFirstChild("TestEZ") then
	report.message = "ServerStorage.Tests or DevPackages.TestEZ missing (run `wally install`, check Rojo)"
	finish()
	return
end

-- Load every spec under pcall first. TestEZ's TestBootstrap requires specs unprotected, so a spec with
-- a syntax or runtime error would otherwise kill this script with no summary. require caches, so
-- TestEZ gets the same function afterwards.
for _, module in testsFolder:GetDescendants() do
	if module:IsA("ModuleScript") and string.match(module.Name, "%.spec$") then
		report.specCount += 1
		local ok, err = pcall(require, module)
		if not ok then
			report.message = string.format("failed to load %s: %s", module:GetFullName(), tostring(err))
			finish()
			return
		end
	end
end

local ok, resultsOrErr = pcall(function()
	local TestEZ = require(devPackages.TestEZ)
	return TestEZ.TestBootstrap:run({ testsFolder }, TestEZ.Reporters.TextReporter)
end)
if not ok then
	report.message = "TestEZ run threw: " .. tostring(resultsOrErr)
	finish()
	return
end

local results = resultsOrErr
report.successCount = results.successCount
report.failureCount = results.failureCount
report.skippedCount = results.skippedCount
report.errorCount = #results.errors
-- Zero passing tests is a failure: it means nothing ran, not that everything is fine.
report.status = if results.failureCount == 0
		and report.errorCount == 0
		and results.successCount > 0
	then "PASS"
	else "FAIL"
finish()
