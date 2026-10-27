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
		--
		-- THE GUN'S OWN PIECE LIST AND NOTHING ELSE: the Handle and the hinge group are envelopes
		-- (Transparency 1 by construction) and the GLOVES are not the gun -- counting those read 2
		-- visible on a held gun and said nothing about a box.
		local function visiblePieces(clone: Model): number
			local seen = 0
			for _, piece in ipairs(Gun.pieces(Shotgun.CONFIG)) do
				local part = clone:FindFirstChild(piece.name, true)
				if part ~= nil and part:IsA("BasePart") and (part :: BasePart).Transparency < 1 then
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
			-- THE TEMPLATES ARE FABRICATED, for `semiauto_client.spec`'s own reason: the real ones
			-- are uploaded meshes a Studio with no network may not have, so the waiting state must be
			-- reached on purpose rather than on a good day. A `MeshPart` with no mesh id is EXACTLY
			-- the state this gate exists for -- `AssetFetch.ready` answers false for it -- so no
			-- status seam is needed and the rule being proved is the build's, not the engine's.
			local folder = ReplicatedStorage:FindFirstChild(Gun.FOLDER_NAME)
			local made: { Instance } = {}
			if folder == nil then
				local created = Instance.new("Folder")
				created.Name = Gun.FOLDER_NAME
				created.Parent = ReplicatedStorage
				table.insert(made, created)
				folder = created
			end
			local names = 0
			for _, piece in ipairs(Gun.pieces(Shotgun.CONFIG)) do
				if piece.meshKey ~= nil then
					names += 1
					if (folder :: Instance):FindFirstChild(piece.name) == nil then
						local mesh = Instance.new("MeshPart")
						mesh.Name = piece.name
						mesh.Parent = folder
						table.insert(made, mesh)
					end
				end
			end
			expect(names > 0).to.equal(true)
			TestKit.note(string.format("task294 hold case: %d mesh piece(s), %d fabricated", names, #made))

			-- THE DOWNLOAD IS HELD BACK AT THE GATE'S OWN SEAM, so this case proves the same rule in
			-- every place. Measured at 70b2a718: where the server HAS published the folder the pieces
			-- read Success, `waiting` is 0 and the hold never fires -- "2 mesh piece(s), 0 fabricated
			-- ... waiting=0 held=0 holding=false visible=3", red on both clients of the two-player run.
			-- `reset()` is needed because `arrived` short-circuits `readyId` ahead of the status; both
			-- it and the two seams are restored below.
			AssetFetch.reset()
			AssetFetch.setAsk(function() end) -- no PreloadAsync: nothing is really downloading here
			AssetFetch.setStatus(function()
				return Enum.AssetFetchStatus.Loading
			end)

			local ok, why = pcall(function()
				withGunDrawn(function()
					local clockNow = 1000
					Viewmodel.setClock(function()
						return clockNow
					end)
					Viewmodel.forgetHold()
					Viewmodel.clear()
					Viewmodel.update(CFrame.new(0, 12, 0), stateNow(), firstPersonConfig)
					local clone = Viewmodel.current() :: Model
					expect(clone).to.be.ok()
					-- THE GUN IS BUILT -- every piece is there for everything downstream to read by
					-- name (dropping them left `semiauto_client.spec` with no bolt)...
					expect(#clone:GetDescendants() > 2).to.equal(true)
					-- EVERY COUNTER THE VERDICT RESTS ON, printed BEFORE the first assertion that
					-- can end the case, so a red run says WHY and not only that it was red.
					TestKit.note(
						string.format(
							"task294 hold counters: waiting=%d held=%d holding=%s visible=%d",
							Viewmodel.stats().meshesWaiting,
							Viewmodel.stats().meshesHeld,
							tostring(Viewmodel.holding()),
							visiblePieces(clone)
						)
					)
					expect(Viewmodel.holding()).to.equal(true)
					expect(Viewmodel.stats().meshesHeld > 0).to.equal(true)
					-- ...AND NOT ONE PIECE OF IT IS VISIBLE. This is Karen's sentence as a number.
					-- TO SEE IT FAIL: drop the `if held then 1` from `buildNewGun`'s fallback branch.
					expect(visiblePieces(clone)).to.equal(0)

					-- PAST THE BOUND: the honest fallback. The gun comes back as boxes rather than
					-- staying an empty hand for the session.
					clockNow += Viewmodel.HOLD_SECONDS + 0.1
					Viewmodel.clear()
					Viewmodel.update(CFrame.new(0, 12, 0), stateNow(), firstPersonConfig)
					local after = Viewmodel.current() :: Model
					expect(Viewmodel.holding()).to.equal(false)
					expect(Viewmodel.stats().meshesHeld).to.equal(0)
					local seen = visiblePieces(after)
					expect(seen > 0).to.equal(true)
					TestKit.note(string.format("task294 held: 0 visible; past the bound: %d visible", seen))
				end)
			end)
			-- ONLY WHAT THIS CASE MADE, and before the verdict: a template left behind would change
			-- what every later frame of this session draws.
			AssetFetch.setStatus(nil)
			AssetFetch.setAsk(nil)
			-- AND PUT BACK WHAT `reset()` CLEARED, through the gate's own reader: `arrived` is the
			-- one-way "this client has the bytes" fact, so a later spec that draws a gun must not be
			-- pushed into the hold by this case's bookkeeping.
			for _, part in ipairs((folder :: Instance):GetDescendants()) do
				if part:IsA("MeshPart") then
					AssetFetch.ready(part)
				end
			end
			for _, instance in ipairs(made) do
				instance:Destroy()
			end
			assert(ok, tostring(why))
		end)
	end)

	describe("asking early (task 294)", function()
		it("ASKS THE ENGINE for every mesh it is handed, once", function()
			-- REAL MESH IDS, in any place and with no upload: an R15 avatar's body is MeshParts.
			-- `warm` is what the lobby sweep and the shop case both call, and this is the whole of
			-- its promise -- walk, ask, remember.
			local character = player.Character or player.CharacterAdded:Wait()
			local wanted: { [string]: boolean } = {}
			local ids = 0
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("MeshPart") and (part :: MeshPart).MeshId ~= "" then
					if not wanted[(part :: MeshPart).MeshId] then
						wanted[(part :: MeshPart).MeshId] = true
						ids += 1
					end
				end
			end
			expect(ids > 0).to.equal(true)

			local askedIds: { [string]: number } = {}
			AssetFetch.reset()
			AssetFetch.setAsk(function(holder)
				if holder:IsA("MeshPart") then
					local id = (holder :: MeshPart).MeshId
					askedIds[id] = (askedIds[id] or 0) + 1
				end
			end)
			local ok, why = pcall(function()
				-- TO SEE IT FAIL: delete the `request(id, part)` line in `AssetFetch.warm`.
				expect(AssetFetch.warm({ character })).to.equal(ids)
				for id in pairs(wanted) do
					expect(askedIds[id]).to.equal(1)
				end
				-- ...AND NEVER TWICE FOR THE SAME BYTES: the lobby sweep runs every second for 30
				-- tries, so a second ask per id per sweep would be 30 requests for bytes in flight.
				expect(AssetFetch.warm({ character })).to.equal(0)
				for id in pairs(wanted) do
					expect(askedIds[id]).to.equal(1)
				end
			end)
			AssetFetch.setAsk(nil)
			AssetFetch.reset()
			assert(ok, tostring(why))
			TestKit.note(string.format("task294 warm asked for %d avatar mesh id(s), once each", ids))
		end)

		it("hands AssetFetch EVERY weapon folder that has replicated, from the lobby", function()
			-- A PLAYER WHO HAS ONLY EVER CARRIED THE SHOTGUN HAS NEVER ASKED for the rifle's meshes,
			-- so their status is `None` until something asks -- and until this task the first thing
			-- that asked was the DRAW, as Karen looked at it. The sweep reads `Weapons.ROWS`, so this
			-- is the list it is checked against. TO SEE IT FAIL: replace `Weapon.warmWeapons`'s loop
			-- with `return AssetFetch.warm({})`.
			local expected: { [string]: boolean } = {}
			local folders = 0
			for id in pairs(Weapons.ROWS) do
				local geometry = Weapons.geometry(id)
				expect(type(geometry.FOLDER_NAME)).to.equal("string")
				if ReplicatedStorage:FindFirstChild(geometry.FOLDER_NAME) ~= nil then
					expected[geometry.FOLDER_NAME] = true
					folders += 1
				end
			end

			-- AND THERE IS ALWAYS AT LEAST ONE TO HAND OVER, so this cannot pass on an empty sweep
			-- (the Reviewer's round-1 finding, in the one place it could come back): a DEV place with
			-- no uploaded weapon gets one fabricated folder, destroyed below.
			local temporary: Instance? = nil
			if folders == 0 then
				local created = Instance.new("Folder")
				created.Name = Gun.FOLDER_NAME
				created.Parent = ReplicatedStorage
				temporary = created
				expected[created.Name] = true
				folders = 1
			end

			-- THE SPY IS THE MODULE'S OWN FUNCTION, swapped back whatever happens: what is being
			-- proved is which holders the client weapon owner hands over, not what `warm` does with
			-- them (the case above proves that half).
			local realWarm = AssetFetch.warm
			local handed: { [string]: boolean } = {}
			local calls = 0
			local fromTheSweep = 0
			-- ONLY THIS CASE'S OWN CALL IS COUNTED (the Reviewer of 294): `Weapon.start`'s sweep calls
			-- `warmWeapons()` once a second for 30 tries, so a sweep landing inside this window used
			-- to make `calls` read 2. `warm` is called SYNCHRONOUSLY, so our call is always on this
			-- coroutine and the sweep's is always on the `task.spawn` thread: the race is closed by
			-- identity, not by a timing window.
			local mine = coroutine.running()
			AssetFetch.warm = function(holders)
				if coroutine.running() ~= mine then
					fromTheSweep += 1
					return realWarm(holders) -- the live sweep keeps working through the spy
				end
				calls += 1
				for _, holder in ipairs(holders) do
					handed[holder.Name] = true
				end
				return 0
			end
			local ok, why = pcall(function()
				expect(WeaponClient.warmWeapons()).to.equal(0) -- the spy's answer, passed straight out
			end)
			AssetFetch.warm = realWarm
			if temporary ~= nil then
				(temporary :: Instance):Destroy()
			end
			assert(ok, tostring(why))

			expect(folders > 0).to.equal(true)
			expect(calls).to.equal(1) -- one sweep, one call: not one per weapon
			TestKit.note(
				string.format("task294 warm calls: %d from this case, %d from the live sweep", calls, fromTheSweep)
			)
			local count = 0
			for name in pairs(handed) do
				-- NOTHING BUT A WEAPON'S OWN FOLDER: a sweep that handed over the hands folder or
				-- the whole of ReplicatedStorage would pass a "> 0" claim and fail this one.
				expect(expected[name]).to.equal(true)
				count += 1
			end
			expect(count).to.equal(folders)
			expect(WeaponClient.WARM_TRIES > 1).to.equal(true)
			expect(WeaponClient.WARM_SECONDS > 0).to.equal(true)
			TestKit.note(string.format("task294 the lobby sweep handed over %d weapon folder(s)", count))
		end)

		it("IS REALLY STARTED by Weapon.start, so a cold client asks before anything draws", function()
			-- NOTHING ASSERTED THE SWEEP IS EVER RUN (the Reviewer of 294): every case above calls
			-- `warmWeapons()` itself, and `Weapon.start`'s `started` guard means it cannot be
			-- re-entered. So the proof is the LIVE thread: a call to `AssetFetch.warm` from a
			-- coroutine that is not this one can only come from that `task.spawn` block.
			-- TO SEE IT FAIL: delete the `task.spawn` block in `Weapon.start`.
			local window = WeaponClient.WARM_TRIES * WeaponClient.WARM_SECONDS
			-- The observation is only possible while the sweep is still running, so say so as an
			-- assertion rather than letting a late session read as a deleted sweep.
			expect(time() < window).to.equal(true)

			local realWarm = AssetFetch.warm
			local mine = coroutine.running()
			local fromTheSweep = 0
			AssetFetch.warm = function(holders)
				if coroutine.running() ~= mine then
					fromTheSweep += 1
				end
				return realWarm(holders)
			end
			local waited = os.clock()
			local ok, why = pcall(function()
				local deadline = os.clock() + WeaponClient.WARM_SECONDS * 3
				while fromTheSweep == 0 and os.clock() < deadline do
					task.wait(0.1)
				end
			end)
			AssetFetch.warm = realWarm
			local took = os.clock() - waited
			assert(ok, tostring(why))
			TestKit.note(
				string.format(
					"task294 the sweep's own thread called warm %d time(s) in %.1fs, %.1fs into a %ds window",
					fromTheSweep,
					took,
					time(),
					window
				)
			)
			expect(fromTheSweep > 0).to.equal(true)
		end)
	end)
end
