# Task 104 — a landmark format that can say "down-away" (lean lane, behind `NEW_GUN`)

Task: 104
Round: 1
Base: `587e9c8` (main, after PR #94)
Code commit: `370dc8c89ff7f81b517937ed7a41be0b14119e74`

```
[harness] PASS: 32/32 checks @ 370dc8c89ff7f81b517937ed7a41be0b14119e74 (clean tree)
[harness2] PASS: 34/34 checks @ 370dc8c89ff7f81b517937ed7a41be0b14119e74 (clean tree)
```

Tools and one data file only; no `src/` change, and **`poses.json` is untouched** — the fit ran three
times and I am not saving any of it. `test2` is here because `tools/studio_mcp.py` changed.

1. **Three things the format could not say, and now can.** `nearer`/`farther` name another mark — a
   picture gives no distance but it always gives an ORDER, and a chain of orders pins the recession
   one `studs` reading cannot (hinge loss: the right side costs nothing, the wrong side costs by how
   far). `offScreen` may name the **edge** (`bottom`/`top`/`left`/`right`) — "off the bottom" and
   "off the left" are different guns, and task 103's fit chose the second while scoring the first as
   satisfied. `directions` are the **screen angle** from one mark to another, 0 right and 90 down.
   Verify: `read_landmark_file` and `fit_error` in `tools/pose.py`.
2. **Each one is selftested, with no Studio** (CI runs it): the right depth order costs 0 and the
   wrong one costs by how far, and more when it is more wrong; the asked-for edge costs 0, the wrong
   edge costs, and on-screen-when-it-should-be-off costs most — that last needed a **floor** on the
   constraint, because without it a dead-centre mark scored 0.25 against a wrong-edge 0.41 and the
   search preferred the frame it could see. A quarter turn out costs 0.354 and a half turn 0.707 of
   the scale (an RMS over the one exact mark beside it). Four malformed shapes are refused.
3. **`pose.py play` / `stop`.** Studio's two-player session leaves its CLIENT processes unconnected
   to StudioMCP (task 103: three attempts over ~90 s, only Edit and the Play server answered), and
   the viewmodel lives on a client. These start and end a SOLO session through the harness's own
   `Studio.set_play` — the same call `test` makes, so there is no second way to start a session in
   this repo — and each is refused in the wrong state: `play` only from Edit, `stop` only while one
   runs.
4. **The reload landmarks are six marks, an edge, an angle and four depth orders**, every reading
   written down beside it in the file. The screen positions are the Director's prescription (breech
   50–60 % across, 65–75 % down), **not** the video's own, and the file says why: the two frames do
   not share an aspect ratio (16:9 against ~1.24:1, and `side_by_side` matches their HEIGHT), so a
   horizontal fraction does not carry across. The vertical readings, the order, the edge and the
   angle do.
5. **THREE FITS, AND NOTHING SAVED.** Errors 0.4173 → 0.1474, 0.3868 → 0.1525, 0.3564 → 0.1352.
   Fit 1 and 2 both answered with the gun standing on end, butt up — **nothing in the format said
   which way round its own axis it lies**, so `TopLever` and `TriggerGuard` became landmarks: they
   are on opposite sides of the gun's axis, so which is nearer the eye IS the roll. Fit 3 satisfies
   every constraint it was given — Muzzle off the **bottom** (y 100.6 %), Stock 1.28 nearer Action
   1.89 nearer StandingBreech 1.99, Forend 2.27 farther, lever nearer than guard — **and the picture
   is still wrong**: `.screenshots/20261002T044122Z-compare-reload.png` shows the stock filling the
   right of the lower half close to the lens, the sleeve across the centre and the action a dark blob
   low down; the two chamber mouths do not face the camera at all.
6. **What is off, exactly, and it is no longer the format.** The breech lands **1.99 studs** from the
   eye where the file asks **0.9** — and raising its weight from 2 to 4 moved it only 2.12 → 1.96, so
   it is not a weighting problem — while its y lands at 81.7 % against the 70 % asked. Five of the
   six marks sit within about a stud of one another, so the depth terms barely discriminate, and the
   screen positions came from a frame of a different shape. The next lever is not another constraint
   type: it is to read the marks off **our own** frame — hold the pose, move it by hand with
   `pose.py set`, read the landmarks `compare` already prints — and fit against those.

**Not verified.** There is no good reload capture, because there is not a good reload pose. I did not
re-measure the aim view: this task moved no colour and no geometry.
