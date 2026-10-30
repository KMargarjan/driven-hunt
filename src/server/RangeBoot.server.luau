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
local Workspace = game:GetService("Workspace")
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

-- THE RANGE IS SILENT (design 7.4, step B7). Six animals in one corridor would play six footstep
-- loops and six snorts at one man's ear, and Roblox has no per-player sound for a server `Sound`.
-- A FULL clone with one value flipped: `newRuntime` merges only MODEL, SENSE and KINDS key by key
-- and assigns everything else wholesale (`ForestTestBoot`'s stated rule). Karen's to overrule.
local sound = table.clone(Boar.CONFIG.SOUND)
sound.ENABLED = false
world.config.SOUND = sound

local runtime = Boar.newRuntime(world)
runtime:run()

-- WHERE THIS RUNTIME'S TARGET WAS, for the task-305 rewind. **ADDED beside the drive's, not in
-- place of it** (`Weapon.addHistoryProvider`): the lobby has two runtimes and the single
-- replaceable slot belongs to `MatchBoot`. Without this the range had no rewind at all and every
-- shot passed through the target -- measured 0/6, round 1 finding 1.
Weapon.addHistoryProvider(function(instance, at)
	return runtime:cframeAt(instance, at)
end)

-- A SHOT IS *NOT* A SOUND HERE, and not wiring `Weapon.ShotFired` to this runtime's `hearShot` is
-- the whole mechanism -- no branch, no flag, no new state. In the drive every boar runs from a shot;
-- at a range that would bolt the target off the lane on the first one.

-- THE NARROW VIEW (`ForestTest.readOnlyBoars`' shape): five verbs and two readers, so `Range`
-- requires no owner and can never reach a method this list does not name.
local started = Range.start({
	enabled = true,
	world = Map.EXPECTED_WORLD,
	-- WHO IS IN THE SERVER (design 7.4): the DataModel read is the root's, the rule -- which
	-- station each man is at -- is the owner's. Without it the range releases nothing at all.
	players = function()
		return Players:GetPlayers()
	end,
	-- nil in DEV, which lays its own plate (`row.plate`) and has no ground to read.
	groundAt = groundAt,
	-- THE PLACE'S OWN TERRAIN, AND ONLY WHERE THE ROW ASKS FOR A CUT (design 8.2, step B8). Karen's
	-- OK of 2026-10-28 is what makes this legal: her Forest Test's terrain may be edited. It is an
	-- ARGUMENT and never a `GetService` inside the builder, which is what keeps every spec -- and
	-- the DEV place the harness runs in -- out of it.
	terrain = if RangeData.fillsTerrain(row) then Workspace.Terrain else nil,
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
		-- ONE STATION'S ANIMAL (task 306 B7): `clear` above is range-WIDE and this runtime holds
		-- all six, so a carcass or a species pick at one station used to take the other five.
		clearOne = function(id: string, reason: string?)
			return runtime:clearOne(id, reason)
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
		-- WHERE THE TARGET WAS WHEN THE SHOOTER DREW IT (task 308 bug 4): the SAME history ring the
		-- rewound cast above is judged against, so the board's miss gap and the hit agree.
		cframeAt = function(id: string, at: number)
			return runtime:cframeAtId(id, at)
		end,
		-- THE TRUNK, FOR THE SHOT'S IGNORE LIST (task 306 B5, design 4.3). The only reader is
		-- `Range.ignoredFor`; one Instance per target, and its zone parts are welded under it.
		rootOf = function(id: string)
			return runtime:rootOf(id)
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

-- A READ-ONLY CENSUS OF THE LANE (task 315, design 7.4). The pine that stood in the new footprint
-- is taken away by the LOBBY's sweep, so if the lobby does not build, a 105-stud spruce stands in
-- the firing fan and nothing says so. This writes nothing and removes nothing -- it turns "the lane
-- is clear" into a number instead of a belief. A print is not a second writer.
--
-- IT IS DELAYED, AND THAT IS A MEASUREMENT RATHER THAN A PRECAUTION. `RangeBoot` and
-- `ForestTestBoot` are two Scripts in no defined order; run inline it printed **3 foreign
-- BaseParts** in Karen's place while the pine was in fact taken away a moment later (measured
-- 2026-10-30, the first live run of this task). A census that beats the sweep is a census that
-- lies, so it is taken once the server has settled. `task.delay` is not a writer either.
task.delay(8, function()
	local box = RangeData.footprintFor(Vector3.new(row.x, 0, row.z), RangeData.LAYOUT, RangeData.downrangeOf(row))
	do
		local count, nearestName, nearestAt = 0, "none", nil
		for _, folder in ipairs(Workspace:GetChildren()) do
			if
				folder:IsA("Folder")
				and folder.Name ~= RangeData.FOLDER_NAME
				and folder.Name ~= RangeData.TARGETS_FOLDER
			then
				for _, thing in ipairs(folder:GetDescendants()) do
					if thing:IsA("BasePart") then
						local at = thing.Position
						if at.X >= box.minX and at.X <= box.maxX and at.Z >= box.minZ and at.Z <= box.maxZ then
							count += 1
							if nearestAt == nil then
								nearestName, nearestAt = thing:GetFullName(), at
							end
						end
					end
				end
			end
		end
		print(
			string.format(
				"[RangeBoot] footprint census: %d foreign BaseParts, nearest %s at (%s, %s)",
				count,
				nearestName,
				if nearestAt then string.format("%.0f", nearestAt.X) else "-",
				if nearestAt then string.format("%.0f", nearestAt.Z) else "-"
			)
		)
	end
end)

-- ONE ANIMAL IN ONE SHOT'S WORLD (task 306 B5, design 4.3). Six bodies share one corridor, and
-- `Cast.candidates` returns the EIGHT nearest the muzzle while `Rewind.impact` takes the nearest
-- rewound one -- so without this a body the shooter cannot see stops his bullet. Wired here and
-- only here: unwired, `ignoreFor` is today's two-entry list.
Weapon.setIgnoreProvider(function(player, rewindSeconds)
	return Range.ignoredFor(player, rewindSeconds)
end)

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

-- HE IS ON THE MAT: SEND HIM THE LISTS (task 308 bug 1). MEASURED in Karen's place on 46cbd787 --
-- standing on the mat, before any request, `boardPushes=0` and all six menu strips had zero
-- children -- so the first real E drew six labels and no chips, and nothing but a blind click on
-- RELEASE THE TARGET or RESET filled them. The edge is read HERE because `Range` reaches no
-- DataModel and holds no player list; `Range.look` decides whether it publishes.
--
-- THE EDGE IS THE FIRING POSITION AND NOT ONLY "ON THE RANGE" (306k item 4). The bench and the deck
-- are the SAME station, so a man climbing his own ladder crossed no edge and his record kept the
-- bench's `position` -- and the menu he opened on the deck printed the bench's distances and lit the
-- bench's chip, 125 where the board says 139. The word is read here for the same reason the boolean
-- was: `Range` reaches no DataModel and holds no player list.
local onMat: { [number]: string } = {}
local function matEdges()
	for _, player in ipairs(Players:GetPlayers()) do
		local spot, word = Range.positionOf(player)
		-- A REAL FIRING POSITION, NEVER THE BAND BETWEEN THEM (review round 1, finding 2): `word` is
		-- nil for a man at the station but on neither, and `"2:nil"` would be an edge of its own --
		-- one every walk to the ladder crosses twice.
		local here = if spot ~= nil and word ~= nil then tostring(spot) .. ":" .. tostring(word) else nil
		if here ~= nil and here ~= onMat[player.UserId] then
			Range.look(player)
		end
		onMat[player.UserId] = here
	end
end

-- A RECORD LEAVES WITH ITS PLAYER (round 1, finding 2).
Players.PlayerRemoving:Connect(function(player)
	Range.forget(player)
	-- ...and the mat edge goes with him, or a man who left standing on it leaves a `true` behind.
	onMat[player.UserId] = nil
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
	matEdges()
end)
