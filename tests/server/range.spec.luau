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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
-- Step B3: the loan is the SHIPPED entitlement path, so the spec asks the shipped tables.
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Rules = require(ServerScriptService:WaitForChild("Weapon"):WaitForChild("Rules"))
-- ONLY TO PUT THE PROVIDERS BACK (`weapon_shot.spec`'s reason): `MatchBoot` wired them.
local Match = require(ServerScriptService:WaitForChild("Match"))
local Lobby = require(ServerScriptService:WaitForChild("Lobby"))
local LobbyData = require(ReplicatedStorage:WaitForChild("Lobby"))
local Range = require(ServerScriptService:WaitForChild("Range"))
local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local StateMachine = Weapon.StateMachine

local LAYOUT = RangeData.LAYOUT
local DEV_ROW = { x = 1200, z = 0, y = 0, plate = true }
-- THE LOBBY'S OWN RECTANGLES, read from the lobby's own data: step B6 holds the range clear of
-- the seven pieces `lobby.spec` already holds to that rectangle (design 4.2 item 4).
-- KAREN'S ROW, at file scope: the lane arithmetic and the B6 block read the same one.
local FOREST_ROW = RangeData.anchorFor("forest-test")
local Pads = Lobby.Pads
local LOBBY_CFG = LobbyData.CONFIG
local LOBBY_ANCHOR = LobbyData.anchorFor("forest-test")

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
		-- THE TWO READERS STEP B4 ADDED, wired exactly as `RangeBoot` wires them: the kinds of a
		-- species off the kind rows' own `species` field, and the zones of the animal a KIND spawns
		-- (`Boar.kindConfig`, which is what `Runtime:spawn` resolves).
		fake.kindsFor = function(species: string)
			local out = {}
			for _, kind in ipairs(Boar.CONFIG.KINDS.ORDER) do
				local row = (Boar.CONFIG.KINDS :: any)[kind]
				local owner = (type(row) == "table" and row.species) or "boar"
				if owner == species then
					table.insert(out, kind)
				end
			end
			return out
		end
		fake.zonesForKind = function(kind: string)
			local zones = Boar.kindConfig(kind, Boar.CONFIG).ZONES
			return if type(zones) == "table" and type(zones.ORDER) == "table" then zones.ORDER else {}
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
		it("has a row for the DEV place and one for Karen's, and for nothing else", function()
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
			-- ...AND KAREN'S PLACE NOW HAS ONE, MEASURED (step B6). Design 4.2's instrument, run by
			-- the Director over her own ground in Edit AND in Play: a raycast grid, 8-stud spacing,
			-- 504 samples over the 160 x 185 footprint. Best centre (2650, -3300): 0 non-terrain
			-- hits, 0 misses, ground spread 11.6 studs (the lobby's own chosen site had 16).
			local forest = RangeData.anchorFor("forest-test")
			expect(forest).to.be.ok()
			expect((forest :: any).x).to.equal(2650)
			expect((forest :: any).z).to.equal(-3216)
			-- NO TYPED Y: the shelf comes from the injected `groundAt` at build time, because a
			-- typed one would put the range in the air or inside the hill (design section 3).
			expect((forest :: any).plate).to.equal(false)
			expect((forest :: any).y).to.equal(nil)
			-- SHE SHOOTS SOUTH, AWAY FROM THE LODGE, and the direction is a DATA FIELD ON THE ROW
			-- and never a branch on the world's name.
			expect((forest :: any).downrange).to.equal(-1)
			-- ...AND THE TARGET IS DRAWN THERE, which is also a row field and not a branch: in DEV
			-- there is no such field and the target stays the grey box the weapon specs shoot at.
			expect((forest :: any).drawn).to.equal(true)
			expect((dev :: any).drawn).to.equal(nil)
			expect(RangeData.downrangeOf(forest)).to.equal(-1)
			expect(RangeData.downrangeOf(dev)).to.equal(1)
			expect(RangeData.downrangeOf(nil)).to.equal(1)
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

		it("gives the range a field whose exit is south of the whole field -- BOTH rows", function()
			-- BOTH ROWS, because `Brain:_outcome`'s despawn test is `position.Z <= field.exitZ` and
			-- ITS direction is not a parameter: an exit NORTH of the lane despawns every ordered
			-- target the moment it is led (round 2, finding 1).
			local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local field = RangeData.fieldFor(anchor, LAYOUT)
			for _, row in ipairs({ DEV_ROW, FOREST_ROW }) do
				local at0 = Vector3.new((row :: any).x, 0, (row :: any).z)
				local dir = RangeData.downrangeOf(row)
				local each = RangeData.fieldFor(at0, LAYOUT, dir)
				for leg = 1, 2 do
					local at = RangeData.laneEnds(at0, LAYOUT, leg, dir)
					expect(at.X > each.bounds.minX and at.X < each.bounds.maxX).to.equal(true)
					expect(at.Z > each.bounds.minZ and at.Z < each.bounds.maxZ).to.equal(true)
				end
				expect(each.exitZ < each.bounds.minZ).to.equal(true)
				expect(each.groundY).to.equal(at0.Y)
			end
			-- ...AND THE DEV ROW IS BIT-FOR-BIT WHAT IT ALWAYS WAS.
			expect(field.exitZ).to.equal(-RangeData.FIELD_EXIT_BEHIND_STUDS)
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
			-- An unknown KIND is false, never true. ("weapon" was the example here until step B4
			-- made it a real option; the rule is the same and the example is one that is still
			-- unknown.)
			expect(RangeData.optionAllowed("colour", "green")).to.equal(false)
			expect(RangeData.optionAllowed("", "green")).to.equal(false)
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

	describe("the corridor the target walks", function()
		-- THE CASE THE FAKE COULD NOT GIVE US, and it is here because the live DEV lane gave it
		-- instead: with the screens at `+-(WINDOW/2 + APRON)` -- design section 4.1's own row -- the
		-- target walked to the east end, stopped against the screen's west face at x = +32.2 and
		-- stayed there for 30 s. Nothing crossed, and every case above still passed, because a fake
		-- animal walks through walls. So the geometry is asserted against the corridor.
		it("builds nothing inside the lane the target walks", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			expect(built).to.be.ok()
			local anchor = (built :: any).anchor
			local shelf = (built :: any).shelf
			local centre = RangeData.laneCentre(anchor, LAYOUT)
			local half = RangeData.laneLength(LAYOUT) / 2
			-- The widest animal the lane can carry, with a stud of air each side.
			local body = Boar.bodyAvoidRadius(Boar.CONFIG)
			local blocking = {}
			for _, part in ipairs((built :: any).folder:GetDescendants()) do
				if not part:IsA("BasePart") then
					continue
				end
				-- The ground is UNDER the shelf and is what the target walks ON, not into.
				if part.Position.Y + part.Size.Y / 2 <= shelf + 1e-6 then
					continue
				end
				local overlapX = math.abs(part.Position.X - centre.X) <= half + part.Size.X / 2 + body
				local overlapZ = math.abs(part.Position.Z - centre.Z) <= part.Size.Z / 2 + body
				if overlapX and overlapZ then
					table.insert(
						blocking,
						string.format("%s at %.1f,%.1f", part.Name, part.Position.X, part.Position.Z)
					)
				end
			end
			expect(#blocking).to.equal(0)
			if #blocking > 0 then
				error("in the corridor: " .. table.concat(blocking, " | "))
			end
			-- ...AND THE TWO SCREENS ARE STILL THERE, outside it, so this case cannot be satisfied by
			-- building no screen at all.
			for leg = 1, 2 do
				local screen = RangeData.screenPosition(anchor, LAYOUT, leg)
				expect(math.abs(screen.X - centre.X) > half).to.equal(true)
				expect(math.abs(screen.X - RangeData.laneEnds(anchor, LAYOUT, leg).X)).to.equal(
					LAYOUT.SCREEN.size.X / 2 + LAYOUT.SCREEN.beyondStuds
				)
			end
			expect((built :: any).folder:FindFirstChild("ScreenEast")).to.be.ok()
			expect((built :: any).folder:FindFirstChild("ScreenWest")).to.be.ok()
			TestKit.note(string.format("range: 0 parts inside the %d-stud corridor (body radius %.2f)", 2 * half, body))
		end)

		-- THE WAY IN STANDS AT CHEST HEIGHT, NOT ON THE FLOOR. On the 8x8 mat the prompt was under
		-- her feet and off screen down the lane, so E did nothing (Director's proof, frames 03/04/06).
		it("hangs the prompt on a POST at the mat's front edge, at the one arithmetic's point", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			expect(built).to.be.ok()
			local folder = (built :: any).folder
			local post = folder:FindFirstChild("Post")
			expect(post).to.be.ok()
			expect((post :: any):IsA("BasePart")).to.equal(true)
			-- THE PROMPT IS ON THE POST and nowhere near the mat.
			local prompt = RangeData.promptFor(1, folder)
			expect(prompt).to.be.ok()
			expect((prompt :: any):IsA("ProximityPrompt")).to.equal(true)
			expect((prompt :: any).Parent.Parent).to.equal(post)
			local mat = folder:FindFirstChild(RangeData.MAT_NAME)
			expect(mat).to.be.ok()
			expect((prompt :: any):IsDescendantOf(mat :: any)).to.equal(false)
			-- ...AT THE POINT THE SHARED ARITHMETIC NAMES, which is what the client case projects.
			-- Over the DEV plate the ground spread is zero, so this is exact.
			local anchor = (built :: any).anchor
			local want = RangeData.promptPosition(anchor, 1, LAYOUT, (built :: any).downrange)
			local at = (post :: any).Position + Vector3.new(0, (post :: any).Size.Y / 2, 0)
			expect((at - want).Magnitude < 1e-3).to.equal(true)
			-- IT IS STILL IN REACH of a man on the mat, and still inside the range's own footprint.
			local matAt = RangeData.matPosition(anchor, 1, LAYOUT)
			local reach = (want - matAt).Magnitude
			expect(reach < LAYOUT.PROMPT.MaxActivationDistance).to.equal(true)
			local box = RangeData.footprintFor(anchor, LAYOUT, (built :: any).downrange)
			expect(want.X >= box.minX and want.X <= box.maxX).to.equal(true)
			expect(want.Z >= box.minZ and want.Z <= box.maxZ).to.equal(true)
			TestKit.note(
				string.format(
					"range: prompt on Post, %.2f studs from the mat (reach %d)",
					reach,
					LAYOUT.PROMPT.MaxActivationDistance
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

		-- THE DIRECTOR'S OWN SEQUENCE IN KAREN'S PLACE, 2026-10-28: the target was crossing at a
		-- TROT and he picked WALK through the menu while it was INSIDE the window. The board then
		-- read `crossing 4.75 s` beside `issued 4.5 studs/s` -- 21.4 studs of a 40-stud window,
		-- because `setPace` cleared the entry time and the next scan re-started the clock where the
		-- target happened to be. The animal was never fast; the CLOCK was started late.
		it("times a WALK picked MID-WINDOW over the whole window, not the studs that were left", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			expect(Range.setPace(1, RangeData.WORD.TROT)).to.equal(true)
			-- Into the window at a trot: the apron is 20 studs, so 3 s puts it well inside.
			advance(fake, clock, 3)
			local centre = RangeData.laneCentre(Vector3.new(DEV_ROW.x, 0, DEV_ROW.z), LAYOUT)
			local animal = fake.only() :: any
			local offset = math.abs(animal.position.X - centre.X)
			expect(offset < LAYOUT.WINDOW_STUDS / 2).to.equal(true)
			TestKit.note(string.format("range: picked WALK with the target %.1f studs inside the window", offset))
			-- THE PICK, mid-window.
			expect(Range.setPace(1, RangeData.WORD.WALK)).to.equal(true)
			-- Two whole lane lengths at a walk: enough for the partial exit AND a real crossing.
			advance(fake, clock, 2 * RangeData.laneLength(LAYOUT) / speedOf("walk") + 2)
			local trial = Range.trialOf(1) :: any
			local measured = trial.crossingSecondsByPace[RangeData.WORD.WALK]
			local predicted = RangeData.crossingSeconds(LAYOUT.WINDOW_STUDS, speedOf("walk"))
			expect(measured).to.be.ok()
			local err = math.abs(measured - predicted) / predicted
			-- TARGET 3, +-10 %. BEFORE the arming field this recorded ~21 studs / 4.5 studs/s.
			expect(err <= Range.CONFIG.CROSSING_TOLERANCE).to.equal(true)
			TestKit.note(
				string.format(
					"range: WALK picked mid-window measured %.2f s (predicted %.2f, %.1f %%)",
					measured,
					predicted,
					err * 100
				)
			)
			Range.stop()
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
			-- THE NEW TARGET IS STEERED LIKE THE FIRST, measured as a RISE from a snapshot taken
			-- after the release (review round 1, finding 2: a `flips >= 1` on a cumulative counter
			-- passes with the whole re-release path deleted).
			local flipsAfterRelease = Range.stats().flips
			local leadsAfterRelease = #fake.leads
			advance(fake, clock, 20)
			expect(Range.stats().flips > flipsAfterRelease).to.equal(true)
			expect(#fake.leads > leadsAfterRelease).to.equal(true)
			expect((fake.only() :: any).position.X ~= nil).to.equal(true)
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

	describe("the data and the counters", function()
		it("is frozen, so there is no run-time writer", function()
			-- Deep: `table.freeze` is shallow and this repository has paid for that once.
			expect(table.isfrozen(RangeData.LAYOUT)).to.equal(true)
			expect(table.isfrozen(RangeData.LAYOUT.MAT)).to.equal(true)
			expect(table.isfrozen(RangeData.ANCHORS)).to.equal(true)
			expect(table.isfrozen(RangeData.ANCHORS["map:v1"])).to.equal(true)
			expect(table.isfrozen(RangeData.WORD)).to.equal(true)
			expect(table.isfrozen(Range.CONFIG)).to.equal(true)
			expect(pcall(function()
				(RangeData.LAYOUT :: any).WINDOW_STUDS = 1
			end)).to.equal(false)
			-- ...and `anchorFor` still hands out a COPY a caller may hold.
			local row = RangeData.anchorFor("map:v1")
			expect(table.isfrozen(row :: any)).to.equal(false)
		end)

		it("counts one run, not every run in the session", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			advance(fake, clock, 30)
			expect(Range.stats().flips > 0).to.equal(true)
			Range.stop()
			-- A fresh start zeroes the running counters, or an assertion that something ROSE can be
			-- satisfied by a previous case (review round 1, finding 2).
			local _, now2 = newClock()
			local fake2 = newFakeBoars()
			expect(select(1, startRange(fake2, now2))).to.equal(true)
			expect(Range.stats().flips).to.equal(0)
			expect(Range.stats().scans).to.equal(0)
			expect(Range.stats().spawns).to.equal(0)
			expect(Range.stats().crossings).to.equal(0)
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
			local flipsBefore = Range.stats().flips
			advance(fake, clock, 20)
			expect(Range.stats().flips > flipsBefore).to.equal(true)

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

	-- ------------------------------------------------------------------ 7. WHO HOLDS A GUN (7.4)
	--
	-- Task 298 step B3. The ONE predicate and the THREE composed providers, each case driving the
	-- real function by parameter -- `Range.armingOver` and friends are what `RangeBoot` installs, so
	-- deleting a branch here fails here.
	local function manAt(position: Vector3?)
		if position == nil then
			return { Character = nil }
		end
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.one
		root.Anchored = true
		root.Position = position
		root.Parent = character
		return { Character = character }
	end

	local ANCHOR = Vector3.new(DEV_ROW.x, DEV_ROW.y, DEV_ROW.z)

	-- --------------------------------------------- 2b. THE MENU'S WHITELIST (step B4, design 7.3)
	describe("the option whitelist", function()
		it("accepts each gun and only the cartridges that gun really carries", function()
			for _, id in ipairs(Weapons.ORDER) do
				expect(RangeData.optionAllowed("weapon", id)).to.equal(true)
				for _, ammo in ipairs(Weapons.row(id).AMMO_KINDS) do
					expect(RangeData.optionAllowed("ammo", ammo, { weapon = id })).to.equal(true)
				end
			end
			-- A LOAD THE ROW DOES NOT CARRY IS REFUSED, and so is one with no gun named at all.
			expect(RangeData.optionAllowed("ammo", "buck", { weapon = "rifle" })).to.equal(false)
			expect(RangeData.optionAllowed("ammo", Weapons.row("rifle").AMMO_KINDS[1], {})).to.equal(false)
			expect(RangeData.optionAllowed("weapon", "musket")).to.equal(false)
			expect(RangeData.optionAllowed("weapon", 1 :: any)).to.equal(false)
		end)

		it("refuses a species or a kind that the server did not offer", function()
			local offered = { species = { "boar", "reddeer" }, kinds = { "male", "female" } }
			expect(RangeData.optionAllowed("species", "boar", offered)).to.equal(true)
			expect(RangeData.optionAllowed("species", "wolf", offered)).to.equal(false)
			expect(RangeData.optionAllowed("kind", "male", offered)).to.equal(true)
			expect(RangeData.optionAllowed("kind", "stag", offered)).to.equal(false)
			-- WITH NO LISTS, REFUSED: a whitelist whose default is "yes" is not a whitelist.
			expect(RangeData.optionAllowed("species", "boar")).to.equal(false)
			expect(RangeData.optionAllowed("kind", "male")).to.equal(false)
		end)

		it("offers the four pace words with STAND, and one distance -- the lane that is built", function()
			expect(#RangeData.PACE_ORDER).to.equal(4)
			expect(RangeData.PACE_ORDER[1]).to.equal(RangeData.WORD.STAND)
			local seen = {}
			for _, word in ipairs(RangeData.PACE_ORDER) do
				seen[word] = true
				expect(RangeData.paceAllowed(word)).to.equal(true)
			end
			expect(seen[RangeData.WORD.WALK]).to.equal(true)
			expect(seen[RangeData.WORD.TROT]).to.equal(true)
			expect(seen[RangeData.WORD.RUN]).to.equal(true)
			expect(#RangeData.DISTANCES_STUDS).to.equal(1)
			expect(RangeData.DISTANCES_STUDS[1]).to.equal(LAYOUT.DISTANCE_STUDS)
			expect(RangeData.optionAllowed("distanceStuds", LAYOUT.DISTANCE_STUDS)).to.equal(true)
			expect(RangeData.optionAllowed("distanceStuds", 200)).to.equal(false)
		end)

		it("says the gap in metres through the repository's one conversion, with Karen's words", function()
			local metresPerStud = Report.CONFIG.METRES_PER_STUD
			-- -3.2 studs is 0.896 m, which READS "0.9 m behind" -- Karen's own sentence, 2026-10-27.
			expect(RangeData.gapText(-3.2)).to.equal(
				string.format("%.1f m behind", math.floor(math.abs(-3.2 * metresPerStud) * 10 + 0.5) / 10)
			)
			expect(RangeData.gapText(3.2)).to.equal(
				string.format("%.1f m ahead", math.floor(3.2 * metresPerStud * 10 + 0.5) / 10)
			)
			expect(string.find(RangeData.gapText(-3.2), "behind") ~= nil).to.equal(true)
			expect(string.find(RangeData.gapText(3.2), "ahead") ~= nil).to.equal(true)
			expect(RangeData.gapText(nil)).to.equal("--")
			-- NO SECOND COPY OF 0.28 ANYWHERE: the number comes out of `Report.CONFIG`.
			expect(string.find(RangeData.distanceText(125), tostring(Report.metres(125)), 1, true) ~= nil).to.equal(
				true
			)
		end)
	end)

	-- --------------------------------------------- 2c. THE DOOR AND THE RECORD (step B4, 8.2 / 9)
	describe("the range's one inbound door", function()
		local function manOn(position: Vector3?, id: number)
			local man = manAt(position) :: any
			man.UserId = id
			man.Name = "Man" .. tostring(id)
			return man
		end

		local function tick(clock, seconds: number)
			clock.t += seconds
		end

		it("refuses a forged payload and a pick from a man who is not on the mat", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local mat = RangeData.matPosition(ANCHOR, 1, LAYOUT)
			local man = manOn(mat, 101)
			local before = Range.stats().badRequests

			-- NOT A TABLE, NO SPOT, A SPOT THAT IS A STRING, A WORD OUTSIDE THE WHITELIST.
			expect(Range.onRequest(man, "go" :: any)).to.equal(false)
			tick(clock, 1)
			expect(Range.onRequest(man, {})).to.equal(false)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = "1" :: any, go = true })).to.equal(false)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, pace = "sprint" })).to.equal(false)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, weapon = "musket" })).to.equal(false)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, weapon = "rifle", ammo = "buck" })).to.equal(false)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, species = "wolf" })).to.equal(false)
			expect(Range.stats().badRequests > before).to.equal(true)

			-- A LEGAL PICK FROM A MAN OFF THE MAT IS NOT A FORGERY: it is refused, and NOT counted
			-- as one (`badRequests` apart from `refusedBy`).
			local away = manOn(mat + Vector3.new(500, 0, 0), 102)
			local forged = Range.stats().badRequests
			tick(clock, 1)
			expect(Range.onRequest(away, { spot = 1, pace = RangeData.WORD.RUN })).to.equal(false)
			expect(Range.stats().badRequests).to.equal(forged)

			-- ...AND THE RATE BUCKET, which is per player and its own counter.
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.RUN })).to.equal(true)
			local limited = Range.stats().rateLimited
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.WALK })).to.equal(false)
			expect(Range.stats().rateLimited).to.equal(limited + 1)
			Range.stop()
		end)

		it("applies a legal pick to the trial and starts a fresh record", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 103)
			tick(clock, 1)
			expect(Range.onRequest(man, {
				spot = 1,
				pace = RangeData.WORD.RUN,
				weapon = "rifle",
				ammo = Weapons.row("rifle").AMMO_KINDS[1],
			})).to.equal(true)
			local trial = Range.trialOf(1) :: any
			expect(trial.pace).to.equal(RangeData.WORD.RUN)
			expect(trial.weapon).to.equal("rifle")
			expect(trial.speedStudsPerSecond).to.equal(speedOf(RangeData.WORD.RUN))
			local record = Range.recordOf(man) :: any
			expect(record).to.be.ok()
			expect(record.shots).to.equal(0)
			expect(record.weapon).to.equal("rifle")
			-- THE TRIAL STARTS WITH A REAL GUN AND A LOAD THAT GUN REALLY CARRIES, read off the row.
			expect(Range.CONFIG.DEFAULT_AMMO).to.equal(Weapons.row(Range.CONFIG.DEFAULT_WEAPON).AMMO_KINDS[1])
			expect(Ballistics.shotFor(Weapons.row(Range.CONFIG.DEFAULT_WEAPON), Range.CONFIG.DEFAULT_AMMO)).to.be.ok()
			-- THE ZONE COLUMNS ARE THE ANIMAL'S OWN, read through the seam and not typed here.
			expect(#record.zoneOrder).to.equal(#Boar.CONFIG.ZONES.ORDER)
			Range.stop()
		end)

		it("offers the boar as well as the deer, and the cartridge follows the gun", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			-- THE BOAR IS THE BASE CONFIG, NOT A ROW IN `SPECIES`: measured live on 2026-10-27, the
			-- menu offered RED DEER and nothing else until `optionLists` seeded the default.
			local offered = Range.optionLists()
			local seen = {}
			for _, name in ipairs(offered.species) do
				seen[name] = true
			end
			expect(seen.boar).to.equal(true)
			expect(seen.reddeer).to.equal(true)
			expect(Boar.CONFIG.SPECIES.boar).to.equal(nil)

			-- PICKING A GUN TAKES ITS OWN FIRST LOAD, because the old gun's load is not legal on it
			-- -- which is what made `Ballistics.shotFor` return nil and the board print 0.00.
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 107)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, weapon = "lever" })).to.equal(true)
			local trial = Range.trialOf(1) :: any
			expect(trial.weapon).to.equal("lever")
			expect(RangeData.optionAllowed("ammo", trial.ammo, { weapon = "lever" })).to.equal(true)
			expect(Ballistics.shotFor(Weapons.row(trial.weapon), trial.ammo)).to.be.ok()
			-- ...AND A LOAD NAMED IN THE SAME REQUEST WINS over the row's first.
			local loads = Weapons.row("shotgun").AMMO_KINDS
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, weapon = "shotgun", ammo = loads[#loads] })).to.equal(true)
			expect((Range.trialOf(1) :: any).ammo).to.equal(loads[#loads])

			-- THE BOARD SHOWS A LEAD FROM THE MOMENT OF THE PICK, not only after a shot.
			local record = Range.recordOf(man) :: any
			expect(record.shots).to.equal(0)
			expect(record.leadBallisticStuds > 0).to.equal(true)
			expect(record.leadViewStuds > 0).to.equal(true)
			expect(record.leadViewMeasured).to.equal(false)
			Range.stop()
		end)

		it("publishes the speed it ISSUES, which at STAND is the walk it orders", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 108)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.STAND })).to.equal(true)
			local trial = Range.trialOf(1) :: any
			-- B2's QUEUED NOTE: the pace's own speed is 0 at STAND while the target WALKS to the
			-- middle, so the board prints both and `issuedSpeedFor` is the one answer `order` uses.
			expect(trial.speedStudsPerSecond).to.equal(speedOf(RangeData.WORD.STAND))
			expect(Range.issuedSpeedFor(trial)).to.equal(speedOf(RangeData.WORD.WALK))
			local record = Range.recordOf(man) :: any
			expect(record.paceStudsPerSecond).to.equal(speedOf(RangeData.WORD.STAND))
			expect(record.issuedStudsPerSecond).to.equal(speedOf(RangeData.WORD.WALK))
			-- ...AND THE SPEED THE RUNTIME IS ACTUALLY ASKED FOR IS THAT SAME NUMBER.
			advance(fake, clock, 1)
			local last = fake.leads[#fake.leads]
			expect(last).to.be.ok()
			expect((last :: any).speed).to.equal(speedOf(RangeData.WORD.WALK))
			-- A STANDING TARGET NEEDS NO LEAD, and the board says which.
			expect((Range.recordOf(man) :: any).leadBallisticStuds).to.equal(0)
			Range.stop()
		end)

		it("counts a shot, a hit in its own zone, a miss, and resets on the same door", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 104)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.TROT })).to.equal(true)
			advance(fake, clock, 1)

			-- ONE SHOT THAT MISSES: `ShotResolved` alone, because a miss produces no `HitReported`.
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			local record = Range.recordOf(man) :: any
			expect(record.shots).to.equal(1)
			expect(record.hits).to.equal(0)
			expect(record.miss).to.equal(1)
			-- THE BALLISTIC LEAD IS THE SHIPPED FUNCTION'S ANSWER, never a number typed twice.
			local shot = Ballistics.shotFor(Weapons.row(record.weapon), record.ammo)
			expect(shot).to.be.ok()
			expect(record.leadBallisticStuds).to.equal(
				Ballistics.leadStuds(shot, record.distanceStuds, record.paceStudsPerSecond)
			)

			-- ONE SHOT THAT HITS, and the zone column is `report.zone` and nothing re-derived.
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 125 })
			record = Range.recordOf(man) :: any
			expect(record.shots).to.equal(2)
			expect(record.hits).to.equal(1)
			expect(record.miss).to.equal(1)
			expect(record.zones.chest).to.equal(1)
			expect(record.lastDistanceStuds).to.equal(125)
			-- A SECOND REPORT OF THE SAME SHOT CHANGES NOTHING AT ALL: the slot is consumed, so the
			-- zone column and HITS cannot disagree (round 2, finding 2; the Reviewer's own note).
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 125 })
			record = Range.recordOf(man) :: any
			expect(record.hits).to.equal(1)
			expect(record.zones.chest).to.equal(1)

			-- THE RESET, through the same door, whitelisted like a pick: THIS player's record only.
			local other = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 105)
			tick(clock, 1)
			expect(Range.onRequest(other, { spot = 1, go = true })).to.equal(true)
			Range.onShotResolved({ shooter = other, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			expect((Range.recordOf(other) :: any).shots).to.equal(1)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, reset = true })).to.equal(true)
			expect((Range.recordOf(man) :: any).shots).to.equal(0)
			expect((Range.recordOf(other) :: any).shots).to.equal(1)
			Range.stop()
		end)

		it("keeps the kind with its species, and reads the columns off the animal it spawns", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 109)

			-- PICKING THE DEER WITH NO KIND NAMED TAKES THE DEER'S FIRST KIND: `male` left on the
			-- trial made `release` spawn a BOAR under the deer's six columns (round 1, finding 1).
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, species = "reddeer" })).to.equal(true)
			local trial = Range.trialOf(1) :: any
			expect(trial.species).to.equal("reddeer")
			local deerKinds = Range.kindsFor("reddeer")
			local isDeerKind = false
			for _, kind in ipairs(deerKinds) do
				if kind == trial.kind then
					isDeerKind = true
				end
			end
			expect(isDeerKind).to.equal(true)
			expect(trial.kind).never.to.equal("male")

			-- ...AND THE COLUMNS ARE THAT ANIMAL'S OWN, read through the injected seam and compared
			-- with the config the runtime itself resolves from the kind -- which is the thing
			-- `release` hands `spawn`. The deer has a `neck` and the boar has none.
			local record = Range.recordOf(man) :: any
			local expected = Boar.kindConfig(trial.kind, Boar.CONFIG).ZONES.ORDER
			expect(#record.zoneOrder).to.equal(#expected)
			for index, zone in ipairs(expected) do
				expect(record.zoneOrder[index]).to.equal(zone)
			end
			expect(record.zones.neck).to.be.ok()
			expect(#record.zoneOrder).never.to.equal(#Boar.CONFIG.ZONES.ORDER)

			-- A KIND FROM THE OTHER ANIMAL IS REFUSED, because the door asks the species of THIS
			-- request and not the trial's previous one.
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, species = "boar", kind = "stag" })).to.equal(false)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, species = "boar", kind = "female" })).to.equal(true)
			expect((Range.trialOf(1) :: any).kind).to.equal("female")
			expect(#(Range.recordOf(man) :: any).zoneOrder).to.equal(#Boar.CONFIG.ZONES.ORDER)
			Range.stop()
		end)

		it("counts only the hits of the shots it counted, and forgets a player who leaves", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 110)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, go = true })).to.equal(true)

			-- A HIT WITH NO SHOT OF THIS MODULE'S IS NOT THE RANGE'S HIT. `Weapon.HitReported` fires
			-- for every hit in the place, so a boar shot in the DRIVE used to raise HITS on a board
			-- the player had opened earlier -- hits with no shots (round 1, finding 2).
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 40 })
			local record = Range.recordOf(man) :: any
			expect(record.shots).to.equal(0)
			expect(record.hits).to.equal(0)
			expect(record.zones.chest).to.equal(0)

			-- ...AND THE HIT OF A SHOT IT DID COUNT STILL COUNTS.
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 125 })
			record = Range.recordOf(man) :: any
			expect(record.shots).to.equal(1)
			expect(record.hits).to.equal(1)

			-- THE RECORD LEAVES WITH HIM, and a later stray hit finds nothing.
			Range.forget(man)
			expect(Range.recordOf(man)).to.equal(nil)
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 40 })
			expect(Range.recordOf(man)).to.equal(nil)
			Range.stop()
		end)

		it("writes NOTHING when any word of the request is refused", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 111)
			local before = Range.trialOf(1) :: any

			-- THE MENU'S OWN CLICK ORDER: ANIMAL = REDDEER with the KIND row still showing the boar's
			-- words. The door refuses the pair -- and must leave the trial exactly as it found it
			-- (round 2, finding 1: species was written before kind was judged).
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, species = "reddeer", kind = "male", go = true })).to.equal(false)
			local after = Range.trialOf(1) :: any
			expect(after.species).to.equal(before.species)
			expect(after.kind).to.equal(before.kind)

			-- ...AND THE SAME FOR A GUN WITH A LOAD IT CANNOT FIRE: the pair that made
			-- `Ballistics.shotFor` return nil must never reach the trial.
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, weapon = "rifle", ammo = "Buck" })).to.equal(false)
			after = Range.trialOf(1) :: any
			expect(after.weapon).to.equal(before.weapon)
			expect(after.ammo).to.equal(before.ammo)
			expect(Ballistics.shotFor(Weapons.row(after.weapon), after.ammo)).to.be.ok()

			-- ...and a request whose every word passes still applies, so the two passes did not
			-- simply stop the door working.
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, species = "reddeer", go = true })).to.equal(true)
			expect((Range.trialOf(1) :: any).species).to.equal("reddeer")
			Range.stop()
		end)

		it("never counts a hit landed away from the mat, however old the last range shot is", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local mat = RangeData.matPosition(ANCHOR, 1, LAYOUT)
			local man = manOn(mat, 112)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, go = true })).to.equal(true)

			-- A RANGE SHOT THAT MISSED: the slot is open and `record.shots` is 1.
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			expect((Range.recordOf(man) :: any).shots).to.equal(1)

			-- HE WALKS INTO THE DRIVE AND HITS A BOAR THERE. `Weapon.HitReported` is the same signal,
			-- so without the `mayShoot` gate AND the consumed slot this landed on the range board
			-- (round 2, finding 2: `pending.shots` can never go stale on its own).
			local character = (man :: any).Character
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			rootPart.Position = mat + Vector3.new(600, 0, 0)
			expect(Range.mayShoot(man)).to.equal(false)
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 30 })
			local record = Range.recordOf(man) :: any
			expect(record.shots).to.equal(1)
			expect(record.hits).to.equal(0)
			expect(record.zones.chest).to.equal(0)

			-- AND BACK ON THE MAT, THE OLD SLOT IS STALE: a hit minutes after the shot that opened it
			-- is some other shot somewhere else, so `HIT_WINDOW_SECONDS` expires it.
			rootPart.Position = mat
			expect(Range.mayShoot(man)).to.equal(true)
			clock.t += Range.CONFIG.HIT_WINDOW_SECONDS + 1
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 125 })
			record = Range.recordOf(man) :: any
			expect(record.hits).to.equal(0)
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 125 })
			record = Range.recordOf(man) :: any
			expect(record.shots).to.equal(2)
			expect(record.hits).to.equal(1)
			expect(record.zones.chest).to.equal(1)
			Range.stop()
		end)

		it("hands back the stand provider it is replacing", function()
			-- THE PRODUCER THE COMPOSED BASE IS MADE OF (task 301): `setStandProvider` returned nothing,
			-- so `installOver` captured a nil base and the composition answered nil everywhere
			-- (reviews/task-298/RESULT.md finding 1). The other three setters have had this shape since
			-- tasks 150 and 298.
			local function first(_player)
				return nil
			end
			local function second(_player)
				return nil
			end
			local was = Weapon.setStandProvider(first)
			expect(Weapon.setStandProvider(second)).to.equal(first)
			expect(Weapon.setStandProvider(nil)).to.equal(second)
			expect(Weapon.setStandProvider(was)).to.equal(nil)
		end)

		it("keeps the drive's stand off the mat and drops it on the mat, through the boot's own compose", function()
			-- MEASURED IN DEV, 2026-10-27: a real `FireRequest` from the mat came back
			-- `refused=off-stand notice=NOT IN YOUR STAND`, because the drive had dealt the lone
			-- player a stand 1200 studs away. Design 7.4's *"no stand -> no rule"* is false whenever
			-- a drive is also running, which is Karen's place.
			--
			-- IT INSTALLS A REAL BASE AND COMPOSES THROUGH `Range.installOver` -- the function
			-- `RangeBoot.compose` calls -- rather than hand-building the base, which is how round 3's
			-- own regression stayed green (reviews/task-298/RESULT.md finding 2).
			Range.stop()
			local fake = newFakeBoars()
			local _, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local mat = RangeData.matPosition(ANCHOR, 1, LAYOUT)
			local onMat = manOn(mat, 113)
			local away = manOn(mat + Vector3.new(600, 0, 0), 114)
			local driveArea = { centre = Vector3.new(0, 0, 0), radius = 24 }
			local function base(_player)
				return driveArea
			end

			local wasStand = Weapon.setStandProvider(base)
			local uninstall = Range.installOver(nil)
			-- THE COMPOSED PROVIDER, READ OUT OF THE OWNER THAT HOLDS IT, then put straight back.
			local composedStand = Weapon.setStandProvider(nil)
			Weapon.setStandProvider(composedStand)
			expect(type(composedStand)).to.equal("function")
			expect(composedStand).never.to.equal(base)

			-- OFF THE MAT: the drive's own area survives, and the rule still refuses a shot outside it.
			expect(composedStand(away)).to.equal(driveArea)
			expect(Rules.outsideStand(mat, composedStand(away))).to.equal(true)
			expect(Rules.outsideStand(Vector3.new(0, 0, 0), composedStand(away))).to.equal(false)
			-- ON THE MAT: no area, so `Rules.outsideStand` answers false by its own first line and the
			-- range shot is allowed.
			expect(composedStand(onMat)).to.equal(nil)
			expect(Rules.outsideStand(mat, composedStand(onMat))).to.equal(false)

			-- UNINSTALL PUTS THE BASE BACK, the same identity that was installed.
			uninstall()
			expect(Weapon.setStandProvider(base)).to.equal(base)
			-- WITH NO BASE PROVIDER nothing is invented: still no area.
			expect(Range.standOver(nil)(away)).to.equal(nil)
			Weapon.setStandProvider(wasStand)
			Range.stop()
		end)

		it("says he is at the spot by the prompt's own reach", function()
			-- THE CLIENT'S CLOSER AND THE SERVER'S REFUSAL ARE THE SAME MEASUREMENT: `Hud.step`
			-- feeds this to `RangePanel.setNear`, which is what gives the two doors back
			-- (round 1, finding 3).
			local mat = RangeData.matPosition(ANCHOR, 1, LAYOUT)
			local reach = LAYOUT.PROMPT.MaxActivationDistance
			expect(RangeData.atSpot(mat, mat, LAYOUT)).to.equal(true)
			expect(RangeData.atSpot(mat, mat + Vector3.new(reach - 1, 0, 0), LAYOUT)).to.equal(true)
			expect(RangeData.atSpot(mat, mat + Vector3.new(reach + 1, 0, 0), LAYOUT)).to.equal(false)
			expect(RangeData.atSpot(mat, nil, LAYOUT)).to.equal(false)
			expect(RangeData.atSpot(nil, mat, LAYOUT)).to.equal(false)
		end)

		it("signs the miss gap against the target's own direction, both ways", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 106)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.TROT })).to.equal(true)
			advance(fake, clock, 2)
			local animal = fake.only()
			expect(animal).to.be.ok()
			local target = (animal :: any).position
			local trial = Range.trialOf(1) :: any

			-- A SHOT 4 STUDS BEHIND A TARGET RUNNING EAST (an odd leg, +X) IS NEGATIVE, and the same
			-- 4 studs on a WEST leg is positive -- the gap is projected onto the target's travel, so
			-- the two directions read OPPOSITE signs for the same world-space error.
			local east = Range.gapStuds(trial, target - Vector3.new(4, 0, 0), target)
			expect(east).to.be.near(-4, 0.001)
			local west = table.clone(trial)
			west.leg = trial.leg + 1
			expect(Range.gapStuds(west, target - Vector3.new(4, 0, 0), target)).to.be.near(4, 0.001)
			-- STAND HAS NO GAP: nothing is moving, so "behind" has no meaning.
			local standing = table.clone(trial)
			standing.pace = RangeData.WORD.STAND
			expect(Range.gapStuds(standing, target - Vector3.new(4, 0, 0), target)).to.equal(nil)
			Range.stop()
		end)
	end)

	describe("Range.mayShoot", function()
		it("is false with the range not started, and false for nil and for a man with no character", function()
			Range.stop()
			expect(Range.mayShoot(manAt(RangeData.matPosition(ANCHOR, 1, LAYOUT)))).to.equal(false)
			local _, now = newClock()
			expect(startRange(newFakeBoars(), now)).to.equal(true)
			expect(Range.mayShoot(nil)).to.equal(false)
			expect(Range.mayShoot(manAt(nil))).to.equal(false)
			Range.stop()
		end)

		it("is TRUE on the mat and FALSE one stride off it", function()
			Range.stop() -- a sibling case that failed before its own stop must not decide this one
			local _, now = newClock()
			expect(startRange(newFakeBoars(), now)).to.equal(true)
			local mat = RangeData.matPosition(ANCHOR, 1, LAYOUT)
			expect(Range.mayShoot(manAt(mat))).to.equal(true)
			local off = mat + Vector3.new(LAYOUT.MAT.size.X, 0, 0)
			expect(Range.spotAt(off)).to.equal(nil)
			expect(Range.mayShoot(manAt(off))).to.equal(false)
			Range.stop()
			-- ...AND IT IS FALSE AGAIN THE MOMENT THE RANGE IS GONE, which is what the weapon's own
			-- 2 s arming sweep re-asks and what takes the loan back.
			expect(Range.mayShoot(manAt(mat))).to.equal(false)
		end)
	end)

	describe("the two relaxations, composed", function()
		it("arms a man on the mat whose drive refuses him, and leaves everybody else's answer alone", function()
			Range.stop()
			local _, now = newClock()
			expect(startRange(newFakeBoars(), now)).to.equal(true)
			local onMat = manAt(RangeData.matPosition(ANCHOR, 1, LAYOUT))
			local offMat = manAt(ANCHOR + Vector3.new(0, 0, 400))

			-- THE DRIVE SAYS NO TO EVERYBODY: today's lobby.
			local asked = 0
			local arming = Range.armingOver(function(_player)
				asked += 1
				return false
			end)
			expect(arming(onMat)).to.equal(true)
			expect(arming(offMat)).to.equal(false)
			expect(asked).to.equal(1) -- the man on the mat never reaches the drive's policy

			-- ...AND A DRIVE THAT SAYS YES IS UNCHANGED, which is the identity the design claims.
			expect(Range.armingOver(function(_player)
				return true
			end)(offMat)).to.equal(true)

			-- THE TRIGGER, BETWEEN DRIVES. `Rules.driveClosed` refuses on an explicit `false`.
			local driveOpen = Range.driveOpenOver(function(_player)
				return false
			end)
			expect(driveOpen(onMat)).to.equal(true)
			expect(driveOpen(offMat)).to.equal(false)
			-- UNWIRED STAYS "NOBODY SAID", the default every provider on `Weapon` takes.
			expect(Range.driveOpenOver(nil)(offMat)).to.equal(nil)
			expect(Range.driveOpenOver(nil)(onMat)).to.equal(true)
			Range.stop()
		end)

		it("lends all four guns and the endless shells at a spot, and NOTHING off it", function()
			Range.stop()
			local _, now = newClock()
			expect(startRange(newFakeBoars(), now)).to.equal(true)
			local onMat = manAt(RangeData.matPosition(ANCHOR, 1, LAYOUT))
			local offMat = manAt(ANCHOR + Vector3.new(0, 0, 400))

			-- OFF THE MAT THE BASE'S ANSWER IS HANDED BACK UNTOUCHED, nil included: a world with no
			-- shop is bit-for-bit what it was.
			expect(Range.entitlementOver(nil)(offMat)).to.equal(nil)
			local bought = { ["licence.reddeer"] = true }
			expect(Range.entitlementOver(function(_player)
				return bought
			end)(offMat)).to.equal(bought)

			-- ON THE MAT: every gun in `Weapons.ORDER`, through the SHIPPED loadout rule.
			local owned = Range.entitlementOver(nil)(onMat)
			expect(type(owned)).to.equal("table")
			expect(#Shop.loadoutFrom(Weapons.ids(), Weapons.PRIMARY, owned)).to.equal(#Weapons.ORDER)
			-- EVERY GUN BUT THE PRIMARY IS *OWNED*; the primary is in the loadout by the shipped
			-- rule and has no row to own (*"The primary is never taken away"*, `Shop.loadoutFrom`).
			for _, id in ipairs(Weapons.ORDER) do
				if id ~= Weapons.PRIMARY then
					expect(Shop.ownsWeapon(owned, id)).to.equal(true)
				end
			end
			-- ...AND THE LOAN IS A LOAN: what he had bought is still there, and nothing he had not
			-- bought came with it.
			local withLicence = Range.entitlementOver(function(_player)
				return { ["licence.reddeer"] = true }
			end)(onMat)
			expect((withLicence :: any)["licence.reddeer"]).to.equal(true)
			-- THE WHOLE SET, ROW BY ROW, and not one id (round 1, finding 1): every lent row grants
			-- a gun, a cartridge or the endless shells and NOTHING else -- a BUNDLE's merged grants
			-- carry a weapon AND a drive gun AND the high seat, and the one-id check passed anyway.
			for id in pairs(Range.LOAN) do
				local grants = (Shop.anyRow(id) :: any).grants
				expect(grants.weapon ~= nil or grants.ammo ~= nil or grants.unlimitedAmmo == true).to.equal(true)
				for _, field in ipairs(Shop.GRANT_FIELDS) do
					if field ~= "weapon" and field ~= "ammo" and field ~= "unlimitedAmmo" then
						expect(grants[field]).to.equal(nil)
					end
				end
			end
			-- ...AND THE THREE THINGS A LOAN IS NOT, asked of the shipped readers themselves.
			expect(Shop.grantsDriveGun(owned)).to.equal(false)
			expect(Shop.grantsAlwaysHunter(owned)).to.equal(false)
			expect(Shop.grantsHighSeat(owned)).to.equal(false)

			-- THE ENDLESS SHELLS ARE THE SHIPPED `ammo.unlimited` ENTITLEMENT AND NOT A SECOND
			-- COUNTER: `Shop.startFor` is the one function `Weapon.grant` asks, and it fills the
			-- `unlimited` pockets `StateMachine` already reads.
			expect(Shop.grantsUnlimitedAmmo(owned)).to.equal(true)
			for _, id in ipairs(Weapons.ORDER) do
				local start = Shop.startFor(Weapons.row(id), owned)
				expect(start.unlimited).to.be.ok()
				expect((start.unlimited :: any)[start.ammo]).to.equal(true)
			end
			Range.stop()
		end)

		-- KAREN, 2026-10-27: *"amunition is endless"*. MEASURED over 30 shots through the shipped
		-- reducer, with the same 30 pulls WITHOUT the loan as the control.
		it("never spends a shell over 30 shots at a spot -- and spends them without the loan", function()
			Range.stop()
			local _, now = newClock()
			expect(startRange(newFakeBoars(), now)).to.equal(true)
			local owned = Range.entitlementOver(nil)(manAt(RangeData.matPosition(ANCHOR, 1, LAYOUT)))

			local row = Weapons.ROWS[Weapons.PRIMARY]
			local function pocket(reserve): number
				local left = 0
				for _, count in pairs(reserve) do
					left += count
				end
				return left
			end
			-- THE REAL CYCLE of a break action, through the shipped reducer and nothing else:
			-- Fire until the barrels are spent, then Break / Load each chamber / Close. `Load` is
			-- where a pocket goes down, and `boundless` is where it does not.
			local function fire30(start): (number, number)
				local state = StateMachine.setEquipped(StateMachine.initial(row, start), true)
				local clock, fired = 0, 0
				for _ = 1, 400 do
					if fired >= 30 then
						break
					end
					clock += 5
					local shot, why = StateMachine.apply(state, { kind = "Fire" }, clock, row)
					if why == nil then
						state = shot
						fired += 1
					else
						clock += 5
						local opened, openWhy = StateMachine.apply(state, { kind = "Break" }, clock, row)
						if openWhy == nil then
							state = opened
						end
						local loadedAny = false
						for _ = 1, #state.barrels do
							clock += 5
							local filled, loadWhy = StateMachine.apply(state, { kind = "Load" }, clock, row)
							if loadWhy == nil then
								state = filled
								loadedAny = true
							end
						end
						clock += 5
						local closed, closeWhy = StateMachine.apply(state, { kind = "Close" }, clock, row)
						if closeWhy == nil then
							state = closed
						end
						if not loadedAny then
							break -- the pocket is empty: this is where the control run stops
						end
					end
				end
				return fired, pocket(state.reserve)
			end

			local start = Shop.startFor(row, owned)
			local before = pocket(start.reserve)
			local fired, left = fire30(start)
			expect(fired).to.equal(30)
			expect(left).to.equal(before)

			local plainFired, plainLeft = fire30(nil)
			expect(plainFired > 0).to.equal(true)
			expect(plainFired < 30).to.equal(true)
			expect(plainLeft < before).to.equal(true)
			TestKit.note(
				string.format(
					"range endless ammo: 30 pulls on the loan fired %d, pocket %d -> %d; without it %d fired, pocket %d",
					fired,
					before,
					left,
					plainFired,
					plainLeft
				)
			)
			Range.stop()
		end)
	end)

	-- ------------------------------------------------------------------ 8. Weapon.ShotResolved (8.3)
	--
	-- Task 298 step B3. A MISS publishes no `HitReported` and `ShotFired` fires at the TRIGGER, so
	-- the range needs the one fact neither carries: this shot has LANDED, and here is where. Driven
	-- through the owner's real fire path and its real flight, with `Weapon.setCast` scripting the
	-- world -- a miss, then a hit, each counted on its own.
	describe("Weapon.ShotResolved", function()
		it("fires exactly ONCE per resolved shot, for a miss AND for a hit, with an end point", function()
			local function readyShooter()
				for _ = 1, 20 do
					for _, player in ipairs(Players:GetPlayers()) do
						local snapshot = Weapon.getSnapshot(player)
						if snapshot ~= nil and snapshot.barrels[snapshot.selected] ~= "Live" then
							Weapon.refillForDrive(player, 298298)
							Weapon.onActionRequest(player, "Reload", nil, nil)
							task.wait(0.3)
							snapshot = Weapon.getSnapshot(player)
						end
						if
							snapshot ~= nil
							and snapshot.equipped == true
							and snapshot.open == false
							and (snapshot.busyFor or 0) <= 0
							and snapshot.barrels[snapshot.selected] == "Live"
						then
							return player, snapshot
						end
					end
					task.wait(0.4)
				end
				return nil, nil
			end

			local subject = readyShooter()
			if subject == nil then
				TestKit.note(
					"range ShotResolved: nobody is holding a gun that can fire, so the publish was not "
						.. "entered. NOT PROVEN in this run."
				)
				expect(Weapon.ShotResolved).to.be.ok()
				return
			end

			local character = (subject :: any).Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			expect(root).to.be.ok()
			local origin = (root :: BasePart).Position + Vector3.new(0, 2, 0)
			local direction = Vector3.new(0, 0, -1)

			local seen = {}
			local connection = Weapon.ShotResolved:Connect(function(shot)
				table.insert(seen, shot)
			end)
			-- THE RULES THAT ARE NOT ABOUT THIS CASE, out of the way for two shots and put back
			-- afterwards -- `weapon_shot.spec`'s own idiom, naming the same functions.
			Weapon.setTargetProvider(nil)
			Weapon.setStandProvider(nil)
			Weapon.setLicenceProvider(nil)
			Weapon.setSafetyLineProvider(nil)
			local wasDriveOpen = Weapon.setDriveOpenProvider(function(): boolean
				return true
			end)
			local function putBack()
				connection:Disconnect()
				Weapon.setCast(nil)
				Weapon.setTargetProvider(Match.classifyTarget)
				Weapon.setStandProvider(Match.standAreaFor)
				Weapon.setSafetyLineProvider(Match.lineIsUnsafe)
				Weapon.setDriveOpenProvider(wasDriveOpen)
			end

			-- 1. A MISS: the cast answers nothing, so the pellets fly to the ammo's range cap.
			Weapon.setCast(function()
				return nil
			end)
			local missWhy = Weapon.onFireRequest(subject, { origin = origin, direction = direction })
			local deadline = os.clock() + 3
			while #seen < 1 and os.clock() < deadline do
				task.wait(0.05)
			end
			if #seen < 1 then
				putBack()
				TestKit.note("range ShotResolved: the miss was refused -- " .. tostring(missWhy))
			end
			expect(#seen).to.equal(1)
			local miss = seen[1]
			expect(#miss.hitParts).to.equal(0)
			expect(miss.shooterUserId).to.equal(subject.UserId)
			expect(typeof(miss.endPoint)).to.equal("Vector3")
			expect(miss.reachedStuds > 0).to.equal(true)
			expect(type(miss.resolvedAtServerTime)).to.equal("number")
			expect(miss.resolvedAtServerTime > 0).to.equal(true)
			-- THE END POINT IS DOWNRANGE, not the muzzle: the flight measured it. AND IT IS ON THE
			-- PATH: a straight line from the muzzle can never be longer than the curved path the
			-- bullet flew, which is what caught the unclamped `nextPosition` this task (106.3
			-- studs from the muzzle for a 100.0-stud cap).
			local reach = (miss.endPoint - miss.muzzle).Magnitude
			expect(reach > 1).to.equal(true)
			expect(reach <= miss.reachedStuds + 0.01).to.equal(true)

			-- 2. A HIT, on a part of this spec's own, 40 studs out.
			local target = Instance.new("Part")
			target.Name = "ShotResolvedSpecTarget"
			target.Size = Vector3.new(4, 4, 1)
			target.Anchored = true
			target.CanCollide = false
			target.CanQuery = false
			target.Position = origin + direction * 40
			target.Parent = workspace
			Weapon.setCast(function(castOrigin: Vector3, castVector: Vector3)
				return {
					instance = target,
					position = castOrigin + castVector,
					normal = -direction,
					distance = castVector.Magnitude,
					material = Enum.Material.Plastic,
				}
			end)

			local ready = readyShooter()
			if ready == nil then
				putBack()
				target:Destroy()
				TestKit.note("range ShotResolved: the miss was proven; the gun could not be reloaded for the hit.")
				expect(#seen).to.equal(1)
				return
			end
			Weapon.onFireRequest(subject, { origin = origin, direction = direction })
			deadline = os.clock() + 3
			while #seen < 2 and os.clock() < deadline do
				task.wait(0.05)
			end
			putBack()
			target:Destroy()

			expect(#seen).to.equal(2)
			local hit = seen[2]
			expect(#hit.hitParts >= 1).to.equal(true)
			expect(hit.hitParts[1]).to.equal(target)
			expect(typeof(hit.endPoint)).to.equal("Vector3")
			expect(hit.resolvedAtServerTime >= miss.resolvedAtServerTime).to.equal(true)
			TestKit.note(
				string.format(
					"range ShotResolved: miss reached %.1f studs (end %.1f from the muzzle), hit on %s at %.1f studs",
					miss.reachedStuds,
					reach,
					hit.hitParts[1].Name,
					hit.reachedStuds
				)
			)
		end)
	end)
	-- ------------------------------------------------- 9. KAREN'S PLACE: THE FOREST ROW (step B6)
	--
	-- The anchor is MEASURED, not chosen here: design 4.2's instrument (a raycast grid, 8-stud
	-- spacing, 504 samples over the 160 x 185 footprint) run by the Director over Karen's own
	-- ground in Edit and again in Play. Best centre (2650, -3300), spread 11.6 studs, 0 non-terrain
	-- hits; the firing line stands at the footprint's NORTH end and the lane runs SOUTH, away from
	-- the lodge, the pads and the gathering yard.
	--   evidence: <runs-dir>/evidence/b6-anchor/SUMMARY.md (grid1.txt, grid2.txt, grid-play.txt)
	describe("the forest row: a range beside Karen's lodge (step B6)", function()
		-- THE MEASURED RECTANGLE, from the SUMMARY above. The range must fit inside what was sampled.
		local MEASURED = { minX = 2570, maxX = 2730, minZ = -3392, maxZ = -3208 }
		-- A SHELF THAT IS EXACT IN FLOAT32, because `Vector3` stores floats and 147.3 does not survive
		-- the trip: the case is about where the parts are laid, not about rounding.
		local FAKE_SHELF = 147.25
		-- ...AND IT SLOPES, because Karen's does: the measured spread over this footprint is 11.6
		-- studs, and a CONSTANT reader cannot tell a range that follows the ground from one that
		-- lays everything on the single number it read at the anchor (round 1, findings 1 and 2).
		-- The two gradients are exact in binary (1/16 and 1/32), so nothing here is about rounding,
		-- and over the footprint they span 8.75 + 5.0 = 13.75 studs.
		local function slopedGround(x: number, z: number): number
			return FAKE_SHELF + (z + 3216) * 0.0625 + (x - 2650) * 0.03125
		end

		-- EVERY PART BUILD MAKES, BY NAME, so the Director can enumerate them under Workspace.Range
		-- and read each one's LOWEST point against the terrain ray under it (L-086).
		local function partsOf(folder: Instance)
			local out = {}
			for _, child in ipairs(folder:GetDescendants()) do
				if child:IsA("BasePart") then
					table.insert(out, child)
				end
			end
			return out
		end

		local function footprintOf(parts)
			local box = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
			for _, part in ipairs(parts) do
				box.minX = math.min(box.minX, part.Position.X - part.Size.X / 2)
				box.maxX = math.max(box.maxX, part.Position.X + part.Size.X / 2)
				box.minZ = math.min(box.minZ, part.Position.Z - part.Size.Z / 2)
				box.maxZ = math.max(box.maxZ, part.Position.Z + part.Size.Z / 2)
			end
			return box
		end

		-- ONE PATH, TWO DIRECTIONS (L-093). The DEV row runs the lane +z and Karen's runs it -z, and
		-- the only difference between the two calls is the ROW: no second code path, and no branch
		-- on a world's name. Both arms are entered here, by parameter.
		local function buildWith(row, groundAt)
			local parent = Instance.new("Folder")
			local built, why = Range.Build.build({ parent = parent, row = row, layout = LAYOUT, groundAt = groundAt })
			return built, why, parent
		end

		it("lays every part on the ground it is handed, both worlds, and never a typed Y", function()
			local asked = {}
			local forestGround = function(x: number, z: number)
				table.insert(asked, Vector3.new(x, 0, z))
				return slopedGround(x, z)
			end
			local cases = {
				{
					name = "forest-test",
					row = FOREST_ROW,
					ground = forestGround,
					shelf = FAKE_SHELF,
					dir = -1,
					sloped = true,
				},
				-- The DEV arm, RE-ENTERED and not assumed: its plate still lays its own shelf and it
				-- never asks a ground reader (plate is data, not a branch in the caller).
				{ name = "map:v1", row = DEV_ROW, ground = nil, shelf = 0, dir = 1, sloped = false },
			}
			for _, case in ipairs(cases) do
				local built, why, parent = buildWith(case.row, case.ground)
				expect(why).to.equal(nil)
				expect(built).to.be.ok()
				local b = built :: any
				expect(b.shelf).to.equal(case.shelf)
				expect(b.anchor.Y).to.equal(case.shelf)
				local parts = partsOf(b.folder)
				expect(#parts >= 4).to.equal(true)
				-- NO PART UNDER THE GROUND AND NONE FLOATING, MEASURED THE WAY KAREN SEES IT (rule
				-- E, L-086): the LOWEST face of each part against the ground under EVERY sample of
				-- its own footprint -- a 9 x 9 scan, which is not the five points `Build` reads, so
				-- the assertion is not a transcription of the code. The part must reach the lowest
				-- of them (nothing floats) and keep its full height above the highest.
				for _, part in ipairs(parts) do
					local bottom = part.Position.Y - part.Size.Y / 2
					local top = part.Position.Y + part.Size.Y / 2
					if part.Name == "Plate" then
						expect(math.abs(top - case.shelf) < 1e-3).to.equal(true)
					elseif not case.sloped then
						expect(math.abs(bottom - case.shelf) < 1e-3).to.equal(true)
					else
						local lo, hi = math.huge, -math.huge
						for ix = 0, 8 do
							for iz = 0, 8 do
								local gx = part.Position.X + (ix / 8 - 0.5) * part.Size.X
								local gz = part.Position.Z + (iz / 8 - 0.5) * part.Size.Z
								local g = slopedGround(gx, gz)
								lo = math.min(lo, g)
								hi = math.max(hi, g)
							end
						end
						local nominal = if part.Name == "Berm"
							then LAYOUT.BERM.size.Y
							elseif part.Name == "Mat" then LAYOUT.MAT.size.Y
							else LAYOUT.SCREEN.size.Y
						expect(math.abs(bottom - lo) < 1e-2).to.equal(true)
						expect(top >= hi + nominal - 1e-2).to.equal(true)
					end
				end
				-- THE LANE RUNS THE ROW'S OWN WAY. Downrange is a signed data field: the berm is the
				-- furthest thing downrange of the mat, on the row's own side of the firing line.
				local anchor = b.anchor
				local lane = RangeData.laneCentre(anchor, LAYOUT, case.dir)
				expect(lane.Z - anchor.Z).to.equal(case.dir * LAYOUT.DISTANCE_STUDS)
				local berm = (b.folder :: any):FindFirstChild("Berm")
				expect(berm).to.be.ok()
				expect((berm.Position.Z - anchor.Z) * case.dir > LAYOUT.DISTANCE_STUDS).to.equal(true)
				-- ...and NOTHING is built behind the shooter by more than his own mat.
				for _, part in ipairs(parts) do
					local behind = (anchor.Z - part.Position.Z) * case.dir
					expect(behind <= LAYOUT.MAT.size.Z).to.equal(true)
				end
				parent:Destroy()
			end
			-- THE GROUND WAS READ UNDER EVERY PART -- five samples each, four parts, plus the one
			-- `shelfAt` takes at the anchor -- and never outside the rectangle that was measured.
			expect(#asked >= 5 * 4).to.equal(true)
			for _, at in ipairs(asked) do
				expect(at.X >= MEASURED.minX and at.X <= MEASURED.maxX).to.equal(true)
				expect(at.Z >= MEASURED.minZ and at.Z <= MEASURED.maxZ).to.equal(true)
			end
		end)

		it("keeps the whole range inside the rectangle that was measured", function()
			local built, _, parent = buildWith(FOREST_ROW, function()
				return FAKE_SHELF
			end)
			local b = built :: any
			local parts = partsOf(b.folder)
			local names = {}
			for _, part in ipairs(parts) do
				table.insert(names, part.Name)
			end
			table.sort(names)
			local box = footprintOf(parts)
			expect(box.minX >= MEASURED.minX).to.equal(true)
			expect(box.maxX <= MEASURED.maxX).to.equal(true)
			expect(box.minZ >= MEASURED.minZ).to.equal(true)
			expect(box.maxZ <= MEASURED.maxZ).to.equal(true)
			TestKit.note(
				string.format(
					"range forest footprint: x %.1f..%.1f z %.1f..%.1f (measured x %d..%d z %d..%d); parts %s",
					box.minX,
					box.maxX,
					box.minZ,
					box.maxZ,
					MEASURED.minX,
					MEASURED.maxX,
					MEASURED.minZ,
					MEASURED.maxZ,
					table.concat(names, ", ")
				)
			)
			parent:Destroy()
		end)

		it("stands clear of all seven lobby rectangles -- the range is the eighth", function()
			local anchor = Vector3.new(LOBBY_ANCHOR.x, 0, LOBBY_ANCHOR.z)
			local rects = {}
			-- THE THREE GROUND PADS, read from Lobby.CONFIG.FIELD.PADS itself (the yard, the road
			-- and the gathering yard) and never retyped: a second copy is two definitions of one fact.
			for _, pad in ipairs(LOBBY_CFG.FIELD.PADS) do
				table.insert(rects, {
					name = pad.NAME,
					minX = anchor.X + pad.OFFSET.X - pad.SIZE.X / 2,
					maxX = anchor.X + pad.OFFSET.X + pad.SIZE.X / 2,
					minZ = anchor.Z + pad.OFFSET.Z - pad.SIZE.Z / 2,
					maxZ = anchor.Z + pad.OFFSET.Z + pad.SIZE.Z / 2,
				})
			end
			-- ...AND THE FOUR TRUCK PADS, from Lobby.Pads.centreFor, the one writer of where they are.
			for index = 1, LOBBY_CFG.TRUCK.COUNT do
				local centre = Pads.centreFor(anchor, index, LOBBY_CFG)
				table.insert(rects, {
					name = "TruckPad" .. tostring(index),
					minX = centre.X - LOBBY_CFG.PADS.SIZE.X / 2,
					maxX = centre.X + LOBBY_CFG.PADS.SIZE.X / 2,
					minZ = centre.Z - LOBBY_CFG.PADS.SIZE.Z / 2,
					maxZ = centre.Z + LOBBY_CFG.PADS.SIZE.Z / 2,
				})
			end
			expect(#rects).to.equal(7)

			local built, _, parent = buildWith(FOREST_ROW, function()
				return FAKE_SHELF
			end)
			local b = built :: any
			-- THE FIRING LINE AND THE WHOLE DOWNRANGE CONE: the box that holds every part the range
			-- builds, which is the mat, the two screens, the lane between them and the berm.
			local box = footprintOf(partsOf(b.folder))
			local worst = math.huge
			local worstName = "--"
			for _, rect in ipairs(rects) do
				local gapX = math.max(rect.minX - box.maxX, box.minX - rect.maxX)
				local gapZ = math.max(rect.minZ - box.maxZ, box.minZ - rect.maxZ)
				local gap = math.max(gapX, gapZ)
				expect(gap > 0).to.equal(true)
				if gap < worst then
					worst = gap
					worstName = rect.name
				end
			end
			TestKit.note(
				string.format("range forest: nearest lobby rectangle is %s, %.1f studs away", worstName, worst)
			)
			parent:Destroy()
		end)

		it("leads the target SOUTH of the mat when the owner is started on Karen's row", function()
			-- FINDING 3, round 1: the owner's half of the direction -- `state.downrange`, fed to the
			-- five lane calls that decide where a target is RELEASED and LED -- was only ever driven
			-- with the DEV row, where the sign is the default. Here the owner is started on the
			-- forest row: with the sign dropped the target would be released 125 studs NORTH of the
			-- mat, behind the shooter.
			local fake = newFakeBoars()
			local clock, now = newClock()
			local root = Instance.new("Folder")
			local row = FOREST_ROW :: any
			local ok = Range.start({
				enabled = true,
				anchor = row,
				root = root,
				groundAt = slopedGround,
				boars = fake,
				now = now,
			})
			expect(ok).to.equal(true)
			advance(fake, clock, 4)
			local animal = fake.only()
			expect(animal).to.be.ok()
			-- RELEASED SOUTH OF THE MAT, by the whole distance of the lane.
			expect((animal :: any).position.Z < row.z - LAYOUT.DISTANCE_STUDS + 1).to.equal(true)
			-- ...AND LED SOUTH as well: every order the owner issued is downrange, never behind him.
			expect(#fake.leads >= 1).to.equal(true)
			for _, lead in ipairs(fake.leads) do
				expect(lead.point.Z < row.z).to.equal(true)
			end
			TestKit.note(
				string.format(
					"range forest owner: target released at z %.0f, %d order(s), all south of the mat at z %d",
					(animal :: any).position.Z,
					#fake.leads,
					row.z
				)
			)
			Range.stop()
			root:Destroy()
		end)

		it("keeps an ORDERED target alive on Karen's field -- the real runtime, not the rail", function()
			-- ROUND 2, FINDING 1, PROVED WITH THE REAL `Brain`: the fake rail never despawns, so only
			-- `Boar.newRuntime` can see an exit line on the wrong side. At `b8e83b32` the forest
			-- field's `exitZ` was -2816 and the lane is at z -3341, so the first order despawned the
			-- target as `escaped` and `statusOf` went nil.
			local parent = Instance.new("Folder")
			parent.Name = "RangeForestFieldSpec"
			parent.Parent = Workspace
			local row = FOREST_ROW :: any
			local dir = RangeData.downrangeOf(row)
			local anchor = Vector3.new(row.x, 0, row.z)
			local field = RangeData.fieldFor(anchor, LAYOUT, dir)
			local world = Boar.defaultWorld(field)
			world.parent = parent
			world.folderName = "RangeTargets"
			world.threats = function()
				return {}
			end
			local line = table.clone(Boar.CONFIG.LINE)
			line.ENABLED = true
			world.config = {
				LINE = line,
				SENSE = { ENABLED = false },
				KINDS = { ENABLED = true },
				maxBoars = Range.CONFIG.MAX_TARGETS,
			}
			local runtime = Boar.newRuntime(world)
			local from = RangeData.laneEnds(anchor, LAYOUT, 2, dir)
			local handle = runtime:spawn(from, "male")
			expect(handle).to.be.ok()
			local id = (handle :: any).id
			-- ORDERED, which is the half of `_outcome`'s test the range always satisfies.
			expect(runtime:leadTo(id, RangeData.laneEnds(anchor, LAYOUT, 1, dir), speedOf("trot"))).to.equal(true)
			local DT = 1 / 30
			for _ = 1, 90 do
				runtime:step(DT)
			end
			local status = runtime:statusOf(id)
			expect(status).to.be.ok()
			expect((status :: any).alive).to.equal(true)
			expect(runtime:count()).to.equal(1)
			TestKit.note(
				string.format(
					"range forest field: ordered target alive after 3 s at z %.0f; exitZ %.0f, bounds z %.0f..%.0f",
					(status :: any).position.Z,
					field.exitZ,
					field.bounds.minZ,
					field.bounds.maxZ
				)
			)
			runtime:destroy()
			parent:Destroy()
		end)

		it("refuses nothing a man in the gathering yard is doing (design 4.2 item 5)", function()
			local anchor = Vector3.new(LOBBY_ANCHOR.x, 0, LOBBY_ANCHOR.z)
			local gather = nil
			for _, pad in ipairs(LOBBY_CFG.FIELD.PADS) do
				if pad.NAME == "Gather" then
					gather = Vector3.new(anchor.X + pad.OFFSET.X, 0, anchor.Z + pad.OFFSET.Z)
				end
			end
			expect(gather).to.be.ok()

			local row = FOREST_ROW :: any
			local dir = RangeData.downrangeOf(row)
			local mat = Vector3.new(row.x, 0, row.z)
			local people = { { userId = 4242, position = gather :: Vector3 } }
			local LOCK = {
				SAFETY_LOCK_ENABLED = true,
				SAFETY_LOCK_STUDS = Match.CONFIG.SAFETY_LOCK_STUDS,
				SAFETY_MISS_STUDS = Match.CONFIG.SAFETY_MISS_STUDS,
				SAFETY_RANGE_STUDS = Match.CONFIG.SAFETY_RANGE_STUDS,
				SAFETY_BODY_STUDS = Match.CONFIG.SAFETY_BODY_STUDS,
			}
			local downrange = {
				userId = 1,
				muzzle = mat,
				aim = Vector3.new(0, 0, dir),
				stopAt = LOCK.SAFETY_RANGE_STUDS,
				at = 0,
			}
			expect(Match.lineUnsafeFor(downrange, people, LOCK)).to.equal(false)
			-- ...AND THE RULE IS LIVE, not switched off: turn round and the same man refuses the shot.
			local atHim = {
				userId = 1,
				muzzle = mat,
				aim = ((gather :: Vector3) - mat).Unit,
				stopAt = LOCK.SAFETY_RANGE_STUDS,
				at = 0,
			}
			expect(Match.lineUnsafeFor(atHim, people, LOCK)).to.equal(true)
			TestKit.note(
				string.format(
					"range forest: the gathering yard is %.0f studs from the mat, %.0f of it downrange",
					((gather :: Vector3) - mat).Magnitude,
					math.abs((gather :: Vector3).Z - mat.Z)
				)
			)
		end)
	end)
end
