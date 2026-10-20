--!strict
-- Weapon.ShapeSemiAuto: THE WORLD SEMI-AUTOMATIC SHOTGUN, as a piece list. Pure data, no Instances
-- -- the sibling of `Weapon.Shape` (the world side-by-side), `Weapon.ShapeRifle` and
-- `Weapon.ShapeLever`, and the same contract: `pieces(row)` is walked forwards by
-- `Hardware.addParts` and backwards by `Hardware.removeParts`, so what the fallback gun is made of
-- is written down once.
--
-- FIVE BOXES, AND THE FIFTH IS THE SILHOUETTE CUE. This is what another player sees when the
-- uploaded meshes have not loaded, at the thirty studs the drive is fought at: a stock, a long
-- barrel, a receiver, the fat FORE-END that a gas gun wears over its tube -- and the SIGHT standing
-- up on the rail, which is the one cue at that distance that says this is not the side-by-side.
-- Without it this gun and the Rigby are the same three boxes, and a wrong gun that measures
-- perfectly is the failure `docs/PROJECT_CONTEXT.md` opens with.
--
-- NOTHING HERE MOVES. `Hardware` builds the world gun and the world gun has no cycle animation --
-- only the first-person viewmodel moves the bolt and the tray. What these boxes buy is the shape.
--
-- NO DOT EITHER, and that is deliberate rather than an omission: the red dot is a 3 mm emissive ball
-- for the man holding the gun, and at thirty studs on somebody else's rifle it would be a floating
-- speck of light. `Geometry.pieces` draws it; this does not.
--
-- The proportions are the model's own, measured in the Handle's frame and written down in
-- `SemiAuto.Geometry` (the FIRST-person gun). This file reads them from there rather than re-typing
-- them, so the two guns a player can see cannot drift apart.
--
-- Design: docs/design/semiauto-shotgun.md (section 5.4)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Geometry = require(ReplicatedStorage:WaitForChild("SemiAuto"):WaitForChild("Geometry"))

local ShapeSemiAuto = {}

export type Piece = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType,
	reflectance: number?,
}

-- Every piece of the WORLD semi-automatic shotgun, in build order. Pure.
function ShapeSemiAuto.pieces(config): { Piece }
	local at = Geometry.layout(config)
	local look = (config and config.LOOK) or { barrel = Color3.fromRGB(42, 43, 47) }
	local lying = CFrame.Angles(0, math.pi / 2, 0) -- a Cylinder's length runs along its own X
	return {
		{
			name = "SemiAutoStock",
			size = at.stock.size,
			offset = CFrame.new(at.stock.at),
			color = look.wood or Color3.fromRGB(111, 73, 60),
			material = Enum.Material.Wood,
			shape = Enum.PartType.Block,
		},
		{
			name = "SemiAutoBarrel",
			-- The barrel as a tube rather than the group's whole box: at thirty studs the thing
			-- that says "shotgun" is a long pipe. The group spans the barrel AND the fore-end,
			-- which is why the fore-end is its own box below.
			size = Vector3.new(at.barrel.size.Z, 0.075, 0.075),
			offset = CFrame.new(0, 0.12 * (at.total / 4.9), at.barrel.at.Z) * lying,
			color = look.barrel or Color3.fromRGB(42, 43, 47),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Cylinder,
		},
		{
			-- THE FORE-END, and it is the gas gun's own silhouette: a fat wooden tube under the
			-- barrel's rear half, covering the piston and the magazine. The side-by-side has
			-- nothing there and the two rifles have a thin stick. Placed from the MEASURED
			-- fore-end span rather than the barrel group's centre, which is a stud out along the
			-- bore because that group also holds the barrel.
			name = "SemiAutoForeEnd",
			size = Vector3.new(at.barrel.size.X, at.barrel.size.Y * 0.62, 1.25 * (at.total / 4.9)),
			offset = CFrame.new(0, 0.01 * (at.total / 4.9), -0.525 * (at.total / 4.9)),
			color = look.wood or Color3.fromRGB(111, 73, 60),
			material = Enum.Material.Wood,
			shape = Enum.PartType.Block,
		},
		{
			name = "SemiAutoAction",
			size = Vector3.new(at.action.size.X, at.action.size.Y * 0.7, at.action.size.Z),
			offset = CFrame.new(at.action.at),
			color = look.action or Color3.fromRGB(71, 69, 69),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Block,
		},
		{
			-- THE SIGHT ON ITS RAIL. The one box here that is not on any other gun in the game, and
			-- the reason this list has five: a lump standing proud of the receiver is what a red dot
			-- looks like from across a drive.
			name = "SemiAutoSight",
			size = at.sight.size,
			offset = CFrame.new(at.sight.at),
			color = look.sight or Color3.fromRGB(69, 70, 70),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Block,
		},
	}
end

-- WHERE THE EYE LOOKS. The same answer the drawn gun gives, from the same module: the dot's plane.
function ShapeSemiAuto.sight(config): CFrame
	return Geometry.sight(config)
end

function ShapeSemiAuto.muzzleZ(config): number
	return Geometry.layout(config).muzzleZ
end

return ShapeSemiAuto
