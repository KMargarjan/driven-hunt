-- The range's PICTURE, on the client (design 11.3, step B6). Each man sees ONE animal: his own
-- station's, inside his own station's window, and nothing else.
--
-- IT ASSERTS THE STARTER COPY OF `Range.Mask`, not the running one: `RangeBoot.client.luau` steps
-- the module in `player.PlayerScripts` every Heartbeat, and a counter a second owner is stepping
-- cannot carry T12's "writes did not climb". `range_panel.spec`'s live/starter distinction, used
-- the other way round. The LIVE copy is asserted separately, at the end, for the one thing that
-- makes this file's numbers readable: that it is a DIFFERENT module instance.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterPlayer = game:GetService("StarterPlayer")
	local Workspace = game:GetService("Workspace")
	local Players = game:GetService("Players")

	local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
	local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local Mask = require(scripts:WaitForChild("Range"):WaitForChild("Mask"))
	local Cursor = require(scripts:WaitForChild("Camera"):WaitForChild("Cursor"))

	local LAYOUT = RangeData.LAYOUT
	-- THE ANCHOR THE SPEC MEASURES FROM, and the windows come from the SHIPPED `windowSpanFor` --
	-- the same function `Range.ignoredFor` reads, so this file types no window edge of its own.
	local ANCHOR = Vector3.new(0, 0, 0)

	-- SIX FAKE TRUNKS, one per station, each at its own station's lane centre so the shipped window
	-- arithmetic decides which is in and which is out. A zone part is welded under each, because
	-- the drawn animal is a trunk plus its zones and the mask must write both.
	local function stage(): (Folder, { BasePart }, { BasePart })
		local folder = Instance.new("Folder")
		folder.Name = "RangeMaskSpecTargets"
		local trunks: { BasePart } = {}
		local zones: { BasePart } = {}
		for spot = 1, LAYOUT.SPOT_COUNT do
			local mat = RangeData.matPosition(ANCHOR, spot, LAYOUT)
			local trunk = Instance.new("Part")
			trunk.Name = "Trunk" .. tostring(spot)
			trunk.Anchored = true
			trunk.Position = Vector3.new(mat.X, 0, 0)
			local zone = Instance.new("Part")
			zone.Name = "Zone" .. tostring(spot)
			zone.Anchored = true
			zone.Position = trunk.Position
			zone.Parent = trunk
			trunk.Parent = folder
			table.insert(trunks, trunk)
			table.insert(zones, zone)
		end
		folder.Parent = Workspace
		return folder, trunks, zones
	end

	local function teardown(folder: Folder)
		Mask.stop()
		folder:Destroy()
	end

	describe("the mask hides every animal but his own", function()
		it("shows exactly one and writes 1 on the other five", function()
			local folder, trunks, zones = stage()
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[3])
			local minX, maxX = RangeData.windowSpanFor(ANCHOR, 3, LAYOUT)
			Mask.setWindow(minX, maxX)
			Mask.step(1 / 60)
			local stats = Mask.stats()
			expect(stats.targets).to.equal(LAYOUT.SPOT_COUNT)
			expect(stats.shown).to.equal(1)
			expect(stats.hidden).to.equal(LAYOUT.SPOT_COUNT - 1)
			for spot = 1, LAYOUT.SPOT_COUNT do
				local wanted = if spot == 3 then 0 else 1
				expect(trunks[spot].LocalTransparencyModifier).to.equal(wanted)
				-- THE ZONE PARTS TOO: a hidden trunk with a drawn shoulder is still a second
				-- animal on his screen.
				expect(zones[spot].LocalTransparencyModifier).to.equal(wanted)
			end
			teardown(folder)
		end)

		it("hides his own outside his own window and shows it inside", function()
			local folder, trunks = stage()
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[2])
			local minX, maxX = RangeData.windowSpanFor(ANCHOR, 2, LAYOUT)
			Mask.setWindow(minX, maxX)
			Mask.step(1 / 60)
			expect(trunks[2].LocalTransparencyModifier).to.equal(0)
			-- ONE STUD PAST HIS OWN WINDOW'S EDGE, which is the same edge the shot's ignore list
			-- reads (`RangeData.inWindow`).
			trunks[2].Position = Vector3.new(maxX + 1, 0, 0)
			Mask.step(1 / 60)
			expect(trunks[2].LocalTransparencyModifier).to.equal(1)
			expect(Mask.stats().shown).to.equal(0)
			trunks[2].Position = Vector3.new(maxX - 1, 0, 0)
			Mask.step(1 / 60)
			expect(trunks[2].LocalTransparencyModifier).to.equal(0)
			teardown(folder)
		end)

		it("told no window, shows his own and still hides the other five", function()
			local folder, trunks = stage()
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[5])
			Mask.setWindow(nil, nil)
			Mask.step(1 / 60)
			expect(trunks[5].LocalTransparencyModifier).to.equal(0)
			expect(Mask.stats().hidden).to.equal(LAYOUT.SPOT_COUNT - 1)
			teardown(folder)
		end)

		it("told nobody's animal is his, hides all six", function()
			local folder = stage()
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(nil)
			Mask.step(1 / 60)
			expect(Mask.stats().shown).to.equal(0)
			expect(Mask.stats().hidden).to.equal(LAYOUT.SPOT_COUNT)
			teardown(folder)
		end)

		it("refuses to start with no folder at all", function()
			expect(Mask.start({ root = nil, player = nil })).to.equal(false)
		end)
	end)

	describe("T12: the mask is free when nothing changes", function()
		it("writes nothing across 60 idle steps and reasserts no cursor", function()
			local folder, trunks = stage()
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[1])
			local minX, maxX = RangeData.windowSpanFor(ANCHOR, 1, LAYOUT)
			Mask.setWindow(minX, maxX)
			Mask.step(1 / 60)
			local settled = Mask.stats().writes
			-- EVERY PART WAS WRITTEN ONCE on the settling step and never again: 6 trunks + 6 zones.
			expect(settled).to.equal(2 * LAYOUT.SPOT_COUNT)
			local reassertsBefore = Cursor.stats().reasserts
			for _ = 1, 60 do
				Mask.step(1 / 60)
			end
			expect(Mask.stats().writes).to.equal(settled)
			expect(Mask.stats().sweeps).to.equal(61)
			expect(Cursor.stats().reasserts).to.equal(reassertsBefore)
			teardown(folder)
		end)

		it("masks a part that arrives after start, on the next step", function()
			local folder, trunks = stage()
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[1])
			Mask.step(1 / 60)
			local late = Instance.new("Part")
			late.Name = "LateZone"
			late.Anchored = true
			late.Parent = trunks[4]
			expect(late.LocalTransparencyModifier).to.equal(0)
			Mask.step(1 / 60)
			expect(late.LocalTransparencyModifier).to.equal(1)
			teardown(folder)
		end)
	end)

	describe("the door out, and the owner boundary", function()
		it("stop restores every value it wrote, including a non-zero one", function()
			local folder, trunks, zones = stage()
			-- A TARGET THAT SHIPPED ITS OWN MODIFIER: "shown" means as the range drew it, not 0.
			trunks[1].LocalTransparencyModifier = 0.25
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[1])
			Mask.setWindow(RangeData.windowSpanFor(ANCHOR, 1, LAYOUT))
			Mask.step(1 / 60)
			-- Hidden, then shown again: the restore is the value it found, not a literal.
			trunks[1].Position = Vector3.new(9e4, 0, 0)
			Mask.step(1 / 60)
			expect(trunks[1].LocalTransparencyModifier).to.equal(1)
			Mask.stop()
			expect(trunks[1].LocalTransparencyModifier).to.equal(0.25)
			for spot = 2, LAYOUT.SPOT_COUNT do
				expect(trunks[spot].LocalTransparencyModifier).to.equal(0)
				expect(zones[spot].LocalTransparencyModifier).to.equal(0)
			end
			folder:Destroy()
		end)

		it("never writes a part under the local character", function()
			local folder, trunks = stage()
			-- THE CHARACTER'S OWN PART, put WHERE THE MASK WOULD OTHERWISE WRITE IT. `Camera.Rig` is
			-- the only writer of this property on the local body (design 10), so the mask refuses.
			local character = Instance.new("Model")
			character.Name = "RangeMaskSpecCharacter"
			local limb = Instance.new("Part")
			limb.Name = "Torso"
			limb.Anchored = true
			limb.LocalTransparencyModifier = 0.5
			limb.Parent = character
			character.Parent = folder
			expect(Mask.start({ root = folder, player = { Character = character } })).to.equal(true)
			Mask.setMine(trunks[1])
			Mask.step(1 / 60)
			expect(limb.LocalTransparencyModifier).to.equal(0.5)
			expect(Mask.stats().refused > 0).to.equal(true)
			teardown(folder)
			character:Destroy()
		end)

		it("never touches a part outside its own folder", function()
			local folder, trunks = stage()
			local outside = Instance.new("Part")
			outside.Name = "RangeMaskSpecOutside"
			outside.Anchored = true
			outside.LocalTransparencyModifier = 0.75
			outside.Parent = Workspace
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[1])
			Mask.step(1 / 60)
			expect(outside.LocalTransparencyModifier).to.equal(0.75)
			teardown(folder)
			outside:Destroy()
		end)

		it("forgets a trunk that was cleared, and writes nothing to it", function()
			local folder, trunks = stage()
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[1])
			Mask.step(1 / 60)
			local gone = trunks[6]
			gone.Parent = nil
			Mask.step(1 / 60)
			expect(Mask.stats().targets).to.equal(LAYOUT.SPOT_COUNT - 1)
			-- NOT RESTORED BY `stop` EITHER: it is out of the folder, so it is out of the mask.
			Mask.stop()
			expect(gone.LocalTransparencyModifier).to.equal(1)
			gone:Destroy()
			folder:Destroy()
		end)
	end)

	describe("the skinned-mesh fallback, by parameter (design 4.4)", function()
		it("off by default: Transparency is left alone", function()
			local folder, trunks = stage()
			trunks[2].Transparency = 0
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(trunks[1])
			Mask.step(1 / 60)
			expect(trunks[2].LocalTransparencyModifier).to.equal(1)
			expect(trunks[2].Transparency).to.equal(0)
			teardown(folder)
		end)

		it("on: the same parts get a client-local Transparency, and stop puts it back", function()
			local folder, trunks = stage()
			trunks[2].Transparency = 0.1
			expect(Mask.start({ root = folder, alsoTransparency = true })).to.equal(true)
			Mask.setMine(trunks[1])
			Mask.step(1 / 60)
			expect(trunks[2].Transparency).to.equal(1)
			expect(trunks[1].Transparency).to.equal(0)
			Mask.stop()
			expect(trunks[2].Transparency).to.be.near(0.1, 1e-4)
			folder:Destroy()
		end)
	end)

	describe("the running client", function()
		it("the live copy RangeBoot steps is not the one this spec measured", function()
			-- THE WHOLE REASON THIS FILE MEASURES THE STARTER COPY. `RangeBoot.client.luau` steps
			-- `player.PlayerScripts.Range.Mask` every Heartbeat; if that were the same module
			-- instance, T12's "writes did not climb" could never be read. Two instances, asserted.
			local liveScripts = (Players.LocalPlayer :: any):WaitForChild("PlayerScripts")
			local liveRange = liveScripts:WaitForChild("Range", 10)
			expect(liveRange).to.be.ok()
			local liveMask = require((liveRange :: Instance):WaitForChild("Mask", 10))
			expect(liveMask).to.be.ok()
			expect(liveMask == Mask).to.equal(false)
			expect(type(liveMask.stats().writes)).to.equal("number")
		end)
	end)
end
