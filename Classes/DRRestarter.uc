// Starts a demo again for a rewind (DRDemoViewer.SeekTo). The game won't start a demo while one plays, and stopping it
// unloads the level (and the viewer with it), so this waits on the game's viewport, which stays through level changes:
// once the demo has stopped and the menu level is up, it plays the demo again, then does nothing more (the viewport's
// list of these can't be changed from outside, so it stays there, idle, until the game closes).
// Stopping a demo can send the game back to the menu twice, and the second cancels a demo started in between, so it
// asks 2 seconds into each new menu level, up to 3 times, until the demo plays.
// The new viewer then goes quickly to the time (MutDemoRec_Client.ini, ResumeDemo and ResumeTime).
class DRRestarter extends Interaction;

var string              DemoToPlay;
var bool                bDone;
var bool                bNewLevel;      // A level has started since the last ask
var int                 Tries;
var float               LastLevelTime;  // The level's clock last time: a new level's starts again at 0

event Tick(float DeltaTime)
{
    local WorldInfo WI;

    WI = class'Engine'.static.GetCurrentWorldInfo();
    if (bDone || WI == None)
        return;
    if (WI.RealTimeSeconds < LastLevelTime)
        bNewLevel = true;
    LastLevelTime = WI.RealTimeSeconds;

    if (WI.IsPlayingDemo())
    {
        bDone = Tries > 0;
        return;
    }
    if (bNewLevel && WI.RealTimeSeconds > 2.0)
    {
        bNewLevel = false;
        if (Tries >= 3)
        {
            bDone = true;
            return;
        }
        Tries++;
        WI.ConsoleCommand("demoplay "$DemoToPlay);
    }
}

defaultproperties
{
}
