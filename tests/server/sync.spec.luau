-- sync.spec: asserts that the Rojo sync delivered disk content into the running server.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-09-24-toolchain.md
-- The harness (tools/studio_mcp.py) also compares every synced script's Source with disk before Play.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local DEV_PLACE_ID = 136410205938347 -- default.project.json servePlaceIds

return function()
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

		it("opens the gate for the token this run is using, without waiting for it", function()
			-- awaitToken is what both runners call (Task 34): with a valid token already present it
			-- returns immediately, which is every one-player run. That this spec is running at all
			-- is the proof it returned a token; this pins the value it returns.
			local tokenValue = ReplicatedStorage:FindFirstChild("TestSyncToken")
			expect(TestKit.awaitToken(0)).to.equal(tokenValue.Value)
			expect(TestKit.openToken()).to.equal(tokenValue.Value)
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
