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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Hud = require(scripts:WaitForChild("Hud"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
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
			-- Give a late download the quarter-second the viewmodel's own staleness tick runs on.
			frames(60)
			local model = Camera.Viewmodel.current()
			expect(model).to.be.ok()
			local worn: { [string]: boolean } = {}
			for _, part in ipairs((model :: Model):GetDescendants()) do
				if part:IsA("MeshPart") then
					worn[part.Name] = true
				end
			end
			local ready, drawn, missing = 0, 0, {}
			for _, template in ipairs(folder:GetChildren()) do
				if Camera.Viewmodel.meshReady(template) then
					ready += 1
					if worn[template.Name] then
						drawn += 1
					else
						table.insert(missing, template.Name)
					end
				end
			end
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
			local plain = firstPerson
			expect((plain :: any).SHELL_LOAD).to.be.ok()
			local magazine = table.clone(plain) :: any
			magazine.MAGAZINE_SWAP =
				{ outShare = 0.38, inShare = 0.4, dropStuds = 0.42, seconds = 1.35, hand = CFrame.new() }
			table.freeze(magazine)
			local ok, why = pcall(function()
				Camera.Viewmodel.setReload({ open = true, spent = 1, loaded = { false, true } })
				-- A BREAK ACTION IS MID-FEED HERE, which is what makes the case able to fail: the
				-- weight is non-zero without the magazine block...
				local now = os.clock() + (plain :: any).SHELL_LOAD.fetchSeconds * 0.5
				expect((Camera.Viewmodel.loadingAt(plain, now)) > 0).to.equal(true)
				-- ...and exactly zero with it, which is the whole fix.
				expect((Camera.Viewmodel.loadingAt(magazine, now))).to.equal(0)
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
			local header = Report.detailHeaderText()
			expect((string.find(header, "GUN", 1, true) :: number) > (string.find(header, "RANGE", 1, true) :: number)).to.equal(
				true
			)
			-- ...AND EVERY COLUMN STANDS UNDER ITS OWN HEADING, for every label the weapon table
			-- carries (the Reviewer's round-1 note: `RIFLE (OPEN)` is twelve characters and the
			-- field was nine, so every open-rifle row pushed HITS three characters right). A case
			-- rather than an eye, so weapon four's label fails here and not on Karen's screen.
			for _, id in ipairs(Weapons.ids()) do
				local one = table.clone(row)
				one.weapon = id
				local line = Report.detailRowText(one)
				local word = (Weapons.row(id) :: any).label
				expect(string.find(line, word, 1, true)).to.equal(string.find(header, "GUN", 1, true))
				-- ...and the HITS column is the right-hand edge of both, which is what makes the
				-- count readable: `%4d` ends where `HITS` ends.
				expect(#line).to.equal(#header)
			end

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
			if tool ~= nil then
				expect(id).to.equal(tool:GetAttribute("DrivenHunt.Weapon"))
				expect(Weapons.row(id)).to.be.ok()
			else
				expect(id).to.equal(nil)
			end
		end)
	end)
end
