--!strict
-- Match.Body: the only writer of a player's TEAM and of where their character stands. Named after
-- Boar/Body.luau, which has exactly this role for the boar: the module that touches Instances so
-- that nothing else in the system has to.
--
-- It decides NOTHING. Every team, every position and every timing arrives as an argument.
--
--   Team / Player.Team  https://create.roblox.com/docs/reference/engine/classes/Team
--     Roblox's own team field: server-authoritative (a client cannot write it), replicated for free,
--     and what Boar.CONFIG.isThreat and Shotgun.CONFIG.shouldArm were both written against. Teams is
--     NOT a Rojo-owned container, so the two Team instances are created at run time and are
--     invisible to the harness's file comparison -- a spec is the only proof they exist.
--     AutoAssignable is set to FALSE explicitly: the page does not state its default
--     (docs/research/2026-09-25-drive.md source A), and Roblox assigning players itself would be a
--     second writer of the one field this system owns.
--
-- PivotTo AFTER LoadCharacter IS A TWO-STEP, not one call: the character does not exist
-- synchronously. place() connects CharacterAdded BEFORE calling LoadCharacter and pivots in that
-- handler, and the owner counts placementsMissed when a character never arrives -- a number in the
-- harness report rather than a feeling in a playtest.
--
-- SINCE MILESTONE 1.7b IT ALSO TIES A PLAYER TO A TREE (design section 8.4) and owns
-- Workspace.DriveMarkers, the one runtime container this system creates -- one rope Part per tied
-- player and nothing else, ever (design section 6.4). Workspace is not Rojo-owned and the harness
-- compares the Edit-mode DataModel, so a run-time folder cannot dirty a run, exactly as
-- Workspace.WeaponEffects does not.
--   Humanoid.WalkSpeed  https://create.roblox.com/docs/reference/engine/classes/Humanoid#WalkSpeed
--     The stock PlayerModule drives movement through Humanoid:Move and never writes WalkSpeed, so
--     this is not a second writer of anything (the same boundary docs/design/camera.md section 6.3
--     records for the camera).
--   BasePart.Anchored   https://create.roblox.com/docs/reference/engine/classes/BasePart#Anchored
--     The belt to WalkSpeed's braces: the CHARACTER'S physics is owned by its own client, so a
--     server-side pivot alone is a suggestion the client can walk out of. Anchoring first makes the
--     pivot stick, which is why the order here is anchor-then-pivot and not the design's list order.
--
-- SINCE M2.8d IT ALSO DRESSES THE CHARACTER (map-generator design section 10): a shooter gets an
-- orange hat, a driver an orange vest. Same module, same signal, same discipline -- it is one more
-- thing written onto a character at the moment the team or the character changes, and the design
-- gives it this owner precisely so it never gets two (not the Hud, which draws the screen and not
-- the world; not the client, which cannot be trusted or screenshotted from the server).
--
-- Design: docs/design/drive.md (sections 5.1, 5.3, 6.4, 8.4),
--         docs/design/map-generator.md (section 10)
-- Note:   docs/research/2026-09-25-drive.md
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Body = {}

export type TeamName = "Drivers" | "Shooters"

