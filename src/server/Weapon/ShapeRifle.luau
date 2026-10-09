--!strict
-- Weapon.ShapeRifle: THE WORLD RIFLE, as a piece list. Pure data, no Instances -- the sibling of
-- `Weapon.Shape`, which is the world shotgun, and the same contract: `pieces(row)` is walked
-- forwards by `Hardware.addParts` and backwards by `Hardware.removeParts`, so what the fallback gun
-- is made of is written down once.
--
-- THREE BOXES AND A TUBE, NOT THE SHOTGUN'S TEN. This is what another player sees when the rifle's
-- uploaded meshes have not loaded: enough that it reads as a scoped rifle at thirty studs, and
-- deliberately NOT the shotgun's parts list -- a wrong gun that measures perfectly is the failure
-- `docs/PROJECT_CONTEXT.md` opens with.
--
-- The proportions are the model's own, measured in the Handle's frame by `tools/gltf_split.py probe`
-- and written down in `Rifle.Geometry` (the FIRST-person gun). This file reads them from there
-- rather than re-typing them, so the two guns a player can see cannot drift apart.
--
-- Design: docs/design/rifle.md (section 6.2)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Geometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))

local ShapeRifle = {}

export type Piece = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType,
	reflectance: number?,
}

-- Every piece of the WORLD rifle, in build order. Pure.
function ShapeRifle.pieces(config): { Piece }
	local at = Geometry.layout(config)
	local look = (config and config.LOOK) or { barrel = Color3.fromRGB(58, 60, 64) }
	local lying = CFrame.Angles(0, math.pi / 2, 0) -- a Cylinder's length runs along its own X
	return {
		{
			name = "RifleStock",
			size = at.stock.size,
			offset = CFrame.new(at.stock.at),
			color = look.wood or Color3.fromRGB(104, 64, 38),
			material = Enum.Material.Wood,
			shape = Enum.PartType.Block,
		},
		{
			name = "RifleBarrel",
			-- The barrel as a tube rather than the action's whole box: at thirty studs the thing
			-- that says "rifle" is a long thin pipe with nothing under it.
			size = Vector3.new(at.action.size.Z, 0.075, 0.075),
			offset = CFrame.new(0, 0.12 * (at.total / 4.4), at.action.at.Z) * lying,
			color = look.barrel or Color3.fromRGB(58, 60, 64),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Cylinder,
		},
		{
			name = "RifleAction",
			size = Vector3.new(at.action.size.X, at.action.size.Y * 0.6, at.action.size.Z * 0.28),
			offset = CFrame.new(at.action.at.X, at.action.at.Y, at.bolt.at.Z),
			color = look.action or Color3.fromRGB(78, 79, 82),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Block,
		},
		{
			name = "RifleScope",
			size = Vector3.new(at.scope.size.Z, at.scope.size.Y * 0.62, at.scope.size.Y * 0.62),
			offset = CFrame.new(0, at.scopeAxisY, at.scope.at.Z) * lying,
			color = look.scope or Color3.fromRGB(42, 43, 46),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Cylinder,
		},
	}
end

-- WHERE THE EYE LOOKS. The same answer the drawn rifle gives, from the same module: the ocular lens.
function ShapeRifle.sight(config): CFrame
	return Geometry.sight(config)
end

function ShapeRifle.muzzleZ(config): number
	return Geometry.layout(config).muzzleZ
end

return ShapeRifle
