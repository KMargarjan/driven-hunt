# REQUEST -- Task 323a: stand pick, the owner and the wire

Task: 323
Round: 2
Base: `origin/main` (merged into this branch at `81946956`, carrying 313-322)
Code commit: `25981ef518970a56950af6a65299f499b853948e`

```
[harness]  PASS: 34/34 checks @ 25981ef518970a56950af6a65299f499b853948e (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 25981ef518970a56950af6a65299f499b853948e (clean tree)
```

`git diff --name-only 25981ef5..HEAD` is **empty**: the code commit IS the head. `test2` was run
**twice** at this commit, both clean.

## The two round-1 findings

### Finding 1 -- the collision. FIXED, and it was real.

`applyStandSettle` moved only claimants, and sweep A displaces a **non**-claimant. On the `road`
walk the two men **swap**: provisional h1 -> 1, h2 -> 2; h2 claims 1; the settled deal is h2 -> 1 and
h1 -> 2. Carrying only h2 left **both men on stand 1 with stand 2 empty**, and the forest's
`nearestStand` then bound both to one circle. (The Reviewer's `{5,4,…}` example and this one are the
same defect; `ForestTest.standWalk()` on the `road` happens to be in index order, so it reads as a
swap.)

**The fix:** the settle now carries every hunter whose **settled** deal differs from his
**provisional** one, which is exactly *the pick changed where he belongs*. `provisional` is
`placementLine("Shooters")` with the picks taken out -- the same table `applyPlace` used at
`enterAssigning` -- and `Match.standMoved(was, target)` is the pure, exported predicate.

*Verify:* `applyStandSettle` in `src/server/Match/init.luau`; `Match.standMoved`; case
**"FINDING 1: one claim displaces a NON-claimant"** (the swap, by value, plus the five `standMoved`
branches) and **"FINDING 1: with NO claim the two deals are equal"** (all four layouts x counts 1..8,
so the flag-off path provably carries nobody). The `not StandPick.anyClaim()` early return is still
the first thing the settle does, so flag off is untouched twice over.

### Finding 2 -- the door was driven by no case. FIXED, all three parts.

`Match.onStandRequest` is now driven **by parameter** in `tests/server/match_stand_pick.spec.luau`,
in a describe of its own. Delete the handler and all four cases fail.

* **(a)** a non-number (`"4"`, `{}`, `nil`, `true`) returns `nil`, moves `standPickStats().malformed`
  by 4, moves his **ask budget** by 4, and **judges nothing** -- asserted by every refusal counter
  being unmoved.
* **(b)** a numeric ask returns a verdict whose `stand` is **echoed** (4) and whose `reason` is
  `closed` while the flag is off, and `refused.closed` moved by exactly 1 -- which is how the case
  proves `judge` was *reached* rather than merely *callable*. A second case drives `range` over the
  world's own `standCount`.
* **(c)** the **accepting** path: the verdict is `ok`, and `StandPick.holderOf(5)`,
  `StandPick.standOf`, `Match.standOf` and `stats.accepted` all show **the table was written through
  the door**. The same case then drives a second man to `taken`, the rate floor to `rate`, and a
  change past the floor that frees the old stand at once.

**(c) needed a lever, and the lever is the MEASUREMENT, never the rule.** With `STAND_PICK` off
`Phase.pickWindow` is false, and **no spec may call `Match.start`** (`match_live.spec`'s own rule;
`Match.start` asserts *"called twice"*), so the accepting path had no lever at all.
`Match.setStandAskReader(fn?)` substitutes **what the world said** -- `nil` is "measure it", which is
production and the only thing the game ever runs; `Match.stop` clears it and so does the spec's
`afterEach`, and a case asserts `Match.standAskReader() == nil` in production. `StandPick.judge` and
`StandPick.claim` are the real ones throughout. This is CLAUDE.md's own flag rule --
*"A flagged path must be reachable BY PARAMETER as well as by flag, or its two states cannot be
tested while the flag sits at one of them"* -- and the `Body.setGroundReader` /
`Weapon.setEntitlementProvider` idiom it already uses.

## Four of the notes, also fixed

