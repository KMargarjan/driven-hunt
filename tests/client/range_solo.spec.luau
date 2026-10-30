-- range_solo.spec: ALONE ON THE RANGE, on the client (task 313, design 7, 14.2). Karen,
-- 2026-10-30: *"when I click E it will make that I am alone in all shooting range"* -- so the
-- second picture hides other MEN, and `Range.Mask` keeps hiding their animals.
--
-- IT ASSERTS THE STARTER COPY of `Range.Solo`, not the running one, for `range_mask.spec`'s own
-- reason: `RangeBoot.client.luau` steps the module in `player.PlayerScripts` every Heartbeat, and
-- a counter a second owner is stepping cannot carry T12's "writes did not climb". The live copy is
-- asserted separately, at the end, for the one thing that makes these numbers readable.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterPlayer = game:GetService("StarterPlayer")
	local Players = game:GetService("Players")

	local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
	local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local Solo = require(scripts:WaitForChild("Range"):WaitForChild("Solo"))
	local Mask = require(scripts:WaitForChild("Range"):WaitForChild("Mask"))

	-- NOTHING THIS SPEC STAGES IS PARENTED TO `Workspace`, AND THAT IS A MEASUREMENT, NOT TIDINESS.
	-- Studio's Play runs ONE DataModel, so the server specs' world raycasts see anything a client
	-- spec leaves in `Workspace` -- and these fakes sit at the origin, which is where
	-- `deer_hitbox.spec` stages its animal. Parented here, they took that spec's flank ray and it
	-- failed three runs out of three. Neither `Solo` nor `Mask` reads an ancestor above the root it
	-- is handed (`Mask.start`'s `root`, `Solo`'s injected `players`) and `RangeData.isTarget` is a
	-- `FindFirstAncestor` that works on a detached tree, so a detached scene tests the same code.
	local holder = Instance.new("Folder")
	holder.Name = "RangeSoloSpecScene"

	-- A FAKE PLAYER IS A TABLE WITH A `Character`, which is all either module reads of one. The
	-- real `Players` service is never touched: both seams are injected.
	local function fakePlayer(name: string, parts: number, parent: Instance?): (any, { BasePart })
		local character = Instance.new("Model")
		character.Name = name
		local made: { BasePart } = {}
		for index = 1, parts do
			local part = Instance.new("Part")
			part.Name = name .. "_" .. tostring(index)
			part.Anchored = true
			part.LocalTransparencyModifier = 0
			part.Parent = character
			table.insert(made, part)
		end
		character.Parent = parent or holder
		return { Name = name, Character = character }, made
	end

	local function allAt(parts: { BasePart }, value: number): boolean
		for _, part in ipairs(parts) do
			if math.abs(part.LocalTransparencyModifier - value) > 1e-6 then
				return false
			end
		end
		return true
	end

	describe("Range.Solo hides every other man and nobody else", function()
		it("hides the others on `alone` and puts them back when it is cleared", function()
			local me, mine = fakePlayer("SoloSpecMe", 3)
			local a, aParts = fakePlayer("SoloSpecA", 3)
			local b, bParts = fakePlayer("SoloSpecB", 2)
			-- A PART THAT ALREADY CARRIES A MODIFIER: "shown" is the value this module FOUND, never
			-- a flat 0, which is `Mask.apply`'s own rule.
			aParts[1].LocalTransparencyModifier = 0.25
			local list = { me, a, b }
			expect(Solo.start({
				players = function()
					return list
				end,
				me = me,
			})).to.equal(true)

			Solo.step(0)
			expect(Solo.stats().others).to.equal(2)
			expect(aParts[1].LocalTransparencyModifier).to.be.near(0.25, 1e-6)
			expect(aParts[2].LocalTransparencyModifier).to.be.near(0, 1e-6)
			expect(allAt(mine, 0)).to.equal(true)

			Solo.setAlone(true)
			Solo.step(0)
			expect(allAt(aParts, Solo.HIDDEN)).to.equal(true)
			expect(allAt(bParts, Solo.HIDDEN)).to.equal(true)
			expect(Solo.stats().hidden).to.equal(2)
			-- MY OWN BODY IS NEVER TOUCHED: `Camera.Rig` owns it (design 7.2).
			expect(allAt(mine, 0)).to.equal(true)

			Solo.setAlone(false)
			Solo.step(0)
			expect(aParts[1].LocalTransparencyModifier).to.be.near(0.25, 1e-6)
			expect(allAt(bParts, 0)).to.equal(true)

			Solo.stop()
			me.Character:Destroy()
			a.Character:Destroy()
			b.Character:Destroy()
		end)

		it("hides a man who arrives after start, by the sweep and not by a signal", function()
			local me = fakePlayer("SoloSpecMe2", 1)
			local list = { me }
			Solo.start({
				players = function()
					return list
				end,
				me = me,
			})
			Solo.setAlone(true)
			Solo.step(0)
			expect(Solo.stats().others).to.equal(0)

			local late, lateParts = fakePlayer("SoloSpecLate", 2)
			table.insert(list, late)
			Solo.step(0)
			expect(Solo.stats().others).to.equal(1)
			expect(allAt(lateParts, Solo.HIDDEN)).to.equal(true)

			Solo.stop()
			-- `stop` IS THE DOOR OUT: nobody keeps a modifier this module put on him.
			expect(allAt(lateParts, 0)).to.equal(true)
			me.Character:Destroy()
			late.Character:Destroy()
		end)

		-- T12: free when nothing changes.
		it("writes nothing across 60 idle steps", function()
			local me = fakePlayer("SoloSpecMe3", 1)
			local a = fakePlayer("SoloSpecA3", 4)
			local list = { me, a }
			Solo.start({
				players = function()
					return list
				end,
				me = me,
			})
			Solo.setAlone(true)
			Solo.step(0)
			local settled = Solo.stats().writes
			expect(settled).to.equal(4)
			for _ = 1, 60 do
				Solo.step(1 / 60)
			end
			expect(Solo.stats().writes).to.equal(settled)
			expect(Solo.stats().sweeps).to.equal(61)
			Solo.stop()
			me.Character:Destroy()
			a.Character:Destroy()
		end)
	end)

	-- THE PARTITION (design 7.2), ASSERTED AND NOT DESCRIBED. One staged scene holding all the
	-- sets, both modules stepped, and for every part exactly one of them accounts for the write.
	describe("the two pictures partition the one property", function()
		it("refuses a range target, and leaves the animals to the mask", function()
			local folder = Instance.new("Folder")
			folder.Name = RangeData.TARGETS_FOLDER
			local trunk = Instance.new("Part")
			trunk.Name = "SoloSpecTrunk"
			trunk.Anchored = true
			trunk.Parent = folder
			folder.Parent = holder

			-- THE PATHOLOGICAL CASE `range_mask.spec` ALREADY STAGES: a character model parented
			-- INTO the targets folder. The FOLDER WINS, so `Solo` refuses every part of it.
			local inside, insideParts = fakePlayer("SoloSpecInsideFolder", 2, folder)
			local outside, outsideParts = fakePlayer("SoloSpecOutside", 2)
			local me = fakePlayer("SoloSpecMe4", 1)
			local list = { me, inside, outside }

			Solo.start({
				players = function()
					return list
				end,
				me = me,
			})
			Solo.setAlone(true)
			Solo.step(0)

			expect(allAt(insideParts, 0)).to.equal(true)
			expect(allAt(outsideParts, Solo.HIDDEN)).to.equal(true)
			-- EVERY PART OF THE IN-FOLDER CHARACTER WAS REFUSED, counted and not written.
			expect(Solo.stats().refused >= #insideParts).to.equal(true)
			expect(Solo.stats().writes).to.equal(#outsideParts)

			-- ...AND THE MASK OWNS THEM: it writes the folder's parts, including that character's,
			-- and `Solo` has written none of them.
			expect(Mask.start({ root = folder })).to.equal(true)
			Mask.setMine(nil)
			Mask.step(0)
			expect(trunk.LocalTransparencyModifier).to.be.near(Mask.HIDDEN, 1e-6)
			expect(Mask.stats().writes >= 1).to.equal(true)

			Mask.stop()
			Solo.stop()
			folder:Destroy()
			outside.Character:Destroy()
			me.Character:Destroy()
		end)
	end)

	describe("the running client", function()
		it("the live copy RangeBoot steps is not the one this spec measured", function()
			local liveScripts = (Players.LocalPlayer :: any):WaitForChild("PlayerScripts")
			local liveRange = liveScripts:WaitForChild("Range", 10)
			expect(liveRange).to.be.ok()
			local liveSolo = require((liveRange :: Instance):WaitForChild("Solo", 10))
			expect(liveSolo).to.be.ok()
			expect(liveSolo == Solo).to.equal(false)
			expect(type(liveSolo.stats().writes)).to.equal("number")
		end)
	end)
end
