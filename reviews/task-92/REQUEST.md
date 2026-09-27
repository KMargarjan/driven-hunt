# Task 92 — the shotgun's feel: ADS, the bead, the gun's look, recoil, the flash

Task: 92
Round: 3
Base: `main` (`62b20e7`)
Code commit: `1fa29e5d695f6df5096ff321ceba4415fa5121ad`

```
[harness2] PASS: 32/32 checks @ 1fa29e5d695f6df5096ff321ceba4415fa5121ad (clean tree)
[harness]  PASS: 32/32 checks @ 1fa29e5d695f6df5096ff321ceba4415fa5121ad (clean tree)
```

## Claims

1. **FINDING 1, FIXED: the first-person extras stay in the first-person branch.** `Viewmodel.build`
   adds the fill light **and the drawn bead** only when `config.FIRST_PERSON`. The bead was in exactly
   the same place and is gated with it -- the shoulder camera's sight picture is the framing Karen
   accepted on 2026-09-25, not a bead on the view axis. `camera_client.spec` drives both branches from
   ONE handle: with the flag off the clone has the gun's own attachment and nothing else -- no
   `ViewmodelFillAt`, no PointLight, no `SightBead` -- and rebuilt with the first-person config it has
   the fill attachment, exactly one light, and the bead. **MUTATION:** forcing the branch on fails
   both by name (`camera_client.spec:500`, two attachments where one was expected, and `:719`, a
   `SightBead` in the OFF branch). Restored.
2. **ONE GATE FAILED ON THE WAY, DIAGNOSED.** `28/32` and `30/32 @ b544f3d`: the rebuild was in the
   MIDDLE of the sweep case, and a rebuild destroys the clone the assertions after it read -- so
   `BarrelLeft` was gone, the case aborted before putting the live source back, and the driver's
   "aiming empty hands gets no viewmodel" failed with it. The rebuild is the last thing that case
   does now.
3. **EVERY OTHER THING THIS TASK ADDED, CHECKED AGAINST THE OFF BRANCH, one line each.**
   *Fill light* -- ON only (this round, asserted both ways). *Drawn bead* -- ON only (same guard, same
   case). *Cheek tilt* -- ON only: `Mode.viewmodelOffset` calls `aimOffset` only under
   `config.FIRST_PERSON`, and the OFF branch keeps `VIEWMODEL_AIM_OFFSET` (asserted in
   `camera_mode.spec`). *Recoil* -- ON only: `Mode.kick` returns the state it was given when the flag
   is off (asserted), and the live client, which runs with it off, reports `recoilKicks = 0`.
   *Effects origin* -- ON only: `Camera.viewmodelMuzzle` answers nil outside first person, so the OFF
   branch draws at the world muzzle (asserted live: the installed provider answers nil).
   **The one deliberate exception**: the flash's new shape, the smoke puff and the per-barrel muzzle
   frame are drawn for BOTH branches and for every player -- that is Karen's "the light has to be from
   the pipes", which is about the gun in the world, not about the camera.
4. **NOTHING ELSE MOVED.** The round-2 rule holds unchanged: `Effects.muzzleFrame` asks the provider
   only for `payload.shooterUserId == Players.LocalPlayer.UserId`, with the ask-count asserted for
   another player's shot (`task92 flash: my shot 0.30 studs from my drawn muzzle; another player's
   0.30 from the world muzzle and 41.9 from mine`).
5. **THE SCREENS, AS BEFORE** (`.screenshots/...t92r2-ads.png`, `...t92r2-carry.png`): aimed, the two
   barrels run from the bottom of the frame to the muzzle as one smooth blued surface with a single
   highlight down the rib, no shards or seams, the breech below the frame edge, the brass bead
   **1.44 px (0.09 deg)** from the centre; carried, the same smooth gloss, walnut stock, bead at the
   muzzle. Neither was retaken this round: no drawn geometry changed, only which branch gets it.

## Not verified

- Karen has not played any of it; the cheek angle changes a picture she had already called good.
- The OFF branch's viewmodel was not re-photographed after the guard -- it is asserted, not seen.
