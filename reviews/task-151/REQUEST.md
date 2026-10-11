# Task 151 — review request

Task: 151
Round: 1
Base: `a1d87a5` (main, PR #133 merged)
Code commit: `36fb2b135967d0bbe5c6500a9d1f02e3813b49cb`

```
[harness] PASS: 33/33 checks @ 36fb2b135967d0bbe5c6500a9d1f02e3813b49cb (clean tree) scope=all
```

`[harness2]` is **not** pasted: `src/server/Match/` is in `TWO_PLAYER_PATHS`, so the PR to `main`
needs `test2` — but it costs a human click, the line above is full `scope=all` evidence, and the
Director has the click queued in `ESCALATE.md` (NEEDS KAREN 2). Nothing in this change is about who
the OTHER player is.

## What changed

One outfit for both roles. Karen's design doc: hunter = green jacket + green trousers + orange hat;
beater = the same green plus an orange vest. `Match.Body` stays the single writer and gains three
writes on the signals it already had — the base colour, the removal of the player's own clothing,
and a short window that holds both against a late appearance load — plus a chat-driven role switch
in the Forest Test so Karen can see a beater in a world that has none.

The horn is Task 152 (the Director's scope cut); its research is section 5 of the note.

Design: `docs/design/beater-kit.md` (Architect PASS, `cde4800`).
Note: `docs/research/2026-10-11-beater-kit.md`.

## Claims

**1. The green is RGB(86, 80, 56), and it was measured off the sleeve's own albedo rather than off a
lit screenshot — and the two glove maps disagree, which is why it is a median over both.**
Verify: the note's section 3 table, and `Body.BASE_COLOR` in `src/server/Match/Body.luau`. Right
glove 267,953 olive pixels median (74, 67, 47); left 265,739 median (96, 92, 65); both 533,692
median (86, 80, 56). The Director's lit sample was (105, 100, 78) — an albedo should be darker than
the same surface lit, which is the only agreement available here. `match_outfit.spec`'s
`BASE_COLOR` is written out by hand, so the module cannot silently redefine it.

**2. The dispatched catalog route is measured shut, so the dispatch's own fallback is the lead and
this task adds no asset id, no upload and no Robux.**
Verify: the note's section 4.2. `MarketplaceService:GetProductInfo` + `InsertService:LoadAsset` in
the DEV place — "High Vis Vest Orange" (99269365249885) **50 R$, `IsPublicDomain: false`**; "Hunting
Hat" (1043468) 99 R$; "Hunting Cap" (6037258153) 90 R$ and its own accessory is named
**"Hunting Cap [Red]"**. Then `AvatarEditorService:SearchCatalog` with `CatalogSearchParams.MaxPrice
= 0` over *high vis vest*, *safety vest*, *hunting vest*, *orange cap*, *orange beanie*, *hunter
orange hat*: no blaze-orange hi-vis vest and no orange hunting cap in the free pool at all. Grep the
diff for `rbxassetid`, `LoadAsset` and `uploads.json` — this change contains none.

**3. The green is `BodyColors` written directly and never `Humanoid:ApplyDescription`, and the head
is never painted.**
Verify: `Body.paint` in `src/server/Match/Body.luau` writes `stem .. "Color3"` for each entry of
`BASE.limbs`, which is `Torso, LeftArm, RightArm, LeftLeg, RightLeg` — `Head` is absent. `grep -rn
"ApplyDescription\|HumanoidDescription" src/` returns comments only. The reason is in the module
header and the design's N1: `ApplyDescription` rebuilds the character's parts, and this is the
module that welds plates to `UpperTorso` (`Body.dress`) and anchors a tied player's root
(`Body.tieCharacter`). Cases: *"writes the green on five properties and never on the head"* and
*"creates the BodyColors itself when the character has none"* in `tests/server/match_outfit.spec.luau`.

**4. The hat is declared ONCE and both roles wear it; a hunter wears 2 parts and a beater 6; no hat
or vest geometry changed.**
Verify: `HAT`, `VEST` and `OUTFITS` in `src/server/Match/Body.luau` — `Shooters = { base = BASE,
parts = { HAT } }`, `Drivers = { base = BASE, parts = { HAT, VEST } }`. The spec case *"declares the
hat ONCE"* asserts **table identity** (`beater[i] == hunter[i]`), not field equality, so a second
copy of those two rows fails. Every stud, `scale`, `pad`, `anchor`, `fallbackLimb` and
`OUTFIT_COLOR` is unchanged, and the Task 82 clearance invariant still runs over three torsos
(`vestRows()` keeps the hat out of that case, because a brim has no `anchor` and is not a plate
fitted to a torso).

**5. `Body.strip` removes exactly what would hide the green, and spares the head's own things — and
the predicate asks for the wrap objects, not for `AccessoryType`, for a measured reason.**
Verify: `Body.isLayered` and `Body.SPARED_ACCESSORY_TYPES` in `Body.luau`; the spec cases *"takes off
what would hide the green"* (returns 4: Shirt, Pants, ShirtGraphic, a layered Accessory; the Hat-
and Hair-typed accessories survive) and *"knows layered clothing by its wrap and not by the catalog's
taxonomy"*. Two measurements behind it, both in the Edit place on 2026-10-11:
`Instance.new("WrapLayer")` refuses every parent but a MeshPart — *"BaseWrap must be parented to a
MeshPart"* — which is itself the evidence that a layered garment is a mesh standing off the limb;
and `AccessoryType` came back `Enum.AccessoryType.Unknown` on all three real catalog accessories
probed, so it is used only for the spare list, where being wrong costs a hat rather than the design.
Nothing is backed up and nothing is restored (design N4) — a player's own clothes return on their
next character, and the module says so.

**6. A late appearance load cannot undo the colour, and the window cannot leak.**
Verify: `Body.dressWhenLoaded` in `Body.luau`, and the four call sites now routed through it
(`Body.place`'s `pivot`, `Body.setTeam`, `Body.tie`, and `Match.watchCharacter` in
`src/server/Match/init.luau`). One window per userId, replaced by the next character, closed by
`Body.forget`; every handler re-checks `player.Character == character`; one extra paint at the close
because the engine can MODIFY an existing `BodyColors` and fire no `ChildAdded`. The leak check is
written as a BOUND (`appearanceWatching() <= #Players`) rather than as 0, because the running server
legitimately holds one per player it dressed in the last five seconds and a spec demanding 0 would
be asserting on the clock.

**7. The gate's first run caught a real bug in that window, and the fix is the commit after the
code.**
Verify: `435b2da` → `36fb2b1`. `paint` used `FindFirstChildOfClass`, so a character already carrying
ours and then handed a second `BodyColors` by the appearance load would never have the new one
painted — `FindFirstChildOfClass` answers whichever comes first in child order, and the engine
honours whichever it honours. It paints **every** `BodyColors` now, which is the only form of the
write that does not depend on an order nothing here controls; it still creates one when there is
none, so dressing twice leaves one instance. The spec case asserts both at once. This is reported
rather than quietly squashed: the spec found it, not a playtest.

**8. Measured live on the running server and on the client, at the code commit.**
Verify: the harness notes in the run at `36fb2b1` —
`task151 live: 1 of 1 teamed character(s) green, 1 kept their own head colour, 1 with no shirt/pants`,
`task151: appearanceWatching=0 (players 1) strayCleared=0 repaints=21`, and from the client
`outfit[client]: 1 teamed, 1 green, 1 own head colour (0.243137, 0.207843, 0.164706), 1 with no
shirt/pants` and `outfit[client]: 1 role(s) counted (Alhamdulilah824=Shooters:2)`.
**`strayCleared=0` is reported as what it is:** in this place the engine's appearance load did not
fight us even once, so the window has so far caught nothing — which is the number that decides
whether its five seconds can later be shortened or dropped, and it is not evidence that the window
is wrong.

**9. Looked at, and described wrong-first (rule 5).**
Verify: `<runs-dir>/151-outfit-preview.png`. Four figures in front of the live first-person camera —
hunter front, hunter back, beater front, beater back — each a clone of the character the server had
just dressed, with the live first-person sleeve in the bottom-left of the same frame. Measured off
the frame: lit clothing (106, 107, 65) and (111, 110, 66) against the lit sleeve (100, 106, 67) and
(122, 126, 79) — within 6 on every channel on the comparable faces; the orange reads (255, 153, 0),
which is `OUTFIT_COLOR` rendered. Hair is kept and the hat sits above it; the head is not green.
**What is wrong with the frame, said first:** two of the clones have an arm stuck out horizontally
holding a shotgun — the Tool's grip pose frozen when the Humanoid was removed from the copy, an
artefact of how the picture was taken and not of the outfit; and the hat still reads as a wide
boater rather than a hunting cap, which is Task 77's accepted shape, unchanged here, and Karen's to
judge against the green.
**How the picture was taken, because it is not the obvious way:** the client owns the camera
(`Camera.Rig`), so a `screen_capture` camera argument cannot orbit a Play session — the first
attempt produced a plain first-person frame with nothing in it. The clones are parked in front of
the real camera instead. Setting the live player's team to `Drivers` and calling `LoadCharacter`
is what produced the beater, so **the dressing in that frame is the production path**
(`Match.watchCharacter` → `Body.dressWhenLoaded`); only the team write bypassed `Body.setTeam`, and
no tool can set a live player's team any other way.

**10. The Forest Test role switch is server-only and HALF-PROVEN, and the unproven half is named.**
Verify: `ForestTest.parseRole` / `roleOf` / `setRole` / `clearRole` in
`src/server/ForestTest/init.luau` (no Instance written, no `Match` required — it answers in Karen's
words), `Body.ROLE_WORDS` / `Body.teamForWord` in `Body.luau` as the one translator, and the wiring
in `src/server/ForestTestBoot.server.luau` (`Body.ensureTeams`, `applyRole` on `CharacterAdded`,
`player.Chatted`, and `ForestTest.clearRole` + `Body.forget` on `PlayerRemoving` — `Match.forget`
never runs in that world). Specs: *"reads the two commands, however they are typed"*, *"starts him
as a hunter…"*, *"translates Karen's word through Match.Body"* in
`tests/server/forest_stand.spec.luau`.
**PROVEN:** `Player.Chatted` fires under `TextChatService` — this place reports
`ChatVersion = Enum.ChatVersion.TextChatService`, and a client `RBXGeneral:SendAsync("/beater")` in a
DEV Play session made the server hear `/beater` **verbatim**. The design's `TextChatCommand` fallback
is therefore not needed and is not built.
**NOT PROVEN, and I am not claiming it:** this wiring has never run, because the "Driven Hunt Forest
Test" place is **not Rojo-Connected** — every script there reads `#Source == 0`. That is a
`NEEDS KAREN` with the exact clicks in `ESCALATE.md`.

## What I could not verify

* **The Forest Test wiring end to end** — claim 10. The place holds no code until Karen presses
  Connect. The trigger mechanism and the pure half are proven separately; the boot's own lines are not.
* **`test2`** — a human click, queued in `ESCALATE.md`. Required for the merge, not for this round.
* **A beater that the DRIVE assigned.** No tool can set a live player's team mid-session, so the
  beater in the frame was made by writing `Player.Team` and respawning. The *dressing* is the
  production path; the team write is not.
* **Whether RGB(86, 80, 56) is right.** It matches the sleeve to within 6 per channel in the frame,
  which is the question I can answer. Whether it looks right is Karen's, and it is one line.
* **`camera_client.spec:598` failed once** ("zooms to the eye and back", the aim-blend timing) on an
  intermediate run and passed on the runs either side of it, including the clean-tree PASS above.
  I did not chase it: nothing in this change touches the camera, the FOV or the blend. Reported
  because a flake nobody writes down is a flake nobody fixes.
