--!strict
-- Weapon.Registry: every per-player table the weapon owns, behind one key, so that forgetting a
-- player is ONE call that provably drops all of it. That is defect (c) of the Task 23 review -- per
-- player state and rate-limit buckets leaked and pinned the Player instance -- and it is closed by
-- a tested function rather than by a sentence in a document.
--
-- It never knows what a Player is: it keys by any value, which is what lets weapon_state.spec
-- exercise the whole lifecycle with stand-in keys and no Studio.
--
-- Design: docs/design/shotgun.md (sections 5.3, 5.4)
local Registry = {}
Registry.__index = Registry

function Registry.new()
	return setmetatable({ _states = {}, _buckets = {} }, Registry)
end

function Registry:set(key: any, state: any)
	self._states[key] = state
end

function Registry:get(key: any): any
	return self._states[key]
end

function Registry:bucket(key: any, name: string): any
	local perKey = self._buckets[key]
	return perKey and perKey[name]
end

function Registry:setBucket(key: any, name: string, bucket: any)
	local perKey = self._buckets[key]
	if not perKey then
		perKey = {}
		self._buckets[key] = perKey
	end
	perKey[name] = bucket
end

-- Removes EVERY table this registry keys by `key`. Add a table here and it is cleaned up here.
function Registry:forget(key: any)
	self._states[key] = nil
	self._buckets[key] = nil
end

function Registry:count(): number
	local n = 0
	for _ in pairs(self._states) do
		n += 1
	end
	return n
end

return Registry
