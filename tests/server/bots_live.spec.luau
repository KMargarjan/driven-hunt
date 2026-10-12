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
local Match = require(ServerScriptService:WaitForChild("Match"))
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

		it("nudges a bot that has stopped moving, WITH A READER THAT SAYS THE WAY IS CLEAR", function()
			-- THE END-TO-END OF ROUND 1'S FINDING 1. In the Forest Test `roomToStand` is injected, so
			-- `room` was true and the forced branch was dead: a stuck bot was counted and never
			-- moved. Here the reader answers `true` for every point -- the inverted case -- and the
			-- side-step must still fire.
			local clear = function()
				return true
			end
			Bots.setRigSource(fakeRig)
			Bots.fill(walkerSlot())
			Bots.step(0.2, 1000, clear)
			Bots.go()
			local stuckBefore = Bots.stats().stuck
			local stepsBefore = Bots.stats().sideSteps
			Bots.step(0.2, 1001, clear) -- inside the stuck window: nothing yet
			expect(Bots.stats().stuck).to.equal(stuckBefore)
			expect(Bots.stats().sideSteps).to.equal(stepsBefore)

			-- ...and past `STUCK_SECONDS`, having moved nowhere.
			Bots.step(0.2, 1001 + Bots.CONFIG.STUCK_SECONDS + 0.1, clear)
			expect(Bots.stats().stuck).to.equal(stuckBefore + 1)
			expect(Bots.stats().sideSteps).to.equal(stepsBefore + 1)
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
			-- AT THE LANE'S OWN GOAL, not at the base's: `Bots.fill` spreads the slot through
			-- `Bots.Lane`, so lane 1's goal is 18 studs to the side of the one the drive handed over.
			local goal = Bots.Lane.goalFor(Vector3.new(0, 10, -20), CFrame.new(0, 10, 240), 1, Bots.CONFIG)
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
			-- TWO CLIPS PER BODY, and a failure shows as a NUMBER rather than as a statue nobody can
			-- explain. If `clipsFailed` is ever non-zero the ids in `Rig.CLIPS` are what to look at.
			expect(s.clipsLoaded + s.clipsFailed).to.equal(4)
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
	end)

	describe("the horn", function()
		it("blows far less often than the horn's own cooldown allows", function()
			-- ASSERTED, NOT TRUSTED: the rhythm is Karen's *"now and then"* and the cooldown is the
			-- server's rate limit. If the rhythm ever dropped below the cooldown, a bot would become
			-- the thing that tests `Horn.CONFIG.COOLDOWN` -- and a continuous unbroken horn is the
			-- exact thing that cooldown exists to prevent.
			expect(Bots.CONFIG.HORN.EVERY_SECONDS.min > HornData.CONFIG.COOLDOWN).to.equal(true)
			expect(Bots.CONFIG.HORN.EVERY_SECONDS.max >= Bots.CONFIG.HORN.EVERY_SECONDS.min).to.equal(true)
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
			expect(Bots.stats().stepMsAvg >= 0).to.equal(true)
		end)
	end)
end
