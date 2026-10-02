# Task 103 — dark steel, and a reload that does not look like the target yet

Task: 103
Round: 1
Base: `e9b5c78` (main, after PR #93)
Code commit: `ae7c72e6dd4cc054f02dad0038d927211133c34c`

```
[harness] PASS: 32/32 checks @ ae7c72e6dd4cc054f02dad0038d927211133c34c (clean tree)
[harness2] PASS: 34/34 checks @ ae7c72e6dd4cc054f02dad0038d927211133c34c (clean tree)
```

I ran the capture session myself and **looked at both frames**.

1. **The action is dark now, and the number is from a capture, not a prediction.**
   `Gun.LOOK.action` 118 → **62**, solved from `TARGET-aim.jpg`'s own metal — the top strap between
   the two wooden flanks measures a median of (69, 66, 66), lower quartile (54, 52, 52) — plus the
   measured fact that this gun renders about 14 points above its albedo at the shipped fill.
   **Measured after, in `.screenshots/20261002T041352Z-compare-aim.png`: the sunlit strap reads
   (63, 69, 81) and the shaded fences and lever (16, 22, 36) and (14, 15, 20)**, against (132, 135,
   140) before this task and (155, 161, 173) in task 100. Verify: that capture and `Gun.LOOK`.
2. **Dark, but still two materials.** `gun.spec` "is a DARK case-hardened grey against blued
   barrels…" asserts the action's luminance stays above 1.8× the blued barrels' (it is 2.4×) and
   below 90/255 — because "darker" has an end, and an action that reaches the barrels is a gun with
   no action.
3. **Four on-screen reload marks, each a different point along the gun.**
   `tools/landmarks/newGun-reload.json` carries `StandingBreech`, `Action`, `Forend` and `Stock`,
   measured off a 4× crop of `TARGET-reload-open.jpg` with every reading written down beside it, and
   `Muzzle` off screen. The left hand is deliberately not a mark: in that frame it has left the
   forend to feed a shell, and its offset is its own dial rather than one of the six numbers a fit
   searches. `BarrelLeft`/`BarrelRight` became landmarks in `QUERY_POSE_LANDMARKS` as well — a
   tube's centre is the one reading that says which way the barrels point.
4. **A fit with fewer than three marks is refused, not answered.** `read_landmark_file` stops at
   `FIT_MIN_MARKS`, because task 102 ran a fit on two marks and got the gun lying flat across the
   frame: an answer that looks like a result is worse than a refusal. **Mutation-checked**: with the
   check replaced by `if False`, `pose.py selftest` fails on "two marks cannot pin six numbers, and
   are refused"; restored, it passes. Verify: `pose.py selftest` (CI runs it).
5. **THE FIT RAN AND I AM NOT SAVING IT.** 4 marks, 1 off-screen, 240 evaluations, error
   **0.1048 → 0.0512** screen fractions — and `.screenshots/20261002T041555Z-compare-reload.png` is
   still not the target. What is off, exactly: our gun lies roughly **horizontal** across the lower
   third with the barrels running off to the **left** and the action and stock to the right, both
   gloves on it; the target has the barrels pointing **down-away**, strongly foreshortened, with the
   open breech **close to the lens and the two chambers facing it**. Ours shows no chambers.
   `poses.json` is unchanged and every override was cleared.
6. **Why it is off, and it is a defect in the landmarks rather than in the search.** "Down-away" is
   almost entirely DEPTH, and only one mark carries a `studs` reading; and `offScreen: ["Muzzle"]`
   is satisfied just as well by barrels leaving the LEFT edge as the BOTTOM one. Halving the screen
   error did not make the picture right, which is this repo's own failure mode (`PROJECT_CONTEXT.md`:
   "Things measured correct and looked wrong"). The fix is a mark format that can say WHICH edge a
   point leaves by, or depths on more than one mark — that is a tool change, not a number, and it is
   the Director's call whether it is task 104.

**Not verified.** No capture exists of a *good* reload, because there is not one to capture. The two
client Studios of an `F7` session never registered with StudioMCP (`studios` listed only the Edit and
the Play **server**, through three attempts over ~90 s), so the session was started solo through the
harness's own `set_play` instead; that is a path no CLI command exposes and it is how both captures
above were taken. The aim comb still spans 30 %/35 % of the half-frame's width at y = 90 %/97 %
against the target's 52 %/54 % — unchanged by this task, which moved no stock number.
