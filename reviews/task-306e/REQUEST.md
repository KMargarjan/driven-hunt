# Task 306 step B5: ISOLATION, THE SHOT

Task: 306e
Round: 2
Base: `task-306b4-paces` at `5bbab673`, merged with `origin/main` at `9bbfc71e`
Code commit: `17100e4f20b6ebe1425d2f8d751f0122758bc9da`

`[harness] PASS: 34/34 checks @ 17100e4f20b6ebe1425d2f8d751f0122758bc9da (clean tree) scope=all`
`test2`: N/A — no `TWO_PLAYER_PATHS` path in the diff (`src/server/Range/`, `src/shared/Range/`,
`src/server/Weapon/`, `src/server/Boar/`, `src/server/RangeBoot.server.luau`, three specs).

Design `docs/design/shooting-range-lobby.md` section 16 row **B5**, sections 4.3 / 5.3 / 9.2 / 9.3,
and section 12 **T13**. Six bodies share one corridor; `Cast.candidates` returns the eight nearest
the muzzle and `Rewind.impact` takes the nearest rewound one, so without a list a body the shooter
cannot see stops his bullet. No new cast and no second shot path: the 305/305b/305c seams
(`Weapon.addHistoryProvider`, `castWithRewind`, `Cast.candidates`) are reused as they ship.

## PLAN (core quality protocol step 0)

- **(a) REAL LIFE.** On a running-boar range each firer's target is his own: ISSF's 10 m running
  target is one silhouette crossing one 2 m opening per firer (research note
  `docs/research/2026-10-28-the-range-in-the-lobby.md`, source A).
- **(b) MEASURED NOW** (DEV, Play, `<runs-dir>/306b5-stage.luau` + `306b5-read.luau`): six trunks on
  one corridor, 24 studs apart in X, every one of them a candidate for every station's shot. One
  shared target before this step; `Range.ignoredFor` did not exist.
- **(c) TARGET.** Exactly ONE animal in one shot's world: his own, and only while it is inside his
  station's own 36-stud window — the same predicate the client mask will read at B6, so the animal
  is hittable exactly where it is drawn. T13: `Range.ignoredFor` ≤ 0.1 ms, asked at most twice a shot.
- **(d) LEVER.** `src/server/Weapon/init.luau`'s `ignoreFor` is the one writer of a shot's ignore
  list, at two call sites:
  `1835: local impact = castFn(origin, direction * range, ignoreFor(player))`
  `2620: ignore = ignoreFor(player, rewindSeconds),`
