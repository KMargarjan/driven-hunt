# Task 224: the lever-action rifle, bought in the shop

Task: 224
Round: 1
Base: `747d628` (main, the task-223 merge)
Code commit: `bb1c01aa8348800f99ba20044b55e15a27558dff`

```
[harness] PASS: 33/33 checks @ bb1c01aa8348800f99ba20044b55e15a27558dff (clean tree) scope=all
```

`test2` is **N/A**: not one file in this diff is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The diff
touches `src/shared/Lever/`, `src/shared/Weapons/`, `src/shared/Gun/`, `src/shared/Rifle/Geometry.luau`,
`src/shared/Shop/`, `src/shared/Viewmodel/`, `src/server/Weapon/`, `src/server/Economy/`,
`src/serverstorage/Assets/`, `src/client/Camera/Viewmodel.luau`, `src/client/CameraBoot.client.luau`,
`src/client/Weapon/Sound.luau`, `src/client/Hud/ShopDisplay.luau`, `tools/` and docs — the match, the
drive, the tie and the teams are untouched.

**What this is.** A third weapon: a Ruger-made Marlin 1895 SBL in .45-70, open-sighted, five rounds
in a tube, sold in the shop. Built to `docs/design/lever-rifle.md` (ARCHITECT **PASS**, no blocking
open decisions), from `reviews/task-224/BRIEF.md`. Research note
`docs/research/2026-10-20-lever-action.md` + INDEX row.

---

## Claims

**1. It is a row, and it reads NOTHING out of the other rifle.** `Weapons.ROWS.lever` is built field
by field from `Lever.CONFIG`; the two rifles share no number, only machinery — `Rifle`'s own header
is the rule.
*Verify:* `tests/server/lever.spec.luau`, "is a third weapon on slot 3, and it reads NOTHING out of
Rifle.CONFIG" and "is built field by field from Lever.CONFIG" (a `pairs` walk with a skip set, so a
number that moves fails the harness).

**2. The .45-70 is fitted, then predicts.** `DRAG_PER_STUD` was fitted to Hornady's published 100 yd
velocity **alone**, then predicts their 200 yd and 300 yd figures to **+0.6 %** and **+0.5 %** with
nothing fitted to either.
*Verify:* `lever.spec`, "PREDICTS the published 200 yd and 300 yd velocities to within 1 per cent" —
it drives `Ballistics.speedAt` and would fail if the coefficient were tidied. Sources and the
arithmetic: research note section 3.

**3. The cycle is a lever throw and the reload is the gate, and neither adds a primitive.**
`CYCLE = { Break 0.46, Close 0.64 }` (1.10 s, between the bolt's 1.62 — Karen's own number from task
184 — and the 0.62 that read as too fast); `RELOAD = { Break, Load × 5, Close }` = 2.90 s, which is
`StateMachine.apply`'s `Load` filling exactly one chamber per step, five times.
*Verify:* `lever.spec`, "cycles in two steps…", "reloads through the gate… and NO Magazine step",
"charges each sequence its OWN Break window", and the reducer cases driven with this row.

**4. `Weapon.cycleRefusal` is a pure three-answer rule, and neither shipped gun can reach the new
branch.** A partial top-up answers `barrel-full`, which today takes the "the world moved under it"
recovery path. `walk` / `finish` / `abort`.
*Verify:* `lever.spec`, "answers walk, finish and abort", "a FULL tube answers barrel-full on a
Load", and **"NEITHER SHIPPED GUN CAN REACH IT"** — which drives the shotgun's `Break` (ejects
`"all"`, so every chamber is `Empty`) and asserts the Rigby's reload issues no `Load` at all.

**5. `CYCLE_KIND = "lever"` is a third value, and the throw's SIGN lives in the geometry.**
`"hinge"` would ride the fore-end glove through the loop's whole arc (`Viewmodel.poseHands` keys off
exactly that string), and its negative rotation carries a loop hanging below its pin **up and toward
the butt**. Measured on the model: the loop's apex at 60° moves **down 0.360, forward 0.546**.
*Verify:* `lever.spec`, "THE LOOP SWINGS DOWN AND FORWARD, and at rest it has not moved" — at
progress 1 the grip point has both a smaller Y and a more negative Z, at 0 the transform is
identity, and an over-range progress is clamped. This is the case task 188 bought.

**6. `Viewmodel.handFeedsShells` closes a shipped defect this gun would have walked into.**
`MAGAZINE_SWAP ~= nil` was standing in for "is this gun hand-fed"; underneath it `chamberOffset` is
`Gun.chamber(barrel, Shotgun.CONFIG)` — the **shotgun's** chamber mouths at the shotgun's 4.4-stud
layout with its red 12-gauge hull. The lever has no magazine block, so the old test said "draw
them". Each geometry now declares `HAND_FED_SHELLS`, and `loadingAt` takes the geometry **as a
parameter**.
*Verify:* `tests/client/rifle_client.spec.luau`, "hides the shell feed on a magazine weapon" — now
driven with three geometries by hand (`Gun` true, `Rifle.Geometry` and `Lever.Geometry` false).

