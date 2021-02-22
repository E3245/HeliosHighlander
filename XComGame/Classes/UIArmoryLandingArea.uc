//---------------------------------------------------------------------------------------
//  FILE:    	UIArmoryLandingArea
//  AUTHOR:  	Brit Steiner 8/14/2019
//  PURPOSE: 	UI screen to armory without any unit selected. 
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIArmoryLandingArea extends UIScreen;

var UIDIOHUD m_HUD;
var UIX2ScreenHeader FacilityHeader;
var int				m_SelectedUnit;

var localized string m_strScreenHeader; 

simulated function OnInit()
{
	local XComStrategyPresentationLayer StratPres;

	super.OnInit();
	RegisterForEvents();

	StratPres = XComStrategyPresentationLayer(Movie.Pres);
	StratPres.RefreshCamera(class'XComStrategyPresentationLayer'.const.ArmoryAreaTag);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END
	m_HUD.UpdateResources(self);
	UpdateNavHelp();

	InitializeFacilityHeader();

	// On entering Armory landing, check first for viewed tutorial
	if (`TutorialEnabled == false || StratPres.HasSeenTutorial('StrategyTutorial_DiscoverArmory'))
	{
		if (`DIOHQ.PendingSquadUnlocks > 0)
		{
			StratPres.UIUnlockCharacter();
		}
	}	
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_CharacterUnlocked_Submitted', OnCharacterUnlocked, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_CharacterUnlocked_Submitted');
}

simulated function InitializeFacilityHeader()
{
	FacilityHeader = Spawn(class'UIX2ScreenHeader', self);
	FacilityHeader.InitScreenHeader('FacilityHeader');
	FacilityHeader.AnchorTopLeft();
	FacilityHeader.DisableNavigation();
	FacilityHeader.SetText(m_strScreenHeader, "");
}

simulated function OnReceiveFocus()
{
	local XComStrategyPresentationLayer StratPres;
	local int i;

	super.OnReceiveFocus();
	StratPres = XComStrategyPresentationLayer(Movie.Pres);

	StratPres.RefreshCamera(class'XComStrategyPresentationLayer'.const.ArmoryAreaTag);
	m_HUD.UpdateResources(self);
	UpdateNavHelp();
	
	for (i = 0; i < m_HUD.m_ArmoryUnitHeads.Length; i++)
	{
		if (i == m_SelectedUnit)
		{
			m_HUD.m_ArmoryUnitHeads[i].OnReceiveFocus();
		}
		else
		{
			m_HUD.m_ArmoryUnitHeads[i].OnLoseFocus();
		}
	}

	// Recheck to raise UnlockCharacter UI if returning to this screen after viewing tutorial
	if (`TutorialEnabled == false || StratPres.HasSeenTutorial('StrategyTutorial_DiscoverArmory'))
	{
		if (`DIOHQ.PendingSquadUnlocks > 0)
		{
			StratPres.UIUnlockCharacter();
		}
	}
}

simulated function UpdateNavHelp()
{
	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.AddBackButton(CloseScreen);
	m_HUD.NavHelp.AddSelectNavHelp(); // mmg_john.hawley (11/5/19) - Updating NavHelp for new controls
	if (`ISCONTROLLERACTIVE)
	{
		m_HUD.NavHelp.AddLeftHelp(Caps(class'UIArmory_MainMenu'.default.ChangeSoldierLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1);
	}
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnCharacterUnlocked(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	return ELR_NoInterrupt;
}

simulated function SelectNextUnit()
{
	m_HUD.m_ArmoryUnitHeads[m_SelectedUnit].OnLoseFocus();

	m_SelectedUnit++;
	if (m_SelectedUnit == m_HUD.m_ArmoryUnitHeads.Length)
	{
		m_SelectedUnit = 0;
	}

	m_HUD.m_ArmoryUnitHeads[m_SelectedUnit].OnReceiveFocus();
}

simulated function SelectPreviousUnit()
{
	m_HUD.m_ArmoryUnitHeads[m_SelectedUnit].OnLoseFocus();
	
	m_SelectedUnit--;
	if (m_SelectedUnit < 0)
	{
		m_SelectedUnit = m_HUD.m_ArmoryUnitHeads.Length - 1;
	}

	m_HUD.m_ArmoryUnitHeads[m_SelectedUnit].OnReceiveFocus();
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local StateObjectReference TargetUnitRef;

	// Only pay attention to presses or repeats; ignoring other input types
	if( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	switch( cmd )
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
		PlayMouseClickSound();
		//Just to keep controller able to get to the units! Future: need to nav the bottom heads in UIDIIOHUD.
		TargetUnitRef.ObjectID = m_HUD.m_ArmoryUnitHeads[m_SelectedUnit].WorkerObjectID;
		`PRESBASE.UIArmorySelectUnit(TargetUnitRef);
		break; 
	case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER :
		PlayMouseOverSound();
		SelectNextUnit();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER :
		PlayMouseOverSound();
		SelectPreviousUnit();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		PlayMouseClickSound();
		CloseScreen();
		break;
	default:
		break;
	}

	return true;
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	UnRegisterForEvents();
	super.CloseScreen();
}
