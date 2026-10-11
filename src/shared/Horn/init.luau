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
	-- LOWER AND TO THE RIGHT, which is the first of the two answers the Director offered for the
	-- first-person view (*"hold it lower and to the right, as a hand would, or hide it in first
	-- person until a blast"*). **This task picks HOLD IT**, and the reason is ownership rather than
	-- taste: hiding it until a blast would make `Camera.Rig`'s rule depend on the horn's per-player
	-- blast TIMING, so the camera would have to read weapon state every frame and the horn would pop
	-- in and out of the hand. The rule stays static -- a non-weapon Tool in the hand is visible --
	-- and the horn is simply carried where a carried thing hangs: below the hand and outboard of it,
	-- so it sits in the bottom-right of a right-handed first-person view instead of across it.
	--
	-- THE NUMBERS WERE LOOKED AT, NOT REASONED ABOUT (rule 5). Four candidates were set on a live
	-- horn through `Tool.Grip` and photographed: (-0.12, 0.42, 0.10) filled the bottom-right corner
	-- and cut the bell off; (-0.18, -0.55, 0.10) and (-0.30, -1.00, 0.45) went UP the frame, which
	-- is how the sign of Grip's Y was settled -- POSITIVE Y lowers it; (-0.35, 0.95, 0.45) dropped it
	-- almost entirely below the edge. This one shows about a fifth of the coil in the bottom-right
	-- with the view clear, which is a thing carried at the side.
	GRIP = CFrame.new(-0.8, 0.7, 0.45) * CFrame.Angles(0, 0, math.rad(25)),
	-- ...AND THE SAME GRIP, TILTED UP, IS THE WHOLE "RAISE TO MOUTH" (the dispatch allows a tilt).
	-- IT IS A GRIP AND NOT AN ANIMATION ON PURPOSE: raising the ARM means writing the character's
	-- Motor6Ds or playing a track on its Animator, and the character already has exactly one writer
	-- per concern (`Match.Body` dresses it, `Camera.Rig` hides it in first person) -- a horn that
	-- animated an arm would be a second one, which CLAUDE.md rule 3 forbids. `Tool.Grip` is the
	-- Tool's own property, the engine rebuilds the grip weld when it changes, and `Weapon.Horn` is
	-- the only thing that ever writes it.
	-- ...and the raised pose brings it up and inboard with the mouthpiece turned toward the face.
	-- Photographed the same way, on the same horn, in the same session.
	GRIP_BLOW = CFrame.new(-0.42, 0.05, 0.4) * CFrame.Angles(math.rad(-55), 0, math.rad(25)),

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

-- Is this the name of the Tool this system owns? Answered off the constant, so no caller carries the
-- literal "Horn" again -- the shape `Weapons.isToolName` already has.
function Horn.isToolName(name: string?): boolean
	return name == Horn.TOOL_NAME
end

Shotgun.deepFreeze(Horn.CONFIG)

return Horn
