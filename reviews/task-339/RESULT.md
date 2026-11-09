PASS (items 1, 2, 3 NOT PROVEN)

## Rule 5, stated so this PASS is not read as rule 5 having been met
Core items 1 (hind AND calf), 2 (calf) and 3 (stag) are what Karen judges by playing. SEEN in her
place: one described first-person frame from the stand of a HIND inside the band at `dz=13.2`, mid
stride with her feet on the ground (claim 7, `339-F1.png`) — the hind half of her sentence. NOT
seen: the CALF (no frame at all; only the 0-in-band count and the `vy1` 12.3..14.9 split), and the
STAG'S BOUND, which claim 8 states itself — *"Nobody has yet seen the stag's bound at speed in a
frame"* (`339-F2.png` is sky, `339-F2b.png` is the same stag standing). The stag's arc rests on
claim 3's numbers and on `deer.spec`'s arithmetic, not on a picture.

## Round 1's blocking finding is fixed
`tests/server/deer.spec.luau`, `it("is 2x the measured height and 3x the measured length for the
stag, within 15 %")` now reads `local BEFORE_APEX, BEFORE_LENGTH, BEFORE_AIR = 2.905, 8.14, 0.340`,
which is `docs/research/2026-10-23-deer-road-leap.md` section 9.1's own row to the digit
(`| stag | 7 | 2.905 | 8.14 | 0.340 |`), and the `APEX_STUDS` comment no longer contradicts it
(*"2x the CONFIGURED 3.000 this row held, which is 2.07x the 2.905 studs his bound actually
measured"*). The case still passes: apex ratio exactly 2.000, length `(8.14/0.340) * 2.12132 *
0.494624 / 8.14` = 3.085 against tolerance 0.45, air `0.494624 / 0.340` = 1.4548 against sqrt(2),
tolerance 0.1 — none of it decided by rounding noise.

## Delete the producer — checked by reading, case by case
- `it("bounds the STAG ALONE, over his own sink...")` — `expect(leap.APEX_STUDS.hind).to.equal(nil)`
  and the loop's `expect(Body.leapApex(kind, leap)).to.equal(0)` / `leapAir` 0 / `leapPlan`
  `(0, 1, 0)` die the moment `hind = 5.132` or `calf = 3.336` returns. `Body.leapApex` returns 0 at
  `if type(apex) ~= "number" or apex <= 0 then return 0 end` BEFORE the `math.max(apex, (sink +
  clearance) / leapSinkShare)`, so the surviving `LIFT_STUDS.hind` cannot float the assertion back
  above zero. Not vacuous.
- `it("switches the leap OFF in a non-leaper's OWN config, in every state (task 339)")` — with
  `leapByKind`'s `air <= 0` / `ENABLED` branch deleted, `other` is `lit` by reference, so
  `expect(other.MODEL.LEAP.ENABLED).to.equal(false)` fails, and so do
  `Brain.leapStarts(..., other.MODEL.LEAP)` (reads `leap.ENABLED ~= true`) and
  `Brain.boundStarts(true, 0, 1, other.MODEL.LEAP)` (`SECONDS` 0.75 > 0, `0 <= 1`, so it would
  answer true). `SPECIES.reddeer.MODEL_OVERRIDES` is `CLIPS`/`ANIMATION_IDS`/band edge/flinch and
  does NOT name `LEAP`, so the lit table really reaches `leapByKind`. No side of any comparison is
  the same engine identity through two names.
- `it("gives the leaping kind its OWN airtime through kindConfig")` — the new
  `expect(Boar.kindConfig(kind, CONFIG).MOVE.LEAP_AIR_SECONDS).to.equal(nil)` for hind and calf
  dies on a revert (it would read 0.4573 / 0.3688).
- `forest_line.spec`, the counts case — `expect(normal.leapingGroups).to.equal(4)`,
  `expect(leaping).to.equal(22)`, `expect(stags).to.equal(9)` and the in-loop
  `expect((party.stag or 0) > 0)` all die if a `hindherd` row gets `leaps` back. Checked against the
  data, not the prose: the four surviving `leaps = true` rows are slots 4 `herd` {stag 1, hind 4,
  calf 2}, 6 `stags` {stag 6}, 8 `stag` {stag 1}, 9 `bigherd` {stag 1, hind 5, calf 2} —
  7+6+1+8 = 22 animals and 1+6+1+1 = 9 stags. The loop's `> 0` assertion is guarded against
  vacuity by the group count above it.
- Claims 1, 2, 7, 8, 9 are Studio readings I cannot re-run. The code could produce them: `ENABLED
  = false` on the per-animal table is read by the only two writers of `_leapFor`
  (`Brain:step`'s `leapStarts` branch and `Brain:spook`'s `boundStarts` branch, both on
  `config.MODEL.LEAP` where `config` is `self._config`), `Runtime:spawn` hands the same
  `animalConfig` to `Brain.new` and to `entry.config`, and `entry.config` is what `stepVisual`
  draws from. The off-branch CLONES `LEAP` before writing `ENABLED = false`, so the shared
  `Boar.CONFIG.MODEL.LEAP` the stag reads is not mutated.

## Paperwork
Harness line `[harness] PASS: 34/34 checks @ fc323305f31521b7d2451567f3d5ad4bd0a1d4ce (clean tree)
scope=all` names the request's `Code commit:` exactly and says "(clean tree)";
`paperwork-after-code-commit.txt` says only `reviews/task-339/REQUEST.md` followed it. Rule 7's
archive exists (`backups/task-339-hind-calf-apex.md`) and names what to restore and what else must
be undone with it. selene (src and tests), stylua and `rojo build` all exit 0. No secret, no
absolute user path, no non-noreply address in the diff. `5.132`/`3.336` survive only in the
archive, two comments, the research note's history table and notes-only files, so claim 5's grep
holds; `APEX_STUDS` has exactly the two readers claimed (`Body.leapApex` and its own type guard),
and no spec outside `deer.spec` names `leapApex`/`leapAir`/`leapPlan`/`leapByKind`.

## Notes (non-blocking)
- `src/server/Boar/init.luau`, `LEAP.SECONDS` — the paragraph above the new task-339 line still
  reads *"the Brain does not, so it holds the longest of the three (the stag's 0.49 s)"*, which the
  line two below now contradicts. Delete the stale clause rather than appending to it.
- `docs/research/2026-10-23-deer-road-leap.md` — the new section is `### 9.6` but is inserted
  between 9.2 and 9.3, so the file reads 9.1, 9.2, 9.6, 9.3, 9.4, 9.5. Section 9.2's lever table
  also still shows `hind 5.132, calf 3.336` in its "after" column with no pointer to 9.6.
- `tests/server/deer.spec.luau`, the 2x/3x case — the header says the three constants are *"the
  MEANS"*, but section 9.1's table labels its numbers neither mean nor median; the claim of
  provenance is one word stronger than the cited row. Separately, `apexSeen = apex * (BEFORE_APEX /
  BEFORE_CONFIGURED)` is then divided by `BEFORE_APEX`, so that constant cancels and the apex half
  is really `APEX_STUDS.stag / 3.0` — it still dies on a revert, but the measurement does no work
  there.
- `src/shared/ForestTest/init.luau`, `SCHEDULE.drive` slots 2 and 14 — removing `leaps = true` left
  a stray blank line inside each row table.
- `src/shared/ForestTest/init.luau` — slot 2's comment says `leaps` now means *"an animal in this
  group bounds over the road"* while the `driveTally` header says it means *"a STAG in this group
  bounds"*. The header's wording is the one the spec asserts.
- `src/shared/ForestTest/init.luau`, the `WHAT THE NUMBERS COME OUT AT` block — *"13 groups, 59
  animals (boar 11 groups / 56, red deer 2 / 3)"* above the new line is still task 251's and
  contradicts `forest_line.spec`'s 7 deer / 6 boar. The new sentence acknowledges the staleness in
  parentheses instead of fixing the two lines above it.
- `src/shared/ForestTest/init.luau`, the `leaps` doc bullet — the edit left the sentence broken
  mid-parenthesis: *"already behind `DEER_ROAD_LEAP` (which is"* / *"ON in Karen's place)"*.
- Claim 3 — the two readings inside it are in tension: the stag's in-band LEAP lines go 6 -> 10 and
  his out-of-band ones 4 -> 0 at bound-grade `vy1`, while *"bounds attributed to a road crossing"*
  stays 6 of 16. His code and every number he reads are byte-identical, so this is not a defect in
  the change, and the request is honest that it cannot explain it — but it is the one number in the
  request Karen's own eye could contradict, and either the attribution rule or one measured
  sentence would close it.
- `src/server/Boar/init.luau`, `leapByKind` — with `DEER_ROAD_LEAP` on, every BOAR spawn now clones
  config, MODEL and LEAP as well. Verified harmless: `table.clone` is shallow so
  `MODEL.ANIMATION_IDS` stays the same table `Runtime:_modelTemplate` fills in place and
  `newRuntime` has already given each runtime its own, and nothing in `src` compares config
  identity. But `boar_legendary.spec`'s *"FOR EVERY OTHER ANIMAL `kindConfig` IS THE IDENTITY
  FUNCTION"* and `deer.spec`'s `expect(Boar.kindConfig("male", CONFIG)).to.equal(CONFIG)` now hold
  only while the flag is down, which is the state the harness runs in.
- `ESCALATE.md` still derives the calf's flight from `2*sqrt(2*3.336/196.2)`, and the backup note
  and the plan date Karen's earlier sentence 2026-11-07 where the research note and the
  `APEX_STUDS` comment date it 2026-11-06. Notes-only files, named only so claim 5's grep is
  complete.

---
REVIEWER verdict on commit `5472c1b9a13a79690ba645e4563f90af9e5fdec3` (round 2) · 2026-11-09 13:54 UTC · session cost $3.08, 38 turns · written by tools/agents.py
