--!strict
-- MODEL B, the first-person gun, in a real client (task 105), and the gloves that hold it.
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
-- under the camera, and that its barrel group really turns about the model's own knuckle.
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
	-- MODEL B (task 105), DRIVEN BY PARAMETER while the flag sits OFF -- the rule every flagged path
	-- in this repo follows (docs/design/feature-flags.md 13.3). The GEOMETRY is proved on the server
	-- (tests/server/gun.spec.luau); what only a client can show is that it is really built, really
	-- under the camera, and that its barrel group really turns about the model's own knuckle.
	--
	-- NOT ONE OF THESE CASES READS A DRAWN TUBE ANY MORE, and that is the point of the task: the gun
	-- is two MeshParts of somebody else's model, so there is no `BarrelLeft` to measure a flash
	-- against. Every claim is measured against the gun's OWN arithmetic (`Gun.barrelOffset`,
	-- `Gun.chamber`, `Gun.hinge`) on the instances that are really on screen -- which is the harder
	-- test, because the arithmetic is what the mesh has to agree with.
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
				-- WHAT SWINGS IS A PARENT, not a list of names: the barrel group and the bead are
				-- children of it, and the frame group is not.
				for _, name in ipairs({ Gun.BARREL_GROUP_NAME, "Bead" }) do
					expect(barrels:FindFirstChild(name)).to.be.ok()
				end
				expect(clone:FindFirstChild(Gun.FRAME_GROUP_NAME)).to.be.ok()
				expect(barrels:FindFirstChild(Gun.FRAME_GROUP_NAME)).to.equal(nil)
				-- The two attachments the rest of the system reads off the PrimaryPart.
				expect(clone:FindFirstChild("Sight")).to.be.ok()
				expect(clone:FindFirstChild("Muzzle")).to.be.ok()
				expect((Camera.Viewmodel.sight() :: CFrame).Position).to.equal(Gun.beadOffset(Shotgun.CONFIG))
				-- WHETHER THE UPLOADS LOADED, SAID RATHER THAN ASSUMED. Both halves are published by
				-- the server through `InsertService`, which takes seconds, so a run that got there
				-- first draws the fallback boxes -- a real state, and the reason the fallback exists.
				-- Either way the gun is the same parts in the same places, which is what is asserted.
				local drawn = Camera.Viewmodel.stats().meshesDrawn
				TestKit.note(string.format("task105 %d of 2 group meshes were on this build", drawn))
				for _, name in ipairs({ Gun.BARREL_GROUP_NAME, Gun.FRAME_GROUP_NAME }) do
					local part = clone:FindFirstChild(name) or barrels:FindFirstChild(name)
					expect((part :: BasePart):IsA("BasePart")).to.equal(true)
				end
				-- THE GUN'S OWN PARTS, which is what the budget is about: the two gloves and their
				-- sleeves are the HANDS' cost and are counted in their own case. The two-player run
				-- is what taught this -- there the live templates had arrived, so the drawn model was
				-- bigger than the gun and the budget read as broken when it was not.
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
				TestKit.note(string.format("task105 the drawn new gun is %d gun part(s) plus %d worn", parts, worn))
				expect(parts).to.equal(Gun.partCount(Shotgun.CONFIG))
			end)
		end)

		it("swings its barrel group about the model's knuckle, and the frame stays put", function()
			withNewGun(function()
				local at = CFrame.new(0, 16, 0)
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(at, stateAtBlend(0), newGunConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				local group = barrels:FindFirstChild(Gun.BARREL_GROUP_NAME) :: BasePart
				local frame = clone:FindFirstChild(Gun.FRAME_GROUP_NAME) :: BasePart
				local bead = barrels:FindFirstChild("Bead") :: BasePart
				local hinge = Gun.hinge(Shotgun.CONFIG)
				local shutGroup = clone.CFrame:ToObjectSpace(group.CFrame)
				local shutFrame = clone.CFrame:ToObjectSpace(frame.CFrame)
				local shutBead = clone.CFrame:ToObjectSpace(bead.CFrame)
				local onBarrels = barrels.CFrame:ToObjectSpace(group.CFrame)

				local open = table.clone(stateAtBlend(0)) :: any
				open.openTilt = 1
				table.freeze(open)
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { false, false } })
				Camera.Viewmodel.update(at, open, newGunConfig)

				local openGroup = clone.CFrame:ToObjectSpace(group.CFrame)
				local openFrame = clone.CFrame:ToObjectSpace(frame.CFrame)
				local openBead = clone.CFrame:ToObjectSpace(bead.CFrame)
				TestKit.note(
					string.format(
						"task105 break: the barrel group moved %.3f studs on the body, the frame %.4f",
						(openGroup.Position - shutGroup.Position).Magnitude,
						(openFrame.Position - shutFrame.Position).Magnitude
					)
				)
				-- THE BARRELS MOVE AND THE FRAME DOES NOT, which is what a hinge is. The bead is
				-- measured too, because it is the one piece that is still DRAWN and it has to ride
				-- the barrels down rather than hang where the muzzle used to be.
				expect((openGroup.Position - shutGroup.Position).Magnitude > 0.1).to.equal(true)
				expect((openBead.Position - shutBead.Position).Magnitude > 0.1).to.equal(true)
				expect((openFrame.Position - shutFrame.Position).Magnitude < 1e-3).to.equal(true)
				-- ...and the group has not moved relative to the parent it belongs to: it turns as
				-- one piece rather than the mesh tearing, which is the frame task 99 existed to fix.
				local stillOnBarrels = barrels.CFrame:ToObjectSpace(group.CFrame)
				expect((stillOnBarrels.Position - onBarrels.Position).Magnitude < 1e-3).to.equal(true)
				-- AND EVERY RIDER STAYS THE SAME DISTANCE FROM THE HINGE, which is what makes the
				-- motion a rotation about THAT axis rather than a slide that looks like one. The
				-- hinge is a point in the gun's own frame now -- there is no pin part on model B to
				-- read it off -- so it is measured against `Gun.hinge`, which is what swung it.
				for _, row in ipairs({
					{ name = "group", shut = shutGroup, opened = openGroup },
					{ name = "bead", shut = shutBead, opened = openBead },
				}) do
					local shutR = (row.shut.Position - hinge).Magnitude
					local openR = (row.opened.Position - hinge).Magnitude
					TestKit.note(string.format("task105 %s is %.4f from the hinge, was %.4f", row.name, openR, shutR))
					expect(math.abs(shutR - openR) < 1e-3).to.equal(true)
				end
			end)
		end)

		it("draws the muzzle flash on the model's own bore line, at the muzzle", function()
			-- `Camera.Viewmodel.muzzle` is what `Weapon.Effects` draws the first-person flash at, and
			-- it adds the barrel's own rise to the `Muzzle` attachment. Model B's bores are 0.039
			-- studs off the centre line where the drawn gun's were 0.076 and the world gun's are
			-- 0.09, so a flash built from the wrong gun's number lands between the tubes.
			withNewGun(function()
				Camera.Viewmodel.setReload(nil)
				Camera.Viewmodel.update(CFrame.new(0, 16, 0), stateAtBlend(0), newGunConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local at = Gun.layout(Shotgun.CONFIG)
				for barrel = 1, 2 do
					local flash = Camera.Viewmodel.muzzle(barrel)
					expect(flash).to.be.ok()
					local inGun = clone.CFrame:ToObjectSpace(flash :: CFrame)
					local bore = Gun.barrelOffset(barrel, Shotgun.CONFIG)
					local across = Vector2.new(inGun.Position.X - bore.X, inGun.Position.Y - bore.Y).Magnitude
					TestKit.note(
						string.format(
							"task105 barrel %d flash %.4f studs off its bore line (bore radius %.4f), z %+.4f",
							barrel,
							across,
							at.barrelRadius,
							inGun.Position.Z
						)
					)
					expect(across < 1e-3).to.equal(true)
					-- AT THE MUZZLE END, by sign and by distance: the muzzle is the Handle's -Z.
					expect(inGun.Position.Z < 0).to.equal(true)
					expect(math.abs(inGun.Position.Z - at.muzzleZ) < 1e-3).to.equal(true)
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

		it("seats a fresh shell on the bore line, its rim OUT of the breech face", function()
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
				-- tube's own bore line, and its back face is OUTSIDE the breech. A shell still
				-- travelling in is further out than a seated one, so neither depends on a frame.
				Camera.Viewmodel.setReload({ open = true, spent = 2, loaded = { true, true } })
				Camera.Viewmodel.update(at, open, newGunConfig)
				local clone = (Camera.Viewmodel.current() :: Model).PrimaryPart :: BasePart
				local barrels = clone:FindFirstChild("Barrels") :: BasePart
				local layout = Gun.layout(Shotgun.CONFIG)
				for barrel = 1, 2 do
					local shell = clone:FindFirstChild("FreshShell" .. barrel)
					expect(shell).to.be.ok()
					-- MEASURED IN THE BARREL GROUP'S FRAME, which is where the shell is drawn and
					-- where it swings: the bore line is `Gun.barrelOffset`, the one definition of it.
					local inBarrels = barrels.CFrame:ToObjectSpace((shell :: Model):GetPivot())
					-- ...and the barrel group's own part sits `at.barrelZ` down the gun from the
					-- Handle, so the bore line in ITS frame is the same X and Y and that Z removed.
					local bore = Gun.barrelOffset(barrel, Shotgun.CONFIG)
					local across = Vector2.new(inBarrels.Position.X - bore.X, inBarrels.Position.Y - bore.Y).Magnitude
					TestKit.note(
						string.format(
							"task105 fresh shell %d is %.4f studs off its bore line (bore radius %.4f)",
							barrel,
							across,
							layout.barrelRadius
						)
					)
					-- EXACTLY on the bore line, not merely inside the tube: the bound used to be the
					-- tube's own radius, which is five times the error the old answer had, so the
					-- case passed with the new gun's branch of it deleted (task 99 round 2).
					expect(across < 1e-3).to.equal(true)
					-- THE SEAT IS OUTSIDE THE BREECH FACE. Rounds 1 and 2 of task 99 seated the shell
					-- down an opaque tube, so a loaded chamber and an empty one were the same
					-- picture. This is the claim with no clock in it: the gun's own seat, against the
					-- gun's own breech.
					local seat = Gun.chamber(barrel, Shotgun.CONFIG).Position.Z
					expect(seat > layout.breechZ).to.equal(true)
					-- AND THE BUILDER AND THE SEAT AGREE ABOUT WHERE THE RIM ENDED UP. The pivot is
					-- backed off from the rim by the shell's own length, so the two can be read back
					-- against each other -- and they must be, or the rim is seated against nothing.
					-- Which shell is drawn depends on whether the upload had loaded, so the back-off
					-- is read off the drawn thing rather than assumed.
					local rim = (shell :: Model):FindFirstChild("Rim")
					local back = if rim ~= nil
						then Gun.shellLayout(newGunConfig.SHELL_SIZE_STUDS, newGunConfig.SHELL_BASE_FRACTION).back
						else Gun.SHELL_MESH_SIZE_STUDS.X / 2
					local wanted = (Gun.chamber(barrel, Shotgun.CONFIG) * CFrame.new(0, 0, -back)).Position
					local isMesh = rim == nil
					TestKit.note(
						string.format(
							"task105 shell %d is the %s one, backed off %.4f",
							barrel,
							if isMesh then "uploaded" else "drawn",
							back
						)
					)
					-- MEASURED IN THE BARREL GROUP'S FRAME, NOT THE HANDLE'S, and with the gun open
					-- that matters: the shells are drawn from the SWUNG gun's transform, which the
					-- Handle's own CFrame is not. The group's part sits `at.barrelZ` down the gun from
					-- it, so that is what is added back. The feed slides the shell backward along Z from
					-- the seat, so only the two across-axes are exact and Z is a bound.
					expect(math.abs(inBarrels.Position.X - wanted.X) < 1e-3).to.equal(true)
					expect(math.abs(inBarrels.Position.Y - wanted.Y) < 1e-3).to.equal(true)
					expect(inBarrels.Position.Z + layout.barrelZ >= wanted.Z - 1e-3).to.equal(true)
				end
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