* **case 5's count is 64, not 128.** `dealLine(w,s,e,c)` and `(w,s,e,c,nil)` are the same argument
  list in Luau, so half the comparisons were a pure function against itself. The case now compares
  only `{}` (which enters sweep A's branch) and asserts 64. The note says why.
* **`close()` is load-bearing.** `StandPick.claim` now reads `open`, so the window is shut for the
  **table** as well as for the player and a late claim is refused `closed` -- `open` has a production
  reader and `close()` is not a flag nobody consults.
* **`StandPick.forget` returns the stand it freed**; `Match.forget` no longer releases twice.
* **the ask is counted BEFORE the type check**, so a client spamming tables spends the same budget as
  one spamming numbers -- which is what `STAND_PICK_MAX_REQUESTS` claims to bound.
* **`src/server/HitLog/init.luau`** no longer says `Drive.remotes()` has no inbound remote.

## Notes left alone, each with its reason

* **REQUEST claim 6's wording** ("3 remotes, exactly one inbound") -- the Reviewer is right that
  direction is not a property of a `RemoteEvent`. The case counts three children and names
  `StandRequest`; the direction claim is carried by the code (`FireServer` appears in exactly one
  place in `src/client/Match`, `OnServerEvent` in exactly one place in `src/server/Match`), not by
  that case. Stated here rather than overclaimed again.
* **The three `StandPick.release` call sites, `placementLine`'s `picks` line and the two snapshot
  fields have no case of their own.** True. They are one line each at a composition point, and with
  the flag off every one of them is a no-op, so a case would assert nothing a reading does not. They
  are 323b's first dependency and the Director may queue them.
* **`Flags.MAX_FLAGS` 22 -> 23** is the Director's call, as the Reviewer says.

## Claims from round 1 that are unchanged

1. `StandPick` is the one writer of the claim; `judge` is pure (no service, no `Player`, no clock);
   `claim` yields nowhere. *Verify:* grep the module for `task.`, `Players`, `pcall`, `os.clock`.
2. The window **is** the `Assigning` phase: no new `PhaseName`, no new clock, no new timestamp.
   `grep -n "Picking" src/` is empty. Cases 3, 4.
3. Flag off is today's placement bit for bit -- 64 equal-by-value deals, plus production's own
   `STAND_PICK_SECONDS == 0`, `standsSettled == 0`, `standSettleStuds == 0`.
4. Sweep A is strictly stronger than the fallback (case 6, the case one pass gets wrong).
5. The entitlement is checked twice; a claim of a stand the layout does not state is ignored, not
   clamped (case 11 and its sibling).
6. One inbound remote carrying one number; nothing coerced (cases 12 and the door's (a)).
7. The client derives nothing; one outbound door (cases 21, 22).
8. `Body` stays the one writer of where a character stands -- `Body.carry` calls no `LoadCharacter`,
   refuses a character something else holds, and cannot yield (cases 18, 19, 20).
9. A stand freed by a change, a leave or a role switch is free at once (case 8, three call sites).
10. Zero new `TWO_PLAYER_PATHS` entries; no call site left on an old arity.

## What could NOT be verified

* **NOT PROVEN LIVE -- nobody has seen this run in Karen's place.** The Director closed her Forest
  Test for this task, so there is no `stats.movedStuds` from a real drive, no live
  `Body.snapMisses()` after a settle, and no frame. 323a draws no pixel (screenshot N/A, design §15).
* **The two-player race is not runnable at this commit, and the flag is why.** With `STAND_PICK` off
  `Phase.pickWindow` is false, so every ask is `closed` -- there is no race to run. What stands in
  its place: case 7 (`claim` twice, same stand, same `now`) and the door's own `taken` refusal in
  (c). `test2` ran twice, clean, and what it proves here is that **nothing in the match, the drive,
  the tie or the teams moved**.
* **A real tap / `GuiButton.Activated`** is 323b's; the harness cannot synthesise one.
* **`placementLine` and `applyStandSettle` are locals.** Case 16 and the finding-1 cases assert the
  **composition they build**, not the locals. Design case 20 (`standAreaOf` after a settle) is not
  asserted: it needs a started `Match`.

## Not verified / for the Architect (no design file was edited)

* `docs/design/stand-pick.md` §5.2's *"Only claimants are moved"* is the sentence finding 1 came
  from, and §12's *"`stats.standsSettled == <how many hunters claimed>`"* follows from it. Both are
  now wrong: the number is **how many hunters the pick moved**, which is >= the claimants.
* `docs/design/drive.md` §9.1 and line 117 still say this system takes no client remote;
  `stand-pick.md` §14's delta table does not list that amendment.
* `stand-pick.md` §10.1 does not mention `Flags.MAX_FLAGS`, which the row cannot be added without.