-- What a tied player's humanoid was before it was frozen, keyed by userId so nothing here holds a
-- Player (design section 7.2's discipline, applied to this table too). Written only by tie/untie.
local held: { [number]: { walkSpeed: number, jumpHeight: number, jumpPower: number } } = {}

local TEAM_COLORS = {
	Drivers = BrickColor.new("Bright blue"),
	Shooters = BrickColor.new("Bright orange"),
}

-- ------------------------------------------------------------------- M2.8d: the outfits
-- ONE FOLDER PER CHARACTER, destroyed and rebuilt (design section 10.2). Parented to the character,
-- which is what makes "removed on leave and on respawn" structural rather than a cleanup path: a
-- respawn replaces the character and takes its children with it, and so does leaving.
Body.OUTFIT_NAME = "HuntOutfit"

-- HUNTER ORANGE, RGB(255, 112, 0), the design's number, and the same one for both roles. In the
-- field both sides wear safety orange; what says WHICH side you are is the Hud's badge and the team
-- colour below. Director's pick and Karen's to change (her rule: styling never blocks).
local OUTFIT_COLOR = Color3.fromRGB(255, 112, 0)

-- THE GREY-BOX OUTFIT. The design's table (section 10.2) plus the fields it cannot express --
-- `shape`, `rotationDeg`, and since Task 82 `scale`/`pad`/`anchor`, which is how a row says "fit
-- yourself to the limb you are hung on" instead of naming studs that are only right for one avatar.
--
-- `fallbackLimb` is R6: an R15 character has `UpperTorso` and an R6 one has `Torso`. A missing limb
-- is a counted miss rather than a crash.
--
-- THE HAT IS TWO PARTS AND THE SCREENSHOT IS WHY (rule 5). The design's table is one flat cylinder,
-- 2.2 x 0.6 x 2.2 at +0.8 above the Head's centre, and that is exactly what was built and
-- photographed first (.screenshots/20260927T031301Z-task77-hat-2.png): a disc AT THE HAIR LINE that
-- the avatar's hair grows straight through. It measured perfectly -- the spec's 0.95 is still
-- asserted below -- and it read as an orange HALO, not headwear. A hat is a crown and a brim; one
-- disc at any height is a brim on its own, and this project has a whole page about things that
-- measure correct and look wrong (docs/PROJECT_CONTEXT.md).
--
-- So the brim keeps the design's 2.2 diameter and its place in the silhouette, thins to 0.35 and
-- rises to clear a default avatar's hair, and a short crown sits on it. The hat's rows keep their
-- STUDS, because Karen has seen this hat on a player and it reads (PLAYTEST.md, 2026-09-27).
--
-- AND THE VEST IS FOUR PLATES THAT WRAP THE TORSO, BECAUSE KAREN COULD NOT SEE THE OLD ONE.
-- PLAYTEST.md, 2026-09-27: "I can see hat on hunter but not vest on driver". The old row was one
-- 2.2 x 1.6 x 1.3 box CENTRED on the torso, and both halves of that are why it was invisible:
--   * CENTRED means most of it is INSIDE the limb. It stood 0.1 proud on each side of an R15
--     UpperTorso of (2, 1.6, 1) and 0.15 front and back -- and nothing in this game guarantees that
--     torso. `HumanoidDescription` body scaling, an R6 `Torso` and any avatar bundle change the box,
--     and a torso wider than 2.2 or deeper than 1.3 SWALLOWS a part with those numbers whole. A
--     number that is only right for one avatar is the class of bug here, not the vest.
--   * ONE PLATE HAS ONE FACE. Karen looks at a driver from the front, from behind (her own camera is
--     over her shoulder) and from a post 40-80 m away.
-- So a vest row now says its size and its offset as a FUNCTION OF THE LIMB (`Body.fit`): four
-- plates, one per horizontal face, each standing VEST_GAP clear of the limb's own surface whatever
-- that surface is, and the two side plates deep enough to close the wrap around the other two. The
-- deviation from the design's single `Vest` row is recorded in TASKS.md row 82a for the Architect.
-- The thickness, the gap and the 0.78 of the torso's height are the Director's pick and Karen's to
-- change (her rule: styling never blocks).
local VEST_THICKNESS = 0.22
-- CLEAR OF THE SURFACE, not flush with it. Two coplanar faces z-fight, and a plate exactly on the
-- surface also sits INSIDE any layered-clothing mesh that stands off the limb's own box.
local VEST_GAP = 0.12
local VEST_HEIGHT_FRACTION = 0.78 -- of the torso's height: a vest, not a barrel

local OUTFITS = {
	Shooters = {
		{
			name = "Hat", -- the brim
			limb = "Head",
			fallbackLimb = nil,
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.35, 2.2, 2.2), -- world box 2.2 x 0.35 x 2.2 after the turn below
			rotationDeg = Vector3.new(0, 0, 90),
			offset = Vector3.new(0, 0.95, 0), -- above the Head's CENTRE, which is what a Position is
			color = OUTFIT_COLOR,
		},
		{
			name = "HatCrown",
			limb = "Head",
			fallbackLimb = nil,
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.7, 1.35, 1.35),
			rotationDeg = Vector3.new(0, 0, 90),
			offset = Vector3.new(0, 1.42, 0),
			color = OUTFIT_COLOR,
		},
	},
	-- FOUR PLATES, ONE PER HORIZONTAL FACE. `scale` is a multiple of the limb's own size, `pad` is
	-- studs added to it, and `anchor` is which face to sit on in halves of the limb (so -1 on Z is
	-- the -Z face). A character's front is its -Z, but the front and back plates are identical on
	-- purpose: a wrap has no front, so nothing here depends on which way a limb happens to face.
	Drivers = {
		{
			name = "VestFront",
			limb = "UpperTorso",
			fallbackLimb = "Torso",
			shape = Enum.PartType.Block,
			scale = Vector3.new(0.98, VEST_HEIGHT_FRACTION, 0),
			pad = Vector3.new(0, 0, VEST_THICKNESS),
			anchor = Vector3.new(0, 0, -1),
			offset = Vector3.new(0, 0, -(VEST_THICKNESS / 2 + VEST_GAP)),
			rotationDeg = Vector3.zero,
			color = OUTFIT_COLOR,
		},
		{
			name = "VestBack",
			limb = "UpperTorso",
			fallbackLimb = "Torso",
			shape = Enum.PartType.Block,
			scale = Vector3.new(0.98, VEST_HEIGHT_FRACTION, 0),
			pad = Vector3.new(0, 0, VEST_THICKNESS),
			anchor = Vector3.new(0, 0, 1),
			offset = Vector3.new(0, 0, VEST_THICKNESS / 2 + VEST_GAP),
			rotationDeg = Vector3.zero,
			color = OUTFIT_COLOR,
		},
		{
			-- The sides are as DEEP as the wrap needs to be closed: the limb plus both plates and
			-- both gaps, so there is no orange-free corner to look at a driver through.
			name = "VestLeftSide",
			limb = "UpperTorso",
			fallbackLimb = "Torso",
			shape = Enum.PartType.Block,
			scale = Vector3.new(0, VEST_HEIGHT_FRACTION, 1),
			pad = Vector3.new(VEST_THICKNESS, 0, 2 * (VEST_THICKNESS + VEST_GAP)),
			anchor = Vector3.new(-1, 0, 0),
			offset = Vector3.new(-(VEST_THICKNESS / 2 + VEST_GAP), 0, 0),
			rotationDeg = Vector3.zero,
			color = OUTFIT_COLOR,
		},
		{
			name = "VestRightSide",
			limb = "UpperTorso",
			fallbackLimb = "Torso",
			shape = Enum.PartType.Block,
			scale = Vector3.new(0, VEST_HEIGHT_FRACTION, 1),
			pad = Vector3.new(VEST_THICKNESS, 0, 2 * (VEST_THICKNESS + VEST_GAP)),
			anchor = Vector3.new(1, 0, 0),
			offset = Vector3.new(VEST_THICKNESS / 2 + VEST_GAP, 0, 0),
			rotationDeg = Vector3.zero,
			color = OUTFIT_COLOR,
		},
	},
}

