//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIDayTransitionScreen
//  AUTHOR:  Brit Steiner --  09/03/2019
//  PURPOSE: Controls the day shift black out / time animation transition. 
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIDayTransitionScreen extends UIScreen;

var localized string Yesterday_Field1;
var localized string Yesterday_Field2;
var localized string Yesterday_Field3;
var localized string Today_Field1;
var localized string Today_Field2;
var localized string Today_Field3;
var localized string SkipMessage;
var localized string Tooltip_Payday;
var localized string Tooltip_PaydayEmpty;
var localized string Tooltip_NormalDay;

var bool bWantToSkip;

var UIText SkipInfo; 

var UIDayTransitionScreen_EndOfDayPanel EndOfDayPanel; 

// Constructor
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);
	Movie.InsertHighestDepthScreen(self); //This screen will show depth in front of others 

	EndOfDayPanel = Spawn(class'UIDayTransitionScreen_EndOfDayPanel', self);
	EndOfDayPanel.InitEndOfDayPanel();
	
	InitializeTooltipData();
	RegisterForEvents();
	ShowSteady();
	Hide();
}

function RegisterForEvents()
{
	local Object SelfObject;

	SelfObject = self;

	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamTargetingActivated', OnFieldTeamTargetingActivated, ELD_Immediate, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamTargetingDeactivated', OnFieldTeamTargetingDeactivated, ELD_Immediate, , );
}

event Destroyed()
{
	local Object SelfObject;

	SelfObject = self;

	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamTargetingActivated');
	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamTargetingDeactivated');
}

simulated protected function UpdateData()
{
	local XComGameState_GameTime TodayGameTime;
	local TDateTime YesterdayDateTime, TodayDateTime;
	local XGParamTag LocTag;
	local string YesterdayField1, YesterdayField2, YesterdayField3, TodayField1, TodayField2, TodayField3, DayOfWeek, DateStr, MonthStr, YearStr;

	TodayGameTime = class'UIUtilities_Strategy'.static.GetGameTime();
	TodayDateTime = TodayGameTime.CurrentTime;
	YesterdayDateTime = TodayDateTime;
	class'X2StrategyGameRulesetDataStructures'.static.SubtractDay(YesterdayDateTime);

	// ------------------

	//YESTERDAY'S DATE 
	DayOfWeek	= class'X2StrategyGameRulesetDataStructures'.static.GetDayOfTheWeekString(YesterdayDateTime);
	DateStr		= string(YesterdayDateTime.m_iDay);
	MonthStr	= class'X2StrategyGameRulesetDataStructures'.static.GetMonthString(YesterdayDateTime.m_iMonth);
	YearStr		= string(YesterdayDateTime.m_iYear);

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = DayOfWeek;
	LocTag.StrValue1 = DateStr;
	LocTag.StrValue2 = MonthStr;
	LocTag.StrValue3 = YearStr;

	YesterdayField1 = `XEXPAND.ExpandString(Yesterday_Field1);
	YesterdayField2 = `XEXPAND.ExpandString(Yesterday_Field2);
	YesterdayField3 = `XEXPAND.ExpandString(Yesterday_Field3);

	// ------------------
	// TODAY'S DATE 
	DayOfWeek   = class'X2StrategyGameRulesetDataStructures'.static.GetDayOfTheWeekString(TodayDateTime);
	DateStr		= string(TodayDateTime.m_iDay);
	MonthStr	= class'X2StrategyGameRulesetDataStructures'.static.GetMonthString(TodayDateTime.m_iMonth);
	YearStr		= string(TodayDateTime.m_iYear);

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = DayOfWeek;
	LocTag.StrValue1 = DateStr;
	LocTag.StrValue2 = MonthStr;
	LocTag.StrValue3 = YearStr;
	TodayField1 = `XEXPAND.ExpandString(Today_Field1);
	TodayField2 = `XEXPAND.ExpandString(Today_Field2);
	TodayField3 = `XEXPAND.ExpandString(Today_Field3);

	// ------------------

	//SetDisplayInfo(  "WEDNESDAY", "13 AUGUST", "2019",
	//				   "THURSDAY", "14 AUGUST", "2019");

	MC.BeginFunctionOp("SetDisplayInfo");
	MC.QueueString(YesterdayField1);
	MC.QueueString(YesterdayField2);
	MC.QueueString(YesterdayField3);
	MC.QueueString(TodayField1);
	MC.QueueString(TodayField2);
	MC.QueueString(TodayField3);
	MC.EndOp();
}

function HideClock()
{
	MC.BeginFunctionOp("SetDisplayInfo");
	MC.QueueString("");
	MC.QueueString("");
	MC.QueueString("");
	MC.QueueString("");
	MC.QueueString("");
	MC.QueueString("");
	MC.EndOp();
}

