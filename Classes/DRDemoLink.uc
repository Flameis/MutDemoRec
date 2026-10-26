// What MutDemoRec puts into a server demo while it records. It is owned by the demo camera, so only the demo gets it
// (players on the server never do), and it comes back when the demo is played back.
//
// Why it is needed: a played-back demo has the players and their shots, but the game sends each gunshot (and every
// other sound it sends a player) to the hidden camera the demo is recorded from, and the game never brings that camera
// back when the demo plays: it is lost, so those sounds are too. And the playback's own player has no proper camera
// controller, so the sounds the playback makes itself (explosions, artillery) have no one to hear them either.
//
// - Gunfire (bGunfire): on the server it watches every pawn's shots and writes each shot's sound into a short
//   replicated list, which the demo records. On playback each new sound in the list is played where it was fired,
//   the way the game plays a gunshot for a player. Every single shot, and the tail when a burst of automatic fire
//   ends (the sound of automatic fire itself is part of the pawn, so it is already in demos).
// - The viewer (bViewer): on playback the local player gets a DRDemoViewer, a spectator camera like the game's own.
// - Ambient sound (bAmbient): on playback the map's ambient sound is started (the map's own start doesn't run then).
// - The demo's name (DemoName), so the viewer can start the demo again to rewind it.
// - The server's clock (ServerTime). The game plays a demo one recorded moment per frame drawn, so it goes as fast as
//   the viewer's frame rate against the server's (several times too fast). The viewer paces it on this clock.
// - Who is sprinting (Sprints). The game sends a player's sprinting only to the other players, and a demo counts as
//   every player's own, so it never gets it: playback showed sprinting players running. It is set on playback here.
class DRDemoLink extends Actor;

struct DemoSound
{
    var AkEvent Sound;
    var Actor   Source;     // The shooter
    var vector  Location;   // Where the sound plays (the shooter's eyes, as the game does)
    var byte    Seq;        // Changes every time this slot gets a new sound (0: never used)
};

// The newest sounds, in turn. A slot is only reused 16 sounds later, by then long sent.
var repnotify DemoSound Sounds[16];
var bool    bGunfire, bViewer, bAmbient;
var string  DemoName;
var float   ServerTime;         // The server's clock (sent with every update)
var float   StartServerTime;    // The server's clock when this was made: demo time 0

struct PawnSprint
{
    var Pawn    P;
    var bool    bSprinting;
};
var PawnSprint Sprints[64];

replication
{
    if (bNetDirty)
        Sounds, ServerTime, Sprints;
    if (bNetInitial)
        bGunfire, bViewer, bAmbient, DemoName, StartServerTime;
}

// ---- Server
struct ShotWatch
{
    var Pawn    P;
    var byte    LastFlashCount;
    var vector  LastFlashLocation;
    var bool    bLooping;       // Its automatic fire loop was playing last time
};
var array<ShotWatch>    Watched;
var int                 NextSlot;
var byte                NextSeq;
var int                 SoundsAdded;    // Sounds put into the demo

// ---- Playback
var byte                PlayedSeq[16];
var bool                bViewerDone, bAmbientDone;

simulated event PostBeginPlay()
{
    super.PostBeginPlay();
    if (Role == ROLE_Authority)
    {
        StartServerTime = WorldInfo.TimeSeconds;
        ServerTime = StartServerTime;
    }
    if (WorldInfo.IsPlayingDemo())
        SetTimer(0.5, true, 'SetUpPlayback');
}

simulated event Tick(float DeltaTime)
{
    local Pawn P;
    local int i;

    // Playback: who is sprinting
    if (Role < ROLE_Authority)
    {
        ApplySprints();
        return;
    }

    ServerTime = WorldInfo.TimeSeconds;
    WatchSprints();
    if (!bGunfire)
        return;
    for (i = Watched.Length - 1; i >= 0; i--)
    {
        if (Watched[i].P == None || Watched[i].P.bDeleteMe)
            Watched.Remove(i, 1);
    }
    foreach WorldInfo.AllPawns(class'Pawn', P)
        WatchShots(P);
}

// ====================================================
// Sprinting
// ====================================================

