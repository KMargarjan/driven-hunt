-- ForestTestBoot: THE COMPOSITION ROOT OF THE PLAYTEST WORLD, and of nothing else.
--
-- It is the twin of `MatchBoot`: boot line only, owns nothing, decides nothing, holds no state. It
-- is where the boar runtime, the weapon and the ambient drive meet in the place "Driven Hunt Forest
-- Test" -- so that, exactly as in the DEV place, no owner requires another owner.
--
-- IT RETURNS IMMEDIATELY ANYWHERE ELSE. `Map.EXPECTED_WORLD` resolves from the place id, so in the
-- DEV place this file is a no-op and the harness that runs there sees nothing new.
--
-- Design: no new design document -- a playtest world behind a world string. TASKS.md row 122.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Map = require(ReplicatedStorage:WaitForChild("Map"))

if Map.EXPECTED_WORLD ~= "forest-test" then
	return
end

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
local Data = ForestTest.Data

print(
	string.format(
		"[ForestTestBoot] world=%s place=%d: %d stands on the road, waves every %ds",
		Map.EXPECTED_WORLD,
		game.PlaceId,
		Data.STAND_COUNT,
		Data.SCHEDULE.intervalSeconds
	)
)

-- ---------------------------------------------------------------- the boars

-- THE FIELD IS THIS WORLD'S, not the generated map's. `Boar.CONFIG.field` describes block 1 of a
-- map that does not exist in this place, and `Brain:_outcome` despawns a boar at
-- `position.Z <= exitZ` -- so with the map's exitZ an animal here would either never be gone or be
-- gone the moment it spawned.
local field = {
	bounds = {
		minX = Data.CENTRE.X - Data.HALF_SPAN,
		maxX = Data.CENTRE.X + Data.HALF_SPAN,
		minZ = Data.EXIT_Z - 100,
		maxZ = Data.CENTRE.Z + Data.DRIVERS.startNorthStuds + 200,
	},
	exitZ = Data.EXIT_Z,
	groundY = Data.CENTRE.Y,
}

-- THE TWO FLAGS ARE ON IN THIS WORLD, AND THEY ARE TURNED ON HERE RATHER THAN LIVE.
--
-- `BOAR_MODEL` (the drawn animal, its sounds, its kinds) and `BOAR_BEHAVIOUR` (what it notices and
-- what it does about it) both default to false, and the Director asked for both ON in this place.
-- The designed way to do that is `tools/flags.py set`, which writes a `DHFlag_*` attribute into the
-- running place -- but that is LIVE STATE: it is not in git, it is lost when somebody reopens the
-- place, and Karen would find a playtest world with box boars and no reason why.
--
-- `Boar.newRuntime` already takes a world `config`, and its own header documents exactly this use
-- ("a world passing `config = { SENSE = { ENABLED = true } }`"). So the world says what it needs
-- and nothing outside this file changes.
--
-- SENSE AND KINDS ARE MERGED KEY BY KEY by `newRuntime`, so `{ ENABLED = true }` is enough and
-- correct. MODEL AND CALM ARE NOT -- they are replaced wholesale -- so each is passed as a full
-- clone with one value flipped. Passing `{ ENABLED = true }` for those would wipe every other
-- number in the block, which is not a boar with a model: it is a boar with nil for every dimension.
local model = table.clone(Boar.CONFIG.MODEL)
model.ENABLED = true
local calm = table.clone(Boar.CONFIG.CALM)
calm.ENABLED = true

local world = Boar.defaultWorld(field)
-- WHERE THIS WORLD'S GROUND IS, per position. See `ForestTest.groundAt`: `field.groundY` is one
-- number and this terrain climbs 56 studs in 400, so without this every released boar was spawned
-- inside a hill.
world.groundAt = Data.groundAt
world.config = {
	MODEL = model,
	CALM = calm,
	SENSE = { ENABLED = true },
	KINDS = { ENABLED = true },
	-- 8 IS THE DRIVE'S CEILING AND IT IS NOT THIS WORLD'S. MEASURED from the server console:
	-- "wave 5 held: 8 of 8 boars already out" -- waves 1 to 4 filled the world and every wave after
	-- them was refused, so the schedule ran but nothing new ever appeared. `Boar.CONFIG.maxBoars`
	-- is 8 because the real drive releases a sounder at a time into a corridor; Karen asked for
	-- *"a lot not too much to break"* and this world has no drive to balance against.
	maxBoars = Data.MAX_BOARS,
}

-- THE CLOSURE TRAP, and the same line as MatchBoot for the same reason (design section 6.5):
-- `defaultWorld`'s own `threats` closes over the module-level config, so the replacement has to
-- happen HERE, at the composition root, rather than being passed in as config.
--
-- THE PHANTOM BEATERS LIVE ON THE OTHER SIDE OF THIS LINE. `ForestTest.boarThreats` returns the
-- real players plus whatever beater the schedule currently wants, and the Brain cannot tell the
-- difference -- a threat is a position and a kind.
world.threats = function()
	return ForestTest.boarThreats(os.clock())
end

