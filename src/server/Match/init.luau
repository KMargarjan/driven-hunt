--!strict
-- Match: the owner of the drive (CLAUDE.md rule 3) -- the phase and its deadline, team membership,
-- every player's per-drive score, which boars exist while a drive runs, and the two outbound
-- RemoteEvents. It fills the `Game state` slot that has been `_unassigned_` in GAME_DESIGN.md since
-- Task 1.
--
-- It writes NO boar state (it calls runtime:spawn and reads handles), NO weapon state (it injects a
-- policy and asks the weapon to re-evaluate), nothing drawn, and no camera.
--
-- Pattern: a folder module that owns state over pure decision modules driven by an injected world --
-- the shape src/server/Boar/init.luau and src/server/Weapon/init.luau already are, at a third
-- instance. NOTHING HAPPENS ON REQUIRE: only Match.start(world) begins production, which is what
-- lets every spec in tests/server/match_*.spec.luau drive a whole drive with no players, no boars
-- and no clock.
--   Phase   pure: the state machine, returning state + an explicit effect list
--   Roster  pure: who is on which team
--   Score   pure: points
--   Markers read-only: the CollectionService tags
--   Body    the only writer of teams and of where a character stands
--   Scene   the only writer of Workspace.DriveScene: the results scene's animals and lamps
--
-- MILESTONE 1.7b turned both switches on: SAFETY_ENABLED ties a shooter who fires at a driver to a
-- tree for the rest of the drive, and Drive.CONFIG.SCOREBOARD_ENABLED shows the score screen. The
-- penalty adds one pure module (Penalty) and two effects (`freeze`, `release`); nothing else about
-- the machine changed.
--
-- TASK 158 ADDED THE START OF A DRIVE and no phase: the countdown IS the existing `Assigning`
-- intermission, now 10 seconds, and the three things Karen asked for all read its one deadline --
-- the start card ("what you can shoot" plus your role), the hunter's stand timer, and the beaters
-- held at their line until GO. Two effects (`hold`, `free`), one set (`heldStill`), one pure rule
-- each side: `Phase.heldUserIds` says who is held, `Match.quarryRows` says what may be shot.
--
-- TASK 159 ADDED THE END OF A DRIVE AND THE RESULTS SCENE, and no phase either. Karen: *"Timer or
-- when all beaters cross line of hunters. And yes could be that all they standing around the animals
-- there is light on 4 corners and then showing image transperent with results table"*. So:
--   * a drive ends on the clock as it always did, OR earlier when every REAL beater is through the
--     hunters' line -- `Match.crossedLine` measures it against the nearest stand, `Phase` decides;
--   * the `Scoring` phase IS the scene: this drive's animals laid out in a row, four lamps on the
--     four corners, everybody held and stood round them (`Body.stand`), and the results table on
--     screen -- which is the drive's own score panel reading the snapshot this owner already
--     broadcasts. There is no second score and no new remote.
--     WHERE that row lies is `Match.gatherSpot`, and SINCE TASK 191 THE WORLD GETS FIRST SAY: Karen,
--     2026-10-15, *"next is when hunt over everyone is in clean ground no grass firstable / second
--     it could be next to cabin"*, so the Forest Test hands this owner `world.gatherSpot` and the
--     gathering happens in the lobby's clean yard beside the lodge. `Match.gatherSpotFor` -- behind
--     the middle stand -- is the fallback, and it is what a world that injects nothing still gets.
--
-- TASK 161 FILLED THE DRIVE WITH BOTS, and this owner gained no rig and no clock for it. Karen's v1
-- rule: *"Let's make 4 hunters 4 beaters"*, and she plays solo. `ServerScriptService.Bots` owns every
-- rig, its movement and its horn; this owner is injected with a narrow VIEW of it (`world.bots`, the
-- `ForestTest.readOnlyBoars` idiom) and asks it four things at its own phase boundaries -- fill,
-- go, gather, clear -- plus two readings: who the bot beaters are, and what a boar can perceive.
-- A world that injects no `bots` is this file before task 161, by every branch.
--
-- WHAT THE BOTS CHANGED INSIDE THIS FILE, and it is deliberately small: `Match.CONFIG.BOTS` (the one
-- flag read and the targets), `Match.beaterCrossing` counts the bot beaters into the LINE so a SOLO
-- beater no longer ends a drive by herself (Karen's own complaint, TASKS.md 159a(f)),
-- `Match.boarThreats` appends them as real bodies with no `phantom` mark, `applyScene` widens the
-- ring so they stand round the animals too, and `syncBots` is the one level-triggered call site.
-- `Phase` learns NOTHING about bots -- `beatersThrough` still only compares two numbers -- and
-- `Match.driverThreats`, `playerDrivers`, `samplePush`, `pushCreditable` and `Penalty` are untouched,
-- because a bot has no userId and all five are keyed by one.
--
-- Design: docs/design/drive.md, docs/design/bots.md
-- Note:   docs/research/2026-09-25-drive.md, docs/research/2026-10-12-drive-end-and-results-scene.md,
--         docs/research/2026-10-12-bots.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
-- THE HORN'S OWN DATA, FOR EXACTLY ONE NUMBER: how long the start fanfare sounds, which is how long
-- the beaters are held past GO (task 168, `GO_HOLD_SECONDS`). It is a require of a pure shared data
-- module and not of an owner -- `src/shared/Horn` creates no Instance, reads no service and holds no
-- state -- so this adds no second writer of anything. The alternative was a second copy of 2.18
-- seconds in this file, which is the drift this project is a document about.
local HornData = require(ReplicatedStorage:WaitForChild("Horn"))
-- THE LICENCE TABLE, FOR EXACTLY ONE STRING: the name of the attribute a target publishes to say
-- which species it is (task 171). Pure shared data, like `HornData` above -- no Instance, no
-- service, no state -- and the alternative was the literal "Species" written in two files.
local Licences = require(ReplicatedStorage:WaitForChild("Licences"))
-- THE SHOP'S PURE DATA (task 178), for ONE question: may a licensed BEATER carry a gun in the drive
-- (`Shop.grantsDriveGun`). Frozen shared data with no writer, required exactly as `Licences` above
-- is and for the same reason -- a rule about what a player may do lives in one table, and this owner
-- reads it rather than keeping a second copy. `ServerScriptService.Shop` is NOT required here.
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))

local Body = require(script.Body)
local Markers = require(script.Markers)
local Penalty = require(script.Penalty)
local Phase = require(script.Phase)
local Roster = require(script.Roster)
local Scene = require(script.Scene)
local Score = require(script.Score)

local Match = {}

-- Exported for specs only, exactly as Boar.Brain and Weapon.StateMachine are.
Match.Phase = Phase
Match.Roster = Roster
Match.Score = Score
Match.Markers = Markers
Match.Penalty = Penalty
Match.Body = Body
Match.Scene = Scene

-- THE QUICK TEST'S BOUNDARY READ, AND THE STUDIO GUARD IS PART OF IT (task 83). Pure and exported
-- so the guard itself is testable: `quickTestEnabled(true, false)` is false, which is the assertion
-- that says a live server can never run this however the attribute got there. It is the only flag in
-- this repo whose value is ANDed with anything, and it is ANDed with `RunService:IsStudio()`.
local function quickTestEnabled(flagOn: boolean, isStudio: boolean): boolean
	return flagOn == true and isStudio == true
end

