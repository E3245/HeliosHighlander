// Borrowed from X2WotCCommunityHighlander
// XComGame.u cannot see this package when retrieving the version number so we cannot edit the Shell directly to perform this change
class UISL_Shell_Helios extends UIScreenListener config(Game);

var config bool bEnableVersionDisplay;

event OnInit(UIScreen Screen)
{
	if(UIShell(Screen) == none || !bEnableVersionDisplay)  // this captures UIShell and UIFinalShell
		return;

	`LOG("Shell Screen Called",,'Helios_Overhaul');

	// Generate the version text
	RealizeVersionText(UIShell(Screen));
}

event OnReceiveFocus(UIScreen Screen)
{
	if(UIShell(Screen) == none || !bEnableVersionDisplay)  // this captures UIShell and UIFinalShell
		return;

	RealizeVersionText(UIShell(Screen));
}

//event OnRemoved(UIScreen Screen)
//{
//	if(UIShell(Screen) == none || !bEnableVersionDisplay)  // this captures UIShell and UIFinalShell
//		return;
//}

function RealizeVersionText(UIShell ShellScreen)
{
    local UIText VersionDisplay;
	local string VersionString;

	VersionDisplay = UIText(ShellScreen.GetChildByName('theVersionText', false));

	if (VersionDisplay == none)
	{
		VersionDisplay = ShellScreen.Spawn(class'UIText', ShellScreen);
		VersionDisplay.InitText('theVersionText');
		// This code aligns the version text to the Main Menu Ticker
		VersionDisplay.AnchorBottomCenter();
		VersionDisplay.SetY(-ShellScreen.TickerHeight + 10);

		VersionString = "Codename Helios loaded, Version: " $ class'X2DownloadableContentInfo_Helios_Overhaul'.default.Version;
		VersionDisplay.SetHTMLText(VersionString);
	
		`LOG("Version Text Created: " $ VersionString $", Object: " $ VersionDisplay,,'Helios_Overhaul');		
	}
}

defaultProperties
{
	ScreenClass = none
}
