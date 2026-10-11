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
-- THE START SWITCH LIVES HERE (task 153): an attribute on `ServerStorage`, read once per join. See
-- `ForestTest.START_ROLE_ATTRIBUTE` for why it is an attribute and not a file.
local ServerStorage = game:GetService("ServerStorage")

local Map = require(ReplicatedStorage:WaitForChild("Map"))

if Map.EXPECTED_WORLD ~= "forest-test" then
	return
end

-- THE HORN'S NUMBERS (task 152): how far a blast carries, and which team carries one. The behaviour
-- is `Weapon.Horn`'s and the animals are `Boar`'s; this root only wires them together.
local HornData = require(ReplicatedStorage:WaitForChild("Horn"))

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
-- THE OUTFIT (task 151). `Match.Body` is the one writer of what a character wears, in this world as
-- in the real one, and `Match.CONFIG` is where the `ORANGE_OUTFITS` flag is read -- once, by its own
-- owner. This root passes that config inward and never reads the flag itself: a second boundary read
-- would be a second answer (`docs/design/beater-kit.md` section 9).
local Match = require(ServerScriptService:WaitForChild("Match"))
local Body = Match.Body
-- THE HIT RECORD (task 124). It is wired here, at the composition root, exactly as the boar runtime
-- and the weapon are: `HitLog` requires neither of them and neither requires it.
local HitLog = require(ServerScriptService:WaitForChild("HitLog"))
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
-- ...AND SO IS THE PACE (task 123 round 2). Karen, after playing this world: *"they seems walking to
-- fast / they has to trot or walk when spook then fast"*. `Boar.CONFIG.PACE` makes a pushed animal
-- WALK and a spooked one RUN; it is born off because it changes what a fleeing boar does and the DEV
-- drive is a world of fleeing boars that she has already signed off. A full clone with one value
-- flipped, for the same reason as MODEL and CALM: the block is replaced wholesale, not merged.
local pace = table.clone(Boar.CONFIG.PACE)
pace.ENABLED = true
-- ...AND THE GAIT BAND FOLLOWS THE SLOWER FLIGHT (task 123 round 4). Karen: *"when they fleet make
-- speed slover it's to fast"*. `PACE.RUN_SPEED` is 24 and `MODEL.RUN_FROM` is 28, so without this an
-- animal bolting at 24 would be DRAWN trotting. The same formula the module uses for the band, with
-- this world's run speed in it: (18 + 24) / 2 = 21.
model.RUN_FROM = (Boar.CONFIG.TROT_SPEED + pace.RUN_SPEED) / 2

-- ...AND HOW A DRIVEN SOUNDER MOVES (task 126). Karen, after watching this world: *"it could be
-- lines of boars like in real life"*, *"they shouldn do circles like I see now"*, *"when I shoot it
-- runs awai a lot until I can;t see them"*, *"and not hitting the trees and hang"*. `Boar.CONFIG.MOVE`
-- is the file, the edge stop, the straight flight, the turn budget and the speed-scaled whisker; it
-- is born off for the same reason `PACE` is -- it changes what every animal does -- and it is turned
-- on here, by the world that asked for it, as a full clone with one value flipped because the block
-- is replaced wholesale rather than merged.
local move = table.clone(Boar.CONFIG.MOVE)
move.ENABLED = true

-- ...AND WALKING WHERE THE DRIVE SAYS (task 127). Karen: *"imagine they come from one side in one
-- line and crossing road thats it"*. `Boar.CONFIG.LINE` is the mode in which an animal stops deciding
-- and simply walks to the point it was given; the drive computes the route and the trail. Born off,
-- turned on here, a full clone with one value flipped like every block before it.
local lineMode = table.clone(Boar.CONFIG.LINE)
lineMode.ENABLED = true

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
	PACE = pace,
	MOVE = move,
	LINE = lineMode,
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
	-- BOTH ENDS OF THE SHOT (task 149b): the bang at the muzzle and the strike at the far end,
	-- each with its own radius. `shot.at` is nil for any caller older than this task.
	runtime:hearShot(shot.muzzle, shot.at)
