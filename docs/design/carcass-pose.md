# Design: `carcass-pose` — the client-side owner of a dead animal's drawn pose

Task 358. Written to `reviews/task-358/BRIEF.md` (the Builder carrying the Director's dispatch of
2026-11-13), which overrides anything older in `docs/`, `TASKS.md` or an earlier design. There is no
earlier `docs/design/carcass-pose.md`; this is the first.

Karen, 2026-11-10: *"animal died and then stand and then again die"*.

---

## 0. What the measurements already settled, and what is therefore being built

The brief's readings are the premise of this design, not a hypothesis in it:

| reading | result | file |
|---|---|---|
| 480 s drive, 19 kills, 4 kinds | **0 pops / 19 kills** | `358-BEFORE-cli.txt` |
| the server's 6 s re-assert forced 80 times | **0 client pops / 80 repairs** | `358-BEFORE-staged-cli.txt` |
| a client track stopped, bones left alone | the pose **stays** (1.05 → 1.05 after 12 s, 0 tracks) | `358-clipop.luau` |
| no track **and** the bones at bind | hind 1.05 → **4.94**, hind 1.04 → **4.93**, cub 1.01 → 1.35; **recovered never in 12 s, 3 of 3** | `358-bind.luau` |
| a client-loaded track on a server-owned Animator | `ok=true`, `playing=2`, it takes its weight, span 0.72 → 1.16, `Stop` → 0.72 | `358-feas.luau` |

So: **the dispatch's stated cause (the 6 s re-assert) is refuted.** What stands an animal back up is a
client whose rig has **no pose at all** — bind pose, which for every animal in this game is standing
— and that client never recovers, because the server's re-assert is one-shot
(`handle.reasserted` in `Boar.Body.create`, fired by `Body.shouldReassert` at
`CONFIG.WOUND.CARCASS_REASSERT_SECONDS` = 6.0) and `Body.shouldRehold` only fires when the
**server's own** track is broken. A carcass that reaches a client after the 6 s mark stands for the
rest of its `CARCASS_SECONDS` = 120.

The fix is therefore not more server repair. It is a client that can see *"this rig is drawing
nothing"* and put the pose on itself. That is a new owner, and this document is its boundary.

---

## 1. What the system must do, and what it must not do

### Must do

1. On **this client**, for an animal the **server has already called dead** (`Carcass == true` on the
   trunk, written by `Boar.Body.collapse`), make sure the rig is drawing the death pose the server
   says it should be holding.
2. Decide that from **instance state alone** — no remote, no guess, no clock shared with the server.
3. Act **once** per carcass, with a bounded, named per-frame cost, on every client, for every
   carcass, at up to `MAX_BOARS` = 60 trunks in the folder (`src/shared/ForestTest/init.luau`,
   `Data.MAX_BOARS`; `Boar.CONFIG.maxBoars` is 8 in the DEV place).
4. Ship behind one feature flag **born OFF**, with **OFF byte-for-byte today's world**, and both
   states reachable **by parameter** as well as by flag.
5. Undo itself: `stop()` leaves no track it created playing and no record held.

### Must not do

1. **Must not write anything the server owns.** Not the trunk's `CFrame`, `Anchored`,
   `AssemblyLinearVelocity`, `AssemblyAngularVelocity`, `CollisionGroup`, `CanCollide`, `CanQuery`,
   `Massless`, `Transparency`, `Color`, nor **any attribute on any instance**, nor any constraint
   (`Mover`, `Upright`, `ZoneWeld`, `VisualWeld`), nor any part of the `Visual` model's geometry.
2. **Must not touch a track it did not itself load.** It never calls `Stop`, `AdjustSpeed` or
   `TimePosition` on a track from `Animator:GetPlayingAnimationTracks()`; it reads those tracks and
   nothing more. The server's track (`Boar.Body`'s `trackFor` / `play`) stays the server's.
3. **Must not decide anything about death.** Not when an animal dies, where it lies, when it is
   removed, the collapse, the roll (`Body.topple`), the anchor, the lift (`Body.liftDrawn`), the
   backstop (`Body.shouldBackstopDeath`), the score, the drag/claim, the hit boxes.
4. **Must not pose a living animal** (`Carcass ~= true`), **must not pose a toppled one** (section 5
   makes that impossible by construction, and section 11 asserts it), and must not touch any
   instance outside the folder it was given — in particular no player's `Character` and no
   `Workspace.RangeTargets` part.
5. **Must not create any instance under `Workspace`.** Its `Animation` instances live in its own
   client-local folder.
6. **Must not fire a remote, read a remote, or write a Studio attribute.** It reads its flag once, at
   its boundary, through its boot script.

---

## 2. The owner

> **`PlayerScripts.CarcassPose` is the one writer of client-local `AnimationTrack`s on a dead
> animal's rig.** It writes nothing else, anywhere.

| | |
|---|---|
| Module | `PlayerScripts.CarcassPose` |
| On disk | `src/client/CarcassPose/init.luau` |
| Boot | `src/client/CarcassPoseBoot.client.luau` (boot line only, the shape of `src/client/AmbienceBoot.client.luau` and `src/client/RangeBoot.client.luau`) |
| Shared data it reads | `ReplicatedStorage.Carcass` (`src/shared/Carcass/init.luau`) — the attribute name and the pure format/parse pair. **No run-time writer**, the shape of `src/shared/Licences/init.luau` |
| Flag | `CARCASS_POSE`, born `false`, read **once** in `CarcassPoseBoot` and passed inward as `start({ enabled = … })` |

**It is the first client-side animation owner in this repository.** A grep of `src/` for
`LoadAnimation`, `Animator` and `GetPlayingAnimationTracks` finds eight files and **not one of them
is under `src/client/`**: `src/shared/Horn/init.luau`, `src/server/Weapon/Horn.luau`,
`src/server/Bots/init.luau`, `src/server/Bots/Rig.luau`, `src/server/Boar/init.luau`,
`src/server/Boar/Body.luau`, `src/server/Lobby/Build.luau`, `src/serverstorage/Assets/init.luau`.
So this is a **first writer, not a second one** — the same sentence `Horn`'s own header makes about
a player character's `Animator`.

### Owner boundaries against the two client systems that already write on drawn things

- `PlayerScripts.Camera.Viewmodel` (`src/client/Camera/Viewmodel.luau`) poses **its own clone** of
  the gun by `CFrame`, from `src/shared/Viewmodel/poses.json`. Disjoint: different instances,
  different property, no `Animator`.
- `PlayerScripts.Range.Mask` (`src/client/Range/Mask.luau`) writes `LocalTransparencyModifier` on
  parts under `Workspace.RangeTargets`; `PlayerScripts.Range.Solo` writes it on other players'
  characters; `Camera.Rig` writes it on the local character. Disjoint: this owner writes **no
  BasePart property at all**.

