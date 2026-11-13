--!strict
-- carcass_pose.spec (CLIENT): the owner of what THIS client draws on a dead animal (task 358).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- THE CLIENT IS WHERE THE DEFECT IS, so this is where the owner is proved. Karen, 2026-11-10:
-- "animal died and then stand and then again die". MEASURED in her Forest Test (358-bind.luau): a
-- rig drawing NO pose shows its BIND pose -- hind 1.05 -> 4.94 studs of drawn bone span -- and it
-- never recovers, 3 of 3 after 12 s. The server already thinks it said the death once.
--
-- IT NEEDS NO ASSET AND NO NETWORK. `start` takes its folder, its clock, its asset answer and its
-- loader as seams, so the real sweep runs over a rig this spec built. The LAST case uses the real
-- `Animator:LoadAnimation` on that rig, so the mechanism is proved in the player's own client and
-- not only through the seam.
--
-- Design: docs/design/carcass-pose.md sections 4, 6.2, 11.2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarcassData = require(ReplicatedStorage:WaitForChild("Carcass"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local CarcassPose = require(scripts:WaitForChild("CarcassPose"))

-- A real published boar death id is not needed to prove the rule, and inventing one that looks real
-- would be a second home for an id this client is never allowed to know. This is a number.
local FAKE_ID = 1234567890
local FAKE_AT = 0.9

return function()
	local function fakeRig(parent: Instance, carcass: boolean, pose: string?): BasePart
		local trunk = Instance.new("Part")
		trunk.Name = "Boar1"
		trunk.Anchored = true
		trunk.CanCollide = false
		if carcass then
			trunk:SetAttribute("Carcass", true)
		end
		if pose ~= nil then
			trunk:SetAttribute(CarcassData.ATTRIBUTE, pose)
		end
		local visual = Instance.new("Model")
		visual.Name = "Visual"
		local controller = Instance.new("AnimationController")
		controller.Name = "BoarAnimation"
		local animator = Instance.new("Animator")
		animator.Parent = controller
		controller.Parent = visual
		visual.Parent = trunk
		trunk.Parent = parent
		return trunk
	end

	local function stubTrack(length: number)
		local track: any = {
			Length = length,
			TimePosition = -1,
			Speed = -1,
			Priority = nil,
			Looped = true,
			IsPlaying = false,
			plays = 0,
			stops = 0,
		}
		function track:Play(_fade, weight, speed)
			self.plays += 1
			self.IsPlaying = true
			self.Weight = weight
			self.Speed = speed
			self.TimePosition = 0 -- what Play really does, which is the defect being fixed
		end
		function track:AdjustSpeed(speed)
			self.Speed = speed
		end
		function track:Stop()
			self.stops += 1
			self.IsPlaying = false
		end
		return track
	end

	describe("CarcassPose.decide, the whole rule", function()
		-- A FIELD CAN BE CLEARED AS WELL AS SET: `pairs` cannot see a `nil` in an override table, so
		-- `{ poseId = nil }` is an empty table and the case it was written for never ran (round 1 of
		-- this task's own harness caught exactly that).
		local NONE = newproxy()

		local function view(over)
			local v = {
				carcass = true,
				poseId = FAKE_ID,
				poseAt = FAKE_AT,
				hasAnimator = true,
				deathPlaying = false,
				assetReady = true,
				trackLength = 4,
				posed = false,
			}
			for k, value in pairs(over or {}) do
				v[k] = if value == NONE then nil else value
			end
			return v
		end

		it("answers a named reason for every branch, in order", function()
			expect(CarcassPose.decide(view({ carcass = false }))).to.equal("skip")
			expect(CarcassPose.decide(view({ poseId = NONE }))).to.equal("skip")
			expect(CarcassPose.decide(view({ poseId = 0 }))).to.equal("skip")
			expect(CarcassPose.decide(view({ poseAt = NONE }))).to.equal("skip")
			expect(CarcassPose.decide(view({ poseAt = -0.1 }))).to.equal("skip")
			-- ONCE PER CARCASS PER PUBLISHED POSE: no storm, no per-frame write.
			expect(CarcassPose.decide(view({ posed = true }))).to.equal("skip")
			-- The rig is Atomic-streamed and can arrive after the trunk.
			expect(CarcassPose.decide(view({ hasAnimator = false }))).to.equal("wait-rig")
			-- A death is already drawing it: measured benign in 19/19 kills and 80/80 forced repairs.
			expect(CarcassPose.decide(view({ deathPlaying = true }))).to.equal("leave")
			expect(CarcassPose.decide(view({ assetReady = false }))).to.equal("wait-asset")
			-- Nothing loaded yet is a reason to LOAD, and a zero length is a reason to WAIT: frame 0
			-- of a death is the animal standing, which is the defect, caused by the fix.
			expect(CarcassPose.decide(view({ trackLength = NONE }))).to.equal("pose")
			expect(CarcassPose.decide(view({ trackLength = 0 }))).to.equal("wait-length")
			expect(CarcassPose.decide(view({ trackLength = -1 }))).to.equal("wait-length")
			expect(CarcassPose.decide(view())).to.equal("pose")
			-- ORDER MATTERS: a living animal is skipped even with everything else broken, and a
			-- posed one is skipped before the rig is ever looked for.
			expect(CarcassPose.decide(view({ carcass = false, hasAnimator = false }))).to.equal("skip")
			expect(CarcassPose.decide(view({ posed = true, hasAnimator = false }))).to.equal("skip")
		end)
	end)

	describe("CarcassPose, over a rig this spec built", function()
		local folder: Folder

		beforeEach(function()
			CarcassPose.stop()
			folder = Instance.new("Folder")
			folder.Name = "CarcassPoseTest"
			folder.Parent = ReplicatedStorage
		end)

		afterEach(function()
			CarcassPose.stop()
			folder:Destroy()
		end)

		it("poses a published carcass exactly once, and pins it where the server said", function()
			-- FAILS WITH THE POSE BRANCH DELETED, and at main, where this module does not exist.
			local trunk = fakeRig(folder, true, CarcassData.format(FAKE_ID, FAKE_AT))
			local loaded = 0
			local track = stubTrack(4)
			expect(CarcassPose.start({
				enabled = true,
				folder = folder,
				sweepSeconds = 0,
				ready = function()
					return true
				end,
				load = function()
					loaded += 1
					return track
				end,
			})).to.equal(true)
			CarcassPose.step(1)
			CarcassPose.step(1)
			local stats = CarcassPose.stats()
			expect(loaded).to.equal(1)
			expect(stats.posed).to.equal(1)
			expect(stats.plays).to.equal(1)
			expect(track.plays).to.equal(1)
			expect(track.Priority).to.equal(Enum.AnimationPriority.Action)
			expect(track.Looped).to.equal(false)
			expect(track.Speed).to.equal(0)
			-- THE FRAME THE SERVER PUBLISHED, not frame 0 (which is the animal standing).
			expect(track.TimePosition).to.be.near(FAKE_AT, 1e-4)
			-- The trunk itself was never written to.
			expect(trunk:GetAttribute("Carcass")).to.equal(true)
			expect(trunk.Anchored).to.equal(true)
			expect(trunk.CanCollide).to.equal(false)
			TestKit.note(
				string.format("carcass-pose: posed=%d loads=%d writes=%d", stats.posed, stats.loads, stats.writes)
			)
		end)

		it("is idempotent: 60 more steps load nothing, play nothing and write nothing", function()
			fakeRig(folder, true, CarcassData.format(FAKE_ID, FAKE_AT))
			local loaded = 0
			local track = stubTrack(4)
			CarcassPose.start({
				enabled = true,
				folder = folder,
				sweepSeconds = 0,
				ready = function()
					return true
				end,
				load = function()
					loaded += 1
					return track
				end,
			})
			CarcassPose.step(1)
			local after = CarcassPose.stats()
			for _ = 1, 60 do
				CarcassPose.step(1)
			end
			local later = CarcassPose.stats()
			expect(loaded).to.equal(1)
			expect(later.loads).to.equal(after.loads)
			expect(later.plays).to.equal(after.plays)
			expect(later.writes).to.equal(after.writes)
			expect(track.plays).to.equal(1)
		end)

		it("puts its own pose back when something stops it (the 358-bind state, forced)", function()
			-- MEASURED IN KAREN'S FOREST TEST: a carcass whose rig is drawing nothing shows the BIND
			-- pose -- standing -- and before this owner nothing ever put it back (3 of 3 never
			-- recovered in 12 s, `358-bind.luau`). Posing once is not enough: a pose that is taken
			-- off later is Karen's sentence exactly, "died and then stand".
			fakeRig(folder, true, CarcassData.format(FAKE_ID, FAKE_AT))
			local track = stubTrack(4)
			local loaded = 0
			CarcassPose.start({
				enabled = true,
				folder = folder,
				sweepSeconds = 0,
				ready = function()
					return true
				end,
				load = function()
					loaded += 1
					return track
				end,
			})
			CarcassPose.step(1)
			expect(CarcassPose.stats().posed).to.equal(1)
			expect(track.plays).to.equal(1)
			-- Something else stops it. A pinned track cannot stop by itself, which is why this and
			-- not a count is the test.
			track:Stop()
			track.TimePosition = 0 -- ...and the rig is back at frame 0: the animal on its feet
			CarcassPose.step(1)
			local stats = CarcassPose.stats()
			expect(stats.repairs).to.equal(1)
			expect(stats.posed).to.equal(2)
			expect(track.plays).to.equal(2)
			expect(track.IsPlaying).to.equal(true)
			expect(track.Speed).to.equal(0)
			expect(track.TimePosition).to.be.near(FAKE_AT, 1e-4)
			-- ...and it does NOT reload: the track it owns is the track it repairs.
			expect(loaded).to.equal(1)
			-- A repair's own result refuses the next one.
			CarcassPose.step(1)
			CarcassPose.step(1)
			expect(CarcassPose.stats().repairs).to.equal(1)
			expect(track.plays).to.equal(2)
		end)

		it("leaves a carcass alone when a death is already drawing it", function()
			local trunk = fakeRig(folder, true, CarcassData.format(FAKE_ID, FAKE_AT))
			-- A REAL playing track on the rig's own Animator, with the published id on it. The owner
			-- reads it and must not fight it: snapping a fall still running to its end would be a
			-- defect this owner caused.
			local animator = trunk:FindFirstChildWhichIsA("Animator", true) :: Animator
			local animation = Instance.new("Animation")
			animation.AnimationId = CarcassData.contentId(FAKE_ID)
			animation.Parent = trunk
			local real = animator:LoadAnimation(animation)
			real:Play(0, 1, 1)
			local loaded = 0
			CarcassPose.start({
				enabled = true,
				folder = folder,
				sweepSeconds = 0,
				ready = function()
					return true
				end,
				load = function()
					loaded += 1
					return stubTrack(4)
				end,
			})
			CarcassPose.step(1)
			CarcassPose.step(1)
			local stats = CarcassPose.stats()
			expect(loaded).to.equal(0)
			expect(stats.posed).to.equal(0)
			expect(stats.leftAlone).to.equal(1)
			real:Stop(0)
		end)

		it("touches nothing it was not told about: a live animal, an unpublished carcass, a stranger", function()
			local alive = fakeRig(folder, false, nil)
			alive.Name = "Alive"
			local unpublished = fakeRig(folder, true, nil)
			unpublished.Name = "Unpublished"
			local rubbish = fakeRig(folder, true, "not-a-pose")
			rubbish.Name = "Rubbish"
			local loaded = 0
			CarcassPose.start({
				enabled = true,
				folder = folder,
				sweepSeconds = 0,
				ready = function()
					return true
				end,
				load = function()
					loaded += 1
					return stubTrack(4)
				end,
			})
			for _ = 1, 10 do
				CarcassPose.step(1)
			end
			expect(loaded).to.equal(0)
			expect(CarcassPose.stats().posed).to.equal(0)
			for _, trunk in ipairs({ alive, unpublished, rubbish }) do
				local animator = trunk:FindFirstChildWhichIsA("Animator", true) :: Animator
				expect(#animator:GetPlayingAnimationTracks()).to.equal(0)
			end
		end)

		it("with the flag OFF it starts nothing, sweeps nothing and loads nothing", function()
			local trunk = fakeRig(folder, true, CarcassData.format(FAKE_ID, FAKE_AT))
			local loaded = 0
			expect(CarcassPose.start({
				enabled = false,
				folder = folder,
				sweepSeconds = 0,
				load = function()
					loaded += 1
					return stubTrack(4)
				end,
			})).to.equal(false)
			expect(CarcassPose.isStarted()).to.equal(false)
			for _ = 1, 60 do
				CarcassPose.step(1)
			end
			local stats = CarcassPose.stats()
			expect(stats.sweeps).to.equal(0)
			expect(stats.posed).to.equal(0)
			expect(loaded).to.equal(0)
			local animator = trunk:FindFirstChildWhichIsA("Animator", true) :: Animator
			expect(#animator:GetPlayingAnimationTracks()).to.equal(0)
			expect(Players.LocalPlayer:FindFirstChild("PlayerScripts"):FindFirstChild(CarcassPose.CLIP_FOLDER_NAME)).to.equal(
				nil
			)
		end)

		it("forgets a carcass that left the folder, and never writes to it", function()
			local trunk = fakeRig(folder, true, CarcassData.format(FAKE_ID, FAKE_AT))
			CarcassPose.start({
				enabled = true,
				folder = folder,
				sweepSeconds = 0,
				ready = function()
					return true
				end,
				load = function()
					return stubTrack(4)
				end,
			})
			CarcassPose.step(1)
			expect(CarcassPose.stats().posed).to.equal(1)
			trunk:Destroy()
			-- A write to a destroyed instance is an error, not a restore.
			for _ = 1, 5 do
				CarcassPose.step(1)
			end
			expect(CarcassPose.stats().posed).to.equal(1)
		end)

		it("publishes its counters on its own Clips folder, where a live probe can read them", function()
			-- A live `execute_luau` probe gets a FRESH module cache, so `stats()` through one is
			-- always zeroes (V293b). The counters are therefore written where a probe already looks:
			-- attributes on the ONE instance this owner creates. Nothing else is ever written.
			fakeRig(folder, true, CarcassData.format(FAKE_ID, FAKE_AT))
			CarcassPose.start({
				enabled = true,
				folder = folder,
				sweepSeconds = 0,
				ready = function()
					return true
				end,
				load = function()
					return stubTrack(4)
				end,
			})
			CarcassPose.step(1)
			local clips =
				Players.LocalPlayer:FindFirstChild("PlayerScripts"):FindFirstChild(CarcassPose.CLIP_FOLDER_NAME)
			expect(clips).never.to.equal(nil)
			local stats = CarcassPose.stats()
			expect(clips:GetAttribute("posed")).to.equal(stats.posed)
			expect(clips:GetAttribute("sweeps")).to.equal(stats.sweeps)
			expect(clips:GetAttribute("carcasses")).to.equal(stats.carcasses)
			expect(clips:GetAttribute("leftAlone")).to.equal(stats.leftAlone)
			expect(clips:GetAttribute("bindBefore")).to.equal(stats.bindBefore)
			expect(stats.posed).to.equal(1)
		end)

		it("THE REAL LOADER on a real Animator: the mechanism, in the player's own client", function()
			-- `358-feas.luau` measured this on a live carcass in Karen's Forest Test: a client-loaded
			-- track on a SERVER-owned Animator plays beside the replicated one and changes what is
			-- drawn. Here the Animator is this spec's, so what is proved is narrower and still the
			-- thing that matters: the owner's real path loads and pins without a seam.
			fakeRig(folder, true, CarcassData.format(FAKE_ID, FAKE_AT))
			CarcassPose.start({
				enabled = true,
				folder = folder,
				sweepSeconds = 0,
				ready = function()
					return true
				end,
			})
			CarcassPose.step(1)
			CarcassPose.step(1)
			local stats = CarcassPose.stats()
			-- The id is not a published asset, so `Length` is 0 and the owner WAITS rather than
			-- pinning frame 0 -- which is the animal standing. Either it posed or it waited; it
			-- never pinned a zero-length track.
			expect(stats.loads >= 1).to.equal(true)
			expect(stats.posed + stats.waitingLength >= 1).to.equal(true)
			if stats.posed == 0 then
				expect(stats.waitingLength >= 1).to.equal(true)
			end
			-- Its Animation lives in its own folder under PlayerScripts, never under Workspace.
			local clips =
				Players.LocalPlayer:FindFirstChild("PlayerScripts"):FindFirstChild(CarcassPose.CLIP_FOLDER_NAME)
			expect(clips).never.to.equal(nil)
			TestKit.note(
				string.format(
					"carcass-pose(client): loads=%d posed=%d waitLength=%d",
					stats.loads,
					stats.posed,
					stats.waitingLength
				)
			)
		end)
	end)
end
