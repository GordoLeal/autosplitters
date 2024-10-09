state("Patrick") { }

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
	//Game sets the applicationstate to "game"(3) ~0.91 seconds before removing the loading UI.
    vars.TargetOffset = TimeSpan.FromSeconds(-0.91);
    vars.PreviousOffset = TimeSpan.Zero;
}

onStart
{
    timer.Run.Offset = vars.PreviousOffset;
}

init
{
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
	mono.Images.Clear();
        //ApplicationState enum = Boot, OnLogo, OnMainMenu, inGame
        vars.Helper["GameLevelState"] = mono.Make<int>("ApplicationManager", "instance", "applicationState"); 
        vars.Helper["CameraPosition"] = mono.Make<Vector3f>("CameraManager", "cameraPosition3D");

        return true;
    });
}

start
{
    if (old.GameLevelState == 2 && current.GameLevelState == 3)
    {
        vars.PreviousOffset = timer.Run.Offset;
        timer.Run.Offset = vars.TargetOffset;

        return true;
    }
}

split
{
	//Check if camera is on final cutscene position.
	//Observation for future maintainers: if this results in false positive (very rare if not impossible since the position is oob and semi-precise)
	//Fix for this would be to check for current mission Step inside EventManager, the final cutscene event state is 4.
    return current.CameraPosition.X > -75f && current.CameraPosition.X < -73f
        && current.CameraPosition.Y >  76f && current.CameraPosition.Y <  78f
        && current.CameraPosition.Z > -65f && current.CameraPosition.Z < -63f;
}
