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
			local dressed, teamed = 0, 0
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if character and player.Team then
					teamed += 1
					if character:FindFirstChild(OUTFIT_NAME) then
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
