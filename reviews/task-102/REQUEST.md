# Task 102 — pale metal, a narrow comb, and a pose solver (lean lane, behind `NEW_GUN`)

Task: 102
Round: 1
Base: `317a013` (main, after PR #91)
Code commit: `c569e1e12b1079ca60c5d03c5fffa4baa83ed404`

```
[harness] PASS: 32/32 checks @ c569e1e12b1079ca60c5d03c5fffa4baa83ed404 (clean tree)
[harness2] PASS: 34/34 checks @ c569e1e12b1079ca60c5d03c5fffa4baa83ed404 (clean tree)
```

1. **The pale metal was the LIGHT, so the light became data.** Task 100 measured it: an albedo of
   (118, 120, 122) rendering at (155, 161, 173) in the aimed capture. `look.fill` — brightness,
   range, colour, offset — now lives in `poses.json`, and `Viewmodel.view` publishes the same four
   `VIEWMODEL_FILL_*` names `Camera.Config` used to define as literals, so `Camera.Poses`
   republishes them on the next frame and `pose.py set look.fill.brightness 0.3` is one command.
   Verify: `viewmodel_poses.spec` "tunes the viewmodel's own FILL LIGHT live…" — an override moves
   `VIEWMODEL_FILL_BRIGHTNESS` and leaves the other three at the file's values.
2. **And the drawn light had to learn to follow.** `addFillLight` wrote the Light's properties once
   at build time, so a live change would not have shown until the next rebuild — the hours-per-tweak
   loop the content lane exists to end. `Camera.Viewmodel.applyFill` runs in `update`: four
   comparisons a frame, a write only when one differs. Verify: `applyFill` in `Camera.Viewmodel`,
   called from `Viewmodel.update` beside `Viewmodel.hands`; `camera_client.spec`'s existing fill
   case still compares the drawn light against `Config`.
3. **The stock was at life size and the rest of the gun is not.** Karen's mesh is
   190.153 × 69.262 × 17.743 in its own units, so uniform to 1.32 studs long it is 0.481 tall and
   **0.123 wide** — about right for a real stock (a 486's butt is some 1.6 in across a 45 in gun)
   and wrong for this one, because `BARREL_DIAMETER` is 0.145 where life size at this length is
   about 0.089: the metal is drawn at ~1.65× so a pair of tubes is readable at arm's length. Length
   and height stay uniform (design 6.1); the **width** is the gun's own answer,
   `Gun.WOOD_WIDTH_STUDS` = the action's 0.255, which is **2.07×** what uniform gives. Verify:
   `gun.spec` "scales Karen's stock mesh to the length THIS gun says, and to the WIDTH it says" —
   it reads the width off the drawn `Action` rather than a literal, so the two cannot drift.
4. **`pose.py fit` is a bounded compass search**, over the pose's six `gun.pos`/`gun.rot` numbers,
   minimising the RMS **screen error** (in screen fractions) against landmarks read off a reference
   frame. Pattern: Hooke-Jeeves coordinate search — Kolda, Lewis & Torczon, *Optimization by direct
   search*, SIAM Review 45(3), 2003 — which is the standard derivative-free method for a handful of
   variables and an expensive objective, needs only comparisons, is deterministic, and cannot step
   outside its box. **No screenshot per step**: `QUERY_POSE_LANDMARKS` is a projection, and it now
   reports `StandingBreech`, `Action`, `Forend`, `Stock` and the `Muzzle` attachment beside the bead
   and the hands. A mark may carry a `studs` depth (the one thing a flat picture cannot give) and
   may be declared `offScreen`, which is often the only thing that pins the muzzle down.
5. **And it never measures the frame before its own.** The override carries a `serial` the tool
   bumps per candidate; the landmark query reports the override text the CLIENT can see; the search
   waits for its own candidate and then takes one further reading. A search over a blurred objective
   converges on nothing. `Viewmodel.SERIAL_KEY` is skipped by `merge` exactly as `hold` is — if it
   were not, every candidate would be refused whole and the gun would never move. Verify:
   `viewmodel_poses.spec` "carries the fit tool's serial without treating it as a pose number".
6. **The search is proved with no Studio at all**, which is the only way to test a search: `pose.py
   selftest` (CI runs it) walks it from a wrong start to a known pose inside its budget, checks it
   stops at the box's edge when the answer is outside the bounds — a solver that could leave them
   would "solve" the reload by putting the gun forty studs behind the player — and pins the scoring:
   a mark that is where it should be scores 0, one that is not drawn or is behind the eye is the
   worst case, and one that should be off screen is penalised by how far inside the frame it is.

**Not verified, and it is the whole of the evidence the dispatch asked for.** `fit` and `compare`
both need a running Play session; the gate ends its own, and this Builder has none — so **no capture
exists for this commit**, the seeded fill numbers (brightness 0.8 → 0.45, offset 0.80 → 1.30 studs
forward, because at 0.80 the light sat on the SHORT action's breech) are seeds and not measurements,
and `newGun.reload` has **not** been fitted. `tools/landmarks/newGun-reload.json` carries the marks
measured by hand off `TARGET-reload-open.jpg` (640 × 357, read on a 3× crop of x 0.52–1.0,
y 0.35–1.0), so the run is one command when there is a session.
