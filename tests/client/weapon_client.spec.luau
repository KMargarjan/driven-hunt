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
-- THE WEAPON TABLE, for the one assertion that is about HOW MANY Tools a hunter carries
-- (task 149): the RIFLE flag's default went ON, so the loadout is two and a literal 1 was a
-- count of the world before it.
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
-- NOTES, NOT PRINTS, for anything that explains a failure. TestKit's own header says why: "Studio's
-- console comes back truncated from a long session -- every two-player run so far lost the head of
-- it". Task 80 lost a whole diagnostic run to exactly that: the map world's console came back
-- `[TRUNCATED DUE TO LENGTH LIMIT]` and every print from this file with it, while the notes arrived.
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))

local CUE_ACTION = "DrivenHunt.Test.WeaponCue"
local RUN_TIMEOUT = 70 -- Task 36: two clients share one replay, so every step costs two calls

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Weapon = require(scripts:WaitForChild("Weapon"))
local Hud = require(scripts:WaitForChild("Hud"))
-- WHICH VIEW THIS BUILD IS RUNNING, asked of the camera and not of `Flags` (the camera owns the
-- switch and republishes it as a fact about the view, docs/design/camera.md section 6.2). Two of the
-- claims below are different claims in the two branches: there is no crosshair in first person at
-- all, and the muzzle a shot's light is drawn at is the DRAWN gun's there rather than the world's.
--
-- RESOLVED LAZILY AND TOLERANTLY, the way "never writes the camera itself" below already does it:
-- this spec is the WEAPON's, and it still has to run in a place with no camera system in it.
local function cameraView()
	local module = scripts:FindFirstChild("Camera")
	return if module then require(module) else nil
end

local function liveFirstPerson(): boolean
	local view = cameraView()
	return view ~= nil and view.isFirstPerson()
end

-- Every snapshot the server published, in order, with the client clock that received it.
local log = {}
-- ...and how much of it belongs to THIS scenario. Task 30 added `shoot-the-boar`, which fires the
-- same gun later in the same Play session, so "exactly two shots" and "it ends here" are claims
-- about a window, not about the session. The window closes when the harness stages the next
-- scenario -- the one event that says another scenario has taken the gun (tools/studio_mcp.py, the
-- `stage` step, which sets this attribute and nothing else does).
local ownLogEntries: number? = nil
-- WHEN THIS SPEC TOOK THE GUN, and what the gun held then: the near end of its own window (Task 80).
-- Declared here because `ownLog` below reads it.
local equippedAt = nil
local baseline = nil
player:GetAttributeChangedSignal("StagedTarget"):Connect(function()
	ownLogEntries = ownLogEntries or #log
end)

-- THIS SPEC'S OWN WINDOW: from its cue to the moment the harness staged the next scenario.
--
-- BOTH ENDS ARE CAUSAL, and the near end is new (Task 80). It used to start at the beginning of the
-- session, so anything the owner's auto-equip let through before the cue counted as this spec's --
-- which is exactly how a slug fired at +4.1 s became "3 shots where the replay fires two", and how
-- 77a(a) read the same 23-slugs-and-3-shots when a spec file loaded in a different order. Neither was
-- about order or timing: the window simply had no near end.
local function ownLog()
	local out = {}
	for index = 1, ownLogEntries or #log do
		local entry = log[index]
		if not equippedAt or entry.at >= equippedAt then
			table.insert(out, entry)
		end
	end
	return out
end
local aimEvents = {}
local cameraSamples = {}

local suiteStart = os.clock()

Weapon.Changed:Connect(function(snapshot)
	table.insert(log, { at = os.clock(), state = snapshot })
	-- The baseline, if the cue could not read one itself: the first snapshot of this spec's window.
	if equippedAt and not baseline then
		baseline = snapshot
	end
end)

-- EVERY TOOL THE OWNER HANDS THIS PLAYER (Task 80). `Weapon.grant` destroys the recorded Tool,
-- builds a new one, resets the state to `StateMachine.initial` -- reserve back to full -- and then
-- AUTO-EQUIPS it, because `Shotgun.CONFIG.AUTO_EQUIP` is true (Karen: a playtest should not start by
-- hunting for the hotbar). `Weapon.refreshArming`'s sweep calls grant again whenever it finds a
-- player who should be holding one, so a session sees several. That makes "the gun is in the Backpack
-- because this spec parked it" an arrangement the OWNER is free to undo, with no input at all -- and
-- a gun in the hand when the replay's first click arrives fires a shell nothing in this file asked
-- for. This is the record of it, so a wrong shot count says WHERE the extra shot came from.
local guns: { { at: number, where: string } } = {}
local seen: { [Instance]: true } = {}
local function sawGun(child: Instance, where: string)
	if child.Name ~= "Shotgun" or not child:IsA("Tool") or seen[child] then
		return
	end
	seen[child] = true
	table.insert(guns, { at = os.clock() - suiteStart, where = where })
end

local function watchBag()
	local bag = player:FindFirstChildOfClass("Backpack")
	if bag then
		for _, child in ipairs(bag:GetChildren()) do
			sawGun(child, "backpack")
		end
		bag.ChildAdded:Connect(function(child)
			sawGun(child, "backpack")
		end)
	end
end
watchBag()
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watchBag()
	end
end)

