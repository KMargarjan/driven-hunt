-- match_outfit.spec: the orange hat and the orange vest (M2.8d, map-generator design section 10),
-- and since Task 82 the invariant Karen's complaint rests on -- that the vest is OUTSIDE the torso.
--
-- SINCE TASK 151 IT IS ALSO THE GREEN (docs/design/beater-kit.md). Karen's design doc gives the
-- hunter a green jacket and green trousers plus an orange hat, and the beater the same green plus an
-- orange hat AND an orange vest -- so the hat is declared ONCE and both roles wear it, a hunter wears
-- 2 parts and a beater 6, and three things that are not parts at all are asserted here for the first
-- time: the base COLOUR on five `BodyColors` properties and never on the head, the removal of the
-- player's own `Shirt`/`Pants`/`ShirtGraphic` and layered clothing, and the five-second window that
-- holds both against a late appearance load.
--
-- WHY THE WINDOW HAS CASES AT ALL: a character's appearance is applied asynchronously, after the
-- model exists, so the avatar's own shirt and body colours can land AFTER ours. Welded parts survive
-- that; a colour does not. The window is the fix, and since review round 1 it has its OWN case,
-- driven through `Body.dressWhenLoaded` against a rig and a STUB PLAYER -- the seam the design named
-- (beater-kit.md section 15 item 9). The leak proof is `isWatching(userId)` false AND
-- `appearanceWatching()` back to **0**, which is section 13's number: the old bound "no more windows
-- than players" was satisfied by zero windows ever opening, which is exactly what the old case did.
--
-- WHAT CHANGED IN TASK 82. `ORANGE_OUTFITS` is ON by default now (Karen's OK, PLAYTEST.md
-- 2026-09-27), so the live case at the bottom is no longer "nobody is dressed": it is "everybody
-- with a team is dressed, and every plate of their vest stands clear of the torso it is welded to".
-- That is the assertion this run can actually fail, and it is the one that would have caught what
-- she reported -- a vest that `dress` built, that a spec asserted the Instances of, and that nobody
-- could see.
--
-- BOTH BRANCHES STILL NEED NO FLAG. `Match.CONFIG.OUTFITS_ENABLED` is read ONCE at the boundary and
-- passed inward as a parameter (CLAUDE.md, "Feature flags"; feature-flags.md 13.3), so every case
-- below hands `dressFor`/`dress` a config table of its own -- the OFF branch included, which is now
-- the branch the flag is NOT sitting at. Nothing here restores anything.
--
-- IT RUNS AGAINST RIGS THIS SPEC BUILDS, at y = 900, and never against the one real player in the
-- Play session: half the client suite is standing in that player, and a spec that changed what he
-- was wearing would be rewriting what those specs report on (the Task 34 lesson, which
-- match_safety.spec records at length).
--
-- THE NUMBERS ARE WRITTEN OUT rather than read back from the module, the convention
-- test_arena.spec set -- with one deliberate exception: `Body.VEST_GAP` and `Body.VEST_THICKNESS`
-- are the invariant's own constants and are read, because what is asserted here is the RELATION
-- (every plate stands that far clear of whatever torso it found), not a stud count that is only
-- right for one avatar. That relation is the fix; a copied 2.2 was the bug.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/beater-kit.md (THE design of what a character wears since Task 151; it
--         supersedes map-generator section 10), docs/design/feature-flags.md (section 13.3)
-- Note:   docs/research/2026-10-11-beater-kit.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Body = Match.Body

local ON = { OUTFITS_ENABLED = true }
local OFF = { OUTFITS_ENABLED = false }

-- The design's own numbers, by hand (section 10.2's table).
local ORANGE = Color3.fromRGB(255, 112, 0)
local HAT_BRIM_WORLD_BOX = Vector3.new(2.2, 0.35, 2.2)

-- The four plates, by name, in the order the table declares them.
local VEST_PLATES = { "VestFront", "VestBack", "VestLeftSide", "VestRightSide" }
-- The hat, the same two rows for both roles since Task 151.
local HAT_PARTS = { "Hat", "HatCrown" }
-- What each role wears, as a flat count: a hunter the hat, a beater the hat and the vest.
local HUNTER_PART_COUNT = #HAT_PARTS
local BEATER_PART_COUNT = #HAT_PARTS + #VEST_PLATES

-- THE GREEN, by hand (the convention test_arena.spec set). The number itself is the median over
-- 533,692 olive cuff pixels of the two glove albedo maps -- docs/research/2026-10-11-beater-kit.md
-- section 3 -- and if `Body.BASE_COLOR` ever stops being it, this case says so instead of agreeing
-- with whatever the module now holds.
local BASE_COLOR = Color3.fromRGB(86, 80, 56)
-- The five BodyColors property stems the base writes. `Head` is NOT one of them: the head keeps the
-- player's own colour, so a dressed player reads as a person in a green outfit, not a green person.
local BASE_LIMBS = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local CLEAR_CLASSES = { "Shirt", "Pants", "ShirtGraphic" }

-- THREE TORSOS, AND THE THIRD IS THE POINT. An R15 UpperTorso, an R6 Torso, and a big one: a player
-- whose avatar is scaled or whose bundle is simply bulkier than the blocky default. Task 77's single
-- 2.2 x 1.6 x 1.3 plate, centred on the limb, is entirely INSIDE that third box -- invisible from
-- every side, exactly as reported.
local TORSOS = {
	{ name = "R15", size = Vector3.new(2, 1.6, 1) },
	{ name = "R6", size = Vector3.new(2, 2, 1) },
	{ name = "scaled", size = Vector3.new(3.2, 2.4, 1.8) },
}

local AXES = { "X", "Y", "Z" }

-- HOW FAR OUTSIDE the limb's own box this (size, offset) lands, measured in the limb's frame: the
-- best of the three axes, because a plate needs to be fully clear on ONE axis to be seen. Negative
-- means it overlaps the limb on every axis, which is what "inside the torso" means.
local function clearanceOf(limbSize: Vector3, size: Vector3, offset: Vector3): number
	local best = -math.huge
	for _, axis in ipairs(AXES) do
		local gap = math.abs((offset :: any)[axis]) - (size :: any)[axis] / 2 - (limbSize :: any)[axis] / 2
		best = math.max(best, gap)
	end
	return best
end

-- The same measurement on two live Instances. The vest plates carry no rotation of their own, so the
-- part's Size axes are the limb's axes and an axis-aligned comparison is exact.
local function clearanceBetween(limb: BasePart, part: BasePart): number
	local relative = limb.CFrame:Inverse() * part.CFrame
	return clearanceOf(limb.Size, part.Size, relative.Position)
end

-- An R15-shaped rig: a root, a head and an upper torso, anchored and far from anybody.
local function rig(name: string, y: number, torsoSize: Vector3?): Model
	local model = Instance.new("Model")
	model.Name = name
	local limbs = {
		{ name = "HumanoidRootPart", size = Vector3.new(2, 2, 1), offset = Vector3.zero },
		{ name = "Head", size = Vector3.new(2, 1, 1), offset = Vector3.new(0, 1.5, 0) },
		{ name = "UpperTorso", size = torsoSize or Vector3.new(2, 1.6, 1), offset = Vector3.new(0, 0.2, 0) },
	}
	for _, limb in ipairs(limbs) do
		local part = Instance.new("Part")
		part.Name = limb.name
		part.Size = limb.size
		part.Position = Vector3.new(0, y, 0) + limb.offset
		part.Anchored = true
		part.Parent = model
	end
	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") :: BasePart
	return model
