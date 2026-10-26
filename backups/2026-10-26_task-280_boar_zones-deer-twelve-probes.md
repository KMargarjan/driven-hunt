# Archived: `boar_zones.spec`'s twelve fixed deer probes (task 280, 2026-10-26)

Rule 7. Removed from `tests/server/boar_zones.spec.luau`, where it had stood since task 223
round 2. Replaced by `tests/server/deer_hitbox.spec.luau` plus one case in the same describe
("answers a real ray at every one of its own zone boxes, on every kind").

## Why it was removed

The table was twelve points written as **fractions of the animal's own box**, and its own comment
says why:

> THE POINTS ARE IN THE ANIMAL'S OWN FRACTIONS and not in studs, so one table drives all three:
> a fraction of its own `BODY_SIZE` is the same place on every size of the same animal.

That is true of a **size** and false of a **shape**, and task 280 measured the difference. The
stag's twelve shot volumes taken to the hind's scale (0.8553) leave **131** cells of air on her
drawn mesh, and at the calf's (0.495) **312** of its 649 answering rays are air -- because
`Red_Deer_NoAlpha`, `Red_Deer_Doe_NoAlpha` and `Red_Deer_Calf_NoAlpha` are three models and not
one model at three sizes. So each kind now carries its own boxes (`Boar.CONFIG.KINDS.hind.zones`,
`.calf.zones`) and one fraction table names a different part of each animal.

The case also asserted `clearance > 0` -- how far the zone part beat the **bare trunk** by. A
deer's trunk now has `CanQuery = false` (`SPECIES.reddeer.ZONES.TRUNK_HITTABLE`), so it is on no
ray and there is nothing to tie with; that measurement answers `math.huge` for every deer ray and
can no longer discriminate.

## What it was

```lua
local DEER_PROBES = {
    -- { name, local point as a fraction of the deer's own box, from, want }
    { "the skull from the front", Vector3.new(0, 0.566, -0.388), Vector3.new(0, 0, -1), "head" },
    { "the skull from the flank", Vector3.new(0, 0.566, -0.388), Vector3.new(1, 0, 0), "head" },
    { "the skull from above", Vector3.new(0, 0.566, -0.388), Vector3.new(0, 1, 0), "head" },
    { "the chest from the near flank", Vector3.new(0, 0.255, -0.142), Vector3.new(1, 0, 0), "chest" },
    { "the chest from the far flank", Vector3.new(0, 0.255, -0.142), Vector3.new(-1, 0, 0), "chest" },
    { "the chest from above", Vector3.new(0, 0.255, -0.142), Vector3.new(0, 1, 0), "chest" },
    { "the rump from the near flank", Vector3.new(0, 0.231, 0.353), Vector3.new(1, 0, 0), "rear" },
    { "the rump from the far flank", Vector3.new(0, 0.231, 0.353), Vector3.new(-1, 0, 0), "rear" },
    { "the rump from behind", Vector3.new(0, 0.231, 0.353), Vector3.new(0, 0, 1), "rear" },
    { "the rump from above", Vector3.new(0, 0.231, 0.353), Vector3.new(0, 1, 0), "rear" },
    { "the legs from the near flank", Vector3.new(0, -0.302, 0.028), Vector3.new(1, 0, 0), "legs" },
    { "the legs from the far flank", Vector3.new(0, -0.302, 0.028), Vector3.new(-1, 0, 0), "legs" },
}
```

and the case that walked it:

```lua
it("answers twelve real rays with the zone its geometry claims", function()
    local box = trunk.Size
    for _, probe in ipairs(DEER_PROBES) do
        local point = Vector3.new(probe[2].X * box.X, probe[2].Y * box.Y, probe[2].Z * box.Z)
        local zone, _instance, clearance = zoneAt(point, probe[3], 20)
        -- Named in the failure, so a red line says WHICH ray on WHICH animal.
        if zone ~= probe[4] then
            error(string.format("%s: %s answered %s, wanted %s", kind, probe[1], tostring(zone), probe[4]), 0)
        end
        expect(zone).to.equal(probe[4])
        -- PROUD, not flush: two coincident faces at one ray distance is a coin toss, which is
        -- the fault round 2 of task 116 removed on the boar.
        expect(clearance > 0).to.equal(true)
    end
end)
```

## What it could never see, and this is the point

Nine of those twelve points sit on a box. A ray fired at a box's own centre answers that box's
zone whether or not the box is on the **animal**, so the whole table passed while
`SPECIES.reddeer.ZONES` held the air under the deer's neck and the air between its legs. Karen,
2026-10-26, on a frozen broadside hind at ~28 m: *"wrong I hit the chest shows outside"*. The
replacement compares every ray against the DRAWN MESH, which is the only instrument that is not
the box under test.
