-- deer.spec: THE RED DEER (task 223) -- stag, hind and calf in the drive, behind a licence.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- Karen, 2026-10-20: *"I will buy red tag deer"*, and then the rule, verbatim: *"deer also will be
-- possible to shoot if you have purchased deer license"*.
--
-- **EVERY CASE HERE ENTERS AN ARM THAT DID NOT EXIST BEFORE THIS TASK**, which is the thing the
-- Learning Agent's L-093 asks for and the thing a licence spec is easiest to get wrong at: a
-- `has licence` assertion is trivially satisfiable with the branch never inverted, so each of the
-- two licence cases below is written as a PAIR -- the same real animal, the same real gate, one
-- player holding the card and one not -- and the calf's penalty is a case of its own rather than a
-- corollary of the stag's.
--
-- MOSTLY PURE, for `boar_legendary.spec`'s stated reason: `BOAR_MODEL` sits at its DEFAULT in every
-- harness run (`test` refuses to start with an override set) -- `true` since task 230 -- so the only
-- way both states are reachable is to drive the config by parameter. The two cases that are not pure are the two that
-- cannot be: a REAL trunk built by `Body.create` reaching the REAL fire gate, and the per-drive cap,
-- which is runtime state across two releases.
--
-- Design: docs/design/red-deer.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Assets = require(game:GetService("ServerStorage"):WaitForChild("Assets"))
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local ForestTest = require(ReplicatedStorage:WaitForChild("ForestTest"))
local Licences = require(ReplicatedStorage:WaitForChild("Licences"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local Brain = Boar.Brain
local Body = require(ServerScriptService:WaitForChild("Boar"):WaitForChild("Body"))

local Rules = Weapon.Rules
local Score = Match.Score
local CONFIG = Boar.CONFIG

local EPSILON = 1e-4
local DEER_KINDS = { "stag", "hind", "calf" }
local BOAR_KINDS = { "male", "female", "cub", "legendary" }
local ALL_KINDS = { "male", "female", "cub", "legendary", "stag", "hind", "calf" }
local FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
}

-- THE CLIP NAME -> ASSET KEY MAPS, ONE PER SPECIES, written out as LITERAL key strings for the
-- reason `boar_model.spec`'s own `KEY_OF` is: reading them out of `Assets.KEYS` would assert that
-- the manifest agrees with itself. The ELEVEN names are the deer's own; the boar's table is here
-- only so the case below can prove the two species' ids are different numbers.
local DEER_CLIP_KEY = {
	idle = "deer.anim.idle",
	walk = "deer.anim.walk",
	trot = "deer.anim.trot",
	run = "deer.anim.run",
	turnLeft = "deer.anim.turn.left",
	turnRight = "deer.anim.turn.right",
	deathLeft = "deer.anim.death.left",
	deathRight = "deer.anim.death.right",
	hitFront = "deer.anim.hit.front",
	hitBack = "deer.anim.hit.back",
	smell = "deer.anim.calm.smell",
	leap = "deer.anim.leap", -- the twelfth, task 245b
}
local BOAR_CLIP_KEY = {
	idle = "boar.anim.idle",
	walk = "boar.anim.walk",
	trot = "boar.anim.trot",
	run = "boar.anim.run",
	turnLeft = "boar.anim.turn.left",
	turnRight = "boar.anim.turn.right",
	deathLeft = "boar.anim.death.left",
	deathRight = "boar.anim.death.right",
	hitFront = "boar.anim.hit.front",
	hitBack = "boar.anim.hit.back",
	smell = "boar.anim.calm.smell",
}

-- THE FLAG AS A PARAMETER, the one permitted shape (`boar_kinds.spec`'s own helper). A deep-enough
-- clone that `KINDS.ENABLED` can be true without the module's own frozen table being touched.
local function configWith(on: boolean)
	local config = table.clone(Boar.CONFIG)
	config.KINDS = table.clone(Boar.CONFIG.KINDS)
	config.KINDS.ENABLED = on
	config.MODEL = table.clone(Boar.CONFIG.MODEL)
	config.MODEL.ENABLED = on
	return config
end

return function()
	describe("the red deer", function()
		-- 0. THE DRIVE FORCE, AS A PURE RULE (task 328n) -----------------------------------------
		describe("Body.driveForce", function()
			it("returns MAX_FORCE unchanged for the box it was tuned on, and for a world without one", function()
				local config = Boar.CONFIG
				expect(Body.driveForce(config.MAX_FORCE_BODY, config)).to.equal(config.MAX_FORCE)
				expect(Body.driveForce(config.BODY_SIZE, config)).to.equal(config.MAX_FORCE)
				-- EVERY WORLD WRITTEN BEFORE THIS TASK: no `MAX_FORCE_BODY`, so no scaling at all.
				expect(Body.driveForce(Vector3.new(1.8, 4.8, 7.05), { MAX_FORCE = 6000 })).to.equal(6000)
			end)

			it("scales UP by volume for the red deer, and never down for a smaller box", function()
				local config = Boar.CONFIG
				local deer = (config.SPECIES.reddeer :: any).BODY_SIZE
				local ref = config.MAX_FORCE_BODY
				local ratio = (deer.X * deer.Y * deer.Z) / (ref.X * ref.Y * ref.Z)
				expect(ratio > 1.8).to.equal(true)
				expect(math.abs(Body.driveForce(deer, config) - config.MAX_FORCE * ratio) < 1e-6).to.equal(true)
				-- THE FLOOR. A cub-sized box scaled both ways came out at 547 against 6000, which
				-- is a weaker cub nobody asked for; it keeps the whole number.
				expect(Body.driveForce(Vector3.new(1, 1.5, 2.75), config)).to.equal(config.MAX_FORCE)
			end)
		end)

		-- 0b. THE TWO OF TASK 344b: ON ITS FEET AFTER A BOUND, AND DEAD THE WAY UP ---------------
		--
		-- KAREN, 2026-11-10, playing her Forest Test at #357: *"still bug with redstag jumping then
		-- fall on side and glide"* and *"animal died and then stand and then again die"*. MEASURED in
		-- her place with `<runs-dir>/344b-srv.luau` before the fix: over 58 stag landings **10 ended
		-- past 20 degrees of tilt and the worst reached 96** -- the body on its side, still driven at
		-- 28.3 studs/s -- and of 11 kills the ONE animal shot in that state drew a bone span of
		-- **5.20 studs** (a deer standing; a lying one is ~1.4) for the whole 110 s it was watched.
		-- The two are one fault: the box is the frame the death clip lays the rig down IN.
		describe("the upright torque and the level death (task 344b)", function()
			it("gives a bigger box more torque, and the reference box exactly MAX_TORQUE", function()
				local config = Boar.CONFIG
				-- THE REFERENCE BOX: unchanged to the byte, which is the floor.
				expect(Body.uprightTorque(config.MAX_FORCE_BODY, config)).to.equal(config.MAX_TORQUE)
				expect(Body.uprightTorque(config.BODY_SIZE, config)).to.equal(config.MAX_TORQUE)
				-- ...AND SO IS EVERY BOX SMALLER THAN IT. A cub-sized box is never given LESS.
				expect(Body.uprightTorque(Vector3.new(1, 1.5, 2.75), config)).to.equal(config.MAX_TORQUE)
				-- THE LEGENDARY BOAR IS NOT UNCHANGED, AND THAT IS SAID OUT LOUD (round 1, finding
				-- 1): he is the male's box at `scale` 1.35, so his roll inertia is 4.48x the
				-- reference's and this rule hands him ~89,680. It is the same arithmetic the stag
				-- gets and `Body.driveForce` already treats him the same way ("THE TWO ANIMALS
				-- BIGGER THAN IT"), but NO RUN IN THIS TASK SAMPLED HIM -- every measurement in
				-- `reviews/task-344b/REQUEST.md` is a staged stag.
				local legendary = config.BODY_SIZE * (config.KINDS.legendary :: any).scale
				local got = Body.uprightTorque(legendary, config)
				expect(got > config.MAX_TORQUE * 4).to.equal(true)
				expect(got < config.MAX_TORQUE * 5).to.equal(true)
				-- EVERY WORLD WRITTEN BEFORE THIS TASK: no `MAX_FORCE_BODY`, so no scaling at all.
				expect(Body.uprightTorque(Vector3.new(1.8, 4.8, 7.05), { MAX_TORQUE = 20000 })).to.equal(20000)
				-- THE DEER, AND THE ARITHMETIC IT IS: roll inertia is `m * (X^2 + Y^2) / 12` and the
				-- density is shared, so `volume * (X^2 + Y^2)` is the whole ratio -- 3.73 for the stag.
				local deer = (config.SPECIES.reddeer :: any).BODY_SIZE
				local ref = config.MAX_FORCE_BODY
				local ratio = (deer.X * deer.Y * deer.Z * (deer.X * deer.X + deer.Y * deer.Y))
					/ (ref.X * ref.Y * ref.Z * (ref.X * ref.X + ref.Y * ref.Y))
				expect(ratio > 3).to.equal(true)
				-- FAILS AT MAIN, where the stag is handed the boar's 20000. THE NUMBER IS THE ONE
				-- READ LIVE out of her Forest Test at the code commit (`344b-FINAL.out`, `build:`),
				-- not a transcription of the function under test (verdict 278).
				expect(Body.uprightTorque(deer, config) > config.MAX_TORQUE * 3).to.equal(true)
				expect(Body.uprightTorque(deer, config)).to.be.near(74627.86, 0.01)
			end)

			it("takes the roll and the pitch out of a death CFrame and keeps the yaw", function()
				-- THE STATE KAREN PHOTOGRAPHED: a trunk rolled onto its side when the shot lands.
				local yaw = math.rad(37)
				local at = Vector3.new(12, 5, -8)
				local tipped = CFrame.new(at) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(90))
				expect(tipped.UpVector.Y < 0.01).to.equal(true) -- on its side, which is the defect
				local level = Body.levelCFrame(tipped)
				-- FAILS AT MAIN (nothing levels the box) AND IF THE FUNCTION IS DELETED.
				expect(level.UpVector.Y).to.be.near(1, 1e-5)
				expect(level.Position).to.equal(at)
				-- ...AND IT IS STILL FACING WHERE IT DIED.
				local kept = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
				expect(level.LookVector:Dot(kept.LookVector)).to.be.near(1, 1e-4)
				-- AN ANIMAL ALREADY THE WAY UP IS NOT MOVED.
				expect(Body.levelCFrame(kept).LookVector:Dot(kept.LookVector)).to.be.near(1, 1e-5)
				-- NOSE STRAIGHT UP: there is no yaw to keep, and it must not error or return junk.
				local nose = CFrame.new(at) * CFrame.Angles(math.rad(90), 0, 0)
				expect(Body.levelCFrame(nose).UpVector.Y).to.be.near(1, 1e-5)
			end)

			it("stops the tumble on the frame the bound ends, and not before", function()
				-- MEASURED in her place: a stag touched down already rotating at **252 deg/s** and
				-- was at 90 degrees of tilt half a second later. The brake is one write, at the one
				-- instant the bound ends -- beside the write that already cancels the second little
				-- hop there -- so the upright constraint has an ANGLE to correct and not a SPIN.
				local deer = Boar.speciesConfig("reddeer", Boar.CONFIG)
				local part = Instance.new("Part")
				part.Size = Vector3.new(1.8, 4.8, 7.05)
				part.Anchored = false
				part.CanCollide = false
				part.Parent = workspace
				local handle: any = {
					part = part,
					visual = Instance.new("Model"),
					clip = "leap", -- `play` short-circuits, so no track machinery runs in a spec
					collapsed = false,
					toppled = false,
					reasserted = true,
					deadFor = 0,
					reholds = 0,
					tracks = {},
					hitFor = 0,
					clipHeldFor = 0,
					exitFor = 0,
					activityFor = 0,
					paddleFor = 0,
					warmFor = 0,
					yawRate = 0,
					rateWrites = 0,
					kind = "stag",
					leapFor = 0.2,
					leapSpent = false,
				}
				local info = { speed = 28.3, leaping = true, kind = "stag" }
				part.AssemblyAngularVelocity = Vector3.new(0, 0, 4.4) -- 252 deg/s, the measured one
				-- MID-BOUND: the brake has not fired, and the spin is the animal's own.
				Boar.stepVisual(handle, 1 / 60, info, deer)
				expect(handle.leapSpent).to.equal(false)
				expect(part.AssemblyAngularVelocity.Magnitude > 1).to.equal(true)
				-- THE FRAME THE BOUND ENDS: spun down to nothing. FAILS AT MAIN.
				Boar.stepVisual(handle, 0.5, info, deer)
				expect(handle.leapSpent).to.equal(true)
				expect(part.AssemblyAngularVelocity.Magnitude).to.be.near(0, 1e-5)
				part:Destroy()
			end)
		end)

		-- 1 + 2. THE LICENCE RULE, AS A PAIR, ON A REAL ANIMAL -----------------------------------
		--
		-- Not the hand-made stub `weapon_rules.spec` drives (that one proves the GATE with no world
		-- and must stay green); this one builds a REAL trunk with `Body.create`, reads it back the
		-- way the weapon does -- through `Match.classifyTarget`, which walks the instance for the
		-- species attribute -- and puts the answer through the real `Rules.refuse`.
		describe("the fire gate, reached from a trunk the boar owner built", function()
			local holder, runtime
			local trunks: { [string]: Instance } = {}

			beforeAll(function()
				holder = Instance.new("Folder")
				holder.Name = "DeerSpecAnimals"
				holder.Parent = Workspace
				-- THE PUBLIC DOOR AND NOT `Body.create`: `Body` is private on purpose ("the only
				-- writer of a boar's Instances" is a claim an export would weaken), so the animal
				-- is made the way the drive makes one. `KINDS.ENABLED` is merged key by key by
				-- `newRuntime`, which is why it arrives like this.
				runtime = Boar.newRuntime({
					field = FIELD,
					parent = holder,
					folderName = "DeerGate",
					rng = Random.new(223),
					config = { KINDS = { ENABLED = true }, maxBoars = 12 },
					threats = function()
						return {}
					end,
					probe = function()
						return false
					end,
					requestPath = function(_id, _from, _to, done)
						done(nil)
					end,
					releasePath = function() end,
				})
				for index, kind in ipairs(ALL_KINDS) do
					local handle = runtime:spawn(Vector3.new(index * 12, 10, 0), kind)
					trunks[kind] = handle.part
				end
			end)

			afterAll(function()
				runtime:destroy()
				holder:Destroy()
			end)

			-- THE DRIVE FORCE IS PER MASS, ON THE REAL TRUNK (task 328n). Karen: *"red stag stuck
			-- cant clim in this mountain"*. A constant `MaxForce` gave the deer 54 % of the boar's
			-- acceleration, which is what decides the slope it can climb. Read off the Instance the
			-- owner built, not off the pure rule, and asserted as an EQUAL ACCELERATION across all
			-- seven kinds -- the property. `AssemblyMass` is the trunk's own: zones and mesh are
			-- Massless.
			it("gives the stag the force his mass needs, and takes none off any animal", function()
				local function moverOf(kind: string): (BasePart, LinearVelocity)
					local trunk = trunks[kind] :: BasePart
					local mover = trunk:FindFirstChild("Mover") :: LinearVelocity
					expect(mover).to.be.ok()
					return trunk, mover
				end
				-- NOTHING LOSES FORCE. `driveForce` is a floor, so no animal in the game is driven
				-- by less than the 6000 it has had since Milestone 1.2.
				for _, kind in ipairs(ALL_KINDS) do
					local _, mover = moverOf(kind)
					expect(mover.MaxForce >= Boar.CONFIG.MAX_FORCE).to.equal(true)
				end
				-- THE THREE ANIMALS BUILT ON THE REFERENCE BOX KEEP IT EXACTLY: the male IS that
				-- box, and the sow and the cub are smaller, so the floor is what they get.
				for _, kind in ipairs({ "male", "female", "cub" }) do
					local _, mover = moverOf(kind)
					expect(mover.MaxForce).to.equal(Boar.CONFIG.MAX_FORCE)
				end
				-- ...AND THE TWO ANIMALS BIGGER THAN IT GET THE SAME ACCELERATION AS THE MALE,
				-- which is what decides the slope they can climb. The legendary is the male's box
				-- at scale 1.35; the stag's is 1.85x by volume.
				local male, maleMover = moverOf("male")
				local boarAccel = maleMover.MaxForce / male.AssemblyMass
				for _, kind in ipairs({ "stag", "legendary" }) do
					local trunk, mover = moverOf(kind)
					expect(mover.MaxForce > Boar.CONFIG.MAX_FORCE * 1.5).to.equal(true)
					local accel = mover.MaxForce / trunk.AssemblyMass
					expect(math.abs(accel - boarAccel) / boarAccel < 1e-6).to.equal(true)
				end
			end)

			-- THE UPRIGHT TORQUE IS PER INERTIA, ON THE REAL TRUNK (task 344b, round 1 finding 2).
			-- Read off the Instance `Body.create` built, exactly as the force case above is: the
			-- pure rule can be right while the line that puts it in the game is missing, and
			-- deleting `upright.MaxTorque = Body.uprightTorque(...)` left the whole suite green.
			it("gives the stag the upright torque his inertia needs, and takes none off any animal", function()
				local function uprightOf(kind: string): (BasePart, AlignOrientation)
					local trunk = trunks[kind] :: BasePart
					local upright = trunk:FindFirstChild("Upright") :: AlignOrientation
					expect(upright).to.be.ok()
					return trunk, upright
				end
				-- NOTHING LOSES TORQUE: the rule is a floor, like `driveForce`.
				for _, kind in ipairs(ALL_KINDS) do
					local _, upright = uprightOf(kind)
					expect(upright.MaxTorque >= Boar.CONFIG.MAX_TORQUE).to.equal(true)
				end
				-- THE THREE BUILT ON THE REFERENCE BOX OR SMALLER KEEP 20000 EXACTLY.
				for _, kind in ipairs({ "male", "female", "cub" }) do
					local _, upright = uprightOf(kind)
					expect(upright.MaxTorque).to.equal(Boar.CONFIG.MAX_TORQUE)
				end
				-- THE STAG GETS 3.73x, which is what he was missing: MEASURED in Karen's Forest
				-- Test, 10 of 58 landings ended past 20 degrees of tilt and the worst reached 96 --
				-- the body on its side, still driven at 28.3 studs/s. FAILS AT MAIN.
				local _, stag = uprightOf("stag")
				expect(stag.MaxTorque).to.be.near(74627.86, 0.01)
				-- ...AND THE LEGENDARY BOAR GETS 4.48x (round 1, finding 1). Unmeasured: no run in
				-- this task staged him. It is the same arithmetic and the same direction as the
				-- stag's, and `driveForce` already scales him the same way.
				local _, legendary = uprightOf("legendary")
				expect(legendary.MaxTorque > Boar.CONFIG.MAX_TORQUE * 4).to.equal(true)
			end)

			it("publishes reddeer on every deer kind and boar on every boar kind", function()
				-- BOTH ARMS of `Body.create`'s `row.species or Licences.ROWS.boar.species`. The
				-- second half is what proves the four boar rows did not change meaning when the
				-- field was added to three new ones.
				for _, kind in ipairs(DEER_KINDS) do
					expect(trunks[kind]:GetAttribute(Licences.SPECIES_ATTRIBUTE)).to.equal("reddeer")
				end
				for _, kind in ipairs(BOAR_KINDS) do
					expect(trunks[kind]:GetAttribute(Licences.SPECIES_ATTRIBUTE)).to.equal("boar")
				end
			end)

			it("REFUSES a shot at any red deer from a player with no card", function()
				for _, kind in ipairs(DEER_KINDS) do
					local target = Match.classifyTarget(trunks[kind])
					expect(target).to.be.ok()
					expect(target.species).to.equal("reddeer")
					-- The arm: `Rules.unlicensed` TRUE, reached through the real sequencer.
					expect(Rules.unlicensed(target, nil)).to.equal(true)
					expect(Rules.refuse({ target = target, licences = nil })).to.equal(Rules.REASON.LICENCE)
					expect(Rules.noticeFor(Rules.REASON.LICENCE)).to.equal("NO LICENCE")
				end
			end)

			it("ALLOWS the same shot from a player holding the deer card", function()
				-- THE SAME ANIMAL AND THE SAME GATE, inverted only by what he holds -- which is the
				-- half that makes the case above mean something.
				local held = ShopData.licencesFor({ [ShopData.ITEM.RED_STAG] = true })
				expect(held).to.be.ok()
				expect(held.reddeer).to.equal(true)
				for _, kind in ipairs(DEER_KINDS) do
					local target = Match.classifyTarget(trunks[kind])
					expect(Rules.unlicensed(target, held)).to.equal(false)
					expect(Rules.refuse({ target = target, licences = held })).to.equal(nil)
				end
			end)

			it("never asks a card of a boar, with or without one", function()
				for _, kind in ipairs(BOAR_KINDS) do
					local target = Match.classifyTarget(trunks[kind])
					expect(Rules.unlicensed(target, nil)).to.equal(false)
					expect(Rules.refuse({ target = target, licences = nil })).to.equal(nil)
				end
			end)

			it("sizes a deer off the DEER's trunk and not off a scaled boar", function()
				-- The seam reaching the world: a stag's physics box is the species' own measured
				-- box times his `scale`, and it is longer and NARROWER than a boar's.
				local stag = trunks.stag.Size
				local male = trunks.male.Size
				expect(stag.Z > male.Z).to.equal(true)
				expect(stag.X < male.X).to.equal(true)
				expect(stag.Z).to.be.near(CONFIG.SPECIES.reddeer.BODY_SIZE.Z, 0.01)
			end)
		end)

		-- 3. THE CATALOGUE -----------------------------------------------------------------------
		describe("the deer licence in the shop", function()
			it("is on sale, named for the species and still held to its own invariant", function()
				local row = ShopData.ROWS[ShopData.ITEM.RED_STAG]
				expect(row).to.be.ok()
				expect(row.sale).to.equal(true)
				expect(row.grants.licence).to.equal("reddeer")
				-- THE RENAME: it covers three animals, so it may not be named for one of them.
				expect(row.label).to.equal("DEER LICENCE")
				expect(string.find(row.label, "STAG")).to.equal(nil)
				expect(Licences.ROWS.reddeer.shipped).to.equal(true)
				expect(#ShopData.rowsOk(Weapons.ROWS, Weapons.ROWS.shotgun.AMMO_KINDS, Licences.ROWS)).to.equal(0)
			end)

			it("would STILL be refused for a species no build ships", function()
				-- THE INVARIANT IS NOT WEAKENED BY BEING SATISFIED (L-093: the other arm). A
				-- hand-made licence table with `shipped = false` must still close the door.
				local rows = { reddeer = table.clone(Licences.ROWS.reddeer) }
				rows.reddeer.shipped = false
				local problems = ShopData.rowsOk(Weapons.ROWS, Weapons.ROWS.shotgun.AMMO_KINDS, rows)
				expect(#problems > 0).to.equal(true)
			end)
		end)

		-- 4 + 5. THE SPECIES SEAM ----------------------------------------------------------------
		describe("speciesConfig and kindConfig", function()
			it("is the IDENTITY for nil, for boar and for a species nobody ships", function()
				-- BY REFERENCE, which is the whole property that makes this seam safe: a boar, and
				-- the whole flag-off world, get the table they always got and nothing can drift.
				local config = configWith(true)
				expect(Boar.speciesConfig(nil, config)).to.equal(config)
				expect(Boar.speciesConfig("boar", config)).to.equal(config)
				expect(Boar.speciesConfig("wolf", config)).to.equal(config)
			end)

			it("hands a deer its own trunk, zones and clips", function()
				local config = configWith(true)
				local deer = Boar.speciesConfig("reddeer", config)
				expect(deer).never.to.equal(config)
				expect(deer.BODY_SIZE).to.equal(CONFIG.SPECIES.reddeer.BODY_SIZE)
				expect(deer.ZONES).to.equal(CONFIG.SPECIES.reddeer.ZONES)
				-- THE `MODEL` IS AN OVERLAY SINCE TASK 240 and so is NOT the module's table by
				-- reference any more -- it is the WORLD's `MODEL` with `MODEL_OVERRIDES` laid over
				-- it. Asserted as the property rather than as an identity: every override wins, and
				-- `ANIMATION_IDS` is still the SAME TABLE the boot script fills, because a copy
				-- would leave every deer with an empty id table and no clips at all.
				expect(deer.MODEL).never.to.equal(CONFIG.SPECIES.reddeer.MODEL)
				for key, value in pairs(CONFIG.SPECIES.reddeer.MODEL_OVERRIDES) do
					expect(deer.MODEL[key]).to.equal(value)
				end
				expect(deer.MODEL.ANIMATION_IDS).to.equal(CONFIG.SPECIES.reddeer.MODEL.ANIMATION_IDS)
				expect(deer.MODEL.CLIPS).to.equal(CONFIG.SPECIES.reddeer.MODEL.CLIPS)
				-- The deer is longer than the boar and NOT a multiple of its box.
				expect(deer.BODY_SIZE.Z > config.BODY_SIZE.Z).to.equal(true)
				expect(deer.BODY_SIZE.X < config.BODY_SIZE.X).to.equal(true)
			end)

			-- 5b. THE WORLD'S OWN `MODEL` NUMBERS REACH THE DEER (task 240) ----------------------
			--
			-- KAREN, 2026-10-22: *"deer running is a bit odd"*. `ForestTestBoot` lowers
			-- `MODEL.RUN_FROM` from 28 to `(TROT_SPEED + PACE.RUN_SPEED) / 2` = 21 so an animal
			-- bolting at 24 is DRAWN running rather than trotting -- and until this task the deer
			-- kept the module's 28 while bolting at `24 x runScale 1.18` = 28.3, three tenths of a
			-- stud a second over its own band edge. MEASURED in two 70 s windows of real drives:
			-- 8 of 13 and 8 of 68 of the stag's samples at 20 studs/s or more were drawn TROTTING
			-- or WALKING, against 2-3 % for every boar kind and for the hind and the calf.
			--
			-- IT IS DRIVEN BY PARAMETER, as the whole file is: a world table with RUN_FROM moved,
			-- exactly the shape `ForestTestBoot` builds, and then the deer's own band read back
			-- through `Body.gaitBands` -- the function `Body.clipFor` picks a gait with.
			it("takes the WORLD's gait band, not the module's, so a bolting stag is drawn running", function()
				local config = configWith(true)
				local world = table.clone(config)
				world.MODEL = table.clone(config.MODEL)
				world.MODEL.RUN_FROM = 21 -- the Forest Test's own number
				world.MODEL.ENABLED = true

				local stag = Boar.kindConfig("stag", world)
				expect(stag.MODEL.RUN_FROM).to.equal(21)
				expect(stag.MODEL.ENABLED).to.equal(true)
				-- ...and the four overrides still win over the world's values.
				expect(stag.MODEL.CLIPS).to.equal(CONFIG.SPECIES.reddeer.MODEL.CLIPS)
				expect(stag.MODEL.TROT_FROM).to.be.near(
					CONFIG.SPECIES.reddeer.MODEL.CLIPS.walk.groundStudsPerSecond * config.MODEL.WALK_MAX_RATE,
					EPSILON
				)

				-- THE BAND, PER KIND, AGAINST THE SPEED EACH ONE ACTUALLY BOLTS AT. One case per
				-- arm (L-093): the stag was the only kind on its rail, and a case that only
				-- entered his would not notice if the hind's or the calf's regressed.
				for _, kind in ipairs(DEER_KINDS) do
					local animal = Boar.kindConfig(kind, world)
					local bands = Boar.gaitBands(CONFIG.KINDS[kind].clipScale, animal)
					local bolt = animal.PACE.RUN_SPEED
					expect(bolt > bands.runFrom).to.equal(true)
					-- A FIFTH OF MARGIN, not three tenths of a stud: below this the clip flickers
					-- between the trot and the run at every wobble in the animal's speed.
					expect((bolt - bands.runFrom) / bolt > 0.2).to.equal(true)
					TestKit.note(
						string.format(
							"deer-240: %s bolts at %.2f studs/s, run band from %.2f (margin %.0f%%)",
							kind,
							bolt,
							bands.runFrom,
							100 * (bolt - bands.runFrom) / bolt
						)
					)
				end

				-- AND WITHOUT THE WORLD'S NUMBER THE STAG IS BACK ON THE RAIL, which is the state
				-- Karen played: the two states have to be reachable by parameter or neither is
				-- tested. 28.32 against 28.0 is 1.1 % of margin.
				local onTheRail = Boar.kindConfig("stag", config)
				local railBands = Boar.gaitBands(1.0, onTheRail)
				expect(railBands.runFrom).to.equal(config.MODEL.RUN_FROM)
				expect((onTheRail.PACE.RUN_SPEED - railBands.runFrom) / railBands.runFrom < 0.05).to.equal(true)
			end)

			it("composes the species tables with the kind's wary scaling", function()
				local config = configWith(true)
				local stag = Boar.kindConfig("stag", config)
				expect(stag.BODY_SIZE).to.equal(CONFIG.SPECIES.reddeer.BODY_SIZE)
				-- 1.5 -> 1.8 IN TASK 251 PART 2 (spec section 3.1, Karen OK'd): *"a lone stag has no jumpy
				-- companion to trigger him, so he must be his own alarm"*, so he carries the hind's own
				-- scale. The radius this case is about is unchanged in MEANING -- it is still the kind's
				-- `wary` multiplier reaching `DETECT_RADIUS` through `scaledByWary` -- and what the stag
				-- NOTICES at is the case in "the red stag's own behaviour" below.
				expect(stag.DETECT_RADIUS).to.be.near(config.DETECT_RADIUS * 1.8, EPSILON)
				expect(stag.SPRINT_SPEED).to.be.near(config.SPRINT_SPEED * 1.18, EPSILON)
				local hind = Boar.kindConfig("hind", config)
				expect(hind.DETECT_RADIUS).to.be.near(config.DETECT_RADIUS * 1.8, EPSILON)
				-- ONE SPECIES, ONE RUN SPEED: a hind who outran her own calf would dissolve the
				-- group at `SOUNDER.BREAK_STUDS`, which is a correctness constraint and not taste.
				expect(Boar.kindConfig("calf", config).SPRINT_SPEED).to.be.near(hind.SPRINT_SPEED, EPSILON)
				-- ...and a boar with no `wary` row is still the config itself, by reference.
				expect(Boar.kindConfig("male", config)).to.equal(config)
			end)
		end)

		-- 5c. THE DEER'S VOICE IS NOT A PIG'S (task 240) -----------------------------------------
		--
		-- KAREN, 2026-10-22, after playing the Forest Test: *"deer sound has to bee when hit now it
		-- seems it's pig sound when I hit deer"*. Task 223 shipped the three deer rows holding the
		-- BOAR's pig squeals, pitched, and wrote that down as a known compromise. A pig squeal is
		-- the most recognisable noise in the whole set and pitching it does not stop it being one.
		--
		-- ONE CASE PER KIND AND PER CUE (L-093): the fix is a three-armed branch -- stag, hind,
		-- calf -- and a single generic "the deer does not sound like a pig" assertion would pass
		-- with two of the three arms still holding pig ids. That exact defect class cost task 219
		-- three review rounds.
		--
		-- IT IS ASSERTED AS A DISJOINTNESS and not as a list of expected ids: "the stag's death is
		-- 9113626273" would have to be edited by anybody who swaps a sample, which is the one thing
		-- this table is meant to make cheap. What may never happen is a deer and a boar sharing a
		-- sample, or a deer borrowing the module-level generic set (which IS the pig squeals).
		describe("the deer's voice", function()
			it("shares no sample with any boar cue, kind by kind and cue by cue", function()
				local on = configWith(true)
				local voice = CONFIG.SOUND.VOICE
				local sound = CONFIG.SOUND

				-- EVERY ID A BOAR CAN MAKE, including the module-level generic rows a kind with no
				-- voice falls back to -- because falling back IS how the deer got pig squeals.
				local boarIds: { [number]: string } = {}
				local function collect(ids, where: string)
					if type(ids) ~= "table" then
						return
					end
					for _, id in ipairs(ids) do
						boarIds[id] = where
					end
				end
				collect(sound.CRY.ids, "SOUND.CRY")
				collect(sound.DEATH.ids, "SOUND.DEATH")
				collect(sound.GRUNTS.ids, "SOUND.GRUNTS")
				for _, kind in ipairs(BOAR_KINDS) do
					local row = voice[kind]
					expect(row).to.be.ok()
					for _, cue in ipairs({ "cry", "death", "grunt" }) do
						collect(row[cue], kind .. "." .. cue)
					end
				end

				-- `SOUND.BARK.ids` IS NOT COLLECTED ABOVE, and that is the point rather than an
				-- omission (task 257): the bark is a cue NO BOAR CAN REACH. `Runtime:check` plays
				-- it only where `MOVE.EDGE_BARKS` is true, which is the stag's and the hind's
				-- `edge` rows and nothing else, so the row's ids are a deer's by construction.
				-- The case two below drives that switch on a real animal of each kind.
				local clashes = {}
				for _, kind in ipairs(DEER_KINDS) do
					for _, cue in ipairs({ "cry", "death", "grunt", "bark" }) do
						-- THROUGH THE REAL RESOLVER, not by reading the table: `Body.voiceIds` is
						-- what `playOneShot` calls, and its fallback to `spec.ids` is the path that
						-- produced the pig sound in the first place.
						local spec = if cue == "cry"
							then sound.CRY
							elseif cue == "death" then sound.DEATH
							elseif cue == "bark" then sound.BARK
							else sound.GRUNTS
						local ids = Boar.voiceIds(cue, kind, spec, on)
						-- A CALF HAS NO `bark` ROW AND MUST NOT GROW ONE: she never takes an edge
						-- check at all, so `voiceIds` falling through to `SOUND.BARK.ids` here is
						-- the honest answer and is asserted as such.
						if cue == "bark" and voice[kind][cue] == nil then
							expect(kind).to.equal("calf")
							expect(ids).to.equal(sound.BARK.ids)
						else
							expect(ids).to.equal(voice[kind][cue]) -- its OWN list, never the generic one
						end
						expect(#ids > 0).to.equal(true)
						for _, id in ipairs(ids) do
							if boarIds[id] ~= nil then
								table.insert(
									clashes,
									string.format("%s.%s id %d is also %s", kind, cue, id, boarIds[id])
								)
							end
						end
					end
				end
				table.sort(clashes)
				expect(table.concat(clashes, " | ")).to.equal("")
			end)

			it("gives each deer kind a pitch of its own, measured against ITS OWN sample", function()
				-- THE THREE NUMBERS ARE NOT IN SIZE ORDER AND MUST NOT BE READ AS IF THEY WERE
				-- (round 1's note). The boar's three are one sample set, so their ratio IS which
				-- animal sounds deeper; the deer's are not -- the stag's 1.15 multiplies a BULL
				-- bellow (pitched UP, a stag being about a third of a bull) and the hind's 0.80 a
				-- LAMB bleat (pitched DOWN, a hind being about three lambs). Comparing 1.15 with
				-- 0.80 says nothing about either animal.
				--
				-- SO WHAT IS ASSERTED IS WHAT IS TRUE: three distinct pitches, none of them task
				-- 223's pig-era numbers, and the hind not sharing the sow's samples.
				local voice = CONFIG.SOUND.VOICE
				local seen = {}
				for _, kind in ipairs(DEER_KINDS) do
					expect(type(voice[kind].pitch)).to.equal("number")
					expect(voice[kind].pitch > 0).to.equal(true)
					expect(seen[voice[kind].pitch]).to.equal(nil)
					seen[voice[kind].pitch] = kind
				end
				-- THE CALF IS THE THIN ONE AND THE HIND IS NOT, within the one sample set they share.
				expect(voice.calf.pitch > voice.hind.pitch).to.equal(true)
				-- ...AND THE TWO FEMALES ARE NOT THE SAME ANIMAL: a hind bleats and a sow squeals,
				-- so if the two rows ever converge on one sample set the deer is a pig again.
				expect(voice.hind.death).never.to.equal(voice.female.death)
			end)

			-- ROUND 1, FINDING 2'S REPLACEMENT. The case that stood here named no deer and would have
			-- passed with every line of this task reverted: it asserted `DEATH.cut`, `SQUEAL_SECONDS`
			-- and `CRY.cut == nil`, all three of which predate the task. It also failed to catch
			-- round 1's finding 1 -- that the hind's and the calf's bleats are LONGER than the budget
			-- the world books for them.
			--
			-- THIS ONE ASSERTS THE RELATION ON THE DEER'S OWN ROWS, off MEASURED lengths
			-- (`VOICE.LENGTHS`, read back from `Sound.TimeLength` in a live session), so an id added
			-- without a measurement fails the suite and an id that is too long fails it too.
			it("cannot hold a voice slot it has already given back, on any deer kind or cue", function()
				local on = configWith(true)
				local sound = CONFIG.SOUND
				local voice = sound.VOICE
				local crowd = sound.CROWD
				local specOf = {
					cry = sound.CRY,
					death = sound.DEATH,
					grunt = sound.GRUNTS,
					bark = sound.BARK, -- task 257
				}

				-- EVERY ID IN THE TABLE HAS A MEASURED LENGTH, boar ids included, because the bound
				-- below is a comparison and an unmeasured id would silently skip it.
				local unmeasured = {}
				local function check(ids, where: string)
					for _, id in ipairs(ids) do
						local length = voice.LENGTHS[id]
						if type(length) ~= "number" or length <= 0 then
							table.insert(unmeasured, string.format("%s id %d", where, id))
						end
					end
				end
				for _, cue in ipairs({ "cry", "death", "grunt", "bark" }) do
					check(specOf[cue].ids, "SOUND." .. cue)
					for _, kind in ipairs(CONFIG.KINDS.ORDER) do
						check(voice[kind][cue] or {}, kind .. "." .. cue)
					end
				end
				table.sort(unmeasured)
				expect(table.concat(unmeasured, ", ")).to.equal("")

				-- ...AND NO DEER CUE SOUNDS FOR LONGER THAN THE WORLD BOOKS IT FOR. A sample plays
				-- for `length / pitch` seconds and `Body.voiceCut` bounds that; the booking is
				-- `SQUEAL_SECONDS` for a cry or a death (`Runtime:_claimSqueal`) and
				-- `GRUNT_GAP_SECONDS` for a grunt (the gap before another may START).
				--
				-- ...AND A CLIPPED ID IS MEASURED BY ITS REGION AND NOT BY ITS FILE (task 257).
				-- `VOICE.LENGTHS` for the two real recordings is 177.3483 s and 34.0 s -- the whole
				-- file -- and neither is ever played whole: `Body.voiceClip` answers a region, and
				-- the longest region is what the cue can actually hold. Dividing the FILE by the
				-- pitch here would still pass (the cut bounds it either way) while asserting
				-- nothing about the thing that sounds, which is how a 1.8 s region could be added
				-- to a 1.2 s booking with a green suite.
				local tooLong, lines = {}, {}
				local clips = CONFIG.SOUND.VOICE.CLIPS or {}
				for _, kind in ipairs(DEER_KINDS) do
					local pitch = voice[kind].pitch
					for _, cue in ipairs({ "cry", "death", "grunt", "bark" }) do
						local spec = specOf[cue]
						local cut = Boar.voiceCut(cue, kind, spec, on)
						local budget = if cue == "grunt" then crowd.GRUNT_GAP_SECONDS else crowd.SQUEAL_SECONDS
						for _, id in ipairs(Boar.voiceIds(cue, kind, spec, on)) do
							local entry = clips[id]
							local whole
							if entry ~= nil then
								-- THE CLIP'S OWN PITCH, where it has one: it REPLACES the kind's
								-- centre in `playOneShot`, so the kind's is not what this sounds at.
								local speed = if type(entry.pitch) == "number" then entry.pitch else pitch
								whole = 0
								for _, region in ipairs(entry.regions) do
									whole = math.max(whole, Boar.clipSeconds(region, speed))
								end
							else
								whole = voice.LENGTHS[id] / pitch
							end
							local sounds = if cut ~= nil then math.min(whole, cut) else whole
							if sounds >= budget then
								table.insert(
									tooLong,
									string.format(
										"%s.%s id %d sounds %.2f s against %.2f",
										kind,
										cue,
										id,
										sounds,
										budget
									)
								)
							end
							table.insert(lines, string.format("%s.%s %.2fs", kind, cue, sounds))
						end
					end
				end
				table.sort(tooLong)
				expect(table.concat(tooLong, " | ")).to.equal("")
				TestKit.note("deer-240 cue lengths: " .. table.concat(lines, " "))
			end)

			-- ...AND THE OTHER HALF OF THE SAME FIX: the cut is on the DEER's rows and nowhere else,
			-- so the boar makes exactly the noise Karen signed off (*"animal react sound is good"*).
			it("cuts only the deer, and never lengthens a death", function()
				local on = configWith(true)
				local sound = CONFIG.SOUND
				local specOf = { cry = sound.CRY, death = sound.DEATH, grunt = sound.GRUNTS }
				-- ONE ARM PER BOAR KIND (L-093): a case that only entered the male's would not see a
				-- `cut` smuggled onto the legendary.
				for _, kind in ipairs(BOAR_KINDS) do
					expect(CONFIG.SOUND.VOICE[kind].cut).to.equal(nil)
					for _, cue in ipairs({ "cry", "death", "grunt" }) do
						expect(Boar.voiceCut(cue, kind, specOf[cue], on)).to.equal(specOf[cue].cut)
					end
				end
				-- ...AND ONE PER DEER KIND: the cry and the grunt take the row's, the DEATH keeps the
				-- 0.6 s Karen asked for, because `voiceCut` takes the SMALLER of the two.
				for _, kind in ipairs(DEER_KINDS) do
					local own = CONFIG.SOUND.VOICE[kind].cut
					expect(own).to.be.ok()
					expect(own).to.be.near(CONFIG.SOUND.VOICE.CUE_CUT_SECONDS, EPSILON)
					expect(Boar.voiceCut("cry", kind, sound.CRY, on)).to.be.near(own, EPSILON)
					expect(Boar.voiceCut("grunt", kind, sound.GRUNTS, on)).to.be.near(own, EPSILON)
					expect(Boar.voiceCut("death", kind, sound.DEATH, on)).to.be.near(sound.DEATH.cut, EPSILON)
					expect(sound.DEATH.cut < own).to.equal(true)
				end
				-- A CUT CUE MUST BE ABLE TO END RATHER THAN BE CHOPPED, which is what `fade` is for
				-- and what `Body.cutVolume` reads. The two cues the deer newly cuts had none.
				expect(sound.CRY.fade).to.be.ok()
				expect(sound.GRUNTS.fade).to.be.ok()
				expect(sound.CRY.fade < CONFIG.SOUND.VOICE.CUE_CUT_SECONDS).to.equal(true)
				-- ...and with the voice OFF nothing is cut that was not cut before.
				local off = table.clone(on)
				local offSound = table.clone(CONFIG.SOUND)
				offSound.VOICE = table.clone(CONFIG.SOUND.VOICE)
				offSound.VOICE.ENABLED = false
				off.SOUND = offSound
				expect(Boar.voiceCut("cry", "stag", sound.CRY, off)).to.equal(sound.CRY.cut)
			end)
		end)

		-- 5d. TWENTY PER CENT MORE HITS (task 240) ------------------------------------------------
		--
		-- KAREN, 2026-10-22: *"deer need more hits before die a bit more like 20% more"*.
		-- `toughness` is the mechanism task 219 built for the legendary and 1.2 is her sentence
		-- arithmetically: `Wound.damageFor` divides a NON-VITAL hit by it, so each point is worth
		-- 83.3 % and it takes 20 % more of them. One case per kind (L-093), because three rows were
		-- edited and a case that only entered the stag's would not see a missing one.
		describe("how much a deer takes", function()
			local Wound = Boar.Wound
			local WOUND = CONFIG.WOUND

			it("is a fifth tougher than it was, on every one of the three kinds", function()
				local on = configWith(true)
				for _, kind in ipairs(DEER_KINDS) do
					expect(Boar.toughnessFor(kind, on)).to.be.near(1.2, EPSILON)
				end
				-- ...and the boars are untouched: only the legendary has ever had armour.
				expect(Boar.toughnessFor("male", on)).to.equal(nil)
				expect(Boar.toughnessFor("female", on)).to.equal(nil)
				expect(Boar.toughnessFor("cub", on)).to.equal(nil)
				expect(Boar.toughnessFor("legendary", on)).to.be.near(2.0, EPSILON)
				-- WITH THE KINDS OFF NOTHING IS ARMOURED, which is the flag-off world unchanged.
				for _, kind in ipairs(DEER_KINDS) do
					expect(Boar.toughnessFor(kind, configWith(false))).to.equal(nil)
				end
			end)

			it("leaves the head and the chest unarmoured and charges the rump and legs a fifth more", function()
				local tough = Boar.toughnessFor("stag", configWith(true))
				-- THE VITALS ARE NEVER ARMOURED -- `Wound.damageFor`'s own rule and the hunting rule
				-- behind it: take the chamber or the head. A chest slug still drops a stag.
				for _, zone in ipairs({ "head", "chest" }) do
					expect(Wound.damageFor(zone, "Slug", 1, WOUND, tough)).to.equal(
						Wound.damageFor(zone, "Slug", 1, WOUND, nil)
					)
					expect(Wound.damageFor(zone, "Slug", 1, WOUND, tough) >= WOUND.LETHAL).to.equal(true)
				end
				-- ...AND EVERYTHING ELSE IS WORTH FIVE SIXTHS.
				for _, zone in ipairs({ "rear", "legs" }) do
					for _, ammo in ipairs({ "Slug", "Pellet" }) do
						local before = Wound.damageFor(zone, ammo, 1, WOUND, nil)
						local after = Wound.damageFor(zone, ammo, 1, WOUND, tough)
						expect(after).to.be.near(before / 1.2, EPSILON)
					end
				end
			end)

			it("names the hits to kill, before and after", function()
				-- THE NUMBERS IN THE REPORT, COMPUTED RATHER THAN TYPED. `Wound.damageFor` has no
				-- range term, so these are the same at 20 m and at 40 m; what range changes is how
				-- many pellets land, and buckshot's own `RANGE_STUDS` is 100 studs (28 m), so at
				-- 40 m none of them do.
				local function hitsTo(zone: string, ammo: string, target: number, tough: number?): number
					local each = Wound.damageFor(zone, ammo, 1, WOUND, tough)
					expect(each > 0).to.equal(true)
					return math.ceil(target / each)
				end
				local tough = Boar.toughnessFor("stag", configWith(true))
				local lines = {}
				for _, zone in ipairs({ "rear", "legs" }) do
					for _, ammo in ipairs({ "Slug", "Pellet" }) do
						local wasMortal = hitsTo(zone, ammo, WOUND.MORTAL, nil)
						local wasLethal = hitsTo(zone, ammo, WOUND.LETHAL, nil)
						local isMortal = hitsTo(zone, ammo, WOUND.MORTAL, tough)
						local isLethal = hitsTo(zone, ammo, WOUND.LETHAL, tough)
						-- IT MAY NEVER GET EASIER, which is the only direction this can be wrong in.
						expect(isMortal >= wasMortal).to.equal(true)
						expect(isLethal >= wasLethal).to.equal(true)
						table.insert(
							lines,
							string.format(
								"%s/%s mortal %d to %d, lethal %d to %d",
								zone,
								ammo,
								wasMortal,
								isMortal,
								wasLethal,
								isLethal
							)
						)
					end
				end
				-- ...AND IT REALLY IS HARDER SOMEWHERE, so a `toughness` of 1.0 could not pass this.
				local softLethal = hitsTo("rear", "Pellet", WOUND.LETHAL, nil)
				local hardLethal = hitsTo("rear", "Pellet", WOUND.LETHAL, tough)
				expect(hardLethal > softLethal).to.equal(true)
				TestKit.note("deer-240 hits to kill: " .. table.concat(lines, " | "))
			end)
		end)

		-- 5e. THE SWEEP IS AS WIDE AS THE ANTLERS (task 240) --------------------------------------
		--
		-- KAREN, 2026-10-22: *"deer running is a bit odd and seems it hitting trees"*. MEASURED in
		-- her own place off each kind's loaded mesh: a stag is DRAWN 3.47 studs wide and COLLIDES as
		-- a 1.80-wide box, so his box clears a trunk by 0.70 studs while his antlers are 0.84 studs
		-- inside it -- and the swept avoidance cast that is supposed to keep him off trunks was
		-- 1.60, narrower than his own drawn half-width of 1.735. Every BOAR is drawn NARROWER than
		-- its box (male 1.40 against 2.00), which is why no boar number may move.
		it("sweeps for trunks as wide as the animal a player SEES, and leaves every boar at 1.6", function()
			local on = configWith(true)
			local move = CONFIG.MOVE
			expect(move.AVOID_CLEARANCE_STUDS).to.be.ok()

			-- EVERY BOAR KIND IS THE NUMBER TASK 167 MEASURED, to the last decimal.
			for _, kind in ipairs(BOAR_KINDS) do
				expect(Boar.avoidRadius(kind, on)).to.be.near(move.AVOID_RADIUS_STUDS, EPSILON)
			end
			expect(Boar.avoidRadius(nil, on)).to.be.near(move.AVOID_RADIUS_STUDS, EPSILON)
			expect(Boar.avoidRadius("wildebeest", on)).to.be.near(move.AVOID_RADIUS_STUDS, EPSILON)

			-- ...AND EACH DEER KIND ENTERS ITS OWN ARM (L-093), through the config it really lives
			-- by, because `_avoidTurnFor` is handed `entry.config` and that is the SPECIES box.
			local widths = {}
			for _, kind in ipairs(DEER_KINDS) do
				local animal = Boar.kindConfig(kind, on)
				local row = CONFIG.KINDS[kind]
				expect(row.drawnWidthStuds).to.be.ok()
				local radius = Boar.avoidRadius(kind, animal)
				local widest = math.max(row.drawnWidthStuds, animal.BODY_SIZE.X)
				expect(radius).to.be.near(
					math.max(move.AVOID_RADIUS_STUDS, widest / 2 + move.AVOID_CLEARANCE_STUDS),
					EPSILON
				)
				-- THE PROPERTY THAT MATTERS: the cast is never narrower than the thing a player
				-- watches go past a trunk.
				expect(radius >= row.drawnWidthStuds / 2).to.equal(true)
				table.insert(widths, string.format("%s drawn %.2f, radius %.3f", kind, row.drawnWidthStuds, radius))
			end

			-- THE STAG IS THE ONE THAT MOVES, and it moves UP: a case that only asserted the
			-- formula would pass with every number unchanged.
			local stag = Boar.avoidRadius("stag", Boar.kindConfig("stag", on))
			expect(stag > move.AVOID_RADIUS_STUDS).to.equal(true)
			expect(stag).to.be.near(3.47 / 2 + move.AVOID_CLEARANCE_STUDS, EPSILON)
			-- EVERY KIND HAS THE MEASUREMENT, so a new animal cannot arrive without one -- and it
			-- walks `KINDS.ORDER` and not this file's own literal (round 1's note), because `ORDER`
			-- is what `BoarAssetsBoot` walks and what a new kind is really added to.
			expect(#CONFIG.KINDS.ORDER).to.equal(#ALL_KINDS)
			for _, kind in ipairs(CONFIG.KINDS.ORDER) do
				expect(type(CONFIG.KINDS[kind].drawnWidthStuds)).to.equal("number")
				expect(CONFIG.KINDS[kind].drawnWidthStuds > 0).to.equal(true)
			end
			TestKit.note("deer-240 avoid radius: " .. table.concat(widths, " | "))
		end)

		-- 6. THE CLIP TABLES ARE NOT SHARED ------------------------------------------------------
		it("gives the deer its own animation id table", function()
			-- THE BUG THIS SEAM EXISTS TO PREVENT, asserted where a spec can see it: sharing one
			-- table would play the BOAR's published ids on `Arm_Deer`, and nothing in the suite
			-- could tell, because an `AnimationId` is a number and it would be set correctly.
			local deerModel = CONFIG.SPECIES.reddeer.MODEL
			expect(deerModel.ANIMATION_IDS).never.to.equal(CONFIG.MODEL.ANIMATION_IDS)
			expect(deerModel.CLIPS).never.to.equal(CONFIG.MODEL.CLIPS)
			-- The deer asks for its OWN package's clip names, not the boar's.
			expect(deerModel.CLIPS.hitFront.clip).to.equal("Hit_Front")
			expect(CONFIG.MODEL.CLIPS.hitFront.clip).to.equal("Hit_F")
			-- Twelve since task 245b added the leap, and none of the boar's grazing four.
			local count = 0
			for _ in pairs(deerModel.CLIPS) do
				count += 1
			end
			expect(count).to.equal(12)
			expect(deerModel.CLIPS.grazeLoop).to.equal(nil)
			expect(deerModel.CLIPS.crippleDrag).to.equal(nil)
			-- ALL THREE MODELS HAVE ROWS, which is what makes a deer visible at all.
			for _, key in ipairs({ Assets.KEYS.deerStag, Assets.KEYS.deerHind, Assets.KEYS.deerCalf }) do
				local row = Assets.byKey(key)
				expect(row).to.be.ok()
				expect(row.kind).to.equal("model")
				expect(row.scope).to.equal("deer")
			end
		end)

		-- 6b. THE TWELVE PUBLISHED CLIPS (task 232, and the leap in 245b) ----------------------------------------------
		--
		-- IT IS THE MANIFEST THAT IS ASSERTED AND NOT THE LIVE `ANIMATION_IDS` TABLE, which is a
		-- real lesson from the first run of this spec: `_modelTemplate` FILLS that table from
		-- whatever source is wired, so another spec's fake id function had already written `20009`
		-- into it by the time this case ran. The manifest is the fact; the live table is session
		-- state.
		it("has a published animation row for every one of the deer's twelve clips", function()
			local model = CONFIG.SPECIES.reddeer.MODEL
			-- NAMED, NOT COUNTED: "3 missing" sends the next reader looking for which three.
			local missing, sharedWithBoar = {}, {}
			for name in pairs(model.CLIPS) do
				local key = DEER_CLIP_KEY[name]
				expect(key).to.be.ok()
				local row = Assets.byKey(key)
				if row == nil or row.kind ~= "animation" or row.modelId <= 0 then
					table.insert(missing, name)
				else
					-- ...AND IT IS NOT THE BOAR'S ID. The seam exists to stop a deer playing boar
					-- clips on `Arm_Deer`, and an `AnimationId` is a number, so nothing downstream
					-- could tell. This is where it is caught.
					-- A CLIP THE BOAR DOES NOT HAVE HAS NO BOAR KEY TO COLLIDE WITH, which is the
					-- leap (task 245b): `BOAR_CLIP_KEY.leap` is nil on purpose and there is nothing
					-- to compare it against.
					local boarKey = BOAR_CLIP_KEY[name]
					local boarRow = if boarKey ~= nil then Assets.byKey(boarKey) else nil
					if boarRow ~= nil and boarRow.modelId == row.modelId then
						table.insert(sharedWithBoar, name)
					end
				end
			end
			table.sort(missing)
			table.sort(sharedWithBoar)
			expect(table.concat(missing, ", ")).to.equal("")
			expect(table.concat(sharedWithBoar, ", ")).to.equal("")
		end)

		it("agrees with the manifest about how long each deer clip is", function()
			-- The two copies of one measurement: `clipSeconds` was read back off the published
			-- asset with `AnimationClipProvider:GetAnimationClipAsync`, `clip.seconds` is what the
			-- deer plays by. `BoarAssetsBoot` warns at boot; this fails the build, which is the
			-- half that stops it being merged. Half a frame at 24 fps is the tolerance.
			local model = CONFIG.SPECIES.reddeer.MODEL
			local worst, worstName = 0, "none"
			for name, clip in pairs(model.CLIPS) do
				local row = Assets.byKey(DEER_CLIP_KEY[name])
				expect(row.clipSeconds).to.be.ok()
				local drift = math.abs(row.clipSeconds - clip.seconds)
				if drift > worst then
					worst, worstName = drift, name
				end
			end
			TestKit.note(string.format("deer: worst clip-length drift %.4f s (%s)", worst, worstName))
			expect(worst <= 1 / 48).to.equal(true)
		end)

		it("never asks InsertService to load a deer animation", function()
			-- An animation is a number on an `Animation.AnimationId`, not an Instance you insert.
			-- A boot script handed one would spend a network load that can only fail, and delay the
			-- model that does need it -- which for the deer is its own `preload` budget.
			for _, key in ipairs(Assets.keysFor("deer")) do
				expect(Assets.byKey(key).kind).never.to.equal("animation")
			end
			expect(#Assets.keysFor("deer-animation")).to.equal(0)
		end)

		-- BOTH LOOPED STATES, ENTERED, AND NOT ONE CASE THAT HAPPENS TO BE IN FRONT OF THE WRITER
		-- (L-093). The deer's assets are the boar's case INVERTED -- only `Walk_F_IP` was published
		-- `Loop = true` -- so `looped` cannot be taken off the asset, and both arms are stated.
		it("loops the deer's gaits and plays its deaths and flinches ONCE", function()
			local clips = CONFIG.SPECIES.reddeer.MODEL.CLIPS
			local looping, once = {}, {}
			for name, clip in pairs(clips) do
				table.insert(if clip.looped then looping else once, name)
			end
			table.sort(looping)
			table.sort(once)
			-- Named on both sides, so a clip that moves from one arm to the other fails here.
			expect(table.concat(looping, ", ")).to.equal("idle, run, smell, trot, turnLeft, turnRight, walk")
			-- `leap` joined the once-only arm in task 245b: a looping bound would have a deer
			-- jumping on the spot all the way across the lane.
			expect(table.concat(once, ", ")).to.equal("deathLeft, deathRight, hitBack, hitFront, leap")
			-- A LOOPING DEATH WOULD STAND THE CARCASS BACK UP, in front of the player who just
			-- shot it; a one-shot GAIT would freeze a running deer mid-stride.
			expect(clips.deathLeft.looped).to.equal(false)
			expect(clips.deathRight.looped).to.equal(false)
			expect(clips.walk.looped).to.equal(true)
			expect(clips.run.looped).to.equal(true)
			-- `smell` LOOPS ON THE DEER AND NOT ON THE BOAR, deliberately: the calm activity runs
			-- it for exactly its own length, and a frame past the end drops a one-shot track --
			-- and the animal -- into the bind pose. The boar's row is untouched, which is the
			-- other half of this assertion.
			expect(clips.smell.looped).to.equal(true)
			expect(CONFIG.MODEL.CLIPS.smell.looped).to.equal(false)
		end)

		-- EACH KIND ENTERS ITS OWN BRANCH (L-093), because `deathLiftStuds` is per kind and a
		-- single case would prove one of three.
		it("carries a MEASURED death lift for each of the three deer kinds", function()
			local config = configWith(true)
			local measured = { stag = 0.011, hind = 0.185, calf = 1.325 }
			for kind, expected in pairs(measured) do
				-- Through `Boar.kindGeometry`, which is what the live carcass reads, so the number
				-- is asserted where it is USED and not only where it is written.
				local geometry = Boar.kindGeometry(kind, config)
				expect(geometry.kind).to.equal(kind)
				expect(geometry.deathLift).to.be.near(expected, EPSILON)
			end
			-- THE CALF'S IS THE BIG ONE and it is the whole point of the field: the three kinds
			-- play the STAG's published clips on geometry baked smaller, so the smaller the animal
			-- the further its fall overshoots. A calf with no lift is 1.32 studs under the floor.
			local stag = Boar.kindGeometry("stag", config).deathLift
			local hind = Boar.kindGeometry("hind", config).deathLift
			local calf = Boar.kindGeometry("calf", config).deathLift
			expect(calf > hind).to.equal(true)
			expect(hind > stag).to.equal(true)
			-- ...AND WITH `KINDS` OFF EVERY ANIMAL IS THE MALE-SIZED GREY BOX, lift 0, so the
			-- flag-OFF world is arithmetically untouched.
			expect(Boar.kindGeometry("calf", configWith(false)).deathLift).to.equal(0)
		end)

		-- 7 + 8. THE SPAWN MIX -------------------------------------------------------------------
		describe("the deer draw", function()
			it("draws nothing at roll 1 and always at roll 0", function()
				local config = configWith(true)
				expect(Boar.deerComposition(1.0, 0, config)).to.equal(nil)
				expect(Boar.deerComposition(0.9999, 0, config)).to.equal(nil)
				expect(Boar.deerComposition(0.0, 0, config)).to.be.ok()
				-- The dial itself: 0.2 is one release in five.
				expect(CONFIG.SPECIES.reddeer.RELEASE.CHANCE_PER_RELEASE).to.be.near(0.2, EPSILON)
				expect(Boar.deerComposition(0.1999, 0, config)).to.be.ok()
				expect(Boar.deerComposition(0.2, 0, config)).to.equal(nil)
			end)

			it("draws each of the three compositions at its own weight boundary", function()
				local config = configWith(true)
				local alone = Boar.deerComposition(0, 0.0, config)
				expect(alone.stag).to.equal(1)
				expect(Boar.compositionSize(alone, config)).to.equal(1)
				local nursery = Boar.deerComposition(0, 0.5, config)
				expect(nursery.hind).to.equal(1)
				expect(nursery.calf).to.equal(1)
				expect(Boar.compositionSize(nursery, config)).to.equal(2)
				local harem = Boar.deerComposition(0, 0.9, config)
				expect(harem.stag).to.equal(1)
				expect(harem.hind).to.equal(2)
				expect(Boar.compositionSize(harem, config)).to.equal(3)
				-- `weight` IS NOT AN ANIMAL and must never be counted as one.
				expect(harem.weight).to.equal(nil)
			end)

			-- ------------------------------- THE HERDS ARE NAMED, NEVER DRAWN (task 328z)
			it("KEEPS THE HERDS OUT OF THE WEIGHTED DRAW and lets a name reach them", function()
				-- Karen, 2026-11-03: *"could be more red stags they also run in bundle like 5 8 one
				-- row"* -- and the Director's option B (`ESCALATE.md` 2026-11-05): the herds are the
				-- FOREST TEST's, and the `Match` drive releases exactly what it released before.
				-- `weight = 0` is the whole mechanism, so this case is about the zero.
				local config = configWith(true)
				local rows = config.SPECIES.reddeer.RELEASE.COMPOSITIONS
				local herds, drawable = {}, {}
				for _, row in ipairs(rows) do
					if (row.weight or 0) > 0 then
						table.insert(drawable, row)
					else
						herds[row.name] = Boar.compositionSize(row, config)
					end
				end
				-- THE DRAWABLE ROWS ARE THE DRIVE'S, and none of them is bigger than three animals:
				-- that is what makes `Match.CONFIG.MAX_ALIVE_BOARS` mean what it says.
				expect(#drawable).to.equal(3)
				for _, row in ipairs(drawable) do
					expect(Boar.compositionSize(row, config) <= 3).to.equal(true)
				end
				-- THE HERDS ARE FIVE TO EIGHT, which is Karen's own range read as the four Isle of
				-- Rum medians (docs/research/2026-11-05-red-deer-herds.md).
				expect(herds.hindherd).to.equal(5)
				expect(herds.stags).to.equal(6)
				expect(herds.herd).to.equal(7)
				expect(herds.bigherd).to.equal(8)
				-- NO `pick` REACHES ONE. The walk is over [0, 1) and the herds carry no weight, so
				-- 1001 picks across the whole interval answer a drawable row every time.
				for i = 0, 1000 do
					local drawn = Boar.deerComposition(0, i / 1000, config)
					expect(drawn).to.be.ok()
					expect(Boar.compositionSize(drawn, config) <= 3).to.equal(true)
				end
				-- ...AND A NAME REACHES EVERY ONE OF THEM, which is how the Forest Test's script
				-- asks (`ForestTest.SCHEDULE.drive[n].party`).
				for name, size in pairs(herds) do
					local party = Boar.deerComposition(0, 0, config, name)
					expect(party).to.be.ok()
					expect(Boar.compositionSize(party, config)).to.equal(size)
				end
				-- THE ZERO IS LOAD-BEARING, and this is the arm that proves it: give `bigherd` a
				-- weight in a clone and the same walk reaches it at the top of the interval. Delete
				-- the `weight = 0` and the loop above fails, which is the point.
				local weighted = configWith(true)
				weighted.SPECIES = table.clone(weighted.SPECIES)
				weighted.SPECIES.reddeer = table.clone(weighted.SPECIES.reddeer)
				weighted.SPECIES.reddeer.RELEASE = table.clone(weighted.SPECIES.reddeer.RELEASE)
				local copy = {}
				for _, row in ipairs(rows) do
					local one = table.clone(row)
					if one.name == "bigherd" then
						one.weight = 1000
					end
					table.insert(copy, one)
				end
				weighted.SPECIES.reddeer.RELEASE.COMPOSITIONS = copy
				local big = Boar.deerComposition(0, 0.999, weighted)
				expect(Boar.compositionSize(big, weighted)).to.equal(8)
			end)

			it("turns a named composition into that composition's own kinds", function()
				local config = configWith(true)
				local kinds = Boar.sounderKinds(3, {}, config, { stag = 1, hind = 2 })
				expect(#kinds).to.equal(3)
				table.sort(kinds)
				expect(kinds[1]).to.equal("hind")
				expect(kinds[2]).to.equal("hind")
				expect(kinds[3]).to.equal("stag")
				-- The boar's own three words are untouched and still mean what they meant.
				local sounder = Boar.sounderKinds(3, {}, config, { females = 1, cubs = 2 })
				expect(sounder[1]).to.equal(config.SOUNDER.MAKEUP.SOW)
				expect(sounder[2]).to.equal(config.SOUNDER.MAKEUP.YOUNG)
			end)

			it("draws NOTHING, and no number, with BOAR_MODEL off", function()
				-- The gate is in FRONT of the roll, so the runtime's `Random` stream is bit-for-bit
				-- the one every existing spec was written against in the flag-off world.
				expect(Boar.deerComposition(0, 0, configWith(false))).to.equal(nil)
			end)

			-- ------------------------------------------------ THE DRIVE ASKS FOR ONE (task 234)
			it("GIVES A GROUP WHATEVER THE ROLL when the drive asks, and still picks WHICH", function()
				-- Karen, 2026-10-21: *"we need all a time in drive deer"*. `CHANCE_PER_RELEASE` is
				-- 0.2 and 0.8^6 = 26 % of drives carried none; the schedule now names one release.
				--
				-- THE ASK SKIPS THE CHANCE AND NOTHING ELSE: `pick` still chooses the group by the
				-- same weighted walk, so WHICH deer come is still this function's own decision and
				-- `Match.Phase` never learns the vocabulary.
				local config = configWith(true)
				expect(Boar.deerComposition(1.0, 0, config)).to.equal(nil) -- the roll that refuses
				local asked = Boar.deerComposition(1.0, 0, config, true)
				expect(asked).to.be.ok()
				expect(asked.stag).to.equal(1)
				expect(Boar.deerComposition(1.0, 0.5, config, true).hind).to.equal(1)
				expect(Boar.deerComposition(1.0, 0.9, config, true).hind).to.equal(2)
				-- ...AND IT CANNOT CONJURE AN ANIMAL THAT DOES NOT EXIST. With `BOAR_MODEL` off
				-- there are no deer kinds, and an ask is refused exactly as a roll is -- which is
				-- what keeps the schedule's half of this feature free of the flag.
				expect(Boar.deerComposition(0, 0, configWith(false), true)).to.equal(nil)
				-- ...and `false` is the behaviour every caller before task 234 had.
				expect(Boar.deerComposition(1.0, 0, config, false)).to.equal(nil)
			end)

			-- ------------------------------------- ...AND MAY ASK FOR ONE BY NAME (task 251)
			it("GIVES THE PARTY THE DRIVE NAMED, and refuses a word this table does not have", function()
				-- KAREN, 2026-10-23, through the plan she OK'd: the HIND PARTY comes early in the
				-- drive and THE STAG comes last, alone. That is a fact about the drive's SHAPE, so
				-- `ForestTest.SCHEDULE.drive` has to be able to name which party it wants -- and it
				-- names the WORD, while this function stays the only thing that knows which row that
				-- is.
				local config = configWith(true)
				local stag = Boar.deerComposition(0, 0, config, "stag")
				expect(stag).to.be.ok()
				expect(stag.stag).to.equal(1)
				expect(stag.hind).to.equal(nil)
				local hinds = Boar.deerComposition(0, 0, config, "hinds")
				expect(hinds).to.be.ok()
				expect(hinds.hind).to.equal(1)
				expect(hinds.calf).to.equal(1)
				expect(hinds.stag).to.equal(nil)
				expect(Boar.deerComposition(0, 0, config, "harem").hind).to.equal(2)
				-- THE NAME BEATS THE PICK, which is the whole point: at `pick` 0.9 the weighted walk
				-- would answer the harem, and the ask answers what it asked for.
				expect(Boar.deerComposition(0, 0.9, config, "hinds").calf).to.equal(1)
				-- ...AND A NAME IT DOES NOT HAVE IS nil, not a draw and not the first row. A slot
				-- that asked for a party this table has not got is a mistake in the drive script, and
				-- "no deer, and the console says which word" is the honest answer to it.
				expect(Boar.deerComposition(0, 0, config, "roedeer")).to.equal(nil)
				expect(Boar.deerComposition(0, 0, config, "")).to.equal(nil)
				-- THE CHANCE IS SKIPPED BY A NAMED ASK TOO, even at the roll that refuses -- and even
				-- if `CHANCE_PER_RELEASE` were 0, which a drive's own scripted stag must survive.
				expect(Boar.deerComposition(1.0, 0, config, "stag")).to.be.ok()
				local noChance = configWith(true)
				noChance.SPECIES = table.clone(noChance.SPECIES)
				noChance.SPECIES.reddeer = table.clone(noChance.SPECIES.reddeer)
				noChance.SPECIES.reddeer.RELEASE = table.clone(noChance.SPECIES.reddeer.RELEASE)
				noChance.SPECIES.reddeer.RELEASE.CHANCE_PER_RELEASE = 0
				expect(Boar.deerComposition(0, 0, noChance, "stag")).to.be.ok()
				expect(Boar.deerComposition(0, 0, noChance)).to.equal(nil)
				-- ...and it still cannot conjure a kind that does not exist.
				expect(Boar.deerComposition(0, 0, configWith(false), "stag")).to.equal(nil)
				-- EVERY ROW IS NAMED, so a drive can reach all three and no row is unreachable.
				local names = {}
				for _, row in ipairs(config.SPECIES.reddeer.RELEASE.COMPOSITIONS) do
					expect(type(row.name)).to.equal("string")
					expect(names[row.name]).to.equal(nil) -- and the names are unique
					names[row.name] = true
					expect(Boar.deerComposition(0, 0, config, row.name)).to.be.ok()
				end
				-- `name` IS NOT A MEMBER OF THE GROUP, which is the one way this could have gone
				-- wrong: it is stripped exactly as `weight` is, so nothing tries to spawn a "name".
				expect(stag.name).to.equal(nil)
				expect(stag.weight).to.equal(nil)
			end)

			-- ------------------------------------------------ THEY WALK IN FILE (task 234)
			it("MARCHES A DEER GROUP IN SINGLE FILE, declared rather than drawn", function()
				-- Karen, 2026-10-21: *"we need all a time in drive deer and could be also lines and
				-- how they behav"*, and "yes" to deer walking one after another in a row.
				--
				-- `"column"` IS THE FORMATION THIS GAME ALREADY HAD (task 118): a leader,
				-- `Boar.marchOrder` behind him, slots at `(0, 0, (i-1) * COLUMN_SPACING_STUDS)`.
				-- Nothing here is a second movement writer -- the group simply declares what a
				-- boar sounder draws.
				local config = configWith(true)
				expect(config.SPECIES.reddeer.RELEASE.FORMATION).to.equal("column")
				for _, shape in ipairs(config.SPECIES.reddeer.RELEASE.COMPOSITIONS) do
					expect(Boar.compositionFormation(shape, config)).to.equal("column")
				end
				-- A BOAR COMPOSITION HAS NO OPINION, so a boar sounder still draws between the
				-- wedge and the column at `COLUMN_CHANCE` -- unchanged, which is the whole of
				-- "no boar behaviour moved".
				expect(Boar.compositionFormation({ females = 2, cubs = 3 }, config)).to.equal(nil)
				expect(Boar.compositionFormation({ males = 1 }, config)).to.equal(nil)
				-- ...AND A MIXED GROUP HAS NO ONE ANSWER, so it gets none rather than one of them.
				expect(Boar.compositionFormation({ stag = 1, male = 1 }, config)).to.equal(nil)
				-- `weight` IS NOT AN ANIMAL: a `COMPOSITIONS` row carries its draw weight beside
				-- its counts, and reading it as a kind would answer nil for every real row.
				expect(Boar.compositionFormation({ weight = 40, stag = 1 }, config)).to.equal("column")
				-- With `BOAR_MODEL` off there are no kinds, so nothing declares anything.
				expect(Boar.compositionFormation({ stag = 1 }, configWith(false))).to.equal(nil)
				expect(Boar.compositionFormation(nil, config)).to.equal(nil)
			end)

			it("SPACES THE FILE wider than the longest deer in it", function()
				-- The Director asked for "each follower on the leader's trail at a MEASURED
				-- spacing". The three deer were measured at the prep (`KINDS`), and this is the
				-- check that says 9 studs is the right gap for them rather than a number reused
				-- from the boar because it was there. TO SEE IT FAIL: drop
				-- `SOUNDER.COLUMN_SPACING_STUDS` to 6 -- a stag is 7.05 studs long and the file
				-- becomes a stag standing inside the hind in front of him.
				local config = configWith(true)
				local gap = config.SOUNDER.COLUMN_SPACING_STUDS
				local longest, which = 0, ""
				for _, kind in ipairs({ "stag", "hind", "calf" }) do
					local length = Boar.kindGeometry(kind, Boar.kindConfig(kind, config)).bodySize.Z
					if length > longest then
						longest, which = length, kind
					end
				end
				TestKit.note(
					string.format("task234 deer file: %.2f stud slots, longest deer %s at %.2f", gap, which, longest)
				)
				expect(longest > 0).to.equal(true)
				expect(gap > longest).to.equal(true)
			end)

			it("refuses a second deer group while one is alive, and counts GROUPS", function()
				local config = configWith(true)
				expect(Boar.deerGroupsAllowed({}, config)).to.equal(true)
				expect(Boar.deerGroupsAllowed({ "male", "female", "cub" }, config)).to.equal(true)
				expect(Boar.deerGroupsAllowed({ "male", "hind" }, config)).to.equal(false)
				expect(Boar.deerGroupsAllowed({ "stag" }, config)).to.equal(false)
				-- ROUND 1 DID NOT COUNT ANYTHING (Reviewer's note): it answered
				-- `MAX_GROUPS_ALIVE > 1` on the FIRST live deer, so the dial worked only at 1 and at
				-- 2 it capped nothing at all. Three members of ONE release share a sounder id and
				-- are ONE group, so at a cap of 2 they still leave room for a second.
				local two = configWith(true)
				two.SPECIES = table.clone(Boar.CONFIG.SPECIES)
				two.SPECIES.reddeer = table.clone(Boar.CONFIG.SPECIES.reddeer)
				two.SPECIES.reddeer.RELEASE = table.clone(Boar.CONFIG.SPECIES.reddeer.RELEASE)
				two.SPECIES.reddeer.RELEASE.MAX_GROUPS_ALIVE = 2
				local oneHerd = {
					{ kind = "stag", sounder = "S1" },
					{ kind = "hind", sounder = "S1" },
					{ kind = "hind", sounder = "S1" },
				}
				expect(Boar.deerGroupsAllowed(oneHerd, two)).to.equal(true)
				local twoHerds = {
					{ kind = "stag", sounder = "S1" },
					{ kind = "hind", sounder = "S2" },
				}
				expect(Boar.deerGroupsAllowed(twoHerds, two)).to.equal(false)
				-- ...and at the shipped cap of 1 that same single herd already fills it.
				expect(Boar.deerGroupsAllowed(oneHerd, config)).to.equal(false)
			end)

			-- --------------------------------- THE SAME CAP, ASKED FROM OUTSIDE (task 239)
			--
			-- THE FOREST TEST NEVER REACHES `spawnSounder`. Its drive releases a wave as a FILE:
			-- `Runtime:spawn` one animal at a time, then `Runtime:formSounder` -- so the deer door
			-- inside `spawnSounder`, and the cap it consults, are not on that path at all. The
			-- forest therefore asks `Runtime:deerAllowed`, and this case is what says that is the
			-- SAME answer and not a second one: a live runtime with a real deer group out, checked
			-- against the pure rule over the same animals.
			it("answers the live cap through one door, for a caller that never spawns a sounder", function()
				local holder = Instance.new("Folder")
				holder.Name = "DeerAllowedSpec"
				holder.Parent = Workspace
				local runtime = Boar.newRuntime({
					field = FIELD,
					parent = holder,
					folderName = "Allowed",
					config = { KINDS = { ENABLED = true }, maxBoars = 12 },
					threats = function()
						return {}
					end,
					probe = function()
						return false
					end,
					requestPath = function(_id, _from, _to, done)
						done(nil)
					end,
					releasePath = function() end,
				})
				-- An empty world allows one.
				expect(runtime:deerAllowed()).to.equal(true)
				-- A BOAR IS NOT A DEER: the cap is the deer's and nothing else fills it.
				runtime:spawn(Vector3.new(0, FIELD.groundY, 0), "male")
				runtime:spawn(Vector3.new(6, FIELD.groundY, 0), "female")
				expect(runtime:deerAllowed()).to.equal(true)
				-- ...and one hind does, at `MAX_GROUPS_ALIVE` of 1.
				local hind = runtime:spawn(Vector3.new(12, FIELD.groundY, 0), "hind")
				expect(hind).to.be.ok()
				expect(runtime:deerAllowed()).to.equal(false)
				-- IT DRAWS NO NUMBER, which is what lets the forest ask it before deciding
				-- anything: the same question twice is the same answer twice.
				expect(runtime:deerAllowed()).to.equal(false)
				-- ...AND IT IS THE PURE RULE, not a second count. `Boar.deerGroupsAllowed` over
				-- the same three animals must agree, which is the whole claim.
				local live = {
					{ kind = "male", sounder = nil },
					{ kind = "female", sounder = nil },
					{ kind = "hind", sounder = nil },
				}
				expect(Boar.deerGroupsAllowed(live, configWith(true))).to.equal(false)
				-- ...AND THE STAG COMES ANYWAY, BECAUSE HE MOVES ALONE (task 253). **THE DIRECTOR'S
				-- DECISION, 2026-10-24**: *"if MAX_GROUPS_ALIVE slips him, let the stag (only) be
				-- released even if one other group is alive"*. MEASURED the night before -- the hind
				-- party was still on its feet at his slot, so the drive held him over to its next
				-- silence and he came out 26 s late, against an arithmetic written for his slot.
				expect(runtime:deerAllowed("stag")).to.equal(true)
				expect(Boar.deerGroupsAllowed(live, configWith(true), "stag")).to.equal(true)
				-- IT IS "A PARTY OF ONE" AND NOT "THE STAG": the hind party weighs two, so it is
				-- still refused while a group is out, and a drive cannot have two herds.
				expect(runtime:deerAllowed("hinds")).to.equal(false)
				expect(Boar.deerGroupsAllowed(live, configWith(true), "hinds")).to.equal(false)
				-- AND THE EXEMPTION IS ONE GROUP DEEP, not a bypass: with the stag out as well, the
				-- next stag is refused too.
				local stagOut = {
					{ kind = "hind", sounder = nil },
					{ kind = "stag", sounder = nil },
				}
				expect(Boar.deerGroupsAllowed(stagOut, configWith(true), "stag")).to.equal(false)
				-- A PARTY NOBODY NAMED is the answer every caller got before this task.
				expect(Boar.deerGroupsAllowed(live, configWith(true), nil)).to.equal(false)
				runtime:destroy()
				holder:Destroy()
			end)

			-- WHICH KINDS ARE DEER, ASKED ONCE (task 253) ---------------------------------------
			--
			-- The drive asks it on every tick of the beater line, to decide whether an animal the
			-- line has reached bolts or slips away, and three callers were about to inline
			-- `KINDS[kind].species == "reddeer"`.
			it("knows a deer kind from a boar kind, and knows none at all with the flag off", function()
				local config = configWith(true)
				expect(Boar.isDeerKind("stag", config)).to.equal(true)
				expect(Boar.isDeerKind("hind", config)).to.equal(true)
				expect(Boar.isDeerKind("calf", config)).to.equal(true)
				expect(Boar.isDeerKind("male", config)).to.equal(false)
				expect(Boar.isDeerKind("female", config)).to.equal(false)
				expect(Boar.isDeerKind("cub", config)).to.equal(false)
				-- AN UNKNOWN WORD AND NO WORD ARE BOTH "not a deer", which is the safe answer: the
				-- caller's fallback is the behaviour every animal had before this task.
				expect(Boar.isDeerKind("elephant", config)).to.equal(false)
				expect(Boar.isDeerKind(nil, config)).to.equal(false)
				-- WITH `KINDS` OFF THERE ARE NO KINDS, so there is no deer -- the same first line
				-- `deerGroupsAllowed` takes, and the default build has one animal and it is a boar.
				expect(Boar.isDeerKind("stag", configWith(false))).to.equal(false)
			end)

			-- FINDING 1. THE FLAG-OFF STREAM, COUNTED AGAINST A BASELINE ------------------------
			--
			-- ROUND 1 SHIPPED THE BUG THIS CASE EXISTS FOR. The two rolls were the ARGUMENTS to
			-- `Boar.deerComposition`, and Lua evaluates arguments before it enters a function, so
			-- the gate INSIDE it could not stop them being drawn: the default build, where
			-- `BOAR_MODEL` is off, consumed two extra numbers on every composition-less release and
			-- every later draw -- the formation's `phase`, its `COLUMN_CHANCE` -- came out
			-- different from the values every spec written before task 223 was written against.
			--
			-- IT IS COUNTED, NOT INSPECTED. The runtime's `Random` is handed in, so a counting
			-- wrapper records exactly how many numbers one release asks for. The BASELINE is a
			-- release that cannot possibly want a deer -- a NAMED composition, which
			-- `spawnSounder` never offers the deer draw -- and the flag-off release must ask for
			-- the same count. Nothing here asserts a magic number: it asserts two runs agree.
			it("draws NOT ONE extra number with BOAR_MODEL off", function()
				local function releaseDraws(flagOn: boolean, composition): number
					local holder = Instance.new("Folder")
					holder.Name = "DeerStreamSpec"
					holder.Parent = Workspace
					local drawn = 0
					local real = Random.new(2231)
					local counting = {
						NextNumber = function(_self, ...)
							drawn += 1
							return real:NextNumber(...)
						end,
						NextInteger = function(_self, ...)
							drawn += 1
							return real:NextInteger(...)
						end,
					}
					local runtime = Boar.newRuntime({
						field = FIELD,
						parent = holder,
						folderName = "Stream",
						rng = counting :: any,
						config = { KINDS = { ENABLED = flagOn }, maxBoars = 12 },
						threats = function()
							return {}
						end,
						probe = function()
							return false
						end,
						requestPath = function(_id, _from, _to, done)
							done(nil)
						end,
						releasePath = function() end,
					})
					runtime:spawnSounder(Vector3.new(0, 10, 0), 3, 20, composition)
					runtime:destroy()
					holder:Destroy()
					return drawn
				end

				-- The baseline: a NAMED composition of three boars. `spawnSounder` never consults
				-- the deer draw when the caller named one, with the flag on or off, so this is the
				-- release that cannot want a deer in either world.
				local named = releaseDraws(false, { females = 1, cubs = 2 })
				-- The one that round 1 broke: no composition, flag OFF. Same release, same size.
				local blind = releaseDraws(false, nil)
				expect(blind).to.equal(named)
			end)
		end)

		-- 9. THE PRICES, THROUGH THE REAL SCORER -------------------------------------------------
		describe("what a red deer is worth", function()
			local function pointsFor(kind: string): number
				local board = Score.new()
				local after = Score.kill(board, { killedByUserId = 7, kind = kind, at = 0 }, nil, Match.CONFIG)
				return after.rows[7].points
			end

			it("prices the stag above a male boar and below the trophy", function()
				expect(pointsFor("stag")).to.equal(20)
				expect(pointsFor("stag") > pointsFor("male")).to.equal(true)
				expect(pointsFor("stag") < pointsFor("legendary")).to.equal(true)
			end)

			it("prices the hind exactly as the sow", function()
				expect(pointsFor("hind")).to.equal(6)
				expect(pointsFor("hind")).to.equal(pointsFor("female"))
			end)

			it("makes the CALF a penalty, through the price and through nothing else", function()
				-- THE ARM: a negative row IS the penalty (there is no second mechanism), and the
				-- kill must be a KNOWN kind -- a calf landing in `unknown` would score +6 and the
				-- rule would silently be inverted.
				expect(pointsFor("calf")).to.equal(-10)
				expect(pointsFor("calf")).to.equal(pointsFor("cub"))
				expect(pointsFor("calf") < 0).to.equal(true)
				local board = Score.new()
				local after, awards =
					Score.kill(board, { killedByUserId = 7, kind = "calf", at = 0 }, nil, Match.CONFIG)
				expect(after.rows[7].kills).to.equal(1)
				expect(awards[1].reason).to.equal("kill-calf")
			end)
		end)

		-- 12. THE SCENE'S SCALES ARE THE BAKED LENGTHS -------------------------------------------
		it("lays every kind out at its own baked length", function()
			-- The trap this catches: a deer's `KINDS.scale` is against the STAG and the scene's is
			-- against the BOAR MALE, so the two numbers for one animal are different on purpose.
			local scales = Match.CONFIG.SCENE.ANIMAL_SCALES
			local male = CONFIG.BODY_SIZE.Z
			local deerLength = CONFIG.SPECIES.reddeer.BODY_SIZE.Z
			for _, kind in ipairs(CONFIG.KINDS.ORDER) do
				local row = CONFIG.KINDS[kind]
				local baked = if row.species == "reddeer" then deerLength * row.scale else male * row.scale
				expect(scales[kind]).to.be.ok()
				expect(scales[kind] * male).to.be.near(baked, 0.01)
			end
		end)

		-- 13. THE SCREENS ------------------------------------------------------------------------
		describe("what the screens draw", function()
			it("gives each deer kind its own picture", function()
				local art = Report.CONFIG.BOAR_IMAGE
				expect(Report.boarImage("stag").id).to.equal(art.stag.id)
				expect(Report.boarImage("hind").id).to.equal(art.hind.id)
				-- The calf is the HIND's drawing, smaller -- said out loud, not hidden.
				expect(Report.boarImage("calf").id).to.equal(art.hind.id)
				expect(Report.boarImage("calf").scale).to.be.near(Report.CONFIG.CALF_SCALE, EPSILON)
				-- ...and its own row, not the piglet's, although both are 0.70 today.
				expect(Report.boarImage("cub").id).to.equal(art.female.id)
				-- An id a label can actually draw: an Open Cloud PNG upload makes a DECAL, and an
				-- ImageLabel cannot draw a decal id (task 205 lost a round to exactly that). These
				-- are the IMAGE ids those decals carry.
				for _, kind in ipairs({ "stag", "hind" }) do
					expect(string.match(art[kind].id, "^rbxassetid://%d+$")).to.be.ok()
					expect(art[kind].id).never.to.equal(art.male.id)
				end
			end)

			it("names the stag on the hit card and nothing else", function()
				expect(Report.trophyWord("stag")).to.equal("RED STAG")
				expect(Report.trophyWord("hind")).to.equal(nil)
				expect(Report.trophyWord("calf")).to.equal(nil)
				expect(Report.trophyWord("legendary")).to.equal("LEGENDARY BOAR")
			end)

			it("prints each deer kind's own word in the report's ANIMAL column", function()
				expect(Report.kindWord("stag")).to.equal("stag")
				expect(Report.kindWord("hind")).to.equal("hind")
				expect(Report.kindWord("calf")).to.equal("calf")
				-- The piglet's rename is untouched.
				expect(Report.kindWord("cub")).to.equal("piglet")
			end)
		end)

		-- 12. THE LEAP OVER THE ROAD (task 245b) -------------------------------------------------
		--
		-- KAREN, 2026-10-22: *"they usually jump when is cross road so can we do that ?"*.
		--
		-- EVERY CASE DRIVES THE FEATURE **ON BY PARAMETER** while `Flags.DEFAULTS.DEER_ROAD_LEAP`
		-- sits at false, which is what `docs/design/feature-flags.md` section 11 asks of a flagged
		-- path: *"a flagged path must be reachable by parameter as well as by flag, or its two
		-- states cannot be tested while the flag sits at one of them"*.
		describe("the leap over the road", function()
			local ROAD = {
				halfWidthStuds = 20,
				zAt = function(_: number)
					return 0
				end,
			}
			local SINE = {
				halfWidthStuds = 20,
				zAt = function(x: number)
					return 30 * math.sin(x / 70)
				end,
			}
			local ON = { ENABLED = true, SECONDS = 0.55 }
			local OFF = { ENABLED = false, SECONDS = 0.55 }
			-- WHO BOUNDS, AND IT IS ONE KIND (task 339). Karen, 2026-11-09: *"deer famale and kid
			-- doesnt jumt you need to remove that only male jump"*. Every case below that drives a
			-- bound loops over THIS and not `DEER_KINDS`, which is the list of deer that EXIST.
			local LEAPERS = { "stag" }

			it("is BORN OFF, with an owner, a birthday and an expiry inside 21 days", function()
				local row = Flags.DEFAULTS.DEER_ROAD_LEAP
				expect(row).to.be.ok()
				expect(row.default).to.equal(false)
				expect(row.owner).to.equal("ServerScriptService.Boar")
				expect(row.born).to.equal("2026-10-23 task 245b")
				expect(row.expires).to.equal("2026-11-13")
				expect(#row.why > 0).to.equal(true)
			end)

			it("reads the flag at ONE boundary and passes it inward", function()
				-- `Boar.CONFIG.MODEL.LEAP.ENABLED` is the only place in the game that asks, and with
				-- the row at its default it is false -- so the shipped game draws no leap.
				expect(CONFIG.MODEL.LEAP.ENABLED).to.equal(Flags.isOn("DEER_ROAD_LEAP"))
				expect(CONFIG.MODEL.LEAP.ENABLED).to.equal(false)
			end)

			it("knows the road band, and a world without one has none", function()
				expect(Brain.onRoad(Vector3.new(0, 0, 0), ROAD)).to.equal(true)
				expect(Brain.onRoad(Vector3.new(500, 0, 19.9), ROAD)).to.equal(true)
				expect(Brain.onRoad(Vector3.new(500, 0, -19.9), ROAD)).to.equal(true)
				expect(Brain.onRoad(Vector3.new(0, 0, 20.1), ROAD)).to.equal(false)
				expect(Brain.onRoad(Vector3.new(0, 0, -20.1), ROAD)).to.equal(false)
				-- THE WHOLE FEATURE IS INERT IN A WORLD WITH NO ROAD, which is the DEV map: nil in,
				-- false out, and `leapStarts` can then never be true.
				expect(Brain.onRoad(Vector3.new(0, 0, 0), nil)).to.equal(false)
				expect(Brain.onRoad(Vector3.new(0, 0, 0), {})).to.equal(false)
				expect(Brain.onRoad(Vector3.new(0, 0, 0), { zAt = ROAD.zAt, halfWidthStuds = 0 })).to.equal(false)
			end)

			it("FOLLOWS THE SINE, which is why the road is a function and not a number", function()
				-- At x = 70 * pi / 2 the ride is at its crest, z = +30. A constant-z band would have
				-- this animal 30 studs off the lane, and would catch one that is 30 studs off it.
				local crestX = 70 * math.pi / 2
				expect(Brain.onRoad(Vector3.new(crestX, 0, 30), SINE)).to.equal(true)
				expect(Brain.onRoad(Vector3.new(crestX, 0, 0), SINE)).to.equal(false)
				expect(Brain.onRoad(Vector3.new(0, 0, 0), SINE)).to.equal(true)
			end)

			it("leaps only when it is ON the road, ARMED, RUNNING and switched ON", function()
				local runFrom = 21
				expect(Brain.leapStarts(true, true, 28, runFrom, ON)).to.equal(true)
				-- ...and each condition removed on its own.
				expect(Brain.leapStarts(false, true, 28, runFrom, ON)).to.equal(false)
				expect(Brain.leapStarts(true, false, 28, runFrom, ON)).to.equal(false)
				expect(Brain.leapStarts(true, true, 20.9, runFrom, ON)).to.equal(false)
				expect(Brain.leapStarts(true, true, 28, runFrom, OFF)).to.equal(false)
				expect(Brain.leapStarts(true, true, 28, runFrom, nil)).to.equal(false)
				-- The edge is inclusive: an animal exactly at the band edge is running.
				expect(Brain.leapStarts(true, true, 21, runFrom, ON)).to.equal(true)
			end)

			it("draws the leap above every gait and below every reaction", function()
				local config = table.clone(CONFIG)
				config.MODEL = table.clone(CONFIG.SPECIES.reddeer.MODEL)
				config.MODEL.ANIMATION_IDS = table.clone(config.MODEL.ANIMATION_IDS)
				for name in pairs(config.MODEL.CLIPS) do
					config.MODEL.ANIMATION_IDS[name] = 20000
				end
				-- `Body.clipFor` reads `hitFor` and `deadFor` without guarding them -- every call
				-- site in the game is `stepVisual`, which always has both -- so the helper fills
				-- in the resting values rather than each case repeating them.
				local function clip(info)
					info.speed = info.speed or 28
					info.clipScale = 1
					info.hitFor = info.hitFor or 0
					info.deadFor = info.deadFor or 0
					return (Boar.clipFor(info, config))
				end
				-- A running deer on the road bounds instead of galloping.
				expect(clip({ leaping = true })).to.equal("leap")
				-- ...AND WITH NO KIND NAMED THE RATE IS 1 (task 325), which is the FALLBACK and not
				-- the game: `Body.leapPlan` answers `(0, 1, 0)` for a kind with no `APEX_STUDS` row,
				-- so a caller that does not say which animal this is draws exactly what task 245b
				-- drew. The per-kind rate a real deer gets is the case below this one.
				local name, rate =
					Boar.clipFor({ leaping = true, speed = 28, clipScale = 1, hitFor = 0, deadFor = 0 }, config)
				expect(name).to.equal("leap")
				expect(rate).to.equal(1)
				for _, kind in ipairs(LEAPERS) do
					local planned = select(2, Body.leapPlan(kind, config.MODEL.LEAP))
					local _, kindRate = Boar.clipFor({
						leaping = true,
						kind = kind,
						speed = 28,
						clipScale = 1,
						hitFor = 0,
						deadFor = 0,
					}, config)
					expect(kindRate).to.be.near(planned, 1e-9)
					expect(kindRate).never.to.equal(1)
				end
				-- ...and without the Brain's fact it gallops, which is the game as it shipped.
				expect(clip({ leaping = false })).to.equal("run")
				-- A DEATH AND A FLINCH BOTH BEAT IT: a deer shot mid-bound flinches, and one that
				-- dies mid-bound falls.
				expect(clip({ leaping = true, collapsed = true, deadFor = 0 })).to.equal("deathLeft")
				expect(clip({ leaping = true, hitFor = config.MODEL.HIT_SECONDS, speed = 0 })).to.equal("hitFront")
			end)

			it("draws NOTHING with no published leap, which is every boar", function()
				-- `Body.hasClip` is the one owner of "is there anything to play", so a world where
				-- the id is missing draws the gait it always drew -- and a BOAR has no `leap` entry
				-- in its CLIPS at all, so the branch is unreachable for one.
				expect(CONFIG.MODEL.CLIPS.leap).to.equal(nil)
				expect(Boar.hasClip("leap", CONFIG)).to.equal(false)
				local config = table.clone(CONFIG)
				config.MODEL = table.clone(CONFIG.SPECIES.reddeer.MODEL)
				config.MODEL.ANIMATION_IDS = {}
				expect(Boar.hasClip("leap", config)).to.equal(false)
				expect((Boar.clipFor({ leaping = true, speed = 28, clipScale = 1, hitFor = 0, deadFor = 0 }, config))).to.equal(
					"run"
				)
			end)

			it("has a leap clip whose length is the asset's and whose rate is never divided", function()
				local clip = CONFIG.SPECIES.reddeer.MODEL.CLIPS.leap
				expect(clip).to.be.ok()
				expect(clip.clip).to.equal("Jump_Run_IP")
				expect(clip.looped).to.equal(false)
				-- A bound is played at rate 1, so the field every gait divides by is 0 here and
				-- nothing can quietly start rating it.
				expect(clip.groundStudsPerSecond).to.equal(0)
				-- 2.0000 s, measured two ways in Play and recorded on the manifest row. What is
				-- PLAYED is t 0.458..0.808 (task 325); `LEAP.SECONDS` is the Brain's outer window,
				-- and this line checks only that the window cannot outlast the asset.
				expect(math.abs(clip.seconds - 2.0) < EPSILON).to.equal(true)
				expect(CONFIG.MODEL.LEAP.SECONDS < clip.seconds).to.equal(true)
			end)

			it("carries the measured sink for all three kinds, inside the clip", function()
				-- The sink each rig takes off the clip, pinned here so it cannot move. It is read as
				-- the floor under a bound (`Body.leapApex`), which since task 339 is the STAG's row
				-- alone; the other two stay because the measurement is of the CLIP on those rigs.
				local leap = CONFIG.MODEL.LEAP
				for _, kind in ipairs(DEER_KINDS) do
					expect(leap.LIFT_STUDS[kind] > 1).to.equal(true)
					expect(leap.LIFT_STUDS[kind] < 1.5).to.equal(true)
				end
				-- It grows as the animal gets smaller, which is the `deathLiftStuds` shape: all
				-- three play the STAG's clip and bone translations are absolute studs.
				expect(leap.LIFT_STUDS.stag < leap.LIFT_STUDS.hind).to.equal(true)
				expect(leap.LIFT_STUDS.hind < leap.LIFT_STUDS.calf).to.equal(true)
				-- The airborne window is inside the clip, and the Brain's outer bound covers the
				-- longest kind's bound (task 325).
				expect(leap.TAKEOFF_SECONDS < leap.LAND_SECONDS).to.equal(true)
				expect(leap.LAND_SECONDS < CONFIG.SPECIES.reddeer.MODEL.CLIPS.leap.seconds).to.equal(true)
			end)

			it("bounds the STAG ALONE, over his own sink, and the arc and the legs agree (339)", function()
				-- KAREN, 2026-11-09: *"deer famale and kid doesnt jumt you need to remove that only
				-- male jump"*. ONE RULE: no `APEX_STUDS` row, no bound. His arc is task 334's and
				-- task 339 does not touch it. Note: docs/research/2026-10-23-deer-road-leap.md s8.
				local leap = CONFIG.MODEL.LEAP
				local up, rate, window = Body.leapPlan("stag", leap)
				-- HE ACTUALLY LEAVES THE GROUND, and by more than the clip takes off his rig --
				-- an arc lower than the sink puts the hooves back through the road.
				expect(up > 0).to.equal(true)
				local apex = up * up / (2 * leap.GRAVITY)
				expect(apex).to.be.near(6.0, 1e-9)
				-- AT THE INSTANT THE HOOVES REACH DEEPEST, not at the apex: the two are 0.04 s
				-- apart and the apex is the later one.
				local atSink = apex * Body.leapSinkShare(leap)
				expect(atSink >= leap.LIFT_STUDS.stag + leap.CLEARANCE_STUDS - EPSILON).to.equal(true)
				-- THE LEGS ARE AIRBORNE FOR EXACTLY AS LONG AS THE BODY IS: the clip's own
				-- airborne span, played at `rate`, is the flight time 2v/g.
				local air = 2 * up / leap.GRAVITY
				expect(math.abs((leap.LAND_SECONDS - leap.TAKEOFF_SECONDS) / rate - air) < 1e-6).to.equal(true)
				expect(window > air).to.equal(true)
				-- THE BRAIN'S WINDOW COVERS IT, or the animal is dropped back into its gait in
				-- mid-air.
				expect(leap.SECONDS >= window).to.equal(true)
				-- **THIS CASE DIES IF THE HIND'S 5.132 AND THE CALF'S 3.336 COME BACK** -- the two
				-- rows task 339 deleted (`backups/task-339-hind-calf-apex.md`). No row, no arc, for
				-- them and for every boar.
				expect(leap.APEX_STUDS.hind).to.equal(nil)
				expect(leap.APEX_STUDS.calf).to.equal(nil)
				for _, kind in ipairs({ "hind", "calf", "male", "female", "cub", "legendary" }) do
					expect(Body.leapApex(kind, leap)).to.equal(0)
					expect(Body.leapAir(kind, leap)).to.equal(0)
					local kindUp, kindRate, kindWindow = Body.leapPlan(kind, leap)
					expect(kindUp).to.equal(0)
					expect(kindRate).to.equal(1)
					expect(kindWindow).to.equal(0)
				end
				-- ...AND THE GRAVITY THE ARC IS SOLVED AGAINST IS THE WORLD'S OWN.
				expect(math.abs(leap.GRAVITY - workspace.Gravity) < 0.01).to.equal(true)
			end)

			it("switches the leap OFF in a non-leaper's OWN config, in every state (task 339)", function()
				-- `Boar.leapByKind` is the gate and it is upstream of all three readers: the road
				-- crossing (`Brain.leapStarts`), the spook bound (`Brain.boundStarts`) and what
				-- `Body` draws (`intent.leaping`). **THIS CASE DIES** when that branch is deleted:
				-- a hind then triggers and plays the clip in place with no arc (the 11-01 defect).
				local lit = table.clone(CONFIG)
				local litModel = table.clone(CONFIG.MODEL)
				local litLeap = table.clone(CONFIG.MODEL.LEAP)
				litLeap.ENABLED = true
				litModel.LEAP = litLeap
				lit.MODEL = litModel
				local runFrom = CONFIG.MODEL.RUN_FROM
				local stag = Boar.kindConfig("stag", lit)
				expect(stag.MODEL.LEAP.ENABLED).to.equal(true)
				expect(Brain.leapStarts(true, true, runFrom + 7, runFrom, stag.MODEL.LEAP)).to.equal(true)
				for _, kind in ipairs({ "hind", "calf", "male", "female", "cub" }) do
					local other = Boar.kindConfig(kind, lit)
					expect(other.MODEL.LEAP.ENABLED).to.equal(false)
					expect(Brain.leapStarts(true, true, runFrom + 7, runFrom, other.MODEL.LEAP)).to.equal(false)
					expect(Brain.boundStarts(true, 0, 1, other.MODEL.LEAP)).to.equal(false)
				end
				-- AND NOTHING IS ALLOCATED IN A WORLD WHERE THE LEAP IS ALREADY OFF, which is the
				-- shipped one: every boar still gets the config table itself.
				expect(Boar.kindConfig("male", CONFIG)).to.equal(CONFIG)
			end)
			it("drives stepVisual: ONE take-off per crossing, the body really launched (task 325)", function()
				-- FAILS WHEN THE `stepVisual` BLOCKS ARE DELETED, and at main (they do not exist
				-- there). MEASURED at the first cut in her place: a stag bounded at t 44.66, landed,
				-- took two frames of the run clip and bounded AGAIN at t 45.21 off the same
				-- crossing -- the Brain holds one window for every kind (0.55 s) and the stag's own
				-- is 0.49, so a gate that asked only "is the leap clip playing" re-opened.
				--
				-- IT DRIVES THE REAL WRITER, not the pure functions: the trunk is a real `Part`, so
				-- the upward velocity this asserts is the one the game writes.
				local deer = Boar.speciesConfig("reddeer", CONFIG)
				local model = table.clone(deer.MODEL)
				-- EVERY clip gets an id and a track, so `play` can always reach the one `clipFor`
				-- asks for: a missing track leaves `handle.clip` alone, which would read as the
				-- bound never ending.
				model.ANIMATION_IDS = table.clone(deer.MODEL.ANIMATION_IDS)
				for name in pairs(model.CLIPS) do
					model.ANIMATION_IDS[name] = 1
				end
				local config = table.clone(deer)
				config.MODEL = model
				local leap = model.LEAP
				for _, kind in ipairs(LEAPERS) do
					local up, rate, window = Body.leapPlan(kind, leap)
					local plays, track = 0, nil :: any
					local function newTrack(name: string)
						local t: any = {
							Name = name,
							Length = model.CLIPS[name].seconds,
							TimePosition = 0,
							Speed = 1,
							WeightCurrent = 1,
							IsPlaying = false,
							Looped = false,
						}
						function t:Play(_fade, weight, speed)
							plays += 1
							self.IsPlaying = true
							self.WeightCurrent = weight or 1
							self.Speed = speed or 1
							self.TimePosition = 0
						end
						function t:AdjustSpeed(speed)
							self.Speed = speed
						end
						function t:Stop() end
						return t
					end
					local tracks: any = {}
					for name in pairs(model.CLIPS) do
						tracks[name] = newTrack(name)
					end
					track = tracks.leap
					local handle: any = {
						part = Instance.new("Part"),
						kind = kind,
						collapsed = false,
						toppled = false,
						reasserted = true,
						deadFor = 0,
						clip = nil,
						reholds = 0,
						tracks = tracks,
						hitFor = 0,
						hitFromBehind = false,
						clipHeldFor = 0,
						exitFor = 0,
						activityFor = 0,
						paddleFor = 0,
						warmFor = 0,
						yawRate = 0,
						rateWrites = 0,
						leapFor = 0,
						leapSpent = false,
						visual = Instance.new("Model"),
					}
					-- NOT anchored and not parented: an anchored part ignores a velocity write, and
					-- an unparented one is never stepped, so what this reads back is exactly what
					-- the code wrote.
					handle.part.AssemblyLinearVelocity = Vector3.new(7, 0, 11)
					local dt = 1 / 60
					local info = { leaping = true, speed = 40, clipScale = 1, hitFor = 0, deadFor = 0 }
					Boar.stepVisual(handle, dt, info, config)
					-- THE BODY LEAVES THE GROUND, with its planar velocity untouched.
					expect(handle.clip).to.equal("leap")
					expect(handle.part.AssemblyLinearVelocity.Y).to.be.near(up, 1e-3)
					expect(handle.part.AssemblyLinearVelocity.X).to.be.near(7, 1e-3)
					expect(handle.part.AssemblyLinearVelocity.Z).to.be.near(11, 1e-3)
					-- ...AT THE CLIP'S OWN TAKE-OFF FRAME, and at this kind's own rate.
					expect(track.TimePosition).to.be.near(leap.TAKEOFF_SECONDS, 1e-9)
					expect(track.Speed).to.be.near(rate, 1e-9)
					expect(handle.leapFor).to.be.near(window, 1e-9)
					local takeOffs = 1
					-- NOW RUN THE BRAIN'S WHOLE WINDOW OUT with `leaping` never dropping, which is
					-- exactly the state the second bound happened in.
					local elapsed = 0
					while elapsed < leap.SECONDS do
						local before = handle.part.AssemblyLinearVelocity.Y
						Boar.stepVisual(handle, dt, info, config)
						elapsed += dt
						if handle.part.AssemblyLinearVelocity.Y > before + 1 then
							takeOffs += 1
						end
					end
					expect(takeOffs).to.equal(1)
					-- ...AND THE BOUND IS OVER: latched, off the leap clip, back on the gait, with
					-- no upward velocity left to float on.
					expect(handle.leapSpent).to.equal(true)
					expect(handle.clip).never.to.equal("leap")
					expect(handle.part.AssemblyLinearVelocity.Y <= 0).to.equal(true)
					-- ...AND IT RE-ARMS ONLY WHEN THE BRAIN SAYS THE CROSSING IS OVER.
					Boar.stepVisual(
						handle,
						dt,
						{ leaping = false, speed = 28, clipScale = 1, hitFor = 0, deadFor = 0 },
						config
					)
					expect(handle.leapSpent).to.equal(false)
				end
			end)

			-- 12b. TWICE AS HIGH AND THREE TIMES AS LONG (task 334) ---------------------------
			--
			-- KAREN, 2026-11-06: *"fix deer jump only mail jumping and does twice high and 3 times
			-- longer then now"*. Note: docs/research/2026-10-23-deer-road-leap.md section 9.
			it("carries the animal forward only while it is airborne, and only when switched on", function()
				local leap = CONFIG.MODEL.LEAP
				local burstOn = table.clone(leap)
				burstOn.ENABLED = true
				local burstOff = table.clone(burstOn)
				burstOff.ENABLED = false
				-- SWITCHED ON AND AIRBORNE is the only combination that is not 1.
				expect(Brain.leapSpeedScale(true, burstOn)).to.equal(leap.SPEED_SCALE)
				-- ...AND THE NUMBER ITSELF, which `leap.SPEED_SCALE` alone cannot tell from any
				-- other value above 1 (Reviewer note, round 1). 3 / sqrt(2) is section 9.2's
				-- derivation: 2x the apex is sqrt(2) x the airtime, so 3x the length needs this.
				expect(leap.SPEED_SCALE).to.be.near(3 / math.sqrt(2), 1e-5)
				expect(Brain.leapSpeedScale(false, burstOn)).to.equal(1)
				expect(Brain.leapSpeedScale(nil, burstOn)).to.equal(1)
				expect(Brain.leapSpeedScale(true, burstOff)).to.equal(1)
				expect(Brain.leapSpeedScale(true, nil)).to.equal(1)
				-- A world that names no burst, or names one that would SLOW the animal, gets 1.
				local none = table.clone(burstOn)
				none.SPEED_SCALE = nil
				expect(Brain.leapSpeedScale(true, none)).to.equal(1)
				none.SPEED_SCALE = 0.5
				expect(Brain.leapSpeedScale(true, none)).to.equal(1)
			end)

			it("gives the leaping kind its OWN airtime through kindConfig (task 334 round 2)", function()
				-- FAILS WHEN `Boar.leapByKind` IS DROPPED FROM `Boar.kindConfig`. That call is the
				-- ONE wire between the arc (`Body.leapAir`) and the Brain's `_burstFor`: without it
				-- every live deer reads `MOVE.LEAP_AIR_SECONDS` as nil, the burst never fires, and
				-- the whole 3x length is gone with a green suite (Reviewer finding 1, round 1).
				local leap = CONFIG.MODEL.LEAP
				for _, kind in ipairs(LEAPERS) do
					local move = Boar.kindConfig(kind, CONFIG).MOVE
					expect(move).to.be.ok()
					local air = Body.leapAir(kind, leap)
					expect(air > 0).to.equal(true)
					expect(move.LEAP_AIR_SECONDS).to.be.near(air, 1e-9)
					-- ...AND IT IS SHORTER THAN THE DRAWING WINDOW, which is why it exists.
					expect(move.LEAP_AIR_SECONDS < leap.SECONDS).to.equal(true)
				end
				-- A NON-LEAPER CARRIES NO AIRTIME AT ALL, which is task 339's rule read off `MOVE`.
				for _, kind in ipairs({ "hind", "calf" }) do
					expect(Boar.kindConfig(kind, CONFIG).MOVE.LEAP_AIR_SECONDS).to.equal(nil)
				end
				-- A BOAR HAS NO `APEX_STUDS` ROW, so it gets the config back BY REFERENCE and no
				-- boar in the game carries this key at all.
				expect(Body.leapAir("male", leap)).to.equal(0)
				expect(Boar.kindConfig("male", CONFIG)).to.equal(CONFIG)
				expect(CONFIG.MOVE.LEAP_AIR_SECONDS).to.equal(nil)
				-- Nothing to solve, nothing to write: a world with no leap table answers 0.
				expect(Body.leapAir("stag", nil)).to.equal(0)
			end)

			it("is 2x the measured height and 3x the measured length for the stag, within 15 %", function()
				-- MEASURED in her place at cdc885b7, 7 stag road bounds, instrument
				-- `<runs-dir>/334-instrument.luau`, log `334-BEFORE.txt`: apex 2.905 studs,
				-- length 8.14 studs, airtime 0.340 s -- the MEANS, which is the row
				-- `docs/research/2026-10-23-deer-road-leap.md` section 9.1 already records for this
				-- same log, so the repo states one number for one measurement. THIS CASE DIES if
				-- `APEX_STUDS` or
				-- `SPEED_SCALE` goes back to what cdc885b7 shipped. It was the HIND's reading until
				-- task 339 took her bound away; the ratio is the same and the kind is the one left.
				local leap = CONFIG.MODEL.LEAP
				local BEFORE_APEX, BEFORE_LENGTH, BEFORE_AIR = 2.905, 8.14, 0.340
				-- The CONFIGURED apex this measurement came off, so the after/before comparison is
				-- made through the same instrument bias (the peak falls between frames, so the
				-- reading runs ~3.2 % under the arc it is reading).
				local BEFORE_CONFIGURED = 3.0
				local up = Body.leapPlan("stag", leap)
				local apex = up * up / (2 * leap.GRAVITY)
				local air = 2 * up / leap.GRAVITY
				local apexSeen = apex * (BEFORE_APEX / BEFORE_CONFIGURED)
				expect(apexSeen / BEFORE_APEX).to.be.near(2, 0.3)
				-- LENGTH IS THE IN-AIR HORIZONTAL SPEED TIMES THE AIRTIME, and the speed it had
				-- before is the measurement itself: 8.14 / 0.340 = 23.9 studs/s.
				local lengthSeen = (BEFORE_LENGTH / BEFORE_AIR)
					* Brain.leapSpeedScale(true, {
						ENABLED = true,
						SPEED_SCALE = leap.SPEED_SCALE,
					})
					* air
				expect(lengthSeen / BEFORE_LENGTH).to.be.near(3, 0.45)
				-- ...AND THE AIRTIME CANNOT BE CHOSEN SEPARATELY: 2x the apex IS sqrt(2) x the air.
				expect(air / BEFORE_AIR).to.be.near(math.sqrt(2), 0.1)
			end)

			it("LANDS RUNNING STRAIGHT ON: the heading cannot outrun the drawn body (task 344)", function()
				-- KAREN, 2026-11-10: *"there is bug animals go on the side after jum"*.
				-- FAILS WHEN THE `LAND_TURN_DEG` `math.min` IN `Brain:step` IS DELETED: both runs
				-- then slew at the gait's own rate and `capped` is no smaller than `free`.
				--
				-- The two runs differ in NOTHING but `MOVE.LAND_SECONDS`. The animal bounds over the
				-- road away from a driver, and on the first tick after the bound the driver is moved
				-- to the far side -- one 180-degree demand, at the instant the defect was measured.
				local function run(landSeconds: number?)
					local config = table.clone(CONFIG)
					config.SENSE = table.clone(CONFIG.SENSE)
					config.SENSE.ENABLED = true
					local model = table.clone(CONFIG.MODEL)
					model.LEAP = table.clone(CONFIG.MODEL.LEAP)
					model.LEAP.ENABLED = true
					config.MODEL = model
					config.MOVE = table.clone(CONFIG.MOVE)
					config.MOVE.LEAP_AIR_SECONDS = Body.leapAir("stag", model.LEAP)
					config.MOVE.LAND_SECONDS = landSeconds
					-- THE SIDESTEP IS OFF IN BOTH RUNS, exactly as `boar_move.spec`'s own wedge case
					-- switches it off: it rotates `_desired` by 90 degrees AFTER the slew and is
					-- deliberately not capped (a pinned animal must still step round the trunk), so
					-- leaving it on would measure that mechanism and not this one.
					config.MOVE.WEDGE_SECONDS = nil
					local field = {
						bounds = FIELD.bounds,
						exitZ = FIELD.exitZ,
						groundY = 0,
						road = {
							halfWidthStuds = 20,
							zAt = function(_x: number): number
								return 0
							end,
						},
					}
					local brain = Brain.new(config, field, Vector3.zero, Random.new(7))
					local bounded, flipped, since, worst = false, false, 0, 0
					local previous, position = nil, Vector3.zero
					for _ = 1, 900 do
						local threatZ = if flipped then -8 else 8
						local intent = brain:step(1 / 60, {
							position = position,
							velocity = Vector3.zero,
							threats = {
								{ id = "d", position = position + Vector3.new(0, 0, threatZ), kind = "driver" },
							},
							waypoints = nil,
							pathFailed = false,
							blockedAhead = false,
						})
						if intent.leaping then
							bounded = true
						elseif bounded and not flipped then
							flipped = true -- the 180-degree demand, on the first tick back on the ground
						end
						-- THE GROUND IS HELD UNTIL THE BOUND and passes afterwards, which is task
						-- 334's own harness plus the one thing this case needs: an animal whose
						-- position never changes is a WEDGED animal, and `_updateWedge`'s 90-degree
						-- sidestep is applied after the slew and is deliberately not capped.
						if flipped then
							position += intent.targetVelocity * (1 / 60)
						end
						if flipped then
							since += 1 / 60
							local facing = intent.facing
							if previous ~= nil and facing ~= nil and facing.Magnitude > 1e-6 and since <= 0.7 then
								local dot = math.clamp(previous:Dot(facing.Unit), -1, 1)
								worst = math.max(worst, math.deg(math.acos(dot)) * 60)
							end
							if facing ~= nil and facing.Magnitude > 1e-6 then
								previous = facing.Unit
							end
						end
					end
					return bounded, worst
				end
				local boundedCapped, capped = run(CONFIG.MOVE.LAND_SECONDS)
				local boundedFree, free = run(nil)
				TestKit.note(
					string.format(
						"deer 344: worst heading turn in the 0.7 s after the bound -- %.0f deg/s with the"
							.. " landing hold, %.0f deg/s without (cap %d)",
						capped,
						free,
						CONFIG.MOVE.LAND_TURN_DEG
					)
				)
				-- BOTH BOUNDED: the hold changes how it steers out of the bound, never whether it bounds.
				expect(boundedCapped).to.equal(true)
				expect(boundedFree).to.equal(true)
				-- ...AND THE SHIPPED WORLD HOLDS THE CAP, where the world without the window does not.
				-- 0.5 deg/s OF SLACK, AND IT IS ONE FLOAT ULP: the rate is ONE FRAME's angle times
				-- 60, so the rounding of a 1.5-degree `acos` comes out 60 times bigger here. Read at
				-- full precision in a DEV Play probe it is 90.0067871327 against the free run's
				-- 229.1865142121 -- the two are three orders of magnitude apart.
				expect(capped <= CONFIG.MOVE.LAND_TURN_DEG + 0.5).to.equal(true)
				expect(free > CONFIG.MOVE.LAND_TURN_DEG).to.equal(true)
			end)

			it("the burst is on the published velocity and nowhere else (task 334)", function()
				-- FAILS WHEN THE `leapSpeedScale` CALL AT `Brain:step`'s `targetVelocity` LINE IS
				-- DELETED. The two runs below differ in NOTHING but `LEAP.SPEED_SCALE`: the
				-- position is held, so both see the same observation on every tick and `_speed`
				-- evolves identically.
				local function run(scale: number)
					local config = table.clone(CONFIG)
					config.SENSE = table.clone(CONFIG.SENSE)
					config.SENSE.ENABLED = true
					local model = table.clone(CONFIG.MODEL)
					model.LEAP = table.clone(CONFIG.MODEL.LEAP)
					model.LEAP.ENABLED = true
					model.LEAP.SPEED_SCALE = scale
					config.MODEL = model
					-- THIS KIND'S OWN FLIGHT, exactly as `Boar.kindConfig` lays it on, and shorter
					-- than `LEAP.SECONDS`: that is the whole point of the second timer.
					config.MOVE = table.clone(CONFIG.MOVE)
					config.MOVE.LEAP_AIR_SECONDS = Body.leapAir("stag", model.LEAP)
					local field = {
						bounds = FIELD.bounds,
						exitZ = FIELD.exitZ,
						groundY = 0,
						road = {
							halfWidthStuds = 20,
							zAt = function(_x: number): number
								return 0
							end,
						},
					}
					local brain = Brain.new(config, field, Vector3.zero, Random.new(7))
					local leaping, flat, ticks = 0, 0, 0
					local speeds = {}
					for _ = 1, 600 do
						local intent = brain:step(1 / 60, {
							position = Vector3.zero,
							velocity = Vector3.zero,
							threats = {
								{ id = "d", position = Vector3.new(0, 0, 8), kind = "driver" },
							},
							waypoints = nil,
							pathFailed = false,
							blockedAhead = false,
						})
						local speed = intent.targetVelocity.Magnitude
						if intent.leaping then
							ticks += 1
							leaping = math.max(leaping, speed)
						else
							flat = math.max(flat, speed)
						end
						table.insert(speeds, speed)
					end
					-- A BURST TICK IS ONE PUBLISHED ABOVE EVERY GROUNDED TICK'S SPEED, counted on a
					-- second pass because the gait is still ramping on the first.
					local burst = 0
					for _, speed in ipairs(speeds) do
						if speed > flat + 1e-3 then
							burst += 1
						end
					end
					return leaping, flat, ticks, burst
				end
				local burstOn, flatOn, ticksOn, burstTicks = run(CONFIG.MODEL.LEAP.SPEED_SCALE)
				local burstOff, flatOff, ticksOff, noBurstTicks = run(1)
				-- IT BOUNDED, in both runs and for the same number of ticks: the scale changes the
				-- published velocity and nothing about WHEN the bound happens.
				expect(ticksOn > 0).to.equal(true)
				expect(ticksOn).to.equal(ticksOff)
				-- THE BURST ENDS AT TOUCHDOWN AND THE DRAWING RUNS ON (task 334's round-2 fix).
				-- MEASURED in her place when it did not: a calf was driven along the GROUND at 60
				-- studs/s for the 0.381 s its clip outlasted its 0.369 s flight, and the herd's
				-- measured speeds reached 138 studs/s. `LEAP.SECONDS` is 0.75, a hind flies 0.457.
				expect(burstTicks > 0).to.equal(true)
				expect(burstTicks < ticksOn).to.equal(true)
				expect(noBurstTicks).to.equal(0)
				-- 1e-3 AND NOT 1e-6: a `Vector3`'s components are float32, so the magnitude of the
				-- same 38 studs/s differs by ~4e-6 between two ticks with different headings.
				expect(flatOn).to.be.near(flatOff, 1e-3)
				-- WITH NO BURST a bound publishes the gait speed and nothing more...
				expect(burstOff).to.be.near(flatOff, 1e-3)
				-- ...and with it, that speed times the scale.
				expect(burstOn / burstOff).to.be.near(CONFIG.MODEL.LEAP.SPEED_SCALE, 1e-4)
			end)

			it("cannot re-arm the burst inside a bound it is already flying (task 334 round 3)", function()
				-- FAILS WITH NO GUARD AT ALL **AND WITH ROUND 2'S** (`self._leapFor <= 0` on the
				-- trigger): that one only DELAYED the refresh to the window edge, where `leaping` never
				-- drops for a tick, `Body`'s `leapSpent` stays latched, the launch never fires and the
				-- burst runs 0.46 s along the GROUND with no arc. A bound covers 45 studs across a
				-- 40-stud band, so the animal LEAVES the band mid-flight every crossing and `_leapArmed`
				-- comes back; that re-entry must buy nothing. Karen's rule: one bound per crossing.
				local TICKS = 200
				local function run(leaveAt: number?)
					local config = table.clone(CONFIG)
					config.SENSE = table.clone(CONFIG.SENSE)
					config.SENSE.ENABLED = true
					local model = table.clone(CONFIG.MODEL)
					model.LEAP = table.clone(CONFIG.MODEL.LEAP)
					model.LEAP.ENABLED = true
					config.MODEL = model
					config.MOVE = table.clone(CONFIG.MOVE)
					config.MOVE.LEAP_AIR_SECONDS = Body.leapAir("stag", model.LEAP)
					local away = false
					local field = {
						bounds = FIELD.bounds,
						exitZ = FIELD.exitZ,
						groundY = 0,
						-- THE ROAD MOVES, not the animal: the observation the Brain is handed is
						-- then identical tick for tick in every run, and the ONE thing that differs
						-- is whether it is on the road.
						road = {
							halfWidthStuds = 20,
							zAt = function(_x: number): number
								return if away then 400 else 0
							end,
						},
					}
					local brain = Brain.new(config, field, Vector3.zero, Random.new(7))
					local speeds, flying, flat = {}, {}, 0
					for tick = 1, TICKS do
						away = leaveAt ~= nil and tick >= leaveAt and tick < leaveAt + 2
						local intent = brain:step(1 / 60, {
							position = Vector3.zero,
							velocity = Vector3.zero,
							threats = {
								{ id = "d", position = Vector3.new(0, 0, 8), kind = "driver" },
							},
							waypoints = nil,
							pathFailed = false,
							blockedAhead = false,
						})
						local speed = intent.targetVelocity.Magnitude
						if not intent.leaping then
							flat = math.max(flat, speed)
						end
						table.insert(speeds, speed)
						table.insert(flying, intent.leaping == true)
					end
					-- EVERY BURST RUN AND NOT JUST THE FIRST (Reviewer finding 2, round 2): the
					-- refresh round 2 left behind lands ~17 ticks AFTER the first burst ended, so a
					-- metric that stops at the first contiguous run is blind to exactly the defect.
					local bursts = {}
					for index, speed in ipairs(speeds) do
						if speed > flat + 1e-3 then
							local last = bursts[#bursts]
							if last ~= nil and last.to == index - 1 then
								last.to = index
							else
								table.insert(bursts, { from = index, to = index })
							end
						end
					end
					return bursts, flying
				end
				-- ONE BURST, THE HIND'S OWN FLIGHT: 0.457 s against the 0.75 s drawing window.
				local bursts = run(nil)
				expect(#bursts).to.equal(1)
				local air = Body.leapAir("stag", CONFIG.MODEL.LEAP)
				local held = bursts[1].to - bursts[1].from + 1
				expect(held).to.be.near(air * 60, 2)
				local startedAt = bursts[1].from
				-- A RE-ENTRY ANYWHERE INSIDE THE FLIGHT BUYS NOTHING. `window - 2` is the last offset
				-- whose two off-band ticks both fall inside the window, so the animal is back on the
				-- band on the very tick `_leapFor` reaches 0 -- the edge round 2's guard left open.
				local window = math.floor(CONFIG.MODEL.LEAP.SECONDS * 60)
				for offset = 2, window - 2 do
					local each, flying = run(startedAt + offset)
					expect(#each).to.equal(1)
					expect(each[1].to - each[1].from + 1).to.equal(held)
					-- ...and the one burst there is is the take-off's own: the tick before it, the
					-- animal was NOT already flying. This is `_burstFor` is never set while
					-- `intent.leaping` has stayed true since the previous tick, which is the exact
					-- condition under which `Body` cannot launch the bound it is handed.
					expect(flying[each[1].from - 1]).to.equal(false)
				end
			end)

			it("starts the bound at the clip's own take-off frame (task 325)", function()
				local leap = CONFIG.MODEL.LEAP
				expect(Body.leapStartAt(leap)).to.equal(leap.TAKEOFF_SECONDS)
				-- Nothing to start, nothing to play: a world with no leap table answers 0 and 1.
				expect(Body.leapStartAt(nil)).to.equal(0)
				local up, rate, window = Body.leapPlan("stag", nil)
				expect(up).to.equal(0)
				expect(rate).to.equal(1)
				expect(window).to.equal(0)
			end)

			it("gives the Forest Test's field a road that IS ForestTest.roadZ", function()
				local field = ForestTest.fieldFor()
				expect(field.road).to.be.ok()
				expect(field.road.halfWidthStuds).to.equal(ForestTest.SHAPE.halfWidthStuds)
				-- Not "a road exists" -- the SAME curve the map is built on, at four points across
				-- it, so a second answer to where the lane runs cannot appear.
				for _, x in ipairs({ -400, 0, 137, 2800 }) do
					expect(math.abs(field.road.zAt(x) - ForestTest.roadZ(x)) < EPSILON).to.equal(true)
				end
				-- ...and the animal's owner agrees that a point on it is on it.
				local onIt = Vector3.new(137, 0, ForestTest.roadZ(137))
				expect(Brain.onRoad(onIt, field.road)).to.equal(true)
				expect(Brain.onRoad(onIt + Vector3.new(0, 0, 25), field.road)).to.equal(false)
			end)
		end)
	end)

	-- ------------------------------------------- THE RED STAG'S OWN BEHAVIOUR (task 251 part 2)
	--
	-- KAREN, 2026-10-23, verbatim: *"we need better saound and behaviour for red stag"*, and her "ok"
	-- to the plan (`<runs-dir>/design/driveflow-spec.md` sections 3 and 4). Four things, and every one
	-- of them is a NUMBER ON A KIND ROW composed through `Boar.kindConfig`: he notices at 1.8, he
	-- checks the open at 0.90 for 2-6 s, he looks 150 degrees back at the man while he does it, and he
	-- barks once when he takes the check. The fifth -- the bound -- is dark by instruction.
	--
	-- EVERY CASE IS PURE AND EVERY ONE OF THEM ENTERS AN ARM THAT DID NOT EXIST BEFORE THIS TASK
	-- (L-093), which here means something specific: `Brain:check` reads ONE table, `self._config.MOVE`,
	-- so the per-kind difference has to arrive THERE -- and a case that only asserted the KINDS rows
	-- would pass with `edgeByKind` never called. So the composed config is what is asked.
	describe("the red stag's own behaviour (task 251 part 2)", function()
		it("notices a walking man at 108 studs, which is the hind's own radius and not a boar's", function()
			-- SPEC SECTION 3.1: 1.5 -> 1.8, *"a lone stag has no jumpy companion to trigger him, so he
			-- must be his own alarm"*. Asserted as the RADIUS and not only as the multiplier, because
			-- the multiplier is not the thing Karen sees.
			expect(CONFIG.KINDS.stag.wary.noticeScale).to.equal(1.8)
			expect(CONFIG.KINDS.stag.wary.noticeScale).to.equal(CONFIG.KINDS.hind.wary.noticeScale)
			-- SENSE IS TURNED ON BY PARAMETER rather than read off the live flag, which is this
			-- file's own discipline: `Brain.noticeRadius` answers `DETECT_RADIUS` for everything with
			-- `SENSE` off, so a case that happened to run in a flag-off world would assert the wrong
			-- number and pass.
			local on = configWith(true)
			on.SENSE = table.clone(on.SENSE)
			on.SENSE.ENABLED = true
			local stag = Boar.kindConfig("stag", on)
			local male = Boar.kindConfig("male", on)
			local walking = { id = "p", position = Vector3.new(0, 0, 0), kind = "driver", speed = 5 }
			expect(math.abs(Brain.noticeRadius(walking, stag) - 108) < 1e-6).to.equal(true)
			expect(math.abs(Brain.noticeRadius(walking, male) - 60) < 1e-6).to.equal(true)
			TestKit.note(
				string.format(
					"a walking man is noticed at %.0f studs by a stag, %.0f by a hind and %.0f by a boar",
					Brain.noticeRadius(walking, stag),
					Brain.noticeRadius(walking, Boar.kindConfig("hind", on)),
					Brain.noticeRadius(walking, male)
				)
			)
		end)

		it("checks the open likelier and longer than his hinds, and they both longer than a boar", function()
			-- SPEC SECTION 3.1, the two rows: *"a red deer reconnoitres the open; a boar marches
			-- through"* for the chance, and *"long enough that a hunter can mount the rifle"* for the
			-- length. THE COMPOSED CONFIG IS WHAT IS ASKED, because that is what `Brain:check` reads.
			local on = configWith(true)
			local stag = Boar.kindConfig("stag", on).MOVE
			local hind = Boar.kindConfig("hind", on).MOVE
			local calf = Boar.kindConfig("calf", on).MOVE
			local male = Boar.kindConfig("male", on).MOVE
			expect(stag.EDGE_CHANCE).to.equal(0.90)
			expect(hind.EDGE_CHANCE).to.equal(0.75)
			expect(stag.EDGE_MIN_SECONDS).to.equal(2.0)
			expect(stag.EDGE_MAX_SECONDS).to.equal(6.0)
			expect(hind.EDGE_MIN_SECONDS).to.equal(1.5)
			expect(hind.EDGE_MAX_SECONDS).to.equal(4.0)
			-- THE ORDER IS THE CLAIM, so a retune that crosses two of them fails here.
			expect(stag.EDGE_CHANCE > hind.EDGE_CHANCE).to.equal(true)
			expect(hind.EDGE_CHANCE > male.EDGE_CHANCE).to.equal(true)
			expect(stag.EDGE_MAX_SECONDS > hind.EDGE_MAX_SECONDS).to.equal(true)
			-- A BOAR IS UNTOUCHED, byte for byte: no boar kind carries an `edge` row, so
			-- `edgeByKind` hands back the config it was given BY REFERENCE.
			for _, kind in ipairs(BOAR_KINDS) do
				local composed = Boar.kindConfig(kind, on)
				expect(composed.MOVE.EDGE_CHANCE).to.equal(on.MOVE.EDGE_CHANCE)
				expect(composed.MOVE.EDGE_MIN_SECONDS).to.equal(on.MOVE.EDGE_MIN_SECONDS)
				expect(composed.MOVE.EDGE_MAX_SECONDS).to.equal(on.MOVE.EDGE_MAX_SECONDS)
				expect(composed.MOVE.EDGE_LOOK_BACK_DEG).to.equal(0)
				expect(composed.MOVE.EDGE_BARKS).to.equal(false)
			end
			-- THE CALF HAS NO ROW AT ALL and takes the defaults, which is the spec's *"follows her
			-- mother"*: she walks behind the hind and a follower is never offered the check.
			expect(CONFIG.KINDS.calf.edge).to.equal(nil)
			expect(calf.EDGE_CHANCE).to.equal(male.EDGE_CHANCE)
		end)

		it("lays a kind's edge row over MOVE as a DELTA and never as a replacement", function()
			-- THE LESSON `speciesConfig` PAID FOR IN TASK 240, asserted rather than commented: a world
			-- that tunes a key the row does not name must keep its own number.
			local world = configWith(true)
			world.MOVE = table.clone(world.MOVE)
			world.MOVE.EDGE_CHANCE = 0.11
			world.MOVE.WEDGE_SECONDS = 9.75
			local stag = Boar.edgeByKind(world, CONFIG.KINDS.stag.edge, CONFIG.KINDS.stag.spook).MOVE
			expect(stag.EDGE_CHANCE).to.equal(0.90) -- the row names it: the row wins
			expect(stag.WEDGE_SECONDS).to.equal(9.75) -- the row does not: the world keeps it
			-- NEITHER ROW -> THE SAME TABLE, by reference, which is what makes this free for a boar.
			expect(Boar.edgeByKind(world, nil, nil)).to.equal(world)
			-- ...AND IT NEVER WRITES THROUGH to the config it was handed.
			expect(world.MOVE.EDGE_CHANCE).to.equal(0.11)
		end)

		it("looks back at the nearest man, 150 degrees and never further", function()
			-- SPEC SECTION 3.1: *"stand looking back"*, *"150 degrees to the nearest threat"* -- *"150
			-- and not 180: a stag looks over his shoulder, he does not reverse"*.
			local travel = Vector3.new(0, 0, -1) -- walking south, toward the road
			-- THE MAN BEHIND HIM: dead astern is 180 degrees away, so the look is CLAMPED to 150 and
			-- the last 30 are what he cannot turn. That is the whole of the number.
			local behind = Brain.lookBack(travel, Vector3.new(0, 0, 1), 150)
			expect(math.abs(math.deg(math.acos(math.clamp(behind:Dot(travel), -1, 1))) - 150) < 1e-3).to.equal(true)
			-- A MAN OFF TO ONE SIDE is inside the limit, so he faces him exactly.
			local side = Brain.lookBack(travel, Vector3.new(1, 0, 0), 150)
			expect(math.abs(side:Dot(Vector3.new(1, 0, 0)) - 1) < 1e-6).to.equal(true)
			-- THE Y IS IGNORED: a man up a high seat is a man in the same direction.
			local high = Brain.lookBack(travel, Vector3.new(1, 40, 0), 150)
			expect(math.abs(high:Dot(side) - 1) < 1e-6).to.equal(true)
			-- EVERY WAY OUT ANSWERS "THE WAY YOU ARE GOING", which is what every boar in the game
			-- gets and is the behaviour task 126 shipped: no man, no angle, a zero angle, a
			-- degenerate direction.
			expect(Brain.lookBack(travel, nil, 150)).to.equal(travel)
			expect(Brain.lookBack(travel, Vector3.new(0, 0, 1), 0)).to.equal(travel)
			expect(Brain.lookBack(travel, Vector3.new(0, 0, 1), nil)).to.equal(travel)
			expect(Brain.lookBack(travel, Vector3.zero, 150)).to.equal(travel)
		end)

		it("barks when he takes the check, and a calf never does", function()
			-- SPEC SECTION 4.2: the alarm bark plays *"once, at the edge-check"* -- *"the sound that
			-- tells the player he has been seen"*. `Runtime:check` is the one caller and
			-- `MOVE.EDGE_BARKS` the one switch; what is asserted here is the SWITCH and the SAMPLE,
			-- because nobody in this toolchain can hear a Sound.
			local on = configWith(true)
			expect(Boar.kindConfig("stag", on).MOVE.EDGE_BARKS).to.equal(true)
			expect(Boar.kindConfig("hind", on).MOVE.EDGE_BARKS).to.equal(true)
			expect(Boar.kindConfig("calf", on).MOVE.EDGE_BARKS).to.equal(false)
			-- IT IS ITS OWN CUE SINCE TASK 257, and that is the line this case used to deny: it
			-- said *"the animal's own `cry` row and not a new cue"*, which stopped being true when
			-- the hit cue became a real stag's distress call. One row cannot be both a bark and a
			-- cry, so `SOUND.BARK` is the cue and `VOICE.<kind>.bark` the ids.
			local voice = CONFIG.SOUND.VOICE
			expect(CONFIG.SOUND.BARK).to.be.ok()
			expect(#voice.stag.bark >= 1).to.equal(true)
			expect(#voice.hind.bark >= 1).to.equal(true)
			expect(voice.calf.bark).to.equal(nil)
			-- ...AND THE TWO KINDS THAT BARK BARK THE SAME REAL RECORDING, which is the whole of
			-- the first half of Karen's sentence (*"when near"*).
			expect(voice.stag.bark[1]).to.equal(voice.hind.bark[1])
			expect(CONFIG.SOUND.VOICE.CLIPS[voice.stag.bark[1]]).to.be.ok()
			-- ...AND IT IS BOUNDED BY THE WORLD'S VOICE RATION, so two barking deer cannot be three
			-- voices: `CROWD.MAX_SQUEALS` is what `Runtime:check` claims against.
			expect(CONFIG.SOUND.CROWD.MAX_SQUEALS >= 1).to.equal(true)
		end)

		-- THE REAL BARK AND THE REAL HIT CALL (task 257) ------------------------------------------
		--
		-- KAREN, 2026-10-24, verbatim: *"redsatg sound whn hit and when near need corection better
		-- real"*. Two cues, two CC0 field recordings, and neither is a cue on its own: the bark is
		-- 177.3483 s of a forest edge and the hit call is 34 s of a rut, so each plays ONE measured
		-- region of itself through `Sound.PlaybackRegion`.
		--
		-- WHAT CAN AND CANNOT BE ASSERTED HERE (rule 8). That the right id is chosen, that a region
		-- is one of the measured four, that nothing 177 seconds long can be played whole, that the
		-- cue is bounded by the budget the world books it for, and that a real hind really plays the
		-- cue when she really takes the edge check -- all of that is below. **Whether it sounds like
		-- a red deer is KAREN'S EARS**, and so is the level: the request carries the live
		-- `PlaybackLoudness` and `Volume` numbers, and no spec can hear either.
		describe("the real deer voice (task 257)", function()
			local function clipOf(id)
				return CONFIG.SOUND.VOICE.CLIPS[id]
			end

			it("NO BOAR PRELOADS THE 177-SECOND BARK: the default row is library breaths (task 258)", function()
				-- 257a(a). `Body.oneShotSpecs` builds `bark = sound.BARK` on EVERY animal and
				-- `Body.warmAssets` hands all of them to `ContentProvider:PreloadAsync`, so whatever
				-- is in THIS row is fetched once per animal -- including by a sounder of boars, none
				-- of which can ever reach the cue (`MOVE.EDGE_BARKS` is false for every boar kind).
				-- It used to be the real red deer recording, 177.3483 s by the `LENGTHS` table's own
				-- measurement.
				local on = configWith(true)
				local sound = CONFIG.SOUND
				local lengths = sound.VOICE.LENGTHS
				local LONG_SECONDS = 10

				-- THE ROW ITSELF carries nothing long.
				expect(#sound.BARK.ids > 0).to.equal(true)
				for _, id in ipairs(sound.BARK.ids) do
					local secs = lengths[id]
					expect(secs).to.be.ok() -- or nobody has measured what every animal is fetching
					expect(secs < LONG_SECONDS).to.equal(true)
				end

				-- ...AND THE CLAIM THAT MATTERS, through the real resolver: for every BOAR kind, the
				-- ids this cue would resolve to are all short. This is what fails if the long id goes
				-- back in the default, which is the regression the task fixed.
				for _, kind in ipairs(BOAR_KINDS) do
					local ids = Boar.voiceIds("bark", kind, sound.BARK, on)
					expect(#ids > 0).to.equal(true)
					for _, id in ipairs(ids) do
						local secs = lengths[id]
						expect(secs).to.be.ok()
						expect(secs < LONG_SECONDS).to.equal(true)
					end
				end

				-- ...AND THE TWO KINDS THAT DO BARK STILL BARK THE REAL RECORDING, so this is a
				-- preload fix and not a quiet downgrade of the thing Karen asked for.
				for _, kind in ipairs({ "stag", "hind" }) do
					local ids = Boar.voiceIds("bark", kind, sound.BARK, on)
					expect(lengths[ids[1]] > LONG_SECONDS).to.equal(true)
					expect(sound.VOICE.CLIPS[ids[1]]).to.be.ok()
				end
			end)

			it("plays ONE measured region of the real recording, over the whole roll", function()
				local on = configWith(true)
				local voice = CONFIG.SOUND.VOICE
				-- ONE ARM PER CUE AND PER KIND THAT HAS ONE (L-093): the stag's bark, his cry and
				-- his death, and the hind's bark. A case that only entered the first would not see
				-- a `CLIPS` entry missing from the other three.
				local cases = {
					{ kind = "stag", cue = "bark", spec = CONFIG.SOUND.BARK },
					{ kind = "stag", cue = "cry", spec = CONFIG.SOUND.CRY },
					{ kind = "stag", cue = "death", spec = CONFIG.SOUND.DEATH },
					{ kind = "hind", cue = "bark", spec = CONFIG.SOUND.BARK },
				}
				local seen = {}
				for _, case in ipairs(cases) do
					local ids = Boar.voiceIds(case.cue, case.kind, case.spec, on)
					local real = ids[1]
					local clip = clipOf(real)
					expect(clip).to.be.ok()
					expect(#clip.regions >= 3).to.equal(true) -- the dispatch asked for 3 to 4
					-- EVERY ROLL IN [0, 1) ANSWERS THE REAL ID AND A REGION OF ITS OWN TABLE, and
					-- the rolls are walked rather than sampled so that an off-by-one at either end
					-- of `voiceClip`'s index arithmetic is a failure and not a flake.
					local hits = {}
					for step = 0, 99 do
						local roll = step / 100
						local id, chosen = Boar.voiceClip(ids, on, roll)
						expect(id).to.equal(real)
						expect(chosen).to.be.ok()
						local found = false
						for index, region in ipairs(clip.regions) do
							if region == chosen.region then
								found, hits[index] = true, true
							end
						end
						expect(found).to.equal(true)
						expect(chosen.clip).to.equal(clip)
						-- A REGION IS INSIDE THE FILE. A `from`/`to` past the recording's own
						-- length is silence with no error, which is the quietest possible bug.
						expect(chosen.region.from >= 0).to.equal(true)
						expect(chosen.region.to <= voice.LENGTHS[real]).to.equal(true)
						expect(chosen.region.to > chosen.region.from).to.equal(true)
					end
					-- ...AND EVERY ONE OF THEM IS REACHABLE, which is what makes "picked at random
					-- per cue" true rather than "the first one, always".
					for index = 1, #clip.regions do
						expect(hits[index]).to.equal(true)
					end
					seen[case.kind .. "." .. case.cue] = #clip.regions
				end
				TestKit.note(
					string.format(
						"deer-257: stag bark %d / cry %d / death %d regions, hind bark %d",
						seen["stag.bark"],
						seen["stag.cry"],
						seen["stag.death"],
						seen["hind.bark"]
					)
				)
			end)

			it("NEVER plays a clipped id whole, and falls back to the library when the real one goes", function()
				local on = configWith(true)
				local clips = CONFIG.SOUND.VOICE.CLIPS
				-- THE REVERT PATH, DRIVEN: *"to revert a cue to the library samples, delete the
				-- real id from its `ids` list"*. This is that list with the first id deleted, and
				-- it must answer a library sample and NO region -- otherwise the sentence written
				-- in `VOICE.CLIPS` is a comment and not a behaviour.
				local full = Boar.voiceIds("cry", "stag", CONFIG.SOUND.CRY, on)
				local reverted = {}
				for index = 2, #full do
					table.insert(reverted, full[index])
				end
				expect(#reverted >= 1).to.equal(true)
				for step = 0, 99 do
					local id, chosen = Boar.voiceClip(reverted, on, step / 100)
					expect(chosen).to.equal(nil)
					expect(clips[id]).to.equal(nil)
				end
				-- ...AND 254's RULE, THE OTHER WAY ROUND: a clipped id sitting ANYWHERE in a list
				-- whose first id has no clip entry is SKIPPED, never played whole. A 177-second
				-- alarm bark out of one animal is the thing this prevents.
				local mixed = { reverted[1], full[1] }
				for step = 0, 99 do
					local id, chosen = Boar.voiceClip(mixed, on, step / 100)
					expect(id).to.equal(reverted[1])
					expect(chosen).to.equal(nil)
				end
				-- An empty list answers nothing rather than erroring, which is what `playOneShot`'s
				-- `if chosen then` relies on.
				expect(Boar.voiceClip({}, on, 0.5)).to.equal(nil)
			end)

			it("bounds every region by the cue the world books, and fades inside it", function()
				local on = configWith(true)
				local crowd = CONFIG.SOUND.CROWD
				local lines = {}
				-- ONE ARM PER CUE, and the arithmetic is the one `playOneShot` does: the clip's own
				-- pitch replaces the kind's, the region's length at that speed is how long it can
				-- sound, and the cue is the SMALLER of that and `Body.voiceCut`.
				local cases = {
					{ kind = "stag", cue = "bark", spec = CONFIG.SOUND.BARK },
					{ kind = "hind", cue = "bark", spec = CONFIG.SOUND.BARK },
					{ kind = "stag", cue = "cry", spec = CONFIG.SOUND.CRY },
					{ kind = "stag", cue = "death", spec = CONFIG.SOUND.DEATH },
				}
				for _, case in ipairs(cases) do
					local ids = Boar.voiceIds(case.cue, case.kind, case.spec, on)
					local clip = clipOf(ids[1])
					local cut = Boar.voiceCut(case.cue, case.kind, case.spec, on)
					expect(cut).to.be.ok()
					-- THE JITTER BAND, NOT THE CENTRE. `playOneShot` multiplies the clip's pitch by
					-- `+-PITCH_JITTER`, so the SLOWEST speed is the longest the region can sound --
					-- and that is the one the budget has to hold, not the nominal.
					local slowest = clip.pitch * (1 - CONFIG.SOUND.PITCH_JITTER)
					for _, region in ipairs(clip.regions) do
						local seconds = Boar.clipSeconds(region, slowest)
						local sounds = math.min(cut, seconds)
						expect(sounds < crowd.SQUEAL_SECONDS).to.equal(true)
						-- THE FADE FITS INSIDE WHAT SOUNDS, at both ends: `cutVolume` ramps up over
						-- `fadeSeconds` and down over the same, so a cue shorter than two fades
						-- would never reach its own level and a bark would be a swell.
						expect(clip.fadeSeconds * 2 < sounds).to.equal(true)
						expect(region.gain > 0).to.equal(true)
						table.insert(
							lines,
							string.format("%s.%s %.2fs g%.2f", case.kind, case.cue, sounds, region.gain)
						)
					end
				end
				-- THE DEATH IS STILL THE SHORT ONE Karen asked for, through the same `voiceCut`
				-- minimum that has held since task 120: a region cannot lengthen it.
				expect(Boar.voiceCut("death", "stag", CONFIG.SOUND.DEATH, on)).to.be.near(
					CONFIG.SOUND.DEATH.cut,
					EPSILON
				)
				TestKit.note("deer-257 cue budget: " .. table.concat(lines, " "))
			end)

			it("ramps a region in as well as out, and leaves every library cue alone", function()
				-- `Body.cutVolume(left, spec, since)`. `since` nil is every cue written before this
				-- task, and the function must be exactly what it was for those -- full level until
				-- the fade, then down in a straight line.
				local spec = { volume = 0.8, fade = 0.2 }
				expect(Boar.cutVolume(1.0, spec)).to.be.near(0.8, EPSILON)
				expect(Boar.cutVolume(0.2, spec)).to.be.near(0.8, EPSILON)
				expect(Boar.cutVolume(0.1, spec)).to.be.near(0.4, EPSILON)
				expect(Boar.cutVolume(0, spec)).to.be.near(0, EPSILON)
				-- ...AND WITH `since` IT RAMPS UP TOO, which is what stops a cut into the middle of
				-- a 44.1 kHz field recording clicking on the way IN as well as on the way out.
				expect(Boar.cutVolume(1.0, spec, 0)).to.be.near(0, EPSILON)
				expect(Boar.cutVolume(1.0, spec, 0.1)).to.be.near(0.4, EPSILON)
				expect(Boar.cutVolume(1.0, spec, 0.2)).to.be.near(0.8, EPSILON)
				expect(Boar.cutVolume(1.0, spec, 5)).to.be.near(0.8, EPSILON)
				-- BOTH RAMPS AT ONCE, multiplied rather than branched: 0.1 s in and 0.1 s left is a
				-- quarter of the level, not a half, and that is the honest answer for a cue two
				-- fades long.
				expect(Boar.cutVolume(0.1, spec, 0.1)).to.be.near(0.2, EPSILON)
				-- A row with no fade is untouched by either.
				local hard = { volume = 0.5, fade = 0 }
				expect(Boar.cutVolume(0, hard, 0)).to.be.near(0.5, EPSILON)
			end)

			-- THE LIVE HALF OF THIS IS IN `boar_shot.spec`, NOT HERE, and that is task 251 round 2's
			-- own finding carried forward: *"the producer was tested by nothing"* because this file
			-- asserted the switch and the sample while `Runtime:check`'s block could be deleted
			-- whole. `boar_shot.spec`'s "BARKS when a deer takes the edge check" case drives a real
			-- runtime with `MOVE.ENABLED` and the edge chance forced to 1 -- which is what a check
			-- needs and what a plain runtime does not give -- and since task 257 it reads the id,
			-- the region, the gain and the pitch off the animal's own Sound. Repeating it here with
			-- a coin-toss loop would be a second, flakier copy of one claim.

			it("gives the STAG the real hit call and leaves the hind and the calf their bleats", function()
				-- THE DISPATCH ASKED FOR *"the deer kinds' hit/death voice"* AND WHAT SHIPPED IS
				-- THE STAG'S, said here because a spec is where a deliberate narrowing has to be
				-- visible. `99831947794105` is a MALE RUT BELLOW (Freesound 653533, "Deer rut -
				-- Brame Cerf 02"), and the literature this whole table was built on says a hind
				-- answers with *"a louder nasal bleat, NOT DISSIMILAR TO THAT PRODUCED BY SHEEP"*
				-- and a calf with *"a softer bleat"*. Giving either of them a stag's rut call would
				-- be a regression for a kind Karen did not name -- her words are *"redsatg"*.
				local on = configWith(true)
				local voice = CONFIG.SOUND.VOICE
				local hit = voice.stag.cry[1]
				expect(voice.stag.death[1]).to.equal(hit)
				expect(clipOf(hit)).to.be.ok()
				-- THE BARK AND THE HIT CALL ARE TWO DIFFERENT RECORDINGS, which is the whole of
				-- Karen's *"whn hit and when near"*: one cue each.
				expect(voice.stag.bark[1] ~= hit).to.equal(true)
				-- ...AND NEITHER FEMALE KIND HAS IT, on either cue.
				for _, kind in ipairs({ "hind", "calf" }) do
					for _, cue in ipairs({ "cry", "death" }) do
						for _, id in ipairs(Boar.voiceIds(cue, kind, CONFIG.SOUND[string.upper(cue)], on)) do
							expect(id ~= hit).to.equal(true)
							expect(clipOf(id)).to.equal(nil) -- her bleats play whole, as they did
						end
					end
				end
				-- AND NO BOAR HAS EITHER RECORDING, on any cue: the two real deer are the deer's.
				for _, kind in ipairs(BOAR_KINDS) do
					for _, cue in ipairs({ "cry", "death", "grunt" }) do
						for _, id in ipairs(voice[kind][cue]) do
							expect(clipOf(id)).to.equal(nil)
						end
					end
				end
			end)
		end)

		it("bounds when spooked from a stand-still, and it is DARK by instruction", function()
			-- THE DIRECTOR'S DISPATCH, 2026-10-24: *"HOLD the bound when spooked until 245c (the hoof
			-- sink) is fixed, behind a flag born off"*. So the row is off and every case below drives
			-- the feature ON BY PARAMETER, which is what section 11 of the flag design asks.
			local row = Flags.DEFAULTS.STAG_BOUND_ON_SPOOK
			expect(row).to.be.ok()
			expect(row.default).to.equal(false)
			expect(row.owner).to.equal("ServerScriptService.Boar")
			expect(row.born).to.equal("2026-10-24 task 251 part 2")
			expect(row.expires).to.equal("2026-11-14")
			expect(#row.why > 0).to.equal(true)
			-- ONE BOUNDARY, AND IT IS THE STAG'S OWN KIND ROW. With the row at its default this is
			-- false, so no animal in the shipped game bounds -- and `MOVE`'s own default is false
			-- too, so a world that forgot the kind row would not bound either.
			expect(CONFIG.KINDS.stag.spook.bound).to.equal(Flags.isOn("STAG_BOUND_ON_SPOOK"))
			expect(CONFIG.KINDS.stag.spook.bound).to.equal(false)
			expect(CONFIG.MOVE.BOUND_ON_SPOOK).to.equal(false)
			local on = configWith(true)
			for _, kind in ipairs({ "male", "female", "cub", "legendary", "hind", "calf" }) do
				expect(Boar.kindConfig(kind, on).MOVE.BOUND_ON_SPOOK).to.equal(false)
			end
			-- THE RULE, each condition on its own. `ON`/`OFF` are the leap tables this block already
			-- defines for the road leap, because the bound IS that clip.
			local LEAP_ON = { ENABLED = true, SECONDS = 0.55 }
			local LEAP_OFF = { ENABLED = false, SECONDS = 0.55 }
			local from = CONFIG.MOVE.BOUND_FROM_SPEED
			expect(from).to.equal(6)
			expect(Brain.boundStarts(true, 0, from, LEAP_ON)).to.equal(true)
			expect(Brain.boundStarts(true, 4.5, from, LEAP_ON)).to.equal(true) -- a walk
			expect(Brain.boundStarts(true, 6, from, LEAP_ON)).to.equal(true) -- the edge is inclusive
			-- ...AND EVERY WAY IT DOES NOT HAPPEN.
			expect(Brain.boundStarts(true, 6.1, from, LEAP_ON)).to.equal(false) -- already trotting on
			expect(Brain.boundStarts(true, 28, from, LEAP_ON)).to.equal(false) -- *"a running stag just runs"*
			expect(Brain.boundStarts(false, 0, from, LEAP_ON)).to.equal(false) -- the kind does not bound
			expect(Brain.boundStarts(nil, 0, from, LEAP_ON)).to.equal(false)
			expect(Brain.boundStarts(true, 0, from, LEAP_OFF)).to.equal(false) -- no road leap, no bound
			expect(Brain.boundStarts(true, 0, from, nil)).to.equal(false)
			expect(Brain.boundStarts(true, 0, 0, LEAP_ON)).to.equal(false) -- no threshold, no bound
			expect(Brain.boundStarts(true, 0, from, { ENABLED = true, SECONDS = 0 })).to.equal(false)
		end)
	end)

	-- ------------------------------------------- THE STAG GETS THROUGH THE WOOD (task 249)
	--
	-- KAREN, 2026-10-23: *"I can see redtag is stucking when walking in mountain,tree ect check
	-- that"*. MEASURED in her own place first, 150 s of a real drive sampled four times a second,
	-- "stuck" being *its `Mover` is asking for movement and the body is under 0.8 studs/s*:
	-- **stag 73 of 337 samples (21.7 %)** against cub 4.2 %, female 4.2 %, calf 3.1 %, hind 2.2 %,
	-- male 0.0 %. One animal, five to ten times the rest.
	--
	-- AND THE STAG IS THE ONE ANIMAL WHOSE AVOIDANCE IS PLANNED AT A WIDTH IT HAS NOT GOT:
	-- `Boar.avoidRadius` reads `drawnWidthStuds`, and only the stag's (3.47, his ANTLERS) is wider
	-- than his collision box.
	describe("the stag in close wood (task 249)", function()
		it("plans at the antlers but is allowed through at the body", function()
			local deer = Boar.speciesConfig("stag", Boar.CONFIG)
			local wide = Boar.avoidRadius("stag", deer)
			local body = Boar.bodyAvoidRadius(deer)
			-- THE WIDE ONE IS TASK 240'S AND IS UNCHANGED: the antler span, halved, plus the
			-- clearance every animal keeps.
			expect(wide > body).to.equal(true)
			expect(
				math.abs(wide - (Boar.CONFIG.KINDS.stag.drawnWidthStuds / 2 + deer.MOVE.AVOID_CLEARANCE_STUDS)) < 1e-6
			).to.equal(true)
			-- ...AND THE NARROW ONE IS THE BOX HE ACTUALLY COLLIDES AT, under the same floor.
			expect(body >= deer.MOVE.AVOID_RADIUS_STUDS).to.equal(true)
			expect(body >= deer.BODY_SIZE.X / 2 + deer.MOVE.AVOID_CLEARANCE_STUDS).to.equal(true)
		end)

		it("changes nothing measurable for any animal but the stag", function()
			-- THE WHOLE BLAST RADIUS OF THE FIX, AS AN ASSERTION. The fallback can only ever run
			-- when `bodyAvoidRadius` is SMALLER than `avoidRadius`, and the gap is what it buys.
			--
			-- FOR EVERY BOAR KIND THE TWO ARE THE SAME NUMBER -- none of them is drawn wider than
			-- its 2.0-stud box -- so each reaches exactly the code it reached before task 249.
			for _, kind in ipairs({ "male", "female", "cub", "legendary" }) do
				local cfg = Boar.speciesConfig(kind, Boar.CONFIG)
				expect(Boar.avoidRadius(kind, cfg)).to.equal(Boar.bodyAvoidRadius(cfg))
			end
			-- THE HIND AND THE CALF ARE NOT EXACTLY EQUAL AND THAT WAS MEASURED RATHER THAN
			-- ASSUMED: the hind's drawn width is 2.01 against the deer box's 2.00, so her wide
			-- radius is 1.605 and her narrow one 1.600 -- **five thousandths of a stud**. The
			-- fallback is reachable for her in principle and can buy her nothing in practice: no
			-- corridor in any wood is 0.01 studs wide. The stag's gap is 0.735, a hundred and
			-- forty times hers, which is the whole point.
			local deer = Boar.speciesConfig("hind", Boar.CONFIG)
			local narrow = Boar.bodyAvoidRadius(deer)
			expect(Boar.avoidRadius("hind", deer) - narrow < 0.01).to.equal(true)
			expect(Boar.avoidRadius("calf", deer) <= narrow).to.equal(true)
			local stagCfg = Boar.speciesConfig("stag", Boar.CONFIG)
			expect(Boar.avoidRadius("stag", stagCfg) - Boar.bodyAvoidRadius(stagCfg) > 0.7).to.equal(true)
		end)
	end)
end
