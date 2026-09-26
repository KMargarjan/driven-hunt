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
-- Design: docs/design/drive.md (sections 5.1, 5.3, 6.4, 8.4)
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
function Body.setTeam(player: Player, name: TeamName?)
	player.Team = Body.teamNamed(name)
	player.Neutral = name == nil
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
	return Body.tieCharacter(player.Character, player.UserId, tree, config, parent)
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

return Body
