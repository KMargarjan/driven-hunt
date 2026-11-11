# Task 345c (T3): "never in view" as a predicate and a counter

Task: 345c
Round: 1
Base: main (`5bb69c40`, #362)
Code commit: `ea0cbbb789918ef9a212c8f369f68b657e91bcd2`

`[harness] PASS: 34/34 checks @ ea0cbbb789918ef9a212c8f369f68b657e91bcd2 (clean tree) scope=all`

`test2` **N/A**: no `TWO_PLAYER_PATHS` path is touched (`src/server/ForestTest/`,
`src/shared/ForestTest/`, `src/server/Boar/Body.luau`, `src/client/Camera/`, `tests/`), and
`docs/design/animal-placement.md` section 17 says the one-player line is the gate for all six tasks.

**What changed.** T3 of the design's section 17, exactly as sections 6, 7, 8 and 13 write it:
`ForestTest.bedHidden` (the ray), `Placement.clearOfEyes` wired in at the one bed searcher,
`placementStats().inView/rays` beside `searches` and on the `DHForestPlacement` probe attribute,
`ModelStreamingMode = Atomic` on the drawn animal, and `tests/client/animal_placement.spec.luau`.
Plus the Director's frame instrument: `Camera.ProbeCamera`, a Studio-only held CFrame read inside
the client camera's one owner. `docs/design/` is unchanged.

**Deviation, one, and it is a place and not a number.** The design's T3 row says
`ModelStreamingMode = Atomic` *"in `Boar.Body.create`"*; `create` builds a Part and the drawn
**Model** is born in `Body.attachVisual`, so the property is set there — the only line in the repo
where an animal Model is created. Design section 7.2's own wording (*"every animal model"*) is what
is implemented.

## PLAN (core-quality step 0, written at request time and not before the edit — said plainly)

(a) **REAL LIFE:** a beaten wood holds its game before the line enters it; driven game is found, not
conjured. (b) **MEASURED NOW:** at the merge base, flag ON in C1, the drive reported `9 searches` and
no sight test at all — `345b-R3-ON-C1-console.txt`. (c) **TARGET:** `inView = 0` with `rays > 0` over
a live drive in two cells (design 12.2). (d) **LEVER:** `ForestTest.bedSpot` →
`ForestTest.bedHidden` → `Placement.clearOfEyes` + `Workspace:Raycast`; the counters are written at
`state.placementRays`/`state.placementInView` in `src/server/ForestTest/init.luau`. (e) **HOW
MEASURED AFTER:** the same instrument — `ServerStorage.DHForestPlacement`, read by
`<runs-dir>/345b-arm.luau` every 2 s.

## Claims

1. **Nothing is bedded where a player can see it, and the rule is two halves in one order.**
   `ForestTest.bedHidden`: `Placement.clearOfEyes` per eye first (a refusal names the player), then
   one ray per eye. Verify: *"refuses inside the reach by arithmetic, before it spends a ray"* and
   *"spends one ray per eye, and calls a bed in clear air SEEN"* in `forest_placement.spec`.
2. **The ray decides, and it is the measured one.** `ForestTest.seenFromEye` is
   `restSeenFromLane`'s ray with the origin at a player's head: `RespectCanCollide = true`, terrain
   included, `Data.characterOf` means a body is not a screen, and the observer's own character is
   excluded because the ray starts inside its head. Verify: *"calls the same bed HIDDEN behind
   something a bullet would stop"* — one Part between eye and bed flips the answer, and the same Part
   under a Humanoid flips it back.
3. **L-093, RUN at this code commit** (`<runs-dir>/345c-L093.txt`, one full harness run with both
   producers deleted: `Placement.clearOfEyes` replaced by `return true, math.huge` AND the ray loop
   cut out of `bedHidden`). Five cases went red, each *Expected false, got true*:
   `forest_placement.spec:763` (the distance arm of `bedHidden`), `:788` (the ray arm, *"calls a bed
   in clear air SEEN"*), `:819` (*"a character is not a screen"*), and T1's own `:469` and `:491`.
   Line: `[harness] FAIL: 32/34 checks @ ea0cbbb7… (DIRTY TREE (3 paths) - NOT valid evidence)
   scope=all`. The tree was restored and the PASS line at the top is the clean one.
4. **`inView` is an audit over the bodies that were really made, not over the point that was
   tested.** `materialise` walks the spawned ids, asks `runtime:statusOf(id).position`, and counts a
   body inside `neverStuds` of any eye — no ray, so the design's per-step ray budget is unchanged.
   Verify: *"counts a body born in view, over the bodies that were really made"*, which the DEV run
   exercises for real — harness note **`placement audit: 5 bodies counted in view of
   Alhamdulilah824`**.
5. **A refusal is counted by its reason and printed.** `bedSpot` returns `nobed` (a fact about the
   wood, ends the group's drive) or `inview` (a fact about the instant, retried until the line has
   walked past the bed). Verify: *"writes the refusal into the drive's own ledger, by its reason"*,
   and live below.
6. **THE LIVE ON DRIVE, C1, at this code commit** (`345c-ON-C1-console.txt`), verbatim:
   `[placement] drive 1: placed 13 / bedded 0 / awake 0 / gone 9 / skipped 4 (73 animals placed, 0 bedded bodies, 9 searches, 9 rays, 0 in view, skips budget 4)`
   — **`inView = 0`, `rays = 9 > 0`**, `skipped.inview` 0. Rays = searches: one ray per materialise
   attempt with one player on the stand, which is design 6.2's budget.
7. **THE LIVE ON DRIVE, A2, at this code commit** (`345c-ON-A2-console.txt`), verbatim:
   `[placement] drive 1: placed 15 / bedded 0 / awake 0 / gone 10 / skipped 5 (83 animals placed, 0 bedded bodies, 2952 searches, 2950 rays, 0 in view, skips inview 3 nobed 2)`
   — **`inView = 0`, `rays = 2950`**, and the predicate BIT: `bed g1-s13: slot 13 SKIPPED for this drive
   (inview: in sight of Alhamdulilah824) at planned dz 364`. 2950 rays over 14,160 steps is 0.21
   rays/step, inside the `<= #Players` bound. **Two numbers for the Director, not fixed here:**
   design section 12 wants `skipped.inview = 0` per drive and A2 gave **3**; and a group refused on
   `inview` is retried every Heartbeat, so one refused bed cost ~2,940 ring searches in that drive.
8. **The frame, from the stand, opened** (`345c-ON-C1-F1.png`, zoom `…-F1-zoom.png`): the hunter's
   own first-person view — shotgun barrel bottom-left, tall grass, a birch wood and an open glade,
   HUD *"stay on stand, animals coming"*, DRIVE 1, 4:59, 0 ANIMALS. **Three red deer are standing
   under the far treeline on the left**, still, in place; nothing appears in the lane. The client's
   own reading at that instant (`345c-ON-C1-frame-got.txt`): **11 Boars replicated, 0 within 145
   studs, nearest 172 studs.**
9. **The frame instrument parks where it is asked (L-185).** `Camera.ProbeCamera`, read by
   `Camera.update` inside the one owner, which then calls `Rig.apply` and does nothing else.
   ASKED `-3904.767,112.079,-5062.005`; **the client's own `CurrentCamera` read
   `-3904.767,112.079,-5062.005`** (`345c-ON-C1-frame-got.txt`), i.e. 0.000 studs off. Verify:
   *"parks the REAL camera at the asked frame, holds it, and gives it back"* in
   `camera_client.spec` — held ≥ 8 of 12 frames, achieved within 0.01 studs of the ask, the owner's
   published CFrame equal to the engine's, and the view returned on release.
10. **`Atomic` costs nothing a client can feel, flag OFF, C1 stand, 60 s, median of 3**
    (`345c-BEFORE-*-client.txt` on `5bb69c40` vs `345c-AFTER-*-client.txt` on this branch, same
    instrument `345c-carm.luau`): **client memory 5134.7 → 5002.6 MB (−2.6 %), frame p95 26.13 →
    26.41 ms (+0.28 ms)**, with run-to-run spreads of 5103.5–5158.4 / 4982.5–5002.6 MB and
    25.65–27.38 / 26.15–28.15 ms. Both deltas sit inside the spread: no measurable change.

## What I could not verify

- **The client spec's in-view assertion is vacuous in DEV, by construction, and says so in its own
  header.** The system is behind `PLACEMENT_IN_PLACE`, OFF by default, and `test` refuses to run with
  an override set — so in the harness the arrivals are other specs' boars and the spec reports them
  rather than judging them. Its DEV note, verbatim: `placement client: switch=false watched 7s, 0
  arrivals judged, 0 ignored (respawn/teleport), 0 inside 145 studs, 0 with a clear camera ray,
  nearest none studs`. **The ignored count is 0.** The live client-side reading with the switch ON is
  claim 8's `0 within 145 studs`, taken by a probe of the same shape in Karen's own place.
- **`camera_client.spec:2610` (the cursor's two-tag release) failed in 3 of 5 full runs** at
  `e7acf195` and `bf36e3aa`, with its own note reading `cursor handed back before this case=true`
  every time — a holder arriving DURING the case, which is the map modal the harness's own
  `map-toggle` scenario opens, exactly as that case's opening comment predicts. `Cursor.isFree()` is
  tag bookkeeping and no line in this task writes a cursor tag. The case now waits for its close the
  way it already waits for its premise; **two consecutive full runs since then are PASS 34/34 at
  `ea0cbbb7`** (`345c-harness6.txt`, `345c-harness7.txt`). I did **not** run a merge-base control for
  it, so "it was there before" is argued from the case's own note and not measured.
- Nobody has PLAYED a drive with the switch on. Karen's eye is T6's.
- No other named failure fired at this code commit; `boar_behaviour.spec` and `boar_shot.spec` were
  green in every run.

ANSWERED: L-136 — the FAIL lines are named with their commits and their case above; at the code
commit `ea0cbbb7` there are 0 FAIL lines in two consecutive runs.
ANSWERED: L-127 — every before/after pair quotes BOTH sides on one line (claim 10), and what is
unproven (Karen's eye, the DEV-vacuous client assertion) is written as unproven, not as a nicety.
ANSWERED: L-162 — both live drives, the frame, the camera read-back and the AFTER cost runs were all
taken at this code commit's tree; the BEFORE runs name `5bb69c40` on their own line.
ANSWERED: L-014 — no code was checked out in `driven-hunt-karen`; the proof served :34873 from
`driven-hunt-rev` and her FT ends on :34873 from `driven-hunt-karen`, in Edit, verified
(`342-ft.py mode` → `Edit`).
ANSWERED: L-101 — `345c-attrs-before.txt` against `345c-attrs-final.txt`, `diff` **EMPTY**. The proof
flag and the cell attribute were removed BY NAME; `flags.py --place forest clear` was never run.
ANSWERED: L-093 — claim 3, two delete-the-producer cases named with the line that fails.
ANSWERED: L-185 — the camera's achieved CFrame is read back off the engine and printed before any
frame is trusted (claim 9), and the owner publishes it in `Camera.stats().probeCameraAt`.
ANSWERED: L-109 / L-120 — the new attribute route was proved against a known landmark (the player's
own eye, 0.000 studs off) in the same session, before the frame was used as evidence.
ANSWERED: L-033 — the repeated failure was not called settled on one clean pass: two consecutive
full PASS runs at `ea0cbbb7` are pasted above.
