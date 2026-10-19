-- bots_live.spec: THE RIGS THEMSELVES -- real Instances, but no Play of its own, no frames hunted and
-- no avatar service. Karen's rule holds: this drives the LOGIC that touches the world (build, dress,
-- place, walk, gather, destroy) by stepping `Bots` by hand.
--
-- IT DOES NOT START A `Bots` OF ITS OWN, and that is deliberate, for exactly the reason
-- `match_live.spec` does not start a `Match`: `ServerScriptService.Bots` is a singleton that
-- `MatchBoot` has already started with the real dressing seam and the real horn, and a second
-- `start` would assert ("called twice") or stop production under the drive's feet. So this asserts on
-- production, with a FAKE RIG SOURCE swapped in and put back -- which is the one seam that exists to
-- be swapped (`Bots.setRigSource`, the shape `Boar.setModelSource` already has).
--
-- WITH THE FLAG OFF -- which is how it ships -- the drive's own `syncBots` returns before it asks
-- `Bots` anything at all, so this spec owns the rigs while it runs and clears up after each case.
-- That is also the claim in "the switch is off" below.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/bots.md (sections 8, 9, 11, 16.2)
-- Note:   docs/research/2026-10-12-bots.md
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Bots = require(ServerScriptService:WaitForChild("Bots"))
local HornData = require(game:GetService("ReplicatedStorage"):WaitForChild("Horn"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))
local Rig = Bots.Rig

-- A BODY WITH ENOUGH OF A BODY IN IT: a Humanoid, a root, and the two limbs the outfit hangs on
-- (`Body.dress` finds limbs by name, with an R6 fallback). No avatar service, no web call, nothing
-- to load -- which is why the rig source is a seam at all.
local function fakeRig(): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Parent = model
	model.PrimaryPart = root
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(2, 1.6, 1)
	torso.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	return model
end

local LINE = { position = Vector3.new(0, 10, 0), normal = Vector3.new(0, 0, 1) }
local POSTS = {
	{ Position = Vector3.new(-60, 11, 0), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(0, 11, 0), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(60, 11, 0), Size = Vector3.new(6, 2, 6) },
}

local function slotsFor(hunters: number, beaters: number)
	local place = function(_markers, team, index)
		if team == "Shooters" then
			return CFrame.new(index * 30 - 90, 14, 0)
		end
		return CFrame.new(0, 10, 240)
	end
	return Match.botSlotsFor(
		{ posts = POSTS, line = LINE },
		place,
		{ hunters = 0, beaters = 0 },
		{ hunters = hunters, beaters = beaters },
		Match.CONFIG
	)
end

-- Steps until every slot has a body, or the build budget has had its chances. `BUILD_PER_STEP` is 2,
-- so eight rigs need four steps; ten is room to spare and it is still not a frame hunt -- the fake
-- source does not yield, so this returns at once.
local function stepUntilBuilt(want: number)
	for _ = 1, 10 do
		Bots.step(0.2)
		if Bots.count() >= want then
			return
		end
	end
end

