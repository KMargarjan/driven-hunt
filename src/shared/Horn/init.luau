--!strict
-- Horn: THE BEATER'S SIGNAL HORN, as data. Task 152, the beater kit part 2.
--
-- KAREN, 2026-10-10 ~18:20: *"we need to make tool for beater, horn, signal, something that they can
-- walk and make sound for spook"*, and ~22:10: *"for horn you can use hon from free library roblox /
-- ... / so horn will be default tool for beater"*.
--
-- WHY A HORN AT ALL, AND WHY ONE ROW RATHER THAN A HARD-CODED HORN. A driven hunt's beater carries a
-- *Signalgeber* -- "Pfeife, Horn oder Rassel" (whistle, horn or rattle) -- and the sources disagree
-- about which, so the noise-maker is one row of data and a whistle is the same mechanic with another
-- sound id (note section 5.1):
--   https://www.jagdjuenger.de/ausruestung/drueckjagd-ausruestung/
--   https://www.livingactive.de/blog/als-treiber-auf-der-drueckjagd-unsere-empfehlungen/
--   https://www.oldenburger-jagdcenter.de/Ausruestung/Diverses-Jagdzubehoer/Jagd-Signalhorn-aus-Messing.html
-- The last one sells the object this file models: a polished-brass signal horn, standard driven-hunt
-- kit and easy for the unpractised to blow.
--
-- WHY PARTS AND NOT A MODEL FROM THE FREE LIBRARY, which is what Karen asked for. MEASURED, twice
-- (note section 5.2, and again in this task): the avatar catalog has no horn at any price, and the
-- two plausible free Creator Store horn MODELS -- "The FIRST Bugle!" (33685172) and "horn"
-- (5454407759), both IsPublicDomain true -- answer InsertService:LoadAsset with "User is not
-- authorized to access Asset." A model marked public in the store is not therefore loadable by this
-- place. So the geometry is built in code from the numbers below, exactly as Weapon.Shape builds the
-- shotgun and for the reasons recorded there: .rbxm is banned (CLAUDE.md), typed values in a
-- .model.json are refused by the harness, a Cylinder is analytically round, and a number in a diff
-- is reviewable.
--
-- THE VOICE *IS* FROM THE LIBRARY, which is the half of her instruction that works: "Hunting Horn",
-- APMOfficial, rbxassetid://9038902877, IsPublicDomain true -- verified by name and creator through
-- the public asset-details endpoint, the procedure Task 142 used for the rifle.
--
-- Note:   docs/research/2026-10-11-beater-kit.md (section 5)
-- Design: docs/design/beater-kit.md (section 16 item 1: carried, not worn, so its owner is
--         ServerScriptService.Weapon and never Match.Body)
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Horn = {}

-- The Tool's name, and also how a stray one is found. It is NOT a row in `Weapons.ROWS`: that
-- table's type is a GUN's -- ranges, pellets, ammo kinds, a cycle -- and a horn has none of them.
-- One row per noise-maker lives here instead.
Horn.TOOL_NAME = "Horn"
Horn.LABEL = "HORN"

-- ---------------------------------------------------------------- the uploaded horn (task 169)
--
-- KAREN, 2026-10-12 ~21:45: *"We need better horn"* -- and the thing she meant is the LOOK. Task 152
-- built the horn out of nine welded cylinders because it had MEASURED that the free library has no
-- horn this place can load (see `pieces` below, which is still the fallback and still the thing a
-- spec asserts the proportions of). She then went and found one herself: "Horn" by r4ulp3rcy,
-- CC-BY-4.0, which is a real natural signal horn with two silver bands -- ivory, curved, tapering
-- from a narrow mouthpiece to an open bell -- and gave the upload OK the same evening.
--
-- THE KEY, AND IT IS THE ONLY THING `Weapon.Horn` NEEDS OUT OF THIS SECTION. Every other number
-- below is read by the MANIFEST (`ServerStorage.Assets`), which is where the asset pipeline keeps
-- what an upload is -- and `Weapon.Horn` reads them back through the template provider's row, the
-- same route `Weapon.Hardware` already takes for the gun. So there is exactly one copy of each
-- number, and the file it lives in is the horn's.
Horn.ASSET_KEY = "horn.body"

-- WHAT THE UPLOAD IS, AS THE MANIFEST ROW STATES IT. `ServerStorage.Assets` holds the id, the
-- licence and the provenance; these are the four GEOMETRY numbers, and they are here because they
-- are facts about the horn rather than about the upload -- how big it is, which way round it goes,
-- and where in the hand it sits. A screenshot is what decides them (rule 5) and changing one is a
-- line here, with no re-upload.
Horn.MESH = table.freeze({
	-- 1.25 STUDS LONG, which is 0.35 m at this game's `METRES_PER_STUD` -- a real natural signal
	-- horn, and the top of the Director's "~25-35 cm across". The two other numbers are not a
	-- choice at all: they are 1.25 times the model's OWN aspect (0.34696 and 0.19174, measured off
	-- the prepared mesh's bounding box, below), so the horn is scaled UNIFORMLY. A non-uniform fit
	-- is a squashed horn that measures perfectly -- `Weapon.Hardware.addMesh`'s own warning.
	SIZE_STUDS = Vector3.new(1.25, 0.4337, 0.2397),
	-- WHAT IT MEASURES BEFORE ANYTHING RESIZES IT, so `Assets.Loader`'s aspect check has something
	-- to compare the arriving template against rather than a hope. Measured off the prepared
	-- model's own bounding box (11.6478 x 4.0413 x 2.2334 Blender units), which Roblox's FBX import
	-- lands at a hundred times over: (long, curve-height, thickness).
	NATURAL_SIZE_STUDS = Vector3.new(1164.78, 404.13, 223.34),
	-- A QUARTER TURN ABOUT Y, which lays the mesh's own long axis along the Handle's Z -- the axis
	-- the coil's bell already pointed down (`BELL_ANGLE` below puts it at -Z, "forward, away from
	-- the player"). The mesh's curve stays in the Handle's YZ plane, which is the plane a carried
	-- horn hangs in, so `GRIP` and `GRIP_BLOW` mean the same thing for both builds.
	--
	-- MINUS 90 AND NOT PLUS, AND A SCREENSHOT IS THE ONLY THING THAT COULD SAY SO (rule 5). The
	-- mouthpiece is at the file's own -X and the bell at its +X -- measured off the glTF, where the
	-- cross-section grows from 0.72 to 2.23 units along it -- so +90 should have put the bell
	-- forward. It did the opposite: photographed in the raise, the horn hung BELL DOWN AT THE CHEST
	-- with the tip pointing up past the head (`.screenshots/...-t169-horn-raised-close.png`). That
	-- is task 107's measurement arriving again -- "the Blender export plus the Roblox import reverse
	-- the model along its own long axis" -- and it is why `Gun.MESH_ROTATION_DEG` carries the same
	-- correction. Flipped live and re-photographed: mouthpiece at the face, bell up and forward past
	-- the head, which is how a horn is blown.
	ROTATION_DEG = Vector3.new(0, -90, 0),
	-- WHERE IT SITS IN THE HANDLE. The Handle is the envelope and the mesh is centred in it.
	OFFSET_STUDS = Vector3.zero,
	-- THE COLOUR IT FALLS BACK TO WHEN THE TEXTURE DOES NOT DRAW, measured rather than guessed: the
	-- median of the prepared base-colour atlas over its used pixels is RGB(171, 149, 99), a warm
	-- bone. Task 99's lesson, where a glove whose colour map failed rendered as Roblox's default
	-- grey and Karen saw a white hand.
	FALLBACK_COLOR = Color3.fromRGB(171, 149, 99),
})