local runtime = Boar.newRuntime(world)
runtime:run()

-- A shot is a sound, and a hit is a hit. Both lines are MatchBoot's, verbatim, because the weapon's
-- contract does not change with the world.
Weapon.ShotFired:Connect(function(shot)
	runtime:hearShot(shot.muzzle)
end)

Weapon.HitReported:Connect(function(report)
	if report.target:IsA("BasePart") then
		local shooter = report.shooter
		local character = shooter and shooter.Character
		local root = character and character.PrimaryPart
		runtime:takeHit(report.target, {
			zone = report.zone,
			zones = report.zones,
			ammo = report.ammo,
			pellets = report.pellets,
			at = report.at,
			distance = report.nearest,
			shooterUserId = shooter and shooter.UserId,
			shooterName = shooter and shooter.Name,
			shooterPosition = root and root.Position,
			normal = report.normal,
		})
	end
end)

runtime.Downed:Connect(function(record)
	local userId = record.killedByUserId
	local shooter = if userId then Players:GetPlayerByUserId(userId) else nil
	if shooter then
		Weapon.markHit(shooter, "kill", record.killingZone)
	end
end)

-- ---------------------------------------------------------------- the gun

-- EVERYONE IN THIS WORLD CARRIES. There is no roster here and no drive to be on the wrong side of:
-- Karen is testing shooting alone. `Match.mayCarryWeapon` would have refused everybody, because it
-- answers a question about a drive that is not running.
Weapon.setArmingPolicy(function(_player)
	return true
end)

-- THIS WORLD HAS NO DRIVE LINE, AND REGISTERING ONE CRASHED EVERY SHOT.
--
-- The first version returned `{ from, to }`. `Shotgun.DriveLine` is `{ position, normal }`, so
-- `line.normal` was nil and every single shot died in the safety arc:
--
--   ServerScriptService.Weapon.SafetyArc:15: attempt to index nil with 'Magnitude'
--   Script 'ServerScriptService.Weapon', Line 462 - function onFireRequest
--
-- It was also wrong for a second and better reason, which is why this is a deletion and not a
-- repair. THE SAFETY ARC EXISTS TO PROTECT DRIVERS. There are no drivers in this world -- the
-- beaters are phantoms with nobody standing on them -- and a line whose normal pointed north would
-- flag every shot at the boars Karen is here to shoot. The old comment claimed the opposite ("every
-- shot reads as safe, which would make the one thing Karen wants to test test nothing"); that was
-- reasoning about a drive this place does not have.
--
-- `Weapon.setDriveLineProvider` takes `Shotgun.DriveLineProvider`, which may answer nil, and the
-- weapon already treats "no line" as "nothing to be unsafe toward". The annotation is deliberate:
-- the wrong shape was a runtime crash and should have been a type error.
local noDriveLine: Shotgun.DriveLineProvider = function()
	return nil
end
Weapon.setDriveLineProvider(noDriveLine)

-- ---------------------------------------------------------------- the hunter's stand

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root == nil then
			return
		end
		ForestTest.openPick(player.UserId, os.clock())
		-- He lands on the road at the default stand; where he WALKS in the next ten seconds is the
		-- choice, and the timer below is the save.
		task.defer(function()
			-- FACING THE DRIVE. `CFrame.new(position)` carries no rotation, so the character landed
			-- looking down -Z -- SOUTH, with his back to every animal in the world; the console's
			-- own camera line said look z = -0.99. North is +Z here (a holding at
			-- `roadZ + northStuds` has the larger z), so he is turned to face it.
			local at = ForestTest.spawnPosition()
			local root3 = root :: BasePart
			root3.CFrame = CFrame.lookAt(at, at + Vector3.zAxis)
		end)
		task.delay(Data.PICK.seconds, function()
			if player.Parent == nil or root.Parent == nil then
				return
			end
			local index = ForestTest.lockPick(player.UserId, (root :: BasePart).Position, os.clock())
			print(string.format("[ForestTest] %s took stand %d", player.Name, index))
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	ForestTest.clearPick(player.UserId)
end)

-- ---------------------------------------------------------------- the loop

-- ONE HEARTBEAT FOR BOTH JOBS: the schedule and the leash. The boar runtime runs its own; this is
-- only the playtest's own clock.
--
-- THE WAVE REPORT GOES TO THE CONSOLE, and that is not decoration. A tool connected over StudioMCP
-- cannot read this module's state: its `require` returns ITS OWN instance of the module, with an
-- empty `state` table -- measured, `stats()` answered "started=false boars=0" while 40 boars stood
-- in the world. The console comes from the server that is actually running, so it is the only
-- honest channel for "what is the push doing".
local lastReportAt = 0

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local line = ForestTest.step(now)
	if line then
		print("[ForestTest] " .. line)
	end
	if now - lastReportAt >= 2 then
		lastReportAt = now
		for _, report in ipairs(ForestTest.waveReport(now)) do
			print("[wave] " .. report)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			ForestTest.leash(player.UserId, root :: BasePart)
		end
	end
end)

ForestTest.start(runtime, os.clock())