local function watchBody(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		sawGun(child, "hand")
	end
	character.ChildAdded:Connect(function(child)
		sawGun(child, "hand")
	end)
end
if player.Character then
	watchBody(player.Character)
end
player.CharacterAdded:Connect(watchBody)

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

-- KEEP the Tool in the Backpack until the cue, and that is not optional: CONFIG.AUTO_EQUIP is true
-- (Karen's playtest should start with the gun in hand), so a gun in the character when Task 6's
-- `key-mouse-order` scenario sends MouseButton1 fires a shell nothing in this file asked for.
-- Unequipping unbinds the weapon's own actions (Tool.Unequipped), so scenario 1's clicks reach
-- nothing, and the cue key puts it back. This is the spec's arrangement; nothing asserted afterwards
-- depends on it.
--
-- AN INVARIANT, NOT A ONE-OFF ACT, and Task 80 measured why. `parkTool` used to return true the
-- moment it found the gun in the Backpack -- "already parked" -- and the OWNER then auto-equipped it
-- a moment later, because `Weapon.grant` ends with `Hardware.equip` and `refreshArming`'s sweep calls
-- grant repeatedly. On the map world that race was lost about one run in three: the failing run's own
-- note read `3 gun(s) handed over [+2.2s backpack, ...]; rises [#1 at +4.1s None/Slug res=24/24
-- BEFORE THE CUE, ...]` -- a slug fired at +4.1 s, before this spec's cue at +4.5 s, and the gun was
-- never unequipped at all. So the watcher below keeps unequipping until the cue: the owner may hand
-- the gun over as often as it likes, and the replay's early clicks still reach nothing.
local cueGiven = false
local function unequipNow(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local held = character and character:FindFirstChild("Shotgun")
	if humanoid and held then
		humanoid:UnequipTools()
		return true
	end
	return false
end

local function keepParked(character: Model)
	character.ChildAdded:Connect(function(child)
		if not cueGiven and child.Name == "Shotgun" and child:IsA("Tool") then
			unequipNow()
		end
	end)
end
if player.Character then
	keepParked(player.Character)
end
player.CharacterAdded:Connect(keepParked)

-- The cue: equip the Tool the way the Backpack does, so Tool.Equipped fires on the client and the
-- server sees Tool.Parent become the character. Equipping is this spec's arrangement; everything
-- asserted afterwards arrives through the real input path.
local function onCue(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = player:FindFirstChildOfClass("Backpack")
		local tool = backpack and backpack:FindFirstChild("Shotgun")
		-- THE CUE IS THIS SPEC'S OWN WINDOW OPENING, so the parking watcher stands down here and
		-- nothing before this moment counts against the assertions below (Task 80).
		cueGiven = true
		baseline = baseline or Weapon.get()
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

-- WHEN THE REPLAY LAST TOUCHED THIS GUN. The exploit window below has to be quiet to mean anything:
-- its whole claim is "the server did nothing", and a legitimate reload arriving inside it looks
-- exactly like the server acting on a forged `Break`. There is no way to tell those apart from the
-- state, so the window is opened only when none of the weapon's own inputs has arrived for a while --
-- and thrown away and retried if one arrives while it is open. `Pass`, like every probe here, so
-- nothing a player does is swallowed.
local QUIET_ACTION = "DrivenHunt.Test.WeaponQuiet"
local lastWeaponInput = 0
ContextActionService:BindAction(QUIET_ACTION, function()
	lastWeaponInput = os.clock()
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.R, Enum.KeyCode.X, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2)

local function parkTool(): boolean
	local deadline = os.clock() + 15
	repeat
		local backpack = player:FindFirstChildOfClass("Backpack")
		if unequipNow() then
			return true
		end
		if backpack and backpack:FindFirstChild("Shotgun") then
			return true -- in the Backpack, and the watcher above keeps it there
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

		-- --------------------------------------------------- the flash comes from the pipes (task 92)
		it("draws MY shot at my drawn muzzle and everyone else's where the world says", function()
			-- KAREN, after playing S2 (2026-09-27): "when firing this animation where flies light has
			-- to be from pipes not from shoulder." In first person the Tool is in the character's
			-- hand, hidden, and the gun the player SEES is the camera's clone -- so for MY OWN shot
			-- the server's muzzle position is off at the shoulder.
			--
			-- ROUND 1'S DEFECT WAS THE OTHER HALF OF THAT SENTENCE. `Effects.play` runs for EVERY
			-- payload, so asking the provider without checking who fired drew a teammate's flash,
			-- smoke and tracers out of MY barrel. Both cases are driven here, and the shooter is the
			-- only thing that differs between them.
			local Effects = Weapon.Effects
			local live = Effects.getMuzzleProvider()
			-- NOBODY DRAWS THE FIRST-PERSON FLASH FOR THE LENGTH OF THIS CASE (task 114). `Effects`
			-- asks the viewmodel first and skips its own pair when the answer is yes (task 112), and
			-- since the gun flag retired the LIVE answer for my own shot is yes whenever a viewmodel
			-- is on screen -- which depends on whether this client happens to be a shooter holding
			-- the gun. What this case is about is WHOSE MUZZLE the parts come out of, so the other
			-- owner is stood down and put back. The skip itself is asserted in `gun_client.spec`.
			--
			-- BOTH SEAMS ARE PUT BACK THROUGH A `pcall` (round 1's note). Restoring them after the
			-- assertions only works when the assertions pass: a failure between here and the restore
			-- would otherwise leave the live first-person flash provider nil for the whole rest of the
			-- session, so every later shot in it would draw the world pair on top of the viewmodel's.
			-- `gun_client.spec`'s `withNewGun` is the shape this follows.
			local liveFlash = Effects.getViewmodelFlash()
			Effects.setViewmodelFlash(nil)
			local ok, why = pcall(function()
				local worldFrame = CFrame.new(10, 20, 30) * CFrame.Angles(0, math.pi / 3, 0)
				local drawn = CFrame.new(-5, 2, -5)
				local askedFor: { number? } = {}
				Effects.setMuzzleProvider(function(barrel: number?): CFrame?
					table.insert(askedFor, barrel)
					return drawn
				end)
				local function payloadFrom(userId: number)
					return {
						shooterUserId = userId,
						muzzle = worldFrame.Position,
						muzzleCFrame = worldFrame,
						barrel = 1,
						impacts = { worldFrame.Position + worldFrame.LookVector * 30 },
						ammo = "Buck",
					}
				end
				local mine = payloadFrom(Players.LocalPlayer.UserId)
				-- NOT A LITERAL -1. MEASURED, in this task's two-player gate: a Studio test client gets a
				-- NEGATIVE UserId (-1 for the first, -2 for the second), so "another player" written as -1
				-- was the shooter's own id in that window -- the case failed on the shooter and passed on
				-- the driver, which is a fixture fault and not the rule under test. Derived from the local
				-- id, so it is another player wherever this runs.
				local otherId = Players.LocalPlayer.UserId - 7
				expect(otherId).never.to.equal(Players.LocalPlayer.UserId)
				local theirs = payloadFrom(otherId)

				-- MY SHOT: the drawn gun, and the provider is told which pipe fired.
				expect(Effects.muzzleFrame(mine)).to.equal(drawn)
				expect(askedFor[1]).to.equal(1)

				-- SOMEBODY ELSE'S SHOT: the world, and the provider is not even asked -- the count is the
				-- assertion, because a provider that answered nil would look the same at the call site.
				local asked = #askedFor
				expect(Effects.muzzleFrame(theirs)).to.equal(worldFrame)
				expect(#askedFor).to.equal(asked)
				-- ...and a payload with no frame at all still draws, at the bare position the payload has
				-- always carried: an older server, or a gun with no attachment.
				local bare = table.clone(theirs)
				bare.muzzleCFrame = nil
				expect(Effects.muzzleFrame(bare).Position).to.equal(worldFrame.Position)

				-- AND IT IS REALLY WHERE THE PARTS GO, for both shots: flash, smoke AND the tracer, which
				-- is built from the same origin and stretched from my muzzle to their impacts by the
				-- defect this case now covers.
				local folder = Effects.folder()
				local function playAndMeasure(payload)
					for _, child in ipairs(folder:GetChildren()) do
						child:Destroy()
					end
					Effects.play(payload)
					local flash = folder:FindFirstChild("Flash") :: BasePart
					local smoke = folder:FindFirstChild("Smoke") :: BasePart
					local tracer = folder:FindFirstChild("Tracer") :: BasePart
					expect(flash).to.be.ok()
					expect(smoke).to.be.ok()
					expect(tracer).to.be.ok()
					return flash.Position, smoke.Position, tracer.Position
				end

				local flashMine, smokeMine = playAndMeasure(mine)
				expect((flashMine - drawn.Position).Magnitude < 0.6).to.equal(true)
				expect((smokeMine - drawn.Position).Magnitude < 0.8).to.equal(true)
				expect((flashMine - worldFrame.Position).Magnitude > 10).to.equal(true)
				-- Forward of the muzzle, not inside the barrel: -Z is the bore direction.
				expect(drawn:PointToObjectSpace(flashMine).Z < 0).to.equal(true)

				local flashTheirs, smokeTheirs, tracerTheirs = playAndMeasure(theirs)
				expect((flashTheirs - worldFrame.Position).Magnitude < 0.6).to.equal(true)
				expect((smokeTheirs - worldFrame.Position).Magnitude < 0.8).to.equal(true)
				expect((flashTheirs - drawn.Position).Magnitude > 10).to.equal(true)
				-- the tracer is the one the defect stretched across the map: its midpoint belongs to the
				-- shooter's own muzzle, not to mine.
				expect((tracerTheirs - drawn.Position).Magnitude > 10).to.equal(true)

				TestKit.note(
					string.format(
						"task92 flash: my shot %.2f studs from my drawn muzzle; another player's %.2f studs "
							.. "from the world muzzle and %.1f from mine",
						(flashMine - drawn.Position).Magnitude,
						(flashTheirs - worldFrame.Position).Magnitude,
						(flashTheirs - drawn.Position).Magnitude
					)
				)
				for _, child in ipairs(folder:GetChildren()) do
					child:Destroy()
				end
			end)
			Effects.setMuzzleProvider(live)
			Effects.setViewmodelFlash(liveFlash)
			if not ok then
				error(why, 0)
			end
			-- THE LIVE WIRING IS PUT BACK -- BOTH SEAMS -- and both were there to begin with:
			-- `CameraBoot` installs them, so a nil here would mean the composition root never ran.
			--
			-- WHAT IT ANSWERS IS THE BRANCH'S OWN TRUTH. In third person the player is looking at
			-- their character holding the real gun, so the provider answers nil and the flash is
			-- drawn at the world muzzle. In first person -- the live branch since task 97 -- it
			-- answers the DRAWN gun's muzzle whenever there is a drawn gun, and nil when there is
			-- none (a driver holds no Tool, so there is no viewmodel to ask).
			expect(Effects.getMuzzleProvider()).to.be.ok()
			expect(Effects.getViewmodelFlash()).to.be.ok()
			--
			-- THE CLAIM IS THAT THE PROVIDER IS THE CAMERA'S OWN ANSWER, which is what the composition
			-- root wired, and it is one claim in both branches: third person answers nil (the player
			-- is looking at their character holding the real gun) and first person answers the DRAWN
			-- gun's muzzle. Asserting "not nil in first person" was a claim about whether a viewmodel
			-- with a `Muzzle` attachment happened to be on screen at this moment, which is a
			-- different question and one this case does not stage.
			local answer = (Effects.getMuzzleProvider() :: any)(1)
			local view = cameraView()
			expect(answer).to.equal(if view then view.viewmodelMuzzle(1) else nil)
			if not liveFirstPerson() then
				expect(answer).to.equal(nil)
			end
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

		-- THREE TOOLS BROKE THIS REPLICA, and the fix is an ordering rule (task 143). The server
		-- publishes PER TOOL, so one keypress sends TWO snapshots -- the gun being put away and the
		-- gun being taken out -- and with one variable the last to arrive won. Measured in the
		-- Forest Test: switching to slot 3 left `Weapon.get()` holding the rifle's un-equipped
		-- snapshot, the readout went blank and the aim source refused to aim, for the open rifle AND
		-- for the shotgun after it. With two weapons the ordering happened to come out right.
		--
		-- DRIVEN AS A FUNCTION, NOT AS A SESSION: the hotbar keys 1/2/3 cannot be replayed at all
		-- (`VirtualInput`: "permanently bound to a CoreGUI core action", task 141), so the orderings
		-- below are the real ones written down rather than hoped for.
		it("answers with the gun whose newest snapshot claimed the hand", function()
			local function snap(id, equipped)
				return Shotgun.deepFreeze({ weapon = id, equipped = equipped })
			end
			-- THE THIRD ID IS FABRICATED, and since task 148 that is all it is: Karen retired the
			-- open-sighted rifle, so `Weapons.ORDER` is two again -- but the ordering rule this case
			-- exists for is about N replicas and not about which guns exist, and the day a third
			-- weapon arrives it must already hold.
			local shotgun, rifle = snap("shotgun", false), snap("rifle", false)
			local openRifle, openHeld = snap("third", false), snap("third", true)
			local rifleHeld = snap("rifle", true)

			-- the switch to slot 3, in the order the server sends it: the new gun's equip, then the
			-- old gun's un-equip. The un-equip arrives LAST and must not win.
			local replicas = { rifle = rifleHeld, third = openHeld }
			expect(Weapon.heldFrom(replicas, "third", rifle).weapon).to.equal("third")
			-- ...and the other order, where the un-equip comes first
			replicas = { rifle = rifle, third = openHeld }
			expect(Weapon.heldFrom(replicas, "third", openHeld).weapon).to.equal("third")
			-- A STALE `equipped` CANNOT WIN. The rifle's un-equip was dropped, so its own replica
			-- still says it is held -- but the open rifle claimed the hand after it.
			replicas = { rifle = rifleHeld, third = openHeld }
			expect(Weapon.heldFrom(replicas, "third", openHeld).weapon).to.equal("third")
			-- nothing holds the hand: the newest snapshot of any weapon, which is what every caller
			-- written before three weapons got
			replicas = { shotgun = shotgun, rifle = rifle, third = openRifle }
			expect(Weapon.heldFrom(replicas, nil, shotgun).weapon).to.equal("shotgun")
			expect(Weapon.heldFrom(replicas, "rifle", rifle).weapon).to.equal("rifle")
			-- ...and an empty replica set is nil rather than an error
			expect(Weapon.heldFrom({}, nil, nil)).to.equal(nil)
			expect(Weapon.heldFrom({}, "rifle", nil)).to.equal(nil)
		end)

		it("exposes the aim seam the camera task will attach to", function()
			expect(typeof(Weapon.Input.AimChanged)).to.equal("RBXScriptSignal")
			expect(type(Weapon.Input.isAiming())).to.equal("boolean")
		end)

		-- THE RACE THAT MADE `test2` UNRELIABLE (two failures in three runs, Director, Task 48). The
		-- watcher used to drop a Tool only from its own `AncestryChanged` with `parent == nil`, and
		-- Roblox's signals are DEFERRED (measured in Task 47) -- so on a respawn the NEW Tool, granted
		-- by the server on `CharacterAdded` and delivered through the new Backpack's `ChildAdded`, was
		-- watched before the old one's handler ran, and for that moment two Tools were watched.
		--
		-- This reproduces the ordering without depending on which deferred signal drains first, and it
		-- is the stronger case: the old Tool LEAVES THE PLAYER'S CONTAINERS WITHOUT ITS PARENT
		-- BECOMING NIL, so the old rule never fired at all and it was watched for the rest of the
		-- session. Before the fix this reads two more than it started with; after it, one.
		it("drops a dead Tool no later than it watches a new one", function()
			local backpack = player:WaitForChild("Backpack")
			local before = Weapon.Input.watchedTools()

			local function settleUntil(predicate: () -> boolean): boolean
				local deadline = os.clock() + 5
				while os.clock() < deadline do
					if predicate() then
						return true
					end
					task.wait()
				end
				return false
			end

			local old = Instance.new("Tool")
			old.Name = "Shotgun" -- the watcher filters on the name
			old.RequiresHandle = false
			old.Parent = backpack
			expect(settleUntil(function()
				return Weapon.Input.watchedTools() == before + 1
			end)).to.equal(true)

			-- Out of the player's containers, parent NOT nil: the departure the old rule could not see.
			old.Parent = ReplicatedStorage

			local new = Instance.new("Tool")
			new.Name = "Shotgun"
			new.RequiresHandle = false
			new.Parent = backpack

			-- Let every deferred signal drain, then read once. The claim is a CEILING, so waiting for
			-- it to be true would hide the failure; this waits for the new Tool to be watched at all
			-- and then asserts the count did not climb.
			task.wait(0.5)
			local peak = Weapon.Input.watchedTools()
			old:Destroy()
			new:Destroy()

			if peak > before + 1 then
				error(
					string.format(
						"the watcher held %d Tools where %d is the ceiling: a dead Tool was still watched "
							.. "when a new one arrived (24a(c), Task 48)",
						peak,
						before + 1
					),
					0
				)
			end

			-- And it leaves the set as it found it, so the test after this one is not reading residue.
			expect(settleUntil(function()
				return Weapon.Input.watchedTools() <= before
			end)).to.equal(true)
		end)

		it("listens to the LOADOUT's Tools, however many the session has destroyed", function()
			-- TASKS.md 24a(c). The Tool dies with the Backpack or the character every time the drive
			-- places a player (Match.Body.place -> LoadCharacter), and the watcher used to keep the
			-- dead one's key and both its connections for ever -- one set per respawn, cleared only
			-- by Input.stop(), which nothing calls. This session has already respawned at least once
			-- by the time the drive assigns teams, so a count above the loadout is the leak.
			--
			-- IT WAS A LITERAL 1 UNTIL TASK 149, which was the whole loadout when it was written and
			-- stopped being so the moment the RIFLE flag's default went ON. The leak this guards is
			-- "one more set per respawn", so the honest bound is what the hunter actually carries --
			-- and now a third weapon would not quietly turn the guard into a tautology either.
			local carried = #Weapons.loadout()
			expect(carried >= 1).to.equal(true)
			expect(Weapon.Input.watchedTools() <= carried).to.equal(true)
			TestKit.note(
				string.format("weapon-client: %d tool(s) watched, loadout is %d", Weapon.Input.watchedTools(), carried)
			)
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
				-- OVER THE LOG, BOTH HALVES (task 112). This waited on `Weapon.get().equipped` and
				-- then said, one line down, that `Weapon.get()` is the wrong thing to ask -- "by the
				-- time a later `it` runs, the scenario has moved on". It does: the LAST scenario in
				-- `input_scenarios.txt` is `tie-the-driver`, which exists to get this shooter TIED,
				-- and a tied player's gun goes to his backpack. So by the time this case ran the
				-- wait could only time out, which is what it did on three separate `test2` runs
				-- (tasks 108 and 112). The equip is a claim about the BEGINNING of the session and
				-- the log is where the beginning is kept.
				local sawEquipped = false
				for _, entry in ipairs(log) do
					if entry.state.equipped then
						sawEquipped = true
						break
					end
				end
				TestKit.note(
					string.format(
						"weapon_client: equipped in %d of %d logged snapshot(s)",
						if sawEquipped then 1 else 0,
						#log
					)
				)
				expect(sawEquipped).to.equal(true)
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
					TestKit.note(
						string.format(
							"weapon_client: %d snapshots; last: ammo=%s slug=%s busyFor=%.2f aims=%d",
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
				TestKit.note(
					string.format(
						"weapon_client: end state: barrels=%s/%s loaded=%s/%s selected=%d ammo=%s slug=%d buck=%d open=%s",
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
				-- A DELTA FROM THE CUE, not an absolute (Task 80). These used to read `== 24` and
				-- `== 22`, which is `Shotgun.CONFIG`'s starting pocket -- a claim about the whole
				-- session rather than about this spec's window. `Weapon.grant` resets the reserve to
				-- full whenever the owner hands over a new gun, and a shot before the cue leaves it one
				-- short for ever, so the absolute was right only when nothing had touched the gun
				-- first. Slug: -2 for the R reload, +2 returned when X broke the action open, so back
				-- to what the gun held at the cue. Buck: -2, the two that came out for the swap.
				expect(baseline).to.be.ok()
				expect(state.reserve.Slug).to.equal(baseline.reserve.Slug)
				expect(state.reserve.Buck).to.equal(baseline.reserve.Buck - 2)
			end)

			it("fired exactly twice: an empty gun refused the third click", function()
				-- Three clicks were sent: two into a loaded gun and one into a gun with both barrels
				-- spent. Only the first two may spend a barrel -- no phantom shot.
				local entries = ownLog()
				local rises = 0
				local previous = 0
				local when = {}
				for _, entry in ipairs(entries) do
					local spent = spentCount(entry.state)
					if spent > previous then
						rises += 1
						-- WHICH shot, not just how many (Task 80). An extra one is either the replay
						-- firing three times or a gun that was in the hand before this spec's cue,
						-- and the reserve at the moment it went off says which.
						table.insert(
							when,
							string.format(
								"#%d at +%.1fs %s/%s res=%d/%d%s",
								rises,
								entry.at - suiteStart,
								tostring(entry.state.loaded[1]),
								tostring(entry.state.loaded[2]),
								entry.state.reserve.Slug or -1,
								entry.state.reserve.Buck or -1,
								if equippedAt and entry.at < equippedAt then " BEFORE THE CUE" else ""
							)
						)
					end
					previous = spent
				end
				local handed = {}
				for index, gun in ipairs(guns) do
					handed[index] = string.format("+%.1fs %s", gun.at, gun.where)
				end
				TestKit.note(
					string.format(
						"weapon_client: shots seen: %d over %d snapshots (%d in the session); cue at "
							.. "+%.1fs; %d gun(s) handed over [%s]; rises [%s]",
						rises,
						#entries,
						#log,
						if equippedAt then equippedAt - suiteStart else -1,
						#guns,
						table.concat(handed, ", "),
						table.concat(when, ", ")
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
				-- OVER THIS SCENARIO'S OWN LOG (TASKS.md 30a(d)). Scanning the whole session let a
				-- later scenario satisfy half of this by itself -- `shoot-the-boar` fires the same gun
				-- and reloads it -- so "the swap happened" was a claim about the session and not about
				-- the X this scenario pressed. Two siblings were converted in Task 30 and this one was
				-- missed.
				local sawSwapInProgress, sawSwapDone = false, false
				for _, entry in ipairs(ownLog()) do
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
					TestKit.note("weapon_client: no camera system; asserting the camera did not change instead")
					expect(cameraSamples[1].fov).to.equal(cameraSamples[2].fov)
					expect(Weapon.Input.isAiming()).to.equal(false)
					return
				end
				local CameraSystem = require(cameraModule)
				local stats = CameraSystem.stats()
				TestKit.note(
					string.format(
						"weapon_client: camera foreign writes: %d (from %d) over %d frames",
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
				-- NO CROSSHAIR AT ALL IN FIRST PERSON (Karen, 2026-09-27), which is the live branch
				-- since task 97. That is a DIFFERENT CLAIM about the same screen, not a skip: the
				-- Hud is up, the Crosshair Instance still exists, and it is never visible. The
				-- camera's own spec asserts the Hud asks the camera rather than the flag.
				if liveFirstPerson() then
					expect(Hud.isCrosshairVisible()).to.equal(false)
					local gui = Hud.gui()
					expect(gui).to.be.ok()
					expect(gui.Enabled).to.equal(true)
					local hidden = gui:FindFirstChild("Crosshair")
					expect(hidden).to.be.ok()
					expect(hidden.Visible).to.equal(false)
					TestKit.note("weapon_client: first person -- the crosshair exists and is never drawn")
					return
				end
				local visible = waitUntil(RUN_TIMEOUT, function()
					return Hud.isCrosshairVisible()
				end)
				if not visible then
					local state = Weapon.get()
					TestKit.note(
						string.format(
							"weapon_client: crosshair not visible: gui=%s equipped=%s enabled=%s",
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
				TestKit.note(
					string.format(
						"weapon_client: crosshair centre %.1f,%.1f vs viewport centre %.1f,%.1f (inset %.0f,%.0f)",
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
				TestKit.note("weapon_client: readout: " .. text)
				-- THE SHAPE IS ASKED OF A STATE THIS CASE OWNS (round 2's finding: the version before
				-- this returned before its only assertion when the player was tied, which is every
				-- `test2` run -- the last scenario ties him on purpose). `Hud.readoutFor` is the
				-- formatter itself, so this asserts the thing the screen is written from rather than
				-- whatever the screen happens to hold while he is roped to a tree.
				--
				-- glyphs, ammo, the pocket for that ammo, an optional " R" while busy, and an optional
				-- one-line notice such as "NO BUCK" (Karen, 2026-09-25).
				local SHAPE = "^[%[%*%-x%]]+ [A-Z]+ %d+[ A-Z]*$"
				local mine = {
					equipped = true,
					barrels = { "Live", "Spent" },
					loaded = { "Slug", "None" },
					selected = 1,
					ammo = "Slug",
					reserve = { Slug = 24, Buck = 22 },
					open = false,
					busyFor = 0,
				}
				local shaped = Hud.readoutFor(mine :: any)
				TestKit.note("weapon_client: readout of my own state: " .. shaped)
				expect(string.match(shaped, SHAPE)).to.be.ok()
				expect(string.match(shaped, "^%[%*%]x SLUG 24")).to.be.ok()
				-- ...AND THE LIVE ONE IS EMPTY EXACTLY WHEN THERE IS NO GUN, which is the other half
				-- of "no gun, no readout" (TASKS.md 35b(a)) and the half the tie actually exercises.
				local state = Weapon.get()
				local hasGun = state ~= nil and state.equipped == true
				if hasGun then
					expect(string.match(text, SHAPE)).to.be.ok()
				else
					expect(text).to.equal("")
				end
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

			it("is listening to no Tool at all, and holds nothing for one that died", function()
				-- TASKS.md 24a(c): the watcher table used to keep a key and two connections per Tool for
				-- ever, and the drive destroys a Tool on every placement respawn. A driver is never given
				-- one, so his count is zero for the whole session.
				expect(Weapon.Input.watchedTools()).to.equal(0)
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
			if Role.isDriver() then
				-- The sharper version of the same claim: a driver has no state at all, and firing
				-- every request a client can fire must not conjure him one.
				expect(Weapon.get()).to.equal(nil)
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

			-- THE ASSERTIONS ARE THE STRICT ONES, AND THE WINDOW IS WHAT WAS MADE ROBUST (Task 36,
			-- round 1 finding 1). The first attempt at this replaced "nothing changed" with a
			-- conservation law -- reserves never grow, no barrel loads unpaid -- and that was WRONG
			-- in the one case the test exists for: Validator.checkRequest is the whitelist that
			-- makes the reducer's primitives unreachable, so without it a forged "Break" runs the
			-- whole Break -> Load -> Load -> Close cycle, and a second later the reserves and the
			-- barrels are back where they started. The exploit would have passed.
			--
			-- What was actually flaky was the WINDOW: the replay is one stream of input for the
			-- session, it got twice as long when Task 36 started sending it to both clients, and a
			-- legitimate reload landed inside. A legitimate reload and an accepted "Break" are
			-- indistinguishable from the state, so the window is opened only on a quiet gun with no
			-- weapon input for QUIET seconds, and is DISCARDED AND RETRIED if any arrives while it
			-- is open. A real exploit reproduces on every attempt; a replayed keypress does not.
			-- QUIET COMES FROM THE GUN'S OWN NUMBERS, NOT FROM A GUESS, and Task 79's final gate
			-- measured why it has to. It was a flat 1.5 s, and a two-player run failed here with
			-- `after.open == true`: the window's own note read `last weapon input 1.51 s before it
			-- opened` and then, at +0.47 s inside it, one state change -- `Spent/Spent -> Empty/Empty,
			-- open=true, busyFor=0.50`. That is the BREAK step of a reload (`RELOAD_BREAK` is 0.50),
			-- and it landed **1.98 s** after the last input the spec could see, against
			-- `RELOAD_TOTAL = 2.0`. An input just outside a 1.5 s quiet period is still producing state
			-- changes for half a second after the window opens, and `stillBusy()` cannot see it: that
			-- reads the newest snapshot's `busyFor`, and at window-open time the gun really was idle.
			--
			-- So the quiet period is the SERVER'S OWN reload window plus a second for the round trip,
			-- read from the config the server runs on -- one source, and it moves if Karen changes the
			-- feel. It was never a forged request: at that same head, in that same session, the server
			-- case reported `action Break=bad-request` and `badRequests +12, rateDropped +0, shots +0`.
			-- This is still a TIME-based guard and 80a(a) stays open; what it guards is a smoke test
			-- whose worst failure is a retry, because the property itself is proved on the server.
			local QUIET = Shotgun.CONFIG.RELOAD_TOTAL + 1
			local WINDOW = 1
			local attempts, opened = 3, false

			-- "NO ACTION IS STILL RUNNING", which neither obvious spelling says. `state.busyFor` is a
			-- number the SERVER computed when it published, and the replica never ticks it down -- a
			-- session's last snapshot reads busyFor = 0.25 for ever. The elapsed time since that
			-- snapshot arrived is the real test, and this spec already records it per snapshot.
			local function stillBusy(): boolean
				local newest = log[#log]
				return newest ~= nil and os.clock() - newest.at < newest.state.busyFor
			end

			-- THE PROPERTY ITSELF NOW LIVES ON THE SERVER (Task 80), in `weapon_shot.spec`'s "consults
			-- the whitelist before acting, at the handler the remote calls", which counts
			-- `stats.badRequests` and needs no window at all. What is left here is the half only a
			-- client can prove: that these remotes REACH that handler, from a real Play client, and
			-- that nothing comes back. Keeping both is deliberate -- the server case would still pass
			-- if `Weapon.start` forgot to connect the remote.
			for _ = 1, attempts do
				-- THE WINDOW MUST OPEN ON A GUN THESE REQUESTS COULD ACTUALLY MOVE (round 2, finding
				-- 1). src/server/Weapon/init.luau's onActionRequest returns at
				-- `if not state.equipped or state.open or now < state.busyUntil then ... end` --
				-- BEFORE Validator.checkRequest is consulted -- so on an unequipped, broken-open or
				-- busy gun every forged primitive is refused by that guard and this test would be
				-- green with the whitelist deleted. Requiring equipped-and-closed-and-idle is what
				-- makes the whitelist the only thing standing between "Break" and a reload cycle.
				--
				-- (Round 1's version dropped `not open` after a failing run, on the reading that the
				-- replay leaves the gun broken open. That was wrong: the failing run's own print said
				-- `open=false busyFor=0.25`, so what never came true was the stale busyFor above.)
				local ready = waitUntil(45, function()
					local state = Weapon.get()
					return state ~= nil
						and state.equipped
						and not state.open
						and not stillBusy()
						and os.clock() - lastWeaponInput > QUIET
				end)
				if not ready then
					local state = Weapon.get()
					TestKit.note(
						string.format(
							"weapon_client: no quiet gun to test: equipped=%s open=%s busyFor=%.2f since input=%.1f s",
							tostring(state and state.equipped),
							tostring(state and state.open),
							if state then state.busyFor else -1,
							os.clock() - lastWeaponInput
						)
					)
					-- ...AND A TIED PLAYER HAS NO GUN BY THE GAME'S OWN RULE, which is not this
					-- case's failure. The safety rule takes the Tool away and `TIE_UNTIL_DRIVE_END`
					-- keeps it until the drive ends, so a shooter tied earlier in the run reaches
					-- here disarmed -- measured, on the two-player run of task 97, 41.9 s after his
					-- last input. The forged-remote claim needs an equipped gun to mean anything, so
					-- for a tied player the claim asserted instead is the tie's own: no gun.
					-- Not a skip -- `Match.isTied()` is the server's replicated answer, and "tied but
					-- still armed" is the bug it would catch.
					local matchModule = scripts:FindFirstChild("Match")
					local Match = if matchModule then require(matchModule) else nil
					if Match ~= nil and Match.isTied() then
						TestKit.note("weapon_client: this shooter is tied to a tree, so he has no gun to forge against")
						local tiedSnapshot = Weapon.get()
						expect(tiedSnapshot == nil or tiedSnapshot.equipped ~= true).to.equal(true)
						return
					end
				end
				expect(ready).to.equal(true)

				local before = Weapon.get()
				expect(before).to.be.ok()
				-- TASK 80, THE MEASUREMENT. This case has failed intermittently at
				-- `after.open` and `after.barrels[1]`, which is either the whitelist letting a forged
				-- request through -- a security defect -- or something legitimate moving the gun
				-- inside a window this spec believed was quiet. The two look identical from the state,
				-- so the window prints its own timeline, every run, pass or fail: every snapshot that
				-- arrived, when, and what changed in it. A green run says the window really was empty;
				-- a red one says what moved it.
				local firstIndex = #log
				local inputAtOpen = os.clock() - lastWeaponInput
				local openedAt = os.clock()
				-- ...AND THE OWNER MUST NOT HAND OVER A GUN INSIDE THE WINDOW (Task 80). `Weapon.grant`
				-- resets the state to `StateMachine.initial` and auto-equips, so a grant inside the
				-- window changes `open`, `barrels` and the whole reserve with no input at all -- which
				-- is indistinguishable from an accepted `Break` and is what the failing two-player runs
				-- looked like (that session's own note read `weapon granted=9 revoked=4`). Counting the
				-- guns is causal: it does not care how long anything took.
				local gunsAtOpen = #guns
				local remotes = Shotgun.remotes()
				-- The reducer's own primitives, which Validator.checkRequest does not accept at all.
				for _, bad in ipairs({ "Break", "Load", "Close", "Fire", "", 42 }) do
					remotes.ActionRequest:FireServer(bad)
				end
				remotes.ActionRequest:FireServer({})
				remotes.ActionRequest:FireServer("SelectAmmo", "Grenade")
				remotes.FireRequest:FireServer("not a table")
				remotes.FireRequest:FireServer({ origin = "x", direction = Vector3.zero })
				task.wait(WINDOW)

				if os.clock() - lastWeaponInput > QUIET + WINDOW and #guns == gunsAtOpen then
					-- Nothing of the player's own arrived between the quiet check and now, and the gun
					-- was equipped, closed and idle when the requests went out -- so the server's own
					-- state guard refused none of them, and anything that moved was the whitelist
					-- failing to.
					local after = Weapon.get()
					local timeline = {}
					for index = firstIndex + 1, #log do
						local entry = log[index]
						table.insert(
							timeline,
							string.format(
								"+%.2fs eq=%s open=%s b=%s/%s ld=%s/%s ammo=%s res=%d/%d busyFor=%.2f",
								entry.at - openedAt,
								tostring(entry.state.equipped),
								tostring(entry.state.open),
								tostring(entry.state.barrels[1]),
								tostring(entry.state.barrels[2]),
								tostring(entry.state.loaded[1]),
								tostring(entry.state.loaded[2]),
								tostring(entry.state.ammo),
								entry.state.reserve.Slug or -1,
								entry.state.reserve.Buck or -1,
								entry.state.busyFor
							)
						)
					end
					TestKit.note(
						string.format(
							"weapon_client: exploit window: %d snapshot(s) in %.2f s; last weapon input "
								.. "%.2f s before it opened, %.2f s before it closed; before open=%s "
								.. "b=%s/%s res=%d/%d -> after open=%s b=%s/%s res=%d/%d%s",
							#log - firstIndex,
							os.clock() - openedAt,
							inputAtOpen,
							os.clock() - lastWeaponInput,
							tostring(before.open),
							tostring(before.barrels[1]),
							tostring(before.barrels[2]),
							before.reserve.Slug or -1,
							before.reserve.Buck or -1,
							tostring(after.open),
							tostring(after.barrels[1]),
							tostring(after.barrels[2]),
							after.reserve.Slug or -1,
							after.reserve.Buck or -1,
							if #timeline > 0 then " | " .. table.concat(timeline, " | ") else ""
						)
					)
					expect(after.open).to.equal(before.open)
					expect(after.reserve.Slug).to.equal(before.reserve.Slug)
					expect(after.reserve.Buck).to.equal(before.reserve.Buck)
					expect(after.ammo).to.equal(before.ammo)
					expect(after.barrels[1]).to.equal(before.barrels[1])
					expect(after.barrels[2]).to.equal(before.barrels[2])
					expect(after.loaded[1]).to.equal(before.loaded[1])
					expect(after.loaded[2]).to.equal(before.loaded[2])
					-- An accepted "Break" would be mid-cycle here, so the gun would have published a
					-- snapshot with an unfinished action in it.
					expect(stillBusy()).to.equal(false)
					expect(after.busyUntil).to.equal(nil) -- still a snapshot, not the server's state
					opened = true
					break
				end
			end
			-- Not "give up quietly": if the replay never stops touching this gun, or the owner keeps
			-- handing over new ones, this spec asserted nothing and must say so.
			if not opened then
				TestKit.note(
					string.format(
						"weapon_client: the exploit window never closed quietly: %d gun(s) handed over, "
							.. "last weapon input %.2f s ago",
						#guns,
						os.clock() - lastWeaponInput
					)
				)
			end
			expect(opened).to.equal(true)
		end)
	end)

	describe("cleanup", function()
		it("unbinds the cue key", function()
			ContextActionService:UnbindAction(CUE_ACTION)
			ContextActionService:UnbindAction(QUIET_ACTION)
			expect(ContextActionService:GetAllBoundActionInfo()[CUE_ACTION]).to.equal(nil)
			expect(ContextActionService:GetAllBoundActionInfo()[QUIET_ACTION]).to.equal(nil)
		end)
	end)
end
