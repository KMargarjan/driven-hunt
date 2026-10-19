-- LightBoot: the composition root of the game's light, and of nothing else. Boot line only: it owns
-- nothing, decides nothing, holds no state, and creates no Instance of its own -- `Light.apply` does
-- every write, and `Light.plan` makes every decision.
--
-- IT RUNS IN EVERY WORLD, and that is the point of the task rather than an oversight. `ArenaBoot`,
-- `MatchBoot` and `ForestTestBoot` all return early on `Map.EXPECTED_WORLD`, because each of them
-- builds something only one world has. The LIGHT is not like that: one late-autumn morning, in the
-- DEV arena where the harness runs and in the Forest Test where Karen plays, is exactly what stops
-- the two drifting apart again -- which, measured on 2026-10-19, they had (`Ambient` 159,159,159 /
-- `Brightness` 3.0 / `ClockTime` 15 against 110,100,90 / 2.6 / 13).
--
-- WHY IT IS ITS OWN SCRIPT AND NOT A LINE IN `ForestTestBoot`, which is the argument
-- `OutfitAssetsBoot` and `BoarAssetsBoot` already make: that root is the Forest Test's alone, and a
-- line there would leave the DEV place unlit. It is not in `MatchBoot` for the second half of the
-- same argument -- `MatchBoot` is on `TWO_PLAYER_PATHS` (tools/agents.py), so a line added there
-- would put a two-player run and a human click into the gate of every lighting task from now on.
--
-- THE ORDER OF TWO SCRIPTS IN ServerScriptService IS UNDEFINED, and this one does not need an order.
-- It reads nothing another boot writes and writes nothing another boot reads: `Lighting` and its own
-- children, and nothing else. It runs before or after the lodge is built with the same result,
-- because the lodge's six lamps are `Lobby.Build`'s and this script never touches a `PointLight`.
--
-- Design: no new design document -- one owner for a service nobody owned, as the Director's dispatch
-- specified it (TASKS.md row 215).
-- Note: docs/research/2026-10-19-one-owner-for-the-lighting.md
local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")

local Light = require(ServerScriptService:WaitForChild("Light"))

-- A BAD ROW IS ONE LINE AND NOT FIVE RUNS (`Flags.problems`'s own shape). It is reported whether the
-- flag is on or off, because a table with a fault in it is a fault in the commit, not in the run.
local problems = Light.problems(Light.CONFIG)
if #problems > 0 then
	warn(string.format("[LightBoot] the lighting table has %d fault(s): %s", #problems, table.concat(problems, "; ")))
end

-- THE ONE FLAG READ IS `Light.ENABLED`, AT ITS OWNER'S BOUNDARY, and this root only reads that back
-- -- so there is still one source for it (`OutfitAssetsBoot`'s own rule, and `ForestTestBoot`'s).
local plan = Light.plan(Light.ENABLED, Light.CONFIG)

-- OFF IS "NOTHING WAS WRITTEN", and the line says so out loud. The place keeps its own `Lighting`
-- exactly as it stands: not restored, not overwritten with a second set of numbers, not touched.
-- That is what makes `python tools/flags.py set AUTUMN_LIGHT off` a real off-switch for a look.
if plan == nil then
	print("[LightBoot] AUTUMN_LIGHT is off: the place's own Lighting is untouched.")
	return
end

local report = Light.apply(Lighting, plan)

-- ONE LINE, AND IT IS THE EVIDENCE. Three things are only ever visible here: WHICH instances this
-- server created rather than took over (a place with none is a place whose look was never saved),
-- any property the engine refused (`failed`), and a SECOND `Atmosphere` or grade stacking on top of
-- the one this module writes (`extra`). Without it, a half-applied look and a fully-applied one read
-- identically in a screenshot.
local function list(label: string, values: { string }): string
	if #values == 0 then
		return ""
	end
	return string.format(" %s=%s", label, table.concat(values, ","))
end

print(
	string.format(
		"[LightBoot] AUTUMN_LIGHT is on: %d property(ies) written on Lighting and its children.%s%s%s%s",
		report.written,
		list("created", report.created),
		list("adopted", report.adopted),
		list("absent", report.absent),
		list("extra", report.extra)
	)
)

-- A REFUSED PROPERTY IS A WARNING AND NOT A CRASH, and it is separate from the line above so it
-- cannot be read past. `Light.apply` guards every write for this reason: a lighting owner that threw
-- on one unknown property would leave the world half-lit, which is worse than the look it was
-- fixing. `Technology` is NOT in this list -- it is deliberately not written at all, because the
-- engine refuses even to read it from a script (research note, section 2).
if #report.failed > 0 then
	warn(
		string.format(
			"[LightBoot] the engine refused %d write(s): %s",
			#report.failed,
			table.concat(report.failed, " | ")
		)
	)
end
