--!strict
-- Weapon.Sound: THE ONE WRITER of the gun's sounds for the local player (CLAUDE.md rule 3).
--
-- Karen's order, 2026-10-02: finish the weapon before the animal, and shooting is next. A shot with
-- no sound does not read as a shot however good the flash is, so this is the third leg of task 112
-- beside the kick and the smoke.
--
-- LOCAL ONLY, AND AT THE EAR. Every sound here is played for the player who did the thing, with no
-- parent part, so it is not positional: the gun is two studs from the eye and a 3D sound at that
-- range is just a loud one. Other players hearing each other's shots is a server-side system that
-- does not exist yet and is not this task.
--
-- BEHIND `NEW_GUN`, like the rest of task 112: `play` refuses unless the config says so, so the gun
-- Karen has been playing makes exactly the noises it always has (none).
--
-- THE IDS ARE CONFIGURATION AND THE VOLUMES ARE DATA. `Camera.Config.SOUND_*` holds the asset ids,
-- because an id is not a number and `tools/pose.py` tunes numbers; `newGun.fire.volume` holds the
-- three volumes, so the Director can balance them live while listening. AN EMPTY ID PLAYS NOTHING
-- and is not an error: see `Config.SOUND_SHOT_ID`.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Sound = {}

local played = { shot = 0, open = 0, close = 0 }

-- So a spec can hear what was asked for without a speaker.
function Sound.stats()
	return table.clone(played)
end

function Sound.resetStats()
	played = { shot = 0, open = 0, close = 0 }
end

local function play(kind: string, config, id: string?, volume: number?): boolean
	-- BEHIND `NEW_GUN` WITH THE REST OF TASK 112 (round 1, finding 3). Without this the two clicks
	-- shipped ON, unflagged, on the gun Karen plays -- a feel-critical path that CLAUDE.md says is
	-- born OFF -- and at a volume no data could reach, because only `newGun.fire` carries a `volume`
	-- block. One guard fixes both: the old gun is silent exactly as it has always been.
	if config == nil or config.NEW_GUN ~= true then
		return false
	end
	played[kind] = (played[kind] or 0) + 1
	if type(id) ~= "string" or id == "" then
		-- NOT AN ERROR. The shot id is empty until Karen picks one, and a gun that is silent is the
		-- gun this repo has had all along; a warn per shot would be worse than the silence.
		return false
	end
	local made = Instance.new("Sound")
	made.SoundId = id
	made.Volume = volume or 0.5
	made.Parent = SoundService
	made:Play()
	Debris:AddItem(made, 8)
	return true
end

-- The three things the gun does that make a noise. `config` is the resolved camera config, so the
-- volumes come from `poses.json` and change on the next shot while a session runs.
function Sound.shot(config): boolean
	local volume = config ~= nil and config.FIRE ~= nil and config.FIRE.volume or nil
	return play("shot", config, config and config.SOUND_SHOT_ID, volume and volume.shot)
end

function Sound.open(config): boolean
	local volume = config ~= nil and config.FIRE ~= nil and config.FIRE.volume or nil
	return play("open", config, config and config.SOUND_OPEN_ID, volume and volume.open)
end

function Sound.close(config): boolean
	local volume = config ~= nil and config.FIRE ~= nil and config.FIRE.volume or nil
	return play("close", config, config and config.SOUND_CLOSE_ID, volume and volume.close)
end

return Sound
