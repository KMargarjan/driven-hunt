--!strict
-- Weapon.Shapes: weapon id -> the WORLD gun's piece list. The server-side twin of
-- `Weapons.geometry(id)`, which maps the same ids to the FIRST-PERSON geometry.
--
-- WHY TWO MAPS AND NOT ONE. `Weapon.Shape` and `Weapon.ShapeRifle` are server modules
-- (`ServerScriptService.Weapon.*`) and `Weapons` is a shared one, and a shared module may not
-- require a server module -- it would not exist on a client. So each map lives on the side that can
-- see its own modules, and both are keyed by exactly the same ids.
--
-- Shallow-frozen ON PURPOSE: `Shotgun.deepFreeze` recurses into table values, and these values are
-- other modules' own tables, which are not this module's to freeze.
--
-- Design: docs/design/rifle.md (section 6.2)
local Shape = require(script.Parent.Shape)
local ShapeRifle = require(script.Parent.ShapeRifle)

local Shapes = {}

Shapes.BY_ID = table.freeze({
	shotgun = Shape,
	rifle = ShapeRifle,
})

-- `for_` rather than `for`, which is a Luau keyword. A weapon this map does not know gets the
-- shotgun's shape, which is what every caller written before the rifle means.
function Shapes.for_(id: string?): any
	if type(id) == "string" and (Shapes.BY_ID :: any)[id] ~= nil then
		return (Shapes.BY_ID :: any)[id]
	end
	return Shape
end

return Shapes