end

local function outfitParts(character: Model): { BasePart }
	local folder = character:FindFirstChild(Body.OUTFIT_NAME)
	local out = {}
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(out, child)
			end
		end
	end
	return out
end

-- JUST THE VEST ROWS of a beater's outfit. Since Task 151 `dressFor("Drivers")` answers the hat as
-- well, and the hat is a row in STUDS with no `anchor` -- the clearance invariant below is about
-- plates fitted to a torso and asking it of a brim is a category error, not a stricter test.
local function vestRows(): { any }
	local out = {}
	for _, row in ipairs(Body.dressFor("Drivers", ON)) do
		if string.sub(row.name, 1, 4) == "Vest" then
			table.insert(out, row)
		end
	end
	return out
end

-- An `Accessory` with a `WrapLayer` inside: layered clothing as the engine renders it, and what
-- `Body.isLayered` is written against. `kind` is the AccessoryType to declare, or nil to leave it.
local function layeredAccessory(name: string, kind: Enum.AccessoryType?): Accessory
	local accessory = Instance.new("Accessory")
	accessory.Name = name
	if kind then
		accessory.AccessoryType = kind
	end
	-- A `MeshPart` HANDLE, AND IT IS NOT A CHOICE: `Instance.new("WrapLayer")` refuses any other
	-- parent -- *"BaseWrap must be parented to a MeshPart"*, measured in the Edit place on
	-- 2026-10-11 -- which is itself the evidence that a layered garment is a MESH standing off the
	-- limb rather than a texture on it.
	local handle = Instance.new("MeshPart")
	handle.Name = "Handle"
	handle.Parent = accessory
	local wrap = Instance.new("WrapLayer")
	wrap.Parent = handle
	return accessory
end

-- A FAKE CATALOG ACCESSORY, the shape `InsertService:LoadAsset` really answers with: a Model
-- holding one `Accessory` whose `Handle` is a MeshPart carrying the attachment the Humanoid welds
-- by. Built here rather than loaded, so these cases never touch the network and never depend on a
-- stranger's asset still existing.
local function fakeAccessoryTemplate(attachmentName: string): Model
	local model = Instance.new("Model")
	model.Name = "FakeCatalogAccessory"
	local accessory = Instance.new("Accessory")
	accessory.Name = "FakeAccessory"
	local handle = Instance.new("MeshPart")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Parent = accessory
	local attachment = Instance.new("Attachment")
	attachment.Name = attachmentName
	attachment.Parent = handle
	accessory.Parent = model
	return model
end

-- A player's OWN accessory, hanging on a named attachment: hair, a hat, whatever their avatar came
-- with. It carries no `ACCESSORY_TAG`, which is exactly what makes it theirs and not ours.
local function ownAccessory(name: string, attachmentName: string): Accessory
	local accessory = Instance.new("Accessory")
	accessory.Name = name
	local handle = Instance.new("MeshPart")
	handle.Name = "Handle"
	handle.Parent = accessory
	local attachment = Instance.new("Attachment")
	attachment.Name = attachmentName
	attachment.Parent = handle
	return accessory
end

-- Every accessory THIS MODULE put on, by its slot. The attribute is what tells ours from a player's
-- own hat, which `Body.strip` deliberately spares.
local function wornAccessories(character: Model): { [string]: Instance }
	local out = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accoutrement") then
			local slot = child:GetAttribute(Body.ACCESSORY_TAG)
			if slot ~= nil then
				out[tostring(slot)] = child
			end
		end
	end
	return out
end

local function partNamed(character: Model, name: string): BasePart?
	for _, part in ipairs(outfitParts(character)) do
		if part.Name == name then
			return part
		end
	end
	return nil
end

