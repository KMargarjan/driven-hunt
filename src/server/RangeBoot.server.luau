-- RangeBoot: THE ONE composition root of the lobby shooting range, in every world that has a row.
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
-- STEP B6 KEEPS THIS AS THE ONE ROOT and adds no second block in `ForestTestBoot`: this file
-- already learns its world the way `Lobby` does -- `Map.EXPECTED_WORLD` through
-- `RangeData.anchorFor` -- so Karen's place is a ROW and not a second wiring (design section 3's
-- two roots, collapsed into one, stated for the Architect rather than slipped in).
--
-- IT CANNOT BE HALF-ON AND IT DOES NOT SNIFF `Workspace`: the world's row decides (`Range.ANCHORS`),
-- exactly as `Lobby.anchorFor` and `ArenaBoot` decide, *"because a predicate like that lies the
-- moment a run half-finishes"*.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
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
-- ONLY FOR `HitLog.sendCard` (task 304): the hit card, built and sent by its own owner, so the
-- range re-derives no projection and writes no row.
local HitLog = require(ServerScriptService:WaitForChild("HitLog"))
-- Only for `CONFIG.shouldArm`: the answer a server with no arming policy already gives.
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

if not Range.ENABLED then
	print("[RangeBoot] RANGE is off: nothing is built")
	return
end

-- THE RANGE'S OWN RUNTIME, ITS OWN FIELD AND ITS OWN FOLDER (design section 5). It does not borrow
-- the drive's: the lobby is outside the drive's field and an animal there is deleted on the first
-- step, and `Runtime:setField`'s own header says *"THE FOREST IS THE ONLY CALLER"*.
-- WHERE THE GROUND IS, IN A WORLD THAT HAS ITS OWN (`row.plate ~= true`). `ForestTest.groundAt`
-- is the ONE reader Karen's lobby, her markers, her boar world and her bots are all handed; a
-- second copy of "where is the ground" would be two definitions of one fact.
local groundAt: ((number, number) -> number?)? = nil
if row.plate ~= true then
	groundAt = (require(ReplicatedStorage:WaitForChild("ForestTest")) :: any).groundAt
end

-- THE SHELF, BEFORE THE FIELD. The runtime's field carries a `groundY`, so the root has to know
-- the shelf before it builds one -- and it asks the owner (`Range.shelfFor`, which asks `Build`)
-- rather than keeping a second copy of the `plate` rule. A typed Y is never used.
local shelf = Range.shelfFor(row, groundAt)
if shelf == nil then
	warn(
		string.format(
			"[RangeBoot] no ground under the range at %s,%s: nothing is built",
			tostring(row.x),
			tostring(row.z)
		)
	)
	return
end

