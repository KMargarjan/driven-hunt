# Task 366 -- review request

Task: 366
Round: 3
Base: c311f27821e53e1433a96e65658a504ff4d324db
Code commit: 4330c6ca

**Docs-only. `git diff --stat c311f278..HEAD -- src tests tools` is EMPTY.** The dispatch's own
step 3 fired: *"If the cost is the dealt cell's own density, or the fix needs an owner change or a
design: NO CODE, write ESCALATE.md with the numbers and the options, and stop."* Changed:
`TASKS.md` (the dispatch transcribed as the Director's, plus the Builder status),
`reviews/task-366/MEASUREMENTS.md` and `reviews/task-366/evidence/` (the probe output the
conclusions rest on), `ESCALATE.md` (new entry on top), `reviews/task-366/RESULT.md` (round 1).

Everything was read in **Karen's Forest Test** (130094961655666) at `c311f278` -- the commit
`driven-hunt-karen` serves on `:34873`, which is this branch's base, so the readings are at the code
commit's content. Five Play sessions, each started and stopped by this session, each preceded by `ftplay.py mode`
-> `Edit`, and her place re-checked (attributes, census) after each. Probes: `<runs-dir>/366-*`; their output: `reviews/task-366/evidence/`.

## Claims

1. **The cells that are not dealt cost the client nothing.** Task 337's `Places.Cells` stores 7 of
   the 8 cells in `ServerStorage.GridWood` (28,535 models / 92,052 parts); `Workspace.GridForest`
   holds **C1 only**, on the server and on the client.
   *Verify:* `MEASUREMENTS.md` section 1 against `evidence/366-srvcensus-S1.txt` (server) and
   `evidence/366-client-census.txt` (client).
2. **The dealt cell's wood costs +10.92 ms p95 (+54 % of the OFF median) at C1 stand 4 and +0.82 ms (+3.4 %) at the
   lobby, where it draws 0 extra triangles.** Four ON and four OFF samples, alternating, client-side
   detach only, `restored=true` on the last line.
   *Verify:* `evidence/366-forestoff-c1s4.txt` and `evidence/366-forestoff-lobby.txt`; the lobby
   pair's `RenderBreakdown/Opaque` is the identical 2,452,223 on both sides. An independent
   three-station run in another session (`evidence/366-grid3-three.txt`) puts the stand's DRAWN-wood
   cost at `35.38 - 21.73 = +13.65 ms` with residency held constant on both sides; the two bracket
   the same thing from either side and neither is averaged into the other.
3. **Residency is about a millisecond, and only ONE pair establishes it.** The lobby pair holds
   DRAWING exactly constant -- the wood is out of frustum attached or detached and `Opaque` is the
   identical **2,452,223** tris on all four ON and all four OFF samples -- and gives
   **+0.82 ms p95** (ON median 25.40, range 25.31-25.66; OFF 24.58, range 22.97-26.12). **The two
   ranges overlap, so it is not distinguishable from zero**; what it establishes is a ceiling of
   about a millisecond against the ~11-14 ms the drawn wood costs.
   Round 2's camera-up pair is **withdrawn as a bound**. Two things were wrong with it and both are
   corrected rather than reworded: its probe's `med()` was `s[ceil(n/2)]`, which at n=2 is the
   **minimum**, and it picked p95 and memory column by column so a row could mix two samples. Re-run
   at **n=4 interleaved with a true median** (`evidence/366-grid3-up.txt`) the gap is **+1.93 ms**,
   not +0.85. But it still bounds residency in **neither** direction: its two sides draw 126,887 and
   1,778,814 triangles, and this task measured that **cost is not a function of triangle count** --
   at the stand the OFF side draws 40,248 **fewer** triangles and is **10.92 ms cheaper**. So the
   sign of the correction is unknown. Round 2's "at most ~0.9 ms, and the true figure is lower" was
   wrong on both the statistic and the sign; nothing now rests on that pair.
   *Verify:* `evidence/366-forestoff-lobby.txt` (the isolate), `evidence/366-grid3-up.txt` (the
   withdrawn pair, at n=4 with ranges); `MEASUREMENTS.md` section 3a, which keeps both and says
   which is which.
4. **Memory: 360b's "client memory +11.6 %" was never a client figure, and the client's own share
   of the dealt cell's wood is +11.1 MB.** The same probe run against the **server** DataModel and
   against the **client** DataModel, seconds apart in one Play, returns **byte-identical** numbers:
   `BaseParts 565.4 MB`, `GraphicsParts 14.9 MB`, `Instances 336.6 MB`, totals 4,905.4 / 4,902.5.
   (Identical for those and for `Signals`, `Script`, `GraphicsMeshParts`, `GraphicsParticles`,
   `GraphicsSpatialHash`, `GraphicsTerrain`, `GraphicsTexture`, `GraphicsTextureCharacter` and
   `Sounds`; `Internal`, `LuaHeap`, `TerrainVoxels`, `Gui`, `Animation` and `Navigation` differ,
   and the conclusion does not need them to.) The two files are demonstrably different DataModels --
   the server's reads `Workspace parts 27488` / `GridWood parts 92052`, the client's
   `Workspace parts=2857` / `GridForest parts=0` -- and `BaseParts` is the identical 565.4 across
   that gulf.
   `Stats` in Studio reports the process, and in Studio the server and client are one process -- so
   360b's figure includes the server holding all eight cells' 108,396 parts, 92,052 of them in
   `ServerStorage.GridWood`. The one tag the client-side detach moves is `GraphicsParts`: **16.6 MB
   detached, 27.1-27.7 MB attached, in all four pairs, and +11.0 MB again at n=4 in `evidence/366-grid3-up.txt`**; `BaseParts`, `Instances`,
   `GraphicsMeshParts` and `GraphicsTexture` do not move, because the detach keeps every instance
   alive. 360b's remaining ~600 MB is **NOT decomposed** and `MEASUREMENTS.md` section 9 item 4 and
   `ESCALATE.md` both say so.
   *Verify:* `evidence/366-mem-server.txt` against `evidence/366-mem-client-same-session.txt`
   (same Play, same tags); `evidence/366-grid2.txt`'s `GraphicsParts` column.
5. **`360b-park.luau` never parks the camera**, so 360b's "lobby" row and its "C1 stand 4" row are
   one view measured twice. It writes `cam.CFrame` once and never binds to RenderStep;
   `src/client/Camera/Rig.luau` is the only writer of `workspace.CurrentCamera` in `src/`, and the
   bind itself is in `src/client/Camera/init.luau`
   (`RunService:BindToRenderStep(Config.RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, update)`).
   *Verify:* read `360b-park.luau` (no `BindToRenderStep`) beside `360-holdA.luau`, whose own
   comment names this and binds at `Camera.Value + 10`; then `evidence/366-camcheck.txt` -- the
   camera sat **7,082 studs** off station, constant over 28 samples / 14 s, and **6,791** on an
   earlier run in another session. It stays on the character, wherever the character is.
   `MEASUREMENTS.md` section 2 now quotes the committed 7,082 line rather than the uncommitted one,
   and cites `init.luau` for the bind as well as `Rig.luau` for the ownership.
6. **One 8 s frame-p95 sample of this place is worth +/- 47 %.** Six consecutive 8 s samples, one
   held station, nothing changed between them (same resident parts, boars, character; the same
   triangles in four of the six -- s5 and s6 read 2,446,353, and the minimum s1 and maximum s4 are
   both in the 2,418,401 group): 23.72 -> 34.79 ms, 1.47x. Absolutes also drift between SESSIONS --
   the same three stations read 19.5/22.8/35.5 in one and 21.7/31.1/35.4 in another -- so every
   figure quoted anywhere here is a pair taken inside one probe call.
   *Verify:* `evidence/366-noise-1.txt`, every sample's state printed on its own line.
7. **The trees behind the default stand are unchanged.** `366-GA-NOW.png`, C1 stand 4, eye height,
   Karen's S/SW angle, held by `360-holdA.luau` verbatim: a continuous trunk wall, canopy closing
   the top, no open horizon. Sky/haze in the eye-level band **1.95 %** against 360b-GA-AFTER's
   2.29 % on the same rule.
   *Verify:* open `<runs-dir>/366-GA-NOW.png`; `python 366-sky.py 366-GA-NOW.png 360b-GA-AFTER.png`.
   The frame is not committed (it is a screenshot of her place). The rule is
   mine, not 360b's -- `MEASUREMENTS.md` section 8 states its calibration against all six of 360b's
   frames and the gap to their reported figures.
8. **`RenderFidelity = Performance` is the only ownable lever worth more than noise, and it buys
   2.2 of the 10.9 ms** (-8.7 % p95, triangles -21 %, all three interleaved pairs improved) at the
   price of how the trees look. Forest `CastShadow=false` is -0.33 ms (noise);
   `Lighting.GlobalShadows=false` is -3.01 ms but Lighting is not Rojo-owned.
   *Verify:* `evidence/366-lod.txt`, `evidence/366-shadow-out.txt`; `MEASUREMENTS.md` section 7,
   whose percentage column is one base per row (each lever against its own ON median), and which now
   states that the LOD rows are interleaved and **the two shadow rows are not**: that sequence's two
   controls differ by 2.20 ms with nothing changed, larger than the -0.33 ms it calls noise, so both
   shadow figures are soft and neither is relied on.
9. **Karen's place was left as found.** `ftplay.py mode` -> Edit on `:34873`; attribute diff EMPTY;
   360b's unsaved plant intact at 32,966 models / 108,396 parts / 8 cells / the same `PlantEpoch`;
   never Saved, Published or Drafts-Committed; `ft-open.sh` not used; 0 game error lines.
   Checked after each of the three Play sessions.
   *Verify:* `diff reviews/task-366/evidence/366-attrs-BEFORE.txt
   reviews/task-366/evidence/366-attrs-END.txt` (identical) and
   `diff evidence/366-census-EDIT.txt evidence/366-census-END.txt` -- both now committed.
10. **The harness FAILs, and it FAILs the same way on `main` with none of this branch's files.**
   Two lines, two different commits:
   - `[harness] FAIL: 31/34 checks @ eae6bf537b2d9ab7463a62fcc2d18bc15b078258 (clean tree) scope=all`
   - `[harness] FAIL: 29/34 checks @ c311f27821e53e1433a96e65658a504ff4d324db (clean tree) scope=all`
     (the control, run from a detached checkout of `origin/main`)

   **Every failed check on this branch is accounted for.** `31/34` is three failed checks, and one
   failing server assertion produces TWO of them: `[server] status PASS` and `[server] > 0 passed,
   0 failed, 0 errors, 0 skipped` are both read off the same report. So the three are that pair,
   from `licence_popup.spec` (*Expected nil, got "no-range"*), plus `[input] replayed every step of
   6 scenario(s)`. The control's `29/34` is five: the same server pair, this time from
   `weapon_shot.spec` x2 (*4 vs 3*, *2 vs 3*) and `deer_hitbox.spec` (*calf: legs box 1 is
   unreachable by a flank ray*); the matching client pair from `semiauto_client.spec`
   (*true vs false*); and the same input check.
   The failing specs **differ between runs**, which is what makes them intermittent rather than a
   regression. Both runs also hit the same
   harness-transport fault, `[input] tie-the-driver: user_keyboard_input ... Target is not
   reachable ... DMN_ID_PLAYCLIENT` -- a StudioMCP delivery failure, not a game assertion.
   **This is a docs-only change** (`agents.py`: *"docs-only change: no harness line required"*), so
   the gate does not rest on it; the lines are here as evidence that **`main` is red right now**,
   which blocks every task's merge gate until someone owns it. This also gives task 365's note
   **365(f)** -- *"one server assertion failed ... and was not captured by name"* -- its names.
   *Verify:* re-run `python tools/studio_mcp.py test` on this branch and on `c311f278`.

Standing rule G: `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both
PASS; `python tools/privacy_scan.py scan` -> `PASS: 0 findings in 1543 tracked text files`.

## What could not be verified

* **There is no AFTER, and step 4 was not run.** No flag and no code, so no second set of readings
  and no drive started by a click. The interleaved `ON | OFF` pairs are the before/after this task
  can honestly produce.
* **Nobody has played it.** Every figure is a probe's. Whether 35 ms at the stand *feels* worse than
  25 ms is Karen's call and she has not been asked. That is the decision `ESCALATE.md` puts to the
  Director.
* **360b's +608 MB is NOT decomposed.** Claim 4 shows what it is not (a client figure) and what the
  client's own share is (+11.1 MB of `GraphicsParts`). Where the rest sits -- the seven stored cells
  on the server, Luau heap, drift between two Play sessions -- is not measured, because the stored
  cells cannot leave the Studio process without destroying Karen's unsaved plant.
* **Residency is bounded, not measured.** Claim 3's lobby pair has overlapping ranges, so +0.82 ms
  is a ceiling of about a millisecond rather than a figure. The camera-up pair bounds nothing.
* **Absolute frame times are not comparable across Play sessions** (claim 6). Only pairs taken
  inside one probe call are quoted.
* **The two shadow figures are soft** (claim 8): that run is not interleaved and its own controls
  drift by more than the smaller of the two effects.
* **The lobby rows were taken with the player at the stand** -- moving the character to the lobby
  mid-drive did not stick, the server pulled it back. So they are the harder case (C1's wood
  resident), not the easier one.
* **`StreamOutBehavior` was not switched and re-read.** What it could win is claim 3's +0.82 ms and
  claim 4's 11.1 MB. `Workspace` is not Rojo-owned, so no file under `src/` can own it.
* **The flaky specs were named, not diagnosed.**
* **CI was still `in_progress` when this request was written** and has not been re-read since.

## Round 3: what the Reviewer's two blocking findings changed

1. **The residency figure was a minimum dressed as a median** -- correct, and worse than the
   finding said, because the probe also picked p95 and memory independently per column. The probe's
   `med()` is fixed (true median, even n averages the two middle values), every sample's own line is
   printed, and the cell was re-run at **n=4 interleaved**: the gap is **+1.93 ms**, not +0.85.
   The derived `+9.47` and `+8.00` are gone; section 4's +10.92 (n=4) and section 3's +13.65
   (residency held constant) replace them.
2. **The confound's sign was stated backwards** -- and the right conclusion is stronger than the
   finding's: the pair bounds residency in **neither** direction, because this task's own section 4
   shows cost is not a function of triangle count (40,248 fewer triangles, 10.92 ms cheaper). So the
   pair is withdrawn as a bound entirely, and residency now rests on the lobby pair the Reviewer
   named -- drawing held exactly constant, `Opaque` identical on both sides. Every "at most" and
   "the true figure is lower" is struck from `MEASUREMENTS.md` sections 0, 3a, 9.5 and 9.7, from
   this request, and from both places in `ESCALATE.md`.

All ten non-blocking notes are addressed in this round, not queued: the committed camcheck line,
the `init.luau` citation, "four of the six" triangle counts, the "19-21 ms" over-claim removed with
section 3a, one spelling of 10.92, the shadow rows marked not-interleaved with their controls' own
drift quoted, "five Play sessions" in the header, `evidence/366-grid3-three.txt` for section 3's
table and its `held offset 0.00` lines, `evidence/366-census-END.txt` and the two attribute files
committed, the `Internal`/`LuaHeap` caveat on "byte-identical", and the 8 s wording in `ESCALATE.md`.

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
