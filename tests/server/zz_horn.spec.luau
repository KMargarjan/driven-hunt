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

local Boar = require(ServerScriptService:WaitForChild("Boar"))
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
		end)
	end)

	---------------------------------------------------------------- pure: the two decisions

	describe("who carries one, and when it may sound", function()
		it("grants to a beater who has none and revokes from anyone else who has one", function()
			expect(HornTool.carryAction(true, false)).to.equal("grant")
			expect(HornTool.carryAction(false, true)).to.equal("revoke")
			-- The two no-ops, which is what makes the sweep idempotent.
			expect(HornTool.carryAction(true, true)).to.equal(nil)
			expect(HornTool.carryAction(false, false)).to.equal(nil)
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

		it("builds a horn from parts, with no asset and no upload", function()
			local tool = HornTool.build()
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
			local pushed = runtime:hearHorn(Vector3.new(0, GROUND_Y, 0), radius)
			expect(pushed).to.equal(2)
			expect(runtime:stats().hornsHeard - before).to.equal(2)

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
end
