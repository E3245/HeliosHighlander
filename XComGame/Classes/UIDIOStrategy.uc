//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategy
//  AUTHOR:  	Joe Cortese  --  10/16/2018
//  PURPOSE: 	HUD for Dio strategy layer.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIDIOStrategy extends UIScreen implements(UIDioAutotestInterface, UIDIOIconSwap)
	config(GameCore);

var UIList m_ActionStatusList;
var UIList m_ForecastList;

var UIDIOHUD m_HUD;

// HUD elements

var UIDIOShiftBriefing				m_ShiftBriefing;

var float Margin;
var float ForecastListHeight;

// Text
var localized string ForecastLabel;
var localized string ForecastNoEvents;
var localized string TagStr_ForecastEntryThisTurn;
var localized string TagStr_ForecastEntry;

//----------------------------------------------------------------------------

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);	

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END
	
	UpdateNavHelp();

	RegisterForEvents();
	RefreshCamera();
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	RefreshAll();
	m_HUD.UpdateResources(self);
	m_HUD.m_ScreensNav.Navigator.SelectFirstAvailable();
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
simulated function Show()
{
	super.Show();
	RefreshAll();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted', OnExecuteStrategyAction, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_InvestigationStarted_Submitted', OnInvestigationStarted, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_RoundChanged_Submitted', OnTurnOrRoundChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_TurnChanged_Submitted', OnTurnOrRoundChanged, ELD_OnStateSubmitted);
}

function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
		SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_InvestigationStarted_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_RoundChanged_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_TurnChanged_Submitted');
}

