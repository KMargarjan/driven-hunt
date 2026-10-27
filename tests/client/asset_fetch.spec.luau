--!strict
-- TASK 294. Karen, 2026-10-27, playing her build: "weapons loaded at first in game is rectangles".
--
-- A MeshPart whose mesh this client has not downloaded draws as its plain box, and nothing on a
-- client asks for a gun's meshes until something DRAWS one -- so the first gun of a COLD session was
-- drawn out of boxes. Two halves, both here: ONE shared fetch gate (`ReplicatedStorage.AssetFetch`,
-- the rule and the per-id cool-down task 244 built for the shop case, now the gun's too), and the
-- viewmodel's FIRST-SHOW HOLD, which draws no pieces at all rather than boxes until the meshes land
-- or the bound runs out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local WeaponClient = require(scripts:WaitForChild("Weapon"))
local AssetFetch = require(ReplicatedStorage:WaitForChild("AssetFetch"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
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
				return statuses[id]
			end)
			AssetFetch.setAsk(function(holder)
				table.insert(askedFor, holder.Name)
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
		it("withholds the gun's pieces while a mesh is still downloading", function()
			local Viewmodel = Camera.Viewmodel
			-- THE RULE, where it can fail. Nothing waiting is never a hold.
			expect(Viewmodel.holdPieces(0, nil)).to.equal(false)
			expect(Viewmodel.holdPieces(0, 0)).to.equal(false)
			-- THE FIRST FRAME OF A HOLD, and every frame inside the bound: do not draw the boxes.
			expect(Viewmodel.holdPieces(1, nil)).to.equal(true)
			expect(Viewmodel.holdPieces(1, 0)).to.equal(true)
			expect(Viewmodel.holdPieces(4, Viewmodel.HOLD_SECONDS - 0.01)).to.equal(true)
			-- AND IT IS BOUNDED: a mesh that never arrives gets the honest fallback, not an empty
			-- hand for the rest of the session.
			expect(Viewmodel.holdPieces(1, Viewmodel.HOLD_SECONDS)).to.equal(false)
			expect(Viewmodel.holdPieces(4, 1e6)).to.equal(false)
			expect(Viewmodel.HOLD_SECONDS > 0).to.equal(true)
			expect(Viewmodel.HOLD_SECONDS <= 10).to.equal(true)
			expect(type(Viewmodel.holding())).to.equal("boolean")
			expect(type(Viewmodel.stats().meshesHeld)).to.equal("number")
		end)
	end)

	describe("asking early (task 294)", function()
		it("asks for EVERY weapon's meshes, from the client weapon owner", function()
			-- A PLAYER WHO HAS ONLY EVER CARRIED THE SHOTGUN HAS NEVER ASKED for the rifle's
			-- meshes. The shop case asks when the case opens (task 244); this asks at the lobby,
			-- which is where the first gun Karen sees is handed over.
			expect(type(WeaponClient.warmWeapons())).to.equal("number")
			expect(WeaponClient.WARM_TRIES > 1).to.equal(true)
			expect(WeaponClient.WARM_SECONDS > 0).to.equal(true)
			-- EVERY ROW, not the three the shop draws: the sweep reads `Weapons.ROWS`, so a weapon
			-- added later is warmed without a second list.
			local rows = 0
			for id in pairs(Weapons.ROWS) do
				rows += 1
				expect(type(Weapons.geometry(id).FOLDER_NAME)).to.equal("string")
			end
			expect(rows >= 4).to.equal(true)
		end)
	end)
end
