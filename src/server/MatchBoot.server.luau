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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- THE HORN'S NUMBERS (task 152). The boot reads one of them -- how far a blast carries -- and the
-- team that carries one; the behaviour is `Weapon.Horn`'s and the animals are `Boar`'s.
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local HornData = require(ReplicatedStorage:WaitForChild("Horn"))
local Map = require(ReplicatedStorage:WaitForChild("Map"))

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Match = require(ServerScriptService:WaitForChild("Match"))
-- THE HIT RECORD (task 124). Wired here for the same reason the boar runtime and the weapon are:
-- `HitLog` requires neither of them and neither requires it. The DEV world's drive boundary is
-- `Match.PhaseChanged`; the Forest Test latches on its own window.
local HitLog = require(ServerScriptService:WaitForChild("HitLog"))
local TestArena = require(ServerScriptService:WaitForChild("TestArena"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

-- THE PLAYTEST WORLD HAS ITS OWN COMPOSITION ROOT, AND THIS ONE STANDS ASIDE FOR IT (task 122).
--
-- "Driven Hunt Forest Test" is a hand-built place where Karen stands on a road and shoots animals
-- that cross it. There is no drive there, no roster and no tagged markers -- `Match.Markers.read`
-- would find none, the match would sit in `Waiting` forever, and `Match.mayCarryWeapon` would
-- therefore hand nobody a gun. That is not a broken match; it is a world this match was never
-- about.
--
-- SO THE DECISION IS MADE ONCE, HERE, at the only place that already decides which world is the
-- world. `ForestTestBoot` wires that world's boar runtime and weapon exactly as the lines below
-- wire this one's. Two composition roots, one per world, neither requiring the other -- which is
-- the property this file's header exists to protect.
if Map.EXPECTED_WORLD == "forest-test" then
	print("[MatchBoot] the world is forest-test: ForestTestBoot owns this place")
	return
end

-- Unchanged from BoarBoot: the arena rectangle is carried as data, so when the Milestone 2 map
-- generator replaces the arena this fails loudly here instead of routing boars to an edge that no
-- longer exists.
-- ...and ONLY WHILE THE ARENA IS THE WORLD (M2.8e). Once `Map.EXPECTED_WORLD` is "map:v1",
-- `ArenaBoot` never builds the grey box and `Boar.CONFIG.field` is the map's corridor, so this
-- assertion would compare the map's rectangle against an arena nobody built. The contract's own
-- string decides, exactly as `ArenaBoot` does, so this composition root still decides nothing.
local field = Boar.CONFIG.field
if Map.EXPECTED_WORLD == "arena" then
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
end

local world = Boar.defaultWorld()

-- THE CLOSURE TRAP, and it is why this line exists (design section 6.5): Boar.defaultWorld's
-- `threats` closes over the MODULE-level Boar.CONFIG, not over the runtime's merged clone, so
-- passing `config = { isThreat = ... }` into the world would change the Brain's copy and not the one
-- that actually filters threats. Replace the function itself, here, at the composition root.
-- EVERYTHING A BOAR CAN PERCEIVE, drivers and shooters alike, each carrying its own `kind` (task
-- 118). WHO SCARES IT IS STILL NOT THIS LINE'S DECISION: with `BOAR_BEHAVIOUR` off the Brain drops
-- every stimulus that is not a driver, so a shooter on a post is invisible and cannot push the boar
-- back into the wood -- exactly as before. With the flag on he is noticed at 25 studs and flushes it
-- only at 15, which is what lets a boar come down to the line at all.
-- Design: docs/design/boar-behaviour.md section 8
world.threats = Match.boarThreats

local runtime = Boar.newRuntime(world)
-- The Heartbeat is boot; WHEN a boar exists is the Match's call, so nothing is spawned here.
runtime:run()

-- A SHOT IS A SOUND (task 118, docs/design/boar-behaviour.md section 4.5): every boar inside
-- `SENSE.SHOT_AUDIBLE_STUDS` sprints, hit or miss. The mirror of the `HitReported` line below, in
-- the same composition root and for the same reason -- neither owner requires the other.
Weapon.ShotFired:Connect(function(shot)
	-- BOTH ENDS OF THE SHOT (task 149b): the bang at the muzzle and the strike at the far end,
	-- each with its own radius. `shot.at` is nil for any caller older than this task.
	runtime:hearShot(shot.muzzle, shot.at)
end)

-- Unchanged from BoarBoot. The weapon publishes hits; the boar's own owner decides what a hit means.
Weapon.HitReported:Connect(function(report)
	if report.target:IsA("BasePart") then
		-- THE RECORD, BESIDE THE DAMAGE AND NOT INSTEAD OF IT (task 124).
		HitLog.recordHit(report)
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
-- THE REPORTING WINDOW IS THE DRIVE (task 124). This world HAS a drive, so the record's window is
-- simply its phases: a drive opens when teams are assigned and closes when the scoring starts. Both
-- calls are idempotent at the other end, so a phase that fires twice cannot open two drives.
Match.PhaseChanged:Connect(function(_before, phase, driveNumber)
	if phase == "Assigning" then
		HitLog.openDrive(driveNumber or 1, os.clock())
	elseif phase == "Scoring" then
		HitLog.closeDrive(os.clock())
	end
end)
HitLog.start()

runtime.Downed:Connect(function(record)
	-- ...AND THE DEATH, which is the kill line everybody sees and the row the report draws.
	HitLog.recordDown(record)
	local userId = record.killedByUserId
	local shooter = if userId then Players:GetPlayerByUserId(userId) else nil
	if shooter then
		Weapon.markHit(shooter, "kill", record.killingZone)
	end
end)

-- A HORN IS A PUSH (task 152): every boar within the horn's own radius runs away from the beater who
-- blew it. The exact mirror of the `Weapon.ShotFired` line above -- the horn publishes one fact and
-- the boar's owner decides what it means -- and the radius comes from the HORN, because how far a
-- signal carries is a property of the signal (`Horn.spookStuds`).
--
-- IT IS NOT THE SHOT PATH. `runtime:hearHorn` goes through `Brain:spook`, the same door a real
-- driver's flush uses, so nothing latches and the animals settle afterwards under the rules they
-- already have (docs/research/2026-10-11-beater-kit.md section 5.3).
Weapon.Horn.Blown:Connect(function(blast)
	runtime:hearHorn(blast.at, HornData.spookStuds(HornData.CONFIG))
end)

-- The drive answers two questions for the weapon and writes none of its state: who may carry a gun,
-- and where the drive line is. The weapon still decides and still writes (design section 8.5).
Weapon.setArmingPolicy(Match.mayCarryWeapon)
Weapon.setDriveLineProvider(Match.driveLine)

-- ...AND A THIRD, FOR THE HORN: who is a beater. `Match.Body.teamOf` reads `Player.Team` -- the same
-- fact the outfit is chosen from -- so a beater's horn and a beater's vest can never disagree about
-- whether he is one. The horn still decides and still writes; this root only answers the question.
-- The drive respawns players to place them, which destroys the Tool, and `Horn.start`'s own sweep is
-- what notices -- so the match needs no new call and `src/server/Match/` is untouched by this task.
--
-- THE FLAG IS READ ONCE, HERE, AT THE BOUNDARY, and the value is passed inward -- the only permitted
-- shape (CLAUDE.md, "Feature flags"). `Horn.carriesFor(on, team)` is pure, so both worlds are
-- reachable in a spec while the flag sits at one of them, and OFF nobody is granted anything: the
-- drive is bit-for-bit the game before task 152.
local hornOn = Flags.isOn(HornData.FLAG)
Weapon.Horn.setCarryPolicy(function(player)
	return HornData.carriesFor(hornOn, Match.Body.teamOf(player))
end)
Weapon.Horn.start()
print(string.format("[MatchBoot] horn=%s", if hornOn then "on" else "off (born dark, task 152)"))

Match.start({
	boars = runtime, -- the Match calls spawn/clear and reads handles; it never writes a boar
	-- The weapon, for two things and nothing else: refreshArming (the Tool is granted or revoked by
	-- its own owner) and SafetyViolated, the signal the drive judges (design sections 8.2, 8.5).
	weapon = Weapon,
	now = function()
		return os.clock()
	end,
})
