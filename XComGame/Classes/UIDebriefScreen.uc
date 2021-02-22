//---------------------------------------------------------------------------------------
//  FILE:    	UIDebriefScreen
//  AUTHOR:  	David McDonough  --  1/15/2020
//  PURPOSE: 	View current Investigation status, operations, bio, etc.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2020 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDebriefScreen extends UIScreen;

struct JournayEntryData
{
	var string DateString;
	var string EntryString;
	var string ImageString;
};

var UIDIOHUD					DioHUD;
var UIList						JournalList;
var array<UIDebriefScreenTab>	TabButtons;
var int							SelectedTabIdx;

var config string DefaultHeaderIcon;

var localized string ScreenTitle;
var localized string m_strActiveOperationLabel;
var localized string m_strBioLabel;
var localized string m_strLeaderLabel;
var localized string m_strJournalLabel;
var localized string m_strDarkEventsLabel;
var localized string m_strNoActiveDarkEvents;
var localized string m_strFactionDefeated;
var localized string m_strCompletedInvestigationLabel;
var localized string m_strCompletedInvestigationBody;
var localized string m_strSelectInvestigation;

var private transient string m_CachedMouseClickSound;

// 3 Main Act investigations only, no tutorial or finale [1/25/2020]
const NumTabs = 3;

//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local UIDebriefScreenTab TempTab;
	local int i;

	super.InitScreen(InitController, InitMovie, InitName);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	DioHUD.UpdateResources(self);

	JournalList = Spawn(class'UIList', self).InitList('DBJournalList',635.45, 543.45, 680.95, 433);

	for (i = 0; i < NumTabs; i++)
	{
		TempTab = Spawn(class'UIDebriefScreenTab', self);
		TempTab.InitButton(name("DBTab_"$i), , OnTabClicked);
		TabButtons.AddItem(TempTab);
	}

	m_CachedMouseClickSound = m_MouseClickSound;
	m_MouseClickSound = "";

	UpdateNavHelp();
	RegisterForEvents();

	SetAlpha(0);
	SetTimer(0.5, false, nameof(CheckCurrentScreen));
}

function CheckCurrentScreen()
{
	local UIScreen ActiveScreen;

	ActiveScreen = `SCREENSTACK.GetCurrentScreen();
	if (ActiveScreen != self)
	{
		SetTimer(0.5, false, nameof(CheckCurrentScreen));
	}
	else
	{
		SetAlpha(1.0);
	}
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();

	UpdateData();
	AS_UpdateHeader(ScreenTitle, DefaultHeaderIcon); // TODO: needs icon?
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_OperationStarted_Submitted', OnOperationStarted, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_OperationStarted_Submitted');
}


//---------------------------------------------------------------------------------------
simulated function UpdateData()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation, SelectedInvestigation;
	local array<StateObjectReference> VisibleInvestigationRefs;
	local StateObjectReference InvestigationRef;	
	local int i;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	// Tabs
	// Make tabs for all visible investigations -- completed first
	VisibleInvestigationRefs = DioHQ.CompletedInvestigations;
	// Only add current if not already counted among completed (happens during transition between investigations)
	if (VisibleInvestigationRefs.Find('ObjectID', DioHQ.CurrentInvestigation.ObjectID) == INDEX_NONE)
	{
		VisibleInvestigationRefs.AddItem(DioHQ.CurrentInvestigation);
	}

	i = 0;
	foreach VisibleInvestigationRefs(InvestigationRef)
	{
		Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(InvestigationRef.ObjectID));
		
		// Main Act investigations only
		if (Investigation.GetMyTemplate().bMainCampaign == false)
		{
			continue;
		}

		SelectedInvestigation = Investigation;

		// Populate tab at index
		TabButtons[i].SetVisible(true);
		TabButtons[i].SetInvestigationData(Investigation);
		i++;
	}

	SelectedTabIdx = i;
	RefreshSelectedTab();
	UpdateInvestigationData(SelectedInvestigation);	

	// Hide unused tabs
	for (i = SelectedTabIdx; i < TabButtons.Length; ++i)
	{
		TabButtons[i].SetVisible(false);
	}
}

//---------------------------------------------------------------------------------------
function UpdateInvestigationData(XComGameState_Investigation Investigation)
{
	local X2DioInvestigationTemplate InvestigationTemplate;
	local XComGameState_InvestigationOperation CurrentOp;
	local array<string> DarkEventSummaries;
	local string Bio, DarkEventFormattedSummary, LeaderName, LeaderBio, LeaderImage;

	InvestigationTemplate = Investigation.GetMyTemplate();

	Bio = InvestigationTemplate.FormatLongDescription();
	AS_UpdateBio(m_strBioLabel, Bio);

	if (Investigation.Stage < eStage_Completed)
	{
		Investigation.FormatActiveDarkEventSummaries(DarkEventSummaries);
		DarkEventFormattedSummary = class'UIUtilities_Text'.static.StringArrayToNewLineList(DarkEventSummaries, true);
		if (DarkEventFormattedSummary == "")
		{
			DarkEventFormattedSummary = m_strNoActiveDarkEvents;
		}
	}
	else
	{
		DarkEventFormattedSummary = m_strFactionDefeated;
	}
	AS_UpdateDarkEvents(m_strDarkEventsLabel, DarkEventFormattedSummary);

	Investigation.GetPlayerVisibleLeaderStrings(LeaderName, LeaderBio, LeaderImage);
	AS_UpdateLeader(m_strLeaderLabel, LeaderBio, LeaderImage);

	AS_UpdateJournal(m_strJournalLabel);
	UpdateJournalData(Investigation);

	// Operation info
	
	// Completed investigation? Show such info
	if (Investigation.IsInvestigationComplete())
	{
		AS_UpdateActiveOperation("", m_strCompletedInvestigationLabel, m_strCompletedInvestigationBody, false);
	}
	// Current investigation? Show current Operation info
	else if (`DIOHQ.CurrentInvestigation.ObjectID == Investigation.ObjectID)
	{
		CurrentOp = class'DioStrategyAI'.static.GetCurrentOperation();
		UpdateOperationData(CurrentOp, true);
	}
}

