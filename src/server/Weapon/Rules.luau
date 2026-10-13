--!strict
-- Weapon.Rules: MAY THIS SHOT BE TAKEN AT ALL? Pure -- no service, no Instance, no clock, no
-- `Player`, no `Random`; every fact is a parameter. The owner (`Weapon.onFireRequest`) asks these
-- questions in its own order and is the only thing that writes.
--
-- THREE RULES OF ONE NEW SHAPE (task 171): the trigger does nothing and NOTHING IS TAKEN AWAY.
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
})

-- ONE SHORT LINE EACH, in the Hud's own voice ("NO BUCK" is the line this sits beside). Short
-- because the readout is one row at the bottom of the screen and Karen's rule is a clear screen.
Rules.NOTICE = table.freeze({
	[Rules.REASON.BEATER] = "NOT AT A BEATER",
	[Rules.REASON.OFF_STAND] = "NOT IN YOUR STAND",
	[Rules.REASON.LICENCE] = "NO LICENCE",
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
	if type(area.radius) ~= "number" or area.radius <= 0 then
		-- A circle with no radius is not a boundary. Refusing every shot on one would make a
		-- mis-wired provider look exactly like Karen's rule working, which is the kind of silent
		-- failure this repo measures rather than assumes.
		return false
	end
	local flat = Vector3.new(position.X - area.centre.X, 0, position.Z - area.centre.Z)
	return flat.Magnitude > area.radius
end

-- RULE 3. IS HE SHOOTING AT SOMETHING HE HAS NO LICENCE FOR? The table is `Licences.ROWS` and this
-- is only the question; `rows` is a parameter so a spec can drive a species the game does not ship.
function Rules.unlicensed(target: Target?, held: { [string]: boolean }?, rows: any?): boolean
	if target == nil or type(target.species) ~= "string" then
		return false -- nothing identifiable was in the way: a miss is not an offence
	end
	return not Licences.allows(target.species, held, rows)
end

return Rules
