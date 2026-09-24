-- TestRunner: runs the server specs (ServerStorage.Tests) through TestKit when the harness opens the gate.
-- Pattern: thin runner over TestKit (tests/TestKit.luau). Full description: tools/studio_mcp.py docstring.
-- Note: docs/research/2026-09-24-toolchain.md
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local token = TestKit.openToken()
if not token then
	return
end

local report = TestKit.run("server", token, ServerStorage:FindFirstChild("Tests"))
-- Read by tools/studio_mcp.py from the Server DataModel.
ServerStorage:SetAttribute("TestReport", HttpService:JSONEncode(report))
