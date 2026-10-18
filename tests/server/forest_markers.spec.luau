-- forest_markers.spec: THE FOREST'S MARKER SET -- and, first, that it can say NO (task 157).
--
-- THE HARNESS RUNS IN THE DEV PLACE, and that is what makes the most important case here free: there
-- is no terrain under this world's coordinates (x ~ 3030, z ~ -2097) in DEV, so
-- `ForestTest.Markers.build` with its real readers measures nothing, refuses all nine stands, builds
-- NO part and answers `complete = false` with the reasons named. That is the guard against the audit
-- in `docs/PROJECT_CONTEXT.md` that *"certified a blank screen twice"*: a set that could only ever
-- say yes would be a drive standing on a world nobody checked. `forest_stand.spec`'s own header
-- already relies on the same absence of terrain.
--
-- EVERYTHING ELSE IS DRIVEN WITH INJECTED GROUND READERS, which is the "reachable by parameter"
-- rule applied to a raycast: `build(standX, ground, canopy)` takes both, so the nine stands, the
-- line, the beater pad, the tolerance and the refusal are all assertable with hand-written numbers
-- and no forest.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/forest-drive.md (sections 4.1, 13.1)
-- Note:   docs/research/2026-10-11-forest-drive.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Markers = ForestTest.Markers

-- A FLAT WORLD AT A KNOWN HEIGHT, for the cases that are about the arithmetic and not about terrain.
local FLAT_Y = 140
local function flat(_x: number, _z: number): number?
	return FLAT_Y
end
local function nothing(_x: number, _z: number): number?
	return nil
end

local function hasMissing(set, needle: string): boolean
	for _, reason in ipairs(set.missing) do
		if string.find(reason, needle, 1, true) then
			return true
		end
	end
	return false
end

