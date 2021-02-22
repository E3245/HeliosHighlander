//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIConbatLose
//  AUTHOR:  Brit Steiner -- 4/2/12 
//  PURPOSE: Special tactical game lost screen. 
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UICombatLose extends UIScreen
	dependson(UIDialogueBox);

enum UICombatLoseOption
{
	eUICombatLoseOpt_Restart,
	eUICombatLoseOpt_Reload,
	eUICombatLoseOpt_ExitToMain,
};


var localized string m_sGenericTitle;
var localized string m_sGenericBody;
var localized string m_sObjectiveTitle;
var localized string m_sObjectiveBody;
var localized string m_sCampaignTitle;
var localized string m_sCampaignBody;
var localized string m_sCommanderKilledTitle;
var localized string m_sCommanderKilledBody;
var localized string m_sSubtitle;

var localized string m_sRestart;
var localized string m_sReload; 
var localized string m_sExitToMain;

var localized string m_kExitGameDialogue_title;
var localized string m_kExitGameDialogue_body; 
var localized string m_sAccept; 
var localized string m_sCancel;

var localized string m_sReloadDisabledTooltip;

var UICombatLoseType m_eType; 
var UIButton Button0;
var UIButton Button1;
var UIButton Button2;
var UIButton Button3;

var UINavigationHelp NavHelp;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{	
	local UIPanel ButtonGroup;
	
	super.InitScreen(InitController, InitMovie, InitName);

	ButtonGroup = Spawn(class'UIPanel', self);
	ButtonGroup.bAnimateOnInit = false;
	ButtonGroup.bIsNavigable = true;
	ButtonGroup.InitPanel('ButtonGroup', '');
	ButtonGroup.bCascadeFocus = false;

	Button0 = Spawn(class'UIButton', ButtonGroup);
	Button0.bAnimateOnInit = false;
	Button0.SetResizeToText(false);
	Button0.InitButton('Button0', `MAKECAPS(class'UIPauseMenu'.default.m_sRestartEncounter), RequestRestartEncounter, eUIButtonStyle_NONE);

	Button1 = Spawn(class'UIButton', ButtonGroup);
	Button1.bAnimateOnInit = false;
	Button1.SetResizeToText(false);
	Button1.InitButton('Button1', m_sRestart, RequestRestart, eUIButtonStyle_NONE);

	Button2 = Spawn(class'UIButton', ButtonGroup);
	Button2.bAnimateOnInit = false;
	Button2.SetResizeToText(false);
	Button2.InitButton('Button2', m_sReload, RequestLoad, eUIButtonStyle_NONE);

	// mmg_john.hawley (11/18/19) - Disable loading during launch chunk. Can lead to states not available yet in the game.
	if (!class'GameEngine'.static.GetOnlineSubsystem().IsGameDownloaded())
	{
		Button2.DisableButton();
	}

	Button3 = Spawn(class'UIButton', ButtonGroup);
	Button3.bAnimateOnInit = false; 
	Button3.SetResizeToText(false);
	Button3.InitButton('Button3', m_sExitToMain, RequestExit, eUIButtonStyle_NONE);


	Navigator.Clear();
	Navigator.AddControl(Button0);
	Navigator.AddControl(Button1);
	Navigator.AddControl(Button2);
	Navigator.AddControl(Button3);

	//We're hijacking the pause menu override of the input methods here, to allow the Steam controller to switch the input mode in Tactical to use the menu mode. 
	`BATTLE.m_bInPauseMenu = true;
	
	//bsg-crobinson (5.4.17): Spawn and update navhelp
	NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();
	UpdateNavHelp();
	//bsg-crobinson (5.4.17): end

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).UpdateResources(self);	
	// HELIOS END
}

