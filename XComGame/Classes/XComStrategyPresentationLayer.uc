//---------------------------------------------------------------------------------------
//  FILE:    	XComStrategyPresentationLayer
//  AUTHOR:  	dmcdonough  --  10/15/2018
//  PURPOSE: 	Presentation actor to manage the Strategy layer.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComStrategyPresentationLayer extends XComPresentationLayerBase
	config(GameCore)
	dependson(UIDialogueBox);

struct TutorialQueueData
{
	var name TutorialTemplateName;
	var UIScreen Screen;
};

// Turn-Update UI batch storage
var private array<StateObjectReference> m_ActionReportRefs;
var private array<StateObjectReference> m_PendingActionReportRefs;
var private array<X2DioResearchTemplate> m_UnlockedResearchQueue;
var private array<X2DioTrainingProgramTemplate> m_UnlockedTrainingQueue;

var UIDIOHUD DIOHUD; 
var UIDIOStrategy DIOStrategy;
var UIDayTransitionScreen DayTransitionScreen;
// HELIOS BEGIN
//var private name CachedTargetLocationTag; 
// HELIOS END

// 'Attention!' flag counters
var int CityMapAttentionCount;
// HELIOS BEGIN
//var int ArmoryAttentionCount;
// HELIOS END
var int SupplyAttentionCount;
var int ResearchAttentionCount;
var int ScavengerMarketAttentionCount;

var bool AnimateDistrictUnrestChanges; // used in UIDIOStrategyMap, UIDIOStrategyMap_CityDistrict
var int CampaignLoseWarningCount;

// Investigation Progress presentation
var privatewrite string PendingProgressVignette;
var privatewrite bool PendingDebriefScreen;

// VO & Tutorial presentation
var bool m_bTutorialEnabled;
var bool m_bVOTutorialPaused;	// During day transition, don't respond to vo/tutorial triggers
var transient X2DioStrategyTutorialTemplate m_CurrentTutorial;
var Class LastTutorialScreenClass;
var array<name> TutorialsRaisedThisTurn;
var array<Class> m_ScreenChangeIgnores; // Don't attempt to show VO/tutorials when these screen become active


const MapAreaTag		= 'StrategyMap';
const ArmoryAreaTag		= 'Armory';
const GarageAreaTag		= 'Garage';
const AssemblyAreaTag	= 'Assembly';		// TODO
const CommandAreaTag    = 'StrategyMap';	// TODO
const SpecOpsAreaTag    = 'SpecOps';
const TrainingAreaTag	= 'Training';
const HQOverviewAreaTag = 'HeadquartersOverview';
const SupplyAreaTag		= 'Supply';
const MarketAreaTag		= 'Market'; //Scavenger 
const FieldTeamTargetingTag = 'Camera_FieldTeams';
const CaseworkAreaTag   = 'Casework';

// Cinematics
var config string		IntroMovieFilename;
var config string		FinaleIntroMovieFilename;
var config string		FinaleOutroMovieFilename;
var config string		CreditsMovieFilename;

// Loc
var localized string	strConfirmLeaveCampaignTitle;
var localized string	strConfirmLeaveCampaignSummary;
var localized string	strConfirmSwitchDutiesTitle;
var localized string	strConfirmUnassignDutyTitle;
var localized string	strConfirmUnassignDutySummary;
var localized string	TagStr_ConfirmSwitchDutyTitle;
var localized string	TagStr_ConfirmSwitchDutyDestructiveSummary;
var localized string	TagStr_ConfirmSwitchDutiesSummary;
var localized string	strConfirmNewDutySummary;
var localized string	strChangeProjectTitle;
var localized string	TagStr_ChangeProjectBody;
var localized string	strCancelSpecOpsTitle;
var localized string	TagStr_CancelSpecOpsBody;

//---------------------------------------------------------------------------------------
//				INIT
//---------------------------------------------------------------------------------------
simulated function Init()
{
	`log("XComStrategyPresentationLayer.Init()", , 'uixcom');
	super.Init();

	m_bTutorialEnabled = `TutorialEnabled;

	m_ScreenChangeIgnores.Length = 0;
	m_ScreenChangeIgnores.AddItem(class'UIMouseGuard');
	m_ScreenChangeIgnores.AddItem(class'UITutorialBox');
	m_ScreenChangeIgnores.AddItem(class'UIDialogueBox');
	m_ScreenChangeIgnores.AddItem(class'UIRedScreen');
}

