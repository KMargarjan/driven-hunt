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
function Settings.apply(streaming): ({ string }, { string })
	local changed, unreachable = {}, {}
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
		elseif typeof(current) == "boolean" and current ~= value then
			(Workspace :: any)[property] = value
			table.insert(changed, property)
		end
	end
	table.sort(changed)
	table.sort(unreachable)
	return changed, unreachable
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
