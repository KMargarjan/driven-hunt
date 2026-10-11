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
-- each side: `Phase.heldUserIds` says who is held, `Match.quarryLines` says what may be shot.
--
-- TASK 159 ADDED THE END OF A DRIVE AND THE RESULTS SCENE, and no phase either. Karen: *"Timer or
-- when all beaters cross line of hunters. And yes could be that all they standing around the animals
-- there is light on 4 corners and then showing image transperent with results table"*. So:
--   * a drive ends on the clock as it always did, OR earlier when every REAL beater is through the
--     hunters' line -- `Match.crossedLine` measures it against the nearest stand, `Phase` decides;
--   * the `Scoring` phase IS the scene: this drive's animals laid out in a row behind the middle
--     stand (`Match.gatherSpotFor`), four lamps on the four corners, everybody held and stood round
--     them (`Body.stand`), and the results table on screen -- which is the drive's own score panel
--     reading the snapshot this owner already broadcasts. There is no second score and no new remote.
--
-- Design: docs/design/drive.md
-- Note:   docs/research/2026-09-25-drive.md, docs/research/2026-10-12-drive-end-and-results-scene.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

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
	-- 20 -> 10: the old 20 was "long enough to read the teams and walk to your post", and Karen has
	-- now named the number she wants. See backups/2026-10-11_task158_intermission_20s.txt.
	INTERMISSION_SECONDS = 10, -- K
	-- HOW LONG THE RESULTS SCENE IS UP (task 159): the Scoring phase, unchanged in length. Karen's
	-- scene -- the animals laid out, the four lights, everybody standing round them and the results
	-- table on screen -- lasts exactly this, and then the next drive starts as it always did.
	SCORE_SECONDS = 25, -- K
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
		RING_RADIUS_STUDS = 14, -- K, close enough to see the animals, far enough not to stand on them
		CORNER_STUDS = 16, -- K, the four lamps stand just outside the ring
		-- The display animal: a boar-sized box, scaled per kind. The SCALES are data here rather than
		-- a require of `Boar.CONFIG.KINDS`, because the scene must not learn what a boar is -- and
		-- they are the same three numbers that config holds (male 1.0, female 0.85, cub 0.45).
		ANIMAL_SIZE = Vector3.new(1.6, 1.4, 4.0),
		ANIMAL_SCALES = { male = 1.0, female = 0.85, cub = 0.45 },
		ANIMAL_COLOR = Color3.fromRGB(58, 48, 42),
		POST_SIZE = Vector3.new(0.6, 10, 0.6),
		POST_COLOR = Color3.fromRGB(70, 60, 50),
		LIGHT_COLOR = Color3.fromRGB(255, 190, 120), -- K's "light on 4 corners", warm: it is dusk
		LIGHT_BRIGHTNESS = 4,
		LIGHT_RANGE_STUDS = 60,
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
	-- WHAT HAPPENS AT 0 TO A HUNTER WHO IS NOT AT HIS STAND: NOTHING NEW, AND THAT IS DELIBERATE
	-- (task 158). The drive has no rule for a hunter off his post and never has -- the only penalty
	-- in this system is the safety one (firing toward the drive, `SAFETY_*` above). The 6-stud leash
	-- Karen has felt is `ForestTest.leash`, which belongs to the Forest Test world, applies only to
	-- a hunter who LOCKED a stand there, and opens on `Running` -- so it is untouched by this task
	-- and still runs in that world. So at 0 the drive simply starts: a hunter still walking loses
	-- shots and nothing else. Inventing a punishment for a ten-second timer is a Karen decision, not
	-- a Builder one (TASKS.md row 158a).
	-- WHAT YOU MAY SHOOT, AS THE RULE REALLY IS IN THE CODE (task 158). The start card asks "what
	-- they can shoot", and Karen's words were *"wild boar -- male, female; NOT piglets/cubs"*.
	--
	-- THE CODE DOES NOT HAVE THAT RULE AND THIS CARD WILL NOT PRETEND IT DOES. `Boar.CONFIG.KINDS`
	-- distinguishes male, female and cub and the drive spawns all three, but `POINTS.KILL` scores a
	-- kill by HIT ZONE alone -- there is nothing anywhere that refuses a cub, deducts for one or
	-- even names one as different. So the card states today's rule, and the rule Karen described is
	-- a decision waiting for her (TASKS.md row 158a). The day a cub is protected, this row and the
	-- thing that enforces it change together.
	QUARRY = {
		{ species = "WILD BOAR", kinds = { "male", "female", "cub" } },
	},
	QUARRY_NOTE = "every one of them counts - no cub rule yet",
	PLACE_TIMEOUT = 5,
	STAND_HEIGHT_STUDS = 3.5, -- how far above a post's top face a character is put down

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

	-- points (design section 7.1)
	POINTS = {
		KILL = { head = 100, chest = 80, body = 50, legs = 30, unknown = 50 }, -- K
		ASSIST = 10, -- K
		ASSIST_MIN_DAMAGE = 25, -- K, a quarter of Boar.CONFIG.WOUND.LETHAL: one pellet is not an assist
		PUSH = 25, -- K, to a driver who was the reason it ran
		PUSH_RADIUS = 60, -- K, 1.5x Boar.CONFIG.DETECT_RADIUS
		PUSH_WINDOW = 20, -- K, seconds before the kill
		ESCAPE_WOUNDED = 0, -- K, "take the shot you can make"
		SAFETY_PENALTY = -50, -- K, 1.7b
	},
	PUSH_SAMPLE_HZ = 2,

	-- the safety rule (design section 11.4). Karen's rule as written: tied to a tree until the drive
	-- ends, visible to everyone, announced in the feed.
	SAFETY_ENABLED = true,
	SAFETY_MISS_STUDS = 12, -- K, ~3.4 m: a shot that passes within three metres of a person is a shot at them
	SAFETY_RANGE_STUDS = 330, -- Shotgun.CONFIG.RANGE_STUDS.Slug; past it nothing arrives
	-- The depth of a person, added to where the shot stopped. See Penalty.judge: without it a shot
	-- that HITS a driver stops on his surface, a stud in front of his root, and would be judged
	-- harmless. reviews/task-35/DESIGN_DELTA.md.
	SAFETY_BODY_STUDS = 4,
	SAFETY_GRACE_SECONDS = 0, -- K, no grace: the rule is the rule from the first second
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
function Match.quarryLines(cfg): { string }
	local lines = {}
	for _, row in ipairs(cfg.QUARRY or {}) do
		table.insert(lines, string.format("%s: %s", row.species, table.concat(row.kinds, ", ")))
	end
	if cfg.QUARRY_NOTE then
		table.insert(lines, cfg.QUARRY_NOTE)
	end
	return lines
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
-- WHO IS HELD STILL, AND THERE ARE TWO OCCASIONS NOW: the beaters at the start line for the length
-- of the countdown (task 158), and EVERYBODY at the results scene for the length of Scoring (task
-- 159). The same shape as `tied` above and for the same reason: the pure machine SAYS who must be
-- held and this is the one table that remembers it, so the character watch can put the hold back on
-- the character `placePlayers` is about to respawn. Emptied by `free`, which `Phase.enterRunning`,
-- `Phase.enterAssigning` and `Phase.enterWaiting` all emit -- so a hold cannot outlive its phase.
local heldStill: { [number]: boolean } = {}
-- WHAT THIS DRIVE SHOT, in the order it was shot, for the results scene to lay out (task 159). It is
-- NOT a second score: it carries the kind and the hit zone and no points at all, and the board
-- (`Score`) is still the one answer to how the drive went. Cleared when a drive starts.
local driveKills: { any } = {}
local characterWatch: { [number]: RBXScriptConnection } = {}
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
	emptyTeamDrives = 0,
	unknownZoneKills = 0,
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
	sceneAnimals = 0,
	sceneMoved = 0,
	violations = 0,
	safetySignalMissing = 0,
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