-- WHICH TEAM CARRIES IT. The beater's -- and `Match.Body.ROLE_WORDS` is the one translator from
-- Karen's word ("beater") to this team name, so this constant is the TEAM, because that is what
-- `Match.Body.teamOf` answers and what both composition roots compare against.
Horn.TEAM = "Drivers"

-- THE ONE FLAG THIS SYSTEM HAS, and it is read at the composition root and nowhere else. A new
-- feel-critical path is BORN OFF (CLAUDE.md, "Feature flags"), and all three of this one's halves
-- are feel: how loud a blast is, how often a beater may blow, and whether a drive visibly moves when
-- he does. OFF, nobody is granted a horn and no blast reaches a boar, so the game is bit-for-bit
-- what it was before task 152.
Horn.FLAG = "HORN"

-- WHO CARRIES ONE, as a pure function of the two facts it depends on -- so both worlds are reachable
-- in a spec while the flag sits at one of them, which is the only permitted shape (CLAUDE.md).
function Horn.carriesFor(on: boolean, team: string?): boolean
	return on and team == Horn.TEAM
end

-- ...AND THE EXACT COMPLEMENT: WHO CARRIES A GUN (task 154). Karen, 2026-10-10: *"so horn will be
-- default tool for beater"*, and the Director's reading of it -- guns come later, with a licence.
--
-- IT IS HERE, BESIDE `carriesFor`, SO THE TWO CANNOT DISAGREE. In the Forest Test's first beater
-- playtest she spawned HOLDING THE SHOTGUN with the rifle and the horn in the bag (measured,
-- 2026-10-11: `tools=[HAND:Shotgun,BAG:Rifle,BAG:Horn]`), because the world's arming policy was
-- `return true` for everybody while the horn's carry policy already knew about teams. Two policies
-- answering one question -- "which role is this player" -- is how they came to disagree, so the
-- second answer is derived from the first and this file states both.
--
-- PURE, and a function of the team alone, so a spec can assert it without taking a live beater's
-- horn away -- the shape `Horn.carriesFor` and `Weapon.armingAction` both already have.
function Horn.gunFor(team: string?): boolean
	return team ~= Horn.TEAM
end

-- ONE SOUNDING OF THE DRIVE'S SIGNAL: when it starts relative to the cue, how long it sounds, and
-- which cut of which asset it is. `soundId`/`from` are carried in the row rather than read from the
-- config again by the client, so the plan is the whole instruction.
export type SignalNote = { at: number, seconds: number, soundId: string, from: number }

-- ONE PHRASE OF THE DRIVE'S SIGNAL, as data: the asset, the cut, and the asset's measured length so
-- a spec can prove the cut lies inside it.
export type SignalPhrase = { SOUND_ID: string, FROM: number, CUT: number, CLIP_SECONDS: number }

-- WHICH PHRASE AN UNKNOWN CUE GETS. The drive's own first word, so a signal is never silent.
Horn.SIGNAL_DEFAULT = "start"

export type Piece = {
	name: string,
	size: Vector3,
	offset: CFrame, -- relative to the Handle's centre; -Z is the bell, as GRIP assumes
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType,
	reflectance: number?,
}

-- THE HORN IS A COIL, NOT A TUBE, and that is Karen's correction after the first build (the
-- Director, 2026-10-11: *"the horn reads as a straight brass tube / spyglass. A driven-hunt horn is
-- CURVED (a Fuerst-Pless or Parforce horn: a coiled or half-moon brass tube with a bell)"*). He is
-- right and the sources said so already: the Oldenburger Jagdcenter *Jagd-Signalhorn aus Messing*
-- in the note's section 5.1 is a wound brass tube, and a Fuerst-Pless horn is one full turn of it.
--
-- SO THE TUBE IS BENT ROUND AN ARC. A real Fuerst-Pless coil is about 0.25 m across, which is 0.9
-- studs at this game's `METRES_PER_STUD` -- so the arc's RADIUS is 0.38 and the coil is 0.76 studs
-- across before the bell flares past it.
local ARC_RADIUS = 0.38
-- A C, not a closed ring: 230 degrees leaves the mouthpiece and the bell clearly apart, so the
-- object reads as a horn from any angle instead of as a brass doughnut.
local ARC_DEGREES = 230
-- The Director asked for 4-6. Five chords of a 230-degree arc turn 46 degrees at each joint, which
-- is a visible bend at this size and still cheap: nine parts in all.
local ARC_SEGMENTS = 5
-- The bore, mouthpiece end to bell end. A signal horn is conical for most of its length.
local BORE_START = 0.09
local BORE_END = 0.22