function AnimateTransition()
{
	UpdateData();
	bWantToSkip = false;
	bIsFocused = true;

	`SOUNDMGR.PlayLoadedAkEvent("UI_Strategy_DayTransition_Start", Screen);

	EndOfDayPanel.Show();
	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).HideForDayTransition();
	// HELIOS END	
	MC.FunctionVoid("AnimateInBlackout");
}

function OnClickContinue()
{
	local XComStrategyPresentationLayer StratPres;
	Movie.Pres.m_kTooltipMgr.TextTooltip.bAvailable = true;

	StratPres = `STRATPRES;
	if (StratPres.PendingProgressVignette != "" || StratPres.PendingDebriefScreen)
	{
		// Skip transition, pipe into vignette/debrief flow
		HideSkipPrompt();
		ShowSteady();		

		StratPres.BeginInvestigationProgressUI();
	}
	else
	{
		// Transition normally
		UpdateData();
		PlayConfirmSound();
		MC.FunctionVoid("AnimateTransitionIn");
	}
}

function ShowSteady()
{
	Show();
	bWantToSkip = false;
	bIsFocused = false;
	UpdateData();
	MC.FunctionVoid("ShowSteady");
	EndOfDayPanel.Hide();
}

simulated function InitializeTooltipData()
{
	local UITextTooltip TextTooltip;

	CachedTooltipID = Movie.Pres.m_kTooltipMgr.AddNewTooltipTextBox("", 0, 15, string(MCPath), , true, class'UIUtilities'.const.ANCHOR_BOTTOM_RIGHT, true, 400, , , , , 0.1 /*snappy!*/);
	TextTooltip = Movie.Pres.m_kTooltipMgr.TextTooltip;
	TextTooltip.SetUsePartialPath(CachedTooltipID, true);
	TextTooltip.SetMouseDelegates(CachedTooltipID, UpdateTooltipText);
}

simulated function UpdateTooltipText(UIToolTip tooltip)
{
	local XGParamTag LocTag;
	local string FormattedString, IncomeString;
	local int CreditsIncome, IntelIncome, EleriumIncome;

	UITextTooltip(tooltip).bAvailable = !bIsFocused;

	class'DioStrategyAI'.static.CalculatePassiveIncome(CreditsIncome, IntelIncome, EleriumIncome);
	if (CreditsIncome > 0 || IntelIncome > 0 || EleriumIncome > 0)
	{
		IncomeString = class'UIUtilities_DioStrategy'.static.FormatMultiResourceValues(CreditsIncome, IntelIncome, EleriumIncome);
	}
	else
	{
		IncomeString = `DIO_UI.default.strTerm_None;
	}

	if (class'DioStrategyAI'.static.GetDaysUntilPassiveIncome() == 0)
	{
		// Payday: normal
		if (CreditsIncome > 0 || IntelIncome > 0 || EleriumIncome > 0)
		{
			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.StrValue0 = IncomeString;
			FormattedString = `XEXPAND.ExpandString(Tooltip_Payday);
		}
		else
		{
			// Payday but you have no income
			FormattedString = Tooltip_PaydayEmpty;
		}
	}
	else
	{
		// Not payday, preview income to come
		LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		LocTag.StrValue0 = IncomeString;
		FormattedString = `XEXPAND.ExpandString(Tooltip_NormalDay);
	}

	UITextTooltip(tooltip).SetText(FormattedString);
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	// Only allow releases through past this point.
	if((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0)
	{
		return false;
	}

	//If we aren't actively doing stuff, don't take any of the input. 
	if(!bIsFocused) return false;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		EndOfDayPanel.OnClickedConfirm(none);
		break;

	default:
		// need text hint for skip 
		ShowSkipPrompt();
		break;
	}

	return true;
}



simulated function OnCommand(string cmd, string arg)
{
	if (cmd == "NotifyOnScreenFadeIn")
	{
		HideSkipPrompt();
		bIsFocused = false;
		EndOfDayPanel.Hide();

		// HELIOS BEGIN
		// Replace the hard reference with a reference to the main HUD	
		UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).UpdateResources(`SCREENSTACK.GetCurrentScreen());
		// HELIOS END
		//Audio hook

		// UI event
		`XEVENTMGR.TriggerEvent('UIEvent_DayTransitionComplete_Immediate', none, self);
	}
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	EndOfDayPanel.OnMouseEvent(cmd, args);
}

simulated function Show()
{
	super.Show();
}
simulated function Hide()
{
	super.Hide();
	EndOfDayPanel.ConfirmButton.Hide();
	HideSkipPrompt();
}

function ShowSkipPrompt()
{
	return; //bsteiner: disabling the skip prompt, since we're replacing it with end of day screen. 

	bWantToSkip = true;
	if(SkipInfo == none)
	{
		SkipInfo = Spawn(class'UIText', self).InitText('skipPrompt', SkipMessage);
		SkipInfo.AnchorBottomLeft();
		SkipInfo.SetX(20);
		SkipInfo.SetY(-40);
		SkipInfo.SetAlpha(50);
	}
	SkipInfo.Show();
}

function HideSkipPrompt()
{
	SkipInfo.Hide();
}

//---------------------------------------------------------------------------------------
//				EVENTS
//---------------------------------------------------------------------------------------
function EventListenerReturn OnFieldTeamTargetingActivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	Hide();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnFieldTeamTargetingDeactivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	Show();
	return ELR_NoInterrupt;
}

DefaultProperties
{
	LibID = "DayTransitionScreen"
	Package = "/ package/gfxDayTransitionScreen/DayTransitionScreen";
	InputState = eInputState_Evaluate;
	bAnimateOnInit = false;
	bHideOnLoseFocus = true;
	bProcessMouseEventsIfNotFocused = false;
}
