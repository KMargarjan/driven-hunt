-- lever.spec: the lever-action rifle's row, its ballistics, its throw, its gate reload, the one
-- refusal rule that reload forced, and its shop row. Pure: no Instances, no clock, no Player, no
-- client.
--
-- WHAT THIS FILE IS FOR, in one sentence: **every case must enter THIS weapon's own branch.** A
-- third gun that is only ever tested through code the second gun also reaches is a third gun nobody
-- has tested -- so each case below says what makes it the lever's and not the Rigby's, and the two
-- shipped guns are asserted to be UNABLE to reach the one new branch in `runCycle`.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/lever-rifle.md (sections 6, 9, 15.1)
-- Note:   docs/research/2026-10-20-lever-action.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Lever = require(ReplicatedStorage:WaitForChild("Lever"))
local LeverGeometry = require(ReplicatedStorage:WaitForChild("Lever"):WaitForChild("Geometry"))
local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
-- THE HAND ANCHORS (round 2) need three things this file did not read: where the hand holds
-- (`HandAssets`), the camera's own pose maths (`Mode.handOffsetAt`, which is the ONE conversion
-- site the viewmodel draws with), and a config carrying this weapon's pose set.
local StarterPlayer = game:GetService("StarterPlayer")
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))
local cameraScripts = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Camera")
local Config = require(cameraScripts:WaitForChild("Config"))
local Mode = require(cameraScripts:WaitForChild("Mode"))

local StateMachine = Weapon.StateMachine
local Shapes = Weapon.Shapes
local ROW = Weapons.ROWS.lever
local C = Lever.CONFIG

local METRES_PER_STUD = 0.28
local FPS_PER_STUD_PER_S = METRES_PER_STUD / 0.3048

local function equipped(row)
	return StateMachine.setEquipped(StateMachine.initial(row), true)
end

-- THE GLOVE'S OWN GRIP POINT, not the pose's origin: `HandAssets.GRIP_STUDS` is the hole in the
-- closed fist, and a pose is only "on the gun" if THAT lands on the gun. Lifted verbatim from
-- `tests/server/viewmodel_poses.spec.luau`, which holds the Rigby's hands the same way -- so the two
-- guns are measured by one expression and cannot drift apart.
local function gripPointOf(offset: CFrame): Vector3
	return offset:PointToWorldSpace(HandAssets.GRIP_STUDS)
end

-- The lever's own pose set, as the camera resolves it: `Mode.handOffsetAt` reads these fields.
local leverConfig = (function()
	local out = table.clone(Config) :: any
	for key, value in pairs(Viewmodel.view(Viewmodel.DATA, "lever")) do
		out[key] = value
	end
	out.FIRST_PERSON = true
	return table.freeze(out)
end)()

local function stateAt(blend: number, openTilt: number)
	local state = table.clone(Mode.initial(Config)) :: any
	state.mode = if blend > 0 then "Aiming" else "Third"
	state.blend = blend
	state.openTilt = openTilt
	return table.freeze(state)
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

