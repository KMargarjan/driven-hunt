# Task 305b -- the live measurements, all in KAREN'S place (Forest Test, Play)

**Her overrides, left exactly as they were and NOT at the shipped defaults** (both rows are
`default = false`): `DHFlag_AIM_REWIND=true` and `DHFlag_RANGE=true`, plus the eight others already
on her ServerStorage. Nothing was set, cleared or restored by this session. Every number below is
read with the rewind ON; at the shipped default it is off and none of this path runs.

Instruments: `<runs-dir>/305b/cand.luau` (the live `Cast.candidates` over the flight's own step),
`305b/hist.luau` and `305b/trail.luau` (`ServerStorage.DHBoarHistory` / `DH305Rewind`, both written
by the LIVE code), `305/lag-srv.luau` + `305/lag3r-cli.luau` (client-drawn vs server, one clock),
and `305b/p-run-rifle.luau` / `p-run-slug.luau` / `z-run-rifle-nolead.luau` -- the trial rig, which
aims at THIS CLIENT'S RENDERED `ZoneChest` plus **the game's own `Ballistics.leadStuds`** for the
equipped row at the real range, and fires a real `FireRequest` from the client VM.

## 1. Every candidate cause the dispatch named, ruled in or out

| candidate | measurement | verdict |
|---|---|---|
| the range runtime's history answers nil | `DH305Rewind` = `why=rewound rewind=0.181 cands=1 back=3.32 hit=true`; `DHBoarHistory` `misses=0`, step 0.025-0.034 s, 96 samples = 2.9 s span | **RULED OUT** -- the rewind runs |
| ownership not pinned on her drawn model | `ft-stand.luau`: `Boar1 anchored=false auto=false owner=SERVER` | **RULED OUT** -- 97d67896 holds |
| no candidate found (sphere saturated in a thick wood) | `cand.luau`: root found on 2 of 11 flight steps, 17 parts in the sphere, cap 800 never reached | **RULED OUT** |
| a different interpolation delay in her heavier place | `lag3r-cli`: **0.205 s** then **0.185 s** (DEV was 0.176). The live effective look-back, `DH305Rewind` `eff=`, reads **0.182** and **0.190** | **REAL but small** -- R tracks L to ~0.005-0.02 s |
| the drawn mesh offset vs the trunk | the rig aims at the client's own `ZoneChest`, so a mesh offset cannot enter it | not the path |

**So the dispatch's premise -- "as if no rewind" -- is refuted, in numbers.** The rewind runs in her
place and its look-back matches her client's drawn lag.

## 2. What the hits actually depend on. Same build 2b77716e, same rig, same lane, back to back

| aim rule | RUN, rifle | zones |
|---|---|---|
| drawn chest + `Ballistics.leadStuds` (1.1-1.4 studs) | **9/10** | body x5, rear x2, chest x1, 1 miss |
| drawn chest, **zero lead** (the Playtester's rule) | **0/10** | -- |

That is the whole of the 1/10. The Playtester's brief said *zero lead*; 24 studs/s x the rifle's own
0.051 s flight to 125 studs is 1.2 studs, and the chest zone is narrow enough along the heading that
1.2 studs is off the front of it. At TROT (11 studs/s) the same rule costs 0.55 studs, which is why
the Playtester still hit 5/5 there with the dots sitting BODY/REAR instead of CHEST.

**The board's `MISS GAP 1.3 m behind` is not a measurement of the error.** 1.3 m = 4.3 studs =
0.18 s x 24, which is the view lag itself: the board reports the gap against the server's PRESENT
position, which is always one view lag ahead of what the shooter drew. Queued, not fixed here.

## 3. The one real defect found, and the fix

`Weapon.castWithRewind` read `Workspace:GetServerTimeNow()` at EVERY flight step, so everything
between the trigger and that step -- the upward trip, the wait for the next server Heartbeat --
became lead nobody can see. Measured on the trial rig, `testedAt - firedAt` (the instant the server
tested the animal, minus the trigger):

| cycle | build | anchor | testedAt-firedAt | ideal (= flightT - R) | hits, RUN rifle |
|---|---|---|---|---|---|
| 1 | 2b77716e | wall clock at the cast | -0.118 (n=5, spread 0.104-0.128) | -0.133 | 3/6 (hand lead 0.0476) |
| 2 | 5bc97c6e | trigger + the pellet's stepped `elapsed` | -0.119 (n=4) | -0.133 | 4/6 (hand lead 0.0476) |
| 3 | 14bbd363 | trigger + `Ballistics.timeToRange(travelled)` | **-0.126** (n=10, spread 0.111-0.135) | -0.133 | 7/10 (the game's own lead) |

Cycle 2 shows why the stepped `elapsed` is the wrong clock: it is quantised to the sub-step and read
0.061 s where the closed form says 0.047, so the lead the board PRINTS and the lead the server
DEMANDS were two different numbers. Cycle 3 makes them one function.

**The fix does not change the hit rate within this sample** (7/10 at `14bbd363` against 9/10 at
`2b77716e`, n=10 each -- one standard error of a binomial at p=0.8 is 0.13, so these are the same
number). It is kept because the arithmetic is strictly closer to the ideal and the variance it
removes is real; it is NOT claimed as the cause of anything Karen saw.

## 4. NOT PROVEN

- **The real-click path -- READ, NOT RUN, and it is the same ray.** `src/client/Weapon/Input.luau`,
  `Input.fire` sends exactly `origin = cframe.Position, direction = cframe.LookVector.Unit` off
  `Workspace.CurrentCamera`. The rig sends the same origin and a direction straight at the aim
  point, and the Playtester's tracker held the camera ON the drawn chest (their own gate: within
  12 px of the viewport centre). So the two rigs send the same ray and the 9/10-vs-1/10 gap is the
  **zero-lead rule**, measured at 0/10 on that build. This is a code reading, not a live run with
  a real click -- nobody has fired a real click on the FIXED build.
- **The lever, the semi-auto and buckshot**: nobody has fired them at a moving animal.
- **Any animal but the range's boar** -- no deer, no drive animal.
- **Shotgun SLUG at run**: 3 of 5 (one line never fired, one produced no impact). Below the 4/5 asked.
- **WALK and TROT on the fixed build**: not re-run.
- **The task's own stud criterion** -- plan (c), "the impact lands within 1.0 stud of the chest the
  client drew" -- is NOT measured on either build. What is reported is hit counts and
  `testedAt - firedAt`. The rig's `impact-drawn` column reads the chest ~0.6 s after the shot and
  is not that number.
- **`DH305At` is overwritten per rewound cast**, so for a MISS the probe reads the range-cap cast
  and not an impact cast. The cycle-3 row's n=10 mixes both; the seven hits are impact casts.
- **`eff = back / spd` reproduces `rewind` by construction** for a steadily-moving animal: it is
  evidence the ring can answer that far back, not an independent measurement of the look-back. The
  real comparison in that row is the shipped `FLIGHT_REWIND_BASE_SECONDS = 0.18` against the
  separately measured 0.185-0.205.
- **Rule 5 / Karen**: nobody has played this. No screenshot, no real click, and the whole path is
  behind `AIM_REWIND`, which ships OFF -- so this commit changes nothing she can judge until a
  separate commit lights the flag.
