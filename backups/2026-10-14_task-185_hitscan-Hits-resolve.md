# `Weapon.Hits.resolve` — the hitscan resolver, archived (Task 185)

Archived 2026-10-14. Last commit that had it: **`14138ad`** (branch `task-185-bullet-flight`, from
`main` at `2eedfce`). Lived in `src/server/Weapon/Hits.luau` from Task 23 (2026-09-24) until
Task 185.

## What it was

```luau
-- One cast per direction, every one of them given the same ignore list, unmodified.
function Hits.resolve(
	muzzle: Vector3,
	directions: { Vector3 },
	range: number,
	cast: CastFn,
	ignore: { Instance }
): { Impact }
	local impacts = {}
	for _, direction in ipairs(directions) do
		local impact = cast(muzzle, direction * range, ignore)
		if impact then
			impacts[#impacts + 1] = impact
		end
	end
	return impacts
end
```

One cast per pellet, the whole range, **in the trigger's own frame**.

## Why it is archived and not kept

Task 185 replaced it with `ServerScriptService.Weapon.Flight`: the shot is now a projectile the
server steps on `RunService.Heartbeat`, and each step casts only the **segment just travelled**, so
the hit is judged where the target is when the bullet gets there.

Karen, 2026-10-14 ~20:15: *"another thing it has to be real like in a life when I shoot in running
animal I need to aim a bit in front based on speed distance ect I wan to have that feeling"*, and
~20:20: *"same with s/s"*. Under this function a boar sprinting at `Boar.CONFIG.SPRINT_SPEED`
(38 studs/s) was hit wherever the reticle sat, and aiming ahead could only ever miss.

It is **removed** rather than left callable beside the stepper, because two functions in one folder
that both answer "where did the bullet go" is the exact failure `docs/PROJECT_CONTEXT.md` records:
*"Two systems wrote the creature's position. Most of the worst bugs were two correct pieces of code
disagreeing."* `docs/design/ballistics.md` section 2.1 states the same decision.

`Hits.targetOf` and `Hits.group` are **untouched**: `Hits.group` is still the one constructor of a
`HitReport`, still makes one per (shot, target), and still counts `pellets`.

## What it would take to roll back

Restore the function above, and in `src/server/Weapon/init.luau`'s `onFireRequest` replace the
`Ballistics.shotFor` / `launchDirection` / `flight:launch` block with the two lines it had:

```luau
local impacts = Hits.resolve(muzzle, Pattern.directions(ammo, aim, rng, row), range, castFn, ignore)
local reports = Hits.group(player, impacts, ammo, now, id)
```

…then drop the `Heartbeat` connection in `Weapon.start`, `onShotLanded`, and the `ShotLanded`
remote. The three ballistic numbers per ammo (`MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD`, `ZERO_STUDS`)
and the four `FLIGHT_*` system numbers become dead data, not errors.