end)

-- A HORN IS A PUSH (task 152), and this line is `MatchBoot`'s verbatim, for the same reason the two
-- above it are: the horn's contract does not change with the world. Karen plays in THIS place, so
-- this is the wire her `/beater` blast actually travels down.
Weapon.Horn.Blown:Connect(function(blast)
	-- ...AND IN THIS WORLD IT LATCHES (task 154). Karen, 2026-10-11: *"horn reach is further once
	-- they hear also run without stop"*. The `true` is the one-way flight of task 150 -- the same
	-- one a beater's own walk now asks for (`ForestTest.spookNearBeaters`) and the same one a heard
	-- shot has always asked for -- and it is decided HERE, at the composition root, because how
	-- long a fright lasts is the WORLD's question: `MatchBoot` does not pass it, so the drive's own
	-- horn is bit-for-bit what task 152 shipped until the rotation task says otherwise.
	local pushed = runtime:hearHorn(blast.at, HornData.spookStuds(HornData.CONFIG), true)
	-- ONE LINE PER BLAST, and it is the evidence. "The horn had no visible effect" is the kind of
	-- claim that needs a number beside it, so the console says how many animals the blast reached.
	print(
		string.format(
			"[ForestTest] horn blown at (%.0f, %.0f, %.0f): %d boar(s) pushed within %.0f studs (%d m)",
			blast.at.X,
			blast.at.Y,
			blast.at.Z,
			pushed,
			HornData.spookStuds(HornData.CONFIG),
			HornData.CONFIG.SPOOK_M
		)
	)
end)

Weapon.HitReported:Connect(function(report)
	if report.target:IsA("BasePart") then
		local shooter = report.shooter
		local character = shooter and shooter.Character
		local root = character and character.PrimaryPart
		-- THE RECORD, BESIDE THE DAMAGE AND NOT INSTEAD OF IT (task 124). `HitReported` is already one
		-- report per (shot, target), so nine pellets on one boar are one dot and not nine.
		HitLog.recordHit(report)
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
	-- ...AND THE DEATH. `HitLog` turns this into the kill line everybody sees and the row the report
	-- draws; `Weapon.markHit` below is still what puts the KILL marker on the shooter's screen.
	HitLog.recordDown(record)
	local userId = record.killedByUserId
	local shooter = if userId then Players:GetPlayerByUserId(userId) else nil
	if shooter then
		Weapon.markHit(shooter, "kill", record.killingZone)
	end
end)

-- ---------------------------------------------------------------- the gun