local function partsInFolder(): number
	local folder = Markers.folder()
	if folder == nil then
		return 0
	end
	local n = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return function()
	-- A PERSON STANDING ON A MARKER'S SPOT DOES NOT MOVE THE GROUND (task 158a(f)).
	--
	-- THE DEFECT THIS FAILS ON, measured in the Forest Test on 2026-10-11: `Data.groundAt`'s ray
	-- excluded `OurForest`, `Foliage` and `Boars` and NOTHING ELSE, so at the beater pad -- where the
	-- drive PUTS a beater and now holds her -- it stopped on `<player>.Head` at y 161.09 while the
	-- terrain was 155.81. `Markers.groundFor` compares the two readings against
	-- `GROUND_TOLERANCE_STUDS` (1), so 5.3 studs refused `forest:beater-start`, and the world sat in
	-- `Waiting` for ever after its first drive.
	--
	-- IT RUNS IN THE DEV PLACE, where there is no terrain under this world's coordinates, so the
	-- fixture IS the ground: one anchored slab, and a rig standing on it. On the old code the first
	-- case reads the rig's head; on this one it reads the slab.
	describe("the ground, with somebody standing on it", function()
		local folder: Folder
		local SLAB_TOP = 140
		local X, Z = 11000, 11000 -- far from anything this place holds, so the slab is the only hit

		local function rig(at: Vector3): Model
			local model = Instance.new("Model")
			model.Name = "GroundRig"
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			root.Position = at
			root.Anchored = true
			root.Parent = model
			local head = Instance.new("Part")
			head.Name = "Head"
			head.Size = Vector3.new(2, 1, 1)
			head.Position = at + Vector3.new(0, 1.5, 0)
			head.Anchored = true
			head.Parent = model
			model.PrimaryPart = root
			return model
		end

		beforeAll(function()
			folder = Instance.new("Folder")
			folder.Name = "ForestGroundSpec"
			local slab = Instance.new("Part")
			slab.Name = "Slab"
			slab.Size = Vector3.new(40, 4, 40)
			slab.Position = Vector3.new(X, SLAB_TOP - 2, Z) -- its TOP face is SLAB_TOP
			slab.Anchored = true
			slab.Parent = folder
			folder.Parent = workspace
		end)

		afterAll(function()
			folder:Destroy()
		end)

		it("reads the slab with nobody on it", function()
			expect(Data.groundAt(X, Z)).to.equal(SLAB_TOP)
		end)

		it("STILL reads the slab with a character standing on it -- head, body and all", function()
			local body = rig(Vector3.new(X, SLAB_TOP + 3, Z))
			body.Parent = folder
			local answer = Data.groundAt(X, Z)
			print(string.format("[forest_markers] ground with a body on it: %s (slab %d)", tostring(answer), SLAB_TOP))
			expect(answer).to.equal(SLAB_TOP)
			body:Destroy()
		end)

		it("skips a HAT too, which a parent-only test would call the ground", function()
			-- A hat's `Handle` is parented to an `Accessory`, which is parented to the character, so
			-- the hit's immediate parent has no Humanoid. `Data.characterOf` walks up; the old
			-- inline test did not.
			local body = rig(Vector3.new(X, SLAB_TOP + 3, Z))
			local accessory = Instance.new("Accessory")
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(2, 1, 2)
			handle.Position = Vector3.new(X, SLAB_TOP + 7, Z)
			handle.Anchored = true
			handle.Parent = accessory
			accessory.Parent = body
			body.Parent = folder
			expect(Data.characterOf(handle)).to.equal(body)
			expect(Data.groundAt(X, Z)).to.equal(SLAB_TOP)
			body:Destroy()
		end)

		it("answers nil where there is nothing at all, which is what a refusal is made of", function()
			expect(Data.groundAt(X + 5000, Z + 5000)).to.equal(nil)
			-- ...and a ray that only ever finds bodies gives up rather than looping: the slab is not
			-- under this column, so every hit is a character and the bound is what ends it.
			local tower = {}
			for index = 1, 3 do
				local body = rig(Vector3.new(X + 5000, SLAB_TOP + index * 10, Z + 5000))
				body.Parent = folder
				table.insert(tower, body)
			end
			expect(Data.groundAt(X + 5000, Z + 5000)).to.equal(nil)
			for _, body in ipairs(tower) do
				body:Destroy()
			end
		end)

		it("is the ONE rule: characterOf says no to the world and yes to a person", function()
			expect(Data.characterOf(nil)).to.equal(nil)
			expect(Data.characterOf(workspace.Terrain)).to.equal(nil)
			local body = rig(Vector3.new(X, SLAB_TOP + 3, Z))
			body.Parent = folder
			expect(Data.characterOf(body.PrimaryPart)).to.equal(body)
			expect(Data.characterOf(body)).to.equal(body)
			body:Destroy()
			TestKit.note("forest-markers: one rule for what a person is (Data.characterOf), three callers")
		end)
	end)

	describe("it can say no", function()
		it("refuses every stand where there is no ground, and builds nothing", function()
			Markers.clear()
			-- THE REAL READERS, in the DEV place: no terrain under the forest's coordinates.
			local set = Markers.build(Data.standX(Data.PICK.defaultIndex), Data.ROAD_LAYOUT)
			expect(#set.posts).to.equal(0)
			expect(set.complete).to.equal(false)
			expect(hasMissing(set, "forest:stands")).to.equal(true)
			expect(hasMissing(set, string.format("0 of %d", Data.ROAD_LAYOUT.standCount))).to.equal(true)
			expect(Markers.folder()).to.equal(nil) -- not one Instance created
			expect(Markers.stats().refused).to.equal(Data.ROAD_LAYOUT.standCount)
			TestKit.note(string.format("forest-markers: %s", table.concat(set.missing, ", ")))
		end)

		it("is the shape Match consumes, so the Hud says WHY it is waiting", function()
			-- The drive stays in `Waiting` while `complete` is false, and `Phase.waitingFor` passes
			-- these strings to the snapshot the drive bar prints. No client change: the Hud already
			-- renders `waitingFor`.
			local set = Markers.build(0, Data.ROAD_LAYOUT, nothing, nothing)
			local state = Match.Phase.initial(Match.CONFIG)
			state = Match.Phase.step(state, {
				kind = "markers",
				complete = set.complete,
				missing = set.missing,
				boarSpawns = set.boarSpawns,
			}, 0, Match.CONFIG)
			expect(state.phase).to.equal("Waiting")
			local reasons = Match.Phase.waitingFor(state, Match.CONFIG)
			expect(#reasons >= 1).to.equal(true)
		end)
	end)

	describe("the set it builds on real ground", function()
		it("puts one part per stand, on the road, sorted west to east", function()
			local set = Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			expect(#set.posts).to.equal(Data.ROAD_LAYOUT.standCount)
			local worst = 0
			for index, post in ipairs(set.posts) do
				local stand = Data.standPosition(index)
				worst = math.max(worst, math.abs(post.Position.X - stand.X), math.abs(post.Position.Z - stand.Z))
				expect(post.Position.Y).to.equal(FLAT_Y)
				expect(post.Anchored).to.equal(true)
				-- A MARKER MUST NOT STOP A PELLET: what the shot hit is what the weapon reports and
				-- `Penalty.judge` reads.
				expect(post.CanQuery).to.equal(false)
				expect(post.CanCollide).to.equal(false)
				expect(post.Transparency).to.equal(1)
				if index > 1 then
					expect(post.Position.X > set.posts[index - 1].Position.X).to.equal(true)
				end
			end
			expect(worst < 1).to.equal(true)
			TestKit.note(string.format("forest-markers: 9 stands within %.4f studs of the curve", worst))
		end)

		it("is complete with no boar spawns and no trees, and both are decisions", function()
			local set = Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			expect(#set.boarSpawns).to.equal(0) -- the drive releases nothing here
			expect(#set.trees).to.equal(0) -- the forest tags no trunks; anchorFor falls back to posts
			expect(set.complete).to.equal(true)
			expect(#set.missing).to.equal(0)
			expect(set.spawnRadius).to.equal(Data.REST.spreadStuds)
		end)

		it("hands over ONE drive line, pointing at the drive side", function()
			local set = Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			expect(set.lineParts).to.equal(1)
			expect(set.line).to.be.ok()
			local line = set.line :: any
			expect(line.normal).to.equal(Vector3.zAxis) -- +Z: north, where the beaters are
			expect(math.abs(line.position.Z - Data.ROAD_LAYOUT.centre.Z) < 1e-3).to.equal(true)
			expect(math.abs(line.position.X - Data.ROAD_LAYOUT.centre.X) < 1e-3).to.equal(true)
		end)

		it("puts a hunter on her stand at the height the DEV world uses", function()
			local set = Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			-- Through `Body.placementFor`, which is the one rule in both worlds, and
			-- `standIndexFor(1)` -- the solo hunter's stand.
			local cframe = Match.Body.placementFor(set, "Shooters", ForestTest.standIndexFor(1), Match.CONFIG)
			expect(cframe).to.be.ok()
			local at = (cframe :: CFrame).Position
			local stand = Data.standPosition(Data.PICK.defaultIndex)
			expect(math.abs(at.X - stand.X) < 1e-3).to.equal(true)
			expect(math.abs(at.Y - (FLAT_Y + Markers.POST_SIZE.Y / 2 + Match.CONFIG.STAND_HEIGHT_STUDS)) < 1e-3).to.equal(
				true
			)
			-- Facing +Z: north, up the drive. (`ForestTest.DRIVE_BEARING_DEG` is 0.)
			expect((cframe :: CFrame).LookVector.Z > 0.99).to.equal(true)
		end)

		it("ties a punished hunter to the nearest stand, because there are no tagged trunks", function()
			local set = Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			local stand = Data.standPosition(7)
			local anchor = Match.Body.anchorFor(set, Vector3.new(stand.X, FLAT_Y, stand.Z + 5))
			expect(anchor).to.be.ok()
			expect((anchor :: BasePart).Name).to.equal("Stand7")
		end)
	end)

	-- ---------------------------------------------------------------- one set per layout (task 179)
	describe("the set it builds for EVERY drive layout", function()
		it("builds that layout's own stands, and says which layout it measured", function()
			-- KAREN, 2026-10-13: *"not all a time same place hunters standing"*. The marker set is
			-- what the drive stands on, so a layout the markers cannot build is a layout nobody can
			-- play. These cases run the real `build` over every layout in the table with hand-written
			-- ground readers, so a fourth layout added later is built here before it is played.
			for _, name in ipairs(Data.LAYOUT_ORDER) do
				local layout = Data.layoutNamed(name) :: any
				local set = Markers.build(Data.standX(1, layout), layout, flat, flat)
				expect(set.layout).to.equal(name)
				expect(#set.posts).to.equal(layout.standCount)
				expect(set.complete).to.equal(true)
				expect(set.lineParts).to.equal(1)
				expect(set.driverStart).to.be.ok()
				-- One part per stand, named for its index, sorted west to east, on that layout's line.
				local previousX = -math.huge
				for index, post in ipairs(set.posts) do
					local stand = Data.standPosition(index, layout)
					expect(post.Name).to.equal(string.format("Stand%d", index))
					expect(math.abs(post.Position.X - stand.X) < 1e-3).to.equal(true)
					expect(math.abs(post.Position.Z - stand.Z) < 1e-3).to.equal(true)
					expect(post.Position.X > previousX).to.equal(true)
					previousX = post.Position.X
				end
				-- The drive line sits ON the line at the layout's own centre, where the sine is 0 --
				-- and for a straight layout that is exact by construction rather than by arithmetic.
				local line = set.line :: any
				expect(math.abs(line.position.X - layout.centre.X) < 1e-3).to.equal(true)
				expect(math.abs(line.position.Z - Data.roadZ(layout.centre.X, layout)) < 1e-3).to.equal(true)
				-- THE FOLDER HOLDS ONE LAYOUT'S WORTH AND NEVER TWO: `build` destroys and rebuilds,
				-- so switching layouts cannot leave the previous one's posts in the world.
				expect(partsInFolder()).to.equal(layout.standCount + 1)
				TestKit.note(
					string.format("forest-markers: layout %s built %d stands + the beater pad", name, #set.posts)
				)
			end
		end)

		it("counts a refusal against the layout's own stand count", function()
			for _, name in ipairs(Data.LAYOUT_ORDER) do
				local layout = Data.layoutNamed(name) :: any
				local set = Markers.build(Data.standX(1, layout), layout, nothing, nothing)
				expect(#set.posts).to.equal(0)
				expect(set.complete).to.equal(false)
				expect(set.layout).to.equal(name)
				expect(hasMissing(set, string.format("0 of %d", layout.standCount))).to.equal(true)
				expect(Markers.stats().refused).to.equal(layout.standCount)
			end
		end)

		it("draws a ring on the stand of the layout it is given", function()
			for _, name in ipairs(Data.LAYOUT_ORDER) do
				local layout = Data.layoutNamed(name) :: any
				Markers.build(Data.standX(1, layout), layout, flat, flat)
				local radius = Data.PICK.standRadiusStuds
				local placed = Markers.ring(layout.standCount, radius, layout, flat, flat)
				expect(placed).to.equal(Markers.RING.SEGMENTS)
				local home = Data.standPosition(layout.standCount, layout)
				local folder = (Markers.folder() :: Folder):FindFirstChild(Markers.ringName(layout.standCount))
				expect(folder).to.be.ok()
				for _, segment in ipairs((folder :: Instance):GetChildren()) do
					local at = (segment :: BasePart).Position
					local flatOff = Vector2.new(at.X - home.X, at.Z - home.Z).Magnitude
					-- Every segment's middle is within its own chord error of the true circle.
					expect(math.abs(flatOff - radius) < 1).to.equal(true)
				end
				Markers.clearRings()
			end
		end)
	end)

	describe("the ground, asked twice", function()
		it("refuses a stand when the terrain and the canopy disagree by more than a stud", function()
			local function canopy(_x: number, _z: number): number?
				return FLAT_Y + Markers.GROUND_TOLERANCE_STUDS + 5 -- a ray that stopped on a branch
			end
			local set = Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, canopy)
			expect(#set.posts).to.equal(0)
			expect(set.complete).to.equal(false)
			expect(Markers.stats().refused).to.equal(Data.ROAD_LAYOUT.standCount)
			expect(Markers.stats().lastMaxDelta > Markers.GROUND_TOLERANCE_STUDS).to.equal(true)
		end)

		it("accepts a disagreement inside the tolerance", function()
			local function canopy(_x: number, _z: number): number?
				return FLAT_Y + Markers.GROUND_TOLERANCE_STUDS / 2
			end
			local set = Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, canopy)
			expect(#set.posts).to.equal(Data.ROAD_LAYOUT.standCount)
			expect(set.complete).to.equal(true)
		end)
	end)

	-- TASK 166. KAREN, 2026-10-12: *"we need boundries but not put back where it started"*. A
	-- boundary a player cannot see is a wall in the dark, so the circle he may walk in is DRAWN at
	-- exactly the radius `ForestTest.boundaryPoint` clamps to. These cases hold the ring to that
	-- radius, to its own ground readings, and to being replaced rather than stacked.
	describe("the stand's edge ring", function()
		local function ringOf(standIndex: number): Instance?
			local folder = Markers.folder()
			return folder and folder:FindFirstChild(Markers.ringName(standIndex))
		end

		it("lays its segments ON the circle, at the radius the boundary clamps to", function()
			Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			local radius = Data.PICK.standRadiusStuds
			local placed = Markers.ring(4, radius, Data.ROAD_LAYOUT, flat, flat)
			expect(placed).to.equal(Markers.RING.SEGMENTS)

			local ring = ringOf(4)
			expect(ring).to.be.ok()
			local home = Data.standPosition(4)
			local segments = 0
			for _, part in ipairs((ring :: Instance):GetChildren()) do
				expect(part:IsA("BasePart")).to.equal(true)
				local box = part :: BasePart
				segments += 1
				-- THE MIDDLE OF A CHORD IS SLIGHTLY INSIDE THE CIRCLE, and by a known amount:
				-- r*(1-cos(pi/n)) = 0.148 studs at r=12, n=20. So "on the circle" is asserted to
				-- that tolerance and not to a guess.
				local flatOut = Vector3.new(box.Position.X - home.X, 0, box.Position.Z - home.Z)
				local sag = radius * (1 - math.cos(math.pi / Markers.RING.SEGMENTS))
				expect(flatOut.Magnitude).to.be.near(radius - sag, 1e-3)
				-- ON ITS OWN GROUND READING, lifted clear of it so it cannot z-fight.
				expect(box.Position.Y).to.be.near(FLAT_Y + Markers.RING.LIFT_STUDS, 1e-3)
				-- A PELLET MUST PASS THROUGH IT -- the rule every marker in this folder follows,
				-- because what a shot hit is what the safety rule and the hit record read.
				expect(box.CanQuery).to.equal(false)
				expect(box.CanCollide).to.equal(false)
				expect(box.Anchored).to.equal(true)
				-- VISIBLE, which is the whole point of it, and subtle rather than a fence.
				expect(box.Transparency < 1).to.equal(true)
			end
			expect(segments).to.equal(Markers.RING.SEGMENTS)
			TestKit.note(
				string.format(
					"stand ring: %d segments at r=%.0f, chord %.2f studs, lift %.2f, transparency %.2f",
					segments,
					radius,
					2 * radius * math.sin(math.pi / Markers.RING.SEGMENTS),
					Markers.RING.LIFT_STUDS,
					Markers.RING.TRANSPARENCY
				)
			)
		end)

		it("is replaced and not stacked, and goes when it is cleared", function()
			Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			Markers.ring(2, Data.PICK.standRadiusStuds, Data.ROAD_LAYOUT, flat, flat)
			local first = #((ringOf(2) :: Instance):GetChildren())
			-- A RE-LOCK DRAWS AGAIN: one ring per stand, however many times it is asked for.
			Markers.ring(2, Data.PICK.standRadiusStuds, Data.ROAD_LAYOUT, flat, flat)
			expect(#((ringOf(2) :: Instance):GetChildren())).to.equal(first)

			-- A SECOND STAND IS A SECOND RING, so two hunters each see their own edge.
			Markers.ring(7, Data.PICK.standRadiusStuds, Data.ROAD_LAYOUT, flat, flat)
			expect(ringOf(7)).to.be.ok()
			expect(Markers.clearRings()).to.equal(2)
			expect(ringOf(2)).to.equal(nil)
			expect(ringOf(7)).to.equal(nil)
			-- ...AND THE STANDS THEMSELVES ARE UNTOUCHED BY ALL OF IT: the ring is a child folder,
			-- so the folder still holds exactly the nine posts and the pad.
			expect(partsInFolder()).to.equal(Data.ROAD_LAYOUT.standCount + 1)
			expect(Markers.clearRings()).to.equal(0)
		end)

		-- TASK 207. KAREN, 2026-10-18 ~14:20, on the road line's stand 6: *"and this is not circle is
		-- broken one"*. These three cases are the ones task 166's ring FAILS, and they are driven on
		-- a plane so the right answer is arithmetic rather than a reading of the placement code's
		-- own output. MEASURED against the pre-fix commit, on this same slope of 0.5 (26.6 degrees):
		-- worst joint 1.854 studs, worst slab buried 0.927, worst slab floating 0.967. On the real
		-- ground of Karen's four places, over all 25 stands: 2.48, 1.06 and 1.56, all at road 6.
		local SLOPE = 0.5
		local CROSS = 0.3
		local function hill(x: number, z: number): number?
			return FLAT_Y + SLOPE * (x - Data.standPosition(4).X) + CROSS * (z - Data.standPosition(4).Z)
		end

		-- THE LOWEST VISIBLE GEOMETRY OF A SEGMENT against the ground under EVERY footprint point
		-- (rule E), never the pivot: `u` runs the length of the box, `v` its width, and the sample is
		-- taken on the BOTTOM face.
		local function worstGroundError(ring: Instance, groundOf): (number, number)
			local buried, floating = -math.huge, -math.huge
			for _, child in ipairs(ring:GetChildren()) do
				local box = child :: BasePart
				for _, u in ipairs({ -0.5, -0.25, 0, 0.25, 0.5 }) do
					for _, v in ipairs({ -0.5, 0, 0.5 }) do
						local at = box.CFrame * Vector3.new(u * box.Size.X, -box.Size.Y / 2, v * box.Size.Z)
						local y = groundOf(at.X, at.Z) :: number
						buried = math.max(buried, y - at.Y)
						floating = math.max(floating, at.Y - y)
					end
				end
			end
			return buried, floating
		end

		-- EVERY JOINT, AS TWO NUMBERS, because one cannot tell an overlap from a gap (lesson L-086:
		-- a single distance of 0.12 reads the same whether the two ends passed each other or missed
		-- each other by the same amount). For each segment, its nearest successor is found, and then:
		--   * `overlap`  -- how far this segment's far end lies PAST its successor's near end, along
		--                   the successor's own axis. Positive means they overlap. SMALLEST wins.
		--   * `miss`     -- how far that far end lies OFF the successor's centre line. This is the
		--                   STEP, and task 166's level slabs on a slope answered 1.85 for it.
		local function worstJoints(ring: Instance): (number, number)
			local boxes = ring:GetChildren()
			local leastOverlap, worstMiss = math.huge, -math.huge
			for i = 1, #boxes do
				local a = boxes[i] :: BasePart
				local tip = a.CFrame * Vector3.new(a.Size.X / 2, 0, 0)
				local nearest, at = math.huge, nil
				for j = 1, #boxes do
					if j ~= i then
						local b = boxes[j] :: BasePart
						local start = b.CFrame * Vector3.new(-b.Size.X / 2, 0, 0)
						if (tip - start).Magnitude < nearest then
							nearest, at = (tip - start).Magnitude, b
						end
					end
				end
				if at ~= nil then
					local follower = at :: BasePart
					local offset = tip - follower.CFrame * Vector3.new(-follower.Size.X / 2, 0, 0)
					local along = offset:Dot(follower.CFrame.RightVector)
					leastOverlap = math.min(leastOverlap, along)
					worstMiss = math.max(worstMiss, (offset - follower.CFrame.RightVector * along).Magnitude)
				end
			end
			return leastOverlap, worstMiss
		end

		it("meets itself on a slope: every neighbour overlaps, so there is no gap and no step", function()
			Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			local radius = Data.PICK.standRadiusStuds
			expect(Markers.ring(4, radius, Data.ROAD_LAYOUT, hill, hill)).to.equal(Markers.RING.SEGMENTS)
			local ring = ringOf(4) :: Instance
			local overlap, miss = worstJoints(ring)
			-- THEY PASS EACH OTHER, so the joint is not merely small, and NO END IS OFF ITS
			-- NEIGHBOUR'S LINE -- which is the step task 166 could not avoid, because its two
			-- neighbours read the ground in two different places.
			expect(overlap > Markers.RING.OVERLAP_STUDS / 2).to.equal(true)
			expect(miss < 0.03).to.equal(true)
			TestKit.note(
				string.format(
					"stand ring on a slope of %.2f/%.2f: %d segments, least overlap %.3f, worst step %.3f studs (task 166: a 1.854-stud joint)",
					SLOPE,
					CROSS,
					#ring:GetChildren(),
					overlap,
					miss
				)
			)
			Markers.clearRings()
		end)

		it("lies ON the slope: no segment is buried in it and none floats over it", function()
			Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			Markers.ring(4, Data.PICK.standRadiusStuds, Data.ROAD_LAYOUT, hill, hill)
			local buried, floating = worstGroundError(ringOf(4) :: Instance, hill)
			-- NOTHING UNDER THE GROUND AT ALL, and nothing further over it than the lift it was
			-- given plus the sag of one 1.57-stud chord across a plane, which on a plane is zero.
			expect(buried <= 0).to.equal(true)
			expect(floating < Markers.RING.LIFT_STUDS + 0.05).to.equal(true)
			TestKit.note(
				string.format(
					"stand ring on a slope: worst buried %.3f, worst floating %.3f (task 166 answered 0.927 and 0.967)",
					buried,
					floating
				)
			)
			Markers.clearRings()
		end)

		it("keeps the circle whole where the canopy reader argues with the terrain", function()
			Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			-- A READER THAT STOPPED ON A BRANCH over half the circle. `build` refuses such a point,
			-- and must; the ring draws it on the TERRAIN reading instead of leaving a hole in itself.
			local function branchy(x: number, z: number): number?
				local y = flat(x, z) :: number
				return if x > Data.standPosition(4).X then y + Markers.GROUND_TOLERANCE_STUDS + 9 else y
			end
			expect(Markers.ring(4, Data.PICK.standRadiusStuds, Data.ROAD_LAYOUT, flat, branchy)).to.equal(
				Markers.RING.SEGMENTS
			)
			expect(Markers.stats().lastRingFallbacks > 0).to.equal(true)
			for _, child in ipairs((ringOf(4) :: Instance):GetChildren()) do
				-- ON THE TERRAIN, not on the branch: not one segment is nine studs up.
				expect((child :: BasePart).Position.Y).to.be.near(FLAT_Y + Markers.RING.LIFT_STUDS, 0.05)
			end
			Markers.clearRings()
		end)

		it("refuses the ground it cannot read, and draws nothing at all for a radius of zero", function()
			Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			-- THE SAME REFUSAL `build` MAKES: where the two readings disagree there is no segment,
			-- counted rather than guessed at. Nothing readable anywhere means no ring and no folder.
			expect(Markers.ring(3, Data.PICK.standRadiusStuds, Data.ROAD_LAYOUT, nothing, nothing)).to.equal(0)
			expect(ringOf(3)).to.equal(nil)
			expect(Markers.ring(3, 0, Data.ROAD_LAYOUT, flat, flat)).to.equal(0)
			expect(ringOf(3)).to.equal(nil)
			Markers.clearRings()
		end)
	end)

	describe("the folder", function()
		it("is rebuilt and never grows, and `clear` leaves nothing behind", function()
			Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			local first = partsInFolder()
			expect(first).to.equal(Data.ROAD_LAYOUT.standCount + 1) -- nine stands plus the beater pad
			Markers.build(Data.standX(5), Data.ROAD_LAYOUT, flat, flat)
			expect(partsInFolder()).to.equal(first)
			Markers.clear()
			expect(Markers.folder()).to.equal(nil)
		end)
	end)
end
