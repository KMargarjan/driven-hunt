--!strict
-- Hud.Sound: THE ONE WRITER of the Hud's own 2-D feedback sounds (CLAUDE.md rule 3).
--
-- TWO CUES NOW. The soft tick that goes with the hit marker (Karen, 2026-10-05: *"we need to
-- indicate a hit"* -- and a marker you only see if you were already looking at the middle of the
-- screen is half an indicator), and THE DRIVE'S OWN HORN SIGNAL at the start and the end of a drive
-- (Karen, 2026-10-12: *"when hunt starts 3 longer horn calls and when ends the same"*, and then,
-- having heard it: *"for start and end of drive has to be tuturutu tu tu different one"* -- so the
-- signal is a BUGLE FANFARE out of the free library and no longer three long notes of the beater's
-- own horn. Task 166; every number and the measurement behind it is in `Horn.CONFIG.SIGNAL`).
--
-- TWO VOICES, ONE PER CUE, because the two cues are now two different assets. They are made and
-- preloaded at module load for the reason task 163a(a) measured, and they are kept in a table keyed
-- by the server's own word rather than in two variables, so the word is looked up and never branched
-- on (`Horn.signalWords` is the list).
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
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Sound = {}

-- THE DRIVE-SIGNAL VOICES, MADE AT MODULE LOAD AND PRELOADED THERE (task 163a(a); the Reviewer
-- found it, and it is the one note of that review with a consequence Karen would HEAR).
--
-- ONE INSTANCE PER CUE, KEPT, rather than a fresh Sound per sounding: the fix of 163a(a) is that a
-- Sound created at the cue only STARTS its download then, and `TimePosition` on an unloaded Sound is
-- not kept -- so a lost race plays the clip from 0. For task 163's 60 s recording that meant the
-- eight short notes instead of the long one; for task 166's 4 s bugle call it would mean the phrase
-- plus its lead-in silence, cut off in the middle. Either way the FIRST signal of a session is the
-- one Karen hears first.
--
-- Made here, the assets have the whole of the client's boot and the drive's countdown to arrive
-- instead of two seconds, and `ContentProvider:PreloadAsync` asks for both of them immediately.
--   https://create.roblox.com/docs/reference/engine/classes/ContentProvider#PreloadAsync
-- The bounded `IsLoaded` wait in `driveSignal` stays as the backstop, and is expected to pass on its
-- first look.
local SIGNAL_NAME = "DriveSignal"
-- KEYED BY THE SERVER'S OWN WORD ("start" / "end"), so this module looks a voice up and never
-- branches on which cue it is. The two are separate Instances even when two rows name one asset: a
-- Sound is cheap, and one Instance shared by two cues would make "a signal is already sounding" a
-- property of the Instance as well as of `signalling`.
local voices: { [string]: Sound } = {}
-- WERE THE VOICES MADE AT MODULE LOAD? A fact about load time, recorded so a spec can assert it
-- after the fact -- "they existed and were configured BEFORE the first cue" is otherwise unprovable
-- once a cue has happened. True only if EVERY word got one.
local madeAtLoad = false
-- HAS THE PRELOAD RETURNED? `PreloadAsync` yields, so it runs in its own thread and this is how a
-- spec waits for it. It says the request FINISHED, not that it succeeded: `Sound.IsLoaded` is the
-- fact that matters and the spec asks for that too.
local preloaded = false
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

-- ONE CUE'S VOICE, so a spec can read the Instance this module configured rather than hunt for it by
-- name in SoundService. The word is optional and defaults to the drive's first cue.
function Sound.signalVoice(which: string?): Sound?
	return voices[which or Horn.SIGNAL_DEFAULT]
end

-- WAS IT MADE AT MODULE LOAD, and has its preload returned (task 163a(a))? Both are facts about
-- what happened BEFORE any cue, which is the whole point of the fix.
function Sound.signalReady(): (boolean, boolean)
	return madeAtLoad, preloaded
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

-- ONE CUE'S VOICE, BUILT. Factored out because two callers need it: module load (the normal one)
-- and `driveSignal`'s guard against something having destroyed it. An empty id makes NO Sound and is
-- not an error -- the same rule as the tick's.
local function makeSignalVoice(which: string): Sound?
	local phrase = Horn.signalPhrase(which, Horn.CONFIG)
	local id = tostring(phrase.SOUND_ID or "")
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = SIGNAL_NAME .. "_" .. which
	-- A BARE NUMBER IS AN ASSET ID; ANYTHING WITH A SCHEME IS ALREADY A URI (`Sound.tick`'s own
	-- rule, which is there because a glued-on prefix plays silence with no error).
	sound.SoundId = if string.find(id, "://", 1, true) then id else "rbxassetid://" .. id
	sound.Volume = Horn.CONFIG.SIGNAL.VOLUME
	sound.Looped = false
	-- NO PARENT PART, SO IT IS NOT POSITIONAL: at the ear, like every other cue in this module.
	sound.Parent = SoundService
	voices[which] = sound
	return sound
