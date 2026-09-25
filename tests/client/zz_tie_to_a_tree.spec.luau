-- zz_tie_to_a_tree.spec: the safety rule, end to end, with a real shot from a real player.
--
-- THE `zz_` PREFIX IS DELIBERATE AND IT IS LOAD-BEARING. TestEZ runs the spec modules in the order
-- the specs folder lists them, and this is the one spec whose success TAKES THE GUN AWAY: a tied
-- shooter may not carry one (docs/design/drive.md section 8.4 item 5). tests/client/weapon_client.spec
-- already records that "a spec that revoked this gun mid-session broke exactly this window, and was
-- withdrawn" (Task 34). So this must run after every spec that needs an armed player, and its
-- scenario must be the LAST one in tests/client/input_scenarios.txt. Rename it and the run goes red
-- in weapon_client, not here.
--
-- WHAT IT ASSERTS DEPENDS ON WHO IS IN THE SESSION, which is what makes it run in both harness modes
-- (`test` and `test2`), and neither branch is a skip -- each one asserts a real rule:
--   * TWO PLAYERS (test2): this client is the SHOOTER, the other is the DRIVER standing on the driver
--     pad. This spec walks up behind him, keeps the camera on him, the harness replays a click, and
--     the server ties this player to a tree. Click -> ContextActionService -> client weapon ->
--     FireRequest -> validator -> cast -> Weapon.SafetyArc's 45-degree filter -> Match.Penalty.judge
--     -> Match.Body.tie -> the snapshot's `tied` list -> this client's Hud banner. Nothing is stubbed.
--   * ONE PLAYER (test): there is no driver, so this fires the same shot straight INTO the drive and
--     asserts that nothing happens. That is not a weaker test -- it is the case the design rejected
--     an earlier rule for: a shooter on a post faces the drive, so if "inside the 45-degree cone"
--     were the verdict, this shot would tie everybody in the first minute (design section 8.1).
--   * A DRIVER's client (test2, printed as an observation): carries no gun, and asserts that.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 8.1, 8.2, 8.3, 8.4, 9.3)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Hud = require(scripts:WaitForChild("Hud"))
local Match = require(scripts:WaitForChild("Match"))

local CUE_ACTION = "DrivenHunt.Test.TieCue"
-- The last of five scenarios, and since Task 36 `test2` sends every step to BOTH clients, so the
-- replay takes about twice as long there as the ~60 s it takes with one.
local CUE_TIMEOUT = 240
local TIE_TIMEOUT = 25 -- from the cue to the snapshot saying so
local STAND_BEHIND = 25 -- studs behind the driver, so the shot cannot stop in something else
local DOWN_THE_DRIVE = 200 -- studs up +Z, for the one-player shot at nobody

local cuedAt: number? = nil
local stagedFrom: Vector3? = nil
local stagedDistance: number? = nil
local violations = {}

-- The feed is the "visible to everyone" half of Karen's rule, and it fades after FEED_SECONDS, so it
-- is recorded as it arrives rather than read later.
Match.Feed:Connect(function(entry)
	if entry.kind == "violation" then
		table.insert(violations, entry)
	end
end)

local function rootOf(subject: Player): BasePart?
	local character = subject.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The other player, if this session has one and the drive made them a driver.
local function driver(): Player?
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Team and other.Team.Name == "Drivers" then
			return other
		end
	end
	return nil
end

local function holdsGun(): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and backpack:FindFirstChildOfClass("Tool") then
		return true
	end
	local character = player.Character
	return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
end