// Server: every pawn has a slot while it is there (64 at most), with whether it is sprinting
function WatchSprints()
{
    local Pawn P;
    local int i, Free;

    for (i = 0; i < ArrayCount(Sprints); i++)
    {
        if (Sprints[i].P != None && Sprints[i].P.bDeleteMe)
            Sprints[i].P = None;
    }
    foreach WorldInfo.AllPawns(class'Pawn', P)
    {
        Free = INDEX_NONE;
        for (i = 0; i < ArrayCount(Sprints); i++)
        {
            if (Sprints[i].P == P)
                break;
            if (Free == INDEX_NONE && Sprints[i].P == None)
                Free = i;
        }
        if (i == ArrayCount(Sprints))
        {
            if (Free == INDEX_NONE)
                continue;
            i = Free;
            Sprints[i].P = P;
        }
        Sprints[i].bSprinting = P.bIsSprinting;
    }
}

// Playback: as the game does for another player when their sprinting changes (ROPawn.ReplicatedEvent)
simulated function ApplySprints()
{
    local int i;

    for (i = 0; i < ArrayCount(Sprints); i++)
    {
        if (Sprints[i].P == None || Sprints[i].P.bIsSprinting == Sprints[i].bSprinting)
            continue;
        Sprints[i].P.bIsSprinting = Sprints[i].bSprinting;
        if (Sprints[i].bSprinting && ROPawn(Sprints[i].P) != None)
            ROPawn(Sprints[i].P).CleanupActiveAnimation();
    }
}

// The demo's own time in seconds from when the link was made (or -1 before the clock has come in)
simulated function float DemoSeconds()
{
    return (ServerTime > 0) ? ServerTime - StartServerTime : -1.0;
}

// ====================================================
// Gunfire (server)
// ====================================================

function int FindWatch(Pawn P)
{
    local int i;

    for (i = 0; i < Watched.Length; i++)
    {
        if (Watched[i].P == P)
            return i;
    }
    return INDEX_NONE;
}

// A weapon shot raises the pawn's flash count (projectile weapons, which is nearly all of them) or moves its flash
// location (instant hit): what the game uses to show the shot to other players. The end of a burst of automatic
// fire is the pawn's looping fire sound stopping.
function WatchShots(Pawn P)
{
    local int i, Shots;
    local bool bLooping;
    local ROWeapon W;

    W = ROWeapon(P.Weapon);
    bLooping = ROPawn(P) != None && ROPawn(P).WeaponAmbientSound != None;

    i = FindWatch(P);
    if (i == INDEX_NONE)
    {
        i = Watched.Length;
        Watched.Length = i + 1;
        Watched[i].P = P;
        Watched[i].LastFlashCount = P.FlashCount;
        Watched[i].LastFlashLocation = P.FlashLocation;
        Watched[i].bLooping = bLooping;
        return;
    }

    if (P.FlashCount != Watched[i].LastFlashCount && P.FlashCount != 0)
    {
        Shots = int(P.FlashCount) - int(Watched[i].LastFlashCount);
        if (Shots <= 0)
            Shots += 254; // the count skips 0 (0 means stopped firing) when it wraps past 255
    }
    if (Shots == 0 && P.FlashLocation != Watched[i].LastFlashLocation && !IsZero(P.FlashLocation))
        Shots = 1;
    Watched[i].LastFlashCount = P.FlashCount;
    Watched[i].LastFlashLocation = P.FlashLocation;

    if (W != None && !W.bSuppressSounds)
    {
        for (Shots = Min(Shots, 3); Shots > 0; Shots--)
            AddSound(ShotSound(W, P.FiringMode), P);
        if (Watched[i].bLooping && !bLooping)
            AddSound(LoopEndSound(W, P.FiringMode), P);
    }
    Watched[i].bLooping = bLooping;
}

// The sound the game plays for other players when the weapon fires (ROWeapon.PlayFiringSound), or None when it plays
// none for each shot: while the looping fire sound of an automatic weapon plays instead
function AkEvent ShotSound(ROWeapon W, int Mode)
{
    if (W.bPlayingLoopingFireSnd || Mode >= W.WeaponFireSnd.Length)
        return None;
    if (Mode < W.bLoopHighROFSounds.Length && W.bLoopHighROFSounds[Mode] && W.IsInState('WeaponFiring'))
        return None;
    return W.WeaponFireSnd[Mode].DefaultCue;
}

// The tail the game plays when a burst ends (ROWeapon.StopLoopingFireSound)
function AkEvent LoopEndSound(ROWeapon W, int Mode)
{
    if (Mode >= W.WeaponFireLoopEndSnd.Length)
        return None;
    return W.WeaponFireLoopEndSnd[Mode].DefaultCue;
}