return function()
	describe("the rigs", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		it("builds one body per slot, under Workspace.DriveBots, and fill itself never yields", function()
			Bots.setRigSource(fakeRig)
			local before = os.clock()
			local made = Bots.fill(slotsFor(4, 4))
			-- NEVER YIELDS: the build is spawned off the step loop, because
			-- `CreateHumanoidModelFromDescription` is documented to load assets and a yield inside
			-- the drive's own dispatch is the hazard `Phase`'s ordering comment was paid for twice.
			expect(os.clock() - before < 0.05).to.equal(true)
			expect(made.hunters).to.equal(4)
			expect(made.beaters).to.equal(4)
			expect(Bots.count()).to.equal(0) -- nothing is built yet: `fill` only records

			stepUntilBuilt(8)
			expect(Bots.count()).to.equal(8)
			expect(Bots.count("Shooters")).to.equal(4)
			expect(Bots.count("Drivers")).to.equal(4)
			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME)
			expect(folder).to.be.ok()
			expect(#(folder :: Folder):GetChildren()).to.equal(8)
		end)

		it("gives every bot a NON-NUMERIC id, which is what keeps it out of the score", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(2, 2))
			stepUntilBuilt(4)
			local threats = Bots.threats()
			expect(#threats).to.equal(4)
			for _, threat in ipairs(threats) do
				-- THE WHOLE MECHANISM, in one assertion. `Match.playerDrivers` filters by
				-- `tonumber(id)`, `Match.pushCreditable` refuses a non-number userId, and
				-- `Phase.participantIds` reads a table only a Player is written into -- so a bot
				-- cannot be scored, cannot be push-credited and cannot be protected by the safety
				-- rule, structurally rather than by a filter somebody has to remember.
				expect(tonumber(threat.id)).to.equal(nil)
			end
			-- ...and the drive's own filter agrees, over the whole list.
			expect(#Match.playerDrivers(threats)).to.equal(0)
			-- ...and a horn blast from a bot pays nobody.
			expect(Match.creditPush(nil, { "b1", "b2" })).to.equal(0)
		end)

		it("tells a boar what each bot IS, and marks none of them phantom", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(2, 2))
			stepUntilBuilt(4)
			local drivers, shooters = 0, 0
			for _, threat in ipairs(Bots.threats()) do
				if threat.kind == "driver" then
					drivers += 1
				elseif threat.kind == "shooter" then
					shooters += 1
				end
				-- NO `phantom` MARK, because somebody IS standing there: that mark exists to tell
				-- `Boar.CONFIG.PACE` that a "driver" this close is nobody, and a visible beater is
				-- the opposite of that. This is the one assertion behind "the bots push for real".
				expect((threat :: any).phantom).to.equal(nil)
			end
			expect(drivers).to.equal(2)
			expect(shooters).to.equal(2)

			-- `beaters()` is the driver subset, with positions -- the shape `Match.beaterCrossing`
			-- measures against `Match.crossedLine`.
			local beaters = Bots.beaters()
			expect(#beaters).to.equal(2)
			for _, beater in ipairs(beaters) do
				expect(typeof(beater.position)).to.equal("Vector3")
			end
		end)

		it("is level-triggered: the same slots build nothing new, fewer slots hand bodies back", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(4, 4))
			stepUntilBuilt(8)
			local builtOnce = Bots.stats().built

			-- IDEMPOTENT: ioquake3's own shape, read as a level rather than an edge. Calling it again
			-- with the same answer must not be eight more bodies.
			Bots.fill(slotsFor(4, 4))
			stepUntilBuilt(8)
			expect(Bots.stats().built).to.equal(builtOnce)
			expect(Bots.count()).to.equal(8)

			-- ...AND THE SYMMETRY: two real players joining as hunters is two fewer bot hunters, and
			-- the bodies really go.
			Bots.fill(slotsFor(2, 4))
			expect(Bots.count("Shooters")).to.equal(2)
			expect(Bots.count("Drivers")).to.equal(4)
			expect(Bots.desired()).to.equal(6)

			-- ...and an EMPTY slot list is how every body is handed back.
			Bots.fill({})
			expect(Bots.count()).to.equal(0)
			expect(Bots.desired()).to.equal(0)
		end)

		it("destroys everything on clear, and leaves no folder behind", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(4, 4))
			stepUntilBuilt(8)
			expect(Bots.clear()).to.equal(8)
			expect(Bots.count()).to.equal(0)
			expect(Workspace:FindFirstChild(Rig.FOLDER_NAME)).to.equal(nil)
		end)

		it("destroys a body that arrives after its drive has gone (the epoch)", function()
			-- THE YIELD THAT CROSSES A DRIVE BOUNDARY. A build carries the epoch it started on; if
			-- the drive has cleared since, the rig destroys itself instead of standing in the wood
			-- with nobody owning it. It is `Body.dressWhenLoaded`'s `watching[userId] ~= row` guard
			-- and `Horn.blow`'s `lastBlast == at` guard, applied to this system's one yield.
			local held: { Model } = {}
			local release: (() -> ())? = nil
			Bots.setRigSource(function()
				local model = fakeRig()
				table.insert(held, model)
				-- Yield until this spec says go, which is what a slow avatar load looks like.
				local waiting = true
				release = function()
					waiting = false
				end
				while waiting do
					task.wait(0.02)
				end
				return model
			end)
			Bots.fill(slotsFor(1, 0))
			Bots.step(0.2)
			expect(Bots.stats().staleBuilds).to.equal(0)

			local staleBefore = Bots.stats().staleBuilds
			Bots.clear() -- the drive is over while the body is still being made
			if release then
				(release :: () -> ())()
			end
			local deadline = os.clock() + 2
			while Bots.stats().staleBuilds == staleBefore and os.clock() < deadline do
				task.wait(0.05)
			end
			expect(Bots.stats().staleBuilds).to.equal(staleBefore + 1)
			expect(Bots.count()).to.equal(0)
			for _, model in ipairs(held) do
				expect(model.Parent).to.equal(nil) -- it really went
			end
			expect(Workspace:FindFirstChild(Rig.FOLDER_NAME)).to.equal(nil)
		end)
	end)

	describe("what a bot wears, and who dresses it", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		it("is dressed once per body, by Match.Body and nothing else", function()
			Bots.setRigSource(fakeRig)
			local before = Bots.stats().dressed
			Bots.fill(slotsFor(2, 2))
			stepUntilBuilt(4)
			-- ONE DRESSING PATH: `MatchBoot` hands `Match.Body.dress` in as the seam, so this count
			-- going up is the one owner of what a character wears having done the work. A second
			-- dressing path would be the thing rule 3 exists to prevent.
			expect(Bots.stats().dressed - before).to.equal(4)
			expect(Bots.stats().dressFailed).to.equal(0)

			-- ...and it shows on the body: the base colour is written where `Body.paint` writes it.
			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder
			local one = folder:GetChildren()[1] :: Model
			local colors = one:FindFirstChildOfClass("BodyColors")
			expect(colors).to.be.ok()
			expect((colors :: BodyColors).TorsoColor3).to.equal(Match.Body.BASE_COLOR)
		end)
	end)

	describe("the walk", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		it("does not move until the drive says GO, which is how a bot is held at the line", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 2))
			stepUntilBuilt(2)
			expect(Bots.released()).to.equal(false)
			-- A BOT IS NOT IN `Body`'S `held` TABLE -- that is keyed by userId -- so "held through the
			-- countdown exactly as a player is" is this one boolean instead.
			expect(Match.Body.isHolding(0)).to.equal(false)
			Bots.step(0.2)
			expect(Bots.stats().walking).to.equal(0)

			expect(Bots.go()).to.equal(2)
			expect(Bots.released()).to.equal(true)
			Bots.step(0.2)
			expect(Bots.stats().walking).to.equal(2)
		end)

		it("is held through the START FANFARE too, and goes on the same dispatch as the players", function()
			-- ROUND 1, FINDING 1, AND IT IS KAREN'S OWN ITEM: *"a beater (player AND bot) cannot move
			-- until the START FANFARE has sounded"*. Task 168 deferred the PLAYERS' release by
			-- `Phase.goHoldSeconds` (2.18 s) and left `syncBots` calling `bots.go()` on the phase --
			-- so for the whole fanfare a player beater stood anchored at the line while the bot line
			-- beside her walked off and blew.
			--
			-- THE RULE IS `Match.botsMayGo` AND IT IS THE PLAYERS' OWN (`Phase.lineHeld`), so the two
			-- cannot drift: this case fails on the old code because the rule did not exist.
			expect(Match.botsMayGo({ phase = "Running", goFreed = true })).to.equal(true)
			-- ...and NOT while the line is still held, which is the whole fix.
			expect(Match.botsMayGo({ phase = "Running", goFreed = false })).to.equal(false)
			expect(Match.botsMayGo({ phase = "Assigning", goFreed = true })).to.equal(false)
			expect(Match.botsMayGo({ phase = "Scoring", goFreed = true })).to.equal(false)
			expect(Match.botsMayGo({ phase = "Waiting", goFreed = true })).to.equal(false)
			expect(Match.botsMayGo(nil)).to.equal(false)

			-- AND THE CONSEQUENCE, WITH REAL RIGS: held, a bot neither walks nor blows.
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 2))
			stepUntilBuilt(2)
			expect(Bots.released()).to.equal(false)
			local blastsBefore = Bots.stats().blasts
			-- EIGHTY SECONDS OF HELD TIME, with the clock handed in (`Bots.step`'s own test seam)
			-- rather than fifty steps of the real one -- so "every bot's horn was due and none of them
			-- blew" is a measurement and not a hope. It is past `HORN.EVERY_SECONDS.max`, which task
			-- 174 raised to 60 s, so the loop still outlasts the window it is about.
			local heldFrom = os.clock()
			for index = 1, 50 do
				Bots.step(0.2, heldFrom + index * 1.6)
			end
			expect(Bots.stats().walking).to.equal(0)
			expect(Bots.stats().blasts).to.equal(blastsBefore)

			-- ...and the moment the drive says go -- which is the dispatch the players are freed on --
			-- the same two things start.
			expect(Bots.go()).to.equal(2)
			Bots.step(0.2)
			expect(Bots.stats().walking).to.equal(2)
			TestKit.note(
				string.format(
					"bots: held through the fanfare -- %d walking and %d blast(s) in 80 s of held time,"
						.. " then %d walking on GO",
					0,
					Bots.stats().blasts - blastsBefore,
					Bots.stats().walking
				)
			)
		end)

		it("counts a bot that reaches its goal, and stops walking it", function()
			Bots.setRigSource(fakeRig)
			-- A slot whose start IS its goal: it has arrived the first time it is looked at.
			Bots.fill({
				{
					id = "bot-beater-1",
					team = "Drivers",
					from = CFrame.new(0, 10, 0),
					to = Vector3.new(0, 10, 0),
					lane = 1,
				},
			})
			stepUntilBuilt(1)
			local before = Bots.stats().arrived
			Bots.go()
			Bots.step(0.2)
			expect(Bots.stats().arrived).to.equal(before + 1)
		end)

		it("stands the bots where the results scene says, and stops them walking", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 2))
			stepUntilBuilt(2)
			Bots.go()
			local ring = Match.Scene.ringLayout(Vector3.new(0, 10, -24), 4, Match.CONFIG)
			-- SLOTS AFTER THE PLAYERS: `applyScene` moves the participants into 1..#ids with
			-- `Body.stand` and then hands the rest of the ring over, so one real player and two bots
			-- is a ring of three with the person first.
			expect(Bots.gather(ring, 3)).to.equal(2)
			expect(Bots.released()).to.equal(false)
			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder
			local placed = 0
			for _, child in ipairs(folder:GetChildren()) do
				local root = (child :: Model).PrimaryPart
				if root then
					for index = 3, 4 do
						if (root.Position - ring[index].Position).Magnitude < 0.1 then
							placed += 1
						end
					end
				end
			end
			expect(placed).to.equal(2)
		end)
	end)

	describe("a stuck bot, and the walk clock (round 2, findings 1 and 3)", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		-- A FAKE RIG DOES NOT WALK: it is a Part with a Humanoid and nothing to stand on, so it stays
		-- exactly where it was placed. That makes it the perfect STUCK bot, and the two optional
		-- arguments on `Bots.step` -- the clock and the clearance reader -- are what let this case
		-- exist without spending `STUCK_SECONDS` of real time in the suite's own budget.
		local function walkerSlot()
			return {
				{
					id = "bot-beater-1",
					team = "Drivers",
					from = CFrame.new(0, 10, 240),
					to = Vector3.new(0, 10, -20),
					lane = 1,
				},
			}
		end

		it("MOVES a bot that has stopped, WITH A READER THAT SAYS THE WAY IS CLEAR", function()
			-- THE END-TO-END OF ROUND 1'S FINDING 1, kept and RE-POINTED by task 208. In the Forest
			-- Test `roomToStand` is injected, so `room` was true and the forced branch was dead: a
			-- stuck bot was counted and never moved. The reader here still answers `true` for every
			-- point -- the inverted case -- and the bot must still be moved.
			--
			-- WHAT CHANGED IS WHO MOVES IT. Until task 208 the recovery was `Lane.clearAim`'s
			-- one-step nudge on the FOUR-SECOND edge, which the re-issue cadence then discarded nine
			-- times in ten (note section 4.3); it is now the fast window's ladder, which holds its
			-- decision and issues it at once. So this asserts `recoverSide` where it used to assert
			-- `sideSteps`, and the long counter is still counted for the report.
			local clear = function()
				return true
			end
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 1000, clear)
			Bots.go()
			Bots.step(0.2, 1000, clear) -- the first released step: the walk and both windows start
			local stuckBefore = Bots.stats().stuck
			local recoveredBefore = Bots.stats().recoveries
			Bots.step(0.2, 1000.5, clear) -- inside even the FAST window: nothing yet
			expect(Bots.stats().stuck).to.equal(stuckBefore)
			expect(Bots.stats().recoveries).to.equal(recoveredBefore)

			-- ...past `STUCK_FAST_SECONDS`, having moved nowhere: it is recovered at once.
			Bots.step(0.2, 1000 + Bots.CONFIG.STUCK_FAST_SECONDS + 0.1, clear)
			expect(Bots.stats().recoveries).to.equal(recoveredBefore + 1)
			expect(Bots.stats().recoverSide).to.equal(1)

			-- ...and the LONG window still counts, because that is what `[bots]` prints.
			Bots.step(0.2, 1000 + Bots.CONFIG.STUCK_SECONDS + 0.1, clear)
			expect(Bots.stats().stuck).to.equal(stuckBefore + 1)
		end)

		it("measures the WALK, not the stuck window", function()
			-- ROUND 1'S FINDING 3: the arrival measured `at - bot.movedAt`, and `movedAt` is the
			-- stuck window's own stamp, re-set every `STUCK_SECONDS` -- so a 29-second walk could
			-- never print as more than about four. That number is the one Karen's end-of-drive
			-- decision rests on (`docs/design/bots.md` section 5.2).
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 2000)
			Bots.go()
			Bots.step(0.2, 2000) -- the first released step stamps the walk's start

			-- THIRTY SECONDS LATER it reaches the goal -- seven stuck windows deep, which is the
			-- whole point: the old maths could not have reported more than one of them. The move is
			-- made through `Bots.Rig.place`, the one writer of a bot's body, rather than by poking
			-- the part.
			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder
			local body = folder:FindFirstChild("bot-beater-1") :: Model
			expect(body).to.be.ok()
			-- AT THE LANE'S OWN GOAL, which since task 167 is the one the DRIVE stated: the slot
			-- carries this lane's own start and its own goal, and `Bots.laneOf` is the identity.
			local goal = walkerSlot()[1].to :: Vector3
			Rig.place(body, CFrame.new(goal), false)
			Bots.step(0.2, 2030)
			local walked = Bots.stats().walkSeconds
			expect(walked >= 29).to.equal(true)
			expect(walked <= 31).to.equal(true)
			-- The bug it replaces could not have exceeded this.
			expect(walked > Bots.CONFIG.STUCK_SECONDS + 1).to.equal(true)
			expect(string.find(Bots.report(1), "arrived in 30.0s")).to.be.ok()
		end)

		it("resets the per-drive counters when the drive's rigs go", function()
			-- The line says `[bots] drive N`, so a lifetime total under it reads as a measurement and
			-- is not one (round 1 note).
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 1))
			stepUntilBuilt(1)
			Bots.go()
			Bots.step(0.2, 3000)
			Bots.step(0.2, 3000 + Bots.CONFIG.STUCK_SECONDS + 0.1)
			expect(Bots.stats().stuck > 0).to.equal(true)
			Bots.clear()
			expect(Bots.stats().stuck).to.equal(0)
			expect(Bots.stats().walkSeconds).to.equal(0)
			expect(Bots.stats().arrived).to.equal(0)
			-- ...and the LIFETIME ones stay, because they answer a question about the session.
			expect(Bots.stats().built > 0).to.equal(true)
		end)
	end)

	describe("the legs move (round 2, Director item -- 161a(c) closed)", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		it("loads Roblox's own default R15 walk and idle onto every bot", function()
			-- WITHOUT THIS A BOT SLIDES: a rig built by the engine carries no `Animate` script, which
			-- comes from `StarterCharacterScripts` and only a PLAYER's character gets one. This is
			-- the first thing Karen would see.
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(1, 1))
			stepUntilBuilt(2)
			local s = Bots.stats()
			-- THREE CLIPS PER BODY SINCE TASK 164 -- the gait pair plus the tool pose -- and a
			-- failure shows as a NUMBER rather than as a statue nobody can explain. If `clipsFailed`
			-- is ever non-zero the ids in `Rig.CLIPS` and `Rig.TOOL_CLIP` are what to look at, and
			-- the count comes from what `Rig.loadClips` says it TRIED rather than from a literal
			-- here, so the next clip does not need this line changed.
			local perBody = 1
			for _ in pairs(Rig.CLIPS) do
				perBody += 1
			end
			-- ...AND A FOURTH SINCE TASK 166, the horn-to-mouth pose, when this session managed to
			-- register one. `Rig.blowAnimationId` is memoised, so asking costs nothing, and asking
			-- rather than adding 1 keeps the count honest in a session where the registration failed
			-- -- the one case where a bot really does load three clips and not four.
			if Rig.blowAnimationId(Rig.BLOW) ~= nil then
				perBody += 1
			end
			-- ...AND A FIFTH SINCE TASK 206, the horn-at-the-side pose, asked for the same way and
			-- for the same reason: `Rig.carryAnimationId` is memoised, and asking rather than
			-- adding 1 keeps the count honest in a session where that registration failed.
			if Rig.carryAnimationId(Rig.CARRY) ~= nil then
				perBody += 1
			end
			expect(s.clipsLoaded + s.clipsFailed).to.equal(perBody * 2)
			expect(s.clipsFailed).to.equal(0)

			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder
			for _, child in ipairs(folder:GetChildren()) do
				local humanoid = (child :: Model):FindFirstChildOfClass("Humanoid")
				expect(humanoid:FindFirstChildOfClass("Animator")).to.be.ok()
			end
		end)

		it("plays walk while walking and idle once it is standing", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 1))
			stepUntilBuilt(1)
			Bots.go()
			Bots.step(0.2, 4000)
			local clips = Bots.clipsOf("bot-beater-1")
			expect(clips).to.be.ok()
			expect((clips :: any).playing).to.equal("walk")

			-- Stood in the results ring: it is standing, not walking.
			Bots.gather(Match.Scene.ringLayout(Vector3.new(0, 10, 0), 2, Match.CONFIG), 1)
			expect((Bots.clipsOf("bot-beater-1") :: any).playing).to.equal("idle")
		end)

		it("gives a stander idle from the moment it exists", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(1, 0))
			stepUntilBuilt(1)
			expect((Bots.clipsOf("bot-hunter-1") :: any).playing).to.equal("idle")
		end)

		it("gives a WALKER idle from the moment it exists too, which is the whole countdown", function()
			-- TASK 164. A walker only reaches the step loop's gait branch once the drive is
			-- RELEASED, and that is 15 s of countdown (task 163) in which it had no clip playing at
			-- all -- four beaters on the start line with their arms in the rig's bind pose. Karen
			-- sees that at the top of every drive. `Bots.go()` is deliberately NOT called here:
			-- this is the countdown.
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 1))
			stepUntilBuilt(1)
			expect((Bots.clipsOf("bot-beater-1") :: any).playing).to.equal("idle")
			-- ...and stepping it while the drive has not started changes nothing.
			Bots.step(0.2, 1000)
			expect((Bots.clipsOf("bot-beater-1") :: any).playing).to.equal("idle")
		end)

		it("scales the walk's playback rate to the speed it is actually making", function()
			-- THE SLIDE (task 164). Measured in Karen's Forest Test: four beaters covering
			-- 4.70-5.00 studs/s with the walk clip at rate 1.000, which is the rate for a 6.74
			-- studs/s gait. Here the fake body is MOVED BY HAND between steps, so the rate the step
			-- picks is a measurement of that movement and not of `WALK_SPEED`.
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 1))
			stepUntilBuilt(1)
			Bots.go()
			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder
			local body = folder:FindFirstChild("bot-beater-1") :: Model

			-- First step: no previous sample, so the pace it was TOLD to walk at.
			Bots.step(0.2, 5000)
			local clips = Bots.clipsOf("bot-beater-1") :: any
			expect(clips.playing).to.equal("walk")
			local _, nominal = Rig.gait(Bots.CONFIG.WALK_SPEED, "walk")
			expect(math.abs(clips.rate - nominal) < Rig.GAIT.RATE_EPSILON).to.equal(true)
			expect(nominal < Rig.GAIT.MAX_RATE).to.equal(true) -- the slide: it used to be 1.000

			-- HALF THE PACE OVER THE NEXT STEP -> half the rate. 0.5 studs in 0.2 s is 2.5 studs/s.
			local here = Rig.positionOf(body) :: Vector3
			Rig.place(body, CFrame.new(here + Vector3.new(0, 0, -0.5)), false)
			Bots.step(0.2, 5000.2)
			-- TO A TOLERANCE, not to the bit: the step measures 0.5 studs over 0.2 s of a float
			-- clock, so 2.5 arrives as 2.4999999999999996 and the two divisions differ in the last
			-- place. `RATE_EPSILON` is the resolution the owner itself acts on, so anything inside
			-- it is the same rate as far as the Animator is ever told.
			local _, half = Rig.gait(2.5, "walk")
			local got = (Bots.clipsOf("bot-beater-1") :: any).rate
			expect(math.abs(got - half) < Rig.GAIT.RATE_EPSILON).to.equal(true)
			expect(math.abs(got - nominal / 2) < Rig.GAIT.RATE_EPSILON).to.equal(true)

			-- AND A BOT THAT IS NOT MOVING STANDS STILL instead of churning its legs on the spot,
			-- which is the other half of "odd": the body is not moved at all over this step.
			Bots.step(0.2, 5000.4)
			expect((Bots.clipsOf("bot-beater-1") :: any).playing).to.equal("idle")
		end)

		it("counts the tool pose PER DRIVE, because the line that prints it says `drive N`", function()
			-- ROUND 1'S BLOCKING FINDING. `toolPosed` was added to `stats` and printed under
			-- `[bots] drive %d` but left out of `PER_DRIVE_STATS`, so four beaters would have read
			-- `4 tool-posed` on drive 1, `8` on drive 2 and `12` on drive 3 -- a lifetime total
			-- under a per-drive heading, which is the exact fault that list's own header describes.
			--
			-- ASSERTED AS MEMBERSHIP rather than by zeroing a counter this suite cannot raise (the
			-- `HORN` flag is off, so no bot in it is ever handed a Tool -- see the next case). That
			-- is also the GENERAL form of the finding: the list is now readable, so the next counter
			-- cannot be added to the line and forgotten here.
			local listed = {}
			for _, name in ipairs(Bots.PER_DRIVE_STATS) do
				listed[name] = true
			end
			expect(listed.toolPosed).to.equal(true)
			-- ...and every name in it is really a counter, so the list cannot rot the other way.
			local s = Bots.stats() :: any
			for _, name in ipairs(Bots.PER_DRIVE_STATS) do
				expect(type(s[name])).to.equal("number")
			end
			-- The reset itself, through the one door that does it.
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 1))
			stepUntilBuilt(1)
			Bots.clear()
			expect((Bots.stats() :: any).toolPosed).to.equal(0)
		end)

		it("holds a carried tool like a player does -- on top of the gait, not instead of it", function()
			-- MEASURED BOTH WAYS on 2026-10-12: a player holding a Tool plays `ToolNoneAnim`
			-- (507768375) at priority `Idle` AT THE SAME TIME as its walk at priority `Core`, and
			-- every bot beater in Karen's place was playing the walk ALONE with a Horn in its hand.
			-- So the horn rode a freely swinging arm.
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(1, 0))
			stepUntilBuilt(1)
			local clips = Bots.clipsOf("bot-hunter-1") :: any
			-- The clip is on every rig, loaded; a bot hunter carries nothing, so it is not POSED.
			-- THIS IS THE HALF OF `finishBuild`'S WIRING THE SUITE CAN REACH (round 1 note): with
			-- the `HORN` flag off, `world.horn.give` hands no bot a Tool, so `bot.horn` is nil and
			-- the owner's call is `Rig.holdTool(clips, false)`. That the TRUE branch reaches a real
			-- beater is evidence from the live probe instead -- 507768375 at weight 1.00 on all four
			-- beaters of a real drive (`docs/research/2026-10-12-bots.md` section 8.6) -- and the
			-- request says so rather than claiming a spec covers it.
			expect(clips.tool).to.be.ok()
			expect(clips.holding).to.never.equal(true)
			expect((Bots.stats() :: any).toolPosed).to.equal(0)

			-- Asking for nothing twice is a no-op, so the owner's count cannot be inflated by a rig
			-- that carries nothing.
			expect(Rig.holdTool(clips, false)).to.equal(false)

			-- Turning it on plays it and LEAVES THE GAIT ALONE -- that is the whole of the pattern.
			expect(Rig.holdTool(clips, true)).to.equal(true)
			expect(clips.holding).to.equal(true)
			expect(clips.playing).to.equal("idle")
			expect((clips.idle :: AnimationTrack).IsPlaying).to.equal(true)
			expect((clips.tool :: AnimationTrack).IsPlaying).to.equal(true)
			-- Idempotent, so a 5 Hz step can call it.
			expect(Rig.holdTool(clips, true)).to.equal(false)

			-- And a gait change does not take the tool pose down with it.
			Rig.playClip(clips, "walk", 0.5)
			expect(clips.playing).to.equal("walk")
			expect((clips.tool :: AnimationTrack).IsPlaying).to.equal(true)
		end)

		it("raises the horn on top of the gait, and the drive's end takes it down again", function()
			-- TASK 166, AND BOTH HALVES OF IT ARE ROUND 1'S FINDINGS.
			--
			-- THE PLAYING HALF OF `Rig.blow` WAS ASSERTED NOWHERE (finding 2): the only case named
			-- for it drove a clips table with no track, so both answers came from `if track == nil`
			-- and deleting the idempotence guard, the Play/Stop calls and the `blowing` write all
			-- left it green. This is `holdTool`'s own idiom, on a real rig, for the same contract.
			--
			-- AND A BEATER MID-BLAST WHEN THE DRIVE ENDED KEPT THE HORN AT ITS FACE FOR THE WHOLE
			-- RESULTS SCENE (finding 1). `Bots.gather` -- `Match.applyScene`'s own call at the drive
			-- end -- sets `released = false`, and the only thing that lowered the arm sat behind that
			-- flag, so there was no next step to ask again; `gather`'s `Rig.playClip(clips, "idle")`
			-- stops only the gait, and the pose is a LOOPING clip at `Action`, which outranks it.
			-- This case fails on that code at the `gather` line below.
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 1))
			stepUntilBuilt(1)
			local clips = Bots.clipsOf("bot-beater-1") :: any
			expect(clips).to.be.ok()
			if clips.blow == nil then
				-- A session whose `RegisterKeyframeSequence` failed has no pose to take down, and
				-- that is the one state where "the arm never goes up" is correct rather than a bug.
				TestKit.note("bots: no blow clip registered in this session, so there is no pose to raise")
				expect(Rig.blow(clips, true)).to.equal(false)
				return
			end

			-- The gait is what a walking beater is doing while it blows, and it has to survive.
			Rig.playClip(clips, "walk", 0.6)
			expect(clips.playing).to.equal("walk")

			-- UP: it plays, it records, and it does NOT take the gait down with it -- that is the
			-- whole of the pattern, and it is why the clip is `Action` over the walk's `Core`.
			expect(Rig.blow(clips, true)).to.equal(true)
			expect(clips.blowing).to.equal(true)
			expect((clips.blow :: AnimationTrack).IsPlaying).to.equal(true)
			expect((clips.walk :: AnimationTrack).IsPlaying).to.equal(true)
			expect(clips.playing).to.equal("walk")
			-- IDEMPOTENT, which is what stops a 5 Hz step re-playing the 0.2 s fade every tick.
			expect(Rig.blow(clips, true)).to.equal(false)

			-- DOWN, through the owner's own door: the drive ends and the bots are gathered into the
			-- results ring. One ring entry is enough -- this is about the horn, not the placement.
			local posed = (Bots.stats() :: any).blowPosed
			Bots.gather({ CFrame.new(0, 10, 0) }, 1)
			expect(clips.blowing).to.equal(false)
			expect((Bots.stats() :: any).blowPosed > posed).to.equal(true)
			-- The TRACK follows over its own fade, so this is waited for rather than read on sight.
			local stopped = false
			for _ = 1, 40 do
				if not (clips.blow :: AnimationTrack).IsPlaying then
					stopped = true
					break
				end
				task.wait(0.05)
			end
			expect(stopped).to.equal(true)

			-- ...AND THE STEP WOULD HAVE TAKEN IT DOWN TOO, which is the half that makes it
			-- level-triggered: `released` is false now and this bot has been gathered, so an arm put
			-- up here is behind every guard the old call sat behind.
			expect(Rig.blow(clips, true)).to.equal(true)
			Bots.step(0.2, 9000)
			expect(clips.blowing).to.equal(false)
			TestKit.note("bots: the blow pose plays over the gait and is down again after gather and after a step")
		end)
	end)

	describe("the horn", function()
		it("blows far less often than the horn's own cooldown allows", function()
			-- ASSERTED, NOT TRUSTED: the rhythm is Karen's *"now and then"* and the cooldown is the
			-- server's rate limit. If the rhythm ever dropped below the cooldown, a bot would become
			-- the thing that tests `Horn.CONFIG.COOLDOWN` -- and a continuous unbroken horn is the
			-- exact thing that cooldown exists to prevent.
			expect(Bots.CONFIG.HORN.EVERY_SECONDS.min > HornData.CONFIG.COOLDOWN).to.equal(true)
			expect(Bots.CONFIG.HORN.EVERY_SECONDS.max >= Bots.CONFIG.HORN.EVERY_SECONDS.min).to.equal(true)
			-- ...AND SINCE TASK 174 IT IS A LOT LESS OFTEN. KAREN, 2026-10-13 ~13:40, choosing between
			-- three answers to task 172's measurement -- the bot horns reach 100 m, so every sounder
			-- in the wood was already running before she could walk up on one: *"Bots blow less
			-- often"*. FOUR beaters share this window, so the quiet between blasts is about a quarter
			-- of `min`, and a walk-up takes the time it takes to cross 100 m. 45 s is ~11 s of quiet;
			-- the 18 s this was before was ~4.5 s, which is less than nothing at that reach.
			expect(Bots.CONFIG.HORN.EVERY_SECONDS.min >= 45).to.equal(true)
		end)

		it("is jittered, deterministic and inside its own window", function()
			local every = Bots.CONFIG.HORN.EVERY_SECONDS
			local seen = {}
			for index = 1, 4 do
				local due = Bots.hornDue({ index = index } :: any, 100, Bots.CONFIG)
				expect(due >= 100 + every.min).to.equal(true)
				expect(due <= 100 + every.max).to.equal(true)
				table.insert(seen, due)
				-- DETERMINISTIC: a Random here would make a bug report unreproducible, which is why
				-- `Phase` has none either.
				expect(Bots.hornDue({ index = index } :: any, 100, Bots.CONFIG)).to.equal(due)
			end
			-- FOUR BEATERS DO NOT SOUND TOGETHER, which would read as one loud horn rather than as a
			-- line of men: at least two of the four due times differ.
			local allSame = true
			for _, due in ipairs(seen) do
				if math.abs(due - seen[1]) > 1e-6 then
					allSame = false
				end
			end
			expect(allSame).to.equal(false)
		end)

		it("refuses a blast for a bot with no horn, and counts the refusal", function()
			local before = Bots.stats().blastsRefused
			expect(Bots.blowFor("bot-beater-never-built", 100)).to.equal(false)
			-- A bot that does not exist is not a refusal to count: it is nothing at all.
			expect(Bots.stats().blastsRefused).to.equal(before)
		end)
	end)

	describe("the end of a drive counts the LINE, not just the people", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		it("puts the bot beaters into the drive's own beater count", function()
			-- KAREN'S OPEN COMPLAINT, TASKS.md 159a(f): *"a solo beater ends the drive the moment she
			-- crosses the road"*. Her rule is *"Timer or when all beaters cross line of hunters"*, and
			-- with a line of bots walking beside her "all beaters" is the LINE -- so she crossing
			-- first ends nothing. This is the measurement half; `Phase.beatersThrough` is the rule and
			-- is untouched.
			local people, peopleAcross = Match.beaterCrossing()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(0, 4))
			stepUntilBuilt(4)
			local withBots, withBotsAcross = Match.beaterCrossing()
			expect(withBots).to.equal(people + 4)
			-- They are standing 240 studs up the drive, so none of them is through yet -- which is
			-- exactly why a solo beater's own crossing can no longer end the drive.
			expect(withBotsAcross).to.equal(peopleAcross)
			expect(withBotsAcross <= withBots).to.equal(true)

			-- ...and a bot HUNTER is not in the line at all.
			Bots.fill(slotsFor(4, 0))
			local hunterOnly = Match.beaterCrossing()
			expect(hunterOnly).to.equal(people)
		end)

		it("gives a bot no score row and no place in the roster", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(slotsFor(4, 4))
			stepUntilBuilt(8)
			-- THE BOARD IS THE THING KAREN READS AT THE END OF EVERY DRIVE, and ioquake3's own bots
			-- are in its scoreboard -- which is the one half of that source this design rejected. A
			-- bot has no userId, so there is nothing to make a row out of.
			local snapshot = Match.snapshot()
			for _, row in ipairs(snapshot.rows or {}) do
				expect(tonumber(row.userId)).to.be.ok()
				expect(string.find(tostring(row.name or ""), "bot%-")).to.equal(nil)
			end
			-- ...and the results scene's ring is widened by the rig count rather than by a roster that
			-- grew: `Phase.participantIds` is what the drive holds, and it holds only players.
			expect(Match.botCount()).to.equal(8)
			expect(#Match.Phase.participantIds({ participants = {} } :: any)).to.equal(0)
		end)
	end)

	describe("drive 2 (round 2, finding 1 -- the bug Karen would have hit)", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		it("is the first Assigning tick of a drive that rebuilds, and only that", function()
			-- EDGE, NOT LEVEL. `Assigning` lasts ten seconds and `syncBots` runs on every dispatch,
			-- so a rule keyed on the phase would destroy and rebuild eight bodies four times a
			-- second; and a bot mid-walk must never be teleported back to the line.
			expect(Match.botsNeedRebuild("Assigning", 1, nil)).to.equal(true)
			expect(Match.botsNeedRebuild("Assigning", 1, 1)).to.equal(false) -- the same drive, again
			expect(Match.botsNeedRebuild("Assigning", 2, 1)).to.equal(true) -- the next drive
			expect(Match.botsNeedRebuild("Running", 2, 1)).to.equal(false)
			expect(Match.botsNeedRebuild("Scoring", 2, 1)).to.equal(false)
			expect(Match.botsNeedRebuild("Waiting", 2, 1)).to.equal(false)
		end)

		it("puts every bot back on the start line, and drive 2 does not end before they walk", function()
			-- THE WHOLE OF FINDING 1. `Bots.fill` only re-places a slot whose BASE MOVED, and a base
			-- does not move between drives -- `Body.placementFor` is a pure function of the marker
			-- and the index, and `botSlotsFor` asks for the same index every time. So before this
			-- fix, drive 2 began with every bot exactly where the results scene had stood it:
			-- `gathered` still true, so none of them ever walked again, and all of them standing
			-- PAST the hunters' line, which ended drive 2 on its first `Running` tick. For ever.
			--
			-- THE BOUNDARY BELOW IS `syncBots`'S OWN, through the same exported rule, so deleting
			-- that rule makes this case fail rather than quietly pass.
			local slots = slotsFor(0, 4)
			local starts = {}
			for _, slot in ipairs(slots) do
				starts[slot.id] = Bots.laneOf(slot, Bots.CONFIG).Position
			end

			Bots.setRigSource(fakeRig)
			-- ---- drive 1 -------------------------------------------------------------------
			local rebuiltFor: number? = nil
			if Match.botsNeedRebuild("Assigning", 1, rebuiltFor) then
				Bots.clear()
				rebuiltFor = 1
			end
			Bots.fill(slots)
			stepUntilBuilt(4)
			expect(Bots.count("Drivers")).to.equal(4)
			local _, aloneAcross = Match.beaterCrossing()
			for _, beater in ipairs(Bots.beaters()) do
				expect((beater.position - starts[beater.id]).Magnitude < 1).to.equal(true)
			end

			-- ...it walks, and the results scene stands it in the ring. FAR south of the arena's
			-- line, which is what makes the next two numbers mean something: a bot in the ring is a
			-- bot the drive counts as THROUGH.
			Bots.go()
			local ring = {}
			for index = 1, 4 do
				ring[index] = CFrame.new(index * 20 - 50, 10, -5000)
			end
			expect(Bots.gather(ring, 1)).to.equal(4)
			local inRing, ringAcross = Match.beaterCrossing()
			expect(inRing >= 4).to.equal(true)
			expect(ringAcross).to.equal(aloneAcross + 4) -- all four are "through", standing still

			-- ---- the drive boundary, exactly as `syncBots` does it ---------------------------
			if Match.botsNeedRebuild("Assigning", 2, rebuiltFor) then
				Bots.clear()
				rebuiltFor = 2
			end
			Bots.fill(slots) -- the SAME slots: the geometry has not moved, which was the whole trap
			stepUntilBuilt(4)

			-- ---- drive 2 --------------------------------------------------------------------
			expect(Bots.count("Drivers")).to.equal(4)
			local backAt = Bots.beaters()
			expect(#backAt).to.equal(4)
			for _, beater in ipairs(backAt) do
				-- BACK ON THE START LINE, not in last drive's ring. Without the rebuild this is
				-- 5,000 studs out.
				expect((beater.position - starts[beater.id]).Magnitude < 1).to.equal(true)
			end
			-- ...AND THE DRIVE DOES NOT END BEFORE THEY WALK: nobody is through, so
			-- `Phase.beatersThrough` -- which is untouched and only compares two numbers -- cannot
			-- fire on the first `Running` tick.
			local beaters, across = Match.beaterCrossing()
			expect(beaters >= 4).to.equal(true)
			expect(across).to.equal(aloneAcross)
			expect(Match.Phase.beatersThrough({ beaters = beaters, beatersAcross = across }, Match.CONFIG)).to.equal(
				false
			)

			-- ...and they are walkers again, not statues standing in a ring that is gone.
			Bots.go()
			Bots.step(0.2, 9000)
			expect(Bots.stats().walking).to.equal(4)
		end)
	end)

	describe("the switch is off, and off means the drive before task 161", function()
		it("ships with the flag off, so the drive never asks the bots anything", function()
			expect(Match.CONFIG.BOTS.ENABLED).to.equal(false)
			-- `syncBots` returns on that test before it reads the roster or the markers, so a DEV
			-- drive builds nothing -- which is why this spec can own the rigs while it runs.
			expect(Match.botCount()).to.equal(0)
		end)

		it("leaves the drive's own numbers exactly as they were with no bots in it", function()
			-- `Match.beaterCrossing` with no bot beaters is the two numbers task 159 shipped, and
			-- `Phase.beatersThrough` is what reads them -- unchanged, and it still refuses to end a
			-- drive that has no beater in it at all.
			local beaters, across = Match.beaterCrossing()
			expect(across <= beaters).to.equal(true)
			expect(Match.Phase.beatersThrough({ beaters = 0, beatersAcross = 0 }, Match.CONFIG)).to.equal(false)
		end)

		it("reports its numbers in one line, with the step cost and the walk seconds in it", function()
			-- The vendor's performance page has NO numbers in it, so "eight humanoids are cheap" is a
			-- measurement and not a claim -- and a drive now ENDS when the line is through, so the
			-- walk's own seconds are what the next feel conversation needs.
			local line = Bots.report(1)
			expect(string.find(line, "%[bots%] drive 1")).to.be.ok()
			expect(string.find(line, "step")).to.be.ok()
			expect(string.find(line, "arrived in")).to.be.ok()
			-- ...and the field task 164 added, so the line and the counters cannot drift apart.
			expect(string.find(line, "tool%-posed")).to.be.ok()
			expect(Bots.stats().stepMsAvg >= 0).to.equal(true)
		end)
	end)

	-- ---------------------------------------------------------------- not getting stuck (task 208)
	--
	-- KAREN, 2026-10-18 ~14:20: *"bot beater stuck we definatly need to fix that they not stuck the
	-- can avoid"*. These cases are the three findings of
	-- `docs/research/2026-10-19-bots-unstuck.md` section 4, each as a thing a spec can state:
	--   1. the walk could not SEE a body in the way (`roomToStand` ignores characters by design);
	--   2. the recovery it did make was not HELD, so the next step aimed back into the thing;
	--   3. the decision was issued on a 2-second cadence, so NINE IN TEN never reached the humanoid.
	--
	-- `Humanoid.WalkToPoint` IS HOW A SPEC SEES `MoveTo`. The engine sets it from the call, so "did
	-- this bot get told to walk somewhere new" is a property read and not a stub.
	describe("a bot that is pinned (task 208)", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		-- A FAKE RIG DOES NOT WALK -- it is a Part with a Humanoid and nothing to stand on -- which
		-- makes it the perfect PINNED bot, exactly as the round-2 cases above use it.
		local function walkerSlot()
			return {
				{
					id = "bot-beater-1",
					team = "Drivers",
					from = CFrame.new(0, 10, 240),
					to = Vector3.new(0, 10, -20),
					lane = 1,
				},
			}
		end

		local function pinnedWalker(clock: number)
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, clock)
			Bots.go()
			Bots.step(0.2, clock) -- the first released step: stamps the walk and issues the first aim
			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder
			local body = folder:FindFirstChild("bot-beater-1") :: Model
			return body:FindFirstChildOfClass("Humanoid") :: Humanoid
		end

		it("TELLS THE HUMANOID somewhere new as soon as it is pinned, not on the next re-issue", function()
			-- FINDING 3, AND THIS CASE FAILS ON THE CODE BEFORE THIS TASK. The clock moves 1.0 s --
			-- long enough for the fast stuck window (`STUCK_FAST_SECONDS` 0.8) and SHORTER than
			-- `MOVE_REISSUE_SECONDS` (2) -- so the old cadence could not have issued anything, and
			-- the old four-second window had not even noticed. Measured in Karen's place, that is
			-- how a bot stood against a spruce for 169 seconds while the stuck counter ticked.
			local humanoid = pinnedWalker(4000)
			local before = humanoid.WalkToPoint
			Bots.step(0.2, 4000 + Bots.CONFIG.STUCK_FAST_SECONDS + 0.2)
			expect((humanoid.WalkToPoint - before).Magnitude > 1).to.equal(true)
			expect(Bots.stats().recoveries).to.equal(1)
		end)

		it("HOLDS that decision instead of aiming back into the thing on the next step", function()
			-- FINDING 2. Three more steps inside the hold must not move the aim: the hold is what
			-- the bot spends GETTING PAST the thing (the boar's `WEDGE_HOLD_SECONDS`).
			local humanoid = pinnedWalker(5000)
			local at = 5000 + Bots.CONFIG.STUCK_FAST_SECONDS + 0.2
			Bots.step(0.2, at)
			local committed = humanoid.WalkToPoint
			local recoveries = Bots.stats().recoveries
			for i = 1, 3 do
				Bots.step(0.2, at + i * 0.2)
			end
			expect((humanoid.WalkToPoint - committed).Magnitude < 0.01).to.equal(true)
			expect(Bots.stats().recoveries).to.equal(recoveries)
		end)

		it("tries again, and the OTHER WAY, once the hold has run out", function()
			-- ioquake3's `avoidreachtries` and the boar's alternating `_wedgeCount`: a bot that
			-- could not get past on one side tries the other rather than leaning harder.
			local humanoid = pinnedWalker(6000)
			local at = 6000 + Bots.CONFIG.STUCK_FAST_SECONDS + 0.2
			Bots.step(0.2, at)
			local first = humanoid.WalkToPoint
			local after = at + Bots.CONFIG.RECOVER_HOLD_SECONDS + Bots.CONFIG.STUCK_FAST_SECONDS + 0.2
			Bots.step(0.2, after)
			expect(Bots.stats().recoveries).to.equal(2)
			expect((humanoid.WalkToPoint - first).Magnitude > 1).to.equal(true)
			-- Opposite sides of the lane, which runs down z: so the two aims straddle x = 0.
			expect(first.X * humanoid.WalkToPoint.X < 0).to.equal(true)
		end)

		it("BACKS OFF once the tries run out, which is the last rung of the ladder", function()
			-- THE BRANCH THAT IS HARDEST TO REACH, and it gets its own case for exactly that reason.
			local humanoid = pinnedWalker(7000)
			local at = 7000
			for _ = 1, Bots.CONFIG.BACK_OFF_AFTER_TRIES + 1 do
				at += Bots.CONFIG.RECOVER_HOLD_SECONDS + Bots.CONFIG.STUCK_FAST_SECONDS + 0.2
				Bots.step(0.2, at)
			end
			expect(Bots.stats().recoverBack >= 1).to.equal(true)
			-- A back-off aims BEHIND the bot: further from the goal than the bot stands.
			local goal = walkerSlot()[1].to :: Vector3
			local body = (Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder):FindFirstChild("bot-beater-1") :: Model
			local here = Rig.positionOf(body) :: Vector3
			local mine = Vector3.new(here.X - goal.X, 0, here.Z - goal.Z).Magnitude
			local aimed = Vector3.new(humanoid.WalkToPoint.X - goal.X, 0, humanoid.WalkToPoint.Z - goal.Z).Magnitude
			expect(aimed > mine).to.equal(true)
		end)

		it("JUMPS a low thing, and only a walker can", function()
			-- THE THIRD BRANCH, driven by a reader that reports a knee-high obstruction. A fake rig
			-- has no state machine to watch, so the claim is the COUNT and the JumpHeight that makes
			-- the call worth anything -- the two things `Rig.prepare` and the ladder decide.
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 8000)
			Bots.go()
			local low = function()
				return 3.0, Bots.CONFIG.JUMP_OVER_STUDS - 1
			end
			Bots.step(0.2, 8000, nil, low)
			Bots.step(0.2, 8000 + Bots.CONFIG.STUCK_FAST_SECONDS + 0.2, nil, low)
			expect(Bots.stats().recoverJump).to.equal(1)
			expect(Bots.stats().recoverSide).to.equal(0)
			local body = (Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder):FindFirstChild("bot-beater-1") :: Model
			local humanoid = body:FindFirstChildOfClass("Humanoid") :: Humanoid
			-- A float32 round trip through the property: 5.2 comes back as 5.199999809265137.
			expect(math.abs(humanoid.JumpHeight - Bots.CONFIG.JUMP_HEIGHT_STUDS) < 1e-4).to.equal(true)
		end)

		it("goes ROUND a thing it can see BEFORE it touches it, and holds that too", function()
			-- FINDING 1, as the thing that stops the pin happening at all: the swept reader answers
			-- "blocked straight ahead, clear at an angle", and the bot deflects without ever being
			-- stuck. The reader is the `laneAhead` seam, so no world and no trunk are needed.
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 9000)
			Bots.go()
			local straight = Vector3.new(0, 10, 228) -- 12 studs down the lane from (0, 10, 240)
			local reader = function(_from: Vector3, to: Vector3)
				if math.abs(to.X) < 1 and math.abs(to.Z - straight.Z) < 1 then
					return 4.0, 20.0 -- a trunk, too tall to jump
				end
				return nil, nil
			end
			Bots.step(0.2, 9000, nil, reader)
			expect(Bots.stats().detours).to.equal(1)
			expect(Bots.stats().recoveries).to.equal(0) -- it was never stuck: it saw it
			local body = (Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder):FindFirstChild("bot-beater-1") :: Model
			local humanoid = body:FindFirstChildOfClass("Humanoid") :: Humanoid
			expect(math.abs(humanoid.WalkToPoint.X) > 1).to.equal(true)
		end)

		it("does NOT let the point test throw the detour away", function()
			-- A DEFECT THIS TASK WOULD OTHERWISE HAVE SHIPPED. `Lane.clearAim` recomputes from the
			-- plain LANE point, so if it spoke after a detour it would aim the bot at ITS answer
			-- instead of the one the deflection chose.
			--
			-- ROUND 1'S BLOCKING FINDING 2: the first version of this case handed `clearAim` a
			-- reader that called every point CLEAR, which makes it return `stepped = 0` and leave
			-- the aim alone -- so the case passed with the `if not deflected` guard DELETED and
			-- proved nothing. The clearance reader here BLOCKS the lane point and clears the sides,
			-- so a surviving `clearAim` returns a side-step with `stepped = 1` and would overwrite
			-- the detour; and the assertion is now that the issued point IS the detour point, not
			-- merely that it is off-centre -- a `SIDE_STEP_STUDS` nudge of 10 is off-centre too, and
			-- further off than the 18-degree deflection this must choose.
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 12000)
			Bots.go()
			local slot = walkerSlot()[1]
			local here = slot.from.Position
			local goal = slot.to :: Vector3
			local lanePoint = Bots.Lane.aimFor(here, goal, Bots.CONFIG.AHEAD_STUDS)
			local straightOnly = function(_from: Vector3, to: Vector3)
				if math.abs(to.X) < 1 then
					return 4.0, 20.0 -- a trunk dead ahead, too tall to jump
				end
				return nil, nil
			end
			-- BLOCKED at the lane point, clear anywhere else: `clearAim` would answer with a
			-- `SIDE_STEP_STUDS` side-step and `stepped = 1`.
			local blockTheLane = function(point: Vector3)
				return (point - lanePoint).Magnitude > 0.01
			end
			Bots.step(0.2, 12000, blockTheLane, straightOnly)
			local body = (Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder):FindFirstChild("bot-beater-1") :: Model
			local humanoid = body:FindFirstChildOfClass("Humanoid") :: Humanoid
			expect(Bots.stats().detours).to.equal(1)
			-- THE DETOUR POINT ITSELF -- the smallest deflection in the fan, on this bot's own side.
			local wanted = Bots.Lane.turnedAim(here, goal, Bots.CONFIG.DETOUR_ANGLES_DEG[1], Bots.CONFIG)
			expect((humanoid.WalkToPoint - wanted).Magnitude < 0.01).to.equal(true)
			-- ...and NOT the side-step `clearAim` would have given, which is further out.
			local nudge = Bots.Lane.sideStep(lanePoint, here, goal, 1, Bots.CONFIG)
			expect((humanoid.WalkToPoint - nudge).Magnitude > 1).to.equal(true)
			expect(Bots.stats().sideSteps).to.equal(0)
		end)

		it("says BOXED IN rather than inventing a way through", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 9500)
			Bots.go()
			local everywhere = function()
				return 2.0, 30.0
			end
			Bots.step(0.2, 9500, nil, everywhere)
			expect(Bots.stats().boxedIn).to.equal(1)
			expect(Bots.stats().detours).to.equal(0)
		end)

		it("spends NO cast at all in a world with no reader, which is the DEV arena", function()
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 9800)
			Bots.go()
			Bots.step(0.2, 9800)
			Bots.step(0.2, 9800 + Bots.CONFIG.STUCK_FAST_SECONDS + 0.2)
			expect(Bots.stats().laneCasts).to.equal(0)
			expect(Bots.stats().detours).to.equal(0)
			-- ...and it still recovers, by the sidestep this has always been there.
			expect(Bots.stats().recoverSide).to.equal(1)
		end)

		it("reports the WORST PIN in seconds, which is the number the task is judged on", function()
			local humanoid = pinnedWalker(10000)
			expect(humanoid).to.be.ok()
			local at = 10000
			for _ = 1, 4 do
				at += Bots.CONFIG.STUCK_FAST_SECONDS + 0.05
				Bots.step(0.2, at)
			end
			-- Four closed windows of a bot that never moved: the pin is at least three of them.
			expect(Bots.stats().worstStuckSeconds > 2.5).to.equal(true)
			expect(string.find(Bots.report(1), "worst pin")).to.be.ok()
		end)

		it("is NOT pinned while it is still being held at the start line", function()
			-- A bot standing on its lane start through the countdown is HELD, not stuck -- and
			-- `Bots.go` has not been called here at all.
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 11000)
			Bots.step(0.2, 11000 + Bots.CONFIG.STUCK_FAST_SECONDS + 5)
			expect(Bots.stats().recoveries).to.equal(0)
			expect(Bots.stats().stuck).to.equal(0)
		end)
	end)

	-- ---------------------------------------------------------------- the reader itself (round 2)
	--
	-- ROUND 1'S BLOCKING FINDING 1: every case above drives a HAND-WRITTEN reader, so nothing asserted
	-- what the real one answers -- and the real one was wrong. A character's `HumanoidRootPart` is 2
	-- studs tall, so `Size.Y / 2 + BODY_HEIGHT_STUDS / 2` came to **3.5**, BELOW
	-- `Bots.CONFIG.JUMP_OVER_STUDS` (4), which meant a bot JUMPED at a person instead of walking
	-- round one -- the opposite of what `ForestTest.laneAhead`'s own header, the ladder and the task's
	-- request all said. `bots_lane.spec` even asserted a hand-written 5 under the comment *"which is
	-- what `ForestTest.laneAhead` reports for a person"*, a number the function never returned.
	--
	-- SO THESE CASES CALL THE REAL READER, with a real rig in the real `Workspace.DriveBots`, and
	-- assert the step height instead of assuming it.
	describe("ForestTest.laneAhead, the real reader (round 2, finding 1)", function()
		afterEach(function()
			Bots.clear()
			Bots.setRigSource(nil)
		end)

		local function bodyOnTheLane(): Vector3
			Bots.setRigSource(fakeRig)
			Bots.fill({
				{
					id = "bot-beater-1",
					team = "Drivers",
					from = CFrame.new(0, 200, 0),
					to = Vector3.new(0, 200, -200),
					lane = 1,
				},
			})
			Bots.step(0.2, 20000)
			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder
			local body = folder:FindFirstChild("bot-beater-1") :: Model
			expect(body).to.be.ok()
			return Rig.positionOf(body) :: Vector3
		end

		it("reports a BODY as TALLER than a bot may jump, so a person is gone ROUND", function()
			local at = bodyOnTheLane()
			-- Looking down the lane from 10 studs behind it, at the same height.
			local from = Vector3.new(at.X, at.Y, at.Z + 10)
			local to = Vector3.new(at.X, at.Y, at.Z - 2)
			local ahead, step = ForestTest.laneAhead(from, to, Bots.CONFIG.LANE_BODY_SIZE, nil)
			expect(ahead).to.be.ok()
			expect(step).to.be.ok()
			-- THE CLAIM, as a number: above the jump gate, so `recoveryFor` can never answer "jump".
			expect((step :: number) > Bots.CONFIG.JUMP_OVER_STUDS).to.equal(true)
			expect(math.abs((step :: number) - 5) < 0.01).to.equal(true)
			expect(Bots.Lane.recoveryFor(ahead, step, 1, Bots.CONFIG)).to.equal("sidestep")
			-- ...and it is where the body actually is, not at the far end of the segment.
			expect(math.abs((ahead :: number) - 10) < 1.5).to.equal(true)
		end)

		it("does not see the walker's OWN body, which is what `ignore` is for", function()
			local at = bodyOnTheLane()
			local folder = Workspace:FindFirstChild(Rig.FOLDER_NAME) :: Folder
			local body = folder:FindFirstChild("bot-beater-1") :: Model
			local from = Vector3.new(at.X, at.Y, at.Z + 10)
			local to = Vector3.new(at.X, at.Y, at.Z - 2)
			local ahead = ForestTest.laneAhead(from, to, Bots.CONFIG.LANE_BODY_SIZE, body)
			expect(ahead).to.equal(nil)
		end)

		it("answers NOTHING down an empty lane, which is the clear case", function()
			-- 4,000 studs up, where neither this world's terrain nor anything else is.
			local from = Vector3.new(0, 4000, 0)
			local to = Vector3.new(0, 4000, -12)
			local ahead, step = ForestTest.laneAhead(from, to, Bots.CONFIG.LANE_BODY_SIZE, nil)
			expect(ahead).to.equal(nil)
			expect(step).to.equal(nil)
		end)
	end)
end
