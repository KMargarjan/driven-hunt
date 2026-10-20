# Task 224: the lever-action rifle, bought in the shop

Task: 224
Round: 3
Base: `747d628` (main, the task-223 merge)
Code commit: `77899a220c6ea8a7703258df3edd0169065d6070`

```
[harness] PASS: 33/33 checks @ 77899a220c6ea8a7703258df3edd0169065d6070 (clean tree) scope=all
```

`test2` **N/A, checked at this round's head**: no file in this diff is in `TWO_PLAYER_PATHS` — the
match, the drive, the tie and the teams are untouched. `tools/agents.py` reports it when it gates
this request.

**Round 2 returned two blocking findings and both were right — both were my tests being toothless a
second time.** This round is those two and the refusal diagnosis, and nothing else. Claims from
rounds 1 and 2 that the Reviewer has already accepted are not restated.


## Addendum after the round-3 PASS: `poses.json` re-saved in the tool's own format

CI's **Pose tool selftest** was red. `tools/pose.py`'s `write_poses` is
`json.dumps(data, indent=2, sort_keys=True)`, and `pose.py selftest` asserts the shipped file is
already in that format — so that an edit saved through the tool shows only what moved instead of a
773-line reformat burying one number. I had hand-written it at `indent=1`.

**Rewritten through `write_poses` itself, not by hand, and no value changed:** both trees walked
together, **430 leaf values compared, 0 differences**. The diff is indentation, 773 insertions and
773 deletions. `pose.py selftest`, `studio_mcp.py selftest` and `agents.py selftest` all PASS, as do
StyLua, selene, `rojo build` and `privacy_scan`.

**Why this needs no fourth review round, said explicitly rather than assumed** ([L-036]/[L-039] ask
for it): the commit touches **one file and it is `src/shared/Viewmodel/poses.json`**, which
`tools/agents.py` itself classifies — *"content lane: 1 data file(s) ... need no review round
(CLAUDE.md 'Content lane')"* — and which CLAUDE.md's content lane exempts from the Builder and
Reviewer rounds while still requiring the one-player `test`, which is the PASS above. No Luau, no
tool and no spec changed between `c08355f8` (the round-3 PASS) and this commit. A `Round: 4` would
in any case be refused by `MAX_ROUNDS` without a recorded Director authorisation. **The merge
decision on this sha is the Director's, and this paragraph is the record of what changed.**

---

## Finding 1 — the glove case never read `poseHands`. Now it drives the instances.

Round 2's version was `expect(atCarry.x).to.equal(atCycle.x)` over two `poses.json` entries: forcing
`follows = true` — the defect itself — left it green, and its swing half duplicated the server case.

**The seam is the one this repo already uses, and my stated reason for avoiding it was wrong.**
`Viewmodel.weaponId` reads `DrivenHunt.Weapon` off the Handle's **Tool parent**, so a Handle in a
Tool saying `"lever"`, handed over through `Camera.Viewmodel.setSource`, makes `geometryNow()` answer
`Lever.Geometry` — no purchase, no grant, no drive. `withLeverDrawn` does that and puts the live
source, the hand templates and the reload state back whatever happens, the way `gun_client.spec`'s
`withNewGun` does.

*Verify:* `tests/client/lever_client.spec.luau`, "THE LOOP SWINGS DOWN AND FORWARD while the fore-end
glove stays put". It runs `Viewmodel.update` at `openTilt` 0 and 1 and measures the **instances in
the body's own frame** (`clone.CFrame:ToObjectSpace(...)`, which is `camera_client.spec`'s own
correction — working the action moves the whole gun, so world space would pass for the wrong
reason): the `Lever` part must go **down** and **forward**, and `HandLeft`'s place on the body must
move **< 0.01 stud**.

## Finding 2 — the shell case could not fail. Now it drives `Viewmodel.shells`.

Round 2 counted shell parts on a freshly built clone — 0 for every weapon, because `buildNewGun`
draws no shells at all.

*Verify:* same file, "draws NO loose shell when the action is open with a spent case in it". It
drives `Viewmodel.shells` on the lever clone with `setReload({ open = true, spent = 1, ... })` — the
state that makes the drawing happen — and asserts `stats().shellsDrawn` does not move and no
`SpentShell*` / `FreshShell*` child appears.

## Both were shown FAILING with the defects forced, in the running game

I edited `Viewmodel.luau` to force `follows = true` and to delete the `handFeedsShells` guard, ran
the full gate, and the harness said:

```
note   task224 throw on the body: lever down 0.3023, forward 0.0983; fore-end glove moved 0.7147 studs
note   task224 lever shells: shellsDrawn 32 -> 33, 1 shell part(s) on the clone
failed [client] lever_client.spec: Expected value "true" (boolean), got "false" (boolean) instead
failed [client] lever_client.spec: Expected value "32" (number), got "33" (number) instead
[harness] FAIL: 31/33 checks @ ... (DIRTY TREE (1 paths) - NOT valid evidence) scope=all
```

