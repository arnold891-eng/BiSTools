## 0.3.0

- **Minimap button** (Arn: "the / commands are so convoluted between all the addons"). Left
  click: the **Hub** - every tool on one list; click a row to open its window (shift-click
  drags the window to the middle of the screen - "I have no idea where the farm window is
  at"), right-click a row to switch the tool on/off. Right click on the button: **Options** -
  on/off per tool, farm find-sound / spot radius / burst / prune, summon window mode / nag /
  Summoner / interact key / at-stone yards / rows / linger, the minimap button itself, the BiS
  channel switch, and "reset window positions". Drag the button around the minimap rim.
  `/bt hub`, `/bt options`, `/bt minimap` are the slash fallbacks.

- Fix: "SUMMON from someone" raid warning when somebody ELSE got summoned. The client fires
  `CONFIRM_SUMMON` on bystanders too, with no summoner, area or clock; the nag took it as an
  offer and the lib announced a phantom OFFER to every summoner. LibBiSComm minor 5 asks the
  client whether a summon is really pending (`HasPendingSummon`) and both now stay quiet.

- Drift guard: `release.ps1` refuses to zip if an embedded lib differs from its canonical
  copy; the harness asserts the same bytes; `_bisdev\sync.ps1` pushes the canonical libs into
  every addon. A phantom OFFER from a peer still on an older lib is ignored on this side too.

## 0.2.0

- **LibBiSComm** embedded (`Libs/LibBiSComm-1.0`): the shared BiS raid channel. Just having
  BiSTools installed makes you answer "where are you" and "did the summon go through" to any
  BiS summoner, with nothing to configure. `/biscomm` shows status; `/biscomm off` is the only mute
  and is remembered across sessions.
- `summon` tool: SummonScan folded in. `/bt summon` pins the window, auto mode brings it up
  when you mouse over a summoning stone. Furthest first; click a name to target, right-click
  to skip, shift-drag to move. Raid members with any BiS addon are shown as fact (they say
  where they are and whether they accepted); everyone else is a guess with a `?`. A decline
  pops the name back to the top the second it happens.
- Summon nag: when someone summons YOU, a raid-warning line, the raid-warning sound and a
  voice line, every 20 s until you answer. Works even with the summon tool switched off;
  `/bt summon nag off` is its switch.
- **Request a summon**: the button at the bottom of the summon window (or `/bt summon me`)
  puts you on top of every BiS summoner's list marked `asks`, with a ping on their side.
  Click again to cancel; clears itself when an offer reaches you.
- Summoning stones are learned, not looked up: hover one (or a peer lands on one after
  accepting) and its position is saved and shared with the raid. "At the stone" is then a
  distance to the stone, wherever the summoner stands; the header shows `N at stone`.
- **Summoner mode** (`J` on the header, `/bt summon summoner`): you are the summoner tonight - window
  pinned, every request reaches you as a raid warning + sound + voice, wherever you are.
- Summon list order: whoever asked, then the other world (Azeroth/Outland, named in the row),
  then same world other zone (`far`), then same zone by yards, furthest first. People inside
  an instance, at the stone or next to you are hidden; `all` on the footer unrolls the whole
  raid with `inside` / `here`.
- Yards in the summon list only show while you stand at (or look at) a stone - then they are
  yards from the stone. Away from it a same-zone name shows nothing, another zone `far`.
  Raid members already inside an instance are listed last as `inside`.
- LibBiSComm minor 2: WHERE now carries the map id outdoors too, so a peer standing next to
  you no longer reads as `far`. Tools also falls back to what the client can see for peers
  still on minor 1.
- **Spam the key**: stand at the stone, mouse on the summon window, press Interact With
  Target: first press targets the top name, next press is the real interact - the stone. The
  top changes, the key targets the next one. `/bt summon key off` to disable.
- Positions stay fresh: stepping on or off a known stone pushes your position to the raid,
  and an open summon window re-asks when a name's position is older than 30 s.
- Two people at a stone: the summon window opens on every BiSTools client in the raid. Far
  from the stone it is compact - `N at the stone` and the request button; `all` unrolls the
  list. At the stone you get the full list.
- The summon window talks like a shell, in its header: the title is a `BiS> _` prompt with a
  blinking cursor that cycles what matters - `Summon`, `2 at stone` (green, you counted),
  `1 asking`, `requesting...`, `summon incoming` - and says events over it for a few seconds:
  `X asks`, `X accepted`, `X declined`, `request now`, `no summons`. Nothing of that goes to
  chat any more. The prompt is `BiSTheme.Console`, shared by every BiS window from here on
  (a copy ships in `Libs/BiSTheme/Console.lua`, so it works without BiSTheme installed).
- LibBiSComm minor 3: a client no longer listens to its own echo. The game hands every group
  addon message back to the sender; minor 2 took it and made you your own peer, so a summoner
  at the stone counted himself twice (`2 at stone` with one person there) and a requester saw
  his own `1 asking`. `N asking` now shows only to summoners (at a stone, or Summoner mode).
- 25-man rehearsal (`_bisdev/comm/raid25.lua`, 41 checks; Tools harness gained a 25-man block):
  forming a raid is one HI per client; a zone line is one WHERE and never a HI; a roster tick
  that changes nobody costs nothing; only the man who joined says HI and only the people he is
  short of answer him (minor 2 had 8 people zoning into Karazhan turn into 30 HIs and every
  promote into 22); a throttled answer now waits instead of being dropped (a reload right
  after a join lost a third of the raid). Whole simulated night: ~140 messages, ~4 KB.
- **RezComm** embedded (`Libs/RezComm-1.0`, byte-identical to `_bisdev`): a BiSTools priest,
  paladin or shaman now puts rez claims on BiSInnervate's wire (`4|RCLAIM|name`, `RFREE`, `RDONE`
  on prefix `BiSInn`) the instant the cast starts, so an Innervate raid coordinates around them
  without them running Innervate. Announce-only, no rez code in Tools, stands down when Innervate
  is installed. Rebirth excluded on purpose.