-- What every fitted plate keeps between itself and the limb's surface, published so a spec asserts
-- the invariant rather than a number copied out of this file.
Body.VEST_GAP = VEST_GAP
Body.VEST_THICKNESS = VEST_THICKNESS
Body.VEST_HEIGHT_FRACTION = VEST_HEIGHT_FRACTION

-- PURE, and the whole of the fix. (size, offset) for one row on a limb of THIS size:
--   size   = limbSize * row.scale + row.pad
--   offset = limbSize/2 * row.anchor + row.offset
-- A row with no `scale` is a row in studs (the hat) and comes back exactly as written, so this is
-- the same function for both roles and there is no second code path to keep in step.
--
-- Because the offset is measured from the limb's own half-extent, the plate's INNER face lands
-- `VEST_GAP` clear of the limb's surface on ANY avatar: an R15 torso, an R6 `Torso`, a scaled one,
-- or a bundle nobody has seen yet. That is the invariant match_outfit.spec asserts over three
-- different torsos, and it is what the old hard-coded 2.2 x 1.6 x 1.3 could not promise.
function Body.fit(row: any, limbSize: Vector3): (Vector3, Vector3)
	if not row.scale then
		return row.size, row.offset
	end
	local scale, pad = row.scale, row.pad or Vector3.zero
	local anchor = row.anchor or Vector3.zero
	local size = Vector3.new(limbSize.X * scale.X + pad.X, limbSize.Y * scale.Y + pad.Y, limbSize.Z * scale.Z + pad.Z)
	local offset = Vector3.new(
		limbSize.X / 2 * anchor.X + row.offset.X,
		limbSize.Y / 2 * anchor.Y + row.offset.Y,
		limbSize.Z / 2 * anchor.Z + row.offset.Z
	)
	return size, offset
