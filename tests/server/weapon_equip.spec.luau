-- weapon_equip.spec: THE GUN ENDS UP IN THE HAND, AND STAYS THERE. One real player, two real Tools
-- this spec makes and destroys, and no Play of its own.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- KAREN, TWICE: *"There is no weapon something is broken"* -- and then *"be sure that those mistakes
-- never be repeated / it's basics"*. It was fixed twice and neither fix had a spec that would fail
-- if the fix were deleted:
--
--   * TASK 123 ROUND 9 -- the barrels template landed AFTER the gun was handed out (measured in her
--     session: handle at 416 ms, barrels at 2096 ms), the upgrade put the mesh on and left the Tool
--     in the BACKPACK, and she stood at her stand with empty hands. `Weapon.upgradeLook` hands
--     `Hardware.upgradeAll` an `after` callback that puts the upgraded gun back in the hand.
--   * TASK 129 -- `Hardware.equip` CALLED `EquipTool` and never checked. Measured in the DEV gate:
--     all three grants were equipped with a live Humanoid ("equip now=3") and the client still had
--     the gun in the Backpack from +76 s, because during the drive's placement respawn the humanoid
--     exists but will not carry anything yet and `EquipTool` fails silently. It now verifies the
--     outcome and retries for two seconds.
--
-- HOW THE FAILING EQUIP IS PRODUCED, WITHOUT A STUB: a `Tool` with `RequiresHandle = true` and no
-- `Handle` CANNOT be equipped -- `Humanoid:EquipTool` does nothing and says nothing, which is the
-- same shape as the respawn window. Giving it a Handle a moment later makes the next attempt
-- succeed. The engine's own `EquipTool` is the thing under test either way; nothing is faked.
--
-- WHAT MAKES EACH CASE LOAD-BEARING is named in it: the retry case asserts `Weapon.stats().equipLate`,
-- a counter only the retry loop can move, and the upgrade case asserts the Tool is in the CHARACTER
-- after `upgradeLook`, which only the `after` callback puts it there.
--
-- Design: docs/design/weapon.md (the arming policy). TASKS.md rows 123a, 129, 131.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Hardware = Weapon.Hardware

local PROBE_NAME = "SpecEquipProbe"

local function somebody(): Player?
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character ~= nil and player.Character:FindFirstChildOfClass("Humanoid") ~= nil then
			return player
		end
	end
	return nil
end

-- A Tool that cannot be equipped yet: it requires a handle and has none.
local function handlelessTool(name: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	return tool
end

local function addHandle(tool: Tool): BasePart
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 3)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return handle
end

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return predicate()
end

return function()
	describe("the gun ends up in the hand", function()
		it("retries the equip until the character can actually take it", function()
			local player = somebody()
			if player == nil then
				-- A server spec runs inside a Play session with a player in it; if there is none, say
				-- so rather than passing on nothing.
				error("no player with a character: this case needs the harness's own player", 0)
			end
			local backpack = player:FindFirstChildOfClass("Backpack")
			expect(backpack).to.be.ok()

			local tool = handlelessTool(PROBE_NAME)
			tool.Parent = backpack
			local before = Weapon.stats().equipLate

			Hardware.equip(tool, player)
			-- THE FIRST ATTEMPT FAILS, SILENTLY, which is the whole fault this guards: `EquipTool`
			-- was called and the Tool did not move.
			expect(tool.Parent).to.equal(backpack)

			-- ...and then the character becomes able to take it, exactly as it does when a respawn
			-- finishes assembling.
			task.delay(0.25, function()
				if tool.Parent ~= nil then
					addHandle(tool)
				end
			end)

			local landed = waitUntil(3, function()
				return tool.Parent == player.Character
			end)
			expect(landed).to.equal(true)
			-- THE RETRY IS WHAT PUT IT THERE. `equipLate` is incremented in one place only -- the
			-- loop in `Hardware.equip` that checks the OUTCOME on a later frame -- so this assertion
			-- fails the moment that loop is deleted, which is what a regression of task 129 is.
			expect(Weapon.stats().equipLate).to.equal(before + 1)
			TestKit.note(
				string.format(
					"weapon-equip: a tool that could not be equipped at first was in the hand after the retry (late %d -> %d)",
					before,
					Weapon.stats().equipLate
				)
			)

			tool:Destroy()
		end)

		it("gives up quietly when the character goes away, instead of retrying for ever", function()
			local player = somebody()
			expect(player).to.be.ok()
			local backpack = (player :: Player):FindFirstChildOfClass("Backpack")
			local tool = handlelessTool(PROBE_NAME)
			tool.Parent = backpack
			local before = Weapon.stats().equipGaveUp

			Hardware.equip(tool, player :: Player)
			-- The Tool leaves: a revoke, or a respawn taking the old character with it. The loop's
			-- own exit, and the reason a retry cannot become a leak.
			tool:Destroy()
			expect(waitUntil(3, function()
				return Weapon.stats().equipGaveUp > before
			end)).to.equal(true)
		end)
	end)

	describe("a gun that gets its mesh late", function()
		it("is put back in the hand by the upgrade, and not yanked back twice", function()
			local player = somebody()
			expect(player).to.be.ok()
			local backpack = (player :: Player):FindFirstChildOfClass("Backpack")

			-- A GUN WEARING THE FALLBACK: the real Tool name, a Handle, and no mesh -- which is
			-- exactly what a player who spawned inside the server's first second was holding.
			local tool = Instance.new("Tool")
			tool.Name = Hardware.TOOL_NAME
			tool.RequiresHandle = true
			tool.CanBeDropped = false
			addHandle(tool)
			tool.Parent = backpack
			expect(Hardware.wearsMesh(tool)).to.equal(false)

			-- THE MESH LANDS. `Weapon.upgradeLook` is the one path both callers use (`WeaponBoot`
			-- once, the arming sweep after that), and its `after` callback is task 123 round 9.
			local upgraded = Weapon.upgradeLook()
			if not Hardware.wearsMesh(tool) then
				-- The template is not loaded in this session, so there is nothing to upgrade TO and
				-- this case cannot say anything. It fails rather than passing on nothing: a silent
				-- skip is how the fault it guards came back twice.
				tool:Destroy()
				error("the gun mesh template is not available in this session, so the upgrade path could not run", 0)
			end
			expect(upgraded >= 1).to.equal(true)

			-- ...AND IT IS BACK IN THE HAND. Nothing else in this path parents the Tool to the
			-- character: delete the `after` callback and the gun stays in the Backpack, which is
			-- what Karen saw.
			expect(waitUntil(3, function()
				return tool.Parent == (player :: Player).Character
			end)).to.equal(true)

			-- ONCE PER UPGRADED GUN, NOT EVERY SWEEP. The second pass finds nothing to upgrade, so
			-- `after` does not run -- which is what lets a player holster a gun and keep it holstered.
			local again = Weapon.upgradeLook()
			expect(again).to.equal(0)
			local backpackAgain = (player :: Player):FindFirstChildOfClass("Backpack")
			tool.Parent = backpackAgain
			expect(Weapon.upgradeLook()).to.equal(0)
			task.wait(0.2)
			expect(tool.Parent).to.equal(backpackAgain)
			TestKit.note(
				string.format(
					"weapon-equip: a fallback gun was upgraded (%d this pass) and put back in the hand; a second pass upgraded 0",
					upgraded
				)
			)

			tool:Destroy()
		end)
	end)
end
