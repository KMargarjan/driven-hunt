--!strict
-- Weapon.Rewind: test a bullet's segment against each animal WHERE THE SHOOTER DREW IT (task 305).
--
-- Karen, 2026-10-28: *"aiming is off ... I need to aim in free space to hit boar correctly"*.
-- MEASURED in DEV that day (<runs-dir>/305lag.py): the client draws a server-owned boar
-- +0.180 s in the past (residual 0.011 studs), while its own client-owned part reads -0.170 s --
-- opposite signs, so it is replication delay, not clock skew. 0.180 s x 24 studs/s = 4.3 studs of
-- lead nobody can see, on top of the real ballistic 1.18.
--
-- Pattern: Valve's server-side hitbox rewind, in the RAY-TRANSLATION variant -- cast the segment
-- moved by MINUS the animal's own displacement over the lag, against the animal's present parts,
-- and move the impact back. Only the animal is rewound; trees, ground and stands stay put.
--   https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization
--   https://devforum.roblox.com/t/how-to-make-lag-compensation/1398919
-- The translation trick is already in this repo, in `Weapon.Claim.simulate`'s target pass (task 266).
--
-- PURE: no world, no clock, no cast of its own. The caller hands in the candidates with both
-- tenses and a per-instance cast, which is what lets `weapon_rewind.spec` drive it with hand-made
-- CFrames and no Workspace.
--
-- Design: docs/design/ballistics.md (section 4.6, the ring this reads through)
-- Note:   docs/research/2026-10-28-lag-compensation.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

type Impact = Shotgun.Impact

-- One animal, in both tenses. `present` is where the server has it now; `past` is where the ring
-- says it was when the shooter's screen drew it. Same instance either way.
export type Candidate = { root: Instance, present: CFrame, past: CFrame }

local Rewind = {}

-- THE NEAREST REWOUND IMPACT ON THIS SEGMENT, or nil.
--
-- `castOnly(root, origin, segment) -> Impact?` must cast against THAT INSTANCE ALONE (an Include
-- filter plus `Shotgun.Pierce`, so a `ZonesOnly` animal's own trunk is passed through, which task
-- 280 round 1 proved is not optional).
--
-- TRANSLATION ONLY, AND THE ROTATION IS NAMED RATHER THAN DISCOVERED: an animal that TURNED during
-- the lag is tested at its present heading in its past position, which is `Claim.simulate`'s own
-- approximation and is tenths of a stud over 0.18 s at a boar's turn rate.
function Rewind.impact(
	origin: Vector3,
	segment: Vector3,
	candidates: { Candidate },
	castOnly: (Instance, Vector3, Vector3) -> Impact?,
	maxTargets: number?
): Impact?
	if typeof(origin) ~= "Vector3" or typeof(segment) ~= "Vector3" or type(candidates) ~= "table" then
		return nil
	end
	local cap = if type(maxTargets) == "number" and maxTargets > 0 then maxTargets else #candidates
	local best: Impact? = nil
	for index, candidate in ipairs(candidates) do
		if index > cap then
			break
		end
		if typeof(candidate.present) == "CFrame" and typeof(candidate.past) == "CFrame" then
			-- The shift that carries the PRESENT animal onto its PAST self. Applying it to the ray
			-- backwards is the same question with nothing moved.
			local shift = candidate.past.Position - candidate.present.Position
			local hit = castOnly(candidate.root, origin - shift, segment)
			if hit ~= nil and (best == nil or hit.distance < best.distance) then
				best = {
					instance = hit.instance,
					-- REPORTED IN THE PAST FRAME: this is where the shooter saw the animal, so the
					-- mark the client draws lands on the body it drew and not ahead of its nose.
					position = hit.position + shift,
					normal = hit.normal,
					distance = hit.distance,
					material = hit.material,
				}
			end
		end
	end
	return best
end

-- THE WINNER OF THE TWO PASSES, nearest first. `static` is the world with every candidate EXCLUDED
-- (so a present-position animal can never stop a bullet and be mistaken for a tree), `rewound` is
-- the answer above. A tie goes to the static world: cover wins.
function Rewind.nearer(static: Impact?, rewound: Impact?): Impact?
	if static == nil then
		return rewound
	end
	if rewound == nil then
		return static
	end
	return if rewound.distance < static.distance then rewound else static
end

return Rewind
