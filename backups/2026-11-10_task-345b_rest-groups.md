# Archived: the stocked wood — `REST.groups`, `stockWood`, `stepRest`, `stockStep` (task 345b, T2)

Rule 7: never delete. This is the note; the code is still in the tree and still runs, because
`PLACEMENT_IN_PLACE` is **off by default** and with it off the drive Karen plays today is unchanged.
The Director's decision D-2 of 2026-11-10: **the retirements happen at the flag flip.** When Karen's
OK flips the default, the four things below are deleted in that commit and this note is what records
what they were and why they went.

## What is retired, and by what

| Retired | Replaced by |
|---|---|
| `Data.REST.groups` — 36 animals in ten hand-written rows (`offsetX`, `laneOffset`, `northStuds`, `composition`, `note`) | `Placement.plan`, from the fifteen rows of `Data.SCHEDULE.drive` the dial keeps. The band, the lane offsets and the ten depths the table encoded are now derived: the bed is where the line will be at the moment the script says that group moves |
| `ForestTest.stockWood(now)` — one `spawnSounder` per row, on the first heartbeat of beater mode | `ForestTest.stepPlacement` / `ForestTest.materialise`, one group per Heartbeat, `leadSeconds` 20 before the line reaches it |
| `ForestTest.stepRest(now, spooked)` and its `state.restStocked` / `state.restTriedAt` latch | nothing. There is no stocking step: a record becomes a body on the drive's own clock |
| `Data.stockStep(stocked, triedAt, now, rest)` — "done" / "wait" / "stock" | nothing. A roster has no retry window, because it has no attempt that can be lost |
| `ForestTest.step`'s `if ForestTest.beaterMode() then return ForestTest.stepRest(...)` branch | one path for both roles (design 3.2) |

## Why

Two populations, two spawn paths, two sets of rules. A hunter's drive got `releaseLine`'s scheduled
groups, released 25–85 studs north of the road — inside the lane he is looking down, which is the
magic Karen named. A beater's drive got these 36, stocked in one heartbeat into the wood. So the
thing she asked for already existed in one of the two and not the other, and the two disagreed about
where an animal comes from.

`ESCALATE.md` 2026-11-10 ~04:30 measured the cost of the split: *"36 > 24 with no drive in it at
all"*, live jumping 9 → 60 in one ten-second sample at the second drive's opening.

Keeping the table beside the roster would be a **second answer to "where does a group lie up"**,
which is rule 3's whole subject.

## What is NOT retired

`ForestTest.restSpot`, `restSpotOk`, `restSeenFromLane`, `Data.restPoint`, `laneLookPoint`,
`offLaneStuds`, `restPasses`, `restPassTakes`, `restZonesOf` and every number of `Data.REST` but
`groups` and `stockRetrySeconds`. They are **the searcher**, and the roster uses all of it: T2 hands
it one band override (`Placement.searchBand`) and asks the same question. `state.rest`,
`ForestTest.restAlive` and `restReport` stay for the flag-off path and go with the branch.

Design: `docs/design/animal-placement.md` sections 3.2, 4.3, 4.4, 8.2, 17.
Note: `docs/research/2026-11-10-animal-placement.md`.
