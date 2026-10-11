--!strict
-- The outfit, from the client's side (M2.8d, map-generator design section 10; the §18 row asks for
-- exactly this spec). The server is the only writer, so what a client can say about an outfit is
-- what REACHED it -- which is the half that matters, because the client is where Karen looks.
--
-- SINCE TASK 82 THIS SPEC HAS SOMETHING TO MEASURE. `ORANGE_OUTFITS` is ON by default (Karen's OK,
-- PLAYTEST.md 2026-09-27), so in a harness run the players in the world are dressed and every
-- assertion below runs over real Instances instead of over an empty list. Two properties:
--   * `CanQuery = false` on every outfit part. Every ray in this game is cast by somebody -- the
--     weapon for the shot, the camera for occlusion, and `Match.Penalty.judge` decides whether a
--     player is tied to a tree from where that shot STOPPED. A hat that stops a pellet is a shot
--     that hit a hat, and the penalty would be judged on it.
--   * EVERY VEST PLATE STANDS CLEAR OF THE TORSO IT IS WELDED TO. This is the one Karen's report
--     rests on: "I can see hat on hunter but not vest on driver". Task 77's vest was a single plate
--     centred on the limb, so most of it was inside the torso and all of it was on one face; a spec
--     asserted the Instances existed and nobody asserted they could be seen (77a(d)). A plate inside
--     the torso now fails this case on the client that would have had to look at it.
--
-- THE OFF BRANCH IS STILL WRITTEN, because a flag is two states and the default can be flipped back
-- in one line. It is simply not the branch a run takes today.
--
-- AND IT SCANS CHARACTERS, NOT WORKSPACE. `Body.dress` parents the folder to the character and
-- nowhere else, so a character scan is complete -- and `Workspace:GetDescendants()` over a map of
-- 2,700 trees is exactly the kind of cost that moves the replay again.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/map-generator.md (section 10.2), docs/design/feature-flags.md (section 13.2)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- The server's `Match.Body.OUTFIT_NAME` and its vest gap. Written out rather than required: `Match`
-- is ServerScriptService and a client cannot see it, which is the point of the boundary. If either
-- ever disagrees with `src/server/Match/Body.luau`, the case below fails and says so.
local OUTFIT_NAME = "HuntOutfit"
local VEST_GAP = 0.12
-- THE GREEN, by hand for the same reason (task 151). It is the median over 533,692 olive cuff pixels
-- of the two glove albedo maps (docs/research/2026-10-11-beater-kit.md section 3); if the server's
-- `Body.BASE_COLOR` ever stops being it, the case below fails on the client that has to look at it.
local BASE_COLOR = Color3.fromRGB(86, 80, 56)
local BASE_LIMBS = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local CLEAR_CLASSES = { "Shirt", "Pants", "ShirtGraphic" }
-- WHICH SLOTS EACH ROLE WEARS. Not a part count any more (Task 151 round 2): a slot is satisfied
-- either by a real catalog accessory or by its fallback plates, and which one is a run-time fact.
local SLOTS_FOR = { Shooters = { "hat" }, Drivers = { "hat", "vest" } }

local AXES = { "X", "Y", "Z" }

-- How far outside the limb's own box this part lands, in the LIMB's frame: the best of the three
-- axes, because a plate needs to be fully clear on ONE axis to be seen. Negative means it overlaps
-- the limb on every axis -- a vest inside a torso, which is what nobody could see.
local function clearance(limb: BasePart, part: BasePart): number
	local relative = limb.CFrame:Inverse() * part.CFrame
	local best = -math.huge
	for _, axis in ipairs(AXES) do
		local gap = math.abs((relative.Position :: any)[axis])
			- (part.Size :: any)[axis] / 2
			- (limb.Size :: any)[axis] / 2
		best = math.max(best, gap)
	end
	return best
end

-- The attribute the server marks ITS OWN accessories with, written out for the same reason
-- OUTFIT_NAME is: `Match.Body` is ServerScriptService and a client cannot see it. Since Task 151
-- round 2 a slot may be wearing a real catalog accessory instead of plates, and the attribute is
-- what tells one of those from a player's own hat.
local ACCESSORY_TAG = "HuntOutfitAccessory"

-- Every accessory the SERVER put on this character, by slot.
local function wornAccessories(character: Model): { [string]: Instance }
	local out = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accoutrement") then
			local slot = child:GetAttribute(ACCESSORY_TAG)
			if slot ~= nil then
				out[tostring(slot)] = child
			end
		end
	end
	return out
end

-- EVERY PART OF THE OUTFIT THAT REACHED THIS CLIENT, by both routes: the plates in `HuntOutfit` and
-- the parts of any real accessory the server welded on. The ray rule below has to hold for both --
-- a catalog vest that stops a pellet is exactly as wrong as a plate that does.
local function outfitParts(): { BasePart }
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local folder = character and character:FindFirstChild(OUTFIT_NAME)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("BasePart") then
					table.insert(out, child)
				end
			end
		end
		if character then
			for _, accessory in pairs(wornAccessories(character)) do
				for _, d in ipairs(accessory:GetDescendants()) do
					if d:IsA("BasePart") then
						table.insert(out, d)
					end
				end
			end
		end
	end
	return out
end

