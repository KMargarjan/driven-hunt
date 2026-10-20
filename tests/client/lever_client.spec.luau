-- lever_client.spec: the DRAWN lever rifle, driven through the real seam and asserted on the real
-- INSTANCES. The maths is proved on the server (tests/server/lever.spec.luau); this is the half only
-- a running client can show.
--
-- IT EXISTS BECAUSE ROUND 1'S FINDING 2 WAS THAT NOTHING CERTIFIED THE DRAWN GUN, AND ROUND 2'S WAS
-- THAT MY FIRST ATTEMPT STILL DID NOT. Round 2 compared two `poses.json` entries and called it the
-- `poseHands` finding -- so forcing `follows = true`, which is the defect itself, left it green --
-- and counted shell parts on a freshly built clone, which is 0 for every weapon because
-- `buildNewGun` draws no shells at all. Both cases below are written so that the defect they are
-- named for makes them fail, and the request says which edit to make to see it.
--
-- THE SEAM IS THE ONE THIS REPO ALREADY USES, and round 2's stated reason for not using it ("an
-- `OWNED_ONLY` weapon is never in a test session's hands") was wrong: `gun_client.spec`'s
-- `withNewGun` hands the owner a fabricated Handle through `Camera.Viewmodel.setSource`, and
-- `Viewmodel.weaponId` reads `DrivenHunt.Weapon` off that Handle's **Tool parent** -- so a Handle in
-- a Tool carrying `"lever"` is what makes `geometryNow()` answer `Lever.Geometry`. No purchase, no
-- grant and no drive needed.
--
-- IT REACHES THE OWNER THROUGH PlayerScripts, never through StarterPlayerScripts, which is a
-- template (docs/design/shotgun.md section 3.2).
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/lever-rifle.md (section 15.3)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local LeverGeometry = require(ReplicatedStorage:WaitForChild("Lever"):WaitForChild("Geometry"))
local RifleGeometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local ROW = Weapons.ROWS.lever

-- The lever's own first-person config, built here rather than read off the live one: the live
-- session is holding whatever it is holding, and this file is about THIS weapon.
local leverConfig = (function()
	local out = table.clone(Camera.Config) :: any
	for key, value in pairs(Viewmodel.view(Viewmodel.DATA, "lever")) do
		out[key] = value
	end
	out.FIRST_PERSON = true
	return table.freeze(out)
end)()

local function stateAt(openTilt: number)
	local made = table.clone(Camera.Mode.initial(Camera.Config)) :: any
	made.mode = "Third"
	made.blend = 0
	made.openTilt = openTilt
	return table.freeze(made)
end

