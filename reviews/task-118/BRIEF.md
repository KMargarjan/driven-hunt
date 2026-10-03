# Task 118 brief: boar behaviour (Director, carrying Karen's decisions)

Written 2026-10-03 by the Director for the Architect's design run (`tools/architect.sh design boar-behaviour --task 118`).
This brief overrides anything older in `docs/`, `TASKS.md` or `docs/design/boar-ai.md` where they disagree.

## Karen's words (verbatim, 2026-10-03)

> "imagine they on easy, then see dog or person spook them they run (we will improve how they run where) then comes line to hunter it can be they relaxed if hunter doesnt move but once move it start to run or turn around and go another direction, so after shoot they will start sprint
> and they usually do one line each after another or mixed like in real life"

> "so my point is we need to fix one boar 100% then move to anothers"

Approved order: Task 116 the shot and the death (merged), Task 117 the calm boar (in review), **Task 118 this behaviour**, then the female and the cub.

## Decisions already taken (do not reopen)

1. **A standing hunter is noticed by a calm boar at about 25 studs; a moving hunter at about 60 studs.** (Karen: "agree".) Numbers are data, tunable live.
2. **Panic spreads through the sounder.** When one member is spooked, the whole group runs together. (Karen: "spreading agree with you".)
3. **One boar first.** The behaviour must work for a single boar and for a sounder of the male model; the female/cub come later on the same skeleton.
4. **The calm repertoire (Task 117) is the IDLE state's inside** and stays: stand, graze, root, smell, walk. Task 118 decides when IDLE is left, not what IDLE draws.
5. **The body stays the body:** the physics box, hit zones, wounds, death types and sounds of Tasks 115–116 do not change. `Boar.Body` stays the only writer of boar instances; the Brain stays the only writer of boar state.
6. **Everything ships behind `BOAR_MODEL`** (born OFF, already exists) unless the design shows the behaviour is independent of the drawn model; if it is, a separate flag born OFF.

## What the design must contain

1. **The states and transitions** from Karen's scene: calm (IDLE + activities) → alert (head up, looking at the cause, listening — uses the `smell` / head-up clip) → spooked/flee (by a dog, a driver, a person on foot) → approaching the shooter line (relaxed, trotting, in line) → reacting to a hunter who moves inside 60 studs (turn away and go another direction, or break into a run) → sprint after a shot is heard (any shot within an audible radius, not only a hit) → wounded/crippled/down as today.
2. **Perception, as ONE function** (the existing "who is a threat" seam in `boar-ai.md` §4): what a boar sees and hears, by distance, the hunter standing vs moving (a speed threshold on the character), drivers and dogs as spooking sources, a shot as a sound event with a radius. Line of sight only if it is cheap and already available; say which.
3. **Sounder movement:** single file (each member follows the one ahead at a spacing) or mixed (loose group), chosen per sounder; panic spreading with a short delay member to member so it reads.
4. **"Where they run"**: Karen said "we will improve how they run where" — keep the existing route-to-exit logic; only define the hooks so a later task can improve routing.
5. **Numeric targets**, all data: 25 / 60 studs, the moving-hunter speed threshold, alert duration, panic delay per member, sprint duration after a shot, the audible radius of a shot, spacing in single file.
6. **How it is tested** with one player: each transition reachable by parameter AND by a real stimulus in a Play session (a character standing / moving at a distance, a shot fired), plus what a screenshot must show.
7. **Owner table rows** for anything new, and what `docs/design/boar-ai.md` sections this supersedes.
8. **Open decisions**: only ones that need Karen's taste. Everything else, decide.

## Out of scope

Dogs as agents (only "a dog spooks a boar" as a perception source if dogs exist; if not, drivers and people only), the map, new animations beyond the published clips (list any the design would want; the Director can publish from RedDeer's 74), the female and the cub, flipping `BOAR_MODEL`'s default.
