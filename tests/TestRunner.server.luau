-- TestRunner: runs the server specs (ServerStorage.Tests) through TestKit when the harness opens the gate.
-- Pattern: thin runner over TestKit (tests/TestKit.luau). Full description: tools/studio_mcp.py docstring.
-- Note: docs/research/2026-09-24-toolchain.md
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- awaitToken, not openToken: a two-player run cannot put the token in the place these processes
-- start from, so it arrives after they are up (tools/studio_mcp.py docstring, `test2`). The gate is
-- the same one -- Studio, and a token under 120 s old -- so a playtest still runs no tests.
local token = TestKit.awaitToken()
if not token then
	return
end

local report = TestKit.run("server", token, ServerStorage:FindFirstChild("Tests"))
-- THE DRIVE-CLOCK SEAM, observed from OUTSIDE TestKit after the run returned (audit-004 F5). Asked
-- here rather than inside `TestKit.finish`, where the answer would sit one line below the assignment
-- that makes it true and could only ever be `true` in a committed state. `activeToken` is what
-- `Match.advanceForTests` asks "is a gated test run in progress"; left set, the seam stays open for
-- the rest of a Studio session a human is about to play in.
--
-- It travels in the report because nothing outside the module can see the upvalue: MEASURED, a query
-- that requires ReplicatedStorage.TestKit through `execute_luau` gets a DIFFERENT instance, out of its
-- own require cache, and answers about a token nothing ever set.
report.seamClosed = TestKit.activeToken() == nil
-- Read by tools/studio_mcp.py from the Server DataModel.
ServerStorage:SetAttribute("TestReport", HttpService:JSONEncode(report))
