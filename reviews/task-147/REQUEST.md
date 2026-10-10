# Task 147 - the rifle comes down to work the bolt, and the tube goes near-black

Task: 147
Round: 1
Base: main (`809a290`, task 146 merged as PR #129)
Code commit: `4edf5fad9eb7c1cc80b0a02fc2dc0ee65940e7c2`

```
[harness] PASS: 33/33 checks @ 4edf5fad9eb7c1cc80b0a02fc2dc0ee65940e7c2 (clean tree) scope=all
```

`test2` is N/A: the diff is `poses.json`, one colour in `Rifle.CONFIG` and one spec case — nothing in
`TWO_PLAYER_PATHS`.

Karen, 2026-10-10, with a screenshot of the open rifle at hip: *"still scope ring there / after each
shoot right hand has to reload like it does after 3 shoots / so we keep after 3 shoots magazine
change but after each shoot has to move right hand nad reload"*. Transcribed in `PLAYTEST.md`.
**No Architect run:** no new owner and no new system.

**TWO OF HER THREE SHIPPED. THE RINGS DID NOT, AND THE REASON IS GEOMETRY** — claim 8.

**WHY THIS IS STILL `Round: 1`.** `reviews/task-147/RESULT.md` passed `3856389`. Two of its six notes
were text I had just shipped that misstated the record — one of them crediting Karen with words she
did not say, which is the mistake task 142 corrected me on — so they are fixed in `e920aff`, after
the commit that was passed. A PASS does not consume a round, so `tools/agents.py` refuses anything
but `Round: 1` here; this asks for a verdict that covers the code. Claim 11 is what changed.

## The ten claims

1. **THE DISPATCH'S PREMISE WAS WRONG, AND I MEASURED IT BEFORE CHANGING ANYTHING.** It read task
   146's `+0.28 Break → +0.56 Close` as a 0.28-second bolt, "too fast to see", against a slower
   chambering bolt. `driven-hunt-runs/t147-bolt.luau` logs every cycle's right-glove travel:

   ```
   AFTER-SHOT     0.817 / 0.816 / 0.817 studs over 0.65 s (33-35 frames)
   AFTER-MAGAZINE 0.824 studs over 0.65 s (34 frames)
   ```

   **They are one definition and already identical.** `+0.28` was the delay from the shot to the
   bolt STARTING, not its length.

2. **NOR WAS RECOIL HIDING IT.** The same trace watches the viewmodel's own transform: **the gun
   stops moving 0.23 s after the shot** (three shots, 0.23/0.24/0.24) and the bolt starts at 0.28.
   They barely overlap.

3. **WHAT WAS ACTUALLY WRONG WAS WRITTEN IN THE SPEC'S OWN COMMENT, SINCE TASK 142.** `cycle.gun` was
   seeded bit-for-bit equal to `carry.gun` — *"Seeded equal; the Director may make them differ later,
   and then this case is the thing that says so out loud."* So **the rifle did not move at all while
   the bolt was worked.** All there was to see was a thumbnail-sized glove sliding ALONG the gun's own
   axis, behind the scope, foreshortened into almost nothing — while the magazine change reads
   because the magazine drops 0.42 studs straight DOWN into open space. **Verify:** the frame
   `t147-bolt-0.png` from before the change, where the right hand is a pale smudge behind the scope.

4. **SO THE GUN COMES DOWN TO WORK THE BOLT.** `cycle.gun` is now back 0.55 studs (`z -2.0 → -1.45`),
   up 0.20 (`y -0.62 → -0.42`) and rolled 20 degrees (`rot.z -10 → -30`, `rot.y 45.7 → 56`), so the
   bolt side of the action turns toward the eye. `Mode.viewmodelOffset` lerps toward it by the
   cycle's own progress, which runs 0 → 1 → 0, so the rifle comes out of the shoulder, is worked,
   and goes back with no new branch anywhere. **Tuned live with `pose.py` and looked at**, not
   calculated. (Two different turns, not one: a 20-degree ROLL about the gun's own axis and a
   10.3-degree YAW.)

5. **IT IS THE SAME POSE FOR BOTH BOLTS, because there is still only one of them.** Karen asked to
   keep the magazine change exactly as it is, and nothing in `RELOAD` changed — the bolt that
   chambers after it simply gets the same new motion. **Verify:** `rifle.spec`, "BRINGS THE RIFLE
   DOWN TO WORK THE BOLT, which it did not until task 147", which also asserts `rifle_open`'s cycle
   pose equals the rifle's, field by field.

6. **THE CASE THAT USED TO ASSERT THE OPPOSITE NOW ASSERTS THIS.** It was "holds the gun still while
   the bolt moves" and it would have failed on this change — which is exactly what its own comment
   promised it would do. It is rewritten to say what the four numbers mean rather than to re-state
   them: back, up, rolled, and the same on both rifles.

7. **THE SCOPE TUBE IS NEAR-BLACK.** `rimColor` 60,60,62 → **22,22,24**. Karen's reference is a dark
   body with a lit top edge; one flat UI colour has to pick the body rather than the highlight.
   **Verify:** `t147-ship-scope.png` beside `karen-scope-target.jpg`.

8. **THE RINGS COULD NOT BE REMOVED, AND IT IS NOT A NODE PROBLEM — IT IS A FACE PROBLEM.** The
   dispatch asked for a re-split into `rifle.action_open` without the rings and the scope base.
   Measured (`driven-hunt-runs/t147-vijsjes.py`):

   ```
   Vijsjes_Low  2074 verts:  976 at y +0.20..+0.30   the mount RINGS
                             732 at y +0.12..+0.20   their bases on the receiver top
                             244 at y -0.10..+0.00   trigger-guard screws, z +0.14..+0.90
   Midden2_Low  2420 verts: 1299 ABOVE y +0.20, z +0.116..+0.569
                            -- the scope BASE, in the same node as the receiver itself
   ```

   **Dropping `Vijsjes_Low` takes the rings and leaves the base block. Dropping `Midden2_Low` leaves
   a hole where the receiver was** — more than half its vertices are up at scope height, so it is not
   a separable lump. `gltf_split.py` selects whole NODES, so neither gives Karen what she asked for.

9. **WHAT IT WOULD TAKE, SO THE DIRECTOR CAN DECIDE.** Face-level surgery in Blender: delete the
   faces above roughly `y +0.19` between `z +0.10` and `z +0.60` on both nodes, **cap the opening**
   so the receiver is closed, then prep and upload as `rifle.action_open`. That is a modelling job
   with a judgement call in it (how much of the rail to leave, whether the cap reads), not a plan
   edit — and it is the same shape of work as `boar_prep_blender.py`. **I did not produce an upload
   folder, so there is no `READY TO UPLOAD`.**

10. **NOTHING ELSE MOVED.** The content-lane diff is eight numbers (four each on the two rifles'
    `cycle.gun`); the code diff is one `Color3`; the test diff is one case. `CYCLE`, `RELOAD`, the
    magazine, the sounds, the hands and the sight picture are untouched.

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t147-ship-bolt-1.png` (mid-cycle, `1/3 .416 6 R`) | **The glove still reads as a pale khaki blob rather than fingers**, and the gun coming toward the camera is a bigger visual event than the hand itself — the scope tube also crosses the bolt's path. But it IS now a hand on the bolt handle, large and clear of the receiver, where before it was a smudge: the rifle is rolled with the action facing the eye and the bolt drawn back |
| `t147-bolt-0.png` (before the change, same moment) | The same instant with the old pose: the rifle is exactly where it sits at rest, down in the corner, and the right hand is a few grey pixels behind the scope. This is the pair that makes claim 3 |
| `t147-ship-scope.png` | **The tube is now so dark it nearly merges with the darkened surround** — Karen's reference has a lit top edge that one flat colour cannot give. Everything else is as task 146 left it: the cross spans the glass, the red dot is centred, the forest outside is visible |
| `karen-open-rifle-rings.png` (hers) | Both gold mount rings standing on the action at hip, which is claim 8 and is not fixed |

## Standing rule A, Forest Test, 85 s, with RIFLE ON

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 20 boars alive

## What I could not verify, and what I am unsure of

* **I cannot know whether this is enough for Karen.** The thing she cannot see is a hand against a
  gun, in the corner of the screen, for two thirds of a second. Making the gun move is the biggest
  lever the content lane has; if it still does not read, the next levers are the cycle's LENGTH
  (0.62 s, shared with the chambering bolt she already sees) and the bolt's own drawn travel.
* **The mid-cycle frames are a race.** The capture round trip is longer than the 0.65 s window, so I
  fired four times and kept the frames that landed inside it; two of the four landed at rest.
* **I did not touch `CYCLE`'s timings**, deliberately: she asked to keep the magazine change as it is
  and the two bolts share one definition, so a timing change would have altered the one she likes.
* **Nobody has seen the open rifle's cycle pose from outside** — `pose.py inspect` holds `carry`,
  `raise`, `aim` and `reload`, not `cycle`.

## Round 2 (still `Round: 1` by the counter): two comments that misstated the record

11. **I SHIPPED TWO PIECES OF TEXT IN ROUND 1 THAT SAID THE WRONG THING, and the Reviewer caught
    both.** (a) Task 146's reason for the grey tube — *"a black ring against a black mask is one
    shape"* — was left standing in the present tense directly above `rimColor = 22, 22, 24`. It was
    true of task 141's OPAQUE mask and stopped being true when task 146 made the surround 0.45
    transparent; the comment now says that and marks the old reason as history. (b) *"Karen, after
    playing task 146: the tube read as a light grey band"* **is not hers** — her note is the rings
    and the bolt and says nothing about the tube. The words are the DISPATCH's, and the comment names
    the Director now. **This is the same mistake task 142 corrected me on**, which is why it is fixed
    here rather than queued. The comment also records that the tube may now be too dark, because
    nobody in this toolchain can settle that and Karen's eye owns it.
    Also: the spec's title said the rifle comes DOWN while its own first assertions say up and back,
    and the four sign assertions now say out loud that they pin the direction and not the distance.
