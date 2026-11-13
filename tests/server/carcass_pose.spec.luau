-- carcass_pose.spec: the SERVER half of task 358 -- the one thing the server tells every client
-- about a dead animal's drawn pose, and the one place it says it.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- WHY IT EXISTS. Karen, 2026-11-10: "animal died and then stand and then again die". MEASURED in
-- her Forest Test before a line was written (`<runs-dir>/358-bind.luau`): a client whose rig is
-- drawing NO pose shows the BIND pose -- hind 1.05 -> 4.94 studs of drawn bone span -- and it never
-- recovers, 3 of 3 still standing after 12 s. The client cannot ask for the clip: the ids live in
-- `ServerStorage.Assets`, which does not replicate. So the carcass carries it.
--
-- Design: docs/design/carcass-pose.md sections 5, 11.1 · Note: docs/research/2026-11-13-carcass-pose.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local CarcassData = require(ReplicatedStorage:WaitForChild("Carcass"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

return function()
	describe("Carcass, the published format", function()
		it("round-trips a real pose and refuses everything that is not one", function()
			local value = CarcassData.format(131795481631371, 3.97)
			expect(value).to.equal("131795481631371:3.9700")
			local id, at = CarcassData.parse(value)
			expect(id).to.equal(131795481631371)
			expect(at).to.be.near(3.97, 1e-4)
			-- A FRAME OF 0 IS A REAL FRAME (a deer's fall can be held at 0 only in theory, but the
			-- parser may not invent a reason to refuse it); an id of 0 is not.
			expect(CarcassData.format(12, 0)).to.equal("12:0.0000")
			expect(CarcassData.format(0, 1)).to.equal("")
			expect(CarcassData.format(-3, 1)).to.equal("")
			expect(CarcassData.format(12, -0.1)).to.equal("")
			expect(CarcassData.format(nil, 1)).to.equal("")
			expect(CarcassData.format(12, nil)).to.equal("")
			expect(CarcassData.format("12", "1")).to.equal("")
			expect(CarcassData.format(math.huge, 1)).to.equal("")
			expect(CarcassData.format(12, math.huge)).to.equal("")
			for _, bad in ipairs({ "", "abc", "12:", ":3", "12:3:4", "12", " ", "0:3", "12:-3" }) do
				local badId, badAt = CarcassData.parse(bad)
				expect(badId).to.equal(nil)
				expect(badAt).to.equal(nil)
			end
			expect((CarcassData.parse(nil))).to.equal(nil)
			expect((CarcassData.parse(12))).to.equal(nil)
			expect((CarcassData.parse({}))).to.equal(nil)
			expect(CarcassData.contentId(12)).to.equal("rbxassetid://12")
			expect(CarcassData.ATTRIBUTE).to.equal("DeathPose")
		end)
	end)

	describe("the carcass publishes the pose the server froze", function()
		local CONFIG = Boar.CONFIG

		-- A FIELD CAN BE CLEARED AS WELL AS SET: `pairs` cannot see a `nil` in an override table, so
		-- `{ visual = nil }` is an empty table and the case it was written for never ran (round 1 of
		-- this task's own harness caught exactly that).
		local NONE = newproxy()

		-- The fields `Body.stepVisual` reads and nothing else, exactly as `boar_model.spec`'s own
		-- `carcass293` does, so these cases drive the REAL writer and not a copy of its rule.
		local function carcass(clip: string, track, over)
			local handle: any = {
				part = Instance.new("Part"),
				visual = Instance.new("Model"),
				collapsed = true,
				toppled = false,
				reasserted = true,
				deadFor = 0,
				clip = clip,
				heldClip = clip,
				heldAt = nil,
				reholds = 0,
				tracks = { [clip] = track },
				hitFor = 0,
				hitFromBehind = false,
				clipHeldFor = 0,
				exitFor = 0,
				activityFor = 0,
				paddleFor = 0,
				warmFor = 0,
				yawRate = 0,
				rateWrites = 0,
			}
			for key, value in pairs(over or {}) do
				handle[key] = if value == NONE then nil else value
			end
			return handle
		end

		local function heldTrack(len: number)
			local track: any = {
				Length = len,
				TimePosition = len - 0.03,
				Speed = 0,
				WeightCurrent = 1,
				IsPlaying = true,
				Looped = false,
			}
			function track:Play(_fade, weight, speed)
				self.IsPlaying = true
				self.WeightCurrent = weight or 1
				self.Speed = speed or 1
				self.TimePosition = 0
			end
			function track:AdjustSpeed(speed)
				self.Speed = speed
			end
			function track:Stop() end
			return track
		end

		-- A config whose MODEL block is this case's own, so `PUBLISH_DEATH_POSE` and the ids can be
		-- set BY PARAMETER while the flag row sits at `false` (the harness refuses an override).
		local function configWith(publish: boolean, ids)
			local config = table.clone(CONFIG)
			config.MODEL = table.clone(CONFIG.MODEL)
			config.MODEL.PUBLISH_DEATH_POSE = publish
			config.MODEL.ANIMATION_IDS = ids
			return config
		end

		it("writes DeathPose where the death is frozen, and only there (FAILS with the block deleted)", function()
			local fall = (Boar.deathClips(CONFIG))
			local len = CONFIG.MODEL.CLIPS[fall].seconds
			local config = configWith(true, { [fall] = 131795481631371 })
			local handle = carcass(fall, heldTrack(len), { heldAt = len - CONFIG.MODEL.HOLD_EPSILON })
			expect(handle.part:GetAttribute(CarcassData.ATTRIBUTE)).to.equal(nil)
			Boar.stepVisual(handle, 1 / 60, { speed = 0 }, config)
			local value = handle.part:GetAttribute(CarcassData.ATTRIBUTE)
			expect(typeof(value)).to.equal("string")
			local id, at = CarcassData.parse(value)
			expect(id).to.equal(131795481631371)
			expect(at).to.be.near(len - CONFIG.MODEL.HOLD_EPSILON, 1e-4)
		end)

		it("is read-compare-write: 200 steps that change nothing write the attribute once", function()
			local fall = (Boar.deathClips(CONFIG))
			local len = CONFIG.MODEL.CLIPS[fall].seconds
			local config = configWith(true, { [fall] = 131795481631371 })
			local handle = carcass(fall, heldTrack(len), { heldAt = len - CONFIG.MODEL.HOLD_EPSILON })
			local writes = 0
			handle.part:GetAttributeChangedSignal(CarcassData.ATTRIBUTE):Connect(function()
				writes += 1
			end)
			for _ = 1, 200 do
				Boar.stepVisual(handle, 1 / 60, { speed = 0 }, config)
			end
			task.wait()
			expect(writes).to.equal(1)
		end)

		it("re-publishes when the PADDLE supersedes the fall, as one untearable string", function()
			local fall, paddle = Boar.deathClips(CONFIG)
			expect(paddle).never.to.equal(fall)
			local fallLen = CONFIG.MODEL.CLIPS[fall].seconds
			local paddleLen = CONFIG.MODEL.CLIPS[paddle].seconds
			local config = configWith(true, { [fall] = 111, [paddle] = 222 })
			local handle = carcass(fall, heldTrack(fallLen), { heldAt = fallLen - CONFIG.MODEL.HOLD_EPSILON })
			Boar.stepVisual(handle, 1 / 60, { speed = 0 }, config)
			local firstId = (CarcassData.parse(handle.part:GetAttribute(CarcassData.ATTRIBUTE)))
			expect(firstId).to.equal(111)
			-- The paddle is now the held clip, at its own frame.
			handle.heldClip = paddle
			handle.clip = paddle
			handle.tracks[paddle] = heldTrack(paddleLen)
			handle.heldAt = paddleLen - CONFIG.MODEL.HOLD_EPSILON
			Boar.stepVisual(handle, 1 / 60, { speed = 0 }, config)
			local id, at = CarcassData.parse(handle.part:GetAttribute(CarcassData.ATTRIBUTE))
			-- BOTH HALVES MOVED TOGETHER: an id from one clip with the other's frame is the torn
			-- pair one attribute exists to make impossible.
			expect(id).to.equal(222)
			expect(at).to.be.near(paddleLen - CONFIG.MODEL.HOLD_EPSILON, 1e-4)
		end)

		it("publishes nothing with the flag off, no visual, a topple, no id, a live animal or a gait", function()
			local fall = (Boar.deathClips(CONFIG))
			local len = CONFIG.MODEL.CLIPS[fall].seconds
			local held = len - CONFIG.MODEL.HOLD_EPSILON
			local function attributeAfter(config, over)
				local handle = carcass(fall, heldTrack(len), over)
				Boar.stepVisual(handle, 1 / 60, { speed = 0 }, config)
				return handle.part:GetAttribute(CarcassData.ATTRIBUTE)
			end
			local ids = { [fall] = 131795481631371 }
			-- OFF is byte for byte today's world.
			expect(attributeAfter(configWith(false, ids), { heldAt = held })).to.equal(nil)
			-- No rig at all (BOAR_MODEL off): `stepVisual` returns before the write.
			expect(attributeAfter(configWith(true, ids), { heldAt = held, visual = NONE })).to.equal(nil)
			-- The BOX laid this one down: a client clip over a rolled box is task 150's carcass
			-- buried upside down, and the attribute is what would invite it.
			expect(attributeAfter(configWith(true, ids), { heldAt = held, toppled = true })).to.equal(nil)
			-- The clip was never published, so there is no id to tell anybody.
			expect(attributeAfter(configWith(true, {}), { heldAt = held })).to.equal(nil)
			-- Alive.
			expect(attributeAfter(configWith(true, ids), { heldAt = held, collapsed = false })).to.equal(nil)
			-- Dead, but the held clip is not a death (nothing froze yet).
			expect(attributeAfter(configWith(true, ids), { heldAt = held, heldClip = "walk", clip = "walk" })).to.equal(
				nil
			)
			-- Dead and the death is held, but no frame was ever written.
			expect(attributeAfter(configWith(true, ids), { heldAt = NONE })).to.equal(nil)
		end)

		it("THE INVARIANT: a carcass carrying DeathPose can never be toppled afterwards", function()
			-- The attribute is only written where the freeze happened, and the freeze only happens to
			-- a track that reached the end of its own clip -- so `Body.shouldBackstopDeath` is
			-- already false for the rest of that carcass's life. This asserts it rather than
			-- describing it: the box cannot roll under a client's clip.
			local fall = (Boar.deathClips(CONFIG))
			local len = CONFIG.MODEL.CLIPS[fall].seconds
			local config = configWith(true, { [fall] = 131795481631371 })
			local handle = carcass(fall, heldTrack(len), { heldAt = len - CONFIG.MODEL.HOLD_EPSILON })
			Boar.stepVisual(handle, 1 / 60, { speed = 0 }, config)
			expect(handle.part:GetAttribute(CarcassData.ATTRIBUTE)).never.to.equal(nil)
			-- The attribute was written because a death clip was HELD, which means that clip reached
			-- the end of itself -- so `Body.deathDrawn` is true for the frame it is held at, and the
			-- backstop answers `false` for every later moment, armed or not.
			local held = handle.heldAt
			expect(Boar.deathDrawn(held, len)).to.equal(true)
			local backstop = CONFIG.WOUND.DEATH_BACKSTOP_SECONDS
			expect(typeof(backstop)).to.equal("number")
			for i = 1, 10 do
				expect(Boar.shouldBackstopDeath(backstop * i, true, true, false, CONFIG.WOUND)).to.equal(false)
			end
			expect(handle.toppled).to.equal(false)
			TestKit.note(
				string.format("carcass-pose: published %s", tostring(handle.part:GetAttribute(CarcassData.ATTRIBUTE)))
			)
		end)

		it("the flag row is born OFF, owned, and expires inside 21 days", function()
			local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
			local row = Flags.DEFAULTS.CARCASS_POSE
			expect(row).never.to.equal(nil)
			expect(row.default).to.equal(false)
			expect(row.born).to.equal("2026-11-13")
			expect(row.owner).to.equal("src/client/CarcassPoseBoot.client.luau")
			-- The live config read the row at its boundary, which is the only permitted shape.
			expect(typeof(CONFIG.MODEL.PUBLISH_DEATH_POSE)).to.equal("boolean")
			expect(CONFIG.MODEL.PUBLISH_DEATH_POSE).to.equal(Flags.isOn("CARCASS_POSE"))
		end)
	end)
end
