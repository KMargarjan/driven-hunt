--!strict
-- The NEW first-person gun, in a real client (task 99), and the gloves that hold it.
--
-- WHY IT IS ITS OWN FILE: `camera_client.spec.luau` grew past what StudioMCP will return in one
-- reply. MEASURED -- the harness refused the run with "Studio's answer for
-- ReplicatedStorage.ClientTests.camera_client.spec was truncated at 100015 chars: one instance is
-- too big for a single StudioMCP result" -- and that is a real bound on how big any one synced
-- instance may be, not a thing to work around. The claims are unchanged; they live here.
--
-- THE FLAG SITS OFF AND BOTH GUNS ARE DRIVEN BY PARAMETER, the rule every flagged path in this repo
-- follows (docs/design/feature-flags.md 13.3). The GEOMETRY is proved on the server
-- (tests/server/gun.spec.luau); what only a client can show is that the gun is really built, really
-- under the camera, and that its barrel group really turns about its own pin.
--
-- Note: docs/research/2026-10-01-exact-metal-gun.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Config = Camera.Config
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- THE ON BRANCH BY PARAMETER, exactly as `camera_client.spec` builds it: nothing is flipped and
-- nothing has to be restored.
local firstPersonConfig = table.clone(Config) :: any
firstPersonConfig.FIRST_PERSON = true
table.freeze(firstPersonConfig)

local function stateAtBlend(blend: number)
	local state = table.clone(Camera.Mode.initial(Config)) :: any
	state.mode = if blend > 0 then "Aiming" else "Third"
	state.blend = blend
	return table.freeze(state)
end

