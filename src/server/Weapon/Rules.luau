--!strict
-- Weapon.Rules: MAY THIS SHOT BE TAKEN AT ALL? Pure -- no service, no Instance, no clock, no
-- `Player`, no `Random`; every fact is a parameter. The owner (`Weapon.onFireRequest`) asks these
-- questions in its own order and is the only thing that writes.
--
-- FOUR RULES OF ONE SHAPE (three in task 171, the fourth in 174): the trigger does nothing and NOTHING IS TAKEN AWAY.
-- Karen, 2026-10-11, about beaters: *"No penalty now we need simplify scope, thye just can't shoot
-- them"*; 2026-10-12, about a hunter who is not in his stand circle: he *"CAN'T SHOOT until he steps
-- in"*, with no punishment; 2026-10-10, about a red deer with no licence: *"they can aim but no
-- shooting happening"*. Every rule this drive had before today -- the safety arc and the tie
-- (`Match.Penalty`), the piglet's -10 (`Match.CONFIG.POINTS.KIND.cub`) -- lets the shot HAPPEN and
-- then charges for it.
--
-- HOW THIS RELATES TO `Match.Penalty`, WHICH STAYS AND IS NOT DOUBLE HANDLING. Two different
-- questions about two different shots:
--   * `Rules.beaterInLine` -- "the aim ray would hit a beater": the shot is REFUSED, before it
--     exists. No shell, no flash, no pellet, no penalty.
--   * `Match.Penalty.judge` -- "a shot that WAS fired passed within `SAFETY_MISS_STUDS` of a
--     beater": the tie to a tree. Reached only by a shot that got past the gate, which by
--     construction is one that was not aimed at anybody.
-- A shot cannot be both, because a refused shot never fires `Weapon.SafetyViolated` at all -- the
-- owner returns before it.
--
-- SO THE BOUNDARY BETWEEN THE TWO IS HIS BODY, and it was MEASURED rather than reasoned about: the
-- Director's two-player run at `5e0ee90` staged a driver 25 studs out and DEAD ON the shot line
-- (`miss 0.0 of 12`, `zz_tie_to_a_tree.spec`'s own note), the new rule refused that shot, and
-- nothing was tied -- the tie proof had been staging a refusal all along. The two rules in one
-- sentence each, which is what the game does now:
--   * the aim ray WOULD HIT HIM -> refused. No fire, no shell, no tie, no punishment.
--   * the aim ray MISSES HIM but the shot passes within `Match.CONFIG.SAFETY_MISS_STUDS` (12) of him
--     inside the arc -> FIRED, and he is tied to a tree. That is what the arc is for.
-- `zz_tie_to_a_tree.spec` stages both: the probe aimed at him (refused, ties nobody) and the real
-- replayed click aimed `BESIDE_STUDS` = 5 studs off his body (fired, ties the shooter).
--
-- THE THREE ARE ASKED IN ONE DECLARED ORDER -- `Rules.ORDER`, off-stand first -- and that too was
-- forced by a measurement rather than chosen on paper: in the Director's run at `8b2bb40` the probe
-- aimed straight at a beater answered `off-stand`, because the shooter had walked 525 studs from his
-- post to reach him. Both answers were correct; nothing said which should win. See `Rules.ORDER`.
--
-- THE EDGE IS SHARP AND THAT IS DELIBERATE: a man who aims AT a beater is stopped and not punished
-- (Karen: *"No penalty now"*), and a man who aims a yard past him is punished. Softening it would
-- mean punishing the refused shot, which is the thing she asked not to happen, or refusing the near
-- miss, which would retire the safety rule she asked for in the first place.
--
-- Pattern: one pure predicate per question, over an injected provider per fact -- Luanti's
-- `core.is_protected` ("Mods should use core.is_protected when testing whether a player owns a
-- specific position, and protection mods simply override this function"), committed only after
-- every question has answered, which is OpenTTD's `CommandCost` test-then-execute. ioquake3's
-- `g_friendlyFire` -- the check inside `G_Damage`, after the rocket has flown -- is quoted in the
-- note as the pattern this REFUSES.
--   https://api.luanti.org/core-namespace-reference/   (Luanti, LGPL-2.1+)
--   https://github.com/OpenTTD/OpenTTD                 (src/command_type.h, GPL-2.0)
--   https://github.com/ioquake/ioq3                    (code/game/g_combat.c, GPL-2.0)
--
-- ONE QUESTION PER FUNCTION, and `Match.Penalty`'s own header says why: *"four questions in one
-- predicate is how 'one predicate answered two unrelated questions' happened in the previous
-- project"* (docs/PROJECT_CONTEXT.md).
--
-- Note: docs/research/2026-10-13-the-rules.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Licences = require(ReplicatedStorage:WaitForChild("Licences"))

local Rules = {}

-- WHAT THE AIM RAY HIT, as the target's own owner describes it. The weapon knows neither what a
-- beater is nor what a boar is: it reads one table from `Weapon.setTargetProvider`.
export type Target = {
	beater: boolean?, -- this is a man walking the drive (a player on the push team, or a bot)
	species: string?, -- `Licences.SPECIES_ATTRIBUTE` off the thing that was hit
}

-- WHERE A HUNTER MAY STAND AND STILL SHOOT: task 166's circle, as data. nil from the provider means
-- "this player has no stand", which is a beater, a player between drives, and a hunter whose pick
-- has not locked -- none of whom is OUTSIDE anything.
export type StandArea = {
	centre: Vector3,
	radius: number,
}

-- The closed set, so the owner, the client and the specs can name them. They are wire values: the
-- snapshot carries one in `refused` and the Hud prints `NOTICE[reason]`.
Rules.REASON = table.freeze({
	BEATER = "beater-in-line",
	OFF_STAND = "off-stand",
	LICENCE = "no-licence",
	-- THE DRIVE IS NOT ON (task 174). KAREN, 2026-10-13 ~09:35: *"for hunter once hunt over (drive)
	-- horn anounce then I can; shoot anymore"*.
	DRIVE_OVER = "drive-over",
})

-- ONE SHORT LINE EACH, in the Hud's own voice ("NO BUCK" is the line this sits beside). Short
-- because the readout is one row at the bottom of the screen and Karen's rule is a clear screen.
Rules.NOTICE = table.freeze({
	[Rules.REASON.BEATER] = "NOT AT A BEATER",
	[Rules.REASON.OFF_STAND] = "NOT IN YOUR STAND",
	[Rules.REASON.LICENCE] = "NO LICENCE",
	[Rules.REASON.DRIVE_OVER] = "THE DRIVE IS OVER",
})

function Rules.noticeFor(reason: string?): string?
	if type(reason) ~= "string" then
		return nil
	end
	return Rules.NOTICE[reason]
end

-- RULE 1. WOULD THIS SHOT HIT A BEATER? The aim ray's own target, which is the ray the pellets are
-- aimed down -- never the camera direction, the same rule `SafetyArc` states for the same reason:
-- what is refused must be what would have been shot.
--
-- IT IS THE AIM RAY AND NOT THE PELLET PATTERN, and that is a decision rather than a shortcut.
-- Buckshot throws nine pellets over ~1.6 degrees; asking "would ANY pellet hit a beater" would need
-- the pattern cast before the shot is allowed to exist, and at 100 studs that cone is wide enough
-- that a beater standing near a boar would block a legitimate shot at the boar. The aim ray is
-- where the player is pointing the gun, which is the thing Karen's rule is about.
function Rules.beaterInLine(target: Target?): boolean
	return target ~= nil and target.beater == true
end

-- RULE 2. IS HE OUTSIDE HIS STAND? FLAT -- the Y is ignored, because a hunter standing on his post
-- is a stud or three above the ground he picked it from and that is not leaving the stand
-- (`ForestTest.withinStand`'s rule, and this is the same comparison so the two can never disagree
-- about what "in your stand" means).
--
-- NO AREA MEANS NO RULE. A beater has no stand, a player between drives has no stand, and a hunter
-- whose 15 s pick has not locked has no stand yet -- none of them is outside one.
function Rules.outsideStand(position: Vector3?, area: StandArea?): boolean
	if area == nil or position == nil then
		return false
	end
	if typeof(area.centre) ~= "Vector3" or type(area.radius) ~= "number" or area.radius <= 0 then
		-- A circle with no centre or no radius is not a boundary. Refusing every shot on one would
		-- make a mis-wired provider look exactly like Karen's rule working, which is the kind of
		-- silent failure this repo measures rather than assumes -- and THE CENTRE IS CHECKED FOR THE
		-- STRONGER REASON (the Reviewer's round-1 note): `Rules.refuse` is called straight from
		-- `onFireRequest` and only the PROVIDER is pcall-ed, so an area of `{ radius = 12 }` would
		-- throw inside the fire handler and nobody could shoot at all.
		return false
	end
	local flat = Vector3.new(position.X - area.centre.X, 0, position.Z - area.centre.Z)
	return flat.Magnitude > area.radius
end

-- RULE 4. IS THE DRIVE OVER -- OR NOT YET BEGUN? (task 174.) KAREN, 2026-10-13 ~09:35: *"for hunter
-- once hunt over (drive) horn anounce then I can; shoot anymore"*. THE SIGNALS ARE THE RULES: the
-- start horn opens the drive and the end horn closes it, so the window in which a gun may fire is
-- exactly the window the two signals bracket (`Match.Phase.driveOpen`, the one answer the bot line's
-- walk and the beater's horn read too).
--
-- `nil` IS "NO RESTRICTION" AND ONLY AN EXPLICIT `false` REFUSES, which is the same call every other
-- fact on this gate makes (`Rules.outsideStand`'s nil area, `Rules.beaterInLine`'s nil target): a
-- server with no drive wired -- every `tests/server/weapon_*.spec.luau` and a bare DEV place -- fires
-- exactly as it did before this task, and a provider that throws (the owner pcalls it) falls back to
-- the same "no restriction" rather than silencing every gun in the wood. A gate that refused on an
-- unwired world would make a mis-wiring look exactly like Karen's rule working, which is the silent
-- failure this repo measures instead of assuming.
function Rules.driveClosed(driveOpen: boolean?): boolean
	return driveOpen == false
end

-- THE ORDER THE FOUR ARE ASKED IN, DECLARED AND TESTABLE (task 171, after the Director's
-- two-player run at `8b2bb40`: the probe aimed at a beater came back `off-stand`, because the
-- shooter had walked out of his own circle, and nothing in the repo said which answer was meant to
-- win). It is here rather than in the owner because an ORDER is a rule, and a rule nobody can assert
-- is a rule that drifts -- `weapon_rules.spec`'s case *"asks the three rules in one declared order"*
-- trips all three at once and names the winner.
--
-- WHY THIS ORDER, and it is a decision and not an accident:
--   1. `OFF_STAND` first. It is a fact about the SHOOTER, true of every shot he takes from where he
--      is standing, whatever he points at -- so it is the one thing he must fix before any other
--      answer is even useful. "NOT IN YOUR STAND" tells him to move; "NOT AT A BEATER" would tell
--      him to aim somewhere else, and aiming somewhere else would not let him shoot either.
--   2. `BEATER` next. A fact about the AIM, and it must come before the licence question because a
--      man is not quarry: `Licences` has no row for him and never should.
--   3. `LICENCE` last, the narrowest -- it needs a target that published a species.
-- `Rules.ORDER` is the list, `Rules.refuse` walks it, and the owner calls `Rules.refuse` and nothing
-- else, so there is ONE place the order lives.
--
-- ...AND `DRIVE_OVER` IS FIRST SINCE TASK 174, which follows that same rule one step further out: it
-- is a fact about the DRIVE, true of every shot every player takes wherever he stands and whatever
-- he points at, so it is the one thing he cannot fix by moving or by aiming somewhere else. "NOT IN
-- YOUR STAND" to a man whose drive is over would send him walking back to a circle that will not let
-- him shoot either.
Rules.ORDER = table.freeze({
	Rules.REASON.DRIVE_OVER,
	Rules.REASON.OFF_STAND,
	Rules.REASON.BEATER,
	Rules.REASON.LICENCE,
})

-- RULE 3. IS HE SHOOTING AT SOMETHING HE HAS NO LICENCE FOR? The table is `Licences.ROWS` and this
-- is only the question; `rows` is a parameter so a spec can drive a species the game does not ship.
function Rules.unlicensed(target: Target?, held: { [string]: boolean }?, rows: any?): boolean
	if target == nil or type(target.species) ~= "string" then
		return false -- nothing identifiable was in the way: a miss is not an offence
	end
	return not Licences.allows(target.species, held, rows)
end

-- WHAT THE OWNER ASKS: the three questions in `Rules.ORDER`, and the FIRST one that answers yes.
-- PURE -- every fact is a field of `context` -- so the order is drivable with hand-written numbers
-- and no world, which is the whole reason it is a function instead of an `if` chain in the owner.
--
-- IT IS A SEQUENCER AND NOT A FOURTH PREDICATE. Each question still lives in its own function above
-- and is still tested on its own; this adds no condition of its own and answers exactly one thing:
-- which rule refuses this shot first. `Match.Penalty`'s warning is about a predicate that answers
-- two unrelated questions -- this one answers "which of the three", which is one question.
export type Context = {
	position: Vector3?, -- where the shooter is standing
	stand: StandArea?, -- his stand's circle, or nil for "he has none"
	target: Target?, -- what the aim ray hit
	licences: { [string]: boolean }?, -- what he holds
	rows: any?, -- the licence table, for a spec that wants its own
	driveOpen: boolean?, -- is the drive between its two signals? nil means "nothing said", task 174
}

function Rules.refuse(context: Context): string?
	for _, reason in ipairs(Rules.ORDER) do
		if reason == Rules.REASON.OFF_STAND then
			if Rules.outsideStand(context.position, context.stand) then
				return reason
			end
		elseif reason == Rules.REASON.BEATER then
			if Rules.beaterInLine(context.target) then
				return reason
			end
		elseif reason == Rules.REASON.LICENCE then
			if Rules.unlicensed(context.target, context.licences, context.rows) then
				return reason
			end
		elseif reason == Rules.REASON.DRIVE_OVER then
			if Rules.driveClosed(context.driveOpen) then
				return reason
			end
		end
	end
	return nil
end

return Rules