end

-- PURE (design section 10.2). Takes the team and the config, touches no Instance, and answers the
-- same way whether or not there is a game running -- which is what lets a spec drive BOTH states of
-- the flag with nothing to restore (feature-flags.md 13.3).
--
-- The switch is READ FROM THE CONFIG, not from `Flags` directly: `Match.CONFIG.OUTFITS_ENABLED` is
-- the one boundary read (CLAUDE.md, "Feature flags"), and passing it inward as a parameter is what
-- makes the ON branch reachable while the flag sits OFF.
function Body.dressFor(team: TeamName?, config): { any }
	if not team or not (config and config.OUTFITS_ENABLED) then
		return {}
	end
	return OUTFITS[team] or {}
end

-- DRESSES ONE CHARACTER. Destroys any existing outfit first, so it is idempotent and a team swap is
-- a re-dress rather than two hats.
--
-- Returns false only when it FAILED to do something it should have -- no character, or no limb to
-- hang the item on -- so the caller can count a miss rather than believe a change it did not make
-- (the `Body.tie` discipline). With the flag off there is nothing to do and that is a success, not a
-- miss: the folder is still cleared, so switching the flag off undresses at the next respawn.
--
-- FOUR PROPERTIES THAT ARE NOT TIDINESS (design section 10.2):
--   * `CanQuery = false`. A hat that stops a pellet changes what the shot hit, and what the shot hit
--     is what `Match.Penalty.judge` reads through the weapon's report. The outfit must be invisible
--     to every ray in the game. This is the one the client spec asserts.
--   * `Massless = true` and NOT anchored. `Body.tie` anchors the ROOT; an anchored hat would pin a
--     character's head to the world.
--   * `CanTouch = false`, which the design's list does not name and `Weapon.Hardware.addPiece` sets
--     for the same reason: a cosmetic part should not fire a Touched event at anything.
--   * `CastShadow = false`: a shadow is the only thing a hat could cost that a player would see.
--
-- THE FOLDER IS PARENTED FIRST, THEN THE PARTS, THEN THE WELDS. A `WeldConstraint` records the
-- offset the parts happen to have when it is enabled and needs both of them in the DataModel --
-- `src/server/Boar/Body.luau` says so where it uses one, and `Weapon.Hardware` uses a legacy Weld
-- instead precisely because its Tool is not parented anywhere yet. Here the character IS live, so
-- the design's WeldConstraint is the right one and the order is what makes it work.
function Body.dress(character: Model?, team: TeamName?, config): boolean
	if not character or not character.Parent then
		return false
	end
	local existing = character:FindFirstChild(Body.OUTFIT_NAME)
	if existing then
		existing:Destroy()
	end
	local rows = Body.dressFor(team, config)
	if #rows == 0 then
		return true -- nothing to wear: the flag is off, or this player has no team
	end
	local folder = Instance.new("Folder")
	folder.Name = Body.OUTFIT_NAME
	folder.Parent = character
	local made = 0
	for _, row in ipairs(rows) do
		local limb = character:FindFirstChild(row.limb)
		if not limb and row.fallbackLimb then
			limb = character:FindFirstChild(row.fallbackLimb)
		end
		if limb and limb:IsA("BasePart") then
			-- FITTED TO THE LIMB THAT WAS ACTUALLY FOUND, not to the one the row hoped for: an
			-- R6 `Torso` and a scaled R15 `UpperTorso` are different boxes and the vest wraps both.
			local size, offset = Body.fit(row, limb.Size)
			local part = Instance.new("Part")
			part.Name = row.name
			part.Shape = row.shape
			part.Size = size
			part.Color = row.color
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.CFrame = limb.CFrame
				* CFrame.new(offset)
				* CFrame.Angles(math.rad(row.rotationDeg.X), math.rad(row.rotationDeg.Y), math.rad(row.rotationDeg.Z))
			part.Parent = folder
			local weld = Instance.new("WeldConstraint")
			weld.Name = row.name .. "Weld"
			weld.Part0 = limb
			weld.Part1 = part
			weld.Parent = part
			made += 1
		end
	end
	if made == 0 then
		folder:Destroy()
		return false
	end
	return true
