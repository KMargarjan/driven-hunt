--!strict
-- Ambience: THE BED'S DATA AND ITS PURE RULES. No Instance, no service, no state, no clock, no
-- writer at run time -- the discipline `ReplicatedStorage.Horn` and `ReplicatedStorage.Licences`
-- already keep (frozen data plus pure functions).
--
-- KAREN, 2026-10-23, verbatim: *"any lobby music, like birds relax quuiet ?"*. So at the lodge there
-- is quiet birdsong and a soft wind, calmer and quieter than the hunt, crossfading when you leave
-- for the drive and when you come back.
--
-- THE OWNER IS `StarterPlayerScripts.Ambience` AND IT IS THE ONLY WRITER OF A BED'S `Volume`. This
-- half exists so a SERVER spec can drive every branch of the state machine and every data invariant
-- with no client, no Sound and no clock -- the `ReplicatedStorage.Horn` + `Hud.Sound` split that
-- `zz_horn.spec` already exploits. See `docs/design/ambience.md` sections 3 and 3.2.
--
-- THERE WAS NO AMBIENCE OWNER IN THIS REPOSITORY BEFORE THIS TASK, and the dispatch's premise said
-- otherwise. Measured, 2026-10-23: the forest ambience Karen hears in the Forest Test is
-- `Workspace.Ambience`, `rbxassetid://4629533497`, `Volume 0.50`, `Looped`, playing, parented
-- straight to `Workspace` -- a STUDIO-MADE instance in a container Rojo does not own, which nothing
-- in git names. **This owner may not touch it** (design section 2, brief decision 4): writing its
-- `Volume` would make this repository a second writer of an instance a Connect cannot restore.
--
-- Pattern: the one-active-bed crossfade. Two looped beds, at most one rising and one falling, the
-- gain carried continuously across any number of flips -- id Tech 4's `idSoundWorld` ambient
-- fade and Wwise's "state" music transitions both do exactly this, and neither supplies numbers for
-- a 400-stud wood (the research note records that as a negative result).
--   https://create.roblox.com/docs/reference/engine/classes/Sound#PlaybackRegion
--   https://create.roblox.com/docs/reference/engine/classes/ContentProvider#PreloadAsync
--
-- NOBODY HERE CAN HEAR IT. The Builder cannot play audio. What is proved is what reaches the engine
-- -- the Sound exists, it loaded, it is playing, its id and its resolved `Volume` -- and **KAREN'S
-- EARS DECIDE** whether quiet birds and a soft wind at the lodge are *"relax quuiet"*.
--
-- Design: docs/design/ambience.md
-- Note:   docs/research/2026-10-23-ambience-and-money-fines.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Ambience = {}

export type Voice = {
	-- "rbxassetid://<n>", or "" for SILENT-AND-NOT-AN-ERROR. The standing rule, with its reason, at
	-- `src/client/Weapon/Sound.luau`'s `play`: *"a gun that is silent is the gun this repo has had
	-- all along; a warn per shot would be worse than the silence"*.
	ID: string,
	-- THIS LAYER'S OWN `Volume` AT FULL GAIN. `Sound.Volume` runs 0..10, and `volumeFor` multiplies
	-- the gain by this -- so the GAIN is where the bed is in the crossfade and the LEVEL is how loud
	-- that bed's layer is when it is all the way in. Two numbers, two jobs: one number could not
	-- express "half way into a quiet bed".
	LEVEL: number,
	FROM: number, -- loop window start, seconds
	TO: number, -- loop window end, seconds. 0 means "the whole clip, no region at all"
	CLIP_SECONDS: number, -- the asset's MEASURED TimeLength
	WHAT: string, -- "birds" / "wind": the layer's word, and the Instance's name suffix
}

export type Bed = { WORD: string, VOICES: { Voice } }

-- ---------------------------------------------------------------- the two beds
--
-- `lodge` AND `hunt`, IN THIS ORDER, and the order is the one `BED_WORDS` publishes: a table has no
-- order and a spec that read one out of `pairs` would be a spec that reorders between runs.
Ambience.BED_WORDS = table.freeze({ "lodge", "hunt" })

-- A PLAYER WHO IS NOT IN A DRIVE IS AT THE LODGE, and that is the safe answer as well as the true
-- one: nil, "", "Spectators" and any team word this game grows later all land here. The rule
-- `Horn.signalPhrase` already sets -- a silent drive would be a worse answer than the wrong phrase.
Ambience.DEFAULT_BED = "lodge"