-- A HUNTER CARRIES AND A BEATER DOES NOT, AND SINCE TASK 157 THE DRIVE IS WHAT SAYS SO.
--
-- IT WAS `HornData.gunFor(Body.teamOf(player))`, and for these two teams that is the same answer
-- `Match.mayCarryWeapon` gives (a Shooter carries; a Driver carries only if `DRIVERS_MAY_SHOOT`,
-- which is false). What the drive knows and `gunFor` cannot is the other two halves of the question:
-- nobody is armed in `Waiting` -- before a drive exists -- and a hunter who has been TIED to her
-- stand loses her gun until the drive ends. Two policies answering one question is the bug task 154
-- was fixing when it wrote this line (`Horn.gunFor`'s own header says so), so there is one now.
--
-- `HornData.gunFor` keeps its file and its spec; this world simply stops calling it. The horn's carry
-- policy below still reads `Player.Team`, which the drive writes.
-- Design: docs/design/forest-drive.md section 8.1
Weapon.setArmingPolicy(Match.mayCarryWeapon)

-- ...AND THIS WORLD HAS A DRIVE LINE NOW, which is `MatchBoot`'s line verbatim.
--
-- WHAT WENT, AND WHY THE OLD COMMENT WAS RIGHT UNTIL TODAY: `noDriveLine` returned nil because *"the
-- safety arc exists to protect drivers. There are no drivers in this world -- the beaters are
-- phantoms with nobody standing on them"*. The real drive puts REAL beaters here, so that sentence is
-- gone rather than left standing (archived with the rest of it in
-- `backups/2026-10-11_task157_forest_roles_and_placement.txt`).
--
-- IT CANNOT COST KAREN A SHOT WHILE SHE PLAYS ALONE. The arc only PUBLISHES -- `Weapon` fires
-- `SafetyViolated` and `Match.Penalty.judge` then has to find a REAL driver within
-- `SAFETY_MISS_STUDS` of the shot's own path, and `Match.playerDrivers` filters every phantom out by
-- its non-numeric id. With nobody else in the world the verdict is always "no".
-- Design: docs/design/forest-drive.md section 6.2
Weapon.setDriveLineProvider(Match.driveLine)

-- ---------------------------------------------------------------- the role, and the outfit
--
-- KAREN ASKS FOR A ROLE AND THE DRIVE GIVES IT (task 157). She types `/beater` (and `/hunter` back),
-- or the Director sets `DHForestStartRole` before she presses Play. It is still a DEV COMMAND in a
-- playtest world: server-only, no remote, no input binding, no client module, no camera.
--
-- WHAT CHANGED IS WHO HONOURS IT. Until today this root called `Body.setTeam` itself, which with the
-- real drive here would not merely be a second decider -- it would not WORK: `Match` reads
-- `state.assignment`, not `Player.Team`, so a player dressed as a beater would still be a shooter to
-- the drive (armed, push-credited, unprotected by the safety rule). So the ask is recorded as a
-- one-shot REQUEST (`ForestTest.requestRole`) and `Match.requestTeam` is what moves her -- which
-- respawns her at the beater start, dresses her, hands her the horn and takes her gun, all through
-- the drive's own effects.
-- Design: docs/design/forest-drive.md section 5.2
--
-- `Body.ensureTeams()` is gone from here: `Match.start` does it, idempotently.

-- EVERYONE IN THIS WORLD IS A BEATER IF THE DRIVE SAYS THEY ARE. `Body.teamOf` reads `Player.Team`,
-- which `Match.Body.setTeam` is still the only writer of -- so the horn and the orange vest can
-- never disagree about whether Karen is a beater.
--
-- THE FLAG IS READ ONCE, HERE, exactly as `MatchBoot` reads it -- except that THIS world turns it ON
-- the way it turns `BOAR_MODEL` and the rest on: Karen plays here to judge the thing, and a playtest
-- world that hands her nothing to judge is no use. The DEV drive keeps the declared default.
-- HOW LONG THE START LINE WAITS FOR THE RESPAWN TO SETTLE. `Body.place` pivots on
-- `CharacterAdded` and `Body.settle` pivots again on the next frame, so anything over a frame is
-- enough; one second is long enough to be obviously enough and short enough to read as "at the
-- start".
local PLACEMENT_SETTLE_SECONDS = 1

local hornOn = true
Weapon.Horn.setCarryPolicy(function(player)
	return HornData.carriesFor(hornOn, Body.teamOf(player))
end)
Weapon.Horn.start()

-- WHERE EACH ROLE STANDS, AND WHICH WAY SHE LOOKS -- as an ANSWER, not as a write (task 157).
--
-- `Match.Body.place` is the one writer of where a character stands, in this world as in the DEV one;
-- this closure only chooses the spot, and it is handed to `Match.start` as `world.placement`. Task
-- 153's geometry is kept byte for byte: it is the same `beaterStartPosition` (which measures the
-- ground with `terrainYAt` and the trunks with `roomToStand`) and the same look down the push at the
-- road.
--
-- A HUNTER GOES THROUGH `Body.placementFor`, so `STAND_HEIGHT_STUDS`, the post's own half-height and
-- the facing (+Z, north, up the drive) are one rule in both worlds. What this adds is WHICH post:
-- `ForestTest.standIndexFor` is centre-out, so a solo hunter gets stand 5 -- the stand
-- `hunterStandX()` aims every wave at -- instead of `posts[1]`, 600 studs west of the push.
--
-- WHY A BEATER DOES NOT GO THROUGH IT: `placementFor` faces a driver straight -Z, and this road is a
-- sine whose tangent swings +-23 degrees (`atan(30/70)`), so the generic look would be up to 23
-- degrees off the push.
-- Design: docs/design/forest-drive.md section 4.3
local function placement(markers, team, index, cfg)
	if team ~= Data.PUSH_TEAM then
		-- THROUGH THE POST'S NAME AND NOT ITS PLACE IN THE LIST: a stand whose ground was refused is
		-- not in `markers.posts` at all (MEASURED: one run came back `8/9 stands (1 refused)`), and
		-- `placementFor` indexes modulo the length -- so the fifth entry of eight is not stand 5,
		-- while the drive goes on aiming every wave at stand 5's x.
		local stand = ForestTest.standIndexFor(index)
		return Body.placementFor(markers, team, ForestTest.postIndexFor(markers.posts, stand), cfg)
	end
	local at = ForestTest.beaterStartPosition()
	local road = Data.roadPointAt(at.X)
	return CFrame.lookAt(at, Vector3.new(road.X, at.Y, road.Z))
