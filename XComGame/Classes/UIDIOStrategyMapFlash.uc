//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategy
//  AUTHOR:  	Joe Cortese  --  10/16/2018
//  PURPOSE: 	HUD for Dio strategy layer.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIDIOStrategyMapFlash extends UIScreen 
	implements(UIDioAutotestInterface, UIDIOIconSwap)
	config(UI);

// HUD elements
var UIDIOHUD						m_HUD;
var bool m_bTutorialSeen;
var UIFieldTeamHUD					m_FieldTeamHUD;

var array<UIDIOStrategyMap_CityDistrict>		 m_districts;

var int		m_selectedDistrict;
var bool	bInPlacementMode;
var bool	bInFieldTeamPlaceMode;
var bool	bInFieldTeamAbilityTargetMode;
var X2FieldTeamEffectTemplate m_TargetingFieldTeamEffect;

var string	m_CitywideUnrestHelpImage;
var localized String	m_strBuyFieldTeam;
var localized String	m_strModifyFieldTeam;
var localized string	m_WarningBuildFieldTeamTitle;
var localized string	m_WarningBuildFieldTeamText;
var localized string	m_CitywideUnrestTitle;
var localized string	m_strOpenAssignment;
var localized string	m_WarningNoFieldTeam;
var localized string	m_WorkerUnavailableTitle;
var localized string	m_SelectAbilityLabel;
var localized string	m_TutorialMustBuildFieldTeamTitle;
var localized string	m_TutorialMustBuildFieldTeamBody;

var config float displayTimeForUnrestDelta; 

//----------------------------------------------------------------------------

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{	
	local int i;

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	m_HUD.UpdateResources(self);
	m_FieldTeamHUD = m_HUD.FieldTeamHUD;

	super.InitScreen(InitController, InitMovie, InitName);
	SetY(`MAPTOPOFFSET); // mmg_aaron.lee (10/31/19) - allow to edit through global.uci
	m_bTutorialSeen = false;

	for(i = 0; i < 9; i++)
	{
		m_districts.AddItem(Spawn(class'UIDIOStrategyMap_CityDistrict', self).InitCityDistrict(name("Region_" $ i), `DIOCITY.CityDistricts[i], i));
	}

	Navigator.Clear();
	for (i = 0; i < 9; i++)
	{
		Navigator.AddControl(m_districts[i]);
	}
	Navigator.OnlyUsesNavTargets = true;
	Navigator.UsesNavTargetsIfNotHandled = true;
	if(`ISCONTROLLERACTIVE)
		Navigator.SetSelected(m_districts[0]);

	SetupNavTargets();

	RegisterForEvents();
	AddOnRemovedDelegate(UnRegisterForEventsFailsafe);
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	RefreshAll();
	UpdateNavHelp();
	`STRATPRES.UITryCampaignLoseWarning();

	if( `STRATPRES.AnimateDistrictUnrestChanges )
	{
		SetTimer(displayTimeForUnrestDelta, false, nameof(ClearPrevTurnUnrestGlow), self);
	}

	RaiseValidPopups();
}

function ClearPrevTurnUnrestGlow()
{
	local int i;

	`STRATPRES.AnimateDistrictUnrestChanges = false;

	for (i = 0; i < m_districts.Length; i++)
	{
		if (m_districts[i].bIsInited)
		{
			m_districts[i].ClearAllStatusMeterGlow();
		}
	}
}

simulated function UpdateCityLocations()
{
	local int i;

	for (i = 0; i < 9; i++)
	{
		if(m_districts[i].bIsInited)
			m_districts[i].UpdateData();
	}
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'UIEvent_StartPlaceFieldTeam_Immediate', OnBuildFieldTeamStarted, ELD_Immediate);
	EventManager.RegisterForEvent(SelfObject, 'UIEvent_CancelPlaceFieldTeam_Immediate', OnBuildFieldTeamEnded, ELD_Immediate);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamTargetingDeactivated', OnBuildFieldTeamEnded, ELD_Immediate);
	EventManager.RegisterForEvent(SelfObject, 'UIEvent_StartTargetFieldTeamAbility_Immediate', OnTargetFieldTeamAbilityStarted, ELD_Immediate);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted', OnExecuteStrategyAction, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_RevertStrategyAction_Submitted', OnRevertStrategyAction, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_CollectionAddedWorker_Submitted', OnWorkerPlacementChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_CollectionRemovedWorker_Submitted', OnWorkerPlacementChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_WorkerMaskedChanged_Submitted', OnWorkerMaskChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamCreated_Submitted', OnFieldTeamCreated, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamEffectActivated_Submitted', OnFieldTeamEffectActivated, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_InvestigationStarted_Submitted', OnInvestigationStarted, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_CityDistrictUnrestChanged_Submitted', OnUnrestChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_OverallCityUnrestChanged_Submitted', OnUnrestChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_TurnChanged_Submitted', OnTurnChanged, ELD_OnStateSubmitted);
}

