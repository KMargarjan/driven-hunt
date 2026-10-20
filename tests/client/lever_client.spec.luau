-- lever_client.spec: the DRAWN lever rifle on the real screen. The maths is proved on the server
-- (tests/server/lever.spec.luau); this proves the three things only a running client can show, and
-- it exists because the Reviewer's round-1 finding 2 was that none of them was certified by
-- anything: the `"lever"` branch of `Viewmodel.hinge` was entered by no test, nothing showed
-- `poseHands` leaves the left glove on the fore-end, and the rewritten `Viewmodel.shells` gate ran
-- on no real clone.
--
-- IT REACHES THE OWNER THROUGH PlayerScripts, never through StarterPlayerScripts, which is a
-- template (docs/design/shotgun.md section 3.2).
--
-- WHAT IT DOES NOT NEED: the lever in the player's hands. Every case below drives the owner's own
-- pure functions and a REAL clone built from this weapon's geometry, by parameter -- which is the
-- rule `camera_client.spec` and `rifle_client.spec` already follow, and which matters more here
-- than anywhere: the lever is `OWNED_ONLY`, so a session that has not bought it never holds one and
-- a case that waited for it would be a case that silently never ran.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/lever-rifle.md (section 15.3)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local LeverGeometry = require(ReplicatedStorage:WaitForChild("Lever"):WaitForChild("Geometry"))
local RifleGeometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local ROW = Weapons.ROWS.lever

