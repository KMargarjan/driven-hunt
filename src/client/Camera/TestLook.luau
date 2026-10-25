--!strict
-- Camera.TestLook: the ONE reader of the Studio-only HELD look override (CLAUDE.md rule 3, task 263).
--
-- WHAT IT IS FOR. The Learning Agent, 2026-10-25: *"we cannot point a camera to photograph anything
-- in Play ... until that is fixed, nobody can prove shooting or animal behaviour where you play
-- it."* A proof of a shot needs the real first-person view held on the animal while a REAL click
-- travels through the window and a frame is taken -- and task 261's item 3 is `NOT PROVEN` because
-- there was no instrument that could do it.
--
-- IT IS NOT `DHLookAt`, AND THE DIFFERENCE IS THE WHOLE REASON THIS FILE EXISTS. That attribute
-- (task 101, read in `Camera.start`) is an EDGE-TRIGGERED ONE-SHOT: the harness writes a point,
-- `Camera.lookAt` snaps to it, and the owner writes the attribute back to `nil` as its handshake.
-- Three things were MEASURED in the Forest Test on 2026-10-25 and each of them is fatal to an aiming
-- instrument:
--   1. it works, and well -- a client probe moved the view 84.8599 degrees and landed 0.00 degrees
--      off the asked-for point (`<runs-dir>/263-camlook.luau`). So the premise that the camera
--      cannot be pointed was wrong; task 258's `moved=0.0000` was a probe that went through
--      `require()` and got the command bar's own fresh copy of the module.
--   2. FROM THE SERVER THE HANDSHAKE IS BROKEN. The client's clear is a client write to its own
--      `Player` and does not replicate up, so the server's copy is never cleared
--      (`serverCopyAfter1 == serverCopyAfter2`, `<runs-dir>/263-camlook-server.luau`). Asking for the
--      SAME point a second time changes no property, fires no changed signal, and is silently
--      dropped -- and a probe aims through the server, because that is the side that can see the
--      animals.
--   3. it holds nothing. One snap, and the next frame is whatever the player's own input says.
--
-- SO THIS ONE IS LEVEL-TRIGGERED AND HELD, AND **THE CAMERA NEVER WRITES THE ATTRIBUTE**. There is
-- no handshake to break, re-asking the same point is idempotent, and a probe releases the view by
-- saying so rather than by the owner deleting the record of where it was pointed. One writer: the
-- probe. One reader: this file.
--
-- STUDIO ONLY, AND BY `RunService:IsStudio()` RATHER THAN BY A FLAG -- `Camera.Poses`'s own rule,
-- quoted: *"A live server must never read it: the attribute is a tuning instrument, not a game rule,
-- and a published place has nothing to write it."* The gate is a PARAMETER of the pure resolver
-- below, so a spec reaches both branches with no Studio session and no attribute at all -- the shape
-- `Economy.testGrantFor` and `Economy.testOwnsFor` already have.
--
-- Pattern: a resolved-per-frame overlay over the state the step produced, exactly as
-- `Camera.Poses.holdState` is -- read at a boundary, applied after the step, never consulted twice
-- in one frame.
--
-- Design: docs/design/camera.md (sections 3, 9.3)
-- Note:   docs/research/2026-10-01-poses-as-data.md (the override-attribute pattern this copies)
local RunService = game:GetService("RunService")

local TestLook = {}

-- THE HELD POINT, as a comma-separated string -- `"x,y,z"`. A STRING and not a `Vector3`, for one
-- measured reason: a probe writes this from the SERVER (attributes on a `Player` replicate down),
-- and `studio_mcp`'s Luau channel carries text. The parse is this file's, once, and it is pure.
TestLook.ATTRIBUTE = "DHTestLook"
-- ...AND THE RELEASE. `true` gives the view back to the player even while the point above still
-- holds a value, so an instrument can hand control back without forgetting where it was aiming.
-- Clearing the point releases too; this is the POSITIVE signal, and `off` wins when both are set.
TestLook.OFF_ATTRIBUTE = "DHTestLookOff"

-- PURE, exported, and the one place a string becomes a point.
--
-- `nil` FOR A LIVE SERVER, for no attribute, for the release, and for anything that is not three
-- finite numbers. Never an error and never a guess: a camera that threw on a malformed attribute
-- would take the player's whole view down for a typo in a test tool.
function TestLook.point(isStudio: boolean, raw: any, off: any): Vector3?
	if not isStudio or off == true or type(raw) ~= "string" then
		return nil
	end
	local pieces = string.split(raw :: string, ",")
	if #pieces ~= 3 then
		return nil
	end
	local out = { 0, 0, 0 }
	for index, piece in ipairs(pieces) do
		local value = tonumber(piece)
		-- `value ~= value` is the NaN test: `tonumber("nan")` parses, and a NaN fed to
		-- `CFrame.lookAt` puts the camera somewhere no screenshot can be described.
		if value == nil or value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		out[index] = value
	end
	return Vector3.new(out[1], out[2], out[3])
end

-- THE POINT FOR THIS FRAME, off the LocalPlayer, or `nil`. One `IsStudio` boolean and two attribute
-- reads outside Studio -- and outside Studio the boolean short-circuits both away, so a production
-- frame costs one comparison, which is `Poses.config`'s own budget.
function TestLook.current(player: Instance?): Vector3?
	local isStudio = RunService:IsStudio()
	if not isStudio or player == nil then
		return nil
	end
	return TestLook.point(
		isStudio,
		player:GetAttribute(TestLook.ATTRIBUTE),
		player:GetAttribute(TestLook.OFF_ATTRIBUTE)
	)
end

return TestLook
