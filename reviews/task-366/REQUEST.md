# Task 366 -- review request

Task: 366
Round: 1
Base: c311f27821e53e1433a96e65658a504ff4d324db
Code commit: eae6bf537b2d9ab7463a62fcc2d18bc15b078258

**Docs-only. `git diff --stat c311f278..eae6bf53 -- src tests tools` is EMPTY.** The dispatch's own
step 3 fired: *"If the cost is the dealt cell's own density, or the fix needs an owner change or a
design: NO CODE, write ESCALATE.md with the numbers and the options, and stop."* Changed:
`TASKS.md` (the dispatch transcribed as the Director's, plus the Builder status),
`reviews/task-366/MEASUREMENTS.md` (new), `ESCALATE.md` (new entry on top).

Everything was read in **Karen's Forest Test** (130094961655666) at `c311f278` -- the commit
`driven-hunt-karen` serves on `:34873`, which is this branch's base, so the readings are at the code
commit's content. One Play, started and stopped by this session. Probes: `<runs-dir>/366-*`.

## Claims

1. **The cells that are not dealt cost the client nothing.** Task 337's `Places.Cells` stores 7 of
   the 8 cells in `ServerStorage.GridWood` (28,535 models / 92,052 parts); `Workspace.GridForest`
   holds **C1 only**, on the server and on the client.
   *Verify:* `MEASUREMENTS.md` section 1 table against `366-srvcensus-S1.txt` (server) and
   `366-cl-live1.txt` (client), both produced by `360b-census.luau` / `366-cl.luau`.
2. **The dealt cell's wood costs +10.92 ms p95 (+54 %) at C1 stand 4 and +0.82 ms (+3.4 %) at the
   lobby, where it draws 0 extra triangles.** Four ON and four OFF samples, alternating, client-side
   detach only, `restored=true` on the last line.
   *Verify:* `366-forestoff-c1s4.txt` and `366-forestoff-lobby.txt`; the lobby pair's
   `RenderBreakdown/Opaque` is the identical 2,452,223 on both sides.
3. **Residency is not the cost: ~1 ms.** Camera held straight up at the stand with the same 11,254
   tree parts resident reads p95 19.2 ms; the forest detached entirely with the camera in the wood
   reads 20.2 ms. Two ways of drawing no wood, same answer.
   *Verify:* `366-hold-up.luau` rows in `MEASUREMENTS.md` section 3 against claim 2's OFF rows.
4. **`360b-park.luau` never parks the camera**, so 360b's "lobby" row and its "C1 stand 4" row are
   one view measured twice. It writes `cam.CFrame` once and never binds to RenderStep;
   `src/client/Camera/Rig.luau` owns the camera and binds at `Enum.RenderPriority.Camera`.
   *Verify:* read `360b-park.luau` (no `BindToRenderStep`) beside `360-holdA.luau`, whose own
   comment names this and binds at `Camera.Value + 10`; then `366-camcheck.luau`'s output -- the
   camera sat **6,791 studs** off station, constant over 28 samples / 14 s.
5. **One 10 s frame-p95 sample of this place is worth +/- 47 %.** Six consecutive 8 s samples, one
   held station, nothing changed between them (same resident parts, boars, character, triangles):
   23.72 -> 34.79 ms, 1.47x.
   *Verify:* `366-noise-1.txt`, every sample's state printed on its own line.
6. **The trees behind the default stand are unchanged.** `366-GA-NOW.png`, C1 stand 4, eye height,
   Karen's S/SW angle, held by `360-holdA.luau` verbatim: a continuous trunk wall, canopy closing
   the top, no open horizon. Sky/haze in the eye-level band **1.95 %** against 360b-GA-AFTER's
   2.29 % on the same rule.
   *Verify:* open the frame; `python 366-sky.py 366-GA-NOW.png 360b-GA-AFTER.png`. The rule is
   mine, not 360b's -- `MEASUREMENTS.md` section 8 states its calibration against all six of 360b's
   frames and the gap to their reported figures.
7. **`RenderFidelity = Performance` is the only ownable lever worth more than noise, and it buys
   2.2 of the 10.9 ms** (-8.7 % p95, triangles -21 %, all three interleaved pairs improved) at the
   price of how the trees look. Forest `CastShadow=false` is -0.33 ms (noise);
   `Lighting.GlobalShadows=false` is -3.01 ms but Lighting is not Rojo-owned.
   *Verify:* `366-lod.txt`, `366-shadow-out.txt`; `MEASUREMENTS.md` section 7.
8. **Karen's place was left as found.** `ftplay.py mode` -> Edit on `:34873`; attribute diff EMPTY;
   360b's unsaved plant intact at 32,966 models / 108,396 parts / 8 cells / the same `PlantEpoch`;
   never Saved, Published or Drafts-Committed; `ft-open.sh` not used; 0 game error lines.
   *Verify:* `diff 366-attrs-BEFORE.txt 366-attrs-AFTER.txt`; `366-census-EDIT.txt` against
   `366-census-END.txt`.
9. **The harness FAILs, and it FAILs the same way on `main` with none of this branch's files.**
   Two lines, two different commits:
   - `[harness] FAIL: 31/34 checks @ eae6bf537b2d9ab7463a62fcc2d18bc15b078258 (clean tree) scope=all`
   - `[harness] FAIL: 29/34 checks @ c311f27821e53e1433a96e65658a504ff4d324db (clean tree) scope=all`
     (the control, run from a detached checkout of `origin/main`)

   The failing specs **differ between runs**, which is what makes them intermittent rather than a
   regression: on this branch `licence_popup.spec` (*Expected nil, got "no-range"*); on `main`
   `weapon_shot.spec` x2 (*4 vs 3*, *2 vs 3*), `deer_hitbox.spec` (*calf: legs box 1 is unreachable
   by a flank ray*) and `semiauto_client.spec` (*true vs false*). Both runs also hit the same
   harness-transport fault, `[input] tie-the-driver: user_keyboard_input ... Target is not
   reachable ... DMN_ID_PLAYCLIENT` -- a StudioMCP delivery failure, not a game assertion.
   **This is a docs-only change** (`agents.py`: *"docs-only change: no harness line required"*), so
   the gate does not rest on it; the lines are here as evidence that **`main` is red right now**,
   which blocks every task's merge gate until someone owns it. This also gives task 365's note
   **365(f)** -- *"one server assertion failed ... and was not captured by name"* -- its names.
   *Verify:* re-run `python tools/studio_mcp.py test` on this branch and on `c311f278`.
10. **`python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both PASS**
    (standing rule G); `python tools/privacy_scan.py scan` -> `PASS: 0 findings in 1524 tracked
    text files`.

## What could not be verified

* **There is no AFTER, and step 4 was not run.** No flag and no code, so no second set of readings
  and no drive started by a click. Section 4's interleaved `ON | OFF` is the before/after pair this
  task can honestly produce.
* **Nobody has played it.** Every figure is a probe's. Whether 35 ms at the stand *feels* worse than
  25 ms is Karen's call and she has not been asked.
* **The lobby rows were taken with the player at the stand** -- moving the character to the lobby
  mid-drive did not stick, the server pulled it back. So they are the harder case (C1's wood
  resident), not the easier one.
* **`StreamOutBehavior` was not switched and re-read.** Its ceiling (~1 ms) is inferred from the
  residency measurement. `Workspace` is not Rojo-owned, so no file under `src/` can own it.
* **The flaky specs were not diagnosed**, only named and shown to pre-date this branch.

## Answered CHECKED flags

* **ANSWERED: L-127** -- every pair is BEFORE | AFTER on one line, same instrument, same Play
  session, and interleaved ON/OFF/ON/OFF so drift cannot pass for the effect. Where the dispatch's
  BEFORE came from a different session (360b's), it is NOT compared: section 6 shows why.
* **ANSWERED: L-162** -- her Forest Test serves on `:34873` from `driven-hunt-karen` at
  `c311f278`, which is this branch's base; `git rev-parse HEAD` in that worktree is pasted in
  `MEASUREMENTS.md`.
* **ANSWERED: L-136** -- the flakes are named before any re-run: `licence_popup.spec`,
  `weapon_shot.spec` x2, `deer_hitbox.spec`, `semiauto_client.spec`, and the `tie-the-driver`
  `user_keyboard_input` transport fault, with a control run at a second commit (claim 9).
* **ANSWERED: L-093** -- no fix, so no new case. The equivalent control was run anyway: claim 2's
  OFF condition *is* "the thing removed", and it moves the number by 10.9 ms at the stand and by
  0.8 ms at the lobby. The instrument fault of claim 4 likewise reproduces on demand
  (`366-camcheck.luau`).
* **ANSWERED: L-101** -- `366-attrs-BEFORE.txt` and `366-attrs-AFTER.txt` are identical; no flag was
  set, `flags.py --place forest clear` was never run.
* **ANSWERED: L-095** -- step 4 is N/A (no flag to switch on), so no click was needed. The control
  path the dispatch records is transcribed into the TASKS.md entry for whoever needs it next.
* **ANSWERED: perf lesson (task 357)** -- every figure counts `RenderStepped` frames over an 8-10 s
  window, 282-598 frames per sample, printed on every line. No `os.clock` spans a yielding call,
  and nothing is called a stall.
