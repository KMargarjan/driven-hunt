-- match_safety.spec: the safety rule. Two halves, and the split is the design's (section 8):
--
--   * Match.Penalty is PURE, so every case the rule has to get right is a table and a number here --
--     including the two the game would be broken by: a shot that hits a driver, and a clean kill on a
--     boar with a driver far behind it, in line.
--   * Match.Body actually freezes somebody, and that half runs against a RIG THIS SPEC BUILDS, at
--     y = 700, never against the one real player in the Play session. Half the client suite is
--     standing in that player, and "a spec that revoked this gun mid-session broke exactly this
--     window, and was withdrawn" is already written in tests/client/weapon_client.spec.luau (Task 34).
--     The real tie, on the real player, is tests/client/zz_tie_to_a_tree.spec.luau in a two-player run.
--
-- THE NUMBERS ARE WRITTEN OUT rather than read from Match.CONFIG (the convention
-- tests/server/test_arena.spec.luau set), so a config that disagrees with the design is a finding and
-- not a tautology. The last describe is what compares the two.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 8.1, 8.3, 8.4, 11.4, 12.3)
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Body = Match.Body
local Penalty = Match.Penalty

-- The design's numbers, by hand.
local CONFIG = {
	SAFETY_MISS_STUDS = 12,
	SAFETY_RANGE_STUDS = 330,
	SAFETY_BODY_STUDS = 4,
	SAFETY_GRACE_SECONDS = 0,
	TIE_UNTIL_DRIVE_END = true,
	TIE_SECONDS = 60,
	TIE_GAP_STUDS = 2.5,
	STAND_HEIGHT_STUDS = 3.5,
	ROPE_COLOR = Color3.fromRGB(170, 130, 85),
	ROPE_THICKNESS = 0.3,
}

local SHOOTER = 11
local DRIVER = 22
local OTHER = 33

-- A shot from the origin straight up +Z, which is the direction the arena's drive line points: the
-- drivers are at +Z of the posts, so this is the shot the rule is about.
local function shotUpZ(stopAt: number): Penalty.Shot
	return { userId = SHOOTER, muzzle = Vector3.zero, aim = Vector3.new(0, 0, 1), stopAt = stopAt, at = 0 }
end

local function driverAt(userId: number, x: number, z: number): Penalty.DriverPos
	return { userId = userId, position = Vector3.new(x, 0, z) }
end

