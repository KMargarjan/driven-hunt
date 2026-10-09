# Archived: the line-level "once across, they run away" speed-up (task 139 round 3)

CLAUDE.md rule 7. Removed from `ForestTest.stepLines` (and `line.crossed` with it) because the
Reviewer proved it UNREACHABLE: task 139's permanent-exit filter (`Line.stillInFile`) drops a member
on `status.position.Z - (Data.roadZ(X) - halfWidthStuds) < 0`, which is the SAME inequality this rule
tested on the leader, and the filter runs first in the same step. So `line.crossed` could never
become true and nobody was ever sped up: Karen's *"and they run away when cross the road"* had no
code left.

It is replaced by `Line.crossedOut` plus one `Runtime:spook` on the step a member leaves the file
for having crossed -- per animal instead of per line, and through the one door a fright comes
through, so the Brain owns the heading (south, `field.exitZ`), the pace, the herd-mates it alarms and
the despawn.

```lua
		-- ONCE ACROSS, THEY RUN AWAY. Karen: *"once they in another side of road they run away"*.
		if not line.crossed and at.Z < Data.roadZ(at.X) - Data.ROAD.halfWidthStuds then
			line.crossed = true
			line.speed = boarConfig().PACE.RUN_SPEED
			line.baseSpeed = boarConfig().PACE.RUN_SPEED
		end
```

...and the field it latched on, in `releaseLine`'s line record:

```lua
				crossed = false,
```