-- WHAT THIS DRIVE HAS SHOT SO FAR, in order, as the results scene lays it out (task 159). A copy, so
-- a caller cannot write the drive's record.
function Match.driveKills(): { any }
	return table.clone(driveKills)
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
		})
	end
	local tiedList = {}
	for userId in pairs(tied) do
		table.insert(tiedList, userId)
	end
	table.sort(tiedList)

	snapshotCache = Drive.deepFreeze({
		phase = state.phase,
		phaseEndsAt = serverTimeFor(state.phaseEndsAt),
		driveNumber = state.driveNumber,
		-- The WIRE IS UNCHANGED (design decision L: no sounder field on it). A player is told how
		-- many ANIMALS have been released, which is the number that was always meant.
		boarsReleased = state.boarsReleased,
		boarsLeft = math.max(0, config.BOARS_PER_DRIVE - state.boarsAccounted),
		waitingFor = Phase.waitingFor(state, config),
		-- WHAT MAY BE SHOT IN THIS DRIVE, in the server's own words (task 158): the start card's
		-- quarry lines. The same shape as `waitingFor` right above it, and for the same reason --
		-- the rule is the server's and the Hud only draws it.
		quarry = Match.quarryLines(config),
		rows = rows,
		tied = tiedList,
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
	for _, userId in ipairs(targets :: { number }) do
		local player = playersService():GetPlayerByUserId(userId)
		local team = state.assignment[userId]
		if player and team and markerSet then
			-- WHERE a player of this team stands may be the WORLD's answer; putting him there is
			-- still `Body`'s and only `Body`'s (design section 4.3.1). The default IS
			-- `Body.placementFor`, with the same argument order, so a world that injects nothing
			-- takes exactly the line this file has always taken.
			--
			-- The Forest Test needs it because its road is a sine curve over ground that climbs 56
			-- studs in 400: `placementFor`'s generic -Z look is up to 23 degrees off the push there.
			local place = if world and world.placement then world.placement else Body.placementFor
			local cframe = place(markerSet, team, indexWithinTeam(userId, team), config)
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

local function applySpawnSounder(position: Vector3?, size: number?, quickSpread: number?)
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
			return world.boars:spawnSounder(position, animals, spread)
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
		state = Phase.releaseFailed(state, now(), animals)
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

-- ------------------------------------------------------------------ the results scene (task 159)
--
-- THE SCENE IS `Match.Scene`'S INSTANCES AND `Body`'S CHARACTERS, and this is the one place either is
-- asked for: the spot and the facing are this owner's reading of the world's own geometry
-- (`Match.gatherSpotFor` over the marker set), the animals are this drive's own kill record, and
-- WHERE A PLAYER STANDS is still written by `Body` alone.
--
-- A WORLD THAT ANSWERS NOWHERE GETS NO SCENE AND ONE LINE SAYING SO, which is the same shape
-- `applyPlace` already has: a drive whose markers have no stands has nothing to gather the animals
-- behind, and that is a fact about the world, not an error.
local function applyScene()
	if not config.SCENE.ENABLED then
		return
	end
	local spot, facing = Match.gatherSpotFor(markerSet, config)
	if spot == nil or facing == nil then
		stats.scenesNowhere += 1
		print(
			string.format("[match] nowhere to gather the drive: posts=%d", if markerSet then #markerSet.posts else -1)
		)
		return
	end
	stats.scenes += 1
	stats.sceneAnimals += Scene.build(spot, facing, driveKills, config)

	-- EVERYBODY STANDING ROUND THEM, in roster order so the ring is the same ring every drive.
	local ids = Phase.participantIds(state)
	local ring = Scene.ringLayout(spot, #ids, config)
	for index, userId in ipairs(ids) do
		local player = playersService():GetPlayerByUserId(userId)
		if player and ring[index] and Body.stand(player, ring[index]) then
			stats.sceneMoved += 1
		end
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
		elseif kind == "placePlayers" then
			applyPlace(effect.userIds)
		elseif kind == "refreshArming" then
			applyRefreshArming(effect.userIds)
		elseif kind == "spawnSounder" then
			applySpawnSounder(effect.position, effect.size, effect.spread)
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

-- The one place the machine is driven. Every caller goes through here, so the phase can never
-- advance without its effects being applied and the snapshot cache can never go stale.
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
	end
	local endedEarlyBefore = state.endedEarly
	local holdbacksBefore = state.holdbacks
	state, effects = Phase.step(state, filled, now(), config)
	if state.endedEarly and not endedEarlyBefore then
		stats.drivesEndedByBeaters += 1
	end
	snapshotCache = nil

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
		-- section 6.2). Read on the NEXT step, never from inside dispatch: readMarkers dispatches
		-- an event of its own, and a dispatch inside a dispatch would apply effects out of order.
		markersStale = true
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

	applyEffects(effects)
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
function Match.crossedLine(position: Vector3?, line, posts, marginStuds: number?): boolean
	if typeof(position) ~= "Vector3" or not (line and typeof(line.normal) == "Vector3") then
		return false
	end
	if line.normal.Magnitude < 1e-4 or typeof(line.position) ~= "Vector3" then
		return false
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
	return (at - reference):Dot(normal) <= -(marginStuds or 0)
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

-- The weapon still decides and still writes; this only answers the question.
function Match.mayCarryWeapon(player: Player): boolean
	if state.phase == "Waiting" then
		return false
	end
	if tied[player.UserId] then
		return false
	end
	local team = state.assignment[player.UserId]
	if team == "Shooters" then
		return true
	end
	return team == "Drivers" and config.DRIVERS_MAY_SHOOT
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

-- HOW MANY REAL BEATERS ARE IN THIS DRIVE, AND HOW MANY OF THEM ARE THROUGH THE HUNTERS' LINE (task
-- 159). The owner's measurement; the RULE is `Phase.beatersThrough`, which only compares the two.
--
-- `driverPositions` IS THE READ, and it is the right one for exactly the reason the safety rule uses
-- it: it is keyed by userId, so the quick test's phantom and the forest's wave beaters -- which carry
-- non-numeric ids -- are filtered out by `Match.playerDrivers` and can never end a drive. Karen's
-- rule is about the people walking up.
function Match.beaterCrossing(): (number, number)
	local beaters = driverPositions()
	local line = if markerSet then markerSet.line else nil
	local posts = if markerSet then markerSet.posts else nil
	local across = 0
	for _, beater in ipairs(beaters) do
		if Match.crossedLine(beater.position, line, posts, config.BEATER_CROSS_MARGIN_STUDS) then
			across += 1
		end
	end
	return #beaters, across
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

local function creditFor(boarId: string?): { [number]: number }
	local out = {}
	local credit = if boarId then pushCredit[boarId] else nil
	if not credit then
		return out
	end
	local at = now()
	for userId, seen in pairs(credit) do
		if at - seen <= config.POINTS.PUSH_WINDOW then
			out[userId] = seen
		end
	end
	return out
end

local function onDowned(record)
	if not Phase.isLive(state) then
		return -- a shot at a carcass between drives scores nothing
	end
	stats.kills += 1
	if record.killingZone == nil or config.POINTS.KILL[record.killingZone] == nil then
		stats.unknownZoneKills += 1
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

local function readMarkers()
	-- A WORLD MAY HAND OVER A SET, OR A FUNCTION THAT MEASURES ONE (design section 4.1.6). The
	-- Forest Test's geometry is raycast off its own terrain, so its set has to be built rather than
	-- held: a table captured once at boot would be a measurement taken before the place had
	-- finished loading. Every existing caller passes a table and is bit-identical.
	--
	-- It is re-read on exactly the two occasions a TAGGED world is re-read, and no others: once a
	-- second while `Waiting`, and once on entering `Assigning` (`markersStale`).
	if type(world.markers) == "function" then
		markerSet = world.markers()
	elseif world.markers then
		markerSet = world.markers
	else
		markerSet = Markers.read(world.collection)
	end
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
	dispatch({ kind = "tick", aliveBoars = boarsAlive() })
	if now() - lastBroadcast >= config.STATE_HEARTBEAT then
		broadcast(true)
	end
end

-- A TIED PLAYER WHO RESPAWNS MUST NOT WALK AWAY FREE. Nothing damages players (shotgun design
-- section 15 item C), but the Reset button exists, and "press Escape, Reset, and the penalty is over"
-- is not a penalty. The tie is re-applied to the new character, at the same tree.
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
				if not character.PrimaryPart then
					character:GetPropertyChangedSignal("PrimaryPart"):Wait()
				end
				if heldStill[player.UserId] and character.Parent and Body.holdCharacter(character, player.UserId) then
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
	dispatch({ kind = "join", userId = player.UserId, name = player.Name })
end

-- After this, NO table in this system is keyed by that player.
function Match.forget(player: Player)
	local userId = player.UserId
	names[userId] = nil
	-- The hold goes with the player, exactly as the rope does: `Body.forget` below drops his saved
	-- WalkSpeed row, so leaving this set would hold a userId nothing can ever free (task 158).
	heldStill[userId] = nil
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
	state = Phase.initial(config)
	board = Score.new()
	table.clear(names)
	table.clear(tied)
	table.clear(characterWatch)
	table.clear(pushCredit)
	snapshotCache = nil

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
	-- ...AND THE WORLD'S NUMBERS GO WITH THE WORLD. A spec that started a 300-second drive must not
	-- leave the next require of this singleton reading 300.
	config = Match.CONFIG
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
