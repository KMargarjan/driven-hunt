-- ClientTestRunner: runs the client specs (ReplicatedStorage.ClientTests) through TestKit, in the player's
-- client, when the harness opens the gate. Client specs cover camera, input, cursor and UI state.
-- Pattern: thin runner over TestKit (tests/TestKit.luau). Full description: tools/studio_mcp.py docstring.
-- Note: docs/research/2026-09-24-toolchain.md
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local token = TestKit.openToken()
if not token then
	return
end

local report = TestKit.run("client", token, ReplicatedStorage:WaitForChild("ClientTests", 10))
-- Read by tools/studio_mcp.py from the Client DataModel. LocalPlayer attributes set on the client do
-- not replicate, which is fine: only the harness reads this.
Players.LocalPlayer:SetAttribute("TestReport", HttpService:JSONEncode(report))
