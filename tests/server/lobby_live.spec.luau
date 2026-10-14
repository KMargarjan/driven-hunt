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

local CFG = Data.CONFIG
local ANCHOR = Data.anchorFor("forest-test") :: any
local SHELF = 153

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
			enrol = function(player: any): boolean
				table.insert(seen.enrolled, player.UserId)
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
			local body = (bin:FindFirstChild(Data.FOLDER_NAME) :: Instance):FindFirstChild(Data.KEEPER_NAME, true)
			expect(body).to.be.ok()
			expect((body :: Instance):FindFirstChild(Data.PROMPT_NAME, true)).to.be.ok()
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

		it("starts a deadline on his own Player when he steps in, and clears it when he steps out", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local spot = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z) + CFG.SPOT.OFFSET
			local player = occupant(22, spot, bin)
			Lobby.step(1001, { player })
			-- ONE ATTRIBUTE, written by the server, counted down by his own client. No new wire.
			local deadline = player.attributes[Data.LEAVE_AT_ATTRIBUTE]
			expect(type(deadline)).to.equal("number")
			expect(#seen.enrolled).to.equal(0)
			-- ...AND WRITTEN ONCE, ON THE EDGE (review round 1, note 3). It used to be rewritten on
			-- every scan -- ~50 replicated writes per walk-in, each recomputing the same deadline.
			Lobby.step(1001.5, { player })
			Lobby.step(1001.8, { player })
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(deadline)

			player.root.Position = spot + Vector3.new(40, 0, 0)
			Lobby.step(1002, { player })
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(nil)
			expect(#seen.enrolled).to.equal(0)
			expect(Lobby.stats().cancels).to.equal(1)
		end)

		it("enrols him exactly once after the countdown, with his respawn point cleared first", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local spot = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z) + CFG.SPOT.OFFSET
			local player = occupant(23, spot, bin)
			Lobby.step(1001, { player })
			expect(#seen.enrolled).to.equal(0)
			Lobby.step(1001 + CFG.COUNTDOWN_SECONDS, { player })
			expect(#seen.enrolled).to.equal(1)
			expect(seen.enrolled[1]).to.equal(23)
			-- CLEARED BEFORE THE ENROLMENT, because `enrol` reaches `LoadCharacter` inside the same
			-- call: with the lodge still set, the engine would put the new character there and the
			-- drive's own pivot would have to beat it.
			expect(player.RespawnLocation).to.equal(nil)
			expect(player.attributes[Data.LEAVE_AT_ATTRIBUTE]).to.equal(nil)

			-- ONE WALK IS ONE ENROLMENT, however many scans follow.
			seen.inDrive[23] = true
			Lobby.step(1001 + CFG.COUNTDOWN_SECONDS + 1, { player })
			Lobby.step(1001 + CFG.COUNTDOWN_SECONDS + 2, { player })
			expect(#seen.enrolled).to.equal(1)
		end)

		it("leaves a player who is in the drive entirely alone", function()
			local seen = fresh(bin)
			Lobby.step(1000, {})
			local spot = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z) + CFG.SPOT.OFFSET
			local player = occupant(24, spot, bin)
			seen.inDrive[24] = true
			Lobby.step(1001, { player })
			Lobby.step(1001 + CFG.COUNTDOWN_SECONDS + 1, { player })
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
			local spot = Vector3.new(ANCHOR.x, SHELF, ANCHOR.z) + CFG.SPOT.OFFSET
			local player = occupant(41, spot, bin)
			Lobby.step(1001, { player })
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
