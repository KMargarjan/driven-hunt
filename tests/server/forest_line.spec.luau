-- forest_line.spec: THE ARITHMETIC OF A FILE OF BOARS, with no world, no animal and no clock.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- `ForestTest.Line` is pure by construction -- crumbs in, an arc position or a speed out -- so every
-- rule the drive relies on is drivable here with hand-written tables. The three that have actually
-- been wrong in play get their own cases: the SIGN of a follower's slack (round 2: an unsigned
-- distance cannot tell "behind" from "overshot", so both sped up), `arcAt` finding where an animal is
-- ON the trail rather than how far it is FROM it (round 2: following a chord cuts the corner the
-- leader went round, which is a trunk), and the leader easing up for her tail.
--
-- Design: no new design document -- the playtest world's drive. TASKS.md row 127.
-- Note:   docs/research/2026-10-05-sounder-movement.md (section 4: a chain cannot orbit)
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
-- THE BEATERS' OWN PACE (task 251c). A slot's release depth is now relative to where the LINE has
-- got to, so the case that proves "every group is released ahead of it" is a relation between three
-- modules: this schedule's clock, `Bots.CONFIG.WALK_SPEED` and the boar's `PACE`. None of the three
-- may be written down a second time here (`bots_lane.spec` holds the other half of the same pair --
-- that every slot is DUE before the line arrives).
local Bots = require(ServerScriptService:WaitForChild("Bots"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
local Line = ForestTest.Line
-- The world's own data (the road curve, the stands, the push line), for the drive-line case
-- task 157 added at the bottom.
local Data = ForestTest.Data
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))

-- A straight trail east along +X, one crumb a stud, then a right-angle turn south along -Z.
local function elbow()
	local trail = {}
	for x = 0, 20 do
		Line.addCrumb(trail, Vector3.new(x, 0, 0), 1)
	end
	for z = 1, 20 do
		Line.addCrumb(trail, Vector3.new(20, 0, -z), 1)
	end
	return trail
end