end

-- ---------------------------------------------------------------- the drive

-- THE REAL DRIVE, IN THIS WORLD, ON THIS WORLD'S GEOMETRY (task 157). The pattern is "the world
-- provides; the owner decides", and `Match` decides everything it decided before:
--
--   markers   a FUNCTION, because this geometry is raycast off the terrain: a table captured at boot
--             would be a measurement taken before the place had finished loading. `Match` calls it
--             on exactly the two occasions it re-reads tags in DEV -- once a second while `Waiting`,
--             and once on entering `Assigning`.
--   placement the closure above.
--   config    two scalars off `Match.WORLD_OVERRIDABLE`: this world's own drive length, and NO
--             RELEASES -- `BOARS_PER_DRIVE = 0` makes `Phase.maybeRelease` return on its first
--             predicate, so the drive asks for no animal and `ForestTest` stays the one owner of
--             when one exists.
--   boars     a READ-ONLY view (`ForestTest.readOnlyBoars`): the two signals and three counts, with
--             no `spawn`, `spawnSounder` or `clear`. That is what lets the drive SCORE the animals it
--             does not own -- and what stops `applyClearBoars` wiping the wood at a drive boundary,
--             because its `if world.boars.clear` is simply false.
Match.start({
	boars = ForestTest.readOnlyBoars(runtime),
	weapon = Weapon,
	markers = function()
		return ForestTest.Markers.build(ForestTest.hunterStandX())
	end,
	placement = placement,
	config = {
		DRIVE_SECONDS = Data.DRIVE.seconds,
		BOARS_PER_DRIVE = 0,
	},
	now = function()
		return os.clock()
	end,
})

-- THE REPORTING WINDOW IS THE DRIVE, in this world as in the DEV one (task 157): `MatchBoot`'s two
-- lines verbatim. The Heartbeat latch on `ForestTest.drive(...).index` is archived with the rest.
-- Both `HitLog` calls are idempotent at the other end, so a phase that fires twice cannot open two
-- drives.
Match.PhaseChanged:Connect(function(_before, phase, driveNumber)
	if phase == "Assigning" then
		HitLog.openDrive(driveNumber or 1, os.clock())
		print(string.format("[report] drive %d opened (%ds windows)", driveNumber or 1, Data.DRIVE.seconds))
	elseif phase == "Scoring" then
		HitLog.closeDrive(os.clock())
	end
end)

