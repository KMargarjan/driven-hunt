-- lobby_live.spec: THE OWNER, DRIVEN BY HAND AGAINST FAKES -- fake occupants with real root parts,
-- a fake terrain, a fake ground reader, and the drive's four seams replaced by recorders. No Play of
-- its own, no frames hunted, no character service and no drive.
--
-- WHY IT CAN START THE SINGLETON AT ALL, which is the opposite of `bots_live.spec`'s rule: the lobby
-- is only ever started by `ForestTestBoot`, and that file returns immediately in the DEV place --
-- which is the only place the harness runs (`[harness] FAIL Studio has the DEV place open` is a real
-- check). So here `ServerScriptService.Lobby` is an unstarted module, and each case starts it with
-- its own fakes and stops it again. `Lobby.stop()` on an unstarted owner is a no-op, which is what
-- makes the first line of `fresh` safe.
--
-- EVERY SEAM IS A FAKE, AND THAT IS THE POINT OF THEM BEING SEAMS (docs/design/lobby.md 12.2): the
-- lobby writes no roster, no team and no character position, so a spec can watch exactly what it
-- ASKS for -- which is the owner-boundary claim, stated as counts.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/lobby.md (section 16.1)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
local Lobby = require(ServerScriptService:WaitForChild("Lobby"))

local Pads = Lobby.Pads

local CFG = Data.CONFIG
local ANCHOR = Data.anchorFor("forest-test") :: any
local SHELF = 153

-- WHERE PAD n IS IN THIS SPEC'S WORLD, through the ONE function that knows (task 182) -- so a retune
-- of `SIZE` or `PAD_BEHIND_STUDS` moves the spec's occupants with the slabs instead of leaving them
-- standing in the gap.
local function padAt(index: number): Vector3
	return Pads.centreFor(Vector3.new(ANCHOR.x, SHELF, ANCHOR.z), index, CFG)
end

-- HOW LONG FROM STEPPING ON AN EMPTY PAD TO THE PARTY LEAVING, with no pick at all: the pick
-- timeout, then the countdown, plus a scan of slack for each edge because `Pads.step` applies ONE
-- transition per call.
local SOLO_SECONDS = CFG.PADS.PICK_TIMEOUT_SECONDS + CFG.COUNTDOWN_SECONDS + 3 / CFG.SCAN_HZ

-- A PLAYER-SHAPED THING with a root part and the two methods the lobby touches. It is NOT a Player:
-- the lobby keys by `UserId` and only ever reads `Character.PrimaryPart`, sets one attribute and
-- writes `RespawnLocation`, so a table with those four is the whole surface.
local function occupant(userId: number, at: Vector3?, bin: Instance)
	local model = Instance.new("Model")
	model.Name = string.format("Occupant%d", userId)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = true
	root.CanCollide = false
	root.Position = at or Vector3.new(0, 0, 0)
	root.Parent = model
	model.PrimaryPart = root
	model.Parent = bin
	local attributes: { [string]: any } = {}
	return {
		UserId = userId,
		Name = string.format("Occupant%d", userId),
		Character = if at == nil then nil else model,
		RespawnLocation = nil :: any,
		root = root,
		attributes = attributes,
		GetAttribute = function(self, name: string)
			return self.attributes[name]
		end,
		SetAttribute = function(self, name: string, value: any)
			self.attributes[name] = value
		end,
	}
end

