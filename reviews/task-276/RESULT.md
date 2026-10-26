PASS (item 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: **item 2 (CORE -- 8 of 10 led
shots accepted as chest claims with the mark on the chest) has NOT been seen in Karen's place at any
rate.** The request reports 0 of 10, and 0 of 4 on the shots where the chest was still presented
when the trigger fell; no led chest hit exists to photograph, so none is described. What HAS been
seen in her place and described is one frame of an **UNLED** shot, `276-ul-ul.15.1.png` -- the hit
card `HIT - .416`, a red diamond on the chest, `Alhamdulilah824 HIND  chest  13 m  RIFLE` -- and the
request's own reading of that frame is that the mark sat 5.033 studs from the chest zone's centre on
an animal at 12 degrees aspect whose chest the shooter could not see. Items 1 and 3 are printed lines
in logs I cannot open; I can say only that the code could produce them.

Delete the producer, by reading, for each case offered as proof:
- **Item 1 (the sign).** The producer is `aim = chest + vel * (flight * LEAD)` and `flight` from
  `Ballistics.timeToRange`. Remove either and the printed column becomes `+0.000 / NEITHER` -- which
  the instrument demonstrably does print, in (i)'s UNLED row (`the lead applied 0.000`) and on the
  two standing-still shots. So the case does not survive the deletion, and the SIGN column does
  discriminate the Director's actual hypothesis: `chest - v * t` would print `BEHIND`. The one field
  that survives is `across 0.000` (note 3). The second side of the direction check, `ang(v, m)`, is a
  separate 0.2 s (time, position) ring against the EWMA the lead uses, so it is not the same engine
  identity: a `vel` that pointed backwards would read ~180 deg there, not 0.9-2.1.
- **Item 1's magnitude is self-consistent with the repo, which is a real check.** Back-solving each
  row's `v * flight` through `Ballistics.timeToRange` with `MUZZLE_STUDS_PER_S.Slug = 2612` and
  `DRAG_PER_STUD.Slug = 4.29e-4` gives shot ranges of 27.1, 93.6 and 189.5 studs -- the closed form,
  not a typed constant.
- **Item 2.** A reported failure, offered as proof of nothing; its table closes (7 claims built + 3
  `static-blocked` = 10; 3 accepted + 4 refused = 7).
- **Item 3.** Producer is the signed-along-`v` offset; with it removed (the magnitude nine tasks
  printed) the sentence "they land behind" cannot be stated at all, and the magnitude half is
  reported as REFUTED, not as a pass.

## Notes (non-blocking)
- `reviews/task-276/REQUEST.md`, PLAN (a) — repeats task **269a(c)** verbatim, a note already raised
  and not fixed: *"the flight to 140 studs is **0.057 s**"*. `Ballistics.timeToRange` with the
  rifle's own `v0 = 2612` and `k = 4.29e-4` gives **0.05524 s** at 140 studs; 0.057 is 145 studs'
  answer. So the lead is **1.77** studs, not 1.84, and *"the two differ by 3.7 studs"* is **3.54**.
  The argument (3.54 against a 6.03-stud trunk is still more than half a body) is unaffected. Fix:
  write 145, or 0.0552 / 1.77 / 3.54.
- `REQUEST.md`, the shot tally — three denominators that do not reconcile. WHAT CHANGED says
  *"twenty live shots"*; item 1 says *"16 of the 16 moving-target shots taken since"* plus *"the
  other two were animals standing still"* = **18**; the next sentence says *"Not one shot in
  twenty"* = **20**. The named trials sum to at least **23** (276-l1.log with 3 tabled but shots
  named `l1.1.1`, `l1.2.1`, **`l1.5.1`**; 276-ul.log 5; 276-ld.log 5; 276-led.log 10). Fix: one
  denominator per trial and one total.
- `REQUEST.md`, item 1 bullet 2 and claim 2 — *"MAGNITUDE: exactly `v * flight`, to the three
  decimals printed, with `across` 0.000"* is offered as a measured corroboration and is an algebraic
  identity. `aim - chest` IS `vel * flight * LEAD`, so its projection on `vhat = vel.Unit` is
  `|vel| * flight * LEAD` against a reference of `|vel| * flight` -- the same product through two
  names, which tests only `|LEAD| = 1` and cannot detect a wrong `vel`, a wrong frame or a stale
  read; and `across` is 0.000 both by construction and with the lead deleted. The request concedes
  *"parallel to the velocity by construction"* in the same bullet, then still prints
  *"Not one shot in twenty read `BEHIND`"* as though it were a survived falsification of the frame
  question. Fix: say `across` proves nothing, and attach "nothing read BEHIND" to the hypothesis it
  does refute (`chest - v*t`) rather than to the direction of `vel`.
- `REQUEST.md`, (i) — *"that is **0.19 s** of animal -- the view lag tasks 271-273 measured at
  0.167-0.178 s"* reads as an identity; 0.19 is above the cited range. (5.19 / 0.19 = 27.3 studs/s is
  inside the measured 21-32, so the inference is sound.) Fix: "within 10% of".
- `REQUEST.md`, item 3 — *"They land behind, all five -- but by 3.6 to 7.1 studs"*. The fifth unled
  shot is the `-79.2 into a tree`, a miss, outside that range and excluded from the mean; four of
  five are clean at 3.6-7.1, which section (i) states correctly as *"every clean shot"*. Fix: "all
  five negative, four clean at 3.6-7.1".
- `REQUEST.md`, item 2's table — the row `a claim was built | 7 (3 static-blocked)` reads as "7
  built, 3 of them static-blocked", but 7 + 3 = 10 means the 3 are the shots that built **no** claim.
  Give `static-blocked` its own row.
- `REQUEST.md`, item 3 / claim 9 — 275a(a) asked for *"ten UNLED shots against ten LED, same build,
  same session"*; the pair run is 5 against 5. The withdrawal is argued on power (quantity 1 stud
  against a 3.5-stud within-arm spread), which is sound reasoning, but the queued item's own
  denominator was not met. Say so where the request says *"re-run as a pair"*.
- `src/client/Weapon/Effects.luau`, `puff` — the defect the request names under THE ONE ACCEPTED
  CHEST CLAIM is **supportable and pre-existing**, outside this change's blast radius, and nothing
  here made it worse. `attachment.CFrame = attachTo.CFrame:ToObjectSpace(frame)` converts the hit's
  **world** position with the part's **current** CFrame, deliberately per its own header (*"the part
  has moved since the server measured the hit, and where this client draws the animal NOW is the
  frame the player can actually see the dust against"*), and the riding path then sets
  `emitter.LockedToPart = true`. So a mark drawn from a point the animal has since left is off in the
  part's local frame by exactly the animal's travel in that interval -- the 5.033 studs reported.
  Worth queueing as its own task: either convert with the CFrame the hit was measured at, or draw the
  card's zone from the point rather than the claimed part.
- `REQUEST.md`, claim 3 — *"it is the better of the two available"* rests on 3 shots, 0.9-2.1 deg
  against 4.0-7.2. The numbers are given, so this is only the word "better" outrunning n = 3.

---
REVIEWER verdict on commit `8da53df03612137b47a6243108ebadce3b69606b` (round 1) · 2026-10-26 11:57 UTC · session cost $2.63, 31 turns · written by tools/agents.py
