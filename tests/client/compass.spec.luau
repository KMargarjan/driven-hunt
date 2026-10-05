-- compass.spec: the compass strip, in the real client, on the real Hud.
--
-- A SPEC CANNOT TURN A CAMERA, so `Compass.render` takes a heading and the arithmetic is pure and
-- exported -- the same reason `Hud.renderScore` and `ReportPanel.render` are public. What is checked
-- here is the two things that can actually be wrong: the bearing convention (a compass that is 90
-- degrees out is worse than no compass) and whether the marks really move on screen.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local Compass = Hud.Compass
local CONFIG = Compass.CONFIG

return function()
	describe("the bearing convention", function()
		it("reads +Z as north and +X as east, clockwise", function()
			expect(Compass.headingDeg(Vector3.new(0, 0, 1))).to.be.near(0, 1e-3)
			expect(Compass.headingDeg(Vector3.new(1, 0, 0))).to.be.near(90, 1e-3)
			expect(Compass.headingDeg(Vector3.new(0, 0, -1))).to.be.near(180, 1e-3)
			expect(Compass.headingDeg(Vector3.new(-1, 0, 0))).to.be.near(270, 1e-3)
		end)

		it("ignores pitch, so looking at the sky does not spin the compass", function()
			local level = Compass.headingDeg(Vector3.new(0, 0, 1))
			local steep = Compass.headingDeg(Vector3.new(0, 8, 1))
			expect(steep).to.be.near(level, 1e-3)
		end)

		it("answers 0 rather than erroring when the look is straight down", function()
			expect(Compass.headingDeg(Vector3.new(0, 1, 0))).to.equal(0)
		end)
	end)

	describe("the shortest way round", function()
		it("puts a bearing just west of north on the LEFT, not 350 degrees right", function()
			expect(Compass.deltaDeg(0, 350)).to.be.near(-10, 1e-6)
			expect(Compass.deltaDeg(350, 0)).to.be.near(10, 1e-6)
			expect(Compass.deltaDeg(0, 180)).to.be.near(-180, 1e-6)
		end)
	end)

	describe("where a bearing lands on the strip", function()
		it("puts the heading itself dead centre", function()
			local x, onStrip = Compass.offsetPx(137, 137, CONFIG)
			expect(x).to.be.near(0, 1e-6)
			expect(onStrip).to.equal(true)
		end)

		it("scales by SPAN_DEG across the whole width", function()
			local x = Compass.offsetPx(0, CONFIG.SPAN_DEG / 4, CONFIG)
			expect(x).to.be.near(CONFIG.WIDTH / 4, 1e-6)
		end)

		it("pins a bearing behind the player to the nearer end and says it is not on the strip", function()
			local left, onLeft = Compass.offsetPx(0, 200, CONFIG)
			expect(onLeft).to.equal(false)
			expect(left).to.equal(-CONFIG.WIDTH / 2)
			local right, onRight = Compass.offsetPx(0, 160, CONFIG)
			expect(onRight).to.equal(false)
			expect(right).to.equal(CONFIG.WIDTH / 2)
		end)
	end)

	describe("where the heading comes from", function()
		-- THE ASSERTION THIS WHOLE TASK TURNED ON, and it took three rounds to get right. Two sources
		-- look correct and are not:
		--   `CurrentCamera.CFrame` -- measured 180 degrees away from the view at spawn, because
		--      `Camera.Rig` has a counted, warned-about FOREIGN WRITER of that property since task 123;
		--   the character's `HumanoidRootPart` -- measured by the Director with real mouse input: the
		--      view turned right round and the body's look never moved, because in first person the
		--      camera system turns the VIEW and not the BODY.
		-- The owner of the view publishes the view, and that is what the compass reads.
		-- THE CONVERSION, DRIVEN THROUGH THE CAMERA'S OWN FUNCTION (task 129). Four rounds of task
		-- 125 were spent on a compass that was exactly half a turn out, and this case did not catch
		-- it because it COPIED the expression under test into itself -- so it agreed with the wrong
		-- one. It now calls `Camera.headingOfLookDeg`, which is the one the view really goes through.
		--
		-- THE EXPECTATIONS BELOW WERE ALWAYS RIGHT, and task 129 settled that against the picture
		-- rather than against another CFrame: four neon posts 60 studs out, one per world axis, and
		-- a photograph. The blue post at -Z filled the middle of the frame while the strip read N.
		-- See `.screenshots/t129-turn-A.png` and `Camera.headingOfLookDeg`'s own comment.
		it("turns the camera's own yaw into a world bearing for all four cardinals", function()
			local CameraSystem = require(scripts:WaitForChild("Camera"))
			local cases = {
				{ look = Vector3.new(0, 0, 1), name = "north", bearing = 0 },
				{ look = Vector3.new(1, 0, 0), name = "east", bearing = 90 },
				{ look = Vector3.new(0, 0, -1), name = "south", bearing = 180 },
				{ look = Vector3.new(-1, 0, 0), name = "west", bearing = 270 },
			}
			for _, case in ipairs(cases) do
				-- the camera's INVERSE: the yaw it would store to look this way
				local yaw = math.deg(math.atan2(-case.look.X, -case.look.Z))
				-- ...its FORWARD: the CFrame it would then build and apply
				local built = CFrame.fromEulerAnglesYXZ(0, math.rad(yaw), 0)
				local flat = Vector3.new(built.LookVector.X, 0, built.LookVector.Z)
				-- ...and the CAMERA's own conversion, called rather than copied.
				local bearing = CameraSystem.headingOfLookDeg(flat)
				local off = math.abs(Compass.deltaDeg(bearing, case.bearing))
				if off > 0.5 then
					error(
						string.format(
							"%s: camera yaw %.0f deg should publish bearing %.0f, got %.1f (%.0f off)",
							case.name,
							yaw,
							case.bearing,
							bearing,
							off
						)
					)
				end
			end
		end)

		it("publishes a bearing, and the compass uses it unchanged", function()
			local CameraSystem = require(scripts:WaitForChild("Camera"))
			expect(type(CameraSystem.viewHeadingDeg)).to.equal("function")
			local published = CameraSystem.viewHeadingDeg()
			if published == nil then
				return -- the camera system has not applied a frame yet
			end
			expect(math.abs(Compass.deltaDeg(Compass.headingFrom(CameraSystem), published))).to.be.near(0, 1e-3)
			TestKit.note(string.format("compass: camera publishes %.0f deg", published))
		end)

		it("asks the camera system for the view, not the engine's camera or the body", function()
			local CameraSystem = require(scripts:WaitForChild("Camera"))
			expect(type(CameraSystem.viewCFrame)).to.equal("function")
			local view = CameraSystem.viewCFrame()
			if view == nil then
				return -- the camera system has not applied a frame yet; nothing to compare
			end
			local used = Compass.headingFrom(CameraSystem)
			-- THE SAME BEARING AS THE VIEW'S OWN LookVector, with nothing carried on top of it
			-- (task 129). This used to demand `fromView + 180`, which is the bug it was written to
			-- defend against: a LookVector IS the direction the camera faces, so its bearing IS the
			-- view's bearing. Settled against a photograph of four known posts, not against another
			-- CFrame -- see `Camera.headingOfLookDeg`.
			local fromView = Compass.headingDeg((view :: CFrame).LookVector)
			expect(math.abs(Compass.deltaDeg(used, fromView))).to.be.near(0, 1e-3)

			-- ...and it is RECORDED, not asserted, how far the other two sources are from it: both
			-- belong to other owners, and failing this gate for their state helps nobody.
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local camera = workspace.CurrentCamera
			local bodyDeg = if root then Compass.headingDeg((root :: BasePart).CFrame.LookVector) else -1
			local engineDeg = if camera then Compass.headingDeg((camera :: Camera).CFrame.LookVector) else -1
			TestKit.note(
				string.format(
					"compass: view %.0f deg | engine camera %.0f (%.0f off) | body %.0f (%.0f off)",
					fromView,
					engineDeg,
					math.abs(Compass.deltaDeg(fromView, engineDeg)),
					bodyDeg,
					math.abs(Compass.deltaDeg(fromView, bodyDeg))
				)
			)
		end)

		it("falls back to a plain camera when there is no camera system at all", function()
			local plain = Instance.new("Camera")
			plain.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0))
			expect(Compass.headingFrom(nil, plain)).to.be.near(90, 1e-3)
			expect(Compass.headingFrom({}, plain)).to.be.near(90, 1e-3)
			plain:Destroy()
		end)

		it("keeps the heading it last had when there is nothing trustworthy to read", function()
			-- THE CONTRACT CHANGED IN TASK 125 ROUND 4, and this case still asserted the old one.
			-- The Director's rule for that round: *"if CurrentCamera.CFrame is not what is rendered,
			-- do not use it"* -- so with no camera system and no camera of its own the strip does NOT
			-- fall back to the engine camera and does NOT snap to north; it holds the last heading it
			-- published. A compass that lags a few frames at spawn is not a compass that lies.
			local held = Compass.headingFrom(nil, nil)
			expect(type(held)).to.equal("number")
			expect(held).to.equal(Compass.lastHeadingDeg())
			-- ...and it never errors, which is the half of the old case that still stands.
			expect(Compass.headingFrom({}, nil)).to.equal(held)
		end)
	end)

	describe("the strip on screen", function()
		it("exists inside the one Hud ScreenGui, visible, and clips its own marks", function()
			local frame = Hud.compass()
			expect(frame).to.be.ok()
			expect((frame :: Frame):IsDescendantOf(player.PlayerGui)).to.equal(true)
			expect((frame :: Frame).Visible).to.equal(true)
			expect((frame :: Frame).ClipsDescendants).to.equal(true)
		end)

		it("shows the cardinal you are facing in the middle, and moves it when you turn", function()
			Compass.render(0)
			local facingNorth = {}
			for _, mark in ipairs(Compass.markPositions()) do
				facingNorth[mark.text] = mark.x
			end
			expect(facingNorth.N).to.be.ok()
			expect(math.abs(facingNorth.N)).to.be.near(0, 1)

			Compass.render(90)
			local facingEast = {}
			for _, mark in ipairs(Compass.markPositions()) do
				facingEast[mark.text] = mark.x
			end
			expect(facingEast.E).to.be.ok()
			expect(math.abs(facingEast.E)).to.be.near(0, 1)
			-- ...and north has gone off to the left, by a quarter turn's worth of pixels.
			expect(facingEast.N).to.never.be.ok()
		end)
	end)

	describe("the drive marker", function()
		it("is drawn where the drive is, and dims when it is behind you", function()
			Compass.setBearing(0)
			Compass.render(0)
			expect(Compass.driveMarkerX()).to.be.near(0, 1)

			-- A quarter turn right: the drive is now to the LEFT by SPAN_DEG/… worth of pixels, or
			-- pinned at the end if that is off the strip. Either way it is still drawn.
			Compass.render(90)
			local x = Compass.driveMarkerX()
			expect(x).to.be.ok()
			expect((x :: number) < 0).to.equal(true)
		end)

		it("draws no marker at all when no world has said where the drive comes from", function()
			-- A marker pointing at zero would be a lie in the shape of a fact.
			Compass.setBearing(nil)
			Compass.render(0)
			expect(Compass.driveMarkerX()).to.never.be.ok()
		end)

		it("leaves the strip as this world had it", function()
			local Map = require(ReplicatedStorage:WaitForChild("Map"))
			local restore = nil
			if Map.EXPECTED_WORLD == "forest-test" then
				local data = require(ReplicatedStorage:WaitForChild("ForestTest"))
				restore = data.DRIVE_BEARING_DEG
			end
			Compass.setBearing(restore)
			expect(Compass.bearingDeg()).to.equal(restore)
		end)
	end)
end