-- HOW CLOSE TO A PERSON A SHOT MAY PASS, AS ONE LOCAL READ BY TWO ROWS (task 248). A table literal
-- cannot read its own field, and the SAFETY LOCK's radius is *measured from the existing Penalty
-- config* (the Director's dispatch) rather than chosen again -- so the two rows below cannot drift
-- apart by an edit to one of them. The idiom `Shotgun.CONFIG`'s own `DRIVE_SHELLS` already uses.
local SAFETY_MISS_STUDS = 12

-- Every number the drive has. K marks Karen's feel values. No magic number anywhere else in this
-- system, and none of this is replicated: a client that knows the safety numbers can dodge the rule
-- by eye (design section 3.4).
Match.CONFIG = {
	-- the drive
	DRIVE_SECONDS = 600, -- K, Karen: "10-minute drives"
	-- THE START OF A DRIVE, AND IT IS ONE NUMBER FOR THREE THINGS (task 158). Karen: *"timer when
	-- start, timer like 10s to find position to stand"*, *"Hunter in position where can select
	-- within 10s"*, *"Beater start in line with others and countdown when drive starts"*. The start
	-- card is up for this long, the hunter's stand timer counts this down, and the beaters are held
	-- at their line for exactly it -- all three read `phaseEndsAt`, so they cannot disagree.
	-- 20 -> 10 -> 15. The old 20 was "long enough to read the teams and walk to your post"; 10 was
	-- the number Karen named in task 158; 15 is the number she named after playing it (2026-10-12
	-- ~10:40: *"for hunter a bit more time like 15s to find a place"*).
	-- IT IS STILL ONE NUMBER FOR ALL THREE, which is task 158's decision and nothing in her words
	-- asks to split it: the hunter gets his 15 s to pick a stand, the start card is up for the same
	-- 15 s (longer, so no less readable), and the beaters stand at their line 5 s longer -- against
	-- the two-minute walk task 162 measured, that is 4% of a drive.
	-- backups/2026-10-11_task158_intermission_20s.txt, backups/2026-10-12_task163_intermission_10s.txt.
	INTERMISSION_SECONDS = 15, -- K
	-- HOW LONG THE RESULTS SCENE IS UP (task 159): the Scoring phase, unchanged in length. Karen's
	-- scene -- the animals laid out, the four lights, everybody standing round them and the results
	-- table on screen -- lasts exactly this, and then the next drive starts as it always did.
	-- KAREN, 2026-10-18 ~14:20: *"time for next rount is to long make 8s max"*. THIS is the number
	-- she was reading: the results panel's own footer says `NEXT DRIVE IN n` and counts this down
	-- (`Hud.ScorePanel.Footer`), and it was 25. The drive ends, everybody is held at the gathering
	-- scene, and that hold IS this row -- so it is the one wait between two drives that she spends
	-- doing nothing at all.
	--
	-- THE OTHER WAIT IS `INTERMISSION_SECONDS` 15 AND IT IS DELIBERATELY LEFT ALONE, reported to the
	-- Director rather than cut: that one is Karen's own (task 158, *"timer like 10s to find position
	-- to stand"*), she is respawned, free and walking to her stand through it, and it is the
	-- countdown the start card shows. Cutting the results hold is what she asked for; cutting her
	-- stand timer is not.
	SCORE_SECONDS = 8, -- K, 2026-10-18 ("make 8s max"); 25 from task 32 until then
	-- THE SECOND WAY A DRIVE CAN END (task 159). Karen: *"Timer or when all beaters cross line of
	-- hunters"*. The clock still ends every drive; this can only ever end one EARLIER, and only when
	-- there is at least one real beater in it -- `Phase.beatersThrough` is the whole rule.
	--
	-- Not on `Match.WORLD_OVERRIDABLE`: whether a drive can end early is a RULE, like the safety
	-- numbers, and one world answering it differently would be two answers to one rule in the world
	-- Karen plays. It is still reachable by parameter from a spec, which is what the flag discipline
	-- is actually for.
	END_ON_BEATERS_CROSS = true, -- K, Karen's second ending
	-- HOW FAR PAST THE HUNTERS' LINE "CROSSED" IS. Measured against the nearest STAND, not against
	-- the line marker's own position, because the forest's road is a sine whose plane is up to 30
	-- studs off the real road (`docs/design/forest-drive.md` section 6.1) -- so the stand a beater
	-- walks past is the only honest reference. 10 studs is just past a hunter's own post: a beater
	-- standing ON the line, or walking up to it and stopping, has not crossed it.
	BEATER_CROSS_MARGIN_STUDS = 10, -- K

	-- THE DRIVE'S OWN HORN SIGNAL (task 163; the SOUND of it replaced in 166). KAREN, 2026-10-12
	-- ~10:40: *"when hunt starts 3 longer horn calls and when ends the same"*, and ~16:00, having
	-- heard it: *"for start and end of drive has to be tuturutu tu tu different one"*.
	--
	-- WHETHER THE DRIVE SIGNALS IS THIS TABLE'S; WHAT THE SIGNAL SOUNDS LIKE IS NOT. The two
	-- phrases and their cuts out of their own assets are `Horn.CONFIG.SIGNAL` -- shared, because
	-- the client is what plays them -- and a client that knows how long a horn note is learns
	-- nothing it is not already being told. This boolean is the drive's half of it: the phase
	-- machine emits one `signal` feed entry at GO and one at the end, and with this false it emits
	-- neither, so both states are reachable by parameter from a pure spec.
	--
	-- A PLAIN BOOLEAN AND NOT A FLAG ROW, the same call task 159 made for `SCENE.ENABLED`: this is
	-- not an experiment whose default has to be decided, it is a thing Karen asked for in her own
	-- words, and the client half cannot read a flag anyway (an override is an attribute on
	-- ServerStorage, which no client sees).
	SIGNAL_ENABLED = true, -- K

	-- HOW LONG THE BEATERS STAND STILL AFTER THE DRIVE'S CLOCK STARTS (task 168). KAREN, 2026-10-12
	-- ~21:45, verbatim: *"you can't move as a beater before horn made signal and there should be
	-- countdown"*.
	--
	-- GO IS THE END OF THE FANFARE, AND THIS IS THE FANFARE -- not a feel number, a measurement of
	-- the asset: `Horn.CONFIG.SIGNAL.PHRASES.start` is cut 0.42 -> 2.60 out of "Bugle Call (a)", so
	-- `Horn.signalSeconds("start")` is 2.18 s. Reading it here rather than typing 2.18 is the whole
	-- point: the day Karen picks a different phrase, the hold follows it with no second edit.
	--
	-- IT IS NOT ON `Match.WORLD_OVERRIDABLE`. "When may a beater move" is a RULE of the drive, like
	-- the safety numbers, and a world answering it differently would be two answers to one rule in
	-- the world Karen plays. A spec reaches both states by parameter (`Phase.goHoldSeconds`), which
	-- is what the flag discipline is actually for.
	GO_HOLD_SECONDS = HornData.signalSeconds("start", HornData.CONFIG),

	-- THE RESULTS SCENE (task 159). Karen: *"all they standing around the animals there is light on 4
	-- corners and then showing image transperent with results table"*. `Match.Scene` is the only
	-- writer of the Instances; these are its numbers, and every one of them is handed in as a
	-- parameter so a pure spec can lay the scene out with no world.
	--
	-- THE TABLE ITSELF IS NOT HERE AND HAS NO NUMBER HERE: it is the drive's own score panel, drawn
	-- by `src/client/Hud` from the snapshot this owner already broadcasts. One score, one wire.
	SCENE = {
		ENABLED = true,
		-- HOW FAR BEHIND THE STANDS the animals are gathered, on the hunters' own side of the line --
		-- in the forest that is the ground beside the road by the stands, which is where Karen's
		-- beaters and hunters meet. Behind, never in front: the gathering spot must not be in the
		-- corridor the drive comes down.
		GATHER_BEHIND_STUDS = 24, -- K
		SPACING_STUDS = 6, -- K, a boar's own width plus room to walk between them
		MAX_ANIMALS = 12, -- a cap, so a long drive's row cannot run off into the wood
		-- SEVERAL ROWS (task 168). KAREN, 2026-10-12 ~21:45: *"animals layed down in front in
		-- several lines if more"*. Six to a row is 30 studs of front at `SPACING_STUDS` -- about
		-- what the ring can stand round and see at once -- and the cap of 12 is then two full rows.
		PER_ROW = 6, -- K's "several lines"
		-- DEEPER THAN THE SIDEWAYS SPACING, because an animal is 4 studs LONG and 1.6 wide
		-- (`ANIMAL_SIZE`) and lies across the row: 6 studs side to side is a gap you can walk
		-- through, and 6 studs nose to tail would be two studs of gap.
		ROW_SPACING_STUDS = 8,
		RING_RADIUS_STUDS = 14, -- K, close enough to see the animals, far enough not to stand on them
		-- HOW FAR OUTSIDE THE ANIMALS THE PEOPLE STAND once the block is bigger than the ring (task
		-- 168): the ring grows to the block's corner plus this, so a bag of twelve is stood AROUND
		-- rather than stood on. Below that it is `RING_RADIUS_STUDS` exactly, so the scene Karen has
		-- already seen does not move.
		RING_MARGIN_STUDS = 6,
		CORNER_STUDS = 16, -- K, the four lamps stand just outside the ring
		-- ...AND WHAT "JUST OUTSIDE THE RING" MEANS, now that the ring can grow (task 168). 14 + 2 is
		-- 16, which is `CORNER_STUDS`: with a small bag the four torches stand exactly where they
		-- stood before this task, and the floor is what makes that true rather than a coincidence.
		CORNER_MARGIN_STUDS = 2,
		-- The display animal: a boar-sized box, scaled per kind. The SCALES are data here rather than
		-- a require of `Boar.CONFIG.KINDS`, because the scene must not learn what a boar is -- and
		-- they are the same three numbers that config holds (male 1.0, female 0.85, cub 0.45).
		ANIMAL_SIZE = Vector3.new(1.6, 1.4, 4.0),
		-- ...and `legendary = 1.35` since task 219, for the same reason the other three are here: the
		-- scene must not learn what a boar is, and these are the same four numbers
		-- `Boar.CONFIG.KINDS` holds. A trophy laid out at the gathering is 35 % longer than the males
		-- beside it, which is the whole point of having shot it.
		-- ...AND THE THREE RED DEER (task 223). **THEY ARE AGAINST THE BOAR MALE'S 5.5 STUDS LIKE
		-- EVERY OTHER ROW HERE, AND THAT IS THE TRAP IN THIS LINE**: `Boar.CONFIG.KINDS[kind].scale`
		-- for a deer is against the STAG's 7.05, because a deer's boxes are built from the deer's
		-- own `BODY_SIZE`. The two numbers for one animal mean different things, so they are not the
		-- same number and must never be "tidied" into each other. Written as the division that
		-- produced them:
		--   stag 7.05 / 5.5 = 1.2818   hind 6.03 / 5.5 = 1.0964   calf 3.49 / 5.5 = 0.6345
		-- `tests/server/deer.spec.luau` asserts `ANIMAL_SCALES[kind] * 5.5` against each kind's
		-- baked length for all SEVEN kinds, which turns this comment into arithmetic a spec checks.
		ANIMAL_SCALES = {
			male = 1.0,
			female = 0.85,
			cub = 0.45,
			legendary = 1.35,
			stag = 1.2818,
			hind = 1.0964,
			calf = 0.6345,
		},
		ANIMAL_COLOR = Color3.fromRGB(58, 48, 42),
		POST_SIZE = Vector3.new(0.6, 10, 0.6),
		POST_COLOR = Color3.fromRGB(70, 60, 50),
		LIGHT_COLOR = Color3.fromRGB(255, 190, 120), -- K's "light on 4 corners", warm: it is dusk
		-- 4 -> 2.5 (task 168), and it is the LAMP MOVING that asks for it, not taste: the light used
		-- to hang on the post, which put it at the post's own middle with five studs of post above
		-- it; it hangs on the FLAME now, in the open at the top. The same number therefore reads
		-- brighter, and the first photograph of the new scene came back washed out (rule 5 -- the
		-- screenshot is why this line moved). Karen's to retune, and it is one number.
		-- backups/ has no entry for this: the old value is right here in the comment.
		LIGHT_BRIGHTNESS = 2.5,
		LIGHT_RANGE_STUDS = 60,
		-- THE BURNING END OF A TORCH (task 168). KAREN, 2026-10-12 ~21:45: *"torches 4 in corners"*,
		-- and the Director: *"real torches: a post with a FIRE"*. The flame is a small NEON box so
		-- the source reads bright even where `Fire`'s own particles are thin, and `Fire` is the
		-- flicker -- it animates itself, so nothing in this repo writes a light per frame.
		--
		-- `Fire.Size` IS IN THE ENGINE'S OWN UNITS AND NOT IN STUDS: the property page documents the
		-- default as 5 with no conversion, so these are the default flame scaled down to something a
		-- 10-stud post can carry, and what it looks like is a screenshot (rule 5) rather than an
		-- estimate. `Heat` is how fast it rises.
		FLAME_SIZE = Vector3.new(0.9, 0.9, 0.9),
		FLAME_COLOR = Color3.fromRGB(255, 200, 130),
		FIRE_SIZE = 4,
		FIRE_HEAT = 9,
		FIRE_COLOR = Color3.fromRGB(255, 160, 60), -- the body of the flame
		FIRE_SECONDARY_COLOR = Color3.fromRGB(120, 40, 10), -- its smoky tips
	},
	-- ------------------------------------------------------------ the bots (task 161)
	--
	-- HOW MANY BODIES A DRIVE HAS, AND WHETHER ANY OF THEM ARE FAKE. Karen's v1 rule, 2026-10-11:
	-- *"Let's make 4 hunters 4 beaters"* -- and she plays SOLO, so without this a drive is one person
	-- in an empty wood. Every slot no real player fills is a visible R15 rig: a beater in the orange
	-- vest walking the wood and blowing the real horn, a hunter standing on a free stand.
	--
	-- THIS TABLE IS "HOW MANY AND WHETHER", WHICH IS THE DRIVE'S QUESTION. How a bot BEHAVES -- its
	-- pace, its lanes, its horn rhythm, its own clock -- is `Bots.CONFIG`, because it is the bots'
	-- question. Two tables, disjoint facts: the split `Match.CONFIG.SOUNDER` and `Boar.CONFIG.SOUNDER`
	-- already have.
	--
	-- `ENABLED` IS THE ONLY PERMITTED SHAPE for a flagged value: one read, at this boundary, passed
	-- inward as `config` -- so `Bots.Fill.counts` drives both states from a table while the flag
	-- itself sits at OFF. BOTS is a nested TABLE and `Match.mergeConfig` refuses tables, so it is not
	-- on `Match.WORLD_OVERRIDABLE` and no world can give it a second value.
	-- Flag: docs/design/feature-flags.md. Design: docs/design/bots.md section 13.
	BOTS = {
		ENABLED = Flags.isOn("DRIVE_BOTS"),
		-- K, Karen's sentence taken literally. A target of 0 for a side is that side off, which is
		-- ioquake3's own `bot_minplayers <= 0` switch per team rather than a second boolean.
		TARGET = { hunters = 4, beaters = 4 },
		-- The two targets summed: a ceiling that holds whatever the targets say. `bots_fill.spec`
		-- asserts `TARGET.hunters + TARGET.beaters <= MAX_BOTS`, the
		-- `MAX_ALIVE_BOARS >= SOUNDER.MAX_SIZE` idiom -- so the trim inside `Fill.counts` is
		-- unreachable with the shipped numbers as a CHECKED claim, not as a coincidence.
		MAX_BOTS = 8,
		-- HOW FAR PAST THE HUNTERS' LINE A BOT BEATER WALKS. Twice `BEATER_CROSS_MARGIN_STUDS`, so a
		-- bot that reaches its goal has crossed WITH MARGIN and the drive's end does not turn on one
		-- stud of float error.
		GOAL_PAST_LINE_STUDS = 20,
	},

	-- DIRECTOR DECISION F (audit-003 must-fix 1), Milestone 1 only: ONE player is a drive. A solo
	-- player is a SHOOTER and is armed, so the harness's single Play player keeps its gun and the
	-- weapon and camera client specs stay green. Raise to 2 before release.
	-- See reviews/task-32/DESIGN_DELTA.md.
	MIN_PLAYERS = 1,
	MAX_PLAYERS = 16,
	ODD_PLAYER_TEAM = "Shooters" :: any, -- K; see the delta: with one player this makes them a shooter
	SWAP_TEAMS_EACH_DRIVE = true, -- K, everybody wants to shoot
	DRIVERS_MAY_SHOOT = false, -- K, the brief: a switch, default OFF
	END_ON_LAST_BOAR = false, -- K, a drive is ten minutes, not "until the boars run out"
	-- WHO IS HELD AT THE START LINE while the countdown runs (task 158): the beaters, so they start
	-- in a line together and go on GO. A HUNTER IS NOT HELD -- the same ten seconds is the one he
	-- walks to his stand with. A team name and not a boolean, because `Phase.heldUserIds` then
	-- answers "who is held" from one value a spec can point at either side.
	START_HOLD_TEAM = "Drivers" :: any, -- K, Karen's beaters
	-- WHAT HAPPENS AT 0 TO A HUNTER WHO IS NOT AT HIS STAND: HE CANNOT SHOOT UNTIL HE STEPS IN, and
	-- THAT IS STILL NOT A PUNISHMENT (task 171; until it, task 158's answer here was "nothing", and
	-- it said so). KAREN, 2026-10-12: a hunter not inside his stand circle when the 15 s end *"CAN'T
	-- SHOOT until he steps in"*, with no punishment -- so the drive answers WHERE his circle is
	-- (`Match.standAreaFor`, radius `STAND_RADIUS_STUDS`) and the WEAPON refuses the shot
	-- (`Weapon.Rules.outsideStand`). Nothing is taken away: no points, no coins, no tie, no shell.
	-- The only PENALTY in this system is still the safety one (firing toward the drive, `SAFETY_*`
	-- above) plus the piglet's negative points. The soft wall Karen has felt is
	-- `ForestTest.boundary`, which belongs to the Forest Test world and still runs there; it keeps a
	-- locked hunter inside the same circle this rule measures, so in that world the refusal is what
	-- answers for the window BEFORE his pick locks.
	-- WHAT YOU MAY SHOOT, AS THE RULE REALLY IS IN THE CODE (task 158). The start card asks "what
	-- they can shoot", and Karen's words were *"wild boar -- male, female; NOT piglets/cubs"*.
	--
	-- SINCE TASK 170 A PIGLET IS A PENALTY, which is the half of her rule the code can hold.
	-- Karen, 2026-10-12: shooting a piglet is a penalty. `POINTS.KIND.cub` is `-10` -- one whole
	-- male, the figure `SAFETY_PENALTY` already uses for the other thing you must not shoot -- so
	-- the card reads `cub -10` and a player is told the price before the drive rather than
	-- discovering it on the board. The note below changed in the SAME commit as that number, which
	-- is exactly what the comment that used to stand here promised.
	--
	-- WHAT IS STILL NOT IN THE CODE: the shot is not REFUSED. A refusal is a weapon-side rule with
	-- its own owner and its own task (TASKS.md row 158a); the price is this one.
	-- THE RED DEER IS ON THE CARD SINCE TASK 234, and the row NAMES THE SPECIES KEY rather than the
	-- printed words. Karen, 2026-10-21, having played: *"I didnt see deer red tag why ?"* / *"I want
	-- to see a deer"*. The deer have been licensed quarry since task 223 -- `POINTS.KIND` has
	-- carried `stag 20, hind 6, calf -10` since that day and `Licences.ROWS.reddeer` has said
	-- `licence = true` since task 171 -- and the one screen that answers *"what may I shoot"* has
	-- never mentioned them.
	--
	-- `species = "boar"` AND NOT `"WILD BOAR"`: the KEY, which `Match.quarryRows` turns into the
	-- label through `Licences.ROWS`, so the words a player reads and the rule the weapon enforces
	-- come from one row. A literal still passes through unchanged (`quarryRows` falls back to what
	-- it was given), which is why every spec that hands this function its own table still reads the
	-- same.
	--
	-- `legendary` IS STILL DELIBERATELY NOT IN THIS LIST (task 219): it is one of the MALES grown
	-- old, not a fourth animal, and `Report.kindWord` names it where there is room -- the hit card's
	-- plate, the TAB report's ANIMAL column. Task 219's reason was the start card's four-row
	-- ceiling; task 234 raised that ceiling to eight for the deer, and the trophy's reason did not
	-- change with it.
	--
	-- NOTHING ELSE READS THIS: a legendary is still a WILD BOAR to `Licences` and to
	-- `Match.classifyTarget`, which learn the species from the animal and never from here.
	QUARRY = {
		{ species = "boar", kinds = { "male", "female", "cub" } },
		{ species = "reddeer", kinds = { "stag", "hind", "calf" } },
	},
	PLACE_TIMEOUT = 5,
	STAND_HEIGHT_STUDS = 3.5, -- how far above a post's top face a character is put down
	-- HOW BIG THE STAND IS, AS AN AREA (task 171). 12 studs (~3.4 m) is the radius task 166
	-- measured, drew as a neon ring and Karen accepted as `ForestTest.PICK.standRadiusStuds`; this
	-- is the DRIVE's copy of that number, for the world whose stands are posts rather than picks.
	-- Karen, 2026-10-12: a hunter not inside his circle when the 15 s end *"CAN'T SHOOT until he
	-- steps in"*, and there is still NO PUNISHMENT -- see `Weapon.Rules.outsideStand`.
	STAND_RADIUS_STUDS = 12,

	-- boars (design section 6.3)
	BOARS_PER_DRIVE = 6, -- K
	FIRST_RELEASE_SECONDS = 20, -- K, the drivers need to be walking before the first boar moves
	RELEASE_INTERVAL_SECONDS = 90, -- K, 20 + 5*90 = 470 s, so the last boar has ~130 s of drive left
	RELEASE_JITTER_SECONDS = 15, -- K, so the drive is not a metronome
	-- 4 -> 6 (Director decision H, and it is OUTSIDE the flag, stated so it is declared rather than
	-- discovered): a sounder may be 5, and a ceiling of 4 would make a 5-boar release PERMANENTLY
	-- impossible and stall the drive on a retry loop. MAX_ALIVE_BOARS >= SOUNDER.MAX_SIZE is an
	-- invariant asserted in match_live.spec, not a coincidence of two numbers. With the flag off it
	-- only widens a guard the 90-second singles rhythm never approaches.
	MAX_ALIVE_BOARS = 6, -- never exceed Boar.CONFIG.maxBoars, and carcasses do not count

	-- THE SOUNDER: how big a release is and how often (design, "the sounder release" and "the
	-- sounder numbers"). How a sounder BEHAVES is Boar.CONFIG.SOUNDER and is not this system's.
	SOUNDER = {
		-- THE ONLY PERMITTED SHAPE for a flagged value (feature-flags.md section 10): one read, at
		-- this boundary, passed inward as `config`. Off it, every size is 1 and the schedule is the
		-- one this drive has always had. Flag: docs/design/feature-flags.md
		ENABLED = Flags.isOn("BOAR_SOUNDERS"),
		MAX_SIZE = 5, -- K, Karen: groups of 2-5
		SIZE_WEIGHTS = { 40, 20, 18, 12, 10 }, -- K, sizes 1..5: 40% singles, a five once in ten
		-- NOT AN INDEPENDENT NUMBER: match_phase.spec asserts it equals the weighted mean of the row
		-- above to 0.01, so retuning the weights cannot leave the pacing reading a stale average.
		EXPECTED_SIZE = 2.32,
		TAIL_SECONDS = 90, -- K, the last release lands this long before 0:00 so it can reach the line
		GAP_MIN_SECONDS = 45, -- K, two sounders never arrive on top of each other
		GAP_MAX_SECONDS = 180, -- K, never more than three minutes of empty wood
		HOLDBACK_WARN = 20, -- consecutive hold-backs of one sounder before this warns, once
	},

	-- ------------------------------------------------------------ the quick test (task 83)
	-- STUDIO ONLY. One read, at this boundary, ANDed with IsStudio and passed inward as `config` --
	-- so `Phase` needs no flag and no service, and a spec drives both states with a table
	-- (feature-flags.md section 13.3). Karen: "just for testing could be much faster that they cross
	-- a line small group and then you can shoot".
	QUICK_TEST = quickTestEnabled(Flags.isOn("QUICK_TEST"), RunService:IsStudio()),
	QUICK_TEST_INTERMISSION_SECONDS = 3, -- enough to read "Drive 1" and turn round
	-- NOT ZERO, AND THE SCREENSHOTS ARE WHY. At zero the sounder is released the instant the drive
	-- starts -- about two seconds after Play -- and a boar at SPRINT_SPEED is across the road before
	-- a player has finished loading in: five capture bursts in a row caught an empty road, twice on
	-- either side of the run. Five seconds is still "much faster" (Karen's ask against 20 + 20), and
	-- it is long enough to spawn in, look up the drive and see them coming.
	QUICK_TEST_FIRST_RELEASE_SECONDS = 5,
	QUICK_TEST_SOUNDER = 3, -- K's "small group": the first release only, then the drive is normal
	-- JUST NORTH OF THE ROAD, in front of the first shooter post. The road is the one strip of
	-- ground the map GUARANTEES flat at groundY (`Map.ROAD`: halfWidth 8, then a 24-stud verge eased
	-- up to the terrain), and `Runtime:spawn` OVERWRITES the caller's Y with groundY -- so a spawn
	-- far off it puts a boar inside a hill, where nobody sees it.
	--
	-- 90 WAS TRIED AND IS NOT WHAT SHIPPED. A 90-stud run-up would be a longer look, and three
	-- capture bursts at 90 showed an empty road: either the boars were off the flat strip and under
	-- the ground, or the screenshot tool's 3-6 second round trip kept missing them. I could not tell
	-- which from a picture, so this is the number whose ground is GUARANTEED. If the run-up is worth
	-- having, the honest way to buy it is a flat pad near the line from the map generator, not a
	-- guess about terrain height (TASKS.md row 83a).
	QUICK_TEST_AHEAD_STUDS = 12,
	QUICK_TEST_SPREAD_STUDS = 6,
	-- DEAD AHEAD OF THE POST, and 0 is a measurement rather than a default: at 12 studs the visible
	-- half-width of a 70-degree view is 12 * tan(35) = 8.4 studs, so a sideways offset of 25 or 60
	-- -- both tried -- puts the sounder outside the frame of the player it is released for. The
	-- shooter looks up the drive; this is what he is looking at.
	QUICK_TEST_SIDE_STUDS = 0,
	-- THE PHANTOM DRIVER, and it is what makes them RUN rather than graze. A boar flees only when a
	-- threat is inside DETECT_RADIUS (40), and in a quick test there may be no driver on the map at
	-- all -- a solo player is a shooter. So while the quick test's first sounder is young, the boar
	-- world is told there is a driver standing this far BEHIND it, which is exactly what a real
	-- driver walking up would look like: the sounder bolts for the exit, across the road, in front
	-- of the shooters. It is not a player, carries no userId, and `Penalty` therefore never sees it.
	-- AND THEY KEEP COMING. One fast crossing is three seconds of boar and then nine minutes of
	-- nothing -- which is not a playtest, it is a blink: measured here, the whole first release was
	-- across the road before the screenshot tool could take its second frame. A quick test releases
	-- the drive's whole budget on this rhythm instead of the real 90 seconds, so a player gets three
	-- or four crossings in the first minute and can practise the shot. The drive's budget
	-- (BOARS_PER_DRIVE) is unchanged: this is pace, not quantity.
	QUICK_TEST_INTERVAL_SECONDS = 15,
	QUICK_TEST_PUSH_BEHIND_STUDS = 30,
	QUICK_TEST_PUSH_SECONDS = 25, -- after this the phantom is gone and the drive is the real drive

	-- points (design section 7.1 -- STALE since task 160, which retuned this table whole; the
	-- Architect owns that file and the Builder does not write designs. Note:
	-- docs/research/2026-10-12-scoring.md. The table it replaced, with its rollback:
	-- backups/2026-10-12_task-160_points-by-hit-zone.txt)
	POINTS = {
		-- WHAT AN ANIMAL IS WORTH, AND IT IS THE ANIMAL AND NOTHING ELSE (task 160). Karen's answer
		-- in her own design doc, 2026-10-10: *"How many shoot and male is more worth then famale"*,
		-- and 2026-10-11: *"first place ofc more legendary more ect"*.
		--
		-- THIS IS THE ROW TASK 158 SAID WAS MISSING. Its start card refused to pretend the rule
		-- existed -- *"`POINTS.KILL` scores a kill by HIT ZONE alone"* -- and left it as a decision
		-- waiting for Karen. This is that decision: `Score.kill` reads `record.kind`, the field the
		-- kill record has carried since task 120 (*"WHICH ANIMAL DIED"*), and reads nothing else.
		--
		-- THE HIT ZONE IS NOT GONE FROM THE GAME, ONLY FROM THE MONEY. It still decides whether the
		-- animal dies and how far it runs (`Boar.Wound`), it is still on the kill record, still
		-- drawn on the drive report's silhouette in its own ring colour and still printed in that
		-- report's ZONE column. What it no longer does is set a price.
		KIND = {
			male = 10, -- K, the unit of this game's currency: every other number is read against it
			female = 6, -- K, *"male is more worth then famale"* -- and a sow is still worth shooting
			-- NEGATIVE SINCE TASK 170, AND THAT DAY HAS COME: Karen, 2026-10-12, shooting a piglet
			-- is a penalty. Task 160 left this row at `+2` with a promise -- *"The day Karen
			-- protects cubs (her doc says 'NOT piglets/cubs') this row goes to 0 or negative and
			-- that sentence changes in the same commit"* -- and `QUARRY_NOTE` (retired in 201 part 3) changed
			-- in this one.
			--
			-- `-10` AND NOT `0`: one whole male, the same figure `SAFETY_PENALTY` uses for the other
			-- thing you must not shoot. A cub was `+2`, so this is a 12-point swing, which is what
			-- makes shooting one a MISTAKE rather than a smaller prize -- and at
			-- `Economy.CONFIG.COINS_PER_POINT = 2` it costs him 20 coins as well. The old value and
			-- its rollback are in backups/2026-10-13_task-170_cub-points-and-quarry-note.txt.
			cub = -10, -- K
			-- THE ANIMAL ARRIVED (task 219). This row was task 160's price with nothing behind it --
			-- *"the row is live the instant a kind by that name dies"* -- and `Boar.CONFIG.KINDS` now
			-- has a `legendary`: one per drive, in one drive in four, 35 % bigger, twice as hard to
			-- kill anywhere but the vitals, and warier. **THE NUMBER DID NOT MOVE**, because it was
			-- Karen's (*"first place ofc more legendary more ect"*) and 2.5 males is what she
			-- approved; what changed is that something can now die and claim it. At
			-- `Economy.CONFIG.COINS_PER_POINT` it pays 50 coins, through the same rule as every other
			-- kill and with no second price anywhere.
			legendary = 25, -- K
			-- THE RED DEER (task 223), AND THE PENALTY IS THE ROW. Karen bought a red deer family
			-- on 2026-10-20 and made it licensed quarry: *"deer also will be possible to shoot if
			-- you have purchased deer license"*.
			--
			--   stag 20   TWO MALES. Above a male boar because it is the licensed, rarer,
			--             paid-for quarry -- the 750-coin DEER LICENCE is bought for this shot --
			--             and BELOW the legendary boar's 25, which stays this game's ceiling
			--             because that number is Karen's own (*"first place ofc more legendary more
			--             ect"*) and because a legendary is a 1-in-4 trophy while a stag is in most
			--             drives.
			--   hind 6    EXACTLY THE SOW'S PRICE, and that is the point rather than a coincidence:
			--             a hind and a sow are the same thing to a hunter -- the female of the
			--             species -- so they cost the same and no gap has to be invented.
			--   calf -10  A CALF IS A PIGLET. Karen's rule of 2026-10-12 is that shooting the young
			--             is a penalty, and this is the identical figure `cub` carries and the one
			--             `SAFETY_PENALTY` uses for the other thing you must not shoot.
			--
			-- **THERE IS NO SECOND MECHANISM FOR THE CALF.** `Score.kill` prices a kill off
			-- `record.kind` and off nothing else, so a negative row IS the penalty -- the same way
			-- `cub = -10` has been the piglet's penalty since task 170. Nothing in `Penalty`,
			-- nothing in the weapon, no refusal: the price is the rule, and at
			-- `Economy.CONFIG.COINS_PER_POINT = 2` it costs him 20 coins as well.
			stag = 20, -- K's species, the Director's "stag > male boar"
			hind = 6, -- K, the Director's "hind ~ female boar": the sow's own number
			calf = -10, -- K, the piglet's rule applied to the piglet's equivalent
			-- An unnamed kind: never free, and counted by the owner as `stats().unknownKindKills`.
			-- A kind typo must show up as a NUMBER rather than as an animal that quietly scores
			-- nothing -- the same discipline the retired `KILL.unknown` kept for zones.
			unknown = 6,
		},
		-- RESCALED WITH THE KILL ROW, and it is scale and not taste (note section 4): against a
		-- 100-point head shot this was a tenth, and against a 10-point male the old 10 would make an
		-- assist worth a whole animal. The ratio Karen approved is what was kept. It reads as the
		-- same thing a push reads as, which is what an assist IS: you moved it or you hurt it and
		-- somebody else finished it.
		ASSIST = 3, -- K
		ASSIST_MIN_DAMAGE = 25, -- K, a quarter of Boar.CONFIG.WOUND.LETHAL: one pellet is not an assist
		-- WHAT A BEATER EARNS FOR AN ANIMAL HE PUSHED THAT SOMEBODY THEN SHOT (task 160). Karen,
		-- 2026-10-10: *"beater ranking also is cool"*. It was `PUSH = 25`, which paid EVERY driver
		-- inside `PUSH_RADIUS`; it now pays the animal's LAST credit before it died, which is
		-- ioquake3's own rule for a support action (`g_team.h`: *"awarded for returning a flag that
		-- causes a capture to happen almost immediately"*, GPL-2.0, quoted in the note).
		--
		-- 3 AND NOT 1, against that source's own tenth: a beater's drive is six animals at best, so
		-- at a tenth his column is noughts and the ranking Karen asked for cannot be read. At 3, a
		-- beater who walks four animals onto the guns (12) is level with a hunter who shot a male
		-- and a cub (12) -- the two jobs in one currency, which is the whole reason this award
		-- exists (`Score`'s own header). `BEATER_PUSH = 0` switches the idea off, as `PUSH = 0` did.
		BEATER_PUSH = 3, -- K
		PUSH_RADIUS = 60, -- K, 1.5x Boar.CONFIG.DETECT_RADIUS
		PUSH_WINDOW = 20, -- K, seconds before the kill
		ESCAPE_WOUNDED = 0, -- K, "take the shot you can make"
		-- RESCALED FOR THE SAME REASON AS `ASSIST`, and this one matters most: -50 was half a good
		-- kill, and against a 10-point male it would be FIVE animals -- more than a good drive
		-- earns, so one violation would end a player's board irrecoverably. -10 is one whole animal,
		-- which is a harder penalty than the old half and still survivable. The real punishment is
		-- unchanged and is Karen's: you are tied to a tree for the rest of the drive.
		SAFETY_PENALTY = -10, -- K, 1.7b
	},
	PUSH_SAMPLE_HZ = 2,

	-- the safety rule (design section 11.4). Karen's rule as written: tied to a tree until the drive
	-- ends, visible to everyone, announced in the feed.
	SAFETY_ENABLED = true,
	SAFETY_MISS_STUDS = SAFETY_MISS_STUDS, -- K, ~3.4 m: a shot that passes within three metres of a person is a shot at them
	SAFETY_RANGE_STUDS = 330, -- Shotgun.CONFIG.RANGE_STUDS.Slug; past it nothing arrives
	-- The depth of a person, added to where the shot stopped. See Penalty.judge: without it a shot
	-- that HITS a driver stops on his surface, a stud in front of his root, and would be judged
	-- harmless. reviews/task-35/DESIGN_DELTA.md.
	SAFETY_BODY_STUDS = 4,
	SAFETY_GRACE_SECONDS = 0, -- K, no grace: the rule is the rule from the first second

	-- ------------------------------------------------- THE SAFETY LOCK (task 248)
	--
	-- KAREN, 2026-10-23: *"I still can shoot towards hunters and beaters"*. The trigger does NOT
	-- FIRE while the shot line passes within `SAFETY_LOCK_STUDS` of ANY person -- human or bot,
	-- hunter or beater -- and what she gets instead is `NOT SAFE` and a dry click. The shot never
	-- exists: no shell, no pellet, no penalty, which is the shape of every rule Karen has asked for
	-- since task 171 (*"thye just can't shoot them"*, `Weapon.Rules`'s own header).
	--
	-- A DATA ROW SO IT CAN CHANGE (the Director's dispatch). `SAFETY_LOCK_ENABLED = false` is the
	-- game before this task, bit for bit, and both states are reachable BY PARAMETER because
	-- `Match.lineUnsafeFor` is pure and takes its config.
	--
	-- THE PENALTY IS NOT RETIRED AND THIS IS NOT DOUBLE HANDLING, for the reason
	-- `Weapon.Rules`'s header already gives about the beater gate: a refused shot never fires
	-- `SafetyViolated` at all, so the two can never both judge one shot. What is left for the
	-- PENALTY is the shot that got through -- the man who walked into a line that was clear when
	-- the trigger broke (the Director: *"moving targets"*) -- which is exactly the case a lock
	-- measured at the trigger cannot see.
	SAFETY_LOCK_ENABLED = true,
	-- MEASURED FROM `SAFETY_MISS_STUDS` AND DELIBERATELY INSIDE IT, AND THIS IS THE ONE DECISION OF
	-- THIS TASK THE DIRECTOR MAY WANT TO MOVE -- it is one line, which is why it is a data row.
	--
	-- The dispatch says *"measure the danger radius from the existing Penalty config"*, and the
	-- arithmetic that follows from the two rules reading the SAME geometry is this: the lock's
	-- people list (`Match.peoplePositions`, everybody) is a SUPERSET of the tie's
	-- (`driverPositions`, players on the push team), so at an EQUAL radius every shot the tie would
	-- punish is a shot the lock has already refused -- and both are measured in the same frame, from
	-- the same muzzle, down the same segment. At 12 the tie would therefore never fire again, and a
	-- rule that silently retires another rule has retired it without saying so. Karen's tie is her
	-- own rule from her design doc; this task was not asked to end it.
	--
	-- So the lock is 6 studs (1.7 m, a man's width and some) and the tie is still 12: point the gun
	-- within 6 studs of ANY person and the trigger does nothing, fire between 6 and 12 of a DRIVER
	-- and you are tied to a tree. `zz_tie_to_a_tree.spec` stages both, which is what makes the band
	-- real rather than a sentence here: `BESIDE_STUDS` is 10.
	--
	-- IT WAS 8 FOR ONE AFTERNOON AND THE TWO-PLAYER RUN IS WHY IT IS 6. At 8 the tie proof's own
	-- shot -- 10 studs beside a driver 25 studs out, which that spec measures at `miss 9.3 of 12`
	-- from the EYE -- came back `unsafe-line` twice in two runs (`test2-t248a.log`,
	-- `test2-t248b.log`, identical): the lock measures from the MUZZLE down the server's own aim
	-- ray, and a 1.3-stud margin is less than the difference between those two lines. A band whose
	-- edges are closer together than the two ways of measuring it is not a band. At 6 the same shot
	-- has 3.3 studs of margin above the lock and 2.7 below the tie, and both rules are provable in
	-- one run.
	SAFETY_LOCK_STUDS = 6,
	-- THE ONLY PERMITTED SHAPE for a flagged value: a read, never a literal beside a flag of the
	-- same name. There is still one source of truth (Flags.DEFAULTS, reviewed in git) and
	-- Match.CONFIG is still the one table the drive's DEFAULTS live in -- and this key is not on
	-- `Match.WORLD_OVERRIDABLE`, so no world can give the rule a second value (task 157,
	-- docs/design/forest-drive.md section 4.2.3). Penalty.expired is untouched: it already
	-- takes `config`, which is what lets a spec exercise BOTH states without touching this one.
	-- K, Karen's rule as written; flag: docs/design/feature-flags.md
	TIE_UNTIL_DRIVE_END = Flags.isOn("TIE_UNTIL_DRIVE_END"),
	-- M2.8d, and the same one permitted shape: ONE read, at this boundary, passed inward as a
	-- parameter. `Match.Body.dressFor` and `Body.dress` both take the config, so a spec drives the
	-- ON branch with a table while the flag itself stays OFF -- which is what "merged dark" means.
	-- K: Karen chose the items (2026-09-26, shooters a hat, drivers a vest); flag:
	-- docs/design/feature-flags.md, design: docs/design/map-generator.md section 10.
	OUTFITS_ENABLED = Flags.isOn("ORANGE_OUTFITS"),
	TIE_SECONDS = 60, -- K, used only when the flag above is false (Penalty.expired)
	TIE_GAP_STUDS = 2.5, -- K, studs from the trunk's SURFACE, on the side the offender came from
	ROPE_COLOR = Color3.fromRGB(170, 130, 85), -- K, checked on screen: see the note in Body
	ROPE_THICKNESS = 0.3,

	-- the wire (design section 11.5)
	STATE_MIN_INTERVAL = 0.25,
	STATE_HEARTBEAT = 5,
	MATCH_STEP_HZ = 4,

	SEED = 1,
}

Drive.deepFreeze(Match.CONFIG)

-- ------------------------------------------------------------------ the config THIS drive runs on
--
-- `Match.CONFIG` above is the frozen DEFAULTS and stays exported, because every spec reads it. This
-- is the table the drive is actually running on, and in the DEV place it IS that table -- the same
-- object, by identity, so `Match.config() == Match.CONFIG` is the whole proof that a world which
-- injects nothing changed nothing (docs/design/forest-drive.md section 4.2.5).
--
-- A WORLD MAY OVERRIDE A FEW SCALARS AT THE COMPOSITION ROOT, and nothing else may write this:
-- `Match.start` sets it from `world.config` and `Match.stop` puts it back. Every read inside this
-- file goes through it, so a drive whose clock says 300 cannot have a safety grace that says 600.
local config = Match.CONFIG

-- WHICH KEYS A WORLD MAY OVERRIDE, AND THE LIST IS THE WHOLE GUARD (design section 4.2.3). It is an
-- ALLOW-list rather than a deny-list because the refusals are the point: the safety and tie numbers
-- are not replicated precisely so a client cannot dodge the rule by eye (docs/design/drive.md
-- section 3.4), and a per-world value for one of them would be a second answer to one rule IN THE
-- WORLD KAREN ACTUALLY PLAYS. The roster five (MIN_PLAYERS, MAX_PLAYERS, ODD_PLAYER_TEAM,
-- SWAP_TEAMS_EACH_DRIVE, DRIVERS_MAY_SHOOT) are the Director's decisions 1 and 7 themselves: a world
-- that could change them could silently make a solo player a beater. Flag-derived keys
-- (OUTFITS_ENABLED, QUICK_TEST*) stay out because a second value for a flag is a second boundary
-- read (docs/design/feature-flags.md). Everything else is simply unasked-for, and an untested
-- override is worse than none.
Match.WORLD_OVERRIDABLE = table.freeze({
	DRIVE_SECONDS = true,
	INTERMISSION_SECONDS = true,
	SCORE_SECONDS = true,
	BOARS_PER_DRIVE = true,
	FIRST_RELEASE_SECONDS = true,
	RELEASE_INTERVAL_SECONDS = true,
	MAX_ALIVE_BOARS = true,
	STAND_HEIGHT_STUDS = true,
	PLACE_TIMEOUT = true,
})

-- WHAT MAY BE SHOT, IN THE WORDS THE START CARD SHOWS (task 158). PURE and exported, so a spec
-- reads the rule with no drive, no client and no world -- the same shape `Phase.waitingFor` already
-- has: the SERVER states the rule in words and the Hud only lays them out, so there is one source
-- for "what can I shoot" and the client holds no second copy of it.
-- ...AND SINCE TASK 160 EACH KIND CARRIES WHAT IT IS WORTH, off `POINTS.KIND` and no second copy of
-- it. Karen asked *"How many shoot and male is more worth then famale"*, and the one screen that
-- answers "what may I shoot" is the one place that answer belongs.
--
-- IT SENDS ROWS AND NOT A SENTENCE SINCE TASK 201 PART 3, and that is the whole change here. It
-- used to format `WILD BOAR, POINTS: male 10, female 6, cub -10` -- one line carrying three prices,
-- which is the first fault the Designer's start-card spec names (`startcard-spec.md` section 0,
-- after Karen on 2026-10-18: *"this message has to be improved maybe each from new line ask designer
-- more user friendly"*). A LINE CANNOT BE LAID OUT: a card that wants a tick, a noun and a signed
-- number in three columns has to have three values, so the server sends the three values. The RULE
-- is still only here -- which kinds are quarry and what each is worth -- and the client still holds
-- no copy of it; what moved to the client is where the number is drawn. The old function, its
-- `QUARRY_NOTE` and the specs that asserted its wording are in
-- `backups/2026-10-18_task-201-3_quarry-lines.txt` (rule 7).
--
-- `QUARRY` STILL SAYS WHICH ANIMALS ARE IN THE DRIVE AND `POINTS.KIND` SAYS WHAT EACH IS WORTH, and
-- the two tables are not merged: `POINTS.KIND` carries a `legendary` row with no animal behind it
-- and an `unknown` fallback, and neither of those is quarry. A kind the points table has no row for
-- is sent with `points = nil` rather than with a wrong number, and the card then draws the row with
-- no value cell -- the same discipline as the old label's *"THE WORD ONLY WHEN THERE IS A NUMBER
-- UNDER IT"*.
-- ...AND SINCE TASK 234 EACH ROW ALSO CARRIES WHETHER SHOOTING IT NEEDS A LICENCE, off
-- `Licences.ROWS` and no second copy of it. The card has to say *"NEEDS LICENCE"* over the deer and
-- the client must not be the thing that knows which species those are: a second copy of *"a red
-- deer needs a licence"* living on the client is exactly the two-correct-pieces-of-code failure
-- `Licences`' own header refuses.
--
-- `species` ON THE WIRE IS STILL THE PRINTED LABEL -- `WILD BOAR`, `RED DEER` -- and `QUARRY`'s is
-- now the KEY, so this is where one becomes the other. A `QUARRY` row whose species is not a
-- licence key passes through UNCHANGED and carries `licence = false`, which is what makes every
-- spec that hands this function a literal `"WILD BOAR"` read exactly as it did.
function Match.quarryRows(cfg): { { species: string, kind: string, points: number?, licence: boolean } }
	local rows = {}
	local prices = (cfg.POINTS or {}).KIND or {}
	for _, row in ipairs(cfg.QUARRY or {}) do
		local licence = Licences.row(row.species)
		local label = if licence ~= nil then licence.label else row.species
		for _, kind in ipairs(row.kinds) do
			table.insert(rows, {
				species = label,
				kind = kind,
				points = prices[kind],
				licence = Licences.required(row.species),
			})
		end
	end
	return rows
end

-- PURE, and exported so the spec drives every branch without a world (design section 4.2.2).
--
-- NO OVERRIDES MEANS THE DEFAULTS THEMSELVES, by identity -- that is what makes "DEV did not change"
-- one assertion instead of a list of thirty numbers.
--
-- TABLES ARE REFUSED, and the evidence for that is in this repo: `Boar.newRuntime`'s merge replaces a
-- nested block wholesale, which cost `ForestTestBoot` five hand-written `table.clone`s and
-- `Boar.newRuntime` two key-by-key special cases, each with a comment about what nil-for-every-number
-- did. One refusal here is cheaper than three repairs there.
function Match.mergeConfig(defaults, overrides)
	if overrides == nil or next(overrides) == nil then
		return defaults
	end
	-- `table.clone` of a frozen table returns an UNFROZEN copy (the idiom `Flags.resolve` uses), so
	-- the defaults are never mutated.
	local merged = table.clone(defaults)
	for key, value in pairs(overrides) do
		assert(
			Match.WORLD_OVERRIDABLE[key] == true,
			string.format("Match.start: a world may not override %s (see Match.WORLD_OVERRIDABLE)", tostring(key))
		)
		assert(
			type(value) ~= "table",
			string.format("Match.start: %s is a block; a world may override scalars only", tostring(key))
		)
		merged[key] = value
	end
	return Drive.deepFreeze(merged)
end

-- The table this drive is running on. `== Match.CONFIG` in the DEV place, and a spec says so.
function Match.config()
	return config
end

type TeamName = Roster.TeamName

local world: any = nil
local started = false
-- WHETHER JOINING THE SERVER IS JOINING THE DRIVE (task 177). True in every world that injects
-- nothing, so the DEV place and every spec written before this task behave exactly as they did; a
-- world with a lobby passes `enrol = false` and then decides for itself who is in the hunt.
-- `Match.stop` puts it back, so a spec that started a lobby world cannot leave the next one gated.
local autoEnrol = true
local state = Phase.initial(config)
local board = Score.new()
local markerSet: any = nil
local connections: { RBXScriptConnection } = {}
local heartbeat: RBXScriptConnection? = nil
local remotes: any = nil

local names: { [number]: string } = {} -- userId -> name, for the feed and the board
-- Who is tied, and to what. THE ONE TRUTH about it: mayCarryWeapon reads it, the snapshot reports it
-- and the release effect empties it. The pure machine does not track it -- two writers of one fact is
-- the failure docs/PROJECT_CONTEXT.md names three times.
local tied: { [number]: { tree: BasePart, at: number } } = {}
-- WHO ASKED TO BEAT AND WAS SEATED ON THIS DRIVE (task 229, review round 1 finding 1). The same
-- shape as `tied` above and for the same reason: `Roster.overruled` has to be able to tell a
-- privilege the BALANCE beat from one its owner GAVE UP, and the man's own wish is SPENT by the
-- very assignment it is about -- `Lobby.beaterWishes()` is empty one lobby scan later. So the pure
-- machine decides it and this is the one table that remembers it, for exactly one drive.
local seatedWishes: { [number]: boolean } = {}
-- WHO IS HELD STILL, AND THERE ARE TWO OCCASIONS NOW: the beaters at the start line for the length
-- of the countdown (task 158), and EVERYBODY at the results scene for the length of Scoring (task
-- 159). The same shape as `tied` above and for the same reason: the pure machine SAYS who must be
-- held and this is the one table that remembers it, so the character watch can put the hold back on
-- the character `placePlayers` is about to respawn. Emptied by `free`, which `Phase.enterAssigning`
-- and `Phase.enterWaiting` emit, and which the time section emits once `goFreeAt` has passed -- so a
-- hold cannot outlive its phase. SINCE TASK 168 `enterRunning` EMITS IT ONLY WHEN `goHoldSeconds` IS
-- ZERO, because GO is the end of the start fanfare and the line stands still for the length of it.
local heldStill: { [number]: boolean } = {}
-- WHO IS THROUGH THE HUNTERS' LINE, keyed the way a horn's cooldown is keyed -- `tostring(userId)`
-- for a player, the slot id for a bot (task 168). KAREN, 2026-10-12 ~21:45: *"when beater cross the
-- line of hunter it's done for him cant use sound anymore"*.
--
-- ONE MEASUREMENT, NOT TWO. `Match.beaterCrossing` already walks every beater in the line against
-- `Match.crossedLine` once per tick to decide whether the drive is over (task 159); this is the
-- per-beater half of that same walk, written down. Asking the geometry a second time at the instant
-- of a blast would be a second answer to "has this man crossed", which is this project's named
-- failure mode -- and the staleness it buys is at most one match tick.
local throughLine: { [string]: boolean } = {}
-- WHAT THIS DRIVE SHOT, in the order it was shot, for the results scene to lay out (task 159). It is
-- NOT a second score: it carries the kind and the hit zone and no points at all, and the board
-- (`Score`) is still the one answer to how the drive went. Cleared when a drive starts.
local driveKills: { any } = {}
local characterWatch: { [number]: RBXScriptConnection } = {}
-- WHICH CHARACTER THE DRIVE GAVE THIS PLAYER (task 248). Written by `applyPlace` out of
-- `Body.place`'s own `onCharacter`, which is the one place that knows; read by `respawnSweep` below,
-- whose whole rule is *"the character he is in is not the character we gave him"*.
--
-- IT HOLDS A REFERENCE TO A MODEL AND THAT IS WHY IT IS CLEARED in `Match.forget`, in the sweep's
-- own withdrawal and in `stop`: a destroyed character compares unequal to everything, which is
-- correct for the rule and a leak if the row outlives the player.
local placedCharacter: { [number]: Model } = {}
local pushCredit: { [string]: { [number]: number } } = {} -- boarId -> userId -> last time near
local accumulator = 0
local sinceSample = 0
local sinceMarkers = 0
local markersStale = false
local lastBroadcast = -math.huge
local lastSent: any = nil -- the snapshot the clients were last actually sent
local snapshotCache: any = nil

local stats = {
	drives = 0,
	kills = 0,
	escapes = 0,
	releases = 0,
	releasesDeferred = 0,
	placementsMissed = 0,
	-- How many times a world answered nil for where a player of this team stands (task 157).
	placementsNowhere = 0,
	-- HOW MANY CHARACTERS THE FLOOR NET PUT BACK (task 192). IT MUST STAY 0: the placement rule in
	-- `Body.onGround` is the fix and this net is only under it, so a session in which this is not
	-- zero is a session with a placement bug the net is hiding. Karen's own words were *"when drive
	-- ends I am underground ... when new round I die"*, and this is the number that says whether
	-- that is still happening. Note: docs/research/2026-10-15-one-placement-rule.md
	rescuedFromUnderGround = 0,
	emptyTeamDrives = 0,
	-- A KILL WHOSE ANIMAL THIS TABLE HAS NO PRICE FOR (task 160; it was `unknownZoneKills`, the same
	-- diagnostic pointed at the retired zone table). It is the kind, not the zone, that now decides
	-- what a kill pays, so it is a kind typo that must show up here as a number.
	unknownKindKills = 0,
	-- How many (animal, beater) credits the horn has written this session (task 160). It is the one
	-- number that says the second door into push credit is actually open, and a drive where a beater
	-- blew a horn at a sounder and this stayed 0 is a defect.
	hornCredits = 0,
	killSignalMissing = 0,
	broadcasts = 0,
	testSeconds = 0, -- seconds of test time this owner has been given; 0 in every real session
	ties = 0,
	tiesWithoutAnchor = 0,
	-- The start line (task 158): how many holds were applied, and how many were put back onto a
	-- character that arrived after them -- which is every one of them in a real drive, because
	-- `placePlayers` respawns the player the hold is for.
	holds = 0,
	holdsReapplied = 0,
	-- THE END OF A DRIVE AND THE RESULTS SCENE (task 159), as numbers rather than a feeling: how many
	-- drives ended because the beaters were through rather than on the clock, how many scenes were
	-- built and taken down, how many animals were laid out, how many players were stood round them,
	-- and how many times a world had no stands to gather anything behind.
	drivesEndedByBeaters = 0,
	scenes = 0,
	scenesCleared = 0,
	scenesNowhere = 0,
	-- HOW MANY TIMES THE WORLD NAMED THE SPOT ITSELF (task 191), rather than the drive deriving it
	-- from the middle stand. It is the one number that tells "the gathering happened at the cabin"
	-- apart from "the gathering happened in the grass again": in the Forest Test it must equal
	-- `scenes`, and in the DEV place it must be 0.
	sceneWorldSpots = 0,
	sceneAnimals = 0,
	-- ...AND HOW MANY OF THEM WERE THE REAL ANIMAL AND HOW MANY THE GREY BOX (task 173). Summed from
	-- `Scene.stats()` after each build, which is the module that knows: these are totals across the
	-- session, exactly like every other counter here -- and `Scene`'s own pair is PER BUILD, which is
	-- what the console line beside them prints (round 1, finding 1).
	sceneModels = 0,
	sceneBoxes = 0,
	sceneMoved = 0,
	-- THE BOTS (task 161), and these two are the gap that makes a failure visible: how many rigs the
	-- drive asked for at this boundary, and how many of them the results scene actually stood in the
	-- ring. A build that failed is `botsWanted > botsFilled`, not silence.
	botsWanted = 0,
	botsFilled = 0,
	botSyncs = 0,
	-- HOW MANY TIMES THE DRIVE BOUNDARY REBUILT THE BOTS. It must equal the number of drives that
	-- have had bots in them -- round 2 finding 1 was this number being 0 from drive 2 on.
	botRebuilds = 0,
	sceneBotsMoved = 0,
	violations = 0,
	safetySignalMissing = 0,
	-- HOW MANY TRIGGER PULLS THE SAFETY LOCK REFUSED (task 248), and how many men a respawn took out
	-- of a live drive. Two numbers rather than two beliefs: a session where `safetyLocked` stayed 0
	-- is a lock Karen can shoot straight through, and one where `withdrawals` stayed 0 while she was
	-- pressing Reset is her own bug still there under a different trigger.
	safetyLocked = 0,
	withdrawals = 0,
	-- The release, counted three ways, because "six boars were released" can now mean two sounders
	-- and one single, and a stall looks like nothing at all from the outside.
	soundersReleased = 0,
	boarsReleased = 0,
	sounderHoldbacks = 0,
	-- HOW LONG A PLAYER WAITED FOR THE FIRST BOAR OF THIS SERVER, in seconds from this module's
	-- load, and -1 until one is released (Task 79). `FIRST_RELEASE_SECONDS` says 20 seconds INTO
	-- THE DRIVE, but a player's wait also carries the intermission and however long it takes to put
	-- everybody on a post -- and placing somebody 1,400 studs away in a streamed world is not the
	-- same job as placing them in a 400-stud arena. That difference is a number now instead of a
	-- guess, and it is the number Karen would feel at 10:00.
	firstReleaseAfterSeconds = -1,
	-- THE LOBBY'S SEAM (task 177), as three numbers rather than a belief: how many players the lobby
	-- put into the drive, how many times it emptied the roster at the end of one, and how many teams
	-- were handed back to nil. A lobby session where `enrolments` stayed 0 is a lobby nobody could
	-- leave, and one where `unassigned` stayed 0 is a player standing by the lodge still wearing an
	-- orange vest.
	enrolments = 0,
	dismissals = 0,
	unassigned = 0,
}

-- When this module loaded, which on a live server is server start: the only clock a "how long did
-- the player wait" number can be measured against. `os.clock()` and not the drive's own `now()`,
-- because the drive's clock carries `testOffset` and a spec that advanced it would flatter this.
local bootAt = os.clock()

local phaseSignal = Instance.new("BindableEvent")
local scoredSignal = Instance.new("BindableEvent")
local punishedSignal = Instance.new("BindableEvent")
Match.PhaseChanged = phaseSignal.Event
Match.Scored = scoredSignal.Event
Match.Punished = punishedSignal.Event

function Match.stats()
	return table.clone(stats)
end

function Match.phase(): string
	return state.phase
end

-- WHICH DRIVE THIS IS, counting from 1; 0 while `Waiting` (task 179). A plain read, so a
-- `world.markers` provider may call it from inside `dispatch` -- which is the one place the Forest
-- Test needs it, because the drive boundary is where it deals a new drive layout
-- (`docs/design/drive-layouts.md` 5.2).
function Match.driveNumber(): number
	return state.driveNumber
end

-- The snapshot the clients were LAST ACTUALLY SENT, or nil before the first broadcast. Not the same
-- as Match.snapshot(), and the difference is the point: see `broadcast`.
function Match.lastSent()
	return lastSent
end

function Match.trackedPlayers(): number
	local n = 0
	for _ in pairs(names) do
		n += 1
	end
	return n
end

-- Is this player tied to a tree right now? The one public reader of `tied`, so a spec and the
-- weapon's arming policy ask the same question of the same table.
function Match.isTied(userId: number): boolean
	return tied[userId] ~= nil
end

-- Is this player held still right now -- at the start line (task 158) or at the results scene (task
-- 159)? The one public reader of `heldStill`.
function Match.isHeld(userId: number): boolean
	return heldStill[userId] == true
end

-- WHICH SIDE THIS DRIVE PUTS A PLAYER ON, as the DRIVE sees it (task 159). Read-only, and it exists
-- because "his team" has two representations -- `Player.Team`, which `Body.setTeam` writes for the
-- engine to replicate, and `state.assignment`, which this system actually decides from -- and when a
-- two-player failure says "one of them is held and should not be", the first question is whether
-- those two agree. A spec can now print both instead of inferring one from the other.
function Match.assignmentOf(userId: number): TeamName?
	return state.assignment[userId]
end

-- WHAT THIS DRIVE HAS SHOT SO FAR, in order, as the results scene lays it out (task 159). A copy, so
-- a caller cannot write the drive's record.
function Match.driveKills(): { any }
	return table.clone(driveKills)
end

-- WHO ASKED TO BEAT AND WAS SEATED ON THIS DRIVE (task 229, review round 1 finding 1). A COPY, so
-- nothing outside this owner can write the record `roleOverruled` is computed against -- the
-- `driveKills` rule above. EMPTY in every build with no lobby, which is every harness run.
function Match.seatedWishes(): { [number]: boolean }
	return table.clone(seatedWishes)
end

-- THE TEST SEAM: THE DRIVE'S OWN CLOCK, MOVED FORWARD (TASKS.md 38a(i)).
--
-- Every transition in this system is time-driven from `phaseEndsAt`, and `phaseEndsAt` is the only
-- clock (design section 4.1) -- so a drive boundary is 600 seconds away and NOTHING in the suite
-- could ever watch one. Six queued notes sat behind that: the drive-start rows, the award the
-- violation publishes, `Match.forget`, and the rest. Adding seconds to this owner's own clock is the
-- whole seam: no number changes, no phase is skipped, the machine takes exactly the transitions it
-- would have taken ten minutes later, and the code under test is the production code.
--
-- IT IS GATED EXACTLY LIKE THE TEST RUNNERS, and the gate is TestKit's, not a second copy of it:
-- Studio, plus a harness token under TestKit.TOKEN_MAX_AGE seconds old. Karen's playtests write no
-- token (tools/studio_mcp.py clears it after every run), and a published place has no TestKit at all
-- -- which is why this reaches it through FindFirstChild and a pcall rather than a require at the
-- top of the file: the publish step strips TestKit (TASKS.md row 2) and this owner must not break
-- when it does. A shortened drive can therefore never happen in a playtest or on a live server.
local testOffset = 0

local function testGateOpen(): boolean
	if not RunService:IsStudio() then
		return false
	end
	local module = ReplicatedStorage:FindFirstChild("TestKit")
	if not (module and module:IsA("ModuleScript")) then
		return false
	end
	local ok, kit = pcall(require, module)
	-- activeToken, not openToken: "is a gated test run in progress", not "may a runner start now".
	-- The second is time-limited by design (TOKEN_MAX_AGE = 120 s) and a suite outlives it, so asking
	-- it here refused the seam 200 s into a run. Only TestKit.run sets activeToken, and a playtest
	-- never reaches TestKit.run because nothing writes it a token.
	return ok and type(kit) == "table" and kit.activeToken() ~= nil
end

-- Moves THIS OWNER's clock forward by `seconds`. Returns false, and does nothing, when the gate is
-- shut. The next step sees the new time and the machine transitions on its own.
function Match.advanceForTests(seconds: number): boolean
	if not testGateOpen() then
		return false
	end
	local step = math.max(0, tonumber(seconds) or 0)
	testOffset += step
	stats.testSeconds += step
	return true
end

-- How many seconds of test time this owner has been given. Zero in every real session, and a spec
-- reads it to prove the seam it just used was actually open.
function Match.testSeconds(): number
	return testOffset
end

local function now(): number
	local base = if world and world.now then world.now() else os.clock()
	return base + testOffset
end

local function playersService()
	return if world and world.players then world.players else Players
end

-- The ONE conversion from the server's own clock to the wire's. The server's logic runs on
-- world.now() (os.clock by default, which means nothing across the wire); the snapshot is the only
-- place server TIME appears, as a GetServerTimeNow timestamp the client counts down from locally.
local function serverTimeFor(deadline: number): number
	if deadline == math.huge then
		return 0
	end
	local remaining = math.max(0, deadline - now())
	local clock = if world and world.serverTime then world.serverTime() else Workspace:GetServerTimeNow()
	return clock + remaining
end

-- THE SAME CONVERSION WITHOUT THE CLAMP, for a deadline that is allowed to be in the PAST (task
-- 168). `serverTimeFor` floors the remaining time at zero, which is right for a countdown -- a phase
-- that has ended reads 0 and not a negative number -- and wrong for exactly one field: `holdUntil`
-- stays on the wire for the whole drive so a beater's screen can work out how long ago GO was
-- (`Match.goAgeSeconds`), and a clamped one would read "GO was now" for ten minutes.
local function serverTimeAt(deadline: number): number
	if deadline == math.huge then
		return 0
	end
	local clock = if world and world.serverTime then world.serverTime() else Workspace:GetServerTimeNow()
	return clock + (deadline - now())
end

local function boarsAlive(): number
	if not (world and world.boars) then
		return 0
	end
	local alive = 0
	for _, handle in ipairs(world.boars:boars()) do
		local boarState = handle.state()
		if boarState ~= "DOWN" and boarState ~= "GONE" then
			alive += 1
		end
	end
	return alive
end

function Match.snapshot()
	if snapshotCache then
		return snapshotCache
	end
	-- THE ECONOMY'S TWO NUMBERS, READ ONCE FOR THE WHOLE BOARD (task 170) and not per row: both are
	-- a table lookup out of the read-only view the drive was handed, and `nil` all the way down when
	-- there is no economy at all -- which is this file before task 170, by every branch.
	--
	-- ABSENT IS NOT ZERO. A row carries no `coins` when the flag is off or when that player has no
	-- open profile, and the Hud draws an absent one as `--`: zero would be the server asserting he
	-- has no coins.
	local economy = if world then world.economy else nil
	-- IS THERE MONEY IN THIS BUILD (round 2, finding 1)? `true` only when the economy is actually
	-- running, and the field is ABSENT otherwise -- which is what lets the Hud draw NOTHING with the
	-- flag off instead of a dead `COINS --` on every bar. It is one fact for the whole board, not a
	-- row field: whether money exists is a property of the SERVER, and a per-row copy of it would be
	-- sixteen answers to one question.
	local coinsOn = if economy and economy.enabled() then true else nil
	local balances = if economy then economy.balances() else nil
	local earned = if economy then economy.earned() else nil
	local rows = {}
	for _, row in ipairs(Score.leaderboard(board)) do
		table.insert(rows, {
			userId = row.userId,
			name = row.name,
			team = row.team,
			points = row.points,
			kills = row.kills,
			assists = row.assists,
			pushes = row.pushes,
			violations = row.violations,
			left = row.left,
			coins = balances and balances[row.userId],
			earned = earned and earned[row.userId],
		})
	end
	local tiedList = {}
	for userId in pairs(tied) do
		table.insert(tiedList, userId)
	end
	table.sort(tiedList)
	-- EVERY SHOOTER'S STAND CIRCLE (task 171), from the SAME `Match.standAreaOf` the weapon's fire
	-- gate reads -- one answer, two readers, which is the whole reason it is on the wire. A beater
	-- gets no entry, because he has no stand; a shooter the world has nowhere to put gets none
	-- either, and that absence means "no rule" at both ends.
	local stands: { [string]: any }? = nil
	for userId in pairs(state.assignment) do
		local area = Match.standAreaOf(userId)
		if area ~= nil then
			stands = stands or {}
			(stands :: any)[tostring(userId)] = { centre = area.centre, radius = area.radius }
		end
	end

	snapshotCache = Drive.deepFreeze({
		phase = state.phase,
		phaseEndsAt = serverTimeFor(state.phaseEndsAt),
		driveNumber = state.driveNumber,
		-- The WIRE IS UNCHANGED (design decision L: no sounder field on it). A player is told how
		-- many ANIMALS have been released, which is the number that was always meant.
		boarsReleased = state.boarsReleased,
		boarsLeft = math.max(0, config.BOARS_PER_DRIVE - state.boarsAccounted),
		waitingFor = Phase.waitingFor(state, config),
		-- WHAT MAY BE SHOT IN THIS DRIVE (task 158), AS ROWS SINCE 201 PART 3: one entry per kind,
		-- carrying what that kind is worth. The rule is the server's and the Hud only lays it out.
		quarry = Match.quarryRows(config),
		-- WHAT SHOOTING A PERSON COSTS, so the start card can price the other thing you must not
		-- shoot. The Designer's spec adds that row for a reason worth keeping: *"`SAFETY_PENALTY =
		-- -10` and a tie to a tree for the rest of the drive is a real rule the card never
		-- mentioned, and the beaters are walking toward the hunter while this card is up"*. It is
		-- sent rather than typed into the client for the same reason the quarry's points are: there
		-- is one copy of a rule and it is this one.
		safetyPenalty = config.POINTS.SAFETY_PENALTY,
		-- WHETHER THIS BUILD HAS MONEY IN IT AT ALL (task 170, round 2). Absent means no, and absent is
		-- what the game before task 170 sends -- so a client reading this field is byte-identical to one
		-- that never heard of it.
		coinsOn = coinsOn,
		-- WHERE EACH SHOOTER MAY STAND AND STILL SHOOT (task 171). Absent when nobody has a circle,
		-- which is every build before this task -- so a client that never heard of the field reads
		-- exactly what it always did.
		stands = stands,
		rows = rows,
		tied = tiedList,
		-- THE TWO TASK-168 FACTS, both of them things a beater's own screen says and neither of them
		-- a rule a client gets to decide: WHEN the line may walk (the server holds it) and WHO is
		-- finished (the server refuses the blast).
		holdUntil = serverTimeAt(state.goFreeAt or math.huge),
		through = Match.throughUserIds(),
		-- WHO PAID FOR THE HUNTER'S PLACE AND IS DRIVING ANYWAY (task 221). DERIVED, never stored:
		-- `Roster.overruled` reads the assignment that was actually made, so it cannot go stale
		-- against it and no field is added to `state` -- which is why `Phase.freezeState` and every
		-- `match_*.spec` are untouched.
		--
		-- ABSENT, not an empty array, when there is no economy at all: the `stands` and `coinsOn`
		-- idiom (*"ABSENT means the server never sent it"*), so a build with the flag off is
		-- byte-identical to the one before this task.
		-- IT IS GATED ON `coinsOn` AND NOT MERELY ON A WIRED VIEW (task 221, round 1 finding 2's own
		-- new spec caught this): a view is wired in every world that has an economy at all, so
		-- keying off its existence shipped an empty array to every client with the money switched
		-- OFF. `coinsOn` is the same fact the row beside it keys off, and ABSENT is what a build
		-- without money has always sent.
		roleOverruled = if coinsOn
				and economy
				and economy.alwaysHunters
			-- THE WISHERS ARE PASSED IN AND ARE NEVER NAMED HERE (task 229): a man who ASKED to
			-- beat was not overruled, and telling him he was would be the screen contradicting the
			-- button he pressed.
			--
			-- `seatedWishes` AND NOT `world.roleWishes()` (review round 1, finding 1). The live memo
			-- is EMPTY within 0.1 s of the assignment, because the assignment is exactly what spends
			-- the wish -- so reading it here named the man who had just pressed BEATER for the whole
			-- intermission. This is the set recorded AT the assignment, beside `state.assignment`,
			-- which is the other half of the same one-drive fact. Empty in every build without a
			-- lobby, so the answer is today's list by identity.
			then Roster.overruled(state.assignment, economy.alwaysHunters(), seatedWishes)
			else nil,
	})
	return snapshotCache
end

local function broadcast(force: boolean?)
	if not remotes then
		return
	end
	local at = now()
	if not force and at - lastBroadcast < config.STATE_MIN_INTERVAL then
		return
	end
	lastBroadcast = at
	stats.broadcasts += 1
	-- KEPT, because "what the clients were actually told" is not the same question as "what does
	-- snapshot() say now", and the difference is a real defect this system has already had: the
	-- drive-start push carried the previous drive's score rows while snapshot() read correctly a
	-- quarter of a second later (TASKS.md 32a(c)). It is the payload, frozen, so holding it costs
	-- one reference.
	lastSent = Match.snapshot()
	remotes.MatchState:FireAllClients(lastSent)
end

local function publishFeed(entry)
	if not remotes then
		return
	end
	local filled = table.clone(entry)
	if filled.userId and not filled.name then
		filled.name = names[filled.userId]
	end
	remotes.MatchEvent:FireAllClients(Drive.deepFreeze(filled))
end

-- ----------------------------------------------------------------------------------- the effects
-- The pure machine says what must happen; this is the only place any of it is done.

-- Where a player is standing, or nil. Read-only.
local function characterPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character.PrimaryPart
	return if root then root.Position else nil
end

local function refreshArmingFor(player: Player)
	if world and world.weapon and world.weapon.refreshArming then
		world.weapon.refreshArming(player)
	end
	-- ...AND THIS DRIVE'S SHELLS (task 171). KAREN, 2026-10-10: *"limited ammon per round"*. The
	-- WEAPON decides what a refill is and writes it; the drive only says WHICH drive this is, and
	-- `Weapon.refillForDrive` is level-triggered on that number -- so being called here, on a
	-- transition, a join, a tie and a respawn alike, refills once per drive and dying is not a
	-- resupply. The `Horn.refreshCarry` / `Weapon.refreshArming` discipline, for the same reason.
	if world and world.weapon and world.weapon.refillForDrive then
		world.weapon.refillForDrive(player, state.driveNumber)
	end
end

local function applyAssignTeams(assignment)
	for userId, team in pairs(assignment) do
		local player = playersService():GetPlayerByUserId(userId)
		if player then
			-- CONFIG GOES WITH THE TEAM so the outfit follows it in the same call (M2.8d): an
			-- assignment that swaps two players does not always come with a respawn.
			Body.setTeam(player, team, config)
		end
		board = Score.setTeam(board, userId, team)
	end
	-- THE PERSISTED RECORD MIRRORS THE ROLE HE IS ACTUALLY PLAYING (task 217, write edge 1). It is
	-- HERE, beside `Body.setTeam`, because this is the ONE place a team is written -- so an
	-- assignment this task did not think of (a mid-drive join, a `/beater` request, a second
	-- placement) cannot leave the record stale. That is the shape task 214's root cause in this very
	-- path was missing: a fact written at remembered moments instead of where it is decided.
	--
	-- DURING A DRIVE THE OWED TEAM IS THE TEAM HE IS PLAYING, which is what makes a rejoin resume
	-- the drive he left rather than hand a beater a gun -- Karen's *"no cheating back to hunter"*.
	-- The drive's END is what flips it (write edge 2).
	--
	-- `assignment` is sometimes the whole table and sometimes one row (`{ [userId] = team }`), and
	-- both are correct inputs: the record is per player, so a partial update is a partial update.
	-- The owner derives nothing -- it is handed the table and stores exactly it.
	if world and world.economy and world.economy.noteNextTeams then
		world.economy.noteNextTeams(assignment)
	end
end

-- A TEAM HANDED BACK, and it closes a hole that was invisible until the lobby existed (task 177,
-- design section 4.4).
--
-- THE HOLE, WITH ITS EVIDENCE. `Body.setTeam` is the only writer of `Player.Team`, and its only
-- caller was `applyAssignTeams`, which is only reached from an `assignTeams` effect.
-- `Phase.enterWaiting` emits `clearScene`, `free`, a feed line and a `broadcast` -- no `assignTeams`
-- -- so NOTHING in this repo ever set a team back to nil. Today that is invisible, because
-- `MIN_PLAYERS` is 1 and every tracked player is a participant, so `enterWaiting` is unreachable in
-- a session with anybody in it. With a lobby it is the normal end of every drive, and without this a
-- player standing by the lodge would still be `Player.Team = Drivers`: he would keep the horn
-- (`Horn.setCarryPolicy` reads `Body.teamOf`), keep the orange vest, wear a DRIVER badge and read
-- *"waiting for the drive to start"* instead of the lobby's own line.
--
-- THROUGH `Body`, so `Body` stays the one writer of a team and of what a character wears:
-- `setTeam(player, nil, config)` sets `Neutral` and re-dresses, and `Body.dress` with a nil team
-- destroys the outfit folder and this module's own tagged accessories -- so the vest and the cap come
-- off through the same door that put them on.
--
-- THE HORN AND THE GUN THEN GO ON THEIR OWN, with no new code in either system: `Weapon.Horn`'s
-- carry sweep revokes a tool `Horn.carriesFor(on, nil)` says false for, and the gun's arming sweep
-- does the same through `Match.mayCarryWeapon`, which returns false for a userId with no assignment.
-- WHOM AN `unassign` MAY TOUCH: the ids the effect named, filtered to the ones this owner STILL
-- KNOWS. PURE and exported, the shape `Match.botSlotsFor`, `Match.quickSpawnFor` and
-- `Match.pushCreditWithin` already have, so the rule is a table of cases in a spec rather than a
-- branch nobody can reach.
--
-- IT EXISTS BECAUSE THE EFFECT'S LIST OUTLIVES THE PLAYER (review round 1, finding 1), and the cost
-- was a GHOST on Karen's score board. `Phase.enterAssigning` builds the list from
-- `previousAssignment`, and `Phase`'s `leave` branch clears `participants` and `assignment` and not
-- that -- so a player who disconnects during the results scene is still in it. The owner rebuilds
-- the board from `names` at the same edge, which correctly drops his row; `applyUnassign` then ran
-- `Score.setTeam(board, userId, nil)` unconditionally, and `Score.setTeam` -> `mutable` ->
-- `blankRow(userId, name or tostring(userId))` CREATES a row for a userId it has never seen. The
-- next whole drive showed a player named by his raw userId, with 0 points, not on the server and not
-- even dimmed as `left`.
--
-- `names` IS THE READ, and it is the right one: it is this owner's own register of who is on the
-- server, written by `watchPlayer` and cleared by `Match.forget` BEFORE the `leave` it dispatches --
-- so by the time any later phase edge emits an `unassign`, a departed player is already absent from
-- it. `Body.setTeam` was never the hazard (`GetPlayerByUserId` answers nil and the branch is
-- skipped); the board was.
function Match.unassignTargets(userIds: { number }?, known: { [number]: any }): { number }
	local out = {}
	for _, userId in ipairs(userIds or {}) do
		if known[userId] ~= nil then
			table.insert(out, userId)
		end
	end
	return out
end

local function applyUnassign(userIds: { number }?)
	for _, userId in ipairs(Match.unassignTargets(userIds, names)) do
		local player = playersService():GetPlayerByUserId(userId)
		if player then
			Body.setTeam(player, nil, config)
			stats.unassigned += 1
		end
		board = Score.setTeam(board, userId, nil)
	end
end

-- WHO IS BEING PLACED ON THIS TEAM, AND WHICH OF THEM PAID FOR A HIGH SEAT (task 221).
--
-- IT EXISTS BECAUSE A PER-PLAYER RULE CANNOT BE COLLISION-FREE. The world places one man at a
-- time, so two hunters independently skipping the same seat would land on the same ground stand.
-- This hands the WHOLE LINE to `world.placement`, which deals it in one pass
-- (`HighSeats.dealLine`).
--
-- WHAT `Match` LEARNS IS ONE BOOLEAN PER PLAYER, out of the economy view it already holds for
-- `Match.mayCarryWeapon` and for the hat. It does NOT learn what a high seat is, where the seats
-- are, or which stand anybody gets -- that is the world's, and `ReplicatedStorage.HighSeats` is
-- required by the forest's closure and not by this file. The same boundary
-- `Body.setAccessorySource` already is.
--
-- nil ALL THE WAY DOWN WITH NO ECONOMY: `entitled[i]` is left nil, and nil is "nobody answered",
-- which `Shop.grantsHighSeat` and `HighSeats.dealLine` both read as entitled -- so a build with no
-- economy deals exactly the line it dealt before this task.
local function placementLine(team: TeamName): any
	local ids = {}
	for id, assigned in pairs(state.assignment) do
		if assigned == team then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local economy = if world then world.economy else nil
	local ownedOf = if economy then economy.ownedOf else nil
	local entitled: { boolean? } = {}
	if ownedOf ~= nil then
		for index, userId in ipairs(ids) do
			entitled[index] = Shop.grantsHighSeat(ownedOf(userId))
		end
	end
	return { count = #ids, entitled = entitled }
end

local function indexWithinTeam(userId: number, team: TeamName): number
	local ids = {}
	for id, assigned in pairs(state.assignment) do
		if assigned == team then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for index, id in ipairs(ids) do
		if id == userId then
			return index
		end
	end
	return 1
end

local function applyPlace(userIds: { number }?)
	local targets = userIds
	if not targets then
		targets = {}
		for userId in pairs(state.assignment) do
			table.insert(targets, userId)
		end
		table.sort(targets)
	end
	-- ONCE PER CALL AND NOT PER PLAYER (task 221): the line is the same for everybody on a team,
	-- and building it inside the loop would ask the economy once per man for one answer.
	local lines: { [string]: any } = {}
	for _, userId in ipairs(targets :: { number }) do
		local player = playersService():GetPlayerByUserId(userId)
		local team = state.assignment[userId]
		if player and team and markerSet then
			if lines[team] == nil then
				lines[team] = placementLine(team)
			end
			-- WHERE a player of this team stands may be the WORLD's answer; putting him there is
			-- still `Body`'s and only `Body`'s (design section 4.3.1). The default IS
			-- `Body.placementFor`, with the same argument order, so a world that injects nothing
			-- takes exactly the line this file has always taken.
			--
			-- The Forest Test needs it because its road is a sine curve over ground that climbs 56
			-- studs in 400: `placementFor`'s generic -Z look is up to 23 degrees off the push there.
			local place = if world and world.placement then world.placement else Body.placementFor
			local cframe = place(markerSet, team, indexWithinTeam(userId, team), config, lines[team])
			-- ONE LINE WHEN THERE IS NOWHERE TO PUT HIM, and it is here because the alternative is
			-- what task 157 round 1 spent a measurement on: a player who spawns at the place's own
			-- SpawnLocation looks exactly like a player whose pivot was overwritten, and neither the
			-- harness nor a playtest can tell them apart from the outside. `Body.place` treats a nil
			-- CFrame as "they spawned, and that is not a failure", so this is not an error -- it is
			-- the drive saying which world gave it no answer.
			if cframe == nil then
				stats.placementsNowhere += 1
				print(
					string.format(
						"[match] nowhere to place %s on %s: posts=%d driverStart=%s",
						player.Name,
						tostring(team),
						#markerSet.posts,
						tostring(markerSet.driverStart ~= nil)
					)
				)
			end
			Body.place(player, cframe, config, function(ok)
				if not ok then
					stats.placementsMissed += 1
				end
			end, function(character)
				-- THE DRIVE'S OWN RESPAWN, RECORDED (task 248). Everything after this line that
				-- finds him in a DIFFERENT character knows he made that one himself -- by dying, or
				-- by pressing Reset -- which is the whole of Karen's *"when I respawn I am in lobby
				-- with weapons but I can't go to next hunt"*.
				placedCharacter[userId] = character
			end)
		end
	end
end

local function applyRefreshArming(userIds: { number }?)
	for _, userId in ipairs(userIds or {}) do
		local player = playersService():GetPlayerByUserId(userId)
		if player then
			refreshArmingFor(player)
		end
	end
end

local function applySpawnSounder(position: Vector3?, size: number?, quickSpread: number?, deer: boolean?)
	if not (world and world.boars) then
		return
	end
	local animals = math.max(1, math.floor(size or 1))
	-- NO SECOND GUARD. Phase.maybeRelease already decided, on the same counts this owner gives it;
	-- a second check here is what dropped releases in round 1. Runtime:spawnSounder still ASSERTS at
	-- maxBoars and an assert inside the Heartbeat step would kill the step rather than the spawn, so
	-- the call is wrapped -- and a refusal HANDS THE WHOLE SOUNDER BACK, so it is retried on the
	-- next step instead of vanishing (design section 6.3: deferred, not dropped).
	--
	-- THE PAD IS THE CONTRACT: the runtime is told the radius the MAP guarantees is flat, and
	-- spreads the ring inside it -- because Runtime:spawn overwrites the caller's Y, so a member
	-- placed on a slope would be spawned inside a hill (map-generator.md section 11).
	-- THE EFFECT MAY NAME ITS OWN SPREAD (task 83): the quick test spawns on the road, whose flat
	-- half-width is 8 studs, not on a 30-stud spawn pad. Everything else still gets the pad.
	local spread = quickSpread or (markerSet and markerSet.spawnRadius)
	local ok, handles = pcall(function()
		if world.boars.spawnSounder then
			-- THE FIFTH ARGUMENT IS THE DRIVE'S ONE DEER (task 234): the schedule says THIS release
			-- is it, and the runtime still draws WHICH deer. `nil` on every other release is
			-- exactly the call this owner made before, so a world whose runtime predates the
			-- argument is unaffected.
			return world.boars:spawnSounder(position, animals, spread, nil, deer)
		end
		-- A world without the sounder interface (an older spec's fake) still gets its one boar.
		return { world.boars:spawn(position) }
	end)
	if ok and type(handles) == "table" and #handles > 0 then
		if stats.firstReleaseAfterSeconds < 0 then
			stats.firstReleaseAfterSeconds = math.floor((os.clock() - bootAt) * 10 + 0.5) / 10
		end
		stats.releases += 1
		stats.soundersReleased += 1
		stats.boarsReleased += #handles
	else
		stats.releasesDeferred += 1
		-- ...AND THE DEER GOES BACK WITH IT. A refused release must not spend the drive's one
		-- guaranteed deer group (task 234), or the guarantee would be undone by exactly the case
		-- `releaseFailed` exists for.
		state = Phase.releaseFailed(state, now(), animals, deer)
		snapshotCache = nil
	end
end

local function applyClearBoars()
	-- Through the BOAR's own owner, never by touching an Instance: Boar.Body is the only writer of
	-- a boar's Instances, so the runtime grew a `clear` of its own (Runtime:clear) rather than this
	-- system reaching into Workspace.Boars.
	if world and world.boars and world.boars.clear then
		world.boars:clear("driveOver")
	end
	table.clear(pushCredit)
end

-- One tie. The owner has already decided (the phase is Running, this shooter was not tied, the grace
-- is over and Penalty.judge said yes); this performs it, through Body, which is the only writer of a
-- character's position and of Workspace.DriveMarkers.
local function applyFreeze(userId: number)
	local player = playersService():GetPlayerByUserId(userId)
	if not player then
		return
	end
	-- The POINTS penalty lands either way: the shot was a violation whether or not the map gave us
	-- anything to tie him to. Only the tie itself needs an anchor.
	--
	-- AND THE AWARD IS PUBLISHED, like every other (TASKS.md 35b(b)): Score.violation returns
	-- (board, awards) and only the board was being taken, so Match.Scored carried kills and escapes
	-- but never the -50 -- a listener rebuilding the drive from that signal alone would have missed
	-- every penalty.
	local awards
	board, awards = Score.violation(board, userId, config)
	for _, award in ipairs(awards) do
		scoredSignal:Fire(award)
	end
	stats.violations += 1

	-- WITHOUT AN ANCHOR THE VIOLATION STILL HAPPENED, and everything that does not need a tree still
	-- happens (TASKS.md 35b(c)): the points above, the feed line the machine emits, and Punished.
	-- Only the rope, the freeze and the revoked gun need somewhere to tie him. The half-state the
	-- review found was Punished going missing with them, so a listener saw a feed line and no event.
	local tree = if markerSet then Body.anchorFor(markerSet, characterPosition(player)) else nil
	if not tree or not Body.tie(player, tree, config) then
		-- Never a nil CFrame, which would silently teleport him to the origin (design section 8.4).
		stats.tiesWithoutAnchor += 1
		snapshotCache = nil
		punishedSignal:Fire(userId, Penalty.REASON)
		return
	end
	tied[userId] = { tree = tree, at = now() }
	stats.ties += 1
	snapshotCache = nil -- the tie is part of the snapshot the broadcast effect is about to send
	-- The weapon still decides and still writes: mayCarryWeapon now says no, so the Tool goes.
	refreshArmingFor(player)
	punishedSignal:Fire(userId, Penalty.REASON)
end

local function untie(userId: number)
	tied[userId] = nil
	snapshotCache = nil
	local player = playersService():GetPlayerByUserId(userId)
	if player then
		Body.untie(player)
		refreshArmingFor(player)
	else
		Body.forget(userId)
	end
end

-- The end of a drive frees everybody, which is what TIE_UNTIL_DRIVE_END means.
local function applyRelease()
	for userId in pairs(tied) do
		untie(userId)
	end
	table.clear(tied)
end

-- THE HOLD (task 158 at the start line, task 159 at the results scene). The machine has already
-- decided WHO -- the `START_HOLD_TEAM` of this drive's assignment entering `Assigning`, the whole
-- roster entering `Scoring` -- and WHEN; this performs it,
-- through `Body`, which is the only writer of whether a character can move.
--
-- IT REMEMBERS BEFORE IT WRITES, AND THAT ORDER IS THE WHOLE TRICK: `placePlayers` runs first and
-- calls `LoadCharacter`, so the character being held here is about to be destroyed. `heldStill` is
-- what survives that, and `watchCharacter` puts the hold on the character that arrives -- exactly
-- the way a tie survives the Reset button.
local function applyHold(userIds: { number }?)
	for _, userId in ipairs(userIds or {}) do
		heldStill[userId] = true
		stats.holds += 1
		local player = playersService():GetPlayerByUserId(userId)
		if player then
			Body.hold(player)
		end
	end
end

-- GO, one player changing sides inside the countdown, or the end of the results scene. `userIds ==
-- nil` means EVERYBODY held, which is what the start of a drive and the end of the scene both mean.
--
-- A TIED PLAYER IS NEVER FREED HERE. A tie and a hold are the same freeze in `Body` (one `held`
-- row), so freeing a tied player would hand back his WalkSpeed and leave the rope hanging on a man
-- who can walk. The two still cannot overlap -- ties only exist in `Running`, holds only in
-- `Assigning` and `Scoring`, and `enterScoring`'s `release` empties the ties BEFORE its own `hold`
-- holds anybody -- so this guard is what keeps that true rather than what works around it being
-- false.
local function applyFree(userIds: { number }?)
	local targets = userIds
	if not targets then
		targets = {}
		for userId in pairs(heldStill) do
			table.insert(targets, userId)
		end
		table.sort(targets)
	end
	for _, userId in ipairs(targets :: { number }) do
		if heldStill[userId] and not tied[userId] then
			heldStill[userId] = nil
			local player = playersService():GetPlayerByUserId(userId)
			if player then
				Body.untie(player) -- the one restore: a hold is a tie without the rope
			else
				Body.forget(userId)
			end
		end
	end
end

-- THE REAL ANIMAL FOR ONE OF THE SCENE'S ROWS, or nil (task 173). KAREN, 2026-10-13 ~09:30:
-- *"and after hunt over we need to see boars shooted not boxes when we stand around"*.
--
-- THIS OWNER IS THE WIRE AND NOTHING ELSE. `Match.Scene` owns where each animal lies and which way
-- it faces; the BOAR owns what a boar looks like and how a dead one lies; and this function is the
-- one line that joins them -- the shape `world.placement`, `world.bots` and `world.weapon` already
-- have. It decides nothing, holds nothing and creates nothing.
--
-- NIL IS THE ANSWER FOR EVERY WORLD THAT CANNOT DRAW ONE, and the scene's own grey box is what that
-- means: the DEV quick test (no boar world at all), an older or narrower boar view without the
-- method, `BOAR_MODEL` off, and an asset that has not loaded -- the runtime answers nil for the last
-- two, exactly as a live boar stays a grey box in the same states.
--
-- Note: docs/research/2026-10-13-real-animals-at-the-gathering.md
function Match.displayAnimal(kind: string?, ground: CFrame): Instance?
	local boars = if world then world.boars else nil
	if boars == nil or boars.displayCarcass == nil then
		return nil
	end
	return boars:displayCarcass(kind, ground)
end

-- ------------------------------------------------------------------ the results scene (task 159)
--
-- THE SCENE IS `Match.Scene`'S INSTANCES AND `Body`'S CHARACTERS, and this is the one place either is
-- asked for: the spot and the facing come from `Match.gatherSpot` below, the animals are this
-- drive's own kill record, and WHERE A PLAYER STANDS is still written by `Body` alone.
--
-- A WORLD THAT ANSWERS NOWHERE GETS NO SCENE AND ONE LINE SAYING SO, which is the same shape
-- `applyPlace` already has: a drive whose markers have no stands has nothing to gather the animals
-- behind, and that is a fact about the world, not an error.
local function applyScene()
	if not config.SCENE.ENABLED then
		return
	end
	local spot, facing, fromWorld = Match.gatherSpot()
	if spot == nil or facing == nil then
		stats.scenesNowhere += 1
		print(
			string.format("[match] nowhere to gather the drive: posts=%d", if markerSet then #markerSet.posts else -1)
		)
		return
	end
	stats.scenes += 1
	if fromWorld then
		stats.sceneWorldSpots += 1
	end
	-- ...AND ON THE GROUND UNDER EACH POINT OF IT (task 192), through the one ground reader this
	-- owner already handed `Body`. The animals and the four torches are laid out flat round one
	-- spot, and on a sloped layout that buries half of them.
	local laid = Scene.build(spot, facing, driveKills, config, Match.displayAnimal, Body.groundUnder)
	stats.sceneAnimals += laid
	-- HOW MANY WERE THE REAL ANIMAL (task 173). `Scene` counts both FOR THE SCENE IT JUST BUILT, and
	-- the difference between them is the whole of "did the asset load": a row of grey boxes with
	-- `models = 0` is an asset that never arrived, and the same row with `models = 3` would be a bug
	-- in the scene.
	--
	-- `+=` AND NOT `=` (round 1, finding 1): `Scene.stats()` is now this drive's pair, and every
	-- counter in THIS table is a session total -- `sceneAnimals += laid` on the line above it is the
	-- same sum of the same scenes. So the two sides keep the meaning each of them already had, and
	-- `stats.sceneModels + stats.sceneBoxes == stats.sceneAnimals` across a session.
	local sceneStats = Scene.stats()
	stats.sceneModels += sceneStats.models
	stats.sceneBoxes += sceneStats.boxes
	-- ...AND WHERE IT HAPPENED, IN THE SAME SENTENCE (task 191). A log line saying twelve animals were
	-- laid out in two rows cannot tell the yard beside the cabin from the grass in the forest, and
	-- that is the whole of what Karen asked to change -- so the spot goes in it, with `world` or
	-- `drive` naming which of the two rules answered.
	print(
		string.format(
			"[match] gathered %d animal(s) in %d row(s) at %s (%.0f, %.0f, %.0f): %d real model(s), %d box(es)",
			laid,
			sceneStats.rows,
			if fromWorld then "the world's own spot" else "the drive's spot behind the stands",
			spot.X,
			spot.Y,
			spot.Z,
			sceneStats.models,
			sceneStats.boxes
		)
	)

	-- EVERYBODY STANDING ROUND THEM, in roster order so the ring is the same ring every drive.
	--
	-- ...AND THE BOTS ARE IN IT (task 161). Karen: *"all they standing around the animals"* -- with
	-- one real player that was a ring of one, and the bots that walked the drive are the rest of the
	-- people who were in it. The ring is widened by the rig COUNT, players take slots 1..#ids exactly
	-- as they did, and the bots take what is left: `Scene.ringLayout` already took a count, so this
	-- is one argument and one call, and `Body.stand` is still the only thing that moves a PLAYER.
	local ids = Phase.participantIds(state)
	local botCount = Match.botCount()
	-- ...AND THE RING IS WIDE ENOUGH TO HOLD THE ANIMALS (task 168): `laid` is how many were really
	-- laid out (the cap applied), so the people stand round the block rather than in it.
	local ring = Scene.ringLayout(spot, #ids + botCount, config, laid)
	for index, userId in ipairs(ids) do
		local player = playersService():GetPlayerByUserId(userId)
		if player and ring[index] and Body.stand(player, ring[index], config) then
			stats.sceneMoved += 1
		end
	end
	if botCount > 0 and world and world.bots then
		stats.sceneBotsMoved += world.bots.gather(ring, #ids + 1)
	end
end

local function applyClearScene()
	if Scene.clear() then
		stats.scenesCleared += 1
	end
end

local function applyEffects(effects)
	for _, effect in ipairs(effects) do
		local kind = effect.kind
		if kind == "assignTeams" then
			applyAssignTeams(effect.assignment)
		elseif kind == "unassign" then
			applyUnassign(effect.userIds)
		elseif kind == "placePlayers" then
			applyPlace(effect.userIds)
		elseif kind == "refreshArming" then
			applyRefreshArming(effect.userIds)
		elseif kind == "spawnSounder" then
			applySpawnSounder(effect.position, effect.size, effect.spread, effect.deer)
		elseif kind == "clearBoars" then
			applyClearBoars()
		elseif kind == "freeze" then
			applyFreeze(effect.userId)
		elseif kind == "hold" then
			applyHold(effect.userIds)
		elseif kind == "free" then
			applyFree(effect.userIds)
		elseif kind == "release" then
			applyRelease()
		elseif kind == "scene" then
			applyScene()
		elseif kind == "clearScene" then
			applyClearScene()
		elseif kind == "feed" then
			publishFeed(effect.entry)
		elseif kind == "broadcast" then
			-- Throttled unless the machine says otherwise, and it says so for every phase entry:
			-- STATE_MIN_INTERVAL is the floor between pushes for a busy drive, and the heartbeat is
			-- what catches a client up -- but a PHASE CHANGE arriving up to five seconds late is a
			-- client showing the wrong drive (Phase.enterAssigning).
			broadcast(effect.force == true)
		end
	end
end

-- ------------------------------------------------------------------ the bots (task 161)
--
-- LEVEL-TRIGGERED AND IDEMPOTENT, called once at the end of every `dispatch` AFTER `applyEffects` --
-- the `Horn.refreshCarry` / `Weapon.refreshArming` discipline, because every edge-triggered grant in
-- this repo has been measured missing one. It reads the phase, this drive's roster and the marker
-- set, and does exactly one thing per phase:
--
--   Waiting    clear. No drive, no roster, nothing to fill -- and a server that empties out is not
--              left with eight rigs standing in the wood (`enterWaiting`'s own `clearScene` reason).
--   Assigning  fill. The roster for THIS drive has just been decided by `Roster.assign`, which is
--              ioquake3's *"if (level.intermissiontime) return"* read forwards: never fill while the
--              roster is unknown. Every rig is rebuilt here, so a bot cannot be left on a stand a
--              real hunter now owns.
--   Running    the same fill, and GO. A join, a leave or a `Match.requestTeam` inside the drive
--              changes a side's real count, and the fill is symmetric -- one call site for all four
--              events. `go()` is what releases the walkers, which is how a bot is "held through the
--              countdown exactly as a player is" without ever touching `Body`'s userId-keyed `held`.
--   Scoring    nothing. The rigs are already standing in the ring, moved by `applyScene`'s `gather`
--              inside this same dispatch; the next `Assigning` rebuilds them from scratch.
--
-- AFTER `applyEffects`, NOT BEFORE: `placePlayers` respawns the real players in that list, and the
-- fill has to be measured against the roster the drive has just applied rather than against the one
-- it is leaving.
-- WHICH DRIVE'S BOTS HAVE BEEN BUILT. `nil` means none, which is what `Match.start`, `Match.stop`
-- and `Waiting` all put it back to. It is the only state the bot boundary keeps, and it is a number
-- rather than a boolean so that a drive whose rebuild was missed cannot look done.
local botsRebuiltForDrive: number? = nil

local function syncBots()
	if not (world and world.bots) then
		return
	end
	-- OFF MEANS NOT ONE CALL, which is the strongest form of "today's game bit for bit": with the
	-- flag off this function returns here on every dispatch, so nothing is built, nothing is
	-- destroyed, and `Bots` is never even asked a question. The flag is resolved once per process
	-- (`Flags`), so this cannot change mid-session and leave rigs behind.
	if config.BOTS.ENABLED ~= true then
		return
	end
	local bots = world.bots
	local phase = state.phase
	if phase == "Waiting" then
		bots.clear()
		botsRebuiltForDrive = nil
		stats.botsWanted = 0
		stats.botsFilled = 0
		return
	end
	if phase ~= "Assigning" and phase ~= "Running" then
		return
	end
	-- EVERY DRIVE REBUILDS ITS BOTS FROM SCRATCH, ONCE, ON ITS FIRST `Assigning` TICK.
	--
	-- ROUND 2 FINDING 1, AND IT WAS A GAME BUG KAREN WOULD HAVE HIT ON DRIVE 2. `Bots.fill` only
	-- re-places a slot whose BASE MOVED, and a base does not move between drives: `Body.placementFor`
	-- is a pure function of the marker and the index, and `botSlotsFor` always asks for the same
	-- index. So from drive 2 every bot stayed exactly where the results scene had stood it --
	-- `gathered` still true, so none of them ever walked again, and `Bots.beaters()` still reported
	-- them, in a ring that is 10 to 38 studs PAST the hunters' line. `Match.beaterCrossing` therefore
	-- answered "all of them are through" on the first `Running` tick and `Phase.beatersThrough` ended
	-- the drive instantly, for the rest of the session.
	--
	-- `Waiting` IS NOT THE BOUNDARY, which is what hid it: `Phase.step` goes `Scoring` -> `Assigning`
	-- directly whenever there are enough players and the markers are complete, and `MIN_PLAYERS` is
	-- 1 -- so the one branch that cleared the rigs was never reached between two drives.
	--
	-- THE RULE IS THE DESIGN'S OWN (`docs/design/bots.md` section 8: *"Every rig is rebuilt here"*,
	-- *"removed and re-placed every drive ... and no pool"*), and it is EDGE-triggered on the drive
	-- NUMBER rather than on the phase, because `Assigning` lasts ten seconds and this function runs
	-- on every dispatch -- clearing on the level would destroy and rebuild eight bodies four times a
	-- second. `Match.botsNeedRebuild` is that edge, pure and exported so a spec can state it.
	local drive = state.driveNumber
	if Match.botsNeedRebuild(phase, drive, botsRebuiltForDrive) then
		bots.clear()
		botsRebuiltForDrive = drive
		stats.botRebuilds += 1
	end
	stats.botSyncs += 1
	local counts = Roster.counts(state.assignment)
	local real = { hunters = counts.Shooters or 0, beaters = counts.Drivers or 0 }
	local posts = if markerSet then markerSet.posts else nil
	-- HOW MANY STANDS NO REAL HUNTER IS ON. `nil` means "this caller did not measure the stands"
	-- (the pure specs and any world with no post list), which is NOT the same fact as "there are no
	-- stands" -- so only a real number clamps. The subtraction is `Bots.Fill.standsFree`'s and is
	-- reached through the view, because this owner must not require that one.
	local standsFree = if posts ~= nil then bots.standsFree(#posts, real.hunters) else nil
	local want = bots.fillCounts(real, config, standsFree)
	stats.botsWanted = want.hunters + want.beaters
	if want.hunters + want.beaters == 0 then
		-- NOT A NO-OP: the flag may have gone off, or real players may have taken every slot, and
		-- the fill is symmetric. An empty slot list is what hands the bodies back.
		bots.fill({}, nil)
		stats.botsFilled = 0
	else
		-- THE SAME PLACEMENT SEAM `applyPlace` USES, with the same default and the same argument
		-- order -- so a bot stands where this world says a player of that team stands, and there is
		-- one answer to "where does a hunter stand" rather than two.
		local place = if world.placement then world.placement else Body.placementFor
		-- THE HUNTERS' LINE, LENGTHENED BY THE BOTS (task 221). The real hunters keep indices 1..n
		-- with their own `entitled` answers, and the bots take n+1 upward with none -- so an entitled
		-- hunter always has first refusal of a seat and a bot can only ever take a leftover one.
		local hunterLine = placementLine("Shooters")
		local botLine = {
			count = (real.hunters or 0) + (want.hunters or 0),
			entitled = hunterLine.entitled,
		}
		local slots = Match.botSlotsFor(markerSet, place, real, want, config, botLine)
		local made = bots.fill(slots, nil)
		stats.botsFilled = made.hunters + made.beaters
	end
	-- ...AND THE BOT LINE GOES WHEN THE PLAYERS DO, AND NOT 2.18 SECONDS EARLIER (task 168, round 1
	-- finding 1). `Match.botsMayGo` is the one rule and `syncBots` runs on every dispatch, so the
	-- bots are released on the SAME dispatch as the `free` that lets the people walk.
	if Match.botsMayGo(state) then
		bots.go()
	end
end

-- The one place the machine is driven. Every caller goes through here, so the phase can never
-- advance without its effects being applied and the snapshot cache can never go stale.
-- FORWARD-DECLARED, because `dispatch` below measures the markers on the `Assigning` edge (task
-- 179) and the measurement itself needs `world`, which is set by `Match.start` far below. One
-- declaration, assigned once, at its definition.
local measureMarkers: () -> ()

local function dispatch(event)
	local before = state.phase
	local driveBefore = state.driveNumber
	local effects
	-- EVERY event carries the live boar count, not just the tick. The release guard lives in the
	-- pure machine and reads this; a join or a leave that arrives at a release moment must see the
	-- same world a tick would (round 1, finding 1).
	local filled = table.clone(event)
	if filled.aliveBoars == nil then
		filled.aliveBoars = boarsAlive()
	end
	-- ...AND THE CAPACITY NUMBERS, on every event for the same reason `aliveBoars` is: a release
	-- that lands on a join must see the world a tick would. `boarEntries` counts carcasses, which
	-- `aliveBoars` does not, and it is the number the runtime's own assert is about.
	if filled.boarEntries == nil and world and world.boars and world.boars.count then
		filled.boarEntries = world.boars:count()
	end
	if filled.boarCapacity == nil and world and world.boars and world.boars.capacity then
		filled.boarCapacity = world.boars:capacity()
	end
	-- ...AND, WHILE A DRIVE IS RUNNING, HOW MANY BEATERS ARE THROUGH THE HUNTERS' LINE (task 159).
	-- Measured here because the GEOMETRY is this owner's (the marker set) and the RULE is the pure
	-- machine's (`Phase.beatersThrough`), which is the same split `aliveBoars` above has.
	--
	-- ONLY IN `Running`, which is the only phase that reads it: nothing else is in front of the line
	-- to measure, and a crossing counted in `Assigning` would be a beater standing at his own start.
	if filled.beaters == nil and state.phase == "Running" then
		filled.beaters, filled.beatersAcross = Match.beaterCrossing()
	elseif state.phase ~= "Running" then
		-- NOBODY IS THROUGH OUTSIDE A RUNNING DRIVE (task 168): the measurement above is the only
		-- thing that fills `throughLine`, so without this a beater who finished drive 1 would still
		-- be refused his horn at the start of drive 2.
		table.clear(throughLine)
	end
	-- ...AND WHAT EACH PLAYER IS OWED (task 217), on every event for exactly `aliveBoars`' reason: an
	-- assignment happens on a JOIN as well as on a tick, so a fact read only on ticks would be
	-- missing from the branch that needs it most -- the lobby's own door into the drive.
	--
	-- THE VIEW'S ANSWER IS A MEMOISED FROZEN TABLE, so this is one table read, no clone and no
	-- freeze. That matters while TASKS.md 214a(a) is open: with a refused role ask pending, this
	-- dispatch is stepped at ~15x `MATCH_STEP_HZ`, and a clone here would be ~60 table builds a
	-- second for a table that changes at most twice a drive (design, hazard 5).
	--
	-- IT IS A SUGGESTION AND NEVER A DECISION: `Phase` hands it to `Roster.previousFrom`, and
	-- `Roster.assign`'s balance check may discard the whole swap -- in which case nothing is
	-- consumed, because the only thing that ever WRITES a turn is the drive's end.
	if filled.owed == nil and world and world.economy and world.economy.owedTeams then
		filled.owed = world.economy.owedTeams()
	end
	-- WHO BOUGHT THE HUNTER'S PLACE (task 221), beside the turn and for the identical reasons: one
	-- table read out of a memoised FROZEN table, no clone and no freeze, filled on EVERY event
	-- because an assignment can happen on a join as well as on a tick.
	if filled.alwaysShooters == nil and world and world.economy and world.economy.alwaysHunters then
		filled.alwaysShooters = world.economy.alwaysHunters()
	end
	-- ...AND WHO HAS ASKED TO BEAT THIS ONE DRIVE (task 229), beside the other two and for the
	-- identical reasons: one read of a memoised FROZEN table, no clone and no freeze, filled on
	-- EVERY event because an assignment can happen on a join as well as on a tick.
	--
	-- `world.roleWishes` IS A BARE INJECTED FUNCTION AND NOT A VIEW, because there is exactly one
	-- thing to read and nothing to write -- `world.placement` / `world.groundAt` / `world.standArea`'s
	-- own shape. This owner requires no lobby and learns only a function; the composition root is
	-- what hands it over (`ForestTestBoot`), and a world that injects nothing gets today's game.
	if filled.beaterWishes == nil and world and world.roleWishes then
		filled.beaterWishes = world.roleWishes()
	end
	local endedEarlyBefore = state.endedEarly
	local holdbacksBefore = state.holdbacks
	state, effects = Phase.step(state, filled, now(), config)
	if state.endedEarly and not endedEarlyBefore then
		stats.drivesEndedByBeaters += 1
	end
	snapshotCache = nil
	-- WHO ASKED TO BEAT **AT THE MOMENT HE WAS SEATED** (task 229, review round 1, finding 1).
	--
	-- THE SNAPSHOT CANNOT READ THE LIVE MEMO, and that is the defect this records against. The wish
	-- is SPENT by the assignment: `Lobby.wishFor` answers `HUNTER` as soon as `Match.assignmentOf`
	-- names a team, so `Lobby.beaterWishes()` is EMPTY within one lobby scan (0.1 s) of
	-- `enterAssigning` -- while `roleOverruled` is rebuilt on every dispatch for the whole 15 s
	-- intermission. Reading it live therefore told the man who had just PRESSED BEATER
	-- *"TEAMS MUST BE EVEN - you beat this drive"* (`Objective.CONFIG.TEXT.DriverOverruled`) for
	-- almost all of it -- the exact opposite of what `Roster.overruled`'s third argument exists for
	-- (`docs/design/role-switch.md` section 7 and hazard 8).
	--
	-- SO THE ANSWER IS PINNED TO THE ASSIGNMENT IT IS ABOUT. `Roster.overruled` reads
	-- `state.assignment`, which is a fact about one drive; this is the other half of that same fact,
	-- recorded in the same place and with the same lifetime.
	--
	-- IT IS CLEARED WHEN THE DRIVE NUMBER MOVES and only ever ADDED TO within one drive, because a
	-- mid-drive `join` assigns ONE man off a memo that no longer holds the wishes already spent at
	-- `enterAssigning` -- so replacing it wholesale on a join would hand every earlier wisher back to
	-- `roleOverruled`, which is the same defect one scan later.
	if state.driveNumber ~= driveBefore then
		table.clear(seatedWishes)
	end
	Roster.recordSeated(seatedWishes, filled.beaterWishes, state.assignment)

	-- A STALL IS VISIBLE, not folkloric: every hold-back is counted, and crossing HOLDBACK_WARN
	-- warns ONCE (on the crossing tick, not on every one after it).
	if state.holdbacks > holdbacksBefore then
		stats.sounderHoldbacks += state.holdbacks - holdbacksBefore
		if state.holdbacks == config.SOUNDER.HOLDBACK_WARN then
			warn(
				string.format(
					"[match] a release has been held back %d times in a row: %d alive, %d entries, capacity %s",
					state.holdbacks,
					filled.aliveBoars or -1,
					filled.boarEntries or -1,
					tostring(filled.boarCapacity)
				)
			)
		end
	end

	-- BEFORE applyEffects, AND THAT IS THE WHOLE POINT (TASKS.md 32a(c)). Entering Assigning emits a
	-- `broadcast` effect, and `broadcast` builds the snapshot from `board` -- so with the new drive's
	-- board built afterwards, the push that announces drive N carried drive N-1's score rows, and
	-- every client showed the last drive's points until the next event or the 5 s heartbeat. Round 1
	-- of Task 38 "fixed" this by clearing the snapshot cache after the push had already gone out,
	-- which changed nothing anybody could see; the order is the fix.
	if state.phase ~= before and state.phase == "Assigning" then
		-- A map rebuilt in Edit between drives is picked up without a server restart (design
		-- section 6.2). The EVENT goes out on the NEXT step, never from inside dispatch:
		-- readMarkers dispatches an event of its own, and a dispatch inside a dispatch would
		-- apply effects out of order.
		markersStale = true
		-- ...BUT THE MEASUREMENT HAPPENS NOW (task 179). `applyEffects` below emits `placePlayers`,
		-- which reads `markerSet` -- so without this line every drive places its players on the set
		-- measured during the PREVIOUS drive. That was invisible while a world's geometry never
		-- changed between drives, and in the Forest Test it is now a different LAYOUT: the hunters
		-- of an `edge` drive would be stood on the `road`'s posts 900 studs away, and the pick
		-- window would then lock each of them to a stand nowhere near his feet, gate his gun off
		-- and drag him at the soft wall (docs/design/drive-layouts.md 6.1).
		--
		-- ONLY THE MEASUREMENT MOVES. `markersStale` above is untouched, so `Phase` still sees
		-- exactly the sequence of events it saw before and no dispatch happens inside a dispatch.
		-- In DEV this is `Markers.read(world.collection)` -- five idempotent `GetTagged` calls on a
		-- Studio-built map that does not change between drives -- so the value is identical and the
		-- only difference anywhere is WHEN it was taken.
		measureMarkers()
		stats.drives += 1
		table.clear(driveKills) -- the record is per drive, exactly as the board is (task 159)
		board = Score.new() -- scores are per drive
		for userId, name in pairs(names) do
			board = Score.join(board, userId, name, state.assignment[userId])
		end
		local counts = Roster.counts(state.assignment)
		if counts.Drivers == 0 or counts.Shooters == 0 then
			stats.emptyTeamDrives += 1
		end
		snapshotCache = nil
	end

	-- THE DRIVE PAYS, ON THE `Scoring` EDGE AND BEFORE `applyEffects` (task 170), which is the
	-- mirror image of the `Assigning` block above and rests on the identical measured reason.
	-- `enterScoring` emits `{ kind = "broadcast", force = true }`, and `broadcast` builds the
	-- snapshot from `board` plus the economy's two tables -- so a pay-out AFTER the effects would
	-- make the first, forced snapshot of the results scene carry an empty coins column, and nothing
	-- forces another until the next drive's `enterAssigning`: Karen would read `--` for up to
	-- `STATE_HEARTBEAT` seconds of the scene. That is TASKS.md 32a(c) exactly, in a new place, and
	-- the position is the fix.
	--
	-- IT IS ALSO WHAT MAKES ONE PAY-OUT PER DRIVE STRUCTURAL: this edge can fire at most once per
	-- `Scoring`, and `enterScoring` is the only door into `Scoring`. The owner refuses a repeated
	-- drive number as well (`Economy.payDrive`), which is a belt over this brace.
	--
	-- `Score.leaderboard(board)` AND NOT `Match.snapshot()`: building the snapshot here would cache a
	-- copy from before the pay-out, and the pure board is what the pure conversion wants.
	if state.phase ~= before and state.phase == "Scoring" and world and world.economy then
		world.economy.payDrive(state.driveNumber, Score.leaderboard(board))
		-- ...AND THE TURN FLIPS (task 217, write edge 2). A drive that reached `Scoring` is a drive he
		-- COMPLETED, and the value stored is `other(the role he ACTUALLY played)` -- which is what
		-- makes "a turn the balance rule could not honour is not consumed" structural rather than
		-- bookkeeping: a man owed beater who was made a hunter is written beater again, with no
		-- second field and no "was it honoured" flag to get wrong (design section 5.3).
		--
		-- COMPUTED WHOLE from the final assignment, so it also RECONCILES every mid-flight write of
		-- this drive: whatever write edge 1 missed (a player whose profile had not answered yet, a
		-- race on the spawned load thread) is corrected once per drive, by construction.
		--
		-- WHY BEFORE `applyEffects`, and it is NOT the forced-broadcast reason the pay-out above
		-- rests on -- nothing about the turn goes on the wire. `applyEffects` at this edge applies
		-- `release`, `clearBoars`, `hold` and `scene`, and `applyScene` MOVES every character; if
		-- anything in that list yields, a `Players.PlayerRemoving` landing in the window reaches
		-- `Economy.release` and drops the session before the flip was written, losing the turn of a
		-- man who was there when the drive ended. Writing first closes that window and costs nothing.
		--
		-- `state.assignment` AND NOT `state.previousAssignment`: `enterScoring` has just set the
		-- second to the first and cleared neither, so they are the same table at this instant. The
		-- live one is the one to read.
		if world.economy.noteNextTeams then
			world.economy.noteNextTeams(Roster.invert(state.assignment))
		end
		snapshotCache = nil
	end

	applyEffects(effects)
	syncBots()
	if state.phase ~= before or state.driveNumber ~= driveBefore then
		phaseSignal:Fire(before, state.phase, state.driveNumber)
	end
end

-- ------------------------------------------------------------------------------- the boar's side

-- Exported for the spec: see the comment on the local, above CONFIG.
Match.quickTestEnabled = quickTestEnabled

-- Where the quick test puts its first sounder: `QUICK_TEST_AHEAD_STUDS` north of the drive line and
-- IN FRONT OF THE FIRST POST, or nil when there is no line to measure from. Pure, so the spec can
-- check it without a map.
--
-- THE POST MATTERS AS MUCH AS THE LINE, and the first screenshot is why: the line marker's own
-- Position is the CENTRE of a 1,240-stud corridor, while the eight posts span 1,120 studs of it --
-- so a sounder at the line's centre can be 560 studs from the only shooter, and in the capture at
-- t+13 s and again at t+36 s there was nothing to see. `Body.placementFor` puts shooter number one
-- on `posts[1]`, so that is the post this stands in front of: the same list, the same index.
function Match.quickSpawnFor(line, posts, cfg): Vector3?
	if not (cfg and cfg.QUICK_TEST and line and typeof(line.position) == "Vector3") then
		return nil
	end
	local x = line.position.X
	local first = posts and posts[1]
	if first and typeof(first.Position) == "Vector3" then
		x = first.Position.X
	end
	return Vector3.new(
		x + (cfg.QUICK_TEST_SIDE_STUDS or 0),
		line.position.Y,
		line.position.Z + cfg.QUICK_TEST_AHEAD_STUDS
	)
end

-- HAS THIS BEATER CROSSED THE HUNTERS' LINE? (task 159). PURE and exported, so a spec drives both
-- sides of the plane and the margin with hand-written Vector3s and no world -- the shape
-- `Match.quickSpawnFor` already has.
--
-- THE LINE'S NORMAL POINTS AT THE BEATERS (`Markers.read`: *"the part's -Z faces the drivers"*, and
-- the forest's own set is `Vector3.zAxis` for the same reason), so a beater who starts up the drive
-- has a POSITIVE signed distance and crossing means going negative -- past the hunters and `margin`
-- studs beyond them.
--
-- MEASURED AGAINST THE NEAREST STAND, NOT AGAINST THE LINE MARKER'S POSITION, and that is the whole
-- reason this takes `posts`: the forest's line is ONE plane for a sine road whose real z wanders up
-- to 30 studs either side of it (`docs/design/forest-drive.md` section 6.1), so a beater crossing
-- the road 600 studs along it would be nowhere near the plane. The stands stand ON the road, so the
-- nearest one sideways is where the line really is for this beater. With no posts at all the plane's
-- own position is the reference, which is exactly the DEV arena's straight line.
--
-- THE REFERENCE AND THE NORMAL ARE `Match.lineReferenceFor`'S, FACTORED OUT IN TASK 161 and not
-- reimplemented: `Match.beaterGoalFor` has to answer the same question from the other side ("walk to
-- 20 studs PAST the line"), and two readings of "where is the line for this beater" would be exactly
-- the drift this project is a document about. This function's behaviour and signature are unchanged.
function Match.crossedLine(position: Vector3?, line, posts, marginStuds: number?): boolean
	local reference, normal = Match.lineReferenceFor(position, line, posts)
	if reference == nil or normal == nil then
		return false
	end
	return ((position :: Vector3) - (reference :: Vector3)):Dot(normal :: Vector3) <= -(marginStuds or 0)
end

-- WHERE THE HUNTERS' LINE IS, FOR THIS BEATER: the stand nearest him LATERALLY and the line's own
-- unit normal, or `(line.position, normal)` when there are no posts -- which is exactly the DEV
-- arena's straight line. `nil, nil` when there is no line to measure from.
--
-- PURE, and the one answer to that question: `Match.crossedLine` asks it to decide whether a beater
-- is through, and `Match.beaterGoalFor` asks it to decide where a bot beater walks TO.
function Match.lineReferenceFor(position: Vector3?, line, posts): (Vector3?, Vector3?)
	if typeof(position) ~= "Vector3" or not (line and typeof(line.normal) == "Vector3") then
		return nil, nil
	end
	if line.normal.Magnitude < 1e-4 or typeof(line.position) ~= "Vector3" then
		return nil, nil
	end
	local normal = line.normal.Unit
	local at = position :: Vector3
	local reference = line.position
	local nearest = math.huge
	for _, post in ipairs(posts or {}) do
		if typeof(post.Position) == "Vector3" then
			local delta = post.Position - at
			-- The distance ALONG the line, with the across-the-line part taken out: "which stand is
			-- this beater walking at", never "which stand is nearest", which would pick the one he
			-- has already walked past.
			local lateral = (delta - normal * delta:Dot(normal)).Magnitude
			if lateral < nearest then
				nearest, reference = lateral, post.Position
			end
		end
	end
	return reference, normal
end

-- WHERE A BOT BEATER WALKS TO (task 161): `marginStuds` past the reference above, along the normal,
-- at the reference's own Y -- so arriving at the goal means CROSSED with margin and the drive's end
-- is not a coin flip on one stud. PURE; `nil` when there is no line.
--
-- IT MEASURES FROM `from`, the lane's own start, for the same reason `crossedLine` does: the stand
-- this beater is walking at is the only honest reference on a curved road.
function Match.beaterGoalFor(from: Vector3?, line, posts, marginStuds: number?): Vector3?
	local reference, normal = Match.lineReferenceFor(from, line, posts)
	if reference == nil or normal == nil then
		return nil
	end
	return (reference :: Vector3) + (normal :: Vector3) * -(marginStuds or 0)
end

-- WHERE THE ANIMALS ARE GATHERED AND WHICH WAY THE SCENE FACES (task 159). PURE, and one rule for
-- both worlds: `GATHER_BEHIND_STUDS` behind the MIDDLE stand, on the hunters' own side of the line.
--
-- In the forest that is the ground beside the road by the stands -- Karen's *"near the road by the
-- stands"* -- and in DEV it is open ground just behind the shooter line. One rule, because both
-- worlds already hand this owner the same two things: the stands and the line's normal.
--
-- THE Y IS THE STAND'S OWN GROUND, read off the post's bottom face rather than raycast: the post
-- stands on the ground in both worlds (the forest measures its posts onto the terrain, task 157), so
-- its underside IS the floor and the scene needs no second measurement of it.
function Match.gatherSpotFor(markers, cfg): (Vector3?, Vector3?)
	if not markers then
		return nil, nil
	end
	local posts = markers.posts
	if not posts or #posts == 0 then
		return nil, nil
	end
	local middle = posts[math.ceil(#posts / 2)]
	local line = markers.line
	local normal = Vector3.zAxis
	if line and typeof(line.normal) == "Vector3" and line.normal.Magnitude >= 1e-4 then
		normal = Vector3.new(line.normal.X, 0, line.normal.Z)
		normal = if normal.Magnitude < 1e-4 then Vector3.zAxis else normal.Unit
	end
	local ground = middle.Position.Y - middle.Size.Y / 2
	local at = Vector3.new(middle.Position.X, ground, middle.Position.Z) - normal * cfg.SCENE.GATHER_BEHIND_STUDS
	return at, normal
end

-- WHERE *THIS* WORLD GATHERS, AND THE WORLD GETS FIRST SAY (task 191).
--
-- KAREN, 2026-10-15 ~17:20: *"next is when hunt over everyone is in clean ground no grass firstable
-- / second it could be next to cabin"*. In the Forest Test the answer is now the LOBBY's clean yard
-- beside the lodge (`Lobby.gatherSpot`, injected here as `world.gatherSpot`), and the rule above --
-- `GATHER_BEHIND_STUDS` behind the middle stand -- is the FALLBACK.
--
-- IT IS SOURCE 3.1'S OWN BRANCH, borrowed whole. ioquake3's `FindIntermissionPoint` looks for an
-- entity the MAP AUTHOR placed and falls back to the spawn logic when there is none:
--   `ent = G_Find (NULL, FOFS(classname), "info_player_intermission");`
--   `if ( !ent ) { // the map creator forgot to put in an intermission point...`
-- Authored answer first, derived answer when there is none. A world with no lobby -- the DEV place,
-- or a Forest Test whose lobby did not build -- therefore gathers exactly where it gathered before
-- this task, and that is reachable by PARAMETER (inject nothing) as well as by state.
--   ioquake3 code/game/g_main.c, GPL-2.0: https://github.com/ioquake/ioq3/blob/main/code/game/g_main.c
--
-- THE SEAM IS THE SHAPE THIS FUNCTION'S NEIGHBOURS ALREADY HAVE -- `world.placement`,
-- `world.markers`, `world.standArea`, `world.boars`, `world.bots` -- *the world provides; the owner
-- decides*. It is wrapped in `pcall` and type-checked for the reason `Match.displayAnimal` and
-- `Body.groundUnder` are: a world's reader that throws, or answers something that is not a pair of
-- `Vector3`s, must cost this drive its fallback and never its scene.
--
-- BOTH HALVES OR NEITHER. A world that answers a spot and no facing is not half-right, it is wrong,
-- so the fallback takes over -- which is also what keeps `applyScene`'s own `spot == nil or facing
-- == nil` branch the one place "nowhere to gather" is decided.
--
-- Note: docs/research/2026-10-16-gathering-at-the-cabin.md
-- THE THIRD RETURN IS WHICH OF THE TWO ANSWERED, and it exists for the console line: "gathered 12
-- animals in 2 rows" cannot tell the yard beside the cabin from the grass in the forest.
--
-- PURE IN THE WORLD'S READER, AND EXPORTED, which is what lets `match_scene.spec` state all five
-- cases -- the world answers, the world is absent, the world throws, the world answers half a pair,
-- the world answers something that is not a `Vector3` -- with no drive, no lobby and no world at all.
-- `Match.gatherSpot` below is the one line that reaches for the live one.
function Match.gatherSpotOf(reader: any, markers, cfg): (Vector3?, Vector3?, boolean)
	if type(reader) == "function" then
		local ok, at, facing = pcall(reader)
		if ok and typeof(at) == "Vector3" and typeof(facing) == "Vector3" then
			return at :: Vector3, facing :: Vector3, true
		end
	end
	local at, facing = Match.gatherSpotFor(markers, cfg)
	return at, facing, false
end

function Match.gatherSpot(): (Vector3?, Vector3?, boolean)
	return Match.gatherSpotOf(if world then world.gatherSpot else nil, markerSet, config)
end

-- Drivers only. A shooter standing on a post must not push the boar back into the wood before it
-- reaches the line, which is the whole mechanic.
--
-- PLUS THE QUICK TEST'S PHANTOM (task 83, Studio only), for its first `QUICK_TEST_PUSH_SECONDS`.
-- The boar world asks this one function "who is pushing?", so this is the one place a quick test can
-- answer "somebody is" without inventing a player. The id is not a number, so
-- `driverPositions()` -- the safety rule's own read, which is `tonumber`-keyed -- skips it and
-- nobody can be tied to a tree for shooting at a phantom.
function Match.driverThreats()
	local out = Body.driverPositions(function(player)
		return state.assignment[player.UserId]
	end, playersService())
	local phantom = Match.quickTestPhantom(now())
	if phantom then
		table.insert(out, { id = "quick-test", position = phantom })
	end
	return out
end

-- EVERYTHING A BOAR CAN PERCEIVE: the drivers above PLUS the shooters, each carrying its `kind`
-- (task 118). It wraps `Body.boarStimuli` and keeps the quick test's phantom, which stays a
-- `kind = "driver"` stimulus with a non-numeric id -- so `Match.playerDrivers`'s filter, which
-- exists because of that id, is untouched.
--
-- `Match.driverThreats` above is NOT changed and NOT replaced: the safety rule and push credit read
-- it, and they mean "a driver who is a person". This is what `MatchBoot` hands the boar world.
-- Design: docs/design/boar-behaviour.md section 8
function Match.boarThreats()
	local out = Body.boarStimuli(function(player)
		return state.assignment[player.UserId]
	end, playersService())
	local phantom = Match.quickTestPhantom(now())
	if phantom then
		-- `phantom = true` (task 123 round 5): the same mark the Forest Test's beater carries, for
		-- the same reason -- `Boar.CONFIG.PACE` runs a herd from a REAL driver this close, and there
		-- is nobody standing on this one.
		table.insert(out, { id = "quick-test", position = phantom, kind = "driver", phantom = true })
	end
	-- ...AND THE BOTS, EACH WITH ITS OWN KIND AND NO `phantom` MARK (task 161). The mark exists to
	-- tell `Boar.CONFIG.PACE` that a "driver" this close is NOBODY; a bot is somebody standing there,
	-- which is the whole point of a visible beater. A bot hunter is a `shooter`, exactly as
	-- `Body.boarStimuli` maps a real one -- noticed at 25 studs, flushing only at 15 -- so a boar can
	-- still come down the corridor to the line.
	if world and world.bots then
		for _, threat in ipairs(world.bots.threats()) do
			table.insert(out, threat)
		end
	end
	return out
end

-- Nil unless the quick test is on, the drive is running, its first seconds have not passed, and
-- there is a spawn to stand behind. Exported so the spec can drive all four of those.
function Match.quickTestPhantom(at: number): Vector3?
	if not config.QUICK_TEST or state.phase ~= "Running" or not state.quickSpawn then
		return nil
	end
	local driveStartedAt = state.phaseEndsAt - config.DRIVE_SECONDS
	if at - driveStartedAt > config.QUICK_TEST_PUSH_SECONDS then
		return nil
	end
	return state.quickSpawn + Vector3.new(0, 0, config.QUICK_TEST_PUSH_BEHIND_STUDS)
end

function Match.driveLine()
	return if markerSet then markerSet.line else nil
end

-- WHAT A PLAYER HAS BOUGHT, for the one question this owner asks about it (task 178). Set by
-- `Match.start` from `world.economy.ownedOf`, and OVERRIDABLE -- `Weapon.setArmingPolicy`'s exact
-- shape, including handing back the one it replaces, *"so a caller that needs the policy for the
-- length of one test can put the real one back without knowing who installed it or what it was"*
-- (task 150).
--
-- IT EXISTS AS A SEAM BECAUSE THE RULE COULD NOT OTHERWISE BE TESTED AT ALL, and the Reviewer's
-- round-1 finding is the record of that: `Match` is a SINGLETON that `MatchBoot` has already
-- started and `Match.start` asserts *"called twice"*, so no spec in this repository can start a
-- second drive with its own economy injected -- which is what `docs/design/shop.md` section 12.2
-- asked for. This is the seam that makes the live `mayCarryWeapon` drivable instead.
local ownedProvider: ((userId: number) -> { [string]: boolean }?)? = nil

function Match.setOwnedProvider(provider: ((userId: number) -> { [string]: boolean }?)?)
	local previous = ownedProvider
	ownedProvider = provider
	return previous
end

-- THROUGH A pcall, the rule every provider in this repo follows: a provider that errors must not
-- leave a man permanently unarmed and must not silently arm everybody. It falls back to nil, which
-- is "nobody answered" -- and for THIS reader nil means REFUSED, because today a beater carries no
-- gun (docs/design/shop.md section 7.1).
local function askOwned(userId: number): { [string]: boolean }?
	if ownedProvider == nil then
		return nil
	end
	local ok, owned = pcall(ownedProvider :: any, userId)
	return if ok and type(owned) == "table" then owned else nil
end

-- PURE, and the whole of the decision. The shape `Match.unassignTargets`, `Match.botSlotsFor`,
-- `Match.quickSpawnFor` and `Match.pushCreditWithin` already have, for the reason the first of them
-- states: *"so the rule is a table of cases in a spec rather than a branch nobody can reach"*.
--
-- THE BEATER'S LICENCE IS THE LAST LINE (task 178). KAREN, 2026-10-10: a beater *"can purchase
-- license to shoot in drive"*. It is the same branch `DRIVERS_MAY_SHOOT` opens, so nothing new about
-- the drive is decided here -- and `Shop.grantsDriveGun(nil)` is FALSE, so a world that wired no
-- economy answers exactly what this function answered before task 178.
--
-- IT BUYS HIM A GUN AND NOT AN EXEMPTION: `Rules.beaterInLine` still refuses him a shot AT a beater
-- (`classifyTarget` reads the roster and knows nothing about entitlements) and `Match.Penalty.judge`
-- still ties him for an unsafe one -- which that file already anticipated (*"the design says there
-- is no exception to write then"*).
export type CarryFacts = {
	phase: string?,
	tied: boolean?,
	team: string?,
	owned: { [string]: boolean }?,
}

function Match.mayCarryFor(facts: CarryFacts, cfg): boolean
	if facts.phase == "Waiting" then
		return false
	end
	if facts.tied == true then
		return false
	end
	if facts.team == "Shooters" then
		return true
	end
	if facts.team ~= "Drivers" then
		return false
	end
	if cfg.DRIVERS_MAY_SHOOT then
		return true
	end
	return Shop.grantsDriveGun(facts.owned)
end

-- The weapon still decides and still writes; this only answers the question.
--
-- IT GATHERS THE FOUR FACTS AND DECIDES NOTHING, which is `Weapon.Rules.refuse`'s own division and
-- is what makes the rule assertable. The ownership read is OUTSIDE the team branch on purpose: a
-- spec can then prove that this function really asks (a tripwire provider, `match_teams.spec`),
-- which the round-1 shape made impossible -- the read sat behind a Driver assignment no spec can
-- produce in the live drive. The cost is one table read per armable player per sweep.
function Match.mayCarryWeapon(player: Player): boolean
	return Match.mayCarryFor({
		phase = state.phase,
		tied = tied[player.UserId] ~= nil,
		team = state.assignment[player.UserId],
		owned = askOwned(player.UserId),
	}, config)
end

-- -------------------------------------------------- the answers the fire gate needs (171, and 174)
--
-- THE DRIVE ANSWERS, THE WEAPON DECIDES AND WRITES -- exactly as `mayCarryWeapon` and `driveLine`
-- above do, and these are handed to `Weapon.setTargetProvider` / `Weapon.setStandProvider` at the
-- composition root so neither owner requires the other (docs/research/2026-10-13-the-rules.md).

-- WHAT THE AIM RAY HIT, in the words the weapon's rules understand: `beater` for a man walking the
-- drive, `species` for an animal. The weapon knows what neither of those is, which is the whole
-- point of answering here.
--
-- A BEATER IS A PLAYER ON THE PUSH TEAM **OR** A BOT (task 171). Karen tests this world alone with a
-- line of bots, so a rule that only protected players would be a rule she could never see working.
-- `state.assignment` IS THE READ for a player -- the same table `mayCarryWeapon` and the safety rule
-- read, never `Player.Team`, which `Match.requestTeam`'s own header explains -- and the bots are
-- asked through `world.bots.isBeaterPart`, their owner's one definition of who walks.
--
-- THE SPECIES COMES OFF THE TARGET'S OWN ATTRIBUTE and nothing here knows a boar from a deer:
-- `Licences.SPECIES_ATTRIBUTE` is published by `Boar.Body.create`, the idiom `Damageable` and
-- `HitZone` already use (shotgun design section 6.4).
function Match.classifyTarget(instance: Instance?): any?
	if instance == nil then
		return nil
	end
	-- THE CHARACTER FIRST, because a man is not quarry. `GetPlayerFromCharacter` wants the Model, so
	-- walk up: a ray hits a limb.
	local node: Instance? = instance
	local species: string? = nil
	while node ~= nil do
		if species == nil then
			local value = node:GetAttribute(Licences.SPECIES_ATTRIBUTE)
			if type(value) == "string" then
				species = value
			end
		end
		local player = playersService():GetPlayerFromCharacter(node)
		if player ~= nil then
			return { beater = state.assignment[player.UserId] == "Drivers", species = species }
		end
		node = node.Parent
	end
	if world and world.bots and world.bots.isBeaterPart and world.bots.isBeaterPart(instance) then
		return { beater = true, species = species }
	end
	if species == nil then
		return nil
	end
	return { beater = false, species = species }
end

-- WHERE THIS PLAYER MAY STAND AND STILL SHOOT, or nil for "he has no stand" -- which is a beater, a
-- player between drives, and a hunter whose stand has not been decided yet. nil means NO RULE, and
-- `Weapon.Rules.outsideStand` says why that is the safe default.
--
-- THE WORLD MAY OWN THE ANSWER, the seam `world.placement` already is: the Forest Test's hunter
-- picks his own stand by walking to it (`ForestTest.lockPick`), so his circle is centred on the PICK
-- and not on the post the drive placed him at. With no injection the centre is the post this drive
-- put him on -- `Body.placementFor` with the same `indexWithinTeam`, so it is the drive's own
-- placement answered a second time rather than a second piece of geometry.
function Match.standAreaOf(userId: number): any?
	local team = state.assignment[userId]
	if team ~= "Shooters" then
		return nil -- a beater is not held to a stand (`ForestTest.boundary`'s own first rule)
	end
	if world and world.standArea then
		return world.standArea(userId)
	end
	if not markerSet then
		return nil
	end
	local place = if world and world.placement then world.placement else Body.placementFor
	-- THE SAME LINE THE PLACEMENT USED (task 221), or this would answer a circle round a stand he is
	-- not standing on: the deal depends on the whole line, so asking for one man without it would be
	-- a second opinion about where he is. This path is the DEV fallback -- the Forest Test answers
	-- through `world.standArea` -- and the DEV place has no seats, so the two agree there trivially;
	-- passing it is what keeps them agreeing if it ever does.
	local cframe = place(markerSet, team, indexWithinTeam(userId, team), config, placementLine(team))
	if cframe == nil then
		return nil -- nowhere to put him means nowhere to hold him
	end
	return { centre = cframe.Position, radius = config.STAND_RADIUS_STUDS }
end

-- BY `Player`, for the weapon's provider, which holds one. One implementation, two doors -- the
-- division `Match.mayBlowHorn` (a key) and `Match.mayCarryWeapon` (a Player) already follow.
function Match.standAreaFor(player: Player): any?
	return Match.standAreaOf(player.UserId)
end

-- A WORLD ASKS FOR ONE PLAYER TO CHANGE SIDES, AND THIS OWNER STILL DECIDES (task 157, design
-- section 5.2). It exists for exactly one caller: the Forest Test's `/beater` command and its start
-- switch, which used to write `Player.Team` at its own composition root -- and that did not merely
-- make two deciders, it did not WORK: this system reads `state.assignment`, not `Player.Team`, so a
-- player who had been dressed as a beater was still a shooter to the drive (armed, push-credited,
-- unprotected by the safety rule).
--
-- IT IS NOT A STICKY PREFERENCE. The roster is untouched, so the next drive's swap happens as it
-- would have: the request moves this drive, and `SWAP_TEAMS_EACH_DRIVE` keeps the rotation Karen
-- asked for. Honoured only in `Assigning` and `Running` -- in `Waiting` and `Scoring` there is no
-- drive to move somebody inside of, and the answer is false.
--
-- Returns whether it was honoured, read off the assignment the machine has just written rather than
-- predicted here: the decision is `Phase`'s.
function Match.requestTeam(player: Player, team: TeamName?): boolean
	if team == nil then
		return false
	end
	dispatch({ kind = "team", userId = player.UserId, name = player.Name, team = team })
	return state.assignment[player.UserId] == team
end

-- ------------------------------------------------------------------------------ the safety rule

-- THE PLAYERS AMONG THE THREATS, and it is the fix for a defect the quick test caused and the
-- console found (task 83). `driverThreats` answers the BOAR's question -- "who is pushing?" -- and
-- since the quick test that list may contain a phantom that is not a player. Everything that means
-- "a driver who is a person" -- the safety rule, and push credit, which is keyed BY USER ID -- has
-- to filter, and `samplePush` did not: `credit[tonumber("quick-test")] = at` is `credit[nil] = at`,
-- which threw `table index is nil` on every step of every quick-test session and took the rest of
-- the drive's step with it. One filter, one place, both callers.
function Match.playerDrivers(threats): { Penalty.DriverPos }
	local out = {}
	for _, driver in ipairs(threats or {}) do
		local userId = tonumber(driver.id)
		if userId then
			table.insert(out, { userId = userId, position = driver.position })
		end
	end
	return out
end

-- Every live DRIVER, as Penalty.judge wants them. driverThreats keys by a string because that is the
-- shape the boar's world wants; this is the same read, keyed by number.
local function driverPositions(): { Penalty.DriverPos }
	return Match.playerDrivers(Match.driverThreats())
end

-- ---------------------------------------------------------------- THE SAFETY LOCK (task 248)
--
-- KAREN, 2026-10-23: *"I still can shoot towards hunters and beaters"*. The trigger does not fire
-- while the shot line passes within `SAFETY_LOCK_STUDS` of a PERSON, and this is the drive's half of
-- it: the drive answers who the people are and whether this line is clear, the WEAPON decides and
-- writes (`Weapon.setSafetyLineProvider` -> `Rules.unsafeLine`) -- the division `mayCarryWeapon`,
-- `classifyTarget`, `standAreaFor` and `driveOpen` already are, so neither owner requires the other.
--
-- WHY IT IS THE DRIVE THAT ANSWERS AND NOT THE WEAPON: the geometry is `Penalty.judge`'s, the one
-- definition of *"the shot passed close to a person"* in this game, and it lives here. A second
-- closest-point formula inside the weapon would be two answers to one question.

-- EVERY PERSON IN THIS WORLD WITH A BODY, EXCEPT THE SHOOTER -- human or bot, hunter or beater,
-- in the drive or at the lodge. The widest list in this file, and deliberately: Karen's rule is
-- about PEOPLE and not about rosters, so a man between drives standing in front of her muzzle is
-- exactly as much a person as her team mate. `Match.playerDrivers`'s filter is the OPPOSITE read
-- and stays as it is -- the penalty means "a driver who is a person", this means "anybody at all".
--
-- A BOT HAS NO userId AND NEEDS NONE (`Penalty.DriverPos`'s own note): nil is never equal to the
-- shooter's id, so the self-exclusion costs no branch. `world.bots.people()` is the bots' own one
-- answer to "who is standing in the wood", hunters included -- `Bots.beaters()` would have left
-- every bot HUNTER unprotected, which is half of what she reported.
function Match.peoplePositions(exceptUserId: number?): { Penalty.DriverPos }
	local out: { Penalty.DriverPos } = {}
	for _, player in ipairs(playersService():GetPlayers()) do
		if player.UserId ~= exceptUserId then
			local character = player.Character
			local root = character and character.PrimaryPart
			if root then
				table.insert(out, { userId = player.UserId, position = root.Position })
			end
		end
	end
	if world and world.bots and world.bots.people then
		local ok, people = pcall(world.bots.people)
		if ok and type(people) == "table" then
			for _, bot in ipairs(people) do
				if typeof(bot.position) == "Vector3" then
					table.insert(out, { position = bot.position })
				end
			end
		end
	end
	return out
end

-- THE LOCK'S OWN CONFIG, DERIVED FROM THE DRIVE'S AND PURE (task 248). `Penalty.judge` reads three
-- numbers off whatever config it is handed; the lock judges at `SAFETY_LOCK_STUDS` and the penalty at
-- `SAFETY_MISS_STUDS`, and today those are the same number by the one local in `Match.CONFIG`. This
-- is what lets the two radii be separate DATA ROWS without a second copy of the formula.
function Match.lockConfigFrom(cfg): any
	return {
		SAFETY_MISS_STUDS = cfg.SAFETY_LOCK_STUDS or cfg.SAFETY_MISS_STUDS,
		SAFETY_RANGE_STUDS = cfg.SAFETY_RANGE_STUDS,
		SAFETY_BODY_STUDS = cfg.SAFETY_BODY_STUDS,
	}
end

-- IS THIS LINE UNSAFE? PURE, every fact a parameter -- the shape `Match.mayCarryFor`,
-- `Match.pushCreditable` and `Weapon.Rules` all have, and for the stated reason: a rule nobody can
-- drive with hand-written numbers is a rule nobody can assert. `people` is `Match.peoplePositions`'s
-- answer and `cfg` the drive's config; the geometry is `Penalty.judge` and nothing else.
--
-- `SAFETY_LOCK_ENABLED = false` ANSWERS false FOR EVERY SHOT, which is this game before task 248.
function Match.lineUnsafeFor(shot: Penalty.Shot, people: { Penalty.DriverPos }, cfg): boolean
	if not cfg.SAFETY_LOCK_ENABLED then
		return false
	end
	local unsafe = Penalty.judge(shot, people, Match.lockConfigFrom(cfg))
	return unsafe
end

-- THE DOOR THE WEAPON IS HANDED AT THE COMPOSITION ROOT. `stopAt` is how far the shot would have
-- got -- the muzzle-to-aim-point distance, or the ammo's range when nothing is in the way -- which
-- is the SAME number `onSafetyViolation` is given after the shot, so the lock and the penalty judge
-- the same segment.
--
-- NOT GATED ON THE PHASE, and that is deliberate: a person in front of your muzzle is a person
-- whether or not a drive is running, and the drive's own `driveOpen` rule already refuses every shot
-- outside one. A phase gate here would be a second answer to a question `Rules.ORDER` already asks.
function Match.lineIsUnsafe(player: Player, muzzle: Vector3, aim: Vector3, stopAt: number?): boolean
	if typeof(muzzle) ~= "Vector3" or typeof(aim) ~= "Vector3" then
		return false
	end
	local shot: Penalty.Shot = {
		userId = player.UserId,
		muzzle = muzzle,
		aim = aim,
		stopAt = stopAt or config.SAFETY_RANGE_STUDS,
		at = now(),
	}
	local unsafe = Match.lineUnsafeFor(shot, Match.peoplePositions(player.UserId), config)
	if unsafe then
		stats.safetyLocked += 1
	end
	return unsafe
end

-- HOW MANY REAL BEATERS ARE IN THIS DRIVE, AND HOW MANY OF THEM ARE THROUGH THE HUNTERS' LINE (task
-- 159). The owner's measurement; the RULE is `Phase.beatersThrough`, which only compares the two.
--
-- `driverPositions` IS THE READ, and it is the right one for exactly the reason the safety rule uses
-- it: it is keyed by userId, so the quick test's phantom and the forest's wave beaters -- which carry
-- non-numeric ids -- are filtered out by `Match.playerDrivers` and can never end a drive. Karen's
-- rule is about the people walking up.
--
-- ...AND SINCE TASK 161 THE LINE IS REAL BEATERS PLUS BOT BEATERS, which is the fix for Karen's own
-- open complaint (TASKS.md 159a(f)): with only real beaters counted, a SOLO beater ends the drive the
-- moment she crosses the road. Her rule is *"Timer or when all beaters cross line of hunters"*, and
-- with a line of bots walking beside her *"all beaters"* is the LINE -- so she crossing first ends
-- nothing and the drive ends when the last of the line is past.
--
-- A BOT IS COUNTED HERE AND NOWHERE ELSE, and that asymmetry is the design: `driverPositions` --
-- which the safety rule and push credit read -- still means "a driver who is a person", because a bot
-- has no userId and `Match.playerDrivers` filters it out by exactly that. This function asks a
-- different question ("how long is the beater line and how much of it is through"), so it asks the
-- bots directly and measures them with the SAME `Match.crossedLine` predicate.
--
-- ...AND SINCE TASK 168 IT ALSO RECORDS WHICH OF THEM ARE THROUGH, in `throughLine`, because the
-- horn needs the per-man answer and this is the walk that already has it. One measurement, one
-- place: `Match.mayBlowHorn` reads the record and `Match.throughUserIds` reports it.
function Match.beaterCrossing(): (number, number)
	local beaters = driverPositions()
	if world and world.bots then
		for _, bot in ipairs(world.bots.beaters()) do
			table.insert(beaters, bot)
		end
	end
	local line = if markerSet then markerSet.line else nil
	local posts = if markerSet then markerSet.posts else nil
	local across = 0
	table.clear(throughLine)
	for _, beater in ipairs(beaters) do
		if Match.crossedLine(beater.position, line, posts, config.BEATER_CROSS_MARGIN_STUDS) then
			across += 1
			-- A PLAYER IS KEYED BY HIS userId AS A STRING AND A BOT BY ITS SLOT ID, which is exactly
			-- how `Weapon.Horn` keys its one cooldown table (`Horn.keyFor`) -- so the horn's policy
			-- looks this up with the key it already holds and no translation exists twice.
			local key = if beater.userId ~= nil then tostring(beater.userId) else tostring(beater.id)
			throughLine[key] = true
		end
	end
	return #beaters, across
end

-- HAS THIS BEATER FINISHED HIS DRIVE? (task 168). `key` is the horn's own key. False for anybody the
-- last measurement did not find past the line, which includes every hunter, every spectator and
-- everybody at all when no drive is running.
function Match.beaterThrough(key: string?): boolean
	return key ~= nil and throughLine[key] == true
end

-- MAY THIS HORN STILL SOUND? (task 168). Karen: *"when beater cross the line of hunter it's done for
-- him cant use sound anymore"*.
--
-- THE TOOL STAYS IN HIS HAND AND THE BLAST IS REFUSED, which is the Director's choice of the two he
-- offered, and the reason is what the player sees: taking the horn away mid-drive would be a Tool
-- vanishing out of a hand with nothing on screen to say why, and `Horn.refreshCarry` is
-- level-triggered off `carriesFor` -- so a revoke would also have to teach the CARRY rule about the
-- line, and a man who walked back north would be handed a new horn. One predicate, one door: he
-- keeps the horn, the click does nothing, and his objective line says *"you are through"*.
--
-- INJECTED, NEVER REQUIRED: the composition root hands this to `Weapon.Horn.setBlowPolicy`, exactly
-- as it hands `Match.mayCarryWeapon` to `Weapon.setArmingPolicy`. Neither owner requires the other.
-- ...AND SINCE TASK 174 THE DRIVE HAS TO BE OPEN AS WELL. KAREN, 2026-10-13 ~09:35: *"we can't
-- walk or make a horn sound before horn anounce hunting started for beater"*. The walk was task
-- 168's (`Body.hold` for a player, `Match.botsMayGo` for the line); the HORN was not, so a beater
-- stood anchored at his line through the start fanfare and could sound the signal that had not
-- finished announcing itself -- and a bot's blast, which the step already held behind `released`,
-- was refused by that one boolean and by nothing a spec could state.
--
-- TWO QUESTIONS, ONE DOOR, AND THEY ARE NOT THE SAME QUESTION: `Phase.driveOpen` is about the DRIVE
-- (before GO, and after the end signal through the results scene) and `beaterThrough` is about the
-- MAN (he has walked out the far side, task 168). Both of them answer "no" through
-- `Weapon.Horn.mayBlow`, which is the one door every blast comes through -- a player's click, a
-- bot's rhythm and a spec's call -- so a player and a bot are held by one rule and not by two.
function Match.mayBlowHorn(key: string?): boolean
	return Match.driveOpen() and not Match.beaterThrough(key)
end

-- IS THE DRIVE OPEN? (task 174.) The owner's one read of `Phase.driveOpen` against the live state,
-- and the fact the WEAPON's fire gate is handed at the composition root
-- (`Weapon.setDriveOpenProvider`) -- exactly as `mayCarryWeapon`, `standAreaFor` and
-- `classifyTarget` are handed over: the drive answers, the weapon decides and writes.
--
-- WHAT IT MEANS FOR A HUNTER: from the moment the drive ends -- the clock or the last beater
-- crossing the line, whichever comes first, which is the moment the END SIGNAL sounds -- the trigger
-- does nothing, through the results scene, until the next drive's GO. Karen: *"for hunter once hunt
-- over (drive) horn anounce then I can; shoot anymore"*. It is refused from the signal's START (the
-- drive's end), not from its end: the signal announces a drive that is already over.
function Match.driveOpen(): boolean
	return Phase.driveOpen(state)
end

-- THE THROUGH LIST AS userIds, for the snapshot -- the shape `tied` has, and sorted for the same
-- reason: the payload is the same payload every tick unless the fact changed. A bot's key is not a
-- number, so `tonumber` is what leaves the bots out of a list of people's screens.
function Match.throughUserIds(): { number }
	local out = {}
	for key in pairs(throughLine) do
		local userId = tonumber(key)
		if userId then
			table.insert(out, userId)
		end
	end
	table.sort(out)
	return out
end

-- MAY THE BOT LINE WALK YET? (task 168, round 1 finding 1.) PURE in the state, and exported so
-- `bots_live.spec` states the rule this owner acts on rather than restating it.
--
-- KAREN'S RULE IS ONE GO FOR EVERYBODY -- the dispatch's own words, *"a beater (player AND bot)
-- cannot move until the START FANFARE has sounded"*. The task deferred the PLAYERS' release by
-- `Phase.goHoldSeconds` and left this call on the phase, so for 2.18 s a player beater stood
-- anchored at the line while the bot line beside her walked off and blew -- which is the visible
-- half of the thing Karen complained about, in the world she actually plays (`DRIVE_BOTS` on).
--
-- `Phase.lineHeld` IS THE SAME PREDICATE THE PLAYERS' HOLD USES, so there is one answer to "has the
-- line been let go" and the two cannot drift: the dispatch that emits `free` is the dispatch on
-- which this first answers true, because `Phase.step` clears `goFreed` in the same step.
function Match.botsMayGo(driveState): boolean
	-- ...AND SINCE TASK 174 IT IS `Phase.driveOpen`, WHICH IS THE SAME TWO CONDITIONS IT USED TO
	-- STATE HERE IN ITS OWN WORDS. The horn gate and the fire gate ask the same predicate, so "is the
	-- drive on" has one answer for the line that walks, the horn that sounds and the gun that fires.
	return Phase.driveOpen(driveState)
end

-- HOW MANY BOT RIGS EXIST, read-only, for the report and for a spec. 0 with no bots injected, which
-- is every DEV drive with the flag off and every pure spec.
function Match.botCount(): number
	if world and world.bots then
		return world.bots.count()
	end
	return 0
end

-- THE SLOT LIST, WHICH IS THE WHOLE OF WHAT THE DRIVE TELLS THE BOTS (task 161). PURE given
-- `place`, so `bots_lane.spec` drives it with hand-written posts and a hand-written placement
-- function -- no markers, no world and no rig.
--
-- `Bots` NEVER READS A MARKER, A TAG OR A PLAYER. This is the one translation between the drive's
-- geometry and a bot: an id, a team, where it starts, and (for a beater) where it walks to.
--
-- A BOT HUNTER GETS A POST OF ITS OWN, by asking `place` for the index AFTER the real hunters --
-- which in the Forest Test is `ForestTest.standIndexFor`'s centre-out order, so the bots take the
-- stands beside the player's rather than the far end of the road.
--
-- EVERY BOT BEATER ASKS FOR ITS OWN LANE, BY INDEX, AND WALKS TO ITS OWN GOAL (task 167).
--
-- KAREN, 2026-10-12 ~16:10, after playing a drive as a hunter with the bots on: *"and seem like all
-- bots came to me"*. Until this task the drive took ONE base from `place` and `Bots.Lane` spread the
-- four of them +-18 and +-36 studs about it, with all four goals translated sideways off the one
-- base goal. Both halves of that were wrong once the base was her own stand:
--
--   * 72 studs of total front is not a drive line, it is four men walking at one stand -- and the
--     base IS the stand she locked, because that is the push line this world releases its waves on;
--   * a goal translated sideways off one base goal is not on the road. The road is a sine 30 studs
--     deep (`ForestTest.LAYOUTS.road.amplitudeStuds`), `GOAL_PAST_LINE_STUDS` is 20, and the lateral translation keeps the
--     BASE's z -- so at any real width a lane's goal can land NORTH of the road, the bot stops short
--     of the line, `Match.crossedLine` never counts it and the drive can only ever end on the timer.
--
-- SO THE LANE IS THE WORLD'S GEOMETRY, asked for the same way a hunter's stand is: `place(markers,
-- "Drivers", realBeaters + lane, cfg)`. The forest spreads those indices across the hunters' front
-- (`ForestTest.beaterLaneOffset`, 0 / +-150 / +-300 -- the stand grid) and measures the ground and
-- the trunks at each one; the DEV arena's `Body.placementFor` already spread drivers across its pad
-- by index and needed no change at all. Index 1 is the push line, so a real beater keeps it and the
-- bots flank her -- the property `Bots.Lane.offsetFor` was written for, kept, and moved to the only
-- owner that can know how wide a front is.
--
-- AND THE GOAL IS MEASURED FROM THE LANE'S OWN START, by the same `Match.beaterGoalFor` that always
-- took a start and answered with the post nearest it: straight ahead down the push, on the road,
-- 20 studs past the same post `Match.crossedLine` will measure it against. Arriving IS crossing.
--
-- `Bots` STILL READS NO MARKER, TAG OR PLAYER, and still spreads nothing it cannot see: it is
-- handed a start and a goal per bot and walks between them.
-- IS THIS THE FIRST `Assigning` TICK OF A DRIVE WHOSE BOTS HAVE NOT BEEN REBUILT YET? PURE and
-- exported, so `bots_live.spec` can state the rule with four calls and no drive at all -- and so
-- that a spec driving two drives by hand uses THIS answer rather than a copy of it.
--
-- TRUE EXACTLY ONCE PER DRIVE. `Running` never rebuilds (a bot mid-walk must not be teleported back
-- to the line four times a second), and a second `Assigning` tick of the same drive never rebuilds
-- (the countdown is ten seconds long and this runs on every dispatch).
function Match.botsNeedRebuild(phase: string, driveNumber: number, lastRebuilt: number?): boolean
	return phase == "Assigning" and lastRebuilt ~= driveNumber
end

--
-- `line` IS THE HUNTERS' LINE (task 221), passed through unchanged so the bots are dealt out of
-- the same walk the real hunters were. A bot has no userId and no profile, so its index carries no
-- `entitled` answer -- nil, which is "nobody answered", which is entitled -- and a bot may take a
-- LEFTOVER seat. The real hunters are dealt FIRST, because their indices are 1..n and the bots get
-- n+1 upward, so an entitled hunter always has first refusal. Accepted and named.
function Match.botSlotsFor(markers, place, real, want, cfg, hunterLine): { any }
	local slots = {}
	if place == nil then
		return slots
	end
	for index = 1, (want.hunters or 0) do
		local at = place(markers, "Shooters", (real.hunters or 0) + index, cfg, hunterLine)
		if at ~= nil then
			table.insert(slots, {
				id = string.format("bot-hunter-%d", index),
				team = "Shooters",
				from = at,
				to = nil,
				lane = 0,
			})
		end
	end
	local wantBeaters = want.beaters or 0
	local line = if markers then markers.line else nil
	local posts = if markers then markers.posts else nil
	for lane = 1, wantBeaters do
		-- ITS OWN LANE, MEASURED BY THE WORLD, AND ITS OWN GOAL ON THE ROAD IN FRONT OF IT.
		--
		-- NO LINE MEANS NO WALK, NOT A WALK TO NOWHERE: `to = nil` makes a bot beater a stander on
		-- the start line. A world whose markers have no drive line is a fact about the world, which
		-- is the shape `applyPlace` and `applyScene` already have.
		local from = place(markers, "Drivers", (real.beaters or 0) + lane, cfg, nil)
		if from ~= nil then
			table.insert(slots, {
				id = string.format("bot-beater-%d", lane),
				team = "Drivers",
				from = from,
				to = Match.beaterGoalFor((from :: CFrame).Position, line, posts, cfg.BOTS.GOAL_PAST_LINE_STUDS),
				lane = lane,
			})
		end
	end
	return slots
end

-- THE WEAPON PUBLISHED A SHOT INTO THE DRIVE; this decides whether it endangered anybody. Four
-- questions, and only the last one is Penalty's: is the drive live, is this shooter already tied, is
-- the grace over, and did the shot pass close to a driver (design section 8.3).
--
-- The weapon's 45-degree arc has already filtered the shot -- that is why this is called at all -- and
-- taking that cone as the verdict would tie everybody in the first minute, because a shooter on a post
-- faces the drive.
local function onSafetyViolation(player: Player, aim: Vector3, muzzle: Vector3, stopAt: number?)
	if not config.SAFETY_ENABLED then
		return
	end
	if not Phase.isLive(state) then
		return -- no penalty outside the drive; shooting in Scoring is possible and pointless
	end
	if tied[player.UserId] then
		return -- already tied: a second violation changes nothing and fires Punished once
	end
	local at = now()
	-- The drive's own start, derived rather than stored: phaseEndsAt is the only clock in this system.
	local driveStartedAt = state.phaseEndsAt - config.DRIVE_SECONDS
	if at - driveStartedAt < config.SAFETY_GRACE_SECONDS then
		return
	end
	local shot: Penalty.Shot = {
		userId = player.UserId,
		muzzle = muzzle,
		aim = aim,
		stopAt = stopAt or config.SAFETY_RANGE_STUDS,
		at = at,
	}
	local guilty = Penalty.judge(shot, driverPositions(), config)
	if not guilty then
		return
	end
	dispatch({ kind = "violation", userId = player.UserId, name = player.Name, at = at })
end

-- Distance sampling, twice a second: which DRIVERS were near which boar, so a kill can pay the
-- people who pushed it. Distance only -- this system casts no rays at all.
local function samplePush()
	if not (world and world.boars) or not Phase.isLive(state) then
		return
	end
	-- PLAYERS ONLY, and by userId: this table is what turns into points. A threat that is not a
	-- player -- the quick test's phantom -- has no userId to credit, and indexing by its `nil` is
	-- what threw on every step until this line filtered (see `Match.playerDrivers`).
	local drivers = driverPositions()
	if #drivers == 0 then
		return
	end
	local at = now()
	for _, handle in ipairs(world.boars:boars()) do
		local boarPosition = handle.position()
		local credit = pushCredit[handle.id]
		if not credit then
			credit = {}
			pushCredit[handle.id] = credit
		end
		for _, driver in ipairs(drivers) do
			if (driver.position - boarPosition).Magnitude <= config.POINTS.PUSH_RADIUS then
				credit[driver.userId] = at
			end
		end
	end
end

-- MAY THIS MAN BE CREDITED FOR AN ANIMAL HE PUSHED? PURE, and exported so a spec drives both
-- branches with no drive and no world -- the shape `Phase.waitingFor` and `Horn.carriesFor` already
-- have (task 160). Three facts and no state: there is a userId at all (a phantom beater has none),
-- the drive is live, and he is a beater OF THIS DRIVE.
function Match.pushCreditable(userId: any, team: any, live: boolean?): boolean
	return type(userId) == "number" and live == true and team == "Drivers"
end

-- THE SECOND DOOR INTO PUSH CREDIT, AND IT IS THE HORN (task 160). Karen, 2026-10-10:
-- *"beater ranking also is cool"*.
--
-- WHY IT HAS TO EXIST: `samplePush` above measures PROXIMITY -- 60 studs, twice a second -- and a
-- horn carries `Horn.spookStuds`, which is far further than that. So the one push a beater makes
-- deliberately, from where he is standing, in the one way Karen designed for him, earned him
-- nothing at all: the animals ran, a hunter shot one, and the man who flushed it was out of radius.
--
-- WHO SAYS WHICH ANIMALS WERE PUSHED IS THE BOAR'S OWNER, not this one. `Runtime:hearHorn` returns
-- the ids it actually pushed (task 160), because "did this blast reach that animal" is a question
-- about the boar world -- a second radius test here would be two systems deciding one fact, which
-- is the failure docs/PROJECT_CONTEXT.md names. This function turns an answer into credit and
-- nothing more: no radius, no distance, no ray.
--
-- ONLY A BEATER OF THIS DRIVE, and only while it is live. `Horn.carriesFor` already grants the tool
-- to nobody else, so this is the belt to that braces: beater points are for beaters, read off
-- `state.assignment` -- the same fact `samplePush` filters on, which is why a phantom beater (the
-- quick test's, the forest's wave) can never earn one. It has no userId to credit and never reaches
-- this door at all.
function Match.creditPush(userId: number?, boarIds): number
	if
		not Match.pushCreditable(
			userId,
			if type(userId) == "number" then state.assignment[userId] else nil,
			Phase.isLive(state)
		)
	then
		return 0
	end
	local credited = Match.writePushCredit(pushCredit, userId :: number, boarIds, now())
	stats.hornCredits += credited
	return credited
end

-- THE WRITE ITSELF, PURE AND EXPORTED, and it is split out for the reason `pushCreditable` was
-- (round 1 finding 1): every assertion about the horn's door was a REFUSAL, so
-- `function Match.creditPush() return 0 end` passed the whole gate and the lines that actually pay
-- a beater -- the loop, the id filter, the write `creditFor` later reads -- were never run. This is
-- those lines, in a function a spec drives with its own table, no drive and no clock.
--
-- `credits` IS MUTATED, deliberately and alone: it is the owner's own `pushCredit`, which lives for
-- a drive and is keyed by boar id. Everything else here is a parameter.
--
-- IT COUNTS NEW CREDITS, NOT IDS (round 1, note 4). `credit[userId] = at` is idempotent, so a
-- beater who blasts the same animal twice inside the window holds ONE credit -- and the old
-- `credited += 1` per id said two, which made `stats().hornCredits` a lie about the thing its own
-- comment claims to count. The refresh still happens (the timestamp moves, which is what decides
-- who pays under `latestPushers`); only the tally is honest.
--
-- A NON-STRING ID IS SKIPPED, not an error: this list comes off a signal payload through a
-- composition root, and `pushCredit[nil]` is the "table index is nil" that took out every step of
-- every quick-test session in task 83.
function Match.writePushCredit(credits, userId: number, boarIds, at: number): number
	local credited = 0
	for _, id in ipairs(boarIds or {}) do
		if type(id) == "string" then
			local credit = credits[id]
			if not credit then
				credit = {}
				credits[id] = credit
			end
			if credit[userId] == nil then
				credited += 1
			end
			credit[userId] = at
		end
	end
	return credited
end

-- ...AND THE READ, equally pure and equally exported, for the same reason: this is the function
-- `onDowned` hands to `Score.kill`, so a spec that drives it is driving the real path from "a horn
-- was blown" to "a beater was paid" rather than a copy of it.
function Match.pushCreditWithin(credits, boarId: string?, at: number, window: number): { [number]: number }
	local out = {}
	local credit = if boarId then credits[boarId] else nil
	if not credit then
		return out
	end
	for userId, seen in pairs(credit) do
		if at - seen <= window then
			out[userId] = seen
		end
	end
	return out
end

local function creditFor(boarId: string?): { [number]: number }
	return Match.pushCreditWithin(pushCredit, boarId, now(), config.POINTS.PUSH_WINDOW)
end

-- WHAT THE OWNER'S OWN CREDIT TABLE SAYS ABOUT ONE ANIMAL, as a copy, with no setter. It follows
-- `Runtime:perceptionOf` and `Runtime:woundOf` exactly: nothing in the game reads it, and it exists
-- so a live spec can prove that a horn's credit really landed where `Score.kill` will look for it,
-- instead of inferring it from a return value (round 1 finding 1).
function Match.pushCreditFor(boarId: string?): { [number]: number }
	return creditFor(boarId)
end

local function onDowned(record)
	if not Phase.isLive(state) then
		return -- a shot at a carcass between drives scores nothing
	end
	stats.kills += 1
	if record.kind == nil or config.POINTS.KIND[record.kind] == nil then
		stats.unknownKindKills += 1
	end
	local awards
	board, awards = Score.kill(board, record, creditFor(record.id), config)
	for _, award in ipairs(awards) do
		scoredSignal:Fire(award)
	end
	pushCredit[record.id] = nil
	-- THE RESULTS SCENE'S OWN ROW (task 159), and it is deliberately thin: what animal it was and
	-- where it was hit. No points -- `Score` owns those and the panel reads them off the snapshot --
	-- and no Instance and no position, because the carcass is about to be despawned and a world
	-- point would then mean nothing (the rule `docs/design/drive-report.md` section 2 already sets).
	table.insert(driveKills, {
		kind = record.kind,
		zone = record.killingZone,
		byUserId = record.killedByUserId,
		byName = record.killedByName,
	})
	dispatch({
		kind = "kill",
		userId = record.killedByUserId,
		name = record.killedByName,
		record = record,
	})
end

local function onDespawned(record)
	if record.reason ~= "escaped" then
		pushCredit[record.id] = nil
		return -- "killed" is the carcass leaving, and the kill was already scored
	end
	if not Phase.isLive(state) then
		return
	end
	stats.escapes += 1
	local awards
	board, awards = Score.escape(board, record, config)
	for _, award in ipairs(awards) do
		scoredSignal:Fire(award)
	end
	pushCredit[record.id] = nil
	dispatch({ kind = "gone", record = record })
end

-- ------------------------------------------------------------------------------------ lifecycle

-- MEASURES THE SET AND DISPATCHES NOTHING (task 179). Split out of `readMarkers` below so the
-- `Assigning` edge can take a fresh measurement from INSIDE `dispatch`, where an event may not be
-- raised but a plain measurement may.
--
-- A WORLD MAY HAND OVER A SET, OR A FUNCTION THAT MEASURES ONE (design section 4.1.6). The
-- Forest Test's geometry is raycast off its own terrain, so its set has to be built rather than
-- held: a table captured once at boot would be a measurement taken before the place had
-- finished loading. Every existing caller passes a table and is bit-identical.
--
-- THE CONTRACT A `world.markers` FUNCTION NOW HAS TO HONOUR, because it is called from inside
-- `dispatch`: it MUST NOT YIELD and MUST NOT CALL BACK INTO `Match` in a way that dispatches. The
-- forest's provider raycasts and creates parts, neither of which yields, and the
-- `Match.driveNumber()` it reads is a plain table read.
function measureMarkers()
	if type(world.markers) == "function" then
		markerSet = world.markers()
	elseif world.markers then
		markerSet = world.markers
	else
		markerSet = Markers.read(world.collection)
	end
end

local function readMarkers()
	-- It is re-read on exactly the two occasions a TAGGED world is re-read, and no others: once a
	-- second while `Waiting`, and once on entering `Assigning` (`markersStale`).
	measureMarkers()
	dispatch({
		kind = "markers",
		complete = markerSet.complete,
		missing = markerSet.missing,
		boarSpawns = markerSet.boarSpawns,
		-- The quick test's own spawn point, computed HERE because this owner is the one that reads
		-- the markers; `Phase` gets a Vector3 like every other position it is given.
		quickSpawn = Match.quickSpawnFor(markerSet.line, markerSet.posts, config),
	})
end

-- ---------------------------------------------------- A RESPAWN ENDS YOUR HUNT (task 248)
--
-- KAREN, 2026-10-23: *"we have a bug / when I respawn I am in lobby with weapons but I can't go to
-- next hunt / so when I respown hunt should over then I can enter to next games"*.
--
-- WHAT WAS WRONG, in this owner's own words: a player who dies or presses Reset mid-drive is still
-- in `state.participants`, so `Match.isParticipant` says yes, so the LOBBY leaves him alone
-- entirely (`Lobby.stepPlayer`'s `inDrive` return: no respawn point, no pad countdown, no walk
-- home) and `mayCarryWeapon` still answers true off his assignment -- which is a man standing at
-- the lodge holding a shotgun with no way into the next drive. Both halves of what she reported,
-- from one cause.
--
-- THE RULE IS A RECONCILIATION AND NOT A REACTION, and that is deliberate: the fact is *"the
-- character he is in is not the character the drive gave him"*, which is TRUE UNTIL SOMETHING FIXES
-- IT however he got there -- a death, the Reset button, a fall past
-- `FallenPartsDestroyHeight`, a `LoadCharacter` from anything else. A `CharacterAdded` handler would
-- have been one trigger among several, and the next way to respawn that this game grows would
-- recreate Karen's bug under it.
--
-- IT IS ASKED AT `MATCH_STEP_HZ`, beside `Body.floorStep` -- the other level rule in this step, and
-- the one that exists for the same reason (*"a player who pressed Reset has no edge"*,
-- `Lobby.Join.needsReturn`).

export type RespawnFacts = {
	live: boolean?, -- is this drive in Assigning or Running
	participant: boolean?, -- is he in its roster
	placing: boolean?, -- is one of THIS owner's placements in flight for him (`Body.isPlacing`)
	placed: Model?, -- the character the drive gave him
	current: Model?, -- the character he is in now
	lobbyWorld: boolean?, -- is there a lobby for him to go back to
}

-- PURE, AND EVERY FACT A PARAMETER -- the shape `Match.mayCarryFor` and `Match.pushCreditable`
-- already have, for the reason the first of them states: a rule nobody can drive with hand-written
-- values is a branch nobody can reach.
--
-- `placing` IS THE ONE THAT MAKES IT CORRECT. `Body.place` respawns the player itself, so during a
-- placement the engine hands him a character this owner has not been told about yet, and a rule
-- without this clause would throw every player out of the drive at the moment it placed him.
-- `Body.isPlacing` is the one answer to *"did we ask for this"* and it is bounded by
-- `PLACE_TIMEOUT`, so a placement that never completes cannot leave him exempt for ever.
--
-- `placed == nil` IS "WE HAVE NEVER PLACED HIM", which is a man who joined mid-drive before his
-- placement landed and every spec that enrols nobody. Nothing is known, so nothing is decided.
--
-- `lobbyWorld` IS WHY THE DEV ARENA IS UNTOUCHED, and it is the same refusal `Match.dismissAll`
-- makes with the same reason: in a world that enrols every arrival automatically there is no lobby
-- to walk back to and nothing that would ever put him in the drive again, so taking him out would
-- leave the drive short with no way to refill it. `autoEnrol == false` is the lobby's own switch
-- (task 177), read at the boundary and passed in here.
function Match.withdrawOnRespawn(facts: RespawnFacts): boolean
	if facts.live ~= true or facts.participant ~= true or facts.lobbyWorld ~= true then
		return false
	end
	if facts.placing == true then
		return false
	end
	if facts.placed == nil or facts.current == nil then
		return false
	end
	return facts.current ~= facts.placed
end

-- ONE PLAYER, OUT OF THIS DRIVE, AT THE LODGE, FREE FOR THE NEXT ONE. The third door of the lobby's
-- seam beside `enrol` and `dismissAll` (design section 4.2), and it is callable by hand: the Forest
-- Test's own proof and `match_live.spec` drive it directly.
--
-- WHAT THIS OWNER DOES BEFORE THE DISPATCH, because `Phase` writes no Instance and holds no rope:
--   * THE ROPE COMES OFF. A tied man who resets is out of the drive, which is a heavier price than
--     the rope -- he loses the rest of the hunt -- so leaving him anchored to a tree in a world he
--     is no longer playing in would be a second punishment with no way out of it. The paragraph
--     this replaces is `watchCharacter`'s (*"press Escape, Reset, and the penalty is over" is not a
--     penalty*) and it is still true: the penalty is no longer the rope, it is the drive.
--   * THE PLACED CHARACTER IS FORGOTTEN, or the sweep would fire again on the next tick for a man
--     who is no longer a participant (harmless, but it would count a second withdrawal).
-- AND `heldStill` IS DELIBERATELY NOT TOUCHED HERE, which is the opposite of what it looks like it
-- should do: `applyFree` is what RESTORES his walk speed (`Body.untie`, *"a hold is a tie without
-- the rope"*) and it only acts on a userId that is still in `heldStill` -- so clearing the row here
-- would leave a withdrawn beater walking home at `HELD_WALK_SPEED` for ever. The untie above is
-- what makes the `free` effect reach him at all, because `applyFree` skips a man who is tied.
function Match.withdraw(player: Player): boolean
	local userId = player.UserId
	if state.participants[userId] == nil then
		return false
	end
	if tied[userId] then
		untie(userId)
	end
	placedCharacter[userId] = nil
	stats.withdrawals += 1
	dispatch({ kind = "withdraw", userId = userId, name = player.Name })
	local out = state.participants[userId] == nil
	if out then
		print(string.format("[match] %s respawned mid-drive: out of this drive, free for the next", player.Name))
	end
	return out
end

-- THE SWEEP. Every participant, once a tick, through the pure rule above.
--
-- IT WALKS THE ROSTER AND NOT THE SERVER, which is the one difference from `Body.floorStep` beside
-- it: a man who is not in the drive cannot be taken out of one.
local function respawnSweep()
	-- `insideDrive` AND NOT `isLive`: a man who presses Reset during the COUNTDOWN was in the drive
	-- too, and `Phase`'s own `withdraw` branch refuses outside exactly this window -- one predicate,
	-- so the sweep and the machine cannot disagree about it.
	if not Phase.insideDrive(state) then
		return
	end
	local lobbyWorld = autoEnrol == false
	if not lobbyWorld then
		return -- the DEV arena: see `Match.withdrawOnRespawn`
	end
	for userId in pairs(state.participants) do
		local player = playersService():GetPlayerByUserId(userId)
		if player ~= nil then
			local withdraw = Match.withdrawOnRespawn({
				live = true,
				participant = true,
				placing = Body.isPlacing(userId),
				placed = placedCharacter[userId],
				current = player.Character,
				lobbyWorld = true,
			})
			if withdraw then
				Match.withdraw(player)
			end
		end
	end
end

function Match:step(dt: number)
	if not started then
		return
	end
	accumulator += dt
	sinceSample += dt

	-- MEASURED, and it is the reason this is here at all: ArenaBoot and MatchBoot are two Scripts in
	-- ServerScriptService with no defined order, so Match.start can run BEFORE the arena exists. It
	-- did, on one harness run in three: the markers came back empty, the drive sat in Waiting for the
	-- whole session, nobody was armed and five specs went red for a reason none of them owned.
	-- Re-reading while Waiting costs five GetTagged calls a second and closes the race for good.
	sinceMarkers += dt
	if (state.phase == "Waiting" or markersStale) and sinceMarkers >= 1 then
		sinceMarkers = 0
		markersStale = false
		readMarkers()
	end
	-- TIE_SECONDS, and only when TIE_UNTIL_DRIVE_END is false. With Karen's value (true) Penalty.expired
	-- is always false and this loop never frees anybody -- the drive's `release` effect does.
	if not config.TIE_UNTIL_DRIVE_END and next(tied) ~= nil then
		local at = now()
		local freed = false
		for userId, record in pairs(tied) do
			if Penalty.expired(record.at, at, config) then
				untie(userId)
				freed = true
			end
		end
		if freed then
			broadcast(false)
		end
	end

	local interval = 1 / config.MATCH_STEP_HZ
	if sinceSample >= 1 / config.PUSH_SAMPLE_HZ then
		sinceSample = 0
		samplePush()
	end
	if accumulator < interval then
		return
	end
	accumulator = 0
	-- THE FLOOR, BEFORE THE TICK (task 192). `Body` owns where a character stands, so it owns putting
	-- one back that is under the ground; this owner only says WHEN, which is the same split the
	-- markers, the outfits and the holds already have. It walks every player on the server and not
	-- only the drive's roster, because the placement that killed Karen every round was the LOBBY's
	-- return and a man at the lodge is in no roster.
	-- Note: docs/research/2026-10-15-one-placement-rule.md
	stats.rescuedFromUnderGround += Body.floorStep(playersService())
	-- ...AND A RESPAWN ENDS YOUR HUNT (task 248), beside it and for the same stated reason: there is
	-- no edge to hang it on, so it is a level rule asked once a tick. KAREN, 2026-10-23: *"when I
	-- respown hunt should over then I can enter to next games"*.
	respawnSweep()
	dispatch({ kind = "tick", aliveBoars = boarsAlive() })
	if now() - lastBroadcast >= config.STATE_HEARTBEAT then
		broadcast(true)
	end
end

-- A TIED PLAYER WHO RESPAWNS MUST NOT WALK AWAY FREE. Nothing damages players (shotgun design
-- section 15 item C), but the Reset button exists, and "press Escape, Reset, and the penalty is over"
-- is not a penalty. The tie is re-applied to the new character, at the same tree.
--
-- SINCE TASK 248 THAT RE-APPLIED TIE LASTS AT MOST ONE TICK IN A LOBBY WORLD, and that is not a
-- contradiction: `respawnSweep` notices the same respawn and takes him OUT OF THE DRIVE, which
-- unties him on the way (`Match.withdraw`). The sentence above still holds, because what he has
-- bought with the Reset button is not his freedom -- it is the rest of his hunt. In a world with no
-- lobby (the DEV arena) nothing withdraws anybody and the rope is still the whole of the penalty.
local function watchCharacter(player: Player)
	characterWatch[player.UserId] = player.CharacterAdded:Connect(function(character)
		-- AND THE OUTFIT IS RE-APPLIED FIRST, tied or not (Task 82). `Body.place` dresses the
		-- character it spawns, so a player who is placed at the start of a drive is dressed -- but
		-- the Reset button and a death make a NEW character in the middle of one, and this handler
		-- was the only thing watching for it. Before this line a driver who reset spent the rest of
		-- the drive with no vest while the shooters kept their hats, which is exactly what Karen
		-- reported not seeing (PLAYTEST.md, 2026-09-27). One call, at the moment a character
		-- arrives, from the module that owns what is written onto a character.
		-- THROUGH THE APPEARANCE WINDOW SINCE TASK 151 (`docs/design/beater-kit.md` section 5): the
		-- outfit now includes the base clothing COLOUR, and a colour is the half that a late
		-- appearance load can overwrite. The welded hat cannot be; a `BodyColors` write can.
		Body.dressWhenLoaded(player, character, config)
		-- AND THE START-LINE HOLD IS PUT BACK (task 158). THIS is the handler the drive's OWN
		-- respawn reaches: `placePlayers` calls `LoadCharacter`, so the character `applyHold` froze
		-- is already gone by the time the beater is standing on her line -- and an unheld beater
		-- would simply walk off before the countdown ended. The same shape as the tie below (wait
		-- for the root, then check the fact is STILL true before writing), and it holds THIS
		-- character rather than `player.Character`, which may be a newer one by then.
		if heldStill[player.UserId] then
			task.spawn(function()
				-- THROUGH `Body.holdWhenLoaded` SINCE TASK 168, and the difference is one bounded
				-- wait for the character to be PARENTED. This code waited for the root and then
				-- asked `character.Parent` once -- and in the Forest Test `CharacterAdded` fires
				-- before the parent is set (the task-157 finding, measured again here), so the
				-- re-apply did nothing and a placed beater could walk through the whole countdown.
				-- The wait, the bound and the reason now live in `Body`, which owns the question.
				if
					Body.holdWhenLoaded(character, player.UserId, function()
						return heldStill[player.UserId] == true
					end)
				then
					stats.holdsReapplied += 1
				end
			end)
		end
		local record = tied[player.UserId]
		if not record then
			return
		end
		task.spawn(function()
			if not character.PrimaryPart then
				character:GetPropertyChangedSignal("PrimaryPart"):Wait()
			end
			if tied[player.UserId] == record and record.tree.Parent then
				Body.tie(player, record.tree, config)
				refreshArmingFor(player)
			end
		end)
	end)
end

local function watchPlayer(player: Player)
	names[player.UserId] = player.Name
	board = Score.join(board, player.UserId, player.Name, state.assignment[player.UserId])
	watchCharacter(player)
	if autoEnrol then
		dispatch({ kind = "join", userId = player.UserId, name = player.Name })
	else
		-- REGISTERED, NOT A PARTICIPANT (task 177). A world with a lobby decides who is in the drive,
		-- and joining the server is not joining the hunt: he is in `names`, he has a board row and
		-- the character watch is on him, and `state.participants` has never heard of him -- so
		-- `Phase.participantCount` does not see him and `enoughPlayers` is false.
		--
		-- ONE BROADCAST, because nothing else will send one: no event was dispatched, so the clients
		-- would otherwise not learn that a player exists until the next heartbeat push.
		--
		-- THE `join` FEED LINE MOVES WITH THE ENROLMENT, and that is an improvement rather than a
		-- loss: *"X joined"* is now printed when he steps into the circle beside the truck, which is
		-- when he actually joined the hunt.
		broadcast(false)
	end
end

-- ---------------------------------------------------- the lobby's seam (task 177)
--
-- TWO DOORS AND ONE READER, and they are the whole of what the lobby may do to the drive. The shape
-- is the one this owner already has five times over -- *the world provides; the owner decides*
-- (`world.markers`, `world.placement`, `world.boars`, `world.bots`, `world.economy`): the lobby
-- calls in, this module decides, and nothing under `src/server/Match/` knows a lobby exists.
-- Design: docs/design/lobby.md section 4.2

-- IS HE IN THE DRIVE'S ROSTER? The read half of the seam, beside `isTied` / `isHeld` / `assignmentOf`.
function Match.isParticipant(userId: number): boolean
	return state.participants[userId] ~= nil
end

-- ONE PLAYER, INTO THE DRIVE. Everything after the dispatch is today's code: `Waiting` ->
-- `Assigning` once `MIN_PLAYERS` is met and the markers are complete.
--
-- IDEMPOTENT, AND THE GUARD IS NOT DEFENSIVE. `Phase.step`'s `join` branch re-assigns a player to the
-- SMALLER TEAM and re-places him when the phase is `Assigning` or `Running`, so a second enrol of a
-- man who is already in the drive would move him mid-drive. The lobby scans at 10 Hz.
function Match.enrol(player: Player): boolean
	local userId = player.UserId
	if state.participants[userId] ~= nil then
		return true
	end
	if names[userId] == nil then
		-- NOT REGISTERED: this owner has never seen him, so there is no board row to put a team on
		-- and no character watch to hang a hold off. Refused rather than half-done.
		return false
	end
	stats.enrolments += 1
	dispatch({ kind = "join", userId = userId, name = player.Name })
	return state.participants[userId] ~= nil
end

-- THE ROSTER, EMPTIED, WITH NOTHING ANNOUNCED -- which is the whole difference from a `leave`: a
-- player standing in the results scene has not left, he is simply not in the next drive.
--
-- REFUSED IN A WORLD THAT ENROLS AUTOMATICALLY, because there nothing would ever refill the roster
-- and the drive would sit in `Waiting` for ever.
function Match.dismissAll(): number
	if autoEnrol then
		warn("[match] dismissAll in a world that enrols automatically: refused")
		return 0
	end
	local count = Phase.participantCount(state)
	if count == 0 then
		return 0
	end
	stats.dismissals += 1
	dispatch({ kind = "dismiss" })
	return count
end

-- After this, NO table in this system is keyed by that player.
function Match.forget(player: Player)
	local userId = player.UserId
	names[userId] = nil
	-- The hold goes with the player, exactly as the rope does: `Body.forget` below drops his saved
	-- WalkSpeed row, so leaving this set would hold a userId nothing can ever free (task 158).
	heldStill[userId] = nil
	-- ...AND HIS SEATED WISH (task 229), for the same reason: no table in this owner may be keyed by
	-- a man who has gone.
	seatedWishes[userId] = nil
	-- ...AND THE CHARACTER THE DRIVE GAVE HIM (task 248), which is a reference to a Model and so is
	-- the one row in this file whose leak would hold an Instance alive.
	placedCharacter[userId] = nil
	if tied[userId] then
		-- The rope outlives nobody: the Instance goes with the player (design section 4.4).
		untie(userId)
	end
	Body.forget(userId)
	local watch = characterWatch[userId]
	if watch then
		watch:Disconnect()
		characterWatch[userId] = nil
	end
	board = Score.leave(board, userId)
	for _, credit in pairs(pushCredit) do
		credit[userId] = nil
	end
	dispatch({ kind = "leave", userId = userId, name = player.Name })
end

function Match.start(injected)
	assert(not started, "Match.start() called twice")
	started = true
	world = injected or {}
	-- THE WORLD'S OWN NUMBERS, MERGED BEFORE THE FIRST STATE EXISTS (design section 4.2.1):
	-- `Phase.initial` seeds `seed` from the config, so merging after it would seed the state from the
	-- wrong table. With no `config` field this is `Match.CONFIG` itself, by identity.
	config = Match.mergeConfig(Match.CONFIG, world.config)
	-- WHAT A PLAYER HAS BOUGHT, from the economy's read-only view (task 178). nil when no economy
	-- was injected, which is every spec that starts no money and is the game before this task.
	ownedProvider = if world.economy and world.economy.ownedOf then world.economy.ownedOf else nil
	-- WHERE THE GROUND IS, AS THE WORLD'S OWN SINGLE ANSWER (task 192). `Body` snaps every placement
	-- onto it, and in the Forest Test this is `ForestTest.groundAt` -- the same function
	-- `Markers.setReaders`, `Bots.start` and `Lobby.start` are already handed, so there is ONE
	-- definition of "where is the ground" per world and not four. A world that injects nothing gets
	-- `Body`'s own ray, which is the DEV place.
	Body.setGroundReader(world.groundAt)
	-- `~= false` IS THE IDIOM THIS FUNCTION ALREADY USES for `world.remotes` and `world.heartbeat`:
	-- a world that injects nothing is unchanged (task 177).
	autoEnrol = world.enrol ~= false
	state = Phase.initial(config)
	board = Score.new()
	table.clear(names)
	table.clear(tied)
	table.clear(seatedWishes)
	table.clear(characterWatch)
	table.clear(placedCharacter)
	table.clear(pushCredit)
	snapshotCache = nil
	botsRebuiltForDrive = nil

	if world.remotes ~= false then
		remotes = world.remotes or Drive.remotes()
	end

	Body.ensureTeams()
	readMarkers()

	if world.boars then
		if world.boars.Downed then
			table.insert(connections, world.boars.Downed:Connect(onDowned))
		else
			-- A missing dependency shows as a number in the harness report rather than as a match
			-- that silently scores zero (design section 7.4).
			stats.killSignalMissing += 1
			warn("[match] the boar runtime has no Downed signal: kills will not score")
		end
		if world.boars.Despawned then
			table.insert(connections, world.boars.Despawned:Connect(onDespawned))
		end
	end

	-- The weapon publishes a shot that went into the drive; this owner decides what it costs. The
	-- weapon writes nothing about the penalty and knows nothing about it (design section 8.2).
	if world.weapon and world.weapon.SafetyViolated then
		table.insert(connections, world.weapon.SafetyViolated:Connect(onSafetyViolation))
	elseif config.SAFETY_ENABLED then
		-- A number in the harness report, not a safety rule that silently never fires.
		stats.safetySignalMissing += 1
		warn("[match] the weapon has no SafetyViolated signal: the safety rule cannot fire")
	end

	local service = playersService()
	for _, player in ipairs(service:GetPlayers()) do
		watchPlayer(player)
	end
	table.insert(connections, service.PlayerAdded:Connect(watchPlayer))
	table.insert(
		connections,
		service.PlayerRemoving:Connect(function(player)
			Match.forget(player)
		end)
	)

	if world.heartbeat ~= false then
		heartbeat = RunService.Heartbeat:Connect(function(dt)
			Match:step(dt)
		end)
	end
end

function Match.stop()
	if not started then
		return
	end
	started = false
	applyRelease() -- nobody stays frozen because a spec stopped the match
	applyFree() -- ...and that includes a beater held at the start line (task 158)
	applyClearScene() -- ...and no lamp or carcass is left standing in the world (task 159)
	if world and world.bots then
		-- ...AND NO BOT (task 161), for exactly the same reason: a spec that stops the drive must not
		-- leave eight rigs standing in the wood for the next one to find.
		world.bots.clear()
	end
	botsRebuiltForDrive = nil
	-- ...AND THE WORLD'S NUMBERS GO WITH THE WORLD. A spec that started a 300-second drive must not
	-- leave the next require of this singleton reading 300.
	config = Match.CONFIG
	-- ...AND NOR DOES ITS ENROLMENT SWITCH (task 177): a spec that started a lobby world must not
	-- leave the next require of this singleton refusing to enrol anybody who joins.
	autoEnrol = true
	-- ...NOR THE OWNERSHIP READ (task 178): a stopped drive must not keep asking a dead economy what
	-- a player has bought, and nil is the answer that leaves a beater exactly as he was.
	ownedProvider = nil
	-- ...NOR THE GROUND READER (task 192), for exactly the same reason: a spec that started a forest
	-- world must not leave the next require of this singleton measuring the ground with a function
	-- whose Workspace has gone.
	Body.setGroundReader(nil)
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	for userId, watch in pairs(characterWatch) do
		watch:Disconnect()
		characterWatch[userId] = nil
	end
	world = nil
	remotes = nil
	markerSet = nil
end

-- DELIBERATELY NOT DESTROYED HERE: the design has stop() destroy the three signals, but this is
-- a singleton ModuleScript that production and every spec share, and a destroyed BindableEvent stays
-- destroyed for the rest of the session -- the next spec to require Match would get a dead module.
-- stop() disconnects everything it connected, which is what the teardown assertion checks.
-- reviews/task-32/DESIGN_DELTA.md records it.

return Match
