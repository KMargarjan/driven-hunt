--!strict
-- Hud.Sound: THE ONE WRITER of the Hud's own 2-D feedback sounds (CLAUDE.md rule 3).
--
-- TWO CUES NOW. The soft tick that goes with the hit marker (Karen, 2026-10-05: *"we need to
-- indicate a hit"* -- and a marker you only see if you were already looking at the middle of the
-- screen is half an indicator), and THE DRIVE'S OWN HORN SIGNAL at the start and the end of a drive
-- (Karen, 2026-10-12: *"when hunt starts 3 longer horn calls and when ends the same"*).
--
-- WHY THE DRIVE'S SIGNAL IS DRAWN FROM HERE AND NOT FROM THE SERVER. A sound every player hears at
-- the same moment can be made two ways: one Instance in the world that everybody is near, or one
-- Instance per client at its own ear. The second is what a signal IS -- nobody is "near" the start
-- of a drive -- and it is also the only one with a single writer: `Weapon.Horn` already owns the
-- positional blast that hangs on a beater's Tool, so a second server-side horn would be a second
-- writer of the same voice. The SERVER says WHEN (`Match.Phase` emits one `signal` feed entry at GO
-- and one at the end) and this module says WHAT IT SOUNDS LIKE, out of `Horn.CONFIG.SIGNAL`.
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

local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Sound = {}

-- THE ONE DRIVE-SIGNAL SOUND, made once and reused for the life of the client. One Instance, because
-- the asset is 60 s long: a fresh Sound per note would have to load it again and the first note of a
-- drive would miss its cue.
local SIGNAL_NAME = "DriveSignal"
local signalSound: Sound? = nil
-- IS A SIGNAL SOUNDING RIGHT NOW. It is what makes "exactly once per cue" true on this side as well
-- as on the server's: a second entry arriving mid-signal is refused and counted rather than played
-- over the first, which would read as a louder horn and not as a second signal.
local signalling = false
local lastSignal: string? = nil

local played = { hit = 0, kill = 0, silent = 0, signal = 0, signalBusy = 0 }

-- So a spec can hear what was asked for without a speaker -- the same seam `Weapon.Sound.stats` is.
function Sound.stats()
	return table.clone(played)
end

function Sound.resetStats()
	played = { hit = 0, kill = 0, silent = 0, signal = 0, signalBusy = 0 }
end

-- WHICH SIGNAL WAS LAST ASKED FOR ("start" or "end"), so a spec can prove the word came through the
-- wire rather than only that something sounded.
function Sound.lastSignal(): string?
	return lastSignal
end

-- IS A SIGNAL SOUNDING. Exported for the same reason: the refusal above is a rule, not an accident.
function Sound.isSignalling(): boolean
	return signalling
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

-- THE DRIVE'S HORN: three long notes at the start of a drive and three at its end (task 163).
--
-- `which` is the server's word, "start" or "end", and TODAY THE TWO SOUND THE SAME -- which is
-- Karen's sentence taken literally (*"when ends the same"*). It is carried and recorded anyway,
-- because the day the two differ is a change to `Horn.CONFIG.SIGNAL` and not to this wire.
--
-- THE SCHEDULE IS NOT HERE. `Horn.signalPlan` is pure and says "note, gap, note, gap, note"; this
-- walks it. So "three notes 2.94 s long, 0.2 s apart" is one statement in the data file, assertable
-- with no sound at all, and the only thing this function decides is the ONE thread it runs on.
function Sound.driveSignal(which: string?): boolean
	local config = Horn.CONFIG
	-- ALREADY SOUNDING: refused, counted, not stacked (see `signalling`).
	if signalling then
		played.signalBusy += 1
		return false
	end
	local id = tostring(config.SOUND_ID or "")
	local plan = Horn.signalPlan(config)
	if id == "" or #plan == 0 then
		-- COUNTED, NOT WARNED -- the same rule as the tick above.
		played.silent += 1
		return false
	end
	signalling = true
	lastSignal = which
	played.signal += 1

	local sound = signalSound
	if sound == nil or sound.Parent == nil then
		sound = Instance.new("Sound")
		sound.Name = SIGNAL_NAME
		-- A BARE NUMBER IS AN ASSET ID; ANYTHING WITH A SCHEME IS ALREADY A URI (`Sound.tick`'s own
		-- rule, which is there because a glued-on prefix plays silence with no error).
		sound.SoundId = if string.find(id, "://", 1, true) then id else "rbxassetid://" .. id
		-- NO PARENT PART, SO IT IS NOT POSITIONAL: at the ear, like every other cue in this module.
		sound.Parent = SoundService
		signalSound = sound
	end
	local voice = sound :: Sound
	voice.Volume = config.SIGNAL.VOLUME

	task.spawn(function()
		-- THE FIRST SIGNAL OF A SESSION MAY ARRIVE BEFORE THE ASSET HAS LOADED, and TimePosition on
		-- an unloaded Sound is not kept -- which would play the clip from 0, where the eight SHORT
		-- notes are. Waiting is bounded and the signal is sounded either way: a late horn is better
		-- than the wrong horn, and a horn that never loads must not leave `signalling` stuck true.
		local waited = os.clock()
		while not voice.IsLoaded and os.clock() - waited < 2 do
			task.wait(0.05)
		end
		for index, note in ipairs(plan) do
			if index > 1 then
				task.wait(config.SIGNAL.GAP)
			end
			-- FROM `START` EVERY NOTE, so each note is the same note and not the tail of the one
			-- before -- `Weapon.Horn.blowTool`'s rule, for its reason.
			voice.TimePosition = config.SIGNAL.START
			voice:Play()
			task.wait(note.seconds)
			voice:Stop()
		end
		signalling = false
	end)
	return true
end

return Sound
