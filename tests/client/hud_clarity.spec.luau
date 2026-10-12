-- hud_clarity.spec: the objective line, the waypoint and the button rail, in the real client.
--
-- WHAT IT PROVES AND WHAT IT CANNOT. The sentence, the target, the projection, the two visibility
-- predicates and every rectangle are PURE -- phase and team in, text out; studs in, pixels out -- so
-- everything that could be arithmetically wrong is asserted here with hand-written values and no
-- drive, no world, no camera and no second player. `docs/PROJECT_CONTEXT.md`'s *"things measured
-- correct and looked wrong"* is survivable only that way round: the arithmetic is provable and the
-- LOOK is the one thing left for Karen's eye.
--
-- THE MOST VALUABLE CASE IN THIS FILE IS THE RECTANGLE ONE, for the reason `map_ui.spec` already
-- gives: task 125 round 2 shipped the compass strip over the drive bar and *"it was not seen because
-- the frames were taken in the Forest Test, where there is no bar at all"*. This task moved FIVE
-- bands at once and added two more, so the whole top of the screen is one rectangle argument -- and
-- it is checked at 400 x 800 as well as at this window, because a scale-anchored `Position` resolves
-- against the real screen and no tool here can resize a Studio viewport.
--
-- WHAT ONE CLIENT CANNOT PROVE, said out loud (rule 6, rule 8):
--   * THE TAP. A spec cannot fire `GuiButton.Activated`, the harness cannot synthesise a touch, and
--     a `moveTo` step in `tests/client/input_scenarios.txt` carries STATIC pixel coordinates while
--     the rail is anchored to the right edge of a Play window whose size is not fixed (969 x 784 in
--     one task 155 run). So `Rail.press` is the seam these cases drive, and what they prove is the
--     ACTION, not the touch. The fix is a scenario step that names a GuiObject and resolves its
--     centre at replay time -- harness work, queued as 165a.
--   * `Scoring`. A drive is 600 s long, so no client run reaches it; the pure cases cover its two
--     strings and the live case asserts whatever phase the run IS in.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/hud-clarity.md - note: docs/research/2026-10-12-hud-clarity.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local Objective = Hud.Objective
local Rail = Hud.Rail
local MapUi = Hud.MapUi
local Compass = Hud.Compass
local CONFIG = Objective.CONFIG

-- A GEOMETRY WITH ROUND NUMBERS, so every expectation below is arithmetic a reader can check: a
-- straight road at z = 0 from x = -100 to x = 100, and three stands 100 studs apart on it.
local function flatGeometry()
	return {
		world = "spec",
		bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
		road = { Vector2.new(-100, 0), Vector2.new(100, 0) },
		stands = { Vector2.new(-100, 0), Vector2.new(0, 0), Vector2.new(100, 0) },
	}
end

-- ...and a BENT one, so the interpolation is exercised rather than the two-point special case.
local function bentGeometry()
	return {
		world = "spec",
		bounds = { minX = -100, maxX = 100, minZ = -100, maxZ = 100 },
		road = { Vector2.new(-100, 0), Vector2.new(0, 50), Vector2.new(100, 0) },
		stands = {},
	}
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh): boolean
	return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

-- EVERY BAND OF THE TOP OF THE SCREEN AT A GIVEN VIEWPORT, as rectangles, from the SAME constants
-- the renderers read -- never a number typed twice. The centred ones are computed the way
-- `Hud.build` anchors them (centre, fixed width), which is what makes a clash at 400 px visible.
local function bands(viewport: Vector2)
	local function centred(width: number, top: number, height: number)
		return { viewport.X / 2 - width / 2, top, width, height }
	end
	local ox, oy, ow, oh = Objective.lineRect(viewport)
	local mx, my, mw, mh = MapUi.minimapRect(viewport)
	local count = #Rail.BUTTONS
	local rx, ry, rw, rh =
		Rail.rect(viewport, MapUi.diameterFor(viewport.X, viewport.Y), MapUi.CONFIG.MINIMAP_TOP, count)
	return {
		{ name = "objective", rect = { ox, oy, ow, oh } },
		{ name = "driveBar", rect = centred(520, Drive.CONFIG.BAR_TOP_OFFSET, 26) },
		{ name = "tiedBanner", rect = centred(620, Drive.CONFIG.TIED_TOP_OFFSET, 30) },
		{ name = "compass", rect = centred(Compass.CONFIG.WIDTH, Compass.CONFIG.TOP, Compass.CONFIG.HEIGHT) },
		{ name = "minimap", rect = { mx, my, mw, mh } },
		{ name = "rail", rect = { rx, ry, rw, rh } },
	}
end