**7. A player who has NOT bought it never holds it, and the free path is bit-for-bit pre-224.**
`OWNED_ONLY` on the row; applied in `Weapons` (the module that owns "which of them a hunter carries"
and the only one that can see the rows), narrowing the candidate list `Shop.loadoutFrom` is given.
**Measured first:** at `a8ae6a1` the DEV gate reported `character holds [Lever]; backpack [Shotgun,
Rifle]`.
*Verify:* `lever.spec`, "is NEVER handed out free, and the free path is what it was before this
weapon" — it drives **both** directions (no lever for a nil ownership set; the lever for a man who
bought it) and asserts neither shipped gun declares the field. Plus `rifle.spec` and `shop.spec`,
whose unrestricted-loadout cases are back to two.

**8. The shop sells it, on the rung the archived "RIFLE, OPEN" row held.** 650 coins, 12 hunts,
`grants.weapon = "lever"`, `Shop.ORDER[5]` (cheapest-first: between the high seat's 600 and the deer
licence's 750), `BASE_AMMO.lever`, and a display model in the panel.
*Verify:* `lever.spec`'s "the shop sells it" block (including `rowsOk` clean with the real weapon
table), `shop.spec`'s ORDER and weapons-shelf cases, `shop_panel.spec`'s "has a picture for every
row it sells".

**9. Three meshes, uploaded to Karen's account, all Approved, and the geometry is measured.**
`lever.action` 125504731571254, `lever.stock` 95062328289891, `lever.lever` 85657989123623;
`assets/uploads.json` carries Karen's words verbatim (*"Upload, sell in shop (Recommended)"*). Every
box and point in `Lever.Geometry` was measured in the Handle's frame by a script that **imports**
`tools/gltf_split.py`, so there is one frame and not a second copy of the maths. The model's own
irons measure **0.0055° from level** over 2.23 studs, so the aim is the gun's own sight line.
*Verify:* the `Assets.ROWS` rows against `assets/uploads.json`; `LEVER_PLAN` in `tools/gltf_split.py`
(and `python tools/gltf_split.py selftest`); research note section 8.

**10. The licence is recorded as the boar's is, and no tier is claimed.** `LEVER_LICENCE` is
`BOAR_LICENCE` word for word with a new attribution, plus a `CREDITS.md` entry. The download ships
**no licence file** (checked: the FBX, the OBJ and every zip entry) and nothing this machine can
reach is Karen's purchase record, so no tier is written down.
*Verify:* `src/serverstorage/Assets/init.luau`, `LEVER_LICENCE` against `BOAR_LICENCE`; `CREDITS.md`.

---

## What I could not verify, and one thing that is wrong

**(a) THE HANDS ARE NOT ON THE GUN.** First-person frame `.screenshots/t224-lever-carry.png`, looked
at: the gun is drawn correctly — stainless receiver, rail with its slots, tube magazine, fore-end,
the large loop below — and the Hud reads **five pips and `.45-70` with 10 in reserve**, which is
`BARRELS`/`MAGAZINE` 5 and `START_RESERVE` 10. **But no gloves are visible on it.** Measured in the
same session: `workspace.CurrentCamera` holds `MeshPart:HandRight` and `MeshPart:HandLeft` — **the
gloves exist and are parented** — and all three uploaded meshes are there
(`MeshPart:Lever, MeshPart:Stock, MeshPart:Action`). So the hands are MIS-PLACED, not missing, and
that is `weapons.lever.carry.left`/`.right` in `poses.json` — the **content lane**, which the
Director tunes live with `tools/pose.py` and which takes no Builder or Reviewer round. It is not a
code defect and this request does not claim the pose is finished.

**(b) No aim, mid-throw or gate-feed frame, and no live 50 m / 100 m hit.** The DEV Studio closed
mid-session before I could take them. What the one frame proves is listed above; nothing else about
how the gun looks or shoots is claimed here.

**(c) Why the proof had to be taken in DEV and not the Forest Test**, and a finding worth keeping:
`MatchBoot.server.luau` passes `counterAt = nil`, so the DEV place has **no lodge and no counter**
and `Shop.atCounter` is false — **every purchase in DEV is refused `too-far` by design**. Measured
over the real wire: `refused=too-far balance=13000 hunts=30 LEVER owned=false buyable=true
price=650`. So the gun was held through `Weapon.refreshArming`'s loadout **parameter** — the seam
task 141 built for exactly this — and the real server's sweep revoking it afterwards is claim 7
working.

**(d) The DEV place has overrides set in Edit that must be cleared.** `DHFlag_COINS`, `DHFlag_SHOP`,
`DHFlag_RIFLE` and `DHShopTestGrant` (which was `nil` before; `Economy.start` reads it from
**ServerStorage**, once, at boot — there is no per-player read). The Studio closed before I could
clear them. **`python tools/flags.py clear` and unset `DHShopTestGrant` before the next harness
run** — `test` and `test2` both REFUSE while an override is set, so this blocks rather than
corrupts.

**(e) Karen's dials, untouched by anyone here:** `GRAVITY_SCALE` 0.35, the 1.10 s throw and 2.90 s
reload, the recoil block, the three voices and their pitches, and the 650 / 12-hunt price. Nobody
here has heard a sound or felt a kick.