### The `GAME_DESIGN.md` owners row (mirror of this design, rule 3)

> | **A dead animal's DRAWN pose, per client** (what THIS client draws on an animal the server has already called dead) — **TASK 358, behind the flag `CARCASS_POSE` (born OFF)** | `PlayerScripts.CarcassPose`, started and stepped by `PlayerScripts.CarcassPoseBoot`, is the ONE writer of client-local `AnimationTrack`s on a trunk whose `Carcass` attribute is true. It writes no BasePart property, no attribute and no instance under `Workspace`, and it never touches a track it did not load: the server's death track, the collapse, the roll, the lift, the anchor and the removal all stay `ServerScriptService.Boar`'s (`Boar.Body`). WHAT IT IS TOLD, and it guesses nothing: `Boar.Body.stepVisual` publishes the pose the server is holding as the ONE string attribute `DeathPose` (`"<animationId>:<seconds>"`) at the moment it freezes the death — so the attribute's existence is proof the clip RAN, which is proof `Body.shouldBackstopDeath` can never fire on that carcass and the box can never roll under a client's pose (task 150's buried-upside-down carcass). `ReplicatedStorage.Carcass` is the frozen format with no run-time writer. OFF: nothing is published, nothing is loaded, nothing is stepped | `src/client/CarcassPose/`, `src/client/CarcassPoseBoot.client.luau`, `src/shared/Carcass/`, published by `src/server/Boar/Body.luau` | [design](docs/design/carcass-pose.md) |

---

## 3. The boundary: exactly which instances it may touch

The drawn animal is built by `Boar.Body.create` and `Boar.Body.attachVisual`:

```
Workspace.Boars.<id>            -- BasePart, the trunk. Attributes: Damageable, Wound, HitZone /
  │                                ZonesOnly, Kind, Species, Carcass, Reholds  [SERVER'S]
  ├── Drive (Attachment), Mover (LinearVelocity), Upright (AlignOrientation)   [SERVER'S]
  ├── ZoneHead / ZoneChest / … (+ ZoneWeld)                                    [SERVER'S]
  └── Visual (Model, ModelStreamingMode = Atomic, name = Boar.CONFIG.MODEL.NAME)
        ├── <MeshPart> ──> Bone × ~40                                          [SERVER'S]
        └── BoarAnimation (AnimationController)
              └── Animator   <── the ONE instance this owner calls into        [SHARED HANDLE]
```

**May touch:**

| Instance | What it may do | Why it is not a second writer |
|---|---|---|
| the `Animator` under `<trunk>.Visual` | `LoadAnimation` only | `LoadAnimation` creates a NEW track; it mutates nothing the server holds. Measured (`358-feas`): `ok=true`, the server's track keeps playing beside it (`playing=2`) |
| the `AnimationTrack` **it loaded** | `Priority`, `Looped`, `Play`, `TimePosition`, `AdjustSpeed`, `Stop` | It is this client's own object, created by this module, referenced only by this module |
| `PlayerScripts.CarcassPose.Clips` (a `Folder` it creates) | its own `Animation` children, one per distinct clip id, cached | Client-local, outside `Workspace`, created and destroyed by this owner alone |

**May read (and only read):** `Workspace.Boars:GetChildren()`, each trunk's `Carcass` and `DeathPose`
attributes, `FindFirstChildWhichIsA("Animator", true)` under its `Visual`,
`Animator:GetPlayingAnimationTracks()` and each returned track's `Animation.AnimationId`,
`IsPlaying` and `TimePosition`, and each `Bone.Transform` (for the recorded observation only,
section 9).

**May never touch:** everything else in the tree above, every player `Character`, every instance
under `Workspace.RangeTargets`, and every track it did not load.

**Why the `Animator` is found by class and not by name:** the controller's name
(`"BoarAnimation"`) and the model's name (`Boar.CONFIG.MODEL.NAME`) are the server's strings. The
model name is already shared through nothing — so this owner descends from the trunk with
`FindFirstChildWhichIsA("Animator", true)` and copies **no** server string. One `Animator` per rig is
not assumed: `Body.attachVisual` **asserts** exactly one controller and one animator per rig
(`controllers == 1 and animators == 1`), which is the fact this relies on, and it is enforced where
it is created.

---

## 4. The rule: when the owner acts

### 4.1 The decision, as one pure function

The project's own idiom (`Body.shouldRehold`, `Body.shouldBackstopDeath`, `AssetFetch.nextAsk`,
`Claim.simulate`'s reason strings): the whole decision is pure, it takes plain values, and it returns
a **named reason** so a spec can drive every branch with no rig, no asset and no Play session.

```luau
export type PoseView = {
    carcass: boolean,       -- the trunk's `Carcass` attribute == true
    poseId: number?,        -- from `Carcass.parse(trunk:GetAttribute(Carcass.ATTRIBUTE))`
    poseAt: number?,        -- ditto, seconds
    hasAnimator: boolean,   -- an Animator was found under the trunk
    deathPlaying: boolean,  -- a track whose Animation.AnimationId names `poseId` IS playing
    assetReady: boolean,    -- AssetFetch says this client has the clip
    trackLength: number?,   -- the loaded track's Length, nil before it is loaded
    posed: boolean,         -- this owner has already posed THIS carcass at THIS poseId/poseAt
}

-- "skip" | "wait-rig" | "wait-asset" | "wait-length" | "leave" | "pose"
function CarcassPose.decide(view: PoseView): string
```

In order:

| order | test | answer | why |
|---|---|---|---|
| 1 | `not carcass` | `"skip"` | a living animal is the server's to draw, always |
| 2 | `poseId == nil or poseId <= 0 or poseAt == nil or poseAt < 0` | `"skip"` | nothing was published: either the box laid this animal down (`Body.boxFalls`), or `BOAR_MODEL` is off and there is no rig, or the server has not frozen the pose yet. Not knowing is not a licence to invent |
| 3 | `posed` | `"skip"` | **once per carcass per published pose.** No storm, no per-frame write |
| 4 | `not hasAnimator` | `"wait-rig"` | the `Visual` is `Atomic`-streamed; it arrives whole or not at all, and it may arrive after the trunk |
| 5 | `deathPlaying` | `"leave"` | some death is already drawing this animal. Measured benign in 19/19 kills and 80/80 forced repairs; and snapping a fall that is still running to its end frame would be a visible defect this owner would have caused |
| 6 | `not assetReady` | `"wait-asset"` | **ask, then wait.** `ReplicatedStorage.AssetFetch` is the one owner of "has this client downloaded that id" |
| 7 | `trackLength == nil` | `"pose"` | nothing loaded yet: load it (the step then re-asks) |
| 8 | `trackLength <= 0` | `"wait-length"` | **the frame-0 trap.** `Animator:LoadAnimation` hands back a track for an asset that has not downloaded, and its `Length` is 0 (`Body.deathDrawn`'s own header, and `Body.shouldRehold`'s *"A ZERO LENGTH MEANS 'NOT LOADED YET', never 'already over'"*). Pinning `TimePosition` on a 0-length track clamps to **frame 0 of the fall, which is the animal standing** — the defect, caused by the fix |
| 9 | otherwise | `"pose"` | |

