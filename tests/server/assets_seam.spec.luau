-- assets_seam.spec: the manifest and the one id -> Instance seam (Task 74, M2.7a).
--
-- BOTH PATHS, DRIVEN BY INJECTION. The harness runs inside Studio, where `InsertService:LoadAsset`
-- may or may not reach the network on any given day -- so a spec that only ever saw the real thing
-- would be a spec that passes for reasons it cannot name. `Loader.setInsert` replaces the one call
-- that hits the world, and every branch below is reached on purpose: the mesh loaded and used, and
-- each way it can fail ending in the grey box rather than in a gunless player.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/asset-pipeline.md (sections 4, 5, 6.1, 6.6, 6.7)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))

local Hardware = Weapon.Hardware
local CONFIG = Shotgun.CONFIG

-- A stand-in for what `LoadAsset` returns: a Model wrapper around one MeshPart, which is the shape
-- the real asset came back as (measured, Task 74: Model > Model > MeshPart + SurfaceAppearance).
local function fakeAsset(meshParts: number, withScript: boolean?, size: Vector3?)
	local container = Instance.new("Model")
	container.Name = "Model"
	for index = 1, meshParts do
		local mesh = Instance.new("MeshPart")
		mesh.Name = "output_unwrapped" .. (if index > 1 then tostring(index) else "")
		mesh.Size = size or Vector3.new(199.999, 31.314, 11.311)
		mesh.Parent = container
	end
	if withScript then
		local nasty = Instance.new("Script")
		nasty.Name = "Backdoor"
		nasty.Parent = container
	end
	return container
end

-- THE ORDER OF THESE TWO LINES IS THE WHOLE POINT, and round 1 had them the wrong way round.
--
-- `Loader.clear()` destroys the templates it is holding and, when no cache parent is set, the live
-- `ServerStorage.AssetCache` too. Round 1 called `clear()` BEFORE `setCacheParent`, so every case in
-- this file destroyed the real shotgun template that `WeaponBoot` had preloaded -- and nothing put
-- it back, so the running server wore the grey box for the rest of the session and any screenshot
-- taken afterwards was of the fallback gun. That is exactly the failure
-- `Hardware.getTemplateProvider` was added to prevent, defeated one line higher up.
--
-- So: nominate the throwaway container FIRST. From that moment `clear()` can only reach what this
-- spec created. `restoreLive` at the end of the file puts the real template back.
local function withLoader(insert, body)
	local cacheFolder = Instance.new("Folder")
	Loader.setCacheParent(cacheFolder)
	Loader.clear()
	Loader.setInsert(insert)
	local ok, why = pcall(body)
	Loader.clear()
	Loader.setInsert(nil)
	Loader.setCacheParent(nil)
	cacheFolder:Destroy()
	if not ok then
		error(why, 0)
	end
end

