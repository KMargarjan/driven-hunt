-- map_ui.spec: the map, in the real client, on the real Hud.
--
-- WHAT IT PROVES AND WHAT IT CANNOT. The projection is PURE -- studs in, pixels out -- so everything
-- that could be arithmetically wrong is asserted here with hand-written numbers and no world, no
-- camera and no second player. `docs/PROJECT_CONTEXT.md`'s *"things measured correct and looked
-- wrong"* is survivable only that way round: the arithmetic is provable and the LOOK is the one
-- thing left for Karen's eye.
--
-- THE MOST VALUABLE CASE IN THIS FILE IS THE RECTANGLE ONE. Task 125 round 2 shipped the compass
-- strip over the drive bar and *"it was not seen because the frames were taken in the Forest Test,
-- where there is no bar at all"*. A rectangle intersection does not care which world it runs in.
--
-- WHAT ONE CLIENT CANNOT PROVE, said out loud: Karen's *"can see other players on map moving"* needs
-- a SECOND real player. The marker code is pinned over a synthetic roster here -- every absent case,
-- the pin, the overflow, the colours -- so the arithmetic and the drawing are provable with one
-- player, but "her daughter shows up as a blue dot" is a playtest item.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/map-ui.md · note: docs/research/2026-10-11-map-ui.md
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage:WaitForChild("Map"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local MapUi = Hud.MapUi
-- THE RAIL IS READ FOR ONE NUMBER ONLY (task 231): `Rail.columnPx`, so the column this spec hands to
-- `MapUi.setRailColumn` is the one the Hud really hands it rather than a literal beside it.
local Rail = Hud.Rail
local Compass = Hud.Compass
-- THE ONE SOURCE FOR EVERY COLOUR ON THIS MAP since task 201 E, read off the Hud exactly as
-- `hud_style.spec` reads it.
local Style = Hud.Style
local CONFIG = MapUi.CONFIG

-- HOW LONG THE M CASE WAITS FOR THE REPLAY TO REACH IT. The whole replay is ~43 s of scenario gaps
-- and `map-toggle` is the fifth of six, so 40 s is past the last press and still well inside the
-- harness's own 300 s wait for this report.
local KEY_TIMEOUT_SECONDS = 40

-- Returns how long it waited. `os.clock()`, like every other wait in the client specs.
local function waitForKeys(seconds: number, wanted: number): number
	local started = os.clock()
	local deadline = started + seconds
	while os.clock() < deadline and MapUi.stats().keyToggles < wanted do
		task.wait(0.05)
	end
	return os.clock() - started
end

-- A VIEW WITH ROUND NUMBERS, so every expectation below is arithmetic a reader can check: 2 px per
-- stud, 100 px to the edge, so 50 studs is the whole half-width.
local function rectView()
	return {
		centreX = 1000,
		centreZ = -500,
		pxPerStud = 2,
		halfWidthPx = 100,
		halfHeightPx = 60,
		shape = "rect" :: any,
	}
end

local function discView()
	return MapUi.minimapView(Vector3.new(1000, 0, -500), 150, 300)
end

local function overlaps(a: GuiObject, b: GuiObject): boolean
	local ap, as = a.AbsolutePosition, a.AbsoluteSize
	local bp, bs = b.AbsolutePosition, b.AbsoluteSize
	return ap.X < bp.X + bs.X and bp.X < ap.X + as.X and ap.Y < bp.Y + bs.Y and bp.Y < ap.Y + as.Y
end

return function()
	describe("the projection", function()
		it("puts north UP and east RIGHT", function()
			local view = rectView()
			-- 20 studs north: +Z, so UP the screen, which is NEGATIVE v.
			local u, v, inside = MapUi.project(view.centreX, view.centreZ + 20, view)
			expect(u).to.be.near(0, 1e-9)
			expect(v).to.be.near(-40, 1e-9)
			expect(inside).to.equal(true)
			-- 20 studs east: +X, so RIGHT, which is positive u.
			local eu, ev = MapUi.project(view.centreX + 20, view.centreZ, view)
			expect(eu).to.be.near(40, 1e-9)
			expect(ev).to.be.near(0, 1e-9)
		end)

		it("puts the centre dead centre", function()
			local view = rectView()
			local u, v, inside = MapUi.project(view.centreX, view.centreZ, view)
			expect(u).to.be.near(0, 1e-9)
			expect(v).to.be.near(0, 1e-9)
			expect(inside).to.equal(true)
		end)

		it("uses ONE scale on both axes, so a diagonal is not a lie", function()
			-- A map with two scales passes every axis-aligned case and lies about every diagonal.
			local view = rectView()
			local u, v = MapUi.project(view.centreX + 30, view.centreZ + 40, {
				centreX = view.centreX,
				centreZ = view.centreZ,
				pxPerStud = view.pxPerStud,
				halfWidthPx = math.huge,
				halfHeightPx = math.huge,
				shape = "rect",
			})
			local pixels = math.sqrt(u * u + v * v)
			local studs = math.sqrt(30 * 30 + 40 * 40)
			expect(pixels).to.be.near(studs * view.pxPerStud, 1e-9)
		end)

		it("agrees with the COMPASS's bearing convention at all four cardinals", function()
			-- COMPARED, NOT COPIED. Task 129 spent three rounds on a case that copied the expression
			-- under test into itself and *"agreed with the wrong one"*. So each cardinal's bearing
			-- comes from `Compass.headingDeg` -- the convention this game settled against a
			-- photograph -- and `facingOffsetPx` must point the same way `project` puts that offset.
			local view = rectView()
			local cardinals = {
				Vector3.new(0, 0, 1), -- north
				Vector3.new(1, 0, 0), -- east
				Vector3.new(0, 0, -1), -- south
				Vector3.new(-1, 0, 0), -- west
			}
			for _, look in ipairs(cardinals) do
				local bearing = Compass.headingDeg(look)
				local fu, fv = MapUi.facingOffsetPx(bearing, 10)
				local pu, pv = MapUi.project(view.centreX + look.X * 5, view.centreZ + look.Z * 5, view)
				-- Same direction: the two unit vectors agree to a rounding error.
				local flen = math.sqrt(fu * fu + fv * fv)
				local plen = math.sqrt(pu * pu + pv * pv)
				expect(fu / flen).to.be.near(pu / plen, 1e-6)
				expect(fv / flen).to.be.near(pv / plen, 1e-6)
			end
		end)

		it("pins a far marker to the RIM of a disc instead of hiding it", function()
			local view = discView()
			-- 400 studs out on a 300-stud minimap.
			local u, v, inside = MapUi.project(view.centreX, view.centreZ + 400, view)
			expect(inside).to.equal(false)
			expect(math.sqrt(u * u + v * v)).to.be.near(view.halfWidthPx, 1e-6)
			-- ...and still in the right direction: north is up.
			expect(v < 0).to.equal(true)
		end)

		it("pins a far marker to the EDGE of a rectangle, per axis", function()
			local view = rectView()
			-- Far west, slightly north: it pins to the west edge at its own latitude, not to a corner.
			local u, v, inside = MapUi.project(view.centreX - 500, view.centreZ + 10, view)
			expect(inside).to.equal(false)
			expect(u).to.be.near(-view.halfWidthPx, 1e-9)
			expect(v).to.be.near(-20, 1e-9)
		end)

		it("leaves a point inside a rectangle exactly where it was", function()
			local view = rectView()
			local u, v, inside = MapUi.project(view.centreX + 10, view.centreZ - 10, view)
			expect(inside).to.equal(true)
			expect(u).to.be.near(20, 1e-9)
			expect(v).to.be.near(20, 1e-9)
		end)

		it("gives the full view an extent the geometry actually fills", function()
			-- A marker pinned to the box it was OFFERED, when the map only reaches part of it, would
			-- be pinned outside the map it is supposed to be on the edge of.
			local view = MapUi.fullView({ minX = -100, maxX = 100, minZ = -50, maxZ = 50 }, 400, 400)
			expect(view.pxPerStud).to.be.near(2, 1e-9)
			expect(view.halfWidthPx).to.be.near(200, 1e-9)
			expect(view.halfHeightPx).to.be.near(100, 1e-9)
		end)
	end)

	describe("the minimap's size on screen", function()
		it("is the full 150 at 1080p and under a quarter of a phone's width", function()
			expect(MapUi.diameterFor(1920, 1080)).to.equal(CONFIG.MINIMAP_DIAMETER_PX)
			local phone = MapUi.diameterFor(400, 800)
			expect(phone).to.equal(CONFIG.MINIMAP_MIN_PX)
			-- The note promised *"without eating a quarter of it"* at ~400 px, and 150/400 is 37.5 %.
			expect(phone / 400 < 0.25).to.equal(true)
		end)

		it("never goes below the readable minimum", function()
			expect(MapUi.diameterFor(100, 100)).to.equal(CONFIG.MINIMAP_MIN_PX)
		end)

		it("RENDERS at that diameter, at a phone's viewport as well as at this one", function()
			-- THIS CASE EXISTS BECAUSE THE RUN COULD NOT SEE THE BUG (task 155 round 1, the
			-- Reviewer's blocking finding). The layout wrote the frame's `Size` AND a `UIScale`, and
			-- the two MULTIPLY -- a `UIScale` scales the GuiObject it is parented to, not only its
			-- descendants -- so a 96 px minimap at 400 px rendered at 96 x 96/150 = 61 px, and the
			-- picture inside it, built in the fixed 150 px space, was clipped: a marker pinned to
			-- the rim disappeared, which is the one thing the pin prevents. At THIS PC's 969 x 784
			-- the diameter is 150 and the scale is exactly 1, so nothing in the gate or in either
			-- screenshot could show it.
			--
			-- `applyLayout` is public for exactly this: a spec cannot resize a Studio viewport.
			local mini = Hud.minimap() :: Frame
			local real = workspace.CurrentCamera.ViewportSize
			-- PINNED, NOT JUST APPLIED. The 20 Hz tick re-reads the real `ViewportSize` and would
			-- undo this within 50 ms -- measured in this task's round 2, when the case read 150 px
			-- back where it had asked for 96 because the tick landed between the call and the read.
			local function renderedAt(x: number, y: number): number
				MapUi.applyLayout(Vector2.new(x, y))
				task.wait()
				task.wait()
				return mini.AbsoluteSize.X
			end
			local phone = renderedAt(400, 800)
			expect(phone).to.be.near(MapUi.diameterFor(400, 800), 1)
			local desktop = renderedAt(1920, 1080)
			expect(desktop).to.be.near(MapUi.diameterFor(1920, 1080), 1)
			-- ...and square, so the disc stays a disc.
			expect(mini.AbsoluteSize.Y).to.be.near(mini.AbsoluteSize.X, 1)
			-- GIVE THE SCREEN BACK, and assert it was given back rather than assuming it.
			MapUi.applyLayout(nil)
			task.wait()
			expect(MapUi.pinnedViewport()).to.equal(nil)
			expect(mini.AbsoluteSize.X).to.be.near(MapUi.diameterFor(real.X, real.Y), 1)
			TestKit.note(
				string.format(
					"map: minimap renders %.0f px at 400x800 (want %d) and %.0f px at 1920x1080 (want %d)",
					phone,
					MapUi.diameterFor(400, 800),
					desktop,
					MapUi.diameterFor(1920, 1080)
				)
			)
		end)

		-- 220a(c), task 231: `MapUi.setRailColumn` used to call `MapUi.applyLayout()` with NO
		-- argument, and that argument is not decoration -- `nil` means *"follow the real screen"* and
		-- writes `viewportOverride`. So telling the map how wide the rail had folded to threw away a
		-- pinned viewport, and the layout snapped back to the Studio window in the middle of whatever
		-- had pinned it. It changes the COLUMN and nothing else now.
		it("keeps a pinned viewport when it is told the rail's column", function()
			MapUi.applyLayout(Vector2.new(800, 400))
			task.wait()
			expect(MapUi.pinnedViewport()).to.equal(Vector2.new(800, 400))
			-- A value it does not already hold, so the early return cannot be what passes this.
			local wide = Rail.columnPx(2)
			local narrow = Rail.columnPx(1)
			MapUi.setRailColumn(if MapUi.railColumn() == wide then narrow else wide)
			task.wait()
			expect(MapUi.pinnedViewport()).to.equal(Vector2.new(800, 400))
			-- ...and an explicit override still wins, which is how the Hud could pin it from outside.
			MapUi.setRailColumn(nil, Vector2.new(400, 800))
			task.wait()
			expect(MapUi.pinnedViewport()).to.equal(Vector2.new(400, 800))
			MapUi.applyLayout(nil)
			task.wait()
			expect(MapUi.pinnedViewport()).to.equal(nil)
		end)
	end)

	describe("the scale bar", function()
		it("picks the largest round number of metres that fits its share of the canvas", function()
			-- 1 px per stud, 1000 px of canvas: the budget is 400 px, and 100 m is 357 studs.
			local studs, metres = MapUi.scaleBarStuds(1, 1000)
			expect(metres).to.equal(100)
			expect(studs).to.be.near(100 / Report.CONFIG.METRES_PER_STUD, 1e-6)
			expect(studs * 1 <= 400).to.equal(true)
		end)

		it("falls back to the smallest choice on a tiny canvas", function()
			local _, metres = MapUi.scaleBarStuds(1, 10)
			expect(metres).to.equal(CONFIG.SCALE_BAR_CHOICES_M[1])
		end)
	end)

	describe("what the world tells the map", function()
		it("draws the Forest Test's road from `ForestTest.roadZ` and nothing else", function()
			-- THERE IS NO SECOND CURVE. A map that re-typed the sine would disagree with the world
			-- the next time the Director bends the road.
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local model = MapUi.geometryFromForestTest(data, data.ROAD_LAYOUT)
			expect(#model.road).to.equal(CONFIG.ROAD_SAMPLES)
			for _, point in ipairs(model.road) do
				-- 1e-3 STUDS AND NOT 1e-9, and the reason is the container and not the arithmetic:
				-- a `Vector2` holds SINGLE-precision floats, so a z of -2069.768633 comes back as
				-- -2069.768555 -- a relative error of 4e-11, which at this map's 0.6 px/stud is
				-- 5e-5 of a pixel. MEASURED in task 155's first gate run, which is what a 1e-9
				-- tolerance on a float32 round trip buys you.
				expect(point.Y).to.be.near(data.roadZ(point.X), 1e-3)
			end
		end)

		it("draws the stands from `ForestTest.standPosition`, all nine, in order", function()
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local model = MapUi.geometryFromForestTest(data, data.ROAD_LAYOUT)
			expect(#model.stands).to.equal(data.ROAD_LAYOUT.standCount)
			for index, point in ipairs(model.stands) do
				local at = data.standPosition(index)
				-- 1e-3, for the float32 reason the road's case above measures.
				expect(point.X).to.be.near(at.X, 1e-3)
				expect(point.Y).to.be.near(at.Z, 1e-3)
			end
			-- In x order, which is what "stand 1 is west of stand 9" means on the picture.
			expect(model.stands[1].X < model.stands[#model.stands].X).to.equal(true)
		end)

		it("holds everything that world states inside its bounds", function()
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local model = MapUi.geometryFromForestTest(data, data.ROAD_LAYOUT)
			local bounds = model.bounds
			-- the exit, the drivers' start, the beater's start, and both ends of the stand line
			expect(data.exitZOf() > bounds.minZ).to.equal(true)
			local driver = data.driverStart(1, 2)
			expect(driver.Z < bounds.maxZ).to.equal(true)
			local beater = data.beaterStart(data.standX(5), 0)
			expect(beater.Z < bounds.maxZ).to.equal(true)
			for index = 1, data.ROAD_LAYOUT.standCount do
				local at = data.standPosition(index)
				expect(at.X > bounds.minX and at.X < bounds.maxX).to.equal(true)
				expect(at.Z > bounds.minZ and at.Z < bounds.maxZ).to.equal(true)
			end
		end)

		it("puts the road's own centre at the centre of the full map", function()
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local model = MapUi.geometryFromForestTest(data, data.ROAD_LAYOUT)
			local view = MapUi.fullView(model.bounds, 1000, 600)
			local u = MapUi.project(data.ROAD_LAYOUT.centre.X, (model.bounds.minZ + model.bounds.maxZ) / 2, view)
			expect(u).to.be.near(0, 1e-6)
			-- ...and stand 1 and stand 9 either side of it, their real spacing apart.
			local first = MapUi.project(data.standX(1), data.roadZ(data.standX(1)), view)
			local last = MapUi.project(
				data.standX(data.ROAD_LAYOUT.standCount),
				data.roadZ(data.standX(data.ROAD_LAYOUT.standCount)),
				view
			)
			expect(first < 0).to.equal(true)
			expect(last > 0).to.equal(true)
			local spacing = (data.ROAD_LAYOUT.standCount - 1) * data.ROAD_LAYOUT.standSpacing * view.pxPerStud
			expect(last - first).to.be.near(spacing, 1e-3)
			TestKit.note(
				string.format(
					"map: full view %.0f x %.0f studs at %.3f px/stud; %d stands span %.0f px",
					model.bounds.maxX - model.bounds.minX,
					model.bounds.maxZ - model.bounds.minZ,
					view.pxPerStud,
					data.ROAD_LAYOUT.standCount,
					last - first
				)
			)
		end)

		-- ---------------------------------------------------------------- one map per layout (179)

		it("draws EVERY drive layout, each on its own line and its own stand count", function()
			-- KAREN, 2026-10-13: *"view for hunter from different places and diffretent tree
			-- lines"*. The map is the one place a hunter can SEE which drive he is on, so a layout
			-- the map cannot draw is a layout he cannot read.
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			expect(#data.LAYOUT_ORDER >= 1).to.equal(true)
			for _, name in ipairs(data.LAYOUT_ORDER) do
				local layout = data.layoutNamed(name)
				local model = MapUi.geometryFor("forest-test", data, Map, name)
				expect(model).to.be.ok()
				local shown = model :: any
				expect(#shown.stands).to.equal(layout.standCount)
				expect(#shown.road).to.equal(CONFIG.ROAD_SAMPLES)
				-- A STRAIGHT LAYOUT IS A STRAIGHT POLYLINE and a curved one is not, with no second
				-- code path either way: `roadZ` answers `centre.Z` at every x at amplitude 0.
				local flat = true
				for _, point in ipairs(shown.road) do
					expect(point.Y).to.be.near(data.roadZ(point.X, layout), 1e-3)
					if math.abs(point.Y - layout.centre.Z) > 1e-3 then
						flat = false
					end
				end
				expect(flat).to.equal(layout.amplitudeStuds == 0)
				-- Every stand and the exit are inside the bounds that layout states.
				expect(data.exitZOf(layout) > shown.bounds.minZ).to.equal(true)
				for index = 1, layout.standCount do
					local at = data.standPosition(index, layout)
					expect(at.X > shown.bounds.minX and at.X < shown.bounds.maxX).to.equal(true)
					expect(at.Z > shown.bounds.minZ and at.Z < shown.bounds.maxZ).to.equal(true)
				end
				TestKit.note(
					string.format(
						"map: layout %s draws %d stands over %.0f studs, bounds %.0f x %.0f",
						name,
						layout.standCount,
						(layout.standCount - 1) * layout.standSpacing,
						shown.bounds.maxX - shown.bounds.minX,
						shown.bounds.maxZ - shown.bounds.minZ
					)
				)
			end
		end)

		it("gives a layout nobody has heard of NO MAP, never the road's", function()
			-- THE ONE THING A CLIENT MUST NOT DO is draw a different drive from the one the hunter's
			-- feet are on, and that is invisible in a screenshot. A nil or unknown published name is
			-- therefore the same answer as a world that has stated nothing: no map, and the Hud's
			-- attribute signal redraws the instant a real name arrives.
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			expect(MapUi.geometryFor("forest-test", data, Map, nil)).to.equal(nil)
			expect(MapUi.geometryFor("forest-test", data, Map, "clearing")).to.equal(nil)
			expect(MapUi.geometryFor("forest-test", data, Map, "")).to.equal(nil)
			expect(MapUi.geometryFor("forest-test", data, Map, "road")).to.be.ok()
		end)

		it("gives the DEV world a straight road, widened bounds and NO stands", function()
			-- THE DEFERRAL, ASSERTED (design section 5.3). `Map.TAGS.shooterPost` is read by
			-- `Markers.read` under `src/server/Match/` -- in `TWO_PLAYER_PATHS` -- and the spacing
			-- lives in ServerStorage, which does not replicate. Task 155a adds `Map.LINE`; until
			-- then this case is what the next task changes, instead of a comment it has to find.
			local model = MapUi.geometryFromMap(Map)
			expect(#model.road).to.equal(2)
			expect(model.road[1].Y).to.equal(Map.ROAD.z)
			expect(model.road[2].Y).to.equal(Map.ROAD.z)
			expect(model.road[1].X).to.equal(Map.ROAD.from)
			expect(model.bounds.minX <= Map.ROAD.from).to.equal(true)
			expect(model.bounds.maxX >= Map.ROAD.to).to.equal(true)
			expect(#model.stands).to.equal(0)
		end)

		it("gives a world that states nothing NO MAP AT ALL", function()
			-- *Visibly no map, never a blank panel* -- the audit that "certified a blank screen
			-- twice" is what that sentence is made of.
			expect(MapUi.geometryFor("forest-test", nil, nil, "road")).to.equal(nil)
			expect(MapUi.geometryFor("something-else", nil, nil)).to.equal(nil)
			expect(MapUi.geometryFor("something-else", nil, {})).to.equal(nil)
			-- ...AND A REAL `Map` DOES NOT ANSWER FOR A WORLD IT IS NOT ABOUT (task 155 round 1, the
			-- Reviewer's note). Without the `EXPECTED_WORLD` compare this returned the DEV road for
			-- any unrecognised place -- a map that is WRONG rather than absent.
			expect(MapUi.geometryFor("some-new-place", nil, Map)).to.equal(nil)
			expect(MapUi.geometryFor(Map.EXPECTED_WORLD, nil, Map)).to.be.ok()
		end)

		it("picks the Forest Test's geometry in that world and the Map's elsewhere", function()
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local forest = MapUi.geometryFor("forest-test", data, Map, "road")
			expect(forest).to.be.ok()
			expect((forest :: any).world).to.equal(data.WORLD)
			expect(#(forest :: any).stands).to.equal(data.ROAD_LAYOUT.standCount)
			-- `Map.EXPECTED_WORLD` AND NOT `DEFAULT_WORLD`: since the fall-through was closed, a `Map`
			-- only answers for the world it is about, and in the Forest Test place those two differ.
			if Map.EXPECTED_WORLD ~= "forest-test" then
				local dev = MapUi.geometryFor(Map.EXPECTED_WORLD, data, Map, "road")
				expect(dev).to.be.ok()
				expect(#(dev :: any).stands).to.equal(0)
			end
		end)
	end)

	describe("the markers", function()
		it("draws nothing for a player with no position, and never invents one", function()
			-- No character yet, or a streamed-out one: a stale dot is a lie about where somebody is.
			local points = MapUi.pointsFor({
				{ userId = 1, team = "Shooters", position = nil },
				{ userId = 2, team = "Drivers", position = Vector3.new(1000, 0, -500) },
			}, rectView(), 2)
			expect(#points).to.equal(1)
			expect(points[1].userId).to.equal(2)
			expect(points[1].mine).to.equal(true)
		end)

		it("pins a player beyond the range instead of dropping them", function()
			local points = MapUi.pointsFor({
				{ userId = 7, team = "Drivers", position = Vector3.new(1000, 0, 400) },
			}, discView(), 1)
			expect(#points).to.equal(1)
			expect(points[1].pinned).to.equal(true)
			expect(points[1].mine).to.equal(false)
		end)

		it("draws at most MAX_MARKERS and COUNTS the rest", function()
			local sources = {}
			for index = 1, CONFIG.MAX_MARKERS + 4 do
				table.insert(sources, { userId = index, position = Vector3.new(1000, 0, -500) })
			end
			expect(#MapUi.pointsFor(sources, rectView(), 1)).to.equal(CONFIG.MAX_MARKERS)
			expect(MapUi.overflowFor(sources)).to.equal(4)
			-- A source with no position is not an overflow, it is simply not drawn.
			expect(MapUi.overflowFor({ { userId = 1, position = nil } })).to.equal(0)
		end)

		it("keys every mark by a shape as well as by a colour", function()
			-- TASK 201 E, AND IT IS A REGRESSION THIS TASK CAUSED. The palette has ONE go-here
			-- orange and the hunters ARE that orange (§1.1: `HUNTER` and `BLAZE_HI` are the same
			-- `#E8832F`), so STAND, GO HERE and HUNTER are now one colour -- and the key drew the
			-- first two as the same square. Found by looking at `t201e-fullmap.png` (rule 5).
			--
			-- SO THE KEY IS ASSERTED AS A PAIR, colour AND shape, and the pair must be unique:
			-- that is the only property that makes a key readable, and the one a colour-only case
			-- could never have caught.
			local seen = {}
			local rows = MapUi.legendRows()
			expect(#rows).to.equal(6)
			for _, row in ipairs(rows) do
				local key = tostring(row.color) .. "/" .. row.shape
				expect(seen[key]).to.equal(nil)
				seen[key] = row.word
			end
			-- ...and the target's shape is the one the MAP draws it with: turned 45 degrees
			-- (`buildDrawer`'s `goal.Rotation = 45`), never a second plain square.
			for _, row in ipairs(rows) do
				if row.word == "GO HERE" then
					expect(row.shape).to.equal("diamond")
					expect(row.color).to.equal(Style.LOOK.BLAZE_HI)
				elseif row.word == "STAND" then
					expect(row.shape).to.equal("square")
					expect(row.color).to.equal(Style.LOOK.HUNTER)
				end
			end
			-- The two that share a colour are told apart by shape, which is the whole claim.
			expect(Style.LOOK.HUNTER).to.equal(Style.LOOK.BLAZE_HI)
		end)

		it("colours by team, from the ONE mapping the pill and the roster read", function()
			-- TASK 201 E: these were `Drive.CONFIG`'s three colours, which was the right answer
			-- while the drive bar's badges were the only other team-coloured thing on screen. The
			-- badge is a `Style` pill now, so `Style.teamColor` is the one mapping and reading
			-- `Drive.CONFIG` here is what WOULD make the map and the roster disagree.
			expect(MapUi.markerColor("Drivers", false)).to.equal(Style.teamColor("Drivers"))
			expect(MapUi.markerColor("Shooters", false)).to.equal(Style.teamColor("Shooters"))
			expect(MapUi.markerColor("Drivers", false)).to.equal(Style.LOOK.BEATER)
			expect(MapUi.markerColor("Shooters", false)).to.equal(Style.LOOK.HUNTER)
			-- A BODY WITH NO TEAM is `FIELD_MUTED` and never `MUTED`: §2 bans `MUTED` over the
			-- world (4.11 : 1 over a bright sky), and the minimap is a field surface.
			expect(MapUi.markerColor(nil, false)).to.equal(Style.LOOK.FIELD_MUTED)
			expect(MapUi.markerColor(nil, false)).never.to.equal(Style.LOOK.MUTED)
			-- ...and your own is brass, whatever team you are on (§5 surface 4: *"own marker
			-- `#FFE896` -> `BRASS_HI`"*).
			expect(MapUi.markerColor("Drivers", true)).to.equal(Style.LOOK.BRASS_HI)
		end)
	end)

	describe("what hides what", function()
		it("shows the full map only when it is open, unsuppressed and the report is shut", function()
			expect(MapUi.fullMapVisible(true, false, false)).to.equal(true)
			expect(MapUi.fullMapVisible(false, false, false)).to.equal(false)
			expect(MapUi.fullMapVisible(true, true, false)).to.equal(false)
			expect(MapUi.fullMapVisible(true, false, true)).to.equal(false)
		end)

		it("shows the minimap only when there IS a map and nothing bigger is up", function()
			expect(MapUi.minimapVisible(false, false, false, true)).to.equal(CONFIG.MINIMAP_ENABLED)
			expect(MapUi.minimapVisible(false, false, false, false)).to.equal(false)
			expect(MapUi.minimapVisible(true, false, false, true)).to.equal(false)
			expect(MapUi.minimapVisible(false, true, false, true)).to.equal(false)
			expect(MapUi.minimapVisible(false, false, true, true)).to.equal(false)
			-- TASK 177: THE FIFTH ARGUMENT DEFAULTS TO FALSE, so every combination above is
			-- bit-identical when it is nil. That is the identity claim, asserted rather than assumed.
			expect(MapUi.minimapVisible(false, false, false, true, nil)).to.equal(CONFIG.MINIMAP_ENABLED)
			expect(MapUi.minimapVisible(false, false, false, true, false)).to.equal(CONFIG.MINIMAP_ENABLED)
		end)

		-- ---------------------------------------------------------------- task 177: outside the map
		--
		-- THE RULE NAMES NO LOBBY, and that is deliberate: *"you are outside the map's own frame"* is
		-- a fact about the world's STATED geometry. It stays true if the lobby moves and it needs no
		-- lobby concept in the Hud at all.
		it("hides the minimap for a player outside the world the map states", function()
			-- The minimap is centred on the player with a 300-stud range, so from 500 studs outside
			-- the stated bounds it would draw a dark disc, a scale bar and your own wedge and nothing
			-- else. That is a half-drawn drive, which is what this is not allowed to be.
			expect(MapUi.minimapVisible(false, false, false, true, true)).to.equal(false)
			-- ...and the FULL map is untouched: it holds the whole stated world and PINS an
			-- out-of-range marker to its border, which is its own documented rule. M keeps working.
			expect(MapUi.fullMapVisible(true, false, false)).to.equal(true)
		end)

		it("answers withinBounds inside, outside and exactly on the boundary", function()
			local bounds = { minX = -100, maxX = 100, minZ = -200, maxZ = 50 }
			expect(MapUi.withinBounds(bounds, Vector3.new(0, 999, 0))).to.equal(true)
			-- ON the edge is IN, so a player standing on the map's own border is not off the map.
			expect(MapUi.withinBounds(bounds, Vector3.new(100, 0, 50))).to.equal(true)
			expect(MapUi.withinBounds(bounds, Vector3.new(-100, 0, -200))).to.equal(true)
			expect(MapUi.withinBounds(bounds, Vector3.new(100.1, 0, 0))).to.equal(false)
			expect(MapUi.withinBounds(bounds, Vector3.new(0, 0, -200.1))).to.equal(false)
			-- Height is not bounded: the map is a footprint.
			expect(MapUi.withinBounds(bounds, Vector3.new(0, -5000, 0))).to.equal(true)
		end)

		it("puts the lobby outside this world's stated bounds, which is why the minimap hides there", function()
			-- The one case that ties the two systems together, and it reads both numbers rather than
			-- copying either: `Lobby.anchorFor` is the lobby's own statement of where it is, and the
			-- geometry is the map's own statement of what it covers.
			--
			-- THE WORLD IS NAMED, NOT ASKED FOR (review round 1, finding 2). This case used to open
			-- `if Map.EXPECTED_WORLD ~= "forest-test" then return end` -- and `Map.EXPECTED_WORLD` is
			-- `"map:v1"` in the DEV place, which is the ONLY place the harness runs, so it asserted
			-- nothing anywhere and the claim that rested on it was never measured. `geometryFor`
			-- branches on its `world` ARGUMENT and `ReplicatedStorage.ForestTest` is in every place,
			-- so the literal runs here and can fail here -- which is what the sibling case two
			-- describes up already does.
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local geometry = MapUi.geometryFor("forest-test", data, Map, "road")
			expect(geometry).to.be.ok()
			local anchor = require(ReplicatedStorage:WaitForChild("Lobby")).anchorFor("forest-test")
			expect(anchor).to.be.ok()
			local at = Vector3.new((anchor :: any).x, 0, (anchor :: any).z)
			expect(MapUi.withinBounds((geometry :: any).bounds, at)).to.equal(false)
		end)

		-- THE MOBILE-BUTTON CASE IS GONE WITH THE BUTTON (task 165). `MapUi.buttonVisible` was
		-- `touchEnabled and BUTTON_ENABLED`, which is exactly why Karen never saw a map button on her
		-- PC and asked for *"buttons on the side for M - map ect"*. The button is `Hud.Rail`'s first
		-- one now and `tests/client/hud_clarity.spec.luau` owns its cases, including that pressing it
		-- opens THIS module's map. Archived: `backups/2026-10-12_mapui-touch-button.txt`.
	end)

	describe("the picture, on the real Hud", function()
		it("lives inside the one Hud ScreenGui", function()
			local mini, full = Hud.minimap(), Hud.fullMap()
			expect(mini).to.be.ok()
			expect(full).to.be.ok()
			expect((mini :: Frame):IsDescendantOf(player.PlayerGui)).to.equal(true)
			expect((full :: Frame):IsDescendantOf(player.PlayerGui)).to.equal(true)
			expect((mini :: Frame).ClipsDescendants).to.equal(true)
		end)

		it("has a geometry in this world, and so a map on screen", function()
			-- Both worlds the harness runs in state a road, so this is not a conditional claim.
			expect(MapUi.geometry()).to.be.ok()
			local mini = Hud.minimap() :: Frame
			expect(mini.Visible).to.equal(CONFIG.MINIMAP_ENABLED)
			expect((Hud.fullMap() :: Frame).Visible).to.equal(false)
			-- ...and the road really is drawn into it, once.
			local inner = mini:FindFirstChild("Geometry")
			expect(inner).to.be.ok()
			local roads = 0
			for _, child in ipairs((inner :: Frame):GetChildren()) do
				if child.Name == "Road" then
					roads += 1
				end
			end
			expect(roads >= 1).to.equal(true)
		end)

		it("REDRAWS the picture when the world hands it a different layout", function()
			-- ROUND 1, FINDING 3: `setGeometry` latched `built` for the life of the client, so the
			-- attribute signal replaced only the `geometry` table `withinBounds` reads -- the DRAWN
			-- road, stands and views stayed on the first layout. From drive 2 on, the hunter's map
			-- showed the PREVIOUS drive's ground.
			--
			-- IT IS ASSERTED ON THE DRAWN NODES, not on `MapUi.geometry()`, which is what made the
			-- round-1 claim pass while the picture was wrong.
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			expect((Hud.minimap() :: Frame):FindFirstChild("Geometry")).to.be.ok()

			-- THE LAYER IS RE-FOUND EVERY TIME, and that is the point rather than caution: a rebuild
			-- DESTROYS the frame the picture was drawn into and makes a new one, so a spec holding
			-- the old one would read a destroyed Instance with no children and "the map changed"
			-- would pass for the wrong reason.
			local function drawn(): (number, number, UDim2?)
				local layer = (Hud.minimap() :: Frame):FindFirstChild("Geometry")
				if layer == nil then
					return 0, 0, nil
				end
				local stands, roads, first = 0, 0, nil
				for _, child in ipairs((layer :: Frame):GetChildren()) do
					if string.match(child.Name, "^Stand%d+$") then
						stands += 1
						if child.Name == "Stand1" then
							first = (child :: Frame).Position
						end
					elseif child.Name == "Road" then
						roads += 1
					end
				end
				return stands, roads, first
			end

			local restore = MapUi.geometry()
			local before = MapUi.stats()
			local standsBefore, roadsBefore = drawn()

			-- Two layouts with DIFFERENT stand counts, so "the picture moved" is countable.
			local wide, narrow = nil, nil
			for _, name in ipairs(data.LAYOUT_ORDER) do
				local layout = data.layoutNamed(name)
				if wide == nil or layout.standCount > data.layoutNamed(wide).standCount then
					wide = name
				end
				if narrow == nil or layout.standCount < data.layoutNamed(narrow).standCount then
					narrow = name
				end
			end
			expect(wide).never.to.equal(narrow)

			MapUi.setGeometry(MapUi.geometryFor("forest-test", data, Map, wide))
			local standsWide, roadsWide, firstWide = drawn()
			expect(standsWide).to.equal(data.layoutNamed(wide).standCount)
			expect(roadsWide >= 1).to.equal(true)

			MapUi.setGeometry(MapUi.geometryFor("forest-test", data, Map, narrow))
			local standsNarrow, _roadsNarrow, firstNarrow = drawn()
			-- THE DRAWN STANDS REALLY CHANGED, in number and in place.
			expect(standsNarrow).to.equal(data.layoutNamed(narrow).standCount)
			expect(standsNarrow).never.to.equal(standsWide)
			expect(firstWide).to.be.ok()
			expect(firstNarrow).to.be.ok()
			expect(firstNarrow).never.to.equal(firstWide)
			-- ...and the road was drawn again rather than stacked on top of itself.
			local _s, roadsNarrow2 = drawn()
			expect(roadsNarrow2).to.equal(roadsWide)
			expect(MapUi.stats().rebuilds > before.rebuilds).to.equal(true)

			-- IDEMPOTENT: the same geometry again rebuilds nothing, because `Hud` calls this on every
			-- attribute write and a map that tore itself down per write would flicker.
			local steady = MapUi.stats().rebuilds
			MapUi.setGeometry(MapUi.geometryFor("forest-test", data, Map, narrow))
			expect(MapUi.stats().rebuilds).to.equal(steady)

			TestKit.note(
				string.format(
					"map: redraw %s(%d stands) -> %s(%d stands); before this task the picture stayed at %d",
					wide,
					standsWide,
					narrow,
					standsNarrow,
					standsBefore
				)
			)
			-- Put the client's own map back, and prove it came back.
			MapUi.setGeometry(restore)
			local standsAfter, roadsAfter = drawn()
			expect(standsAfter).to.equal(standsBefore)
			expect(roadsAfter).to.equal(roadsBefore)
			expect(MapUi.geometry()).to.equal(restore)
		end)

		it("leaves the Hud's OWN decorations alone when it redraws", function()
			-- ROUND 2, FINDING 1. The rebuild cleared the frames' children "by ownership", and the
			-- ownership claim was wrong: `Hud.build` parents four things of its own into them -- the
			-- minimap's `UICorner`, which is HOW a circle is drawn in Roblox GUI without an uploaded
			-- image (Karen: *"small map in left or right corner circle like is on another games"*), a
			-- `UIStroke` rim on each frame, and the `MapLegend` frame, which IS the instance handed
			-- back as `frames.legend`. So one layout change turned the minimap into a square with the
			-- road in its corners, took both rims, and left the module's `legendFrame` pointing at a
			-- destroyed instance. `Hud.build` runs once, so nothing ever put them back.
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local mini, full = Hud.minimap() :: Frame, Hud.fullMap() :: Frame
			local corner = mini:FindFirstChildOfClass("UICorner")
			local miniRim = mini:FindFirstChildOfClass("UIStroke")
			local fullRim = full:FindFirstChildOfClass("UIStroke")
			local legend = full:FindFirstChild("MapLegend") :: Frame
			expect(corner).to.be.ok()
			expect(miniRim).to.be.ok()
			expect(fullRim).to.be.ok()
			expect(legend).to.be.ok()
			local rows = #legend:GetChildren()
			expect(rows > 0).to.equal(true)

			local restore = MapUi.geometry()
			local rebuilds = MapUi.stats().rebuilds
			for _, name in ipairs(data.LAYOUT_ORDER) do
				MapUi.setGeometry(MapUi.geometryFor("forest-test", data, Map, name))
			end
			MapUi.setGeometry(restore)
			expect(MapUi.stats().rebuilds > rebuilds).to.equal(true)

			-- THE SAME INSTANCES, not replacements: `Hud.build` cannot make them again.
			expect(corner.Parent).to.equal(mini)
			expect(miniRim.Parent).to.equal(mini)
			expect(fullRim.Parent).to.equal(full)
			expect(legend.Parent).to.equal(full)
			expect(mini:FindFirstChildOfClass("UICorner")).to.equal(corner)
			-- ...and the legend is still drawn into THAT frame, with its rows, rather than into a
			-- destroyed one.
			expect(#legend:GetChildren()).to.equal(rows)
			expect(full:FindFirstChild("MapLegend")).to.equal(legend)
			-- The circle is still a circle: half the frame's side, which is what `ClipsDescendants`
			-- keeps the road inside.
			expect((corner :: UICorner).CornerRadius).to.equal(UDim.new(0.5, 0))
			expect(mini.ClipsDescendants).to.equal(true)
			TestKit.note(
				string.format(
					"map: %d redraw(s) and the Hud's UICorner, 2 UIStrokes and MapLegend (%d rows) all survived",
					MapUi.stats().rebuilds - rebuilds,
					rows
				)
			)
		end)

		it("leaves EXACTLY ONE of each drawer node on the minimap after a redraw", function()
			-- ROUND 3, FINDING 1, AND IT IS THE THIRD TIME THIS CLASS HAS BEEN MISSED. The minimap
			-- drawer's frame IS the Hud's own `MiniMap` -- unlike the full map's, whose frame is the
			-- claimed `canvas` -- so every instance `buildDrawer` parents there has to be claimed or
			-- the rebuild leaks it. Round 3 claimed six of the seven and left `TargetWord`: from the
			-- first layout change the minimap carried two orange target words, the stale one frozen
			-- at the previous layout's pinned position, still `Visible`, never updated again.
			--
			-- SO THIS CASE COUNTS rather than naming what it expects to find. A comment saying the
			-- claim list is complete got the count wrong twice; a count cannot. The next instance
			-- added to `buildDrawer` and not claimed fails here.
			local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local mini = Hud.minimap() :: Frame

			local function tally(): { [string]: number }
				local counts: { [string]: number } = {}
				for _, child in ipairs(mini:GetChildren()) do
					local name = child.Name
					-- The per-player markers are pooled at `MAX_MARKERS`, so they are counted as one
					-- family rather than by index.
					if string.match(name, "^Player%d+$") then
						name = "Player*"
					end
					counts[name] = (counts[name] or 0) + 1
				end
				return counts
			end

			local restore = MapUi.geometry()
			local before = tally()
			-- The drawer's own nodes, every one of which `buildDrawer` parents into THIS frame.
			local singles = { "Own", "Wedge", "PushArrow", "PushWord", "Target", "TargetWord", "Geometry" }
			for _, name in ipairs(singles) do
				expect(before[name]).to.equal(1, string.format("%s is not drawn once before the redraw", name))
			end
			local playersBefore = before["Player*"]
			expect(playersBefore).to.equal(CONFIG.MAX_MARKERS)

			for _, name in ipairs(data.LAYOUT_ORDER) do
				MapUi.setGeometry(MapUi.geometryFor("forest-test", data, Map, name))
			end
			MapUi.setGeometry(restore)

			local after = tally()
			for _, name in ipairs(singles) do
				expect(after[name]).to.equal(
					1,
					string.format("%d x %s on the minimap after %d redraws", after[name] or 0, name, #data.LAYOUT_ORDER)
				)
			end
			expect(after["Player*"]).to.equal(playersBefore)
			-- ...AND NOTHING ELSE APPEARED EITHER: the same set of names, with the same counts. That
			-- is the half a list of names cannot give you -- it is what makes a NEW unclaimed
			-- instance fail this case instead of slipping past it.
			for name, count in pairs(after) do
				expect(before[name]).to.equal(
					count,
					string.format("%s: %d before the redraws, %d after", name, before[name] or 0, count)
				)
			end
			for name in pairs(before) do
				expect(after[name]).to.be.ok(string.format("%s went missing in the redraws", name))
			end
			TestKit.note(
				string.format(
					"map: after %d redraws the minimap holds one each of %s, and %d player markers",
					#data.LAYOUT_ORDER,
					table.concat(singles, "/"),
					after["Player*"]
				)
			)
		end)

		it("binds M, and only once there is a map to open", function()
			local actions = MapUi.boundActions()
			expect(#actions).to.equal(1)
			local info = ContextActionService:GetAllBoundActionInfo()[actions[1]]
			expect(info).to.be.ok()
			expect(CONFIG.TOGGLE_KEY).to.equal(Enum.KeyCode.M)
		end)

		it("takes a key no other binder in this client has taken", function()
			-- M against every action bound in this client, the map's own excepted.
			local mine = MapUi.boundActions()[1]
			for name, info in pairs(ContextActionService:GetAllBoundActionInfo()) do
				if name == mine then
					continue
				end
				for _, input in ipairs(info.inputTypes or {}) do
					expect(input).never.to.equal(Enum.KeyCode.M)
				end
			end
		end)

		it("has NO button of its own any more, and the rail's one opens this map", function()
			-- THE REPLACEMENT, ASSERTED RATHER THAN ASSUMED (task 165). The old touch button is gone
			-- from the Hud entirely, and the thing that replaced it drives `MapUi.toggle` -- so the
			-- removal cannot have quietly taken the feature with it.
			expect(Hud.mapButton).to.equal(nil)
			local rail = Hud.rail()
			expect(rail).to.be.ok()
			local mapButton = Hud.Rail.button("MAP")
			expect(mapButton).to.be.ok()
			local was = MapUi.isOpen()
			local keyToggles = MapUi.stats().keyToggles
			expect(Hud.Rail.press("MAP")).to.equal(true)
			expect(MapUi.isOpen()).to.equal(not was)
			MapUi.setOpen(was)
			-- ...and it is NOT counted as a key press: `keyToggles` is the evidence that a real M
			-- arrived, which is what task 155 round 1 made it a separate counter for.
			expect(MapUi.stats().keyToggles).to.equal(keyToggles)
		end)
	end)

	describe("the rectangles do not overlap", function()
		it("keeps the map clear of the drive bar, the tied banner, the compass and the readout", function()
			-- THE MOST VALUABLE CASE IN THIS FILE. Task 125 round 2 shipped a strip over the clock
			-- and the frames did not show it, because they were taken in a world with no clock. A
			-- rectangle intersection does not care which world it runs in -- so the other elements
			-- are made visible for the measurement and put back exactly as they were.
			local screen = Hud.gui() :: ScreenGui
			local mini = Hud.minimap() :: Frame
			-- THE RAIL TOOK THE BUTTON'S PLACE IN THIS CASE (task 165), and it is a stricter check:
			-- the old button was one 48 px circle and the rail is a 216 px column, under the same
			-- disc. `ObjectiveLine` is in the list of others because the whole top band moved to make
			-- room for it.
			local rail = Hud.rail() :: Frame
			local others = {}
			for _, name in ipairs({ "DriveBar", "TiedBanner", "Compass", "Readout", "ObjectiveLine" }) do
				local node = screen:FindFirstChild(name)
				if node ~= nil and node:IsA("GuiObject") then
					table.insert(others, { node = node :: GuiObject, was = (node :: GuiObject).Visible })
				end
			end
			for _, entry in ipairs(others) do
				entry.node.Visible = true
			end
			local wasMini = mini.Visible
			local wasRail = rail.Visible
			mini.Visible = true
			rail.Visible = true
			-- One frame, so the engine has computed `AbsolutePosition` for what was just shown.
			task.wait()
			local clashes = {}
			for _, entry in ipairs(others) do
				if overlaps(mini, entry.node) then
					table.insert(clashes, "minimap/" .. entry.node.Name)
				end
				if overlaps(rail, entry.node) then
					table.insert(clashes, "rail/" .. entry.node.Name)
				end
			end
			mini.Visible = wasMini
			rail.Visible = wasRail
			for _, entry in ipairs(others) do
				entry.node.Visible = entry.was
			end
			expect(table.concat(clashes, ", ")).to.equal("")
		end)

		it("sits under the scope's mask and the report, and over the feed", function()
			local mini = Hud.minimap() :: Frame
			local full = Hud.fullMap() :: Frame
			expect(mini.ZIndex).to.equal(CONFIG.Z_INDEX)
			expect(full.ZIndex).to.equal(CONFIG.Z_INDEX)
			expect(CONFIG.Z_INDEX < Report.CONFIG.PANEL_Z_INDEX).to.equal(true)
			expect(CONFIG.Z_INDEX < 11).to.equal(true) -- `SCOPE_Z`
			expect(CONFIG.Z_INDEX > 1).to.equal(true) -- the feed and the drive bar
		end)
	end)

	describe("the toggle and the suppression", function()
		it("swaps the minimap for the full map and back", function()
			local mini = Hud.minimap() :: Frame
			local full = Hud.fullMap() :: Frame
			local was = MapUi.isOpen()
			MapUi.setOpen(true)
			expect(MapUi.isOpen()).to.equal(true)
			expect(full.Visible).to.equal(true)
			expect(mini.Visible).to.equal(false)
			MapUi.setOpen(false)
			expect(full.Visible).to.equal(false)
			expect(mini.Visible).to.equal(CONFIG.MINIMAP_ENABLED)
			MapUi.toggle()
			expect(MapUi.isOpen()).to.equal(true)
			MapUi.setOpen(was)
		end)

		it("hides both at once while a sight picture is in, and puts back what was there", function()
			local mini = Hud.minimap() :: Frame
			local full = Hud.fullMap() :: Frame
			MapUi.setOpen(false)
			MapUi.setSuppressed(true)
			expect(mini.Visible).to.equal(false)
			expect(full.Visible).to.equal(false)
			MapUi.setSuppressed(false)
			expect(mini.Visible).to.equal(CONFIG.MINIMAP_ENABLED)
			-- ...and an OPEN map comes back open, not closed.
			MapUi.setOpen(true)
			MapUi.setSuppressed(true)
			expect(full.Visible).to.equal(false)
			MapUi.setSuppressed(false)
			expect(full.Visible).to.equal(true)
			MapUi.setOpen(false)
		end)

		it("moves nothing else on the screen", function()
			-- The previous project died partly of *"one predicate answered two unrelated questions,
			-- so mounting hid both the crosshair and the weapon"*.
			local crosshair = Hud.isCrosshairVisible()
			local compass = Hud.compass()
			local compassWas = compass ~= nil and compass.Visible
			local bar = Hud.isDriveBarVisible()
			MapUi.setOpen(true)
			MapUi.setOpen(false)
			expect(Hud.isCrosshairVisible()).to.equal(crosshair)
			expect(compass ~= nil and compass.Visible).to.equal(compassWas)
			expect(Hud.isDriveBarVisible()).to.equal(bar)
		end)
	end)

	describe("the live picture", function()
		it("draws THIS player exactly once, and reads back off the frames", function()
			MapUi.setOpen(false)
			MapUi.setSuppressed(false)
			MapUi.render()
			local points = MapUi.markerPoints()
			local mine = 0
			for _, point in ipairs(points) do
				if point.mine then
					mine += 1
					expect(point.userId).to.equal(player.UserId)
				end
			end
			-- ONE DRAWER IS LIVE AT A TIME, so the local player is on screen ONCE -- or not at all if
			-- the harness runs before this client has a character.
			--
			-- THIS CASE CAUGHT A REAL BUG on its first run (task 155's first gate): the full map's
			-- drawer draws into a CANVAS inside the panel, the canvas is always `Visible`, and the
			-- module was asking the canvas instead of the panel -- so the CLOSED full map drew a
			-- second copy of every marker and `mine` was 2. That is
			-- `docs/PROJECT_CONTEXT.md`'s *"a visibility audit ignored parent visibility"*, found by
			-- a spec rather than by Karen. `Drawer.gate` is the fix.
			expect(mine <= 1).to.equal(true)
			local character = player.Character
			if character ~= nil and character.PrimaryPart ~= nil then
				expect(mine).to.equal(1)
			end
		end)

		it("ticks at TICK_HZ and not once a frame", function()
			-- A spec that only checked "it redraws" would pass a `RenderStepped` map.
			local before = MapUi.stats()
			local started = os.clock()
			local frames = 0
			-- 0.6 s IS LONG ENOUGH AND NO LONGER. At 20 Hz that is ~12 ticks, which settles the
			-- order of magnitude against a 60 Hz `RenderStepped` map by a factor of three -- and the
			-- suite's own length is a constraint now, because the START gate is time-limited
			-- (`TestKit.TOKEN_MAX_AGE`, 120 s) and this task's first gate run tipped
			-- `tests/server/sync.spec.luau` over that line.
			while os.clock() - started < 0.6 do
				task.wait()
				frames += 1
			end
			local after = MapUi.stats()
			local ticks = after.ticks - before.ticks
			local elapsed = os.clock() - started
			expect(ticks > 0).to.equal(true)
			-- Within 40 % of the configured rate: a Studio client's Heartbeat is not a metronome,
			-- and what is being proved is the ORDER of magnitude, not the clock.
			expect(ticks / elapsed).to.be.near(CONFIG.TICK_HZ, CONFIG.TICK_HZ * 0.4)
			-- ...and far below the frames that went past in the same window.
			expect(ticks < frames).to.equal(true)
			TestKit.note(
				string.format(
					"map: %d ticks in %.2f s (%.1f Hz, target %d) against %d frames",
					ticks,
					elapsed,
					ticks / elapsed,
					CONFIG.TICK_HZ,
					frames
				)
			)
		end)

		it("shows the push direction the HUD's own rule gives, with its word", function()
			-- THE RULE CHANGED IN TASK 165 AND THIS CASE CHANGED WITH IT. The arrow used to be the
			-- WORLD's bearing, full stop; it is now `Hud.markerFor`'s answer -- the bearing to this
			-- player's own TARGET when there is one, and the world's when there is not. That is what
			-- makes the strip, the minimap and the waypoint chevron agree, and it is why a DEV world
			-- that states no drive direction now HAS an arrow: it points at the hunter's own line.
			--
			-- ASSERTED AS AN INVARIANT rather than by re-deriving the target, because re-deriving it
			-- here would be a second copy of the renderer's rule. If there is a target the arrow is
			-- the bearing TO it and wears its word; if there is none the arrow is the world's answer.
			local target, targetWord = MapUi.target()
			if target ~= nil then
				local at = target :: Vector2
				local root = player.Character and player.Character.PrimaryPart
				expect(MapUi.pushLabel()).to.equal(targetWord)
				if root ~= nil then
					local me = (root :: BasePart).Position
					local wanted = (math.deg(math.atan2(at.X - me.X, at.Y - me.Z)) + 360) % 360
					-- Within a degree: the pass that set the bearing and this read are different
					-- frames, and the player may have moved a stud between them.
					expect(MapUi.pushBearingDeg()).to.be.near(wanted, 1)
				end
				return
			end
			local data = if Map.EXPECTED_WORLD == "forest-test"
				then require(ReplicatedStorage:WaitForChild("ForestTest"))
				else nil
			if data == nil then
				-- No target and no world direction: no arrow and no word -- `Compass.setBearing(nil)`.
				expect(MapUi.pushBearingDeg()).to.equal(nil)
				return
			end
			local team = player.Team
			local bearing, label = Hud.driveBearing(data, if team then team.Name else nil)
			expect(MapUi.pushBearingDeg()).to.equal(bearing)
			expect(MapUi.pushLabel()).to.equal(label or "DRIVE")
			-- A BEATER'S WORD IS THE ROAD, a hunter's is the drive -- the two must not be the same
			-- (task 153 round 2's blocking finding).
			local beaterBearing, beaterLabel = Hud.driveBearing(data, data.PUSH_TEAM)
			expect(beaterBearing).to.equal(data.PUSH_BEARING_DEG)
			expect(beaterLabel).to.equal(data.PUSH_LABEL)
			local hunterBearing = Hud.driveBearing(data, "Shooters")
			expect(hunterBearing).to.equal(data.DRIVE_BEARING_DEG)
			expect(beaterBearing).never.to.equal(hunterBearing)
		end)

		it("runs the push arrow FROM the player TOWARD the way to go", function()
			-- THE SCREENSHOT CAUGHT THIS AND NO NUMBER DID (rule 5). The arrow was anchored at its
			-- base on the reasoning that `GuiObject.Rotation` pivots about the `AnchorPoint`; it
			-- pivots about the element's CENTRE, so a beater's arrow pointed NORTH while her word
			-- `ROAD` and the road itself were south. This case is the number that would have.
			local bearing = MapUi.pushBearingDeg()
			if bearing == nil then
				return
			end
			MapUi.setOpen(false)
			MapUi.setSuppressed(false)
			MapUi.render()
			local mini = Hud.minimap() :: Frame
			local own = mini:FindFirstChild("Own") :: Frame
			local arrow = mini:FindFirstChild("PushArrow") :: Frame
			expect(own.Visible).to.equal(true)
			expect(arrow.Visible).to.equal(true)
			local du, dv = MapUi.facingOffsetPx(bearing :: number, CONFIG.ARROW_LENGTH_PX / 2)
			expect(arrow.Position.X.Offset - own.Position.X.Offset).to.equal(math.round(du))
			expect(arrow.Position.Y.Offset - own.Position.Y.Offset).to.equal(math.round(dv))
			-- ...and the WORD is further out along the SAME line, never on the other side of the
			-- player from the arrow (task 153 round 2's finding, in two dimensions).
			local word = mini:FindFirstChild("PushWord") :: TextLabel
			local wu, wv = MapUi.facingOffsetPx(bearing :: number, CONFIG.ARROW_LENGTH_PX + 10)
			expect(word.Position.X.Offset - own.Position.X.Offset).to.equal(math.round(wu))
			expect(word.Position.Y.Offset - own.Position.Y.Offset).to.equal(math.round(wv))
			expect(math.abs(wv) > math.abs(dv) or math.abs(wu) > math.abs(du)).to.equal(true)
		end)

		it("draws no arrow and no word when the world has stated no direction", function()
			local was, wasLabel = MapUi.pushBearingDeg(), MapUi.pushLabel()
			MapUi.setPush(nil, nil)
			expect(MapUi.pushBearingDeg()).to.equal(nil)
			expect(MapUi.pushLabel()).to.equal(nil)
			MapUi.render()
			local mini = Hud.minimap() :: Frame
			local arrow = mini:FindFirstChild("PushArrow")
			expect(arrow).to.be.ok()
			expect((arrow :: Frame).Visible).to.equal(false)
			MapUi.setPush(was, wasLabel)
		end)
	end)

	describe("M really arrives from a real key", function()
		it("counted two toggles that came from the KEY, not from a caller", function()
			-- `tests/client/input_scenarios.txt` presses M twice. This is rule 6 -- the player's
			-- path, not the harness's -- and the FIRST version of this case did not test it (task
			-- 155 round 1, the Reviewer's blocking finding): it asserted `stats().toggles >= 2`,
			-- and `toggles` counts every change including this spec's own `setOpen` calls, so the
			-- case passed with the M binding deleted.
			--
			-- `keyToggles` is incremented ONLY inside the bound action's `Begin`, so nothing a spec
			-- calls can reach it. If the scenario's two presses do not arrive, this fails.
			-- IT WAITS FOR THE KEY, AND THAT IS THE WHOLE OF TASK 157's FIX HERE.
			--
			-- THE CASE AND THE REPLAY RACE, and until this task the race happened to land the right
			-- way. The harness replays only once every input spec has published readiness -- so the
			-- replay STARTS at about the moment TestEZ starts running cases -- and `map-toggle` is
			-- the FIFTH of six scenarios, about 25 s into a 43 s replay (`input_scenarios.txt`:
			-- `key-mouse-order`, `weapon-fire-reload-ammo`, `aim-hold`, `shoot-the-boar`, then this
			-- one). `map_ui.spec` is the NINTH of sixteen client specs alphabetically, so TestEZ can
			-- reach this case well before the M presses are sent. Reading the counter at that moment
			-- asserts the replay's SCHEDULE, not the player's path.
			--
			-- MEASURED, task 157: with only the DEV Studio open the case ran first and read 0
			-- (`keyToggles=0 toggles=8 ticks=742 builtAt=…` -- the map had been built 45 s earlier
			-- and the binding was there), while a run with a second Studio open was slow enough that
			-- the presses arrived first and it read 2. A probe in a bare Play session proved the key
			-- path itself: a replayed M flipped `FullMap` false -> true -> false, and a respawn does
			-- not clear the binding.
			--
			-- SO IT WAITS, bounded, exactly as `weapon_client` and `match_teams` wait for what the
			-- replay sends them. THE ASSERTION IS UNCHANGED: `keyToggles` is incremented only inside
			-- the bound action's `Begin`, so nothing this spec does can move it (task 155 round 1,
			-- the Reviewer's rule-6 finding), and a key that never arrives still fails here.
			local arrived = waitForKeys(KEY_TIMEOUT_SECONDS, 2)
			local seen = MapUi.stats()
			TestKit.note(
				string.format(
					"map keys: keyToggles=%d after %.1f s (toggles=%d ticks=%d builtAt=%s)",
					seen.keyToggles,
					arrived,
					seen.toggles,
					seen.ticks,
					tostring(seen.builtAt)
				)
			)
			expect(MapUi.stats().keyToggles).to.equal(2)
			-- ...and the binding is really there, under its own reserved name.
			local actions = MapUi.boundActions()
			expect(#actions).to.equal(1)
			expect(ContextActionService:GetAllBoundActionInfo()[actions[1]]).to.be.ok()
		end)
	end)

	describe("the map is left as this world had it", function()
		it("leaves it closed, unsuppressed and on this player's own direction", function()
			-- A harness run must never leave Karen's screen with a map open over her gun.
			MapUi.setOpen(false)
			MapUi.setSuppressed(false)
			-- ...and the screen is this screen's, not a size some case pinned.
			MapUi.applyLayout(nil)
			expect(MapUi.pinnedViewport()).to.equal(nil)
			if Map.EXPECTED_WORLD == "forest-test" then
				local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
				local team = player.Team
				local bearing, label = Hud.driveBearing(data, if team then team.Name else nil)
				MapUi.setPush(bearing, label)
				expect(MapUi.pushBearingDeg()).to.equal(bearing)
			end
			MapUi.render()
			expect(MapUi.isOpen()).to.equal(false)
			expect((Hud.fullMap() :: Frame).Visible).to.equal(false)
		end)
	end)
end