**Why the bone-at-bind test is NOT in the decision.** It was the obvious reading of the measurement
(`358-bind`: no track **and** bones at bind) and it is the wrong gate, for two reasons:

- It would **miss a worse variant**: a client that streamed the animal in alive, has its **idle**
  track still playing, and missed the death. One playing track, bones nowhere near bind, standing
  animal. Test 5 catches that (the playing track is not the death id); a bind test does not.
- It is **not needed** against the other side: re-posing a carcass that is already correctly posed is
  measured harmless — it is exactly what `Body.stepVisual`'s own re-assert does (*"re-playing a held
  track at that moment and pinning it back to the same frame is, on a client that already has it,
  the frame it was already showing"*), and it read **0 pops in 80 forced repairs**.

The bone reading is kept as a **recorded observation**, not a gate: section 9.

### 4.2 What it does then — the pose, and nothing else

For a carcass at `"pose"`:

```luau
local animation = clipFor(poseId)              -- cached in PlayerScripts.CarcassPose.Clips
local track = animator:LoadAnimation(animation)
track.Priority = Enum.AnimationPriority.Action -- beats the server's Movement (Body.trackFor)
track.Looped = false                           -- a looping death stands the carcass up every 1.2 s
-- re-asked on the NEXT sweep; nothing is played until Length is real (test 8 above)
track:Play(0, 1, 0)                            -- weight 1, rate 0
track.TimePosition = math.clamp(poseAt, 0, track.Length - Carcass.HOLD_EPSILON)
track:AdjustSpeed(0)
```

Four writes, once, on an object this client made. Then the record is marked `posed` and the carcass
is never read again except for the `GetChildren` sweep that notices it is gone.

**`Priority`, not weight.** `358-feas` proved a local track takes the weight it is given
(`localW=10.00`); that is an invention and the documented mechanism is priority
(`Enum.AnimationPriority`: a higher-priority track overrides a lower one). The server's tracks are
`Enum.AnimationPriority.Movement` (`Body.trackFor` sets it explicitly), so `Action` wins
deterministically at weight 1. Even at equal priority the result is the same pose — both sides are
the same clip at the same frame — so this is belt and braces over an already-safe state, which is
the repository's house style for a pose.

**`Stop` does not undo a pose, and the design does not pretend it does.** Measured (`358-clipop`):
stopping a client track leaves the bones at their last `Transform` and the pose stays. So
`CarcassPose.stop()` stops its tracks to release them and **states** that the drawn pose it put on
survives until the server destroys the carcass. There is nothing to restore to: the alternative
restore target is bind pose, which is the standing animal this system exists to remove.

---

## 5. Where the frame comes from — and why the attribute is also the permission

