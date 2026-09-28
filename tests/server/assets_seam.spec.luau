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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))

local Hardware = Weapon.Hardware
local Shape = Weapon.Shape
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

-- THE SPEC RUNS AGAINST A LOADER STATE OF ITS OWN, AND THAT IS THE WHOLE FIX. It took three rounds
-- to get right, so here is what did not work:
--
--   * Round 1 called `Loader.clear()` while the loader still held the live `shotgun.handle`, so every
--     case destroyed the template `WeaponBoot` had preloaded. Nothing put it back: the server wore
--     the grey box for the rest of the session and the in-game screenshots were of the fallback gun.
--   * Round 2 nominated a throwaway cache FOLDER first and believed that was enough. It was not.
--     `clear()` walked the loader's one MODULE-LEVEL `templates` table and destroyed every Instance
--     in it -- including the live one, which sits in the live cache folder, not in the spec's. The
--     folder was guarded and the templates were not, so the defect was untouched and the comment
--     that said otherwise was wrong (review finding 3, twice).
--
-- `Loader.newState()` is the structural answer: the scratch state has its own `templates`, its own
-- reports and its own cache container, so `clear()` has no way to NAME the live template, let alone
-- destroy it. A load still in flight keeps the state it started in, so a slow fake cannot park itself
-- into the live cache afterwards either. `hadTemplate` below is what proves it, per run.
--
-- SINCE TASK 76 IT ALSO UNWIRES THE WEAPON'S TEMPLATE PROVIDER, and that is not tidiness either. The
-- 2 s arming sweep now asks for a template on every pass (`Hardware.upgradeAll`), and the cases below
-- YIELD -- so with a scratch loader state current, the sweep's ask would reach THIS spec's fake
-- template and could weld it onto a live player's gun for the rest of the session. `nil` means "build
-- the parts gun", which is the fallback the sweep would otherwise be repairing; the live provider goes
-- back with the live state.
local function withLoader(insert, body)
	local cacheFolder = Instance.new("Folder")
	local live = Loader.setState(Loader.newState())
	local liveProvider = Hardware.getTemplateProvider()
	Hardware.setTemplateProvider(nil)

	Loader.setCacheParent(cacheFolder)
	Loader.setInsert(insert)
	-- THE TRACEBACK COMES WITH IT. A bare pcall reports this rethrow's line and nothing
	-- else, so a failure inside the body names the seam rather than the assertion that
	-- failed -- measured in task 96, where three candidates all looked plausible.
	local ok, why = xpcall(body, function(message)
		return tostring(message) .. " | " .. debug.traceback("", 2)
	end)
	-- clears the SCRATCH state only: its own templates and nothing else in the world
	Loader.clear()
	Loader.setState(live)
	Hardware.setTemplateProvider(liveProvider)
	cacheFolder:Destroy()
	if not ok then
		error(why, 0)
	end
end