//---------------------------------------------------------------------------------------
// Called from InterfaceMgr when it's ready to rock..
simulated function InitUIScreens()
{
	`log("XComStrategyPresentationLayer.InitUIScreens()", , 'uixcom');

	// Load the common screens.
	super.InitUIScreens();

	ScreenStack.Show();
	UIWorldMessages();

	Init3DDisplay();

	if( ScreenStack.IsNotInStack(class'UIDIOHUD', false) )
	{
		DIOHUD = Spawn(class'UIDIOHUD', self);
		ScreenStack.Push(DIOHUD);
	}

	if( ScreenStack.IsNotInStack(class'UIDayTransitionScreen', false) )
	{
		DayTransitionScreen = Spawn(class'UIDayTransitionScreen', self);
		ScreenStack.Push(DayTransitionScreen);
	}

	if( ScreenStack.IsNotInStack(class'UIDIOStrategy', false) )
	{
		DIOStrategy = Spawn(class'UIDIOStrategy', self);
		ScreenStack.Push(DIOStrategy);
	}

	RegisterForScreenStackEvents();

	m_bPresLayerReady = true;
}

//---------------------------------------------------------------------------------------
// This will be called in the initialization sequence in each Pres layer, but specifically so 
// that the stack sorting order looks good in each area of the game. 
simulated function UIWorldMessages()
{
	local XComGameState_CampaignSettings CampaignSettings;

	if (m_kWorldMessageManager == None)
	{
		m_kWorldMessageManager = Spawn(class'UIWorldMessageMgr', self);

		CampaignSettings = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
		if (CampaignSettings != none)
		{
			m_kWorldMessageManager.m_bStrategyTutorial = CampaignSettings.bTutorialEnabled;
		}

		m_kWorldMessageManager.InitScreen(XComPlayerController(Owner), Get2DMovie());
		Get2DMovie().LoadScreen(m_kWorldMessageManager);
	}
}

simulated function bool IsBusy()
{
	return (!Get2DMovie().bIsInited || !IsPresentationLayerReady());
}

function RegisterForScreenStackEvents()
{
	local Object SelfObject;
	SelfObject = self;

	`XEVENTMGR.RegisterForEvent(SelfObject, 'UIEvent_RefreshHUD', OnRefreshHUD, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(SelfObject, 'UIEvent_ActiveScreenChanged', OnStackActiveScreenChanged, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(SelfObject, 'UIEvent_DayTransitionComplete_Immediate', OnDayTransitionComplete, ELD_Immediate);
}

//---------------------------------------------------------------------------------------
//				GENERAL
//---------------------------------------------------------------------------------------

// Display a generic warning dialog with provided title/text
function UIWarningDialog(string Title, string Text, optional EUIDialogBoxDisplay eType = eDialog_Warning, optional string ImagePath)
{
	local TDialogueBoxData DialogData;

	DialogData.eType = eType;
	if (eType == eDialog_NormalWithImage)
		DialogData.strImagePath = ImagePath;
	DialogData.strTitle = Title;
	DialogData.strText = Text;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;

	// Confirm sound needs to be neutral; positive confirm sounds out of place for a warning
	DialogData.bMuteAcceptSound = true;
	DialogData.fnCallback = UIWarningDialogOnConfirm;

	UIRaiseDialog(DialogData);
}

function UIWarningDialogOnConfirm(Name eAction)
{
	local string AkEventName;

	if (eAction == 'eUIAction_Accept')
	{
		AkEventName = "UI_Global_Click_Normal";
		`SOUNDMGR.PlayAkEventDirect(AkEventName, self);
	}
}

function UIClearToStrategyHUD()
{
	ScreenStack.PopUntilClass(class'UIDIOStrategy');
}

simulated function UIControllerMap()
{
	if (ScreenStack.GetScreen(class'UIControllerMap') == none)
	{
		TempScreen = Spawn(class'UIControllerMap', self);
		UIControllerMap(TempScreen).layout = eLayout_Strategy;
		ScreenStack.Push(TempScreen);
	}
	else
	{
		//TODO: this should be refactored. Wherever this function is being called to toggle, should isntead be calling to pop. 
		ScreenStack.PopFirstInstanceOfClass(class'UIControllerMap');
	}
}

//---------------------------------------------------------------------------------------
//				CAMPAIGN
//---------------------------------------------------------------------------------------

function StartCampaignPresentation()
{
	local XComGameState_DialogueManager DialogueManager;

	if (ScreenStack == none)
	{
		return;
	}

	DialogueManager = XComGameState_DialogueManager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
	DialogueManager.RegisterForEvents();

	`XSTRATEGYSOUNDMGR.PlayHQMusicEvent();
	`XSTRATEGYSOUNDMGR.PlayHQAmbienceEvent();
}

//---------------------------------------------------------------------------------------
// Start the UI flow to set up a new campaign (non-tutorial)
function BeginSetupNewCampaignUI()
{
	UIBuildSquad(true);
}

//---------------------------------------------------------------------------------------
// Show the main entry-point Strategy screen
function UICampaignLandingScreen()
{
	//Return to the HQ overview area ( none for event data )
	`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', none, self, none);

	//Signal the start of a campaign session
	`XEVENTMGR.TriggerEvent('Analytics_StrategySessionStart', none, self, none);

	UIRefreshHUD();
	ForceRefreshActiveScreenChanged();
}

//---------------------------------------------------------------------------------------
function UIRefreshHUD()
{
	if (DIOHUD != none)
	{
		DIOHUD.UpdateData();
		DIOHUD.RefreshAll();
	}
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnRefreshHUD(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UIRefreshHUD();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function HighlightTutorialAssignment(name AssignmentName, optional bool bShouldHighlight = true)
{
	if( DIOHUD != none )
	{
		DIOHUD.HighlightTutorialAssignmentBubble(AssignmentName, bShouldHighlight);
	}
}

//---------------------------------------------------------------------------------------
function HighlightAssignment(name AssignmentName)
{
	if (DIOHUD != none)
	{
		DIOHUD.HighlightAssignmentBubble(AssignmentName);
	}
}

//---------------------------------------------------------------------------------------
// Confirm leaving the strategy layer and quitting to the shell
function UIConfirmLeaveCampaign()
{
	local TDialogueBoxData DialogData;

	DialogData.eType = eDialog_Warning;
	DialogData.strTitle = strConfirmLeaveCampaignTitle;
	DialogData.strText = strConfirmLeaveCampaignSummary;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	DialogData.fnCallback = Callback_QuitToShell;

	UIRaiseDialog(DialogData);
}

//---------------------------------------------------------------------------------------
// Check to warn the player of impending game loss
function UITryCampaignLoseWarning()
{
	local XComGameState_CampaignGoal CampaignGoal;

	if (CampaignLoseWarningCount > 0)
		return;

	CampaignGoal = `DIOHQ.GetCampaignGoal();
	if (CampaignGoal.GetGoalStatus() == eGoalStatus_Warning)
	{
		CampaignGoal.ShowGoalWarning();
		CampaignLoseWarningCount++;
	}
}

//---------------------------------------------------------------------------------------
function UIEndCampaign(bool bVictory)
{
	local UIEndGameStats StatsScreen;
	
	ClearUIToHUD();
	if (bVictory)
	{
		StatsScreen = Spawn(class'UIEndGameStats', self);
		StatsScreen.bGameWon = bVictory;
		ScreenStack.Push(StatsScreen);
	}
	else
	{
		TempScreen = Spawn(class'UICombatLose', self);
		UICombatLose(TempScreen).m_eType = eUICombatLose_UnfailableHQAssault;
		ScreenStack.Push(TempScreen);
	}
}

//---------------------------------------------------------------------------------------
simulated function Callback_QuitToShell(name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		QuitToShell();
	}
}

//---------------------------------------------------------------------------------------
simulated function QuitToShell()
{
	ScreenStack.GetCurrentScreen().CloseScreen;
	ConsoleCommand("disconnect");
}

//---------------------------------------------------------------------------------------
// Entry point for setting up the first Investigation of a new campaign
function UINewCampaignInvestigationChooser(CampaignStartData InStartData)
{
	local UIDIOStrategyInvestigationChooserSimple InvestigationChooser;

	if (ScreenStack.IsNotInStack(class'UIDIOStrategyInvestigationChooserSimple', false))
	{
		InvestigationChooser = Spawn(class'UIDIOStrategyInvestigationChooserSimple', self);
		ScreenStack.Push(InvestigationChooser);
		InvestigationChooser.m_CampaignStartData = InStartData;
		InvestigationChooser.InitPopup();
	}
}

//---------------------------------------------------------------------------------------
// Entry point for starting new Investigations during a campaign
function UIInvestigationChooser()
{
	local UIDIOStrategyInvestigationChooserSimple InvestigationChooser;

	if (ScreenStack.IsNotInStack(class'UIDIOStrategyInvestigationChooserSimple', false))
	{
		InvestigationChooser = Spawn(class'UIDIOStrategyInvestigationChooserSimple', self);
		ScreenStack.Push(InvestigationChooser);
		InvestigationChooser.InitPopup();
	}
}

//---------------------------------------------------------------------------------------
function UIOperationPicker()
{
	local UIDIOStrategyOperationChooserSimple OpScreen;

	if( ScreenStack.IsNotInStack(class'UIDIOStrategyOperationChooserSimple', false) )
	{
		OpScreen = Spawn(class'UIDIOStrategyOperationChooserSimple', self);
		ScreenStack.Push(OpScreen);
	}
	else
	{
		ScreenStack.MoveToTopOfStack(class'UIDIOStrategyOperationChooserSimple');
	}
}

//---------------------------------------------------------------------------------------
function UIAgentAssignmentPicker(StateObjectReference UnitRef)
{
	local array<name> DummyOptions;
	local UIDIOStrategyPicker_AgentAssignment PickerScreen;

	if (ScreenStack.IsNotInStack(class'UIDIOStrategyPicker_AgentAssignment', false))
	{
		PickerScreen = UIDIOStrategyPicker_AgentAssignment(ScreenStack.Push(Spawn(class'UIDIOStrategyPicker_AgentAssignment', self)));
	}
	else
	{
		PickerScreen = UIDIOStrategyPicker_AgentAssignment(ScreenStack.MoveToTopOfStack(class'UIDIOStrategyPicker_AgentAssignment'));
	}

	DummyOptions.Length = 0;
	PickerScreen.m_UnitRef = UnitRef;
	PickerScreen.DisplayOptions(DummyOptions);
}

//---------------------------------------------------------------------------------------
function UIUnlockCharacter()
{
	local XComGameState_HeadquartersDio DioHQ;
	local array<name> CharacterIDs;
	local UIScreen UnlockScreen;
	local int i, NumUnlocks;

	DioHQ = `DIOHQ;

	// First 3 items from DioHQ's pregen unlocks, or max if list is smaller
	NumUnlocks = Min(3, DioHQ.RandomizedUnlockableSoldierIDs.Length);
	for (i = 0; i < NumUnlocks; ++i)
	{
		CharacterIDs.AddItem(DioHQ.RandomizedUnlockableSoldierIDs[i]);
	}

	if (CharacterIDs.length > 0)
	{
		if (ScreenStack.IsNotInStack(class'UICharacterUnlock', false))
		{
			UnlockScreen = Spawn(class'UICharacterUnlock', self);
			ScreenStack.Push(UnlockScreen);
		}
		else
		{
			UnlockScreen = ScreenStack.MoveToTopOfStack(class'UICharacterUnlock');
		}
		UICharacterUnlock(UnlockScreen).RefreshData(CharacterIDs);
	}
}

//---------------------------------------------------------------------------------------
function UIBuildSquad(optional bool bCanSelectLockedAgents = false)
{
	local UIScreen UnlockScreen;
	local array<name> CharacterIDs;
	
	if (bCanSelectLockedAgents)
	{
		class'UITacticalQuickLaunch_MapData'.static.GetSquadMemberNames(class'DioStrategyAI'.default.FullCastSquadName, CharacterIDs);
	}
	else
	{
		class'DioStrategyAI'.static.GetAllUnlockedCharacters(CharacterIDs);
	}

	if (ScreenStack.IsNotInStack(class'UIDIOStrategyPicker_CharacterUnlocks', false))
	{
		UnlockScreen = ScreenStack.Push(Spawn(class'UIDIOStrategyPicker_CharacterUnlocks', self));
	}
	else
	{
		UnlockScreen = ScreenStack.MoveToTopOfStack(class'UIDIOStrategyPicker_CharacterUnlocks');
	}

	UIDIOStrategyPicker_CharacterUnlocks(UnlockScreen).m_NumSoldiersToUnlock = 4;
	UIDIOStrategyPicker_CharacterUnlocks(UnlockScreen).m_bNewCampaign = true;
	UIDIOStrategyPicker_CharacterUnlocks(UnlockScreen).DisplayOptions(CharacterIDs);
}

//---------------------------------------------------------------------------------------
function UISpecOpsActionPicker(StateObjectReference UnitRef)
{
	local UISpecOpsScreen PickerScreen;

	if (ScreenStack.IsNotInStack(class'UISpecOpsScreen', false))
	{
		UIClearToStrategyHUD();
		PickerScreen = UISpecOpsScreen(ScreenStack.Push(Spawn(class'UISpecOpsScreen', self)));
	}
	else
	{
		PickerScreen = UISpecOpsScreen(ScreenStack.MoveToTopOfStack(class'UISpecOpsScreen'));
	}

	PickerScreen.UnitRef = UnitRef;
	PickerScreen.DisplayOptions(`DIOHQ.UnlockedSpecOps);
	HighlightAssignment('SpecOps');
}

//---------------------------------------------------------------------------------------
function UITrainingActionPicker(StateObjectReference UnitRef)
{
	local UIDIOTrainingScreen PickerScreen;

	if (ScreenStack.IsNotInStack(class'UIDIOTrainingScreen', false))
	{
		UIClearToStrategyHUD();
		PickerScreen = UIDIOTrainingScreen(ScreenStack.Push(Spawn(class'UIDIOTrainingScreen', self)));
	}
	else
	{
		PickerScreen = UIDIOTrainingScreen(ScreenStack.MoveToTopOfStack(class'UIDIOTrainingScreen'));
	}

	PickerScreen.UnitRef = UnitRef;
	PickerScreen.DisplayOptions();
	HighlightAssignment('Train');
	/*DummyOptions.Length = 0;
	PickerScreen.m_UnitRef = UnitRef;
	PickerScreen.DisplayOptions(DummyOptions);*/
}

//---------------------------------------------------------------------------------------
function UIBuildNewFieldTeam(StateObjectReference DistrictRef)
{
	local UIDIOStrategyPicker_FieldTeamBuilder PickerScreen;

	if (ScreenStack.IsNotInStack(class'UIDIOStrategyPicker_FieldTeamBuilder', false))
	{
		PickerScreen = UIDIOStrategyPicker_FieldTeamBuilder(ScreenStack.Push(Spawn(class'UIDIOStrategyPicker_FieldTeamBuilder', self)));
	}
	else
	{
		PickerScreen = UIDIOStrategyPicker_FieldTeamBuilder(ScreenStack.MoveToTopOfStack(class'UIDIOStrategyPicker_FieldTeamBuilder'));
	}

	PickerScreen.m_DistrictRef = DistrictRef;
	PickerScreen.Display();
}

//---------------------------------------------------------------------------------------
function UIOnCampaignGoalComplete(XComGameState_CampaignGoal Goal)
{
	// DIO DEPRECATED [5/7/2019 dmcdonough]
}

//---------------------------------------------------------------------------------------
//				APRIL INTERIM DELIVERABLE [4/8/2019 bsteiner]
//---------------------------------------------------------------------------------------

function UIShowComp(string CompImage)
{
	// DIO Temporarily disabled until next milestone? [4/29/2019 dmcdonough]
	//local UICompPopUp PopUp; 
	//if( ScreenStack.IsNotInStack(class'UICompPopUp') )
	//{
	//	PopUp = Spawn(class'UICompPopUp', self);
	//	PopUp.CompImage = CompImage;
	//	ScreenStack.Push(PopUp);
	//}
}
//---------------------------------------------------------------------------------------
//				HQ
//---------------------------------------------------------------------------------------

function UIDayTransition()
{
	// Clear per-turn tutorial tracking
	if (`TutorialEnabled)
	{
		TutorialsRaisedThisTurn.Length = 0;
	}

	m_bVOTutorialPaused = true;
	UIClearToStrategyHUD();
	UIClearPendingVOAndTutorial();

	DayTransitionScreen.AnimateTransition();
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnDayTransitionComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	BeginNewDayUI();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
// If Investigation progress from the previous day requires a vignette or a visit to the Debrief Screen, handle that here
// Called from continue input in DayTransitionScreen
function BeginInvestigationProgressUI()
{
	// Fix up: always show debrief screen if there's a vignette waiting
	PendingDebriefScreen = PendingDebriefScreen || PendingProgressVignette != "";

	// Raise Debrief Screen then show vignette (if any)
	if (PendingDebriefScreen)
	{
		UIDebriefScreen(true);

		// hack to trigger debrief screen VO 
		// because m_bVOTutorialPaused is still true at this point,
		// OnStackActiveScreenChanged will exit early
		//m_bVOTutorialPaused = false;
		`XEVENTMGR.TriggerEvent('EvntStratScreen');
	}

	// No current Operation, need to select the next one
	if (NeedsSelectNextOperation())
	{
		UIOperationPicker();
	}

	if (PendingProgressVignette != "")
	{
		PresentVignette(PendingProgressVignette);		
	}
}

//---------------------------------------------------------------------------------------
// Called when all post-mission imperative UI has been viewed and exited
function BeginNewDayUI()
{
	PendingProgressVignette = "";
	PendingDebriefScreen = false;
	m_bVOTutorialPaused = false;

	`XEVENTMGR.TriggerEvent('EvntNewDay');
	CampaignLoseWarningCount = 0;
	AnimateDistrictUnrestChanges = true;

	DIOHUD.m_ScreensNav.Show();
	DIOHUD.ObjectivesList.RefreshAll();

	if (!UIPresentTurnStartUI())
	{
		ForceRefreshActiveScreenChanged();
	}

	SetTimer(3.0f, false, nameof(TriggerTalkIdleVO));
}

//---------------------------------------------------------------------------------------
function SetPendingProgressUpdate(optional string VignettePath)
{
	// By default any call here stages a visit to the Debrief Screen
	PendingDebriefScreen = true;

	// Vignette to accompany that screen is optional
	if (VignettePath != "")
	{
		PendingProgressVignette = VignettePath;
	}
}

//---------------------------------------------------------------------------------------
function UIEnqueueActionReport(StateObjectReference ActionReportRef, optional bool bTop=false)
{
	// DIO DEPRECATED [1/16/2020 dmcdonough]
}

//---------------------------------------------------------------------------------------
// Present any/all screens necessary to see at the start of a new turn. Returns true if any screen pushed.
function bool UIPresentTurnStartUI()
{
	local XComGameState_Investigation CurrentInvestigation;
	local XComGameState_InvestigationOperation CurrentOperation;

	// Current Investigation is done: UI to pick the next one
	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();
	if (CurrentInvestigation.Stage == eStage_Completed)
	{
		if (class'DioStrategyAI'.static.FindAvailableMainActInvestigations())
		{
			UIInvestigationChooser();
			return true;
		}
	}
	else
	{
		// No current Operation, might need to select the next one
		CurrentOperation = class'DioStrategyAI'.static.GetCurrentOperation();
		if (CurrentOperation == none)
		{
			if (CurrentInvestigation.GetStageRequiredOps(CurrentInvestigation.Stage) > 0 &&
				CurrentInvestigation.CountCompletedOperationsForStage(CurrentInvestigation.Stage) >= 2)
			{
				UIOperationPicker();
				return true;
			}
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
function bool NeedsSelectNextOperation()
{
	local XComGameState_Investigation CurrentInvestigation;
	local XComGameState_InvestigationOperation CurrentOperation;

	// Current Investigation is done: UI to pick the next one
	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();
	if (CurrentInvestigation.Stage == eStage_Completed)
	{
		return false;
	}
	else
	{
		// No current Operation, might need to select the next one
		CurrentOperation = class'DioStrategyAI'.static.GetCurrentOperation();
		if (CurrentOperation == none)
		{
			if (CurrentInvestigation.GetStageRequiredOps(CurrentInvestigation.Stage) > 0 &&
				CurrentInvestigation.CountCompletedOperationsForStage(CurrentInvestigation.Stage) >= 2)
			{
				return true;
			}
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
// To display the results of casework the turn it completes
function UIHQCaseworkReport()
{
	local UICaseworkReport CaseworkReport;

	if (ScreenStack.IsNotInStack(class'UICaseworkReport', false))
	{
		CaseworkReport = Spawn(class'UICaseworkReport', self);
		ScreenStack.Push(CaseworkReport);

		CaseworkReport.InitReport();
	}
}

//---------------------------------------------------------------------------------------
function UIDebriefScreen(optional bool bHideHUD=false)
{
	if (ScreenStack.IsNotInStack(class'UIDebriefScreen', false))
	{
		RefreshCamera('Casework');

		ScreenStack.Push(Spawn(class'UIDebriefScreen', self));

		if (bHideHUD)
		{
			DIOHUD.m_ScreensNav.Hide();
		}
	}
}

//---------------------------------------------------------------------------------------

function ViewMetaContent()
{
	UIMetaContentScreen();
}

function UIMetaContentScreen()
{
	local string AkEventName;

	if( ScreenStack.IsNotInStack(class'UIMetaContentScreen', false) )
	{
		AkEventName = "UI_Global_Click_Normal";
		`SOUNDMGR.PlayAkEventDirect(AkEventName);
		ScreenStack.Push(Spawn(class'UIMetaContentScreen', self));
	}
}


