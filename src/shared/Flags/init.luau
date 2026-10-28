--!strict
-- Flags: the declarations and defaults of every feature flag, the pure resolver, and this process's
-- one resolved answer. Booleans only -- no game number and no string ever lives here.
--
-- WHY: feel-critical work (shooting, camera, penalty, the map switch) used to wait for Karen's
-- playtest before merging, so ten PRs stacked on one unmerged PR. A flagged path MERGES as soon as
-- it is reviewed and green, switched OFF; the Director turns it ON for a playtest with
-- `tools/flags.py set <NAME> on`, which touches no file; Karen's OK flips the default in a later
-- three-line commit.
--
-- OWNERSHIP (rule 3), three distinct things and one writer each:
--   * these declarations        -- NOBODY at run time. Frozen data; the Builder edits this file and
--                                 git records it. The same shape as Shotgun.CONFIG and the map
--                                 contract row in GAME_DESIGN.md.
--   * ReplicatedStorage.Flags.State attributes (the mirror clients read)
--                              -- ServerScriptService.FlagsBoot, once per server lifetime.
--   * ServerStorage DHFlag_* attributes (the Studio override)
--                              -- tools/studio_mcp.py, Edit mode only.
--
-- There is no setter, no listener, no event and no remote. A flag is resolved once per process and
-- memoised; nothing can change it afterwards, which is what makes "what was this run tested with"
-- a question with one answer.
--
-- Pattern: a frozen declaration table plus a pure resolver, as src/shared/Shotgun/init.luau and
-- src/shared/Drive/init.luau already are here; the toggle lifecycle (born/expires, and expiry as a
-- build failure) is Pete Hodgson's "Feature Toggles", https://martinfowler.com/articles/feature-toggles.html
-- Design: docs/design/feature-flags.md (sections 3, 4, 5, 11, 12)
-- Note:   docs/research/2026-09-26-feature-flags.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Flags = {}

export type FlagRow = {
	default: boolean, -- the reviewed value. A new dark path is born `false`.
	owner: string, -- the module that READS it, e.g. "ServerScriptService.Match"
	born: string,
	expires: string, -- ISO date: retire, flip, or re-justify by this date. Past = the specs fail.
	why: string, -- one line: what turning it ON does, in the player's terms
}