return function()
	-- THE INSTANCE THE RUNNING SERVER HELD BEFORE THIS FILE DID ANYTHING. Not a boolean: the last
	-- describe asserts the SAME Instance is still there and still parented, so a spec that destroyed
	-- it and fetched a replacement over the network would not pass either.
	local hadTemplate: Instance? = nil

	describe("the live server before any of this", function()
		it("records the template boot loaded, so the cases below can be held to it", function()
			-- IT WAITS FOR THE BOOT LOAD TO DECIDE, ONCE. `WeaponBoot` preloads over the network at
			-- server start and this suite begins a second or two later, so asking once answers "not
			-- yet" on a perfectly healthy server -- which is how round 3's first attempt at this
			-- check ended up vacuous on the very runs it was written for (measured: the note said
			-- "no live template existed" while the same run's later cases proved one had arrived).
			-- `LOAD_TIMEOUT_S` is the bound boot itself works to, so waiting a little past it is
			-- waiting exactly as long as boot could still be trying, and no longer.
			local deadline = os.clock() + Loader.CONFIG.LOAD_TIMEOUT_S + 2
			hadTemplate = Loader.template(Hardware.ASSET_KEY)
			while hadTemplate == nil and os.clock() < deadline do
				task.wait(0.25)
				hadTemplate = Loader.template(Hardware.ASSET_KEY)
			end
			-- NOTHING IS ASSERTED ABOUT WHETHER IT LOADED. A Studio with no network has nothing to
			-- protect and that is not this file's failure; what must not happen is this file
			-- DESTROYING it, which the last describe is what checks.
			TestKit.note(
				if hadTemplate
					then string.format("boot loaded the live template: %s", hadTemplate:GetFullName())
					else "boot loaded no template (no network, or it failed); nothing for the specs to lose"
			)
		end)
	end)

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
			-- ONE KEY, ONCE. Two rows for the gun now exist, and `#keysFor >= 1` would have passed
			-- just as happily on the duplicate that `Loader.preload` would have loaded twice
			-- (review round 1, note). Asserted as an exact set instead.
			local keys = Assets.keysFor("runtime")
			local counted = {}
			for _, key in ipairs(keys) do
				counted[key] = (counted[key] or 0) + 1
			end
			expect(counted[Hardware.ASSET_KEY]).to.equal(1)
			-- TWO KEYS SINCE TASK 96, each exactly once: the gun ships as a body and a barrel group
			-- so the break-action can hinge, and both have to be preloaded before a player holds one.
			expect(counted[Hardware.BARRELS_KEY]).to.equal(1)
			expect(#keys).to.equal(2)
			-- ...and there is no second id table: MapGen's is still empty (map-generator 12.2).
			local mapGen = ServerStorage:FindFirstChild("MapGen")
			if mapGen then
				local mapAssets = require(mapGen:WaitForChild("Assets"))
				expect(#mapAssets.ROWS).to.equal(0)
			end
		end)

		it("keeps the hands out of the server's preload, and gives them a scope of their own", function()
			-- TASK 93. The two hands are loaded on the server -- `LoadAsset` is server-only -- but the
			-- server has nothing to do with them afterwards: they are cloned under the local player's
			-- camera and never worn by a Tool. `WeaponBoot` must not preload them (the `#keys == 2`
			-- above is the other half of this claim) and `ViewmodelAssetsBoot` must not preload the
			-- gun, or the two boot lines would ask the Loader for the same key at the same moment.
			local viewmodel = Assets.keysFor("viewmodel")
			table.sort(viewmodel)
			TestKit.note(string.format("task93 viewmodel keys: [%s]", table.concat(viewmodel, ", ")))
			expect(#viewmodel).to.equal(2)
			expect(viewmodel[1]).to.equal(Assets.KEYS.handLeft)
			expect(viewmodel[2]).to.equal(Assets.KEYS.handRight)
			for _, key in ipairs(Assets.keysFor("runtime")) do
				expect(key ~= Assets.KEYS.handLeft and key ~= Assets.KEYS.handRight).to.equal(true)
			end
			-- AND EACH HAND IS A REAL ROW: an approved id, one mesh, and a size that is a hand's
			-- rather than the gun's. 1.28 studs is 330 mm at this game's scale (the gun is 4.4 studs
			-- for 1,143 mm); anything near the gun's own length would be an arm across the screen.
			for _, key in ipairs(viewmodel) do
				local hand = Assets.byKey(key)
				expect(hand).to.be.ok()
				expect(hand.modelId > 0).to.equal(true)
				expect(hand.kind).to.equal("meshpart")
				expect(hand.moderation).to.equal("approved")
				expect(hand.scope).to.equal("viewmodel")
				local longest = math.max(hand.sizeStuds.X, hand.sizeStuds.Y, hand.sizeStuds.Z)
				TestKit.note(string.format("task93 %s: %.2f studs long, %d tris", key, longest, hand.trisDeclared))
				expect(longest > 0.8 and longest < 1.8).to.equal(true)
				-- THE HANDS ARE POSED BY THE CAMERA, so this field is zero and nothing reads it. It
				-- is asserted rather than left alone because a non-zero rotation here would be a
				-- number somebody wrote expecting it to do something.
				expect(hand.rotationDeg).to.equal(Vector3.zero)
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

		it("keeps the row it replaced, and hands out the new one", function()
			-- RULE 7 IN THE ONE PLACE AN ID LIVES. Task 75 re-uploaded Karen's shotgun with the
			-- barrel shine she asked for, so there are now two rows for one key. The old id STAYS:
			-- an id that has been in a place is provenance, and a rolled-back or moderated-away
			-- asset cannot be diagnosed from a row that was deleted.
			local mine = {}
			for _, row in ipairs(Assets.ROWS) do
				if row.key == Hardware.ASSET_KEY then
					table.insert(mine, row)
				end
			end
			-- NINE SINCE TASK 96, and every one of them is still here with the reason it was replaced:
			-- v3 shaded the generated model smooth, v4 to v7 built and fixed the barrels, v8 seated
			-- the forend, and v9 is the BODY half of the gun -- the barrels moved to a key of their
			-- own so a break-action reload can hinge them. The count is asserted so a row that
			-- appears without anyone deciding is a failure, and the CHAIN is asserted by rule rather
			-- than by naming today's numbers twice: exactly one row is live, every other row points
			-- at a later version, and no chain dead-ends.
			expect(#mine).to.equal(9)
			local live = Assets.byKey(Hardware.ASSET_KEY)
			expect(live.version).to.equal(9)
			expect(live.modelId).to.equal(121405298612730)
			-- ...AND THE PIECE THAT HINGES IS A KEY OF ITS OWN, live and approved (task 96).
			local barrels = Assets.byKey(Hardware.BARRELS_KEY)
			expect(barrels).to.be.ok()
			expect(barrels.modelId).to.equal(85998258056906)
			expect(barrels.moderation).to.equal("approved")
			-- The two halves assemble at ONE CFrame: same size, same rotation, no offset between
			-- them, which is what the baked-in bounding box in each piece is for.
			expect(barrels.sizeStuds).to.equal(live.sizeStuds)
			expect(barrels.rotationDeg).to.equal(live.rotationDeg)
			expect(barrels.offsetStuds).to.equal(live.offsetStuds)
			expect(live.supersededBy).to.equal(nil)
			local byVersion, liveRows = {}, 0
			for _, row in ipairs(mine) do
				byVersion[row.version] = row
				if row.supersededBy == nil then
					liveRows += 1
				end
			end
			expect(liveRows).to.equal(1)
			for _, row in ipairs(mine) do
				if row.supersededBy ~= nil then
					-- the row it points at exists, and is later than it
					expect(byVersion[row.supersededBy]).to.be.ok()
					expect(row.supersededBy > row.version).to.equal(true)
				end
			end
			-- ...and the FIRST row is still here, still saying why it was replaced.
			local first = byVersion[1]
			expect(first.modelId).to.equal(117134580332969)
			expect(first.supersededBy).to.equal(2)
			expect(string.find(first.notes :: string, "SUPERSEDED") ~= nil).to.equal(true)
			-- ...as are the ones tasks 92 and 94 replaced, with their own ids kept.
			expect(byVersion[2].modelId).to.equal(103304840285660)
			expect(byVersion[3].modelId).to.equal(137252961155547)
			expect(byVersion[4].modelId).to.equal(80699745427569)
			expect(byVersion[5].modelId).to.equal(73632997167378)
			expect(byVersion[6].modelId).to.equal(94500894676280)
			expect(byVersion[7].modelId).to.equal(107443663683446)
			expect(byVersion[8].modelId).to.equal(126484176321060)
		end)

		it("skips a superseded row even when it is the newest one", function()
			-- THE RULE, NOT TODAY'S DATA. With the real table the answer is the same whether the
			-- rule is "highest version" or "highest version that is not superseded", so the two are
			-- asked separately, on a table this case owns. Delete the `supersededBy == nil` test in
			-- `Assets.byKey` and this is the case that fails; the one above still passes.
			local row = Assets.byKey("x", {
				{ key = "x", version = 1, modelId = 11 } :: any,
				{ key = "x", version = 9, modelId = 99, supersededBy = 10 } :: any,
			})
			expect(row).to.be.ok()
			expect(row.modelId).to.equal(11)
			-- a rejected row is skipped the same way, and nothing usable means nil, not an error
			expect(Assets.byKey("x", { { key = "x", version = 1, moderation = "rejected" } :: any })).to.equal(nil)
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

		it("gives up on a slow load, says timeout, and adopts it when it lands", function()
			-- A BOOT THAT WAITS ON THE NETWORK IS A GAME THAT DOES NOT START (design 5.2). This
			-- insert takes longer than the bound -- the shape of a moderation queue or a bad day on
			-- the CDN -- and `preload` must come back anyway, with a reason.
			--
			-- IT RETURNS RATHER THAN SPINNING FOREVER, deliberately: round 2's fake was
			-- `while true do task.wait(0.1) end`, and the thread it ran in is abandoned, not
			-- cancelled, so every harness run left one coroutine spinning for the rest of the Studio
			-- session (review round 2, note). Returning late costs the same evidence and also proves
			-- the other half of the rule: a late arrival is LATE, NOT LOST.
			local waited, adopted = 0, 0
			withLoader(function()
				task.wait(Loader.CONFIG.LOAD_TIMEOUT_S + 1)
				return fakeAsset(1)
			end, function()
				local began = os.clock()
				local report = Loader.preload({ Hardware.ASSET_KEY })[1]
				waited = os.clock() - began
				expect(report.ok).to.equal(false)
				expect(report.reason).to.equal("timeout")
				-- FLATLY nil, and that is new: this state is the spec's own, so there is no longer a
				-- shared table for the live boot to fill in the middle of the wait. Round 2 could
				-- only decline to assert this.
				expect(Loader.template(Hardware.ASSET_KEY)).to.equal(nil)
				local deadline = os.clock() + 5
				while Loader.template(Hardware.ASSET_KEY) == nil and os.clock() < deadline do
					task.wait(0.1)
				end
				adopted = os.clock() - began
				expect(Loader.template(Hardware.ASSET_KEY)).to.be.ok()
				expect(Loader.stats().lastReasons[Hardware.ASSET_KEY]).to.equal("late")
			end)
			-- It gave up AT the bound: neither instantly (which would prove nothing) nor forever.
			expect(waited > 1).to.equal(true)
			expect(waited < Loader.CONFIG.LOAD_TIMEOUT_S + 5).to.equal(true)
			TestKit.note(
				string.format(
					"loader timeout: gave up after %.1f s (bound %.0f s), adopted the late arrival at %.1f s",
					waited,
					Loader.CONFIG.LOAD_TIMEOUT_S,
					adopted
				)
			)
		end)

		it("cannot reach a template another state holds, with no network in sight", function()
			-- THE PROOF OF THE FIX, AND IT DEPENDS ON NOTHING OUTSIDE THIS FUNCTION. Two states,
			-- neither of them the live one: `keeper` stands in for the running server that has
			-- preloaded its gun, and then a whole spec's worth of work happens in another state,
			-- `Loader.clear()` included. What the keeper holds must be untouched -- the same
			-- Instance, still parented where it was put.
			--
			-- Round 2's loader could not pass this: `clear()` walked one module-level table, so the
			-- scratch case destroyed the keeper's template. Put `local live = Loader.getState()` back
			-- into `withLoader` and this is the case that goes red first.
			local liveState = Loader.setState(Loader.newState())
			local keeperCache = Instance.new("Folder")
			local ok, why = pcall(function()
				local keeper = Loader.getState()
				Loader.setCacheParent(keeperCache)
				Loader.setInsert(function()
					return fakeAsset(1)
				end)
				expect(Loader.preload({ Hardware.ASSET_KEY })[1].ok).to.equal(true)
				local held = Loader.template(Hardware.ASSET_KEY)
				expect(held).to.be.ok()
				expect(held.Parent).to.equal(keeperCache)

				withLoader(function()
					return fakeAsset(2)
				end, function()
					-- a failure AND a clear in the scratch state, which is the hostile case
					expect(Loader.preload({ Hardware.ASSET_KEY })[1].reason).to.equal("multi-meshpart")
					expect(Loader.template(Hardware.ASSET_KEY)).to.equal(nil)
				end)

				expect(Loader.getState()).to.equal(keeper)
				expect(Loader.template(Hardware.ASSET_KEY)).to.equal(held)
				expect((held :: Instance).Parent).to.equal(keeperCache)
				Loader.clear() -- and now the keeper clears its OWN template, which is allowed
				expect(Loader.template(Hardware.ASSET_KEY)).to.equal(nil)
			end)
			Loader.setState(liveState)
			keeperCache:Destroy()
			if not ok then
				error(why, 0)
			end
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
		it("still holds the very Instance it held before these cases, untouched", function()
			-- THE CHECK THAT CAN FAIL. Round 2's version repaired the damage over the network and
			-- reported it in a note, so it passed in exactly the state its name ruled out. This one
			-- compares IDENTITY against `hadTemplate`, recorded before any case, and it repairs
			-- nothing: put round 2's `clear()` back and this is the assertion that goes red.
			local now = Loader.template(Hardware.ASSET_KEY)
			local stats = Loader.stats()
			if hadTemplate then
				expect(now).to.equal(hadTemplate)
				expect(hadTemplate.Parent ~= nil).to.equal(true)
				-- ...and the gun a player would be handed right now is the mesh, not the grey box.
				-- Asserting "one or the other" would be no assertion at all: `Hardware.build` always
				-- draws one of them (review round 2).
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				local wearing = handle:FindFirstChild("Model") ~= nil
				tool:Destroy()
				expect(wearing).to.equal(true)
				TestKit.note(
					string.format(
						"the live template survived the specs: %s (proxies=%d)",
						hadTemplate:GetFullName(),
						stats.proxies
					)
				)
			else
				-- NETWORK-INDEPENDENT, and this is why the check records the Instance rather than
				-- asking the network: a Studio with no connection, or a boot whose own preload had
				-- not finished when this file was collected, has nothing to protect. Say which case
				-- this run was instead of quietly passing as if it had proved something.
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				local partsGun = handle:FindFirstChild("BarrelLeft") ~= nil
				tool:Destroy()
				expect(partsGun).to.equal(true)
				TestKit.note(
					string.format(
						"no live template existed before these cases; nothing to protect, "
							.. "and the fallback gun is what a player gets (failed=%d)",
						stats.failed
					)
				)
			end
		end)
	end)

	describe("the gun that is built", function()
		local function withProvider(fn, body)
			local live = Hardware.getTemplateProvider()
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

	-- TASK 76: THE GUN THAT WAS HANDED OUT TOO EARLY.
	--
	-- `WeaponBoot` starts the weapon system BEFORE the preload, deliberately (Task 74 review round 1:
	-- a stalled `LoadAsset` must not mean a gunless player), so a player who spawns in the server's
	-- first second is handed the parts fallback. Measured twice in Task 75: the preload took 1227 ms
	-- and the Tool granted before it had `BarrelLeft` and no `Model` for as long as it was held.
	--
	-- EVERY CASE HERE IS DRIVEN BY THE PROVIDER, NOT BY A CLOCK. "Late" is expressed as a provider
	-- that answers nil and then answers a template -- which is what a late arrival IS from this
	-- module's side -- so nothing below yields. That matters twice over: a spec that waits is a spec
	-- that lets the live 2 s arming sweep run while a fake provider is wired, and the sweep now calls
	-- `upgradeAll`.
	-- ------------------------------------------------------------------ the sight (task 90, S2)
	describe("the sight the first-person camera aims with", function()
		local function withProvider(fn, body)
			local live = Hardware.getTemplateProvider()
			Hardware.setTemplateProvider(fn)
			local ok, why = pcall(body)
			Hardware.setTemplateProvider(live)
			if not ok then
				error(why, 0)
			end
		end

		it("is on the Handle beside the Muzzle, at the parts gun's own bead", function()
			withProvider(nil, function()
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				local sight = handle:FindFirstChild(Hardware.SIGHT_NAME)
				expect(sight).to.be.ok()
				expect((sight :: Instance):IsA("Attachment")).to.equal(true)
				expect((sight :: Attachment).CFrame).to.equal(Shape.sight(CONFIG))
				-- beside the muzzle, and one of each
				expect(handle:FindFirstChild("Muzzle")).to.be.ok()
				local sights = 0
				for _, child in ipairs(handle:GetChildren()) do
					if child.Name == Hardware.SIGHT_NAME then
						sights += 1
					end
				end
				expect(sights).to.equal(1)
				tool:Destroy()
			end)
		end)

		it("is the SAME expression that places the bead the player sees", function()
			-- The mechanical proof that there is one source for "where the bead is". Two
			-- expressions would let the drawn bead and the aimed point drift apart -- both
			-- measured, both green, and the picture a lie.
			local bead = nil
			for _, piece in ipairs(Shape.pieces(CONFIG)) do
				if piece.name == "Bead" then
					bead = piece
				end
			end
			expect(bead).to.be.ok()
			local fromPiece = (bead :: any).offset.Position
			local fromSight = Shape.sight(CONFIG).Position
			expect((fromPiece - fromSight).Magnitude < 1e-6).to.equal(true)
			expect((fromSight - Shape.beadOffset(CONFIG)).Magnitude < 1e-6).to.equal(true)
			-- and it is where a bead belongs: above the bore, at the muzzle end
			expect(fromSight.Y > 0).to.equal(true)
			expect(math.abs(fromSight.Z - Shape.muzzleZ(CONFIG)) < 0.25).to.equal(true)
		end)

		it("takes the row's measurement for a mesh, and falls back when there is none", function()
			local row = Assets.byKey(Hardware.ASSET_KEY)
			local template = Instance.new("MeshPart")
			template.Size = row.naturalSizeStuds
			local measured = Vector3.new(0, 0.3, -2.1)

			local withRow = table.clone(row) :: any
			withRow.sightOffsetStuds = measured
			withProvider(function()
				return template, { row = withRow }
			end, function()
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				local sight = handle:FindFirstChild(Hardware.SIGHT_NAME) :: Attachment
				expect(sight).to.be.ok()
				expect(sight.CFrame.Position).to.equal(measured)
				tool:Destroy()
			end)

			-- THE SAME ROW WITHOUT THE FIELD: the parts gun's bead, and the warning (which is once
			-- per server, so this case asserts the VALUE and not the warning's count).
			--
			-- BUILT WITHOUT IT RATHER THAN BORROWED FROM THE MANIFEST. The first version of this
			-- case passed the live row and expected the fallback, which was true only while no row
			-- carried a measurement -- and this task measured one an hour later, so the case failed
			-- on data rather than on behaviour. The fixture now says what it means.
			local withoutRow = table.clone(row) :: any
			withoutRow.sightOffsetStuds = nil
			withProvider(function()
				return template, { row = withoutRow }
			end, function()
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				local sight = handle:FindFirstChild(Hardware.SIGHT_NAME) :: Attachment
				expect(sight).to.be.ok()
				expect(sight.CFrame).to.equal(Shape.sight(CONFIG))
				tool:Destroy()
			end)
			template:Destroy()
		end)

		it("survives the upgrade, exactly once", function()
			local row = Assets.byKey(Hardware.ASSET_KEY)
			local template = Instance.new("MeshPart")
			template.Size = row.naturalSizeStuds
			local measured = Vector3.new(0, 0.29, -2.12)
			local withRow = table.clone(row) :: any
			withRow.sightOffsetStuds = measured

			-- built with no mesh (the parts gun, the parts-gun sight)...
			local tool
			withProvider(nil, function()
				tool = Hardware.build()
			end)
			local handle = (tool :: Tool):FindFirstChild("Handle") :: BasePart
			expect((handle:FindFirstChild(Hardware.SIGHT_NAME) :: Attachment).CFrame).to.equal(Shape.sight(CONFIG))

			-- ...and upgraded in place, which must move the sight and not add a second one.
			withProvider(function()
				return template, { row = withRow }
			end, function()
				expect(Hardware.upgrade(tool :: Tool)).to.equal(true)
			end)
			local sights = 0
			for _, child in ipairs(handle:GetChildren()) do
				if child.Name == Hardware.SIGHT_NAME then
					sights += 1
				end
			end
			expect(sights).to.equal(1)
			expect((handle:FindFirstChild(Hardware.SIGHT_NAME) :: Attachment).CFrame.Position).to.equal(measured);
			(tool :: Tool):Destroy()
			template:Destroy()
		end)

		it("bounds every measurement the manifest carries", function()
			-- Cheap, and it catches a typo without pretending to catch a wrong bead: only a
			-- screenshot can say whether a painted bead is where the row claims (design 9.3 item 5).
			local checked = 0
			for _, row in ipairs(Assets.ROWS) do
				local offset = (row :: any).sightOffsetStuds
				if typeof(offset) == "Vector3" then
					checked += 1
					-- IN THE HANDLE'S FRAME, WHICH `sizeStuds` IS NOT. The row's box is the mesh's
					-- own, before `rotationDeg` is applied -- for this gun (0, 90, 0) swaps its
					-- length onto Z -- so comparing the offset's Z against `sizeStuds.Z/2` compares
					-- a position along the barrels against the gun's WIDTH. It did, and this case
					-- failed on a measurement that was right (task 90, the third gate).
					local rotation = CFrame.Angles(
						math.rad(row.rotationDeg.X),
						math.rad(row.rotationDeg.Y),
						math.rad(row.rotationDeg.Z)
					)
					local size = row.sizeStuds
					local function extent(axis: Vector3): number
						return math.abs(axis.X * size.X) + math.abs(axis.Y * size.Y) + math.abs(axis.Z * size.Z)
					end
					local half = Vector3.new(
						extent(rotation.XVector),
						extent(rotation.YVector),
						extent(rotation.ZVector)
					) / 2
					-- inside the gun's own envelope along the barrels and across them...
					expect(math.abs(offset.Z) <= half.Z + 1e-3).to.equal(true)
					expect(math.abs(offset.X) <= half.X + 1e-3).to.equal(true)
					-- ...above the bore and no more than a bead's clearance above the mesh's own
					-- top, which is what "on the rib" means and what a typo would miss...
					expect(offset.Y >= 0.15).to.equal(true)
					expect(offset.Y <= half.Y + 0.05).to.equal(true)
					-- ...and at the muzzle end.
					expect(math.abs(offset.Z - Shape.muzzleZ(CONFIG)) <= 0.25).to.equal(true)
				end
			end
			TestKit.note(string.format("task90: %d manifest row(s) carry a sightOffsetStuds", checked))
		end)
	end)

	describe("the gun that was granted before the mesh landed", function()
		local function withProvider(fn, body)
			local live = Hardware.getTemplateProvider()
			Hardware.setTemplateProvider(fn)
			local ok, why = pcall(body)
			Hardware.setTemplateProvider(live)
			if not ok then
				error(why, 0)
			end
		end

		-- A template of the row's own natural size, so the size and pose the manifest describes are
		-- the ones the upgrade applies.
		local function fakeTemplate(): MeshPart
			local row = Assets.byKey(Hardware.ASSET_KEY)
			local template = Instance.new("MeshPart")
			template.Size = row.naturalSizeStuds
			return template
		end

		it("upgrades a tool built before the template arrived, exactly once", function()
			local row = Assets.byKey(Hardware.ASSET_KEY)
			local template = fakeTemplate()
			local asked = 0
			-- LATE: nil for the build, the template for every call after it.
			withProvider(function()
				asked += 1
				if asked == 1 then
					return nil, { reason = "not preloaded" }
				end
				return template, { row = row }
			end, function()
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				-- the defect, reproduced: this is the gun Karen was holding
				expect(Hardware.wearsMesh(tool)).to.equal(false)
				expect(handle:FindFirstChild("BarrelLeft")).to.be.ok()

				-- what the Handle carries before, so "nothing but the look changed" is a comparison
				local muzzle = handle:FindFirstChild("Muzzle")

				local upgraded = Hardware.upgrade(tool)
				TestKit.note(
					string.format(
						"task96 upgrade: returned %s, body=%s barrels=%s",
						tostring(upgraded),
						tostring(handle:FindFirstChild(Hardware.MODEL_NAME) ~= nil),
						tostring(handle:FindFirstChild(Hardware.BARRELS_NAME) ~= nil)
					)
				)
				expect(upgraded).to.equal(true)

				local model = handle:FindFirstChild(Hardware.MODEL_NAME) :: BasePart
				expect(model).to.be.ok()
				expect(model.Size).to.equal(row.sizeStuds)
				expect(model.CanQuery).to.equal(false)
				expect((handle:FindFirstChild("ModelWeld") :: Weld).Part1).to.equal(model)
				expect(Hardware.wearsMesh(tool)).to.equal(true)
				-- AND THE FALLBACK IS GONE: one gun in the hand, not two overlapping ones.
				expect(handle:FindFirstChild("BarrelLeft")).to.equal(nil)
				expect(handle:FindFirstChild("BarrelLeftWeld")).to.equal(nil)
				expect(handle:FindFirstChild("Stock")).to.equal(nil)
				expect(handle:FindFirstChild("Trigger")).to.equal(nil)
				-- NOTHING THE REST OF THE SYSTEM STANDS ON MOVED.
				expect(handle.Size).to.equal(CONFIG.HANDLE_SIZE)
				expect(tool.Grip).to.equal(CONFIG.GRIP)
				expect(handle.CanQuery).to.equal(true)
				expect(handle:FindFirstChild("Muzzle")).to.equal(muzzle) -- the SAME Attachment
				expect(Hardware.muzzlePosition(tool)).to.be.ok()

				-- EXACTLY ONCE. A second arrival, and the next sweep pass, find the mesh already
				-- there: no second `Model`, and the same Instance as before.
				expect(Hardware.upgrade(tool)).to.equal(false)
				expect(Hardware.upgrade(tool)).to.equal(false)
				local models = 0
				for _, child in ipairs(handle:GetChildren()) do
					if child.Name == Hardware.MODEL_NAME then
						models += 1
					end
				end
				expect(models).to.equal(1)
				expect(handle:FindFirstChild(Hardware.MODEL_NAME)).to.equal(model)
				tool:Destroy()
			end)
			template:Destroy()
		end)

		it("leaves the fallback alone when the template never arrives", function()
			withProvider(function()
				return nil, { reason = "timeout" }
			end, function()
				local tool = Hardware.build()
				local handle = tool:FindFirstChild("Handle") :: BasePart
				expect(Hardware.upgrade(tool)).to.equal(false)
				expect(Hardware.upgrade(tool)).to.equal(false)
				-- STILL THE WHOLE PARTS GUN. The mesh goes on before the parts come off, so a failed
				-- upgrade cannot leave a player holding an empty Handle.
				expect(Hardware.wearsMesh(tool)).to.equal(false)
				expect(handle:FindFirstChild("BarrelLeft")).to.be.ok()
				expect(handle:FindFirstChild("BarrelRight")).to.be.ok()
				expect(handle:FindFirstChild("Stock")).to.be.ok()
				expect(handle:FindFirstChild("Trigger")).to.be.ok()
				expect(Hardware.muzzlePosition(tool)).to.be.ok()
				tool:Destroy()
			end)
		end)

		it("refuses a Tool that has no Handle, rather than erroring in a sweep", function()
			local template = fakeTemplate()
			withProvider(function()
				return template, { row = Assets.byKey(Hardware.ASSET_KEY) }
			end, function()
				local bare = Instance.new("Tool")
				expect(Hardware.upgrade(bare)).to.equal(false)
				bare:Destroy()
			end)
			template:Destroy()
		end)

		-- THE PLAYER'S PATH, with the LIVE provider and no fake anywhere: whatever this server is
		-- actually holding. This is the assertion row 75a(h) failed.
		it("leaves no carried gun wearing the fallback once the mesh has loaded", function()
			local held, meshed = 0, 0
			for _, player in ipairs(Players:GetPlayers()) do
				for _, tool in Hardware.toolsOf(player) do
					held += 1
					if Hardware.wearsMesh(tool) then
						meshed += 1
					end
				end
			end
			local template = Loader.template(Hardware.ASSET_KEY)
			-- WHY `sweep upgrades` IS OFTEN 0 AND THAT IS NOT A DEFECT, measured while writing this:
			-- this file unwires the provider for the whole 11 s of the slow-load case above, which is
			-- most of the sweep passes that have happened by the time this runs. It is 0 as well
			-- whenever this server's player joined AFTER the preload and was handed the mesh gun
			-- outright -- which is the other thing the count distinguishes. `sweep failures` is what
			-- would say the sweep is broken; a silent pcall used to make those two look alike.
			--
			-- WHAT THE SWEEP ITSELF WOULD GET, asked the same way it asks.
			local provider = Hardware.getTemplateProvider()
			local answered = if provider then (provider(Hardware.ASSET_KEY)) ~= nil else false
			TestKit.note(
				string.format(
					"task76: %d carried gun(s), %d wearing the mesh, live template=%s, provider answers=%s, sweep upgrades=%d, sweep failures=%d, sweeps=%d",
					held,
					meshed,
					if template then "yes" else "no",
					if answered then "yes" else "no",
					Weapon.stats().meshUpgrades,
					Weapon.stats().meshUpgradeFails,
					Weapon.stats().armingSweeps
				)
			)
			-- THE SEAM IS STILL WIRED, and this is the assertion that caught the defect Task 76's
			-- second harness run failed on. Every case above borrows the provider and puts it back;
			-- one that captured its "live" value BEFORE `WeaponBoot` wired it put nil back instead,
			-- and a server with no provider builds the parts gun for every grant and cannot upgrade
			-- one either -- silently, for the rest of the session, including in any screenshot taken
			-- afterwards. It passed and failed on the same commit, which is what a race looks like.
			expect(Hardware.getTemplateProvider()).to.be.ok()
			if template == nil then
				-- No mesh in this server at all, so the fallback is the right answer and there is
				-- nothing to upgrade. Asserted rather than skipped, so this branch still says
				-- something: every carried gun wears the parts gun and none wears half a mesh.
				expect(meshed).to.equal(0)
				return
			end
			-- One sweep, by hand, so the assertion does not depend on when the 2 s one last ran.
			Hardware.upgradeAll()
			for _, player in ipairs(Players:GetPlayers()) do
				for _, tool in Hardware.toolsOf(player) do
					local handle = tool:FindFirstChild("Handle")
					TestKit.note(
						string.format(
							"task96 live gun: body=%s barrels=%s",
							tostring(handle and handle:FindFirstChild(Hardware.MODEL_NAME) ~= nil),
							tostring(handle and handle:FindFirstChild(Hardware.BARRELS_NAME) ~= nil)
						)
					)
					expect(Hardware.wearsMesh(tool)).to.equal(true)
				end
			end
		end)
	end)
end