end

-- Creates the two teams once and returns them by name. Idempotent: a second call returns what is
-- already there rather than making a duplicate (rule 7 -- nothing here ever deletes a Team either).
function Body.ensureTeams(): { [string]: Team }
	local out = {}
	for name, color in pairs(TEAM_COLORS) do
		local existing = Teams:FindFirstChild(name)
		local team = if existing and existing:IsA("Team") then existing else Instance.new("Team")
		team.Name = name
		team.TeamColor = color
		team.AutoAssignable = false
		team.Parent = Teams
		out[name] = team
	end
	return out
end

function Body.teamNamed(name: string?): Team?
	if not name then
		return nil
	end
	local team = Teams:FindFirstChild(name)
	return if team and team:IsA("Team") then team else nil
end

-- One player's team, by NAME. Never by reference: comparing by name is the only form that survives a
-- Team being recreated (source A).
function Body.setTeam(player: Player, name: TeamName?, config)
	player.Team = Body.teamNamed(name)
	player.Neutral = name == nil
	-- AND THE OUTFIT FOLLOWS THE TEAM, at the same moment, from the same writer. A team swap does
	-- not always come with a respawn, and a driver still wearing a shooter's hat is two answers to
	-- one question -- this project's named failure mode. `config` is optional so a caller that does
	-- not have one (a spec asserting only the Team field) is unchanged.
	if config then
		Body.dress(player.Character, name, config)
	end
end

function Body.teamOf(player: Player): TeamName?
	local team = player.Team
	if not team then
		return nil
	end
	return (team.Name :: any) :: TeamName?
end

-- Where a player of this team stands, given the marker set and their index within the team.
-- Shooters take one post each, by index, and face +Z (up the drive). Drivers spread across the
-- driver start's X extent and face -Z (toward the line).
function Body.placementFor(markers, team: TeamName, index: number, config): CFrame?
	if team == "Shooters" then
		local posts = markers.posts
		if #posts == 0 then
			return nil
		end
		local post = posts[((index - 1) % #posts) + 1]
		local at = post.Position + Vector3.new(0, post.Size.Y / 2 + config.STAND_HEIGHT_STUDS, 0)
		return CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
	end

	local start = markers.driverStart
	if not start then
		return nil
	end
	local width = math.max(start.Size.X - 4, 1)
	local count = math.max(config.MAX_PLAYERS, 1)
	-- Spread deterministically across the pad, so two drivers never spawn inside each other.
	local fraction = ((index - 1) % count) / count
	local x = start.Position.X - width / 2 + width * fraction
	local at = Vector3.new(x, start.Position.Y + start.Size.Y / 2 + config.STAND_HEIGHT_STUDS, start.Position.Z)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, -1))
end

-- Respawns `player` and puts them where `cframe` says. Returns a function the owner can call to give
-- up waiting; `onPlaced(true/false)` is called exactly once.
function Body.place(player: Player, cframe: CFrame?, config, onPlaced: ((boolean) -> ())?)
	local finished = false
	local connection: RBXScriptConnection? = nil

	local function finish(ok: boolean)
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if onPlaced then
			onPlaced(ok)
		end
	end

	local function pivot(character: Model)
		-- DRESSED BEFORE THE EARLY RETURN, because a player who spawned with nowhere to stand is
		-- still a player of a team (M2.8d). This handler is the design's first call site: it is the
		-- one place that already knows a NEW character has arrived for a player whose team is set.
		Body.dress(character, Body.teamOf(player), config)
		if not cframe then
			finish(true) -- nowhere to put them: they spawned, and that is not a failure
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			-- The character exists but its root has not replicated yet. One wait, then try again.
			character:GetPropertyChangedSignal("PrimaryPart"):Wait()
		end
		if character.Parent then
			character:PivotTo(cframe)
			finish(true)
		end
	end

	-- CONNECTED BEFORE LoadCharacter, which is the whole point: the character does not exist when
	-- LoadCharacter returns, and a pivot on the old one moves a corpse.
	connection = player.CharacterAdded:Connect(function(character)
		task.spawn(pivot, character)
	end)

	local ok = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		finish(false)
		return
	end

	task.delay(config.PLACE_TIMEOUT, function()
		finish(false)
	end)
