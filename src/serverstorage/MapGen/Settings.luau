--!strict
-- MapGen.Settings: THE ONLY WRITER OF `Workspace`'s five streaming properties (design section 2.2).
-- It writes nothing else, anywhere.
--
-- It runs LAST in a build, deliberately: a streaming change midway would make the rest of the run
-- fight the engine over what is loaded (design section 5.2 layer 9).
--
-- MEASURED 2026-09-26 in Studio 0.740.19: of the five properties the design gives this module, only
-- `StreamingEnabled` is reachable from Luau. The other four raise "not a valid member of Workspace" --
-- they are Studio-panel place settings. So this module writes the one it can, and REPORTS the four it
-- cannot instead of failing the build over them or pretending it set them (rule 8). M2.6 is therefore
-- a Karen click plus a playtest, and this step is what proves the place still agrees with the
-- contract's `enabled`.
--
--   Instance streaming https://create.roblox.com/docs/workspace/streaming
--
-- Design: docs/design/map-generator.md (sections 2.2, 5.2)
local Workspace = game:GetService("Workspace")

local Settings = {}

-- Applies the contract's streaming block. Returns what it changed, so a step report says "nothing"
-- when nothing moved instead of claiming a write it did not make.
-- M2.6 IS THE TASK THAT TURNS STREAMING ON, alone, with a playtest (design section 14). Until it
-- runs, this module REFUSES to change a streaming property rather than writing one silently: today
-- the build's last step is inert only because `Map.STREAMING.enabled` happens to match the place, and
-- a one-character edit to the contract would otherwise make M2.6's change during an M2.3 build
-- (audit-004 F4, TASKS.md row 43a(f)). M2.6 flips this constant and takes the playtest with it.
Settings.MAY_WRITE = false

function Settings.apply(streaming): ({ string }, { string }, { string }, { string })
	local changed, unreachable, unwritten, refused = {}, {}, {}, {}
	local wanted: { [string]: any } = {
		StreamingEnabled = streaming.enabled,
		StreamingMinRadius = streaming.minRadius,
		StreamingTargetRadius = streaming.targetRadius,
		StreamingIntegrityMode = streaming.integrityMode,
		ModelStreamingBehavior = streaming.modelBehavior,
	}
	for property, value in pairs(wanted) do
		local readable, current = pcall(function()
			return (Workspace :: any)[property]
		end)
		if not readable then
			table.insert(unreachable, property)
		elseif typeof(current) == "boolean" then
			if current ~= value then
				if Settings.MAY_WRITE then
					(Workspace :: any)[property] = value
					table.insert(changed, property)
				else
					table.insert(refused, property)
				end
			end
		else
			-- Readable, but not a boolean: the four M2.6 values are two numbers and two enum names,
			-- and this module will not convert a string to an Enum and guess. Reported as a THIRD
			-- class rather than skipped, so the day the engine exposes one, the step says "I did not
			-- write this" instead of "already matched the contract" (review round 1, note).
			table.insert(unwritten, property)
		end
	end
	table.sort(changed)
	table.sort(unreachable)
	table.sort(unwritten)
	table.sort(refused)
	return changed, unreachable, unwritten, refused
end

-- What the place currently says, as plain strings, so a run log records it.
function Settings.current(): { [string]: string }
	local out: { [string]: string } = {}
	for _, property in ipairs({
		"StreamingEnabled",
		"StreamingMinRadius",
		"StreamingTargetRadius",
		"StreamingIntegrityMode",
		"ModelStreamingBehavior",
	}) do
		local ok, value = pcall(function()
			return (Workspace :: any)[property]
		end)
		out[property] = if ok then tostring(value) else "unreachable from Luau"
	end
	return out
end

return Settings
