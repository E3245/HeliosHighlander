//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_Helios_Overhaul.uc
//           
//	The X2DownloadableContentInfo class provides basic hooks into XCOM gameplay events. 
//  Ex. behavior when the player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_Helios_Overhaul extends X2DownloadableContentInfo config (Game);

var config string Version;
var config string Build;

/// <summary>
/// Called after the Templates have been created (but before they are validated) while this DLC / Mod is installed.
/// </summary>
static event OnPostTemplatesCreated()
{
	`log("Loaded Highlander, codename HELIOS. Version: " $ default.Version $ ", Build: " $ default.Build, true , 'Helios_Overhaul');
	
	// Guard against crashing
	if (class'HSHelpers' != none)
	{
		class'HSHelpers'.static.RebuildPerkContentCache();

		// Begin HELIOS Issue #39
		class'HSHelpers'.static.GenerateMarkupMapCompatibility();
		// End HELIOS Issue #39
	}
	else
	{
		`log("WARNING: HSHelpers was not found! This can cause problems in the future!", true , 'Helios_Overhaul');
	}
}
