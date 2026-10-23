--!strict
-- Ambience (client): THE ONE WRITER of the game's ambience beds and of their `Volume`
-- (CLAUDE.md rule 3).
--
-- KAREN, 2026-10-23, verbatim: *"any lobby music, like birds relax quuiet ?"*. At the lodge: quiet
-- birdsong and a soft wind, calmer and quieter than the hunt, crossfading when you leave for the
-- drive and when you come back.
--
-- LOCAL ONLY, AND AT THE EAR, verbatim the rule `src/client/Weapon/Sound.luau` and
-- `src/client/Hud/Sound.luau` both state in their own headers: no parent part, so a bed is NOT
-- positional. A bed every player hears is one Instance per client at that client's own ear, never
-- one Instance in the world everybody happens to be near -- and that is also the only shape with a
-- single writer.
--
-- WHY THIS IS ITS OWN MODULE AND NOT A THIRD VOICE CLASS INSIDE `Hud.Sound` (design section 3.1):
-- that module's own header scopes it to *"the Hud's own 2-D feedback sounds"* and a bed is not
-- feedback -- nothing happened. It would also couple the ear to the screen (`Hud.start` builds a
-- whole `ScreenGui` first), it has no clock of its own where a crossfade is a per-frame stepper, and
-- it sets `Volume` ONCE at creation where this writes it every frame. One module with both rules is
-- one module where *"who last wrote this Sound's Volume"* has two answers.
--
-- WHAT IT IS NOT ALLOWED TO TOUCH, and both are owner boundaries rather than oversights:
--   * `SoundService.AmbientReverb` and `SoundService.Volume`. Nothing in `src/` writes a
--     `SoundService` property today and this module must not be the first: those are GLOBAL answers,
--     so a bed that set them would change the gun, the boar, the horn and the bugle, and "how loud
--     is the game" would have a writer that thinks it is only the lodge's birds.
--   * `Workspace.Ambience`. That is Karen's own STUDIO-MADE Sound in the Forest Test
--     (`rbxassetid://4629533497`, `Volume 0.50`, looped, measured 2026-10-23), in a container Rojo
--     does not own and which nothing in git names. Writing it would make this repository a second
--     writer of an instance a Connect cannot restore. It has no owner in git and the design records
--     that as a hole rather than filling it (section 12, D2).
--
-- THE ONE FACT IT READS IS `Players.LocalPlayer.Team`, at ONE boundary (`refresh`). A player at the
-- lodge has no team, and that is not an inference about the lodge -- it is what "not in the drive"
-- means everywhere in this repo (`Match.myTeam`'s own rule: *"the team is one fact with one
-- representation, and the engine replicates it"*; `Hud.Objective`'s lobby branch; and
-- `ForestTestBoot`'s respawn path). The signal is the same one `Hud` already uses for the compass.
--
-- NOBODY HERE CAN HEAR IT. The Builder cannot play audio. `ready`, `gains`, `targets`, `voices` and
-- `stats` exist so a spec can read what reached the engine without a speaker -- verbatim the seam
-- `Hud.Sound.stats` is, for the reason that module's header gives -- and **KAREN'S EARS DECIDE**.
--
-- Design: docs/design/ambience.md (sections 3, 4, 5, 6.2)
-- Note:   docs/research/2026-10-23-ambience-and-money-fines.md
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = require(ReplicatedStorage:WaitForChild("Ambience"))

local Ambience = {}

-- Re-exported so a caller needs one require. NOT a copy: it is the same frozen table.
Ambience.Shared = Shared
Ambience.CONFIG = Shared.CONFIG

-- ---------------------------------------------------------------- the whole state
--
-- THREE TABLES AND A WORD, and that is all of it. `gains` is where each bed is; `targets` is where
-- it is going; `voices` are the Instances. There is no "is it playing", no "is it fading", no tween
-- and no latch -- which is what makes a flip mid-fade a pure retarget (design section 5.3).
local gains: { [string]: number } = {}
local targets: { [string]: number } = {}
local voices: { [string]: { Sound } } = {}
local bedWord = Shared.DEFAULT_BED

local stats = { applied = 0, silent = 0, stepped = 0, arrived = 0 }

-- WERE THE VOICES MADE AT MODULE LOAD? A fact about load time, recorded so a spec can assert it
-- after the fact -- the shape `Hud.Sound`'s `madeAtLoad` has, and for its reason: once a cue has
-- happened, "they existed before it" is otherwise unprovable.
local madeAtLoad = false
local preloaded = false

local started = false
local heartbeat: RBXScriptConnection? = nil
local teamChanged: RBXScriptConnection? = nil

-- ---------------------------------------------------------------- the voices, made once at load
--
-- EVERY VOICE WITH A NON-EMPTY ID IS `Play()`ED ONCE, AT LOAD, AT `Volume = 0`, AND IS NEVER
-- STOPPED for the rest of the session. `Play()` on a stopped Sound restarts it at the region's
-- start, so a stop-on-silent rule would put an audible restart at the far end of every crossfade --
-- and "is it playing" would be a second place the truth lives. With this rule THE GAIN IS THE WHOLE
-- TRUTH and `Volume` is a function of it.
--
-- The cost is two silent looped streams during a drive, which is nothing; the consequence Karen will
-- notice is that a joining player's lodge bed fades in from silence over `FADE_SECONDS` rather than
-- being already there (design K5). One rule, no join special case.
local function makeVoice(bed: string, voice: Shared.Voice): Sound?
	if type(voice.ID) ~= "string" or voice.ID == "" then
		-- NOT AN ERROR, and the hunt bed ships this way on purpose. The standing rule, with its
		-- reason, at `src/client/Weapon/Sound.luau`'s `play`.
		stats.silent += 1
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = Shared.voiceName(bed, voice)
	sound.SoundId = voice.ID
	sound.Volume = 0
	sound.Looped = true
	local from, to = Shared.loopWindow(voice)
	-- A MEASURED WINDOW, THE ENGINE'S OWN WAY. `PlaybackRegion` plus `LoopRegion`, borrowed from
	-- `src/server/Lobby/Build.luau`'s `engineSound` with the reason written beside it there -- *"the
	-- alternative, `TimePosition` with a `Looped` sound, replays from zero"*. A row with `TO == 0`
	-- gets no region at all and loops the whole clip.
	--   https://create.roblox.com/docs/reference/engine/classes/Sound#PlaybackRegion
	if voice.TO > 0 and to > from then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(from, to)
		sound.LoopRegion = NumberRange.new(from, to)
	end
	sound.Parent = SoundService
	sound:Play()
	return sound
end

local function build()
	local urls: { Sound } = {}
	for _, word in ipairs(Shared.BED_WORDS) do
		gains[word] = 0
		targets[word] = if word == Shared.DEFAULT_BED then 1 else 0
		local made: { Sound } = {}
		local bed = Shared.CONFIG.BEDS[word]
		if bed ~= nil then
			for _, voice in ipairs(bed.VOICES) do
				local sound = makeVoice(word, voice)
				if sound ~= nil then
					table.insert(made, sound)
					table.insert(urls, sound)
				end
			end
		end
		voices[word] = made
	end
	madeAtLoad = true
	-- ASKED FOR AT MODULE LOAD, IN ONE CALL, IN ITS OWN THREAD, INSIDE A `pcall` -- which is task
	-- 163a(a)'s fix applied before it can bite: a Sound created at the cue only STARTS its download
	-- then. Here the assets have the whole of the client's boot to arrive.
	--   https://create.roblox.com/docs/reference/engine/classes/ContentProvider#PreloadAsync
	if #urls > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(urls)
			end)
			preloaded = true
		end)
	else
		preloaded = true
	end