return function()
	describe("the row is the lever's own config, and no other gun's", function()
		it("is a third weapon on slot 3, and it reads NOTHING out of Rifle.CONFIG", function()
			expect(ROW.id).to.equal("lever")
			expect(ROW.slot).to.equal(3)
			expect(ROW.toolName).to.equal("Lever")
			-- THE TWO RIFLES SHARE NO NUMBER. `Rifle`'s own header is the rule: the file that holds
			-- Karen's accepted numbers must not become the file everybody edits. Every ballistic
			-- number differs, and that is asserted rather than assumed.
			expect(ROW.RANGE_STUDS.Slug ~= Rifle.CONFIG.RANGE_STUDS.Slug).to.equal(true)
			expect(ROW.MUZZLE_STUDS_PER_S.Slug ~= Rifle.CONFIG.MUZZLE_STUDS_PER_S.Slug).to.equal(true)
			expect(ROW.DRAG_PER_STUD.Slug ~= Rifle.CONFIG.DRAG_PER_STUD.Slug).to.equal(true)
			expect(ROW.ZERO_STUDS.Slug ~= Rifle.CONFIG.ZERO_STUDS.Slug).to.equal(true)
			expect(ROW.GRAVITY_SCALE.Slug ~= Rifle.CONFIG.GRAVITY_SCALE.Slug).to.equal(true)
			expect(ROW.CYCLE_TOTAL ~= Rifle.CONFIG.CYCLE_TOTAL).to.equal(true)
			expect(ROW.BARRELS ~= Rifle.CONFIG.BARRELS).to.equal(true)
		end)

		it("is built field by field from Lever.CONFIG, so a number that moves fails here", function()
			-- THE SHAPE TASK 143 ASKED FOR: a walk over the config with a skip set, rather than a
			-- hand-written list that forgets the field somebody just added.
			local skip = { LOOK = true, SOUND = true }
			local checked = 0
			for key, value in pairs(C) do
				if not skip[key] then
					expect((ROW :: any)[key]).to.equal(value)
					checked += 1
				end
			end
			expect(checked > 20).to.equal(true)
			TestKit.note(string.format("task224: %d row fields asserted against Lever.CONFIG", checked))
			-- The two that are read THROUGH rather than copied.
			expect(ROW.HANDLE_COLOR).to.equal(C.LOOK.wood)
			expect(ROW.LOOK).to.equal(C.LOOK)
			expect(ROW.SOUND).to.equal(C.SOUND)
		end)

		it("carries no rule that belongs to the drive or to the protocol", function()
			-- `Weapons`' own header: a per-weapon safety arc would let a new gun widen its own
			-- licence to shoot down the line.
			for _, forbidden in ipairs({
				"SAFETY_ARC_HALF_DEG",
				"AUTO_EQUIP",
				"shouldArm",
				"ACTION_RATE_LIMIT",
				"FIRE_RATE_LIMIT",
			}) do
				expect((ROW :: any)[forbidden]).to.equal(nil)
			end
		end)

		it("prints a label short enough for the report's gun column", function()
			-- 88 px, and task 219 measured `SHOTGUN` at 46 px in that cell's own face.
			expect(ROW.label).to.equal("LEVER")
			expect(#ROW.label <= 7).to.equal(true)
		end)
	end)

	describe("the .45-70", function()
		it("carries every number the flight requires, and the shot resolves", function()
			for _, field in ipairs({
				"MUZZLE_STUDS_PER_S",
				"DRAG_PER_STUD",
				"ZERO_STUDS",
				"GRAVITY_SCALE",
				"RANGE_STUDS",
			}) do
				expect((ROW :: any)[field].Slug).to.be.ok()
			end
			expect(Ballistics.shotFor(ROW, "Slug")).to.be.ok()
			-- The zero is inside the reach, or the gun is zeroed where its bullet never arrives.
			expect(ROW.ZERO_STUDS.Slug < ROW.RANGE_STUDS.Slug).to.equal(true)
		end)

		it("PREDICTS the published 200 yd and 300 yd velocities to within 1 per cent", function()
			-- THE WHOLE ARGUMENT FOR ONE DRAG COEFFICIENT (research note section 3). `DRAG_PER_STUD`
			-- was fitted to the 100 yd point ALONE; these two points had nothing fitted to them, and
			-- this is the case that would fail if somebody "tidied" the coefficient.
			local shot = Ballistics.shotFor(ROW, "Slug")
			local cases = { { 653.14, 1450 }, { 979.71, 1225 } }
			for _, case in ipairs(cases) do
				local studs, published = case[1], case[2]
				local fps = Ballistics.speedAt(shot, studs) * FPS_PER_STUD_PER_S
				local err = math.abs(fps - published) / published
				TestKit.note(
					string.format(
						"task224 drag: %.0f studs -> %.0f fps vs %d (%.2f%%)",
						studs,
						fps,
						published,
						err * 100
					)
				)
				expect(err < 0.01).to.equal(true)
			end
		end)

		it("is dead on at its own 100 m zero and falls visibly past it, which the Rigby does not", function()
			-- KAREN'S DIAL (`GRAVITY_SCALE = 0.35`), and the band is what the research note states.
			local shot = Ballistics.shotFor(ROW, "Slug")
			local function cmOff(metres)
				return Ballistics.sightOffsetAt(shot, metres / METRES_PER_STUD) * METRES_PER_STUD * 100
			end
			expect(math.abs(cmOff(100)) < 0.5).to.equal(true)
			expect(math.abs(cmOff(50)) < 2.5).to.equal(true)
			expect(math.abs(cmOff(150)) < 7.0).to.equal(true)
			TestKit.note(
				string.format(
					"task224 band: 50 m %+.2f cm, 100 m %+.2f, 150 m %+.2f",
					cmOff(50),
					cmOff(100),
					cmOff(150)
				)
			)
			-- AND IT IS NOT THE SCOPED RIFLE'S TRAJECTORY. The Rigby is flattened to 0.12 and zeroed
			-- at 200 m; this gun drops, which is the character the two guns must not share.
			local rigby = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug")
			local rigbyAt150 = Ballistics.sightOffsetAt(rigby, 150 / METRES_PER_STUD) * METRES_PER_STUD * 100
			expect(math.abs(cmOff(150)) > math.abs(rigbyAt150)).to.equal(true)
		end)

		it("throws one bullet, exactly along the aim, with no cone", function()
			expect(ROW.PELLETS.Slug).to.equal(1)
			expect(ROW.SPREAD_FULL_DEG.Slug).to.equal(0)
		end)
	end)

	describe("the throw and the gate", function()
		it("cycles in two steps that sum to the stated total, faster than the bolt", function()
			expect(#ROW.CYCLE).to.equal(2)
			expect(ROW.CYCLE[1].kind).to.equal("Break")
			expect(ROW.CYCLE[2].kind).to.equal("Close")
			local sum = ROW.CYCLE[1].wait + ROW.CYCLE[2].wait
			expect(math.abs(sum - ROW.CYCLE_TOTAL) < 1e-9).to.equal(true)
			expect(ROW.CYCLE_TOTAL).to.equal(1.10)
			-- LEVER-ONLY: 1.10 against the bolt's 1.62, which is Karen's own number from task 184.
			expect(ROW.CYCLE_TOTAL < Rifle.CONFIG.CYCLE_TOTAL).to.equal(true)
			expect(ROW.AUTO_CYCLE).to.equal(true)
			expect(ROW.CYCLE_EJECTS).to.equal("spent")
		end)

		it("reloads through the gate: Break, one Load per chamber, Close -- and NO Magazine step", function()
			local reload = ROW.RELOAD :: any
			expect(#reload).to.equal(ROW.BARRELS + 2)
			expect(reload[1].kind).to.equal("Break")
			expect(reload[#reload].kind).to.equal("Close")
			local loads, sum = 0, 0
			for _, step in ipairs(reload) do
				-- LEVER-ONLY: the Rigby's RELOAD BEGINS with `Magazine`. This gun has no box, so a
				-- `Magazine` step anywhere in this list is the wrong gun's reload.
				expect(step.kind ~= "Magazine").to.equal(true)
				if step.kind == "Load" then
					loads += 1
				end
				sum += step.wait
			end
			expect(loads).to.equal(ROW.MAGAZINE)
			expect(math.abs(sum - (ROW.RELOAD_TOTAL :: number)) < 1e-9).to.equal(true)
			-- KAREN'S CUT (task 242, 2026-10-22: *"and lever weapon need to reload much faster"*).
			-- Task 224's claim here was that filling a tube is SLOWER than swapping a box, and it
			-- asserted this gun against the Rigby's 1.97. She has played it and overruled the trade,
			-- so the assertion is the new fact and not the old one: 1.59, which is 45 % off 2.90.
			expect(ROW.RELOAD_TOTAL).to.equal(1.59)
			expect((ROW.RELOAD_TOTAL :: number) < (Rifle.CONFIG.RELOAD_TOTAL :: number)).to.equal(true)
			-- ...AND IT IS STILL LONGER THAN ONE LEVER THROW, which is the relation that has to hold
			-- whatever the dial says: five cartridges through a gate cannot cost less than one cycle
			-- of the action, or the reload is reading as free.
			expect((ROW.RELOAD_TOTAL :: number) > (ROW.CYCLE_TOTAL :: number)).to.equal(true)
			-- EVERY STEP IS SCALED AND NONE IS SKIPPED: the list is still Break + five Loads + Close
			-- (asserted above), and every wait is a real window the pose player is driven by.
			for _, step in ipairs(reload) do
				expect(step.wait > 0.2).to.equal(true)
			end
		end)

		it("charges each sequence its OWN Break window", function()
			-- The defect task 184 measured: `Break` is in both lists with different waits, so the
			-- reducer must be told which list the step came from. LEVER-ONLY: this gun's two lists
			-- disagree about `Break` by 0.06 s.
			expect(ROW.CYCLE[1].wait ~= (ROW.RELOAD :: any)[1].wait).to.equal(true)
			local base = equipped(ROW)
			local now = 0
			local afterCycle = StateMachine.apply(base, { kind = "Break" }, now, ROW, ROW.CYCLE)
			local afterReload = StateMachine.apply(base, { kind = "Break" }, now, ROW, ROW.RELOAD)
			expect(math.abs(afterCycle.busyUntil - (now + ROW.CYCLE[1].wait)) < 1e-9).to.equal(true)
			expect(math.abs(afterReload.busyUntil - (now + (ROW.RELOAD :: any)[1].wait)) < 1e-9).to.equal(true)
		end)
	end)

	describe("the reducer, driven with this row", function()
		it("holds five, and a throw ejects the fired case and leaves the other four", function()
			local state = equipped(ROW)
			expect(#state.barrels).to.equal(5)
			expect(live(state)).to.equal(5)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 0, ROW)
			expect(live(fired)).to.equal(4)
			-- LEVER-ONLY: `CYCLE_EJECTS = "spent"` over FIVE chambers. The shotgun's `"all"` would
			-- leave none, and the Rigby has three.
			local opened = StateMachine.apply(fired, { kind = "Break" }, 10, ROW, ROW.CYCLE)
			expect(live(opened)).to.equal(4)
			local spent = 0
			for _, chamber in ipairs(opened.barrels) do
				if chamber == "Spent" then
					spent += 1
				end
			end
			expect(spent).to.equal(0) -- the fired case went: it is `Empty`, not `Spent`
		end)

		it("feeds ONE cartridge per Load, out of the pocket, which is what a gate is", function()
			local state = equipped(ROW)
			local pocket = state.reserve.Slug
			-- Fire every round, then open.
			-- EACH STEP IS APPLIED PAST THE LAST ONE'S OWN WINDOW, because the reducer refuses
			-- anything while `now < busyUntil` -- a loop that stepped faster than the gun would
			-- measure "busy" and prove nothing.
			local now = 0
			for _ = 1, 5 do
				now += 3
				state = StateMachine.apply(state, { kind = "Fire" }, now, ROW)
				state = StateMachine.apply(state, { kind = "Break" }, now + 0.5, ROW, ROW.CYCLE)
				state = StateMachine.apply(state, { kind = "Close" }, now + 1.5, ROW, ROW.CYCLE)
			end
			expect(live(state)).to.equal(0)
			state = StateMachine.apply(state, { kind = "Break" }, now + 10, ROW, ROW.RELOAD)
			local before = state.reserve.Slug
			state = StateMachine.apply(state, { kind = "Load" }, now + 11, ROW, ROW.RELOAD)
			-- ONE, not "every empty chamber": that is the whole difference from `Magazine`.
			expect(live(state)).to.equal(1)
			expect(state.reserve.Slug).to.equal(before - 1)
			expect(pocket).to.equal(C.START_RESERVE.Slug)
		end)
	end)

	describe("Weapon.cycleRefusal", function()
		it("answers walk, finish and abort, and is pure", function()
			expect(Weapon.cycleRefusal("Load", "no-reserve")).to.equal("walk")
			expect(Weapon.cycleRefusal("Load", "barrel-full")).to.equal("finish")
			expect(Weapon.cycleRefusal("Close", "is-closed")).to.equal("abort")
			expect(Weapon.cycleRefusal("Break", "is-open")).to.equal("abort")
			expect(Weapon.cycleRefusal("Load", "busy")).to.equal("abort")
			expect(Weapon.cycleRefusal(nil, nil)).to.equal("abort")
		end)

		it("a FULL tube answers barrel-full on a Load, which is the branch this gun added", function()
			-- The partial top-up: the tube is full, the player presses R anyway.
			local state = equipped(ROW)
			local opened = StateMachine.apply(state, { kind = "Break" }, 0, ROW, ROW.RELOAD)
			-- Nothing was fired, so `"spent"` ejects nothing and every chamber is still Live.
			expect(live(opened)).to.equal(5)
			local same, reason = StateMachine.apply(opened, { kind = "Load" }, 10, ROW, ROW.RELOAD)
			expect(reason).to.equal("barrel-full")
			expect(same).to.equal(opened)
			expect(Weapon.cycleRefusal("Load", reason)).to.equal("finish")
		end)

		it("NEITHER SHIPPED GUN CAN REACH IT, which is why nothing else changes", function()
			-- THE SHOTGUN: its `Break` ejects "all", so both chambers are Empty when its two
			-- `Load`s run and `barrel-full` is unreachable from its own reload.
			local shotgun = Weapons.ROWS.shotgun
			local sg = StateMachine.apply(equipped(shotgun), { kind = "Break" }, 0, shotgun, shotgun.CYCLE)
			for _, chamber in ipairs(sg.barrels) do
				expect(chamber).to.equal("Empty")
			end
			-- THE RIGBY: its reload issues no `Load` at all -- it swaps a box.
			for _, step in ipairs(Weapons.ROWS.rifle.RELOAD :: any) do
				expect(step.kind ~= "Load").to.equal(true)
			end
		end)
	end)

	describe("the drawn gun", function()
		it("is its own geometry and its own world shape, and neither is another gun's", function()
			expect(Weapons.geometry("lever")).to.equal(LeverGeometry)
			expect(Weapons.geometry("lever") ~= Weapons.geometry("rifle")).to.equal(true)
			expect(Shapes.for_("lever") ~= Shapes.for_("rifle")).to.equal(true)
			expect(Shapes.for_("lever") ~= Shapes.for_("shotgun")).to.equal(true)
		end)

		it("has iron sights and NO scope anywhere", function()
			expect(ROW.scope).to.equal(nil)
			expect(ROW.SIGHT).to.equal("bead")
			expect(LeverGeometry.sightKind(ROW)).to.equal("bead")
			for _, piece in ipairs(LeverGeometry.pieces(ROW)) do
				expect(piece.name ~= "Scope").to.equal(true)
			end
			for _, piece in ipairs(Shapes.for_("lever").pieces(ROW)) do
				expect(piece.name ~= "LeverScope").to.equal(true)
			end
			-- THE SIGHT IS ON THE BORE'S OWN CENTRE LINE, forward of the action: a sight that
			-- disagrees with the bore is a sight that lies.
			local sight = LeverGeometry.sight(ROW)
			expect(math.abs(sight.Position.X) < 1e-6).to.equal(true)
			expect(sight.Position.Z < 0).to.equal(true)
			expect(sight.Position.Z > ROW.MUZZLE_OFFSET.Z).to.equal(true)
		end)

		it("THE SIGHT PICTURE: both sights land on the screen's centre at aim", function()
			-- TASK 227, AND IT IS KAREN'S OWN DEFECT: *"Aiming with lever i terrible and broken"*.
			-- The shot goes down the camera's own axis, so an aimed open-sighted rifle is right only
			-- if the REAR NOTCH and the FRONT BLADE both project to the screen centre AND BOTH ARE
			-- IN FRONT OF THE EYE. This asserts exactly that, on the shipped data, through the
			-- production maths: `Mode.aimOffset` with this weapon's own `Geometry.sight` and its own
			-- `poses.json` numbers.
			local view = Viewmodel.view(Viewmodel.DATA, "lever")
			local aimConfig = { EYE_RELIEF_STUDS = view.EYE_RELIEF_STUDS, ADS_CHEEK_DEG = view.ADS_CHEEK_DEG }
			local at = LeverGeometry.layout(ROW)
			local rear = Vector3.new(0, at.sightRearY, at.sightRearZ)
			local front = Vector3.new(0, at.sightFrontY, at.sightFrontZ)
			-- The gun's Handle, in the CAMERA's frame, at full aim.
			local gun = Mode.aimOffset(LeverGeometry.sight(ROW), aimConfig)
			-- `-Z` is forward in the camera's frame, so `depth` positive is "in front of the eye".
			local function seen(point: Vector3): (number, number)
				local p = gun:PointToWorldSpace(point)
				local depth = -p.Z
				if depth <= 0 then
					return depth, math.huge -- behind the eye: it is not in the picture at all
				end
				return depth, math.deg(math.atan2(math.sqrt(p.X * p.X + p.Y * p.Y), depth))
			end
			local rearDepth, rearOff = seen(rear)
			local frontDepth, frontOff = seen(front)
			TestKit.note(
				string.format(
					"task227 lever sight picture: rear depth %.4f off %.4f deg; blade depth %.4f off %.4f deg",
					rearDepth,
					rearOff,
					frontDepth,
					frontOff
				)
			)
			-- BOTH IN FRONT OF THE EYE. Before this task the rear notch was 1.34 studs BEHIND it:
			-- the eye sat a stud back from the muzzle with the whole rifle behind the player's head.
			expect(rearDepth > 0.2).to.equal(true)
			expect(frontDepth > rearDepth).to.equal(true)
			-- ...AND BOTH ON THE CENTRE, inside a quarter of a degree, which at this gun's 50-degree
			-- aimed field of view is under 4 pixels on a 785-high viewport.
			expect(rearOff < 0.25).to.equal(true)
			expect(frontOff < 0.25).to.equal(true)
			-- THE NEGATIVE ARM, so the case cannot pass by accident. Identity rotation on the sight
			-- frame is what shipped, and it is the whole defect: the blade still lands on the centre
			-- (it IS the point the eye is laid on) and the notch misses it by the model's own slope.
			local flat = Mode.aimOffset(CFrame.new(front), aimConfig)
			local p = flat:PointToWorldSpace(rear)
			local flatOff = math.deg(math.atan2(math.sqrt(p.X * p.X + p.Y * p.Y), math.max(-p.Z, 1e-9)))
			TestKit.note(string.format("task227 lever, sight frame unrotated: notch %.4f deg off centre", flatOff))
			expect(flatOff > 0.9).to.equal(true)
			-- ...AND THE SHIPPED-BEFORE EYE RELIEF, which put the notch behind the eye entirely.
			local near = Mode.aimOffset(LeverGeometry.sight(ROW), { EYE_RELIEF_STUDS = 0.9, ADS_CHEEK_DEG = 0 })
			expect(-near:PointToWorldSpace(rear).Z < 0).to.equal(true)
		end)

		it("THE LOOP SWINGS DOWN AND FORWARD, and at rest it has not moved", function()
			-- THE SIGN CASE. This is the one task 188 bought: a lift written with the wrong sign
			-- buried the Rigby's bolt handle inside the gun for a whole cycle and no number saw it.
			local rest = LeverGeometry.leverThrow(ROW, 60, 0)
			expect((rest.Position - Vector3.zero).Magnitude < 1e-6).to.equal(true)
			local grip = LeverGeometry.leverGripOffset(ROW)
			local thrown = LeverGeometry.leverThrow(ROW, 60, 1) * grip
			TestKit.note(string.format("task224 throw: grip %s -> %s", tostring(grip), tostring(thrown)))
			expect(thrown.Y < grip.Y).to.equal(true) -- DOWN
			expect(thrown.Z < grip.Z).to.equal(true) -- and FORWARD (-Z is the muzzle)
			-- ...and a caller that asks for more than a full throw does not bury it in the stock.
			local over = LeverGeometry.leverThrow(ROW, 60, 1.4) * grip
			expect((over - thrown).Magnitude < 1e-6).to.equal(true)
		end)

		it("is a lever and not a hinge or a slide, with the one group that moves named", function()
			expect(LeverGeometry.CYCLE_KIND).to.equal("lever")
			expect(LeverGeometry.CYCLE_GROUP_NAME).to.equal("Lever")
			-- LEVER-ONLY: `poseHands` keeps the left glove on the fore-end exactly when this is not
			-- `"hinge"`, so the value itself is the assertion.
			expect(LeverGeometry.CYCLE_KIND ~= "hinge").to.equal(true)
			-- The generic envelope pair the viewmodel reads (design 7.2), derived from the lever box.
			-- 1e-5 AND NOT 1e-9: a `Vector3` component is a float32, so `at.lever.size.Z` is a
			-- rounded copy of the float64 `cycleLength` these two are derived from. The first cut
			-- used 1e-9 and failed on exactly that -- which is the right failure for the wrong
			-- reason, and the tolerance is the fix rather than rounding the data.
			local at = LeverGeometry.layout(ROW)
			expect(math.abs(at.cycleLength - at.lever.size.Z) < 1e-5).to.equal(true)
			expect(math.abs(at.cycleZ - at.lever.at.Z) < 1e-5).to.equal(true)
		end)

		it("puts no loose round in the hands, where the shotgun does", function()
			expect(LeverGeometry.HAND_FED_SHELLS).to.equal(false)
			expect(Viewmodel.DATA).to.be.ok()
		end)
	end)

	describe("the pose set", function()
		it("exists, carries a cycle and not a reload, and validate finds nothing wrong", function()
			expect(#Viewmodel.validate(Viewmodel.DATA)).to.equal(0)
			local set = Viewmodel.DATA.weapons.lever
			expect(set).to.be.ok()
			expect(type(set.cycle)).to.equal("table")
			expect(set.reload).to.equal(nil)
			-- NO MAGAZINE BLOCK: that absence is what keeps the drawn box and its hand off this gun.
			expect(set.cycle.magazine).to.equal(nil)
		end)

		it("draws the throw and the close faster than the server performs them", function()
			local set = Viewmodel.DATA.weapons.lever
			TestKit.note(
				string.format(
					"task224 drawn: open %.2f s vs server %.2f; close %.2f vs %.2f",
					set.cycle.openSeconds,
					ROW.CYCLE[1].wait,
					set.cycle.closeSeconds,
					ROW.CYCLE[2].wait
				)
			)
			expect(set.cycle.openSeconds < ROW.CYCLE[1].wait).to.equal(true)
			expect(set.cycle.closeSeconds < ROW.CYCLE[2].wait).to.equal(true)
		end)

		it("holds the WRIST with the right hand, inside the gun's own two bounds", function()
			-- THE CASE ROUND 1 WROTE SO IT COULD NOT FAIL, rewritten so it can. It asserted
			-- `off < 0.5` on a 4.0-stud gun whose own `gripRadius` is 0.0468 -- ten times the bound
			-- the design names -- never asserted `along` at all, and opened with
			-- `offGripAxis(gripOffset)`, which is the distance of a point ON the line FROM the line
			-- and is zero by construction. MEASURED on the poses it passed: the glove's grip point
			-- was **0.0602** off the wrist line, against 0.0468. That is the "no gloves on the gun"
			-- defect the request reported, and this case existed to catch it.
			--
			-- IT IS COMPUTED THE WAY THE RIGBY'S IS (`viewmodel_poses.spec`, "holds the wrist of the
			-- stock at the hip, aimed, and when the cycle starts"): through `Mode.handOffsetAt`,
			-- which is the one conversion site the viewmodel really draws with -- NOT by reading
			-- `pos` out of the file. The two differ by the glove's own `GRIP_STUDS`, and a pose
			-- checked at its origin is a pose nobody checked.
			for _, case in ipairs({
				{ name = "hip", state = stateAt(0, 0) },
				{ name = "aimed", state = stateAt(1, 0) },
				{ name = "cycle", state = stateAt(0, 1) },
			}) do
				local at = gripPointOf(Mode.handOffsetAt("right", case.state, leverConfig))
				local off = LeverGeometry.offGripAxis(ROW, at)
				local along = LeverGeometry.alongGripAxis(ROW, at)
				TestKit.note(
					string.format(
						"task224 lever right hand %s: %.4f off the wrist axis (bound %.4f), %+.4f along it (bound %.4f)",
						case.name,
						off,
						LeverGeometry.gripRadius(ROW),
						along,
						LeverGeometry.gripHalfLength(ROW)
					)
				)
				expect(off < LeverGeometry.gripRadius(ROW)).to.equal(true)
				expect(math.abs(along) < LeverGeometry.gripHalfLength(ROW)).to.equal(true)
			end
		end)

		it("pinches the LOOP, and keeps pinching it wherever the lever has got to", function()
			-- The design's third bound, which round 1 omitted entirely. Same shape as the Rigby's
			-- bolt-knob case, against this gun's own loop.
			local grip = leverConfig.BOLT_HAND.grip
			expect(grip).to.be.ok()
			local loop = LeverGeometry.leverGripOffset(ROW)
			local miss = (gripPointOf(grip) - loop).Magnitude
			local bound = LeverGeometry.leverGripRadius(ROW) + HandAssets.GRIP_RADIUS_STUDS
			TestKit.note(
				string.format("task224 lever cycling hand: %.4f studs from the loop (bound %.4f)", miss, bound)
			)
			expect(miss < bound).to.equal(true)
			-- ...AND IT CANNOT COME OFF IT. `poseHands` places this hand from the SAME transform the
			-- lever is drawn with, so the miss is invariant under any rigid motion of the loop --
			-- which is the whole reason the hand is placed that way rather than from a second clock.
			local carried = CFrame.new(0.31, -0.17, 0.44) * CFrame.Angles(0.3, -1.1, 0.7)
			local moved = (gripPointOf(carried * grip) - carried:PointToWorldSpace(loop)).Magnitude
			expect(math.abs(moved - miss) < 1e-5).to.equal(true)
		end)

		it("keeps the pose set's own shape: one grip, and a throw that is a throw", function()
			local set = Viewmodel.DATA.weapons.lever
			-- ONE HAND, ONE GRIP: a right hand that moved between the hip and the aim would read as
			-- the gun being re-gripped every time Karen aims (the Rigby's own rule).
			local hip = Mode.handOffsetAt("right", stateAt(0, 0), leverConfig)
			local aimed = Mode.handOffsetAt("right", stateAt(1, 0), leverConfig)
			expect((hip.Position - aimed.Position).Magnitude < 1e-6).to.equal(true)
			expect(set.cycle.hand.reachShare > 0 and set.cycle.hand.reachShare < 1).to.equal(true)
			expect(set.cycle.openDeg > 0).to.equal(true)
		end)
	end)

	describe("the shop sells it", function()
		it("is a weapon row between the slug and the scoped rifle, and it grants THIS gun", function()
			local row = Shop.ROWS[Shop.ITEM.LEVER]
			expect(row).to.be.ok()
			expect(row.category).to.equal(Shop.CATEGORY.WEAPON)
			expect(row.sale).to.equal(true)
			expect(row.grants.weapon).to.equal("lever")
			expect(row.price).to.equal(650)
			expect(row.hunts).to.equal(12)
			-- THE LADDER STILL CLIMBS, which is Karen's own shape for the shop.
			expect(row.price > Shop.ROWS[Shop.ITEM.SLUG].price).to.equal(true)
			expect(row.price < Shop.ROWS[Shop.ITEM.RIFLE].price).to.equal(true)
			expect(row.hunts < Shop.ROWS[Shop.ITEM.RIFLE].hunts).to.equal(true)
			-- NO ROBUX PRODUCT IN THIS BUILD (`rowsOk`'s I12).
			expect(row.robuxProductId).to.equal(nil)
		end)

		it("is clean against rowsOk, with the real weapon table passed in", function()
			-- THE INVARIANT THAT MATTERS: the shop cannot sell a weapon no build ships.
			-- THE SAME THREE ARGUMENTS `deer.spec` PASSES. `rowsOk` checks the ammo a row grants
			-- against the kinds it is given and the licence a row grants against the rows it is
			-- given, so calling it with the weapon table alone reports four rows as granting things
			-- no build ships -- a self-inflicted failure, not a finding.
			local Licences = require(ReplicatedStorage:WaitForChild("Licences"))
			local problems = Shop.rowsOk(Weapons.ROWS, Weapons.ROWS.shotgun.AMMO_KINDS, Licences.ROWS)
			if #problems > 0 then
				TestKit.note("task224 rowsOk: " .. table.concat(problems, " | "))
			end
			expect(#problems).to.equal(0)
		end)

		it("is NEVER handed out free, and the free path is what it was before this weapon", function()
			-- THE DIRECTOR'S RULE, 2026-10-20: *"a player who has NOT bought the lever rifle must
			-- never hold it -- the free-path default stays exactly as before 224"*. MEASURED on the
			-- DEV gate before the fix: the character held the LEVER and the shotgun sat in the
			-- backpack.
			expect(ROW.OWNED_ONLY).to.equal(true)
			-- nil IS UNRESTRICTED, and it is the one every un-wired world and every weapon spec
			-- gets. The lever is not in it.
			local free = Weapons.loadoutFor(true, nil)
			expect(#free).to.equal(2)
			expect(free[1]).to.equal("shotgun")
			expect(free[2]).to.equal("rifle")
			for _, id in ipairs(free) do
				expect(id ~= "lever").to.equal(true)
			end
			-- THE OTHER DIRECTION, or this case only proves the gun is missing: a man who HAS bought
			-- it carries it, so `OWNED_ONLY` gates the free path and nothing else.
			local bought = Weapons.loadoutFor(true, { [Shop.ITEM.LEVER] = true })
			expect(#bought).to.equal(2)
			expect(bought[2]).to.equal("lever")
			-- ...AND THE TWO SHIPPED GUNS ARE UNTOUCHED BY THE FIELD, which is what makes it safe:
			-- neither declares it, so neither's free path moved.
			expect(Weapons.ROWS.shotgun.OWNED_ONLY).to.equal(nil)
			expect(Weapons.ROWS.rifle.OWNED_ONLY).to.equal(nil)
			-- THE FLAG-OFF SPAWN IS STILL THE PRIMARY ALONE.
			local off = Weapons.loadoutFor(false, nil)
			expect(#off).to.equal(1)
			expect(off[1]).to.equal("shotgun")
		end)

		it("puts the gun in the loadout of the man who bought it, and nobody else's", function()
			local owned = { [Shop.ITEM.LEVER] = true }
			expect(Shop.ownsWeapon(owned, "lever")).to.equal(true)
			expect(Shop.ownsWeapon({ [Shop.ITEM.RIFLE] = true }, "lever")).to.equal(false)
			local loadout = Shop.loadoutFrom(Weapons.ORDER, Weapons.PRIMARY, owned)
			expect(#loadout).to.equal(2)
			expect(loadout[1]).to.equal("shotgun")
			expect(loadout[2]).to.equal("lever")
		end)

		it("issues its own cartridge with the gun, because selling a rifle and no rounds is theft", function()
			expect(Shop.BASE_AMMO.lever).to.be.ok()
			expect(Shop.BASE_AMMO.lever.Slug).to.equal(true)
			local start = Shop.startFor(ROW, { [Shop.ITEM.LEVER] = true })
			expect(start).to.be.ok()
			expect(start.ammo).to.equal("Slug")
			expect((start.reserve.Slug or 0) > 0).to.equal(true)
			-- ...AND A MAN WHO OWNS NOTHING STILL GETS ROUNDS FOR A GUN HE SOMEHOW HAS: the
			-- unrestricted default, which is what keeps every weapon spec and every un-wired world
			-- working (`Shop.BASE_AMMO`'s own rule).
			local bare = Shop.startFor(ROW, {})
			expect((bare.reserve.Slug or 0) > 0).to.equal(true)
		end)
	end)
end
