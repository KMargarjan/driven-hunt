--!strict
-- HeldTool: WHAT THE FIRST-PERSON VIEW DRAWS FOR THE TOOL IN THIS HAND. One question, one answer,
-- read by the two camera modules that have to agree about it (task 176).
--
-- WHY IT EXISTS. `Camera.Viewmodel` draws the thing in the hand under `workspace.CurrentCamera`, and
-- `Camera.Rig` hides the REAL thing in the hand for the local player. They are exact complements:
-- what is in the hand is on screen ONCE -- either as the viewmodel or as the real Tool -- never twice
-- and never not at all. Task 152 established that with one shared fact (`Weapons.isWeaponTool`,
-- asked identically in both files) after a beater in first person saw A SHOTGUN: the viewmodel took
-- the horn's Handle and fell back to the shotgun's config.
--
-- Task 176 adds the horn to what the view DRAWS (Karen, 2026-10-13: *"horn still hangign somewhere it
-- has to be in hand now I can turn around and horn stand in place somehwere behind"*), and the
-- obvious way to do that -- "or it is a horn" in both files -- is how two correct pieces of code
-- start disagreeing (docs/PROJECT_CONTEXT.md: *"Most of the worst bugs were two correct pieces of
-- code disagreeing"*). So the fact moves here, the two modules keep asking ONE function, and the
-- complement is a property of this file rather than of a habit.
--
-- WHY A THIRD MODULE AND NOT A ROW IN EITHER. `Weapons` is the table of GUNS -- "what a row may not
-- carry" is a rule in its own header -- and a horn is not a weapon; `Horn` is the horn's own data and
-- does not know what a weapon is. This is the only file in the repo that requires both, and it holds
-- nothing but the question.
--
-- IT IS NOT A LIST OF EVERY TOOL. A Tool this file does not name draws NOTHING in first person and
-- stays visible as itself -- task 152's refusal, unchanged, for every non-weapon Tool that is not the
-- horn. Adding one is a line here plus a drawing branch in `Camera.Viewmodel`; it is deliberately not
-- a default, because "draw whatever is in the hand" is what drew a shotgun out of a horn.
--
-- Note: docs/research/2026-10-13-horn-in-the-first-person-view.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local HeldTool = {}

-- The two kinds the first-person view can draw, as the strings `Camera.Viewmodel` branches on.
HeldTool.WEAPON = "weapon"
HeldTool.HORN = "horn"

-- WHAT THE VIEW DRAWS FOR THIS TOOL: `HeldTool.WEAPON`, `HeldTool.HORN`, or nil for "nothing".
--
-- THE WEAPON QUESTION IS ASKED FIRST AND IS `Weapons.isWeaponTool` ITSELF -- the attribute
-- (`DrivenHunt.Weapon`, written by `Weapon.Hardware.build`) and then the Tool's NAME, so a Tool
-- granted by a server older than task 140 is still a gun. The HORN is matched by its name through
-- `Horn.isToolName`, which is the constant `Weapon.Horn` builds the Tool with, so no caller carries
-- the literal "Horn".
--
-- nil FOR ANYTHING THAT IS NOT A TOOL, including nil itself: the callers walk up from a part and may
-- legitimately find no Tool at all (a part of the body, or a Handle a spec injected outside a Tool).
function HeldTool.kindOf(tool: Instance?): string?
	if tool == nil or not tool:IsA("Tool") then
		return nil
	end
	if Weapons.isWeaponTool(tool) then
		return HeldTool.WEAPON
	end
	if Horn.isToolName((tool :: Tool).Name) then
		return HeldTool.HORN
	end
	return nil
end

-- DOES THE FIRST-PERSON VIEW DRAW THIS TOOL AT ALL? The same fact as a boolean, for `Camera.Rig`,
-- which does not care WHICH thing it is -- only whether the viewmodel is going to draw it, because
-- that is exactly when the real one must be hidden.
function HeldTool.drawsFirstPerson(tool: Instance?): boolean
	return HeldTool.kindOf(tool) ~= nil
end

return HeldTool
