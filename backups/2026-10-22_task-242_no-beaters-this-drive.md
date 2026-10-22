# Archived: the `NO BEATERS THIS DRIVE` caption (task 242, 2026-10-22)

Rule 7: nothing is deleted, it is archived with a note.

## What was removed

Two rows, one sentence, in the two tables that are one vocabulary:

```luau
-- src/shared/Lobby/init.luau, CONFIG.PADS.PANEL.ROLE
NOTE_NONE = "NO BEATERS THIS DRIVE",

-- src/shared/Shop/init.luau, CONFIG.TEXT
ROLE_SOLO = "NO BEATERS THIS DRIVE",
```

...and the branch in `Hud.PadPanel.roleCaptionFor` that printed it:

```luau
if size ~= nil then
    return if size <= 1 then words.NOTE_NONE else words.NOTE_SENT
end
```

## Why it existed (task 229, 2026-10-21)

`Roster.assign` honoured no beater wish on a roster of one, because
`ODD_PLAYER_TEAM` is `Shooters`, so `Roster.shooterSlots(1) = 1` and
`driverSlots = 0`. The reason given was `docs/design/bots.md`, which fills both
sides with rigs and states twice that no bot shoots -- so a solo beater was held
to be "a drive in which nothing can be shot".

The caption existed because a refusal with no words is a dead button: the half
of Xonotic's `TeamBalance_CheckAllowedTeams` this repository inverts. If the
switch was going to refuse, it had to say why.

## Why it went (task 242)

KAREN, 2026-10-22, verbatim: *"in nex drive I can't select beater but I have
this license fix it"*. She owns the BEATER LICENCE and plays SOLO.

The premise was wrong, not the arithmetic. A roster of ONE cannot make
`|Drivers - Shooters|` exceed 1 whichever side he takes, so the balance rule has
no opinion to enforce, and `Bots.Fill.counts` fills each side to its own target
independently -- so a solo beater gets bot hunters on the stands and walks the
wood with the horn. Measured in the Forest Test on her own path: team=Drivers,
Horn in the character, 4 bot hunters and 3 bot beaters built, the HUD reading
BEATER (`.screenshots/242-1-after-beating.png`).

So the refusal is gone, and with it the sentence that explained it. A party of
one now reads `ASKED FOR ALREADY` like any other party once a size is pressed.

## If it ever comes back

It would need a reason that is not "no bot shoots" -- that one is Karen's to
overrule and she has. `tests/server/lobby.spec.luau` and
`tests/client/shop_panel.spec.luau` both assert the rows are ABSENT, so bringing
the sentence back means reading this file first.