//---------------------------------------------------------------------------------------
function UIHQCityMapScreen()
{
	local XComEventObject_EnterHeadquartersArea EnterAreaMessage;
	local string VignettePath;

	if (ScreenStack.IsNotInStack(class'UIDIOStrategyMapFlash', false))
	{
		ScreenStack.Push(Spawn(class'UIDIOStrategyMapFlash', self));
	}

	//Issue a message informing the visuals / game that we are switching locations
	EnterAreaMessage = new class'XComEventObject_EnterHeadquartersArea';
	EnterAreaMessage.AreaTag = MapAreaTag; //Should match the area tag for an XComHeadquartersAreaVisualizer actor placed into the strategy map
	`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', EnterAreaMessage, self, none);

	CityMapAttentionCount = 0;

	// Cinematic special case: check to show Conspiracy Progress vignette
	VignettePath = class'X2StrategyElement_DefaultInvestigations'.static.GetMapScreenConspiracyProgressVignette();
	if (VignettePath != "")
	{
		PresentVignette(VignettePath);
	}
}

//---------------------------------------------------------------------------------------
function UIFieldTeamReview(StateObjectReference FieldTeamRef, optional StateObjectReference DistrictRef)
{
	if (ScreenStack.IsNotInStack(class'UIDIOFieldTeamScreen', false))
	{
		TempScreen = ScreenStack.Push(Spawn(class'UIDIOFieldTeamScreen', self));
		UIDIOFieldTeamScreen(TempScreen).m_DistrictRef = DistrictRef; //if field team is blank we need the district to build in
		UIDIOFieldTeamScreen(TempScreen).DisplayFieldTeam(FieldTeamRef);
	}
}

//---------------------------------------------------------------------------------------
function UIWorkerReview(StateObjectReference WorkerRef)
{
	local XComGameStateHistory History;
	local XComGameState_DioWorker Worker;

	History = `XCOMHISTORY;
	Worker = XComGameState_DioWorker(History.GetGameStateForObjectID(WorkerRef.ObjectID));

	if (Worker.GetActionType() == eStrategyAction_Mission)
	{
		if (ScreenStack.IsNotInStack(class'UIDIOWorkerReviewScreen', false))
		{
			TempScreen = ScreenStack.Push(Spawn(class'UIDIOWorkerReviewScreen', self));
			UIDIOWorkerReviewScreen(TempScreen).DisplayWorker(WorkerRef);
		}
	}
	else
	{
		if (ScreenStack.IsNotInStack(class'UIDIOSituationReviewScreen', false))
		{
			TempScreen = ScreenStack.Push(Spawn(class'UIDIOSituationReviewScreen', self));
			UIDIOSituationReviewScreen(TempScreen).DisplayWorker(WorkerRef);
		}
	}
}