Ambience.CONFIG = {
	-- 2.5 SECONDS, LINEAR IN GAIN. It is a feel number and it is Karen's to turn (design K2): long
	-- enough that nobody hears a switch, short enough that a man walking out of the lodge is in the
	-- wood before the birds have gone. The fade is linear rather than curved because a curve is a
	-- second decision nobody has heard yet.
	FADE_SECONDS = 2.5,

	BEDS = {
		-- ------------------------------------------------ THE LODGE: quiet birds and a soft wind
		--
		-- BOTH IDS ARE ROBLOX-PROVIDED LICENSED LIBRARY AUDIO AND NOTHING IS UPLOADED. Karen's OK of
		-- 2026-10-23 covers a CC0 upload; it does not require one, and the licensed catalogue has
		-- both of these. Swept through `apis.roblox.com/toolbox-service/v1/marketplace/audio`
		-- filtered to licensed partners, then MEASURED in a Forest Test Play session on the CLIENT
		-- (on the server every `PlaybackLoudness` reads 0.0, which is how the first run of this
		-- measurement was thrown away):
		--
		--        id          name                                        len     peak   mean
		--     9116971174  Morning Forest Birds 1 (SFX), Pro Sound Eff.  36.01    22.5   15.1
		--     9116970949  Morning Forest Birds 6 (SFX)                  75.20    23.6   16.7
		--     9116969466  Morning Birds 2 (SFX)                         36.01    18.0    5.1
		--     9116258071  Leaves Rustle Wind Blowing Through Trees 1    75.77     7.1    3.7
		--     9116258282  Leaves Rustle Wind Blowing Through Trees 2    87.38     5.7    0.5
		--     9112781510  Forest Ambience 1 (SFX)                       36.01     1.1    0.9
		--     4629533497  Workspace.Ambience (Karen's own, at 0.50)     117.59     7.9    6.0
		--
		-- THE TWO CHOSEN ARE THE LONGEST TAKES WITH THE STEADIEST LEVEL. `Morning Forest Birds 6` is
		-- 75 s -- so an audible repeat happens less than once a minute (design N8 asks for >= 20 s)
		-- -- and its mean of 16.7 against a peak of 23.6 is a continuous dawn chorus rather than a
		-- few calls with silence between them (`Morning Birds 2`'s mean of 5.1 against 18.0 is that
		-- second thing, which is why it is not here). `Leaves Rustle Wind 1` is 76 s at a mean of
		-- 3.7: a quarter of the birds' energy, which is what *"a soft wind"* under birdsong is.
		-- `Leaves Rustle Wind 2` is longer still but its mean of 0.5 is nearly nothing -- it is a
		-- recording of a wind that mostly was not blowing.
		lodge = {
			WORD = "lodge",
			VOICES = {
				-- `LEVEL` IS MEASURED AGAINST KAREN'S OWN FOREST, not chosen by taste.
				-- `Workspace.Ambience` plays at 0.50 with a mean loudness of 6.0, so its energy at
				-- the ear is about 3.0 in these units. The lodge is meant to be CALMER AND QUIETER
				-- than the hunt (the dispatch), and the design's N7 asks for 25-40 % of it:
				--   birds 0.18 x 16.7 = 3.01     wind 0.10 x 3.7 = 0.37     total 3.38
				--   against the forest's        0.50 x 6.0 = 3.00
				-- ...which is 113 %, NOT 25-40 %. **SO THE LEVELS ARE LOWER THAN THE DESIGN'S FIRST
				-- PICK, and the measurement is the reason**: at 0.18 the birds alone would be as
				-- loud as the whole forest. 0.055 and 0.030 put the pair at 0.92+0.11 = 1.03, which
				-- is 34 % of 3.00 -- inside the band the design asked for, computed from the takes
				-- that were actually chosen rather than from the ones it guessed at.
				--
				-- AND BOTH ARE FAR UNDER THE DRIVE'S BUGLE at `Horn.CONFIG.SIGNAL.VOLUME`, so a bed
				-- can never mask the one sound that tells you the drive has started.
				--
				-- KAREN'S EARS DECIDE and each of these is one line (design K1).
				{
					WHAT = "birds",
					ID = "rbxassetid://9116970949",
					LEVEL = 0.055,
					FROM = 0,
					TO = 0,
					CLIP_SECONDS = 75.2,
				},
				{
					WHAT = "wind",
					ID = "rbxassetid://9116258071",
					LEVEL = 0.03,
					FROM = 0,
					TO = 0,
					CLIP_SECONDS = 75.77,
				},
			},
		},
		-- ------------------------------------------------ THE HUNT: SILENT, AND THAT IS NOT A STUB
		--
		-- In the Forest Test the hunt's forest ambience ALREADY EXISTS and it is Karen's
		-- `Workspace.Ambience` at 0.50, which this owner is forbidden to touch (the header). A
		-- second global forest layer during the drive would double a bed nobody in git owns.
		--
		-- So what the crossfade does today is exactly what the dispatch asked for -- at the lodge,
		-- quiet birds and wind OVER the place's own forest; out on the line, the place's own forest
		-- alone -- and this row is one Karen fills the day she wants the drive to sound different
		-- (design K3). An empty id plays nothing and is not an error.
		hunt = {
			WORD = "hunt",
			VOICES = {
				{ WHAT = "forest", ID = "", LEVEL = 0.2, FROM = 0, TO = 0, CLIP_SECONDS = 0 },
			},
		},
	},
}

Shotgun.deepFreeze(Ambience.CONFIG)

-- ---------------------------------------------------------------- the pure rules

-- WHICH BED A PLAYER WITH THIS TEAM BELONGS IN. `Drive.TEAMS` is READ rather than copied: a third
-- spelling of "Shooters" in this repo is a bug waiting for a rename (design section 3.2).
function Ambience.bedFor(team: string?): string
	if type(team) == "string" and Drive.TEAMS[team] then
		return "hunt"
	end
	return Ambience.DEFAULT_BED
end

-- WHERE EVERY BED IS GOING. **Invariant I1: exactly one target is 1 and every other is 0, always**,
-- and it is a property of the only shape a target table can have rather than a rule the stepper
-- enforces -- which is what makes "at most one rising and one falling" true by construction.
function Ambience.targetsFor(bed: string?): { [string]: number }
	local wanted = if type(bed) == "string" and Ambience.CONFIG.BEDS[bed] ~= nil then bed else Ambience.DEFAULT_BED
	local out: { [string]: number } = {}
	for _, word in ipairs(Ambience.BED_WORDS) do
		out[word] = if word == wanted then 1 else 0
	end
	return out
end

-- ONE BED'S GAIN, ONE FRAME ON. Linear at `1 / fadeSeconds` per second, clamped to [0, 1] and
-- landing EXACTLY on the target rather than approaching it -- so "the crossfade finished" is a
-- value a spec can compare and not an asymptote, which is `Camera.Config.RECOIL_REST_EPSILON`'s own
-- stated reason in another system.
--
-- FRAME-RATE INDEPENDENT BY CONSTRUCTION: the step is `dt / fadeSeconds`, so 2.5 s of fade is 2.5 s
-- of fade at 30, 60 or 144 fps. A `fadeSeconds` of 0 or less is INSTANT, which is the honest reading
-- of "no fade" and keeps the function total.
function Ambience.stepGain(gain: number, target: number, dt: number, fadeSeconds: number): number
	local from = math.clamp(if type(gain) == "number" then gain else 0, 0, 1)
	local to = math.clamp(if type(target) == "number" then target else 0, 0, 1)
	if from == to then
		return to
	end
	if type(fadeSeconds) ~= "number" or fadeSeconds <= 0 then
		return to
	end
	local move = (if type(dt) == "number" and dt > 0 then dt else 0) / fadeSeconds
	if move <= 0 then
		return from
	end
	if to > from then
		return math.min(to, from + move)
	end
	return math.max(to, from - move)
end

-- WHAT THE ENGINE IS HANDED. The gain says where the bed is; the level says how loud that layer is
-- when it is all the way in. Clamped to the engine's own `Volume` range, so no data row can ask for
-- a value `Sound` would refuse.
--   https://create.roblox.com/docs/reference/engine/classes/Sound#Volume
Ambience.VOLUME_MAX = 10

function Ambience.volumeFor(gain: number, level: number): number
	local g = math.clamp(if type(gain) == "number" then gain else 0, 0, 1)
	local l = if type(level) == "number" then level else 0
	return math.clamp(g * l, 0, Ambience.VOLUME_MAX)
end

-- THE LOOP WINDOW, WITH `TO == 0` RESOLVED TO THE WHOLE CLIP. Two numbers so the owner never
-- branches on the sentinel.
function Ambience.loopWindow(voice: Voice): (number, number)
	local from = if type(voice.FROM) == "number" then voice.FROM else 0
	local to = if type(voice.TO) == "number" and voice.TO > 0 then voice.TO else voice.CLIP_SECONDS
	return from, to
end

-- THE INSTANCE'S NAME, in one place, so the owner and both specs spell it the same way. The prefix
-- is what makes "no other module creates one of these" greppable (design section 8).
Ambience.NAME_PREFIX = "Ambience_"

function Ambience.voiceName(bed: string, voice: Voice): string
	return string.format("%s%s_%s", Ambience.NAME_PREFIX, tostring(bed), tostring(voice.WHAT))
end

-- IS THE DATA SOUND? The shape `Shop.rowsOk` already has: (true) or (false, a named reason). A
-- checker nobody has shown can fail is not evidence, so the server spec drives every refusal below
-- with a hand-built bad config.
function Ambience.rowsOk(config: any?): (boolean, string?)
	local cfg = if config ~= nil then config else Ambience.CONFIG
	if type(cfg) ~= "table" then
		return false, "config is not a table"
	end
	if type(cfg.FADE_SECONDS) ~= "number" or cfg.FADE_SECONDS <= 0 then
		return false, "FADE_SECONDS must be a positive number"
	end
	if type(cfg.BEDS) ~= "table" then
		return false, "BEDS is not a table"
	end
	local known: { [string]: boolean } = {}
	for _, word in ipairs(Ambience.BED_WORDS) do
		known[word] = true
		if type(cfg.BEDS[word]) ~= "table" then
			return false, "BEDS is missing the bed " .. word
		end
	end
	for word, bed in pairs(cfg.BEDS) do
		if not known[word] then
			return false, "BEDS has a bed no BED_WORDS entry names: " .. tostring(word)
		end
		if bed.WORD ~= word then
			return false, string.format("the bed %s calls itself %s", tostring(word), tostring(bed.WORD))
		end
		if type(bed.VOICES) ~= "table" or #bed.VOICES == 0 then
			return false, "the bed " .. tostring(word) .. " has no voices"
		end
		local seen: { [string]: boolean } = {}
		for _, voice in ipairs(bed.VOICES) do
			if type(voice.WHAT) ~= "string" or voice.WHAT == "" then
				return false, "a voice of " .. tostring(word) .. " has no WHAT"
			end
			if seen[voice.WHAT] then
				return false, string.format("%s has two voices called %s", tostring(word), voice.WHAT)
			end
			seen[voice.WHAT] = true
			if type(voice.ID) ~= "string" then
				return false, string.format("%s.%s has no ID", tostring(word), voice.WHAT)
			end
			-- AN EMPTY ID IS SILENT AND IS NOT CHECKED FURTHER, which is the standing rule: the
			-- hunt bed ships that way on purpose and a build whose takes Karen has removed must
			-- still pass.
			if voice.ID ~= "" then
				if type(voice.LEVEL) ~= "number" or voice.LEVEL <= 0 or voice.LEVEL > Ambience.VOLUME_MAX then
					return false, string.format("%s.%s LEVEL must be in (0, 10]", tostring(word), voice.WHAT)
				end
				if type(voice.CLIP_SECONDS) ~= "number" or voice.CLIP_SECONDS <= 0 then
					return false,
						string.format("%s.%s CLIP_SECONDS must be measured and positive", tostring(word), voice.WHAT)
				end
				if type(voice.FROM) ~= "number" or voice.FROM < 0 then
					return false, string.format("%s.%s FROM must be >= 0", tostring(word), voice.WHAT)
				end
				if type(voice.TO) ~= "number" or voice.TO < 0 then
					return false, string.format("%s.%s TO must be >= 0", tostring(word), voice.WHAT)
				end
				if voice.TO > 0 and not (voice.FROM < voice.TO and voice.TO <= voice.CLIP_SECONDS) then
					return false, string.format("%s.%s needs FROM < TO <= CLIP_SECONDS", tostring(word), voice.WHAT)
				end
			end
		end
	end
	return true, nil
end

return Ambience