**0.7147 studs of glove travel against a 0.01 bound, and a 12-gauge hull really was drawn on the
.45-70.** The file was then restored byte for byte (`git status` clean) and the gate is the PASS
above. The request says which edit reproduces each, so the Reviewer can repeat it.

**Two more things this round:** `hiddenByScope` is driven **both ways** — false for this gun's nil
optics even fully aimed, **true** for the Rigby's optics at the same state — so the lever's answer is
a fact about the weapon and not about the function. And `Viewmodel.buildNewGun`'s export from round 2
is **reverted**: nothing uses it now, and an export added for a test that no longer needs it is dead
weight. **`src/` therefore gains nothing at all this round** — the whole diff is the spec, the scope
entries having already landed.

---

## Why the shot was refused — measured, and it is my workaround, not the gun

Instance facts, live, with the lever in the character (`driven-hunt-runs/t224-why-refused.luau`):

```
held=Lever | handle=true muzzle=true | weaponAttr=lever | team=Shooters
posts tagged=7 | nearest post ShooterPost1 at 4.6 studs | origin-root gap=1.53
```

Every guard in `onFireRequest` that these can answer is **satisfied**: the Tool is held, the `Muzzle`
attachment exists (so not `no-muzzle`), the player is a Shooter 4.6 studs from his post (so not
`outsideStand`), and the origin is 1.53 studs from the root (inside `Validator.checkShot`'s
tolerance). What is left is the first guard in the function:

```luau
local state = stateOf(player, id)
if not state then
    return "untracked"
end
```

**`"untracked"`, and the cause is the route, not the weapon.** The lever in that character was put
there by `Weapon.refreshArming` called from an **MCP-side module instance** — a separate copy of
`Weapon` with its own state table (this is the measured StudioMCP property: a live probe gets a fresh
module, so only INSTANCE facts are trustworthy). The Tool is real; the **live** server never armed
it, so the live `Weapon` holds no state for `"lever"` and refuses every shot for it.

**A legitimate shot therefore needs the live server to grant the gun, which needs ownership, which
needs the shop counter — and the DEV place has none**: `MatchBoot.server.luau` passes
`counterAt = nil`, so `Shop.atCounter` is false and every purchase in DEV is refused `too-far`
(measured over the real wire in round 1: `refused=too-far balance=13000 hunts=30 LEVER owned=false
buyable=true price=650`). **It is only doable in the Forest Test place.** I did not do it: that place
is Karen's and this session has no route that reaches "owned + equipped + on stand" there.

## What I could not verify

**(a) Frames: one, and it does NOT show the fix.** `.screenshots/t224r3-carry-solved.png` (first
person, player eye height, DEV drive) is the carry frame with the solved poses, beside round 2's
`t224r2-carry.png`. Said plainly: **the two look the same.** The hand corrections were 0.06–0.12
studs — sub-pixel at this framing — and `carry.gun` did not change at all. **The fix is the
measurement, not the picture**: `0.0602 off the wrist axis (bound 0.0468)` became `0.0000`, three
states, printed by the harness. What the frame does show is the gun drawn right (stainless receiver,
rail, tube, fore-end, loop), the Hud reading **five pips / `.45-70` / 10**, the left glove on the
fore-end, and the gun held low and across the screen with the right hand below the bottom edge.

**(b) No aim, mid-throw or gate-feed frame.** Each needs either real input or the live camera
module, and neither is reachable from an MCP script (the fresh-module property again). The throw is
held by the spec instead — the instances, down 0.3023 and forward 0.0983 on the body — which is what
design 15.4 offers as the alternative to those frames.

**(c) CI not checked from here:** `gh` is not authenticated in this session; the branch is pushed.

**(d) KAREN'S LOOK, and it is the one thing I would not merge without (L-008).** The carry pose and
the hand rotations are **content lane**. The numbers now put both grip points exactly on their
anchors, but *where the gun sits in the frame* is `weapons.lever.carry.gun` and is hers — and a hand
position has already recurred four times on the horn when shipped on our own look alone.

**(e) Karen's dials, untouched:** `GRAVITY_SCALE` 0.35, the 1.10 s throw and 2.90 s reload, the
recoil block, the three voices, the 650 / 12-hunt price.

**(f) Still queued as 224a**, and round 2's non-blocking notes with them: the drawn gate feed and its
three prerequisites; one gate click per run of `Load` steps; folding `cycleLength`/`cycleZ` into
`Gun` and `Rifle.Geometry`; `leverThrow`'s header table (which quotes 0.360/0.546 where the shipped
constants give 0.396/0.567); design 15.1 cases 15 and 17; the `lever-aim` scenario line.
