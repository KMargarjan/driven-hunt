-- sync.spec: asserts that the Rojo sync delivered disk content into the running server.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-09-24-toolchain.md
-- The harness (tools/studio_mcp.py) also compares every synced script's Source with disk before Play.
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local DEV_PLACE_ID = 136410205938347 -- default.project.json servePlaceIds

return function()
	describe("Rojo sync", function()
		it("runs in the Driven Hunt DEV place", function()
			expect(game.PlaceId).to.equal(DEV_PLACE_ID)
		end)

		it("delivered the harness sync token from tests/sync-token.txt", function()
			local tokenValue = ServerStorage:FindFirstChild("TestSyncToken")
			expect(tokenValue).to.be.ok()
			expect(tokenValue.ClassName).to.equal("StringValue")
			expect(string.match(tokenValue.Value, "^%x+:%d+$")).to.be.ok()
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
