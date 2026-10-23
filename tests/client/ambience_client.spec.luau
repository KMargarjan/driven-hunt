-- ambience_client.spec: the bed's INSTANCES, in the player's own client. The pure half is
-- tests/server/ambience.spec.luau; this file is only ever about what reached the engine.
--
-- IT TAKES THE CLOCK OVER. `beforeAll` calls `Ambience.stop()`, so the live `Heartbeat` and the live
-- `Team` signal are detached and this spec is the only writer of the targets and the only driver of
-- the step; `afterAll` hands them back. THAT IS A FALSE-PASS GUARD and not tidiness: in the DEV
-- arena `MatchBoot` starts a real drive with no lobby, so the single harness player IS assigned a
-- team at some point in the run -- a case that asserted "the lodge bed is at full gain" would pass
-- or fail on the drive's phase (design section 5.5).
--
-- NOBODY HERE CAN HEAR IT. There is no audio capture in `tools/studio_mcp.py` and none is proposed.
-- Every claim here is "what reached the engine": the Sound exists, it is where it should be, it is
-- not positional, its id is the row's, and its `Volume` is the gain times the level. Whether it is
-- *"relax quuiet"* is KAREN'S, in a playtest.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/ambience.md (sections 5.5, 10, 11.2)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = require(ReplicatedStorage:WaitForChild("Ambience"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Ambience = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Ambience"))

local EPSILON = 1e-6

local function liveRows(bed: string)
	local out = {}
	for _, voice in ipairs(Shared.CONFIG.BEDS[bed].VOICES) do
		if voice.ID ~= "" then
			table.insert(out, voice)
		end
	end
	return out
end

-- Steps `seconds` of fade in 1/60 slices, the way the Heartbeat would, with no yielding.
local function run(seconds: number)
	local dt = 1 / 60
	for _ = 1, math.ceil(seconds / dt) do
		Ambience.step(dt)
	end
end