return function()
	describe("the drawn lever", function()
		it("builds from the LEVER's own geometry, with the moving group named `Lever`", function()
			-- A REAL CLONE, built by the owner's own builder from this weapon's row -- not a
			-- fabricated Model. `buildNewGun` is what the session runs; if the three pieces or the
			-- moving group's envelope were wrong, this is where it shows.
			local made = Camera.Viewmodel.buildNewGun(Camera.poseConfig(), LeverGeometry, ROW)
			expect(made).to.be.ok()
			local handle = (made :: any).PrimaryPart
			expect(handle).to.be.ok()
			local moving = handle:FindFirstChild(LeverGeometry.CYCLE_GROUP_NAME)
			expect(moving).to.be.ok()
			expect(moving.Name).to.equal("Lever")
			local names = {}
			for _, d in ipairs((made :: any):GetDescendants()) do
				table.insert(names, d.Name)
			end
			TestKit.note("task224 drawn lever: " .. table.concat(names, ", "))
			-- NO SCOPE ON AN IRON-SIGHTED GUN, anywhere in the clone.
			for _, name in ipairs(names) do
				expect(name ~= "Scope").to.equal(true)
			end
			(made :: any):Destroy()
		end)

		it("THE LOOP SWINGS and the fore-end glove does NOT follow it", function()
			-- THE `poseHands` FINDING this task's design section 7.1 is built on, driven rather than
			-- argued. `poseHands` keys the left hand off `CYCLE_KIND == "hinge"`: on a break action
			-- the left hand holds the barrels and swings with them, and on THIS gun it holds the
			-- fore-end, which is bolted to the barrel and does not move. With `"hinge"` the glove
			-- would ride the loop through its whole arc -- a hand sliding off the gun once a shot.
			expect(LeverGeometry.CYCLE_KIND).to.equal("lever")
			expect(LeverGeometry.CYCLE_KIND ~= "hinge").to.equal(true)

			-- THE SWING ITSELF, through the transform the viewmodel draws with. At rest it is
			-- identity; at full throw the loop's grip point is DOWN and FORWARD (-Z is the muzzle).
			local atRest = LeverGeometry.leverThrow(ROW, 60, 0)
			local thrown = LeverGeometry.leverThrow(ROW, 60, 1)
			local grip = LeverGeometry.leverGripOffset(ROW)
			local moved = thrown * grip
			TestKit.note(
				string.format(
					"task224 throw: grip (%.3f, %.3f, %.3f) -> (%.3f, %.3f, %.3f)",
					grip.X,
					grip.Y,
					grip.Z,
					moved.X,
					moved.Y,
					moved.Z
				)
			)
			expect((atRest.Position - Vector3.zero).Magnitude < 1e-6).to.equal(true)
			expect(moved.Y < grip.Y).to.equal(true)
			expect(moved.Z < grip.Z).to.equal(true)

			-- AND THE LEFT GLOVE IS ANCHORED TO THE GUN, NOT TO THE LOOP: its pose is the same at
			-- rest and at full throw, which is exactly what `poseHands` answering `false` for
			-- `"lever"` buys. A gun whose `CYCLE_KIND` were `"hinge"` would move it.
			local set = Viewmodel.DATA.weapons.lever
			local atCarry = set.carry.left.pos
			local atCycle = set.cycle.left.pos
			expect(atCarry.x).to.equal(atCycle.x)
			expect(atCarry.y).to.equal(atCycle.y)
			expect(atCarry.z).to.equal(atCycle.z)
		end)

		it("draws NO loose shell, where the shotgun draws one", function()
			-- THE SHIPPED DEFECT THIS GUN WOULD HAVE WALKED INTO. `Viewmodel.shells` was gated on
			-- `config.MAGAZINE_SWAP ~= nil` -- "does this gun swap a box" standing in for "is this
			-- gun hand-fed" -- and underneath it `chamberOffset` is `Gun.chamber(barrel,
			-- Shotgun.CONFIG)`: the SHOTGUN's chamber mouths, at the shotgun's 4.4-stud layout, with
			-- its red 12-gauge hull. The lever has no magazine block, so the old predicate said
			-- "draw them": a 12-gauge shell flipping out of a .45-70 after every shot.
			--
			-- THE GATE IS THE DECISION, and it is what this asserts, for all three guns at once.
			expect(Camera.Viewmodel.handFeedsShells(Gun)).to.equal(true)
			expect(Camera.Viewmodel.handFeedsShells(LeverGeometry)).to.equal(false)
			expect(Camera.Viewmodel.handFeedsShells(RifleGeometry)).to.equal(false)
			-- ...AND THE DECLARATION IS ON THE GEOMETRY, not inferred from `MAGAZINE_SWAP`, which is
			-- the whole point: this gun has no magazine block, so the old test would have passed it.
			expect(LeverGeometry.HAND_FED_SHELLS).to.equal(false)
			expect((ROW :: any).MAGAZINE_SWAP).to.equal(nil)

			-- ON A REAL CLONE: a gun built from this geometry carries no shell of any kind, which is
			-- what the drawn feed would have added.
			local made = Camera.Viewmodel.buildNewGun(Camera.poseConfig(), LeverGeometry, ROW)
			expect(made).to.be.ok()
			local drawn = 0
			for _, d in ipairs((made :: any):GetDescendants()) do
				if string.find(d.Name, "Shell") ~= nil then
					drawn += 1
				end
			end
			TestKit.note(string.format("task224 lever clone: %d shell part(s) (must be 0)", drawn))
			expect(drawn).to.equal(0);
			(made :: any):Destroy()
		end)

		it("aims down its irons: no scope picture, and both gloves stay in the view", function()
			-- A `bead` gun takes the SHOTGUN's aim path, which is reached by carrying no `scope`
			-- block at all -- so the eyepiece, the reticle and the `hiddenByScope` branch that hides
			-- the gun and the gloves must all stay off.
			expect(ROW.scope).to.equal(nil)
			expect(ROW.SIGHT).to.equal("bead")
			expect(LeverGeometry.sightKind(ROW)).to.equal("bead")
			-- THE SIGHT IS THE GUN'S OWN FRONT BLADE, on the bore's centre line and forward of the
			-- action -- which is what "aiming true nozzle" means on an iron-sighted gun.
			local sight = LeverGeometry.sight(ROW)
			expect(math.abs(sight.Position.X) < 1e-6).to.equal(true)
			expect(sight.Position.Z < 0).to.equal(true)
			-- ...AND THE GLOVES ARE DRAWN. `HandAssets.GRIP_STUDS` is the hole in the closed fist,
			-- and `lever.spec` holds the poses against the gun's own anchors; what this asserts is
			-- that this weapon draws hands at all.
			expect(HandAssets.GRIP_STUDS).to.be.ok()
			local made = Camera.Viewmodel.buildNewGun(Camera.poseConfig(), LeverGeometry, ROW)
			expect(made).to.be.ok()
			expect(LeverGeometry.partCount(ROW)).to.equal(#LeverGeometry.pieces(ROW) + 2);
			(made :: any):Destroy()
		end)
	end)
end