- **(e) HOW MEASURED AFTER.** The same two probes, plus `ServerStorage.DHLastHits` (task 309a's ring).

## What changed

1. **`RangeData.windowSpanFor` / `inWindow`** (`src/shared/Range/init.luau`) — the ONE predicate both
   sides read. Centred on each station's own mat, so it is the same span at all three distances.
2. **`Range.ignoredFor(player, rewindSeconds)`** (`src/server/Range/init.luau`) — the five targets
   that are not his, plus his own while it is outside its window **at the instant the rewind tests**
   (`targetPositionOf`, the same ring the rewound cast is judged against). Nobody at a station →
   empty, so a shot in the wood is untouched. `stats().ignoreCalls` counts the asks.
   **ROUND 1, FINDING 1 (fixed):** that instant is taken off `serverNow()` -- the clock
   `Runtime:cframeAt` stamps its ring with -- and NOT off `clockNow()`, which is `os.clock()` in the
   shipped wiring. A different epoch, so `Boar.sampleAt` refused every ask and the window was
   silently judged at the PRESENT position. `serverTime` is a new optional `Range.start` seam (nil
   is `Workspace:GetServerTimeNow()`), cleared on `stop`.
3. **`Weapon.setIgnoreProvider`** (`src/server/Weapon/init.luau`) — the eighth injected provider, in
   the shape the seven have. Unwired is bit-for-bit today's list; a provider that throws does not
   refuse the shot. `rewindSeconds` is hoisted so the shot and the list are measured at one instant.
4. **`Runtime:rootOf(id)`** (`src/server/Boar/init.luau`) + the `boars` view's `rootOf`
   (`RangeBoot`) — one trunk per target; the zone parts are welded under it, so one instance per
   animal is the whole exclusion.
5. **Wired once**, at `RangeBoot`, after `Range.start` succeeds.
6. **The merge's own semantic:** 308's new miss-gap case read `fake.only()` of SIX animals (it was
   written when `SPOT_COUNT` was 1) — now `fake.at(1)`.

## Merge (origin/main `9bbfc71e`), three conflicts

- `src/server/Range/init.luau`: HEAD added nothing in the hunk; main's `playerSpot` + `Range.look`
  (308 bug 1) kept whole. (309a's `DHLastHits` work is in `HitLog`/`Weapon` and auto-merged.)
- `docs/research/INDEX.md`: both rows kept, newest first.
- `ESCALATE.md`: both appended entries kept, main's first.

## Claims, and how to verify each

1. **The window is each station's own and the same at all three distances.** `range.spec`
   → "the window, the one predicate both sides read" / "is centred on each station's own mat…".
   Derived from `matPosition` and `laneCentre`, not transcribed.
2. **Both edges are inside, a nil X is outside.** Same describe, second case. `0/0` too.
3. **A player at station 3 gets exactly five roots, and his own the moment it leaves its window.**
   `range.spec` → `Range.ignoredFor` → "hides the five that are not his…". The second half is the
   in-case control for `inWindow`.
4. **The list holds a TRUNK and never a zone part.** Same case: the fake welds a `Zone` child under
   every trunk and the case asserts it is absent.
5. **It asks where his animal WAS, at `now - rewindSeconds`, ON THE RING'S OWN CLOCK.** `range.spec`
   → "asks where his animal was at the instant the rewind tests…": the owner's clock and the ring's
   are driven **50 000 s apart**; inside now / outside then → ignored; outside now / inside then →
   not; and the asked instant is asserted against the SERVER clock and explicitly NOT against the
   owner's. **FAIL FIRST (run):** with round 1's `clockNow()` back, `range.spec:3141` reads
   `0.800000` for `49999.800000` — `[harness] FAIL: 32/34 checks @
   c2d5acd740c93a984014fc7ce4be05c0fa468e7a (clean tree) scope=all`. Reverted; not in the branch.
6. **Nobody at a station, no reader, a reader that throws, a stopped range → empty, no error.**
   `range.spec` → "hides nothing from a man who is not at a station…".
7. **T13, measured.** `range.spec` → "is counted, and costs under a tenth of a millisecond a call":
   harness note `range B5: Range.ignoredFor 0.0028 ms/call over 200 calls` — 36× under the 0.1 ms
   budget. `ignoreCalls` moves by exactly 2 for two asks.
8. **T13's other half, live.** `weapon_shot.spec` → `Weapon.setIgnoreProvider`: one real
   `onFireRequest` asks the provider exactly **twice** — harness note
   `weapon_shot ignore list: trigger asked 2 time(s), rewind 0.000 s` (0.000 because `AIM_REWIND` is
   off in DEV; the aim ray's own ask is `nil`, the trigger's is a number).
9. **Unwired is today's game; the marker reaches the aim ray AND the trigger; a provider that throws
   does not refuse the shot.** Same case, same three arms, driven through the real handlers.
10. **A candidate in the ignore list cannot take the shot.** `weapon_rewind.spec` → "takes the
    candidate that is NOT in the shot's ignore list": the same aim, the same instant — loose → the
    other man's trunk (the defect), his trunk excluded → mine, both excluded → nothing.

## FAIL FIRST

- **Run.** `hide = not RangeData.inWindow(…)` forced to `false` →
  `[harness] FAIL: 32/34 checks @ cd740f74941b253690c9b7910e49f9bfdfbcba78 (clean tree) scope=all`,
  red at `range.spec:3106` (`6` → `5`) and `range.spec:3130`. Reverted; that commit is not in the
  branch.
- **By construction, argued by reading:** claims 9 and 10 each carry their own negative side in the
  same case (unwired vs wired; loose vs isolated), so no separate mutation can be attributed to them.

## LIVE PROOF, DEV (step 3). `RANGE` flag on for the run, cleared afterwards

Probes `<runs-dir>/306b5-stage.luau`, `306b5-fire3.luau`, `306b5-read.luau`. Instance facts only.

- **Staged:** shooter on mat 1 (1200, 4.1, 0). His own animal frozen at (1200, 3.5, 107), station
  2's frozen at (1200, 4.7, 67) — **gap to the line 0.000 studs**, 40 studs NEARER the muzzle. Both
  X = 1200, so both are inside station 1's window (1182..1218): two targets in one window.
- **A real `FireRequest` down that line** (the same remote `Weapon.Input.fire` sends):
  `#2 t=567.86s male id=Boar11 zone=chest local=(-0.10,0.03,-1.29) uv=(0.265,0.489) dist=105.8
  shotgun/Slug pellets=1 fatal=no` — his own animal, at 105.8 studs, **through** station 2's.
  Nothing of station 2's appears in the ring. (First reading, same shape: `#1 … id=Boar1 zone=chest
  … dist=105.8`.)
- **CONTROL, rule L** (`306b5-stage-control.luau`): his own animal moved 10 studs ACROSS (still in
  his window), station 2's left standing dead on the line. Same shot, `barrels=Spent/Live` so it was
  taken — `DHLastHits` reads **nil**. The body he cannot see does not answer.

## What I could not verify

- **A frame of the staged pair: NOT OBTAINABLE.** `ftplay.py capture` returns the live camera, and
  `src/client/Camera` re-asserts it within 0.3 s of a probe's write (read back at (1200, 5.69,
  −0.40) after asking for (1200, 6.6, −4)). `<runs-dir>/306b5-shooter-eye.png` — looked at — is a
  true firing-point frame: six boars on the lane beyond the berm, the shotgun viewmodel, 12 SLUG.
  `306b5-line2.png` — looked at — is the shooter's eye at station 1 looking downrange, and what
  fills it is **station 1's own treestand standing in the lane** (306c's recorded DEV deviation,
  `standFacing` turning WITH the row). Neither shows the two staged animals apart; the proof above
  is numeric, not pictorial.
- **Karen's place: nothing.** B8 is her place; this step is DEV only.
- **`rewindSeconds` live is 0.000** because `AIM_REWIND` is off in DEV, so the live run exercises the
  `at = nil` arm. The non-zero arm is proved by `range.spec` claim 5 only.
- **306a..306d must-fix for this step: none.** 306a (a)(b)(c) were closed at B2/B4; 306b(i),
  306a(g)(h), 306d(d) are named for B6.

## Round 1's notes

Taken in this round: `ignoreCalls`' comment now says it is a cost counter and not a count of
filtered shots; `weapon_shot.spec`'s no-subject arm no longer claims to prove the seam (it cannot —
the harness note is what says the live arm ran, and it did, at this commit).

Queued, not fixed: the `fake.roots` Folder is never destroyed (outside Workspace, so no cast sees
it); that arm is still not reported SKIPPED; `Range.positionOf` and 308's `playerSpot` are two
readers of one fact. The two sequencing notes (B5 without B6's mask excludes his own target on 40 of
76 lane studs while it is still drawn to him; nothing seen in Karen's place) are design section 16's
own order and B8's row.

## History, stated plainly

A `git reset --hard` taken to drop a throwaway mutation commit also dropped the pushed round-1
request commit and the Reviewer's round-1 `RESULT.md`. The request commit was **merged back**, not
force-pushed — no commit on this branch has been rewritten — and `RESULT.md` is restored verbatim
from the session transcript, trailer included (`85e757dc`, round 1, 57 turns, $4.57).
