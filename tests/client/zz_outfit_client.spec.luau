--!strict
-- The outfit, from the client's side (M2.8d, map-generator design section 10; the §18 row asks for
-- exactly this spec). The server is the only writer, so what a client can say about an outfit is
-- what REACHED it -- which is the half that matters for the one property this rests on.
--
-- WHY `CanQuery = false` IS THE CHECK AND NOT A DETAIL. Every ray in this game is cast by somebody:
-- the weapon casts for the shot, the camera casts for occlusion, and `Match.Penalty.judge` decides
-- whether a player is tied to a tree from where that shot STOPPED. A hat that stops a pellet is a
-- shot that hit a hat, and the penalty would be judged on it. The design says it in one line ("the
-- outfit must be invisible to every ray in the game") and this is where a client can see that it
-- is true of the Instances it was actually sent.
--
-- WHAT THIS SPEC CAN AND CANNOT REACH, said plainly. `ORANGE_OUTFITS` is born OFF and merges OFF,
-- and `python tools/studio_mcp.py test` REFUSES to start while a flag override is set -- so in a
-- harness run there is never an outfit in the world, and the loop below runs over nothing. The
-- assertion that bites today is the other one: with the flag off, NOBODY is dressed. A dark path
-- that dresses people is not a dark path, and that is the failure this run can actually catch.
-- The ON half is the Director's two-player screenshot, by hand, with the flag switched on for that
-- session only.
--
-- `zz_` AND IT IS NOT DECORATION. The client suite runs while the harness replays a fixed input
-- scenario into this process, so several specs assert on what the scripted keys and clicks had done
-- BY THE TIME THEY RAN -- `weapon_client`'s end state is an ammo count. Specs load in name order, so
-- a new file inserted before one of those shifts it in the replay: this file first landed as
-- `outfit_client.spec` and `weapon_client` came back with 23 slugs instead of 24 and three shots
-- instead of two, with nothing about the weapon changed. The prefix puts this after them, which is
-- also where a read-only spec belongs. (`zz_tie_to_a_tree` keeps the last word; this one only
-- counts and cannot disturb it.) Reported as a harness fragility in TASKS.md row 77a.
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

-- The server's `Match.Body.OUTFIT_NAME`. Written out rather than required: `Match` is
-- ServerScriptService and a client cannot see it, which is the point of the boundary.
local OUTFIT_NAME = "HuntOutfit"

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

		it("dresses nobody while the flag is off, and everybody while it is on", function()
			-- BOTH BRANCHES ARE WRITTEN, and only one of them can run in a harness run. Said in the
			-- header rather than hidden: the OFF branch is the live assertion here, and it is the
			-- one that catches a dark path that is not dark.
			local dressed, total = 0, 0
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if character then
					total += 1
					if character:FindFirstChild(OUTFIT_NAME) then
						dressed += 1
					end
				end
			end
			if Flags.isOn("ORANGE_OUTFITS") then
				expect(dressed).to.equal(total)
			else
				expect(dressed).to.equal(0)
				expect(#outfitParts()).to.equal(0)
			end
		end)
	end)
end
