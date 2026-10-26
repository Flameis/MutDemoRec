// Demo recording for the RypelCam, in one mutator that needs no other.
//  - Records a demo of every round (bRecordRounds), or when someone asks (demorec, demostop, demostatus: anyone, or
//    only admins with bAdminOnlyCommands).
//  - While any demo records, a DRDemoLink goes into it (and only into it). It puts the gunfire into the demo, and when
//    the demo is played back it gives the viewer a spectator camera like the game's own (DRDemoViewer: cinematic mode,
//    speed, pause, rewind, a smooth camera and camera paths), which also lets the sounds the playback makes itself be
//    heard (explosions, artillery), and starts the map's ambient sound.
class MutDemoRec extends ROMutator
    config(MutDemoRec_Server);

var config bool     bRecordRounds;          // Record a demo of every round, from its start to its end
var config bool     bAdminOnlyCommands;     // Only admins can use demorec, demostop and demostatus (off: anyone)
var config bool     bDisableDemoGunfire;    // Leave the gunfire out of demos (stored as the negative: on by default)
var config bool     bDisableDemoViewer;     // No spectator camera when a demo is played back (on by default)
var config bool     bDisableDemoAmbient;    // Don't start the map's ambient sound when a demo is played back (on by default)

var DRDemoLink      DemoLink;       // While a demo records
var bool            bAutoStarted;   // The recording running now was started by the round starting
var string          DemoName;       // Name of the recording this started ("" if it was started some other way)
var bool            bRoundWasActive;

function PostBeginPlay()
{
    super.PostBeginPlay();
    SetTimer(0.25, true, 'CheckDemo');
    `log("[MutDemoRec] active");
}

// ====================================================
// Recording
// ====================================================

// The server's demo camera while a demo records
function PlayerController FindDemoCamera()
{
    local PlayerController PC;

    foreach WorldInfo.AllControllers(class'PlayerController', PC)
    {
        if (DemoRecSpectator(PC) != None || PC.bDemoOwner)
            return PC;
    }
    return None;
}

function CheckDemo()
{
    local ROGameInfo ROGI;
    local PlayerController DemoCam;
    local bool bRoundActive;

    // Every round (bRecordRounds): from the moment it starts to the moment it ends
    ROGI = ROGameInfo(WorldInfo.Game);
    bRoundActive = ROGI != None && ROGI.bRoundActive;
    if (bRecordRounds && bRoundActive && !bRoundWasActive && !WorldInfo.IsRecordingDemo())
        StartRecording(None, "", true);
    else if (!bRoundActive && bRoundWasActive && bAutoStarted)
        StopRecording();
    bRoundWasActive = bRoundActive;

    // The link into the demo
    if (!WorldInfo.IsRecordingDemo() || (bDisableDemoGunfire && bDisableDemoViewer && bDisableDemoAmbient))
    {
        if (DemoLink != None)
        {
            DemoLink.Destroy();
            DemoLink = None;
        }
        return;
    }
    if (DemoLink != None && !DemoLink.bDeleteMe && DemoLink.Owner != None && !DemoLink.Owner.bDeleteMe)
        return;

    DemoCam = FindDemoCamera();
    if (DemoCam == None)
        return;
    if (DemoLink != None)
        DemoLink.Destroy();
    DemoLink = Spawn(class'DRDemoLink', DemoCam);
    if (DemoLink != None)
    {
        DemoLink.bGunfire = !bDisableDemoGunfire;
        DemoLink.bViewer = !bDisableDemoViewer;
        DemoLink.bAmbient = !bDisableDemoAmbient;
        DemoLink.DemoName = DemoName; // so the viewer can start it again to rewind ("" if it was started some other way)
    }
    `log("[MutDemoRec] demo recording: link "$DemoLink$" for "$DemoCam);
}

