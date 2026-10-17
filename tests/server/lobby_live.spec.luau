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
		inDrive = {} :: { [number]: boolean },
		held = {} :: { [number]: boolean },
		ground = SHELF :: any,
		dressed = 0,
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
			terrain = {
				FillBlock = function()
					seen.fills += 1
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
end