return function()
	describe("the outfit, as this client received it", function()
		it("never eats a slug: every outfit part is invisible to a ray", function()
			local parts = outfitParts()
			local mine = Players.LocalPlayer.Character
			TestKit.note(
				string.format(
					"outfit[client]: ORANGE_OUTFITS=%s, %d outfit part(s) on live characters, mine=%s",
					tostring(Flags.isOn("ORANGE_OUTFITS")),
					#parts,
					if mine and mine:FindFirstChild(OUTFIT_NAME) then "dressed" else "none"
				)
			)
			for _, part in ipairs(parts) do
				expect(part.CanQuery).to.equal(false)
				expect(part.CanCollide).to.equal(false)
				expect(part.Massless).to.equal(true)
				-- not anchored: an anchored hat pins a head to the world, and the character's
				-- physics belongs to its own client
				expect(part.Anchored).to.equal(false)
			end
		end)

		it("dresses everybody with a team while the flag is on, and nobody while it is off", function()
			-- ONE WORN THING PER SLOT, by whichever route it arrived (Task 151 round 2): the real
			-- catalog accessory if it loaded, the plates if it did not. A character wearing both
			-- accessories has NO `HuntOutfit` folder, so the old folder test would have called a
			-- correctly dressed beater undressed.
			local dressed, teamed = 0, 0
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if character and player.Team then
					teamed += 1
					local accessories = wornAccessories(character)
					local folder = character:FindFirstChild(OUTFIT_NAME)
					local hat = accessories["hat"] ~= nil or (folder ~= nil and folder:FindFirstChild("Hat") ~= nil)
					local vest = accessories["vest"] ~= nil
						or (folder ~= nil and folder:FindFirstChild("VestFront") ~= nil)
					if hat and (vest or player.Team.Name ~= "Drivers") then
						dressed += 1
					end
				end
			end
			TestKit.note(string.format("outfit[client]: %d teamed character(s), %d dressed", teamed, dressed))
			if Flags.isOn("ORANGE_OUTFITS") then
				expect(dressed).to.equal(teamed)
			else
				expect(dressed).to.equal(0)
				expect(#outfitParts()).to.equal(0)
			end
		end)

		it("received the green: five limb colours, the player's own head, and no shirt", function()
			-- THE HALF THAT MATTERS, on the side that matters. The server is the only writer, so
			-- what a client can say about the outfit is what REACHED it -- and since task 151 the
			-- outfit includes a colour, which is the half a late appearance load can overwrite. If
			-- the engine's own appearance landed on top of ours, this case is where it shows.
			local teamed, green, headKept, bare = 0, 0, 0, 0
			local heads = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if character and player.Team then
					teamed += 1
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
						table.insert(heads, tostring((colors :: BodyColors).HeadColor3))
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
					"outfit[client]: %d teamed, %d green, %d own head colour (%s), %d with no shirt/pants",
					teamed,
					green,
					headKept,
					table.concat(heads, " "),
					bare
				)
			)
			if Flags.isOn("ORANGE_OUTFITS") then
				expect(green).to.equal(teamed)
				expect(headKept).to.equal(teamed)
				expect(bare).to.equal(teamed)
			else
				expect(green).to.equal(0)
			end
		end)

		it("wears one thing per slot for its role: a hat for a hunter, a hat and a vest for a beater", function()
			-- KAREN'S DOC, AS A COUNT (task 151): the hunter has the orange hat, the beater has the
			-- orange hat AND the orange vest. Before this task a driver had four plates and no hat.
			-- SINCE ROUND 2 a slot may be a real catalog accessory OR its plates, so what is counted
			-- is the SLOT -- and "both at once" is asserted to be impossible, because two hats on
			-- one head is exactly the kind of thing a part count would have called correct.
			local checked = 0
			local lines = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local team = player.Team
				if character and team and SLOTS_FOR[team.Name] then
					local accessories = wornAccessories(character)
					local folder = character:FindFirstChild(OUTFIT_NAME)
					local said = {}
					for _, slot in ipairs(SLOTS_FOR[team.Name]) do
						local viaAccessory = accessories[slot] ~= nil
						local plateName = if slot == "hat" then "Hat" else "VestFront"
						local viaPlates = folder ~= nil and folder:FindFirstChild(plateName) ~= nil
						local how = if viaAccessory then "accessory" elseif viaPlates then "plates" else "NOTHING"
						table.insert(said, slot .. "=" .. how)
						expect(viaAccessory or viaPlates).to.equal(true)
						expect(viaAccessory and viaPlates).to.equal(false)
					end
					checked += 1
					table.insert(lines, string.format("%s=%s[%s]", player.Name, team.Name, table.concat(said, ",")))
				end
			end
			TestKit.note(string.format("outfit[client]: %d role(s) counted (%s)", checked, table.concat(lines, " ")))
		end)

		it("shows the vest: every plate stands clear of the torso it is welded to", function()
			-- MEASURED ON THIS CLIENT'S OWN INSTANCES, which is where the complaint came from. A
			-- plate whose every axis overlaps the torso is a plate inside the body, and that is the
			-- vest Karen could not find on a driver.
			local measured, worst, worstName = 0, math.huge, "none"
			for _, part in ipairs(outfitParts()) do
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				local limb = weld and weld.Part0
				if limb and limb:IsA("BasePart") and string.sub(part.Name, 1, 4) == "Vest" then
					measured += 1
					local clear = clearance(limb, part)
					if clear < worst then
						worst, worstName = clear, part.Name
					end
					expect(clear >= VEST_GAP - 1e-3).to.equal(true)
				end
			end
			TestKit.note(
				string.format(
					"outfit[client]: %d vest plate(s) measured, worst %s at %s (gap %.2f)",
					measured,
					if worst == math.huge then "none" else string.format("%.3f", worst),
					worstName,
					VEST_GAP
				)
			)
		end)
	end)
end