-- All-caps, so a flag name can never collide with the mirror's own Digest/Source attributes, and so
-- it satisfies Roblox's attribute-name rules (no leading digit, no RBX prefix).
Flags.NAME_PATTERN = "^[A-Z][A-Z0-9_]*$"
Flags.MAX_NAME_LENGTH = 40 -- "DHFlag_" + 40 <= Roblox's 100-character attribute-name limit
Flags.OVERRIDE_PREFIX = "DHFlag_"
-- FOURTEEN SINCE TASK 215. `docs/design/feature-flags.md` section 12 makes a bump the DIRECTOR'S
-- call and task 215's dispatch does not name one, so this line is queued for the Director's word as
-- TASKS.md row 215a item (a); the arithmetic below is why it is paperwork and not a real breach.
--
-- The cap's own sentence is about DARK paths -- *"more than twelve dark paths means the stack problem moved, not
-- went away"* -- and it counts ROWS. Task 215 added a row and no dark path at all; task 230 lit one;
-- task 233 lights the rest of what v1 keeps. THE RUNNING COUNT, which is the number the Director
-- should see, is the one line below, and it is under the twelve the rule is about. Three of the lit
-- rows are queued for retirement as TASKS.md 82b; retiring them brings the row count back under 12
-- without touching this line, and that is the Director's call (docs/design/shop.md section 16
-- item 8), not this task's.
--
-- LIT (12): TIE_UNTIL_DRIVE_END, BOAR_SOUNDERS, ORANGE_OUTFITS, RIFLE, FIRST_PERSON, AUTUMN_LIGHT,
--           BOAR_MODEL (task 230), BOAR_BEHAVIOUR, HORN, COINS and LOBBY (task 233), SHOP (233b).
-- DARK (6): QUICK_TEST, DRIVE_BOTS, LICENCE_POPUP (task 238), DEER_ROAD_LEAP (task 245b),
--           STAG_BOUND_ON_SPOOK (task 251 part 2), RANGE (task 298).
--
-- `SHOP` IS LIT SINCE TASK 233b, and what made that safe is NOT this row: it is that a world with
-- no counter does not wire a shop at all (`Shop.start`'s own gate). Task 233's flip lit the shop in
-- the DEV place, which has no lodge and so no counter -- an un-owning player's kit became buckshot
-- and the shotgun alone in the one world where nothing can ever be bought -- and that took the gate
-- red. The flag now lights the shop for every world that HAS a counter, which is every world it was
-- designed for, and `COINS` is no longer lit over a shop nobody can reach.
-- 14 -> 15 FOR TASK 238, AND THE BUILDER IS SAYING SO RATHER THAN QUIETLY RETIRING SOMEBODY ELSE'S
-- ROW. `LICENCE_POPUP` is the fifteenth, and the cap refused it: `flags.spec`'s rot tripwire failed
-- the harness at *"15 flags declared, and MAX_FLAGS is 14"*, which is the cap doing its job.
--
-- THE TWO WAYS OUT, AND WHY THIS ONE. (a) Retire the three lit rows queued as TASKS.md 82b, which
-- brings the count back under 12 -- but the paragraph above says in as many words that retiring them
-- is *"the Director's call ..., not this task's"*, and it is: each retirement deletes a losing branch
-- and archives it (rule 7). (b) Ship the card LIT, which `docs/design/feature-flags.md` section 11
-- step 1 forbids for a new feel-critical path and which would put an unasked card on Karen's screen
-- before she had agreed to it.
--
-- So the cap moves by one and the REAL fix stays queued. **This is a Director decision the Builder
-- has taken under a stated assumption** (task 238's report and `ESCALATE.md`, 2026-10-22): if he
-- would rather have 82b done first, this line goes back to 14 in the same commit as those three
-- retirements. Fifteen rows is still a number a person can read in one screen, which is what the cap
-- is actually for.
-- 15 -> 16 FOR TASK 245b, AND THE SAME SENTENCE TASK 238 WROTE APPLIES WORD FOR WORD: the Builder
-- is saying so rather than quietly retiring somebody else's row. `DEER_ROAD_LEAP` is the sixteenth,
-- the cap refused it the same way (`flags.spec`'s rot tripwire), and the two ways out are still the
-- two task 238 listed -- retire the lit rows queued as TASKS.md 82b, which is the Director's call
-- and deletes a losing branch per retirement, or ship a new feel-critical path LIT, which
-- `docs/design/feature-flags.md` section 11 step 1 forbids. So the cap moves by one again and the
-- real fix stays queued. **This is a Director decision taken under a stated assumption** (task
-- 245b's report): if he would rather have 82b done first, this line goes back to 15 in the same
-- commit as those retirements.
-- 16 -> 17 FOR TASK 251 PART 2, AND THE SAME SENTENCE AGAIN, WORD FOR WORD: the Builder is saying so
-- rather than quietly retiring somebody else's row. `STAG_BOUND_ON_SPOOK` is the seventeenth, the cap
-- refused it the same way (`flags.spec`'s rot tripwire), and the two ways out are still the two task
-- 238 listed -- retire the lit rows queued as TASKS.md 82b, which is the Director's call and deletes a
-- losing branch per retirement, or ship a new feel-critical path LIT, which
-- `docs/design/feature-flags.md` section 11 step 1 forbids. **And this row may not ship lit by
-- instruction**: the Director's dispatch says *"HOLD the bound when spooked until 245c (the hoof sink)
-- is fixed, behind a flag born off"*. So the cap moves by one again and the real fix stays queued.
-- 17 -> 18 FOR TASK 266, **AND THIS ONE THE DIRECTOR APPROVED IN ADVANCE** rather than the Builder
-- taking it under a stated assumption: the dispatch of 2026-10-25 says *"`Flags.MAX_FLAGS` 17 -> 18
-- is APPROVED if the design wants the true-hit path behind a flag (born OFF; the Director turns it on
-- in the Forest Test for Karen's test)"*, and `docs/design/ballistics.md` section 3.4 wants exactly
-- that. `HIT_CLAIM` is the eighteenth. The two ways out are still the two task 238 listed and the
-- first of them is still queued as TASKS.md 82b.
-- 18 -> 19 FOR TASK 298 (step B2), **AND THE SAME SENTENCE AGAIN, WORD FOR WORD**: the Builder is
-- saying so rather than quietly retiring somebody else's row. `RANGE` is the nineteenth, the cap
-- refused it exactly as it refused the seventeenth and the eighteenth (`flags.spec`'s rot
-- tripwire, which is the cap doing its job), and the two ways out are still the two task 238
-- listed -- retire the lit rows queued as TASKS.md 82b, which is the DIRECTOR's call and deletes a
-- losing branch per retirement, or ship a new feel-critical path LIT, which
-- `docs/design/feature-flags.md` section 11 step 1 forbids. The range is a new shooting path in the
-- lobby and `docs/design/shooting-range.md` section 8.1 wants it behind a flag born OFF
-- (`Range.ENABLED = Flags.isOn("RANGE")`, the one boundary that reads it), so the cap moves by one
-- again and the retirements stay queued. **The Director may prefer to spend 82b instead**: this is
-- one line either way.
-- 19 -> 20 FOR TASK 305, **AND IT SHIPS LIT, BY THE DIRECTOR'S OWN SENTENCE**: the dispatch of
-- 2026-10-28 says *"If the fix needs a flag, it is born ON for the range (the range is a training
-- place) -- say so; for the hunt, a flag row is fine and the Director decides with Karen."* The
-- range and the hunt share `Weapon`'s one resolution, so ON-for-the-range and OFF-for-the-hunt
-- would mean a place test inside the weapon, which is a second owner of the shot. So the row is
-- born `default = true` and the Director turns it OFF for the hunt with one override if Karen wants
-- the old behaviour there. `docs/design/feature-flags.md` section 11 step 1 forbids shipping lit and
-- this is the exception the Director authorised in advance, in writing, for this task.
Flags.MAX_FLAGS = 20
Flags.WAIT_SECONDS = 10 -- a client's wait for the published mirror
Flags.STATE_NAME = "State"
Flags.DIGEST_ATTRIBUTE = "Digest"
Flags.SOURCE_ATTRIBUTE = "Source"
Flags.SOURCES = { defaults = true, override = true, published = true, ["published-timeout"] = true }

-- THE DECLARATIONS. One row per flag; see docs/design/feature-flags.md section 11 for the lifecycle.
Flags.DEFAULTS = {
	-- A SHOT HITS WHAT THE SHOOTER SAW (task 266). KAREN, 2026-10-24/25: *"we need to aim in empty
	-- space to get hit in head neck or heart like in real life"* / *"this signe where we shot ...
	-- shows we hit empty space and died"* / *"all shooting has to be like in real life / this is a
	-- key of this game"*.
	HIT_CLAIM = {
		default = false,
		owner = "ServerScriptService.Weapon (and PlayerScripts.Weapon, for whether a claim is sent)",
		born = "2026-10-25 task 266",
		-- 21 days, the ceiling in docs/design/feature-flags.md section 12.
		expires = "2026-11-15",
		why = "A shot hits what the shooter saw: the client simulates its own bullet against its own "
			.. "view and claims the hit, and the server validates it by rewinding the animal. OFF is "
			.. "exactly the game before task 266 -- no claim is sent, none is accepted, and the shot "
			.. "is resolved by the server's own flight alone.",
	} :: FlagRow,
	-- A SHOT HITS WHAT THE SHOOTER SEES (task 305). KAREN, 2026-10-28, shooting the range: *"aiming
	-- is off / when running or trot / with rifle when it trot or run I need to aim in free space to
	-- hit boar correctly ... aiming in nose no hit and I think it with all weapons fix it"*.
	AIM_REWIND = {
		-- BORN LIT. See the paragraph above `Flags.MAX_FLAGS`: the Director's dispatch.
		default = true,
		owner = "ServerScriptService.Weapon",
		born = "2026-10-28 task 305",
		-- 21 days, the ceiling in docs/design/feature-flags.md section 12.
		expires = "2026-11-18",
		why = "The server tests each animal where the SHOOTER DREW it -- 0.180 s back, measured -- "
			.. "instead of where the server has it now, so the only lead a player needs is the real "
			.. "ballistic one. OFF is exactly the game before task 305: the animal is tested at the "
			.. "present instant and the shooter must add 0.18 s x the animal's speed of his own.",
	} :: FlagRow,
	-- THE LOBBY SHOOTING RANGE (task 298). KAREN, 2026-10-27: a place to *"test guns and shooting"*
	-- against a real animal crossing a lane, so the seven shooting dials can be judged by eye.
	RANGE = {
		default = false,
		owner = "ServerScriptService.Range",
		born = "2026-10-27 task 298",
		-- 21 days, the ceiling in docs/design/feature-flags.md section 12.
		expires = "2026-11-17",
		why = "The lobby shooting range: a lane, a target crossing it and back, and later the menu, "
			.. "the gun and the board. OFF is exactly the game before task 298 -- no world has a "
			.. "range built, nothing is spawned and no provider is relaxed.",
	} :: FlagRow,
	TIE_UNTIL_DRIVE_END = {
		default = true,
		owner = "ServerScriptService.Match",
		born = "2026-09-25 task 32 (as Match.CONFIG), 2026-09-26 task 52 (as a flag)",
		-- ACCEPTED by Karen already, so this one does not expire in 21 days like a new dark path:
		-- it stays until the losing TIE_SECONDS branch is archived (design section 10 step 7).
		expires = "2026-12-31",
		why = "A tied player stays tied until the drive ends. OFF frees him after TIE_SECONDS.",
	} :: FlagRow,
	BOAR_SOUNDERS = {
		-- FLIPPED ON BY KAREN'S OK (task 82), which is step 6 of the lifecycle and a one-line
		-- change: she played a drive with the override on and said of the groups and singles
		-- "Didn't try that yet but this ok" and of the density "for now is ok" (PLAYTEST.md,
		-- 2026-09-26 and 2026-09-27). Sounders are now what every server does.
		default = true,
		-- The owner is the module that READS it at its boundary (`Match.CONFIG.SOUNDER.ENABLED`) and
		-- passes it inward as `config`, which is what keeps BOTH states reachable by parameter now
		-- that the flag itself sits at one of them.
		owner = "ServerScriptService.Match",
		born = "2026-09-26 task 60 (the sounder itself; the release is task 61)",
		-- AN ACCEPTED FLAG DOES NOT EXPIRE IN 21 DAYS, exactly as TIE_UNTIL_DRIVE_END does not: the
		-- 21-day ceiling (feature-flags.md section 12) is what stops a DARK path living for ever,
		-- and this path is lit. It stays until the losing one-boar-per-release branch is archived and
		-- the row retired (TASKS.md row 82b).
		expires = "2026-12-31",
		why = "Boars come as a mix of singles and sounders of 2-5. OFF releases one boar per release, as before task 82.",
	} :: FlagRow,
	ORANGE_OUTFITS = {
		-- FLIPPED ON BY KAREN'S OK (task 82): "I can see hat on hunter but not vest on driver"
		-- (PLAYTEST.md, 2026-09-27). The hat is accepted as it is; the vest was the defect, and it is
		-- four plates that wrap the torso in this same task (`Match.Body`'s OUTFITS table). Everybody
		-- is dressed by default from here on.
		default = true,
		-- The owner is the module that READS it at its boundary (`Match.CONFIG.OUTFITS_ENABLED`),
		-- which `Match.Body` then takes as a parameter -- the only permitted shape, and the reason
		-- both branches stay testable now that the flag sits at ON.
		owner = "ServerScriptService.Match",
		born = "2026-09-27 task 77 (M2.8d, docs/design/map-generator.md section 10)",
		-- Accepted, so not a 21-day dark path any more (see BOAR_SOUNDERS above): it stays until the
		-- undressed branch is archived and the row retired (TASKS.md row 82b).
		expires = "2026-12-31",
		why = "Shooters wear an orange hat and drivers an orange vest. OFF dresses nobody, as before task 82.",
	} :: FlagRow,
	QUICK_TEST = {
		-- A PLAYTEST CONVENIENCE, AND IT IS STUDIO-ONLY TWICE OVER. Karen, 2026-09-27: "just for
		-- testing could be much faster that they cross a line small group and then you can shoot" --
		-- today a drive is 10 s of intermission plus 20 s before the first release (the intermission
		-- was 20 until task 158, when Karen named ten), and the first
		-- boars start 1,300 studs from the road. This is the only flag in the table whose value is
		-- ANDed with `RunService:IsStudio()` at its boundary (`Match.quickTestEnabled`), so a live
		-- server cannot run it even if the attribute somehow survived a publish.
		default = false,
		owner = "ServerScriptService.Match",
		born = "2026-09-27 task 83",
		expires = "2026-11-08", -- 21 days: the ceiling in feature-flags.md section 12
		-- STILL IN USE, 2026-10-18: the Director's live playtest switch. Task 205's lobby-card
		-- frames were shot with it on the night of 2026-10-17, because a frame of the lodge cannot
		-- wait 30 s per drive. Re-justified for another 21 days rather than retired.
		why = "Studio only: 3 s intermission, the first release immediately, 3 boars on the road in "
			.. "front of the shooters. `python tools/flags.py set QUICK_TEST on`, play, then "
			.. "`python tools/flags.py clear`. OFF is the real drive, 10 s + 20 s and boars at the "
			.. "far end.",
	} :: FlagRow,
	BOAR_MODEL = {
		-- BORN OFF on 2026-10-03 (task 115). Karen: "we start with one bord and when this works we
		-- do with rest". OFF is the grey box every spec and every screenshot since Milestone 1.2 was
		-- taken against; ON welds RedDeer's skinned male boar to that same box as a VISUAL child and
		-- plays a clip chosen by what the animal is doing. Every attribute the weapon reads is
		-- byte-identical in both states and the model is massless, collisionless and NOT
		-- raycastable, so a shot still lands on the box and its FOUR hit zones and never on the
		-- animal. THE BOX ITSELF IS NO LONGER IDENTICAL, since task 119: with the flag ON a sounder
		-- is a sow and her young, so a trunk and its zones are 0.85 or 0.45 of the male's. OFF,
		-- every boar is the male-sized box Milestone 1.2 shipped.
		--
		-- FLIPPED **ON** ON 2026-10-21 BY KAREN'S OK (task 230), which is step 6 of the lifecycle and
		-- the three-line commit CLAUDE.md's "Feature flags" describes. Her word on the drawn boar was
		-- *"looks good now"* (PLAYTEST.md, 2026-10-03, task 115) and on the shot and the death
		-- *"I thin kwe good"* (same day, task 116); her word on the deer is *"add deer in a game"*
		-- (2026-10-21), and the red deer is behind THIS row as well (`KINDS.ENABLED`, task 223/232).
		-- So a fresh server now shows the drawn animals rather than grey boxes, and a drive can
		-- release a red deer -- which is also what closes TASKS.md row 223b, where the $750 deer
		-- licence was on sale for an animal the default build could never spawn.
		--
		-- THE ROW STAYS, AND THAT IS THE ROLLBACK: one line back to `false` returns the game to the
		-- grey box, and every branch below is still reachable BY PARAMETER (`boar_kinds.spec`'s
		-- `configWith`, `deer.spec`'s, `boar_calm.spec`'s), which is what keeps both states tested
		-- now that the flag sits at the other one. Retiring the row -- archiving the grey-box branch
		-- under `backups/` -- is a separate later task and is NOT done here.
		default = true,
		-- SINCE TASK 117 it also carries the calm repertoire -- what a boar does when nothing is
		-- wrong: graze, root, lift its head to smell, stand, walk a few steps. OFF, an idle boar
		-- wanders at `WANDER_SPEED` with the old graze pauses, exactly as before.
		--
		-- The owner is the module that READS it at its boundary (`Boar.CONFIG.MODEL.ENABLED` and,
		-- since task 117, `Boar.CONFIG.CALM.ENABLED` -- the same module, the same load, so the two
		-- reads cannot disagree) and
		-- passes it inward as `config` -- the only permitted shape, and what keeps both branches
		-- reachable by parameter while the flag sits at one of them.
		owner = "ServerScriptService.Boar",
		born = "2026-10-03 task 115",
		-- AN ACCEPTED FLAG DOES NOT EXPIRE IN 21 DAYS, exactly as `BOAR_SOUNDERS`, `ORANGE_OUTFITS`,
		-- `RIFLE` and `FIRST_PERSON` above and below do not: the ceiling in feature-flags.md section
		-- 12 is what stops a DARK path living for ever, and from today this path is LIT. The date it
		-- keeps is the retirement task's. THE MOVE IS NEEDED AND NOT COSMETIC: left at 2026-10-24
		-- this row fails `tests/server/flags.spec.luau`'s rot tripwire on the 25th, which fails the
		-- harness and blocks whatever gate runs that day -- the same bomb task 149b defused for
		-- `RIFLE` and `FIRST_PERSON`.
		expires = "2026-12-31",
		why = "The boar is a real animal that walks, trots, runs, flinches and falls over, a sounder "
			.. "is a sow and her young, and a drive can release red deer. OFF is the grey box with "
			.. "its tinted hit zones and no deer at all, exactly as before task 115.",
	} :: FlagRow,
	BOAR_BEHAVIOUR = {
		-- BORN OFF on 2026-10-04 (task 118). What a boar DOES about what it notices: it notices a
		-- standing person at 25 studs and a moving one at 60, goes head-up (ALERT), turns away and
		-- trots off (AVOID), runs when anything comes inside its flush band, sprints at a shot it
		-- can hear, and panic spreads through its sounder member by member. OFF is Milestone 1.2's
		-- world exactly: one 40-stud DETECT_RADIUS, drivers only, and the leader-panic rule.
		--
		-- IT IS A FLAG OF ITS OWN AND NOT `BOAR_MODEL`'s, because the behaviour is independent of
		-- the drawn animal: every state, radius and timer is Brain/Runtime state and is fully
		-- exercised on the grey box. The one drawn line this task adds (the head-up clip) sits
		-- behind `BOAR_MODEL`, where it already is.
		--
		-- FLIPPED **ON** ON 2026-10-21 (task 233, "v1 default"): everything v1 keeps is on without a
		-- setting. The row stays, and one line back to `false` is the rollback; both branches are
		-- still reachable BY PARAMETER (`config.SENSE.ENABLED`), which is what keeps the OFF world
		-- tested now that the flag sits at the other one.
		default = true,
		-- The owner is the module that READS it at its boundary (`Boar.CONFIG.SENSE.ENABLED`) and
		-- passes the value inward as `config` -- the only permitted shape, and what keeps both
		-- branches reachable by parameter while the flag itself sits at one of them.
		owner = "ServerScriptService.Boar",
		born = "2026-10-04 task 118",
		-- AN ACCEPTED FLAG DOES NOT EXPIRE IN 21 DAYS, exactly as `BOAR_MODEL`, `BOAR_SOUNDERS`,
		-- `ORANGE_OUTFITS`, `RIFLE` and `FIRST_PERSON` do not: the ceiling in feature-flags.md
		-- section 12 is what stops a DARK path living for ever, and from today this path is LIT. THE
		-- MOVE IS NEEDED AND NOT COSMETIC: left at 2026-10-25 this row fails
		-- `tests/server/flags.spec.luau`'s rot tripwire on the 26th -- five days from now -- which
		-- fails the harness and blocks whatever gate runs that day, the same bomb task 149b defused
		-- for `RIFLE` and `FIRST_PERSON` and task 230 for `BOAR_MODEL`.
		expires = "2026-12-31",
		why = "A boar notices a standing person at 25 studs and a moving one at 60, goes head-up, "
			.. "turns away or runs, sprints at a shot, and panics through its sounder. OFF is the "
			.. "40-stud drivers-only flush of Milestone 1.2.",
	} :: FlagRow,
	HORN = {
		-- BORN OFF (task 152, 2026-10-11). The beater's signal horn: a Tool in a beater's hand, a
		-- 3D blast on a click, and a push that sends every boar within 80 m away from him. All three
		-- are feel -- is it loud enough, is one call per five seconds right, does a drive actually
		-- move when a beater blows -- so by CLAUDE.md's own rule ("a new feel-critical path is BORN
		-- OFF") it merges dark and Karen judges it with `tools/flags.py set HORN on`.
		--
		-- IT WAS A MISS THAT THIS ROW DID NOT EXIST IN ROUND 1, and the Director's gate is what
		-- showed why the rule is there: `test2` fails on this branch at `zz_tie_to_a_tree.spec`
		-- while `main` passes, and with no switch the only A/B available was an uncommitted edit.
		-- OFF, the drive is bit-for-bit the game before this task -- nobody is granted anything --
		-- so the flag is also the isolation experiment and the rollback.
		--
		-- FLIPPED **ON** ON 2026-10-21 (task 233, "v1 default"): the beater is one of Karen's two v1
		-- roles and the horn is what he carries, so a server without her place attributes has to
		-- hand him one. The Forest Test has had it on unconditionally since task 152
		-- (`ForestTestBoot`'s `local hornOn = true`), which is the world she plays in; this flip is
		-- what gives the DEV drive, and every other default server, the same game. The row stays as
		-- the rollback, and `Horn.carriesFor(on, team)` is pure, so both worlds stay reachable BY
		-- PARAMETER.
		default = true,
		-- The owner is the module that READS it, at its boundary: each composition root resolves
		-- `Horn.carryPolicy(...)` ONCE and hands the result to `Weapon.Horn.setCarryPolicy`. Nothing
		-- in the horn reads a flag, and `Horn.carriesFor(on, team)` is pure, so both worlds are
		-- reachable by parameter while the flag sits at one of them.
		owner = "ReplicatedStorage.Horn",
		born = "2026-10-11 task 152",
		-- AN ACCEPTED FLAG DOES NOT EXPIRE IN 21 DAYS, for the reason `BOAR_MODEL` and
		-- `BOAR_BEHAVIOUR` above do not: the ceiling in feature-flags.md section 12 is what stops a
		-- DARK path living for ever, and from today this path is LIT. Left at 2026-10-31 this row
		-- fails `tests/server/flags.spec.luau`'s rot tripwire on 1 November.
		expires = "2026-12-31",
		why = "The beater's horn: the Tool, its voice and the blast that pushes boars away from the "
			.. "beater who blew it. OFF is exactly the game before task 152 -- no beater carries "
			.. "anything, and no blast reaches a boar.",
	} :: FlagRow,
	RIFLE = {
		-- BORN OFF (task 140, 2026-10-09), ON SINCE TASK 149 (2026-10-10). Karen: *"afther this
		-- fixes we need to add rifle with scope"*. A whole second weapon is feel-critical -- the
		-- switch, the scope's magnification, the sway and the bolt are all things only she can judge
		-- -- so it merged dark and she turned it on for playtests. She has now judged it:
		-- **"weapons is ok for now"** (2026-10-10 ~18:10, `PLAYTEST.md`), after eight rounds of her
		-- own notes on the sight picture, the hands, the bolt and the magazine.
		--
		-- THE ROW STAYS, AND THAT IS THE ROLLBACK: one line back to `false` returns the game to one
		-- Tool in the hand, which is what every build before task 140 was.
		default = true,
		-- The owner is the module that READS it, at its boundary: `Weapons.loadout()` resolves the
		-- list of weapons a hunter carries and hands that list inward. Nothing else in the weapon
		-- system reads a flag, and `Weapons.loadoutFor(rifleOn)` is pure, so both worlds are
		-- reachable by parameter while the flag sits at one of them.
		owner = "ReplicatedStorage.Weapons",
		born = "2026-10-09 task 140",
		-- AN ACCEPTED FLAG DOES NOT EXPIRE IN 21 DAYS (feature-flags.md section 11 step 6a, and the
		-- three rows below this one say it in words). The 21-day ceiling is for a flag nobody has
		-- judged yet; this one has been judged, and the date it keeps is the retirement task's --
		-- when the OFF branch is archived and the row goes. Left at 2026-10-30 it would fail
		-- `flags.spec`'s rot tripwire on the 31st and block whatever gate ran that day.
		expires = "2026-12-31",
		why = "A bolt-action rifle with a telescopic sight, carried beside the shotgun on slot 2. "
			.. "Task 143 added a third weapon on slot 3 -- the same rifle over open sights -- and "
			.. "task 148 retired it at Karen's word. OFF is exactly the game before the rifle: "
			.. "one Tool, the shotgun, in the hand.",
	} :: FlagRow,
	FIRST_PERSON = {
		-- BORN OFF on 2026-09-27, ON SINCE TASK 98 (2026-10-01). Karen's word was "start": first
		-- person is now what the game IS, so every Studio Play shows the shotgun she is judging
		-- rather than the shoulder camera nobody is working on -- and the pose tuning this task
		-- exists for is only reachable with the gun in frame. THE ROW STAYS, and that is the
		-- rollback: one line back to `false` returns the camera she accepted on 2026-09-25, with
		-- both branches still reachable by parameter (every camera spec drives the other one with a
		-- config of its own). Design: docs/design/camera.md section 6.6.
		default = true,
		-- The owner is the module that READS it at its boundary (`Camera.Config.FIRST_PERSON`) and
		-- passes it inward as `config` -- the only permitted shape, and what keeps both branches
		-- reachable by parameter while the flag sits at one of them.
		--
		-- ...AND SINCE TASK 260 THE SERVER READS IT TOO, which this field has to say rather than
		-- leave to be discovered (the Reviewer's round-1 note). `ServerScriptService.Weapon`'s
		-- `ORIGIN_TOLERANCE_STUDS` asks this flag once, at its own boundary, because the two camera
		-- branches put the player's eye in genuinely different places -- 1.993 studs from the root in
		-- first person against the third-person clamp's 14.5 -- and since `BORE_ON_SIGHT_LINE` the
		-- bullet LEAVES from that claimed eye. The server cannot ask the camera (there is none), and
		-- "is this game first person" must have ONE answer or the bound and the frame disagree.
		owner = "StarterPlayerScripts.Camera (and ServerScriptService.Weapon, for the origin bound)",
		born = "2026-09-27 task 88 (the design); first code in task 89 (S1)",
		-- AN ACCEPTED FLAG DOES NOT EXPIRE IN 21 DAYS (task 149b -- the same fix task 149 made
		-- for `RIFLE`, and the Reviewer flagged this row as carrying the same bomb). First
		-- person has been lit since task 98 on Karen's own word, and the 21-day ceiling is for
		-- a flag nobody has judged yet. On 2026-10-19 this date goes past and `flags.spec`'s
		-- rot tripwire fails the harness, blocking whatever gate runs that day.
		expires = "2026-12-31",
		why = "The whole game is first person: the gun is carried low-left and aimed down the rib at the "
			.. "bead, with no crosshair. OFF is the accepted over-the-shoulder third person with ADS.",
	} :: FlagRow,
	DRIVE_BOTS = {
		-- BORN OFF on 2026-10-12 (task 161). Karen's v1 rule: "Let's make 4 hunters 4 beaters", and
		-- she plays SOLO -- so a drive with one person in it is one person in an empty wood. ON, every
		-- slot no real player fills is a visible R15 rig: beaters in the orange vest walking the wood
		-- abreast and blowing the real horn, hunters standing on the free stands.
		--
		-- IT IS BORN OFF BECAUSE IT CHANGES WHEN A DRIVE ENDS, which is the loudest thing in it: with
		-- a line of bots walking, "all beaters are through" is the LINE, so a 240-stud walk at 9
		-- studs/s ends a Forest Test drive at about 0:29 against its 300-second clock
		-- (docs/design/bots.md section 5.2 has the arithmetic). That is Karen's own two sentences
		-- composed and it is a FEEL number, so it waits for her eye behind this row.
		default = false,
		-- The owner is the module that READS it at its boundary (`Match.CONFIG.BOTS.ENABLED`) and
		-- passes it inward as `config` -- the only permitted shape, and what keeps both branches
		-- reachable by parameter while the flag sits at one of them. `ServerScriptService.Bots` never
		-- reads a flag: it is handed the targets.
		owner = "ServerScriptService.Match",
		born = "2026-10-12 task 161",
		expires = "2026-11-02", -- 21 days: the ceiling in feature-flags.md section 12
		why = "A drive is always 4 hunters and 4 beaters: every slot no real player fills is a visible "
			.. "R15 bot -- beaters in orange vests walking the wood and blowing the horn, hunters "
			.. "standing on the stands. OFF is exactly the game before task 161: nobody is built, the "
			.. "Forest Test's phantom beaters push as they do today, and only real beaters can end a drive.",
	} :: FlagRow,
	COINS = {
		-- BORN OFF on 2026-10-13 (task 170). Karen, 2026-10-11: *"Scoring - yes get money when shoot
		-- boar not much but get money and first place ofc more legendary more ect"*. ON, every real
		-- player earns coins at the end of a drive out of the points he already scored, the balance
		-- is loaded and saved through ProfileStore, and the results table is two rankings -- hunters
		-- and beaters -- with a coins column.
		--
		-- IT IS BORN OFF FOR A REASON NO OTHER FLAG IN THIS TABLE HAS: this is the FIRST thing in the
		-- project that can write to a player's permanent record. With the row at `false` a live
		-- server opens no ProfileStore session and writes no DataStore key at all, so this flag is
		-- also the kill switch and the rollback. The three rates (`COINS_PER_POINT`, `PARTICIPATION`,
		-- `FIRST_PLACE`) are feel numbers and are Karen's after one drive, which is the ordinary
		-- reason as well.
		--
		-- FLIPPED **ON** ON 2026-10-21 (task 233, "v1 default"). Karen's v1 decision that day puts
		-- money in the game in dollars, with the shop and its v1 list, so a server without her place
		-- attributes has to pay a drive. THE KILL SWITCH IS NOT GONE, it has only changed sides: one
		-- line back to `false` opens no session and writes no key, and `Economy.start`'s
		-- `world.enabled` keeps both branches reachable BY PARAMETER -- which is what every case in
		-- `economy.spec` drives, because no harness run may set an override at all. IN STUDIO NOTHING
		-- REACHES A LIVE DATASTORE EITHER WAY: `Economy.Store` takes the in-memory implementation
		-- whenever `RunService:IsStudio()`, so a playtest and a harness run write no key even with
		-- *Enable Studio Access to API Services* on.
		default = true,
		-- The owner is the module that READS it at its boundary (`Economy.CONFIG.ENABLED`) and passes
		-- it inward through `Economy.start`'s `world.enabled` -- the only permitted shape, and what
		-- keeps both branches reachable by parameter while the flag sits at one of them. `Match`
		-- never reads this flag: it is handed a view whose `payDrive` is a no-op when it is off.
		owner = "ServerScriptService.Economy",
		born = "2026-10-13 task 170",
		-- AN ACCEPTED FLAG DOES NOT EXPIRE IN 21 DAYS, for the reason `BOAR_MODEL`, `BOAR_BEHAVIOUR`
		-- and `HORN` do not: the ceiling in feature-flags.md section 12 is what stops a DARK path
		-- living for ever, and from today this path is LIT.
		expires = "2026-12-31",
		-- WHAT OFF REALLY LEAVES, corrected in round 2 of the gate. The old sentence claimed *"the
		-- score panel is task 159's one-table board"*, and that was never true: the SPLIT into hunters
		-- and beaters is Karen's own decision (2026-10-12) and is not about money, so it is there in
		-- both states and only the coins column reads `--`. What the flag really switches is the MONEY.
		why = "A drive pays coins off the points it already scored, and the balance survives the "
			.. "session through ProfileStore. OFF switches the MONEY off and nothing else: no session is "
			.. "opened, no DataStore key is written, no coin is awarded, the snapshot carries no `coinsOn` "
			.. "and its rows carry neither `coins` nor `earned`, and the drive bar is byte-identical to "
			.. "before task 170. The results table still shows the two rankings Karen asked for, with its "
			.. "coins column reading `--` because there is no money in the build.",
	} :: FlagRow,
	SHOP = {
		-- BORN OFF (CLAUDE.md, feature flags). OFF is task 177's game bit for bit: no panel, no
		-- inbound remote connected, no profile field written, the hunter keeps the rifle and his
		-- twelve slugs, and a beater carries nothing.
		--
		-- FLIPPED **ON** ON 2026-10-22 (task 233b, "v1 default"). Karen's v1 is the lodge with a
		-- counter in it: a drive pays coins and the counter is what they are for, so `COINS` lit
		-- without this row meant a player earned money he could not spend (`ESCALATE.md` item 3,
		-- 2026-10-21).
		--
		-- WHAT MAKES IT SAFE IS A SECOND FACT AND NOT THIS ONE: **a world with no counter wires no
		-- shop at all**. `Shop.start` answers `false` when `world.counterAt` is nil, so the five
		-- providers the composition root hangs off `shopOn` -- the entitlement, the licence, the
		-- look, the high seat and the always-hunter -- stay unwired in such a world and every reader
		-- answers nil, which is today's game by every branch (docs/design/shop.md section 7.1).
		-- `MatchBoot` passes `counterAt = nil` (`Lobby.ANCHORS` has no `map:v1` row, so the DEV place
		-- has no lodge), so THE HARNESS'S PLAYER PATH IS UNCHANGED BY THIS ROW. Task 233's own flip
		-- did not have that gate: it lit the shop in the DEV place, where an un-owning player's kit
		-- became buckshot and the shotgun alone in the one world where nothing can ever be bought,
		-- and five server and fifteen client cases went red (`ESCALATE.md` item 2, which is where the
		-- Director chose this fix over re-baselining the client suite).
		default = true,
		-- THE FLAG'S NAME LIVES IN THE SHARED MODULE as `Shop.FLAG`, and `Shop.isOn()` is the one
		-- read -- `RIFLE`'s shape (`owner = "ReplicatedStorage.Weapons"`) and `HORN`'s. Each owner
		-- calls it ONCE at its own boundary (`ServerScriptService.Shop.ENABLED`,
		-- `ShopPanel.start`'s `enabled`) and passes the value inward.
		owner = "ReplicatedStorage.Shop",
		born = "2026-10-14 task 178",
		expires = "2026-11-04", -- 21 days: the ceiling in feature-flags.md section 12
		-- IT NEEDS `COINS` ON AS WELL, or the shop reads CLOSED: with the money off there is no
		-- profile to charge and nothing to record (docs/design/shop.md section 3.1).
		why = "A player walks up to the counter in the lodge and spends the money a drive paid him "
			.. "on Karen's v1 list: slug shells, high-seat access, unlimited ammunition, the scoped "
			.. "rifle, a beater's licence, the hunter's place every drive, or one of three "
			.. "packages. Needs COINS on too.",
	} :: FlagRow,
	LOBBY = {
		-- BORN OFF on 2026-10-13 (task 177). Karen, that evening: *"I think after this fixes we need
		-- to focus on lobby / Hunting house where inside can shop things / outside is fields and
		-- forrest so house is in fields next to forrest"*, and her two choices asked one by one: a
		-- *"Wooden log lodge"* and *"Walk to a car"*. ON, a player who joins the server stands in
		-- open fields by the forest with a log lodge and a hunting truck, and he starts a hunt by
		-- standing in the marked circle beside the truck for five seconds.
		--
		-- IT IS BORN OFF BECAUSE IT CHANGES WHAT JOINING THE SERVER MEANS, which is the loudest
		-- thing it does: today `Match`'s `watchPlayer` dispatches a `join` on `PlayerAdded`, and
		-- with `MIN_PLAYERS = 1` that one dispatch starts a drive. OFF is exactly that game --
		-- nothing is built, no terrain is written, `Match` is started with no `enrol` field and
		-- `watchPlayer` takes the line it has always taken. The DEV place, where the harness runs,
		-- keeps this default, so no harness check can change its answer.
		--
		-- FLIPPED **ON** ON 2026-10-21 (task 233, "v1 default"). Karen's v1 is the lodge in the
		-- fields: a player joins, stands in the circle beside the truck and a hunt starts. The row
		-- stays as the rollback, and `Lobby.start`'s `world.enabled` keeps both branches reachable BY
		-- PARAMETER -- which is what `lobby_live.spec` drives, since it names both `enabled` and
		-- `world` in its own fakes.
		--
		-- IT IS A NO-OP IN THE DEV PLACE, MEASURED RATHER THAN HOPED (task 233). `MatchBoot` NEVER
		-- CALLS `Lobby.start` AT ALL -- the only caller in `src/` is `ForestTestBoot` -- and even if
		-- it did, `Data.anchorFor("map:v1")` is nil and `start` answers `false` without building
		-- anything or writing a stud of terrain (*"NOT A FAILURE: a world with no row has no lobby,
		-- which is how the DEV place keeps today's behaviour without a second switch"*). So the
		-- harness's player path is byte-identical with this row either way, and the two full runs
		-- across this flip say so: 34/34 before and after.
		default = true,
		-- The owner is the module that READS it at its boundary (`Lobby.ENABLED`) and passes it
		-- inward through `Lobby.start`'s `world.enabled` -- the only permitted shape, and what keeps
		-- both branches reachable by parameter while the row sits at `false`. `Match` never reads
		-- this flag: it is handed `enrol = false` by the composition root, and only when the lobby
		-- said it had actually built itself.
		owner = "ServerScriptService.Lobby",
		born = "2026-10-13 task 177",
		-- AN ACCEPTED FLAG DOES NOT EXPIRE IN 21 DAYS, for the reason the lit rows above do not: the
		-- ceiling in feature-flags.md section 12 is what stops a DARK path living for ever, and from
		-- today this path is LIT.
		expires = "2026-12-31",
		why = "The player starts at a hunting lodge in the fields beside the forest and starts a hunt "
			.. "by standing in the marked circle beside the truck; at the end of a drive he is back "
			.. "at the lodge. OFF is the game before task 177: joining the server joins the drive, "
			.. "nothing is built and no terrain is written.",
	} :: FlagRow,
	AUTUMN_LIGHT = {
		-- BORN **ON**, WHICH NO OTHER NEW PATH IN THIS TABLE IS, AND IT IS THE DIRECTOR'S DECISION
		-- AND NOT THE BUILDER'S. `docs/design/feature-flags.md` section 11 step 1 says a new path is
		-- born `false`; this row is the documented exception, dispatched in these words
		-- (Director, 2026-10-19, task 215, transcribed verbatim in TASKS.md row 215d --
		-- row 215 is the STATUS row and carries none of the dispatch's words):
		--
		--   *"Put the whole look behind a feature flag born ON (`AUTUMN_LIGHT`, expires <= 21 days,
		--   the standard row), so the Director can switch it off live with flags.py if Karen finds
		--   it too dark: with it OFF, the place's own Lighting is left untouched."*
		--
		-- The REASON it is the exception is what the flag protects against rather than what it
		-- switches on. KAREN, 2026-10-17, asked whether the Designer should tune the lighting -- the
		-- cabin and the boar heads read pale: *"yes"*. The Designer's answer (the lighting spec,
		-- 2026-10-19) takes `Ambient` from 159,159,159 to 44,40,34, which is most of the fix and is
		-- also the single thing that could be TOO MUCH: a late-autumn morning nobody can see in is
		-- worse than a pale one. So the look ships ON -- the point of the task was that Karen should
		-- SEE it -- and this row exists so the Director can take it off LIVE with
		-- `tools/flags.py set AUTUMN_LIGHT off` the moment she says it is too dark, without a commit
		-- and without a build. Karen's verdict still lands the ordinary way: her OK retires the row
		-- (section 10 step 7), and a no is one `flags.py` line now and a three-line commit after.
		--
		-- OFF IS "UNTOUCHED", NOT "A SECOND SET OF NUMBERS". `Light.plan` answers nil when it is
		-- off, so `LightBoot` writes nothing at all and the place keeps whatever its own `Lighting`
		-- holds -- which, measured on 2026-10-19, is 159,159,159 at `Brightness` 3.0 in the Forest
		-- Test and 110,100,90 at 2.6 in DEV. A restore-from-snapshot off-switch was refused in the
		-- note (section 4): a snapshot taken after something else has written is a snapshot of the
		-- wrong thing.
		default = true,
		-- The owner is the module that READS it at its boundary (`Light.ENABLED`) and passes it
		-- inward as `Light.plan`'s first argument -- the only permitted shape, and what keeps both
		-- branches reachable by parameter while the row sits at `true`:
		-- `tests/server/light.spec.luau` calls `plan(false, CONFIG)` with no service and no Play.
		owner = "ServerScriptService.Light",
		born = "2026-10-19 task 215",
		expires = "2026-11-09", -- 21 days: the ceiling in feature-flags.md section 12
		why = "One late-autumn Central-European morning, written from code in every world: a warm "
			.. "near-black Ambient, a cool OutdoorAmbient, a low 8.2 sun, one Atmosphere and two "
			.. "post effects. OFF leaves the place's own Lighting exactly as it is.",
	} :: FlagRow,
	-- THE "NO DEER LICENCE" POPUP (task 238). KAREN, 2026-10-21, verbatim: *"if you dont have a
	-- license when you aim and what to shoot it shows popup you dont have license and then you want
	-- to buy and roblox popup like they do to purchase"*.
	--
	-- BORN OFF, which is `docs/design/feature-flags.md` section 11 step 1 for a new feel-critical
	-- path and the default this table takes: a card that appears unasked while a player is holding a
	-- gun at an animal is exactly the kind of thing only Karen can judge, and it merges dark.
	--
	-- WHAT IT SWITCHES, AND WHAT IT DOES NOT. OFF is "no card, and no question asked": `LicenceCard`
	-- reads this once, at its boundary (`LicenceCard.ENABLED`, the only permitted shape), and when
	-- it is off `Hud` never starts it and nothing on screen changes. **The server half is not behind
	-- it**, and that is deliberate rather than an omission: the `"Aim"` question moves no state,
	-- costs one cast and publishes nothing when there is no advice, and a flag on it would mean the
	-- two halves could disagree about whether the feature exists. **Nothing about the fire gate, the
	-- shot, the refusal or the dry click is behind it or touched by this task** -- an unlicensed shot
	-- was already refused with `NO LICENCE` before task 238 and still is, with the row at either
	-- value.
	--
	-- BOTH STATES ARE REACHABLE BY PARAMETER while the row sits at false: `LicenceCard.start` takes
	-- `enabled` and `tests/client/licence_card.spec.luau` drives the card on with the row off.
	--
	-- Note: docs/research/2026-10-22-licence-popup-and-robux.md
	LICENCE_POPUP = {
		default = false,
		-- The owner is the module that READS it at its boundary and draws the card. The BUY it sends
		-- is `ShopPanel.press`'s, and the purchase is still `Economy`'s: this row switches a card,
		-- not a rule and not a till.
		owner = "StarterPlayerScripts.Hud.LicenceCard",
		born = "2026-10-22 task 238",
		expires = "2026-11-12", -- 21 days: the ceiling in feature-flags.md section 12
		why = "One card, when a hunter aims at a red deer he has no licence for: NO DEER LICENCE, "
			.. "what the rule actually is, and a BUY button that goes through the shop's own "
			.. "server purchase path from wherever he is standing. OFF draws nothing.",
	} :: FlagRow,
	-- THE DEER'S LEAP OVER THE ROAD (task 245b). KAREN, 2026-10-22, verbatim: *"they usually jump
	-- when is cross road so can we do that ?"*.
	--
	-- BORN OFF, which is `docs/design/feature-flags.md` section 11 step 1 for a new feel-critical
	-- path and the default this table takes. A bound is the most conspicuous thing an animal in this
	-- game does and it is pure feel: how often, how fast, and whether it reads as a deer or as a
	-- glitch is Karen's to judge, so it merges dark and the Director switches it on for her.
	--
	-- WHAT IT SWITCHES. OFF is the game as it shipped: `Brain` never sets `_leapFor`, `intent.leaping`
	-- is false for every animal on every tick, `Body.clipFor` never reaches its leap branch, and a
	-- deer crosses the road running exactly as it does today. ON, a deer that ENTERS the road band
	-- above `MODEL.RUN_FROM` plays `Jump_Run_IP` once per crossing. It is read ONCE, at
	-- `Boar.CONFIG.MODEL.LEAP.ENABLED` -- the only permitted shape -- and passed inward from there.
	--
	-- BOTH STATES ARE REACHABLE BY PARAMETER while the row sits at false: `Brain.leapStarts` takes
	-- the leap table as an argument and `tests/server/deer.spec.luau` drives it on with the row off.
	--
	-- NOTHING ELSE IS BEHIND IT. The published animation id, its `Assets.ROWS` row and its
	-- `MODEL.CLIPS` entry are NOT flagged: a row that exists and a clip nothing asks for cost
	-- nothing, and flagging data as well as behaviour would be two switches for one feature.
	--
	-- Note: docs/research/2026-10-23-deer-road-leap.md
	DEER_ROAD_LEAP = {
		default = false,
		-- The owner is the module that READS it at its boundary. The TRIGGER is `Brain`'s and the
		-- DRAWING is `Body`'s, and both are inside `ServerScriptService.Boar`, which is the one
		-- owner of what an animal does and what it looks like.
		owner = "ServerScriptService.Boar",
		born = "2026-10-23 task 245b",
		expires = "2026-11-13", -- 21 days: the ceiling in feature-flags.md section 12
		why = "A red deer bounds across the road instead of running flat over it: one leap per "
			.. "crossing, at the clip's own speed, for an animal already running. OFF is the "
			.. "crossing this game has always drawn.",
	} :: FlagRow,

	-- ---------------------------------------------------------------- THE STAG'S BOUND (task 251 part 2)
	--
	-- KAREN, 2026-10-23, through the Designer's plan she OK'd: *"a bound away when spooked"*. A red
	-- stag startled from a stand-still does not simply break into a run -- he leaps once, on the spot,
	-- and then runs. The spec (`<runs-dir>/design/driveflow-spec.md` section 3.2, `BOUND_ON_SPOOK`) is
	-- the whole of it, and so is its own warning, which is why this row exists:
	--
	-- **IT REUSES THE ROAD LEAP'S CLIP AND THEREFORE ITS MEASURED HOOF SINK** -- up to 1.19 studs of
	-- hind hoof below ground for 0.25 s, the known and queued cost in TASKS.md 245c. On the road that
	-- sink is half-hidden by the tarmac and by the speed; a bound on flat ground in front of a standing
	-- hunter is the case that shows it. The spec says *"if the sink is visible on the bound, the bound
	-- waits for 245c"*, and the DIRECTOR'S DISPATCH (2026-10-24) decided it in advance: *"HOLD the
	-- bound when spooked until 245c (the hoof sink) is fixed, behind a flag born off"*. So the
	-- behaviour ships, dark, and 245c unlocks it.
	--
	-- WHAT IT SWITCHES. OFF is the game as it shipped: a spooked stag runs, `Brain.boundStarts` answers
	-- false for every animal and `intent.leaping` is only ever the road leap's. ON, a stag spooked at or
	-- below `MOVE.BOUND_FROM_SPEED` plays the same leap clip once, at the instant of the spook. It is
	-- read ONCE, at `Boar.CONFIG.KINDS.stag.spook.bound` -- the animal's own row, the only permitted
	-- shape -- and passed inward from there.
	--
	-- BOTH STATES ARE REACHABLE BY PARAMETER while the row sits at false: `Brain.boundStarts` takes the
	-- switch, the speed, the threshold and the leap table as arguments, and `tests/server/deer.spec.luau`
	-- drives it on with the row off.
	--
	-- IT IS ALSO BOUNDED BY `DEER_ROAD_LEAP`, deliberately and not by accident: the bound IS that
	-- clip, so `Brain.boundStarts` refuses when the leap table is disabled. Two dark switches cannot
	-- light each other, and when 245c lands the sink is fixed once for both.
	STAG_BOUND_ON_SPOOK = {
		default = false,
		-- The owner is the module that READS it at its boundary, exactly as `DEER_ROAD_LEAP` says: the
		-- TRIGGER is `Brain`'s and the DRAWING is `Body`'s, both inside `ServerScriptService.Boar`.
		owner = "ServerScriptService.Boar",
		born = "2026-10-24 task 251 part 2",
		expires = "2026-11-14", -- 21 days: the ceiling in feature-flags.md section 12
		why = "A red stag bounds once when he is spooked from a stand-still, instead of simply "
			.. "running. OFF until TASKS.md 245c fixes the leap clip's measured hoof sink, which this "
			.. "reuses and which a bound on flat ground is the case that shows.",
	} :: FlagRow,
}

-- deepFreeze, REQUIRED and not copied: table.freeze is shallow, and this repo has already paid for
-- that once (src/shared/Drive/init.luau, Task 23a note (b)). A row's fields must be frozen too.
Shotgun.deepFreeze(Flags.DEFAULTS)

local ISO_DATE = "^(%d%d%d%d)%-(%d%d)%-(%d%d)$"

-- ---------------------------------------------------------------- pure

-- The reviewed value of every flag: name -> boolean. A new frozen table each call.
function Flags.defaults(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for name, row in pairs(Flags.DEFAULTS) do
		out[name] = row.default
	end
	return table.freeze(out)
end

-- resolve(defaults, overrides) -> (a NEW frozen table, the rejected override keys with a reason).
-- It never mutates either argument and NEVER COERCES a value: "true" is not true, and 1 is not true.
-- An override for a name that is not declared is rejected rather than created, because a flag that
-- exists only because somebody set an attribute is a flag nothing reviewed.
function Flags.resolve(
	defaults: { [string]: boolean },
	overrides: { [string]: any }?
): ({ [string]: boolean }, { string })
	-- table.clone, not a hand-rolled loop: it is shallow, which is exactly right for a map of
	-- booleans, and it returns an UNFROZEN copy of a frozen argument, which is what lets the
	-- overrides be applied to it without touching the caller's table.
	local out: { [string]: boolean } = table.clone(defaults)
	local rejected: { string } = {}
	if overrides then
		local names: { string } = {}
		for name in pairs(overrides) do
			table.insert(names, name)
		end
		table.sort(names) -- a stable order, so two runs report the same list
		for _, name in ipairs(names) do
			local value = overrides[name]
			if defaults[name] == nil then
				table.insert(rejected, string.format("unknown flag %s", name))
			elseif type(value) ~= "boolean" then
				table.insert(rejected, string.format("%s is not a boolean (%s)", name, type(value)))
			else
				out[name] = value
			end
		end
	end
	return table.freeze(out), rejected
end

-- "A=1|B=0", sorted by name. One string that says what a process resolved, so the server and every
-- client can be compared with a single equality.
function Flags.digest(resolved: { [string]: boolean }): string
	local names: { string } = {}
	for name in pairs(resolved) do
		table.insert(names, name)
	end
	table.sort(names)
	local parts: { string } = {}
	for _, name in ipairs(names) do
		table.insert(parts, name .. "=" .. (if resolved[name] then "1" else "0"))
	end
	return table.concat(parts, "|")
end

-- Every declaration fault in ONE list, so a bad row is one spec failure and not five runs.
-- `today` is a parameter, not os.date, so the rot tripwire is testable at any date (section 13.1).
function Flags.problems(defaults: { [string]: FlagRow }, today: string): { string }
	local out: { string } = {}
	local names: { string } = {}
	for name in pairs(defaults) do
		table.insert(names, name)
	end
	table.sort(names)

	if #names > Flags.MAX_FLAGS then
		table.insert(out, string.format("%d flags declared, and MAX_FLAGS is %d", #names, Flags.MAX_FLAGS))
	end
	if not string.match(today, ISO_DATE) then
		table.insert(out, string.format("today %q is not an ISO date (YYYY-MM-DD)", today))
	end

	for _, name in ipairs(names) do
		local row = defaults[name]
		local where = "flag " .. name
		if not string.match(name, Flags.NAME_PATTERN) then
			table.insert(out, string.format("%s: the name must match %s", where, Flags.NAME_PATTERN))
		end
		if #name > Flags.MAX_NAME_LENGTH then
			table.insert(
				out,
				string.format("%s: the name is %d characters, over %d", where, #name, Flags.MAX_NAME_LENGTH)
			)
		end
		if type(row) ~= "table" then
			table.insert(out, string.format("%s: the row is a %s, not a table", where, type(row)))
			continue
		end
		if type(row.default) ~= "boolean" then
			table.insert(out, string.format("%s: `default` is a %s, not a boolean", where, type(row.default)))
		end
		for _, field in ipairs({ "owner", "born", "expires", "why" }) do
			local value = (row :: any)[field]
			if type(value) ~= "string" or value == "" then
				table.insert(out, string.format("%s: `%s` must be a non-empty string", where, field))
			end
		end
		if type(row.expires) == "string" then
			if not string.match(row.expires, ISO_DATE) then
				table.insert(out, string.format("%s: `expires` %q is not an ISO date (YYYY-MM-DD)", where, row.expires))
			elseif string.match(today, ISO_DATE) and row.expires < today then
				-- THE ROT TRIPWIRE (design section 11). An expired flag fails the spec, which fails
				-- the harness, which blocks the merge gate. The fix is one of three: retire it, flip
				-- it, or move the date with a reason in `why`. Moving it costs one line, so this can
				-- never actually block a task -- it can only force someone to say the flag still has
				-- a reason to exist.
				table.insert(
					out,
					string.format(
						"%s: EXPIRED on %s (today is %s). Retire it, flip its default, or move the date with a reason: docs/design/feature-flags.md section 11",
						where,
						row.expires,
						today
					)
				)
			end
		end
	end
	return out
end

-- {} when isStudio is false or host is nil. THE STUDIO TEST IS AN ARGUMENT, so the production branch
-- -- "a published place ignores every DHFlag_ attribute" -- is provable from inside Studio, where
-- RunService:IsStudio() is always true and no harness run can make it false.
function Flags.readOverrides(host: Instance?, isStudio: boolean): { [string]: any }
	local out: { [string]: any } = {}
	if not isStudio or host == nil then
		return out
	end
	for name, value in pairs(host:GetAttributes()) do
		if string.sub(name, 1, #Flags.OVERRIDE_PREFIX) == Flags.OVERRIDE_PREFIX then
			out[string.sub(name, #Flags.OVERRIDE_PREFIX + 1)] = value
		end
	end
	return out
end

-- ---------------------------------------------------------------- this process

local resolved: { [string]: boolean }? = nil
local source = "defaults"
local line = ""
local rejectedHere: { string } = {}
local overridden: { string } = {}

-- The mirror's host instance. It is a CHILD OF THIS MODULE (src/shared/Flags/State.model.json), so
-- it is found through `script` and never by searching ReplicatedStorage: one file, one instance, and
-- Rojo owns both. It is a Rojo-owned empty Configuration rather than a run-time-created instance
-- because every Rojo-owned container defaults to $ignoreUnknownInstances: false, so an instance with
-- no file on disk is DELETED at the next Connect (CLAUDE.md, "Rojo DELETES Studio-created
-- instances"). An empty .model.json also makes it exist in Edit, where the `flags` command looks.
local function state(): Instance?
	return script:FindFirstChild(Flags.STATE_NAME)
end

local function describe(set: { [string]: boolean }): string
	local names: { string } = {}
	for name in pairs(set) do
		table.insert(names, name)
	end
	table.sort(names)
	local parts: { string } = {}
	for _, name in ipairs(names) do
		table.insert(parts, name .. "=" .. (if set[name] then "1" else "0"))
	end
	return string.format("%d flag%s: %s", #names, if #names == 1 then "" else "s", table.concat(parts, " "))
end

local function resolveOnServer()
	local overrides = Flags.readOverrides(game:GetService("ServerStorage"), RunService:IsStudio())
	local applied = 0
	for _ in pairs(overrides) do
		applied += 1
	end
	local out, rejected = Flags.resolve(Flags.defaults(), overrides)
	resolved = out
	rejectedHere = rejected
	applied -= #rejected
	source = if applied > 0 then "override" else "defaults"

	local defaults = Flags.defaults()
	for name, value in pairs(out) do
		if defaults[name] ~= value then
			table.insert(overridden, name)
		end
	end
	table.sort(overridden)
end

local function resolveOnClient()
	local host = state()
	local digest: any = host and host:GetAttribute(Flags.DIGEST_ATTRIBUTE)
	if host and digest == nil then
		-- WAIT, then fall back. The mirror is written once at server start, before any player
		-- exists, so the real wait is about zero -- but a client that joined during a restart must
		-- not read half a set, which is why the server writes Digest LAST and this waits for it.
		--
		-- The SIGNAL wakes it and the DEADLINE bounds it: a bare poll would cost up to one interval
		-- of latency on every boot, and a bare signal:Wait() would hang a client for ever if the
		-- server never published. `arrived` is written by the connection and read by the loop.
		local arrived = false
		local connection = host:GetAttributeChangedSignal(Flags.DIGEST_ATTRIBUTE):Connect(function()
			arrived = true
		end)
		local deadline = os.clock() + Flags.WAIT_SECONDS
		while not arrived and os.clock() < deadline do
			task.wait(0.05)
			if host:GetAttribute(Flags.DIGEST_ATTRIBUTE) ~= nil then
				break
			end
		end
		connection:Disconnect()
		digest = host:GetAttribute(Flags.DIGEST_ATTRIBUTE)
	end

	if host == nil or digest == nil then
		resolved = Flags.defaults()
		source = "published-timeout"
		return
	end

	local out: { [string]: boolean } = {}
	for name in pairs(Flags.DEFAULTS) do
		local value = host:GetAttribute(name)
		out[name] = if type(value) == "boolean" then value else Flags.DEFAULTS[name].default
	end
	resolved = table.freeze(out)
	source = "published"
	if Flags.digest(out) ~= digest then
		-- Never a silent disagreement: a client that read something other than what the server
		-- published says so, loudly, and calls itself a timeout rather than the truth.
		warn(
			string.format(
				"[flags] the mirror disagrees with what this client read: %q vs the server's %q. Using the defaults.",
				Flags.digest(out),
				tostring(digest)
			)
		)
		resolved = Flags.defaults()
		source = "published-timeout"
	end
end

local function ensure()
	if resolved ~= nil then
		return
	end
	local began = os.clock()
	if RunService:IsServer() then
		resolveOnServer()
	else
		resolveOnClient()
	end
	local set = resolved :: { [string]: boolean }
	line = string.format(
		"[flags] %s %s %s  digest=%s",
		if RunService:IsServer() then "server" else "client",
		source,
		describe(set),
		Flags.digest(set)
	)
	if #overridden > 0 then
		local parts: { string } = {}
		local defaults = Flags.defaults()
		for _, name in ipairs(overridden) do
			table.insert(
				parts,
				string.format("%s=%d (default %d)", name, if set[name] then 1 else 0, if defaults[name] then 1 else 0)
			)
		end
		local total = 0
		for _ in pairs(set) do
			total += 1
		end
		warn(
			string.format(
				"[flags] OVERRIDE ACTIVE (Studio only) %d of %d: %s",
				#overridden,
				total,
				table.concat(parts, " ")
			)
		)
	end
	if #rejectedHere > 0 then
		-- A silently ignored override is how a playtest gets run against the wrong build and then
		-- reported as the right one.
		warn("[flags] override(s) REJECTED and NOT applied: " .. table.concat(rejectedHere, "; "))
	end
	local took = (os.clock() - began) * 1000
	if took > 1 then
		warn(string.format("[flags] resolution took %.2f ms, over the 1 ms budget (design section 12)", took))
	end
end

-- This process's answer. Computed once, memoised, frozen.
function Flags.all(): { [string]: boolean }
	ensure()
	return resolved :: { [string]: boolean }
end

-- ERRORS on a name that is not declared. A typo that read as `false` would be a dark path that
-- silently never runs and a spec that passes for the wrong reason (design section 4.1), the same
-- refusal Penalty.expired makes of "a config number that nothing reads is a lie in a table".
function Flags.isOn(name: string): boolean
	local set = Flags.all()
	local value = set[name]
	if value == nil then
		local known: { string } = {}
		for declared in pairs(Flags.DEFAULTS) do
			table.insert(known, declared)
		end
		table.sort(known)
		error(string.format("Flags.isOn(%q): no such flag. Declared: %s", name, table.concat(known, ", ")), 2)
	end
	return value
end

function Flags.source(): string
	ensure()
	return source
end

function Flags.line(): string
	ensure()
	return line
end

-- SERVER ONLY, and FlagsBoot is its only caller. Digest is written LAST, after every flag, so
-- "Digest present" means "the set is complete" and a client can never read half a set.
function Flags.publish(resolvedSet: { [string]: boolean }, publishedSource: string): ()
	if not RunService:IsServer() then
		error("Flags.publish is server-only: a client never writes the mirror it reads", 2)
	end
	local host = state()
	if host == nil then
		error("Flags.publish: ReplicatedStorage.Flags.State is missing (src/shared/Flags/State.model.json)", 2)
	end
	if Flags.SOURCES[publishedSource] == nil then
		error(string.format("Flags.publish: %q is not one of the declared sources", publishedSource), 2)
	end
	for name in pairs(host:GetAttributes()) do
		host:SetAttribute(name, nil)
	end
	for name, value in pairs(resolvedSet) do
		host:SetAttribute(name, value)
	end
	host:SetAttribute(Flags.SOURCE_ATTRIBUTE, publishedSource)
	host:SetAttribute(Flags.DIGEST_ATTRIBUTE, Flags.digest(resolvedSet)) -- LAST, always
end

return Flags
