# A dead animal's drawn pose, owned by the client (task 358)

Karen, 2026-11-10: *"animal died and then stand and then again die"*.
Design: `docs/design/carcass-pose.md`. Measurements: `<runs-dir>/358-*`.

## 1. What the system must do

On every client, an animal the server has already called dead must be **drawn** in a death pose,
from the moment that client can see it until the carcass is removed, for every kind (boar male,
female, cub, legendary; red deer stag, hind, calf). Nothing else about death may change: the fall,
where it lies, the drag/claim, the score are the server's and stay the server's.

## 2. What was measured first, and what it refuted

The dispatch's premise was the 6 s death re-assert: *"Play restarts a track at frame 0, and frame 0
of a death is the animal on its feet"*. Instrument `<runs-dir>/358-cli.luau`, a per-Heartbeat read
of the drawn bone span (`Bone.TransformedWorldCFrame`) of every carcass in Karen's Forest Test — the
344b sampler read it every 0.5 s and the event is shorter than that.

| reading | result | file |
|---|---|---|
| a 480 s drive, 19 kills, 4 kinds | **0 pops / 19 kills**, longest 0.00 s | `358-BEFORE-cli.txt` |
| the server's own repair forced 80 times (`358-stage.luau` stops the held death track; the server's `shouldRehold` / 6 s re-assert then replays it: `Play(0,1,0)`, `TimePosition`, `AdjustSpeed(0)`) | **0 client pops / 80 repairs**; the drawn span never moved | `358-BEFORE-staged-cli.txt` |
| a client track stopped, the bones left alone | the pose **stays**: 1.05 before, 1.05 after 12 s, 0 tracks playing | `358-clipop.luau` |
| no track **and** the bones at bind — the state 344b logged on its one standing carcass (`drawn=none`, span 3.07 where lying was 0.90), i.e. a rig that **streamed in and never received the death** | hind 1.05 → **4.94**, hind 1.04 → **4.93**, cub 1.01 → 1.35; **recovered NEVER in 12 s, 3 of 3** | `358-bind.luau` |

**So the stated cause is refuted and a worse one is measured.** The re-assert is harmless. What
stands an animal back up is a client whose rig is drawing **no pose at all** — the bind pose, which
for every animal in this game is on its feet — and such a client **never recovers**, because the
server's re-assert is one-shot (`handle.reasserted`) at `CARCASS_REASSERT_SECONDS` = 6 and
`Body.shouldRehold` only fires when the **server's own** track is broken. A carcass that reaches a
client after the 6 s mark stands for the rest of its `CARCASS_SECONDS` = 120, not "under 4 s".

The second measurement above is also why the server cannot fix this: it already believes it said the
death, and 344b proved that gating the re-assert on the server's pose is worse (a carcass standing
50 s).

## 3. Sources

### 3.1 Roblox Creator Documentation — `Animator`, `AnimationTrack`, `AnimationPriority`

<https://create.roblox.com/docs/reference/engine/classes/Animator> ·
<https://create.roblox.com/docs/reference/engine/classes/AnimationTrack> ·
<https://create.roblox.com/docs/reference/engine/enums/AnimationPriority>
Licence: CC BY 4.0 (`github.com/Roblox/creator-docs`). Maintenance: **active**, by Roblox.

**Well:** the only authority on what blends what — an `Animator` applies a clip to a rig, tracks
compose by **priority then weight**, a non-looped track that reaches its end stops, and an animation
played on a server `Animator` replicates to clients.

**Badly:** it does not say what happens when a **client** loads a track on an `Animator` the
**server** owns — the single fact this system stands on. Measured instead (`358-feas.luau`, on a
live carcass in her Forest Test): `LoadAnimation` from the client returns a track (`ok=true`), it
plays beside the replicated one (`playing=2`), it takes the weight it is given (`localW=10.00`), and
**it changes what is drawn** (span 0.72 → 1.16 with the local track pinned at frame 0); `Stop` put
it back (0.72). The docs are also silent on `Length == 0` for a not-yet-downloaded asset, which this
repository has measured twice (`Body.deathDrawn`, `Body.shouldRehold`).

**Adopted:** the pose is won by **`Priority = Action`** over the server's `Movement`
(`Body.trackFor`) at weight 1 — the documented mechanism — rather than by the probe's weight 10,
which was an invention.

### 3.2 Roblox's own default character `Animate` script

