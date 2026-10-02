# Task 102 — pale metal, a narrow comb, and a pose solver (lean lane, behind `NEW_GUN`)

Task: 102
Round: 2
Base: `317a013` (main, after PR #91)
Code commit: `c569e1e12b1079ca60c5d03c5fffa4baa83ed404`

```
[harness] PASS: 32/32 checks @ c569e1e12b1079ca60c5d03c5fffa4baa83ed404 (clean tree)
[harness2] PASS: 34/34 checks @ c569e1e12b1079ca60c5d03c5fffa4baa83ed404 (clean tree)
```

**Round 1's finding was right and is answered with pictures, not with an argument.** Nothing in the
code changed this round — the Director ran a capture session at this same commit (`NEW_GUN` on, one
player, every override and the flag cleared afterwards) and the three frames are below, looked at and
measured. **One of them says a shipped claim was wrong**, and that is claim 3.

1. **The 2.07× stock is a visibly broader comb, and here is the number.**
   `.screenshots/20261002T035457Z-compare-aim.png`: Karen's walnut now fills the lower centre as a
   broad grained wedge with the top strap and the two fences above it and the bead on the centre
   cross — the target's layout. **Measured** at the bottom of the half-frame: the comb spans **28 %
   of the width at y = 90 % and 33 % at y = 97 %**, against the video target's 49 % and 52 % in the
   same frame. Before this task it was 14 % and 16 %. So: twice as broad, still about two thirds of
   the target's. Verify: that capture, and `gun.spec` "scales Karen's stock mesh… and to the WIDTH it
   says".
2. **The stock's width is the gun's own answer, not a guess.** Karen's mesh is
   190.153 × 69.262 × 17.743 in its own units, so uniform to 1.32 studs long it is 0.481 tall and
   **0.123 wide** — right for a real stock (a 486's butt is some 1.6 in across a 45 in gun) and wrong
   for this one, where `BARREL_DIAMETER` is 0.145 against a life-size 0.089 so a pair of tubes is
   readable at arm's length. Length and height stay uniform (design 6.1); the width is
   `Gun.WOOD_WIDTH_STUDS` = the drawn action's 0.255, read off the piece rather than written down.
3. **THE PALENESS IS NOT THE FILL LIGHT. Claim 1 of round 1 was wrong, and the test that says so is
   in the captures.** With everything else identical, `look.fill.brightness` was set live from 0.45
   to **0.10** (`.screenshots/20261002T035525Z-compare-aim.png`): the metal's median moves from
   **(132, 135, 140) to (130, 134, 139)** — two points of 255 for a 4.5× change in the light — and
   the whole half-frame differs by a mean of 0.5/255. What is pale is the **albedo**,
   `Gun.LOOK.action` = (118, 120, 122), under daylight. The fill light cannot take it to a dark
   case-hardened grey and no brightness will. **Queued as 102a(a); the darker albedo is not this
   round.** Verify: the two captures and those medians.
4. **What the light change DID do is still worth having, and is the smaller half.** Task 100 measured
   the same pixels at (155, 161, 173) with the light at 0.8 and 0.80 studs forward; at 0.45 and 1.30
   forward they read (132, 135, 140). Most of that 23 points is the OFFSET — moving the lamp off the
   short action's breech — because brightness alone then moves it by 2. The mechanism is the claim
   that stands: `look.fill` is data, `Viewmodel.view` publishes the four `VIEWMODEL_FILL_*` names,
   and `Camera.Viewmodel.applyFill` makes the drawn light follow a live change, which it did not.
   Verify: `viewmodel_poses.spec` "tunes the viewmodel's own FILL LIGHT live…", and the fact that
   setting the brightness live changed the frame at all.
5. **The solver RAN and was shown, and it did NOT produce a usable reload.**
   `pose.py fit newGun.reload --landmarks tools/landmarks/newGun-reload.json` completed — 2 marks,
   1 off-screen, 240 evaluations — and `.screenshots/20261002T035435Z-compare-reload.png` is what it
   found: **the gun lies flat and horizontal across the middle of the frame**, barrels running off
   the left edge, the action and the pale top strap off to the right, both gloves on it from above,
   and the breech is not facing the camera at all. The target has the opened gun angled down-away at
   the lower right with the two chamber mouths toward the lens. The search did what it was asked;
   **two marks plus one off-screen constraint do not pin six numbers.** `poses.json` is unchanged and
   the override was cleared. **Queued as 102a(b): at least four on-screen marks, and a check that
   refuses a fit with fewer than three.**
6. **What is proved about the solver is the search, not the pose.** `pose.py selftest` (CI runs it,
   no Studio) walks it from a wrong start to a known pose inside its budget, holds it at the box's
   edge when the answer is outside the bounds, and pins the scoring: a mark where it should be scores
   0, one not drawn or behind the eye is the worst case, one that should be off screen is penalised
   by how far inside the frame it is. The serial that stops it reading the frame before its own is
   `viewmodel_poses.spec` "carries the fit tool's serial without treating it as a pose number".

**Not verified.** No measurement says what albedo would read as mid case-hardened grey in this
daylight — 102a(a) is a number to find with one more live session, not one to guess here. The
Reviewer's nine non-blocking notes from round 1 are queued in TASKS 102a(c)–(k) unchanged, including
the one that matters most: `applyFill`'s "a write only when one differs" does not hold, because the
properties it compares are float32 and the config values are doubles, so three of the four are
rewritten every frame. The drawn result is right; the comment and round 1's claim 2 overstate it.
