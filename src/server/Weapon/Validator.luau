--!strict
-- Weapon.Validator: pure checks on what a client sent. Nothing here trusts a client, and nothing
-- here touches an Instance, a service or a clock.
--
-- checkRequest is the whitelist that makes the reducer's primitives unreachable from a client
-- (design section 2.1 defect d): only "Reload" and "SelectAmmo" cross the wire; Break, Load, Close
-- and Fire are server-side ActionKinds and are not in the accepted set at all.
--
-- Design: docs/design/shotgun.md (section 5.3)
-- Note:   docs/research/2026-09-24-shotgun.md
local Validator = {}

local function isFinite(v: Vector3): boolean
	return v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) ~= math.huge
		and math.abs(v.Y) ~= math.huge
		and math.abs(v.Z) ~= math.huge
end

-- `req.origin` is the CAMERA position and `req.direction` its unit LookVector, so the tolerance is
-- generous on purpose: under the stock third-person camera the origin is MEANT to be behind the
-- character (design section 5.5 step 2).
function Validator.checkShot(req: any, rootPosition: Vector3?, config): (boolean, string?)
	if rootPosition == nil then
		return false, "not-alive"
	end
	if type(req) ~= "table" or typeof(req.origin) ~= "Vector3" or typeof(req.direction) ~= "Vector3" then
		return false, "bad-type"
	end
	if not isFinite(req.origin) or not isFinite(req.direction) then
		return false, "nan"
	end
	if math.abs(req.direction.Magnitude - 1) > config.DIR_UNIT_TOLERANCE then
		return false, "not-unit"
	end
	if (req.origin - rootPosition).Magnitude > config.CAMERA_ORIGIN_TOLERANCE then
		return false, "origin-far"
	end
	return true, nil
end

-- The ONLY strings ActionRequest accepts. Everything else, including every reducer primitive, is
-- "bad-request".
function Validator.checkRequest(kind: unknown, ammo: unknown): (boolean, string?)
	if kind == "Reload" then
		if ammo ~= nil then
			return false, "bad-request"
		end
		return true, nil
	end
	if kind == "SelectAmmo" and (ammo == "Slug" or ammo == "Buck") then
		return true, nil
	end
	return false, "bad-request"
end

return Validator
