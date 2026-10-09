# The bolt, the magazine and the rifle's voice

2026-10-10, for Task 142. Karen, after playing the merged rifle (`b95d8a7`):

> *"we need a dot in scope center red dot where / next is reload has to be done for rifle with right
> hand like it happen in real life / and in magazine 3 shells then it changes with left hand magazine
> / in front of scope when not aiming has circle transperent it shouldn't be like that / for rifle has
> to be another gun fire sound"*

The scope itself is settled in [2026-10-09-rifle-scope.md](2026-10-09-rifle-scope.md); this note
covers only what that one did not: **what a bolt cycle does to the sight picture**, **how a magazine
fits the state machine this project already has**, and **where the rifle's voice comes from**.

---

## 1. What the system must do

| Must | Why, in Karen's words |
|---|---|
| Work the bolt with the **right** hand, visibly, after every shot | *"reload has to be done for rifle with right hand like it happen in real life"* |
| Hold **3 rounds**, then a **left-hand magazine change** | *"in magazine 3 shells then it changes with left hand magazine"* |
| A **red dot** at the centre of the sight picture | *"we need a dot in scope center red dot"* |
| Its **own** gunshot | *"for rifle has to be another gun fire sound"* |
| **No circle** in front of the scope at hip | *"it shouldn't be like that"* |

And one thing the Director asked this note to settle: **does the view stay in the scope while the
bolt is worked?**

---

## 2. The scoped bolt cycle — what other games do, and what we do

Three sources, fetched 2026-10-10.

