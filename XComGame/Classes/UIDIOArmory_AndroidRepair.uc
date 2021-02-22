//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOArmory_AndroidRepair
//  AUTHOR:  	David McDonough  --  4/19/2019
//  PURPOSE: 	(Graybox) screen for repairing Android damage.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOArmory_AndroidRepair extends UIArmory;

var UITextContainer MainContainer;
var UIButton RepairOneButton;
var UIButton RepairAllButton;

var localized string ScreenTitleLabel;
var localized string ScreenDescription;
var localized string TagStr_RepairOne;
var localized string TagStr_RepairAll;

//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
simulated function InitArmory_AndroidRepair(StateObjectReference UnitRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	super.InitArmory(UnitRef, DispEvent, SoldSpawnEvent, NavBackEvent, HideEvent, RemoveEvent, bInstant, InitCheckGameState);
	
	MainContainer = Spawn(class'UITextContainer', self).InitTextContainer('MainContainer', , 0, 0, Width, Height, true);
	MainContainer.AnchorCenter();
	MainContainer.SetPosition(-(Width / 2), -(Height / 2));
	MainContainer.SetCenteredText(`DIO_UI.static.FormatSubheader(ScreenTitleLabel, eUIState_Good, 40));

	RepairOneButton = Spawn(class'UIButton', MainContainer).InitButton('Repair1', "", OnRepairOneButton);
	RepairOneButton.SetPosition(0, MainContainer.Height - 128);
	RepairOneButton.SetSize(Width, 64);

	RepairAllButton = Spawn(class'UIButton', MainContainer).InitButton('RepairAll', "", OnRepairAllButton);
	RepairAllButton.SetPosition(0, MainContainer.Height - 64);
	RepairAllButton.SetSize(Width, 64);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END		
	m_HUD.UpdateResources(self);

	UpdateNavHelp();
	RegisterForEvents();
	Refresh();
	UpdateNavHelp();
} 

simulated static function bool CanCycleTo(XComGameState_Unit Unit)
{
	return Unit.IsAndroid();
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_AndroidRepaired_Submitted', OnAndroidRepaired, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
		SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_AndroidRepaired_Submitted');
}

//---------------------------------------------------------------------------------------
//				DISPLAY
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
simulated private function Refresh()
{
	local XComGameState_Unit Unit;
	local XGParamTag LocTag;
	local string TempString, FormattedString, StatLabel;
	local int CurHP, MaxHP, Cost;
	local bool bDisableButton;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
	if (Unit == none)
	{
		return;
	}
	CurHP = Unit.GetCurrentStat(eStat_HP);
	MaxHP = Unit.GetMaxStat(eStat_HP);
	StatLabel = class'X2TacticalGameRulesetDataStructures'.default.m_aCharStatLabels[eStat_HP];

	// Unit Name
	FormattedString = `DIO_UI.static.FormatSubheader(Unit.GetNickName());

	// HP info
	TempString = StatLabel $ ":" @ CurHP $ "/" $ MaxHP;
	TempString = `DIO_UI.static.FormatSubheader(TempString, eUIState_Normal, 40);
	FormattedString $= "\n" $ TempString;

	// Description
	TempString = `DIO_UI.static.FormatBody(ScreenDescription);
	FormattedString $= "\n\n" $ TempString;
	
	// Button labels
	Cost = class'DioStrategyAI'.static.GetAndroidRepairCost(UnitReference);
	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.IntValue0 = Cost;
	TempString = `XEXPAND.ExpandString(TagStr_RepairOne);
	RepairOneButton.SetText(TempString);

	bDisableButton = (CurHP == MaxHP) || `DIOHQ.Credits < Cost;
	RepairOneButton.SetDisabled(bDisableButton);

	Cost = class'DioStrategyAI'.static.GetAndroidRepairCost(UnitReference, true);
	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.IntValue0 = Cost;
	TempString = `XEXPAND.ExpandString(TagStr_RepairAll);
	RepairAllButton.SetText(TempString);

	bDisableButton = (CurHP >= (MaxHP - 1)) || `DIOHQ.Credits < Cost;
	RepairAllButton.SetDisabled(bDisableButton);

	MainContainer.SetCenteredText(FormattedString);
}

//---------------------------------------------------------------------------------------
simulated function UpdateNavHelp()
{
	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.AddBackButton(OnCancel);
}

//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------

function EventListenerReturn OnAndroidRepaired(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	Refresh();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------
function OnRepairOneButton(UIButton Button)
{
	local X2StrategyGameRuleset StratRules;
	local string AkEventName;

	AkEventName = "UI_Strategy_Android_Repair_Confirm";
	`SOUNDMGR.PlayAkEventDirect(AkEventName, self);
	StratRules = `STRATEGYRULES;
	StratRules.SubmitRepairAndroid(UnitReference, false);
}

//---------------------------------------------------------------------------------------
function OnRepairAllButton(UIButton Button)
{
	local X2StrategyGameRuleset StratRules;
	local string AkEventName;

	AkEventName = "UI_Strategy_Android_Repair_Confirm";
	`SOUNDMGR.PlayAkEventDirect(AkEventName, self);
	StratRules = `STRATEGYRULES;
	StratRules.SubmitRepairAndroid(UnitReference, true);
}

//---------------------------------------------------------------------------------------
// override in child classes to provide custom behavior
simulated function OnCancel()
{
	PlayMouseClickSound();
	CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	UnRegisterForEvents();
	super.CloseScreen();
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	Width = 512
	Height = 512
}