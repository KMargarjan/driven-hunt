--!strict
-- Camera.Viewmodel: the only writer of the first-person weapon model under workspace.CurrentCamera.
--
-- It CLONES the Tool's Handle and never touches the original: ServerScriptService.Weapon.Hardware
-- stays the only writer of Tool Instances (docs/design/shotgun.md section 3.1). The clone is local,
-- unreplicated, and rebuilt only when the source part changes identity -- never per frame.
--
-- CanQuery = false on every part, and it is not optional: workspace.CurrentCamera is a child of
-- Workspace, so a client raycast -- including this system's own occlusion cast -- can hit a part
-- parented to the camera. The symptom would be a camera glued 1.2 studs behind the head.
--   Viewmodel pattern, the technique only and no code copied:
--   https://devforum.roblox.com/t/fps-using-viewmodels-the-improved-version-parts-2-out-of-3/1129877
--   (rokoblox5, 2021; source 4 of docs/research/2026-09-24-shotgun.md and section 7 D of the camera
--   design). That post uses the deprecated SetPrimaryPartCFrame; this uses PivotTo.
--
-- Design: docs/design/camera.md (sections 3.2, 5.5)
local Workspace = game:GetService("Workspace")

local Mode = require(script.Parent.Mode)

local Viewmodel = {}

local source: (() -> BasePart?)? = nil
local model: Model? = nil
local builtFrom: BasePart? = nil

function Viewmodel.setSource(fn: (() -> BasePart?)?)
	source = fn
	if not fn then
		Viewmodel.clear()
	end
end

-- Nil unless the viewmodel is actually in the camera (design section 9.2 item 6). The clone is kept
-- behind this so it is not rebuilt every time the player dips out of aim, but "is there a viewmodel"
-- means "is one on screen".
function Viewmodel.current(): Model?
	return if model and model.Parent then model else nil
end

function Viewmodel.clear()
	if model then
		model:Destroy()
		model = nil
	end
	builtFrom = nil
end

local function build(handle: BasePart): Model
	local made = Instance.new("Model")
	made.Name = "DrivenHuntViewmodel"

	local clone = handle:Clone()
	clone.Name = "Handle"
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false -- see the header: an occlusion ray must not hit our own viewmodel
	clone.CanTouch = false
	clone.Massless = true
	clone.CastShadow = false
	for _, child in ipairs(clone:GetChildren()) do
		if not child:IsA("Attachment") then
			child:Destroy() -- no scripts, no welds, no sounds: a shape and nothing else
		end
	end
	clone.Parent = made
	made.PrimaryPart = clone
	return made
end

-- Parents, poses or unparents the viewmodel for this frame. Below VIEWMODEL_SHOW_BLEND it is
-- UNPARENTED, not merely invisible, so a leak is visible on screen rather than hiding as a
-- transparent part (design section 10).
local cachedHandle: BasePart? = nil
local lastSourceCheck = 0

function Viewmodel.update(camCFrame: CFrame, blend: number, config)
	local cam = Workspace.CurrentCamera
	-- The source walks the character for a Tool, so it is asked four times a second rather than
	-- every frame (the pose below is what has to be per frame, and it is one PivotTo).
	local now = os.clock()
	if source and (now - lastSourceCheck > 0.25 or (cachedHandle and not cachedHandle.Parent)) then
		lastSourceCheck = now
		cachedHandle = source()
	elseif not source then
		cachedHandle = nil
	end
	local handle = cachedHandle

	if not cam or not handle or blend < config.VIEWMODEL_SHOW_BLEND then
		if model then
			model.Parent = nil
		end
		return
	end

	if not model or builtFrom ~= handle then
		Viewmodel.clear()
		model = build(handle)
		builtFrom = handle
	end

	local made = model :: Model
	if made.Parent ~= cam then
		made.Parent = cam
	end
	made:PivotTo(camCFrame * Mode.viewmodelOffset(Mode.ease(blend), config))
end

function Viewmodel.isParented(): boolean
	return model ~= nil and model.Parent ~= nil
end

return Viewmodel
