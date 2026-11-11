--!strict
-- Camera.ProbeCamera: the ONE reader of the Studio-only PARKED-CAMERA override (task 345 T3).
--
-- WHAT IT IS FOR. Task 345b could not photograph a bed at all: the server cannot hold the client's
-- camera or its character -- measured, the client's root read 760 studs from the pose the server
-- had just written (`reviews/task-345b/`, ESCALATE.md 2026-11-10) -- so "the wood in front of a
-- stand shows no animal popping in" had no instrument. `Camera.TestLook` (task 263) turns the view
-- and cannot MOVE it: it steers the angles of a camera that still sits on the character's head.
-- This parks the whole camera, position and orientation, where a probe asks.
--
-- LEVEL-TRIGGERED AND HELD, AND THE CAMERA NEVER WRITES THE ATTRIBUTE -- `TestLook`'s rule and for
-- its measured reasons: a client's clear does not replicate up, so an edge-triggered handshake
-- asked for the same point twice is silently dropped. Clearing the attribute releases the view.
--
-- STUDIO ONLY, by `RunService:IsStudio()` rather than by a flag (`Camera.Poses`' own rule: *"a live
-- server must never read it: the attribute is a tuning instrument, not a game rule"*). The gate is
-- a PARAMETER of the pure resolver, so a spec reaches both branches with no attribute at all.
--
-- Design: docs/design/camera.md (sections 3, 9.3); docs/design/animal-placement.md section 13.3
local RunService = game:GetService("RunService")

local ProbeCamera = {}

-- THE PARKED FRAME, as comma-separated numbers -- `"x,y,z,lookX,lookY,lookZ"` (where the camera is
-- and what it looks at, which is exactly `studio_mcp capture`'s own two points, so the probe and the
-- screenshot cannot disagree) or a full twelve-component `CFrame.new`. A STRING because a probe
-- writes it from the SERVER (attributes on a `Player` replicate down) and the Luau channel carries
-- text; the parse is this file's, once, and it is pure.
ProbeCamera.ATTRIBUTE = "DHProbeCamera"

-- PURE, and the one place a string becomes a frame. `nil` for a live server, for no attribute, and
-- for anything that is not 6 or 12 finite numbers -- never an error and never a guess: a camera that
-- threw on a malformed attribute would take the player's whole view down for a typo in a test tool.
function ProbeCamera.frame(isStudio: boolean, raw: any): CFrame?
	if not isStudio or type(raw) ~= "string" then
		return nil
	end
	local pieces = string.split(raw :: string, ",")
	if #pieces ~= 6 and #pieces ~= 12 then
		return nil
	end
	local numbers = {}
	for index, piece in ipairs(pieces) do
		local value = tonumber(piece)
		-- `value ~= value` is the NaN test: `tonumber("nan")` parses, and a NaN in a CFrame puts the
		-- camera somewhere no screenshot can be described.
		if value == nil or value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		numbers[index] = value
	end
	local at = Vector3.new(numbers[1], numbers[2], numbers[3])
	if #numbers == 12 then
		return CFrame.new(
			numbers[1],
			numbers[2],
			numbers[3],
			numbers[4],
			numbers[5],
			numbers[6],
			numbers[7],
			numbers[8],
			numbers[9],
			numbers[10],
			numbers[11],
			numbers[12]
		)
	end
	local look = Vector3.new(numbers[4], numbers[5], numbers[6])
	-- A LOOK-AT POINT ON TOP OF THE CAMERA IS NOT A FRAME: `CFrame.lookAt` with a zero direction
	-- answers a NaN rotation, which is the one case the parse above cannot catch.
	if (look - at).Magnitude < 1e-3 then
		return nil
	end
	return CFrame.lookAt(at, look)
end

-- THE FRAME FOR THIS FRAME, off the LocalPlayer, or `nil`. One `IsStudio` boolean and one attribute
-- read, and outside Studio the boolean short-circuits the read away -- `TestLook.current`'s budget.
function ProbeCamera.current(player: Instance?): CFrame?
	local isStudio = RunService:IsStudio()
	if not isStudio or player == nil then
		return nil
	end
	return ProbeCamera.frame(isStudio, player:GetAttribute(ProbeCamera.ATTRIBUTE))
end

return ProbeCamera
