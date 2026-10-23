# Task 250 BRIEF: the AMBIENCE system (item 4 of the dispatch)

The input to `tools/architect.sh design ambience --task 250`. Written by the Builder carrying the
Director. It overrides anything older in `docs/`, `TASKS.md` and any earlier design.

## Why a design run at all: the dispatch's premise is wrong and that is the finding

The dispatch says *"Find the existing ambience owner (the forest ambience runs at volume 3.00, per
task 248) and add a lodge bed."* **THERE IS NO AMBIENCE OWNER IN `src/`.** Measured, 2026-10-23:

* `grep -rni "ambien" src/ --include=*.luau` returns only `Lighting.Ambient` reasoning, one
  `MAX_MUTTER_VOICES` comment and the two sound owners' own headers. No module plays a bed.
* The only `Sound` creators in the whole tree are `src/client/Hud/Sound.luau` (the hit tick and the
  drive's bugle), `src/client/Weapon/Sound.luau` (the gun), `src/server/Boar/Body.luau` (the
  animal), `src/server/Lobby/Build.luau` (a truck engine) and `src/server/Weapon/Horn.luau` (the
  beater's blast). None of them is a bed.
* The forest ambience Karen hears is a **Studio-made instance in the Forest Test place**, not code:
  probed in Edit through `ftq.py`, the place holds exactly ONE ambience Sound --
  `Workspace.Ambience`, `rbxassetid://4629533497`, `Volume 0.50`, `Looped = true`, playing,
  parented straight to `Workspace`. Nothing in this repository names that id.

So "add a lodge bed" is a NEW SYSTEM with a NEW OWNER, which is CLAUDE.md loop step 2 and rule 1,
and this brief is its input rather than the Builder inventing the owner.

## Decisions already taken (do not re-open)

1. **Karen's words, 2026-10-23, verbatim:** *"any lobby music, like birds relax quuiet ?"*. The
   Director's reading, which is the brief: **at the lodge/lobby, quiet birdsong plus a soft wind,
   calmer and quieter than the hunt's forest ambience, crossfading when you leave for the drive and
   when you come back.**
2. **CLIENT-SIDE, AT THE EAR, LOCAL.** The same rule both existing sound owners state in their own
   headers: no parent part, so the bed is not positional. A bed every player hears is one Instance
   per client, not one Instance in the world everybody is near.
3. **THE VOICES ARE ROBLOX-PROVIDED LICENSED LIBRARY AUDIO AND NOTHING IS UPLOADED.** Swept and
   measured on 2026-10-23 through `apis.roblox.com/toolbox-service/v1/marketplace/audio` filtered to
   licensed partners: `Pro Sound Effects "Morning Forest Birds"` (36-75 s takes) and
   `Pro Sound Effects "Leaves Rustle Wind Blowing Through Trees 1/2"` (76 s and 87 s). Karen's OK
   covers a CC0 UPLOAD; it does not require one, and `tools/roblox_upload.py` implements Model and
   Decal only (its own selftest asserts that `Audio` is refused), so the upload route would be a
   tool change on top of a four-item task for a sound the licensed catalogue already has.
4. **THE PLACE'S OWN `Workspace.Ambience` IS NOT OURS TO TOUCH.** It is a Studio-edited non-script
   instance in a container Rojo does not own (CLAUDE.md, Layout). The new owner may not delete it,
   reparent it or write its `Volume`: that would make this repository a second writer of an
   instance Karen placed by hand, and a Connect would not put it back.
5. **ONE DATA ROW PER NUMBER**, the discipline `Rifle.CONFIG.SOUND` and `Lever.CONFIG.SOUND`
   already keep: every id, volume, fade length and loop window is one line Karen can turn.
6. **NOBODY HERE CAN HEAR IT.** The Builder cannot play audio. What the Builder proves is what
   reaches the engine -- the Sound exists, `IsLoaded`, `IsPlaying`, its `SoundId` and its resolved
   `Volume` -- and **Karen's ears decide**.

## What the design must contain

1. **THE OWNER AND ITS NAME.** One module, one writer of the bed. Say whether it is a new
   `src/client/Ambience/` or a voice class inside `src/client/Hud/Sound.luau`, and say why -- the
   Hud's own header claims it owns *"the Hud's own 2-D feedback sounds"*, and a world bed is not
   feedback, so reusing it is a naming question the design must answer rather than the Builder.
2. **WHAT TELLS IT WHERE THE PLAYER IS.** The client already has the drive replica
   (`src/client/Match/init.luau` owns the snapshot and the feed; `Hud.Objective`'s own note is that
   *"the lodge is not in a drive, so he has no team"*). Name the ONE fact the owner reads and the
   ONE boundary it reads it at. It must not measure a position, and it must not learn what a lodge
   model is.
3. **THE CROSSFADE, AS A STATE MACHINE.** Two beds, at most one rising and one falling at a time;
   what happens when the state changes mid-fade; and what the bed does in a world that has no lodge
   at all (the DEV arena, where every spec runs).
4. **WHAT IS PROVABLE WITHOUT EARS.** The facts a spec may assert, in a place with no lodge and no
   drive, with no yielding clock -- the shape `Hud.Sound`'s `madeAtLoad` / `preloaded` /
   `signalling` accessors already have.
5. **THE OWNER BOUNDARY AGAINST THE FIVE EXISTING SOUND WRITERS**, named, including that this owner
   never touches `SoundService` properties (`AmbientReverb`, `Volume`) -- which no module writes
   today and which would be a second answer to how loud the whole game is.
6. **THE SCOPE ROW.** Any new spec file must belong to a `SCOPE_SPECS` scope in
   `tools/studio_mcp.py` or CI goes red (standing rule G), and `BLAST_RADIUS` needs a row for the
   new path. Say which scope name.

## Out of scope for this design

The three other items of task 250 (the semi-auto's voice, the rifle's voice/damage/recoil, the money
penalties) are data rows and changes inside systems that already have owners and designs
(`docs/design/semiauto-shotgun.md`, `docs/design/rifle.md`, `docs/design/economy-v1.md`,
`docs/design/drive.md`). This design is the ambience bed and nothing else.