-- THE STAND PICK IS THE HUNTER'S TEN SECONDS, and it opens when the DRIVE starts (task 157).
--
-- It used to open on `CharacterAdded`, which is now the drive's own respawn -- and opening it there
-- would start the clock while the intermission still ran. On entering `Running` everybody has been
-- placed, so the window is the first ten seconds of the drive: she lands on her stand, walks a few
-- steps, and whatever she is standing on at the end is hers.
local function openPickFor(player: Player)
	if ForestTest.roleOfPlayer(player) ~= "hunter" then
		return -- a beater has no stand, and no leash (`ForestTest.leash` refuses her for the same reason)
	end
	ForestTest.openPick(player.UserId, os.clock())
	task.delay(Data.PICK.seconds, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if player.Parent == nil or root == nil then
			return
		end
		-- ...UNLESS THE DRIVE HAS MOVED HER SINCE. Locking a stand for a beater would put a hunter in
		-- `ForestTest.hunterStandX` who is not standing there, and the drive aims every wave at it.
		if ForestTest.roleOfPlayer(player) ~= "hunter" then
			return
		end
		local index = ForestTest.lockPick(player.UserId, (root :: BasePart).Position, os.clock())
		print(string.format("[ForestTest] %s took stand %d", player.Name, index))
	end)
end

-- HONOURS A PENDING ROLE REQUEST, through the drive. One-shot: `takeRequest` clears it, so the same
-- ask cannot be honoured twice and cannot defeat the next drive's swap.
local function honour(player: Player)
	local word = ForestTest.pendingRequest(player.UserId)
	if word == nil then
		return
	end
	if ForestTest.roleOfPlayer(player) == word then
		ForestTest.takeRequest(player.UserId) -- she is already on that side; nothing to ask for
		return
	end
	if Match.requestTeam(player, Body.teamForWord(word)) then
		ForestTest.takeRequest(player.UserId)
		ForestTest.clearPick(player.UserId)
		print(string.format("[ForestTest] %s is now a %s (team=%s)", player.Name, word, tostring(Body.teamOf(player))))
	end
end

-- ONE HANDLER FOR THE DRIVE'S OWN BOUNDARIES: what a new intermission drops, and what the start of a
-- drive opens.
Match.PhaseChanged:Connect(function(_before, phase)
	if phase == "Assigning" then
		-- EVERY PICK IS DROPPED AT THE START OF AN INTERMISSION: teams have just been swapped, so a
		-- stand locked by somebody who is now a beater would aim every wave at a stand nobody is on.
		for _, player in ipairs(Players:GetPlayers()) do
			ForestTest.clearPick(player.UserId)
		end
		return
	end
	if phase ~= "Running" then
		return
	end
	-- A REQUEST MADE BETWEEN DRIVES IS HONOURED HERE, not in `Assigning`: that phase respawns
	-- everybody already, and honouring inside it would be a second `LoadCharacter` for the same
	-- player in the same intermission. The cost is one extra respawn for the player who asked, at the
	-- instant the drive starts, and it is stated rather than discovered.
	for _, player in ipairs(Players:GetPlayers()) do
		honour(player)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		openPickFor(player)
	end
	-- WHAT THE MARKERS MEASURED, once per drive: nine stands or fewer, how many the ground refused,
	-- and the worst disagreement between the two readings of it. This is the line that says "the drive
	-- is standing on this world" rather than hoping it is.
	local stats = ForestTest.Markers.stats()
	print(
		string.format(
			"[ForestTestBoot] markers: %d/%d stands (%d refused), max ground delta %.2f, reads=%d",
			stats.posts,
			Data.STAND_COUNT,
			stats.refused,
			stats.lastMaxDelta,
			stats.reads
		)
	)
end)

