--!strict
-- Weapon.Limits: a pure one-second fixed-window rate limiter. The caller owns the bucket; this
-- returns a NEW bucket and never mutates the one it was given, so it is testable with no clock.
--
-- Pattern: fixed-window counter, the simplest limiter that cannot leak memory per request. A token
-- bucket would be smoother and needs a timestamp per key anyway; this is a spam cut-off, not a
-- traffic shaper (design section 5.3).
--
-- Design: docs/design/shotgun.md (sections 5.3, 5.5)
local Limits = {}

export type Bucket = { windowStart: number, count: number }

function Limits.allow(bucket: Bucket?, now: number, perSecond: number): (boolean, Bucket)
	if bucket == nil or now - bucket.windowStart >= 1 then
		return true, { windowStart = now, count = 1 }
	end
	if bucket.count >= perSecond then
		return false, { windowStart = bucket.windowStart, count = bucket.count + 1 }
	end
	return true, { windowStart = bucket.windowStart, count = bucket.count + 1 }
end

return Limits
