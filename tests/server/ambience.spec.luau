-- ambience.spec: the bed's PURE half -- the state machine and the data invariants -- with no Sound,
-- no clock, no player and no client. `ReplicatedStorage.Ambience` is frozen data plus pure
-- functions, so everything that decides the crossfade's SHAPE is checked here in microseconds and
-- the client spec is only ever about Instances.
--
-- NOBODY HERE CAN HEAR IT. What is asserted is arithmetic and structure; whether quiet birds and a
-- soft wind at the lodge are Karen's *"relax quuiet"* is her ears' business and nothing in this file
-- pretends otherwise.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/ambience.md (sections 5, 6.1, 10, 11.1)
-- Note:   docs/research/2026-10-23-ambience-and-money-fines.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Ambience"))
local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local EPSILON = 1e-6

-- A GOOD CONFIG, BUILT BY HAND, so every refusal below is driven from a known-good starting point
-- rather than from production's table -- which would make a `rowsOk` that silently stopped checking
-- look exactly like one that passes.
local function goodConfig()
	return {
		FADE_SECONDS = 2.0,
		BEDS = {
			lodge = {
				WORD = "lodge",
				VOICES = {
					{ WHAT = "birds", ID = "rbxassetid://1", LEVEL = 0.1, FROM = 0, TO = 0, CLIP_SECONDS = 30 },
					{ WHAT = "wind", ID = "rbxassetid://2", LEVEL = 0.05, FROM = 1, TO = 25, CLIP_SECONDS = 30 },
				},
			},
			hunt = {
				WORD = "hunt",
				VOICES = { { WHAT = "forest", ID = "", LEVEL = 0.2, FROM = 0, TO = 0, CLIP_SECONDS = 0 } },
			},
		},
	}
end

