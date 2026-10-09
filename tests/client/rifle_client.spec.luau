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

		it("lays out as a duplex, thin in the middle and thick at the edge", function()
			local reticle = Hud.reticle() :: Frame
			local spec = Rifle.CONFIG.scope.reticle
			local viewportY = Workspace.CurrentCamera.ViewportSize.Y
			Hud.layoutReticle(reticle, spec, Rifle.CONFIG.scope.aimFovDeg)
			frames(1)
			local ring = reticle:FindFirstChild("Ring") :: Frame
			expect(ring).to.be.ok()
			local wanted = Hud.reticleDegToPx(spec.ringOuterDeg, Rifle.CONFIG.scope.aimFovDeg, viewportY)
			-- MEASURED AGAINST THE LIVE VIEWPORT, not against 1080: a Studio Play window is nowhere
			-- near it, and a fixed pixel count there would be a looser claim.
			expect(math.abs(ring.AbsoluteSize.Y - wanted) <= 2).to.equal(true)
			local cross = reticle:FindFirstChild("CrossTop") :: Frame
			local post = reticle:FindFirstChild("PostTop") :: Frame
			expect(cross).to.be.ok()
			expect(post).to.be.ok()
			expect(post.AbsoluteSize.X > cross.AbsoluteSize.X).to.equal(true)
			TestKit.note(
				string.format(
					"rifle: reticle ring %d px of %d viewport (asked %.1f px)",
					ring.AbsoluteSize.Y,
					viewportY,
					wanted
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
			local wanted = math.min(
				Hud.reticleDegToPx(scope.eyepiece.diameterDeg, scope.aimFovDeg, viewport.Y),
				math.min(viewport.X, viewport.Y)
			)
			expect(math.abs(mask.AbsoluteSize.X - wanted) <= 2).to.equal(true)
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