Horn.CONFIG = {
	-- ---------------------------------------------------------------- the blast
	--
	-- SECONDS BETWEEN BLASTS, per player, enforced on the SERVER. It is also the rate limit:
	-- `Tool.Activated` is a click, and a click is whatever the client sends, so this is the only
	-- thing standing between one beater and a continuous horn -- the same reasoning as
	-- `Shotgun.CONFIG`'s own rate limits.
	--
	-- 1.5, AND IT FOLLOWS THE CUT (task 154). KAREN, 2026-10-11, after hearing it: *"horn sound: -
	-- should be short one like beeep"*. Task 152 played a whole four-note CALL of 4.0 s and set the
	-- cooldown to 5 so that one click could not run into the next; the call is now ONE NOTE of 1.00
	-- s (`SOUND_START`/`SOUND_CUT` below), so the cooldown comes down with it. The rule it has to
	-- keep is unchanged and `tests/server/zz_horn.spec.luau` is what keeps it: a blast must FINISH
	-- before the next may start, or a beater clicking on the cooldown produces one continuous
	-- unbroken horn -- which is the exact thing a cooldown exists to prevent. 1.5 is the Director's
	-- start value and it clears the 1.00 s note by half a second.
	COOLDOWN = 1.5,
	-- How long the horn is held up to the mouth. Shorter than the call on purpose: the arm comes
	-- down while the last note is still ringing, which is what a person does.
	BLOW_SECONDS = 0.9,

	-- ---------------------------------------------------------------- the voice
	--
	-- "Hunting Horn", APMOfficial, IsPublicDomain true, asset type 3 (note section 5.2).
	-- The alternate, measured public the same way and kept here because Karen has not heard either
	-- of them yet and it is a one-line change: "Whistle Calling 4 (SFX)", ProSoundEffects,
	-- rbxassetid://9120675895, 1.0 s -- the whistle the same sources list beside the horn.
	SOUND_ID = "rbxassetid://9038902877",
	VOLUME = 1,
	-- ...AND IT IS SIXTY SECONDS LONG, WHICH THE RESEARCH NOTE COULD NOT KNOW AND TASK 152
	-- MEASURED. `Sound.TimeLength` is **60.63 s**: the asset is not one blast, it is a vintage
	-- recording of a hunting horn being blown over and over. Played whole, one click would sound a
	-- horn for a minute.
	--
	-- SO THE CLIP IS CUT. TASK 152 CUT IT TO ONE CALL; TASK 154 CUTS IT TO ONE NOTE, because Karen
	-- heard the call and said *"horn sound: - should be short one like beeep"* -- and a four-note
	-- signal phrase is not a beep.
	--
	-- THE WHOLE CUT IS MEASURED, TWICE, OFF THE ASSET'S OWN LOUDNESS. `Sound.PlaybackLoudness`
	-- sampled at render rate in a Play session of the Forest Test, 2026-10-11, peak per bucket --
	-- 0.05 s over the first 5.2 s, then 0.02 s over the two candidate windows:
	--     0.00-0.15  silence (0)                    the asset's own lead-in
	--     0.20-3.36  EIGHT separate notes (39-453), each 0.2-0.5 s with a valley between
	--     3.38-3.40  a valley (54, 36)              the gap before the phrase's last note
	--     3.42-3.58  the LAST NOTE's attack (95 -> 381)
	--     3.58-4.38  its long natural decay (381 -> 23)
	--     4.40-5.08  the clip's own silence (9-17)
	--     5.10-      the second call starts again (302, 338)
	--
	-- SO THE NOTE IS 3.40 -> 4.40: ONE note, one second, with the phrase's full tail on it. It is
	-- the only single note in the clip that reaches the Director's 0.5-1 s -- the eight before it
	-- measure 0.39-0.50 s and the loudest of them (peak 453 at 2.40) is 0.40 s nose to tail -- and
	-- it is the only one whose end is REAL SILENCE rather than the next note's attack, so the stop
	-- cannot click and no cut-off is audible. `SOUND_START` sits 0.02 s before the attack, so the
	-- horn sounds on the click.
	SOUND_START = 3.4,
	SOUND_CUT = 4.4,
	-- 3D, SO EVERYBODY NEARBY HEARS IT FROM WHERE IT WAS BLOWN. The Sound hangs on the Handle, so
	-- the engine positions it and these three numbers are the only thing deciding how far it
	-- carries. They are data for exactly that reason.
	--
	-- `InverseTapered` rather than the default `Inverse`: it is the mode Roblox documents for a
	-- point source that should be loud close up and reach actual silence at the far edge.
	--   https://create.roblox.com/docs/reference/engine/enums/RollOffMode
	ROLLOFF_MODE = Enum.RollOffMode.InverseTapered,
	ROLLOFF_MIN_STUDS = 25, -- full volume inside this
	-- ...AND SILENT BEYOND THIS, which is the SHOT's own audible radius (`Boar.CONFIG.SENSE`): 100 m
	-- / 0.28. A horn is made to be heard across a drive, so it carries at least as far as a gun --
	-- a beater nobody can hear is not a signal.
	ROLLOFF_MAX_STUDS = 357,

	-- ------------------------------------------------------------- the drive's signal
	--
	-- KAREN, 2026-10-12 ~10:40: *"when hunt starts 3 longer horn calls and when ends the same"*.
	-- AND THEN, 2026-10-12 ~16:00, AFTER HEARING IT: *"no it's not / for beater yes it's ok / for
	-- start and end of drive has to be tuturutu tu tu different one"*.
	--
	-- SO TASK 163 GOT TWO THINGS RIGHT AND ONE WRONG, AND THIS IS THE CORRECTION. The beater's own
	-- blast is RIGHT and nothing above this line moves. What was wrong is this signal: task 163
	-- played THREE LONG NOTES cut out of the beater's own 60 s recording -- her words were "3 longer
	-- horn calls" and that is what it built -- and three long notes of one pitch is a drone, not a
	-- signal. *"tuturutu tu tu"* is a MELODY: a few quick notes and then held ones, and it has to be
	-- a DIFFERENT sound from the horn a beater carries.
	--
	-- WHICH IS WHAT THE REAL SIGNAL IS. A German drive is opened with *Anblasen des Treibens* and
	-- closed with *Jagd vorbei und Halali* -- *Jagdleitsignale*, the signals a hunt is COMMANDED
	-- with, and two of the three sources call them safety-relevant. They are blown on a
	-- Fuerst-Pless horn, which is a VALVELESS brass signal horn: its notes are the natural
	-- harmonics, which is exactly what a military bugle is and why a bugle call is the same kind of
	-- object and not an approximation.
	--   https://waidwissen.com/lexikon/jagdleitsignale
	--   https://www.jaegerschmiede.de/jagdlexikon/jagdsignale/
	--   https://www.hegering-hitzacker.de/jagdhornsignale.php
	-- NONE OF THE THREE GIVES A NOTE LENGTH (task 163 said so too), so the shape below comes from
	-- the asset's own loudness and not from a transcription.
	--
	-- A LIBRARY SOUND, NOT A BUILT MELODY, AND THAT WAS THE TASK'S OWN CHOICE OF TWO. The dispatch
	-- allowed either a free public library fanfare or a melody assembled out of the beater's single
	-- note by pitch-shifting it per note. The library won on a measurement: the Creator Store audio
	-- search has a whole set of SHORT bugle calls from APMOfficial -- Roblox's own licensed KPM
	-- catalogue, the same creator as the beater's "Hunting Horn" -- every one `IsPublicDomain: true`
	-- and every one of the nine candidates MEASURED TO LOAD in this place (2026-10-12; the note
	-- lists all nine with their lengths). A pitch-shifted single note would have been one timbre
	-- played at three speeds, which is a kazoo rather than a horn, and it would have put a melody's
	-- worth of timing in code to avoid using an asset that already is one.
	--
	-- THE TWO PHRASES ARE MEASURED OFF THEIR OWN LOUDNESS, the way task 152 and 154 measured the
	-- beep. `Sound.PlaybackLoudness` sampled at Heartbeat rate in a Play session, peak per 0.05 s
	-- bucket, over the whole of each clip (Volume 0.0001: the loudness is the source's own and is
	-- not scaled by it).
	--
	-- "Bugle Call (a)", 1842335206, 4.06 s -- THE START.
	--     0.00-0.40  silence                                    the asset's own lead-in
	--     0.45-0.55  note (31, 38, 23)              \
	--     0.70-1.05  two notes (21, 47, 27, 43, 30)  |  SIX QUICK NOTES -- the "tuturutu"
	--     1.20-1.55  two notes (37, 48, 25, 20, 27)  |
	--     1.70-1.85  note (26, 19)                  /
	--     1.95-2.40  ONE HELD NOTE (44, 56, 51, 53, 55, 40, 35, 32, 17) -- the "tu tu"
	--     2.45-4.06  the clip's own silence (2, 1, 0...)
	--   So the cut is 0.42 -> 2.60: the whole phrase, 2.18 s, ending inside the clip's own silence
	--   so the stop cannot click. 0.42 is 0.03 s before the first attack, so it sounds on the cue.
	--
	-- "Bugle Call (c)", 1842368482, 2.84 s -- THE END, and it is a VARIATION rather than the same
	-- phrase, which is the one liberty this task takes with *"when ends the same"*: the two are the
	-- same instrument and the same shape, and a drive that ends on a shorter, lower figure says
	-- "over" rather than "go".
	--     0.00-0.30  silence
	--     0.35-0.50  note (34, 31)                   \
	--     0.60-0.95  two notes (37, 45, 17, 31, 34)   |  FOUR QUICK NOTES
	--     1.10-1.35  two notes (35, 36, 28, 33)      /
	--     1.40-1.85  ONE HELD NOTE (33, 40, 33, 30, 28, 24, 24, 22, 18, 9)
	--     1.90-2.84  the clip's own silence
	--   Cut 0.32 -> 2.00: 1.68 s.
	--
	-- NOT HEARD, AND SAID SO (rule 8): these are measurements, not a listening. Whether the two
	-- phrases feel right at the two ends of a drive is Karen's judgement, and both are one line.
	SIGNAL = {
		-- LOUDER THAN THE OLD NOTE WAS, BECAUSE THE RECORDING IS QUIETER, and that is a measurement
		-- too: the bugle's held note peaks at 56 of 1000 against the hunting-horn note's 214 and the
		-- beater's beep's 418, all three sampled the same way. At Volume 1 it would arrive about a
		-- quarter as loud as the signal Karen heard this morning, so this is 3 -- which is the ratio
		-- rounded down rather than up, because a 2-D cue at the ear startles more easily than a
		-- sound in the world. Hers to change, and one line.
		VOLUME = 3,
		-- KEYED BY THE SERVER'S OWN WORD. `Match.Phase` emits a `signal` feed entry whose text is
		-- "start" or "end" and nothing else; this table is keyed by exactly those two words, so the
		-- client's owner looks the phrase up instead of branching on it, and a third cue one day is
		-- a row here and no code anywhere.
		PHRASES = {
			start = {
				-- "Bugle Call (a)", APMOfficial, IsPublicDomain true, KPM 1000 LP Series,
				-- "Military bugles". Measured to load in this place, 2026-10-12.
				SOUND_ID = "rbxassetid://1842335206",
				FROM = 0.42,
				CUT = 2.6,
				-- The whole asset, measured (`Sound.TimeLength`), so a spec can prove the cut is
				-- inside the clip instead of taking the two numbers on trust.
				CLIP_SECONDS = 4.062,
			},
			["end"] = {
				-- "Bugle Call (c)", the same creator, the same library, the same licence.
				SOUND_ID = "rbxassetid://1842368482",
				FROM = 0.32,
				CUT = 2,
				CLIP_SECONDS = 2.843,
			},
		},
	},

	-- ---------------------------------------------------------------- the spook
	--
	-- HOW FAR A BLAST PUSHES ANIMALS, IN METRES, with the conversion in the open -- the shape Task
	-- 150 established after a radius written in studs had been compared against distances in metres
	-- for two tasks ("at METRES_PER_STUD 0.28, 120 studs is 33.6 m"). The Director's start value.
	-- Both spellings are written out and `tests/server/zz_horn.spec.luau` asserts they agree to the
	-- stud, so a world or a spec may override either unit and be read.
	-- 100 m AND NOT 80 (task 154). KAREN, 2026-10-11: *"horn reach is further once they hear also
	-- run without stop"* -- the horn's whole point against a beater's own 25 m
	-- (`ForestTest.SPOOK.BEATER_M`) is that it reaches four times as far, and 100 m is both the
	-- Director's start value and the distance a gunshot already carries in this game
	-- (`Boar.CONFIG.SENSE.SHOT_HEARD_FROM_SHOOTER_M`). It is also exactly `ROLLOFF_MAX_STUDS`, so
	-- the animals that run are the animals that could hear it.
	METRES_PER_STUD = 0.28, -- the same number `Report.CONFIG` and `Boar.CONFIG.SENSE` publish
	SPOOK_M = 100,
	SPOOK_STUDS = 357, -- 100 m / 0.28

	-- ---------------------------------------------------------------- the hardware
	--
	-- THE HANDLE IS THE ENVELOPE, NOT THE HORN, and it is invisible for the same reason the gun's is
	-- (Task 71): the horn is the welded pieces below, so the Handle's own box would be a slab
	-- through the middle of it. Set HANDLE_TRANSPARENCY to 0 to see the box they are laid out in.
	HANDLE_SIZE = Vector3.new(0.5, 1.1, 1.1),
	HANDLE_TRANSPARENCY = 1,
	HANDLE_COLOR = Color3.fromRGB(205, 160, 60),
	-- ---------------------------------------------------------------- WHERE THE HAND HOLDS IT
	--
	-- KAREN, 2026-10-13 ~09:20, after playing 168-171: *"horn is hanging somewhere it has to be in
	-- hand"*. She is right, and it is not a matter of taste: it was MEASURED on her own live beater
	-- before a number here was touched.
	--
	-- WHAT `Tool.Grip` ACTUALLY IS, because every wrong number in this block came from not knowing
	-- it. The engine welds the Handle to the right hand with `Part0.CFrame * C0 == Part1.CFrame * C1`,
	-- where C1 is this property -- so `Grip.Position` is THE POINT OF THE HANDLE THAT THE HAND HOLDS,
	-- in the Handle's own coordinates. `Shotgun.CONFIG.GRIP` is `CFrame.new(0, 0, 1.4)` on a Handle
	-- 4.4 studs long: a point ON the gun, 1.4 studs back from its middle, which is the wrist of the
	-- stock. Every gun in this repo is held that way.
	--
	-- THE HORN WAS NOT. `CFrame.new(-0.8, 0.7, 0.45)` is 1.17 studs from the Handle's centre, and the
	-- Handle is 0.5 x 1.1 x 1.1 -- so the hand was closing on a point OUTSIDE the object it was
	-- holding, and the horn floated beside it. MEASURED in the Forest Test, 2026-10-13, on a player
	-- beater and on all four bot beaters: the Handle's centre sat **1.224 studs** from the RightHand's
	-- centre, at hand-local (0.43, -0.61, 0.97). A horn 1.25 studs long hanging a stud away from the
	-- fist is exactly what she saw.
	--
	-- IT WAS NOT A MISTAKE IN TASK 152 EITHER, AND THAT IS WHY IT SURVIVED TWO TASKS: the number was
	-- chosen by photographing the FIRST-PERSON frame and asking "where in the corner of the screen do
	-- I want this?", which is a question about the camera and not about the hand. The answer filled
	-- the bottom-right of the view nicely and had the object nowhere near the fist. Task 169 then
	-- re-scaled the horn from a 0.76-stud coil to a 1.25-stud mesh and moved it further still.
	--
	-- SO THE RULE IS THE GUN'S RULE NOW: the grip point is a point ON THE HORN. The mesh is centred
	-- in the Handle (`MESH.OFFSET_STUDS` is zero) and `MESH.ROTATION_DEG` lays its long axis along
	-- the Handle's Z, so the horn's body occupies |x| <= 0.12, |y| <= 0.22, |z| <= 0.625 -- and
	-- `(0, 0, 0.25)` is inside that box, a quarter of a stud from the middle toward the MOUTHPIECE
	-- end. That is where a person holds a signal horn: on the tube, with the bell away from the fist
	-- and the mouthpiece the short end. MEASURED after the change, the same way: the Handle's centre
	-- is **0.407 studs** from the hand -- which is the grip attachment's own offset plus a quarter
	-- stud of horn, i.e. the fist is closed on the tube.
	--
	-- NO ROTATION, AND THAT IS A MEASUREMENT TOO. The grip attachment's Z runs up the arm, so with no
	-- rotation the horn's long axis lies along the forearm: bell forward of the fist when the arm is
	-- out, hanging below it when the arm is down, which is how a carried horn sits either way. The
	-- old 25-degree roll was part of the screen-corner framing and has nothing to hold up now.
	-- Photographed in third person before it was written down (rule 5):
	-- `.screenshots/20261013T094638Z-t172-grip-front.png`, a bot beater from the front and right.
	-- (`.screenshots/` is git-ignored, so the file is on the Builder's machine and the request is
	-- where its contents are described.)
	GRIP = CFrame.new(0, 0, 0.25),
	-- ...AND THE RAISE IS EXACTLY TASK 169's, NOT RE-BASED ONTO THE NEW POINT -- which was tried
	-- first, measured, and rejected (task 172).
	--
	-- A HAND DOES NOT SLIDE ALONG AN OBJECT WHEN IT LIFTS IT, so the obvious thing was to give the
	-- raise `GRIP`'s own translation and change only the rotation. MEASURED in the Forest Test,
	-- 2026-10-13, on a bot beater blowing: the Handle stopped **2.66 studs** from the head instead of
	-- task 169's recorded **1.77**, which is the horn at the CHEST and not at the mouth -- the very
	-- thing 169 photographed its way out of. The reason is that the ARM RAISE IS MODEST (the clip
	-- task 168 plays brings the hand to about chest height, not to the chin), so what actually puts
	-- the mouthpiece at the mouth is this pose's own lateral offset: the horn is drawn up and inboard
	-- through the fist while the arm comes up.
	--
	-- SO IT IS LEFT ALONE, AND THE COST IS DISCLOSED RATHER THAN HIDDEN: between the carry and the
	-- blast the horn slides about half a stud through the hand. Nobody could see that before, because
	-- the horn was not in the hand in either pose; it is visible now, and whether it matters is
	-- Karen's eye. Both the fix (a bigger raise clip, so the hand reaches the mouth and the two poses
	-- can share one point) and the dial (this line) are one change each, and the task's notes row
	-- carries it.
	--
	-- IT IS A GRIP AND NOT AN ANIMATION ON PURPOSE: the ARM is raised by the clip task 168 added on
	-- the character's own Animator (one writer, server-side, replicated), and this is the object in
	-- the hand turning with it. `Tool.Grip` is the Tool's own property, the engine rebuilds the weld
	-- when it changes, and `Weapon.Horn` is the only thing that ever writes it.
	GRIP_BLOW = CFrame.new(-0.42, -0.22, 0.3) * CFrame.Angles(math.rad(-55), 0, math.rad(25)),

	-- THE HORN'S COLOURS. Director's pick and Karen's to change (her rule, 2026-09-26: styling never
	-- blocks). Polished brass, raised well above a photographic albedo for the reason Task 22 and
	-- Task 71 both measured in this place: an unlit face gets Lighting.Ambient alone (~0.275 here),
	-- so a true-to-life brass reads near-black on screen.
	LOOK = {
		brass = Color3.fromRGB(205, 160, 60),
		mouthpiece = Color3.fromRGB(170, 172, 178), -- nickel, as on the real thing
		cord = Color3.fromRGB(74, 48, 32), -- the leather carrying cord
	},
}

