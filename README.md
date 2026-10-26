# MutDemoRec

Demo recording for the RypelCam, as one mutator that needs no other. It records server demos, and makes them better to watch: the gunfire is in them, the sounds the game makes during playback are heard, and the person watching gets a spectator camera like the game's own.

The same things are also in MutRealismMatch (recording) and MutExtras (gunfire, spectator camera, ambient sound), so you can try both ways and keep the one you like. Use one or the other: with MutDemoRec on the server, MutExtras leaves the demo work to it.

## Contents

1. What it does
2. Commands
3. Settings
4. Works with the other mutators
5. What has been checked

## 1. What it does

**Recording**
- **Every round:** with `bRecordRounds` on, the server starts recording a demo when a round starts and stops when it ends. Each demo is named after the map, the date and the time, for example `DR_VNTE-Hue_2026-10-26_19-04-31`. Everyone is told when a recording starts and stops.
- **By hand:** admins can start and stop a recording at any time (`demorec`, `demostop`). A recording started by hand isn't stopped by the end of a round.
- The demos are saved on the server, in its `Demos` folder. Play one back in the game with `demoplay <name>` in the console. To play a demo, your game needs the same version of every mod the server had when it was recorded.

**Watching a demo**

When the server records a demo, MutDemoRec puts a small link into it. Only the demo gets it, so it adds nothing to what players on the server receive. When the demo is played back:

- **Gunfire:** every gunshot is heard where it was fired, and the sound at the end of a burst of automatic fire. Without this a played-back demo has no gunshots at all: the game sends them to a hidden camera the demo is recorded from, and the game doesn't bring that camera back when a demo plays.
- **Spectator camera:** you watch through a spectator camera that works like the game's own spectator:

  | Key | What it does |
  | :--- | :--- |
  | Fire | Next player |
  | Alt fire | Previous player |
  | Iron sights | Next camera mode: free camera around the player, third person, first person, the map's cameras, free roam |
  | Quick grenade | Free roam |
  | Mouse wheel | Free roam camera speed |

  It starts on the first player it finds, in third person. *Not yet tried with the RypelCam installed.*
- **Sounds the playback makes itself:** explosions, artillery, bullet impacts and other sounds the game plays on your own computer are heard. Without the spectator camera they aren't: the game gives a demo's viewer no proper player controller to hear them through.
- **Ambient sound:** the map's background sound (wind, birds, distant noise) is started a moment into the demo.
- **MutCMenu's spectator view:** with MutCMenu on the server, its spectator view comes with the demo too: every player on the map, the triangles over players, tracers and the rest (see the MutCMenu README).

## 2. Commands

Admins only (logged in as admin, or the host of a listen server). With MutRealismMatch on the server, use its demo commands instead: they are the same, and MutDemoRec leaves them to it.

| Command | What it does |
| :--- | :--- |
| `mutate demorec` | Starts recording a demo, named after the map, date and time |
| `mutate demorec [NAME]` | Starts recording under that name (letters, numbers, `-` and `_`; anything else becomes `_`). `--name` or `-n` before the name works too |
| `mutate demostop` | Stops the recording |
| `mutate demostatus` | Says whether a demo is being recorded, and how many gunshots have been put into it |

## 3. Settings

Set in WebAdmin under **Mutators > MutDemoRec Settings**, or in `MutDemoRec_Server.ini`. The page has two tabs, **Recording** and **Playback**. The labels come from `Localization\INT\MutDemoRec.int`, which a server needs next to the mod.

| Setting | What it does |
| :--- | :--- |
| `bRecordRounds` | Record a demo of every round (off unless turned on) |
| `bDisableDemoGunfire` | Leave the gunfire out of demos. On the page: "Put the gunfire into demos", which is On unless this is set |
| `bDisableDemoViewer` | No spectator camera when a demo is played back. On the page: "Spectator camera when a demo is played back", On unless this is set |
| `bDisableDemoAmbient` | Don't start the map's ambient sound when a demo is played back. On the page: "Start the map's ambient sound...", On unless this is set |

## 4. Works with the other mutators

- **MutRealismMatch:** keeps its own recording (`bRecordDemos` records every LIVE round) and its demo commands. Turn on only one of `bRecordRounds` and `bRecordDemos`; if both are on, whichever starts first records.
- **MutExtras:** has the same gunfire, spectator camera and ambient sound settings. With MutDemoRec on the server it leaves all of that to MutDemoRec.
- **MutCMenu:** gives the demo camera its spectator view, whichever of MutDemoRec or MutExtras does the demo work.

## 5. What has been checked

The test harness recorded demos on a listen server with a rifle firing, played them back in the game and checked them:
- Each shot was heard once.
- Without the gunfire setting, shots out of the hidden camera's earshot were silent.
- The demo was watched through the spectator camera.
- A sound played the way explosions and artillery are played was heard.
- MutCMenu's spectator view was on.

*Not yet checked:*
- By someone watching. How the camera keys feel and how CMenu's view looks on screen can't be checked by the tests.
- Together with the RypelCam.
- With a demo recorded on a dedicated server. Demos from the test dedicated server don't play back properly on the test PC, which is a separate problem.
