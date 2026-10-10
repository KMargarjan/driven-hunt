# Task 143 - the rifle without a scope, and two defects from 142

Task: 143
Round: 1
Base: main (`54c7759`, task 142 merged as PR #125)
Code commit: `3495fd6f72f175434375d9bb43afcdb350322cfe`

```
[harness] PASS: 33/33 checks @ 3495fd6f72f175434375d9bb43afcdb350322cfe (clean tree) scope=all
```

`test2` is N/A: nothing in this diff touches `TWO_PLAYER_PATHS`.

Karen, 2026-10-09: *"and also we need to have option rifle without scope / so fix those above and
then move to rifle without scope where aiming true nozzle"*. The Director's two defects from checking
142 are **step 0** and are committed separately (`fcfce79`). Transcribed in `PLAYTEST.md`.
**No Architect run:** no new owner and no new system — one more row in the weapon table the rifle
already lives in, and one more branch in the geometry that already draws it.

## Step 0: both defects, measured off the model rather than moved by eye

`tools/gltf_split`'s own `Scene` reads the Rigby's `Wood_Low` node in the Handle's frame and reports
it in Z slices (the script is `driven-hunt-runs/t143-forend.py`):

```
stock Z spans -0.8483 .. +2.2000          (-Z is the muzzle)
z -0.65..-0.45   y[-0.0024,+0.1165] x[-0.0709,+0.0446]    <- the forend
z +0.35..+0.55   y[-0.0659,+0.1262]                       <- over the magazine well
z +0.55..+0.75   y[-0.0786,+0.1063]
```

1. **THE HAND.** It sat at `(-0.06, -0.16, -1.05)`: **0.2 studs past the wood's own tip** and 0.14
   below it, which is exactly *"floats in the air"*. It is on the forend's measured centroid now,
   `(-0.013, +0.057, -0.55)`, and a live probe says the glove's box
   `x[-0.451,+0.425] y[-0.431,+0.545] z[-0.991,-0.108]` **encloses the wood in all three axes**.
   The other half was the ROTATION, not the position: the shotgun's inherited twist of -150
   presented the palm edge-on beside the barrel. Swept live with `pose.py` and looked at — -120 turns
   the palm flat to the camera, **-90 wraps the hand round the forend**. All three poses (carry, aim,
   cycle) carry the same rotation, so the glove does not turn between hip, aim and the bolt cycle.

2. **THE MAGAZINE.** It hung from the ACTION box's underside (-0.2058) — a quarter of a stud below
   the stock line — 0.21 deep and 0.52 long: a brick. Sized and seated off the **wood** now: 0.11
   deep, 0.42 long, narrower than the action, floor **0.072 studs** under the measured stock line.
   Live probe: `Magazine box y[-0.144,-0.034]` against the wood at `-0.0725`, so its top is INSIDE
   the stock line and only the floor shows.

## The ten claims

1. **WHAT THE MODEL HAS: no sights at all.** Measured over all twelve nodes — `Circle_Low` is a
   138-triangle swivel on the LEFT FLANK of the action (`x -0.095..-0.078, z +0.11..+0.18`) and
   `Safety_Low` is the safety on top at `z +0.77`. It is a scope-only rifle. So the front sight is
   **drawn**, exactly as the shotgun's bead is and for the same reason: there is nothing in the file
   to upload. **Verify:** `BEAD_DIAMETER`'s comment in `Rifle/Geometry.luau`.

2. **The bead sits on the barrel's own measured top line.** `Barrel_Low` spans `y +0.0556..+0.1844`,
   so `BARREL_TOP_Y = 0.1844`, one diameter back from the muzzle so it is not half in the air.
   **Verify:** `rifle.spec`, "is the SAME rifle with the glass off" — the bead is within 0.1 of
   `-HANDLE_SIZE.Z/2` and exactly on the centre line (`|x| < 1e-9`), so it looks where the barrel
   points.

3. **ONE GUN, ONE GEOMETRY, AND THE ROW PICKS THE SIGHT.** `Geometry.pieces` filters its single list
   on `skipFor`/`onlyFor` and `Geometry.sight` answers with the ocular lens or the bead, so the two
   rifles cannot drift into two piece lists. **Verify:** the same spec asserts the scoped row's
   pieces contain `Scope` and no `Bead`, and the open row's the mirror — **from the same list**.

4. **The aim is the shotgun's, by having no scope at all.** With `row.scope` nil, `Mode.fovFor` falls
   back to `FOV_AIM_DEG`, `Hud.scopeVisible` and `Hud.reticleVisible` are both false for want of an
   eyepiece, and `Viewmodel.hiddenByScope` never hides the gun. No overlay, no reticle, no sway, gun
   and hands visible — and Karen's no-crosshair rule is untouched, because the crosshair is false in
   first person whatever is in the hands. **MEASURED through the real hotbar keys:**

   ```
   2 Rifle      aimed  fov 19.87  overlay true   reticle true   gun hidden (0 meshes)
   3 RifleOpen  aimed  fov 50.00  overlay false  reticle false  gun drawn  (5 meshes)
   1 Shotgun    carry  readout 'x[*] SLUG 24'
   ```

5. **It is the SAME gun, asserted field by field.** Range, pellets, spread, ammo, reserve, chambers,
   the bolt's two steps, `CYCLE_EJECTS`, the magazine change, the readout, the handle and the voice
   are all `==` the scoped rifle's row. **Three things differ and all three are the sight:** no
   `scope` block, one fewer `ASSET_KEYS` (never `rifle.scope`), and `SIGHT = "bead"`.

6. **THE THIRD TOOL BROKE THE CLIENT'S REPLICA, and my own task surfaced it.** The server publishes
   PER TOOL, so a switch sends two snapshots — the gun going away (`equipped = false`) and the gun
   coming out — and the client kept ONE variable, so the last to arrive won. Measured: switching to
   slot 3 left `Weapon.get()` holding the rifle's un-equipped snapshot, **the readout went blank and
   the aim source refused to aim** — for the open rifle AND for the shotgun after it. With two
   weapons the ordering happened to come out right, which is why task 142 never saw it. There is one
   snapshot per weapon id now and `Weapon.get()` answers with the one that says it is equipped.
   **Verify:** `byWeapon` in `src/client/Weapon/init.luau`.

7. **The eye relief is the open rifle's own, and both wrong answers were looked at.** It started at
   the shotgun's 3.2, which on a 4.4-stud rifle whose bead is at the muzzle put the eye **inside the
   receiver** — `.screenshots/t143-open-aim.png`'s first version is a view from within the action.
   5.4 pushed it so far back the butt-pad filled the lower third
   (`.screenshots/t143-relief-5.4.png`). At **4.6** the cheek is on the stock, the barrel runs away
   to the bead, and the bead is dead centre.

8. **Slot 3, behind the same flag.** `Weapons.ORDER` is `{shotgun, rifle, rifle_open}` and
   `loadoutFor(true)` returns all three, so the hotbar reads **1 Shotgun, 2 Rifle, 3 RifleOpen** —
   measured off the CoreGui hotbar itself. The shop decides who owns which later.

9. **The report calls it `RIFLE (OPEN)`**, through the same `Weapons.row(id).label` the kill line and
   the drive report's GUN column already read; nothing in `HitLog` or `ReportPanel` changed.

10. **The validator stopped naming two weapons.** `Viewmodel.validate`'s structural loop walks what
    the file actually carries, so a set nobody listed is checked rather than skipped; the
    must-exist list is still explicit (and gained `rifle_open`) because `Viewmodel` is the shared
    module the weapon table reaches through — a require back the other way is a cycle.

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t143-open-aim.png` | **The left glove reads as a pale khaki block** beside the action rather than a hand round the wood — from the aim angle the palm faces the camera, and it is the worst thing in the frame. The gun also fills the lower half and the sight picture sits low. What the frame is FOR is right: the **brass bead is dead centre**, inside the leftover scope ring, the barrel runs away to it, there is **no overlay, no reticle and no crosshair**, the gun and both hands are drawn, and the readout reads `3/3 .416 9` |
| `t143-step0-hip.png` | The magazine still reads as a flat dark plate rather than a moulded box, and the glove is a khaki lump — but the plate is now tucked under the receiver at the stock line instead of hanging a quarter-stud clear, and the hand is back on the forend instead of out past its tip |
| `t143-relief-4.6.png` / `-5.4.png` | The two eye reliefs side by side: at 5.4 the butt-pad is a black slab across the bottom third; at 4.6 the cheek is on the stock and the sight picture is clean. This pair is why 4.6 ships |
| `t143-scope-aim.png` | The scoped rifle, unchanged by this task: black mask, round eyepiece, duplex and red dot, no gun |
| `t143-open-carry.png` | The open rifle carried: **no scope tube**, the mount rings still on the action, the bolt handle, the walnut, the small magazine under the receiver |

## Standing rule A, Forest Test, 85 s, with RIFLE ON

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 25 boars alive

## What I could not finish, and what is a dial

* **THE SCOPE RINGS STAY, and here is the decision the Director asked for.** They are part of the
  ACTION group's own uploaded mesh (`Vijsjes_Low`, the screws and mounts), not a group of their own,
  so taking them off means re-splitting and re-uploading the model — Karen's OK and a moderation
  wait, for a task that is otherwise data. On screen they read as a **ghost ring around the bead**,
  which is a real sight picture rather than an obstruction, and a rifle whose owner took the glass
  off still has its mounts. If Karen dislikes it, it is an upload, not an edit.
* **The left glove's WRAP is first-pass and is the thing I would put next.** It is measurably on the
  wood and no longer floating, and at hip it reads as a hand; from the aim angle it reads as a block.
  I swept the aim pose's twist at -40 and +10 as well and neither beat -90 (-40 reads as a floating
  forearm), so all three poses keep one rotation and the glove does not jump. It is content-lane data
  (`weapons.rifle_open.aim.left`), which is exactly what `tools/pose.py` exists to tune live.
* **Nobody has heard the open rifle's sounds either** — it shares the scoped rifle's `SOUND` block,
  so task 142's disclosure stands unchanged.
* **The open rifle has no spec of its own on the client.** `rifle.spec` drives the row, the pieces
  and the sight on the server; that the aimed FOV is 50 and no overlay appears is the pasted
  measurement above, not a case. Queued.
