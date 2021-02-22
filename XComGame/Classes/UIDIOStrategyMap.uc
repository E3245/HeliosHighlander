//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategy
//  AUTHOR:  	Joe Cortese  --  10/16/2018
//  PURPOSE: 	HUD for Dio strategy layer.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIDIOStrategyMap extends UIScreen implements(UIDioAutotestInterface);

var array<UIDIOStrategyMapDistrict>	DistrictUIs;
var UINavigationHelp				NavHelp;
var UIButton						m_FlashVersionButton;
var UIDIOHUD						m_HUD;

// HUD elements
var UITextContainer					m_MapLegend;

var int								m_selectedDistrict;
var int								GridPadding;

//----------------------------------------------------------------------------

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local XComGameState_DioCity City;
	local int i, j, k;	

	City = `DIOCITY;
	super.InitScreen(InitController, InitMovie, InitName);
	
	for (i = 0; i < 3; i++) // height
	{
		for (j = 0; j < 3; j++) // width
		{
			// 1D array index
			k = (i * 3) + j;
			if (k < City.CityDistricts.Length)
			{
				InitNewDistrictDisplay(i, j, City.CityDistricts[k]);
			}
		}
	}

	m_MapLegend = Spawn(class'UITextContainer', self);
	m_MapLegend.bAnimateOnInit = false;
	m_MapLegend.InitTextContainer('MapLegend', , GridPadding, 960, 640, 48, true);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	NavHelp = InitController.Pres.GetNavHelp();
	if (NavHelp == none) // Tactical
	{
		NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();
	}
	UpdateNavHelp();

	DistrictUIs[m_selectedDistrict].bSelected = true;

	RegisterForEvents();	
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	UpdateNavHelp();
	RefreshAll();
	class'UIUtilities_DioStrategy'.static.GetStrategyPres().UIShowComp(class'UICompPopUp'.const.COMP_CITY_MAP);
}

//---------------------------------------------------------------------------------------
simulated function Show()
{
	super.Show();
	CheckImperativeActions();
}

simulated function GoToFlash(UIButton Button)
{
	if (`ScreenStack.IsNotInStack(class'UIDIOStrategyMapFlash'))
	{
		`ScreenStack.Push(Spawn(class'UIDIOStrategyMapFlash', self));
	}
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted', OnExecuteStrategyAction, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_RevertStrategyAction_Submitted', OnRevertStrategyAction, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_CollectionAddedWorker_Submitted', OnWorkerPlacementChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_CollectionRemovedWorker_Submitted', OnWorkerPlacementChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_WorkerMaskedChanged_Submitted', OnWorkerMaskChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_InvestigationStarted_Submitted', OnInvestigationStarted, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_TurnChanged_Submitted', OnTurnChanged, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_RevertStrategyAction_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_CollectionAddedWorker_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_CollectionRemovedWorker_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_WorkerMaskedChanged_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_InvestigationStarted_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_TurnChanged_Submitted');
}

//---------------------------------------------------------------------------------------
//				DISPLAY
//---------------------------------------------------------------------------------------

function InitNewDistrictDisplay(int GridX, int GridY, StateObjectReference CityDistrictRef)
{
	local int xPos, yPos;
	local UIDIOStrategyMapDistrict DistrictUI;

	DistrictUI = Spawn(class'UIDIOStrategyMapDistrict', self);
	DistrictUI.bAnimateOnInit = false;
	DistrictUI.InitStrategyMapDistrict(CityDistrictRef);
	
	xPos = GridPadding + (GridX * (DistrictUI.Width + GridPadding));
	yPos = 0 + (GridY * (DistrictUI.Height + GridPadding));
	DistrictUI.SetPosition(xPos, yPos);

	DistrictUIs.AddItem(DistrictUI);
}

//---------------------------------------------------------------------------------------
simulated function RefreshAll()
{
	local int i;

	m_HUD.RefreshAll();
	for (i = 0; i < DistrictUIs.Length; i++)
	{
		DistrictUIs[i].RefreshDisplay();
	}

	m_MapLegend.SetHTMLText(BuildMapLegendString());
}

//---------------------------------------------------------------------------------------
// If any current actions are imperative, push their popup immediately
function CheckImperativeActions()
{
	// DIO DEPRECATED [8/27/2019 dmcdonough]
}

//---------------------------------------------------------------------------------------
static function string BuildMapLegendString()
{
	// DIO DEPRECATED [8/21/2019 dmcdonough]
	return "";
}

//---------------------------------------------------------------------------------------
function UpdateNavHelp()
{
	NavHelp.ClearButtonHelp();

	NavHelp.AddBackButton(OnCancel);
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
	NavHelp.ClearButtonHelp();

	UnRegisterForEvents();
	//Return to the HQ overview area ( none for event data )
	`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', none, self, none);

	NavHelp.Remove();

	super.CloseScreen();
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
function EventListenerReturn OnRevertStrategyAction(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
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

//---------------------------------------------------------------------------------------
function EventListenerReturn OnWorkerMaskChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnWorkerPlacementChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_DioWorkerCollection Collection;
	local int i;

	Collection = XComGameState_DioWorkerCollection(EventSource);
	if (Collection == none)
		return ELR_NoInterrupt;

	for (i = 0; i < DistrictUIs.Length; ++i)
	{
		if (DistrictUIs[i].m_DistrictRef == Collection.ParentRef)
		{
			DistrictUIs[i].RefreshDisplay();
			break;
		}
	}

	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnInvestigationStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	// Only allow releases through past this point.
	if ((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0)
	{
		return false;
	}

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
		CloseScreen();
		return true;
		break;
	case class'UIUtilities_Input'.const.FXS_DPAD_UP :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP :
	case class'UIUtilities_Input'.const.FXS_ARROW_UP :

		DistrictUIs[m_selectedDistrict].bSelected = false;
		DistrictUIs[m_selectedDistrict].RefreshDisplay();

		m_selectedDistrict -= 1;
		if (m_selectedDistrict < 0)
		{
			m_selectedDistrict = 9 + m_selectedDistrict;
		}

		DistrictUIs[m_selectedDistrict].bSelected = true;
		DistrictUIs[m_selectedDistrict].RefreshDisplay();
		break;

	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT :
	case class'UIUtilities_Input'.const.FXS_ARROW_RIGHT :

		DistrictUIs[m_selectedDistrict].bSelected = false;
		DistrictUIs[m_selectedDistrict].RefreshDisplay();

		m_selectedDistrict += 3;
		if (m_selectedDistrict >= 9)
		{
			m_selectedDistrict = m_selectedDistrict - 9;
		}

		DistrictUIs[m_selectedDistrict].bSelected = true;
		DistrictUIs[m_selectedDistrict].RefreshDisplay();
		break;

	case class'UIUtilities_Input'.const.FXS_DPAD_DOWN :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN :
	case class'UIUtilities_Input'.const.FXS_ARROW_DOWN :
		DistrictUIs[m_selectedDistrict].bSelected = false;
		DistrictUIs[m_selectedDistrict].RefreshDisplay();

		m_selectedDistrict += 1;
		if (m_selectedDistrict >= 9)
		{
			m_selectedDistrict = m_selectedDistrict - 9;
		}

		DistrictUIs[m_selectedDistrict].bSelected = true;
		DistrictUIs[m_selectedDistrict].RefreshDisplay();
		break;

	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
	case class'UIUtilities_Input'.const.FXS_ARROW_LEFT :

		DistrictUIs[m_selectedDistrict].bSelected = false;
		DistrictUIs[m_selectedDistrict].RefreshDisplay();

		m_selectedDistrict -= 3;
		if (m_selectedDistrict < 0)
		{
			m_selectedDistrict = 9 + m_selectedDistrict;
		}

		DistrictUIs[m_selectedDistrict].bSelected = true;
		DistrictUIs[m_selectedDistrict].RefreshDisplay();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		DistrictUIs[m_selectedDistrict].SimulateScreenInteraction();
		break;
	default:
		break;
	}

	m_HUD.OnUnrealCommand(cmd, arg);

	return true;
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	m_HUD.UpdateResources(self);
}

//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{	
	local array<UIDIOStrategyMapDistrict> DistrictEntries;
	local UIDIOStrategyMapDistrict DistrictEntry;

	// Cache all the regions
	foreach AllActors(class'UIDIOStrategyMapDistrict', DistrictEntry)
	{	
		DistrictEntries.AddItem(DistrictEntry);
	}

	// Try to enter a region with a mission first, if one is available
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

//---------------------------------------------------------------------------------------
DefaultProperties
{
	InputState = eInputState_Evaluate;
	GridPadding = 20
	m_selectedDistrict = 0;
}

