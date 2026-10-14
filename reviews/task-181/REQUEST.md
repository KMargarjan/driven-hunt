# Task 181: the shopkeeper, and `E` as the one way into the shop

Task: 181
Round: 2
Base: ea3d6db (main, #164 merged)
Code commit: 6041ac802dd73fbb9ec351c0708bf5186e97207b

Harness, on a clean tree, TWICE at the code commit:

```
[harness] PASS: 33/33 checks @ 6041ac802dd73fbb9ec351c0708bf5186e97207b (clean tree) scope=all
[harness] PASS: 33/33 checks @ 6041ac802dd73fbb9ec351c0708bf5186e97207b (clean tree) scope=all
```

`test2`: **N/A.** No path this task touches is in `TWO_PLAYER_PATHS` (`tools/agents.py`): the lobby,
the shop panel and the Hud are not the match, the drive, the tie or the teams.

Karen, 2026-10-14 ~09:30, verbatim: *"in lobby has to be a person bot who you need to click E to get
access to shop"*.

---

## What changed

A **shopkeeper** stands behind the lodge's shop counter, with a `ProximityPrompt` on him that is now
the **only** way into task 178's shop panel. Task 178's walk-up auto-open and its
`ContextActionService` `E` binding are **removed**.

| File | What |
|---|---|
| `src/shared/Lobby/init.luau` | `KEEPER_NAME`, `PROMPT_NAME`, `CONFIG.LODGE.KEEPER` (every number with its reason), and `Lobby.shopPrompt()` — the client's one reader, memoised like `counterPart` |
| `src/server/Lobby/Build.luau` | `Seams` (rig, dress, dressConfig, shopOn), `Build.defaultRigSource`, the `shopkeeper` builder, `Build.keeper` / `keeperPosition` / `faceKeeper`, two new `stats` |
| `src/server/Lobby/init.luau` | passes the seams (with this owner's own default rig source), turns his head on the scan it already runs, reports three new numbers |
| `src/server/ForestTestBoot.server.luau` | injects `dress = Body.dress`, `dressConfig`, `shopOn = ShopData.isOn()`; one console line saying whether a keeper is standing |
| `src/shared/Shop/init.luau` | `CONFIG.AUTO_OPEN` **deleted**, with the reason in its place |
| `src/client/Hud/ShopPanel.luau` | `setPrompt` / `onPromptTriggered` / `hasPrompt` / `setEnabled`; the `E` binding, `TOGGLE`, `TOGGLE_KEY`, `bind`, `unbind` and `ShopPanel.toggle` all **gone**; `setNear` now only ever closes |
| `src/client/Hud/init.luau` | one line: the prompt is resolved where `setNear`'s reach already is, and handed over |
| `tests/server/lobby.spec.luau` | a fake rig, and eight `it`s for the keeper |
| `tests/server/lobby_live.spec.luau` | the two seams in the owner's fakes, and two `it`s |
| `tests/client/shop_panel.spec.luau` | a synchronous fake prompt, and four `it`s |
| `docs/research/2026-10-14-the-shopkeeper.md`, `INDEX.md` | the note (rule 1) |
| `TASKS.md`, `PLAYTEST.md` | the row, and Karen's line transcribed |

**Round 1's three findings are all fixed, and all three were real** (`reviews/task-181/RESULT.md`,
committed):

1. **The keeper was never dressed.** `KEEPER.TEAM` was `"Hunter"`, which matches no row in
   `Match.Body.OUTFITS` (`Shooters` / `Drivers`), so `Body.dress` returned early at *"nothing to
   wear"* and he stood at the counter in the default grey of an empty `HumanoidDescription`. It is
   `"Shooters"` now — the outfit owner's own word, the one `Body.ROLE_WORDS.hunter` translates to
   and the one `Bots` already passes. **The picture is the proof**: he is in green with a brown hat
   in `.screenshots/20261014-task181-shopkeeper-press-e.png`, which is the same frame the prompt is
   in, taken after the fix.
2. **`keeperDressed` meant "the call did not throw"** — it kept `pcall`'s flag and dropped
   `Body.dress`'s own answer, which is why the console said `dressed=true` over the undressed man.
   Both are read now.
3. **The lobby could be built twice.** This task put the first yielding call into `tryBuild`, which
   runs off a 10 Hz `Heartbeat` and sets `folder` only after `Build.build` returns. A `building`
   latch now spans the one call that can yield, cleared through a `pcall` so a build that throws is
   retried rather than locked out for ever.

**No design file was touched**: `docs/design/` is the Architect's. §5.4, §5.5 and §15.5 of
`docs/design/shop.md` and §14.3 of `docs/design/lobby.md` are now out of date on exactly this point,
and the research note records the reversal with its reason. Flagged for the Director.

---

## Claims, and how to verify each

1. **There is a man behind the counter, and he is the lodge builder's.** `Lobby.Build.shopkeeper`
   parents a Model named `Lobby.KEEPER_NAME` under `Lodge.Inside.Shop`, `BEHIND_STUDS` further from
   the room than the counter and on the same floor. `tests/server/lobby.spec.luau`, *"stands one man
   behind the till, and counts him"*. LIVE, in the Forest Test:
   `[lobby] shopkeeper: standing, dressed=true, prompt=true`.

2. **He cannot be pushed, walked into, shot or hit.** Root anchored, limbs not (so the idle clip can
   move them, which is `Bots.Rig.place(.., anchored = true)`'s own arrangement); every part
   `CanCollide = false`, `CanQuery = false`, `CanTouch = false` — the rule this file already states
   twice. Spec: *"cannot be pushed, cannot be walked into, and cannot stop a pellet"*, which also
   asserts the fake rig arrives COLLIDING, so the builder is proved to do the work.

3. **The prompt carries Karen's key and Valve's two numbers.** `ActionText = "Shop"`,
   `ObjectText = "Press E"`, `KeyboardKeyCode = E`, `GamepadKeyCode = ButtonX`,
   `MaxActivationDistance = 8`, `HoldDuration = 0`, `RequiresLineOfSight = true`, on an Attachment
   `PROMPT_HEIGHT` above the root. Spec: *"carries the prompt, with Karen's key, 8 studs and line of
   sight"*. One property set is keyboard, gamepad AND touch — the docs line quoted in the note §2a.

4. **Pressing E opens the shop panel.** `ShopPanel.setPrompt` connects to `Triggered` and
   `onPromptTriggered` opens (never toggles). `tests/client/shop_panel.spec.luau`, *"opens the panel
   when the keeper's prompt fires, with the flag on"* — the flag driven on by parameter, which
   CLAUDE.md's feature-flag rule asks for. **A spec cannot fire a real `ProximityPrompt`**, so the
   fake is a synchronous signal through the same `setPrompt` line; the real keypress is the
   screenshot below.

5. **One prompt at a time, and the Hud's per-frame hand-over costs nothing.** `setPrompt` is
   edge-triggered on the instance: the same prompt again is not a second connection, a new one drops
   the old. Spec: *"connects to one prompt at a time, and a trigger reaches the panel"*
   (`first.live() == 0` after the swap).

6. **The counter no longer opens the panel by itself.** `Shop.CONFIG.AUTO_OPEN` is gone; grep
   `AUTO_OPEN` in `src/` finds only its tombstone comment (and `Report`'s unrelated
   `AUTO_OPEN_AT_DRIVE_END`). Spec: *"does not open itself at the counter any more"*, which asserts
   the field is `nil`.

7. **Walking away still closes it, at the distance the server refuses a purchase at.**
   `setNear(false)` closes; the distance is `Shop.CONFIG.REACH_STUDS` (14), unchanged, and the
   dispatch's "~12" was not used **because 14 is the number `ServerScriptService.Shop` measures a
   purchase against** — one fact, one place. Spec: *"closes when he walks away from the counter"*.

8. **No second owner of the `E` key.** `ShopPanel` binds nothing through `ContextActionService` any
   more: grep `DrivenHunt.Shop.` in `src/` finds nothing, and `ContextActionService` is not required
   in that file. A `Sink`ing `E` within 14 studs would have swallowed the prompt's own `E`.

9. **One dressing path, with a word the outfit owner knows, and no new clock.** `Build` hands a Model + a team + task 178's `Look` to the
   injected `dress` (`Match.Body.dress` at the composition root, the `Bots.start` shape) and learns
   nothing about outfits — specs: *"is dressed by the outfit owner and by nothing else"*, *"hands
   over a team the outfit owner has an outfit for"* (which asks `Body.outfitFor` itself, so the
   round-1 defect cannot come back), and *"counts him as dressed only when the outfit owner says
   so"*. The idle
   clip is played once at build. The look-at rides `Lobby.step`'s existing scan and writes only when
   the yaw moved: specs *"turns to the nearest man, and writes nothing when he has not moved"* and
   *"turns his head on the scan it already runs, and only when the man has moved"*
   (`keeperTurns == 1` after three scans with a man standing still).

10. **The lobby is built once, whatever the rig call does.** A `building` latch in `Lobby.tryBuild`
    spans the yielding call; `tests/server/lobby_live.spec.luau`, *"never builds the lobby twice,
    even when the rig call re-enters the scan"*, drives the re-entrancy the only way a spec can —
    the fake rig calls `Lobby.step` from inside the build — and asserts one folder, one build
    attempt and one keeper.

11. **Nothing else can break.** No rig source → no keeper and the lodge still builds (*"builds the
    lodge anyway when no body comes back"*), which is what keeps the avatar service out of this
    harness; with `SHOP` off the prompt is built **dead** (*"hangs a DEAD prompt on him when the shop
    is not in this build"*) and the dark path still opens nothing (*"opens nothing at the counter
    while the flag is off"*); no script anywhere in his body; and `Lobby.shopPrompt()` finds him and
    drops its cache with the instance.

---

## What I could not verify

* **The keypress itself.** `ProximityPrompt.Triggered` cannot be raised from a script and the
  harness cannot synthesise the prompt's own input, so no spec presses `E`. What is proved live is
  the picture: `.screenshots/20261014-task181-shopkeeper-press-e.png`, taken in the Forest Test with
  the player 6.5 studs from the keeper — the prompt reads **"Press E / Shop"** over his head.
  **StudioMCP's `capture` does not include CoreGui**, which is where the prompt's UI lives, so that
  file is a desktop grab of the Studio window rather than a `capture` (measured: three `capture`
  images of the same frame have no prompt in them; the desktop grab of the same moment does).
* **The idle animation actually moving him.** The track loads (`Rig.loadClips`' own caveat: a track
  that loads is evidence the CALL succeeded, not that the body is moving). A still picture cannot
  show motion either way.
* **How he LOOKS.** Dressed, he is hunter green with a wide brown hat, and his face still reads
  dark: the lodge's only light is the fireplace at the far end. That is Karen's call, not mine — a
  light over the counter would be a second `PointLight` in a tree whose spec asserts exactly one, so
  it is queued rather than done.

## Harness and console

* `python tools/studio_mcp.py test` → **PASS 33/33, twice**, both at `bce2cf5`, clean tree,
  `scope=all` (pasted above).
* Smoke in the Forest Test (`driven-hunt-runs/smoke.sh`, 80 s), re-run **after** the round-2 fixes:
  `lobby=[lobby gunBefore=false] gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 | waves=6` →
  **SMOKE PASS**, with `[lobby] shopkeeper: standing, dressed=true, prompt=true` in the console.
  (A later 8-minute unattended session logged repeated `Boar runtime is at maxBoars` warnings: the
  known boar-cap item, nothing to do with this task, and absent from the 80 s smoke run.)
