--!strict
-- Camera.Poses: the ONE reader of the live pose override (CLAUDE.md rule 3, task 98).
--
-- WHAT IT IS FOR. Karen, 2026-10-01, after task 97 was stopped: tuning a pose by editing Luau,
-- running the gate and waiting for a review cost hours per tweak, and the thing being tuned is a
-- picture. So the numbers are data (`src/shared/Viewmodel/poses.json`) and, while a Studio session is
-- running, `tools/pose.py set` writes an override into it that this module applies on the NEXT FRAME.
-- The Director moves a number, looks at the screen, and `tools/pose.py save` writes the keepers back
-- into the file. No commit, no review round, nothing in the git tree.
--
-- STUDIO ONLY, AND BY `RunService:IsStudio()` RATHER THAN BY A FLAG. A live server must never read
-- it: the attribute is a tuning instrument, not a game rule, and a published place has nothing to
-- write it. Outside Studio this module answers with the base config -- the same table, not a copy --
-- so a production frame does one boolean and no work at all.
--
-- IT DOES NOT WRITE ANYTHING. `tools/pose.py` is the one writer of the attribute
-- (GAME_DESIGN.md owners); this reads it, and `ReplicatedStorage.Viewmodel` is the one definition of
-- what it means (`Viewmodel.merge`, `Viewmodel.view`, `Viewmodel.hold`), so the tool, the camera and
-- the specs cannot disagree about a path.
--
-- Pattern: a resolved-per-frame overlay over a frozen base, exactly the shape
-- `src/shared/Flags/init.luau` has for a flag override -- read at a boundary, passed inward as
-- `config`, and never consulted twice in one frame.
--
-- Note: docs/research/2026-10-01-poses-as-data.md
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local Mode = require(script.Parent.Mode)

local Poses = {}

-- CACHED ON THE RAW STRING, which is what makes a per-frame read cost nothing: the attribute is one
-- JSON string, so "has anything changed" is a string comparison, and the merge plus the view run
-- once per change rather than sixty times a second.
local cachedRaw: string? = nil
-- ...AND WHICH WEAPON THAT RESOLVED CONFIG IS FOR (task 140): the same cache, one key wider.
local cachedWeapon: string? = nil
local cachedConfig: any = nil
local cachedHold: string? = nil
local warnedFor: string? = nil

local stats = { applied = 0, refused = 0, lastProblem = nil :: string? }

function Poses.stats()
	return table.clone(stats)
end

