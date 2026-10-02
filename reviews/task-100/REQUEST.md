# Task 100 — the new gun's look pass (lean lane, behind `NEW_GUN`)

Task: 100
Round: 1
Base: `e312419` (main, after PR #89)
Code commit: `8949dc15764e2e1e6ef92632ef72a0f764ef6a80`

```
[harness] PASS: 32/32 checks @ 8949dc15764e2e1e6ef92632ef72a0f764ef6a80 (clean tree)
[harness2] PENDING — the Director runs it; this request is updated with the line before the review
```

What changed, for one player with `NEW_GUN` on: the barrels stopped being sky-blue, the action
stopped being a pale box, the forend became a round walnut splinter, and the left hand sits on it.

1. **The steel is a dielectric, because `Metal` is what made it blue.** Measured, not guessed:
   `.screenshots/20261001T215631Z-compare-carry.png` tube pixels, median (10, 26, 57), p90
   (48, 79, 112) — blue ≈ 3× red — against the video target's (56, 53, 48). Roblox `Metal` is a
   conductor, so its specular is the sky times the albedo. Verify: `Gun.LOOK.blued` and
   `STEEL_MATERIAL` in `src/shared/Gun`, and `gun.spec`'s "is dielectric…" case — no piece but
   `Bead` is `Metal` or carries reflectance, and `blued` is neutral and under 40 per channel.
2. **The action's proportions came off the Beretta side photo.** Segmented by colour: 160 px of
   action against 1,327 px of barrel = **0.121**; ours was **0.226**. `ACTION_LENGTH` 0.62 → 0.36
   (0.131), `ACTION_WIDTH` 0.30 → 0.255 (0.86 of the barrel pair). Its top face is now the **water
   table** — the tubes' underside — not the bore line it stood up between them on. Verify:
   `gun.spec` "keeps the Beretta side photo's action proportions".
3. **It is round, and nothing square is in the sight line.** `ActionBelly` is an elliptical cylinder
   of the action's full width and exactly its height (a *circular* one of that width would bulge
   0.067 studs above the water table); `FenceLeft`/`FenceRight` wrap the chambers inside the
   standing breech; `TopStrap` carries the lever and the safety. Verify: `gun.spec` "is silver
   against blued barrels…" — every body piece's top is now at or below the rib's **underside**
   (was: its top), the two round fences excepted at the tubes' own outline + 0.015.
4. **The forend is a tapering round splinter in Karen's walnut**, and a mesh still has somewhere to
   land: `woodOffset` is where a MESH goes, because a drawn Cylinder carries a quarter turn a mesh
   must not, and `buildNewGun` drops `ForendTip` if a forend mesh is ever published. The walnut is
   measured off her stock mesh's own lit pixels, (144, 79, 49) / (153, 96, 66). Verify: `gun.spec`
   "gives the forend a round, tapering splinter…".
5. **From 99a, and the hinge did not move.** Flat bars were inside the tubes (y 0.1025…0.1375 of a
   tube spanning 0.0475…0.1925) and now hang under the water table; the hinge hook hung 0.0275
   studs above its own pin and now reaches it; `buildNewGun` gates `addFillLight` on `FIRST_PERSON`
   as `build` does; `stats.woodDrawn` resets per build. `ACTION_BOTTOM` is pinned at -0.14 so
   `Gun.hinge` is bit-for-bit task 99's — `gun.spec` asserts the value. The left hand is seeded onto
   the forend in all three `newGun` poses (it was 0.44 studs forward of it, on the bare tubes).

**Not verified.** No capture with `NEW_GUN` on exists for this commit: `pose.py compare` needs a
running Play session and the harness ends its own. Items 1–4 are measured on task 99's captures and
on the shipped numbers; what they look like after the change is unverified until the Director gives
a session. The aim view's near black slab is not explained — the geometry clears the rib either
way, so it is pose or perspective, and `newGun.aim.eyeReliefStuds` is the dial. The action lost 0.26
studs, so the stock and everything behind it moved 0.26 forward; the cheek has to be brought back
with that same dial. Item 7 of the dispatch was **measured false**: the pale wedge is the action
(139, 148, 165), the walnut beside it is (144, 79, 49) — Karen's stock is drawn and textured.
