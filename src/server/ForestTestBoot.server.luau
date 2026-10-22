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
-- THE LOBBY'S TERRAIN IS AN ARGUMENT AND NEVER A GLOBAL REACH (task 177): this root hands
-- `Workspace.Terrain` to `Lobby.start`, so no spec can write a place's terrain by accident.
local Workspace = game:GetService("Workspace")
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
-- THE BOTS THAT FILL THE DRIVE (task 161). Karen plays HERE and she plays SOLO, so this is the world
-- the feature exists for: without it a drive is one person in an empty wood. A fourth owner, wired
-- here exactly as the boar runtime and the weapon are -- `Bots` requires no owner and no owner
-- requires it.
local Bots = require(ServerScriptService:WaitForChild("Bots"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
-- THE OUTFIT (task 151). `Match.Body` is the one writer of what a character wears, in this world as
-- in the real one, and `Match.CONFIG` is where the `ORANGE_OUTFITS` flag is read -- once, by its own
-- owner. This root passes that config inward and never reads the flag itself: a second boundary read
-- would be a second answer (`docs/design/beater-kit.md` section 9).
local Match = require(ServerScriptService:WaitForChild("Match"))
local Body = Match.Body
-- THE SEAT DEAL (task 221): which hunter gets which stand when a seat is a thing you buy.
local HighSeats = require(ReplicatedStorage:WaitForChild("HighSeats"))
-- THE HIT RECORD (task 124). It is wired here, at the composition root, exactly as the boar runtime
-- and the weapon are: `HitLog` requires neither of them and neither requires it.
local HitLog = require(ServerScriptService:WaitForChild("HitLog"))
-- A PLAYER'S COINS AND HIS SAVED PROFILE (task 170). The fifth owner, wired here exactly as the
-- boar runtime, the weapon, the bots and the hit record are: `Economy` requires no owner and no owner
-- requires it. The drive is handed a narrow VIEW (`Economy.view()`) -- three functions, no `start`,
-- no `stop`, no store and no setter -- so the drive cannot open a ProfileStore session, cannot write
-- a balance and cannot see the library.
local Economy = require(ServerScriptService:WaitForChild("Economy"))
-- THE LOBBY (task 177). KAREN, 2026-10-13: *"I think after this fixes we need to focus on lobby /
-- Hunting house where inside can shop things / outside is fields and forrest so house is in fields
-- next to forrest"*. The sixth owner, wired here exactly as the boar runtime, the weapon, the bots,
-- the hit record and the coins are: `Lobby` requires no owner and no owner requires it.
local Lobby = require(ServerScriptService:WaitForChild("Lobby"))
-- THE SHOP (task 178): its own owner, wired the way `Economy` and `Lobby` above are. It owns the
-- DOOR and nothing else -- `Economy.purchase` is the only writer of a purchase, and
-- `Lobby.counterPosition` is the one definition of where the counter is.
local Shop = require(ServerScriptService:WaitForChild("Shop"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
-- WHAT THE LODGE HANGS ON ITS WALLS (task 196): the boar's own model and the two guns the player
-- carries. Required HERE, in the composition root, because that is where a name in one owner's
-- vocabulary is translated into another owner's asset -- the `Body.setAccessorySource` seam's own
-- rule. `Lobby` never learns what an asset key is and `Match.Body` never learns what a shop is.
local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
-- THE FOUR PLACES' OWN FOREST (task 193). The seventh owner, wired exactly as the six above are:
-- `Places` requires no owner and no owner requires it. It is the ONE writer of
-- `Workspace.DrivePlaces` and it reads a layout from `ForestTest.Data` -- never the other way round.
local Places = require(ServerScriptService:WaitForChild("Places"))
local Data = ForestTest.Data

print(
	string.format(
		"[ForestTestBoot] world=%s place=%d: layouts %s, waves every %ds",
		Map.EXPECTED_WORLD,
		game.PlaceId,
		table.concat(Data.layoutNames(), "/"),
		Data.SCHEDULE.intervalSeconds
	)
)

-- ---------------------------------------------------------------- the four places

-- KAREN'S FOUR PLACES, PLANTED ONCE, BEFORE ANYTHING ELSE RUNS. Her 2026-10-15: *"make 4 hunting
-- places where each time person will be in new place when is hunter then loop it again"*.
--
-- BEFORE THE BOARS AND BEFORE THE DRIVE, and that is the ordering that matters: a boar released into
-- a place whose wood arrived afterwards would have pathfound across ground that then grew trees. The
-- navmesh is rebuilt in the background (`tools/mapgen.py`'s own measurement: a wall thrown across a
-- corridor still answered `PathStatus.Success` one second later and `NoPath` after five), so the
-- trees go in first and the first wave is a minute away.
--
-- ONE LINE, AND IT CARRIES THE COUNTS Karen's *"not fake it or broken"* is checked against: how many
-- went in, how many were refused for want of ground, and how many were refused because their
-- footprint lay across a step (`TreeGround.CLIFF_STUDS`).
-- THE READER IS TERRAIN ONLY AND IT IS HANDED IN HERE (design 10.1). `ForestTest.terrainYAt` lives on
-- the SERVER owner of this world, which is why the composition root is where the two meet: the
-- planter learns nothing about `Workspace.Terrain` and `ForestTest` learns nothing about planting.
local planted = Places.build(ForestTest.terrainYAt, nil, workspace.Terrain)
print(
	string.format(
		"[ForestTestBoot] places: %d dressed, %d planted (%d parts), %d skipped, %d on a step, %d missing, %d paint call(s), %.2fs%s",
		planted.places,
		planted.planted,
		planted.parts,
		planted.skipped,
		planted.cliff,
		planted.missing,
		planted.paints,
		planted.seconds,
		if planted.reason then " (" .. tostring(planted.reason) .. ")" else ""
	)
)

-- ---------------------------------------------------------------- the boars

-- THE FIELD IS THIS WORLD'S, not the generated map's. `Boar.CONFIG.field` describes block 1 of a
-- map that does not exist in this place, and `Brain:_outcome` despawns a boar at
-- `position.Z <= exitZ` -- so with the map's exitZ an animal here would either never be gone or be
-- gone the moment it spawned.
--
-- ...AND SINCE TASK 179 IT IS THE LIVE LAYOUT'S, not a table built once at boot. The formula is
-- unchanged and has moved into `Data.fieldFor` so the one definition can be asked for any layout:
-- `Data.fieldFor(Data.ROAD_LAYOUT)` is bit-for-bit the table this file used to build, and
-- `forest_stand.spec` asserts that identity rather than trusting it. `ForestTest` swaps it on the
-- runtime (`Runtime:setField`) when a drive promotes a new layout, because a ride's exit line is
-- 473 studs south of the road's.
local field = Data.fieldFor(ForestTest.layout())

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
	local pushed, ids = runtime:hearHorn(blast.at, HornData.spookStuds(HornData.CONFIG), true)
	-- ...AND THE BEATER IS PAID FOR THEM IF ONE IS SHOT INSIDE THE WINDOW (task 160). Karen plays
	-- in THIS place, so a beater ranking that only worked in the DEV drive would be a beater ranking
	-- she never sees. `Match.creditPush` is the drive's own door and refuses everything that is not
	-- a beater of a live drive, so in a Forest Test session with no drive running it is a no-op.
	local credited = Match.creditPush(blast.blowerUserId, ids)
	-- ONE LINE PER BLAST, and it is the evidence. "The horn had no visible effect" is the kind of
	-- claim that needs a number beside it, so the console says how many animals the blast reached.
	print(
		string.format(
			"[ForestTest] horn blown at (%.0f, %.0f, %.0f): %d boar(s) pushed within %.0f studs (%d m), %d credited",
			blast.at.X,
			blast.at.Y,
			blast.at.Z,
			pushed,
			HornData.spookStuds(HornData.CONFIG),
			HornData.CONFIG.SPOOK_M,
			credited
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

-- ...AND THE THREE THE RULES NEED (task 171). The drive answers, the WEAPON refuses -- one gate, on
-- the server, in the one place a shot can come from (docs/research/2026-10-13-the-rules.md).
--   * what the aim ray hit: a beater (player on the push team, or a bot) or an animal's species
--   * where this player's stand circle is, or nil for "he has none"
-- KAREN, 2026-10-11: *"No penalty now we need simplify scope, thye just can't shoot them"*;
-- 2026-10-12: a hunter outside his circle *"CAN'T SHOOT until he steps in"*. Neither is a penalty.
--
-- THE LICENCE PROVIDER IS DELIBERATELY NOT WIRED. No deer exists, and a boar needs no licence
-- (`Licences.ROWS`), so with nothing wired the rule is reachable and inert -- which is exactly what
-- *"a per-species licence table, data-only for now"* asks for. The shop task wires it to the profile.
Weapon.setTargetProvider(Match.classifyTarget)
Weapon.setStandProvider(Match.standAreaFor)
-- ...AND THE FOURTH (task 174): IS THE DRIVE OPEN AT ALL. KAREN, 2026-10-13 ~09:35: *"for hunter
-- once hunt over (drive) horn anounce then I can; shoot anymore"*. The start horn opens the drive and
-- the end horn closes it, so the gun fires between the two signals and nowhere else -- through the
-- results scene and the next countdown the trigger does nothing, and what the player gets is the dry
-- click and `THE DRIVE IS OVER` on his readout. It is `Match.driveOpen`, the SAME predicate the
-- beater's horn is gated on below and the bot line's walk (`Match.botsMayGo`): one source, no second
-- clock.
Weapon.setDriveOpenProvider(Match.driveOpen)

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
local hornOn = true
Weapon.Horn.setCarryPolicy(function(player)
	return HornData.carriesFor(hornOn, Body.teamOf(player))
end)
-- ...AND WHO MAY STILL SOUND IT (task 168). KAREN, 2026-10-12 ~21:45: *"when beater cross the line of
-- hunter it's done for him cant use sound anymore"*. The DRIVE owns the answer, because "has he
-- crossed the hunters' line" is a fact about the drive's own geometry -- `Match.mayBlowHorn` reads
-- the record `Match.beaterCrossing` already takes once a tick, against the same `Match.crossedLine`
-- predicate that ends the drive. Injected, exactly as `setCarryPolicy` above and
-- `Weapon.setArmingPolicy(Match.mayCarryWeapon)` are: neither owner requires the other.
Weapon.Horn.setBlowPolicy(Match.mayBlowHorn)
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
--
-- `line` IS THE WHOLE HUNTER LINE (task 221) and it is why the seat deal lives HERE rather than in
-- `Match`: which stands carry a high seat is this world's geometry, and `Match` passes only how
-- many hunters there are and which of them paid. With no line -- the DEV place, a spec, any caller
-- that never heard of the argument -- `dealLine` is handed nil `entitled`, which is "nobody
-- answered", which is entitled, and the deal IS `standIndexFor` for every index.
local function placement(markers, team, index, cfg, line)
	if team ~= Data.PUSH_TEAM then
		-- WHICH STAND, DEALT FOR THE WHOLE LINE AT ONCE (task 221). A hunter who has not bought
		-- high-seat access is never given a seated stand while any stand he may stand on is free;
		-- a per-player rule could not promise that without putting two men on one circle.
		local deal = HighSeats.dealLine(
			ForestTest.standWalk(),
			ForestTest.seatedStands(),
			if line then line.entitled else nil,
			math.max(index, if line then line.count else index)
		)
		-- THROUGH THE POST'S NAME AND NOT ITS PLACE IN THE LIST: a stand whose ground was refused is
		-- not in `markers.posts` at all (MEASURED: one run came back `8/9 stands (1 refused)`), and
		-- `placementFor` indexes modulo the length -- so the fifth entry of eight is not stand 5,
		-- while the drive goes on aiming every wave at stand 5's x.
		local stand = deal[index] or ForestTest.standIndexFor(index)
		return Body.placementFor(markers, team, ForestTest.postIndexFor(markers.posts, stand), cfg)
	end
	-- BY INDEX SINCE TASK 167, exactly as a hunter's stand is. Karen: *"and seem like all bots came
	-- to me"* -- every beater was put on the one push line, so the bot line converged on her stand.
	-- `beaterStartPosition(index)` spreads them across the hunters' front and measures the ground and
	-- the trunks at each lane's own x; the look is still straight down the push at the road AT THAT
	-- x, so each of them walks its own lane and not a shared one.
	local at = ForestTest.beaterStartPosition(index)
	local road = Data.roadPointAt(at.X, ForestTest.layout())
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
-- THE BOTS (task 161), started BEFORE the drive, because `Match.start` dispatches its first phase
-- and the drive's `syncBots` runs at the end of it.
--
-- THE EXTRA SEAMS ARE THIS WORLD'S OWN SINGLE READERS: its terrain climbs 56 studs in 400 and it is
-- mostly ferns and leaf cards with `CanCollide = false`, so "where is the ground" is
-- `Data.groundAt`, "is there room for a body" is `ForestTest.roomToStand` and -- since task 208 --
-- "what is in the way between here and there" is `ForestTest.laneAhead`. All three are functions
-- this file hands on rather than versions of its own: `Markers.setReaders` and the boar world get
-- the first two as well. A second copy of any of them would be two definitions of one fact, which is
-- this project's named failure mode.
--
-- `dress` is `Match.Body.dress` -- the ONE owner of what a character wears, in this world as in the
-- real one -- and `horn` is `Weapon.Horn`'s, with `give` asking the horn's own `carriesFor` so who
-- carries one is not a new rule, and `blow` being `Horn.blowTool`, the one implementation of what a
-- blast is. A bot's blast therefore travels the exact wire Karen's `/beater` blast travels, with the
-- real reach and the real cooldown, and pays nobody (`blowerUserId = nil`).
Bots.start({
	dress = Body.dress,
	dressConfig = Match.CONFIG,
	horn = {
		give = function(rig, team)
			if not HornData.carriesFor(hornOn, team) then
				return nil
			end
			return Weapon.Horn.giveTo(rig)
		end,
		blow = Weapon.Horn.blowTool,
		-- HOW LONG A BLAST HOLDS THE HORN AT THE MOUTH (task 166). The HORN's own number, handed to
		-- the bots with the rest of its seam, so the arm raise and the Tool's `GRIP_BLOW` tilt are
		-- the same length by construction and not by two numbers agreeing.
		blowSeconds = HornData.CONFIG.BLOW_SECONDS,
	},
	groundAt = Data.groundAt,
	roomToStand = ForestTest.roomToStand,
	-- ANOTHER SEAM (task 208), and it is this world's THIRD single reader: "what is in the way
	-- between here and there, and how high is it". `ForestTest.laneAhead` sweeps a body down the
	-- lane with `Blockcast` and -- unlike `roomToStand`, which says in so many words that *a person
	-- is not an obstacle* -- it counts another BODY as something to walk round. That difference is a
	-- measurement: two bot beaters spent 34.0 s and 6.0 s pinned against anchored bot hunters
	-- standing on the stands their own lanes aim 20 studs past
	-- (`docs/research/2026-10-19-bots-unstuck.md` section 4.2).
	laneAhead = ForestTest.laneAhead,
	now = function()
		return os.clock()
	end,
})

-- WHAT A BOAR IN THIS WORLD CAN PERCEIVE ABOUT THE BOTS, as ONE injected source (task 161).
-- `ForestTest.boarThreats` appends it and decides the phantom suppression itself, off that live fact
-- -- so this root passes no new argument, its `world.threats` closure above is unchanged, and the
-- phantoms are retired only by the file that invented them.
ForestTest.setBotThreats(Bots.threats)

-- THE COINS (task 170), started BEFORE the drive: a player already on the server must have his
-- profile session open before the first dispatch, because a drive that ends with no session pays him
-- nothing and says so.
--
-- IT PRINTS WHICH STORE IT TOOK -- in Studio always the in-memory one, so no playtest and no harness
-- run can write a live DataStore key even with *Enable Studio Access to API Services* on.
Economy.start()

-- ---------------------------------------------------------------- what hangs in the lodge (196)
--
-- KAREN, 2026-10-16: *"we use our boar head and then add on a wall thats it"*, and *"behind the
-- shoper shotguns on wall rifles on wall ect"*.
--
-- ONE FUNCTION, ANSWERING THREE NAMES, memoised. The lodge asks for `"boar"`, `"shotgun"` and
-- `"rifle"` -- its own vocabulary, three words -- and gets a Model or nil. Nothing it is handed is
-- ever put in a player's hands: the lodge anchors every part of it and turns collision, queries and
-- touch off, which is what makes a wall of guns scenery rather than a shop you can rob.
--
-- THE BOAR IS THE ONE IN THE DRIVE. `Assets.KEYS.boarMale` is the same template `Boar` wears, so the
-- head on the wall is the animal the player shot and not a model of one -- and it costs no upload,
-- no credit and no moderation (Karen asked for exactly that).
--
-- THE GUNS ARE `Weapon.Hardware`'s OWN OUTPUT. It builds a Tool; a Tool cannot be moved as a unit,
-- so the Handle and everything welded to it is lifted into a Model whose PrimaryPart is that Handle
-- -- and from there `PivotTo` lays it on the rack. The Tool itself is destroyed here: nothing with a
-- `Tool` in its name reaches the lodge.
--
-- PRELOADED FIRST, AND THAT YIELD IS THE POINT: `Hardware.build` draws the measured FALLBACK BOXES
-- for a mesh that has not landed, and a rack of grey slabs is exactly what Karen has spent today
-- removing. `Loader.preload` is idempotent (it answers from the cache for a key already in), so
-- when `ViewmodelAssetsBoot` has already run this costs a table lookup; when it has not, the lodge
-- waits for the guns rather than hanging boxes.
local lodgeAssets: { [string]: any } = {}
local WEAPON_OF = { shotgun = "shotgun", rifle = "rifle" }

local function lodgeAsset(name: string): Instance?
	local known = lodgeAssets[name]
	if known ~= nil then
		return if known == false then nil else known
	end
	local made: Instance? = nil
	if name == "boar" or name == "sow" then
		-- THE SOW IS THE FOURTH WORD (the Designer's lodge spec, 2026-10-16, section 14c). Karen:
		-- *"you can make few more famale and one more male"*. `boar.female` is already in the
		-- manifest and the model measures 0.8553 of the male's length, so a sow trophy is a SMALLER
		-- head with smaller tusks and no scaling anywhere -- no upload, no new asset, no credit.
		local key = if name == "sow" then Assets.KEYS.boarFemale else Assets.KEYS.boarMale
		local template = Loader.template(key)
		made = if template ~= nil and template:IsA("Model") then template else nil
	elseif WEAPON_OF[name] ~= nil then
		local ok, tool = pcall(Weapon.Hardware.build, Weapons.row(WEAPON_OF[name]))
		if ok and typeof(tool) == "Instance" and (tool :: Instance):IsA("Tool") then
			local held = Instance.new("Model")
			held.Name = string.format("LodgeGun_%s", name)
			local handle = (tool :: Tool):FindFirstChild("Handle")
			for _, child in ipairs((tool :: Tool):GetChildren()) do
				child.Parent = held
			end
			if handle ~= nil and handle:IsA("BasePart") then
				held.PrimaryPart = handle :: BasePart
				made = held
			else
				held:Destroy()
			end
			(tool :: Tool):Destroy()
		end
	end
	lodgeAssets[name] = made or false
	return made
end

-- THE TWO ANIMALS THE WALL NEEDS, preloaded beside the guns for the same reason: `Loader.template`
-- never yields and answers nil until the load lands, and a lodge built in that window hangs bare
-- boards. `preload` is idempotent, so the male -- which `BoarAssetsBoot` loads anyway -- costs a
-- table lookup.
for _, loaded in ipairs(Loader.preload({ Assets.KEYS.boarMale, Assets.KEYS.boarFemale })) do
	if not loaded.ok then
		warn(string.format("[ForestTest] lodge: %s did not load (%s)", loaded.key, tostring(loaded.reason)))
	end
end

for _, loaded in ipairs(Loader.preload(Assets.keysFor("viewmodel"))) do
	if not loaded.ok then
		warn(string.format("[ForestTest] lodge: %s did not load (%s)", loaded.key, tostring(loaded.reason)))
	end
end

-- ---------------------------------------------------------------- the lobby (task 177)
--
-- THE LOBBY GOES FIRST, AND THE ORDER IS THE WHOLE SAFETY OF IT: the drive's enrolment switch
-- depends on whether the lobby actually built itself, so this file ASKS and only then takes the
-- drive's enrolment away. No lobby -- a world with no anchor row, the flag off, a seam missing, or
-- ground that cannot be read -- means `Lobby.start` returns false, and `Match` is started with no
-- `enrol` field at all, which is today's game: joining the server joins the drive.
--
-- THE FLAG IS TURNED ON HERE, THROUGH THE WORLD'S OWN CONFIG, the way this file already turns
-- `BOAR_MODEL`, `CALM`, `PACE`, `MOVE` and `LINE` on -- not through a live `DHFlag_` attribute,
-- which is not in git and is lost when somebody reopens the place. The cost is the same cost those
-- five already carry and it is stated rather than discovered: in THIS world the lobby cannot be
-- switched off with `tools/flags.py`, and the rollback is this one line.
--
-- EVERY SEAM IS INJECTED, so neither owner requires the other (design section 12.4):
--   enrol/dismissAll  the drive's two doors. `Lobby` never writes a roster.
--   inDrive/isHeld    the drive's two readers. `isHeld` is what stops the lobby respawning a man
--                     out of Karen's results scene.
--   place             `Match.Body.place` -- THE ONE WRITER of where a character stands, in this
--                     world as in the DEV one. `Lobby` chooses the CFrame and writes nothing, which
--                     is exactly what `world.placement` already does for the drive.
--   groundAt          this world's own single ground reader, the same one `Markers.setReaders`, the
--                     boar world and `Bots.start` are given. A third copy of "where is the ground"
--                     would be two definitions of one fact.
--   terrain           an argument, so no spec can write a place's terrain by accident.
local lobbyOn = Lobby.start({
	enabled = true,
	world = Map.EXPECTED_WORLD,
	enrol = Match.enrol,
	dismissAll = Match.dismissAll,
	inDrive = Match.isParticipant,
	isHeld = Match.isHeld,
	--   assignedTeam WHICH SIDE THE DRIVE HAS ACTUALLY GIVEN HIM, or nil (task 229). It is the ONE
	--                fact that spends a role wish, and it is a THIRD reader of the drive rather than
	--                a reuse of `inDrive` for a measured reason: `Lobby.depart` -> `Match.enrol`
	--                makes him a participant immediately, while the assignment that reads the wish
	--                happens on a LATER `Match` step -- so a wish cleared on `inDrive` would be gone
	--                before the assignment it was meant to change (`Lobby.wishFor`'s header).
	--                It is OPTIONAL in `Lobby.start`, like `depart` and `remotes`: a world that
	--                injects nothing never spends a wish, which is a world with no drive.
	assignedTeam = Match.assignmentOf,
	place = function(player, cframe)
		Body.place(player, cframe, Match.CONFIG)
	end,
	--   dress        `Match.Body.dress` -- the ONE owner of what anybody in this game wears, and the
	--                shopkeeper (task 181) is dressed by the same call the bots and the players are.
	--                `Lobby` never learns what an outfit is; it hands over a Model and a team.
	--   shopOn       the `SHOP` flag, read ONCE here and passed inward (CLAUDE.md, feature flags).
	--                It decides one thing: whether the keeper's prompt is live. With the shop off
	--                his panel is dead, and a "Press E" over a man who answers nothing is worse
	--                than no prompt at all.
	--
	--                IT CANNOT DISAGREE WITH `Shop.start`'s ANSWER BELOW, and the reason is the
	--                ORDER (task 233b). `Shop.start` is off when the flag is off or when this world
	--                has no counter -- and the counter is a part of the lodge this very call builds,
	--                so inside the build "there is a counter" is true by construction. The nil-counter
	--                arm is the arm where `Lobby.Build` never ran at all, and then there is no keeper
	--                to hang a prompt on. The flag cannot be read from `Shop.start` here instead:
	--                that call is 130 lines below, because it needs the counter this one makes.
	dress = Body.dress,
	dressConfig = Match.CONFIG,
	shopOn = ShopData.isOn(),
	--   assets       WHAT HANGS ON THE LODGE'S WALLS (task 196): the boar's head over the fire and
	--                the guns on the rack behind the counter, by name. See `lodgeAsset` above.
	assets = lodgeAsset,
	--   remotes      THE PADS' ONE INBOUND DOOR (task 182). `ReplicatedStorage.Lobby.Remotes`, handed
	--                in rather than found, for the reason every other seam here is handed in: a spec
	--                drives `Lobby.onPadRequest` by parameter with no remote at all, and nil means
	--                "there is no door" rather than a crash.
	--
	--                `depart` IS DELIBERATELY NOT INJECTED. It defaults to `Lobby.enrolHere` -- this
	--                server's own drive, through task 177's door -- and the reserved-server teleport
	--                (`ReserveServerAsync` + `TeleportToPrivateServer`) is the second implementation
	--                a published build would pass here. It is not built because Studio cannot test a
	--                teleport at all (docs/design/truck-pads.md section 9).
	remotes = Lobby.Data.remotes(),
	groundAt = Data.groundAt,
	--   terrainAt    WHERE THE TERRAIN IS, WHICH IS NOT THE SAME QUESTION (task 196 part 3d). Karen,
	--                2026-10-16: *"look at the trees wtf"* -- birches standing on their splayed
	--                roots with daylight under them. `Data.groundAt` rays past `OurForest`,
	--                `Foliage` and `Boars`, but its own header measures that this is not every
	--                tree: 831 more live in two Studio folders called `Session`, so a downward ray
	--                can stop on a canopy, and it can also stop on a road part or a fence. A TREE
	--                seated on a canopy is a tree standing on air. `ForestTest.terrainYAt` includes
	--                nothing but `Workspace.Terrain` and so can only ever answer "where is the
	--                ground".
	terrainAt = ForestTest.terrainYAt,
	terrain = Workspace.Terrain,
	now = function()
		return os.clock()
	end,
})
print(
	string.format(
		"[lobby] %s",
		if lobbyOn
			then "on: the drive is entered from one of the four coloured truck pads (task 182)"
			else "off: joining the server joins the drive, as before task 177"
	)
)

-- THE LOBBY'S OWN NUMBERS, ONCE, ON THE CONSOLE (review round 1, note 4). `docs/design/lobby.md`
-- section 18 item 2 asks for exactly this -- *"`Lobby.stats().shelfY` must be printed so it is a
-- number in the console and not a belief"* -- and the module never prints: a tool that `require`s it
-- over StudioMCP gets a sandboxed copy with empty state (measured, task 122), so the console is the
-- only honest channel for what the running server actually built.
--
-- ONE LINE, ON THE BUILD EDGE, from the loop this file already runs: the build is lazy (the ground
-- cannot be read until the place has loaded), so there is nothing to print at boot.
local lobbyReported = false
local function reportLobby()
	if lobbyReported or not lobbyOn or not Lobby.isBuilt() then
		return
	end
	lobbyReported = true
	local st = Lobby.stats()
	print(
		string.format(
			"[lobby] built in %d ms: shelf y=%.1f, %d part(s), %d terrain fill(s) (%d grass), pad 1 %s",
			st.buildMs,
			st.shelfY,
			st.parts,
			st.fillCalls,
			st.grassCalls,
			tostring(Lobby.Data.spotPosition())
		)
	)
	-- THE FOUR PADS, ON THEIR OWN LINE (task 182), for the reason the keeper has one: a pad whose part
	-- never got built is a hunt nobody on the server can start, and that has to be a line in the
	-- console rather than something Karen discovers by walking up to an unmarked truck.
	local found = #Lobby.Data.padPositions()
	print(
		string.format(
			"[lobby] truck pads: %d/%d built, sizes %s, %ds to pick then %ds to leave, door=%s",
			found,
			Lobby.Data.padCount(),
			(function()
				local out = {}
				for _, row in ipairs(Lobby.Data.CONFIG.PADS.SIZES) do
					table.insert(out, tostring(row.size))
				end
				return table.concat(out, "/")
			end)(),
			Lobby.Data.CONFIG.PADS.PICK_TIMEOUT_SECONDS,
			Lobby.Data.CONFIG.COUNTDOWN_SECONDS,
			tostring(Lobby.Data.remotes() ~= nil)
		)
	)

	-- THE TRUCKS, ON THEIR OWN LINE (task 186). Karen, 2026-10-14: *"car tyers are inside earth"* --
	-- and the count that was already printed said four trucks built, because they WERE built: they
	-- were built 0.75 studs under the terrain. So the number that goes on the console is the WORST
	-- WHEEL's clearance above its own ground, which is the one number in which that defect is
	-- visible, and the repaint's part count beside it.
	print(
		string.format(
			"[lobby] trucks: %d/%d settled on the measured ground, worst wheel %+.3f studs, %d part(s) in camouflage",
			st.trucksSettled,
			Lobby.Data.CONFIG.TRUCK.COUNT,
			st.truckGroundStuds,
			st.truckPainted
		)
	)

	-- THE SHOPKEEPER, ON HIS OWN LINE (task 181), because he is the only way into the shop since
	-- this task took task 178's auto-open away: "no keeper" means "no shop", and that has to be a
	-- line in the console rather than something Karen discovers by walking up to an empty counter.
	print(
		string.format(
			"[lobby] shopkeeper: %s, dressed=%s, prompt=%s",
			if st.keepers > 0 then "standing" else "NONE (the shop cannot be opened)",
			tostring(st.keeperDressed > 0),
			tostring(Lobby.Data.shopPrompt() ~= nil)
		)
	)
end

-- ---------------------------------------------------------------- the shop (task 178)
--
-- THE SEVENTH OWNER, WIRED THE SAME WAY as the six before it: it requires none of them and none of
-- them requires it, and this root hands each one what the other answers. Karen, 2026-10-13:
-- *"Hunting house where inside can shop things"*.
--
--   purchase     `Economy.purchase` -- the ONLY writer of either half of a purchase. The shop owns
--                no balance, no ownership set, no session and no key.
--   snapshotFor  `Economy.shopStateFor` -- one player's own payload, built by the pure
--                `Shop.rowsFor`, so `buyable` is decided once and on this side.
--   counterAt    `Lobby.Data.counterPosition` -- the ONE definition of where the counter is: the part
--                the server built, found by name -- **and only when the lobby actually built one**.
--
-- WHETHER THIS WORLD HAS A COUNTER IS THE LOBBY'S OWN ANSWER (task 233b), so it is `lobbyOn` and not
-- a second predicate: the counter is a part of the lodge, and `Lobby.start` is the one thing that
-- builds a lodge. `if lobbyOn then ... else nil` is this file's own idiom for exactly this -- `enrol`
-- and `gatherSpot` in the `Match.start` call below are written the same way, *"a lobby that did not
-- build"*. With a lodge, `Shop.start` answers true and the five providers below are wired; without
-- one it answers false, not one of them is wired, every reader answers nil and this world is
-- today's game by every branch (docs/design/shop.md section 7.1). `SHOP` is a v1 default since task
-- 233b and that is what makes the second half matter: the flag can no longer be the only gate.
--
-- `Weapon.setEntitlementProvider` AND `Body.setLookProvider` ARE THE TRANSLATION, and this root is
-- where it belongs: both seams take a `Player` and `Economy` *"must not hold a Player"* (its own
-- header). With the shop off neither is wired at all, and then every reader answers nil -- which is
-- today's game by every branch (docs/design/shop.md section 7.1).
local shopOn = Shop.start({
	purchase = Economy.purchase,
	snapshotFor = Economy.shopStateFor,
	counterAt = if lobbyOn then Lobby.Data.counterPosition else nil,
	remotes = ShopData.remotes(),
})
if shopOn then
	Weapon.setEntitlementProvider(function(player)
		return Economy.ownedOf(player.UserId)
	end)
	-- WHICH SPECIES HE HOLDS A CARD FOR (task 221). Task 178 left this provider unwired and said
	-- why: *"a species permit is a FIFTH item in the catalogue for an animal that is not in the
	-- game: it would be the thing invariant I3 exists to forbid"*. THAT REASON IS GONE -- Karen put
	-- the RED STAG CARD in the catalogue herself on 2026-10-20 -- so the gate, the catalogue and
	-- the invariant are consistent in one commit rather than in three. The card is `sale = false`
	-- until the animal ships, so nothing can hold a licence yet; `Weapon.askLicences` calls every
	-- provider through `pcall` and falls back to no restriction, which is today's game.
	Weapon.setLicenceProvider(function(player)
		return ShopData.licencesFor(Economy.ownedOf(player.UserId))
	end)
	-- ...AND WHETHER HE MAY STAND ON A HIGH SEAT (task 221 round 3). The placement only decides
	-- where he STARTS -- `ForestTest.lockPick` lets him walk to any stand in the 15-second window --
	-- so without this he could pick a seated stand, climb the engine's own ladder and shoot from a
	-- deck he never bought. `Weapon.Rules.onUnpaidPlatform` is the one question asked about it.
	ForestTest.setSeatProvider(function(userId)
		return ShopData.grantsHighSeat(Economy.ownedOf(userId))
	end)
	-- ...AND WHO BOUGHT THE HUNTER'S PLACE (task 229). It is the gate on the whole role switch: with
	-- this reader unwired `Lobby.wishFor` answers nil for everybody, the `DHRoleWish` attribute is
	-- never written, neither control is built and no wish can reach the roster -- which is today's
	-- game by every branch, exactly as the four providers above are (docs/design/shop.md 7.1).
	--
	-- A SETTER AND NOT A `Lobby.start` FIELD, because `Lobby.start` runs 150 lines above this one and
	-- `Shop.start` decides `shopOn` here -- `ForestTest.setSeatProvider`'s own arrangement.
	--
	-- `Economy.roleChoosers` AND NOT `Economy.ownedOf`, and the difference is measured in that file:
	-- `ownedOf` does `table.freeze(table.clone(set))` PER CALL, so one call per player per scan would
	-- be ~160 clones a second at sixteen players; `roleChoosers` is the frozen memo *"rebuilt and
	-- never mutated"*, so the lobby's scan costs one table read.
	--
	-- IT WAS `Economy.alwaysHunters` UNTIL TASK 242, and that is the whole of Karen's *"in nex drive
	-- I can't select beater but I have this license fix it"*: the switch was wired to the owners of
	-- ONE card. `roleChoosers` is the same projection of the same profiles over `Shop.grantsRoleChoice`,
	-- which is where the list of cards that buy a say in your side belongs.
	Lobby.setRoleChoosers(Economy.roleChoosers)
	Body.setLookProvider(function(player)
		local color = ShopData.hatColorFor(Economy.ownedOf(player.UserId))
		return if color then { hatColor = color } else nil
	end)
end

Match.start({
	-- WHETHER JOINING THE SERVER IS JOINING THE DRIVE (task 177). `false` only when the lobby really
	-- built itself; `nil` otherwise, which `Match.start` reads as today's behaviour.
	enrol = if lobbyOn then false else nil,
	-- A PLAYER'S COINS (task 170): a read-only view. The drive calls it at exactly one moment -- the
	-- `Scoring` edge, before its own effects -- and reads two tables when it builds a snapshot. It
	-- owns no balance and no session.
	economy = Economy.view(),
	-- WHO HAS ASKED TO BEAT THIS ONE DRIVE (task 229): a BARE FUNCTION and not a view, because there
	-- is exactly one thing to read and nothing to write -- `placement`'s and `groundAt`'s own shape.
	-- `Match` requires no lobby and learns only a function; this root is what joins the two owners.
	-- WITH THE LOBBY OR THE SHOP OFF IT ANSWERS AN EMPTY FROZEN TABLE -- the door is closed and the
	-- ownership reader is unwired, so nothing can ever be in it -- and an empty table is what makes
	-- `Roster.assign` answer by identity. `MatchBoot` (the DEV place, which has no lobby at all)
	-- passes no such field, which is the same answer by the other branch.
	roleWishes = Lobby.beaterWishes,
	boars = ForestTest.readOnlyBoars(runtime),
	-- THE BOTS THAT FILL THIS DRIVE (task 161): a read-only view, the same one `MatchBoot` hands over.
	bots = Bots.view(),
	weapon = Weapon,
	markers = function()
		-- THE DRIVE BOUNDARY IS WHERE A LAYOUT CHANGES, and this closure is the one place that sees
		-- it BEFORE anybody is placed: `Match` measures the set on the `Assigning` edge, ahead of
		-- its own `placePlayers` effect (docs/design/drive-layouts.md 6.2). A layout promoted any
		-- later would put the hunters of an edge drive on the road's posts, 900 studs away.
		--
		-- `layoutForDrive` IS IDEMPOTENT PER DRIVE NUMBER, so the once-a-second reads while `Waiting`
		-- promote nothing after the first one.
		--
		-- THE ATTRIBUTE IS READ HERE because this file is the only one in this world that touches
		-- `ServerStorage` (`Data.START_ROLE_ATTRIBUTE` is read exactly here too). The DECISION stays
		-- in `ForestTest`; the composition root only hands it the two things it cannot reach --
		-- `Match`'s drive number and the Director's override.
		ForestTest.layoutForDrive(Match.driveNumber(), ServerStorage:GetAttribute(Data.LAYOUT_OVERRIDE_ATTRIBUTE))
		-- THE HIGH SEATS, BEFORE THE MARKERS, AND THE ORDER IS THE WHOLE OF TASK 218 (design
		-- section 9.3). `Seats.ensure` is LEVEL-TRIGGERED on the layout's name: a folder already
		-- stamped with this layout costs a `FindFirstChild` and casts no ray, so the once-a-second
		-- `Waiting` read churns nothing; any other state is rebuilt, so a rotation cannot leave the
		-- road's seats standing in the ride. It runs FIRST because `Markers.build` then asks the
		-- seat where its deck is instead of reading that column from the sky and refusing the stand.
		--
		-- IT IS HERE AND NOT ON THE `Assigning` EDGE on purpose: an edge handler would be a SECOND
		-- place that decides when seats exist, and this closure already runs at that edge. One call
		-- site, level-triggered, cannot be missed, cannot fire twice and cannot be ordered wrongly.
		ForestTest.Seats.ensure(ForestTest.layout())
		return ForestTest.Markers.build(ForestTest.hunterStandX(), ForestTest.layout())
	end,
	placement = placement,
	-- WHERE THE GROUND IS, FOR THE ONE WRITER OF WHERE A CHARACTER STANDS (task 192). The SAME
	-- function `Markers.setReaders`, `Bots.start` and `Lobby.start` are handed above -- this world's
	-- single ground reader -- so `Body.onGround` snaps a placement onto the ground this world agrees
	-- on and not onto a fourth opinion of it. Without it `Body` falls back to its own ray, which in
	-- THIS place can stop on the canopy of the 831 trees in the two Studio-built `Session` folders
	-- (`ForestTest.terrainYAt`'s header measures exactly that).
	groundAt = Data.groundAt,
	-- WHERE A HUNTER'S STAND IS IN THIS WORLD (task 171), and it is NOT where `placement` put him:
	-- here he picks his own by walking to it in the 15 s window (`ForestTest.lockPick`), so the
	-- circle the fire gate measures is centred on the PICK. `ForestTest.standArea` is the same
	-- `standPosition` and the same `PICK.standRadiusStuds` the soft wall of task 166 is built from,
	-- so where he may SHOOT and where he may WALK are one circle asked twice, and nil until his pick
	-- locks -- which is the whole of "no rule during the pick window".
	standArea = ForestTest.standArea,
	-- WHERE THIS WORLD GATHERS AT THE END OF A DRIVE (task 191). KAREN, 2026-10-15 ~17:20: *"next is
	-- when hunt over everyone is in clean ground no grass firstable / second it could be next to
	-- cabin"*.
	--
	-- IT IS THE LOBBY'S YARD, AND THE LOBBY IS THE OWNER THAT KNOWS WHERE ITS OWN YARD IS. The
	-- rectangle is one row in `Lobby.CONFIG.FIELD.PADS` (`Gather`), blade-free `Ground` like the
	-- lodge's own yard, and `Lobby.gatherSpot` measures its centre with THIS world's ground reader --
	-- the same `Data.groundAt` three lines up. `Match` holds the fallback.
	--
	-- `if lobbyOn`, EXACTLY AS `enrol` ABOVE IS, and for the same reason: a lobby that did not build
	-- has no yard, so the field is absent and the drive gathers behind the middle stand as it did
	-- before this task. That is the "reachable by parameter" half of the flag rule without a flag --
	-- and this world cannot switch it off with `tools/flags.py`, the same stated cost
	-- `BOAR_MODEL`, `CALM`, `PACE`, `MOVE`, `LINE` and the lobby itself already carry: the rollback
	-- is this one line.
	--
	-- THE PLAYERS AND THE BOTS ARRIVE THERE AND STAY: task 177's flow out of the scene starts from
	-- wherever they are standing (the lobby clears the roster when the scene goes up, so they are no
	-- longer in the drive, `Match.isHeld` keeps BOTH the lobby's return rule and the stand wall off
	-- them for its 25 seconds, and `enterWaiting` then frees them where they stand). There is no
	-- second teleport in either direction.
	gatherSpot = if lobbyOn then Lobby.gatherSpot else nil,
	config = {
		-- THE DIRECTOR'S SHORT-DRIVE SWITCH, read HERE because this is the composition root and
		-- `Match.WORLD_OVERRIDABLE` names `DRIVE_SECONDS` as a key a world may set (task 201 part
		-- 2). Nobody has set it in the normal case and this is `Data.DRIVE.seconds`, which is what
		-- every run before the switch existed used. `ForestTest.driveSeconds` is the one place the
		-- value is judged, and it answers nil -- the default -- for anything out of range.
		DRIVE_SECONDS = ForestTest.driveSeconds(ServerStorage:GetAttribute(Data.DRIVE_SECONDS_ATTRIBUTE))
			or Data.DRIVE.seconds,
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
		-- ...AND THE WOOD IS A NEW WOOD (task 172 round 2). `ForestTest.stepRest` stocks it once per
		-- DRIVE and never re-stocks inside one -- Karen, 2026-10-13: *"and again no boar behing
		-- comming after beater walk"* -- so something has to say when a drive began, and this is the
		-- edge this file already opens a report window on. Without it the latch is per SESSION and a
		-- beater's second drive is an empty wood.
		ForestTest.newDrive()
		print(string.format("[report] drive %d opened (%ds windows)", driveNumber or 1, Data.DRIVE.seconds))
	elseif phase == "Scoring" then
		HitLog.closeDrive(os.clock())
		-- ONE LINE PER DRIVE SAYING WHAT THE BOTS DID (task 161), on the same channel and for the
		-- same reason as `[wave]` and `[rest]` above: the module never prints, a tool that `require`s
		-- it over StudioMCP gets a sandboxed copy with empty state (measured, task 122), and "the
		-- bots walked fine" is the kind of claim that needs numbers beside it. It carries the two
		-- nothing else can answer -- the step's own cost, because the vendor's performance page has
		-- no numbers in it at all, and the walk's own seconds, because a drive now ENDS when the line
		-- is through.
		if Bots.count() + Bots.desired() > 0 then
			print(Bots.report(driveNumber or 1))
			-- WHERE THE LINE WAS, AS THREE NUMBERS PER LANE (task 167), because Karen's *"all bots
			-- came to me"* is a claim about exactly those and nothing printed them.
			local lanes = Bots.laneReport(driveNumber or 1)
			if lanes ~= "" then
				print(lanes)
			end
		end
		-- ONE LINE PER DRIVE SAYING WHETHER THE ANIMALS MISSED THE TREES (task 167), on the same
		-- channel and for the same reason. Karen has said *"boar hit tree"* on three playtests
		-- running, and the number this task is judged on is contacts per 100 s OF RUNNING -- so both
		-- halves of it are printed, plus what the sweep fan spent to get them. The module never
		-- prints: a tool that `require`s it over StudioMCP gets a sandboxed copy with empty state
		-- (measured, task 122).
		local boar = runtime:stats()
		if boar.runSeconds > 0 or boar.trunkContacts > 0 then
			print(
				string.format(
					"[trees] drive %d: %d trunk contacts in %.1fs of running (%.1f/100s) | avoid %d turns, %d boxed in,"
						.. " %d casts | %d wedged, %d stuck",
					driveNumber or 1,
					boar.trunkContacts,
					boar.runSeconds,
					boar.trunkContacts / math.max(boar.runSeconds, 1e-6) * 100,
					boar.avoidTurns,
					boar.avoidBoxedIn,
					boar.avoidCasts,
					boar.wedges,
					boar.stuckReports
				)
			)
		end
	end
end)

-- HOW LONG ANYTHING THAT READS A JUST-PLACED CHARACTER WAITS FOR THE RESPAWN TO SETTLE.
-- `Body.place` pivots on `CharacterAdded` and `Body.settle` pivots again when that resumption cycle
-- ends (`task.defer`), so anything over a frame is enough; one second is long enough to be obviously
-- enough and short enough to read as "at the start".
--
-- IT SITS HERE, ABOVE BOTH ITS READERS, SINCE TASK 175: the start line below is one of them and the
-- intermission's ring is the other, and a `local` declared after a closure that names it is a GLOBAL
-- read inside that closure -- nil, and `task.delay(nil, ...)` throws.
local PLACEMENT_SETTLE_SECONDS = 1

-- ---------------------------------------------------------------- the ring a hunter can always see
--
-- KAREN, 2026-10-13 ~19:05, after playing 172-174: *"for shooter - get in your stand (we need to
-- show where is his stand this circle has to remain all a time"*.
--
-- WHAT SHE WAS LOOKING AT, AND IT IS WHY THIS IS ONE FUNCTION NOW. Task 166 drew the ring at exactly
-- one moment -- the instant the pick LOCKED -- and `Markers.clearRings()` took every ring down at the
-- next `Assigning`. So the screen said *get to your stand* through the whole intermission and the
-- first ten seconds of the drive with NO CIRCLE ANYWHERE, which is the one stretch in which a hunter
-- is actually walking to a stand and needs to know which one. The ring then stood for the rest of the
-- drive, the scoring and the results, which is the half that was already right.
--
-- SO THE RING FOLLOWS `ForestTest.standIndexOf` AND NOTHING ELSE: it is drawn whenever that answer
-- changes and cleared when it goes nil, and every caller below is one call to this. One rule, one
-- writer, three moments (the intermission's placement, the drive's pick window, the lock) instead of
-- three rules.
--
-- `shownRing` IS WHAT IT LAST DREW FOR WHOM, and it is needed for one case only: a hunter whose index
-- CHANGES (he walks to another stand in the pick window and locks that one). `Markers.ring` replaces
-- the ring of the index it is given, so without this the stand he left would keep its ring for the
-- rest of the drive -- a circle round a stand nobody is held to, which is the thing the `Assigning`
-- clear exists to prevent.
local shownRing: { [number]: number } = {}

-- Is this stand still somebody's? Two hunters CAN resolve to one index -- `standIndexFor` wraps at
-- nine stands -- and one of them leaving must not take the other's circle with it.
local function standIsClaimed(standIndex: number, exceptUserId: number): boolean
	for userId, index in pairs(shownRing) do
		if userId ~= exceptUserId and index == standIndex then
			return true
		end
	end
	return false
end

-- DRAWS THIS PLAYER'S OWN RING, or takes it down when he has no stand. Returns the index it drew and
-- how many segments went down, so a caller that wants to print a line has both without asking twice.
--
-- THE RING IS A WORLD PART AND SO EVERYBODY SEES EVERYBODY'S (`Workspace.ForestMarkers`, replicated).
-- That is kept rather than made local: the drive's own hunters standing in a line of lit circles is
-- the picture `Markers` was built for, and a per-player ring would need a second, client-side drawer
-- of the same geometry -- a second writer of the thing rule 3 gives this module.
local function showRing(player: Player): (number?, number?)
	local userId = player.UserId
	local index = ForestTest.standIndexOf(userId)
	local before = shownRing[userId]
	if index == nil then
		shownRing[userId] = nil
		if before ~= nil and not standIsClaimed(before, userId) then
			ForestTest.Markers.clearRing(before)
		end
		return nil, nil
	end
	shownRing[userId] = index
	if before ~= nil and before ~= index and not standIsClaimed(before, userId) then
		ForestTest.Markers.clearRing(before)
	end
	return index, ForestTest.Markers.ring(index, Data.PICK.standRadiusStuds, ForestTest.layout())
end

-- THE STAND PICK IS THE HUNTER'S TEN SECONDS, and it opens when the DRIVE starts (task 157).
--
-- It used to open on `CharacterAdded`, which is now the drive's own respawn -- and opening it there
-- would start the clock while the intermission still ran. On entering `Running` everybody has been
-- placed, so the window is the first ten seconds of the drive: she lands on her stand, walks a few
-- steps, and whatever she is standing on at the end is hers.
local function openPickFor(player: Player)
	if ForestTest.roleOfPlayer(player) ~= "hunter" then
		return -- a beater has no stand, and no boundary (`ForestTest.boundary` refuses her for the same reason)
	end
	-- THE OPEN PICK POINTS AT THE STAND HE IS STANDING ON (task 175), which is `nearestStand` of the
	-- position `Body.place` has just put him at -- the same function `lockPick` uses ten seconds
	-- later, so the ring that goes up now is round the stand he would get by not moving. Without a
	-- position it stays `PICK.defaultIndex`, which is what every call before this task got.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local standing = if root then ForestTest.nearestStand((root :: BasePart).Position) else nil
	ForestTest.openPick(player.UserId, os.clock(), standing)
	-- HIS EDGE, DRAWN FROM THE FIRST FRAME OF THE DRIVE and not from the tenth second (task 175).
	local open = showRing(player)
	print(
		string.format(
			"[ForestTest] %s has the pick window open on stand %s (edge ring %d studs, shown now)",
			player.Name,
			tostring(open),
			Data.PICK.standRadiusStuds
		)
	)
	task.delay(Data.PICK.seconds, function()
		local now = player.Character
		local nowRoot = now and now:FindFirstChild("HumanoidRootPart")
		if player.Parent == nil or nowRoot == nil then
			return
		end
		-- ...UNLESS THE DRIVE HAS MOVED HER SINCE. Locking a stand for a beater would put a hunter in
		-- `ForestTest.hunterStandX` who is not standing there, and the drive aims every wave at it.
		if ForestTest.roleOfPlayer(player) ~= "hunter" then
			return
		end
		local index = ForestTest.lockPick(player.UserId, (nowRoot :: BasePart).Position, os.clock())
		-- HIS EDGE, REDRAWN (task 166, one writer since 175). The boundary opens the moment the pick
		-- locks; if he walked to another stand in the window, `showRing` takes the old circle down.
		local _, segments = showRing(player)
		print(
			string.format(
				"[ForestTest] %s took stand %d (edge ring %d studs, %s segments)",
				player.Name,
				index,
				Data.PICK.standRadiusStuds,
				tostring(segments)
			)
		)
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
		-- ...AND HIS CIRCLE GOES WITH IT (task 175). A hunter who types `/beater` mid-drive leaves a
		-- stand; `showRing` follows `standIndexOf` to nil and takes the ring down. The reverse --
		-- `/hunter` mid-drive -- still gets NO ring until the next drive opens a pick window for
		-- him, which is unchanged and is the honest picture: he has no stand and no boundary either.
		showRing(player)
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
		-- ...AND THE RINGS GO WITH THE PICKS (task 166): an edge drawn round a stand nobody is held
		-- to is a line that means nothing, and the next lock draws its own.
		ForestTest.Markers.clearRings()
		table.clear(shownRing)
		-- ...AND THE NEW DRIVE'S RINGS GO UP AS SOON AS THE PLACEMENT HAS LANDED (task 175). KAREN:
		-- *"we need to show where is his stand this circle has to remain all a time"* -- and the
		-- stretch that had no circle at all was exactly this one, the intermission in which the
		-- objective line says *get to your stand*. `enterAssigning` emits `assignTeams` before
		-- `placePlayers`, so the TEAM is already right here; the POSITION is not, because
		-- `Body.place` pivots on `CharacterAdded`. So it waits the same `PLACEMENT_SETTLE_SECONDS`
		-- the start line waits -- the one moment in this file that already knows the character has
		-- actually landed -- and reads `nearestStand` of where he ended up.
		--
		-- IT OPENS AN UNLOCKED PICK AND THAT ENFORCES NOTHING. `standArea`, `boundary` and
		-- `hunterStandX` all ignore a pick with no `lockedAt`, deliberately ("no rule during the
		-- pick window"), so the stated reason for the clear above survives intact: nobody is held to
		-- a stand during the intermission and no wave is aimed at one. What changes is only what is
		-- DRAWN, and the drive's own `openPickFor` re-opens the window on top of it.
		task.delay(PLACEMENT_SETTLE_SECONDS, function()
			if Match.phase() ~= "Assigning" then
				return -- the intermission is over; `openPickFor` owns the ring from here
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				-- ...AND NOT FOR A MAN WHO HAS ASKED TO BE A BEATER (task 214). The sweep honours his
				-- ask the moment his character has landed, which is about this instant; without this
				-- the two answers race and Karen sees a ring drawn round a stand and taken down
				-- again a frame later. `roleOfPlayer` cannot see the ask -- it reads `Player.Team`,
				-- which is the drive's answer and not the question.
				if
					root ~= nil
					and ForestTest.roleOfPlayer(player) == "hunter"
					and ForestTest.pendingRequest(player.UserId) == nil
				then
					ForestTest.openPick(player.UserId, os.clock(), ForestTest.nearestStand((root :: BasePart).Position))
					local index, segments = showRing(player)
					print(
						string.format(
							"[ForestTest] %s is walking to stand %s this intermission (edge ring %d studs, %s segments)",
							player.Name,
							tostring(index),
							Data.PICK.standRadiusStuds,
							tostring(segments)
						)
					)
				end
			end
		end)
		return
	end
	if phase ~= "Running" then
		return
	end
	-- A REQUEST IS NO LONGER HONOURED FROM THIS EDGE (task 214). It used to be honoured here and
	-- nowhere else -- "not in `Assigning`: that phase respawns everybody already, and honouring
	-- inside it would be a second `LoadCharacter` for the same player in the same intermission" --
	-- and the lobby made that one instant the wrong one: a player now enrols from a truck pad, so by
	-- the time the drive could use his ask he had already spent the whole intermission on the other
	-- side, with the other side's gun and a ring round a stand he was about to be taken away from.
	-- The sweep on the Heartbeat below owns it now, which covers this instant and every other one;
	-- `ForestTest.toHonour` carries the measurement.
	for _, player in ipairs(Players:GetPlayers()) do
		openPickFor(player)
	end
	-- WHAT THE MARKERS MEASURED, once per drive: nine stands or fewer, how many the ground refused,
	-- and the worst disagreement between the two readings of it. This is the line that says "the drive
	-- is standing on this world" rather than hoping it is.
	local stats = ForestTest.Markers.stats()
	print(
		string.format(
			"[ForestTestBoot] markers: layout=%s %d/%d stands (%d refused), max ground delta %.2f, reads=%d",
			ForestTest.layoutName(),
			stats.posts,
			ForestTest.layout().standCount,
			stats.refused,
			stats.lastMaxDelta,
			stats.reads
		)
	)
	-- ...AND WHAT THE HIGH SEATS MEASURED (task 218). `Seats` never prints: this is the composition
	-- root, the same division `Markers.stats` and the line above already follow. The worst foot gap
	-- IS the rule E claim as a number -- the worst of five footprint samples of every seat standing
	-- -- so the thing Karen looks at and the thing the console says are the same measurement.
	local seatLine = ForestTest.Seats.takeLine()
	if seatLine ~= nil then
		print(seatLine)
	end
end)

-- WHAT EACH PLAYER WAS WHEN HIS BODY LAST STOOD STILL (task 214), by UserId: the character, and the
-- team he was on at that moment. Owned here, written only in `reportStart`'s settle delay below and
-- dropped only by `PlayerRemoving`. Nothing has to clear it on a respawn or on a team change:
-- `ForestTest.toHonour` compares both fields with what the player has NOW, and its header carries
-- the measurement that says why one of them is not enough.
local settledCharacter: { [number]: ForestTest.Settled } = {}

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
--
-- ...AND IT IS ALSO WHERE THIS ROOT LEARNS THAT A CHARACTER HAS LANDED (task 214). `settledCharacter`
-- below is written in exactly one place, this delay, for the same reason the line above is printed
-- from it: it is the one moment in this file that knows a respawn is over. `ForestTest.toHonour`
-- reads it so that a role request cannot be offered to the drive while the drive's own placement is
-- still in flight for the same player -- that function's header carries the measurement.
local function reportStart(player: Player, character: Model)
	task.delay(PLACEMENT_SETTLE_SECONDS, function()
		-- RECORDED BEFORE THE EARLY RETURN BELOW, and that is deliberate: what this answers is "has
		-- `PLACEMENT_SETTLE_SECONDS` passed since this character arrived", which is the race guard
		-- `ForestTest.toHonour` wants, and it is a different question from "is this character worth
		-- printing a line about". A character that is still unparented at this point would otherwise
		-- leave the player's ask unhonourable for ever, which the `Running` edge used to cover.
		if player.Character == character then
			settledCharacter[player.UserId] = { character = character, team = player.Team }
		end
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
				at.Z - Data.roadZ(at.X, ForestTest.layout()),
				Body.settled()
			)
		)
	end)
end

-- EVERY PLAYER IN THIS WORLD IS WIRED UP, WHENEVER HE JOINED (task 202). `Players.PlayerAdded` did
-- not fire for the only player in a Play Solo session -- measured twice on 2026-10-17, and the proof
-- is that neither print inside this function appeared -- because this root yields for seconds before
-- it reaches this line and Play Solo puts the local player into `Players` while it is still running.
-- Both routes into a role are in here (the `DHForestStartRole` switch, and the `player.Chatted`
-- connection Karen's `/beater` travels down), so neither worked.
--
-- THE FIX IS A SWEEP AND NOT A SECOND EVENT: `ForestTest.toWire` is asked on the Heartbeat below
-- what is still unwired, and `wired` is this root's own record of what it has done. See that
-- function's header for why an edge handler is the wrong shape for this at all.
local function onPlayer(player: Player)
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
	-- ...AND THE CHARACTER HE ALREADY HAS, if he has one: `CharacterAdded` has exactly the same hole
	-- as the event this sweep replaced, and `reportStart` is how a tool outside the server learns
	-- which role the drive actually gave him (its own header says so).
	local character = player.Character
	if character ~= nil then
		reportStart(player, character)
	end
end

-- WHO THIS ROOT HAS ALREADY WIRED, by UserId. Owned here and written nowhere else: `toWire` is pure
-- and answers from it, this is the one place that adds to it, and `PlayerRemoving` below is the one
-- place that takes away -- so a player who leaves and comes back in the same session is wired again
-- rather than left with the dead connections of his old `Player` object.
local wired: { [number]: boolean } = {}

Players.PlayerRemoving:Connect(function(player)
	wired[player.UserId] = nil
	-- ...AND SO DOES THE CHARACTER THIS ROOT HAD SEEN LAND (task 214): a Model kept here would hold
	-- a departed player's body alive, which is `Match.forget`'s own rule one line further down.
	settledCharacter[player.UserId] = nil
	-- HIS RING GOES WITH HIS PICK (round 1's note). An edge drawn round a stand nobody is held to is
	-- a line that means nothing, and without this it stayed until the next intermission cleared all
	-- of them.
	--
	-- THROUGH `showRing` SINCE TASK 175, which is the one writer of it: the pick is dropped FIRST and
	-- the ring then follows `standIndexOf` to nil, instead of this file reading `pickOf(...).index`
	-- and clearing by hand. That also fixes a case the hand-written version could not see -- two
	-- hunters wrapped onto one stand (`standIndexFor` wraps at nine), where one leaving used to take
	-- the other's circle with him (`standIsClaimed`).
	ForestTest.clearPick(player.UserId)
	showRing(player)
	-- THE REQUEST GOES WITH THE PLAYER. `Body.forget` is no longer called here: `Match.forget` runs
	-- in this world now and calls it, so one caller instead of two.
	ForestTest.clearRequest(player.UserId)
	-- ...AND SO DOES EVERY ROW THE LOBBY KEYS BY HIM (task 177, review round 1 finding 3).
	-- `Lobby.forget`'s own header carries `Match.forget`'s rule -- *"After this, no table in this
	-- system is keyed by that player"* -- and until this line the only caller in the repo was a spec:
	-- `entries`, `returnedAt`, `spawnIndex` and `touched` kept a row for every player who had ever
	-- joined, and `touched` held the departed `Player` INSTANCE itself.
	Lobby.forget(player.UserId)
end)

-- ---------------------------------------------------------------- the loop

-- ONE HEARTBEAT FOR BOTH JOBS: the schedule and the stand boundary. The boar runtime runs its own, and the
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
	local players = Players:GetPlayers()
	-- EVERYBODY IS WIRED UP, WHENEVER HE JOINED (task 202). One table lookup per player per tick
	-- while nothing has changed, and `toWire` allocates nothing in that case.
	local joining = ForestTest.toWire(players, wired)
	if joining ~= nil then
		for _, player in ipairs(joining) do
			wired[player.UserId] = true
			onPlayer(player)
		end
	end
	-- ...AND EVERYBODY WHO ASKED FOR A ROLE IS GIVEN IT AS SOON AS THE DRIVE CAN GIVE IT (task 214).
	-- Same shape and same reason as the line above: "he asked" is a STATE, and the one instant this
	-- used to be read at (the `Running` edge) is not the instant the lobby enrols him at. `honour`
	-- is already one-shot and already asks the drive rather than deciding -- outside a drive
	-- `Match.requestTeam` refuses and the ask stays pending, which is what makes a sweep safe here.
	local owed = ForestTest.toHonour(players, settledCharacter)
	if owed ~= nil then
		for _, player in ipairs(owed) do
			honour(player)
		end
	end
	for _, player in ipairs(players) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- THE STAND'S WALL IS THE DRIVE'S, AND IT IS NOT THE LOBBY'S (task 177). This guard was not in
		-- the design and it is a MEASURED fix, not a precaution: at the end of the first live drive the
		-- player was out of the drive (`Player.Team` nil, `RespawnLocation` back at the lodge) and
		-- STILL PINNED at (3027, -2109) on the road, with his y bouncing 143 / 145 / 149 as two writers
		-- fought over him every frame. `ForestTest.boundary`'s own first line reads
		-- `(role or ForestTest.ROLE_DEFAULT) ~= "hunter"`, and `ROLE_DEFAULT` is `"hunter"` -- so a man
		-- with NO team was walled to the stand he had locked ten minutes earlier, and the lobby's
		-- return put him at the lodge only for the wall to drag him back on the next Heartbeat.
		--
		-- THAT STATE DID NOT EXIST BEFORE THIS TASK, which is why nothing had to say this: in this
		-- world everybody was always in the drive. The question *"is this man in the hunt"* has one
		-- owner and one answer -- `Match.isParticipant` -- and this composition root is where it is
		-- asked, exactly as it asks `ForestTest.roleOfPlayer` on the next line.
		--
		-- ...AND IT IS NOT THE DRIVE'S EITHER WHILE THE DRIVE IS HOLDING HIM (task 192). SAME CLASS
		-- OF BUG AS THE GUARD ABOVE, MEASURED THE SAME WAY. At the end of a live drive on the `edge`
		-- layout the results scene stood the player at a ring slot near the middle stand and this
		-- wall dragged him back to 12.0 studs from his OWN stand -- `PICK.standRadiusStuds` exactly
		-- -- CARRYING THE RING'S Y WITH HIM, because `boundaryPoint` clamps X and Z and keeps
		-- `position.Y`. Logged at `(3543, 174.5, -3001)` with the terrain under him at 189.0: his
		-- feet 17.5 studs under the ground, anchored, for the whole 25-second scene. That is Karen's
		-- *"when drive ends I am underground"*, and it is two writers of one fact again.
		--
		-- `Match.isHeld` IS THE QUESTION'S OTHER HALF AND IT ALREADY EXISTS: the lobby is handed the
		-- same function for the same reason one screen up (*"`isHeld` is what stops the lobby
		-- respawning a man out of Karen's results scene"*), so this is a third reader of one answer
		-- and not a new rule. It covers the gathering and the beaters' hold at the start line.
		--
		-- ...AND `Match.isTied` IS A THIRD QUESTION, NOT THE SAME ONE (Reviewer round 1, finding 2,
		-- which was right and caught a comment claiming a fix the code did not make). `isHeld` reads
		-- `heldStill`, written only by `applyHold`; a tie writes `tied`, and `applyFree`'s own
		-- comment says the two never overlap -- *"ties only exist in `Running`, holds only in
		-- `Assigning` and `Scoring`"*. So a tied hunter was a participant, was not held, and this
		-- wall went on rewriting his `root.CFrame` every Heartbeat -- dragging him off the rope
		-- whenever the tree stood outside his stand circle, which is the whole point of a tie.
		-- Two readers, two tables, one guard.
		local frozen = Match.isHeld(player.UserId) or Match.isTied(player.UserId)
		if root and Match.isParticipant(player.UserId) and not frozen then
			-- THE ROLE IS PASSED IN SINCE TASK 157: the truth of it is `Player.Team`, and this loop is
			-- what holds the `Player` -- `ForestTest` keys by `userId` and never holds one.
			--
			-- `Body.liftOntoGround` IS THE FOURTH SEAM THIS LOOP HANDS DOWN, and it is the one
			-- placement rule applied to the one thing in this world that writes a root's CFrame
			-- without going through `Body` (task 192). See `ForestTest.boundary` for the two
			-- measurements that put it here.
			ForestTest.boundary(player.UserId, root :: BasePart, ForestTest.roleOfPlayer(player), Body.liftOntoGround)
		end
	end
	-- ...AND THE LOBBY'S PRESENCE SCAN (task 177), ONE MORE CALL IN THIS HEARTBEAT AND NOT A SECOND
	-- CLOCK. This loop already walks every player's root every frame, and `Lobby.step` throttles
	-- itself to `SCAN_HZ` inside the module -- so a second `RunService.Heartbeat` would be a second
	-- answer to "what time is it" in the file whose own header above says ONE HEARTBEAT FOR BOTH JOBS.
	Lobby.step(now, players)
	reportLobby()
end)

HitLog.start()
ForestTest.start(runtime, os.clock())

-- THE LEVEL-TRIGGERED RETRY FOR A PROFILE THAT DID NOT LOAD (task 170), on the phase this file
-- already listens to. The `Weapon.refreshArming` / `syncBots` discipline and its stated reason:
-- *"every edge-triggered grant in this repo has been measured missing one"*. A transient Roblox
-- outage then costs one drive's coins instead of the whole session's.
Match.PhaseChanged:Connect(function(_before, phase)
	if phase == "Assigning" then
		Economy.onDriveStart()
	end
	-- ...AND THE LOBBY RECORDS THE PHASE AND ACTS ON THE NEXT SCAN (task 177). It must not act HERE:
	-- `Match` fires this signal at the end of `dispatch`, and a dispatch inside a dispatch would
	-- apply effects out of order -- `Match:step`'s own rule.
	Lobby.onPhase(phase)
end)

-- THE ONE `BindToClose` IN THE REPOSITORY: every open session is ended, which is what saves it.
--
-- REGISTERED BY THE ROOT AND NEVER BY `Economy.start`, because `BindToClose` cannot be disconnected
-- (https://create.roblox.com/docs/reference/engine/classes/DataModel#BindToClose) and every spec
-- starts and stops that owner -- a registration inside `start` would leave one callback per spec run
-- bound for the rest of the session. `Economy.closeAll()` on an owner that was never started is a
-- no-op, which is what makes this unconditional line correct.
game:BindToClose(Economy.closeAll)