-- WHAT THE OVERRIDE SAYS, PURELY -> (config, hold, problems). No Instances, no clock, no services
-- beyond JSON decoding, so `tests/server/viewmodel_poses.spec.luau` drives every path of it on the
-- SERVER with no client and no Studio session at all.
--
-- `raw` is the attribute's text. Anything it cannot use leaves the BASE config untouched and comes
-- back as a problem: a half-applied override is a build nobody can name, and the Director would be
-- looking at a gun whose numbers are not the ones they typed.
function Poses.resolve(base: any, raw: string?, weaponId: string?): (any, string?, { string })
	-- NOTHING TO DO FOR THE DEFAULT WEAPON WITH NO OVERRIDE: `base` is already `Camera.Config`,
	-- which was built from that weapon's own view at boot.
	local wanted = weaponId or Data.DEFAULT_WEAPON
	if (raw == nil or raw == "") and wanted == Data.DEFAULT_WEAPON then
		return base, nil, {}
	end
	if raw == nil or raw == "" then
		-- A SECOND WEAPON, NO OVERRIDE: recompute the flat names from that weapon's own set. This is
		-- the path the rifle takes in a published server, which is why `Poses.config` no longer
		-- returns early outside Studio.
		local out = table.clone(base)
		for key, value in pairs(Data.view(Data.DATA, wanted)) do
			out[key] = value
		end
		return table.freeze(out), nil, {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return base, nil, { "the override is not a JSON object: " .. string.sub(tostring(decoded), 1, 120) }
	end
	local merged, problems = Data.merge(Data.DATA, decoded)
	local hold = Data.hold(decoded)
	if #problems > 0 then
		-- REFUSED WHOLE, not per path. Applying the three paths that parsed and dropping the fourth
		-- would put the gun in a pose that is in no file and in no command.
		return base, hold, problems
	end
	local out = table.clone(base)
	-- THE SAME VIEW `Camera.Config` WAS BUILT FROM, recomputed over the merged data: one gun since
	-- task 114, so there is no second pose set a tuning override could silently swap to.
	for key, value in pairs(Data.view(merged, wanted)) do
		out[key] = value
	end
	return table.freeze(out), hold, problems
end

-- The config for THIS FRAME: `base` itself unless this is a second weapon, or a Studio session has
-- a usable override.
--
-- IT NO LONGER RETURNS EARLY OUTSIDE STUDIO (task 140), and that was a real defect waiting to
-- happen: the early return meant a published server never recomputed the view, so the RIFLE's poses
-- would never have applied anywhere but in Studio. The production cost is one table lookup against
-- a cache keyed by `(raw, weaponId)` -- exactly as the raw-string cache was keyed before.
function Poses.config(base: any, weaponId: string?): any
	local wanted = weaponId or Data.DEFAULT_WEAPON
	local raw: string? = nil
	if RunService:IsStudio() then
		local folder = ReplicatedStorage:FindFirstChild("Viewmodel")
		local attribute = if folder then folder:GetAttribute(Data.OVERRIDE_ATTRIBUTE) else nil
		raw = if type(attribute) == "string" then attribute :: string else nil
	end
	-- NO EARLY RETURN AT ALL, and that is the Reviewer's round-2 finding (task 140): one that
	-- answered `base` before the cache was written left `cachedHold` holding whatever the LAST
	-- override said, so `tools/pose.py clear` -- which clears by REMOVING the attribute, so the next
	-- frame reads nil -- never released the hold, and `Camera.update` kept forcing `mode = "Aiming"`,
	-- `blend = 1` on every frame for the rest of the session. The cache below is keyed on exactly
	-- the two things that decide the answer, so it IS the fast path: nil and the default weapon
	-- resolve to `base` itself once and then cost one string compare and one table read.
	if raw == cachedRaw and wanted == cachedWeapon and cachedConfig ~= nil then
		return cachedConfig
	end
	local resolved, hold, problems = Poses.resolve(base, raw, wanted)
	cachedRaw = raw
	cachedWeapon = wanted
	cachedConfig = resolved
	cachedHold = hold
	if #problems > 0 then
		stats.refused += 1
		stats.lastProblem = problems[1]
		-- ONCE PER DISTINCT OVERRIDE, not per frame: a warning sixty times a second is a warning
		-- nobody can read. `tools/pose.py set` refuses the same paths in Python before it writes, so
		-- this only fires for an attribute something else put there.
		if warnedFor ~= raw then
			warnedFor = raw
			warn("[poses] override refused: " .. problems[1] .. " (" .. tostring(#problems) .. " problem(s))")
		end
	elseif raw ~= nil then
		stats.applied += 1
	end
	return resolved
end

-- WHICH POSE IS BEING HELD for a screenshot, or nil. Set by `tools/pose.py compare`, which needs the
-- gun to sit still in one named pose while it captures the frame: a swing caught half way is not a
-- picture anybody can compare with a video frame.
function Poses.hold(): string?
	if not RunService:IsStudio() then
		return nil
	end
	return cachedHold
end

-- THE HELD POSE, APPLIED TO THE STATE -- pure, so a spec drives it with fabricated states.
--
-- It runs AFTER `Mode.step`, every frame, so the player's own aim button and the reload's own clock
-- are overridden rather than fought: the next frame's step starts from the forced state and this
-- forces it again.
--
-- IT NEVER FORCES A MODE THE CAMERA IS NOT IN. Loading and Dead are states about the character --
-- no character yet, or no life -- and a hold that put a viewmodel on screen in either would be a
-- screenshot of a bug (design section 4.1).
function Poses.holdState(state: Mode.State, hold: string?): Mode.State
	if hold == nil or (state.mode ~= "Third" and state.mode ~= "Aiming") then
		return state
	end
	local next_ = table.clone(state) :: any
	-- AND THE SCOPE SITS STILL (design 7.3, the Reviewer's note rounds 1 and 2): the sway is a VIEW
	-- term, so a held frame taken mid-wander is off by up to `ampDeg` in each axis -- which is the
	-- whole point of a hold, and is invisible in the frame itself. The phase goes back to the start
	-- too, so two captures of the same hold are the same picture.
	next_.scopeSwayDeg = Vector2.zero
	next_.scopePhase = 0
	if hold == "carry" then
		next_.mode = "Third"
		next_.blend = 0
		next_.openTilt = 0
	elseif hold == "raise" then
		next_.mode = "Aiming"
		next_.blend = 0.5 -- half way up: the swing's own middle, which is where a mid keyframe goes
		next_.openTilt = 0
	elseif hold == "aim" then
		next_.mode = "Aiming"
		next_.blend = 1
		next_.openTilt = 0
	elseif hold == "reload" then
		next_.mode = "Third"
		next_.blend = 0
		next_.openTilt = 1
	else
		return state
	end
	return table.freeze(next_)
end

-- THE RELOAD A HELD "reload" POSE DRAWS: a gun that fired both barrels and is open with neither
-- chamber fed yet, which is the frame `TARGET-reload-open.jpg` of the reference video shows. nil for
-- every other hold, so the weapon's own replica is what the viewmodel is told (`Camera.update`).
function Poses.holdReload(hold: string?)
	if hold ~= "reload" then
		return nil
	end
	-- BOTH CHAMBERS FED, so the held frame is the one worth photographing: the barrels down on the
	-- pin with two fresh shells seated in the bores. With them empty the hold showed an open gun
	-- and nothing else -- the spent pair had already finished ejecting by the time the capture
	-- was taken (`SHELL_EJECT_SECONDS` is 0.35 and the hold settles for a second).
	return { open = true, spent = 2, loaded = { true, true } }
end

return Poses
