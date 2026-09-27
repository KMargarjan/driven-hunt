-- match_outfit.spec: the orange hat and the orange vest (M2.8d, map-generator design section 10),
-- and since Task 82 the invariant Karen's complaint rests on -- that the vest is OUTSIDE the torso.
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
-- Design: docs/design/map-generator.md (section 10), docs/design/feature-flags.md (section 13.3)
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
			local driver = Body.dressFor("Drivers", ON)
			expect(#driver).to.equal(#VEST_PLATES)
			for index, name in ipairs(VEST_PLATES) do
				expect(driver[index].name).to.equal(name)
				expect(driver[index].limb).to.equal("UpperTorso")
				expect(driver[index].fallbackLimb).to.equal("Torso") -- R6
				expect(driver[index].color).to.equal(ORANGE)
			end
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
			local rows = Body.dressFor("Drivers", ON)
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
			local rows = Body.dressFor("Drivers", ON)
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
				expect(#parts).to.equal(#VEST_PLATES)
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
			expect(#outfitParts(character)).to.equal(2) -- brim and crown
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			local parts = outfitParts(character)
			expect(#parts).to.equal(#VEST_PLATES) -- and the hat is gone, both parts of it
			expect(partNamed(character, "Hat")).to.equal(nil)
			-- and dressing twice for the SAME team is still one vest: the folder is destroyed and
			-- rebuilt, which is what makes every call site above safe to call again.
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			expect(#outfitParts(character)).to.equal(#VEST_PLATES)
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
			expect(#outfitParts(character)).to.equal(2)
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
			expect(#outfitParts(r6)).to.equal(#VEST_PLATES)
			for _, part in ipairs(outfitParts(r6)) do
				expect(clearanceBetween(torso, part) >= Body.VEST_GAP - 1e-3).to.equal(true)
			end
		end)

		it("dresses the live server, because the flag is ON now", function()
			-- THE ASSERTION THAT BITES TODAY, turned over by task 82. Everything above drives both
			-- branches with a table of its own; this one asks what the RUNNING server did with the
			-- real flag. A player with a team must be dressed -- and every plate of the vest he is
			-- wearing must stand clear of the torso it is welded to, which is the half no spec
			-- checked before Karen played it (77a(d)).
			local dressed, teamed, plates, worst = 0, 0, 0, math.huge
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local character = player.Character
				if character and player.Team then
					teamed += 1
					local folder = character:FindFirstChild(Body.OUTFIT_NAME)
					if folder then
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
			if Match.CONFIG.OUTFITS_ENABLED then
				expect(dressed).to.equal(teamed)
			else
				expect(dressed).to.equal(0)
			end
			if plates > 0 then
				expect(worst >= Body.VEST_GAP - 1e-3).to.equal(true)
			end
		end)
	end)
end
