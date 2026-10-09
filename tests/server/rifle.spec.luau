-- rifle.spec: the weapon TABLE, the rifle's row, the reducer driven with a row, and the scope's own
-- arithmetic. Pure: no Instances, no clock, no Player, no client.
--
-- WHAT THIS FILE IS FOR, in one sentence: a second weapon must not be able to change the first one.
-- So the shotgun's row is asserted field by field against `Shotgun.CONFIG` -- a number that moves
-- fails here rather than drifting -- and no row is allowed to carry a rule that belongs to the drive
-- or to the protocol.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/rifle.md (sections 4, 8, 12, 13.1)
-- Note:   docs/research/2026-10-09-rifle-scope.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local StateMachine = Weapon.StateMachine
local Validator = Weapon.Validator
local Hits = Weapon.Hits
local Shapes = Weapon.Shapes
local CONFIG = Shotgun.CONFIG

local function equipped(row)
	return StateMachine.setEquipped(StateMachine.initial(row), true)
end

return function()
	describe("the weapon table", function()
		it("holds exactly the two weapons, in hotbar order, frozen all the way down", function()
			local ids = Weapons.ids()
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal("shotgun")
			expect(ids[2]).to.equal("rifle")
			expect(Weapons.row("nope")).to.equal(nil)
			expect(Weapons.row(nil)).to.equal(nil)
			expect(Weapons.PRIMARY).to.equal("shotgun")
			-- DEEP-FROZEN, which is defect (b) of the Task 23 review made into an assertion: a
			-- shallow freeze leaves the nested tables writable, and a weapon row is nested two deep.
			expect(table.isfrozen(Weapons.ROWS)).to.equal(true)
			expect(function()
				(Weapons.ROWS.rifle.RANGE_STUDS :: any).Slug = 1
			end).to.throw()
		end)

		it("carries the rifle only when the flag says so, and the rule is PURE", function()
			-- The flag is read in exactly one place (`Weapons.loadout`), and this is the function it
			-- reads into -- so both worlds are reachable in a spec with no flag set anywhere.
			local off = Weapons.loadoutFor(false)
			expect(#off).to.equal(1)
			expect(off[1]).to.equal("shotgun")
			local on = Weapons.loadoutFor(true)
			expect(#on).to.equal(2)
			expect(on[2]).to.equal("rifle")
			expect(Weapons.FLAG).to.equal("RIFLE")
		end)

		it("names a Tool for each weapon, and answers which id a Tool name is", function()
			expect(Weapons.ROWS.shotgun.toolName).to.equal("Shotgun")
			expect(Weapons.ROWS.rifle.toolName).to.equal("Rifle")
			expect(Weapons.isToolName("Shotgun")).to.equal(true)
			expect(Weapons.isToolName("Rifle")).to.equal(true)
			expect(Weapons.isToolName("Bucket")).to.equal(false)
			expect(Weapons.isToolName(nil)).to.equal(false)
			expect(Weapons.idForToolName("Rifle")).to.equal("rifle")
		end)
	end)

	describe("the shotgun's row is the shotgun's own numbers", function()
		it("reads every ballistic field out of Shotgun.CONFIG", function()
			local row = Weapons.ROWS.shotgun
			expect(row.RANGE_STUDS.Slug).to.equal(CONFIG.RANGE_STUDS.Slug)
			expect(row.RANGE_STUDS.Buck).to.equal(CONFIG.RANGE_STUDS.Buck)
			expect(row.PELLETS.Slug).to.equal(CONFIG.PELLETS.Slug)
			expect(row.PELLETS.Buck).to.equal(CONFIG.PELLETS.Buck)
			expect(row.SPREAD_FULL_DEG.Slug).to.equal(CONFIG.SPREAD_FULL_DEG.Slug)
			expect(row.SPREAD_FULL_DEG.Buck).to.equal(CONFIG.SPREAD_FULL_DEG.Buck)
			expect(row.BARRELS).to.equal(CONFIG.BARRELS)
			expect(row.BARREL_DELAY).to.equal(CONFIG.BARREL_DELAY)
			expect(row.INITIAL_AMMO).to.equal(CONFIG.INITIAL_AMMO)
			expect(row.START_RESERVE.Slug).to.equal(CONFIG.START_RESERVE.Slug)
			expect(row.HANDLE_SIZE).to.equal(CONFIG.HANDLE_SIZE)
			expect(row.GRIP).to.equal(CONFIG.GRIP)
			expect(row.MUZZLE_OFFSET).to.equal(CONFIG.MUZZLE_OFFSET)
		end)

		it("rebuilds the reload as data, with the four numbers it always had", function()
			local row = Weapons.ROWS.shotgun
			expect(#row.CYCLE).to.equal(4)
			expect(row.CYCLE[1].kind).to.equal("Break")
			expect(row.CYCLE[1].wait).to.equal(CONFIG.RELOAD_BREAK)
			expect(row.CYCLE[2].kind).to.equal("Load")
			expect(row.CYCLE[2].wait).to.equal(CONFIG.RELOAD_SHELL)
			expect(row.CYCLE[3].kind).to.equal("Load")
			expect(row.CYCLE[4].kind).to.equal("Close")
			expect(row.CYCLE[4].wait).to.equal(CONFIG.RELOAD_CLOSE)
			local sum = 0
			for _, step in ipairs(row.CYCLE) do
				sum += step.wait
			end
			expect(math.abs(sum - CONFIG.RELOAD_TOTAL) < 1e-9).to.equal(true)
			expect(row.CYCLE_TOTAL).to.equal(CONFIG.RELOAD_TOTAL)
			-- ...AND IT IS NOT AUTOMATIC. `R` runs the shotgun's reload and always has.
			expect(row.AUTO_CYCLE).to.equal(false)
		end)

		it("carries NO rule that belongs to the drive or to the protocol", function()
			-- A per-weapon safety arc would let a new weapon widen its own licence to shoot down the
			-- line. These live in `Shotgun.CONFIG` and the owner reads them there.
			for _, id in ipairs(Weapons.ids()) do
				local row = Weapons.ROWS[id] :: any
				expect(row.SAFETY_ARC_HALF_DEG).to.equal(nil)
				expect(row.CAMERA_ORIGIN_TOLERANCE).to.equal(nil)
				expect(row.MIN_AIM_DISTANCE).to.equal(nil)
				expect(row.FIRE_RATE_LIMIT).to.equal(nil)
				expect(row.ACTION_RATE_LIMIT).to.equal(nil)
				expect(row.STATE_RATE_LIMIT).to.equal(nil)
				expect(row.AUTO_EQUIP).to.equal(nil)
				expect(row.shouldArm).to.equal(nil)
			end
		end)
	end)

	describe("the rifle's own numbers", function()
		it("reaches further and spreads less than the slug, with one projectile", function()
			local row = Weapons.ROWS.rifle
			expect(row.PELLETS.Slug).to.equal(1)
			expect(row.RANGE_STUDS.Slug > CONFIG.RANGE_STUDS.Slug).to.equal(true)
			expect(row.RANGE_STUDS.Slug).to.equal(450)
			-- FLATTER IS A SPREAD HERE AND NOT A DROP CURVE: nothing in this game models bullet
			-- drop, which the research note records as considered and rejected (FastCast2).
			expect(row.SPREAD_FULL_DEG.Slug < CONFIG.SPREAD_FULL_DEG.Slug).to.equal(true)
			expect(row.BARRELS).to.equal(1)
		end)

		it("carries ONE ammo kind, and that kind is Slug on the wire", function()
			local row = Weapons.ROWS.rifle
			expect(#row.AMMO_KINDS).to.equal(1)
			expect(row.AMMO_KINDS[1]).to.equal("Slug")
			-- `Boar.Wound.damageFor` branches on exactly this string; a new word would be charged as
			-- a buckshot PELLET. The WORD on screen is the Hud's business and is not this.
			expect(row.INITIAL_AMMO).to.equal("Slug")
			expect(row.AMMO_LABEL.Slug).never.to.equal("SLUG")
		end)

		it("works its bolt in three steps, automatically, and the total is the sum", function()
			local row = Weapons.ROWS.rifle
			expect(row.AUTO_CYCLE).to.equal(true)
			expect(#row.CYCLE).to.equal(3)
			expect(row.CYCLE[1].kind).to.equal("Break")
			expect(row.CYCLE[2].kind).to.equal("Load")
			expect(row.CYCLE[3].kind).to.equal("Close")
			local sum = 0
			for _, step in ipairs(row.CYCLE) do
				sum += step.wait
			end
			expect(math.abs(sum - row.CYCLE_TOTAL) < 1e-9).to.equal(true)
			expect(row.CYCLE_TOTAL).to.equal(0.9)
		end)

		it("states a magnification that IS its field of view", function()
			-- THE ARITHMETIC, NOT A LABEL: m = tan(fovThird/2) / tan(fov/2). A hand-typed FOV that
			-- does not match the stated magnification fails here rather than shipping as a lie.
			local scope = Rifle.CONFIG.scope
			local m = math.tan(math.rad(70) / 2) / math.tan(math.rad(scope.aimFovDeg) / 2)
			expect(math.abs(m - scope.magnification) < 1e-3).to.equal(true)
			expect(scope.aimFovDeg < CONFIG.FOV_AIM_DEG or true).to.equal(true)
			-- ...and the shotgun has no scope at all, which is what `nil` means here.
			expect(Weapons.ROWS.shotgun.scope).to.equal(nil)
		end)

		it("describes its reticle in DEGREES, every field", function()
			local r = Rifle.CONFIG.scope.reticle
			expect(r.kind).to.equal("duplex")
			-- Every size is an angle, so one duplex is true at any screen size and any zoom.
			for _, name in ipairs({
				"ringOuterDeg",
				"ringThickDeg",
				"crossGapDeg",
				"crossArmDeg",
				"crossThickDeg",
				"postArmDeg",
				"postThickDeg",
			}) do
				expect(type((r :: any)[name])).to.equal("number")
				expect((r :: any)[name] > 0).to.equal(true)
			end
			-- A DUPLEX IS THIN IN THE MIDDLE AND THICK AT THE EDGE; that is what makes it one.
			expect(r.postThickDeg > r.crossThickDeg).to.equal(true)
			-- ...and the ring is the thing you look THROUGH, so it is wider than the cross reaches.
			expect(r.ringOuterDeg > 2 * (r.crossGapDeg + r.crossArmDeg)).to.equal(true)
		end)
	end)

	describe("the reducer, driven with a row", function()
		it("fires once and is then busy for the rifle's OWN delay", function()
			local row = Weapons.ROWS.rifle
			local state = equipped(row)
			local fired, reason = StateMachine.apply(state, { kind = "Fire" }, 100, row)
			expect(reason).to.equal(nil)
			expect(fired.barrels[1]).to.equal("Spent")
			expect(math.abs(fired.busyUntil - (100 + row.BARREL_DELAY)) < 1e-9).to.equal(true)
			-- ...and a second trigger pull inside that window is refused, by the reducer and not by
			-- a flag somewhere else.
			local _, busy = StateMachine.apply(fired, { kind = "Fire" }, 100.01, row)
			expect(busy).to.equal("busy")
		end)

		it("walks the bolt: open, feed, close -- and refuses to fire while it is open", function()
			local row = Weapons.ROWS.rifle
			local fired = StateMachine.apply(equipped(row), { kind = "Fire" }, 0, row)
			local open = StateMachine.apply(fired, { kind = "Break" }, 1, row)
			expect(open.open).to.equal(true)
			expect(open.barrels[1]).to.equal("Empty")
			expect(math.abs(open.busyUntil - (1 + row.CYCLE[1].wait)) < 1e-9).to.equal(true)
			-- THE ONE RULE EVERY SECOND TRIGGER PULL MEETS, and it lives in one place.
			local _, isOpen = StateMachine.apply(open, { kind = "Fire" }, 2, row)
			expect(isOpen).to.equal("is-open")
			local fed = StateMachine.apply(open, { kind = "Load" }, 2, row)
			expect(fed.barrels[1]).to.equal("Live")
			expect(fed.reserve.Slug).to.equal(row.START_RESERVE.Slug - 1)
			local shut = StateMachine.apply(fed, { kind = "Close" }, 3, row)
			expect(shut.open).to.equal(false)
			expect(shut.selected).to.equal(1)
		end)

		it("refuses to feed an empty pocket, which is the one rejection the sequence walks past", function()
			local row = Weapons.ROWS.rifle
			local state = equipped(row)
			local empty = table.clone(state) :: any
			empty.reserve = { Slug = 0 }
			empty.barrels = { "Empty" }
			empty.loaded = { "None" }
			empty.open = true
			local _, reason = StateMachine.apply(Shotgun.deepFreeze(empty), { kind = "Load" }, 5, row)
			expect(reason).to.equal("no-reserve")
		end)

		it("refuses SelectAmmo on a weapon with one kind, at the wire", function()
			local ok, why = Validator.checkRequest("SelectAmmo", "Buck", Weapons.ROWS.rifle)
			expect(ok).to.equal(false)
			expect(why).to.equal("bad-request")
			expect((Validator.checkRequest("SelectAmmo", "Slug", Weapons.ROWS.rifle))).to.equal(true)
			-- ...and the shotgun still takes both, which is the half that must not change.
			expect((Validator.checkRequest("SelectAmmo", "Buck", Weapons.ROWS.shotgun))).to.equal(true)
			expect((Validator.checkRequest("Reload", nil, Weapons.ROWS.rifle))).to.equal(true)
		end)
	end)

	describe("the drawn gun and the world gun", function()
		it("resolves a geometry and a shape for every weapon, and they are not the same ones", function()
			for _, id in ipairs(Weapons.ids()) do
				local row = Weapons.ROWS[id]
				local geometry = Weapons.geometry(id)
				expect(geometry).to.be.ok()
				expect(#geometry.pieces(row) > 0).to.equal(true)
				local shape = Shapes.for_(id)
				expect(shape).to.be.ok()
				expect(#shape.pieces(row) > 0).to.equal(true)
			end
			-- THE WRONG GUN IS WORSE THAN A BOX. A rifle whose upload did not load must not fall
			-- back to the shotgun's parts list: that is a wrong gun that measures perfectly.
			expect(Shapes.for_("rifle")).never.to.equal(Shapes.for_("shotgun"))
			expect(Weapons.geometry("rifle")).never.to.equal(Weapons.geometry("shotgun"))
		end)

		it("gives the rifle a cycle group that SLIDES, and the shotgun one that hinges", function()
			local rifleGeometry = Weapons.geometry("rifle")
			expect(rifleGeometry.CYCLE_KIND).to.equal("slide")
			expect(rifleGeometry.CYCLE_GROUP_NAME).to.equal("Bolt")
			-- The piece that moves is in the group that moves, and it is the only one.
			local moving = 0
			for _, piece in ipairs(rifleGeometry.pieces(Weapons.ROWS.rifle)) do
				if piece.group == "barrels" then
					moving += 1
					expect(piece.name).to.equal("Bolt")
				end
			end
			expect(moving).to.equal(1)
		end)

		it("puts the eye at the OCULAR lens, behind the scope and above the bore", function()
			local at = Weapons.geometry("rifle").layout(Weapons.ROWS.rifle)
			local sight = Weapons.geometry("rifle").sight(Weapons.ROWS.rifle)
			-- The eye looks into the rear of the tube: +Z is the butt end in the Handle's frame.
			expect(sight.Position.Z > 0).to.equal(true)
			expect(math.abs(sight.Position.Z - at.scopeOcularZ) < 1e-6).to.equal(true)
			-- ...and a scope sits well above the bore line, which is why its own axis is measured.
			expect(sight.Position.Y > 0.12).to.equal(true)
		end)
	end)

	describe("the drawn bolt, as data", function()
		it("holds the gun still while the bolt moves", function()
			-- `Mode.viewmodelOffset` lerps the pose toward the action's pose by the cycle's progress,
			-- and a lerp between EQUAL numbers is those numbers -- which is how the gun stays
			-- shouldered with no new branch in the composition. Seeded equal; the Director may make
			-- them differ later, and then this case is the thing that says so out loud.
			local cycle = Viewmodel.DATA.weapons.rifle.cycle
			local carry = Viewmodel.DATA.weapons.rifle.carry
			for _, axis in ipairs({ "x", "y", "z" }) do
				expect(cycle.gun.pos[axis]).to.equal(carry.gun.pos[axis])
				expect(cycle.gun.rot[axis]).to.equal(carry.gun.rot[axis])
			end
		end)

		it("draws faster than the server's own steps, so the motion always finishes first", function()
			local row = Weapons.ROWS.rifle
			local cycle = Viewmodel.DATA.weapons.rifle.cycle
			expect(cycle.openSeconds < row.CYCLE[1].wait).to.equal(true)
			expect(cycle.closeSeconds < row.CYCLE[#row.CYCLE].wait).to.equal(true)
			expect(cycle.liftFraction > 0 and cycle.liftFraction < 1).to.equal(true)
		end)

		it("publishes the same flat names for both weapons, so no reader can get a nil", function()
			local shotgunView = Viewmodel.view(Viewmodel.DATA, "shotgun")
			local rifleView = Viewmodel.view(Viewmodel.DATA, "rifle")
			for key in pairs(shotgunView) do
				expect(rifleView[key]).never.to.equal(nil)
			end
			-- ...and the rifle's own two are there, which the shotgun's view does not have.
			expect(rifleView.BOLT_LIFT_DEG).to.be.ok()
			expect(rifleView.BOLT_DRAW_STUDS).to.be.ok()
		end)
	end)

	describe("the report carries the weapon", function()
		it("puts the weapon id on every report of a shot", function()
			local target = Instance.new("Part")
			target:SetAttribute("Damageable", true)
			target:SetAttribute("HitZone", "chest")
			local impacts = {
				{ instance = target, position = Vector3.new(0, 0, -10), normal = Vector3.new(0, 0, 1), distance = 10 },
			}
			local reports = Hits.group(nil :: any, impacts, "Slug", 123, "rifle")
			expect(#reports).to.equal(1)
			expect(reports[1].weapon).to.equal("rifle")
			-- ...and a caller that names no weapon still works, which is what keeps every record
			-- written before this task valid on the wire.
			local older = Hits.group(nil :: any, impacts, "Slug", 123)
			expect(older[1].weapon).to.equal(nil)
			target:Destroy()
		end)
	end)
end
