// Borrowed from X2WotCCommunityHighlander
// XComGame.u cannot see this package when retrieving the version number so we cannot edit the Shell directly to perform this change
class UISL_Shell_Helios extends UIScreenListener config(Game);

var config bool bEnableVersionDisplay;
var config bool bAnchorOnBottom;

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

		// Bottom Display
		if (bAnchorOnBottom)
		{
			VersionDisplay.AnchorBottomLeft().SetY(-ShellScreen.TickerHeight + 10);
		}
		// Top Display
		else
		{
			VersionDisplay.AnchorTopLeft();
		}
		
		VersionDisplay.SetWidth(ShellScreen.Movie.m_v2ScaledFullscreenDimension.X);

		VersionString = class'UIUtilities_Text'.static.AlignCenter("Codename Helios loaded, Version: " $ class'X2DownloadableContentInfo_Helios_Overhaul'.default.Version $ "[" $ class'X2DownloadableContentInfo_Helios_Overhaul'.default.Build $ "]");
		VersionDisplay.SetHTMLText(VersionString);
	
		`LOG("Version Text Created: " $ VersionString $", Object: " $ VersionDisplay,,'Helios_Overhaul');		
	}
}

defaultProperties
{
	ScreenClass = none
}