//---------------------------------------------------------------------------------------
function UIHQArmoryScreen()
{
	local X2StrategyGameRuleset StratRules;

	// Validate agent equipment any time player enters Armory
	StratRules = `STRATEGYRULES;
	StratRules.SubmitValidateAgentEquipment();

	if( ScreenStack.IsNotInStack(class'UIArmoryLandingArea', false) )
	{
		TempScreen = ScreenStack.Push(Spawn(class'UIArmoryLandingArea', self));
	}
	ArmoryAttentionCount = 0;
}

//---------------------------------------------------------------------------------------
function UIArmorySelectUnit(optional StateObjectReference UnitRef)
{
	local XComGameState_HeadquartersDio DioHQ;
	local StateObjectReference NoneRef, TargetUnitRef; 

	DioHQ = class'UIUtilities_DioStrategy'.static.GetDioHQ();
	
	TargetUnitRef = (UnitRef == NoneRef) ? DioHQ.Squad[0]  : UnitRef;

	if (ScreenStack.IsNotInStack(class'UIArmory_MainMenu', false))
	{
		if (ScreenStack.IsNotInStack(class'UIArmoryLandingArea', false))
		{
			ScreenStack.Push(Spawn(class'UIArmoryLandingArea', self));
		}
		
		`STRATPRES.RefreshCamera(ArmoryAreaTag);

		UIArmory_MainMenu(ScreenStack.Push(Spawn(class'UIArmory_MainMenu', self))).InitArmory(TargetUnitRef, , , , , , , DioHQ.GetParentGameState());
	}
}

//---------------------------------------------------------------------------------------
function UIBiographyScreen()
{
	`XSTRATEGYSOUNDMGR.BiographyScreenOpened();
	if( ScreenStack.IsNotInStack(class'UIBiographyScreen') )
	{
		ScreenStack.Push(Spawn(class'UIBiographyScreen', self));
	}
}

//---------------------------------------------------------------------------------------
function UIHQGarageScreen()
{
	// DIO DEPRECATED [12/4/2019 dmcdonough]
}

//---------------------------------------------------------------------------------------
function UIHQResearchScreen()
{
	local XComEventObject_EnterHeadquartersArea EnterAreaMessage;

	if (ScreenStack.IsNotInStack(class'UIDIOAssemblyScreen', false))
	{
		UIClearToStrategyHUD();

		//Issue a message informing the visuals / game that we are switching locations
		EnterAreaMessage = new class'XComEventObject_EnterHeadquartersArea';
		EnterAreaMessage.AreaTag = AssemblyAreaTag; //Should match the area tag for an XComHeadquartersAreaVisualizer actor placed into the strategy map
		`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', EnterAreaMessage, self, none);

		ScreenStack.Push(Spawn(class'UIDIOAssemblyScreen', self));
	}

	HighlightAssignment('Research');
	ResearchAttentionCount = 0;
}

