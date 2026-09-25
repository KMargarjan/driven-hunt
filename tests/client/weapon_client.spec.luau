-- weapon_client.spec: the weapon from the player's side. Two halves:
--   * what needs no input -- the remotes, the frozen replica, the crosshair's REAL visibility (every
--     ancestor checked, which is what makes "a visibility audit certified a blank screen twice"
--     (docs/PROJECT_CONTEXT.md) impossible to repeat), and the exploit path;
--   * what the harness drives -- fire, the barrel delay, an empty gun, reload, ammo select and aim,
--     all asserted through Weapon.get() snapshots and never through internals.
--
-- The Tool is equipped on a CUE KEY (Q) rather than before the replay: Task 6's own scenario sends
-- MouseButton1 and R, which are fire and reload, so a gun in the hand during that scenario would
-- spend a barrel before this one started (docs/design/shotgun.md section 13.3).
--
-- MEASURED, AND IT CONTRADICTS THE DESIGN (section 2.3 item 3): consecutive steps inside ONE
-- StudioMCP call are NOT sub-frame. Two batched clicks landed more than BARREL_DELAY apart, so the
-- first run here fired twice where the design expected one shot and a "busy" rejection. So no
-- assertion in this spec depends on two inputs arriving close together: the barrel delay is proved
-- deterministically in tests/server/weapon_state.spec.luau instead, and everything below is written
-- to hold whatever the replay's pacing turns out to be.
--
-- Measured on the second run: a step costs roughly a second of wall time on top of its own `wait`,
-- so an input cannot be placed reliably INSIDE the 2.0 s reload window either -- a second R sent
-- 300 ms after the first arrived after the reload had finished and started a legitimate second one.
-- So the two "rejected while busy" properties are proved where they can be proved exactly, in
-- tests/server/weapon_state.spec.luau ("rejects a second shot inside the barrel delay" and "never
-- lets a second break in"), and this spec asserts what the channel really can: that the inputs
-- arrive, in order, and that the state they produce is the state the design says.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (sections 13.2, 13.3)
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))

local CUE_ACTION = "DrivenHunt.Test.WeaponCue"
local RUN_TIMEOUT = 70 -- Task 36: two clients share one replay, so every step costs two calls

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Weapon = require(scripts:WaitForChild("Weapon"))
local Hud = require(scripts:WaitForChild("Hud"))

-- Every snapshot the server published, in order, with the client clock that received it.
local log = {}
-- ...and how much of it belongs to THIS scenario. Task 30 added `shoot-the-boar`, which fires the
-- same gun later in the same Play session, so "exactly two shots" and "it ends here" are claims
-- about a window, not about the session. The window closes when the harness stages the next
-- scenario -- the one event that says another scenario has taken the gun (tools/studio_mcp.py, the
-- `stage` step, which sets this attribute and nothing else does).
local ownLogEntries: number? = nil
player:GetAttributeChangedSignal("StagedTarget"):Connect(function()
	ownLogEntries = ownLogEntries or #log
end)

-- The log as it stood when this spec's own scenario ended.
local function ownLog()
	if not ownLogEntries then
		return log
	end
	local out = {}
	for index = 1, ownLogEntries do
		out[index] = log[index]
	end
	return out
end
local aimEvents = {}
local cameraSamples = {}
local equippedAt = nil

Weapon.Changed:Connect(function(snapshot)
	table.insert(log, { at = os.clock(), state = snapshot })
end)

Weapon.Input.AimChanged:Connect(function(aiming)
	table.insert(aimEvents, aiming)
	local camera = Workspace.CurrentCamera
	local subject = camera and camera.CameraSubject
	local subjectPart = if subject and subject:IsA("Humanoid")
		then subject.Parent and subject.Parent:FindFirstChild("HumanoidRootPart")
		else subject
	table.insert(cameraSamples, {
		aiming = aiming,
		cameraType = camera and camera.CameraType,
		fov = camera and camera.FieldOfView,
		subject = subject,
		offset = if camera
				and subjectPart
				and subjectPart:IsA("BasePart")
			then camera.CFrame.Position - subjectPart.Position
			else nil,
	})
end)

