PASS (item 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this change is animal
behaviour or shooting, and no code changed, so no core path moved. The one thing Karen will judge by
looking -- claim 7's `366-GA-NOW.png`, the trunk wall behind C1 stand 4 -- was captured in HER place
(130094961655666) and described by the Builder (`MEASUREMENTS.md` section 8: "a continuous wall of
spruce and birch trunks across the full width at ~15-40 studs, canopy closing the top"), but the
frame is NOT committed, I cannot see it, and the sky rule (`366-sky.py`) and both PNGs live only in
`<runs-dir>`. The frame-time finding itself -- 31.13 ms at the stand against 20.22 ms with the wood
detached -- has NEVER BEEN PLAYED by anyone, which the request says itself ("Nobody has played it");
that is the decision ESCALATE.md hands the Director. Item 7 is therefore not proven in her place in
the sense rule 5 means.

Duty (a), delete the producer, done by reading on every case offered:
- `366-forestoff-lobby.txt` is the one case that could have been the same condition twice: `Opaque`
  is the identical 2,452,223 on all eight samples, so the triangle column cannot tell ON from OFF.
  It survives the test on the memory column alone -- ON 5011/5018/5017/5016 MB against OFF
  5006/5008/5008/5009 MB, every ON above every OFF, interleaved -- so the detach demonstrably
  happened and the pair is not one state read twice. The claim drawn from it (+0.82 ms, ranges
  overlapping, not distinguishable from zero) is what the data supports.
- `366-forestoff-c1s4.txt`: with the detach deleted, `Opaque` 2,418,401 vs 2,378,153 and the
  medians 31.13 vs 20.22 collapse. Fails without the producer, correctly.
- `366-grid3-up.txt`, `366-grid3-three.txt`: medians re-derived by hand from the per-sample lines --
  ON (19.15, 19.95, 21.19, 31.67) -> 20.57; OFF (18.05, 18.52, 18.76, 18.77) -> 18.64; gap 1.93.
  Round 2's `s[ceil(n/2)]` minimum bug is verifiably gone FROM THE OUTPUT ITSELF (even n averages
  the two middle values in all five summaries), which is the right way to prove it, since
  `366-grid3.luau` is not committed and I could not read it.
- Claim 4's server/client pair is not the same engine identity: the two files disagree on
  `Workspace parts 27488`/`GridWood 92052` against `parts=2857`/`GridForest parts=0`, and agree to
  the byte on `BaseParts 565.4`, `GraphicsParts 14.9`, `Instances 336.6` plus nine more tags, while
  `Internal`, `LuaHeap`, `TerrainVoxels`, `Gui`, `Animation`, `Navigation` differ exactly as claimed.
  The discriminator moves and the measurand does not, which is the structure the conclusion needs.
- Claim 7's sky rule discriminates: run over 360b's own frames it reads GA 13.01 -> 2.29 %, so with
  the planting deleted the case would not pass at 1.95 %.
- Claim 10's harness lines name `eae6bf53` and `c311f278`, NEITHER of which is the request's
  `Code commit: 4330c6ca`. That is carried only by the docs-only exemption, and I checked the
  exemption rather than took it: `harness_gate` in `tools/agents.py` -- "docs-only change: no
  harness line required" -- fires when no path under `CODE_PATHS` appears in either
  `base...head` or `code_full~1..head`, and `.agent-evidence/changed-files.txt` has 22 entries, none
  under `src/`, `tests/` or `tools/`. `paperwork-after-code-commit.txt` says OK (only
  `reviews/task-366/REQUEST.md` followed the tested commit).

Claim 5's two code facts hold: `src/client/Camera/init.luau` carries the quoted
`RunService:BindToRenderStep(Config.RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, update)`,
and `src/client/Camera/Rig.luau`'s header is "Camera.Rig: THE ONLY WRITER OF
workspace.CurrentCamera IN src/". Claim 9 holds: `366-attrs-BEFORE.txt` / `366-attrs-END.txt` are
identical, and `366-census-EDIT.txt` / `366-census-END.txt` are identical down to
`PlantEpoch=58575af518ae6156` and `parts=108396`.

## Notes (non-blocking)

- `MEASUREMENTS.md` section 1, "What the resident wood is (`evidence/366-client-census.txt`): 10,353
  MeshParts plus 901 Parts; ... `Anchored` 11,254; `CastShadow` 11,254" -- the cited file contains
  none of it. `366-client-census.txt` reads `models=1803 parts=6663` plus a memory-tag list and no
  property breakdown at all. Fix: cite the probe output that holds those counts, or commit it.
- `MEASUREMENTS.md` section 1, "`CastShadow` 11,254" is contradicted by committed evidence:
  `366-shadow-out.txt` reads "forest parts touched=11254, had CastShadow=true: 9923" over the same
  part count. One of the two is wrong; 9,923 is the one with a committed line behind it.
- `MEASUREMENTS.md` section 1, "does not fall again: `Default` **does not stream out except under
  memory pressure**, which is why nothing is released when the player walks away" -- the walking-away
  case was never measured, and section 9.6 says why ("moving the character to the lobby mid-drive
  did not stick -- the server pulled it back"). The growth 6,663 -> 11,254 is measured; the non-fall
  is an inference from the engine's documented semantics. Say which is which, since it is option D's
  premise.
- `TASKS.md` Builder status, third bullet -- still carries the pair this round WITHDREW, and carries
  it with the sign reversed: "Residency is ~free (camera straight up, same 11,254 resident parts:
  p95 19.2 ms, against 20.2 ms with the forest detached entirely)". In `366-grid3-up.txt` the
  resident side is the DEARER one (ON 20.57 against OFF 18.64), and neither 19.2 nor 20.2 appears in
  any committed file. The later paragraph in the same entry states the correction, so the entry now
  asserts both. Strike the bullet's parenthesis.
- `ESCALATE.md` section 2 item 1 still quotes the uncommitted reading with the committed run's
  sample count: "the camera sat **6,791 studs** from the station it was asked for, constant across 28
  samples over 14 s". The committed `366-camcheck.txt` is 28 samples over 14 s at **7,082**; 6,791
  was the earlier session. `MEASUREMENTS.md` section 2 was fixed this round and `ESCALATE.md` was not.
- `ESCALATE.md` option E, "`Lighting.GlobalShadows=false`: -3.01 ms (-11 %)" -- that is A->C in
  `366-shadow-out.txt`, and C has forest `CastShadow` off as well ("C GlobalShadows=off too"), so
  -3.01 is both levers together. `GlobalShadows` on its own is B->C = 26.91 - 24.23 = -2.68 ms.
  `MEASUREMENTS.md` section 7 marks both shadow figures soft; the ESCALATE table that the Director
  will actually read does not carry that caveat.
- `MEASUREMENTS.md` section 4 and claim 2, "puts the stand's DRAWN-wood cost at `35.38 - 21.73 =
  +13.65 ms`" -- that difference is the cost of EVERYTHING drawn at the stand, not the wood alone;
  the up view draws 125,523 triangles of anything. It is a valid upper bracket and section 3's own
  prose is careful about it ("the lobby's own content costs 31.1"), but "the stand's DRAWN-wood
  cost" and section 0's "~11-14 ms the drawn wood costs" read as if the whole 13.65 were wood.
- `MEASUREMENTS.md` section 3b, "16.6 MB detached, 27.1-27.7 MB attached, in all four pairs: +11.1
  MB" -- `366-grid2.txt`'s first pair is 27.1 against 16.6 = +10.5, not +11.1. The other three are
  +11.1.
- `366-lod.txt` prints no `restored=` line, where `366-forestoff-*.txt` print `restored=true` and
  `366-shadow-out.txt` prints "D restored (control 2)". Its last sample is `Performance 3`, so the
  file does not show `RenderFidelity` put back on the 10,353 MeshParts. The Edit census END proves
  the plant's instance counts intact, but a property is not a count. A restore line would close it.
- Session count is inconsistent across the four documents: the request header and
  `MEASUREMENTS.md` say "Five Play sessions", claim 9 says "after each of the three Play sessions",
  and `ESCALATE.md` and the `TASKS.md` status both say "one Play".
- Claim 10's headline, "it FAILs the same way on `main`", is contradicted by its own body, "The
  failing specs **differ** between runs" -- which is the point being made. "FAILs red the same way"
  or "is red too" would say it.
- Citations: the L-136 answer sends the reader to "claim 9" for the named flakes and the control run;
  they are claim 10. Section 3's `Opaque drawn` column quotes one value per station where rep2
  differs (stand rep2 is 2,482,711 against the table's 2,418,401), and section 4's `Opaque ON vs OFF`
  column likewise omits that ON4/OFF4 read 2,431,239 / 2,390,991 -- the 40,248 delta is identical
  either way, so nothing turns on it.

---
REVIEWER verdict on commit `2624c0779777bb6e32e2c58ea53ac85456c5f973` (round 3) · 2026-11-14 03:47 UTC · session cost $1.91, 36 turns · written by tools/agents.py
