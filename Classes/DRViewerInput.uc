// The demo viewer's keys and its line of text (DRDemoViewer puts it first in its interactions, so its keys come before
// the game's). The keys are in MutDemoRec_Client.ini ([MutDemoRec.DRViewerInput]); a key left empty there has the
// default below. The game's spectator keys (fire, alt fire, iron sights, quick grenade, mouse wheel) are left alone.
class DRViewerInput extends Interaction
    config(MutDemoRec_Client);

var DRDemoViewer    Viewer;
var bool            bShowHelp;

var config name     CinematicKey, PauseKey, SlowerKey, FasterKey, NormalSpeedKey, RewindKey, SkipKey;
var config name     SmoothKey, PathAddKey, PathPlayKey, PathClearKey, HelpKey, PacingKey;
var config float    SkipSeconds;    // How far the rewind and skip keys go (0: 10 seconds)

function name KeyOr(name Configured, name Fallback)
{
    return (Configured != '') ? Configured : Fallback;
}

function float SkipBy()
{
    return (SkipSeconds > 0) ? SkipSeconds : 10.0;
}

function bool InputKey(int ControllerId, name Key, EInputEvent Event, optional float AmountDepressed = 1.f, optional bool bGamepad)
{
    if (Viewer == None || Event != IE_Pressed)
        return false;

    switch (Key)
    {
    case KeyOr(CinematicKey, 'H'):
        Viewer.DemoCinematic();
        return true;
    case KeyOr(PauseKey, 'P'):
        Viewer.DemoPause();
        return true;
    case KeyOr(SlowerKey, 'LeftBracket'):
        Viewer.DemoSlower();
        return true;
    case KeyOr(FasterKey, 'RightBracket'):
        Viewer.DemoFaster();
        return true;
    case KeyOr(NormalSpeedKey, 'Backslash'):
        Viewer.DemoSpeed(1.0);
        return true;
    case KeyOr(RewindKey, 'Left'):
        Viewer.DemoSkip(-SkipBy());
        return true;
    case KeyOr(SkipKey, 'Right'):
        Viewer.DemoSkip(SkipBy());
        return true;
    case KeyOr(SmoothKey, 'O'):
        Viewer.DemoSmooth();
        return true;
    case KeyOr(PathAddKey, 'K'):
        Viewer.DemoPathAdd();
        return true;
    case KeyOr(PathPlayKey, 'L'):
        Viewer.DemoPathPlay();
        return true;
    case KeyOr(PathClearKey, 'J'):
        Viewer.DemoPathClear();
        return true;
    case KeyOr(PacingKey, 'U'):
        Viewer.DemoPacing();
        return true;
    case KeyOr(HelpKey, 'F1'):
        bShowHelp = !bShowHelp;
        return true;
    }
    return false;
}

// A dark screen while a rewind catches up; otherwise (not in cinematic mode) a line at the bottom left: the demo time,
// speed, and what is on, and the keys while help is open
event PostRender(Canvas C)
{
    local float X, Y, XL, YL;
    local string S;
    local array<string> Lines;
    local int i;

    if (Viewer == None || C == None)
        return;

    if (Viewer.bSeekForRewind)
    {
        C.SetPos(0, 0);
        C.SetDrawColor(0, 0, 0, 255);
        C.DrawRect(C.SizeX, C.SizeY);
        C.Font = class'Engine'.static.GetMediumFont();
        S = "Rewinding to "$class'DRDemoViewer'.static.TimeText(Viewer.SeekTarget)$"...";
        C.StrLen(S, XL, YL);
        C.SetPos((C.SizeX - XL) / 2, (C.SizeY - YL) / 2);
        C.SetDrawColor(255, 255, 255, 255);
        C.DrawText(S);
        return;
    }
    if (Viewer.bCinematic)
        return;

    S = "Demo "$class'DRDemoViewer'.static.TimeText(Viewer.DemoTime());
    if (Viewer.bSeeking)
        S $= "  skipping to "$class'DRDemoViewer'.static.TimeText(Viewer.SeekTarget);
    else if (Viewer.bPaused)
        S $= "  paused";
    else if (Viewer.Speed != 1.0)
        S $= "  speed "$Viewer.Speed$"x";
    if (Viewer.bLimitFrameRate)
        S $= "  frame rate limited";
    if (Viewer.bSmoothCamera)
        S $= "  smooth camera";
    if (Viewer.bPathPlaying)
        S $= "  flying the camera path";
    else if (Viewer.PathPoints.Length > 0)
        S $= "  camera path: "$Viewer.PathPoints.Length$" points";
    S $= "  ("$KeyOr(HelpKey, 'F1')$": keys)";
    Lines.AddItem(S);

    if (bShowHelp)
    {
        Lines.AddItem(KeyOr(CinematicKey, 'H')$": cinematic mode (everything on screen off)   "$KeyOr(PauseKey, 'P')$": pause");
        Lines.AddItem(KeyOr(SlowerKey, 'LeftBracket')$" / "$KeyOr(FasterKey, 'RightBracket')$": slower / faster   "
            $KeyOr(NormalSpeedKey, 'Backslash')$": normal speed");
        Lines.AddItem(KeyOr(RewindKey, 'Left')$" / "$KeyOr(SkipKey, 'Right')$": back / forward "$int(SkipBy())$" seconds   console: demoseek 2:30   "
            $KeyOr(PacingKey, 'U')$": hold the demo / limit the frame rate");
        Lines.AddItem(KeyOr(SmoothKey, 'O')$": smooth camera   "$KeyOr(PathAddKey, 'K')$": camera path point here   "
            $KeyOr(PathPlayKey, 'L')$": fly the path   "$KeyOr(PathClearKey, 'J')$": clear the path");
        Lines.AddItem("Fire / alt fire: next / previous player   iron sights: camera mode   quick grenade: free roam   wheel: camera speed");
    }

    C.Font = class'Engine'.static.GetSmallFont();
    C.StrLen("X", XL, YL);
    X = 12;
    Y = C.SizeY - 12 - YL * Lines.Length;
    for (i = 0; i < Lines.Length; i++)
    {
        C.SetPos(X + 1, Y + 1);
        C.SetDrawColor(0, 0, 0, 200);
        C.DrawText(Lines[i]);
        C.SetPos(X, Y);
        C.SetDrawColor(255, 255, 255, 230);
        C.DrawText(Lines[i]);
        Y += YL;
    }
}

defaultproperties
{
}