-- EVERY PIECE OF THE HORN, in build order. PURE: it creates no Instance, reads no service and holds
-- no state, so a spec can assert every proportion with no Tool, no character and no physics. The
-- same division this repo already uses twice -- a pure list plus one builder: `Weapon.Shape` plus
-- `Weapon.Hardware`, and `MapGen.Layout` plus `MapGen.Props`.
--
-- A COILED TUBE WITH A FLARED BELL, which is what a hunting horn is. The tube is `ARC_SEGMENTS`
-- straight cylinders laid along a `ARC_DEGREES` arc of radius `ARC_RADIUS` in the Handle's own YZ
-- plane -- each one a CHORD between two points ON the arc, so consecutive sections share an endpoint
-- exactly and the joints cannot gap however the numbers are changed. The bore widens section by
-- section from `BORE_START` to `BORE_END`, the nickel mouthpiece sits tangent at the near end, the
-- flare and bell tangent at the far end, and the carrying cord closes the C.
--
-- WHY THE ARC IS IN THE YZ PLANE: `ARC_NORMAL` is the Handle's X, so the coil lies in the plane a
-- carried horn hangs in, and `CFrame.lookAt` below can take X as its up vector -- which it must,
-- because a tangent of an arc in that plane is sometimes exactly the world up and `lookAt` is
-- degenerate when the two are parallel.
local ARC_NORMAL = Vector3.xAxis

