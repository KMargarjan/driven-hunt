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
-- Design: docs/design/shotgun.md (`AUTO_EQUIP`, the grant/revoke lifecycle). TASKS.md rows 123a, 129, 131.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Hardware = Weapon.Hardware
-- The weapon table and the system numbers, for the hotbar-order case (task 141).
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local PROBE_NAME = "SpecEquipProbe"

local function somebody(): Player?
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character ~= nil and player.Character:FindFirstChildOfClass("Humanoid") ~= nil then
			return player
		end
	end
	return nil
end

-- A Tool this spec can hand to a humanoid: a real handle, because a handleless one is equipped and
-- then bounced straight back out (measured; see the header).
local function probeTool(name: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 3)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

-- THE PLAYER'S OWN GUN, REMEMBERED BEFORE THIS SPEC MAKES ANY OF ITS OWN -- and put back in his
-- hand afterwards, asserted rather than hoped for.
--
-- `Humanoid:EquipTool` UNEQUIPS WHATEVER IS HELD before it equips the new Tool, so a spec that
-- equips a probe onto the live player leaves his real Shotgun in the Backpack: exactly the state
-- Karen complained about and this file exists to prevent (round 1, the Reviewer's finding -- and
-- `Weapon.armingAction`'s own comment records the same trap from Task 34: "a spec that did that
-- broke three client specs, which were right to complain"). Nothing else puts it back: `holdsTool`
-- is record-based, so a gun in the Backpack still reads as held and the arming sweep does nothing.
local function realGunOf(player: Player): Tool?
	for _, tool in Hardware.toolsOf(player) do
		return tool
	end
	return nil
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

-- Put the player's gun back where this spec found it, and prove it landed. Called at the end of
-- every case that equipped anything -- and through `pcall` around the body, so a FAILING assertion
-- cannot leave the session gunless either (TestEZ's `expect` throws).
local function restore(player: Player, gun: Tool?)
	if gun == nil or gun.Parent == nil then
		return
	end
	Hardware.equip(gun, player)
	if not waitUntil(3, function()
		return gun.Parent == player.Character
	end) then
		error("the spec could not put the player's own gun back in his hand", 0)
	end
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

			local realGun = realGunOf(player)
			local tool = probeTool(PROBE_NAME)
			tool.Parent = backpack
			local before = Weapon.stats()

			local ok, err = pcall(function()
				Hardware.equip(tool, player)

				-- THE TOOL IS IN THE HAND, which is the only thing Karen can see. Before task 129
				-- this function called `EquipTool` and returned without ever asking whether it had
				-- worked.
				expect(waitUntil(2, function()
					return tool.Parent == player.Character
				end)).to.equal(true)
				local after = Weapon.stats()
				-- ...AND THE VERIFY RAN. `equipLate` is incremented in ONE place -- the loop that
				-- CHECKS that the Tool really did arrive -- so this is the assertion that fails the
				-- moment task 129's retry is deleted. (`task.spawn` runs that loop's first iteration
				-- synchronously, so on this path the check lands in the same frame as the call; the
				-- counter is the proof that the check happened at all, not that a frame passed.)
				expect(after.equipLate > before.equipLate).to.equal(true)
				expect(after.equipNow > before.equipNow).to.equal(true)
				TestKit.note(
					string.format(
						"weapon-equip: an equip ended in the hand and was counted (now %d->%d, late %d->%d)",
						before.equipNow,
						after.equipNow,
						before.equipLate,
						after.equipLate
					)
				)
			end)
			-- THE SESSION IS LEFT AS IT WAS FOUND, whether the case passed or failed: the probe goes,
			-- the player's own gun comes back, and the restore is asserted too.
			tool:Destroy()
			restore(player, realGun)
			if not ok then
				error(err, 0)
			end
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

	describe("the hotbar's order is the loadout's order", function()
		it("waits for the engine's own hotbar only when there is an order to protect", function()
			-- THE DECISION, PURE, AND BOTH WORLDS BY PARAMETER. This is the assertion that fails on
			-- the pre-fix code, and it has to be a pure one: the gate refuses to run with a flag
			-- override set, so `RIFLE` is at its default and `#Weapons.loadout()` is 1 -- and with
			-- ONE weapon the old code reached the bag first too (`Hardware.give` parents to the
			-- Backpack, and the equip it then did ran after). So a live one-weapon case cannot tell
			-- the fix from the bug, whatever it measures, and the Reviewer was right to say so.
			--
			-- CLAUDE.md's own feature-flag rule is the shape: a flagged path must be reachable by
			-- parameter as well as by flag, or its two states cannot be tested while the flag sits
			-- at one of them.
			expect(Shotgun.CONFIG.AUTO_EQUIP_DELAY_SECONDS > 0).to.equal(true)
			-- TWO TOOLS: the hand waits, because the engine's Backpack GUI numbers a slot the first
			-- time it SEES a Tool and equipping inside the grant hides the shotgun from it.
			expect(Weapon.equipDelayFor({ "shotgun", "rifle" })).to.equal(Shotgun.CONFIG.AUTO_EQUIP_DELAY_SECONDS)
			-- ONE TOOL: no order to get wrong, so the spawn is bit-for-bit what it was before the
			-- rifle existed -- no half second of empty hands for a bug that cannot happen.
			expect(Weapon.equipDelayFor({ "shotgun" })).to.equal(0)
			expect(Weapon.equipDelayFor({})).to.equal(0)
			-- ...and the real loadout resolves through the same function, whichever world this is.
			expect(Weapon.equipDelayFor(Weapons.loadout())).to.equal(
				if #Weapons.loadout() > 1 then Shotgun.CONFIG.AUTO_EQUIP_DELAY_SECONDS else 0
			)
		end)

		it("hands TWO Tools over in order, and the hand comes last", function()
			-- THE ORDER ITSELF, with two Tools, in the world the gate actually runs in (the
			-- Reviewer's note, round 2). `Weapons.loadout()` is one weapon here because the gate
			-- refuses to start with a flag override set -- so the loadout is passed as a PARAMETER
			-- instead, which is the same rule `Weapon.equipDelayFor` follows and the same rule
			-- CLAUDE.md states for anything behind a flag. The rifle's row, geometry and meshes all
			-- exist with the flag off; only the loadout is shorter.
			--
			-- This is the case that fails if the equip moves back inside `Weapon.grant`.
			local player = somebody()
			if player == nil then
				error("no player with a character: this case needs the harness's own player", 0)
			end
			local backpack = player:FindFirstChildOfClass("Backpack") :: Backpack
			local character = player.Character :: Model
			local both = { "shotgun", "rifle" }

			type Arrival = { where: string, name: string, at: number }
			local order: { Arrival } = {}
			local started = os.clock()
			local intoBag = backpack.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and Weapons.isToolName(child.Name) then
					table.insert(order, { where = "bag", name = child.Name, at = os.clock() - started })
				end
			end)
			local intoHand = character.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and Weapons.isToolName(child.Name) then
					table.insert(order, { where = "hand", name = child.Name, at = os.clock() - started })
				end
			end)

			local ok, why = pcall(function()
				for _, tool in ipairs(Hardware.toolsOf(player)) do
					tool:Destroy()
				end
				Weapon.refreshArming(player, both)
				-- NOTHING IS IN THE HAND WHEN THE SWEEP RETURNS. Nothing in `refreshArming` yields
				-- and `Hardware.equip` parents through `EquipTool` synchronously, so this is the
				-- whole fix in one line, at the only moment it is visible.
				expect(Weapon.heldId(player)).to.equal(nil)
				expect(waitUntil(6, function()
					return #Hardware.toolsOf(player) >= 2
				end)).to.equal(true)
				expect(waitUntil(4, function()
					for _, entry in ipairs(order) do
						if entry.where == "hand" then
							return true
						end
					end
					return false
				end)).to.equal(true)
				local shown = {}
				for _, entry in ipairs(order) do
					table.insert(shown, string.format("%s:%s@%.2f", entry.where, entry.name, entry.at))
				end
				TestKit.note("weapon-equip: two-Tool arrivals " .. table.concat(shown, " "))
				-- BOTH BAGS BEFORE THE FIRST HAND, and in `Weapons.ORDER` -- which is what the
				-- engine's hotbar reads, because it numbers a slot the first time it sees a Tool.
				local bagged = {}
				local firstHand, lastBag = nil, nil
				for index, entry in ipairs(order) do
					if entry.where == "bag" then
						table.insert(bagged, entry.name)
						lastBag = index
					elseif firstHand == nil then
						firstHand = index
					end
				end
				expect(firstHand).to.be.ok()
				expect(lastBag).to.be.ok()
				expect((lastBag :: number) < (firstHand :: number)).to.equal(true)
				expect(#bagged).to.equal(2)
				expect(bagged[1]).to.equal((Weapons.row("shotgun") :: any).toolName)
				expect(bagged[2]).to.equal((Weapons.row("rifle") :: any).toolName)
				-- ...AND THE HAND WAITED THE DELAY the two-Tool loadout asks for.
				local gap = order[firstHand :: number].at - order[lastBag :: number].at
				expect(gap >= Weapon.equipDelayFor(both) * 0.9).to.equal(true)
				-- ...and the shotgun is what ends up in it, never the rifle.
				expect(order[firstHand :: number].name).to.equal((Weapons.row(Weapons.PRIMARY) :: any).toolName)
			end)
			intoBag:Disconnect()
			intoHand:Disconnect()
			-- BACK TO THIS WORLD'S OWN LOADOUT, which takes the rifle away again: `refreshArming`
			-- with no argument revokes anything the real loadout does not carry.
			Weapon.refreshArming(player)
			expect(waitUntil(4, function()
				return #Hardware.toolsOf(player) == #Weapons.loadout()
			end)).to.equal(true)
			if not ok then
				error(why, 0)
			end
		end)

		it("puts the whole loadout in the BACKPACK before it puts anything in the hand", function()
			-- THE DIRECTOR'S THIRD BUG (task 141): the hotbar read `1 Rifle, 2 Shotgun`, against the
			-- design and against Karen. THE SLOT NUMBERS ARE NOT OURS -- the engine's own Backpack
			-- GUI numbers a slot the first time it SEES a Tool and then keeps it (MEASURED in the
			-- Forest Test: unequipping left both slots exactly where they were) -- so the only lever
			-- the server has is WHAT THAT GUI SEES FIRST. Granting the shotgun and equipping it in
			-- the same frame put it in the CHARACTER before the GUI looked, so the rifle was the
			-- first thing in the bag and took slot 1.
			--
			-- This is that rule, and it holds with ONE weapon in the loadout as well as two: a grant
			-- reaches the Backpack, and the hand comes after, by `AUTO_EQUIP_DELAY_SECONDS`.
			expect(Shotgun.CONFIG.AUTO_EQUIP_DELAY_SECONDS > 0).to.equal(true)
			local player = somebody()
			if player == nil then
				error("no player with a character: this case needs the harness's own player", 0)
			end
			local backpack = player:FindFirstChildOfClass("Backpack")
			expect(backpack).to.be.ok()
			local character = player.Character :: Model

			type Arrival = { where: string, name: string, at: number }
			local order: { Arrival } = {}
			local started = os.clock()
			local intoBag = (backpack :: Backpack).ChildAdded:Connect(function(child)
				if child:IsA("Tool") and Weapons.isToolName(child.Name) then
					table.insert(order, { where = "bag", name = child.Name, at = os.clock() - started })
				end
			end)
			local intoHand = character.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and Weapons.isToolName(child.Name) then
					table.insert(order, { where = "hand", name = child.Name, at = os.clock() - started })
				end
			end)

			local ok, err = pcall(function()
				-- Take every gun away and let the owner's own sweep hand the loadout back, which is
				-- the path a spawn takes.
				for _, tool in ipairs(Hardware.toolsOf(player)) do
					tool:Destroy()
				end
				local wanted = Weapons.loadout()
				Weapon.refreshArming(player)
				-- WITH AN ORDER TO PROTECT, NOTHING IS IN THE HAND WHEN THE SWEEP RETURNS: nothing
				-- in `refreshArming` yields and `Hardware.equip` parents through `EquipTool`
				-- synchronously, so this is the fix, in one line, at the only moment it is visible.
				-- With ONE weapon the equip is deliberately immediate (`Weapon.equipDelayFor`), so
				-- the opposite is asserted -- and in the gate's own world that is the branch taken.
				if #wanted > 1 then
					expect(Weapon.heldId(player)).to.equal(nil)
				else
					-- ONE WEAPON: the equip is deliberately immediate, and what is asserted is the
					-- OUTCOME rather than `heldId` -- that field is written by `watchEquipped`'s own
					-- signal, which the engine may defer by a frame, and a spec that raced it would
					-- be flaky about something it is not testing.
					expect(waitUntil(2, function()
						return #Hardware.toolsOf(player) > 0 and Weapon.heldId(player) == Weapons.PRIMARY
					end)).to.equal(true)
				end
				expect(waitUntil(6, function()
					return #Hardware.toolsOf(player) >= #wanted
				end)).to.equal(true)
				expect(waitUntil(4, function()
					for _, entry in ipairs(order) do
						if entry.where == "hand" then
							return true
						end
					end
					return false
				end)).to.equal(true)
				local shown = {}
				for _, entry in ipairs(order) do
					table.insert(shown, string.format("%s:%s@%.2f", entry.where, entry.name, entry.at))
				end
				TestKit.note("weapon-equip: arrivals " .. table.concat(shown, " "))
				-- EVERY BAG ARRIVAL COMES BEFORE THE FIRST HAND ARRIVAL. That is the whole rule, and
				-- it is what the hotbar reads.
				local firstHand, lastBag = nil, nil
				for index, entry in ipairs(order) do
					if entry.where == "hand" and firstHand == nil then
						firstHand = index
					end
					if entry.where == "bag" then
						lastBag = index
					end
				end
				expect(firstHand).to.be.ok()
				local bagged = 0
				for index, entry in ipairs(order) do
					if entry.where == "bag" then
						expect(index < (firstHand :: number)).to.equal(true)
						bagged += 1
					end
				end
				expect(bagged).to.equal(#wanted)
				-- ...AND THE HAND WAITED THE DELAY, when there was an order to protect.
				if #wanted > 1 then
					local gap = order[firstHand :: number].at - order[lastBag :: number].at
					expect(gap >= Weapon.equipDelayFor(wanted) * 0.9).to.equal(true)
				end
				-- ...AND THE BAG ARRIVALS ARE IN `Weapons.ORDER`, which is what makes slot 1 the
				-- shotgun. With the rifle flag off the loadout is one weapon and this is one name.
				local seen = 0
				for _, entry in ipairs(order) do
					if entry.where == "bag" then
						seen += 1
						expect(entry.name).to.equal((Weapons.row(wanted[seen]) :: any).toolName)
					end
				end
			end)
			intoBag:Disconnect()
			intoHand:Disconnect()
			-- The session is left armed whatever happened, which is what every case in this file does.
			Weapon.refreshArming(player)
			if not ok then
				error(err, 0)
			end
		end)
	end)

	describe("a gun that gets its mesh late", function()
		it("is put back in the hand by the upgrade, and not yanked back twice", function()
			local player = somebody()
			if player == nil then
				error("no player with a character: this case needs the harness's own player", 0)
			end
			local backpack = player:FindFirstChildOfClass("Backpack")
			local realGun = realGunOf(player)

			-- A GUN WEARING THE FALLBACK: the real Tool name, a Handle, and no mesh -- which is
			-- exactly what a player who spawned inside the server's first second was holding. It
			-- carries the real name because `Hardware.toolsOf` filters by it and `upgradeAll` walks
			-- that list; it is destroyed at the end of the case, pass or fail, because a second Tool
			-- of that name breaks the one-gun-per-player rule `Weapon.grant` enforces.
			local tool = probeTool(Hardware.TOOL_NAME)
			tool.Parent = backpack

			local ok, err = pcall(function()
				expect(Hardware.wearsMesh(tool)).to.equal(false)

				-- THE MESH LANDS. `Weapon.upgradeLook` is the one path both callers use (`WeaponBoot`
				-- once, the arming sweep after that), and its `after` callback is task 123 round 9.
				local upgraded = Weapon.upgradeLook()
				if not Hardware.wearsMesh(tool) then
					-- The template is not loaded in this session, so there is nothing to upgrade TO.
					-- It FAILS rather than passing on nothing: a silent skip is how the fault this
					-- file guards came back twice.
					error(
						"the gun mesh template is not available in this session, so the upgrade path could not run",
						0
					)
				end
				expect(upgraded >= 1).to.equal(true)

				-- ...AND IT IS BACK IN THE HAND. Nothing else in this path parents the Tool to the
				-- character: delete the `after` callback and the gun stays in the Backpack, which is
				-- what Karen saw.
				expect(waitUntil(3, function()
					return tool.Parent == player.Character
				end)).to.equal(true)

				-- ONCE PER UPGRADED GUN, NOT EVERY SWEEP. The second pass finds nothing to upgrade,
				-- so `after` does not run -- which is what lets a player holster a gun and keep it
				-- holstered.
				local backpackAgain = player:FindFirstChildOfClass("Backpack")
				tool.Parent = backpackAgain
				expect(Weapon.upgradeLook()).to.equal(0)
				task.wait(0.2)
				expect(tool.Parent).to.equal(backpackAgain)
				TestKit.note(
					string.format(
						"weapon-equip: a fallback gun was upgraded (%d this pass) and put back in the hand;"
							.. " a second pass upgraded 0",
						upgraded
					)
				)
			end)

			-- THE SESSION IS LEFT AS IT WAS FOUND, pass or fail.
			tool:Destroy()
			restore(player, realGun)
			if not ok then
				error(err, 0)
			end
		end)
	end)
end
