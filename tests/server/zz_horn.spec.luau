-- zz_horn.spec: THE BEATER'S HORN (task 152)
--
-- `zz_` BECAUSE IT SPENDS REAL SECONDS AND SOMETHING AFTER IT COUNTS THEM. TestEZ runs spec files
-- in name order, `TestKit.TOKEN_MAX_AGE` is 120 s, and `sync.spec` asks whether the gate token is
-- still fresh -- so a file that waits on wall clock and sorts before `s` spends the suite's own
-- budget. MEASURED: as `horn.spec` this file's ~3.5 s of real waiting was enough to fail
-- `sync.spec` with a stale token, so the margin on `main` was under that. It runs last now, with
-- `zz_drive_boundary`, which reads `TestKit.runToken()` and is immune by construction. The budget
-- itself is thin and is not this task's to widen -- it is reported, not quietly absorbed -- what it is made of, who carries it, what a click does,
-- and what a blast does to the animals. Pattern: TestEZ describe/it/expect
-- (https://roblox.github.io/testez/api-reference/).
--
-- THREE HALVES, and the division is deliberate.
--   PURE      the numbers and the geometry: `Horn.pieces`, `Horn.spookStuds`, `Horn.carryAction`,
--             `Horn.readyAt`. No Instance, no player, no world.
--   HARDWARE  a real Tool, built and destroyed here, against a STUB player -- a table carrying the
--             three things this system reads off one (`UserId`, `Character`,
--             `FindFirstChildOfClass`). It never touches the live player: taking a running
--             playtester's tool away broke three client specs once (Task 34) and this spec grants,
--             blows and revokes entirely inside its own Folder.
--   LIVE      a real boar on a real plate, pushed by a real blast through `Runtime:hearHorn`, with
--             the animals OUTSIDE the radius asserted unmoved -- because "everything runs away" and
--             "everything within 80 m runs away" are different features and only the second one was
--             asked for.
--
-- WHAT IS NOT ASSERTED HERE, and is reported rather than hidden: nothing in this repository can load
-- an audio asset in a spec, so no case below can prove the horn makes a NOISE. What the `Sound`'s
-- properties ARE is assertable and that is what the hardware half reads -- the id, the volume, the
-- roll-off mode and the two distances. `IsLoaded`, `TimeLength` and `IsPlaying` are measured in a
-- live Play session instead, and whether 9038902877 sounds like a hunting horn is Karen's judgement
-- (PLAYTEST.md). The same honesty `boar_shot.spec` states at its head.
--
-- Note:   docs/research/2026-10-11-beater-kit.md (section 5)
-- Design: docs/design/beater-kit.md (section 16 item 1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ServerStorage:WaitForChild("Assets"))
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local HornTool = Weapon.Horn
local Hardware = Weapon.Hardware
local CONFIG = Horn.CONFIG

local GROUND_Y = 1040 -- its own plate, clear of boar_body (500), boar_model (620), boar_shot (760)
local PLATE_SPAN = 1400 -- wide enough to hold the 286-stud spook radius AND a boar outside it
local FIELD = {
	-- The bounds have to contain the far boar as well, or it is despawned for leaving rather than
	-- left alone, and the case would pass for the wrong reason.
	bounds = { minX = -700, maxX = 700, minZ = -700, maxZ = 700 },
	exitZ = -690,
	groundY = GROUND_Y,
}

-- Flat distance, which is how every radius in this game is measured: a boar on a hill is not farther
-- from the beater than one on the level.
local function flat2(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

return function()
	local testRoot, plate, toolRoot
	-- The horn left RAISED by the blast case, checked back down by the last case in this file.
	local lowering: any = nil

	-- ONE plate for the whole file, as `boar_shot.spec` does: every case below either needs no world
	-- at all or spawns its own runtime into its own folder under this root.
	beforeAll(function()
		testRoot = Instance.new("Folder")
		testRoot.Name = "HornSpec"
		plate = Instance.new("Part")
		plate.Name = "Plate"
		plate.Size = Vector3.new(PLATE_SPAN, 4, PLATE_SPAN)
		plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
		plate.Anchored = true
		plate.TopSurface = Enum.SurfaceType.Smooth
		plate.Parent = testRoot
		testRoot.Parent = Workspace
		-- ...and a root OUT of the world for the Tool cases: see `newBackpack`.
		toolRoot = Instance.new("Folder")
		toolRoot.Name = "HornSpecTools"
		toolRoot.Parent = ServerStorage
	end)

	afterAll(function()
		if testRoot then
			testRoot:Destroy()
			testRoot = nil
		end
		if toolRoot then
			toolRoot:Destroy()
			toolRoot = nil
		end
	end)

	---------------------------------------------------------------- pure: the numbers

	describe("the horn's numbers", function()
		it("writes the spook radius in metres AND in studs, and the two agree to the stud", function()
			-- TASK 150'S LESSON, pinned: a radius written in studs was compared against distances in
			-- metres for two tasks ("at METRES_PER_STUD 0.28, 120 studs is 33.6 m"). Both spellings
			-- are in the file so either can be overridden; this is what stops them drifting.
			local derived = CONFIG.SPOOK_M / CONFIG.METRES_PER_STUD
			expect(math.abs(CONFIG.SPOOK_STUDS - derived) <= 1).to.equal(true)
			TestKit.note(
				string.format(
					"horn: spook %d m = %.1f studs, written as %d",
					CONFIG.SPOOK_M,
					derived,
					CONFIG.SPOOK_STUDS
				)
			)
		end)

		it("uses the same metres-per-stud as the rest of the game", function()
			-- One conversion in the repo, not one per system. `Report.CONFIG` publishes it and
			-- `Boar.CONFIG.SENSE` carries the same number; a horn with its own would make a radius
			-- in metres mean two different distances.
			expect(CONFIG.METRES_PER_STUD).to.equal(Report.CONFIG.METRES_PER_STUD)
			expect(CONFIG.METRES_PER_STUD).to.equal(Boar.CONFIG.SENSE.METRES_PER_STUD)
		end)

		it("carries at least as far as a gun is heard", function()
			-- A beater nobody can hear is not a signal: the roll-off's far edge is the shot's own
			-- audible radius.
			expect(CONFIG.ROLLOFF_MAX_STUDS >= Boar.CONFIG.SENSE.SHOT_AUDIBLE_STUDS).to.equal(true)
			expect(CONFIG.ROLLOFF_MIN_STUDS < CONFIG.ROLLOFF_MAX_STUDS).to.equal(true)
		end)

		it("resolves the radius from either unit", function()
			expect(Horn.spookStuds(CONFIG)).to.equal(CONFIG.SPOOK_STUDS)
			-- A world that overrides the STUDS means the studs...
			expect(Horn.spookStuds({ SPOOK_STUDS = 40, SPOOK_M = 999, METRES_PER_STUD = 0.28 })).to.equal(40)
			-- ...and one that gives only metres gets them converted here, in the one place that does
			-- it, so no caller ever multiplies by METRES_PER_STUD itself.
			-- To the stud, not to the bit: 28 / 0.28 is 99.99999999999999 in binary floating point,
			-- which the first version of this case asserted was 100 and the gate corrected.
			expect(math.abs(Horn.spookStuds({ SPOOK_M = 28, METRES_PER_STUD = 0.28 }) - 100) < 1e-6).to.equal(true)
		end)

		it("blows for less time than its own cooldown", function()
			-- Otherwise the grip restore and the next blast race, and the horn can stick at the
			-- player's chin. The guard in `Horn.blow` covers it; this keeps the data honest.
			expect(CONFIG.BLOW_SECONDS < CONFIG.COOLDOWN).to.equal(true)
		end)

		it("cuts one call out of a sixty-second recording, and the cooldown fits it", function()
			-- MEASURED, 2026-10-11: the asset is 60.63 s of a hunting horn blown over and over, and
			-- its first call runs 0.2-4.0 s with the clip's own silence at 4.1-5.0 and the SECOND
			-- call starting at 5.1. The data file carries the loudness profile that says so.
			expect(CONFIG.SOUND_START > 0).to.equal(true) -- past the asset's dead lead-in
			expect(CONFIG.SOUND_CUT > CONFIG.SOUND_START).to.equal(true)
			-- A cut at or past 5.1 would play the signal TWICE on one click, which is the one
			-- mistake these two numbers exist to prevent.
			expect(CONFIG.SOUND_CUT < 5.1).to.equal(true)
			expect(Horn.playSeconds(CONFIG)).to.equal(CONFIG.SOUND_CUT - CONFIG.SOUND_START)
			-- ...AND ONE BLAST FINISHES BEFORE THE NEXT MAY START. Without this a beater clicking on
			-- the cooldown produces one continuous unbroken horn -- and it is why the cooldown is 5
			-- and not the 3 the dispatch started from.
			expect(Horn.playSeconds(CONFIG) <= CONFIG.COOLDOWN).to.equal(true)
			TestKit.note(
				string.format(
					"horn: clip 60.63 s, playing %.2f-%.2f s (%.2f s), cooldown %.1f s",
					CONFIG.SOUND_START,
					CONFIG.SOUND_CUT,
					Horn.playSeconds(CONFIG),
					CONFIG.COOLDOWN
				)
			)
		end)
	end)

	---------------------------------------------------------------- pure: the drive's signal

	-- TASK 166. KAREN, 2026-10-12 ~16:00, having heard task 163's version: *"for beater yes it's ok /
	-- for start and end of drive has to be tuturutu tu tu different one"*. So the drive's signal is
	-- now a BUGLE FANFARE out of the free library -- one phrase per cue, a different asset from the
	-- beater's horn -- and these cases are what hold its two cuts to the measurements. Every case is
	-- pure: no Tool, no sound, no drive.
	describe("the drive's own signal", function()
		local SIGNAL = CONFIG.SIGNAL

		it("is one phrase per cue, keyed by the server's own word", function()
			-- `Match.Phase` emits a `signal` feed entry whose text is "start" or "end" and nothing
			-- else, and `Horn.signalWords` is that list: a word with no row would be a cue that
			-- cannot sound.
			local words = Horn.signalWords()
			expect(#words).to.equal(2)
			for _, word in ipairs(words) do
				expect(SIGNAL.PHRASES[word]).to.be.ok()
				-- ONE ROW IN THE PLAN, because the melody is in the ASSET: a recorded phrase, not
				-- three notes this repo assembles (which is what task 163 did and what Karen heard).
				expect(#Horn.signalPlan(word, CONFIG)).to.equal(1)
			end
		end)

		it("is a DIFFERENT sound from the beater's horn, which is Karen's actual correction", function()
			-- *"for beater yes it's ok / for start and end of drive has to be ... different one"*.
			-- The beep stays on 9038902877 ("Hunting Horn"); both phrases are bugle calls.
			for _, word in ipairs(Horn.signalWords()) do
				expect(Horn.signalPhrase(word, CONFIG).SOUND_ID).never.to.equal(CONFIG.SOUND_ID)
			end
			-- ...and the two cues differ from EACH OTHER too: the end is a variation, not a repeat.
			expect(Horn.signalPhrase("start", CONFIG).SOUND_ID).never.to.equal(
				Horn.signalPhrase("end", CONFIG).SOUND_ID
			)
		end)

		it("cuts each phrase inside its own measured clip", function()
			-- MEASURED, 2026-10-12, in a Play session: every candidate's `Sound.TimeLength` and then
			-- its `PlaybackLoudness` at 0.05 s buckets (research note sections 2 and 3). A cut past
			-- the end of the asset plays silence; a cut that starts after it ends plays nothing.
			for _, word in ipairs(Horn.signalWords()) do
				local phrase = Horn.signalPhrase(word, CONFIG)
				expect(phrase.FROM >= 0).to.equal(true)
				expect(phrase.CUT > phrase.FROM).to.equal(true)
				expect(phrase.CUT <= phrase.CLIP_SECONDS).to.equal(true)
				expect(Horn.signalSeconds(word, CONFIG)).to.equal(phrase.CUT - phrase.FROM)
				-- THE CUT STARTS AFTER THE ASSET'S OWN LEAD-IN SILENCE and not at 0: both clips
				-- open with silence (0.00-0.40 and 0.00-0.30 measured), so a phrase played from 0
				-- is a signal that starts late and is cut off at the end.
				expect(phrase.FROM > 0).to.equal(true)
			end
		end)

		it("carries the asset and the offset in the PLAN, so the client holds no numbers", function()
			for _, word in ipairs(Horn.signalWords()) do
				local phrase = Horn.signalPhrase(word, CONFIG)
				local row = Horn.signalPlan(word, CONFIG)[1]
				expect(row.at).to.equal(0) -- the phrase is on the cue
				expect(row.seconds).to.equal(Horn.signalSeconds(word, CONFIG))
				expect(row.soundId).to.equal(phrase.SOUND_ID)
				expect(row.from).to.equal(phrase.FROM)
			end
			TestKit.note(
				string.format(
					"horn: beep %.2f s (%.2f-%.2f) on %s; start fanfare %.2f s (%.2f-%.2f of %.2f) on %s; end %.2f s (%.2f-%.2f of %.2f) on %s; volume %.1f",
					Horn.playSeconds(CONFIG),
					CONFIG.SOUND_START,
					CONFIG.SOUND_CUT,
					CONFIG.SOUND_ID,
					Horn.signalSeconds("start", CONFIG),
					SIGNAL.PHRASES.start.FROM,
					SIGNAL.PHRASES.start.CUT,
					SIGNAL.PHRASES.start.CLIP_SECONDS,
					SIGNAL.PHRASES.start.SOUND_ID,
					Horn.signalSeconds("end", CONFIG),
					SIGNAL.PHRASES["end"].FROM,
					SIGNAL.PHRASES["end"].CUT,
					SIGNAL.PHRASES["end"].CLIP_SECONDS,
					SIGNAL.PHRASES["end"].SOUND_ID,
					SIGNAL.VOLUME
				)
			)
		end)

		it("is LONGER than the beater's beep, because a signal is not a beep", function()
			-- The Tool's blast is one short note (*"short one like beeep"*, task 154); a drive
			-- signal no longer than it would not read as a signal. Both phrases clear it.
			for _, word in ipairs(Horn.signalWords()) do
				expect(Horn.signalSeconds(word, CONFIG) > Horn.playSeconds(CONFIG)).to.equal(true)
			end
		end)

		it("answers an unknown or missing word with the start phrase, never with nothing", function()
			-- A cue that reached the data is a drive asking to be signalled, so the one thing this
			-- lookup must not do is go silent. `Horn.SIGNAL_DEFAULT` is the word it falls back to.
			expect(Horn.SIGNAL_DEFAULT).to.equal("start")
			local fallback = Horn.signalPhrase("Scoring", CONFIG)
			expect(fallback.SOUND_ID).to.equal(SIGNAL.PHRASES.start.SOUND_ID)
			expect(Horn.signalPhrase(nil, CONFIG).SOUND_ID).to.equal(SIGNAL.PHRASES.start.SOUND_ID)
			expect(Horn.signalSeconds(nil, CONFIG)).to.equal(Horn.signalSeconds("start", CONFIG))
		end)

		it("fits inside both of the phases it is played at the edge of", function()
			-- The start signal begins as `Assigning` ends and the end signal as `Scoring` begins, so
			-- a signal longer than a drive's intermission or its results scene would still be
			-- sounding when the next thing happens. 2.18 s and 1.68 s against 15 s and 25 s.
			local Match = require(ServerScriptService:WaitForChild("Match"))
			for _, word in ipairs(Horn.signalWords()) do
				expect(Horn.signalSeconds(word, CONFIG) < Match.CONFIG.INTERMISSION_SECONDS).to.equal(true)
				expect(Horn.signalSeconds(word, CONFIG) < Match.CONFIG.SCORE_SECONDS).to.equal(true)
			end
		end)

		it("is clamped, so a crossed-over cut cannot ask for a negative wait", function()
			-- The shape `Horn.playSeconds` already has: a world or a spec may override either number
			-- and the player must not be handed a negative `task.wait`.
			local crossed = {
				SIGNAL = {
					VOLUME = 1,
					PHRASES = {
						start = { SOUND_ID = "rbxassetid://1", FROM = 9, CUT = 1, CLIP_SECONDS = 10 },
					},
				},
			}
			expect(Horn.signalSeconds("start", crossed)).to.equal(0)
			expect(Horn.signalPlan("start", crossed)[1].seconds).to.equal(0)
		end)

		it("is heard at a volume of its own, because a bugle recording is quieter", function()
			-- MEASURED, the same way for all three: the start fanfare's held note peaks at 56 of
			-- 1000, task 163's hunting-horn note at 214 and the beater's beep at 418 (research note
			-- section 3). So the signal needs MORE Volume than 1 to arrive as present as the one
			-- Karen heard this morning, and more than the Hud's other cues.
			expect(SIGNAL.VOLUME > 1).to.equal(true)
			-- ...and inside what the engine takes. 10 is `Sound.Volume`'s documented maximum.
			expect(SIGNAL.VOLUME <= 10).to.equal(true)
		end)
	end)

	---------------------------------------------------------------- pure: the geometry

	describe("what the horn is made of", function()
		-- A cylinder's length runs along its own X, so its two ends are its centre pushed half a
		-- length each way along that axis. Everything below is measured off the piece list alone.
		local function endsOf(piece): (Vector3, Vector3)
			local half = piece.size.X / 2
			return (piece.offset * CFrame.new(-half, 0, 0)).Position, (piece.offset * CFrame.new(half, 0, 0)).Position
		end

		local function byName(pieces)
			local out = {}
			for _, piece in ipairs(pieces) do
				out[piece.name] = piece
			end
			return out
		end

		local function tubes(pieces)
			local out = {}
			for index = 1, Horn.arc().segments do
				local piece = byName(pieces)[string.format("Tube%d", index)]
				expect(piece).to.be.ok()
				table.insert(out, piece)
			end
			return out
		end

		it("is a COIL and not a straight tube", function()
			-- KAREN'S CORRECTION, as a number (the Director, 2026-10-11: the first build *"reads as a
			-- straight brass tube / spyglass"*). A real Fuerst-Pless or Parforce horn is a wound tube,
			-- so the sections must actually TURN -- and this is the case that fails if somebody
			-- straightens them again.
			local arc = Horn.arc()
			local sections = tubes(Horn.pieces(CONFIG))
			expect(#sections).to.equal(arc.segments)

			local turn = 0
			local previous: Vector3? = nil
			for _, piece in ipairs(sections) do
				local a, b = endsOf(piece)
				local dir = (b - a).Unit
				if previous ~= nil then
					local step = math.deg(math.acos(math.clamp((previous :: Vector3):Dot(dir), -1, 1)))
					-- Every joint bends, and by the same amount: a 230-degree arc in 5 chords.
					expect(math.abs(step - arc.degrees / arc.segments) < 1).to.equal(true)
					turn += step
				end
				previous = dir
			end
			-- ...AND THE WHOLE THING TURNS MOST OF THE WAY ROUND. A straight tube scores 0 here.
			expect(turn > 150).to.equal(true)
			TestKit.note(
				string.format(
					"horn: %d section(s) over a %d-degree arc of radius %.2f; total turn %.0f degrees",
					arc.segments,
					arc.degrees,
					arc.radius,
					turn
				)
			)
		end)

		it("rides one arc, nose to tail, with no gap at any joint", function()
			-- Each section is a CHORD between two points ON the arc, so the joints cannot gap however
			-- the numbers move. Both halves are asserted: consecutive ends meet, and every end is at
			-- the arc's own radius from the Handle's origin.
			local arc = Horn.arc()
			local sections = tubes(Horn.pieces(CONFIG))
			local previousEnd: Vector3? = nil
			for _, piece in ipairs(sections) do
				local a, b = endsOf(piece)
				expect(math.abs(a.Magnitude - arc.radius) < 1e-5).to.equal(true)
				expect(math.abs(b.Magnitude - arc.radius) < 1e-5).to.equal(true)
				if previousEnd ~= nil then
					expect(((previousEnd :: Vector3) - a).Magnitude < 1e-5).to.equal(true)
				end
				previousEnd = b
			end
			-- ...and the two ends of the run are the two ends the module publishes.
			local firstA = select(1, endsOf(sections[1]))
			expect((firstA - arc.from).Magnitude < 1e-5).to.equal(true)
			expect(((previousEnd :: Vector3) - arc.to).Magnitude < 1e-5).to.equal(true)
		end)

		it("widens from the mouthpiece to the bell", function()
			local pieces = Horn.pieces(CONFIG)
			local sections = tubes(pieces)
			for index = 2, #sections do
				expect(sections[index].size.Y > sections[index - 1].size.Y).to.equal(true)
			end
			-- ...AND THE BELL IS THE WIDEST THING ON IT, through a flare and not as a bare step.
			local named = byName(pieces)
			expect(named.Flare.size.Y > sections[#sections].size.Y).to.equal(true)
			expect(named.Bell.size.Y > named.Flare.size.Y).to.equal(true)
			TestKit.note(
				string.format(
					"horn: %d piece(s), bore %.2f -> %.2f studs, bell %.2f",
					#pieces,
					sections[1].size.Y,
					sections[#sections].size.Y,
					named.Bell.size.Y
				)
			)
		end)

		it("hangs the flare and the bell off the arc's far end, and the mouthpiece off its near one", function()
			local arc = Horn.arc()
			local named = byName(Horn.pieces(CONFIG))
			-- The flare starts where the tube ends...
			local flareA = select(1, endsOf(named.Flare))
			expect((flareA - arc.to).Magnitude < 1e-5).to.equal(true)
			-- ...the bell starts where the flare ends, and its outer face is what `bellOffset` says.
			local flareB = select(2, endsOf(named.Flare))
			local bellA, bellB = endsOf(named.Bell)
			expect((bellA - flareB).Magnitude < 1e-5).to.equal(true)
			expect((bellB - Horn.bellOffset(CONFIG)).Magnitude < 1e-5).to.equal(true)
			-- ...and the cup sits just outside the near end, tangent to it.
			local mouthB = select(2, endsOf(named.Mouthpiece))
			expect((mouthB - arc.from).Magnitude < 0.06).to.equal(true)
		end)

		it("is brass with a nickel mouthpiece and a cloth cord", function()
			local named = byName(Horn.pieces(CONFIG))
			expect(named.Bell.color).to.equal(CONFIG.LOOK.brass)
			expect(named.Mouthpiece.color).to.equal(CONFIG.LOOK.mouthpiece)
			-- The one piece that is not the instrument, and it must not be metal.
			expect(named.Cord.material).to.equal(Enum.Material.Fabric)
			-- It closes the C: from the mouthpiece end to the bell end, which is how the real object
			-- is carried and what stops the coil reading as a broken ring.
			local arc = Horn.arc()
			local a, b = endsOf(named.Cord)
			expect(((a - arc.from).Magnitude < 1e-5 and (b - arc.to).Magnitude < 1e-5)).to.equal(true)
		end)

		it("points its bell away from the player", function()
			-- -Z is forward, which is what `GRIP` assumes: a horn whose bell faces the player's own
			-- face is a different object.
			expect(Horn.bellOffset(CONFIG).Z < 0).to.equal(true)
			expect(Horn.arc().bellDir.Z < 0).to.equal(true)
			-- ...and the raised grip is a real change, not a copy of the resting one.
			expect(CONFIG.GRIP_BLOW).never.to.equal(CONFIG.GRIP)

			-- ...AND THE ARM POSE IS THE OTHER HALF OF THE SAME GESTURE, and lives here with it since
			-- task 168 so that a player and a bot raise one arm and not two (`Bots.Rig.BLOW` is an
			-- alias of this). The pose tree is asserted in `bots_lane.spec`, which drove it when it
			-- was `Rig`'s; what this states is that the two files are looking at ONE table.
			local Rig = require(ServerScriptService:WaitForChild("Bots")).Rig
			expect(Rig.BLOW).to.equal(Horn.BLOW_POSE)
			expect(Rig.blowSequence).to.equal(Horn.blowSequence)
			expect(Horn.BLOW_POSE.RAISE_SECONDS > 0).to.equal(true)
			expect(Horn.BLOW_POSE.LOWER_SECONDS > Horn.BLOW_POSE.RAISE_SECONDS).to.equal(true)
			-- THE WHOLE RAISE FITS INSIDE A BLAST: the arm is up, held and down again before the
			-- cooldown lets him blow a second time, which is what stops a horn stuck at the chin.
			expect(Horn.BLOW_POSE.RAISE_SECONDS + Horn.BLOW_POSE.LOWER_SECONDS < CONFIG.COOLDOWN).to.equal(true)
		end)
	end)

	---------------------------------------------------------------- pure: the two decisions

	-- ---------------------------------------------------------------- the uploaded horn (task 169)
	describe("the uploaded horn", function()
		it("has a manifest row, approved, under the key the horn names", function()
			local row = Assets.byKey(Horn.ASSET_KEY)
			expect(row).to.be.ok()
			local found = row :: any
			expect(found.kind).to.equal("meshpart")
			expect(found.moderation).to.equal("approved")
			expect(found.modelId > 0).to.equal(true)
			-- ONE COPY OF EACH NUMBER. The row reads its geometry out of `Horn.MESH`, so a tweak to
			-- the horn's own data file cannot leave the manifest describing a different horn.
			expect(found.sizeStuds).to.equal(Horn.MESH.SIZE_STUDS)
			expect(found.naturalSizeStuds).to.equal(Horn.MESH.NATURAL_SIZE_STUDS)
			expect(found.rotationDeg).to.equal(Horn.MESH.ROTATION_DEG)
			expect(found.offsetStuds).to.equal(Horn.MESH.OFFSET_STUDS)
		end)

		it("is scaled UNIFORMLY, so the horn in the hand is the horn that was looked at", function()
			-- A NON-UNIFORM FIT IS A SQUASHED HORN THAT MEASURES PERFECTLY (`Hardware.addMesh`'s own
			-- warning). The consumer writes `Size = sizeStuds` onto a MeshPart, which scales the mesh
			-- to that box per axis -- so the three ratios have to be the mesh's own three ratios.
			local natural = Horn.MESH.NATURAL_SIZE_STUDS
			local size = Horn.MESH.SIZE_STUDS
			local scale = size.X / natural.X
			expect(math.abs(size.Y / natural.Y - scale) < 1e-3).to.equal(true)
			expect(math.abs(size.Z / natural.Z - scale) < 1e-3).to.equal(true)
			-- ...AND IT IS A REAL HORN. The Director asked for ~25-35 cm across; `METRES_PER_STUD` is
			-- the conversion this game publishes, so the check is in metres rather than in studs.
			local metres = size.X * CONFIG.METRES_PER_STUD
			expect(metres >= 0.2).to.equal(true)
			expect(metres <= 0.4).to.equal(true)
			TestKit.note(
				string.format(
					"horn mesh: %.2f studs (%.2f m), natural %s, uniform x%.5f",
					size.X,
					metres,
					tostring(natural),
					scale
				)
			)
		end)

		it("credits its author, which is the whole of what its licence asks", function()
			-- CC-BY-4.0: "Author must be credited. Commercial use is allowed." A credit that lives
			-- only in CREDITS.md is one a code change can quietly outlive, so the row carries it and
			-- this case is what keeps it there.
			local licence = (Assets.byKey(Horn.ASSET_KEY) :: any).licence
			expect(licence).to.be.ok()
			expect(licence.basis).to.equal("cc-by-4.0")
			expect(typeof(licence.attribution)).to.equal("string")
			expect(string.find(licence.attribution, "r4ulp3rcy", 1, true) ~= nil).to.equal(true)
			expect(string.find(licence.attribution, "CC-BY-4.0", 1, true) ~= nil).to.equal(true)
		end)
	end)

	describe("who carries one, and when it may sound", function()
		it("grants to a beater who has none and revokes from anyone else who has one", function()
			expect(HornTool.carryAction(true, false)).to.equal("grant")
			expect(HornTool.carryAction(false, true)).to.equal("revoke")
			-- The two no-ops, which is what makes the sweep idempotent.
			expect(HornTool.carryAction(true, true)).to.equal(nil)
			expect(HornTool.carryAction(false, false)).to.equal(nil)
		end)

		it("is born OFF, and both worlds are reachable by parameter", function()
			-- A NEW FEEL-CRITICAL PATH IS BORN OFF (CLAUDE.md), and this one was not in round 1 --
			-- which the Director's gate is what showed: `test2` fails on this branch where `main`
			-- passes, and with no switch the only A/B available was an uncommitted edit. OFF, nobody
			-- is granted anything and the drive is bit-for-bit the game before this task.
			local row = Flags.DEFAULTS[Horn.FLAG]
			expect(row).to.be.ok()
			expect(row.default).to.equal(false)
			-- ...and the predicate the composition roots call is PURE in the flag, so the ON world is
			-- testable while the flag sits at OFF -- the only permitted shape.
			expect(Horn.carriesFor(true, Horn.TEAM)).to.equal(true)
			expect(Horn.carriesFor(false, Horn.TEAM)).to.equal(false)
			expect(Horn.carriesFor(true, "Shooters")).to.equal(false)
			expect(Horn.carriesFor(true, nil)).to.equal(false)
		end)

		it("gives a beater the horn and NOT a gun, and everybody else the other way round", function()
			-- KAREN, 2026-10-10: *"so horn will be default tool for beater"*. Task 154's measured
			-- bug: in the Forest Test's first beater playtest she spawned
			-- `tools=[HAND:Shotgun,BAG:Rifle,BAG:Horn]`, because the world's arming policy was
			-- `return true` for everybody while the horn's carry policy already knew about teams.
			-- Two policies answering "which role is this player" is how they came to disagree, so
			-- `Horn.gunFor` is the exact complement of `Horn.carriesFor` and lives beside it.
			-- NO `nil` IN THIS LIST, and that is deliberate rather than an omission: a trailing nil
			-- in a Luau table literal is not an element -- the length is 3 -- so a case that put it
			-- here would quietly test nothing. The no-team player is asserted on its own below.
			for _, team in { Horn.TEAM, "Shooters", "Spectators" } do
				-- With the flag ON the two are complements for every team: the horn XOR the gun.
				expect(Horn.carriesFor(true, team)).to.equal(not Horn.gunFor(team))
			end
			expect(Horn.carriesFor(true, nil)).to.equal(not Horn.gunFor(nil))
			expect(Horn.carriesFor(true, Horn.TEAM)).to.equal(true)
			expect(Horn.gunFor(Horn.TEAM)).to.equal(false)
			expect(Horn.gunFor("Shooters")).to.equal(true)
			-- NO TEAM IS NOT A BEATER, so a player the drive has not placed yet carries a gun and
			-- no horn, which is what this world did before task 152 and still does.
			expect(Horn.gunFor(nil)).to.equal(true)

			-- ...AND THE GUN DOES NOT FOLLOW THE FLAG. With the horn switched OFF a beater carries
			-- no horn, and she still carries no gun: the flag decides whether the HORN exists, not
			-- who is a beater. Otherwise turning the horn off would silently arm the drive.
			expect(Horn.carriesFor(false, Horn.TEAM)).to.equal(false)
			expect(Horn.gunFor(Horn.TEAM)).to.equal(false)
		end)

		it("holds a blast to the cooldown", function()
			expect(HornTool.readyAt(nil, 100)).to.equal(true)
			expect(HornTool.readyAt(100, 100)).to.equal(false)
			expect(HornTool.readyAt(100, 100 + CONFIG.COOLDOWN - 0.01)).to.equal(false)
			expect(HornTool.readyAt(100, 100 + CONFIG.COOLDOWN)).to.equal(true)
		end)
	end)

	---------------------------------------------------------------- hardware: a real Tool

	describe("the Tool", function()
		-- THE STUB PLAYER: the three things this system reads off a Player, and nothing else. The
		-- design named this seam for the outfit (beater-kit section 5) and it is the same one here.
		local function stubPlayer(backpack: Instance?, character: Instance?, userId: number): any
			return {
				UserId = userId,
				Name = "HornSpecStub",
				Character = character,
				FindFirstChildOfClass = function(_self, class: string)
					if class == "Backpack" then
						return backpack
					end
					return nil
				end,
			}
		end

		-- THE STUB BACKPACK LIVES IN ServerStorage, NOT IN Workspace, AND THAT IS NOT TIDINESS.
		-- A Sound only plays while it has an ancestry in the world, so a blast fired from a horn in
		-- Workspace would be AUDIBLE for its 4.3 s during every gate run -- and `boar_shot.spec`
		-- asserts how many Sounds are playing in this place at once. A spec must not make a noise
		-- another spec counts.
		local function newBackpack(): Instance
			local backpack = Instance.new("Folder")
			backpack.Name = "Backpack"
			backpack.Parent = toolRoot
			return backpack
		end

		-- THE TEMPLATE SEAM, BORROWED AND PUT BACK (task 169). `Hardware.setTemplateProvider` is
		-- global and the running server's own horns are built through it, so a spec that leaves it
		-- nil leaves every later grant wearing the parts horn for the rest of the session --
		-- `WeaponBoot`'s own header measured that exact failure on the gun (task 76). Save, set,
		-- restore, and rethrow afterwards.
		local function withProvider(fn, body)
			local live = Hardware.getTemplateProvider()
			Hardware.setTemplateProvider(fn)
			local ok, why = pcall(body)
			Hardware.setTemplateProvider(live)
			if not ok then
				error(why, 0)
			end
		end

		-- ONE FAKE UPLOAD, SIZED AS THE MANIFEST SAYS THE REAL ONE ARRIVES. `assets_seam.spec` builds
		-- its gun templates this way for the reason this one does: a spec may not reach the network,
		-- and what is being asserted is what the CONSUMER does with a template, not that Roblox can
		-- hand one over.
		local function fakeTemplate(): (MeshPart, any)
			local row = Assets.byKey(Horn.ASSET_KEY)
			local template = Instance.new("MeshPart")
			template.Size = (row :: any).naturalSizeStuds
			return template, row
		end

		it("builds a horn from parts when there is no uploaded horn to wear", function()
			local tool
			withProvider(nil, function()
				tool = HornTool.build()
			end)
			expect(tool:IsA("Tool")).to.equal(true)
			expect(tool.Name).to.equal(Horn.TOOL_NAME)
			expect(tool.RequiresHandle).to.equal(true)
			expect(tool.CanBeDropped).to.equal(false)
			expect(tool.Grip).to.equal(CONFIG.GRIP)

			local handle = tool:FindFirstChild("Handle") :: BasePart
			expect(handle).to.be.ok()
			expect(handle.Transparency).to.equal(CONFIG.HANDLE_TRANSPARENCY)
			expect(handle.CanCollide).to.equal(false)
			expect(handle.Massless).to.equal(true)

			-- EVERY PIECE THE PURE LIST NAMES, each with its weld, and NOTHING loaded: a MeshPart
			-- here would mean somebody wired an asset into a horn the design says is built in code.
			local meshes = 0
			for _, piece in ipairs(Horn.pieces(CONFIG)) do
				local part = handle:FindFirstChild(piece.name) :: BasePart
				expect(part).to.be.ok()
				expect(part.Size).to.equal(piece.size)
				expect(part.Shape).to.equal(piece.shape)
				expect(handle:FindFirstChild(piece.name .. "Weld")).to.be.ok()
			end
			for _, descendant in ipairs(tool:GetDescendants()) do
				if descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
					meshes += 1
				end
			end
			expect(meshes).to.equal(0)
			tool:Destroy()
		end)

		it("wears the uploaded horn when the template is there, and no parts under it", function()
			local template, row = fakeTemplate()
			local tool
			withProvider(function()
				return template, { row = row }
			end, function()
				tool = HornTool.build()
			end)
			local handle = tool:FindFirstChild("Handle") :: BasePart
			local worn = handle:FindFirstChild(HornTool.MESH_NAME) :: BasePart
			expect(worn).to.be.ok()
			-- THE CONSUMER SETS THE SIZE (design 6.1), from the row and not from the template.
			expect(worn.Size).to.equal(Horn.MESH.SIZE_STUDS)
			-- Scenery, exactly as the gun's mesh is: nothing a ray can hit, nothing with mass.
			expect(worn.CanQuery).to.equal(false)
			expect(worn.CanCollide).to.equal(false)
			expect(worn.Massless).to.equal(true)
			expect(handle:FindFirstChild(HornTool.MESH_NAME .. "Weld")).to.be.ok()
			-- ...AND THE FALLBACK IS NOT ALSO THERE. Nine brass cylinders inside an ivory horn is
			-- the one shape this seam exists to make impossible.
			for _, piece in ipairs(Horn.pieces(CONFIG)) do
				expect(handle:FindFirstChild(piece.name)).to.equal(nil)
			end
			tool:Destroy()
			template:Destroy()
		end)

		it("upgrades a parts horn into the mesh when the template lands later", function()
			-- A HORN BUILT BEFORE THE PRELOAD LANDED, which is not a corner case: `WeaponBoot` starts
			-- the systems BEFORE it preloads, on purpose, so a player who joins in that window is
			-- handed one of these.
			local tool
			withProvider(nil, function()
				tool = HornTool.build()
			end)
			local handle = tool:FindFirstChild("Handle") :: BasePart
			expect(handle:FindFirstChild(HornTool.MESH_NAME)).to.equal(nil)
			expect(handle:FindFirstChild("Bell")).to.be.ok()

			local template, row = fakeTemplate()
			withProvider(function()
				return template, { row = row }
			end, function()
				expect(HornTool.addMesh(handle)).to.equal(true)
				-- ...and the fallback comes off, BY NAME, and only the fallback.
				expect(HornTool.removeParts(handle) > 0).to.equal(true)
				-- IDEMPOTENT: asking again welds no second horn on.
				expect(HornTool.addMesh(handle)).to.equal(true)
			end)
			local worn = handle:FindFirstChild(HornTool.MESH_NAME) :: BasePart
			expect(worn).to.be.ok()
			expect(worn.Size).to.equal(Horn.MESH.SIZE_STUDS)
			local models = 0
			for _, child in ipairs(handle:GetChildren()) do
				if child.Name == HornTool.MESH_NAME then
					models += 1
				end
			end
			expect(models).to.equal(1)
			for _, piece in ipairs(Horn.pieces(CONFIG)) do
				expect(handle:FindFirstChild(piece.name)).to.equal(nil)
				expect(handle:FindFirstChild(piece.name .. "Weld")).to.equal(nil)
			end
			-- The voice survives the upgrade: it is not a piece of the horn and is not named by the
			-- pure list, so `removeParts` must not be able to reach it.
			expect(handle:FindFirstChild(HornTool.SOUND_NAME)).to.be.ok()
			tool:Destroy()
			template:Destroy()
		end)

		it("hangs its voice on the Handle, so the blast is 3D", function()
			local tool = HornTool.build()
			local handle = tool:FindFirstChild("Handle") :: BasePart
			local sound = handle:FindFirstChild(HornTool.SOUND_NAME) :: Sound
			expect(sound).to.be.ok()
			expect(sound:IsA("Sound")).to.equal(true)
			-- A Sound's PARENT is what makes it positional: parented to the Handle, everybody near
			-- the beater hears it from where he stands. The properties are assertable; the noise is
			-- not (see this file's head).
			expect(sound.Parent).to.equal(handle)
			expect(sound.SoundId).to.equal(CONFIG.SOUND_ID)
			expect(sound.Volume).to.equal(CONFIG.VOLUME)
			expect(sound.RollOffMode).to.equal(CONFIG.ROLLOFF_MODE)
			expect(sound.RollOffMinDistance).to.equal(CONFIG.ROLLOFF_MIN_STUDS)
			expect(sound.RollOffMaxDistance).to.equal(CONFIG.ROLLOFF_MAX_STUDS)
			expect(sound.Looped).to.equal(false)
			TestKit.note(
				string.format(
					"horn: voice %s, %s, %d-%d studs",
					sound.SoundId,
					tostring(sound.RollOffMode),
					sound.RollOffMinDistance,
					sound.RollOffMaxDistance
				)
			)
			tool:Destroy()
		end)

		it("gives one horn and only one, and takes it back", function()
			local backpack = newBackpack()
			local player = stubPlayer(backpack, nil, 152001)
			local restore = HornTool.setCarryPolicy(function()
				return true
			end)

			expect(HornTool.held(player)).to.equal(nil)
			local first = HornTool.grant(player)
			expect(first).to.be.ok()
			expect((first :: Tool).Parent).to.equal(backpack)
			-- IDEMPOTENT, which is what lets the sweep run every two seconds: a second grant hands
			-- back the same Tool rather than a second one.
			expect(HornTool.grant(player)).to.equal(first)
			expect(#HornTool.toolsOf(player)).to.equal(1)

			-- ...and the level-triggered path agrees with itself.
			expect(HornTool.refreshCarry(player)).to.equal(nil)

			expect(HornTool.revoke(player)).to.equal(1)
			expect(HornTool.held(player)).to.equal(nil)
			expect(#HornTool.toolsOf(player)).to.equal(0)

			HornTool.setCarryPolicy(restore)
			backpack:Destroy()
		end)

		it("gives nobody a horn when no policy is wired, and revokes from a non-beater", function()
			local backpack = newBackpack()
			local player = stubPlayer(backpack, nil, 152002)
			local restore = HornTool.setCarryPolicy(nil)
			-- A WORLD THAT HAS NOT WIRED THE POLICY HANDS OUT NONE, which is the safe default: the
			-- opposite mistake would put a horn in every hunter's hand.
			expect(HornTool.mayCarry(player)).to.equal(false)
			expect(HornTool.refreshCarry(player)).to.equal(nil)
			expect(HornTool.held(player)).to.equal(nil)

			-- Now hand him one and turn the policy to "no": the refresh takes it away.
			HornTool.setCarryPolicy(function()
				return true
			end)
			expect(HornTool.grant(player)).to.be.ok()
			HornTool.setCarryPolicy(function()
				return false
			end)
			expect(HornTool.refreshCarry(player)).to.equal("revoke")
			expect(HornTool.held(player)).to.equal(nil)

			-- ...and a policy that THROWS is a "no" for that player, not an error that arms everybody
			-- and not one that is swallowed into "yes".
			HornTool.setCarryPolicy(function(): boolean
				error("policy blew up")
			end)
			expect(HornTool.mayCarry(player)).to.equal(false)

			HornTool.setCarryPolicy(restore)
			backpack:Destroy()
		end)

		-- ---------------------------------------------------------------- task 168: through the line
		--
		-- KAREN, 2026-10-12 ~21:45: *"when beater cross the line of hunter it's done for him cant use
		-- sound anymore"*. WHO has crossed is the drive's question and is injected
		-- (`Match.mayBlowHorn`); what this file owns is that a "no" really stops a blast, for a
		-- player and for a bot, and takes nothing with it.
		it("refuses a blast from a beater who is through the line, and keeps the horn in his hand", function()
			local backpack = newBackpack()
			local player = stubPlayer(backpack, nil, 152008)
			local restoreCarry = HornTool.setCarryPolicy(function()
				return true
			end)
			local tool = HornTool.grant(player) :: Tool
			local handle = tool:FindFirstChild("Handle") :: BasePart
			handle.CFrame = CFrame.new(31, GROUND_Y, -41)

			local heard = {}
			local wire = HornTool.Blown:Connect(function(blast)
				table.insert(heard, blast)
			end)
			-- THE DRIVE SAYS HE IS THROUGH, keyed exactly as the cooldown table is keyed.
			local through: { [string]: boolean } = {}
			local restoreBlow = HornTool.setBlowPolicy(function(key: string): boolean
				return through[key] ~= true
			end)
			local key = HornTool.keyFor(152008)

			local t0 = 3000
			-- Before he is through, the horn sounds as it always did.
			expect(HornTool.mayBlow(key)).to.equal(true)
			expect(HornTool.blow(player, t0)).to.equal(true)
			task.wait()
			expect(#heard).to.equal(1)

			-- NOW HE IS THROUGH. The click does nothing: no `Blown`, so nothing moves an animal.
			through[key] = true
			expect(HornTool.mayBlow(key)).to.equal(false)
			local before = HornTool.stats().refusedThrough
			expect(HornTool.blow(player, t0 + CONFIG.COOLDOWN)).to.equal(false)
			task.wait()
			expect(#heard).to.equal(1)
			expect(HornTool.stats().refusedThrough).to.equal(before + 1)
			-- ...AND THE TOOL IS STILL IN HIS HAND, which is the half of the rule that is a choice:
			-- a Tool vanishing out of a hand mid-drive has nothing on screen to say why.
			expect(HornTool.held(player)).to.equal(tool)
			expect(tool.Parent).to.equal(backpack)

			-- A REFUSAL TAKES NO COOLDOWN EITHER, so a man walking back north is not also serving a
			-- three-second penalty for the click that was refused.
			through[key] = nil
			expect(HornTool.blow(player, t0 + CONFIG.COOLDOWN)).to.equal(true)
			task.wait()
			expect(#heard).to.equal(2)

			-- A BOT IS HELD BY THE SAME PREDICATE AND THE SAME TABLE, through `blowTool` -- which is
			-- the one door every blast comes through.
			through["bot-beater-3"] = true
			expect(HornTool.blowTool(tool, "bot-beater-3", nil, t0 + 100)).to.equal(false)
			task.wait()
			expect(#heard).to.equal(2)
			expect(HornTool.blowTool(tool, "bot-beater-4", nil, t0 + 100)).to.equal(true)
			task.wait()
			expect(#heard).to.equal(3)

			-- NO POLICY MEANS EVERYBODY MAY BLOW, which is this file before task 168 and is what the
			-- Forest Test's own `/beater` relies on before a drive is running.
			HornTool.setBlowPolicy(nil)
			expect(HornTool.mayBlow(key)).to.equal(true)
			-- ...AND A POLICY THAT THROWS IS A "YES", the opposite call from `mayCarry`: a drive whose
			-- predicate errored must not silence every horn in the wood with nothing on screen.
			HornTool.setBlowPolicy(function(): boolean
				error("policy blew up")
			end)
			expect(HornTool.mayBlow(key)).to.equal(true)

			wire:Disconnect()
			HornTool.setBlowPolicy(restoreBlow)
			HornTool.setCarryPolicy(restoreCarry)
			HornTool.revoke(player)
			backpack:Destroy()
			TestKit.note(
				string.format(
					"zz_horn: refusedThrough=%d (task 168), blasts=%d",
					HornTool.stats().refusedThrough,
					HornTool.stats().blasts
				)
			)
		end)

		it("raises a PLAYER's arm to the mouth on an accepted blast, and only on an accepted one", function()
			-- KAREN, 2026-10-12 ~21:45: *"we need when I am playing beater to make animation when
			-- raising horn to face and blow"*. Task 166 did it for bots; the pose is one definition
			-- now (`Horn.BLOW_POSE`) and this is the player's half of it.
			--
			-- A REAL R15 CHARACTER IS NOT BUILT HERE: `Players:CreateHumanoidModelFromDescription`
			-- is a web call. What is asserted is the STATE MACHINE -- it tries on an accepted blast,
			-- it does not try on a refused one, and a body with no Humanoid is a miss and not an
			-- error. Whether the arm LOOKS right is a screenshot (rule 5), and task 168 took one.
			local backpack = newBackpack()
			local body = Instance.new("Model")
			body.Name = "HornSpecBody"
			body.Parent = toolRoot
			local player = stubPlayer(backpack, body, 152009)
			local restoreCarry = HornTool.setCarryPolicy(function()
				return true
			end)
			local tool = HornTool.grant(player) :: Tool
			local handle = tool:FindFirstChild("Handle") :: BasePart
			handle.CFrame = CFrame.new(51, GROUND_Y, -61)

			-- NO HUMANOID: the raise is a MISS, counted, and the blast still happens -- a cosmetic
			-- must never be able to swallow the signal.
			local missed = HornTool.stats().raisesMissed
			local t0 = 4000
			expect(HornTool.blow(player, t0)).to.equal(true)
			expect(HornTool.stats().raisesMissed).to.equal(missed + 1)
			expect(HornTool.raise(nil, 0.1)).to.equal(false)
			expect(HornTool.raise(body, 0.1)).to.equal(false)

			-- A REFUSED BLAST RAISES NOTHING AT ALL -- not even an attempt, because the raise is
			-- asked for only after the blast is accepted.
			local restoreBlow = HornTool.setBlowPolicy(function(): boolean
				return false
			end)
			missed = HornTool.stats().raisesMissed
			local raised = HornTool.stats().raised
			expect(HornTool.blow(player, t0 + CONFIG.COOLDOWN)).to.equal(false)
			expect(HornTool.stats().raisesMissed).to.equal(missed)
			expect(HornTool.stats().raised).to.equal(raised)

			HornTool.setBlowPolicy(restoreBlow)
			HornTool.setCarryPolicy(restoreCarry)
			HornTool.revoke(player)
			body:Destroy()
			backpack:Destroy()
		end)

		it("sounds once per cooldown, publishes where it was blown, and raises to the mouth", function()
			local backpack = newBackpack()
			local player = stubPlayer(backpack, nil, 152003)
			local restore = HornTool.setCarryPolicy(function()
				return true
			end)
			local tool = HornTool.grant(player) :: Tool
			local handle = tool:FindFirstChild("Handle") :: BasePart
			-- Somewhere recognisable, so "it published the horn's own position" is a real assertion
			-- and not a comparison of two zeroes.
			handle.CFrame = CFrame.new(11, GROUND_Y, -22)

			local heard = {}
			local wire = HornTool.Blown:Connect(function(blast)
				table.insert(heard, blast)
			end)

			-- A `BindableEvent:Fire` IS DEFERRED, so a listener has not run when `blow` returns --
			-- measured by the gate, which read `#heard == 0` immediately after a blast that had
			-- certainly happened. Every read of `heard` below is therefore after one resumption.
			local t0 = 1000
			expect(HornTool.blow(player, t0)).to.equal(true)
			task.wait()
			expect(#heard).to.equal(1)
			expect(heard[1].blowerUserId).to.equal(152003)
			-- THE STIMULUS IS REAL, FROM THE HORN ITSELF (note section 5.3) -- never a phantom and
			-- never the character's approximate position.
			expect((heard[1].at - handle.Position).Magnitude < 1e-3).to.equal(true)
			-- Raised to the mouth for the length of the blow...
			expect(tool.Grip).to.equal(CONFIG.GRIP_BLOW)

			-- A click inside the cooldown publishes NOTHING: the server holds the rate, because the
			-- click is whatever the client sends.
			expect(HornTool.blow(player, t0 + CONFIG.COOLDOWN - 0.1)).to.equal(false)
			task.wait()
			expect(#heard).to.equal(1)
			-- ...and the next one, on time, does.
			expect(HornTool.blow(player, t0 + CONFIG.COOLDOWN)).to.equal(true)
			task.wait()
			expect(#heard).to.equal(2)

			wire:Disconnect()
			HornTool.setCarryPolicy(restore)

			-- ...AND THE HORN IS LEFT RAISED, ON PURPOSE. Whether it comes back DOWN is the last case
			-- in this file, because the restore is a `task.delay(BLOW_SECONDS)` -- three seconds of
			-- wall clock that would otherwise be spent standing still. MEASURED why that matters: a
			-- fixed 3.4 s wait here pushed the whole server suite past `TestKit.TOKEN_MAX_AGE`, and
			-- `sync.spec` -- which runs after this file and asks whether the gate token is still
			-- fresh -- failed with a stale one. The seconds pass during the live cases below instead,
			-- and the assertion is exactly as strong.
			lowering = { tool = tool, player = player, backpack = backpack }
		end)

		it("is not a weapon, so the first-person viewmodel will not draw a gun out of it", function()
			-- THE DEFECT THIS ASSERTS, MEASURED IN THE FOREST TEST ON 2026-10-11: a beater holding
			-- the horn saw A SHOTGUN in first person. `Camera.Viewmodel`'s source is "the Handle of
			-- the Tool in the local character", so it took the HORN's Handle, `weaponId()` answered
			-- nil, `Weapons.row(nil) or Shotgun.CONFIG` answered the shotgun, and it drew the wrong
			-- object out of the right Handle. Karen plays in first person, so that frame was the
			-- whole of what she would have seen.
			--
			-- `Weapons.isWeaponTool` is the one fact both camera modules now ask, and this is it
			-- asked of a REAL horn and a REAL gun rather than of two hand-made stubs.
			local horn = HornTool.build()
			expect(Weapons.isWeaponTool(horn)).to.equal(false)
			expect(Weapons.isToolName(horn.Name)).to.equal(false)
			horn:Destroy()

			local gun = Hardware.build(Weapons.ROWS.shotgun)
			expect(Weapons.isWeaponTool(gun)).to.equal(true)
			gun:Destroy()
			-- A Tool from a server older than task 140 carries no attribute and must still be a gun.
			local legacy = Instance.new("Tool")
			legacy.Name = Weapons.ROWS.shotgun.toolName
			expect(Weapons.isWeaponTool(legacy)).to.equal(true)
			legacy:Destroy()
			-- ...and nothing that is not a Tool at all is one.
			expect(Weapons.isWeaponTool(nil)).to.equal(false)
			expect(Weapons.isWeaponTool(Instance.new("Part"))).to.equal(false)
		end)

		it("refuses to sound for a player holding no horn", function()
			local backpack = newBackpack()
			local player = stubPlayer(backpack, nil, 152005)
			local heard = 0
			local wire = HornTool.Blown:Connect(function()
				heard += 1
			end)
			expect(HornTool.blow(player, 3000)).to.equal(false)
			task.wait()
			expect(heard).to.equal(0)
			wire:Disconnect()
			backpack:Destroy()
		end)
	end)

	---------------------------------------------------------------- live: real animals

	describe("a blast on a real wood", function()
		local function buildWorld(name: string)
			-- THE FLIGHT IS THE THING UNDER TEST, so `MOVE` is on -- as a full clone with one value
			-- flipped, because `newRuntime` replaces that block wholesale rather than merging it
			-- (the flag as a parameter, the one permitted shape: docs/design/feature-flags.md
			-- section 13.3). This is also the world Karen actually plays: `ForestTestBoot` turns the
			-- same block on for the same reason.
			local move = table.clone(Boar.CONFIG.MOVE)
			move.ENABLED = true
			return {
				field = FIELD,
				parent = testRoot,
				folderName = name,
				rng = Random.new(152),
				threats = function()
					return {}
				end,
				probe = function()
					return false
				end,
				requestPath = function(_agentId, _from, _to, done)
					done(nil)
				end,
				releasePath = function() end,
				config = {
					MOVE = move,
					-- The box boar: this case is about WHO RUNS, and a drawn model adds a mesh, an
					-- Animator and a yaw measurement to a question none of them answer.
					maxBoars = 8,
				},
			}
		end

		it("pushes every animal inside the radius and leaves the ones outside it alone", function()
			local runtime = Boar.newRuntime(buildWorld("HornSpecBoars"))
			-- The beater stands at the origin. One animal well inside the radius, one just inside,
			-- and one well outside it -- so the case fails if the radius is ignored in EITHER
			-- direction.
			local radius = Horn.spookStuds(CONFIG)
			local near = runtime:spawn(Vector3.new(0, GROUND_Y, 40))
			local edge = runtime:spawn(Vector3.new(0, GROUND_Y, radius - 20))
			local far = runtime:spawn(Vector3.new(0, GROUND_Y, radius + 120))
			expect(near).to.be.ok()
			expect(edge).to.be.ok()
			expect(far).to.be.ok()

			local before = runtime:stats().hornsHeard
			local pushed, ids = runtime:hearHorn(Vector3.new(0, GROUND_Y, 0), radius)
			expect(pushed).to.equal(2)
			expect(runtime:stats().hornsHeard - before).to.equal(2)

			-- ...AND IT SAYS WHICH ANIMALS THOSE WERE (task 160), which is what pays the beater who
			-- blew it (`Match.creditPush`). The ids are the ones that RAN -- the owner answers "did
			-- this blast reach that animal" so the drive never runs a second radius test of its own.
			expect(#ids).to.equal(2)
			local pushedIds = {}
			for _, id in ipairs(ids) do
				pushedIds[id] = true
			end
			expect(pushedIds[(near :: any).id]).to.equal(true)
			expect(pushedIds[(edge :: any).id]).to.equal(true)
			expect(pushedIds[(far :: any).id]).to.equal(nil)

			-- WHAT "PUSHED" MEANS, asserted rather than assumed: the two inside are in flight and
			-- the one outside is not.
			expect(runtime:flying((near :: any).id)).to.equal(true)
			expect(runtime:flying((edge :: any).id)).to.equal(true)
			expect(runtime:flying((far :: any).id)).to.equal(false)

			-- ...AND IT IS NOT THE SHOT PATH. A heard shot latches one way for the rest of the
			-- animal's life (task 150) and records where the bang was, so a boar spawned later
			-- inherits it. A horn must leave both alone, or a beater walking a wood would empty it.
			local after = runtime:spawn(Vector3.new(0, GROUND_Y, 60))
			expect(after).to.be.ok()
			expect(runtime:flying((after :: any).id)).to.equal(false)

			TestKit.note(
				string.format(
					"horn: blast at (0,0) pushed %d of 3 inside %.0f studs (%d m); the one at %.0f stayed",
					pushed,
					radius,
					CONFIG.SPOOK_M,
					radius + 120
				)
			)
			runtime:clear("spec done")
			runtime:destroy()
		end)

		it("latches the flight only when the WORLD asks for it (task 154)", function()
			-- KAREN, 2026-10-11: *"horn reach is further once they hear also run without stop"*.
			-- `Runtime:hearHorn`'s third argument is the one-way flight of task 150, and it is the
			-- WORLD's to decide: `ForestTestBoot` passes it, `MatchBoot` does not, so the drive's
			-- own horn is exactly what task 152 shipped.
			--
			-- THE FLIGHT IS MADE SHORT so the case costs no wall clock: `FLIGHT_MAX_SECONDS` is 45
			-- in the shipped config and the runtime is stepped by hand here, which is what makes a
			-- flight that is meant to END observable at all. The number is the PARAMETER -- the
			-- shape a flagged path must have -- and the latch is what this case is about.
			local world = buildWorld("HornLatchBoars")
			local move = table.clone(world.config.MOVE)
			move.FLIGHT_MAX_SECONDS = 0.5
			world.config = table.clone(world.config)
			world.config.MOVE = move
			local runtime = Boar.newRuntime(world)
			local radius = Horn.spookStuds(CONFIG)

			local function stillFlyingAfterTheFlight(untilExit: boolean?): boolean
				local boar = runtime:spawn(Vector3.new(0, GROUND_Y, 40))
				expect(boar).to.be.ok()
				local id = (boar :: any).id
				expect(runtime:hearHorn(Vector3.new(0, GROUND_Y, 0), radius, untilExit) >= 1).to.equal(true)
				expect(runtime:flying(id)).to.equal(true)
				-- Two seconds of simulated time, four times the flight's own ceiling.
				for _ = 1, 120 do
					runtime:step(1 / 60)
				end
				return runtime:flying(id)
			end

			-- Asked for: it is still running when the flight that would have ended has ended.
			expect(stillFlyingAfterTheFlight(true)).to.equal(true)
			runtime:clear("between the halves")
			-- Not asked for: the flight runs out, which is what task 152 shipped and what
			-- `MatchBoot` still gets.
			expect(stillFlyingAfterTheFlight(nil)).to.equal(false)

			TestKit.note(
				"horn: hearHorn(at, r, true) holds the flight past FLIGHT_MAX_SECONDS; hearHorn(at, r) does not"
			)
			runtime:clear("spec done")
			runtime:destroy()
		end)

		it("sends them away from the horn, and out of the wood", function()
			-- WHAT "AWAY FROM THE BEATER" MEANS HERE, SAID PLAINLY, because it is not a straight
			-- line away and the dispatch's wording could be read as one. `Brain:_latchFlight` --
			-- the one door every fright comes through, and the one this task deliberately reuses --
			-- heads the animal for `field.exitZ` and makes the thing that frightened it a SWERVE:
			-- *"the exit is the heading and the gun is a swerve ... driven game breaks PAST the
			-- guns"* (task 139, the Director's decision A, measured: nine shots, five animals ran
			-- back into the view she had just shot into under the old rule). A beater pushing
			-- animals toward the hunters' line is exactly what that rule is for, so the horn
			-- inherits it rather than inventing a second panic rule (note section 5.3).
			--
			-- SO THE BEATER STANDS TO THE SIDE, at the animal's own z: the exit is due south and
			-- the beater is due east, so "away from him" is the lateral half of the heading and is
			-- distinguishable from "toward the way out". With him on the exit line the two cannot be
			-- told apart, which is why the case is not arranged that way.
			local runtime = Boar.newRuntime(buildWorld("HornSpecAway"))
			local beater = Vector3.new(90, GROUND_Y, 0)
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0))
			expect(handle).to.be.ok()
			local id = (handle :: any).id

			-- REAL TIME, NOT A STEP LOOP. `Runtime:step` sets what the body is ASKED to do and the
			-- engine's solver is what actually moves it, so 120 calls to `step(1/60)` inside one
			-- frame cover two seconds of intent and no seconds of physics -- which the gate showed:
			-- the animal ended within a stud of where it started. `run()` puts the runtime on
			-- Heartbeat and the wait is wall clock.
			local start = runtime:statusOf(id).position
			local wasFrom = (flat2(start) - flat2(beater)).Magnitude
			runtime:run()
			expect(runtime:hearHorn(beater, Horn.spookStuds(CONFIG))).to.equal(1)
			task.wait(1.5)
			local moved = runtime:statusOf(id).position
			local fromBeater = (flat2(moved) - flat2(beater)).Magnitude

			-- FARTHER FROM THE BEATER THAN IT STARTED: the whole mechanic, in one number, and the
			-- only part of it this system owns. WHICH WAY it breaks is `Brain:_latchFlight`'s --
			-- the exit is the heading and the beater is a swerve (task 139) -- and the whiskers, the
			-- field and the solver all get a say after that, so the note prints the components and
			-- the assertion does not pin them.
			expect(fromBeater > wasFrom).to.equal(true)
			TestKit.note(
				string.format(
					"horn: pushed from %.0f to %.0f studs off the beater in 1.5 s (dx %+.0f, dz %+.0f)",
					wasFrom,
					fromBeater,
					moved.X - start.X,
					moved.Z - start.Z
				)
			)
			runtime:clear("spec done")
			runtime:destroy()
		end)

		it("ignores a nonsense blast rather than erroring on it", function()
			local runtime = Boar.newRuntime(buildWorld("HornSpecGuard"))
			runtime:spawn(Vector3.new(0, GROUND_Y, 10))
			-- The door is called from a composition root off a signal payload, so a missing or
			-- meaningless argument must be a no-op and never a crash in the boar's own step.
			expect(runtime:hearHorn(Vector3.new(0, GROUND_Y, 0), 0)).to.equal(0)
			expect(runtime:hearHorn(Vector3.new(0, GROUND_Y, 0), -5)).to.equal(0)
			expect(runtime:hearHorn(nil :: any, 100)).to.equal(0)
			expect(runtime:hearHorn(Vector3.new(0, GROUND_Y, 0), nil :: any)).to.equal(0)
			-- ...AND THE SECOND RETURN IS AN EMPTY LIST AND NOT `nil` (task 160), because
			-- `Match.creditPush` iterates it: a refused blast must credit nobody, not throw in the
			-- composition root that forwards it.
			local _, noIds = runtime:hearHorn(nil :: any, 100)
			expect(type(noIds)).to.equal("table")
			expect(#noIds).to.equal(0)
			runtime:clear("spec done")
			runtime:destroy()
		end)
	end)

	---------------------------------------------------------------- the horn comes back down

	describe("after the blow", function()
		-- THE LAST CASE IN THE FILE, and the seconds it needs have already passed during the live
		-- cases above (the blast case says why). A horn stuck at the player's chin is what it exists
		-- to catch, and nothing but real time can prove the `task.delay` fired at all.
		it("lowers the horn again, and the clip is cut", function()
			expect(lowering).to.be.ok()
			local tool = lowering.tool :: Tool
			local lowered = tool.Grip == CONFIG.GRIP
			local deadline = os.clock() + CONFIG.BLOW_SECONDS + 1
			while not lowered and os.clock() < deadline do
				task.wait(0.1)
				lowered = tool.Grip == CONFIG.GRIP
			end
			local left = deadline - os.clock()

			-- ...AND THE CLIP IS CUT, WHICH HAPPENS LATER THAN THE ARM COMES DOWN -- `BLOW_SECONDS`
			-- is 3 and the clip plays for `SOUND_CUT - SOUND_START`, 4.28. The first version of this
			-- case asserted both at the same instant and the gate corrected it: "lowered true ...
			-- clip playing true" is the horn working exactly as the data file describes it (*"the arm
			-- comes down while the last note is still ringing, which is what a person does"*).
			local handle = tool:FindFirstChild("Handle") :: BasePart
			local sound = handle:FindFirstChild(HornTool.SOUND_NAME) :: Sound
			local cutDeadline = os.clock() + Horn.playSeconds(CONFIG) + 1
			while sound.IsPlaying and os.clock() < cutDeadline do
				task.wait(0.1)
			end
			TestKit.note(
				string.format(
					"horn: lowered %s with %.1f s to spare; clip stopped %s (cut at %.2f s of a %.1f s asset)",
					tostring(lowered),
					left,
					tostring(not sound.IsPlaying),
					CONFIG.SOUND_CUT,
					60.63
				)
			)
			expect(lowered).to.equal(true)
			-- Cut, and NOT left running for the rest of the asset's sixty seconds.
			expect(sound.IsPlaying).to.equal(false)

			HornTool.revoke(lowering.player)
			lowering.backpack:Destroy()
			lowering = nil
		end)
	end)

	describe("a blast with no player behind it (task 161)", function()
		-- THE BOTS BLOW THE REAL HORN, through the real door. `Horn.blowTool` is `Horn.blow`'s body,
		-- factored out and keyed by a string, so what a blast IS is written once: one cooldown table,
		-- one measured cut of the asset, one `GRIP_BLOW` tilt, one `Blown` signal. These cases are
		-- what stops that becoming two blast paths.
		local built: { Instance } = {}

		afterEach(function()
			for _, instance in ipairs(built) do
				instance:Destroy()
			end
			built = {}
		end)

		it("sounds once for a key, and the real cooldown refuses the second", function()
			local folder = Instance.new("Folder")
			folder.Parent = workspace
			table.insert(built, folder)
			local tool = HornTool.build()
			tool.Parent = folder
			-- ANCHORED AND SOMEWHERE RECOGNISABLE, for the two reasons the player's own case above
			-- gives: a horn in a Folder rather than in a hand is an unanchored part that FALLS (the
			-- gate measured this one drifting between the blast and the read), and "it published the
			-- horn's own position" has to be a real assertion rather than a comparison of two zeroes.
			local handle = tool:FindFirstChild("Handle") :: BasePart
			handle.Anchored = true
			handle.CFrame = CFrame.new(31, GROUND_Y, -44)

			local blasts = {}
			local connection = HornTool.Blown:Connect(function(blast)
				table.insert(blasts, blast)
			end)
			local at = os.clock()
			expect(HornTool.blowTool(tool, "bot-beater-1", nil, at)).to.equal(true)
			-- INSIDE the cooldown: refused, by the same table and the same number that holds a player.
			expect(HornTool.blowTool(tool, "bot-beater-1", nil, at + CONFIG.COOLDOWN - 0.01)).to.equal(false)
			-- ...and past it, allowed.
			expect(HornTool.blowTool(tool, "bot-beater-1", nil, at + CONFIG.COOLDOWN)).to.equal(true)
			-- A DIFFERENT BOT IS A DIFFERENT ROW: four beaters are four horns, not one.
			expect(HornTool.blowTool(tool, "bot-beater-2", nil, at)).to.equal(true)

			-- A `BindableEvent:Fire` IS DEFERRED, exactly as the player's own case above records
			-- being measured: the listener has not run when `blowTool` returns, so every read of
			-- `blasts` is after one resumption.
			task.wait()
			connection:Disconnect()
			expect(#blasts).to.equal(3)
			-- `blowerUserId` IS NIL for a bot, which is what makes `Match.creditPush` refuse it -- so a
			-- bot's blast pays nobody and cannot appear in a beater ranking.
			for _, blast in ipairs(blasts) do
				expect(blast.blowerUserId).to.equal(nil)
				expect(typeof(blast.at)).to.equal("Vector3")
			end
			-- ...and it is published from the HORN's own handle, never from an approximate position.
			expect((blasts[1].at - handle.Position).Magnitude < 1e-3).to.equal(true)
		end)

		it("refuses a blast with no tool at all, rather than publishing from nowhere", function()
			expect(HornTool.blowTool(nil, "bot-beater-9", nil, os.clock())).to.equal(false)
		end)

		it("puts a real horn in a rig's hand, once", function()
			local folder = Instance.new("Folder")
			folder.Parent = workspace
			table.insert(built, folder)
			local rig = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Parent = rig
			rig.PrimaryPart = root
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = rig
			rig.Parent = folder

			local tool = HornTool.giveTo(rig)
			expect(tool).to.be.ok()
			expect((tool :: Tool).Name).to.equal(Horn.TOOL_NAME)
			expect((tool :: Tool):IsDescendantOf(rig)).to.equal(true)
			-- IDEMPOTENT: a re-dress or a second fill must not be two horns in one hand.
			expect(HornTool.giveTo(rig)).to.equal(tool)
			local horns = 0
			for _, child in ipairs(rig:GetChildren()) do
				if child:IsA("Tool") then
					horns += 1
				end
			end
			expect(horns).to.equal(1)
		end)

		it("refuses a body that is not a body", function()
			expect(HornTool.giveTo(nil)).to.equal(nil)
			local orphan = Instance.new("Model") -- no parent, no Humanoid
			expect(HornTool.giveTo(orphan)).to.equal(nil)
			orphan:Destroy()
		end)
	end)
end