return function()
	describe("which bed a team belongs in", function()
		it("puts a man in a drive out on the line and everybody else at the lodge", function()
			expect(Ambience.bedFor("Shooters")).to.equal("hunt")
			expect(Ambience.bedFor("Drivers")).to.equal("hunt")
			-- A PLAYER AT THE LODGE HAS NO TEAM. That is not an inference about the lodge -- it is
			-- what "not in the drive" means everywhere in this repo.
			expect(Ambience.bedFor(nil)).to.equal("lodge")
			expect(Ambience.bedFor("")).to.equal("lodge")
			expect(Ambience.bedFor("Spectators")).to.equal("lodge")
			-- ...and the WRONG CASE is not a team either, which is the honest answer: team words are
			-- compared, never parsed.
			expect(Ambience.bedFor("shooters")).to.equal("lodge")
			expect(Ambience.bedFor(7 :: any)).to.equal("lodge")
		end)

		it("reads Drive.TEAMS rather than carrying a third spelling of Shooters", function()
			-- A rename on one side cannot pass this: the words that answer "hunt" are exactly the
			-- keys of the table the drive owns.
			local count = 0
			for word in pairs(Drive.TEAMS) do
				expect(Ambience.bedFor(word)).to.equal("hunt")
				count += 1
			end
			expect(count).to.equal(2)
			expect(Ambience.DEFAULT_BED).to.equal("lodge")
		end)
	end)

	describe("the targets", function()
		it("always has exactly one bed at 1 and the rest at 0", function()
			-- INVARIANT I1, and it is a property of the only shape a target table can have rather
			-- than a rule the stepper enforces -- which is what makes "at most one rising and one
			-- falling" true by construction.
			for _, input in ipairs({ "lodge", "hunt", "", "Spectators", "nonsense" }) do
				local targets = Ambience.targetsFor(input)
				local sum, ones = 0, 0
				for _, word in ipairs(Ambience.BED_WORDS) do
					expect(type(targets[word])).to.equal("number")
					sum += targets[word]
					if targets[word] == 1 then
						ones += 1
					end
				end
				expect(sum).to.equal(1)
				expect(ones).to.equal(1)
			end
			local nilTargets = Ambience.targetsFor(nil)
			expect(nilTargets.lodge).to.equal(1)
			expect(nilTargets.hunt).to.equal(0)
		end)

		it("falls back to the lodge for a bed nobody has heard of", function()
			expect(Ambience.targetsFor("hunt").hunt).to.equal(1)
			expect(Ambience.targetsFor("barn").lodge).to.equal(1)
		end)
	end)

	describe("the fade", function()
		it("reaches the target in FADE_SECONDS and lands exactly on it", function()
			-- N3: a flip completes in <= FADE_SECONDS plus one frame, and "arrived" is a VALUE a
			-- spec can compare rather than an asymptote.
			local gain = 0
			local steps = 0
			while gain < 1 and steps < 1000 do
				gain = Ambience.stepGain(gain, 1, 1 / 60, 2.5)
				steps += 1
			end
			expect(gain).to.equal(1)
			expect(steps <= 151).to.equal(true)
			TestKit.note(string.format("[ambience] 0 -> 1 at 60 fps over 2.5 s took %d steps", steps))
		end)

		it("is frame-rate independent", function()
			-- N4: 2.5 s of fade is 2.5 s of fade at 30, 60 or 144 fps.
			for _, fps in ipairs({ 30, 60, 144 }) do
				local dt = 1 / fps
				local gain = 0
				for _ = 1, math.ceil(2.5 * fps) do
					gain = Ambience.stepGain(gain, 1, dt, 2.5)
				end
				expect(gain).to.be.near(1, EPSILON)
			end
		end)

		it("never overshoots, never leaves [0, 1], and is monotone toward the target", function()
			-- N5, including the two degenerate clocks.
			expect(Ambience.stepGain(0, 1, 1e6, 2.5)).to.equal(1)
			expect(Ambience.stepGain(1, 0, 1e6, 2.5)).to.equal(0)
			expect(Ambience.stepGain(0.5, 1, 0, 2.5)).to.equal(0.5)
			expect(Ambience.stepGain(0.5, 0.5, 1, 2.5)).to.equal(0.5)
			-- a fade of zero or less is INSTANT, which is the honest reading of "no fade"
			expect(Ambience.stepGain(0, 1, 1 / 60, 0)).to.equal(1)
			expect(Ambience.stepGain(0, 1, 1 / 60, -3)).to.equal(1)
			-- out-of-range inputs are clamped rather than propagated
			expect(Ambience.stepGain(-5, 1, 1e6, 2.5)).to.equal(1)
			expect(Ambience.stepGain(5, 0, 1e6, 2.5)).to.equal(0)
			local gain, last = 0, -1
			for _ = 1, 200 do
				gain = Ambience.stepGain(gain, 1, 1 / 60, 2.5)
				expect(gain >= last).to.equal(true)
				expect(gain >= 0 and gain <= 1).to.equal(true)
				last = gain
			end
		end)

		it("reverses from where the fade had got to, across twenty flips", function()
			-- SECTION 5.3: `applyTeam` writes only the targets, so a flip mid-fade is a pure
			-- retarget -- no cancel, no tween to destroy, no edge to miss, and the gain is
			-- continuous across any number of flips.
			local gain = 0
			for _ = 1, 60 do
				gain = Ambience.stepGain(gain, 1, 1 / 60, 2.5)
			end
			expect(gain > 0 and gain < 1).to.equal(true)
			local atFlip = gain
			-- the flip itself moves nothing (I2 on this half)
			expect(Ambience.stepGain(gain, 0, 0, 2.5)).to.equal(atFlip)
			local target = 0
			for flip = 1, 20 do
				for _ = 1, 20 do
					gain = Ambience.stepGain(gain, target, 1 / 60, 2.5)
					expect(gain >= 0 and gain <= 1).to.equal(true)
				end
				target = if flip % 2 == 1 then 1 else 0
			end
			expect(gain >= 0 and gain <= 1).to.equal(true)
		end)
	end)

	describe("the volume", function()
		it("is the gain times the level, clamped to the engine's range", function()
			expect(Ambience.volumeFor(0, 0.5)).to.equal(0)
			expect(Ambience.volumeFor(1, 0.5)).to.equal(0.5)
			expect(Ambience.volumeFor(0.5, 0.5)).to.equal(0.25)
			-- N12: `Sound.Volume` runs 0..10 and no data row may ask for more
			expect(Ambience.volumeFor(1, 50)).to.equal(Ambience.VOLUME_MAX)
			expect(Ambience.volumeFor(1, -1)).to.equal(0)
			expect(Ambience.volumeFor(2, 0.5)).to.equal(0.5)
			expect(Ambience.volumeFor(nil :: any, 0.5)).to.equal(0)
		end)
	end)

	describe("the loop window", function()
		it("resolves TO == 0 to the whole clip", function()
			local from, to = Ambience.loopWindow({
				WHAT = "x",
				ID = "rbxassetid://1",
				LEVEL = 1,
				FROM = 0,
				TO = 0,
				CLIP_SECONDS = 40,
			})
			expect(from).to.equal(0)
			expect(to).to.equal(40)
			from, to = Ambience.loopWindow({
				WHAT = "x",
				ID = "rbxassetid://1",
				LEVEL = 1,
				FROM = 3,
				TO = 20,
				CLIP_SECONDS = 40,
			})
			expect(from).to.equal(3)
			expect(to).to.equal(20)
		end)

		it("gives every shipped voice at least twenty seconds of loop", function()
			-- N8: an audible repeat happens at most three times a minute.
			for _, word in ipairs(Ambience.BED_WORDS) do
				for _, voice in ipairs(Ambience.CONFIG.BEDS[word].VOICES) do
					if voice.ID ~= "" then
						local from, to = Ambience.loopWindow(voice)
						expect(to - from >= 20).to.equal(true)
						TestKit.note(string.format("[ambience] %s.%s loops %.2f..%.2f s", word, voice.WHAT, from, to))
					end
				end
			end
		end)
	end)

	describe("the instance names", function()
		it("are prefixed, per bed and per layer, and are the one spelling", function()
			local voice = { WHAT = "birds", ID = "rbxassetid://1", LEVEL = 1, FROM = 0, TO = 0, CLIP_SECONDS = 1 }
			expect(Ambience.voiceName("lodge", voice)).to.equal("Ambience_lodge_birds")
			expect(string.sub(Ambience.voiceName("lodge", voice), 1, #Ambience.NAME_PREFIX)).to.equal(
				Ambience.NAME_PREFIX
			)
			-- every shipped voice gets a DISTINCT name, which is what lets the owner find a row
			-- back from a live Sound
			local seen: { [string]: boolean } = {}
			for _, word in ipairs(Ambience.BED_WORDS) do
				for _, row in ipairs(Ambience.CONFIG.BEDS[word].VOICES) do
					local name = Ambience.voiceName(word, row)
					expect(seen[name]).to.equal(nil)
					seen[name] = true
				end
			end
		end)
	end)

	describe("the data", function()
		it("is what it says it is", function()
			local ok, why = Ambience.rowsOk(Ambience.CONFIG)
			expect(why).to.equal(nil)
			expect(ok).to.equal(true)
			expect(Ambience.rowsOk(goodConfig())).to.equal(true)
		end)

		it("is frozen, as every shared data table in this repo is", function()
			expect(table.isfrozen(Ambience.CONFIG)).to.equal(true)
			expect(table.isfrozen(Ambience.BED_WORDS)).to.equal(true)
			expect(table.isfrozen(Ambience.CONFIG.BEDS.lodge)).to.equal(true)
			expect(table.isfrozen(Ambience.CONFIG.BEDS.lodge.VOICES[1])).to.equal(true)
		end)

		it("ships the lodge quieter than Karen's own forest, and far under the drive's bugle", function()
			-- N6/N7. `Workspace.Ambience` is her Studio-made Sound at Volume 0.50 with a MEASURED
			-- mean loudness of 6.0, so its energy at the ear is about 3.0 in these units; the
			-- drive's bugle is 3 (`Horn.CONFIG.SIGNAL.VOLUME`). The lodge must be plainly under
			-- both, which is the dispatch's *"calmer and quieter than the hunt's forest ambience"*.
			local total = 0
			for _, voice in ipairs(Ambience.CONFIG.BEDS.lodge.VOICES) do
				expect(voice.LEVEL > 0).to.equal(true)
				expect(voice.LEVEL < 0.5).to.equal(true)
				total += voice.LEVEL
			end
			expect(total < 0.5).to.equal(true)
			TestKit.note(string.format("[ambience] lodge levels add to %.3f against the place's 0.50", total))
		end)

		it("ships the hunt bed silent, on purpose, and that is not an error", function()
			-- In the Forest Test the hunt's forest already exists as Karen's `Workspace.Ambience`,
			-- which this owner may not touch. A second global forest layer would double a bed
			-- nobody in git owns. The row is one Karen fills the day she wants it (design K3).
			local hunt = Ambience.CONFIG.BEDS.hunt
			expect(#hunt.VOICES).to.equal(1)
			expect(hunt.VOICES[1].ID).to.equal("")
			-- ...and `rowsOk` passes it, which is the whole point of the empty-id rule
			expect(Ambience.rowsOk(Ambience.CONFIG)).to.equal(true)
		end)

		it("refuses every bad row it claims to, by name", function()
			-- A CHECKER NOBODY HAS SHOWN CAN FAIL IS NOT EVIDENCE.
			local cases = {
				{ "not a table", "no config" },
				{ "FADE_SECONDS", "zero fade" },
				{ "FADE_SECONDS", "negative fade" },
				{ "BEDS", "no beds" },
				{ "missing the bed", "a bed gone" },
				{ "no BED_WORDS entry names", "an extra bed" },
				{ "calls itself", "a bed misnamed" },
				{ "has no voices", "an empty bed" },
				{ "has no WHAT", "a voice with no word" },
				{ "two voices called", "a duplicate word" },
				{ "LEVEL must be in", "a level of zero" },
				{ "LEVEL must be in", "a level over ten" },
				{ "CLIP_SECONDS must be measured", "an unmeasured clip" },
				{ "FROM must be >= 0", "a negative FROM" },
				{ "needs FROM < TO", "TO past the clip" },
				{ "needs FROM < TO", "a crossed window" },
			}
			local broken = {}
			broken[1] = "not a table at all"
			broken[2] = goodConfig()
			broken[2].FADE_SECONDS = 0
			broken[3] = goodConfig()
			broken[3].FADE_SECONDS = -1
			broken[4] = goodConfig()
			broken[4].BEDS = 7
			broken[5] = goodConfig()
			broken[5].BEDS.hunt = nil
			broken[6] = goodConfig()
			broken[6].BEDS.barn = { WORD = "barn", VOICES = { broken[6].BEDS.lodge.VOICES[1] } }
			broken[7] = goodConfig()
			broken[7].BEDS.lodge.WORD = "cabin"
			broken[8] = goodConfig()
			broken[8].BEDS.lodge.VOICES = {}
			broken[9] = goodConfig()
			broken[9].BEDS.lodge.VOICES[1].WHAT = ""
			broken[10] = goodConfig()
			broken[10].BEDS.lodge.VOICES[2].WHAT = "birds"
			broken[11] = goodConfig()
			broken[11].BEDS.lodge.VOICES[1].LEVEL = 0
			broken[12] = goodConfig()
			broken[12].BEDS.lodge.VOICES[1].LEVEL = 11
			broken[13] = goodConfig()
			broken[13].BEDS.lodge.VOICES[1].CLIP_SECONDS = 0
			broken[14] = goodConfig()
			broken[14].BEDS.lodge.VOICES[1].FROM = -1
			broken[15] = goodConfig()
			broken[15].BEDS.lodge.VOICES[2].TO = 999
			broken[16] = goodConfig()
			broken[16].BEDS.lodge.VOICES[2].FROM = 26

			for index, case in ipairs(cases) do
				local ok, why = Ambience.rowsOk(broken[index] :: any)
				expect(ok).to.equal(false)
				expect(type(why)).to.equal("string")
				expect(string.find(why :: string, case[1], 1, true)).to.be.ok()
			end
		end)
	end)

	describe("the shared half is data and arithmetic", function()
		-- SECTION 2, asserted as a NEGATIVE -- and asserted by BEHAVIOUR rather than by reading the
		-- module's own text, because **a game script cannot read `Source`**: it needs the capability
		-- `PluginOrOpenCloud`, which neither runner has (measured, round 1 of this task: the client
		-- spec failed with *"The current thread cannot read 'Source'"*). Only
		-- `tools/studio_mcp.py` can read a script's text, through the Assistant.
		it("makes no Instance and owns no state: two calls agree, and nothing new appears", function()
			local before = #game:GetService("SoundService"):GetChildren()
			for _, word in ipairs(Ambience.BED_WORDS) do
				Ambience.targetsFor(word)
				Ambience.bedFor(word)
				Ambience.stepGain(0, 1, 1 / 60, 2.5)
				Ambience.volumeFor(0.5, 0.1)
			end
			expect(#game:GetService("SoundService"):GetChildren()).to.equal(before)
		end)

		it("is PURE: the same input gives the same answer, and no answer is a shared table", function()
			-- A function that held state would drift across these two calls; a function that
			-- returned its own table would let a caller edit the next caller's answer.
			local first = Ambience.targetsFor("hunt")
			local second = Ambience.targetsFor("hunt")
			expect(first).never.to.equal(second) -- two tables, not one
			expect(first.hunt).to.equal(second.hunt)
			first.hunt = 0.5
			expect(Ambience.targetsFor("hunt").hunt).to.equal(1)
			expect(Ambience.stepGain(0.25, 1, 1 / 60, 2.5)).to.equal(Ambience.stepGain(0.25, 1, 1 / 60, 2.5))
		end)

		it("has no owner's half: no start, no stop, no step, no voices", function()
			-- The shared module is DATA AND RULES. If a later hand moves the owner's writers in
			-- here, this is what says so.
			for _, name in ipairs({ "start", "stop", "step", "applyTeam", "voices", "gains" }) do
				expect((Ambience :: any)[name]).to.equal(nil)
			end
		end)
	end)
end
