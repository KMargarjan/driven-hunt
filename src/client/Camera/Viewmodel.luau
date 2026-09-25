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
--   Viewmodel pattern: https://devforum.roblox.com/t/how-to-make-a-viewmodel/1234567 (research
--   source 4 of docs/research/2026-09-24-shotgun.md; the idea, not the code)
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

function Viewmodel.current(): Model?
	return model
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
function Viewmodel.update(camCFrame: CFrame, blend: number, config)
	local cam = Workspace.CurrentCamera
	local handle = if source then source() else nil

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
