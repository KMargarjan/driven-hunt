-- semiauto_client.spec: the DRAWN semi-automatic shotgun, driven through the real seam and asserted
-- on the real INSTANCES. The maths is proved on the server (tests/server/semiauto.spec.luau); this
-- is the half only a running client can show -- that `buildNewGun` really builds TWO moving groups,
-- that each one really moves on its own sequence, and that the gun itself really does not.
--
-- THE SEAM IS TASK 224'S, verbatim: `Camera.Viewmodel.setSource` hands the owner a Handle inside a
-- Tool carrying `DrivenHunt.Weapon`, and `Viewmodel.weaponId` reads that attribute off the Handle's
-- Tool parent -- so an `OWNED_ONLY` weapon is drawable with no purchase, no grant and no drive.
--
-- EVERY CASE IS WRITTEN SO THE DEFECT IT IS NAMED FOR MAKES IT FAIL, and each says which edit shows
-- that (task 224 round 2's lesson: a case that passes under the defect is not a case).
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/semiauto-shotgun.md (section 15.3)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local SemiAutoGeometry = require(ReplicatedStorage:WaitForChild("SemiAuto"):WaitForChild("Geometry"))
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local ROW = Weapons.ROWS.semiauto

local semiConfig = (function()
	local out = table.clone(Camera.Config) :: any
	for key, value in pairs(Viewmodel.view(Viewmodel.DATA, "semiauto")) do
		out[key] = value
	end
	out.FIRST_PERSON = true
	return table.freeze(out)
end)()

local function stateAt(openTilt: number, blend: number?)
	local made = table.clone(Camera.Mode.initial(Camera.Config)) :: any
	made.blend = blend or 0
	made.mode = if made.blend > 0 then "Aiming" else "Third"
	made.openTilt = openTilt
	return table.freeze(made)
end

-- The seam, and it puts everything back -- `gun_client.spec`'s and `lever_client.spec`'s own
-- discipline: a case that fails here must not leave every later frame of this session drawing
-- somebody else's gun.
local function withSemiAutoDrawn(body)
	local tool = Instance.new("Tool")
	tool.Name = ROW.toolName
	tool:SetAttribute("DrivenHunt.Weapon", ROW.id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = ROW.HANDLE_SIZE
	handle.Transparency = 1
	handle.Parent = tool

	local liveSource = Camera.Viewmodel.getSource()
	local liveHands = Camera.Viewmodel.getHandTemplates()
	local fakes: { [string]: BasePart } = {}
	Camera.Viewmodel.setSource(function()
		return handle
	end)
	-- FABRICATED GLOVES, for `camera_client.spec`'s own reason: the real ones are uploaded meshes a
	-- Studio with no network may not have, and the hands branch must be reached on purpose rather
	-- than on a good day.
	Camera.Viewmodel.setHandTemplates(function(name: string): BasePart?
		if fakes[name] == nil then
			local part = Instance.new("Part")
			part.Name = name .. "Template"
			part.Size = Vector3.new(1.28, 0.57, 0.53)
			fakes[name] = part
		end
		return fakes[name]
	end)

	local ok, why = pcall(function()
		Camera.Viewmodel.clear()
		Camera.Viewmodel.setReload(nil)
		Camera.Viewmodel.setLift(nil)
		task.wait(0.3) -- the source is asked four times a second, not per frame
		body()
	end)
	Camera.Viewmodel.setLift(nil)
	Camera.Viewmodel.setReload(nil)
	Camera.Viewmodel.clear()
	Camera.Viewmodel.setSource(liveSource)
	Camera.Viewmodel.setHandTemplates(liveHands)
	tool:Destroy()
	if not ok then
		error(why, 0)
	end
end

return function()
	describe("the drawn semi-automatic shotgun", function()
		it("is built from its own geometry, with TWO moving groups and a dot", function()
			withSemiAutoDrawn(function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), semiConfig)
				-- THE SEAM REALLY REACHED THIS GUN: every case below rests on it.
				expect(Camera.Viewmodel.weaponId()).to.equal("semiauto")
				expect(Camera.Viewmodel.geometryNow()).to.equal(SemiAutoGeometry)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				expect(clone).to.be.ok()
				-- BOTH ENVELOPES ARE REALLY THERE, which is the whole of design 7.2 as an instance
				-- fact. TO SEE IT FAIL: delete the `LIFT_GROUP_NAME` block in `buildNewGun` -- the
				-- tray then lands on the Handle, this lookup answers nil, and the case fails here
				-- rather than drawing a gun whose lifter silently never moves.
				local bolt = clone:FindFirstChild(SemiAutoGeometry.CYCLE_GROUP_NAME) :: BasePart
				local tray = clone:FindFirstChild(SemiAutoGeometry.LIFT_GROUP_NAME) :: BasePart
				expect(bolt).to.be.ok()
				expect(tray).to.be.ok()
				expect(bolt.Parent).to.equal(clone)
				expect(tray.Parent).to.equal(clone) -- the Handle, NOT the bolt: they are independent
				-- ...AND THE PIECE EACH ENVELOPE OWNS IS INSIDE IT, not beside it.
				expect(bolt:FindFirstChild("Bolt")).to.be.ok()
				expect(tray:FindFirstChild("Lifter")).to.be.ok()
				local names = {}
				for _, d in ipairs(clone:GetDescendants()) do
					table.insert(names, d.Name)
					-- NO SCOPE AND NO EYEPIECE: this gun aims down the side-by-side's path.
					expect(d.Name ~= "Scope").to.equal(true)
				end
				TestKit.note("task225 drawn semiauto: " .. table.concat(names, ", "))
				-- THE DOT IS DRAWN AND IT IS EMISSIVE on the instance, not just in the piece list.
				local dot = clone:FindFirstChild("Dot") :: BasePart
				expect(dot).to.be.ok()
				expect(dot.Material).to.equal(Enum.Material.Neon)
				-- Both gloves are on it, and neither hangs off a moving group.
				local right = clone:FindFirstChild(HandAssets.RIGHT) :: BasePart
				local left = clone:FindFirstChild(HandAssets.LEFT) :: BasePart
				expect(right).to.be.ok()
				expect(left).to.be.ok()
				expect(left.Parent).to.equal(clone)
				expect(right.Parent).to.equal(clone)
				expect(right:IsDescendantOf(Workspace.CurrentCamera)).to.equal(true)
			end)
		end)

		it("THE BOLT GOES STRAIGHT BACK, and the gun and both gloves hold still", function()
			-- THE TWO ARMS THIS GUN ADDS, in one frame-to-frame comparison: `CYCLE_KIND ==
			-- "straight"` (the bolt translates and nothing rotates) and `CYCLE_POSE_SHARE == 0` (the
			-- gun does not travel to a cycle pose, because the shooter does nothing).
			--
			-- TO SEE THE FIRST FAIL: change `boltTravel`'s `+ back` to `- back` -- the bolt then
			-- goes out of the muzzle and the Z assertion flips. TO SEE THE SECOND FAIL: set
			-- `cycle.poseShare` to 1 in `poses.json` -- the gun and both gloves then travel and the
			-- last three assertions go from ~0 to tenths of a stud.
			--
			-- MEASURED IN THE BODY'S OWN FRAME, NOT THE WORLD, which is `camera_client.spec`'s own
			-- hard-won correction.
			withSemiAutoDrawn(function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), semiConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local bolt = clone:FindFirstChild(SemiAutoGeometry.CYCLE_GROUP_NAME) :: BasePart
				local left = clone:FindFirstChild(HandAssets.LEFT) :: BasePart
				local right = clone:FindFirstChild(HandAssets.RIGHT) :: BasePart
				local boltRest = clone.CFrame:ToObjectSpace(bolt.CFrame)
				local leftRest = clone.CFrame:ToObjectSpace(left.CFrame)
				local rightRest = clone.CFrame:ToObjectSpace(right.CFrame)
				local gunRest = clone.CFrame

				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(1), semiConfig)
				local boltBack = clone.CFrame:ToObjectSpace(bolt.CFrame)
				local leftBack = clone.CFrame:ToObjectSpace(left.CFrame)
				local rightBack = clone.CFrame:ToObjectSpace(right.CFrame)

				local travelled = boltBack.Position.Z - boltRest.Position.Z
				TestKit.note(
					string.format(
						"task225 cycle on the body: bolt %+.4f in Z, %.4f in X/Y; gun moved %.4f; gloves %.4f / %.4f",
						travelled,
						math.abs(boltBack.Position.X - boltRest.Position.X)
							+ math.abs(boltBack.Position.Y - boltRest.Position.Y),
						(clone.CFrame.Position - gunRest.Position).Magnitude,
						(leftBack.Position - leftRest.Position).Magnitude,
						(rightBack.Position - rightRest.Position).Magnitude
					)
				)
				-- BACK is +Z in this frame, and the bolt actually travelled.
				expect(travelled > 0.05).to.equal(true)
				-- ...and NOTHING ELSE about it moved: no lift, no turn.
				expect(math.abs(boltBack.Position.X - boltRest.Position.X) < 1e-3).to.equal(true)
				expect(math.abs(boltBack.Position.Y - boltRest.Position.Y) < 1e-3).to.equal(true)
				expect((boltBack.UpVector - boltRest.UpVector).Magnitude < 1e-3).to.equal(true)
				-- THE GUN AND BOTH GLOVES HELD STILL, which is what `poseShare = 0` buys.
				expect((leftBack.Position - leftRest.Position).Magnitude < 1e-3).to.equal(true)
				expect((rightBack.Position - rightRest.Position).Magnitude < 1e-3).to.equal(true)
			end)
		end)

		it("THE TRAY RISES on a shell and comes back down, and the bolt does not move with it", function()
			-- THE SECOND MOVING GROUP, DRIVEN ON ITS OWN CLOCK. The lift runs on `setLift`, which
			-- `CameraBoot` starts from `Camera.fedShell` -- not from `openTilt` -- so this case
			-- holds the cycle at REST throughout and moves only the lifter. That is the separation
			-- the design asked for, and it is what this case exists to prove.
			--
			-- TO SEE IT FAIL: parent the lifter's envelope to `barrels` instead of the Handle in
			-- `buildNewGun`. The tray then travels with the bolt, and the "the bolt did not move"
			-- assertion below fails.
			withSemiAutoDrawn(function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), semiConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local tray = clone:FindFirstChild(SemiAutoGeometry.LIFT_GROUP_NAME) :: BasePart
				local bolt = clone:FindFirstChild(SemiAutoGeometry.CYCLE_GROUP_NAME) :: BasePart
				local trayRest = clone.CFrame:ToObjectSpace(tray.CFrame)
				local boltRest = clone.CFrame:ToObjectSpace(bolt.CFrame)

				-- ONE SHELL GOES IN. A long window so the frame below lands near the peak of the
				-- ramp rather than racing it.
				Camera.Viewmodel.setLift(2.0)
				task.wait(1.0) -- ~the half, where `lifterWeight` is 1
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), semiConfig)
				local trayUp = clone.CFrame:ToObjectSpace(tray.CFrame)
				local boltThen = clone.CFrame:ToObjectSpace(bolt.CFrame)

				local rose = trayUp.Position.Y - trayRest.Position.Y
				local boltMoved = (boltThen.Position - boltRest.Position).Magnitude
				TestKit.note(
					string.format(
						"task225 lifter on the body: tray %+.4f in Y, turned %.4f; bolt moved %.4f",
						rose,
						(trayUp.UpVector - trayRest.UpVector).Magnitude,
						boltMoved
					)
				)
				-- IT WENT UP, and it TURNED -- a tray hinges, it does not slide.
				expect(rose > 0.01).to.equal(true)
				expect((trayUp.UpVector - trayRest.UpVector).Magnitude > 1e-3).to.equal(true)
				-- ...AND THE BOLT DID NOT COME WITH IT.
				expect(boltMoved < 1e-3).to.equal(true)

				-- AND IT COMES BACK DOWN. `liftProgress` clears its own clock at 1, so once the
				-- window has run out the tray is at rest again -- which is what stops it standing
				-- up inside the receiver between shells.
				Camera.Viewmodel.setLift(nil)
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), semiConfig)
				local trayBack = clone.CFrame:ToObjectSpace(tray.CFrame)
				TestKit.note(
					string.format(
						"task225 lifter returned to %.4f of rest",
						(trayBack.Position - trayRest.Position).Magnitude
					)
				)
				expect((trayBack.Position - trayRest.Position).Magnitude < 1e-3).to.equal(true)
			end)
		end)

		it("PUTS THE DOT ON THE SIGHT PLANE the aim is solved from -- one expression, not two", function()
			-- THE CASE THAT WOULD HAVE CAUGHT ROUND 1'S FINDING 1, and it is written the way the
			-- design asks (15.3 case 3): the DRAWN dot and the ATTACHMENT the eye is laid on must be
			-- the same point, because they come from one expression (`Geometry.beadOffset`).
			--
			-- THE DEFECT IT CATCHES IS A NAME, not a number. `Viewmodel.sight()` resolves the
			-- attachment with `FindFirstChild("Sight")` and then `IsA("Attachment")` -- so a PART
			-- named `Sight` is found first, fails the class test, and the whole aimed pose silently
			-- falls back to `VIEWMODEL_AIM_OFFSET` with `eyeReliefStuds` and `cheekDeg` doing nothing.
			-- TO SEE IT FAIL: rename this gun's sight piece back to `"Sight"` in
			-- `SemiAuto.Geometry.MESH_KEYS` and `pieces`. `Viewmodel.sight()` then answers nil and the
			-- first assertion below fails.
			withSemiAutoDrawn(function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), semiConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local sight = Camera.Viewmodel.sight()
				expect(sight).to.be.ok()
				-- `Dot` IS THE LIT BALL; `Optic` IS THE SIGHT'S UPLOADED HOUSING. Two names on
				-- purpose: the first cut of this case asked for the housing and measured the two
				-- 0.56 studs apart, which is the housing's mesh offset and not a defect in the aim.
				local dot = clone:FindFirstChild("Dot") :: BasePart
				expect(dot).to.be.ok()
				expect(dot.Material).to.equal(Enum.Material.Neon)
				expect(clone:FindFirstChild("Optic")).to.be.ok()
				-- ...AND NO PART MAY TAKE THE ATTACHMENT'S NAME, on this gun or any other.
				local named = clone:FindFirstChild("Sight")
				expect(named == nil or named:IsA("Attachment")).to.equal(true)
				local at = clone.CFrame * (sight :: CFrame)
				local miss = (dot.Position - at.Position).Magnitude
				TestKit.note(
					string.format(
						"task225 dot %s vs the sight attachment %s: %.6f studs apart",
						tostring(clone.CFrame:ToObjectSpace(dot.CFrame).Position),
						tostring((sight :: CFrame).Position),
						miss
					)
				)
				expect(miss < 1e-3).to.equal(true)
			end)
		end)

		it("AIMS WITHOUT A SCOPE: no mask, and the gun and both gloves stay in the view", function()
			-- Design 15.3 case 2. The arm is `scope = nil` with `SIGHT = "reddot"`, which is what
			-- makes aiming the side-by-side's path rather than the Rigby's full-screen mask -- and it
			-- is reached by PARAMETER, at blend 1, rather than by holding a mouse button.
			withSemiAutoDrawn(function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0, 1), semiConfig)
				expect(Camera.Viewmodel.weaponId()).to.equal("semiauto")
				-- NO OPTICS AT ALL on this row, so nothing can hide the gun: `Viewmodel.hiddenByScope`
				-- requires an `optics.eyepiece`, and this row carries no `scope` block to build one
				-- from. `Camera.scope()` is the live answer to "is a sight picture up".
				expect(Weapons.ROWS.semiauto.scope).to.equal(nil)
				expect(Camera.scope()).to.equal(nil)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				expect(clone).to.be.ok()
				-- THE GUN AND BOTH GLOVES ARE STILL DRAWN AND STILL UNDER THE CAMERA.
				local right = clone:FindFirstChild(HandAssets.RIGHT) :: BasePart
				local left = clone:FindFirstChild(HandAssets.LEFT) :: BasePart
				expect(right).to.be.ok()
				expect(left).to.be.ok()
				expect(clone:IsDescendantOf(Workspace.CurrentCamera)).to.equal(true)
				-- THE GUN IS VISIBLE, and that is asked of a PIECE and not of the clone: the clone
				-- IS the Handle, which is the invisible envelope every gun here is built around
				-- (`HANDLE_TRANSPARENCY = 1`). Asking it of the Handle is asking the wrong part.
				local body = clone:FindFirstChild("Action") :: BasePart
				expect(body).to.be.ok()
				expect(body.Transparency < 1).to.equal(true)
				-- ...AND THE AIMED HOLD IS A DIFFERENT HOLD FROM THE HIP, which is what proves the
				-- aimed pose was actually solved rather than falling through to a default.
				local aimed = Camera.Mode.viewmodelOffset(stateAt(0, 1), Camera.Viewmodel.sight(), semiConfig)
				local hip = Camera.Mode.viewmodelOffset(stateAt(0, 0), Camera.Viewmodel.sight(), semiConfig)
				TestKit.note(
					string.format("task225 aim vs hip: %.4f studs apart", (aimed.Position - hip.Position).Magnitude)
				)
				expect((aimed.Position - hip.Position).Magnitude > 0.05).to.equal(true)
			end)
		end)

		it("raises the tray once per SHELL, through the edge CameraBoot really uses", function()
			-- `Camera.fedShell` IS THE EDGE, and this case enters the arm that made it necessary:
			-- `runCycle` publishes the step name on EVERY step, so the rising edge of
			-- `action == "Load"` fires once per RUN. The live-chamber count fires once per shell.
			local function snap(action: string?, liveCount: number)
				local barrels = {}
				for i = 1, 5 do
					barrels[i] = if i <= liveCount then "Live" else "Empty"
				end
				return { action = action, barrels = barrels }
			end
			-- Two shells going in, one after the other: BOTH are edges.
			expect(Camera.fedShell(snap("Load", 2), snap("Load", 3))).to.equal(true)
			expect(Camera.fedShell(snap("Load", 3), snap("Load", 4))).to.equal(true)
			-- A `Load` step that has not put one in yet is not an edge.
			expect(Camera.fedShell(snap("Load", 3), snap("Load", 3))).to.equal(false)
			-- THE TWO CASES THAT DEFEATED THE EARLIER ROUND-COUNTING ATTEMPTS, entered: a re-grant
			-- publishes a full gun with no action, and a magazine change is not a `Load`.
			expect(Camera.fedShell(snap(nil, 0), snap(nil, 5))).to.equal(false)
			expect(Camera.fedShell(snap("Magazine", 0), snap("Magazine", 3))).to.equal(false)
			-- ...and the OLD edge would have answered differently, which is why this one exists.
			TestKit.note("task225 fedShell: 2 of 2 consecutive Load steps are edges (the old rule gave 1 of 2)")
		end)
	end)
end
