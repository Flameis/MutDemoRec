// Limits the game's frame rate while a demo plays in the viewer's frame rate mode (DRDemoViewer.bLimitFrameRate), and
// puts the player's own frame rate settings back the moment no demo plays (it sits on the game's viewport, which stays
// through level changes, so it also sees the demo end or be stopped for a rewind). The game only saves these settings
// when its graphics settings are applied, so the limit never goes into the player's ini.
// The viewport's list of these can't be read or changed from outside, so there is one for the game (found by its name),
// idle while it isn't needed.
class DRFrameLimiter extends Interaction;

var bool    bLimiting;
var bool    bOwnSmooth;     // The player's own settings, while limiting
var float   OwnMax, OwnMin;

// The one on the game's viewport (found by its name), put there the first time
static function DRFrameLimiter Get(LocalPlayer LP)
{
    local DRFrameLimiter L;

    if (LP == None || LP.ViewportClient == None)
        return None;
    L = DRFrameLimiter(FindObject(PathName(LP.ViewportClient)$".DRFrameLimiterOne", class'DRFrameLimiter'));
    if (L != None)
        return L;
    L = new(LP.ViewportClient, "DRFrameLimiterOne") class'DRFrameLimiter';
    LP.ViewportClient.InsertInteraction(L);
    return L;
}

function Limit(float FramesPerSecond)
{
    local Engine E;

    E = class'Engine'.static.GetEngine();
    if (E == None)
        return;
    if (!bLimiting)
    {
        bLimiting = true;
        bOwnSmooth = E.bSmoothFrameRate;
        OwnMax = E.MaxSmoothedFrameRate;
        OwnMin = E.MinSmoothedFrameRate;
    }
    E.bSmoothFrameRate = true;
    E.MaxSmoothedFrameRate = FramesPerSecond;
    E.MinSmoothedFrameRate = FMin(OwnMin, FramesPerSecond * 0.5);
}

function Release()
{
    local Engine E;

    if (!bLimiting)
        return;
    bLimiting = false;
    E = class'Engine'.static.GetEngine();
    if (E == None)
        return;
    E.bSmoothFrameRate = bOwnSmooth;
    E.MaxSmoothedFrameRate = OwnMax;
    E.MinSmoothedFrameRate = OwnMin;
}

event Tick(float DeltaTime)
{
    local WorldInfo WI;

    if (!bLimiting)
        return;
    WI = class'Engine'.static.GetCurrentWorldInfo();
    if (WI == None || !WI.IsPlayingDemo())
        Release();
}

defaultproperties
{
}