- LibBiSComm minor 4: the lib's slash is `/biscomm` (`/bis` belongs to LoonBestInSlot).
- House standard: version read from the TOC (the lib announces the real one); the harness loads
  exactly what the TOC lists, in TOC order; no toggle can gate the comm lib (every one is
  flipped in the suite); `dev/theme.lua` runs the suite with a poisoned accent and caught two
  hardcoded purples in the farm titles - now `T.text("accent", ...)` like everything else.
- Pin button dropped: the window opens itself when summons are available; `/bt summon
  show|auto|hide` is the manual way. Logo dropped too - the prompt is the brand.
- Summon window header drags without shift now.
- `/bt summon peers` lists who the channel can see. `/bt summon testaccept` is a live probe
  for whether an addon may accept a summon without a click.

## 0.1.0

- `farm` (Target Farming): small Innervate-style window showing your last kill. Click it once and a 0.5s scanner
  marks every free copy nearby: the nameplate scanner deals star..cross (1-7) one per mob and
  respects marks already on them, skull is for whatever you mouse over (works from the air, never overwrites a mark);
  skips dead / in-combat / tapped. Click
  again to stop. Type any mob name in the box to farm that instead. `/bt farm key <KEY>` binds a key that
  targets the skulled mob. Voice line (FojjiCore pack or client TTS) on the first find, whisper
  ping after; `/bt farm sound first|always|off`. `/bt farm` toggles, `/bt farm clear`, `/bt farm add <name>`.
- `farm` lock: once you are farming a mob, kills of anything else do not swap the row; the
  farmed mob keeps counting. Click it again to unlock and the last-kill tracker resumes.
- `farm` spawn timers, two levels: a **zone** is where a cluster lives (radius = the option,
  default 20 yd, `/bt farm radius 5-60`) and owns one raid mark for good from the first kill
  there. Its **spots** (radius 35% of the zone) sit indented under it on the shelf; each gets a
  mark while you are in the zone - the zone's own first, then marks no zone owns - and gives
  it back when you leave. Skull is never used; it is the cursor's. A kill is matched by the
  mark the mob died wearing first, then by distance, then to the nearest zone with a spot that
  is up. Kills within 60 s of each other at one spot (`/bt farm burst 5-300`) are
  different mobs and get their own spots, as is a kill on a spot still counting down. Up to 16
  zones and 12 spots each; past 7 marks they show as numbers. A spot that sits up for 10 min
  with no kill folds into its neighbour (`/bt farm prune 60-3600|off`). A second kill at a spot teaches its respawn; 15 s before it is due the mark is called
  out. `t` on the header (or `/bt farm spots`) opens the shelf: arrow from where you stand,
  mark, countdown, yards; a zone's timer is its soonest spot; the zone you stand in is tinted. `r` resets this mob; `/bt farm
  spots clear` wipes every mob.
- Skeleton: tool registry, `/bt` dispatcher, per-tool saved settings, BiSTheme palette with fallback.