return function()
	beforeAll(function()
		Ambience.stop()
	end)

	afterAll(function()
		Ambience.start()
	end)

	describe("the voices", function()
		it("were made at MODULE LOAD, before anything asked for them", function()
			-- N2, and it is a fact about load time: once a state change has happened, "they existed
			-- before it" is otherwise unprovable. The `Hud.Sound.signalReady` shape.
			local madeAtLoad = Ambience.ready()
			expect(madeAtLoad).to.equal(true)
		end)

		it("are at most four Sounds, counted both ways", function()
			-- N1. The shipped data makes TWO: the lodge's birds and wind. The hunt row's id is
			-- empty, so it makes none.
			local mine = 0
			for _, word in ipairs(Shared.BED_WORDS) do
				mine += #Ambience.voices(word)
			end
			local inService = 0
			for _, child in ipairs(SoundService:GetChildren()) do
				if child:IsA("Sound") and string.sub(child.Name, 1, #Shared.NAME_PREFIX) == Shared.NAME_PREFIX then
					inService += 1
				end
			end
			expect(mine).to.equal(inService)
			expect(mine <= 4).to.equal(true)
			expect(#Ambience.voices("lodge")).to.equal(#liveRows("lodge"))
			expect(#Ambience.voices("hunt")).to.equal(#liveRows("hunt"))
			TestKit.note(string.format("[ambience] %d bed Sounds in SoundService", mine))
		end)

		it("carry the row's own id, loop, and hang on NOTHING", function()
			for _, word in ipairs(Shared.BED_WORDS) do
				local rows = liveRows(word)
				local made = Ambience.voices(word)
				for index, sound in ipairs(made) do
					local voice = rows[index]
					expect(sound.Name).to.equal(Shared.voiceName(word, voice))
					expect(sound.SoundId).to.equal(voice.ID)
					expect(sound.Looped).to.equal(true)
					expect(sound.Parent).to.equal(SoundService)
					-- THE NON-POSITIONAL ASSERTION, STATED AS A NEGATIVE: a bed is at the EAR. A
					-- Sound under a part is a 3D sound, which is every other sound writer in this
					-- repo and is exactly what this one is not.
					local at: Instance? = sound.Parent
					while at ~= nil do
						expect(at:IsA("BasePart")).to.equal(false)
						expect(at:IsA("Attachment")).to.equal(false)
						at = at.Parent
					end
				end
			end
		end)

		it("gets its loop window from the engine's own mechanism, or none at all", function()
			for _, word in ipairs(Shared.BED_WORDS) do
				local rows = liveRows(word)
				for index, sound in ipairs(Ambience.voices(word)) do
					local voice = rows[index]
					if voice.TO > 0 then
						local from, to = Shared.loopWindow(voice)
						expect(sound.PlaybackRegionsEnabled).to.equal(true)
						expect(sound.PlaybackRegion).to.equal(NumberRange.new(from, to))
						expect(sound.LoopRegion).to.equal(NumberRange.new(from, to))
					else
						-- `TO == 0` IS "THE WHOLE CLIP": no region, which loops everything.
						expect(sound.PlaybackRegionsEnabled).to.equal(false)
					end
				end
			end
		end)

		it("counted the silent row rather than failing on it", function()
			-- The hunt bed ships with an empty id ON PURPOSE (design section 6.3). An empty id plays
			-- nothing and is not an error -- the standing rule.
			expect(#Ambience.voices("hunt")).to.equal(0)
			expect(Ambience.stats().silent >= 1).to.equal(true)
		end)

		it("asked the engine for both assets at load, and REPORTS whether they arrived", function()
			-- N9 / N9a. `IsLoaded` is RECORDED and never asserted: a moderated or network-starved
			-- asset must not fail the suite (rule 8), and the thing that WOULD be a defect -- a bed
			-- that stops being written because its asset did not come -- is asserted below instead.
			local deadline = os.clock() + 10
			local _, preloaded = Ambience.ready()
			while not preloaded and os.clock() < deadline do
				task.wait(0.1)
				_, preloaded = Ambience.ready()
			end
			TestKit.note(string.format("[ambience] preload request finished: %s", tostring(preloaded)))
			for _, word in ipairs(Shared.BED_WORDS) do
				for _, sound in ipairs(Ambience.voices(word)) do
					TestKit.note(
						string.format(
							"[ambience] %s loaded=%s len=%.2f playing=%s",
							sound.Name,
							tostring(sound.IsLoaded),
							sound.TimeLength,
							tostring(sound.IsPlaying)
						)
					)
				end
			end
		end)
	end)

	describe("the crossfade", function()
		beforeEach(function()
			Ambience.resetStats()
		end)

		it("goes to the lodge for no team and to the hunt for either team", function()
			Ambience.applyTeam(nil)
			expect(Ambience.bed()).to.equal("lodge")
			expect(Ambience.targets().lodge).to.equal(1)
			expect(Ambience.targets().hunt).to.equal(0)
			Ambience.applyTeam("Shooters")
			expect(Ambience.bed()).to.equal("hunt")
			Ambience.applyTeam("Drivers")
			expect(Ambience.bed()).to.equal("hunt")
			Ambience.applyTeam("Spectators")
			expect(Ambience.bed()).to.equal("lodge")
		end)

		it("writes a Volume that is the gain times the level, at every step", function()
			Ambience.applyTeam("Shooters")
			run(3)
			Ambience.applyTeam(nil)
			for _ = 1, 150 do
				Ambience.step(1 / 60)
				for _, word in ipairs(Shared.BED_WORDS) do
					local rows = liveRows(word)
					local gain = Ambience.gains()[word]
					for index, sound in ipairs(Ambience.voices(word)) do
						expect(sound.Volume).to.be.near(Shared.volumeFor(gain, rows[index].LEVEL), EPSILON)
					end
				end
			end
		end)

		it("changes nothing on a zero-length step", function()
			-- INVARIANT I2 (N14), which is what makes a flip observably a pure retarget.
			Ambience.applyTeam(nil)
			run(1)
			local before = Ambience.gains()
			local volumes = {}
			for _, word in ipairs(Shared.BED_WORDS) do
				for _, sound in ipairs(Ambience.voices(word)) do
					volumes[sound.Name] = sound.Volume
				end
			end
			Ambience.applyTeam("Shooters")
			Ambience.step(0)
			for _, word in ipairs(Shared.BED_WORDS) do
				expect(Ambience.gains()[word]).to.equal(before[word])
				for _, sound in ipairs(Ambience.voices(word)) do
					expect(sound.Volume).to.equal(volumes[sound.Name])
				end
			end
		end)

		it("fades the lodge up, then across to the hunt, and says so once each", function()
			-- END TO END WITH NO YIELDING CLOCK. The hunt bed ships silent, so what is observable on
			-- its side is the GAIN; the lodge's side is observable as a Volume.
			Ambience.applyTeam("Shooters")
			run(3)
			Ambience.resetStats()
			Ambience.applyTeam(nil)
			run(Shared.CONFIG.FADE_SECONDS + 1 / 30)
			expect(Ambience.gains().lodge).to.equal(1)
			expect(Ambience.gains().hunt).to.equal(0)
			for index, sound in ipairs(Ambience.voices("lodge")) do
				expect(sound.Volume).to.be.near(liveRows("lodge")[index].LEVEL, EPSILON)
			end
			-- N15: `arrived` counts a COMPLETED fade once, not once per frame at the target. Two
			-- beds moved here (lodge up, hunt down), so two arrivals.
			expect(Ambience.stats().arrived).to.equal(2)
			run(2)
			expect(Ambience.stats().arrived).to.equal(2)

			-- ...AND BACK OUT TO THE DRIVE, through the middle.
			Ambience.resetStats()
			Ambience.applyTeam("Drivers")
			run(Shared.CONFIG.FADE_SECONDS / 2)
			expect(Ambience.gains().lodge > 0 and Ambience.gains().lodge < 1).to.equal(true)
			expect(Ambience.gains().hunt > 0 and Ambience.gains().hunt < 1).to.equal(true)
			run(Shared.CONFIG.FADE_SECONDS / 2 + 1 / 30)
			expect(Ambience.gains().lodge).to.equal(0)
			expect(Ambience.gains().hunt).to.equal(1)
			for _, sound in ipairs(Ambience.voices("lodge")) do
				expect(sound.Volume).to.equal(0)
			end
			expect(Ambience.stats().arrived).to.equal(2)
		end)

		it("reverses mid-fade from where it had got to, and never leaves the range", function()
			Ambience.applyTeam("Shooters")
			run(3)
			Ambience.applyTeam(nil)
			run(1)
			local atFlip = Ambience.gains().lodge
			expect(atFlip > 0 and atFlip < 1).to.equal(true)
			Ambience.applyTeam("Shooters")
			expect(Ambience.gains().lodge).to.equal(atFlip) -- the flip moved nothing
			Ambience.step(1 / 60)
			expect(Ambience.gains().lodge < atFlip).to.equal(true)
			for flip = 1, 20 do
				Ambience.applyTeam(if flip % 2 == 0 then nil else "Drivers")
				run(0.2)
				for _, word in ipairs(Shared.BED_WORDS) do
					local gain = Ambience.gains()[word]
					expect(gain >= 0 and gain <= 1).to.equal(true)
				end
			end
		end)

		it("writes the Volume even for a voice whose asset never loaded", function()
			-- N9a's real content: a bed that stops being written because its download failed WOULD
			-- be a defect, and this is the case that would catch it. The write is unconditional.
			Ambience.applyTeam(nil)
			run(Shared.CONFIG.FADE_SECONDS + 1 / 30)
			for index, sound in ipairs(Ambience.voices("lodge")) do
				expect(sound.Volume).to.be.near(liveRows("lodge")[index].LEVEL, EPSILON)
			end
		end)
	end)

	describe("the owner", function()
		it("starts and stops idempotently, and keeps the fade across it", function()
			-- N10: `stop(); stop(); start(); start()` leaves one connection's worth of behaviour and
			-- does not reset the gains.
			Ambience.applyTeam(nil)
			run(1)
			local held = Ambience.gains().lodge
			Ambience.start()
			Ambience.start()
			expect(Ambience.running()).to.equal(true)
			Ambience.stop()
			Ambience.stop()
			expect(Ambience.running()).to.equal(false)
			-- `start`'s own `refresh` may have retargeted off the live team; the GAIN is what must
			-- survive, and it is the thing a restart must not throw away.
			expect(Ambience.gains().lodge).to.equal(held)
		end)

		it("touches nothing it is not the owner of", function()
			-- SECTION 2 AND SECTION 8, each one `string.find` -- the cheap kind of assertion that
			-- keeps an owner boundary from drifting across the next ten tasks.
			local source = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Ambience") :: ModuleScript
			local text = source.Source
			expect(#text > 0).to.equal(true)
			for _, banned in ipairs({
				"AmbientReverb",
				"SoundService.Volume",
				"Workspace",
				".Magnitude",
				"Vector3",
				"Lobby",
				"TweenService",
				"RemoteEvent",
				"EXPECTED_WORLD",
			}) do
				expect(string.find(text, banned, 1, true)).to.equal(nil)
			end
			-- ...AND IT IS NOT A SECOND WRITER OF KAREN'S OWN AMBIENCE. `Workspace.Ambience` is her
			-- Studio-made Sound in the Forest Test and has no owner in git; this module may not
			-- find it, reparent it or write its Volume. The DEV arena has none, so the assertion
			-- that can be made everywhere is the one above -- the word does not appear at all.
			local mine: { [string]: boolean } = {}
			for _, word in ipairs(Shared.BED_WORDS) do
				for _, sound in ipairs(Ambience.voices(word)) do
					mine[sound.Name] = true
				end
			end
			for _, child in ipairs(SoundService:GetChildren()) do
				if child:IsA("Sound") and string.sub(child.Name, 1, #Shared.NAME_PREFIX) == Shared.NAME_PREFIX then
					expect(mine[child.Name]).to.equal(true)
				end
			end
		end)
	end)
end
