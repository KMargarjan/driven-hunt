-- weapon_rules.spec: THE THREE RULES THAT REFUSE A SHOT (task 171), plus the drive's shells.
--
-- Karen, 2026-10-11: *"No penalty now we need simplify scope, thye just can't shoot them"*;
-- 2026-10-12, about a hunter outside his stand circle when the 15 s pick window ends: he *"CAN'T
-- SHOOT until he steps in"*, with no punishment; 2026-10-10, about a red deer with no licence:
-- *"they can aim but no shooting happening"*; 2026-10-10, about the gun: *"limited ammon per round"*.
--
-- MOST OF THIS IS PURE and needs no world: `Weapon.Rules` and `Licences` take every fact as a
-- parameter. Three cases are not, and each says so in its own words: the handler case drives
-- `Weapon.onFireRequest` -- the very function `Weapon.start` connects to the remote -- for a tracked
-- player with a loaded gun, and the two `Match` cases read the live drive's own assignment.
--
-- WHY THE HANDLER CASE IS HERE AT ALL, when the predicates are tested one by one above it: a gate
-- that is never asked is the defect this task could ship. `weapon_shot.spec`'s whitelist case exists
-- for the same reason ("the case above proves the whitelist says no; this proves the HANDLER asks
-- it"), and this one adds the half that is specific to a REFUSAL: that nothing was spent.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-10-13-the-rules.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Licences = require(ReplicatedStorage:WaitForChild("Licences"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local Rules = Weapon.Rules
local StateMachine = Weapon.StateMachine
local ROW = Weapons.ROWS.shotgun

-- A spec-owned species table, so the licence rule is driven by data this file owns rather than by
-- the game's -- and so a row the game has not got (a stub) proves the gate on a species that does
-- not exist. Karen's deer is the real row; `sparrow` is here to prove an unknown one is not an
-- offence.
local SPECIES = {
	boar = { species = "boar", label = "WILD BOAR", licence = false },
	reddeer = { species = "reddeer", label = "RED DEER", licence = true },
}

return function()
	describe("the licence table", function()
		it("has a free boar and a red deer that needs one, frozen", function()
			expect(Licences.ROWS.boar.licence).to.equal(false)
			expect(Licences.ROWS.reddeer.licence).to.equal(true)
			expect(Licences.ROWS.reddeer.label).to.equal("RED DEER")
			-- The rules of the game are not writable at run time (the discipline every frozen table
			-- in this repo follows).
			expect(table.isfrozen(Licences.ROWS)).to.equal(true)
			expect(function()
				(Licences.ROWS.boar :: any).licence = true
			end).to.throw()
			-- The attribute name is ONE string, and the boar publishes it (`Boar.Body.create`) while
			-- `Match.classifyTarget` reads it. A literal in two files is the drift this spec exists
			-- to stop.
			expect(Licences.SPECIES_ATTRIBUTE).to.equal("Species")
			expect(#Licences.species() >= 2).to.equal(true)
		end)

		it("allows what needs no licence, and only a holder for what does", function()
			expect(Licences.required("boar", SPECIES)).to.equal(false)
			expect(Licences.required("reddeer", SPECIES)).to.equal(true)
			-- AN UNKNOWN SPECIES NEEDS NO LICENCE, and that default is written down in the module:
			-- the alternative is a target somebody forgot to put in the table being unshootable,
			-- silently.
			expect(Licences.required("sparrow", SPECIES)).to.equal(false)
			expect(Licences.required(nil, SPECIES)).to.equal(false)

			expect(Licences.allows("boar", nil, SPECIES)).to.equal(true)
			expect(Licences.allows("reddeer", nil, SPECIES)).to.equal(false)
			expect(Licences.allows("reddeer", {}, SPECIES)).to.equal(false)
			expect(Licences.allows("reddeer", { boar = true }, SPECIES)).to.equal(false)
			expect(Licences.allows("reddeer", { reddeer = true }, SPECIES)).to.equal(true)
		end)
	end)

	describe("the three fire rules", function()
		it("refuses a shot whose aim ray would hit a beater, and nothing else", function()
			expect(Rules.beaterInLine({ beater = true })).to.equal(true)
			-- A BEATER WITH A SPECIES ATTRIBUTE IS STILL A BEATER: the man wins over the animal,
			-- which is the order `Match.classifyTarget` answers in and the order the owner asks in.
			expect(Rules.beaterInLine({ beater = true, species = "boar" })).to.equal(true)
			expect(Rules.beaterInLine({ beater = false, species = "boar" })).to.equal(false)
			expect(Rules.beaterInLine({ species = "boar" })).to.equal(false)
			expect(Rules.beaterInLine(nil)).to.equal(false) -- a miss hits nobody
		end)

		it("refuses a hunter outside his circle and allows him on its edge", function()
			local area = { centre = Vector3.new(100, 50, -200), radius = 12 }
			-- FLAT: the Y is ignored, because a hunter on his post is three studs above the ground he
			-- picked it from and that is not leaving the stand (`ForestTest.withinStand`'s rule).
			expect(Rules.outsideStand(Vector3.new(100, 500, -200), area)).to.equal(false)
			expect(Rules.outsideStand(Vector3.new(111, 50, -200), area)).to.equal(false)
			-- ON the circle is IN it, the same comparison `ForestTest.withinStand` makes (`<=`), so
			-- the soft wall of task 166 -- which parks a man at exactly `radius` -- cannot park him
			-- somewhere he may not shoot from.
			expect(Rules.outsideStand(Vector3.new(112, 50, -200), area)).to.equal(false)
			expect(Rules.outsideStand(Vector3.new(112.01, 50, -200), area)).to.equal(true)
			expect(Rules.outsideStand(Vector3.new(100, 50, -300), area)).to.equal(true)
			-- Around the whole circle, not just along +X: a bearing the arithmetic got wrong would
			-- be a direction a hunter may walk out in.
			for step = 0, 35 do
				local bearing = math.rad(step * 10)
				local out = area.centre + Vector3.new(math.cos(bearing) * 13, 0, math.sin(bearing) * 13)
				local inside = area.centre + Vector3.new(math.cos(bearing) * 11, 0, math.sin(bearing) * 11)
				expect(Rules.outsideStand(out, area)).to.equal(true)
				expect(Rules.outsideStand(inside, area)).to.equal(false)
			end
			-- NO AREA MEANS NO RULE: a beater, a player between drives, a hunter whose pick has not
			-- locked. A permissive default is deliberate and the module says why -- a gate that
			-- refused everything on a missing provider would look exactly like the rule working.
			expect(Rules.outsideStand(Vector3.new(0, 0, 0), nil)).to.equal(false)
			expect(Rules.outsideStand(nil, area)).to.equal(false)
			expect(Rules.outsideStand(Vector3.new(999, 0, 999), { centre = area.centre, radius = 0 })).to.equal(false)
		end)

		it("refuses a species the player has no licence for, and lets him aim at anything", function()
			expect(Rules.unlicensed({ species = "reddeer" }, nil, SPECIES)).to.equal(true)
			expect(Rules.unlicensed({ species = "reddeer" }, { reddeer = true }, SPECIES)).to.equal(false)
			expect(Rules.unlicensed({ species = "boar" }, nil, SPECIES)).to.equal(false)
			-- A MISS IS NOT AN OFFENCE, which is also what makes "they can aim but no shooting
			-- happening" true: pointing the gun at a deer refuses the SHOT and nothing else.
			expect(Rules.unlicensed(nil, nil, SPECIES)).to.equal(false)
			expect(Rules.unlicensed({ beater = false }, nil, SPECIES)).to.equal(false)
			-- The game's own table, not the spec's: a boar is free today and the deer row is ready.
			expect(Rules.unlicensed({ species = "boar" }, nil)).to.equal(false)
			expect(Rules.unlicensed({ species = "reddeer" }, nil)).to.equal(true)
		end)

		-- THE ORDER, ASSERTED (task 171, after the Director's two-player run at `8b2bb40`: a probe aimed
		-- straight at a beater came back `off-stand`, because the shooter had walked 525 studs from
		-- his post to reach him. Both answers were true and nothing said which should win).
		it("asks the three rules in one declared order, and names the winner", function()
			expect(Rules.ORDER[1]).to.equal(Rules.REASON.OFF_STAND)
			expect(Rules.ORDER[2]).to.equal(Rules.REASON.BEATER)
			expect(Rules.ORDER[3]).to.equal(Rules.REASON.LICENCE)
			expect(#Rules.ORDER).to.equal(3)
			expect(table.isfrozen(Rules.ORDER)).to.equal(true)

			local area = { centre = Vector3.new(0, 0, 0), radius = 12 }
			local inside, outside = Vector3.new(3, 0, 0), Vector3.new(40, 0, 0)
			local beater = { beater = true, species = "reddeer" }

			-- ALL THREE TRUE AT ONCE: he is off his stand, aiming at a beater, who is somehow also a
			-- licensed species. The first rule in the order wins, and the reason is the one thing he
			-- can act on -- get back on your stand.
			expect(Rules.refuse({ position = outside, stand = area, target = beater, licences = nil, rows = SPECIES })).to.equal(
				Rules.REASON.OFF_STAND
			)
			-- BACK ON HIS STAND, still aiming at the man: the aim is the next question.
			expect(Rules.refuse({ position = inside, stand = area, target = beater, licences = nil, rows = SPECIES })).to.equal(
				Rules.REASON.BEATER
			)
			-- A MAN IS NOT QUARRY, which is why the beater question comes before the licence one: the
			-- same target with `beater` cleared is an animal, and now the licence answers.
			expect(Rules.refuse({
				position = inside,
				stand = area,
				target = { species = "reddeer" },
				licences = nil,
				rows = SPECIES,
			})).to.equal(Rules.REASON.LICENCE)
			-- ...and with the licence in his pocket, nothing refuses it at all.
			expect(Rules.refuse({
				position = inside,
				stand = area,
				target = { species = "reddeer" },
				licences = { reddeer = true },
				rows = SPECIES,
			})).to.equal(nil)
			-- A LEGAL SHOT AT A BOAR FROM YOUR OWN STAND IS THE WHOLE GAME, and it must survive every
			-- gate -- including with no stand and no target at all, which is what a world that wires
			-- no provider answers (and every weapon spec).
			expect(Rules.refuse({ position = inside, stand = area, target = { species = "boar" } })).to.equal(nil)
			expect(Rules.refuse({})).to.equal(nil)
		end)

		it("has one short line for every reason and no reason without one", function()
			local seen = 0
			for _, reason in pairs(Rules.REASON) do
				local line = Rules.noticeFor(reason)
				expect(type(line)).to.equal("string")
				expect(#(line :: string) > 0).to.equal(true)
				-- SHORT, because the readout is one row at the bottom of the screen and it already
				-- carries the glyphs, the ammo word and the pocket.
				expect(#(line :: string) <= 20).to.equal(true)
				seen += 1
			end
			expect(seen).to.equal(3)
			expect(Rules.noticeFor("not-a-reason")).to.equal(nil)
			expect(Rules.noticeFor(nil)).to.equal(nil)
			-- The reasons are wire values the client and the Hud key on, so they are pinned here.
			expect(Rules.REASON.BEATER).to.equal("beater-in-line")
			expect(Rules.REASON.OFF_STAND).to.equal("off-stand")
			expect(Rules.REASON.LICENCE).to.equal("no-licence")
		end)
	end)

	describe("the drive's shells", function()
		it("gives 12 of each kind and puts them back on a Refill, without touching the gun", function()
			expect(Shotgun.CONFIG.DRIVE_SHELLS).to.equal(12)
			local fresh = StateMachine.initial(ROW)
			expect(fresh.reserve.Slug).to.equal(12)
			expect(fresh.reserve.Buck).to.equal(12)

			-- A gun that has been shooting: a spent barrel and an empty pocket.
			local spent = table.clone(fresh) :: any
			spent.reserve = { Slug = 0, Buck = 3 }
			spent.barrels = { "Spent", "Live" }
			spent.loaded = { "None", "Slug" }
			spent.equipped = true
			spent.busyUntil = 1e9 -- mid-reload: a refill is the DRIVE's, not his hands'
			local refilled, reason = StateMachine.apply(Shotgun.deepFreeze(spent), { kind = "Refill" }, 0, ROW)
			expect(reason).to.equal(nil)
			expect(refilled.reserve.Slug).to.equal(12)
			expect(refilled.reserve.Buck).to.equal(12)
			-- WHAT IS IN THE GUN IS NOT TOUCHED: a hunter who starts a drive with a live shell in the
			-- left barrel keeps it, which is what carrying a loaded gun means.
			expect(refilled.barrels[1]).to.equal("Spent")
			expect(refilled.barrels[2]).to.equal("Live")
			expect(refilled.loaded[2]).to.equal("Slug")
			expect(refilled.busyUntil).to.equal(1e9)
			-- THE RIFLE KEEPS ITS OWN NUMBER: the row is the config, so nothing here is the shotgun's.
			local rifle =
				StateMachine.apply(StateMachine.initial(Weapons.ROWS.rifle), { kind = "Refill" }, 0, Weapons.ROWS.rifle)
			expect(rifle.reserve.Slug).to.equal(Weapons.ROWS.rifle.START_RESERVE.Slug)
			expect(rifle.reserve.Slug ~= 12).to.equal(true)
		end)

		it("refills once per drive, so dying in the middle of one is not a resupply", function()
			expect(Weapon.needsRefill(nil, 1)).to.equal(true)
			expect(Weapon.needsRefill(1, 1)).to.equal(false)
			expect(Weapon.needsRefill(1, 2)).to.equal(true)
			expect(Weapon.needsRefill(2, 1)).to.equal(true) -- a drive counter that went back still refills
			-- NO DRIVE MEANS NO REFILL, which is the DEV place with no `Match` and every weapon spec:
			-- they start full from `StateMachine.initial` and this task leaves them alone.
			expect(Weapon.needsRefill(nil, nil)).to.equal(false)
			expect(Weapon.needsRefill(nil, "1")).to.equal(false)
		end)

		it("is idempotent for one drive at the owner, for a player who really has a gun", function()
			local subject = nil
			for _, player in ipairs(Players:GetPlayers()) do
				if Weapon.getSnapshot(player) ~= nil then
					subject = player
					break
				end
			end
			if subject == nil then
				TestKit.note("weapon_rules: no tracked player, so the owner's refill was not driven")
				-- Never silently: the pure half of the same rule is asserted instead.
				expect(Weapon.needsRefill(nil, 7)).to.equal(true)
				return
			end
			-- A drive number no real drive has reached, so this cannot collide with the live one.
			local filled = Weapon.refillForDrive(subject, 9001)
			expect(filled >= 1).to.equal(true)
			expect(Weapon.refillForDrive(subject, 9001)).to.equal(0)
			expect(Weapon.refillForDrive(subject, 9002) >= 1).to.equal(true)
			local snapshot = Weapon.getSnapshot(subject)
			expect(snapshot).to.be.ok()
			-- THE POCKET OF WHICHEVER GUN HE IS HOLDING, from ITS row: the shotgun's 12 and the
			-- rifle's 9 are different numbers and this case must not assert one for the other (the
			-- rule `Weapon.refillForDrive` itself follows).
			local held = Weapons.row((snapshot :: any).weapon) or ROW
			expect((snapshot :: any).reserve.Slug).to.equal(held.START_RESERVE.Slug)
			TestKit.note(
				string.format(
					"weapon_rules: refilled %d weapon(s) for %s, holding %s, pocket Slug=%d",
					filled,
					subject.Name,
					tostring((snapshot :: any).weapon),
					(snapshot :: any).reserve.Slug
				)
			)
			-- PUT BACK: the live drive must be able to refill him again on its next transition, and
			-- 9002 would otherwise sit above every drive number this session will reach.
			Weapon.refillForDrive(subject, Match.snapshot().driveNumber or 1)
		end)
	end)

	describe("the drive's answers to the fire gate", function()
		it("names the species of anything that publishes one, and nobody else", function()
			-- A STUB, because no deer exists (that is the whole of rule 5 in this task's dispatch):
			-- one part, one attribute, parented nowhere a player can reach.
			local stub = Instance.new("Part")
			stub.Name = "RulesSpecStubSpecies"
			stub:SetAttribute(Licences.SPECIES_ATTRIBUTE, "reddeer")
			local target = Match.classifyTarget(stub)
			expect(target).to.be.ok()
			expect((target :: any).species).to.equal("reddeer")
			expect((target :: any).beater).to.equal(false)
			-- AND THE RULE REFUSES IT, which is the claim the stub exists for: a deer nobody has a
			-- licence for cannot be shot, on the game's own table, with no deer in the game.
			expect(Rules.unlicensed(target, nil)).to.equal(true)
			expect(Rules.unlicensed(target, { reddeer = true })).to.equal(false)
			expect(Rules.beaterInLine(target)).to.equal(false)

			-- A child of it answers the same, because a ray hits a limb and not the thing that owns
			-- the attribute.
			local child = Instance.new("Part")
			child.Parent = stub
			expect((Match.classifyTarget(child) :: any).species).to.equal("reddeer")

			-- Nothing claimed, nothing answered: a tree, the ground, a miss.
			local plain = Instance.new("Part")
			expect(Match.classifyTarget(plain)).to.equal(nil)
			expect(Match.classifyTarget(nil)).to.equal(nil)
			stub:Destroy()
			plain:Destroy()
		end)

		it("gives a stand circle to a shooter in this drive and none to anybody else", function()
			local report = {}
			local shooters, others = 0, 0
			for _, player in ipairs(Players:GetPlayers()) do
				local team = Match.assignmentOf(player.UserId)
				local area = Match.standAreaFor(player)
				table.insert(report, string.format("%s=%s/%s", player.Name, tostring(team), tostring(area ~= nil)))
				if team == "Shooters" then
					shooters += 1
					-- An area is OPTIONAL even for a shooter: with no marker set, or nowhere to put
					-- him, there is no circle and `Weapon.Rules.outsideStand` then has no rule --
					-- which is exactly the honest answer and not a silent "he may not shoot".
					if area ~= nil then
						expect(typeof(area.centre)).to.equal("Vector3")
						expect(area.radius).to.equal(Match.config().STAND_RADIUS_STUDS)
						-- HE IS STANDING IN IT, which is the whole claim: the drive puts a shooter on
						-- his post and the circle is centred on that post, so the rule cannot refuse
						-- a hunter the drive has just placed. 12 studs is task 166's measurement.
						expect(Rules.outsideStand(area.centre, area)).to.equal(false)
					end
				else
					others += 1
					-- A BEATER IS NOT HELD TO A STAND (`ForestTest.boundary`'s own first rule), and
					-- neither is a player with no assignment at all.
					expect(area).to.equal(nil)
				end
			end
			expect(Match.config().STAND_RADIUS_STUDS).to.equal(12)
			-- ...AND THE WIRE CARRIES THE SAME CIRCLE (task 171). The client had no way to know where
			-- a hunter's stand was in this world -- which is why `zz_tie_to_a_tree.spec` staged its
			-- shot 525 studs from the post and the off-stand rule refused it -- so the snapshot now
			-- publishes `Match.standAreaOf`'s own answer, keyed by `tostring(userId)`. ONE answer,
			-- two readers: the fire gate and the screen.
			local published = (Match.snapshot() :: any).stands
			for _, player in ipairs(Players:GetPlayers()) do
				local area = Match.standAreaOf(player.UserId)
				local onWire = if published ~= nil then published[tostring(player.UserId)] else nil
				if area == nil then
					expect(onWire).to.equal(nil)
				else
					expect(onWire).to.be.ok()
					expect((onWire :: any).radius).to.equal(area.radius)
					expect(((onWire :: any).centre - area.centre).Magnitude < 1e-4).to.equal(true)
				end
			end
			TestKit.note(
				string.format(
					"weapon_rules: stand areas by player [%s] (%d shooter(s), %d other(s))",
					table.concat(report, ", "),
					shooters,
					others
				)
			)
		end)
	end)

	describe("the handler the remote calls", function()
		-- THE GATE IS ASKED ON THE REAL PATH, and a refused shot COSTS NOTHING: that is the one claim
		-- the pure cases above cannot make. `Weapon.onFireRequest` is the function `Weapon.start`
		-- connects to `FireRequest`, and it returns its own decision per call (task 80), so nothing
		-- here is inferred from a counter another player could move.
		it("refuses a shot at a beater and spends no shell, then fires the same shot once the rule is gone", function()
			local subject, snapshot = nil, nil
			local roster = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local state = Weapon.getSnapshot(player)
				local live = state ~= nil and state.equipped == true and state.barrels[state.selected] == "Live"
				table.insert(roster, player.Name .. (if live then "(armed)" else "(not armed)"))
				if subject == nil and live then
					subject, snapshot = player, state
				end
			end
			if subject == nil then
				TestKit.note(
					"weapon_rules: nobody is holding a loaded gun, so the handler was not driven; roster ["
						.. table.concat(roster, ", ")
						.. "]"
				)
				-- Not silent: the pure rule the handler would have asked.
				expect(Rules.beaterInLine({ beater = true })).to.equal(true)
				return
			end

			local root = subject.Character and subject.Character:FindFirstChild("HumanoidRootPart")
			expect(root).to.be.ok()
			local origin = (root :: BasePart).Position + Vector3.new(0, 2, 0)
			local request = { origin = origin, direction = Vector3.new(0, 0, -1) }

			-- THE SEAMS, ALL FOUR PUT BACK IN THIS CASE'S OWN LAST LINES. The cast answers one
			-- fixed impact so the aim ray cannot depend on what happens to be in front of the
			-- player, and the providers are this case's own answers.
			local stub = Instance.new("Part")
			stub.Name = "RulesSpecStubBeater"
			local hit = {
				instance = stub,
				position = origin + Vector3.new(0, 0, -20),
				normal = Vector3.new(0, 0, 1),
				distance = 20,
			}
			Weapon.setCast(function()
				return hit
			end)
			Weapon.setTargetProvider(function(instance)
				return if instance == stub then { beater = true } else nil
			end)
			Weapon.setStandProvider(nil)
			Weapon.setLicenceProvider(nil)

			local before = Weapon.stats()
			local function ask(): string?
				local why = Weapon.onFireRequest(subject, request)
				if why == "rate-limited" then
					task.wait(1.1)
					why = Weapon.onFireRequest(subject, request)
				end
				return why
			end

			local refusedWhy = ask()
			local afterRefusal = Weapon.getSnapshot(subject)
			local midStats = Weapon.stats()

			-- ...AND NOW THE SAME SHOT WITH NO RULE IN FRONT OF IT, which is what proves the refusal
			-- came from the rule and not from the gun, the state or the harness.
			Weapon.setTargetProvider(nil)
			task.wait(1.1) -- the fire limiter is per second and this case fires twice
			local firedWhy = Weapon.onFireRequest(subject, request)
			local afterShot = Weapon.getSnapshot(subject)
			local endStats = Weapon.stats()

			Weapon.setCast(nil)
			Weapon.setTargetProvider(Match.classifyTarget)
			Weapon.setStandProvider(Match.standAreaFor)
			stub:Destroy()

			TestKit.note(
				string.format(
					"weapon_rules: %s refused=%s fired=%s; shots +%d/+%d, refused +%d/+%d; " .. "barrels %s -> %s -> %s",
					subject.Name,
					tostring(refusedWhy),
					tostring(firedWhy),
					midStats.shots - before.shots,
					endStats.shots - before.shots,
					midStats.refused - before.refused,
					endStats.refused - before.refused,
					table.concat(snapshot.barrels, "/"),
					table.concat((afterRefusal :: any).barrels, "/"),
					table.concat((afterShot :: any).barrels, "/")
				)
			)

			-- THE REFUSAL, and what it did NOT do.
			expect(refusedWhy).to.equal(Rules.REASON.BEATER)
			expect(midStats.shots).to.equal(before.shots) -- no shot was taken
			expect(midStats.refused).to.equal(before.refused + 1)
			expect((midStats.refusedBy[Rules.REASON.BEATER] or 0)).to.equal(
				(before.refusedBy[Rules.REASON.BEATER] or 0) + 1
			)
			-- NO SHELL SPENT, NO BARREL MOVED, NO POCKET TOUCHED: the gun is exactly as it was.
			expect((afterRefusal :: any).barrels[1]).to.equal(snapshot.barrels[1])
			expect((afterRefusal :: any).barrels[2]).to.equal(snapshot.barrels[2])
			expect((afterRefusal :: any).selected).to.equal(snapshot.selected)
			expect((afterRefusal :: any).reserve.Slug).to.equal(snapshot.reserve.Slug)
			-- WHAT THE CLIENT IS TOLD cannot be read back from here: `Weapon.getSnapshot` builds a
			-- FRESH snapshot of the state, and `refused`/`notice` belong to the one the owner
			-- PUBLISHED. So what is asserted is that the wire can carry both, with the owner's own
			-- values -- the publish itself is a read of `onFireRequest`, named in the review request.
			local wire = Shotgun.snapshot(
				StateMachine.initial(ROW),
				0,
				Rules.noticeFor(Rules.REASON.BEATER),
				"shotgun",
				nil,
				Rules.REASON.BEATER
			)
			expect(wire.refused).to.equal(Rules.REASON.BEATER)
			expect(wire.notice).to.equal("NOT AT A BEATER")
			expect(table.isfrozen(wire)).to.equal(true)

			-- THE CONTROL: the same request, the same gun, no beater in the ray.
			expect(firedWhy).to.equal(nil)
			expect(endStats.shots).to.equal(before.shots + 1)
			expect((afterShot :: any).barrels[snapshot.selected]).to.equal("Spent")
			expect((afterShot :: any).refused).to.equal(nil)
		end)
	end)
end
