-- Role: which team is THIS client's player on, resolved once for the whole client suite.
--
-- WHY IT EXISTS. Since Task 34 the harness can run the specs with two players, and the drive makes
-- one of them a DRIVER -- who carries no gun at all (`Match.CONFIG.DRIVERS_MAY_SHOOT = false`), so a
-- driver's client cannot equip, fire, reload, aim down sights or receive a hit marker. Until now that
-- half of the suite simply failed and `test2` printed the driver's report as an observation and
-- checked nothing in it: 23 of 67 specs unasserted (TASKS.md row 34a item 1).
--
-- THE FIX IS NOT A SKIP. TestKit fails a run with any skipped test, and rightly: a skip proves
-- nothing and hides everything. Each spec instead asserts what is TRUE FOR THIS PLAYER'S ROLE -- a
-- shooter's claims, or the driver's own, which are real rules and not excuses:
--   * a driver never holds a Tool, and the weapon's input actions are never bound for him;
--   * a driver's crosshair is never on screen and his camera never enters Aiming;
--   * a driver is never staged on a boar and never receives a hit marker;
--   * a driver's Hud badge says DRIVER.
-- Both branches are asserted, so `test2` can require PASS from all three reports.
--
-- RESOLVED AT REQUIRE TIME, ON PURPOSE. Every spec module is required before TestEZ builds its plan,
-- and `InputReady.ready` is published from those same module bodies -- so resolving here, before the
-- ready attribute exists, means the harness's replay cannot begin until every client knows what it
-- is. Resolving lazily inside the plan or inside an `it` would let the replay start first and burn
-- the input specs' own budgets waiting (measured shape of the Task 34 failure).
--
--   Player.Team  https://create.roblox.com/docs/reference/engine/classes/Player#Team
--     Server-authoritative and replicated; `Match.Body` is its only writer (GAME_DESIGN.md).
--
-- Design: docs/design/drive.md (section 5.1)
local Players = game:GetService("Players")

local Role = {}

-- The drive assigns on entering Assigning, which follows the first join. A one-player `test` writes
-- its token before Play, so this really does wait for the drive here; a two-player `test2` opens the
-- gate long after the teams exist and this returns on the first look.
Role.TIMEOUT = 25

local function resolve(): string?
	local deadline = os.clock() + Role.TIMEOUT
	repeat
		local team = Players.LocalPlayer.Team
		if team then
			return team.Name
		end
		task.wait(0.2)
	until os.clock() >= deadline
	local team = Players.LocalPlayer.Team
	return if team then team.Name else nil
end

Role.team = resolve()

function Role.mine(): string?
	return Role.team
end

-- UNKNOWN COUNTS AS SHOOTER, and that is deliberate: it is the one-player truth (Director decision F
-- makes a lone player a Shooter) and it is the historical behaviour of every spec here, so a drive
-- stuck in Waiting fails the shooter's assertions loudly instead of quietly passing a driver's.
function Role.isDriver(): boolean
	return Role.team == "Drivers"
end

function Role.isShooter(): boolean
	return not Role.isDriver()
end

-- What the Hud's team badge must read for this player.
function Role.badge(): string
	return if Role.isDriver() then "DRIVER" else "SHOOTER"
end

return Role
