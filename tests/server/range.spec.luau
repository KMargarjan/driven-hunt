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
local HighSeats = require(ReplicatedStorage:WaitForChild("HighSeats"))
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

	-- A LAYOUT WITH ONE FIELD CHANGED, so a case can enter an arm the shipped data does not sit on.
	-- `LAYOUT` is deep-frozen (there is no run-time writer), so this copies.
	local function layoutWith(overrides)
		local copy = table.clone(LAYOUT)
		for key, value in pairs(overrides) do
			copy[key] = value
		end
		return copy
	end

	-- A MAN AT A STATION, AS THE OWNER MEASURES ONE (step B7): a Character with a
	-- `HumanoidRootPart`, and nothing else. `Range`'s `playerSpot` reads that part's Position and
	-- asks `Range.spotAt`, so a case that wants a man at station 2 stands him on station 2's mat.
	local function manOnMat(spot: number, row: any?)
		local at = row or DEV_ROW
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = RangeData.matPosition(Vector3.new(at.x, 0, at.z), spot, LAYOUT)
		root.Parent = character
		return { UserId = 1000 + spot, Name = "Man" .. tostring(spot), Character = character }
	end

	-- WHO THE RANGE IS TOLD IS HERE. The list is the CASE'S, and `set` re-writes it mid-run: that
	-- is how "he arrives" and "he leaves" are driven without starting a second range.
	local function newCrowd(spots: { number }, row: any?)
		local crowd = { men = {} :: { any } }
		crowd.set = function(list: { number })
			crowd.men = {}
			for _, spot in ipairs(list) do
				table.insert(crowd.men, manOnMat(spot, row))
			end
		end
		crowd.players = function()
			return crowd.men
		end
		crowd.set(spots)
		return crowd
	end

	local function newFakeBoars()
		local fake = {
			animals = {} :: { [string]: any },
			leads = {} :: { any },
			flyingIds = {} :: { [string]: boolean },
			spawns = 0,
			clears = 0,
			clearOnes = 0,
			lastClear = nil :: string?,
			nextId = 0,
		}
		-- A REAL TRUNK PER ANIMAL (step B5), because the shot's ignore list holds INSTANCES and the
		-- design's rule is that excluding a trunk excludes the zone parts welded under it. Each one
		-- gets a `Zone` child so "the trunk and never a zone part" can be false.
		fake.roots = Instance.new("Folder")
		fake.spawn = function(position: Vector3, kind: string?)
			fake.nextId += 1
			local id = "fake" .. tostring(fake.nextId)
			local trunk = Instance.new("Part")
			trunk.Name = "FakeTrunk_" .. id
			trunk.Anchored = true
			local zone = Instance.new("Part")
			zone.Name = "Zone"
			zone.Anchored = true
			zone.Parent = trunk
			trunk.Parent = fake.roots
			fake.animals[id] = {
				id = id,
				position = position,
				kind = kind,
				alive = true,
				want = 0,
				speed = 0,
				root = trunk,
				zone = zone,
			}
			fake.spawns += 1
			return { id = id, kind = kind }
		end
		-- THE ONE READER STEP B5 ADDED, wired exactly as `RangeBoot` wires it.
		fake.rootOf = function(id: string): Instance?
			local animal = fake.animals[id]
			return if animal ~= nil then animal.root else nil
		end
		fake.clear = function(reason: string?)
			fake.clears += 1
			fake.lastClear = reason
			fake.animals = {}
		end
		-- THE PER-ID DESPAWN STEP B7 ADDED, wired exactly as `RangeBoot` wires it. A case that wants
		-- the OLD range-wide behaviour back deletes this field (`newFakeBoars().clearOne = nil`),
		-- which is how both arms of `clearTarget` are reachable by parameter.
		fake.clearOne = function(id: string, reason: string?): boolean
			if fake.animals[id] == nil then
				return false
			end
			fake.clears += 1
			fake.clearOnes += 1
			fake.lastClear = reason
			fake.animals[id] = nil
			return true
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
		-- TASK 308: WHERE THE ANIMAL WAS WHEN THE SHOOTER DREW IT. nil until a case sets it, so
		-- every older case still takes the `statusOf` present-position fallback.
		fake.pastOf = nil :: ((string, number) -> CFrame?)?
		fake.cframeAt = function(id: string, at: number): CFrame?
			local answer = fake.pastOf
			return if answer ~= nil then answer(id, at) else nil
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
		-- SIX STATIONS MEANS SIX ANIMALS (design 5.1), so a case about ONE station's lane asks for
		-- THAT station's own animal and THAT animal's own orders, through the owner's own trial.
		-- `only` is kept for the cases that really are about there being one.
		fake.only = function()
			for _, animal in pairs(fake.animals) do
				return animal
			end
			return nil
		end
		local function targetAt(spot: number): string?
			local trial = Range.trialOf(spot) :: any
			return if trial ~= nil then trial.targetId else nil
		end
		fake.at = function(spot: number)
			local id = targetAt(spot)
			return if id ~= nil then fake.animals[id] else nil
		end
		fake.leadsAt = function(spot: number)
			local id = targetAt(spot)
			local out = {}
			for _, lead in ipairs(fake.leads) do
				if lead.id == id then
					table.insert(out, lead)
				end
			end
			return out
		end
		return fake
	end

	-- One range, started into a folder of its own, with a fake clock and a fake runtime.
	-- SIX MEN, ONE PER STATION, UNLESS THE CASE SAYS OTHERWISE (step B7). Every case written before
	-- B7 is about what the six lanes DO, and since B7 a station nobody is measured at has no animal
	-- at all -- so the default crowd is a full firing line and the occupancy cases pass their own.
	-- `solo` IS THE SHIPPED SEAM (task 313): nil leaves `Range.start` on `Range.SOLO_VIEW`, which is
	-- what every case written before 313 passes, so a case can drive BOTH states of the flag.
	local function startRange(fake, now, roll, serverTime, players, solo)
		local root = Instance.new("Folder")
		if players == nil then
			players = newCrowd({ 1, 2, 3, 4, 5, 6 }).players
		end
		local ok = Range.start({
			enabled = true,
			anchor = DEV_ROW,
			root = root,
			boars = fake,
			players = players,
			now = now,
			solo = solo,
			-- THE RING'S OWN CLOCK, separate from the owner's step clock (review round 1, finding 1):
			-- the shipped one is `GetServerTimeNow()` and the owner's is `os.clock()`, two epochs.
			serverTime = serverTime,
			roll = roll,
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

	-- THE ANIMAL THIS STATION IS RUNNING RIGHT NOW, waiting out a hand-off if one is in flight.
	-- Since task 321 a pass retires its animal and the next is released on the same scan tick, but a
	-- target the owner finds already gone (`lostTargets`) is re-released on the tick AFTER -- so a
	-- case that wants THE animal may land on a tick with none, and that is the loop, not a defect.
	local function animalAt(fake, clock, spot: number): any
		for _ = 1, 30 do
			local here = fake.at(spot)
			if here ~= nil then
				return here
			end
			advance(fake, clock, 1 / Range.CONFIG.STEP_HZ)
		end
		return nil
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
			-- ...AND KAREN'S PLACE NOW HAS ONE, STRAIGHT OUT OF THE SHOP DOOR (task 315, design 2).
			-- Karen, 2026-10-30: *"shooting range can be moved there that I can directly from shop
			-- walk to shooting range same distance but straight"*.
			--
			-- ASSERTED BY ITS DERIVED PROPERTIES AND NOT BY TWO LITERALS, which is the point: two
			-- typed numbers say nothing about whether the row is still the right row. The station
			-- row's CENTRE is the lodge's own centre line, the nearest mat is inside the Director's
			-- +-15% band about today's 172.8 walked studs, and the bearing is within 10 degrees of
			-- the door's own facing. The row it replaced is archived at
			-- backups/2026-10-30_task-315_range-anchor.txt (rule 7).
			local forest = RangeData.anchorFor("forest-test")
			expect(forest).to.be.ok()
			local at = Vector3.new((forest :: any).x, 0, (forest :: any).z)
			local rowCentre = RangeData.matPosition(at, 1, RangeData.LAYOUT).X
				+ RangeData.spotSpan(RangeData.LAYOUT) / 2
			expect(rowCentre).to.equal((LOBBY_ANCHOR :: any).x + LOBBY_CFG.LODGE.OFFSET.X)
			-- THE DOOR IS THE LODGE'S SOUTH FACE ON THAT CENTRE LINE, read off the lobby's own
			-- config so this case cannot drift from the building.
			local doorX = (LOBBY_ANCHOR :: any).x + LOBBY_CFG.LODGE.OFFSET.X
			local doorZ = (LOBBY_ANCHOR :: any).z + LOBBY_CFG.LODGE.OFFSET.Z - LOBBY_CFG.LODGE.SIZE.Z / 2
			-- THE ANGLE OFF THE DOOR'S OWN FACING, as the angle between the walk and due south --
			-- never a bearing arithmetic that has to wrap through 360, which is where the first
			-- draft of this case was wrong by 356 degrees.
			local function offSouthDeg(mat: Vector3): number
				local dx, dz = mat.X - doorX, mat.Z - doorZ
				local len = math.sqrt(dx * dx + dz * dz)
				return math.deg(math.acos(math.clamp(-dz / len, -1, 1)))
			end
			local nearest, worst, best = math.huge, 0, math.huge
			for spot = 1, RangeData.LAYOUT.SPOT_COUNT do
				local mat = RangeData.matPosition(at, spot, RangeData.LAYOUT)
				local dx, dz = mat.X - doorX, mat.Z - doorZ
				local walk = math.sqrt(dx * dx + dz * dz)
				nearest = math.min(nearest, walk)
				worst = math.max(worst, walk)
				best = math.min(best, offSouthDeg(mat))
				-- EVERY station is reachable in a straight-ish line, not only the nearest.
				expect(offSouthDeg(mat) < 25).to.equal(true)
			end
			expect(nearest > 147 and nearest < 199).to.equal(true)
			expect(worst - nearest < 12).to.equal(true)
			-- ...AND THE NEAREST MAT IS ALMOST DEAD AHEAD OUT OF THE DOOR. 4 degrees is half a mat's
			-- own 24-stud spacing at 174 studs, so this fails the moment the row stops being centred.
			expect(best < 4.0).to.equal(true)
			-- THE TWO NEW DATA FIELDS (design 8.1), and the DEV row's opposite values: one arithmetic,
			-- two rows, no branch anywhere on a world's name.
			expect(RangeData.bermIsTerrain(forest)).to.equal(true)
			expect(RangeData.fillsTerrain(forest)).to.equal(true)
			expect(RangeData.bermIsTerrain(dev)).to.equal(false)
			expect(RangeData.fillsTerrain(dev)).to.equal(false)
			expect(RangeData.bermIsTerrain(nil)).to.equal(false)
			expect(RangeData.fillsTerrain(nil)).to.equal(false)
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

		it("whitelists exactly the seven pace words and refuses everything else", function()
			-- KAREN'S FOUR, 2026-10-27: *"walk trot stand run"*, plus B4's `slow`, `fast` and
			-- `mixed` -- from the table and not from a literal in here.
			local words = 0
			for _, word in pairs(RangeData.WORD) do
				expect(RangeData.paceAllowed(word)).to.equal(true)
				expect(RangeData.optionAllowed("pace", word)).to.equal(true)
				words += 1
			end
			expect(words).to.equal(7)
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
			expect(folder:FindFirstChild("BankEast")).to.be.ok()
			expect(folder:FindFirstChild("BankWest")).to.be.ok()

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
			expect((first :: any).Name).to.equal(RangeData.matName(1))

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
			-- ONE PER STATION SINCE TASK 320: the bench's own post. It was FOUR (the stand's rail
			-- and the two climbs went with the towers).
			expect(prompts).to.equal(LAYOUT.SPOT_COUNT)
			expect(LAYOUT.SPOT_COUNT).to.equal(6)
			-- SIX OF EACH, BY NAME: one mat, one post and one prompt per station (design 5.4).
			for spot = 1, LAYOUT.SPOT_COUNT do
				expect(folder:FindFirstChild(RangeData.matName(spot))).to.be.ok()
				expect(folder:FindFirstChild(RangeData.postName(spot))).to.be.ok()
				expect(RangeData.promptFor(spot, nil, folder)).to.be.ok()
			end
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
			-- THE SHARED CORRIDOR (design 5.3): station 1's west apron edge to station 6's east one,
			-- at the LONGEST lane -- the deepest Z anything walks. Six overlapping windows, one box.
			local west, east = RangeData.corridorSpan(LAYOUT)
			local centre = Vector3.new(anchor.X + (west + east) / 2, anchor.Y, anchor.Z + RangeData.distanceMax(LAYOUT))
			local half = (east - west) / 2
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
				-- THE MOWN LANE IS THE ONE PART IN THE CORRIDOR AND IT EARNS THE EXEMPTION HERE
				-- (step B10): it is the slab of grass the target walks over, and it collides with
				-- nothing and answers no ray. That pair is ASSERTED rather than assumed, so a turf
				-- that quietly became solid lands in `blocking` like anything else.
				if part.Name:sub(1, #RangeData.TURF_NAME) == RangeData.TURF_NAME then
					expect(part.CanCollide).to.equal(false)
					expect(part.CanQuery).to.equal(false)
					expect(part.CanTouch).to.equal(false)
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
			-- ...AND THE TWO BANKS ARE STILL THERE, outside it, so this case cannot be satisfied by
			-- building no bank at all. Each stands beyond the CORRIDOR's end -- station 6's apron
			-- edge, not station 1's -- with `beyondStuds` of clearance to its NEAR face.
			for leg = 1, 2 do
				local bank = RangeData.bankPosition(anchor, LAYOUT, leg)
				expect(math.abs(bank.X - centre.X) > half).to.equal(true)
				local from = if (leg % 2) == 1 then anchor.X + east else anchor.X + west
				local near = math.abs(bank.X - from) - LAYOUT.BANK.size.X / 2
				expect(math.abs(near - LAYOUT.BANK.beyondStuds) < 1e-9).to.equal(true)
			end
			expect((built :: any).folder:FindFirstChild("BankEast")).to.be.ok()
			expect((built :: any).folder:FindFirstChild("BankWest")).to.be.ok()
			TestKit.note(string.format("range: 0 parts inside the %d-stud corridor (body radius %.2f)", 2 * half, body))
		end)

		-- THE WAY IN STANDS AT CHEST HEIGHT, NOT ON THE FLOOR. On the 8x8 mat the prompt was under
		-- her feet and off screen down the lane, so E did nothing (Director's proof, frames 03/04/06).
		it("hangs the prompt on a POST at the mat's front edge, at the one arithmetic's point", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			expect(built).to.be.ok()
			local folder = (built :: any).folder
			local post = folder:FindFirstChild(RangeData.postName(1))
			expect(post).to.be.ok()
			expect((post :: any):IsA("BasePart")).to.equal(true)
			-- THE PROMPT IS ON THE POST and nowhere near the mat.
			local prompt = RangeData.promptFor(1, nil, folder)
			expect(prompt).to.be.ok()
			expect((prompt :: any):IsA("ProximityPrompt")).to.equal(true)
			expect((prompt :: any).Parent.Parent).to.equal(post)
			local mat = folder:FindFirstChild(RangeData.matName(1))
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
			-- AND THE "IS HE AT THE SPOT" SIGNAL IS ALIVE ON THE BUILT FOLDER. The Hud reads the
			-- prompt's own point through `Range.promptPointOf` and asks `atSpot` about THAT, which
			-- is the number the engine offers E at. Reading `prompt.Parent.Position` instead went
			-- silently dead when the prompt moved onto an attachment, and with it the board and the
			-- door-closer (review round 1, finding 1) -- so this drives the real built shape.
			local point = RangeData.promptPointOf(prompt)
			expect(point).to.be.ok()
			expect(((point :: Vector3) - want).Magnitude < 1e-3).to.equal(true)
			local reachStuds = LAYOUT.PROMPT.MaxActivationDistance
			expect(RangeData.atSpot(point, matAt, LAYOUT)).to.equal(true)
			expect(RangeData.atSpot(point, (point :: Vector3) + Vector3.new(reachStuds - 1, 0, 0), LAYOUT)).to.equal(
				true
			)
			expect(RangeData.atSpot(point, (point :: Vector3) + Vector3.new(reachStuds + 1, 0, 0), LAYOUT)).to.equal(
				false
			)
			-- Both shapes answered by the one reader: a prompt on nothing, and a prompt on a part.
			expect(RangeData.promptPointOf(Instance.new("ProximityPrompt"))).to.equal(nil)
			local loose = Instance.new("Part")
			loose.Position = Vector3.new(7, 8, 9)
			local onPart = Instance.new("ProximityPrompt")
			onPart.Parent = loose
			expect(RangeData.promptPointOf(onPart)).to.equal(Vector3.new(7, 8, 9))
			TestKit.note(
				string.format(
					"range: prompt on Post, %.2f studs from the mat (reach %d)",
					reach,
					LAYOUT.PROMPT.MaxActivationDistance
				)
			)
		end)
	end)

	-- ------------------------------------------------- 3b. SIX STATIONS: THE GEOMETRY (step B2)
	-- Design 5.1-5.4. Every number here is DERIVED from `LAYOUT` and never transcribed from the
	-- document (verdict 278's rule, 306a note (k)): a case that retypes the formula's output cannot
	-- fail when the formula is wrong.
	describe("six stations: the geometry", function()
		local DEV_AT = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)

		-- ONE STATION PER CASE (L-093): station 1 is the arm this file shipped on, station 3 a
		-- middle one and station 6 the last -- and each walks all three distances, because the
		-- distance is the other new arm.
		local function laneCases(spot: number)
			local mat = RangeData.matPosition(DEV_AT, spot, LAYOUT)
			for _, studs in ipairs(RangeData.DISTANCES_STUDS) do
				local centre = RangeData.laneCentre(DEV_AT, LAYOUT, 1, spot, studs)
				-- THE WINDOW IS CENTRED ON HIS OWN MAT, so the crossing stays perpendicular to the
				-- range for all six (design 5.3).
				expect(centre.X).to.equal(mat.X)
				expect(centre.Z - DEV_AT.Z).to.equal(studs)
				local east = RangeData.laneEnds(DEV_AT, LAYOUT, 1, 1, spot, studs)
				local west = RangeData.laneEnds(DEV_AT, LAYOUT, 2, 1, spot, studs)
				expect(east.X - centre.X).to.equal(RangeData.laneLength(LAYOUT) / 2)
				expect(west.X - centre.X).to.equal(-RangeData.laneLength(LAYOUT) / 2)
				expect(east.Z).to.equal(centre.Z)
				expect(west.Z).to.equal(centre.Z)
				-- ...AND THE OTHER WAY ROUND, through the row's own sign.
				local south = RangeData.laneCentre(DEV_AT, LAYOUT, -1, spot, studs)
				expect(south.Z - DEV_AT.Z).to.equal(-studs)
				expect(south.X).to.equal(mat.X)
			end
		end

		it("centres station 1's lane on mat 1, at each of the three distances", function()
			laneCases(1)
			-- THE ONE-STATION ANSWER IS UNCHANGED, which is what keeps the shipped cases meaningful.
			expect(RangeData.laneCentre(DEV_AT, LAYOUT).X).to.equal(DEV_AT.X)
			expect(RangeData.laneCentre(DEV_AT, LAYOUT).Z - DEV_AT.Z).to.equal(LAYOUT.DISTANCE_STUDS)
		end)

		it("centres a MIDDLE station's lane on its own mat, at each of the three distances", function()
			laneCases(3)
			local mat = RangeData.matPosition(DEV_AT, 3, LAYOUT)
			expect(mat.X - DEV_AT.X).to.equal(2 * LAYOUT.SPOT_SPACING_STUDS)
		end)

		it("centres station 6's lane on its own mat, at each of the three distances", function()
			laneCases(LAYOUT.SPOT_COUNT)
			local mat = RangeData.matPosition(DEV_AT, LAYOUT.SPOT_COUNT, LAYOUT)
			expect(mat.X - DEV_AT.X).to.equal(RangeData.spotSpan(LAYOUT))
		end)

		-- 306a(c): THE BERM MUST SPAN THE BANKS, AND IT DID NOT. The document derived its width from
		-- the bank's CENTRE, which leaves half a bank outside each end. `bankReach` is the bank's
		-- OUTER face, and the two faces then coincide exactly -- which is what this asserts.
		it("derives a berm that spans every station's lane AND both banks, to the stud", function()
			local bermMin, bermMax = RangeData.bermSpanFor(DEV_AT, LAYOUT)
			local westMin, westMax = RangeData.bankSpanFor(DEV_AT, LAYOUT, 2)
			local eastMin, eastMax = RangeData.bankSpanFor(DEV_AT, LAYOUT, 1)
			expect(westMin < eastMin).to.equal(true)
			-- THE IDENTITY: the berm's faces ARE the banks' outer faces.
			expect(bermMin).to.equal(westMin)
			expect(bermMax).to.equal(eastMax)
			expect(bermMax - bermMin).to.equal(RangeData.bermWidthFor(LAYOUT))
			-- EVERY STATION'S WHOLE LANE, at the longest distance, is inside it.
			for spot = 1, LAYOUT.SPOT_COUNT do
				for leg = 1, 2 do
					local at = RangeData.laneEnds(DEV_AT, LAYOUT, leg, 1, spot, RangeData.distanceMax(LAYOUT))
					expect(at.X > bermMin and at.X < bermMax).to.equal(true)
				end
			end
			-- AND THE OLD ARITHMETIC FAILS IT: a width derived from the bank's CENTRE is one whole
			-- bank narrower, and leaves half a bank outside each end.
			local centreBased = RangeData.spotSpan(LAYOUT)
				+ RangeData.laneLength(LAYOUT)
				+ 2 * (LAYOUT.BANK.beyondStuds + LAYOUT.BANK.size.X / 2)
			expect(RangeData.bermWidthFor(LAYOUT) - centreBased).to.equal(LAYOUT.BANK.size.X)
			local oldMin = (bermMin + bermMax) / 2 - centreBased / 2
			local oldMax = (bermMin + bermMax) / 2 + centreBased / 2
			expect(oldMin > westMin).to.equal(true)
			expect(oldMax < eastMax).to.equal(true)
			expect(oldMin - westMin).to.equal(LAYOUT.BANK.size.X / 2)
			expect(eastMax - oldMax).to.equal(LAYOUT.BANK.size.X / 2)
			-- THE TERRAIN GRID (design 5.4): her place fills this rectangle, and `Terrain:FillBlock`
			-- writes 4-stud voxels on a grid at the world origin, so a misaligned edge leaves voxels
			-- standing (task 191). What is asserted is the rectangle's four edges as OFFSETS FROM
			-- THE ANCHOR -- the world faces are on the grid when the anchor is, and that is a
			-- property of the ANCHOR and not of this arithmetic (round 1, finding 1).
			local grid = LAYOUT.FILL.GRID_STUDS
			expect(RangeData.bermWidthFor(LAYOUT) % grid).to.equal(0)
			expect((bermMin - DEV_AT.X) % grid).to.equal(0)
			expect((bermMax - DEV_AT.X) % grid).to.equal(0)
			-- ...AND BOTH Z FACES, which is why `behindStuds` is 13 and not 12: at 12 they were 187
			-- and 195 (round 1, finding 2). Asserted for BOTH signs of `downrange`.
			for _, dir in ipairs({ 1, -1 }) do
				local at = RangeData.bermPosition(DEV_AT, LAYOUT, dir)
				local near = math.abs(at.Z - DEV_AT.Z) - LAYOUT.BERM.depth / 2
				local far = math.abs(at.Z - DEV_AT.Z) + LAYOUT.BERM.depth / 2
				expect(near % grid).to.equal(0)
				expect(far % grid).to.equal(0)
			end
			-- THE SNAP IS A NO-OP AT THE SHIPPED NUMBERS (232 is already 58 x 4), so every line
			-- above survives deleting it. THIS is the arm that does not: a window two studs
			-- narrower makes the raw width 230, and `bermWidthFor` must answer 232 -- rounding UP,
			-- never down and never through (round 1, finding 1).
			local offGrid = layoutWith({ WINDOW_STUDS = LAYOUT.WINDOW_STUDS - 2 })
			local raw = RangeData.spotSpan(offGrid) + RangeData.laneLength(offGrid) + 2 * RangeData.bankReach(offGrid)
			expect(raw % grid).to.equal(2)
			expect(RangeData.bermWidthFor(offGrid)).to.equal(raw + 2)
			expect(RangeData.bermWidthFor(offGrid) % grid).to.equal(0)
			expect(RangeData.bermWidthFor(offGrid) > raw).to.equal(true)
			-- ...and the snapped berm still spans both banks, which is what the snap must not break.
			local offMin, offMax = RangeData.bermSpanFor(DEV_AT, offGrid)
			local offWestMin = select(1, RangeData.bankSpanFor(DEV_AT, offGrid, 2))
			local offEastMax = select(2, RangeData.bankSpanFor(DEV_AT, offGrid, 1))
			expect(offMin <= offWestMin).to.equal(true)
			expect(offMax >= offEastMax).to.equal(true)
			TestKit.note(
				string.format(
					"range berm: %d studs wide, x %.0f..%.0f -- banks x %.0f..%.0f and %.0f..%.0f (the centre-based %d left %.0f out at each end)",
					RangeData.bermWidthFor(LAYOUT),
					bermMin,
					bermMax,
					westMin,
					westMax,
					eastMin,
					eastMax,
					centreBased,
					LAYOUT.BANK.size.X / 2
				)
			)
		end)

		it("holds both banks, the berm and all six stations inside footprintFor, both ways", function()
			for _, dir in ipairs({ 1, -1 }) do
				local box = RangeData.footprintFor(DEV_AT, LAYOUT, dir)
				local margin = LAYOUT.PROMPT.MaxActivationDistance
				local bermMin, bermMax = RangeData.bermSpanFor(DEV_AT, LAYOUT)
				-- X: the box is the banks and the berm, plus the prompt's own reach.
				expect(box.minX).to.equal(bermMin - margin)
				expect(box.maxX).to.equal(bermMax + margin)
				for leg = 1, 2 do
					local lo, hi = RangeData.bankSpanFor(DEV_AT, LAYOUT, leg)
					expect(lo >= box.minX and hi <= box.maxX).to.equal(true)
				end
				-- ...AND IT REACHES THE BERM AT THE LONGEST LANE, not at the one the menu opens on.
				local reach = (RangeData.distanceMax(LAYOUT) + LAYOUT.BERM.behindStuds + LAYOUT.BERM.depth / 2) + margin
				local far = if dir == 1 then box.maxZ - DEV_AT.Z else DEV_AT.Z - box.minZ
				expect(math.abs(far - reach) < 1e-6).to.equal(true)
				expect(reach > LAYOUT.DISTANCE_STUDS).to.equal(true)
				-- EVERY MAT AND EVERY PROMPT IS IN IT.
				for spot = 1, LAYOUT.SPOT_COUNT do
					local mat = RangeData.matPosition(DEV_AT, spot, LAYOUT)
					local prompt = RangeData.promptPosition(DEV_AT, spot, LAYOUT, dir)
					for _, at in ipairs({ mat, prompt }) do
						expect(at.X >= box.minX and at.X <= box.maxX).to.equal(true)
						expect(at.Z >= box.minZ and at.Z <= box.maxZ).to.equal(true)
					end
				end
				-- THE FIELD THE RUNTIME USES carries the longest lane too, or an ordered target is
				-- out of bounds the moment it is led down the 179.
				local field = RangeData.fieldFor(DEV_AT, LAYOUT, dir)
				for spot = 1, LAYOUT.SPOT_COUNT do
					for leg = 1, 2 do
						local at = RangeData.laneEnds(DEV_AT, LAYOUT, leg, dir, spot, RangeData.distanceMax(LAYOUT))
						expect(at.X > field.bounds.minX and at.X < field.bounds.maxX).to.equal(true)
						expect(at.Z > field.bounds.minZ and at.Z < field.bounds.maxZ).to.equal(true)
					end
				end
			end
		end)

		it("stands every part it builds over the DEV plate, and inside the footprint", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			expect(built).to.be.ok()
			local b = built :: any
			local plate = b.folder:FindFirstChild("Plate")
			expect(plate).to.be.ok()
			local box = RangeData.footprintFor(b.anchor, LAYOUT, b.downrange)
			local overhang = {}
			for _, part in ipairs(b.folder:GetDescendants()) do
				if not part:IsA("BasePart") or part == plate then
					continue
				end
				local loX = part.Position.X - part.Size.X / 2
				local hiX = part.Position.X + part.Size.X / 2
				local loZ = part.Position.Z - part.Size.Z / 2
				local hiZ = part.Position.Z + part.Size.Z / 2
				-- OVER THE PLATE: centred on the anchor instead of the stations, the plate stopped
				-- short of station 6's own bank by 38 studs.
				if
					loX < plate.Position.X - plate.Size.X / 2
					or hiX > plate.Position.X + plate.Size.X / 2
					or loZ < plate.Position.Z - plate.Size.Z / 2
					or hiZ > plate.Position.Z + plate.Size.Z / 2
				then
					table.insert(overhang, string.format("%s off the plate", part.Name))
				end
				if loX < box.minX or hiX > box.maxX or loZ < box.minZ or hiZ > box.maxZ then
					table.insert(overhang, string.format("%s outside the footprint", part.Name))
				end
			end
			if #overhang > 0 then
				error(table.concat(overhang, " | "))
			end
			expect(#overhang).to.equal(0)
			-- THE PLATE, THE SIX MATS, THE SIX POSTS, THE SIX BENCHES, THE TWO BANKS AND THE BERM.
			-- NO SEATS SINCE TASK 320 (no towers): the term was
			-- `SPOT_COUNT * HighSeats.PARTS_PER_SEAT` and it is gone, which is 84 fewer parts.
			-- ...PLUS WHAT STEP B10 DRESSES IT WITH, counted the same way: per station four hut
			-- posts, a roof and a number board; then ONE turf slab, the fence's own posts and its
			-- two rails. Written as the arithmetic and not as 165, so a part that appears or
			-- disappears moves this number rather than passing under it.
			local dressed = LAYOUT.SPOT_COUNT * 6
				+ #RangeData.turfSlabs((b :: any).anchor, LAYOUT, (b :: any).downrange, DEV_ROW)
			expect(b.parts).to.equal(1 + 3 * LAYOUT.SPOT_COUNT + 3 + dressed)
			expect(b.parts <= Range.CONFIG.MAX_PARTS).to.equal(true)
			TestKit.note(
				string.format(
					"range DEV: %d parts (plate %.0f x %.0f) all inside the footprint x %.0f..%.0f z %.0f..%.0f",
					b.parts,
					plate.Size.X,
					plate.Size.Z,
					box.minX,
					box.maxX,
					box.minZ,
					box.maxZ
				)
			)
			parent:Destroy()
		end)

		it("gives each of the six its own prompt, out of reach of its neighbour's", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			local b = built :: any
			local reach = LAYOUT.PROMPT.MaxActivationDistance
			local points = {}
			for spot = 1, LAYOUT.SPOT_COUNT do
				local prompt = RangeData.promptFor(spot, nil, b.folder)
				expect(prompt).to.be.ok()
				local point = RangeData.promptPointOf(prompt)
				expect(point).to.be.ok()
				points[spot] = point :: Vector3
			end
			for spot = 1, LAYOUT.SPOT_COUNT do
				local mat = RangeData.matPosition(b.anchor, spot, LAYOUT)
				-- HIS OWN IS IN REACH...
				expect(RangeData.atSpot(points[spot], mat, LAYOUT)).to.equal(true)
				-- ...AND NOBODY ELSE'S IS, which is what `SPOT_SPACING_STUDS` is for.
				for other = 1, LAYOUT.SPOT_COUNT do
					if other ~= spot then
						expect(RangeData.atSpot(points[other], mat, LAYOUT)).to.equal(false)
						expect((points[other] - points[spot]).Magnitude >= 2 * reach).to.equal(true)
					end
				end
				-- ...AND THE MAN ON IT IS THE MAN THE SERVER SEES THERE.
				expect(RangeData.spotAt(b.anchor, mat, LAYOUT)).to.equal(spot)
			end
			expect(LAYOUT.SPOT_SPACING_STUDS).to.equal(2 * reach)
			-- EVERY SPOT IS A LEGAL PICK, and one past the last is not.
			for spot = 1, LAYOUT.SPOT_COUNT do
				expect(RangeData.optionAllowed("spot", spot)).to.equal(true)
			end
			expect(RangeData.optionAllowed("spot", LAYOUT.SPOT_COUNT + 1)).to.equal(false)
			parent:Destroy()
		end)
	end)

	-- -------------------------------------------- 3b. THE TWO FIRING POSITIONS (step B3, design 7)
	describe("the two firing positions", function()
		local DEV_AT = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
		-- WHAT `Build` MEASURES OVER A PLATE: one flat shelf under all five footprint points, so
		-- every deck's top is the shelf plus the seat's own rise. The Build case below asserts that
		-- against a real build; here it is the input to the PURE function.
		local function deckTopsFor(at: Vector3): { [number]: number }
			local out: { [number]: number } = {}
			for spot = 1, LAYOUT.SPOT_COUNT do
				out[spot] = at.Y + HighSeats.DIMS.DECK_RISE_STUDS
			end
			return out
		end

		it("measures BENCH on every mat, whichever way the lane runs", function()
			for _, dir in ipairs({ 1, -1 }) do
				local tops = deckTopsFor(DEV_AT)
				for spot = 1, LAYOUT.SPOT_COUNT do
					local mat = RangeData.matPosition(DEV_AT, spot, LAYOUT)
					local at, position = RangeData.spotAt(DEV_AT, mat, LAYOUT, dir, tops)
					expect(at).to.equal(spot)
					expect(position).to.equal(RangeData.POSITION.BENCH)
					-- The mat's own corner is still the bench, and still only his station.
					local corner = mat + Vector3.new(LAYOUT.MAT.size.X / 2, 0, dir * LAYOUT.MAT.size.Z / 2)
					expect(RangeData.spotAt(DEV_AT, corner, LAYOUT, dir, tops)).to.equal(spot)
				end
			end
		end)

		it("measures TREESTAND on every deck, at or above the deck's own face and not below", function()
			for _, dir in ipairs({ 1, -1 }) do
				local tops = deckTopsFor(DEV_AT)
				for spot = 1, LAYOUT.SPOT_COUNT do
					local deck = RangeData.standPosition(DEV_AT, spot, LAYOUT, dir)
					local top = tops[spot]
					-- A MAN STANDING ON THE DECK: his root is 3.5 studs above it.
					local at, position =
						RangeData.spotAt(DEV_AT, Vector3.new(deck.X, top + 3.5, deck.Z), LAYOUT, dir, tops)
					expect(at).to.equal(spot)
					expect(position).to.equal(RangeData.POSITION.TREESTAND)
					-- THE LINE IS THE DECK'S OWN FACE WITH NO MARGIN (`Rules.belowPlatform`'s own
					-- comparison): exactly at it is ON; one stud under it is the station with NO
					-- position, which is the honest answer for a man under the deck.
					local line = Vector3.new(deck.X, HighSeats.minYFor(top), deck.Z)
					expect(select(2, RangeData.spotAt(DEV_AT, line, LAYOUT, dir, tops))).to.equal(
						RangeData.POSITION.TREESTAND
					)
					local under, underPosition =
						RangeData.spotAt(DEV_AT, Vector3.new(deck.X, top - 1, deck.Z), LAYOUT, dir, tops)
					expect(under).to.equal(spot)
					expect(underPosition).to.equal(nil)
					-- OFF THE DECK'S RECT, high up, still in the station box: no position either.
					local beside = Vector3.new(deck.X + HighSeats.DIMS.DECK_SIZE.X / 2 + 0.5, top + 3.5, deck.Z)
					local besideSpot, besidePosition = RangeData.spotAt(DEV_AT, beside, LAYOUT, dir, tops)
					expect(besideSpot).to.equal(spot)
					expect(besidePosition).to.equal(nil)
				end
			end
		end)

		it("keeps a man walking from the bench to the ladder AT his own station", function()
			local dir = 1
			local tops = deckTopsFor(DEV_AT)
			local mat = RangeData.matPosition(DEV_AT, 2, LAYOUT)
			local deck = RangeData.standPosition(DEV_AT, 2, LAYOUT, dir)
			-- EVERY STUD OF THE WALK, SAMPLED: the station is the UNION box of the two positions,
			-- so he never loses his gun between them (design 7.3).
			for z = 0, math.floor(RangeData.standReach(LAYOUT)) do
				expect(RangeData.spotAt(DEV_AT, mat - Vector3.new(0, 0, dir * z), LAYOUT, dir, tops)).to.equal(2)
			end
			local foot = Vector3.new(deck.X, DEV_AT.Y, deck.Z - dir * math.abs(HighSeats.DIMS.LADDER_OFFSET_STUDS))
			expect(RangeData.spotAt(DEV_AT, foot, LAYOUT, dir, tops)).to.equal(2)
			-- ...AND WHERE ITS OWN WAY DOWN SETS HIM (306k item 3). MEASURED in her place: a real `F`
			-- landed the man 2.1 studs OUTSIDE the box, `mayShoot` answered false there, and he came
			-- off his own ladder with an empty backpack. Delete the `wayDown` arm of `standReach` and
			-- this line fails.
			local down = RangeData.climbDownTargetFor(DEV_AT, 2, LAYOUT, dir, DEV_AT.Y).Position
			expect(RangeData.spotAt(DEV_AT, down, LAYOUT, dir, tops)).to.equal(2)
			-- THE REACH IS THE SEAT'S OWN NUMBER, not a typed one: the feet, or the way down.
			local feet = LAYOUT.STAND.backStuds + HighSeats.footprintRadiusStuds()
			local wayDown = LAYOUT.STAND.backStuds
				+ math.abs(HighSeats.DIMS.LADDER_OFFSET_STUDS)
				+ LAYOUT.CLIMB.footClearStuds
			expect(RangeData.standReach(LAYOUT)).to.equal(math.max(feet, wayDown))
			expect(RangeData.standReach(LAYOUT) > feet).to.equal(true)
		end)

		it("answers nil one stud outside the station box, on every face", function()
			local dir = 1
			local tops = deckTopsFor(DEV_AT)
			local mat = RangeData.matPosition(DEV_AT, 1, LAYOUT)
			local reach = RangeData.standReach(LAYOUT)
			local ahead = mat + Vector3.new(0, 0, dir * (LAYOUT.MAT.size.Z / 2 + 1))
			expect(RangeData.spotAt(DEV_AT, ahead, LAYOUT, dir, tops)).to.equal(nil)
			local behind = mat - Vector3.new(0, 0, dir * (reach + 1))
			expect(RangeData.spotAt(DEV_AT, behind, LAYOUT, dir, tops)).to.equal(nil)
			local aside = mat + Vector3.new(LAYOUT.MAT.size.X / 2 + 1, 0, 0)
			expect(RangeData.spotAt(DEV_AT, aside, LAYOUT, dir, tops)).to.equal(nil)
			-- HALF WAY BETWEEN TWO STATIONS is neither of them: 24-stud spacing against an 8-stud
			-- mat leaves 16 studs of nothing, which is what makes one position belong to one man.
			local between = mat + Vector3.new(LAYOUT.SPOT_SPACING_STUDS / 2, 0, 0)
			expect(RangeData.spotAt(DEV_AT, between, LAYOUT, dir, tops)).to.equal(nil)
			expect(RangeData.spotAt(DEV_AT, mat + Vector3.new(0, 0, 500), LAYOUT, dir, tops)).to.equal(nil)
			expect(RangeData.spotAt(DEV_AT, nil, LAYOUT, dir, tops)).to.equal(nil)
			expect(RangeData.spotAt(nil, mat, LAYOUT, dir, tops)).to.equal(nil)
		end)

		it("gives a station whose seat was REFUSED a bench and no treestand, as data", function()
			local dir = 1
			local tops = deckTopsFor(DEV_AT)
			-- NO DECK TOP FOR STATION 3 is exactly what `Build` records for a seat `HighSeats.plan`
			-- refused on its own ground, and nothing branches on it.
			tops[3] = nil
			local deck = RangeData.standPosition(DEV_AT, 3, LAYOUT, dir)
			local on = Vector3.new(deck.X, DEV_AT.Y + HighSeats.DIMS.DECK_RISE_STUDS + 3.5, deck.Z)
			local at, position = RangeData.spotAt(DEV_AT, on, LAYOUT, dir, tops)
			expect(at).to.equal(3)
			expect(position).to.equal(nil)
			-- ...his bench is untouched...
			local mat = RangeData.matPosition(DEV_AT, 3, LAYOUT)
			expect(select(2, RangeData.spotAt(DEV_AT, mat, LAYOUT, dir, tops))).to.equal(RangeData.POSITION.BENCH)
			-- ...and so is his neighbour's stand.
			local near = RangeData.standPosition(DEV_AT, 4, LAYOUT, dir)
			local up = Vector3.new(near.X, tops[4] + 3.5, near.Z)
			expect(select(2, RangeData.spotAt(DEV_AT, up, LAYOUT, dir, tops))).to.equal(RangeData.POSITION.TREESTAND)
			-- NO DECK TOPS AT ALL (a range with no seat standing): bench only, and no error.
			expect(select(2, RangeData.spotAt(DEV_AT, on, LAYOUT, dir, nil))).to.equal(nil)
		end)

		it("shoots STAND.backStuds further from the deck than from the bench, at every distance", function()
			for _, studs in ipairs(RangeData.DISTANCES_STUDS) do
				local trial = { distanceStuds = studs }
				expect(RangeData.distanceFor(trial, RangeData.POSITION.BENCH, LAYOUT)).to.equal(studs)
				expect(RangeData.distanceFor(trial, nil, LAYOUT)).to.equal(studs)
				expect(RangeData.distanceFor(trial, RangeData.POSITION.TREESTAND, LAYOUT)).to.equal(
					studs + LAYOUT.STAND.backStuds
				)
			end
			-- A TRIAL WITH NO PICK falls back to the lane the menu opens on, through the shipped
			-- whitelist and never through a second default.
			expect(RangeData.distanceFor({}, RangeData.POSITION.TREESTAND, LAYOUT)).to.equal(
				LAYOUT.DISTANCE_STUDS + LAYOUT.STAND.backStuds
			)
			expect(RangeData.distanceFor(nil, RangeData.POSITION.BENCH, LAYOUT)).to.equal(LAYOUT.DISTANCE_STUDS)
			-- HOW BIG IT IS: 7.8 % at the longest lane, which is why the board's two lead numbers
			-- are computed from THIS and not from the picked lane (design 9.4).
			local far = RangeData.distanceMax(LAYOUT)
			local ratio = RangeData.distanceFor({ distanceStuds = far }, RangeData.POSITION.TREESTAND, LAYOUT) / far
			expect(ratio > 1.07 and ratio < 1.09).to.equal(true)
		end)

		it("holds every deck, ladder foot and stand prompt inside footprintFor, both ways", function()
			for _, dir in ipairs({ 1, -1 }) do
				local box = RangeData.footprintFor(DEV_AT, LAYOUT, dir)
				for spot = 1, LAYOUT.SPOT_COUNT do
					local deck = RangeData.standPosition(DEV_AT, spot, LAYOUT, dir)
					local foot = deck - Vector3.new(0, 0, dir * math.abs(HighSeats.DIMS.LADDER_OFFSET_STUDS))
					local prompt = RangeData.promptPosition(DEV_AT, spot, LAYOUT, dir, RangeData.POSITION.TREESTAND)
					for _, at in ipairs({ deck, foot, prompt }) do
						expect(at.X >= box.minX and at.X <= box.maxX).to.equal(true)
						expect(at.Z >= box.minZ and at.Z <= box.maxZ).to.equal(true)
					end
				end
				-- THE UPRANGE EDGE IS THE SEAT'S OWN FEET plus the prompt's reach, and NOT the
				-- mat's back edge: a man on the deck has to be inside this box, or task 302's
				-- return rule respawns him off it.
				local near = if dir == 1 then DEV_AT.Z - box.minZ else box.maxZ - DEV_AT.Z
				local wanted = RangeData.standReach(LAYOUT) + LAYOUT.PROMPT.MaxActivationDistance
				-- ROUNDED OUTWARD TO WHOLE STUDS (`footprintFor`'s own rule): 31.1 becomes 32, and
				-- a fractional edge never reaches a `Vector3`.
				expect(near >= wanted).to.equal(true)
				expect(near).to.equal(math.ceil(wanted))
				expect(box.minZ).to.equal(math.floor(box.minZ))
				expect(box.maxZ).to.equal(math.floor(box.maxZ))
				expect(near > LAYOUT.MAT.size.Z / 2 + LAYOUT.PROMPT.MaxActivationDistance).to.equal(true)
			end
		end)
	end)

	-- ------------------------------------------ 3c. WHAT `Build` LAYS FOR THE SECOND POSITION (B3)
	-- TASK 320: NO TOWERS. Karen, 2026-10-31: *"and remove towers we dont need them in shooting
	-- range"*. This block asserted the six seats B3 built; it now asserts they are NOT built, case
	-- for case (the bench half of each is unchanged). `backups/task-320/` holds the removed code.
	describe("Build: the bench, and NO treestand (task 320)", function()
		local function buildInto(row, groundAt)
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = row, layout = LAYOUT, groundAt = groundAt })
			return built :: any, parent
		end

		it("lays a bench at every station and NOT ONE seat part: no deck, no ladder, no rail", function()
			-- BOTH SIGNS OF THE LANE, as the seat case did: nothing may build a tower either way.
			for _, dir in ipairs({ 1, -1 }) do
				local row = { x = DEV_ROW.x, z = DEV_ROW.z, y = DEV_ROW.y, plate = true, downrange = dir }
				local b, parent = buildInto(row, nil)
				expect(b).to.be.ok()
				expect(b.downrange).to.equal(dir)
				expect(b.stands).to.equal(0)
				expect(b.refusedStands).to.equal(0)
				expect(next(b.deckTops)).to.equal(nil)
				for spot = 1, LAYOUT.SPOT_COUNT do
					-- THE BENCH, at its own arithmetic point: unchanged by this task.
					local bench = b.folder:FindFirstChild(RangeData.benchName(spot))
					expect(bench).to.be.ok()
					local wantedBench = RangeData.benchPosition(b.anchor, spot, LAYOUT, dir)
					expect(((bench :: BasePart).Position - wantedBench).Magnitude < 1e-3).to.equal(true)
					-- ...AND NO SEAT FOLDER AND NO DECK TOP AT THAT STATION.
					expect(b.folder:FindFirstChild(RangeData.standName(spot))).to.equal(nil)
					expect(b.deckTops[spot]).to.equal(nil)
				end
				-- NOT ONE PIECE OF A SEAT ANYWHERE UNDER THE FOLDER, by NAME and by CLASS: the
				-- ladder is the one TrussPart the range ever built, so a count of zero of them is
				-- a second, independent reading of the same removal.
				local seatNames = { Deck = true, Ladder = true, Leg1 = true, Girt = true, RailN = true }
				local trusses = 0
				for _, child in ipairs(b.folder:GetDescendants()) do
					if child:IsA("BasePart") then
						expect(seatNames[child.Name]).to.equal(nil)
						if child:IsA("TrussPart") then
							trusses += 1
						end
					end
				end
				expect(trusses).to.equal(0)
				-- AND NOTHING THE SHOOTER STANDS AMONG RISES OVER THE HUT'S OWN ROOF: the deck's
				-- rail top was shelf+14.9 against a roof at shelf+9.6, so the tallest thing left
				-- on the firing line is the hut (her place at main: 320-census-main.txt in the
				-- runs dir read the same two numbers). The EARTH is not in this count -- the berm
				-- and the two banks are the backstop, downrange, and task 320 moved neither.
				local earth = { Berm = true, BankEast = true, BankWest = true }
				local tallest, tallestName = 0, "nothing"
				for _, child in ipairs(b.folder:GetDescendants()) do
					if child:IsA("BasePart") and earth[child.Name] == nil then
						local top = child.Position.Y + child.Size.Y / 2 - b.shelf
						if top > tallest then
							tallest, tallestName = top, child.Name
						end
					end
				end
				expect(tallest < LAYOUT.HUT.roofRise + LAYOUT.HUT.roofSize.Y + 0.5).to.equal(true)
				local first = b.folder:FindFirstChildWhichIsA("BasePart")
				expect(first.Name).to.equal(RangeData.matName(1))
				expect(b.parts <= Range.CONFIG.MAX_PARTS).to.equal(true)
				if dir == 1 then
					TestKit.note(
						string.format(
							"range 320: %d parts, %d stands, tallest %s at +%.1f over the shelf",
							b.parts,
							b.stands,
							tallestName,
							tallest
						)
					)
				end
				parent:Destroy()
			end
		end)

		it("gives every station ONE prompt -- its bench's -- and no stand prompt and no climb prompt", function()
			local dir = 1
			local row = { x = DEV_ROW.x, z = DEV_ROW.z, y = DEV_ROW.y, plate = true, downrange = dir }
			local b, parent = buildInto(row, nil)
			local prompts = 0
			for _, child in ipairs(b.folder:GetDescendants()) do
				if child:IsA("ProximityPrompt") then
					prompts += 1
					-- EVERY PROMPT THE RANGE BUILDS IS A BENCH PROMPT, by name.
					expect(string.match(child.Name, "^" .. RangeData.PROMPT_NAME .. "%d+$") ~= nil).to.equal(true)
					expect(child.ObjectText).to.equal(LAYOUT.PROMPT.ObjectText)
					expect(child.ObjectText ~= LAYOUT.CLIMB.OBJECT_TEXT).to.equal(true)
				end
			end
			expect(prompts).to.equal(LAYOUT.SPOT_COUNT)
			for spot = 1, LAYOUT.SPOT_COUNT do
				expect(RangeData.promptFor(spot, RangeData.POSITION.BENCH, b.folder)).to.be.ok()
				expect(RangeData.promptFor(spot, RangeData.POSITION.TREESTAND, b.folder)).to.equal(nil)
				for _, way in ipairs({ "up", "down" }) do
					local wanted = RangeData.climbPromptName(spot, way)
					for _, child in ipairs(b.folder:GetDescendants()) do
						expect(child.Name ~= wanted).to.equal(true)
					end
				end
			end
			parent:Destroy()
		end)

		-- WAS "nearestPrompt finds all TWELVE" (step B6): there are SIX now, and the deck's point
		-- answers nothing, which is how the panel can never be told `treestand`.
		it("nearestPrompt finds the SIX benches, and answers NOTHING where the deck used to be", function()
			local dir = 1
			local row = { x = DEV_ROW.x, z = DEV_ROW.z, y = DEV_ROW.y, plate = true, downrange = dir }
			local b, parent = buildInto(row, nil)
			local found: { [string]: boolean } = {}
			for spot = 1, LAYOUT.SPOT_COUNT do
				local mat = RangeData.matPosition(b.anchor, spot, LAYOUT)
				local prompt, atSpot, position = RangeData.nearestPrompt(mat, b.folder, LAYOUT)
				expect(prompt).to.be.ok()
				expect(atSpot).to.equal(spot)
				expect(position).to.equal(RangeData.POSITION.BENCH)
				expect(prompt).to.equal(RangeData.promptFor(spot, RangeData.POSITION.BENCH, b.folder))
				found[(prompt :: any).Name] = true

				-- THE AIR WHERE THE DECK STOOD: 15 studs up and 14 studs uprange is out of every
				-- bench prompt's reach, so the answer is nothing at all -- never a position word.
				local deckAt = RangeData.standPosition(b.anchor, spot, LAYOUT, dir)
					+ Vector3.new(0, HighSeats.DIMS.DECK_RISE_STUDS, 0)
				local high, highSpot, highPosition = RangeData.nearestPrompt(deckAt, b.folder, LAYOUT)
				expect(high).to.equal(nil)
				expect(highSpot).to.equal(nil)
				expect(highPosition).to.equal(nil)
			end
			local count = 0
			for _ in pairs(found) do
				count += 1
			end
			expect(count).to.equal(LAYOUT.SPOT_COUNT)
			expect((RangeData.nearestPrompt(nil, b.folder, LAYOUT))).to.equal(nil)
			local empty = Instance.new("Folder")
			expect((RangeData.nearestPrompt(RangeData.matPosition(b.anchor, 1, LAYOUT), empty, LAYOUT))).to.equal(nil)
			empty:Destroy()
			parent:Destroy()
		end)

		-- WAS "a station whose ground REFUSES a seat": there is no seat to refuse now, so the
		-- ground that broke station 3's footprint costs the range NOTHING. Same injected seam.
		it("builds the same six benches over ground that used to REFUSE a seat", function()
			local dir = 1
			local row = { x = DEV_ROW.x, z = DEV_ROW.z, plate = false, downrange = dir }
			local badX = RangeData.standPosition(Vector3.new(DEV_ROW.x, 0, DEV_ROW.z), 3, LAYOUT, dir).X
			local b, parent = buildInto(row, function(x: number, z: number): number?
				if math.abs(x - badX) < 1 and z < DEV_ROW.z - LAYOUT.STAND.backStuds - 2 then
					return 5
				end
				return 0
			end)
			expect(b).to.be.ok()
			expect(b.stands).to.equal(0)
			expect(b.refusedStands).to.equal(0)
			expect(#b.standRefusals).to.equal(0)
			for spot = 1, LAYOUT.SPOT_COUNT do
				expect(b.folder:FindFirstChild(RangeData.benchName(spot))).to.be.ok()
				expect(b.folder:FindFirstChild(RangeData.matName(spot))).to.be.ok()
				expect(RangeData.promptFor(spot, RangeData.POSITION.BENCH, b.folder)).to.be.ok()
				expect(b.folder:FindFirstChild(RangeData.standName(spot))).to.equal(nil)
				expect(b.deckTops[spot]).to.equal(nil)
			end
			parent:Destroy()
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
			local animal = fake.at(1) :: any
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

		-- TARGET 5, MEASURED FOR THE FIVE SINGLE-SPEED MOVING PACES at the shipped 36-stud window:
		-- 8.00 / 5.00 / 3.27 / 2.50 / 1.50 s. `stand` never crosses and `mixed` has two answers, so
		-- each has its own case. Asserted against TARGET 3's 10 %: walk, slow, trot and fast are
		-- also inside T5's 5 %, and `run` is not -- 0.1 s of scan quantum is 6.7 % of 1.50 s, which
		-- is the shipped sampling rate and not this step's.
		it("measures the crossing seconds at the five moving paces within 10 % of window / paceSpeedFor", function()
			local rows = {}
			for _, pace in ipairs({ "walk", "slow", "trot", "fast", "run" }) do
				local clock, now = newClock()
				local fake = newFakeBoars()
				expect(select(1, startRange(fake, now))).to.equal(true)
				expect(Range.setPace(1, pace)).to.equal(true)
				local trial = Range.trialOf(1) :: any
				-- THE SPEED ASKED FOR IS `paceSpeedFor`'S AND NEVER A LITERAL: the boar's own for
				-- Karen's three, the window divided by the time for ISSF's two.
				local asked = RangeData.paceSpeedFor(pace, LAYOUT, speedOf)
				expect(trial.speedStudsPerSecond).to.equal(asked)
				-- Three full lane lengths' worth of time, whatever the pace.
				advance(fake, clock, 3 * RangeData.laneLength(LAYOUT) / asked + 2)
				trial = Range.trialOf(1) :: any
				local measured = trial.crossingSecondsByPace[pace]
				local predicted = RangeData.crossingSeconds(LAYOUT.WINDOW_STUDS, asked)
				expect(measured).to.be.ok()
				-- TARGET 3: +-10 %. The measurement is quantised to one scan (1 / STEP_HZ = 0.1 s),
				-- which is 6 % of the fastest crossing and inside the tolerance for all three.
				local err = math.abs(measured - predicted) / predicted
				expect(err <= Range.CONFIG.CROSSING_TOLERANCE).to.equal(true)
				-- ...and every order carried that pace's speed and never another's. Since task 321
				-- there is no second speed to be had: the reversal walk that used to be issued out
				-- in the apron went with the reversal.
				local atPace, other = 0, 0
				for _, lead in ipairs(fake.leadsAt(1)) do
					if lead.speed == asked then
						atPace += 1
					else
						other += 1
					end
				end
				expect(other).to.equal(0)
				expect(atPace > 0).to.equal(true)
				table.insert(
					rows,
					string.format("%s %.2f s (predicted %.2f, %.1f %%)", pace, measured, predicted, err * 100)
				)
				Range.stop()
			end
			TestKit.note("range: measured crossings (T5) -- " .. table.concat(rows, " · "))
		end)

		-- ---------------------------------------------------------- TASK 317: THE LANE IS A LINE
		-- Karen, 2026-10-30: she tests walk/trot/run across the whole span, so the distance she
		-- PICKED has to be the distance she SHOOTS. MEASURED on main in her place: at RUN the animal
		-- was 19.72 studs off its own lane line INSIDE the span -- 144.7 studs from a shooter who
		-- picked 125 -- because the 180-degree reversal was arced across the span edge and, aimed at
		-- a lane end 120 studs away, a 2-stud offset is 1 degree, inside the Brain's 4-degree
		-- TURN_DEADBAND_DEG, so it was never corrected.
		--
		-- THE FAKE RUNTIME CANNOT REPRODUCE THE ARC -- it walks straight at whatever point it is
		-- given -- so these cases assert the LEVER, the order this module issues, and the live
		-- per-leg measurement in Karen's place is what asserts the result.
		it("issues a point ON the lane line a lookahead ahead, never the lane end 120 studs away", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now, nil, nil, nil, true))).to.equal(true)
			expect(Range.setPace(1, "run")).to.equal(true)
			advance(fake, clock, 1.0)
			local trial = Range.trialOf(1) :: any
			local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local legEnd = RangeData.laneEndsFor(
				anchor,
				LAYOUT,
				trial.leg,
				RangeData.downrangeOf(DEV_ROW),
				1,
				trial.distanceStuds,
				true
			)
			local animal = fake.at(1)
			expect(animal).to.be.ok()
			local leads = fake.leadsAt(1)
			local last = leads[#leads]
			expect(last).to.be.ok()
			-- ON THE LANE LINE: the issued Z is the lane's, to the stud.
			expect(math.abs(last.point.Z - legEnd.Z) < 1e-6).to.equal(true)
			-- ...AND A LOOKAHEAD AHEAD OF THE ANIMAL, not the end of the leg. With the task-317
			-- block deleted this is the lane end, which is the whole leg away.
			local ahead = math.abs(last.point.X - animal.position.X)
			local toEnd = math.abs(legEnd.X - animal.position.X)
			expect(toEnd > Range.CONFIG.AIM_MIN_STUDS).to.equal(true)
			expect(ahead <= math.max(Range.CONFIG.AIM_MIN_STUDS, last.speed * Range.CONFIG.AIM_SECONDS) + 1e-6).to.equal(
				true
			)
			expect(ahead < toEnd).to.equal(true)
			TestKit.note(
				string.format("range 317: aim point %.1f studs ahead on the lane line, leg end %.1f away", ahead, toEnd)
			)
			Range.stop()
		end)

		-- THE CLAMP, ASSERTED WHERE IT BINDS (round 1, the blocking finding, which was right). The
		-- first version of this case asked for flips and a crossing, and BOTH are true with the whole
		-- lookahead deleted -- the flip is tested against `laneEndsFor`, recomputed each scan, and
		-- never against the issued point, so an unclamped carrot sails past the end and the animal
		-- flips anyway. What only the clamp can give is this: no issued point is ever BEYOND the
		-- leg's end for that leg's heading, and at least one IS the end. Delete the clamp and the
		-- carrot runs a lookahead past it -- into the bank, in the live world.
		it("never orders the animal PAST the lane end, and does order it TO the end", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now, nil, nil, nil, true))).to.equal(true)
			expect(Range.setPace(1, "run")).to.equal(true)
			local trial = Range.trialOf(1) :: any
			local asked = trial.speedStudsPerSecond
			local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local down = RangeData.downrangeOf(DEV_ROW)
			-- The two ends the legs alternate between: odd legs run east, even legs west.
			local eastX = RangeData.laneEndsFor(anchor, LAYOUT, 1, down, 1, trial.distanceStuds, true).X
			local westX = RangeData.laneEndsFor(anchor, LAYOUT, 2, down, 1, trial.distanceStuds, true).X
			expect(eastX > westX).to.equal(true)
			-- STATION 1's OWN ANIMALS, COLLECTED AS THEY COME (task 321): a pass retires its animal,
			-- so `leadsAt(1)` answers for the current one only and the history has to be kept. The
			-- other five stations' lanes are `SPOT_SPACING_STUDS` away in X and would read as 345
			-- orders "past" station 1's ends, which is the arithmetic and not a defect.
			local mine: { [string]: boolean } = {}
			local dt = 1 / 60
			for _ = 1, math.floor((6 * RangeData.laneLength(LAYOUT) / asked + 4) / dt) do
				clock.t += dt
				fake.advance(dt)
				Range.step(dt)
				local id = (Range.trialOf(1) :: any).targetId
				if id ~= nil then
					mine[id :: string] = true
				end
			end
			expect(Range.stats().flips >= 2).to.equal(true)
			expect((Range.trialOf(1) :: any).crossings >= 1).to.equal(true)
			local past, total = 0, 0
			for _, lead in ipairs(fake.leads) do
				if mine[lead.id] then
					total += 1
					if lead.point.X > eastX + 1e-6 or lead.point.X < westX - 1e-6 then
						past += 1
					end
				end
			end
			expect(total > 0).to.equal(true)
			-- NEVER BEYOND. Without the clamp the carrot is `AIM_SECONDS` of run past the end.
			expect(past).to.equal(0)
			-- ...AND THE END IS REALLY ISSUED, so `past == 0` is not just "it never got near it".
			-- BY PARAMETER since task 321: a pass now ends at the span's edge, a whole apron short of
			-- the lane end, so the live loop no longer walks the animal up to it. Put the animal
			-- inside one lookahead of the end and the clamp is the only thing that holds the point.
			-- A PASS THAT HAS NOT REACHED THE SPAN YET, so being out by the lane end is not the END of
			-- it: that is `passEntered`, and a fresh release is the one state in which the clamp can
			-- still be convicted. One tick of a new range is exactly that animal.
			Range.stop()
			local fake2 = newFakeBoars()
			local clock2, now2 = newClock()
			expect(select(1, startRange(fake2, now2, nil, nil, nil, true))).to.equal(true)
			expect(Range.setPace(1, "run")).to.equal(true)
			advance(fake2, clock2, 1 / Range.CONFIG.STEP_HZ + 2 / 60)
			local here = fake2.at(1) :: any
			expect(here).to.be.ok()
			local legNow = (Range.trialOf(1) :: any).leg
			local endX = RangeData.laneEndsFor(anchor, LAYOUT, legNow, down, 1, trial.distanceStuds, true).X
			local lookahead = math.max(Range.CONFIG.AIM_MIN_STUDS, asked * Range.CONFIG.AIM_SECONDS)
			local heading = if (legNow % 2) == 1 then 1 else -1
			here.position = Vector3.new(endX - heading * (lookahead / 2), here.position.Y, here.position.Z)
			local before = #fake2.leads
			local mineNow = (Range.trialOf(1) :: any).targetId
			advance(fake2, clock2, 0.2)
			local atEnd = 0
			for i = before + 1, #fake2.leads do
				if fake2.leads[i].id == mineNow and math.abs(fake2.leads[i].point.X - endX) < 1e-6 then
					atEnd += 1
				end
			end
			expect(atEnd > 0).to.equal(true)
			TestKit.note(
				string.format(
					"range 321: %d orders, %d beyond a lane end, %d clamped TO the end from half a lookahead out (ends %.1f / %.1f)",
					total,
					past,
					atEnd,
					westX,
					eastX
				)
			)
			Range.stop()
		end)

		-- ---------------------------------------------------- TASK 321: ONE PASS, ONE ANIMAL
		-- KAREN, 2026-10-31, after playing 319: *"it's the same animal running we need each time it
		-- run on one side new one comes ... it runs or walks no matter killed or no it comes to end
		-- new animal comes old gone ... and it has to be new one imediatly not neet to wait to long"*.
		-- MEASURED on main in her place (`<runs-dir>/321-pass.luau`, d7ae1929): ONE animal, FOUR
		-- crossings, 7.12 s out of sight between them. The apron reversal that cost those seconds is
		-- archived (`backups/2026-10-31-range-apron-reversal.md`).
		it("runs ONE animal per pass: a NEW id each crossing, the old one gone, both directions", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now, nil, nil, nil, true))).to.equal(true)
			expect(Range.setPace(1, "trot")).to.equal(true)
			local ids: { string } = {}
			local seen: { [string]: boolean } = {}
			local live = 0
			local dt = 1 / 60
			for _ = 1, math.floor(40 / dt) do
				clock.t += dt
				fake.advance(dt)
				Range.step(dt)
				local id = (Range.trialOf(1) :: any).targetId
				if id ~= nil and ids[#ids] ~= id then
					-- A PASS NEVER GETS ITS OWN ANIMAL BACK: the id is retired with the pass.
					expect(seen[id :: string]).to.equal(nil)
					seen[id :: string] = true
					table.insert(ids, id :: string)
				end
				-- STATION 1's OWN, and not the firing line's: the default crowd is six men, so six
				-- animals are alive at any moment and only this station's are this case's business.
				local alive = 0
				for _, animal in pairs(fake.animals) do
					if animal.alive and seen[animal.id] == true then
						alive += 1
					end
				end
				if alive > live then
					live = alive
				end
			end
			local trial = Range.trialOf(1) :: any
			-- SEVERAL PASSES, each by a different animal, in 40 s at a trot.
			expect(#ids >= 4).to.equal(true)
			expect(trial.passes).to.equal(#ids)
			-- ...AND ONE CROSSING PER PASS, which is the whole of (a): no animal crosses twice.
			expect(trial.crossings >= #ids - 1).to.equal(true)
			expect(trial.crossings <= trial.passes).to.equal(true)
			-- ...AND THE OLD ONE IS GONE: one live animal at a time, never two on the lane.
			expect(live).to.equal(1)
			-- ...AND THE DIRECTION ALTERNATES (b): the leg changes with every pass.
			expect((trial.directions.east or 0) > 0).to.equal(true)
			expect((trial.directions.west or 0) > 0).to.equal(true)
			TestKit.note(
				string.format(
					"range 321: %d passes by %d animals in 40 s at a trot, %d crossings, at most %d alive at once",
					trial.passes,
					#ids,
					trial.crossings,
					live
				)
			)
			Range.stop()
		end)

		-- (b) THE GAP, AS A TIME AND AT EVERY PACE. The run-up is `pace speed * NEXT_PASS_SECONDS`
		-- of apron, so the next animal reaches the span's near edge that long after the last one left
		-- it, whatever the pace. On main the gap is a whole reversal: 7.12 s, measured.
		it("starts the next pass within NEXT_PASS_SECONDS of the last one leaving the span", function()
			local rows = {}
			for _, pace in ipairs({ "walk", "trot", "run" }) do
				local clock, now = newClock()
				local fake = newFakeBoars()
				expect(select(1, startRange(fake, now, nil, nil, nil, true))).to.equal(true)
				expect(Range.setPace(1, pace)).to.equal(true)
				local trial = Range.trialOf(1) :: any
				local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
				local lo, hi = RangeData.sightSpanFor(anchor, 1, LAYOUT, trial.distanceStuds, true)
				local dt = 1 / 60
				local lastOut: number? = nil
				local worst, gaps = 0, 0
				local inside = false
				for _ = 1, math.floor(60 / dt) do
					clock.t += dt
					fake.advance(dt)
					Range.step(dt)
					local here = fake.at(1) :: any
					local isIn = here ~= nil and RangeData.inWindow(lo, hi, here.position.X)
					if isIn and not inside then
						inside = true
						if lastOut ~= nil then
							local gap = clock.t - (lastOut :: number)
							gaps += 1
							if gap > worst then
								worst = gap
							end
						end
					elseif inside and not isIn then
						inside = false
						lastOut = clock.t
					end
				end
				expect(gaps >= 2).to.equal(true)
				-- THE CLAIM, AND IT IS THE ONE KAREN MADE: at most a second with nothing to look at.
				expect(worst <= 1.0).to.equal(true)
				table.insert(rows, string.format("%s %.2f s over %d gaps", pace, worst, gaps))
				Range.stop()
			end
			TestKit.note("range 321: worst out-of-sight gap between passes -- " .. table.concat(rows, " · "))
		end)

		-- (c) A KILL. The carcass stays where it fell (task 318) and the next animal does NOT wait for
		-- it: on main the next live target is `CARCASS_SECONDS` + the old `RELEASE_SECONDS` away,
		-- which 319 measured at +4.37 s in Karen's place.
		it("releases the next animal within a tick of a kill, with the carcass still lying there", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now, nil, nil, nil, true))).to.equal(true)
			expect(Range.setPace(1, "trot")).to.equal(true)
			advance(fake, clock, 4)
			local carcass = animalAt(fake, clock, 1) :: any
			expect(carcass).to.be.ok()
			local trial = Range.trialOf(1) :: any
			local killedId = trial.targetId :: string
			expect(killedId).to.equal(carcass.id)
			carcass.alive = false
			local fellAt = carcass.position
			local killedAtT = clock.t
			-- ONE SCAN TICK is all it may take.
			advance(fake, clock, 1 / Range.CONFIG.STEP_HZ + 2 / 60)
			trial = Range.trialOf(1) :: any
			local nextId = trial.targetId
			expect(nextId).to.be.ok()
			expect(nextId ~= killedId).to.equal(true)
			expect(clock.t - killedAtT <= 1.0).to.equal(true)
			-- THE CARCASS IS STILL THERE, AND WHERE IT FELL.
			expect(trial.carcassId).to.equal(killedId)
			expect(fake.animals[killedId]).to.be.ok()
			expect((fake.animals[killedId].position - fellAt).Magnitude <= 1e-6).to.equal(true)
			-- ...AND CARCASS_SECONDS LATER IT IS GONE, with the pass after it still running.
			advance(fake, clock, Range.CONFIG.CARCASS_SECONDS + 0.3)
			trial = Range.trialOf(1) :: any
			expect(fake.animals[killedId]).to.equal(nil)
			expect(trial.carcassId).to.equal(nil)
			expect(trial.targetId).to.be.ok()
			TestKit.note(
				string.format(
					"range 321: next animal one %.1f Hz tick after the kill; carcass held its own %.0f s",
					Range.CONFIG.STEP_HZ,
					Range.CONFIG.CARCASS_SECONDS
				)
			)
			Range.stop()
		end)

		-- `mixed` IS NOT A SIXTH SPEED: every LEG is drawn as slow OR fast, so every crossing it
		-- measures is 5.00 s or 2.50 s and never anything between them.
		--
		-- THE DRAW IS INJECTED (`seams.roll`), so this runs the two legs BY PARAMETER instead of
		-- waiting on `math.random` -- and the assertion is that the speed CHANGED WITH THE LEG.
		-- Round 1, finding 1: a case that only asked "every order was one of two speeds" stayed
		-- green with the per-leg redraw deleted, because one fixed speed is also one of two.
		it("redraws `mixed` on every leg, so the ordered speed CHANGES when the leg does", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			-- slow, fast, slow, fast, ... one draw per leg, in order.
			local rolls, drawn = { 0.1, 0.9 }, 0
			expect(select(
				1,
				startRange(fake, now, function()
					drawn += 1
					return rolls[((drawn - 1) % #rolls) + 1]
				end)
			)).to.equal(true)
			expect(Range.setPace(1, RangeData.WORD.MIXED)).to.equal(true)
			local slowSpeed = RangeData.paceSpeedFor("slow", LAYOUT, speedOf)
			local fastSpeed = RangeData.paceSpeedFor("fast", LAYOUT, speedOf)
			-- Long enough for several legs at the SLOWER of the two.
			advance(fake, clock, 6 * RangeData.laneLength(LAYOUT) / slowSpeed)
			local trial = Range.trialOf(1) :: any
			expect(trial.crossings >= 2).to.equal(true)
			-- THE REDRAW HAPPENED, AND ON THIS LEG: `legDrawn` is nil with the block deleted.
			expect(trial.legDrawn).to.equal(trial.leg)
			expect(trial.drewWord == RangeData.WORD.SLOW or trial.drewWord == RangeData.WORD.FAST).to.equal(true)
			expect(drawn >= trial.leg).to.equal(true)
			-- EVERY ORDER WAS ONE OF EXACTLY TWO SPEEDS, asked as membership and not as a count
			-- (a count of 0 is truthy in Lua, which is how the old case passed)...
			local slowOrders, fastOrders, other = 0, 0, 0
			for _, lead in ipairs(fake.leadsAt(1)) do
				if lead.speed == slowSpeed then
					slowOrders += 1
				elseif lead.speed == fastSpeed then
					fastOrders += 1
				else
					other += 1
				end
			end
			expect(other).to.equal(0)
			-- ...AND BOTH APPEARED, which one fixed draw cannot produce: the rolls alternate per
			-- leg, so deleting the redraw leaves every order at the FIRST speed and this fails.
			expect(slowOrders > 0).to.equal(true)
			expect(fastOrders > 0).to.equal(true)
			local measured = trial.crossingSecondsByPace[RangeData.WORD.MIXED]
			expect(measured).to.be.ok()
			local nearSlow = math.abs(measured - 5.0) / 5.0 <= Range.CONFIG.CROSSING_TOLERANCE
			local nearFast = math.abs(measured - 2.5) / 2.5 <= Range.CONFIG.CROSSING_TOLERANCE
			expect(nearSlow or nearFast).to.equal(true)
			TestKit.note(
				string.format(
					"range: mixed -- %d slow orders, %d fast orders over %d legs, %d crossings, last %.2f s (5.00 or 2.50)",
					slowOrders,
					fastOrders,
					trial.leg,
					trial.crossings,
					measured
				)
			)
			Range.stop()
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
			local animal = fake.at(1) :: any
			local offset = math.abs(animal.position.X - centre.X)
			expect(offset < LAYOUT.WINDOW_STUDS / 2).to.equal(true)
			TestKit.note(string.format("range: picked WALK with the target %.1f studs inside the window", offset))
			-- THE PICK, mid-window.
			local before = (Range.trialOf(1) :: any).crossings
			expect(Range.setPace(1, RangeData.WORD.WALK)).to.equal(true)
			-- THE *FIRST* CROSSING AFTER THE PICK IS THE ONE SHE READS, and it is the only one the
			-- defect can be seen in: run on and a later whole crossing overwrites it with the right
			-- number, which is why the board was wrong for one crossing and right afterwards.
			local trial = Range.trialOf(1) :: any
			local waited = 0
			while trial.crossings == before and waited < 3 * RangeData.laneLength(LAYOUT) / speedOf("walk") do
				advance(fake, clock, 0.1)
				waited += 0.1
				trial = Range.trialOf(1) :: any
			end
			expect(trial.crossings).to.equal(before + 1)
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

		-- TASK 316. The Director read `RUN ... crossing 9.13 s` on the wide span against 4.18 s of
		-- arithmetic and took it for a boar that could not hold its pace. MEASURED in Karen's place at
		-- `f06f9358`: the boar holds 24.00 studs/s for 100 % of the samples inside the span and crosses
		-- it in 4.24 s. 9.13 s is `100.33 / 11` -- a TROT, measured 9.14 s -- and this is how a trot's
		-- seconds come to be printed under RUN: `setPace` disarmed the timer but left
		-- `lastCrossingSeconds`, and `blankRecord` copies that into the fresh record a pick makes.
		-- Reproduced live through the real remote: `pace=walk issued=4.5 crossing=4.15 s`.
		it("drops the crossing the OLD pace measured, and the old lane's, when the pick changes it", function()
			Range.stop()
			local clock, now = newClock()
			local fake = newFakeBoars()
			local started = select(1, startRange(fake, now))
			local man = manOnMat(1) :: any
			local pacedTrot = Range.setPace(1, RangeData.WORD.TROT)

			-- EVERYTHING IS READ FIRST AND ASSERTED AFTER `Range.stop()`: a failed `expect` ends the
			-- body, and a range left started makes every later case's `startRange` return false.
			local function crossOnce(): number?
				local before = (Range.trialOf(1) :: any).crossings
				local waited = 0
				while (Range.trialOf(1) :: any).crossings == before and waited < 120 do
					advance(fake, clock, 0.1)
					waited += 0.1
				end
				local trial = Range.trialOf(1) :: any
				return if trial.crossings == before + 1 then trial.lastCrossingSeconds else nil
			end

			-- ONE WHOLE CROSSING AT A TROT, so there is a real measurement to carry or to drop.
			local trot = crossOnce()
			-- THE CONTROL, AND IT IS WHAT MAKES THE CASE BITE: a pick that changes neither the pace nor
			-- the lane still makes a fresh record, and that record DOES carry the crossing -- so the
			-- mechanism is live and the assertions below are about WHICH pick drops it, not about a
			-- field nobody fills.
			local keptOk = Range.onRequest(man, { weapon = "rifle" })
			local kept = Range.recordOf(man) :: any
			-- THE PACE PICK. Before this task the fresh record carried the TROT seconds beside RUN's
			-- 24 studs/s, which is exactly the board the Director read.
			advance(fake, clock, 0.2)
			local pickedOk = Range.onRequest(man, { pace = RangeData.WORD.RUN })
			local picked = Range.recordOf(man) :: any
			-- ...AND IT COMES BACK, measured under the pace it is now labelled with.
			local run = crossOnce()
			advance(fake, clock, 0.2)
			local backOk = Range.onRequest(man, { weapon = "shotgun" })
			local back = Range.recordOf(man) :: any
			-- THE LANE PICK, the same rule: the span is per distance, so seconds measured over one lane
			-- are not the next lane's crossing.
			advance(fake, clock, 0.2)
			local other = (Range.trialOf(1) :: any).distanceStuds
			for _, studs in ipairs(LAYOUT.DISTANCES_STUDS) do
				if studs ~= other then
					other = studs
					break
				end
			end
			local laneOk = Range.onRequest(man, { distanceStuds = other })
			local lane = Range.recordOf(man) :: any
			local laneStuds = (Range.trialOf(1) :: any).distanceStuds
			Range.stop()

			expect(started).to.equal(true)
			expect(pacedTrot).to.equal(true)
			expect(trot).to.be.ok()
			expect(keptOk).to.equal(true)
			expect(kept.pace).to.equal(RangeData.WORD.TROT)
			expect(kept.crossingSeconds).to.equal(trot)
			expect(pickedOk).to.equal(true)
			expect(picked.pace).to.equal(RangeData.WORD.RUN)
			expect(picked.issuedStudsPerSecond).to.equal(speedOf("run"))
			-- THE LINE THAT FAILS ON `f06f9358`: it read 3.27 s, which is `WINDOW_STUDS / 11` -- the
			-- trot above, printed under RUN. On the wide span the same arithmetic is 9.14 s.
			expect(picked.crossingSeconds).to.equal(nil)
			expect(run).to.be.ok()
			local predicted = RangeData.crossingSeconds(LAYOUT.WINDOW_STUDS, speedOf("run"))
			local err = math.abs((run :: number) - predicted) / predicted
			expect(err <= Range.CONFIG.CROSSING_TOLERANCE).to.equal(true)
			expect(backOk).to.equal(true)
			expect(back.crossingSeconds).to.equal(run)
			expect(laneOk).to.equal(true)
			expect(laneStuds).to.equal(other)
			expect(lane.crossingSeconds).to.equal(nil)
			TestKit.note(
				string.format(
					"range: trot crossing %.2f s dropped by the RUN pick; run measured %.2f s (predicted %.2f, %.1f %%)",
					trot :: number,
					run :: number,
					predicted,
					err * 100
				)
			)
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
				local animal = fake.at(1) :: any
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
			expect(fake.at(1).speed).to.equal(0)
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

		-- TASK 321 REWROTE THE TIMING HALF OF THIS CASE: the fresh target no longer waits for the
		-- carcass (c), so a kill releases on the next tick and the carcass is cleared on its own
		-- clock. What is unchanged, and is still the point of the case, is step B7's must-fix 1:
		-- the clear is HIS animal, through `clearOne`, and the other five stations keep theirs.
		it("clears a killed target after CARCASS_SECONDS and releases a fresh one AT ONCE", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			advance(fake, clock, 2)
			expect(fake.spawns).to.equal(LAYOUT.SPOT_COUNT)
			local dead = animalAt(fake, clock, 1) :: any
			expect(dead).to.be.ok()
			local deadId = dead.id
			dead.alive = false

			-- WHOSE ANIMALS THE OTHER FIVE STATIONS HAVE, before the kill: the identities are
			-- compared after it, which is what "and only his" means.
			local othersBefore = {}
			for spot = 2, LAYOUT.SPOT_COUNT do
				othersBefore[spot] = (fake.at(spot) :: any).id
			end

			-- ONE TICK: the next animal is out, and the carcass is still lying there untouched.
			advance(fake, clock, 1 / Range.CONFIG.STEP_HZ + 2 / 60)
			expect(fake.spawns).to.equal(LAYOUT.SPOT_COUNT + 1)
			expect(Range.stats().carcasses).to.equal(1)
			expect(Range.stats().releases).to.equal(1)
			expect(fake.clears).to.equal(0)
			expect(fake.animals[deadId]).to.be.ok()
			expect((Range.trialOf(1) :: any).carcassId).to.equal(deadId)
			expect((fake.at(1) :: any).alive).to.equal(true)
			expect((fake.at(1) :: any).id ~= deadId).to.equal(true)
			-- ONE TICK LATER THE OTHER FIVE ARE THE SAME ANIMALS, which is what "and only his" means:
			-- no pass of theirs can have finished in a tenth of a second.
			for spot = 2, LAYOUT.SPOT_COUNT do
				expect((fake.at(spot) :: any).id).to.equal(othersBefore[spot])
			end

			-- ...AND CARCASS_SECONDS AFTER THE KILL IT GOES, as HIS animal and only his. The counters
			-- read here are HIS: `fake.clears` is the whole range's, and since task 321 the other
			-- five stations finish passes of their own inside these three seconds.
			advance(fake, clock, Range.CONFIG.CARCASS_SECONDS + 0.5)
			expect(fake.animals[deadId]).to.equal(nil)
			expect((Range.trialOf(1) :: any).carcassId).to.equal(nil)
			expect(fake.clearOnes >= 1).to.equal(true)
			-- ONE ANIMAL WENT AND ONE CAME BACK -- STEP B7's MUST-FIX 1. Until B7 this read
			-- `2 * SPOT_COUNT` spawns and `SPOT_COUNT - 1` lost targets, because `boars.clear` was
			-- range-WIDE and one man's carcass took the other five stations' animals with it. The
			-- lever is `Boar.Runtime:clearOne`, wired as `boars.clearOne`.
			expect(Range.stats().lostTargets).to.equal(0)
			expect(Range.stats().wideClears).to.equal(0)
			-- THE OTHER FIVE STILL HAVE ANIMALS, and none of them was cleared by HIS kill: the
			-- identities are compared ONE TICK after it (above), because over `CARCASS_SECONDS` they
			-- retire animals of their own -- that is the pass loop, not a wide clear.
			for spot = 2, LAYOUT.SPOT_COUNT do
				expect(fake.at(spot)).to.be.ok()
			end
			-- THE NEW TARGET IS STEERED LIKE THE FIRST, measured as a RISE from a snapshot taken
			-- after the release (review round 1, finding 2: a `flips >= 1` on a cumulative counter
			-- passes with the whole re-release path deleted).
			local flipsAfterRelease = Range.stats().flips
			local leadsAfterRelease = #fake.leadsAt(1)
			advance(fake, clock, 20)
			expect(Range.stats().flips > flipsAfterRelease).to.equal(true)
			expect(#fake.leadsAt(1) > leadsAfterRelease).to.equal(true)
			expect((fake.at(1) :: any).position.X ~= nil).to.equal(true)
			TestKit.note(
				string.format(
					"range 321: fresh target one tick after the kill, carcass cleared %d s later",
					Range.CONFIG.CARCASS_SECONDS
				)
			)
			Range.stop()
		end)

		-- TASK 319. KAREN, 2026-10-31: *"i don't need each time click e to have new animal, I killed,
		-- then new comes after few seconds I can click e and change settings I also can leave then
		-- end"*. The first half is a GUARD -- it passes on main, and it is here because the auto-next
		-- is what the leave must not break. MEASURED in her place at a659b5f9: a new live animal
		-- 4.3 s after the kill with no E pressed.
		it("brings the next animal by itself after a kill, with the settings he last picked", function()
			Range.stop()
			local clock, now = newClock()
			local fake = newFakeBoars()
			local crowd = newCrowd({ 2 })
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			local man = crowd.men[1]
			advance(fake, clock, 1)
			-- HE PICKS ONCE, and never asks again in this case.
			expect(Range.onRequest(man, { spot = 2, species = "reddeer", pace = RangeData.WORD.RUN })).to.equal(true)
			advance(fake, clock, 1)
			local before = Range.trialOf(2) :: any
			local firstId = before.targetId
			expect(firstId).to.be.ok()
			expect(before.species).to.equal("reddeer")
			local spawnsBefore = fake.spawns
			local doomed = animalAt(fake, clock, 2) :: any
			expect(doomed).to.be.ok()
			doomed.alive = false
			-- NOTHING IS SENT: the next animal comes on the owner's own clock.
			advance(fake, clock, Range.CONFIG.CARCASS_SECONDS + 1)
			local after = Range.trialOf(2) :: any
			expect(after.targetId).to.be.ok()
			expect(after.targetId ~= firstId).to.equal(true)
			-- AT LEAST ONE MORE, and since task 321 possibly several: a pass that finishes is
			-- followed by the next one, so this count rises on its own and is not an equality.
			expect(fake.spawns >= spawnsBefore + 1).to.equal(true)
			expect((fake.at(2) :: any).alive).to.equal(true)
			-- ...WITH THE SAME SETTINGS HE PICKED: species, kind, pace and lane all carried over.
			expect(after.species).to.equal("reddeer")
			expect(after.kind).to.equal(before.kind)
			expect(after.pace).to.equal(RangeData.WORD.RUN)
			expect(after.distanceStuds).to.equal(before.distanceStuds)
			expect(after.spot).to.equal(2)
			TestKit.note(
				string.format(
					"range: next animal by itself %.1f s after the kill, same settings",
					Range.CONFIG.CARCASS_SECONDS
				)
			)
			Range.stop()
		end)

		-- TASK 319, THE HALF THAT FAILS ON MAIN: `leave` is not a word the door knows there, so the
		-- first assertion below reads `false`. *"I also can leave then end"*.
		it("ends the session on a leave request, and re-arms when he asks again or walks away", function()
			Range.stop()
			local clock, now = newClock()
			local fake = newFakeBoars()
			local crowd = newCrowd({ 2 })
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			local man = crowd.men[1]
			advance(fake, clock, 1)
			expect((Range.trialOf(2) :: any).targetId).to.be.ok()
			local clearOnesBefore = fake.clearOnes
			local leavesBefore = Range.stats().leaves

			-- HE LEAVES: his own animal goes, through `clearOne` and not a range-wide clear.
			expect(Range.onRequest(man, { spot = 2, leave = true })).to.equal(true)
			expect((Range.trialOf(2) :: any).targetId).to.equal(nil)
			expect((Range.trialOf(2) :: any).ended).to.equal(true)
			expect(fake.clearOnes).to.equal(clearOnesBefore + 1)
			expect(Range.stats().leaves).to.equal(leavesBefore + 1)
			expect(Range.stats().wideClears).to.equal(0)

			-- ...AND NOTHING COMES WHILE HE STANDS THERE, which is what "end" means.
			local spawnsBefore = fake.spawns
			advance(fake, clock, 10)
			expect(fake.spawns).to.equal(spawnsBefore)
			expect((Range.trialOf(2) :: any).targetId).to.equal(nil)

			-- RE-ARM 1: HE ASKS AGAIN. One `go` -- the confirm bar's own word -- and the lane is live.
			expect(Range.onRequest(man, { spot = 2, go = true })).to.equal(true)
			expect((Range.trialOf(2) :: any).ended).to.equal(false)
			advance(fake, clock, 1)
			expect((Range.trialOf(2) :: any).targetId).to.be.ok()
			expect(fake.spawns).to.equal(spawnsBefore + 1)

			-- RE-ARM 2: HE ENDS AND WALKS OFF, and the station the next man finds is a live one.
			expect(Range.onRequest(man, { spot = 2, leave = true })).to.equal(true)
			expect((Range.trialOf(2) :: any).ended).to.equal(true)
			crowd.set({})
			advance(fake, clock, 1)
			expect((Range.trialOf(2) :: any).ended).to.equal(false)
			local spawnsAway = fake.spawns
			-- NOBODY THERE IS STILL NOBODY'S ANIMAL (design 7.4): the re-arm is not a release.
			expect(spawnsAway).to.equal(spawnsBefore + 1)
			crowd.set({ 2 })
			advance(fake, clock, 1)
			expect(fake.spawns).to.equal(spawnsAway + 1)
			expect((Range.trialOf(2) :: any).targetId).to.be.ok()
			TestKit.note("range: leave ends the session, and an ask or a walk-off re-arms the station")
			Range.stop()
		end)

		-- COUNTED BY THE ANIMAL'S OWN ID, and AT A WALK so its pass cannot finish mid-case (task
		-- 321): `leadsAt(spot)` answers for whichever animal the station holds NOW, and since a pass
		-- retires its animal that is not necessarily the one the flight was about.
		it("never orders an animal the Brain is flying", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			expect(Range.setPace(1, "walk")).to.equal(true)
			advance(fake, clock, 2)
			local animal = fake.at(1) :: any
			expect(animal).to.be.ok()
			local function leadsOf(id: string): number
				local count = 0
				for _, lead in ipairs(fake.leads) do
					if lead.id == id then
						count += 1
					end
				end
				return count
			end
			fake.flyingIds[animal.id] = true
			local leadsBefore = leadsOf(animal.id)
			local skippedBefore = Range.stats().skippedFlying
			advance(fake, clock, 2)
			-- IT ENTERED THE BRANCH, and issued nothing: *"the drive must not order an animal the
			-- Brain is flying"*.
			expect(Range.stats().skippedFlying > skippedBefore).to.equal(true)
			expect(leadsOf(animal.id)).to.equal(leadsBefore)
			-- ...and it picks the lane up again when the flight ends.
			fake.flyingIds[animal.id] = false
			advance(fake, clock, 1)
			expect(leadsOf(animal.id) > leadsBefore).to.equal(true)
			Range.stop()
		end)
	end)

	-- ------------------------------------------------- 12. ONE ANIMAL PER *OCCUPIED* STATION (B7)
	--
	-- Design 7.4 and 11.2 group 12. THIS is the functional instrument for the sentence "release on
	-- arrival, clear on idle": design 12's T10 and T11 are the COST targets (<= 2 ms a step,
	-- <= 3 ms a frame), and only T11's trailing clause -- "an empty range costs 0 spawns" -- is
	-- about occupancy at all.
	describe("one animal per occupied station", function()
		it("releases NOTHING with nobody at the range", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			local crowd = newCrowd({})
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			-- Two full minutes of scanning.
			advance(fake, clock, 120)
			expect(fake.spawns).to.equal(0)
			expect(Range.stats().occupied).to.equal(0)
			expect(Range.stats().targets).to.equal(0)
			expect(Range.stats().scans > 0).to.equal(true)
			TestKit.note(string.format("range B7: empty range, %d scans, %d spawns", Range.stats().scans, fake.spawns))
			Range.stop()
		end)

		it("releases nothing at all when the root wired no player list", function()
			-- THE UNMEASURED CASE: `players` nil means the range cannot measure who is where, and
			-- then it releases nothing rather than guessing six men (design 7.4).
			local clock, now = newClock()
			local fake = newFakeBoars()
			local root = Instance.new("Folder")
			expect(Range.start({
				enabled = true,
				anchor = DEV_ROW,
				root = root,
				boars = fake,
				now = now,
			})).to.equal(true)
			advance(fake, clock, 60)
			expect(fake.spawns).to.equal(0)
			expect(Range.stats().occupied).to.equal(0)
			Range.stop()
			root:Destroy()
		end)

		it("gives a man who arrives at station 2 exactly ONE animal, at station 2", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			local crowd = newCrowd({})
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			advance(fake, clock, 10)
			expect(fake.spawns).to.equal(0)
			-- HE ARRIVES. The position is read on the step that RELEASED it -- `fake.advance` has not
			-- run since -- so it is the release point itself and not a point the animal walked to.
			crowd.set({ 2 })
			local released = nil
			for _ = 1, 120 do
				clock.t += 1 / 60
				fake.advance(1 / 60)
				Range.step(1 / 60)
				local animal = fake.at(2)
				if animal ~= nil then
					released = (animal :: any).position
					break
				end
			end
			expect(released).to.be.ok()
			expect(fake.spawns).to.equal(1)
			expect(Range.stats().targets).to.equal(1)
			expect(Range.stats().occupied).to.equal(1)
			for _, spot in ipairs({ 1, 3, 4, 5, 6 }) do
				expect(fake.at(spot)).to.equal(nil)
			end
			-- ...AND IT IS IN *HIS* LANE, which is an assertion about X ALONE (round 1, finding 1):
			-- `laneCentre`'s Z is `anchor.Z + DISTANCE_STUDS` for ALL SIX stations, so any Z pair is
			-- the same number through two names and cannot fail. The discriminator is the release
			-- point against station 2's own lane end and station 1's -- `SPOT_SPACING_STUDS` apart,
			-- asserted here so the two sides are known to be different numbers.
			-- THE RELEASE POINT IS THE PASS'S RUN-UP since task 321, not the lane end: `NEXT_PASS_SECONDS`
			-- of this pace's own speed, outside the span, so the animal is in his sight one run-up later.
			local anchorXZ = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local runUp = Range.CONFIG.NEXT_PASS_SECONDS
				* RangeData.paceSpeedFor(Range.CONFIG.DEFAULT_PACE, LAYOUT, speedOf)
			local end2 = RangeData.passEntryFor(anchorXZ, LAYOUT, 1, nil, 2, LAYOUT.DISTANCE_STUDS, false, runUp)
			local end1 = RangeData.passEntryFor(anchorXZ, LAYOUT, 1, nil, 1, LAYOUT.DISTANCE_STUDS, false, runUp)
			expect(math.abs(end2.X - end1.X)).to.equal(LAYOUT.SPOT_SPACING_STUDS)
			expect(math.abs((released :: any).X - end2.X) < 0.001).to.equal(true)
			expect(math.abs((released :: any).X - end1.X) >= LAYOUT.SPOT_SPACING_STUDS - 0.001).to.equal(true)
			-- Z is the lane's, which every station shares: asserted as the DOWNRANGE fact it is.
			expect(math.abs((released :: any).Z - (DEV_ROW.z + LAYOUT.DISTANCE_STUDS)) < 0.001).to.equal(true)
			TestKit.note(
				string.format(
					"range B7: one man at station 2 -> %d spawn(s) at x %.1f (station 2's end %.1f, station 1's %.1f)",
					fake.spawns,
					(released :: any).X,
					end2.X,
					end1.X
				)
			)
			Range.stop()
		end)

		it("clears HIS animal IDLE_CLEAR_SECONDS after he leaves, not before, and leaves station 4 alone", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			local crowd = newCrowd({ 2, 4 })
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			advance(fake, clock, 1)
			expect(fake.spawns).to.equal(2)
			-- STATION 2 IS STANDING ITS ANIMAL (task 321): a pass retires its own animal at the span
			-- edge, so the idle clock is only ever the thing that clears a target for a man who has
			-- gone if that target has no pass to end -- which is exactly `stand`.
			expect(Range.setPace(2, RangeData.WORD.STAND)).to.equal(true)
			local his = (fake.at(2) :: any).id
			-- HE LEAVES. Station 4's man does not.
			crowd.set({ 4 })
			advance(fake, clock, Range.CONFIG.IDLE_CLEAR_SECONDS - 2)
			-- NOT BEFORE: his animal is still there two seconds short of the idle time.
			expect(fake.at(2)).to.be.ok()
			expect((fake.at(2) :: any).id).to.equal(his)
			expect(Range.stats().idleClears).to.equal(0)
			advance(fake, clock, 3)
			-- ...AND THEN IT GOES, through the PER-ID despawn.
			expect(fake.at(2)).to.equal(nil)
			-- `fake.lastClear` IS THE RANGE'S LAST WRITER, not his: station 4 ends passes of its own
			-- on these same ticks, so the station-scoped counter is what this asserts.
			expect(Range.stats().idleClears).to.equal(1)
			expect(Range.stats().wideClears).to.equal(0)
			-- STATION 4 IS UNAFFECTED: still running passes, still steered, never cleared for him.
			expect(fake.at(4)).to.be.ok()
			expect(Range.stats().targets).to.equal(1)
			local leadsBefore = #fake.leadsAt(4)
			advance(fake, clock, 5)
			expect(#fake.leadsAt(4) > leadsBefore).to.equal(true)
			-- AND NOTHING IS RE-RELEASED AT THE STATION HE LEFT: his lane stays empty.
			expect(fake.at(2)).to.equal(nil)
			TestKit.note(
				string.format(
					"range B7: station 2 cleared %d s after he left (not at %d s); station 4 untouched",
					Range.CONFIG.IDLE_CLEAR_SECONDS,
					Range.CONFIG.IDLE_CLEAR_SECONDS - 2
				)
			)
			Range.stop()
		end)

		it("gives him his animal back when he comes back", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			local crowd = newCrowd({ 2 })
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			advance(fake, clock, 1)
			expect(fake.spawns).to.equal(1)
			crowd.set({})
			advance(fake, clock, Range.CONFIG.IDLE_CLEAR_SECONDS + 1)
			expect(fake.at(2)).to.equal(nil)
			crowd.set({ 2 })
			advance(fake, clock, 1)
			expect(fake.spawns).to.equal(2)
			expect(fake.at(2)).to.be.ok()
			Range.stop()
		end)

		it("counts a range-WIDE clear when the root wired no clearOne", function()
			-- BOTH ARMS OF `clearTarget` BY PARAMETER. A root that wires only the range-wide
			-- `boars.clear` reproduces the B2 defect -- and the owner COUNTS it (`wideClears`)
			-- instead of hiding it, which is the only way that mis-wiring is visible in a stats line.
			local clock, now = newClock()
			local fake = newFakeBoars()
			fake.clearOne = nil
			local crowd = newCrowd({ 1, 2 })
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			advance(fake, clock, 1)
			expect(fake.spawns).to.equal(2)
			-- BOTH STANDING, so the IDLE arm is the only clear there is (task 321): the seam here is
			-- the range-WIDE one, so a pass ending at EITHER station would take both animals first
			-- and the idle clock would find nothing left to clear.
			expect(Range.setPace(1, RangeData.WORD.STAND)).to.equal(true)
			expect(Range.setPace(2, RangeData.WORD.STAND)).to.equal(true)
			crowd.set({ 1 })
			advance(fake, clock, Range.CONFIG.IDLE_CLEAR_SECONDS + 1)
			expect(Range.stats().idleClears).to.equal(1)
			expect(Range.stats().wideClears >= 1).to.equal(true)
			-- ...and station 1's animal went with it, which is the defect, measured.
			expect(fake.at(1)).to.equal(nil)
			expect(Range.stats().lostTargets >= 1).to.equal(true)
			Range.stop()
		end)

		it("does not hold a DEAD id for ever when the clear seam refuses", function()
			-- ROUND 2, NOTE 2. The idle arm used to `continue` whatever `clearTarget` answered, so a
			-- seam that refused left the trial holding an id of an animal that was already gone:
			-- `statusOf`'s `lostTargets` cleanup below it was unreachable, `stats.targets`
			-- over-counted it for ever and the mask kept it.
			local clock, now = newClock()
			local fake = newFakeBoars()
			local crowd = newCrowd({ 2 })
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			advance(fake, clock, 1)
			expect(fake.spawns).to.equal(1)
			expect(Range.stats().targets).to.equal(1)
			-- HE LEAVES AND THE SEAM REFUSES, so the idle arm is firing and failing every tick --
			-- and the animal is still there, held.
			fake.clearOne = function()
				return false
			end
			crowd.set({})
			advance(fake, clock, Range.CONFIG.IDLE_CLEAR_SECONDS + 1)
			expect(Range.stats().idleClears).to.equal(0)
			expect(Range.stats().targets).to.equal(1)
			-- NOW it leaves the runtime by its own hand, INSIDE the idle arm's own tick. The order
			-- matters and was measured: drop it before the threshold and the per-tick `statusOf`
			-- cleanup catches it on an ordinary tick, and the case is green against the old code.
			fake.animals = {}
			advance(fake, clock, 1)
			-- THE CLEAR DID NOT HAPPEN -- and the dead id was still noticed and let go.
			expect(Range.stats().idleClears).to.equal(0)
			expect(Range.stats().lostTargets).to.equal(1)
			expect(Range.stats().targets).to.equal(0)
			expect((Range.trialOf(2) :: any).targetId).to.equal(nil)
			-- ...and nothing is released at the station he left.
			expect(fake.spawns).to.equal(1)
			TestKit.note("range B7: a refused clear releases the dead id instead of holding it")
			Range.stop()
		end)

		it("clears only HIS animal when he picks a new species", function()
			-- 306b's round-2 note (viii): the respawn path was range-WIDE as well, so a pick at
			-- station 1 took station 6's animal.
			local clock, now = newClock()
			local fake = newFakeBoars()
			local crowd = newCrowd({ 1, 6 })
			local player = crowd.men[1]
			expect(select(1, startRange(fake, now, nil, nil, crowd.players))).to.equal(true)
			advance(fake, clock, 1)
			expect(fake.spawns).to.equal(2)
			local hers = (fake.at(6) :: any).id
			expect(Range.onRequest(player, { spot = 1, species = "reddeer" })).to.equal(true)
			expect(fake.clearOnes).to.equal(1)
			expect(fake.lastClear).to.equal("range pick")
			expect(Range.stats().wideClears).to.equal(0)
			-- STATION 6 STILL HAS THE SAME ANIMAL.
			expect(fake.at(6)).to.be.ok()
			expect((fake.at(6) :: any).id).to.equal(hers)
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

		it("offers the seven pace words with STAND, and one distance -- the lane that is built", function()
			expect(#RangeData.PACE_ORDER).to.equal(7)
			expect(RangeData.PACE_ORDER[1]).to.equal(RangeData.WORD.STAND)
			-- KAREN'S FOUR FIRST AND UNMOVED (design 6), then ISSF's two and `mixed`.
			expect(RangeData.PACE_ORDER[2]).to.equal(RangeData.WORD.WALK)
			expect(RangeData.PACE_ORDER[3]).to.equal(RangeData.WORD.TROT)
			expect(RangeData.PACE_ORDER[4]).to.equal(RangeData.WORD.RUN)
			expect(RangeData.PACE_ORDER[5]).to.equal(RangeData.WORD.SLOW)
			expect(RangeData.PACE_ORDER[6]).to.equal(RangeData.WORD.FAST)
			expect(RangeData.PACE_ORDER[7]).to.equal(RangeData.WORD.MIXED)
			local seen = {}
			for _, word in ipairs(RangeData.PACE_ORDER) do
				seen[word] = true
				expect(RangeData.paceAllowed(word)).to.equal(true)
			end
			expect(seen[RangeData.WORD.WALK]).to.equal(true)
			expect(seen[RangeData.WORD.TROT]).to.equal(true)
			expect(seen[RangeData.WORD.RUN]).to.equal(true)
			expect(seen[RangeData.WORD.SLOW]).to.equal(true)
			expect(seen[RangeData.WORD.FAST]).to.equal(true)
			expect(seen[RangeData.WORD.MIXED]).to.equal(true)
			-- A SECOND SPELLING IS A SILENT REFUSAL, so neither word is legal in any other form.
			expect(RangeData.paceAllowed("SLOW")).to.equal(false)
			expect(RangeData.paceAllowed("sprint")).to.equal(false)
			-- THE THREE LANES (design 5.1): 30 m, 35 m and 50 m, and the menu opens on 125 (Karen).
			expect(#RangeData.DISTANCES_STUDS).to.equal(3)
			expect(RangeData.DISTANCES_STUDS).to.equal(LAYOUT.DISTANCES_STUDS)
			local offered = {}
			for _, studs in ipairs(RangeData.DISTANCES_STUDS) do
				offered[studs] = true
				expect(RangeData.optionAllowed("distanceStuds", studs)).to.equal(true)
			end
			expect(offered[107]).to.equal(true)
			expect(offered[125]).to.equal(true)
			expect(offered[179]).to.equal(true)
			expect(offered[LAYOUT.DISTANCE_STUDS]).to.equal(true)
			expect(RangeData.distanceMax(LAYOUT)).to.equal(179)
			expect(RangeData.optionAllowed("distanceStuds", 200)).to.equal(false)
			expect(RangeData.optionAllowed("distanceStuds", 89)).to.equal(false)
		end)

		-- ---------------------------------------------------------- 5. THE PACES (design 6, 11.2)
		it("derives ISSF's two paces from the WINDOW and its TIME, and delegates Karen's four", function()
			local window = LAYOUT.WINDOW_STUDS
			-- THE ONLY NUMBERS TYPED: 5.0 s and 2.5 s. 36 / 5.0 = 7.20, 36 / 2.5 = 14.40 (306a
			-- must-fix (b): NOT the note's 7.14 / 14.29, which came from a 35.714-stud window).
			expect(RangeData.CROSSING_SECONDS.slow).to.equal(5.0)
			expect(RangeData.CROSSING_SECONDS.fast).to.equal(2.5)
			expect(RangeData.paceSpeedFor(RangeData.WORD.SLOW, LAYOUT, speedOf)).to.equal(window / 5.0)
			expect(RangeData.paceSpeedFor(RangeData.WORD.FAST, LAYOUT, speedOf)).to.equal(window / 2.5)
			expect(RangeData.paceSpeedFor(RangeData.WORD.SLOW, LAYOUT, speedOf)).to.equal(7.2)
			expect(RangeData.paceSpeedFor(RangeData.WORD.FAST, LAYOUT, speedOf)).to.equal(14.4)
			-- ...AND THE CROSSING IS EXACT BY CONSTRUCTION, which is why the row is a TIME.
			expect(RangeData.crossingSeconds(window, RangeData.paceSpeedFor("slow", LAYOUT, speedOf))).to.equal(5.0)
			expect(RangeData.crossingSeconds(window, RangeData.paceSpeedFor("fast", LAYOUT, speedOf))).to.equal(2.5)
			-- KAREN'S FOUR ARE THE BOAR'S OWN, through the injected function and never a literal.
			for _, word in ipairs({ "stand", "walk", "trot", "run" }) do
				expect(RangeData.paceSpeedFor(word, LAYOUT, speedOf)).to.equal(speedOf(word))
			end
			-- THE DERIVATION FOLLOWS THE WINDOW: a 72-stud window doubles both speeds and keeps
			-- both TIMES -- the case the arm exists for, and it reddens a hard-coded 7.2 / 14.4.
			local wide = layoutWith({ WINDOW_STUDS = 72 })
			expect(RangeData.paceSpeedFor("slow", wide, speedOf)).to.equal(14.4)
			expect(RangeData.crossingSeconds(wide.WINDOW_STUDS, RangeData.paceSpeedFor("fast", wide, speedOf))).to.equal(
				2.5
			)
			-- WITH NO ANIMAL OWNER INJECTED, Karen's four are 0 and ISSF's two still answer: the
			-- window and the clock are the range's own and need no boar.
			expect(RangeData.paceSpeedFor("trot", LAYOUT, nil)).to.equal(0)
			expect(RangeData.paceSpeedFor("slow", LAYOUT, nil)).to.equal(7.2)
			-- `crossingTargetSeconds` ANSWERS NIL FOR A WORD THAT IS NOT TIMED, and that nil is
			-- what routes Karen's four to the boar.
			expect(RangeData.crossingTargetSeconds("trot")).to.equal(nil)
			expect(RangeData.crossingTargetSeconds(1 :: any)).to.equal(nil)
			expect(RangeData.crossingTargetSeconds("slow")).to.equal(5.0)
			expect(RangeData.crossingTargetSeconds("fast")).to.equal(2.5)
			TestKit.note(
				string.format(
					"range: paceSpeedFor at a %d-stud window -- stand %.2f, walk %.2f, slow %.2f, trot %.2f, fast %.2f, run %.2f studs/s",
					window,
					RangeData.paceSpeedFor("stand", LAYOUT, speedOf),
					RangeData.paceSpeedFor("walk", LAYOUT, speedOf),
					RangeData.paceSpeedFor("slow", LAYOUT, speedOf),
					RangeData.paceSpeedFor("trot", LAYOUT, speedOf),
					RangeData.paceSpeedFor("fast", LAYOUT, speedOf),
					RangeData.paceSpeedFor("run", LAYOUT, speedOf)
				)
			)
		end)

		it("resolves `mixed` to one of the two timed paces and to nothing else", function()
			-- BOTH ARMS BY PARAMETER, because the shipped draw is `math.random`.
			expect(RangeData.mixedWord(0)).to.equal(RangeData.WORD.SLOW)
			expect(RangeData.mixedWord(0.49)).to.equal(RangeData.WORD.SLOW)
			expect(RangeData.mixedWord(0.5)).to.equal(RangeData.WORD.FAST)
			expect(RangeData.mixedWord(1)).to.equal(RangeData.WORD.FAST)
			-- ...AND THE DRAW IS ONLY EVER ONE OF THE TWO, over enough rolls to see both.
			local slow, fast = 0, 0
			for _ = 1, 400 do
				local speed = RangeData.paceSpeedFor(RangeData.WORD.MIXED, LAYOUT, speedOf)
				if speed == 7.2 then
					slow += 1
				elseif speed == 14.4 then
					fast += 1
				end
			end
			expect(slow + fast).to.equal(400)
			expect(slow > 0).to.equal(true)
			expect(fast > 0).to.equal(true)
			TestKit.note(string.format("range: 400 mixed draws -- %d slow, %d fast, 0 other", slow, fast))
		end)

		-- THE HONEST SENTENCE, MEASURED (306a must-fix (a)): `Body.gait` trots from `TROT_FROM` and
		-- runs from `RUN_FROM`, and BOTH new speeds land inside the boar's single TROT band. So
		-- `slow` and `fast` are ONE trot clip played at two rates, not two gaits -- no new gait,
		-- no new clip, no new config row. Whether that READS as two paces is Karen's look.
		it("lands both new paces inside ONE trot band of the boar's own gait rule", function()
			local model = Boar.CONFIG.MODEL or {}
			local trotFrom = model.TROT_FROM
			local runFrom = model.RUN_FROM
			expect(type(trotFrom)).to.equal("number")
			expect(type(runFrom)).to.equal("number")
			local slow = RangeData.paceSpeedFor("slow", LAYOUT, speedOf)
			local fast = RangeData.paceSpeedFor("fast", LAYOUT, speedOf)
			expect(slow >= trotFrom).to.equal(true)
			expect(slow < runFrom).to.equal(true)
			expect(fast >= trotFrom).to.equal(true)
			expect(fast < runFrom).to.equal(true)
			TestKit.note(
				string.format(
					"range: gait bands TROT_FROM %.2f RUN_FROM %.2f -- slow %.2f and fast %.2f are BOTH trot (one clip, two rates)",
					trotFrom,
					runFrom,
					slow,
					fast
				)
			)
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

		-- TASK 308 BUG 1. MEASURED in Karen's place on 46cbd787: on the mat, before any request,
		-- `boardPushes=0` and all six menu strips had zero children -- the first real E drew six
		-- labels and NO chips, because the only things that published were a request, a shot and a
		-- hit. `Range.look` is the publish a man who has picked nothing is owed.
		it("sends the lists to a man standing on the mat who has asked for nothing", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local sent = {}
			Range.setRemotes({
				RangeBoard = {
					FireClient = function(_self, player: any, payload: any)
						table.insert(sent, { player = player, payload = payload })
					end,
				},
			})
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 308)
			tick(clock, 1)

			expect(Range.look(man)).to.equal(true)
			expect(#sent).to.equal(1)
			local payload = sent[1].payload
			expect(sent[1].player).to.equal(man)
			expect(payload.record).to.be.ok()
			-- EVERY ROW THE MENU DRAWS, non-empty, with no pick made: this is what the six strips
			-- had none of.
			expect(#payload.lists.species > 0).to.equal(true)
			expect(#payload.lists.kinds > 0).to.equal(true)
			expect(#payload.lists.pace > 0).to.equal(true)
			expect(#payload.lists.weapons > 0).to.equal(true)
			expect(#payload.lists.distances > 0).to.equal(true)

			-- ...AND THE MAT IS STILL THE PERMISSION, pinned on `mayShoot` and not on `playerSpot`
			-- (round 1, note): a man standing EXACTLY where this one stands, but with no character
			-- for the server to measure, is refused and nothing goes out.
			local ghost = { UserId = 309, Name = "Man309" } :: any
			expect(Range.mayShoot(ghost)).to.equal(false)
			expect(Range.look(ghost)).to.equal(false)
			local away = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT) + Vector3.new(400, 0, 0), 311)
			expect(Range.look(away)).to.equal(false)
			expect(#sent).to.equal(1)
			Range.setRemotes(nil)
			Range.stop()
		end)

		-- REVIEW ROUND 1, FINDING 2: 306k made the board follow the FIRING POSITION, and the band
		-- between the two positions -- at the station, on neither, which is every step of the walk to
		-- his own ladder -- has no position word. Passing that nil on made `recordFor` see a changed
		-- position and hand back a BLANK record, so a walk toward the ladder wiped the board.
		it("keeps the tally when a man walks between the bench and his own ladder", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local mat = RangeData.matPosition(ANCHOR, 1, LAYOUT)
			local man = manOn(mat, 3061)
			tick(clock, 1)
			expect(Range.look(man)).to.equal(true)
			expect((Range.recordOf(man) :: any).position).to.equal(RangeData.POSITION.BENCH)
			-- ONE SHOT ON THE BOARD, so there is a tally to lose.
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			expect((Range.recordOf(man) :: any).shots).to.equal(1)
			-- ...AND THE WALK. 8 studs uprange of the mat is past its own 8-stud square and short of
			-- the deck's rect at `backStuds` -- the station, on neither position.
			local dir = RangeData.downrangeOf(DEV_ROW)
			local between = mat - Vector3.new(0, 0, dir * 8)
			local tops: { [number]: number } = {}
			for spot = 1, LAYOUT.SPOT_COUNT do
				tops[spot] = ANCHOR.Y + HighSeats.DIMS.DECK_RISE_STUDS
			end
			local atSpot, atWord = RangeData.spotAt(ANCHOR, between, LAYOUT, dir, tops)
			expect(atSpot).to.equal(1)
			expect(atWord).to.equal(nil)
			man.Character:PivotTo(CFrame.new(between))
			expect(Range.look(man)).to.equal(true)
			expect((Range.recordOf(man) :: any).shots).to.equal(1)
			expect((Range.recordOf(man) :: any).position).to.equal(RangeData.POSITION.BENCH)
			-- ...AND SINCE TASK 320 THERE IS NOWHERE ELSE TO ARRIVE. The other arm used to climb him
			-- onto the deck and assert a FRESH tally at `TREESTAND`; the runtime has no `deckTops`
			-- now, so the same point in the air is the bench's own station and the board stands.
			local deck = RangeData.standPosition(ANCHOR, 1, LAYOUT, dir)
			local wasDeck = deck + Vector3.new(0, HighSeats.DIMS.DECK_RISE_STUDS + LAYOUT.CLIMB.riseStuds, 0)
			expect((select(2, RangeData.spotAt(ANCHOR, wasDeck, LAYOUT, dir, Range.deckTops())))).to.equal(nil)
			man.Character:PivotTo(CFrame.new(wasDeck))
			expect(Range.look(man)).to.equal(true)
			expect((Range.recordOf(man) :: any).position).to.equal(RangeData.POSITION.BENCH)
			expect((Range.recordOf(man) :: any).shots).to.equal(1)
			TestKit.note("range 320: the walk keeps the board, and the air where the deck stood is no position")
			Range.stop()
		end)

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

		-- 306b's queued note (ii), and B4 is the step that owns it because B4 is where the crossing
		-- times are measured. The defect is IN THE DOOR: `onRequest` wrote a new lane onto a LIVE
		-- trial with no window reset, so the target was led DIAGONALLY across to the new lane and
		-- that TRANSIT was timed as a crossing. Driven through `Range.onRequest`, which is where a
		-- real menu confirm arrives (round 1, finding 2) -- `Range.setDistance` is the writer the
		-- door now calls, not the door.
		it("does not time the transit when a PICK changes the lane under a target inside the window", function()
			Range.stop()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 121)
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.TROT })).to.equal(true)
			-- Walk it until it is INSIDE the window, which is where the defect lives. The condition
			-- is the owner's OWN entry time, not a position this spec re-derives.
			local waited = 0
			local trial = Range.trialOf(1) :: any
			while trial.windowEnteredAt == nil and waited < 4 * RangeData.laneLength(LAYOUT) do
				advance(fake, clock, 0.1)
				waited += 0.1
				trial = Range.trialOf(1) :: any
			end
			expect(trial.windowEnteredAt).to.be.ok()
			expect(trial.distanceStuds).to.equal(LAYOUT.DISTANCE_STUDS)
			local before = trial.crossings
			-- THE PICK, through the one inbound door, exactly as the menu's CONFIRM sends it.
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, distanceStuds = 179 })).to.equal(true)
			trial = Range.trialOf(1) :: any
			expect(trial.distanceStuds).to.equal(179)
			expect(trial.windowEnteredAt).to.equal(nil)
			expect(trial.windowArmed).to.equal(false)
			-- The transit to the far lane crosses the old window's x span; nothing is timed for it,
			-- and the next REAL crossing is timed over the whole window.
			advance(fake, clock, 3 * RangeData.laneLength(LAYOUT) / speedOf("trot") + 2)
			trial = Range.trialOf(1) :: any
			expect(trial.crossings > before).to.equal(true)
			local measured = trial.crossingSecondsByPace[RangeData.WORD.TROT]
			local predicted = RangeData.crossingSeconds(LAYOUT.WINDOW_STUDS, speedOf("trot"))
			expect(math.abs(measured - predicted) / predicted <= Range.CONFIG.CROSSING_TOLERANCE).to.equal(true)
			TestKit.note(
				string.format(
					"range: lane 125 -> 179 picked mid-window, next crossing %.2f s against %.2f predicted",
					measured,
					predicted
				)
			)
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
			local ownLeads = fake.leadsAt(1)
			local last = ownLeads[#ownLeads]
			expect(last).to.be.ok()
			expect((last :: any).speed).to.equal(speedOf(RangeData.WORD.WALK))
			-- A STANDING TARGET NEEDS NO LEAD, and the board says which.
			expect((Range.recordOf(man) :: any).leadBallisticStuds).to.equal(0)
			Range.stop()
		end)

		-- TASK 308, ROUND 1 FINDING 2: `onShotResolved` ASKS FOR THE TENSE AND USES THE ANSWER.
		-- The gap must be measured against the animal where the SHOOTER DREW it, not where the
		-- server has it now. Delete the `at` branch in `targetPositionOf` and this case goes red:
		-- the two readings below are the same shot against two positions 10 studs apart.
		it("measures the miss gap against the animal where the shooter drew it", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 310)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.TROT })).to.equal(true)
			advance(fake, clock, 2)
			-- STATION 1'S OWN ANIMAL. `fake.only()` (this case's shape before the six stations
			-- landed) picks one of six by `pairs` order, so the reading below was a different
			-- station's animal in five runs out of six.
			local animal = fake.at(1)
			expect(animal).to.be.ok()
			local here = (animal :: any).position
			local trial = Range.trialOf(1) :: any
			local heading = if (trial.leg % 2) == 1 then 1 else -1

			-- A SHOT WHOSE SEGMENT ENDS EXACTLY WHERE THE SERVER HAS THE ANIMAL. Against the
			-- present position the gap is 0; against the drawn one, 10 studs back along the lane,
			-- it is the 10 studs the shooter actually missed by.
			local muzzle = here - Vector3.new(0, 0, 120)
			local asked: { number } = {}
			fake.pastOf = function(id: string, at: number): CFrame?
				table.insert(asked, at)
				expect(id).to.equal(trial.targetId)
				return CFrame.new(here - Vector3.new(10 * heading, 0, 0))
			end
			Range.onShotResolved({
				shooter = man,
				muzzle = muzzle,
				endPoint = here,
				resolvedAtServerTime = 1000,
			})
			expect(#asked).to.equal(1)
			local drawn = (Range.recordOf(man) :: any).lastGapStuds
			expect(drawn).to.be.near(10, 0.05)

			-- ...AND WITH NO SEAM TO ASK, the present position is the fallback, which is what the
			-- read was before this task: the same shot then reads 0.
			fake.pastOf = nil
			local kept = fake.cframeAt
			fake.cframeAt = nil
			Range.onShotResolved({
				shooter = man,
				muzzle = muzzle,
				endPoint = here,
				resolvedAtServerTime = 1000,
			})
			expect((Range.recordOf(man) :: any).lastGapStuds).to.be.near(0, 0.05)
			fake.cframeAt = kept
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

		-- ---------------------------------------------------------- TASK 304: THE HIT CARD'S SEAM
		--
		-- KAREN, 2026-10-28: *"hit card will be usefull"*. THIS half is the range's: one call to the
		-- card sender per hit it COUNTS, carrying the report it was given and nothing re-derived.
		-- `HitLog.sendCard` -- the other half, and the card itself -- is proved in
		-- `tests/server/hit_card.spec.luau`, which fails if that function sends nothing.
		it("sends the hit card once per counted hit, and never for a miss or a hit it does not count", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local sent = {}
			Range.setCardSender(function(report: any): boolean
				table.insert(sent, report)
				return true
			end)
			local man = manOn(RangeData.matPosition(ANCHOR, 1, LAYOUT), 140)
			tick(clock, 1)
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.TROT })).to.equal(true)
			advance(fake, clock, 1)

			-- A MISS: `ShotResolved` with no `HitReported`. No card -- the hunt's own rule.
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			expect(#sent).to.equal(0)
			expect(Range.stats().cards).to.equal(0)

			-- A HIT: ONE card, and it carries the REPORT ITSELF (identity), so nothing on the way to
			-- `HitLog` is rebuilt here.
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			local fired = { shooter = man, zone = "chest", nearest = 125, pellets = 2 }
			Range.onHitReported(fired)
			expect(#sent).to.equal(1)
			expect(sent[1]).to.equal(fired)
			expect(Range.stats().cards).to.equal(1)

			-- A SECOND REPORT OF THE SAME SHOT: the slot is consumed, the hit is not counted twice,
			-- and neither is the card.
			Range.onHitReported(fired)
			expect(#sent).to.equal(1)
			expect(Range.stats().cards).to.equal(1)

			-- A SENDER THAT REFUSES is counted and never silent (`HitLog.sendCard` answers false for
			-- a beater or a shot by nobody).
			Range.setCardSender(function(): boolean
				return false
			end)
			Range.onShotResolved({ shooter = man, endPoint = Vector3.new(ANCHOR.X, ANCHOR.Y, ANCHOR.Z) })
			Range.onHitReported({ shooter = man, zone = "chest", nearest = 125 })
			expect(Range.stats().cards).to.equal(1)
			expect(Range.stats().cardlessHits).to.equal(1)

			Range.setCardSender(nil)
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
			local animal = fake.at(1)
			expect(animal).to.be.ok()
			local target = (animal :: any).position
			local trial = Range.trialOf(1) :: any

			-- A SHOT 4 STUDS BEHIND A TARGET RUNNING EAST (an odd leg, +X) IS NEGATIVE, and the same
			-- 4 studs on a WEST leg is positive -- the gap is projected onto the target's travel, so
			-- the two directions read OPPOSITE signs for the same world-space error.
			-- A SHOT THAT STOPPED 4 STUDS BEHIND THE TARGET, fired from straight behind it so the
			-- whole segment lies along the lane and the closest approach IS its end.
			local muzzle = target - Vector3.new(60, 0, 0)
			local stop = target - Vector3.new(4, 0, 0)
			local east = Range.gapStuds(trial, muzzle, stop, target)
			expect(east).to.be.near(-4, 0.001)
			local west = table.clone(trial)
			west.leg = trial.leg + 1
			expect(Range.gapStuds(west, muzzle, stop, target)).to.be.near(4, 0.001)
			-- STAND HAS NO GAP: nothing is moving, so "behind" has no meaning.
			local standing = table.clone(trial)
			standing.pace = RangeData.WORD.STAND
			expect(Range.gapStuds(standing, muzzle, stop, target)).to.equal(nil)

			-- TASK 308 BUG 4. The board printed the same `19.3 m` at a WALK and at a RUN, in both
			-- directions: `endPoint` alone is where the bullet came to REST, so a slug that passed a
			-- hand in front of the nose and buried itself in the berm reported the berm. The gap is
			-- the SEGMENT's closest approach to the animal.
			--
			-- Down the lane (+Z) from 125 studs out, 1 stud of X off: the bullet passes 1 stud ahead
			-- of the animal and carries on past it, ending about 2 studs of X away. The old reading
			-- was that end point; the gap is the 1.0 it actually missed by.
			local shooter = target - Vector3.new(1, 0, 125)
			local far = shooter + (target + Vector3.new(1, 0, 0) - shooter).Unit * 185
			local near_ = Range.gapStuds(trial, shooter, far, target)
			expect(near_).to.be.near(1, 0.02)
			expect((far.X - target.X) > 1.4).to.equal(true)

			-- AND A SHOT THAT STOPPED IN THE ANIMAL READS ~0: the closest approach is the animal.
			expect(Range.gapStuds(trial, shooter, target, target)).to.be.near(0, 0.001)
			-- A MUZZLE IS REQUIRED: no line, no gap.
			expect(Range.gapStuds(trial, nil, stop, target)).to.equal(nil)
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

	-- THE SERVER'S OWN MEASUREMENT OF THE FIRING POSITION (step B3, design 7.3 and 9.4). Nothing a
	-- client sends carries one: these cases move the CHARACTER and read what the owner answers.
	describe("Range.positionOf and the board's distance", function()
		-- WAS "is TRUE on the deck, measures TREESTAND there": since task 320 there is no deck, so
		-- the owner can only ever answer BENCH, and the air where the deck stood is no position.
		it("has NO deck top at all, answers BENCH on the mat and nothing where the deck stood", function()
			Range.stop()
			local _, now = newClock()
			expect(startRange(newFakeBoars(), now)).to.equal(true)
			-- THE BUILD MEASURED NO DECK: the table the owner publishes is empty.
			local tops = Range.deckTops()
			expect(next(tops)).to.equal(nil)
			local deck = RangeData.standPosition(ANCHOR, 1, LAYOUT, 1)
			local wasDeck = ANCHOR.Y + 15
			local up = manAt(Vector3.new(deck.X, wasDeck, deck.Z))
			up.UserId = 306306
			local spot, position = Range.positionOf(up)
			expect(spot).to.equal(1)
			expect(position).to.equal(nil)

			-- ON THE MAT: the one firing position, its own distance, its own tally.
			local down = manAt(RangeData.matPosition(ANCHOR, 1, LAYOUT))
			down.UserId = 306306
			expect(Range.mayShoot(down)).to.equal(true)
			expect(select(2, Range.positionOf(down))).to.equal(RangeData.POSITION.BENCH)
			Range.onShotResolved({ shooter = down })
			local onBench = Range.recordOf(down)
			expect(onBench.position).to.equal(RangeData.POSITION.BENCH)
			expect(onBench.distanceStuds).to.equal(LAYOUT.DISTANCE_STUDS)
			expect(onBench.shots).to.equal(1)
			expect(onBench.spot).to.equal(1)

			-- UNDER WHERE THE DECK WAS: still at the station, so he keeps his gun, and still on
			-- NEITHER position -- the arm that was already true before the towers went.
			local below = manAt(Vector3.new(deck.X, ANCHOR.Y + 1, deck.Z))
			below.UserId = 306306
			expect(Range.mayShoot(below)).to.equal(true)
			local atSpot, noPosition = Range.positionOf(below)
			expect(atSpot).to.equal(1)
			expect(noPosition).to.equal(nil)
			Range.onShotResolved({ shooter = below })
			local under = Range.recordOf(below)
			expect(under.position).to.equal(nil)
			expect(under.distanceStuds).to.equal(LAYOUT.DISTANCE_STUDS)
			TestKit.note(
				string.format(
					"range 320 server: no deck tops, bench %d studs, nothing answers on the old deck point",
					onBench.distanceStuds
				)
			)
			Range.forget(up)
			Range.stop()
			expect(next(Range.deckTops())).to.equal(nil)
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
	-- --------------------------------- 8b. ISOLATION, THE SHOT (step B5, design 4.3 / 5.3 / 12 T13)
	--
	-- Six bodies share ONE corridor, `Cast.candidates` returns the eight nearest the muzzle and
	-- `Rewind.impact` takes the nearest rewound one -- so without an ignore list a body the shooter
	-- cannot see stops his bullet. Groups 6 and 7 of design 11.2.
	describe("the window, the one predicate both sides read", function()
		it("is centred on each station's own mat, the same span at all three distances", function()
			local width = LAYOUT.WINDOW_STUDS
			for spot = 1, LAYOUT.SPOT_COUNT do
				local mat = RangeData.matPosition(ANCHOR, spot, LAYOUT)
				local minX, maxX = RangeData.windowSpanFor(ANCHOR, spot, LAYOUT)
				-- THE IDENTITY, not a transcription: the opening is the mat's own X, and the lane
				-- only ever moves in Z, so the three distances cannot widen or shift it.
				expect(maxX - minX).to.be.near(width, 1e-4)
				expect((minX + maxX) / 2).to.be.near(mat.X, 1e-4)
				for _, distance in ipairs(RangeData.DISTANCES_STUDS) do
					local centre = RangeData.laneCentre(ANCHOR, LAYOUT, 1, spot, distance)
					expect(centre.X).to.be.near((minX + maxX) / 2, 1e-4)
				end
			end
			-- ...AND TWO NEIGHBOURS' WINDOWS OVERLAP, which is the whole reason the shot needs a
			-- list at all: 36 studs of opening at 24-stud spacing.
			local aMin, aMax = RangeData.windowSpanFor(ANCHOR, 1, LAYOUT)
			local bMin = RangeData.windowSpanFor(ANCHOR, 2, LAYOUT)
			expect(bMin < aMax).to.equal(true)
			expect(aMin < bMin).to.equal(true)
		end)

		it("counts both edges as inside, and a nil X as outside", function()
			local minX, maxX = RangeData.windowSpanFor(ANCHOR, 3, LAYOUT)
			expect(RangeData.inWindow(minX, maxX, (minX + maxX) / 2)).to.equal(true)
			-- BOTH EDGES, the repo's `<=` rule.
			expect(RangeData.inWindow(minX, maxX, minX)).to.equal(true)
			expect(RangeData.inWindow(minX, maxX, maxX)).to.equal(true)
			expect(RangeData.inWindow(minX, maxX, minX - 0.01)).to.equal(false)
			expect(RangeData.inWindow(minX, maxX, maxX + 0.01)).to.equal(false)
			-- NO ANSWER IS NOT "IN": no animal, or no history for the instant asked about, has to
			-- read as outside, because the shot then cannot see it either.
			expect(RangeData.inWindow(minX, maxX, nil)).to.equal(false)
			expect(RangeData.inWindow(minX, maxX, "12" :: any)).to.equal(false)
			expect(RangeData.inWindow(minX, maxX, 0 / 0)).to.equal(false)
		end)
	end)

	describe("Range.ignoredFor", function()
		local function manAtSpot(position: Vector3, id: number)
			local man = manAt(position) :: any
			man.UserId = id
			man.Name = "Man" .. tostring(id)
			return man
		end

		-- HIS OWN ANIMAL, PUT IN ITS OWN WINDOW. A released target sits at a lane END, which is
		-- outside the opening by construction (`windowArmed`'s own comment), so a case about the
		-- five that are not his has to move his into the middle first.
		local function centreOn(fake, spot: number)
			local animal = fake.at(spot)
			expect(animal).to.be.ok()
			local minX, maxX = RangeData.windowSpanFor(ANCHOR, spot, LAYOUT)
			animal.position = Vector3.new((minX + maxX) / 2, animal.position.Y, animal.position.Z)
			return animal
		end

		local function has(list, instance: Instance?): boolean
			for _, entry in ipairs(list) do
				if entry == instance then
					return true
				end
			end
			return false
		end

		it("hides the five that are not his, and his own only while it is out of its window", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			advance(fake, clock, 1)
			expect(Range.stats().targets).to.equal(LAYOUT.SPOT_COUNT)
			local man = manAtSpot(RangeData.matPosition(ANCHOR, 3, LAYOUT), 306)
			expect((Range.positionOf(man))).to.equal(3)

			-- HIS OWN IS IN THE OPENING: five roots, and not one of them is his.
			local mine = centreOn(fake, 3)
			local list = Range.ignoredFor(man)
			expect(#list).to.equal(LAYOUT.SPOT_COUNT - 1)
			expect(has(list, mine.root)).to.equal(false)
			for spot = 1, LAYOUT.SPOT_COUNT do
				if spot ~= 3 then
					expect(has(list, fake.at(spot).root)).to.equal(true)
				end
			end
			-- THE TRUNK AND NEVER A ZONE PART: the zone is welded UNDER the trunk, so one instance
			-- per animal is the whole exclusion and a list of zones would be the wrong shape.
			for _, entry in ipairs(list) do
				expect(entry:IsA("BasePart")).to.equal(true)
				expect(string.sub(entry.Name, 1, 10)).to.equal("FakeTrunk_")
			end
			expect(has(list, fake.at(1).zone)).to.equal(false)

			-- ...AND HIS OWN GOES IN THE LIST THE MOMENT IT LEAVES THE OPENING, which is what makes
			-- the animal hittable exactly where the mask draws it.
			local minX = RangeData.windowSpanFor(ANCHOR, 3, LAYOUT)
			mine.position = Vector3.new(minX - 2, mine.position.Y, mine.position.Z)
			local out = Range.ignoredFor(man)
			expect(#out).to.equal(LAYOUT.SPOT_COUNT)
			expect(has(out, mine.root)).to.equal(true)
			Range.stop()
		end)

		it("asks where his animal was at the instant the rewind tests, not where it is now", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			-- TWO CLOCKS, FAR APART (review round 1, finding 1). The history ring is stamped with
			-- `GetServerTimeNow()` and the owner steps on `os.clock()`; with the instant taken off
			-- the WRONG one the ring refuses every ask and the window is silently judged at the
			-- present position. 50 000 s apart, so no tolerance can hide the mix-up.
			local serverClock, serverTime = newClock()
			serverClock.t = 50000
			expect(startRange(fake, now, nil, serverTime)).to.equal(true)
			advance(fake, clock, 1)
			local man = manAtSpot(RangeData.matPosition(ANCHOR, 2, LAYOUT), 307)
			local mine = centreOn(fake, 2)
			local minX, maxX = RangeData.windowSpanFor(ANCHOR, 2, LAYOUT)

			-- NOW it is in the opening; 0.2 s AGO it was two studs west of the west edge. One shot,
			-- two answers, and the one the shot gets is the rewound one.
			local asked: { number } = {}
			fake.pastOf = function(_id: string, at: number): CFrame?
				table.insert(asked, at)
				return CFrame.new(Vector3.new(minX - 2, mine.position.Y, mine.position.Z))
			end
			expect(has(Range.ignoredFor(man), mine.root)).to.equal(false)
			expect(#asked).to.equal(0)
			expect(has(Range.ignoredFor(man, 0.2), mine.root)).to.equal(true)
			expect(#asked).to.equal(1)
			expect(asked[1]).to.be.near(serverClock.t - 0.2, 1e-6)
			-- ...AND NOT ON THE OWNER'S OWN CLOCK, which is the arm that shipped round 1.
			expect(math.abs(asked[1] - (clock.t - 0.2)) > 1).to.equal(true)

			-- ...and the other way round: out of the window now, inside it then, and the shot sees it.
			mine.position = Vector3.new(maxX + 5, mine.position.Y, mine.position.Z)
			fake.pastOf = function(): CFrame?
				return CFrame.new(Vector3.new((minX + maxX) / 2, mine.position.Y, mine.position.Z))
			end
			expect(has(Range.ignoredFor(man, 0.2), mine.root)).to.equal(false)
			fake.pastOf = nil
			Range.stop()
		end)

		it("hides nothing from a man who is not at a station, and nothing when it cannot ask", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			advance(fake, clock, 1)
			-- A SHOT IN THE WOOD IS UNTOUCHED, which is the whole of "unwired means today's game"
			-- on the range's side of the seam: no station, no list.
			local away = manAtSpot(RangeData.matPosition(ANCHOR, 1, LAYOUT) + Vector3.new(0, 0, -600), 310)
			expect((Range.positionOf(away))).to.equal(nil)
			expect(#Range.ignoredFor(away)).to.equal(0)
			local ghost = { UserId = 311, Name = "Man311" } :: any
			expect(#Range.ignoredFor(ghost)).to.equal(0)
			expect(#Range.ignoredFor(nil)).to.equal(0)

			-- A VIEW WITH NO READER, AND A READER THAT THROWS: empty, and no error out of the owner.
			local man = manAtSpot(RangeData.matPosition(ANCHOR, 1, LAYOUT), 312)
			local kept = fake.rootOf
			fake.rootOf = nil
			expect(#Range.ignoredFor(man)).to.equal(0)
			fake.rootOf = function(): Instance?
				error("no trunk for you")
			end
			expect(#Range.ignoredFor(man)).to.equal(0)
			fake.rootOf = kept

			-- ...AND A STOPPED RANGE ANSWERS NOTHING, so a world with no range never filters a shot.
			Range.stop()
			expect(#Range.ignoredFor(man)).to.equal(0)
		end)

		-- THE TWO FIELDS THE CLIENT'S MASK IS TOLD (step B6, design 4.4 / 9.4). They answer the same
		-- two facts `ignoredFor` answers for the shot and are read from the same two places, which is
		-- what makes the picture and the shot one question.
		it("maskFor names HIS trunk and HIS window, and never another station's", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			advance(fake, clock, 1)
			local man = manAtSpot(RangeData.matPosition(ANCHOR, 4, LAYOUT), 320)
			expect((Range.positionOf(man))).to.equal(4)
			-- HIS OWN ANIMAL, PUT IN ITS OWN WINDOW first: a released target sits at a lane END, so
			-- the shot's list would legitimately hold his own trunk until it is in the opening.
			local animal = centreOn(fake, 4)
			local mine, window = Range.maskFor(man)
			expect(mine).to.equal(animal.root)
			expect(mine).to.equal(fake.at(4).root)
			-- THE SHIPPED SPAN, not a number typed here: his station's, and not station 1's.
			local minX, maxX = RangeData.windowSpanFor(ANCHOR, 4, LAYOUT)
			expect((window :: any).minX).to.equal(minX)
			expect((window :: any).maxX).to.equal(maxX)
			local oneMinX = RangeData.windowSpanFor(ANCHOR, 1, LAYOUT)
			expect((window :: any).minX).never.to.equal(oneMinX)
			-- AND IT IS THE TRUNK THE SHOT'S LIST LEAVES OUT: one animal, one answer.
			expect(has(Range.ignoredFor(man), mine)).to.equal(false)

			-- A MAN OFF EVERY STATION IS TOLD NOTHING AT ALL, so his mask hides every target.
			local away = manAtSpot(RangeData.matPosition(ANCHOR, 1, LAYOUT) + Vector3.new(0, 0, -600), 321)
			local noTrunk, noWindow = Range.maskFor(away)
			expect(noTrunk).to.equal(nil)
			expect(noWindow).to.equal(nil)

			-- HIS WINDOW WITH NO ANIMAL RELEASED YET: the window still, and no trunk -- the other
			-- five are hidden and he has nothing of his own to show.
			local kept = fake.rootOf
			fake.rootOf = function(): Instance?
				return nil
			end
			local blind, stillWindow = Range.maskFor(man)
			expect(blind).to.equal(nil)
			expect((stillWindow :: any).minX).to.equal(minX)
			fake.rootOf = kept

			Range.stop()
			local stoppedTrunk, stoppedWindow = Range.maskFor(man)
			expect(stoppedTrunk).to.equal(nil)
			expect(stoppedWindow).to.equal(nil)
		end)

		-- THE REVIEWER, ROUND 1, FINDING 1: `record.mine` is an INSTANCE, and a re-release makes a
		-- new trunk while `boars.clear` destroys all six at once. Without a push on that edge the
		-- man kept a reference to a destroyed trunk and his own NEW animal stayed hidden until his
		-- next shot. ASSERTED ON THE WIRE, through a fake `RangeBoard`: reading `Range.recordOf`
		-- would measure `maskFor` again and pass with the push deleted.
		it("pushes the new trunk on every re-release, to every man at the range", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			local sent = {}
			Range.setRemotes({
				RangeBoard = {
					FireClient = function(_, _player, payload)
						table.insert(sent, payload)
					end,
				},
			})
			advance(fake, clock, 1)
			local man = manAtSpot(RangeData.matPosition(ANCHOR, 2, LAYOUT), 330)
			-- HE IS AT THE RANGE, SO HE IS TOLD -- and since task 321 (e) he is told whether or not
			-- he ever asks, so the payload under test is the LAST one and not the only one.
			expect(Range.onRequest(man, { spot = 2, go = true })).to.equal(true)
			expect(#sent >= 1).to.equal(true)
			local first = sent[#sent].record.mine
			expect(first).to.equal(fake.at(2).root)
			expect(sent[#sent].record.window.minX).to.equal((RangeData.windowSpanFor(ANCHOR, 2, LAYOUT)))

			-- EVERY TRUNK REPLACED AT ONCE, which is exactly what one man's carcass does to all six.
			fake.clear("spec re-release")
			advance(fake, clock, 1)
			-- HE WAS TOLD, without firing a shot: a payload arrived after the pick...
			expect(#sent > 1).to.equal(true)
			local last = sent[#sent].record.mine
			expect(last).to.equal(fake.at(2).root)
			-- ...AND IT NAMES A NEW INSTANCE. A case that passed with the old trunk would prove
			-- nothing about the push.
			expect(last).never.to.equal(first)

			-- ...AND THE FLUSH IS ONCE A TICK, not once per release: six trials re-release together,
			-- so an unbatched push would be six per man per edge.
			-- BOUNDED IN TICKS since task 321 (e): a man at a station is published to on every tick
			-- that dirties the mask, and a pass dirties one every few seconds -- so the bound is one
			-- push per man per TICK. Unbatched it would be one per RELEASE: six trials re-releasing
			-- together is 36 payloads in the one tick they do it in, which this still refuses.
			local before = #sent
			local ticks = 3
			fake.clear("spec re-release 2")
			advance(fake, clock, ticks / Range.CONFIG.STEP_HZ)
			expect(sent[#sent].record.mine).to.equal(fake.at(2).root)
			expect(#sent - before <= LAYOUT.SPOT_COUNT * ticks).to.equal(true)

			-- ...AND THE `targetId == nil` ARM OF `maskFor`, reached through the shipped door: a
			-- species pick clears his animal, and the push that follows names the window and no
			-- trunk (the Reviewer, round 1 -- the `rootOf` arm above does not reach this one).
			expect(Range.onRequest(man, { spot = 2, species = "reddeer" })).to.equal(true)
			local cleared = sent[#sent].record
			expect(cleared.mine).to.equal(nil)
			expect(cleared.window.minX).to.equal((RangeData.windowSpanFor(ANCHOR, 2, LAYOUT)))
			Range.setRemotes(nil)
		end)

		-- THE MUST-FIX OF 306b NOTE (i): the station is MEASURED, never claimed. The menu used to
		-- send `spot = 1` from all six, so a man at station 3 picked station 1's trial.
		it("onRequest lands on the station he is STANDING on, whatever the payload claims", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			advance(fake, clock, 1)
			local man = manAtSpot(RangeData.matPosition(ANCHOR, 5, LAYOUT), 322)
			expect((Range.positionOf(man))).to.equal(5)
			local before = (Range.trialOf(1) :: any).pace
			-- A `spot` THAT IS NOT A STATION IS STILL A BAD MESSAGE, measured station or not.
			local bad = Range.stats().badRequests
			expect(Range.onRequest(man, { spot = 0 :: any, go = true })).to.equal(false)
			expect(Range.stats().badRequests).to.equal(bad + 1)
			-- PAST `REQUEST_MIN_INTERVAL`, on the injected clock, so the second ask is not rate-limited.
			clock.t += 1
			expect(Range.onRequest(man, { spot = 1, pace = RangeData.WORD.STAND })).to.equal(true)
			-- STATION 5 TOOK IT, and station 1 -- the station the payload named -- did not move.
			expect((Range.trialOf(5) :: any).pace).to.equal(RangeData.WORD.STAND)
			expect((Range.trialOf(1) :: any).pace).to.equal(before)
			-- AND THE RECORD IS STATION 5'S, which is what the board then prints.
			expect((Range.recordOf(man) :: any).spot).to.equal(5)
		end)

		it("is counted, and costs under a tenth of a millisecond a call (T13)", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			expect(startRange(fake, now)).to.equal(true)
			advance(fake, clock, 1)
			local man = manAtSpot(RangeData.matPosition(ANCHOR, 4, LAYOUT), 313)
			centreOn(fake, 4)
			local before = Range.stats().ignoreCalls
			Range.ignoredFor(man)
			Range.ignoredFor(man, 0.1)
			expect(Range.stats().ignoreCalls).to.equal(before + 2)

			-- T13's BUDGET, measured over 200 calls so one scheduler hiccup cannot decide it. The
			-- shot asks twice -- once for the aim ray, once for the trigger -- so 0.1 ms a call is
			-- 0.2 ms of one frame with six animals on the lane.
			local runs = 200
			local started = os.clock()
			for _ = 1, runs do
				Range.ignoredFor(man, 0.1)
			end
			local perCall = (os.clock() - started) / runs
			TestKit.note(string.format("range B5: Range.ignoredFor %.4f ms/call over %d calls", perCall * 1000, runs))
			expect(perCall < 0.0001).to.equal(true)
			Range.stop()
		end)
	end)

	-- ------------------------------------------------- 9. KAREN'S PLACE: THE FOREST ROW (step B8)
	--
	-- The anchor is MEASURED, not chosen here. Step B6 sampled a 160 x 185 clearing for ONE station
	-- at (2650, -3216); step B3 then measured a THIRD way in which six stations plus a treestand
	-- overflow it, and design 2.1 moved the row into the lobby, where Karen asked for it. The B8
	-- census, in her own place on 2026-10-29, covers design 2.2's whole 256 x 239 footprint:
	-- 990 samples at 8 studs, 0 missed, 0 non-terrain hits, 0 BaseParts, ground spread 33.0 studs
	-- and 23.5 across the firing line alone -- which is the measurement the terrace exists for.
	-- The B6 case this replaced is archived at backups/task-306b8/ (rule 7).
	--   evidence: <runs-dir>/evidence/306b8/census.txt, profile.txt
	describe("the forest row: a range beside Karen's lodge (step B8)", function()
		-- THE CENSUSED RECTANGLE: design 2.2's own footprint, which is what was sampled. The range
		-- must fit inside what was measured, and now it does by construction rather than by luck.
		-- THE B8 CENSUS BOX, AS OFFSETS FROM THE ANCHOR AND NOT AS FOUR WORLD NUMBERS (task 315).
		-- It was typed as x 2532..2788, z -3238..-2998 about the old anchor (2600, -3030); what the
		-- census actually established is that six stations plus the treestand FIT a 256 x 239 box
		-- about the anchor, and that is a property of `LAYOUT`, not of a site -- so it survives a
		-- translation and these offsets are the same four numbers. The NEW site's own census is a
		-- live reading, not this: `[RangeBoot] footprint census` and the task report.
		local MEASURED = {
			minX = (FOREST_ROW :: any).x - 68,
			maxX = (FOREST_ROW :: any).x + 188,
			minZ = (FOREST_ROW :: any).z - 208,
			maxZ = (FOREST_ROW :: any).z + 32,
		}
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
		-- THE SHELF THE FOREST ROW NOW TAKES, which is NOT the ground under the range (step B8): the
		-- row's `shelfFrom` is the lobby's own anchor and the answer is snapped DOWN to the voxel
		-- grid, so the range terrace and the lodge yard are one terrace. Computed from the row here,
		-- never retyped -- moving `shelfFrom` must move this case, not break it.
		local FOREST_FROM = (FOREST_ROW :: any).shelfFrom
		local FOREST_SHELF = math.floor(slopedGround(FOREST_FROM.x, FOREST_FROM.z) / LAYOUT.FILL.GRID_STUDS)
			* LAYOUT.FILL.GRID_STUDS

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
					shelf = FOREST_SHELF,
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
					-- THE SEAT'S PIECES ARE `HighSeats`' OWN (step B3): they are laid from the five
					-- footprint readings, not by `onGround`, so a deck 12.5 studs up is right and
					-- `onGround`'s rule says nothing about it. What IS asserted here is the pair
					-- that touches the ground -- each foot SUNK by the seat's own embed at ITS OWN
					-- ground, which on the sloping arm fails if `Build` read the wrong five points.
					if part.Parent ~= b.folder then
						if part.Name:match("^Leg%d") ~= nil or part.Name == "Ladder" then
							local g = if case.sloped then slopedGround(part.Position.X, part.Position.Z) else case.shelf
							expect(math.abs(bottom - (g - HighSeats.DIMS.FOOT_EMBED_STUDS)) < 1e-2).to.equal(true)
						end
						continue
					end
					-- WHAT STEP B10 ADDS IS NOT LAID BY `onGround`, AND THAT IS WHY IT IS NAMED HERE
					-- RATHER THAN FALLING THROUGH: the hut's roof and the fence's rail stand ABOVE
					-- the ground by design, the hut's posts are grown from ONE reading at their own
					-- point up to the roof, the board hangs on the fascia, and the turf is a skin on
					-- the shelf. The `else` arm below is the BANK's nominal height, so an unnamed
					-- part would have been measured against a number that is not its own.
					if
						part.Name:match("^Roof%d") ~= nil
						or part.Name:match("^HutPost%d") ~= nil
						or part.Name:match("^Board%d") ~= nil
						or part.Name:sub(1, #RangeData.TURF_NAME) == RangeData.TURF_NAME
					then
						-- the one thing that IS asserted about them: the part's top is above the
						-- ground at its own point, so none of them is buried.
						local g = if case.sloped then slopedGround(part.Position.X, part.Position.Z) else case.shelf
						expect(top > g - 1e-2).to.equal(true)
						continue
					end
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
						-- `Post` is the prompt's own post (task 303), laid on the ground like the rest.
						local nominal = if part.Name == "Berm"
							then LAYOUT.BERM.height
							elseif part.Name:match("^Mat%d") then LAYOUT.MAT.size.Y
							elseif part.Name:match("^Post%d") then LAYOUT.POST.size.Y
							elseif part.Name:match("^Bench%d") then LAYOUT.BENCH.size.Y
							else LAYOUT.BANK.size.Y
						expect(math.abs(bottom - lo) < 1e-2).to.equal(true)
						expect(top >= hi + nominal - 1e-2).to.equal(true)
					end
				end
				-- THE LANE RUNS THE ROW'S OWN WAY. Downrange is a signed data field: the berm is the
				-- furthest thing downrange of the mat, on the row's own side of the firing line.
				local anchor = b.anchor
				local lane = RangeData.laneCentre(anchor, LAYOUT, case.dir)
				expect(lane.Z - anchor.Z).to.equal(case.dir * LAYOUT.DISTANCE_STUDS)
				-- THE BACKSTOP, WHEREVER THE ROW PUTS IT. On Karen's row it is EARTH and there is no
				-- part to find at all (step B8), so the same claim is read off the heap `Build` fills.
				-- BEHIND THE LONGEST LANE, not behind the one the menu opens on, on both arms.
				local bermPart = (b.folder :: any):FindFirstChild("Berm")
				local bermZ
				if RangeData.bermIsTerrain(case.row) then
					expect(bermPart).to.equal(nil)
					expect((b.folder :: any):FindFirstChild(RangeData.bankName(1))).to.equal(nil)
					bermZ = RangeData.bermBalls(anchor, LAYOUT, case.dir)[1].z
				else
					expect(bermPart).to.be.ok()
					expect((b.folder :: any):FindFirstChild(RangeData.bankName(1))).to.be.ok()
					bermZ = bermPart.Position.Z
				end
				expect((bermZ - anchor.Z) * case.dir > RangeData.distanceMax(LAYOUT)).to.equal(true)
				-- ...and NOTHING is built behind the shooter by more than the STATION'S OWN REACH --
				-- the deck plus the seat's feet, which is the number the station box, the footprint
				-- and her place's home area are all measured from (step B3). Before the treestand
				-- this bound was the mat's own 8 studs.
				for _, part in ipairs(parts) do
					-- The DEV plate IS the ground: it is sized to CARRY the range, so it reaches
					-- behind the firing line by its own margin and is not a thing built in it.
					if part.Name ~= "Plate" then
						local behind = (anchor.Z - part.Position.Z) * case.dir + part.Size.Z / 2
						expect(behind <= RangeData.standReach(LAYOUT)).to.equal(true)
					end
				end
				parent:Destroy()
			end
			-- THE GROUND WAS READ UNDER EVERY PART -- five samples each, fifteen parts, plus the one
			-- `shelfAt` takes at the anchor. It is NO LONGER inside `MEASURED`, and that is design
			-- 2.3's own finding rather than a regression: the clearing was sampled for ONE station,
			-- and six do not fit it (the case below measures the overflow). Step B8 moves the row and
			-- re-samples; until then the assertion is that every read is inside the range's OWN box.
			expect(#asked >= 5 * 15).to.equal(true)
			local box = RangeData.footprintFor(
				Vector3.new((FOREST_ROW :: any).x, 0, (FOREST_ROW :: any).z),
				LAYOUT,
				RangeData.downrangeOf(FOREST_ROW)
			)
			-- ...WITH ONE READ OUTSIDE IT BY DESIGN (step B8): the row's `shelfFrom` is the LOBBY's
			-- anchor, 250 studs north-east, because the range takes its level from the lodge's terrace
			-- and not from the ground under itself. It is named here rather than tolerated, so a
			-- second stray read outside the box still fails this case.
			local from = (FOREST_ROW :: any).shelfFrom
			local outside = 0
			for _, at in ipairs(asked) do
				if at.X < box.minX or at.X > box.maxX or at.Z < box.minZ or at.Z > box.maxZ then
					expect(at.X).to.equal(from.x)
					expect(at.Z).to.equal(from.z)
					outside += 1
				end
			end
			expect(outside).to.equal(1)
		end)

		it("FITS the rectangle the B8 census measured, where the B6 clearing could not", function()
			-- THE CASE THIS REPLACES asserted the OPPOSITE and was right to: at (2650, -3216) six
			-- stations overflowed the B6 clearing east, south and -- after the treestand -- uprange.
			-- It is archived at backups/task-306b8/range-spec-overflow-case-before-b8.luau (rule 7),
			-- and this is the same instrument pointed at the row that replaced it.
			local built, _, parent = buildWith(FOREST_ROW, slopedGround)
			local b = built :: any
			local names = {}
			for _, part in ipairs(partsOf(b.folder)) do
				table.insert(names, part.Name)
			end
			table.sort(names)
			local box = footprintOf(partsOf(b.folder))
			expect(box.minX >= MEASURED.minX).to.equal(true)
			expect(box.maxX <= MEASURED.maxX).to.equal(true)
			expect(box.minZ >= MEASURED.minZ).to.equal(true)
			expect(box.maxZ <= MEASURED.maxZ).to.equal(true)
			-- ...AND SO DOES THE GROUND IT WRITES, which the parts' box does not cover: the terrace,
			-- the berm's heap and the two banks are the things that would reach outside a censused
			-- rectangle unnoticed, because nothing in `Workspace.Range` records them.
			local anchor = Vector3.new((FOREST_ROW :: any).x, b.shelf, (FOREST_ROW :: any).z)
			for _, rect in ipairs(RangeData.cutRects(anchor, LAYOUT, -1, FOREST_ROW)) do
				expect(rect.minX >= MEASURED.minX).to.equal(true)
				expect(rect.maxX <= MEASURED.maxX).to.equal(true)
				expect(rect.minZ >= MEASURED.minZ).to.equal(true)
				expect(rect.maxZ <= MEASURED.maxZ).to.equal(true)
			end
			for _, one in ipairs(Range.Build.bermFills(anchor, b.shelf, LAYOUT, -1)) do
				expect(one.at.X - one.radius >= MEASURED.minX).to.equal(true)
				expect(one.at.X + one.radius <= MEASURED.maxX).to.equal(true)
				expect(one.at.Z - one.radius >= MEASURED.minZ).to.equal(true)
				expect(one.at.Z + one.radius <= MEASURED.maxZ).to.equal(true)
			end
			for leg = 1, 2 do
				for _, one in ipairs(RangeData.bankBalls(anchor, LAYOUT, leg, -1)) do
					expect(one.x - one.radius >= MEASURED.minX).to.equal(true)
					expect(one.x + one.radius <= MEASURED.maxX).to.equal(true)
					expect(one.z - one.radius >= MEASURED.minZ).to.equal(true)
					expect(one.z + one.radius <= MEASURED.maxZ).to.equal(true)
				end
			end
			TestKit.note(
				string.format(
					"range B8 site: parts x %.1f..%.1f z %.1f..%.1f inside the censused x %d..%d z %d..%d; shelf %.1f; parts %s",
					box.minX,
					box.maxX,
					box.minZ,
					box.maxZ,
					MEASURED.minX,
					MEASURED.maxX,
					MEASURED.minZ,
					MEASURED.maxZ,
					b.shelf,
					table.concat(names, ", ")
				)
			)
			parent:Destroy()
		end)

		-- ------------------------------------------------- 13. THE TERRACE AND THE EARTH (step B8)
		--
		-- `terrain` IS AN ARGUMENT (design 8.2), so these cases hand in a fake that RECORDS its calls
		-- and no spec can write the DEV place's ground -- `Lobby.Field`'s own discipline, borrowed
		-- with its reason. Both arms are entered by parameter: the DEV row writes nothing even when a
		-- terrain is handed to it, because `fill` is data and not a branch on a world's name.
		local function fakeTerrain()
			local rec = { fills = {}, balls = {}, replaces = {} }
			function rec:FillBlock(at: CFrame, size: Vector3, material: Enum.Material)
				table.insert(rec.fills, { at = at, size = size, material = material })
			end
			-- 306m: THE HILL IS `FillBall` NOW, recorded APART from the boxes -- so "every box the
			-- terrace writer makes is a terrace box" stays a claim this file can make.
			function rec:FillBall(at: Vector3, radius: number, material: Enum.Material)
				table.insert(rec.balls, { at = at, radius = radius, material = material })
			end
			function rec:ReplaceMaterial(region: Region3, resolution: number, from: Enum.Material, to: Enum.Material)
				table.insert(rec.replaces, { region = region, resolution = resolution, from = from, to = to })
			end
			return rec
		end

		local function buildOnTerrain(row, groundAt)
			local terrain = fakeTerrain()
			local parent = Instance.new("Folder")
			local built, why = Range.Build.build({
				parent = parent,
				row = row,
				layout = LAYOUT,
				groundAt = groundAt,
				terrain = terrain,
			})
			return built, why, parent, terrain
		end

		it("writes NOTHING without a terrain, and nothing at all on the DEV row that has one", function()
			-- (a) the shape every other case in this file runs in: no terrain, no write, and the
			-- counters say so rather than the absence of a crash saying it.
			local built, _, parent = buildWith(FOREST_ROW, slopedGround)
			expect((built :: any).terrainFills).to.equal(0)
			expect((built :: any).terrainReplaces).to.equal(0)
			parent:Destroy()
			-- (b) A TERRAIN IS HANDED IN AND THE ROW STILL DECIDES. This is the case that bites: with
			-- the `fillsTerrain(row)` guard dropped, the DEV arm writes a 232-stud terrace into the
			-- place the harness itself runs in.
			-- THE SHIPPED ROW, not the local fixture: `DEV_ROW` carries no `berm` and no `fill`, so it
			-- would only ever exercise the two readers' DEFAULTS (review round 1, note).
			local devBuilt, devWhy, devParent, devTerrain = buildOnTerrain(RangeData.anchorFor("map:v1"), nil)
			expect(devWhy).to.equal(nil)
			expect(#devTerrain.fills).to.equal(0)
			expect(#devTerrain.replaces).to.equal(0)
			expect((devBuilt :: any).terrainFills).to.equal(0)
			-- ...and the DEV berm and banks are still PARTS, which is the other half of the row.
			expect((devBuilt :: any).folder:FindFirstChild("Berm")).to.be.ok()
			expect((devBuilt :: any).folder:FindFirstChild(RangeData.bankName(1))).to.be.ok()
			expect((devBuilt :: any).folder:FindFirstChild(RangeData.bankName(2))).to.be.ok()
			devParent:Destroy()
		end)

		it("cuts one level terrace, AIR before GRASS, every face on the voxel grid", function()
			local built, why, parent, terrain = buildOnTerrain(FOREST_ROW, slopedGround)
			expect(why).to.equal(nil)
			local b = built :: any
			expect(b.shelf).to.equal(FOREST_SHELF)
			expect(#terrain.fills > 0).to.equal(true)
			-- 306m: the counter covers BOTH primitives -- the terrace's boxes and the heap's balls.
			expect(b.terrainFills).to.equal(#terrain.fills + #terrain.balls)
			expect(b.terrainReplaces).to.equal(#terrain.replaces)
			local grid = LAYOUT.FILL.GRID_STUDS
			-- AIR BEFORE GRASS, PER RECTANGLE: the terrace is cut in two pieces (the keep-out case
			-- below), so a global "last air before first grass" would be false for a correct build and
			-- true for one that cut the second piece after filling the first. Keyed on the piece's own
			-- Z centre, which is what tells the two apart.
			local airLast, grassFirst = {}, {}
			for index, call in ipairs(terrain.fills) do
				local key = string.format("%.3f", call.at.Position.Z)
				-- THE TERRACE ONLY. The berm and the banks are filled with the SAME material as the
				-- lane, so a key taken off every call would ask which air box preceded the berm --
				-- and there is none, because a heap is not a cut.
				local isTerrace = call.material == Enum.Material.Air
					or math.abs((call.at.Position.Y - call.size.Y / 2) - (b.shelf - LAYOUT.FILL.DEPTH_STUDS)) < 1e-6
				if not isTerrace then
					continue
				end
				if call.material == Enum.Material.Air then
					airLast[key] = index
				elseif grassFirst[key] == nil then
					grassFirst[key] = index
				end
				-- EVERY X AND Z FACE OF THE TERRACE ON THE 4-STUD GRID. A face inside a voxel writes
				-- that voxel only partly, and for the AIR box that is exactly the mound task 311
				-- photographed. THE HEAPS ARE DELIBERATELY NOT on it: a berm band is 2 studs tall over
				-- a 3-stud run, and the partial voxels that leaves are what make a batter read as a
				-- slope instead of a staircase. So the rule is asserted where it is a rule.
				local terrace = call.material == Enum.Material.Air
					or math.abs((call.at.Position.Y - call.size.Y / 2) - (b.shelf - LAYOUT.FILL.DEPTH_STUDS)) < 1e-6
				if not terrace then
					continue
				end
				for _, pair in ipairs({
					{ call.at.Position.X, call.size.X },
					{ call.at.Position.Z, call.size.Z },
				}) do
					local low = pair[1] - pair[2] / 2
					local high = pair[1] + pair[2] / 2
					expect(math.abs(low / grid - math.floor(low / grid + 0.5)) < 1e-6).to.equal(true)
					expect(math.abs(high / grid - math.floor(high / grid + 0.5)) < 1e-6).to.equal(true)
				end
			end
			-- AIR FIRST, AND THAT IS ORDER AND NOT TIDINESS (task 311): the air box reaches BELOW the
			-- shelf to the voxel boundary, so run after the grass it would eat the terrace it cut for.
			local pieces = 0
			for key, first in pairs(grassFirst) do
				expect(airLast[key]).to.be.ok()
				expect((airLast[key] :: number) < first).to.equal(true)
				pieces += 1
			end
			expect(pieces).to.equal(
				#RangeData.cutRects(
					Vector3.new((FOREST_ROW :: any).x, b.shelf, (FOREST_ROW :: any).z),
					LAYOUT,
					-1,
					FOREST_ROW
				)
			)
			-- THE AIR'S BOTTOM IS THE VOXEL BOUNDARY AT OR BELOW THE SHELF, and the grass is a solid
			-- bank DOWN to it -- never a floating slab (`Lobby.Field`'s two measured lessons).
			local function anchorOf(at)
				return Vector3.new((FOREST_ROW :: any).x, at.shelf, (FOREST_ROW :: any).z)
			end
			-- 306m: EVERY BOX IS A TERRACE BOX NOW. The heap is `FillBall` (recorded apart), so this
			-- loop may state the stronger claim: a `FillBlock` is the air cut or the grass bank under
			-- it, and nothing else writes a box at all.
			for _, call in ipairs(terrain.fills) do
				local bottom = call.at.Position.Y - call.size.Y / 2
				local top = call.at.Position.Y + call.size.Y / 2
				if call.material == Enum.Material.Air then
					expect(math.abs(bottom - math.floor(b.shelf / grid) * grid) < 1e-6).to.equal(true)
					expect(top >= b.shelf + LAYOUT.FILL.CLEAR_STUDS - 1e-6).to.equal(true)
				else
					expect(top <= b.shelf + 1e-6).to.equal(true)
					expect(math.abs(bottom - (b.shelf - LAYOUT.FILL.DEPTH_STUDS)) < 1e-6).to.equal(true)
				end
			end
			-- NOTHING FLOATS, AND FOR A CHAIN OF BALLS THAT IS NOT "its bottom is the shelf" (rule E).
			-- Per column, sorted by rise: the LOWEST ball is buried (its bottom at or under the
			-- terrace) and every ball above it OVERLAPS the one below -- centre distance strictly
			-- under the two radii -- so the heap is one solid body standing from the ground and no
			-- clump or cap hangs in the air.
			local chains = {}
			for _, one in ipairs(RangeData.bermBalls(anchorOf(b), LAYOUT, -1)) do
				local key = string.format("%.3f", one.x)
				chains[key] = chains[key] or {}
				table.insert(chains[key], one)
			end
			local counted = 0
			for _, chain in pairs(chains) do
				table.sort(chain, function(left, right)
					return left.rise < right.rise
				end)
				expect(chain[1].rise - chain[1].radius <= 1e-6).to.equal(true)
				for index = 2, #chain do
					local lower, upper = chain[index - 1], chain[index]
					local gap =
						math.sqrt((upper.rise - lower.rise) ^ 2 + (upper.z - lower.z) ^ 2 + (upper.x - lower.x) ^ 2)
					expect(gap < lower.radius + upper.radius).to.equal(true)
				end
				counted += 1
			end
			expect(counted).to.equal(#RangeData.bermColumns(anchorOf(b), LAYOUT, -1))
			-- ...AND THE SCRUB IS EMBEDDED IN THE CREST IT STANDS ON, by the same rule.
			for _, clump in ipairs(RangeData.bermScrubPoints(anchorOf(b), LAYOUT, -1)) do
				expect(clump.rise - clump.radius < clump.top).to.equal(true)
				expect(clump.rise + clump.radius > clump.top).to.equal(true)
			end
			-- EVERY BALL THE OWNER PREDICTS WAS FILLED, AND NOTHING ELSE WAS -- keyed on what a ball
			-- IS, where its centre stands and how wide it is. THE COUNT IS ANCHORED OUTSIDE the
			-- producer (306l review round 1, finding 2): taken only from `bermFills`, this block
			-- passed with the producer returning nothing at all.
			local wanted = {}
			local function ballKey(x, y, z, radius)
				return string.format("%.3f|%.3f|%.3f|%.3f", x, y, z, radius)
			end
			for _, one in ipairs(Range.Build.bermFills(anchorOf(b), b.shelf, LAYOUT, -1)) do
				wanted[ballKey(one.at.X, one.at.Y, one.at.Z, one.radius)] = true
			end
			for leg = 1, 2 do
				for _, one in ipairs(RangeData.bankBalls(anchorOf(b), LAYOUT, leg, -1)) do
					wanted[ballKey(one.x, b.shelf + one.rise, one.z, one.radius)] = true
				end
			end
			local want = 0
			for _ in pairs(wanted) do
				want += 1
			end
			for _, call in ipairs(terrain.balls) do
				expect(wanted[ballKey(call.at.X, call.at.Y, call.at.Z, call.radius)]).to.equal(true)
			end
			expect(#terrain.balls).to.equal(want)
			expect(want > #RangeData.bermColumns(anchorOf(b), LAYOUT, -1)).to.equal(true)
			parent:Destroy()
		end)

		-- THE RANGE'S HALF OF THE SIGHTLINE (task 315, design 7.1). PURE, derived from the anchor,
		-- so it follows the row with no code change -- and the containment below is load-bearing
		-- rather than decorative: a narrowed hut roof must make it FAIL.
		it("hands out a sightline that contains every built part of every station", function()
			local row = FOREST_ROW :: any
			local anchor = Vector3.new(row.x, FOREST_SHELF, row.z)
			local lane = RangeData.sightlineFrom(anchor, LAYOUT, -1)
			local box = RangeData.footprintFor(anchor, LAYOUT, -1)
			expect(lane.fromZ).to.equal(box.maxZ)
			-- ...AND THE OTHER SIGN OF `downrange` TAKES THE OTHER EDGE, by parameter.
			local up = RangeData.sightlineFrom(anchor, LAYOUT, 1)
			expect(up.fromZ).to.equal(RangeData.footprintFor(anchor, LAYOUT, 1).minZ)
			expect(up.minX).to.equal(lane.minX)
			local function spans(laneRow, layout): boolean
				for spot = 1, layout.SPOT_COUNT do
					local parts = {
						RangeData.matPosition(anchor, spot, layout),
						RangeData.benchPosition(anchor, spot, layout, -1),
						RangeData.standPosition(anchor, spot, layout, -1),
						RangeData.hutRoofPosition(anchor, spot, layout, -1),
					}
					for _, post in ipairs(RangeData.hutPostPositions(anchor, spot, layout, -1)) do
						table.insert(parts, Vector3.new(post.x, 0, post.z))
					end
					for _, at in ipairs(parts) do
						if at.X < laneRow.minX or at.X > laneRow.maxX then
							return false
						end
					end
				end
				return true
			end
			expect(spans(lane, LAYOUT)).to.equal(true)
			-- THE BITE: hand out a sightline computed from a NARROWER hut and hold the REAL hut's
			-- parts to it -- the posts of stations 1 and 6 then fall outside. Narrowing both halves
			-- together proves nothing, which is the mistake the first draft of this case made: the
			-- claim is that the bound is at least half a hut roof, so only one half may move.
			local narrow = table.clone(LAYOUT)
			local hut = table.clone(LAYOUT.HUT)
			hut.roofSize = Vector3.new(1, LAYOUT.HUT.roofSize.Y, LAYOUT.HUT.roofSize.Z)
			narrow.HUT = hut
			expect(spans(RangeData.sightlineFrom(anchor, narrow, -1), LAYOUT)).to.equal(false)
		end)

		it("stops the terrace at the lobby field's own edge, read off Lobby and not retyped", function()
			-- THE SEAM, CHECKED RATHER THAN PROMISED. `keepOut` is two numbers on the row; this case
			-- asserts they ARE the lobby field's west and south edges, computed from `Lobby.CONFIG`,
			-- so moving the lobby breaks this case instead of silently cutting the lodge's ground.
			local keepOut = (FOREST_ROW :: any).keepOut
			local half = LOBBY_CFG.FIELD.SPAN_STUDS / 2
			expect(keepOut.x).to.equal(LOBBY_ANCHOR.x - half)
			expect(keepOut.z).to.equal(LOBBY_ANCHOR.z - half)
			local anchor = Vector3.new((FOREST_ROW :: any).x, FOREST_SHELF, (FOREST_ROW :: any).z)
			local rects = RangeData.cutRects(anchor, LAYOUT, -1, FOREST_ROW)
			-- TASK 315: THE TWO TERRACES NOW MEET FLUSH ON ONE VOXEL PLANE. With the range straight
			-- out of the shop door its uprange edge snaps to -3060, which IS the lobby field's own
			-- south edge -- so the split has nothing to split and `cutRects` returns ONE rectangle.
			-- That is a property to assert, not an accident: the two cuts must share a plane with
			-- zero overlap and zero gap, or there is a step or a cliff across Karen's walk.
			expect(#rects).to.equal(1)
			expect(rects[1].maxZ).to.equal(LOBBY_ANCHOR.z - half)
			local overlap = 0
			for _, rect in ipairs(rects) do
				local dx = math.min(rect.maxX, LOBBY_ANCHOR.x + half) - math.max(rect.minX, LOBBY_ANCHOR.x - half)
				local dz = math.min(rect.maxZ, LOBBY_ANCHOR.z + half) - math.max(rect.minZ, LOBBY_ANCHOR.z - half)
				if dx > 0 and dz > 0 then
					overlap += dx * dz
				end
			end
			expect(overlap).to.equal(0)
			-- THE SPLIT ARM IS DRIVEN BY PARAMETER, because the live row no longer enters it (design
			-- 4.2). Without this case the two-rectangle arm goes dark and a later anchor move north
			-- would inherit an untested seam.
			local northRow = table.clone(FOREST_ROW :: any)
			northRow.z = LOBBY_ANCHOR.z - half + 40
			local northAnchor = Vector3.new(northRow.x, FOREST_SHELF, northRow.z)
			local split = RangeData.cutRects(northAnchor, LAYOUT, -1, northRow)
			expect(#split).to.equal(2)
			local splitOverlap = 0
			for _, rect in ipairs(split) do
				local dx = math.min(rect.maxX, LOBBY_ANCHOR.x + half) - math.max(rect.minX, LOBBY_ANCHOR.x - half)
				local dz = math.min(rect.maxZ, LOBBY_ANCHOR.z + half) - math.max(rect.minZ, LOBBY_ANCHOR.z - half)
				if dx > 0 and dz > 0 then
					splitOverlap += dx * dz
				end
			end
			expect(splitOverlap).to.equal(0)
			-- ...AND THAT SAME NORTHERN ROW WITHOUT `keepOut` GETS ONE WIDER RECTANGLE: the split is
			-- data, not a branch on a world's name.
			local plain = table.clone(northRow)
			plain.keepOut = nil
			local one = RangeData.cutRects(northAnchor, LAYOUT, -1, plain)
			expect(#one).to.equal(1)
			expect(one[1].maxX > split[2].maxX).to.equal(true)
			-- THE TERRACE STILL REACHES EVERYTHING BUILT ON IT, which is what the keep-out could break.
			local built, _, parent = buildWith(FOREST_ROW, slopedGround)
			for _, part in ipairs(partsOf((built :: any).folder)) do
				local covered = false
				for _, rect in ipairs(rects) do
					if
						part.Position.X - part.Size.X / 2 >= rect.minX - 1e-6
						and part.Position.X + part.Size.X / 2 <= rect.maxX + 1e-6
						and part.Position.Z - part.Size.Z / 2 >= rect.minZ - 1e-6
						and part.Position.Z + part.Size.Z / 2 <= rect.maxZ + 1e-6
					then
						covered = true
					end
				end
				if not covered then
					error(
						string.format(
							"%s at x %.2f..%.2f z %.2f..%.2f stands on neither terrace rectangle",
							part.Name,
							part.Position.X - part.Size.X / 2,
							part.Position.X + part.Size.X / 2,
							part.Position.Z - part.Size.Z / 2,
							part.Position.Z + part.Size.Z / 2
						)
					)
				end
				expect(covered).to.equal(true)
			end
			parent:Destroy()
		end)

		-- 306l item 2 AND 306m items 1, 2 AND 4: AN EARTH HILL, NOT A WALL AND NOT A BATTLEMENT.
		-- 306l built the heap out of BOXES -- one grassed core and four bands per 12-stud column --
		-- and from the bench that read as a row of square crenellations with vertical sides, with a
		-- square block for each side bank (306l-R2-AFTER-marker-crop.png, 306l-R2-AFTER-deck2-crop.png;
		-- Karen: "a mountain not high but like in real life ... earth formed mountain").
		-- 306m keeps every number 306l measured -- the toe, the terrace edge, the crest heights -- and
		-- changes only the SHAPE: `Terrain:FillBall`, which writes partial voxel occupancy and so draws
		-- curved, where `FillBlock` draws a vertical face and a flat top.
		it("fills a rolling earth hill out of balls: no box, no step in the skyline, no vertical face", function()
			local anchor = Vector3.new((FOREST_ROW :: any).x, FOREST_SHELF, (FOREST_ROW :: any).z)
			local balls = RangeData.bermBalls(anchor, LAYOUT, -1)
			local columns = RangeData.bermColumns(anchor, LAYOUT, -1)
			local scrub = RangeData.bermScrubPoints(anchor, LAYOUT, -1)
			expect(#columns > 40).to.equal(true)
			expect(#balls > #columns).to.equal(true)
			expect(#scrub).to.equal(LAYOUT.BERM.scrubCount)
			-- THE UNION'S OWN SURFACE, which is the only thing a picture can show: the highest point any
			-- ball reaches over (x, z). Every claim below is asserted against THIS and not against the
			-- dials that made it.
			local function surfaceAt(x: number, z: number): number
				local best = 0
				for _, one in ipairs(balls) do
					local inside = one.radius * one.radius - (x - one.x) ^ 2 - (z - one.z) ^ 2
					if inside > 0 then
						best = math.max(best, one.rise + math.sqrt(inside))
					end
				end
				return best
			end
			-- this row runs with `dir` -1, so UPRANGE (towards the shooter) is +Z and the toe is the
			-- heap's +Z-most earth.
			local apex = RangeData.bermCrestFaceZ(anchor, LAYOUT, -1)
			local toe = RangeData.bermToeZ(anchor, LAYOUT, -1)
			local back = RangeData.bermPosition(anchor, LAYOUT, -1).Z - LAYOUT.BERM.depth / 2
			local west, east = RangeData.bermSpanFor(anchor, LAYOUT)
			-- (1) NOTHING THE HILL IS MADE OF IS A BOX, and the writer's own calls say so: every ball the
			-- owner predicts was filled, and every `FillBlock` left is a terrace rectangle -- air above
			-- the shelf, or the grass bank whose top IS the shelf.
			local built, _, parent, terrain = buildOnTerrain(FOREST_ROW, slopedGround)
			local shelf = (built :: any).shelf
			expect(#terrain.balls).to.equal(#balls + #scrub + 2 * #RangeData.bankBalls(anchor, LAYOUT, 1, -1))
			for _, call in ipairs(terrain.fills) do
				local top = call.at.Position.Y + call.size.Y / 2
				expect(call.material == Enum.Material.Air or top <= shelf + 1e-6).to.equal(true)
			end
			-- (2) THE SKYLINE ROLLS AND NEVER STEPS. Sampled along the crest at one column's width, no
			-- two neighbours differ by more than `crestStepMaxStuds`, and inside the shoulders -- the
			-- stretch a man down the lane actually sees -- by more than `crestStepInnerMaxStuds`. A 306l
			-- column was a 12-stud BOX with a vertical side, so its step was its whole crest difference,
			-- up to 3 studs, at a dead-regular 12-stud period: the crenellation itself.
			local lo, hi, step, inner = math.huge, -math.huge, 0, 0
			local previous, previousInner = nil, nil
			for _, column in ipairs(columns) do
				local height = surfaceAt(column.x, apex)
				-- the cap's top IS the column's crest, so the skyline is the crest line itself and not a
				-- sample of something lower.
				expect(math.abs(height - column.top) < 1e-6).to.equal(true)
				lo, hi = math.min(lo, height), math.max(hi, height)
				if previous ~= nil then
					step = math.max(step, math.abs(height - previous))
				end
				previous = height
				if
					math.min(column.x - west, east - column.x)
					> LAYOUT.BERM.shoulderStuds + LAYOUT.BERM.crestStepStuds
				then
					if previousInner ~= nil then
						inner = math.max(inner, math.abs(height - previousInner))
					end
					previousInner = height
				else
					previousInner = nil
				end
			end
			expect(step <= LAYOUT.BERM.crestStepMaxStuds).to.equal(true)
			-- ...AND BETWEEN TWO CAPS, which is the one place a comb can appear and the place the
			-- column sweep above cannot see (round 1, note). Two caps `crestStepStuds` apart dip
			-- `capRadius - sqrt(capRadius^2 - (crestStepStuds/2)^2)` = 0.76 studs below the lower of
			-- them; widen the columns past `2 * capRadius` and the caps stop touching and this is a
			-- row of cusps instead.
			local dip = LAYOUT.BERM.capRadius
				- math.sqrt(math.max(0, LAYOUT.BERM.capRadius ^ 2 - (LAYOUT.BERM.crestStepStuds / 2) ^ 2))
			local deepest = 0
			for index = 2, #columns do
				local left, right = columns[index - 1], columns[index]
				local middle = surfaceAt((left.x + right.x) / 2, apex)
				deepest = math.max(deepest, math.min(left.top, right.top) - middle)
			end
			expect(deepest <= dip + 0.1).to.equal(true)
			expect(inner > 0).to.equal(true)
			expect(inner <= LAYOUT.BERM.crestStepInnerMaxStuds).to.equal(true)
			-- THE CREST IS STILL NOT ONE LINE, and the spread is studs and not noise.
			expect(hi - lo >= 3).to.equal(true)
			expect(hi <= LAYOUT.BERM.height + 1e-6).to.equal(true)
			-- (3) NO VERTICAL FACE AND NO FLAT TOP: at every column the cross-section RISES all the way
			-- from the toe to the apex and FALLS all the way to the back, sampled every stud. A box fails
			-- this at its own face (0 to its full height in one sample); so does the pedestal the first
			-- 306m draft simulated, which jumped 8.7 studs in one stud at 2.8 studs uprange of the apex.
			-- The steepest 4-stud slope is MEASURED here and held to `faceMaxDegrees`, because the angle
			-- is not free: this envelope is `slopeRun + depth` = 16 studs deep and `height` 21 tall, so
			-- the shallowest possible steepest face is atan(21/8) = 69.1 degrees, and a 50-degree face
			-- would need 17.6 studs of run -- a toe at 174, which is 4.6 studs INSIDE the 179 lane.
			-- THE ONE-STUD RISE IS THE BOUND THAT DOES THE REJECTING (round 1, finding 1). A 4-stud
			-- chord averages a jump with the slope under it, so it cannot see either shape this task
			-- exists to kill: the pedestal's 8.7-stud jump reads about 75 deg over 4 studs, inside
			-- `faceMaxDegrees`, and a box's face is a RISE, which the monotone pair alone allows.
			-- Both fail `riseMaxStuds` -- 8.7 and the whole crest -- and the shipped frustum's worst
			-- is 5.13. The 4-stud slope is kept beside it as the reported angle.
			local sharpest, where, steepest = 0, 0, 0
			for _, column in ipairs(columns) do
				local profile = {}
				for stud = 0, LAYOUT.BERM.slopeRun + LAYOUT.BERM.depth do
					-- from the toe, walking downrange: uprange is +Z on this row, so downrange is -1 a stud.
					profile[#profile + 1] = surfaceAt(column.x, toe - stud)
				end
				for index = 2, #profile do
					local climbed = profile[index] - profile[index - 1]
					if index - 1 <= LAYOUT.BERM.slopeRun then
						expect(climbed >= -1e-6).to.equal(true)
					else
						expect(climbed <= 1e-6).to.equal(true)
					end
					steepest = math.max(steepest, math.abs(climbed))
				end
				-- THE APEX IS A RIDGE AND NOT A PLATEAU: strictly above BOTH its neighbours, so a
				-- flat top of any width fails here -- `climbed` of exactly 0 satisfies the monotone
				-- pair on both sides and would otherwise pass (round 1, finding 1).
				local crest = LAYOUT.BERM.slopeRun + 1
				expect(profile[crest] - profile[crest - 1] > 1e-6).to.equal(true)
				expect(profile[crest] - profile[crest + 1] > 1e-6).to.equal(true)
				-- ...and the crest is the column's own top.
				expect(math.abs(profile[crest] - column.top) < 1e-6).to.equal(true)
				for index = 1, #profile - 4 do
					local slope = math.abs(profile[index + 4] - profile[index]) / 4
					if slope > sharpest then
						sharpest, where = slope, column.x
					end
				end
			end
			expect(steepest <= LAYOUT.BERM.riseMaxStuds).to.equal(true)
			local degrees = math.deg(math.atan(sharpest))
			expect(degrees <= LAYOUT.BERM.faceMaxDegrees).to.equal(true)
			-- NOT a target, a MEASUREMENT: the envelope cannot give 50 degrees, and a day when it can
			-- should break this line rather than pass quietly.
			expect(degrees > 50).to.equal(true)
			-- (4) THE HEAP STAYS INSIDE 306l's ENVELOPE -- toe, back and span -- asserted against every
			-- ball, cap and clump rather than against the dials that place them.
			-- IN Z IT IS EXACT -- that is 306l item 1, the far lane's own clearance and the road's.
			-- IN X THE END COLUMNS' EARTH ROLLS OUT BY THE BASE HALF-DEPTH, because a ball is round:
			-- `bermWidthFor` is derived to COVER the corridor and both banks, and a rounded end dying
			-- away `(slopeRun + depth) / 2` studs further out covers more, not less. The hard bound
			-- in X is the censused rectangle of her own lot, which the terrace case asserts.
			local roll = (LAYOUT.BERM.slopeRun + LAYOUT.BERM.depth) / 2
			for _, group in ipairs({ balls, scrub }) do
				for _, one in ipairs(group) do
					expect(one.z - one.radius >= math.min(toe, back) - 1e-6).to.equal(true)
					expect(one.z + one.radius <= math.max(toe, back) + 1e-6).to.equal(true)
					expect(one.x - one.radius >= west - roll - 1e-6).to.equal(true)
					expect(one.x + one.radius <= east + roll + 1e-6).to.equal(true)
				end
			end
			-- ...and the crest itself -- every cap -- stays inside the derived width.
			for _, column in ipairs(columns) do
				expect(column.x >= west - 1e-6).to.equal(true)
				expect(column.x <= east + 1e-6).to.equal(true)
			end
			-- (5) ...AND THE RIPPLE MAY NOT UNDO THE BACKSTOP (306l review round 1, finding 1). A man on
			-- the deck fires from `DECK_RISE_STUDS + AIM_RISE_STUDS` over the shelf, so every column the
			-- firing fan reaches at the crest face stands at least that tall.
			-- TASK 313: the bound is now the BACKSTOP INTERVAL -- the berm's span less its two
			-- tapered shoulders -- because that is the earth `RangeData.sightSpanFor` leans on and
			-- the only earth that reaches `height`. The shoulders are margin and are excluded by
			-- construction, not by a tolerance.
			local deckEye = HighSeats.DIMS.DECK_RISE_STUDS + HighSeats.AIM_RISE_STUDS
			local fanMin, fanMax = RangeData.backstopSpanFor(anchor, LAYOUT)
			local inFan = 0
			for _, column in ipairs(columns) do
				-- FULLY INSIDE, not merely overlapping: a column straddling the backstop's edge is
				-- already on the shoulder's taper, and the shoulder is margin (design 3.1).
				if column.x - column.width / 2 >= fanMin - 1e-6 and column.x + column.width / 2 <= fanMax + 1e-6 then
					inFan += 1
					expect(surfaceAt(column.x, apex) >= deckEye).to.equal(true)
				end
			end
			-- THE FAN IS COVERED, which is the claim that matters: the columns standing at least
			-- `deckEye` tall span the whole firing fan. The shoulders fall 32 studs outside each end
			-- of it, which is why a count of columns is not the bound.
			expect(inFan * LAYOUT.BERM.crestStepStuds >= (fanMax - fanMin) - 3 * LAYOUT.BERM.crestStepStuds).to.equal(
				true
			)
			expect(deckEye >= 17.5).to.equal(true)
			-- (6) THE TOE IS NOT ONE LINE EITHER, and never reaches past the designed run. The BATTER's
			-- own run is what is left of it after the crest's half width, so it has to stay positive.
			local runLo, runHi = math.huge, -math.huge
			for _, column in ipairs(columns) do
				expect(column.run <= LAYOUT.BERM.slopeRun + 1e-6).to.equal(true)
				expect(column.run - LAYOUT.BERM.capRadius > 0).to.equal(true)
				runLo, runHi = math.min(runLo, column.run), math.max(runHi, column.run)
			end
			expect(runHi - runLo >= 1).to.equal(true)
			-- (7) THE SURFACES: every ball of the heap is written BARE EARTH and the crest and back are
			-- REPAINTED grass by one `ReplaceMaterial` over the apex-to-back band -- the only way a split
			-- can run through the middle of a ball. The band starts above the terrace skin, because
			-- `SURFACE.BERM` and `SURFACE.LANE` are the same material and a band at the shelf would turn
			-- the terrace's own downrange strip to grass. The scrub is written last, so nothing paints it.
			for _, one in ipairs(balls) do
				expect(one.surface).to.equal("BERM")
			end
			-- THE SCRUB IS NOT DOWN THE FACE (306l's own assertion, restored for a ball): a clump's
			-- uprange edge reaches `scrubRadius - scrubBackStuds` past the apex at most, which is
			-- the crest's top and not the face a round lands on.
			for _, clump in ipairs(scrub) do
				-- this row runs with `dir` -1, so UPRANGE is +Z and the clump's uprange edge is z + r.
				local reach = (clump.z + clump.radius) - apex
				expect(reach <= LAYOUT.BERM.scrubRadius - LAYOUT.BERM.scrubBackStuds + 1e-6).to.equal(true)
			end
			local grassed = nil
			for _, call in ipairs(terrain.replaces) do
				if call.from == LAYOUT.SURFACE.BERM and call.to == LAYOUT.SURFACE.HILL then
					grassed = call
				end
			end
			expect(grassed).to.be.ok()
			local region = (grassed :: any).region
			-- WHERE THE BAND STARTS IS THE WHOLE CLAIM (round 1, finding 2): started at the TOE it
			-- would grass the impact face -- the half a shot travels to and the half Karen looks at
			-- -- and a size-only check passes on that. So both faces are pinned to the apex-to-back
			-- band within the one voxel `ExpandToGrid` may add on each side.
			local grid = LAYOUT.FILL.GRID_STUDS
			local bandLow, bandHigh = math.min(apex, back), math.max(apex, back)
			local lowFace = region.CFrame.Position.Z - region.Size.Z / 2
			local highFace = region.CFrame.Position.Z + region.Size.Z / 2
			expect(lowFace <= bandLow + 1e-6 and lowFace >= bandLow - grid - 1e-6).to.equal(true)
			expect(highFace >= bandHigh - 1e-6 and highFace <= bandHigh + grid + 1e-6).to.equal(true)
			expect(region.Size.Z >= LAYOUT.BERM.depth).to.equal(true)
			expect(region.Size.Z <= LAYOUT.BERM.depth + 2 * grid).to.equal(true)
			expect(region.CFrame.Position.Y - region.Size.Y / 2 > shelf + 1e-6).to.equal(true)
			expect(terrain.balls[#terrain.balls].material).to.equal(LAYOUT.SURFACE.SCRUB)
			-- (8) THE TWO BANKS ARE ROUNDED MOUNDS THAT RUN INTO THE HEAP, not two square blocks (306m
			-- item 2): two chains each, the radius TAPERS to the cap, and the cap's own top is the bank's
			-- designed height -- so the mound is as tall as the block was and has no face.
			for leg = 1, 2 do
				local chain = RangeData.bankBalls(anchor, LAYOUT, leg, -1)
				expect(#chain >= 6).to.equal(true)
				local zs = {}
				for _, one in ipairs(chain) do
					expect(one.surface).to.equal("HILL")
					zs[string.format("%.3f", one.z)] = true
				end
				local distinctZ = 0
				for _ in pairs(zs) do
					distinctZ += 1
				end
				expect(distinctZ).to.equal(2)
				table.sort(chain, function(left, right)
					return left.rise < right.rise
				end)
				expect(chain[1].radius > chain[#chain].radius).to.equal(true)
				expect(math.abs(chain[#chain].radius - LAYOUT.BERM.capRadius) < 1e-6).to.equal(true)
				expect(math.abs(chain[#chain].rise + chain[#chain].radius - LAYOUT.BANK.size.Y) < 1e-6).to.equal(true)
			end
			TestKit.note(
				string.format(
					"range 306m hill: %d columns x %d balls, crest %.2f..%.2f, skyline step %.2f (inner %.2f, "
						.. "cap dip %.2f), steepest one-stud rise %.2f studs, 4-stud slope %.1f deg at x %.0f "
						.. "(floor atan(21/8) = 69.1), runs %.2f..%.2f, %d scrub",
					#columns,
					#balls,
					lo,
					hi,
					step,
					inner,
					deepest,
					steepest,
					degrees,
					where,
					runLo,
					runHi,
					#scrub
				)
			)
			parent:Destroy()
		end)

		-- 306l item 1, and the 306k Reviewer's note 1: THE FARTHEST LANE IS CLEAR OF THE HEAP.
		-- MEASURED BEFORE: a terrain raycast down lane 2 read 7.28 studs of earth standing on the
		-- 179 lane, and a real `RangeRequest` for 179 put the boar at d 171.9 and 1.5 studs up the
		-- batter, hidden from bench 2 (306l-profile.luau, 306l-fire-look.luau, her place).
		it("keeps the backstop's toe behind the farthest lane, both ways down the row", function()
			local clear = RangeData.bermToeClearance(LAYOUT)
			expect(clear >= LAYOUT.BERM.toeClearStuds).to.equal(true)
			-- the released boar's trunk measures 2 x 3 x 5.5 in her place, so half its LENGTH is
			-- 2.75 -- and the clearance has to carry that plus room a partial voxel cannot cross.
			expect(clear > 5.5 / 2).to.equal(true)
			for _, dir in ipairs({ 1, -1 }) do
				local devAt = Vector3.new((DEV_ROW :: any).x, 0, (DEV_ROW :: any).z)
				for _, at in ipairs({ devAt, Vector3.new(-410.5, 12, 880.25) }) do
					local toe = RangeData.bermToeZ(at, LAYOUT, dir)
					local lane = RangeData.laneCentre(at, LAYOUT, dir, 2, RangeData.distanceMax(LAYOUT))
					-- THE TOE IS DOWNRANGE OF THE LANE, on the row's own side, by the clearance.
					expect(math.abs((dir * (toe - at.Z)) - (RangeData.distanceMax(LAYOUT) + clear)) < 1e-6).to.equal(
						true
					)
					expect(dir * (toe - lane.Z) > 0).to.equal(true)
					expect(math.abs(dir * (toe - lane.Z) - clear) < 1e-6).to.equal(true)
					-- ...AND NO BOX OF THE HEAP REACHES PAST IT, which is what the lane actually meets.
					for _, one in ipairs(Range.Build.bermFills(at, at.Y, LAYOUT, dir)) do
						-- the ball's UPRANGE-most point: the one the lane would meet.
						local nearest = one.at.Z - dir * one.radius
						expect(dir * (nearest - lane.Z) > 0).to.equal(true)
					end
					-- every one of the three lanes stands on clear ground, not only the farthest.
					for _, distance in ipairs(LAYOUT.DISTANCES_STUDS) do
						local point = RangeData.laneCentre(at, LAYOUT, dir, 2, distance)
						expect(dir * (toe - point.Z) >= clear - 1e-6).to.equal(true)
					end
				end
			end
			TestKit.note(
				string.format(
					"range 306l toe: crest face %d studs out, run %d, toe %d -- %.1f studs clear of the %d lane",
					LAYOUT.BERM.behindStuds - LAYOUT.BERM.depth / 2 + RangeData.distanceMax(LAYOUT),
					LAYOUT.BERM.slopeRun,
					RangeData.distanceMax(LAYOUT) + clear,
					clear,
					RangeData.distanceMax(LAYOUT)
				)
			)
		end)

		it("paints the mown lane, then the firing line over every mat, post and bench", function()
			local built, _, parent, terrain = buildOnTerrain(FOREST_ROW, slopedGround)
			local b = built :: any
			-- ONE REPLACE PER TERRACE RECTANGLE, then the line, then the hill's grass -- DERIVED
			-- from `cutRects` rather than typed as 4 (task 315): the live row's terrace is one
			-- rectangle now that the range meets the lobby field on one voxel plane.
			expect(#terrain.replaces).to.equal(#RangeData.cutRects(b.anchor, LAYOUT, -1, FOREST_ROW) + 2)
			for _, call in ipairs(terrain.replaces) do
				-- `ReplaceMaterial` takes the voxel resolution and nothing else (task 244).
				expect(call.resolution).to.equal(LAYOUT.FILL.GRID_STUDS)
			end
			local last = terrain.replaces[#terrain.replaces]
			-- THE LINE LAST. Not because the lane's repaint could undo it -- that one is AROUND -> LANE
			-- and cannot touch `Limestone` -- but because the order is the one the owner states, and a
			-- repaint aimed at LANE must run after everything that writes LANE (review round 1, note).
			-- 306m ADDED A FOURTH, AND IT IS LAST OF ALL: the hill's own grass line (BERM -> HILL).
			-- It cannot undo the firing line either -- that one is `Limestone` and this reads
			-- `Ground` -- and it runs in a band two voxels ABOVE the shelf, so it cannot reach the
			-- terrace's own `Ground` surface, which shares the heap's material exactly.
			expect(last.from).to.equal(LAYOUT.SURFACE.BERM)
			expect(last.to).to.equal(LAYOUT.SURFACE.HILL)
			local lineCall = terrain.replaces[#terrain.replaces - 1]
			expect(lineCall.from).to.equal(LAYOUT.SURFACE.LANE)
			expect(lineCall.to).to.equal(LAYOUT.SURFACE.LINE)
			for index = 1, #terrain.replaces - 2 do
				expect(terrain.replaces[index].from).to.equal(LAYOUT.SURFACE.AROUND)
				expect(terrain.replaces[index].to).to.equal(LAYOUT.SURFACE.LANE)
			end
			-- THE STRIP COVERS WHAT A MAN STANDS ON AT ALL SIX STATIONS, and that is the claim the
			-- three reaches exist for: every mat, every post and every bench, by its own footprint.
			local anchor = Vector3.new((FOREST_ROW :: any).x, b.shelf, (FOREST_ROW :: any).z)
			local line = RangeData.lineRect(anchor, LAYOUT, -1)
			local covered = 0
			for _, part in ipairs(partsOf(b.folder)) do
				if part.Name:match("^Mat%d") or part.Name:match("^Post%d") or part.Name:match("^Bench%d") then
					expect(part.Position.X - part.Size.X / 2 >= line.minX - 1e-6).to.equal(true)
					expect(part.Position.X + part.Size.X / 2 <= line.maxX + 1e-6).to.equal(true)
					expect(part.Position.Z - part.Size.Z / 2 >= line.minZ - 1e-6).to.equal(true)
					expect(part.Position.Z + part.Size.Z / 2 <= line.maxZ + 1e-6).to.equal(true)
					covered += 1
				end
			end
			expect(covered).to.equal(LAYOUT.SPOT_COUNT * 3)
			-- ...AND THE STRIP IS NOT THE WHOLE LANE: the gravel ends and the mown grass begins, or
			-- there is one surface and the two materials mean nothing.
			local rects = RangeData.cutRects(anchor, LAYOUT, -1, FOREST_ROW)
			local terraceZ = math.huge
			for _, rect in ipairs(rects) do
				terraceZ = math.min(terraceZ, rect.minZ)
			end
			expect(line.minZ > terraceZ + RangeData.distanceMax(LAYOUT) / 2).to.equal(true)
			parent:Destroy()
		end)

		it("takes its level from the LOBBY and lands on the same number a second time", function()
			-- THE FIXED POINT (task 311, review round 1 finding 1). `tryBuild` can run more than once,
			-- and the second run reads the ground the FIRST fill produced. Flooring is stable;
			-- rounding lifts the whole range a voxel per retry.
			local from = (FOREST_ROW :: any).shelfFrom
			expect(from.x).to.equal(LOBBY_ANCHOR.x)
			expect(from.z).to.equal(LOBBY_ANCHOR.z)
			local first = Range.Build.shelfAt(2600, -3030, FOREST_ROW, slopedGround)
			expect(first).to.equal(FOREST_SHELF)
			-- ...and the range anchor's OWN ground is a different number, so this case cannot pass by
			-- accident with `shelfFrom` ignored.
			expect(math.abs(slopedGround(2600, -3030) - (first :: number)) > 1).to.equal(true)
			local second = Range.Build.shelfAt(2600, -3030, FOREST_ROW, function()
				return first
			end)
			expect(second).to.equal(first)
			-- THE DEV ROW IS UNTOUCHED BY ALL OF IT: a plate is its own shelf, read from no ground.
			expect(Range.Build.shelfAt(1200, 0, DEV_ROW, nil)).to.equal(0)
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
				-- SIX MEN ON *HER* ROW'S MATS: since step B7 an empty station has no animal, so the
				-- crowd is built from the row under test and not from the DEV one.
				players = newCrowd({ 1, 2, 3, 4, 5, 6 }, row).players,
				now = now,
			})
			expect(ok).to.equal(true)
			advance(fake, clock, 4)
			local animal = fake.at(1)
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

	-- ------------------------------------------------------------------- THE LOOK (task 306, B10)
	--
	-- Karen, 2026-10-28: *"make nice shooting range clean proper like in real life"*. Research note
	-- docs/research/2026-10-28-the-range-in-the-lobby.md section 8, targets 8.3 L1-L6.
	describe("the look, and that it moved no gameplay number", function()
		-- L1. THE ONE CASE THAT WOULD HAVE CAUGHT A DRESSED RANGE BREAKING THE MEASURED ONE: every
		-- number B2-B9 measured, against the LITERAL it had before this step. A derived assertion
		-- (`== Range.matPosition(...)`) would pass with the arithmetic itself moved, which is exactly
		-- the mistake a look step can make.
		it("leaves every measured point and distance exactly where B2-B9 put it", function()
			expect(LAYOUT.DISTANCE_STUDS).to.equal(125)
			expect(LAYOUT.DISTANCES_STUDS[1]).to.equal(107)
			expect(LAYOUT.DISTANCES_STUDS[2]).to.equal(125)
			expect(LAYOUT.DISTANCES_STUDS[3]).to.equal(179)
			expect(LAYOUT.WINDOW_STUDS).to.equal(36)
			expect(LAYOUT.APRON_STUDS).to.equal(20)
			expect(LAYOUT.SPOT_COUNT).to.equal(6)
			expect(LAYOUT.SPOT_SPACING_STUDS).to.equal(24)
			-- 306l MOVED THE HEAP BACK AND NOTHING ELSE: `behindStuds` 13 -> 17 and `slopeRun`
			-- 12 -> 8 put the battered toe at 184, five studs clear of the 179 lane it used to
			-- stand 7.28 studs of earth on (306l first measure). `height` and `depth` are B8's
			-- still, and the far face at 200 keeps the terrace's own edge (202) two studs clear of
			-- the asphalt the same profile read at 204.
			expect(LAYOUT.BERM.height).to.equal(21)
			expect(LAYOUT.BERM.depth).to.equal(8)
			expect(LAYOUT.BERM.behindStuds).to.equal(17)
			expect(LAYOUT.BERM.slopeRun).to.equal(8)
			expect(RangeData.bermToeClearance(LAYOUT)).to.equal(5)
			expect(LAYOUT.BANK.size).to.equal(Vector3.new(12, 18, 14))
			expect(LAYOUT.BANK.beyondStuds).to.equal(6)
			expect(LAYOUT.MAT.size).to.equal(Vector3.new(8, 1, 8))
			expect(LAYOUT.POST.aheadStuds).to.equal(7)
			expect(LAYOUT.POST.sideStuds).to.equal(3)
			expect(LAYOUT.STAND.backStuds).to.equal(14)
			expect(LAYOUT.STAND.promptRise).to.equal(2.4)
			expect(LAYOUT.PROMPT.MaxActivationDistance).to.equal(12)
			-- THE BENCH'S SIZE AND ITS REACH, which are the 0.7-0.8 m rest: B10 changed the colour
			-- and the material and nothing else.
			expect(LAYOUT.BENCH.size).to.equal(Vector3.new(6, 2.7, 1.2))
			expect(LAYOUT.BENCH.aheadStuds).to.equal(3.5)
			-- ...and the points themselves, at an anchor with no plate and no reader at all.
			local anchor = Vector3.new(0, 100, 0)
			expect(RangeData.matPosition(anchor, 3, LAYOUT)).to.equal(Vector3.new(48, 100, 0))
			expect(RangeData.benchPosition(anchor, 3, LAYOUT, 1)).to.equal(Vector3.new(48, 101.35, 3.5))
			expect(RangeData.standPosition(anchor, 3, LAYOUT, 1)).to.equal(Vector3.new(48, 100, -14))
			expect(RangeData.promptPosition(anchor, 3, LAYOUT, 1)).to.equal(Vector3.new(51, 104, 7))
			expect(RangeData.bermSizeFor(LAYOUT)).to.equal(Vector3.new(232, 21, 8))
			expect(RangeData.bermPosition(anchor, LAYOUT, 1)).to.equal(Vector3.new(60, 100, 196))
			-- 306l: the crest's near face, the toe, and the clear ground the farthest lane keeps.
			expect(RangeData.bermCrestFaceZ(anchor, LAYOUT, 1)).to.equal(192)
			expect(RangeData.bermToeZ(anchor, LAYOUT, 1)).to.equal(184)
			expect(RangeData.bermToeZ(anchor, LAYOUT, -1)).to.equal(-184)
		end)

		-- L2. NOTHING THE HUT ADDS IS IN A LINE OF FIRE, and the bound is the arithmetic rather
		-- than a belief: the worst sight ray reaches `sightHalfWidthAt` off axis at that Z, and the
		-- post stands further out than that at EVERY station and EVERY corner.
		it("keeps the roofed firing point out of every line of fire", function()
			local anchor = Vector3.new(0, 100, 0)
			local hut = LAYOUT.HUT
			expect(hut.roofRise >= 8.5).to.equal(true)
			for _, dir in ipairs({ 1, -1 }) do
				for spot = 1, LAYOUT.SPOT_COUNT do
					local mat = RangeData.matPosition(anchor, spot, LAYOUT)
					-- TASK 313: the two downrange hut posts are the ONE piece of his own furniture
					-- in the bore's plane, so they no longer stand outside the fan -- they BOUND
					-- it. `RangeData.bayHalfSlope` is that bound, and the ray to the widest aim
					-- point the span allows stays inboard of the post's inner face at its own Z.
					for _, at in ipairs(RangeData.hutPostPositions(anchor, spot, LAYOUT, dir)) do
						local ahead = (at.z - mat.Z) * dir
						if ahead > 0 then
							local inner = math.abs(at.x - mat.X) - hut.postSection / 2
							for _, lane in ipairs(LAYOUT.DISTANCES_STUDS) do
								local lo, hi = RangeData.sightSpanFor(anchor, spot, LAYOUT, lane, true)
								local sil = LAYOUT.SIGHT.silhouetteStuds
								local worst = math.max(math.abs(hi + sil - mat.X), math.abs(mat.X - (lo - sil)))
								expect(worst * ahead / lane <= inner + 1e-6).to.equal(true)
							end
						end
					end
					-- AND THE ROOF CLEARS THE TREESTAND, which stands `backStuds` uprange: the roof's
					-- uprange edge must stop short of the deck's own downrange edge.
					local roof = RangeData.hutRoofPosition(anchor, spot, LAYOUT, dir)
					local roofBack = (roof.Z - mat.Z) * dir - hut.roofSize.Z / 2
					local deckFront = -LAYOUT.STAND.backStuds + HighSeats.DIMS.DECK_SIZE.X / 2
					expect(roofBack > deckFront).to.equal(true)
					-- ...and the ray from the DECK's eye to a target at the window passes OVER it.
					local deckEye = HighSeats.DIMS.DECK_RISE_STUDS + HighSeats.AIM_RISE_STUDS
					local far = LAYOUT.DISTANCES_STUDS[3] + LAYOUT.STAND.backStuds
					local atRoofEdge = (roof.Z - mat.Z) * dir + hut.roofSize.Z / 2 + LAYOUT.STAND.backStuds
					local rayY = deckEye - (deckEye - 5) * atRoofEdge / far
					expect(rayY > hut.roofRise + hut.roofSize.Y).to.equal(true)
				end
			end
			-- the bound is 0 at the firing point, and at the crest face it is the backstop's own
			-- corner from the outermost mat -- 160 studs at 192 ahead, 39.81 degrees (design 3.1).
			expect(RangeData.sightHalfWidthAt(LAYOUT, 0)).to.equal(0)
			local crest = RangeData.bermCrestFaceZ(Vector3.new(0, 0, 0), LAYOUT, 1)
			local backMin, backMax = RangeData.backstopSpanFor(Vector3.new(0, 0, 0), LAYOUT)
			expect(math.abs(RangeData.sightHalfWidthAt(LAYOUT, crest) - backMax) < 1e-6).to.equal(true)
			expect(math.abs(backMax - (RangeData.spotSpan(LAYOUT) - backMin)) < 1e-6).to.equal(true)
		end)

		-- ...AND THE SAME BOUND AGAINST WHAT `Build` ACTUALLY WRITES (round 1, finding 2). The case
		-- above is pure arithmetic and passes with the whole hut block deleted; this one reads every
		-- post and roof OUT OF THE FOLDER by name, so deleting the producer fails it.
		it("builds the hut where the sight bound says it may stand, and hangs the board on the roof", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			expect(built).to.be.ok()
			local folder = (built :: any).folder
			local anchor = (built :: any).anchor
			local dir = (built :: any).downrange
			local hut = LAYOUT.HUT
			for spot = 1, LAYOUT.SPOT_COUNT do
				local mat = RangeData.matPosition(anchor, spot, LAYOUT)
				local roof = folder:FindFirstChild(RangeData.hutRoofName(spot))
				expect(roof).to.be.ok()
				local roofPure = RangeData.hutRoofPosition(anchor, spot, LAYOUT, dir)
				expect(math.abs((roof :: any).Position.X - roofPure.X) < 1e-4).to.equal(true)
				expect(math.abs((roof :: any).Position.Z - roofPure.Z) < 1e-4).to.equal(true)
				local roofBottom = (roof :: any).Position.Y - (roof :: any).Size.Y / 2
				-- THE BUILT roof's underside is `roofRise` over the ground it was measured on, which
				-- over a plate is the shelf (`shelfAt`'s own rule).
				expect(math.abs(roofBottom - ((built :: any).shelf + hut.roofRise)) < 1e-4).to.equal(true)
				-- EVERY BUILT POST, out of the folder, against the widest sight ray at its own Z.
				local posts = 0
				for corner = 1, 4 do
					local post = folder:FindFirstChild(RangeData.hutPostName(spot, corner))
					expect(post).to.be.ok()
					posts += 1
					local ahead = ((post :: any).Position.Z - mat.Z) * dir
					if ahead > 0 then
						-- TASK 313: against the SPAN's widest ray, not against the backstop fan.
						local inner = math.abs((post :: any).Position.X - mat.X) - (post :: any).Size.X / 2
						for _, lane in ipairs(LAYOUT.DISTANCES_STUDS) do
							local lo, hi = RangeData.sightSpanFor(anchor, spot, LAYOUT, lane, true)
							local sil = LAYOUT.SIGHT.silhouetteStuds
							local worst = math.max(math.abs(hi + sil - mat.X), math.abs(mat.X - (lo - sil)))
							expect(worst * ahead / lane <= inner + 1e-6).to.equal(true)
						end
					end
					-- and it carries the roof: its top IS the roof's underside
					local top = (post :: any).Position.Y + (post :: any).Size.Y / 2
					expect(math.abs(top - roofBottom) < 1e-4).to.equal(true)
				end
				expect(posts).to.equal(4)
				-- THE BOARD HANGS ON THE ROOF, and this is the case the floating sign failed
				-- (round 1, finding 1): its TOP face is the roof's own underside, not 1.5 studs under it.
				local board = folder:FindFirstChild(RangeData.boardName(spot))
				expect(board).to.be.ok()
				local boardTop = (board :: any).Position.Y + (board :: any).Size.Y / 2
				expect(math.abs(boardTop - roofBottom) < 1e-4).to.equal(true)
				-- ...and it is under the roof's own uprange edge, not out in the air beside it
				local backEdge = roofPure.Z - dir * hut.roofSize.Z / 2
				expect(math.abs((board :: any).Position.Z - (backEdge + dir * hut.boardSize.Z / 2)) < 1e-4).to.equal(
					true
				)
			end
		end)

		-- L3/L4. THE MOWN LANE IS A PART NOTHING CAN MEET: a ray, a bullet, a boar's route and a
		-- man's feet all pass through it, so it cannot cover the target or change a shot.
		it("lays the mown lane as one part that no ray and no body can meet", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			expect(built).to.be.ok()
			local folder = (built :: any).folder
			local turf = folder:FindFirstChild(RangeData.TURF_NAME)
			expect(turf).to.be.ok()
			expect((turf :: any).CanCollide).to.equal(false)
			expect((turf :: any).CanQuery).to.equal(false)
			expect((turf :: any).CanTouch).to.equal(false)
			expect((turf :: any).Material).to.equal(Enum.Material.Grass)
			-- IT COVERS THE LANE AND NOT THE FIRING LINE: its near edge is the pale strip's own far
			-- edge, and its far edge is the berm's near face.
			local anchor = (built :: any).anchor
			local dir = (built :: any).downrange
			local slabs = RangeData.turfSlabs(anchor, LAYOUT, dir, DEV_ROW)
			expect(#slabs).to.equal(1)
			local rect = slabs[1]
			local line = RangeData.lineRect(anchor, LAYOUT, dir)
			local berm = RangeData.bermPosition(anchor, LAYOUT, dir)
			local lineFar = if dir == 1 then line.maxZ else line.minZ
			expect(math.abs(rect.minZ - math.min(lineFar, berm.Z - dir * LAYOUT.BERM.depth / 2)) < 1e-6).to.equal(true)
			expect(math.abs(rect.maxZ - (berm.Z - dir * LAYOUT.BERM.depth / 2)) < 1e-6).to.equal(true)
			-- its TOP is just proud of the shelf, so no voxel shows through and nothing floats
			local top = (turf :: any).Position.Y + (turf :: any).Size.Y / 2
			expect(math.abs(top - ((built :: any).shelf + LAYOUT.TURF.liftStuds)) < 1e-6).to.equal(true)
			-- AND THE LANE'S OWN GROUND IS STILL BLADE-FREE: B8's measured reason stands.
			expect(LAYOUT.SURFACE.LANE).to.equal(Enum.Material.Ground)
			-- ...AND THE BERM AND THE BANKS ARE BARE EARTH SINCE 306k, which reverses B10's `Grass`
			-- on the playtest's own reading: from the bench the blades made the heap read as "a thin
			-- band of tall grass on the horizon" instead of as a backstop.
			expect(LAYOUT.SURFACE.BERM).to.equal(Enum.Material.Ground)
		end)

		-- THE NUMBER BOARD SAYS THE STATION'S OWN NUMBER, read off the instance the player reads --
		-- and asserted at TWO different stations, because one pick cannot tell a real label from a
		-- hard-coded word (V298).
		it("prints each station's own number on its board", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			local folder = (built :: any).folder
			for _, spot in ipairs({ 1, 4, 6 }) do
				local board = folder:FindFirstChild(RangeData.boardName(spot))
				expect(board).to.be.ok()
				local faces = 0
				for _, gui in ipairs((board :: any):GetChildren()) do
					if gui:IsA("SurfaceGui") then
						faces += 1
						local label = gui:FindFirstChild("Number")
						expect(label).to.be.ok()
						expect((label :: any).Text).to.equal(tostring(spot))
						expect((label :: any).Text).to.equal(RangeData.boardText(spot))
					end
				end
				-- BOTH FACES, so the digit reads walking in and standing at the bench
				expect(faces).to.equal(2)
			end
			-- and the three are three different strings, so the case bites
			expect(RangeData.boardText(1)).never.to.equal(RangeData.boardText(4))
		end)

		-- WAS "climbs a man onto the deck and back down again" and "hangs a Climb on E ... and a
		-- Climb down on F": task 320 took the towers out, so there is nothing to climb. The two
		-- cases are replaced by this one, which asserts the climb is UNREACHABLE from both ends --
		-- no prompt to press, and the handler refuses every station because no deck was measured.
		it("has no climb at all: no prompt, nothing wired, and every station refused", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			local folder = (built :: any).folder
			-- NOT ONE CLIMB PROMPT, by name and by count.
			for _, child in ipairs(folder:GetDescendants()) do
				if child:IsA("ProximityPrompt") then
					expect(child.KeyboardKeyCode ~= LAYOUT.CLIMB.UP_KEY or child.ActionText ~= LAYOUT.CLIMB.UP_ACTION).to.equal(
						true
					)
					expect(child.ActionText ~= LAYOUT.CLIMB.DOWN_ACTION).to.equal(true)
				end
			end
			for spot = 1, LAYOUT.SPOT_COUNT do
				for _, way in ipairs({ "up", "down" }) do
					expect(folder:FindFirstChild(RangeData.climbPromptName(spot, way), true)).to.equal(nil)
				end
			end
			-- ...SO THERE IS NOTHING TO WIRE: the number the console line prints is 0.
			expect(Range.wireClimbs(folder)).to.equal(0)
			expect(Range.wireClimbs(nil)).to.equal(0)
			parent:Destroy()

			-- AND THE HANDLER ITSELF REFUSES, at every station, because the build measured no deck
			-- top -- the same rule it already applied to a station whose seat was refused.
			local runtime = Instance.new("Folder")
			local clock, now = newClock()
			local moved = 0
			local shelf = 140
			expect(Range.start({
				enabled = true,
				anchor = { x = 0, z = 0, y = shelf, plate = true },
				root = runtime,
				now = now,
				groundAt = function()
					return shelf
				end,
				move = function()
					moved += 1
					return true
				end,
			})).to.equal(true)
			expect(next(Range.deckTops())).to.equal(nil)
			for spot = 1, LAYOUT.SPOT_COUNT do
				expect(Range.onClimb({ Name = "a" }, spot)).to.equal(false)
			end
			expect(moved).to.equal(0)
			expect(Range.stats().climbsUp).to.equal(0)
			expect(Range.stats().climbsRefused).to.equal(LAYOUT.SPOT_COUNT)
			TestKit.note("range 320: 0 climb prompts, 0 wired, 6 stations refused -- the towers are gone")
			Range.stop()
			clock.t = 0
		end)

		-- THE CLIMB'S ANCHOR COMES OFF, AND IT PUTS BACK WHAT IT FOUND (306k item 3). The hold is
		-- what makes the server's pivot stick against the client that owns the body; a hold that is
		-- never released leaves a man anchored on the deck, and one released to `false` frees a man
		-- the hunt has tied.
		it("releases a climbed body's anchor after the settle, to the value it replaced", function()
			-- PARENTED, because the release SKIPS a root whose character has gone -- which is the
			-- last case below, and a parentless part would have made every case look like it.
			local bin = Instance.new("Folder")
			local free = Instance.new("Part")
			free.Anchored = false
			free.Parent = bin
			local tied = Instance.new("Part")
			tied.Anchored = true
			tied.Parent = bin
			-- DRIVEN THROUGH THE REAL QUEUE: `Range.start`'s own `move` seam is not used here,
			-- because the anchor lives in the SHIPPED arm -- so the two roots are handed straight to
			-- the step, which is the function `Range.step` calls every frame.
			Range.settleStep(math.huge)
			expect(Range.settling()).to.equal(0)
			Range.holdForSettle(free)
			Range.holdForSettle(tied)
			expect(Range.settling()).to.equal(2)
			expect(free.Anchored).to.equal(true)
			expect(tied.Anchored).to.equal(true)
			-- HALFWAY THROUGH, NOTHING IS RELEASED: a shorter hold than this is the defect.
			expect(Range.settleStep(0.1)).to.equal(0)
			expect(Range.settling()).to.equal(2)
			expect(free.Anchored).to.equal(true)
			-- ...and past it, both go back to what they were and the queue empties.
			expect(Range.settleStep(1)).to.equal(2)
			expect(Range.settling()).to.equal(0)
			expect(free.Anchored).to.equal(false)
			expect(tied.Anchored).to.equal(true)
			-- TWICE INSIDE THE WINDOW IS **ONE** HOLD, AND IT ENDS FREE (review round 1, finding 1).
			-- Neither prompt has a hold duration and item 1 put the way DOWN 5.78 studs in front of
			-- the man the way UP just placed, so a real E then a real F inside 0.4 s is one press
			-- apart. Recording the second `was` would restore the `true` the FIRST hold wrote and
			-- freeze him for the session.
			local twice = Instance.new("Part")
			twice.Anchored = false
			twice.Parent = bin
			Range.holdForSettle(twice)
			expect(Range.settleStep(0.1)).to.equal(0)
			Range.holdForSettle(twice)
			expect(Range.settling()).to.equal(1)
			expect(twice.Anchored).to.equal(true)
			-- the window was REFRESHED by the second hold, so 0.2 s more is not yet enough...
			expect(Range.settleStep(0.2)).to.equal(0)
			expect(twice.Anchored).to.equal(true)
			-- ...and past it he is FREE, which is the whole finding.
			expect(Range.settleStep(0.3)).to.equal(1)
			expect(twice.Anchored).to.equal(false)
			expect(Range.settling()).to.equal(0)
			-- ...and the same holds for a root that was ALREADY anchored: it goes back to anchored.
			local tiedTwice = Instance.new("Part")
			tiedTwice.Anchored = true
			tiedTwice.Parent = bin
			Range.holdForSettle(tiedTwice)
			Range.holdForSettle(tiedTwice)
			expect(Range.settleStep(1)).to.equal(1)
			expect(tiedTwice.Anchored).to.equal(true)

			-- A ROOT WHOSE CHARACTER WENT (a respawn mid-climb) is dropped and throws nothing.
			local gone = Instance.new("Part")
			gone.Parent = bin
			Range.holdForSettle(gone)
			gone:Destroy()
			expect(Range.settleStep(1)).to.equal(1)
			expect(Range.settling()).to.equal(0)
			TestKit.note("range: a climbed body is held 0.4 s and released to the Anchored it replaced")
		end)

		-- L6 AND THE EDGES: the fence stands outside the corridor, and nothing in the dressed range
		-- stands in the lane the target walks.
		it("fences the lot outside the corridor and inside the budget", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			local folder = (built :: any).folder
			local anchor = (built :: any).anchor
			local dir = (built :: any).downrange
			local west, east = RangeData.corridorSpan(LAYOUT)
			local posts = RangeData.fencePosts(anchor, LAYOUT, dir, DEV_ROW)
			local runs = RangeData.fenceRuns(anchor, LAYOUT, dir, DEV_ROW)
			expect(#posts >= 8).to.equal(true)
			-- BOTH SIDES HAVE A RUN in a world whose terrace is one rectangle
			expect(#runs).to.equal(2)
			expect(runs[1].leg).never.to.equal(runs[2].leg)
			for _, post in ipairs(posts) do
				-- OUTSIDE THE CORRIDOR, by the bank's own reach, on both sides
				local outside = post.x <= anchor.X + west - LAYOUT.BANK.beyondStuds
					or post.x >= anchor.X + east + LAYOUT.BANK.beyondStuds
				expect(outside).to.equal(true)
			end
			-- AND THE BUILD WRITES NONE OF THEM. Measured in her place on 2026-10-29: along the lot's
			-- east line the build's own ground reader and a terrain raycast disagree by 7.5 studs, so
			-- a post laid there stands in the air (`Build`'s own comment carries the readings). The
			-- arithmetic is kept for a later task; the DECISION that nothing is built on it is here,
			-- as a case, rather than in a comment nobody runs.
			for run = 1, #runs do
				expect(folder:FindFirstChild(RangeData.fencePostName(run, 1))).to.equal(nil)
				expect(folder:FindFirstChild(RangeData.fenceRailName(run))).to.equal(nil)
			end
			-- A TWO-RECTANGLE TERRACE, AND IT IS NOW DRIVEN BY PARAMETER (task 315). Her live row
			-- meets the lobby field on one voxel plane, so `cutRects` returns ONE rectangle for it
			-- and this arm would go dark; a synthetic row 40 studs north of the field's south edge
			-- still splits, and that is the shape this case exists to cover. A post over the lip of
			-- a terrace is the defect, not a short fence.
			local half = LOBBY_CFG.FIELD.SPAN_STUDS / 2
			local FOREST_ROW_SPLIT = table.clone(FOREST_ROW :: any)
			FOREST_ROW_SPLIT.z = LOBBY_ANCHOR.z - half + 40
			local forestAnchor = Vector3.new(FOREST_ROW_SPLIT.x, 148, FOREST_ROW_SPLIT.z)
			local forestCuts = RangeData.cutRects(forestAnchor, LAYOUT, -1, FOREST_ROW_SPLIT)
			expect(#forestCuts).to.equal(2)
			for _, run in ipairs(RangeData.fenceRuns(forestAnchor, LAYOUT, -1, FOREST_ROW_SPLIT)) do
				local inside = false
				for _, cut in ipairs(forestCuts) do
					if
						run.x - LAYOUT.FENCE.postSection / 2 >= cut.minX
						and run.x + LAYOUT.FENCE.postSection / 2 <= cut.maxX
						and run.minZ >= cut.minZ
						and run.maxZ <= cut.maxZ
					then
						inside = true
					end
				end
				expect(inside).to.equal(true)
			end
			-- NOTHING FLOATS AND NOTHING IS HALF BURIED (CLAUDE.md rule E, as a census): every
			-- COLLIDING part's lowest face is at or above the shelf less one stud, and its highest is
			-- above the shelf. The turf is the one exception and it is excluded by name.
			local shelf = (built :: any).shelf
			local worst = 0
			for _, child in ipairs(folder:GetDescendants()) do
				if
					child:IsA("BasePart")
					and child.Name:sub(1, #RangeData.TURF_NAME) ~= RangeData.TURF_NAME
					and child.Name ~= "Plate"
				then
					local low = child.Position.Y - child.Size.Y / 2
					worst = math.min(worst, low - shelf)
					expect(child.Position.Y + child.Size.Y / 2 > shelf).to.equal(true)
				end
			end
			-- the deepest foot is the seat's own `FOOT_EMBED_STUDS`, and nothing is deeper
			expect(worst >= -(HighSeats.DIMS.FOOT_EMBED_STUDS + 0.35)).to.equal(true)
			local parts = 0
			for _, child in ipairs(folder:GetDescendants()) do
				if child:IsA("BasePart") then
					parts += 1
				end
			end
			expect(parts <= Range.CONFIG.MAX_PARTS).to.equal(true)
			TestKit.note(
				string.format(
					"range B10: %d parts dressed (budget %d), %d lot-edge posts REFUSED (measured, see Build), worst foot %.2f studs",
					parts,
					Range.CONFIG.MAX_PARTS,
					#posts,
					worst
				)
			)
		end)
	end)

	-- ============================= TASK 313: SOLO ON THE WHOLE RANGE =============================
	-- Karen, 2026-10-30: *"when I click E it will make that I am alone in all shooting range ...
	-- now is to short for one specific stand"*. The span is the INTERSECTION of three bounds, and
	-- each case below fails if any one of them is deleted.
	-- Design: docs/design/shooting-range-lobby.md sections 2, 3, 4, 9
	describe("the span: solo on the whole range (task 313)", function()
		local AT = Vector3.new(0, 100, 0)

		-- THE SPAN RECOMPUTED FROM THE SAME DIALS, NOT TYPED: deleting any bound changes it.
		local function expected(spot: number, lane: number): (number, number)
			local matX = RangeData.matPosition(AT, spot, LAYOUT).X
			local crest = math.abs(RangeData.bermCrestFaceZ(Vector3.new(0, 0, 0), LAYOUT, 1))
			local backMin, backMax = RangeData.backstopSpanFor(AT, LAYOUT)
			local scale = lane / crest
			local sil = LAYOUT.SIGHT.silhouetteStuds
			local lo = matX + (backMin - matX) * scale + sil
			local hi = matX + (backMax - matX) * scale - sil
			local bay = RangeData.bayHalfSlope(LAYOUT) * lane
			lo = math.max(lo, matX - bay + sil)
			hi = math.min(hi, matX + bay - sil)
			local west, east = RangeData.corridorSpan(LAYOUT)
			lo = math.max(lo, AT.X + west + LAYOUT.APRON_STUDS)
			hi = math.min(hi, AT.X + east - LAYOUT.APRON_STUDS)
			return lo, hi
		end

		local function width(spot: number, lane: number): number
			local lo, hi = RangeData.sightSpanFor(AT, spot, LAYOUT, lane, true)
			return hi - lo
		end

		it("derives the span from the built earth, his own bay and the apron", function()
			for spot = 1, LAYOUT.SPOT_COUNT do
				for _, lane in ipairs(LAYOUT.DISTANCES_STUDS) do
					local lo, hi = RangeData.sightSpanFor(AT, spot, LAYOUT, lane, true)
					local wantLo, wantHi = expected(spot, lane)
					expect(math.abs(lo - wantLo) < 1e-9).to.equal(true)
					expect(math.abs(hi - wantHi) < 1e-9).to.equal(true)
				end
			end
			-- ...AND THE DESIGN NUMBERS (section 3.2), to 0.01 studs: the three floors at the outer
			-- stations and the three ceilings in the middle.
			expect(math.abs(width(1, 107) - 71.07) < 0.01).to.equal(true)
			expect(math.abs(width(1, 125) - 80.67) < 0.01).to.equal(true)
			expect(math.abs(width(1, 179) - 109.47) < 0.01).to.equal(true)
			expect(math.abs(width(3, 107) - 98.11) < 0.01).to.equal(true)
			expect(math.abs(width(3, 125) - 115.96) < 0.01).to.equal(true)
			expect(math.abs(width(3, 179) - 156) < 0.01).to.equal(true)
			-- symmetric about the line: station 6 mirrors station 1, station 4 mirrors station 3
			expect(math.abs(width(6, 179) - width(1, 179)) < 1e-9).to.equal(true)
			expect(math.abs(width(4, 179) - width(3, 179)) < 1e-9).to.equal(true)
			-- ...and EVERY station gains: the NARROWEST span is 71.07 studs, 1.97x the shipped
			-- window, and the widest is 156, 4.33x.
			expect(width(1, 107) / LAYOUT.WINDOW_STUDS > 1.9).to.equal(true)
			expect(math.abs(width(3, 179) / LAYOUT.WINDOW_STUDS - 4.333) < 0.01).to.equal(true)
		end)

		-- WRITTEN OUT, NOT DELEGATED (the Reviewer, round 1, finding 1): the OFF span is the mat
		-- plus or minus half the shipped window, and the OFF leg is the lane's centre plus or minus
		-- half `laneLength` -- the two arithmetics this file shipped with, typed from the dials and
		-- not read back out of the functions the new code delegates to.
		it("is bit-for-bit the shipped window with the flag off", function()
			local half = LAYOUT.WINDOW_STUDS / 2
			local legHalf = RangeData.laneLength(LAYOUT) / 2
			for spot = 1, LAYOUT.SPOT_COUNT do
				local matX = RangeData.matPosition(AT, spot, LAYOUT).X
				for _, lane in ipairs(LAYOUT.DISTANCES_STUDS) do
					local lo, hi = RangeData.sightSpanFor(AT, spot, LAYOUT, lane, false)
					expect(lo).to.equal(matX - half)
					expect(hi).to.equal(matX + half)
					-- nil is OFF too: an unwired caller gets today's game, never the wide span
					local nilLo, nilHi = RangeData.sightSpanFor(AT, spot, LAYOUT, lane, nil)
					expect(nilLo).to.equal(matX - half)
					expect(nilHi).to.equal(matX + half)
				end
				for leg = 1, 4 do
					for _, dir in ipairs({ 1, -1 }) do
						local centre = RangeData.laneCentre(AT, LAYOUT, dir, spot, LAYOUT.DISTANCE_STUDS)
						-- an odd leg runs to the east end, an even one back west
						local want = if (leg % 2) == 1 then centre.X + legHalf else centre.X - legHalf
						local shipped = RangeData.laneEnds(AT, LAYOUT, leg, dir, spot, LAYOUT.DISTANCE_STUDS)
						local off = RangeData.laneEndsFor(AT, LAYOUT, leg, dir, spot, LAYOUT.DISTANCE_STUDS, false)
						expect(shipped.X).to.equal(want)
						expect(off.X).to.equal(want)
						expect(shipped.Z).to.equal(centre.Z)
						expect(off.Z).to.equal(centre.Z)
					end
				end
			end
		end)

		-- T18: the span, the leg and the corridor NEST, always and at every station.
		it("nests the span inside the leg inside the corridor, and releases outside the span", function()
			local west, east = RangeData.corridorSpan(LAYOUT)
			for spot = 1, LAYOUT.SPOT_COUNT do
				for _, lane in ipairs(LAYOUT.DISTANCES_STUDS) do
					for _, wide in ipairs({ true, false }) do
						local lo, hi = RangeData.sightSpanFor(AT, spot, LAYOUT, lane, wide)
						expect(hi > lo).to.equal(true)
						for _, dir in ipairs({ 1, -1 }) do
							local legEast = RangeData.laneEndsFor(AT, LAYOUT, 1, dir, spot, lane, wide)
							local legWest = RangeData.laneEndsFor(AT, LAYOUT, 2, dir, spot, lane, wide)
							expect(legEast.X >= hi).to.equal(true)
							expect(legWest.X <= lo).to.equal(true)
							expect(legEast.X <= AT.X + east + 1e-9).to.equal(true)
							expect(legWest.X >= AT.X + west - 1e-9).to.equal(true)
							-- RELEASED OUTSIDE THE SPAN, so `windowArmed` is right and the first
							-- entry is a real crossing (design 4).
							expect(RangeData.inWindow(lo, hi, legEast.X)).to.equal(false)
							expect(RangeData.inWindow(lo, hi, legWest.X)).to.equal(false)
						end
					end
				end
			end
		end)

		-- T6, RE-SWEPT: 36 combinations (6 stations x 3 lanes x 2 firing positions).
		it("lands every widest shot inside the backstop, from both firing positions", function()
			local crest = math.abs(RangeData.bermCrestFaceZ(Vector3.new(0, 0, 0), LAYOUT, 1))
			local backMin, backMax = RangeData.backstopSpanFor(AT, LAYOUT)
			local sil = LAYOUT.SIGHT.silhouetteStuds
			local swept = 0
			local worstAngle = 0
			for spot = 1, LAYOUT.SPOT_COUNT do
				local matX = RangeData.matPosition(AT, spot, LAYOUT).X
				for _, lane in ipairs(LAYOUT.DISTANCES_STUDS) do
					local lo, hi = RangeData.sightSpanFor(AT, spot, LAYOUT, lane, true)
					-- BENCH: the firing point is the mat. DECK: `STAND.backStuds` further back, so
					-- both the lane and the crest are that much further away.
					for _, back in ipairs({ 0, LAYOUT.STAND.backStuds }) do
						swept += 1
						for _, aim in ipairs({ lo - sil, hi + sil }) do
							local x = matX + (aim - matX) * (crest + back) / (lane + back)
							expect(x >= backMin - 1e-6).to.equal(true)
							expect(x <= backMax + 1e-6).to.equal(true)
							local angle = math.deg(math.atan(math.abs(aim - matX) / lane))
							worstAngle = math.max(worstAngle, angle)
						end
					end
				end
			end
			expect(swept).to.equal(36)
			-- THE WIDEST ANGLE THIS RANGE IS ACTUALLY OFFERED IS THE BAY'S, 28.07 degrees, and
			-- MEASURED rather than taken from the design: section 3.3's table reads 39.81 for
			-- station 1 at 107, which is the angle to the BACKSTOP's corner -- but the bay bound
			-- cuts that lane's span to +-53.07 before the backstop ever binds, so the widest aim
			-- point is 57.07 off axis and not 89.17. 39.81 is the BOUND; 28.07 is the fact, and
			-- the margin between them is the design being conservative in the safe direction.
			-- It was 9.55 before this task.
			local bay = math.deg(math.atan(RangeData.bayHalfSlope(LAYOUT)))
			local backstop = math.deg(math.atan(RangeData.backstopSlope(LAYOUT)))
			expect(math.abs(worstAngle - bay) < 1e-6).to.equal(true)
			expect(math.abs(worstAngle - 28.07) < 0.01).to.equal(true)
			expect(worstAngle < backstop).to.equal(true)
			expect(math.abs(backstop - 39.81) < 0.01).to.equal(true)
			TestKit.note(
				string.format("range 313: T6 swept %d combinations, worst off-axis %.2f deg", swept, worstAngle)
			)
		end)

		-- THE BOUND IS LOAD-BEARING: remove the shoulder trim and a shot leaves the full-height
		-- earth. This is the case that fails if `backstopSpanFor` ever becomes `bermSpanFor`.
		it("fails the sweep when the backstop is not trimmed by the shoulders", function()
			-- STATION 3 AT 107, LOW SIDE, which is where the backstop bound actually binds: its
			-- `lo` is 2.96 and the bay's is -5.07, so the trim is the only thing holding it. (At
			-- station 1 the bay binds at every lane, which is why a case there proves nothing.)
			local matX = RangeData.matPosition(AT, 3, LAYOUT).X
			local tightLo = (RangeData.sightSpanFor(AT, 3, LAYOUT, 107, true))
			local bay = matX - RangeData.bayHalfSlope(LAYOUT) * 107 + LAYOUT.SIGHT.silhouetteStuds
			expect(tightLo > bay + 1e-6).to.equal(true)

			local berm = table.clone(LAYOUT.BERM)
			berm.shoulderStuds = 0
			local loose = layoutWith({ BERM = berm })
			local crest = math.abs(RangeData.bermCrestFaceZ(Vector3.new(0, 0, 0), LAYOUT, 1))
			local tightMin = (RangeData.backstopSpanFor(AT, LAYOUT))
			local looseLo = (RangeData.sightSpanFor(AT, 3, loose, 107, true))
			expect(looseLo < tightLo - 1e-6).to.equal(true)
			-- the loose span's widest ray lands on the SHOULDER, outside the full-height earth
			local x = matX + (looseLo - LAYOUT.SIGHT.silhouetteStuds - matX) * crest / 107
			expect(x < tightMin - 1e-6).to.equal(true)
			expect(x >= tightMin - LAYOUT.BERM.shoulderStuds - 1e-6).to.equal(true)
			-- ...and the SHIPPED span's same ray does not
			local tight = matX + (tightLo - LAYOUT.SIGHT.silhouetteStuds - matX) * crest / 107
			expect(tight >= tightMin - 1e-6).to.equal(true)
		end)

		-- THE REGRESSION SECTION 2 EXISTS TO PREVENT: the ISSF paces are a TIME across the ISSF
		-- window and must not move with what a man can see.
		it("keeps the ISSF paces on the ISSF window while the span is wide", function()
			expect(RangeData.paceWindowStuds(LAYOUT)).to.equal(36)
			expect(RangeData.paceSpeedFor("slow", LAYOUT, speedOf)).to.equal(36 / 5.0)
			expect(RangeData.paceSpeedFor("fast", LAYOUT, speedOf)).to.equal(36 / 2.5)
			local slow = RangeData.paceSpeedFor("slow", LAYOUT, speedOf)
			local fast = RangeData.paceSpeedFor("fast", LAYOUT, speedOf)
			expect(RangeData.crossingSeconds(RangeData.paceWindowStuds(LAYOUT), slow)).to.equal(5.0)
			expect(RangeData.crossingSeconds(RangeData.paceWindowStuds(LAYOUT), fast)).to.equal(2.5)
			-- and the SPAN is 2.0x to 4.3x the shipped window at run, which is Karen complaint
			local run = speedOf("run")
			expect(math.abs(RangeData.crossingSeconds(width(1, 107), run) - 2.96) < 0.01).to.equal(true)
			expect(math.abs(RangeData.crossingSeconds(width(3, 179), run) - 6.50) < 0.01).to.equal(true)
			expect(math.abs(RangeData.crossingSeconds(LAYOUT.WINDOW_STUDS, run) - 1.50) < 0.01).to.equal(true)
		end)
	end)

	-- ====================== TASK 313: THE SERVER'S OWN DOOR CARRIES IT ========================
	-- The Reviewer, round 1, finding 2: the whole server side had no case. These are design
	-- 14.1 items 9 and 11, driven through `Range.start` and read on the wire.
	-- Design: docs/design/shooting-range-lobby.md sections 7.3, 9.4, 14.1
	describe("the span: the server's own door (task 313)", function()
		local function manOn(spot: number, id: number)
			local man = manOnMat(spot) :: any
			man.UserId = id
			man.Name = "Solo" .. tostring(id)
			return man
		end

		local function rootOf(man): BasePart
			return (man.Character :: Instance):FindFirstChild("HumanoidRootPart") :: BasePart
		end

		-- ITEM 11: `alone` and the window are the SERVER's measurement and they ride the record.
		-- Both states of the flag are entered BY PARAMETER, so the case holds whichever way the
		-- flag's default is set.
		it("carries solo through Range.start onto the record: alone, and the wide window", function()
			for _, solo in ipairs({ true, false }) do
				Range.stop()
				local fake = newFakeBoars()
				local clock, now = newClock()
				local man = manOn(4, 1340)
				local players = function()
					return { man }
				end
				expect(select(1, startRange(fake, now, nil, nil, players, solo))).to.equal(true)
				advance(fake, clock, 1)
				expect((Range.positionOf(man))).to.equal(4)
				-- ONE PICK MAKES HIS RECORD, which is the board's audience.
				expect(Range.onRequest(man, { spot = 4, go = true })).to.equal(true)
				local record = Range.recordOf(man) :: any
				expect(record).to.be.ok()
				expect(record.alone).to.equal(solo)
				local matX = RangeData.matPosition(ANCHOR, 4, LAYOUT).X
				local width = record.window.maxX - record.window.minX
				if solo then
					-- THE WIDE SPAN REACHED THE WIRE: his own station's, at the lane his own trial
					-- is running, and at the narrowest nearly twice the shipped window.
					local lane = (Range.trialOf(4) :: any).distanceStuds
					local lo, hi = RangeData.sightSpanFor(ANCHOR, 4, LAYOUT, lane, true)
					expect(record.window.minX).to.equal(lo)
					expect(record.window.maxX).to.equal(hi)
					expect(width > LAYOUT.WINDOW_STUDS * 1.9).to.equal(true)
				else
					-- ...AND WITH IT OFF, TODAY'S GAME, written out from the dials and not read
					-- back out of `windowSpanFor` (finding 1's rule, applied here too).
					expect(record.window.minX).to.equal(matX - LAYOUT.WINDOW_STUDS / 2)
					expect(record.window.maxX).to.equal(matX + LAYOUT.WINDOW_STUDS / 2)
					expect(width).to.equal(LAYOUT.WINDOW_STUDS)
				end
				-- OFF THE MAT, `alone` IS FALSE AND THERE IS NO WINDOW -- with solo ON as well: a
				-- man who walked away is not kept inside an isolated picture (item 11).
				rootOf(man).Position = RangeData.matPosition(ANCHOR, 4, LAYOUT) + Vector3.new(0, 0, -600)
				local away = Range.recordOf(man) :: any
				expect(away.alone).to.equal(false)
				expect(away.window).to.equal(nil)
				expect(away.mine).to.equal(nil)
				Range.stop()
			end
		end)

		-- ITEM 9, and design 7.3's own sentence: the station EDGE. He walks from 2 to 4 and asks
		-- for NOTHING; the push that follows names station 4's trunk and `spanPushes` counts it.
		it("pushes station 4's trunk when he walks from 2 to 4, with no request", function()
			Range.stop()
			local fake = newFakeBoars()
			local clock, now = newClock()
			local man = manOn(2, 1341)
			local players = function()
				return { man }
			end
			-- SOLO OFF, so the window on the wire is today's arithmetic whatever the flag is set to.
			expect(select(1, startRange(fake, now, nil, nil, players, false))).to.equal(true)
			local sent = {}
			Range.setRemotes({
				RangeBoard = {
					FireClient = function(_, _player, payload)
						table.insert(sent, payload)
					end,
				},
			})
			advance(fake, clock, 1)
			expect(Range.onRequest(man, { spot = 2, go = true })).to.equal(true)
			-- TOLD WITHOUT ASKING since task 321 (e), so the pick's payload is the last one.
			expect(#sent >= 1).to.equal(true)
			local twoTrunk = sent[#sent].record.mine
			expect(twoTrunk).to.equal(fake.at(2).root)

			local pushes = Range.stats().spanPushes
			local before = #sent
			rootOf(man).Position = RangeData.matPosition(ANCHOR, 4, LAYOUT)
			advance(fake, clock, 1)
			-- ONE EDGE, ONE COUNT, and he was told without asking for anything.
			expect(Range.stats().spanPushes).to.equal(pushes + 1)
			expect(#sent > before).to.equal(true)
			local last = sent[#sent].record
			expect(last.mine).to.equal(fake.at(4).root)
			expect(last.mine).never.to.equal(twoTrunk)
			local fourX = RangeData.matPosition(ANCHOR, 4, LAYOUT).X
			expect(last.window.minX).to.equal(fourX - LAYOUT.WINDOW_STUDS / 2)
			expect(last.window.maxX).to.equal(fourX + LAYOUT.WINDOW_STUDS / 2)
			Range.setRemotes(nil)
			Range.stop()
		end)
	end)
end
