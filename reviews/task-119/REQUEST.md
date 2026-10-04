# Task 119 — the sow and the cub, and the head zone on the real snout

Task: 119
Round: 1
Base: f21260b0f8540a801882b97444248162955bb855
Code commit: f175659caa2f9255743f0bc02e8187a467773797

The base is the head of `task-118-boar-behaviour`, the branch this PR targets: 119 is stacked on 118.

```
[harness] PASS: 33/33 checks @ f175659caa2f9255743f0bc02e8187a467773797 (clean tree) scope=all
```
`[harness2]`: **N/A.** Nothing in this task touches `src/server/Match/`, `src/server/MatchBoot...`,
`src/client/Match/`, `src/shared/Drive/` or their specs; the branch's own diff against its base is
`src/server/Boar/`, `src/server/BoarAssetsBoot...`, `src/serverstorage/Assets/`, three specs and the
harness's scope table. (118's own Match change is below the base and was gated at `f21260b`.)
CI is red for ONE reason that is **task 117's and must not be fixed here**: `tools/boar_prep.py`'s
selftest still says "ten clips" with sixteen in the tuple.

## Claims

1. **Two animals prepped and uploaded, one run each.** `tools/boar_prep.py` with nothing changed but
   `--animal` and `--length-studs`; female `73776255349661` (13,644 tris, 4.675 studs), cub
   `78344628955312` (12,234 tris, 2.475 studs), both Approved, both recorded in `assets/uploads.json`
   with Karen's 2026-10-03 OK verbatim. *Verify:* the two rows in `src/serverstorage/Assets/init.luau`
   — their `sizeStuds` are the LOADER'S OWN measurements, printed by `BoarAssetsBoot` off the live
   assets (female 1.2019/2.6473/4.6750, cub 0.6177/1.4389/2.4749).
2. **A sounder is a sow with young; a lone animal is a male; every box scales with the animal.**
   *Verify:* `boar_kinds.spec` (five cases: the lengths, every zone at 0.45, the protrusion still
   proud at every size, the makeup by roll, and "with the FLAG off, every animal is the male-sized
   box this game has always spawned"); `boar_behaviour_live.spec`, "spawns a sow and cubs, each on its
   own box, and every one of them lives" — four real bodies, the sow first, a cub's `ZoneChest` at
   0.45 of the male's, all four alive 1.5 s later.
3. **The male's published clip ids play on all three, measured, so nothing was republished.** In a
   live session every hoof lands at **0.86** (sow) and **0.41–0.43** (cub) of the male's height — its
   own scale, no absolute-translation leak and no stretching. What did need a number is the stride:
   each animal's own ground speed is **0.8553** and **0.4372** of the male's, identically on walk,
   trot, run and dig, and `clipScale` is that. *Verify:* `boar_kinds.spec`, "rates a smaller animal's
   clips off its OWN measured stride" (at 12 studs/s both play `trot`, the male at 1.17 and a cub at
   2.68 = 1.17 / 0.4372).
4. **A shot at the drawn snout is a head shot.** The head box hung 1.15 studs in FRONT of the snout
   (grey-box geometry); it is now the skull, sited off the rig's own bones measured in a Play session,
   and the chest moved back one stud onto the shoulder because the head cannot sit where it belongs
   while another zone part is there. *Verify:* `boar_zones.spec`, "is a HEAD shot at the drawn snout"
   — a real ray at the `nose` bone's own measured point — plus the moved front/above/flank cases.
   The flank limit is asserted too, as `body`, rather than left unsaid.
5. **Every cub the drive released used to vanish inside a second, and that is fixed.** A boar is
   spawned at `field.groundY`; the map's real surface is ~2 studs above it (measured: a released sow
   settles with her box bottom there), so every boar spawns embedded — a male's 3-stud box has its
   top above the surface and is pushed out, a cub's 1.35-stud box is entirely below it and is
   ejected. Every kind is now dropped from the MALE's height, so the flag-OFF world spawns exactly
   where it always did. *Verify:* `Runtime:spawn`'s comment carries the measurement; confirmed live —
   a sow, a male and a cub running together (`119-file.png`).

## Screenshots (rule 5), flag-ON Play session, 2026-10-04, `.screenshots/` (git-ignored)

- `119-file.png` — a striped tan cub nearest the camera, the dark sow behind it and the bigger male
  behind her, strung out one behind the other across open ground.
- `119-size.png` — the male facing the camera at ~20 studs with the cub beside him: about half his
  length and a third of his height, tan and striped against his black.
- `119-headshot.png` — the hit marker drawn on the boar's snout and the readout bottom-left:
  **"Alhamdulilah824 BOAR head"**. Before this task that same shot was charged `body`.

## What I could not verify

- **Nobody has judged the feel**: 0.85 and 0.45, the sow-and-young makeup and the 1-in-4 young male
  are all Karen's dials, and nobody has seen a drive of them.
- **The cub's own clips are never played** — all three animals play the male's ids. The package ships
  a cub set; whether the cub's own gait reads better is unasked and unmeasured.
- **The flank head shot is `body`** and always was: the drawn head is 1.1 studs wide inside a 2.0-wide
  trunk. Front and above are `head`. The only fix is a narrower trunk at the front.
- **The moved CHEST is a gameplay change nobody asked for.** It was on the drawn animal's neck; it is
  now on the shoulder. The damage numbers are untouched, but where the vital zone IS has moved by one
  stud and the Director can reverse it.
