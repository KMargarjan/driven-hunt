-- semiauto.spec: the semi-automatic shotgun's row, its shared ammunition, its self-working cycle,
-- its port reload, the TWO moving groups, the red dot, the pose share that keeps the gun still, the
-- hand anchors and its shop row. Pure: no Instances, no clock, no Player, no client.
--
-- WHAT THIS FILE IS FOR, in one sentence: **every case must ENTER this weapon's own arm.** A fourth
-- gun that is only ever tested through code the other three also reach is a fourth gun nobody has
-- tested (the Learning Agent's [L-093], and task 224 round 2's mirrored-frame miss). So each case
-- below says what makes it this gun's, and the three shipped guns are asserted to be UNABLE to
-- reach the arms this one adds.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/semiauto-shotgun.md (sections 6, 7, 9, 15.1)
-- Note:   docs/research/2026-10-20-semiauto-shotgun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
local Lever = require(ReplicatedStorage:WaitForChild("Lever"))
local SemiAuto = require(ReplicatedStorage:WaitForChild("SemiAuto"))
local SemiAutoGeometry = require(ReplicatedStorage:WaitForChild("SemiAuto"):WaitForChild("Geometry"))
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local cameraScripts = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Camera")
local Config = require(cameraScripts:WaitForChild("Config"))
local Mode = require(cameraScripts:WaitForChild("Mode"))
-- THE DRAWN GUN'S OWN MODULE (task 227), for `clearAtAim` alone -- the pure decision that takes the
-- red dot's housing out of the sight line. Requiring it on the server is safe for the reason
-- `camera_mode.spec` already states: its top level only calls `GetService` and `require`.
local Viewmodel3D = require(cameraScripts:WaitForChild("Viewmodel"))
-- THE HUD IS THE PLAYER'S PATH for the readout and the ammo chip, and like `Camera` above
-- it lives in StarterPlayerScripts -- a TEMPLATE, read here the same way.
local Hud = require(StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Hud"))

local StateMachine = Weapon.StateMachine
local Shapes = Weapon.Shapes
local ROW = Weapons.ROWS.semiauto
local C = SemiAuto.CONFIG

-- One 12-gauge hull, in studs, at this gun's measured scale (1 stud = 259.2 mm). Both of the two
-- moving groups are bounded against it: a bolt that travels less than a hull's LENGTH could not
-- throw one clear of the port, and a tray that rises less than a hull's DIAMETER could not lift one
-- to the chamber mouth.
local HULL_LENGTH_STUDS = 76 / 259.2
local HULL_DIAMETER_STUDS = 20.5 / 259.2

local function equipped(row)
	return StateMachine.setEquipped(StateMachine.initial(row), true)
end

local function live(state)
	local n = 0
	for _, chamber in ipairs(state.barrels) do
		if chamber == "Live" then
			n += 1
		end
	end
	return n
end

-- THE GLOVE'S OWN GRIP POINT, not the pose's origin: `HandAssets.GRIP_STUDS` is the hole in the
-- closed fist, and a pose is only "on the gun" if THAT lands on the gun. Lifted verbatim from
-- `lever.spec` and `viewmodel_poses.spec`, so every gun is measured by one expression.
local function gripPointOf(offset: CFrame): Vector3
	return offset:PointToWorldSpace(HandAssets.GRIP_STUDS)
end

-- This weapon's own pose set, as the camera resolves it.
local function configFor(id: string)
	local out = table.clone(Config) :: any
	for key, value in pairs(Viewmodel.view(Viewmodel.DATA, id)) do
		out[key] = value
	end
	out.FIRST_PERSON = true
	return table.freeze(out)
end

local semiConfig = configFor("semiauto")

local function stateAt(blend: number, openTilt: number)
	local state = table.clone(Mode.initial(Config)) :: any
	state.mode = if blend > 0 then "Aiming" else "Third"
	state.blend = blend
	state.openTilt = openTilt
	return table.freeze(state)
end

return function()
	describe("the semi-automatic shotgun's row", function()
		it("is the fourth weapon, bought or not carried, and is built from its own config", function()
			expect(ROW).to.be.ok()
			expect(ROW.id).to.equal("semiauto")
			expect(ROW.toolName).to.equal("SemiAuto")
			expect(ROW.slot).to.equal(4)
			-- SEVEN CHARACTERS IS THE CEILING: `ReportPanel.DETAIL_COLUMNS`' `gun` cell is 88 px and
			-- task 219 measured `SHOTGUN` at 46 px in that cell's own face.
			expect(#ROW.label <= 7).to.equal(true)
			expect(ROW.OWNED_ONLY).to.equal(true)
			expect(Weapons.ORDER[4]).to.equal("semiauto")
			-- ...AND THE THREE SHIPPED GUNS DID NOT MOVE. `Weapons.PRIMARY` and the first three
			-- rungs are what a spawn has always been.
			expect(Weapons.PRIMARY).to.equal("shotgun")
			expect(Weapons.ORDER[1]).to.equal("shotgun")
			expect(Weapons.ORDER[2]).to.equal("rifle")
			expect(Weapons.ORDER[3]).to.equal("lever")
			for _, key in ipairs({
				"BARRELS",
				"MAGAZINE",
				"BARREL_DELAY",
				"AUTO_CYCLE",
				"CYCLE_TOTAL",
				"RELOAD_TOTAL",
				"READOUT",
			}) do
				expect((ROW :: any)[key]).to.equal((C :: any)[key])
			end
			expect(ROW.HANDLE_SIZE).to.equal(C.HANDLE_SIZE)
			expect(ROW.GRIP).to.equal(C.GRIP)
			expect(ROW.MUZZLE_OFFSET).to.equal(C.MUZZLE_OFFSET)
		end)

		it("carries none of the fields a row may not have", function()
			-- `Weapons`' own header: the safety arc, the camera tolerance, the rate limits and
			-- `AUTO_EQUIP` are rules of the DRIVE and the PROTOCOL, not properties of a gun.
			for _, forbidden in ipairs({
				"SAFETY_ARC_HALF_DEG",
				"CAMERA_ORIGIN_TOLERANCE_STUDS",
				"AUTO_EQUIP",
				"shouldArm",
			}) do
				expect((ROW :: any)[forbidden]).to.equal(nil)
			end
		end)

		it("is NOT in an unrestricted loadout, and the free path is what it always was", function()
			-- THE ARM `OWNED_ONLY` EXISTS FOR, entered: a nil ownership set is "unrestricted", and
			-- this gun must still not be in it. Measured on the lever in task 224, where a player
			-- who had bought nothing ended up holding a gun he never asked for.
			local free = Weapons.loadoutFor(true, nil)
			local sawSemi, sawShotgun = false, false
			for _, id in ipairs(free) do
				sawSemi = sawSemi or id == "semiauto"
				sawShotgun = sawShotgun or id == "shotgun"
			end
			TestKit.note(string.format("task225 free loadout: %s", table.concat(free, ", ")))
			expect(sawSemi).to.equal(false)
			expect(sawShotgun).to.equal(true)
			-- ...AND A PLAYER WHO BOUGHT IT DOES CARRY IT, which is the other half and the half
			-- that makes buying the gun work at all.
			local owned = Weapons.loadoutFor(true, { [Shop.ITEM.SEMIAUTO] = true })
			local hasSemi = false
			for _, id in ipairs(owned) do
				hasSemi = hasSemi or id == "semiauto"
			end
			expect(hasSemi).to.equal(true)
		end)
	end)

	describe("the ammunition, which is the side-by-side's", function()
		it("is the SAME TABLE and not a copy, for every ballistic row", function()
			-- THE ARM THIS GUN ADDS TO THE BALLISTICS: two guns firing one cartridge. Asserted by
			-- IDENTITY rather than by value, because two tables that happen to be equal today are
			-- exactly what drifts apart tomorrow -- which is the defect this design chose sharing
			-- to avoid.
			for _, key in ipairs({
				"RANGE_STUDS",
				"PELLETS",
				"SPREAD_FULL_DEG",
				"MUZZLE_STUDS_PER_S",
				"DRAG_PER_STUD",
				"ZERO_STUDS",
				"GRAVITY_SCALE",
				"AMMO_KINDS",
				"AMMO_LABEL",
				"AMMO_GLYPH",
			}) do
				expect((ROW :: any)[key]).to.equal((Shotgun.CONFIG :: any)[key])
				expect((ROW :: any)[key]).to.equal((Weapons.ROWS.shotgun :: any)[key])
			end
		end)

		it("comes loaded with BUCK, where the side-by-side starts on slugs", function()
			expect(ROW.INITIAL_AMMO).to.equal("Buck")
			expect(Weapons.ROWS.shotgun.INITIAL_AMMO).to.equal("Slug")
			-- Buckshot is free with the gun; the slug is still the ladder's first rung.
			local base = (Shop :: any).BASE_AMMO.semiauto
			expect(base).to.be.ok()
			expect(base.Buck).to.equal(true)
			expect(base.Slug).to.equal(nil)
		end)

		it("does NOT share a number with either rifle", function()
			-- The other half of the design's rule, entered: the two SHOTGUNS share a cartridge, the
			-- two RIFLES do not share one with anybody.
			expect(ROW.RANGE_STUDS).never.to.equal(Lever.CONFIG.RANGE_STUDS)
			expect(ROW.MUZZLE_STUDS_PER_S).never.to.equal(Lever.CONFIG.MUZZLE_STUDS_PER_S)
		end)
	end)

	describe("the action, which works itself", function()
		it("cycles automatically in two steps that sum to CYCLE_TOTAL", function()
			expect(C.AUTO_CYCLE).to.equal(true)
			expect(#C.CYCLE).to.equal(2)
			expect(C.CYCLE[1].kind).to.equal("Break")
			expect(C.CYCLE[2].kind).to.equal("Close")
			local sum = 0
			for _, step in ipairs(C.CYCLE) do
				sum += step.wait
			end
			expect(math.abs(sum - C.CYCLE_TOTAL) < 1e-6).to.equal(true)
			-- FASTER THAN EVERY HAND-WORKED ACTION IN THE GAME, which is the whole character of a
			-- gas gun and the one number a spec can hold against the other three rows.
			expect(C.CYCLE_TOTAL < Lever.CONFIG.CYCLE_TOTAL).to.equal(true)
			TestKit.note(
				string.format(
					"task225 rate: %.2f s cycle + %.2f s delay = %.2f s between shots",
					C.CYCLE_TOTAL,
					C.BARREL_DELAY,
					C.CYCLE_TOTAL + C.BARREL_DELAY
				)
			)
		end)

		it("throws the fired hull and KEEPS the live rounds in the tube", function()
			-- THE `"spent"` ARM, entered through the reducer: the side-by-side's `"all"` would dump
			-- four live shells out of a tube gun after every shot.
			expect(C.CYCLE_EJECTS).to.equal("spent")
			local state = equipped(ROW)
			expect(live(state)).to.equal(5)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 0, ROW)
			local opened = StateMachine.apply(fired, { kind = "Break" }, 1, ROW)
			TestKit.note(string.format("task225 after Fire+Break: %d live of %d", live(opened), #opened.barrels))
			expect(live(opened)).to.equal(4)
			for _, chamber in ipairs(opened.barrels) do
				expect(chamber).never.to.equal("Spent")
			end
		end)

		it("holds four in the tube and one in the chamber", function()
			expect(C.BARRELS).to.equal(5)
			expect(C.MAGAZINE).to.equal(5)
			expect(C.READOUT).to.equal("magazine")
			expect(#equipped(ROW).barrels).to.equal(5)
		end)

		it("reloads five single shells through the port, and sums to RELOAD_TOTAL", function()
			expect(C.RELOAD[1].kind).to.equal("Break")
			expect(C.RELOAD[#C.RELOAD].kind).to.equal("Close")
			local loads, sum = 0, 0
			for _, step in ipairs(C.RELOAD) do
				sum += step.wait
				if step.kind == "Load" then
					loads += 1
				end
			end
			expect(loads).to.equal(C.MAGAZINE)
			expect(math.abs(sum - C.RELOAD_TOTAL) < 1e-6).to.equal(true)
			-- SLOWER THAN THE SIDE-BY-SIDE'S, which is the price of five rounds.
			expect(C.RELOAD_TOTAL > Shotgun.CONFIG.RELOAD_TOTAL).to.equal(true)
			-- IT USED TO BE QUICKER THAN THE LEVER'S 2.90 as well, *"because a shotgun's port is a
			-- bigger hole than a rifle's gate"*, and task 242 reversed that: Karen asked for the
			-- lever to reload *"much faster"* and it now fills five rounds in 1.59. So this gun IS
			-- the slowest reload in the game, which is what the design's section 6.2 claimed all
			-- along and what this case used to disprove. The relation is asserted in the new
			-- direction rather than deleted, so nobody re-derives the old one from the comment --
			-- and whether 2.60 should follow the lever down is Karen's ear, not this file's
			-- (TASKS.md 242a).
			expect(C.RELOAD_TOTAL > Lever.CONFIG.RELOAD_TOTAL).to.equal(true)
		end)

		it("tops a PART-EMPTY tube up and finishes early", function()
			-- THE PARTIAL-RELOAD ARM, entered through the reducer rather than asserted about it.
			-- Three shells fired, two go back in, and the fourth `Load` finds the tube full --
			-- which is the refusal `Weapon.cycleRefusal` turns into "finish" rather than an error.
			local state = equipped(ROW)
			-- THE CLOCK MUST MOVE, AND IT MUST CLEAR EVERY STEP'S OWN WINDOW. `Fire` sets
			-- `busyUntil = now + BARREL_DELAY`, `Break` adds its 0.12 and `Close` its 0.18 -- so
			-- three shots at `now = 0` are one shot and two refusals, and three shots 0.5 s apart
			-- are still two, because `Close` at +0.4 leaves the gun busy until +0.58 and the next
			-- `Fire` at +0.5 is inside it. Both versions of this case left four in the tube and
			-- read as though the reducer were wrong. A whole second between shots clears
			-- everything with room to spare.
			local at = 0
			for _ = 1, 3 do
				state = StateMachine.apply(state, { kind = "Fire" }, at, ROW)
				state = StateMachine.apply(state, { kind = "Break" }, at + 0.3, ROW)
				state = StateMachine.apply(state, { kind = "Close" }, at + 0.6, ROW)
				at += 1.0
			end
			expect(live(state)).to.equal(2)
			-- ...AND THE RELOAD OPENS THE ACTION FIRST, which is `RELOAD`'s own first step and not
			-- an incantation: `Load` is refused `"is-closed"` on a shut gun, and the version of
			-- this case without it reported `0 Load step(s)` and read as though the pocket were
			-- empty. On this weapon `Break` opens nothing -- it is the hand leaving the grip for
			-- the port -- but the reducer's precondition is the reducer's.
			state = StateMachine.apply(state, { kind = "Break" }, at, ROW)
			at += 1.0
			local before = state.reserve.Buck
			local steps = 0
			local refusal: string? = nil
			for _ = 1, C.MAGAZINE do
				-- EACH `Load` HAS ITS OWN WINDOW TOO (0.38 s), so the clock advances per shell. The
				-- version of this case that did not reported `1 Load step ... refused busy`, which
				-- is the reducer being right and the case being impatient.
				local next_, reason = StateMachine.apply(state, { kind = "Load" }, at, ROW)
				at += 1.0
				if reason ~= nil then
					refusal = reason
					break
				end
				state = next_
				steps += 1
			end
			TestKit.note(
				string.format(
					"task225 top-up: %d Load step(s), pocket %d -> %d, then refused %s",
					steps,
					before,
					state.reserve.Buck,
					tostring(refusal)
				)
			)
			expect(steps).to.equal(3)
			expect(live(state)).to.equal(5)
			expect(refusal).to.equal("barrel-full")
			-- ...AND `Weapon.cycleRefusal` CALLS THAT A FINISH, which is what makes the sequence end
			-- cleanly instead of taking the error path.
			expect(Weapon.cycleRefusal("Load", refusal)).to.equal("finish")
		end)
	end)

	describe("X on a tube gun: the first magazine readout with two loads", function()
		it("changes the NEXT load without touching a full tube, and the shot flies as what is in it", function()
			-- THE ARM NOTHING ELSE IN THE GAME CAN ENTER (design 15.1 case 9, section 6.4): this is
			-- the first weapon with `READOUT = "magazine"` AND two `AMMO_KINDS` AND
			-- `CYCLE_EJECTS = "spent"`. The side-by-side has two kinds and a per-chamber readout; both
			-- rifles have a magazine readout and one kind.
			local state = equipped(ROW)
			expect(state.ammo).to.equal("Buck")
			expect(live(state)).to.equal(5)
			local switched = StateMachine.apply(state, { kind = "SelectAmmo", ammo = "Slug" }, 0, ROW)
			-- THE TUBE IS UNTOUCHED -- five buckshot shells are still in it -- and only the NEXT load
			-- changed. That is honest and it is what a real tube gun does.
			expect(switched.ammo).to.equal("Slug")
			expect(live(switched)).to.equal(5)
			for index = 1, #switched.loaded do
				expect(switched.loaded[index]).to.equal("Buck")
			end
			-- ...SO A SHOT FROM THAT STATE FLIES AS BUCK, because `onFireRequest` reads
			-- `state.loaded[state.selected]` and not `state.ammo`.
			expect(switched.loaded[switched.selected]).to.equal("Buck")
			TestKit.note(
				string.format(
					"task225 X on a full tube: ammo=%s but chamber=%s, %d live",
					switched.ammo,
					switched.loaded[switched.selected],
					live(switched)
				)
			)
		end)

		it("prints rounds over capacity, with the NEXT load's word and five pips", function()
			-- Design 15.1 case 19, on the player's path: the Hud's own readout and ammo chip for THIS
			-- row, rather than the shape being traced in prose.
			local state = equipped(ROW)
			local line = Hud.readoutFor(Shotgun.snapshot(state, 0, nil, ROW.id), ROW)
			TestKit.note(string.format("task225 readout: %s", tostring(line)))
			expect(type(line)).to.equal("string")
			-- ROUNDS OVER CAPACITY, not one glyph per chamber -- which is what `READOUT = "magazine"`
			-- buys and what five chambers make unreadable otherwise.
			expect(string.find(line, "5/5", 1, true)).to.be.ok()
			expect(string.find(line, "BUCK", 1, true)).to.be.ok()
			-- ...AND THE CHIP DRAWS FIVE PIPS AND THIS SHELL'S OWN GLYPH. `ammoChipFor` always
			-- returns a table, so a `to.be.ok()` on it cannot fail -- the CONTENT is the case
			-- (the Reviewer, round 2). The glyph exists only because the row carries `AMMO_GLYPH`:
			-- the wire word is `Slug` on all four guns, so a chip keyed off that alone would draw
			-- a shotgun shell for a .416 Rigby cartridge.
			local chip = Hud.ammoChipFor(Shotgun.snapshot(state, 0, nil, ROW.id), ROW)
			TestKit.note(string.format("task225 chip: %d pip(s), glyph=%s", #chip.pips, tostring(chip.glyph)))
			expect(#chip.pips).to.equal(C.MAGAZINE)
			expect(chip.pips[1]).to.equal("live")
			expect(chip.glyph).to.equal("buck")
		end)
	end)

	describe("the two moving groups", function()
		it("names a bolt that travels STRAIGHT, which no other gun does", function()
			expect(SemiAutoGeometry.CYCLE_KIND).to.equal("straight")
			expect(SemiAutoGeometry.CYCLE_GROUP_NAME).to.equal("Bolt")
			-- The other three guns cannot reach this arm.
			for _, id in ipairs({ "shotgun", "rifle", "lever" }) do
				expect(Weapons.geometry(id).CYCLE_KIND).never.to.equal("straight")
			end
		end)

		it("draws the bolt BACK, far enough to clear a hull and not out of the receiver", function()
			-- THE SIGN, MADE FALSIFIABLE. `-Z` is the muzzle, so back is `+Z`: a wrong sign would
			-- push the bolt out of the muzzle, and nothing else in the repo says which way is which.
			local travel = semiConfig.BOLT_DRAW_STUDS
			local rest = SemiAutoGeometry.boltTravel(ROW, travel, 0)
			local full = SemiAutoGeometry.boltTravel(ROW, travel, 1)
			TestKit.note(
				string.format(
					"task225 bolt: %.4f studs back at full travel (hull %.4f)",
					full.Z - rest.Z,
					HULL_LENGTH_STUDS
				)
			)
			expect(full.Z > rest.Z).to.equal(true)
			expect(full.Z - rest.Z >= HULL_LENGTH_STUDS).to.equal(true)
			expect(full.Z - rest.Z <= SemiAutoGeometry.layout(ROW).boltTravelMax + 1e-6).to.equal(true)
			-- NOTHING ROTATES, which is what separates this from the Rigby's bolt.
			expect(full.RightVector).to.equal(rest.RightVector)
			expect(full.UpVector).to.equal(rest.UpVector)
			-- ...AND A CALLER THAT ASKS FOR MORE THAN THE RECEIVER HOLDS IS CLAMPED, not obeyed.
			local silly = SemiAutoGeometry.boltTravel(ROW, 99, 1)
			expect(silly.Z <= SemiAutoGeometry.layout(ROW).boltTravelMax + 1e-6).to.equal(true)
		end)

		it("declares a SECOND moving group, which no other gun has", function()
			expect(SemiAutoGeometry.LIFT_GROUP_NAME).to.equal("Lifter")
			for _, id in ipairs({ "shotgun", "rifle", "lever" }) do
				expect(Weapons.geometry(id).LIFT_GROUP_NAME).to.equal(nil)
			end
			-- ...and the geometry builds a piece for it, in the group `buildNewGun` parents to the
			-- second envelope.
			local sawLift = false
			for _, piece in ipairs(SemiAutoGeometry.pieces(ROW)) do
				if piece.group == "lift" then
					sawLift = true
					expect(piece.name).to.equal(SemiAutoGeometry.LIFT_GROUP_NAME)
				end
			end
			expect(sawLift).to.equal(true)
		end)

		it("RAISES the lifter's free end, by at least one hull diameter", function()
			-- THE OTHER SIGN, MADE FALSIFIABLE -- and this one had to be measured on the model
			-- rather than argued about, because the tray pins at the REAR and hangs forward: a
			-- negative turn would drive its free end down through the trigger guard.
			local deg = semiConfig.LIFTER_DEG
			local rest = SemiAutoGeometry.lifterTipOffset(ROW, deg, 0)
			local lifted = SemiAutoGeometry.lifterTipOffset(ROW, deg, 1)
			TestKit.note(
				string.format(
					"task225 lifter: %.1f deg raises the free end %+.4f studs (hull %.4f)",
					deg,
					lifted.Y - rest.Y,
					HULL_DIAMETER_STUDS
				)
			)
			expect(lifted.Y > rest.Y).to.equal(true)
			expect(lifted.Y - rest.Y >= HULL_DIAMETER_STUDS).to.equal(true)
			-- ...AND IT IS CLAMPED, so a caller that passed 1.4 cannot bury the tray in the barrel.
			local over = SemiAutoGeometry.lifterTipOffset(ROW, deg, 1.4)
			expect((over - lifted).Magnitude < 1e-6).to.equal(true)
		end)

		it("rises AND falls once per shell, because a tray takes the next one", function()
			-- THE RAMP'S OWN ARM. A monotone 0..1 would leave the tray standing up inside the
			-- receiver between shells, which is the shape every other moving group in this repo has
			-- and the shape this one must not have.
			local V = require(cameraScripts:WaitForChild("Viewmodel"))
			expect(V.lifterWeight(nil)).to.equal(0)
			expect(V.lifterWeight(0)).to.equal(0)
			expect(math.abs(V.lifterWeight(0.5) - 1) < 1e-6).to.equal(true)
			expect(math.abs(V.lifterWeight(1)) < 1e-6).to.equal(true)
			expect(V.lifterWeight(0.25) > 0).to.equal(true)
			expect(V.lifterWeight(0.75) > 0).to.equal(true)
		end)

		it("fits the lifter's window inside the step that drives it", function()
			local load: number? = nil
			for _, step in ipairs(C.RELOAD) do
				if step.kind == "Load" then
					load = step.wait
					break
				end
			end
			expect(load).to.be.ok()
			expect(semiConfig.LIFTER_SECONDS < (load :: number)).to.equal(true)
			-- ...and the drawn cycle is faster than the server performs it, the rule every gun keeps.
			expect(semiConfig.BREAK_OPEN_SECONDS < C.CYCLE[1].wait).to.equal(true)
			expect(semiConfig.BREAK_CLOSE_SECONDS < C.CYCLE[2].wait).to.equal(true)
		end)
	end)

	describe("the gun does not move when it cycles itself", function()
		it("holds the gun still from open to shut -- AND MOVES IT AT share 1, or this proves nothing", function()
			-- THE ARM `CYCLE_POSE_SHARE` EXISTS FOR, entered at BOTH ends (design 15.1 case 5's
			-- required negative arm, which round 2 of the review found missing).
			--
			-- IT IS DRIVEN AT BLEND 1, and that is not a detail. At blend 0 the gun's pose is
			-- `carryOffset` and the cycle target is `breakOffset` -- and on THIS gun those are the
			-- same numbers (`carry.gun` and `cycle.gun` are bit-identical in `poses.json`), so the
			-- `Lerp` is identity for every value of the share and a hip comparison cannot fail
			-- whatever the code does. At blend 1 the pose is the sight-solved aim, which is NOT
			-- `cycle.gun`, so the share actually gates something.
			expect(semiConfig.CYCLE_POSE_SHARE).to.equal(0)
			local shut, open = stateAt(1, 0), stateAt(1, 1)
			local a = Mode.viewmodelOffset(shut, nil, semiConfig)
			local b = Mode.viewmodelOffset(open, nil, semiConfig)
			local held = (a.Position - b.Position).Magnitude
			-- THE SAME TWO STATES WITH THE SHARE FORCED TO 1 MUST DIFFER. Without this the case
			-- above would pass just as happily against a `poseShare` nothing reads.
			local forced = table.clone(semiConfig) :: any
			forced.CYCLE_POSE_SHARE = 1
			forced = table.freeze(forced)
			local c = Mode.viewmodelOffset(shut, nil, forced)
			local d = Mode.viewmodelOffset(open, nil, forced)
			local moves = (c.Position - d.Position).Magnitude
			TestKit.note(string.format("task225 gun over a cycle: %.6f studs at share 0, %.4f at share 1", held, moves))
			expect(held < 1e-6).to.equal(true)
			expect(moves > 0.05).to.equal(true)
		end)

		it("holds BOTH hands still -- and they are held by the pose data, not by the share", function()
			-- SAID PLAINLY BECAUSE THE SHORT VERSION IS MISLEADING (the Reviewer, round 2). The
			-- hands do not move on this gun, but `CYCLE_POSE_SHARE` is not what stops them:
			-- `Mode.handFrame` blends `carry` -> `aim` -> `cycle`, and on this gun ALL THREE hand
			-- poses are bit-identical, so the hand frame is constant across every state and every
			-- share. That is the right answer for a gas gun -- the shooter's hands really do
			-- nothing -- and this case asserts the fact rather than claiming the mechanism.
			local forced = table.clone(semiConfig) :: any
			forced.CYCLE_POSE_SHARE = 1
			forced = table.freeze(forced)
			for _, side in ipairs({ "left", "right" }) do
				local hip = Mode.handOffsetAt(side, stateAt(0, 0), semiConfig)
				for _, case in ipairs({
					{ name = "aimed", state = stateAt(1, 0), config = semiConfig },
					{ name = "cycling", state = stateAt(1, 1), config = semiConfig },
					{ name = "cycling at share 1", state = stateAt(1, 1), config = forced },
				}) do
					local at = Mode.handOffsetAt(side, case.state, case.config)
					expect((at.Position - hip.Position).Magnitude < 1e-6).to.equal(true)
				end
			end
			-- ...AND THE POSE DATA REALLY DOES SAY SO, which is the fact the case rests on.
			local set = Viewmodel.DATA.weapons.semiauto
			for _, side in ipairs({ "left", "right" }) do
				for _, key in ipairs({ "x", "y", "z" }) do
					expect(set.cycle[side].pos[key]).to.equal(set.carry[side].pos[key])
					expect(set.aim[side].pos[key]).to.equal(set.carry[side].pos[key])
				end
			end
		end)

		it("leaves every gun written before it moving exactly as much as it did", function()
			-- THE DEFAULT ARM, and the reason this ships without a flag: the key is ABSENT from the
			-- three shipped pose sets, so the share is 1 and the expression is the expression. If
			-- this case ever fails, a shipped gun's feel changed.
			for _, id in ipairs({ "shotgun", "rifle", "lever" }) do
				local other = configFor(id)
				expect(other.CYCLE_POSE_SHARE).to.equal(nil)
				local a = Mode.viewmodelOffset(stateAt(1, 0), nil, other)
				local b = Mode.viewmodelOffset(stateAt(1, 1), nil, other)
				TestKit.note(
					string.format(
						"task225 %s still moves %.4f studs over its action",
						id,
						(a.Position - b.Position).Magnitude
					)
				)
				expect((a.Position - b.Position).Magnitude > 1e-3).to.equal(true)
			end
		end)
	end)

	describe("the red dot", function()
		it("is DRAWN, emissive, and on the bore's own centre line", function()
			expect(ROW.SIGHT).to.equal("reddot")
			expect(ROW.scope).to.equal(nil) -- no mask, no eyepiece: the shotgun's aim path
			local dot: any = nil
			for _, piece in ipairs(SemiAutoGeometry.pieces(ROW)) do
				if piece.name == "Dot" then
					dot = piece
				end
			end
			expect(dot).to.be.ok()
			expect(dot.material).to.equal(Enum.Material.Neon)
			expect(dot.meshKey).to.equal(nil) -- drawn, not uploaded: SurfaceAppearance has no emission
			expect(dot.offset.Position.X).to.equal(0)
			expect(dot.offset.Position).to.equal(SemiAutoGeometry.beadOffset(ROW))
			-- ONE EXPRESSION for the thing the eye sees and the point it is laid on.
			expect(SemiAutoGeometry.sight(ROW).Position).to.equal(SemiAutoGeometry.beadOffset(ROW))
			-- ...and it sits ABOVE the bore, where a sight on a rail is.
			expect(SemiAutoGeometry.beadOffset(ROW).Y > 0.12).to.equal(true)
		end)

		it("THE SIGHT PICTURE: a hood to look through, a lens, and the dot on the screen centre", function()
			-- TASK 234, KAREN OWN DEFECT, REPRODUCED FIRST (rule H,
			-- `.screenshots/234-before-semiauto-aim.png`): aimed, the player saw a bare red ball
			-- over the receiver and nothing to look through. *"you know this type of aiming you
			-- look from that galss and there is a dot inside right ?"* Task 227 had faded the
			-- bought one-piece optic out of the sight line because its glass is an opaque amber
			-- face; 227b queued the housing, and this is it.
			--
			-- EVERY BOUND BELOW IS IN DEGREES AT THE SHIPPED EYE RELIEF, which is the only unit the
			-- picture actually has: studs say nothing about what fills the screen, and the research
			-- note section 5 was tuned against Karen two reference photographs measured the same
			-- way (`<runs-dir>/234-ring.py`).
			local view = Viewmodel.view(Viewmodel.DATA, "semiauto")
			local aimConfig = { EYE_RELIEF_STUDS = view.EYE_RELIEF_STUDS, ADS_CHEEK_DEG = view.ADS_CHEEK_DEG }
			local gun = Mode.aimOffset(SemiAutoGeometry.sight(ROW), aimConfig)
			local p = gun:PointToWorldSpace(SemiAutoGeometry.beadOffset(ROW))
			local depth = -p.Z
			local off = math.deg(math.atan2(math.sqrt(p.X * p.X + p.Y * p.Y), math.max(depth, 1e-9)))
			TestKit.note(string.format("task234 semiauto: dot depth %.4f off %.6f deg", depth, off))
			expect(depth > 0.2).to.equal(true) -- in front of the eye
			expect(off < 0.05).to.equal(true) -- and on the centre, where the shot goes

			-- 1. THE HOOD IS A RING, AND IT IS ROUND. Every segment the same distance from the
			--    sight line, every segment the same size, and enough of them that the polygon is
			--    not a nut: 16 was tried and LOOKED like a 16-gon (`.screenshots/234-a3-aim.png`).
			local at = SemiAutoGeometry.layout(ROW)
			local centre = SemiAutoGeometry.beadOffset(ROW)
			local hood, glass, mount = {}, nil, nil
			for _, piece in ipairs(SemiAutoGeometry.pieces(ROW)) do
				if string.sub(piece.name, 1, 9) == "SightHood" then
					table.insert(hood, piece)
				elseif piece.name == "SightGlass" then
					glass = piece
				elseif piece.name == "SightMount" then
					mount = piece
				end
			end
			expect(#hood >= 20).to.equal(true)
			local mid = (at.hoodInnerRadius + at.hoodOuterRadius) / 2
			for _, piece in ipairs(hood) do
				local v = piece.offset.Position - centre
				expect(math.abs(v.Z) < 1e-5).to.equal(true) -- on the lens plane
				expect(math.abs(math.sqrt(v.X * v.X + v.Y * v.Y) - mid) < 1e-4).to.equal(true)
				expect(piece.meshKey).to.equal(nil) -- drawn, not an upload
			end

			-- 2. ...AND THE SEGMENTS TOUCH. A chord sized on the MIDDLE radius leaves daylight at
			--    every joint and the frame came back a cog wheel; the covering condition at the
			--    seam is `halfChord >= rOuter * sin(pi/N)`, and this is that condition.
			local seam = at.hoodOuterRadius * math.sin(math.pi / #hood)
			TestKit.note(
				string.format(
					"task234 hood: %d segments, half-chord %.5f vs seam %.5f",
					#hood,
					hood[1].size.X / 2,
					seam
				)
			)
			expect(hood[1].size.X / 2 >= seam - 1e-6).to.equal(true)

			-- 3. THE WINDOW IS WHAT KAREN REFERENCES SHOW. ref-1 measures 31 % of the frame width
			--    clear with its rim out to 38 %; at FOV 50 on a 16:9 frame the horizontal field is
			--    2*atan(tan(25 deg)*16/9) = 79.3 degrees, so those are 24.6 and 30.1 degrees. The
			--    bounds below are deliberately WIDE either side of that -- this case exists to
			--    catch a sight picture DESTROYED by a later change to the hood or the relief, not
			--    to re-litigate a look Karen has to judge herself.
			local relief = view.EYE_RELIEF_STUDS
			local windowDeg = 2 * math.deg(math.atan(at.hoodInnerRadius / relief))
			local rimDeg = 2 * math.deg(math.atan(at.hoodOuterRadius / relief))
			TestKit.note(
				string.format(
					"task234 sight picture at relief %.3f: window %.1f deg, rim %.1f deg",
					relief,
					windowDeg,
					rimDeg
				)
			)
			expect(windowDeg > 12).to.equal(true) -- a window you can hunt through
			expect(windowDeg < 32).to.equal(true) -- ...and a sight, not a porthole
			expect(rimDeg > windowDeg).to.equal(true) -- the rim is IN VIEW around it
			expect(rimDeg < 42).to.equal(true)
			-- ...AND THE CEILING KAREN SET HERSELF (task 242, 2026-10-22: *"circle is to big"*). The
			-- bounds above are the WIDE ones task 234 wrote to catch a destroyed sight picture; this
			-- one is narrow on purpose, because a ring that creeps back over 18 degrees is the
			-- complaint coming back. Shipped: 16.4 against task 234's 23.8.
			expect(rimDeg < 18).to.equal(true)

			-- 4. THE DOT READS, AND IT DOES NOT HIDE A DEER AT 50 M. A stag is 2.1 m tall, which at
			--    50 m is 2 * atan(1.05/50) = 2.4 degrees. The Director rule: it must be findable
			--    at 1280 x 720 and must not blot the animal out.
			local dotDeg = 2 * math.deg(math.atan(at.dotDiameter / 2 / relief))
			local stagDeg = 2 * math.deg(math.atan(1.05 / 50))
			TestKit.note(string.format("task234 dot: %.2f deg against a stag %.2f deg at 50 m", dotDeg, stagDeg))
			expect(dotDeg > 0.4).to.equal(true) -- bigger than a real 2 MOA, which would be half a pixel
			expect(dotDeg < stagDeg / 2).to.equal(true)
			-- ...AND KAREN'S OWN CEILING AGAIN (task 242: *"dot is to big"*). Shipped 0.49 against
			-- task 234's 0.98, which is the halving she asked for; 0.6 is where it stops being that.
			expect(dotDeg < 0.6).to.equal(true)
			expect(dotDeg * 6 < windowDeg).to.equal(true) -- small inside its own window

			-- 5. THE LENS IS CLEAR AND IT IS BETWEEN THE EYE AND THE DOT. +Z is backward in this
			--    frame, so "toward the eye" is a LARGER z than the dot.
			expect(glass).to.be.ok()
			expect(glass.transparency ~= nil and glass.transparency > 0.8).to.equal(true)
			expect(glass.transparency < 1).to.equal(true) -- a lens you can see, not an absent one
			expect(glass.material).to.equal(Enum.Material.SmoothPlastic)
			expect(glass.offset.Position.Z > centre.Z).to.equal(true)
			-- ...AND IT FILLS THE WINDOW. Compared with a tolerance and not by identity: a
			-- `Vector3` stores float32, so a float64 radius put into one and read back is near
			-- rather than equal -- which is the whole of why this line needs an epsilon.
			expect(math.abs(glass.size.Y - at.hoodInnerRadius * 2) < 1e-5).to.equal(true)

			-- 6. THE NEAR PLANE. The eye lands inside the receiver z span at this relief, so the
			--    reason there is no hole in the gun is the MOUNT height: at the bottom edge of the
			--    frame (25 degrees below the axis at FOV 50) the receiver top must be further than
			--    Roblox 0.1-stud clip. This is the arithmetic of research note section 6.
			expect(mount).to.be.ok()
			local aboveRail = centre.Y - at.railTopY
			local atFrameEdge = aboveRail / math.tan(math.rad(25))
			TestKit.note(
				string.format(
					"task234 near plane: sight line %.4f above the rail, %.4f studs away at the frame "
						.. "bottom edge (clip 0.1)",
					aboveRail,
					atFrameEdge
				)
			)
			expect(aboveRail > 0).to.equal(true)
			expect(atFrameEdge > 0.1).to.equal(true)
			-- ...and the mount is what holds that gap: it reaches the rail and the hood underside.
			local mountTop = mount.offset.Position.Y + mount.size.Y / 2
			expect(math.abs(mountTop - (centre.Y - at.hoodOuterRadius)) < 1e-4).to.equal(true)
			expect(mount.offset.Position.Y - mount.size.Y / 2 < at.railTopY).to.equal(true)

			-- 7. THE BOUGHT OPTIC IS NOT WORN BY THE VIEWMODEL ON THIS ROW, which is the whole
			--    shape of the fix: its glass is one opaque face on a mesh that cannot be split, so
			--    it would sit between the eye and everything the hood frames.
			for _, piece in ipairs(SemiAutoGeometry.pieces(ROW)) do
				expect(piece.name ~= "Optic").to.equal(true)
				expect(piece.clearFromBlend).to.equal(nil)
			end
			-- ...but the WORLD gun still wears it, so another player sees the artist sight.
			local wearsSight = false
			for _, key in ipairs(SemiAutoGeometry.ASSET_KEYS) do
				wearsSight = wearsSight or key == SemiAutoGeometry.MESH_KEYS.Optic
			end
			expect(wearsSight).to.equal(true)
		end)

		it("task 227 fade survives for a row that is not the red dot, and now knows first person", function()
			-- `clearFromBlend` HAS NO SHIPPED USER SINCE TASK 234 -- the same standing `onlyFor`
			-- has had since task 148 -- and it is kept because it is the one answer to "this piece
			-- must stop blocking the sight line" (research note section 7). So its arm is entered
			-- here through the filter that still reaches it: a row with iron sights gets the
			-- artist housing back, and that housing still fades as the eye arrives.
			local other = table.clone(C) :: any
			other.SIGHT = "bead"
			local optic, cleared = nil, 0
			for _, piece in ipairs(SemiAutoGeometry.pieces(other)) do
				if piece.clearFromBlend ~= nil then
					cleared += 1
					optic = piece
				end
			end
			expect(cleared).to.equal(1)
			expect(optic.name).to.equal("Optic")
			expect(optic.meshKey).to.equal(SemiAutoGeometry.MESH_KEYS.Optic)

			local function aimState(mode: string, blend: number)
				local st = table.clone(Mode.initial(Config)) :: any
				st.mode = mode
				st.blend = blend
				return table.freeze(st)
			end
			local from = optic.clearFromBlend
			expect(Viewmodel3D.clearAtAim(aimState("Aiming", 1), from)).to.equal(1)
			expect(Viewmodel3D.clearAtAim(aimState("Aiming", from), from)).to.equal(0)
			expect(Viewmodel3D.clearAtAim(aimState("Third", 1), from)).to.equal(0)
			expect(Viewmodel3D.clearAtAim(aimState("Aiming", 1), nil)).to.equal(0)
			-- ...and it is not a step: half way past the threshold it is half gone.
			local half = (from + 1) / 2
			expect(math.abs(Viewmodel3D.clearAtAim(aimState("Aiming", half), from) - 0.5) < 1e-6).to.equal(true)

			-- TASK 227 REVIEW NOTE (a), TAKEN IN 234: the mode name alone is not enough. With
			-- `FIRST_PERSON` off, `Mode` still reaches `"Aiming"` and the gun is still drawn, over
			-- a camera a boom behind the shoulder -- so a housing that dissolved there would be a
			-- sight that vanishes for no reason the player can see.
			expect(Viewmodel3D.clearAtAim(aimState("Aiming", 1), from, false)).to.equal(0)
			expect(Viewmodel3D.clearAtAim(aimState("Aiming", 1), from, true)).to.equal(1)
			-- ...and a caller that says nothing gets the answer it always got.
			expect(Viewmodel3D.clearAtAim(aimState("Aiming", 1), from)).to.equal(1)

			-- NO OTHER GUN IS TOUCHED: the shotgun, the Rigby and the lever carry no such piece.
			for _, id in ipairs({ "shotgun", "rifle", "lever" }) do
				local row = Weapons.ROWS[id]
				for _, piece in ipairs(Weapons.geometry(id).pieces(row)) do
					expect(piece.clearFromBlend).to.equal(nil)
				end
			end
		end)

		it("is dropped for a sight that is not this one, through task 143's filter", function()
			-- THE FILTER'S OWN ARM, entered: the same geometry asked for a bead draws no dot.
			local other = table.clone(C) :: any
			other.SIGHT = "bead"
			local sawDot = false
			for _, piece in ipairs(SemiAutoGeometry.pieces(other)) do
				sawDot = sawDot or piece.name == "Dot"
			end
			expect(sawDot).to.equal(false)
			expect(SemiAutoGeometry.sightKind(other)).to.equal("bead")
		end)
	end)

	describe("the hands, on this gun's own two holds", function()
		it("holds the GRIP with the right hand, inside the gun's own two bounds", function()
			-- Computed through `Mode.handOffsetAt`, which is the one conversion site the viewmodel
			-- really draws with -- NOT by reading `pos` out of the file, because the two differ by
			-- the glove's own `GRIP_STUDS` and a pose checked at its origin is a pose nobody
			-- checked (task 224 round 2's finding 1).
			for _, case in ipairs({
				{ name = "hip", state = stateAt(0, 0) },
				{ name = "aimed", state = stateAt(1, 0) },
				{ name = "cycle", state = stateAt(0, 1) },
			}) do
				local at = gripPointOf(Mode.handOffsetAt("right", case.state, semiConfig))
				local off = SemiAutoGeometry.offGripAxis(ROW, at)
				local along = SemiAutoGeometry.alongGripAxis(ROW, at)
				TestKit.note(
					string.format(
						"task225 right hand %s: %.4f off the grip axis (bound %.4f), %+.4f along it (bound %.4f)",
						case.name,
						off,
						SemiAutoGeometry.gripRadius(ROW),
						along,
						SemiAutoGeometry.gripHalfLength(ROW)
					)
				)
				expect(off < SemiAutoGeometry.gripRadius(ROW)).to.equal(true)
				expect(math.abs(along) < SemiAutoGeometry.gripHalfLength(ROW)).to.equal(true)
			end
		end)

		it("holds the FORE-END with the left hand, inside its own two bounds", function()
			-- The design's item 9 asks for BOTH holds bounded. A bound on one hand only lets the
			-- other slide off the gun unnoticed, which on this gun is the longer of the two.
			for _, case in ipairs({
				{ name = "hip", state = stateAt(0, 0) },
				{ name = "aimed", state = stateAt(1, 0) },
				{ name = "cycle", state = stateAt(0, 1) },
			}) do
				local at = gripPointOf(Mode.handOffsetAt("left", case.state, semiConfig))
				local off = SemiAutoGeometry.offForeAxis(ROW, at)
				local along = SemiAutoGeometry.alongForeAxis(ROW, at)
				TestKit.note(
					string.format(
						"task225 left hand %s: %.4f off the fore-end axis (bound %.4f), %+.4f along it (bound %.4f)",
						case.name,
						off,
						SemiAutoGeometry.foreRadius(ROW),
						along,
						SemiAutoGeometry.foreHalfLength(ROW)
					)
				)
				expect(off < SemiAutoGeometry.foreRadius(ROW)).to.equal(true)
				expect(math.abs(along) < SemiAutoGeometry.foreHalfLength(ROW)).to.equal(true)
			end
		end)

		it("puts NO loose shells in the hands, and declares that rather than inferring it", function()
			expect(SemiAutoGeometry.HAND_FED_SHELLS).to.equal(false)
			-- ...and the shooter's hands do nothing during a cycle: no `hand` block means the right
			-- hand stays on the grip, which is the whole truth about a gas gun.
			expect(semiConfig.BOLT_HAND).to.equal(nil)
		end)
	end)

	describe("the world gun and the shop", function()
		it("draws a world shape with the sight that says it is not the side-by-side", function()
			local shape = Shapes.for_("semiauto")
			expect(shape).to.be.ok()
			local names = {}
			for _, piece in ipairs(shape.pieces(ROW)) do
				table.insert(names, piece.name)
			end
			TestKit.note(string.format("task225 world pieces: %s", table.concat(names, ", ")))
			expect(#names).to.equal(5)
			expect(shape.muzzleZ(ROW)).to.equal(-ROW.HANDLE_SIZE.Z / 2)
			expect(shape.sight(ROW).Position).to.equal(SemiAutoGeometry.beadOffset(ROW))
		end)

		it("is sold at 500, under the lever, and grants itself", function()
			local row = Shop.row(Shop.ITEM.SEMIAUTO)
			expect(row).to.be.ok()
			expect(row.category).to.equal("weapon")
			expect(row.sale).to.equal(true)
			expect(row.price).to.equal(500)
			expect(row.grants.weapon).to.equal("semiauto")
			expect(row.price < Shop.row(Shop.ITEM.LEVER).price).to.equal(true)
			expect(row.price < Shop.row(Shop.ITEM.RIFLE).price).to.equal(true)
			-- ...and ownership of THIS row is what `Shop.ownsWeapon` answers for THIS gun.
			expect(Shop.ownsWeapon({ [Shop.ITEM.SEMIAUTO] = true }, "semiauto")).to.equal(true)
			expect(Shop.ownsWeapon({}, "semiauto")).to.equal(false)
		end)
	end)
end