-- THE CUE. The harness cannot tell a spec "your scenario starts now" except through the input it
-- replays, and this spec must be moving and aiming BEFORE the click arrives -- so the scenario opens
-- with one key, exactly as weapon_client.spec's Q does. It also means this spec touches the camera
-- only inside its own scenario, so it never fights shoot_boar.spec for it.
--
-- (The scenario's `moveTo` right after the cue is not aiming -- under MouseBehavior = LockCenter
-- StudioMCP's moveTo delivers no usable delta, docs/design/camera.md 9.3. It is there because
-- StudioMCP refuses a click with no established mouse position: "Either x and y, instance_path, or a
-- prior action that establishes mouse position is required", measured 2026-09-25.)
local function onCue(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin or cuedAt then
		return Enum.ContextActionResult.Pass
	end
	cuedAt = os.clock()
	local me = rootOf(player)
	local target = driver()
	local theirs = if target then rootOf(target) else nil
	local character = player.Character
	if me and theirs and character then
		-- Behind him and IN FRONT of the line, so the shot runs up +Z -- the direction the arena's
		-- DriveLine marker points, and the direction the drive comes from. Walking up to somebody and
		-- shooting at them is the player's path; the client owns its own character, which is the same
		-- reason the harness's own `stage` step pivots it (tools/studio_mcp.py).
		local at = theirs.Position - Vector3.new(0, 0, STAND_BEHIND)
		character:PivotTo(CFrame.lookAt(at, theirs.Position))
		stagedFrom = at
		stagedDistance = STAND_BEHIND
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(CUE_ACTION, onCue, false, Enum.KeyCode.T)

-- Holds the aim: on the driver when there is one, otherwise straight down the drive at nobody. It
-- asks the CAMERA OWNER and never writes workspace.CurrentCamera -- the camera's own foreign-write
-- detector counts that, and weapon_client.spec asserts the counter does not move.
local aiming = RunService.RenderStepped:Connect(function()
	if not cuedAt or os.clock() - cuedAt > TIE_TIMEOUT then
		return
	end
	local target = driver()
	local theirs = if target then rootOf(target) else nil
	if theirs then
		Camera.lookAt(theirs.Position)
		return
	end
	local me = rootOf(player)
	if me then
		Camera.lookAt(me.Position + Vector3.new(0, 0, DOWN_THE_DRIVE))
	end
end)

InputReady.ready("zz_tie_to_a_tree")

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

return function()
	describe("a real shot down the drive line", function()
		-- THE REPLAY ONLY EVER REACHES THE SHOOTER (tools/studio_mcp.py: a driver carries no gun), so a
		-- driver's client must not wait for a cue that cannot arrive. MEASURED, and it is the reason
		-- this is a function and not a plain wait: two 150-second waits on the driver's client pushed
		-- its whole suite past the harness's 420-second report window, and a report that never arrives
		-- is one the run cannot even print as an observation (Task 34's half of the client suite).
		local function cued(): boolean
			expect(waitUntil(20, function()
				return Match.myTeam() ~= nil
			end)).to.equal(true)
			if Match.myTeam() ~= "Shooters" then
				return false
			end
			return waitUntil(CUE_TIMEOUT, function()
				return cuedAt ~= nil
			end)
		end

		it("was cued by the harness, so this spec's own scenario really ran", function()
			local shooter = cued()
			TestKit.note(
				string.format(
					"zz_tie: %s team=%s players=%d staged=%s cued=%s",
					player.Name,
					tostring(Match.myTeam()),
					#Players:GetPlayers(),
					tostring(stagedDistance),
					tostring(shooter)
				)
			)
			-- A shooter must have been cued; a driver is never cued and that is the rule, not a miss.
			expect(shooter).to.equal(Match.myTeam() == "Shooters")
		end)

		it("ties the shooter to a tree when a driver was in its path, or nobody when none was", function()
			expect(cued()).to.equal(Match.myTeam() == "Shooters")

			if Match.myTeam() ~= "Shooters" then
				-- A DRIVER's client. It carries no gun (DRIVERS_MAY_SHOOT is false), so it cannot
				-- break this rule at all, and the rule must not have touched it either.
				expect(Match.myTeam()).to.equal("Drivers")
				expect(holdsGun()).to.equal(false)
				expect(Match.isTied()).to.equal(false)
				expect(Hud.isTiedBannerVisible()).to.equal(false)
				return
			end

			if driver() == nil then
				-- ONE PLAYER: the same shot, into an empty drive. The 45-degree arc published it to
				-- the Match and the Match let it go, because no driver was in the path. This is the
				-- rule NOT being a cone (design section 8.1).
				expect(#Players:GetPlayers()).to.equal(1)
				local tiedAnyway = waitUntil(TIE_TIMEOUT, function()
					return Match.isTied()
				end)
				expect(tiedAnyway).to.equal(false)
				expect(Hud.isTiedBannerVisible()).to.equal(false)
				expect(holdsGun()).to.equal(true) -- and the gun is still his
				return
			end

			-- TWO PLAYERS: the shot really did go at a person.
			expect(stagedDistance).to.equal(STAND_BEHIND)
			local tied = waitUntil(TIE_TIMEOUT, function()
				return Match.isTied()
			end)
			if not tied then
				local snapshot = Match.get()
				TestKit.note(
					string.format(
						"zz_tie: NOT tied. phase=%s holdsGun=%s from=%s violations=%d",
						tostring(snapshot and snapshot.phase),
						tostring(holdsGun()),
						tostring(stagedFrom),
						#violations
					)
				)
			end
			expect(tied).to.equal(true)

			-- The snapshot is what everyone sees, and it names him.
			local snapshot = Match.get()
			local found = false
			for _, userId in ipairs(snapshot.tied) do
				if userId == player.UserId then
					found = true
				end
			end
			expect(found).to.equal(true)

			-- Visible to everyone: the feed said so. That is Karen's "visible to everyone with an
			-- announcement", and it is recorded as it arrives because the feed fades.
			expect(#violations >= 1).to.equal(true)
			expect(violations[1].userId).to.equal(player.UserId)

			-- On this player's own screen, with every ancestor really there.
			expect(waitUntil(5, function()
				return Hud.isTiedBannerVisible()
			end)).to.equal(true)
			local node: Instance? = Hud.tiedBanner()
			while node and node ~= game do
				if node:IsA("GuiObject") then
					expect(node.Visible).to.equal(true)
				elseif node:IsA("ScreenGui") then
					expect(node.Enabled).to.equal(true)
				end
				node = node.Parent
			end
			expect(node).to.equal(game)

			-- And the gun is gone: a tied player holding a gun he cannot aim is a worse joke than a
			-- tied player with none (design section 8.4 item 5).
			expect(waitUntil(10, function()
				return not holdsGun()
			end)).to.equal(true)
		end)

		afterAll(function()
			if aiming.Connected then
				aiming:Disconnect()
			end
			ContextActionService:UnbindAction(CUE_ACTION)
		end)
	end)
end
