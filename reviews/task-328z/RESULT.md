PASS (item 6, 8, 9, 10 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the herds were seen in the
Forest Test place (130094961655666) at the code commit, from a C1 stand at the hunter's own eye
height — frames `328z-r3-G1.png` / `-G2.png`, which I cannot view and which are described, not
claimed as unseen — but the Rojo behind them was served from `driven-hunt-rev` on :34876, and
**Karen herself has played neither the Forest Test herds nor a shot into one** (the request says so
in "WHAT I COULD NOT VERIFY"). Claims 6, 8, 9 and 10 are animal behaviour and shooting; they are
measured, not judged. The `Match` drive needs no sighting: it is main's, byte for byte.

What I checked rather than took on trust:
- **Claim 1 (the Match drive is main's)**: `changed-files.txt` holds 13 files and not one is under
  `src/server/Match/`, `src/client/Match/`, `src/shared/Drive/` or `tests/server/match_*.spec.luau`.
  `MAX_ALIVE_BOARS = 6` in `src/server/Match/init.luau`, and `grep DEER_PARTY_MAX src/server/Match`
  answers nothing — claims 2, 3 and 4 are closed by deletion as stated. `Boar.CONFIG`'s `maxBoars`
  8, `CHANCE_PER_RELEASE` 0.2 and `MAX_GROUPS_ALIVE` 1 are all in place.
- **`weight = 0` is load-bearing**: `Boar.deerComposition` sums `math.max(0, row.weight or 0)` to
  100 and walks `want = clamp(pick,0,0.999999) * total`; `seen` reaches 100 at `harem`, so the four
  zero-weight rows are unreachable by any `pick`, while the `row.name == wanted` block three above
  ignores weight entirely. **Delete the producer**: strike the four herd rows and `deer.spec`'s
  `expect(herds.hindherd).to.equal(5)` reads nil and fails; give `bigherd` a weight and the 1001-pick
  loop's `compositionSize(drawn) <= 3` fails. The case bites both ways.
- **Claim 7**: `deerAfter(SCHEDULE.drive, 8) == 3` is the fail-first line — slots 9, 12 and 14 are
  `reddeer`, so the old "every row after him is a boar" is false on the shipped script. Arm two
  reaches 1 by parameter and falls back to 0 when the row is made a `hindherd`.
- **Claim 6's arithmetic reproduces from the rows**, through `driveTally`'s own fields: `keepAt<=9`
  gives quiet 9 groups / 5 deer / 53 animals; `<=13` gives normal 13 / 7 deer / 6 boar / 73; busy
  15 / 7 / 83. `leaps` is on slots 2,4,6,8,9,14 = 6 groups, 5+7+6+1+8+5 = 32 animals. `scriptDeer`
  = 5+7+6+1+8+7+5 = **39**, and `Data.MAX_DEER_GROUPS` 40 >= 39. `slotAt(16)` walks past the
  `reddeer` row 6 and answers row 7, as the spec asserts.
- **The override is one writer at the composition root**: `Boar.newRuntime` replaces `SPECIES`
  wholesale (`self._config[key] = value`), and `ForestTestBoot` clones `SPECIES` → `reddeer` →
  `RELEASE` before flipping one value — the same idiom as the six blocks above it. `boarConfig()`
  returns `runtime:config()`, so `releaseLine`'s named ask and `deerAllowed` read the same table.
  Nothing else in the repo writes `world.config.SPECIES`.
- **The cap case is a cap and not a bypass**: `deerGroupsAllowed` with 40 unique sounders answers
  false and with 39 answers true. The live differential at `2b558bb3` (cap 3, three slots refused)
  against `e4a05fbf` (cap 40, 0 refusals) is the producer-deletion test for the boot line itself.
- Harness: `[harness] PASS: 34/34 @ e4a05fbf... (clean tree) scope=all` names the request's
  `Code commit:`; `log.txt` confirms `e4a05fbf` is the last commit to touch `src/` or `tests/`;
  `paperwork-after-code-commit.txt` says OK (only `TASKS.md` and `REQUEST.md` followed). selene,
  stylua and `rojo build` are exit 0.
- Callers I swept for breakage: `forest_stand.spec` (depth only — every changed row kept its
  `northStuds`), `grid.spec` (15 slots, unchanged), `zz_horn.spec` (deepest 360, slot 15,
  unchanged), `forest_line.spec`'s "names only crossings, compositions and parties that exist"
  (every changed row kept its `crossOffset`, all five still used, `composition` dropped where
  `party` arrived), `deer.spec`'s all-rows loops (names unique, every row reachable, every row
  `compositionFormation == "column"`), and the `STAGED.PARTIES` ↔ `COMPOSITIONS` bidirectional case,
  which is the teeth on the `PARTIES` edit. `stagedRow` matches `PARTIES[who]` exactly, so `stags`
  cannot be read as `stag` nor `herd` as `hindherd`.

## Notes (non-blocking)
- `docs/research/INDEX.md`, the 2026-11-05 row — it is **round 1's design, which the Director
  reversed**, and four of its facts are now false: *"the three one-to-three-animal `COMPOSITIONS`
  rows become four herd shapes ... `hinds` 5, `harem` 7, `stags` 6"* (the three drive rows are
  untouched; four NEW rows were added at `weight = 0`), *"`CHANCE_PER_RELEASE` 0.2 -> 0.5"* (it is
  0.2), *"deer in 4 of the Forest Test's 15 slots"* (7), *"`MAX_GROUPS_ALIVE` 1 -> 3"* (it is 1,
  with a per-place override of 40). The note it indexes is correct; rewrite the row from the note.