end

-- ------------------------------------------------------------------- 1.7b: tied to a tree
-- The one runtime container this system creates, and this module is its only writer. Created on
-- first use so a server that never punishes anybody never makes it.
function Body.driveMarkers(): Folder
	local existing = Workspace:FindFirstChild("DriveMarkers")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "DriveMarkers"
	folder.Parent = Workspace
	return folder
end

function Body.ropeName(userId: number): string
	return string.format("Rope_%d", userId)
end

-- Which tree to tie this player to: the nearest tagged tree, else the nearest post, else nil -- and
-- nil means DO NOT TIE. A nil anchor used as a CFrame would teleport the player to the origin, which
-- is the silent wrong answer this returns nothing instead of (design section 8.4).
function Body.anchorFor(markers, from: Vector3?): BasePart?
	local candidates = if #markers.trees > 0 then markers.trees else markers.posts
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in ipairs(candidates) do
		local distance = if from then (part.Position - from).Magnitude else 0
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- Where a tied player stands: on the side of the tree they came from, on the ground, facing it.
--
-- NOT the design's `TIE_OFFSET = CFrame.new(0, 0, 2.5)` (reviews/task-35/DESIGN_DELTA.md): the
-- arena's trees are the 8 x 24 x 8 corner pillars, so 2.5 studs along the tree's own +Z is INSIDE
-- the pillar and twelve studs up in the air, because a part's Position is its centre. The gap is
-- measured from the trunk's surface and the height from its base.
function Body.tiePointFor(tree: BasePart, from: Vector3?, config): CFrame
	local base = tree.Position.Y - tree.Size.Y / 2 + config.STAND_HEIGHT_STUDS
	local centre = Vector3.new(tree.Position.X, base, tree.Position.Z)
	local away = if from then Vector3.new(from.X - tree.Position.X, 0, from.Z - tree.Position.Z) else Vector3.zero
	local direction = if away.Magnitude < 1e-3 then Vector3.new(0, 0, 1) else away.Unit
	local radius = math.max(tree.Size.X, tree.Size.Z) / 2 + config.TIE_GAP_STUDS
	return CFrame.lookAt(centre + direction * radius, centre)
end

local function ropeFor(root: BasePart, tree: BasePart, userId: number, config, parent: Instance): Part?
	local from = root.Position
	local to = Vector3.new(tree.Position.X, from.Y, tree.Position.Z)
	local span = (to - from).Magnitude
	if span < 0.2 then
		return nil -- no rope to draw, and CFrame.lookAt on two equal points errors
	end
	local rope = Instance.new("Part")
	rope.Name = Body.ropeName(userId)
	rope.Shape = Enum.PartType.Cylinder
	-- A cylinder's axis is its X, so the length goes in X and the rotation below puts X along the
	-- rope: composing a 90-degree yaw onto lookAt maps the part's XVector onto the look direction.
	rope.Size = Vector3.new(span, config.ROPE_THICKNESS, config.ROPE_THICKNESS)
	rope.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
	rope.Color = config.ROPE_COLOR
	rope.Material = Enum.Material.Fabric
	rope.Anchored = true
	rope.CanCollide = false
	rope.CanQuery = false -- it must never stop a pellet or an aim ray
	rope.CastShadow = false
	rope.Parent = parent
	return rope
end

-- Ties `player` to `tree`. Returns true only if it actually happened, so the owner can count a miss
-- rather than believe a tie that never took. `parent` is where the rope goes (Workspace.DriveMarkers
-- in production; its own folder in a spec).
function Body.tie(player: Player, tree: BasePart, config, parent: Instance?): boolean
	local ok = Body.tieCharacter(player.Character, player.UserId, tree, config, parent)
	-- THE SECOND CALL SITE THE DESIGN NAMES: a re-tie. A tied player who presses Reset gets a new
	-- character and `Match.watchCharacter` re-ties it here; without this that character would be the
	-- one person in the drive wearing nothing. It is on the PLAYER wrapper and not on
	-- `tieCharacter`, because the team is a fact about the player and `tieCharacter` has only a
	-- userId -- the seam a spec uses so it never freezes the one live player.
	if ok then
		Body.dress(player.Character, Body.teamOf(player), config)
	end
	return ok