return function()
	describe("the flag row", function()
		it("is ON by default since Karen's OK, and is no longer a 21-day dark path", function()
			local row = Flags.DEFAULTS.ORANGE_OUTFITS
			expect(row).to.be.ok()
			-- FLIPPED (task 82). Step 6 of the lifecycle: she saw the hat and asked for the vest,
			-- the vest is fixed in this task, and the default follows.
			expect(row.default).to.equal(true)
			expect(row.owner).to.equal("ServerScriptService.Match")
			expect(#row.why > 20).to.equal(true)
			-- The 21-day ceiling exists so a DARK path cannot live for ever (feature-flags.md
			-- section 12). A lit one follows TIE_UNTIL_DRIVE_END instead: it stays until the losing
			-- branch is archived, so its expiry is deliberately past that ceiling.
			expect(row.expires > "2026-10-18").to.equal(true)
		end)

		it("is the one thing Match.CONFIG reads, and it reads it once", function()
			-- The permitted shape: the config carries a BOOLEAN, not a function and not the flag
			-- name. If this ever became `Flags.isOn(...)` called from inside Body, the OFF branch
			-- would stop being reachable by parameter and half the cases below would be untestable.
			expect(typeof(Match.CONFIG.OUTFITS_ENABLED)).to.equal("boolean")
			expect(Match.CONFIG.OUTFITS_ENABLED).to.equal(Flags.isOn("ORANGE_OUTFITS"))
		end)
	end)

	describe("dressFor, which is pure", function()
		it("gives a shooter a hat and a driver a vest of four plates", function()
			-- TWO ROWS FOR THE HAT since the first screenshot: a brim and a crown. One disc at the
			-- hair line read as a halo (rule 5); the header of Body's OUTFITS table has the picture.
			local shooter = Body.dressFor("Shooters", ON)
			expect(#shooter).to.equal(2)
			expect(shooter[1].name).to.equal("Hat")
			expect(shooter[2].name).to.equal("HatCrown")
			for _, row in ipairs(shooter) do
				expect(row.limb).to.equal("Head")
				expect(row.color).to.equal(ORANGE)
			end

			-- FOUR PLATES, NOT ONE (task 82): a garment with a front, a back and two sides. One
			-- plate has one face, and Karen looks at a driver from behind as well as in front.
			-- SINCE TASK 151 THE HAT COMES FIRST, because Karen's doc gives the beater both: the
			-- rows are flattened in declaration order, hat then vest.
			local driver = Body.dressFor("Drivers", ON)
			expect(#driver).to.equal(BEATER_PART_COUNT)
			for index, name in ipairs(HAT_PARTS) do
				expect(driver[index].name).to.equal(name)
			end
			for index, name in ipairs(VEST_PLATES) do
				local row = driver[#HAT_PARTS + index]
				expect(row.name).to.equal(name)
				expect(row.limb).to.equal("UpperTorso")
				expect(row.fallbackLimb).to.equal("Torso") -- R6
				expect(row.color).to.equal(ORANGE)
			end
		end)

		it("declares the hat ONCE: the beater's hat rows are the hunter's own tables", function()
			-- TABLE IDENTITY, not a field-by-field comparison, and that is the point of the change:
			-- a second copy of those two rows would be two answers to one question, which is this
			-- project's named failure mode written into a table.
			local hunter = Body.dressFor("Shooters", ON)
			local beater = Body.dressFor("Drivers", ON)
			for index = 1, #HAT_PARTS do
				expect(beater[index]).to.equal(hunter[index])
			end
		end)

		it("gives both roles ONE base, which is the measured sleeve green and never the head", function()
			local hunter = Body.baseFor("Shooters", ON)
			local beater = Body.baseFor("Drivers", ON)
			expect(hunter).to.be.ok()
			-- the SAME table: "everyone wears the same green" is structural, so a team swap has no
			-- colour to re-decide
			expect(beater).to.equal(hunter)
			local base = hunter :: any
			expect(base.color).to.equal(BASE_COLOR)
			expect(base.color).to.equal(Body.BASE_COLOR)
			expect(#base.limbs).to.equal(#BASE_LIMBS)
			for index, stem in ipairs(BASE_LIMBS) do
				expect(base.limbs[index]).to.equal(stem)
			end
			for _, stem in ipairs(base.limbs) do
				expect(stem).never.to.equal("Head")
			end
			expect(#base.clearClasses).to.equal(#CLEAR_CLASSES)
			for index, className in ipairs(CLEAR_CLASSES) do
				expect(base.clearClasses[index]).to.equal(className)
			end
			expect(base.clearLayered).to.equal(true)
		end)

		it("has no base with the flag off, or with no team", function()
			expect(Body.baseFor("Shooters", OFF)).to.equal(nil)
			expect(Body.baseFor("Drivers", OFF)).to.equal(nil)
			expect(Body.baseFor(nil, ON)).to.equal(nil)
			expect(Body.baseFor("Shooters", nil)).to.equal(nil)
		end)

		it("translates Karen's word for a role, in one place and nowhere else", function()
			expect(Body.teamForWord("hunter")).to.equal("Shooters")
			expect(Body.teamForWord("beater")).to.equal("Drivers")
			expect(Body.teamForWord("Beater")).to.equal(nil) -- the parser lower-cases; this does not
			expect(Body.teamForWord("driver")).to.equal(nil)
			expect(Body.teamForWord("")).to.equal(nil)
			expect(Body.teamForWord(nil)).to.equal(nil)
		end)

		it("keeps the design's brim diameter, turned the right way, and stacks the crown on it", function()
			-- A Roblox cylinder's axis is its X, so a part's own Size is not its world box. The
			-- design's table says the brim is 2.2 across and this is the arithmetic that gets there.
			local rows = Body.dressFor("Shooters", ON)
			local brim, crown = rows[1], rows[2]
			expect(brim.shape).to.equal(Enum.PartType.Cylinder)
			expect(brim.rotationDeg).to.equal(Vector3.new(0, 0, 90))
			expect(Vector3.new(brim.size.Y, brim.size.X, brim.size.Z)).to.equal(HAT_BRIM_WORLD_BOX)
			-- the crown is narrower than the brim and sits ON it, not inside it
			expect(crown.size.Y < brim.size.Y).to.equal(true)
			expect(crown.offset.Y > brim.offset.Y).to.equal(true)
			local brimTop = brim.offset.Y + brim.size.X / 2
			local crownBottom = crown.offset.Y - crown.size.X / 2
			expect(math.abs(crownBottom - brimTop) < 0.15).to.equal(true)
		end)

		it("gives nobody anything with the flag off, or with no team", function()
			expect(#Body.dressFor("Shooters", OFF)).to.equal(0)
			expect(#Body.dressFor("Drivers", OFF)).to.equal(0)
			expect(#Body.dressFor(nil, ON)).to.equal(0)
			expect(#Body.dressFor("Shooters", nil)).to.equal(0)
		end)
	end)

	-- THE FIX ITSELF, AS ARITHMETIC (task 82). `Body.fit` is pure, so the property Karen's complaint
	-- rests on can be asserted over torsos no rig in this place has -- which is the point: the old
	-- vest was right for exactly one avatar.
	describe("fit, which sizes a plate against the limb it is hung on", function()
		it("stands every plate clear of the torso's own surface, on all three torsos", function()
			local rows = vestRows()
			expect(#rows).to.equal(#VEST_PLATES)
			for _, torso in ipairs(TORSOS) do
				for _, row in ipairs(rows) do
					local size, offset = Body.fit(row, torso.size)
					local clear = clearanceOf(torso.size, size, offset)
					-- >= the gap the module publishes: not flush (two coplanar faces z-fight, and a
					-- plate ON the surface is inside any layered clothing), and never inside.
					expect(clear >= Body.VEST_GAP - 1e-6).to.equal(true)
					-- and it has real thickness on the axis it stands off, or there is nothing to see
					local axis = if math.abs(row.anchor.X) > 0 then "X" else "Z"
					expect((size :: any)[axis] >= Body.VEST_THICKNESS - 1e-6).to.equal(true)
					-- a vest, not a barrel: it covers most of the torso's height and none of its legs
					expect(math.abs(size.Y - torso.size.Y * Body.VEST_HEIGHT_FRACTION) < 1e-6).to.equal(true)
				end
			end
		end)

		it("wraps all four horizontal faces and closes the corners", function()
			local rows = vestRows()
			local anchors = {}
			for _, row in ipairs(rows) do
				anchors[string.format("%d,%d", row.anchor.X, row.anchor.Z)] = true
			end
			-- one plate per face: -Z (a character's front), +Z, -X, +X
			expect(anchors["0,-1"]).to.equal(true)
			expect(anchors["0,1"]).to.equal(true)
			expect(anchors["-1,0"]).to.equal(true)
			expect(anchors["1,0"]).to.equal(true)

			for _, torso in ipairs(TORSOS) do
				local front, side
				for _, row in ipairs(rows) do
					if row.name == "VestFront" then
						front = row
					elseif row.name == "VestLeftSide" then
						side = row
					end
				end
				local frontSize, frontOffset = Body.fit(front, torso.size)
				local sideSize, sideOffset = Body.fit(side, torso.size)
				-- THE CORNER: the side plate must reach past the front plate's outer face, or a
				-- driver seen from 45 degrees has an orange-free corner to be missed through.
				local frontOuter = math.abs(frontOffset.Z) + frontSize.Z / 2
				expect(sideSize.Z / 2 >= frontOuter - 1e-6).to.equal(true)
				-- ...and the front plate covers nearly the whole width of the torso it is on
				expect(frontSize.X >= torso.size.X * 0.9).to.equal(true)
				expect(sideOffset.X < 0).to.equal(true) -- the left plate is on the left
			end
		end)

		it("leaves a row written in studs exactly as written", function()
			-- The hat has no `scale`, so fit is the identity on it: one function, two roles, no
			-- second code path to keep in step.
			local hat = Body.dressFor("Shooters", ON)[1]
			local size, offset = Body.fit(hat, Vector3.new(2, 1, 1))
			expect(size).to.equal(hat.size)
			expect(offset).to.equal(hat.offset)
			-- and a different head does not change it, which is exactly why the vest needed the
			-- other path: a stud count cannot answer for an avatar it has never seen
			local other, otherOffset = Body.fit(hat, Vector3.new(3, 2, 2))
			expect(other).to.equal(hat.size)
			expect(otherOffset).to.equal(hat.offset)
		end)
	end)

	describe("dress, which writes the character", function()
		local made: { Model } = {}

		local function newRig(name: string, torsoSize: Vector3?): Model
			local model = rig(name, 900, torsoSize)
			model.Parent = workspace
			table.insert(made, model)
			return model
		end

		afterAll(function()
			for _, model in ipairs(made) do
				model:Destroy()
			end
		end)

		it("puts one orange hat on a shooter, welded, and invisible to every ray", function()
			local character = newRig("Task77Shooter")
			expect(Body.dress(character, "Shooters", ON)).to.equal(true)
			local parts = outfitParts(character)
			expect(#parts).to.equal(2)
			local hat = parts[1]
			if hat.Name ~= "Hat" then
				hat = parts[2]
			end
			expect(hat.Name).to.equal("Hat")
			expect(hat.Color).to.equal(ORANGE)
			-- THE ONE THAT MATTERS: a hat that stops a pellet changes what the shot hit, and what
			-- the shot hit is what Match.Penalty.judge reads.
			-- asserted on EVERY part of the outfit, not just the one this case names: a crown that
			-- ate a slug would be exactly as wrong as a brim that did.
			for _, part in ipairs(parts) do
				expect(part.CanQuery).to.equal(false)
				expect(part.CanCollide).to.equal(false)
				expect(part.CanTouch).to.equal(false)
				expect(part.Massless).to.equal(true)
				expect(part.Anchored).to.equal(false)
				expect(part.Color).to.equal(ORANGE)
			end
			expect(hat.CastShadow).to.equal(false)
			-- welded to the limb it is named against, not to the root
			local weld = hat:FindFirstChildOfClass("WeldConstraint")
			expect(weld).to.be.ok()
			expect((weld :: WeldConstraint).Part0).to.equal(character:FindFirstChild("Head"))
			expect((weld :: WeldConstraint).Part1).to.equal(hat)
			-- above the head's CENTRE, which is what a Position is, and high enough to clear a
			-- default avatar's hair -- which the design's 0.8 did not (rule 5, the first screenshot)
			local head = character:FindFirstChild("Head") :: BasePart
			expect(math.abs((hat.Position - head.Position).Y - 0.95) < 1e-3).to.equal(true)
		end)

		it("wraps a driver's torso in four plates, every one of them outside it", function()
			-- ON EVERY TORSO, and the `scaled` one is the regression: Task 77's single centred
			-- 2.2 x 1.6 x 1.3 plate is entirely inside a torso that size, which is a vest nobody can
			-- see from any side (PLAYTEST.md, 2026-09-27).
			for _, torso in ipairs(TORSOS) do
				local character = newRig("Task82Driver" .. torso.name, torso.size)
				expect(Body.dress(character, "Drivers", ON)).to.equal(true)
				local parts = outfitParts(character)
				-- SIX SINCE TASK 151: the four plates plus the hat Karen's doc gives the beater too.
				expect(#parts).to.equal(BEATER_PART_COUNT)
				local limb = character:FindFirstChild("UpperTorso") :: BasePart
				local clearances = {}
				for _, name in ipairs(VEST_PLATES) do
					local part = partNamed(character, name)
					expect(part).to.be.ok()
					local clear = clearanceBetween(limb, part :: BasePart)
					table.insert(clearances, string.format("%s=%.3f", name, clear))
					-- THE ASSERTION KAREN'S COMPLAINT RESTS ON: not inside the torso, on any avatar.
					expect(clear >= Body.VEST_GAP - 1e-3).to.equal(true)
					expect((part :: BasePart).CanQuery).to.equal(false)
					expect((part :: BasePart).Color).to.equal(ORANGE)
					local weld = (part :: BasePart):FindFirstChildOfClass("WeldConstraint")
					expect(weld).to.be.ok()
					expect((weld :: WeldConstraint).Part0).to.equal(limb)
				end
				TestKit.note(
					string.format(
						"task82 vest on a %s torso %s: clearance %s (gap %.2f)",
						torso.name,
						tostring(torso.size),
						table.concat(clearances, " "),
						Body.VEST_GAP
					)
				)
			end
		end)

		it("follows the torso when it moves, because it is welded to it", function()
			-- A vest that does not follow a running driver is not a vest. The weld is what does it,
			-- and this is the weld doing it rather than a WeldConstraint merely existing.
			local character = newRig("Task82Follow")
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			local limb = character:FindFirstChild("UpperTorso") :: BasePart
			local front = partNamed(character, "VestFront") :: BasePart
			local before = limb.CFrame:Inverse() * front.CFrame
			limb.CFrame = limb.CFrame * CFrame.new(0, 0, -18) * CFrame.Angles(0, math.rad(35), 0)
			task.wait(0.2) -- one physics step is enough; a fifth of a second is not a race
			local after = limb.CFrame:Inverse() * front.CFrame
			expect((after.Position - before.Position).Magnitude < 0.05).to.equal(true)
			expect(clearanceBetween(limb, front) >= Body.VEST_GAP - 1e-3).to.equal(true)
		end)

		it("swaps the item when the team swaps, and never wears two", function()
			local character = newRig("Task77Swap")
			expect(Body.dress(character, "Shooters", ON)).to.equal(true)
			expect(#outfitParts(character)).to.equal(HUNTER_PART_COUNT) -- brim and crown
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			local parts = outfitParts(character)
			-- THE HAT STAYS SINCE TASK 151, and the vest is added to it: a beater wears both.
			expect(#parts).to.equal(BEATER_PART_COUNT)
			expect(partNamed(character, "Hat")).to.be.ok()
			-- and dressing twice for the SAME team is still one vest: the folder is destroyed and
			-- rebuilt, which is what makes every call site above safe to call again.
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			expect(#outfitParts(character)).to.equal(BEATER_PART_COUNT)
			-- back to a hunter: the four plates go and the green stays, because the base is the
			-- SAME table for both roles and there is nothing to re-decide.
			expect(Body.dress(character, "Shooters", ON)).to.equal(true)
			expect(#outfitParts(character)).to.equal(HUNTER_PART_COUNT)
			expect(partNamed(character, "VestFront")).to.equal(nil)
			local colors = character:FindFirstChildOfClass("BodyColors") :: BodyColors
			expect(colors).to.be.ok()
			expect(colors.TorsoColor3).to.equal(BASE_COLOR)
			-- one folder, not two
			local folders = 0
			for _, child in ipairs(character:GetChildren()) do
				if child.Name == Body.OUTFIT_NAME then
					folders += 1
				end
			end
			expect(folders).to.equal(1)
		end)

		it("adds nothing with the flag off, and takes off what is already there", function()
			local character = newRig("Task77Off")
			expect(Body.dress(character, "Shooters", ON)).to.equal(true)
			expect(#outfitParts(character)).to.equal(HUNTER_PART_COUNT)
			-- Switching off and respawning must undress: the folder is cleared before the rows are
			-- asked for, so "off" is not "whatever you were wearing stays". Since task 82 this is
			-- the branch the flag is NOT at, which is the half a parameter keeps reachable.
			expect(Body.dress(character, "Shooters", OFF)).to.equal(true)
			expect(#outfitParts(character)).to.equal(0)
			expect(character:FindFirstChild(Body.OUTFIT_NAME)).to.equal(nil)
		end)

		it("counts a miss rather than believing a change it did not make", function()
			expect(Body.dress(nil, "Shooters", ON)).to.equal(false)
			local unparented = rig("Task77Unparented", 900)
			expect(Body.dress(unparented, "Shooters", ON)).to.equal(false)
			unparented:Destroy()
			-- a character with no head: the design's "returns false when a limb is missing"
			local headless = newRig("Task77Headless")
			local head = headless:FindFirstChild("Head") :: Instance
			head:Destroy()
			expect(Body.dress(headless, "Shooters", ON)).to.equal(false)
			expect(headless:FindFirstChild(Body.OUTFIT_NAME)).to.equal(nil)
			-- ...and a driver on an R6 rig finds Torso instead of UpperTorso, and the vest is fitted
			-- to THAT limb: the fallback is not a weaker vest.
			local r6 = newRig("Task77R6", Vector3.new(2, 2, 1))
			local torso = r6:FindFirstChild("UpperTorso") :: BasePart
			torso.Name = "Torso"
			expect(Body.dress(r6, "Drivers", ON)).to.equal(true)
			expect(#outfitParts(r6)).to.equal(BEATER_PART_COUNT)
			for _, part in ipairs(outfitParts(r6)) do
				if string.sub(part.Name, 1, 4) == "Vest" then
					expect(clearanceBetween(torso, part) >= Body.VEST_GAP - 1e-3).to.equal(true)
				end
			end
			-- ...and the GREEN is not a miss on an R6 rig: `BodyColors` has one property per R6 limb
			-- and the engine maps them onto an R15 rig's parts, so there is no limb to look for.
			local r6Colors = r6:FindFirstChildOfClass("BodyColors") :: BodyColors
			expect(r6Colors).to.be.ok()
			expect(r6Colors.LeftLegColor3).to.equal(BASE_COLOR)
		end)

		it("writes the green on five properties and never on the head", function()
			local character = newRig("Task151Paint")
			local head = Color3.fromRGB(205, 148, 112) -- whatever the avatar's own head was
			local before = Instance.new("BodyColors")
			before.HeadColor3 = head
			before.Parent = character
			expect(Body.paint(character, Body.BASE)).to.equal(true)
			local colors = character:FindFirstChildOfClass("BodyColors") :: BodyColors
			expect(colors).to.equal(before) -- found, not replaced
			for _, stem in ipairs(BASE_LIMBS) do
				expect((colors :: any)[stem .. "Color3"]).to.equal(BASE_COLOR)
			end
			-- THE HEAD IS UNTOUCHED, which is what makes a dressed player a person in a green
			-- outfit rather than a green person.
			expect(colors.HeadColor3).to.equal(head)
			-- painting twice leaves ONE instance: an existing one is written to, never appended to
			expect(Body.paint(character, Body.BASE)).to.equal(true)
			local count = 0
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("BodyColors") then
					count += 1
				end
			end
			expect(count).to.equal(1)
		end)

		it("creates the BodyColors itself when the character has none, and none at all with no base", function()
			local character = newRig("Task151PaintFresh")
			expect(character:FindFirstChildOfClass("BodyColors")).to.equal(nil)
			expect(Body.paint(character, Body.BASE)).to.equal(true)
			expect(character:FindFirstChildOfClass("BodyColors")).to.be.ok()

			local bare = newRig("Task151PaintNoBase")
			expect(Body.paint(bare, nil)).to.equal(false)
			expect(bare:FindFirstChildOfClass("BodyColors")).to.equal(nil)
			expect(Body.paint(nil, Body.BASE)).to.equal(false)
		end)

		it("takes off what would hide the green, and leaves the head's own things alone", function()
			local character = newRig("Task151Strip")
			local shirt = Instance.new("Shirt")
			shirt.Parent = character
			local pants = Instance.new("Pants")
			pants.Parent = character
			local graphic = Instance.new("ShirtGraphic")
			graphic.Parent = character
			local jacket = layeredAccessory("LayeredJacket", nil)
			jacket.Parent = character
			-- SPARED: a hat and hair, even though the hat below carries a wrap too. The spare check
			-- runs first, and nothing in Karen's doc asks for them to go.
			local hat = layeredAccessory("OwnHat", Enum.AccessoryType.Hat)
			hat.Parent = character
			local hair = layeredAccessory("OwnHair", Enum.AccessoryType.Hair)
			hair.Parent = character

			expect(Body.strip(character, Body.BASE)).to.equal(4)
			expect(shirt.Parent).to.equal(nil)
			expect(pants.Parent).to.equal(nil)
			expect(graphic.Parent).to.equal(nil)
			expect(jacket.Parent).to.equal(nil)
			expect(hat.Parent).to.equal(character)
			expect(hair.Parent).to.equal(character)
			-- a second pass finds nothing new
			expect(Body.strip(character, Body.BASE)).to.equal(0)
			-- and with no base NOBODY'S own clothes are touched, which is the flag-off branch
			local untouched = newRig("Task151StripOff")
			local keep = Instance.new("Shirt")
			keep.Parent = untouched
			expect(Body.strip(untouched, nil)).to.equal(0)
			expect(keep.Parent).to.equal(untouched)
		end)

		it("knows layered clothing by its wrap and not by the catalog's taxonomy", function()
			-- WHY THE WRAP: a layered accessory is a MESH STANDING OFF the limb, which is why no
			-- colour written to the limb can show through it. `AccessoryType` came back `Unknown` on
			-- every real catalog accessory probed for this task, and is `Unknown` on anything a spec
			-- builds, so it is used only for the SPARE list.
			local jacket = layeredAccessory("Jacket", nil)
			expect(Body.isLayered(jacket)).to.equal(true)
			jacket.AccessoryType = Enum.AccessoryType.Hat
			expect(Body.isLayered(jacket)).to.equal(false) -- spared wins over the wrap
			jacket:Destroy()

			local rigid = Instance.new("Accessory") -- an accessory with no wrap at all
			local handle = Instance.new("MeshPart")
			handle.Name = "Handle"
			handle.Parent = rigid
			expect(Body.isLayered(rigid)).to.equal(false)
			rigid:Destroy()

			local part = Instance.new("Part")
			expect(Body.isLayered(part)).to.equal(false)
			part:Destroy()
			local shirt = Instance.new("Shirt") -- a Shirt is cleared by CLASS, not by this predicate
			expect(Body.isLayered(shirt)).to.equal(false)
			shirt:Destroy()
		end)

		it("dresses and paints in one call, and the base is part of dress now", function()
			local character = newRig("Task151Dress")
			local shirt = Instance.new("Shirt")
			shirt.Parent = character
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			expect(#outfitParts(character)).to.equal(BEATER_PART_COUNT)
			expect(shirt.Parent).to.equal(nil)
			local colors = character:FindFirstChildOfClass("BodyColors") :: BodyColors
			expect(colors).to.be.ok()
			expect(colors.TorsoColor3).to.equal(BASE_COLOR)
			expect(colors.RightArmColor3).to.equal(BASE_COLOR)
			-- with the flag OFF nothing is painted and nothing is taken off
			local off = newRig("Task151DressOff")
			local keep = Instance.new("Pants")
			keep.Parent = off
			expect(Body.dress(off, "Drivers", OFF)).to.equal(true)
			expect(off:FindFirstChildOfClass("BodyColors")).to.equal(nil)
			expect(keep.Parent).to.equal(off)
		end)

		it("holds the green and the outfit against a late appearance load, then closes its window", function()
			-- THE WINDOW'S OWN CASE, AND ROUND 1 DID NOT HAVE ONE. The Reviewer was right: the case
			-- that stood here called `Body.strip` and `Body.paint` by hand, opened no window, and
			-- would have passed unchanged with `dressWhenLoaded` reduced to `Body.dress` -- so the
			-- `ChildAdded` handler, `strayCleared`'s only increment path, `stopWatching` and the
			-- full re-dress at the close had no coverage at all. This drives the real function.
			--
			-- A STUB PLAYER IS THE SEAM THE DESIGN NAMED (beater-kit.md section 15 item 9), and the
			-- old comment claiming `dressWhenLoaded` "needs a real Player" was simply wrong:
			-- `player: Player` is a type annotation, and the only things read off it are `UserId`,
			-- `Character` and `Team.Name`. A table with those three satisfies every one -- which is
			-- also what keeps this case away from the live player, whom half the client suite is
			-- standing in (the Task 34 lesson).
			local userId = -1511
			local saved = Body.accessorySource()
			local character = newRig("Task151Window")
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character
			local stub = { UserId = userId, Character = character, Team = { Name = "Drivers" } }

			Body.setAccessorySource(function(slot)
				return fakeAccessoryTemplate(if slot == "hat" then "HatAttachment" else "BodyFrontAttachment")
			end)
			local ok, err = pcall(function()
				local strayBefore = Body.strayCleared()
				Body.dressWhenLoaded(stub :: any, character, ON)
				expect(Body.isWatching(userId)).to.equal(true)
				expect(wornAccessories(character)["hat"]).to.be.ok()

				-- (1) A SHIRT THAT LANDS INSIDE THE WINDOW IS TAKEN OFF, and counted. `ChildAdded`
				-- is deferred, so this waits for the engine rather than for a number of frames.
				local shirt = Instance.new("Shirt")
				shirt.Parent = character
				task.wait(0.3)
				expect(shirt.Parent).to.equal(nil)
				expect(Body.strayCleared()).to.equal(strayBefore + 1)

				-- (2) THE PLAYER'S OWN HAT IS KEPT. It carries no wrap, so it is not what hides a
				-- limb's colour, and nothing in Karen's doc asks for it to go.
				local ownHat = ownAccessory("OwnHatLate", "SomeOtherAttachment")
				ownHat.Parent = character
				task.wait(0.3)
				expect(ownHat.Parent).to.equal(character)

				-- (3) A `BodyColors` THE ENGINE ADDS LATER IS PAINTED, not fought with.
				local engineColors = Instance.new("BodyColors")
				engineColors.TorsoColor3 = Color3.fromRGB(255, 0, 0)
				engineColors.Parent = character
				task.wait(0.3)
				expect(engineColors.TorsoColor3).to.equal(BASE_COLOR)

				-- (4) THE CLOSE PUTS BACK WHAT THE APPEARANCE LOAD TOOK OFF. This is the case
				-- claim 8(b) is about: in the Forest Test a spawned player came out green and
				-- BARE-HEADED, because the load applies the avatar's whole look and takes a
				-- freshly welded accessory with it. Destroying ours here is that, exactly.
				local hat = wornAccessories(character)["hat"]
				expect(hat).to.be.ok();
				(hat :: Instance):Destroy()
				expect(wornAccessories(character)["hat"]).to.equal(nil)

				-- ...and the window closes on its own clock, which is the module's own number and
				-- not a 5 copied into this file.
				task.wait(Body.APPEARANCE_WATCH_SECONDS + 1)
				expect(Body.isWatching(userId)).to.equal(false)
				expect(wornAccessories(character)["hat"]).to.be.ok()

				-- (5) AFTER THE CLOSE, A NEW SHIRT SURVIVES. The window is bounded: it is not a
				-- permanent guard on the character, and a spec that did not check this could not
				-- tell a closed window from a leaked one.
				local strayAfterClose = Body.strayCleared()
				local late = Instance.new("Shirt")
				late.Parent = character
				task.wait(0.3)
				expect(late.Parent).to.equal(character)
				expect(Body.strayCleared()).to.equal(strayAfterClose)

				-- (6) AND NOTHING IS LEAKED. The design's section 13 says 0, and 0 is what this
				-- asserts; `isWatching` above is the per-user half, which cannot be satisfied by
				-- somebody else's window.
				TestKit.note(
					string.format(
						"task151 window: strayCleared %d -> %d, repaints now %d, watching %d",
						strayBefore,
						Body.strayCleared(),
						Body.repaints(),
						Body.appearanceWatching()
					)
				)
				expect(Body.appearanceWatching()).to.equal(0)
			end)
			Body.setAccessorySource(saved)
			Body.forget(userId)
			if not ok then
				error(err, 0)
			end
		end)

		it("setTeam dresses through the window, swaps without leaving two, and forget closes it", function()
			-- `Body.setTeam` IS CALLED BY NO OTHER SPEC (the Reviewer's finding), and it is the call
			-- site the Forest Test's `/beater` uses -- so the one path Karen drives by hand had no
			-- test behind it.
			local userId = -1512
			local saved = Body.accessorySource()
			Body.ensureTeams() -- idempotent; `setTeam` writes the team BY NAME and needs it to exist
			local character = newRig("Task151SetTeam")
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character
			local stub = { UserId = userId, Character = character, Team = nil :: any, Neutral = true }

			Body.setAccessorySource(function(slot)
				return fakeAccessoryTemplate(if slot == "hat" then "HatAttachment" else "BodyFrontAttachment")
			end)
			local ok, err = pcall(function()
				Body.setTeam(stub :: any, "Drivers", ON)
				expect(Body.teamOf(stub :: any)).to.equal("Drivers")
				expect(stub.Neutral).to.equal(false)
				expect(Body.isWatching(userId)).to.equal(true)
				local worn = wornAccessories(character)
				expect(worn["hat"]).to.be.ok()
				expect(worn["vest"]).to.be.ok()

				-- A TEAM SWAP REPLACES THE WINDOW, it does not add one: the row is keyed by userId,
				-- which is the whole reason a player can never hold two.
				local open = Body.appearanceWatching()
				Body.setTeam(stub :: any, "Shooters", ON)
				expect(Body.teamOf(stub :: any)).to.equal("Shooters")
				expect(Body.appearanceWatching()).to.equal(open)
				expect(Body.isWatching(userId)).to.equal(true)
				-- ...and the vest is gone with the team, while the hat stays
				local after = wornAccessories(character)
				expect(after["hat"]).to.be.ok()
				expect(after["vest"]).to.equal(nil)

				-- `Body.forget` CLOSES IT. Without this line a player who leaves inside the five
				-- seconds leaves a connection held against a character that is gone -- and in the
				-- Forest Test `Match.forget` never runs at all, so that boot calls this itself.
				Body.forget(userId)
				expect(Body.isWatching(userId)).to.equal(false)
			end)
			Body.setAccessorySource(saved)
			Body.forget(userId)
			if not ok then
				error(err, 0)
			end
		end)

		it("wears the REAL accessory when one is loaded, and builds no plates for that slot", function()
			-- THE SOURCE IS A MODULE-LEVEL SEAM THE LIVE SERVER HAS ALREADY WIRED, so it is put back
			-- before this case can return by any route. A spec that left a fake source in place
			-- would dress the next respawning player in a 1x1 cube.
			local saved = Body.accessorySource()
			local asked = {}
			Body.setAccessorySource(function(slot)
				table.insert(asked, slot)
				return fakeAccessoryTemplate(if slot == "hat" then "HatAttachment" else "BodyFrontAttachment")
			end)
			local ok, err = pcall(function()
				-- A HUMANOID IS WHAT `AddAccessory` NEEDS, so this rig has one. Every other rig in
				-- this file has none, which is exactly why the plates can never be deleted.
				local character = newRig("Task151Accessory")
				local humanoid = Instance.new("Humanoid")
				humanoid.Parent = character

				expect(Body.dress(character, "Drivers", ON)).to.equal(true)
				local worn = wornAccessories(character)
				expect(worn["hat"]).to.be.ok()
				expect(worn["vest"]).to.be.ok()
				-- ...and NOT the plates as well: one worn thing per slot, never two.
				expect(#outfitParts(character)).to.equal(0)
				expect(character:FindFirstChild(Body.OUTFIT_NAME)).to.equal(nil)
				expect(#asked).to.equal(2)

				-- A pellet must not stop on a vest: the same rule the plates carry.
				for _, accessory in pairs(worn) do
					for _, d in ipairs((accessory :: Instance):GetDescendants()) do
						if d:IsA("BasePart") then
							expect(d.CanQuery).to.equal(false)
							expect(d.CanTouch).to.equal(false)
							expect(d.CanCollide).to.equal(false)
							expect(d.Massless).to.equal(true)
						end
					end
				end

				-- DRESSING TWICE IS STILL ONE HAT. The accessories live on the CHARACTER, not in the
				-- folder, so destroying the folder does not reach them -- this is the line that
				-- stops a re-dress leaving a player in two.
				expect(Body.dress(character, "Drivers", ON)).to.equal(true)
				local count = 0
				for _, child in ipairs(character:GetChildren()) do
					if child:IsA("Accoutrement") and child:GetAttribute(Body.ACCESSORY_TAG) ~= nil then
						count += 1
					end
				end
				expect(count).to.equal(2)

				-- A team swap takes the vest off and leaves the hat: still one worn thing per slot.
				expect(Body.dress(character, "Shooters", ON)).to.equal(true)
				local after = wornAccessories(character)
				expect(after["hat"]).to.be.ok()
				expect(after["vest"]).to.equal(nil)
			end)
			Body.setAccessorySource(saved)
			if not ok then
				error(err, 0)
			end
		end)

		it("falls back to the plates when the slot has no accessory, or the rig cannot wear one", function()
			local saved = Body.accessorySource()
			local ok, err = pcall(function()
				-- ONE slot answers, the other does not: the answering slot wears its accessory and
				-- the silent one builds its plates. Both halves, one character.
				Body.setAccessorySource(function(slot)
					if slot == "vest" then
						return fakeAccessoryTemplate("BodyFrontAttachment")
					end
					return nil
				end)
				local mixed = newRig("Task151Mixed")
				local humanoid = Instance.new("Humanoid")
				humanoid.Parent = mixed
				expect(Body.dress(mixed, "Drivers", ON)).to.equal(true)
				expect(wornAccessories(mixed)["vest"]).to.be.ok()
				expect(wornAccessories(mixed)["hat"]).to.equal(nil)
				local parts = outfitParts(mixed)
				expect(#parts).to.equal(#HAT_PARTS) -- the hat's plates, and nothing of the vest's
				expect(partNamed(mixed, "Hat")).to.be.ok()
				expect(partNamed(mixed, "VestFront")).to.equal(nil)

				-- NO HUMANOID, so nothing can be worn at all and every slot falls back. This is the
				-- case every other rig in this file is in, and it is why the plates stay.
				Body.setAccessorySource(function(slot)
					return fakeAccessoryTemplate(if slot == "hat" then "HatAttachment" else "BodyFrontAttachment")
				end)
				local bare = newRig("Task151NoHumanoid")
				expect(Body.dress(bare, "Drivers", ON)).to.equal(true)
				expect(next(wornAccessories(bare))).to.equal(nil)
				expect(#outfitParts(bare)).to.equal(BEATER_PART_COUNT)

				-- A SOURCE THAT THROWS is a failed load, not a crash: the plates are built.
				Body.setAccessorySource(function(_slot): Instance?
					error("the catalog is on fire")
				end)
				local angry = newRig("Task151AngrySource")
				local hum2 = Instance.new("Humanoid")
				hum2.Parent = angry
				expect(Body.dress(angry, "Shooters", ON)).to.equal(true)
				expect(#outfitParts(angry)).to.equal(HUNTER_PART_COUNT)
			end)
			Body.setAccessorySource(saved)
			if not ok then
				error(err, 0)
			end
		end)

		it("clears the hair a real cap would hide under, and ONLY when the cap actually goes on", function()
			-- MEASURED, AND IT IS WHY THIS EXISTS (task 151 round 2). The preview showed a hunter in
			-- a BLACK cap with an orange peak. He was not: our cap was on correctly -- 2.01 x 0.93 x
			-- 1.43 studs on `HatAttachment` -- and the black was the avatar's OWN hair, 2.08 x 2.05
			-- x 1.94 on `HairAttachment`, a bowl twice the cap's height in the same place. The
			-- grey-box hat never had the problem because Task 77 RAISED its crown; a catalog
			-- accessory hangs where its own attachment puts it and cannot be raised.
			local saved = Body.accessorySource()
			local ok, err = pcall(function()
				Body.setAccessorySource(function(slot)
					return fakeAccessoryTemplate(if slot == "hat" then "HatAttachment" else "BodyFrontAttachment")
				end)
				local character = newRig("Task151Clears")
				local humanoid = Instance.new("Humanoid")
				humanoid.Parent = character
				local hair = ownAccessory("OwnHair", "HairAttachment")
				hair.Parent = character
				local ownHat = ownAccessory("OwnHat", "HatAttachment")
				ownHat.Parent = character
				-- NOT on an attachment the hat clears, so it must survive: this is the line that
				-- says the rule is narrow and not "take everything off".
				local back = ownAccessory("OwnBackpack", "BodyBackAttachment")
				back.Parent = character

				expect(Body.dress(character, "Shooters", ON)).to.equal(true)
				expect(wornAccessories(character)["hat"]).to.be.ok()
				expect(hair.Parent).to.equal(nil)
				expect(ownHat.Parent).to.equal(nil)
				-- the hunter's outfit has no vest group, so nothing cleared the back attachment
				expect(back.Parent).to.equal(character)
			end)
			Body.setAccessorySource(saved)
			if not ok then
				error(err, 0)
			end
		end)

		it("keeps the player's own hair when the slot falls back to plates", function()
			-- THE OTHER HALF, and it is the half that makes the rule honest: the plates were BUILT
			-- to live with hair (Task 77 raised the crown for exactly that), so nothing is taken off
			-- to make room for something that is not coming. A character that loses its hair and
			-- then gets no cap would be strictly worse than before this task.
			local saved = Body.accessorySource()
			local ok, err = pcall(function()
				Body.setAccessorySource(function(_slot): Instance?
					return nil
				end)
				local character = newRig("Task151KeepsHair")
				local humanoid = Instance.new("Humanoid")
				humanoid.Parent = character
				local hair = ownAccessory("OwnHair", "HairAttachment")
				hair.Parent = character
				expect(Body.dress(character, "Shooters", ON)).to.equal(true)
				expect(#outfitParts(character)).to.equal(HUNTER_PART_COUNT)
				expect(hair.Parent).to.equal(character)
			end)
			Body.setAccessorySource(saved)
			if not ok then
				error(err, 0)
			end
		end)

		it("names one slot per group, and the composition root is the only thing that maps them", function()
			-- `Match.Body` knows the slots it dresses and must never learn an asset key: the mapping
			-- from "hat" to "outfit.cap" lives in `ServerScriptService.OutfitAssetsBoot` alone.
			local hunter = Body.outfitFor("Shooters", ON)
			local beater = Body.outfitFor("Drivers", ON)
			expect(#(hunter :: any).parts).to.equal(1)
			expect((hunter :: any).parts[1].slot).to.equal(Body.SLOTS.hat)
			expect(#(beater :: any).parts).to.equal(2)
			expect((beater :: any).parts[1].slot).to.equal(Body.SLOTS.hat)
			expect((beater :: any).parts[2].slot).to.equal(Body.SLOTS.vest)
			-- the hat GROUP is the same table for both roles, not just its rows
			expect((beater :: any).parts[1]).to.equal((hunter :: any).parts[1])
		end)

		it("dresses the live server, because the flag is ON now", function()
			-- THE ASSERTION THAT BITES TODAY, turned over by task 82. Everything above drives both
			-- branches with a table of its own; this one asks what the RUNNING server did with the
			-- real flag. A player with a team must be dressed -- and every plate of the vest he is
			-- wearing must stand clear of the torso it is welded to, which is the half no spec
			-- checked before Karen played it (77a(d)).
			-- SINCE TASK 151 ROUND 2 "DRESSED" IS NOT "HAS A FOLDER". A slot whose real catalog
			-- accessory loaded wears that instead, and a character wearing both accessories has no
			-- `HuntOutfit` folder at all -- so the folder test would have called a correctly
			-- dressed beater undressed. What is asserted is one WORN THING PER SLOT, by whichever
			-- of the two routes it arrived.
			local dressed, teamed, plates, worst = 0, 0, 0, math.huge
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local character = player.Character
				if character and player.Team then
					teamed += 1
					local accessories = wornAccessories(character)
					local hat = accessories["hat"] ~= nil or partNamed(character, "Hat") ~= nil
					local vest = accessories["vest"] ~= nil or partNamed(character, "VestFront") ~= nil
					local needsVest = player.Team.Name == "Drivers"
					if hat and (vest or not needsVest) then
						dressed += 1
					end
					for _, part in ipairs(outfitParts(character)) do
						local weld = part:FindFirstChildOfClass("WeldConstraint")
						local limb = weld and (weld :: WeldConstraint).Part0
						if limb and limb:IsA("BasePart") and string.sub(part.Name, 1, 4) == "Vest" then
							plates += 1
							worst = math.min(worst, clearanceBetween(limb, part))
						end
					end
				end
			end
			TestKit.note(
				string.format(
					"task82: ORANGE_OUTFITS=%s, %d teamed character(s), %d dressed, %d vest plate(s), worst clearance %s",
					tostring(Match.CONFIG.OUTFITS_ENABLED),
					teamed,
					dressed,
					plates,
					if worst == math.huge then "none" else string.format("%.3f", worst)
				)
			)
			-- WHICH ROUTE THE LIVE SERVER ACTUALLY TOOK. If `accessoriesWorn` is 0 on a run, the
			-- catalog load failed and everybody is in grey-box plates that look deliberate -- which
			-- is playable, and is exactly the difference nobody can see in a console screenshot
			-- unless it is printed.
			TestKit.note(
				string.format(
					"task151 accessories: %d worn, %d slot(s) fell back to plates",
					Body.accessoriesWorn(),
					Body.slotsFellBack()
				)
			)
			-- WHY A SLOT FELL BACK, AS A NUMBER RATHER THAN A GUESS. "The player is in plates" has
			-- two completely different causes -- the catalog load failed, or it succeeded and
			-- nothing re-dressed him -- and they look identical on screen. This reads the loader's
			-- own report for the two outfit keys, so every run says which one happened.
			--
			-- IT IS A READ AND NOT A DRIVE: the spec asks `Assets`/`Loader` what they already hold
			-- and changes nothing. `ServerStorage` is reachable from a server spec, which is the
			-- only reason this can be asked at all from here.
			local ServerStorage = game:GetService("ServerStorage")
			local assetsModule = ServerStorage:FindFirstChild("Assets")
			if assetsModule then
				local AssetsLive = require(assetsModule) :: any
				local LoaderLive = require(assetsModule:FindFirstChild("Loader") :: any) :: any
				local said = {}
				for _, key in ipairs(AssetsLive.keysFor("outfit")) do
					local template, report = LoaderLive.template(key)
					table.insert(
						said,
						string.format(
							"%s=%s%s",
							key,
							if template then "cached" else "MISSING",
							if report and not report.ok then "(" .. tostring(report.reason) .. ")" else ""
						)
					)
				end
				TestKit.note("task151 outfit assets: " .. table.concat(said, " "))
			end
			if Match.CONFIG.OUTFITS_ENABLED then
				expect(dressed).to.equal(teamed)
			else
				expect(dressed).to.equal(0)
			end
			-- AND THE GREEN, on the server that is actually running (task 151). Every teamed
			-- character wears the base on five properties, keeps its own head colour, and has had
			-- its own shirt and trousers taken off.
			local green, headKept, bare = 0, 0, 0
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local character = player.Character
				if character and player.Team then
					local colors = character:FindFirstChildOfClass("BodyColors")
					if colors then
						local all = true
						for _, stem in ipairs(BASE_LIMBS) do
							if (colors :: any)[stem .. "Color3"] ~= BASE_COLOR then
								all = false
							end
						end
						if all then
							green += 1
						end
						if (colors :: BodyColors).HeadColor3 ~= BASE_COLOR then
							headKept += 1
						end
					end
					local covered = false
					for _, className in ipairs(CLEAR_CLASSES) do
						if character:FindFirstChildOfClass(className) then
							covered = true
						end
					end
					if not covered then
						bare += 1
					end
				end
			end
			TestKit.note(
				string.format(
					"task151 live: %d of %d teamed character(s) green, %d kept their own head colour, %d with no shirt/pants",
					green,
					teamed,
					headKept,
					bare
				)
			)
			if Match.CONFIG.OUTFITS_ENABLED then
				expect(green).to.equal(teamed)
				expect(headKept).to.equal(teamed)
				expect(bare).to.equal(teamed)
			else
				expect(green).to.equal(0)
			end
			if plates > 0 then
				expect(worst >= Body.VEST_GAP - 1e-3).to.equal(true)
			end
		end)
	end)
end
