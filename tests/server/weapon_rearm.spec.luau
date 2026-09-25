-- weapon_rearm.spec: the arming sweep -- the thing that puts a gun back in a shooter's hands when
-- every edge has missed (Task 34).
--
-- WHY THERE IS A SWEEP. Every grant in this system is edge-triggered: the drive calls
-- Weapon.refreshArming on its own phase transitions, and the weapon grants on CharacterAdded. A
-- two-player drive found the hole between those edges twice -- the drive places players
-- (Match.Body.place -> LoadCharacter), the grant lands around that respawn while the answer to
-- "may this player carry a gun" is still changing, and nothing ever asks again. mayCarryWeapon said
-- the shooter was armed; the shooter carried nothing for a whole ten-minute drive, and no Tool
-- existed anywhere in the place.
--
-- WHY THIS SPEC DOES NOT TAKE THE PLAYER'S GUN. It did, at first, and the client suite failed specs
-- that were entirely right: the scenario's end state and the exploit path both describe THIS
-- player's weapon, and a spec that revokes and re-grants it mid-session rewrites what they are
-- reporting on. So the decision is asserted as a pure function, the sweep is asserted to be
-- running, and the live outcome -- a shooter is holding a gun -- belongs to match_live.spec, which
-- is the spec a two-player run actually fails.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (section 8.5), and the deltas in reviews/task-34/DESIGN_DELTA.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local SWEEP_OBSERVATION = 6 -- seconds: the sweep runs every 2, so this sees at least two passes

local function gunOf(player: Player): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = backpack and backpack:FindFirstChildOfClass("Tool")
	if tool then
		return tool
	end
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

return function()
	describe("the arming decision", function()
		it("grants to someone who may carry and is not holding, and revokes the other way", function()
			expect(Weapon.armingAction(true, false)).to.equal("grant")
			expect(Weapon.armingAction(false, true)).to.equal("revoke")
			-- The two cases that must do NOTHING: doing something here is what would re-grant a gun
			-- under a player who is using it, on every sweep, for the whole session.
			expect(Weapon.armingAction(true, true)).to.equal(nil)
			expect(Weapon.armingAction(false, false)).to.equal(nil)
		end)
	end)

	describe("the arming sweep", function()
		it("is running in this server, which is the only reason a missed edge heals", function()
			local before = Weapon.stats().armingSweeps
			task.wait(SWEEP_OBSERVATION)
			local after = Weapon.stats().armingSweeps
			TestKit.note(
				string.format(
					"weapon_rearm: sweeps %d -> %d in %d s, repairs=%d granted=%d revoked=%d grantsMissed=%d",
					before,
					after,
					SWEEP_OBSERVATION,
					Weapon.stats().armingRepairs,
					Weapon.stats().granted,
					Weapon.stats().revoked,
					Weapon.stats().grantsMissed
				)
			)
			expect(after > before).to.equal(true)
		end)

		it("leaves a correctly armed player exactly as it found them", function()
			-- The sweep asks the question refreshArming asks, so the steady state must be steady:
			-- nobody is re-granted while they are holding what they should hold. A sweep that
			-- churned would break the client's scenario one snapshot at a time.
			--
			-- THE SAME TOOL, not an unchanged counter: a drive that places players during these six
			-- seconds grants legitimately, and counting grants would fail this spec for something it
			-- does not own. The identity of the gun in the player's hands is the claim.
			local rows = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local mayCarry = Match.mayCarryWeapon(player)
				local gun = gunOf(player)
				table.insert(
					rows,
					string.format("%s may=%s holds=%s", player.Name, tostring(mayCarry), tostring(gun ~= nil))
				)
				if mayCarry and gun then
					task.wait(SWEEP_OBSERVATION)
					expect(gunOf(player)).to.equal(gun)
				end
			end
			TestKit.note("weapon_rearm: steady state " .. table.concat(rows, "; "))
		end)
	end)
end