function AddSound(AkEvent Sound, Pawn Source)
{
    if (Sound == None)
        return;
    if (NextSeq == 255)
        NextSeq = 1;
    else
        NextSeq++;
    Sounds[NextSlot].Sound = Sound;
    Sounds[NextSlot].Source = Source;
    Sounds[NextSlot].Location = Source.GetPawnViewLocation();
    Sounds[NextSlot].Seq = NextSeq;
    NextSlot = (NextSlot + 1) % ArrayCount(Sounds);
    SoundsAdded++;
    bForceNetUpdate = true;
}

// ====================================================
// Gunfire (playback): the demo brings new sounds into the list
// ====================================================

simulated event ReplicatedEvent(name VarName)
{
    local int i;

    if (VarName != 'Sounds')
    {
        super.ReplicatedEvent(VarName);
        return;
    }
    for (i = 0; i < ArrayCount(Sounds); i++)
    {
        if (Sounds[i].Seq != 0 && Sounds[i].Seq != PlayedSeq[i])
        {
            PlayedSeq[i] = Sounds[i].Seq;
            // (not while the viewer skips through the demo to a point: hundreds of shots at once)
            if (DRDemoViewer(GetALocalPlayerController()) == None || !DRDemoViewer(GetALocalPlayerController()).bSeeking)
                PlayDemoSound(Sounds[i].Sound, Sounds[i].Source, Sounds[i].Location);
        }
    }
}

// What the game does when it plays a gunshot for a player (ROPlayerController.WwiseClientHearSound and
// ClientHearSoundAdvanced): the reverb of the place it is fired in, the sound at that spot, and its echoes
simulated function PlayDemoSound(AkEvent Sound, Actor Source, vector Where)
{
    local ROPlayerController PC;
    local rotator EchoRotation;

    if (Sound == None)
        return;
    if (IsZero(Where) && Source != None)
        Where = Source.Location;

    if (Sound.bUseEnvironmentReverbSwitchGroup)
        SetReverb(Sound, Where);
    PostAkEventAtLocation(Sound, Where);

    PC = ROPlayerController(GetALocalPlayerController());
    if (Sound.bUseAdvancedSoundFunctionality && PC != None)
    {
        if (Source != None)
            EchoRotation = Source.GetAKRotation();
        PC.HearEchoes(Sound, Where, EchoRotation);
    }
}

simulated function SetReverb(AkEvent Sound, vector Where)
{
    local name EnvironmentName;
    local int i;

    EnvironmentName = WorldInfo.GetAkEnvironmentName(Where);
    for (i = 0; i < Sound.CustomSwitches.Length; i++)
    {
        if (Sound.CustomSwitches[i].SwitchGroupName == 'Environment_Reverb')
        {
            Sound.CustomSwitches[i].SwitchName = EnvironmentName;
            return;
        }
    }
    Sound.CustomSwitches.Insert(0, 1);
    Sound.CustomSwitches[0].SwitchGroupName = 'Environment_Reverb';
    Sound.CustomSwitches[0].SwitchName = EnvironmentName;
}

// ====================================================
// Playback: the viewer and the ambient sound
// ====================================================

simulated function SetUpPlayback()
{
    if (bViewer && !bViewerDone)
        bViewerDone = class'DRDemoViewer'.static.TakeOverLocalPlayer(self);

    // A moment in, so the map's own start (if it has one that works on playback) goes first
    if (bAmbient && !bAmbientDone && WorldInfo.TimeSeconds - CreationTime > 2.0)
    {
        bAmbientDone = true;
        StartAmbientSound();
    }

    if ((!bViewer || bViewerDone) && (!bAmbient || bAmbientDone))
        ClearTimer('SetUpPlayback');
}

// Fires the "Start All" input of the map's AkStartAmbientSound Kismet node(s), "Stop All" first so a map that did start
// its ambience doesn't play it twice
simulated function StartAmbientSound()
{
    local Sequence GameSeq;
    local array<SequenceObject> Nodes;
    local int i;

    GameSeq = WorldInfo.GetGameSequence();
    if (GameSeq == None)
        return;
    GameSeq.FindSeqObjectsByClass(class'SeqAct_AkStartAmbientSound', true, Nodes);
    for (i = 0; i < Nodes.Length; i++)
    {
        SequenceOp(Nodes[i]).ForceActivateInput(1); // "Stop All"
        SequenceOp(Nodes[i]).ForceActivateInput(0); // "Start All"
    }
    `log("[MutDemoRec] demo playback: started the map's ambient sound ("$Nodes.Length$" node(s))");
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bOnlyRelevantToOwner=true
    bAlwaysRelevant=false
    bHidden=true
    bSkipActorPropertyReplication=false
    NetUpdateFrequency=100
    NetPriority=3.0
}
