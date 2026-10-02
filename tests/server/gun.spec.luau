--!strict
-- The NEW first-person gun's exact geometry (task 99), and the gloves' fallback colour.
--
-- WHY IT IS A SERVER SPEC when nothing here is ever drawn on a server: `ReplicatedStorage.Gun` is
-- PURE -- a piece list and four pieces of arithmetic, no Instance and no service -- so it is driven
-- here for the same reason `camera_mode.spec` is. What only a client can show (that the parts are
-- really on screen, in the right place, and that the gloves are not white) is in
-- `tests/client/camera_client.spec.luau`.
--
-- EVERY CLAIM IS ABOUT THE SHIPPED NUMBERS, because the shipped numbers are the gun: a barrel that
-- stops being a Cylinder, a bore disc that pokes out of its tube, or a hinge pin that is not on the
-- axis the barrels turn about are all things a screenshot shows late and this shows at once.
--
-- Note: docs/research/2026-10-01-exact-metal-gun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Assets = require(ServerStorage:WaitForChild("Assets"))
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local Poses = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

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
	describe("the barrels", function()
		local pieces = Gun.pieces(CONFIG)

		it("are two round tubes, side by side, on one bore line", function()
			local left = byName(pieces, "BarrelLeft")
			local right = byName(pieces, "BarrelRight")
			expect(left).to.be.ok()
			expect(right).to.be.ok()
			for _, tube in ipairs({ left, right }) do
				-- ROUND BY CONSTRUCTION, which is the whole reason this gun is parts rather than a
				-- generated mesh: a Roblox Cylinder is analytic, so there is no facet count at which
				-- it stops being round (the note, section 3).
				expect(tube.shape).to.equal(Enum.PartType.Cylinder)
				-- ...AND NOT SQUASHED INTO AN ELLIPSE. A cylinder's length is its own X; the other
				-- two axes are the circle, and they must be equal or the "round" above is a lie.
				expect(tube.size.Y).to.equal(tube.size.Z)
				expect(tube.size.X > tube.size.Y * 5).to.equal(true) -- a tube, not a disc
			end
			-- SIDE BY SIDE: same height, mirrored across the centre line, and touching.
			expect(left.offset.Position.Y).to.equal(right.offset.Position.Y)
			expect(left.offset.Position.X).to.equal(-right.offset.Position.X)
			local gap = right.offset.Position.X - left.offset.Position.X
			TestKit.note(string.format("task99 barrels: %.3f studs across, centres %.3f apart", left.size.Y, gap))
			expect(gap < left.size.Y * 1.25).to.equal(true) -- they read as ONE pair, not two sticks
		end)

		it("run the spec sheet's 28 of 45 inches, inside the Handle this repo already has", function()
			local at = Gun.layout(CONFIG)
			expect(at.total).to.equal(CONFIG.HANDLE_SIZE.Z)
			expect(math.abs(at.barrelLength / at.total - 28 / 45) < 1e-9).to.equal(true)
			expect(at.muzzleZ).to.equal(-CONFIG.HANDLE_SIZE.Z / 2)
		end)

		it("show two dark openings at each end, each one PROUD of its own tube's end face", function()
			local bores = 0
			for _, piece in ipairs(pieces) do
				local found = string.find(piece.name, "Bore", 1, true)
				if found then
					bores += 1
					local tube = byName(pieces, string.sub(piece.name, 1, found - 1))
					expect(tube).to.be.ok()
					-- NARROWER THAN THE TUBE and on its axis, so a ring of blued steel shows all
					-- round the dark: a wall, then the hole.
					expect(piece.size.Y < tube.size.Y).to.equal(true)
					expect(piece.offset.Position.X).to.equal(tube.offset.Position.X)
					expect(piece.offset.Position.Y).to.equal(tube.offset.Position.Y)
					-- ...AND OUTSIDE THE END FACE, BY SIGN. ROUND 2, FINDING 1: a Roblox Part is an
					-- opaque closed solid, so a smaller part wholly inside a larger one is never
					-- drawn -- and rounds 1 and 2 both put these discs INSIDE the tube, which cost
					-- four invisible parts and a seated shell nobody could see. A distance cannot
					-- say this (0.002 in and 0.002 out are the same distance, and only one of them
					-- can be seen), so what is asserted is the DIRECTION.
					local towardOpening = if string.find(piece.name, "Muzzle", 1, true) then -1 else 1
					local tubeFace = tube.offset.Position.Z + towardOpening * tube.size.X / 2
					local discFace = piece.offset.Position.Z + towardOpening * piece.size.X / 2
					local proud = towardOpening * (discFace - tubeFace)
					TestKit.note(string.format("task99 %s stands %.4f studs out of its end face", piece.name, proud))
					expect(proud > 0).to.equal(true)
				end
			end
			-- Two tubes, two ends each: the MUZZLE pair is what you look at down the rib and the
			-- BREECH pair is what you see with the gun broken open, which is the frame this task
			-- exists to fix.
			expect(bores).to.equal(4)
		end)

		it("lets you SEE both openings: nothing in the barrel group stands in front of one", function()
			-- ROUND 1, FINDING 1, AND THE FIRST VERSION OF THIS CASE COULD NOT CATCH ROUND 2'S. A
			-- `BreechFace` plate spanned both tube ends and buried both breech discs; it was deleted,
			-- and then THE TUBE ITSELF buried them, because this case excluded the one part that
			-- could -- `other.name == tubeName`. It no longer does: the tube a disc belongs to has to
			-- clear that disc like everything else, which is only true when the disc is proud of the
			-- end face.
			--
			-- THE GROUP IS THE RIGHT SCOPE, not the whole gun: the break-open is what separates the
			-- barrels from the body, so with the gun open the standing breech is nowhere near the
			-- chamber mouths. What may never stand in front of a bore is something that SWINGS WITH
			-- IT -- which is exactly what the plate was.
			--
			-- AXIS-ALIGNED BOXES, which every piece in the barrel group is: the tubes, the discs and
			-- the forend are cylinders along Z, and the rib and the hook are blocks.
			for _, piece in ipairs(pieces) do
				local at = string.find(piece.name, "Bore", 1, true)
				if at == nil then
					continue
				end
				local towardOpening = if string.find(piece.name, "Muzzle", 1, true) then -1 else 1
				local face = piece.offset.Position.Z + towardOpening * piece.size.X / 2
				local blocked = {}
				for _, other in ipairs(pieces) do
					-- THE TUBE IS NOT EXCLUDED (round 2, finding 1), only the disc itself.
					if other.group ~= "barrels" or other.name == piece.name then
						continue
					end
					-- A CYLINDER LYING ALONG Z CARRIES ITS LENGTH ON X, and a block does not, so the
					-- half-extents are read differently for the two. The first run of this case used
					-- the block rule for both and reported the LEFT muzzle bore as hidden by the
					-- RIGHT BARREL -- a tube 2.7 studs long "spanning" 1.37 studs sideways. The test
					-- was wrong, not the gun.
					--
					-- THE QUARTER TURN IS ABOUT Y, so a cylinder's own X goes to the gun's -Z, its Y
					-- stays Y and its Z goes to the gun's +X. Task 100 corrected the X and Y rows,
					-- which were written X<-size.Y and Y<-size.Z: harmless while every cylinder in
					-- the group is CIRCULAR (size.Y == size.Z, true of the tubes and the discs) and
					-- wrong the moment one is not -- which the splinter forend is.
					local cylinder = other.shape == Enum.PartType.Cylinder
					local halfX = if cylinder then other.size.Z / 2 else other.size.X / 2
					local halfY = other.size.Y / 2 -- the same on both: the quarter turn leaves Y alone
					local halfZ = if cylinder then other.size.X / 2 else other.size.Z / 2
					local spansX = math.abs(other.offset.Position.X - piece.offset.Position.X) < halfX
					local spansY = math.abs(other.offset.Position.Y - piece.offset.Position.Y) < halfY
					local reach = other.offset.Position.Z + towardOpening * halfZ
					if spansX and spansY and towardOpening * (reach - face) > 1e-6 then
						table.insert(blocked, other.name)
					end
				end
				if #blocked > 0 then
					TestKit.note(string.format("task99 %s is hidden by %s", piece.name, table.concat(blocked, ", ")))
				end
				expect(#blocked).to.equal(0)
			end
		end)

		it("carry the bead, on the rib, at exactly the point the aimed pose is solved from", function()
			local bead = byName(pieces, "Bead")
			expect(bead).to.be.ok()
			expect(bead.shape).to.equal(Enum.PartType.Ball)
			expect(bead.offset.Position).to.equal(Gun.beadOffset(CONFIG))
			expect(Gun.sight(CONFIG).Position).to.equal(Gun.beadOffset(CONFIG))
			-- The rib is the highest line on the gun, which is what makes a bead sight work: the
			-- bead sits above both tubes.
			local tube = byName(pieces, "BarrelLeft")
			expect(bead.offset.Position.Y > tube.offset.Position.Y + tube.size.Y / 2).to.equal(true)
		end)
	end)

	describe("the action and the hinge", function()
		local pieces = Gun.pieces(CONFIG)

		it("puts the pin EXACTLY on the axis the barrels turn about", function()
			local pin = byName(pieces, "HingePin")
			expect(pin).to.be.ok()
			-- THE ONE CLAIM THAT MAKES THE BREAK-OPEN REAL. If the drawn pin and the axis differ,
			-- the barrels swing AROUND the pin instead of ON it, which is exactly what the old mesh
			-- gun looked like: a torn breech and a gap.
			expect(pin.offset.Position).to.equal(Gun.hinge(CONFIG))
			expect(pin.shape).to.equal(Enum.PartType.Cylinder)
			-- It lies ACROSS the gun, so its round face is what you see from the side.
			expect(pin.size.X > pin.size.Y).to.equal(true)
			local at = Gun.layout(CONFIG)
			TestKit.note(
				string.format(
					"task99 hinge at (%.3f, %.3f, %.3f), breech at z %.3f",
					pin.offset.Position.X,
					pin.offset.Position.Y,
					pin.offset.Position.Z,
					at.breechZ
				)
			)
			-- At the action's lower FRONT -- the knuckle -- which is where a break gun's pin is.
			expect(pin.offset.Position.Z < at.actionZ).to.equal(true)
			expect(pin.offset.Position.Y < at.actionY).to.equal(true)
		end)

		it("is silver against blued barrels, and carries a trigger, a round guard, a lever and a safety", function()
			for _, name in ipairs({
				"Action",
				"ActionBelly",
				"StandingBreech",
				"FenceLeft",
				"FenceRight",
				"TopStrap",
				"FlatBars",
				"TopLever",
				"Safety",
				"Trigger",
				"TriggerGuard",
				"GuardStrap",
			}) do
				expect(byName(pieces, name)).to.be.ok()
			end
			expect(byName(pieces, "Action").color).to.equal(Gun.LOOK.action)
			expect(byName(pieces, "BarrelLeft").color).to.equal(Gun.LOOK.blued)
			expect(byName(pieces, "Action").color).never.to.equal(byName(pieces, "BarrelLeft").color)
			-- A ROUND guard, not a rectangle of three bars.
			expect(byName(pieces, "TriggerGuard").shape).to.equal(Enum.PartType.Cylinder)
			-- The action is SHALLOW AND WIDE, which is what a side-by-side has.
			local action = byName(pieces, "Action")
			expect(action.size.X > action.size.Y).to.equal(true)
			-- ...AND NOTHING ON THE BODY RISES ABOVE THE RIB, which is the one thing that makes a
			-- bead sight work. MEASURED ON SCREEN: the first standing breech stood 0.11 studs proud
			-- of the rib and filled the middle of the aimed view with the barrels hidden behind it.
			--
			-- TASK 100 TIGHTENED IT FROM THE RIB'S TOP TO ITS UNDERSIDE, because what the aimed view
			-- may not contain is anything square between the eye and the RIB, and a piece level with
			-- the rib's top is level with the sighting plane. The two FENCES are the one exemption:
			-- they are round, they wrap the tubes, and they reach only `FENCE_CLEARANCE` past the
			-- tubes' own outline -- a rounded shoulder around each chamber, which is what a
			-- side-by-side has and what the photo shows.
			local rib = byName(pieces, "Rib")
			local ribBottom = rib.offset.Position.Y - rib.size.Y / 2
			local tubeTop = byName(pieces, "BarrelLeft").offset.Position.Y + byName(pieces, "BarrelLeft").size.Y / 2
			for _, piece in ipairs(pieces) do
				if piece.group == "body" and piece.name ~= Gun.STOCK_NAME then
					local top = piece.offset.Position.Y + piece.size.Y / 2
					local limit = if string.find(piece.name, "Fence", 1, true) then tubeTop + 0.015 else ribBottom
					if top > limit then
						TestKit.note(string.format("task100 %s tops out %.3f studs too high", piece.name, top - limit))
					end
					-- The top lever and the safety sit ON the top strap, which is a hair above the
					-- bore line; only the rib, the bead and the fences' round shoulders are higher.
					expect(top <= limit + 1e-6).to.equal(true)
				end
			end
		end)

		it("splits every piece into the half that swings and the half that does not", function()
			local groups = { body = 0, barrels = 0 }
			for _, piece in ipairs(pieces) do
				expect(groups[piece.group]).to.be.ok() -- no third group
				groups[piece.group] += 1
			end
			-- THE FOREND SWINGS AND THE STOCK DOES NOT, which is the whole of a break gun: the
			-- forend is bolted to the barrels (and is what the left hand holds), the stock to the
			-- action.
			expect(byName(pieces, Gun.FOREND_NAME).group).to.equal("barrels")
			expect(byName(pieces, Gun.STOCK_NAME).group).to.equal("body")
			expect(byName(pieces, "HingePin").group).to.equal("body")
			expect(byName(pieces, "Bead").group).to.equal("barrels")
			TestKit.note(string.format("task99 pieces: %d body, %d barrels", groups.body, groups.barrels))
		end)

		it("seats a shell's RIM at each tube's own chamber mouth, OUTSIDE the breech face", function()
			local left = byName(pieces, "BarrelLeft")
			local right = byName(pieces, "BarrelRight")
			local at = Gun.layout(CONFIG)
			for barrel, tube in ipairs({ right, left }) do -- barrel 1 is +X (Shotgun's own rule)
				local chamber = Gun.chamber(barrel, CONFIG)
				local across = Vector2.new(
					chamber.Position.X - tube.offset.Position.X,
					chamber.Position.Y - tube.offset.Position.Y
				)
				-- ON the bore line, exactly: the chamber is built from `Gun.barrelOffset`, the same
				-- one definition the flash uses. It used to take the whole of
				-- `Shotgun.barrelMuzzleOffset`, which is the MESH gun's 0.09, and sat 0.014 studs
				-- off -- passing a bound five times looser than the error.
				expect(across.Magnitude < 1e-6).to.equal(true)
				-- ...AND OUTSIDE THE BREECH FACE, WHICH IS THE WHOLE OF ROUND 2, FINDING 1. This
				-- point is where a seated shell's brass RIM goes, and a rim inside an opaque tube is
				-- a rim nobody can see: rounds 1 and 2 seated the shell 0.10 studs down the chamber,
				-- so a loaded gun and an empty one were the same picture.
				-- 1e-6 AND NOT 1e-9, and the reason is the type: a `CFrame` and a `Vector3` hold
				-- FLOAT32 components, so every number read back out of `offset.Position` has already
				-- lost about seven digits. 1e-9 fails here on arithmetic that is exactly right --
				-- measured, this run. The claims below are about studs, where 1e-6 is a thousandth
				-- of a millimetre at this scale.
				local breechFace = tube.offset.Position.Z + tube.size.X / 2
				expect(math.abs(breechFace - at.breechZ) < 1e-6).to.equal(true)
				expect(chamber.Position.Z > breechFace).to.equal(true)
				expect(math.abs(chamber.Position.Z - (breechFace + Gun.SHELL_RIM_PROUD)) < 1e-6).to.equal(true)
				-- ...and in FRONT of the dark bore disc rather than in its plane, because two discs
				-- ending on one plane z-fight and neither reads as anything.
				local disc = byName(pieces, (if barrel == 1 then "BarrelRight" else "BarrelLeft") .. "BoreBreech")
				expect(disc).to.be.ok()
				local discFace = disc.offset.Position.Z + disc.size.X / 2
				expect(chamber.Position.Z > discFace + 1e-6).to.equal(true)
				-- THE RIM IS WIDER THAN THE DARK IT COVERS, so brass at the mouth is what a loaded
				-- chamber looks like.
				expect(Gun.SHELL_RIM_DIAMETER > disc.size.Y).to.equal(true)
				TestKit.note(
					string.format(
						"task99 barrel %d rim seats %.4f studs out of the breech face (disc %.4f out)",
						barrel,
						chamber.Position.Z - breechFace,
						discFace - breechFace
					)
				)
			end
		end)

		it("backs the shell off its rim by its own length, so the body is in the tube", function()
			-- THE OTHER HALF OF THE SEAT. `Gun.chamber` says where the RIM goes; what the viewmodel
			-- places is the shell model's PIVOT, which is its Body part, so the one number that joins
			-- them is `Gun.shellLayout().back`. If it were wrong in either direction the rim would
			-- float off the breech or the whole shell would be swallowed -- the round 2 defect again.
			-- A `Vector3` HOLDS FLOAT32, so `size.Z` is not the 0.16 written here but the nearest
			-- float to it; every bound below is 1e-6 for that reason, which is a thousandth of a
			-- millimetre at this gun's scale.
			local size = Vector3.new(0.055, 0.055, 0.16)
			local shell = Gun.shellLayout(size, 0.34)
			-- Body, base and rim lie END TO END with no gap and no overlap, mouth forward.
			local mouth = shell.bodyX + shell.bodyLength / 2
			expect(math.abs(mouth - size.Z / 2) < 1e-6).to.equal(true)
			expect(math.abs((shell.bodyX - shell.bodyLength / 2) - (shell.baseX + shell.baseLength / 2)) < 1e-6).to.equal(
				true
			)
			expect(math.abs((shell.baseX - shell.baseLength / 2) - (shell.rimX + shell.rimThick / 2)) < 1e-6).to.equal(
				true
			)
			-- ...and `back` is the pivot-to-rim-face distance those three imply.
			expect(math.abs(shell.back - (shell.bodyX - (shell.rimX - shell.rimThick / 2))) < 1e-6).to.equal(true)
			-- SEATED: the rim's face lands exactly on the mouth, and the body is inside the tube.
			local at = Gun.layout(CONFIG)
			local pivotZ = Gun.chamber(1, CONFIG).Position.Z - shell.back
			expect(math.abs((pivotZ + shell.back) - (at.breechZ + Gun.SHELL_RIM_PROUD)) < 1e-6).to.equal(true)
			expect(pivotZ + shell.bodyLength / 2 < at.breechZ).to.equal(true)
			TestKit.note(string.format("task99 shell pivot %.4f studs forward of the breech face", at.breechZ - pivotZ))
		end)

		-- ---------------------------------------------------------------- task 100: the look pass

		it("is dielectric, because Roblox Metal is what made the barrels sky-blue", function()
			-- MEASURED (rule 5), `.screenshots/20261001T215631Z-compare-carry.png`: the tube pixels
			-- came back with a median of (10, 26, 57) and a 90th percentile of (48, 79, 112) -- blue
			-- about three times red -- against the video target frame's (56, 53, 48) and
			-- (69, 64, 62), which are NEUTRAL. `Enum.Material.Metal` is a conductor: its specular is
			-- the ENVIRONMENT times the albedo, and over a field the environment is the sky, so no
			-- albedo could have fixed it. Every drawn metal piece is a dielectric now, and none of
			-- them carries reflectance -- a mirror finish is the same defect by another route.
			--
			-- THE BEAD IS THE ONE EXEMPTION, and it is deliberate: a 0.034-stud brass ball whose
			-- whole job is to catch the light is exactly what `Metal` is good at, and a dull bead is
			-- a sight a player cannot find (task 92 measured the same thing from the other side when
			-- it took the bead off Neon).
			local metal = 0
			for _, piece in ipairs(pieces) do
				if piece.material ~= Enum.Material.Wood and piece.name ~= "Bead" then
					expect(piece.material).never.to.equal(Enum.Material.Metal)
					expect(piece.reflectance == nil or piece.reflectance == 0).to.equal(true)
					metal += 1
				end
			end
			expect(byName(pieces, "Bead").material).to.equal(Enum.Material.Metal)
			TestKit.note(string.format("task100 %d pieces of steel, none of them Metal", metal))
			-- ...and the blued steel is near-black and NEUTRAL: no channel over 40, and no more than
			-- a 6-point cool cast. The old (34, 38, 46) was a blue-biased albedo under a material
			-- that multiplied the sky by it.
			local blued = Gun.LOOK.blued
			for _, channel in ipairs({ blued.R, blued.G, blued.B }) do
				expect(channel * 255 <= 40).to.equal(true)
			end
			expect((blued.B - blued.R) * 255 <= 6).to.equal(true)
		end)

		it("keeps the Beretta side photo's action proportions, and says the numbers", function()
			local at = Gun.layout(CONFIG)
			local action = byName(pieces, "Action")
			local belly = byName(pieces, "ActionBelly")
			local breech = byName(pieces, "StandingBreech")
			-- THE PHOTO (`Social_1_1-2500 (5).jpeg`, segmented by colour): a 2,348 px gun with the
			-- muzzle at 85, the action's front at 1412 and its joint with the stock at 1572. So the
			-- action is 160 px against 1,327 px of barrel: 0.121 of it. Ours was 0.226 -- 1.9x.
			local lengthRatio = action.size.Z / at.barrelLength
			TestKit.note(string.format("task100 action length is %.3f of the barrels (photo 0.121)", lengthRatio))
			expect(lengthRatio < 0.14).to.equal(true)
			-- THE ACTION BODY IS NARROWER THAN THE BARREL PAIR, so the tubes overhang it and nothing
			-- square shows beside them from the shooter's eye.
			local left, right = byName(pieces, "BarrelLeft"), byName(pieces, "BarrelRight")
			local pairWidth = (right.offset.Position.X - left.offset.Position.X) + left.size.Y
			TestKit.note(string.format("task100 action %.3f wide, barrel pair %.3f", action.size.X, pairWidth))
			expect(action.size.X < pairWidth).to.equal(true)
			expect(breech.size.X < pairWidth).to.equal(true)
			-- THE BARRELS LIE ON THE WATER TABLE: the action's top face is their UNDERSIDE, not the
			-- bore line it used to be, so the body no longer stands up between the two tubes.
			local barrelBottom = left.offset.Position.Y - left.size.Y / 2
			expect(math.abs(at.actionTop - barrelBottom) < 1e-6).to.equal(true)
			-- ...and the belly is round, exactly as tall as the action and no taller: its upper half
			-- is covered by the block and nothing bulges above the water table, which a CIRCULAR
			-- belly of the action's width would have done by 0.067 studs.
			expect(belly.shape).to.equal(Enum.PartType.Cylinder)
			expect(math.abs(belly.offset.Position.Y - belly.size.Y / 2 - at.actionBottom) < 1e-6).to.equal(true)
			expect(belly.offset.Position.Y + belly.size.Y / 2 <= at.actionTop + 1e-6).to.equal(true)
		end)

		it("hangs the hinge hook ON the pin, and did not move the axis doing it", function()
			-- THE AXIS IS THE ONE THING THIS LOOK PASS MAY NOT MOVE (the dispatch says so), and the
			-- action got shallower from the TOP for exactly that reason. This is the value task 99
			-- shipped, written out so a later change to `ACTION_HEIGHT` cannot quietly move it.
			-- 1e-6 AND NOT 1e-9, for the reason task 99's round 3 found the hard way: a Vector3's
			-- components are FLOAT32, so -0.14 + 0.035 comes back as -0.10500000417 and a 1e-9 bound
			-- refuses arithmetic that is exactly right.
			local hinge = Gun.hinge(CONFIG)
			expect(math.abs(hinge.Y - -0.105) < 1e-6).to.equal(true)
			-- ...and the hook now REACHES it. The Reviewer measured a 0.0275-stud air gap between
			-- the hook's underside and the top of the pin it is said to drop onto (TASKS.md 99a(f)).
			local hook = byName(pieces, "HingeHook")
			local hookBottom = hook.offset.Position.Y - hook.size.Y / 2
			TestKit.note(string.format("task100 hook bottom %.4f, hinge axis %.4f", hookBottom, hinge.Y))
			expect(math.abs(hookBottom - hinge.Y) < 1e-6).to.equal(true)
		end)

		it("puts the flat bars UNDER the bore instead of inside the tubes", function()
			-- TASKS.md 99a(f): while the action's top was the bore LINE these sat at y
			-- 0.1025..0.1375, wholly inside two tubes spanning 0.0475..0.1925 -- an invisible part.
			local bars = byName(pieces, "FlatBars")
			local tube = byName(pieces, "BarrelLeft")
			local tubeBottom = tube.offset.Position.Y - tube.size.Y / 2
			local barsTop = bars.offset.Position.Y + bars.size.Y / 2
			TestKit.note(string.format("task100 flat bars top %.4f, tubes start %.4f", barsTop, tubeBottom))
			expect(barsTop <= tubeBottom + 1e-6).to.equal(true)
		end)

		it("gives the forend a round, tapering splinter and a place for a mesh to land", function()
			local body = byName(pieces, Gun.FOREND_NAME)
			local tip = byName(pieces, Gun.FOREND_TIP_NAME)
			expect(body).to.be.ok()
			expect(tip).to.be.ok()
			-- NO BOX EDGES ON THE WOOD a hand wraps: both lengths are Cylinders.
			expect(body.shape).to.equal(Enum.PartType.Cylinder)
			expect(tip.shape).to.equal(Enum.PartType.Cylinder)
			-- ...AND IT TAPERS toward the muzzle, which is what a splinter forend does: the tip is
			-- thinner in both cross-section axes and sits ahead of the body (-Z is the muzzle).
			expect(tip.size.Y < body.size.Y).to.equal(true)
			expect(tip.size.Z < body.size.Z).to.equal(true)
			expect(tip.offset.Position.Z < body.offset.Position.Z).to.equal(true)
			-- THE SAME WALNUT AS KAREN'S STOCK MESH: measured off its own lit pixels in
			-- `.screenshots/20261002T012118Z-pose-reload.png` -- (144, 79, 49) and (153, 96, 66).
			expect(body.color).to.equal(Gun.LOOK.wood)
			expect(tip.color).to.equal(Gun.LOOK.wood)
			expect(byName(pieces, Gun.STOCK_NAME).color).to.equal(Gun.LOOK.wood)
			-- A MESH IS NOT A CYLINDER. The drawn part carries a quarter turn so its own X lies
			-- along the gun; composing `Gun.WOOD_ROTATION_DEG` on top of that would cancel the turn
			-- the MESH needs, so the forend declares where a mesh goes separately -- and it is the
			-- whole splinter, tip included, because a mesh replaces both.
			expect(body.woodOffset).to.be.ok()
			expect((body.woodOffset :: CFrame).Rotation).to.equal(CFrame.identity)
			local wanted = Gun.WOOD_LENGTH_STUDS[Gun.FOREND_NAME]
			expect(math.abs(wanted - (body.size.X + tip.size.X)) < 1e-6).to.equal(true)
		end)

		it("seeds the left hand ON THE FOREND, in the frame the viewmodel actually poses it in", function()
			-- ROUND 1'S FINDING, AND IT IS WHY THIS CASE EXISTS. The seed was computed in the BARREL
			-- GROUP's frame and the viewmodel poses hands in the GUN's: `Camera.Viewmodel.update`
			-- passes `Viewmodel.hinge(gun, state, config)` as `barrelsCFrame`, and that is
			-- `gunCFrame * swing` -- identity with the gun shut -- NOT the `Barrels` part's own
			-- CFrame, which is `handle.CFrame * CFrame.new(0, 0, at.barrelZ)` and is never passed to
			-- anything. The two frames are `at.barrelZ` = -0.831 studs apart, so a number right in
			-- one puts the glove at the breech in the other: two hands at the grip and none on the
			-- wood. Nothing caught it, because no spec read these three numbers at all.
			--
			-- THE BOUND IS THE WOOD'S OWN EXTENT, read off `Gun.pieces` rather than written down, so
			-- moving the splinter moves the bound with it.
			local front, rear = math.huge, -math.huge
			for _, piece in ipairs(pieces) do
				if piece.name == Gun.FOREND_NAME or piece.name == Gun.FOREND_TIP_NAME then
					-- A Cylinder lying along the gun carries its length on its own X.
					front = math.min(front, piece.offset.Position.Z - piece.size.X / 2)
					rear = math.max(rear, piece.offset.Position.Z + piece.size.X / 2)
				end
			end
			expect(front < rear).to.equal(true)
			TestKit.note(string.format("task100 the splinter spans z %.4f to %.4f", front, rear))
			for _, pose in ipairs({ "carry", "aim", "reload" }) do
				local seeded = Poses.DATA.newGun[pose].left.pos
				TestKit.note(string.format("task100 newGun.%s.left.pos.z = %.4f", pose, seeded.z))
				expect(seeded.z >= front).to.equal(true)
				expect(seeded.z <= rear).to.equal(true)
			end
		end)

		it("costs the budget the note states, so growth is a decision", function()
			local count = Gun.partCount(CONFIG)
			TestKit.note(string.format("task99 the drawn gun is %d parts", count))
			-- 22 -> 27 in task 100: the action's round belly, the two fences, the top strap and the
			-- forend's tapered tip.
			expect(count).to.equal(27)
		end)

		it("moves no number a shot depends on", function()
			-- The hitbox, the grip and the muzzle are the world gun's and this task may not touch
			-- them: the new gun is DRAWN under one player's camera and nothing else.
			expect(CONFIG.HANDLE_SIZE).to.equal(Vector3.new(0.4, 0.5, 4.4))
			expect(CONFIG.MUZZLE_OFFSET).to.equal(Vector3.new(0, 0, -2.2))
		end)

		it("puts the Muzzle attachment on the HANDLE'S AXIS, so the rise is counted once", function()
			-- ROUND 1, FINDING 2. `Camera.Viewmodel.muzzle` adds the barrel's own rise to whatever
			-- the attachment says, because on every gun in this repo the attachment sits on the
			-- Handle's axis (`Weapon.Hardware`: `CFrame.new(config.MUZZLE_OFFSET)`). The first build
			-- put this one on the BORE LINE, so the rise was added to a point that already had it and
			-- the first-person flash was drawn 0.12 studs above the barrels -- off the top of the rib
			-- at the bead rather than out of a tube.
			expect(Gun.muzzle(CONFIG).Position).to.equal(CONFIG.MUZZLE_OFFSET)
		end)

		it("gives each tube ONE bore line, and the flash point lands inside that tube", function()
			-- THE ONE DEFINITION (round 1, finding 2). `Gun.barrelOffset` is this gun's answer to the
			-- question `Shotgun.barrelMuzzleOffset` answers for the mesh gun, and the two guns' tubes
			-- are NOT in the same place -- 0.076 apart here against 0.09 there. Whatever draws the
			-- flash must use the gun's own.
			for barrel, tubeName in ipairs({ "BarrelRight", "BarrelLeft" }) do -- barrel 1 is +X
				local tube = byName(pieces, tubeName)
				local offset = Gun.barrelOffset(barrel, CONFIG)
				-- THE SIGN STILL COMES FROM `Shotgun`, so "which tube is barrel 1" has one owner.
				local theirs = Shotgun.barrelMuzzleOffset(barrel, CONFIG)
				expect(offset.X > 0).to.equal(theirs.X > 0)
				-- ...and the magnitude is THIS gun's: exactly its own tube's centre line.
				expect(offset.X).to.equal(tube.offset.Position.X)
				expect(offset.Y).to.equal(tube.offset.Position.Y)
				-- THE DRAWN FLASH POINT, as `Camera.Viewmodel.muzzle` builds it: the attachment plus
				-- this offset. It must be ON the tube's axis, at its muzzle end -- which is false by
				-- 0.12 studs the moment the rise is counted twice.
				local flash = Gun.muzzle(CONFIG) * CFrame.new(offset)
				local across = Vector2.new(
					flash.Position.X - tube.offset.Position.X,
					flash.Position.Y - tube.offset.Position.Y
				).Magnitude
				TestKit.note(string.format("task99 %s flash %.4f studs off the bore line", tubeName, across))
				expect(across < 1e-6).to.equal(true)
				expect(math.abs(flash.Position.Z - Gun.layout(CONFIG).muzzleZ) < 1e-6).to.equal(true)
			end
		end)
	end)

	describe("the wood", function()
		local pieces = Gun.pieces(CONFIG)

		it("scales Karen's stock mesh to the length THIS gun says, and to the WIDTH it says", function()
			local row = Assets.byKey(Gun.WOOD_KEYS[Gun.STOCK_NAME])
			expect(row).to.be.ok()
			expect(row.scope).to.equal("viewmodel")
			expect(row.modelId > 0).to.equal(true)
			-- UNIFORM IN LENGTH AND HEIGHT: the long axis is what the gun asks for and the height is
			-- whatever the wood's own proportions give. A stock squashed into a chosen box measures
			-- perfectly and looks wrong (design 6.1, the squashed boar).
			local wanted = Gun.WOOD_LENGTH_STUDS[Gun.STOCK_NAME]
			expect(math.abs(row.sizeStuds.X - wanted) < 1e-6).to.equal(true)
			local scale = wanted / row.naturalSizeStuds.X
			expect(math.abs(row.sizeStuds.Y - row.naturalSizeStuds.Y * scale) < 1e-6).to.equal(true)
			-- ...AND THE WIDTH IS THE GUN'S OWN ANSWER, which is task 102 and the ONE deliberate
			-- break with "uniform". Uniformly scaled this mesh is 0.123 studs wide -- about right for
			-- a REAL stock (a 486's butt is some 1.6 in across a 45 in gun) and wrong for this one,
			-- because the metal here is drawn at about 1.65x life in cross-section (`BARREL_DIAMETER`
			-- 0.145 against a life-size 0.089 at this length) so that a pair of tubes is readable at
			-- arm's length. The stock arrived at 1.0x, and the aimed capture is what it cost: a comb
			-- spanning ~15% of the half-frame's width against the video target's ~50%.
			local uniformWidth = row.naturalSizeStuds.Z * scale
			expect(math.abs(row.sizeStuds.Z - Gun.WOOD_WIDTH_STUDS[Gun.STOCK_NAME]) < 1e-6).to.equal(true)
			TestKit.note(
				string.format(
					"task102 stock width %.4f studs, where uniform gives %.4f (%.2fx)",
					row.sizeStuds.Z,
					uniformWidth,
					row.sizeStuds.Z / uniformWidth
				)
			)
			-- IT IS THE ACTION'S WIDTH, which is the Director's rule for a side-by-side's stock: as
			-- wide as the action at the head. Read off the drawn action rather than written down, so
			-- the two cannot drift.
			expect(Gun.WOOD_WIDTH_STUDS[Gun.STOCK_NAME]).to.equal(byName(pieces, "Action").size.X)
			expect(row.sizeStuds.Z > uniformWidth).to.equal(true)
			TestKit.note(
				string.format(
					"task99 stock %.3f x %.3f x %.3f studs (natural %.1f x %.1f x %.1f)",
					row.sizeStuds.X,
					row.sizeStuds.Y,
					row.sizeStuds.Z,
					row.naturalSizeStuds.X,
					row.naturalSizeStuds.Y,
					row.naturalSizeStuds.Z
				)
			)
			-- THE TURN IS THE GUN'S, not the row's: the mesh is not mis-oriented, it simply lies
			-- along X and this gun lies along Z.
			expect(row.rotationDeg).to.equal(Vector3.zero)
			expect(row.textureId).to.be.ok()
			expect(Gun.WOOD_ROTATION_DEG[Gun.STOCK_NAME]).to.equal(-90)
		end)

		it("has no forend mesh, and that is stated rather than silent", function()
			-- MEASURED, 2026-10-01, on `A-barrels.glb`: ONE mesh, ONE material, ONE primitive, and --
			-- welded by position, which is the test that survives UV seams -- ONE connected component
			-- spanning the whole model. Meshy fused the forend into the barrels, so there is nothing
			-- in the file that marks it apart and no loose part to lift out. The exact-geometry
			-- forend in `Gun.pieces` is what is drawn, in the same place and at the same size, and
			-- `Camera.Viewmodel` swaps in a mesh the moment a row appears.
			expect(Assets.byKey(Gun.WOOD_KEYS[Gun.FOREND_NAME])).to.equal(nil)
			expect(Gun.WOOD_LENGTH_STUDS[Gun.FOREND_NAME]).to.be.ok()
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

		it("is smaller than it was, against the slimmer gun", function()
			local right = Assets.byKey("hand.right")
			local tube = byName(Gun.pieces(CONFIG), "BarrelLeft")
			TestKit.note(string.format("task99 right hand %.3f studs long", right.sizeStuds.X))
			expect(right.sizeStuds.X < 1.28).to.equal(true) -- task 93's value, measured as too bulky
			-- A hand is still a hand: several times the width of the barrel it holds.
			expect(right.sizeStuds.X > tube.size.Y * 4).to.equal(true)
		end)
	end)
end
