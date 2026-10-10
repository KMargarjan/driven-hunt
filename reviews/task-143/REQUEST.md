# Task 143 - the rifle without a scope, and two defects from 142

Task: 143
Round: 2
Base: main (`54c7759`, task 142 merged as PR #125)
Code commit: `b176f2f0401b01afdfb1f644c232d911bc5aaf3f`

```
[harness] PASS: 33/33 checks @ b176f2f0401b01afdfb1f644c232d911bc5aaf3f (clean tree) scope=all
```

`test2` is N/A: nothing in this diff touches `TWO_PLAYER_PATHS`.

Karen, 2026-10-09: *"and also we need to have option rifle without scope / so fix those above and
then move to rifle without scope where aiming true nozzle"*. The Director's two defects from checking
142 are **step 0** and are committed separately (`fcfce79`). Transcribed in `PLAYTEST.md`.
**No Architect run:** no new owner and no new system — one more row in the weapon table the rifle
already lives in, and one more branch in the geometry that already draws it.

Round 1 passed with 14 notes. Nine of them were real and are fixed in `b176f2f`; the rest are queued
as 143a. **Round 1 got one thing wrong and claim 1 below is the correction.**

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
   The other half was the ROTATION, and the three poses did not agree with each other: `carry` and
   `cycle` were the shotgun's inherited `pitch 80 / twist -150 / yaw 90` and `aim` was
   `pitch 85 / twist 110 / yaw -165` — a palm presented edge-on beside the barrel, turning between
   hip and aim. Swept live with `pose.py` and looked at — -120 turns the palm flat to the camera,
   **-90 wraps the hand round the forend**. One rotation across all three now.

2. **THE MAGAZINE.** It hung from the ACTION box's underside (-0.2058) — a quarter of a stud below
   the stock line — 0.21 deep and 0.52 long: a brick. Sized and seated off the **wood** now: 0.11
   deep, 0.42 long, narrower than the action, floor **0.072 studs** under the measured stock line.
   Live probe: `Magazine box y[-0.144,-0.034]` against the wood at `-0.0725`, so its top is INSIDE
   the stock line and only the floor shows.

## The ten claims

1. **WHAT THE MODEL HAS — AND ROUND 1 SAID "NO SIGHT AT ALL", WHICH IS WRONG.** Chasing the
   Reviewer's note on `BARREL_TOP_Y` found it: `driven-hunt-runs/t143-muzzle3.py` fits the rings in
   `Barrel_Low`'s own vertices and the muzzle face is **two stacked tubes, not one** — the barrel at
   centre `(-0.0138, +0.0920)` r 0.0364, and **a second 0.0404-stud tube on top of it** at centre
   `(-0.0150, +0.1634)`, running `z -2.200..-2.095`. That is the **band of a banded front sight**,
   with no bead and no blade on it. The drawn bead sits ON that band. Also measured: the barrel is
   tapered and its axis rises toward the receiver (`+0.092` at the muzzle, `+0.135` at z -0.25), so
   the note was right to ask — `+0.1844` survives because it is the BAND's top at the bead's own z,
   not because it is the node's maximum, and the constant is now `SIGHT_BAND_TOP_Y`.
   **Verify:** that comment block in `Rifle/Geometry.luau`, and `t143-muzzle3.py`'s output in it.

2. **ONE EXPRESSION FOR THE BEAD.** `Geometry.beadOffset` is read by `Geometry.sight` AND by the
   drawn `Bead` piece — the rule `Gun.beadOffset` already keeps for the shotgun. **Verify:**
   `rifle.spec`, "is the SAME rifle with the glass off" asserts the drawn piece's own offset equals
   `beadOffset(open)` and so does the sight, so a second copy could not pass.

3. **ONE GUN, ONE GEOMETRY, AND THE ROW PICKS THE SIGHT.** `Geometry.pieces` filters its single list
   on `skipFor`/`onlyFor` and `Geometry.sight` answers with the ocular lens or the bead, so the two
   rifles cannot drift into two piece lists. `ShapeRifle` — the silhouette OTHER players see until
   the uploads land — follows the same row: it no longer draws a scope tube on a rifle that has
   none. **Verify:** the same spec, plus the new "reads any row written before this task as the
   SCOPED rifle", which also pins `sightKind(nil) == "scope"`.

4. **The aim is the shotgun's, by having no scope at all.** With `row.scope` nil, `Mode.fovFor` falls
   back to `FOV_AIM_DEG`, `Hud.scopeVisible` and `Hud.reticleVisible` are both false for want of an
   eyepiece, and `Viewmodel.hiddenByScope` never hides the gun. No overlay, no reticle, no sway, gun
   and hands visible — and Karen's no-crosshair rule is untouched. **RE-MEASURED after the round-2
   changes, through the real hotbar keys and the right mouse button** (`t143-switch.py`):

   ```
   2 Rifle      aimed  fov 19.87  overlay true   reticle true   gun hidden (0 meshes)
   3 RifleOpen  aimed  fov 50.00  overlay false  reticle false  gun drawn  (5 meshes)
   1 Shotgun    aimed  fov 50.00  overlay false  reticle false  gun drawn  (4 meshes)
   ```

5. **It is the SAME gun, asserted field by field.** Range, pellets, spread, ammo, reserve, chambers,
   the bolt's two steps, `CYCLE_EJECTS`, the magazine change, the readout, the handle and the voice
   are all `==` the scoped rifle's row. **Three things differ and all three are the sight:** no
   `scope` block, one fewer `ASSET_KEYS` (never `rifle.scope`), and `SIGHT = "bead"`.

6. **THE THIRD TOOL BROKE THE CLIENT'S REPLICA, and the fix is now an ORDERING rule.** The server
   publishes PER TOOL, so a switch sends two snapshots and the client kept ONE variable: switching to
   slot 3 left `Weapon.get()` holding the rifle's un-equipped snapshot, the readout went blank and
   the aim refused — for the open rifle AND for the shotgun after it. Round 1 fixed it with a `pairs`
   scan for `equipped`, which the Reviewer was right to call random during the instant both say so.
   It is `Weapon.heldFrom(replicas, heldId, newest)` now: **the gun whose NEWEST snapshot claimed the
   hand**, so a stale `equipped` from a dropped un-equip cannot win either. **Verify:**
   `weapon_client.spec`, "answers with the gun whose newest snapshot claimed the hand" — driven as a
   function because keys 1/2/3 cannot be replayed at all (`VirtualInput` refuses them).
   **MEASURED live in both directions**, 1→2→3→1→3→2→1, readout following the gun every time:
   `3/3 .416 9` for either rifle, `x[*] SLUG 24` for the shotgun.

7. **The eye relief is the open rifle's own, and both wrong answers were looked at.** It started at
   the shotgun's 3.2, which on a 4.4-stud rifle whose bead is at the muzzle put the eye **inside the
   receiver** — `.screenshots/t143-open-aim.png`'s first version is a view from within the action.
   5.4 pushed it so far back the butt-pad filled the lower third
   (`.screenshots/t143-relief-5.4.png`). At **4.6** the cheek is on the stock, the barrel runs away
   to the bead, and the bead is dead centre.

8. **Slot 3, behind the same flag, and the bag order is a case now.** `Weapons.ORDER` is
   `{shotgun, rifle, rifle_open}` and `loadoutFor(true)` returns all three, so the hotbar reads
   **1 Shotgun, 2 Rifle, 3 RifleOpen**. Round 1 only pasted that measurement; `weapon_equip.spec`'s
   order case now hands over `Weapons.loadoutFor(true)` itself — three Tools — so weapon four joins
   it the day it joins `Weapons.ORDER`.

9. **The report calls it `RIFLE (OPEN)` and the column fits it.** Twelve characters in a nine-wide
   field pushed HITS three right of its header (the Reviewer's note). `%-12s` now — **and the RANGE
   column gained the second space it had owed since task 140**, which had every column after it one
   character left of its own heading. **Verify:** `rifle_client.spec` asserts, for every label in
   `Weapons.ids()`, that the gun word starts exactly at the header's `GUN` and that the row is the
   header's own length.

10. **A validator that throws is the failure it exists to prevent.** `Viewmodel.validate`'s
    structural loop walks what the file actually carries, so a set nobody listed is checked rather
    than skipped — and a non-table member is now REPORTED instead of erroring out of the loop.

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t143-open-aim.png` | **The left glove reads as a pale khaki block** beside the action rather than a hand round the wood — from the aim angle the palm faces the camera, and it is the worst thing in the frame. The gun also fills the lower half and the sight picture sits low. What the frame is FOR is right: the **brass bead is dead centre**, inside the leftover scope ring, the barrel runs away to it, there is **no overlay, no reticle and no crosshair**, the gun and both hands are drawn, and the readout reads `3/3 .416 9` |
| `t143-step0-hip.png` | The magazine still reads as a flat dark plate rather than a moulded box, and the glove is a khaki lump — but the plate is now tucked under the receiver at the stock line instead of hanging a quarter-stud clear, and the hand is back on the forend instead of out past its tip |
| `t143-relief-4.6.png` / `-5.4.png` | The two eye reliefs side by side: at 5.4 the butt-pad is a black slab across the bottom third; at 4.6 the cheek is on the stock and the sight picture is clean. This pair is why 4.6 ships |
| `t143-scope-aim.png` | The scoped rifle, unchanged by this task: black mask, round eyepiece, duplex and red dot, no gun |
| `t143-open-carry.png` | The open rifle carried: **no scope tube**, the mount rings still on the action, the bolt handle, the walnut, the small magazine under the receiver |

Round 2 changed no drawn number — `beadOffset` returns the same vector the two copies did — so the
frames above are still what the gun looks like. The report's row is text and is asserted, not shot.

## Standing rule A, Forest Test, 85 s, with RIFLE ON — re-run on `b176f2f`

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 2 boar sounds at once over 10 s with 29 boars alive

## What I could not finish, and what is a dial

* **THE SCOPE RINGS STAY, and here is the decision the Director asked for.** They are part of the
  ACTION group's own uploaded mesh (`Vijsjes_Low`, the screws and mounts), not a group of their own,
  so taking them off means re-splitting and re-uploading the model — Karen's OK and a moderation
  wait, for a task that is otherwise data. On screen they read as a **ghost ring around the bead**,
  which is a real sight picture rather than an obstruction, and a rifle whose owner took the glass
  off still has its mounts. If Karen dislikes it, it is an upload, not an edit.
* **The left glove's WRAP is first-pass and is the thing I would put next.** It is measurably on the
  wood and no longer floating, and at hip it reads as a hand; from the aim angle it reads as a block.
  I swept the aim pose's twist at -40 and +10 as well and neither beat -90, so all three poses keep
  one rotation. It is content-lane data (`weapons.rifle_open.aim.left`), which is what `pose.py` is
  for.
* **Nobody has heard the open rifle's sounds** — it shares the scoped rifle's `SOUND` block, so task
  142's disclosure stands unchanged.
* **The live key sweep FIRES THE GUN.** `t141-oskeys.ps1` must left-click into the viewport to get
  keyboard focus, so every hotbar press costs a round — which is why the readout above walks
  `3/3 -> 2/3` and `x[*] -> x[x]`. It is the measuring instrument, not the game; and the first probe
  of the sweep read `held=none` because the Tool had not reached the hand yet.
* **`docs/design/rifle.md` is stale** (`slot: 1 or 2`, `ORDER = { "shotgun", "rifle" }`). Folded into
  the Architect refresh already queued as 142a, per the Reviewer's own note.