end

build()

-- ---------------------------------------------------------------- the state machine

-- THE ONE WRITER OF `targets`. It writes NOTHING else: the gains keep their current values, so the
-- next `step` reverses direction from where the fade had got to. There is no cancel, no tween to
-- destroy and no edge to miss, and the gains are continuous across any number of flips.
function Ambience.applyTeam(team: string?)
	bedWord = Shared.bedFor(team)
	targets = Shared.targetsFor(bedWord)
	stats.applied += 1
end

-- THE ONE WRITER OF `gains` AND OF EVERY BED SOUND'S `Volume`. One pass, no table allocated, at
-- most four `Volume` writes.
--
-- `arrived` COUNTS A COMPLETED FADE EXACTLY ONCE -- it is incremented on the step that MOVES a gain
-- onto its target, never on the steps that sit there afterwards -- so "the crossfade finished" is a
-- number and not a sleep.
function Ambience.step(dt: number)
	stats.stepped += 1
	for _, word in ipairs(Shared.BED_WORDS) do
		local was = gains[word] or 0
		local target = targets[word] or 0
		local now = Shared.stepGain(was, target, dt, Shared.CONFIG.FADE_SECONDS)
		if now ~= was then
			gains[word] = now
			if now == target then
				stats.arrived += 1
			end
			local level = voices[word]
			if level ~= nil then
				local bed = Shared.CONFIG.BEDS[word]
				for index, sound in ipairs(level) do
					-- The Instances are made in row order and only for non-empty rows, so a bed with
					-- one silent row of two has its surviving Sound at index 1 and the row it came
					-- from is found the same way. `rowFor` keeps that correspondence in one place.
					local voice = Ambience.rowFor(bed, sound)
					if voice ~= nil then
						sound.Volume = Shared.volumeFor(now, voice.LEVEL)
					else
						-- UNREACHABLE unless a row's `WHAT` changed under a live Sound, and it is
						-- counted rather than silently skipped: a bed that stopped responding to the
						-- crossfade must be a number in the report.
						local _ = index
						stats.silent += 1
					end
				end
			end
		end
	end
