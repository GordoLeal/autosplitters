state("Patrick")
{
}

startup
{
    // ApplicationManager:Awake pointer to ApplicationManager.instance
    vars.AppManAwakeScanTarget = new SigScanTarget(17,"55 48 8B EC 48 83 EC 30 48 89 75 F8 48 8B F1 48 B8 ?? ?? ?? ?? ?? ?? ?? ?? 48 89 30 48 89 45 F0 48 B9 ?? ?? ?? ?? ?? ?? ?? ?? 48 8D 6D 00 49 BB ?? ?? ?? ?? ?? ?? ?? ?? 41 FF D3 48 8B 45 F0 C6 46 35 00 49 BA ?? ?? ?? ?? ?? ?? ?? ?? 90");
    // PHL_MissionManager:Awake pointer to instance of itself
    //vars.MissionManagerScanTarget = new SigScanTarget(14,"55 48 8B EC 48 83 EC 30 48 89 4D F8 48 B8 ?? ?? ?? ?? ?? ?? ?? ?? 48 8B 4D F8 48 89 08 48 89 45 F0 48 B9 ?? ?? ?? ?? ?? ?? ?? ?? 66 66 90 49 BB ?? ?? ?? ?? ?? ?? ?? ?? 41 FF D3 48 8B 45 F0 48 8D 65 00 5D C3");
    // CameraManager:UpdateCaches - current position vector 3 static pointer
    vars.CameraCurrentPositionScanTarget = new SigScanTarget(77,"55 48 8B EC 48 83 EC 60 48 89 75 F8 48 8B F1 48 8B 46 48 48 8B C8 83 38 00 48 8D 64 24 00 49 BB ?? ?? ?? ?? ?? ?? ?? ?? 41 FF D3 48 8B D5 48 83 C2 E0 48 8B C8 83 38 00 48 8D 64 24 00 90 49 BB ?? ?? ?? ?? ?? ?? ?? ?? 41 FF D3 48 B8 ?? ?? ?? ?? ?? ?? ?? ??");

    vars.scanning = new Func<SigScanTarget, Process, IntPtr>((signa, gameProc) => {
        
        IntPtr ptr = IntPtr.Zero;
        foreach (var memModule in gameProc.MemoryPages(true).Reverse())
        {
            var scanner = new SignatureScanner(gameProc, memModule.BaseAddress, (int)memModule.RegionSize);
            ptr = scanner.Scan(signa);
            if(ptr != IntPtr.Zero){
                IntPtr asa = (IntPtr)BitConverter.ToInt64(gameProc.ReadBytes(ptr,8), 0);
                return asa;
            }
        }
        return ptr;
    }
    );
}

init
{
    //Signature read.
    vars.camPosPtr = IntPtr.Zero;
    vars.awakePtr = IntPtr.Zero;
    vars.awakePtr = vars.scanning(vars.AppManAwakeScanTarget,game);
    //camPosPtr = vars.scanning(vars.CameraCurrentPositionScanTarget,game);
    if(vars.awakePtr == IntPtr.Zero)
    {
        //If for some reason the game takes a lot of time to boot up and we still need to take take awake ptr, just throw exception and let autosplitter deal with it.
        throw new Exception();
    }
    else{
        print("ApplicationManager:Awake Signature Found");
    }

    vars.Watchers = new MemoryWatcherList
    {
        new MemoryWatcher<int>(new DeepPointer(vars.awakePtr,0x30)){Name = "GameLevelState"}, //currentApplicationState - ApplicationStateEnum = {Boot=0, LogoTrain=1, MainMenu=2, Game=3}
    };

    vars.CheckingThread = new Thread(() =>
    {
        vars.camPosPtr = vars.scanning(vars.CameraCurrentPositionScanTarget,game);
        //Probably still on menu or in a scene that don't have the CameraManager loaded.
        if(vars.camPosPtr != IntPtr.Zero){
            vars.Watchers.Add(new MemoryWatcher<float>((vars.camPosPtr+0x0)){Name = "CameraPositionX"});
            vars.Watchers.Add(new MemoryWatcher<float>((vars.camPosPtr+0x4)){Name = "CameraPositionY"});
            vars.Watchers.Add(new MemoryWatcher<float>((vars.camPosPtr+0x8)){Name = "CameraPositionZ"});

        }
    });
    timer.Run.Offset = TimeSpan.FromSeconds(-0.91f);
}   
start
{
    if(vars.Watchers["GameLevelState"].Old == 2 && vars.Watchers["GameLevelState"].Current == 3)
    {
        timer.Run.Offset = TimeSpan.FromSeconds(-0.91f);
        return true;
    }
    return false;
}

update
{
    vars.Watchers.UpdateAll(game);
    if(vars.awakePtr != IntPtr.Zero){
        // If we are in game, and we still don't have the camera position pointer, try to load it.
        if(vars.Watchers["GameLevelState"].Current == 3 && vars.camPosPtr == IntPtr.Zero && !vars.CheckingThread.IsAlive)
        {
            vars.CheckingThread.Start();
        }    
    }
}

split
{
    // If camera is in the final cutscene position
    if(vars.camPosPtr != IntPtr.Zero)
    if(vars.Watchers["CameraPositionY"].Current > 76f && vars.Watchers["CameraPositionY"].Current < 78f)
        if(vars.Watchers["CameraPositionZ"].Current < -63f && vars.Watchers["CameraPositionZ"].Current > -65f)
            if(vars.Watchers["CameraPositionX"].Current <-73f && vars.Watchers["CameraPositionX"].Current > -75f)
                return true;
else if (vars.camPosPtr == IntPtr.Zero){
    print("ainda tá errado");
}
    return false;
}