return function()
	describe("the asset manifest", function()
		it("is the one source of ids, and the gun's key resolves", function()
			local row = Assets.byKey(Hardware.ASSET_KEY)
			expect(row).to.be.ok()
			expect(row.key).to.equal("shotgun.handle")
			-- 0 IS NEVER VALID: an unset id must not look like a row.
			expect(row.modelId > 0).to.equal(true)
			expect(row.kind).to.equal("meshpart")
			expect(row.moderation).to.equal("approved")
			expect(Assets.describe(Hardware.ASSET_KEY)).to.equal(row)
			expect(#Assets.keysFor("runtime") >= 1).to.equal(true)
			-- ...and there is no second id table: MapGen's is still empty (map-generator 12.2).
			local mapGen = ServerStorage:FindFirstChild("MapGen")
			if mapGen then
				local mapAssets = require(mapGen:WaitForChild("Assets"))
				expect(#mapAssets.ROWS).to.equal(0)
			end
		end)

		it("keeps the gun's LENGTH and does not squash it", function()
			local row = Assets.byKey(Hardware.ASSET_KEY)
			-- The length is the number GRIP and MUZZLE_OFFSET are built on, so it is exact.
			expect(math.abs(row.sizeStuds.X - CONFIG.HANDLE_SIZE.Z) < 1e-6).to.equal(true)
			-- UNIFORM, and this is the assertion that catches a non-uniform "fit to the envelope":
			-- every axis is the natural size times the SAME factor, so the gun cannot be squashed
			-- flat and still measure right (design 6.1's squashed boar).
			local natural = row.naturalSizeStuds
			expect(natural).to.be.ok()
			local factor = row.sizeStuds.X / natural.X
			expect(math.abs(row.sizeStuds.Y / natural.Y - factor) < 1e-4).to.equal(true)
			expect(math.abs(row.sizeStuds.Z / natural.Z - factor) < 1e-4).to.equal(true)
			-- and it really is a different shape from the envelope, or the check above proves nothing
			expect(row.sizeStuds.Y > CONFIG.HANDLE_SIZE.Y).to.equal(true)
			TestKit.note(
				string.format(
					"shotgun mesh: natural %.1f x %.1f x %.1f -> %.3f x %.3f x %.3f studs (x%.5f)",
					natural.X,
					natural.Y,
					natural.Z,
					row.sizeStuds.X,
					row.sizeStuds.Y,
					row.sizeStuds.Z,
					factor
				)
			)
		end)

		it("is frozen, all the way down", function()
			expect(function()
				(Assets.ROWS :: any)[1] = nil
			end).to.throw()
			expect(function()
				(Assets.ROWS[1] :: any).modelId = 1
			end).to.throw()
		end)
	end)

	describe("the id to Instance seam", function()
		it("loads the mesh, unwraps it, and hands the same template out without yielding", function()
			withLoader(function(modelId)
				expect(modelId).to.equal(Assets.byKey(Hardware.ASSET_KEY).modelId)
				return fakeAsset(1)
			end, function()
				local report = Loader.preload({ Hardware.ASSET_KEY })[1]
				expect(report.ok).to.equal(true)
				expect(report.reason).to.equal(nil)
				expect(report.meshParts).to.equal(1)
				local template = Loader.template(Hardware.ASSET_KEY)
				expect(template).to.be.ok()
				-- THE MODEL WRAPPER IS NOT THE ASSET (design 6.7): what comes back is the MeshPart.
				expect(template:IsA("MeshPart")).to.equal(true)
				expect(Loader.stats().loaded).to.equal(1)
			end)
		end)

		it("ends in the grey box for every way it can fail, and says which", function()
			local cases = {
				{
					name = "insert-failed",
					insert = function()
						return nil
					end,
				},
				{
					name = "contains-script",
					insert = function()
						return fakeAsset(1, true)
					end,
				},
				{
					name = "no-meshpart",
					insert = function()
						return fakeAsset(0)
					end,
				},
				{
					name = "multi-meshpart",
					insert = function()
						return fakeAsset(2)
					end,
				},
				-- A mesh whose proportions are not the row's: the squashed-model case, caught by
				-- measurement rather than by trust.
				{
					name = "aspect",
					insert = function()
						return fakeAsset(1, false, Vector3.new(100, 100, 100))
					end,
				},
			}
			for _, case in ipairs(cases) do
				withLoader(case.insert, function()
					local report = Loader.preload({ Hardware.ASSET_KEY })[1]
					if report.ok or report.reason ~= case.name then
						error(
							string.format(
								"expected %s, got ok=%s reason=%s",
								case.name,
								tostring(report.ok),
								tostring(report.reason)
							),
							0
						)
					end
					expect(Loader.template(Hardware.ASSET_KEY)).to.equal(nil)
					expect(Loader.stats().lastReasons[Hardware.ASSET_KEY]).to.equal(case.name)
				end)
			end
		end)

		it("gives up on a load that never returns, and says timeout", function()
			-- A BOOT THAT WAITS ON THE NETWORK IS A GAME THAT DOES NOT START (design 5.2). The
			-- insert here never returns -- the shape of a moderation queue, a dead endpoint or a
			-- Studio with no network -- and `preload` must still come back, with a reason.
			local started = os.clock()
			withLoader(function()
				while true do
					task.wait(0.1)
				end
			end, function()
				local report = Loader.preload({ Hardware.ASSET_KEY })[1]
				expect(report.ok).to.equal(false)
				expect(report.reason).to.equal("timeout")
				expect(Loader.template(Hardware.ASSET_KEY)).to.equal(nil)
			end)
			local waited = os.clock() - started
			-- It gave up at the bound rather than hanging the suite: generous, because the harness
			-- runs under load, but far below "forever".
			expect(waited < Loader.CONFIG.LOAD_TIMEOUT_S + 8).to.equal(true)
			TestKit.note(
				string.format(
					"loader timeout: gave up after %.1f s (bound %.0f s)",
					waited,
					Loader.CONFIG.LOAD_TIMEOUT_S
				)
			)
		end)

		it("refuses a key it has no row for, and never throws for it", function()
			withLoader(function()
				error("the insert must not even be attempted for an unknown key", 0)
			end, function()
				local report = Loader.preload({ "no.such.key" })[1]
				expect(report.ok).to.equal(false)
				expect(report.reason).to.equal("no-row")
			end)
		end)
	end)

	describe("the live server after this file has run", function()
		it("still holds the real template, so the session does not end on the grey box", function()
			-- THE SPEC PUTS THE WORLD BACK. Every case above worked in its own container, so the
			-- live cache was never touched -- but `preload` is the only thing that fills it, and if
			-- anything here ever drops it again this check is what says so, in the run, rather than
			-- in a screenshot three tasks later.
			local template = Loader.template(Hardware.ASSET_KEY)
			if template == nil then
				-- Not necessarily this file's doing: a server where the real LoadAsset failed at
				-- boot has none either. Re-run the real load once and report what happened.
				local report = Loader.preload({ Hardware.ASSET_KEY })[1]
				template = Loader.template(Hardware.ASSET_KEY)
				TestKit.note(
					string.format(
						"live template was missing; re-preload ok=%s reason=%s",
						tostring(report.ok),
						tostring(report.reason)
					)
				)
			end
			local stats = Loader.stats()
			TestKit.note(
				string.format(
					"live loader after the specs: template=%s loaded=%d failed=%d proxies=%d",
					if template then template.ClassName else "nil",
					stats.loaded,
					stats.failed,
					stats.proxies
				)
			)
			-- The Tool a player gets right now is the thing this asserts, not the cache directly.
			local tool = Hardware.build()
			local handle = tool:FindFirstChild("Handle") :: BasePart
			local wearing = handle:FindFirstChild("Model") ~= nil
			local partsGun = handle:FindFirstChild("BarrelLeft") ~= nil
			tool:Destroy()
			-- One or the other, never neither: a Handle with nothing on it is the gunless case.
			expect(wearing or partsGun).to.equal(true)
			TestKit.note(
				if wearing
					then "the live server is wearing Karen's mesh"
					else "the live server is wearing the parts gun"
			)
		end)
	end)

	describe("the gun that is built", function()
		-- THE LIVE PROVIDER IS PUT BACK. A spec that leaves its fake wired in changes what every
		-- later spec -- and every later screenshot -- sees.
		local live = Hardware.getTemplateProvider()

		local function withProvider(fn, body)
			Hardware.setTemplateProvider(fn)
			local ok, why = pcall(body)
			Hardware.setTemplateProvider(live)
			if not ok then
				error(why, 0)
			end
		end

		it("wears the mesh when there is one, and nothing about the Handle changes", function()
			local row = Assets.byKey(Hardware.ASSET_KEY)
			local template = Instance.new("MeshPart")
			template.Size = row.naturalSizeStuds
			withProvider(function()
				return template, { row = row }
			end, function()
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				-- Everything the rest of the system is built on is untouched.
				expect(handle.Size).to.equal(CONFIG.HANDLE_SIZE)
				expect(tool.Grip).to.equal(CONFIG.GRIP)
				expect(handle:FindFirstChild("Muzzle")).to.be.ok()
				expect(handle.CanQuery).to.equal(true) -- still the only part a ray can hit

				local model = handle:FindFirstChild("Model") :: BasePart
				expect(model).to.be.ok()
				expect(model:IsA("MeshPart")).to.equal(true)
				expect(model.Size).to.equal(row.sizeStuds)
				expect(model.CanQuery).to.equal(false)
				expect(model.CanCollide).to.equal(false)
				expect(model.Massless).to.equal(true)
				-- welded to the Handle with the row's own pose, so the geometry comes from the
				-- manifest and not from wherever the part happened to be
				local weld = handle:FindFirstChild("ModelWeld") :: Weld
				expect(weld).to.be.ok()
				expect(weld.Part0).to.equal(handle)
				expect(weld.Part1).to.equal(model)
				-- AND THE PARTS GUN IS NOT ALSO THERE: one gun, not two overlapping ones.
				expect(handle:FindFirstChild("BarrelLeft")).to.equal(nil)
				expect(handle:FindFirstChild("Stock")).to.equal(nil)
				tool:Destroy()
			end)
		end)

		it("falls back to the parts gun when the mesh is not there", function()
			withProvider(function()
				return nil, { reason = "insert-failed" }
			end, function()
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				expect(handle:FindFirstChild("Model")).to.equal(nil)
				-- Task 71's ten pieces, so the player is never gunless.
				expect(handle:FindFirstChild("BarrelLeft")).to.be.ok()
				expect(handle:FindFirstChild("BarrelRight")).to.be.ok()
				expect(handle:FindFirstChild("Stock")).to.be.ok()
				expect(handle:FindFirstChild("Trigger")).to.be.ok()
				tool:Destroy()
			end)
		end)

		it("falls back with no provider wired at all", function()
			withProvider(nil, function()
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				expect(handle:FindFirstChild("Model")).to.equal(nil)
				expect(handle:FindFirstChild("BarrelLeft")).to.be.ok()
				tool:Destroy()
			end)
		end)
	end)
end