//----------------------------------------------------------------------------
//	Set default values.
//
simulated function OnInit()
{
	local XComGameState_CampaignSettings CampaignSettingsStateObject;
	local string ReloadString, RestartLevelString;
	local string RestartEncounterString;

	super.OnInit();

	ReloadString = m_sReload;
	RestartLevelString = m_sRestart;
	RestartEncounterString = `MAKECAPS(class'UIPauseMenu'.default.m_sRestartEncounter);


	CampaignSettingsStateObject = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings', true));
	if (CampaignSettingsStateObject.bHardcoreEnabled)
	{
		RestartEncounterString = "";
		RestartLevelString = "";
		ReloadString = "";

		Button0.Hide();
		Button1.Hide();
		Button2.Hide();
	}
	else
	{
		if (CampaignSettingsStateObject.bIronmanEnabled)
		{
			RestartEncounterString = "";
			RestartLevelString = m_sRestart;
			ReloadString = "";
		
			Button0.Hide();
			Button1.Show();
			Button2.Hide();
		}
		else
		{
			ReloadString = m_sReload;
			RestartLevelString = m_sRestart;
			RestartEncounterString = `MAKECAPS(class'UIPauseMenu'.default.m_sRestartEncounter);

			Button0.Show();
			Button1.Show();
			Button2.Show();
		}
	}
	
	switch( m_eType )
	{
		case eUICombatLose_UnfailableGeneric:
		case eUICombatLose_UnfailableCommanderKilled:
			AS_SetDisplay(m_sGenericTitle, m_sGenericBody, class'UIUtilities_Image'.const.LossScreenNarrativeImage, m_sSubtitle, RestartEncounterString, RestartLevelString, ReloadString, m_sExitToMain);
			break;
		case eUICombatLose_UnfailableObjective:
			AS_SetDisplay(m_sObjectiveTitle, m_sObjectiveBody, class'UIUtilities_Image'.const.LossScreenNarrativeImage, m_sSubtitle, RestartEncounterString, RestartLevelString, ReloadString, m_sExitToMain);
			break;
		case eUICombatLose_UnfailableHQAssault: 
			AS_SetDisplay(m_sCampaignTitle, m_sCampaignBody, class'UIUtilities_Image'.const.LossScreenNarrativeImage, m_sSubtitle, "", "", ReloadString, m_sExitToMain);
			Button0.Hide();
			Button1.Hide();
			break;
		
	}

	Show();
}

//bsg-crobinson (5.4.17): navhelp updating, typical lose/receive focus behavior
simulated function UpdateNavHelp()
{
	NavHelp.ClearButtonHelp();
	NavHelp.AnchorBottomLeft();
	NavHelp.AddSelectNavHelp();
}

simulated function OnLoseFocus()
{
	NavHelp.ClearButtonHelp();
	super.OnLoseFocus();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
}
//bsg-crobinson (5.4.17): end

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if(!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return true;

	// TODO: Need a custom implementation for keyboard / gamepad (track selected index and set button's focus state manually)

	return super.OnUnrealCommand(cmd, arg);
}

function RequestRestartEncounter(UIButton Button)
{
	`XCOMVISUALIZATIONMGR.DisableForShutdown();
	PC.RestartEncounter();
}

simulated function RequestRestart(UIButton Button)
{
	if (m_eType == eUICombatLose_UnfailableHQAssault)
	{
		// TODO: Rewind campaign 5 days
		CloseScreen();
	}
	else
	{
		//Turn the visualization mgr off while the map shuts down / seamless travel starts
		`XCOMVISUALIZATIONMGR.DisableForShutdown();
		PC.RestartLevel();
	}
}
simulated function RequestLoad(UIButton Button)
{
	Movie.Pres.UILoadScreen(); 
}
simulated function RequestExit(UIButton Button)
{
	local TDialogueBoxData      kDialogData;
	
	kDialogData.eType       = eDialog_Warning;
	kDialogData.strTitle	= m_kExitGameDialogue_title;
	kDialogData.strText     = m_kExitGameDialogue_body; 
	kDialogData.fnCallback  = ExitGameDialogueCallback;

	kDialogData.strAccept = m_sAccept; 
	kDialogData.strCancel = m_sCancel; 

	Movie.Pres.UIRaiseDialog( kDialogData );
}

simulated public function ExitGameDialogueCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		`BATTLE.m_bInPauseMenu = false;
		Movie.Pres.UIEndGame();
		`XCOMHISTORY.ResetHistory();
		ConsoleCommand("disconnect");
	}
	else if( eAction == 'eUIAction_Cancel' )
	{
		//Nothing
	}
}

simulated protected function AS_SetDisplay( string title, string body, string image, string subtitle, string button0Label, string button1Label, string button2Label, string button3Label )
{
	Movie.ActionScriptVoid(screen.MCPath$".SetDisplay");
}



	
DefaultProperties
{
	Package   = "/ package/gfxCombatLose/CombatLose";
	MCName      = "theCombatLoseScreen";
	bConsumeMouseEvents = true;
	InputState= eInputState_Consume;
}
