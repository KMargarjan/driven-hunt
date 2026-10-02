# Task 111 - the left hand loads the shells, and no sleeves

Task: 111
Round: 1
Base: `content-hands-karen-1` (`9b45c56`)
Code commit: PENDING -- the gate runs on the paperwork commit and its line is pasted in here

```
[harness] PENDING
```

`test2` is N/A: every changed file is in `WEAPON_VIEWMODEL_PATHS`
(`src/client/Camera/Viewmodel.luau`, `src/shared/Viewmodel/`, `tests/client/gun_client.spec.luau`),
checked with `tools/agents.py`'s own `needs_two_player`, which answered `[]`.

## Claims

1. **No sleeve on either glove with NEW_GUN on.** `Viewmodel.sleeveSegments` answers an empty list,
   so `addHand` builds none and `poseHands` places none. The OLD gun keeps its sleeve, taper and
   to-the-shoulder rule exactly as task 108 left them: its glove is the one that ends in the open
   cuff the sleeve exists to plug. Measured on the running session: the drawn viewmodel's parts are
   `Handle, Barrels, BarrelGroup, Bead, HandLeft, FrameGroup, HandRight` and nothing else.
2. **The left hand loads, on the SHELL'S OWN CLOCK.** `Viewmodel.shells` already slides each fresh
   shell forward from `feedFromStuds` over `feedSeconds` from `loadedAt[barrel]` -- the moment the
   SERVER said that barrel was loaded. `Viewmodel.loading` is placed from those same two numbers, so
   "the shell travels with the hand" is not two timelines that could drift: it is one. The hand
   blends in over the first `reachShare` of the feed, sits `behindStuds` behind the shell all the way
   home, then blends back over `returnSeconds`. Two shells are two of those, a moment apart, because
   the server loads one barrel at a time and whichever is further along wins.
3. **Karen's numbers are untouched and the right hand never leaves the grip.** `newGun.reload.left`
   and `.right` are byte-identical to `content-hands-karen-1`; the only `poses.json` change is the
   new `newGun.reload.load` block. At weight 0 the left hand is bit-for-bit her pose.
4. **The seated shell is still task 107's.** `Viewmodel.shells` is not touched by this task at all --
   the hand follows the shell, not the other way round -- so where a shell ends up is the same
   arithmetic and the same spec.
5. **One client case measures all of it on the drawn instances**: mid-feed the left hand is within
   0.45 studs of the drawn `FreshShell1` and less than half its rest distance from it, the right hand
   is within 0.001 studs of the grip, after the feed and the return the left hand is back within
   0.001 studs of Karen's pose, the shell is seated at the chamber mouth, and no part named `Sleeve`
   exists with NEW_GUN on while the old gun still has one.
6. **Every number is tunable live**: `newGun.reload.load.{reachShare, returnSeconds, behindStuds,
   sideStuds, upStuds, fingerDownDeg}` are `pose.py set` paths, and three of them were moved that way
   while watching the screen (see below) before `pose.py save` wrote them.

## What I could not verify

- **The glove is big in the frame and its fingers read down-left, not along the bore.** The brass
  head is clearly beside the fingertips at the breech, but the motion reads as "the hand is at the
  shell" more than "the fingers push it in". The three `load` numbers are the dial for that and
  Karen can move them live.
- **Only one reload was photographed**, with the second shell's push caught only as the readout
  going 21 -> 19 -> both loaded; the two pushes were not captured separately.
- **No mutation check.** The case rests on a distance, not on a guard; the lean-lane rule keeps
  mutation checks for guards, and this round had none.
