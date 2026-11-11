# Task 345c (T3): "never in view" as a predicate and a counter

Task: 345c
Round: 2
Base: main (`5bb69c40`, #362)
Code commit: `20d36cab887f37dc21b860891accf869623734db`

`[harness] PASS: 34/34 checks @ 20d36cab887f37dc21b860891accf869623734db (clean tree) scope=all`

`test2` **N/A**: no `TWO_PLAYER_PATHS` path is touched (`src/server/ForestTest/`,
`src/shared/ForestTest/`, `src/server/Boar/Body.luau`, `src/client/Camera/`, `tests/`), and
`docs/design/animal-placement.md` section 17 says the one-player line is the gate for all six tasks.

**What changed.** T3 of the design's section 17, as sections 6, 7, 8 and 13 write it:
`ForestTest.bedHidden` (the ray), `Placement.clearOfEyes` wired in at the one bed searcher,
`placementStats().inView/rays` beside `searches` and on the `DHForestPlacement` probe attribute,
`ModelStreamingMode = Atomic` on the drawn animal, and `tests/client/animal_placement.spec.luau`.
Plus the frame instrument `ESCALATE.md` 2026-11-11 ~02:05 asks for: `Camera.ProbeCamera`, a
Studio-only held CFrame read inside the client camera's one owner. `docs/design/` is unchanged.

**Round 2 fixed both findings and took every note.** (1) The `inview` ledger case now stubs the
SEARCHER (`ForestTest.restSpot`) and drives the real `bedSpot` → `bedHidden` → `clearOfEyes` twice
against the live player's own eye; (2) the client spec's classifier ASKS `Placement.clearOfEyes`
instead of restating it, and its flag-off branch asserts nothing and says so in its note. Notes
taken: the Atomic property is asserted in `boar_model.spec`; the one-ray-per-eye case puts a screen
in front of the first eye; the boundary case survives a place with ground under it; every case that
patches the module table or builds a part restores it on both paths; the parked frame counts its own
milliseconds; the release margin is 50 studs, not the park's own 300; the deviation sentence below is
corrected. The two numbers that moved against the design went to `ESCALATE.md`
(2026-11-11 ~04:55); `TASKS.md` carries the task row and five queued notes.

**Deviation, one, and it is a place and not a number.** The design's T3 row says
`ModelStreamingMode = Atomic` *"in `Boar.Body.create`"*; `create` builds a Part, and the drawn
**Model** of a drive animal is born in `Body.attachVisual`, so the property is set there.
(`Body.displayCarcass` also builds an animal Model — a static end-of-drive trophy, not a streamed
drive body — and is left alone; queued as 345c-notes (b).)

## PLAN (core-quality step 0, written at round 1's request time and not before the edit — said plainly)

(a) **REAL LIFE:** a beaten wood holds its game before the line enters it; driven game is found, not
conjured. (b) **MEASURED NOW:** at the merge base, flag ON in C1, the drive reported `9 searches` and
no sight test at all (`345b-R3-ON-C1-console.txt`). (c) **TARGET:** `inView = 0` with `rays > 0` over
a live drive in two cells (design 12.2). (d) **LEVER:** `ForestTest.bedSpot` →
`ForestTest.bedHidden` → `Placement.clearOfEyes` + `Workspace:Raycast`; the counters are written at
`state.placementRays` / `state.placementInView` in `src/server/ForestTest/init.luau`. (e) **HOW
MEASURED AFTER:** the same instrument — `ServerStorage.DHForestPlacement`, read every 2 s by
`<runs-dir>/345b-arm.luau`.

## Claims

1. **Nothing is bedded where a player can see it, and the rule is two halves in one order.**
   `ForestTest.bedHidden`: `Placement.clearOfEyes` per eye first (the refusal names the player), then
   one ray per eye. Verify: *"refuses inside the reach by arithmetic, before it spends a ray"* and
   *"spends one ray per eye, and calls a bed in clear air SEEN"* in `forest_placement.spec` — the
   second now puts a SCREEN in front of the first eye, so the count is the per-eye one and not an
   early return, and the refusal names the SECOND eye.
2. **The ray is the measured one.** `ForestTest.seenFromEye` is `restSeenFromLane`'s ray with the
   origin at a player's head: `RespectCanCollide = true`, terrain included, `Data.characterOf` means
   a body is not a screen, and the observer's own character is excluded because the ray starts inside
   its head. Verify: *"calls the same bed HIDDEN behind something a bullet would stop"* — one Part
   between eye and bed flips the answer, and the same Part under a Humanoid flips it back.
3. **ROUND 1, FINDING 1 — one case drives the whole T3 path through its own producers.**
   *"refuses a bed a player can see, raises `rays` and writes `inview` into the ledger"* stubs
   `ForestTest.restSpot` only; `bedSpot`, `bedHidden`, `clearOfEyes`, the ray and `stepPlacement`'s
   ledger are the real ones, and the eye is the harness's own player. A bed 10 studs from his head is
   refused *"within … of <name>"* **with `rays` unchanged**; a bed 600 studs up in clear air is
   refused *"in sight of <name>"* **with `rays` raised**, and `skips.inview` reaches 2. Its note from
   this code commit's own run, verbatim: `placement ledger: bed g958-s2: slot 2 SKIPPED for this
   drive (inview: in sight of Alhamdulilah824) at planned dz 1170 -- placed 8 / bedded 0 / awake 0 /
   gone 0 / skipped 2`.
4. **L-093, TWO RUNS at the round-2 tree.** (a) `Placement.clearOfEyes` → `return true, math.huge`:
   `forest_placement.spec:765` (the arithmetic arm), `:988` (the ledger case's *"within"*), `:469`
   and `:491` (T1's own), **and `animal_placement.spec:162` on the CLIENT** — *Expected "inview", got
   "clear"*. (b) the ray loop cut out of `bedHidden`: `:778` (*Expected 1, got 0* — the ray counter),
   `:790`, `:840`, and the ledger case at `:988`/`:1003`. Files `<runs-dir>/345c-L093b.txt` and
   `345c-L093c.txt`, both `(DIRTY TREE (1 paths) - NOT valid evidence)`; the tree was restored and
   the PASS line at the top is the clean one.
5. **ROUND 1, FINDING 2 — the client spec asks the owner, and asserts nothing it cannot fail.**
   `verdictFor` calls `Placement.clearOfEyes` for its distance half (claim 4a is the proof), and with
   the switch off it writes `placement client: PLACEMENT_IN_PLACE is OFF, so NOTHING WAS JUDGED by
   the in-view rule in this run` instead of an `expect` that always passes.
6. **`inView` is an audit over the bodies that were really made.** `materialise` walks the spawned
   ids, asks `runtime:statusOf(id).position` and counts a body inside `neverStuds` of any eye — no
   ray, so the per-step ray budget is unchanged. Verify: *"counts a body born in view, over the
   bodies that were really made"*, exercised for real in DEV — note `placement audit: 5 bodies
   counted in view of Alhamdulilah824`.
7. **THE LIVE ON DRIVE, C1** (`345c-ON-C1-console.txt`, taken at `ea0cbbb7`; its `src/` is this code
   commit's but for the parked frame's own `stats` accounting — everything since is `tests/`,
   `TASKS.md` and `ESCALATE.md`), verbatim:
   `[placement] drive 1: placed 13 / bedded 0 / awake 0 / gone 9 / skipped 4 (73 animals placed, 0 bedded bodies, 9 searches, 9 rays, 0 in view, skips budget 4)`
   — **`inView = 0`, `rays = 9 > 0`**, `skipped.inview` 0.
8. **THE LIVE ON DRIVE, A2** (`345c-ON-A2-console.txt`, same commit), verbatim:
   `[placement] drive 1: placed 15 / bedded 0 / awake 0 / gone 10 / skipped 5 (83 animals placed, 0 bedded bodies, 2952 searches, 2950 rays, 0 in view, skips inview 3 nobed 2)`
   — **`inView = 0`, `rays = 2950`**, and the predicate BIT in Karen's own place: `bed g1-s13: slot
   13 SKIPPED for this drive (inview: in sight of Alhamdulilah824) at planned dz 364`. **Both numbers
   that moved against the design are in `ESCALATE.md` 2026-11-11 ~04:55 and are not fixed here:**
   A2's 3 `inview` skips against section 12.1's target of 0, and the ~2,940 ring searches that one
   retried refusal cost (`rays` counts `bedHidden`'s own ray only, so it understates that work).
9. **The frame, from the stand, opened** (`345c-ON-C1-F1.png`, zoom `345c-ON-C1-F1-zoom.png`): the
   hunter's own first-person view — shotgun barrel bottom-left, tall grass, a birch wood and an open
   glade, HUD *"stay on stand, animals coming"*, DRIVE 1, 4:59, 0 ANIMALS. **Three red deer stand
   under the far treeline on the left**, still, in place; nothing appears in the lane. The client's
   own reading at that instant (`345c-ON-C1-frame-got.txt`): **11 Boars replicated, 0 within 145
   studs, nearest 172 studs.** It is one frame of a negative — design 12.2 says Karen's eye over a
   whole drive is the only instrument — so claims 7 and 8 stay NOT PROVEN in her sense.
10. **The frame instrument parks where it is asked (L-185), and `Atomic` costs nothing a client can
    feel.** ASKED `-3904.767,112.079,-5062.005`; the client's own `CurrentCamera` read
    `-3904.767,112.079,-5062.005`, 0.000 studs off (`345c-ON-C1-frame-got.txt`). Verify *"parks the
    REAL camera at the asked frame, holds it, and gives it back"* in `camera_client.spec`: held ≥ 8
    of 12 frames, `achieved` within 0.01 studs of the ASK (the assertion that carries the claim), and
    the camera back within 50 studs of the root on release. Cost, flag OFF, C1 stand, 60 s, median of
    3 (`345c-BEFORE-*-client.txt` on `5bb69c40` against `345c-AFTER-*-client.txt` on this branch, one
    instrument `345c-carm.luau`): **client memory 5134.7 → 5002.6 MB, frame p95 26.13 → 26.41 ms**,
    spreads 5103.5–5158.4 / 4982.5–5002.6 MB and 25.65–27.38 / 26.15–28.15 ms — both deltas inside
    the spread. The property itself is now asserted in `boar_model.spec` (*"is ONE thing to stream
    in"*), which a cost run reading "no measurable change" could not do.

## What I could not verify

- **Nobody has played a drive with the switch on.** Claims 7 and 8 are NOT PROVEN in Karen's sense:
  console counters and one frame, not her eye over a drive. That is T6.
- **The client spec's in-view assertion cannot run in the gate**, by construction: the system is
  behind `PLACEMENT_IN_PLACE`, off by default, and `test` refuses to start with an override set. Its
  DEV note says exactly that, and the live client-side reading with the switch ON is claim 9's
  `0 within 145 studs`.
- **`camera_client.spec`'s cursor case is timing-bound to the harness's own input replay.** Its tag
  and lock assertions now wait the way its opening premise already waited; before that it failed in
  3 of 5 full runs at `e7acf195`/`bf36e3aa`, its own note reading `cursor handed back before this
  case=true` every time, and the lock half fired once more during claim 4's delete run.
  `Cursor.isFree()` is tag bookkeeping no line of this task writes. I did **not** run a merge-base
  control for it.
- No other named failure fired at this code commit; `boar_behaviour.spec` and `boar_shot.spec` were
  green in every run of this task.

ANSWERED: L-136 — the FAIL lines above name their commits and their cases; at this code commit there
are 0 FAIL lines.
ANSWERED: L-127 — every before/after pair quotes BOTH sides on one line (claim 10), and what is
unproven is written as unproven, not as a nicety.
ANSWERED: L-162 — both live drives, the frame, the camera read-back and the AFTER cost runs were
taken at `ea0cbbb7`; claim 7 says what has changed in `src/` since (the parked frame's own stats),
and the BEFORE runs name `5bb69c40` on their own line.
ANSWERED: L-014 — no code was checked out in `driven-hunt-karen`; the proof served :34873 from
`driven-hunt-rev` and her FT ends on :34873 from `driven-hunt-karen`, in Edit (`342-ft.py mode`).
ANSWERED: L-101 — `345c-attrs-before.txt` against `345c-attrs-final.txt`, `diff` **EMPTY**: the proof
flag and the cell attribute were removed BY NAME, and `flags.py --place forest clear` was never run.
ANSWERED: L-093 — claim 4, two full runs, with the failing line numbers on both sides, the client's
included.
ANSWERED: L-185 — the camera's achieved CFrame is read off the engine and printed before any frame is
trusted (claim 10), and the owner publishes it in `Camera.stats().probeCameraAt`.
ANSWERED: L-109 / L-120 — the new attribute route was proved against a known landmark (the player's
own eye, 0.000 studs off) in the same session, before any frame was used as evidence.
ANSWERED: L-033 — nothing was called settled on one clean pass: the cursor case has two consecutive
PASS runs at `ea0cbbb7` and two more at `b777dc31` and `20d36cab`.
