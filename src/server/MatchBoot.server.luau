-- MatchBoot: THE ONE COMPOSITION ROOT OF THE DRIVE. Boot line only: it owns nothing, decides
-- nothing, and holds no state. It is where the boar runtime, the weapon and the match meet, so that
-- no owner requires another owner (the property docs/design/shotgun.md section 6.3 established).
--
-- It replaces BoarBoot.server.luau, which is archived at
-- backups/2026-09-25_boarboot.server.luau.txt with a note (rule 7: never delete). All three of its
-- jobs are here verbatim -- the arena assertion, the production boar runtime, and the
-- Weapon.HitReported wiring -- because from Milestone 1.7a **when a boar exists is a drive
-- decision**, and two Scripts in ServerScriptService have no defined order and cannot share a Luau
-- value. Leaving the runtime in BoarBoot would have forced a singleton accessor on Boar, which is a
-- global by another name.
--
-- Design: docs/design/drive.md (section 3.5)
-- Note:   docs/research/2026-09-25-drive.md
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestArena = require(ServerScriptService:WaitForChild("TestArena"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

-- Unchanged from BoarBoot: the arena rectangle is carried as data, so when the Milestone 2 map
-- generator replaces the arena this fails loudly here instead of routing boars to an edge that no
-- longer exists.
local field = Boar.CONFIG.field
local ground = TestArena.LAYOUT.ground
local span = field.bounds.maxX - field.bounds.minX

assert(
	ground.span == span and ground.top == field.groundY,
	string.format(
		"boar-ai: the arena changed (span %d, top %d) but Boar.CONFIG.field still says span %d, groundY %d."
			.. " Update CONFIG.field in src/server/Boar/init.luau (see docs/design/boar-ai.md section 9).",
		ground.span,
		ground.top,
		span,
		field.groundY
	)
)

local world = Boar.defaultWorld()

-- THE CLOSURE TRAP, and it is why this line exists (design section 6.5): Boar.defaultWorld's
-- `threats` closes over the MODULE-level Boar.CONFIG, not over the runtime's merged clone, so
-- passing `config = { isThreat = ... }` into the world would change the Brain's copy and not the one
-- that actually filters threats. Replace the function itself, here, at the composition root.
-- Only DRIVERS scare boars: a shooter standing on a post must not push the boar back into the wood
-- before it reaches the line.
world.threats = Match.driverThreats

local runtime = Boar.newRuntime(world)
-- The Heartbeat is boot; WHEN a boar exists is the Match's call, so nothing is spawned here.
runtime:run()

-- Unchanged from BoarBoot. The weapon publishes hits; the boar's own owner decides what a hit means.
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

-- The kill marker: the boar's runtime is the only thing that knows the animal died, the weapon owns
-- the one-way remote to the shooter, and the Hud draws it (Task 28).
runtime.Downed:Connect(function(record)
	local userId = record.killedByUserId
	local shooter = if userId then Players:GetPlayerByUserId(userId) else nil
	if shooter then
		Weapon.markHit(shooter, "kill", record.killingZone)
	end
end)

-- The drive answers two questions for the weapon and writes none of its state: who may carry a gun,
-- and where the drive line is. The weapon still decides and still writes (design section 8.5).
Weapon.setArmingPolicy(Match.mayCarryWeapon)
Weapon.setDriveLineProvider(Match.driveLine)

Match.start({
	boars = runtime, -- the Match calls spawn/clear and reads handles; it never writes a boar
	-- The weapon, for two things and nothing else: refreshArming (the Tool is granted or revoked by
	-- its own owner) and SafetyViolated, the signal the drive judges (design sections 8.2, 8.5).
	weapon = Weapon,
	now = function()
		return os.clock()
	end,
})