//---------------------------------------------------------------------------------------
function UpdateJournalData(XComGameState_Investigation Investigation)
{
	local XComGameStateHistory History;
	local X2DioInvestigationTemplate InvestigationTemplate;
	local XComGameState_InvestigationOperation Operation;
	local X2DioInvestigationOperationTemplate OpTemplate;
	local XComGameState_DioWorker OpMissionWorker;
	local array<JournayEntryData> JournalData;
	local JournayEntryData TempJournalEntryData;
	local UIDebriefScreenJournalListItem JournalItem;
	local TDateTime TempDate;
	local int i;

	History = `XCOMHISTORY;
	InvestigationTemplate = Investigation.GetMyTemplate();
	JournalList.ClearItems();

	// Build Entry data
	
	// Initial entry for investigation start
	TempDate = class'XComGameState_GameTime'.static.ComposeDateTimeFromTurnNum(Investigation.TurnStarted);
	TempJournalEntryData.DateString = string(TempDate.m_iDay) @ class'X2StrategyGameRulesetDataStructures'.static.GetMonthString(TempDate.m_iMonth);
	TempJournalEntryData.EntryString = InvestigationTemplate.HistoryText_InvestigationStart;
	TempJournalEntryData.ImageString = ""; // TODO: have any image for start/end of investigation?
	JournalData.AddItem(TempJournalEntryData);

	// Entries per completed operation
	for (i = 0; i < Investigation.CompletedOperationHistory.Length; ++i)
	{	
		Operation = XComGameState_InvestigationOperation(History.GetGameStateForObjectID(Investigation.CompletedOperationHistory[i].OperationRef.ObjectID));
		if (Operation == none)
		{
			continue;
		}
		OpMissionWorker = Operation.GetMainMissionWorker();
		if (OpMissionWorker == none)
		{
			continue;
		}

		OpTemplate = Operation.GetMyTemplate();

		TempDate = class'XComGameState_GameTime'.static.ComposeDateTimeFromTurnNum(Investigation.CompletedOperationHistory[i].TurnCompleted);
		TempJournalEntryData.DateString = string(TempDate.m_iDay) @ class'X2StrategyGameRulesetDataStructures'.static.GetMonthString(TempDate.m_iMonth);
		TempJournalEntryData.EntryString = OpMissionWorker.GetDebriefJournalSummary();
		// Append Operation-level phrase if available
		if (OpTemplate.DebriefOpJournalSummary != "")
		{
			TempJournalEntryData.EntryString @= OpTemplate.DebriefOpJournalSummary;
		}
		//TempJournalEntryData.ImageString = OpMissionWorker.GetMissionBriefingImage();	
		TempJournalEntryData.ImageString = Investigation.CompletedOperationHistory[i].ImageString;
		JournalData.AddItem(TempJournalEntryData);
	}

	// Final entry, if investigation complete
	if (Investigation.IsInvestigationComplete())
	{
		TempDate = class'XComGameState_GameTime'.static.ComposeDateTimeFromTurnNum(Investigation.TurnCompleted);
		TempJournalEntryData.DateString = string(TempDate.m_iDay) @ class'X2StrategyGameRulesetDataStructures'.static.GetMonthString(TempDate.m_iMonth);
		TempJournalEntryData.EntryString = InvestigationTemplate.HistoryText_InvestigationEnd;
		TempJournalEntryData.ImageString = "";
		JournalData.AddItem(TempJournalEntryData);
	}

	// Create and init journal items in reverse order (newest first)
	for (i = JournalData.Length - 1; i >= 0; i--)
	{
		JournalItem = UIDebriefScreenJournalListItem(JournalList.CreateItem(class'UIDebriefScreenJournalListItem')).InitJournalListItem(name("JournalEntry_"$i));
		JournalItem.UpdateData(JournalData[i].EntryString, JournalData[i].DateString, JournalData[i].ImageString);
	}

	JournalList.RealizeItems();
	JournalList.SetSelectedIndex(0);
}

//---------------------------------------------------------------------------------------
function UpdateOperationData(XComGameState_InvestigationOperation Operation, optional bool bIsCurrentOperation=false)
{
	local X2DioInvestigationOperationTemplate OpTemplate;
	local string Summary, Description;

	OpTemplate = Operation.GetMyTemplate();
	if (Operation.IsReadyToReveal())
	{
		Summary = OpTemplate.RevealSummary;
		Description = OpTemplate.RevealDescription;
	}
	
	// If op is not ready to reveal or no text exists for pre/post reveal, just use normal
	if (Summary == "")
	{
		Summary = OpTemplate.Summary;
	}
	if (Description == "")
	{
		Description = OpTemplate.Description;
	}

	AS_UpdateActiveOperation(m_strActiveOperationLabel, Summary, Description, bIsCurrentOperation);
}

//---------------------------------------------------------------------------------------
//				FLASH HOOKS
//---------------------------------------------------------------------------------------
function AS_UpdateHeader(string Title, string IconImage)
{
	MC.BeginFunctionOp("UpdateHeaderInfo");
	MC.QueueString(Title);
	MC.QueueString(IconImage);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
function AS_UpdateActiveOperation(string Title, string Summary, string Description, bool bIsActive)
{
	MC.BeginFunctionOp("UpdateActiveOp");
	MC.QueueString(Title);
	MC.QueueString(Summary);
	MC.QueueString(Description);
	MC.QueueBoolean(bIsActive);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
function AS_UpdateBio(string Title, string Body)
{
	MC.BeginFunctionOp("UpdateBio");
	MC.QueueString(Title);
	MC.QueueString(Body);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
function AS_UpdateJournal(string Label)
{
	MC.BeginFunctionOp("UpdateJournal");
	MC.QueueString(Label);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
function AS_UpdateDarkEvents(string Title, string Body)
{
	MC.BeginFunctionOp("UpdateDarkEvents");
	MC.QueueString(Title);
	MC.QueueString(Body);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
function AS_UpdateLeader(string Title, string Description, string ImagePath)
{
	MC.BeginFunctionOp("UpdateLeader");
	MC.QueueString(Title);
	MC.QueueString(Description);
	MC.QueueString(ImagePath);
	MC.EndOp();
}


simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
function UpdateNavHelp()
{

	DioHUD.NavHelp.ClearButtonHelp();
	if (`STRATPRES.PendingDebriefScreen)
	{
		DioHUD.NavHelp.AddContinueButton(OnContinue);
	}
	else
	{
		DioHUD.NavHelp.AddBackButton(OnClose);
		
		if (`DIOHQ.CompletedInvestigations.Length > 0)
		{
			DioHUD.NavHelp.AddSelectNavHelp();
			if(`ISCONTROLLERACTIVE)
			{
				DioHUD.NavHelp.AddLeftHelp(Caps(m_strSelectInvestigation), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_DPAD_HORIZONTAL);
			}
		}
	}
}

