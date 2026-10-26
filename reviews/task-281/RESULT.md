PASS (item 1, 2, 3 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing has been SHOT at in
Karen's place. No player has hit a deer in the neck, along the back, or on a calf's leg on screen,
and no hit card has been seen with the `neck` word or a dorsal-band hit on it. What was seen is
three DEV frames of the volumes drawn over the mesh (`.screenshots/20261026T2245*-281-{stag,hind,
calf}-side.png`, described in the request; I cannot open them). The request says so itself and
reserves the mouse for the Playtester. Items 1 (the back line), 2 (the neck zone) and 3 (the calf's
legs) are therefore NOT PROVEN in her place.

Delete-the-producer, done by reading, per case the request offers:
- claim 1, "covers the drawn back line": with the bands removed, `bandTop <= firstTop + 1e-6` is
  true for `body` and `rear` on all three kinds (highest box becomes the barrel/rump), so the case
  errors. The mesh half is a real second instrument, not the same box read twice. Survives nothing.
- claim 2, "charges a neck hit like the chest": delete `CLASS.neck` -> `hitClass` returns
  "nonVital"; delete `DAMAGE.neck` -> `chargedZone` returns "body" and `slug` is 55 against
  `LETHAL`; delete `SPECIES.reddeer.ZONES.neck` -> `geometry.zones.neck` is nil and `neck.part`
  errors. `damageFor("neck",...) == damageFor("chest",...)` is two distinct table rows, not one
  value through two names.
- claim 3, the calf's twelve leg boxes: pinned by `COVERAGE_FLOOR.calf = 0.46`. Worked the 0.25
  grid by hand: calf trunk 0.891 x 2.376 x 3.49, z samples hit -0.245 (inside the new front boxes'
  z -0.285..-0.165) and the shaft/shin/hoof y spans catch ~6 cells, while task 280's stubs
  (y -1.103..-0.963, -0.583..+0.017) catch ~0 at any sampled y. Bands add ~4. 6 + 4 = the observed
  22 -> 32. Remove the legs and the calf reads ~26/63 = 41 %, under the floor. Non-vacuous.
- claim 4/5, the sweep: not vacuous on a missing mesh -- `BOAR_MODEL.default = true`, and
  "has a drawn mesh to be measured against" asserts `#meshes >= 1` when `MODEL.ENABLED`.
- claim 8, the four known-bad points: the loosening is sound. The vacuity guard (`airPoints < 3`)
  bites, and on the calf the fourth point (y -0.713, z -0.175) is inside the new front-left/right
  shaft boxes (y -0.828..+0.372, z -0.285..-0.165), which is where the drawn leg is -- so `legs`
  there is correct and the mesh ray, not an assumption, is what says so.

Checked for a second writer and for a downstream crash on the new zone word: `Wound.chargedZone` /
`row` / `hitClass` / `FLIGHT` all fall back rather than index nil; `Hits.targetOf` has no zone
whitelist; `Hud.killLineText`'s `%-6s` fits "neck"; `BoarArt` does `RING[zone] or RING.body`;
`Match.Score` prices by kind and not by zone; `report_silhouette.spec` iterates
`Report.CONFIG.ZONES` -> `WOUND.DAMAGE` one way only, so a sixth DAMAGE row does not break it; the
boar's `CONFIG.ZONES.ORDER` is untouched, so no boar can carry a `ZoneNeck`. Lint, stylua and rojo
clean; harness line names the `Code commit:` with "(clean tree)" and
`paperwork-after-code-commit.txt` says OK.

## Notes (non-blocking)

- `reviews/task-281/REQUEST.md` claim 7 — the fail-first evidence was produced against a
  PRE-FINAL revision of the spec, not the committed one. It quotes `deer_hitbox.spec:389 ... under
  the 66.0 % floor`, but committed `COVERAGE_FLOOR.stag` is `0.64`; and `:494` / `:626` do not hold
  the quoted lines in the committed file (the dorsal-band error is at the `error(` after
  `bandTop <= firstTop`, and 626 is `expect(neck.part)`, which would index nil with 'part', not
  'boxes'). The CONCLUSION survives by reading: 61.9 % < 64.0 %, and the three other quoted
  failures follow from the old config. Re-run the fail-first against the committed specs and paste
  that, or say in the request that the floors were lowered after the run and why.
- `tests/server/deer_hitbox.spec.luau` / `COVERAGE_FLOOR` comment — "losing the dorsal band, the
  neck or the calf's twelve leg boxes fails here" overstates it for the neck: `neck` carries task
  280's own boxes, so renaming the zone back to `chest` changes no ray's answer and no cell of the
  sweep. The neck is pinned by "charges a neck hit like the chest" and by the centres case, which
  is enough -- the comment should say so.
- `tests/server/deer_hitbox.spec.luau` / "covers the drawn back line" — on the STAG the `rear`
  croup band (y +1.86..+2.04) falls between the sweep's y samples (1.85 and 2.10 off
  `-half.Y - GRID` at 0.25), so the coverage floor cannot see it; only this case guards it. Worth a
  sentence, since the floor is advertised as the guard against a lost volume.
