--!strict
-- Bots.Rig: THE ONLY WRITER OF A BOT RIG'S INSTANCES, and of `Workspace.DriveBots` (rule 3). It
-- builds one R15 body, sets its properties, parents it, places it, and destroys it. It decides
-- nothing: how many there are is `Bots.Fill`'s, where they walk is `Bots.Lane`'s, when any of it
-- happens is the owner's, and what they WEAR is `Match.Body`'s and is reached through an injected
-- seam so there is one dressing path in this repo and not two.
--
-- THE BOUNDARY WITH `Match.Body` IS THE PLAYER (docs/design/bots.md section 3.2). `Body` is the only
-- writer of a PLAYER's character -- its team, its position, its freeze, its clothes and the one
-- `held` table keyed by userId. This module is the only writer of a BOT's. It never touches `held`
-- (a bot has no userId to key it with) and never calls `Body.place`, `Body.hold`, `Body.stand`,
-- `Body.tie` or `Body.dressWhenLoaded` -- all five take a `Player`.
--
-- THE RIG SOURCE IS INJECTED, the shape `Boar.setModelSource` and `Body.setAccessorySource` already
-- have: the default is the engine's own R15 builder and a spec hands in a fake body, so every spec
-- runs with no avatar service, no web call and no Play.
--   Players:CreateHumanoidModelFromDescription
--     https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescription
--
-- Design: docs/design/bots.md (sections 3.2, 11)
-- Note:   docs/research/2026-10-12-bots.md (sections 2.2, 2.5)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Rig = {}

Rig.FOLDER_NAME = "DriveBots"

-- THE DEFAULT SOURCE: one call is a complete R15 rig with a Humanoid, so there is no hand-built rig,
-- no `.rbxm` (banned) and no sixty-line model file. An EMPTY `HumanoidDescription` on purpose -- no
-- bundle, no clothing, nothing to fetch -- because `Match.Body.dress` paints the green and wears the
-- hat and the vest, and a described outfit would be a second answer to what a beater looks like.
local function defaultSource(description: HumanoidDescription, rigType: Enum.HumanoidRigType): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, rigType)
	end)
	if not ok or typeof(model) ~= "Instance" then
		return nil
	end
	return model :: Model
end

local source: (HumanoidDescription, Enum.HumanoidRigType) -> Model? = defaultSource

function Rig.setSource(fn: ((HumanoidDescription, Enum.HumanoidRigType) -> Model?)?)
	source = fn or defaultSource
end

function Rig.source(): (HumanoidDescription, Enum.HumanoidRigType) -> Model?
	return source
end

-- THE ONE RUN-TIME CONTAINER, created on demand under Workspace. `Workspace` is not Rojo-owned and
-- the harness compares the EDIT DataModel, so a rig built during Play cannot dirty a run -- exactly
-- as `Workspace.DriveMarkers`, `DriveScene`, `ForestMarkers`, `WeaponEffects` and `Boars` do not.
function Rig.folder(): Folder
	local existing = Workspace:FindFirstChild(Rig.FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Rig.FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

-- MAY YIELD. `CreateHumanoidModelFromDescription` is documented to load assets, so the owner keeps
-- this off its step loop and guards the result with an epoch (`Bots.step`). Returns nil rather than
-- erroring: a build that fails is a number in the report, not a dead drive.
function Rig.build(name: string): Model?
	local model = source(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	if model == nil then
		return nil
	end
	model.Name = name
	return model
end

-- WHAT A BOT'S BODY IS SET TO, and two of these are measurements rather than tidiness.
--
-- `CanQuery = false` ON EVERY PART, and the reason is this repo's own, stated the same way in
-- `Match.Scene`, `Match.Body` and `ForestTest.Markers`: *a prop that stops a pellet changes what the
-- shot hit, and what the shot hit is what the safety rule and the hit record read*. Three facts
-- become true at once with one property instead of a filter in three places -- a bot cannot be
-- credited a hit, cannot appear in the drive report, and cannot stop a shot that is otherwise legal.
-- `shootable = true` is the fallback if a humanoid turns out not to WALK with it off, and the
-- measurement is the Builder's to take (design section 11.3).
--
-- `CanTouch = false`: a body should not fire `Touched` at anything.
--
-- `DisplayDistanceType = None`: eight name tags over the stands is eight things Karen did not ask to
-- see.
function Rig.prepare(model: Model, config, walks: boolean): Humanoid?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = if walks then config.WALK_SPEED else 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0

	-- THE VENDOR'S OWN SENTENCE, taken as far as the outfit allows (Roblox, "Improve performance":
	-- *"Static NPCs that do not move generally have no need for the Humanoid class"*, and *"There is
	-- a performance cost to leaving certain HumanoidStateTypes enabled"*). The class has to stay --
	-- `Humanoid:AddAccessory` needs it and the outfit is `Body`'s -- so what goes is the WORK: a
	-- stander evaluates no state machine at all.
	if not walks then
		humanoid.EvaluateStateMachine = false
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanTouch = false
			if config.SHOOTABLE ~= true then
				part.CanQuery = false
			end
		end
	end
	return humanoid
end

-- WHERE IT STANDS. A stander is ANCHORED and a walker is not, and the anchor is the same measurement
-- `Body.holdCharacter`'s header records: a character's physics is owned by a client, so a
-- server-side pivot alone is a suggestion. Nothing else in the game owns a bot's physics, but a
-- stander on a post must not be nudged off it by anything, and anchoring is also what makes the
-- vendor's "static NPC" case cost nothing.
function Rig.place(model: Model, cframe: CFrame, anchored: boolean): boolean
	if model.Parent == nil then
		return false
	end
	local found = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not (found and found:IsA("BasePart")) then
		return false
	end
	local root = found :: BasePart
	if model.PrimaryPart == nil then
		model.PrimaryPart = root
	end
	root.Anchored = anchored
	model:PivotTo(cframe)
	return true
end

-- Where it is now, flat or not -- nil for a rig that has lost its root or its parent.
function Rig.positionOf(model: Model?): Vector3?
	if model == nil or model.Parent == nil then
		return nil
	end
	local found = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if found and found:IsA("BasePart") then
		return (found :: BasePart).Position
	end
	return nil
end

-- Destroys one rig. Idempotent.
function Rig.destroy(model: Model?)
	if model ~= nil then
		model:Destroy()
	end
end

-- Destroys the whole container. Returns whether there was one, so the owner can count it.
function Rig.clearFolder(): boolean
	local existing = Workspace:FindFirstChild(Rig.FOLDER_NAME)
	if existing == nil then
		return false
	end
	existing:Destroy()
	return true
end

return Rig