end

-- THE DRIVE'S HORN: a bugle fanfare at the start of a drive and another at its end (task 166).
--
-- `which` is the server's word, "start" or "end", and SINCE TASK 166 THE TWO REALLY DIFFER: two
-- phrases out of two assets, looked up in `Horn.CONFIG.SIGNAL.PHRASES` by that word. An unknown word
-- gets the start phrase rather than silence, and that decision is the data's
-- (`Horn.signalPhrase`), not this function's.
--
-- THE SCHEDULE IS NOT HERE. `Horn.signalPlan` is pure and says "this cut of this asset, this long,
-- at this offset from the cue"; this walks it. So the whole of what a signal IS lives in the data
-- file, assertable with no sound at all, and the only thing this function decides is the ONE thread
-- it runs on.
function Sound.driveSignal(which: string?): boolean
	local config = Horn.CONFIG
	-- ALREADY SOUNDING: refused, counted, not stacked (see `signalling`).
	if signalling then
		played.signalBusy += 1
		return false
	end
	local word = if which ~= nil and config.SIGNAL.PHRASES[which] ~= nil then which else Horn.SIGNAL_DEFAULT
	local plan = Horn.signalPlan(word, config)
	if #plan == 0 or tostring(plan[1].soundId or "") == "" then
		-- COUNTED, NOT WARNED -- the same rule as the tick above.
		played.silent += 1
		return false
	end
	signalling = true
	-- THE WORD THAT WAS SOUNDED, NOT THE WORD THAT WAS ASKED FOR (round 1's note): an unknown cue
	-- sounds the start phrase, and recording the raw word would have `lastSignal` naming a phrase
	-- nobody heard.
	lastSignal = word
	played.signal += 1

	-- NORMALLY THIS IS THE VOICE MADE AT MODULE LOAD, loaded long before the first cue. It is
	-- re-made only if something has destroyed it, so the loaded asset is never thrown away -- and
	-- the branch is not taken in an ordinary session.
	local sound = voices[word]
	if sound == nil or sound.Parent == nil then
		sound = makeSignalVoice(word)
		if sound == nil then
			signalling = false
			played.signal -= 1
			played.silent += 1
			return false
		end
	end
	local voice = sound :: Sound
	voice.Volume = config.SIGNAL.VOLUME

	task.spawn(function()
		-- THE BACKSTOP, and since task 163a(a) it is only that: the voice was made and preloaded at
		-- module load, so by the first cue `IsLoaded` is already true and this falls through on its
		-- first look. It stays because `TimePosition` on an unloaded Sound is not kept -- which
		-- would play the clip from 0, where this asset's own lead-in silence is. Waiting is bounded
		-- and the signal is sounded either way: a late horn is better than the wrong horn, and a
		-- horn that never loads must not leave `signalling` stuck true.
		local waited = os.clock()
		while not voice.IsLoaded and os.clock() - waited < 2 do
			task.wait(0.05)
		end
		for index, note in ipairs(plan) do
			if index > 1 then
				task.wait(note.at - (plan[index - 1].at + plan[index - 1].seconds))
			end
			-- FROM THE ROW'S OWN `from` EVERY TIME, so a sounding is the measured phrase and never
			-- the tail of the one before -- `Weapon.Horn.blowTool`'s rule, for its reason.
			voice.TimePosition = note.from
			voice:Play()
			task.wait(note.seconds)
			voice:Stop()
		end
		signalling = false
	end)
	return true
end

-- ---------------------------------------------------------------- at module load (task 163a(a))
--
-- MADE AND ASKED FOR NOW, so the first cue of a session plays the measured phrase and never the clip
-- from 0. `PreloadAsync` YIELDS, so it runs in its own thread: requiring this module must not block
-- on a download, and the Hud requires it while it is building itself.
--
-- ONE VOICE PER CUE WORD, and `madeAtLoad` is true only if every word got one -- so a config with a
-- missing id is visible to a spec instead of being discovered at the end of a drive.
local wanted = Horn.signalWords()
local made = 0
for _, word in ipairs(wanted) do
	if makeSignalVoice(word) ~= nil then
		made += 1
	end
end
madeAtLoad = made == #wanted and made > 0
if made > 0 then
	local list = {}
	for _, voice in pairs(voices) do
		table.insert(list, voice)
	end
	task.spawn(function()
		-- PROTECTED, because a content request can throw (no network, a moderated asset) and this
		-- thread is nobody's caller. A failure leaves `preloaded` true and `IsLoaded` false, which
		-- is exactly what the backstop in `driveSignal` is for.
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		preloaded = true
	end)
end

return Sound
