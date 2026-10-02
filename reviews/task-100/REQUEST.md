# Task 100 — the new gun's look pass (lean lane, behind `NEW_GUN`)

Task: 100
Round: 1
Base: `e312419` (main, after PR #89)
Code commit: `5aa672ef42f95794ef6f6580ca57984cef8f7130`

```
[harness] PASS: 32/32 checks @ 5aa672ef42f95794ef6f6580ca57984cef8f7130 (clean tree)
[harness2] PASS: 34/34 checks @ 5aa672ef42f95794ef6f6580ca57984cef8f7130 (clean tree)
```

With `NEW_GUN` on: the barrels stopped being sky-blue, the action stopped being a long pale box,
the forend became a round walnut splinter, and the left hand came off the top of the barrels.

1. **The steel is a dielectric, because `Metal` was what made it blue.** Roblox `Metal` is a
   conductor: its specular is the ENVIRONMENT times the albedo, and over a field that is the sky, so
   no albedo could have fixed it. Before (`20261001T215631Z-compare-carry.png`): tube pixels median
   (10, 26, 57), p90 (48, 79, 112) — blue ≈ 3× red. After (`20261002T021833Z-compare-carry.png`,
   darkest quartile of the gun crop): **p50 (27, 29, 24), p90 (66, 66, 68)**, and 219 of 64,903 gun
   pixels exceed 90 in any channel — the highlight line. The video target's own barrels in the same
   frame are p50 (64, 58, 46), so ours are now darker and neutral rather than blue. Verify:
   `Gun.LOOK.blued`, `STEEL_MATERIAL`, and `gun.spec` "is dielectric…" — no piece but `Bead` is
   `Metal` or carries reflectance, and `blued` is neutral and under 40 per channel.
2. **The action's proportions came off the Beretta side photo.** Segmented by colour: 160 px of
   action against 1,327 px of barrel = **0.121**; ours was **0.226**. `ACTION_LENGTH` 0.62 → 0.36
   (0.131), `ACTION_WIDTH` 0.30 → 0.255 (0.86 of the barrel pair). Its top face is now the **water
   table** — the tubes' underside — not the bore line it stood up between them on. Verify:
   `gun.spec` "keeps the Beretta side photo's action proportions".
3. **It is round, and nothing square sits in the sight line.** `ActionBelly` is an elliptical
   cylinder of the action's full width and exactly its height (a *circular* one of that width would
   bulge 0.067 studs above the water table); `FenceLeft`/`FenceRight` wrap the chambers inside the
   standing breech; `TopStrap` carries the lever and the safety. Verify: `gun.spec` "is silver
   against blued barrels…" — every body piece's top is now at or below the rib's **underside** (was:
   its top), the two round fences excepted at the tubes' own outline + 0.015.
4. **The forend is a tapering round splinter in Karen's walnut**, and a mesh still has somewhere to
   land: `woodOffset` is where a MESH goes, because a drawn Cylinder carries a quarter turn a mesh
   must not, and `buildNewGun` drops `ForendTip` if a forend mesh is ever published. Verify:
   `gun.spec` "gives the forend a round, tapering splinter…".
5. **From 99a, and the hinge did not move.** Flat bars were inside the tubes (y 0.1025…0.1375 of a
   tube spanning 0.0475…0.1925) and now hang under the water table; the hinge hook hung 0.0275 studs
   above its own pin and now reaches it; `buildNewGun` gates `addFillLight` on `FIRST_PERSON` as
   `build` does; `stats.woodDrawn` resets per build. `ACTION_BOTTOM` is pinned at -0.14 so
   `Gun.hinge` is bit-for-bit task 99's — `gun.spec` asserts the value.
6. **The left hand is on the forend**, seeded in all three `newGun` poses; it was 0.44 studs forward
   of the forend's front end, out on the bare tubes, and showed as a glove beside the bead.
   Verify: `newGun.*.left.pos` in `poses.json` is (0, -0.16, 0.649), the splinter's own centre in
   the barrel group's frame, and `20261002T021839Z-compare-aim.png` — no glove near the bead.

**The dispatch's item 7 is answered: FALSE, and it was measured before anything was changed.** In
`20261002T012118Z-pose-reload.png` the near-white wedge reads (139, 148, 165) — a blue-grey, which
is the ACTION under `Metal` — while the walnut beside it reads (144, 79, 49) and (153, 96, 66), two
different values, so Karen's stock was drawn AND textured all along. Nothing was changed for it; the
action was the white thing in that frame and claim 2 is its fix.

**What the three new captures show, as they are** (`NEW_GUN` on, Player1, 2026-10-02):
- `021833Z-compare-carry`: near-black tubes with one thin grey highlight down each, crossing lower
  right to upper left like the target. Bigger in frame than the target, and no hand or stock in it.
- `021839Z-compare-aim`: the target's layout at last — two round fences, the top strap with its
  lever, walnut comb in front, bead on the centre cross. But the fences and strap read **pale
  blue-grey, p50 (155, 161, 173)**, where the target's metal there is dark, and the comb spans only
  ~15% of the half-frame's width at the bottom against the target's ~50%.
- `021845Z-pose-reload`: barrels hinged down and near-black (mean 28, 24, 22), a brass rim
  (mean 156, 127, 97) in one chamber mouth, walnut forend (mean 136, 102, 66) under the left glove.
  The action still reads pale (mean 131, 132, 131) and the right sleeve's olive cuff fills the right
  third of the frame.

**Not verified / known open.** The pale metal is NOT the albedo alone — (118, 120, 122) rendering at
(155, 161, 173) is the viewmodel's own fill light, which no claim here touches; a darker action needs
that light or `Gun.LOOK.action`, and it is a one-number content change, not this task. The action
lost 0.26 studs, so the stock moved 0.26 forward; `newGun.aim.eyeReliefStuds` is the dial that brings
the cheek back onto the comb, and the comb's narrowness is partly that and partly `STOCK_SIZE`. The
`gun.stock` row still has no `fallbackColor`, so a texture that failed to load would show white.
