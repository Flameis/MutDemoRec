class MutDemoRecSettings extends MutatorSettings
    config(MutDemoRec_Server);

// The playback settings are shown the right way round ("put the gunfire into demos": On) but stored as their negative
// (bDisableDemoGunfire), so a line missing from the ini means on
function InitMutSettings()
{
    if (self.myMut == None)
    {
        self.SetIntPropertyByName('bRecordRounds', int(class'MutDemoRec'.default.bRecordRounds));
        self.SetIntPropertyByName('bAdminOnlyCommands', int(class'MutDemoRec'.default.bAdminOnlyCommands));
        self.SetIntPropertyByName('bDemoGunfire', int(!class'MutDemoRec'.default.bDisableDemoGunfire));
        self.SetIntPropertyByName('bDemoViewer', int(!class'MutDemoRec'.default.bDisableDemoViewer));
        self.SetIntPropertyByName('bDemoAmbient', int(!class'MutDemoRec'.default.bDisableDemoAmbient));
    }
    else
    {
        self.SetIntPropertyByName('bRecordRounds', int(MutDemoRec(self.myMut).bRecordRounds));
        self.SetIntPropertyByName('bAdminOnlyCommands', int(MutDemoRec(self.myMut).bAdminOnlyCommands));
        self.SetIntPropertyByName('bDemoGunfire', int(!MutDemoRec(self.myMut).bDisableDemoGunfire));
        self.SetIntPropertyByName('bDemoViewer', int(!MutDemoRec(self.myMut).bDisableDemoViewer));
        self.SetIntPropertyByName('bDemoAmbient', int(!MutDemoRec(self.myMut).bDisableDemoAmbient));
    }
}

function SaveMutSettings()
{
    local int Record, AdminOnly, Gunfire, Viewer, Ambient;

    self.GetIntPropertyByName('bRecordRounds', Record);
    self.GetIntPropertyByName('bAdminOnlyCommands', AdminOnly);
    self.GetIntPropertyByName('bDemoGunfire', Gunfire);
    self.GetIntPropertyByName('bDemoViewer', Viewer);
    self.GetIntPropertyByName('bDemoAmbient', Ambient);

    if (self.myMut == None)
    {
        class'MutDemoRec'.default.bRecordRounds = (Record != 0);
        class'MutDemoRec'.default.bAdminOnlyCommands = (AdminOnly != 0);
        class'MutDemoRec'.default.bDisableDemoGunfire = (Gunfire == 0);
        class'MutDemoRec'.default.bDisableDemoViewer = (Viewer == 0);
        class'MutDemoRec'.default.bDisableDemoAmbient = (Ambient == 0);
        class'MutDemoRec'.static.StaticSaveConfig();
    }
    else
    {
        MutDemoRec(self.myMut).bRecordRounds = (Record != 0);
        MutDemoRec(self.myMut).bAdminOnlyCommands = (AdminOnly != 0);
        MutDemoRec(self.myMut).bDisableDemoGunfire = (Gunfire == 0);
        MutDemoRec(self.myMut).bDisableDemoViewer = (Viewer == 0);
        MutDemoRec(self.myMut).bDisableDemoAmbient = (Ambient == 0);
        self.myMut.SaveConfig();
    }
}

// The WebAdmin page: one tab per group, a plain label for each setting, every on/off setting as On / Off buttons. The
// group names and labels are in the .int file (Localization\INT\MutDemoRec.int, section [MutDemoRecSettings]), in the
// same order as below.
defaultproperties
{
    SettingsGroups.Add((GroupID="Recording",pMin=100,pMax=110,lMin=0,lMax=0))
    SettingsGroups.Add((GroupID="Playback",pMin=110,pMax=120,lMin=0,lMax=0))

    Properties.Add((PropertyId=100,Data=(Type=SDT_Int32,Value1=0)))
    PropertyMappings.Add((Id=100,Name="bRecordRounds",MappingType=PVMT_IdMapped,ValueMappings=((Id=0),(Id=1))))
    Properties.Add((PropertyId=101,Data=(Type=SDT_Int32,Value1=0)))
    PropertyMappings.Add((Id=101,Name="bAdminOnlyCommands",MappingType=PVMT_IdMapped,ValueMappings=((Id=0),(Id=1))))

    Properties.Add((PropertyId=110,Data=(Type=SDT_Int32,Value1=0)))
    PropertyMappings.Add((Id=110,Name="bDemoGunfire",MappingType=PVMT_IdMapped,ValueMappings=((Id=0),(Id=1))))
    Properties.Add((PropertyId=111,Data=(Type=SDT_Int32,Value1=0)))
    PropertyMappings.Add((Id=111,Name="bDemoViewer",MappingType=PVMT_IdMapped,ValueMappings=((Id=0),(Id=1))))
    Properties.Add((PropertyId=112,Data=(Type=SDT_Int32,Value1=0)))
    PropertyMappings.Add((Id=112,Name="bDemoAmbient",MappingType=PVMT_IdMapped,ValueMappings=((Id=0),(Id=1))))
}
