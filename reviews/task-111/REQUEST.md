# Task 111 - the left hand loads the shells, and no sleeves

Task: 111
Round: 2
Base: `content-hands-karen-1` (`9b45c56`)
Code commit: PENDING -- the gate runs on the paperwork commit and its line is pasted in here

```
[harness] PENDING
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
5. **No sleeve on either glove with NEW_GUN**, the old gun's unchanged -- round 1's claim, unchanged
   and still asserted on the drawn parts.
6. **`Viewmodel.view` now passes the `load` BLOCK, not six flat names with literal defaults.** The
   Reviewer's note was right: those defaults had drifted from the file (0.16 against 0.1, +0.06
   against -0.3, the other side of the gun) and nothing would have failed if the block went missing.
   There is one source now.

## What I could not verify

- **The fetch instant was not caught on camera.** The four frames show the hand still on the forend
  with the gun open, then carrying a shell above the breech, then the second shell above the
  breech with the first seated, then the gun shut and the hand back. The fetch segment is 0.15 s
  and the capture round trip is longer than that; what proves it is the spec, at the fetch time.
- **The second shell's return is cut short**, which the Reviewer's first note predicted: the server
  closes the gun before `returnSeconds` has run out, so the last part of the way home is skipped.
  `returnSeconds` is data; 0.12 is inside the 0.15 the note names, but the close still wins.
- **The three non-blocking notes about the now-dead model-B sleeve machinery, the seated-shell
  tolerance and the `right.x` bound are NOT addressed** -- lean lane, and none of them changes what
  is drawn.
