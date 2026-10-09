# The rifle's drawn lens disc (task 140-141), removed in task 142

**Why it went.** Karen, 2026-10-09 after playing the rifle: *"in front of scope when not aiming has
circle transperent it shouldn't be like that"*. Zoomed into her own carry frame it is unmistakable --
a pale grey-green faceted translucent cylinder stuck on the objective end of the scope, reading as a
plastic plug rather than glass. Task 141's own frame description had already called it *"a grey plug
on the ocular bell"* and done nothing about it.

It was added in task 140 because the model's lens node carries no base-colour texture at all
(`asset_prep` refuses it) and the scope was then often drawn as a FALLBACK BOX with a hollow end.
Task 141 fixed the fallback -- the four uploaded groups now really arrive -- so the disc was covering
a case that had stopped happening, and was visible in the case that always happens.

**Exactly what was removed**, from `src/shared/Rifle/Geometry.luau`:

```luau
local LENS_DIAMETER = 0.16
local LENS_THICK = 0.012

-- in Geometry.layout(), inside the returned frozen table:
	lens = {
		size = Vector3.new(LENS_THICK * k, LENS_DIAMETER * k, LENS_DIAMETER * k),
		at = Vector3.new(0, SCOPE_AXIS_Y * k, (SCOPE_OBJECTIVE_Z - LENS_THICK / 2) * k),
	},

-- in Geometry.pieces(), the last entry:
	{
		-- THE OBJECTIVE LENS, DRAWN. A Roblox Cylinder's axis is its own X, so the quarter turn
		-- lays it across the gun and the disc faces down the barrel.
		name = "Lens",
		group = "body" :: Gun.Group,
		size = at.lens.size,
		offset = CFrame.new(at.lens.at) * CFrame.Angles(0, math.rad(90), 0),
		color = Color3.fromRGB(150, 170, 190),
		material = Enum.Material.Glass,
		shape = Enum.PartType.Cylinder,
		reflectance = 0.15,
		transparency = 0.9,
	},
```

**To bring it back** (if a scope ever ships whose mesh really has no objective): paste both blocks
back and darken it -- `Color3.fromRGB(20, 26, 34)` with `transparency = 0.55` reads as glass with
something behind it, which the pale blue-grey at 0.9 never did. `SCOPE_OBJECTIVE_Z = -0.2081` and
`SCOPE_AXIS_Y` are still in the file; only the two lens constants went with it.