//---------------------------------------------------------------------------------------
function UIHQEnqueueUnlockedResearch(X2DioResearchTemplate ResearchTemplate)
{
	if (m_UnlockedResearchQueue.Find(ResearchTemplate) == INDEX_NONE)
	{
		m_UnlockedResearchQueue.AddItem(ResearchTemplate);
	}
}

//---------------------------------------------------------------------------------------
// To display a just-unlocked research project
function UIHQPresentUnlockedResearch()
{
	local UIResearchUnlocked ResearchUnlocked;

	if (m_UnlockedResearchQueue.Length > 0)
	{
		if (ScreenStack.IsNotInStack(class'UIResearchUnlocked', false))
		{
			ResearchUnlocked = Spawn(class'UIResearchUnlocked', self);
			ScreenStack.Push(ResearchUnlocked);
		}
		else
		{
			ResearchUnlocked = UIResearchUnlocked(ScreenStack.MoveToTopOfStack(class'UIResearchUnlocked'));
		}

		ResearchUnlocked.InitResearchUnlocked(m_UnlockedResearchQueue);
	}
	
	m_UnlockedResearchQueue.Length = 0;
}

//---------------------------------------------------------------------------------------
// To display the results of a just-completed research project
function UIHQResearchReport(StateObjectReference ResearchRef)
{
	local UIResearchReport ResearchReport;
	if (ScreenStack.IsNotInStack(class'UIResearchReport', false))
	{
		ResearchReport = Spawn(class'UIResearchReport', self);
		ScreenStack.Push(ResearchReport);

		ResearchReport.InitResearchReport(ResearchRef);
	}
}

//---------------------------------------------------------------------------------------
function UIHQEnqueueUnlockedTraining(X2DioTrainingProgramTemplate TrainingTemplate)
{
	if (m_UnlockedTrainingQueue.Find(TrainingTemplate) == INDEX_NONE)
	{
		m_UnlockedTrainingQueue.AddItem(TrainingTemplate);
		ArmoryAttentionCount++;
	}
}

//---------------------------------------------------------------------------------------
// To display just-unlocked Training Programs
function UIHQPresentUnlockedTraining()
{
	local UITrainingUnlocked TrainingUnlockedUI;

	if (m_UnlockedTrainingQueue.Length > 0)
	{
		if (ScreenStack.IsNotInStack(class'UITrainingUnlocked', false))
		{
			TrainingUnlockedUI = Spawn(class'UITrainingUnlocked', self);
			ScreenStack.Push(TrainingUnlockedUI);
		}
		else
		{
			TrainingUnlockedUI = UITrainingUnlocked(ScreenStack.MoveToTopOfStack(class'UITrainingUnlocked'));
		}

		TrainingUnlockedUI.InitTrainingUnlocked(m_UnlockedTrainingQueue);
	}

	m_UnlockedTrainingQueue.Length = 0;
}

//---------------------------------------------------------------------------------------
function UIHQArmory_Androids(optional int AndroidIndex=0)
{
	local XComEventObject_EnterHeadquartersArea EnterAreaMessage;
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = class'UIUtilities_DioStrategy'.static.GetDioHQ();

	if (ScreenStack.IsNotInStack(class'UIArmory_Androids', false))
	{
		//Issue a message informing the visuals / game that we are switching locations
		EnterAreaMessage = new class'XComEventObject_EnterHeadquartersArea';
		EnterAreaMessage.AreaTag = ArmoryAreaTag; //Should match the area tag for an XComHeadquartersAreaVisualizer actor placed into the strategy map
		`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', EnterAreaMessage, self, none);

		UIArmory_Androids(ScreenStack.Push(Spawn(class'UIArmory_Androids', self))).InitArmory(DioHQ.Androids[AndroidIndex], , , , , , , DioHQ.GetParentGameState());
	}
}

//---------------------------------------------------------------------------------------
function UIArmory_AndroidUpgrades(optional int AndroidIndex=0)
{
	local XComEventObject_EnterHeadquartersArea EnterAreaMessage;
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = class'UIUtilities_DioStrategy'.static.GetDioHQ();

	if (ScreenStack.IsNotInStack(class'UIArmory_AndroidUpgrades', false))
	{
		//Issue a message informing the visuals / game that we are switching locations
		EnterAreaMessage = new class'XComEventObject_EnterHeadquartersArea';
		EnterAreaMessage.AreaTag = ArmoryAreaTag; //Should match the area tag for an XComHeadquartersAreaVisualizer actor placed into the strategy map
		`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', EnterAreaMessage, self, none);

		UIArmory_AndroidUpgrades(ScreenStack.Push(Spawn(class'UIArmory_AndroidUpgrades', self))).InitArmory_AndroidUpgrades(DioHQ.Androids[AndroidIndex], , , , , , , DioHQ.GetParentGameState());
	}
}

