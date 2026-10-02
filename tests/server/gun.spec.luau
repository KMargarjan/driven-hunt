--!strict
-- MODEL B, the first-person gun Karen chose (task 105), and the gloves' fallback colour.
--
-- WHY IT IS A SERVER SPEC when nothing here is ever drawn on a server: `ReplicatedStorage.Gun` is
-- PURE -- a piece list and some arithmetic, no Instance and no service -- so it is driven here for
-- the same reason `camera_mode.spec` is. What only a client can show (that the parts are really on
-- screen, in the right place, and that the gloves are not white) is in
-- `tests/client/gun_client.spec.luau` and `tests/client/camera_client.spec.luau`.
--
-- WHAT CHANGED, AND WHY THE OLD CASES WENT. Until task 104 this gun was EXACT GEOMETRY: Cylinder
-- tubes, a drawn action, four bore discs, a hinge pin, a splinter forend. Karen looked at it on
-- 2026-10-02 and said "bad", and picked a professional CC-BY model instead. There is no rib piece,
-- no hinge pin and no bore disc to assert any more, because there are none: the gun is two MeshParts
-- of somebody else's model plus the bead it has not got. Those cases are archived with the code they
-- tested, in `backups/task-105/gun-exact-geometry.spec.luau`.
--
-- SO WHAT IS LEFT TO ASSERT IS THE SEAM, and that is the part a screenshot shows late: that the two
-- hinge groups really do assemble at one CFrame, that the bore line the flash comes out of is the
-- model's own, that the hinge is on the model's own knuckle, that a shell seats at the model's own
-- chamber mouth, that the bead is on the shot line and on the steel, and that nothing a shot depends
-- on moved.
--
-- Note: docs/research/2026-10-01-exact-metal-gun.md (why the gun stopped being one AI mesh)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Assets = require(ServerStorage:WaitForChild("Assets"))
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local Poses = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
-- THE CAMERA'S OWN NUMBERS, not a copy of them: the sleeve is drawn by `Camera.Viewmodel` from
-- `Camera.Config`, and the bound below is only worth anything if it reads the shipped values.
local CameraConfig =
	require(StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Camera"):WaitForChild("Config"))

local CONFIG = Shotgun.CONFIG

local function byName(pieces, name)
	for _, piece in ipairs(pieces) do
		if piece.name == name then
			return piece
		end
	end
	return nil
end

return function()
	describe("the two hinge groups", function()
		local pieces = Gun.pieces(CONFIG)

		it("are one mesh each, split at the hinge, and they assemble at ONE CFrame", function()
			local barrels = byName(pieces, Gun.BARREL_GROUP_NAME)
			local frame = byName(pieces, Gun.FRAME_GROUP_NAME)
			expect(barrels).to.be.ok()
			expect(frame).to.be.ok()
			-- WHAT SWINGS AND WHAT DOES NOT, which is the whole of the break-open: the forend is
			-- inside the barrel group's mesh, so it goes down with the tubes exactly as on a real gun.
			expect(barrels.group).to.equal("barrels")
			expect(frame.group).to.equal("body")
			expect(barrels.meshKey).to.equal(Gun.MESH_KEYS[Gun.BARREL_GROUP_NAME])
			expect(frame.meshKey).to.equal(Gun.MESH_KEYS[Gun.FRAME_GROUP_NAME])
			-- ONE CFRAME, AND IT IS WHY `tools/gltf_split.py` ANCHORS BOTH HALVES to the whole gun's
			-- corners. If these two ever differ, the barrels and the action are drawn apart by that
			-- difference and no screenshot will say by how much.
			expect(barrels.meshOffset).to.be.ok()
			expect((barrels.meshOffset :: CFrame).Position).to.equal((frame.meshOffset :: CFrame).Position)
			TestKit.note(
				string.format(
					"task105 both group meshes sit at (%.4f, %.4f, %.4f)",
					(barrels.meshOffset :: CFrame).Position.X,
					(barrels.meshOffset :: CFrame).Position.Y,
					(barrels.meshOffset :: CFrame).Position.Z
				)
			)
		end)

		it("ship as two rows of one model, at one size, with the author credited", function()
			local rows = {}
			for _, key in pairs(Gun.MESH_KEYS) do
				local row = Assets.byKey(key)
				expect(row).to.be.ok()
				table.insert(rows, row)
				-- THE LICENCE IS THE CONDITION OF USING IT AT ALL: CC-BY-4.0 says the author must be
				-- credited, so a row of this model without an attribution is a licence breach that
				-- nothing else in the repo would catch.
				expect(row.licence.basis).to.equal("cc-by-4.0")
				expect(row.licence.attribution).to.be.ok()
				expect(string.find(row.licence.attribution :: string, "Ryan_Nein", 1, true)).to.be.ok()
				-- ...and the camera draws it, so the server's own boot must not load it.
				expect(row.scope).to.equal("viewmodel")
			end
			expect(#rows).to.equal(2)
			-- BOTH CARRY THE WHOLE GUN'S BOX, which is the other half of "they assemble at one
			-- CFrame": one offset is only right if both meshes are the same size and centred alike.
			expect(rows[1].sizeStuds).to.equal(rows[2].sizeStuds)
			expect(rows[1].offsetStuds).to.equal(Vector3.zero)
			expect(rows[2].offsetStuds).to.equal(Vector3.zero)
			expect(rows[1].rotationDeg).to.equal(rows[2].rotationDeg)
		end)

		it("is scaled so the gun's own length is the one the hitbox is built on", function()
			-- UNIFORMLY, so no shot or hit number moves (design 6.1's rule, and the squashed boar).
			expect(Gun.MESH_SIZE_STUDS.X).to.equal(CONFIG.HANDLE_SIZE.Z)
			local row = Assets.byKey(Gun.MESH_KEYS[Gun.BARREL_GROUP_NAME])
			expect(row.sizeStuds).to.equal(Gun.MESH_SIZE_STUDS)
			-- MEASURED rather than asserted blind: the natural box the prep run wrote out, scaled by
			-- the one factor, has to BE the target box, or the model is being stretched.
			local natural = row.naturalSizeStuds :: Vector3
			local scale = Gun.MESH_SIZE_STUDS.X / natural.X
			TestKit.note(string.format("task105 the model B gun scales by %.6f", scale))
			expect(math.abs(natural.Y * scale - Gun.MESH_SIZE_STUDS.Y) < 1e-4).to.equal(true)
			expect(math.abs(natural.Z * scale - Gun.MESH_SIZE_STUDS.Z) < 1e-4).to.equal(true)
		end)

		it("still draws a gun when nothing was published: each group has its own measured box", function()
			-- A FAILURE IS NOT AN ERROR (asset-pipeline design 5.3). An upload that did not load must
			-- leave a plain dark gun, not a hole -- so every mesh piece carries a fallback box, and
			-- the two boxes must not be the same one or the gun is drawn twice in one place.
			local barrels = byName(pieces, Gun.BARREL_GROUP_NAME)
			local frame = byName(pieces, Gun.FRAME_GROUP_NAME)
			local at = Gun.layout(CONFIG)
			for _, piece in ipairs({ barrels, frame }) do
				expect(piece.size.X > 0 and piece.size.Y > 0 and piece.size.Z > 0).to.equal(true)
				expect(piece.shape).to.equal(Enum.PartType.Block)
			end
			-- The barrel group's box runs from the muzzle to the breech; the frame group's from the
			-- knuckle to the butt. They OVERLAP along the gun, which is what a wrapped action is.
			local barrelFront = barrels.offset.Position.Z - barrels.size.Z / 2
			local frameBack = frame.offset.Position.Z + frame.size.Z / 2
			expect(math.abs(barrelFront - at.muzzleZ) < 1e-6).to.equal(true)
			expect(math.abs(frameBack - at.half) < 1e-6).to.equal(true)
			TestKit.note(
				string.format(
					"task105 fallback boxes: barrels %.3f long, frame %.3f long",
					barrels.size.Z,
					frame.size.Z
				)
			)
		end)

		it("points the imported mesh's MUZZLE down the gun, not the butt", function()
			-- TASK 107, AND IT IS THE CASE THAT WOULD HAVE CAUGHT TASK 105. The gun shipped END-FOR-END
			-- REVERSED: the walnut stock and the action sat at the far end where the muzzle belongs
			-- (`.screenshots/20261002T121400Z-pose-carry.png`), and the aimed eye looked into two open
			-- muzzles a foot away (`...121329Z-pose-aim.png`). Nothing measured the composition,
			-- because the only claim anybody had made was "the file is written muzzle-at-+X", which
			-- was true and not enough.
			--
			-- SO THE CLAIM IS THE ROUND TRIP. `Gun.MESH_MUZZLE_AXIS` is where the muzzle points in the
			-- MeshPart's OWN axes once Roblox has imported the FBX -- the file's +X, reversed by the
			-- import, measured on screen. Turned by the gun's own `MESH_ROTATION_DEG` it has to come
			-- out as the gun's muzzle direction, which is the Handle's -Z. Flip the sign of either
			-- number and this fails.
			local turned = (CFrame.Angles(0, math.rad(Gun.MESH_ROTATION_DEG), 0) * Gun.MESH_MUZZLE_AXIS).Unit
			local wanted = Vector3.new(0, 0, -1)
			TestKit.note(
				string.format(
					"task107 the mesh's muzzle axis %s turns by %.0f to (%.3f, %.3f, %.3f)",
					tostring(Gun.MESH_MUZZLE_AXIS),
					Gun.MESH_ROTATION_DEG,
					turned.X,
					turned.Y,
					turned.Z
				)
			)
			expect((turned - wanted).Magnitude < 1e-5).to.equal(true)
			-- ...and the shell comes through the same import, so it takes the same half turn. One
			-- number, used twice: a shell left at the gun's old turn seats its brass head up the
			-- barrel.
			expect(Gun.SHELL_ROTATION_DEG).to.equal(Gun.MESH_ROTATION_DEG)
		end)

		it("puts the stock and the action BEHIND the breech, with the muzzle at the far end", function()
			-- THE SAME DEFECT STATED AS GEOMETRY, which is what a player sees: on a gun held at the
			-- shoulder the butt is nearest the eye and the muzzle is furthest. In the Handle's frame
			-- the muzzle is -Z and the shooter is +Z, so every part of the frame group -- the action,
			-- the trigger, the stock -- lies BEHIND the barrels' breech, and the barrel group reaches
			-- the muzzle end and the frame group does not.
			local at = Gun.layout(CONFIG)
			local barrels = byName(pieces, Gun.BARREL_GROUP_NAME)
			local frame = byName(pieces, Gun.FRAME_GROUP_NAME)
			local frameFront = frame.offset.Position.Z - frame.size.Z / 2
			local frameCentre = frame.offset.Position.Z
			local barrelFront = barrels.offset.Position.Z - barrels.size.Z / 2
			TestKit.note(
				string.format(
					"task107 muzzle %.3f, barrel group front %.3f, frame front %.3f, frame centre %.3f, breech %.3f",
					at.muzzleZ,
					barrelFront,
					frameFront,
					frameCentre,
					at.breechZ
				)
			)
			-- THE BARREL GROUP REACHES THE MUZZLE and the frame group does not come near it.
			expect(math.abs(barrelFront - at.muzzleZ) < 1e-6).to.equal(true)
			expect(frameFront > at.muzzleZ).to.equal(true)
			-- THE STOCK'S CENTRE IS BEHIND THE BREECH, toward the shooter: that is the whole claim.
			expect(frameCentre > at.breechZ).to.equal(true)
			-- ...and the butt is the furthest thing back, at the Handle's own +Z half.
			expect(math.abs((frame.offset.Position.Z + frame.size.Z / 2) - at.half) < 1e-6).to.equal(true)
			-- THE HINGE IS AT THE ACTION'S FRONT LOWER EDGE: ahead of the breech face, behind the
			-- frame group's own front, and below the bore line.
			local hinge = Gun.hinge(CONFIG)
			expect(hinge.Z < at.breechZ).to.equal(true)
			expect(hinge.Z >= frameFront).to.equal(true)
			expect(hinge.Y < at.barrelY).to.equal(true)
		end)

		it("costs the budget this gun states, so growth is a decision", function()
			local count = Gun.partCount(CONFIG)
			TestKit.note(string.format("task105 the drawn gun is %d parts", count))
			-- 27 -> 5 in task 105: two group meshes, the bead, and the two envelopes the viewmodel
			-- adds. The exact-geometry gun was twenty-five drawn parts.
			expect(count).to.equal(5)
		end)
	end)

	describe("the hinge, the chambers and the bead", function()
		local pieces = Gun.pieces(CONFIG)
		local at = Gun.layout(CONFIG)

		it("turns the barrels on the model's own knuckle, below the bores and ahead of the breech", function()
			-- A BREAK ACTION TURNS ON THE KNUCKLE -- the rounded front of the action -- so the axis is
			-- that round's centre. Both numbers are measured off model B; what this asserts is that
			-- they are still a HINGE: below the bore line (or the barrels would rise through the
			-- action) and ahead of the breech face (or the breech could never clear the standing
			-- breech when the gun opens).
			local hinge = Gun.hinge(CONFIG)
			TestKit.note(string.format("task105 hinge at y %.4f z %.4f", hinge.Y, hinge.Z))
			expect(hinge.X).to.equal(0)
			expect(hinge.Y < at.barrelY).to.equal(true)
			expect(hinge.Z < at.breechZ).to.equal(true)
			-- ...and it is INSIDE the frame group, which is the half it belongs to: a pin hanging in
			-- front of the action is not a pin.
			local frame = byName(pieces, Gun.FRAME_GROUP_NAME)
			expect(hinge.Z >= frame.offset.Position.Z - frame.size.Z / 2).to.equal(true)
		end)

		it("opens without driving the breech through the standing breech face", function()
			-- MEASURED, NOT ARGUED. Rotate the breech end of the barrels about the hinge by the shipped
			-- break angle and it must end up ABOVE where it started: that is what "breaks open" means,
			-- and a hinge behind the breech would take it backwards into the action instead.
			local hinge = CFrame.new(Gun.hinge(CONFIG))
			local angle = math.rad(Poses.DATA.newGun.reload.openDeg)
			local swing = hinge * CFrame.Angles(-angle, 0, 0) * hinge:Inverse()
			local breech = Vector3.new(0, at.barrelY, at.breechZ)
			local moved = (swing * CFrame.new(breech)).Position
			TestKit.note(
				string.format(
					"task105 at %.0f degrees the breech rises %.3f and moves %.3f forward",
					Poses.DATA.newGun.reload.openDeg,
					moved.Y - breech.Y,
					breech.Z - moved.Z
				)
			)
			expect(moved.Y > breech.Y).to.equal(true)
			expect(moved.Z < breech.Z).to.equal(true)
			-- ...and the muzzle goes DOWN, which is the other half of the same motion.
			local muzzle = (swing * CFrame.new(Vector3.new(0, at.barrelY, at.muzzleZ))).Position
			expect(muzzle.Y < at.barrelY).to.equal(true)
		end)

		it("seats a shell's RIM at each tube's own chamber mouth, OUTSIDE the breech face", function()
			for barrel = 1, 2 do
				local chamber = Gun.chamber(barrel, CONFIG)
				local bore = Gun.barrelOffset(barrel, CONFIG)
				-- ON THE TUBE'S OWN BORE LINE, not on the gun's centre line: the old mesh gun put the
				-- shell between the two tubes, where it floated in the gap.
				expect(chamber.Position.X).to.equal(bore.X)
				expect(chamber.Position.Y).to.equal(bore.Y)
				-- ...and PROUD of the breech face, because a shell seated inside an opaque tube is a
				-- shell nobody can see.
				expect(chamber.Position.Z > at.breechZ).to.equal(true)
				TestKit.note(
					string.format(
						"task105 chamber %d at x %.4f, %.4f proud of the breech",
						barrel,
						chamber.Position.X,
						chamber.Position.Z - at.breechZ
					)
				)
			end
			-- The two chambers are a tube apart and on opposite sides.
			local one, two = Gun.chamber(1, CONFIG).Position, Gun.chamber(2, CONFIG).Position
			expect(one.X * two.X < 0).to.equal(true)
			expect(math.abs(math.abs(one.X - two.X) - at.barrelRadius * 2) < 0.002).to.equal(true)
		end)

		it("puts the bead ON the steel, on the shot line, at the muzzle", function()
			local bead = byName(pieces, "Bead")
			expect(bead).to.be.ok()
			-- IT RIDES THE BARRELS, because a bead is a sight on the barrels: with the gun broken
			-- open it belongs down at the muzzle with them.
			expect(bead.group).to.equal("barrels")
			-- ON THE SHOT LINE: dead centre across the gun, which is what makes it an aiming mark at
			-- all, and the same point `Mode.aimOffset` solves the aimed pose from.
			expect(bead.offset.Position.X).to.equal(0)
			expect(Gun.sight(CONFIG).Position).to.equal(Gun.beadOffset(CONFIG))
			expect(Gun.beadOffset(CONFIG)).to.equal(bead.offset.Position)
			-- AND ON THE STEEL, WHICH IS SOLVED ARITHMETIC AND NOT A PICKED NUMBER: it rests in the
			-- notch between the two tube tops, touching both, so the distance from the bead's centre
			-- to a tube's axis is exactly the two radii added.
			local r = at.barrelRadius
			local b = bead.size.X / 2
			local tube = Gun.barrelOffset(1, CONFIG)
			local gap = (Vector2.new(tube.X, tube.Y) - Vector2.new(0, bead.offset.Position.Y)).Magnitude
			TestKit.note(string.format("task105 bead centre %.4f from a bore axis, r+b %.4f", gap, r + b))
			expect(math.abs(gap - (r + b)) < 1e-6).to.equal(true)
			-- ...and it stands above the tubes, or it is a sight nobody can find.
			expect(bead.offset.Position.Y + b > at.barrelTopY).to.equal(true)
			-- At the muzzle end, not somewhere down the gun.
			expect(bead.offset.Position.Z < at.muzzleZ + at.barrelLength * 0.1).to.equal(true)
		end)
	end)

	describe("what a shot depends on", function()
		it("moves no number a shot depends on", function()
			-- The hitbox, the grip and the muzzle are the world gun's and this task may not touch
			-- them: this gun is DRAWN under one player's camera and nothing else.
			expect(CONFIG.HANDLE_SIZE).to.equal(Vector3.new(0.4, 0.5, 4.4))
			expect(CONFIG.MUZZLE_OFFSET).to.equal(Vector3.new(0, 0, -2.2))
		end)

		it("puts the Muzzle attachment on the HANDLE'S AXIS, so the rise is counted once", function()
			-- `Camera.Viewmodel.muzzle` adds the barrel's own rise to whatever the attachment says,
			-- because on every gun in this repo the attachment sits on the Handle's axis
			-- (`Weapon.Hardware`: `CFrame.new(config.MUZZLE_OFFSET)`). An attachment on the bore line
			-- would have the rise counted twice and draw the flash off the top of the barrels.
			expect(Gun.muzzle(CONFIG).Position).to.equal(CONFIG.MUZZLE_OFFSET)
		end)

		it("gives each tube ONE bore line, and it is MODEL B'S, not the drawn gun's", function()
			local at = Gun.layout(CONFIG)
			for barrel = 1, 2 do
				local offset = Gun.barrelOffset(barrel, CONFIG)
				-- THE SIGN STILL COMES FROM `Shotgun`, so "which tube is barrel 1" has one owner in
				-- the whole repo.
				local theirs = Shotgun.barrelMuzzleOffset(barrel, CONFIG)
				expect(offset.X > 0).to.equal(theirs.X > 0)
				-- WITHIN A TOLERANCE, because a Vector3 holds SINGLE precision and `at.barrelY` is a
				-- Lua double: 0.12 comes back out of the vector as 0.11999999731779099, and the first
				-- run of this case failed on exactly that. Every comparison here is between a number
				-- that has been through a Vector3 and one that has not.
				expect(math.abs(offset.Y - at.barrelY) < 1e-6).to.equal(true)
				-- A REAL 12-GAUGE PAIR, which is why this model was chosen: the tubes' centres are one
				-- tube apart, and that tube is about 21.7 mm at this gun's scale. The drawn gun's were
				-- 0.145 studs across -- nearly twice life -- and `Shotgun`'s world gun is 0.09 apart.
				TestKit.note(
					string.format(
						"task105 barrel %d bore at x %.4f, tube %.4f across",
						barrel,
						offset.X,
						at.barrelRadius * 2
					)
				)
				expect(math.abs(math.abs(offset.X) - at.barrelRadius) < 0.002).to.equal(true)
				expect(at.barrelRadius * 2 < 0.09).to.equal(true)
				-- THE DRAWN FLASH POINT, as `Camera.Viewmodel.muzzle` builds it: the attachment plus
				-- this offset, which must land on the tube's axis at its muzzle end.
				local flash = Gun.muzzle(CONFIG) * CFrame.new(offset)
				expect(math.abs(flash.Position.X - offset.X) < 1e-6).to.equal(true)
				expect(math.abs(flash.Position.Y - offset.Y) < 1e-6).to.equal(true)
				expect(math.abs(flash.Position.Z - at.muzzleZ) < 1e-6).to.equal(true)
			end
		end)

		it("keeps a real gun's barrel fraction", function()
			local at = Gun.layout(CONFIG)
			TestKit.note(string.format("task105 barrels are %.4f of the gun", at.barrelLength / at.total))
			-- A Beretta 486 Parallelo is 28 in of barrel in a 45 in gun: 0.622. This model measured
			-- 0.617, which is the reason it looks like a gun.
			expect(math.abs(at.barrelLength / at.total - 28 / 45) < 0.01).to.equal(true)
		end)
	end)

	describe("the hands on this gun", function()
		it("seeds the left hand ON THE FOREND and the right ON THE GRIP", function()
			-- THE BOUND IS THE MODEL'S OWN, read off `Gun.layout` rather than written down. The left
			-- hand holds the forend, which is inside the barrel group and swings with it; the right
			-- holds the grip, which is behind the trigger on the frame group.
			--
			-- ROUND 1 OF TASK 100 IS WHY THIS CASE EXISTS AT ALL: the seed was computed in the barrel
			-- group's frame and the viewmodel poses hands in the GUN's, so a number right in one put
			-- the glove at the breech in the other -- two hands at the grip and none on the wood.
			local at = Gun.layout(CONFIG)
			for _, pose in ipairs({ "carry", "aim", "reload" }) do
				local left = Poses.DATA.newGun[pose].left.pos
				local right = Poses.DATA.newGun[pose].right.pos
				TestKit.note(string.format("task105 newGun.%s left z %.4f, right z %.4f", pose, left.z, right.z))
				-- The left hand is somewhere along the barrels, ahead of the breech.
				expect(left.z < at.breechZ).to.equal(true)
				expect(left.z > at.muzzleZ).to.equal(true)
				-- ...and the right is BEHIND the breech, on the frame group, ahead of the butt.
				expect(right.z > at.breechZ).to.equal(true)
				expect(right.z < at.half).to.equal(true)
				-- THE RIGHT HAND IS ON THE GUN'S CENTRE LINE, because it wraps the wrist and its own
				-- model is symmetric about its box.
				expect(right.x).to.equal(0)
				-- THE LEFT ONE IS NOT, AND TASK 106 IS WHY. What this pose places is the MESH'S
				-- BOUNDING-BOX CENTRE, not the palm, and Karen's left glove is a palm-up C whose
				-- forearm runs at an angle to the fingers -- so its box is a diagonal and the hand
				-- sits off-centre inside it. Asserting zero here asserted a fact about the OLD
				-- model's symmetry, and the first gate run of task 106 caught it.
				--
				-- WHAT IS STILL TRUE, and is the claim worth keeping: the offset is less than the
				-- hand's OWN half-width, so the palm is within a hand of the gun's centre line
				-- rather than beside the gun.
				local leftHand = Assets.byKey("hand.left")
				local halfWidth = math.min(leftHand.sizeStuds.X, leftHand.sizeStuds.Y, leftHand.sizeStuds.Z) / 2
				TestKit.note(string.format("task106 newGun.%s left x %.4f, half-width %.4f", pose, left.x, halfWidth))
				expect(math.abs(left.x) < halfWidth).to.equal(true)
			end
		end)
	end)

	describe("the gloves", function()
		-- THE WHITE GLOVE (task 99). Karen, 2026-10-01: the right glove is WHITE in game. Both hands
		-- carry a SurfaceAppearance with a ColorMap and both source textures are dark brown, but the
		-- pixels of the aimed screenshot read as Roblox's DEFAULT medium stone grey -- what a part
		-- shows when its map does not draw. So every hand row must declare the colour its own
		-- texture would have given it, and `ViewmodelAssetsBoot` writes it.
		local DEFAULT_GREY = Color3.fromRGB(163, 162, 165)

		it("every published hand declares a fallback colour, and it is not the default grey", function()
			for name, key in pairs(HandAssets.KEY_OF) do
				local row = Assets.byKey(key)
				expect(row).to.be.ok()
				expect(row.fallbackColor).to.be.ok()
				-- AND THE COLOUR MAP'S OWN ID, which is what actually draws it: a game script cannot
				-- read `SurfaceAppearance.ColorMap`, so the row carries the id and the boot writes it
				-- to `TextureID`. A row without one is a hand that can only ever be a flat colour.
				expect(row.textureId).to.be.ok()
				expect(string.sub(row.textureId :: string, 1, 13)).to.equal("rbxassetid://")
				local colour = row.fallbackColor :: Color3
				TestKit.note(
					string.format(
						"task99 %s fallback (%d, %d, %d)",
						name,
						math.round(colour.R * 255),
						math.round(colour.G * 255),
						math.round(colour.B * 255)
					)
				)
				-- NOT THE DEFAULT, which is the defect itself: a hand left at medium stone grey is
				-- the white blob Karen saw.
				expect(colour).never.to.equal(DEFAULT_GREY)
				-- ...and dark, like the leather the source texture actually is: anything this
				-- bright is the fault coming back under another name.
				expect(colour.R < 0.5 and colour.G < 0.5 and colour.B < 0.5).to.equal(true)
			end
		end)

		it("is sized to the grip it closes on, not to a hand's own length", function()
			-- TASK 106, AND IT IS THE THIRD TIME THIS NUMBER HAS MOVED, so it is now pinned to
			-- something the gun can be measured against rather than to an anatomy fact. A generated
			-- glove is chunky: at the 1.27 studs that is right for 330 mm of real hand and cuff,
			-- Karen's glove measured 0.665 studs ACROSS THE FINGERS -- 173 mm, nearly twice an adult
			-- palm -- and task 105's aimed capture showed exactly that.
			--
			-- SO THE ANCHOR IS MODEL B'S STOCK WRIST, which is what the fist has to close on: 0.320
			-- studs from the grip's front to the comb, 83 mm at this gun's scale. A fist round a
			-- wrist that size is about an adult palm across.
			local right = Assets.byKey(Assets.KEYS.gunHandRight)
			local left = Assets.byKey(Assets.KEYS.gunHandLeft)
			local across = right.sizeStuds.Y -- the right glove's across-the-fingers axis
			TestKit.note(
				string.format(
					"task106 right glove %.3f long, %.3f across; left %.3f long",
					right.sizeStuds.X,
					across,
					math.max(left.sizeStuds.X, left.sizeStuds.Y, left.sizeStuds.Z)
				)
			)
			expect(math.abs(across - 0.35) < 0.005).to.equal(true)
			-- ...and an adult palm is 85 to 95 mm, which at 259.8 mm to the stud is this band. The
			-- old 1.27 put it at 173 mm and fails here, which is the point of the case.
			expect(across * 259.8 > 85 and across * 259.8 < 95).to.equal(true)
			-- THE PAIR IS ONE PAIR, AND THE CLAIM IS THE SCALE FACTOR (round 1, note). Comparing the
			-- two longest axes proves nothing: `uniformTo` pins the longest axis to the dial, so ANY
			-- two models come out equal there. What "one pair" means is that both models were shrunk
			-- by the same factor -- two hands drawn at different scales is the defect nobody measures
			-- until a screenshot shows it.
			local rightScale = right.sizeStuds.X / (right.naturalSizeStuds :: Vector3).X
			local leftScale = left.sizeStuds.X / (left.naturalSizeStuds :: Vector3).X
			TestKit.note(string.format("task106 scale: right %.6f, left %.6f", rightScale, leftScale))
			expect(math.abs(rightScale - leftScale) < 1e-4).to.equal(true)
			-- A hand is still several times the width of the barrel it holds.
			local at = Gun.layout(CONFIG)
			expect(across > at.barrelRadius * 4).to.equal(true)
		end)

		it("gives each gun its OWN pair, so the flag-OFF build cannot be handed model B's", function()
			-- ROUND 1'S FINDING 1, AND THIS CASE IS THE THING THAT WOULD HAVE CAUGHT IT. The new
			-- gloves first shipped as `hand.right` VERSION 2 -- and a new version supersedes, so
			-- `Assets.byKey("hand.right")` answered with them for every caller, including the
			-- flag-OFF default build whose TOP-LEVEL poses were measured against the v1 models. The
			-- old gun drew the new left glove upside down (its `twist` of 180 belongs to a palm-DOWN
			-- model) at 53 % of the size its poses assume.
			--
			-- SO THE TWO GUNS HAVE TWO KEYS, and this asserts all three halves of that: the old keys
			-- still answer with v1, the new keys answer with the new pair, and no row of either is
			-- superseded by the other.
			for name, key in pairs(HandAssets.KEY_OF) do
				local old = Assets.byKey(key)
				local new = Assets.byKey(HandAssets.NEW_GUN_KEY_OF[name])
				expect(old).to.be.ok()
				expect(new).to.be.ok()
				expect(old.modelId).never.to.equal(new.modelId)
				-- THE OLD PAIR IS STILL THE 1.27-STUD PAIR the top-level poses were measured at. A
				-- regression here is the flag-OFF build changing size, which is exactly what round 1
				-- shipped.
				local oldLongest = math.max(old.sizeStuds.X, old.sizeStuds.Y, old.sizeStuds.Z)
				local newLongest = math.max(new.sizeStuds.X, new.sizeStuds.Y, new.sizeStuds.Z)
				TestKit.note(
					string.format("task106 %s: old gun %.3f studs, model B %.3f", name, oldLongest, newLongest)
				)
				expect(math.abs(oldLongest - 1.27) < 1e-4).to.equal(true)
				expect(newLongest < oldLongest * 0.75).to.equal(true)
				-- ...and neither row may be superseded by the other: that is the mechanism that
				-- failed.
				expect(old.supersededBy).to.equal(nil)
				expect(new.supersededBy).to.equal(nil)
			end
			-- THE TWO KEY TABLES NAME DIFFERENT KEYS, which is what makes the lookup above possible
			-- at all. One table pointing at the other's keys is the same defect wearing a hat.
			for name, key in pairs(HandAssets.KEY_OF) do
				expect(HandAssets.NEW_GUN_KEY_OF[name]).never.to.equal(key)
			end
			-- ...and the two folders they are published into are different, or one pair overwrites
			-- the other on the client.
			expect(HandAssets.NEW_GUN_FOLDER_NAME).never.to.equal(HandAssets.FOLDER_NAME)
		end)

		it("starts each gun's sleeve INSIDE the glove it belongs to", function()
			-- ROUND 1'S NOTE, MADE INTO A BOUND. `Camera.Viewmodel.poseHands` places the sleeve at
			-- `hand.Size.X / 2 + sleeve.Size.X / 2 - overlap` back along the hand's own axis: if the
			-- overlap ever exceeds half the hand, the cylinder's near end comes out through the
			-- fingers instead of starting inside the cuff. Model B's glove has 0.015 studs of margin
			-- and nothing was asserting it, so the next size tweak would have shown it on screen.
			--
			-- IT IS A SERVER CASE because the sizes are the manifest's and the numbers are
			-- `Camera.Config`'s, and both are readable here. The client cannot see the manifest, and
			-- the published Instances have not landed by the time its specs run.
			for _, case in ipairs({
				{
					name = "old gun",
					key = Assets.KEYS.handRight,
					overlap = CameraConfig.SLEEVE_OVERLAP_STUDS,
					length = CameraConfig.SLEEVE_LENGTH_STUDS,
				},
				{
					name = "model B",
					key = Assets.KEYS.gunHandRight,
					overlap = CameraConfig.SLEEVE_OVERLAP_NEW_GUN_STUDS,
					length = CameraConfig.SLEEVE_LENGTH_NEW_GUN_STUDS,
				},
			}) do
				local hand = Assets.byKey(case.key)
				expect(hand).to.be.ok()
				local halfHand = hand.sizeStuds.X / 2
				TestKit.note(
					string.format(
						"task106 %s: overlap %.3f against half a hand %.3f, sleeve %.2f long",
						case.name,
						case.overlap,
						halfHand,
						case.length
					)
				)
				expect(case.overlap < halfHand).to.equal(true)
				-- ...and the sleeve is longer than the hand it joins, which is the claim that its far
				-- end is behind the eye rather than beside the cuff.
				expect(case.length > hand.sizeStuds.X).to.equal(true)
			end
		end)

		it("keeps the old gun's own poses, measured for the old gun's own gloves", function()
			-- THE OTHER HALF OF FINDING 1: the TOP-LEVEL poses are the v1 pair's, and nothing in task
			-- 106 re-measured them. The `newGun` set answers differently BECAUSE the models differ --
			-- Karen's new left glove is modelled palm-up, so its twist is 0 where the old one needs a
			-- half turn to get the palm under the barrels.
			expect(Poses.DATA.carry.left.rot.twist).to.equal(180)
			expect(Poses.DATA.aim.left.rot.twist).to.equal(180)
			expect(Poses.DATA.reload.left.rot.twist).to.equal(180)
			for _, pose in ipairs({ "carry", "aim", "reload" }) do
				TestKit.note(
					string.format(
						"task106 %s left twist: old gun %.0f, model B %.0f",
						pose,
						Poses.DATA[pose].left.rot.twist,
						Poses.DATA.newGun[pose].left.rot.twist
					)
				)
				expect(Poses.DATA.newGun[pose].left.rot.twist).never.to.equal(Poses.DATA[pose].left.rot.twist)
			end
		end)
	end)

	describe("the model B rows as a whole", function()
		it("retires the pieces this gun replaced, without losing their ids", function()
			-- RULE 7: the `gun.stock` row stays, with its asset id, because an id that has been in a
			-- place is provenance. What changes is that nothing asks for it any more -- model B's
			-- frame group IS a stock -- so the viewmodel's boot must not try to load it.
			local retired = Assets.byKey("gun.stock")
			expect(retired).to.be.ok()
			expect(retired.scope).to.equal("retired")
			local viewmodel = Assets.keysFor("viewmodel")
			local seen = {}
			for _, key in ipairs(viewmodel) do
				seen[key] = true
			end
			expect(seen["gun.stock"]).to.equal(nil)
			-- ...and the three model B keys ARE in it, or the gun is drawn as three fallback boxes.
			for _, key in pairs(Gun.MESH_KEYS) do
				expect(seen[key]).to.equal(true)
			end
			expect(seen[Gun.SHELL_KEY]).to.equal(true)
			TestKit.note(string.format("task105 viewmodel scope loads %d key(s)", #viewmodel))
		end)

		it("sizes the shell at the gun's own scale, mouth forward", function()
			local row = Assets.byKey(Gun.SHELL_KEY)
			expect(row).to.be.ok()
			expect(row.sizeStuds).to.equal(Gun.SHELL_MESH_SIZE_STUDS)
			-- IT IS NOT IN THE GUN'S BOX: a cartridge anchored to the gun's corners would be a
			-- 4.4-stud MeshPart. Its long axis is still its own X, like the gun's and like the drawn
			-- shell's, so one quarter turn seats all three.
			expect(row.sizeStuds.X < Gun.MESH_SIZE_STUDS.X / 10).to.equal(true)
			expect(row.sizeStuds.X > row.sizeStuds.Y).to.equal(true)
			expect(row.rotationDeg).to.equal(Vector3.new(0, Gun.SHELL_ROTATION_DEG, 0))
			-- AND IT FITS THE CHAMBER IT GOES IN, which is the only thing about it the gun cares
			-- about: a 12-gauge shell is a hair narrower than the bore it slides into.
			local at = Gun.layout(CONFIG)
			TestKit.note(
				string.format("task105 shell %.4f across against a %.4f bore", row.sizeStuds.Y, at.barrelRadius * 2)
			)
			expect(row.sizeStuds.Y < at.barrelRadius * 2).to.equal(true)
			expect(row.sizeStuds.Y > at.barrelRadius).to.equal(true)
		end)
	end)
end
