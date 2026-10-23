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
			expect(#SCHEDULE.drive).to.equal(ForestTest.wavesPerDrive(Data.DRIVE.seconds, SCHEDULE.intervalSeconds))
			for index, row in ipairs(SCHEDULE.drive) do
				expect(row.slot).to.equal(index)
				-- `atSeconds` IS AN ASSERTION, NOT A SECOND CLOCK: it has to be the interval's own
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
			expect(normal.leapers).to.equal(2) -- the hind party is ONE row of two animals, plus the stag
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
			expect(shallowest).to.equal(85) -- zone A, the near holding
			expect(deepest).to.equal(360) -- zone C, the one that holds
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

		it("puts the hinds early and the stag LAST, alone, and deeper than anything that comes", function()
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
			-- ...and he is in act III, at a walk, and he is the last ANIMAL row of the drive that
			-- a hunter at the stand ever sees come at him.
			expect(stag.act).to.equal(3)
			expect(stag.pace).to.equal("walk")
		end)

		it("walks the stag's SNEAK as a declared field and nothing more, which is part 2's boundary", function()
			-- RULE 8, AS A CASE. Task 251 part 1 ships the pattern and the horn; the stag's own
			-- behaviour (the 0.90 edge check, the look back, the treeline sneak, the bound) is part 2.
			-- So `sneak` is DATA that no route reads yet, and the day part 2 reads it, THIS case is
			-- the thing that has to change -- which is the opposite of discovering the gap in a
			-- playtest.
			local stag = nil
			for _, row in ipairs(SCHEDULE.drive) do
				if row.party == "stag" then
					stag = row
				end
			end
			expect(stag.sneak).to.equal(true)
			expect(stag.check).to.equal(true)
			-- The route it is actually released on today is the ordinary one.
			expect(Data.slotRoute(stag)).to.equal("STRAIGHT")
			-- ...and the existing edge stop is what honours `check` for now: every file's leader is
			-- offered it inside this band, at the Brain's own chance.
			expect(Data.LINE.checkWithinStuds > 0).to.equal(true)
			expect(Boar.CONFIG.MOVE.EDGE_CHANCE > 0).to.equal(true)
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
			expect(animalsAt("busy") <= Data.MAX_BOARS + 9).to.equal(true)
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
		it("refuses a route that is not pinned through at least two points", function()
			-- A route that was not pinned through a crossing is a route that may cross anywhere,
			-- which is what the two-leg shape has always existed to prevent.
			expect(ForestTest.computeRouteVia({})).to.equal(nil)
			expect(ForestTest.computeRouteVia({ Vector3.new(0, 0, 0) })).to.equal(nil)
			expect(ForestTest.computeRouteVia(nil :: any)).to.equal(nil)
		end)
	end)
end
