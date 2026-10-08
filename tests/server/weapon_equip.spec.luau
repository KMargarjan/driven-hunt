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
-- WHAT THIS SPEC CAN PIN, AND WHAT IT CANNOT, said here because the difference cost three gate runs
-- and is the honest answer to "add a spec for the retry".
--
-- THE TASK 129 RETRY CANNOT BE DRIVEN FROM A SPEC, because the failure it guards cannot be produced
-- outside a respawn: `Humanoid:EquipTool` on a LIVE humanoid always takes the Tool. Measured, in
-- this order, each a separate gate run:
--   * a Tool with `RequiresHandle` and no `Handle` -- equipped anyway (the case read the player's
--     name where it expected the Backpack), then bounced back out: a flicker, not a refusal;
--   * the Tool put back in the Backpack right after the call -- too late: `task.spawn` runs the
--     retry's first iteration SYNCHRONOUSLY, it sees the Tool in the character and the loop returns
--     before a spec can touch anything;
--   * the Tool parented to `ServerStorage`, in neither the Backpack nor the character -- `EquipTool`
--     moved it to the character from there too.
-- So the retry's own loop is unreachable with a healthy humanoid, which is itself worth knowing: the
-- window it exists for is the placement respawn, and only a respawn makes it.
--
-- WHAT IS PINNED INSTEAD, and each of these fails if its fix is deleted:
--   * the equip reports an OUTCOME rather than a call -- the Tool ends in the character and
--     `equipNow`/`equipLate` move. Those counters exist only inside the verify-and-retry path that
--     task 129 added;
--   * the arming POLICY that decides whether there is a gun at all (`Weapon.armingAction`);
--   * TASK 123 ROUND 9's re-equip: a gun wearing the fallback, upgraded by `Weapon.upgradeLook`,
--     ends in the CHARACTER -- and nothing but the `after` callback puts it there.
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
		it("reports the OUTCOME of an equip, not the fact that it called EquipTool", function()
			local player = somebody()
			if player == nil then
				error("no player with a character: this case needs the harness's own player", 0)
			end
			local backpack = player:FindFirstChildOfClass("Backpack")
			expect(backpack).to.be.ok()

			local tool = handlelessTool(PROBE_NAME)
			addHandle(tool)
			tool.Parent = backpack
			local before = Weapon.stats()

			Hardware.equip(tool, player)

			-- THE TOOL IS IN THE HAND, which is the only thing Karen can see. Before task 129 this
			-- function called `EquipTool` and returned without ever asking whether it had worked.
			expect(waitUntil(2, function()
				return tool.Parent == player.Character
			end)).to.equal(true)
			local after = Weapon.stats()
			-- ...AND THE VERIFY RAN. `equipLate` is incremented in ONE place -- the loop that checks,
			-- on a LATER frame, that the Tool really did arrive -- so this is the assertion that
			-- fails the moment task 129's retry is deleted. Measured on this commit: one equip moves
			-- `now` by one (the call) and `late` by one (the outcome, seen a frame later).
			expect(after.equipLate > before.equipLate).to.equal(true)
			expect(after.equipNow > before.equipNow).to.equal(true)
			expect(after.equipNoCharacter).to.equal(before.equipNoCharacter)
			TestKit.note(
				string.format(
					"weapon-equip: an equip ended in the hand and was counted (now %d->%d, late %d->%d)",
					before.equipNow,
					after.equipNow,
					before.equipLate,
					after.equipLate
				)
			)
			tool:Destroy()
		end)

		it("hands a gun out only to somebody who may carry one, and takes it back otherwise", function()
			-- THE POLICY THAT DECIDES WHETHER THERE IS A GUN AT ALL. Pure, and the one place the
			-- answer lives: `Weapon.refreshArming` asks it on every sweep and on every respawn, so a
			-- rule that drifted here is a shooter with empty hands or a driver holding a shotgun.
			expect(Weapon.armingAction(true, false)).to.equal("grant")
			expect(Weapon.armingAction(false, true)).to.equal("revoke")
			-- ...AND NOTHING WHEN THE WORLD ALREADY MATCHES, which is what keeps the sweep from
			-- re-granting a gun every pass and from yanking a holstered one back.
			expect(Weapon.armingAction(true, true)).to.equal(nil)
			expect(Weapon.armingAction(false, false)).to.equal(nil)
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
