PASS (item 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: **nothing was seen in Karen's
place and nothing was shot.** Phase A is docs only (`changed-files.txt`: `TASKS.md`, the note, the
design, `docs/research/INDEX.md`, three `reviews/task-306/` files; no `src/`, `tests/` or `tools/`
path), so the harness exemption is correctly claimed and `paperwork-after-code-commit.txt` says OK
(only `REQUEST.md` changed after `4324c817`). Claim 7's *documentary* assertion is true — §11.1 does
carry the 12 cases, rule L's known-bad control, T4 in §12 and B9 in §16 — but the twelve hits, T3's
two screens, T6's sweep and T1 walked are B1/B5/B6/B8/B9's and exist today only as sentences. Every
geometric number in both documents is arithmetic over earlier tasks' readings
(`evidence/p306-lobby.txt`, `evidence/p298/walk-after.txt`) or over shipped constants, which both
documents say (note §7's closing paragraph, design §14).

Rule 3(a), delete the producer, done by reading: the proofs offered are documents, and each
verification reads the thing it proves (§2's rows, §2.2's worked arithmetic, §4's tables, the §2
source rows, `grep "^| 306 " TASKS.md`), so deleting the deliverable fails the check — **except**
claim 3's second half, "neither number equals any shipped pace", which no number could fail. The
producer-coupled form of that check is already in the design: §11.2 group 5's
`crossingSeconds(WINDOW_STUDS, paceSpeedFor(w)) == 5.00 / 2.50` exactly. I re-derived §2.2, §2.3,
§2.4, §2.6, §5.2, §6, §7.3 and T9; what did not reproduce is in the notes. Shipped constants the two
documents lean on were read back and are right: `Range.LAYOUT` (`SPOT_COUNT` 1, `SPOT_SPACING_STUDS`
24, `WINDOW_STUDS` 40, `APRON_STUDS` 20, `SCREEN` 10×8×1 `beyondStuds` 6, `BERM` 160×10×6
`behindStuds` 12, `MAT` 8×1×8, `POST.aheadStuds` 7 / `sideStuds` 3, `PROMPT.MaxActivationDistance`
12, `PLATE` 120/80), `Lobby.ANCHORS["forest-test"]` (2850, −2950), `FIELD.SPAN_STUDS` 220,
`WALKWAY_HALF_STUDS` 24, `DEPTH_STUDS` 48, `CLEAR_STUDS` 96, `TREELINE` 30/100/0.6/5.68/9,
`HighSeats.DIMS.DECK_RISE_STUDS` 12.5 / `RAIL_RISE_STUDS` 2.4 / `LADDER_OFFSET_STUDS` −4.0 /
`MAX_FOOT_SPREAD_STUDS` 4.0, `HitLog.rowWorthy` = `not RangeData.isTarget(part)`,
`Cast.candidates`' `GetPartBoundsInRadius` with `FilterDescendantsInstances` (so the §4.3 ignore seam
really does remove a body from the bounds query *and* from the static pass — `castWithRewind`'s
`staticIgnore = table.clone(ignore)`), `ignoreFor`'s shipped two-entry list, `Camera.Rig` as the one
`LocalTransparencyModifier` writer on the local character, and `ForestTestBoot`'s `rangeHomeAreas` =
`RangeData.footprintFor(...)` composed in the root. `forest_stand.spec.luau` does assert `exitZ`
−2377, `minX` 2230, `maxX` 3830. Nothing in the brief is left undone: §2.1's eight bullets, §2.2,
§2.3, §2.4, §2.5 and §2.6 all have an answer, and both stated deviations (§4.2, §5.3) are routed as
§15 open decisions with B1–B4 independent of them. selene, stylua and `rojo build` are clean; no
secret, local path or non-noreply address in the changed files.

## Notes (non-blocking)

- `docs/design/shooting-range-lobby.md` §6 and §14 item 11 — the gait-band claim is wrong on the
  repo's own numbers. The design says *"`model.RUN_FROM = (TROT_SPEED + RUN_SPEED)/2` already bands
  7.20 as a walk/trot and 14.40 as a trot/run"*. `Body.luau`'s `gait` is
  `if speed >= model.RUN_FROM then "run" elseif speed >= model.TROT_FROM then "trot" else "walk"`;
  for the boar `TROT_FROM = BOAR_CLIPS.walk.groundStudsPerSecond * WALK_MAX_RATE` = 2.852 × 1.8 =
  **5.13** (`Boar.CONFIG`'s own comment) and `RUN_FROM` is **21** (`(TROT_SPEED 18 + PACE.RUN_SPEED
  24)/2`; 28 for the stag). So **both** new paces, 7.20 and 14.40, land inside the single TROT band —
  `slow` and `fast` will be drawn with the same clip at two rates, not as two gaits. Also the formula
  as written mixes `Boar.CONFIG.TROT_SPEED` 18 with `PACE.TROT_SPEED` 11. Fix §6's sentence and
  restate §14 item 11 as "both new paces are one trot clip; does that read as two paces".
- `docs/research/2026-10-28-the-range-in-the-lobby.md` §5.2 — the table contradicts itself. The
  `slow` row's rule is *"5.0 s across the window (ISSF)"*, its column header is *"Studs/s at a
  36-stud window"*, and its cells are 7.14 and **5.04 s**; 36 / 5.0 = 7.20 and the crossing is 5.00.
  The speeds are derived from the unrounded 35.714-stud window, which design §6 catches and corrects
  — the note itself does not, and the `TASKS.md` row 306 carries 7.14 / 14.29 forward. One line in
  the note's table header would close it.
- Design §2.2 against §5.3 / §5.4 — the cover banks are placed 4 studs apart in two sections.
  §2.2 uses `bankOut = laneHalf + BANK.beyondStuds + BANK.X/2 = 50` (the shipped `screenOut` shape,
  i.e. the bank's *centre*), which puts the west bank at x 2544..2556; §5.3 and §5.4 state
  *"x 2548..2560 and 2760..2772"* and *"outer faces x 2548 / 2772"*. Under §2.2's placement the
  derived berm (224 wide, 2548..2772) stops 4 studs short of each bank's outer face, so the identity
  §5.2 states and §11.2 group 4 asserts — *"the berm spans every station's lane plus both banks"* —
  is false by 4 studs at each end. Pick one placement in the document; B2's spec asserts the identity.
- Design §2.5, the tree argument — reading (ii) rests on a premise its own table disproves:
  *"the range's easternmost part is at x 2724"*, while the same table's clearance column uses
  *"east cover bank, outer face x 2772"* and §5.2 puts the berm's east face there too. The conclusion
  ("no tree need be removed", so no rule-7 archive) does survive a re-derivation — every part east of
  2724 is at z ≤ −3180 and every lobby crown edge is at z ≥ −3061.5 — but the stated reasoning does
  not cover the banks or the berm. Related: `TREELINE`'s westernmost possible trunk is
  2850 − 100 − `JITTER_STUDS` 9 = **2741**, not the stated 2750.
- Design §2.5 clearance column — several rows do not reproduce from the coordinates printed beside
  them: lodge plinth (2831, −2919) to mat 6 (2724, −3026) is **151.3**, not 145; LodgeSpawn
  (2844, −2937) is **149.4**, not 146; Logs (2816, −2912) is **≈146**, not 127; the gather pad's
  corner (2748, −2980) to the ladder foot (2721, −3011) is **41.1**, not 31. §2.5's door-to-mat-6
  *"172.9 studs"* also disagrees with §2.6's straight-line **166.5** for the same two points. Every
  one is non-decisive (all ≥ 100 studs except the gather pad, where the stated figure is the
  conservative one) and §14 item 2 already routes them to B1's census — but B1 should recompute, not
  confirm.
- Design §12, T9 — *"12 + 6 benches + 6×14 stands = 102 in her place, 109 in DEV"*. §5.4's own list
  adds berm 1 + cover banks 2 + side banks 2 + plate 1 = 6 parts in DEV, i.e. 108. The ≤ 160 bound
  holds either way.
- Note §3 — *"Roblox has no per-player visibility for a server-created part"* is too strong, and it
  is the sentence that refuses pattern 2 and is carried verbatim into `TASKS.md` row 306 and the
  brief. `BasePart.LocalTransparencyModifier` is exactly per-player visibility of a server-created
  part, client-side — which is what design §4.2/§4.4 then adopt. The accurate form is "no
  *server-driven* per-player visibility"; pattern 2's refusal then needs its real reason (six times
  the geometry, and a man who walks over still sees the lot), which the note already gives.
- Design §4.4 — the stated fallback contradicts the same subsection's boundary. §4.4 says `Mask`
  *"never touches `CanQuery`, `CanCollide`, `Transparency`"*, and then names *"a client-local write of
  `Transparency` on the same parts"* as the fallback if `LocalTransparencyModifier` does not hide a
  skinned MeshPart (§14 item 8). `Boar.Body` writes `Transparency` at `attachVisual` and under
  `MODEL.HIDE_BOX`, so the fallback makes the client a second writer of a property the server owner
  writes. B6 needs a decision from the Director if the primary fails, not a fallback that is taken
  silently.
- Design §8, §10, §16 — the `RANGE` flag is never named. `Range.ENABLED = Flags.isOn("RANGE")` is
  dark (`Flags`' own LIT/DARK list, `MAX_FLAGS` 20) and `ForestTestBoot` gates the home area on it:
  `if row ~= nil and RangeOwner.ENABLED then rangeHomeAreas = {...}`. So in her place the new site is
  only home once the Director lights the flag, which T1 and T7 (B8) depend on. One sentence in §8 or
  B8 would say it.
- Design §4.4, §7.4 — nothing says what a man who walks downrange meets. The mask writes only
  `LocalTransparencyModifier`, `CanCollide` is untouched, and §2.3 puts home out to z −3237, so a man
  can walk into up to five invisible, solid animals in the shared corridor. B6/B7's problem, worth a
  line in §14.
- Design §11.2 group 1 — the four literal footprint numbers are a transcription of `footprintFor`'s
  own formula (verdict 278's rule). What can actually fail there is the half that reads the other
  owners — `Lobby.CONFIG.PADS`, `Lobby.ANCHORS`, `ForestTest.boundsOf(ROAD_LAYOUT)`, `insideHome`
  sampled every 8 studs — which the design rightly keeps. Derive the literals from `LAYOUT` in the
  spec rather than typing §2.2's output twice.
- Note §4 — *"about 304 studs across x and 222 along z at today's `BERM.size.X` of 160"* mixes bases:
  304 follows from today's berm, but 222 needs the new 179-stud station (today's `DISTANCE_STUDS` 125
  gives ≈168, which a 220-wide field would hold). The conclusion — an extra home area is required
  whatever site is chosen — rests on the x axis alone and is unaffected.
- Design §7.3 — *"deck centre to post top is `sqrt(3² + 21²)` = 21.2 studs"* drops the Y term
  (`DECK_RISE_STUDS` 12.5 against `POST.size.Y` 4), so the true separation is 22.9. The conclusion
  (outside `MaxActivationDistance` 12) holds with more margin than stated.

---
REVIEWER verdict on commit `e1e3da117ee5aaac499e3d6cd627c3d8d13a2591` (round 1) · 2026-10-28 13:12 UTC · session cost $3.59, 40 turns · written by tools/agents.py
