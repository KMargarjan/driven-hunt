# Task 111 - the left hand loads the shells, and no sleeves

Task: 111
Round: 3
Base: `content-hands-karen-1` (`9b45c56`)
Code commit: `0c5c268438fb338e83e96dc5403fb03df3ec41ed`

```
[harness] PASS: 33/33 checks @ 0c5c268438fb338e83e96dc5403fb03df3ec41ed (clean tree)
```

`test2` is N/A: every changed file is in `WEAPON_VIEWMODEL_PATHS`
(`src/client/Camera/Viewmodel.luau`, `src/shared/Viewmodel/`, `tests/client/gun_client.spec.luau`),
checked with `tools/agents.py`'s own `needs_two_player`, which answered `[]`.

## Claims

1. **The hand FETCHES the shell now**, which is Karen's whole complaint: round 1 went barrels ->
   breech with nothing picked up. One shell is four moments, every one of them data in
   `newGun.reload.load`: rest -> **fetch** (`fetchSeconds`, back toward the hunter, low and left,
   empty), fetch -> **above** (`carrySeconds`, carrying it up over the open chamber), above ->
   **seat** (`seatSeconds`, straight down in), seat -> rest (`returnSeconds`). Two shells are two of
   those, because the server loads one barrel at a time. `fetch` is a point in the GUN's own frame
   (during the reload the gun is held at one fixed pose, so that frame and the hunter's differ by a
   constant); `above` and `seat` are offsets from the CHAMBER MOUTH, so they follow the barrels.
2. **The shell is in the hand from fetch to seat**, placed from the hand's own frame at
   `shellInHand`, so the two cannot come apart with nothing parented; once let go it is back on
   `shellFeedAt`, which is the slide `Viewmodel.shells` has drawn since task 99.
3. **Round 1's finding was right and is fixed at the root.** The case asserted a constant --
   `loadFrameAt` minus `shellFeedAt` was a fixed offset -- and passed with the feature deleted.
   `Viewmodel.setClock` is the seam (the same shape as `setSource`): the player's own camera loop
   clears the reload state on every frame it draws, so a spec that WAITS loses the state and one that
   does not only ever sees weight 0. The case steps its own clock and reads the DRAWN left hand at
   the fetch (more than 0.3 studs off Karen's rest pose, and within 0.001 of the keyframe), while
   carrying (the drawn shell within 0.35 studs of the drawn glove and more than 0.2 from its
   chamber), seated (the shell at the mouth) and after the return (back within 0.001 of her pose),
   with the right hand within 0.001 of the grip throughout. **Mutation-checked**: with the blend in
   `poseHands` deleted, `gun_client.spec:353` FAILS -- the hand never leaves the barrels.
4. **Karen's rest numbers are untouched** (`newGun.reload.left` and `.right` byte-identical to
   `content-hands-karen-1`), and the whole motion is `pose.py set` paths under `newGun.reload.load`.
5. **ONE ANIMATION PER SHELL, NOT TWO -- round 2's blocking finding, and Karen's own words for the
   same defect.** The Reviewer: "the fresh shell feeds ITSELF into the chamber while the hand is away
   fetching it, then teleports back into the hand"; Karen, live: "either we have 2
   animation when shells go inside or one go straight another from hand" -- both were drawn, because
   `Viewmodel.shells` fell back to the old self-sliding feed for every barrel that was not the one in
   the hand. `Viewmodel.freshShellAt` is now the ONE place that decides where a fresh shell is AND
   whether there is one: with the new gun, nothing on screen before the hand picks it up, the hand's
   own frame while it carries it, the chamber once it is in. The OLD gun's self-sliding feed comes
   out of that same function, unchanged. The case steps the whole load on its own clock and requires
   at every step that the shell is in one of those three states and never on the slide --
   **mutation-checked**: with the old feed back on for the new gun, `gun_client.spec:384` FAILS. The
   stale comments the finding names are gone with the code they described. No sleeve on either glove
   with NEW_GUN either, the old gun's unchanged.
6. **`Viewmodel.view` now passes the `load` BLOCK, not six flat names with literal defaults.** The
   Reviewer's note was right: those defaults had drifted from the file (0.16 against 0.1, +0.06
   against -0.3, the other side of the gun) and nothing would have failed if the block went missing.
   There is one source now.

**Round 3 and not 2**: the round-2 verdict on `63a5c2c` landed while this was being fixed, and its
one blocking finding IS this fix, so the counter had already moved.

## What I could not verify

- **The fetch instant was not caught on camera.** The four frames (`.screenshots/20261002T183720Z-task111r2-{fetch,carry,above,seated}.png`) show the hand still on the forend
  with the gun open, then carrying a shell above the breech, then the second shell above the
  breech with the first seated, then the gun shut and the hand back. The fetch segment is 0.15 s
  and the capture round trip is longer than that; what proves it is the spec, at the fetch time.
- **The second shell's return is cut short**, which the Reviewer's first note predicted: the server
  closes the gun before `returnSeconds` has run out, so the last part of the way home is skipped.
  `returnSeconds` is data; 0.12 is inside the 0.15 the note names, but the close still wins.
- **The three non-blocking notes about the now-dead model-B sleeve machinery, the seated-shell
  tolerance and the `right.x` bound are NOT addressed** -- lean lane, and none of them changes what
  is drawn.
