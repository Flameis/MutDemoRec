// The spectator camera for watching a demo (made by DRDemoLink when a demo is played back, never on a server).
//
// When a demo plays, the game never brings back the demo camera it was recorded from, and gives the viewer's player a
// bare controller that isn't properly the local player's. So there is no spectating, and the sounds the playback
// makes itself (explosions, artillery, impacts) have no one to hear them. This takes over the local player instead,
// the way the game's debug camera does (SwitchController), so it is the local player's camera and listener.
//
// It is the game's demo camera (DemoRecSpectator), with the controls of the game's own spectator (fire / alt fire: next
// and previous player, iron sights: camera mode, quick grenade: free roam, mouse wheel: free roam speed), and more for
// watching and filming (the keys are DRViewerInput's; each is also a console command):
//  - Cinematic mode: the game's HUD, MutCMenu's view and this camera's own text all off (democinematic).
//  - Speed: slower, faster, normal, pause (demospeed, demoslower, demofaster, demopause). The camera keeps moving at
//    its own speed, also while paused. "Normal" is the real speed. The game reads one recorded moment of a demo for
//    every frame it draws, whatever its demo speed (DemoPlayTimeDilation only sets the game's clock), and a demo has
//    a moment for each server update (20 a second on the 29th's servers, 30 at most): played on a PC drawing 125
//    frames a second, it went 4 to 6 times too fast. So each frame the demo is held (the game's pause) until its next
//    moment is due on the real clock, by the server's clock in it (DRDemoLink.ServerTime); and the game's clock, which
//    the animations go by, is set to keep up with the server's (UpdatePacing, UpdateClock). Holding the demo pauses the
//    game on most frames, which may make shadows flicker; the other way (demopacing, bLimitFrameRate) limits the frame
//    rate to the demo's own moments a second instead (DRFrameLimiter), so the camera goes at that rate too.
//  - Skip forward and rewind (demoskip, demoseek). Rewinding starts the demo again and goes quickly to the time (the
//    engine's own demo rewind is switched off in RS2). What carries over the restart is kept in MutDemoRec_Client.ini.
//  - Smooth camera: the view eases after where it should be, so moves and switching players are smooth (demosmooth).
//  - Camera paths: points set where the camera is, then a smooth flight through them (demopathadd, demopathplay,
//    demopathclear, demopathtime).
// MutCMenu's spectator view comes with it when MutCMenu is on the server (its info for the demo camera is in the demo).
class DRDemoViewer extends DemoRecSpectator
    config(MutDemoRec_Client);

var PlayerController    PlaybackController;     // The controller the playback gave the player (kept: it may need it)
var string              DemoName;               // The demo being watched, when MutDemoRec recorded it (for rewinding)
var DRDemoLink          Link;                   // What MutDemoRec put into the demo
var DRViewerInput       ViewerInput;

// ---- Watching and filming
var bool                bCinematic;
var array<Interaction>  HiddenInteractions;     // MutCMenu's view, while in cinematic mode
var float               Speed;                  // How fast the demo plays (1 normal)
var bool                bPaused;
var bool                bSeeking;               // Going quickly to SeekTarget
var float               SeekTarget;
var bool                bSeekForRewind;         // The seek after a restart for a rewind (the screen is dark meanwhile)
var vector              SmoothLoc;
var rotator             SmoothRot;
var bool                bSmoothStarted;
var float               LastViewTime;
var bool                bPathPlaying;
var float               PathStart;
var vector              PathLoc;
var rotator             PathRot;
// Playing at the real speed (UpdatePacing, UpdateClock)
var bool                bPaceSet;
var float               PaceServer, PaceReal;   // The server's clock in the demo at a real time: the pace from there
var bool                bHeld;                  // Held back this frame (its next moment isn't due yet)
var float               TimeScale;              // How fast the game's clock goes, so it keeps up with the demo's
var bool                bClockSampled, bClockSet;
var float               ClockServer, ClockWorld, ClockReal;
var float               LastRealTime, RealStep; // Real seconds this frame
// The frame rate way (bLimitFrameRate)
var DRFrameLimiter      Limiter;
var float               MomentsPerSecond;       // The demo's recorded moments per second of it (measured; 30 at first)
var float               LimitScale;             // A correction to the limit, from how fast the demo really went
var bool                bRateSampled;
var int                 RateFrame;
var float               RateServer, RateReal;

