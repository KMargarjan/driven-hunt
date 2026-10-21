-- rifle_client.spec: the SCOPE on the real screen, and the two Tools in the real Backpack. The
-- maths is proved on the server (tests/server/rifle.spec.luau); this proves the things only a
-- running client can show -- that the engine really narrows the field of view to 19.87 degrees, that
-- the reticle is genuinely visible rather than merely existing, and that the drawn gun follows the
-- Tool the player is holding.
--
-- IT REACHES THE OWNER THROUGH PlayerScripts, never through StarterPlayerScripts, which is a
-- template (docs/design/shotgun.md section 3.2).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/rifle.md (section 13.2)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Hud = require(scripts:WaitForChild("Hud"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
-- ...and for ONE table: the poses file as DATA, so the kick below is checked against the rifle's
-- own `fire` block rather than against whatever `Camera.Config` was built from (task 183).
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))
-- ...for ONE name: the shell template, which is never worn (see the case below).
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local LeverGeometry = require(ReplicatedStorage:WaitForChild("Lever"):WaitForChild("Geometry"))
local RifleGeometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Mode = Camera.Mode
local Config = Camera.Config

-- A state at a given blend, fabricated: the same shape `camera_mode.spec`'s own helper has, and the
-- reason is the same -- the live state's blend is whatever the session is doing.
local function stateAtBlend(blend: number): any
	local made = table.clone(Mode.initial(Config)) :: any
	made.mode = if blend > 0 then "Aiming" else "Third"
	made.blend = blend
	return table.freeze(made)
end

-- THE FIRST-PERSON BRANCH BY PARAMETER, exactly as `camera_client.spec` drives it: nothing is
-- flipped and nothing has to be restored.
local firstPerson = table.clone(Config) :: any
firstPerson.FIRST_PERSON = true
table.freeze(firstPerson)

