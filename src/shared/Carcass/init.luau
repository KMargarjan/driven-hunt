--!strict
-- Carcass: the FORMAT of the one thing the server tells every client about a dead animal's drawn
-- pose -- which clip it froze and at which frame. Pure shared DATA: it creates no Instance, reads no
-- service and holds no state, so it has no run-time writer and nothing here can be written by it
-- (the shape of `src/shared/Licences/init.luau`).
--
-- ONE STRING AND NOT TWO NUMBERS. The pose changes once in a boar's life, when the paddle
-- supersedes the fall, and both halves change together; two attributes are a torn pair, and a
-- client reading between the two writes would pin the paddle track at the fall's frame.
--   https://create.roblox.com/docs/reference/engine/classes/Instance#SetAttribute
-- Design: docs/design/carcass-pose.md sections 5.1, 6.1 · Note: docs/research/2026-11-13-carcass-pose.md
local Carcass = {}

-- The attribute `Boar.Body.stepVisual` writes on the trunk and `CarcassPose` reads. One home.
Carcass.ATTRIBUTE = "DeathPose"

-- A pin AT the end of a non-looped track is the state that stopped it, so the reader stays this far
-- below the length (`Boar.CONFIG.MODEL.HOLD_EPSILON` is the same 0.03 for the same reason).
Carcass.HOLD_EPSILON = 0.03

local SEPARATOR = ":"

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- "<animationId>:<seconds>", the seconds to 4 decimals. "" for anything that is not a real pose,
-- so a bad input can never be published as a good one.
function Carcass.format(id: unknown, at: unknown): string
	if type(id) ~= "number" or type(at) ~= "number" then
		return ""
	end
	if not finite(id) or not finite(at) or id <= 0 or at < 0 then
		return ""
	end
	return string.format("%d%s%.4f", math.floor(id), SEPARATOR, at)
end

-- (id, seconds), or (nil, nil) for a non-string, an empty string, a missing or extra separator, a
-- non-numeric half, a non-finite number, id <= 0 or at < 0. A reader that cannot parse does nothing.
function Carcass.parse(value: unknown): (number?, number?)
	if type(value) ~= "string" or value == "" then
		return nil, nil
	end
	local left, right = string.match(value, "^([^" .. SEPARATOR .. "]+)" .. SEPARATOR .. "([^" .. SEPARATOR .. "]+)$")
	if left == nil or right == nil then
		return nil, nil
	end
	local id, at = tonumber(left), tonumber(right)
	if id == nil or at == nil or not finite(id) or not finite(at) or id <= 0 or at < 0 then
		return nil, nil
	end
	return id, at
end

-- The content id of an animation asset, which is what `Animation.AnimationId` holds and what a
-- client compares against to answer "is the death already drawing this animal".
function Carcass.contentId(id: number): string
	return "rbxassetid://" .. tostring(math.floor(id))
end

return Carcass
