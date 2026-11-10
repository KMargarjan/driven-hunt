-- forest_placement.spec: WHERE EVERY ANIMAL OF A DRIVE IS STANDING BEFORE ANYBODY CAN SEE IT, as
-- arithmetic -- no world, no animal, no raycast and no clock (task 345, T1).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- `Placement` requires nothing and owns no state: every fact is handed in, so each of the ten rules
-- the drive will rely on is drivable here with the real tables AND with hand-written ones. The
-- cases assert RELATIONS and never literals, so moving `SPOOK.NOTICE_STUDS`, `REST.nearRoadStuds`,
-- `BEATER.behindLineStuds` or a `DENSITIES` row moves the rule instead of leaving a stale number.
--
-- IT RIDES `BOAR_MODEL` FOR THE DEER HALF, and that is said rather than guarded (round 1's note):
-- `Boar.CONFIG.KINDS.ENABLED` is `Flags.isOn("BOAR_MODEL")` and `Boar.deerComposition` answers nil
-- with the kinds off, so flipping that row to false drops every `reddeer` row from a plan and the
-- density counts go red for a reason that is not placement's. It is on by default and has been since
-- task 123; the cap, which `ForestTestBoot` MUTATES at boot, is the one that is built instead of
-- read (`configWithDeerCap`), because load order is not a thing a spec may depend on.
--
-- Design: docs/design/animal-placement.md section 13.1
-- Note:   docs/research/2026-11-10-animal-placement.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- The ANIMAL owner answers how many animals a composition is and which party a name is; this file
-- never counts a hind (design section 4.2).
local Boar = require(ServerScriptService:WaitForChild("Boar"))
-- The BEATERS' own pace, for the arithmetic that turns a bed's depth into a time.
local Bots = require(ServerScriptService:WaitForChild("Bots"))
local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
local Placement = require(ReplicatedStorage:WaitForChild("ForestTest"):WaitForChild("Placement"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local CONFIG = Placement.CONFIG
local SPOOK = Data.SPOOK
local REST = Data.REST
local SCHEDULE = Data.SCHEDULE
local DENSITIES = { "quiet", "normal", "busy" }

-- WHAT THE OWNERS ANSWER. Exactly the live wiring T2 will write, so a case that passes here is a
-- case about the drive and not about a stub.
local function depsFor(layout: any?)
	return {
		noticeAheadStuds = Data.noticeAheadStuds(SPOOK, layout),
		laneSpacingStuds = Data.laneSpacing(layout),
		slotAt = Data.slotAt,
		compositionSize = Boar.compositionSize,
		deerComposition = Boar.deerComposition,
		sounderKinds = Boar.sounderKinds,
	}
end

-- THE FOREST TEST'S OWN DEER CAP, and it is built rather than read off `Boar.CONFIG` because
-- `ForestTestBoot` MUTATES that table at boot (`species.reddeer.RELEASE.MAX_GROUPS_ALIVE =
-- Data.MAX_DEER_GROUPS`): a spec that depended on whether the boot script had run yet would pass or
-- fail by load order. `table.clone` of a frozen table returns an unfrozen copy.
local function configWithDeerCap(cap: number)
	local config = table.clone(Boar.CONFIG)
	local species = table.clone(config.SPECIES)
	local reddeer = table.clone(species.reddeer)
	local release = table.clone(reddeer.RELEASE)
	release.MAX_GROUPS_ALIVE = cap
	reddeer.RELEASE = release
	species.reddeer = reddeer
	config.SPECIES = species
	return config
end

local FOREST = configWithDeerCap(Data.MAX_DEER_GROUPS)

local function planAt(density: string, beaterNorth: number?, schedule: any?, config: any?)
	return Placement.plan(
		1,
		schedule or SCHEDULE,
		{ density = density, restZones = { 2, 3 } },
		REST,
		SPOOK,
		beaterNorth or Data.beaterNorthStuds(),
		Bots.CONFIG.WALK_SPEED,
		config or FOREST,
		Random.new(1),
		depsFor(nil)
	)
end

-- The nominal size of every row the dial keeps at this density, asked of the animal owner.
local function animalsWanted(density: string): (number, { number })
	local total, slots = 0, {}
	for slot = 1, #SCHEDULE.drive do
		local row = Data.slotAt(slot, density, SCHEDULE)
		if row ~= nil then
			table.insert(slots, row.slot)
			if row.species == "reddeer" then
				total += Boar.compositionSize(Boar.deerComposition(0, 0, FOREST, row.party), FOREST)
			else
				total += Boar.compositionSize(FOREST.SOUNDER.COMPOSITIONS[row.composition], FOREST)
			end
		end
	end
	return total, slots
end

return function()
	describe("the roster is the dial", function()
		it("keeps exactly the rows Data.slotAt keeps, at every density", function()
			for _, density in ipairs(DENSITIES) do
				local rows = planAt(density)
				local wantedAnimals, wantedSlots = animalsWanted(density)
				expect(#rows).to.equal(#wantedSlots)
				expect(#rows).to.equal(SCHEDULE.DENSITIES[density])
				for index, row in ipairs(rows) do
					expect(row.slot).to.equal(wantedSlots[index])
				end
				local total = Placement.tally(rows)
				expect(total.animals).to.equal(wantedAnimals)
				expect(total.placed).to.equal(#wantedSlots)
				TestKit.note(
					string.format(
						"placement %s: %d groups / %d animals / %d walkers / %d skipped",
						density,
						total.placed,
						total.animals,
						total.walkers,
						total.skipped
					)
				)
			end
		end)

		it("follows the dial when the dial moves, so no count is written down here", function()
			-- 9 AND NOT 1 (round 1's blocking finding, which was right): every one of the fifteen
			-- rows carries `keepAt` 9, 13 or 15, so a dial of ONE keeps nothing and the case was
			-- `0 == 0` -- it survived gutting `plan`. A dial of nine keeps a NON-EMPTY subset that
			-- is not the shipped one, so the case now bites in both directions.
			local schedule = table.clone(SCHEDULE)
			local dials = table.clone(SCHEDULE.DENSITIES)
			dials.normal = SCHEDULE.DENSITIES.quiet
			schedule.DENSITIES = dials
			local moved, wanted = planAt("normal", nil, schedule), {}
			for slot = 1, #schedule.drive do
				local row = Data.slotAt(slot, "normal", schedule)
				if row ~= nil then
					table.insert(wanted, row.slot)
				end
			end
			expect(#wanted > 0).to.equal(true)
			expect(#moved).to.equal(#wanted)
			for index, row in ipairs(moved) do
				expect(row.slot).to.equal(wanted[index])
			end
			-- ...AND IT IS A DIFFERENT SET FROM THE UNMOVED DIAL'S, which is what "follows" means:
			-- a plan that ignored the dial would answer the same thirteen rows for both.
			local unmoved = planAt("normal")
			expect(#unmoved).to.equal(SCHEDULE.DENSITIES.normal)
			expect(#moved < #unmoved).to.equal(true)
			local shipped = {}
			for _, row in ipairs(unmoved) do
				shipped[row.slot] = true
			end
			local dropped = 0
			for _, slot in ipairs(wanted) do
				if not shipped[slot] then
					dropped += 1
				end
			end
			-- The quiet set is a SUBSET of the normal one, so every slot the moved dial keeps is one
			-- the shipped dial kept too -- the difference is which it drops, and it drops four.
			expect(dropped).to.equal(0)
			expect(#unmoved - #moved).to.equal(SCHEDULE.DENSITIES.normal - SCHEDULE.DENSITIES.quiet)
		end)

		it("gives the two shallowest beds the slot clock and every other bed none", function()
			local rows = planAt("normal")
			local total = Placement.tally(rows)
			expect(total.walkers).to.equal(CONFIG.walkersPerDrive)
			for index, row in ipairs(rows) do
				local shallowest = index > #rows - CONFIG.walkersPerDrive
				expect(row.walker).to.equal(shallowest)
				if shallowest then
					-- The shallowest bed takes the FIRST clock: it has the shortest walk and it is
					-- the opening of the drive.
					local which = #rows - index
					expect(row.wakeAtSeconds).to.equal(SCHEDULE.firstSlotSeconds + which * SCHEDULE.intervalSeconds)
				else
					expect(row.wakeAtSeconds).to.equal(math.huge)
				end
			end
		end)
	end)

	describe("the beds", function()
		it("run deepest first, evenly, and end on the band's two edges", function()
			local far, near = 450, 150
			expect(Placement.bedNorth(1, 9, near, far)).to.equal(far)
			expect(Placement.bedNorth(9, 9, near, far)).to.equal(near)
			local spacing = (far - near) / 8
			for ordinal = 2, 9 do
				local above = Placement.bedNorth(ordinal - 1, 9, near, far)
				local here = Placement.bedNorth(ordinal, 9, near, far)
				expect(above > here).to.equal(true)
				expect(math.abs((above - here) - spacing) < 1e-9).to.equal(true)
			end
			-- One group has no ladder to stand on, and the honest answer is the deepest bed.
			expect(Placement.bedNorth(1, 1, near, far)).to.equal(far)
		end)

		it("puts every planned bed inside the band, at every density", function()
			local layoutFar = Placement.bandFar(Data.beaterNorthStuds(), Data.noticeAheadStuds(SPOOK, nil), SPOOK)
			local layoutNear = Placement.bandNear(SPOOK, REST)
			for _, density in ipairs(DENSITIES) do
				local rows = planAt(density)
				local previous = math.huge
				for _, row in ipairs(rows) do
					expect(row.bedNorth <= layoutFar + 1e-9).to.equal(true)
					expect(row.bedNorth >= layoutNear - 1e-9).to.equal(true)
					expect(row.bedNorth < previous).to.equal(true)
					previous = row.bedNorth
					-- ...AND NO BED IS INSIDE THE LATERAL CAP'S OWN LIMIT either, so a bed is
					-- always within sight of the stand the drive aims at (task 267 item 1).
					expect(math.abs(row.bedOffsetX) <= SCHEDULE.crossCapStuds).to.equal(true)
				end
			end
		end)

		it("turns a bed's depth into the second the line reaches it", function()
			local far, near = 450, 150
			local speed = Bots.CONFIG.WALK_SPEED
			expect(Placement.lineReaches(far, far, speed)).to.equal(0)
			expect(math.abs(Placement.lineReaches(near, far, speed) - (far - near) / speed) < 1e-9).to.equal(true)
			-- A line that is not walking has no arrival, and that is a refusal rather than a divide.
			expect(Placement.lineReaches(near, far, 0)).to.equal(math.huge)
			local rows = planAt("normal")
			local gap = rows[2].reachAtSeconds - rows[1].reachAtSeconds
			TestKit.note(string.format("placement normal: the line finds a group every %.2f s", gap))
		end)
	end)

	describe("the band is derived and not written", function()
		it("takes the far edge off the muster, the notice band and the sweep floor", function()
			-- BOTH THE SHIPPED MUSTER AND THE ONE K-1 PROPOSES, so moving `behindLineStuds` moves
			-- the band with nothing else edited.
			for _, beaterNorth in ipairs({ Data.beaterNorthStuds(), 700 }) do
				local notice = Data.noticeAheadStuds(SPOOK, nil)
				local want = beaterNorth - notice - SPOOK.SWEEP.MIN_AHEAD_STUDS
				expect(Placement.bandFar(beaterNorth, notice, SPOOK)).to.equal(want)
			end
		end)

		it("never lets the near edge inside a hunter's reach", function()
			local never = Placement.neverStuds(SPOOK)
			local near = Placement.bandNear(SPOOK, REST)
			-- THE CLAMP. Delete the `max` with `neverStuds` in `Placement.bandNear` and this is the
			-- line that fails: the band would start at `REST.nearRoadStuds`, 105 studs inside the
			-- reach of a hunter at his stand.
			expect(near >= never).to.equal(true)
			expect(near).to.equal(CONFIG.bandNearStuds)
			-- ...and it is the road rule when the road rule is the bigger of the two, so the arm is
			-- a `max` and not a replacement.
			expect(Placement.bandNear({ NOTICE_STUDS = 0 }, { nearRoadStuds = 220 })).to.equal(220)
			-- A BAND HANDED IN THE WRONG WAY ROUND still answers inside its own two bounds rather
			-- than inventing a depth outside them: the ladder walks from `far` to `near` whichever
			-- of the two is the deeper (round 1's note -- the old line here drove an ordinary band
			-- and duplicated the case above).
			expect(Placement.bedNorth(1, 2, 450, 150)).to.equal(150)
			expect(Placement.bedNorth(2, 2, 450, 150)).to.equal(450)
		end)

		it("derives neverStuds from the notice reach and orders the four radii", function()
			expect(Placement.neverStuds(SPOOK)).to.equal(SPOOK.NOTICE_STUDS + CONFIG.bedSpreadStuds / 2)
			expect(Placement.neverStuds(SPOOK)).to.equal(CONFIG.neverStuds)
			expect(Placement.bedGapStuds(SPOOK)).to.equal(SPOOK.BEATER_STUDS)
			expect(Placement.bedGapStuds(SPOOK)).to.equal(CONFIG.bedGapStuds)
			-- THE ORDER IS THE RULE, not the numbers: a bed spread wider than the gap would make two
			-- beds one group, and a never-reach inside the gap would let a hunter stand in one.
			expect(CONFIG.bedSpreadStuds < CONFIG.bedGapStuds).to.equal(true)
			expect(CONFIG.bedGapStuds < CONFIG.neverStuds).to.equal(true)
			expect(CONFIG.neverStuds <= CONFIG.bandNearStuds).to.equal(true)
			-- Move the reach and `neverStuds` moves: it is not a literal anywhere but the published
			-- row this case has just checked.
			expect(Placement.neverStuds({ NOTICE_STUDS = 200 })).to.equal(200 + CONFIG.bedSpreadStuds / 2)
		end)
	end)

	describe("no two groups lie up inside one flush", function()
		it("clears every pair of beds by the flush circle, at every density", function()
			local gap = Placement.bedGapStuds(SPOOK)
			for _, density in ipairs(DENSITIES) do
				local rows = planAt(density)
				local beds = {}
				for _, row in ipairs(rows) do
					if row.skipped == nil then
						table.insert(beds, Vector3.new(row.bedOffsetX, 0, row.bedNorth))
					end
				end
				local closest = math.huge
				for i = 1, #beds do
					for j = i + 1, #beds do
						local distance = (beds[i] - beds[j]).Magnitude
						if distance < closest then
							closest = distance
						end
						expect(distance >= gap - 1e-9).to.equal(true)
					end
				end
				TestKit.note(
					string.format(
						"placement %s: %d beds, closest pair %.2f studs (gap %.0f)",
						density,
						#beds,
						closest,
						gap
					)
				)
			end
		end)

		it("skips a group it cannot bed, counts it and says so, rather than bedding it on another", function()
			-- A BAND WITH NO ROOM: one stud of lateral cap and thirteen beds 25 studs apart cannot
			-- hold a 71-stud gap, so the plan must refuse rather than stack them.
			local schedule = table.clone(SCHEDULE)
			schedule.crossCapStuds = 1
			local rows, lines = planAt("normal", nil, schedule)
			local total = Placement.tally(rows)
			expect(total.placed).to.equal(SCHEDULE.DENSITIES.normal)
			expect(total.skipped > 0).to.equal(true)
			local said = 0
			for _, line in ipairs(lines) do
				if string.find(line, "SKIPPED", 1, true) ~= nil then
					said += 1
				end
			end
			expect(said).to.equal(total.skipped)
			-- A SKIPPED ROW IS NEVER A WALKER and never comes back (design must-not 3).
			for _, row in ipairs(rows) do
				if row.skipped ~= nil then
					expect(row.walker).to.equal(false)
					expect(Placement.dueNow(row, math.huge, CONFIG.leadSeconds)).to.equal(false)
				end
			end
		end)

		it("takes the nearest legal x to the one the script wrote, and nil when there is none", function()
			local laid = { { x = 0, z = 100 } }
			-- Nothing in the way: the written x survives untouched.
			expect(Placement.clearX({}, 40, 100, 95, 71)).to.equal(40)
			-- In the way: swept outward, east first, to the first stud that clears 71.
			expect(Placement.clearX(laid, 0, 100, 95, 71)).to.equal(71)
			-- The cap refuses both sides, so there is no bed and the caller must skip.
			expect(Placement.clearX(laid, 0, 100, 40, 71)).to.equal(nil)
			-- The gap is 3-D: the same neighbour 60 studs deeper needs only 38 studs sideways.
			expect(Placement.clearX({ { x = 0, z = 40 } }, 0, 100, 95, 71)).to.equal(38)
		end)
	end)

	describe("nothing is created near a player's eyes", function()
		it("refuses inside the reach, allows outside it, and says how far", function()
			local spot = Vector3.new(0, 0, 0)
			local never = Placement.neverStuds(SPOOK)
			local inside, near = Placement.clearOfEyes(spot, { Vector3.new(never - 1, 0, 0) }, never)
			expect(inside).to.equal(false)
			expect(near).to.equal(never - 1)
			local outside, far = Placement.clearOfEyes(spot, { Vector3.new(never + 1, 0, 0) }, never)
			expect(outside).to.equal(true)
			expect(far).to.equal(never + 1)
			-- NO EYES IS NOT A REFUSAL, and the distance it reports is honest.
			local empty, none = Placement.clearOfEyes(spot, {}, never)
			expect(empty).to.equal(true)
			expect(none).to.equal(math.huge)
			-- THE NEAREST EYE DECIDES, not the first one in the list.
			local many, nearest =
				Placement.clearOfEyes(spot, { Vector3.new(400, 0, 0), Vector3.new(never - 5, 0, 0) }, never)
			expect(many).to.equal(false)
			expect(nearest).to.equal(never - 5)
		end)

		it("measures a high seat in three dimensions and not flat", function()
			local spot = Vector3.new(0, 0, 0)
			local never = Placement.neverStuds(SPOOK)
			local deck = 12.5 -- a hunter on a high seat deck (`Match.CONFIG.STAND_HEIGHT_STUDS`'s order)
			-- The design's case: 144 studs away flat and 12.5 up is STILL inside 145.
			local still = Placement.clearOfEyes(spot, { Vector3.new(never - 1, deck, 0) }, never)
			expect(still).to.equal(false)
			-- ...AND THE CASE THAT PROVES THE THIRD DIMENSION IS USED AT ALL: 144 flat and 20 up is
			-- 145.38 studs away, which is OUTSIDE. A flat test would refuse this bed; the 3-D rule
			-- allows it, so replacing the body with a flat distance fails here.
			local high, measured = Placement.clearOfEyes(spot, { Vector3.new(never - 1, 20, 0) }, never)
			expect(high).to.equal(true)
			expect(measured > never).to.equal(true)
			-- 1e-3 and not 1e-9: a Vector3 is float32, so a 145-stud magnitude carries about 1.5e-5
			-- of its own (MEASURED: this line failed at 1e-6 on the first run of this spec).
			expect(math.abs(measured - math.sqrt((never - 1) ^ 2 + 400)) < 1e-3).to.equal(true)
		end)
	end)

	describe("the budget door", function()
		it("refuses on each arm independently and is read at the instant", function()
			local cap, bedCap = 24, CONFIG.bedCap
			expect(Placement.roomFor(21, 0, 3, cap, bedCap)).to.equal(true)
			local tooMany, why = Placement.roomFor(22, 0, 3, cap, bedCap)
			expect(tooMany).to.equal(false)
			expect(why).to.equal("live")
			-- The bed cap bites with the live cap wide open, so the two arms are independent.
			local bedded, reason = Placement.roomFor(0, bedCap - 1, 3, cap, bedCap)
			expect(bedded).to.equal(false)
			expect(reason).to.equal("bedded")
			expect(Placement.roomFor(0, bedCap - 3, 3, cap, bedCap)).to.equal(true)
			-- NEVER LATCHED (L-029): a refusal followed by room answers room, on the same door.
			expect(Placement.roomFor(24, 0, 1, cap, bedCap)).to.equal(false)
			expect(Placement.roomFor(23, 0, 1, cap, bedCap)).to.equal(true)
		end)

		it("is due only when the line is within the lead, and never for a skip or a body", function()
			local rows = planAt("normal")
			local deepest = rows[1]
			expect(deepest.reachAtSeconds).to.equal(0)
			expect(Placement.dueNow(deepest, 0, CONFIG.leadSeconds)).to.equal(true)
			local shallow = rows[#rows - CONFIG.walkersPerDrive]
			-- Its own arrival is beyond the lead, so it is not due at the opening...
			expect(shallow.reachAtSeconds > CONFIG.leadSeconds).to.equal(true)
			expect(Placement.dueNow(shallow, 0, CONFIG.leadSeconds)).to.equal(false)
			-- ...and it is due exactly `leadSeconds` before the line gets there.
			expect(Placement.dueNow(shallow, shallow.reachAtSeconds - CONFIG.leadSeconds, CONFIG.leadSeconds)).to.equal(
				true
			)
			-- A ROW THAT ALREADY HAS A BODY IS NOT DUE A SECOND ONE.
			local bodied = table.clone(shallow)
			bodied.state = "bedded"
			expect(Placement.dueNow(bodied, math.huge, CONFIG.leadSeconds)).to.equal(false)
			-- A SKIP IS A SKIP: a wood is beaten once (task 172), so a refused group can never come
			-- back inside this drive however late it is.
			local refused = table.clone(shallow)
			refused.skipped = "nobed"
			expect(Placement.dueNow(refused, math.huge, CONFIG.leadSeconds)).to.equal(false)
			-- A walker is due on its own clock even where the line will never reach it.
			local walker = table.clone(rows[#rows])
			walker.reachAtSeconds = math.huge
			expect(Placement.dueNow(walker, walker.wakeAtSeconds - CONFIG.leadSeconds, CONFIG.leadSeconds)).to.equal(
				true
			)
		end)
	end)

	describe("what makes a bedded group move", function()
		it("wakes a walker on its clock and never earlier", function()
			local notice = Data.noticeAheadStuds(SPOOK, nil)
			local row = { state = "bedded", walker = true, wakeAtSeconds = 10, bedNorth = 200 }
			expect(Placement.wakeReason(row, 9.99, nil, notice)).to.equal(nil)
			expect(Placement.wakeReason(row, 10, nil, notice)).to.equal("slot")
			-- A RECORD HAS NO BODY TO WAKE, so the clock cannot reach it.
			local record = table.clone(row)
			record.state = "record"
			expect(Placement.wakeReason(record, 100, nil, notice)).to.equal(nil)
		end)

		it("wakes a bedded group when the line's notice band reaches its bed, and never without a line", function()
			local notice = Data.noticeAheadStuds(SPOOK, nil)
			local row = { state = "bedded", walker = false, wakeAtSeconds = math.huge, bedNorth = 450 }
			-- NO LINE, NO WAKE, for ever: a group the line must find waits for the line.
			expect(Placement.wakeReason(row, 1e9, nil, notice)).to.equal(nil)
			-- The front one stud outside the band is still a group lying down...
			expect(Placement.wakeReason(row, 0, 450 + notice + 1, notice)).to.equal(nil)
			-- ...and on the band's own edge it is up.
			expect(Placement.wakeReason(row, 0, 450 + notice, notice)).to.equal("beaters")
			-- A line that has walked past the bed has certainly reached it (`Data.sweepCatches` is
			-- the server's half of that story).
			expect(Placement.wakeReason(row, 0, 100, notice)).to.equal("beaters")
		end)

		it("keeps a bed clear of every bed already found", function()
			local gap = Placement.bedGapStuds(SPOOK)
			local rows = {
				{ state = "bedded", at = Vector3.new(0, 0, 0) },
				{ state = "record", at = nil },
				{ state = "gone", at = Vector3.new(10, 0, 0) },
				{ state = "bedded", at = Vector3.new(20, 0, 0), skipped = "nobed" },
			}
			expect(Placement.gapOk(rows, Vector3.new(gap, 0, 0), gap)).to.equal(true)
			expect(Placement.gapOk(rows, Vector3.new(gap - 1, 0, 0), gap)).to.equal(false)
			-- A group that has GONE and one that was SKIPPED hold no ground.
			expect(Placement.gapOk(rows, Vector3.new(10, 0, 200), gap)).to.equal(true)
			expect(Placement.gapOk(rows, Vector3.new(20, 0, 200), gap)).to.equal(true)
			-- 3-D, as everywhere else in this file.
			expect(Placement.gapOk(rows, Vector3.new(0, gap - 1, 0), gap)).to.equal(false)
		end)
	end)

	describe("the deer cap is spent once per drive, at plan time", function()
		it("admits one group of two, refuses the other and prints the refusal", function()
			-- TWO DEER ROWS, NEITHER OF THEM A PARTY OF ONE, and a cap of one group.
			local schedule = table.clone(SCHEDULE)
			schedule.DENSITIES = { quiet = 2, normal = 2, busy = 2 }
			schedule.drive = table.freeze({
				table.freeze({ slot = 1, act = 1, species = "reddeer", party = "hindherd", offsetX = -60, keepAt = 1 }),
				table.freeze({ slot = 2, act = 1, species = "reddeer", party = "herd", offsetX = 60, keepAt = 1 }),
			})
			local rows, lines = planAt("normal", nil, schedule, configWithDeerCap(1))
			expect(#rows).to.equal(1)
			expect(rows[1].slot).to.equal(1)
			local refusals = 0
			for _, line in ipairs(lines) do
				if string.find(line, "the deer cap refused", 1, true) ~= nil then
					refusals += 1
				end
			end
			expect(refusals).to.equal(1)
		end)

		it("lets a party of one through over the cap, so the stag is still the last deer", function()
			local schedule = table.clone(SCHEDULE)
			schedule.DENSITIES = { quiet = 3, normal = 3, busy = 3 }
			schedule.drive = table.freeze({
				table.freeze({ slot = 1, act = 1, species = "reddeer", party = "hindherd", offsetX = -60, keepAt = 1 }),
				table.freeze({ slot = 2, act = 1, species = "reddeer", party = "herd", offsetX = 60, keepAt = 1 }),
				table.freeze({ slot = 3, act = 3, species = "reddeer", party = "stag", offsetX = -95, keepAt = 1 }),
			})
			local rows = planAt("normal", nil, schedule, configWithDeerCap(1))
			-- The hind party takes the one group, the herd is refused, and the lone stag comes
			-- anyway on `LONE_PARTY_EXTRA_GROUPS` -- the animal owner's own rule, read off its table.
			expect(#rows).to.equal(2)
			expect(rows[1].slot).to.equal(1)
			expect(rows[#rows].slot).to.equal(3)
			expect(rows[#rows].size).to.equal(1)
			-- ...AND THE EXEMPTION IS WEIGHED, NOT NAMED (task 253's own words): make that third row
			-- a party of three and the same cap refuses it, with nothing else edited. So the rule
			-- reads off the animal owner's composition table and not off the word "stag".
			local harem = table.clone(schedule)
			harem.drive = table.freeze({
				schedule.drive[1],
				schedule.drive[2],
				table.freeze({ slot = 3, act = 3, species = "reddeer", party = "harem", offsetX = -95, keepAt = 1 }),
			})
			local rows3 = planAt("normal", nil, harem, configWithDeerCap(1))
			expect(#rows3).to.equal(1)
			expect(rows3[1].slot).to.equal(1)
		end)

		it("counts the whole roster in one line a console can read", function()
			local rows = planAt("normal")
			expect(Placement.line({})).to.equal("placed 0 / bedded 0 / awake 0 / gone 0 / skipped 0")
			expect(Placement.line(rows)).to.equal(
				string.format("placed %d / bedded 0 / awake 0 / gone 0 / skipped 0", #rows)
			)
			-- Every row of a fresh plan is a RECORD: nothing exists in the world yet, which is the
			-- whole point of the tier (design section 4.1).
			for _, row in ipairs(rows) do
				expect(row.state).to.equal("record")
				expect(row.at).to.equal(nil)
				expect(#row.ids).to.equal(0)
				expect(#row.kinds).to.equal(row.size)
				expect(row.id).to.equal(string.format("g1-s%d", row.slot))
				-- The lane a bed belongs to is one of the lattice `Data.beaterLaneOffset` deals.
				expect(row.laneOffset % Data.laneSpacing(nil)).to.equal(0)
			end
		end)
	end)
end
