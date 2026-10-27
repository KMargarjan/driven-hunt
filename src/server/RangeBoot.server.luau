-- RangeBoot: the composition root of the lobby shooting range in the world the harness runs in.
-- It wires the range's own `Boar` runtime and hands `Range` everything it needs; it decides nothing.
--
-- Design: docs/design/shooting-range.md sections 3 and 5. Task 298, step B2.
--
-- WHY IT IS ITS OWN BOOT AND NOT A BLOCK IN `MatchBoot` (a deviation from design section 3, stated
-- rather than slipped in, for the Director and the Architect to ratify in step B6). Two measured
-- reasons: (1) `MatchBoot` has NO `RunService.Heartbeat` of its own -- grep: the word appears only
-- in its comments -- so the design's *"one more call in the Heartbeat the root already runs"* has no
-- Heartbeat to join in this world; (2) `src/server/MatchBoot.server.luau` is in `TWO_PLAYER_PATHS`
-- (tools/agents.py), so a line added there costs a two-player run and a human click on every round,
-- for a range that one player evidences completely. `ArenaBoot` is the precedent in this repository:
-- one boot line per world-geometry owner, declining to build when the world is not its world.
-- Step B6 wires Karen's place from `ForestTestBoot`, which has its own Heartbeat already.
--
-- IT CANNOT BE HALF-ON AND IT DOES NOT SNIFF `Workspace`: the world's row decides (`Range.ANCHORS`),
-- exactly as `Lobby.anchorFor` and `ArenaBoot` decide, *"because a predicate like that lies the
-- moment a run half-finishes"*.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Map = require(ReplicatedStorage:WaitForChild("Map"))
local RangeData = require(ReplicatedStorage:WaitForChild("Range"))

local row = RangeData.anchorFor(Map.EXPECTED_WORLD)
if row == nil then
	print("[RangeBoot] the world is " .. tostring(Map.EXPECTED_WORLD) .. ": no range row, nothing is built")
	return