// Starts a server demo; the file goes to ROGame\Demos on the server. Returns false if one is already recording
function bool StartRecording(optional PlayerController Sender, optional string WantedName, optional bool bAuto)
{
    if (WorldInfo.IsRecordingDemo())
    {
        if (Sender != None)
            Sender.ClientMessage("[Demo] A demo is already being recorded"$(DemoName != "" ? ": "$DemoName : ""));
        return false;
    }

    WantedName = CleanName(WantedName);
    DemoName = (WantedName != "") ? WantedName : MakeDemoName();
    bAutoStarted = bAuto;
    ConsoleCommand("demorec "$DemoName);
    `log("[MutDemoRec] demorec "$DemoName$" recording="$WorldInfo.IsRecordingDemo());

    if (WorldInfo.IsRecordingDemo())
        WorldInfo.Game.Broadcast(self, "[Demo] Recording a demo: "$DemoName);
    else
        SetTimer(1.0, false, 'CheckStarted'); // the engine may only start it on the next tick
    return true;
}

function CheckStarted()
{
    if (WorldInfo.IsRecordingDemo())
    {
        WorldInfo.Game.Broadcast(self, "[Demo] Recording a demo: "$DemoName);
    }
    else
    {
        WorldInfo.Game.Broadcast(self, "[Demo] The demo recording could not be started");
        DemoName = "";
        bAutoStarted = false;
    }
}

function bool StopRecording(optional PlayerController Sender)
{
    if (!WorldInfo.IsRecordingDemo())
    {
        if (Sender != None)
            Sender.ClientMessage("[Demo] No demo is being recorded");
        return false;
    }

    ConsoleCommand("demostop");
    WorldInfo.Game.Broadcast(self, "[Demo] Demo recording stopped"$(DemoName != "" ? ": "$DemoName : ""));
    DemoName = "";
    bAutoStarted = false;
    return true;
}

function ShowStatus(PlayerController Sender)
{
    if (WorldInfo.IsRecordingDemo())
    {
        Sender.ClientMessage("[Demo] Recording a demo: "$(DemoName != "" ? DemoName : "(started some other way)")
            $(bAutoStarted ? ", stops when the round ends" : ", stops with demostop"));
        if (DemoLink != None && DemoLink.bGunfire)
            Sender.ClientMessage("[Demo] Gunshots put into the demo: "$DemoLink.SoundsAdded);
    }
    else
    {
        Sender.ClientMessage("[Demo] No demo is being recorded. Recording every round is "$(bRecordRounds ? "on" : "off"));
    }
}

// DR_<map>_<date>_<time>, for example DR_VNTE-Hue_2026-10-26_19-04-31
function string MakeDemoName()
{
    local int Year, Month, DayOfWeek, Day, Hour, Min, Sec, MSec;

    GetSystemTime(Year, Month, DayOfWeek, Day, Hour, Min, Sec, MSec);
    return "DR_"$CleanName(WorldInfo.GetMapName(true))$"_"$Year$"-"$TwoDigits(Month)$"-"$TwoDigits(Day)$"_"$TwoDigits(Hour)$"-"$TwoDigits(Min)$"-"$TwoDigits(Sec);
}

static function string TwoDigits(int N)
{
    return (N < 10) ? "0"$N : string(N);
}

// Only letters, digits, - and _ so the name is a safe file name (anything else becomes _)
static function string CleanName(string S)
{
    local string Out, C;
    local int i, A;

    for (i = 0; i < Len(S) && i < 64; i++)
    {
        C = Mid(S, i, 1);
        A = Asc(C);
        if ((A >= 48 && A <= 57) || (A >= 65 && A <= 90) || (A >= 97 && A <= 122) || C == "-" || C == "_")
            Out $= C;
        else
            Out $= "_";
    }
    return Out;
}

// ====================================================
// Commands
// ====================================================

// Admins: logged in as admin, or the host of a listen server or a single player game
function bool IsAdmin(PlayerController PC)
{
    return PC != None && (WorldInfo.NetMode == NM_Standalone || PC.IsLocalPlayerController()
        || (PC.PlayerReplicationInfo != None && PC.PlayerReplicationInfo.bAdmin));
}

function Mutate(string MutateString, PlayerController PC)
{
    local array<string> Args;
    local string Command, WantedName;
    local int i;

    Args = SplitString(MutateString, " ", true);
    if (Args.Length > 0)
        Command = Caps(Args[0]);

    if (Command == "DEMOREC" || Command == "DEMOSTOP" || Command == "DEMOSTATUS")
    {
        if (bAdminOnlyCommands && !IsAdmin(PC))
        {
            PC.ClientMessage("[Demo] Only an admin can do that on this server");
        }
        else if (Command == "DEMOREC")
        {
            // demorec [name], or demorec --name / -n [name]
            for (i = 1; i < Args.Length; i++)
            {
                if (Args[i] ~= "--name" || Args[i] ~= "-n")
                    continue;
                WantedName $= (WantedName != "" ? "_" : "")$Args[i];
            }
            StartRecording(PC, WantedName);
        }
        else if (Command == "DEMOSTOP")
        {
            StopRecording(PC);
        }
        else
        {
            ShowStatus(PC);
        }
    }

    super.Mutate(MutateString, PC);
}

event Destroyed()
{
    // Map change: don't leave a recording the round started running into the next map
    if (bAutoStarted && WorldInfo.IsRecordingDemo())
        ConsoleCommand("demostop");
    super.Destroyed();
}

defaultproperties
{
}