-- THE DRIVE'S FOUR SEAMS, AS RECORDERS, plus the ground and the terrain. `inDrive` and `isHeld`
-- answer from sets a case can write, which is what lets the results-scene case be stated at all.
local function fakes(bin: Instance)
	local seen = {
		enrolled = {} :: { number },
		dismissed = 0,
		placed = {} :: { { userId: number, cframe: CFrame } },
		fills = 0,
		scrubs = 0,
		inDrive = {} :: { [number]: boolean },
		held = {} :: { [number]: boolean },
		ground = SHELF :: any,
		dressed = 0,
		-- TASK 229: who the DRIVE has given a side to (the reset's fact), and who OWNS
		-- `ALWAYS HUNTER` (the gate on the whole feature). Both are sets a case writes.
		assigned = {} :: { [number]: string },
		owners = {} :: { [number]: boolean },
		-- TASK 287: who a LIVE drive let go of, which is the owner's `withdrawnFrom`. A case writes
		-- it beside `inDrive[id] = false`, because those are the two halves of one event.
		withdrawn = {} :: { [number]: boolean },
	}
	return seen,
		{
			enabled = true,
			world = "forest-test",
			root = bin,
			-- IT MAKES HIM A PARTICIPANT, which is what `Match.enrol` does inside the same call:
			-- `dispatch({ kind = "join" })` is synchronous, so `Match.isParticipant` answers true the
			-- instant `enrol` returns. A fake that recorded the call and left `inDrive` false made
			-- the lobby hand a man it had just enrolled a lodge respawn again on the SAME scan --
			-- which is not what production does, so it was a defect in the FAKE and not in the owner
			-- (task 182, found by the case below).
			enrol = function(player: any): boolean
				table.insert(seen.enrolled, player.UserId)
				seen.inDrive[player.UserId] = true
				-- ...AND EVERY BAR IS LIFTED, which is what the owner does and not a convenience
				-- (task 287): a man enrolled into an empty drive RESTARTS it, the drive number moves,
				-- and `Phase.barredFromRejoin` is then false for everybody the OLD drive let go of
				-- (`dispatch` clears `withdrawnFrom` on that edge). A fake that kept them barred would
				-- claim this owner locks a second withdrawn man off the pads for a whole fresh drive,
				-- which is review round 1's finding 3 and is exactly what was fixed.
				table.clear(seen.withdrawn)
				return true
			end,
			dismissAll = function(): number
				seen.dismissed += 1
				return 1
			end,
			inDrive = function(userId: number): boolean
				return seen.inDrive[userId] == true
			end,
			isHeld = function(userId: number): boolean
				return seen.held[userId] == true
			end,
			-- WOULD THE DRIVE'S DOOR REFUSE HIM (task 287)? THE REAL RULE, written out of the two
			-- facts `Match.enrolRefused` is written out of: the drive let go of him
			-- (`seen.withdrawn`, which is the owner's `withdrawnFrom`) AND somebody is still in it
			-- (`seen.inDrive`, so there is nothing to restart). A stub that answered a constant would
			-- let the two cases below share one branch, and they are two branches: a man ALONE gets a
			-- door, a man with other men still hunting gets a notice.
			enrolRefused = function(userId: number): boolean
				if seen.withdrawn[userId] ~= true or seen.inDrive[userId] == true then
					return false
				end
				for _, inside in pairs(seen.inDrive) do
					if inside then
						return true
					end
				end
				return false
			end,
			place = function(player: any, cframe: CFrame)
				table.insert(seen.placed, { userId = player.UserId, cframe = cframe })
			end,
			groundAt = function(): number?
				return seen.ground
			end,
			-- THE SHOPKEEPER'S BODY, FAKED (task 181). The owner's default is
			-- `Players:CreateHumanoidModelFromDescription`, which reaches the avatar service and may
			-- yield; this hands in four parts and a Humanoid instead, so this spec proves the WIRING
			-- -- a man is built, he is turned, he is counted -- with no web call anywhere in it.
			rig = function(): Model?
				local model = Instance.new("Model")
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Size = Vector3.new(2, 2, 1)
				root.Parent = model
				for _, name in ipairs({ "Head", "UpperTorso", "LeftHand" }) do
					local limb = Instance.new("Part")
					limb.Name = name
					limb.Parent = model
				end
				local humanoid = Instance.new("Humanoid")
				humanoid.Parent = model
				model.PrimaryPart = root
				return model
			end,
			dress = function(): boolean
				seen.dressed += 1
				return true
			end,
			dressConfig = { fake = true },
			-- WHICH SIDE THE DRIVE HAS GIVEN HIM (task 229), from a set a case can write -- which is
			-- what lets the reset be stated at all, and lets it be told apart from `inDrive`.
			assignedTeam = function(userId: number): string?
				return seen.assigned[userId]
			end,
			terrain = {
				FillBlock = function()
					seen.fills += 1
				end,
				-- TASK 244: `Field.fill` scrubs each pad's own rectangle back to its own material
				-- after the air cut (`Terrain:ReplaceMaterial`), and it calls it UNGUARDED for the
				-- reason it calls `FillBlock` unguarded -- so this stand-in answers the whole
				-- contract or the lobby cannot build at all.
				ReplaceMaterial = function()
					seen.scrubs += 1
				end,
			},
			now = os.clock,
		}
end

return function()
	local bin: Instance

	beforeEach(function()
		bin = Instance.new("Folder")
		bin.Name = "LobbyLiveSpecWorld"
		-- WORKSPACE, which Rojo does not own: a folder in a Rojo-owned container is deleted at the
		-- next Connect. Destroyed in `afterEach` either way.
		bin.Parent = Workspace
	end)

	afterEach(function()
		Lobby.stop()
		bin:Destroy()
	end)

	local function fresh(bin_: Instance, patch: ((any) -> ())?)
		Lobby.stop()
		local seen, world = fakes(bin_)
		if patch then
			patch(world)
		end
		local on = Lobby.start(world)
		return seen, on
	end

	describe("the switch", function()
		it("builds nothing when it is off, and writes no terrain", function()
			-- CLAUDE.md's reachability condition: the OFF branch is driven by PARAMETER while the flag
			-- row itself sits at `false`, so both states are provable from one commit.
			local seen, on = fresh(bin, function(world)
				world.enabled = false
			end)
			expect(on).to.equal(false)
			expect(Lobby.isBuilt()).to.equal(false)
			expect(seen.fills).to.equal(0)
		end)

		it("builds nothing in a world with no anchor row", function()
			local _seen, on = fresh(bin, function(world)
				world.world = "map:v1"
			end)
			expect(on).to.equal(false)
			expect(Lobby.isBuilt()).to.equal(false)
		end)

		it("refuses a start with a door missing, rather than half-building", function()
			-- `ForestTestBoot` asks the lobby whether it exists and only THEN takes the drive's own
			-- enrolment away -- so this combination cannot ship silently.
			-- `isHeld` JOINED THE LIST IN ROUND 2 (review note 6): it is the one thing stopping the
			-- lobby respawning a man out of Karen's results scene, so a boot that forgets it must be
			-- refused rather than silently answering "nobody is held".
			for _, name in ipairs({ "enrol", "dismissAll", "inDrive", "isHeld", "place", "groundAt" }) do
				local _seen, on = fresh(bin, function(world)
					world[name] = nil
				end)
				expect(on).to.equal(false)
				expect(Lobby.isBuilt()).to.equal(false)
			end
		end)
	end)

	describe("the build", function()
		it("measures the shelf rather than typing it, and fills the terrain through the argument", function()
			local seen, on = fresh(bin)
			expect(on).to.equal(true)
			Lobby.step(1000, {})
			expect(Lobby.isBuilt()).to.equal(true)
			local stats = Lobby.stats()
			-- MEASURED: the Y is the world's own ground reader's answer, printed by the boot so it is
			-- a number in the console and not a belief.
			expect(stats.shelfY).to.equal(SHELF)
			expect(stats.parts > 50).to.equal(true)
			expect(stats.parts <= CFG.MAX_PARTS).to.equal(true)
			expect(seen.fills > 0).to.equal(true)
			expect(stats.fillCalls).to.equal(seen.fills)
			expect(bin:FindFirstChild(Data.FOLDER_NAME)).to.be.ok()
		end)

		-- THE SHOPKEEPER (task 181). Karen: *"in lobby has to be a person bot who you need to click E
		-- to get access to shop"*. He is built by `Build` and WIRED here: the owner is what supplies
		-- the body and the clothes, and what decides who he turns to on the scan it already runs.
		it("stands a dressed shopkeeper at the counter, through the two injected seams", function()
			local seen, on = fresh(bin)
			expect(on).to.equal(true)
			Lobby.step(1000, {})
			local stats = Lobby.stats()
			expect(stats.keepers).to.equal(1)
			expect(stats.keeperDressed).to.equal(1)
			expect(seen.dressed).to.equal(1)
			local lobby = bin:FindFirstChild(Data.FOLDER_NAME) :: Instance
			local body = lobby:FindFirstChild(Data.KEEPER_NAME, true)
			expect(body).to.be.ok()
			-- THE PROMPT IS ON THE COUNTER SINCE TASK 195, not on the man: a part that collides is
			-- hit by every ray whatever `CanQuery` says (measured), so the clip that stops a player
			-- vaulting the till also stops the prompt's own sight line, and a prompt behind it is a
			-- shop nobody can open. It is still built only when there IS a keeper, which is what
			-- this case cares about -- so it asks for both, and for the prompt to be on the till.
			local prompt = lobby:FindFirstChild(Data.PROMPT_NAME, true)
			expect(prompt).to.be.ok()
			local counter = lobby:FindFirstChild(Data.COUNTER_NAME, true)
			expect(counter).to.be.ok()
			expect((prompt :: Instance):IsDescendantOf(counter :: Instance)).to.equal(true)
		end)

		it("turns his head on the scan it already runs, and only when the man has moved", function()
			local _seen, on = fresh(bin)
			expect(on).to.equal(true)
			Lobby.step(1000, {})
			local at = Lobby.Build.keeperPosition()
			expect(at).to.be.ok()
			local here = at :: Vector3
			-- A man standing well off to one side of him: that is a turn, on the next scan.
			local player = occupant(31, here + Vector3.new(8, 0, -3), bin)
			Lobby.step(1001, { player })
			local turns = Lobby.stats().keeperTurns
			expect(turns).to.equal(1)
			-- ...AND A MAN STANDING STILL COSTS NOTHING. A counter that climbed with `scans` would
			-- be a per-scan write on a body, which is exactly what this epsilon exists to stop.
			Lobby.step(1002, { player })
			Lobby.step(1003, { player })
			expect(Lobby.stats().keeperTurns).to.equal(turns)
			expect(Lobby.stats().scans >= 4).to.equal(true)
		end)

		-- THE BUILD CANNOT RUN TWICE (review round 1, finding 3). Since task 181 the build path can
		-- YIELD -- `Players:CreateHumanoidModelFromDescription` is documented to load assets -- and
		-- `step` runs off a `Heartbeat` at 10 Hz, so a rig call longer than one scan used to let the
		-- next scan build the WHOLE LOBBY again: two folders, two lodges, two keepers with two
		-- prompts, and `Build.build`'s "parented last" meant the second could not see the first to
		-- destroy it. The yield is driven here by the only thing a spec can do deterministically:
		-- the fake rig re-enters `Lobby.step` from inside the build, which is exactly what a
		-- heartbeat landing mid-yield does.
		it("never builds the lobby twice, even when the rig call re-enters the scan", function()
			local reentered = 0
			local _seen, on = fresh(bin, function(world)
				local inner = world.rig
				world.rig = function(...)
					reentered += 1
					if reentered == 1 then
						Lobby.step(1000.5, {}) -- the next heartbeat, landing inside the yield
					end
					return inner(...)
				end
			end)
			expect(on).to.equal(true)
			Lobby.step(1000, {})
			expect(reentered).to.equal(1)
			local folders = 0
			for _, child in ipairs(bin:GetChildren()) do
				if child.Name == Data.FOLDER_NAME then
					folders += 1
				end
			end
			expect(folders).to.equal(1)
			expect(Lobby.stats().buildAttempts).to.equal(1)
			expect(Lobby.stats().keepers).to.equal(1)
		end)

		-- ---------------------------------------------------------- task 213, the hill under pad 4
		--
		-- KAREN, 2026-10-19: *"truck is good, now can make pods closer to truck"*. Bringing the pads
		-- south to her gap put pad 4's south-east corner on the last of the yard's old east hill --
		-- the same 1.27 studs of it `TRUCK.SETTLE` was written for. MEASURED in the live Forest Test
		-- the same day, 81 rays per pad: dead flat under pads 1, 2 and 3 (spread 0.000) and 0.936
		-- studs of rise across pad 4's corner, which left 8 of its 81 samples ABOVE the deck's top --
		-- a buried corner and a broken rim, photographed from the player's eye.
		--
		-- SO THE GROUND IS ASKED AT NINE PLACES AND THE HIGHEST WINS, which is task 196's finding
		-- (*"WHY ONE SAMPLE IS NOT ENOUGH"*) on a third surface. This case is the shape of that live
		-- yard: flat everywhere except one corner of one pad.
		it("lays a pad on the HIGHEST ground under it, not the ground at its middle (task 213)", function()
			local BUMP = 0.936 -- the live measurement, kept as the number it was measured at
			local corner = padAt(CFG.TRUCK.COUNT)
			local _seen, on = fresh(bin, function(world)
				world.groundAt = function(x: number?, z: number?): number?
					-- THE HILL IS IN THE LAST PAD'S LAST CORNER AND NOWHERE ELSE, so a build that
					-- read the centre, the mean or the lowest sample cannot pass this.
					if
						x ~= nil
						and z ~= nil
						and x >= corner.X + CFG.PADS.SIZE.X / 2 - 0.5
						and z <= corner.Z - CFG.PADS.SIZE.Z / 2 + 0.5
					then
						return SHELF + BUMP
					end
					return SHELF
				end
			end)
			expect(on).to.equal(true)
			Lobby.step(1000, {})
			expect(Lobby.isBuilt()).to.equal(true)
			-- THE PAD ON THE HILL CLEARS IT: its top is the highest ground plus the z-fighting lift.
			local hilly = Lobby.Build.padPart(CFG.TRUCK.COUNT) :: BasePart
			local top = hilly.Position.Y + hilly.Size.Y / 2
			expect(math.abs(top - (SHELF + BUMP + CFG.PADS.LIFT_STUDS)) < 1e-3).to.equal(true)
			-- ...AND THE FLAT ONES ARE NOT DRAGGED UP WITH IT. One pad's hill is one pad's business:
			-- the lift is per pad and the slab's own floor (`ROAD.THICK_STUDS`) still bounds it.
			for index = 1, CFG.TRUCK.COUNT - 1 do
				local flat = Lobby.Build.padPart(index) :: BasePart
				local flatTop = flat.Position.Y + flat.Size.Y / 2
				expect(math.abs(flatTop - (SHELF + CFG.ROAD.THICK_STUDS + CFG.PADS.LIFT_STUDS)) < 1e-3).to.equal(true)
				expect(flatTop < top).to.equal(true)
			end
		end)

		it("builds inside a second and says how long it took", function()
			local _seen, on = fresh(bin)
			expect(on).to.equal(true)
			Lobby.step(1000, {})
			expect(Lobby.stats().buildMs <= 1000).to.equal(true)
		end)

		it("retries while the ground cannot be read, and never locks the game out", function()
			local seen, on = fresh(bin, function(world)
				world.groundAt = function(): number?
					return nil
				end
			end)
			expect(on).to.equal(true)
			local player = occupant(11, Vector3.new(0, 0, 0), bin)
			Lobby.step(1000, { player })
			expect(Lobby.isBuilt()).to.equal(false)
			expect(#seen.enrolled).to.equal(0)
			-- ...and after the timeout everybody is enrolled through the SAME door the circle uses, so
			-- the game is today's game exactly: no second code path.
			Lobby.step(1000 + CFG.BUILD_TIMEOUT_SECONDS, { player })
			expect(#seen.enrolled).to.equal(1)
			expect(seen.enrolled[1]).to.equal(11)
			-- Once, and never again.
			Lobby.step(1000 + CFG.BUILD_TIMEOUT_SECONDS + 5, { player })
			expect(#seen.enrolled).to.equal(1)
		end)
	end)

	describe("a player walking to the truck", function()
		it("does nothing while he stands away from the circle", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local far = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z) + CFG.SPAWN.OFFSET
			local player = occupant(21, far, bin)
			Lobby.step(1001, { player })
			expect(#seen.enrolled).to.equal(0)
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(nil)
			-- ...and his respawn point is the lodge while he is out of the drive.
			expect(player.RespawnLocation).to.be.ok()
			expect((player.RespawnLocation :: Instance).Name).to.equal(Data.SPAWN_NAME)
		end)

		it("asks the first man on a pad, through the pad's own two attributes and nothing else", function()
			-- TASK 182: STEPPING ON NO LONGER STARTS A CLOCK OF HIS OWN. It starts the PAD, and the
			-- pad asks him how many -- which reaches his client as two attributes on the pad's own
			-- part and not as a message.
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local player = occupant(22, padAt(2), bin)
			Lobby.step(1001, { player })
			local pad = Lobby.padOf(2)
			expect(pad.state).to.equal(Pads.SIZING)
			expect(pad.firstUserId).to.equal(22)
			expect(pad.size).to.equal(nil)
			expect(#seen.enrolled).to.equal(0)
			-- THE ATTRIBUTES ARE ON THE PART, AND `Lobby.padAsking` IS WHAT THE CLIENT ASKS.
			local deck = Lobby.Build.padPart(2) :: BasePart
			expect(deck:GetAttribute(Data.PAD_STATE_ATTRIBUTE)).to.equal(Pads.SIZING)
			expect(deck:GetAttribute(Data.PAD_FIRST_ATTRIBUTE)).to.equal(22)
			-- `Data.padAsking` IS NOT ASKED HERE, and the reason is this spec's own foundation: the
			-- lobby is built into `bin` and that reader looks for `Workspace.Lobby` by name. The two
			-- attributes above ARE what it reads, and `lobby.spec` drives the reader itself against a
			-- lobby that really is in `Workspace`.
			-- AND NO COUNTDOWN YET: `DHLobbyLeaveAt` belongs to the `filling -> countdown` edge.
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(nil)
			-- ...THE BILLBOARD SAYS `1 / -`, because nobody has picked and that is not a party of nought.
			expect(select(2, Lobby.Build.padLabel(2))).to.equal(string.format(CFG.PADS.BILLBOARD.COUNT_UNSET, 1))

			-- HE STEPS OFF: the pad empties, everything is taken back, nobody is enrolled.
			player.root.Position = padAt(2) + Vector3.new(0, 0, 60)
			Lobby.step(1002, { player })
			expect(Lobby.padOf(2).state).to.equal(Pads.EMPTY)
			expect(deck:GetAttribute(Data.PAD_FIRST_ATTRIBUTE)).to.equal(nil)
			expect(#seen.enrolled).to.equal(0)
			expect(Lobby.stats().cancels).to.equal(1)
		end)

		-- ---------------------------------------------------------------- task 197
		it("starts THAT pad's truck when the size is picked, and leaves the other three dark", function()
			-- KAREN, 2026-10-15: *"also could be car started sound light on something like that
			-- indicating loading ect"*.
			--
			-- IT RUNS AGAINST `Build.truck`'S FALLBACK AND THAT IS THE POINT HERE: the DEV place has
			-- no `LobbyAssets`, so every bay is the parts truck, which ships NO lamp at all -- the
			-- branch that has to build its own four lenses. The free model's own lamps are classified
			-- by `lobby.spec`'s pure case, off the table measured out of the real model.
			local _seen = fresh(bin)
			Lobby.step(1000, {})
			-- EVERY TRUCK GOT A RIG, AND EVERY ONE IS BORN OFF: a yard nobody is standing in is four
			-- dark trucks, which is the state the game is in for all but a few seconds.
			for index = 1, CFG.TRUCK.COUNT do
				expect(Lobby.Build.truckRunning(index)).to.equal(false)
				local lamps, lights, voice = Lobby.Build.truckRigCounts(index)
				-- FOUR LENSES on the fallback truck: two headlights and two tails.
				expect(lamps).to.equal(4)
				-- ...AND TWO LIGHTS, NOT FOUR. A tail lamp is its OWN LENS and nothing else since the
				-- rear-quarter night frame (`TAIL_BRIGHTNESS = 0`): the six red `PointLight`s behind
				-- the lenses turned twenty studs of ground, two neighbouring trucks and the lodge
				-- salmon pink, and the lit lens reads as a tail light without them. The two that are
				-- left are the headlamps' `SpotLight`s, which have a job to do.
				local tailGlows = if CFG.TRUCK.ENGINE.TAIL_BRIGHTNESS > 0 then 2 else 0
				expect(lights).to.equal(2 + tailGlows)
				-- ...AND AN ENGINE, A SMOKE EMITTER AND BOTH SOUNDS.
				expect(voice).to.equal(true)
			end
			expect(Lobby.Build.stats().truckRigs).to.equal(CFG.TRUCK.COUNT)
			expect(Lobby.Build.truckRunning(CFG.TRUCK.COUNT + 1)).to.equal(nil)

			local player = occupant(61, padAt(2), bin)
			Lobby.step(1001, { player })
			-- STILL DARK WHILE THE DIALOG IS UP: `sizing` is not loading, because a man reading the
			-- dialog has committed to nothing.
			expect(Lobby.padOf(2).state).to.equal(Pads.SIZING)
			expect(Lobby.Build.truckRunning(2)).to.equal(false)

			-- THE PICK STARTS IT, ON THE PRESS AND NOT ON THE NEXT SCAN.
			expect(Lobby.onPadRequest(player, { pad = 2, size = 1 }, 1001.1).ok).to.equal(true)
			expect(Lobby.Build.truckRunning(2)).to.equal(true)
			for _, dark in ipairs({ 1, 3, 4 }) do
				expect(Lobby.Build.truckRunning(dark)).to.equal(false)
			end
			local writes = Lobby.stats().truckWrites
			expect(writes).to.equal(1)

			-- IT IS AN EDGE AND NOT A SCAN. `setTruck` is asked every scan with a level answer, so
			-- fifty scans of a running truck are still one write -- `padWrites`' own claim, which is
			-- what stops this costing four instance writes a tick for ever.
			for tick = 1, 20 do
				Lobby.step(1001.1 + tick * 0.12, { player })
			end
			expect(Lobby.stats().truckWrites).to.equal(writes)
			expect(Lobby.Build.truckRunning(2)).to.equal(true)
			-- ...AND IT IS STILL RUNNING THROUGH THE COUNTDOWN, which is the state the banner counts
			-- down in.
			expect(Lobby.padOf(2).state).to.equal(Pads.COUNTDOWN)
		end)

		it("puts the engine and the exhaust ON the truck, not three thousand studs away", function()
			-- **THE DEFECT THIS CASE IS WRITTEN FROM, measured in the live Forest Test on 2026-10-17:**
			-- the exhaust attachment reported `(5783.8, 304.8, -5872.9)` against a lobby at
			-- (2893, 150, -2941) -- very nearly twice everything. `Attachment.WorldCFrame` was being
			-- written BEFORE the attachment was parented, so it landed in the LOCAL `CFrame` and the
			-- engine then multiplied it by the part's own. The smoke was emitting three thousand
			-- studs away and the engine SOUND was playing there with it, which is the whole of
			-- Karen's *"car started sound"* gone -- and no spec could see it, because an attachment
			-- has no failure to assert, only a position nobody looked at.
			--
			-- SO THE ASSERTION IS THE ONE THING THAT WOULD HAVE CAUGHT IT: every piece of the rig is
			-- inside its own truck's box, with a stud of slack for the exhaust hanging under the
			-- tailgate.
			local _seen = fresh(bin)
			Lobby.step(1000, {})
			local trucks = bin:FindFirstChild(Data.TRUCKS_NAME, true)
			expect(trucks).to.be.ok()
			local checked = 0
			for index = 1, CFG.TRUCK.COUNT do
				local truck = (trucks :: Instance):FindFirstChild(string.format(Data.TRUCK_NAME, index))
				expect(truck).to.be.ok()
				local centre, half = Lobby.Build.worldBoxOf(truck :: Instance)
				local slack = Vector3.new(2, 2, 2)
				for _, piece in ipairs((truck :: Instance):GetDescendants()) do
					if piece:IsA("Attachment") then
						local at = (piece :: Attachment).WorldPosition
						local gap = at - centre
						expect(math.abs(gap.X) <= half.X + slack.X).to.equal(true)
						expect(math.abs(gap.Y) <= half.Y + slack.Y).to.equal(true)
						expect(math.abs(gap.Z) <= half.Z + slack.Z).to.equal(true)
						checked += 1
					end
				end
			end
			-- AND THERE IS SOMETHING TO CHECK: two per truck (the engine and the exhaust) plus one
			-- aim attachment per headlamp, so a rig that built nothing would fail here rather than
			-- pass a loop over an empty list.
			expect(checked >= 2 * CFG.TRUCK.COUNT).to.equal(true)
		end)

		it("turns the truck off again whichever way the party ends", function()
			-- THE RECONCILE IS THE WHOLE REASON THIS IS NOT AN EVENT. A truck started by the PICK and
			-- stopped by the DEPARTURE would be left idling by every other way a party can end -- and
			-- there are three, driven one after the other below.
			local seen = fresh(bin)
			Lobby.step(1000, {})

			-- (1) HE DEPARTS. The drive takes him, the pad empties by itself, the truck goes quiet.
			local goes = occupant(71, padAt(1), bin)
			Lobby.step(1001, { goes })
			expect(Lobby.onPadRequest(goes, { pad = 1, size = 1 }, 1001.1).ok).to.equal(true)
			expect(Lobby.Build.truckRunning(1)).to.equal(true)
			-- ONE TRANSITION PER CALL (`Pads.step`'s own rule), so the scan that arms the countdown and
			-- the scan that departs are two scans and the deadline is measured from the FIRST of them.
			Lobby.step(1001.2, { goes })
			expect(Lobby.padOf(1).state).to.equal(Pads.COUNTDOWN)
			Lobby.step(1001.3 + CFG.COUNTDOWN_SECONDS, { goes })
			expect(#seen.enrolled).to.equal(1)
			Lobby.step(1001.5 + CFG.COUNTDOWN_SECONDS, { goes })
			expect(Lobby.padOf(1).state).to.equal(Pads.EMPTY)
			expect(Lobby.Build.truckRunning(1)).to.equal(false)

			-- (2) HE WALKS AWAY DURING THE COUNTDOWN. Karen's own task-177 rule -- stepping out
			-- cancels it -- and the truck has to stop with it.
			local quits = occupant(72, padAt(3), bin)
			Lobby.step(1010, { quits })
			expect(Lobby.onPadRequest(quits, { pad = 3, size = 1 }, 1010.1).ok).to.equal(true)
			expect(Lobby.Build.truckRunning(3)).to.equal(true)
			quits.root.Position = padAt(3) + Vector3.new(0, 0, 60)
			Lobby.step(1010.3, { quits })
			expect(Lobby.padOf(3).state).to.equal(Pads.EMPTY)
			expect(Lobby.Build.truckRunning(3)).to.equal(false)

			-- (3) THE HAND-OVER FAILS. `Lobby.depart` returns 0, the pad re-enters `sizing` -- a
			-- fresh question, not a resumed one -- and `sizing` is not loading, so the engine stops
			-- rather than idling at a pad that is asking again.
			local stuck = fresh(bin, function(world)
				world.enrol = function()
					return false
				end
			end)
			expect(stuck).to.be.ok()
			Lobby.step(2000, {})
			local stranded = occupant(73, padAt(4), bin)
			Lobby.step(2001, { stranded })
			expect(Lobby.onPadRequest(stranded, { pad = 4, size = 1 }, 2001.1).ok).to.equal(true)
			expect(Lobby.Build.truckRunning(4)).to.equal(true)
			Lobby.step(2001.2, { stranded })
			expect(Lobby.padOf(4).state).to.equal(Pads.COUNTDOWN)
			Lobby.step(2001.3 + CFG.COUNTDOWN_SECONDS, { stranded })
			Lobby.step(2001.5 + CFG.COUNTDOWN_SECONDS, { stranded })
			expect(Lobby.padOf(4).state).to.equal(Pads.SIZING)
			expect(Lobby.Build.truckRunning(4)).to.equal(false)
		end)

		it("tells every member of the party that his truck is loading, and nobody else", function()
			-- KAREN: *"we need clear message that game is loading once clicked 1/1 or other now is
			-- delay"*. `DHPadMine` is the banner's whole visibility rule and it is a server-measured
			-- fact: one attribute per member, the state word of the pad taking him.
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local a = occupant(81, padAt(2), bin)
			local b = occupant(82, padAt(2) + Vector3.new(2, 0, 2), bin)
			local bystander = occupant(83, Vector3.new(ANCHOR.x, SHELF, ANCHOR.z) + CFG.SPAWN.OFFSET, bin)
			Lobby.step(1001, { a, b, bystander })
			-- NOTHING WHILE THE DIALOG IS UP: `sizing` is not a loading state, so the dialog and the
			-- banner can never be on screen together.
			expect(a.attributes[Data.PAD_MINE_ATTRIBUTE]).to.equal(nil)

			expect(Lobby.onPadRequest(a, { pad = 2, size = 2 }, 1001.1).ok).to.equal(true)
			Lobby.step(1001.2, { a, b, bystander })
			-- BOTH MEMBERS, THE SAME WORD, and it is the pad's own state -- so the banner's line and
			-- the pad's billboard can never disagree about what is happening.
			expect(a.attributes[Data.PAD_MINE_ATTRIBUTE]).to.equal(Lobby.padOf(2).state)
			expect(b.attributes[Data.PAD_MINE_ATTRIBUTE]).to.equal(a.attributes[Data.PAD_MINE_ATTRIBUTE])
			expect(Data.padLoading(a.attributes[Data.PAD_MINE_ATTRIBUTE])).to.equal(true)
			-- AND NOT THE MAN BY THE LODGE.
			expect(bystander.attributes[Data.PAD_MINE_ATTRIBUTE]).to.equal(nil)

			-- IT CLEARS THE MOMENT THE DRIVE HAS HIM, which is the Director's *"until the drive takes
			-- the player"* -- the same edge the roster is written on, so the banner cannot outlive the
			-- thing it was counting down to.
			Lobby.step(1001.2 + CFG.COUNTDOWN_SECONDS, { a, b, bystander })
			expect(#seen.enrolled).to.equal(2)
			Lobby.step(1001.4 + CFG.COUNTDOWN_SECONDS, { a, b, bystander })
			expect(a.attributes[Data.PAD_MINE_ATTRIBUTE]).to.equal(nil)
			expect(b.attributes[Data.PAD_MINE_ATTRIBUTE]).to.equal(nil)
		end)

		it("leaves no banner and no running truck behind when the owner stops", function()
			-- THE TEARDOWN CLAIM, extended to task 197's two new things: an owner that stopped must
			-- leave nothing on anybody's screen and no engine running in an empty yard.
			local _seen = fresh(bin)
			Lobby.step(1000, {})
			local player = occupant(91, padAt(1), bin)
			Lobby.step(1001, { player })
			expect(Lobby.onPadRequest(player, { pad = 1, size = 1 }, 1001.1).ok).to.equal(true)
			Lobby.step(1001.2, { player })
			expect(player.attributes[Data.PAD_MINE_ATTRIBUTE]).to.be.ok()
			expect(Lobby.Build.truckRunning(1)).to.equal(true)
			Lobby.stop()
			expect(player.attributes[Data.PAD_MINE_ATTRIBUTE]).to.equal(nil)
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(nil)
			-- THE TRUCK WENT WITH THE FOLDER: `Lobby.stop` destroys it, so there is nothing left to
			-- be running. The rig is dropped at the next build, and `setTruck` would write nothing on
			-- a part that is no longer in the DataModel.
			expect(Lobby.Build.padPart(1)).to.equal(nil)
		end)

		it("gives every member of a departing party the SAME deadline, once, on the edge", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local a = occupant(31, padAt(3), bin)
			local b = occupant(32, padAt(3) + Vector3.new(2, 0, 2), bin)
			Lobby.step(1001, { a, b })
			-- A PICK OF TWO, FROM THE MAN THE PAD ASKED: the pad is full the moment it is sized.
			expect(Lobby.onPadRequest(a, { pad = 3, size = 2 }, 1001.1).ok).to.equal(true)
			Lobby.step(1001.2, { a, b })
			local pad = Lobby.padOf(3)
			expect(pad.state).to.equal(Pads.COUNTDOWN)
			-- ONE DEADLINE, SHARED. Task 177 gave each man his own clock; a party of two watching two
			-- different numbers would be two answers to "how long until I go".
			local first = a.attributes[Data.LEAVE_AT_ATTRIBUTE]
			local second = b.attributes[Data.LEAVE_AT_ATTRIBUTE]
			expect(type(first)).to.equal("number")
			expect(second).to.equal(first)
			expect(#seen.enrolled).to.equal(0)
			-- ...AND WRITTEN ONCE, ON THE EDGE (task 177 review round 1, note 3). It used to be
			-- rewritten every scan -- ~50 replicated writes per walk-in, each recomputing the same
			-- number.
			Lobby.step(1001.5, { a, b })
			Lobby.step(1001.8, { a, b })
			expect(a.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(first)

			-- BOTH GO, ONE `enrol` EACH, AND NO FIFTH CALL ON THE NEXT SCAN.
			Lobby.step(1001.2 + CFG.COUNTDOWN_SECONDS, { a, b })
			expect(#seen.enrolled).to.equal(2)
			Lobby.step(1001.4 + CFG.COUNTDOWN_SECONDS, { a, b })
			Lobby.step(1001.6 + CFG.COUNTDOWN_SECONDS, { a, b })
			expect(#seen.enrolled).to.equal(2)
			expect(Lobby.stats().departures).to.equal(1)
			-- THE PAD EMPTIES BY ITSELF, because a man the drive has is left out of its member list.
			expect(Lobby.padOf(3).state).to.equal(Pads.EMPTY)
		end)

		it("takes a pick only from the man it asked, on the pad he is standing on, while it is asking", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local first = occupant(51, padAt(1), bin)
			local other = occupant(52, padAt(1) + Vector3.new(2, 0, 0), bin)
			local away = occupant(53, padAt(4), bin)
			Lobby.step(1001, { first, other, away })
			expect(Lobby.padOf(1).firstUserId).to.equal(51)

			-- A FORGED PAYLOAD IS COUNTED AS A FORGERY AND CHANGES NOTHING, and `refusedBy` stays
			-- empty -- `Weapon.stats`' own split, because counting a forgery as a refusal would hide
			-- a mis-wired client inside a game rule.
			local forged = {
				nil,
				"x",
				{},
				{ pad = 99, size = 4 },
				{ pad = 1, size = 3 },
				{ pad = 1, size = "4" },
				{ pad = 1.5, size = 4 },
			}
			for index = 1, 7 do
				local reply = Lobby.onPadRequest(first, forged[index], 1001 + index * 0.3)
				expect(reply.ok).to.equal(false)
				expect(reply.refused).to.equal("bad-request")
			end
			expect(Lobby.stats().badRequests).to.equal(7)
			expect(next(Lobby.stats().refusedBy)).to.equal(nil)
			expect(Lobby.padOf(1).size).to.equal(nil)

			-- A LEGAL PICK FROM THE WRONG MAN: refused by NAME, counted as a refusal and not a forgery.
			local notFirst = Lobby.onPadRequest(other, { pad = 1, size = 4 }, 1010)
			expect(notFirst.refused).to.equal("not-first")
			expect(Lobby.stats().refusedBy["not-first"]).to.equal(1)
			expect(Lobby.stats().badRequests).to.equal(7)
			expect(Lobby.padOf(1).size).to.equal(nil)

			-- A PICK FOR A PAD HE IS NOT STANDING ON, measured off the character the SERVER can see
			-- and never from the payload.
			local elsewhere = Lobby.onPadRequest(away, { pad = 1, size = 4 }, 1011)
			expect(elsewhere.refused).to.equal("not-on-pad")

			-- THE REAL ONE.
			local ok = Lobby.onPadRequest(first, { pad = 1, size = 4 }, 1012)
			expect(ok.ok).to.equal(true)
			expect(ok.size).to.equal(4)
			expect(Lobby.padOf(1).size).to.equal(4)
			expect(Lobby.padOf(1).state).to.equal(Pads.FILLING)
			expect(select(2, Lobby.Build.padLabel(1))).to.equal("2 / 4")
			-- ...AND A SECOND ONE IS TOO LATE: the pad has moved on, which is a stale client and not
			-- a forged one.
			expect(Lobby.onPadRequest(first, { pad = 1, size = 2 }, 1013).refused).to.equal("too-late")

			-- RATE-LIMITED. A person cannot press a button four times a second, so a second request
			-- inside the interval is not answered at all.
			expect(Lobby.onPadRequest(first, { pad = 1, size = 2 }, 1013.05)).to.equal(nil)
			expect(Lobby.stats().rateLimited).to.equal(1)
			expect(#seen.enrolled).to.equal(0)
		end)

		it("defaults the pick to one and sends him alone, which is the unattended path", function()
			-- THE PATH THE DIRECTOR'S SMOKE CHECK TAKES: pivot a man onto `TruckSpot`, press nothing,
			-- and the drive has him 13 seconds later (design section 15.4).
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local player = occupant(61, padAt(1), bin)
			Lobby.step(1001, { player })
			local at = 1001
			while at < 1001 + SOLO_SECONDS do
				at += 1 / CFG.SCAN_HZ
				Lobby.step(at, { player })
			end
			expect(Lobby.stats().pickTimeouts).to.equal(1)
			expect(#seen.enrolled).to.equal(1)
			expect(seen.enrolled[1]).to.equal(61)
			-- CLEARED BEFORE THE ENROLMENT, because `enrol` reaches `LoadCharacter` inside the same
			-- call: with the lodge still set, the engine would put the new character there and the
			-- drive's own pivot would have to beat it.
			expect(player.RespawnLocation).to.equal(nil)
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(nil)
		end)

		it("hands the party to the injected depart seam instead, when a world gives one", function()
			-- THE TELEPORT'S SEAM, DRIVEN IN BOTH DIRECTIONS (design section 9). The reserved-server
			-- path cannot be built here -- Studio cannot reserve a server -- but the SWITCH can be,
			-- and this is what makes "both branches are reachable by parameter" a checked claim
			-- rather than a promise.
			local sent: { any } = {}
			local seen = fresh(bin, function(world)
				world.depart = function(departure)
					table.insert(sent, departure)
					return #departure.members
				end
			end)
			Lobby.step(1000, {})
			local player = occupant(71, padAt(2), bin)
			Lobby.step(1001, { player })
			local at = 1001
			while at < 1001 + SOLO_SECONDS do
				at += 1 / CFG.SCAN_HZ
				Lobby.step(at, { player })
			end
			expect(#sent).to.equal(1)
			expect(sent[1].padIndex).to.equal(2)
			expect(sent[1].size).to.equal(1)
			expect(#sent[1].members).to.equal(1)
			expect(sent[1].members[1].UserId).to.equal(71)
			-- ...AND THE DRIVE WAS NOT ASKED AT ALL, which is the whole point of the seam.
			expect(#seen.enrolled).to.equal(0)
			expect(Lobby.stats().departures).to.equal(1)
		end)

		it("re-elects the next man when the first steps off, and clears every attribute when it empties", function()
			local _seen = fresh(bin)
			Lobby.step(1000, {})
			local a = occupant(81, padAt(2), bin)
			local b = occupant(82, padAt(2) + Vector3.new(2, 0, 0), bin)
			Lobby.step(1001, { a, b })
			expect(Lobby.padOf(2).firstUserId).to.equal(81)
			a.root.Position = padAt(2) + Vector3.new(0, 0, 60)
			Lobby.step(1002, { a, b })
			local pad = Lobby.padOf(2)
			expect(pad.firstUserId).to.equal(82)
			expect(pad.state).to.equal(Pads.SIZING)
			-- A FRESH CLOCK, not an inherited one.
			expect(pad.deadline).to.equal(1002 + CFG.PADS.PICK_TIMEOUT_SECONDS)
			b.root.Position = padAt(2) + Vector3.new(0, 0, 60)
			Lobby.step(1003, { a, b })
			local deck = Lobby.Build.padPart(2) :: BasePart
			expect(deck:GetAttribute(Data.PAD_STATE_ATTRIBUTE)).to.equal(Pads.EMPTY)
			expect(deck:GetAttribute(Data.PAD_FIRST_ATTRIBUTE)).to.equal(nil)
		end)

		it("still enrols a party while a drive is running: the mid-drive join stays", function()
			-- THE DIRECTOR'S DEFAULT, ASSERTED (design section 6.5). "HUNT IN PROGRESS, pads inert"
			-- was refused, because it would make four pads dead for up to ten minutes to protect a
			-- behaviour `Match.enrol` already supports in any phase.
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local hunting = occupant(91, padAt(4) + Vector3.new(0, 0, 400), bin)
			seen.inDrive[91] = true
			local joining = occupant(92, padAt(4), bin)
			Lobby.step(1001, { hunting, joining })
			local at = 1001
			while at < 1001 + SOLO_SECONDS do
				at += 1 / CFG.SCAN_HZ
				Lobby.step(at, { hunting, joining })
			end
			expect(#seen.enrolled).to.equal(1)
			expect(seen.enrolled[1]).to.equal(92)
			-- ...AND THE MAN ALREADY IN THE DRIVE WAS NEVER IN THE PARTY: a pad's members are the men
			-- standing on it who are NOT already hunting, which is what makes `leaving` end by itself.
			expect(Lobby.stats().departures).to.equal(1)
		end)

		it("writes nothing to a pad when nobody moves", function()
			-- THE EDGE CLAIM, over fifty scans. `Build.setPad` is asked every scan because the COUNT
			-- changes on a join and a leave, so it has to be free when nothing moved.
			local _seen = fresh(bin)
			Lobby.step(1000, {})
			local before = Lobby.stats().padWrites
			local scans = Lobby.stats().scans
			local at = 1000
			for _ = 1, 50 do
				at += 1 / CFG.SCAN_HZ
				Lobby.step(at, {})
			end
			expect(Lobby.stats().scans).to.equal(scans + 50)
			expect(Lobby.stats().padWrites).to.equal(before)
		end)

		it("starts even when the remote's Connect answers nothing", function()
			-- MEASURED IN ROUND 1 OF TASK 178: nine cases of `shop_door.spec` died INSIDE `start`
			-- because `table.insert(t, nil)` throws, and a `RemoteEvent` double whose `Connect`
			-- returns nil is a legal stand-in -- a spec drives the handler by parameter, which is the
			-- whole point of it being public. Not repeated here.
			local _seen, on = fresh(bin, function(world)
				world.remotes = {
					PadRequest = {
						OnServerEvent = {
							Connect = function()
								return nil
							end,
						},
					},
				}
			end)
			expect(on).to.equal(true)
			Lobby.step(1000, {})
			expect(Lobby.isBuilt()).to.equal(true)
		end)

		-- "ENROLS HIM EXACTLY ONCE AFTER THE COUNTDOWN" IS NOW TWO CASES, above: the party case
		-- (which asserts one `enrol` per member and no second call) and the unattended case (which
		-- asserts the pick timeout, the respawn cleared first, and one man going alone). Task 177's
		-- single-player five-second walk-in no longer exists as a path -- the pad decides, and a solo
		-- hunt is a party of one.

		it("leaves a player who is in the drive entirely alone", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local player = occupant(24, padAt(1), bin)
			seen.inDrive[24] = true
			Lobby.step(1001, { player })
			Lobby.step(1001 + SOLO_SECONDS, { player })
			expect(#seen.enrolled).to.equal(0)
			expect(#seen.placed).to.equal(0)
			expect(player.RespawnLocation).to.equal(nil)
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(nil)
		end)
	end)

	describe("the end of a drive", function()
		it("empties the roster once, on the scan after the results scene goes up", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			expect(seen.dismissed).to.equal(0)
			-- IT RECORDS AND DOES NOT ACT: `Match` fires `PhaseChanged` at the end of a dispatch, and
			-- a dispatch inside a dispatch would apply effects out of order.
			Lobby.onPhase("Scoring")
			expect(seen.dismissed).to.equal(0)
			Lobby.step(1001, {})
			expect(seen.dismissed).to.equal(1)
			-- ...and not again on the next scan, or the one after.
			Lobby.step(1002, {})
			Lobby.step(1003, {})
			expect(seen.dismissed).to.equal(1)
		end)

		it("puts a dismissed player back at the lodge, and not a held one", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local away = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z + 600)
			local standing = occupant(31, away, bin)
			local frozen = occupant(32, away, bin)
			-- HELD IS LOAD-BEARING: this is the man standing in Karen's results scene.
			seen.held[32] = true
			Lobby.step(1001, { standing, frozen })
			expect(#seen.placed).to.equal(1)
			expect(seen.placed[1].userId).to.equal(31)
			-- +Z: he faces the lodge with the forest behind it.
			expect(seen.placed[1].cframe.LookVector.Z > 0.99).to.equal(true)

			-- ...and once the scene lets him go, he goes too.
			seen.held[32] = false
			Lobby.step(1001 + CFG.RETURN_COOLDOWN_SECONDS + 1, { standing, frozen })
			local ids = {}
			for _, row in ipairs(seen.placed) do
				ids[row.userId] = true
			end
			expect(ids[32]).to.equal(true)
		end)

		it("does not return a player who has no character: absent is not outside", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local respawning = occupant(33, nil, bin)
			Lobby.step(1001, { respawning })
			expect(#seen.placed).to.equal(0)
		end)

		it("does not return the same player twice inside the cooldown", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local away = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z + 600)
			local player = occupant(34, away, bin)
			Lobby.step(1001, { player })
			Lobby.step(1001.5, { player })
			Lobby.step(1002, { player })
			expect(#seen.placed).to.equal(1)
			Lobby.step(1001 + CFG.RETURN_COOLDOWN_SECONDS, { player })
			expect(#seen.placed).to.equal(2)
		end)
	end)

	-- ---------------------------------------------------------------- task 246: the hunt goes on
	--
	-- KAREN, 2026-10-23: *"we need continues game so after drive new drive imidiatly after same
	-- amount seconds"*.
	--
	-- THE OWNER'S HALF: the roster measured before it is emptied, the three facts handed to
	-- `Lobby.Next`, the two attributes written as a LEVEL rule, the door against a forgery, and the
	-- party handed to the SAME `depart` seam a pad's party leaves through. `Lobby.Next`'s own rules
	-- are in `lobby_next.spec`, with no world in them at all.
	describe("the next drive", function()
		-- WHO OWNS `ALWAYS HUNTER`, injected the way the role block's own cases inject it -- a second
		-- copy of four lines rather than a shared one, because `Lobby.setAlwaysHunters` is a SETTER
		-- on the singleton and a helper shared across two `describe`s would leak a reader between
		-- them. `afterEach` hands it back.
		local function owning(seen: any, ...)
			local ids = { ... }
			for _, userId in ipairs(ids) do
				seen.owners[userId] = true
			end
			Lobby.setAlwaysHunters(function()
				return seen.owners
			end)
		end

		afterEach(function()
			Lobby.setAlwaysHunters(nil)
		end)

		-- A WORLD WHOSE `dismissAll` EMPTIES THE ROSTER, which is what `Match.dismissAll` does and
		-- what the shared fake deliberately does NOT: that fake's `enrol` sets `inDrive` and nothing
		-- clears it, *"because a fake that recorded the call and left `inDrive` false made the lobby
		-- hand a man it had just enrolled a lodge respawn again on the SAME scan"*. For the loop that
		-- asymmetry is the wrong half: the party is collected from the men the drive HAS, so a
		-- dismissal that leaves them in it drops every one of them on the same scan. **The first
		-- harness run said so in nine failures.** One patch, in the one describe that needs it.
		local function freshLoop(bin_: Instance, patch: ((any) -> ())?)
			local captured: any = nil
			local seen = (
				fresh(bin_, function(world)
					world.dismissAll = function(): number
						local cleared = 0
						for userId in pairs(captured.inDrive) do
							captured.inDrive[userId] = nil
							cleared += 1
						end
						captured.dismissed += 1
						return cleared
					end
					if patch then
						patch(world)
					end
				end)
			)
			captured = seen
			return seen
		end

		-- EVERYBODY THE DRIVE HAS, AT THE LODGE, WITH THE SCENE OVER: the state the loop starts from.
		-- `away` is 600 studs north, which is outside the field, so the return rule fires too -- and
		-- it is the same spot the dismissal cases above use.
		local function drivenHome(seen: any, ids: { number })
			local away = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z + 600)
			local men = {}
			for _, id in ipairs(ids) do
				seen.inDrive[id] = true
				table.insert(men, occupant(id, away, bin))
			end
			Lobby.step(2000, men)
			-- THE DRIVE ENDS. `onPhase` records, the next scan acts.
			Lobby.onPhase("Scoring")
			-- STILL HELD: the results scene is up, so the party is collected and NOT counting yet.
			for _, id in ipairs(ids) do
				seen.held[id] = true
			end
			Lobby.step(2001, men)
			return men
		end

		-- ------------------------------ HE RESPAWNED OUT OF THE DRIVE (task 249)
		--
		-- KAREN, 2026-10-23: *"still game wasant over when I respawn after while it was showing what
		-- was shooted but I was free to walk, is it ok ?"*. It is -- task 248 made a respawn end your
		-- hunt -- and the two things missing were that NOTHING SAID SO and that he was dropped from
		-- the party his drive turned into.
		it("marks the man a LIVE drive let go of, and takes him on the next one (task 249)", function()
			local seen = freshLoop(bin)
			local away = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z + 600)
			local men = { occupant(51, away, bin), occupant(52, away, bin) }
			seen.inDrive[51] = true
			seen.inDrive[52] = true
			Lobby.onPhase("Running")
			Lobby.step(2000, men)
			expect(men[1]:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(nil)
			-- HE PRESSES RESET. `Match.withdraw` takes him out of the roster mid-drive, which is the
			-- ONLY thing this owner sees: `world.inDrive` goes true -> false while a drive is live.
			seen.inDrive[51] = false
			Lobby.step(2001, men)
			expect(men[1]:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(true)
			expect(men[2]:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(nil)
			expect(Lobby.stats().withdrawalsSeen).to.equal(1)
			-- RECONCILED ON THE TICK, NOT FIRED ONCE (L-029): more scans do not count it twice and
			-- do not lose it.
			Lobby.step(2002, men)
			Lobby.step(2003, men)
			expect(men[1]:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(true)
			expect(Lobby.stats().withdrawalsSeen).to.equal(1)
			-- ...AND HE GOES ON THE NEXT DRIVE WITH THE PARTY HE LEFT. The dispatch: *"keep her on
			-- the next drive's countdown party by default"*. He is NOT `inDrive` any more, so
			-- without this he would watch them leave and have to walk to a pad again.
			--
			-- THE ROSTER IS READ ON THIS SIDE OF `dismissAll`, which is `drivenHome`'s own order and
			-- its own measured reason: in production the drive is emptied by that call, and the
			-- fake does not clear `inDrive`, so 52 is still in the drive on the scan that collects.
			Lobby.onPhase("Scoring")
			Lobby.step(2004, men)
			-- `Lobby.nextDrive()` IS A REPORT, NOT THE STATE: `members` is the sorted ARRAY of ids
			-- (`Next.ids`), which is what the case below this one reads too.
			local party = Lobby.nextDrive()
			table.sort(party.members)
			expect(#party.members).to.equal(2)
			expect(party.members[1]).to.equal(51)
			expect(party.members[2]).to.equal(52)
			-- ...AND THE MAN WHO LEFT IS STILL IN IT once the drive has really let go of everybody,
			-- which is the recount `Next.step` makes every scan.
			seen.inDrive[52] = false
			seen.held[51] = false
			seen.held[52] = false
			Lobby.step(2005, men)
			expect(#Lobby.nextDrive().members).to.equal(2)
			-- ...AND THE LINE COMES DOWN THE MOMENT A DRIVE HAS HIM AGAIN.
			Lobby.onPhase("Assigning")
			seen.inDrive[51] = true
			Lobby.step(2006, men)
			expect(men[1]:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(nil)
		end)

		-- ------------------------- AND THE PAD IS NOT HIS DOOR BACK IN (task 261, item 1)
		--
		-- KAREN, 2026-10-25: *"when I respawn and then go to lobby then go back on pad to hunt I been
		-- transfarred to same hunt where I was previuosly with less than min remaining I was hunter but
		-- then time pass and done it's a bug"*.
		-- **A SECOND MAN IS IN THE DRIVE, AND THAT IS WHAT THIS CASE IS NOW ABOUT** (task 287). Task
		-- 261 wrote it with one occupant, because then the only rule was *the pad is never his door
		-- back in*; since task 287 the roster decides which of two things the pad is, so this case
		-- states the MULTI-PLAYER half and the case below it states the solo half. The second
		-- participant is real -- `seen.inDrive[66]`, which is the set `mayRestart` answers from --
		-- and not a stub, or both cases would be the same branch.
		it("keeps a man a live drive let go of off the pads while others hunt (tasks 261, 287)", function()
			local seen = freshLoop(bin)
			Lobby.step(2000, {})
			-- HE IS IN THE DRIVE, STANDING ON A PAD -- which already does nothing, because a man the
			-- drive has is left out of every pad list. MILA IS IN IT TOO, out in the wood.
			local man = occupant(55, padAt(1), bin)
			local mila = occupant(66, Vector3.new(ANCHOR.x, SHELF, ANCHOR.z + 600), bin)
			seen.inDrive[55] = true
			seen.inDrive[66] = true
			Lobby.onPhase("Running")
			Lobby.step(2001, { man, mila })
			expect(Lobby.padOf(1).state).to.equal(Pads.EMPTY)
			-- HE PRESSES RESET: the drive lets go of him, mid-drive. Mila is still hunting.
			seen.inDrive[55] = false
			seen.withdrawn[55] = true
			Lobby.step(2002, { man, mila })
			expect(man:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(true)
			-- ...AND THE PAD HE IS STANDING ON STILL DOES NOTHING. Before task 261 it sized a party,
			-- counted down and handed him back into the hunt he had just left, forty seconds from the
			-- horn. The door he is asking at is refused as well, so the countdown cannot be started by
			-- a forged request either.
			Lobby.step(2003, { man, mila })
			expect(Lobby.padOf(1).state).to.equal(Pads.EMPTY)
			expect(Lobby.onPadRequest(man, { pad = 1, size = 1 }, 2003.1).ok).to.equal(false)
			Lobby.step(2004, { man, mila })
			expect(#seen.enrolled).to.equal(0)
			-- ...**AND NOW HIS SCREEN SAYS WHY** (task 287). The Playtester's measurement of this
			-- rectangle was *"no feedback at all"*: the pad is dead and nothing said that the hunt
			-- was still on or that he goes with the next one. ONE FACT OUT, and the Hud owns the
			-- words (`Objective.CONFIG.TEXT.LobbyLate`).
			expect(man:GetAttribute(Data.PAD_LATE_ATTRIBUTE)).to.equal(true)
			-- IT IS ABOUT THE RECTANGLE AND NOT ABOUT THE MAN: Mila has not left anything, and a man
			-- who steps OFF reads nothing either.
			expect(mila:GetAttribute(Data.PAD_LATE_ATTRIBUTE)).to.equal(nil)
			man.root.Position = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z + 600)
			Lobby.step(2004.5, { man, mila })
			expect(man:GetAttribute(Data.PAD_LATE_ATTRIBUTE)).to.equal(nil)
			man.root.Position = padAt(1)
			Lobby.step(2004.8, { man, mila })
			expect(man:GetAttribute(Data.PAD_LATE_ATTRIBUTE)).to.equal(true)
			-- HE IS NOT WAITING FOR NOTHING: the latch is what puts him in the next drive's party --
			-- both of them, which is what the line on his screen promises -- and the pads are his
			-- again the moment this drive is over.
			Lobby.onPhase("Scoring")
			Lobby.step(2005, { man, mila })
			expect(#Lobby.nextDrive().members).to.equal(2)
			expect(man:GetAttribute(Data.PAD_LATE_ATTRIBUTE)).to.equal(nil)
			-- ...AND THE PAD ASKS HIM ON THAT SAME SCAN: outside the live window he is an occupant like
			-- anybody else, and `Pads.step` takes an EMPTY pad with somebody on it to `sizing`.
			expect(Lobby.padOf(1).state).to.equal(Pads.SIZING)
		end)

		-- ------------------------- ...AND ALONE, THE PAD STARTS A FRESH HUNT (task 287)
		--
		-- KAREN, 2026-10-24: *"when I respawn and then go to lobby then go back on pad to hunt I been
		-- transferred to same hunt ... with less than min remaining ... I need to be same role and
		-- from beginning"*. Task 261 gave her the next drive's party instead of the running one, which
		-- is right while other men are hunting and is a woman standing alone in a lobby watching the
		-- clock of a drive nobody is in. The DRIVE decides (`Match.mayRestart` -> `Phase.mayRestart`,
		-- `match_phase.spec`); this case is the LOBBY half -- that the rectangle is a door again.
		it("hands the man alone in a dead drive back to a pad, and enrols him (task 287)", function()
			local seen = freshLoop(bin)
			Lobby.step(2000, {})
			local man = occupant(55, padAt(1), bin)
			seen.inDrive[55] = true
			Lobby.onPhase("Running")
			Lobby.step(2001, { man })
			expect(Lobby.padOf(1).state).to.equal(Pads.EMPTY)
			-- SHE PRESSES RESET. Nobody else is in the drive, so its clock is running for nobody.
			seen.inDrive[55] = false
			seen.withdrawn[55] = true
			Lobby.step(2002, { man })
			expect(man:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(true)
			-- **THE PAD IS A DOOR AND NOT A NOTICE**: it sizes her party on the next scan, exactly as
			-- it does for anybody standing on it between drives -- and nothing on her screen says
			-- *"the hunt is still on"*, because it is not.
			Lobby.step(2003, { man })
			expect(Lobby.padOf(1).state).to.equal(Pads.SIZING)
			expect(man:GetAttribute(Data.PAD_LATE_ATTRIBUTE)).to.equal(nil)
			-- ...AND THE PARTY GOES, WHICH IS THE ENROLMENT THE DRIVE TURNS INTO A FRESH ONE. With no
			-- pick at all: the timeout defaults her to 1, which is the unattended path.
			-- 1.5 SCANS' WORTH OF TIME PER STEP, not one: `Lobby.step` throttles on
			-- `now - lastScan < 1 / SCAN_HZ`, and a step of exactly `1 / SCAN_HZ` is skipped by
			-- floating-point error about half the time (measured: this case's first run).
			local went = 2003
			for step = 1, math.ceil(SOLO_SECONDS * CFG.SCAN_HZ) + 2 do
				went = 2003 + step * 1.5 / CFG.SCAN_HZ
				Lobby.step(went, { man })
			end
			expect(#seen.enrolled).to.equal(1)
			expect(seen.enrolled[1]).to.equal(55)
			-- ...AND A SECOND MAN WHO RESPAWNED OUT OF THE SAME DRIVE IS NOT LOCKED OUT BY THE DRIVE
			-- THE FIRST ONE JUST STARTED (review round 1, finding 3). His pad is an ordinary pad the
			-- moment the drive's door would take him -- there is no lobby-side latch left to
			-- disagree with it.
			-- HE WAS WITHDRAWN FROM THE SAME DRIVE, BEFORE THE RESTART, which is the state finding 3
			-- is about: the bar he carries is the OLD drive's, and the old drive is gone.
			local second = occupant(57, padAt(2), bin)
			Lobby.step(went + 2 / CFG.SCAN_HZ, { man, second })
			expect(second:GetAttribute(Data.PAD_LATE_ATTRIBUTE)).to.equal(nil)
			Lobby.step(went + 4 / CFG.SCAN_HZ, { man, second })
			expect(Lobby.padOf(2).state).to.equal(Pads.SIZING)
			-- THE LATCH IS DOWN THE MOMENT A DRIVE HAS HER, so the line and the bar lift together.
			Lobby.step(went + 1 / CFG.SCAN_HZ, { man })
			expect(man:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(nil)
		end)

		-- SIT OUT PUTS HIM BACK ON THE PADS (TASKS.md row 249b, and item 1 is what gives it teeth).
		it("clears the latch when he sits the next drive out (task 261)", function()
			local seen = freshLoop(bin)
			Lobby.step(2000, {})
			local man = occupant(56, padAt(2), bin)
			seen.inDrive[56] = true
			Lobby.onPhase("Running")
			Lobby.step(2001, { man })
			seen.inDrive[56] = false
			Lobby.step(2002, { man })
			expect(man:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(true)
			-- HE IS IN THE NEXT DRIVE'S PARTY -- that is what the latch is for -- and then he says he is
			-- not going with them.
			Lobby.onPhase("Scoring")
			Lobby.step(2003, { man })
			expect(#Lobby.nextDrive().members).to.equal(1)
			expect(Lobby.onNextRequest(man, { next = Data.NEXT_WORD.OUT }, 2003.1).ok).to.equal(true)
			-- THE LINE COMES DOWN, which is the note's own complaint (*"keeps reading 'next soon'"*)...
			Lobby.onPhase("Running")
			Lobby.step(2004, { man })
			expect(man:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(nil)
			-- ...AND SO IS THE PAD, on the same scan and WHILE THE DRIVE IS STILL RUNNING, which is what
			-- this task made load-bearing: a man who sat out and then changed his mind would otherwise
			-- have had no door at all until the horn.
			expect(Lobby.padOf(2).state).to.equal(Pads.SIZING)
		end)

		it("does NOT mark the end of a drive as a withdrawal (task 249)", function()
			-- `dismissAll` empties the roster one scan into `Scoring` and that is EVERYBODY at once.
			-- If the latch read the edge alone, every player would read *"you left the drive"* after
			-- every drive -- which is why the phase is part of the test.
			local seen = freshLoop(bin)
			local away = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z + 600)
			local men = { occupant(61, away, bin), occupant(62, away, bin) }
			seen.inDrive[61] = true
			seen.inDrive[62] = true
			Lobby.onPhase("Running")
			Lobby.step(2000, men)
			Lobby.onPhase("Scoring")
			seen.inDrive[61] = false
			seen.inDrive[62] = false
			Lobby.step(2001, men)
			Lobby.step(2002, men)
			expect(men[1]:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(nil)
			expect(men[2]:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE)).to.equal(nil)
			expect(Lobby.stats().withdrawalsSeen).to.equal(0)
		end)

		it("collects the whole roster, both sides, and waits for the results scene", function()
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41, 42 })
			-- THE DRIVE HAS BEEN EMPTIED and the party holds exactly who was in it. The fake's
			-- `dismissAll` does not clear `inDrive`, so this spec does what production does: the
			-- roster is read on THIS side of the call.
			expect(seen.dismissed).to.equal(1)
			local party = Lobby.nextDrive()
			expect(#party.members).to.equal(2)
			expect(party.members[1]).to.equal(41)
			expect(Lobby.stats().nextParties).to.equal(1)
			-- NO DEADLINE WHILE THE SCENE IS UP, and therefore no card: `DHNextDriveAt` is the card's
			-- whole visibility rule, so Karen's score table is alone on the screen for its full 8 s.
			expect(party.at).to.equal(nil)
			expect(party.verdict).to.equal(Lobby.Next.WAITING)
			expect(men[1]:GetAttribute(Data.NEXT_AT_ATTRIBUTE)).to.equal(nil)
			expect(Lobby.stats().nextArmed).to.equal(0)
		end)

		it("arms the countdown when the scene lets everybody go, once, on the edge", function()
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41, 42 })
			for _, id in ipairs({ 41, 42 }) do
				seen.inDrive[id] = false
				seen.held[id] = false
			end
			Lobby.step(2002, men)
			local party = Lobby.nextDrive()
			expect(party.verdict).to.equal(Lobby.Next.COUNTING)
			expect(party.at).to.equal(2002 + CFG.PADS.NEXT.SECONDS)
			expect(Lobby.stats().nextArmed).to.equal(1)
			-- EVERY MEMBER IS HANDED THE SAME DEADLINE, converted into the server's own clock ONCE
			-- per scan -- the pad's measured rule (*"two men on one pad got deadlines four
			-- microseconds apart"*), applied to this card.
			local first = men[1]:GetAttribute(Data.NEXT_AT_ATTRIBUTE)
			expect(type(first)).to.equal("number")
			expect(men[2]:GetAttribute(Data.NEXT_AT_ATTRIBUTE)).to.equal(first)
			-- AND NOT ARMED TWICE, however many scans arrive.
			Lobby.step(2003, men)
			Lobby.step(2004, men)
			expect(Lobby.stats().nextArmed).to.equal(1)
			expect(Lobby.nextDrive().at).to.equal(2002 + CFG.PADS.NEXT.SECONDS)
		end)

		it("sends the party again through the same depart seam, with no pad", function()
			-- THE SEAM, RECORDED: a published build swaps this for a reserved-server teleport, so the
			-- claim *"one place a party leaves this lobby"* is what is asserted and not the enrolment.
			local sent = {}
			local taken = {}
			local seen = freshLoop(bin, function(world)
				world.depart = function(departure)
					table.insert(sent, departure)
					for _, player in ipairs(departure.members) do
						taken[player.UserId] = true
					end
					return #departure.members
				end
			end)
			local men = drivenHome(seen, { 41, 42 })
			for _, id in ipairs({ 41, 42 }) do
				seen.inDrive[id] = false
				seen.held[id] = false
			end
			Lobby.step(2002, men)
			Lobby.step(2002 + CFG.PADS.NEXT.SECONDS, men)
			expect(#sent).to.equal(1)
			expect(#sent[1].members).to.equal(2)
			-- NO PAD SENT THEM, and the field says so rather than naming a pad that did not exist.
			expect(sent[1].padIndex).to.equal(nil)
			expect(sent[1].size).to.equal(2)
			expect(Lobby.stats().nextDepartures).to.equal(1)
			expect(taken[41]).to.equal(true)
			expect(taken[42]).to.equal(true)
			-- ...AND THE CARD COMES DOWN ON THE SAME SCAN, because the party was cleared with the GO.
			Lobby.step(2003 + CFG.PADS.NEXT.SECONDS, men)
			expect(men[1]:GetAttribute(Data.NEXT_AT_ATTRIBUTE)).to.equal(nil)
			expect(Lobby.nextDrive().verdict).to.equal(Lobby.Next.IDLE)
		end)

		it("enrols the party into this server's own drive when no seam is injected", function()
			-- THE BUILT PATH, which is the one that ships: `Lobby.enrolHere` -> `world.enrol`.
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41 })
			seen.inDrive[41] = false
			seen.held[41] = false
			Lobby.step(2002, men)
			Lobby.step(2002 + CFG.PADS.NEXT.SECONDS, men)
			local enrolled = false
			for _, id in ipairs(seen.enrolled) do
				if id == 41 then
					enrolled = true
				end
			end
			expect(enrolled).to.equal(true)
			expect(Lobby.stats().nextDepartures).to.equal(1)
		end)

		it("leaves a man who sat out at the lodge, and sends the rest", function()
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41, 42 })
			for _, id in ipairs({ 41, 42 }) do
				seen.inDrive[id] = false
				seen.held[id] = false
			end
			Lobby.step(2002, men)
			local answer = Lobby.onNextRequest(men[1], { next = Data.NEXT_WORD.OUT }, 2002.5)
			expect(answer.ok).to.equal(true)
			-- THE SERVER WRITES THE ATTRIBUTE INSIDE THE CALL, not on the next scan: one network hop
			-- instead of a tenth of a second of scan (the role door's own arrangement).
			expect(men[1]:GetAttribute(Data.NEXT_OUT_ATTRIBUTE)).to.equal(true)
			expect(Lobby.stats().nextAsks).to.equal(1)
			expect(Lobby.stats().nextWrites).to.equal(1)
			-- THE COUNTDOWN IS UNTOUCHED, which is what lets him change his mind.
			expect(Lobby.nextDrive().at).to.equal(2002 + CFG.PADS.NEXT.SECONDS)
			Lobby.step(2002 + CFG.PADS.NEXT.SECONDS, men)
			expect(#seen.enrolled).to.equal(1)
			expect(seen.enrolled[1]).to.equal(42)
		end)

		it("takes him back when he presses again", function()
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41 })
			seen.inDrive[41] = false
			seen.held[41] = false
			Lobby.step(2002, men)
			Lobby.onNextRequest(men[1], { next = Data.NEXT_WORD.OUT }, 2002.5)
			Lobby.onNextRequest(men[1], { next = Data.NEXT_WORD.IN }, 2003)
			expect(men[1]:GetAttribute(Data.NEXT_OUT_ATTRIBUTE)).to.equal(nil)
			Lobby.step(2002 + CFG.PADS.NEXT.SECONDS, men)
			expect(#seen.enrolled).to.equal(1)
			expect(seen.enrolled[1]).to.equal(41)
		end)

		it("ends the gap with nobody enrolled when the only man sits out", function()
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41 })
			seen.inDrive[41] = false
			seen.held[41] = false
			Lobby.step(2002, men)
			Lobby.onNextRequest(men[1], { next = Data.NEXT_WORD.OUT }, 2002.5)
			Lobby.step(2002 + CFG.PADS.NEXT.SECONDS, men)
			expect(#seen.enrolled).to.equal(0)
			expect(Lobby.stats().nextCleared).to.equal(1)
			expect(Lobby.stats().nextDepartures).to.equal(0)
			-- ...AND THE CARD IS GONE, so he is left standing in the lobby with the pads, which is
			-- exactly the lobby before this task.
			expect(men[1]:GetAttribute(Data.NEXT_AT_ATTRIBUTE)).to.equal(nil)
			expect(men[1]:GetAttribute(Data.NEXT_OUT_ATTRIBUTE)).to.equal(nil)
		end)

		it("refuses a forged payload, a flood and a man with no party, and tells them apart", function()
			local seen = freshLoop(bin)
			local stranger = occupant(49, padAt(2), bin)
			Lobby.step(2000, { stranger })
			-- A FORGERY: the wrong word, a second key, no table at all.
			expect(Lobby.onNextRequest(stranger, { next = "maybe" }, 2000.1).refused).to.equal("bad-request")
			expect(Lobby.onNextRequest(stranger, { next = "out", pad = 1 }, 2000.4).refused).to.equal("bad-request")
			expect(Lobby.onNextRequest(stranger, "out", 2000.7).refused).to.equal("bad-request")
			local forged = Lobby.stats().badRequests
			expect(forged >= 3).to.equal(true)
			-- A LEGAL REQUEST THE GAME SAID NO TO IS A DIFFERENT FACT, and it is counted apart:
			-- *"counting it as a bad request would hide a mis-wired provider inside the forgery
			-- counter"*.
			expect(Lobby.onNextRequest(stranger, { next = Data.NEXT_WORD.OUT }, 2001).refused).to.equal("no-party")
			expect(Lobby.stats().badRequests).to.equal(forged)
			expect(Lobby.stats().refusedBy["no-party"]).to.equal(1)
			expect(Lobby.stats().nextAsks).to.equal(0)
			-- THE FLOOD GUARD, and it is its OWN bucket: the role door's row must not be spent here.
			expect(Lobby.nextRateLimited(49, 3000)).to.equal(false)
			expect(Lobby.nextRateLimited(49, 3000.01)).to.equal(true)
			expect(Lobby.roleRateLimited(49, 3000.01)).to.equal(false)
			local _ = seen
		end)

		it("arms the countdown anyway when the scene never lets one man go", function()
			-- HAZARD 1, AT THE OWNER: one member held for ever -- a character that never loads -- and
			-- the loop goes on without him rather than stopping for everybody. The warning is the
			-- counter, so it can never be invisible.
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41, 42 })
			seen.inDrive[41] = false
			seen.held[41] = false
			seen.inDrive[42] = false
			Lobby.step(2002, men)
			expect(Lobby.nextDrive().verdict).to.equal(Lobby.Next.WAITING)
			Lobby.step(2001 + CFG.PADS.NEXT.ARM_TIMEOUT_SECONDS, men)
			expect(Lobby.nextDrive().verdict).to.equal(Lobby.Next.COUNTING)
			expect(Lobby.stats().nextTimeouts).to.equal(1)
		end)

		it("writes each attribute once per change and not once per scan", function()
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41 })
			seen.inDrive[41] = false
			seen.held[41] = false
			local writes = 0
			local raw = men[1].SetAttribute
			men[1].SetAttribute = function(self: any, name: string, value: any)
				if name == Data.NEXT_AT_ATTRIBUTE or name == Data.NEXT_OUT_ATTRIBUTE then
					writes += 1
				end
				raw(self, name, value)
			end
			Lobby.step(2002, men)
			expect(writes).to.equal(1)
			Lobby.step(2003, men)
			Lobby.step(2004, men)
			Lobby.step(2005, men)
			expect(writes).to.equal(1)
		end)

		it("hands both attributes back when the owner stops", function()
			local seen = freshLoop(bin)
			local men = drivenHome(seen, { 41 })
			seen.inDrive[41] = false
			seen.held[41] = false
			Lobby.step(2002, men)
			Lobby.onNextRequest(men[1], { next = Data.NEXT_WORD.OUT }, 2002.5)
			expect(men[1]:GetAttribute(Data.NEXT_AT_ATTRIBUTE) ~= nil).to.equal(true)
			Lobby.stop()
			expect(men[1]:GetAttribute(Data.NEXT_AT_ATTRIBUTE)).to.equal(nil)
			expect(men[1]:GetAttribute(Data.NEXT_OUT_ATTRIBUTE)).to.equal(nil)
			expect(#Lobby.nextDrive().members).to.equal(0)
		end)

		it("still lets a man choose his role while he waits at the lodge", function()
			-- KAREN'S THIRD SENTENCE: *"who has licesne can select who he can be next round"*. The
			-- role door's own `in-a-drive` refusal is FALSE between drives -- the drive handed his
			-- team back -- so the pick made on this card is the pick `Roster.assign` reads.
			local seen = freshLoop(bin)
			owning(seen, 41)
			local men = drivenHome(seen, { 41 })
			seen.inDrive[41] = false
			seen.held[41] = false
			seen.assigned[41] = nil
			Lobby.step(2002, men)
			local answer = Lobby.onRoleRequest(men[1], { role = Data.ROLE_WISH.BEATER }, 2002.5)
			expect(answer.ok).to.equal(true)
			expect(Lobby.beaterWishes()[41]).to.equal(true)
			-- ...AND IT SURVIVES THE WHOLE COUNTDOWN, because `Lobby.wishFor` only clears a wish the
			-- drive has SPENT (`world.assignedTeam`), which is nil at the lodge.
			Lobby.step(2003, men)
			Lobby.step(2002 + CFG.PADS.NEXT.SECONDS - 0.1, men)
			expect(Lobby.beaterWishes()[41]).to.equal(true)
			expect(men[1]:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.BEATER)
		end)
	end)

	describe("the scan", function()
		it("runs at SCAN_HZ and not once per call", function()
			local _seen = fresh(bin)
			Lobby.step(1000, {})
			local after = Lobby.stats().scans
			-- Ten calls inside one scan window are one scan.
			for index = 1, 10 do
				Lobby.step(1000 + index * 0.001, {})
			end
			expect(Lobby.stats().scans).to.equal(after)
			Lobby.step(1000 + 1 / CFG.SCAN_HZ, {})
			expect(Lobby.stats().scans).to.equal(after + 1)
		end)
	end)

	describe("the teardown", function()
		it("takes the lobby down and hands back everything it wrote", function()
			local _seen = fresh(bin)
			Lobby.step(1000, {})
			local player = occupant(41, padAt(1), bin)
			Lobby.step(1001, { player })
			-- THE DEADLINE ONLY EXISTS ONCE HIS PAD IS COUNTING DOWN (task 182), so this walks the
			-- scan forward to the point `stop` actually has something of his to hand back.
			local at = 1001
			while at < 1001 + CFG.PADS.PICK_TIMEOUT_SECONDS + 2 / CFG.SCAN_HZ do
				at += 1 / CFG.SCAN_HZ
				Lobby.step(at, { player })
			end
			expect(type(player.attributes[Data.LEAVE_AT_ATTRIBUTE])).to.equal("number")
			expect(Lobby.isBuilt()).to.equal(true)

			Lobby.stop()
			expect(Lobby.isBuilt()).to.equal(false)
			expect(bin:FindFirstChild(Data.FOLDER_NAME)).to.equal(nil)
			-- `stop` hands back exactly what it wrote: this player's deadline and his respawn point.
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(nil)
			expect(player.RespawnLocation).to.equal(nil)
			Lobby.forget(41)
			-- And a step after a stop does nothing at all rather than erroring.
			Lobby.step(2000, { player })
		end)
	end)

	-- ----------------------------------------------------------- THE ROLE SWITCH (task 229)
	--
	-- KAREN, 2026-10-21: *"we also need to have posibility to choose once you have a card always
	-- hunter maybe sometimes I want to be a beater we need to find a way to do that"*.
	--
	-- THE OWNER, DRIVEN BY HAND: the door and its five verdicts, its own rate bucket, the level
	-- reset on this owner's own scan, the frozen memo the drive reads, and the teardown. The PURE
	-- half (`Lobby.roleAllowed`, `Lobby.wishFor`) is in `tests/server/lobby.spec.luau`; the ROSTER
	-- rule is `match_roster.spec`'s.
	-- Design: docs/design/role-switch.md (sections 4, 6, 15.3)
	describe("the role a man asks for, for one drive", function()
		-- THE OWNERSHIP READER IS A SETTER AND NOT A `start` FIELD, because in production
		-- `Lobby.start` runs before `Shop.start` decides whether there is a shop at all.
		local function owning(seen: any, ...)
			local ids = { ... }
			for _, userId in ipairs(ids) do
				seen.owners[userId] = true
			end
			Lobby.setAlwaysHunters(function()
				return seen.owners
			end)
		end

		afterEach(function()
			-- THE READER IS MODULE STATE, so it is handed back after every case -- otherwise one
			-- case's owner would be the next case's.
			Lobby.setAlwaysHunters(nil)
		end)

		it("refuses a payload that is not one of the two words, and tells nobody what would work", function()
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			for _, forged in ipairs({
				{},
				{ role = "Drivers" },
				{ role = "HUNTER" },
				{ role = 1 },
				{ role = true },
				{ pad = 1, size = 1 },
				-- ONE FIELD AND NOTHING ELSE (review round 1, note 1). A packet carrying a legal word
				-- PLUS anything more is not a client of this build, and accepting it while silently
				-- ignoring the extra is how a second field comes to be read by accident later --
				-- `Shop.checkRequest`'s *"an argument nobody reads is an argument nobody checked"*.
				{ role = Data.ROLE_WISH.BEATER, pad = 1 },
				{ role = Data.ROLE_WISH.HUNTER, size = 4 },
				"beater",
				42,
			}) do
				local reply = Lobby.onRoleRequest(man, forged, 1000)
				expect(reply.ok).to.equal(false)
				expect(reply.refused).to.equal("bad-request")
			end
			expect(Lobby.stats().badRequests >= 10).to.equal(true)
			-- A REFUSED PAYLOAD IS NOT AN ASK: `roleAsks` counts only the ones the game ANSWERED (review
			-- round 1, note 2).
			expect(Lobby.stats().roleAsks).to.equal(0)
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(nil)
		end)

		it("refuses a man who does not own the place, and counts it APART from a forgery", function()
			-- `Lobby.stats`' OWN SPLIT, written in that file: *"a FORGED payload is a different fact
			-- from a legal request the game said no to, because counting it as a bad request would
			-- hide a mis-wired provider inside the forgery counter"*. A build where
			-- `setAlwaysHunters` was never called would otherwise read as an attack.
			local seen = fresh(bin)
			owning(seen, 7)
			local stranger = occupant(8, padAt(2), bin)
			local reply = Lobby.onRoleRequest(stranger, { role = Data.ROLE_WISH.BEATER }, 1000)
			expect(reply.ok).to.equal(false)
			expect(reply.refused).to.equal("not-an-owner")
			expect(Lobby.stats().refusedBy["not-an-owner"]).to.equal(1)
			expect(Lobby.stats().badRequests).to.equal(0)
			expect(stranger:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(nil)
			expect(next(Lobby.beaterWishes())).to.equal(nil)
		end)

		it("refuses every ask when no ownership reader was wired at all", function()
			-- THE SWITCH-OFF STORY, BY PARAMETER: with the shop off `ForestTestBoot` never calls
			-- `setAlwaysHunters`, so nothing can be asked, nothing is written and no control is built.
			fresh(bin)
			local man = occupant(7, padAt(1), bin)
			local reply = Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 1000)
			expect(reply.refused).to.equal("not-an-owner")
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(nil)
		end)

		it("writes the wish inside the call, so what he waits for is one network hop", function()
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			local reply = Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 1000)
			expect(reply.ok).to.equal(true)
			expect(reply.role).to.equal(Data.ROLE_WISH.BEATER)
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.BEATER)
			expect(Lobby.beaterWishes()[7]).to.equal(true)
			expect(Lobby.stats().roleAsks).to.equal(1)
			-- ...AND ASKING FOR HUNTER AGAIN DROPS THE ROW rather than storing a second state.
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.HUNTER }, 1001).ok).to.equal(true)
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.HUNTER)
			expect(next(Lobby.beaterWishes())).to.equal(nil)
		end)

		it("refuses a change of mind once the truck has him", function()
			-- THE DOOR USES THE EARLIER FACT ON PURPOSE -- *may he still change his mind* -- and the
			-- reset uses the later one. `inDrive` becomes true first, so the two cannot contradict.
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			seen.inDrive[7] = true
			local reply = Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 1000)
			expect(reply.refused).to.equal("in-a-drive")
			expect(Lobby.stats().refusedBy["in-a-drive"]).to.equal(1)
			expect(next(Lobby.beaterWishes())).to.equal(nil)
		end)

		it("has its own rate bucket, so a role ask never costs him his size pick", function()
			-- SHARING THE PAD'S BUCKET WOULD MAKE "press BEATER, then press 1 / 1" LOSE THE PICK,
			-- because `Lobby.padRateLimited` writes its row on every accepted call. One number, two
			-- buckets.
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 2000).ok).to.equal(true)
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.HUNTER }, 2000.05)).to.equal(nil)
			expect(Lobby.stats().roleRateLimited).to.equal(1)
			-- THE WISH IS UNCHANGED by a refused ask.
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.BEATER)
			-- ...AND THE PAD STILL ANSWERS IN THE SAME 1/10 s. The pad must be in `sizing` with him
			-- first on it, which one scan with him standing there arranges.
			Lobby.step(2000, { man })
			expect(Lobby.padOf(1).state).to.equal(Pads.SIZING)
			expect(Lobby.onPadRequest(man, { pad = 1, size = 2 }, 2000.06).ok).to.equal(true)
		end)

		it("clears the wish ONE SCAN after the drive has given him a side, and not before", function()
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 3000).ok).to.equal(true)
			-- ENROLLED BUT NOT YET ASSIGNED: `inDrive` is true and `assignedTeam` is nil, which is
			-- the state `Lobby.depart` -> `Match.enrol` leaves for at least one `Match` step. A reset
			-- keyed on `inDrive` would clear the wish HERE -- before the assignment that is supposed
			-- to spend it -- and the feature would silently do nothing.
			seen.inDrive[7] = true
			Lobby.step(3001, { man })
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.BEATER)
			expect(Lobby.beaterWishes()[7]).to.equal(true)
			-- THE DRIVE HAS SEATED HIM: one scan later it reads HUNTER.
			seen.assigned[7] = "Drivers"
			Lobby.step(3002, { man })
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.HUNTER)
			expect(next(Lobby.beaterWishes())).to.equal(nil)
			-- ...AND IT STAYS CLEARED. The reconciliation can only ever clear: nothing re-invents a
			-- wish, through a dismissal or a second drive or anything else.
			seen.assigned[7] = nil
			seen.inDrive[7] = false
			Lobby.step(3003, { man })
			Lobby.step(3004, { man })
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.HUNTER)
			expect(next(Lobby.beaterWishes())).to.equal(nil)
		end)

		it("keeps the wish of a party that cancelled before any assignment", function()
			-- CORRECT, AND IT FALLS OUT OF THE READER CHOICE RATHER THAN NEEDING A RULE: a man who
			-- enrolled and was dismissed before any assignment never got the drive he asked for.
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 4000).ok).to.equal(true)
			seen.inDrive[7] = true
			Lobby.step(4001, { man })
			seen.inDrive[7] = false
			Lobby.step(4002, { man })
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.BEATER)
		end)

		it("writes the attribute once per CHANGE and not once per scan", function()
			-- `clearLeaveAt`'s AND `setPadMine`'s DISCIPLINE: the rule is asked every scan and
			-- written only when it differs, so this is one replicated write per change and not ten a
			-- second. A `roleWrites` that climbed with `scans` would mean it had stopped being
			-- edge-triggered.
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 5000).ok).to.equal(true)
			local writes = Lobby.stats().roleWrites
			local scans = Lobby.stats().scans
			for index = 1, 10 do
				Lobby.step(5000 + index, { man })
			end
			expect(Lobby.stats().scans > scans).to.equal(true)
			expect(Lobby.stats().roleWrites).to.equal(writes)
		end)

		it("hands the drive a FROZEN memo, the same table until something changes", function()
			-- `Economy.alwaysHunters`' OWN DEVICE AND ITS OWN STATED REASON: the drive fills this on
			-- EVERY event, so a clone per call would be ~60 table builds a second for a table that
			-- changes at most twice a drive.
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 6000).ok).to.equal(true)
			local first = Lobby.beaterWishes()
			expect(table.isfrozen(first)).to.equal(true)
			expect(Lobby.beaterWishes()).to.equal(first)
			expect(function()
				(first :: any)[99] = true
			end).to.throw()
			-- ...AND A DIFFERENT TABLE ONCE THE VALUE MOVES, so a reader can never be handed a stale
			-- answer that happens to be the same object.
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.HUNTER }, 6001).ok).to.equal(true)
			expect(Lobby.beaterWishes()).never.to.equal(first)
			expect(next(Lobby.beaterWishes())).to.equal(nil)
		end)

		it("forgets a man who leaves, and hands the attribute back when it stops", function()
			-- THE TEARDOWN ASSERTION EVERY OWNER'S SPEC IN THIS REPOSITORY MAKES. A logout is also
			-- what makes *"nothing is persisted"* true without a rule: the wish dies with him.
			local seen = fresh(bin)
			owning(seen, 7, 8)
			local man = occupant(7, padAt(1), bin)
			local other = occupant(8, padAt(2), bin)
			expect(Lobby.onRoleRequest(man, { role = Data.ROLE_WISH.BEATER }, 7000).ok).to.equal(true)
			expect(Lobby.onRoleRequest(other, { role = Data.ROLE_WISH.BEATER }, 7000).ok).to.equal(true)
			Lobby.forget(7)
			expect(Lobby.beaterWishes()[7]).to.equal(nil)
			expect(Lobby.beaterWishes()[8]).to.equal(true)
			-- ...AND HIS BUCKET WENT WITH HIM, so a re-join is not rate-limited by his last session.
			expect(Lobby.roleRateLimited(7, 7000.01)).to.equal(false)
			Lobby.stop()
			expect(other:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(nil)
			expect(next(Lobby.beaterWishes())).to.equal(nil)
		end)

		it("asks nothing of a man who owns nothing, on any scan", function()
			-- THE ATTRIBUTE IS NEVER WRITTEN FOR A NON-OWNER, which is what makes *"invisible to a
			-- non-owner"* structural: there is no value for either panel to draw from.
			local seen = fresh(bin)
			owning(seen, 7)
			local man = occupant(7, padAt(1), bin)
			local stranger = occupant(8, padAt(2), bin)
			Lobby.step(8000, { man, stranger })
			expect(man:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(Data.ROLE_WISH.HUNTER)
			expect(stranger:GetAttribute(Data.ROLE_WISH_ATTRIBUTE)).to.equal(nil)
		end)
	end)
end
