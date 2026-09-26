--!strict
-- MapGen.Settings: THE ONLY WRITER OF `Workspace`'s five streaming properties (design section 2.2).
-- It writes nothing else, anywhere.
--
-- It runs LAST in a build, deliberately: turning streaming on midway would make the rest of the run
-- fight the engine over what is loaded (design section 5.2 layer 9). For M2.1 the contract says
-- `enabled = false`, so this step's job is to assert that the place still agrees with the contract
-- rather than to change behaviour -- M2.6 is the task that turns it on, alone, with a playtest.
--
--   Instance streaming https://create.roblox.com/docs/workspace/streaming
--
-- Design: docs/design/map-generator.md (sections 2.2, 5.2)
local Workspace = game:GetService("Workspace")

local Settings = {}

-- Applies the contract's streaming block. Returns what it changed, so a step report says "nothing"
-- when nothing moved instead of claiming a write it did not make.
function Settings.apply(streaming): { string }
	local changed = {}
	local wanted: { [string]: any } = {
		StreamingEnabled = streaming.enabled,
		StreamingMinRadius = streaming.minRadius,
		StreamingTargetRadius = streaming.targetRadius,
		StreamingIntegrityMode = Enum.StreamingIntegrityMode[streaming.integrityMode],
		ModelStreamingBehavior = Enum.ModelStreamingBehavior[streaming.modelBehavior],
	}
	for property, value in pairs(wanted) do
		if (Workspace :: any)[property] ~= value then
			(Workspace :: any)[property] = value
			table.insert(changed, property)
		end
	end
	table.sort(changed)
	return changed
end

-- What the place currently says, as plain strings, so a run log records it.
function Settings.current(): { [string]: string }
	return {
		StreamingEnabled = tostring(Workspace.StreamingEnabled),
		StreamingMinRadius = tostring(Workspace.StreamingMinRadius),
		StreamingTargetRadius = tostring(Workspace.StreamingTargetRadius),
		StreamingIntegrityMode = tostring(Workspace.StreamingIntegrityMode),
		ModelStreamingBehavior = tostring(Workspace.ModelStreamingBehavior),
	}
end

return Settings
