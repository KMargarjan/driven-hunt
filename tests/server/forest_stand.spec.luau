-- forest_stand.spec: THE PLAYTEST WORLD'S OWN ARITHMETIC -- the road, the stands, the leash and the
-- phase a wave is in. Pure, with two named exceptions since task 153: `beaterStartPosition` raycasts
-- `Workspace` (and in the DEV place, where there is no terrain under this world's coordinates, what
-- that case proves is the FALLBACK), and the threat-kind case reads the live `Players` service and
-- says so when there is nobody to read. No boars and no clock anywhere.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- IT EXISTS BECAUSE NOTHING COVERED ANY OF IT (task 122 round 2, the Reviewer's last note). The
-- verification of record was an inlined run in the Edit place, written into TASKS.md row 122 -- "9
-- stands all within 0.0001 studs of the road curve ... the leash passes at 5 studs and fails at 7" --
-- which is a measurement nobody can repeat on a later commit. These are the same claims as
-- assertions, and they cost nothing to run.
--
-- THE TWO HALVES ARE TWO MODULES, deliberately: `ReplicatedStorage.ForestTest` is the DATA (the road
-- curve, the stands, the bands) and `ServerScriptService.ForestTest` is the drive that reads it. A
-- spec that drives both proves they agree.
--
-- Design: no new design document -- a playtest world behind a world string. TASKS.md row 122.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

return function()
	describe("the road and the stands", function()
		it("puts every stand ON the road, at the spacing the world claims", function()
			local worst = 0
			for index = 1, Data.STAND_COUNT do
				local stand = Data.standPosition(index)
				worst = math.max(worst, math.abs(stand.Z - Data.roadZ(stand.X)))
			end
			-- A STAND'S z IS READ OFF THE CURVE, so the only difference between the two is the
			-- FLOAT32 a `Vector3` stores: this world sits at z = -2097, and float32 carries about
			-- seven digits, so a round trip there costs ~1e-4 studs. MEASURED on this commit, in the
			-- live module: 0.000110, 0.000043, 0.000106, 0.000020, 0.000000 and back out again --
			-- symmetric about the middle stand, which is what a rounding error looks like and what a
			-- second definition of the road would not. The bound is a thousandth of a stud: tight
			-- enough to catch a real disagreement, loose enough not to assert float32 away.
			expect(worst < 1e-3).to.equal(true)
			for index = 2, Data.STAND_COUNT do
				local gap = Data.standX(index) - Data.standX(index - 1)
				expect(math.abs(gap - Data.STAND_SPACING) < 1e-6).to.equal(true)
			end
			TestKit.note(
				string.format(
					"forest-stand: %d stands %d studs apart, worst %.6f studs off the road curve",
					Data.STAND_COUNT,
					Data.STAND_SPACING,
					worst
				)
			)
		end)

		it("centres the line on the world's centre", function()
			local middle = (Data.STAND_COUNT + 1) / 2
			expect(math.abs(Data.standX(middle) - Data.CENTRE.X) < 1e-6).to.equal(true)
		end)

		it("curves: the road is not a straight line across the stands", function()
			-- If it were, `roadZ` could be deleted and every stand would sit at CENTRE.Z -- which is
			-- what a reader checking only the first claim above might conclude.
			local lowest, highest = math.huge, -math.huge
			for index = 1, Data.STAND_COUNT do
				local z = Data.roadZ(Data.standX(index))
				lowest, highest = math.min(lowest, z), math.max(highest, z)
			end
			expect(highest - lowest > 1).to.equal(true)
		end)
	end)

	describe("the stand's boundary and the pick", function()
		it("holds a hunter inside his own stand's circle and lets him go nowhere else", function()
			local home = Data.standPosition(4)
			expect(ForestTest.withinStand(home, 4)).to.equal(true)
			-- Inside and outside, either side of the one number the rule is made of.
			local inside = home + Vector3.new(Data.PICK.standRadiusStuds - 1, 0, 0)
			local outside = home + Vector3.new(Data.PICK.standRadiusStuds + 1, 0, 0)
			expect(ForestTest.withinStand(inside, 4)).to.equal(true)
			expect(ForestTest.withinStand(outside, 4)).to.equal(false)
			-- HEIGHT DOES NOT COUNT: the boundary is a circle on the ground, so a hunter on a rise
			-- is not pulled off his stand by the terrain.
			expect(ForestTest.withinStand(home + Vector3.new(0, 50, 0), 4)).to.equal(true)
		end)

		-- TASK 166. KAREN, 2026-10-12: *"it always put me at the same place even I moved a bit we
		-- need boundries but not put back where it started"*. These two cases are that sentence:
		-- the first says the wall is where it says it is, the second says it is the ONLY place the
		-- clamp can ever put anybody.
		it("clamps a hunter ONTO the circle, at the bearing he walked out along", function()
			local home = Data.standPosition(6)
			local radius = Data.PICK.standRadiusStuds
			-- Inside is nil: there is no wall until you reach it.
			expect(ForestTest.boundaryPoint(home, 6)).to.equal(nil)
			expect(ForestTest.boundaryPoint(home + Vector3.new(radius - 0.5, 0, 0), 6)).to.equal(nil)
			-- A RING OF BEARINGS, and a player 200 studs away as well as one a step outside: every
			-- one of them lands at EXACTLY the radius, on his own bearing, at his own height.
			for degrees = 0, 350, 10 do
				local radians = math.rad(degrees)
				local out = Vector3.new(math.cos(radians), 0, math.sin(radians))
				for _, distance in ipairs({ radius + 0.1, radius + 4, 200 }) do
					local from = home + out * distance + Vector3.new(0, 7, 0)
					local to = ForestTest.boundaryPoint(from, 6)
					expect(to).to.be.ok()
					local at = to :: Vector3
					local flat = Vector3.new(at.X - home.X, 0, at.Z - home.Z)
					expect(flat.Magnitude).to.be.near(radius, 1e-3)
					-- THE SAME BEARING, so he is stopped where he is and not slid round the circle.
					expect(flat.Unit:Dot(out)).to.be.near(1, 1e-4)
					-- HIS OWN HEIGHT, so the clamp cannot drop him through the ground or lift him.
					expect(at.Y).to.be.near(from.Y, 1e-6)
				end
			end
		end)

		it("can NEVER put him back at the middle of his stand, which is Karen's actual complaint", function()
			-- The one thing the old leash did that she felt: it wrote a position every frame while
			-- she pushed against it, 6 studs from the post, which read as being put back where she
			-- started. The radius is twice as far now AND this is the structural half: the only
			-- value this function returns is a point ON the circle, so "back to the centre" is not
			-- expressible at all.
			local home = Data.standPosition(3)
			local radius = Data.PICK.standRadiusStuds
			for degrees = 0, 330, 30 do
				local radians = math.rad(degrees)
				local out = Vector3.new(math.cos(radians), 0, math.sin(radians))
				local to = ForestTest.boundaryPoint(home + out * (radius * 3), 3) :: Vector3
				local flat = Vector3.new(to.X - home.X, 0, to.Z - home.Z)
				expect(flat.Magnitude > radius - 1e-3).to.equal(true)
			end
			-- AND THE CIRCLE IS THE ONE KAREN ASKED FOR: 12 studs, which at `Report.CONFIG`'s 0.28 m
			-- per stud is 3.4 m -- room to walk about on the stand, where 6 studs (1.7 m) was not.
			expect(radius).to.equal(12)
			TestKit.note(
				string.format(
					"stand boundary: radius %.0f studs (%.1f m), was 6 (1.7 m); measured 2026-10-12, the old leash wrote 20.00 -> 6.000 studs in ONE Heartbeat and 6.000 every sample after",
					radius,
					radius * 0.28
				)
			)
		end)

		it("picks the stand a hunter is standing on, and his neighbour's when he walks there", function()
			for index = 1, Data.STAND_COUNT do
				expect(ForestTest.nearestStand(Data.standPosition(index))).to.equal(index)
			end
			-- Just past the midpoint between two stands, the far one wins -- which is what makes
			-- "walk to it" the selection.
			local midpoint = (Data.standPosition(3) + Data.standPosition(4)) / 2
			expect(ForestTest.nearestStand(midpoint + Vector3.new(1, 0, 0))).to.equal(4)
			expect(ForestTest.nearestStand(midpoint - Vector3.new(1, 0, 0))).to.equal(3)
		end)
	end)

	describe("which phase a wave is in", function()
		local WAVE = ForestTest.WAVE

		it("pushes until its time is up, then it is done", function()
			expect(ForestTest.wavePhase(0, false)).to.equal("push")
			expect(ForestTest.wavePhase(WAVE.pushSeconds - 1, false)).to.equal("push")
			expect(ForestTest.wavePhase(WAVE.pushSeconds, false)).to.equal("done")
		end)

		it("stops pushing a turn-back wave once it is near the road", function()
			-- THE TURN IS A PUSH THAT STOPS, which is what this world can honestly do; the "turn"
			-- phase itself was removed in round 2 after three measured attempts all crossed anyway
			-- (`backups/2026-10-06-forest-test-turn-phase.md`).
			expect(ForestTest.wavePhase(1, true, WAVE.turnAtDz + 10)).to.equal("push")
			expect(ForestTest.wavePhase(1, true, WAVE.turnAtDz)).to.equal("done")
			expect(ForestTest.wavePhase(1, true, WAVE.turnAtDz - 10)).to.equal("done")
		end)

		it("walks a lateral wave ACROSS her front before it goes over the road", function()
			-- Coming south, still too far north to be worth watching: keep pushing.
			expect(ForestTest.wavePhase(1, false, WAVE.lateralDz + 10, "LtoR", 0)).to.equal("push")
			-- In the band and the pass has not been walked yet: across.
			expect(ForestTest.wavePhase(1, false, WAVE.lateralDz - 1, "LtoR", 0)).to.equal("lateral")
			-- The pass is done: over the road.
			expect(ForestTest.wavePhase(1, false, WAVE.lateralDz - 1, "LtoR", WAVE.lateralSpan)).to.equal("push")
			-- Out of time is out of time, whatever it was doing.
			expect(ForestTest.wavePhase(WAVE.pushSeconds, false, WAVE.lateralDz - 1, "LtoR", 0)).to.equal("done")
		end)

		it("never answers a phase that no longer exists", function()
			-- `Phase` lost "turn" in round 2; this is the assertion that keeps it gone.
			for _, turnsBack in ipairs({ true, false }) do
				for elapsed = 0, WAVE.pushSeconds, 3 do
					for _, dz in ipairs({ -50, 0, WAVE.turnAtDz, 80 }) do
						local phase = ForestTest.wavePhase(elapsed, turnsBack, dz)
						expect(phase == "push" or phase == "lateral" or phase == "done").to.equal(true)
					end
				end
			end
		end)
	end)

	describe("which way a lateral wave walks", function()
		it("reads a side as a sign, and anything else as none", function()
			-- THE WAVE SPECS NAME THE DIRECTION OF TRAVEL, not a side: "LtoR" is a herd walking from
			-- her left to her right (`src/shared/ForestTest/init.luau`), and the sign is the flank
			-- the BEATER takes, which is the one they came from.
			expect(ForestTest.lateralSign("LtoR")).to.equal(-1)
			expect(ForestTest.lateralSign("RtoL")).to.equal(1)
			expect(ForestTest.lateralSign(nil)).to.equal(0)
			expect(ForestTest.lateralSign("sideways")).to.equal(0)
		end)

		it("puts the beater on the flank they came from, at the herd's own z", function()
			local centre = Vector3.new(100, 5, -600)
			local at = ForestTest.beaterPosition(centre, 1, false, ForestTest.WAVE.lateralDz - 1, "LtoR", 0)
			expect(at).to.be.ok()
			-- A beater NORTH of them pushes them south, which is the one thing the lateral phase
			-- exists to postpone: it stands beside them, not behind them.
			expect(math.abs((at :: Vector3).Z - centre.Z) < 1e-6).to.equal(true)
			expect((at :: Vector3).X > centre.X).to.equal(true)
			-- ...and the mirror.
			local other = ForestTest.beaterPosition(centre, 1, false, ForestTest.WAVE.lateralDz - 1, "RtoL", 0)
			expect((other :: Vector3).X < centre.X).to.equal(true)
		end)

		it("pushes from BEHIND, and stands nowhere at all once the wave is done", function()
			local centre = Vector3.new(0, 5, -600)
			local pushing = ForestTest.beaterPosition(centre, 1, false)
			expect(pushing).to.be.ok()
			expect((pushing :: Vector3).Z > centre.Z).to.equal(true) -- north of them: the drive's side
			expect(ForestTest.beaterPosition(centre, ForestTest.WAVE.pushSeconds, false)).to.equal(nil)
		end)
	end)

	-- THE ROLE KAREN ASKS FOR BY TYPING (task 151, docs/design/beater-kit.md section 9). This world
	-- has no beaters -- its drivers are phantom positions with nobody standing on them -- so the only
	-- way to SEE the beater outfit here is to ask for it. The chat itself cannot be driven by the
	-- harness (`tests/client/input_scenarios.txt` expresses keys, mouse and gaps, not text), so what
	-- is asserted here is the PARSER and the store, and the console line from the Forest Test place
	-- is the other half of the evidence.
	describe("which role the player has asked for", function()
		it("reads the two commands, however they are typed", function()
			expect(ForestTest.parseRole("/beater")).to.equal("beater")
			expect(ForestTest.parseRole("/hunter")).to.equal("hunter")
			expect(ForestTest.parseRole("  /BEATER ")).to.equal("beater")
			expect(ForestTest.parseRole("/Hunter")).to.equal("hunter")
			-- and nothing else is a role, including the horn that is task 152
			expect(ForestTest.parseRole("/horn")).to.equal(nil)
			expect(ForestTest.parseRole("beater")).to.equal(nil) -- no slash: ordinary chat
			expect(ForestTest.parseRole("/beater now")).to.equal(nil)
			expect(ForestTest.parseRole("")).to.equal(nil)
			expect(ForestTest.parseRole(nil)).to.equal(nil)
		end)

		it("reads the role off the TEAM, which is the drive's own answer (task 157)", function()
			-- `roleOf(userId)` is gone: the real `Match` runs in that world now and it reads
			-- `state.assignment`, so a role table of this module's own would have been a second
			-- answer -- and the one the drive did not believe.
			expect(ForestTest.ROLE_DEFAULT).to.equal("hunter")
			expect(ForestTest.roleFor(Data.PUSH_TEAM)).to.equal("beater")
			expect(ForestTest.roleFor("Shooters")).to.equal("hunter")
			expect(ForestTest.roleFor(nil)).to.equal("hunter")
			expect(ForestTest.roleFor("something else")).to.equal("hunter")
		end)

		it("holds a role ASK as a one-shot request, so it cannot defeat the rotation (task 157)", function()
			local userId = -151 -- no player has a negative id, so this cannot touch the live one
			ForestTest.clearRequest(userId)
			expect(ForestTest.pendingRequest(userId)).to.equal(nil)
			expect(ForestTest.requestRole(userId, "beater")).to.equal("beater")
			expect(ForestTest.pendingRequest(userId)).to.equal("beater")
			-- TAKEN ONCE. Karen asked for hunter-then-beater-then-hunter
			-- (`SWAP_TEAMS_EACH_DRIVE`), and a request that stuck would pin her on one side for
			-- ever -- so honouring it consumes it.
			expect(ForestTest.takeRequest(userId)).to.equal("beater")
			expect(ForestTest.takeRequest(userId)).to.equal(nil)
			expect(ForestTest.pendingRequest(userId)).to.equal(nil)
			ForestTest.requestRole(userId, "hunter")
			ForestTest.clearRequest(userId)
			expect(ForestTest.pendingRequest(userId)).to.equal(nil)
		end)

		it("gives a solo hunter the stand the drive aims at, centre-out (task 157)", function()
			-- `Body.placementFor` would hand her `posts[1]` -- 600 studs west of the push -- and
			-- whether she ever got a crossing would be luck again (the defect task 123 round 8
			-- measured). `standIndexFor(1)` is the default stand, which is the x `hunterStandX()`
			-- aims every wave at.
			expect(ForestTest.standIndexFor(1)).to.equal(Data.PICK.defaultIndex)
			expect(ForestTest.standIndexFor(1)).to.equal(5)
			local order = {}
			for index = 1, Data.STAND_COUNT do
				local stand = ForestTest.standIndexFor(index)
				expect(stand >= 1 and stand <= Data.STAND_COUNT).to.equal(true)
				expect(order[stand]).to.equal(nil) -- every stand once: nine hunters, nine stands
				order[stand] = index
			end
			expect(ForestTest.standIndexFor(2)).to.equal(4)
			expect(ForestTest.standIndexFor(3)).to.equal(6)
			-- ...and a tenth hunter wraps onto the middle stand rather than onto nothing. With
			-- `MAX_PLAYERS` 16 and a balanced split there are at most 8 shooters, so this is
			-- unreachable in production -- which is a claim, so it is asserted.
			expect(ForestTest.standIndexFor(Data.STAND_COUNT + 1)).to.equal(ForestTest.standIndexFor(1))
		end)

		it("finds a stand by NAME, because a refused stand shortens the list (task 157)", function()
			-- MEASURED in the Forest Test: `8/9 stands (1 refused), max ground delta 6.99`. With
			-- eight posts in the list the fifth entry is not stand 5, and stand 5's x is where the
			-- drive aims every wave -- so the post is found by the name the marker builder gave it.
			local full = {}
			for index = 1, Data.STAND_COUNT do
				table.insert(full, { Name = string.format("Stand%d", index) })
			end
			expect(ForestTest.postIndexFor(full, 5)).to.equal(5)
			-- stand 3 refused: stand 5 is now the FOURTH entry
			local short = {}
			for index = 1, Data.STAND_COUNT do
				if index ~= 3 then
					table.insert(short, { Name = string.format("Stand%d", index) })
				end
			end
			expect(ForestTest.postIndexFor(short, 5)).to.equal(4)
			expect(short[ForestTest.postIndexFor(short, 5)].Name).to.equal("Stand5")
			-- a list that names them some other way falls back to the index, which is what the DEV
			-- world's tagged posts are (and that world never calls this)
			expect(ForestTest.postIndexFor({ { Name = "Post1" }, { Name = "Post2" } }, 2)).to.equal(2)
			expect(ForestTest.postIndexFor({}, 7)).to.equal(7)
		end)

		it("hands the drive a boar view it cannot spawn or clear with (task 157)", function()
			-- ONE OWNER OF THE ANIMALS, as a test rather than as a comment. `Match` scores kills and
			-- escapes off the two signals; it has no door to release or wipe a wood that is this
			-- world's. `applyClearBoars` is already written as `if world.boars.clear`, so the absence
			-- IS the guard.
			local fake = {
				Downed = "downed-signal" :: any,
				Despawned = "despawned-signal" :: any,
				boars = function()
					return { "a", "b" }
				end,
				count = function()
					return 2
				end,
				capacity = function()
					return 60
				end,
				clear = function() end,
				spawn = function() end,
				spawnSounder = function() end,
			}
			local view = ForestTest.readOnlyBoars(fake)
			expect(view.clear).to.equal(nil)
			expect(view.spawn).to.equal(nil)
			expect(view.spawnSounder).to.equal(nil)
			expect(view.Downed).to.equal("downed-signal")
			expect(view.Despawned).to.equal("despawned-signal")
			expect(#view:boars()).to.equal(2)
			expect(view:count()).to.equal(2)
			expect(view:capacity()).to.equal(60)
		end)

		it("turns the role into what a boar actually sees (task 153)", function()
			-- A BEATER IS A DRIVER AND ANYBODY ELSE IS A SHOOTER, which is the whole of task 153's
			-- wiring: the Brain pushes an animal away from a `driver` and spooks it with anything
			-- else (`Boar.CONFIG.PACE`), so before this the player's own walk SPOOKED the wave she
			-- was supposed to be pushing.
			expect(ForestTest.threatKind("beater")).to.equal("driver")
			expect(ForestTest.threatKind("hunter")).to.equal("shooter")
			expect(ForestTest.threatKind(nil)).to.equal("shooter")
		end)

		it("marks a REAL beater as a driver in the boar's own threat list (task 153)", function()
			-- THE WIRING ITSELF, against the live `Players` service, because the kind is what the
			-- Brain branches on: a `driver` PUSHES an animal (walk, or a trot inside
			-- `PACE.TROT_WITHIN_STUDS`) and anything else SPOOKS it into a run inside
			-- `PACE.SPOOK_STUDS`. Before this task every player in this world was a `shooter`
			-- whatever role they had asked for.
			local Players = game:GetService("Players")
			local player = nil
			for _, candidate in ipairs(Players:GetPlayers()) do
				local character = candidate.Character
				-- `boarThreats` reads `character.PrimaryPart`, so a player without one is not in
				-- the list at all and is not the case this proves.
				if character and character.PrimaryPart then
					player = candidate
					break
				end
			end
			if player == nil then
				-- NOT A PASS DRESSED AS ONE: with nobody in the world there is no real threat to
				-- mark, and the pure half above is what still holds.
				TestKit.note("forest-beater: no player with a character; the threat-list case did not run")
				return
			end
			-- NOTHING IS WRITTEN HERE SINCE TASK 157, and that is deliberate: `Player.Team` has one
			-- writer (`Match.Body.setTeam`, from the drive's own roster), and a spec that wrote it to
			-- stage a case would be the second writer this whole task exists to remove -- in the
			-- middle of a harness run where other specs are reading the same field. So the live half
			-- asserts the WIRING -- the kind this player is reported as is the kind her team says --
			-- and the pure half above asserts both answers.
			local function threatOf()
				for _, threat in ipairs(ForestTest.boarThreats(0)) do
					if threat.id == tostring(player.UserId) then
						return threat
					end
				end
				return nil
			end
			local team = player.Team
			local teamName = if team then team.Name else nil
			-- SPELLED OUT HERE AND NOT DERIVED THE WAY `boarThreats` DERIVES IT (round 1's first
			-- note): `threatKind(roleFor(teamName))` is exactly what the function under test does, so
			-- asserting against it asserted nothing. A beater pushes and anybody else spooks, which
			-- is the rule in the words the Brain branches on.
			local wanted = if teamName == Data.PUSH_TEAM then "driver" else "shooter"
			local threat = threatOf()
			expect(threat).to.be.ok()
			expect((threat :: any).kind).to.equal(wanted)
			-- ...AND NOT A PHANTOM. The drive marks its invented beaters `phantom = true` so that
			-- `PACE.DRIVER_RUN_STUDS` cannot fire on one; a player standing there is real, and the
			-- absence of the mark is what makes her walk count.
			expect((threat :: any).phantom).to.equal(nil)
			TestKit.note(
				string.format(
					"forest-beater: %s is on %s, so a boar sees a %s",
					player.Name,
					tostring(if team then team.Name else nil),
					(threat :: any).kind
				)
			)
		end)

		it("reads the start switch, with or without the slash Karen types (task 153)", function()
			-- The attribute is set by hand -- `SetAttribute("DHForestStartRole", "beater")` -- so it
			-- is a bare word; the chat command is `/beater`. Both mean the same role and anything
			-- else means "nobody has said", which is the hunter this world has always started her as.
			expect(ForestTest.startRole("beater")).to.equal("beater")
			expect(ForestTest.startRole("/beater")).to.equal("beater")
			expect(ForestTest.startRole(" Hunter ")).to.equal("hunter")
			expect(ForestTest.startRole("driver")).to.equal(nil)
			expect(ForestTest.startRole("")).to.equal(nil)
			expect(ForestTest.startRole(nil)).to.equal(nil)
			expect(ForestTest.startRole(7)).to.equal(nil)
			expect(ForestTest.startRole(true)).to.equal(nil)
			-- The attribute's NAME is the world's, so the Director and the server read one string.
			expect(Data.START_ROLE_ATTRIBUTE).to.equal("DHForestStartRole")
		end)

		it("translates Karen's word through Match.Body, which is the one translator", function()
			-- `ForestTest` answers in KAREN'S words and never in team names: the mapping lives in
			-- `Match.Body.ROLE_WORDS` alone, so "beater means Drivers" is written down once.
			local Body = require(ServerScriptService:WaitForChild("Match")).Body
			expect(Body.teamForWord(ForestTest.roleFor(nil))).to.equal("Shooters")
			expect(Body.teamForWord(ForestTest.roleFor(Data.PUSH_TEAM))).to.equal(Data.PUSH_TEAM)
			expect(Body.teamForWord("beater")).to.equal("Drivers")
			expect(Body.teamForWord("hunter")).to.equal("Shooters")
			expect(Body.teamForWord("x")).to.equal(nil)
		end)
	end)

	-- WHERE A BEATER STARTS, AND WHY SHE IS NOT HELD TO A STAND (task 153). Karen, 2026-10-11:
	-- *"how to start a game as a beter?"*, and then *"beater are behind animals and moving towards
	-- hunter line (road) like in real life ... we will try walk spook, use horn have that feeling"*.
	describe("where a beater starts", function()
		it("puts her behind the line's own spawn, on the push line, north of the road", function()
			local standX = Data.standX(Data.PICK.defaultIndex)
			local at = Data.beaterStart(standX)
			-- BEHIND THE ANIMALS BY CONSTRUCTION: a line is released `LINE.spawnNorthStuds` north of
			-- the road, so she is `BEATER.behindLineStuds` further north than every animal the drive
			-- has just put down -- not a number that merely happens to be bigger.
			local north = at.Z - Data.roadZ(at.X)
			expect(north).to.be.near(Data.LINE.spawnNorthStuds + Data.BEATER.behindLineStuds, 1e-2)
			expect(north > Data.LINE.spawnNorthStuds).to.equal(true)
			expect(at.X).to.be.near(standX, 1e-6)
			-- ...and a sidestep moves her sideways and nowhere else: still on the curve's own offset.
			local beside = Data.beaterStart(standX, Data.BEATER.sideStepStuds)
			expect(beside.X).to.be.near(standX + Data.BEATER.sideStepStuds, 1e-6)
			expect(beside.Z - Data.roadZ(beside.X)).to.be.near(north, 1e-2)
			TestKit.note(
				string.format(
					"forest-beater: start %.0f studs north of the road (line spawns at %.0f), road point z=%.1f",
					north,
					Data.LINE.spawnNorthStuds,
					Data.roadPointAt(standX).Z
				)
			)
		end)

		it("looks AT the road, which is the way she is pushing", function()
			local standX = Data.standX(Data.PICK.defaultIndex)
			local at = Data.beaterStart(standX)
			local road = Data.roadPointAt(at.X)
			-- The point she faces is on the road curve at her own x, and it is SOUTH of her: the
			-- compass bearing of that direction is `PUSH_BEARING_DEG`, which is 180 from the
			-- direction the drive comes from.
			expect(road.Z).to.be.near(Data.roadZ(at.X), 1e-6)
			expect(road.Z < at.Z).to.equal(true)
			expect(Data.PUSH_BEARING_DEG).to.equal((Data.DRIVE_BEARING_DEG + 180) % 360)
			expect(Data.PUSH_TEAM).to.equal("Drivers")
		end)

		it("never answers nil or a point off the push line, whatever the ground says", function()
			-- THIS RUNS IN THE DEV PLACE, where this world's coordinates have no terrain under them:
			-- the fallback is therefore what is proved here, and what it must never do is answer nil
			-- or a point off the push line. The live numbers -- her actual y and the nearest trunk --
			-- are measured in the Forest Test place and written into the task's request.
			local at = ForestTest.beaterStartPosition()
			expect(at).to.be.ok()
			local north = at.Z - Data.roadZ(at.X)
			expect(north).to.be.near(Data.LINE.spawnNorthStuds + Data.BEATER.behindLineStuds, 1e-2)
			expect(at.Y == at.Y).to.equal(true) -- not a NaN: the y comes from a measurement or a default
		end)

		it("puts each lane of the line on its own x, across the hunters' front (task 167)", function()
			-- KAREN, 2026-10-12: *"and seem like all bots came to me"*. Every beater used to be put
			-- on the push line itself whatever its index, so the bot line arrived at her stand.
			local push = ForestTest.beaterStartPosition(1)
			local xs = { [1] = push.X }
			for index = 2, 5 do
				local lane = ForestTest.beaterStartPosition(index)
				xs[index] = lane.X
				-- ITS OWN x, on the stand grid, measured to the clear-spot search's tolerance: the
				-- search may step up to `sideTries * sideStepStuds` sideways to miss a trunk.
				local wanted = push.X + Data.beaterLaneOffset(index)
				expect(math.abs(lane.X - wanted) <= Data.BEATER.sideTries * Data.BEATER.sideStepStuds).to.equal(true)
				-- ...and still the same depth north of the road at its own x.
				local north = lane.Z - Data.roadZ(lane.X)
				expect(north).to.be.near(Data.LINE.spawnNorthStuds + Data.BEATER.behindLineStuds, 1e-2)
			end
			-- FOUR BOT LANES SPAN THE FRONT, not 72 studs of it.
			expect(math.abs(xs[4] - xs[5]) >= 500).to.equal(true)
		end)

		it("finds the nearest beater, flat, and says so when there is none", function()
			-- WHAT `stepLines` ASKS BEFORE IT FLUSHES AN ANIMAL. Flat, because the hill between a
			-- beater's start and the road climbs 94 studs in 580 (MEASURED in the place, task 162;
			-- it was 16 in 240 before the start was deepened) and a beater uphill of a boar is not
			-- further from it than one beside it.
			local none, gap = ForestTest.nearestBeater(Vector3.new(0, 0, 0), {})
			expect(none).to.equal(nil)
			expect(gap).to.equal(math.huge)
			local beaters = {
				{ id = "a", position = Vector3.new(30, 0, 0) },
				{ id = "b", position = Vector3.new(0, 90, 12) },
			}
			local at, near = ForestTest.nearestBeater(Vector3.new(0, 0, 0), beaters)
			expect(at).to.be.ok()
			expect((at :: Vector3).Z).to.be.near(12, 1e-6) -- the closer one FLAT, 90 studs up or not
			expect(near).to.be.near(12, 1e-6)
		end)

		it("does not hold a beater to a stand", function()
			-- WITHOUT THIS THE WHOLE TASK IS DEAD: she walks 580 studs south (240 when task 153
			-- wrote this), and a hunter's stand circle would pull her back to the road every
			-- heartbeat.
			local userId = -153
			local part = Instance.new("Part")
			part.CFrame = CFrame.new(Data.standPosition(5) + Vector3.new(60, 0, 0))
			ForestTest.openPick(userId, 0)
			ForestTest.lockPick(userId, Data.standPosition(5), 0)

			-- THE ROLE IS A PARAMETER SINCE TASK 157: its truth is `Player.Team`, and the caller is
			-- what holds the `Player` -- this module keys by `userId` and never holds one.
			expect(ForestTest.boundary(userId, part, "hunter")).to.be.ok() -- 60 studs out IS stopped

			part.CFrame = CFrame.new(Data.standPosition(5) + Vector3.new(60, 0, 0))
			expect(ForestTest.boundary(userId, part, "beater")).to.equal(nil)
			-- ...and the part was not moved either: the boundary is the one writer of that CFrame.
			expect(part.Position.X).to.be.near(Data.standPosition(5).X + 60, 1e-3)
			-- `nil` means "nobody said", which is the hunter this world starts her as.
			expect(ForestTest.boundary(userId, part, nil)).to.be.ok()

			ForestTest.clearPick(userId)
			part:Destroy()
		end)

		-- TASK 166, THE LIVE HALF: what the wall does to a character that walks into it. The pure
		-- half above says WHERE; these say that the two writes happen, that they happen only to a
		-- locked hunter, and that a player inside his circle is not written at all.
		it("stops a hunter at the edge and takes away only his OUTWARD speed", function()
			local userId = -166
			local home = Data.standPosition(5)
			local radius = Data.PICK.standRadiusStuds
			local part = Instance.new("Part")
			ForestTest.openPick(userId, 0)
			ForestTest.lockPick(userId, home, 0)

			-- He is 40 studs out, running straight out at 16 studs/s with 10 of sideways and a
			-- fall of -30 on him.
			part.CFrame = CFrame.new(home + Vector3.new(40, 3, 0)) * CFrame.Angles(0, math.rad(35), 0)
			local facing = part.CFrame.LookVector
			part.AssemblyLinearVelocity = Vector3.new(16, -30, 10)
			local to = ForestTest.boundary(userId, part, "hunter")
			expect(to).to.be.ok()

			-- ON THE CIRCLE, and his height and his facing are his own.
			local flat = Vector3.new(part.Position.X - home.X, 0, part.Position.Z - home.Z)
			expect(flat.Magnitude).to.be.near(radius, 1e-3)
			expect(part.Position.Y).to.be.near(home.Y + 3, 1e-3)
			expect(part.CFrame.LookVector:Dot(facing)).to.be.near(1, 1e-4)

			-- THE OUTWARD PART OF THE VELOCITY IS GONE -- that is what makes the edge a wall rather
			-- than a rubber band -- and NOTHING ELSE IS. He walked out along +X, so +X goes and the
			-- sideways 10 and the falling -30 stay.
			local velocity = part.AssemblyLinearVelocity
			expect(velocity.X).to.be.near(0, 1e-4)
			expect(velocity.Z).to.be.near(10, 1e-4)
			expect(velocity.Y).to.be.near(-30, 1e-4)

			-- INSIDE THE CIRCLE NOTHING IS WRITTEN AT ALL: he keeps walking, at speed.
			part.CFrame = CFrame.new(home + Vector3.new(radius - 2, 3, 0))
			part.AssemblyLinearVelocity = Vector3.new(16, 0, 0)
			expect(ForestTest.boundary(userId, part, "hunter")).to.equal(nil)
			expect(part.AssemblyLinearVelocity.X).to.be.near(16, 1e-4)
			expect(part.Position.X).to.be.near(home.X + radius - 2, 1e-3)

			-- ...AND A HUNTER WALKING ALONG THE EDGE KEEPS THAT SPEED. Only the component pointing
			-- away from the stand is removed, so he can circle his own stand.
			part.CFrame = CFrame.new(home + Vector3.new(radius + 1, 3, 0))
			part.AssemblyLinearVelocity = Vector3.new(0, 0, 14)
			expect(ForestTest.boundary(userId, part, "hunter")).to.be.ok()
			expect(part.AssemblyLinearVelocity.Z).to.be.near(14, 1e-4)

			-- AND AN UNLOCKED PICK IS NOT BOUNDED: the ten seconds are for walking to a stand.
			ForestTest.clearPick(userId)
			ForestTest.openPick(userId, 0)
			part.CFrame = CFrame.new(home + Vector3.new(40, 3, 0))
			expect(ForestTest.boundary(userId, part, "hunter")).to.equal(nil)
			expect(part.Position.X).to.be.near(home.X + 40, 1e-3)

			ForestTest.clearPick(userId)
			part:Destroy()
		end)
	end)

	---------------------------------------------------------------- the wood a beater walks into

	describe("how close she may get, and how far the horn reaches (task 154)", function()
		it("writes the beater's reach in metres AND in studs, and the two agree to the stud", function()
			-- TASK 150'S LESSON, pinned here as it is pinned in `zz_horn.spec`: a radius written in
			-- studs was compared against distances in metres for two tasks.
			local derived = Data.SPOOK.BEATER_M / Data.SPOOK.METRES_PER_STUD
			expect(math.abs(Data.SPOOK.BEATER_STUDS - derived) <= 1).to.equal(true)
			-- ONE CONVERSION IN THE REPO, not one per system.
			expect(Data.SPOOK.METRES_PER_STUD).to.equal(Boar.CONFIG.SENSE.METRES_PER_STUD)
			expect(Data.SPOOK.METRES_PER_STUD).to.equal(Horn.CONFIG.METRES_PER_STUD)
			TestKit.note(
				string.format(
					"beater reach %d m = %.1f studs, written as %d",
					Data.SPOOK.BEATER_M,
					derived,
					Data.SPOOK.BEATER_STUDS
				)
			)
		end)

		it("resolves the reach from either unit, like the horn's", function()
			expect(Data.beaterSpookStuds(Data.SPOOK)).to.equal(Data.SPOOK.BEATER_STUDS)
			-- A world that overrides the STUDS means the studs...
			expect(Data.beaterSpookStuds({ BEATER_STUDS = 40, BEATER_M = 999, METRES_PER_STUD = 0.28 })).to.equal(40)
			-- ...and one that gives only metres gets them converted here, in the one place that does it.
			expect(math.abs(Data.beaterSpookStuds({ BEATER_M = 28, METRES_PER_STUD = 0.28 }) - 100) < 1e-6).to.equal(
				true
			)
		end)

		it("makes the horn reach further than her own feet do", function()
			-- KAREN, 2026-10-11: *"horn reach is further once they hear also run without stop"*. The
			-- horn's whole reason to exist against a 25 m walk-up is that it covers ground she
			-- cannot.
			expect(Horn.spookStuds(Horn.CONFIG) > Data.beaterSpookStuds(Data.SPOOK)).to.equal(true)
			TestKit.note(string.format("horn %d m vs beater %d m", Horn.CONFIG.SPOOK_M, Data.SPOOK.BEATER_M))
		end)
	end)

	describe("where the resting groups go (task 154)", function()
		local standX = Data.standX(Data.PICK.defaultIndex)

		it("puts every group between her and the road, and none of them inside her reach", function()
			-- KAREN: *"so animals already there somewhere in bushes close to trees ect"* -- which
			-- means in front of her and short of the road.
			--
			-- ...AND NOT ALREADY INSIDE IT, which is this task's own measured mistake: the first
			-- layout put a group 71 studs from where she is put down, inside `BEATER_STUDS` (89), so
			-- it was latched and gone on the first heartbeat before she had taken a step.
			local start = Data.beaterStart(standX, 0)
			local keepAway = Data.beaterSpookStuds(Data.SPOOK) + Data.REST.clearOfStartStuds
			local closest, nearestRoad, farthestRoad = math.huge, math.huge, 0
			for _, spec in ipairs(Data.REST.groups) do
				local at = Data.restPoint(standX, spec)
				local dz = at.Z - Data.roadZ(at.X)
				expect(dz >= Data.REST.nearRoadStuds).to.equal(true)
				expect(dz <= Data.REST.farRoadStuds).to.equal(true)
				nearestRoad = math.min(nearestRoad, dz)
				farthestRoad = math.max(farthestRoad, dz)
				local gap = Vector3.new(at.X - start.X, 0, at.Z - start.Z).Magnitude
				expect(gap >= keepAway).to.equal(true)
				closest = math.min(closest, gap)
			end
			-- ...and the band itself has to be north of the road, or "between her and the road" is
			-- a group standing on it.
			expect(Data.REST.nearRoadStuds > Data.ROAD.halfWidthStuds).to.equal(true)
			TestKit.note(
				string.format(
					"%d resting groups at %.0f-%.0f studs from the road; the nearest is %.0f studs from her start (reach %d + %d)",
					#Data.REST.groups,
					nearestRoad,
					farthestRoad,
					closest,
					Data.beaterSpookStuds(Data.SPOOK),
					Data.REST.clearOfStartStuds
				)
			)
		end)

		it("takes the band as deep as the keep-away allows, so none of the walk is empty", function()
			-- TASK 162. The walk is 580 studs now (`BEATER.behindLineStuds` 400 +
			-- `LINE.spawnNorthStuds` 180), and the band this table may put a group in is the ONLY
			-- thing that decides whether she meets anything on the way down. Leaving it at 160 would
			-- have put every group in the last quarter of the walk and the first 420 studs would have
			-- been empty wood -- which is the defect task 154 exists to prevent, in a new form.
			--
			-- SO `farRoadStuds` IS DERIVED: as deep as the keep-away permits and no deeper. The
			-- keep-away is one spook reach plus `clearOfStartStuds`, so a group at the far edge is
			-- still outside her reach when she is put down.
			local start = Data.LINE.spawnNorthStuds + Data.BEATER.behindLineStuds
			local keepAway = Data.beaterSpookStuds(Data.SPOOK) + Data.REST.clearOfStartStuds
			expect(Data.REST.farRoadStuds + keepAway <= start).to.equal(true)
			-- ...AND NO SHALLOWER THAN THAT EITHER, within a stud of rounding: a band that stopped
			-- short would be empty wood nobody chose. This is the half that would have failed before
			-- task 162 (160 + 119 against 240 passes the line above and leaves 80 studs unused).
			expect(start - (Data.REST.farRoadStuds + keepAway) < 2).to.equal(true)
			-- The band covers most of the walk, which is the sentence the two bounds add up to.
			local covered = (Data.REST.farRoadStuds - Data.REST.nearRoadStuds) / start
			expect(covered > 0.6).to.equal(true)
			TestKit.note(
				string.format(
					"the resting band is %d-%d studs of a %d-stud walk (%.0f%% of it); keep-away %d",
					Data.REST.nearRoadStuds,
					Data.REST.farRoadStuds,
					start,
					covered * 100,
					keepAway
				)
			)
		end)

		it("never puts two resting groups inside one spook reach of each other", function()
			-- WHY THE DEPTHS ARE SPACED THE WAY THEY ARE (task 162). `SPOOK.BEATER_STUDS` is 89, and
			-- the fright LATCHES -- `ForestTest.SPOOK`'s own header: *"the animal keeps the line it
			-- set off on, it never settles"*. So two groups inside 89 studs of each other both bolt
			-- on one approach and six groups become three events. A walk down a deep wood is only a
			-- walk if the wood gives them up one at a time.
			--
			-- THE PAIRS ARE MEASURED FLAT in the stand's own frame, which is what `restPoint` returns
			-- before the ground is read: the x is `offsetX` from her line and the z is the depth, and
			-- the ground does not change a horizontal distance.
			local reach = Data.beaterSpookStuds(Data.SPOOK)
			local worst, deepest, shallowest = math.huge, 0, math.huge
			local groups = Data.REST.groups
			for i = 1, #groups do
				local here = Data.restPoint(standX, groups[i])
				local dz = here.Z - Data.roadZ(here.X)
				deepest = math.max(deepest, dz)
				shallowest = math.min(shallowest, dz)
				for j = i + 1, #groups do
					local there = Data.restPoint(standX, groups[j])
					local gap = Vector3.new(here.X - there.X, 0, here.Z - there.Z).Magnitude
					worst = math.min(worst, gap)
				end
			end
			-- WITH MARGIN, not by a stud: the ring search may move a spot up to `searchRings *
			-- searchStepStuds` (64) from its nominal point, so a pair that clears the reach by five
			-- studs on paper does not clear it in the wood. The first layout of this table was 94.7
			-- apart against a reach of 89 and the offsets were widened for exactly this assertion.
			expect(worst > reach + 25).to.equal(true)
			-- ...and they are spread down the walk rather than stacked in one band: the deepest and
			-- the shallowest are more than half the walk apart.
			expect(deepest - shallowest > (Data.LINE.spawnNorthStuds + Data.BEATER.behindLineStuds) / 2).to.equal(true)
			TestKit.note(
				string.format(
					"%d groups over %.0f studs of depth (%.0f to %.0f); closest pair %.0f studs, reach %.0f",
					#groups,
					deepest - shallowest,
					shallowest,
					deepest,
					worst,
					reach
				)
			)
		end)

		it("names a real composition for every group, and asks for fewer animals than the world holds", function()
			-- WHO IS IN A FLOCK IS THE BOAR SYSTEM'S FACT, so an index that names nothing would
			-- silently stock the wood with lone males.
			local total = 0
			for _, spec in ipairs(Data.REST.groups) do
				local composition = Boar.CONFIG.SOUNDER.COMPOSITIONS[spec.composition]
				expect(composition).to.be.ok()
				total += Boar.compositionSize(composition)
				expect(type(spec.note)).to.equal("string")
			end
			-- Karen: *"make them a lot not too much to break but enough to test"*.
			expect(total <= Data.MAX_BOARS).to.equal(true)
			expect(total > 0).to.equal(true)
			TestKit.note(
				string.format(
					"the wood is stocked with %d animals in %d groups (cap %d)",
					total,
					#Data.REST.groups,
					Data.MAX_BOARS
				)
			)
		end)

		it("searches sideways and outward without ever leaving the band", function()
			-- `restSpot` walks rings around the nominal point; `restPoint` is the pure half it walks,
			-- and a ring that put a group on the road would be a boar standing in front of the gun.
			local spec = Data.REST.groups[1]
			local reach = Data.REST.searchRings * Data.REST.searchStepStuds
			local moved = Data.restPoint(standX, spec, reach, 0)
			expect(math.abs(moved.X - Data.restPoint(standX, spec).X)).to.be.near(reach, 1e-3)
			local out = Data.restPoint(standX, spec, 0, reach)
			expect(out.Z - Data.restPoint(standX, spec).Z).to.be.near(reach, 1e-3)
		end)

		it("takes a spot that is on the ground and in the trees, and refuses every other kind", function()
			-- `ForestTest.restSpotOk` is the whole rule, pure: five measurements in, yes or no out.
			-- `restSpot` takes the measurements and this decides. Hand-written numbers here, so the
			-- rule is asserted in the DEV place where this world's terrain does not exist.
			local rest = Data.REST
			local keepAway = Data.beaterSpookStuds(Data.SPOOK) + rest.clearOfStartStuds
			-- A spot that is right in every way: in the band, clear of her start, on terrain the
			-- spawn ray agrees with, and a trunk's width away from a trunk.
			local dz = (rest.nearRoadStuds + rest.farRoadStuds) / 2
			local trunk = (rest.clearStuds + rest.nearTrunkStuds) / 2
			local function ok(...)
				return ForestTest.restSpotOk(...)
			end
			expect(ok(dz, keepAway, trunk, 140, 140, rest, keepAway)).to.equal(true)

			-- TOO NEAR THE ROAD, and too far from it: a boar standing on the verge in front of the
			-- gun, and one behind where she starts.
			expect(ok(rest.nearRoadStuds - 1, keepAway, trunk, 140, 140, rest, keepAway)).to.equal(false)
			expect(ok(rest.farRoadStuds + 1, keepAway, trunk, 140, 140, rest, keepAway)).to.equal(false)
			-- ...and the two boundaries themselves are IN, or the band is not the band it says.
			expect(ok(rest.nearRoadStuds, keepAway, trunk, 140, 140, rest, keepAway)).to.equal(true)
			expect(ok(rest.farRoadStuds, keepAway, trunk, 140, 140, rest, keepAway)).to.equal(true)

			-- ALREADY INSIDE HER REACH: this task's own measured mistake, as an assertion.
			expect(ok(dz, keepAway - 1, trunk, 140, 140, rest, keepAway)).to.equal(false)
			expect(ok(dz, keepAway, trunk, 140, 140, rest, keepAway)).to.equal(true)

			-- INSIDE A TRUNK, and out in the open with nothing near: both are "no".
			expect(ok(dz, keepAway, rest.clearStuds - 1, 140, 140, rest, keepAway)).to.equal(false)
			expect(ok(dz, keepAway, rest.nearTrunkStuds + 1, 140, 140, rest, keepAway)).to.equal(false)
			-- `nearestSolid` answers `math.huge` for nothing within its radius, which is the shape
			-- the open-ground case actually arrives in.
			expect(ok(dz, keepAway, math.huge, 140, 140, rest, keepAway)).to.equal(false)

			-- THE SPAWN RAY STOPPED ON A CANOPY: the terrain says 140 and `groundAt` says 196, which
			-- is 56 studs of tree (task 153 measured exactly that hill). A sounder dropped from
			-- there falls out of a tree.
			expect(ok(dz, keepAway, trunk, 140, 196, rest, keepAway)).to.equal(false)
			expect(ok(dz, keepAway, trunk, 140, 140 + rest.canopySlackStuds, rest, keepAway)).to.equal(true)
			expect(ok(dz, keepAway, trunk, 140, 140 + rest.canopySlackStuds + 1, rest, keepAway)).to.equal(false)

			-- NO GROUND AT ALL is "no spot", never "close enough": off the edge of the terrain,
			-- either ray can answer nil.
			expect(ok(dz, keepAway, trunk, nil, 140, rest, keepAway)).to.equal(false)
			expect(ok(dz, keepAway, trunk, 140, nil, rest, keepAway)).to.equal(false)

			TestKit.note(
				string.format(
					"a resting spot: dz %d-%d, >= %.0f studs from her start, %d-%d studs from the nearest trunk, terrain and spawn ray within %d",
					rest.nearRoadStuds,
					rest.farRoadStuds,
					keepAway,
					rest.clearStuds,
					rest.nearTrunkStuds,
					rest.canopySlackStuds
				)
			)
		end)

		it("is TRUE for a roster with a beater on it and FALSE without one (task 157 round 2)", function()
			-- ROUND 1's FINDING 1, and it was right: the case here compared `beaterMode()` against a
			-- loop that WAS `beaterMode()`, in a place where both answers are false -- so
			-- `return false` would have passed it, and this predicate is the ONE switch between the
			-- stocked resting wood and the 20-second wave schedule (`ForestTest.step`).
			--
			-- SO THE ROSTER IS HANDED IN, as a list of team names, exactly as `ForestTest.boundary`
			-- takes the role -- because the alternative is a spec writing `Player.Team`, which is the
			-- second writer this whole task removed. `Data.PUSH_TEAM` is the world's own name for the
			-- pushing side, so neither this spec nor that function hard-codes "Drivers".
			expect(ForestTest.beaterMode({ Data.PUSH_TEAM })).to.equal(true)
			expect(ForestTest.beaterMode({ "Shooters", Data.PUSH_TEAM })).to.equal(true)
			expect(ForestTest.beaterMode({ "Shooters" })).to.equal(false)
			expect(ForestTest.beaterMode({ "Shooters", "Shooters" })).to.equal(false)
			expect(ForestTest.beaterMode({})).to.equal(false)
			-- ...and a player with NO team (between a join and the drive's first assignment) is not a
			-- beater either, which is the state every session starts in.
			expect(ForestTest.beaterMode({ "" })).to.equal(false)
		end)

		it("answers for the live roster when it is handed nothing, and does not error", function()
			-- WHAT THIS PROVES AND WHAT IT DOES NOT (round 2's note, which is right): the gathering
			-- branch builds its list with the same loop this case does, and in the only roster the
			-- DEV place has -- one player on `Shooters` -- both sides are false, so `return false`
			-- would pass it. The case above is what carries the function; this one says the
			-- no-argument call reaches the live teams and does not error, and the note says which
			-- state it ran in.
			local Players = game:GetService("Players")
			local teams = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local team = player.Team
				table.insert(teams, if team then team.Name else "")
			end
			expect(ForestTest.beaterMode()).to.equal(ForestTest.beaterMode(teams))
			TestKit.note(
				string.format(
					"forest-beatermode: %d player(s) on [%s], beaterMode=%s",
					#teams,
					table.concat(teams, ","),
					tostring(ForestTest.beaterMode())
				)
			)
		end)
	end)

	describe("the bots replace the phantom beaters (task 161)", function()
		-- ONE PUSH SOURCE. This world invents a phantom beater 11 studs behind each herd, and a body
		-- Karen can SEE must not push at the same time as a position nobody is standing on -- or the
		-- thing she is watching is not the cause of what the animals do.
		--
		-- THE SOURCE IS INJECTED, so this spec drives both states with a table and the phantoms come
		-- straight back when it is cleared. `ForestTestBoot` sets it to `Bots.threats`; in the DEV
		-- place nothing sets it at all, which is the `nil` case below.
		local BOT_BEATER = { id = "bot-beater-1", position = Vector3.new(3030, 140, -1850), kind = "driver" }
		local BOT_HUNTER = { id = "bot-hunter-1", position = Vector3.new(3030, 142, -2100), kind = "shooter" }

		afterEach(function()
			ForestTest.setBotThreats(nil)
		end)

		it("answers no bots at all until a world injects a source", function()
			ForestTest.setBotThreats(nil)
			expect(#ForestTest.botThreats()).to.equal(0)
		end)

		it("puts a bot beater into the one list that says who is pushing", function()
			local before = #ForestTest.realBeaters()
			ForestTest.setBotThreats(function()
				return { BOT_BEATER, BOT_HUNTER }
			end)
			local after = ForestTest.realBeaters()
			expect(#after).to.equal(before + 1) -- the beater, not the hunter
			local found = false
			for _, beater in ipairs(after) do
				if beater.id == BOT_BEATER.id then
					found = true
					expect(beater.position).to.equal(BOT_BEATER.position)
				end
			end
			expect(found).to.equal(true)
			-- THAT LIST IS THE DOOR. `spookNearBeaters` reads exactly it, so a bot's walk flushes a
			-- file through the same rule a player's walk does, with no second push mechanism.
		end)

		it("DECIDES WHICH WAVES GET A PHANTOM, and the rule is what is asserted", function()
			-- ROUND 1'S FINDING 2: the old case asserted `phantoms == 0` out of `boarThreats`, and
			-- `state.active` is only ever filled by a running wave -- which nothing in the spec place
			-- does, because `ForestTestBoot` returns at once anywhere but the Forest Test and no spec
			-- calls `ForestTest.start`. So the assertion was true with the suppression DELETED.
			--
			-- `ForestTest.wavesToPush` is that choice, factored out and pure, so both states are
			-- stated with a hand-written wave list and no world at all. Delete the rule and the first
			-- expectation below fails.
			local waves = { { id = "wave-1" }, { id = "wave-2" } }

			-- NO BOTS: every wave gets its phantom, which is this file before task 161.
			expect(#ForestTest.wavesToPush(waves, {})).to.equal(2)
			expect(#ForestTest.wavesToPush(waves, nil)).to.equal(2)
			expect(ForestTest.wavesToPush(waves, {})[1].id).to.equal("wave-1")

			-- A BOT BEATER IS PUSHING: no wave gets one. One push source, and it is the body Karen
			-- can see.
			expect(#ForestTest.wavesToPush(waves, { BOT_BEATER })).to.equal(0)
			expect(#ForestTest.wavesToPush(waves, { BOT_HUNTER, BOT_BEATER })).to.equal(0)

			-- A BOT HUNTER IS NOT PUSHING ANYTHING: the phantoms stay.
			expect(#ForestTest.wavesToPush(waves, { BOT_HUNTER })).to.equal(2)

			-- NO WAVES AT ALL is not an error, and it is the state the spec place is really in.
			expect(#ForestTest.wavesToPush({}, { BOT_BEATER })).to.equal(0)
			expect(#ForestTest.wavesToPush(nil, {})).to.equal(0)
		end)

		it("routes boarThreats through that rule, and carries the bots themselves", function()
			local now = os.clock()
			ForestTest.setBotThreats(function()
				return { BOT_BEATER }
			end)
			local withBots = ForestTest.boarThreats(now)
			local bots = 0
			for _, threat in ipairs(withBots) do
				if threat.id == BOT_BEATER.id then
					bots += 1
					expect(threat.kind).to.equal("driver")
					-- NO MARK: somebody IS standing there, which is what makes `Boar.CONFIG.PACE`'s
					-- real-driver branch apply -- the whole point of a visible beater.
					expect((threat :: any).phantom).to.equal(nil)
				end
			end
			expect(bots).to.equal(1)
			-- WHAT THIS CASE DOES NOT PROVE, said out loud rather than counted as if it did: there
			-- are no phantoms in `withBots`, and there would be none with the suppression deleted
			-- either -- `state.active` is empty in the place the specs run in. The RULE is the case
			-- above; this one proves the WIRING, that `boarThreats` carries the bots and asks it.

			-- A BOT HUNTER DOES NOT SILENCE THEM: it is not pushing anything.
			ForestTest.setBotThreats(function()
				return { BOT_HUNTER }
			end)
			local hunterOnly = ForestTest.boarThreats(now)
			local stillThere = false
			for _, threat in ipairs(hunterOnly) do
				if threat.id == BOT_HUNTER.id then
					expect(threat.kind).to.equal("shooter")
				end
			end
			-- ...and with the source cleared the file is this file before task 161, by every branch.
			ForestTest.setBotThreats(nil)
			local plain = ForestTest.boarThreats(now)
			for _, threat in ipairs(plain) do
				if string.find(threat.id, "bot%-") then
					stillThere = true
				end
			end
			expect(stillThere).to.equal(false)
			TestKit.note(
				string.format(
					"forest-bots: threats with a bot beater=%d, with a bot hunter=%d, with none=%d"
						.. " (no waves run in this place, so the phantom COUNT here is not evidence -- the rule's own case is)",
					#withBots,
					#hunterOnly,
					#plain
				)
			)
		end)

		it("survives a source that errors, rather than taking the whole threat list down with it", function()
			ForestTest.setBotThreats(function(): any
				error("the bots are on fire")
			end)
			expect(#ForestTest.botThreats()).to.equal(0)
			-- ...and the phantoms are therefore NOT silenced: no bot is pushing, so the push does not
			-- gap. That is the same reason the rule reads a live fact instead of a boolean.
			expect(function()
				ForestTest.boarThreats(os.clock())
			end).never.to.throw()
		end)
	end)
end