- `tests/server/deer_hitbox.spec.luau` / the `above` probe — it asserts only
  `type(zoneAbove) == "string"`, so another zone's box answering a tenth of a stud over the barrel
  would pass while the comment says "THE BAND IS WHAT ANSWERS". `expect(zoneAbove).to.equal(zoneName)`
  is the assertion the comment describes, and it holds on all three kinds as committed.
- `src/server/Boar/init.luau` / `SPECIES.reddeer.ZONES.neck` and `KINDS.calf.zones.neck` — the
  throat box overlaps the WIDER `chest` thorax box in z on the stag (neck z -2.065..-1.165 against
  chest -1.286..+0.800, overlap 0.12 studs) and on the calf (throat z -0.675..-0.325 against chest
  -0.465..-0.010). A flank ray meets the wider box first, so the base of the throat answers `chest`
  and not `neck`. Both are vital with identical damage, so nothing a player feels changes -- but
  claim 6's "no band meets another zone's box" is about the BANDS only and should not be read as
  covering the neck/chest seam.
- `src/server/Boar/init.luau` / `KINDS.calf.zones.legs` — the front-left and front-right triples
  share identical y and z spans (hoof y -1.188..-0.948 z -0.345..-0.285, etc.), so the left-side
  box is always shadowed by its right-side twin on a +x flank ray. Six of the twelve are
  unreachable from the flank, and "every box's centre answers SOME zone" passes on the twin. Same
  zone word, so no behaviour change; the loop just does not prove what it looks like it proves.
- `src/server/Boar/init.luau` / `KINDS.hind.zones.body` — the band over her loin tops at +2.087
  against her trunk half-height of 2.053 (4.8 x 0.8553 / 2), so 0.034 studs of it stand above the
  trunk box. The 0.25 sweep samples 1.947 and 2.197 and cannot see that sliver; the request's own
  0.06 fitter is what says it is inside her drawn back. Nothing to fix if the measurement holds --
  record it, because the spec's "AIR 0" does not cover it.
- `src/server/Boar/init.luau` / the new bands — at 0.180 studs (stag croup) these are the thinnest
  zone volumes in the game, which tightens `Validator.judgeClaim`'s `span + REACH_SLACK +
  displacement` waiver further on a deer. That is 280a (e), still unmeasured; this change makes it
  a little worse and should be named in that row.
- `tests/server/deer_hitbox.spec.luau` / `COVERAGE_FLOOR.stag = 0.64` — against a measured
  65.7-66.4 % with a disclosed +/-0.7-point run variance, worst-case headroom is about one point.
  A flake here fails the whole harness. The hind (2.6) and calf (4.8) have room; the stag is the
  one to watch.
- `src/client/Hud/BoarArt.luau` — a `neck` dot draws with `RING.body`, the trunk's colour, because
  `Report.CONFIG.ZONES` has five zones. Disclosed in the request and queued, not fixed; queue it
  with `Report.CONFIG.ZONES` gaining a sixth rect, since the zone WORD is right everywhere else.
- `docs/design/red-deer.md` 7.3 and `docs/design/hit-zones.md` 4 — stale since task 280 and now
  also silent on `neck` and on the dorsal bands. 280a (f), the Architect's; the change made the gap
  wider, not the game wrong.
- `reviews/task-281/REQUEST.md` PLAN — written after the measurement rather than before the `src/`
  edit, and says so. Disclosed honestly; nothing to fix this round.

---
REVIEWER verdict on commit `f368929e6958aa1b77aa19292857097ae8224b0c` (round 1) · 2026-10-26 22:57 UTC · session cost $3.95, 38 turns · written by tools/agents.py