1. **PUBG (Krafton), bolt-action snipers.** The Steam discussion
   ["How to stay in scope after ive shot with a kar or any other bolt action sniper?"](https://steamcommunity.com/app/578080/discussions/1/3211505894117635275/)
   — the question itself is the evidence: the **default is that the view leaves the scope for the
   bolt cycle**, and the answer is a workaround, *"Hold down the left mouse button when you shoot"*.
   Community forum, no licence, not a maintained artefact: cited as evidence of **behaviour**, not as
   code.
2. **Battlefield 1 (DICE).** Reported consistently in the same search: BF1 **requires the player to
   come out of the sight to cycle the bolt**, and the stated in-world reason is that you need a grip
   on the rifle to work it and that cycling while aimed throws the aim off. Same status: evidence of
   behaviour.
3. **Enlisted (Darkflow), developer forum,
   ["Bolt action rifle animation refinment"](https://forum.enlisted.net/t/bolt-action-rifle-animation-refinment/130226).**
   What it settles is the **speed**, not the camera: a shooter who learned on an SMLE Mk III —
   *"Can cycle that bolt every bit has fast. Hard and fast."* — against a request for a slower, less
   *"clunky"* animation, and the thread's own consensus is that refinement must **not** cost bolt
   speed. Live forum thread, no licence.

**ADOPTED: the view comes OUT of the scope for the cycle and goes back in when it ends.** Two of the
three games with the most-played bolt actions do exactly this, and for this game it is not a close
call for a third reason the sources do not have to supply: **our sight picture is a full-screen black
mask with the gun hidden behind it** (task 141), so "stay scoped" would mean Karen watching a black
circle while the thing she asked to see happens behind it. She asked to SEE the right hand work the
bolt. Coming out of the scope is what makes that animation exist at all.

**The other branch is reachable by a parameter, not by an edit** — `scope.cycle.leaveScope`, data on
the weapon's scope. Setting it false keeps the sight picture up through the cycle, which is the
"stay scoped" pattern, so the Director can look at both live without a build. **There is no jolt**:
an earlier draft of this note promised a `joltDeg` as well and nothing implements one, which is the
kind of sentence a design doc must not carry.

**ADOPTED: the cycle is FAST.** Source 3. The two steps total **0.62 s** — back 0.26, forward 0.36 —
against the shotgun's 2.0 s break-load-load-close. Two steps and not three: there is no `Load`,
because the magazine already holds the rounds. A bolt that takes a second reads as a jam.

---

## 3. The magazine — three chambers, not a second ammo model

`Weapon.StateMachine` already models a gun as an **array of chambers** (`barrels`, each
`Live`/`Spent`/`Empty`) plus a **pocket** (`reserve`, counted per ammo kind). A box magazine of three
is that array with three entries. Nothing else about the reducer changes shape.

Two row fields carry the difference, because a bolt is not a break action:

* **`CYCLE_EJECTS = "spent"`.** The shotgun's `Break` empties **every** chamber — correct for a
  gun you crack open over your arm, and catastrophic for a magazine, where it would dump the two
  unfired rounds on the ground after every shot. The rifle's bolt ejects **the SPENT chamber** and
  leaves the rest of the magazine alone. (It is `"spent"` and not `"selected"`: `Fire` has already
  moved `selected` on to the next live chamber by the time the bolt opens, so "the selected one" is
  the round about to be fired, not the case to throw.)
* **`Magazine` — one new action.** It fills every empty chamber from the reserve in **one step**,
  which is what swapping a magazine is. Feeding three rounds one at a time through the existing
  `Load` would be a stripper clip, not what Karen described.

**Borrowed before built** (rule 2): the alternative was a separate `magazine` field in the state and
a second path through the wire, the validator, the Hud and the viewmodel. The chamber array already
replicates, the Hud already reads it, `nextLive` already picks the next loaded chamber, and the
rifle's "one round at a time" reading of it was always a special case of "three". One new action and
two row fields is the smaller change by a wide margin.

**The readout** becomes `3/3` rather than the shotgun's per-chamber glyphs, because three glyphs is
not what Karen asked for and is not what a magazine rifle shows anybody. `row.READOUT` names which.

---

## 4. The rifle's voice

**The rule this project already follows:** an id is configuration, the volumes are data, and an empty
id plays nothing and is not an error (`Camera.Config.SOUND_SHOT_ID`'s own comment). What task 142 adds
is that the ids are **per weapon**, on the row, because a second gun with the first gun's voice is
exactly what Karen heard.

**Every id below is Roblox-provided licensed library audio, verified by name and creator** through
`economy.roblox.com/v2/assets/<id>/details`, and **measured to load in the Forest Test** with
`ContentProvider:PreloadAsync`, reading `IsLoaded` and `TimeLength` off the real `Sound` — the same
procedure task 124 used for the hit ticks.

| Use | Id | Name, creator | Measured |
|---|---|---|---|
| rifle shot | `9118173739` | "Rifle Single Shots 1 (SFX)", **ProSoundEffects** — *"Rifle, Barrett M82 .50 Cal, Single Shots, Metal Clinks"*, Guns - Machine | `loaded=true 3.36 s` |
| bolt | `9117889191` | "Ppsh Burp Gun 7 (SFX)", **ProSoundEffects** — *"Cocking and Loading, Dull Metal Movements, Clicks"*, Guns - Handling | `loaded=true 2.45 s` |
| magazine | `9119115171` | "Shotgun Handle 1 (SFX)", **ProSoundEffects** — *"Grab, Handle"*, Guns - Handling | `loaded=true 0.58 s` |
| (the shotgun's, for contrast) | `99008924129683` | "AS_shotgun_shot-01", Audioscape | `loaded=true 0.92 s` |

"Courtesy of Pro Sound Effects" is Roblox's own licensed catalogue, `IsPublicDomain: true`: nothing is
uploaded to Karen's account and no `assets/uploads.json` row is needed, exactly as the shotgun's id
needed none.

**Why a .50 BMG for a .416 Rigby.** Karen asked for *"another gun fire sound"* with, in the
Director's words, a sharper crack and a longer tail than the shotgun. The measurement is the
argument: the shotgun's sample is **0.92 s** and this one is **3.36 s**, which is the tail. A big-bore
rifle is the nearest thing in the licensed catalogue to a .416, and the alternative — a user re-upload
of game audio — is what the search actually turns up for "hunting rifle" (Call of Duty, Fortnite and
CS:GO rips, every one of them `IsPublicDomain: true` and none of them ours to ship).

**Every sample is CUT, and that is not optional.** "Single Shot**s**" is plural: a 3.36 s clip from a
gunfire library is a take, not a round. `SOUND.cut`/`SOUND.fade` play the first `cut` seconds and fade
the last `fade` of them, the mechanism `Boar.CONFIG.SOUND`'s own `cut = 0.6` already uses for the
death squeal. Shot 1.6 s, bolt 0.35 s, magazine 0.45 s.

**NOBODY HERE HAS HEARD ANY OF THEM.** The Builder cannot play audio; what is verified is that the id
exists, is licensed library audio, says on its own store record what it is, and loads in this place.
**Karen's ears decide**, and every one of these is one line to change.

---

## 5. Numeric targets

| Thing | Value | Where it came from |
|---|---|---|
| magazine | 3 rounds | Karen |
| reserve | 9 (three magazines) | Builder's pick; her dial |
| bolt cycle | 0.62 s total | source 3's "hard and fast" |
| magazine change | 1.35 s | Builder's pick; slower than the bolt because two hands and a part are involved |
| scope leaves for the cycle | yes | sources 1 and 2, plus our own mask |
| red dot | 0.085 deg | at FOV 19.87 on 1080p that is ~4.6 px: a dot, not a blob |
| shot sample | cut 1.6 s, fade 0.4 | one crack plus tail from a 3.36 s take |

---

## 6. What is explicitly NOT in this task

* **The rifle without a scope** — Karen asked for it in the same message and the Director cut it to
  **Task 143**.
* Bullet drop, hold-breath and a second ammo kind: out, with the reasons in the scope note's §1.2.
* A real detachable magazine **mesh**: the Rigby model has none (its four groups are stock, action,
  bolt and scope), so the magazine is a **drawn part** sized to the action's underside, the same way
  the lens was drawn and for the same reason — there is nothing in the file to upload.
