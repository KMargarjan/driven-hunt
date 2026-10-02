# Task 100 — the new gun's look pass (lean lane, behind `NEW_GUN`)

Task: 100
Round: 2
Base: `e312419` (main, after PR #89)
Code commit: `b18ab732cc39f851fe65f21859b196c5813704fa`

```
[harness] PASS: 32/32 checks @ b18ab732cc39f851fe65f21859b196c5813704fa (clean tree)
[harness2] PASS: 34/34 checks @ b18ab732cc39f851fe65f21859b196c5813704fa (clean tree)
```

1. **Round 1's finding was right, and the FRAME was the whole of it.** `Camera.Viewmodel.update`
   passes `Viewmodel.hinge(gun, state, config)` as `poseHands`'s `barrelsCFrame`, and that is
   `gunCFrame * swing` — identity with the gun shut — never the `Barrels` part's own CFrame, which
   is `at.barrelZ` = -0.831 studs away and is passed to nothing. So `0.649`, right in the barrel
   group's frame, put the glove **0.41 studs behind the forend's rear end**: two hands at the grip
   and none on the wood, which is what the round-1 reload capture shows. The seed is now the
   splinter's own centre **in the Handle's frame**, `(0, -0.0275, -0.1822)`, in all three `newGun`
   poses. Verify: `newGun.*.left.pos` in `poses.json`, and `Gun.pieces`'s `Forend` centre
   `-0.0622 ± 0.30` with `ForendTip` `-0.4822 ± 0.12` — union z `-0.6022…0.2378`, centre `-0.1822`.
2. **And a spec now reads those three numbers, which nothing did before.** `gun.spec` "seeds the
   left hand ON THE FOREND…" computes the `Forend`/`ForendTip` z span from `Gun.pieces` — so the
   bound moves with the wood rather than being written down — and asserts each pose's
   `Viewmodel.DATA.newGun.<pose>.left.pos.z` lies inside it. **Mutation-checked**: with `0.649` put
   back, it fails at `seeded.z <= rear` (`gun.spec:493`, 0.649 against 0.2378) and the harness
   reports 30/32. Restored, 32/32.
3. **The steel is a dielectric, because `Metal` was what made it blue.** Roblox `Metal` is a
   conductor: its specular is the environment times the albedo, and over a field that is the sky.
   Before: tube pixels median (10, 26, 57), p90 (48, 79, 112). After
   (`20261002T021833Z-compare-carry.png`, darkest quartile of the gun crop): **p50 (27, 29, 24),
   p90 (66, 66, 68)**, 219 of 64,903 gun pixels over 90 in any channel — the highlight line. The
   video target's own barrels are p50 (64, 58, 46), so ours are darker and neutral. Verify:
   `Gun.LOOK.blued`, `STEEL_MATERIAL`, `gun.spec` "is dielectric…".
4. **The action's proportions came off the Beretta side photo**: 160 px of action against 1,327 px
   of barrel = **0.121**, where ours was **0.226**. `ACTION_LENGTH` 0.62 → 0.36 (0.131),
   `ACTION_WIDTH` 0.30 → 0.255 (0.86 of the barrel pair), and its top face is now the **water
   table** — the tubes' underside — not the bore line it stood up between them on. `ActionBelly` is
   an elliptical cylinder of the action's full width and exactly its height; `FenceLeft`/`Right`
   wrap the chambers inside the standing breech; `TopStrap` carries the lever and the safety. Every
   body piece's top is now at or below the rib's **underside**, the two round fences excepted.
   Verify: `gun.spec` "keeps the Beretta side photo's action proportions" and "is silver against
   blued barrels…".
5. **The forend is a tapering round splinter in Karen's walnut**, and `woodOffset` is where a MESH
   goes — a drawn Cylinder carries a quarter turn a mesh must not. Verify: `gun.spec` "gives the
   forend a round, tapering splinter…".
6. **From 99a, and the hinge did not move.** Flat bars out of the tubes, hinge hook onto its own
   pin, `addFillLight` gated on `FIRST_PERSON` as `build` does, `stats.woodDrawn` reset per build.
   `ACTION_BOTTOM` is pinned at -0.14 so `Gun.hinge` is bit-for-bit task 99's; `gun.spec` asserts
   the value. The Reviewer is right that these are outside the dispatch's seven items — disclosed in
   TASKS row 100, and queued as the lesson in 100a(h).

**The dispatch's item 7 is answered: FALSE, measured.** In `20261002T012118Z-pose-reload.png` the
near-white wedge is (139, 148, 165) — the ACTION under `Metal` — while the walnut beside it is
(144, 79, 49) and (153, 96, 66): Karen's stock was drawn AND textured all along.

**Not verified.** No capture exists for this commit: `pose.py compare` needs a Play session and the
gate ends its own, so the hand is verified by the spec above and not on screen. Whether the glove
reads UNDER the wood rather than on it is the rotation triple (`yaw`/`pitch`/`twist`), untouched here
and the Director's live dial. The fences and top strap still render pale, p50 (155, 161, 173) from an
albedo of (118, 120, 122) — that is the viewmodel's FILL LIGHT, not the colour, and 100a(i). The
other seven round-1 notes are queued in TASKS 100a; 100a(b), one false sentence in a comment, was
corrected here rather than queued.
