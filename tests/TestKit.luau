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

-- Runs every *.spec ModuleScript under specsFolder and returns the report table.
-- side is "server" or "client"; it is echoed in the report and the [tests:<side>] line.
function TestKit.run(side: string, token: string, specsFolder: Instance?)
	local report = {
		side = side,
		token = token,
		placeId = game.PlaceId,
		specs = {}, -- full names of every spec module found; the harness matches these to *.spec.* files
		successCount = 0,
		failureCount = 0,
		skippedCount = 0,
		errorCount = 0,
		status = "ERROR",
		message = "",
	}

	local function finish()
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