function UnRegisterForEventsFailsafe(UIPanel Panel)
{
	UnRegisterForEvents();
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromAllEvents(SelfObject);
}

//---------------------------------------------------------------------------------------
//				INPUT HANDLER
//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local int PreviousSelectedIndex;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	// mmg_john.hawley - don't let input through when on APC
	// HELIOS BEGIN
	if (`SCREENSTACK.IsInStack(`PRESBASE.SquadSelect))
	// HELIOS END
	{
		return true;
	}

	if (m_HUD.m_WorkerTray.bIsVisible)
	{
		if (m_HUD.m_WorkerTray.OnUnrealCommand(cmd, arg))
		{
			return true;
		}
		else if(m_HUD.m_ScreensNav.GetBubbleAssignedTo('APC').OnUnrealCommand(cmd, arg))
		{
			return true;
		}
	}

	// mmg_john.hawley - If abilities are available, check if we get a valid input from the class
	if (m_FieldTeamHUD.bIsVisible && m_FieldTeamHUD.OnUnrealCommand(cmd, arg))
	{
		return true;
	}
	
	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
		OnDistrictSelected(m_districts[Navigator.SelectedIndex].m_districtNum, m_districts[Navigator.SelectedIndex].m_SelectionIdx);
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		if (m_HUD.m_WorkerTray.bIsVisible)
		{
			m_HUD.m_WorkerTray.Hide();
		}
		else
		{
			PlayMouseClickSound();
			CloseScreen();
		}
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_Y :
		OnClickFieldTeamButton(m_districts[Navigator.SelectedIndex].DistrictRef);
		PlayMouseClickSound();
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_X :
		m_HUD.m_ScreensNav.GetBubbleAssignedTo('APC').OnUnrealCommand(cmd, arg);
		break;

	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP :
	case class'UIUtilities_Input'.const.FXS_DPAD_UP :
	case class'UIUtilities_Input'.const.FXS_ARROW_UP :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT :
	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
	case class'UIUtilities_Input'.const.FXS_ARROW_RIGHT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN :
	case class'UIUtilities_Input'.const.FXS_DPAD_DOWN :
	case class'UIUtilities_Input'.const.FXS_ARROW_DOWN :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
	case class'UIUtilities_Input'.const.FXS_ARROW_LEFT :
		PreviousSelectedIndex = Navigator.SelectedIndex;
		super.OnUnrealCommand(cmd, arg);
		if (Navigator.SelectedIndex != PreviousSelectedIndex)
		{
			PlayMouseOverSound();
		}
		return true;

	default:
		Super.OnUnrealCommand(cmd, arg);
	}

	return true;
}

