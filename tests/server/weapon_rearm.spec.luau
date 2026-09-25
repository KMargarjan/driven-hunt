-- weapon_rearm.spec: the gun survives what the DRIVE does to a player, in one Play session with one
-- player -- so the bug a two-player run found can be chased in a two-minute harness run instead of a
-- seven-minute Clients-and-Servers one (Task 34, Director's method, 2026-09-25).
--
-- WHAT THE DRIVE DOES, measured on a live server: every placement respawns the player
-- (Match.Body.place -> LoadCharacter), and the drive's refreshArming effect lands around that
-- respawn -- sometimes before the old Backpack is destroyed, sometimes between it and the new one.
-- A Tool belongs to whatever it is parented to, so a grant that lands in the doomed Backpack dies
-- with it, and the weapon must NOTICE and grant again. The symptom when it does not: a Shooter
-- walks a whole drive with empty hands while mayCarryWeapon says they are armed.
--
-- It asserts on the REAL weapon owner and the REAL player, like match_live.spec, because a stub
-- would not have the CharacterAdded and Backpack timing that IS the bug.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (section 8.5), docs/design/drive.md (section 8.5)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local REARM_TIMEOUT = 15

local function waitUntil(timeout: number, predicate: () -> boolean): boolean
	local started = os.clock()
	while os.clock() - started < timeout do
		if predicate() then
			return true
		end
		task.wait(0.1)
	end
	return predicate()
end

local function holdsGun(player: Player): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and backpack:FindFirstChildOfClass("Tool") then
		return true
	end
	local character = player.Character
	return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
end

return function()
	describe("a shooter's gun, through the drive's own placement", function()
		it("comes back after a respawn with the arming effect landing around it", function()
			local player = Players:GetPlayers()[1]
			expect(player).to.be.ok()
			-- Only a player the drive arms can be asked this. With two players one of them is a
			-- Driver and carries no gun by design, so drive that case through the shooter only.
			if not Match.mayCarryWeapon(player) then
				expect(holdsGun(player)).to.equal(false)
				return
			end

			expect(waitUntil(REARM_TIMEOUT, function()
				Weapon.refreshArming(player)
				return holdsGun(player)
			end)).to.equal(true)

			-- THE DRIVE'S ORDER, as traced on a live server: the effect, then the placement, then
			-- the effect again while the Backpack is being replaced -- and a second placement right
			-- behind it, because a join re-enters Assigning.
			Weapon.refreshArming(player)
			player:LoadCharacter()
			task.wait()
			Weapon.refreshArming(player)
			task.wait(0.2)
			player:LoadCharacter()
			Weapon.refreshArming(player)

			local armed = waitUntil(REARM_TIMEOUT, function()
				return holdsGun(player)
			end)
			print(
				string.format(
					"[weapon_rearm] after two placements: holds=%s granted=%d grantsMissed=%d revoked=%d",
					tostring(holdsGun(player)),
					Weapon.stats().granted,
					Weapon.stats().grantsMissed,
					Weapon.stats().revoked
				)
			)
			expect(armed).to.equal(true)
		end)

		it("comes back after the gun is taken away mid-drive, which is what a revoke leaves behind", function()
			local player = Players:GetPlayers()[1]
			if not Match.mayCarryWeapon(player) then
				return -- a driver: there is no gun to lose
			end

			-- A revoke is the drive's own doing at the end of a drive, and the next drive has to put
			-- a gun back. Destroying the Tool directly is the same loss with none of the drive's
			-- bookkeeping: whatever the weapon holds internally, the PLAYER is empty-handed here.
			local backpack = player:FindFirstChildOfClass("Backpack")
			local tool = (backpack and backpack:FindFirstChildOfClass("Tool"))
				or (player.Character and player.Character:FindFirstChildOfClass("Tool"))
			expect(tool).to.be.ok();
			(tool :: Tool):Destroy()
			expect(holdsGun(player)).to.equal(false)

			Weapon.refreshArming(player)
			expect(waitUntil(REARM_TIMEOUT, function()
				return holdsGun(player)
			end)).to.equal(true)
		end)
	end)
end