end

-- The same work against a Model rather than a Player, which is the seam a spec uses: a live spec must
-- not freeze and move the one real player in a Play session, because half the client suite is
-- standing in it (a spec that revoked the live gun broke exactly that, Task 34).
function Body.tieCharacter(character: Model?, userId: number, tree: BasePart, config, parent: Instance?): boolean
	if not character or not character.Parent then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not (root and root:IsA("BasePart")) then
		return false
	end

	if not held[userId] then
		held[userId] = {
			walkSpeed = humanoid.WalkSpeed,
			jumpHeight = humanoid.JumpHeight,
			jumpPower = humanoid.JumpPower,
		}
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0 -- for places on UseJumpPower; writing both costs nothing

	root.Anchored = true
	character:PivotTo(Body.tiePointFor(tree, root.Position, config))

	local folder = parent or Body.driveMarkers()
	local previous = folder:FindFirstChild(Body.ropeName(userId))
	if previous then
		previous:Destroy() -- one rope per player, never two (it is re-tied after a respawn)
	end
	ropeFor(root :: BasePart, tree, userId, config, folder)
	return true
end

-- Frees a tied player: the humanoid gets back exactly the numbers it had, the root is unanchored and
-- the rope is destroyed. Safe to call on somebody who was never tied.
function Body.untie(player: Player, parent: Instance?)
	Body.untieCharacter(player.Character, player.UserId, parent)
end

function Body.untieCharacter(character: Model?, userId: number, parent: Instance?)
	local saved = held[userId]
	held[userId] = nil
	if character and character.Parent then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and saved then
			humanoid.WalkSpeed = saved.walkSpeed
			humanoid.JumpHeight = saved.jumpHeight
			humanoid.JumpPower = saved.jumpPower
		end
		local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = false
		end
	end
	local folder = parent or Workspace:FindFirstChild("DriveMarkers")
	local rope = folder and folder:FindFirstChild(Body.ropeName(userId))
	if rope then
		rope:Destroy()
	end
end

-- After this, no table in this module is keyed by that user.
function Body.forget(userId: number)
	held[userId] = nil
end

function Body.tracked(): number
	local n = 0
	for _ in pairs(held) do
		n += 1
	end
	return n
end

-- Every live player, as the boar's world wants them: only DRIVERS scare boars, which is the
-- mechanic -- a shooter standing on a post must not push the boar back into the wood before it
-- reaches the line.
function Body.driverPositions(teamOf: (Player) -> TeamName?, service: any?): { { id: string, position: Vector3 } }
	local out = {}
	for _, player in ipairs((service or Players):GetPlayers()) do
		if teamOf(player) == "Drivers" then
			local character = player.Character
			local root = character and character.PrimaryPart
			if root then
				table.insert(out, { id = tostring(player.UserId), position = root.Position })
			end
		end
	end
	return out
end

-- EVERYTHING A BOAR CAN PERCEIVE, with what KIND each one is (task 118). A new function beside
-- `driverPositions` and deliberately not a change to it: that one answers "who is pushing, and who
-- may be tied", this one answers "what can a boar perceive". One predicate answering two unrelated
-- questions is a named cause of death of the previous project, and `Match.playerDrivers` and
-- `Penalty` keep reading the old one unchanged.
--
-- A SHOOTER STANDING ON A POST IS NOW PERCEIVABLE, and that is what makes Karen's central scene
-- possible: he is noticed at 25 studs and flushes the animal only at 15, so a boar can come down
-- the corridor to the line instead of turning back at the first man it can see. Whether it reacts
-- to him at all is `Boar.CONFIG.SENSE.ENABLED`'s decision, in the Brain, not this function's.
-- Design: docs/design/boar-behaviour.md section 8
function Body.boarStimuli(
	teamOf: (Player) -> TeamName?,
	service: any?
): { { id: string, position: Vector3, kind: string } }
	local out = {}
	for _, player in ipairs((service or Players):GetPlayers()) do
		local team = teamOf(player)
		local kind = if team == "Drivers" then "driver" elseif team == "Shooters" then "shooter" else nil
		if kind then
			local character = player.Character
			local root = character and character.PrimaryPart
			if root then
				table.insert(out, { id = tostring(player.UserId), position = root.Position, kind = kind })
			end
		end
	end
	return out
end

return Body
