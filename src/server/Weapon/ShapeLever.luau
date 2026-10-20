--!strict
-- Weapon.ShapeLever: THE WORLD LEVER RIFLE, as a piece list. Pure data, no Instances -- the sibling
-- of `Weapon.Shape` (the world shotgun) and `Weapon.ShapeRifle`, and the same contract:
-- `pieces(row)` is walked forwards by `Hardware.addParts` and backwards by `Hardware.removeParts`,
-- so what the fallback gun is made of is written down once.
--
-- FOUR BOXES, AND THE FOURTH IS THE WHOLE POINT. This is what another player sees when the uploaded
-- meshes have not loaded, at the thirty studs the drive is fought at: a stock, a long thin barrel, a
-- receiver -- and a LOOP under the wrist, which is the one silhouette cue that says *lever* and not
-- *bolt*. Without it this gun and the Rigby are the same three boxes, and a wrong gun that measures
-- perfectly is the failure `docs/PROJECT_CONTEXT.md` opens with.
--
-- NO SCOPE TUBE. This rifle has iron sights on a rail and no glass, so there is nothing to draw and
-- no `sightKind` branch to make -- unlike `ShapeRifle`, which carries one because its two rows
-- disagreed about the tube.
--
-- The proportions are the model's own, measured in the Handle's frame by `tools/gltf_split.py probe`
-- and written down in `Lever.Geometry` (the FIRST-person gun). This file reads them from there
-- rather than re-typing them, so the two guns a player can see cannot drift apart.
--
-- Design: docs/design/lever-rifle.md (section 5.4)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Geometry = require(ReplicatedStorage:WaitForChild("Lever"):WaitForChild("Geometry"))

local ShapeLever = {}

export type Piece = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType,
	reflectance: number?,
}

-- Every piece of the WORLD lever rifle, in build order. Pure.
function ShapeLever.pieces(config): { Piece }
	local at = Geometry.layout(config)
	local look = (config and config.LOOK) or { barrel = Color3.fromRGB(150, 152, 156) }
	local lying = CFrame.Angles(0, math.pi / 2, 0) -- a Cylinder's length runs along its own X
	return {
		{
			name = "LeverStock",
			size = at.stock.size,
			offset = CFrame.new(at.stock.at),
			-- GREY LAMINATE, NOT WALNUT -- an 1895 SBL's stock is layered birch. `Wood` is still the
			-- right material: laminate is wood, and it is not shiny.
			color = look.wood or Color3.fromRGB(76, 74, 72),
			material = Enum.Material.Wood,
			shape = Enum.PartType.Block,
		},
		{
			name = "LeverBarrel",
			-- The barrel as a tube rather than the action group's whole box: at thirty studs the
			-- thing that says "rifle" is a long thin pipe. The group spans the barrel AND the
			-- receiver, which is why the receiver is its own box below.
			size = Vector3.new(at.action.size.Z, 0.075, 0.075),
			offset = CFrame.new(0, 0.12 * (at.total / 4.0), at.action.at.Z) * lying,
			color = look.barrel or Color3.fromRGB(150, 152, 156),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Cylinder,
		},
		{
			name = "LeverAction",
			size = Vector3.new(at.action.size.X, at.action.size.Y * 0.6, at.action.size.Z * 0.30),
			-- Placed from the LEVER's own z, not the action group's: the group's centre is a stud
			-- out along the bore because it holds the barrel, and the lever hangs under the
			-- receiver by construction. The same correction `Rifle.Geometry`'s magazine comment
			-- records, which was measured on screen in task 142.
			offset = CFrame.new(at.action.at.X, at.action.at.Y, at.lever.at.Z),
			color = look.action or Color3.fromRGB(168, 170, 173),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Block,
		},
		{
			-- THE LOOP. It is drawn CLOSED and it does not move: `Hardware` builds the world gun and
			-- the world gun has no cycle animation -- only the first-person viewmodel swings
			-- (`Lever.Geometry.leverThrow`). What this box buys is the silhouette.
			name = "LeverLoop",
			size = Vector3.new(at.lever.size.X, at.lever.size.Y, at.lever.size.Z * 0.5),
			offset = CFrame.new(at.lever.at),
			color = look.lever or Color3.fromRGB(168, 170, 173),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Block,
		},
	}
end

-- WHERE THE EYE LOOKS. The same answer the drawn gun gives, from the same module: the front blade.
function ShapeLever.sight(config): CFrame
	return Geometry.sight(config)
end

function ShapeLever.muzzleZ(config): number
	return Geometry.layout(config).muzzleZ
end

return ShapeLever
