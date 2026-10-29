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
	local function startRange(fake, now, roll, serverTime, players)
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
			-- ...AND KAREN'S PLACE NOW HAS ONE, RE-MEASURED FOR SIX STATIONS (step B8, design 2.1).
			-- The B6 anchor (2650, -3216) was chosen for ONE station over a 160 x 185 footprint and
			-- the case below measured three ways in which six no longer fit it. The B8 census, run in
			-- her own place 2026-10-29 over design 2.2's 256 x 239 box: 990 ground samples, 0 missed,
			-- 0 non-terrain hits, 0 BaseParts inside it. The row it replaced is archived at
			-- backups/task-306b8/ with its note (rule 7).
			local forest = RangeData.anchorFor("forest-test")
			expect(forest).to.be.ok()
			expect((forest :: any).x).to.equal(2600)
			expect((forest :: any).z).to.equal(-3030)
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
			-- TWO PER STATION SINCE STEP B3 (the bench's post and the stand's rail, design 7.3) and
			-- FOUR SINCE B10: the climb up at the ladder's foot and the climb down over the rail gap.
			expect(prompts).to.equal(4 * LAYOUT.SPOT_COUNT)
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
			-- THE PLATE, THE SIX MATS, THE SIX POSTS, THE SIX BENCHES, THE SIX SEATS, THE TWO BANKS
			-- AND THE BERM -- counted from the seat's own published size, never from 84.
			-- ...PLUS WHAT STEP B10 DRESSES IT WITH, counted the same way: per station four hut
			-- posts, a roof and a number board; then ONE turf slab, the fence's own posts and its
			-- two rails. Written as the arithmetic and not as 165, so a part that appears or
			-- disappears moves this number rather than passing under it.
			local dressed = LAYOUT.SPOT_COUNT * 6
				+ #RangeData.turfSlabs((b :: any).anchor, LAYOUT, (b :: any).downrange, DEV_ROW)
				+ #RangeData.fencePosts((b :: any).anchor, LAYOUT, (b :: any).downrange, DEV_ROW)
				+ #RangeData.fenceRuns((b :: any).anchor, LAYOUT, (b :: any).downrange, DEV_ROW)
			expect(b.parts).to.equal(
				1 + 3 * LAYOUT.SPOT_COUNT + LAYOUT.SPOT_COUNT * HighSeats.PARTS_PER_SEAT + 3 + dressed
			)
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
			-- THE REACH IS THE SEAT'S OWN NUMBER, not a typed one.
			expect(RangeData.standReach(LAYOUT)).to.equal(LAYOUT.STAND.backStuds + HighSeats.footprintRadiusStuds())
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
	describe("Build: the bench and the treestand", function()
		local function buildInto(row, groundAt)
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = row, layout = LAYOUT, groundAt = groundAt })
			return built :: any, parent
		end

		it("lays a bench and a 14-piece seat at every station, with the ladder and the gap UPRANGE", function()
			-- BOTH SIGNS OF THE LANE, because the whole of `facing` is that the seat turns WITH the
			-- row: a constant would put the ladder in front of the DEV shooter (design 7.1, L-019).
			for _, dir in ipairs({ 1, -1 }) do
				local row = { x = DEV_ROW.x, z = DEV_ROW.z, y = DEV_ROW.y, plate = true, downrange = dir }
				local b, parent = buildInto(row, nil)
				expect(b).to.be.ok()
				expect(b.downrange).to.equal(dir)
				expect(b.stands).to.equal(LAYOUT.SPOT_COUNT)
				expect(b.refusedStands).to.equal(0)
				for spot = 1, LAYOUT.SPOT_COUNT do
					-- THE BENCH, at its own arithmetic point.
					local bench = b.folder:FindFirstChild(RangeData.benchName(spot))
					expect(bench).to.be.ok()
					local wantedBench = RangeData.benchPosition(b.anchor, spot, LAYOUT, dir)
					expect(((bench :: BasePart).Position - wantedBench).Magnitude < 1e-3).to.equal(true)
					-- THE SEAT, in a folder of its own, with the seat's own part count.
					local seat = b.folder:FindFirstChild(RangeData.standName(spot))
					expect(seat).to.be.ok()
					local pieces = 0
					for _, child in ipairs((seat :: Instance):GetDescendants()) do
						if child:IsA("BasePart") then
							pieces += 1
						end
					end
					expect(pieces).to.equal(HighSeats.PARTS_PER_SEAT)
					-- THE DECK IS WHERE THE ARITHMETIC SAYS, and its top is what `deckTops` reports.
					local deck = (seat :: Instance):FindFirstChild("Deck") :: BasePart
					local at = RangeData.standPosition(b.anchor, spot, LAYOUT, dir)
					expect(math.abs(deck.Position.X - at.X) < 1e-3).to.equal(true)
					expect(math.abs(deck.Position.Z - at.Z) < 1e-3).to.equal(true)
					expect(math.abs(b.deckTops[spot] - (deck.Position.Y + deck.Size.Y / 2)) < 1e-3).to.equal(true)
					expect(math.abs(b.deckTops[spot] - (b.shelf + HighSeats.DIMS.DECK_RISE_STUDS)) < 1e-3).to.equal(
						true
					)
					-- THE MIRROR, READ OFF THE BUILT PARTS: the ladder and the rail's GAP stand on
					-- the UPRANGE face, behind the shooter, and the solid board faces downrange as
					-- the shooting rest `high-seats.md` 5.3 designed it.
					local ladder = (seat :: Instance):FindFirstChild("Ladder") :: BasePart
					expect((ladder.Position.Z - deck.Position.Z) * dir < 0).to.equal(true)
					for _, name in ipairs({ "RailSE", "RailSW" }) do
						local stub = (seat :: Instance):FindFirstChild(name) :: BasePart
						expect((stub.Position.Z - deck.Position.Z) * dir < 0).to.equal(true)
					end
					local solid = (seat :: Instance):FindFirstChild("RailN") :: BasePart
					expect((solid.Position.Z - deck.Position.Z) * dir > 0).to.equal(true)
					-- AND THE LADDER IS CLIMBED BY THE ENGINE, with no script and no key.
					expect(ladder:IsA("TrussPart")).to.equal(true)
				end
				-- THE MAT IS STILL THE FOLDER'S FIRST DIRECT-CHILD BasePart: the harness's stage
				-- block puts the player on it, and 84 seat parts must not get in front of it.
				local first = b.folder:FindFirstChildWhichIsA("BasePart")
				expect(first.Name).to.equal(RangeData.matName(1))
				expect(b.parts <= Range.CONFIG.MAX_PARTS).to.equal(true)
				if dir == 1 then
					TestKit.note(
						string.format(
							"range B3: %d parts, %d stands, deck tops %.1f (shelf %.1f + %.1f), bench %.1f tall",
							b.parts,
							b.stands,
							b.deckTops[1],
							b.shelf,
							HighSeats.DIMS.DECK_RISE_STUDS,
							LAYOUT.BENCH.size.Y
						)
					)
				end
				parent:Destroy()
			end
		end)

		it("gives every station TWO prompts, each found by name, and neither in the other's reach", function()
			local dir = 1
			local row = { x = DEV_ROW.x, z = DEV_ROW.z, y = DEV_ROW.y, plate = true, downrange = dir }
			local b, parent = buildInto(row, nil)
			local reach = LAYOUT.PROMPT.MaxActivationDistance
			local stand = {}
			for spot = 1, LAYOUT.SPOT_COUNT do
				local bench = RangeData.promptFor(spot, RangeData.POSITION.BENCH, b.folder)
				local high = RangeData.promptFor(spot, RangeData.POSITION.TREESTAND, b.folder)
				expect(bench).to.be.ok()
				expect(high).to.be.ok()
				expect(high.Name).to.equal(RangeData.promptName(spot, RangeData.POSITION.TREESTAND))
				expect(high.Name ~= bench.Name).to.equal(true)
				local benchAt = RangeData.promptPointOf(bench) :: Vector3
				local highAt = RangeData.promptPointOf(high) :: Vector3
				stand[spot] = highAt
				-- THE BUILT PROMPT IS WHERE THE ARITHMETIC SAYS (over a plate the shelf and the
				-- measured ground are one point), so the screen's claim and the world agree.
				local wanted = RangeData.promptPosition(b.anchor, spot, LAYOUT, dir, RangeData.POSITION.TREESTAND)
				expect((highAt - wanted).Magnitude < 1e-3).to.equal(true)
				-- THEY CANNOT BE CONFUSED FOR ONE REACH, which is why the stand needs its own at
				-- all: deck centre to post top is 22.9 studs against a 12-stud reach.
				local deckAt = RangeData.standPosition(b.anchor, spot, LAYOUT, dir)
					+ Vector3.new(0, b.deckTops[spot] - b.anchor.Y, 0)
				expect((deckAt - highAt).Magnitude <= reach).to.equal(true)
				expect((deckAt - benchAt).Magnitude > reach).to.equal(true)
				expect(RangeData.atSpot(highAt, deckAt, LAYOUT)).to.equal(true)
				expect(RangeData.atSpot(benchAt, deckAt, LAYOUT)).to.equal(false)
				-- ...AND A MAN ON THE MAT CANNOT PRESS THE STAND'S ONE.
				local mat = RangeData.matPosition(b.anchor, spot, LAYOUT)
				expect(RangeData.atSpot(highAt, mat, LAYOUT)).to.equal(false)
			end
			-- NOR HIS NEIGHBOUR'S, which is what `SPOT_SPACING_STUDS` buys for the second prompt too.
			for spot = 1, LAYOUT.SPOT_COUNT do
				for other = 1, LAYOUT.SPOT_COUNT do
					if other ~= spot then
						expect((stand[other] - stand[spot]).Magnitude >= 2 * reach).to.equal(true)
					end
				end
			end
			parent:Destroy()
		end)

		-- THE MUST-FIX OF 306b NOTE (i) / 306c NOT PROVEN item 1 (step B6). The Hud asked
		-- `promptFor(1)`, so 11 of the 12 prompts opened nothing. `nearestPrompt` answers which one
		-- he is standing at, in ONE walk, and names the station AND the position.
		it("nearestPrompt finds all TWELVE: the bench at a mat, the deck's at a deck", function()
			local dir = 1
			local row = { x = DEV_ROW.x, z = DEV_ROW.z, y = DEV_ROW.y, plate = true, downrange = dir }
			local b, parent = buildInto(row, nil)
			local found: { [string]: boolean } = {}
			for spot = 1, LAYOUT.SPOT_COUNT do
				-- STANDING ON HIS MAT: his OWN bench prompt, and never a neighbour's and never the
				-- deck's -- the two reaches the case above measured apart.
				local mat = RangeData.matPosition(b.anchor, spot, LAYOUT)
				local prompt, atSpot, position = RangeData.nearestPrompt(mat, b.folder, LAYOUT)
				expect(prompt).to.be.ok()
				expect(atSpot).to.equal(spot)
				expect(position).to.equal(RangeData.POSITION.BENCH)
				expect(prompt).to.equal(RangeData.promptFor(spot, RangeData.POSITION.BENCH, b.folder))
				found[(prompt :: any).Name] = true

				-- ...AND ON HIS DECK, HIS OWN STAND PROMPT. This is the half that opened nothing at
				-- all: `promptFor(1)` cannot name a treestand prompt whatever the station.
				local deckAt = RangeData.standPosition(b.anchor, spot, LAYOUT, dir)
					+ Vector3.new(0, b.deckTops[spot] - b.anchor.Y, 0)
				local high, highSpot, highPosition = RangeData.nearestPrompt(deckAt, b.folder, LAYOUT)
				expect(highSpot).to.equal(spot)
				expect(highPosition).to.equal(RangeData.POSITION.TREESTAND)
				expect(high).to.equal(RangeData.promptFor(spot, RangeData.POSITION.TREESTAND, b.folder))
				found[(high :: any).Name] = true
			end
			-- ALL TWELVE WERE REACHED, counted: the number the note said was 1 of 12.
			local count = 0
			for _ in pairs(found) do
				count += 1
			end
			expect(count).to.equal(2 * LAYOUT.SPOT_COUNT)
			-- NO MEASUREMENT MEANS NO ANSWER, and no range means no answer: a Hud with no character
			-- yet must not bind an arbitrary station's prompt.
			expect((RangeData.nearestPrompt(nil, b.folder, LAYOUT))).to.equal(nil)
			local empty = Instance.new("Folder")
			expect((RangeData.nearestPrompt(RangeData.matPosition(b.anchor, 1, LAYOUT), empty, LAYOUT))).to.equal(nil)
			empty:Destroy()
			parent:Destroy()
		end)

		it("leaves a station whose ground REFUSES a seat with five stands, six benches and no deck top", function()
			local dir = 1
			local row = { x = DEV_ROW.x, z = DEV_ROW.z, plate = false, downrange = dir }
			-- STATION 3'S LADDER FOOT STANDS 5 STUDS HIGH, over `MAX_FOOT_SPREAD_STUDS` 4.0: the
			-- one ground `HighSeats.plan` refuses, read through the SAME injected seam her place
			-- uses. Everything else is flat.
			local badX = RangeData.standPosition(Vector3.new(DEV_ROW.x, 0, DEV_ROW.z), 3, LAYOUT, dir).X
			local b, parent = buildInto(row, function(x: number, z: number): number?
				if math.abs(x - badX) < 1 and z < DEV_ROW.z - LAYOUT.STAND.backStuds - 2 then
					return 5
				end
				return 0
			end)
			expect(b).to.be.ok()
			expect(b.stands).to.equal(LAYOUT.SPOT_COUNT - 1)
			expect(b.refusedStands).to.equal(1)
			expect(#b.standRefusals).to.equal(1)
			expect(string.match(b.standRefusals[1], "^3: spread") ~= nil).to.equal(true)
			expect(b.folder:FindFirstChild(RangeData.standName(3))).to.equal(nil)
			expect(b.deckTops[3]).to.equal(nil)
			expect(RangeData.promptFor(3, RangeData.POSITION.TREESTAND, b.folder)).to.equal(nil)
			-- ...AND HIS BENCH, HIS MAT AND HIS OWN PROMPT ARE ALL STILL THERE: a refused seat
			-- costs the station nothing but the second position.
			expect(b.folder:FindFirstChild(RangeData.benchName(3))).to.be.ok()
			expect(b.folder:FindFirstChild(RangeData.matName(3))).to.be.ok()
			expect(RangeData.promptFor(3, RangeData.POSITION.BENCH, b.folder)).to.be.ok()
			for spot = 1, LAYOUT.SPOT_COUNT do
				expect(b.folder:FindFirstChild(RangeData.benchName(spot))).to.be.ok()
				if spot ~= 3 then
					expect(b.deckTops[spot]).to.be.ok()
					expect(b.folder:FindFirstChild(RangeData.standName(spot))).to.be.ok()
				end
			end
			TestKit.note(string.format("range B3 refusal: %s", b.standRefusals[1]))
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
				-- ...and every order carried that pace's speed, never another's.
				for _, lead in ipairs(fake.leadsAt(1)) do
					expect(lead.speed).to.equal(asked)
				end
				table.insert(
					rows,
					string.format("%s %.2f s (predicted %.2f, %.1f %%)", pace, measured, predicted, err * 100)
				)
				Range.stop()
			end
			TestKit.note("range: measured crossings (T5) -- " .. table.concat(rows, " · "))
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

		it("clears a killed target after CARCASS_SECONDS and releases a fresh one after RELEASE_SECONDS", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now))).to.equal(true)
			advance(fake, clock, 2)
			expect(fake.spawns).to.equal(LAYOUT.SPOT_COUNT)
			local dead = fake.at(1) :: any
			dead.alive = false

			-- Under the hold, nothing is cleared: the player is looking at what he did.
			advance(fake, clock, Range.CONFIG.CARCASS_SECONDS - 1)
			expect(fake.clears).to.equal(0)
			expect(Range.stats().carcasses).to.equal(1)

			-- WHOSE ANIMALS THE OTHER FIVE STATIONS HAVE, before the carcass is cleared: the
			-- identities are compared after it, which is what "and only his" means.
			local othersBefore = {}
			for spot = 2, LAYOUT.SPOT_COUNT do
				othersBefore[spot] = (fake.at(spot) :: any).id
			end
			advance(fake, clock, 1.5)
			expect(fake.clears).to.equal(1)
			expect(fake.lastClear).to.equal("range carcass")
			expect(Range.stats().releases).to.equal(1)
			-- ...and the fresh one is not released instantly either.
			expect(fake.spawns).to.equal(LAYOUT.SPOT_COUNT)
			advance(fake, clock, Range.CONFIG.RELEASE_SECONDS + 0.5)
			-- ONE ANIMAL WENT AND ONE CAME BACK -- STEP B7's MUST-FIX 1. Until B7 this read
			-- `2 * SPOT_COUNT` spawns and `SPOT_COUNT - 1` lost targets, because `boars.clear` was
			-- range-WIDE and one man's carcass took the other five stations' animals with it. The
			-- lever is `Boar.Runtime:clearOne`, wired as `boars.clearOne`.
			expect(fake.spawns).to.equal(LAYOUT.SPOT_COUNT + 1)
			expect(fake.clearOnes).to.equal(1)
			expect(Range.stats().lostTargets).to.equal(0)
			expect(Range.stats().wideClears).to.equal(0)
			expect((fake.at(1) :: any).alive).to.equal(true)
			-- THE OTHER FIVE ARE THE SAME ANIMALS, not re-released copies.
			for spot = 2, LAYOUT.SPOT_COUNT do
				expect((fake.at(spot) :: any).id).to.equal(othersBefore[spot])
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
			local animal = fake.at(1) :: any
			fake.flyingIds[animal.id] = true
			local leadsBefore = #fake.leadsAt(1)
			local skippedBefore = Range.stats().skippedFlying
			advance(fake, clock, 3)
			-- IT ENTERED THE BRANCH, and issued nothing: *"the drive must not order an animal the
			-- Brain is flying"*.
			expect(Range.stats().skippedFlying > skippedBefore).to.equal(true)
			expect(#fake.leadsAt(1)).to.equal(leadsBefore)
			-- ...and it picks the lane up again when the flight ends.
			fake.flyingIds[animal.id] = false
			advance(fake, clock, 2)
			expect(#fake.leadsAt(1) > leadsBefore).to.equal(true)
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
			-- Two full minutes of scanning, which is 60 x `RELEASE_SECONDS`.
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
			local anchorXZ = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local end2 = RangeData.laneEnds(anchorXZ, LAYOUT, 2, nil, 2, LAYOUT.DISTANCE_STUDS)
			local end1 = RangeData.laneEnds(anchorXZ, LAYOUT, 2, nil, 1, LAYOUT.DISTANCE_STUDS)
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
			local his = (fake.at(2) :: any).id
			local hers = (fake.at(4) :: any).id
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
			expect(Range.stats().idleClears).to.equal(1)
			expect(fake.clearOnes).to.equal(1)
			expect(fake.lastClear).to.equal("range idle")
			expect(Range.stats().wideClears).to.equal(0)
			-- STATION 4 IS UNAFFECTED: the same animal, still steered.
			expect(fake.at(4)).to.be.ok()
			expect((fake.at(4) :: any).id).to.equal(hers)
			expect(Range.stats().targets).to.equal(1)
			local leadsBefore = #fake.leadsAt(4)
			advance(fake, clock, 5)
			expect(#fake.leadsAt(4) > leadsBefore).to.equal(true)
			-- AND NOTHING IS RE-RELEASED AT THE STATION HE LEFT.
			expect(fake.spawns).to.equal(2)
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
			crowd.set({ 1 })
			advance(fake, clock, Range.CONFIG.IDLE_CLEAR_SECONDS + 1)
			expect(Range.stats().idleClears).to.equal(1)
			expect(Range.stats().wideClears).to.equal(1)
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
		it("is TRUE on the deck, measures TREESTAND there, and tallies the longer distance", function()
			Range.stop()
			local _, now = newClock()
			expect(startRange(newFakeBoars(), now)).to.equal(true)
			-- WHAT THE BUILD MEASURED, not a number this spec types.
			local tops = Range.deckTops()
			expect(tops[1]).to.be.ok()
			local deck = RangeData.standPosition(ANCHOR, 1, LAYOUT, 1)
			local up = manAt(Vector3.new(deck.X, tops[1] + 3.5, deck.Z))
			up.UserId = 306306
			expect(Range.mayShoot(up)).to.equal(true)
			local spot, position = Range.positionOf(up)
			expect(spot).to.equal(1)
			expect(position).to.equal(RangeData.POSITION.TREESTAND)
			Range.onShotResolved({ shooter = up })
			local onStand = Range.recordOf(up)
			expect(onStand.position).to.equal(RangeData.POSITION.TREESTAND)
			expect(onStand.distanceStuds).to.equal(LAYOUT.DISTANCE_STUDS + LAYOUT.STAND.backStuds)
			expect(onStand.shots).to.equal(1)

			-- HE CLIMBS DOWN: the SAME station and the SAME trial, but the bench's own distance and
			-- a FRESH tally, because both lead numbers are different numbers (design 9.4).
			local down = manAt(RangeData.matPosition(ANCHOR, 1, LAYOUT))
			down.UserId = 306306
			expect(select(2, Range.positionOf(down))).to.equal(RangeData.POSITION.BENCH)
			Range.onShotResolved({ shooter = down })
			local onBench = Range.recordOf(down)
			expect(onBench.position).to.equal(RangeData.POSITION.BENCH)
			expect(onBench.distanceStuds).to.equal(LAYOUT.DISTANCE_STUDS)
			expect(onBench.shots).to.equal(1)
			expect(onBench.spot).to.equal(1)

			-- UNDER THE DECK: at the station, so he keeps his gun, on NEITHER position -- and the
			-- board prints no position rather than guessing one.
			local below = manAt(Vector3.new(deck.X, tops[1] - 1, deck.Z))
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
					"range B3 server: deck top %.1f, stand %d studs vs bench %d studs",
					tops[1],
					onStand.distanceStuds,
					onBench.distanceStuds
				)
			)
			Range.forget(up)
			Range.stop()
			-- AND THE DECK TOPS GO WITH THE RANGE: nothing stale answers "on the stand".
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
			-- HE IS AT THE RANGE: one pick makes his record, which is the board's audience.
			expect(Range.onRequest(man, { spot = 2, go = true })).to.equal(true)
			expect(#sent).to.equal(1)
			local first = sent[1].record.mine
			expect(first).to.equal(fake.at(2).root)
			expect(sent[1].record.window.minX).to.equal((RangeData.windowSpanFor(ANCHOR, 2, LAYOUT)))

			-- EVERY TRUNK REPLACED AT ONCE, which is exactly what one man's carcass does to all six.
			fake.clear("spec re-release")
			advance(fake, clock, Range.CONFIG.RELEASE_SECONDS + 1)
			-- HE WAS TOLD, without firing a shot: a payload arrived after the pick...
			expect(#sent > 1).to.equal(true)
			local last = sent[#sent].record.mine
			expect(last).to.equal(fake.at(2).root)
			-- ...AND IT NAMES A NEW INSTANCE. A case that passed with the old trunk would prove
			-- nothing about the push.
			expect(last).never.to.equal(first)

			-- ...AND THE FLUSH IS ONCE A TICK, not once per release: six trials re-release together,
			-- so an unbatched push would be six per man per edge.
			local before = #sent
			fake.clear("spec re-release 2")
			advance(fake, clock, Range.CONFIG.RELEASE_SECONDS + 1)
			expect(sent[#sent].record.mine).to.equal(fake.at(2).root)
			expect(#sent - before <= LAYOUT.SPOT_COUNT).to.equal(true)

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
		local MEASURED = { minX = 2532, maxX = 2788, minZ = -3238, maxZ = -2998 }
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
						or part.Name:match("^FenceRail%d") ~= nil
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
							elseif
								part.Name:match("^Bench%d")
							then LAYOUT.BENCH.size.Y -- the fence's posts ARE laid by `onGround` (step B10), so they belong in							-- this rule -- with their OWN height and not the bank's.


							elseif part.Name:match("^FencePost%d") then LAYOUT.FENCE.postRise
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
					bermZ = Range.Build.bermBoxes(anchor, b.shelf, LAYOUT, case.dir)[1].at.Position.Z
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
			for _, boxen in ipairs(Range.Build.bermBoxes(anchor, b.shelf, LAYOUT, -1)) do
				local at, size = boxen.at.Position, boxen.size
				expect(at.X - size.X / 2 >= MEASURED.minX).to.equal(true)
				expect(at.X + size.X / 2 <= MEASURED.maxX).to.equal(true)
				expect(at.Z - size.Z / 2 >= MEASURED.minZ).to.equal(true)
				expect(at.Z + size.Z / 2 <= MEASURED.maxZ).to.equal(true)
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
			local rec = { fills = {}, replaces = {} }
			function rec:FillBlock(at: CFrame, size: Vector3, material: Enum.Material)
				table.insert(rec.fills, { at = at, size = size, material = material })
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
			expect(b.terrainFills).to.equal(#terrain.fills)
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
			local heaps = {}
			local function anchorOf(at)
				return Vector3.new((FOREST_ROW :: any).x, at.shelf, (FOREST_ROW :: any).z)
			end
			for _, call in ipairs(terrain.fills) do
				local bottom = call.at.Position.Y - call.size.Y / 2
				local top = call.at.Position.Y + call.size.Y / 2
				if call.material == Enum.Material.Air then
					expect(math.abs(bottom - math.floor(b.shelf / grid) * grid) < 1e-6).to.equal(true)
					expect(top >= b.shelf + LAYOUT.FILL.CLEAR_STUDS - 1e-6).to.equal(true)
				elseif top <= b.shelf + 1e-6 then
					expect(math.abs(bottom - (b.shelf - LAYOUT.FILL.DEPTH_STUDS)) < 1e-6).to.equal(true)
				else
					-- A HEAP: it stands ON the terrace, never in a hole and never in the air (rule E).
					expect(math.abs(bottom - b.shelf) < 1e-6).to.equal(true)
					heaps[string.format("%.3f|%.3f", top, call.at.Position.Z)] = true
				end
			end
			-- EVERY HEAP IS ONE THE OWNER PREDICTS, AND EVERY PREDICTED ONE WAS FILLED. Counting the
			-- calls would count CHUNKS -- a 232-stud berm is four of them at `CHUNK_STUDS` 64 -- so the
			-- set is keyed on what a heap IS: its top and where it stands. The two banks share both.
			local wanted = {}
			for _, box in ipairs(Range.Build.bermBoxes(anchorOf(b), b.shelf, LAYOUT, -1)) do
				wanted[string.format("%.3f|%.3f", box.at.Position.Y + box.size.Y / 2, box.at.Position.Z)] = true
			end
			for leg = 1, 2 do
				local bank = RangeData.bankPosition(anchorOf(b), LAYOUT, leg, -1)
				wanted[string.format("%.3f|%.3f", b.shelf + LAYOUT.BANK.size.Y, bank.Z)] = true
			end
			local seen, want = 0, 0
			for key in pairs(heaps) do
				expect(wanted[key]).to.equal(true)
				seen += 1
			end
			for _ in pairs(wanted) do
				want += 1
			end
			expect(seen).to.equal(want)
			expect(want).to.equal(1 + LAYOUT.BERM.slopeSteps + 1)
			parent:Destroy()
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
			expect(#rects).to.equal(2)
			local overlap = 0
			for _, rect in ipairs(rects) do
				local dx = math.min(rect.maxX, LOBBY_ANCHOR.x + half) - math.max(rect.minX, LOBBY_ANCHOR.x - half)
				local dz = math.min(rect.maxZ, LOBBY_ANCHOR.z + half) - math.max(rect.minZ, LOBBY_ANCHOR.z - half)
				if dx > 0 and dz > 0 then
					overlap += dx * dz
				end
			end
			expect(overlap).to.equal(0)
			-- ...AND A ROW WITHOUT `keepOut` GETS ONE RECTANGLE and the same arithmetic: the split is
			-- data, not a branch, and the one-rectangle arm is entered here rather than assumed.
			local plain = table.clone(FOREST_ROW :: any)
			plain.keepOut = nil
			local one = RangeData.cutRects(anchor, LAYOUT, -1, plain)
			expect(#one).to.equal(1)
			expect(one[1].maxX > rects[2].maxX).to.equal(true)
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
				expect(covered).to.equal(true)
			end
			parent:Destroy()
		end)

		it("fills a berm with a battered uprange face and ONE level crest, and two banks on the flat", function()
			local anchor = Vector3.new((FOREST_ROW :: any).x, FOREST_SHELF, (FOREST_ROW :: any).z)
			local boxes = Range.Build.bermBoxes(anchor, FOREST_SHELF, LAYOUT, -1)
			expect(#boxes).to.equal(1 + LAYOUT.BERM.slopeSteps)
			-- EVERY BAND STANDS FROM THE TERRACE, so the heap is solid and nothing floats (rule E).
			for _, box in ipairs(boxes) do
				expect(math.abs((box.at.Position.Y - box.size.Y / 2) - FOREST_SHELF) < 1e-6).to.equal(true)
			end
			-- THE CREST IS THE CORE'S, one level line at the design's 10 studs, and no band reaches it.
			expect(math.abs(boxes[1].size.Y - LAYOUT.BERM.height) < 1e-6).to.equal(true)
			local nearFace = RangeData.bermPosition(anchor, LAYOUT, -1).Z + LAYOUT.BERM.depth / 2
			local lastReach, lastTop = -math.huge, math.huge
			for index = 2, #boxes do
				local box = boxes[index]
				local top = box.at.Position.Y + box.size.Y / 2
				expect(top < FOREST_SHELF + LAYOUT.BERM.height - 1e-6).to.equal(true)
				-- A BATTER AND NOT A WALL: each higher band reaches LESS far uprange than the one below.
				local reach = (box.at.Position.Z + box.size.Z / 2) - nearFace
				expect(reach > 0).to.equal(true)
				if index > 2 then
					expect(reach < lastReach).to.equal(true)
					expect(top > lastTop).to.equal(true)
				end
				lastReach, lastTop = reach, top
			end
			-- ...AND THE SLOPE'S TOE IS THE DESIGNED RUN, so "1:1.2" is a number and not a word.
			expect(math.abs(((boxes[2].at.Position.Z + boxes[2].size.Z / 2) - nearFace) - LAYOUT.BERM.slopeRun) < 1e-6).to.equal(
				true
			)
			-- THE BANKS ARE FILLED WHERE THE PARTS WOULD HAVE STOOD -- one answer to "where is a bank".
			local _, _, parent, terrain = buildOnTerrain(FOREST_ROW, slopedGround)
			for leg = 1, 2 do
				local at = RangeData.bankPosition(anchor, LAYOUT, leg, -1)
				local found = false
				for _, call in ipairs(terrain.fills) do
					if
						math.abs(call.at.Position.X - at.X) < 1e-6
						and math.abs(call.at.Position.Z - at.Z) < 1e-6
						and math.abs(call.size.Y - LAYOUT.BANK.size.Y) < 1e-6
					then
						found = true
					end
				end
				expect(found).to.equal(true)
			end
			parent:Destroy()
		end)

		it("paints the mown lane, then the firing line over every mat, post and bench", function()
			local built, _, parent, terrain = buildOnTerrain(FOREST_ROW, slopedGround)
			local b = built :: any
			expect(#terrain.replaces).to.equal(3) -- two terrace rectangles, then the line
			for _, call in ipairs(terrain.replaces) do
				-- `ReplaceMaterial` takes the voxel resolution and nothing else (task 244).
				expect(call.resolution).to.equal(LAYOUT.FILL.GRID_STUDS)
			end
			local last = terrain.replaces[#terrain.replaces]
			-- THE LINE LAST. Not because the lane's repaint could undo it -- that one is AROUND -> LANE
			-- and cannot touch `Limestone` -- but because the order is the one the owner states, and a
			-- repaint aimed at LANE must run after everything that writes LANE (review round 1, note).
			expect(last.from).to.equal(LAYOUT.SURFACE.LANE)
			expect(last.to).to.equal(LAYOUT.SURFACE.LINE)
			for index = 1, #terrain.replaces - 1 do
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
			expect(LAYOUT.BERM.height).to.equal(10)
			expect(LAYOUT.BERM.depth).to.equal(8)
			expect(LAYOUT.BERM.behindStuds).to.equal(13)
			expect(LAYOUT.BANK.size).to.equal(Vector3.new(12, 8, 14))
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
			expect(RangeData.bermSizeFor(LAYOUT)).to.equal(Vector3.new(232, 10, 8))
			expect(RangeData.bermPosition(anchor, LAYOUT, 1)).to.equal(Vector3.new(60, 100, 192))
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
					for _, at in ipairs(RangeData.hutPostPositions(anchor, spot, LAYOUT, dir)) do
						-- its own downrange offset from the mat, and the widest ray at that offset
						local ahead = (at.z - mat.Z) * dir
						local clear = RangeData.sightHalfWidthAt(LAYOUT, ahead)
						-- an UPRANGE post is behind the shooter and cannot be in front of him
						if ahead > 0 then
							expect(math.abs(at.x - mat.X) > clear + hut.postSection / 2).to.equal(true)
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
			-- the bound itself is real arithmetic and not a constant: 9.6 degrees at the short lane
			expect(RangeData.sightHalfWidthAt(LAYOUT, 0)).to.equal(0)
			expect(math.abs(RangeData.sightHalfWidthAt(LAYOUT, 107) - 18) < 1e-6).to.equal(true)
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
			expect(rect.minZ >= math.min(line.minZ, line.maxZ)).to.equal(true)
			expect(math.abs(rect.maxZ - (berm.Z - dir * LAYOUT.BERM.depth / 2)) < 1e-6).to.equal(true)
			-- its TOP is just proud of the shelf, so no voxel shows through and nothing floats
			local top = (turf :: any).Position.Y + (turf :: any).Size.Y / 2
			expect(math.abs(top - ((built :: any).shelf + LAYOUT.TURF.liftStuds)) < 1e-6).to.equal(true)
			-- AND THE LANE'S OWN GROUND IS STILL BLADE-FREE: B8's measured reason stands.
			expect(LAYOUT.SURFACE.LANE).to.equal(Enum.Material.Ground)
			-- ...while the berm and the banks are GRASSED (Karen's "earth formed mountain").
			expect(LAYOUT.SURFACE.BERM).to.equal(Enum.Material.Grass)
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

		-- L5 (and L-093: a case that actually ENTERS each new arm). THE WAY UP AND THE WAY DOWN,
		-- driven through the owner with a fake body -- both branches, and the refusals.
		it("climbs a man onto the deck and back down again, by station", function()
			local parent = Instance.new("Folder")
			local clock, now = newClock()
			local moved: { CFrame } = {}
			local shelf = 140
			local ok = Range.start({
				enabled = true,
				anchor = { x = 0, z = 0, y = shelf, plate = true },
				root = parent,
				now = now,
				groundAt = function()
					return shelf
				end,
				move = function(_who, cframe)
					table.insert(moved, cframe)
					return true
				end,
			})
			expect(ok).to.equal(true)
			local anchor = Range.stats().parts and Vector3.new(0, shelf, 0) or nil
			expect(anchor).to.be.ok()

			-- THE WAY UP: onto station 4's deck, `CLIMB.riseStuds` over its top face.
			local deckTops = Range.deckTops()
			expect(deckTops[4]).to.be.ok()
			expect(Range.onClimb({ Name = "a" }, 4)).to.equal(true)
			expect(#moved).to.equal(1)
			local up = moved[1]
			local deck = RangeData.standPosition(anchor :: Vector3, 4, LAYOUT, 1)
			expect(math.abs(up.Position.X - deck.X) < 1e-4).to.equal(true)
			expect(math.abs(up.Position.Z - deck.Z) < 1e-4).to.equal(true)
			expect(math.abs(up.Position.Y - (deckTops[4] + LAYOUT.CLIMB.riseStuds)) < 1e-4).to.equal(true)
			-- A MAN AT THAT POINT IS ON THE STAND, by the server's OWN rule -- which is what the
			-- climb is for, and it would be false for a point one stud off the deck.
			local spotUp, wordUp = Range.spotAt(up.Position)
			expect(spotUp).to.equal(4)
			expect(wordUp).to.equal(RangeData.POSITION.TREESTAND)

			-- THE WAY DOWN: at the ladder's foot, on the measured ground, and NOT on the stand.
			expect(Range.onClimbDown({ Name = "a" }, 4)).to.equal(true)
			expect(#moved).to.equal(2)
			local down = moved[2]
			expect(math.abs(down.Position.Y - (shelf + LAYOUT.CLIMB.riseStuds)) < 1e-4).to.equal(true)
			local foot = RangeData.ladderFootPosition(anchor :: Vector3, 4, LAYOUT, 1)
			expect(math.abs(down.Position.X - foot.X) < 1e-4).to.equal(true)
			local _spotDown, wordDown = Range.spotAt(down.Position)
			expect(wordDown).never.to.equal(RangeData.POSITION.TREESTAND)

			-- BOTH ARMS COUNTED, and a refusal is a refusal: no station 0, no station 9.
			expect(Range.onClimb({ Name = "a" }, 99)).to.equal(false)
			expect(Range.onClimbDown({ Name = "a" }, 0)).to.equal(false)
			expect(Range.stats().climbsUp).to.equal(1)
			expect(Range.stats().climbsDown).to.equal(1)
			expect(Range.stats().climbsRefused).to.equal(2)
			-- ...AND A MOVER THAT SAYS NO IS NOT A CLIMB. The seam's false must not be counted as
			-- a success, which is the shape a "did not raise" counter gets wrong.
			Range.stop()
			local refused = Range.start({
				enabled = true,
				anchor = { x = 0, z = 0, y = shelf, plate = true },
				root = Instance.new("Folder"),
				now = now,
				move = function()
					return false
				end,
			})
			expect(refused).to.equal(true)
			expect(Range.onClimb({ Name = "a" }, 2)).to.equal(false)
			expect(Range.stats().climbsUp).to.equal(0)
			expect(Range.stats().climbsRefused).to.equal(1)
			Range.stop()
			clock.t = 0
		end)

		-- THE PROMPTS THEMSELVES: two per station, with the two KEYS that the deck's own crowding
		-- forces apart, and `wireClimbs` finds all twelve.
		it("hangs a Climb on E at the ladder foot and a Climb down on F on the deck", function()
			local parent = Instance.new("Folder")
			local built = Range.Build.build({ parent = parent, row = DEV_ROW, layout = LAYOUT })
			local folder = (built :: any).folder
			local anchor = (built :: any).anchor
			local dir = (built :: any).downrange
			local found: { [string]: any } = {}
			for _, child in ipairs(folder:GetDescendants()) do
				if child:IsA("ProximityPrompt") then
					found[child.Name] = child
				end
			end
			for spot = 1, LAYOUT.SPOT_COUNT do
				local upPrompt = found[RangeData.climbPromptName(spot, "up")]
				local downPrompt = found[RangeData.climbPromptName(spot, "down")]
				expect(upPrompt).to.be.ok()
				expect(downPrompt).to.be.ok()
				expect((upPrompt :: any).ActionText).to.equal(LAYOUT.CLIMB.UP_ACTION)
				expect((downPrompt :: any).ActionText).to.equal(LAYOUT.CLIMB.DOWN_ACTION)
				expect((upPrompt :: any).KeyboardKeyCode).to.equal(Enum.KeyCode.E)
				expect((downPrompt :: any).KeyboardKeyCode).to.equal(Enum.KeyCode.F)
				-- THE WAY UP IS AT THE LADDER'S FOOT: its world point is the arithmetic's, so the
				-- screen's claim and the built world are about ONE point.
				local point = RangeData.promptPointOf(upPrompt)
				local want = RangeData.climbPromptPosition(anchor, spot, LAYOUT, dir)
				expect(point).to.be.ok()
				expect(((point :: Vector3) - want).Magnitude < 1e-3).to.equal(true)
				-- AND THE TWO KEYS HAD TO DIFFER: the down prompt and the station's RANGE prompt are
				-- BOTH within `MaxActivationDistance` of a man on the deck, and `Exclusivity` shows
				-- one prompt per key. This is that measurement, as a case.
				local downPoint = RangeData.promptPointOf(downPrompt)
				local menuPoint =
					RangeData.promptPointOf(found[RangeData.promptName(spot, RangeData.POSITION.TREESTAND)])
				expect(downPoint).to.be.ok()
				expect(menuPoint).to.be.ok()
				local apart = ((downPoint :: Vector3) - (menuPoint :: Vector3)).Magnitude
				expect(apart < LAYOUT.PROMPT.MaxActivationDistance).to.equal(true)
				expect((downPrompt :: any).KeyboardKeyCode).never.to.equal((upPrompt :: any).KeyboardKeyCode)
			end
			-- `wireClimbs` FINDS ALL TWELVE, which is the number the console line prints.
			expect(Range.wireClimbs(folder)).to.equal(2 * LAYOUT.SPOT_COUNT)
			expect(Range.wireClimbs(nil)).to.equal(0)
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
			for run = 1, #runs do
				expect(folder:FindFirstChild(RangeData.fencePostName(run, 1))).to.be.ok()
				expect(folder:FindFirstChild(RangeData.fenceRailName(run))).to.be.ok()
			end
			-- HER PLACE'S TERRACE IS TWO RECTANGLES, and the far side has no ground to stand on in
			-- the narrow one -- so the runs are NOT simply two there, and that arm is entered here
			-- rather than assumed. A post over the lip of a terrace is the defect, not a short fence.
			local forestAnchor = Vector3.new((FOREST_ROW :: any).x, 148, (FOREST_ROW :: any).z)
			local forestCuts = RangeData.cutRects(forestAnchor, LAYOUT, -1, FOREST_ROW)
			expect(#forestCuts).to.equal(2)
			for _, run in ipairs(RangeData.fenceRuns(forestAnchor, LAYOUT, -1, FOREST_ROW)) do
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
					"range B10: %d parts dressed (budget %d), %d fence posts, worst foot %.2f studs",
					parts,
					Range.CONFIG.MAX_PARTS,
					#posts,
					worst
				)
			)
		end)
	end)
end