-- THE SEAM, AND IT PUTS EVERYTHING BACK. `withLeverDrawn` hands the owner a Handle inside a Tool
-- that says it is a lever, lets the source poll pick it up, and restores the live source, the hand
-- templates and the reload state whatever happens -- the discipline `gun_client.spec`'s `withNewGun`
-- already keeps, and the reason is the same: a case that fails here must not leave every later frame
-- of this session drawing somebody else's gun.
local function withLeverDrawn(body)
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
	-- FABRICATED GLOVES, for `camera_client.spec`'s own reason: the real ones are uploaded meshes
	-- published into ReplicatedStorage, which a Studio with no network may not have. Driving the
	-- seam means the hands branch is reached on purpose rather than on a good day.
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
		task.wait(0.3) -- the source is asked four times a second, not per frame
		body()
	end)
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
	describe("the drawn lever", function()
		it("is the LEVER on screen, built from its own geometry, with no scope on it", function()
			withLeverDrawn(function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), leverConfig)
				-- THE SEAM REALLY REACHED THE LEVER: this is what every case below rests on.
				expect(Camera.Viewmodel.weaponId()).to.equal("lever")
				expect(Camera.Viewmodel.geometryNow()).to.equal(LeverGeometry)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				expect(clone).to.be.ok()
				local lever = clone:FindFirstChild(LeverGeometry.CYCLE_GROUP_NAME) :: BasePart
				expect(lever).to.be.ok()
				local names = {}
				for _, d in ipairs(clone:GetDescendants()) do
					table.insert(names, d.Name)
					expect(d.Name ~= "Scope").to.equal(true)
				end
				TestKit.note("task224 drawn lever: " .. table.concat(names, ", "))
				-- BOTH GLOVES ARE ON IT, and the left hangs off the BODY rather than off the moving
				-- group: `Viewmodel.hands` picks `leftParent` as `FindFirstChild("Barrels")`, which
				-- this gun has no child named -- so on a break gun the glove rides the barrels and
				-- here it does not. That parent IS the fact the next case measures.
				local right = clone:FindFirstChild(HandAssets.RIGHT) :: BasePart
				local left = clone:FindFirstChild(HandAssets.LEFT) :: BasePart
				expect(right).to.be.ok()
				expect(left).to.be.ok()
				expect(left.Parent).to.equal(clone)
				expect(right.Parent).to.equal(clone)
				expect(right:IsDescendantOf(Workspace.CurrentCamera)).to.equal(true)
			end)
		end)

		it("THE LOOP SWINGS DOWN AND FORWARD while the fore-end glove stays put", function()
			-- THE `poseHands` FINDING OF DESIGN 7.1, DRIVEN. `poseHands` places the left glove with
			-- `local follows = (geometryNow().CYCLE_KIND or "hinge") == "hinge"` and then
			-- `(if follows then barrelsCFrame else gunCFrame) * held`. On a break action the glove
			-- holds the barrels and swings with them; on THIS gun it holds the fore-end, which is
			-- bolted to the barrel and does not move.
			--
			-- TO SEE IT FAIL: force `follows = true` in `Viewmodel.poseHands`. The glove then rides
			-- the loop through its whole arc and the last assertion below goes from ~0 to a tenth of
			-- a stud. Round 2's version compared two `poses.json` entries and stayed green under
			-- exactly that edit.
			--
			-- MEASURED IN THE BODY'S OWN FRAME, NOT THE WORLD, which is `camera_client.spec`'s own
			-- hard-won correction: working the action also moves the WHOLE gun, so in world space
			-- everything travels and "the glove moved" would pass for the wrong reason.
			withLeverDrawn(function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), leverConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local lever = clone:FindFirstChild(LeverGeometry.CYCLE_GROUP_NAME) :: BasePart
				local left = clone:FindFirstChild(HandAssets.LEFT) :: BasePart
				expect(lever).to.be.ok()
				expect(left).to.be.ok()
				local leverAtRest = clone.CFrame:ToObjectSpace(lever.CFrame)
				local leftAtRest = clone.CFrame:ToObjectSpace(left.CFrame)

				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(1), leverConfig)
				local leverThrown = clone.CFrame:ToObjectSpace(lever.CFrame)
				local leftThrown = clone.CFrame:ToObjectSpace(left.CFrame)

				local dropped = leverAtRest.Position.Y - leverThrown.Position.Y
				local forward = leverAtRest.Position.Z - leverThrown.Position.Z
				local gloveMoved = (leftThrown.Position - leftAtRest.Position).Magnitude
				TestKit.note(
					string.format(
						"task224 throw on the body: lever down %.4f, forward %.4f; fore-end glove moved %.4f studs",
						dropped,
						forward,
						gloveMoved
					)
				)
				-- THE LOOP MOVED, and in the two directions a lever throw goes: DOWN, and FORWARD,
				-- which is -Z because the muzzle is at -Z.
				expect(dropped > 0.01).to.equal(true)
				expect(forward > 0.01).to.equal(true)
				-- ...AND THE GLOVE DID NOT. This is the assertion the defect fails.
				expect(gloveMoved < 0.01).to.equal(true)
			end)
		end)

		it("draws NO loose shell when the action is open with a spent case in it", function()
			-- THE SHIPPED DEFECT THIS GUN WOULD HAVE WALKED INTO. `Viewmodel.shells` was gated on
			-- `config.MAGAZINE_SWAP ~= nil` -- "does this gun swap a box" standing in for "is this
			-- gun hand-fed" -- and underneath it `chamberOffset` is `Gun.chamber(barrel,
			-- Shotgun.CONFIG)`: the SHOTGUN's chamber mouths, at the shotgun's 4.4-stud layout, with
			-- its red 12-gauge hull. The lever has no magazine block, so the old predicate said
			-- "draw them": a 12-gauge shell flipping out of a .45-70 after every shot.
			--
			-- IT DRIVES `Viewmodel.shells` WITH A GUN THAT IS OPEN AND HAS A SPENT CASE, which is
			-- the state that makes the drawing happen. Round 2 counted shell parts on a freshly
			-- built clone -- 0 for every weapon, because `buildNewGun` draws no shells at all -- so
			-- it could not fail.
			--
			-- TO SEE IT FAIL: delete the `if not Viewmodel.handFeedsShells(geometryNow()) then`
			-- guard in `Viewmodel.shells`. The spent chamber is then drawn and `shellsDrawn` moves.
			withLeverDrawn(function()
				Camera.Viewmodel.update(CFrame.new(0, 12, 0), stateAt(0), leverConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				expect(Camera.Viewmodel.geometryNow()).to.equal(LeverGeometry)
				local before = Camera.Viewmodel.stats().shellsDrawn
				Camera.Viewmodel.setReload({ open = true, spent = 1, loaded = { false, true } })
				Camera.Viewmodel.shells(clone.CFrame, leverConfig)
				local after = Camera.Viewmodel.stats().shellsDrawn
				local drawn = 0
				for _, d in ipairs(clone:GetDescendants()) do
					if string.find(d.Name, "SpentShell") ~= nil or string.find(d.Name, "FreshShell") ~= nil then
						drawn += 1
					end
				end
				TestKit.note(
					string.format(
						"task224 lever shells: shellsDrawn %d -> %d, %d shell part(s) on the clone",
						before,
						after,
						drawn
					)
				)
				expect(after).to.equal(before)
				expect(drawn).to.equal(0)
			end)
			-- ...AND THE GATE IS A DECLARED FACT ABOUT THE GUN, not inferred from `MAGAZINE_SWAP` --
			-- which this weapon does not have, so the old predicate would have passed it.
			expect(Camera.Viewmodel.handFeedsShells(Gun)).to.equal(true)
			expect(Camera.Viewmodel.handFeedsShells(LeverGeometry)).to.equal(false)
			expect(Camera.Viewmodel.handFeedsShells(RifleGeometry)).to.equal(false)
			expect(LeverGeometry.HAND_FED_SHELLS).to.equal(false)
			expect((ROW :: any).MAGAZINE_SWAP).to.equal(nil)
		end)

		it("aims down its irons: no scope picture, and both gloves stay in the view", function()
			-- A `bead` gun takes the SHOTGUN's aim path, reached by carrying no `scope` block at all
			-- -- so the eyepiece, the reticle and the `hiddenByScope` branch that hides the gun and
			-- the gloves must all stay off. `hiddenByScope` is pure and exported, so it is driven
			-- here rather than inferred.
			expect(ROW.scope).to.equal(nil)
			expect(LeverGeometry.sightKind(ROW)).to.equal("bead")
			local aimed = table.clone(Camera.Mode.initial(Camera.Config)) :: any
			aimed.mode = "Aiming"
			aimed.blend = 1
			aimed.openTilt = 0
			table.freeze(aimed)
			-- `hiddenByScope(state, optics)` is what blanks the gun and both gloves behind a sight
			-- picture. This gun carries NO optics, so it is false even fully aimed...
			expect(Camera.Viewmodel.hiddenByScope(aimed, ROW.scope)).to.equal(false)
			expect(Camera.Viewmodel.hiddenByScope(stateAt(0), ROW.scope)).to.equal(false)
			-- ...and the branch is not simply dead: handed the RIGBY's optics at the same state it
			-- answers true, which is what makes the lever's `false` a fact about this weapon rather
			-- than about the function.
			expect(Camera.Viewmodel.hiddenByScope(aimed, Weapons.ROWS.rifle.scope)).to.equal(true)
			-- THE SIGHT IS THE GUN'S OWN FRONT BLADE, on the bore's centre line and forward of the
			-- action -- which is what "aiming true nozzle" means on an iron-sighted gun.
			local sight = LeverGeometry.sight(ROW)
			expect(math.abs(sight.Position.X) < 1e-6).to.equal(true)
			expect(sight.Position.Z < 0).to.equal(true)
		end)
	end)
end
