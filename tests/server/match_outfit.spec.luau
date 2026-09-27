-- match_outfit.spec: the orange hat and the orange vest (M2.8d, map-generator design section 10).
--
-- BOTH BRANCHES OF THE FLAG, AND NEITHER NEEDS THE FLAG. `ORANGE_OUTFITS` is born OFF and merges
-- OFF, so a spec that read the live flag could only ever test one half of the work -- which is the
-- whole reason `Match.CONFIG.OUTFITS_ENABLED` is read ONCE at the boundary and passed inward as a
-- parameter (CLAUDE.md, "Feature flags"; feature-flags.md 13.3). Every case below hands
-- `dressFor`/`dress` a config table of its own, so there is nothing to restore and nothing that
-- depends on what the server booted with.
--
-- IT RUNS AGAINST RIGS THIS SPEC BUILDS, at y = 900, and never against the one real player in the
-- Play session: half the client suite is standing in that player, and a spec that changed what he
-- was wearing would be rewriting what those specs report on (the Task 34 lesson, which
-- match_safety.spec records at length).
--
-- THE NUMBERS ARE WRITTEN OUT rather than read back from the module, the convention
-- test_arena.spec set: a module that disagrees with the design's table is then a finding and not a
-- tautology.
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
local VEST_SIZE = Vector3.new(2.2, 1.6, 1.3)

-- An R15-shaped rig: a root, a head and an upper torso, anchored and far from anybody.
local function rig(name: string, y: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local limbs = {
		{ name = "HumanoidRootPart", size = Vector3.new(2, 2, 1), offset = Vector3.zero },
		{ name = "Head", size = Vector3.new(2, 1, 1), offset = Vector3.new(0, 1.5, 0) },
		{ name = "UpperTorso", size = Vector3.new(2, 1.6, 1), offset = Vector3.new(0, 0.2, 0) },
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

return function()
	describe("the flag row", function()
		it("is declared, born off, and expires within the ceiling", function()
			local row = Flags.DEFAULTS.ORANGE_OUTFITS
			expect(row).to.be.ok()
			-- BORN FALSE. This is the whole of "merges dark": the path exists in main and does
			-- nothing until the Director turns it on for a playtest.
			expect(row.default).to.equal(false)
			expect(row.owner).to.equal("ServerScriptService.Match")
			expect(#row.why > 20).to.equal(true)
			-- `flags.spec` fails the harness on an expiry in the past; this one asserts the other
			-- half of the same rule -- that a NEW dark path was not given a decade.
			expect(row.expires <= "2026-10-18").to.equal(true)
		end)

		it("is the one thing Match.CONFIG reads, and it reads it once", function()
			-- The permitted shape: the config carries a BOOLEAN, not a function and not the flag
			-- name. If this ever became `Flags.isOn(...)` called from inside Body, the ON branch
			-- would stop being reachable by parameter and every case below would be untestable.
			expect(typeof(Match.CONFIG.OUTFITS_ENABLED)).to.equal("boolean")
			expect(Match.CONFIG.OUTFITS_ENABLED).to.equal(Flags.isOn("ORANGE_OUTFITS"))
		end)
	end)

	describe("dressFor, which is pure", function()
		it("gives a shooter a hat on the head and a driver a vest on the torso", function()
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

			local driver = Body.dressFor("Drivers", ON)
			expect(#driver).to.equal(1)
			expect(driver[1].name).to.equal("Vest")
			expect(driver[1].limb).to.equal("UpperTorso")
			expect(driver[1].fallbackLimb).to.equal("Torso") -- R6
			expect(driver[1].color).to.equal(ORANGE)
			expect(driver[1].size).to.equal(VEST_SIZE)
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

	describe("dress, which writes the character", function()
		local made: { Model } = {}

		local function newRig(name: string): Model
			local model = rig(name, 900)
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
			expect(hat.CanQuery).to.equal(false)
			expect(hat.Massless).to.equal(true)
			-- NOT anchored: Body.tie anchors the ROOT, and an anchored hat pins a head to the world.
			expect(hat.Anchored).to.equal(false)
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

		it("puts one orange vest on a driver's torso", function()
			local character = newRig("Task77Driver")
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			local parts = outfitParts(character)
			expect(#parts).to.equal(1)
			expect(parts[1].Name).to.equal("Vest")
			expect(parts[1].Size).to.equal(VEST_SIZE)
			expect(parts[1].CanQuery).to.equal(false)
			local weld = parts[1]:FindFirstChildOfClass("WeldConstraint")
			expect((weld :: WeldConstraint).Part0).to.equal(character:FindFirstChild("UpperTorso"))
		end)

		it("swaps the item when the team swaps, and never wears two", function()
			local character = newRig("Task77Swap")
			expect(Body.dress(character, "Shooters", ON)).to.equal(true)
			expect(#outfitParts(character)).to.equal(2) -- brim and crown
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			local parts = outfitParts(character)
			expect(#parts).to.equal(1) -- and the hat is gone, both parts of it
			expect(parts[1].Name).to.equal("Vest")
			-- and dressing twice for the SAME team is still one item: the folder is destroyed and
			-- rebuilt, which is what makes every call site above safe to call again.
			expect(Body.dress(character, "Drivers", ON)).to.equal(true)
			expect(#outfitParts(character)).to.equal(1)
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
			-- asked for, so "off" is not "whatever you were wearing stays".
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
			-- ...and a driver on an R6 rig finds Torso instead of UpperTorso
			local r6 = newRig("Task77R6")
			local torso = r6:FindFirstChild("UpperTorso") :: BasePart
			torso.Name = "Torso"
			expect(Body.dress(r6, "Drivers", ON)).to.equal(true)
			expect(#outfitParts(r6)).to.equal(1)
		end)

		it("leaves the live server undressed, because the flag is off", function()
			-- THE ASSERTION THAT BITES TODAY. Everything above drives the ON branch with a table of
			-- its own; this one asks what the RUNNING server did with the real flag, and the answer
			-- must be "nothing" -- a merged-dark path that dresses people is not merged dark.
			local dressed, total = 0, 0
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local character = player.Character
				if character then
					total += 1
					if character:FindFirstChild(Body.OUTFIT_NAME) then
						dressed += 1
					end
				end
			end
			TestKit.note(
				string.format(
					"task77: ORANGE_OUTFITS=%s, %d live character(s), %d dressed",
					tostring(Match.CONFIG.OUTFITS_ENABLED),
					total,
					dressed
				)
			)
			if Match.CONFIG.OUTFITS_ENABLED then
				expect(dressed).to.equal(total)
			else
				expect(dressed).to.equal(0)
			end
		end)
	end)
end
