-- boar_hit.spec: the damage seam (shotgun design section 6) from the boar's side -- the attributes
-- the weapon reads, Runtime:takeHit, the Hit signal, and the assertion that a hit changes NOTHING
-- else in this milestone. Hit zones, wounds and the boar's reaction to being shot are ROADMAP 1.5:
-- if one of them lands early, the last test here goes red on purpose.
--
-- It builds its own small world at y = 500, the pattern tests/server/boar_body.spec.luau uses, so
-- production's boar (spawned by BoarBoot) is untouched.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (sections 6.4, 6.5, 13.1)
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))

local GROUND_Y = 500
local FIELD = {
	bounds = { minX = -55, maxX = 55, minZ = -55, maxZ = 55 },
	exitZ = -40,
	groundY = GROUND_Y,
}

local function waitUntil(timeout: number, predicate: () -> boolean): boolean
	local started = os.clock()
	while os.clock() - started < timeout do
		if predicate() then
			return true
		end
		task.wait()
	end
	return predicate()
end

return function()
	describe("the boar's damage seam", function()
		local testRoot, runtime, handle, hits

		beforeEach(function()
			testRoot = Instance.new("Folder")
			testRoot.Name = "BoarHitSpec"
			local plate = Instance.new("Part")
			plate.Name = "Plate"
			plate.Size = Vector3.new(120, 4, 120)
			plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
			plate.Anchored = true
			plate.Parent = testRoot
			testRoot.Parent = Workspace

			runtime = Boar.newRuntime({
				field = FIELD,
				parent = testRoot,
				folderName = "Boars",
				rng = Random.new(5),
				threats = function()
					return {}
				end,
				probe = function()
					return false
				end,
				requestPath = function(_id, _from, _to, done)
					done(nil)
				end,
				releasePath = function() end,
			})
			handle = runtime:spawn(Vector3.new(0, GROUND_Y, 20))
			hits = {}
			runtime.Hit:Connect(function(record)
				table.insert(hits, record)
			end)
		end)

		afterEach(function()
			runtime:destroy()
			testRoot:Destroy()
		end)

		it("publishes the two attributes the weapon reads", function()
			expect(handle.part:GetAttribute("Damageable")).to.equal(true)
			expect(handle.part:GetAttribute("HitZone")).to.equal("body")
		end)

		it("takes a hit, counts the pellets and says so exactly once", function()
			local taken = runtime:takeHit(handle.part, { zone = "body", ammo = "Buck", pellets = 9, at = 1 })
			expect(taken).to.equal(true)
			expect(runtime:stats().hits).to.equal(1)
			expect(runtime:stats().pelletsTaken).to.equal(9)

			-- Signals may be deferred, so this polls rather than assuming it has fired.
			expect(waitUntil(2, function()
				return #hits == 1
			end)).to.equal(true)
			expect(hits[1].zone).to.equal("body")
			expect(hits[1].ammo).to.equal("Buck")
			expect(hits[1].pellets).to.equal(9)
			expect(hits[1].id).to.be.ok()
		end)

		it("refuses a part that is not one of its boars, and moves no counter", function()
			local stranger = Instance.new("Part")
			stranger.Parent = testRoot
			expect(runtime:takeHit(stranger, { zone = "body", ammo = "Slug", pellets = 1, at = 0 })).to.equal(false)
			expect(runtime:stats().hits).to.equal(0)
			expect(runtime:stats().pelletsTaken).to.equal(0)
			stranger:Destroy()
		end)

		it("does not move the boar: the reaction is ROADMAP 1.5, not this task", function()
			local before = handle.part.Position
			local speedBefore = handle.part.AssemblyLinearVelocity.Magnitude
			runtime:takeHit(handle.part, { zone = "body", ammo = "Slug", pellets = 1, at = 0 })
			expect(#runtime:boars()).to.equal(1)
			expect(handle.part.Parent).to.be.ok()
			expect((handle.part.Position - before).Magnitude < 2).to.equal(true)
			expect(math.abs(handle.part.AssemblyLinearVelocity.Magnitude - speedBefore) < 5).to.equal(true)
			expect(runtime:stats().despawned).to.equal(0)
		end)
	end)

	describe("the boar's teardown", function()
		-- Round 1, finding 1: the first version of this counted BindableEvent descendants of the
		-- spec's own folder. The runtime's signals are never parented, so that count was 0 before
		-- destroy(), after destroy(), and with the destroy call deleted -- a test that could not
		-- fail, guarding the one line it existed for. A connection is the observable: Destroy()
		-- disconnects every listener, so this goes red the moment _hitSignal:Destroy() is removed.
		it("destroys both signals, so every listener is disconnected", function()
			local testRoot = Instance.new("Folder")
			testRoot.Name = "BoarHitTeardownSpec"
			testRoot.Parent = Workspace
			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = testRoot,
				folderName = "Boars",
				rng = Random.new(6),
				threats = function()
					return {}
				end,
				probe = function()
					return false
				end,
				requestPath = function(_id, _from, _to, done)
					done(nil)
				end,
				releasePath = function() end,
			})
			local onHit = runtime.Hit:Connect(function() end)
			local onDespawn = runtime.Despawned:Connect(function() end)
			expect(onHit.Connected).to.equal(true)
			expect(onDespawn.Connected).to.equal(true)

			runtime:destroy()

			expect(onHit.Connected).to.equal(false)
			expect(onDespawn.Connected).to.equal(false)
			testRoot:Destroy()
		end)
	end)
end
