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

local CUE_ACTION = "DrivenHunt.Test.WeaponCue"
local RUN_TIMEOUT = 40

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Weapon = require(scripts:WaitForChild("Weapon"))
local Hud = require(scripts:WaitForChild("Hud"))

-- Every snapshot the server published, in order, with the client clock that received it.
local log = {}
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

local function last()
	return if #log > 0 then log[#log].state else nil
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
			expect(waitUntil(20, function()
				return Weapon.get() ~= nil
			end)).to.equal(true)
			local state = Weapon.get()
			expect(type(state.equipped)).to.equal("boolean")
			expect(type(state.reserve)).to.equal("number")
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

	describe("the harness-driven weapon", function()
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
					and state.reserve == 24
					and state.selected == 1
				then
					sawFull = true
					break
				end
			end
			expect(sawFull).to.equal(true)
			expect(equippedAt).to.be.ok()
		end)

		it("runs the whole scenario and ends where the design says", function()
			local finished = waitUntil(RUN_TIMEOUT, function()
				local state = last()
				return state ~= nil and state.ammo == "Buck" and state.busyFor == 0 and #aimEvents >= 2
			end)
			if not finished then
				local state = last()
				print(
					string.format(
						"[weapon_client] %d snapshots; last: ammo=%s reserve=%s busyFor=%.2f aims=%d",
						#log,
						tostring(state and state.ammo),
						tostring(state and state.reserve),
						(state and state.busyFor) or -1,
						#aimEvents
					)
				)
			end
			expect(finished).to.equal(true)

			local state = last()
			print(
				string.format(
					"[weapon_client] end state: barrels=%s/%s loaded=%s/%s selected=%d ammo=%s reserve=%d open=%s",
					state.barrels[1],
					state.barrels[2],
					state.loaded[1],
					state.loaded[2],
					state.selected,
					state.ammo,
					state.reserve,
					tostring(state.open)
				)
			)
			expect(state.equipped).to.equal(true)
			expect(state.open).to.equal(false)
			expect(state.barrels[1]).to.equal("Live")
			expect(state.barrels[2]).to.equal("Live")
			-- SelectAmmo changes the NEXT load only: the shells in the barrels are still slugs.
			expect(state.loaded[1]).to.equal("Slug")
			expect(state.loaded[2]).to.equal("Slug")
			expect(state.selected).to.equal(1)
			expect(state.ammo).to.equal("Buck")
			-- One reload of exactly two shells: 24 - 2. The uninterruptible property behind it is
			-- asserted exactly in weapon_state.spec; see the note at the top of this file.
			expect(state.reserve).to.equal(22)
		end)

		it("fired exactly twice: an empty gun refused the third click", function()
			-- Three clicks were sent: two into a loaded gun and one into a gun with both barrels
			-- spent. Only the first two may spend a barrel -- no phantom shot.
			local rises = 0
			local previous = 0
			for _, entry in ipairs(log) do
				local spent = spentCount(entry.state)
				if spent > previous then
					rises += 1
				end
				previous = spent
			end
			print(string.format("[weapon_client] shots seen: %d over %d snapshots", rises, #log))
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

		it("raised and lowered the aim flag exactly once each", function()
			expect(#aimEvents).to.equal(2)
			expect(aimEvents[1]).to.equal(true)
			expect(aimEvents[2]).to.equal(false)
			expect(Weapon.Input.isAiming()).to.equal(false)
		end)

		-- The brief's requirement, in the strongest form that is TRUE: the stock PlayerModule is the
		-- camera's live writer and moves it every frame to follow the character, so a byte-identical
		-- CFrame would be asserting a property of Roblox's camera script, not of this weapon.
		-- CameraType and FieldOfView are what the stock camera leaves alone and an ADS would not.
		it("never touched the camera while aiming", function()
			expect(#cameraSamples).to.equal(2)
			local down, up = cameraSamples[1], cameraSamples[2]
			expect(down.cameraType).to.equal(up.cameraType)
			expect(down.fov).to.equal(up.fov)
			expect(down.subject).to.equal(up.subject)
			if down.offset and up.offset then
				local drift = (up.offset - down.offset).Magnitude
				print(string.format("[weapon_client] camera drift across the aim hold: %.3f studs", drift))
				expect(drift <= Shotgun.CONFIG.CAMERA_DRIFT_TOLERANCE).to.equal(true)
			end
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

			-- Parent visibility, which is what a "visible = true" audit misses.
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
			expect(string.match(text, "^[%[%*%-x%]]+ [A-Z]+ %d+ ?R?$")).to.be.ok()
		end)
	end)

	describe("the exploit path", function()
		it("ignores every request a client must not be able to make", function()
			local before = Weapon.get()
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
			expect(after.reserve).to.equal(before.reserve)
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
