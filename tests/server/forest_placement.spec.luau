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
-- SINCE T2 IT ALSO DRIVES THE OWNER (`ServerScriptService.ForestTest`), for the two rules the pure
-- half cannot carry: that the roster IS the drive's population behind the flag, and that a slot
-- whose group is already in the wood is not released again (the bridge). Both are driven with no
-- runtime, so they are about the decision and not about a body.
--
-- Design: docs/design/animal-placement.md sections 13.1, 17 (T2)
-- Note:   docs/research/2026-11-10-animal-placement.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- The ANIMAL owner answers how many animals a composition is and which party a name is; this file
-- never counts a hind (design section 4.2).
local Boar = require(ServerScriptService:WaitForChild("Boar"))
-- The BEATERS' own pace, for the arithmetic that turns a bed's depth into a time.
local Bots = require(ServerScriptService:WaitForChild("Bots"))
local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
-- THE OWNER OF THE ROSTER (T2), and the GRID that holds the live beater pace and a cell's depth.
local Forest = require(ServerScriptService:WaitForChild("ForestTest"))
local Grid = require(ReplicatedStorage:WaitForChild("Grid"))
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
		slotSeconds = Data.slotSeconds,
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

-- A STUB BOAR RUNTIME, so the OWNER's two flag states can be told apart (round 1, findings 1 and 2).
-- `ForestTest.stepPlacement` and `ForestTest.releaseLine` both answer nil on their first line while
-- `state.runtime` is nil, so without one every case that called them passed through the same arm and
-- could not fail. It is `forest_stand.spec`'s own `fake` plus the methods the placement path asks
-- for; it records what was spawned, and `standing` is the list of ids it reports ON THEIR FEET --
-- which is what `stepPlacement`'s reconcile reads, so a case decides for itself whether a bedded
-- group still has bodies (round 3).
-- `where` IS WHAT T4 NEEDS OF THE STUB: `orderGroup` reads every member's POSITION and KIND off the
-- runtime (never off the roster row, because a bedded group has drifted over its graze repertoire)
-- and asks the Brain whether the fright has already taken it (`flying`). A row of `where` is one
-- body: `{ at = Vector3, kind = "female", flying = false }`.
local function stubRuntime()
	local made, standing, where = {}, {}, {}
	local fake
	fake = {
		setField = function() end,
		clear = function() end,
		count = function()
			return 0
		end,
		capacity = function()
			return Data.MAX_BOARS
		end,
		liveCount = function()
			return 0
		end,
		boars = function()
			local out = {}
			for _, id in ipairs(standing) do
				-- THE REAL HANDLE'S SHAPE, copied from `Runtime:boars` -> `entry.handle`
				-- (`src/server/Boar/init.luau`): `position` is a FUNCTION, read live, and `kind` is
				-- on the handle. `ForestTest.spookNearBeaters` reads all three unguarded, and it is
				-- reached whenever a real beater exists -- which is why only `test2` found this.
				-- `part` is left out on purpose: both of its readers nil-guard it and a stub has no
				-- instance to hand over.
				table.insert(out, {
					id = id,
					kind = (where[id] or {}).kind or "female",
					position = function()
						return (where[id] or {}).at or Vector3.new(0, 0, 0)
					end,
				})
			end
			return out
		end,
		statusOf = function(_self, id)
			for _, live in ipairs(standing) do
				if live == id then
					local body = where[id] or {}
					return {
						alive = true,
						position = body.at or Vector3.new(0, 0, 0),
						kind = body.kind or "female",
						speed = 0,
						want = 0,
					}
				end
			end
			return nil
		end,
		flying = function(_self, id)
			return (where[id] or {}).flying == true
		end,
		leadTo = function() end,
		woundOf = function()
			return nil
		end,
		sounderOf = function()
			return nil
		end,
		check = function() end,
		notice = function()
			return false
		end,
		spook = function()
			return false
		end,
		config = function()
			return Boar.CONFIG
		end,
		deerAllowed = function()
			return true
		end,
		formSounder = function() end,
		-- A BODY THE STUB MAKES IS REALLY ALIVE IN IT (T4): `materialise` keeps the ids `spawn`
		-- and `spawnSounder` hand back, and `orderGroup` then reads those ids' positions off the
		-- runtime -- so a stub that answered nil could not carry a group from its bed to its
		-- route at all.
		spawn = function(_self, at, kind)
			table.insert(made, tostring(kind))
			local id = string.format("Stub%d", #made)
			table.insert(standing, id)
			where[id] = { at = at, kind = tostring(kind) }
			return { id = id }
		end,
		spawnSounder = function(_self, at, size)
			local out = {}
			for index = 1, size do
				table.insert(made, "sounder")
				local id = string.format("Stub%d", #made)
				table.insert(standing, id)
				where[id] = { at = at + Vector3.new(index * 2, 0, 0), kind = "female" }
				table.insert(out, { id = id })
			end
			return out
		end,
	}
	return made, standing, fake, where
end

-- WHERE THE LINE ACTUALLY MUSTERS IN A DRIVE KAREN PLAYS: a CELL's own depth (`grid-map.md` 4.3;
-- every layout the rotation deals has been a cell since task 327d), and not the archived road
-- place's 580. The band is `beaterNorth - noticeAhead - MIN_AHEAD`, so this is what decides whether
-- fifteen slots 73 studs apart fit in front of the line at all.
local CELL_MUSTER = Grid.CONFIG.cellDepthStuds

local function planAt(density: string, beaterNorth: number?, schedule: any?, config: any?)
	return Placement.plan(
		1,
		schedule or SCHEDULE,
		{ density = density, restZones = { 2, 3 } },
		REST,
		SPOOK,
		beaterNorth or CELL_MUSTER,
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
		it("lie where the line will be at the moment the script says the group moves", function()
			local far, near = Placement.bandFar(CELL_MUSTER, Data.noticeAheadStuds(SPOOK, nil), SPOOK), 150
			local speed = Grid.CONFIG.beaterWalkStudsPerSecond
			-- SLOT 1 IS THE DEEPEST, and it is `firstSlotSeconds` of the line's walk short of the far
			-- edge -- so the roster's clock and the metronome's are one clock.
			local first = Placement.bedNorth(far, Data.slotSeconds(1, SCHEDULE), speed, near)
			expect(math.abs(first - (far - SCHEDULE.firstSlotSeconds * speed)) < 1e-9).to.equal(true)
			-- ...AND CONSECUTIVE SLOTS ARE ONE TEMPO APART, deepest first, for all fifteen rows.
			for slot = 2, #SCHEDULE.drive do
				local above = Placement.bedNorth(far, Data.slotSeconds(slot - 1, SCHEDULE), speed, near)
				local here = Placement.bedNorth(far, Data.slotSeconds(slot, SCHEDULE), speed, near)
				expect(above > here).to.equal(true)
				expect(math.abs((above - here) - CONFIG.bedSpacingStuds) < 1e-9).to.equal(true)
				expect(here >= near).to.equal(true)
			end
			-- THE FLOOR, AND THE SECOND RETURN IS WHAT SAYS IT BIT. Delete the `near` arm and a slot
			-- due at 10,000 s is bedded on the far side of the road.
			local bed, clamped = Placement.bedNorth(far, 10000, speed, near)
			expect(bed).to.equal(near)
			expect(clamped).to.equal(true)
			local _, untouched = Placement.bedNorth(far, 0, speed, near)
			expect(untouched).to.equal(false)
			-- A LINE THAT IS NOT WALKING MOVES NO BED: the far edge, not a divide.
			expect(Placement.bedNorth(far, 10, 0, near)).to.equal(far)
		end)

		it("keeps the tempo Karen accepted, at the live line speed and not the design's 3.1", function()
			-- THE ONE DERIVED CONSTANT (the Director, 2026-11-10 ~13:50): 13 s x 5.64 studs/s. Both
			-- owners' own numbers, so neither can move without this line failing.
			local speed = Grid.CONFIG.beaterWalkStudsPerSecond
			expect(Bots.CONFIG.WALK_SPEED).to.equal(speed)
			local want = Placement.bedSpacingStuds(SCHEDULE.intervalSeconds, speed)
			expect(math.abs(CONFIG.bedSpacingStuds - want) < 1e-9).to.equal(true)
			-- ...AND A PLANNED DRIVE DELIVERS IT: consecutive KEPT slots of a busy drive (every one of
			-- the fifteen fires) are one interval apart in the second the line reaches them.
			local rows = planAt("busy")
			for index = 2, #rows do
				local gap = rows[index].reachAtSeconds - rows[index - 1].reachAtSeconds
				expect(math.abs(gap - SCHEDULE.intervalSeconds) < 1e-6).to.equal(true)
			end
			TestKit.note(
				string.format(
					"placement tempo: %.2f studs per slot = %d s x %.2f studs/s; busy delivers %.2f s between groups",
					CONFIG.bedSpacingStuds,
					SCHEDULE.intervalSeconds,
					speed,
					rows[2].reachAtSeconds - rows[1].reachAtSeconds
				)
			)
		end)

		it("puts every planned bed inside the band, at every density", function()
			-- THE BAND `planAt` ACTUALLY PLANS IN: a cell's own muster, which is where every drive
			-- Karen plays musters (`Grid.CELLS[i].beaterNorthStuds = cellDepthStuds`).
			local layoutFar = Placement.bandFar(CELL_MUSTER, Data.noticeAheadStuds(SPOOK, nil), SPOOK)
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
			-- THE ROAD PLACE'S 580, K-1's 700, AND THE ONE EVERY DRIVE KAREN PLAYS MUSTERS AT -- a
			-- CELL's own depth, 1,430 (`Grid.CELLS[i].beaterNorthStuds = cellDepthStuds`).
			for _, beaterNorth in ipairs({ Data.beaterNorthStuds(), 700, CELL_MUSTER }) do
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
			-- ...AND THE FLOOR IS THE NEAR EDGE AND NOT A SEPARATE NUMBER: a slot whose moment is
			-- past the whole band beds on it, which is what the clamp's second return reports.
			expect(Placement.bedNorth(450, 1000, 5.64, near)).to.equal(near)
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
			-- A BAND WITH NO ROOM: one stud of lateral cap, and a tempo of one second puts the beds
			-- 5.64 studs apart in depth, which cannot hold a 71-stud gap -- so the plan must refuse
			-- rather than stack them.
			local schedule = table.clone(SCHEDULE)
			schedule.crossCapStuds = 1
			schedule.intervalSeconds = 1
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
			-- THE DEEPEST BED IS THE FIRST SLOT'S, and the line reaches it at the second the script
			-- says that slot moves -- which is the whole point of `bedNorth`'s one rule.
			expect(math.abs(deepest.reachAtSeconds - Data.slotSeconds(deepest.slot, SCHEDULE)) < 1e-6).to.equal(true)
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
			-- THE WAKE LEADS THE NOTICE BY HALF A BED SPREAD (T4), and the reason is measured: with
			-- no lead, 3 of 4 woken groups at C1 were already FLYING when `orderGroup` reached them
			-- (`345d-diag-mid.txt`: `flights=3 ordered=1`), because `spookNearBeaters` measures its
			-- band off each ANIMAL's live position and a member can stand half a spread in front of
			-- the bed point. A group that bolts instead of filing out cannot form a file at all.
			local lead = Placement.wakeLeadStuds(Placement.CONFIG)
			expect(lead).to.equal(Placement.CONFIG.bedSpreadStuds / 2)
			expect(Placement.wakeReason(row, 0, 450 + notice + lead, notice, lead)).to.equal("beaters")
			expect(Placement.wakeReason(row, 0, 450 + notice + lead + 1, notice, lead)).to.equal(nil)
			-- ...AND IT IS THE BED THAT WAS FOUND, NOT THE ONE THAT WAS PLANNED. `searchBand` may
			-- take a bed half a spread either side of the plan, so a row that has a body is judged
			-- where that body IS. Delete `row.atNorth` from `materialise` (or the `or` here) and a
			-- bed 20 studs shallower than its plan wakes 3.5 s late -- longer than the two-second
			-- stand that bolts it.
			local found = { state = "bedded", walker = false, wakeAtSeconds = math.huge, bedNorth = 450, atNorth = 430 }
			expect(Placement.wakeReason(found, 0, 430 + notice + lead, notice, lead)).to.equal("beaters")
			expect(Placement.wakeReason(found, 0, 450 + notice + lead, notice, lead)).to.equal(nil)
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

	-- =============================================== T2: THE ROSTER **IS** THE POPULATION
	describe("the owner's roster is the drive's population, behind the flag", function()
		it("plans a roster when the switch is on and nothing at all when it is off", function()
			-- A KNOWN CELL, so the dial and the schedule are that cell's and not whatever the last
			-- spec promoted. `layoutForDrive` is the one promoter and `forest_stand.spec` drives it
			-- the same way.
			Forest.layoutForDrive(951, "c1")
			-- OFF: NO ROSTER. Delete the `inPlace ~= true` guard in `ForestTest.planDrive` and this
			-- is the line that fails -- the flag would decide nothing and Karen's drive would change
			-- under her with the switch off.
			expect(Forest.planDrive(951, false)).to.equal(nil)
			expect(#Forest.roster()).to.equal(0)
			expect(Forest.placementStats().placed).to.equal(0)
			-- ON: the roster is the dial's rows, and the count is the one `Placement.plan` answers.
			local line = Forest.planDrive(951, true)
			expect(line ~= nil).to.equal(true)
			local rows = Forest.roster()
			expect(#rows > 0).to.equal(true)
			local planned = Placement.plan(
				951,
				Forest.cellSchedule(),
				Grid.animalsOf("c1"),
				REST,
				SPOOK,
				Data.beaterNorthStuds(Forest.layout()),
				Grid.CONFIG.beaterWalkStudsPerSecond,
				-- THE CONFIG THE OWNER ITSELF USED, which is `Boar.CONFIG` while no boar runtime
				-- exists (`ForestTest`'s own `boarConfig()`) -- and NOT this file's `FOREST`, whose
				-- deer cap is the one `ForestTestBoot` installs in the Forest Test. In the DEV place
				-- that boot does not run, so `FOREST` admits five deer rows the owner's own config
				-- refuses and the two plans would differ by five groups for a reason that is not
				-- placement's (measured: 13 against 8).
				Boar.CONFIG,
				Random.new(1),
				depsFor(Forest.layout())
			)
			-- THE SAME ROWS, SLOT FOR SLOT: the owner asks the pure half and copies nothing.
			expect(#rows).to.equal(#planned)
			for index, row in ipairs(rows) do
				expect(row.slot).to.equal(planned[index].slot)
				expect(math.abs(row.bedNorth - planned[index].bedNorth) < 1e-6).to.equal(true)
				-- NOTHING HAS A BODY YET: a record costs no instance and no millisecond.
				expect(row.state).to.equal("record")
				expect(#row.ids).to.equal(0)
			end
			expect(Forest.placementStats().placed).to.equal(#rows)
			expect(Forest.placementStats().bedded).to.equal(0)
			-- IDEMPOTENT PER DRIVE NUMBER: the once-a-second `Waiting` read plans once. Delete the
			-- `rosterDrive` key and a group already lying in the wood is re-planned every second.
			expect(Forest.planDrive(951, true)).to.equal(nil)
			expect(#Forest.roster()).to.equal(#rows)
			-- AND ONE SLOT IS FOUND BY ITS NUMBER, which is what the bridge below asks.
			expect(Forest.rosterSlot(rows[1].slot)).to.equal(rows[1])
			expect(Forest.rosterSlot(-7)).to.equal(nil)
			TestKit.note(string.format("placement owner: c1 drive 951 planned %s", Placement.line(rows)))
		end)

		it("never says the line finds a group whose bodies have gone", function()
			-- ROUND 2'S NOTE, the Director's round-3 instruction: a row that goes `gone` clears its
			-- ids, so `releaseLine`'s bridge -- which keys its two arms on `#row.ids` -- can never
			-- print "the line finds it" for a group that is not in the wood.
			local _made, _standing, fake = stubRuntime()
			Forest.layoutForDrive(955, "c1")
			Forest.start(fake, 0)
			Forest.newDrive(0)
			expect(Forest.planDrive(955, true) ~= nil).to.equal(true)
			local first = Forest.roster()[1]
			first.state = "bedded"
			first.ids = { "Boar1", "Boar2" }
			first.at = Vector3.new(0, 0, 0)
			-- `step` reconciles FIRST and releases second, which is the live ordering: the stub's
			-- `boars()` is empty, so those two bodies are gone by the time the slot fires.
			local line = Forest.step(Data.slotSeconds(1, Forest.cellSchedule()), true)
			-- THE STATE WORD, and the ids that must go with it. Delete `row.ids = {}` from
			-- `stepPlacement`'s reconcile and this line is the first that fails.
			expect(first.state).to.equal("gone")
			expect(#first.ids).to.equal(0)
			expect(line ~= nil).to.equal(true)
			expect(string.find(line :: string, "HELD BY THE ROSTER", 1, true) ~= nil).to.equal(true)
			expect(string.find(line :: string, "gone", 1, true) ~= nil).to.equal(true)
			-- ...AND THE SENTENCE THAT MUST NEVER BE PRINTED FOR IT.
			expect(string.find(line :: string, "the line finds it", 1, true)).to.equal(nil)
			Forest.start(nil :: any, 0)
		end)

		it("makes a body when the switch is on and nothing at all when it is off", function()
			-- ROUND 1, FINDING 2: with no runtime both states answered nil through the SAME arm, so
			-- deleting `inPlace ~= true` changed nothing. With the stub runtime installed the two
			-- states differ: ON reaches the materialise door and answers a line for the group it
			-- refused (there is no terrain in this place, so every bed search answers `nobed`), OFF
			-- answers nil before it reads anything at all.
			local _made, _standing2, fake = stubRuntime()
			Forest.layoutForDrive(954, "c1")
			Forest.start(fake, 0)
			Forest.newDrive(0)
			expect(Forest.planDrive(954, true) ~= nil).to.equal(true)
			expect(Forest.stepPlacement(0, false)).to.equal(nil)
			expect(Forest.stepPlacement(0, nil)).to.equal(nil)
			expect(Forest.placementStats().searches).to.equal(0)
			local line = Forest.stepPlacement(0, true)
			expect(line ~= nil).to.equal(true)
			expect(string.find(line :: string, "bed g954-s", 1, true) ~= nil).to.equal(true)
			expect(Forest.placementStats().searches > 0).to.equal(true)
			Forest.start(nil :: any, 0)
		end)
	end)

	-- =============================================== T3: "NEVER IN VIEW", AS A PREDICATE AND A COUNTER
	--
	-- `bedHidden` TAKES ITS EYES AS A PARAMETER, which is what makes it drivable here: the distance
	-- arm is hand-written points, and the ray arm is a real raycast over real geometry this case
	-- builds and destroys. The DEV place has no terrain, so `bedSpot` answers `nobed` before it ever
	-- reaches the predicate (the T2 case above says so) -- the live wiring is measured in the Forest
	-- Test, and what is asserted here is the rule, the order, the counters and the refusal's words.
	describe("nothing is created where a player can see it", function()
		it("refuses inside the reach by arithmetic, before it spends a ray", function()
			local spot = Vector3.new(0, 0, 0)
			local before = Forest.placementStats().rays
			-- THE DISTANCE ARM IS `Placement.clearOfEyes` AND NOTHING ELSE: replace that function
			-- with `return true` and this case is the first that fails (lesson L-093).
			local hidden, why = Forest.bedHidden(spot, { { name = "Hunter", at = Vector3.new(0, 0, 100) } })
			expect(hidden).to.equal(false)
			expect(why ~= nil).to.equal(true)
			expect(string.find(why :: string, "within", 1, true) ~= nil).to.equal(true)
			expect(string.find(why :: string, "Hunter", 1, true) ~= nil).to.equal(true)
			-- THE ORDER IS THE BUDGET (design 6.2): a spot the arithmetic refuses costs NO ray.
			expect(Forest.placementStats().rays).to.equal(before)
			-- ...AND AN EYE EXACTLY AT THE REACH IS PAST THE ARITHMETIC: the refusal changes its
			-- words and a ray is spent, which is how the two halves agree on the boundary.
			-- MEASURED: over the open DEV arena that ray then answers "seen", so the ASSERTION is
			-- the arm that refused and not the verdict.
			local never = Placement.neverStuds(SPOOK)
			local _atEdge, edgeWhy = Forest.bedHidden(spot, { { name = "Hunter", at = Vector3.new(0, 0, never) } })
			-- `nil` when the ray answers "hidden", which is what a place with ground under this spot
			-- would give: either way the ARITHMETIC let it through, which is the assertion.
			expect(edgeWhy == nil or string.find(edgeWhy :: string, "within", 1, true) == nil).to.equal(true)
			expect(Forest.placementStats().rays).to.equal(before + 1)
		end)

		it("spends one ray per eye, and calls a bed in clear air SEEN", function()
			-- A POINT NOBODY IS NEAR, so the distance arm passes and the ray decides. High in the
			-- air over the DEV arena: nothing is between these two points.
			local spot = Vector3.new(0, 600, 0)
			local eye = { name = "Hunter", at = Vector3.new(0, 600, 400) }
			local before = Forest.placementStats().rays
			local hidden, why = Forest.bedHidden(spot, { eye })
			-- DELETE THE RAY LOOP FROM `bedHidden` AND THIS IS THE LINE THAT FAILS: with only the
			-- distance arm a bed 400 studs away down an open lane reads "hidden" (lesson L-093).
			expect(hidden).to.equal(false)
			expect(string.find(why :: string, "in sight of Hunter", 1, true) ~= nil).to.equal(true)
			expect(Forest.placementStats().rays).to.equal(before + 1)
			-- ...AND ONE RAY PER EYE, never one per candidate (design 6.2). The FIRST eye is given a
			-- screen, so the loop has to reach the second to answer at all -- without it the first
			-- eye's "seen" returns early and a count of 2 would prove nothing (round 1, note).
			local screen = Instance.new("Part")
			screen.Name = "ForestPlacementSpecScreen"
			screen.Anchored = true
			screen.CanCollide = true
			screen.Size = Vector3.new(60, 60, 4)
			screen.CFrame = CFrame.new(0, 600, 200)
			screen.Parent = workspace
			local two, twoWhy = Forest.bedHidden(spot, { eye, { name = "Second", at = Vector3.new(0, 600, -400) } })
			screen:Destroy()
			expect(Forest.placementStats().rays).to.equal(before + 3)
			expect(two).to.equal(false)
			expect(string.find(twoWhy :: string, "in sight of Second", 1, true) ~= nil).to.equal(true)
		end)

		it("calls the same bed HIDDEN behind something a bullet would stop", function()
			local spot = Vector3.new(0, 600, 0)
			local eye = { name = "Hunter", at = Vector3.new(0, 600, 400) }
			local wall = Instance.new("Part")
			wall.Name = "ForestPlacementSpecWall"
			wall.Anchored = true
			wall.CanCollide = true
			wall.Size = Vector3.new(60, 60, 4)
			wall.CFrame = CFrame.new(0, 600, 200)
			wall.Parent = workspace
			local body = Instance.new("Model")
			body.Name = "ForestPlacementSpecBody"
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = body
			-- BOTH PATHS, because a failing assert in between would leave a 60-stud wall standing in
			-- the arena for every case after this one (round 1, note).
			local ok, why = pcall(function()
				-- THE SCREEN IS THE WHOLE DIFFERENCE between this case and the one above: one part
				-- between the eye and the bed, and the same two points answer the other way.
				expect(Forest.bedHidden(spot, { eye })).to.equal(true)
				-- A CHARACTER IS NOT A SCREEN (`Data.characterOf`, `restSeenFromLane`'s own rule):
				-- the same wall inside a character hides nothing. Built with a Humanoid, because
				-- that is what `Data.characterOf` looks for.
				wall.Parent = body
				body.Parent = workspace
				expect(Forest.bedHidden(spot, { eye })).to.equal(false)
			end)
			body:Destroy()
			wall:Destroy()
			if not ok then
				error(why, 0)
			end
		end)

		it("counts a body born in view, over the bodies that were really made", function()
			-- THE AUDIT (design 12.2). `bedHidden` tests ONE point; `spawnSounder` spreads a group
			-- over 40 studs, so the count that matters is taken over the bodies' OWN positions after
			-- the spawn. Driven with a stub runtime that reports where it put them, and with
			-- `bedSpot` replaced -- the DEV place has no ground for the real searcher to find.
			local eyes = Forest.eyes()
			local realBedSpot = Forest.bedSpot
			local placed = Vector3.new(0, 900, 0)
			local fake = {
				setField = function() end,
				clear = function() end,
				count = function()
					return 0
				end,
				capacity = function()
					return Data.MAX_BOARS
				end,
				liveCount = function()
					return 0
				end,
				boars = function()
					return {}
				end,
				statusOf = function()
					return { alive = true, position = placed }
				end,
				config = function()
					return Boar.CONFIG
				end,
				deerAllowed = function()
					return true
				end,
				formSounder = function() end,
				spawn = function()
					return { id = "specBoar" }
				end,
				spawnSounder = function(_self, _at, size)
					local out = {}
					for index = 1, size do
						table.insert(out, { id = string.format("specBoar%d", index) })
					end
					return out
				end,
			}
			Forest.layoutForDrive(957, "c1")
			Forest.start(fake :: any, 0)
			Forest.newDrive(0)
			expect(Forest.planDrive(957, true) ~= nil).to.equal(true)
			local row = Forest.roster()[1]
			local ok, why = pcall(function()
				-- FAR FROM EVERY EYE: the bodies are made and nothing is in view.
				local far = Vector3.new(0, 20000, 0)
				Forest.bedSpot = function()
					return far, nil, nil
				end
				placed = far
				local before = Forest.placementStats().inView
				local made = Forest.materialise(row, 0)
				expect(made).to.equal(true)
				expect(Forest.placementStats().inView).to.equal(before)
				-- ...AND NOW THE BODIES LAND ON TOP OF A PLAYER'S HEAD. Every one of them is counted,
				-- which is what makes `inView` a measurement of the spawn and not of the plan: delete
				-- the audit loop in `materialise` and this is the line that fails (lesson L-093).
				if #eyes > 0 then
					local second = Forest.roster()[2]
					placed = eyes[1].at
					second.state = "record"
					local okTwo = Forest.materialise(second, 0)
					expect(okTwo).to.equal(true)
					expect(Forest.placementStats().inView >= before + 1).to.equal(true)
					TestKit.note(
						string.format(
							"placement audit: %d bodies counted in view of %s",
							Forest.placementStats().inView - before,
							eyes[1].name
						)
					)
				else
					TestKit.note("placement audit: no player had a character, so the in-view arm was not driven")
				end
			end)
			-- Restored on both paths, for the reason the ledger case below gives.
			Forest.bedSpot = realBedSpot
			Forest.start(nil :: any, 0)
			if not ok then
				error(why, 0)
			end
		end)

		it("refuses a bed a player can see, raises `rays` and writes `inview` into the ledger", function()
			-- ROUND 1, FINDING 1. The SEARCHER is stubbed and `bedSpot` is the real one, so the whole
			-- T3 path runs: the band, the gap, `bedHidden`'s two arms and `stepPlacement`'s ledger.
			-- Delete the ray loop from `bedHidden` and the second half reds (the bed is accepted);
			-- replace `Placement.clearOfEyes` with `return true` and the first half reds (a bed ten
			-- studs from a player's head costs a ray and is refused with the wrong words).
			--
			-- IT NEEDS A REAL EYE, which in a gated Studio run is the harness's own player.
			local eyes = Forest.eyes()
			if #eyes == 0 then
				TestKit.note("placement ledger: no player had a character, so the in-view path was not driven")
				return
			end
			local eye = eyes[1]
			local realRestSpot = Forest.restSpot
			local _made, _standing, fake = stubRuntime()
			Forest.layoutForDrive(958, "c1")
			Forest.start(fake, 0)
			Forest.newDrive(0)
			expect(Forest.planDrive(958, true) ~= nil).to.equal(true)
			-- Past the second the line reaches every bed: a refusal that is this instant's is retried
			-- until then, and only then becomes a skip (`stepPlacement`'s own rule).
			local late = 1e6
			local ok, why = pcall(function()
				-- ONE: A BED TEN STUDS FROM HIS HEAD. The arithmetic refuses it and NO ray is spent.
				Forest.restSpot = function()
					return eye.at + Vector3.new(0, 10, 0)
				end
				local raysBefore = Forest.placementStats().rays
				local near = Forest.stepPlacement(late, true)
				expect(near ~= nil).to.equal(true)
				expect(string.find(near :: string, "SKIPPED", 1, true) ~= nil).to.equal(true)
				expect(string.find(near :: string, "inview", 1, true) ~= nil).to.equal(true)
				expect(string.find(near :: string, "within", 1, true) ~= nil).to.equal(true)
				expect(string.find(near :: string, eye.name, 1, true) ~= nil).to.equal(true)
				expect(Forest.placementStats().rays).to.equal(raysBefore)
				expect((Forest.placementStats().skips.inview or 0) >= 1).to.equal(true)
				-- TWO: A BED WELL OUTSIDE THE REACH, IN CLEAR AIR. The arithmetic passes it, the RAY
				-- refuses it, and both the counter and the ledger move.
				Forest.restSpot = function()
					return eye.at + Vector3.new(0, 600, 0)
				end
				local seen = Forest.stepPlacement(late, true)
				expect(seen ~= nil).to.equal(true)
				expect(string.find(seen :: string, "inview", 1, true) ~= nil).to.equal(true)
				expect(string.find(seen :: string, "in sight of " .. eye.name, 1, true) ~= nil).to.equal(true)
				expect(Forest.placementStats().rays > raysBefore).to.equal(true)
				expect((Forest.placementStats().skips.inview or 0) >= 2).to.equal(true)
				TestKit.note(string.format("placement ledger: %s", seen :: string))
			end)
			-- RESTORED ON BOTH PATHS: a failing assert that left the owner's bed searcher stubbed
			-- would poison `forest_stand.spec` and `forest_line.spec` behind it (round 1, note).
			Forest.restSpot = realRestSpot
			Forest.start(nil :: any, 0)
			if not ok then
				error(why, 0)
			end
		end)

		it("publishes the two counters a drive is read by", function()
			-- `rays` AND `inView` ARE PUBLISHED TOGETHER, deliberately (design 12.3): a drive that
			-- reports `inView = 0` with `rays = 0` has not tested anything.
			-- THE COUNTERS ARE PER DRIVE and `planDrive` zeroes them, which is why this case spends
			-- its own ray instead of reading what an earlier case left behind (MEASURED: the cases
			-- above plan three drives, so the tally here was 0).
			local zeroed = Forest.placementStats()
			expect(type(zeroed.rays)).to.equal("number")
			expect(type(zeroed.inView)).to.equal("number")
			Forest.bedHidden(Vector3.new(0, 600, 0), { { name = "Hunter", at = Vector3.new(0, 600, 400) } })
			local stats = Forest.placementStats()
			expect(stats.rays > zeroed.rays).to.equal(true)
			-- ...AND THE MARGIN THAT MAKES THE CLIENT SPEC VALID, as a statement (design 7.3): the
			-- reach is well inside the place's documented `StreamingMinRadius` 384, so an arrival
			-- inside it cannot be the engine streaming a bed in.
			expect(Placement.neverStuds(SPOOK) < 384).to.equal(true)
		end)
	end)

	-- ======================================= T4: `releaseLine` STOPS SPAWNING; `orderGroup` ORDERS
	--
	-- Karen, 2026-11-10: *"it has to be there then it spooked or it walkks towards"*. These cases are
	-- about the two halves of that sentence: nothing is created for a scheduled slot any more, and a
	-- group that wakes is handed its own route from where it is standing.
	--
	-- WHAT THIS PLACE CANNOT DO is compute a route: `PathfindingService` has no navigable ground in
	-- the DEV place, so `ForestTest.computeRouteVia` answers nil and `orderGroup` gets as far as
	-- "noroute". That is stated rather than worked around -- the FILE itself is measured live in her
	-- Forest Test (the request's claim 4) -- and what is asserted here is every rule around it: who
	-- is ordered and who is not, that the pathfinder is asked ONCE, the trail's arithmetic, and the
	-- retry cap over more than one wake cycle.
	describe("a bedded group is handed its route and nothing is spawned for its slot", function()
		it("seeds the trail behind the leader along the way it is about to walk", function()
			-- DESIGN 4.6'S ONE NAMED TECHNICAL RISK, as arithmetic. A woken group stands in a loose
			-- bed, not in a file, so station k must EXIST on the first step: with an empty trail
			-- `Line.pointBack` answers nil and every follower is told "walk at the leader", which
			-- task 127 measured as a 9.6-stud median against a 3-stud station.
			local origin = Vector3.new(100, 10, -200)
			local toward = Vector3.new(0, 0, -1) -- south, the road
			local spacing = Data.LINE.spacingStuds
			local trail = Placement.seedTrail(origin, toward, 4, spacing)
			expect(#trail > 1).to.equal(true)
			-- THE HEAD IS THE LEADER'S OWN FEET: the last point is where she is standing.
			local head = trail[#trail]
			expect((head.at - origin).Magnitude < 1e-6).to.equal(true)
			-- ...AND EVERY OTHER POINT IS BEHIND HER ALONG THE WAY SHE WILL WALK (north here), never
			-- in front. Seed it forwards and the file is ordered into the ground it has not reached.
			for index = 1, #trail - 1 do
				expect(trail[index].at.Z > origin.Z).to.equal(true)
			end
			-- `s` IS CUMULATIVE AND RISING, which is what `Line.arcAt` and `Line.pointAt` read.
			expect(trail[1].s).to.equal(0)
			for index = 2, #trail do
				expect(trail[index].s > trail[index - 1].s).to.equal(true)
			end
			-- AND IT IS LONG ENOUGH TO HOLD EVERY STATION: rank k stands (k - 1) x spacing behind the
			-- head, so a trail shorter than that is a station that does not exist yet. Delete the
			-- `+ 1` or the `members` term from `Placement.seedTrail` and this line fails.
			expect(trail[#trail].s >= 4 * spacing).to.equal(true)
			-- A FIRST LEG THAT IS NOT AN AXIS IS THE NORMAL CASE (a crossing is off to one side), and
			-- the seed follows the leg and not the compass.
			local slant = Placement.seedTrail(origin, Vector3.new(3, 0, -4), 2, spacing)
			local back = slant[1].at - origin
			expect(math.abs(back.Unit:Dot(Vector3.new(-0.6, 0, 0.8)) - 1) < 1e-3).to.equal(true)
			-- A DEGENERATE LEG (the route's first point under her feet) falls back to south rather
			-- than dividing by zero.
			local flat = Placement.seedTrail(origin, Vector3.new(0, 5, 0), 2, spacing)
			expect(flat[1].at.Z > origin.Z).to.equal(true)
			TestKit.note(
				string.format("T4 seed: %d points, %.1f studs for 4 members at %.1f", #trail, trail[#trail].s, spacing)
			)
		end)

		it("judges a file five seconds after it was ordered, and keeps the two kinds apart", function()
			-- THE INSTRUMENT ITSELF (design 12.1, core protocol 0(e)): one reading per file, taken
			-- once, at the first step past `fileFormedSeconds`, over the members still in it. Both
			-- sides go through it -- a WOKEN file and a RELEASED one -- so the measurement cannot be
			-- the thing that differs between them.
			local _made, _standing, fake = stubRuntime()
			Forest.layoutForDrive(960, "c1")
			Forest.start(fake, 0)
			local function body(z: number)
				return { status = { position = Vector3.new(0, 0, z) } }
			end
			-- THREE ANIMALS 10 STUDS APART: two gaps of 10, so the median is 10.
			local woken = { id = "g960-s1-f1", bornAt = 0, woken = true }
			Forest.measureFile(woken, { body(0), body(-10), body(-20) }, 4.9)
			-- BEFORE THE WINDOW, NOTHING IS WRITTEN. Delete the `fileFormedSeconds` guard and a file
			-- is judged on the step it was born, when nobody has walked anywhere.
			expect(Forest.fileGaps().woken.files).to.equal(0)
			Forest.measureFile(woken, { body(0), body(-10), body(-20) }, 5.1)
			local gaps = Forest.fileGaps()
			expect(gaps.woken.files).to.equal(1)
			expect(math.abs(gaps.woken.median - 10) < 1e-6).to.equal(true)
			expect(math.abs(gaps.woken.worst - 10) < 1e-6).to.equal(true)
			-- ONCE PER FILE: a second call on the same line is not a second reading.
			Forest.measureFile(woken, { body(0), body(-40), body(-80) }, 9)
			expect(Forest.fileGaps().woken.files).to.equal(1)
			-- ...AND A RELEASED FILE IS THE CONTROL, in its own digest and never in the woken one.
			Forest.measureFile({ id = "line-1-1", bornAt = 0 }, { body(0), body(-30) }, 6)
			local both = Forest.fileGaps()
			expect(both.woken.files).to.equal(1)
			expect(both.released.files).to.equal(1)
			expect(math.abs(both.released.median - 30) < 1e-6).to.equal(true)
			-- A FILE OF ONE HAS NO GAP TO READ, and reads as nothing rather than as zero.
			Forest.measureFile({ id = "g960-s2-f1", bornAt = 0, woken = true }, { body(0) }, 9)
			expect(Forest.fileGaps().woken.files).to.equal(1)
			-- THE TARGET IS `2 x LINE.spacingStuds` AND IT IS THE LINE OWNER'S NUMBER, not a literal
			-- here: 8.5 -> 17. Move `spacingStuds` and the target moves with it.
			expect(2 * Data.LINE.spacingStuds).to.equal(17)
			expect(Placement.CONFIG.fileFormedSeconds).to.equal(5)
			Forest.start(nil :: any, 0)
		end)

		it("orders a woken group once, counts a group the fright already took, and spawns nothing", function()
			local made, standing, fake, where = stubRuntime()
			Forest.layoutForDrive(961, "c1")
			Forest.start(fake, 0)
			Forest.newDrive(0)
			expect(Forest.planDrive(961, true) ~= nil).to.equal(true)
			local row = Forest.roster()[1]
			expect(row ~= nil).to.equal(true)
			-- A GROUP LYING IN ITS BED WITH TWO BODIES ON THEIR FEET, 12 studs apart.
			row.state = "bedded"
			row.ids = { "Boar1", "Boar2" }
			row.at = Vector3.new(0, 0, -300)
			table.insert(standing, "Boar1")
			table.insert(standing, "Boar2")
			where.Boar1 = { at = Vector3.new(0, 0, -300), kind = "female" }
			where.Boar2 = { at = Vector3.new(6, 0, -288), kind = "cub" }
			-- THE FRIGHT HAS ALREADY TAKEN BOTH OF THEM: they are AWAKE AS A FLIGHT (design 4.1's
			-- other legal shape) and the drive does NOT order a flying animal -- that is the one-owner
			-- boundary `stepLines` keeps and `Runtime:flying` is the Brain's answer. Delete the
			-- `flying` guard in `orderGroup` and this is the line that fails: the reason becomes
			-- "noroute" and `flights` stays 0.
			where.Boar1.flying = true
			where.Boar2.flying = true
			local line, why = Forest.orderGroup(row, 0)
			expect(line).to.equal(nil)
			expect(why).to.equal("flight")
			expect(Forest.placementStats().flights).to.equal(1)
			expect(#made).to.equal(0)
			-- ON THEIR FEET, THE SAME CALL REACHES THE ROUTE and gets as far as this place can go:
			-- no navmesh, so no route, and the group stays where it lay -- which is reported, not
			-- hidden.
			where.Boar1.flying = false
			where.Boar2.flying = false
			local _again, why2 = Forest.orderGroup(row, 0)
			expect(why2).to.equal("noroute")
			expect(Forest.placementStats().noroute).to.equal(1)
			-- AND STILL NOT ONE ANIMAL IS CREATED. `orderGroup` has no `spawn` call at all.
			expect(#made).to.equal(0)
			-- THE PATHFINDER IS ASKED FOUR TIMES PER GROUP AT MOST, FOUR SECONDS APART, and never
			-- once per Heartbeat. `stepPlacement` writes the try count and the next-try clock BEFORE
			-- the attempt, so a group in a dead end costs four routes in a drive and not fifteen a
			-- second; and FOUR rather than one because the commonest refusal is a fright that is
			-- holding the group right now (the horn reaches 357 studs) and a flight ends. Delete the
			-- clock and `noroute` grows with every step below; delete the counter and it never stops.
			row.state = "awake"
			row.lineId = nil
			row.orderTries = nil
			row.orderNextAt = nil
			local first = Forest.stepPlacement(1, true)
			expect(first ~= nil).to.equal(true)
			expect(string.find(first :: string, "NOT ordered", 1, true) ~= nil).to.equal(true)
			expect(row.orderTries).to.equal(1)
			local before = Forest.placementStats().noroute
			-- A WHOLE SECOND OF HEARTBEATS AT 60 Hz, inside the retry window: not one more route.
			for step = 1, 60 do
				Forest.stepPlacement(1 + step / 60, true)
			end
			expect(Forest.placementStats().noroute).to.equal(before)
			-- ...AND SIXTY SECONDS OF THEM COST THE THREE THAT ARE LEFT, AND THEN NOTHING FOR EVER.
			for step = 1, 600 do
				Forest.stepPlacement(2 + step / 10, true)
			end
			expect(row.orderTries).to.equal(4)
			expect(Forest.placementStats().noroute).to.equal(before + 3)
			Forest.start(nil :: any, 0)
		end)

		it("makes the file itself: one line, in march order, trailed from the leader's own feet", function()
			-- ROUND 1, FINDING 1, WHICH WAS RIGHT: every other case in this file asserts a REFUSAL,
			-- so the whole half the task was written to build -- `Line.order`/`Line.split`, the
			-- `state.lines` row, the seeded trail, the `woken` tag, `row.lineId` -- could be deleted
			-- and they would all still pass. The DEV place has no navmesh, so the only way to drive
			-- it here is to hand `orderGroup` a route: `routeFilesFor` asks
			-- `ForestTest.computeRouteVia` through the module table, which is the same patch point
			-- the retry-cap case uses for `bedSpot`.
			local _made, standing, fake, where = stubRuntime()
			Forest.layoutForDrive(962, "c1")
			Forest.start(fake, 0)
			Forest.newDrive(0)
			expect(Forest.planDrive(962, true) ~= nil).to.equal(true)
			local row = Forest.roster()[1]
			row.state = "awake"
			row.ids = { "Boar1", "Boar2", "Boar3" }
			row.at = Vector3.new(0, 0, -900)
			row.lineId = nil
			-- THE BODIES ARE NOT AT THE BED AND NOT IN A FILE: a group lying up has drifted over its
			-- graze repertoire, which is the whole reason the route starts at the LEADER'S FEET.
			-- The march leader (`Boar.MARCH_RANK`: a sow leads) is deliberately NOT the foremost
			-- animal, so a file built off position alone would put the wrong one at the head.
			local leaderAt = Vector3.new(20, 0, -830)
			where.Boar1 = { at = Vector3.new(-6, 0, -860), kind = "male" }
			where.Boar2 = { at = leaderAt, kind = "female" }
			where.Boar3 = { at = Vector3.new(9, 0, -845), kind = "cub" }
			for _, id in ipairs(row.ids) do
				table.insert(standing, id)
			end
			-- THE LADDER OF STARTS (`ORDER_START_STUDS` = 0, 30, 60, 90), measured in the Forest Test
			-- because the pathfinder answers `NoPath` from a bed: the first two candidates are
			-- refused here and the third is taken, so the case fails if the ladder is replaced by a
			-- single try.
			local realVia = Forest.computeRouteVia
			local asked = {}
			Forest.computeRouteVia = function(via)
				table.insert(asked, via[1])
				if #asked < 3 then
					return nil
				end
				local out = {}
				for _, point in ipairs(via) do
					table.insert(out, point)
				end
				return out
			end
			local line, why = Forest.orderGroup(row, 11)
			Forest.computeRouteVia = realVia
			expect(why).to.equal(nil)
			expect(line ~= nil).to.equal(true)
			expect(string.find(line :: string, "3 animal(s)", 1, true) ~= nil).to.equal(true)
			expect(string.find(line :: string, "from its BED", 1, true) ~= nil).to.equal(true)
			-- THE STARTS THAT WERE OFFERED: the leader's own feet, then 30 studs along the way out,
			-- then 60 -- which is the one that was taken.
			-- FLAT, because the ladder walks along the ground and each candidate's HEIGHT is
			-- `Data.groundAt`'s answer at that point -- which is the other half of the same measured
			-- fix (the body's own Y is what the pathfinder refuses).
			local function flat(a: Vector3, b: Vector3)
				return (Vector3.new(a.X - b.X, 0, a.Z - b.Z)).Magnitude
			end
			expect(#asked).to.equal(3)
			expect(flat(asked[1], leaderAt) < 1e-3).to.equal(true)
			expect(math.abs(flat(asked[2], leaderAt) - 30) < 1e-3).to.equal(true)
			expect(math.abs(flat(asked[3], leaderAt) - 60) < 1e-3).to.equal(true)
			-- ONE FILE, AND IT IS THE ROSTER ROW'S.
			local lines = Forest.lines()
			expect(#lines).to.equal(1)
			local file = lines[1]
			expect(row.lineId).to.equal(file.id)
			expect(file.id).to.equal(row.id .. "-f1")
			expect(Forest.placementStats().ordered).to.equal(1)
			-- ...TAGGED AS WOKEN, which is what keeps the measurement honest: without the tag a file
			-- that got up out of a bed would be counted in the RELEASED control and claim 3 would be
			-- reading the wrong population.
			expect(file.woken).to.equal(true)
			-- ...IN MARCH ORDER, the ANIMAL owner's fact: the sow is at the head although she is the
			-- rearmost body on the ground.
			expect(#file.members).to.equal(3)
			expect(file.members[1].id).to.equal("Boar2")
			expect(file.members[1].kind).to.equal("female")
			-- ...AND TRAILED FROM HER OWN FEET, BACKWARDS ALONG THE FIRST LEG. The head of the trail
			-- is where she is standing NOW, never the bed the plan wrote (70 studs away here), and
			-- every other point is behind her, so station k exists on the first step.
			expect(#file.trail > 1).to.equal(true)
			local head = file.trail[#file.trail].at
			expect((head - leaderAt).Magnitude < 1e-3).to.equal(true)
			expect((head - (row.at :: Vector3)).Magnitude > 50).to.equal(true)
			expect(file.trail[#file.trail].s > 3 * Data.LINE.spacingStuds).to.equal(true)
			-- ...WITH THE PINS THE DRIVE CHOSE, which is what a stuck leader is re-pathed through.
			expect(#file.pins > 0).to.equal(true)
			expect(file.speed > 0).to.equal(true)
			expect(type(file.pace)).to.equal("string")
			expect(file.bornAt).to.equal(11)
			-- AND THE INSTRUMENT READS IT AS A WOKEN FILE, not as the control.
			local before = Forest.fileGaps().woken.files
			Forest.measureFile(file, {
				{ status = { position = Vector3.new(0, 0, 0) } },
				{ status = { position = Vector3.new(0, 0, -9) } },
			}, 11 + Placement.CONFIG.fileFormedSeconds + 0.1)
			expect(Forest.fileGaps().woken.files).to.equal(before + 1)
			expect(Forest.fileGaps().released.files).to.equal(0)
			Forest.start(nil :: any, 0)
			TestKit.note(string.format("T4 file: %s, %d members, trail %.1f studs", file.id, #file.members, head.Y))
		end)

		it("releases nothing for a scheduled slot the switch owns, whether or not it has a body", function()
			-- THE BRIDGE IS GONE (design 4.6; `backups/2026-11-11_task-345d_release-line-bridge.md`).
			-- T2 still SPAWNED a group the wood had refused a bed to; a group with no legal bed is now
			-- a HOLE IN THE WOOD and is reported (design 4.3), because spawning it 25 studs off the
			-- road is the magic appearance Karen's *"not just apear magically"* is about.
			local made, standing, fake = stubRuntime()
			Forest.layoutForDrive(953, "c1")
			Forest.start(fake, 0)
			Forest.newDrive(0)
			expect(Forest.planDrive(953, true) ~= nil).to.equal(true)
			local first = Forest.roster()[1]
			expect(first ~= nil).to.equal(true)
			-- ITS GROUP IS LYING IN ITS BED: the slot releases nothing and says whose it is.
			first.state = "bedded"
			first.ids = { "Boar1", "Boar2" }
			first.at = Vector3.new(0, 0, 0)
			table.insert(standing, "Boar1")
			table.insert(standing, "Boar2")
			table.clear(made)
			local held = Forest.step(Data.slotSeconds(1, Forest.cellSchedule()), true)
			expect(held ~= nil).to.equal(true)
			expect(string.find(held :: string, "THE ROSTER'S", 1, true) ~= nil).to.equal(true)
			expect(string.find(held :: string, "the line finds it", 1, true) ~= nil).to.equal(true)
			expect(#made).to.equal(0)
			-- ...AND A ROW THE **WOOD** REFUSED IS NOT RELEASED EITHER, which is the whole of T4's
			-- first half. THE BITE: restore the T2 bridge (`and not Placement.bridgeMustRelease(...)`)
			-- and this call falls through to the old spawn path, which answers **nil** in this place
			-- (no navmesh, so `#routes == 0`) -- so both of the next two lines fail.
			Forest.newDrive(0)
			local refused = Forest.roster()[1]
			refused.state = "record"
			refused.ids = {}
			refused.skipped = "nobed"
			local hole = Forest.step(Data.slotSeconds(1, Forest.cellSchedule()), true)
			expect(hole ~= nil).to.equal(true)
			expect(string.find(hole :: string, "nothing is released for this slot", 1, true) ~= nil).to.equal(true)
			expect(string.find(hole :: string, "nobed", 1, true) ~= nil).to.equal(true)
			expect(#made).to.equal(0)
			-- ...AND WITH THE SWITCH OFF THE SAME SLOT IS THE OLD PATH AND SAYS NOTHING ABOUT A ROSTER.
			-- MEASURED: it answers nil here, for the same missing navmesh.
			Forest.newDrive(0)
			local plain = Forest.step(Data.slotSeconds(1, Forest.cellSchedule()), false)
			expect(plain == nil or string.find(plain :: string, "ROSTER", 1, true) == nil).to.equal(true)
			Forest.start(nil :: any, 0)
		end)

		it("parks a row that has spent its searches, and the drive wakes it once more", function()
			-- THE DIRECTOR'S RETRY CAP, 2026-11-11 ~04:55: A2 spent **~2,940 ring searches re-trying
			-- three `inview` refusals** in one drive. Three searches per row, then the row is PARKED
			-- -- still a record, not skipped -- and one more window is opened when the drive actually
			-- wants the group.
			--
			-- L-142, AND IT IS THE WHOLE POINT OF THE CASE: a bounded self-repair that LOSES the row
			-- is the "it has to be there" bug in a new form. So this drives TWO wake cycles in one
			-- drive and asserts the row ends up with a body.
			local _made, _standing, fake = stubRuntime()
			Forest.layoutForDrive(959, "c1")
			Forest.start(fake, 0)
			Forest.newDrive(0)
			expect(Forest.planDrive(959, true) ~= nil).to.equal(true)
			-- ONE ROW IN PLAY, so the counters are about it and not about twelve others.
			local rows = Forest.roster()
			local row = rows[1]
			for index = #rows, 2, -1 do
				table.remove(rows, index)
			end
			-- ITS SLOT CLOCK IS AT 2 s AND THE LINE IS 40 s AWAY, so the reopen below is the CLOCK's
			-- arm and the refusal never becomes final inside the window being measured (a refusal
			-- past `reachAtSeconds` ends the row's drive, which is the other rule and has its own
			-- case).
			row.walker = true
			row.wakeAtSeconds = 2
			row.reachAtSeconds = 40
			-- THE WOOD SAYS "SOMEBODY IS LOOKING AT IT" EVERY TIME, which is the refusal that is a
			-- fact about THIS INSTANT and is therefore re-tried -- the one the cap bounds.
			local realBedSpot = Forest.bedSpot
			local asks = 0
			local giveIn = math.huge
			Forest.bedSpot = function(_row)
				asks += 1
				if asks >= giveIn then
					return Vector3.new(0, 0, -300), nil, nil
				end
				return nil, "inview", "a player is looking at it (spec)"
			end
			for step = 1, 12 do
				Forest.stepPlacement(step * 0.1, true)
			end
			-- THREE SEARCHES AND THEN SILENCE. Delete the cap arm from `Placement.dueNow` (or the
			-- `searchesSpent` increment in `materialise`) and `asks` is 12 here, not 3.
			expect(asks).to.equal(3)
			expect(Forest.placementStats().caps).to.equal(1)
			-- PARKED, NOT SKIPPED: the row is still a record and still in the drive.
			expect(row.state).to.equal("record")
			expect(row.skipped).to.equal(nil)
			expect(Placement.dueNow(row, 1.2, Placement.CONFIG.leadSeconds, Placement.CONFIG.searchesPerWake)).to.equal(
				false
			)
			-- CYCLE TWO: its slot clock comes, the window reopens ONCE, and this time the wood says
			-- yes on the second search -- so the row reaches the hunt with a body before the drive
			-- ends. Delete `Placement.reopenNow`'s call in `stepPlacement` and the row is lost here:
			-- `asks` stays 3 and the row never beds.
			giveIn = 5
			for step = 1, 12 do
				Forest.stepPlacement(2 + step * 0.1, true)
			end
			expect(Forest.placementStats().reopens).to.equal(1)
			expect(asks).to.equal(5)
			expect(row.state).to.equal("bedded")
			expect(#row.ids > 0).to.equal(true)
			-- ONE REOPEN PER ROW PER DRIVE, so the cap cannot be re-armed for ever: 3 + 3 = 6 searches
			-- is the bound the arithmetic in `CONFIG.searchesPerWake` is written against.
			expect(Placement.reopenNow(row, 99, nil, 100, Placement.CONFIG.searchesPerWake)).to.equal(nil)
			Forest.bedSpot = realBedSpot
			Forest.start(nil :: any, 0)
			TestKit.note(string.format("T4 retry cap: %d searches over two wake cycles, one reopen", asks))
		end)

		it("reopens on the beaters as well as on the clock, and never for a skipped row", function()
			-- THE TWO SIGNALS THAT MEAN "NOW", as arithmetic (`Placement.reopenNow`). The geometry arm
			-- is the same one `wakeReason` uses -- the line's notice band reaching the bed -- so a
			-- group the line has walked up to gets its last window whatever the clock says.
			local cap = Placement.CONFIG.searchesPerWake
			local function parked(extra: any?)
				local row = {
					state = "record",
					bedNorth = 300,
					wakeAtSeconds = math.huge,
					reachAtSeconds = 20,
					searchesSpent = cap,
				}
				for key, value in pairs(extra or {}) do
					row[key] = value
				end
				return row
			end
			-- NOT YET: the front is 140 studs north of the bed and the notice band is 100.
			expect(Placement.reopenNow(parked(), 5, 440, 100, cap)).to.equal(nil)
			-- NOW: the band has reached it.
			expect(Placement.reopenNow(parked(), 5, 395, 100, cap)).to.equal("beaters")
			-- ...AND A FRONT THAT HAS PASSED THE BED IS STILL "NOW", for the same reason `wakeReason`
			-- has no lower bound: a group the line walked through is exactly the one that must move.
			expect(Placement.reopenNow(parked(), 5, 100, 100, cap)).to.equal("beaters")
			-- A ROW THAT HAS NOT SPENT ITS SEARCHES IS NOT PARKED and needs no window.
			expect(Placement.reopenNow(parked({ searchesSpent = cap - 1 }), 5, 100, 100, cap)).to.equal(nil)
			-- A SKIPPED ROW NEVER COMES BACK (design must-not 3, task 172's rule: a wood is beaten
			-- once), and neither does one that has already had its reopen, or one with a body.
			expect(Placement.reopenNow(parked({ skipped = "nobed" }), 5, 100, 100, cap)).to.equal(nil)
			expect(Placement.reopenNow(parked({ reopened = true }), 5, 100, 100, cap)).to.equal(nil)
			expect(Placement.reopenNow(parked({ state = "bedded" }), 5, 100, 100, cap)).to.equal(nil)
			-- THE CLOCK ARM, for a walker: no line in the world and it still stands up on time.
			expect(Placement.reopenNow(parked({ wakeAtSeconds = 10 }), 10, nil, 100, cap)).to.equal("slot")
			expect(Placement.reopenNow(parked({ wakeAtSeconds = 10 }), 9.9, nil, 100, cap)).to.equal(nil)
			-- AND THE CAP ITSELF IS A NUMBER WITH ARITHMETIC BEHIND IT: 15 rows x (3 + 3) = 90
			-- searches worst case in a drive, under the Director's target of 100.
			expect(cap).to.equal(3)
			expect(#SCHEDULE.drive * cap * 2 < 100).to.equal(true)
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
	-- ------------------------------------------------- THE BUDGET, RESTATED (task 345 T5, design 5.2)
	--
	-- `grid-map.md` 9.2 still prints the OLD rows -- <= 4.0 ms average and <= 8.0 ms peak, and no
	-- bedded row at all. `animal-placement.md` 5.2 is the restatement and it is what these cases
	-- assert (the discrepancy is in `ESCALATE.md`, 2026-11-12: `docs/design/` is not the Builder's).
	--
	-- ONE OWNER PER NUMBER (rule 3): the enforced rows are ASKED of the constant that enforces them,
	-- so `ForestTest.budget()` cannot drift from `Data.LIVE_CAP`, `Placement.CONFIG.bedCap`,
	-- `Data.MAX_BOARS` or `SPOOK.BEATER_STUDS`. Only the MEASURED targets are literals here, because
	-- a target nothing enforces has nowhere else to live.
	describe("the budget", function()
		it("names design 5.2's rows, and each enforced one through its own owner", function()
			local budget = Forest.budget()
			expect(budget.liveCap).to.equal(Data.LIVE_CAP)
			expect(budget.liveCap).to.equal(24)
			-- 18 AND NOT THE DESIGN'S 12, by the Director's decision of 2026-11-11 ~01:45
			-- (`ESCALATE.md`, deviation 5), which supersedes the "<= 12" rows in sections 5.2 and 16.
			expect(budget.beddedCap).to.equal(CONFIG.bedCap)
			expect(budget.beddedCap).to.equal(18)
			-- ...AND IT IS STILL A SUB-CAP, which is the thing that makes `liveCap` the binding arm.
			expect(budget.beddedCap < budget.liveCap).to.equal(true)
			expect(budget.hardCeiling).to.equal(Data.MAX_BOARS)
			expect(budget.hardCeiling).to.equal(60)
			expect(budget.bedGapStuds).to.equal(SPOOK.BEATER_STUDS)
			-- THE MEASURED TARGETS, raised from `grid-map.md` 9.2's 4.0 / 8.0. 7.0 is the fit's own
			-- answer at the cap (`0.222 x 24 + 1.44 = 6.77`) and 22 % of the 32.05 ms heartbeat.
			expect(budget.stepMsAvg).to.equal(7.0)
			expect(budget.stepMsPeak).to.equal(20.0)
			expect(budget.heartbeatP95Ms).to.equal(32.0)
			-- A peak below the average, or an average above the heartbeat it is a share of, would be
			-- a restatement that does not hold together.
			expect(budget.stepMsPeak > budget.stepMsAvg).to.equal(true)
			expect(budget.stepMsAvg < budget.heartbeatP95Ms).to.equal(true)
			expect(budget.parts).to.equal(2000)
			-- THE NUMBER THIS TASK EXISTS FOR.
			expect(budget.laneSpawns).to.equal(0)
			TestKit.note(
				string.format(
					"task 345 T5 budget: live <= %d, bedded <= %d, ceiling %d, step <= %.1f/%.1f ms,"
						.. " heartbeat p95 <= %.1f ms, parts < %d, lane spawns %d",
					budget.liveCap,
					budget.beddedCap,
					budget.hardCeiling,
					budget.stepMsAvg,
					budget.stepMsPeak,
					budget.heartbeatP95Ms,
					budget.parts,
					budget.laneSpawns
				)
			)
		end)

		it("holds the dormant roster inside 120 rows, at 0 instances and 0 parts", function()
			local budget = Forest.budget()
			expect(budget.dormantRows).to.equal(120)
			-- THE SCRIPT'S OWN WORST CASE, not a number typed here: fifteen slots at `busy`, which is
			-- the density that silences nothing. Design 5.2 puts it at "15 slots x <= 9 animals".
			local rows = planAt("busy")
			expect(#rows <= budget.dormantRows).to.equal(true)
			local animals = 0
			for _, row in ipairs(rows) do
				animals += row.size
				-- A RECORD COSTS NO INSTANCE AND NO PART, which is the whole of the tier: the roster
				-- is a table of rows and `Runtime:step` never sees one.
				expect(row.state).to.equal("record")
				expect(#row.ids).to.equal(0)
				expect(row.at).to.equal(nil)
			end
			-- 83 at `busy` (design 5.2's "53 / 73 / 83"), and every one of them dormant.
			expect(animals <= budget.dormantRows).to.equal(true)
			TestKit.note(
				string.format(
					"task 345 T5: a busy drive is %d dormant rows / %d animals, 0 instances, 0 parts (cap %d rows)",
					#rows,
					animals,
					budget.dormantRows
				)
			)
		end)

		it("starts a drive with 0 lane spawns and 0 of each wake source counted", function()
			-- THE COUNTERS EXIST AND ARE ZEROED BY `planDrive`, which is what makes a live reading of
			-- 0 evidence rather than a counter nothing ever wrote (design 12.3).
			local stats = Forest.placementStats()
			for _, key in ipairs({ "laneSpawns", "laneSlots", "laneWorstSlot", "wokeWalk", "wokeHorn", "wokeSlot" }) do
				expect(type(stats[key])).to.equal("number")
			end
			expect(stats.laneSpawns).to.equal(0)
			expect(stats.laneSlots).to.equal(0)
			expect(stats.laneWorstSlot).to.equal(0)
		end)
	end)
end
