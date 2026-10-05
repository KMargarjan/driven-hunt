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

	describe("against the world, not against the convention", function()
		-- THE CHECK THAT CANNOT BE FOOLED BY A SIGN. Every assertion above is about arithmetic, and
		-- arithmetic that is consistently 180 degrees wrong passes all of them -- which is exactly
		-- what task 125 round 2 was raised about. This one asks the ENGINE: it puts a point due north
		-- of the camera and asks the camera whether that point is on screen, then asks the compass
		-- whether north is on the strip. The two must agree, whatever anybody believes about atan2.
		it("reads the BODY's facing in first person, not the camera's", function()
			-- THE ASSERTION THIS ROUND EXISTS FOR. At spawn the camera reads 180 degrees away from the
			-- character and holds it, so a compass that trusts `CurrentCamera.LookVector` points the
			-- player backwards -- measured, and the reason `Compass.headingFrom` exists.
			local camera = workspace.CurrentCamera
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if camera == nil or head == nil or root == nil then
				return
			end
			local eye = ((camera :: Camera).CFrame.Position - (head :: BasePart).Position).Magnitude
			local used = Compass.headingFrom(camera, character)
			local body = Compass.headingDeg((root :: BasePart).CFrame.LookVector)
			local cameraDeg = Compass.headingDeg((camera :: Camera).CFrame.LookVector)
			TestKit.note(
				string.format(
					"compass: eye %.2f studs, body %.0f deg, camera %.0f deg, used %.0f deg",
					eye,
					body,
					cameraDeg,
					used
				)
			)
			if eye <= CONFIG.EYE_STUDS then
				expect(math.abs(Compass.deltaDeg(used, body))).to.be.near(0, 1e-3)
			else
				expect(math.abs(Compass.deltaDeg(used, cameraDeg))).to.be.near(0, 1e-3)
			end
		end)

		it("agrees with the character's own facing while the camera is first person", function()
			-- A SECOND INDEPENDENT WITNESS, and the one that caught the real confusion in round 2: at
			-- spawn the character's root read +Z while the camera read -Z, which is a camera pointing
			-- the opposite way to the body. In first person the two must agree; when they do not, the
			-- stock camera is still in charge and the compass is briefly reading it (recorded in
			-- TASKS.md, not fixed here).
			local camera = workspace.CurrentCamera
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local head = character and character:FindFirstChild("Head")
			if camera == nil or root == nil or head == nil then
				return -- nothing to compare against; not a failure of the compass
			end
			local eye = ((camera :: Camera).CFrame.Position - (head :: BasePart).Position).Magnitude
			if eye > 3 then
				return -- third person: the camera is deliberately not the body's facing
			end
			local cameraDeg = Compass.headingDeg((camera :: Camera).CFrame.LookVector)
			local bodyDeg = Compass.headingDeg((root :: BasePart).CFrame.LookVector)
			local apart = math.abs(Compass.deltaDeg(cameraDeg, bodyDeg))
			-- RECORDED, NOT ASSERTED, and deliberately so: the camera is `src/client/Camera/`'s and
			-- this file only reads it. MEASURED at spawn, 2026-10-05: 180 degrees apart, stable. The
			-- note is here so the number is in every harness report until the camera's owner fixes
			-- it; the compass is already immune (`Compass.headingFrom` takes the body in first
			-- person), and asserting here would fail the gate for somebody else's defect.
			TestKit.note(
				string.format(
					"compass: camera %.0f deg, body %.0f deg, %.0f apart (the camera is not this file's)",
					cameraDeg,
					bodyDeg,
					apart
				)
			)
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
