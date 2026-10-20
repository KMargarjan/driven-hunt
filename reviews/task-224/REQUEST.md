# Task 224: the lever-action rifle, bought in the shop

Task: 224
Round: 2
Base: `747d628` (main, the task-223 merge)
Code commit: `c4c7b5f401fd7da7d319e5de2f17f72daf379a33`

```
[harness] PASS: 33/33 checks @ c4c7b5f401fd7da7d319e5de2f17f72daf379a33 (clean tree) scope=all
```

`test2` **N/A at this round's head**: no file in this diff is in `TWO_PLAYER_PATHS` — the match, the
drive, the tie and the teams are untouched. `tools/agents.py` says so for this commit's own change
set when it gates this request.

**Round 1 returned two blocking findings and both were right.** This round is those two, and nothing
else. Every claim below that round 1 already made is unchanged and is not restated; what follows is
what moved.

---

## Finding 1 — the hand case was written so it could not fail. Fixed, and shown failing first.

The Reviewer was right on every count: the case asserted `off < 0.5` on a 4.0-stud gun whose own
`gripRadius` is **0.0468**, never asserted `along`, omitted the loop bound entirely, and opened with
`offGripAxis(gripOffset)` — the distance of a point *on* the line *from* the line, which cannot fail.

**1a. The bounds are now the design's three, computed the way the Rigby's are.** Through
`Mode.handOffsetAt` and `gripPointOf` (`offset:PointToWorldSpace(HandAssets.GRIP_STUDS)`) — the one
conversion site the viewmodel really draws with — and not by reading `pos` out of the file. The two
differ by the glove's own `GRIP_STUDS`, and a pose checked at its origin is a pose nobody checked.
*Verify:* `tests/server/lever.spec.luau`, "holds the WRIST with the right hand, inside the gun's own
two bounds" (hip, aimed and cycle), "pinches the LOOP, and keeps pinching it wherever the lever has
got to" (with the rigid-motion invariance case the Rigby's has), and "keeps the pose set's own shape".

**1b. They were run against the OLD poses first, and they failed.** Committed at `c5b97812` with the
poses untouched; the harness said:

```
note  task224 lever right hand hip: 0.0602 off the wrist axis (bound 0.0468), -0.0109 along it (bound 0.1042)
note  task224 lever cycling hand: 0.0113 studs from the loop (bound 0.0713)
failed [server] lever.spec:461 Expected value "true" (boolean), got "false" (boolean) instead
```

**0.0602 is the Reviewer's own 0.060**, reproduced by the game. One correction, offered as a
measurement and not an argument: the Reviewer's loop figure (0.173 from `pos`, "0.268 with
`GRIP_STUDS` applied") does not reproduce — the game measures the cycling hand's **grip point** at
**0.0113** from the loop, inside the 0.0713 bound, before and after this round. The hip hand was the
real one, and it was failing.

**1c. The cause, and why shifting was wrong.** Round 1 built this gun's hand poses by shifting the
**Rigby's** by the difference between the two guns' anchors. That is wrong twice: the anchors are at
different scales (4.4 against 4.0), and the two wrists run in different **directions** — the Rigby's
drops, this one rises 16.3° — so an offset that preserves distance from a *point* does not preserve
distance from a *line*. Each hand is now **solved**: `pos = target − R · HandAssets.GRIP_STUDS`, with
`R` composed the way `Mode.handOffset` composes it (yaw, **then** pitch, **then** twist about the
hand's own long axis — *not* `CFrame.Angles(pitch, yaw, twist)`, which is the convention task 188
shipped a pose in and put the hand on the comb).
*Verify:* the same three cases at the new head:

```
note  task224 lever right hand hip:    0.0000 off the wrist axis (bound 0.0468), -0.0000 along it (bound 0.1042)
note  task224 lever right hand aimed:  0.0000 off the wrist axis (bound 0.0468), -0.0000 along it (bound 0.1042)
note  task224 lever right hand cycle:  0.0000 off the wrist axis (bound 0.0468), -0.0000 along it (bound 0.1042)
note  task224 lever cycling hand:      0.0113 studs from the loop (bound 0.0713)
```

---

## Finding 2 — the drawn lever was certified by nothing. `tests/client/lever_client.spec.luau`.

Four cases, in `SCOPE_SPECS` under **`weapon`** and **`viewmodel`** (standing rule G; `studio_mcp`
and `agents` selftests both pass, and a new spec in no scope turns CI red).

**2a. A REAL clone, built by the owner's own builder** from this weapon's geometry and row: the
moving group is named `Lever`, and no descendant is named `Scope`.
**2b. The `"lever"` branch, driven rather than argued:** at rest the transform is identity, at full
throw the loop's grip point is **down and forward** — the harness printed
`grip (0.000, -0.359, 0.820) -> (0.000, -0.755, 0.253)`. And the fore-end glove does **not** follow
it, which is the `poseHands` finding section 7.1 is built on.
**2c. The shells gate on a real clone:** `handFeedsShells` for all three geometries, the declaration
on the geometry rather than inferred from `MAGAZINE_SWAP` (which this gun does not have, so the old
predicate would have passed it), and a built lever clone carrying **0** shell parts.
**2d. It aims down its own irons:** no `scope` block, `sightKind` is `"bead"`, and the front blade is
on the bore's centre line forward of the action.

`Viewmodel.buildNewGun` is **exported** to make 2a/2c possible: an `OWNED_ONLY` weapon is never in a
test session's hands, so the only way to assert what it draws is to build one. It is a pure builder
— config, geometry and row in, a parentless Model out — and the live path still calls the local.

---

## What I could not verify, and what needs Karen before this merges

**(a) ONE FRAME, NOT FOUR, and the carry pose needs Karen's eye.**
`.screenshots/t224r2-carry.png`, first person, player eye height, DEV drive: the gun draws correctly
— stainless receiver, Picatinny rail with its slots, tube magazine, fore-end, the large loop below,
butt to the lower right — and the Hud reads **five pips, `.45-70`, 10 in reserve**, which is
`BARRELS`/`MAGAZINE` 5 and `START_RESERVE` 10. A dark glove sits at the fore-end. **The right hand is
not in frame**: this carry pose holds the gun low and across the screen with the butt off the bottom
edge, which is where the wrist is. The numbers now say both grip points are exactly on their
anchors; **whether the gun is HELD in a place Karen likes is her call, not mine** — it is
`weapons.lever.carry.gun` and the hand rotations, all content lane. **Per L-008 this grip wants her
look before merge**, and I am saying so rather than hard-stopping only because this round was
explicitly dispatched through to the review.

**(b) No aim, mid-throw or gate-feed frame, and no 50 m / 100 m shots.** I fired through
`FireRequest:FireServer` and the shot was **refused** — the Hud still read five pips and 10 in
reserve afterwards — and I ran out of box before finding out why. Nothing about the aim picture, the
drawn throw or a live hit is claimed here; what the throw does is held by 2b instead.

**(c) CI not checked from here.** `gh` is not authenticated in this session; the branch is pushed.

**(d) Karen's dials, untouched:** `GRAVITY_SCALE` 0.35, the 1.10 s throw and 2.90 s reload, the
recoil block, the three voices and their pitches, and the 650 / 12-hunt price. Nobody here has heard
a sound or felt a kick.

**(e) Still queued as 224a** (from the design): the drawn gate feed and its three prerequisites; one
gate click per run of `Load` steps rather than per round; folding `cycleLength`/`cycleZ` into `Gun`
and `Rifle.Geometry`. Round 1's non-blocking notes are not addressed in this round and remain the
Director's to schedule.
