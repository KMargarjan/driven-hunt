-- boar_hit.spec: the damage seam and what a hit now MEANS -- the attributes the weapon reads,
-- Runtime:takeHit, the Hit signal, the reaction, the kill, the carcass and the escaped wounded boar.
-- The model itself is proved with no world in tests/server/boar_wound.spec.luau and the geometry with
-- real rays in tests/server/boar_zones.spec.luau; this file is the live seam.
--
-- Task 24's assertions are kept unchanged, which is the back-compatibility claim of hit-zones design
-- section 2.2: the four original Hit fields keep their names and meanings. The one Task 24 test that
-- is GONE is "a hit does not move the boar", which said in its own comment that Milestone 1.5 would
-- turn it red on purpose. This is that milestone.
--
-- It builds its own small world at y = 500, the pattern tests/server/boar_body.spec.luau uses, so
-- production's boar (spawned by BoarBoot) is untouched.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (sections 6.4, 6.5, 13.1), docs/design/hit-zones.md (section 12.4)
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Wound = Boar.Wound

local GROUND_Y = 500
-- Bigger than Task 24's field, because a hit boar now RUNS: with the old 60 studs between the
-- spawn and the exit line, every test here would have been racing it off the edge. 200 studs is
-- about 6 seconds at a sprint, longer than any single test below.
local FIELD = {
	bounds = { minX = -150, maxX = 150, minZ = -150, maxZ = 150 },
	exitZ = -140,
	groundY = GROUND_Y,
}
local SPAWN = Vector3.new(0, GROUND_Y, 60)

local CARCASS_SECONDS = 2 -- so a carcass lifetime costs the suite two seconds, not two minutes

-- newRuntime does a SHALLOW merge of world.config, so a spec that overrides WOUND replaces the whole
-- sub-table. This clone is shallow too, which is safe only because nothing here writes into the
-- nested DAMAGE/FLIGHT tables it shares with production (hit-zones design section 11).
local function specWound()
	local wound = table.clone(Boar.CONFIG.WOUND)
	wound.CARCASS_SECONDS = CARCASS_SECONDS
	return wound