Shipped by Roblox into every place's `StarterCharacterScripts`; updated with the engine; no open
licence, inspectable in Studio.

**Well:** the engine's own precedent for exactly this shape — **the client owns the drawn pose of a
replicated rig**. A LocalScript loads tracks on the character's `Animator` and plays them locally;
no server script poses the player.

**Badly:** it animates a rig the client has network ownership of, and a carcass is pinned to the
server (`Body.create` and `Body.attachVisual` both `SetNetworkOwner(nil)`). So it proves the
**shape**, not the mechanism; the mechanism is `358-feas.luau`.

### 3.3 Sleitnick — RbxUtil `Component` (MIT, active)

<https://github.com/Sleitnick/RbxUtil> · <https://sleitnick.github.io/RbxUtil/api/Component>

**Well:** the canonical Roblox answer to "one record per instance with a lifecycle" —
`Construct`/`Start`/`Stop` and automatic teardown when the instance leaves, which is the part
everybody forgets.

**Badly:** a framework (`Trove`, `Signal`, `CollectionService` tags) for one owner, and this
repository ships no run-time Wally package at all. Tagging carcasses would also be a second answer
to "is this a carcass" beside the `Carcass` attribute the server already writes.

**Adopted:** the **lifecycle**, not the code — one record per carcass, created on the sweep that
first sees it and dropped on the sweep that does not.

### 3.4 Quenty — NevermoreEngine `Binder` (MIT, active)

<https://github.com/Quenty/NevermoreEngine> · <https://quenty.github.io/NevermoreEngine/api/Binder/>

**Well:** the most battle-tested per-instance ownership pattern on Roblox, explicit about the two
things that bite here: an instance can be bound **before its children replicate**, and teardown must
be idempotent.

**Badly:** a service-bag dependency graph for one client module, and tag-driven for the same reason
we refuse tags.

**Adopted:** "**bound early, ready later**" as explicit, counted states (`wait-rig`, `wait-asset`,
`wait-length`) instead of a `WaitForChild` that blocks a sweep.

## 4. The pattern adopted, and why (rule 2)

**Borrowed, not invented.** The owner is `Range.Mask`'s shape (a client-side owner of a client-local
fact on server-owned instances: `start`/`step`/`stop`/`stats`, a sweep rather than a signal, and a
`seen` loop that forgets departed instances). The animal publishing one fact about itself as an
attribute on its own trunk, read-compare-write, is `Body.stepVisual`'s own `Reholds` (task 293c).
The pure rule plus a thin writer is `Body.shouldRehold`. The named reason strings are
`Claim.simulate`. The flag read once at a boundary and passed inward is
`Boar.CONFIG.MODEL.ATTACH_BUDGET_MS`.

**The one thing with no precedent here** is a client-loaded `AnimationTrack` on a server-owned
`Animator`: no file under `src/client/` calls `LoadAnimation` today. That is why it was measured
before it was designed (3.1), and why Roblox's own `Animate` script is cited as the shape (3.2).

**Why the client and not more server repair:** the failing client is precisely the one the server
believes it has already told. Any server-side answer is another message to a client that is not
listening yet; the client is the only place that can see "I am drawing nothing".

**Why an attribute carries the clip id:** `ServerStorage.Assets` does not replicate and there is no
shared id table by design, so the id is the one thing the client cannot get any other way. One
string (`"<id>:<seconds>"`) and not two numbers, because the pair changes together when the paddle
supersedes the fall, and a reader between two writes would pin one clip at the other's frame.

## 5. Numeric targets

| target | value |
|---|---|
| standing carcasses on Karen's screen | **0** over a ≥ 480 s drive with ≥ 14 kills, ≥ 3 kinds |
| the measured failure (`358-bind`: 3 of 3 never recovering in 12 s) | recovers within **one sweep**, 0.25 s + a frame |
| the measured-benign states stay benign | **0** poses on healthy kills and on the 80 forced server repairs (counted as `leftAlone`) |
| sweep period / poses per sweep | 0.25 s / ≤ 4 |
| worst sweep | ≤ 0.30 ms at 60 trunks; amortised ≤ 0.07 % of a 60 fps frame |
| writes per carcass, for ever | 4, on a track this client made; **0** to any BasePart, attribute, constraint or remote |
| publish latency (server) | deer ≈ 1.14 s, boar ≈ 5.18 s after collapse (the held clip's own length) |
| flag OFF | 0 sweeps, 0 reads, 0 instances, 0 attribute writes |