-- ONE LINE PER START, AND IT IS PRINTED WHEN THE CHARACTER HAS ACTUALLY LANDED (task 157).
--
-- IT USED TO BE PRINTED FROM THE PHASE HANDLER, and round 1 of this task measured what that was
-- worth: `Body.place` respawns her and pivots on `CharacterAdded`, so a line printed in the same
-- frame reads the position of the character she is ABOUT TO LEAVE -- it said *"starts as a beater
-- ... 0 studs from the road"* while the drive had chosen a point 240 studs north. The honest moment
-- is after the respawn, so this waits for one.
--
-- IT WRITES NOTHING. `Match.Body` is still the only thing that moves a character; this reads the
-- position it ended up in and says what the role was, which is the only channel a tool outside the
-- server has (an MCP `require` of this module answers with a sandboxed copy -- measured, task 122).
local function reportStart(player: Player, character: Model)
	task.delay(PLACEMENT_SETTLE_SECONDS, function()
		local root = character.PrimaryPart
		if character.Parent == nil or root == nil then
			return
		end
		local at = root.Position
		print(
			string.format(
				"[ForestTest] %s is a %s at (%.0f, %.0f, %.0f), %.0f studs from the road (settled=%d)",
				player.Name,
				ForestTest.roleOfPlayer(player),
				at.X,
				at.Y,
				at.Z,
				at.Z - Data.roadZ(at.X),
				Body.settled()
			)
		)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		reportStart(player, character)
	end)
	-- WHICH ROLE SHE STARTS AS (task 153, and a request since 157). Karen: *"how to start a game as a
	-- beter?"* -- so Play itself can put her on the drive side with nothing typed, when the Director
	-- has set the switch. Nothing set means the hunter this world has always started her as, which is
	-- also what the roster gives a solo player (`ODD_PLAYER_TEAM`).
	local startRole = ForestTest.startRole(ServerStorage:GetAttribute(Data.START_ROLE_ATTRIBUTE))
	if startRole ~= nil then
		ForestTest.requestRole(player.UserId, startRole)
		print(string.format("[ForestTest] %s asked to join as a %s (start switch)", player.Name, startRole))
	end

	player.Chatted:Connect(function(message)
		local role = ForestTest.parseRole(message)
		if role == nil then
			return
		end
		ForestTest.requestRole(player.UserId, role)
		-- HONOURED NOW IF THERE IS A DRIVE TO HONOUR IT IN, and otherwise at the next `Running`. The
		-- answer comes from the drive, so a request typed in `Waiting` is not silently lost and not
		-- silently applied either.
		honour(player)
		if ForestTest.pendingRequest(player.UserId) ~= nil then
			print(
				string.format(
					"[ForestTest] %s asked to be a %s; the drive is %s, so it happens when the next one starts",
					player.Name,
					role,
					Match.phase()
				)
			)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	ForestTest.clearPick(player.UserId)
	-- THE REQUEST GOES WITH THE PLAYER. `Body.forget` is no longer called here: `Match.forget` runs
	-- in this world now and calls it, so one caller instead of two.
	ForestTest.clearRequest(player.UserId)
end)

-- ---------------------------------------------------------------- the loop

-- ONE HEARTBEAT FOR BOTH JOBS: the schedule and the leash. The boar runtime runs its own, and the
-- drive runs its own; this is only the playtest's own clock.
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
		-- ...AND WHAT THE RESTING GROUPS ARE DOING (task 154). Same channel and same reason as the
		-- wave report above it: "they ran away from her and did not stop" is the kind of claim that
		-- needs a number beside it, and a tool that requires this module over StudioMCP gets a
		-- sandboxed copy with empty state (measured, task 122).
		for _, report in ipairs(ForestTest.restReport(now)) do
			print("[rest] " .. report)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			-- THE ROLE IS PASSED IN SINCE TASK 157: the truth of it is `Player.Team`, and this loop is
			-- what holds the `Player` -- `ForestTest` keys by `userId` and never holds one.
			ForestTest.leash(player.UserId, root :: BasePart, ForestTest.roleOfPlayer(player))
		end
	end
end)

HitLog.start()
ForestTest.start(runtime, os.clock())