-- Where the tube's centreline is at angle `t` (radians), and which way it is going there. The bell
-- is at `BELL_ANGLE`, where the tangent is the Handle's -Z -- so the bell faces FORWARD, away from
-- the player, which is what `GRIP` assumes.
local BELL_ANGLE = math.pi / 2

local function arcPoint(t: number): Vector3
	return Vector3.new(0, ARC_RADIUS * math.sin(t), ARC_RADIUS * math.cos(t))
end

-- A cylinder's length runs along its own X, so a section lying along `dir` is `lookAt` (whose
-- LookVector is -Z) turned a quarter turn about Y. The same quarter turn `Weapon.Shape` uses for the
-- gun's barrels, applied to a frame that is no longer axis-aligned.
local function lyingAlong(centre: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(centre, centre + dir, ARC_NORMAL) * CFrame.Angles(0, math.pi / 2, 0)
end

function Horn.pieces(config): { Piece }
	local look = config.LOOK
	local span = math.rad(ARC_DEGREES)
	-- Travelling forward along the arc and ENDING at the bell, so the bell's tangent is -Z.
	local from = BELL_ANGLE - span

	local pieces: { Piece } = {}
	local function add(name: string, centre: Vector3, dir: Vector3, length: number, diameter: number, color: Color3)
		table.insert(pieces, {
			name = name,
			size = Vector3.new(length, diameter, diameter),
			offset = lyingAlong(centre, dir),
			color = color,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
			reflectance = 0.15, -- polished
		})
	end

	-- THE MOUTHPIECE, tangent at the near end and just short of it, so the cup reads as a separate
	-- fitting rather than as the first section in a different colour.
	local head = arcPoint(from)
	local headDir = (arcPoint(from + 0.01) - head).Unit
	add("Mouthpiece", head - headDir * 0.05, headDir, 0.1, 0.13, look.mouthpiece)

	-- THE TUBE: one chord per segment, each starting where the last one ended.
	local last, lastDir = head, headDir
	for index = 1, ARC_SEGMENTS do
		local a = arcPoint(from + span * (index - 1) / ARC_SEGMENTS)
		local b = arcPoint(from + span * index / ARC_SEGMENTS)
		local chord = b - a
		local dir = chord.Unit
		-- The bore at the MIDDLE of this section, so the taper is even end to end.
		local bore = BORE_START + (BORE_END - BORE_START) * ((index - 0.5) / ARC_SEGMENTS)
		add(string.format("Tube%d", index), a + chord / 2, dir, chord.Magnitude, bore, look.brass)
		last, lastDir = b, dir
	end

	-- THE FLARE AND THE BELL, tangent at the far end. Two pieces and not one, because a single wide
	-- disc reads as a washer on the end of a pipe; a cone needs a step.
	add("Flare", last + lastDir * 0.06, lastDir, 0.12, 0.3, look.brass)
	add("Bell", last + lastDir * (Horn.BELL_REACH - 0.07), lastDir, 0.14, 0.46, look.brass)

	-- THE CARRYING CORD, the one piece that is not the instrument: a signal horn hangs on a cord, and
	-- here it closes the C between the mouthpiece end and the bell end -- which is both what the real
	-- object looks like and what stops the coil reading as a broken ring.
	local gap = last - head
	table.insert(pieces, {
		name = "Cord",
		size = Vector3.new(gap.Magnitude, 0.035, 0.035),
		offset = lyingAlong(head + gap / 2, gap.Unit),
		color = look.cord,
		material = Enum.Material.Fabric,
		shape = Enum.PartType.Cylinder,
	})

	return pieces
end

-- WHERE THE ARC'S TWO ENDS ARE, exported so a spec can assert the shape without re-deriving it and
-- so nothing else has to know the parametrisation. `bellTangent` is the direction the note leaves in.
export type Arc = {
	from: Vector3,
	to: Vector3,
	bellDir: Vector3,
	radius: number,
	degrees: number,
	segments: number,
}

function Horn.arc(): Arc
	local span = math.rad(ARC_DEGREES)
	local to = arcPoint(BELL_ANGLE)
	-- The LAST CHORD's direction, not the tangent at the end: the tube is a polyline, so the bell is
	-- welded to the chord it grows out of. Re-derived from the same two points `pieces` uses.
	local beforeLast = arcPoint(BELL_ANGLE - span / ARC_SEGMENTS)
	return {
		from = arcPoint(BELL_ANGLE - span),
		to = to,
		bellDir = (to - beforeLast).Unit,
		radius = ARC_RADIUS,
		degrees = ARC_DEGREES,
		segments = ARC_SEGMENTS,
	}
end

-- How far past the arc's end the bell's outer face sits. One number, read by `pieces` and by
-- `bellOffset`, so the drawn bell and the published bell cannot drift apart.
Horn.BELL_REACH = 0.26

-- THE BELL MOUTH, in the Handle's own frame: where the note comes out, and the point a screenshot is
-- checked against.
function Horn.bellOffset(_config): Vector3
	-- The bell's OUTER FACE, derived from the same parametrisation `pieces` uses, so the two cannot
	-- disagree about where the note comes out.
	local arc = Horn.arc()
	return arc.to + arc.bellDir * Horn.BELL_REACH
end

-- THE SPOOK RADIUS IN STUDS, from whichever unit the config carries. PURE, and the ONE place the
-- conversion happens: no caller multiplies by METRES_PER_STUD itself. `SPOOK_STUDS` wins when it is
-- there, because a world that overrides the studs means the studs.
function Horn.spookStuds(config): number
	local resolved = config or Horn.CONFIG
	if type(resolved.SPOOK_STUDS) == "number" then
		return resolved.SPOOK_STUDS
	end
	return resolved.SPOOK_M / resolved.METRES_PER_STUD
end

-- HOW LONG THE CLIP IS LEFT PLAYING, from `SOUND_START` to `SOUND_CUT`. PURE, and derived rather
-- than written down a second time: a cut moved without its start would otherwise play the asset's
-- next call, which is the one mistake these two numbers exist to prevent.
function Horn.playSeconds(config): number
	local resolved = config or Horn.CONFIG
	return math.max(resolved.SOUND_CUT - resolved.SOUND_START, 0)
end

-- WHICH PHRASE A CUE SOUNDS. The server's word in, one row of `SIGNAL.PHRASES` out -- and an
-- unknown word, or none at all, is the START phrase rather than nil: a cue that reached this far is
-- a drive asking to be signalled, and a silent drive would be a worse answer than the wrong phrase.
-- PURE, so `zz_horn.spec` drives both words and the unknown one with no sound and no drive.
function Horn.signalPhrase(which: string?, config): SignalPhrase
	local phrases = (config or Horn.CONFIG).SIGNAL.PHRASES
	local row = if which ~= nil then phrases[which] else nil
	return row or phrases[Horn.SIGNAL_DEFAULT]
end

-- HOW LONG ONE PHRASE SOUNDS, from `FROM` to `CUT`. Clamped exactly as `Horn.playSeconds` is, so a
-- row whose two numbers are crossed over cannot ask for a negative wait.
function Horn.signalSeconds(which: string?, config): number
	local phrase = Horn.signalPhrase(which, config)
	return math.max(phrase.CUT - phrase.FROM, 0)
end

-- THE PHRASE AS A PLAN, AND IT IS PURE: one row per sounding, each with the offset from the cue at
-- which it starts, how long it sounds, which asset it comes out of and where in that asset. The
-- client walks it (`Hud.Sound.driveSignal`) and holds no schedule of its own.
--
-- ONE ROW TODAY, AND THE SHAPE IS STILL A LIST ON PURPOSE. Task 163's signal was three notes this
-- code assembled; this one is a RECORDED PHRASE -- *"tuturutu tu tu"* is six quick notes and a held
-- one, played by a bugler, not by us -- so the plan has one entry and the melody is in the asset
-- where a melody belongs. A cue that one day wants a phrase twice, or two phrases back to back, is
-- rows here and no change to the client.
function Horn.signalPlan(which: string?, config): { SignalNote }
	local phrase = Horn.signalPhrase(which, config)
	local seconds = Horn.signalSeconds(which, config)
	return { { at = 0, seconds = seconds, soundId = phrase.SOUND_ID, from = phrase.FROM } }
end

-- EVERY CUE THE SIGNAL HAS, in a stable order, so the one client-side owner can make and PRELOAD a
-- voice for each of them at module load without knowing how many there are (task 163a(a)'s fix,
-- kept: a voice created at the cue plays the clip from 0, because `TimePosition` on an unloaded
-- Sound is not kept).
--
-- DERIVED FROM `SIGNAL.PHRASES` AND NOT WRITTEN OUT (round 1's note, and it was right): a hardcoded
-- pair made `PHRASES`' own claim -- *"a third cue one day is a row here and no code anywhere"* --
-- false, because a third row would never have been made or preloaded. STABLE because the order is
-- decided rather than taken from `pairs`: the drive's own first cue leads, the rest follow sorted.
function Horn.signalWords(config): { string }
	local phrases = (config or Horn.CONFIG).SIGNAL.PHRASES
	local rest = {}
	for word in pairs(phrases) do
		if word ~= Horn.SIGNAL_DEFAULT then
			table.insert(rest, word)
		end
	end
	table.sort(rest)
	local words = {}
	if phrases[Horn.SIGNAL_DEFAULT] ~= nil then
		table.insert(words, Horn.SIGNAL_DEFAULT)
	end
	for _, word in ipairs(rest) do
		table.insert(words, word)
	end
	return words
end

-- Is this the name of the Tool this system owns? Answered off the constant, so no caller carries the
-- literal "Horn" again -- the shape `Weapons.isToolName` already has.
function Horn.isToolName(name: string?): boolean
	return name == Horn.TOOL_NAME
end

-- ---------------------------------------------------------------- the horn at the mouth
--
-- THE ARM RAISE, AND IT LIVES HERE SO THERE IS EXACTLY ONE OF IT (task 168).
--
-- KAREN, 2026-10-12 ~21:45, verbatim: *"We need better horn and we need when I am playing beater to
-- make animation when raising horn to face and blow"*. Task 166 built this pose for the BOTS and put
-- it in `Bots.Rig`, where a player cannot reach it; task 168 moved the numbers and the sequence here,
-- to the file that already owns the other half of the same gesture (`CONFIG.GRIP_BLOW`, the Tool's
-- own tilt). `Bots.Rig.BLOW` and `Bots.Rig.blowSequence` are now aliases of these, so the bots play
-- the pose they played before and nothing is written twice.
--
-- WHO PLAYS IT ON WHAT, because that is the ownership question and it has two answers and no overlap:
--   * a BOT's rig  -- `Bots.Rig`, which owns every clip on a rig's own `Animator` (its gait, its
--     tool pose and this). Unchanged by task 168.
--   * a PLAYER's character -- `Weapon.Horn`, which owns the horn and is the one thing that performs
--     a blast. Nothing else in this repo writes a player character's `Animator` at all, so this is a
--     first writer and not a second one (`Match.Body` dresses the character and stands it somewhere;
--     `Camera.Rig` hides it in first person; neither animates it).
-- IT IS PLAYED ON THE SERVER, which is what makes the two the same mechanism: an animation played on
-- a character's `Animator` server-side replicates to every client, so the other players see the arm
-- come up AND the blower sees it in first person -- where `Camera.Rig` hides the body but deliberately
-- NOT a non-weapon Tool (*"the beater's horn has no viewmodel"*), so what he sees rise into frame is
-- the real horn on the real hand.
--   Animator:LoadAnimation   https://create.roblox.com/docs/reference/engine/classes/Animator
--   KeyframeSequenceProvider https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider
--
-- WHY A SEQUENCE BUILT IN CODE AND NOT AN UPLOADED CLIP: an animation asset id can only be made by
-- hand in Studio's Animation Editor (`tools/boar_prep.py`'s header says so), and
-- `KeyframeSequenceProvider:RegisterKeyframeSequence` is the engine's documented way to make a usable
-- content id without one. Task 166 MEASURED it working here, and measured the three alternatives
-- failing: an `AnimationConstraint.Transform` write moved the hand 0.01 studs, the same write every
-- Heartbeat moved it 0.12, and the rig attachment's own CFrame 0.3 -- because the animator re-solves
-- the joint from the playing tracks every frame. Only another ANIMATION, at a priority above the
-- gait, poses an arm that is already being animated.
Horn.BLOW_POSE = table.freeze({
	-- THE POSE, IN DEGREES. The arm swings forward and in at the shoulder and folds hard at the
	-- elbow, which is what brings the hand up in front of the face -- a bugler's pose. Chosen off a
	-- measured sweep of ten candidates (task 166: this pair put the horn's own mouthpiece nearest
	-- the head) and then LOOKED AT in a screenshot, which is the only thing that settles a pose.
	SHOULDER_DEG = { x = -120, y = 0, z = 15 },
	ELBOW_DEG = { x = -150, y = 0, z = 0 },
	-- UP QUICKLY, DOWN A LITTLE SLOWER, because that is what a person does with an instrument. They
	-- are `AnimationTrack:Play`/`Stop` FADE times and not a hand-rolled ramp: the engine blends the
	-- pose in and out, so "a short raise, a hold, a lower" costs two calls and no per-frame work.
	RAISE_SECONDS = 0.2,
	LOWER_SECONDS = 0.35,
})

-- THE SEQUENCE, BUILT FROM THE NUMBERS. Pure in the sense that matters -- it reads no rig, no
-- service and no state, so a spec can assert the whole pose tree, the weights and the two angles
-- without a character, an Animator or a Play session.
--
-- TWO IDENTICAL KEYFRAMES AND `Loop = true`: a one-keyframe sequence has no length, and a held pose
-- is a loop of one pose. The second keyframe's time is what gives the clip a duration at all.
--
-- ONLY THE SHOULDER AND THE ELBOW ARE OURS. Every other pose carries `Weight = 0`, so the clip says
-- nothing about the torso, the legs or the wrist: the gait keeps the walk, the tool clip keeps the
-- grip, and `Action` priority buys exactly two joints. A sequence that wrote identity over the torso
-- at `Action` would freeze a walking beater's lean for the length of every blast.
--
-- R15 JOINT NAMES, which is what both bodies in this game are: `Bots.Rig` builds R15 rigs, and the
-- place's own avatar type is R15 (MEASURED in a Play session, task 168). A `Pose` is matched by its
-- place in the rig's hierarchy, so on an R6 character these names match nothing and the clip simply
-- poses nothing -- no error and no half-raised arm, which is the right failure for a cosmetic.
function Horn.blowSequence(config): KeyframeSequence
	local blow = config or Horn.BLOW_POSE
	local sequence = Instance.new("KeyframeSequence")
	sequence.Loop = true
	sequence.Priority = Enum.AnimationPriority.Action
	local shoulder = blow.SHOULDER_DEG
	local elbow = blow.ELBOW_DEG
	for _, at in ipairs({ 0, 0.5 }) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = at
		-- THE CHAIN FROM THE ROOT, because a `Pose` is found by its place in the rig's hierarchy and
		-- not by name alone. Everything above the shoulder carries no weight (see above).
		local parent: Instance = keyframe
		for _, name in ipairs({ "HumanoidRootPart", "LowerTorso", "UpperTorso" }) do
			local pose = Instance.new("Pose")
			pose.Name = name
			pose.CFrame = CFrame.identity
			pose.Weight = 0
			pose.Parent = parent
			parent = pose
		end
		local upperArm = Instance.new("Pose")
		upperArm.Name = "RightUpperArm"
		upperArm.CFrame = CFrame.Angles(math.rad(shoulder.x), math.rad(shoulder.y), math.rad(shoulder.z))
		upperArm.Weight = 1
		upperArm.Parent = parent
		local lowerArm = Instance.new("Pose")
		lowerArm.Name = "RightLowerArm"
		lowerArm.CFrame = CFrame.Angles(math.rad(elbow.x), math.rad(elbow.y), math.rad(elbow.z))
		lowerArm.Weight = 1
		lowerArm.Parent = upperArm
		-- THE WRIST IS THE TOOL CLIP'S, so this pose exists only to close the chain and says
		-- nothing about the hand.
		local hand = Instance.new("Pose")
		hand.Name = "RightHand"
		hand.CFrame = CFrame.identity
		hand.Weight = 0
		hand.Parent = lowerArm
		keyframe.Parent = sequence
	end
	return sequence
end

-- THE REGISTERED ID, MADE ONCE PER SESSION AND SHARED BY EVERY BODY THAT BLOWS A HORN -- bots and
-- players both, which is the point of it living here. Registering is a service call, the sequence is
-- the same for everybody, and the id is a string, so one registration serves eight bots and a player.
--
-- A FAILURE IS REMEMBERED, NOT RETRIED. `RegisterKeyframeSequence` is not documented to fail here,
-- but if it ever does -- a future security-context change is the obvious way -- a retry per body per
-- blast would be a service call per body for ever. One attempt, and the arms stay down.
--
-- ITS ONE DOCUMENTED LIMIT IS THAT THE ID IS TEMPORARY AND LOCAL TO THE SESSION, which is exactly
-- what this needs: the pose is rebuilt from the numbers above every time the place runs, so those
-- numbers ARE the animation and there is no asset to keep in step with them.
local blowAnimationId: string? = nil
local blowRegisterTried = false

function Horn.blowAnimationId(config): string?
	if blowAnimationId ~= nil then
		return blowAnimationId
	end
	if blowRegisterTried then
		return nil
	end
	blowRegisterTried = true
	local sequence = Horn.blowSequence(config)
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	sequence:Destroy()
	if not ok or type(id) ~= "string" then
		return nil
	end
	blowAnimationId = id :: string
	return blowAnimationId
end

Shotgun.deepFreeze(Horn.CONFIG)

return Horn