simulated function SetupNavTargets()
{
	m_districts[0].Navigator.AddNavTargetRight(m_districts[3]);
	m_districts[0].Navigator.AddNavTargetDown(m_districts[1]);

	m_districts[1].Navigator.AddNavTargetRight(m_districts[4]);
	m_districts[1].Navigator.AddNavTargetUp(m_districts[0]);
	m_districts[1].Navigator.AddNavTargetDown(m_districts[2]);

	m_districts[2].Navigator.AddNavTargetRight(m_districts[5]);
	m_districts[2].Navigator.AddNavTargetUp(m_districts[1]);

	m_districts[3].Navigator.AddNavTargetRight(m_districts[6]);
	m_districts[3].Navigator.AddNavTargetLeft(m_districts[0]);
	m_districts[3].Navigator.AddNavTargetDown(m_districts[4]);

	m_districts[4].Navigator.AddNavTargetRight(m_districts[7]);
	m_districts[4].Navigator.AddNavTargetLeft(m_districts[1]);
	m_districts[4].Navigator.AddNavTargetUp(m_districts[3]);
	m_districts[4].Navigator.AddNavTargetDown(m_districts[5]);

	m_districts[5].Navigator.AddNavTargetLeft(m_districts[2]);
	m_districts[5].Navigator.AddNavTargetRight(m_districts[8]);
	m_districts[5].Navigator.AddNavTargetUp(m_districts[4]);

	m_districts[6].Navigator.AddNavTargetLeft(m_districts[3]);
	m_districts[6].Navigator.AddNavTargetDown(m_districts[7]);

	m_districts[7].Navigator.AddNavTargetLeft(m_districts[4]);
	m_districts[7].Navigator.AddNavTargetUp(m_districts[6]);
	m_districts[7].Navigator.AddNavTargetDown(m_districts[8]);

	m_districts[8].Navigator.AddNavTargetLeft(m_districts[5]);
	m_districts[8].Navigator.AddNavTargetUp(m_districts[7]);
}

//---------------------------------------------------------------------------------------
//				DISPLAY
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
simulated function RefreshAll()
{
	UpdateCityLocations();	
	//m_FieldTeamHUD.UpdateData();
}

