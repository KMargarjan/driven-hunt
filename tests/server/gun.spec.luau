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

		it("show two dark openings at each end, each one inside its own tube", function()
			local bores = 0
			for _, piece in ipairs(pieces) do
				if string.find(piece.name, "Bore", 1, true) then
					bores += 1
					local tube = byName(pieces, string.sub(piece.name, 1, string.find(piece.name, "Bore", 1, true) - 1))
					expect(tube).to.be.ok()
					-- INSIDE THE TUBE, in both senses: narrower than the bore it sits in, and set
					-- back from the end face rather than poking out of it.
					expect(piece.size.Y < tube.size.Y).to.equal(true)
					expect(piece.offset.Position.X).to.equal(tube.offset.Position.X)
					expect(piece.offset.Position.Y).to.equal(tube.offset.Position.Y)
					local alongTube = math.abs(piece.offset.Position.Z - tube.offset.Position.Z)
					expect(alongTube < tube.size.X / 2).to.equal(true)
				end
			end
			-- Two tubes, two ends each: the MUZZLE pair is what you look at down the rib and the
			-- BREECH pair is what you see with the gun broken open, which is the frame this task
			-- exists to fix.
			expect(bores).to.equal(4)
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
				"StandingBreech",
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

		it("puts a chamber on each tube's own bore line, not between them", function()
			local left = byName(pieces, "BarrelLeft")
			local right = byName(pieces, "BarrelRight")
			local at = Gun.layout(CONFIG)
			for barrel, tube in ipairs({ right, left }) do -- barrel 1 is +X (Shotgun's own rule)
				local chamber = Gun.chamber(barrel, CONFIG)
				-- INSIDE THE TUBE: within its radius of the bore line, in both cross axes. This is
				-- what "the shell goes IN" means, against the old answer that put it on the gun's
				-- centre line -- i.e. in the gap between the two barrels.
				local across = Vector2.new(
					chamber.Position.X - tube.offset.Position.X,
					chamber.Position.Y - tube.offset.Position.Y
				)
				expect(across.Magnitude < tube.size.Y / 2).to.equal(true)
				-- ...and at the BREECH end, behind the middle of the barrel.
				expect(chamber.Position.Z > at.barrelZ).to.equal(true)
				expect(chamber.Position.Z < at.breechZ).to.equal(true)
			end
		end)

		it("costs the budget the note states, so growth is a decision", function()
			local count = Gun.partCount(CONFIG)
			TestKit.note(string.format("task99 the drawn gun is %d parts", count))
			expect(count).to.equal(23)
		end)

		it("moves no number a shot depends on", function()
			-- The hitbox, the grip and the muzzle are the world gun's and this task may not touch
			-- them: the new gun is DRAWN under one player's camera and nothing else.
			expect(CONFIG.HANDLE_SIZE).to.equal(Vector3.new(0.4, 0.5, 4.4))
			expect(CONFIG.MUZZLE_OFFSET).to.equal(Vector3.new(0, 0, -2.2))
			expect(Gun.muzzle(CONFIG).Position.Z).to.equal(CONFIG.MUZZLE_OFFSET.Z)
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
