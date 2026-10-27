# Archived by task 293b: `Body.freezeReach` and `MODEL.REHOLD_LIMIT`

Removed from `src/server/Boar/Body.luau` and `src/server/Boar/init.luau` on 2026-10-27, because
each was a cause of Karen's *"deer error remains, after kill stands"*. Rule 7: nothing is deleted
without a note.

## `Body.freezeReach(speed, dt, epsilon)` -> `Body.freezeWindow(length, config)`

```lua
-- the window is whichever is larger: the fixed epsilon, or the distance this clip covers in this frame.
function Body.freezeReach(speed: number, dt: number, epsilon: number): number
	return math.max(epsilon, math.abs(speed) * dt)
end
```

WHY IT WENT. It measured the window with the LAST frame's step, so a 16 ms frame gave a 16 ms
window and the 300 ms frame after it stepped `TimePosition` clean past `Length`. A non-looped
`AnimationTrack` that passes its end STOPS, and a stopped track draws the rig's bind pose -- the
deer standing up inside its own carcass (measured on the real hind: 1.02-1.33 studs of drawn height
held, 3.85-4.94 in bind pose). The replacement is a FIXED width, 0.05 s, which catches every frame
down to 20 fps because samples are one frame apart.

## `MODEL.REHOLD_LIMIT = 3`

```lua
	-- HOW MANY TIMES ONE CARCASS MAY HAVE ITS DEATH POSE PUT BACK (task 293). A bound, not a
	-- measurement: `Body.shouldRehold` allows one repair per stop, and three is room for a stop
	-- nobody has seen yet without this ever becoming a per-frame writer.
	REHOLD_LIMIT = 3,
```

WHY IT WENT. Three repairs per carcass against `CARCASS_SECONDS = 120`: the 4th overrun inside one
carcass's life left the deer standing for the rest of it. Measured in the suite at main: **7110 of
7200 steps standing** across one carcass's life with an overrun every half second. The repair is
unbounded now. What keeps it from becoming a per-frame writer is not a count but the rule itself --
the state the repair produces (playing, weight 1, at the held frame) is the state
`Body.shouldRehold` refuses, asserted by the first case of the task-293 block in
`tests/server/boar_model.spec.luau`.