-- AT REST, FABRICATED, not `Camera.getState()` (the Reviewer's note, round 2): the live state's
-- blend is whatever the session is doing, and `amp = Mode.ease(blend) * ampDeg`, so "the sway is zero
-- in the hip view" held only because the blend happened to be 0. This is the shape
-- `camera_mode.spec`'s own `stateAtBlend` has.
local function atRest(): any
	local state = table.clone(Mode.initial(firstPerson)) :: any
	state.mode = "Third"
	state.blend = 0
	state.scopePhase = 0
	state.scopeSwayDeg = Vector2.zero
	return table.freeze(state)
end

local function frames(n: number)
	for _ = 1, n do
		RunService.Heartbeat:Wait()
	end
end

-- Is this GuiObject visible all the way up to the ScreenGui? A visibility audit that ignored parent
-- visibility certified a blank screen twice (docs/PROJECT_CONTEXT.md), so this walks the ancestors.
local function visibleUp(instance: Instance?): boolean
	local node = instance
	while node ~= nil and node:IsA("GuiObject") do
		if not (node :: GuiObject).Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and node:IsA("ScreenGui") and (node :: ScreenGui).Enabled
end

return function()
	describe("the scope's field of view, on the real camera", function()
		it("is the number the weapon asked for, and the engine does not clamp it", function()
			-- THE CASE THE RESEARCH NOTE ASKED FOR. Roblox's own `Camera` page states no range for
			-- `FieldOfView`, so "19.87 is reachable" is a measurement rather than documentation --
			-- and `Rig.apply`'s foreign-write detector compares what it read back to 1e-3, so a
			-- clamp would count the ENGINE as a second writer every frame.
			-- ON A CAMERA OF THIS SPEC'S OWN, and that is not a dodge: `Camera.Rig` is the one
			-- writer of `workspace.CurrentCamera` and rewrites its FieldOfView every frame, so a
			-- value written there by anything else is gone before it can be read back -- which is
			-- the owner rule working, not a result. What is being measured is the ENGINE: whether
			-- it keeps 19.87 and 13.31, or clamps them.
			local scope = Rifle.CONFIG.scope
			local probe = Instance.new("Camera")
			probe.FieldOfView = scope.aimFovDeg
			expect(math.abs(probe.FieldOfView - scope.aimFovDeg) < 1e-3).to.equal(true)
			-- ...and 6x as well, before anybody ships it.
			probe.FieldOfView = 13.31
			expect(math.abs(probe.FieldOfView - 13.31) < 1e-3).to.equal(true)
			local held = probe.FieldOfView
			probe:Destroy()
			TestKit.note(string.format("rifle: the engine held FOV %.2f and %.2f to 1e-3", scope.aimFovDeg, held))
		end)

		it("blends to the aimed weapon's own fov, and the mouse slows with it", function()
			-- PURE, through the owner's own functions: `fovFor(1, config, nil)` is the shotgun's 50
			-- and every caller written before the rifle; with the scope's number it is the scope's.
			expect(math.abs(Mode.fovFor(1, Config, nil) - Config.FOV_AIM_DEG) < 1e-9).to.equal(true)
			local aimed = Rifle.CONFIG.scope.aimFovDeg
			expect(math.abs(Mode.fovFor(1, Config, aimed) - aimed) < 1e-9).to.equal(true)
			expect(math.abs(Mode.fovFor(0, Config, aimed) - Config.FOV_THIRD_DEG) < 1e-9).to.equal(true)
			-- A QUARTER OF THE HIP RATE AT 4x, with no new code: the sensitivity is derived from the
			-- blended fov and always has been.
			local scale = Mode.sensitivityScale(aimed, Config)
			expect(math.abs(scale - 1 / Rifle.CONFIG.scope.magnification) < 1e-2).to.equal(true)
		end)
	end)

	describe("the sway moves the VIEW, and only while scoped", function()
		it("is exactly zero in the hip view and non-zero at full blend", function()
			local sway = Rifle.CONFIG.scope.sway
			local state = atRest()
			-- At blend 0 the sway is scaled to nothing: you cannot see a wobble at 1x, and no
			-- hip-fire scenario can ever be touched by it.
			local hip = Mode.step(state, {
				aiming = false,
				alive = true,
				hasCharacter = true,
				lookDelta = Vector2.zero,
				sway = sway,
				aimFovDeg = Rifle.CONFIG.scope.aimFovDeg,
			}, 1 / 60, firstPerson)
			expect(hip.scopeSwayDeg.X).to.equal(0)
			expect(hip.scopeSwayDeg.Y).to.equal(0)

			-- ...and at full blend it wanders, inside its own amplitude, without ever moving the
			-- player's own aim.
			local aimed = hip
			-- THE PLAYER'S OWN AIM, as the fabricated state left it: read off `hip` rather than
			-- assumed to be zero, so this asserts "the sway does not move the player's aim" against
			-- whatever the mode's own step did with the pitch.
			local pitch0, yaw0 = hip.pitchDeg, hip.yawDeg
			local worst = 0
			for _ = 1, 600 do
				aimed = Mode.step(aimed, {
					aiming = true,
					alive = true,
					hasCharacter = true,
					lookDelta = Vector2.zero,
					sway = sway,
					aimFovDeg = Rifle.CONFIG.scope.aimFovDeg,
				}, 1 / 60, firstPerson)
				worst = math.max(worst, math.abs(aimed.scopeSwayDeg.X), math.abs(aimed.scopeSwayDeg.Y))
				expect(aimed.pitchDeg).to.equal(pitch0)
				expect(aimed.yawDeg).to.equal(yaw0)
			end
			expect(worst > 0).to.equal(true)
			expect(worst <= sway.ampDeg + 1e-9).to.equal(true)
			TestKit.note(string.format("rifle: sway reached %.3f deg of %.3f over 10 s", worst, sway.ampDeg))
		end)

		it("does not advance its clock for a weapon with no scope", function()
			local state = atRest()
			for _ = 1, 30 do
				state = Mode.step(state, {
					aiming = true,
					alive = true,
					hasCharacter = true,
					lookDelta = Vector2.zero,
				}, 1 / 60, firstPerson)
			end
			expect(state.scopePhase).to.equal(0)
			expect(state.scopeSwayDeg).to.equal(Vector2.zero)
		end)
	end)

	describe("the reticle", function()
		it("exists, is hidden in the hip view, and converts degrees to pixels once", function()
			local reticle = Hud.reticle()
			expect(reticle).to.be.ok()
			-- NOT VISIBLE UNTIL SCOPED, and `Hud.reticleVisible` is the pure rule that says so.
			expect(Hud.reticleVisible(nil, nil)).to.equal(false)
			expect(Hud.reticleVisible("Third", { reticle = Rifle.CONFIG.scope.reticle })).to.equal(false)
			expect(Hud.reticleVisible("Aiming", nil)).to.equal(false)
			-- ...and the shotgun never shows one, because its optics are nil at the source.
			expect(Hud.reticleVisible("Aiming", { aimFovDeg = 50 })).to.equal(false)
			expect(Hud.reticleVisible("Aiming", { reticle = Rifle.CONFIG.scope.reticle })).to.equal(true)

			-- THE ONE CONVERSION: a quarter of the field of view is a quarter of the viewport's
			-- height, because Roblox's fov is the VERTICAL angle.
			expect(Hud.reticleDegToPx(10, 20, 1080)).to.equal(540)
			expect(Hud.reticleDegToPx(1, 0, 1080)).to.equal(0)
			-- AND IT GROWS WITH THE MAGNIFICATION: the same angle is twice as many pixels at half
			-- the fov, which is what keeps a duplex true at any zoom.
			local wide = Hud.reticleDegToPx(1, 19.87, 1080)
			local tight = Hud.reticleDegToPx(1, 13.31, 1080)
			expect(tight > wide).to.equal(true)
		end)

		it("lays out as a cross that spans the glass, with no ring and no posts", function()
			local reticle = Hud.reticle() :: Frame
			local scope = Rifle.CONFIG.scope
			local viewportY = Workspace.CurrentCamera.ViewportSize.Y
			Hud.layoutReticle(reticle, scope, scope.aimFovDeg)
			frames(1)
			-- KAREN'S FRAME, ELEMENT BY ELEMENT (task 146). The ring round the centre and the duplex
			-- posts are not in her picture, so they are not in the data, so they are not drawn.
			local ring = reticle:FindFirstChild("Ring") :: Frame
			expect(ring).to.be.ok()
			expect(ring.Visible).to.equal(false)
			local post = reticle:FindFirstChild("PostTop") :: Frame
			expect(post).to.be.ok()
			expect(post.Visible).to.equal(false)
			-- ...AND THE HAIR RUNS FROM THE CENTRE TO THE INSIDE OF THE TUBE. The arm is the lens's
			-- own radius less the body's thickness, so the cross cannot disagree with the glass.
			local cross = reticle:FindFirstChild("CrossTop") :: Frame
			expect(cross).to.be.ok()
			expect(cross.Visible).to.equal(true)
			local arm = scope.eyepiece.diameterDeg / 2 - scope.eyepiece.rimThickDeg
			local wanted = Hud.reticleDegToPx(arm, scope.aimFovDeg, viewportY)
			-- MEASURED AGAINST THE LIVE VIEWPORT, not against 1080: a Studio Play window is nowhere
			-- near it, and a fixed pixel count there would be a looser claim.
			expect(math.abs(cross.AbsoluteSize.Y - wanted) <= 2).to.equal(true)
			-- ...AND THE DRAWN GLASS IS KAREN'S 0.889 OF THE VIEWPORT (the Reviewer's finding 1).
			-- This is the assertion that would have caught round 1: it reads the RIM frame, which is
			-- the clear lens itself, off the live screen rather than trusting a config number.
			Hud.layoutScope(Hud.scopeOverlay() :: Frame, scope, scope.aimFovDeg)
			frames(1)
			local lens = (Hud.scopeOverlay() :: Frame):FindFirstChild("Rim") :: Frame
			expect(lens).to.be.ok()
			local share = lens.AbsoluteSize.Y / viewportY
			TestKit.note(string.format("rifle: clear glass %.3f of the viewport (Karen's frame: 0.889)", share))
			expect(math.abs(share - 0.889) < 0.03).to.equal(true)
			-- ...and it starts AT the centre: no gap, which is the whole difference from a duplex.
			expect(math.abs(math.abs(cross.Position.Y.Offset) - wanted / 2) <= 2).to.equal(true)
			-- ...and it is a hair across, not a bar.
			expect(cross.AbsoluteSize.X <= 6).to.equal(true)
			TestKit.note(
				string.format(
					"rifle: cross arm %d px of %d viewport (asked %.1f px), %d px thick",
					cross.AbsoluteSize.Y,
					viewportY,
					wanted,
					cross.AbsoluteSize.X
				)
			)
		end)

		it("is visible up its ancestors once the Hud shows it", function()
			local reticle = Hud.reticle() :: Frame
			local was = reticle.Visible
			reticle.Visible = true
			-- NO FRAME IS WAITED FOR, and that is the task-141 change rather than a weakening: the
			-- Hud is the ONE writer of this frame's `Visible` and since task 141 it writes it every
			-- frame (`Hud.renderScope`), so a spec that set the flag and then yielded would be
			-- measuring the Hud's own answer for a player who is not aiming. What this case is about
			-- is the ANCESTOR CHAIN -- that showing the reticle really shows it, rather than putting
			-- it inside something hidden -- and that is a property of the tree, not of a rendered
			-- frame. (Measured: with the yield this case failed, because the next frame's render
			-- correctly set it back to false.)
			expect(visibleUp(reticle)).to.equal(true)
			reticle.Visible = was
		end)
	end)

	describe("no crosshair, ever", function()
		it("stays hidden in first person with either weapon in hand", function()
			-- Karen's standing rule since 2026-09-27, and the reticle does not change it: two
			-- predicates, two questions.
			local state = { equipped = true, open = false }
			expect(Hud.crosshairVisible(state, false, true)).to.equal(false)
			expect(Hud.crosshairVisible(state, true, true)).to.equal(false)
			expect(Hud.isCrosshairVisible()).to.equal(false)
		end)
	end)

	describe("the sight picture", function()
		-- THE THREE PREDICATES, PURE. The crosshair's, the reticle's and now the mask's: three marks,
		-- three questions, and the mask's answer blacks out the screen, so it may never be the same
		-- predicate as "does this gun have a reticle" (task 141).
		it("is in only while the eye is at the glass, and the duplex waits for it", function()
			local scope = Rifle.CONFIG.scope
			local eyepiece = scope.eyepiece
			local optics = { aimFovDeg = scope.aimFovDeg, reticle = scope.reticle, eyepiece = eyepiece }
			expect(eyepiece.atBlend > 0).to.equal(true)
			-- not aiming, no optics, and a weapon with no eyepiece at all: three ways to be out.
			expect(Hud.scopeVisible("Third", optics, 1)).to.equal(false)
			expect(Hud.scopeVisible("Aiming", nil, 1)).to.equal(false)
			expect(Hud.scopeVisible("Aiming", { aimFovDeg = 50 }, 1)).to.equal(false)
			-- ...and the raise itself: the gun is still coming up, so the mask is not in yet.
			expect(Hud.scopeVisible("Aiming", optics, 0)).to.equal(false)
			expect(Hud.scopeVisible("Aiming", optics, eyepiece.atBlend - 0.01)).to.equal(false)
			expect(Hud.scopeVisible("Aiming", optics, eyepiece.atBlend)).to.equal(true)
			expect(Hud.scopeVisible("Aiming", optics, 1)).to.equal(true)
			-- THE DUPLEX WAITS FOR THE MASK, which is the defect the Director's frames showed: a
			-- reticle drawn over the gun half way up the swing is a mark floating in the world.
			expect(Hud.reticleVisible("Aiming", optics, 0)).to.equal(false)
			expect(Hud.reticleVisible("Aiming", optics, 1)).to.equal(true)
			-- ...and a scope with no eyepiece block has nothing to wait for, which is what every
			-- caller without a blend means.
			expect(Hud.reticleVisible("Aiming", { reticle = scope.reticle })).to.equal(true)
			expect(Hud.reticleVisible("Aiming", optics)).to.equal(true)
		end)

		it("is a circle of the scope's own degrees, and black to the corners", function()
			local overlay = Hud.scopeOverlay()
			expect(overlay).to.be.ok()
			local scope = Rifle.CONFIG.scope
			local optics = { aimFovDeg = scope.aimFovDeg, reticle = scope.reticle, eyepiece = scope.eyepiece }
			Hud.layoutScope(overlay :: Frame, optics, scope.aimFovDeg)
			local viewport = Workspace.CurrentCamera.ViewportSize
			local mask = (overlay :: Frame):FindFirstChild("Mask") :: Frame
			expect(mask).to.be.ok()
			-- THE CLAMP IS ON THE GLASS, NOT ON THE WHOLE CIRCLE (task 146): the tube may run off the
			-- top and bottom -- it does in Karen's own reference -- and what may not leave the screen
			-- is the lens, because the reticle's degrees are measured against it.
			local rimPx = math.max(1, Hud.reticleDegToPx(scope.eyepiece.rimThickDeg, scope.aimFovDeg, viewport.Y))
			local wanted = math.min(
				Hud.reticleDegToPx(scope.eyepiece.diameterDeg, scope.aimFovDeg, viewport.Y),
				math.min(viewport.X, viewport.Y) + 2 * rimPx
			)
			expect(math.abs(mask.AbsoluteSize.X - wanted) <= 2).to.equal(true)
			-- ...and the glass inside it never does leave the screen.
			expect(mask.AbsoluteSize.Y - 2 * rimPx <= math.min(viewport.X, viewport.Y) + 2).to.equal(true)
			expect(math.abs(mask.AbsoluteSize.Y - mask.AbsoluteSize.X) <= 1).to.equal(true)
			-- THE MASK REACHES EVERY CORNER. A stroke is drawn outward from the circle, so anything
			-- short of the screen's own diagonal leaves a lit wedge at the corners.
			local edge = mask:FindFirstChild("Edge") :: UIStroke
			expect(edge).to.be.ok()
			local diagonal = math.sqrt(viewport.X * viewport.X + viewport.Y * viewport.Y)
			expect(edge.Thickness >= diagonal).to.equal(true)
			-- ...AND THE DUPLEX IS OVER IT, not behind it: a reticle is etched on the glass.
			local reticle = Hud.reticle()
			expect(reticle).to.be.ok()
			expect((reticle :: Frame).ZIndex > (overlay :: Frame).ZIndex).to.equal(true)
			TestKit.note(
				string.format(
					"rifle: eyepiece %d px of %d viewport (asked %.1f), mask stroke %d of %d diagonal",
					mask.AbsoluteSize.X,
					viewport.Y,
					wanted,
					edge.Thickness,
					math.ceil(diagonal)
				)
			)
		end)

		it("has no gun in it, and the gun comes back when the eye leaves", function()
			-- THROUGH A SCOPE YOU SEE NO RIFLE: the eye is AT the ocular lens, so the gun is behind
			-- it. The viewmodel owns this, because it is the one writer of the drawn gun, and it
			-- reads the SAME `atBlend` the mask does -- so there is never a frame with a mask and a
			-- gun, or a gun and no mask.
			local scope = Rifle.CONFIG.scope
			local optics = { aimFovDeg = scope.aimFovDeg, eyepiece = scope.eyepiece }
			local aimed = stateAtBlend(1)
			local half = stateAtBlend(scope.eyepiece.atBlend - 0.01)
			expect(Camera.Viewmodel.hiddenByScope(aimed, optics)).to.equal(true)
			expect(Camera.Viewmodel.hiddenByScope(half, optics)).to.equal(false)
			expect(Camera.Viewmodel.hiddenByScope(stateAtBlend(0), optics)).to.equal(false)
			-- ...and a weapon with no scope is never hidden, whatever the blend.
			expect(Camera.Viewmodel.hiddenByScope(aimed, nil)).to.equal(false)
			expect(Camera.Viewmodel.hiddenByScope(aimed, { aimFovDeg = 50 })).to.equal(false)
		end)
	end)

	describe("the published model reaches the drawn gun", function()
		it("wears a mesh for every piece this client has actually downloaded", function()
			-- THE DIRECTOR'S FIRST BUG, AS A RULE (task 141): switch to the rifle and the viewmodel
			-- read `mesh=2 box=7` at +0/+4/+8/+12 s and never changed -- the two meshes were the
			-- gloves and the whole rifle was its fallback boxes, for the rest of the session. The
			-- cause was one weapon's folder name hardcoded in the staleness check, so for any OTHER
			-- weapon both halves of the signal were constants and nothing could ever mark the gun
			-- stale again.
			--
			-- The rule is weapon-agnostic on purpose: whatever is in the player's hands, a piece
			-- whose template this client can draw must be drawn as that template and not as a box.
			local id = Camera.Viewmodel.weaponId()
			if id == nil then
				TestKit.note("rifle: no weapon in hand, so nothing to compare")
				return
			end
			local geometry = Weapons.geometry(id)
			expect(geometry).to.be.ok()
			local folder = ReplicatedStorage:FindFirstChild((geometry :: any).FOLDER_NAME)
			if folder == nil then
				TestKit.note("rifle: " .. tostring((geometry :: any).FOLDER_NAME) .. " is not published in this place")
				return
			end
			-- IT IS A RACE, AND THE TWO-PLAYER RUN IS WHAT SHOWED IT (task 150). With one client this
			-- read `3 of 3`; with two it read `2 of 3` and failed, because a single `frames(60)` is
			-- not a wait for anything in particular -- a template that finished downloading between
			-- the two loops below counted as READY and could not yet be WORN, and the viewmodel only
			-- re-dresses on its own quarter-second staleness tick. So this waits for the thing the
			-- rule is about -- every downloaded piece drawn as itself -- and only then asserts, which
			-- is the same claim with a deadline instead of a guess.
			-- THE VIEWMODEL IS NIL WHILE IT RE-DRESSES, which the two-player run showed as well: a
			-- reading taken on one of those frames has no model to compare against and says nothing,
			-- so only a reading WITH a model is kept.
			local ready, drawn, missing = 0, 0, {}
			local model = nil
			local sawModel = false
			local deadline = os.clock() + 8
			repeat
				frames(15)
				local current = Camera.Viewmodel.current()
				if current ~= nil then
					model = current
					sawModel = true
					local worn: { [string]: boolean } = {}
					for _, part in ipairs((current :: Model):GetDescendants()) do
						if part:IsA("MeshPart") then
							worn[part.Name] = true
						end
					end
					ready, drawn, missing = 0, 0, {}
					for _, template in ipairs(folder:GetChildren()) do
						-- THE SHELL IS NOT A PIECE OF THE GUN (task 150). It is a TEMPLATE the
						-- viewmodel clones per barrel during a break-action reload, under its own
						-- name -- `SpentShell1`, `FreshShell2` -- and `Viewmodel.clearShells` takes
						-- them away again, so a gun at rest wears no part called `Shell` and never
						-- should. This case read `shotgun wears 2 of 3 downloaded piece(s) missing
						-- Shell` in a two-player run and passed in a one-player one for a reason
						-- that is not about the rule: with one client the shell's mesh had not
						-- finished downloading yet, so it was not counted as ready either.
						if template.Name ~= Gun.SHELL_TEMPLATE_NAME and Camera.Viewmodel.meshReady(template) then
							ready += 1
							if worn[template.Name] then
								drawn += 1
							else
								table.insert(missing, template.Name)
							end
						end
					end
				end
			until (sawModel and ready > 0 and drawn == ready) or os.clock() >= deadline

			-- ...AND A TIED PLAYER HAS NO VIEWMODEL AT ALL, which is the game's own rule and not
			-- this case's failure (task 166). The safety penalty takes the Tool away and
			-- `TIE_UNTIL_DRIVE_END` keeps it until the drive ends, so a shooter tied earlier in the
			-- run reaches here with nothing drawn -- `Expected nil to be non-nil`, which is what one
			-- of the two `test2` runs of task 166 read here. The guard is `weapon_client`'s, with
			-- its reasoning: NOT a skip, because `Match.isTied()` is the server's replicated answer
			-- and the claim asserted instead is the tie's own -- no gun, so no drawn gun.
			if not sawModel then
				local matchModule = scripts:FindFirstChild("Match")
				local Match = if matchModule then require(matchModule) else nil
				if Match ~= nil and Match.isTied() then
					TestKit.note("rifle: this shooter is tied to a tree, so there is no gun to draw")
					expect(Camera.Viewmodel.current()).to.equal(nil)
					return
				end
			end
			expect(model).to.be.ok()
			TestKit.note(
				string.format(
					"rifle: %s wears %d of %d downloaded piece(s)%s",
					id,
					drawn,
					ready,
					if #missing > 0 then " missing " .. table.concat(missing, ",") else ""
				)
			)
			expect(drawn).to.equal(ready)
		end)
	end)

	describe("the bolt, the magazine and the voice", function()
		-- THE DEFECT THIS CASE EXISTS FOR (task 142, the Reviewer's round-1 finding): the hand's
		-- weight was a function of the bolt's POSITION, and `Mode.cycleProgress` runs 0 -> 1 -> 0
		-- over one cycle -- so a "return" ramp near progress 1 let go of the knob at FULL TRAVEL and
		-- grabbed it again on the way forward, twice per shot.
		it("keeps the right hand on the knob for the whole of the bolt's travel", function()
			local config = table.clone(firstPerson) :: any
			config.BOLT_HAND = { reachShare = 0.25, grip = CFrame.new(0.14, 0.07, 0.2) }
			table.freeze(config)
			local weight = Camera.Viewmodel.boltHandWeight
			-- the reach, as the bolt starts to move
			expect(weight(0, config)).to.equal(0)
			expect(math.abs(weight(0.125, config) - 0.5) < 1e-6).to.equal(true)
			-- ...and ON for everything past it, INCLUDING full travel, which is where it used to
			-- let go.
			for _, at in ipairs({ 0.25, 0.5, 0.75, 0.9, 1.0 }) do
				expect(weight(at, config)).to.equal(1)
			end
			-- The release is the same ramp, run backwards: the bolt coming home takes the hand off.
			expect(weight(0.1, config) < 1).to.equal(true)
			-- ...and a weapon with no bolt never moves that hand at all.
			expect(weight(0.5, firstPerson)).to.equal(0)
		end)

		it("drops the magazine and takes the hand with it, on one progress", function()
			local config = table.clone(firstPerson) :: any
			config.MAGAZINE_SWAP = {
				outShare = 0.38,
				inShare = 0.4,
				dropStuds = 0.42,
				seconds = 1.35,
				hand = CFrame.new(0, -0.3, 0.33),
			}
			table.freeze(config)
			local at = Camera.Viewmodel.magazineAtProgress
			-- no swap running: the box is home and no hand is on it
			local away, onBox = at(nil, config)
			expect(away).to.equal(0)
			expect(onBox).to.equal(0)
			-- out, hold, and back in -- and the hand's weight tracks the box the whole way
			local half = select(1, at(0.19, config))
			expect(half > 0 and half < 0.42).to.equal(true)
			expect(math.abs(select(1, at(0.6, config)) - 0.42) < 1e-6).to.equal(true)
			expect(select(2, at(0.6, config))).to.equal(1)
			expect(select(1, at(0.9, config)) < 0.42).to.equal(true)
			-- ...and a weapon with no magazine never draws one.
			expect(select(1, at(0.5, firstPerson))).to.equal(0)
		end)

		it("gives the rifle its own voice and leaves a weapon without one silent", function()
			local Sound = require(scripts:WaitForChild("Weapon")).Sound
			local rifle = Weapons.row("rifle")
			expect(Sound.voiceFor(rifle, "shot")).to.be.ok()
			expect((Sound.voiceFor(rifle, "shot") :: any).id).never.to.equal("")
			-- A CUT IS NOT OPTIONAL: a library "Single Shots" sample is a take, not a round.
			expect((Sound.voiceFor(rifle, "shot") :: any).cut > 0).to.equal(true)
			expect(Sound.voiceFor(rifle, "bolt")).to.be.ok()
			expect(Sound.voiceFor(rifle, "magazine")).to.be.ok()
			-- ...and the SHOTGUN has none of its own, which is what keeps it on the camera config's
			-- single id -- the gun this repo has had all along.
			expect(Sound.voiceFor(Weapons.row("shotgun"), "shot")).to.equal(nil)
			expect(Sound.voiceFor(nil, "shot")).to.equal(nil)
		end)

		it("hides the shell feed on a magazine weapon, which has nothing to feed by hand", function()
			-- THE OTHER ROUND-1 FINDING: three chambers plus `CYCLE_EJECTS = "spent"` leave a live
			-- chamber while the action is open, which the shell-feed animation reads as "that
			-- chamber was just loaded" -- so the LEFT hand dived off the fore-end on every bolt
			-- cycle, which is the opposite of what Karen asked for.
			--
			-- IT DRIVES THE PLAYER'S PATH, which is round 3's correction: round 2's version asserted
			-- 0 from a function that returns 0 on an EARLIER guard, so it passed with the fix
			-- deleted. The state below is what `Camera.breakFrom` produces after a rifle `Break` --
			-- the action open, one case spent, chamber 2 still holding a round -- and the clock is
			-- the module's own, which is what `loadedAt` is stamped from.
			local before = Camera.Viewmodel.reloadState()
			-- THE REAL `SHELL_LOAD`, not a fabricated one: it is the raw pose block out of
			-- `poses.json` (`{pos = ..., rot = ...}` per keyframe), and a hand-built table of CFrames
			-- fails inside `loadStep` with "pos is not a valid member of CFrame" -- which is how the
			-- first version of this case failed the gate rather than measuring anything.
			--
			-- WHAT DECIDES IT IS THE GUN'S OWN GEOMETRY SINCE TASK 224, not `MAGAZINE_SWAP`. That
			-- field answers *"does this gun swap a box"* and was standing in for *"is this gun
			-- hand-fed"*; the two agree on the shotgun and the Rigby and disagree on the lever
			-- rifle, which has no magazine block and is not hand-fed either. So the two sides of
			-- this case are now two GEOMETRIES, passed in by parameter -- which is also what keeps
			-- the function pure, rather than answering differently depending on which Tool happens
			-- to be in the hand while the spec runs.
			local plain = firstPerson
			expect((plain :: any).SHELL_LOAD).to.be.ok()
			local ok, why = pcall(function()
				Camera.Viewmodel.setReload({ open = true, spent = 1, loaded = { false, true } })
				-- A BREAK ACTION IS MID-FEED HERE, which is what makes the case able to fail: the
				-- weight is non-zero for the hand-fed gun...
				local now = os.clock() + (plain :: any).SHELL_LOAD.fetchSeconds * 0.5
				expect(Camera.Viewmodel.handFeedsShells(Gun)).to.equal(true)
				expect((Camera.Viewmodel.loadingAt(plain, now, Gun)) > 0).to.equal(true)
				-- ...and exactly zero for a magazine rifle, which is the whole fix.
				expect(Camera.Viewmodel.handFeedsShells(RifleGeometry)).to.equal(false)
				expect((Camera.Viewmodel.loadingAt(plain, now, RifleGeometry))).to.equal(0)
				-- ...AND ZERO FOR THE LEVER RIFLE TOO (task 224), which is the gun that would have
				-- flipped a red 12-gauge hull out of a .45-70 under the old predicate.
				expect(Camera.Viewmodel.handFeedsShells(LeverGeometry)).to.equal(false)
				expect((Camera.Viewmodel.loadingAt(plain, now, LeverGeometry))).to.equal(0)
			end)
			Camera.Viewmodel.setReload(before)
			if not ok then
				error(why, 0)
			end
		end)

		it("takes the eye off the glass to work the bolt, and only for a scope that asks", function()
			-- THE ADOPTED BEHAVIOUR, BOTH BRANCHES, BY PARAMETER (task 142 round 3). The note's
			-- section 2: PUBG's own community asks how to STAY scoped through a bolt cycle, which is
			-- evidence that the default is to leave it, and BF1 requires coming out of the sight --
			-- and for THIS game the sight picture is a black mask with the gun behind it, so staying
			-- would hide the thing Karen asked to see.
			local scope = Rifle.CONFIG.scope
			expect(scope.cycle.leaveScope).to.equal(true)
			-- a step is running and the scope says to come down
			expect(Camera.leavesScopeFor("Break", scope)).to.equal(true)
			expect(Camera.leavesScopeFor("Close", scope)).to.equal(true)
			expect(Camera.leavesScopeFor("Magazine", scope)).to.equal(true)
			-- ...nothing is running, so the eye stays where the player put it
			expect(Camera.leavesScopeFor(nil, scope)).to.equal(false)
			-- ...a weapon with no scope has none to leave
			expect(Camera.leavesScopeFor("Break", nil)).to.equal(false)
			expect(Camera.leavesScopeFor("Break", Weapons.row("shotgun").scope)).to.equal(false)
			-- ...AND THE OTHER PATTERN IS ONE NUMBER: a scope that says false keeps the picture up.
			local stays = { cycle = { leaveScope = false } }
			expect(Camera.leavesScopeFor("Break", stays)).to.equal(false)
		end)

		it("prints rounds over capacity for a magazine, and glyphs for a break action", function()
			local rifle = Weapons.row("rifle")
			local full = {
				equipped = true,
				open = false,
				barrels = { "Live", "Live", "Live" },
				loaded = { "Slug", "Slug", "Slug" },
				selected = 1,
				ammo = "Slug",
				reserve = { Slug = 9 },
				busyFor = 0,
				weapon = "rifle",
			}
			expect(string.find(Hud.readoutFor(full :: any, rifle), "3/3", 1, true)).to.be.ok()
			local one = table.clone(full)
			one.barrels = { "Spent", "Spent", "Live" }
			expect(string.find(Hud.readoutFor(one :: any, rifle), "1/3", 1, true)).to.be.ok()
			-- ...and the shotgun still prints one glyph per chamber, which is what it has always done.
			local sg = table.clone(full)
			sg.barrels = { "Live", "Live" }
			sg.loaded = { "Slug", "Slug" }
			sg.weapon = "shotgun"
			local text = Hud.readoutFor(sg :: any, Weapons.row("shotgun"))
			expect(string.find(text, "/", 1, true)).to.equal(nil)
			expect(string.find(text, "[*]", 1, true)).to.be.ok()
		end)

		it("puts a red dot at the centre of the cross, sized in the same degrees", function()
			local scope = Rifle.CONFIG.scope
			local dot = scope.reticle.dot
			expect(dot).to.be.ok()
			-- IT IS A TOGGLE SINCE TASK 146, defaulting on: Karen asked for the dot on 2026-10-09
			-- and the reference she sent on 2026-10-10 has none, so the answer is one data line.
			expect((dot :: any).enabled).to.equal(true)
			local reticle = Hud.reticle() :: Frame
			Hud.layoutReticle(reticle, scope, scope.aimFovDeg)
			frames(1)
			local core = reticle:FindFirstChild("Dot") :: Frame
			local halo = reticle:FindFirstChild("DotHalo") :: Frame
			expect(core).to.be.ok()
			expect(halo).to.be.ok()
			local viewportY = Workspace.CurrentCamera.ViewportSize.Y
			local wanted = Hud.reticleDegToPx(dot.deg, scope.aimFovDeg, viewportY)
			expect(math.abs(core.AbsoluteSize.X - math.max(1, wanted)) <= 1).to.equal(true)
			-- THE HALO IS BIGGER AND SOFTER, which is what gives the dot an edge on a bright trunk.
			expect(halo.AbsoluteSize.X > core.AbsoluteSize.X).to.equal(true)
			expect(halo.BackgroundTransparency > core.BackgroundTransparency).to.equal(true)
			-- ...and it is ON TOP of the cross, because a dot behind a hair is not a dot.
			expect(core.ZIndex > (reticle:FindFirstChild("CrossTop") :: Frame).ZIndex).to.equal(true)
			TestKit.note(
				string.format(
					"rifle: red dot %d px, halo %d px of %d viewport",
					core.AbsoluteSize.X,
					halo.AbsoluteSize.X,
					viewportY
				)
			)
		end)
	end)

	-- ------------------------------------------------------ the kick is the DRAWN gun's (task 183)
	--
	-- THE CASE THAT WOULD HAVE CAUGHT IT. `Camera.kick` read `Poses.config(Config)` with no weapon
	-- id, which answers for `Viewmodel.DEFAULT_WEAPON` -- the SHOTGUN -- and `Mode.kick` is the only
	-- reader of the six RECOIL_* numbers in the repo. So `poses.json`'s `weapons.rifle.fire` block
	-- reached nothing: task 183 raised the rifle's kick to 19 degrees and the player still got the
	-- shotgun's 8, clamped by the shotgun's own ceiling. `rifle.spec`'s "kicks harder than the
	-- shotgun" could not see it, because it asserts DATA RELATIONS and the data was always right.
	--
	-- SO THIS ONE EQUIPS THE RIFLE AND READS THE STATE THE PLAYER WOULD BE LOOKING THROUGH. It is
	-- the only place the wiring is observable: with the shotgun in hand the buggy and the correct
	-- code return the same table, so a case driven by whatever the harness happens to hold is
	-- vacuous exactly when it matters.
	describe("the kick belongs to the gun on screen", function()
		it("applies the rifle's own recoil when the rifle is the drawn weapon", function()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local backpack = player:FindFirstChildOfClass("Backpack")
			local held = character and character:FindFirstChildOfClass("Tool")
			local rifle = nil
			for _, where in ipairs({ backpack, character }) do
				if where ~= nil and rifle == nil then
					local found = where:FindFirstChild("Rifle")
					if found ~= nil and found:IsA("Tool") then
						rifle = found
					end
				end
			end

			local rifleView = Viewmodel.view(Viewmodel.DATA, "rifle")
			local shotgunView = Viewmodel.view(Viewmodel.DATA, "shotgun")
			-- The two really are different numbers, or nothing below can tell them apart.
			expect(rifleView.RECOIL_CAM_PITCH_DEG).never.to.equal(shotgunView.RECOIL_CAM_PITCH_DEG)

			if humanoid == nil or rifle == nil then
				TestKit.note(
					"rifle kick: no rifle Tool to equip ("
						.. (if humanoid == nil then "no humanoid" else "not in the backpack")
						.. "), so the wiring was asserted through Camera.fireConfig instead"
				)
				-- THE WEAKER CLAIM, NEVER SILENCE: whatever weapon is drawn, the shot's config is
				-- the SAME one the poses resolve to. That is the omission, stated without a rifle.
				expect(Camera.fireConfig()).to.equal(Camera.poseConfig())
				return
			end

			humanoid:EquipTool(rifle)
			local drawn = nil
			for _ = 1, 60 do
				drawn = Camera.Viewmodel.weaponId()
				if drawn == "rifle" then
					break
				end
				frames(2)
			end

			local applied, settled = nil, false
			if drawn == "rifle" then
				-- FROM REST, so the number read back is the kick itself and not a clamped sum.
				for _ = 1, 240 do
					if not Mode.recoiling(Camera.getState()) then
						settled = true
						break
					end
					frames(1)
				end
				if settled then
					Camera.kick()
					applied = Camera.getState()
				end
			end

			-- PUT THE GUN BACK BEFORE ASSERTING ANYTHING, so a failure here cannot leave the session
			-- holding a weapon the specs that run after this file do not expect.
			if held ~= nil and held ~= rifle then
				humanoid:EquipTool(held)
			else
				humanoid:UnequipTools()
			end
			for _ = 1, 60 do
				if Camera.Viewmodel.weaponId() ~= "rifle" then
					break
				end
				frames(2)
			end

			expect(drawn).to.equal("rifle")
			expect(settled).to.equal(true)
			expect(applied).to.be.ok()
			local state = applied :: any
			-- THE THREE NUMBERS `Mode.kick` WRITES, against the RIFLE's row and not the default's.
			expect(math.abs(state.recoilCamPitchDeg - rifleView.RECOIL_CAM_PITCH_DEG) < 1e-6).to.equal(true)
			expect(math.abs(state.recoilGunPitchDeg - rifleView.RECOIL_GUN_PITCH_DEG) < 1e-6).to.equal(true)
			expect(math.abs(state.recoilGunBackStuds - rifleView.RECOIL_GUN_BACK_STUDS) < 1e-6).to.equal(true)
			-- ...and explicitly NOT the shotgun's, which is the bug written out.
			expect(math.abs(state.recoilCamPitchDeg - shotgunView.RECOIL_CAM_PITCH_DEG) > 1e-6).to.equal(true)
			TestKit.note(
				string.format(
					"rifle kick: drawn=%s applied view %.2f deg / gun %.2f deg / back %.3f studs "
						.. "(rifle wants %.2f / %.2f / %.3f, shotgun %.2f / %.2f / %.3f)",
					tostring(drawn),
					state.recoilCamPitchDeg,
					state.recoilGunPitchDeg,
					state.recoilGunBackStuds,
					rifleView.RECOIL_CAM_PITCH_DEG,
					rifleView.RECOIL_GUN_PITCH_DEG,
					rifleView.RECOIL_GUN_BACK_STUDS,
					shotgunView.RECOIL_CAM_PITCH_DEG,
					shotgunView.RECOIL_GUN_PITCH_DEG,
					shotgunView.RECOIL_GUN_BACK_STUDS
				)
			)
		end)
	end)

	-- ------------------------------------------------------ the reticle IS the camera centre (183)
	--
	-- KAREN, 2026-10-14: *"hit it has to be precist and on 200m acurat"*. The server shoots along
	-- `camera.CFrame.LookVector` -- that is the whole of the wire message (`Weapon.Input.onFire`) --
	-- and the LookVector passes through the centre of the VIEWPORT. So the mark the player holds on
	-- the animal is only honest if it is drawn at that pixel, and there is one classic way for it
	-- not to be: a ScreenGui that respects the topbar inset puts its own (0, 0) 36 px down the
	-- screen, which at this scope's 19.87 degrees over a 1080-high viewport is 0.33 degrees -- over
	-- FOUR STUDS, more than a metre, low at 200 m.
	--
	-- SO IT IS MEASURED AGAINST THE RAY, not against a number: a world point placed ON the look
	-- vector is projected back to the screen, and that pixel has to be the dot's own centre.
	describe("the reticle centre is the camera centre", function()
		it("draws the dot on the pixel the shot ray goes through", function()
			local camera = Workspace.CurrentCamera
			expect(camera).to.be.ok()
			local gui = Hud.gui()
			expect(gui).to.be.ok()
			-- THE INSET, FIRST AND BY NAME: with this false every mark in the Hud sits half the
			-- topbar lower than the ray, and nothing else in this case would notice.
			expect((gui :: ScreenGui).IgnoreGuiInset).to.equal(true)

			local scope = Rifle.CONFIG.scope
			local reticle = Hud.reticle() :: Frame
			Hud.layoutReticle(reticle, scope, scope.aimFovDeg)
			frames(2)

			-- WHERE THE SHOT REALLY GOES, projected back to the screen. 500 studs out so the
			-- projection is well clear of the near plane; the answer is the same at any distance
			-- along the ray, which is the point.
			--
			-- `WorldToScreenPoint` AND NOT `WorldToViewportPoint`, AND THAT COST A ROUND. The two
			-- differ by exactly the topbar inset, and MEASURED in the DEV place on 2026-10-14 the
			-- inset is (0, 58): the ray through the centre of a 969 x 784 viewport projects to
			-- (484.5, 392.0) in VIEWPORT coordinates and (484.5, 334.0) in SCREEN ones. A
			-- GuiObject's `AbsolutePosition` is in the SCREEN space -- the ScreenGui itself reports
			-- `AbsolutePosition = (0, -58)` with `IgnoreGuiInset` true, which is what "ignores the
			-- inset" means: it covers the whole viewport, and its origin is still quoted relative
			-- to the inset-adjusted one. So the screen projection is the one that can be compared
			-- with a frame, and the first version of this case failed by precisely those 58 px
			-- while the dot was exactly where it belonged.
			local onTheRay = camera.CFrame.Position + camera.CFrame.LookVector * 500
			local projected, onScreen = camera:WorldToScreenPoint(onTheRay)
			expect(onScreen).to.equal(true)
			expect(projected.Z > 0).to.equal(true)

			local core = reticle:FindFirstChild("Dot") :: Frame
			expect(core).to.be.ok()
			local drawn = (core :: Frame).AbsolutePosition + (core :: Frame).AbsoluteSize / 2
			local offPx = (Vector2.new(projected.X, projected.Y) - drawn).Magnitude
			-- TWO PIXELS, AND THE REASON IS ROUNDING, not tolerance for an error: an odd-sized
			-- frame centred on an even pixel lands half a pixel off, and Roblox rounds
			-- `AbsolutePosition` to integers. Two pixels at this scope on a 1080-high viewport is
			-- 0.037 degrees, which is 0.46 studs -- 13 cm -- at 200 m, and it is a DRAWING error of
			-- the mark rather than of the ray.
			TestKit.note(
				string.format(
					"reticle centre: ray lands at (%.1f, %.1f), dot at (%.1f, %.1f) -> %.2f px off; "
						.. "viewport %d x %d, inset %d px, gui origin %.0f, inset ignored",
					projected.X,
					projected.Y,
					drawn.X,
					drawn.Y,
					offPx,
					camera.ViewportSize.X,
					camera.ViewportSize.Y,
					GuiService:GetGuiInset().Y,
					(gui :: ScreenGui).AbsolutePosition.Y
				)
			)
			expect(offPx <= 2).to.equal(true)

			-- ...AND THE CROSS AGREES WITH THE DOT, because two marks at two centres is the bug
			-- that would survive the assertion above: `spanLens` runs the hairs edge to edge, so
			-- their crossing is where the vertical bar's X meets the horizontal bar's Y.
			local vertical = reticle:FindFirstChild("CrossTop") :: Frame
			local horizontal = reticle:FindFirstChild("CrossLeft") :: Frame
			expect(vertical).to.be.ok()
			expect(horizontal).to.be.ok()
			local crossX = (vertical :: Frame).AbsolutePosition.X + (vertical :: Frame).AbsoluteSize.X / 2
			local crossY = (horizontal :: Frame).AbsolutePosition.Y + (horizontal :: Frame).AbsoluteSize.Y / 2
			expect(math.abs(crossX - projected.X) <= 2).to.equal(true)
			expect(math.abs(crossY - projected.Y) <= 2).to.equal(true)

			TestKit.note(string.format("reticle centre: cross crosses at (%.1f, %.1f)", crossX, crossY))
		end)
	end)

	describe("the downloaded count follows the folder it is asked about", function()
		it("counts the folder it is HANDED, which is the whole of the first bug", function()
			-- THE DEFECT, PINNED (the Reviewer's note, round 1). The live case above is vacuous in
			-- DEV -- there are no downloaded templates there -- and the real fix was that this
			-- count took one weapon's folder name whatever weapon was drawn. A stub folder of this
			-- spec's own proves the count follows the NAME, in any place.
			local ready = ReplicatedStorage:FindFirstChild("DHSpecReadyProbe")
			if ready then
				ready:Destroy()
			end
			expect(Camera.Viewmodel.readyMeshesIn("DHSpecReadyProbe")).to.equal(0)
			local folder = Instance.new("Folder")
			folder.Name = "DHSpecReadyProbe"
			-- PLAIN PARTS, which `meshReady` answers true for: this case is about the COUNT and the
			-- name, not about the engine's fetch status, which the live gun exercises.
			for index = 1, 3 do
				local part = Instance.new("Part")
				part.Name = "Piece" .. index
				part.Parent = folder
			end
			folder.Parent = ReplicatedStorage
			local ok, why = pcall(function()
				expect(Camera.Viewmodel.readyMeshesIn("DHSpecReadyProbe")).to.equal(3)
				-- ...AND A DIFFERENT NAME IS A DIFFERENT ANSWER, which is the assertion the bug
				-- fails: before the fix this function ignored its argument entirely.
				expect(Camera.Viewmodel.readyMeshesIn("DHSpecReadyProbeMissing")).to.equal(0)
				-- ...and every weapon's own folder is askable by name, which is how the viewmodel
				-- uses it.
				for _, id in ipairs(Weapons.ids()) do
					local geometry = Weapons.geometry(id)
					expect(geometry).to.be.ok()
					local name = (geometry :: any).FOLDER_NAME
					expect(type(name)).to.equal("string")
					expect(Camera.Viewmodel.readyMeshesIn(name) >= 0).to.equal(true)
				end
			end)
			folder:Destroy()
			if not ok then
				error(why, 0)
			end
		end)
	end)

	describe("the drive report's detail row", function()
		it("prints the gun's WORD after the distance, and nothing at all for an old record", function()
			-- DESIGN SECTION 9, and the one half of the report path a spec can reach: the row is
			-- built by `HitLog`'s own local `detailPayload` (only `onRequest`'s remote returns it),
			-- but what the SCREEN does with `row.weapon` is this function and it is public.
			local Report = Hud.Report
			local row = {
				kind = "female",
				result = "down",
				zone = "chest",
				distance = 45,
				hits = 1,
				weapon = "rifle",
			}
			local text = Report.detailRowText(row)
			local label = Weapons.row("rifle").label
			expect(string.find(text, label, 1, true)).to.be.ok()
			-- AFTER THE DISTANCE AND BEFORE THE HITS, which is the order the header names. The
			-- range column is matched as a PATTERN because `distance` is in studs and the column
			-- prints metres (45 studs is 13 m), which is `Report.metres`' business and not this
			-- case's.
			local atRange = string.find(text, "%d+ m")
			local atGun = string.find(text, label, 1, true)
			expect(atRange).to.be.ok()
			expect((atGun :: number) > (atRange :: number)).to.equal(true)
			-- ...AND EVERY COLUMN STANDS IN ITS OWN CELL, for every label the weapon table carries.
			-- UNTIL TASK 201 PART 2 THIS WAS A CHARACTER OFFSET -- the row was one padded monospace
			-- string and `RIFLE (OPEN)` at twelve characters pushed HITS three right of its header
			-- (the Reviewer's round-1 note on task 143). The row is one `TextLabel` PER CELL now
			-- (the design system section 3.12), so the question is no longer "where in the string"
			-- but "is it the GUN cell" -- which is the thing that was actually being asked, and it
			-- cannot be broken by a longer word.
			local head = Report.detailHeaderText()
			expect((string.find(head, "GUN", 1, true) :: number) > (string.find(head, "RANGE", 1, true) :: number)).to.equal(
				true
			)
			for _, id in ipairs(Weapons.ids()) do
				local one = table.clone(row)
				one.weapon = id
				local cells = Report.detailCellsFor(one)
				local word = (Weapons.row(id) :: any).label
				expect(cells.gun).to.equal(word)
				-- ...and the HITS cell is its own, whatever the gun is called.
				expect(cells.hits).to.equal(tostring(one.hits))
			end
			-- THE COLUMN THE CELL IS DRAWN IN has a place of its own, and GUN is left of HITS.
			local gunColumn, hitsColumn = nil, nil
			for _, column in ipairs(Report.DETAIL_COLUMNS) do
				if column.key == "gun" then
					gunColumn = column
				elseif column.key == "hits" then
					hitsColumn = column
				end
			end
			expect(gunColumn).to.be.ok()
			expect(hitsColumn).to.be.ok()
			expect((gunColumn :: any).x + (gunColumn :: any).w <= (hitsColumn :: any).x).to.equal(true)

			-- A RECORD FROM BEFORE THE RIFLE NAMES NO GUN, and prints no word rather than "nil".
			local old = table.clone(row)
			old.weapon = nil
			local plain = Report.detailRowText(old)
			expect(string.find(plain, "nil", 1, true)).to.equal(nil)
			expect(string.find(plain, label, 1, true)).to.equal(nil)
			TestKit.note("rifle: detail row = '" .. text .. "'")
		end)
	end)

	describe("two Tools, and the drawn gun follows the Instance", function()
		it("watches every Tool this system owns, and no more than the loadout has", function()
			local Weapon = require(scripts:WaitForChild("Weapon"))
			local watched = Weapon.Input.watchedTools()
			expect(watched <= #Weapons.loadout()).to.equal(true)
			-- ...and the filter is the TABLE's, not a literal: a Tool of another system is ignored.
			expect(Weapons.isToolName("Shotgun")).to.equal(true)
			expect(Weapons.isToolName("Lantern")).to.equal(false)
			TestKit.note(string.format("rifle: %d tool(s) watched, loadout is %d", watched, #Weapons.loadout()))
		end)

		it("reads the weapon off the Tool the viewmodel was built from", function()
			-- THE DRAWN GUN FOLLOWS THE INSTANCE (design 5.2). With the flag off the player holds a
			-- shotgun, so this asserts the route rather than the rifle: the id is whatever the Tool
			-- says, and nil only when there is no Tool at all.
			local id = Camera.Viewmodel.weaponId()
			local character = player.Character
			local tool = character and character:FindFirstChildOfClass("Tool")
			-- ...AND ONLY IF IT IS A GUN (task 152). The beater's horn is a `Tool` with no weapon
			-- attribute, so `weaponId()` answers nil for one -- correctly -- and `Weapons.row(nil)`
			-- below would then be asserted non-nil for a player holding a horn.
			if tool ~= nil and not Weapons.isWeaponTool(tool) then
				tool = nil
			end
			if tool ~= nil then
				expect(id).to.equal(tool:GetAttribute("DrivenHunt.Weapon"))
				expect(Weapons.row(id)).to.be.ok()
			else
				expect(id).to.equal(nil)
			end
		end)
	end)
end
