# Task 97 — the carry, the aim and the raise, from the new side-by-side video

Task: 97
Round: 1
Base: task-93-fp-hands (174bee5) — stacked, PR #87 targets that branch
Code commit: a520a44972167406e709cd89bee8306600635137

```
[harness2] PASS: 32/32 checks @ a520a44972167406e709cd89bee8306600635137 (clean tree)
[harness] PASS: 32/32 checks @ a520a44972167406e709cd89bee8306600635137 (clean tree)
```

## Claims

1. **`FIRST_PERSON` is ON by default and the row is still the rollback.** `src/shared/Flags/init.luau`:
   `default = true`, every other field kept, so one line returns the accepted shoulder camera.
   Verify: `tests/server/flags.spec.luau` still passes, and both camera specs now build BOTH configs
   themselves (below), so nothing anywhere tests "whatever booted".
2. **The carry is solved from the target frame, not nudged.** `Camera.Config`'s carry block derives
   the pose from three readings of `TARGET-carry.jpg` — action at the bottom edge 31 % across, muzzle
   leaving the left edge 40 % down, barrel pair ~8 % of the width — and records the one measured
   correction (the first build rendered 8 % of the height high). Verify: `camera_mode.spec`, "carries
   the gun ACROSS THE BODY" — the muzzle is now ABOVE the view axis and more than 25 degrees above
   the action, which is the claim task 95's pose had the other way round.
3. **The aim contains the gun again.** At `EYE_RELIEF_STUDS` 3.27 the eye sat at the gun's own
   Z = +1.08 — inside the stock — so everything behind the breech was behind the camera and a 5.4
   degree cheek angle dropped the rest below the frame. 4.40 and 1.2 put the wrist, the top tang, the
   action and both hands in front of the lens. Verify: `camera_mode.spec`, "puts the stock behind the
   eye when aiming", which now measures the butt as an ANGLE off the axis (> 40 degrees, outside the
   corner of the aiming field) because at this relief it is a tenth of a stud in FRONT of the camera
   and still far out of the picture; and the near-plane case, unchanged.
4. **Both camera branches are driven by parameter, in both specs.** Seventeen cases passed the LIVE
   `Config` where they meant "the shoulder camera" and got away with it only while the flag was born
   off. `camera_mode.spec` and `camera_client.spec` each build a `thirdPerson` config beside the
   first-person one. Verify: no `, Config)` call remains in either file; `Config` is read for numbers
   only.
5. **The live first-person camera is a second writer during a spec, and the specs now say so.** It
   draws the viewmodel every frame, so a case that cleared the clone and then yielded had it rebuilt
   under the LIVE config before its own `update` ran — the config it passed never reached `build`.
   The three cases that depended on that now clear with no yield after it. Verify the comments at
   "keeps the appearance", the bead case and the hands case, and the hands case's counter, which
   asserts the hands are ON the clone rather than who put them there.

## Evidence (the gate of this task), described as it is

* `.screenshots/task97-compare-carry.png` — both run the gun diagonally from the bottom centre to the
  left edge with a gloved hand at the lower left. Ours is steeper (49 degrees against the video's 47,
  because our viewport is 1.24:1 and the reference 16:9 and Roblox's field of view is vertical) and
  the gun reads bigger; the muzzle leaves the left edge at the same height.
* `.screenshots/task97-compare-aim.png` — same structure in both: wrist at the bottom centre, top
  tang up it, two rounded barrel tops either side, bead at the top dead centre on the shot line.
  Ours is smaller in the frame than the video's, our action is bright silver where the video's is
  dark, and our left hand shows at the left of the wrist where the video shows the right hand's
  fingers at the right.
* `.screenshots/task97-compare-raise-mid.png` — both catch the gun part way up, barrels running from
  the lower right to the upper left with a hand at the lower left. Ours is further through the swing:
  the muzzle is inside the frame where the video's is still off the left edge.

## What I could not verify

* **Whether Karen likes it.** Composition only; the world is bare on purpose.
* **The bead's offset from the shot line in pixels.** It is geometric — `Mode.aimOffset` puts the
  sight on the axis and `camera_mode.spec` asserts that to 1e-4 — and it reads as the screen centre
  in the capture, but I did not measure the pixel.
* **Recoil and smoke**, which Karen also named. Not in this task.