return function()
	describe("the trail", function()
		it("only remembers a crumb once the leader has moved", function()
			local trail = {}
			expect(Line.addCrumb(trail, Vector3.new(0, 0, 0), 1)).to.equal(true)
			expect(Line.addCrumb(trail, Vector3.new(0.4, 0, 0), 1)).to.equal(false)
			expect(Line.addCrumb(trail, Vector3.new(2, 0, 0), 1)).to.equal(true)
			expect(#trail).to.equal(2)
			expect(Line.length(trail)).to.equal(2)
		end)

		it("measures a station back along the path it was walked, not across it", function()
			local trail = elbow()
			-- 40 studs walked; 25 back from the head is 5 studs before the corner, on the straight.
			local point = Line.pointBack(trail, 25)
			expect(point).to.be.ok()
			expect(math.abs(point.X - 15) < 0.001).to.equal(true)
			expect(math.abs(point.Z) < 0.001).to.equal(true)
		end)

		it("has no station for a follower the leader has not yet walked past", function()
			local trail = {}
			Line.addCrumb(trail, Vector3.new(0, 0, 0), 1)
			Line.addCrumb(trail, Vector3.new(3, 0, 0), 1)
			expect(Line.pointBack(trail, 8.5)).to.equal(nil)
		end)

		it("tells an animal where it is ON the trail", function()
			local trail = elbow()
			-- Standing two studs off the straight, level with x = 12: its arc position is 12, and the
			-- order that follows is a point further ALONG the trail rather than a chord to a station.
			local at = Line.arcAt(trail, Vector3.new(12, 0, 2))
			expect(math.abs(at - 12) < 0.01).to.equal(true)
			-- ...and past the corner it keeps counting along the second leg, not back down the first.
			local after = Line.arcAt(trail, Vector3.new(20, 0, -6))
			expect(math.abs(after - 26) < 0.01).to.equal(true)
		end)

		it("refuses a branch the animal cannot have reached, when it is told where it was", function()
			-- THE DOUBLE-BACK, WHICH IS WHAT TASK 136 IS ABOUT. A leader rounding a trunk lays two
			-- passes a few studs apart; a follower on the FIRST is geometrically nearest the SECOND,
			-- and the unhinted search answers with the second one's arc length. Everything downstream
			-- then goes wrong at once: `slack` reads negative so the animal is told it has overrun
			-- and stops, and its aim is a point on the far branch so when it moves it cuts across the
			-- loop the leader just walked round.
			local trail = {}
			-- Out along z = 0, round the end, and back along z = 3: the two passes are 3 studs apart.
			for x = 0, 30, 1 do
				Line.addCrumb(trail, Vector3.new(x, 0, 0), 0.5)
			end
			for x = 30, 0, -1 do
				Line.addCrumb(trail, Vector3.new(x, 0, 3), 0.5)
			end
			-- An animal at (10, 1.6) is 1.6 studs from the OUTBOUND pass (arc 10) and 1.4 from the
			-- RETURN pass (arc ~53) -- so the RETURN branch is the nearer one, and nearest wins
			-- without a hint...
			local blind = Line.arcAt(trail, Vector3.new(10, 0, 1.6))
			-- ...so this is the number the drive used to get, and it is on the far branch.
			expect(blind > 40).to.equal(true)
			-- ...and with the hint it stays where the animal actually is.
			local hinted = Line.arcAt(trail, Vector3.new(10, 0, 1.6), 10, 14)
			expect(math.abs(hinted - 10) < 2).to.equal(true)
			-- A HINT THAT HAS FALLEN OFF THE BACK OF THE TRAIL FALLS BACK rather than answering with
			-- a stale number: the trail is trimmed from behind, so this case is reachable.
			local lost = Line.arcAt(trail, Vector3.new(10, 0, 1.6), 1000, 5)
			expect(lost > 0).to.equal(true)
		end)

		it("aims along the trail, never past the one in front and never under its own feet", function()
			-- `Line.aimFor`'s four rules, each driven on its own. 60 is the head of the trail, 0 the
			-- tail, the lookahead is 4, the no-overtake margin 1.5 and the minimum aim 2.5 -- the
			-- numbers `LINE` carries.
			local function aim(ownS: number, aheadS: number): number
				return Line.aimFor(ownS, 4, aheadS, 1.5, 2.5, 60, 0)
			end
			-- A follower with room ahead gets its lookahead.
			expect(aim(20, 40)).to.equal(24)
			-- ...one that has closed up is held short of the animal in front rather than aimed at it.
			expect(aim(20, 24)).to.equal(22.5)
			-- ...AND NEVER AT A POINT IT IS ALREADY STANDING ON. This is the rule whose absence turned
			-- 15 stuck into 58: at a 6.5-stud station the one in front is 6.5 along, so a body-length
			-- margin aimed the animal 1.0 stud ahead -- inside `LINE.ARRIVE_STUDS` -- and it stopped.
			expect(aim(20, 21)).to.equal(22.5)
			-- The head of the trail is the furthest anything can aim...
			expect(aim(58, 100)).to.equal(60)
			-- ...and the tail is the nearest.
			expect(Line.aimFor(5, 4, 6, 1.5, 2.5, 60, 9)).to.equal(9)
		end)

		it("takes a fled or crossed animal out of the file FOR GOOD (task 139)", function()
			-- KAREN, 2026-10-09: *"when boars crossing road they can't come back to same view, they
			-- just move on a specially after spook or shoot"*. Measured on `0c7f736`: five of nine
			-- shot animals ran north afterwards, back into the view she had just shot into.
			--
			-- A calm animal north of the road is in the file...
			expect(Line.stillInFile(false, false, false, 12)).to.equal(true)
			-- ...and each of the three ways out takes it out, on its own.
			expect(Line.stillInFile(false, true, false, 12)).to.equal(false) -- flying
			expect(Line.stillInFile(false, false, true, 12)).to.equal(false) -- hurt
			expect(Line.stillInFile(false, false, false, -1)).to.equal(false) -- over the road
			-- ...AND IT IS PERMANENT, which is the whole rule: an animal whose flight has ENDED, and
			-- which is back north of the road and unhurt, is still out. This is the assertion that
			-- fails if `gone` is dropped and the old rejoin-at-the-tail comes back.
			expect(Line.stillInFile(true, false, false, 12)).to.equal(false)
		end)

		it("shoves the animal that leaves because it CROSSED, and only that one (task 139)", function()
			-- KAREN, 2026-10-09: *"and they run away when cross the road"*. The rule used to be a
			-- line-level speed-up tested on the LEADER -- `at.Z < roadZ(at.X) - halfWidth`, the same
			-- inequality `stillInFile` ends on -- and once the exit became permanent the filter ran
			-- first in the same step, so she was out of `live` before the test and `line.crossed`
			-- could never become true. The Reviewer found it; this is the assertion that would have.
			--
			-- Over the road and nothing else wrong: it gets the shove.
			expect(Line.crossedOut(false, false, false, -1)).to.equal(true)
			-- ...and it is the ONLY way out that does. An animal already running is already running,
			-- a hurt one is the Brain's cripple, and one already `gone` was shoved on its own step --
			-- re-spooking it every step is what task 126 round 2 took out of this file.
			expect(Line.crossedOut(true, false, false, -1)).to.equal(false)
			expect(Line.crossedOut(false, true, false, -1)).to.equal(false)
			expect(Line.crossedOut(false, false, true, -1)).to.equal(false)
			-- ...AND AN ANIMAL STILL IN THE FILE IS NOT SHOVED AT ALL, which is the other half: a
			-- calm line walks to the road, it does not bolt at it (task 139 item 9).
			expect(Line.crossedOut(false, false, false, 12)).to.equal(false)
			expect(Line.stillInFile(false, false, false, 12)).to.equal(true)
			-- The two rules partition every live member: in the file, or out of it with exactly one
			-- of the four reasons -- so "it left because it crossed" is never also "it stays".
			for _, dz in ipairs({ -40, -0.01, 0, 5 }) do
				local stays = Line.stillInFile(false, false, false, dz)
				local shoved = Line.crossedOut(false, false, false, dz)
				expect(stays and shoved).to.equal(false)
				expect(stays or shoved).to.equal(true)
			end
		end)

		it("forgets the tail nobody stands on", function()
			local trail = elbow()
			Line.trim(trail, 10)
			expect(Line.length(trail) - trail[1].s <= 11).to.equal(true)
			expect(#trail >= 2).to.equal(true)
		end)
	end)

	describe("who walks where", function()
		it("puts the sow first, the piglets in the middle and the males last", function()
			local ordered = Line.order({
				{ id = "a", kind = "male" },
				{ id = "b", kind = "cub" },
				{ id = "c", kind = "female" },
				{ id = "d", kind = "female" },
			})
			expect(ordered[1].id).to.equal("c")
			expect(ordered[2].id).to.equal("d")
			expect(ordered[3].id).to.equal("b")
			expect(ordered[4].id).to.equal("a")
		end)

		it("deals two lines so each keeps a female at its head", function()
			local groups = Line.split(
				Line.order({
					{ id = "a", kind = "female" },
					{ id = "b", kind = "female" },
					{ id = "c", kind = "cub" },
					{ id = "d", kind = "cub" },
				}),
				2
			)
			expect(#groups).to.equal(2)
			expect(groups[1][1].kind).to.equal("female")
			expect(groups[2][1].kind).to.equal("female")
		end)
	end)

	describe("holding station", function()
		it("walks the leader's speed while it is in station", function()
			expect(Line.followerSpeed(10, 1, 1.5, 0.4)).to.equal(10)
			expect(Line.followerSpeed(10, -1, 1.5, 0.4)).to.equal(10)
		end)

		it("closes when it is BEHIND and eases off when it has OVERSHOT", function()
			-- The sign is the whole point: an unsigned error made both of these speed up.
			expect(Line.followerSpeed(10, 6, 1.5, 0.4)).to.equal(14)
			expect(Line.followerSpeed(10, -6, 1.5, 0.4)).to.equal(6)
		end)

		it("keeps the sow at her pace until her tail is really behind", function()
			expect(Line.leaderSpeed(18, 5, 12, 0.45)).to.equal(18)
			expect(Line.leaderSpeed(18, 24, 12, 0.45) < 18 * 0.46).to.equal(true)
			-- ...and she never stops dead, which would open a hole in the file.
			expect(Line.leaderSpeed(18, 400, 12, 0.45) > 0).to.equal(true)
		end)
	end)
	---------------------------------------------------------------- the drive line (task 157)

	describe("one plane for a curved road", function()
		-- THE FOREST HANDS THE WEAPON ONE `{ position, normal }` for a road that is a SINE: the plane
		-- is up to `ROAD.amplitudeStuds` (30) studs off the real road in z, and a hunter at stand 1 or
		-- 9 stands 600 studs from its position along x. This is the case that says why that costs
		-- nothing -- and it is an argument about WHICH FIELD IS READ, not an estimate.
		local SafetyArc = require(ServerScriptService:WaitForChild("Weapon")).SafetyArc
		local HALF = 45 -- Shotgun.CONFIG.SAFETY_ARC_HALF_DEG

		it("is invariant to where the plane SITS, because the arc reads the normal only", function()
			local north = Vector3.new(0, 0, 1)
			local away = Vector3.new(0, 0, -1)
			local base = { position = Data.ROAD_LAYOUT.centre, normal = Vector3.zAxis }
			local moved = {
				position = Data.ROAD_LAYOUT.centre + Vector3.new(600, 0, Data.ROAD_LAYOUT.amplitudeStuds),
				normal = Vector3.zAxis,
			}
			local far = {
				position = Data.ROAD_LAYOUT.centre - Vector3.new(600, 0, Data.ROAD_LAYOUT.amplitudeStuds),
				normal = Vector3.zAxis,
			}
			for _, line in ipairs({ base, moved, far }) do
				expect(SafetyArc.isForbidden(north, line, HALF)).to.equal(true)
				expect(SafetyArc.isForbidden(away, line, HALF)).to.equal(false)
			end
			-- A shot along the road is outside a 45-degree half-cone about +Z, wherever the plane is.
			for _, line in ipairs({ base, moved, far }) do
				expect(SafetyArc.isForbidden(Vector3.new(1, 0, 0), line, HALF)).to.equal(false)
			end
		end)

		it("has the beaters north of every point of this road", function()
			-- What WOULD matter is north ceasing to be the drive side. The road's tangent swings only
			-- atan(30/70) = 23 degrees, so every stand has the push line to its north -- which is why
			-- one plane with a +Z normal is the right answer here.
			for index = 1, Data.ROAD_LAYOUT.standCount do
				local x = Data.standX(index)
				local road = Data.roadZ(x)
				local start = Data.beaterStart(x, 0)
				expect(start.Z > road).to.equal(true)
			end
			-- ...and the spawn the waves come from is north of the road too, said ONCE rather than
			-- nine times inside the loop above.
			expect(Data.LINE.spawnNorthStuds > 0).to.equal(true)
			local swing = math.deg(math.atan(Data.ROAD_LAYOUT.amplitudeStuds / Data.SHAPE.wavelengthDivisor))
			expect(swing < HALF).to.equal(true)
			TestKit.note(string.format("forest-line: the road's tangent swings %.1f degrees", swing))
		end)
	end)
	-- ------------------------------------------- THE DRIVE'S RED DEER, ON THE PATH SHE PLAYS (239)
	--
	-- THE DEFECT THIS BLOCK REPRODUCES, measured by the Director in the Forest Test on 2026-10-22
	-- and again here before a line of it was changed: a drive's worth of waves carried cub, male
	-- and female only -- 80 animals over 240 seconds, 13 waves, NOT ONE stag, hind or calf. Karen
	-- saw none on 2026-10-21 either, and she had asked for *"we need all a time in drive deer"*.
	--
	-- THE CAUSE IS THE FIRST CASE BELOW, AND IT IS NOT THE ONE THE DISPATCH NAMED. `ForestTest`
	-- releases every wave of this world as a FILE (`releaseLine`, because `Data.LINE.enabled` is
	-- true): the animals are placed one at a time with `Runtime:spawn` and their kinds come from
	-- `Boar.sounderKinds(count, rolls, config, nil)`, which draws from `SOUNDER.MAKEUP` and has no
	-- deer in it at any roll. `Runtime:spawnSounder` -- where task 223's deer door lives -- is not
	-- reached on this path at all, so that door's `composition == nil` test never comes into it.
	describe("the drive's red deer (task 239)", function()
		local function configWith(on: boolean)
			local config = table.clone(Boar.CONFIG)
			config.KINDS = table.clone(Boar.CONFIG.KINDS)
			config.KINDS.ENABLED = on
			return config
		end

		local function deerIn(kinds: { string }): number
			local found = 0
			for _, kind in ipairs(kinds) do
				local row = Boar.CONFIG.KINDS[kind]
				if type(row) == "table" and row.species == "reddeer" then
					found += 1
				end
			end
			return found
		end

		it("REPRODUCES IT: the file path's own kind draw can never make a deer", function()
			-- The call `releaseLine` made before this task, with the world's real config (`KINDS`
			-- on, which is what `BOAR_MODEL` is in the Forest Test) and REAL rolls -- swept rather
			-- than sampled once, because the claim is "at no roll".
			local config = configWith(true)
			local rng = Random.new(2390)
			local drawn, deer = 0, 0
			for _ = 1, 400 do
				local count = rng:NextInteger(4, 9)
				local rolls = {}
				for index = 1, count do
					rolls[index] = rng:NextNumber()
				end
				local kinds = Boar.sounderKinds(count, rolls, config, nil)
				drawn += #kinds
				deer += deerIn(kinds)
			end
			expect(drawn > 1000).to.equal(true)
			expect(deer).to.equal(0)
			TestKit.note(string.format("forest-deer: %d animals drawn with no composition, %d deer", drawn, deer))
		end)

		it("counts a drive's waves from the metronome rather than from a number", function()
			expect(ForestTest.wavesPerDrive(300, 20)).to.equal(15)
			expect(ForestTest.wavesPerDrive(100, 20)).to.equal(5)
			-- The live pair, so a retune of either number is a retune of this answer.
			expect(ForestTest.wavesPerDrive()).to.equal(math.floor(Data.DRIVE.seconds / Data.SCHEDULE.intervalSeconds))
			-- A drive shorter than one interval still has a wave to put the deer in.
			expect(ForestTest.wavesPerDrive(5, 20)).to.equal(1)
		end)

		it("draws the deer's wave inside the first third of the drive, and varies it", function()
			-- THE WINDOW IS WHAT MAKES THIS A GUARANTEE INSTEAD OF A BETTER CHANCE: a 15-wave drive
			-- picks from 1..5, so the ordinal is always reached.
			local waves = ForestTest.wavesPerDrive(300, 20)
			local window = math.floor(waves / 3)
			local seen = {}
			for step = 0, 100 do
				local which = ForestTest.deerWaveOf(step / 100, waves)
				expect(which >= 1).to.equal(true)
				expect(which <= window).to.equal(true)
				seen[which] = true
			end
			local distinct = 0
			for _ in pairs(seen) do
				distinct += 1
			end
			expect(distinct).to.equal(window)
			-- The boundaries, exactly, at a window of five.
			expect(ForestTest.deerWaveOf(0, waves)).to.equal(1)
			expect(ForestTest.deerWaveOf(0.999999, waves)).to.equal(5)
			-- ...and a pick outside [0, 1) can still only answer inside the window.
			expect(ForestTest.deerWaveOf(1.5, waves)).to.equal(5)
			expect(ForestTest.deerWaveOf(-1, waves)).to.equal(1)
			-- A one-wave drive puts them in the only wave it has.
			expect(ForestTest.deerWaveOf(0.5, 1)).to.equal(1)
		end)

		it("asks on its wave, keeps asking until it lands, and asks once per drive", function()
			-- The latch.
			expect(ForestTest.deerWanted(1, 3, false)).to.equal(false)
			expect(ForestTest.deerWanted(3, 3, false)).to.equal(true)
			expect(ForestTest.deerWanted(3, 3, true)).to.equal(false)
			-- `>=` AND NOT `==`: a wave that could not carry the deer -- no route, no room, the cap
			-- -- must hand the drive's one group to the next wave rather than lose it.
			expect(ForestTest.deerWanted(4, 3, false)).to.equal(true)
			expect(ForestTest.deerWanted(12, 3, false)).to.equal(true)
			-- Before the drive's first wave has drawn an ordinal there is nothing to want.
			expect(ForestTest.deerWanted(9, nil, false)).to.equal(false)
		end)

		it("GUARANTEES a group inside every drive, at the roll that refuses one", function()
			-- The whole rule, walked over a drive, with `Boar.deerComposition`'s chance roll pinned
			-- at 1.0 -- the value that draws NOTHING. So what this case proves is the GUARANTEE and
			-- not the dial: every drive carries deer even when the dice never would.
			local config = configWith(true)
			local waves = ForestTest.wavesPerDrive(300, 20)
			local window = math.floor(waves / 3)
			local rng = Random.new(2391)
			for _ = 1, 50 do
				local ordinal = ForestTest.deerWaveOf(rng:NextNumber(), waves)
				local done, at, group = false, nil, nil
				for wave = 1, waves do
					if ForestTest.deerWanted(wave, ordinal, done) then
						local composition = Boar.deerComposition(1.0, rng:NextNumber(), config, true)
						expect(composition).to.be.ok()
						done, at, group = true, wave, composition
					end
				end
				expect(done).to.equal(true)
				expect(at).to.equal(ordinal)
				expect(at <= window).to.equal(true)
				-- ...and it is a real group of real deer, named by the animal's own owner.
				local size = Boar.compositionSize(group, config)
				expect(size >= 1).to.equal(true)
				expect(deerIn(Boar.sounderKinds(size, {}, config, group))).to.equal(size)
			end
		end)

		it("marches a deer file by the animal owner's rank, not by spawn order", function()
			-- THE HAREM IS THE CASE: `{ stag = 1, hind = 2 }` is dealt stag-first by `KINDS.ORDER`,
			-- and a stag at the head of his hinds is not what a harem looks like.
			local config = configWith(true)
			local dealt = Boar.sounderKinds(3, {}, config, { stag = 1, hind = 2 })
			local members = {}
			for index, kind in ipairs(dealt) do
				table.insert(members, { id = string.format("Deer%d", index), kind = kind })
			end
			-- `Line.order`'s own default knows the three BOAR words only, so all three deer tie at
			-- the unknown rank of 2 and the file keeps the order it was dealt in.
			expect(Line.order(members)[1].kind).to.equal(dealt[1])
			-- The one owner's table ranks them: hind 1, calf 2, stag 3.
			local marched = Line.order(members, Boar.MARCH_RANK)
			expect(marched[1].kind).to.equal("hind")
			expect(marched[2].kind).to.equal("hind")
			expect(marched[3].kind).to.equal("stag")
			-- A hind leads her calf for the same reason.
			local nursery = {
				{ id = "A", kind = "calf" },
				{ id = "B", kind = "hind" },
			}
			expect(Line.order(nursery, Boar.MARCH_RANK)[1].kind).to.equal("hind")
			-- ...AND THE BOARS ARE UNTOUCHED, which is what makes this a de-duplication rather than
			-- a retune: the three words the default knew answer the same in the owner's table.
			local sounder = {
				{ id = "A", kind = "male" },
				{ id = "B", kind = "cub" },
				{ id = "C", kind = "female" },
			}
			local byDefault = Line.order(sounder)
			local byOwner = Line.order(sounder, Boar.MARCH_RANK)
			for index = 1, #sounder do
				expect(byOwner[index].kind).to.equal(byDefault[index].kind)
			end
		end)
	end)
	-- ---------------------------------------------------------------- THE DRIVE SCRIPT (task 251)
	--
	-- KAREN, 2026-10-23: *"them patter with animals how many where they come how they come how many
	-- groups jumping over road red stags ect"*, and then *"ok"* to the Designer's plan
	-- (`<runs-dir>/design/driveflow-spec.md`). Every case below is one sentence of her question
	-- answered against the ROWS -- never against a second copy of the numbers, which is why the
	-- counts are added through `Boar.compositionSize` and the times through `Data.slotSeconds`.
	describe("the drive script (task 251)", function()
		local SCHEDULE = Data.SCHEDULE

		local function configOn()
			local config = table.clone(Boar.CONFIG)
			config.KINDS = table.clone(Boar.CONFIG.KINDS)
			config.KINDS.ENABLED = true
			return config
		end

		-- HOW MANY ANIMALS A DENSITY RELEASES, counted through the ANIMAL owner's own weigher. This
		-- spec never writes a composition's size down.
		local function animalsAt(density: string): number
			local config = configOn()
			local total = 0
			for _, row in ipairs(Data.driveTally(density, SCHEDULE).rows) do
				if row.species == "reddeer" then
					local party = Boar.deerComposition(0, 0, config, row.party)
					expect(party).to.be.ok()
					total += Boar.compositionSize(party, config)
				else
					local composition = config.SOUNDER.COMPOSITIONS[row.composition]
					expect(composition).to.be.ok()
					total += Boar.compositionSize(composition, config)
				end
			end
			return total
		end

		it("is fifteen slots of one drive, and every row names a slot the clock actually has", function()
			-- FIFTEEN IS THE SCRIPT'S OWN SHAPE SINCE PART 2, AND NO LONGER A QUOTIENT. It used to be
			-- asserted against `wavesPerDrive(DRIVE.seconds, intervalSeconds)` -- 300 / 20 -- and that
			-- was arithmetic about a clock this world does not run on: a drive here ENDS WHEN THE
			-- BEATER LINE ARRIVES and `DRIVE.seconds` is only the ceiling, which is the whole of part
			-- 1's escalation (`ESCALATE.md`, 2026-10-23). The three acts are five slots each, which is
			-- what fifteen means, and WHETHER THEY ALL FIT inside the drive the beaters actually make
			-- is asserted where the beaters' numbers live (`bots_lane.spec`, "the length of the walk").
			expect(#SCHEDULE.drive).to.equal(15)
			expect(SCHEDULE.firstSlotSeconds).to.equal(10)
			expect(SCHEDULE.intervalSeconds).to.equal(13)
			-- THE DIRECTOR'S THREE NUMBERS, 2026-10-24: *"slot 1 at 10 s, about 13 s apart, the last
			-- at ~192 s"*.
			expect(Data.slotSeconds(1, SCHEDULE)).to.equal(10)
			expect(Data.slotSeconds(15, SCHEDULE)).to.equal(192)
			for index, row in ipairs(SCHEDULE.drive) do
				expect(row.slot).to.equal(index)
				-- `atSeconds` IS AN ASSERTION, NOT A SECOND CLOCK: it has to be the two rows' own
				-- arithmetic, or a changed `intervalSeconds` would leave fifteen stale timestamps.
				expect(row.atSeconds).to.equal(Data.slotSeconds(index, SCHEDULE))
				expect(row.act >= 1 and row.act <= 3).to.equal(true)
				expect(type(row.note)).to.equal("string")
			end
			-- The three acts are five slots each, in order, which is what makes the drive read as a
			-- beginning, a body and an end rather than as fifteen waves.
			for index, row in ipairs(SCHEDULE.drive) do
				expect(row.act).to.equal(math.floor((index - 1) / 5) + 1)
			end
		end)

		it("never repeats the stag, however long the drive runs (task 251c)", function()
			-- HE IS SLOT 8 NOW, WHICH IS INSIDE THE REPEAT WINDOW -- so the exclusion the window's
			-- own comment claimed had to stop being positional. A long drive asks `slotAt` for slots
			-- past the script's end; none of them may be him. Slot 18 is the one that was: with
			-- `repeatFrom` 6 and `repeatTo` 12, slot 18 maps to row 8.
			local stag, slot = Data.stagRow("normal", SCHEDULE)
			expect(stag).to.be.ok()
			expect(slot).to.equal(8)
			expect(SCHEDULE.repeatFrom <= slot and slot <= SCHEDULE.repeatTo).to.equal(true)
			for index = #SCHEDULE.drive + 1, #SCHEDULE.drive + 30 do
				local row = Data.slotAt(index, "normal", SCHEDULE)
				expect(row ~= stag).to.equal(true)
				if row ~= nil then
					expect(row.party == "stag").to.equal(false)
				end
			end
			-- ...AND THE WINDOW STILL ANSWERS SOMETHING, which is what it exists for: a drive that
			-- outlives its script can never run out of animals.
			expect(Data.slotAt(#SCHEDULE.drive + 1, "normal", SCHEDULE)).to.be.ok()
			expect(Data.slotAt(#SCHEDULE.drive + 3, "normal", SCHEDULE)).to.be.ok()
		end)

		it("answers Karen's counts at the dial she OK'd: 13 groups, 10 crossings, 2 back, 1 that holds", function()
			local normal = Data.driveTally("normal", SCHEDULE)
			expect(normal.groups).to.equal(13)
			expect(normal.silent).to.equal(2)
			expect(normal.crossings).to.equal(10)
			expect(normal.refusals).to.equal(2)
			expect(normal.holds).to.equal(1)
			expect(normal.deerGroups).to.equal(2)
			expect(normal.boarGroups).to.equal(11)
			-- THREE LEAPING ANIMALS AND NO BOAR AMONG THEM. *"how many groups jumping over road"*:
			-- the hind, her calf and the stag -- and `leaps` is only ever on a `reddeer` row.
			-- `leapingGroups` COUNTS GROUPS, and the field is named for it (round 1's note): the hind
			-- party is ONE row of two animals, and the stag is the other -- so two ROWS and three
			-- ANIMALS leap, and the animals are counted through the owner's weigher just below.
			expect(normal.leapingGroups).to.equal(2)
			local config3 = configOn()
			local leaping = 0
			for _, row in ipairs(normal.rows) do
				if row.leaps == true then
					leaping += Boar.compositionSize(Boar.deerComposition(0, 0, config3, row.party), config3)
				end
			end
			expect(leaping).to.equal(3)
			for _, row in ipairs(SCHEDULE.drive) do
				if row.leaps == true then
					expect(row.species).to.equal("reddeer")
				end
			end
			-- ...and the animals, weighed by the animal's owner rather than written down here.
			expect(animalsAt("normal")).to.equal(59)
			TestKit.note(
				string.format(
					"task 251: one normal drive is %d groups / %d animals -- %d cross, %d break back, %d holds",
					normal.groups,
					animalsAt("normal"),
					normal.crossings,
					normal.refusals,
					normal.holds
				)
			)
		end)

		it("moves all five of the dial's columns with ONE number", function()
			-- The table in `SCHEDULE`'s own comment, asserted column by column. It is one rule --
			-- `row.keepAt <= groups` -- and the whole point is that nothing else has to be kept in
			-- step with it.
			expect(Data.groupsWanted("quiet", SCHEDULE)).to.equal(9)
			expect(Data.groupsWanted("normal", SCHEDULE)).to.equal(13)
			expect(Data.groupsWanted("busy", SCHEDULE)).to.equal(15)

			local quiet = Data.driveTally("quiet", SCHEDULE)
			expect(quiet.groups).to.equal(9)
			expect(quiet.refusals).to.equal(0)
			expect(quiet.holds).to.equal(0)
			expect(quiet.deerGroups).to.equal(1) -- the hinds only; no stag in a quiet drive
			expect(animalsAt("quiet")).to.equal(37)

			local busy = Data.driveTally("busy", SCHEDULE)
			expect(busy.groups).to.equal(15)
			expect(busy.silent).to.equal(0)
			expect(busy.refusals).to.equal(2)
			expect(busy.holds).to.equal(1)
			expect(busy.deerGroups).to.equal(2)
			expect(animalsAt("busy")).to.equal(69)

			-- AN UNKNOWN WORD IS `normal`, not silence: a typo in the dial must not empty the wood.
			expect(Data.groupsWanted("sideways", SCHEDULE)).to.equal(13)
			expect(Data.groupsWanted(nil, SCHEDULE)).to.equal(13)
			expect(SCHEDULE.density).to.equal("normal")
		end)

		it("comes from a different depth every slot, and ALL of it in front of the beaters", function()
			-- THE OLD SIX-ROW CYCLE'S DEFECT, as a measurement: it released every wave from
			-- `LINE.spawnNorthStuds` (180) whatever its row said, so the drive had one depth. The
			-- script's own rows span the three zones.
			local standX = Data.standX(5)
			local startNorth = Data.beaterStart(standX, 0).Z - Data.roadZ(Data.beaterStart(standX, 0).X)
			local shallowest, deepest = math.huge, -math.huge
			for _, row in ipairs(SCHEDULE.drive) do
				local at = Data.wavePoint(standX, row)
				local dz = at.Z - Data.roadZ(at.X)
				-- NOTHING IS SPAWNED BEHIND THE BEATERS' LINE (task 168's rule, which the script
				-- must not break: an animal put behind the line would be walled on the wrong side).
				expect(dz < startNorth).to.equal(true)
				shallowest = math.min(shallowest, dz)
				deepest = math.max(deepest, dz)
			end
			-- TO THE STUD, NOT TO THE BIT (the gate caught it at 85.0000603346607): `wavePoint` adds
			-- `roadZ(x)`, which is a sine, and the dz is measured back off a second call at the same
			-- x -- so the two differ in the last bits of a double.
			expect(math.abs(shallowest - 85) < 1e-3).to.equal(true) -- zone A, the near holding
			expect(math.abs(deepest - 360) < 1e-3).to.equal(true) -- zone C, the one that holds
			expect(deepest - shallowest >= 250).to.equal(true)
			TestKit.note(
				string.format(
					"task 251: the script spans dz %.0f to %.0f; a beater starts at %.0f",
					shallowest,
					deepest,
					startNorth
				)
			)
		end)

		it("names only crossings, compositions and parties that exist", function()
			local config = configOn()
			local offsets = {}
			for _, offset in ipairs(Data.LINE.crossOffsets) do
				offsets[offset] = true
			end
			local used = {}
			for _, row in ipairs(SCHEDULE.drive) do
				local route = Data.slotRoute(row)
				if route == "BREAK-BACK" or route == "HOLD" then
					-- A group that never reaches the road has no crossing, and must not pretend to.
					expect(row.crossOffset).to.equal(nil)
				else
					-- EVERY CROSSING IS ONE OF THE FIVE THE GAME ALREADY HAS, and they are SHARED on
					-- purpose: a *Wechsel* is a path, not a one-off.
					expect(offsets[row.crossOffset]).to.equal(true)
					used[row.crossOffset] = true
				end
				if row.species == "reddeer" then
					-- The party is named, and the ANIMAL's owner is what knows the word.
					expect(Boar.deerComposition(0, 0, config, row.party)).to.be.ok()
					expect(row.composition).to.equal(nil)
				else
					expect(config.SOUNDER.COMPOSITIONS[row.composition]).to.be.ok()
					expect(row.party).to.equal(nil)
				end
			end
			-- ...and all five are used, so no stand's approach is dead ground.
			local count = 0
			for _ in pairs(used) do
				count += 1
			end
			expect(count).to.equal(#Data.LINE.crossOffsets)
		end)

		it("puts the hinds early and the stag LAST AT THE ROAD, alone, and deeper than anything that comes", function()
			-- THE ONE THING KAREN NAMED TWICE. *"red stags"* -- and the Rum finding is that a mature
			-- stag keeps his own company outside the rut, while the Jaeger finding is that red deer
			-- come long after the drive starts.
			local hinds, stag = nil, nil
			for _, row in ipairs(SCHEDULE.drive) do
				if row.party == "hinds" then
					hinds = row
				elseif row.party == "stag" then
					stag = row
				end
			end
			expect(hinds).to.be.ok()
			expect(stag).to.be.ok()
			-- THE HINDS ARE INSIDE THE FIRST THIRD, which is the guarantee task 239 used to DRAW an
			-- ordinal for (`deerWaveOf`) and the script now meets by data, every drive, with nothing
			-- drawn at all.
			expect(hinds.slot <= math.floor(#SCHEDULE.drive / 3)).to.equal(true)
			-- HE IS THE LAST DEER, and 60 s and 100 studs clear of her (the spec's own two numbers).
			expect(stag.slot > hinds.slot).to.equal(true)
			expect(stag.atSeconds - hinds.atSeconds >= 60).to.equal(true)
			expect(stag.northStuds - hinds.northStuds >= 100).to.equal(true)
			-- ALONE: his party weighs one animal, and he is the only one of it.
			local party = Boar.deerComposition(0, 0, configOn(), "stag")
			expect(Boar.compositionSize(party, configOn())).to.equal(1)
			expect(party.stag).to.equal(1)
			-- AND NOTHING THAT COMES IS DEEPER. Slot 15 starts further out (360) and never comes;
			-- of everything that crosses or turns back, he is the deepest.
			for _, row in ipairs(Data.driveTally("normal", SCHEDULE).rows) do
				if Data.slotRoute(row) ~= "HOLD" then
					expect(row.northStuds <= stag.northStuds).to.equal(true)
				end
			end
			-- ...AND HE IS RELEASED IN ACT II SINCE TASK 251c, at a walk. His `act` is 2 because a
			-- row's act is WHERE IT SITS IN THE DRIVE (five slots each, asserted as a quotient
			-- above) -- what reaches act III is the stag HIMSELF, at the verge, and that is the
			-- claim the case below makes with the arithmetic. He was slot 13 / act 3 and part 2
			-- measured what that cost: 44 seconds for a 95-second walk, so the sneak, the edge check
			-- and the look back could not happen at all (`ESCALATE.md`, 2026-10-24).
			expect(stag.act).to.equal(2)
			expect(stag.pace).to.equal("walk")
			-- HE IS STILL THE LAST DEER, which is what *"the stag last"* has always been about: the
			-- hinds come at slot 2 and nothing with antlers or a calf comes after him. (He is not the
			-- last WALKER -- slot 9's big lone male walks at 114 s -- and the gate caught the case
			-- that claimed he was.)
			for _, row in ipairs(SCHEDULE.drive) do
				if row.slot > stag.slot then
					expect(row.species).to.equal("boar")
				end
			end
		end)

		-- ---------------------------------------------- AHEAD OF THE BEATER LINE (task 251c)
		--
		-- **THE DIRECTOR ANSWERED part 2's escalation on 2026-10-24** (`ESCALATE.md`, *"ACT III ... IS
		-- RELEASED BEHIND THE ADVANCING BEATER LINE"*) with two rules, and these two cases are them.
		-- Both FAIL on the commit before this task: the first calls a function that did not exist, and
		-- the second's own arithmetic is what the escalation measured as broken -- slot 13's stag was
		-- put down at dz 330 at 166 s with the line already 100 studs past that depth.
		local function lineNorthAt(seconds: number, factor: number?): number
			-- WHERE THE LINE IS AT A TIME, from the two shipped numbers and nothing written twice:
			-- the beaters start at `beaterNorthStuds` and walk at `Bots.CONFIG.WALK_SPEED`.
			-- `factor` is `bots_lane.spec`'s measured ground factor (the arrival is 1.081x the flat
			-- quotient over a hill), so the same case can be stated flat and as Karen's place.
			return Data.beaterNorthStuds() - (Bots.CONFIG.WALK_SPEED / (factor or 1)) * seconds
		end

		it("clamps a slot's depth to stay ahead of the line, and never deeper than the row (task 251c)", function()
			-- PURE, hand-written, with this spec's own two numbers rather than the shipped ones, so
			-- the RULE is stated here and the DIAL is checked against the rows below it.
			local sched = { leadStuds = 60, minNorthStuds = 25 }
			-- NOBODY PUSHING: the table's own depth, untouched. That is the DEV place, and it is also
			-- the seconds before a drive's bots exist.
			expect(Data.releaseDepth(330, nil, nil, sched)).to.equal(330)
			-- THE LINE IS STILL DEEPER THAN THE ROW: the row keeps its depth. This is the `min`, and
			-- it is what keeps the script's relative ordering -- act III stays deeper than act I.
			expect(Data.releaseDepth(330, 500, nil, sched)).to.equal(330)
			expect(Data.releaseDepth(330, 390, nil, sched)).to.equal(330) -- exactly `leadStuds` clear
			-- THE LINE HAS WALKED PAST THE ROW: it comes in to `leadStuds` ahead of the line.
			expect(Data.releaseDepth(330, 389, nil, sched)).to.equal(329)
			expect(Data.releaseDepth(330, 267, nil, sched)).to.equal(207) -- the stag's own slot
			-- AND IT IS NEVER BEHIND THE LINE wherever there is room in front of it.
			for line = 100, 600, 7 do
				local north = Data.releaseDepth(330, line, nil, sched)
				expect(north <= 330).to.equal(true)
				if line - sched.leadStuds >= sched.minNorthStuds then
					expect(north <= line - sched.leadStuds).to.equal(true)
				end
			end
			-- THE FLOOR IS THE ONE CASE THAT IS NOT AHEAD OF THE LINE, and it is deliberate: once the
			-- line is within `leadStuds` of the road there is nowhere in front of it, and a group
			-- spawned south of the verge would be behind the hunter.
			expect(Data.releaseDepth(290, 32, nil, sched)).to.equal(25)
			expect(Data.releaseDepth(290, 10, nil, sched)).to.equal(25)
			-- A SNEAKING ROW FLOORS AT ITS OWN `sneakDz`: the sneak's pins sit that far north of the
			-- road, so a shallower start would walk the stag north into the band and then back south.
			expect(Data.releaseDepth(330, 100, 75, sched)).to.equal(75)
			expect(Data.releaseDepth(330, 200, 75, sched)).to.equal(140)
			-- ...AND THE FLOOR IS THE ROW'S OWN ROUTE'S (`Data.routeFloor`), which is the half that
			-- stops the clamp breaking the three route words that turn. Hand-written rows, so the
			-- RULE is here and the shipped rows are checked against it below.
			expect(Data.routeFloor({ sneak = true, sneakDz = 75 }, sched)).to.equal(75)
			expect(Data.routeFloor({ route = "BREAK-BACK", turnAtDz = 40 }, sched)).to.equal(65)
			expect(Data.routeFloor({ route = "STRAIGHT" }, sched)).to.equal(25)
			expect(Data.routeFloor({ route = "LATERAL" }, sched)).to.equal(25)
			expect(Data.routeFloor(nil, sched)).to.equal(25)
			-- A REFUSAL THAT NAMES NO TURN TAKES THE SCHEDULE'S OWN FALLBACK, the same one
			-- `releaseLine` walks it to.
			expect(Data.routeFloor({ route = "BREAK-BACK" }, { minNorthStuds = 25, turnBackStuds = 70 })).to.equal(95)
			-- EVERY SHIPPED ROW'S FLOOR IS BELOW ITS OWN DEPTH, or the clamp could put a row deeper
			-- than the script wrote it.
			for _, row in ipairs(SCHEDULE.drive) do
				expect(Data.routeFloor(row, SCHEDULE) < (row.northStuds or 100)).to.equal(true)
			end
			-- ...AND THE ONE THAT HOLDS IS NOT CLAMPED AT ALL (round 1's blocking finding, which was
			-- right). The clamp exists because a group released behind the line MEETS IT HEAD-ON
			-- when it starts for the road; the one that stays never starts, so being passed by the
			-- men is what it is for. Clamped, its floor was `holdStuds + minNorthStuds` = 85 and its
			-- hold leg -- `start dz - holdStuds` -- then put six animals down to lie up 25 studs
			-- from the road, against a row whose note reads "It never comes".
			expect(Data.clampedToLine({ route = "HOLD", holdStuds = 60 })).to.equal(false)
			expect(Data.clampedToLine({ route = "STRAIGHT" })).to.equal(true)
			expect(Data.clampedToLine({ route = "BREAK-BACK", turnAtDz = 40 })).to.equal(true)
			expect(Data.clampedToLine({ route = "LATERAL" })).to.equal(true)
			expect(Data.clampedToLine({ route = "SPLIT" })).to.equal(true)
			-- A ROW WITH NO ROUTE WORD IS A STRAIGHT ONE (`slotRoute`'s own default), so it is
			-- clamped: the exemption is the HOLD and nothing else.
			expect(Data.clampedToLine({})).to.equal(true)
			-- EXACTLY ONE SHIPPED ROW IS EXEMPT, and it is slot 15.
			local exempt = {}
			for _, row in ipairs(SCHEDULE.drive) do
				if not Data.clampedToLine(row) then
					table.insert(exempt, row.slot)
				end
			end
			expect(#exempt).to.equal(1)
			expect(exempt[1]).to.equal(15)
			-- A ROW WITH NO DEPTH TAKES `wavePoint`'S OWN DEFAULT, so the two cannot disagree.
			expect(Data.releaseDepth(nil, nil, nil, sched)).to.equal(100)
			-- A LINE AT OR PAST THE ROAD IS NOT A LINE: the table's own depth, unclamped. MEASURED in
			-- the first live run of this task -- the repeat window released two sounders at the
			-- 25-stud floor with the line at dz 26 and dz -9, which is a sounder appearing on the
			-- verge in front of the hunter.
			expect(Data.releaseDepth(170, 0, nil, sched)).to.equal(170)
			expect(Data.releaseDepth(170, -9, nil, sched)).to.equal(170)
			expect(Data.releaseDepth(170, 1, nil, sched)).to.equal(25)
			-- ...AND THE SHIPPED NUMBERS. The floor is below every depth the script writes, which is
			-- what makes "the clamp never puts a row deeper than its own row says" true of the floor
			-- as well as of the `min`.
			-- 130 AND NOT 60 SINCE TASK 253, and it was measured: 60 is inside the line's own notice
			-- band (100 studs) and its flush circle (71), so every clamped group was spawned already
			-- noticed and broke two seconds later. `forest_stand.spec` asserts that relation --
			-- `noticeAheadStuds < leadStuds` -- rather than either number.
			expect(SCHEDULE.leadStuds).to.equal(130)
			expect(SCHEDULE.minNorthStuds).to.equal(25)
			for _, row in ipairs(SCHEDULE.drive) do
				expect(SCHEDULE.minNorthStuds < (row.northStuds or 100)).to.equal(true)
			end
		end)

		it("releases every slot ahead of the line at its own time, and the stag early enough to WALK", function()
			-- THE SECOND HALF, AND IT IS THE WHOLE OF THE ESCALATION. Every slot, at its own
			-- `atSeconds`, against where the line actually is then -- which is the comparison nothing
			-- made before this task, so act III was released 30 to 106 s after the beaters had walked
			-- through its own start.
			-- BOTH MODELS, AND THAT IS ROUND 1'S FINDING TOO: the flat quotient puts the line at the
			-- road by 187 s and the measured ground factor by 202, so a case stated only on the flat
			-- one asserts a branch Karen's place does not take. Every claim below is made twice.
			local function run(factor: number?)
				local exempt, tight = {}, {}
				for _, row in ipairs(SCHEDULE.drive) do
					local line = lineNorthAt(row.atSeconds, factor)
					local floor = Data.routeFloor(row, SCHEDULE)
					local clamped = Data.clampedToLine(row)
					local north = Data.releaseDepth(row.northStuds, if clamped then line else nil, floor, SCHEDULE)
					-- NEVER DEEPER THAN ITS OWN ROW: the clamp only ever pulls one toward the road.
					expect(north <= (row.northStuds or 100)).to.equal(true)
					if not clamped or line <= 0 then
						-- THE ONE THAT HOLDS IS NOT THE LINE'S BUSINESS, and a line past the road is
						-- not a line: either way the row's own depth stands.
						expect(north).to.equal(row.northStuds)
						table.insert(exempt, row.slot)
					else
						-- AHEAD OF THE LINE. This is the claim the escalation existed to get, and
						-- every row of the script meets it on both models: the row's own route floor
						-- is shallower than the line at its own release time, every time.
						expect(floor < line).to.equal(true)
						expect(north < line).to.equal(true)
						if line - SCHEDULE.leadStuds >= floor then
							-- ...AND BY THE FULL LEAD MARGIN, wherever the row's floor allows it.
							expect(north <= line - SCHEDULE.leadStuds).to.equal(true)
						else
							table.insert(tight, row.slot)
						end
						if row.slot <= 10 then
							-- EVERY SLOT UP TO 10 GETS THE FULL MARGIN on both models -- all of act
							-- I and all of act II, the stag included.
							expect(north <= line - SCHEDULE.leadStuds).to.equal(true)
						end
					end
				end
				return exempt, tight
			end
			-- WHAT THE END OF THE DRIVE COSTS, SAID OUT LOUD (rule 8, and the Director's *"if another
			-- act-III group cannot reach the road in time either, say so and apply the same rule"*).
			-- Act III's late rows are ahead of the line but inside the 130-stud margin, and they take
			-- their own route floors. Slot 15 is exempt on both models -- it holds and never comes --
			-- and on the FLAT quotient the men are through by its 192 s as well.
			local flatExempt, flatTight = run()
			expect(#flatExempt).to.equal(1)
			expect(flatExempt[1]).to.equal(15)
			expect(#flatTight).to.equal(4)
			expect(flatTight[1]).to.equal(11)
			expect(flatTight[2]).to.equal(12)
			expect(flatTight[3]).to.equal(13)
			expect(flatTight[4]).to.equal(14)
			-- IN KAREN'S PLACE the line is 8 % slower, so act III's first row keeps the whole margin
			-- and only the last three are tight. The live drive is this column:
			-- `SLOT 11 ... released=77, line=207` is a full 130 clear.
			local groundExempt, groundTight = run(1.081)
			expect(#groundExempt).to.equal(1)
			expect(groundExempt[1]).to.equal(15)
			expect(#groundTight).to.equal(3)
			expect(groundTight[1]).to.equal(12)
			expect(groundTight[2]).to.equal(13)
			expect(groundTight[3]).to.equal(14)
			TestKit.note(
				string.format(
					"task 251c: slots 1-11 are released a full %d studs ahead of the line; 12-14 are ahead but inside that margin; slot 15 is due after the men are through",
					SCHEDULE.leadStuds
				)
			)

			-- THE STAG'S OWN ARITHMETIC, which is why his slot moved. His route is three legs and it
			-- adds up to `north + sneakStuds`: the approach `north - sneakDz`, the sneak `sneakStuds`
			-- along the band, and `sneakDz` out to the road.
			local stag = Data.stagRow("normal", SCHEDULE)
			expect(stag).to.be.ok()
			local walk = Boar.CONFIG.PACE.WALK_SPEED
			local function reachesVergeAt(factor: number?): number
				local line = lineNorthAt(stag.atSeconds, factor)
				local north = Data.releaseDepth(stag.northStuds, line, Data.routeFloor(stag, SCHEDULE), SCHEDULE)
				return stag.atSeconds + (north + stag.sneakStuds) / walk
			end
			-- WHEN THE LINE IS AT THE ROAD, which is what ends a drive in this world.
			local arrivesFlat = Data.beaterNorthStuds() / Bots.CONFIG.WALK_SPEED
			local arrivesGround = arrivesFlat * 1.081
			-- HE IS AT THE VERGE BEFORE IT ON BOTH MODELS -- at the lead of 130 that is 158 s against
			-- a line at the road at 187 s flat (29 s), and 163 s against 202 s in Karen's place
			-- (39 s). The Director asked for *"a margin of about 20 s"*; the bigger lead bought more
			-- of it, because a shallower release is a shorter walk.
			expect(reachesVergeAt() < arrivesFlat - 20).to.equal(true)
			expect(reachesVergeAt(1.081) < arrivesGround - 20).to.equal(true)
			-- ...AND IN ACT III'S OWN WINDOW, which is the Director's words exactly: *"reaches the
			-- verge in act III"*. Act III is slots 11-15, 140 s to 192 s.
			expect(reachesVergeAt() > Data.slotSeconds(11, SCHEDULE)).to.equal(true)
			expect(reachesVergeAt(1.081) < Data.slotSeconds(15, SCHEDULE)).to.equal(true)
			TestKit.note(
				string.format(
					"task 251c: the stag is released at %d s from dz %.0f (the line is at dz %.0f) and is at the verge at %.0f s; the line reaches the road at %.0f s flat / %.0f s on the ground",
					stag.atSeconds,
					Data.releaseDepth(
						stag.northStuds,
						lineNorthAt(stag.atSeconds),
						Data.routeFloor(stag, SCHEDULE),
						SCHEDULE
					),
					lineNorthAt(stag.atSeconds),
					reachesVergeAt(),
					arrivesFlat,
					arrivesGround
				)
			)
		end)

		it("gives the sneak its two numbers and its DIRECTION, which is the side he came from", function()
			-- PART 1'S OWN BOUNDARY CASE, NOW FLIPPED -- which is what it said would happen: *"the day
			-- part 2 reads it, THIS case is the thing that has to change"*. Spec section 3.2, Karen
			-- OK'd: *"ein Stueck innerhalb des Waldrands ... ehe es das offene Feld annimmt"*.
			local stag = nil
			for _, row in ipairs(SCHEDULE.drive) do
				if row.party == "stag" then
					stag = row
				end
			end
			expect(stag.sneak).to.equal(true)
			expect(stag.check).to.equal(true)
			-- THE TWO NUMBERS ARE INSIDE THE SPEC'S OWN BANDS (80-160 studs parallel, dz 60-90), and
			-- they are single numbers and not ranges because A SCRIPT DRAWS NOTHING.
			expect(stag.sneakStuds >= 80 and stag.sneakStuds <= 160).to.equal(true)
			expect(stag.sneakDz >= 60 and stag.sneakDz <= 90).to.equal(true)
			-- HE ENTERS THE BAND ON THE SIDE HE CAME FROM and walks to his crossing. Slot 13 starts 95
			-- studs west of the stand and crosses 35 west, so the entry is further WEST again and the
			-- walk is eastward -- and the distance walked IS `sneakStuds`, which is the claim.
			local entry = Data.sneakEntryX(stag.offsetX, stag.crossOffset, stag.sneakStuds)
			expect(entry < stag.crossOffset).to.equal(true)
			expect(math.abs(math.abs(stag.crossOffset - entry) - stag.sneakStuds) < 1e-6).to.equal(true)
			-- ...AND THE OTHER SIDE, so the rule is a rule and not this row's luck.
			expect(Data.sneakEntryX(100, 20, 120)).to.equal(140)
			expect(Data.sneakEntryX(-100, 20, 120)).to.equal(-100)
			-- A TIE TAKES THE WEST, and a missing or zero distance collapses the two legs into the
			-- STRAIGHT route part 1 shipped -- so a row that declares `sneak` and no distance is the
			-- behaviour before this task and never an error.
			expect(Data.sneakEntryX(20, 20, 120)).to.equal(-100)
			expect(Data.sneakEntryX(-95, -35, nil)).to.equal(-35)
			expect(Data.sneakEntryX(-95, -35, 0)).to.equal(-35)
			-- AND NOTHING ELSE IN THE SCRIPT SNEAKS, which is what makes the "a row cannot be both a
			-- sneak and a LATERAL" guard in `releaseLine` a guard and not a live branch.
			for _, row in ipairs(SCHEDULE.drive) do
				if row.sneak == true then
					expect(row.party).to.equal("stag")
					expect(Data.slotRoute(row)).to.equal("STRAIGHT")
				end
			end
			-- ...and the edge stop still honours `check`: every file's leader is offered it inside
			-- this band, now at the stag's OWN chance (`deer.spec` holds that half).
			expect(Data.LINE.checkWithinStuds > 0).to.equal(true)
			expect(Boar.kindConfig("stag", Boar.CONFIG).MOVE.EDGE_CHANCE).to.equal(0.9)
		end)

		it("knows which row carries the stag, and answers nil for a drive that has none", function()
			-- `Data.stagRow` is read by the rut roar (which must sound from his holding BEFORE he is
			-- released) and by the proof that logs a drive. IT ASKS THE DIAL, which is the whole
			-- point: at `quiet` his row is `keepAt = 13` and does not fire, so a quiet drive has no
			-- stag and a roar from an empty wood would be a lie.
			local row, slot = Data.stagRow("normal", SCHEDULE)
			expect(row).to.be.ok()
			expect(slot).to.equal(8) -- 13 until task 251c moved his release so that he could walk
			expect(row.party).to.equal("stag")
			expect(row.species).to.equal("reddeer")
			expect(Data.stagRow("busy", SCHEDULE)).to.be.ok()
			expect(Data.stagRow("quiet", SCHEDULE)).to.equal(nil)
			-- An unknown word is `normal` (`groupsWanted`'s own rule), so a typo does not silence him.
			expect(Data.stagRow("sideways", SCHEDULE)).to.be.ok()
		end)

		it("gives the rut roar its own emitter, far, quiet and never a voice slot", function()
			-- SPEC SECTION 4.2, the one new cue: *"3-6 s, pitch 1.15, no cut -- a distant roar must be
			-- long, heard at 350 studs, heavy rolloff, quiet"*. `ForestTest.ROAR`'s own comment is why
			-- it is this module's data and not `Boar.CONFIG.SOUND.VOICE`'s: it sounds before the stag
			-- exists, so it cannot be an animal's voice and must not book a voice slot.
			local roar = Data.ROAR
			expect(roar.enabled).to.equal(true)
			-- FIVE SINCE TASK 254, AND THE FIRST IS THE REAL ANIMAL. It was four library bull bellows
			-- -- *"four, so the ambience is not one sample on a loop"* -- and the real recording is
			-- now `ids[1]` with the four kept behind it as the revert path. The variety moved from
			-- the ids to that id's three regions; the count below is what makes it impossible to
			-- delete the real one and still pass.
			expect(#roar.ids).to.equal(5)
			expect(roar.ids[1]).to.equal(122287696922128)
			expect(roar.pitch).to.equal(Boar.CONFIG.SOUND.VOICE.stag.pitch) -- one animal, one pitch
			-- FARTHER THAN ANY VOICE IN THIS WORLD CARRIES, and quieter than one.
			expect(roar.audibleStuds > Boar.CONFIG.SOUND.CRY.audibleStuds).to.equal(true)
			-- ...AND FAR ENOUGH TO REACH THE STAND FROM THE ROW IT SOUNDS FROM, which is the thing the
			-- spec's own 350 got wrong and the first live drive printed: *"the stag answers from the
			-- far wood, 401 studs from the stand, audible to 350"*. His holding is slot 13's own, so
			-- the distance is arithmetic about two rows of one table and belongs in a case, not in a
			-- comment -- otherwise a deeper stag silently goes out of earshot again.
			--
			-- IT IS THE FLAT DISTANCE, said plainly (review round 1, note): the emitter stands on
			-- terrain this place measures about 50 studs higher at dz 360 than at the road, and a
			-- `Sound`'s roll-off is measured in three dimensions -- so the real distance is a little
			-- longer than this. 372 against 420 has 48 studs of margin and `sqrt(372^2 + 50^2)` is
			-- 375, so the claim holds either way; the flat figure is used because it is the one the
			-- two rows of the table actually state, and the Y is the terrain's and not the drive's.
			local stag = Data.stagRow("normal", SCHEDULE)
			local reach = math.sqrt((stag.northStuds + roar.deeperStuds) ^ 2 + stag.offsetX ^ 2)
			expect(reach < roar.audibleStuds).to.equal(true)
			expect(math.sqrt(reach ^ 2 + 60 ^ 2) < roar.audibleStuds).to.equal(true)
			TestKit.note(
				string.format("the roar sounds %.0f studs from the stand and carries %d", reach, roar.audibleStuds)
			)
			expect(roar.volume < Boar.CONFIG.SOUND.CRY.volume).to.equal(true)
			-- A HIGH PLATEAU IS WHAT GIVES A LONG TAIL: `InverseTapered` falls as `near / distance`.
			expect(roar.nearStuds > Boar.CONFIG.SOUND.NEAR_STUDS).to.equal(true)
			-- NO CUT, which is the column the spec filled in with "none". Every deer VOICE row has one
			-- because it books a squeal slot; this books nothing.
			expect(roar.cut).to.equal(nil)
			expect(Boar.CONFIG.SOUND.VOICE.stag.cut).to.be.ok()
			-- AND IT IS NOT A VOICE: not one of its ids is any animal's cue, so a bull bellow chosen
			-- for the distance can never turn up as something's death.
			local voiced = {}
			for _, kind in ipairs({ "stag", "hind", "calf", "male", "female", "cub", "legendary" }) do
				local rowFor = Boar.CONFIG.SOUND.VOICE[kind]
				-- `bark` SINCE TASK 257: the alarm bark is its own cue with its own real recording,
				-- so it belongs in the set this case holds the roar apart from. A kind with no
				-- bark row contributes nothing, which is every boar and the calf.
				for _, cue in ipairs({ "cry", "death", "grunt", "bark" }) do
					for _, id in ipairs(rowFor[cue] or {}) do
						voiced[id] = true
					end
				end
			end
			for _, id in ipairs(roar.ids) do
				expect(voiced[id]).to.equal(nil)
			end
			-- THE WINDOW IS THE SPEC'S: four roars inside the first 90 s, all of them before the stag
			-- is released at slot 13, so he is heard long before he is seen.
			expect(roar.windowSeconds).to.equal(90)
			local heard = math.floor((roar.windowSeconds - roar.firstAtSeconds) / roar.everySeconds) + 1
			expect(heard >= 3).to.equal(true)
			local _, stagSlot = Data.stagRow("normal", SCHEDULE)
			expect(roar.windowSeconds < Data.slotSeconds(stagSlot, SCHEDULE)).to.equal(true)
			TestKit.note(
				string.format(
					"%d roars in the first %d s; the stag himself is released at %d s",
					heard,
					roar.windowSeconds,
					Data.slotSeconds(stagSlot, SCHEDULE)
				)
			)
		end)

		it("plays the real stag by region, loud, and reverts to the bulls without its clip", function()
			-- TASK 254. `reviews/task-253` note (d): *"`roarPoint` / `roarEmitter` / `stepRoar` /
			-- `roarNow` have no spec at all; the evidence is the live console lines"*. The CHOOSING
			-- half is pure and lives in `Data.roarClip`, so it is driven here with no Sound, no
			-- emitter and no Play session -- and both halves of it are, because the fallback is the
			-- revert path and a revert path nobody drives is a revert path that does not work.
			local roar = Data.ROAR
			local clip = roar.clips[roar.ids[1]]
			expect(clip).to.be.ok()
			expect(#clip.regions).to.equal(3)
			-- NO PITCH SHIFT ON THE REAL ANIMAL: 1.15 is there because a bull is three times a
			-- stag's weight, and this recording IS the stag.
			expect(clip.pitch).to.equal(1)
			expect(clip.pitch < roar.pitch).to.equal(true)

			local lastEnd = 0
			for index, region in ipairs(clip.regions) do
				local length = region.to - region.from
				-- 4-6 SECONDS, which is the length the spec's cue table asks a distant roar to be
				-- (*"3-6 s ... a distant roar must be long"*) and the length the Director's dispatch
				-- asked for. A region outside that band is either half a roar or two of them.
				expect(length >= 4).to.equal(true)
				expect(length <= 6).to.equal(true)
				-- INSIDE THE RECORDING, which is 52.897 s long as the live run measured it. A region
				-- past the end plays silence and `PlaybackRegion` will not say so.
				expect(region.from >= 0).to.equal(true)
				expect(region.to <= 52.89).to.equal(true)
				-- IN ORDER AND NEVER OVERLAPPING: two regions sharing a roar is the same sample
				-- twice wearing two names.
				expect(region.from > lastEnd).to.equal(true)
				lastEnd = region.to
				-- BOTH FADES FIT INSIDE THE REGION, twice over, or the fade-out would start before
				-- the fade-in finished and the cue would never reach its own volume.
				expect(clip.fadeSeconds * 2 < length).to.equal(true)
				-- THE GAIN IS WHAT MAKES ALL THREE AUDIBLE, and it is measured: 142 (the mean peak
				-- `PlaybackLoudness` of the four bulls this cue shipped with) over each region's own
				-- peak of 98, 54 and 50. It only ever lifts, and never past 1.0, which is the
				-- ceiling the peak-based figures were chosen to keep.
				expect(region.gain >= 1).to.equal(true)
				local effective = roar.volume * region.gain
				expect(effective <= 1).to.equal(true)
				-- ...AND IT LANDS WHERE THE BULLS ARE, to a tenth: that is the whole claim, because
				-- this task changes WHICH ANIMAL sounds and not how loud the cue is.
				-- THIS LITERAL IS THE MEASUREMENT RESTATED, NOT A MEASUREMENT (round 1, note): the
				-- three peaks and the bulls' 142 were read in a live Play session and written here
				-- by hand. So this case cannot prove the level is right -- only that `gain` and the
				-- peaks it was derived from have not drifted apart in a half-edit, which is what a
				-- later reader is most likely to do.
				local peaks = { 98, 54, 50 }
				expect(math.abs(peaks[index] * region.gain - 142) < 1).to.equal(true)
			end
			TestKit.note(
				string.format(
					"3 regions of asset %d, %.2f-%.2f s, at volume %.2f-%.2f (dial %.2f x gain %.2f-%.2f)",
					roar.ids[1],
					clip.regions[1].from,
					clip.regions[#clip.regions].to,
					roar.volume * clip.regions[1].gain,
					roar.volume * clip.regions[3].gain,
					roar.volume,
					clip.regions[1].gain,
					clip.regions[3].gain
				)
			)

			-- WHAT SOUNDS: the real stag, every time, with one of its three regions and that
			-- region's own volume. Driven over enough picks that all three regions turn up, so a
			-- chooser that always answered `regions[1]` would fail.
			local rng = Random.new(254)
			local seen = {}
			for _ = 1, 200 do
				local chosen = Data.roarClip(rng)
				expect(chosen.id).to.equal(roar.ids[1])
				expect(chosen.pitch).to.equal(1)
				expect(chosen.fadeSeconds).to.equal(clip.fadeSeconds)
				expect(chosen.from).to.be.ok()
				expect(chosen.to).to.be.ok()
				local found = nil
				for _, region in ipairs(clip.regions) do
					if region.from == chosen.from and region.to == chosen.to then
						found = region
					end
				end
				expect(found).to.be.ok()
				expect(chosen.volume).to.equal(roar.volume * found.gain)
				seen[chosen.from] = true
			end
			local distinct = 0
			for _ in pairs(seen) do
				distinct += 1
			end
			expect(distinct).to.equal(3)

			-- THE REVERT PATH, BY PARAMETER (the flag rule's shape, and the only way to drive the
			-- half that does not ship). It is ONE edit -- the first id out of `ids` -- and then this
			-- is task 251 part 2 exactly: a uniform pick over the four bulls at the table's own pitch
			-- and volume, and NO REGION, which matters because `roarNow` reads `from`/`to` to decide
			-- whether to clear `PlaybackRegionsEnabled` on the one Sound in the world. The `clips`
			-- entry is left in place, orphaned, exactly as the revert would leave it.
			local reverted = {
				ids = { roar.ids[2], roar.ids[3], roar.ids[4], roar.ids[5] },
				clips = roar.clips,
				pitch = roar.pitch,
				volume = roar.volume,
			}
			local heard = {}
			for _ = 1, 200 do
				local chosen = Data.roarClip(rng, reverted)
				expect(chosen.from).to.equal(nil)
				expect(chosen.to).to.equal(nil)
				expect(chosen.pitch).to.equal(roar.pitch)
				expect(chosen.volume).to.equal(roar.volume)
				heard[chosen.id] = true
			end
			for index = 2, 5 do
				expect(heard[roar.ids[index]]).to.equal(true)
			end

			-- AND THE TRAP THAT IS NOT THE REVERT PATH (round 1, finding 2). A `clips` entry whose
			-- `regions` list has gone empty must NOT drop its id back into the uniform pick: that id
			-- is 52.897 seconds long, it would play WHOLE at pitch 1.15 -- about 46 s -- and
			-- `roarNow`'s `IsPlaying` guard would then refuse the two cues behind it. One in five
			-- cues would cost three. So an id with a `clips` entry is never played whole, and here
			-- 200 picks over a table that still lists it never return it.
			local hollow = {
				ids = roar.ids,
				clips = { [roar.ids[1]] = { regions = {} } },
				pitch = roar.pitch,
				volume = roar.volume,
			}
			for _ = 1, 200 do
				local chosen = Data.roarClip(rng, hollow)
				expect(chosen).to.be.ok()
				expect(chosen.id).never.to.equal(roar.ids[1])
				expect(chosen.from).to.equal(nil)
				expect(chosen.pitch).to.equal(roar.pitch)
			end
			-- ...AND WHEN THE FILTER LEAVES NOTHING, SILENCE. 46 seconds of a field recording is a
			-- worse answer than no roar at all, so this is `nil` rather than "play it anyway".
			expect(Data.roarClip(rng, {
				ids = { roar.ids[1] },
				clips = { [roar.ids[1]] = { regions = {} } },
				pitch = roar.pitch,
				volume = roar.volume,
			})).to.equal(nil)
			-- AND NO IDS AT ALL IS SILENCE TOO, not a nil SoundId.
			expect(Data.roarClip(rng, { ids = {}, pitch = 1, volume = 1 })).to.equal(nil)
		end)

		it("repeats the body of the drive when a drive outlives its script, and never a second stag", function()
			-- A longer `DRIVE.seconds` must not run out of animals, and must not put a second stag
			-- out: `MAX_GROUPS_ALIVE` would refuse him anyway, and "the stag comes last" is the row's
			-- whole meaning.
			local rows = #SCHEDULE.drive
			for slot = rows + 1, rows + 40 do
				local row = Data.slotAt(slot, "normal", SCHEDULE)
				expect(row).to.be.ok()
				expect(row.slot >= SCHEDULE.repeatFrom and row.slot <= SCHEDULE.repeatTo).to.equal(true)
				expect(row.party).to.equal(nil)
			end
			-- The window wraps in order, so slot 16 is the first row of it.
			expect(Data.slotAt(rows + 1, "normal", SCHEDULE).slot).to.equal(SCHEDULE.repeatFrom)
			-- A slot before the first is nothing at all, rather than row 1 by accident.
			expect(Data.slotAt(0, "normal", SCHEDULE)).to.equal(nil)
			expect(Data.slotAt(-3, "normal", SCHEDULE)).to.equal(nil)
		end)

		it("is what BOTH release paths read, through one function", function()
			-- ONE OWNER PER FACT (rule 3). `ForestTest.waveAt` is the only reader of the rows, so the
			-- `LINE` path Karen plays and the pre-task-127 wave path cannot disagree about the drive.
			for slot = 1, #SCHEDULE.drive do
				expect(ForestTest.waveAt(slot)).to.equal(Data.slotAt(slot, SCHEDULE.density, SCHEDULE))
			end
			-- The two silences are nil from both, which is what makes a silence cost its slot.
			local silent = 0
			for slot = 1, #SCHEDULE.drive do
				if ForestTest.waveAt(slot) == nil then
					silent += 1
				end
			end
			expect(silent).to.equal(2)
		end)

		it("gives every route word a shape, and the one that never crosses no crossing", function()
			local seen = {}
			for _, row in ipairs(SCHEDULE.drive) do
				local route = Data.slotRoute(row)
				seen[route] = (seen[route] or 0) + 1
				if route == "LATERAL" then
					-- A lateral pass must say which way it travels, or `lateralSign` answers 0 and
					-- the "broadside" walk is a walk of nowhere.
					expect(ForestTest.lateralSign(row.lateral) ~= 0).to.equal(true)
				elseif route == "BREAK-BACK" then
					-- It turns SHORT of the road and goes home past the beaters.
					expect(row.turnAtDz > 0).to.equal(true)
					expect(row.turnAtDz < row.northStuds).to.equal(true)
					expect(SCHEDULE.breakBackToDz > row.northStuds).to.equal(true)
				elseif route == "HOLD" then
					-- It moves a little and lies up, well short of the verge.
					expect(row.holdStuds > 0).to.equal(true)
					expect(row.northStuds - row.holdStuds > Data.LINE.checkWithinStuds).to.equal(true)
				elseif route == "SPLIT" then
					expect(row.splitStuds ~= 0).to.equal(true)
					expect(row.files >= 1).to.equal(true)
				end
			end
			-- All five of the spec's route types are actually used by the drive.
			expect(seen.STRAIGHT >= 1).to.equal(true)
			expect(seen.LATERAL >= 1).to.equal(true)
			expect(seen["BREAK-BACK"]).to.equal(2)
			expect(seen.SPLIT).to.equal(1)
			expect(seen.HOLD).to.equal(1)
			-- An empty row is a silence and not a straight line, which is what `releaseLine` leans on.
			expect(Data.slotRoute(nil)).to.equal("SILENT")
		end)

		it("stays well inside the world's ceiling even if the whole script were alive at once", function()
			-- `MAX_BOARS` ASSERTS rather than refusing inside `Runtime:spawn`, so the script may never
			-- be able to ask past it. This is the worst case the dial can produce, which is far more
			-- than is ever on its feet at once (groups are released over five minutes and most are
			-- gone within a minute of crossing).
			-- WHAT CAN BE ALIVE AT ONCE, which is the only thing `MAX_BOARS` is about -- not the
			-- drive's total (round 1's note, which was right: `<= MAX_BOARS + 9` was 69 <= 69 and
			-- asserted nothing). The worst case is the biggest window of CONSECUTIVE slots whose
			-- animals could all still be on their feet: a group crosses and is gone well inside a
			-- minute, which is three slots at this interval.
			local config2 = configOn()
			local sizes = {}
			for slot = 1, #SCHEDULE.drive do
				local row = Data.slotAt(slot, "busy", SCHEDULE)
				local composition = if row == nil
					then nil
					elseif row.species == "reddeer" then Boar.deerComposition(0, 0, config2, row.party)
					else config2.SOUNDER.COMPOSITIONS[row.composition]
				sizes[slot] = if composition ~= nil then Boar.compositionSize(composition, config2) else 0
			end
			local worst = 0
			for slot = 1, #sizes do
				local window = 0
				for ahead = slot, math.min(slot + 2, #sizes) do
					window += sizes[ahead]
				end
				worst = math.max(worst, window)
			end
			expect(worst < Data.MAX_BOARS).to.equal(true)
			TestKit.note(
				string.format(
					"task 251: the busiest three consecutive slots are %d animals against MAX_BOARS %d",
					worst,
					Data.MAX_BOARS
				)
			)
			-- ...and no single group can fill the world by itself.
			local config = configOn()
			for _, row in ipairs(SCHEDULE.drive) do
				local composition = if row.species == "reddeer"
					then Boar.deerComposition(0, 0, config, row.party)
					else config.SOUNDER.COMPOSITIONS[row.composition]
				expect(Boar.compositionSize(composition, config) < Data.MAX_BOARS).to.equal(true)
			end
		end)
	end)

	-- ------------------------------------------------- THE ROUTE THROUGH N PINNED POINTS (task 251)
	describe("the route builder", function()
		it("RE-PINS A STUCK LEADER THROUGH ITS OWN PINS, and never through a crossing that is nil", function()
			-- ROUND 1'S BLOCKING FINDING, AS A CASE. The repath used to be computed through
			-- `line.crossing`, which this task made nil for exactly the two route words that never
			-- reach the road -- so the first stuck leader of a `BREAK-BACK` or a `HOLD` file would have
			-- indexed a nil inside the drive's own un-pcalled Heartbeat and lost the rest of that tick,
			-- every stuck check, for the life of the line. A HOLD file stands still BY DESIGN, which
			-- is the very case the stuck rule fires on.
			local standX = Data.standX(5)
			local here = Vector3.new(standX, 140, Data.roadZ(standX) + 120)
			-- A ROUTE WITH NO CROSSING STILL HAS PINS: the turn and the way home for a refusal, the
			-- hold point for the one that stays. Built the way `releaseLine` builds them.
			for _, row in ipairs(Data.SCHEDULE.drive) do
				local route = Data.slotRoute(row)
				if route == "BREAK-BACK" then
					local at = Data.wavePoint(standX, row)
					local pins = {
						Vector3.new(at.X, 140, Data.roadZ(at.X) + row.turnAtDz),
						Vector3.new(at.X, 140, Data.roadZ(at.X) + Data.SCHEDULE.breakBackToDz),
					}
					local via = ForestTest.repathVia(here, pins)
					expect(via).to.be.ok()
					expect(#via).to.equal(3)
					expect(via[1]).to.equal(here)
					expect(via[3]).to.equal(pins[2])
				end
			end
			-- ...AND NOTHING TO PIN THROUGH IS nil, NOT A STRAIGHT LINE. The leader is then left to the
			-- Brain, which is what the `leaderFreeSeconds` window beside it is for -- and nothing is
			-- indexed.
			expect(ForestTest.repathVia(here, nil)).to.equal(nil)
			expect(ForestTest.repathVia(here, {})).to.equal(nil)
			expect(ForestTest.repathVia(nil :: any, { here })).to.equal(nil)
			-- A pins list with one real point is a one-leg repath, which `computeRouteVia` accepts.
			local one = ForestTest.repathVia(here, { Vector3.new(standX, 140, Data.roadZ(standX)) })
			expect(#one).to.equal(2)
		end)

		it("refuses a route that is not pinned through at least two points", function()
			-- A route that was not pinned through a crossing is a route that may cross anywhere,
			-- which is what the two-leg shape has always existed to prevent.
			expect(ForestTest.computeRouteVia({})).to.equal(nil)
			expect(ForestTest.computeRouteVia({ Vector3.new(0, 0, 0) })).to.equal(nil)
			expect(ForestTest.computeRouteVia(nil :: any)).to.equal(nil)
		end)
	end)
end
