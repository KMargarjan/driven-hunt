-- range.spec: THE LOBBY SHOOTING RANGE -- its frozen data, its pure arithmetic, the geometry it
-- builds into a folder of its own, and the lane the owner runs. Task 298, step B2.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- IT WORKS IN DEV WITH NO PLAY AND NO WORLD (`lobby_live.spec`'s arrangement): every case builds
-- into `Instance.new("Folder")` and starts the owner with its own fakes and its own clock, then
-- stops it again. Nothing here touches `Workspace`, and two cases assert exactly that.
--
-- THE FAKE ANIMAL IS A RAIL, and it moves by the BRAIN's own rule rather than a convenience: it
-- walks toward the point it was last ordered to, at the speed it was asked for, and stops inside
-- `Boar.CONFIG.LINE.ARRIVE_STUDS` -- *"ARRIVED: hold the heading and stop, rather than jittering on
-- top of the point"* (`Brain._step`'s ordered branch). So what the crossing cases measure is the
-- owner's lane and the ordered speed, not the spec's idea of walking.
--
-- Design: docs/design/shooting-range.md sections 3, 4.1, 5, 6, 8.4 and 11.1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Range = require(ServerScriptService:WaitForChild("Range"))
local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local LAYOUT = RangeData.LAYOUT
local DEV_ROW = { x = 1200, z = 0, y = 0, plate = true }

return function()
	-- The one place the spec names a speed: it asks `Boar` and compares, so a changed `PACE` row
	-- moves the assertion with it.
	local function speedOf(pace: string): number
		return Boar.paceSpeed(pace, Boar.CONFIG)
	end

	local function newClock()
		local clock = { t = 0 }
		return clock, function()
			return clock.t
		end
	end

	local function newFakeBoars()
		local fake = {
			animals = {} :: { [string]: any },
			leads = {} :: { any },
			flyingIds = {} :: { [string]: boolean },
			spawns = 0,
			clears = 0,
			lastClear = nil :: string?,
			nextId = 0,
		}
		fake.spawn = function(position: Vector3, kind: string?)
			fake.nextId += 1
			local id = "fake" .. tostring(fake.nextId)
			fake.animals[id] = { id = id, position = position, kind = kind, alive = true, want = 0, speed = 0 }
			fake.spawns += 1
			return { id = id, kind = kind }
		end
		fake.clear = function(reason: string?)
			fake.clears += 1
			fake.lastClear = reason
			fake.animals = {}
		end
		fake.statusOf = function(id: string)
			local animal = fake.animals[id]
			if animal == nil then
				return nil
			end
			return {
				position = animal.position,
				speed = animal.speed,
				want = animal.want,
				alive = animal.alive,
				kind = animal.kind,
			}
		end
		fake.leadTo = function(id: string, point: Vector3, speed: number)
			local animal = fake.animals[id]
			if animal == nil then
				return false
			end
			animal.order = point
			animal.want = speed
			table.insert(fake.leads, { id = id, point = point, speed = speed })
			return true
		end
		fake.flying = function(id: string)
			return fake.flyingIds[id] == true
		end
		fake.configOf = function()
			return Boar.CONFIG
		end
		fake.paceSpeed = function(pace: string)
			return speedOf(pace)
		end
		fake.advance = function(dt: number)
			for _, animal in pairs(fake.animals) do
				if animal.alive and animal.order ~= nil then
					local to = Vector3.new(animal.order.X - animal.position.X, 0, animal.order.Z - animal.position.Z)
					if to.Magnitude <= Boar.CONFIG.LINE.ARRIVE_STUDS or animal.want <= 0 then
						animal.speed = 0
					else
						animal.position += to.Unit * math.min(animal.want * dt, to.Magnitude)
						animal.speed = animal.want
					end
				end
			end
		end
		fake.only = function()
			for _, animal in pairs(fake.animals) do
				return animal
			end
			return nil
		end
		return fake
	end

	-- One range, started into a folder of its own, with a fake clock and a fake runtime.
	local function startRange(fake, now)
		local root = Instance.new("Folder")
		local ok = Range.start({
			enabled = true,
			anchor = DEV_ROW,
			root = root,
			boars = fake,
			now = now,
		})
		return ok, root
	end

	local function advance(fake, clock, seconds: number)
		local dt = 1 / 60
		for _ = 1, math.floor(seconds / dt) do
			clock.t += dt
			fake.advance(dt)
			Range.step(dt)
		end
	end

	-- ------------------------------------------------------------------ 1. THE ROW DECIDES
	describe("which worlds have a range", function()
		it("has a row for the DEV place and for nothing else yet", function()
			local dev = RangeData.anchorFor("map:v1")
			expect(dev).to.be.ok()
			expect((dev :: any).plate).to.equal(true)
			expect((dev :: any).x).to.equal(1200)
			-- THE SWITCH-OFF CASE, which matters most: no row means no range, and the answer is
			-- never found by sniffing Workspace.
			expect(RangeData.anchorFor("arena")).to.equal(nil)
			expect(RangeData.anchorFor("nowhere")).to.equal(nil)
			expect(RangeData.anchorFor(nil)).to.equal(nil)
			expect(RangeData.anchorFor(7 :: any)).to.equal(nil)
			-- ...AND KAREN'S PLACE HAS NO ROW IN STEP B2: its anchor is a measurement over her own
			-- ground (design section 4.2) and it belongs to step B6.
			expect(RangeData.anchorFor("forest-test")).to.equal(nil)
		end)
	end)

	-- ------------------------------------------------------------------ 2. THE PURE ARITHMETIC
	describe("the lane arithmetic", function()
		it("puts the two ends of the lane either side of the middle, and flips with the leg", function()
			local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			expect(RangeData.laneLength(LAYOUT)).to.equal(LAYOUT.WINDOW_STUDS + 2 * LAYOUT.APRON_STUDS)
			local centre = RangeData.laneCentre(anchor, LAYOUT)
			expect(centre.Z - anchor.Z).to.equal(LAYOUT.DISTANCE_STUDS)
			local east = RangeData.laneEnds(anchor, LAYOUT, 1)
			local west = RangeData.laneEnds(anchor, LAYOUT, 2)
			expect(east.X - centre.X).to.equal(RangeData.laneLength(LAYOUT) / 2)
			expect(west.X - centre.X).to.equal(-RangeData.laneLength(LAYOUT) / 2)
			-- ODD EAST, EVEN WEST, for ever: the leg number is the direction.
			expect(RangeData.laneEnds(anchor, LAYOUT, 3).X).to.equal(east.X)
			expect(RangeData.laneEnds(anchor, LAYOUT, 4).X).to.equal(west.X)
			-- Both ends are on the lane, not in front of or behind it.
			expect(east.Z).to.equal(centre.Z)
			expect(west.Z).to.equal(centre.Z)
		end)

		it("predicts TARGET 3's crossing seconds from the BOAR's own PACE rows", function()
			local window = LAYOUT.WINDOW_STUDS
			local walk = RangeData.crossingSeconds(window, speedOf("walk"))
			local trot = RangeData.crossingSeconds(window, speedOf("trot"))
			local run = RangeData.crossingSeconds(window, speedOf("run"))
			expect(math.abs(walk - window / Boar.CONFIG.PACE.WALK_SPEED) < 1e-9).to.equal(true)
			expect(math.abs(trot - window / Boar.CONFIG.PACE.TROT_SPEED) < 1e-9).to.equal(true)
			expect(math.abs(run - window / Boar.CONFIG.PACE.RUN_SPEED) < 1e-9).to.equal(true)
			expect(walk > trot and trot > run).to.equal(true)
			-- A STANDING TARGET NEVER CROSSES, and the honest answer is infinity and not zero.
			expect(RangeData.crossingSeconds(window, speedOf("stand"))).to.equal(math.huge)
			expect(RangeData.crossingSeconds(window, -1)).to.equal(math.huge)
			TestKit.note(
				string.format(
					"range: predicted crossing of %d studs -- walk %.2f s, trot %.2f s, run %.2f s",
					window,
					walk,
					trot,
					run
				)
			)
		end)

		it("gives the range a field whose exit is behind the firing line", function()
			local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local field = RangeData.fieldFor(anchor, LAYOUT)
			-- NOTHING DESPAWNS MID-CROSSING: both ends of the lane are inside the bounds, and the
			-- exit line is 400 studs BEHIND the shooter, where a target that is doing what it was
			-- told can never reach.
			for leg = 1, 2 do
				local at = RangeData.laneEnds(anchor, LAYOUT, leg)
				expect(at.X > field.bounds.minX and at.X < field.bounds.maxX).to.equal(true)
				expect(at.Z > field.bounds.minZ and at.Z < field.bounds.maxZ).to.equal(true)
			end
			expect(field.exitZ < field.bounds.minZ).to.equal(true)
			expect(field.groundY).to.equal(anchor.Y)
			-- The lobby anchor (2850, -2950) is OUTSIDE the drive's field (z -2477..-1197), which is
			-- why the range has a field of its own at all.
			expect(-2950 < -2477).to.equal(true)
		end)

		it("answers which mat a man is standing on, and nil everywhere else", function()
			local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local mat = RangeData.matPosition(anchor, 1, LAYOUT)
			expect(mat.X).to.equal(anchor.X)
			expect(mat.Z).to.equal(anchor.Z)
			expect(RangeData.spotAt(anchor, mat, LAYOUT)).to.equal(1)
			-- One stud in from the edge is on it; one stud outside is not.
			local halfX = LAYOUT.MAT.size.X / 2
			expect(RangeData.spotAt(anchor, mat + Vector3.new(halfX - 1, 0, 0), LAYOUT)).to.equal(1)
			expect(RangeData.spotAt(anchor, mat + Vector3.new(halfX + 1, 0, 0), LAYOUT)).to.equal(nil)
			expect(RangeData.spotAt(anchor, mat + Vector3.new(0, 0, 500), LAYOUT)).to.equal(nil)
			expect(RangeData.spotAt(anchor, nil, LAYOUT)).to.equal(nil)
			expect(RangeData.spotAt(nil, mat, LAYOUT)).to.equal(nil)
		end)

		it("whitelists exactly the four pace words and refuses everything else", function()
			-- KAREN, 2026-10-27: *"walk trot stand run"*. The four words, from the table and not
			-- from a literal in here.
			local words = 0
			for _, word in pairs(RangeData.WORD) do
				expect(RangeData.paceAllowed(word)).to.equal(true)
				expect(RangeData.optionAllowed("pace", word)).to.equal(true)
				words += 1
			end
			expect(words).to.equal(4)
			expect(RangeData.WORD.STAND).to.equal("stand")
			for _, bad in ipairs({ "", "sprint", "WALK", "0" }) do
				expect(RangeData.paceAllowed(bad)).to.equal(false)
			end
			expect(RangeData.paceAllowed(nil)).to.equal(false)
			expect(RangeData.paceAllowed(1 :: any)).to.equal(false)
			expect(RangeData.paceAllowed({} :: any)).to.equal(false)
			-- An unknown KIND is false, never true.
			expect(RangeData.optionAllowed("weapon", "shotgun")).to.equal(false)
			expect(RangeData.optionAllowed("spot", 1)).to.equal(true)
			expect(RangeData.optionAllowed("spot", 0)).to.equal(false)
			expect(RangeData.optionAllowed("spot", 1.5)).to.equal(false)
			expect(RangeData.optionAllowed("spot", LAYOUT.SPOT_COUNT + 1)).to.equal(false)
		end)
	end)

	-- ------------------------------------------------------------------ 3. THE GEOMETRY
	describe("Build", function()
		it("builds the whole range into the folder it is given, both anchor branches", function()
			-- PLATE = TRUE (DEV): its own anchored ground, no terrain and no raycast.
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			expect(built).to.be.ok()
			local folder = (built :: any).folder
			expect(folder.Parent).to.equal(parent)
			expect(folder.Name).to.equal(LAYOUT.folderName)
			expect(folder:FindFirstChild("Plate")).to.be.ok()
			expect(folder:FindFirstChild("Berm")).to.be.ok()
			expect(folder:FindFirstChild("ScreenEast")).to.be.ok()
			expect(folder:FindFirstChild("ScreenWest")).to.be.ok()

			-- THE MAT IS THE FIRST DIRECT-CHILD BASEPART: the harness's stage block puts the player
			-- at a folder's first BasePart, and that has to be the firing position.
			local first = nil
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("BasePart") then
					first = child
					break
				end
			end
			expect(first).to.be.ok()
			expect((first :: any).Name).to.equal(RangeData.MAT_NAME)

			local parts, prompts = 0, 0
			for _, child in ipairs(folder:GetDescendants()) do
				if child:IsA("BasePart") then
					parts += 1
					-- EVERY PART ANCHORED, or the range falls over the first time anything touches it.
					expect(child.Anchored).to.equal(true)
				elseif child:IsA("ProximityPrompt") then
					prompts += 1
				end
			end
			expect(prompts).to.equal(LAYOUT.SPOT_COUNT)
			expect(parts).to.equal((built :: any).parts)
			expect(parts <= Range.CONFIG.MAX_PARTS).to.equal(true)

			-- NO DUPLICATE RANGE: a second build into the same parent is refused.
			local again, why = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			expect(again).to.equal(nil)
			expect(why).to.equal("already built")

			-- PLATE = FALSE: the lane is laid on the ground that is MEASURED, through the world's one
			-- ground reader, and the row carries no Y at all.
			local reads = 0
			local onGround = Instance.new("Folder")
			local laid = Range.Build.build({
				parent = onGround,
				row = { x = 50, z = -20, plate = false },
				layout = LAYOUT,
				groundAt = function()
					reads += 1
					return 137.5
				end,
			})
			expect(laid).to.be.ok()
			expect(reads > 0).to.equal(true)
			expect((laid :: any).shelf).to.equal(137.5)
			expect((laid :: any).folder:FindFirstChild("Plate")).to.equal(nil)
			local mat = (laid :: any).mats[1]
			expect(math.abs(mat.Position.Y - (137.5 + LAYOUT.MAT.size.Y / 2)) < 1e-6).to.equal(true)

			-- ...and with no plate AND no ground reader there is no range, rather than one in the air.
			local nothing, reason = Range.Build.build({
				parent = Instance.new("Folder"),
				row = { x = 0, z = 0, plate = false },
				layout = LAYOUT,
			})
			expect(nothing).to.equal(nil)
			expect(reason).to.equal("no ground under the range")
			TestKit.note(
				string.format(
					"range: built %d parts in %d ms (budget %d parts)",
					parts,
					(built :: any).buildMs,
					Range.CONFIG.MAX_PARTS
				)
			)
		end)
	end)

	-- ------------------------------------------------------------------ 4. THE OWNER AND THE LANE
	describe("the lane the owner runs", function()
		it("refuses to start with the flag off, and with no row", function()
			expect(Range.start({ enabled = false, anchor = DEV_ROW, root = Instance.new("Folder") })).to.equal(false)
			expect(Range.stats().refusedBy).to.equal("flag")
			expect(Range.isBuilt()).to.equal(false)
			expect(Range.start({ enabled = true, world = "arena", root = Instance.new("Folder") })).to.equal(false)
			expect(Range.stats().refusedBy).to.equal("no row")
			expect(Range.isBuilt()).to.equal(false)
		end)

		it("crosses the lane and FLIPS direction at the end, both ways", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			local ok, root = startRange(fake, now)
			expect(ok).to.equal(true)
			expect(Range.isBuilt()).to.equal(true)
			expect(root:FindFirstChild(LAYOUT.folderName)).to.be.ok()

			-- Long enough for several legs at a trot: the lane is 80 studs, a trot is 11 studs/s.
			advance(fake, clock, 40)
			local trial = Range.trialOf(1) :: any
			expect(trial).to.be.ok()
			-- IT ENTERED THE BRANCH: flips happened, and orders went BOTH ways.
			expect(Range.stats().flips >= 2).to.equal(true)
			expect((trial.directions.east or 0) > 0).to.equal(true)
			expect((trial.directions.west or 0) > 0).to.equal(true)
			expect(trial.crossings >= 2).to.equal(true)
			-- ...AND THE ORDER IS RE-ISSUED, a count that rises with the scans (TARGET 7).
			expect(Range.stats().leadTos >= Range.stats().scans - 2).to.equal(true)
			-- The target stayed ON the lane: inside the apron in x, and within 2 studs of the lane in z.
			local animal = fake.only() :: any
			local centre = RangeData.laneCentre(Vector3.new(DEV_ROW.x, 0, DEV_ROW.z), LAYOUT)
			expect(math.abs(animal.position.X - centre.X) <= RangeData.laneLength(LAYOUT) / 2 + 4).to.equal(true)
			expect(math.abs(animal.position.Z - centre.Z) <= 2).to.equal(true)
			TestKit.note(
				string.format(
					"range: %d crossings and %d flips in 40 s at a trot (east %d, west %d orders)",
					trial.crossings,
					Range.stats().flips,
					trial.directions.east or 0,
					trial.directions.west or 0
				)
			)
			Range.stop()
			expect(Range.isBuilt()).to.equal(false)
			expect(root:FindFirstChild(LAYOUT.folderName)).to.equal(nil)
		end)

		it("measures the crossing seconds at walk, trot and run within 10 % of lane / paceSpeed", function()
			local rows = {}
			for _, pace in ipairs({ "walk", "trot", "run" }) do
				local clock, now = newClock()
				local fake = newFakeBoars()
				expect(select(1, startRange(fake, now))).to.equal(true)
				expect(Range.setPace(1, pace)).to.equal(true)
				local trial = Range.trialOf(1) :: any
				-- THE SPEED ASKED FOR IS `Boar.paceSpeed`'S AND NEVER A LITERAL.
				expect(trial.speedStudsPerSecond).to.equal(speedOf(pace))
				-- Three full lane lengths' worth of time, whatever the pace.
				advance(fake, clock, 3 * RangeData.laneLength(LAYOUT) / speedOf(pace) + 2)
				trial = Range.trialOf(1) :: any
				local measured = trial.crossingSecondsByPace[pace]
				local predicted = RangeData.crossingSeconds(LAYOUT.WINDOW_STUDS, speedOf(pace))
				expect(measured).to.be.ok()
				-- TARGET 3: +-10 %. The measurement is quantised to one scan (1 / STEP_HZ = 0.1 s),
				-- which is 6 % of the fastest crossing and inside the tolerance for all three.
				local err = math.abs(measured - predicted) / predicted
				expect(err <= Range.CONFIG.CROSSING_TOLERANCE).to.equal(true)
				-- ...and every order carried that pace's speed, never another's.
				for _, lead in ipairs(fake.leads) do
					expect(lead.speed).to.equal(speedOf(pace))
				end
				table.insert(
					rows,
					string.format("%s %.2f s (predicted %.2f, %.1f %%)", pace, measured, predicted, err * 100)
				)
				Range.stop()
			end
			TestKit.note("range: measured crossings -- " .. table.concat(rows, " · "))
		end)

		it("holds a STAND target within 2 studs of the lane middle for 3 seconds", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			expect(Range.setPace(1, RangeData.WORD.STAND)).to.equal(true)
			-- KAREN, 2026-10-27: a target released broadside at the lane's middle and HELD there, so
			-- aim is isolated from lead. It walks there and the BRAIN stops it inside
			-- `LINE.ARRIVE_STUDS`; the range issues the same `leadTo` seam and writes no CFrame.
			local centre = RangeData.laneCentre(Vector3.new(DEV_ROW.x, 0, DEV_ROW.z), LAYOUT)
			-- 40 studs of lane at a walk is ~9 s to reach the middle, then 3 s of standing.
			advance(fake, clock, 20)
			local held = 0
			local samples = 0
			for _ = 1, 180 do
				clock.t += 1 / 60
				fake.advance(1 / 60)
				Range.step(1 / 60)
				local animal = fake.only() :: any
				samples += 1
				if
					(Vector3.new(animal.position.X - centre.X, 0, animal.position.Z - centre.Z)).Magnitude
					<= Range.CONFIG.STAND_HOLD_STUDS
				then
					held += 1
				end
			end
			-- N = 2 studs, M = 3 seconds: every one of the 180 samples (3 s at 60 Hz) is inside it.
			expect(samples).to.equal(180)
			expect(held).to.equal(180)
			local trial = Range.trialOf(1) :: any
			expect(trial.standSeconds >= 3).to.equal(true)
			-- IT ENTERED THE BRANCH: the orders went to the MIDDLE, not to an end of the lane.
			expect((trial.directions.middle or 0) > 0).to.equal(true)
			expect(trial.directions.east).to.equal(nil)
			expect(fake.only().speed).to.equal(0)
			-- A STANDING TARGET DOES NOT CROSS, so nothing is timed while it stands.
			expect(trial.crossings).to.equal(0)
			TestKit.note(
				string.format(
					"range: STAND held %.1f s within %d studs of the middle",
					trial.standSeconds,
					Range.CONFIG.STAND_HOLD_STUDS
				)
			)
			Range.stop()
		end)

		it("clears a killed target after CARCASS_SECONDS and releases a fresh one after RELEASE_SECONDS", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			advance(fake, clock, 2)
			expect(fake.spawns).to.equal(1)
			local dead = fake.only() :: any
			dead.alive = false

			-- Under the hold, nothing is cleared: the player is looking at what he did.
			advance(fake, clock, Range.CONFIG.CARCASS_SECONDS - 1)
			expect(fake.clears).to.equal(0)
			expect(Range.stats().carcasses).to.equal(1)

			advance(fake, clock, 1.5)
			expect(fake.clears).to.equal(1)
			expect(fake.lastClear).to.equal("range carcass")
			expect(Range.stats().releases).to.equal(1)
			-- ...and the fresh one is not released instantly either.
			expect(fake.spawns).to.equal(1)
			advance(fake, clock, Range.CONFIG.RELEASE_SECONDS + 0.5)
			expect(fake.spawns).to.equal(2)
			expect((fake.only() :: any).alive).to.equal(true)
			-- The new target crosses like the first: the lane did not stop with the death.
			advance(fake, clock, 20)
			expect(Range.stats().flips >= 1).to.equal(true)
			TestKit.note(
				string.format(
					"range: carcass held %d s, cleared, fresh target after %d s",
					Range.CONFIG.CARCASS_SECONDS,
					Range.CONFIG.RELEASE_SECONDS
				)
			)
			Range.stop()
		end)

		it("never orders an animal the Brain is flying", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			advance(fake, clock, 2)
			local animal = fake.only() :: any
			fake.flyingIds[animal.id] = true
			local leadsBefore = #fake.leads
			local skippedBefore = Range.stats().skippedFlying
			advance(fake, clock, 3)
			-- IT ENTERED THE BRANCH, and issued nothing: *"the drive must not order an animal the
			-- Brain is flying"*.
			expect(Range.stats().skippedFlying > skippedBefore).to.equal(true)
			expect(#fake.leads).to.equal(leadsBefore)
			-- ...and it picks the lane up again when the flight ends.
			fake.flyingIds[animal.id] = false
			advance(fake, clock, 2)
			expect(#fake.leads > leadsBefore).to.equal(true)
			Range.stop()
		end)
	end)

	-- ------------------------------------------------------------------ 5. ONE WRITER EACH
	describe("the drive is untouched", function()
		it("writes no Workspace.Boars, no drive runtime and no Workspace.Range", function()
			-- WHAT THE DRIVE OWNS, BEFORE: its folder and its count.
			local boarsFolderBefore = Workspace:FindFirstChild("Boars")
			local boarsBefore = if boarsFolderBefore then #boarsFolderBefore:GetChildren() else -1

			-- A REAL drive runtime, into a parent of this spec's own, so the range can be caught
			-- touching it if it ever does.
			local driveParent = Instance.new("Folder")
			local driveWorld = Boar.defaultWorld({
				bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
				exitZ = -190,
				groundY = 0,
			})
			driveWorld.parent = driveParent
			driveWorld.threats = function()
				return {}
			end
			local drive = Boar.newRuntime(driveWorld)
			expect(drive:count()).to.equal(0)

			local clock, now = newClock()
			local fake = newFakeBoars()
			local ok, root = startRange(fake, now)
			expect(ok).to.equal(true)
			advance(fake, clock, 20)
			expect(Range.stats().flips >= 1).to.equal(true)

			-- THE RANGE SPAWNED THROUGH ITS OWN INJECTED VIEW AND NOWHERE ELSE.
			expect(fake.spawns >= 1).to.equal(true)
			expect(drive:count()).to.equal(0)
			-- THE DRIVE'S OWN FOLDER IS EMPTY. The runtime creates it itself on `run`, so the claim
			-- is that nothing is IN it: the range released its target through its own view.
			expect(drive:folder().Parent).to.equal(driveParent)
			expect(#drive:folder():GetChildren()).to.equal(0)
			-- Nothing was built in Workspace: the range built into the folder it was handed.
			expect(Workspace:FindFirstChild(LAYOUT.folderName)).to.equal(nil)
			expect(root:FindFirstChild(LAYOUT.folderName)).to.be.ok()
			local boarsFolderAfter = Workspace:FindFirstChild("Boars")
			local boarsAfter = if boarsFolderAfter then #boarsFolderAfter:GetChildren() else -1
			expect(boarsAfter).to.equal(boarsBefore)

			Range.stop()
			drive:destroy()
			expect(Workspace:FindFirstChild(LAYOUT.folderName)).to.equal(nil)
		end)
	end)

	-- ------------------------------------------------------------------ 6. KAREN'S DEER QUESTION
	describe("the range runtime and a deer kind", function()
		-- KAREN, 2026-10-27: *"animals"*. MEASURED HERE rather than assumed: can the range's own
		-- `Boar.newRuntime` -- the world of design section 5, with its own folder, no threats, SENSE
		-- off and `LINE` on -- spawn a DEER kind, with the deer's own zones, through no new code path?
		it("spawns a hind with the deer's own zones, through the same seam, with no new code path", function()
			-- A HOLDER UNDER `Workspace`, AND IT HAS TO BE (`deer.spec`'s own idiom): `Body.create`
			-- calls the Network Ownership API, which refuses a part that is not a descendant of
			-- `Workspace`. It is named, and destroyed at the end of the case.
			local parent = Instance.new("Folder")
			parent.Name = "RangeDeerSpec"
			parent.Parent = Workspace
			local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local world = Boar.defaultWorld(RangeData.fieldFor(anchor, LAYOUT))
			world.parent = parent
			world.folderName = "RangeTargets"
			world.threats = function()
				return {}
			end
			-- `LINE` IS MERGED AND NOT REPLACED: `newRuntime` assigns every key but MODEL, SENSE and
			-- KINDS wholesale, and an order with a nil lifetime is a crash and not a refusal.
			local line = table.clone(Boar.CONFIG.LINE)
			line.ENABLED = true
			world.config = {
				LINE = line,
				SENSE = { ENABLED = false },
				KINDS = { ENABLED = true },
				maxBoars = Range.CONFIG.MAX_TARGETS,
			}
			local runtime = Boar.newRuntime(world)

			local handle = runtime:spawn(RangeData.laneEnds(anchor, LAYOUT, 2), "hind")
			expect(handle).to.be.ok()
			expect((handle :: any).kind).to.equal("hind")
			local status = runtime:statusOf((handle :: any).id)
			expect(status).to.be.ok()
			expect((status :: any).alive).to.equal(true)
			expect((status :: any).kind).to.equal("hind")

			-- ITS OWN ZONES: the red deer's order carries `neck`, the boar's does not. Read off the
			-- config the animal actually lives by, not off a literal.
			local deerZones = Boar.kindConfig("hind", runtime:config()).ZONES.ORDER
			local boarZones = Boar.kindConfig("male", runtime:config()).ZONES.ORDER
			local function has(list, name)
				for _, item in ipairs(list) do
					if item == name then
						return true
					end
				end
				return false
			end
			expect(has(deerZones, "neck")).to.equal(true)
			expect(has(boarZones, "neck")).to.equal(false)

			-- ...AND THE LANE'S ONE SEAM ACCEPTS IT: `leadTo` answers true for the hind, so the lane
			-- takes the kind as a PARAMETER and nothing else has to change.
			expect(runtime:leadTo((handle :: any).id, RangeData.laneEnds(anchor, LAYOUT, 1), speedOf("trot"))).to.equal(
				true
			)
			TestKit.note(
				string.format(
					"range: a hind spawns in the range runtime with %d zones (boar %d), and leadTo accepts it",
					#deerZones,
					#boarZones
				)
			)
			runtime:destroy()
			parent:Destroy()
			expect(Workspace:FindFirstChild("RangeDeerSpec")).to.equal(nil)
		end)
	end)
end
