-- Example TestEZ spec: the file shape every spec follows (ModuleScript named *.spec returning a function).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
return function()
	describe("example", function()
		it("adds numbers", function()
			expect(1 + 1).to.equal(2)
		end)

		it("sees the synced ReplicatedStorage service", function()
			expect(game:GetService("ReplicatedStorage")).to.be.ok()
		end)
	end)
end