//---------------------------------------------------------------------------------------
//				NAV
//---------------------------------------------------------------------------------------
function RefreshSelectedTab()
{
	local int i;

	for (i = 0; i < TabButtons.Length; ++i)
	{
		if (i == SelectedTabIdx)
		{
			Navigator.SetSelected(TabButtons[i]);
		}
		else
		{
			TabButtons[i].OnLoseFocus();
		}
	}
}

//---------------------------------------------------------------------------------------
function SelectTabPrev()
{
	local int PrevTabIdx;

	PrevTabIdx = SelectedTabIdx - 1;
	PrevTabIdx = (PrevTabIdx < 0) ? TabButtons.Length - 1 : PrevTabIdx;

	// Early out: prev tab isn't available
	if (TabButtons[PrevTabIdx].bIsVisible == false)
	{
		PlayNegativeMouseClickSound();
		return;
	}

	m_MouseClickSound = m_CachedMouseClickSound;
	PlayMouseClickSound();
	m_MouseClickSound = "";

	Navigator.OnLoseFocus();
	TabButtons[SelectedTabIdx].OnLoseFocus();
	SelectedTabIdx = PrevTabIdx;
	TabButtons[SelectedTabIdx].SetSelectedNavigation();
}

//---------------------------------------------------------------------------------------
function SelectTabNext()
{
	local int NextTabIdx;

	NextTabIdx = SelectedTabIdx + 1;
	NextTabIdx = (NextTabIdx > TabButtons.Length - 1) ? 0 : NextTabIdx;

	// Early out: next tab isn't available
	if (TabButtons[NextTabIdx].bIsVisible == false)
	{
		PlayNegativeMouseClickSound();
		return;
	}

	m_MouseClickSound = m_CachedMouseClickSound;
	PlayMouseClickSound();
	m_MouseClickSound = "";

	Navigator.OnLoseFocus();
	TabButtons[SelectedTabIdx].OnLoseFocus();
	SelectedTabIdx = NextTabIdx;
	TabButtons[SelectedTabIdx].SetSelectedNavigation();
}

