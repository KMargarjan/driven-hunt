# Project context

## Who
Karen, frontend developer (Vue/TS), building a public Roblox game. Her daughter
plays and builds with her. Karen tests the game; nobody else can judge feel.

## The game
"Driven Hunt". Drivers with AI dogs push wild boar toward shooters on a line.
10-16 players, equal split, third person with first-person aim, break-action
shotgun (slugs and buckshot). Hit zones: head/chest instant, body short run,
legs long run with a blood trail. 10-minute drives, points per animal. Shooting
toward the drive line is punished (tied to a tree). Map: European farmland and
woods. Cosmetics only for money. v1 in a couple of months. Later: roe deer,
fox, rabbit.

## Build order
1. Grey-box core loop: one boar AI, shotgun, hit zones, score, teams, one
   drive. Tested with two real players. No art.
2. Dogs, safety rule, posts, full match loop.
3. Art, map, sound.
4. Menu, cosmetics, publish.

## Why the rules exist - the previous project
A Roblox flying-and-archery game, abandoned after months. What killed it:
- The agent verified its own work with numbers and never looked. Things
  measured correct and looked wrong: a knife held backwards for three rounds,
  purple untextured legs, a marker wandering the screen, 304 "burnt" trees on
  green grass.
- Its own test harness was wrong as often as the game was. Several rounds were
  spent on bugs that did not exist. A visibility audit ignored parent
  visibility and certified a blank screen twice.
- Overlapping owners. Three scripts set the mouse cursor. One predicate
  answered two unrelated questions, so mounting hid both the crosshair and the
  weapon. Two systems wrote the creature's position. Most of the worst bugs
  were two correct pieces of code disagreeing.
- Invented foundations. Cutting a mesh into pieces, a hand-written FBX reader,
  a home-grown viewmodel system. Each produced a run of bugs and each was fixed
  for good only by adopting an established pattern.
- Big multi-item rounds hid failures. Small single-task rounds worked.
- Everything lived in the cloud place file: no diffs, no history, no rollback.

## What follows from that
- Research before implementation, borrow before building.
- One owner per system, written down.
- One task per round.
- Look at the screen; a number is not a verification.
- A harness fault is a bug and gets reported.
- Code on disk, in git, reviewed as a diff.
