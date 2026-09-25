-- BoarBoot: spawns the production boar at server start (ROADMAP.md step 1.2).
-- Boot line only. All state, movement and lifetime belong to ServerScriptService.Boar (rule 3),
-- mirroring ArenaBoot.server.luau.
--
-- It asserts the arena still matches Boar.CONFIG.field before spawning. Boar itself never requires
-- TestArena: the arena rectangle is carried as data, so when the Milestone 2 map generator replaces
-- the arena this fails loudly here instead of routing the boar to an edge that no longer exists.
--
-- Design: docs/design/boar-ai.md (section 9)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestArena = require(ServerScriptService:WaitForChild("TestArena"))

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

local runtime = Boar.newRuntime(Boar.defaultWorld())
runtime:spawn()
runtime:run()

-- The weapon publishes hits; the boar's own owner decides what a hit means. This composition root
-- knows both systems so that neither owner requires the other (shotgun design section 6.3), which
-- is the same reason TestArena is required here and not from Boar.
-- Weapon.HitReported exists as soon as the module is required, before Weapon.start(), so the order
-- of the two boot Scripts does not matter.
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

Weapon.HitReported:Connect(function(report)
	if report.target:IsA("BasePart") then
		local shooter = report.shooter
		local character = shooter and shooter.Character
		local root = character and character.PrimaryPart
		-- Every field here already exists on the report the weapon publishes; this widening reads
		-- nothing new from another system (hit-zones design section 9.2). userId and name, never the
		-- Player: a wounded boar can outlive a disconnect by 16 seconds, and a stored Player pins the
		-- instance (design section 8.4).
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

-- The kill marker. The boar's runtime is the only thing that knows the animal died; the weapon owns
-- the one-way remote to the shooter; the Hud draws it. This line is the only place those three meet,
-- and it owns nothing (Director decision, 2026-09-25: hit-zones design section 14 item C).
runtime.Downed:Connect(function(record)
	local userId = record.killedByUserId
	local shooter = if userId then Players:GetPlayerByUserId(userId) else nil
	if shooter then
		Weapon.markHit(shooter, "kill", record.killingZone)
	end
end)