//---------------------------------------------------------------------------------------
function UIDebriefScreenTab GetSelectedTab()
{
	return TabButtons[SelectedTabIdx];
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnOperationStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateData();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------
function OnTabClicked(UIButton Button)
{
	local XComGameState_Investigation SelectedInvestigation;
	local int i;

	for (i = 0; i < TabButtons.Length; ++i)
	{
		if (TabButtons[i] == Button)
		{
			m_MouseClickSound = m_CachedMouseClickSound;
			PlayMouseClickSound();
			m_MouseClickSound = "";

			SelectedTabIdx = i;
			RefreshSelectedTab();

			SelectedInvestigation = XComGameState_Investigation(`XCOMHISTORY.GetGameStateForObjectID(Button.metadataInt));
			UpdateInvestigationData(SelectedInvestigation);

			return;
		}
	}
}

//---------------------------------------------------------------------------------------
function OnClose()
{
	DioHUD.NavHelp.ClearButtonHelp();
	CloseScreen();
}

//---------------------------------------------------------------------------------------
function OnContinue()
{
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;

	CloseScreen();

	// Continuing from this screen as part of a progress-forced visit should tell pres layer to start the day's normal UI flow
	if (StratPres.PendingDebriefScreen)
	{
		StratPres.BeginNewDayUI();
	}
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	UnRegisterForEvents();
	super.CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bInputConsumed;
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;

	// Only pay attention to presses or repeats; ignoring other input types
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return false;
	}

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
	case class'UIUtilities_Input'.const.FXS_ARROW_LEFT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
		SelectTabPrev();
		bInputConsumed = true;
		break;
	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
	case class'UIUtilities_Input'.const.FXS_ARROW_RIGHT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT :
		SelectTabNext();
		bInputConsumed = true;
		break;
	case class'UIUtilities_Input'.const.FXS_DPAD_UP :
	case class'UIUtilities_Input'.const.FXS_ARROW_UP :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP:
		JournalList.OnChildMouseEvent(JournalList, class'UIUtilities_Input'.const.FXS_MOUSE_SCROLL_DOWN);
		bInputConsumed = true;
		break;
	case class'UIUtilities_Input'.const.FXS_DPAD_DOWN :
	case class'UIUtilities_Input'.const.FXS_ARROW_DOWN :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN :
		JournalList.OnChildMouseEvent(JournalList, class'UIUtilities_Input'.const.FXS_MOUSE_SCROLL_UP);
		bInputConsumed = true;
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_X :
		if (StratPres.PendingDebriefScreen)
		{
			m_MouseClickSound = m_CachedMouseClickSound;
			PlayMouseClickSound();
			m_MouseClickSound = "";

			OnContinue();
			bInputConsumed = true;
		}
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		m_MouseClickSound = m_CachedMouseClickSound;
		PlayMouseClickSound();
		m_MouseClickSound = "";

		if (StratPres.PendingDebriefScreen)
		{
			OnContinue();
		}
		else
		{
			OnClose();
		}
		bInputConsumed = true;
		break;
	default:
		break;
	}

	if (!bInputConsumed)
	{
		return Super.OnUnrealCommand(cmd, arg);
	}

	return bInputConsumed;
}

// ===========================================================================
//  DEFAULTS:
// ===========================================================================
defaultproperties
{
	Package = "/ package/gfxDebriefScreen/DebriefScreen";
	MCName = "theScreen";
}