end

-- WHICH ROW A LIVE `Sound` CAME FROM, by the NAME this system itself gave it -- so the mapping is
-- the one `Shared.voiceName` defines and not an index two lists have to keep in step.
function Ambience.rowFor(bed: any?, sound: Sound): Shared.Voice?
	if type(bed) ~= "table" then
		return nil
	end
	for _, voice in ipairs(bed.VOICES) do
		if Shared.voiceName(bed.WORD, voice) == sound.Name then
			return voice
		end
	end
	return nil
end

-- ---------------------------------------------------------------- the boundary, and the clock

-- THE ONE PLACE THE WORLD IS READ. `Player.Team` and nothing else: no position, no lodge model, no
-- snapshot, no `WaitForChild` on another system.
local function refresh()
	local player = Players.LocalPlayer
	local team = if player ~= nil then player.Team else nil
	Ambience.applyTeam(if team ~= nil then team.Name else nil)
end

-- IDEMPOTENT, the `Match.start` shape: a second call connects nothing twice. It does NOT rebuild the
-- voices and does not reset the gains -- those are module-load facts and a session-long fade.
function Ambience.start()
	if started then
		return
	end
	started = true
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		Ambience.step(dt)
	end)
	local player = Players.LocalPlayer
	if player ~= nil then
		teamChanged = player:GetPropertyChangedSignal("Team"):Connect(refresh)
	end
	refresh()
end

-- Disconnects both and leaves `gains`, `targets` and the Instances exactly where they are, so a spec
-- can take the clock over and then hand it back (`tests/client/ambience_client.spec.luau`).
function Ambience.stop()
	if heartbeat ~= nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if teamChanged ~= nil then
		teamChanged:Disconnect()
		teamChanged = nil
	end
	started = false
end

-- ---------------------------------------------------------------- what a spec may read

function Ambience.gains(): { [string]: number }
	return table.clone(gains)
end

function Ambience.targets(): { [string]: number }
	return table.clone(targets)
end

function Ambience.bed(): string
	return bedWord
end

function Ambience.voices(bed: string): { Sound }
	return table.clone(voices[bed] or {})
end

-- madeAtLoad, preloaded. The second says the REQUEST finished, not that it succeeded:
-- `Sound.IsLoaded` is the fact that matters and the spec asks for that separately.
function Ambience.ready(): (boolean, boolean)
	return madeAtLoad, preloaded
end

function Ambience.running(): boolean
	return started
end

function Ambience.stats(): { [string]: number }
	return table.clone(stats)
end

function Ambience.resetStats()
	stats = { applied = 0, silent = 0, stepped = 0, arrived = 0 }
end

return Ambience