return function()
	describe("the sentence", function()
		it("says one thing per role and phase", function()
			local text = CONFIG.TEXT
			expect(Objective.text("Assigning", "Shooters")).to.equal(text.Shooters.Assigning)
			expect(Objective.text("Running", "Shooters")).to.equal(text.Shooters.Running)
			expect(Objective.text("Scoring", "Shooters")).to.equal(text.Shooters.Scoring)
			expect(Objective.text("Assigning", "Drivers")).to.equal(text.Drivers.Assigning)
			expect(Objective.text("Running", "Drivers")).to.equal(text.Drivers.Running)
			expect(Objective.text("Scoring", "Drivers")).to.equal(text.Drivers.Scoring)
			-- WAITING IS THE SAME SENTENCE FOR BOTH, with no reason attached: the drive bar already
			-- carries the reason, and two renderings of one reason is what this task removes.
			expect(Objective.text("Waiting", "Shooters")).to.equal(text.Waiting)
			expect(Objective.text("Waiting", "Drivers")).to.equal(text.Waiting)
			-- A hunter and a beater are never given the same instruction in a phase that HAS one.
			expect(Objective.text("Running", "Shooters")).never.to.equal(Objective.text("Running", "Drivers"))
		end)

		it("says NOTHING with no team, in every phase", function()
			-- The design's own ruling: a player with no team has no objective, and a sentence would be
			-- an instruction nobody gave. `Hud.roleWord` answers "" for the same case.
			for _, phase in ipairs({ "Waiting", "Assigning", "Running", "Scoring" }) do
				expect(Objective.text(phase, nil)).to.equal("")
				expect(Objective.text(phase, "Spectators")).to.equal("")
			end
			expect(Objective.text(nil, "Shooters")).to.equal("")
			expect(Objective.text(nil, nil)).to.equal("")
		end)

		it("is ASCII, and never an em dash", function()
			-- Everything drawn in this repo is ASCII (`Drive.CONFIG.TIED_TEXT`'s own rule). An em dash
			-- is the one character a rewrite is likely to introduce, so it is named.
			local seen = 0
			for _, team in ipairs({ "Shooters", "Drivers" }) do
				for _, phase in ipairs({ "Assigning", "Running", "Scoring" }) do
					local line = Objective.text(phase, team)
					expect(#line > 0).to.equal(true)
					for index = 1, #line do
						expect(string.byte(line, index) < 128).to.equal(true)
					end
					seen += 1
				end
			end
			expect(seen).to.equal(6)
			-- ...AND THE FOUR TASK-168 SENTENCES, which are drawn in the same label by the same
			-- renderer and are therefore held to the same rule. The countdown is formatted with a
			-- real number so what is checked is the sentence a player sees.
			local extra = {
				Objective.text("Assigning", "Drivers", { secondsLeft = 10 }),
				Objective.text("Running", "Drivers", { holdLeft = 2 }),
				Objective.text("Running", "Drivers", { holdLeft = 0, goAge = 0 }),
				Objective.text("Running", "Drivers", { through = true }),
			}
			for _, line in ipairs(extra) do
				expect(#line > 0).to.equal(true)
				for index = 1, #line do
					expect(string.byte(line, index) < 128).to.equal(true)
				end
			end
		end)

		it("FITS a phone's screen, measured by the engine and not by a font guess", function()
			-- THE ENGINE MEASURES IT. `TextFits` is the only honest answer to "does this sentence fit
			-- 400 px", because a width computed from a character count assumes a font's metrics.
			--
			-- ON A CLONE, NOT ON THE REAL LABEL, AND THE FIRST ROUND OF THIS TASK IS WHY. Measuring
			-- needs a frame to pass (`TextFits` is a layout result), and `Hud.renderObjective` writes
			-- that label's `Text` AND its `TextSize` EVERY frame -- so the save-and-restore idiom
			-- `map_ui.spec` uses for a `Visible` does not work for a property with a live writer: the
			-- run came back with all eight sentences "too long" because what was measured was the
			-- renderer's own 24 px text in a 368 px box. A clone in the same `ScreenGui` carries the
			-- same font, size and width and has no writer but this case.
			local label = Hud.objectiveLine()
			expect(label).to.be.ok()
			local node = (label :: TextLabel):Clone()
			node.Name = "SpecProbe"
			local _, _, width, height = Objective.lineRect(Vector2.new(400, 800))
			node.Size = UDim2.fromOffset(width, height)
			node.TextSize = Objective.textSizeFor(400)
			node.Visible = true
			node.Parent = (label :: TextLabel).Parent
			local tooLong = {}
			local longest = 0
			for _, team in ipairs({ "Shooters", "Drivers" }) do
				for _, phase in ipairs({ "Waiting", "Assigning", "Running", "Scoring" }) do
					local line = Objective.text(phase, team)
					longest = math.max(longest, #line)
					node.Text = line
					task.wait()
					if not node.TextFits then
						table.insert(tooLong, string.format("%s/%s (%d chars)", team, phase, #line))
					end
				end
			end
			-- THE BEATER'S FOUR TASK-168 SENTENCES ARE MEASURED THE SAME WAY, at the same 400 px: a
			-- countdown that does not fit a phone is a countdown nobody can read.
			local cases = {
				{ name = "countdown", drive = { secondsLeft = 10 } },
				{ name = "fanfare", drive = { holdLeft = 2 } },
				{ name = "go", drive = { holdLeft = 0, goAge = 0 } },
				{ name = "through", drive = { through = true } },
			}
			for _, case in ipairs(cases) do
				local phase = if case.drive.secondsLeft ~= nil then "Assigning" else "Running"
				local line = Objective.text(phase, "Drivers", case.drive)
				longest = math.max(longest, #line)
				node.Text = line
				task.wait()
				if not node.TextFits then
					table.insert(tooLong, string.format("Drivers/%s (%d chars)", case.name, #line))
				end
			end
			node:Destroy()
			expect(table.concat(tooLong, ", ")).to.equal("")
			-- The design's numeric target, so a rewrite that breaks it says so here.
			expect(longest <= 32).to.equal(true)
			TestKit.note(
				string.format(
					"objective: longest sentence %d chars, all fit %d px at TextSize %d",
					longest,
					width,
					Objective.textSizeFor(400)
				)
			)
		end)

		-- ---------------------------------------------------------------- task 168: the beater's drive
		--
		-- KAREN, 2026-10-12 ~21:45: *"you can't move as a beater before horn made signal and there
		-- should be countdown"*, and *"when beater cross the line of hunter it's done for him cant use
		-- sound anymore"*. The line is the only thing on screen that says either, and it is still PURE
		-- -- the clock is subtracted by the caller (`Match.holdSecondsLeft`, `Match.goAgeSeconds`), so
		-- every one of these is a number in and a sentence out.
		it("counts the countdown down for a beater, and for nobody else", function()
			local text = CONFIG.TEXT
			expect(Objective.text("Assigning", "Drivers", { secondsLeft = 10 })).to.equal("drive starts in 10")
			-- CEILING, so the last second reads "1" and not "0": the same rule the start card's own
			-- timer uses (`Hud.startCardTimerFor`), because they are the same deadline.
			expect(Objective.text("Assigning", "Drivers", { secondsLeft = 2.4 })).to.equal("drive starts in 3")
			expect(Objective.text("Assigning", "Drivers", { secondsLeft = 0.2 })).to.equal("drive starts in 1")
			expect(Objective.text("Assigning", "Drivers", { secondsLeft = 0 })).to.equal("drive starts in 0")
			-- A HUNTER'S COUNTDOWN IS HIS STAND TIMER AND IT IS ON THE CARD: his line is unchanged.
			expect(Objective.text("Assigning", "Shooters", { secondsLeft = 10 })).to.equal(text.Shooters.Assigning)
			-- AND WITH NOTHING KNOWN ABOUT THE DRIVE, the row stands -- which is what every caller
			-- before this task passed and is why the eight role-by-phase cases above did not change.
			expect(Objective.text("Assigning", "Drivers")).to.equal(text.Drivers.Assigning)
			expect(Objective.text("Assigning", "Drivers", {})).to.equal(text.Drivers.Assigning)
		end)

		it("holds the line while the fanfare sounds, then says GO, then the standing instruction", function()
			local text = CONFIG.TEXT
			-- THE DRIVE HAS STARTED AND THE HORN IS SOUNDING: he may not walk yet, and this is the
			-- only thing that tells him why.
			expect(Objective.text("Running", "Drivers", { holdLeft = 2.18 })).to.equal(text.DriverHorn)
			expect(Objective.text("Running", "Drivers", { holdLeft = 0.1 })).to.equal(text.DriverHorn)
			-- THEN GO, for the flash, counted from the moment the line was let go.
			expect(Objective.text("Running", "Drivers", { holdLeft = 0, goAge = 0 })).to.equal(text.DriverGo)
			expect(Objective.text("Running", "Drivers", { holdLeft = 0, goAge = CONFIG.GO_FLASH_SECONDS })).to.equal(
				text.DriverGo
			)
			-- ...AND THEN THE STANDING INSTRUCTION TAKES IT BACK, so a ten-minute drive is not spent
			-- being told to start.
			expect(Objective.text("Running", "Drivers", { holdLeft = 0, goAge = CONFIG.GO_FLASH_SECONDS + 0.1 })).to.equal(
				text.Drivers.Running
			)
			expect(Objective.text("Running", "Drivers", { holdLeft = 0, goAge = 400 })).to.equal(text.Drivers.Running)
			-- A HUNTER NEVER SEES ANY OF IT: he is not held and he has no GO.
			expect(Objective.text("Running", "Shooters", { holdLeft = 2, goAge = 0 })).to.equal(text.Shooters.Running)
			-- NOR DOES THE HOLD LEAK INTO ANOTHER PHASE: the results scene holds everybody, and
			-- "drive over" is the only thing worth saying there.
			expect(Objective.text("Scoring", "Drivers", { holdLeft = 2 })).to.equal(text.Drivers.Scoring)
		end)

		it("tells a beater who is through that his drive is over, and that beats everything else", function()
			local text = CONFIG.TEXT
			expect(Objective.text("Running", "Drivers", { through = true })).to.equal(text.DriverThrough)
			-- IT BEATS THE GO FLASH AND THE HOLD, because it is the newest true thing about him: he
			-- cannot be both pushing and finished.
			expect(Objective.text("Running", "Drivers", { through = true, goAge = 0, holdLeft = 2 })).to.equal(
				text.DriverThrough
			)
			-- ONLY WHILE THE DRIVE IS RUNNING. In the countdown of the NEXT drive he is not through
			-- anything -- the server clears the record at the phase boundary, and this says so even if
			-- a stale snapshot arrives first.
			expect(Objective.text("Assigning", "Drivers", { through = true, secondsLeft = 9 })).to.equal(
				"drive starts in 9"
			)
			expect(Objective.text("Scoring", "Drivers", { through = true })).to.equal(text.Drivers.Scoring)
			-- A HUNTER IS NEVER "THROUGH": the list only ever holds beaters, and his line is his.
			expect(Objective.text("Running", "Shooters", { through = true })).to.equal(text.Shooters.Running)
		end)

		it("has one text size break point", function()
			expect(Objective.textSizeFor(1920)).to.equal(CONFIG.TEXT_SIZE)
			expect(Objective.textSizeFor(CONFIG.SMALL_BELOW_PX)).to.equal(CONFIG.TEXT_SIZE)
			expect(Objective.textSizeFor(400)).to.equal(CONFIG.TEXT_SIZE_SMALL)
		end)
	end)

	describe("where the player must go", function()
		it("sends a hunter to the NEAREST stand", function()
			local geometry = flatGeometry()
			local target = Objective.targetFor("Shooters", "Running", geometry, Vector3.new(10, 5, 3))
			expect(target).to.be.ok()
			local at = target :: any
			expect(at.point.X).to.be.near(0, 1e-6)
			expect(at.point.Z).to.be.near(0, 1e-6)
			expect(at.word).to.equal(CONFIG.WORD_STAND)
			expect(at.kind).to.equal("stand")
			-- The player's OWN height, which is the stated choice: `MapGeometry` is flat.
			expect(at.point.Y).to.be.near(5, 1e-6)
		end)

		it("gives the NEIGHBOUR'S stand once he has walked past half the spacing", function()
			-- THE FAILURE CASE, ASSERTED SO IT IS A DECISION AND NOT A SURPRISE. Stands are 150 studs
			-- apart in the Forest Test, so the nearest one is his until he walks 75; past that the
			-- chevron silently becomes his neighbour's. The fix is the drive publishing the assigned
			-- stand, which is a new snapshot field and is queued as 165a.
			local geometry = flatGeometry()
			local target = Objective.targetFor("Shooters", "Running", geometry, Vector3.new(80, 0, 0))
			expect((target :: any).point.X).to.be.near(100, 1e-6)
		end)

		it("gives a hunter the LINE in a world that has stated no stands", function()
			-- The DEV world: `MapUi.geometryFromMap` returns `stands = {}` deliberately, and
			-- `Match.CONFIG.ODD_PLAYER_TEAM` is "Shooters", so a solo player there IS a hunter. The
			-- word says LINE and not STAND, because the world has not said which post is his.
			local geometry = flatGeometry()
			geometry.stands = {}
			local target = Objective.targetFor("Shooters", "Running", geometry, Vector3.new(40, 2, 90))
			expect(target).to.be.ok()
			local at = target :: any
			expect(at.word).to.equal(CONFIG.WORD_LINE)
			expect(at.kind).to.equal("line")
			expect(at.point.X).to.be.near(40, 1e-6)
			expect(at.point.Z).to.be.near(0, 1e-6)
		end)

		it("sends a beater STRAIGHT AHEAD to the road at her own x", function()
			local target = Objective.targetFor("Drivers", "Running", flatGeometry(), Vector3.new(-37, 0, 400))
			expect(target).to.be.ok()
			local at = target :: any
			expect(at.word).to.equal(CONFIG.WORD_ROAD)
			expect(at.point.X).to.be.near(-37, 1e-6)
			expect(at.point.Z).to.be.near(0, 1e-6)
		end)

		it("interpolates a bent road rather than re-typing its curve", function()
			local road = bentGeometry().road
			expect(Objective.roadZAt(road, -100)).to.be.near(0, 1e-9)
			expect(Objective.roadZAt(road, -50)).to.be.near(25, 1e-9)
			expect(Objective.roadZAt(road, 0)).to.be.near(50, 1e-9)
			expect(Objective.roadZAt(road, 50)).to.be.near(25, 1e-9)
			-- PAST EITHER END, x IS CLAMPED: a beater off the end of the world is sent back to the
			-- end of the line, not to a point that does not exist.
			expect(Objective.roadZAt(road, -5000)).to.be.near(0, 1e-9)
			expect(Objective.roadZAt(road, 5000)).to.be.near(0, 1e-9)
			expect(Objective.roadZAt({}, 0)).to.equal(nil)
		end)

		it("sends nobody anywhere in Waiting or Scoring, or with nothing stated", function()
			local geometry = flatGeometry()
			local me = Vector3.new(0, 0, 50)
			expect(Objective.targetFor("Shooters", "Waiting", geometry, me)).to.equal(nil)
			expect(Objective.targetFor("Shooters", "Scoring", geometry, me)).to.equal(nil)
			expect(Objective.targetFor("Shooters", nil, geometry, me)).to.equal(nil)
			-- D5: a world that has stated no geometry gets NO waypoint, never a guess.
			expect(Objective.targetFor("Shooters", "Running", nil, me)).to.equal(nil)
			-- No character yet: no position, so nothing to measure from.
			expect(Objective.targetFor("Shooters", "Running", geometry, nil)).to.equal(nil)
			-- No team, no objective.
			expect(Objective.targetFor(nil, "Running", geometry, me)).to.equal(nil)
			expect(Objective.targetFor("Spectators", "Running", geometry, me)).to.equal(nil)
		end)

		it("measures the distance from the PLAYER, in studs", function()
			local target = { point = Vector3.new(30, 100, 40), word = "X", kind = "x" }
			-- 30/40/50, and the height is ignored: he walks on the ground.
			expect(Objective.distanceStuds(target, Vector3.new(0, 0, 0))).to.be.near(50, 1e-6)
			expect(Objective.distanceStuds(nil, Vector3.new(0, 0, 0))).to.equal(nil)
			expect(Objective.distanceStuds(target, nil)).to.equal(nil)
		end)

		it("latches ARRIVED with a dead band, so the chevron cannot flicker", function()
			-- IN at 24, and not back OUT until 30 -- both directions, which is what proves the
			-- hysteresis exists rather than one threshold written twice. Driven off the config, so
			-- the next time the band follows the stand's radius this case follows it too.
			local inAt = CONFIG.ARRIVED_IN_STUDS
			local outAt = CONFIG.ARRIVED_OUT_STUDS
			expect(Objective.arrived(inAt + 1, false)).to.equal(false)
			expect(Objective.arrived(inAt, false)).to.equal(true)
			expect(Objective.arrived(inAt + 1, true)).to.equal(true)
			expect(Objective.arrived(outAt - 0.1, true)).to.equal(true)
			expect(Objective.arrived(outAt, true)).to.equal(false)
			expect(Objective.arrived(nil, true)).to.equal(false)
			expect(outAt > inAt).to.equal(true)
			-- TASK 166: THE BAND IS OUTSIDE THE CIRCLE A HUNTER MAY LEGALLY WALK IN. The stand's
			-- radius went 6 -> 12, and an "arrived" ring inside 12 would flicker at exactly the
			-- place he is meant to be standing. 24 is twice the radius, with the same 6-stud band.
			expect(inAt).to.equal(24)
			expect(outAt).to.equal(30)
		end)

		it("writes the distance in METRES, through the one conversion", function()
			local target = { point = Vector3.new(0, 0, 0), word = "ROAD", kind = "road" }
			expect(Objective.markText(target, 100)).to.equal(string.format("ROAD  %d m", Report.metres(100)))
			expect(Objective.markText(target, nil)).to.equal("ROAD")
			expect(Objective.markText(nil, 100)).to.equal("")
		end)
	end)

	describe("the projection", function()
		it("puts a point dead ahead dead centre", function()
			local view = CFrame.new(Vector3.new(0, 0, 0))
			-- A default `CFrame` looks down -Z, so 100 studs along -Z is straight in front.
			local u, v, onScreen = Objective.project(Vector3.new(0, 0, -100), view, 70, Vector2.new(1920, 1080))
			expect(u).to.be.near(0, 1e-6)
			expect(v).to.be.near(0, 1e-6)
			expect(onScreen).to.equal(true)
		end)

		it("is a PERSPECTIVE projection, which four properties pin down and no copy of the formula does", function()
			-- TASK 129 SPENT THREE ROUNDS on a case that copied the expression under test into itself
			-- and *"agreed with the wrong one"*, so this case asserts PROPERTIES instead. Each of the
			-- four is a consequence of `px = f * x / -z` with `f = (Y/2)/tan(fov/2)` that a wrong
			-- formula does not have -- in particular the LINEAR form `Y * deg / fov` fails (1) and (3).
			local fov, viewportY = 70, 1080
			local viewport = Vector2.new(1920, viewportY)
			local view = CFrame.new(Vector3.new(0, 0, 0))
			local function atDeg(deg: number, fovDeg: number, port: Vector2): number
				local radians = math.rad(deg)
				local u = Objective.project(
					Vector3.new(math.sin(radians) * 1000, 0, -math.cos(radians) * 1000),
					view,
					fovDeg,
					port
				)
				return u
			end
			-- (1) THE TANGENT LAW. Doubling the angle multiplies the pixels by tan(2d)/tan(d), which
			-- is more than 2 -- a linear mapping would give exactly 2.
			local one, two = atDeg(5, fov, viewport), atDeg(10, fov, viewport)
			expect(two / one).to.be.near(math.tan(math.rad(10)) / math.tan(math.rad(5)), 1e-6)
			expect(two / one > 2).to.equal(true)
			-- (2) DISTANCE DOES NOT MATTER. Twice as far along the same ray is the same pixel.
			local near = Objective.project(Vector3.new(50, 20, -100), view, fov, viewport)
			local far = Objective.project(Vector3.new(100, 40, -200), view, fov, viewport)
			expect(near).to.be.near(far, 1e-6)
			-- (3) HALVING THE FIELD OF VIEW MAGNIFIES BY tan(fov/2)/tan(fov'/2), which is what makes
			-- one reticle true at any magnification. 70 -> 35 is 2.22x, not 2x.
			local zoomed = atDeg(5, 35, viewport)
			expect(zoomed / one).to.be.near(math.tan(math.rad(35)) / math.tan(math.rad(17.5)), 1e-6)
			-- (4) TWICE THE VIEWPORT HEIGHT IS TWICE THE PIXELS, because the fov is VERTICAL.
			local tall = atDeg(5, fov, Vector2.new(1920, 2 * viewportY))
			expect(tall / one).to.be.near(2, 1e-6)
		end)

		it("DIFFERS from Hud.reticleDegToPx by 15 per cent, and that is reported rather than asserted", function()
			-- A MEASUREMENT, NOT A CLAIM OF AGREEMENT (rule 8). The design asked for this projection to
			-- be compared against `Hud.reticleDegToPx` as *"an INDEPENDENT expression of the same
			-- relation"*. IT IS NOT THE SAME RELATION, and the number is worth writing down: the
			-- scope's conversion is the LINEAR screen mapping `viewportY * deg / fov`, while a
			-- perspective camera puts an angle at `f * tan(deg)`. At the screen centre the ratio is
			-- `2 * tan(fov/2) / fov_in_radians`, which at fov 70 is 1.146 -- so the duplex's elements
			-- are drawn about 15 % further from the centre than the world behind them is.
			--
			-- NOTHING HERE DEPENDS ON IT and nothing in this task changes it: the scope was tuned and
			-- photographed against its own conversion (task 141), the reticle is a mark on glass
			-- rather than a thing registered to the world, and `src/client/Camera` is out of this
			-- task's scope. It is queued as a finding so the next scope task knows the number.
			local fov, viewportY = 70, 1080
			local viewport = Vector2.new(1920, viewportY)
			local view = CFrame.new(Vector3.new(0, 0, 0))
			local radians = math.rad(1)
			local exact = Objective.project(
				Vector3.new(math.sin(radians) * 1000, 0, -math.cos(radians) * 1000),
				view,
				fov,
				viewport
			)
			local linear = Hud.reticleDegToPx(1, fov, viewportY)
			local predicted = 2 * math.tan(math.rad(fov / 2)) / math.rad(fov)
			expect(linear / exact).to.be.near(predicted, 0.01)
			TestKit.note(
				string.format(
					"projection: 1 deg is %.2f px exact against %.2f px by Hud.reticleDegToPx "
						.. "(ratio %.3f, predicted %.3f) at fov %d, viewportY %d",
					exact,
					linear,
					linear / exact,
					predicted,
					fov,
					viewportY
				)
			)
		end)

		it("puts up UP and right RIGHT", function()
			local view = CFrame.new(Vector3.new(0, 0, 0))
			local viewport = Vector2.new(1920, 1080)
			local ru = Objective.project(Vector3.new(50, 0, -100), view, 70, viewport)
			expect(ru > 0).to.equal(true)
			local _, uv = Objective.project(Vector3.new(0, 50, -100), view, 70, viewport)
			-- Screen y grows DOWNWARD, so something above the axis is NEGATIVE v.
			expect(uv < 0).to.equal(true)
		end)

		it("PINS to the edge instead of hiding, and says it pinned", function()
			local view = CFrame.new(Vector3.new(0, 0, 0))
			local viewport = Vector2.new(1920, 1080)
			-- Far to the right and barely in front: way off the edge.
			local u, v, onScreen = Objective.project(Vector3.new(5000, 0, -100), view, 70, viewport)
			expect(onScreen).to.equal(false)
			expect(u).to.be.near(viewport.X / 2 - CONFIG.INSET_RIGHT_PX, 1e-6)
			expect(math.abs(v) <= viewport.Y / 2 - CONFIG.INSET_PX + 1e-6).to.equal(true)
			-- THE RIGHT INSET IS BIGGER THAN THE OTHERS, so a pinned chevron never lands under a
			-- rail button. That is the whole reason the box is not symmetric.
			local lu = Objective.project(Vector3.new(-5000, 0, -100), view, 70, viewport)
			expect(lu).to.be.near(-(viewport.X / 2 - CONFIG.INSET_PX), 1e-6)
			expect(CONFIG.INSET_RIGHT_PX > CONFIG.INSET_PX).to.equal(true)
		end)

		it("treats BEHIND as a direction, not a point", function()
			local view = CFrame.new(Vector3.new(0, 0, 0))
			local viewport = Vector2.new(1920, 1080)
			-- Behind and to the right: +Z is behind a camera that looks down -Z.
			local u, v, onScreen = Objective.project(Vector3.new(60, 90, 100), view, 70, viewport)
			expect(onScreen).to.equal(false)
			expect(u > 0).to.equal(true)
			-- MID HEIGHT, because a point behind the camera has no honest vertical position.
			expect(v).to.be.near(0, 1e-6)
			local lu = Objective.project(Vector3.new(-60, 0, 100), view, 70, viewport)
			expect(lu < 0).to.equal(true)
			-- Dead behind pins RIGHT: arbitrary, deterministic, and asserted so it cannot drift.
			local du = Objective.project(Vector3.new(0, 0, 100), view, 70, viewport)
			expect(du > 0).to.equal(true)
		end)
	end)

	describe("what hides what", function()
		it("hides BOTH when something bigger is up", function()
			local target = { point = Vector3.new(0, 0, 0), word = "ROAD", kind = "road" }
			-- report open, map open, scope in: nothing of this task is drawn.
			expect(Objective.lineVisible("Running", "Shooters", true, false, false, false)).to.equal(false)
			expect(Objective.lineVisible("Running", "Shooters", false, true, false, false)).to.equal(false)
			expect(Objective.lineVisible("Running", "Shooters", false, false, true, false)).to.equal(false)
			expect(Objective.markVisible(target, true, false, false, true)).to.equal(false)
			expect(Objective.markVisible(target, false, true, false, true)).to.equal(false)
			expect(Objective.markVisible(target, false, false, true, true)).to.equal(false)
		end)

		it("stands the LINE down for the start card and keeps the CHEVRON up", function()
			-- THE ONE ROW WHERE THE TWO PREDICATES DIFFER, which is the design's ruling: in `Assigning`
			-- the card's own timer already reads GET TO YOUR STAND, so two renderings of one
			-- instruction 140 px apart is the duplication this task removes. The card says WHAT and
			-- the chevron says WHERE, and that is the moment the arrow matters most.
			local target = { point = Vector3.new(0, 0, 0), word = "STAND", kind = "stand" }
			expect(Objective.lineVisible("Assigning", "Shooters", false, false, false, true)).to.equal(false)
			expect(Objective.markVisible(target, false, false, false, true)).to.equal(true)
			-- ...and the line takes over the moment the card goes.
			expect(Objective.lineVisible("Assigning", "Shooters", false, false, false, false)).to.equal(true)
		end)

		it("draws no chevron with no target and no view", function()
			local target = { point = Vector3.new(0, 0, 0), word = "ROAD", kind = "road" }
			expect(Objective.markVisible(nil, false, false, false, true)).to.equal(false)
			-- NO VIEW, NO CHEVRON: a mark drawn from a stale camera is in the wrong PLACE, which is a
			-- lie in the shape of a fact. (The compass keeps its last heading instead, on purpose.)
			expect(Objective.markVisible(target, false, false, false, false)).to.equal(false)
		end)

		it("draws no line when there is no sentence", function()
			expect(Objective.lineVisible("Running", nil, false, false, false, false)).to.equal(false)
			expect(Objective.lineVisible(nil, "Shooters", false, false, false, false)).to.equal(false)
		end)
	end)

	describe("the compass, the map and the chevron agree", function()
		it("points the strip at the TARGET when there is one, and at the WORLD when there is not", function()
			local me = Vector3.new(0, 0, 0)
			-- 100 studs north (+Z) is bearing 0; 100 east (+X) is 90.
			local north = { point = Vector3.new(0, 0, 100), word = "ROAD", kind = "road" }
			local deg, word = Hud.markerFor(north, me, 123, "WORLD")
			expect(deg).to.be.near(0, 1e-6)
			expect(word).to.equal("ROAD")
			local east = { point = Vector3.new(100, 0, 0), word = "STAND", kind = "stand" }
			local eastDeg = Hud.markerFor(east, me, 123, "WORLD")
			expect(eastDeg).to.be.near(90, 1e-6)
			-- AGAINST `Compass.headingDeg` OF THE SAME VECTOR, not against a copy of the expression:
			-- the convention was settled in task 129 against a photograph of four neon posts.
			expect(eastDeg).to.be.near(Compass.headingDeg(Vector3.new(100, 0, 0)), 1e-6)
			expect(Hud.markerFor(north, me, 123, "WORLD")).to.be.near(Compass.headingDeg(Vector3.new(0, 0, 100)), 1e-6)
			-- NO TARGET: the world's own answer, untouched -- which is the right answer, because a
			-- hunter who has ARRIVED wants the strip back on where the drive is coming from.
			local worldDeg, worldWord = Hud.markerFor(nil, me, 123, "WORLD")
			expect(worldDeg).to.equal(123)
			expect(worldWord).to.equal("WORLD")
			expect(Hud.markerFor(nil, me, nil, nil)).to.equal(nil)
			-- Standing exactly on it is noise, so the world's answer stands.
			local onIt = { point = Vector3.new(0, 9, 0), word = "STAND", kind = "stand" }
			expect(Hud.markerFor(onIt, me, 123, "WORLD")).to.equal(123)
		end)

		it("hands the map the SAME point, flat", function()
			MapUi.setTarget(Vector2.new(12, -34), "STAND")
			local point, word = MapUi.target()
			expect(point).to.be.ok()
			expect((point :: Vector2).X).to.be.near(12, 1e-9)
			expect((point :: Vector2).Y).to.be.near(-34, 1e-9)
			expect(word).to.equal("STAND")
			MapUi.setTarget(nil, nil)
			local cleared = MapUi.target()
			expect(cleared).to.equal(nil)
		end)
	end)

	describe("the button rail", function()
		it("shows on a touch device, and on this desktop by the one boolean", function()
			expect(Rail.visible(true)).to.equal(true)
			expect(Rail.visible(false)).to.equal(Rail.CONFIG.SHOW_ON_DESKTOP)
		end)

		it("hides a weapon button when there is no weapon, and nothing else", function()
			local hidden, shown = {}, {}
			for _, button in ipairs(Rail.BUTTONS) do
				if Rail.buttonVisible(button, false) then
					table.insert(shown, button.id)
				else
					table.insert(hidden, button.id)
				end
				-- With a weapon, every button is drawn.
				expect(Rail.buttonVisible(button, true)).to.equal(true)
			end
			expect(table.concat(hidden, ",")).to.equal("RELOAD,AMMO")
			expect(table.concat(shown, ",")).to.equal("MAP,REPORT")
		end)

		it("has a real action behind every button it draws", function()
			-- D9, "no dead buttons", as a check rather than a comment: `Rail.start` builds a node only
			-- when it was handed the module that answers it, so what is on screen is what works.
			local ids = Rail.buttonIds()
			expect(#ids > 0).to.equal(true)
			for _, id in ipairs(ids) do
				local node = Rail.button(id)
				expect(node).to.be.ok()
				expect(#(node :: TextButton).Text > 0).to.equal(true)
			end
			TestKit.note(
				string.format("rail: %s (touch=%s)", table.concat(ids, ","), tostring(UserInputService.TouchEnabled))
			)
		end)

		it("lives inside the one Hud ScreenGui", function()
			local rail = Hud.rail()
			expect(rail).to.be.ok()
			expect((rail :: Frame):IsDescendantOf(player.PlayerGui)).to.equal(true)
			local line = Hud.objectiveLine()
			expect((line :: TextLabel):IsDescendantOf(player.PlayerGui)).to.equal(true)
			expect((Hud.waypoint() :: Frame):IsDescendantOf(player.PlayerGui)).to.equal(true)
		end)

		it("MAP leads to the same room the M key does", function()
			-- WHAT THIS PROVES IS THE ACTION, NOT THE TAP (see the header). A spec cannot fire
			-- `Activated`, so `Rail.press` -- the one function every button's `Activated` calls -- is
			-- the seam, and the thing proved is that the second door opens the same map.
			local was = MapUi.isOpen()
			local toggles = MapUi.stats().toggles
			expect(Rail.press("MAP")).to.equal(true)
			expect(MapUi.isOpen()).to.equal(not was)
			expect(MapUi.stats().toggles > toggles).to.equal(true)
			Rail.press("MAP")
			expect(MapUi.isOpen()).to.equal(was)
			expect(Rail.stats().byId.MAP >= 2).to.equal(true)
		end)

		it("REPORT opens and closes the drive report", function()
			local was = Hud.Report.isOpen()
			expect(Rail.press("REPORT")).to.equal(true)
			expect(Hud.Report.isOpen()).to.equal(not was)
			Rail.press("REPORT")
			expect(Hud.Report.isOpen()).to.equal(was)
		end)

		it("refuses nothing it does not have", function()
			expect(Rail.press("NOT_A_BUTTON")).to.equal(false)
		end)
	end)

	describe("the rectangles do not overlap", function()
		it("keeps every band of the top of the screen clear of every other, at three viewports", function()
			-- THE MOST VALUABLE CASE IN THIS FILE. This task moved FIVE bands and added two, and the
			-- numbers it moved them to are only right if nothing lands on anything -- at a PHONE as
			-- well as at this window. `AbsolutePosition` cannot answer for 400 x 800 (no tool here can
			-- resize a Studio viewport), so the rectangles are computed from the same constants the
			-- renderers read and compared arithmetically.
			local clashes = {}
			for _, viewport in ipairs({ Vector2.new(400, 800), Vector2.new(800, 600), Vector2.new(1920, 1080) }) do
				local list = bands(viewport)
				for i = 1, #list do
					for j = i + 1, #list do
						local a, b = list[i], list[j]
						if
							rectsOverlap(
								a.rect[1],
								a.rect[2],
								a.rect[3],
								a.rect[4],
								b.rect[1],
								b.rect[2],
								b.rect[3],
								b.rect[4]
							)
						then
							table.insert(
								clashes,
								string.format("%.0fx%.0f %s/%s", viewport.X, viewport.Y, a.name, b.name)
							)
						end
					end
				end
			end
			expect(table.concat(clashes, ", ")).to.equal("")
		end)

		it("keeps the full map clear of the rail, which cannot hide while the map is open", function()
			-- THE HOLE THE RESERVED COLUMN CLOSES. The minimap never had this problem because
			-- `minimapVisible` hides it while the map is open; the rail CANNOT hide, because on a
			-- phone it is the only way to close the map.
			local clashes = {}
			for _, viewport in ipairs({ Vector2.new(400, 800), Vector2.new(800, 600), Vector2.new(1920, 1080) }) do
				local fx, fy, fw, fh = MapUi.fullMapRect(viewport)
				local rx, ry, rw, rh = Rail.rect(
					viewport,
					MapUi.diameterFor(viewport.X, viewport.Y),
					MapUi.CONFIG.MINIMAP_TOP,
					#Rail.BUTTONS
				)
				if rectsOverlap(fx, fy, fw, fh, rx, ry, rw, rh) then
					table.insert(clashes, string.format("%.0fx%.0f", viewport.X, viewport.Y))
				end
			end
			expect(table.concat(clashes, ", ")).to.equal("")
			-- ...and the reserved column really is the rail's own width plus its margin and a gap.
			expect(MapUi.CONFIG.RAIL_COLUMN_PX).to.equal(Rail.CONFIG.BUTTON_PX + Rail.CONFIG.MARGIN + 8)
		end)

		it("hangs the rail under the minimap at every viewport", function()
			for _, viewport in ipairs({ Vector2.new(400, 800), Vector2.new(1920, 1080) }) do
				local _, my, _, mh = MapUi.minimapRect(viewport)
				local _, ry = Rail.rect(
					viewport,
					MapUi.diameterFor(viewport.X, viewport.Y),
					MapUi.CONFIG.MINIMAP_TOP,
					#Rail.BUTTONS
				)
				expect(ry >= my + mh).to.equal(true)
			end
		end)

		it("hides the legend where no font inside the panel could be read", function()
			expect(MapUi.legendVisible(1)).to.equal(true)
			expect(MapUi.legendVisible(0.7)).to.equal(true)
			expect(MapUi.legendVisible(0.3)).to.equal(false)
			expect(#MapUi.legendRows()).to.equal(6)
			local legend = Hud.mapLegend()
			expect(legend).to.be.ok()
			-- It is the MAP's, drawn inside the panel, so it cannot outlive the panel being closed.
			expect((legend :: Frame):IsDescendantOf(Hud.fullMap() :: Frame)).to.equal(true)
		end)
	end)

	describe("what is actually drawn, live", function()
		it("draws EXACTLY what the rule says, in whatever phase this run is in", function()
			-- VALID IN EVERY PHASE, so it needs no phase to be arranged: it compares the LABEL against
			-- the PURE function, which is the one check that catches a renderer that stopped following
			-- the rule. (A one-player run does reach `Running` -- `Match.CONFIG.MIN_PLAYERS` is 1 --
			-- but WHICH phase it is in when this case runs is not something a spec may assume.)
			local Match = scripts:FindFirstChild("Match")
			local phase, team = nil, (if player.Team then player.Team.Name else nil)
			if Match ~= nil then
				local replica = require(Match)
				phase = replica.phase()
				team = replica.myTeam() or team
			end
			local label = Hud.objectiveLine() :: TextLabel
			local wanted = Objective.text(phase, team)
			if label.Visible then
				expect(label.Text).to.equal(wanted)
			else
				-- Hidden is only legitimate for a reason the predicate agrees with.
				expect(
					Objective.lineVisible(
						phase,
						team,
						Hud.Report.isOpen(),
						MapUi.isOpen(),
						Objective.isSuppressed(),
						Hud.isStartCardVisible()
					)
				).to.equal(false)
			end
			TestKit.note(
				string.format(
					"objective live: phase=%s team=%s visible=%s text=%q",
					tostring(phase),
					tostring(team),
					tostring(label.Visible),
					label.Text
				)
			)
		end)

		it("renders the chevron where the projection says, and dims it when pinned", function()
			-- HANDED ITS INPUTS, for the reason `Hud.renderScore` is public: a spec cannot turn a
			-- camera. Two renders, one in front and one far off the edge, and the node is read back.
			local view = CFrame.new(Vector3.new(0, 0, 0))
			local viewport = Vector2.new(1920, 1080)
			local mark = Hud.waypoint() :: Frame
			local word = Hud.waypointWord() :: TextLabel
			local ahead = { point = Vector3.new(0, 0, -100), word = "ROAD", kind = "road" }
			Objective.render({
				text = "",
				target = ahead,
				distanceStuds = 100,
				view = view,
				fovDeg = 70,
				viewport = viewport,
				lineVisible = false,
				markVisible = true,
			})
			expect(mark.Visible).to.equal(true)
			expect(Objective.isMarkPinned()).to.equal(false)
			expect(mark.BackgroundTransparency).to.be.near(0, 1e-6)
			expect(word.Text).to.equal(Objective.markText(ahead, 100))
			local u, v = Objective.markOffsetPx()
			expect(u).to.be.near(0, 1)
			expect(v).to.be.near(0, 1)

			local behind = { point = Vector3.new(5000, 0, 100), word = "STAND", kind = "stand" }
			Objective.render({
				text = "",
				target = behind,
				distanceStuds = 5000,
				view = view,
				fovDeg = 70,
				viewport = viewport,
				lineVisible = false,
				markVisible = true,
			})
			expect(mark.Visible).to.equal(true)
			expect(Objective.isMarkPinned()).to.equal(true)
			expect(mark.BackgroundTransparency).to.be.near(CONFIG.PINNED_TRANSPARENCY, 1e-6)

			-- ...and nothing is left on screen when there is nowhere to go.
			Objective.render({
				text = "",
				target = nil,
				distanceStuds = nil,
				view = view,
				fovDeg = 70,
				viewport = viewport,
				lineVisible = false,
				markVisible = false,
			})
			expect(mark.Visible).to.equal(false)
			expect(word.Visible).to.equal(false)
			expect(Objective.markOffsetPx()).to.equal(nil)
		end)

		it("draws ONE target mark on the map, and pins it when it is out of range", function()
			-- ONE drawer is live per tick (`MapUi.render` only renders a visible gate), so one mark.
			local far = Vector2.new(1e6, 1e6)
			MapUi.setTarget(far, "STAND")
			-- NO YIELD BETWEEN THE RENDER AND THE READ, and that is deliberate: the per-frame pass
			-- (`Hud.renderObjective`) is the one writer of the target and would overwrite this one on
			-- the very next frame. `render` writes `Visible` synchronously, so the picture is read in
			-- the same resumption it was drawn in.
			MapUi.render()
			local seen, pinned = 0, 0
			for _, holder in ipairs({ Hud.minimap(), Hud.fullMap() }) do
				for _, node in ipairs((holder :: Frame):GetDescendants()) do
					if node.Name == "Target" and node:IsA("Frame") and node.Visible then
						seen += 1
						if (node :: Frame).BackgroundTransparency > 0 then
							pinned += 1
						end
					end
				end
			end
			-- A world with no geometry draws no map at all, and then there is nothing to count: the
			-- claim is "never more than one", which holds either way.
			expect(seen <= 1).to.equal(true)
			if seen == 1 then
				expect(pinned).to.equal(1)
			end
			MapUi.setTarget(nil, nil)
			MapUi.render()
			TestKit.note(
				string.format(
					"map target: %d drawn, %d pinned (geometry=%s)",
					seen,
					pinned,
					tostring(MapUi.geometry() ~= nil)
				)
			)
		end)

		it("hides all three while the sight picture is in, and puts them back", function()
			local line = Hud.objectiveLine() :: TextLabel
			local rail = Hud.rail() :: Frame
			local wasRail = rail.Visible
			Objective.setSuppressed(true)
			Rail.setSuppressed(true)
			Objective.render({
				text = Objective.text("Running", "Shooters"),
				target = nil,
				distanceStuds = nil,
				view = CFrame.new(),
				fovDeg = 70,
				viewport = Vector2.new(1920, 1080),
				lineVisible = true,
				markVisible = false,
			})
			expect(line.Visible).to.equal(false)
			expect(rail.Visible).to.equal(false)
			Objective.setSuppressed(false)
			Rail.setSuppressed(false)
			Objective.render({
				text = Objective.text("Running", "Shooters"),
				target = nil,
				distanceStuds = nil,
				view = CFrame.new(),
				fovDeg = 70,
				viewport = Vector2.new(1920, 1080),
				lineVisible = true,
				markVisible = false,
			})
			expect(line.Visible).to.equal(true)
			expect(line.Text).to.equal(Objective.text("Running", "Shooters"))
			expect(rail.Visible).to.equal(wasRail)
		end)
	end)
end
