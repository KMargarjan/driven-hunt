--!strict
-- Camera.Cursor: THE ONLY WRITER of UserInputService.MouseBehavior, .MouseIconEnabled,
-- .MouseDeltaSensitivity and Mouse.Icon (CLAUDE.md rule 3).
--
-- Pattern: a TAGGED REQUEST API instead of a setter. A caller states a NEED ("I want a free cursor,
-- and my tag is `menu`"); this module resolves every outstanding need and performs the single write.
-- Three systems can want a free cursor and there is still exactly one writer -- which is "three
-- scripts set the mouse cursor" (docs/PROJECT_CONTEXT.md, the previous project's death) designed out
-- rather than banned.
--   UserInputService.MouseBehavior  https://create.roblox.com/docs/reference/engine/classes/UserInputService
--
-- It writes only when the engine's value differs from the wanted one, and counts every difference it
-- did not cause. A non-zero `reasserts` means something else wrote the mouse: a number a spec
-- asserts is zero (design section 10.1).
--
-- Design: docs/design/camera.md (sections 3.3, 5.4)
local UserInputService = game:GetService("UserInputService")

local Cursor = {}

local tags: { [string]: boolean } = {}
local reasserts = 0
local started = false
local wantedBehavior: Enum.MouseBehavior? = nil
local wantedIcon: boolean? = nil

function Cursor.start()
	started = true
	table.clear(tags)
	wantedBehavior, wantedIcon = nil, nil
	Cursor.apply()
end

function Cursor.stop()
	started = false
	table.clear(tags)
	wantedBehavior, wantedIcon = nil, nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

function Cursor.requestFree(tag: string)
	assert(type(tag) == "string" and tag ~= "", "Cursor.requestFree needs a non-empty tag")
	tags[tag] = true
end

function Cursor.release(tag: string)
	tags[tag] = nil
end

function Cursor.isFree(): boolean
	return next(tags) ~= nil
end

-- Called once per frame by the owner. Writes only on a difference, and counts the differences it did
-- not cause.
function Cursor.apply()
	if not started then
		return
	end
	local free = Cursor.isFree()
	local behavior = if free then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	local iconEnabled = free

	if wantedBehavior ~= nil and wantedIcon ~= nil then
		if UserInputService.MouseBehavior ~= wantedBehavior or UserInputService.MouseIconEnabled ~= wantedIcon then
			reasserts += 1
		end
	end

	if UserInputService.MouseBehavior ~= behavior then
		UserInputService.MouseBehavior = behavior
	end
	if UserInputService.MouseIconEnabled ~= iconEnabled then
		UserInputService.MouseIconEnabled = iconEnabled
	end
	wantedBehavior, wantedIcon = behavior, iconEnabled
end

function Cursor.stats()
	local out = {}
	for tag in pairs(tags) do
		table.insert(out, tag)
	end
	table.sort(out)
	return { reasserts = reasserts, tags = out }
end

return Cursor
