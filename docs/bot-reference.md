# MiniKillingBlow reference

## What it does

Plays a sound when you land a killing blow on an enemy player. NPC kills do not
trigger it. Consecutive kills within 10 seconds form a streak, and most sound packs
escalate through different sounds as the streak grows. Optionally shows a large red
"KILLING BLOW!" text on screen as well.

## Facts

| Item | Value |
| --- | --- |
| Version | 2.4.6 |
| Author | Verz |
| Interface versions (TOC) | 120100, 50504, 40402, 38002, 38000, 30405, 30300, 20506, 11509 |
| Saved variables | MiniKillingBlowDB |
| Slash commands | /minikillingblow, /minikb, /mkb (all open the settings panel) |
| Options location | Game options -> AddOns -> MiniKillingBlow |
| Bundled libraries | MiniFramework only |
| External dependencies | None (a Custom sound pack uses a user-created folder, see below) |

## Features

### Kill detection

- Listens for the PARTY_KILL combat event. The kill counts only when the killer is
  you and the victim is a player character (GUID starts with "Player-"). Kills by
  your pet have a different killer GUID and do not trigger the sound.
- On pre-Midnight clients this comes from COMBAT_LOG_EVENT_UNFILTERED. On Midnight
  (12.x) clients the direct PARTY_KILL event is used instead.
- Midnight arena/battleground workaround: when the client hides combat log GUIDs
  behind secret values, the addon cannot read who killed whom. Inside arena or
  battleground instances it falls back to checking whether your "Total Killing
  Blows" statistic (achievement criteria 1487, Achievement -> Statistics) went up,
  and triggers on that. Outside arena/BG instances, secret GUIDs are skipped and no
  sound plays.

### Kill streaks

- Killing blows within 10 seconds of each other increment a streak counter. The
  streak resets after 10 seconds without a kill.
- The streak picks the sound file: Unreal Tournament has 7 escalating sounds (stays
  at 7 beyond that), Halo has 10, Guns cycles through 4 gun shots repeatedly, One
  Gun always plays its single sound, Custom escalates up to your configured file
  count. Changing the sound pack resets the streak counter.

### Killing blow text

- Off by default. When enabled, shows "KILLING BLOW!" (customizable) in large red
  38 pt text with a dark red shadow, centered on screen offset by a saved X/Y
  (default 0, 100, i.e. above center).
- The text fades in (0.12 s), holds (1.8 s), and fades out (0.6 s).
- When "Locked" is unchecked the text stays permanently on screen and can be
  dragged to reposition it; re-check Locked when done. There is no numeric X/Y
  input in the UI.

### Custom sound pack

Instructions as shown in the options panel:

1. Create a folder called "MiniKillingBlowCustomSounds" in your AddOns folder.
2. Put sound files in ogg format named 1.ogg, 2.ogg, etc. in that folder.
3. Choose the "Custom" sound pack.
4. Enter the number of files in the "Custom sound effect count" box.
5. /reload, then click Test to verify.

Files play in streak order (1.ogg for the first kill, 2.ogg for the second, ...)
capped at the configured count.

## Settings

Single options panel. Panel description reads "Increase your PvP immersion."

| Setting | Type | Default | Range / options | Notes |
| --- | --- | --- | --- | --- |
| Sound Pack | dropdown | Unreal Tournament | Unreal Tournament, Halo, One Gun, Guns, Custom | Changing it resets the current streak. |
| Custom sound effect count | numeric edit box | 5 | 1-50 | Only visible when Sound Pack is Custom. Number of N.ogg files in the custom folder. |
| Sound Channel | dropdown | SFX | Master, Music, SFX, Ambience, Dialog | Which audio channel the sound plays on. |
| Test | button | - | - | Plays the sound (and text, if enabled) as if a killing blow happened. Also advances the streak counter. |
| Locked | checkbox | on | - | Unchecked: the killing blow text stays visible and can be dragged to reposition it. |
| Show killing blow text | checkbox | off | - | Enables the on-screen text. |
| Killing blow text | edit box | "KILLING BLOW!" | - | Empty text reverts to the default. |

There is no reset-to-defaults button; settings live in MiniKillingBlowDB.

## Version-gated behavior

- Pre-Midnight clients: kill detection via the combat log.
- Midnight (12.x) clients: direct PARTY_KILL event; when GUIDs are secret, the
  achievement-statistic fallback works only inside arenas and battlegrounds.
- On Midnight clients the settings panel cannot be opened during combat; the slash
  command prints "Can't do that during combat." instead.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| No sound on a killing blow | The victim must be an enemy player, and the killing blow must be yours (pet kills do not count). Also check the Sound Channel setting: the chosen channel (default SFX) must not be muted or at zero volume in the game's sound options. |
| No sound in world PvP on Midnight | Known limitation: with secret combat log GUIDs the workaround only functions inside arena and battleground instances. |
| Sound plays for NPC kills | Should not happen: victims must have a player GUID. On Midnight in arena/BG the fallback uses the "Total Killing Blows" statistic, which itself tracks killing blows. |
| Custom sounds do not play | Folder must be exactly "MiniKillingBlowCustomSounds" inside AddOns, files named 1.ogg, 2.ogg, ... in ogg format, the count field must match, and a /reload is needed after adding files. Use the Test button to check. |
| The killing blow text never shows | "Show killing blow text" is off by default; enable it in the options. |
| Text stuck permanently on screen | "Locked" is unchecked, which intentionally keeps the text visible for repositioning. Re-check Locked. |
| Cannot move the text | Untick "Locked" (with "Show killing blow text" enabled) and drag it, then lock again. |
| Same sound repeats instead of escalating | Streaks require kills within 10 seconds of each other; the counter resets after 10 idle seconds. The Guns pack intentionally cycles 4 sounds, and One Gun has a single sound. |
