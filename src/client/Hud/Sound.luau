--!strict
-- Hud.Sound: THE ONE WRITER of the Hud's own 2-D feedback sounds (CLAUDE.md rule 3).
--
-- Today that is one cue: the soft tick that goes with the hit marker. Karen, 2026-10-05: *"we need to
-- indicate a hit"* -- and a marker you only see if you were already looking at the middle of the
-- screen is half an indicator.
--
-- LOCAL ONLY, AND AT THE EAR, verbatim the rule `src/client/Weapon/Sound.luau` already states: no
-- parent part, so it is not positional. The marker is the shooter's alone -- the weapon fires
-- `HitMarker` to ONE client -- and so is this.
--
-- AN EMPTY ID PLAYS NOTHING AND IS NOT AN ERROR, which is the same rule again (`Config.SOUND_SHOT_ID`:
-- "a gun that is silent is the gun this repo has had all along; a warn per shot would be worse than
-- the silence"). The two ids are Karen's to pick and sit beside the marker's other numbers in
-- `Shotgun.CONFIG`.
--
-- Design: docs/design/drive-report.md (section 4.1)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Sound = {}

local played = { hit = 0, kill = 0, silent = 0 }

-- So a spec can hear what was asked for without a speaker -- the same seam `Weapon.Sound.stats` is.
function Sound.stats()
	return table.clone(played)
end

function Sound.resetStats()
	played = { hit = 0, kill = 0, silent = 0 }
end

-- WHICH ID A MARKER KIND ASKS FOR. Pure and exported, so the mapping is assertable without a speaker
-- and without a wire.
function Sound.idFor(kind: string?, config): string
	if kind == "kill" then
		return tostring(config.HIT_MARK_KILL_SOUND_ID or "")
	end
	return tostring(config.HIT_MARK_SOUND_ID or "")
end

-- Called by `Hud.showHitMark`, which is the one writer of the marker, so the picture and the tick
-- cannot disagree about what happened.
function Sound.tick(kind: string?)
	local config = Shotgun.CONFIG
	local id = Sound.idFor(kind, config)
	if id == "" then
		-- COUNTED, NOT WARNED. A silent cue is the state this repo ships in until Karen picks a
		-- sample, and a count is how a spec proves the path ran at all.
		played.silent += 1
		return false
	end
	local sound = Instance.new("Sound")
	-- A BARE NUMBER IS AN ASSET ID; ANYTHING WITH A SCHEME IS ALREADY A URI. The two ids this repo
	-- ships are `rbxasset://sounds/...` -- engine assets, not Marketplace uploads -- and gluing
	-- "rbxassetid://" in front of one would make a path that resolves to nothing and plays silence
	-- with no error, which is the worst of the three possible outcomes.
	sound.SoundId = if string.find(id, "://", 1, true) then id else "rbxassetid://" .. id
	sound.Volume = config.HIT_MARK_VOLUME or 0.35
	sound.Parent = SoundService
	sound:Play()
	-- The same clean-up `Weapon.Sound` uses: a one-shot that removes itself rather than a pool
	-- nothing owns.
	Debris:AddItem(sound, 3)
	if kind == "kill" then
		played.kill += 1
	else
		played.hit += 1
	end
	return true
end

return Sound