//---------------------------------------------------------------------------------------
function UIMissionSquadSelect(StateObjectReference ActionRef, optional XComGameState ModifyGameState)
{
	local XComGameState_StrategyAction_Mission MissionAction;

	if (ModifyGameState != none)
	{
		MissionAction = XComGameState_StrategyAction_Mission(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyAction_Mission', ActionRef.ObjectID));
	}
	else
	{
		MissionAction = XComGameState_StrategyAction_Mission(`XCOMHISTORY.GetGameStateForObjectID(ActionRef.ObjectID));
	}

	if (ScreenStack.IsNotInStack(class'UIDIOSquadSelect', false))
	{
		TempScreen= Spawn(class'UIDIOSquadSelect', self);
		UIDIOSquadSelect(TempScreen).MissionAction = MissionAction;
		ScreenStack.Push(TempScreen);
	}
}

//----------------------------------------------------------------------------------------
function UISquadUnitLoadout(StateObjectReference UnitRef)
{
	if (ScreenStack.IsNotInStack(class'UIDIOStrategySquadManager_Loadout', false))
	{
		TempScreen = Spawn(class'UIDIOStrategySquadManager_Loadout', self);
		UIDIOStrategySquadManager_Loadout(TempScreen).SetUnit(UnitRef);
		ScreenStack.Push(TempScreen);
	}
}

//----------------------------------------------------------------------------------------
function UISquadUnitScars(StateObjectReference UnitRef)
{
	if (ScreenStack.IsNotInStack(class'UIDIOStrategySquadManager_Scars', false))
	{
		TempScreen = Spawn(class'UIDIOStrategySquadManager_Scars', self);
		UIDIOStrategySquadManager_Scars(TempScreen).SetUnit(UnitRef);
		ScreenStack.Push(TempScreen);
	}
}

//----------------------------------------------------------------------------------------
function UISquadUnitAbilities(StateObjectReference UnitRef)
{
	if (ScreenStack.IsNotInStack(class'UIDIOStrategySquadManager_Abilities', false))
	{
		TempScreen = Spawn(class'UIDIOStrategySquadManager_Abilities', self);
		UIDIOStrategySquadManager_Abilities(TempScreen).SetUnit(UnitRef);
		ScreenStack.Push(TempScreen);
	}
}

//----------------------------------------------------------------------------------------
function UIArmory_Loadout(StateObjectReference UnitRef, optional array<EInventorySlot> CannotEditSlots, optional XComGameState InitCheckGameState)
{
	local UIArmory_Loadout ArmoryScreen;

	if (ScreenStack.IsNotInStack(class'UIArmory_Loadout', false))
	{
		ArmoryScreen = UIArmory_Loadout(ScreenStack.Push(Spawn(class'UIArmory_Loadout', self)));
		ArmoryScreen.CannotEditSlotsList = CannotEditSlots;
		ArmoryScreen.InitArmory(UnitRef);
	}
}

//----------------------------------------------------------------------------------------
function UIArmory_Promotion(StateObjectReference UnitRef, optional bool bInstantTransition)
{
	if (ScreenStack.IsNotInStack(class'UIArmory_Promotion', false))
	{
		DoPromotionSequence(UnitRef, bInstantTransition);
	}
}

//----------------------------------------------------------------------------------------
private function DoPromotionSequence(StateObjectReference UnitRef, bool bInstantTransition)
{
	local XComGameState_Unit UnitState;
	local name SoldierClassName;

	SoldierClassName = class'X2StrategyGameRulesetDataStructures'.static.PromoteSoldier(UnitRef);
	if (SoldierClassName == '')
	{
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		SoldierClassName = UnitState.GetSoldierClassTemplate().DataName;
	}

	// The ShowPromotionUI will get triggered at the end of the class movie if it plays, or...
	if (!class'X2StrategyGameRulesetDataStructures'.static.ShowClassMovie(SoldierClassName, UnitRef))
	{
		// ...this wasn't the first time we saw this unit's new class so just show the UI
		ShowPromotionUI(UnitRef, bInstantTransition);
	}
}

//----------------------------------------------------------------------------------------
function ShowPromotionUI(StateObjectReference UnitRef, optional bool bInstantTransition)
{
	local UIArmory_Promotion PromotionUI;

	PromotionUI = UIArmory_Promotion(ScreenStack.Push(Spawn(class'UIArmory_Promotion', self)));

	PromotionUI.InitPromotion(UnitRef, bInstantTransition);
}

//---------------------------------------------------------------------------------------
function UIHQXCOMStoreScreen()
{
	SupplyAttentionCount = 0;
	UIStrategyMarket(`DIOHQ.XCOMStoreRef, true);
}

//---------------------------------------------------------------------------------------
function UIScavengerMarketScreen()
{
	local XComGameState_StrategyMarket ScavengerMarket;

	ScavengerMarket = `DIOHQ.GetScavengerMarket();
	if (ScavengerMarket == none)
	{
		return;
	}

	ScavengerMarketAttentionCount = 0;

	if (ScreenStack.IsNotInStack(class'UIScavengerMarket', false))
	{
		TempScreen = Spawn(class'UIScavengerMarket', self);
		UIScavengerMarket(TempScreen).MarketRef = ScavengerMarket.GetReference();
		ScreenStack.Push(TempScreen);
	}
}

//----------------------------------------------------------------------------------------
function UIStrategyMarket(StateObjectReference MarketRef, bool bIsSupplyMarket)
{
	if (ScreenStack.IsNotInStack(class'UIBlackMarket_Buy', false))
	{
		TempScreen = Spawn(class'UIBlackMarket_Buy', self);
		UIBlackMarket_Buy(TempScreen).MarketRef = MarketRef;
		UIBlackMarket_Buy(TempScreen).m_bIsSupplyMarket = bIsSupplyMarket;
		ScreenStack.Push(TempScreen);
	}
}

//---------------------------------------------------------------------------------------
//				CONFIRMS
//---------------------------------------------------------------------------------------

function PromptDestructiveUnassignAgentDuty(StateObjectReference UnitRef)
{
	local TDialogueBoxData DialogData;
	local UICallbackData_StateObjectReference CallbackData;

	DialogData.eType = eDialog_Warning;
	DialogData.strTitle = strConfirmUnassignDutyTitle;
	DialogData.strText = strConfirmUnassignDutySummary;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	
	CallbackData = new class'UICallbackData_StateObjectReference';
	CallbackData.ObjectRef = UnitRef;
	DialogData.xUserData = CallbackData;
	DialogData.fnCallbackEx = ConfirmUnassignDuty;

	UIRaiseDialog(DialogData);
}

function ConfirmUnassignDuty(name eAction, UICallbackData xUserData)
{
	local UICallbackData_StateObjectReference CallbackData;
	local X2StrategyGameRuleset StratRules;

	if (eAction == 'eUIAction_Accept')
	{
		StratRules = `STRATEGYRULES;
		CallbackData = UICallbackData_StateObjectReference(xUserData);
		if (CallbackData == none)
		{
			return;
		}

		StratRules.SubmitAssignAgentDuty(CallbackData.ObjectRef, 'Unassign');
		`SOUNDMGR.PlayLoadedAkEvent(class'UIDIOStrategyMap_AssignmentBubble'.default.UnassignAgentSound);
	}
}

//---------------------------------------------------------------------------------------
function ConfirmChangeAssemblyProject(delegate<UIDialogueBox.ActionCallback> InCallback)
{
	local XComGameState_DioResearch ActiveResearch;
	local TDialogueBoxData DialogData;
	local XGParamTag LocTag;
	local string FormattedTitle, FormattedSummary;

	// Early out, no research after all!
	if (`DIOHQ.ActiveResearchRef.ObjectID <= 0)
	{
		InCallback('eUIAction_Accept');
		return;
	}

	ActiveResearch = XComGameState_DioResearch(`XCOMHISTORY.GetGameStateForObjectID(`DIOHQ.ActiveResearchRef.ObjectID));

	// Title
	FormattedTitle = strChangeProjectTitle;

	// Summary
	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = ActiveResearch.GetMyTemplate().DisplayName;
	LocTag.StrValue1 = ActiveResearch.GetMyTemplate().GetCostString();
	FormattedSummary = `XEXPAND.ExpandString(TagStr_ChangeProjectBody);

	DialogData.eType = eDialog_Warning;
	DialogData.strTitle = FormattedTitle;
	DialogData.strText = FormattedSummary;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	DialogData.fnCallback = InCallback;

	UIRaiseDialog(DialogData);
}

//---------------------------------------------------------------------------------------
function ConfirmReplaceSpecOpAgent(StateObjectReference CurrentSpecOpUnitRef, StateObjectReference ReplacementSpecOpUnitRef, delegate<UIDialogueBox.ActionCallbackEx> InCallbackEx)
{
	local XComGameState_Unit PreviousUnit;
	local X2DioSpecOpsTemplate SpecOpsTemplate;
	local XComGameState_StrategyAction UnitAction;
	local TDialogueBoxData DialogData;
	local XGParamTag LocTag;
	local UICallbackData_StateObjectReference CallbackData;
	local string FormattedTitle, FormattedSummary;

	CallbackData = new class'UICallbackData_StateObjectReference';
	CallbackData.ObjectRef = CurrentSpecOpUnitRef;
	CallbackData.ObjectRef2 = ReplacementSpecOpUnitRef;

	PreviousUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(CurrentSpecOpUnitRef.ObjectID));
	// Early out, no previous unit after all
	if (PreviousUnit == none)
	{
		InCallbackEx('eUIAction_Accept', CallbackData);
		return;
	}
	UnitAction = PreviousUnit.GetAssignedAction();
	// Early outs, previous unit somehow isn't doing spec ops 
	if (UnitAction.GetMyTemplateName() != 'HQAction_SpecOps')
	{
		InCallbackEx('eUIAction_Accept', CallbackData);
		return;
	}
	SpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(UnitAction.TargetName));
	if (SpecOpsTemplate == none)
	{
		InCallbackEx('eUIAction_Accept', CallbackData);
		return;
	}

	// Title
	FormattedTitle = strCancelSpecOpsTitle;

	// Summary
	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = PreviousUnit.GetNickName(true);
	LocTag.StrValue1 = SpecOpsTemplate.DisplayName;
	FormattedSummary = `XEXPAND.ExpandString(TagStr_CancelSpecOpsBody);

	DialogData.eType = eDialog_Warning;
	DialogData.strTitle = FormattedTitle;
	DialogData.strText = FormattedSummary;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	DialogData.xUserData = CallbackData;
	DialogData.fnCallbackEx = InCallbackEx;

	UIRaiseDialog(DialogData);
}

//---------------------------------------------------------------------------------------
//				STRATEGY ACTIONS
//---------------------------------------------------------------------------------------