var config bool         bSmoothCamera;          // Ease the view (remembered)
var config float        SmoothSpeed;            // How quickly the smooth camera catches up (higher: quicker; 0: 3)
var config float        PathPointSeconds;       // How long a camera path takes from one point to the next (0: 3)
var config bool         bLimitFrameRate;        // Real speed by limiting the frame rate, not by holding the demo (remembered)
var config array<vector>  PathPoints;           // The camera path (kept, so it is there again after a rewind)
var config array<rotator> PathRotations;
// A rewind under way: the demo is started again, then goes quickly to ResumeTime
var config string       ResumeDemo;
var config float        ResumeTime;
var config float        ResumeSpeed;
var config bool         bResumeCinematic;
var config float        ResumeTimeScale;        // and the game's clock speed it had found (UpdateClock)

const MIN_SPEED = 0.1;
const MAX_SPEED = 8.0; // (as fast as one moment a frame goes, at most)

// Called on the playback by DRDemoLink. Returns true once the local player has a viewer (made now, or already)
static function bool TakeOverLocalPlayer(Actor Maker)
{
    local Engine E;
    local LocalPlayer LP;
    local PlayerController Old;
    local DRDemoViewer Viewer;

    E = class'Engine'.static.GetEngine();
    if (E == None || E.GamePlayers.Length == 0)
        return false;
    LP = E.GamePlayers[0];
    if (LP == None || LP.Actor == None)
        return false;
    if (DemoRecSpectator(LP.Actor) != None) // ours, or another mod's demo camera already took over
        return true;

    Old = LP.Actor;
    Viewer = Maker.Spawn(default.Class,,, Old.Location, Old.Rotation);
    if (Viewer == None)
        return false;
    Viewer.Link = DRDemoLink(Maker);
    if (Viewer.Link != None)
        Viewer.DemoName = Viewer.Link.DemoName;
    Viewer.TakeOver(LP, Old);
    return true;
}

simulated event PreBeginPlay()
{
    super.PreBeginPlay();
    // Made on the playback, where there is no game to give it player info; its spectator state needs some
    if (PlayerReplicationInfo == None)
        InitPlayerReplicationInfo();
}

// A spectator's player info, made here
function InitPlayerReplicationInfo()
{
    PlayerReplicationInfo = Spawn(class'ROPlayerReplicationInfo', self,, vect(0,0,0), rot(0,0,0));
    if (PlayerReplicationInfo == None)
        return;
    PlayerReplicationInfo.PlayerName = "Demo camera";
    PlayerReplicationInfo.bIsSpectator = true;
    PlayerReplicationInfo.bOnlySpectator = true;
    PlayerReplicationInfo.bOutOfLives = true;
    PlayerReplicationInfo.bWaitingPlayer = false;
}