//---------------------------------------------------------------------------------------
function UpdateNavHelp()
{
	local XComGameStateHistory History;
	local XComGameState_FieldTeam FieldTeam;
	local XComGameState_DioCityDistrict District;

	History = `XCOMHISTORY;
	if( m_selectedDistrict < m_districts.length )
		District = XComGameState_DioCityDistrict(History.GetGameStateForObjectID(m_districts[m_selectedDistrict].DistrictRef.ObjectID));

	FieldTeam = District.GetFieldTeam();

	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.bIsVerticalHelp = true;
	m_HUD.NavHelp.AddBackButton(OnCancel);

	// mmg_john.hawley (11/7/19) - Updating NavHelp
	if (`ISCONTROLLERACTIVE)
	{
		m_HUD.NavHelp.AddSelectNavHelp(); // mmg_john.hawley (11/5/19) - Updating NavHelp for new controls
		m_HUD.NavHelp.AddLeftHelp(Caps(m_strOpenAssignment), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);

		if (class'DioStrategyTutorialHelper'.static.AreFieldTeamsAvailable())
		{
			if (FieldTeam == none)
			{
				m_HUD.NavHelp.AddLeftHelp(Caps(m_strBuyFieldTeam), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
			}
			else
			{
				m_HUD.NavHelp.AddLeftHelp(Caps(m_strModifyFieldTeam), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
			}
		}

		// mmg_john.hawley (11/25/19) - Check if any bubble besides map is selectable before drawing NavHelp
		/*if (m_HUD.m_assignments[1].bIsVisible || m_HUD.m_assignments[2].bIsVisible || m_HUD.m_assignments[3].bIsVisible)
		{
			m_HUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyScreenNavigation'.default.SelectHQAreaLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1);
		}*/

		if (m_FieldTeamHUD.bIsVisible)
		{
			m_HUD.NavHelp.AddLeftHelp(Caps(m_SelectAbilityLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LTRT_L2R2);
		}

		if (Navigator.GetSelected() == none)
		{
			Navigator.SetSelected(m_districts[0]); // mmg_john.hawley (11/8/19) - Fix case where controller cannot select districts if mouse entered strategymap
		}
	}
	else
	{
		Navigator.OnLoseFocus();// mmg_john.hawley (11/8/19) -unhighlight district when swapping to mouse
	}
}

//---------------------------------------------------------------------------------------
// override in child classes to provide custom behavior
simulated function OnCancel()
{
	CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	// Intercept: can't leave if tutorial requires FT build
	if (MustBuildFieldTeam())
	{
		RaiseMustBuildFieldTeamAlert();
		return;
	}

	UnRegisterForEvents(); 

	bInFieldTeamPlaceMode = false;
	bInFieldTeamAbilityTargetMode = false;
	m_TargetingFieldTeamEffect = none;

	`STRATPRES.AnimateDistrictUnrestChanges = false;

	//Return to the HQ overview area ( none for event data )
	`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', none, self, none);	
	super.CloseScreen();
}

simulated function OnMouseEvent(int cmd, array<string> args) // mmg_john.hawley TODO: Make controller equivalent?
{
	local int districtStarted, actionSelected;
	local string AkEventName;

	if (!`ISCONTROLLERACTIVE && InStr(args[6], "regionButton") != -1)
	{
		districtStarted = int(GetRightMost(args[4]));

		switch (cmd)
		{
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN :
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER :
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OVER :
			m_districts[districtStarted].OnReceiveFocus();
			break;

		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OUT:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OUT:
			m_districts[districtStarted].OnLoseFocus();
			break;
		}
	}

	if (cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_UP)
	{
		if(InStr(args[6], "regionButton") != -1)
		{
			PlayMouseClickSound();

			districtStarted = int(GetRightMost(args[4]));

			m_districts[districtStarted].FTSelectionEmitter.Activate();

			OnDistrictTargeted(districtStarted);
		}
		else if (InStr(args[4], "Region") != -1)
		{
			districtStarted = int(GetRightMost(args[4]));
			actionSelected = int(GetRightMost(args[5]));

			OnDistrictSelected(districtStarted, actionSelected);
		}
	}
	else
	{
		switch (cmd)
		{
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_UP :
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_DOUBLE_UP :
			if (!bInFieldTeamAbilityTargetMode)
			{
				AkEventName = "UI_Global_Click_Normal";
				`SOUNDMGR.PlayAkEventDirect(AkEventName, self);
			}
			break;
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN :
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER :
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OVER :
			AkEventName = "UI_Global_Mouseover";
			`SOUNDMGR.PlayAkEventDirect(AkEventName, self);
			break;
		}
	}
}

simulated function OnDistrictTargeted(int districtNum)
{
	local UIDIOStrategyMap_CityDistrict SelectedDistrict;
	local XComGameState_DioCityDistrict District;	

	if (districtNum < 0 || districtNum >= m_districts.Length)
	{
		return;
	}

	SelectedDistrict = m_districts[districtNum];
	District = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(SelectedDistrict.DistrictRef.ObjectID));
	if (District != none)
	{
		`XEVENTMGR.TriggerEvent('UIEvent_DistrictTargetSelected_Immediate', District, none, none);
	}
}

simulated function OnDistrictSelected(int districtNum, int selectionIdx)
{
	local StateObjectReference SelectionRef, DistrictRef;
	local XComGameState_BaseObject SelectedObject;

	SelectionRef = m_districts[districtNum].SelectionRefs[selectionIdx];
	SelectedObject = `XCOMHISTORY.GetGameStateForObjectID(SelectionRef.ObjectID);
	
	if (!ClassIsChildOf(SelectedObject.Class, class'XComGameState_DioWorker'))
	{
		PlayNegativeMouseClickSound();
		return;
	}
	
	// Intercept: can't view mission if tutorial requires FT build
	if (MustBuildFieldTeam())
	{
		PlayNegativeMouseClickSound();
		RaiseMustBuildFieldTeamAlert();
		return;
	}
	// Early out: APC doesn't have enough agents to run any mission
	else if (`DIOHQ.APCRoster.Length < 4)
	{
		`STRATPRES.UIWarningDialog(`DIO_UI.default.strTerm_APCShort, `DIO_UI.default.strStatus_APCShorthanded, eDialog_Alert);
		PlayNegativeMouseClickSound();
	}
	// Intercept: if targeting a field ability, treat action selections as district selections
	else if (m_FieldTeamHUD.bTargetingActive)
	{
		PlayMouseClickSound();
		DistrictRef = m_districts[districtNum].DistrictRef;

		if (m_FieldTeamHUD.ActiveTargetingAbility != none &&
			m_FieldTeamHUD.ActiveTargetingAbility.m_FieldTeamAbilityTemplate.CanTargetDistrict(DistrictRef))
		{
			OnDistrictTargeted(districtNum);
		}
	}
	else
	{
		PlayMouseClickSound();
		`STRATPRES.UIWorkerReview(SelectionRef);
	}
}

