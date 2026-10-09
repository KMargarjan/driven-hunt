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
-- THE IDS ARE CONFIGURATION AND THE VOLUMES ARE DATA. `Camera.Config.SOUND_*` holds the asset ids,
-- because an id is not a number and `tools/pose.py` tunes numbers; `fire.volume` in `poses.json`
-- holds the three volumes, so the Director can balance them live while listening. AN EMPTY ID PLAYS NOTHING
-- and is not an error: see `Config.SOUND_SHOT_ID`.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Sound = {}

local played = { shot = 0, open = 0, close = 0, bolt = 0, magazine = 0 }

-- So a spec can hear what was asked for without a speaker.
function Sound.stats()
	return table.clone(played)
end

function Sound.resetStats()
	played = { shot = 0, open = 0, close = 0, bolt = 0, magazine = 0 }
end

-- WHICH SOUND THIS WEAPON MAKES FOR THIS EVENT, and nil when it has nothing of its own (task 142).
-- A row's `SOUND` block beats the camera config's single id, which is what every caller before the
-- rifle used and what the shotgun still uses: one id for the whole game was exactly the bug Karen
-- heard -- *"for rifle has to be another gun fire sound"*.
function Sound.voiceFor(row: any?, kind: string): any?
	if row == nil or row.SOUND == nil then
		return nil
	end
	return row.SOUND[kind]
end

-- A SAMPLE FROM A LIBRARY IS A TAKE, NOT A ROUND (task 142): see `Rifle.CONFIG.SOUND`. `cut` is how
-- many seconds of it to play and `fade` is how much of that is spent going quiet, so one crack and
-- its tail comes out of a three-second clip of a man emptying a magazine into a hillside.
local function cutAfter(made: Sound, cut: number?, fade: number?)
	if cut == nil or cut <= 0 then
		return
	end
	local full = made.Volume
	local fadeFor = math.clamp(fade or 0, 0, cut)
	task.delay(cut - fadeFor, function()
		if made.Parent == nil then
			return
		end
		local started = os.clock()
		while fadeFor > 0 and made.Parent ~= nil do
			local t = (os.clock() - started) / fadeFor
			if t >= 1 then
				break
			end
			made.Volume = full * (1 - t)
			task.wait()
		end
		if made.Parent ~= nil then
			made:Stop()
			made:Destroy()
		end
	end)
end

local function play(kind: string, config, id: string?, volume: number?, voice: any?): boolean
	-- NO CONFIG, NO SOUND. Task 112 asked the gun flag here as well, which kept the two clicks
	-- off the gun Karen was playing while it was still flagged; the flag retired with that gun in
	-- task 114, and what is left is the honest check -- a caller with no resolved config has no
	-- volumes either, because the three of them are `fire.volume` in `poses.json`.
	if config == nil then
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
	if voice ~= nil and voice.pitch ~= nil then
		made.PlaybackSpeed = voice.pitch
	end
	made.Parent = SoundService
	made:Play()
	if voice ~= nil then
		cutAfter(made, voice.cut, voice.fade)
	end
	Debris:AddItem(made, 8)
	return true
end

-- The three things the gun does that make a noise. `config` is the resolved camera config, so the
-- volumes come from `poses.json` and change on the next shot while a session runs.
-- `row` IS THE WEAPON (task 142) and is optional: a caller that does not pass one gets the camera
-- config's single id, which is what the shotgun has always used.
function Sound.shot(config, row: any?): boolean
	local volume = config ~= nil and config.FIRE ~= nil and config.FIRE.volume or nil
	local voice = Sound.voiceFor(row, "shot")
	local id = if voice ~= nil then voice.id else (config and config.SOUND_SHOT_ID)
	return play("shot", config, id, volume and volume.shot, voice)
end

-- THE BOLT AND THE MAGAZINE (task 142), which only a weapon that has them ever asks for. A row with
-- no voice for one plays nothing, and that is not an error -- the rule `SOUND_SHOT_ID` set.
function Sound.bolt(config, row: any?): boolean
	local volume = config ~= nil and config.FIRE ~= nil and config.FIRE.volume or nil
	local voice = Sound.voiceFor(row, "bolt")
	return play("bolt", config, voice and voice.id, volume and volume.open, voice)
end

function Sound.magazine(config, row: any?): boolean
	local volume = config ~= nil and config.FIRE ~= nil and config.FIRE.volume or nil
	local voice = Sound.voiceFor(row, "magazine")
	return play("magazine", config, voice and voice.id, volume and volume.close, voice)
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
