# BiS Tools — CurseForge page text (0.5.0, first public page)

Paste everything below the line into the project description
(CurseForge → BiS Tools, project 1686340 → Edit → Description), in the Markdown editor.

First public text (12 Oct 2026). Arn: "bis recap and rival first paragraph". In the house voice
(`_bisdev/docs/voice.md`): the opener and "Why it works" talk; tables and lists stay flat.

**Deliberately NOT on the page: summon.** It needs summoning stones, and Forever has none, so the
tool does not even load there. The page is for Forever.

---

# BiS Tools

**What killed you, who to watch for, and what to farm. For WoW Forever.**

You're dead, and you never saw it coming. BiS Tools opens the game's own record of the hits that killed you: who landed the last one, who helped, with what, and how fast. Click a player on that screen and they're your rival. The next time they walk into view, you'll know.

## Death recap

When you die, a small window opens with the last ten hits.

- **The killer in the middle, the two biggest helpers either side.** Their damage, their share, their main spell, the killing blow and how far past zero it went.
- **Your health falling across those seconds**, gold where a hit was a crit.
- **The hits, newest first**, crits and blocks marked, and a total: "306 damage in 6.0 seconds".
- **Players in their class colour.** Mobs are grouped by who they really are. Forever gives a mob a new nickname on every hit; the recap knows it was one Molten Elemental, not three.
- **It closes when you're back in your body.** `/bist recap` opens your last death again. "stop showing this" keeps it from popping up.

## Rivals

Click a player on your recap, or right-click any player and pick **BiS: add rival**. They're gold now: hunted.

- **They walk into view, you hear it.** A warning in the middle of your screen, a sound, and where you are. Once a minute at most.
- **A crosshair on their body**, pinned under their nameplate, pulsing. Eight shapes to pick from - rails, corner brackets, a scope, an ACOG drop, a chevron, a box and more - or none. It needs enemy nameplates on; the options have a button for that.
- **One button targets them.** It sits in the BiS> tools box, shows only while you have a gold rival, and takes a key if you want one.
- **The rivals list**: gold for the ones you're hunting, silver for the ones you're done with, how often they've killed you, and where you last saw them.

Red is for players. Purple is for mobs. You'll never mistake one for the other in a crowd.

## Guild rivals

Right-click a player and pick **BiS: add guild rival**, and every guildmate running BiS Tools learns them. A guild rival wears an **amber** crosshair, so you know the call came from someone else. When anyone sees one, the guild's lists say where, and who saw them. No sound. Switch it off in the options if you'd rather not.

## Guildmates in passing

Out in the world on your own, a guildmate's nameplate gets a small teal **+**. Nothing else: no sound, no text. Join a party, a raid or a battleground and it's gone.

## A thank-you for buffs

A stranger buffs you on the road and you're mid-pull, or just didn't notice. Switch on `/bist social on` and BiS Tools does it for you: a random friendly emote at them, a thank or a hug or a bow. Two to five minutes between emotes, never the same person twice in ten, never in a fight, and your group left alone. It's off until you turn it on.

## Farm

Type a mob's name, or kill one, and the farm window keeps it.

- **The skull, on a fresh copy.** One key press targets a live one nobody else has tagged and marks it.
- **A purple crosshair on every live copy** in view, so you can see the next one coming.
- **Spawn timers.** Where you killed it, and when it's back. On the minimap, on the world map, and as a big arrow pointing at the next one up.
- **RestedXP's targets.** If you run RestedXP, the mobs your guide step wants show in the farm window and wear the purple crosshair too.

## The BiS> tools box

The farm's skull button and the rival button sit together in one small box. Each shows only when it has something to do. With BiS Healing's "BiS> now" on screen, the box docks beside it; drag its header to put it anywhere, shift-click to send it round.

## Settings

Left-click the minimap button for the tools, right-click for the options. Or type:

| command | does |
|---|---|
| `/bist` | the list of tools |
| `/bist recap` | your last death |
| `/bist recap rivals` | your rivals, in chat |
| `/bist recap forget <name>` | drop one |
| `/bist recap key F6` | a key that targets a gold rival - `off` to drop it |
| `/bist recap style scope` | the crosshair: rails, L, aim, box, scope, drop, chevron, tee, none |
| `/bist recap why` | what the tracker last saw, and why it stayed quiet |
| `/bist social on` · `off` · `group` · `why` | the thank-you emote for buffs |
| `/bist farm` | the farm window |
| `/bist farm key F5` | the skull key |
| `/bist farm spots` · `pins on` · `arrow on` · `guide on` | spawn timers, map pins, the arrow, RestedXP's mobs |
| `/bist on <tool>` · `/bist off <tool>` | switch a tool on or off |

## Why it works the way it does

Forever closed the combat log to addons. So this one never asks for it. The death recap is the game's own record, the one Blizzard keeps for its recap screen, and it was read to the last number in a dungeon, mid-fight, before a line of the window was written.

The rest watches nameplates. When one appears, a name is read and compared. That's all. With nobody to watch for, a city full of players costs nothing; with the guildmate + on, it's one more question per nameplate.

When the game won't say, it says so. It does not guess.