function TakeOver(LocalPlayer LP, PlayerController Old)
{
    local class<HUD> HUDClass;

    PlaybackController = Old;
    // The playback's controller is left with a voice chat callback, which only the local player's controller has
    // cleared when the map ends; left there, the map can't be unloaded when the demo ends (and the game stops)
    if (ROPlayerController(Old) != None && Old.OnlineSub != None && Old.OnlineSub.VoiceInterface != None)
        Old.OnlineSub.VoiceInterface.ClearPlayerTalkingDelegate(ROPlayerController(Old).OnPlayerTalking);
    LP.SwitchController(self);
    if (PlayerCamera == None)
        SpawnPlayerCamera();
    if (myHUD == None && WorldInfo.GRI != None && WorldInfo.GRI.GameClass != None)
    {
        HUDClass = WorldInfo.GRI.GameClass.default.HUDType;
        if (HUDClass != None)
            ClientSetHUD(HUDClass);
    }
    bFindPlayer = true;
    InitLocalSpectating();

    ViewerInput = new(self) class'DRViewerInput';
    ViewerInput.Viewer = self;
    ViewerInput.OnReceivedNativeInputKey = ViewerInput.InputKey;
    Interactions.Insert(0, 1);
    Interactions[0] = ViewerInput;

    Speed = 1.0;
    TimeScale = 1.0;
    ResumeRewind();
    `log("[MutDemoRec] demo playback: "$self$" is the viewer (was "$Old$"), demo "$((DemoName != "") ? DemoName : "(name not known)"));
}

// ====================================================
// The game's spectator controls, in a demo (where there is no server to ask)
// ====================================================

// Back through the players (the reverse of DemoViewNextPlayer)
function DemoViewPrevPlayer()
{
    local Pawn P, Prev, Last;

    Prev = None;
    Last = None;
    foreach WorldInfo.AllPawns(class'Pawn', P)
    {
        if (P.PlayerReplicationInfo == None)
            continue;
        if (RealViewTarget == P.PlayerReplicationInfo || ViewTarget == P)
            Prev = Last;
        Last = P;
    }
    if (Prev == None)
        Prev = Last;
    if (Prev != None)
        SetViewTarget(Prev);
}

unreliable server function ServerViewPrevTarget()
{
    switch (CurrentSpectateMode)
    {
    case SMODE_PawnFreeCam:
    case SMODE_PawnThirdPerson:
    case SMODE_PawnFirstPerson:
        DemoViewPrevPlayer();
        break;
    case SMODE_Viewpoint:
        ViewMapViewpoint(-1);
        break;
    }
    if (CurrentSpectateMode == SMODE_PawnFirstPerson && ROVehicleBase(ViewTarget) != None)
    {
        CurrentSpectateMode = SMODE_PawnThirdPerson;
        ClientSetCameraMode('ThirdPerson');
    }
}

// Free roam (the game's checks are on its server, which a demo doesn't have)
reliable server function ServerSetRoamingSpectate()
{
    CurrentSpectateMode = SMODE_Roaming;
    MyRealViewTarget = None;
    RealViewTarget = None;
    bFindPlayer = false;
    ServerViewSelf();
    SetCameraMode('FirstPerson');
}

// ====================================================
// Watching and filming
// ====================================================

function Say(string Msg)
{
    ClientMessage("[Demo] "$Msg);
}

// The demo's own time: the server's clock in it, from when the recording began (else the playback's level time, which
// runs with the demo but at the recorded speed). It stops while paused
function float DemoTime()
{
    if (Link != None && Link.DemoSeconds() >= 0)
        return Link.DemoSeconds();
    return WorldInfo.TimeSeconds;
}

// Every frame: the demo goes on to its next moment only once that is due at the chosen speed, by the server's clock in
// it against the real clock (else it is held for this frame). A demo that can't keep up (faster than one moment a
// frame) goes as fast as it can, without saving up the time. Skipping goes as fast as it can
function UpdatePacing()
{
    local float S, R, Due;

    UpdateFrameLimit();
    if (Link == None || Link.ServerTime <= 0 || bPaused || bSeeking || bLimitFrameRate)
    {
        bPaceSet = false;
        if (bHeld && !bPaused)
            WorldInfo.Pauser = None;
        bHeld = false;
        return;
    }
    S = Link.ServerTime;
    R = WorldInfo.RealTimeSeconds;
    if (!bPaceSet || S < PaceServer)
    {
        bPaceSet = true;
        PaceServer = S;
        PaceReal = R;
    }
    Due = PaceServer + Speed * (R - PaceReal);
    if (Due - S > 0.25)
    {
        PaceServer = S;
        PaceReal = R;
        Due = S;
    }
    bHeld = S > Due;
    WorldInfo.Pauser = bHeld ? PlayerReplicationInfo : None;
}

// The frame rate way: the game draws (and so reads) only as many frames a second as the demo has moments at the chosen
// speed. Every second or so the moments per second are measured, and the limit corrected by how fast the demo really
// went. Not while paused or skipping (the camera goes at the game's own frame rate then)
function UpdateFrameLimit()
{
    local float S, R, F;
    local int Frame;

    if (Limiter == None && LocalPlayer(Player) != None)
        Limiter = class'DRFrameLimiter'.static.Get(LocalPlayer(Player));
    if (Limiter == None)
        return;
    if (!bLimitFrameRate || bPaused || bSeeking || Link == None || Link.ServerTime <= 0)
    {
        Limiter.Release();
        bRateSampled = false;
        return;
    }
    if (MomentsPerSecond <= 0)
        MomentsPerSecond = 30.0;
    if (LimitScale <= 0)
        LimitScale = 1.0;

    WorldInfo.GetDemoFrameInfo(Frame);
    S = Link.ServerTime;
    R = WorldInfo.RealTimeSeconds;
    if (!bRateSampled || S < RateServer)
    {
        bRateSampled = true;
        RateFrame = Frame;
        RateServer = S;
        RateReal = R;
    }
    else if (R - RateReal >= 1.0 && S - RateServer >= 0.25)
    {
        MomentsPerSecond = FClamp((Frame - RateFrame) / (S - RateServer), 5.0, 120.0);
        F = (S - RateServer) / (R - RateReal);
        LimitScale = FClamp(LimitScale * ((Speed / FMax(F, 0.01)) ** 0.5), 0.5, 2.0);
        RateFrame = Frame;
        RateServer = S;
        RateReal = R;
    }
    Limiter.Limit(FClamp(MomentsPerSecond * Speed * LimitScale, 2.0, 240.0));
}

// demopacing: the real speed by holding the demo between moments (the camera as smooth as the game's frame rate), or by
// limiting the frame rate to the demo's moments (no pausing, but everything at that rate). Remembered
exec function DemoPacing()
{
    bLimitFrameRate = !bLimitFrameRate;
    default.bLimitFrameRate = bLimitFrameRate;
    StaticSaveConfig();
    LimitScale = 1.0;
    bRateSampled = false;
    ApplySpeed();
    Say(bLimitFrameRate ? "Real speed by limiting the frame rate to the demo's (no pausing between moments)"
        : "Real speed by holding the demo between moments (the camera at your frame rate)");
}

// The game's clock (what the animations and effects go by) moves on only in the frames the demo does, by the frame's
// time times DemoPlayTimeDilation: every second or so that is set so it went as far as the server's clock in the demo
function UpdateClock()
{
    local float S, W, R, F;

    if (Link == None || Link.ServerTime <= 0 || bPaused)
    {
        bClockSampled = false;
        return;
    }
    S = Link.ServerTime;
    W = WorldInfo.TimeSeconds;
    R = WorldInfo.RealTimeSeconds;
    if (!bClockSampled || S < ClockServer)
    {
        bClockSampled = true;
        ClockServer = S;
        ClockWorld = W;
        ClockReal = R;
        return;
    }
    if (R - ClockReal < 1.0 || W - ClockWorld < 0.05 || S - ClockServer < 0.05)
        return;
    F = (S - ClockServer) / (W - ClockWorld);
    ClockServer = S;
    ClockWorld = W;
    ClockReal = R;
    if (Abs(F - 1.0) < 0.03)
        return;
    // the first time all the way, then in steps (each second's measure is a little uneven)
    TimeScale = FClamp(TimeScale * (bClockSet ? (F ** 0.6) : F), MIN_SPEED, 20.0);
    bClockSet = true;
    WorldInfo.DemoPlayTimeDilation = TimeScale;
}

// Real seconds for this frame, whatever the demo does, so the camera moves at its own speed
function float RealDelta(float DeltaTime)
{
    return (RealStep > 0) ? RealStep : DeltaTime;
}

static function string TimeText(float T)
{
    local int Secs;

    Secs = int(FMax(T, 0));
    return (Secs / 60)$":"$(((Secs % 60) < 10) ? "0" : "")$(Secs % 60);
}

// The demo's speed, and pause (the game's pause: the demo stops; this camera keeps going, see PlayerTick). The pace
// starts again from here (UpdatePacing)
function ApplySpeed()
{
    WorldInfo.DemoPlayTimeDilation = TimeScale;
    bPaceSet = false;
    bHeld = false;
    if (bPaused && !bSeeking)
        WorldInfo.Pauser = PlayerReplicationInfo;
    else
        WorldInfo.Pauser = None;
}

// The game's HUD, MutCMenu's view and this camera's own text, all off (or back on)
exec function DemoCinematic()
{
    SetCinematic(!bCinematic);
}

function SetCinematic(bool bOn)
{
    local int i;

    if (bOn == bCinematic)
        return;
    bCinematic = bOn;
    if (myHUD != None)
        myHUD.bShowHUD = !bOn;
    if (bOn)
    {
        for (i = Interactions.Length - 1; i >= 0; i--)
        {
            if (Interactions[i] != None && Interactions[i].Class.Name == 'CMMapInteraction')
            {
                HiddenInteractions.AddItem(Interactions[i]);
                Interactions.Remove(i, 1);
            }
        }
    }
    else
    {
        for (i = 0; i < HiddenInteractions.Length; i++)
        {
            if (HiddenInteractions[i] != None && Interactions.Find(HiddenInteractions[i]) == INDEX_NONE)
                Interactions.AddItem(HiddenInteractions[i]);
        }
        HiddenInteractions.Length = 0;
    }
}

// demospeed 0.5 (half), demospeed 2 (double); 1 is normal
exec function DemoSpeed(float NewSpeed)
{
    Speed = FClamp(NewSpeed, MIN_SPEED, MAX_SPEED);
    bPaused = false;
    ApplySpeed();
    Say("Speed "$Speed$"x");
}

// One step slower or faster: 0.1, 0.25, 0.5, 1, 2, 4, 8
exec function DemoSlower()
{
    if (Speed > 1.0)
        DemoSpeed(Speed / 2);
    else if (Speed > 0.5)
        DemoSpeed(0.5);
    else if (Speed > 0.25)
        DemoSpeed(0.25);
    else
        DemoSpeed(0.1);
}

exec function DemoFaster()
{
    if (Speed < 0.25)
        DemoSpeed(0.25);
    else if (Speed < 0.5)
        DemoSpeed(0.5);
    else if (Speed < 1.0)
        DemoSpeed(1.0);
    else
        DemoSpeed(FMin(Speed * 2, 8.0));
}

exec function DemoPause()
{
    bPaused = !bPaused;
    ApplySpeed();
}

// demoskip 10 (forward), demoskip -10 (back)
exec function DemoSkip(float Seconds)
{
    SeekTo(DemoTime() + Seconds);
}

// demoseek 2:30, or demoseek 150 (seconds into the demo)
exec function DemoSeek(string When)
{
    local array<string> Parts;

    Parts = SplitString(When, ":", true);
    if (Parts.Length >= 2)
        SeekTo(float(Parts[0]) * 60 + float(Parts[1]));
    else
        SeekTo(float(When));
}

function SeekTo(float T)
{
    local DRRestarter Restarter;

    T = FMax(T, 0);
    if (T < DemoTime() - 0.5)
    {
        // Back: the demo is started again and goes quickly to T (the engine's own rewind is off in RS2)
        if (DemoName == "")
        {
            Say("This demo can't be rewound: its name isn't known (it wasn't recorded by MutDemoRec)");
            return;
        }
        default.ResumeDemo = DemoName;
        default.ResumeTime = T;
        default.ResumeSpeed = Speed;
        default.bResumeCinematic = bCinematic;
        default.ResumeTimeScale = TimeScale;
        SaveViewerConfig();
        Say("Rewinding to "$TimeText(T));
        // The game won't start a demo while one plays: stop it, and a restarter on the viewport (which stays through
        // the level change) plays it again
        Restarter = new(LocalPlayer(Player).ViewportClient) class'DRRestarter';
        Restarter.DemoToPlay = DemoName;
        Restarter.LastLevelTime = WorldInfo.RealTimeSeconds;
        LocalPlayer(Player).ViewportClient.InsertInteraction(Restarter);
        ConsoleCommand("demostop");
        return;
    }
    if (T <= DemoTime())
        return;
    SeekTarget = T;
    bSeeking = true;
    bSeekForRewind = false;
    ApplySpeed();
}

// After the restart for a rewind: back to the time, the speed and the cinematic mode it was at
function ResumeRewind()
{
    if (default.ResumeDemo == "" || default.ResumeDemo != DemoName)
        return;
    Speed = (default.ResumeSpeed > 0) ? default.ResumeSpeed : 1.0;
    if (default.ResumeTimeScale > 0)
    {
        TimeScale = default.ResumeTimeScale;
        bClockSet = true;
    }
    SetCinematic(default.bResumeCinematic);
    SeekTarget = default.ResumeTime;
    bSeeking = SeekTarget > DemoTime();
    bSeekForRewind = bSeeking;
    default.ResumeDemo = "";
    default.ResumeTime = 0;
    SaveViewerConfig();
    ApplySpeed();
}

// The defaults are what the next viewer (after a restart) starts from, so they are what is saved
function SaveViewerConfig()
{
    default.bSmoothCamera = bSmoothCamera;
    default.PathPoints = PathPoints;
    default.PathRotations = PathRotations;
    StaticSaveConfig();
}

function float SmoothRate()
{
    return (SmoothSpeed > 0) ? SmoothSpeed : 3.0;
}

// demosmooth: on or off. demosmooth 5: on, catching up at that rate (higher is quicker, 3 if never set)
exec function DemoSmooth(optional float NewSpeed)
{
    if (NewSpeed > 0)
    {
        SmoothSpeed = NewSpeed;
        default.SmoothSpeed = NewSpeed;
        bSmoothCamera = true;
    }
    else
        bSmoothCamera = !bSmoothCamera;
    bSmoothStarted = false;
    SaveViewerConfig();
    Say("Smooth camera "$(bSmoothCamera ? "on" : "off"));
}

// A camera path point where the camera is now
exec function DemoPathAdd()
{
    local vector Loc;
    local rotator Rot;

    Global.GetPlayerViewPoint(Loc, Rot);
    AddPathPoint(Loc, Rot);
    Say("Camera path point "$PathPoints.Length);
}

function AddPathPoint(vector Loc, rotator Rot)
{
    PathPoints.AddItem(Loc);
    PathRotations.AddItem(Rot);
    SaveViewerConfig();
}

exec function DemoPathClear()
{
    PathPoints.Length = 0;
    PathRotations.Length = 0;
    bPathPlaying = false;
    SaveViewerConfig();
    Say("Camera path cleared");
}

// demopathtime 2: two seconds from one point to the next (3 if never set)
exec function DemoPathTime(float Seconds)
{
    PathPointSeconds = FMax(Seconds, 0.25);
    default.PathPointSeconds = PathPointSeconds;
    StaticSaveConfig();
}

// Fly the path (or stop flying it). It ends in free roam where the path ends
exec function DemoPathPlay()
{
    if (bPathPlaying)
    {
        StopPath();
        return;
    }
    if (PathPoints.Length < 2)
    {
        Say("A camera path needs at least two points (demopathadd)");
        return;
    }
    bPathPlaying = true;
    PathStart = WorldInfo.RealTimeSeconds;
    UpdatePath();
}

function StopPath()
{
    bPathPlaying = false;
    // Carry on from where the path stopped, in free roam
    ServerSetRoamingSpectate();
    SetLocation(PathLoc);
    SetRotation(PathRot);
    bSmoothStarted = false;
}

function float PathSeconds()
{
    return (PathPointSeconds > 0) ? FMax(PathPointSeconds, 0.25) : 3.0;
}

// Where the path is now: a Catmull-Rom curve through the points (smooth, and through every point), the same for the
// rotation (each step the short way round). On real time, so it flies the same at any demo speed
function UpdatePath()
{
    local float T, F;
    local int i, i0, i2, i3;
    local rotator R0, R1, R2, R3;

    T = (WorldInfo.RealTimeSeconds - PathStart) / PathSeconds();
    if (T >= PathPoints.Length - 1)
    {
        PathLoc = PathPoints[PathPoints.Length - 1];
        PathRot = PathRotations[PathRotations.Length - 1];
        StopPath();
        return;
    }
    i = int(T);
    F = T - i;
    i0 = Max(i - 1, 0);
    i2 = Min(i + 1, PathPoints.Length - 1);
    i3 = Min(i + 2, PathPoints.Length - 1);
    PathLoc = CatmullRom(PathPoints[i0], PathPoints[i], PathPoints[i2], PathPoints[i3], F);

    R1 = PathRotations[i];
    R0 = R1 + Normalize(PathRotations[i0] - R1);
    R2 = R1 + Normalize(PathRotations[i2] - R1);
    R3 = R2 + Normalize(PathRotations[i3] - R2);
    PathRot.Pitch = CatmullRomF(R0.Pitch, R1.Pitch, R2.Pitch, R3.Pitch, F);
    PathRot.Yaw = CatmullRomF(R0.Yaw, R1.Yaw, R2.Yaw, R3.Yaw, F);
    PathRot.Roll = 0;
}

static function vector CatmullRom(vector P0, vector P1, vector P2, vector P3, float T)
{
    local vector V;

    V.X = CatmullRomF(P0.X, P1.X, P2.X, P3.X, T);
    V.Y = CatmullRomF(P0.Y, P1.Y, P2.Y, P3.Y, T);
    V.Z = CatmullRomF(P0.Z, P1.Z, P2.Z, P3.Z, T);
    return V;
}

static function float CatmullRomF(float P0, float P1, float P2, float P3, float T)
{
    return 0.5 * ((2 * P1) + (P2 - P0) * T + (2 * P0 - 5 * P1 + 4 * P2 - P3) * T * T + (3 * P1 - P0 - 3 * P2 + P3) * T * T * T);
}

// The view: the camera path while it plays, else the camera eased towards where it should be (smooth camera)
simulated event GetPlayerViewPoint(out vector Loc, out rotator Rot)
{
    local float Dt, Alpha;

    super.GetPlayerViewPoint(Loc, Rot);
    if (bPathPlaying)
    {
        Loc = PathLoc;
        Rot = PathRot;
        return;
    }
    if (!bSmoothCamera)
        return;

    // Once per frame (this is asked for more than once), on real time: the same at any demo speed
    if (!bSmoothStarted)
    {
        bSmoothStarted = true;
        SmoothLoc = Loc;
        SmoothRot = Rot;
        LastViewTime = WorldInfo.RealTimeSeconds;
    }
    Dt = WorldInfo.RealTimeSeconds - LastViewTime;
    if (Dt > 0)
    {
        LastViewTime = WorldInfo.RealTimeSeconds;
        Alpha = 1.0 - Exp(-SmoothRate() * Dt);
        SmoothLoc += (Loc - SmoothLoc) * Alpha;
        SmoothRot += Normalize(Rot - SmoothRot) * Alpha;
        SmoothRot.Roll = 0;
    }
    Loc = SmoothLoc;
    Rot = SmoothRot;
}

auto state Spectating
{
    exec function StartAltFire(optional byte FireModeNum)
    {
        ServerViewPrevTarget(); // the game's spectator: previous player (the demo camera's own: an aim debug view)
    }

    exec function PrevWeapon()
    {
        SpectatorCameraSpeed = FClamp(SpectatorCameraSpeed + CameraSpeedIncrease, CameraSpeedMin, CameraSpeedMax);
    }

    exec function NextWeapon()
    {
        SpectatorCameraSpeed = FClamp(SpectatorCameraSpeed - CameraSpeedIncrease, CameraSpeedMin, CameraSpeedMax);
    }

    // The camera moves at its own speed, however fast the demo plays (and while it is paused)
    function PlayerMove(float DeltaTime)
    {
        super.PlayerMove(RealDelta(DeltaTime));
    }

    // (the demo camera's own, in this state, would skip the path and the smooth camera)
    simulated event GetPlayerViewPoint(out vector Loc, out rotator Rot)
    {
        Global.GetPlayerViewPoint(Loc, Rot);
    }

    // The demo camera's player following, which it only does as the network copy of the server's camera; this one is
    // made here
    event PlayerTick(float DeltaTime)
    {
        local Pawn P;

        RealStep = (LastRealTime > 0) ? FClamp(WorldInfo.RealTimeSeconds - LastRealTime, 0.0, 0.25) : 0.0;
        LastRealTime = WorldInfo.RealTimeSeconds;
        Global.PlayerTick(DeltaTime);
        // While the demo is paused or held the game still runs this, but doesn't update the camera: do it here
        if (WorldInfo.Pauser != None && PlayerCamera != None)
            PlayerCamera.UpdateCamera(RealStep);

        if (bSeeking && DemoTime() >= SeekTarget)
        {
            bSeeking = false;
            bSeekForRewind = false;
            ApplySpeed();
        }
        if (bPathPlaying)
            UpdatePath();
        UpdatePacing();
        UpdateClock();

        if (RealViewTarget == None && MyRealViewTarget != None)
            RealViewTarget = MyRealViewTarget;

        if ((RealViewTarget == None || RealViewTarget == PlayerReplicationInfo) && bFindPlayer)
        {
            DemoViewNextPlayer();
            if (RealViewTarget != None && RealViewTarget != PlayerReplicationInfo)
            {
                bFindPlayer = false;
                CurrentSpectateMode = SMODE_PawnThirdPerson;
                SetCameraMode('ThirdPerson');
            }
        }
        else if (RealViewTarget != None && RealViewTarget != PlayerReplicationInfo
            && (Pawn(ViewTarget) == None || Pawn(ViewTarget).PlayerReplicationInfo != RealViewTarget))
        {
            // the player switched pawns (respawned, got in a vehicle)
            foreach WorldInfo.AllPawns(class'Pawn', P)
            {
                if (P.PlayerReplicationInfo == RealViewTarget)
                {
                    SetViewTarget(P);
                    break;
                }
            }
        }

        if (Pawn(ViewTarget) != None)
        {
            TargetViewRotation = ViewTarget.Rotation;
            TargetViewRotation.Pitch = Pawn(ViewTarget).RemoteViewPitch << 8;
            if (ROPawn(ViewTarget) != None)
                ROPawn(ViewTarget).SetPosition();
        }
    }
}

defaultproperties
{
    bAlwaysTick=true
    RemoteRole=ROLE_None
    bFindPlayer=true
}