- `docs/research/2026-11-05-red-deer-herds.md` section 3, "Frequency" — *"`ForestTest.MAX_DEER_GROUPS
  = 3` is overridden at `ForestTestBoot`'s composition root"*. The shipped value is **40**, and the
  request's own iteration row 3 is why it moved. Same stale 3 in the `TASKS.md` 328z row.
- `src/shared/ForestTest/init.luau`, the comment above `STAGED_ATTRIBUTE` — *"this drive carries
  deer in **2 of its 15 slots** (`SCHEDULE.drive` rows 2 and 8) and releases them 200-360 studs
  out"*. This change made that false (7 slots, 85-330 studs), and it is the paragraph that argues
  why the staged-release instrument exists. One sentence.
- `ForestTest.MAX_DEER_GROUPS = 40` vs `docs/design/red-deer.md` section 4.3 — the design fixes
  `MAX_GROUPS_ALIVE = 1` structurally and says *"Two deer groups cannot be out at once"*. The
  Director's 13:20 item 1 queues an amendment for sections 4.2 and 15 (*"Forest Test herds 5-8;
  Match path 1-3"*) and names only group size and chance, so **the Forest Test's deer-group cap has
  no amendment queued**. `Boar.CONFIG`'s own 1 is untouched and the override is at the documented
  composition-root seam, so nothing is wrong in the code — but 4.3 should be on the Architect's list
  beside 4.2 and 15.
- The Forest Test's species mix at `normal` is now **39 deer against 34 boar** (53 %), up from 3 of
  59. That follows arithmetically from the Director's own *"a group comes in about every second
  wave"* at a group of 5-8, and the `TASKS.md` row discloses it — but the Builder's round-2
  escalation called a 19-vs-3 inversion on the Match path *"not what anybody asked for"*, and this
  is larger, in the place Karen actually plays. Worth her eye, and worth a number in front of the
  Architect, before it is read as settled.
- `src/server/ForestTest/init.luau` `releaseLine` — the request's *"`releaseLine`'s
  whole-line-or-nothing"* is not what the code does: `count = math.min(count, room)` **truncates
  silently** (only `room <= 0` prints a held line). Worst-case concurrent animals are now 73 against
  the 60 ceiling (`min(Data.MAX_BOARS, runtime:capacity())`), the first time the script's own total
  has exceeded it. The live drive released all seven herds whole (sizes 5/7/6/1/8/7/5), so it did
  not bite, and at ~13 s between slots only ~5 groups are afoot at once — but peak was not measured,
  as the request says, and a herd that ever truncates will show as a short file and no console line.
- `REQUEST.md` claim 5 and the L-093 answer — *"Delete `weight = 0` from the four new rows and the
  1001-pick loop fails"* is wrong: deleting the field leaves `row.weight or 0` = 0 and the loop
  still passes. The case's real teeth are the second arm (`bigherd` at weight 1000 answers 8) and
  row deletion (`herds.hindherd` reads nil). The case is sound; the sentence describing it is not.
- `src/shared/Flags/init.luau` SHOP `expires` 2026-11-04 → 2026-12-31 — work beyond the task
  (rule 4), declared as such on the row itself, and 2026-12-31 is what fourteen other accepted rows
  in the file carry. Queue the retirement it names: delete the off branch and archive under
  `backups/` (rule 7).

---
REVIEWER verdict on commit `59f3b313e8e298d02bceb69108258d3df8d3318e` (round 3) · 2026-11-05 15:07 UTC · session cost $5.48, 55 turns · written by tools/agents.py
