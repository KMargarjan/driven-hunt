# Task 151 — review request

Task: 151
Round: 2
Base: `a1d87a5` (main, PR #133 merged)
Code commit: `81b424a71346928eb8da92fc416802f26bac68f5`

```
[harness] PASS: 33/33 checks @ 81b424a71346928eb8da92fc416802f26bac68f5 (clean tree) scope=all
```

```
[harness2] <the Director runs this at the new code commit; src/server/Match/ is in TWO_PLAYER_PATHS>
```

## Round 2 — what the Reviewer found, and what changed

**Finding 1 was right, and the reason I gave for not testing the window was false.** The case titled
*"holds the green against a late appearance load, and closes its window"* opened **no window**: it
called `Body.strip` and `Body.paint` by hand, asserted that `strayCleared` had **not** moved, and its
leak check (`appearanceWatching() <= players`) was satisfied by zero windows ever existing. It would
have passed unchanged with `dressWhenLoaded` reduced to `Body.dress`. The comment claiming
*"`dressWhenLoaded` needs a real Player"* was simply wrong — `player: Player` is a type annotation,
and the only things read off it are `UserId`, `Character` and `Team.Name`, which is exactly the stub
seam `docs/design/beater-kit.md` section 15 item 9 named. Claims 13 and 14 are the fix.

**Every non-blocking note is fixed, not queued** — all eight were cheap and true. Two of them were
real latent defects, not tidying: the `ChildAdded` handler could destroy an accessory this module had
just put on, and `clearAttachments` read only the first attachment under a handle. Claim 15 lists
them.

## What changed

**One outfit for both roles.** Karen's design doc: hunter = green jacket + green trousers + orange
hat; beater = the same green plus an orange vest. `Match.Body` stays the single writer of what a
character wears. The green is a measured colour written as `BodyColors`; the hat and the vest are
**real Roblox catalog accessories**, with the repo's existing grey-box plates kept as the fallback.
Karen can switch role in the Forest Test by typing `/beater`.

The horn is Task 152 (the Director's scope cut); its research is section 5 of the note.

Design: `docs/design/beater-kit.md` (Architect PASS, `cde4800`).
Note: `docs/research/2026-10-11-beater-kit.md`.

**One deviation from that design, by the Director's decision of 2026-10-11, recorded for the
Architect in TASKS.md row 151:** the design's section 4.2 concluded the catalog route was shut and
made the plates the lead. That conclusion was wrong (claim 2), so the accessories are the lead and
the plates are the fallback. No owner moved.

## Claims

**1. The green is RGB(86, 80, 56), measured off the sleeve's own albedo, and the two glove maps
disagree — which is why it is a median over both.**
Verify: note section 3, and `Body.BASE_COLOR` in `src/server/Match/Body.luau`. Right glove 267,953
olive pixels median (74, 67, 47); left 265,739 median (96, 92, 65); both 533,692 median (86, 80, 56).
An albedo should be darker than the same surface lit, and the Director's lit sample was (105, 100,
78). `match_outfit.spec`'s `BASE_COLOR` is written out by hand so the module cannot redefine it
silently.

**2. ROUND 1 OF THIS TASK WAS WRONG ABOUT THE CATALOG, AND THE NOTE SAYS SO IN THOSE WORDS.**
Verify: note section 4.2, which now opens *"ROUND 1 OF THIS NOTE WAS WRONG, and the error was
mine."* It had measured `PriceInRobux: 50` and `IsPublicDomain: false` and concluded the route was
"measured shut". The measurements were right; the conclusion was not — **a catalog item's price is
what a PLAYER pays to OWN it on their own avatar**, and an experience may dress a character in any
public catalog accessory at no cost to anyone. Round 1's own evidence already showed it: all three
items **loaded**. The Director caught it. Nothing was uploaded and nothing was bought; there is no
`assets/uploads.json` row, because that file is one row per Open Cloud upload and there was none.

**3. The vest and the cap are real catalog accessories, worn through `AddAccessory`, never
`ApplyDescription`.**
Verify: `src/serverstorage/Assets/init.luau` rows `outfit.vest` (99269365249885, RP UGC) and
`outfit.cap` (13724841516, dvdko), both `kind = "model"`, `scope = "outfit"`,
`basis = "roblox-catalog-accessory"`, `bakedScale = true` (a worn accessory must not be resized: the
Humanoid welds the Handle by its own Attachment). `Body.wearAccessory` clones the template, sets
`CanQuery`/`CanTouch`/`CanCollide`/`CastShadow` false and `Massless` true on every part, and calls
`humanoid:AddAccessory`. `grep -rn "ApplyDescription" src/` returns comments only.

**4. The cap took two goes, and the method that failed is worth more than the one that worked.**
Verify: note section 4.2's "chosen by measurement" block and the `outfit.cap` row's `notes`.
*First attempt:* ten candidates floated as **handles** in one row, photographed once, each read at an
x coordinate I had **guessed**. It picked `6202417448`, which renders **black with an orange trim on
an actual head**. Two mistakes: a pixel sample at a guessed coordinate is not a measurement, and **a
handle in a row is not a hat on a head**. *What settles it:* each candidate alone, same place, one
fixed camera, measured over the whole silhouette with a **dark fraction** beside the colour — the
number that catches a black cap with an orange logo. The pick is (203, 97, 1), saturation 0.995,
green/red **0.478** against `OUTFIT_COLOR`'s 0.439, dark fraction **0.000**; the rejected one is
0.495 and 0.758. The table of ten is in the note.

**5. The vest wraps, so no back plate is needed under it.**
Verify: `<runs-dir>/151-vest-check.png`, rendered front and back on a stand-in torso in the base
green and inspected. The **back is a plain orange panel with a reflective band**; the front has the
V-neck, the zip and two bands. The Director asked specifically, because Karen once could not see a
single-plate vest (PLAYTEST.md, 2026-09-27).

**6. A slot wears the accessory OR its plates, never both and never neither — and the plates are
kept for reasons, not as hedging.**
Verify: `Group` in `Body.luau` (`slot`, `rows`, `clears`), `OUTFITS`, and the `wearAccessory`-or-build
loop in `Body.dress`. Three ways a slot falls back, each with a spec case: no template (the load
failed or has not landed), no Humanoid on the character, and a source that throws. **The middle one
is why the plates can never be deleted** — though the round-1 request overstated it as "every rig in
`match_outfit.spec`" (the Reviewer's note): five of the newer rigs are given a Humanoid precisely so
the accessory path can be driven, and the rigs without one are the ones that prove the fallback. A catalog accessory
is somebody else's mesh and can be taken down. The accessories carry the `HuntOutfitAccessory`
attribute so a re-dress removes ours and **never** a player's own hat.

**7. The real cap was invisible under the player's own hair, and the fix is narrow.**
Verify: `HAT.clears` / `VEST.clears` and `clearAttachments` in `Body.luau`, plus the two spec cases
*"clears the hair a real cap would hide under…"* and *"keeps the player's own hair when the slot
falls back to plates"*. Measured: the preview showed a hunter in a **black cap with an orange peak**
— our cap was on correctly (`SolidCap`, 2.01 × 0.93 × 1.43 on `HatAttachment`) and the black was the
avatar's own hair, 2.08 × 2.05 × 1.94 on `HairAttachment`, a bowl twice the cap's height in the same
place. Task 77's grey-box hat never had the problem because it **raised** its crown; a catalog
accessory hangs where its attachment puts it. So a group names the attachments its accessory needs
clear, and they are cleared **only when a real accessory is about to go on** — with the plates, hair
stays, because they were built to live with it. `Body.strip`'s spare list is untouched.

**8. Two timing defects were found by looking, not by reasoning, and both are fixed.**
Verify: `src/server/OutfitAssetsBoot.server.luau` and `Body.dressWhenLoaded`.
*(a)* The boot wires the source in its first millisecond and `preload` hits the network, while the
player joins a second or two later — so a one-shot re-dress at boot re-dressed **nobody**
(`Players:GetPlayers()` is empty) and the gate showed `outfit.vest=cached outfit.cap=cached` beside
`hat=plates` in the same run. It is now a bounded poll over exactly the characters that still have a
`HuntOutfit` folder, every second for 20 s, self-limiting, and it also covers the case `Loader`
documents: `preload` giving up stops this thread *waiting* while the abandoned load keeps running
and `adopt` takes a late template.
*(b)* In the Forest Test a spawned player came out **green and bare-headed** — the colour survived
(the window repaints it) and the cap did not, because the appearance load applies the avatar's whole
look and can take a freshly welded accessory with it. The window's close is now a full `dress`
rather than a repaint; it is idempotent by construction, so it is "whatever is missing, put it back"
and never a second hat.

**9. Measured live at the code commit, on the server and on the client.**
Verify: the run at `ab81e5b` —
`task151 outfit assets: outfit.vest=cached outfit.cap=cached`,
`task151 live: 1 of 1 teamed character(s) green, 1 kept their own head colour, 1 with no shirt/pants`,
`task151: appearanceWatching=0 (players 1) strayCleared=0 repaints=23`, and from the client
`outfit[client]: 1 role(s) counted (Alhamdulilah824=Shooters[hat=accessory])`. The boot's own line,
from a Play session in the Forest Test:
`[OutfitAssetsBoot] 2 of 2 catalog accessory(ies) loaded: outfit.vest=ok(266ms) outfit.cap=ok(1052ms)`.
**`strayCleared=0` is reported as what it is:** the appearance load has never added a stray shirt in
this place, so the window's `ChildAdded` half has so far caught nothing — which is the number that
decides whether its five seconds can be shortened, and is not evidence that it is wrong. Its
*close* half is doing real work, per claim 8(b).

**10. The Forest Test role switch works end to end, in that place, and the console line is here.**
Verify: `ForestTest.parseRole`/`roleOf`/`setRole`/`clearRole`, `Body.teamForWord` as the one
translator, and the wiring in `ForestTestBoot`. Measured in a Play session in "Driven Hunt Forest
Test" (placeId 130094961655666), with the chat message sent through the real pipeline
(`RBXGeneral:SendAsync`):

| Moment | What the server reported |
|---|---|
| on spawn | `team=Shooters`, `SolidCap tag=hat`, torso green |
| after `/beater` | `team=Drivers`, `SolidCap tag=hat` **and** `Accessory (High Vis Vest) tag=vest` |
| after `/hunter` | `team=Shooters`, `SolidCap tag=hat` alone |

Console: `[ForestTest] Alhamdulilah824 is now a beater (team=Drivers, 0 outfit part(s))` — **0 parts
is correct and is the point**: both slots are wearing real accessories, so no plates were built.
`Player.Chatted` was also measured to fire under `TextChatService` (this place reports
`ChatVersion = Enum.ChatVersion.TextChatService`), so the design's `TextChatCommand` fallback is not
built.

**11. THE LOCAL BODY WAS NEVER HIDDEN IN FIRST PERSON, AND THE CAUSE IS A SECOND WRITER.**
Verify: `src/client/Camera/Rig.luau` (`setLocalBodyHidden`, `Rig.reassertions`) and the new client
case *"keeps the body hidden against the stock TransparencyController, which writes every frame"*.

*What Karen would have seen:* her own right arm as a tan block in the bottom-right and, once this
task gave everybody a cap, her own orange brim across the top.

*Measured, in the Forest Test:* **16 of 20 parts of the local character were DRAWN** in first person
(`LocalTransparencyModifier = 0`), the right arm at camera-relative (+1.00 right, −0.88 down, −0.91
forward) and the cap Handle at (+0.01, +0.66 up, +0.23) with a half-depth of 0.71, so it reaches
past the eye. Only the shotgun's own parts were hidden, and those by `Transparency`, not by this
path.

*The experiment that names the cause:* write `LocalTransparencyModifier = 1` on all 18 drawable
parts of the local character, wait two seconds, read it back — **only 2 were still 1**. The writer
that put them back names itself:
`Players.<player>.PlayerScripts.PlayerModule.CameraModule.TransparencyController`. `Rig.acquire`
**already warns about it**, in this place's own console: *"the stock cameras are not disabled: this
PlayerModule's GetCameras() has no Disable method; the camera is still ours"*. It computes
transparency from its **own zoom distance** rather than from where this camera put the eye, decides
the player is in third person, and writes 0 over everything every frame.

*So the owner was right and the write was not.* `Camera.Rig` is and stays the single writer of
`LocalTransparencyModifier` on the local character, and it **already** tracked accessories — its own
header says two screenshots taught it that. What was wrong is that it wrote **once, on the change**,
into a value something else overwrites on the next frame. Hiding is now re-asserted every frame over
the cached list; **showing** is still written once, because nothing else is trying to hide the body
and a per-frame write there would be a cost with no effect. The `GetDescendants` walk — the 0.8 ms
the header warns about — stays off the frame path; what is per-frame is ~20 property sets.

*Measured after:* `task151 camera: 20 of 20 local part(s) still hidden after 1.5 s; re-asserted 91
frame(s)` — in the gate run at the code commit. **The `20 of 20` is the half that bites.** Round 1's
request said the count "proves something really was contesting the value"; it does not, and the
Reviewer was right to say so — `Camera.step` calls `setLocalBodyHidden(true)` every frame in first
person, so the counter rises whether or not anything overwrote it. What proves contention is the
pre-fix experiment above. The spec's comment now says exactly that, and the case is gated on
`Config.FIRST_PERSON`, because with the flag off `hideBody` is blend-driven and it would have failed
for a reason that is not a defect.

**12. Nothing of the player's own body or outfit is in the first-person view, at three pitches, in
both roles.**
Verify: the six frames in `<runs-dir>/151-fp/`, and the count taken at each one:

| | level | up 30° | down 45° |
|---|---|---|---|
| **hunter** | drawn **0/20** (pitch −0.1°) | drawn **0/20** (29.8°) | drawn **0/20** (−44.6°) |
| **beater** | drawn **0/21** (−0.3°) | drawn **0/21** (29.8°) | drawn **0/21** (−44.6°) |

The pitch was set through the camera owner's own door (`DHLookAt` → `Camera.lookAt`), not by writing
the CFrame.

**13. THE APPEARANCE WINDOW IS NOW DRIVEN BY A TEST, AND IT ASSERTS THE DESIGN'S LIST.**
Verify: `tests/server/match_outfit.spec.luau`, *"holds the green and the outfit against a late
appearance load, then closes its window"*. It calls `Body.dressWhenLoaded(stub, character, ON)`
against a rig with a Humanoid and a stub player `{ UserId, Character, Team = { Name } }`, then
asserts, in order:

| # | What | How it is driven |
|---|---|---|
| 1 | a `Shirt` landing **inside** the window is removed **and `strayCleared` increments** | parent one, wait for the deferred `ChildAdded` |
| 2 | the player's **own hat is kept** | an untagged `Accessory` with no wrap |
| 3 | a `BodyColors` added later is **painted** | parent a red one, read it back as the base green |
| 4 | the **close puts back** what the appearance load took off | destroy our own cap after the dress, wait out the window, assert it is back |
| 5 | **after** the close a new `Shirt` survives, and `strayCleared` does not move | the window is bounded, not a permanent guard |
| 6 | `isWatching(userId)` false **and `appearanceWatching()` exactly 0** | section 13's number |

Row 4 is claim 8(b) reproduced deliberately: the Forest Test player who came out *green and
bare-headed*. The wait uses `Body.APPEARANCE_WATCH_SECONDS`, published for this, so the case cannot
go quietly wrong the day the number moves. **Measured in the gate run:**
`task151 window: strayCleared 0 -> 1, repaints now 24, watching 0`.

**14. `Body.setTeam` has a case too — it had none, and it is the path `/beater` uses.**
Verify: *"setTeam dresses through the window, swaps without leaving two, and forget closes it"*. It
asserts the team is written and read back through `Body.teamOf`, that `Neutral` follows, that a
window opens, that a **team swap replaces the window rather than adding one** (the whole point of
keying by userId), that the vest goes with the team while the hat stays, and that **`Body.forget`
closes the window** — the line the Forest Test boot calls because `Match.forget` never runs there.

**15. Every non-blocking note is fixed. Two were real defects.**
Verify, in order of what they would have cost:
* **`Body.dressWhenLoaded`'s `ChildAdded` handler could destroy an accessory this module had just put
  on.** The close calls `Body.dress` *before* `stopWatching`, so `AddAccessory` fires into a live
  handler, and `Body.isLayered` is true of any wrap-carrying catalog garment. Guarded on
  `ACCESSORY_TAG`. Today's cap and vest are rigid so it never bit; a catalog **jacket** is exactly
  where it would have.
* **`Body.clearAttachments` read only the first attachment under a handle** — it iterates all of them
  now, so an accessory offering more than one slot cannot slip past the name the group asked to clear.
* **The boot's re-dress loop** now remembers who it has offered one (`redressedOnce`): a slot that
  keeps falling back could otherwise re-dress that player once a second for the whole 20 s, each pass
  destroying and re-adding the slot that *did* work.
* `camera_client.spec`'s case gated on `Config.FIRST_PERSON`, and its contention claim corrected
  (claim 11).
* `Rig.trackHiddenPart`'s stale comment ("the write loop only runs when the flag CHANGES").
* `GAME_DESIGN.md`'s owners row now names `clearAttachments` and the four attachments it clears.
* **TASKS.md row 151 now records the SECOND Architect deviation**: `beater-kit.md` M5 and section 6
  say *"hair and head accessories are left alone"*, and the accessory route takes the player's own hat
  and hair off. Named rather than silently contradicted.
* The round-1 request's "every rig in `match_outfit.spec` has no Humanoid" (claim 6) corrected.

## Looked at (rule 5), described wrong-first

**The six first-person frames, `<runs-dir>/151-fp/151-fp-{hunter,beater}-{level,up30,down45}.png`.**
I looked at all six. Every one shows the viewmodel — the shotgun's barrels, the brown glove, the
sleeve — and **nothing else of the player**: no cap brim at the top at any pitch, no tan arm block in
the bottom-right, no orange vest. Compare `<runs-dir>/151-forest-beater.png`, the round-2 frame, where
the brim is a band across the top and the arm fills the bottom-right corner.

**What is wrong with them, first:** the sleeve reads much paler in the forest (bright sun on a low
dirt path) than it does in the DEV preview, so "the clothing matches the sleeve" is a claim about the
*albedo* and about the DEV frame where both are in the same light — not something these six frames
show. And **a pixel test I tried on them is reported as useless rather than as evidence**: an
orange-fraction threshold returned 0.013 % of the frame for all six *and for the round-2 control*,
which means it was measuring the HUD's small red DRIVE marker and never the cap. The count in
claim 12 is the measurement that stands; that one does not.

**`<runs-dir>/151-outfit-preview.png`, re-taken.** Hunter front and back, beater front and back,
beside the live first-person sleeve: the orange cap on all four, the hi-vis vest with its reflective
bands on the beater front and back, and the green consistent across torso, arms and legs. Sleeve
(140, 141, 92) against the beater's leg (139, 131, 89) — within 10 on every channel.

**It had to be re-taken, and that is itself a consequence worth naming:** `Clone()` copies
`LocalTransparencyModifier`, so once the live character is correctly hidden from its own client, a
straight copy of it is **invisible in the very picture that exists to show it**. The preview script
resets the modifier on the copies; they are mannequins, not the local player.

**Still wrong in it, first:** the heads are bald (accepted by the Director — it is what makes the cap
readable), and the clones are frozen mid-stride with one leg lifted, an artefact of anchoring a
copied character rather than anything about the outfit.

## Standing rule A — smoke, in the place Karen will use

Forest Test, 90 s, at the code commit: `gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 |
waves=5 | worst playing sounds over 10 s: 1 (boars=28)` → **SMOKE PASS**.

## What I could not verify

* **`test2`** — a human click; the Director runs it. Required for the merge and for the review round.
* **A published server.** Both accessories load in **Studio**. `InsertService:LoadAsset` has its own
  ownership rules on a live server and this project has never run one. If it refuses there, players
  get the grey-box plates — which is why the fallback exists and why the boot prints which route it
  took.
* **A beater the DRIVE assigned.** No tool can set a live player's team mid-session, so the beater in
  the preview was made by writing `Player.Team` and respawning.
* **Whether any of it looks right.** The colour matches the sleeve to within 10 per channel and the
  cap measures as blaze orange; whether Karen likes the bald heads, the cap shape and the vest is
  hers, and each is one line.
* **A harness flake worth writing down:** two `test` runs in a row failed before this one — once with
  `Studio has the DEV place open (130094961655666 vs 136410205938347)` and once with
  `execute_luau: This call is missing the required studio_id argument`, both immediately after a Play
  session in the second Studio, while `studios` listed only DEV. The third run passed unchanged. This
  is the stale-registration behaviour `tools/studio_mcp.py`'s own docstring describes; reported
  because a flake nobody writes down is a flake nobody fixes.
