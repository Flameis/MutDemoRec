# MutDemoRec

Server demos for the RypelCam, in one mutator. It records demos on the server and makes them good to watch and film: the gunfire is in them, the sounds the game makes during playback are heard, and the person watching gets a spectator camera with a cinematic mode, speed control, pause, rewind, a smooth camera and camera paths.

## Contents

1. Recording
2. Watching a demo
3. The viewer's keys and commands
4. Recording commands
5. Settings
6. Works with the other mutators
7. What has been checked

## 1. Recording

- **Every round:** with `bRecordRounds` on, the server starts recording a demo when a round starts and stops when it ends. Each demo is named after the map, the date and the time, for example `DR_VNTE-Hue_2026-10-26_19-04-31`. Everyone is told when a recording starts and stops.
- **By hand:** anyone can start and stop a recording at any time (`demorec`, `demostop`), or only admins with `bAdminOnlyCommands` on. A recording started by hand isn't stopped by the end of a round.
- The demos are saved on the server, in its `Demos` folder. Play one back in the game with `demoplay <name>` in the console. To play a demo, your game needs the same version of every mod the server had when it was recorded.

## 2. Watching a demo

When the server records a demo, MutDemoRec puts a small link into it. Only the demo gets it, so it adds nothing to what players on the server receive. When the demo is played back:

- **Gunfire:** every gunshot is heard where it was fired, and the sound at the end of a burst of automatic fire. Without this a played-back demo has no gunshots at all: the game sends them to a hidden camera the demo is recorded from, and doesn't bring that camera back when a demo plays.
- **A spectator camera:** you watch through a camera that works like the game's own spectator (fire and alt fire for the next and previous player, iron sights for the camera mode, and so on; see the keys below). It starts on the first player it finds, in third person.
- **Sounds the playback makes itself:** explosions, artillery, bullet impacts and other sounds the game plays on your own computer are heard. Without the spectator camera they aren't: the game gives a demo's viewer no proper player controller to hear them through.
- **Ambient sound:** the map's background sound (wind, birds, distant noise) is started a moment into the demo.
- **MutCMenu's spectator view:** with MutCMenu on the server, its spectator view comes with the demo too: every player on the map, the triangles over players, tracers and the rest.
- **Real speed:** the demo plays at the speed it happened. Without this, demos play several times too fast: the game shows one recorded moment of a demo for every frame your PC draws, and a demo only has one moment for each server update (20 a second on the 29th's servers). A PC drawing 125 frames a second played them about 6 times too fast. MutDemoRec holds each moment back until it is due, and keeps the animations in step. Players and effects move in steps of those recorded moments, but the camera stays as smooth as your frame rate (see "The server's update rate and demos" in section 5).
- **Sprinting:** players who sprint are shown sprinting. The game never puts sprinting into a demo, so on playback sprinting players were shown running.
- **Cinematic mode:** everything on screen off (the game's HUD, MutCMenu's view and the demo's own line of text), for filming.
- **Speed and pause:** slower, faster or paused. The camera keeps moving at its own speed whatever the demo does, so you can look around a paused moment. The fastest a demo can go is one recorded moment per frame your PC draws (about 6 times on a 20-update server at 125 frames a second).
- **Skip and rewind:** forward or back 10 seconds, or straight to a time. Going back starts the demo again and goes quickly to the time (the screen is dark meanwhile); the speed, cinematic mode, smooth camera and camera path carry over. Only demos recorded by MutDemoRec can be rewound (it needs the demo's name).
- **Smooth camera:** the view eases after where the camera is, so moving the camera and switching players become smooth swoops instead of jumps.
- **Camera paths:** set points where the camera is, then fly a smooth curve through them, as slowly or quickly as you like. At the end you are left in free roam where the path ended. The points are kept until you clear them.

A line at the bottom left shows the demo's time, speed, and what is on. It isn't shown in cinematic mode.

## 3. The viewer's keys and commands

| Key | Console command | What it does |
| :--- | :--- | :--- |
| Fire | | Next player |
| Alt fire | | Previous player |
| Iron sights | | Next camera mode: free camera around the player, third person, first person, the map's cameras, free roam |
| Quick grenade | | Free roam |
| Mouse wheel | | Free roam camera speed |
| H | `democinematic` | Cinematic mode on or off |
| P | `demopause` | Pause or carry on |
| [ and ] | `demoslower`, `demofaster` | Slower or faster (0.1, 0.25, 0.5, 1, 2, 4, 8 times) |
| \ | `demospeed 1` | Normal (real) speed. `demospeed 0.3` sets any speed from 0.1 to 8 |
| Left and Right arrows | `demoskip -10`, `demoskip 10` | Back or forward 10 seconds |
| | `demoseek 2:30` | Go to 2 minutes 30 into the demo (or `demoseek 150`) |
| O | `demosmooth` | Smooth camera on or off. `demosmooth 5` turns it on and sets how quickly it catches up (higher is quicker; 3 if never set) |
| K | `demopathadd` | Add a camera path point where the camera is |
| L | `demopathplay` | Fly the camera path (again to stop) |
| J | `demopathclear` | Clear the camera path |
| | `demopathtime 2` | Seconds from one path point to the next (3 if never set) |
| F1 | | Show or hide the list of keys |

The keys can be changed in `MutDemoRec_Client.ini` (in your game's `Config` folder), under `[MutDemoRec.DRViewerInput]`: `CinematicKey`, `PauseKey`, `SlowerKey`, `FasterKey`, `NormalSpeedKey`, `RewindKey`, `SkipKey`, `SmoothKey`, `PathAddKey`, `PathPlayKey`, `PathClearKey`, `HelpKey`, and `SkipSeconds` for how far the rewind and skip keys go. The same file keeps the smooth camera, the camera path and a rewind under way.

## 4. Recording commands

Anyone can use these. With `bAdminOnlyCommands` on, only admins can (logged in as admin, or the host of a listen server).

| Command | What it does |
| :--- | :--- |
| `mutate demorec` | Starts recording a demo, named after the map, date and time |
| `mutate demorec [NAME]` | Starts recording under that name (letters, numbers, `-` and `_`; anything else becomes `_`). `--name` or `-n` before the name works too |
| `mutate demostop` | Stops the recording |
| `mutate demostatus` | Says whether a demo is being recorded, and how many gunshots have been put into it |

## 5. Settings

Set in WebAdmin under **Mutators > MutDemoRec Settings**, or in `MutDemoRec_Server.ini`. The page has two tabs, **Recording** and **Playback**. The labels come from `Localization\INT\MutDemoRec.int`, which a server needs next to the mod.

| Setting | What it does |
| :--- | :--- |
| `bRecordRounds` | Record a demo of every round (off unless turned on) |
| `bAdminOnlyCommands` | Only admins can use `demorec`, `demostop` and `demostatus` (off: anyone can) |
| `bDisableDemoGunfire` | Leave the gunfire out of demos. On the page: "Put the gunfire into demos", which is On unless this is set |
| `bDisableDemoViewer` | No spectator camera when a demo is played back (and so none of its controls). On the page: "Spectator camera when a demo is played back", On unless this is set |
| `bDisableDemoAmbient` | Don't start the map's ambient sound when a demo is played back. On the page: "Start the map's ambient sound...", On unless this is set |

### The server's update rate and demos

A demo records one moment each time the server updates the game, and never more than its own limit. Both are set in the server's `ROEngine.ini`, not by MutDemoRec:

| Section | Setting | 29th servers | What it does |
| :--- | :--- | :--- | :--- |
| `[IpDrv.TcpNetDriver]` | `NetServerMaxTickRate` | 20 | How many times a second the server updates the game (`LanServerMaxTickRate`: on a LAN) |
| `[Engine.DemoRecDriver]` | `NetServerMaxTickRate` | 30 | The most moments a second a demo records |

At 20 updates a second, players in a demo move in 20 steps a second. A higher update rate makes demos smoother (the demo limit has to be raised with it, to 60 for a 60-update server). It also makes the server do more work and send more to every player, so it is a decision for the server, not something MutDemoRec changes. The playback speed is right either way.

## 6. Works with the other mutators

- **MutCMenu:** gives the demo camera its spectator view, so it is in the demo.
- **MutRealismMatch:** its respawn, round restart and weapon safety commands leave the demo camera alone, so they don't reset it inside the demo.

## 7. What has been checked

The test harness recorded demos on a listen server with a rifle firing, played them back in the game and checked them:
- Each shot was heard once.
- Without the gunfire setting, shots out of the hidden camera's earshot were silent.
- The demo was watched through the spectator camera.
- A sound played the way explosions and artillery are played was heard.
- MutCMenu's spectator view was on.
- Normal speed played the demo at the real speed (it had played 4 times too fast), half speed at half, and the animations' clock kept in step.
- A player marked sprinting in the demo was shown sprinting, and back.
- Speed, pause, cinematic mode, the camera path, the smooth camera, skipping forward and rewinding each worked.

*Not yet checked:*
- By someone watching. How the camera keys feel and how things look on screen can't be checked by the tests.
- How the sound plays while the demo is held back between moments. The real speed uses the game's pause, and whether that makes sounds choppy can only be heard.
- A real player sprinting in a demo (the test marks its player as sprinting; it can't make it run).
- `bAdminOnlyCommands` turning away someone who isn't an admin. The test for it needs a player who isn't an admin, and in the single player test game everyone is.
- Together with the RypelCam.
- With a demo recorded on a dedicated server. Demos from the test dedicated server don't play back properly on the test PC, which is a separate problem.