simulated function OnClickFieldTeamButton(StateObjectReference DistrictRef)
{
	local XComGameState_FieldTeam FieldTeam;
	local XComGameState_DioCityDistrict District;

	if (!class'DioStrategyTutorialHelper'.static.AreFieldTeamsAvailable())
	{
		return;
	}

	District = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(DistrictRef.ObjectID));
	FieldTeam = District.GetFieldTeam();
	`STRATPRES.UIFieldTeamReview(FieldTeam.GetReference(), DistrictRef);
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	m_HUD.UpdateResources(self);
	RefreshAll();

	// HELIOS BEGIN
	`PRESBASE.RefreshCamera(class'XComStrategyPresentationLayer'.const.MapAreaTag);
	// HELIOS END

	UpdateNavHelp();

	if (`STRATPRES.AnimateDistrictUnrestChanges)
	{
		SetTimer(displayTimeForUnrestDelta, false, nameof(ClearPrevTurnUnrestGlow), self);
	}

	RaiseValidPopups();
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	m_HUD.NavHelp.ClearButtonHelp();
	ClearTimer(nameof(ClearPrevTurnUnrestGlow));
}

//---------------------------------------------------------------------------------------
// If any rules changed require alerting the player, raise them now
function RaiseValidPopups()
{
	local XComGameState_Investigation Investigation;
	local XComStrategyPresentationLayer StratPres;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_CampaignGoal Goal;
	local X2DioCampaignGoalTemplate GoalTemplate;

	StratPres = `STRATPRES;
	DioHQ = `DIOHQ;
	Investigation = class'DioStrategyAI'.static.GetCurrentInvestigation();

	// Unrest Intensifies
	if (Investigation.Act == 2)
	{
		if (!StratPres.HasSeenTutorial('StrategyTutorial_UnrestIntensifiesAct2'))
		{
			Goal = DioHQ.GetCampaignGoal();
			GoalTemplate = Goal.GetMyTemplate();
			if (GoalTemplate.DoesUnrestIntensifyForAct(Investigation.Act - 1)) // Index
			{
				StratPres.UIRaiseTutorial('StrategyTutorial_UnrestIntensifiesAct2', self);
			}
		}
	}
	else if (Investigation.Act == 3)
	{
		if (!StratPres.HasSeenTutorial('StrategyTutorial_UnrestIntensifiesAct3'))
		{
			Goal = DioHQ.GetCampaignGoal();
			GoalTemplate = Goal.GetMyTemplate();
			if (GoalTemplate.DoesUnrestIntensifyForAct(Investigation.Act - 1)) // Index
			{
				StratPres.UIRaiseTutorial('StrategyTutorial_UnrestIntensifiesAct3', self);
			}
		}
	}
}

//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------

function EventListenerReturn OnExecuteStrategyAction(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnTurnChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnWorkerPlacementChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnRevertStrategyAction(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnWorkerMaskChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnFieldTeamCreated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnFieldTeamEffectActivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnInvestigationStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnUnrestChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnBuildFieldTeamStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	bInFieldTeamPlaceMode = true;
	bInFieldTeamAbilityTargetMode = false;
	return ELR_NoInterrupt;
}

function EventListenerReturn OnBuildFieldTeamEnded(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	bInFieldTeamPlaceMode = false;
	bInFieldTeamAbilityTargetMode = false;
	return ELR_NoInterrupt;
}

function EventListenerReturn OnTargetFieldTeamAbilityStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	m_TargetingFieldTeamEffect = X2FieldTeamEffectTemplate(EventData);
	bInFieldTeamAbilityTargetMode = true;
	bInFieldTeamPlaceMode = false;
	return ELR_NoInterrupt;
}

function EventListenerReturn OnTargetFieldTeamAbilityEnded(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	bInFieldTeamPlaceMode = false;
	bInFieldTeamAbilityTargetMode = false;
	m_TargetingFieldTeamEffect = none;
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function int GetDistrictIndex(StateObjectReference DistrictRef)
{
	local int i; 

	for( i = 0; i < 9; i++ )
	{
		if( m_districts[i].DistrictRef == DistrictRef )
		{
			return i;
		}
	}
	return -1;
}

//---------------------------------------------------------------------------------------
//				Tutorial Handling
//---------------------------------------------------------------------------------------
static function bool MustBuildFieldTeam()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}

	// FTs not yet opened by tutorial
	if (class'DioStrategyTutorialHelper'.static.IsFieldTeamsTutorialLocked())
	{
		return false;
	}

	return class'DioStrategyTutorialHelper'.static.CountFieldTeams() == 0;
}

//---------------------------------------------------------------------------------------
function RaiseMustBuildFieldTeamAlert()
{
	`STRATPRES.UIWarningDialog(m_TutorialMustBuildFieldTeamTitle, m_TutorialMustBuildFieldTeamBody, eDialog_Alert);
}

