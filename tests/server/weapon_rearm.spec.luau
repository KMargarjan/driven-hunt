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
-- IT WAITS FOR THE HARNESS TO FINISH DRIVING THE WEAPON FIRST. Respawning the player is exactly
-- what this spec is for, and doing it mid-scenario cost the client suite two specs (the aim hold and
-- the scenario's end state) the first time it ran -- the specs were right and this spec was rude.
-- The server sees the scenario end in its own shot counter, which is the one thing both sides agree
-- on without a new channel.
--
-- It asserts on the REAL weapon owner and the REAL player, like match_live.spec, because a stub
-- would not have the CharacterAdded and Backpack timing that IS the bug.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (section 8.5), docs/design/drive.md (section 8.5)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local REARM_TIMEOUT = 15
-- The input scenarios fire two shots at the barrels and one staged shot at a boar. Waiting for them
-- keeps this spec out of the client suite's way; the timeout is there because a session where the
-- gun never arrived is exactly the session this spec has to run in.
local SCENARIO_SHOTS = 3
local SCENARIO_TIMEOUT = 120

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

local function counters(): string
	local stats = Weapon.stats()
	return string.format(
		"granted=%d grantsMissed=%d revoked=%d shots=%d",
		stats.granted,
		stats.grantsMissed,
		stats.revoked,
		stats.shots
	)
end

return function()
	describe("a shooter's gun, through the drive's own placement", function()
		it("comes back after a respawn with the arming effect landing around it", function()
			local player = Players:GetPlayers()[1]
			expect(player).to.be.ok()
			-- Only a player the drive arms can be asked this. With two players one of them is a
			-- Driver and carries no gun by design; the shooter is not always GetPlayers()[1].
			for _, candidate in ipairs(Players:GetPlayers()) do
				if Match.mayCarryWeapon(candidate) then
					player = candidate
					break
				end
			end
			if not Match.mayCarryWeapon(player) then
				TestKit.note("weapon_rearm: nobody may carry a weapon right now; " .. counters())
				expect(holdsGun(player)).to.equal(false)
				return
			end

			local droveTheWeapon = waitUntil(SCENARIO_TIMEOUT, function()
				return Weapon.stats().shots >= SCENARIO_SHOTS
			end)
			TestKit.note(
				string.format(
					"weapon_rearm: before placements, %s holds=%s scenarioDone=%s | %s",
					player.Name,
					tostring(holdsGun(player)),
					tostring(droveTheWeapon),
					counters()
				)
			)

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
			TestKit.note(
				string.format("weapon_rearm: after two placements, holds=%s | %s", tostring(armed), counters())
			)
			expect(armed).to.equal(true)
		end)

		it("comes back after the gun is taken away mid-drive, which is what a revoke leaves behind", function()
			local player = nil
			for _, candidate in ipairs(Players:GetPlayers()) do
				if Match.mayCarryWeapon(candidate) then
					player = candidate
					break
				end
			end
			if not player then
				return -- everybody here is a driver: there is no gun to lose
			end

			-- A revoke is the drive's own doing at the end of a drive, and the next drive has to put
			-- a gun back. Destroying the Tool directly is the same loss with none of the weapon's
			-- bookkeeping: whatever it holds internally, the PLAYER is empty-handed here.
			local backpack = player:FindFirstChildOfClass("Backpack")
			local tool = (backpack and backpack:FindFirstChildOfClass("Tool"))
				or (player.Character and player.Character:FindFirstChildOfClass("Tool"))
			expect(tool).to.be.ok();
			(tool :: Tool):Destroy()
			expect(holdsGun(player)).to.equal(false)

			Weapon.refreshArming(player)
			local armed = waitUntil(REARM_TIMEOUT, function()
				return holdsGun(player)
			end)
			TestKit.note(
				string.format("weapon_rearm: after a destroyed gun, holds=%s | %s", tostring(armed), counters())
			)
			expect(armed).to.equal(true)
		end)
	end)
end