function UIConfirmSwitchDutyAssignment(XComGameState_Unit Unit, name ToDutyName, optional delegate<UIDialogueBox.ActionCallbackEx> InCallbackEx, optional int unassignUnitRef = -1)
{
	local XComGameState_StrategyAction Action;
	local X2DioStrategyActionTemplate ToActionTemplate;
	local UICallbackData_StateObjectReference CallbackData;
	local UICallbackData_POD DefaultCallbackData;
	local TDialogueBoxData DialogData;
	local XGParamTag LocTag;
	local string FormattedTitle, FormattedSummary;
	local name AgentAssignment;

	ToActionTemplate = class'DioStrategyAI'.static.GetAssignmentActionTemplate(ToDutyName);

	// Title
	if (ToActionTemplate != none)
	{
		LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		LocTag.StrValue0 = ToActionTemplate.Summary;
		FormattedTitle = `XEXPAND.ExpandString(TagStr_ConfirmSwitchDutyTitle);
	}
	else
	{
		FormattedTitle = strConfirmSwitchDutiesTitle;
	}

	// Summary
	AgentAssignment = class'DioStrategyAI'.static.GetAgentAssignment(Unit.GetReference());
	if (AgentAssignment == 'None')
	{
		//FormattedSummary = strConfirmNewDutySummary;

		// If we are assigning from [NONE: no current assignment] - then we do not need a confiramtion popup. Annoying. 
		CallbackData = new class'UICallbackData_StateObjectReference';
		CallbackData.ObjectRef = Unit.GetReference();
		InCallbackEx('eUIAction_Accept', CallbackData); 
		return; 
	}
	else
	{
		LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		LocTag.StrValue0 = class'UIUtilities_DioStrategy'.static.GetDutyNameString(AgentAssignment);;

		Action = Unit.GetAssignedAction();
		if (Action != none && Action.IsAgentReassignmentDestructive(Unit.GetReference()))
		{
			FormattedSummary = `XEXPAND.ExpandString(TagStr_ConfirmSwitchDutyDestructiveSummary);
		}
		else
		{
			FormattedSummary = `XEXPAND.ExpandString(TagStr_ConfirmSwitchDutiesSummary);
		}
	}

	DialogData.eType = eDialog_Warning;
	DialogData.strTitle = FormattedTitle;
	DialogData.strText = FormattedSummary;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	DialogData.bMuteAcceptSound = true; // Generic confirm sound steps on screen-specific confirm and assign-agent sounds
	
	if (InCallbackEx != none)
	{
		CallbackData = new class'UICallbackData_StateObjectReference';
		CallbackData.ObjectRef = Unit.GetReference();
		DialogData.xUserData = CallbackData;
		DialogData.fnCallbackEx = InCallbackEx;
	}
	else
	{
		DefaultCallbackData = new class'UICallbackData_POD';
		DefaultCallbackData.IntValue = Unit.ObjectID;
		DefaultCallbackData.unassignUnitValue = unassignUnitRef;
		DefaultCallbackData.NameValue = ToDutyName;
		DialogData.xUserData = DefaultCallbackData;
		DialogData.fnCallbackEx = DefaultConfirmReassignDuty;
	}

	UIRaiseDialog(DialogData);
}

//---------------------------------------------------------------------------------------
static function DefaultConfirmReassignDuty(name eAction, UICallbackData xUserData)
{
	local UICallbackData_POD CallbackData;
	local X2StrategyGameRuleset StratRules;
	local StateObjectReference UnitRef, previousUnitRef;
	local name AssignmentName;

	if (eAction == 'eUIAction_Accept')
	{
		StratRules = `STRATEGYRULES;
		CallbackData = UICallbackData_POD(xUserData);
		UnitRef.ObjectID = CallbackData.IntValue;
		AssignmentName = CallbackData.NameValue;

		if (CallbackData.unassignUnitValue != -1)
		{
			previousUnitRef.ObjectID = CallbackData.unassignUnitValue;
			StratRules.SubmitAssignAgentDuty(previousUnitRef, 'Unassign');
		}

		StratRules.SubmitAssignAgentDuty(UnitRef, AssignmentName);
		`SOUNDMGR.PlayLoadedAkEvent(class'UIDIOStrategyMap_AssignmentBubble'.default.AssignAgentSound);
	}
}

//---------------------------------------------------------------------------------------
//				CINEMATICS
//---------------------------------------------------------------------------------------
function bool HasSeenVignette(string VignettePath)
{
	local XComGameState_CampaignSettings SettingsState;
	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	if (SettingsState != none)
	{
		return SettingsState.SeenVignettes.Find(VignettePath) != INDEX_NONE;
	}
	return false;
}

function PresentVignette(string VignettePath, optional bool bForce=false)
{
	// Unless forced, don't show the same vignette twice
	if (!bForce && HasSeenVignette(VignettePath))
	{
		return;
	}

	`STRATEGYRULES.SubmitFlagVignetteSeen(VignettePath);
}

//---------------------------------------------------------------------------------------
//				VO & TUTORIAL
//---------------------------------------------------------------------------------------

// Single Entry point: any time the active screen changes, check to show a VO sequence or a tutorial
function EventListenerReturn OnStackActiveScreenChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local UIScreen ActiveScreen;
	local name TutorialName, VOEventName;

	ActiveScreen = UIScreen(EventData);
	if (ActiveScreen == none)
	{
		return ELR_NoInterrupt;
	}

	// Early out: this screen class is ignored
	if (m_ScreenChangeIgnores.Find(ActiveScreen.Class) != INDEX_NONE)
	{
		return ELR_NoInterrupt;
	}

	// Early out: paused for Day Transition
	if (m_bVOTutorialPaused)
	{
		return ELR_NoInterrupt;
	}

	// Clear any tutorials up, don't clobber
	if (LastTutorialScreenClass != ActiveScreen.Class)
	{
		UIClearPendingVOAndTutorial();
	}

	// Track visited screen
	`STRATEGYRULES.SubmitTutorialVisitedScreen(ActiveScreen.Class.Name);

	// Look for a VO event that matches this screen moment. If exists, show that and exit
	VOEventName = class'DioStrategyTutorialHelper'.static.GetNextScreenVO(ActiveScreen);
	if (VOEventName != '')
	{
		SetTimer(0.5, false, nameof(TriggerScreenVO));
		return ELR_NoInterrupt;
	}

	// If no VO event is ready to appear, check to start a tutorial
	if (m_bTutorialEnabled)
	{
		TutorialName = class'DioStrategyTutorialHelper'.static.GetNextScreenTutorial(ActiveScreen);
		if (TutorialName != '')
		{
			SetTimer(0.5, false, nameof(TriggerScreenTutorial));
			return ELR_NoInterrupt;
		}
	}
	
	// Default case: generic strategy screen VO trigger
	LastTutorialScreenClass = none;

	// If m_kTalkingHead already exists, then a conversation is already playing or still being cleaned up
	if(`PRESBASE.m_kTalkingHead == None)
		`XEVENTMGR.TriggerEvent('EvntStratScreen', ActiveScreen, none, none);

	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
private function TriggerScreenVO()
{
	local UIScreen ActiveScreen;
	local name VOEventName;

	ActiveScreen = ScreenStack.GetCurrentScreen();
	VOEventName = class'DioStrategyTutorialHelper'.static.GetNextScreenVO(ActiveScreen);
	
	// If VO event is none or it fails to trigger (because no valid conversations), pipe straight into attempting tutorial
	if (VOEventName == '')
	{
		TriggerScreenTutorial();
	}
	else
	{
		if (class'XComGameState_DialogueManager'.static.StaticTriggerDialogue(VOEventName, ActiveScreen, none, none))
		{
			// If UISharedHUD_TalkingHead is not in the screen stack, then it is merely small chatter and shouldn't block tutorial popups
			if (ScreenStack.IsNotInStack(class'UISharedHUD_TalkingHead', false))
			{
				TriggerScreenTutorial();
			}
		
			// We're watching TV!
			`STRATEGYRULES.SubmitFlagVOEventAsSeen(VOEventName);
		}
		else
		{
			LastTutorialScreenClass = none;
			TriggerScreenTutorial();
		}
	}
}

function TriggerTalkIdleVO()
{
	if (!ScreenStack.HasInstanceOf(class'UIDIOStrategyInvestigationChooserSimple') &&
		!ScreenStack.HasInstanceOf(class'UIDIOStrategyOperationChooserSimple') &&
		!ScreenStack.HasInstanceOf(class'UIDIOStrategyPicker_Operation') &&
		!ScreenStack.HasInstanceOf(class'UIDebriefScreen')
		// check for other important screens if needed
		)
	{
		if (`DIOHQ.PendingSquadUnlocks < 1)
		{
			`XEVENTMGR.TriggerEvent('TalkIdle');
		}
	}
}

