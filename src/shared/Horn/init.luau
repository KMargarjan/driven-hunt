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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Horn = {}

-- The Tool's name, and also how a stray one is found. It is NOT a row in `Weapons.ROWS`: that
-- table's type is a GUN's -- ranges, pellets, ammo kinds, a cycle -- and a horn has none of them.
-- One row per noise-maker lives here instead.
Horn.TOOL_NAME = "Horn"
Horn.LABEL = "HORN"

-- WHICH TEAM CARRIES IT. The beater's -- and `Match.Body.ROLE_WORDS` is the one translator from
-- Karen's word ("beater") to this team name, so this constant is the TEAM, because that is what
-- `Match.Body.teamOf` answers and what both composition roots compare against.
Horn.TEAM = "Drivers"

export type Piece = {
	name: string,
	size: Vector3,
	offset: CFrame, -- relative to the Handle's centre; -Z is the bell, as GRIP assumes
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType,
	reflectance: number?,
}

-- A real brass signal horn is about 0.35 m end to end, which is 1.25 studs at this game's
-- METRES_PER_STUD. 1.3 is that, rounded to the number the sections below divide cleanly.
local TOTAL = 1.3

Horn.CONFIG = {
	-- ---------------------------------------------------------------- the blast
	--
	-- SECONDS BETWEEN BLASTS, per player, enforced on the SERVER. It is also the rate limit:
	-- `Tool.Activated` is a click, and a click is whatever the client sends, so this is the only
	-- thing standing between one beater and a continuous horn -- the same reasoning as
	-- `Shotgun.CONFIG`'s own rate limits.
	--
	-- THE DIRECTOR'S START VALUE WAS 3, AND THE CLIP SAYS 5 (measured in this task, below): one
	-- click plays one complete CALL of 4.0 s, so a cooldown of 3 would chop the last note in half
	-- and a beater clicking on it would produce one continuous unbroken horn -- which is the exact
	-- thing a cooldown exists to prevent. 5 is the smallest number that fits a whole call with the
	-- clip's own silence after it. It is DATA: one line for Karen or the Director to change, and
	-- `tests/server/horn.spec.luau` only asserts that it is long enough for the cut.
	COOLDOWN = 5,
	-- How long the horn is held up to the mouth. Shorter than the call on purpose: the arm comes
	-- down while the last note is still ringing, which is what a person does.
	BLOW_SECONDS = 3,

	-- ---------------------------------------------------------------- the voice
	--
	-- "Hunting Horn", APMOfficial, IsPublicDomain true, asset type 3 (note section 5.2).
	-- The alternate, measured public the same way and kept here because Karen has not heard either
	-- of them yet and it is a one-line change: "Whistle Calling 4 (SFX)", ProSoundEffects,
	-- rbxassetid://9120675895, 1.0 s -- the whistle the same sources list beside the horn.
	SOUND_ID = "rbxassetid://9038902877",
	VOLUME = 1,
	-- ...AND IT IS SIXTY SECONDS LONG, WHICH THE RESEARCH NOTE COULD NOT KNOW AND THIS TASK
	-- MEASURED. `Sound.TimeLength` is **60.63 s**: the asset is not one blast, it is a vintage
	-- recording of a hunting horn being blown over and over. Played whole, one click would sound a
	-- horn for a minute.
	--
	-- SO THE CLIP IS CUT, AND THE CUT IS MEASURED RATHER THAN GUESSED. `Sound.PlaybackLoudness`
	-- sampled at render rate for 14 s, peak per 0.1 s bucket, in the Forest Test on 2026-10-11:
	--     0.0-0.1  silence (0)              the asset's own lead-in
	--     0.2-4.0  the FIRST CALL (43-453)   a complete four-note signal phrase
	--     4.1-5.0  decaying to silence (142 -> 11)
	--     5.1-8.8  the second call           (so a cut later than 5.1 plays the signal TWICE)
	--     9.0-9.6  silence again, 10.0-     the third call
	-- `SOUND_CUT` is therefore 4.4 -- inside the clip's OWN silence, so the stop cannot click, and
	-- before the second call, so one blast is one signal. `SOUND_START` skips the dead lead-in, so
	-- the horn sounds on the click rather than a fifth of a second after it.
	SOUND_START = 0.12,
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

	-- ---------------------------------------------------------------- the spook
	--
	-- HOW FAR A BLAST PUSHES ANIMALS, IN METRES, with the conversion in the open -- the shape Task
	-- 150 established after a radius written in studs had been compared against distances in metres
	-- for two tasks ("at METRES_PER_STUD 0.28, 120 studs is 33.6 m"). The Director's start value.
	-- Both spellings are written out and `tests/server/horn.spec.luau` asserts they agree to the
	-- stud, so a world or a spec may override either unit and be read.
	METRES_PER_STUD = 0.28, -- the same number `Report.CONFIG` and `Boar.CONFIG.SENSE` publish
	SPOOK_M = 80,
	SPOOK_STUDS = 286, -- 80 m / 0.28

	-- ---------------------------------------------------------------- the hardware
	--
	-- THE HANDLE IS THE ENVELOPE, NOT THE HORN, and it is invisible for the same reason the gun's is
	-- (Task 71): the horn is the welded pieces below, so the Handle's own box would be a slab
	-- through the middle of it. Set HANDLE_TRANSPARENCY to 0 to see the box they are laid out in.
	HANDLE_SIZE = Vector3.new(0.3, 0.3, TOTAL),
	HANDLE_TRANSPARENCY = 1,
	HANDLE_COLOR = Color3.fromRGB(205, 160, 60),
	-- The hand grips just behind the middle, where a horn balances. -Z is the bell, so the bell
	-- points away from the player and the mouthpiece is the end nearest him.
	GRIP = CFrame.new(0, 0, 0.25),
	-- ...AND THE SAME GRIP, TILTED UP, IS THE WHOLE "RAISE TO MOUTH" (the dispatch allows a tilt).
	-- IT IS A GRIP AND NOT AN ANIMATION ON PURPOSE: raising the ARM means writing the character's
	-- Motor6Ds or playing a track on its Animator, and the character already has exactly one writer
	-- per concern (`Match.Body` dresses it, `Camera.Rig` hides it in first person) -- a horn that
	-- animated an arm would be a second one, which CLAUDE.md rule 3 forbids. `Tool.Grip` is the
	-- Tool's own property, the engine rebuilds the grip weld when it changes, and `Weapon.Horn` is
	-- the only thing that ever writes it.
	GRIP_BLOW = CFrame.Angles(math.rad(-55), 0, 0) * CFrame.new(0, 0, 0.25),

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

-- EVERY PIECE OF THE HORN, in build order, for a Handle of `config.HANDLE_SIZE`. PURE: it creates no
-- Instance, reads no service and holds no state, so a spec can assert every proportion with no Tool,
-- no character and no physics. The same division this repo already uses twice -- a pure list plus
-- one builder: `Weapon.Shape` plus `Weapon.Hardware`, and `MapGen.Layout` plus `MapGen.Props`.
--
-- A TAPERED TUBE AND A FLARED BELL, which is what a signal horn is: five sections of growing
-- diameter laid nose to tail along the Handle's own Z, the nickel mouthpiece at the +Z end nearest
-- the player and the bell mouth landing exactly on -Z half.
function Horn.pieces(config): { Piece }
	local look = config.LOOK
	local half = config.HANDLE_SIZE.Z / 2
	-- A cylinder's length runs along its own X, so every section is turned a quarter turn to lie
	-- along Z. The same `lying` rotation `Weapon.Shape` uses for the gun's barrels.
	local lying = CFrame.Angles(0, math.pi / 2, 0)

	local pieces: { Piece } = {}
	-- Laid from the mouthpiece end forwards, each section starting where the last one ended, so the
	-- LENGTHS are the only numbers: no section's centre is a second guess that could leave a gap or
	-- an overlap. `z` tracks the near face of the next piece.
	local z = half
	local function tube(name: string, length: number, diameter: number, color: Color3)
		table.insert(pieces, {
			name = name,
			size = Vector3.new(length, diameter, diameter),
			offset = CFrame.new(0, 0, z - length / 2) * lying,
			color = color,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
			reflectance = 0.15, -- polished
		})
		z -= length
	end

	tube("Mouthpiece", 0.14, 0.14, look.mouthpiece)
	tube("Throat", 0.34, 0.1, look.brass)
	tube("Tube", 0.36, 0.16, look.brass)
	tube("Flare", 0.26, 0.28, look.brass)
	tube("Bell", 0.2, 0.46, look.brass)

	-- THE CARRYING CORD, the one piece that is not the instrument: a signal horn hangs on a cord
	-- round the neck, and without it the object reads as a plumbing fitting. Cosmetic, one block,
	-- slung under the tube.
	table.insert(pieces, {
		name = "Cord",
		size = Vector3.new(0.04, 0.04, 0.52),
		offset = CFrame.new(0, -0.1, 0.18),
		color = look.cord,
		material = Enum.Material.Fabric,
		shape = Enum.PartType.Block,
	})

	return pieces
end

-- THE BELL MOUTH, in the Handle's own frame: where the note comes out, and the point a screenshot is
-- checked against. Derived from HANDLE_SIZE, so it cannot disagree with the `Bell` piece above.
function Horn.bellOffset(config): Vector3
	return Vector3.new(0, 0, -config.HANDLE_SIZE.Z / 2)
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

-- Is this the name of the Tool this system owns? Answered off the constant, so no caller carries the
-- literal "Horn" again -- the shape `Weapons.isToolName` already has.
function Horn.isToolName(name: string?): boolean
	return name == Horn.TOOL_NAME
end

Shotgun.deepFreeze(Horn.CONFIG)

return Horn
