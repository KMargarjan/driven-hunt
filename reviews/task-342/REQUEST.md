# Task 342 -- at most 24 animals alive, so the animals never lag the server

Task: 342
Round: 1
Base: e77e755a (main, #354)
Code commit: TBD

## PLAN (core quality protocol, step 0)

**(a) REAL LIFE.** A *Treiben* is beaten ONCE: the animals in a section either cross the shooting
line or break back through the beaters, and nothing comes back in. So the count of animals inside a
beaten section only ever FALLS once the push starts. `docs/design/grid-map.md` 9.2 puts the number
for one cell at **<= 24 live at the busiest instant** ("slot 12 releases nine today, so 24 is three
overlapping groups"), with `MAX_BOARS` 60 as the hard ceiling and **<= 4.0 ms/frame average,
<= 8.0 ms peak** for the boar runtime's server step. In our world the count only ever ROSE.

**(b) MEASURED NOW** -- her Forest Test, full 400 s drives, main e77e755a, probe
`<runs-dir>/342-arm.luau` + `342-step.luau` (`342-drive.sh <tag> <cell> 400`):

| cell | peak live | released | crossed W/C/E | boar stepMsAvg | stepMsMax | server hb p95 | client p95 | parts |
|---|---|---|---|---|---|---|---|---|
| C1 normal/split | **60** | 192 | 4/138/7 | **7.27 ms** | 258.7 | 36.35 ms | 33.92 ms | 1025 |
| D1 quiet/centre | **50** | 147 | 3/117/0 | **6.06 ms** | 130.1 | 36.47 ms | 33.84 ms | 850 |
| A2 busy/east | **60** | 184 | 8/123/11 | **8.01 ms** | 264.0 | 38.14 ms | 34.43 ms | 1055 |

Live climbs all drive and never falls back: C1 `47 @230s -> 59 @330s -> 50` for the last 70 s. It
agrees with the escalation (327h) and refutes nothing in the dispatch. The dial is ALREADY not
visible over a full drive: busy A2 released FEWER (184) than normal C1 (192), because A2 hit the
60 ceiling at 170 s and the ceiling then refused its releases.

**(c) TARGET.** peak live **<= 24** per drive, boar `stepMsAvg` **<= 4.0 ms** -- both design 9.2,
and 24 because that is three of the drive's own overlapping groups. `MAX_BOARS` 60 stays.

**(d) LEVER.** Two writers, both pasted from `grep -n`:

```
src/server/Boar/Brain.luau:2066:			intent.despawn = true          <- the ONE despawn decision
src/server/Boar/init.luau:8041:			self:_despawn(entry, index, intent.reason or "outOfBounds", position)
src/server/Boar/Brain.luau:848:		return "outOfBounds"           <- Brain:_outcome, the rule it reads
src/server/ForestTest/init.luau:3233:	local room = ceiling - runtime:count()   <- the release door (MAX_BOARS only)
src/server/Boar/init.luau:8062:		stats.stepMsMax = took         <- the counter, never reset
```

`Boar` (`src/server/Boar/`) already owns `_despawn` and `intent.despawn` and is required by both
`ForestTest` and `Match/Phase.luau`, so the out-of-play DECISION goes in `Brain:_outcome` -- no
second despawn path (L-104).

**(e) HOW IT WILL BE MEASURED AFTER.** The same `342-drive.sh` / `342-arm.luau` / `342-step.luau`,
same three cells, same 400 s, in her Forest Test at the code commit.