end

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Range = require(ServerScriptService:WaitForChild("Range"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
-- Only for `CONFIG.shouldArm`: the answer a server with no arming policy already gives.
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

if not Range.ENABLED then
	print("[RangeBoot] RANGE is off: nothing is built")
	return
end

-- THE RANGE'S OWN RUNTIME, ITS OWN FIELD AND ITS OWN FOLDER (design section 5). It does not borrow
-- the drive's: the lobby is outside the drive's field and an animal there is deleted on the first
-- step, and `Runtime:setField`'s own header says *"THE FOREST IS THE ONLY CALLER"*.
local anchor = Vector3.new(row.x, row.y or 0, row.z)
local field = RangeData.fieldFor(anchor, RangeData.LAYOUT)
local world = Boar.defaultWorld(field)
world.folderName = "RangeTargets"

-- NOBODY IS A THREAT AT A RANGE. With the shipped `defaultWorld.threats` the target would see the
-- shooter 125 studs away and flee the lane, so the threat list is empty and `SENSE` is off as well
-- -- belt to that brace. The lane is a ROUTE, not a reaction.
world.threats = function()
	return {}
end

-- `LINE` IS MERGED AND NOT REPLACED. `Boar.newRuntime` merges `MODEL`, `SENSE` and `KINDS` key by
-- key and assigns every other key WHOLESALE, so `config = { LINE = { ENABLED = true } }` would wipe
-- `ORDER_SECONDS`, `ARRIVE_STUDS` and `TURN_SCALE` -- and an order with a nil lifetime is not an
-- error, it is a crash on the first step.
local line = table.clone(Boar.CONFIG.LINE)
line.ENABLED = true -- required in both worlds: `Brain:leadTo` returns false without it.
world.config = {
	LINE = line,
	SENSE = { ENABLED = false },
	KINDS = { ENABLED = true },
	maxBoars = Range.CONFIG.MAX_TARGETS,
}

local runtime = Boar.newRuntime(world)
runtime:run()

-- A SHOT IS *NOT* A SOUND HERE, and not wiring `Weapon.ShotFired` to this runtime's `hearShot` is
-- the whole mechanism -- no branch, no flag, no new state. In the drive every boar runs from a shot;
-- at a range that would bolt the target off the lane on the first one.

-- THE NARROW VIEW (`ForestTest.readOnlyBoars`' shape): five verbs and two readers, so `Range`
-- requires no owner and can never reach a method this list does not name.
local started = Range.start({
	enabled = true,
	world = Map.EXPECTED_WORLD,
	groundAt = nil, -- DEV lays its own plate (`row.plate`), so there is no ground to read.
	boars = {
		spawn = function(position: Vector3, kind: string?)
			-- The capacity check is here and not in `Range`: how many animals a runtime holds is the
			-- runtime's fact, and `Runtime:spawn` ASSERTS on a full one.
			if runtime:count() >= runtime:capacity() then
				return nil
			end
			return runtime:spawn(position, kind)
		end,
		clear = function(reason: string?)
			runtime:clear(reason)
		end,
		statusOf = function(id: string)
			return runtime:statusOf(id)
		end,
		leadTo = function(id: string, point: Vector3, speed: number)
			return runtime:leadTo(id, point, speed)
		end,
		flying = function(id: string)
			return runtime:flying(id)
		end,
		configOf = function()
			return runtime:config()
		end,
		-- ONE ANSWER TO "HOW FAST IS A TROT", injected rather than required: `Boar.paceSpeed` reads
		-- this runtime's own merged config, so the range invents no speed (design section 6).
		paceSpeed = function(pace: string)
			return Boar.paceSpeed(pace, runtime:config())
		end,
	},
})

if not started then
	warn("[RangeBoot] the range refused to start: " .. tostring(Range.stats().refusedBy))
	return
end

-- A HIT ON A RANGE TARGET IS THE HUNT'S HIT (design section 12): the same `Weapon.HitReported`, the
-- same `Runtime:takeHit`, so a shot that kills on the lane kills in the wood. `takeHit` matches the
-- part against its OWN animals, so this listener and `MatchBoot`'s never answer for each other.
-- The range writes no score and no money: `HitLog.recordHit` is `MatchBoot`'s line and it records
-- nothing while no drive is open (`HitLog.openDrive` is never called here).
Weapon.HitReported:Connect(function(report)
	if not report.target:IsA("BasePart") then
		return
	end
	local shooter = report.shooter
	runtime:takeHit(report.target, {
		zone = report.zone,
		zones = report.zones,
		ammo = report.ammo,
		weapon = report.weapon,
		pellets = report.pellets,
		at = report.at,
		distance = report.nearest,
		shooterUserId = shooter and shooter.UserId,
		shooterName = shooter and shooter.Name,
		normal = report.normal,
	})
end)

-- ------------------------------------------------------------------ THE GUN, ON LOAN (7.4)
--
-- THE TWO RELAXATIONS AND THE LOAN, COMPOSED OVER WHATEVER THIS WORLD ALREADY WIRED. `Range` builds
-- the functions (`armingOver`, `driveOpenOver`, `entitlementOver`); this line installs them and keeps
-- the base each setter hands back, so `MatchBoot`'s own answer is never lost and no caller is edited.
--
-- ON THE FIRST HEARTBEAT, NOT AT REQUIRE TIME: boot Scripts run in no defined order, and composing
-- during the loading stage would capture a base `MatchBoot` had not installed yet -- and then be
-- overwritten by it. The first Heartbeat is after every server Script has run.
local composed = false
local function compose()
	local baseArming: any = nil
	local baseDriveOpen: any = nil
	local baseOwned: any = nil
	baseArming = Weapon.setArmingPolicy(Range.armingOver(function(player)
		return if baseArming ~= nil then baseArming(player) == true else Shotgun.CONFIG.shouldArm(player)
	end))
	baseDriveOpen = Weapon.setDriveOpenProvider(Range.driveOpenOver(function(player)
		return if baseDriveOpen ~= nil then baseDriveOpen(player) else nil
	end))
	baseOwned = Weapon.setEntitlementProvider(Range.entitlementOver(function(player)
		return if baseOwned ~= nil then baseOwned(player) else nil
	end))
	print("[RangeBoot] the range's two relaxations and the four guns on loan are composed")
end

-- ITS OWN HEARTBEAT, because this world's root has none. One clock for the range, throttled to
-- `Range.CONFIG.STEP_HZ` inside the module.
RunService.Heartbeat:Connect(function(dt: number)
	if not composed then
		composed = true
		compose()
	end
	Range.step(dt)
end)