return function()
	-- THE NEW GUN (task 99), DRIVEN BY PARAMETER while the flag sits OFF -- the rule every flagged
	-- path in this repo follows (docs/design/feature-flags.md 13.3). The GEOMETRY is proved on the
	-- server (tests/server/gun.spec.luau); what only a client can show is that it is really built,
	-- really under the camera, and that its barrel group really turns about its own pin.
	describe("the new gun", function()
		local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
		local newGunConfig = table.clone(firstPersonConfig) :: any
		newGunConfig.NEW_GUN = true
		table.freeze(newGunConfig)

		-- Its own handle, so this never depends on what the live player happens to be holding, and
		-- the live source is always put back.
		local function withNewGun(body)
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			task.wait(0.3) -- the source is asked four times a second, not per frame
			Camera.Viewmodel.clear()
			local ok, why = pcall(body)
			Camera.Viewmodel.setReload(nil)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
		end

		it("is built, not cloned: the pieces are really under the camera", function()
			withNewGun(function()
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), newGunConfig)
				local model = Camera.Viewmodel.current()
				expect(model).to.be.ok()
				local clone = (model :: Model).PrimaryPart :: BasePart
				-- THE ENVELOPE IS UNCHANGED, which is what keeps every pose and the near-plane
				-- arithmetic the same gun they were written for.
				expect(clone.Size).to.equal(Shotgun.CONFIG.HANDLE_SIZE)
				expect(clone.Transparency).to.equal(1)
				expect(clone:IsDescendantOf(Workspace.CurrentCamera)).to.equal(true)
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				expect(barrels).to.be.ok()
				-- WHAT SWINGS IS A PARENT, not a list of names: the tubes, the rib, the bead and the
				-- forend are children of the barrel group, and the pin and the stock are not.
				for _, name in ipairs({ "BarrelLeft", "BarrelRight", "Rib", "Bead", "Forend" }) do
					expect(barrels:FindFirstChild(name)).to.be.ok()
				end
				for _, name in ipairs({ "HingePin", "Action", "StandingBreech", "Trigger", "Stock" }) do
					expect(clone:FindFirstChild(name)).to.be.ok()
				end
				-- The two attachments the rest of the system reads off the PrimaryPart.
				expect(clone:FindFirstChild("Sight")).to.be.ok()
				expect(clone:FindFirstChild("Muzzle")).to.be.ok()
				expect((Camera.Viewmodel.sight() :: CFrame).Position).to.equal(Gun.beadOffset(Shotgun.CONFIG))
				-- THE GUN'S OWN PARTS, which is what the budget is about: the two gloves and their
				-- sleeves are the HANDS' cost and are counted in their own case. The two-player run
				-- is what taught this -- there the live templates had arrived, so the drawn model was
				-- 27 parts against the gun's 23 and the budget read as broken when it was not.
				local parts, worn = 0, 0
				for _, found in ipairs((model :: Model):GetDescendants()) do
					if found:IsA("BasePart") then
						if found.Name == "HandRight" or found.Name == "HandLeft" or found.Name == "Sleeve" then
							worn += 1
						else
							parts += 1
						end
						-- NOTHING UNDER THE CAMERA MAY BE HIT BY A RAY, including this system's own
						-- occlusion cast (the viewmodel header).
						expect(found.CanQuery).to.equal(false)
						expect(found.Anchored).to.equal(true)
					end
				end
				TestKit.note(string.format("task99 the drawn new gun is %d gun part(s) plus %d worn", parts, worn))
				expect(parts).to.equal(Gun.partCount(Shotgun.CONFIG))
			end)
		end)

		it("swings its barrel group about its own pin, and the pin stays put", function()
			withNewGun(function()
				local at = CFrame.new(0, 16, 0)
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(at, stateAtBlend(0), newGunConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				local tube = barrels:FindFirstChild("BarrelLeft") :: BasePart
				local pin = clone:FindFirstChild("HingePin") :: BasePart
				local shutTube = clone.CFrame:ToObjectSpace(tube.CFrame)
				local shutPin = clone.CFrame:ToObjectSpace(pin.CFrame)
				local onBarrels = barrels.CFrame:ToObjectSpace(tube.CFrame)

				local open = table.clone(stateAtBlend(0)) :: any
				open.openTilt = 1
				table.freeze(open)
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { false, false } })
				Camera.Viewmodel.update(at, open, newGunConfig)

				local openTube = clone.CFrame:ToObjectSpace(tube.CFrame)
				local openPin = clone.CFrame:ToObjectSpace(pin.CFrame)
				TestKit.note(
					string.format(
						"task99 break: the tube moved %.3f studs on the body, the pin %.4f",
						(openTube.Position - shutTube.Position).Magnitude,
						(openPin.Position - shutPin.Position).Magnitude
					)
				)
				-- THE BARRELS MOVE AND THE PIN DOES NOT, which is what a hinge is.
				expect((openTube.Position - shutTube.Position).Magnitude > 0.1).to.equal(true)
				expect((openPin.Position - shutPin.Position).Magnitude < 1e-3).to.equal(true)
				-- ...and the tube has not moved relative to the group it belongs to: the whole
				-- barrel group turns as one piece rather than the mesh tearing, which is the frame
				-- this task exists to fix.
				local stillOnBarrels = barrels.CFrame:ToObjectSpace(tube.CFrame)
				expect((stillOnBarrels.Position - onBarrels.Position).Magnitude < 1e-3).to.equal(true)
				-- AND THE TUBE STAYS THE SAME DISTANCE FROM THE PIN, which is what makes the motion
				-- a rotation about that axis rather than a slide that looks like one.
				local shutR = (shutTube.Position - shutPin.Position).Magnitude
				local openR = (openTube.Position - openPin.Position).Magnitude
				expect(math.abs(shutR - openR) < 1e-3).to.equal(true)
			end)
		end)

		it("draws the muzzle flash INSIDE the tube it comes out of", function()
			-- ROUND 1, FINDING 2, MEASURED ON THE DRAWN INSTANCES. `Camera.Viewmodel.muzzle` is what
			-- `Weapon.Effects` draws the first-person flash at, and it adds the barrel's own rise to
			-- the `Muzzle` attachment. With the attachment on the bore line the rise was counted
			-- twice and the flash sat 0.12 studs above the barrels -- outside a 0.0725-radius tube,
			-- which is what this measures.
			withNewGun(function()
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), newGunConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				for barrel, tubeName in ipairs({ "BarrelRight", "BarrelLeft" }) do -- barrel 1 is +X
					local tube = barrels:FindFirstChild(tubeName) :: BasePart
					local flash = Camera.Viewmodel.muzzle(barrel)
					expect(flash).to.be.ok()
					-- IN THE TUBE'S OWN FRAME: a cylinder's length is its X, so the other two axes
					-- are the bore and the flash must be inside that circle.
					local inTube = tube.CFrame:ToObjectSpace(flash :: CFrame)
					local across = Vector2.new(inTube.Position.Y, inTube.Position.Z).Magnitude
					TestKit.note(
						string.format(
							"task99 %s flash %.4f studs off the bore line, bore radius %.4f",
							tubeName,
							across,
							tube.Size.Y / 2
						)
					)
					expect(across < tube.Size.Y / 2).to.equal(true)
					-- ...AND AT THE MUZZLE END OF IT, BY SIGN AND BY DISTANCE (round 2 note). This
					-- used to read `never.to.equal(0)`, which the BREECH end satisfies just as well
					-- -- the real value is 1.369 and the breech is -1.369. A cylinder's own +X is the
					-- end its `LYING` quarter turn points down the gun's -Z, which is the muzzle, so
					-- the flash must be at POSITIVE X and half a tube away from the centre.
					local halfLength = tube.Size.X / 2
					TestKit.note(
						string.format(
							"task99 %s flash at x %+.4f of a %.4f half-tube",
							tubeName,
							inTube.Position.X,
							halfLength
						)
					)
					expect(inTube.Position.X > 0).to.equal(true)
					expect(math.abs(inTube.Position.X - halfLength) < 1e-3).to.equal(true)
				end
			end)
		end)

		it("leaves the OLD gun's flash where it has always been", function()
			-- THE OTHER HALF OF ONE DEFINITION: the mesh gun's tubes are 0.09 apart and 0.12 above
			-- the Handle's axis (`Shotgun.barrelMuzzleOffset`), and nothing about this task may move
			-- them. A gun built from a cloned Handle must still get that offset and not the new
			-- gun's -- which is why `Viewmodel.muzzle` asks the MODEL which gun it is.
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local muzzle = Instance.new("Attachment")
			muzzle.Name = "Muzzle"
			muzzle.CFrame = CFrame.new(Shotgun.CONFIG.MUZZLE_OFFSET)
			muzzle.Parent = handle
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, why = pcall(function()
				task.wait(0.3)
				Camera.Viewmodel.clear()
				Camera.Viewmodel.setReload(nil)
				local at = CFrame.new(0, 16, 0)
				Camera.Viewmodel.update(at, stateAtBlend(0), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				for barrel = 1, 2 do
					local flash = Camera.Viewmodel.muzzle(barrel)
					expect(flash).to.be.ok()
					local inGun = clone.CFrame:ToObjectSpace(flash :: CFrame)
					local wanted = Shotgun.CONFIG.MUZZLE_OFFSET + Shotgun.barrelMuzzleOffset(barrel, Shotgun.CONFIG)
					expect((inGun.Position - wanted).Magnitude < 1e-3).to.equal(true)
				end
			end)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
		end)

		it("seats a fresh shell on the bore line with its brass rim OUT of the breech face", function()
			withNewGun(function()
				local at = CFrame.new(0, 16, 0)
				local open = table.clone(stateAtBlend(0)) :: any
				open.openTilt = 1
				table.freeze(open)
				-- NO YIELD ANYWHERE IN HERE, and the two-player run is why: the live render step
				-- draws with the LIVE source, so a `task.wait` between these calls lets it rebuild
				-- the clone from a different handle and this case then measures somebody else's gun.
				--
				-- SO BOTH CLAIMS ARE ONES THAT HOLD AT EVERY MOMENT OF THE FEED: the shell is ON the
				-- tube's own bore line, and its brass RIM is OUTSIDE the tube's breech face. A shell
				-- still travelling in is further out than a seated one, so neither claim depends on
				-- catching a frame.
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { true, true } })
				Camera.Viewmodel.update(at, open, newGunConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				local worst, worstAt = 0, "none"
				for barrel, tubeName in ipairs({ "BarrelRight", "BarrelLeft" }) do -- barrel 1 is +X
					local shell = clone:FindFirstChild("FreshShell" .. barrel)
					expect(shell).to.be.ok()
					local tube = barrels:FindFirstChild(tubeName) :: BasePart
					-- MEASURED IN THE TUBE'S OWN FRAME: a cylinder's length is its X, so the other
					-- two axes are the bore, and the shell must be inside that circle. This is what
					-- "the shell goes IN" means, against a shell floating in the gap.
					local inTube = tube.CFrame:ToObjectSpace((shell :: Model):GetPivot())
					local across = Vector2.new(inTube.Position.Y, inTube.Position.Z).Magnitude
					if across > worst then
						worst, worstAt = across, tubeName
					end
					-- EXACTLY on the bore line, not merely inside the tube (round 2 note). The bound
					-- used to be the tube's own radius, 0.0725 -- five times the 0.014 the OLD
					-- `chamberOffset` answer is out by, so the case passed with the new gun's branch
					-- of it deleted.
					expect(across < 1e-3).to.equal(true)
					-- THE BRASS RIM (round 2, finding 1). Rounds 1 and 2 seated the shell 0.10 studs
					-- down an opaque tube, so a loaded chamber and an empty one were the same
					-- picture. Two claims, and NEITHER of them is "the drawn rim is outside the
					-- tube right now": a shell still travelling in is outside the tube whatever the
					-- seat is, so that one passes for the wrong reason -- it is noted below, not
					-- asserted.
					local rim = (shell :: Model):FindFirstChild("Rim") :: BasePart
					expect(rim).to.be.ok()
					-- ONE: THE BUILDER AND THE SEAT AGREE. `Gun.shellLayout().back` is what
					-- `chamberOffset` backs the shell off by, so the drawn rim's outer face must be
					-- exactly that far behind the model's pivot. If the two ever disagreed the rim
					-- would be seated against nothing.
					local layout = Gun.shellLayout(newGunConfig.SHELL_SIZE_STUDS, newGunConfig.SHELL_BASE_FRACTION)
					local rimFromPivot = (shell :: Model):GetPivot():ToObjectSpace(rim.CFrame)
					-- ALONG X: the three parts are built as unrotated cylinders offset along the
					-- shell's own X, and the model's quarter turn moves all of them together, so in
					-- the PIVOT's frame the rim is still straight behind it on X.
					local back = -rimFromPivot.Position.X + rim.Size.X / 2
					expect(math.abs(back - layout.back) < 1e-4).to.equal(true)
					-- TWO: THE SEAT IS OUTSIDE THE DRAWN TUBE'S BREECH FACE. Measured against the
					-- tube as it is really drawn (its own half length), against the gun's own
					-- arithmetic for the seat -- and the feed only ever slides the shell BACKWARD
					-- from that, so this is the claim with no clock in it.
					local seatBehindCentre = Gun.chamber(barrel, Shotgun.CONFIG).Position.Z
						- Gun.layout(Shotgun.CONFIG).barrelZ
					local rimIn = tube.CFrame:ToObjectSpace(rim.CFrame)
					TestKit.note(
						string.format(
							"task99 %s seat %.4f studs behind the tube centre (half tube %.4f); drawn rim %.4f out, mid-feed",
							tubeName,
							seatBehindCentre,
							tube.Size.X / 2,
							-rimIn.Position.X - tube.Size.X / 2
						)
					)
					expect(seatBehindCentre > tube.Size.X / 2).to.equal(true)
					-- ...and the rim is wider than the dark disc it has to cover.
					local disc = barrels:FindFirstChild(tubeName .. "BoreBreech") :: BasePart
					expect(disc).to.be.ok()
					expect(rim.Size.Y > disc.Size.Y).to.equal(true)
				end
				TestKit.note(
					string.format(
						"task99 fed shells: worst %.4f studs off the bore line (%s), bore radius %.4f",
						worst,
						worstAt,
						(barrels:FindFirstChild("BarrelLeft") :: BasePart).Size.Y / 2
					)
				)
			end)
		end)
	end)

	-- THE GLOVES (task 99). Karen, 2026-10-01: the right glove is WHITE in game. The manifest half of
	-- the fix is asserted on the server (`gun.spec`); this is the half only a client can see -- what
	-- is actually published, and that the drawn hands carry the sleeve.
	describe("the gloves", function()
		local DEFAULT_GREY = Color3.fromRGB(163, 162, 165)

		it("are never left at Roblox's default grey, and each drawn one has a sleeve", function()
			local folder = ReplicatedStorage:FindFirstChild("ViewmodelHands")
			local published = if folder then folder:GetChildren() else {}
			if #published == 0 then
				-- A gun with no hands is a real state -- the load failed, or the asset was moderated
				-- away -- and `Viewmodel.stats().handsMissing` is what reports it. Said rather than
				-- passed silently.
				TestKit.note("task99 gloves: nothing published on this client, so nothing to measure")
			end
			for _, hand in ipairs(published) do
				if hand:IsA("BasePart") then
					TestKit.note(
						string.format(
							"task99 %s published at (%d, %d, %d), %s",
							hand.Name,
							math.round(hand.Color.R * 255),
							math.round(hand.Color.G * 255),
							math.round(hand.Color.B * 255),
							hand.Material.Name
						)
					)
					-- THE DEFECT ITSELF: a part whose colour map does not draw falls back to its
					-- `Color`, and left at the default that is the white blob Karen saw.
					expect(hand.Color).never.to.equal(DEFAULT_GREY)
					-- ...AND THE EXACT STATE THAT CAUSED IT IS GONE. `AlphaMode.Overlay` blends the
					-- colour map over `Color` THROUGH THE MAP'S ALPHA, and these maps have no alpha
					-- channel -- so a hand left with a SurfaceAppearance and no `TextureID` draws no
					-- texture at all, whatever ids it carries. Either the map is on `TextureID`
					-- (the path that does not read alpha) or there is no map to draw.
					local appearance = hand:FindFirstChildOfClass("SurfaceAppearance")
					expect(appearance).to.equal(nil)
					-- ...AND THE MAP IS ON THE PATH THAT DRAWS IT. The id comes from the manifest
					-- row, because a game script cannot READ `SurfaceAppearance.ColorMap` at all --
					-- measured, 2026-10-01: "lacking capability Plugin", which took the whole boot
					-- down and published nothing.
					expect((hand :: any).TextureID).never.to.equal("")
					-- A MeshPart's Color TINTS its TextureID, so a textured hand is left white.
					expect(hand.Color).to.equal(Color3.new(1, 1, 1))
				end
			end

			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Shotgun.CONFIG.HANDLE_SIZE
			handle.Transparency = 1
			local live = Camera.Viewmodel.getSource()
			Camera.Viewmodel.setSource(function()
				return handle
			end)
			local ok, why = pcall(function()
				task.wait(0.3)
				Camera.Viewmodel.clear()
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), firstPersonConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local found = 0
				for _, drawn in ipairs(clone:GetDescendants()) do
					if drawn.Name == "HandRight" or drawn.Name == "HandLeft" then
						local sleeve = drawn:FindFirstChild("Sleeve")
						expect(sleeve).to.be.ok()
						-- IT RUNS BACK PAST THE EYE, which is the claim: longer than the hand it is
						-- joined to, so the cuff's open end is never the thing facing the camera.
						expect((sleeve :: BasePart).Size.X > (drawn :: BasePart).Size.X).to.equal(true)
						found += 1
					end
				end
				TestKit.note(string.format("task99 sleeves: %d drawn hand(s) carried one", found))
				expect(found).to.equal(#published)
			end)
			Camera.Viewmodel.clear()
			Camera.Viewmodel.setSource(live)
			handle:Destroy()
			if not ok then
				error(why, 0)
			end
		end)
	end)
end
