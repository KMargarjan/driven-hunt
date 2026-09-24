-- TestRunner: runs every *.spec module in ServerStorage.Tests with TestEZ, Studio playtests only.
-- Pattern: TestEZ TestBootstrap + TextReporter (https://roblox.github.io/testez/, Apache-2.0, archived upstream).
-- Note: docs/research/2026-09-24-toolchain.md
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end

local TestEZ = require(ServerStorage.DevPackages.TestEZ)

local results = TestEZ.TestBootstrap:run({ ServerStorage.Tests }, TestEZ.Reporters.TextReporter)

local summary = string.format(
	"[tests] %s: %d passed, %d failed, %d skipped",
	if results.failureCount == 0 then "PASS" else "FAIL",
	results.successCount,
	results.failureCount,
	results.skippedCount
)

-- One greppable summary line for humans...
print(summary)
-- ...and for tools/studio_mcp.py, which polls this in the Server DataModel. Studio clears Output on
-- each Play, so the log alone cannot tell this run's result from the previous run's.
ServerStorage:SetAttribute("TestSummary", summary)