//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{
	local array<UIDIOStrategyMapDistrict> DistrictEntries;
	local UIDIOStrategyMapDistrict DistrictEntry;

	// Cache all the districts
	foreach AllActors(class'UIDIOStrategyMapDistrict', DistrictEntry)
	{
		DistrictEntries.AddItem(DistrictEntry);
	}

	// Try to enter a district with a mission first, if one is available`
	foreach DistrictEntries(DistrictEntry)
	{
		if (DistrictEntry.NumMissions > 0)
		{
			if (DistrictEntry.SimulateScreenInteraction())
			{
				return true;
			}
		}
	}

	// Try to start any random action
	DistrictEntries.RandomizeOrder();
	foreach DistrictEntries(DistrictEntry)
	{
		if (DistrictEntry.NumOther > 0)
		{
			if (DistrictEntry.SimulateScreenInteraction())
			{
				return true;
			}
		}
	}

	// No actions anywhere, end the round
	`log("AUTOTESTMGR: Strategy Play - no available activities, ending the round...", , 'XComLogLevel1');
	m_HUD.m_TurnControls.OnTurnButton(none);

	return true;
}

// mmg_john.hawley (12/9/19) - Update NavHelp ++ 
function IconSwapPlus(bool IsMouse)
{
	if (`SCREENSTACK.IsTopScreen(self))
	{
		UpdateNavHelp();
	}
}

//---------------------------------------------------------------------------------------
DefaultProperties
{
	Package = "/ package/gfxDIOCityMap/DIOCityMap";
	MCName = "theCityScreen";

	bHideOnLoseFocus = true;
	bAutoSelectFirstNavigable=false
	bInPlacementMode=false
	bInFieldTeamPlaceMode=false
		bInFieldTeamAbilityTargetMode=false
	InputState = eInputState_Evaluate;
	m_selectedDistrict = 0;

}