//---------------------------------------------------------------------------------------
//				INPUT HANDLERS
//---------------------------------------------------------------------------------------

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled; // Has input been 'consumed'?

	// Only allow releases through past this point.
	if ((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0)
	{
		return false;
	}

	if (Navigator.OnUnrealCommand(cmd, arg))
	{
		return true;
	}

	// Route input based on the cmd
	switch (cmd)
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_L3 :
			ShowResourceInfoPopup();
			bHandled = true;
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_B :
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
			//If the tray is open, close it up! 
			// HELIOS BEGIN
			// Refer to the hud stored in this class instead on invoking presentation layer
			m_HUD.m_WorkerTray.Hide();
			// HELIOS END
			return true;
			break;

		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
		case class'UIUtilities_Input'.const.FXS_BUTTON_START :
			if(AllowedToEsc())
			{
				bHandled = true;
				// HELIOS BEGIN
				// Short-hand version of the `PRESBASE macro
				`PRESBASE.UIPauseMenu(false, false);
				// HELIOS END
			}
			break;
		default:
			bHandled = false;
			break;
	}

	//Pass input up the chain if we didn't handle it
	if (!bHandled)
	{
		bHandled = super.OnUnrealCommand(cmd, arg);
	}	

	return bHandled;
}

function bool AllowedToEsc()
{
	local UIDayTransitionScreen DayScreen; 
	// HELIOS BEGIN
	DayScreen = UIDayTransitionScreen(`SCREENSTACK.GetScreen(`PRESBASE.UIDayTransitionScreen));
	//HELIOS END
	if(DayScreen != none && DayScreen.bIsFocused)
	{
		return false;
	}

	return true; 
}

function UpdateNavHelp()
{
	local UIDIOStrategyMap_AssignmentBubble SelectedBubble;
	//local XComGameState_DioWorker CriticalMissionWorker;

	m_HUD.NavHelp.ClearButtonHelp();

	if (`ISCONTROLLERACTIVE)
	{
		m_HUD.NavHelp.bIsVerticalHelp = true;
		m_HUD.NavHelp.AddSelectNavHelp(); // mmg_john.hawley (11/5/19) - Updating NavHelp for new controls
		SelectedBubble = m_HUD.m_ScreensNav.GetControllerSelectedBubble();
		if (SelectedBubble != none && SelectedBubble.ValidForWorkerAssignment())
		{
			m_HUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyScreenNavigation'.default.AgentSelectionMenu), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);
			m_HUD.NavHelp.AddLeftHelp(Caps(class'UIArmory'.default.ChangeSoldierLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_DPAD_HORIZONTAL);
		}

		m_HUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyScreenNavigation'.default.MenuLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_DPAD_VERTICAL);
		m_HUD.NavHelp.AddLeftHelp(`MAKECAPS(class'UIDayTransitionScreen_EndOfDayPanel'.default.Label_QuietNight), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LSTICK);
	}
	else
	{
		m_HUD.NavHelp.AddPauseButton();
		m_HUD.NavHelp.AddDetailsButton();
	}
}

// Console path to view tooltip and status info on City Anarchy and Resources
static function ShowResourceInfoPopup()
{
	local XComGameState_HeadquartersDio DioHQ;
	local string Title, Text, TempHeader, TempDesc;

	DioHQ = `DIOHQ;

	// City Anarchy
	TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatWarningHeader(class'UIDIOStrategyMapFlash'.default.m_CitywideUnrestTitle);
	TempDesc = class'UIDIOCityUnrest_Tooltip'.static.BuildTooltipDescription();
	if (TempHeader != "" && TempDesc != "")
		Text $= TempHeader $ "\n" $ TempDesc $ "\n\n";

	// Credits
	TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatGoodHeader(`DIO_UI.default.strTerm_Credits);
	TempDesc = class'UIDIOResourceHeader'.static.BuildTooltipString_Credits();
	if (TempHeader != "" && TempDesc != "")
		Text $= TempHeader $ "\n" $ TempDesc $ "\n\n";

	// Intel
	if (!class'DioStrategyTutorialHelper'.static.IsIntelResourceTutorialLocked())
	{
		TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatGoodHeader(`DIO_UI.default.strTerm_Intel);
		TempDesc = class'UIDIOResourceHeader'.static.BuildTooltipString_Intel();
		if (TempHeader != "" && TempDesc != "")
			Text $= TempHeader $ "\n" $ TempDesc $ "\n\n";
	}

	// Elerium
	if (!class'DioStrategyTutorialHelper'.static.IsEleriumResourceTutorialLocked())
	{
		TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatGoodHeader(`DIO_UI.default.strTerm_Elerium);
		TempDesc = class'UIDIOResourceHeader'.static.BuildTooltipString_Elerium();
		if (TempHeader != "" && TempDesc != "")
			Text $= TempHeader $ "\n" $ TempDesc $ "\n\n";
	}

	// Free Field Teams (if any)
	if (class'DioStrategyTutorialHelper'.static.AreFieldTeamsAvailable() && DioHQ.FreeFieldTeamBuilds > 0)
	{
		TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatGoodHeader(`DIO_UI.default.strTerm_FreeFieldTeamPlural);
		TempDesc = class'UIDIOResourceHeader'.static.BuildTooltipString_Elerium();
		if (TempHeader != "" && TempDesc != "")
			Text $= TempHeader $ "\n" $ TempDesc $ "\n\n";
	}

	Title = `MAKECAPS(class'UIDayTransitionScreen_EndOfDayPanel'.default.Label_QuietNight);
	`STRATPRES.UIWarningDialog(Title, Text, eDialog_Normal);
}


// override in child classes to provide custom behavior
simulated function OnExitStrategy()
{
	`STRATPRES.UIConfirmLeaveCampaign();
}

simulated function CloseScreen()
{
	m_HUD.NavHelp.ClearButtonHelp();
	UnRegisterForEvents();
	super.CloseScreen();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	m_HUD.UpdateResources(self);
	UpdateNavHelp();
	RefreshCamera();
}

function RefreshCamera()
{
	// HELIOS BEGIN
	// Re-route
	`PRESBASE.RefreshCamera(class'XComStrategyPresentationLayer'.const.HQOverviewAreaTag);
	// HELIOS END
}

//---------------------------------------------------------------------------------------
//				DISPLAY LOGIC
//---------------------------------------------------------------------------------------
simulated function RefreshAll()
{
	m_HUD.RefreshAll();
	//m_OperationStatus.RefreshAll();
	//m_ShiftBriefing.RefreshAll();	
}

//---------------------------------------------------------------------------------------
simulated function OnTextRealized()
{
	m_ForecastList.RealizeList();
}

//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------
function EventListenerReturn OnResourceChange(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnExecuteStrategyAction(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnInvestigationStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnTurnOrRoundChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function BlockUntilStreamingInstallComplete()
{
	local TProgressDialogData kProgressDialogData;
	local string ProgressStringText; 
	ProgressStringText = class'UIPauseMenu'.default.m_sChunkLocked $ " - " $ int(class'GameEngine'.static.GetOnlineSubsystem().GameDownloadInterface.GetOverallProgress() * 100) $ "%"; 

	if (!class'GameEngine'.static.GetOnlineSubsystem().IsGameDownloaded())
	{
		kProgressDialogData.strDescription = ProgressStringText;
		kProgressDialogData.strAbortButtonText = "";
		kProgressDialogData.bStreamingInstall = true;
		`PRESBASE.UIProgressDialog(kProgressDialogData);
	}
}

//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{
	//Confirm we are in an appropriate state to start performing actions
	if (`STRATEGYRULES.IsInState('TurnRound_Actions'))
	{
		m_HUD.m_ScreensNav.OnClickMapScreen();
		return true;
	}
	return false;
}

// mmg_john.hawley (12/9/19) - Update NavHelp ++ 
function IconSwapPlus(bool IsMouse)
{
	// mmg_john.hawley (12/10/19) - Prevent this screen from overwriting NavHelp on strategy screens that are pushed on top of it
	// HELIOS BEGIN
	// Reference the class in the Primary Strategy Layer
	if (`SCREENSTACK.GetCurrentScreen().IsA(`PRESBASE.UIPrimaryStrategyLayer.Name))
	{
		UpdateNavHelp();
	}
	// HELIOS END
}

//---------------------------------------------------------------------------------------
DefaultProperties
{
	bHideOnLoseFocus = false;
	Margin = 16;
	ForecastListHeight=160
}

