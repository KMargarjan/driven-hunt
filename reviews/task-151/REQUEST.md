# Task 151 — review request

Task: 151
Round: 1
Base: `a1d87a5` (main, PR #133 merged)
Code commit: `035b5227cab9bbcfaed8459340dc4799995741d1`

```
[harness] PASS: 33/33 checks @ 035b5227cab9bbcfaed8459340dc4799995741d1 (clean tree) scope=all
```

```
[harness2] <the Director runs this; src/server/Match/ is in TWO_PLAYER_PATHS>
```

**Round 1, still** — the review has never run. `tools/review.ps1 151` refused the first attempt
because `src/server/Match/` is on `TWO_PLAYER_PATHS` and no `[harness2]` line was pasted, so no
Reviewer session has ever started and no round has been spent. The Director runs `test2` and the
review.

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
failed or has not landed), no Humanoid on the character (every rig in `match_outfit.spec` is in this
case, which is why the plates can never be deleted), and a source that throws. A catalog accessory
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
Verify: the run at `035b522` —
`task151 outfit assets: outfit.vest=cached outfit.cap=cached`,
`task151 live: 1 of 1 teamed character(s) green, 1 kept their own head colour, 1 with no shirt/pants`,
`task151: appearanceWatching=0 (players 1) strayCleared=0 repaints=24`, and from the client
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

## Looked at (rule 5), described wrong-first

**`<runs-dir>/151-outfit-preview.png`** — hunter front and back, beater front and back, beside the
live first-person sleeve. Each figure is a clone of the character the server had just dressed; the
beater was made by writing `Player.Team` and respawning, so the **dressing** is the production path
(`Match.watchCharacter` → `dressWhenLoaded`) and only the team write is not. Measured off the frame:
the sleeve reads (140, 141, 92) and the beater's leg (139, 131, 89) — within 10 on every channel.

**What is wrong with it, first:**
* **The heads are bald.** Removing the avatar's own hair is what makes the cap readable (claim 7),
  and it does make them look like mannequins. Karen's call: say the word and the hair stays and the
  raised grey-box hat comes back instead.
* **The clones are frozen mid-stride** and one leg is lifted — an artefact of anchoring a copied
  character, not of the outfit.
* The camera could not be orbited: the client owns it (`Camera.Rig`), so the clones are parked in
  front of the real first-person camera rather than photographed from outside.

**`<runs-dir>/151-forest-beater.png`** — first person in the Forest Test, as a beater. **It shows a
defect I am reporting rather than fixing:** the cap's brim hangs into the top of the first-person
view as an orange band. It is this task's own cap doing it, it was not there with the grey-box hat
(which sits higher and behind the eye), and hiding the local player's head accessories in first
person is **client** work that belongs to the camera's owner, not to `Match.Body`. Named for the
Director; not touched here.

**`<runs-dir>/151-caps/cap-13724841516.png`** and **`<runs-dir>/151-vest-check.png`** — the cap alone
and the vest front and back, both inspected, both described above.

## Standing rule A — smoke, in the place Karen will use

Forest Test, 90 s: `gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=5 | worst playing
sounds over 10 s: 1 (boars=28)` → **SMOKE PASS**.

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
