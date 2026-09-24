-- client_env.spec: proves client specs run in the player's client, with the objects client systems
-- (camera, input, cursor, UI) will be tested against. Archive with sync.spec once real client specs exist.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-09-24-toolchain.md
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

return function()
	describe("client test path", function()
		it("runs on the client, not the server", function()
			expect(RunService:IsClient()).to.equal(true)
			expect(RunService:IsServer()).to.equal(false)
		end)

		it("has a LocalPlayer with a PlayerGui (UI root)", function()
			expect(Players.LocalPlayer).to.be.ok()
			expect(Players.LocalPlayer:WaitForChild("PlayerGui", 10)).to.be.ok()
		end)

		it("has a current Camera (camera root)", function()
			expect(workspace.CurrentCamera).to.be.ok()
			expect(workspace.CurrentCamera.ClassName).to.equal("Camera")
		end)

		it("can read input and cursor state (input/cursor root)", function()
			expect(typeof(UserInputService.MouseIconEnabled)).to.equal("boolean")
			expect(typeof(UserInputService:GetMouseLocation())).to.equal("Vector2")
		end)
	end)
end
