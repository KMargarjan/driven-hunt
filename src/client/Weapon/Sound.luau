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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

-- THE ONE ANSWER TO "WHAT DOES THIS LOAD DO TO THE SHOT" (task 204). The camera reads the same
-- function for the kick, so the gun cannot sound like a slug and kick like buckshot.
local Data = require(ReplicatedStorage:WaitForChild("Viewmodel"))

local Sound = {}

local played = { shot = 0, open = 0, close = 0, bolt = 0, magazine = 0, dry = 0 }
-- WHAT THE LAST SHOT ACTUALLY CAME OUT AT (task 204): the id, the resolved Volume and the resolved
-- PlaybackSpeed. A COUNT cannot tell a slug from buckshot -- both are one shot -- and Karen's
-- complaint is about the difference, so the difference is what a spec has to be able to read. It is
-- written where the `Sound` is built, from the very numbers handed to the engine, rather than
-- recomputed beside it.
local lastShot: { [string]: any } = {}

-- So a spec can hear what was asked for without a speaker.
function Sound.stats()
	return table.clone(played)
end

function Sound.lastShot()
	return table.clone(lastShot)
end

function Sound.resetStats()
	played = { shot = 0, open = 0, close = 0, bolt = 0, magazine = 0, dry = 0 }
	lastShot = {}
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

-- `pitch` IS THE PLAYBACK SPEED THE CALLER RESOLVED (task 204), and nil means "whatever the voice
-- says", which is every caller but the shot. One number, applied at the one site that builds the
-- `Sound`: a second place that set `PlaybackSpeed` would be a second answer to how deep the gun is.
local function play(kind: string, config, id: string?, volume: number?, voice: any?, pitch: number?): boolean
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
	local speed = pitch or (voice ~= nil and voice.pitch) or nil
	if speed ~= nil then
		made.PlaybackSpeed = speed
	end
	if kind == "shot" then
		lastShot = { id = id, volume = made.Volume, pitch = made.PlaybackSpeed }
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
-- `ammo` IS THE LOAD THAT WENT OFF (task 204). Karen, 2026-10-18: *"we need to change shooting sound
-- and power to shotgun when slugs and shells is used slugs are harder"*. A slug is LOUDER and
-- DEEPER, and both are one multiplier off `fire.loads` in `poses.json` -- the same block
-- `Camera.kick` scales its spring by, so the ear and the eye are told the same thing.
--
-- NO NEW SOUND WAS UPLOADED AND NONE WAS NEEDED. The dispatch allows a low-frequency layer "if the
-- game already has a suitable sound", and it does not: the other four voices are Studio's own
-- `switch`, `switch3` and `clickfast` wavs, which are mechanism clicks and not a boom. Dropping the
-- sample's `PlaybackSpeed` lowers its whole spectrum AND stretches it -- the shotgun's voice has no
-- `cut`, so the full report plays -- which is what a heavier charge sounds like.
function Sound.shot(config, row: any?, ammo: string?): boolean
	local volume = config ~= nil and config.FIRE ~= nil and config.FIRE.volume or nil
	local voice = Sound.voiceFor(row, "shot")
	local id = if voice ~= nil then voice.id else (config and config.SOUND_SHOT_ID)
	local load = Data.loadFor(config and config.FIRE, ammo)
	local base = volume and volume.shot
	-- THE VOICE'S OWN PITCH IS THE BASE, not 1: the rifle's sample is already played slow, and a
	-- load scale has to multiply what the weapon says rather than replace it.
	local pitch = ((voice ~= nil and voice.pitch) or 1) * load.pitchScale
	return play("shot", config, id, base and base * load.volumeScale, voice, pitch)
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

-- THE TRIGGER THAT DID NOTHING (task 171). The gun is loaded, closed and not busy, and the server
-- refused the shot -- a beater in the line, a hunter off his stand, a species with no licence -- so
-- what the player hears is the one sound that says "nothing happened": a dry click. The volume is
-- the OPEN click's, because it is the same class of noise and `fire.volume` has three entries, not
-- four; a fourth volume in `poses.json` would be a number nobody has balanced.
--
-- No `row` and no voice: this is not the gun speaking, it is the mechanism not speaking.
function Sound.dry(config): boolean
	local volume = config ~= nil and config.FIRE ~= nil and config.FIRE.volume or nil
	return play("dry", config, config and config.SOUND_DRY_ID, volume and volume.open)
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