local function rig(name: string, at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Position = at
	root.Anchored = true
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Position = at + Vector3.new(0, 1.5, 0)
	head.Anchored = true
	head.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

return function()
	describe("Penalty.judge -- did that shot endanger a driver", function()
		it("ties a shot that passed straight through where a driver stood", function()
			local guilty, reason = Penalty.judge(shotUpZ(100), { driverAt(DRIVER, 0, 50) }, CONFIG)
			expect(guilty).to.equal(true)
			expect(reason).to.equal("driver-in-line")
		end)

		it("does NOT tie a shot that stopped in the boar in front of him", function()
			-- The case that decides whether Karen calls this broken: a clean kill at 40 studs with a
			-- driver 50 studs out, in line. The pellets never got near him.
			local guilty = Penalty.judge(shotUpZ(40), { driverAt(DRIVER, 0, 50) }, CONFIG)
			expect(guilty).to.equal(false)
		end)

		it("ties a shot that HIT a driver, which stops a stud in front of his root", function()
			-- SAFETY_BODY_STUDS exists for exactly this and nothing else. A direct hit stops on the
			-- SURFACE, so stopAt is less than the distance to the root -- and with the design's bare
			-- `t <= stopAt` a point-blank shot at a driver would have been judged harmless.
			-- reviews/task-35/DESIGN_DELTA.md.
			expect(Penalty.judge(shotUpZ(39.1), { driverAt(DRIVER, 0, 40) }, CONFIG)).to.equal(true)
			-- ...and the allowance is a person, not a licence: 4 studs, no more.
			expect(Penalty.judge(shotUpZ(35), { driverAt(DRIVER, 0, 40) }, CONFIG)).to.equal(false)
		end)

		it("measures the miss at exactly SAFETY_MISS_STUDS and one tenth outside it", function()
			expect(Penalty.judge(shotUpZ(100), { driverAt(DRIVER, 12, 50) }, CONFIG)).to.equal(true)
			expect(Penalty.judge(shotUpZ(100), { driverAt(DRIVER, 12.1, 50) }, CONFIG)).to.equal(false)
		end)

		it("ignores a driver behind the muzzle, however close", function()
			expect(Penalty.judge(shotUpZ(100), { driverAt(DRIVER, 0, -20) }, CONFIG)).to.equal(false)
			expect(Penalty.judge(shotUpZ(100), { driverAt(DRIVER, 0, -1) }, CONFIG)).to.equal(false)
		end)

		it("ignores a driver past the ammo's range, whatever the shot claims", function()
			-- reach is capped by SAFETY_RANGE_STUDS: a slug does not arrive at 400 studs.
			expect(Penalty.judge(shotUpZ(500), { driverAt(DRIVER, 0, 400) }, CONFIG)).to.equal(false)
			expect(Penalty.judge(shotUpZ(500), { driverAt(DRIVER, 0, 320) }, CONFIG)).to.equal(true)
		end)

		it("never punishes the shooter for himself", function()
			-- It cannot happen in v1 (a driver carries no gun) but it can the day DRIVERS_MAY_SHOOT is
			-- true, and the design says there is no exception to add then.
			expect(Penalty.judge(shotUpZ(100), { driverAt(SHOOTER, 0, 50) }, CONFIG)).to.equal(false)
		end)

		it("answers false for no drivers and for a degenerate aim, and never errors", function()
			expect(Penalty.judge(shotUpZ(100), {}, CONFIG)).to.equal(false)
			local zero = { userId = SHOOTER, muzzle = Vector3.zero, aim = Vector3.zero, stopAt = 100, at = 0 }
			expect(Penalty.judge(zero, { driverAt(DRIVER, 0, 50) }, CONFIG)).to.equal(false)
		end)

		it("is one violation for two drivers in the line, not two", function()
			local guilty, reason =
				Penalty.judge(shotUpZ(200), { driverAt(OTHER, 90, 50), driverAt(DRIVER, 0, 60) }, CONFIG)
			expect(guilty).to.equal(true)
			expect(reason).to.equal("driver-in-line")
		end)

		it("does not need a unit aim to be given one", function()
			local long = { userId = SHOOTER, muzzle = Vector3.zero, aim = Vector3.new(0, 0, 7), stopAt = 100, at = 0 }
			expect(Penalty.judge(long, { driverAt(DRIVER, 0, 50) }, CONFIG)).to.equal(true)
		end)
	end)

	describe("Penalty.expired -- how long the tie lasts", function()
		it("never expires with Karen's rule, whatever the clock says", function()
			expect(Penalty.expired(0, 1e6, CONFIG)).to.equal(false)
		end)

		it("expires after TIE_SECONDS when the flag is off, and not one second early", function()
			local shortTie = table.clone(CONFIG)
			shortTie.TIE_UNTIL_DRIVE_END = false
			expect(Penalty.expired(100, 159, shortTie)).to.equal(false)
			expect(Penalty.expired(100, 160, shortTie)).to.equal(true)
		end)
	end)

	describe("Body.tiePointFor -- where a tied player stands", function()
		local folder: Folder
		local tree: BasePart

		beforeAll(function()
			folder = Instance.new("Folder")
			folder.Name = "MatchSafetySpec"
			-- The arena's trees ARE the 8 x 24 x 8 corner pillars, and that is the whole reason the
			-- design's `TIE_OFFSET = CFrame.new(0, 0, 2.5)` had to go: a part's Position is its centre,
			-- so 2.5 studs along the tree's own axis is inside the trunk and twelve studs up.
			tree = Instance.new("Part")
			tree.Name = "Pillar"
			tree.Size = Vector3.new(8, 24, 8)
			tree.Position = Vector3.new(150, 712, -150)
			tree.Anchored = true
			tree.Parent = folder
			folder.Parent = workspace
		end)

		afterAll(function()
			folder:Destroy()
		end)

		it("stands them on the ground, outside the trunk, facing it", function()
			local from = Vector3.new(150, 703, -120) -- 30 studs away on +Z
			local at = Body.tiePointFor(tree, from, CONFIG)

			-- On the ground: the trunk's base is 712 - 12 = 700.
			expect(math.abs(at.Position.Y - (700 + CONFIG.STAND_HEIGHT_STUDS)) < 0.001).to.equal(true)
			-- Outside the trunk: half of 8 is 4, plus the gap.
			local flat = Vector3.new(at.Position.X - tree.Position.X, 0, at.Position.Z - tree.Position.Z)
			expect(math.abs(flat.Magnitude - (4 + CONFIG.TIE_GAP_STUDS)) < 0.001).to.equal(true)
			expect(flat.Magnitude > 4).to.equal(true)
			-- Facing it.
			local toTree = Vector3.new(tree.Position.X - at.Position.X, 0, tree.Position.Z - at.Position.Z).Unit
			expect(at.LookVector:Dot(toTree) > 0.999).to.equal(true)
		end)

		it("puts them on the side they came from, not always the same side", function()
			local north = Body.tiePointFor(tree, Vector3.new(150, 703, -120), CONFIG)
			local south = Body.tiePointFor(tree, Vector3.new(150, 703, -180), CONFIG)
			expect(north.Position.Z > tree.Position.Z).to.equal(true)
			expect(south.Position.Z < tree.Position.Z).to.equal(true)
		end)

		it("does not error when the offender is standing in the trunk", function()
			local at = Body.tiePointFor(tree, tree.Position, CONFIG)
			expect(at.Position.Y > 0).to.equal(true)
		end)
	end)

	describe("Body.tie -- what being tied to a tree actually does", function()
		local folder: Folder
		local ropes: Folder
		local tree: BasePart
		local character: Model
		local USER = 900001

		beforeAll(function()
			folder = Instance.new("Folder")
			folder.Name = "MatchTieSpec"
			ropes = Instance.new("Folder")
			ropes.Name = "Ropes"
			ropes.Parent = folder

			tree = Instance.new("Part")
			tree.Size = Vector3.new(8, 24, 8)
			tree.Position = Vector3.new(0, 712, 0)
			tree.Anchored = true
			tree.Name = "Pillar"
			tree.Parent = folder

			character = rig("TiedRig", Vector3.new(0, 703, 30))
			character.Parent = folder
			folder.Parent = workspace
		end)

		afterAll(function()
			Body.untieCharacter(character, USER, ropes)
			Body.forget(USER)
			folder:Destroy()
		end)

		it("freezes the humanoid, anchors the root and puts them at the tree", function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			humanoid.WalkSpeed = 16
			humanoid.JumpHeight = 7.2
			humanoid.JumpPower = 50

			expect(Body.tieCharacter(character, USER, tree, CONFIG, ropes)).to.equal(true)

			expect(humanoid.WalkSpeed).to.equal(0)
			expect(humanoid.JumpHeight).to.equal(0)
			expect(humanoid.JumpPower).to.equal(0)
			-- The belt to WalkSpeed's braces: the character's physics belongs to its own client, so a
			-- pivot alone is a suggestion it can walk out of.
			expect(character.PrimaryPart.Anchored).to.equal(true)

			local expected = Body.tiePointFor(tree, Vector3.new(0, 703, 30), CONFIG)
			local moved = (character:GetPivot().Position - expected.Position).Magnitude
			print(string.format("[match_safety] tied %.2f studs from the computed point", moved))
			expect(moved < 0.01).to.equal(true)
		end)

		it("draws exactly one rope, and a second tie does not add another", function()
			local rope = ropes:FindFirstChild(Body.ropeName(USER))
			expect(rope).to.be.ok()
			expect(rope:IsA("Part")).to.equal(true)
			expect(rope.Shape).to.equal(Enum.PartType.Cylinder)
			expect(rope.Anchored).to.equal(true)
			-- It must never stop a pellet or an aim ray: the rope is scenery, not cover.
			expect(rope.CanCollide).to.equal(false)
			expect(rope.CanQuery).to.equal(false)
			expect(rope.Color).to.equal(CONFIG.ROPE_COLOR)
			expect(math.abs(rope.Size.Y - CONFIG.ROPE_THICKNESS) < 0.001).to.equal(true)
			-- Its length is the gap it spans: a cylinder's axis is its X.
			local span = Vector3.new(
				character.PrimaryPart.Position.X - tree.Position.X,
				0,
				character.PrimaryPart.Position.Z - tree.Position.Z
			).Magnitude
			expect(math.abs(rope.Size.X - span) < 0.2).to.equal(true)

			Body.tieCharacter(character, USER, tree, CONFIG, ropes)
			expect(#ropes:GetChildren()).to.equal(1)
		end)

		it("gives back exactly the numbers it took, and destroys the rope", function()
			Body.untieCharacter(character, USER, ropes)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			expect(humanoid.WalkSpeed).to.equal(16)
			-- A tolerance, because Roblox stores these as float32: 7.2 comes back 7.199999809265137,
			-- which is the same rounding the harness's own property comparison allows for.
			expect(math.abs(humanoid.JumpHeight - 7.2) < 1e-4).to.equal(true)
			expect(humanoid.JumpPower).to.equal(50)
			expect(character.PrimaryPart.Anchored).to.equal(false)
			expect(ropes:FindFirstChild(Body.ropeName(USER))).to.equal(nil)
			-- Twice is not an error, and it does not resurrect the rope.
			Body.untieCharacter(character, USER, ropes)
			expect(ropes:FindFirstChild(Body.ropeName(USER))).to.equal(nil)
		end)

		it("refuses a character it cannot freeze, rather than half-tying it", function()
			local naked = Instance.new("Model")
			naked.Name = "NoHumanoid"
			local part = Instance.new("Part")
			part.Name = "HumanoidRootPart"
			part.Anchored = true
			part.Position = Vector3.new(20, 703, 20)
			part.Parent = naked
			naked.PrimaryPart = part
			naked.Parent = folder

			expect(Body.tieCharacter(naked, 900002, tree, CONFIG, ropes)).to.equal(false)
			expect(ropes:FindFirstChild(Body.ropeName(900002))).to.equal(nil)
			expect(Body.tieCharacter(nil, 900003, tree, CONFIG, ropes)).to.equal(false)
			naked:Destroy()
		end)

		it("holds nothing after forget", function()
			-- Body keys what it took by userId and never by Player, so forget is a table operation and
			-- the count is how that is proved (design section 7.2's discipline, applied here too).
			local before = Body.tracked()
			Body.tieCharacter(character, USER, tree, CONFIG, ropes)
			expect(Body.tracked()).to.equal(before + 1)
			Body.forget(USER)
			expect(Body.tracked()).to.equal(before)
		end)
	end)

	describe("Body.anchorFor -- which tree", function()
		it("takes the nearest tree, falls back to a post, and returns nil with neither", function()
			local folder = Instance.new("Folder")
			folder.Name = "MatchAnchorSpec"
			local function part(x: number): BasePart
				local p = Instance.new("Part")
				p.Size = Vector3.new(4, 8, 4)
				p.Position = Vector3.new(x, 704, 0)
				p.Anchored = true
				p.Parent = folder
				return p
			end
			local near, far, post = part(10), part(200), part(-300)
			folder.Parent = workspace

			local from = Vector3.new(0, 703, 0)
			expect(Body.anchorFor({ trees = { far, near }, posts = { post } }, from)).to.equal(near)
			-- No tree tagged anywhere: a post will do, and it is still visible to everyone.
			expect(Body.anchorFor({ trees = {}, posts = { post } }, from)).to.equal(post)
			-- ...and it is still the NEAREST of them.
			expect(Body.anchorFor({ trees = {}, posts = { post, far } }, from)).to.equal(far)
			-- Neither: nil, which the owner reads as "do not tie". A nil CFrame would silently
			-- teleport the offender to the origin, which is the wrong answer nobody would notice.
			expect(Body.anchorFor({ trees = {}, posts = {} }, from)).to.equal(nil)

			folder:Destroy()
		end)
	end)

	describe("the safety numbers in Match.CONFIG", function()
		it("are the ones this spec just used, and 1.7b is switched on", function()
			expect(Match.CONFIG.SAFETY_ENABLED).to.equal(true)
			expect(Match.CONFIG.SAFETY_MISS_STUDS).to.equal(CONFIG.SAFETY_MISS_STUDS)
			expect(Match.CONFIG.SAFETY_RANGE_STUDS).to.equal(CONFIG.SAFETY_RANGE_STUDS)
			expect(Match.CONFIG.SAFETY_BODY_STUDS).to.equal(CONFIG.SAFETY_BODY_STUDS)
			expect(Match.CONFIG.SAFETY_GRACE_SECONDS).to.equal(CONFIG.SAFETY_GRACE_SECONDS)
			expect(Match.CONFIG.TIE_UNTIL_DRIVE_END).to.equal(true)
			expect(Match.CONFIG.TIE_SECONDS).to.equal(CONFIG.TIE_SECONDS)
			expect(Match.CONFIG.TIE_GAP_STUDS).to.equal(CONFIG.TIE_GAP_STUDS)
			expect(Match.CONFIG.ROPE_COLOR).to.equal(CONFIG.ROPE_COLOR)
			expect(Match.CONFIG.ROPE_THICKNESS).to.equal(CONFIG.ROPE_THICKNESS)
			expect(Match.CONFIG.POINTS.SAFETY_PENALTY).to.equal(-50)
		end)

		it("keeps SAFETY_RANGE_STUDS at the slug's own range, so one cannot drift from the other", function()
			local Shotgun = require(game:GetService("ReplicatedStorage"):WaitForChild("Shotgun"))
			expect(Match.CONFIG.SAFETY_RANGE_STUDS).to.equal(Shotgun.CONFIG.RANGE_STUDS.Slug)
		end)
	end)

	describe("Score.violation -- what a violation costs", function()
		it("takes SAFETY_PENALTY points, counts it, and lets the total go negative", function()
			local board = Match.Score.new()
			board = Match.Score.join(board, SHOOTER, "Karen", "Shooters")
			local awards
			board, awards = Match.Score.violation(board, SHOOTER, Match.CONFIG)
			expect(board.rows[SHOOTER].points).to.equal(-50)
			expect(board.rows[SHOOTER].violations).to.equal(1)
			expect(#awards).to.equal(1)
			expect(awards[1].reason).to.equal("safety")
			-- Frozen, and the input board untouched.
			expect(function()
				board.rows[SHOOTER].points = 0
			end).to.throw()
		end)
	end)
end