end

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
		local testRoot, runtime, handle, hits, downs, despawns, disconnect

		local function newWorld()
			return {
				field = FIELD,
				parent = testRoot,
				folderName = "Boars",
				rng = Random.new(5),
				config = { WOUND = specWound() },
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
			}
		end

		beforeEach(function()
			testRoot = Instance.new("Folder")
			testRoot.Name = "BoarHitSpec"
			local plate = Instance.new("Part")
			plate.Name = "Plate"
			plate.Size = Vector3.new(320, 4, 320)
			plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
			plate.Anchored = true
			plate.Parent = testRoot
			testRoot.Parent = Workspace

			runtime = Boar.newRuntime(newWorld())
			handle = runtime:spawn(SPAWN)
			hits, downs, despawns = {}, {}, {}
			runtime.Hit:Connect(function(record)
				table.insert(hits, record)
			end)
			runtime.Downed:Connect(function(record)
				table.insert(downs, record)
			end)
			runtime.Despawned:Connect(function(record)
				table.insert(despawns, record)
			end)
			disconnect = runtime:run()
		end)

		afterEach(function()
			if disconnect then
				disconnect()
				disconnect = nil
			end
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
			-- Added in Milestone 1.5, alongside the four above and not instead of them.
			expect(hits[1].damage).to.equal(99)
			expect(hits[1].severity).to.equal("mortal")
		end)

		it("refuses a part that is not one of its boars, and moves no counter", function()
			local stranger = Instance.new("Part")
			stranger.Parent = testRoot
			expect(runtime:takeHit(stranger, { zone = "body", ammo = "Slug", pellets = 1, at = 0 })).to.equal(false)
			expect(runtime:stats().hits).to.equal(0)
			expect(runtime:stats().pelletsTaken).to.equal(0)
			stranger:Destroy()
		end)

		it("reacts inside a tick: a hit boar bolts, whatever it was doing", function()
			-- Karen's playtest asked for exactly this ("I cannot tell if I hit anything"), and the
			-- design's number is ONE Heartbeat tick, not one 0.2 s sense interval.
			expect(handle.state()).to.equal("IDLE")
			local started = os.clock()
			runtime:takeHit(handle.part, {
				zone = "legs",
				ammo = "Slug",
				pellets = 1,
				at = os.clock(),
				shooterPosition = Vector3.new(0, GROUND_Y, 85),
			})
			expect(waitUntil(0.5, function()
				return handle.state() ~= "IDLE"
			end)).to.equal(true)
			local reaction = os.clock() - started
			print(string.format("[boar_hit] reacted in %.0f ms", reaction * 1000))
			expect(reaction < 0.2).to.equal(true)
			expect(handle.state()).to.equal("FLEE")

			-- And it runs AWAY from the shot, using the route code that already existed.
			local before = handle.position()
			expect(waitUntil(2, function()
				return (handle.position() - before).Magnitude > 5
			end)).to.equal(true)
			local shot = Vector3.new(0, GROUND_Y, 85)
			expect((handle.position() - shot).Magnitude > (before - shot).Magnitude).to.equal(true)
		end)

		it("flashes on a hit, and puts its own colours back afterwards", function()
			local zoneHead = handle.part:FindFirstChild("ZoneHead") :: BasePart
			local baseTrunk, baseHead = handle.part.Color, zoneHead.Color
			runtime:takeHit(handle.part, { zone = "legs", ammo = "Buck", pellets = 1, at = 0 })

			expect(waitUntil(0.5, function()
				return handle.part.Color ~= baseTrunk
			end)).to.equal(true)
			expect(zoneHead.Color).never.to.equal(baseHead) -- the zone parts flash too

			-- ...and the zone tint survives it: restoring everything to BODY_COLOR would silently
			-- flatten the boar after its first hit.
			expect(waitUntil(2, function()
				return handle.part.Color == baseTrunk
			end)).to.equal(true)
			expect(zoneHead.Color).to.equal(baseHead)
		end)

		it("dies on a head slug: down, collapsed, and the kill published once", function()
			local at = os.clock()
			expect(runtime:takeHit(handle.part, {
				zone = "head",
				ammo = "Slug",
				pellets = 1,
				at = at,
				distance = 70,
				shooterUserId = 4242,
				shooterName = "Karen",
			})).to.equal(true)

			expect(waitUntil(1, function()
				return handle.state() == "DOWN"
			end)).to.equal(true)
			expect(runtime:stats().downed).to.equal(1)

			expect(waitUntil(2, function()
				return #downs == 1
			end)).to.equal(true)
			local record = downs[1]
			expect(record.killingZone).to.equal("head")
			expect(record.killingAmmo).to.equal("Slug")
			expect(record.killedByUserId).to.equal(4242)
			expect(record.killedByName).to.equal("Karen")
			expect(record.killingDistance).to.equal(70)
			expect(record.instant).to.equal(true) -- it dropped where it stood
			expect(record.flightStuds).to.equal(0)
			expect(#record.wounds).to.equal(1)
			expect(record.shots).to.equal(1)

			-- The body collapsed rather than standing dead.
			expect(handle.part:GetAttribute("Damageable")).to.equal(false)
			expect(handle.part:GetAttribute("Carcass")).to.equal(true)
			expect(handle.part.Parent).to.be.ok()
			local mover = handle.part:FindFirstChild("Mover") :: LinearVelocity
			local upright = handle.part:FindFirstChild("Upright") :: AlignOrientation
			expect(mover.Enabled).to.equal(false)
			expect(upright.Enabled).to.equal(false)

			-- Nothing may kill it twice: 1.7 must not be able to count two kills for one animal.
			expect(runtime:takeHit(handle.part, { zone = "head", ammo = "Slug", pellets = 1, at = 0 })).to.equal(false)
			expect(runtime:stats().hits).to.equal(1)
			task.wait(0.3)
			expect(#downs).to.equal(1)
		end)

		it("leaves a carcass, then removes it with the existing despawn path", function()
			runtime:takeHit(handle.part, { zone = "chest", ammo = "Slug", pellets = 1, at = os.clock() })
			expect(waitUntil(1, function()
				return handle.state() == "DOWN"
			end)).to.equal(true)

			-- Still there a second later: the carcass IS the point.
			task.wait(1)
			expect(handle.part.Parent).to.be.ok()
			expect(runtime:stats().killed).to.equal(0)

			expect(waitUntil(CARCASS_SECONDS + 2, function()
				return #despawns == 1
			end)).to.equal(true)
			expect(despawns[1].reason).to.equal("killed")
			expect(despawns[1].mortallyWounded).to.equal(true)
			expect(despawns[1].damage).to.equal(100)
			expect(handle.part.Parent == nil).to.equal(true)
			expect(runtime:stats().killed).to.equal(1)
			expect(runtime:stats().downed).to.equal(1)
		end)

		it("does NOT die of one leg hit, and slows down when it is mortally wounded", function()
			expect(runtime:takeHit(handle.part, { zone = "legs", ammo = "Slug", pellets = 1, at = os.clock() })).to.equal(
				true
			)
			task.wait(1.5)
			expect(handle.state()).to.equal("FLEE") -- hurt, running, not dying
			expect(runtime:woundOf(handle.id).severity).to.equal("grazed")
			expect(runtime:stats().downed).to.equal(0)

			runtime:takeHit(handle.part, { zone = "legs", ammo = "Slug", pellets = 1, at = os.clock() })
			expect(waitUntil(1, function()
				return handle.state() == "WOUNDED"
			end)).to.equal(true)
			local wound = runtime:woundOf(handle.id)
			expect(wound.severity).to.equal("mortal")
			expect(wound.flightStuds > 300).to.equal(true) -- legs: it has a long way to go

			-- The limp is a SETPOINT scale, so the physics follows it: a leg-shot boar never reaches
			-- the full sprint again.
			local scale = Wound.speedScale(wound, Boar.CONFIG.WOUND)
			expect(scale < 0.8).to.equal(true)
			local fastest = 0
			local deadline = os.clock() + 1
			while os.clock() < deadline do
				local velocity = handle.part.AssemblyLinearVelocity
				fastest = math.max(fastest, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
				task.wait()
			end
			print(string.format("[boar_hit] wounded top speed %.1f studs/s (scale %.2f)", fastest, scale))
			expect(fastest < Boar.CONFIG.SPRINT_SPEED * 0.95).to.equal(true)
			expect(runtime:stats().downed).to.equal(0) -- and it is still very much alive
		end)

		it("counts the zones, and says when a tally or a zone name was missing", function()
			runtime:takeHit(handle.part, {
				zone = "chest",
				zones = { chest = 2, legs = 3 },
				ammo = "Buck",
				pellets = 5,
				at = 0,
			})
			runtime:takeHit(handle.part, { zone = "nose", ammo = "Buck", pellets = 2, at = 0 })

			local stats = runtime:stats()
			expect(stats.zoneHits.chest).to.equal(2)
			expect(stats.zoneHits.legs).to.equal(3)
			expect(stats.tallylessHits).to.equal(1) -- the second call carried no per-pellet tally
			expect(stats.unknownZoneHits).to.equal(1) -- "nose" is not a zone; charged as body, counted
			expect(stats.pelletsTaken).to.equal(7)
			expect(stats.damageTaken).to.equal(2 * 25 + 3 * 6 + 2 * 11)
		end)
	end)

	describe("a wounded boar that gets away", function()
		it("crosses the exit line and reports the wound with the escape", function()
			local testRoot = Instance.new("Folder")
			testRoot.Name = "BoarEscapeSpec"
			local plate = Instance.new("Part")
			plate.Name = "Plate"
			plate.Size = Vector3.new(320, 4, 320)
			plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
			plate.Anchored = true
			plate.Parent = testRoot
			testRoot.Parent = Workspace

			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = testRoot,
				folderName = "Boars",
				rng = Random.new(9),
				config = { WOUND = specWound() },
				threats = function()
					return {}
				end,
				probe = function()
					return false
				end,
				requestPath = function(_id, _from, _to, done)
					done(nil) -- no navmesh here: the straight-line fallback is what drives it out
				end,
				releasePath = function() end,
			})
			local records = {}
			runtime.Despawned:Connect(function(record)
				table.insert(records, record)
			end)
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, -120))
			local stop = runtime:run()

			-- Two leg slugs: mortal, but with 336 studs to run -- far more than the 20 studs between
			-- it and the exit line at z = -140. It does not die here; it gets away hurt, and that is
			-- an event in its own right.
			runtime:takeHit(handle.part, {
				zone = "legs",
				ammo = "Slug",
				pellets = 1,
				at = os.clock(),
				shooterPosition = Vector3.new(0, GROUND_Y, -80),
			})
			runtime:takeHit(handle.part, {
				zone = "legs",
				ammo = "Slug",
				pellets = 1,
				at = os.clock(),
				shooterPosition = Vector3.new(0, GROUND_Y, -80),
			})

			expect(waitUntil(12, function()
				return #records == 1
			end)).to.equal(true)
			expect(records[1].reason).to.equal("escaped")
			expect(records[1].wounded).to.equal(true)
			expect(records[1].mortallyWounded).to.equal(true)
			expect(records[1].damage).to.equal(60)
			expect(#records[1].wounds).to.equal(2)
			expect(runtime:stats().escapedWounded).to.equal(1)
			expect(runtime:stats().killed).to.equal(0) -- an escape is not a kill

			stop()
			runtime:destroy()
			testRoot:Destroy()
		end)
	end)

	describe("the boar's teardown", function()
		-- Round 1, finding 1 (Task 24): the first version of this counted BindableEvent descendants
		-- of the spec's own folder. The runtime's signals are never parented, so that count was 0
		-- before destroy(), after destroy(), and with the destroy call deleted -- a test that could
		-- not fail, guarding the one line it existed for. A connection is the observable: Destroy()
		-- disconnects every listener, so this goes red the moment a signal stops being destroyed.
		it("destroys all three signals, so every listener is disconnected", function()
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
			local onDowned = runtime.Downed:Connect(function() end)
			expect(onHit.Connected).to.equal(true)
			expect(onDespawn.Connected).to.equal(true)
			expect(onDowned.Connected).to.equal(true)

			runtime:destroy()

			expect(onHit.Connected).to.equal(false)
			expect(onDespawn.Connected).to.equal(false)
			expect(onDowned.Connected).to.equal(false)
			testRoot:Destroy()
		end)
	end)
end