A client that never received the death has **no `TimePosition` and no animation id**, and it cannot
get the id: `Boar.CONFIG.MODEL.ANIMATION_IDS` is filled per runtime by `Boar.setModelSource` from
`src/server/BoarAssetsBoot.server.luau`, out of `ServerStorage.Assets` (`Assets.KEYS.boarDeathLeft`
and friends). **ServerStorage does not replicate.** There is no shared id table, by design
(`Boar.CONFIG.MODEL`'s own header: *"ids have one home … and a mapping between two owners belongs in
the composition root"*).

### 5.1 The decision: yes, the server publishes it on the carcass part, as ONE attribute

The precedent is `Reholds` (task 293c, `Body.stepVisual`): *"`reholds` lives in the handle, which a
live probe cannot read … The trunk part is the instance a probe already finds (it is the one carrying
`Carcass`), and this is read-compare-write."* `Wound` (task 331, `Body.setWound`), `Kind`, `Species`
(`Licences.SPECIES_ATTRIBUTE`) and `Damageable` are the same idiom: **boar-owned data the boar
publishes about itself**, and the reader only reads.

```
attribute:  DeathPose    (string)
value:      "<animationId>:<seconds>"       e.g. "128792697872198:5.178"
writer:     Boar.Body.stepVisual — the ONE writer, the same function and the same
            read-compare-write shape as `Reholds`
readers:    PlayerScripts.CarcassPose; any probe; the Explorer
format:     ReplicatedStorage.Carcass (src/shared/Carcass/init.luau) — Carcass.format / Carcass.parse
```

**One string and not two numbers, and that is not tidiness.** Two attributes are a **torn pair**: the
pose changes once in a boar's life, when the paddle supersedes the fall, and both numbers change
together. A client reading between the two writes would pin the 4.0 s paddle track at the fall's
1.178 s — the legs 29 % through a paddle, which is a visibly wrong pose this owner would have caused.
`Flags.publish` solves the same problem by writing `Digest` last (`Flags.DIGEST_ATTRIBUTE`); one
attribute removes the class instead of ordering around it. The cost is a four-line pure parser, in
one shared home so the format cannot drift between the writer and the reader.

### 5.2 Where it is written, and why that single choice removes the worst defect

**It is written where the server freezes the death**, i.e. in `Body.stepVisual` where `handle.heldAt`
and `handle.heldClip` are set (the freeze branch that calls `Body.shouldFreeze` / `Body.holdFrame`,
and the `Body.shouldRehold` repair beside it), gated on `handle.heldClip` being one of
`Body.deathClips(config)` and `handle.toppled` being false:

```luau
-- read-compare-write, exactly as `Reholds` above it
if config.MODEL.PUBLISH_DEATH_POSE and handle.collapsed and not handle.toppled
   and heldIsADeathClip and handle.heldAt ~= nil then
    local id = config.MODEL.ANIMATION_IDS[handle.heldClip]
    if type(id) == "number" and id > 0 then
        local value = CarcassData.format(id, handle.heldAt)
        if handle.part:GetAttribute(CarcassData.ATTRIBUTE) ~= value then
            handle.part:SetAttribute(CarcassData.ATTRIBUTE, value)
        end
    end
end
```

**The attribute's existence is proof the clip ran.** The freeze only happens to a track that reached
the end of its own clip, so `Body.deathDrawn` is true, so `Body.collapse`'s armed `handle.deathTrack`
has been cleared and `Body.shouldBackstopDeath` returns `false` for the rest of that carcass's life.
Therefore:

> **A carcass carrying `DeathPose` can never be toppled afterwards.** The box cannot roll under a
> client's clip, and task 150's buried-upside-down carcass (head 1.20 studs below the ground, hooves
> 0.85 above it — two correct rotations composing) **cannot be reproduced by this system.**

That is the one hazard this design had to kill, and it is killed by *where* one write goes, not by a
guard anybody has to remember. Section 11 asserts it rather than describing it.

The three other states fall out for free:

- `Body.boxFalls` true (no visual, or no death track for this rig) → `Body.collapse` topples and
  returns; `stepVisual` returns early on `handle.toppled`; **no attribute, ever.**
- `BOAR_MODEL` off → no visual → `stepVisual` returns before the freeze → **no attribute.** The
  grey-box world is untouched without a second switch.
- `ANIMATION_IDS` empty (clips not published) → no track → `boxFalls` → **no attribute.**

### 5.3 What this costs in time, stated as a number

The pose is published when the held clip ends, which is (from `Boar.CONFIG.MODEL.CLIPS` /
`SPECIES.reddeer.MODEL.CLIPS`, minus `MODEL.HOLD_EPSILON` = 0.03):

| animal | clips held | `DeathPose` appears, after collapse |
|---|---|---|
| red deer (stag, hind, calf) | `deathLeft/Right` 1.167 s; the package publishes no paddle | **≈ 1.14 s** |
| boar (male, female, cub, legendary) | `deathLeft/Right` 1.208 s then `deathPaddleLeft/Right` 4.0 s | **≈ 5.18 s** |

A client that meets a boar carcass **before** 5.18 s and has no pose therefore draws a standing
animal for the remainder of that window. Against today's measured **~110 s**, and against the fact
that such a client is the 1-in-10 case in the first place, that is the right trade; it is also the
only version of this with no composition race. It is written here as a number, and section 12 puts
the alternative in front of Karen rather than taking it quietly.

### 5.4 The routes refused

- **A remote per carcass** (`DeathPose` as a `RemoteEvent` payload): a remote per kill to every
  client, a second answer to "what pose is this carcass in", and it still has to be re-sent to a
  client that streams the animal in later — which is the whole failure. Refused.
- **`KeyframeSequenceProvider:RegisterKeyframeSequence` on the client**, the route `Horn.blowAnimationId`
  uses to make a content id with no upload: it would be a **second copy of the death pose**, authored
  in code, drifting from `Death_L`/`Death_Paddle_L`. Refused (rule 2 cuts both ways).
- **A shared id table in `ReplicatedStorage`**: a second home for asset ids, which
  `Boar.CONFIG.MODEL`'s header forbids in as many words. Refused.
- **The client measuring the frame itself** (scan the bones, find the lying pose): inventing a
  foundation, per-kind magic numbers, and a measurement believed over the screen. Refused.

---

## 6. Public interface

### 6.1 `ReplicatedStorage.Carcass` — `src/shared/Carcass/init.luau`

Pure shared DATA. Creates no instance, reads no service, holds no state, **has no run-time writer**
(the shape of `src/shared/Licences/init.luau`, which `Boar.Body` already requires for exactly this
reason).

```luau
Carcass.ATTRIBUTE: string            -- "DeathPose"
Carcass.HOLD_EPSILON: number         -- 0.03, the same margin Boar.CONFIG.MODEL.HOLD_EPSILON uses:
                                     -- a pin AT the end of a non-looped track is the state that
                                     -- stopped it (Body.holdFrame's own reason)
Carcass.format(id: number, at: number): string      -- "<id>:<at>", 4 decimals, "" for a bad input
Carcass.parse(value: unknown): (number?, number?)   -- (id, seconds), or (nil, nil)
```

`parse` answers `(nil, nil)` for a non-string, an empty string, a missing separator, a non-numeric
half, a non-finite number, `id <= 0` or `at < 0`. A reader that cannot parse does nothing.

### 6.2 `PlayerScripts.CarcassPose` — `src/client/CarcassPose/init.luau`

```luau
export type Seams = {
    enabled: boolean,                 -- the flag, resolved ONCE by the boot script
    folderName: string?,              -- default "Boars" (the literal `Weapon.Claim.visibleTargets`
                                      -- already uses; `Boar.CONFIG`'s `folderName = "Boars"` is
                                      -- server-side and not reachable from here)
    folder: Instance?,                -- a spec hands its own folder and never searches Workspace
    now: (() -> number)?,             -- default os.clock
    sweepSeconds: number?,            -- default CarcassPose.SWEEP_SECONDS
    assets: {                         -- default: ReplicatedStorage.AssetFetch
        ready: (id: number) -> boolean,
        ask: (id: number) -> (),
    }?,
    load: ((animator: Instance, id: number) -> any?)?,  -- default Animator:LoadAnimation; the seam
                                                        -- that makes the pose path driveable with
                                                        -- no asset and no download
}

export type Stats = {
    sweeps: number, trunks: number, carcasses: number, candidates: number,
    posed: number,            -- carcasses this client posed
    leftAlone: number,        -- "leave": a death was already drawing it
    waitingRig: number, waitingAsset: number, waitingLength: number,
    timedOut: number,         -- gave up after POSE_TIMEOUT_SECONDS
    loads: number, plays: number, writes: number,   -- Instance + property writes, ever
    bindBefore: number,       -- carcasses that were at bind when posed (section 9.2)
    worstSweepMs: number,
    lastSweepAt: number,
}

CarcassPose.SWEEP_SECONDS: number        -- 0.25
CarcassPose.MAX_POSES_PER_SWEEP: number  -- 4
CarcassPose.POSE_TIMEOUT_SECONDS: number -- 20
CarcassPose.CLIP_FOLDER_NAME: string     -- "Clips"

function CarcassPose.start(seams: Seams): boolean   -- false and touches nothing when not enabled,
                                                    -- or when the folder is not there yet (askable
                                                    -- again: `Mask.start`'s own contract)
function CarcassPose.step(dt: number)               -- cheap; sweeps at most every SWEEP_SECONDS
function CarcassPose.stop()                         -- stops its tracks, forgets every record,
                                                    -- destroys its Clips folder
function CarcassPose.decide(view: PoseView): string -- PURE (section 4.1)
function CarcassPose.stats(): Stats
```

**No remotes. No events. No setters.** Nothing in the game reads `stats()` — it exists for a spec and
for a probe, the way `Runtime:animationOf` and `Mask.stats` do.

### 6.3 `CarcassPoseBoot` — `src/client/CarcassPoseBoot.client.luau`

Boot line only, verbatim the shape of `RangeBoot`:

```luau
local on = Flags.isOn("CARCASS_POSE")            -- THE ONE READ, at the boundary
local started = CarcassPose.start({ enabled = on })
Workspace.ChildAdded:Connect(…)                  -- the folder can arrive after the boot
RunService.Heartbeat:Connect(function(dt) CarcassPose.step(dt) end)
```

With `enabled = false`, `start` returns `false` before touching any state and `step` returns on its
first line. **Nothing is connected that writes, nothing is created, nothing is scanned.**

### 6.4 Server side: one config key and one write

| | |
|---|---|
| `Boar.CONFIG.MODEL.PUBLISH_DEATH_POSE` | `Flags.isOn("CARCASS_POSE")`, read **once** at that boundary — the exact shape of its neighbour `ATTACH_BUDGET_MS = if Flags.isOn("BOAR_ATTACH_BUDGET") then 8 else 0` |
| `Body.stepVisual` | the one write (section 5.2), read-compare-write, gated on that key |
| `Boar.Body`'s requires | a second pure shared require (`ReplicatedStorage.Carcass`) beside `Licences`. That header says *"THIS MODULE'S FIRST AND ONLY REQUIRE"* and gives the test it must pass — pure shared data, no owner, nothing that can be written by it. `Carcass` passes it. **The header gets updated in the same commit** |

Both states are reachable **by parameter**: every server spec passes a config table with
`PUBLISH_DEATH_POSE` true or false, which is the only way either branch can be tested while the flag
sits at one of them (the harness refuses to run with an override set).

---

## 7. What it reads from and writes to other systems

| Fact | Owner | This system |
|---|---|---|
| `Workspace.Boars` and every trunk, zone part, constraint and `Visual` in it | `ServerScriptService.Boar` → `Boar.Body` (*"Nothing else in the codebase may touch `Workspace.Boars`"*) | **reads** the folder's children; **writes nothing** |
| `Carcass`, `Damageable`, `Wound`, `HitZone`, `Kind`, `Species`, `Reholds` | `Boar.Body` | **reads** `Carcass`; never writes any attribute |
| `DeathPose` (new) | `Boar.Body.stepVisual` — one writer | **reads** only |
| the death clip, its frame, the hold, the re-assert, the repair, the backstop, the roll, the lift, the anchor, the removal | `Boar.Body` (`collapse`, `stepVisual`, `stepCarcass`, `topple`, `liftDrawn`, `shouldRehold`, `shouldBackstopDeath`) | **untouched.** No call, no write, no track of the server's touched |
| the server's `AnimationTrack`s on the rig | `Boar.Body` (`trackFor`, `play`) | **reads** `Animation.AnimationId`, `IsPlaying`, `TimePosition` on the tracks `GetPlayingAnimationTracks` returns. Never writes one |
| animation asset ids | `ServerStorage.Assets` (`Assets.KEYS`), wired by `BoarAssetsBoot` into `Boar.CONFIG.MODEL.ANIMATION_IDS` | **never reads.** It is told one id per carcass, by the server, on the carcass |
| "has this client downloaded that id" | `ReplicatedStorage.AssetFetch` (`AssetFetch.nextAsk`, `ready`, `ask`) | **reads and asks** through it. It does **not** call `ContentProvider` itself: that would be a second answer to the same question, which is what `AssetFetch`'s own header is about |
| the flag mirror `ReplicatedStorage.Flags.State` | `ServerScriptService.FlagsBoot` | **reads once**, in `CarcassPoseBoot`, through `Flags.isOn` |
| `LocalTransparencyModifier` on range targets / other players / the local character | `Range.Mask` / `Range.Solo` / `Camera.Rig` | **untouched** |
| the viewmodel's own clone and poses | `Camera.Viewmodel` | **untouched** |

**It writes to no other system.** Its only writes in the world are `AnimationTrack`s it created on an
`Animator` it did not, plus `Animation` instances inside its own folder under `PlayerScripts`.

---

## 8. External sources

### 8.1 Roblox Creator Documentation — `Animator`, `AnimationTrack`, `AnimationPriority`

- <https://create.roblox.com/docs/reference/engine/classes/Animator>
- <https://create.roblox.com/docs/reference/engine/classes/AnimationTrack>
- <https://create.roblox.com/docs/reference/engine/enums/AnimationPriority>
- <https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider>
- Licence: Creator Documentation content, CC BY 4.0 (`github.com/Roblox/creator-docs`). Maintenance:
  **active**, by Roblox, with the engine.

**Well:** it is the only authority on what blends what. It states that an `Animator` is the thing
that applies a clip to a rig, that tracks are composed by **priority then weight**, that a
non-looped track that reaches its end stops, and that an animation played on an `Animator` on the
server replicates to clients. `Boar.Body`'s header already rests on exactly those sentences.

**Badly:** it does **not** say what happens when a **client** loads a track on an `Animator` the
**server** owns — which is the single fact this whole system stands on. That had to be measured
(`358-feas`: `ok=true`, `playing=2`, the drawn span moved 0.72 → 1.16 and `Stop` put it back). The
docs also do not state the `Length == 0` behaviour of a not-yet-downloaded asset, which this
repository measured twice (`Body.deathDrawn`, `Body.shouldRehold`) and which is test 8 of section 4.1.

**Adopted:** the pose is won by **`Priority = Action`** over the server's `Movement`
(`Body.trackFor`), at weight 1 — the documented mechanism, instead of the probe's weight 10, which
was an invention.

### 8.2 Roblox's own default character `Animate` script

Shipped by Roblox into every place's `StarterCharacterScripts` (a `LocalScript`), updated with the
engine; no open licence, inspectable in Studio.

**Well:** it is the engine's own precedent for the exact shape this design takes — **the client owns
the drawn pose of a replicated rig**: a LocalScript loads tracks on the character's `Animator` and
plays them locally, and no server script poses the player. "A client decides what this client draws
on somebody else's rig" is therefore not a new idea in this engine; it is the default.

**Badly:** it animates a character the client has **network ownership** of, and our carcass is pinned
to the server (`Body.create` and `Body.attachVisual` both call `SetNetworkOwner(nil)`; task 305
measured why). So it proves the **shape** and not the **mechanism** — the mechanism is `358-feas`.
**Not verified in this worktree:** no Studio here, so the claim about that script's contents is from
knowledge of the engine's default, not from a file in this repo. The Builder should confirm it in
Studio in one look before quoting it in a code comment (rule 9).

### 8.3 Sleitnick — RbxUtil `Component`

- <https://github.com/Sleitnick/RbxUtil> · <https://sleitnick.github.io/RbxUtil/api/Component>
- Licence: **MIT**. Maintenance: **active** (Sleitnick's maintained utility monorepo).

**Well:** the canonical Roblox answer to "one record per instance, with a lifecycle": a class bound
to instances by tag, with `Construct` / `Start` / `Stop`, and **automatic teardown when the instance
leaves**. That is precisely the per-carcass record this owner needs, including the part everybody
gets wrong — forgetting the record when the instance is destroyed.

**Badly:** it brings a framework (`Trove`, `Signal`, `CollectionService` tags) for one owner, and
this repository ships **no run-time Wally package at all** (`DevPackages` is TestEZ, test-only, and
it is git-ignored). Tagging the carcasses would also mean a second answer to "is this a carcass"
beside the `Carcass` attribute `Boar.Body.collapse` already writes and `Weapon.Claim.visibleTargets`
already reads.

**Adopted:** the **lifecycle**, not the code. One record per carcass keyed by the trunk; the record
is created on the sweep that first sees it and **dropped on the sweep that does not** — which is
`Range.Mask.step`'s own `seen` loop (*"A PART THAT LEFT THE FOLDER IS FORGOTTEN, not written to: a
cleared carcass is destroyed, and a write to a destroyed instance is an error, not a restore"*).

### 8.4 Quenty — NevermoreEngine `Binder`

- <https://github.com/Quenty/NevermoreEngine> · <https://quenty.github.io/NevermoreEngine/api/Binder/>
- Licence: **MIT**. Maintenance: **active** (long-running, versioned monorepo).

**Well:** the most battle-tested per-instance ownership pattern on Roblox, and it is explicit about
the two things that bite here: an instance can be bound **before its children replicate**, and
teardown must be idempotent. Our `"wait-rig"` branch is that first fact (`Visual` is
`ModelStreamingMode.Atomic`, so it arrives whole but **later** than the trunk).

**Badly:** same objection as 8.3 and larger — a service-bag dependency graph for one client module,
and it is tag-driven for the same reasons we refuse tags.

**Adopted:** "**bound early, ready later**" as an explicit state (`"wait-rig"`, `"wait-asset"`,
`"wait-length"`, each counted in `stats()`), instead of the usual `WaitForChild` that blocks a
sweep.

### 8.5 Borrowed from inside this repository (rule 2: say where you borrow)

| Borrowed | From |
|---|---|
| a **client-side owner** of a client-local fact on **server-owned instances**, with `start` / `step` / `stop` / `stats`, a **sweep instead of a signal**, an edge-triggered write table, a `seen` sweep that forgets departed instances, and a boundary asserted rather than promised | `src/client/Range/Mask.luau` (`Mask.start`, `Mask.step`, `Mask.apply`, `Mask.stats`, `Mask.stop`) |
| **the animal publishing its own fact as an attribute on its own trunk**, read-compare-write, for a reader that cannot see module state | `Boar.Body.stepVisual`'s `Reholds` (task 293c); `Body.setWound`'s `Wound`; `Body.collapse`'s `Carcass` |
| **a pure rule plus a thin writer**, so the branch is testable where it can fail | `Body.shouldRehold`, `Body.shouldBackstopDeath`, `Body.holdFrame`, `AssetFetch.nextAsk` |
| **named reason strings** instead of a bare `nil` | `Weapon.Claim.simulate` (`"no-target"`, `"static-blocked"`, `"refined-nil"`, …) |
| **injected seams** so a spec drives the real path with no network and no asset | `AssetFetch.setStatus` / `setAsk` / `setClock` |
| **the flag read once at the boundary and passed inward** | `Boar.CONFIG.MODEL.ATTACH_BUDGET_MS`, `Boar.CONFIG.GAIT.ENABLED` |
| **the boot line** | `src/client/RangeBoot.client.luau`, `src/client/AmbienceBoot.client.luau` |

The research note rule 1 asks for is `docs/research/2026-11-13-carcass-pose.md`, added to
`docs/research/INDEX.md`; sections 0, 5.4 and 8 of this design are its content, plus the five
readings' raw numbers.

---

## 9. Numeric targets

### 9.1 Cost — the brief's item 5

| target | value | derivation |
|---|---|---|
| sweep period | **0.25 s** (`SWEEP_SECONDS`) | a carcass that is standing has been standing for seconds; a quarter second is invisible beside that, and it is 4 sweeps/s instead of 60 |
| new poses per sweep | **≤ 4** (`MAX_POSES_PER_SWEEP`) | a release wave is ten animals (`Body.attachVisual`'s 92.1 ms burst, task 355); four per sweep clears ten in ≤ 0.75 s and never spikes a frame |
| per sweep, worst case | **≤ 0.30 ms** at 60 trunks | one `GetChildren` + 60 `GetAttribute("Carcass")`; `GetAttribute("DeathPose")` only for carcasses; `GetPlayingAnimationTracks` only for unposed candidates with a published pose |
| per sweep, typical | **≤ 0.10 ms** (≤ 10 carcasses of ≤ 32 trunks measured live) | |
| amortised | **≤ 1.2 ms/s = 0.07 %** of a 60 fps budget (16.7 ms/frame) | 4 × 0.30 ms |
| writes per carcass, **for ever** | **1** `LoadAnimation`, **1** `Play`, **1** `TimePosition`, **1** `AdjustSpeed` | section 4.2. Zero per-frame writes, which is the defect `Body.play`'s own `heldClip` fix was about |
| instances created, **for ever** | **1** `Folder` + **≤ 6** `Animation` (boar `deathLeft/Right`, `deathPaddleLeft/Right`; deer `deathLeft/Right`), cached by id | |
| writes to any BasePart, attribute, constraint or remote | **0** | section 1, asserted in section 11 |
| pose latency, once the state is detectable | **≤ 0.25 s + 1 frame** | one sweep |
| asset wait cap | **20 s** (`POSE_TIMEOUT_SECONDS`), then give up and count it (`stats.timedOut`) | `AssetFetch.RETRY_SECONDS` is 3, so ~6 attempts. A client that cannot download a clip is not helped by asking for ever |
| publish latency (server) | deer **≈ 1.14 s**, boar **≈ 5.18 s** after collapse | `MODEL.CLIPS` 1.167 / (1.208 + 4.0) minus `HOLD_EPSILON` 0.03 — section 5.3 |
| flag OFF | **0** sweeps, **0** reads, **0** instances, **0** attribute writes | section 10 |

### 9.2 Correctness — what has to read what

| target | value | instrument |
|---|---|---|
| standing carcasses on Karen's screen | **0** over a ≥ 480 s drive with ≥ 19 kills, 4 kinds | `<runs-dir>/358-cli.luau`, before and after |
| the measured failure state recovers | the `358-bind` case (hind 1.05 → 4.94, 3 of 3 **never** recovering in 12 s) recovers **within one sweep**, and the drawn span returns to within **0.15 studs** of the kind's held-fall value | `358-bind.luau` re-run with the flag on |
| the measured-benign states stay benign | **0** poses on the 19/19 healthy kills and **0** on the 80 forced server repairs → they answer `"leave"`, counted in `stats.leftAlone` | `358-stage.luau` + `stats()` |
| the bind reading is **recorded, not guessed** | for every carcass it poses, the owner records whether the rig was at bind before the write (`stats.bindBefore`), measured as the max `Bone.Transform` offset over ≤ 40 bones, once, on the frame it poses | so "the ON state fixed the ones that were broken" is a number. ≤ 40 CFrame reads per posed carcass, once — inside the 0.30 ms budget |
| `Boar`'s own counters | `handle.reholds` / the `Reholds` attribute and `handle.backstopped` **unchanged** between a flag-off and a flag-on run of the same drive | the server's own report |

---

## 10. The two states

**OFF (shipped, `default = false`) — today's world, byte for byte.**

- `Boar.CONFIG.MODEL.PUBLISH_DEATH_POSE` is `false`: `Body.stepVisual` writes **no** `DeathPose`
  attribute. Every other server write, counter, clip, freeze, repair, roll, lift, anchor and
  removal is the same code on the same instances.
- `CarcassPoseBoot` calls `start({ enabled = false })`, which returns `false` before touching any
  state. No folder lookup, no sweep, no `Animation`, no track, no `Clips` folder. The `Heartbeat`
  connection exists and `step` returns on its first line.
- So: the drawn world, the shot, the hit boxes, the score and every spec written before this task
  are untouched, and the 1-in-10 standing carcass is still there. That is the state the gate runs in.

**ON.**

- The server publishes one string attribute per carcass, once (twice for a boar: the fall's hold is
  superseded by the paddle's).
- Each client makes sure every carcass it can see is drawing that pose, and leaves alone every
  carcass that already is.
- Nothing else changes: same fall, same place, same drag/claim, same score (the brief's scope).

**Both states are reachable by parameter** with the row at `false`: the server specs pass a config
with `PUBLISH_DEATH_POSE` either way; the client specs pass `start({ enabled = … })`.

---

## 11. How it is proven

### 11.1 Server spec — `tests/server/carcass_pose.spec.luau`

Drives `Body.stepVisual` on a hand-built handle, which `tests/server/boar_model.spec.luau` already
does (`stepVisual` on a table the spec wrote itself — the reason `handle.leapFor or 0` exists).

1. **The format round-trips, and refuses rubbish.** `Carcass.format` / `Carcass.parse` over: a real
   id and frame; `0`; a negative frame; `nil`; `""`; `"abc"`; `"12:"`; `":3"`; `"12:3:4"`; a number;
   a table; `1/0`.
2. **It is published where the pose is frozen**, with the held clip's own id from
   `config.MODEL.ANIMATION_IDS` and `handle.heldAt` to 4 decimals.
3. **It is published for the PADDLE when the paddle supersedes the fall**, and the pair is never
   torn — one attribute, one value, asserted as one string.
4. **It is not published**: with `PUBLISH_DEATH_POSE` false; with `handle.visual == nil`; with
   `handle.toppled` true; with `ANIMATION_IDS` empty (`withIds({})`, the idiom
   `boar_shot.spec.luau` already uses); while the animal is alive; for a non-death held clip.
5. **THE INVARIANT, asserted and not described:** on a staged carcass, once `DeathPose` is present,
   `Body.shouldBackstopDeath` answers `false` for every later `since`, and a full
   `Body.stepCarcass` sweep over `DEATH_BACKSTOP_SECONDS` × 10 leaves `handle.toppled` false and
   `handle.backstopped` false. **A carcass carrying the attribute can never be rolled.**
6. **Read-compare-write:** 200 steps with nothing changed produce exactly **one** attribute write
   (counted through `GetAttributeChangedSignal`), the same test the `Reholds` mirror already passes.
7. **OFF is byte for byte:** with `PUBLISH_DEATH_POSE` false, the carcass's attribute set is exactly
   the set before this task.

### 11.2 Client spec — `tests/client/carcass_pose.spec.luau`

Runs in the player's client, in Play, as every `tests/client/` spec does.

1. **`CarcassPose.decide` over its whole truth table** — all nine ordered tests of section 4.1, each
   returning its named reason, with no instance anywhere. This is where the rule is really proven.
2. **Off an Instance the owner built, with the `load` seam** (a stub track table): a `Folder` holding
   a `Part` with `Carcass = true` and `DeathPose = Carcass.format(<a real published boar death id>,
   0.9)`, a `Visual` `Model`, an `AnimationController` and an `Animator` under it. After
   `start({ enabled = true, folder = fake, load = stub, assets = { ready = always, ask = noop } })`
   and two `step`s: exactly **one** load, `Priority == Action`, `Looped == false`, `Speed == 0`,
   `TimePosition == 0.9`, `stats().posed == 1`, `stats().plays == 1`.
3. **Idempotence:** 60 further steps add **no** load, **no** play and **no** write
   (`stats().loads`, `plays`, `writes` unchanged), and `decide` answers `"skip"`.
4. **Flag OFF:** `start({ enabled = false, folder = fake })` returns `false`; 60 steps leave
   `stats().sweeps == 0`, `posed == 0`, no `Clips` folder, and **zero** tracks on the fake `Animator`.
5. **The boundary, asserted:** a sibling `Part` with no `Carcass` attribute, a `Part` with
   `Carcass = true` and no `DeathPose`, and a clone of the local character placed in the fake folder
   are all untouched — no track loaded on any of them, and the trunk's `CFrame`, `Anchored`,
   `CanCollide`, `CanQuery` and attribute set are identical before and after (compared field by
   field, not eyeballed).
6. **The real call, once, with the real loader** on the fake `Animator` with a real published death
   id: `LoadAnimation` returns a track and the owner either poses it or answers `"wait-length"`.
   This is what proves the mechanism is real in the player's client and not only through the seam.
7. **`stop()` undoes what it can and says what it cannot:** every track it loaded is stopped, the
   `Clips` folder is gone, `stats()` is reset, and the spec records that the drawn pose stays
   (measured: `358-clipop`).
8. **`Carcass.parse` on the client** reads the same strings the server spec writes — one format, two
   suites, no second copy.

### 11.3 Harness

- **No new input scenario.** This system takes no input, so `tests/client/input_scenarios.txt` is
  untouched and none of Task 6's limits (touch, gamepad, `textInput`, frame-counted holds, input
  aimed at an instance, anything after the client report — `TASKS.md` rows 6, 7) bite.
- **One-player `test` only.** `src/client/CarcassPose/`, `src/shared/Carcass/` and
  `src/server/Boar/Body.luau` are **not** in `TWO_PLAYER_PATHS` (`tools/agents.py`): this is the
  boar and the drawn animal, which *"behave the same with one player as with two"*. `test2` is
  **N/A, with that as the reason.**
- **`scope=all`, and do not change that in this task.** An unmapped path under `src/` resolves to
  `all` in `BLAST_RADIUS` (`tools/studio_mcp.py`), which is the honest answer. Adding a `carcass`
  scope row would be a harness change inside the task whose evidence that harness produces. Queue
  it, do not take it.
- **Screenshot, rule 5, REQUIRED.** `python tools/studio_mcp.py capture` of the same staged carcass
  with the row off and with `python tools/flags.py set CARCASS_POSE on`, inspected by the Builder
  before any claim about what it shows. This is a visual change about a thing that *measured correct
  and looked wrong* — `docs/PROJECT_CONTEXT.md`'s first bullet.

### 11.4 The live instrument, which is the real proof

`<runs-dir>/358-cli.luau` (per-Heartbeat reading of the drawn bone span of every carcass), in
Karen's Forest Test, flag ON by `tools/flags.py`:

1. a ≥ 480 s drive, ≥ 19 kills, ≥ 4 kinds → **0 pops**, and `stats()` printed: `posed`,
   `leftAlone`, `bindBefore`, `timedOut`, `worstSweepMs`;
2. `358-bind.luau` staged 3 times → each recovers inside one sweep, against **3 of 3 never** today;
3. `358-stage.luau` forcing the server's repair 80 times → **0** poses by this owner
   (`leftAlone` = 80), proving the owner does not fight the server;
4. `worstSweepMs` against the 0.30 ms target, over the whole drive.

### 11.5 What no spec in this repository can prove, named rather than discovered

- **That the pose looks right.** Only the instrument and Karen's eye. Section 11.3's two screenshots
  and her playtest are the evidence; a number is not a verification.
- **Whether a client-loaded track on a server-owned `Animator` replicates to the OTHER clients.**
  Not measured, and `358-feas` does not answer it. **The design is robust either way**: every client
  runs the same owner and pins the same clip at the same frame the server published, so a pose that
  leaked to another client is the pose that client would have drawn anyway. If the Builder wants the
  answer it is one two-client probe, and it is **not** a blocker.
- **`TimePosition` on a real not-yet-downloaded asset in Play.** The `Length <= 0` guard exists
  because of two measurements already in `Boar.Body`; it is enforced by `decide` and asserted
  through the seam, not by making an asset fail to download on command.
- **The exact contents of Roblox's default `Animate` script** (section 8.2) — no Studio in the
  Architect's worktree.

---

## 12. Open decisions

**None of these blocks building.** Each has a stated default, and the default is what the Builder
builds.

### For Karen (feel)

1. **The boar's ≈ 5.18 s publish window** (section 5.3). A client that meets a boar carcass before
   its paddle has finished has no pose to be told, so it keeps drawing whatever it has — which for
   the broken 1-in-10 is a standing animal, for up to ~5.2 s instead of ~110 s. **Default: as
   designed.** The alternative is publishing a provisional pose at the moment of collapse, which
   re-opens the backstop race section 5.2 closes; it would need its own guard and its own
   measurement. Ask her after she has played it once with the flag on: is a boar that stands for a
   few seconds and then lies down worse than one that stands for two minutes? A deer is ≈ 1.14 s
   either way.
2. **Nothing else.** ON draws the server's own held frame — the pose she already accepted
   (*"I thin kwe good"*, 2026-10-03, task 116). This task adds no new look.

### For the Director (scope)

3. **`Flags.MAX_FLAGS` 29 → 30** for `CARCASS_POSE`. `src/shared/Flags/init.luau` holds 29 rows and
   `flags.spec`'s rot tripwire refuses the thirtieth until that line moves. The two ways out are the
   two task 238 listed: spend `TASKS.md` row 82b (retire the lit rows — the Director's call, one
   archive per retirement, rule 7), or ship lit, which `docs/design/feature-flags.md` section 11
   step 1 forbids for a new feel-critical path. **Default: bump by one under a stated assumption,
   as tasks 238, 245b, 251, 298, 305c, 313, 323a, 345a, 347, 349, 351, 354 and 355 each did**, and
   put 82b back in front of him. `expires` ≤ 21 days: **2026-12-04**.
4. **One new shared module, `src/shared/Carcass/init.luau`** (frozen format + pure parser, no
   run-time writer). The alternative is the string format written in `Boar.Body` and parsed again in
   `CarcassPose` — two homes for one format, which is the drift this repository is a document about.
   **Default: the module.**
5. **Log only, not this task:** the literal `"Boars"` is already written twice
   (`Boar.CONFIG`'s `folderName` and `Weapon.Claim.visibleTargets`), and the literal `"Carcass"`
   three times (`Body.collapse`, `Claim.visibleTargets`, and the range). Unifying them into
   `ReplicatedStorage.Carcass` is a separate task; this design adds the **new** name there and
   touches neither old one. Queue it in `TASKS.md` under "before release".
6. **Log only, not this task:** `Workspace.RangeTargets` carcasses (`Range.CONFIG.CARCASS_SECONDS`
   = 3) get no pose owner. One line in the boot's folder list if the range ever wants it; the brief's
   scope is the hunt.
7. **Log only:** a `carcass` row in `BLAST_RADIUS` / `SCOPE_SPECS` (`tools/studio_mcp.py`) so a later
   change here can run a scoped review round. Not in this task — section 11.3.

---

## 13. The build order this design asks for

One commit, in this order, because each step is inert until the next one exists:

1. `src/shared/Carcass/init.luau` — the attribute name, `format`, `parse`, `HOLD_EPSILON`.
2. `src/shared/Flags/init.luau` — the `CARCASS_POSE` row (`default = false`, `owner`, `born`,
   `expires = "2026-12-04"`, `why`), and `MAX_FLAGS` 29 → 30 with the sentence the file's own
   precedent requires.
3. `src/server/Boar/init.luau` — `MODEL.PUBLISH_DEATH_POSE = Flags.isOn("CARCASS_POSE")`, at the
   boundary, beside `ATTACH_BUDGET_MS`.
4. `src/server/Boar/Body.luau` — the one read-compare-write in `stepVisual`, the `Carcass` require,
   and the header updated (it currently says *"FIRST AND ONLY REQUIRE"*).
5. `src/client/CarcassPose/init.luau` — `decide` first, then the sweep around it.
6. `src/client/CarcassPoseBoot.client.luau` — the boot line.
7. `tests/server/carcass_pose.spec.luau`, `tests/client/carcass_pose.spec.luau`.
8. `docs/research/2026-11-13-carcass-pose.md` + `docs/research/INDEX.md`; the `GAME_DESIGN.md`
   owners row of section 2.
9. The gate: `python tools/flags.py clear`, `python tools/studio_mcp.py test` (full), the two
   screenshots, then the request.

If the Builder disagrees with any of this, `ESCALATE.md` and stop — it does not edit this file.
