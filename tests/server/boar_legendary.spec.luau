-- boar_legendary.spec: THE LEGENDARY BOAR (task 219) -- one rare, bigger, tougher, warier animal per
-- drive. Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- Karen, 2026-10-10: *"Legendary animals: one or a few, e.g. a legendary boar"*, and 2026-10-11:
-- *"legendary animals worth more"*. Task 160 wrote the price with no animal behind it; this is the
-- animal.
--
-- MOSTLY PURE, deliberately. Everything about WHO the animal is, HOW tough it is and WHETHER a drive
-- has one is a pure function driven with its own config -- which is the only way both flag states are
-- reachable while `BOAR_MODEL` sits at one of them, and the only way "one in four drives" is a case
-- rather than a probability somebody has to play for an hour to see. The two cases that are not pure
-- are the two that cannot be: the per-drive CAP (which is runtime state across several releases) and
-- the forcing switch's own guard.
--
-- Note: docs/research/2026-10-20-legendary-boar.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Wound = Boar.Wound
local CONFIG = Boar.CONFIG
local WOUND = CONFIG.WOUND

local EPSILON = 1e-4
local FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
}

-- THE FLAG AS A PARAMETER, which is the one permitted shape (`boar_kinds.spec`'s own helper): a
-- harness run only ever sees `BOAR_MODEL`'s DEFAULT -- `true` since task 230 -- because `test`
-- refuses to start with an override set, so the other state is reachable only like this. `chance` is the drive roll, and 0 and 1 are EXACT -- `NextNumber` returns [0, 1) --
-- so a case never depends on a draw.
local function configWith(on: boolean, chance: number?)
	local rare = table.clone(CONFIG.KINDS.LEGENDARY)
	if chance ~= nil then
		rare.CHANCE_PER_DRIVE = chance
	end
	local kinds = table.clone(CONFIG.KINDS)
	kinds.ENABLED = on
	kinds.LEGENDARY = rare
	local config = table.clone(CONFIG)
	config.KINDS = kinds
	return config
end

return function()
	describe("the legendary boar: who it is", function()
		local on = configWith(true)
		local off = configWith(false)

		it("is the male's own asset at 1.35, every box and the drawn rig", function()
			-- KAREN ASKED FOR *"clearly bigger"* AND THE BRIEF SAID ~1.3-1.4x THE MALE, measured off
			-- his bounds. 1.35 is the middle of that, and this game's rule since task 119 is "one
			-- scale, EVERY box" -- so the trunk and all four hit zones are his times 1.35 and the
			-- animal is a big target in exactly the way it looks big.
			local legend = Boar.kindGeometry("legendary", on)
			local male = Boar.kindGeometry("male", on)
			expect(math.abs(legend.scale - 1.35) < EPSILON).to.equal(true)
			expect((legend.bodySize - male.bodySize * 1.35).Magnitude < EPSILON).to.equal(true)
			for _, zone in ipairs(CONFIG.ZONES.ORDER) do
				expect((legend.zones[zone].size - male.zones[zone].size * 1.35).Magnitude < EPSILON).to.equal(true)
				expect((legend.zones[zone].offset - male.zones[zone].offset * 1.35).Magnitude < EPSILON).to.equal(true)
			end

			-- NO UPLOAD AND NO NEW ASSET ID: it asks for the MALE's template. That is what the row's
			-- `model` field is for, and `Runtime:_modelTemplate` is what reads it.
			expect(legend.model).to.equal("male")
			expect(legend.model).to.equal(male.model)

			-- AND THE DRAWN RIG IS SCALED AT RUNTIME, which is `meshScale` -- 1 for every kind whose
			-- scale is BAKED into its own upload by `tools/boar_prep.py`. MEASURED in the DEV place
			-- (`Model:ScaleTo(1.35)` moved the lowest bone -1.6264 -> -2.1957, exactly 1.3500, where
			-- `MeshPart.Size` left it at -1.6264); the derivation is in `Boar.CONFIG.KINDS`.
			expect(math.abs(legend.meshScale - 1.35) < EPSILON).to.equal(true)
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.kindGeometry(kind, on).meshScale).to.equal(1)
			end
			TestKit.note(
				string.format(
					"boar-legendary: the trophy is %.2f studs long against the male's %.2f, on his own asset",
					legend.bodySize.Z,
					male.bodySize.Z
				)
			)
		end)

		it("wears a model the composition root can actually find an asset for", function()
			-- THIS CASE EXISTS BECAUSE THE HARNESS COULD NOT SEE THE DEFECT, and the defect was the
			-- worst one in this task. `BoarAssetsBoot` asserts, at server start, that every kind has
			-- a model it can map to an asset key -- and its loop walked `pairs(KINDS)` with three
			-- names skipped by hand, so the two fields task 219 added to that table (`legendary` and
			-- the `LEGENDARY` rarity block) failed the assert, the script died before
			-- `Boar.setModelSource`, and **not one boar in the game was ever dressed.** A full
			-- 33/33 gate said nothing, because no spec runs a boot script; it was found by looking
			-- at a live server's output.
			--
			-- WHAT A SPEC *CAN* HOLD is the invariant the boot depends on, without copying its asset
			-- keys: every kind's `model` must name a kind that exists and that wears its OWN asset.
			-- A new kind whose `model` is a typo, or a chain of models pointing at each other, fails
			-- here -- in the gate -- instead of at somebody's next Play.
			local kinds = CONFIG.KINDS
			for _, kind in ipairs(kinds.ORDER) do
				local row = kinds[kind]
				expect(type(row)).to.equal("table")
				expect(type(row.model)).to.equal("string")
				local base = kinds[row.model]
				expect(base).to.be.ok() -- the model names a kind, not a string nothing answers
				expect(base.model).to.equal(row.model) -- ...and that kind wears its own: no chains
			end
			-- AND THE TROPHY'S IS THE MALE'S, which is the whole of "no upload, no new asset id".
			expect(kinds.legendary.model).to.equal("male")
			expect(kinds.male.model).to.equal("male")
			TestKit.note(
				string.format(
					"boar-legendary: %d kinds wear %s distinct model(s)",
					#kinds.ORDER,
					tostring(#(function()
						local seen, list = {}, {}
						for _, kind in ipairs(kinds.ORDER) do
							local model = kinds[kind].model
							if not seen[model] then
								seen[model] = true
								table.insert(list, model)
							end
						end
						return list
					end)())
				)
			)
		end)

		it("has a VOICE -- and so does every kind, which is the omission this task made three times", function()
			-- ROUND 2'S BLOCKING FINDING. `SOUND.VOICE` named male, female and cub; the fourth kind
			-- was added to `KINDS` and not to it, so `Body.voiceRow` answered nil and the biggest,
			-- oldest boar in the game cried, grunted and DIED on the generic samples at pitch **1.0**
			-- -- a sow's voice, higher than an ordinary male's 0.8. Against Karen's own words on that
			-- very table: *"pown should sqeen differen, male differen female different"*.
			--
			-- **THIS IS THE THIRD TIME THIS TASK SHIPPED THE SAME OMISSION**: a table keyed by kind
			-- that did not learn the fourth one. `BoarAssetsBoot`'s `pairs(KINDS)` killed the boot;
			-- `HitLog`'s `byKind` counted the trophy as an `unknown`; this one made it sound wrong.
			-- Finding the first two did not make me go looking for the rest -- so this case walks
			-- **every kind in `ORDER`** rather than naming the one that was missed, and it is the
			-- case that fails if a FIFTH kind arrives with no voice.
			local kinds = CONFIG.KINDS
			local voice = CONFIG.SOUND.VOICE
			local generic = CONFIG.SOUND.DEATH.ids
			for _, kind in ipairs(kinds.ORDER) do
				for _, cue in ipairs({ "cry", "death", "grunt" }) do
					local row = Boar.voiceRow(cue, kind, on)
					-- A ROW, NOT NIL: nil is the generic set, which is what "sounds like a sow" was.
					expect(row).to.be.ok()
					-- ...AND THE ROW ANSWERS FOR THIS CUE, which is the thing that was missing: with no
					-- row at all `voiceIds` falls through to the module-level `spec.ids` and the
					-- animal borrows the generic set. Asserted as "the row supplies the list, and
					-- `voiceIds` returns THAT list" -- identity, not contents.
					--
					-- NOT "the ids differ from the generic pair", which is what the first draft of
					-- this case asserted and which the gate refused: the male's and the cub's own
					-- `cry` ARE `SOUND.DEATH.ids` ("Pig Squeals 1 / 3"), by the config's own choice.
					-- Only their `death` and `grunt` differ. Sharing a sample deliberately is not
					-- the defect; having no row is.
					expect(type(row[cue])).to.equal("table")
					expect(#row[cue] > 0).to.equal(true)
					local ids = Boar.voiceIds(cue, kind, { ids = generic, pitch = 1 }, on)
					expect(ids).to.equal(row[cue])
				end
			end

			-- THE FALLBACK ARM, which is what makes this robust rather than one more hand-written
			-- row (L-093: a branch-adding change needs a case per arm). `Body.voiceRow` resolves a
			-- kind with no voice of its own through its `model`, exactly as `Runtime:_modelTemplate`
			-- resolves its asset key -- so ANY future kind built on the male sounds like the male
			-- instead of like a sow, without anybody remembering to add a row.
			local borrowed = table.clone(on)
			local borrowedKinds = table.clone(on.KINDS)
			borrowedKinds.ORDER = { "male", "female", "cub", "legendary", "elder" }
			borrowedKinds.elder = table.clone(on.KINDS.legendary)
			borrowedKinds.elder.name = "elder"
			borrowedKinds.elder.model = "male" -- a new kind on the male's asset, with NO voice row
			borrowed.KINDS = borrowedKinds
			expect(CONFIG.SOUND.VOICE.elder).to.equal(nil) -- there is genuinely no row for it
			local elderRow = Boar.voiceRow("death", "elder", borrowed)
			expect(elderRow).to.be.ok()
			expect(elderRow).to.equal(voice.male) -- the MALE's, through `model`
			expect(Boar.voicePitch("death", "elder", { ids = generic, pitch = 1 }, borrowed)).to.equal(voice.male.pitch)

			-- ...AND A KIND THAT IS NOT A KIND AT ALL still answers nil, so an unknown string gets
			-- the generic voice it always got rather than the male's by accident.
			expect(Boar.voiceRow("death", "wildebeest", on)).to.equal(nil)
			expect(Boar.voiceRow("death", nil, on)).to.equal(nil)
			-- ...and a cue that is not a voice is still not one (hooves, breath, the sniff).
			expect(Boar.voiceRow("step", "legendary", on)).to.equal(nil)

			-- THE TROPHY IS DEEPER THAN THE MALE, which is the one thing it should NOT borrow. 0.72
			-- against his 0.8 is a tenth lower -- audibly a bigger animal, and still clearly the same
			-- beast-like scream rather than a new sample nobody has heard.
			local legendary = Boar.voiceRow("death", "legendary", on)
			expect(legendary).to.be.ok()
			expect(legendary.pitch).to.equal(0.72)
			expect(legendary.pitch < voice.male.pitch).to.equal(true)
			expect(voice.male.pitch < voice.female.pitch).to.equal(true)
			expect(voice.female.pitch < voice.cub.pitch).to.equal(true)
			expect(Boar.voicePitch("death", "legendary", { ids = generic, pitch = 1 }, on)).to.equal(0.72)
			TestKit.note(
				string.format(
					"boar-legendary: pitches legendary %.2f < male %.2f < female %.2f < cub %.2f",
					legendary.pitch,
					voice.male.pitch,
					voice.female.pitch,
					voice.cub.pitch
				)
			)
		end)

		it("carries a coat tint, and no other animal does", function()
			-- THE COAT IS MULTIPLIED on the `SurfaceAppearance` the bought asset already carries --
			-- measured: it has exactly one, and its `Color` reads (1, 1, 1). A `MeshPart.Color` write
			-- would have been ignored, which is a no-op nobody could explain, so the tint travels
			-- with the geometry and `Body.attachVisual` writes it on that property.
			expect(Boar.kindGeometry("legendary", on).tint).to.be.ok()
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.kindGeometry(kind, on).tint).to.equal(nil)
			end
			-- IT IS A MULTIPLIER, AND IT HAS A CEILING **AND A FLOOR** (round 1, the Director's look:
			-- *"the legendary reads as a FLAT BLACK silhouette -- no fur, no detail"*). Round 1
			-- compared this value against `CONFIG.BODY_COLOR`, which is a category error -- that is
			-- the GREY BOX's albedo and this is a factor the artist's ColorMap is multiplied by -- and
			-- the comparison happily passed a value of (0.275, 0.227, 0.188) that crushed the fur to
			-- black. So the assertion is the thing a frame actually shows:
			--   * every channel BELOW 1, or the animal is not darker than the males beside it;
			--   * every channel ABOVE `FUR_FLOOR`, or the ColorMap's bristles and the pale tusks stop
			--     being visible at all and the trophy is a silhouette.
			-- 0.35 is the floor because 0.275 is what was measured as flat; it leaves the number
			-- Karen's to turn and the failure mode named.
			local FUR_FLOOR = 0.35
			local tint = Boar.kindGeometry("legendary", on).tint :: Color3
			for _, channel in ipairs({ tint.R, tint.G, tint.B }) do
				expect(channel < 1).to.equal(true)
				expect(channel > FUR_FLOOR).to.equal(true)
			end
			TestKit.note(
				string.format(
					"boar-legendary: the coat is multiplied by (%.3f, %.3f, %.3f) -- below 1 and clear of the %.2f fur floor",
					tint.R,
					tint.G,
					tint.B,
					FUR_FLOOR
				)
			)
		end)

		it("plays the male's clips at the male's stride times 1.35, inside its own rate rails", function()
			-- MEASURED IN A PLAY SESSION, on the published walk clip, with 41 samples across it: the
			-- scaled rig's `hoof_f.L` travels 2.2152 studs against the male's 1.6409 -- 1.3500, the
			-- same ratio as the bones. So a scaled model's Animator DOES scale the clip's absolute
			-- translations, `clipScale` is 1.35, and the gait bands scale with the stride.
			local bands = Boar.gaitBands(Boar.kindRow("legendary", on).clipScale, on)
			expect(math.abs(bands.scale - 1.35) < EPSILON).to.equal(true)
			expect(math.abs(bands.runFrom - CONFIG.MODEL.RUN_FROM * 1.35) < EPSILON).to.equal(true)

			-- ...AND THE CEILING DID NOT GO DOWN WITH IT. `MAX_RATE / clipScale` is only safe below
			-- 1: the worst ask is the TROT clip at the top of its own band, which is
			-- `RUN_FROM * s / (10.244 * s)` = 2.733 for EVERY s -- so at 1.35 the old formula gave
			-- 2.074 against an ask of 2.733, a third of the animal's feet sliding. This is the case
			-- that pins `math.min(scale, 1)`.
			local worstAsk = CONFIG.MODEL.RUN_FROM / CONFIG.MODEL.CLIPS.trot.groundStudsPerSecond
			expect(math.abs(bands.maxRate - CONFIG.MODEL.MAX_RATE) < 1e-9).to.equal(true)
			expect(bands.maxRate > worstAsk).to.equal(true)
			expect(CONFIG.MODEL.MAX_RATE / 1.35 < worstAsk).to.equal(true) -- what it WOULD have been

			-- EVERY SMALLER KIND IS EXACTLY AS IT WAS, which is what makes this a widening and not a
			-- change: the cub's rail is still the male's cadence in the cub's own units.
			expect(math.abs(Boar.gaitBands(1, on).maxRate - CONFIG.MODEL.MAX_RATE) < 1e-9).to.equal(true)
			expect(
				math.abs(Boar.gaitBands(CONFIG.KINDS.cub.clipScale, on).maxRate - CONFIG.MODEL.MAX_RATE / 0.4372) < 1e-3
			).to.equal(true)

			-- ...AND ITS CARCASS NEEDS NO LIFT, measured on the same rig: the death clip held at
			-- `length - HOLD_EPSILON` leaves the lowest bone +0.0030 above the box's bottom plane,
			-- against the male's own +0.0022. It IS the male's rig, so it is the male's row.
			expect(Boar.kindGeometry("legendary", on).deathLift).to.equal(0)
		end)

		it("with the FLAG off there is no fourth animal at all", function()
			-- The flag gates the whole block, so the grey-box world Milestone 1.2 shipped is
			-- untouched -- kinds, the trophy, the tint and the armour alike.
			local geometry = Boar.kindGeometry("legendary", off)
			expect((geometry.bodySize - CONFIG.BODY_SIZE).Magnitude < EPSILON).to.equal(true)
			expect(geometry.scale).to.equal(1)
			expect(geometry.meshScale).to.equal(1)
			expect(geometry.tint).to.equal(nil)
			expect(Boar.toughnessFor("legendary", off)).to.equal(nil)
			expect(Boar.wantsLegendary(0, off)).to.equal(false)
			expect(Boar.kindConfig("legendary", off)).to.equal(off) -- the identity, table and all
		end)
	end)

	describe("the legendary boar: how rare it is", function()
		local always = configWith(true, 1)
		local never = configWith(true, 0)

		it("rolls once per drive, and 0 and 1 are exact", function()
			-- `NextNumber` returns [0, 1), so `roll < 0` is never and `roll < 1` is always -- which is
			-- what lets every other case in this file be driven with no randomness.
			expect(Boar.wantsLegendary(0, always)).to.equal(true)
			expect(Boar.wantsLegendary(0.999999, always)).to.equal(true)
			expect(Boar.wantsLegendary(0, never)).to.equal(false)
			-- ...and the shipped number is the one the note argues for: one drive in four.
			expect(CONFIG.KINDS.LEGENDARY.CHANCE_PER_DRIVE).to.equal(0.25)
			expect(Boar.wantsLegendary(0.24, configWith(true))).to.equal(true)
			expect(Boar.wantsLegendary(0.26, configWith(true))).to.equal(false)
		end)

		it("NEVER promotes a yearling walking behind its mother (round 1, note 5)", function()
			-- `SOUNDER.MAKEUP.YOUNG_MALE` is ALSO "male", at `YOUNG_MALE_CHANCE` 0.25, so "the first
			-- male in the release" used to pick a YEARLING inside a sow-led sounder a quarter of the
			-- time -- a trophy three times the size of the piglets beside it, in the one group the
			-- design says it is never in. The research note claimed "a release of sows and piglets
			-- promotes NOBODY"; that was only true of a release with no yearling in it.
			expect(CONFIG.SOUNDER.MAKEUP.YOUNG_MALE).to.equal(CONFIG.SOUNDER.MAKEUP.LONE) -- the trap
			local nursery = { "female", "cub", "male", "cub" } -- a sow, her piglets, and a yearling
			local out, index = Boar.promoteLegendary(nursery, true, always)
			expect(index).to.equal(nil)
			expect(table.concat(out, ",")).to.equal("female,cub,male,cub")
			-- ...AND THE SAME ANIMALS WITHOUT THE SOW ARE A MALE GROUP, which IS the trophy's.
			local bachelors = { "male", "male" }
			local promoted, where = Boar.promoteLegendary(bachelors, true, always)
			expect(where).to.equal(1)
			expect(table.concat(promoted, ",")).to.equal("legendary,male")
		end)

		it("cannot surprise a spec that pinned the chance, which is what round 1 could", function()
			-- ROUND 1'S FLAKE, AS A CASE. The roll was `Random.new()` with no seed and no way for a
			-- world to supply one, so `boar_behaviour_live.spec` -- which releases a sounder with
			-- kinds ON and then looks each animal up in a THREE-kind table -- did arithmetic on nil
			-- whenever that run's draw promoted somebody. A green gate was one sample.
			--
			-- Both halves are held here: the chance is EXACT at 0 and 1 (so a spec needs no stream at
			-- all), and a world may hand in its own stream when it wants one.
			expect(Boar.wantsLegendary(0, never)).to.equal(false)
			expect(Boar.wantsLegendary(0.999999, never)).to.equal(false)
			expect(Boar.wantsLegendary(0, always)).to.equal(true)
			expect(Boar.wantsLegendary(0.999999, always)).to.equal(true)

			-- AND THE WORLD'S OWN STREAM IS USED WHEN IT IS GIVEN. Two runtimes, same seed, same
			-- answer -- which is what "a harness run is reproducible" means.
			local holder = Instance.new("Folder")
			holder.Name = "BoarLegendarySeedSpec"
			holder.Parent = Workspace
			local function drew(seed: number): boolean
				local runtime = Boar.newRuntime({
					field = FIELD,
					parent = holder,
					folderName = "Seed" .. tostring(seed) .. "_" .. tostring(math.random(1, 1e6)),
					rng = Random.new(219),
					legendaryRng = Random.new(seed),
					config = { KINDS = { ENABLED = true, LEGENDARY = CONFIG.KINDS.LEGENDARY }, maxBoars = 8 },
					threats = function()
						return {}
					end,
				})
				runtime:spawnSounder(Vector3.new(0, FIELD.groundY, 0), 1, nil, { males = 1 })
				local trophy = runtime:stats().legendariesSpawned > 0
				runtime:destroy()
				return trophy
			end
			for _, seed in ipairs({ 1, 2, 3, 7 }) do
				expect(drew(seed)).to.equal(drew(seed)) -- the SAME seed answers the same thing twice
			end
			holder:Destroy()
		end)

		it("promotes exactly ONE male, and nobody in a nursery", function()
			-- A LEGENDARY IS A MATURE LONE BOAR: `SOUNDER.MAKEUP.LONE` is already "male" and
			-- `COMPOSITIONS` row 6 is *"a lone big male"*. So the promotion takes the FIRST male of a
			-- MALE GROUP and no one else.
			--
			-- THIS CASE USED TO LEAD WITH A SOW (`{ "female", "cub", "male", "male", "cub" }`) and
			-- expect the third member promoted -- which is exactly the yearling-behind-its-mother
			-- that round 1's note 5 is about, written down as an expectation. The guard refuses that
			-- release now, so the herd here is the one a trophy actually comes out of.
			local herd = { "male", "cub", "male" }
			local promoted, index = Boar.promoteLegendary(herd, true, always)
			expect(index).to.equal(1)
			expect(promoted[1]).to.equal("legendary")
			-- EXACTLY ONE: the second male is still a male. "At most one per drive" starts here, in
			-- the shape of the function, rather than in a counter two code paths could disagree on.
			local count = 0
			for _, kind in ipairs(promoted) do
				if kind == "legendary" then
					count += 1
				end
			end
			expect(count).to.equal(1)
			expect(promoted[3]).to.equal("male")
			-- ...AND IT NEVER MUTATES ITS INPUT, so a caller can compare before with after.
			expect(herd[1]).to.equal("male")

			-- A RELEASE WITH A SOW IN IT PROMOTES NOBODY, and the permission is therefore NOT spent
			-- -- which is what lets the next release of the same drive carry the trophy. Her young
			-- are not the trophy whether or not one of them is a yearling male.
			local nursery, none = Boar.promoteLegendary({ "female", "cub", "cub" }, true, always)
			expect(none).to.equal(nil)
			expect(table.concat(nursery, ",")).to.equal("female,cub,cub")

			-- AND WITHOUT THE PERMISSION NOTHING HAPPENS AT ALL.
			local untouched, refused = Boar.promoteLegendary(herd, false, always)
			expect(refused).to.equal(nil)
			expect(table.concat(untouched, ",")).to.equal(table.concat(herd, ","))
		end)

		it("puts AT MOST ONE in a drive however many releases it has, and a new drive gets a new one", function()
			-- THE CAP, LIVE, because it is the one thing in this task that is runtime state rather
			-- than a pure function: four releases of a drive whose chance is 1, and exactly one
			-- animal in the world is the trophy. `clear` is the drive boundary -- `Match` calls it at
			-- every drive's end -- so the next drive rolls again and may have its own.
			-- IN WORKSPACE, because `Body.create` calls `SetNetworkOwner` and the engine refuses it
			-- on a part that is not a descendant of Workspace ("Can only call Network Ownership API
			-- on a part that is descendent of Workspace" -- what the first run of this file said).
			-- Nothing here steps, so no boar moves; the folder is destroyed at the end of the case.
			local holder = Instance.new("Folder")
			holder.Name = "BoarLegendarySpec"
			holder.Parent = Workspace
			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "Trophy",
				rng = Random.new(219),
				-- `KINDS` is merged KEY BY KEY by `newRuntime`, so `LEGENDARY` has to arrive whole or
				-- its other two fields would be lost.
				config = { KINDS = { ENABLED = true, LEGENDARY = always.KINDS.LEGENDARY }, maxBoars = 8 },
				threats = function()
					return {}
				end,
			})

			local function trophies(): number
				local found = 0
				for _, handle in ipairs(runtime:boars()) do
					if handle.kind == "legendary" then
						found += 1
					end
				end
				return found
			end

			-- FOUR LONE MALES, which is the release most likely to be the trophy AND the path that
			-- returns early -- the one this task got wrong first.
			for _ = 1, 4 do
				runtime:spawnSounder(Vector3.new(0, FIELD.groundY, 0), 1, nil, { males = 1 })
			end
			expect(#runtime:boars()).to.equal(4)
			expect(trophies()).to.equal(1)
			expect(runtime:stats().legendariesSpawned).to.equal(1)

			-- ...AND A SOUNDER RELEASE AFTERWARDS ADDS NO SECOND ONE.
			runtime:spawnSounder(Vector3.new(30, FIELD.groundY, 30), 3, nil, { males = 3 })
			expect(trophies()).to.equal(1)

			-- THE DRIVE ENDS. Everything is despawned and the permission comes back, so the next
			-- drive can have its own -- and with the chance at 1 it does.
			runtime:clear("driveOver")
			expect(#runtime:boars()).to.equal(0)
			runtime:spawnSounder(Vector3.new(0, FIELD.groundY, 0), 1, nil, { males = 1 })
			expect(trophies()).to.equal(1)
			expect(runtime:stats().legendariesSpawned).to.equal(2)
			TestKit.note(
				"boar-legendary: 4 lone releases in one drive produced exactly 1 trophy; the next drive got its own"
			)

			runtime:destroy()
			holder:Destroy()
		end)

		it("puts NONE in a drive whose roll said no", function()
			local holder = Instance.new("Folder")
			holder.Name = "BoarLegendaryNoneSpec"
			holder.Parent = Workspace
			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "NoTrophy",
				rng = Random.new(219),
				config = { KINDS = { ENABLED = true, LEGENDARY = never.KINDS.LEGENDARY }, maxBoars = 8 },
				threats = function()
					return {}
				end,
			})
			for _ = 1, 4 do
				runtime:spawnSounder(Vector3.new(0, FIELD.groundY, 0), 1, nil, { males = 1 })
			end
			for _, handle in ipairs(runtime:boars()) do
				expect(handle.kind).to.equal("male")
			end
			expect(runtime:stats().legendariesSpawned).to.equal(0)
			runtime:destroy()
			holder:Destroy()
		end)

		it("leaves the Director's forcing switch OFF, and fails the harness if it is not", function()
			-- THE GUARD THE HARNESS CANNOT GIVE US. `tools/studio_mcp.py` refuses to start while a
			-- `DHFlag_*` override is set; this switch is deliberately not one of those, so a run with
			-- it left on would silently change what every drive spawns. This case is that guard: it
			-- is inside the gate that already exists, and it says how to clear it.
			local name = CONFIG.KINDS.LEGENDARY.FORCE_ATTRIBUTE
			expect(type(name)).to.equal("string")
			local set = ServerStorage:GetAttribute(name)
			if set ~= nil then
				TestKit.note(
					string.format(
						'boar-legendary: the forcing switch is STILL SET. Clear it: ServerStorage:SetAttribute("%s", nil)',
						name
					)
				)
			end
			expect(set).to.equal(nil)
		end)
	end)

	describe("the legendary boar: harder to kill, and where", function()
		local on = configWith(true)

		it("is armoured everywhere but the vitals", function()
			-- THE DJV'S `Schild`: an old keiler carries centimetres of hardened tissue over the
			-- shoulders and flanks, and his skull and his chamber are no harder than a young boar's.
			-- So the armour is per-CLASS, and `WOUND.CLASS` is what already says which is which.
			local toughness = Boar.toughnessFor("legendary", on)
			expect(toughness).to.equal(2)
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.toughnessFor(kind, on)).to.equal(nil)
			end

			-- A VITAL ZONE TAKES FULL DAMAGE, which is the half that makes the rule Karen's
			-- *"only head/chest zones kill"* rather than "it takes four slugs anywhere".
			for _, zone in ipairs({ "head", "chest" }) do
				expect(Wound.hitClass(zone, WOUND)).to.equal("vital")
				expect(Wound.damageFor(zone, "Slug", 1, WOUND, toughness)).to.equal(
					Wound.damageFor(zone, "Slug", 1, WOUND)
				)
			end
			-- EVERYTHING ELSE IS HALVED.
			for _, zone in ipairs({ "body", "legs", "rear" }) do
				expect(Wound.hitClass(zone, WOUND) ~= "vital").to.equal(true)
				expect(Wound.damageFor(zone, "Slug", 1, WOUND, toughness)).to.equal(
					Wound.damageFor(zone, "Slug", 1, WOUND) / 2
				)
			end
			-- AND `nil` IS EVERY ANIMAL BEFORE THIS TASK: the arithmetic is untouched.
			expect(Wound.damageFor("body", "Slug", 1, WOUND, nil)).to.equal(WOUND.DAMAGE.body.Slug)
			expect(Wound.damageFor("body", "Pellet", 5, WOUND, 1)).to.equal(WOUND.DAMAGE.body.Pellet * 5)
		end)

		it("dies to the chamber or the head and shrugs off a body shot, which a male does not", function()
			-- THE WHOLE TABLE FROM THE RESEARCH NOTE, driven through `Wound.apply` rather than
			-- through `damageFor`, so it is the severity a player would actually see.
			local toughness = Boar.toughnessFor("legendary", on)
			local function shoot(zone: string, ammo: string, pellets: number, armour: number?)
				local state = Wound.new()
				local severity
				for _ = 1, pellets do
					state, severity = Wound.apply(state, { zone = zone, ammo = ammo, pellets = 1 }, WOUND, armour)
				end
				return severity, state
			end

			-- ONE SLUG IN THE VITALS STILL KILLS IT OUTRIGHT -- the same word a male gets.
			expect((shoot("head", "Slug", 1, toughness))).to.equal("lethal")
			expect((shoot("chest", "Slug", 1, toughness))).to.equal("lethal")
			expect((shoot("head", "Pellet", 3, toughness))).to.equal("lethal")

			-- A BODY SLUG DROPS A MALE AND ONLY GRAZES THE TROPHY. This is the pair the rule is
			-- about, and it is asserted as a PAIR so the change cannot be read as "it got tougher
			-- everywhere".
			expect((shoot("body", "Slug", 1, nil))).to.equal("mortal")
			expect((shoot("body", "Slug", 1, toughness))).to.equal("grazed")
			expect((shoot("body", "Slug", 2, toughness))).to.equal("mortal")

			-- A RUMP SLUG CRIPPLES A MALE (*"the back end goes"*) and does not cripple this one.
			expect((shoot("rear", "Slug", 1, nil))).to.equal("mortal")
			expect((shoot("rear", "Slug", 1, toughness))).to.equal("grazed")

			-- FIVE BUCKSHOT PELLETS IN THE BODY are mortal on a male and it takes ten here.
			expect((shoot("body", "Pellet", 5, nil))).to.equal("mortal")
			expect((shoot("body", "Pellet", 5, toughness))).to.equal("grazed")
			expect((shoot("body", "Pellet", 10, toughness))).to.equal("mortal")

			-- ...AND THE FLIGHT IS NOT CHANGED, which is why the thresholds were NOT scaled instead:
			-- two body slugs put it exactly where one puts a male, so the taper
			-- `Wound.flightStuds` applies across `MORTAL..LETHAL` reads the same.
			local _, trophy = shoot("body", "Slug", 2, toughness)
			local _, male = shoot("body", "Slug", 1, nil)
			expect(math.abs(trophy.flightStuds - male.flightStuds) < EPSILON).to.equal(true)
			TestKit.note(
				string.format(
					"boar-legendary: a body slug is mortal on a male and a graze on the trophy; two of them run it %.0f studs, same as one on a male",
					trophy.flightStuds
				)
			)
		end)
	end)

	describe("the legendary boar: wary", function()
		local on = configWith(true)

		it("notices further out and runs faster, and no other animal moved", function()
			local config = Boar.kindConfig("legendary", on)
			local wary = CONFIG.KINDS.legendary.wary

			-- EVERY RADIUS AT WHICH A PERSON MATTERS MOVES TOGETHER. Scaling one and not the others
			-- would put the calm radius inside the flee radius, which is a state that flickers.
			expect(math.abs(config.DETECT_RADIUS - CONFIG.DETECT_RADIUS * wary.noticeScale) < EPSILON).to.equal(true)
			expect(math.abs(config.CALM_RADIUS - CONFIG.CALM_RADIUS * wary.noticeScale) < EPSILON).to.equal(true)
			expect(config.CALM_RADIUS > config.DETECT_RADIUS).to.equal(true)
			for _, key in ipairs({ "NOTICE_MOVING", "NOTICE_STANDING", "FLUSH_STUDS", "CALM_MARGIN" }) do
				expect(math.abs(config.SENSE[key] - CONFIG.SENSE[key] * wary.noticeScale) < EPSILON).to.equal(true)
			end
			expect(math.abs(config.SPRINT_SPEED - CONFIG.SPRINT_SPEED * wary.runScale) < EPSILON).to.equal(true)

			-- THE BRAIN'S OWN TWO READERS ANSWER THE BIGGER NUMBERS, which is the point of doing this
			-- as a config rather than as a branch: `Brain.noticeRadius` and `Brain.fleeRadius` are
			-- unchanged code reading changed numbers.
			local walker = { position = Vector3.zero, speed = CONFIG.SENSE.MOVING_SPEED + 1 }
			expect(Boar.Brain.noticeRadius(walker, config) > Boar.Brain.noticeRadius(walker, on)).to.equal(true)
			expect(Boar.Brain.fleeRadius(walker, config) > Boar.Brain.fleeRadius(walker, on)).to.equal(true)
			TestKit.note(
				string.format(
					"boar-legendary: it notices a walking man at %.0f studs against %.0f, and runs at %.1f against %.1f",
					Boar.Brain.noticeRadius(walker, config),
					Boar.Brain.noticeRadius(walker, on),
					config.SPRINT_SPEED,
					on.SPRINT_SPEED
				)
			)

			-- ...AND FOR EVERY OTHER ANIMAL `kindConfig` IS THE IDENTITY FUNCTION -- the config TABLE
			-- itself, not a copy. That is what makes "nothing else moved" structural: there is no
			-- second table that could drift.
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.kindConfig(kind, on)).to.equal(on)
			end
			expect(Boar.kindConfig(nil, on)).to.equal(on)
			expect(Boar.kindConfig("wildebeest", on)).to.equal(on)

			-- IT IS STILL INSIDE ITS OWN RATE RAIL at the speed it can now reach, which is the other
			-- half of `runScale` being 1.12 and not 2: the run clip at 42.6 studs/s asks 1.83 of a
			-- ceiling of 2.8.
			local bands = Boar.gaitBands(CONFIG.KINDS.legendary.clipScale, on)
			local asked = config.SPRINT_SPEED / (CONFIG.MODEL.CLIPS.run.groundStudsPerSecond * bands.scale)
			expect(asked < bands.maxRate).to.equal(true)
			expect(asked > bands.minRate).to.equal(true)
		end)
	end)

	describe("the legendary boar: what it is worth, and what the screens are told", function()
		it("is laid out at the gathering BIGGER AND DARKER, on the model branch (round 1, finding 2)", function()
			-- ROUND 1 SHIPPED THE COMMENT AND NOT THE BEHAVIOUR. `Match.CONFIG.SCENE.ANIMAL_SCALES`
			-- gained `legendary = 1.35` and a comment saying the trophy is laid out 35 % longer than
			-- the males beside it -- but `Scene.build` reads that table ONLY on the grey-box fallback
			-- branch (`if display ~= nil then ... else local size = Scene.animalSize(...)`). The model
			-- branch goes `Match.displayAnimal` -> `Runtime:displayCarcass` -> `Body.displayCarcass`,
			-- which took no kind at all. So in the only world a live game ever runs -- `BOAR_MODEL`
			-- ON -- the animal the player just shot lay in the results scene at the male's length in
			-- the male's coat, and the one world that honoured 1.35 was the one with no model in it.
			--
			-- THIS CASE IS ON THE MODEL BRANCH, with a template that carries a `SurfaceAppearance`
			-- exactly as the bought asset does, so it fails if either half is dropped again.
			local holder = Instance.new("Folder")
			holder.Name = "BoarLegendaryDisplaySpec"
			holder.Parent = Workspace

			local MESH = Vector3.new(1.4011, 3.2573, 5.5) -- the male's own, measured off the asset
			local function template(): Model
				local model = Instance.new("Model")
				local mesh = Instance.new("MeshPart")
				mesh.Size = MESH
				mesh.Anchored = true
				local coat = Instance.new("SurfaceAppearance")
				coat.Parent = mesh
				mesh.Parent = model
				-- PARENTED, and that is not tidiness: `Runtime:_modelTemplate` only reuses a held
				-- template while `held.Parent ~= nil`, and re-asking is rate-limited to once a second
				-- per key (`MODEL.ASK_EVERY_SECONDS`). An unparented fake therefore answered the
				-- FIRST call and nil to the second -- which is how the first draft of this case
				-- failed, on the trophy, for a reason that had nothing to do with the trophy.
				model.Parent = holder
				return model
			end

			local kindsOn = table.clone(CONFIG.KINDS)
			kindsOn.ENABLED = true
			local modelOn = table.clone(CONFIG.MODEL)
			modelOn.ENABLED = true
			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "Display",
				rng = Random.new(219),
				config = { KINDS = kindsOn, MODEL = modelOn },
				threats = function()
					return {}
				end,
			})
			local held = {}
			runtime:setModelSource(function(key: string): Instance?
				-- ONE TEMPLATE PER ASSET KEY, as the live source does. The trophy's key is "male",
				-- which is the whole of "no upload, no new asset id".
				if held[key] == nil then
					held[key] = template()
				end
				return held[key]
			end, nil)

			local ground = CFrame.new(0, FIELD.groundY, 0)
			local male = runtime:displayCarcass("male", ground)
			local trophy = runtime:displayCarcass("legendary", ground)
			expect(male).to.be.ok()
			expect(trophy).to.be.ok()

			-- BIGGER, on the drawn mesh and not in a config table.
			local maleMesh = (male :: Model).PrimaryPart :: BasePart
			local trophyMesh = (trophy :: Model).PrimaryPart :: BasePart
			expect(math.abs(trophyMesh.Size.Z / maleMesh.Size.Z - 1.35) < 1e-3).to.equal(true)
			expect(math.abs(trophyMesh.Size.Y / maleMesh.Size.Y - 1.35) < 1e-3).to.equal(true)

			-- ...AND DARKER, on the coat the asset carries.
			local function coatOf(model: Model): Color3?
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("SurfaceAppearance") then
						return d.Color
					end
				end
				return nil
			end
			local trophyCoat = coatOf(trophy :: Model)
			expect(trophyCoat).to.be.ok()
			expect(trophyCoat :: Color3).to.equal(CONFIG.KINDS.legendary.tint)
			-- The male's is untouched: white, i.e. the artist's ColorMap as drawn.
			expect(coatOf(male :: Model)).to.equal(Color3.new(1, 1, 1))

			-- ...AND IT STILL LIES ON THE GROUND. `Body.lyingCFrame` reads the mesh's size, so
			-- scaling BEFORE the pose is what keeps the bigger animal resting on the grass rather
			-- than sunk a third of the way into it.
			local half = Boar.lyingHalfHeight(trophyMesh.Size, CONFIG.MODEL.DISPLAY_ROLL_DEG)
			expect(math.abs((trophyMesh.Position.Y - half) - FIELD.groundY) < 1e-3).to.equal(true)
			TestKit.note(
				string.format(
					"boar-legendary: the display is %.2f studs against the male's %.2f, coat x(%.2f, %.2f, %.2f)",
					trophyMesh.Size.Z,
					maleMesh.Size.Z,
					(trophyCoat :: Color3).R,
					(trophyCoat :: Color3).G,
					(trophyCoat :: Color3).B
				)
			)

			-- AND THE SCENE'S OWN FALLBACK TABLE STILL AGREES WITH THE ANIMAL, which is what keeps
			-- the grey-box branch and the model branch showing one size: `Match` must not require
			-- `Boar`, so the numbers are copied -- and copied numbers need a case that compares them.
			-- BOAR KINDS ONLY SINCE TASK 223, and that is the trap this loop would otherwise walk
			-- straight into: a DEER's `KINDS[kind].scale` is against the STAG's 7.05 studs, while
			-- every row of `ANIMAL_SCALES` is against the boar male's 5.5. The two numbers for one
			-- deer are different ON PURPOSE. What they must agree about is the BAKED LENGTH, and
			-- `tests/server/deer.spec.luau` asserts exactly that, for all seven kinds.
			for kind, scale in pairs(Match.CONFIG.SCENE.ANIMAL_SCALES) do
				if CONFIG.KINDS[kind].species == nil then
					expect(math.abs(scale - CONFIG.KINDS[kind].scale) < EPSILON).to.equal(true)
				end
			end

			(male :: Model):Destroy();
			(trophy :: Model):Destroy()
			runtime:destroy()
			holder:Destroy()
		end)

		it("carries kind = legendary on the kill record", function()
			-- THE ONE FIELD EVERY SCREEN AND THE WHOLE PRICE DEPEND ON. `Wound.killRecord` has
			-- carried `kind` since task 120 (*"WHICH ANIMAL DIED"*), and this is the case that says a
			-- legendary arrives on it -- the hit card, the TAB report and `Score.kill` all read it.
			local state = Wound.apply(Wound.new(), {
				zone = "chest",
				ammo = "Slug",
				pellets = 1,
				shooterUserId = 4219,
				shooterName = "Karen",
			}, WOUND, Boar.toughnessFor("legendary", configWith(true)))
			local record = Wound.killRecord(state, "Boar1", Vector3.zero, 12, WOUND, "legendary")
			expect(record.kind).to.equal("legendary")
			expect(record.killedByUserId).to.equal(4219)
			expect(record.instant).to.equal(true) -- a chest slug is still a chest slug
		end)

		it("is worth 25 points and 2.5 males, through the table task 160 already wrote", function()
			-- **THE NUMBER DID NOT MOVE.** It was Karen's (*"first place ofc more legendary more
			-- ect"*) and it has been in `Match.CONFIG.POINTS.KIND` since task 160 with nothing behind
			-- it. What this task added is an animal that can claim it, so this case reads the price
			-- through `Match.Score.kill` -- the function the drive actually scores with -- rather
			-- than reading the constant twice.
			local points = Match.CONFIG.POINTS
			expect(points.KIND.legendary).to.equal(25)
			expect(points.KIND.legendary).to.equal(points.KIND.male * 2.5)

			local board = Match.Score.new()
			board = Match.Score.join(board, 4219, "Karen", "Shooters")
			local awards
			board, awards = Match.Score.kill(board, {
				kind = "legendary",
				killedByUserId = 4219,
				killingZone = "chest",
			}, nil, Match.CONFIG)
			expect(board.rows[4219].points).to.equal(25)
			expect(board.rows[4219].kills).to.equal(1)
			-- THE AWARD SAYS WHICH ANIMAL IT WAS PAID FOR, which is how a kind typo is told from a
			-- real kind: a legendary is `kill-legendary` and never `kill-unknown`.
			expect(#awards).to.equal(1)
			expect(awards[1].reason).to.equal("kill-legendary")
			-- ...and a male beside it, so the LADDER is asserted and not just the number.
			board = Match.Score.kill(board, { kind = "male", killedByUserId = 4219 }, nil, Match.CONFIG)
			expect(board.rows[4219].points).to.equal(35)
			TestKit.note("boar-legendary: one trophy and one male score 25 + 10 = 35 points, as kill-legendary")
		end)

		it("is named on every screen that names an animal, and is one of the species' kinds", function()
			-- L-093's lesson, applied: every place a `kind` is READ gets a case that actually enters
			-- the legendary arm, not just the data table.
			local Report = require(ReplicatedStorage:WaitForChild("Report"))
			local Drive = require(ReplicatedStorage:WaitForChild("Drive"))

			-- 1. THE TAB REPORT'S ANIMAL COLUMN. `Report.kindWord` returns an unknown kind as it
			--    came, so this needed no mapping -- but it needs a case, because "no change was
			--    needed" is a claim about behaviour and not about a diff.
			expect(Report.kindWord("legendary")).to.equal("legendary")
			expect(string.upper(Report.kindWord("legendary"))).to.equal("LEGENDARY")

			-- 2. THE HIT CARD'S PLATE TAG, and nothing else gets one.
			expect(Report.trophyWord("legendary")).to.equal("LEGENDARY BOAR")
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Report.trophyWord(kind)).to.equal(nil)
			end
			expect(Report.trophyWord(nil)).to.equal(nil)

			-- 3. THE PICTURE. It is the male's silhouette at full size, which is honest about being
			--    the same drawing -- the same answer the sow gives a piglet.
			expect(Report.boarImage("legendary").id).to.equal(Report.boarImage("male").id)
			expect(Report.boarImage("legendary").scale).to.equal(1)

			-- 4. THE START CARD DOES **NOT** NAME IT, and that is asserted rather than left to
			--    chance -- because the failure would be invisible: the card's row cap is 4 and its
			--    height is a fixed number, so a fourth quarry kind would push the PERSON row (the
			--    Designer's own addition) off the card and nothing would error. The reason lives on
			--    `Match.CONFIG.QUARRY`; this is the case that holds it in place.
			expect(Drive.CONFIG.START_CARD_QUARRY_WORDS.legendary).to.equal(nil)
			expect(Drive.CONFIG.START_CARD_ROWS_MAX).to.equal(4)
			local quarryKinds = 0
			for _, row in ipairs(Match.CONFIG.QUARRY) do
				for _, kind in ipairs(row.kinds) do
					quarryKinds += 1
					expect(kind ~= "legendary").to.equal(true)
				end
			end
			expect(quarryKinds + 1).to.equal(Drive.CONFIG.START_CARD_ROWS_MAX)

			-- 5. ...AND IT IS STILL A WILD BOAR TO THE RULES. Nothing but the card reads `QUARRY`;
			--    the licence and `Match.classifyTarget` learn the species from the ANIMAL, so the
			--    trophy needs no licence of its own and cannot be shot by somebody who may not shoot
			--    a boar.
			expect(Match.CONFIG.QUARRY[1].species).to.equal("WILD BOAR")

			-- 6. THE GATHERING lays it out 35 % longer than the males beside it, and the scene's own
			--    scales are the same four numbers the boar config holds.
			-- BOAR KINDS ONLY SINCE TASK 223, and that is the trap this loop would otherwise walk
			-- straight into: a DEER's `KINDS[kind].scale` is against the STAG's 7.05 studs, while
			-- every row of `ANIMAL_SCALES` is against the boar male's 5.5. The two numbers for one
			-- deer are different ON PURPOSE. What they must agree about is the BAKED LENGTH, and
			-- `tests/server/deer.spec.luau` asserts exactly that, for all seven kinds.
			for kind, scale in pairs(Match.CONFIG.SCENE.ANIMAL_SCALES) do
				if CONFIG.KINDS[kind].species == nil then
					expect(math.abs(scale - CONFIG.KINDS[kind].scale) < EPSILON).to.equal(true)
				end
			end
			expect(Match.CONFIG.SCENE.ANIMAL_SCALES.legendary).to.equal(1.35)

			-- 7. THE DRIVE REPORT'S WIRE carries it as its OWN count and not as an `unknown`, which
			--    is what keeps `unknown` meaning "a kind typo". The TAB list's three columns are the
			--    client's business (`report_panel.spec`); what this pins is that the key exists.
			local HitLog = require(ServerScriptService:WaitForChild("HitLog"))
			local rows = HitLog.Shape.hunterRows({
				order = { "Boar1" },
				animals = {
					Boar1 = {
						kind = "legendary",
						result = "down",
						killedByUserId = 4219,
						dots = { { userId = 4219, name = "Karen", u = 0.5, v = 0.5, zone = "chest" } },
					},
				},
			}, 8)
			expect(#rows).to.equal(1)
			expect(rows[1].byKind.legendary).to.equal(1)
			expect(rows[1].byKind.unknown).to.equal(0)
			expect(rows[1].kills).to.equal(1)
		end)
	end)
end