//---------------------------------------------------------------------------------------
private function TriggerScreenTutorial()
{
	local UIScreen ActiveScreen;
	local name TutorialName;

	ActiveScreen = ScreenStack.GetCurrentScreen();
	TutorialName = class'DioStrategyTutorialHelper'.static.GetNextScreenTutorial(ActiveScreen);
	if (TutorialName != '')
	{
		if (ActiveScreen.Class != LastTutorialScreenClass)
		{
			LastTutorialScreenClass = ActiveScreen.Class;
			UIRaiseTutorial(TutorialName, ActiveScreen);
		}
	}
	else
	{
		LastTutorialScreenClass = none;
	}
}

//---------------------------------------------------------------------------------------
function UIRaiseTutorial(name TutorialTemplateName, optional UIScreen OnScreen)
{
	local X2DioStrategyTutorialTemplate TutorialTemplate;
	local UITutorialBox TutorialBox;
	local string Header, Body;

	// Early outs
	if (TutorialTemplateName == '')
	{
		return;
	}

	TutorialTemplate = X2DioStrategyTutorialTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(TutorialTemplateName));
	if (TutorialTemplate == none)
	{
		return;
	}

	if (HasSeenTutorial(TutorialTemplateName))
	{
		// If this is the first time we're trying a seen tutorial this turn, fall through to its linked tutorials
		// so they get some visibility.
		if (TutorialsRaisedThisTurn.Find(TutorialTemplateName) == INDEX_NONE &&
			TutorialTemplate.LinkedTutorial != '')
		{
			UIRaiseTutorial(TutorialTemplate.LinkedTutorial);
			return;
		}
	}
	
	m_CurrentTutorial = TutorialTemplate;
	Header = m_CurrentTutorial.Header;
	Body = m_CurrentTutorial.GetBody();

	if (Body != "")
	{
		// Blade or normal?
		if (TutorialTemplate.Type == "Blade")
		{
			TutorialTemplate.DisplayBlade();
			`STRATEGYRULES.SubmitUpdateTutorialBladeSeen(m_CurrentTutorial.DataName);
		}
		else
		{
			TutorialBox = UITutorialBox(UITutorialBox(Header, Body, TutorialTemplate.Image, TutorialTemplate.MoreInfo));
			TutorialBox.fnOnCloseCallback = Callback_TutorialClosed;
		}
	}
}

//---------------------------------------------------------------------------------------
simulated function Callback_TutorialClosed()
{
	TutorialsRaisedThisTurn.AddItem(m_CurrentTutorial.DataName);

	if (m_CurrentTutorial.Type != "Blade")
	{
		`STRATEGYRULES.SubmitFlagTutorialAsSeen(m_CurrentTutorial.DataName);

		if (m_CurrentTutorial.LinkedTutorial != '')
		{
			UIRaiseTutorial(m_CurrentTutorial.LinkedTutorial, ScreenStack.GetCurrentScreen());
		}
	}	
}

//---------------------------------------------------------------------------------------
function UIClearPendingVOAndTutorial(optional string BladeID="")
{
	//m_QueuedTutorials.Length = 0;
	ClearTimer(nameof(TriggerScreenVO));
	ClearTimer(nameof(TriggerScreenTutorial));

	if (BladeID != "")
	{
		GetWorldMessenger().RemoveMessage(BladeID);
	}
	else
	{
		GetWorldMessenger().RemoveAllBladeMessages();
	}

	`XEVENTMGR.TriggerEvent('UIEvent_ClearGlobalTutorialHighlights');
}

//---------------------------------------------------------------------------------------
function bool HasSeenTutorial(name TutorialTemplateName)
{
	local XComGameState_CampaignSettings SettingsState;
	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	if (SettingsState != none)
	{
		return SettingsState.SeenTutorials.Find(TutorialTemplateName) != INDEX_NONE;
	}
	return false;
}

//---------------------------------------------------------------------------------------
function bool HasSeenTutorialBlade(name TutorialTemplateName, optional int OnTurn=-1)
{
	local XComGameState_CampaignSettings SettingsState;
	local int idx;

	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	if (SettingsState != none)
	{
		idx = SettingsState.SeenTutorialBlades.Find('DataName', TutorialTemplateName);
		if (idx != INDEX_NONE)
		{
			if (OnTurn == -1)
			{
				return true;
			}
			else
			{
				return SettingsState.SeenTutorialBlades[idx].Weight == OnTurn;
			}
		}
	}
	return false;
}

//---------------------------------------------------------------------------------------
function bool HasSeenVOEvent(name VOEventName)
{
	local XComGameState_CampaignSettings SettingsState;
	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	if (SettingsState != none)
	{
		return SettingsState.SeenTutorialVO.Find(VOEventName) != INDEX_NONE;
	}
	return false;
}

//---------------------------------------------------------------------------------------
// Tracks when the player has visited UI areas for major features, e.g.: assembly, training, spec ops
function bool HasVisitedScreen(name ScreenClassName)
{
	local XComGameState_CampaignSettings SettingsState;
	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	if (SettingsState != none)
	{
		return SettingsState.VisitedScreens.Find(ScreenClassName) != INDEX_NONE;
	}
	return false;
}

//---------------------------------------------------------------------------------------
// For those screens that "close" by some unusual method and need to spoof the pres layer into refreshing the active screen
function ForceRefreshActiveScreenChanged()
{
	LastTutorialScreenClass = none;
	OnStackActiveScreenChanged(ScreenStack.GetCurrentScreen(), none, none, 'UIEvent_ActiveScreenChanged', none);
}

//---------------------------------------------------------------------------------------
// HELIOS BEGIN
// Now a simulated function so now the RefreshCamera is on the parent of this class
simulated function RefreshCamera(name targetLocationTag)
{
	super.RefreshCamera(targetLocationTag);
}
// HELIOS END

/** Call to refresh the city district colors on the 3d city map */
function RefreshDistrictMapColors()
{
	local int i;
	local name InitName, OutlineName;
	local XComLevelActor mapActor;
	local XComGameState_DioCityDistrict District;
	local MaterialInstanceConstant RegionUnrestMaterial;
	local MaterialInstanceConstant RegionOutlineMaterial;
	local MaterialInstanceConstant RegionUnrestMaterial2;

	for (i = 0; i < 9; i++)
	{
		InitName = name("Region_" $ i);
		OutlineName = name("Region_Outline_" $ GetRightmost(InitName));
		// No districts to work with!
		// District = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(`DIOCITY.CityDistricts[i].ObjectID));

		foreach class'Engine'.static.GetCurrentWorldInfo().AllActors(class'XComLevelActor', mapActor)
		{
			if (mapActor.Tag == InitName)
			{
				RegionUnrestMaterial = MaterialInstanceConstant(mapActor.StaticMeshComponent.GetMaterial(0));
				RegionUnrestMaterial2 = MaterialInstanceConstant(mapActor.StaticMeshComponent.GetMaterial(1));
			}

			if (mapActor.Tag == OutlineName)
			{
				RegionOutlineMaterial = MaterialInstanceConstant(mapActor.StaticMeshComponent.GetMaterial(0));
			}
		}

		RegionUnrestMaterial.SetScalarParameterValue('UnrestScalar', District.GetUnrestScalar());
		RegionUnrestMaterial2.SetScalarParameterValue('UnrestScalar', District.GetUnrestScalar());
		RegionOutlineMaterial.SetScalarParameterValue('UnrestScalar', District.GetUnrestScalar());
	}
}

reliable client function UIScreen UITutorialBox(string Title, string Desc, string ImagePath, optional string MoreInfo = "", optional string ButtonHelp0 = "", optional string ButtonHelp1 = "")
{
	local UIScreen Screen; 
	Screen = super.UITutorialBox(Title, Desc, ImagePath, MoreInfo, ButtonHelp0, ButtonHelp1);

	//We want to hide appropriate UI elements in strategy underneath the tutorial box. 
	DioHUD.UpdateResources(Screen);
	return Screen; 
}