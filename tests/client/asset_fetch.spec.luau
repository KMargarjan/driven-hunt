--!strict
-- TASK 294. Karen, 2026-10-27, playing her build: "weapons loaded at first in game is rectangles".
--
-- A MeshPart whose mesh this client has not downloaded draws as its plain box, and nothing on a
-- client asks for a gun's meshes until something DRAWS one -- so the first gun of a COLD session was
-- drawn out of boxes. Two halves, both here: ONE shared fetch gate (`ReplicatedStorage.AssetFetch`,
-- the rule and the per-id cool-down task 244 built for the shop case, now the gun's too), and the
-- viewmodel's FIRST-SHOW HOLD, which draws no pieces at all rather than boxes until the meshes land
-- or the bound runs out.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local WeaponClient = require(scripts:WaitForChild("Weapon"))
local AssetFetch = require(ReplicatedStorage:WaitForChild("AssetFetch"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Display = require(scripts:WaitForChild("Hud"):WaitForChild("ShopDisplay"))

return function()
	describe("the shared mesh-fetch gate (task 294)", function()
		-- THE SEAM IS WHAT MAKES THIS PROVABLE AT ALL: a MeshPart cannot be given a mesh id in a
		-- test place, so the status and the ask are injected and the ids are plain strings.
		local statuses: { [string]: any } = {}
		local askedFor: { string } = {}
		local now = 100

		local function advance(seconds: number)
			now += seconds
		end

		beforeEach(function()
			statuses = {}
			askedFor = {}
			now = 100
			AssetFetch.reset()
			AssetFetch.setClock(function()
				return now
			end)
			AssetFetch.setStatus(function(id)
				-- DELEGATE FOR EVERY ID THIS CASE DOES NOT OWN. The live render loop reads the real
				-- gun's meshes four times a second through this same seam, so answering nil for them
				-- would start a hold on Karen's gun from inside a test.
				if statuses[id] ~= nil then
					return statuses[id]
				end
				return ContentProvider:GetAssetFetchStatus(id)
			end)
			AssetFetch.setAsk(function(holder)
				-- ONLY THIS CASE'S OWN HOLDERS: the live loop's asks are real MeshParts.
				if holder:IsA("Folder") then
					table.insert(askedFor, holder.Name)
				end
			end)
		end)

		afterEach(function()
			AssetFetch.setClock(nil)
			AssetFetch.setStatus(nil)
			AssetFetch.setAsk(nil)
			AssetFetch.reset()
		end)

		it("asks once for a mesh in flight, and never again for bytes already coming", function()
			local holder = Instance.new("Folder")
			holder.Name = "Barrels"
			statuses["rbxassetid://1"] = Enum.AssetFetchStatus.None
			-- NOBODY HAS ASKED YET, so the gate asks -- and says NOT READY, which is the whole
			-- point: the draw must not be handed a mesh it cannot show.
			expect(AssetFetch.readyId("rbxassetid://1", holder)).to.equal(false)
			expect(#askedFor).to.equal(1)
			expect(askedFor[1]).to.equal("Barrels")
			-- ...AND NOT FOUR TIMES A SECOND (task 244's own regression, kept): every caller
			-- re-asks on its own cadence, and `Loading` means the bytes are already on the way.
			statuses["rbxassetid://1"] = Enum.AssetFetchStatus.Loading
			for _ = 1, 20 do
				expect(AssetFetch.readyId("rbxassetid://1", holder)).to.equal(false)
			end
			expect(#askedFor).to.equal(1)
			expect(AssetFetch.stats().asks).to.equal(1)
			expect(AssetFetch.stats().retries).to.equal(0)
		end)

		it("asks again for a fetch the engine CALLED failed, once the cool-down has run out", function()
			local holder = Instance.new("Folder")
			holder.Name = "Model"
			statuses["rbxassetid://2"] = Enum.AssetFetchStatus.Failure
			expect(AssetFetch.readyId("rbxassetid://2", holder)).to.equal(false)
			expect(#askedFor).to.equal(1)
			advance(AssetFetch.RETRY_SECONDS - 0.01)
			expect(AssetFetch.readyId("rbxassetid://2", holder)).to.equal(false)
			expect(#askedFor).to.equal(1) -- still inside the cool-down
			advance(0.02)
			expect(AssetFetch.readyId("rbxassetid://2", holder)).to.equal(false)
			expect(#askedFor).to.equal(2)
			expect(AssetFetch.stats().retries).to.equal(1)
		end)

		it("is READY once the engine says Success, and stays ready for the session", function()
			local holder = Instance.new("Folder")
			statuses["rbxassetid://3"] = Enum.AssetFetchStatus.Success
			expect(AssetFetch.readyId("rbxassetid://3", holder)).to.equal(true)
			expect(#askedFor).to.equal(0)
			-- A FRESH CLONE ASKS FOR CONTENT THE CLIENT ALREADY HAS and reads `Loading` again for
			-- ~250 ms (the measurement in `Camera.Viewmodel`'s header). Downloaded is a one-way
			-- fact, so the gate must not take the gun back off the screen.
			statuses["rbxassetid://3"] = Enum.AssetFetchStatus.Loading
			expect(AssetFetch.readyId("rbxassetid://3", holder)).to.equal(true)
		end)

		it("answers READY when it cannot read the status at all", function()
			local holder = Instance.new("Folder")
			AssetFetch.setStatus(function()
				error("no ContentProvider")
			end)
			-- A GUARD THAT FAILED CLOSED WOULD SHIP THE BOXES TO EVERYBODY FOR EVER.
			expect(AssetFetch.readyId("rbxassetid://4", holder)).to.equal(true)
		end)

		it("is the rule the shop case drives, in one place", function()
			-- TASK 244 FOUND THIS RULE AND THE GUN HAD A SECOND, WEAKER COPY WITH NO COOL-DOWN.
			-- One owner now, so both doors are provably the same door.
			expect(Display.RETRY_SECONDS).to.equal(AssetFetch.RETRY_SECONDS)
			local S = Enum.AssetFetchStatus
			expect(Display.nextAsk(S.Success, false, nil, 100)).to.equal("ready")
			expect(AssetFetch.nextAsk(S.None, false, nil, 100)).to.equal("ask")
			expect(AssetFetch.nextAsk(S.Loading, true, 0, 1e6)).to.equal("wait")
			expect(AssetFetch.nextAsk(S.Failure, true, 100, 100)).to.equal("wait")
			expect(AssetFetch.nextAsk(S.Failure, true, 100, 100 + AssetFetch.RETRY_SECONDS)).to.equal("ask")
		end)

		it("walks a folder's MeshParts and nothing else when it warms", function()
			local folder = Instance.new("Folder")
			local plain = Instance.new("Part")
			plain.Parent = folder
			-- A MESHPART WITH NO MESH ID IS NOT AN ASK: there is nothing to fetch.
			local mesh = Instance.new("MeshPart")
			mesh.Parent = folder
			expect(AssetFetch.warm({ folder })).to.equal(0)
			expect(AssetFetch.stats().warms).to.equal(1)
			-- A PLAIN PART IS ALWAYS READY; a MeshPart with no id never is.
			expect(AssetFetch.ready(plain)).to.equal(true)
			expect(AssetFetch.ready(mesh)).to.equal(false)
		end)
	end)

	describe("the first-show hold (task 294)", function()
		-- THE FIXTURE IS `semiauto_client.spec`'s `withSemiAutoDrawn`, with its own discipline: a case
		-- that fails here must not leave every later frame of this session drawing somebody else's gun.
		local function withGunDrawn(body)
			local Viewmodel = Camera.Viewmodel
			local tool = Instance.new("Tool")
			tool.Name = "Shotgun"
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			handle.Parent = tool
			local liveSource = Viewmodel.getSource()
			local liveHands = Viewmodel.getHandTemplates()
			local fakes: { [string]: BasePart } = {}
			Viewmodel.setSource(function()
				return handle
			end)
			Viewmodel.setHandTemplates(function(name: string): BasePart?
				if fakes[name] == nil then
					local part = Instance.new("Part")
					part.Name = name .. "Template"
					part.Size = Vector3.new(1.28, 0.57, 0.53)
					fakes[name] = part
				end
				return fakes[name]
			end)
			local ok, why = pcall(function()
				Viewmodel.clear()
				Viewmodel.setReload(nil)
				Viewmodel.setLift(nil)
				task.wait(0.3) -- the source is asked four times a second, not per frame
				body(handle)
			end)
			Viewmodel.clear()
			Viewmodel.setSource(liveSource)
			Viewmodel.setHandTemplates(liveHands)
			Viewmodel.setClock(nil)
			Viewmodel.forgetHold()
			AssetFetch.setStatus(nil)
			AssetFetch.setAsk(nil)
			tool:Destroy()
			if not ok then
				error(why, 0)
			end
		end

		local firstPersonConfig = (function()
			local out = table.clone(Camera.Config) :: any
			out.FIRST_PERSON = true
			return table.freeze(out)
		end)()

		local function stateNow()
			local made = table.clone(Camera.Mode.initial(Camera.Config)) :: any
			made.blend = 0
			made.mode = "Third"
			return table.freeze(made)
		end

		-- HOW MANY PIECES OF THE DRAWN GUN A PLAYER CAN SEE. Karen's rectangles, as a number.
		local function visiblePieces(clone: Model): number
			local seen = 0
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "Handle" and part.Transparency < 1 then
					seen += 1
				end
			end
			return seen
		end

		it("the rule: it withholds while a mesh is downloading, and it is bounded", function()
			local Viewmodel = Camera.Viewmodel
			expect(Viewmodel.holdPieces(0, nil)).to.equal(false)
			expect(Viewmodel.holdPieces(0, 0)).to.equal(false)
			-- THE PRODUCTION-REACHABLE FORM FIRST (the Reviewer's note): `buildNewGun` always has a
			-- number, because it sets `since` to now when there is none.
			expect(Viewmodel.holdPieces(1, 0)).to.equal(true)
			expect(Viewmodel.holdPieces(1, nil)).to.equal(true)
			expect(Viewmodel.holdPieces(4, Viewmodel.HOLD_SECONDS - 0.01)).to.equal(true)
			-- BOUNDED: a mesh that never arrives gets the honest fallback, not an empty hand.
			expect(Viewmodel.holdPieces(1, Viewmodel.HOLD_SECONDS)).to.equal(false)
			expect(Viewmodel.holdPieces(4, 1e6)).to.equal(false)
			expect(Viewmodel.HOLD_SECONDS > 0).to.equal(true)
			expect(Viewmodel.HOLD_SECONDS <= 10).to.equal(true)
		end)

		it("DRAWS NOTHING A PLAYER CAN SEE while the gun's meshes are still downloading", function()
			local Viewmodel = Camera.Viewmodel
			-- THE FOLDER THE SERVER PUBLISHED, and the ids this case holds back: the cold client, in
			-- a Studio whose cache is warm. Without the folder there is no mesh to wait for and the
			-- case says so rather than passing quietly.
			local folder = ReplicatedStorage:FindFirstChild(Gun.FOLDER_NAME)
			expect(folder).to.be.ok()
			local held: { [string]: boolean } = {}
			local ids = 0
			for _, child in ipairs((folder :: Instance):GetChildren()) do
				if child:IsA("MeshPart") and child.MeshId ~= "" then
					held[child.MeshId] = true
					ids += 1
				end
			end
			expect(ids > 0).to.equal(true)
			TestKit.note(string.format("task294 holding %d mesh id(s) of %s back", ids, Gun.FOLDER_NAME))

			withGunDrawn(function()
				local clockNow = 1000
				AssetFetch.reset()
				AssetFetch.setAsk(function() end) -- no network from a test
				AssetFetch.setStatus(function(id)
					if held[id] then
						return Enum.AssetFetchStatus.Loading
					end
					return ContentProvider:GetAssetFetchStatus(id)
				end)
				Viewmodel.setClock(function()
					return clockNow
				end)
				Viewmodel.forgetHold()
				Viewmodel.clear()
				Viewmodel.update(CFrame.new(0, 12, 0), stateNow(), firstPersonConfig)
				local clone = Viewmodel.current() :: Model
				expect(clone).to.be.ok()
				-- THE GUN IS BUILT -- every piece is there to be read by name...
				expect(#clone:GetDescendants() > 2).to.equal(true)
				expect(Viewmodel.holding()).to.equal(true)
				expect(Viewmodel.stats().meshesHeld > 0).to.equal(true)
				-- ...AND NOT ONE PIECE OF IT IS VISIBLE. This is Karen's sentence as a number: the
				-- boxes are what she called rectangles. TO SEE IT FAIL: drop the `if held then 1`
				-- from `buildNewGun`'s fallback branch.
				expect(visiblePieces(clone)).to.equal(0)

				-- PAST THE BOUND: the honest fallback. The gun comes back as boxes rather than
				-- staying an empty hand for the session.
				clockNow += Viewmodel.HOLD_SECONDS + 0.1
				Viewmodel.clear()
				Viewmodel.update(CFrame.new(0, 12, 0), stateNow(), firstPersonConfig)
				local after = Viewmodel.current() :: Model
				expect(Viewmodel.holding()).to.equal(false)
				expect(Viewmodel.stats().meshesHeld).to.equal(0)
				expect(visiblePieces(after) > 0).to.equal(true)
				TestKit.note(string.format("task294 held=0 visible, after the bound=%d visible", visiblePieces(after)))
			end)
		end)
	end)

	describe("asking early (task 294)", function()
		it("ASKS THE ENGINE for every weapon folder that has replicated", function()
			-- A PLAYER WHO HAS ONLY EVER CARRIED THE SHOTGUN HAS NEVER ASKED for the rifle's meshes,
			-- so their status is `None` until something asks -- and until this task the first thing
			-- that asked was the DRAW, as Karen looked at it.
			-- EVERY ID ANYTHING ASKED FOR, AND HOW OFTEN. The live render loop shares this door, so
			-- the claims below are a SET and a no-duplicates rule rather than a call count: a frame
			-- landing mid-case must not be able to make this red or green by accident.
			local askedIds: { [string]: number } = {}
			AssetFetch.reset()
			AssetFetch.setAsk(function(holder)
				if holder:IsA("MeshPart") then
					local id = (holder :: MeshPart).MeshId
					askedIds[id] = (askedIds[id] or 0) + 1
				end
			end)
			local ok, why = pcall(function()
				-- WHICH FOLDERS ARE THERE TO ASK FOR, counted first: the claim is about every one of
				-- them, so a session where nothing has replicated must fail rather than pass on an
				-- empty sweep.
				local wanted: { [string]: number } = {}
				local meshes = 0
				for id in pairs(Weapons.ROWS) do
					local geometry = Weapons.geometry(id)
					expect(type(geometry.FOLDER_NAME)).to.equal("string")
					local folder = ReplicatedStorage:FindFirstChild(geometry.FOLDER_NAME)
					if folder ~= nil then
						for _, child in ipairs(folder:GetChildren()) do
							if child:IsA("MeshPart") and child.MeshId ~= "" then
								wanted[child.MeshId] = (wanted[child.MeshId] or 0) + 1
								meshes += 1
							end
						end
					end
				end
				expect(meshes > 0).to.equal(true)

				-- THE SWEEP ASKS FOR THEM ALL, IN ONE CALL. TO SEE IT FAIL: replace
				-- `Weapon.warmWeapons`'s loop over `Weapons.ROWS` with `return AssetFetch.warm({})`,
				-- or drop the `AssetFetch.warm(holders)` line -- `asks` is then 0 and so is coverage.
				local asks = WeaponClient.warmWeapons()
				expect(asks > 0).to.equal(true)
				-- EVERY MESH OF EVERY WEAPON THAT HAS REPLICATED was asked for, not just the one in
				-- the hand: this is the whole claim, as a set.
				for id in pairs(wanted) do
					expect((askedIds[id] or 0) >= 1).to.equal(true)
				end
				TestKit.note(string.format("task294 warm asked for %d weapon mesh(es) of %d", asks, meshes))

				-- ...AND NEVER TWICE FOR THE SAME BYTES: the sweep runs every second for 30 tries,
				-- so a second ask per id per sweep would be 30 requests for bytes already coming.
				expect(WeaponClient.warmWeapons()).to.equal(0)
				local twice = 0
				for _, times in pairs(askedIds) do
					if times > 1 then
						twice += 1
					end
				end
				expect(twice).to.equal(0)
				expect(WeaponClient.WARM_TRIES > 1).to.equal(true)
				expect(WeaponClient.WARM_SECONDS > 0).to.equal(true)
			end)
			AssetFetch.setAsk(nil)
			AssetFetch.reset()
			assert(ok, tostring(why))
		end)
	end)
end
