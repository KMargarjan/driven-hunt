# Task 71 — the shotgun's real look, built from Parts

Task: 71
Round: 1
Base: `main` (`07022aa`)
Code commit: `51ff5769e6665498eb5dc88ad1798ff7c1279cb4`

```
[harness] PASS: 30/30 checks @ 51ff5769e6665498eb5dc88ad1798ff7c1279cb4 (clean tree)
```

*(the `[harness2]` line for this same commit is the Director's run; this request is updated with it
before the review.)*

**What changed.** The shotgun's grey box becomes a side-by-side built from Parts — Director decision
after two Meshy text-to-3D previews (40 credits) both came back over-unders. 389 server specs (383
before: six new), 84 client. New: `docs/research/2026-09-26-shotgun-model.md`,
`src/server/Weapon/Shape.luau`, `tests/server/weapon_look.spec.luau`. Changed:
`Weapon.Hardware`, `Weapon` (one export), `Shotgun.CONFIG`, `Camera.Viewmodel`,
`tests/client/camera_client.spec.luau`, `TASKS.md`, `docs/research/INDEX.md`.

**Side item, its own commit (`1f069ce`), paperwork only:** `reviews/task-67/ASSET_RESULT.md`, the
Asset agent's inspection of the boar GLB, committed verbatim. Privacy scan PASS, 0 findings.

## Claims

1. **Research before implementation (rule 1), and the borrow is written down (rule 2).**
   `docs/research/2026-09-26-shotgun-model.md` names five sources with licence and maintenance:
   Roblox's Weapons Kit (Limited Use License, maintained), Roblox's Assemblies page (CC BY 4.0),
   `JonathanKwak/gun-system` (MIT, unmaintained), a 2019 devforum low-poly weapon pack (**no licence
   — a forum sentence**, and `.rbxm`/`.obj`, both unusable here), and Gun Mart's 486 Parallelo review
   for the dimensions. The written reason for building rather than borrowing: there is no part-built
   side-by-side under a usable licence, so the **pattern** is borrowed and no file is. Indexed in
   `docs/research/INDEX.md`.

2. **The proportions are published, not invented, and they check each other.** Barrel 28 in, overall
   45.0 in, length of pull 14.5 in. `Shape.BARREL_FRACTION`, `Shape.PULL_FRACTION` and
   `Shape.BREECH_TO_TRIGGER_FRACTION` are those three over 45, and 28 + 14.5 = 42.5 leaves 2.5 in
   from breech to trigger — which is what a break action has. Verify: `weapon_look.spec`,
   `it("keeps the real gun's proportions...")`, which writes every number out rather than importing
   it from the module under test.

3. **Dimensions only.** No engraving, lettering, logo, maker mark or trade dress is modelled or
   named, and the brief forbade them. Verify: grep `Shape.luau` — there is no Decal, no TextLabel and
   no SurfaceGui in the repo's weapon code at all.

4. **A pure list plus one builder, the division this repo already uses.** `Weapon.Shape` creates no
   Instance and reads no service; `Weapon.Hardware` builds it and is still the only writer of `Tool`
   Instances (`docs/design/shotgun.md` §3.1). `GAME_DESIGN.md`'s owners table is unchanged because no
   owner moved.

5. **Appearance only, and the raycast surface is provably unchanged.** Every piece is
   `CanQuery = false`, so the `Handle` is still the one part of the gun a ray can hit — ten queryable
   boxes on another player's gun would be ten new things a slug stops against. Verify:
   `weapon_look.spec`, `it("welds every piece to the Handle, and the Handle alone answers a ray")`,
   which builds a real Tool and asserts `CanQuery` on every piece and on the Handle. `Weapon.Cast`,
   `MUZZLE_OFFSET`, `GRIP` and the ignore list are untouched.

6. **The Handle stays the assembly root.** Every piece is `Massless = true`; Roblox picks an
   assembly's root anchored-first and then by "Parts with Massless set to false (default) take
   precedence" (the Assemblies page), so a massful barrel could take the root from the Handle and
   move the Tool's grip.

7. **A legacy `Weld` with an explicit `C0`, and the reason is in the code.** `Hardware.build()`
   returns a Tool that is **not** in the DataModel — `Hardware.give()` parents it later — and a
   `WeldConstraint` needs both parts parented (`src/server/Boar/Body.luau` says exactly that where it
   uses one). A `Weld` carries the offset as data, so the geometry comes from `Weapon.Shape` rather
   than from wherever a part happened to be. Verify: the spec asserts `Part0 == handle` and
   `C0 == pieces[name].offset` for all ten.

8. **One source, two views.** `Camera.Viewmodel` clones the Handle and used to destroy every child
   that was not an `Attachment` — which would have left the first-person gun blank while the
   third-person gun was real. It now keeps `BasePart` descendants, anchors them all and destroys the
   rest (welds included, so nothing under `workspace.CurrentCamera` is simulated).
   `camera_client.spec` asserts on screen that the **PrimaryPart is the only invisible part**, that
   every part is anchored and `CanQuery = false`, and that there are between 4 and 16 of them — a
   stronger claim than the "every part is visible, at most four" it replaces, and it still fails on a
   blank viewmodel.

9. **Screenshots, inspected (rule 5).** Third person:
   `.screenshots/20260926T203023Z-task71-tp-31.png` — walnut stock, silver-grey action hanging below
   the bore with the guard under it, walnut splinter forend, dark blued barrels running out with the
   rib catching light. ADS: `.screenshots/20260926T202736Z-task71-ads-45.png` — **two dark bores side
   by side**, the rib between them narrowing away, the bead a white dot at the end. **LOOKED AT, THEN
   CHANGED:** the first build centred the action on the bore and the ADS shot
   (`20260926T202413Z-task71-ads-45.png`) showed **no barrels and no bead** — the near action hid
   them. Commit `7ed846f` drops the action so its top is the bore line, as on a real break gun.

10. **The harness failed once at `b5788a8` and passed twice at the same commit**, on
    `weapon_client.spec:454` (three shots seen where the replay fires two) and `:429` (`reserve.Slug`
    23 not 24 — the same extra shot). The gun code was identical in all three runs; the same suite
    has a recorded intermittent history (`TASKS.md` rows 48a(a), 52a). Queued as row 71a(a) with the
    evidence rather than papered over. Every later run — `7ed846f` twice, `51ff576` once — is
    `PASS: 30/30`.

## Not verified

- **`test2`** — the Director's run; this request is updated with the `[harness2]` line before the
  review.
- **Nobody has held this gun in a two-player session**, and nobody has fired at another player's gun
  to confirm the slug passes through it. Claim 5 is asserted on the built part's `CanQuery`, not on a
  ray's path.
- **The colours are a first pick**, Karen's to change (`Shotgun.CONFIG.LOOK`). Under the arena's flat
  lighting the barrels read light grey from some angles and properly blued from others.
- **No screenshot shows the gun from directly in front of the muzzle.** The two-bores-side-by-side
  claim rests on the ADS sight picture, which is the same pair seen from the breech end.
- **Whether Karen likes it** is a playtest question, not this task's.