local anchor = Vector3.new(row.x, shelf, row.z)
local field = RangeData.fieldFor(anchor, RangeData.LAYOUT, RangeData.downrangeOf(row))
local world = Boar.defaultWorld(field)
-- THE LANE'S ANIMALS, IN THEIR OWN FOLDER, NAMED ONCE (task 304): `Range.isTarget` reads this same
-- constant, which is how `ForestTestBoot` tells a range target from the drive's.
world.folderName = RangeData.TARGETS_FOLDER
-- ...AND THE SAME READER FOR THE BODIES: `field.groundY` is ONE number and Karen's terrain
-- climbs, so without it a carcass on the lane hangs in the air (`ForestTestBoot`'s own line).
world.groundAt = groundAt

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

-- IS THE TARGET DRAWN HERE? A DATA FIELD ON THE ROW (design section 5's last row), because what
-- an animal looks like is the WORLD's answer and not the range's: in DEV it is the grey box with
-- its real welded zones, which is what every weapon spec already shoots at, and in Karen's place
-- it is the same drawn animal her drive uses. MODEL, CALM, PACE and MOVE are replaced WHOLESALE
-- by `newRuntime` (only MODEL, SENSE and KINDS merge key by key), so each is a full clone with
-- one value flipped -- `ForestTestBoot`'s stated rule, and the gait band follows that run speed.
if row.drawn == true then
	local model = table.clone(Boar.CONFIG.MODEL)
	model.ENABLED = true
	local calm = table.clone(Boar.CONFIG.CALM)
	calm.ENABLED = true
	local pace = table.clone(Boar.CONFIG.PACE)
	pace.ENABLED = true
	local move = table.clone(Boar.CONFIG.MOVE)
	move.ENABLED = true
	model.RUN_FROM = (Boar.CONFIG.TROT_SPEED + pace.RUN_SPEED) / 2
	world.config.MODEL = model
	world.config.CALM = calm
	world.config.PACE = pace
	world.config.MOVE = move
end

local runtime = Boar.newRuntime(world)
runtime:run()

-- WHERE THIS RUNTIME'S TARGET WAS, for the task-305 rewind. CHAINED onto whatever the drive's boot
-- already installed (`Weapon.setHistoryProvider` returns the one it replaced), so the lobby's two
-- runtimes both answer and neither clobbers the other. Without it every shot on the range resolved
-- with no rewind -- round 1 finding 1, and the range is the one place the flag is lit for.
local previousHistory
previousHistory = Weapon.setHistoryProvider(function(instance, at)
	local mine = runtime:cframeAt(instance, at)
	if mine ~= nil then
		return mine
	end
	return if previousHistory ~= nil then previousHistory(instance, at) else nil
end)

-- A SHOT IS *NOT* A SOUND HERE, and not wiring `Weapon.ShotFired` to this runtime's `hearShot` is
-- the whole mechanism -- no branch, no flag, no new state. In the drive every boar runs from a shot;
-- at a range that would bolt the target off the lane on the first one.

-- THE NARROW VIEW (`ForestTest.readOnlyBoars`' shape): five verbs and two readers, so `Range`
-- requires no owner and can never reach a method this list does not name.
local started = Range.start({
	enabled = true,
	world = Map.EXPECTED_WORLD,
	-- nil in DEV, which lays its own plate (`row.plate`) and has no ground to read.
	groundAt = groundAt,
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
		-- THE ZONE COLUMNS ARE THE ANIMAL'S OWN (design 9.1): a boar has five and a red deer six,
		-- so the board reads the order from the config the target was spawned with.
		-- BY THE KIND, which is what `spawn` is given: `Boar.kindConfig` resolves the species from
		-- it, so the board's columns are the animal that is actually on the lane.
		zonesForKind = function(kind: string)
			local config = Boar.kindConfig(kind, runtime:config())
			local zones = config.ZONES
			return if type(zones) == "table" and type(zones.ORDER) == "table" then zones.ORDER else {}
		end,
		zonesFor = function(species: string)
			local config = Boar.speciesConfig(species, runtime:config())
			local zones = config.ZONES
			return if type(zones) == "table" and type(zones.ORDER) == "table" then zones.ORDER else {}
		end,
		-- WHICH KINDS THIS SPECIES HAS, from the kind rows' own `species` field (`Boar.kindConfig`
		-- reads the same one). A boar kind carries none, which is what makes boar the default.
		kindsFor = function(species: string)
			local config = runtime:config()
			local kinds = config.KINDS
			local order = if type(kinds) == "table" then kinds.ORDER else nil
			local out = {}
			if type(order) ~= "table" then
				return out
			end
			for _, kind in ipairs(order) do
				local kindRow = (kinds :: any)[kind]
				local owner = (type(kindRow) == "table" and kindRow.species) or "boar"
				if owner == species then
					table.insert(out, kind)
				end
			end
			return out
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
	local character = shooter and shooter.Character
	local root = character and character.PrimaryPart
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
		-- WITHOUT IT A WOUNDED TARGET BOLTS OFF THE IMPACT NORMAL instead of away from the man who
		-- shot it, which is not what it does in the wood (round 1, note). `MatchBoot` passes it.
		shooterPosition = root and root.Position,
		normal = report.normal,
	})
	-- ...AND THE SAME REPORT IS THE BOARD'S HIT AND ITS ZONE COLUMN (design 9.1). A DERIVED VIEW of
	-- the report `HitLog` is fed from in the same frame: no second source of truth, no drive row.
	Range.onHitReported(report)
end)

-- ------------------------------------------------------------------ THE MENU AND THE BOARD (B4)
--
-- THE TWO REMOTES, TOLD to `Range` (it reaches no DataModel of its own), and the one inbound door
-- connected here: `Range.onRequest` measures every fact off the character the server can see.
local remotes = RangeData.remotes()
Range.setRemotes(remotes)
-- ...AND THE HIT CARD'S SENDER (task 304). Karen, 2026-10-28: *"hit card will be usefull"*. It is
-- `HitLog`'s own builder and `HitLog`'s own remote -- nothing here re-derives a dot -- and it writes
-- no drive row, no money and no report entry: the range is free (design section 1).
Range.setCardSender(function(report: any): boolean
	return HitLog.sendCard(report)
end)
remotes.RangeRequest.OnServerEvent:Connect(function(player, request)
	Range.onRequest(player, request)
end)

-- THE RECORD'S TWO INPUTS (design 9.1). `ShotResolved` fires once per RESOLVED shot, hit or miss --
-- which is the only way a MISS is counted at all, since `HitReported` is per hit (design 8.3).
Weapon.ShotResolved:Connect(function(shot)
	Range.onShotResolved(shot)
end)

-- A RECORD LEAVES WITH ITS PLAYER (round 1, finding 2).
Players.PlayerRemoving:Connect(function(player)
	Range.forget(player)
end)

-- ------------------------------------------------------------------ THE GUN, ON LOAN (7.4)
--
-- THE TWO RELAXATIONS AND THE LOAN, COMPOSED OVER WHATEVER THIS WORLD ALREADY WIRED. `Range` builds
-- the functions (`armingOver`, `driveOpenOver`, `entitlementOver`, `standOver`) and `installOver`
-- installs them, keeping the base each of the four setters hands back -- `setStandProvider` hands one
-- back since task 301 -- so `MatchBoot`'s own answer is never lost and no caller is edited.
--
-- ON THE FIRST HEARTBEAT, NOT AT REQUIRE TIME: boot Scripts run in no defined order, and composing
-- during the loading stage would capture a base `MatchBoot` had not installed yet -- and then be
-- overwritten by it. The first Heartbeat is after every server Script has run.
local composed = false
local function compose()
	-- THE BODY LIVES IN `Range.installOver` (task 301), so the spec drives THIS composition rather
	-- than a copy of it. This root passes the one thing the module must not require: the gun's own
	-- "arm him anyway" answer.
	Range.installOver(Shotgun.CONFIG.shouldArm)
	print("[RangeBoot] the range's three relaxations and the four guns on loan are composed")
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