-- The cue: equip the Tool the way the Backpack does, so Tool.Equipped fires on the client and the
-- server sees Tool.Parent become the character. Equipping is this spec's arrangement; everything
-- asserted afterwards arrives through the real input path.
local function onCue(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = player:FindFirstChildOfClass("Backpack")
		local tool = backpack and backpack:FindFirstChild("Shotgun")
		if humanoid and tool then
			humanoid:EquipTool(tool)
			equippedAt = os.clock()
		elseif character and character:FindFirstChild("Shotgun") then
			equippedAt = os.clock()
		end
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(CUE_ACTION, onCue, false, Enum.KeyCode.Q)

-- Park the Tool in the Backpack BEFORE signalling ready, and that is not optional: CONFIG.AUTO_EQUIP
-- is true (Karen's playtest should start with the gun in hand), so without this the gun is in the
-- character while Task 6's `key-mouse-order` scenario sends MouseButton1 and R -- and it was: the
-- third run fired a shot and ran a whole reload before this scenario began. Unequipping unbinds the
-- weapon's own actions (Tool.Unequipped), so scenario 1's clicks reach nothing, and the cue key puts
-- it back. This is the spec's arrangement; nothing asserted afterwards depends on it.
local function parkTool(): boolean
	local deadline = os.clock() + 15
	repeat
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = player:FindFirstChildOfClass("Backpack")
		local held = character and character:FindFirstChild("Shotgun")
		if humanoid and held then
			humanoid:UnequipTools()
			return true
		end
		if backpack and backpack:FindFirstChild("Shotgun") then
			return true -- already parked
		end
		task.wait(0.1)
	until os.clock() > deadline
	return false
end

local parked = parkTool()
InputReady.ready("weapon_client")

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

local function spentCount(state): number
	local n = 0
	for _, barrel in ipairs(state.barrels) do
		if barrel == "Spent" then
			n += 1
		end
	end
	return n
end

-- The last snapshot of THIS spec's own scenario. While its scenario is the one running, that is
-- simply the last snapshot; once the harness stages the next one, the window is frozen. Task 30:
-- `shoot-the-boar` fires the same gun afterwards, so the session's last snapshot had busyFor = 0.25
-- from someone else's shot and "the scenario ended where the design says" timed out waiting for a
-- state it had already reached.
local function last()
	local entries = ownLog()
	return if #entries > 0 then entries[#entries].state else nil
end

return function()
	describe("the weapon's shared data", function()
		it("has the four remotes on disk, with the right classes", function()
			local remotes = Shotgun.remotes()
			expect(remotes.FireRequest:IsA("RemoteEvent")).to.equal(true)
			expect(remotes.ActionRequest:IsA("RemoteEvent")).to.equal(true)
			expect(remotes.StateChanged:IsA("RemoteEvent")).to.equal(true)
			expect(remotes.ShotFired:IsA("RemoteEvent")).to.equal(true)
		end)

		it("keeps CONFIG frozen to its nested tables", function()
			expect(Shotgun.CONFIG.SPREAD_FULL_DEG.Buck).to.equal(1.6)
			expect(function()
				Shotgun.CONFIG.SPREAD_FULL_DEG.Buck = 9
			end).to.throw()
		end)
	end)

	describe("the client replica", function()
		it("arrives, and is frozen all the way down", function()
			if Role.isDriver() then
				-- ROLE-AWARE (TASKS.md row 34a). A driver is never granted a Tool, so the server
				-- never publishes him a weapon state and this replica stays empty. That IS the
				-- claim for a driver, and it is asserted rather than skipped: a driver who has a
				-- weapon snapshot has been armed by something, which is the bug.
				task.wait(5)
				expect(Weapon.get()).to.equal(nil)
				return
			end
			expect(waitUntil(20, function()
				return Weapon.get() ~= nil
			end)).to.equal(true)
			local state = Weapon.get()
			expect(type(state.equipped)).to.equal("boolean")
			expect(type(state.reserve)).to.equal("table") -- one pocket per ammo type
			expect(type(state.reserve.Slug)).to.equal("number")
			expect(state.busyUntil).to.equal(nil) -- a server-only field
			expect(function()
				(state :: any).reserve = 0
			end).to.throw()
			expect(function()
				state.barrels[1] = "Spent"
			end).to.throw()
		end)

		it("exposes the aim seam the camera task will attach to", function()
			expect(typeof(Weapon.Input.AimChanged)).to.equal("RBXScriptSignal")
			expect(type(Weapon.Input.isAiming())).to.equal("boolean")
		end)
	end)

	-- THE TWO DESCRIBES BELOW ARE THE SHOOTER'S, and they are guarded rather than branched inside
	-- because every assertion in them needs a Tool in the hand: a driver carries none at all
	-- (`Match.CONFIG.DRIVERS_MAY_SHOOT` is false), so there is nothing to equip, fire, reload, swap
	-- or draw a crosshair for. The driver's own describe is at the bottom of this file and asserts
	-- the other half of the same rule -- not a skip, which TestKit fails the whole run for.
	if Role.isShooter() then
		describe("the harness-driven weapon", function()
			-- The camera's foreign-write counter, as it stood when this describe started. Task 30 made
			-- the detector see rotation-only writes, and camera_client.spec now performs one deliberately
			-- to prove the detector works -- so a session TOTAL of zero is no longer the right claim.
			-- The claim that matters is this one: while the weapon was being driven, nothing but the
			-- camera wrote the camera.
			local foreignBefore = 0

			beforeAll(function()
				local cameraModule = scripts:FindFirstChild("Camera")
				if cameraModule then
					foreignBefore = require(cameraModule).stats().foreignCameraWrites
				end
			end)

			it("equips on the cue and starts full", function()
				expect(waitUntil(RUN_TIMEOUT, function()
					local state = Weapon.get()
					return state ~= nil and state.equipped
				end)).to.equal(true)
				-- Over the LOG, not over Weapon.get(): by the time a later `it` runs, the scenario has
				-- moved on, and "it started full" is a claim about the beginning.
				local sawFull = false
				for _, entry in ipairs(log) do
					local state = entry.state
					if
						state.equipped
						and state.barrels[1] == "Live"
						and state.barrels[2] == "Live"
						and state.loaded[1] == "Slug"
						and state.reserve.Slug == 24
						and state.selected == 1
					then
						sawFull = true
						break
					end
				end
				expect(parked).to.equal(true) -- the arrangement above actually happened
				expect(sawFull).to.equal(true)
				expect(equippedAt).to.be.ok()
			end)

			it("runs the whole scenario and ends where the design says", function()
				-- THE STATE THE SCENARIO ENDED ON, captured when it ended -- not the newest one the gun
				-- ever published. The server may hand this player a fresh weapon later in the session
				-- for reasons that have nothing to do with the scenario (a respawn, a drive placement,
				-- the arming sweep), and a full magazine minutes afterwards is not this claim being
				-- wrong. Task 30 turned two session-wide claims into window claims for the same reason;
				-- Task 34 found this one the same way, through a spec that respawned the player.
				local endState = nil
				local finished = waitUntil(RUN_TIMEOUT, function()
					local state = last()
					if
						state ~= nil
						and state.ammo == "Buck"
						and state.loaded[1] == "Buck"
						and state.busyFor == 0
						and #aimEvents >= 2
					then
						endState = state
						return true
					end
					return false
				end)
				if not finished then
					local state = last()
					print(
						string.format(
							"[weapon_client] %d snapshots; last: ammo=%s slug=%s busyFor=%.2f aims=%d",
							#log,
							tostring(state and state.ammo),
							tostring(state and state.reserve and state.reserve.Slug),
							(state and state.busyFor) or -1,
							#aimEvents
						)
					)
				end
				expect(finished).to.equal(true)

				local state = endState
				expect(state).to.be.ok()
				print(
					string.format(
						"[weapon_client] end state: barrels=%s/%s loaded=%s/%s selected=%d ammo=%s slug=%d buck=%d open=%s",
						state.barrels[1],
						state.barrels[2],
						state.loaded[1],
						state.loaded[2],
						state.selected,
						state.ammo,
						state.reserve.Slug,
						state.reserve.Buck,
						tostring(state.open)
					)
				)
				expect(state.equipped).to.equal(true)
				expect(state.open).to.equal(false)
				expect(state.barrels[1]).to.equal("Live")
				expect(state.barrels[2]).to.equal("Live")
				-- X now SWAPS the gun (Karen, 2026-09-25): the two slugs went back into the slug pocket
				-- and two buckshot came out of the buck pocket, so the gun holds buckshot.
				expect(state.loaded[1]).to.equal("Buck")
				expect(state.loaded[2]).to.equal("Buck")
				expect(state.selected).to.equal(1)
				expect(state.ammo).to.equal("Buck")
				-- Slug: 24 - 2 for the R reload, + 2 returned when X broke the action open. Buck: -2.
				expect(state.reserve.Slug).to.equal(24)
				expect(state.reserve.Buck).to.equal(22)
			end)

			it("fired exactly twice: an empty gun refused the third click", function()
				-- Three clicks were sent: two into a loaded gun and one into a gun with both barrels
				-- spent. Only the first two may spend a barrel -- no phantom shot.
				local entries = ownLog()
				local rises = 0
				local previous = 0
				for _, entry in ipairs(entries) do
					local spent = spentCount(entry.state)
					if spent > previous then
						rises += 1
					end
					previous = spent
				end
				print(
					string.format(
						"[weapon_client] shots seen: %d over %d snapshots (%d in the session)",
						rises,
						#entries,
						#log
					)
				)
				expect(rises).to.equal(2)
			end)

			it("moved to the other barrel by itself after the first shot", function()
				local sawSwitch = false
				for _, entry in ipairs(log) do
					if
						entry.state.barrels[1] == "Spent"
						and entry.state.loaded[1] == "None"
						and entry.state.selected == 2
					then
						sawSwitch = true
						break
					end
				end
				expect(sawSwitch).to.equal(true)
			end)

			it("swapped the gun to buckshot, through a reload it showed as busy", function()
				-- Karen's change: X is not a label swap, it breaks the gun open and reloads it. So a
				-- snapshot must exist where the ammo is already Buck and the barrels are NOT yet loaded
				-- with it -- the open action mid-swap.
				local sawSwapInProgress, sawSwapDone = false, false
				for _, entry in ipairs(log) do
					local state = entry.state
					if state.ammo == "Buck" and state.loaded[1] ~= "Buck" then
						sawSwapInProgress = true
					end
					if state.ammo == "Buck" and state.loaded[1] == "Buck" and state.loaded[2] == "Buck" then
						sawSwapDone = true
					end
				end
				expect(sawSwapInProgress).to.equal(true)
				expect(sawSwapDone).to.equal(true)
			end)

			it("showed the reload as busy while it ran", function()
				local sawBusy = false
				for _, entry in ipairs(log) do
					if entry.state.busyFor > 0 then
						sawBusy = true
						break
					end
				end
				expect(sawBusy).to.equal(true)
			end)

			it("raised and lowered the aim flag once each, for its own hold", function()
				-- ITS OWN first two edges. Since Task 26 the camera's aim-hold scenario holds the same
				-- button later in the same run, so the session total is not this scenario's business
				-- (it was 3 on the run that taught this).
				expect(#aimEvents >= 2).to.equal(true)
				expect(aimEvents[1]).to.equal(true)
				expect(aimEvents[2]).to.equal(false)
			end)

			-- REWRITTEN in Task 26 (round 1, finding 2). This used to assert that the camera did not
			-- move across the aim hold -- which, with the camera system built, asserts the OPPOSITE of
			-- what aiming is for, and could only pass while the camera was deaf to the aim button. What
			-- the weapon actually owes is that IT never writes the camera, and the camera's own
			-- foreign-write detector is the mechanical proof: Rig.apply records what it wrote and counts
			-- any value it did not set, so a write from anywhere else -- this weapon included -- shows
			-- up there (docs/design/camera.md section 10.1).
			it("never writes the camera itself", function()
				expect(#cameraSamples >= 2).to.equal(true)
				local cameraModule = scripts:FindFirstChild("Camera")
				if not cameraModule then
					-- No camera system in the place: the old evidence is the best available, and the
					-- stock camera is then the only other writer.
					print("[weapon_client] no camera system; asserting the camera did not change instead")
					expect(cameraSamples[1].fov).to.equal(cameraSamples[2].fov)
					expect(Weapon.Input.isAiming()).to.equal(false)
					return
				end
				local CameraSystem = require(cameraModule)
				local stats = CameraSystem.stats()
				print(
					string.format(
						"[weapon_client] camera foreign writes: %d (from %d) over %d frames",
						stats.foreignCameraWrites,
						foreignBefore,
						stats.frames
					)
				)
				expect(stats.foreignCameraWrites - foreignBefore).to.equal(0)
				-- And the aim request did reach the camera, which is what makes the zero meaningful:
				-- the camera moved, and only the camera moved it.
				expect(stats.aimEnters >= 1).to.equal(true)
			end)
		end)

		describe("the crosshair", function()
			it("is really on screen: every ancestor present and visible, centred on the viewport", function()
				local visible = waitUntil(RUN_TIMEOUT, function()
					return Hud.isCrosshairVisible()
				end)
				if not visible then
					local state = Weapon.get()
					print(
						string.format(
							"[weapon_client] crosshair not visible: gui=%s equipped=%s enabled=%s",
							tostring(Hud.gui() ~= nil),
							tostring(state and state.equipped),
							tostring(Shotgun.CONFIG.CROSSHAIR_ENABLED)
						)
					)
				end
				expect(visible).to.equal(true)

				local gui = Hud.gui()
				expect(gui).to.be.ok()
				expect(gui:IsA("ScreenGui")).to.equal(true)
				expect(gui.Enabled).to.equal(true)
				expect(gui.Parent).to.equal(player:FindFirstChildOfClass("PlayerGui"))

				local crosshair = gui:FindFirstChild("Crosshair")
				expect(crosshair).to.be.ok()
				expect(crosshair.Visible).to.equal(true)
				for _, name in ipairs({ "Top", "Bottom", "Left", "Right" }) do
					local armFrame = crosshair:FindFirstChild(name)
					expect(armFrame).to.be.ok()
					expect(armFrame.Visible).to.equal(true)
					expect(armFrame.BackgroundTransparency < 1).to.equal(true)
				end

				-- Reachability to the DataModel: an orphaned GUI tree is invisible however true its
				-- Visible properties are. The GuiObject branch is what would catch a hidden ancestor if
				-- the tree ever gains one; today the only ancestors are the ScreenGui and the PlayerGui,
				-- whose Enabled and Parent are checked above (round 1 note: the comment here used to
				-- claim more than the loop does).
				local node = crosshair.Parent
				while node and node ~= game do
					if node:IsA("GuiObject") then
						expect(node.Visible).to.equal(true)
					end
					node = node.Parent
				end
				expect(node).to.equal(game)

				-- AbsolutePosition does NOT account for IgnoreGuiInset, so a GUI that ignores the inset
				-- reports positions shifted by it (measured: 36 px in Y on this screen). Add it back
				-- before comparing with the viewport's own centre.
				local inset = GuiService:GetGuiInset()
				local centre = crosshair.AbsolutePosition + crosshair.AbsoluteSize / 2 + inset
				local viewport = Workspace.CurrentCamera.ViewportSize / 2
				print(
					string.format(
						"[weapon_client] crosshair centre %.1f,%.1f vs viewport centre %.1f,%.1f (inset %.0f,%.0f)",
						centre.X,
						centre.Y,
						viewport.X,
						viewport.Y,
						inset.X,
						inset.Y
					)
				)
				expect((centre - viewport).Magnitude <= 2).to.equal(true)
			end)

			it("reads out the barrels, the ammo and the reserve", function()
				local text = Hud.readoutText()
				print("[weapon_client] readout: " .. text)
				-- glyphs, ammo, the pocket for that ammo, an optional " R" while busy, and an optional
				-- one-line notice such as "NO BUCK" (Karen, 2026-09-25).
				expect(string.match(text, "^[%[%*%-x%]]+ [A-Z]+ %d+[ A-Z]*$")).to.be.ok()
			end)
		end)
	else
		describe("the driver's empty hands", function()
			it("is never given a Tool, anywhere, at any point in the session", function()
				-- The whole replay reaches this client too since Task 36 -- Q, the clicks, R and X all
				-- arrive -- so this is "every key a shooter uses was pressed here and produced nothing".
				task.wait(5)
				local backpack = player:FindFirstChildOfClass("Backpack")
				expect(backpack).to.be.ok()
				expect(backpack:FindFirstChildOfClass("Tool")).to.equal(nil)
				local character = player.Character
				expect(character).to.be.ok()
				expect(character:FindFirstChildOfClass("Tool")).to.equal(nil)
				expect(Weapon.get()).to.equal(nil)
			end)

			it("binds none of the weapon's input actions, so its keys do nothing", function()
				-- PlayerScripts.Weapon.Input binds on Tool.Equipped and unbinds on Unequipped, and it is
				-- the ONLY binder of the DrivenHunt.Weapon.* prefix. No Tool, no actions.
				for name in pairs(ContextActionService:GetAllBoundActionInfo()) do
					expect(string.sub(name, 1, 18)).never.to.equal("DrivenHunt.Weapon.")
				end
				expect(Weapon.Input.isAiming()).to.equal(false)
			end)

			it("never draws a crosshair, because there is nothing to aim", function()
				expect(Hud.isCrosshairVisible()).to.equal(false)
				expect(Hud.readoutText()).to.equal("")
				-- The Hud itself is up: this is "no crosshair", not "no Hud".
				expect(Hud.gui()).to.be.ok()
				expect(Hud.isDriveBarVisible()).to.equal(true)
			end)
		end)
	end

	describe("the exploit path", function()
		it("ignores every request a client must not be able to make", function()
			-- THIS WINDOW ASSUMES NOBODY RE-ARMS THIS PLAYER while it is open, and that assumption
			-- is worth stating: a snapshot deliberately carries no epoch (weapon_state.spec asserts
			-- it), so a fresh weapon handed out mid-window is indistinguishable here from an exploit
			-- that refilled the pockets. What keeps it true is that the only thing that re-arms a
			-- player is a change of answer -- and the arming sweep never re-grants a player who is
			-- correctly armed (weapon_rearm.spec). A spec that revoked this gun mid-session broke
			-- exactly this window, and was withdrawn (Task 34).
			local before = Weapon.get()
			if Role.isDriver() then
				-- The sharper version of the same claim: a driver has no state at all, and firing
				-- every request a client can fire must not conjure him one.
				expect(before).to.equal(nil)
				local channel = Shotgun.remotes()
				for _, bad in ipairs({ "Break", "Load", "Close", "Fire", "", 42 }) do
					channel.ActionRequest:FireServer(bad)
				end
				channel.ActionRequest:FireServer("SelectAmmo", "Slug")
				channel.FireRequest:FireServer({ origin = Vector3.zero, direction = Vector3.new(0, 0, 1) })
				task.wait(1)
				expect(Weapon.get()).to.equal(nil)
				local backpack = player:FindFirstChildOfClass("Backpack")
				expect(backpack and backpack:FindFirstChildOfClass("Tool")).to.equal(nil)
				return
			end
			expect(before).to.be.ok()
			local remotes = Shotgun.remotes()
			-- The reducer's own primitives, which Validator.checkRequest does not accept at all.
			for _, bad in ipairs({ "Break", "Load", "Close", "Fire", "", 42 }) do
				remotes.ActionRequest:FireServer(bad)
			end
			remotes.ActionRequest:FireServer({})
			remotes.ActionRequest:FireServer("SelectAmmo", "Grenade")
			remotes.FireRequest:FireServer("not a table")
			remotes.FireRequest:FireServer({ origin = "x", direction = Vector3.zero })
			task.wait(1)

			local after = Weapon.get()
			expect(after.open).to.equal(before.open)
			expect(after.reserve.Slug).to.equal(before.reserve.Slug)
			expect(after.reserve.Buck).to.equal(before.reserve.Buck)
			expect(after.ammo).to.equal(before.ammo)
			expect(after.barrels[1]).to.equal(before.barrels[1])
			expect(after.barrels[2]).to.equal(before.barrels[2])
			expect(after.loaded[1]).to.equal(before.loaded[1])
		end)
	end)

	describe("cleanup", function()
		it("unbinds the cue key", function()
			ContextActionService:UnbindAction(CUE_ACTION)
			expect(ContextActionService:GetAllBoundActionInfo()[CUE_ACTION]).to.equal(nil)
		end)
	end)
end
