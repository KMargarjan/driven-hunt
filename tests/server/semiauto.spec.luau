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
			-- SLOWER THAN THE SIDE-BY-SIDE'S, which is the price of five rounds -- and QUICKER
			-- than the lever's 2.90, because a shotgun's port is a bigger hole than a rifle's
			-- gate. The design's section 6.2 calls this "the slowest reload in the game"; it is
			-- not, and this case is what measured that.
			expect(C.RELOAD_TOTAL > Shotgun.CONFIG.RELOAD_TOTAL).to.equal(true)
			expect(C.RELOAD_TOTAL < Lever.CONFIG.RELOAD_TOTAL).to.equal(true)
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
			local before = state.reserve.Buck
			local steps = 0
			local refusal: string? = nil
			for _ = 1, C.MAGAZINE do
				local next_, reason = StateMachine.apply(state, { kind = "Load" }, at, ROW)
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
		it("holds the gun and BOTH hands still from open to shut", function()
			-- THE ARM `CYCLE_POSE_SHARE` EXISTS FOR, entered at both ends. At `poseShare = 0` the
			-- pose at full open must be the pose at rest, to the last decimal -- otherwise this gun
			-- lurches out of its own sight picture 2.4 times a second.
			expect(semiConfig.CYCLE_POSE_SHARE).to.equal(0)
			local shut, open = stateAt(1, 0), stateAt(1, 1)
			local a = Mode.viewmodelOffset(shut, nil, semiConfig)
			local b = Mode.viewmodelOffset(open, nil, semiConfig)
			TestKit.note(
				string.format(
					"task225 gun pose moved %.6f studs over a whole cycle",
					(a.Position - b.Position).Magnitude
				)
			)
			expect((a.Position - b.Position).Magnitude < 1e-6).to.equal(true)
			for _, side in ipairs({ "left", "right" }) do
				local p = Mode.handOffsetAt(side, shut, semiConfig)
				local q = Mode.handOffsetAt(side, open, semiConfig)
				expect((p.Position - q.Position).Magnitude < 1e-6).to.equal(true)
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
