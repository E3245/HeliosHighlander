//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOWorkerReviewScreen
//  AUTHOR:  	David McDonough  --  4/24/2019
//  PURPOSE: 	Used to view details of a Worker on the City Map and take action on it.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOWorkerReviewScreen extends UIScreen implements(UIDioAutotestInterface);

// HUD elements
var UIDIOHUD					m_HUD;
var UILargeButton				m_ContinueButton;

var StateObjectReference m_WorkerRef;
var bool bCanStartAction;
var array<string>		PendingIdleActivityStrings; // Used in IdleWarningPrompt

var localized string m_MissionTitle;
var localized string m_SituationTitle;
var localized string m_DarkEventsString;
var localized string m_ThreatsString;
var localized string m_RewardsString;
var localized string m_DifficultyLabel;
var localized string m_ConfirmSituationTitle;
var localized string m_ConfirmSituationDesc;
var localized string m_MustVisitAssemblyTitle;
var localized string m_MustVisitAssemblyDesc;
var localized string m_MustVisitSpecOpsTitle;
var localized string m_MustVisitSpecOpsDesc;
var localized string m_MustVisitTrainingTitle;
var localized string m_MustVisitTrainingDesc;
var localized string m_MustUnlockNewAgentTitle;
var localized string m_MustUnlockNewAgentDesc;
var localized string m_ConfirmIdleWarningTitle;
var localized string m_ConfirmIdleWarningBodyStart;
var localized string m_ConfirmIdleWarningBodyEnd;
var localized string m_ConfirmIdleWarningAgent;
var localized string m_ConfirmIdleWarningScavenger;

//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	SetY(`WORKERREVIEWYOFFSET); // mmg_aaron.lee (11/07/19) - allow edit from Global.uci
	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	m_HUD.UpdateResources(self);

	m_ContinueButton = Spawn(class'UILargeButton', self);
	m_ContinueButton.InitLargeButton('workerReviewContinueButton', , , OnAction);
	m_ContinueButton.SetGood(true);
		
	UpdateNavHelp();
	RegisterForEvents();
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	UpdateNavHelp();
	ShowCityMapVisuals();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;
	
	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'UIEvent_ActionAssignmentConfirmed_Immediate', OnReviewComplete, ELD_Immediate);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_WorkerMaskedChanged_Submitted', OnWorkerMaskChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_APCRosterChanged_Submitted', OnAPCRosterChanged, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'UIEvent_ActionAssignmentConfirmed_Immediate');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_WorkerMaskedChanged_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_APCRosterChanged_Submitted');
}

//---------------------------------------------------------------------------------------
//				DISPLAY
//---------------------------------------------------------------------------------------

function DisplayWorker(StateObjectReference WorkerRef)
{
	m_WorkerRef = WorkerRef;
	Refresh();	

	// Strategy Tutorial: spoof active screen event to refresh tutorial
	`XEVENTMGR.TriggerEvent('UIEvent_ActiveScreenChanged', self);
}

//---------------------------------------------------------------------------------------
function Refresh()
{
	local XComGameStateHistory History;
	local XComGameState_DioWorker Worker;
	local XComGameState_StrategyAction Action;
	local XComGameState_StrategyAction_Mission MissionAction;
	local XComGameState_MissionSite Mission;
	local XComGameState_Reward Reward;
	local XComGameState_DioCityDistrict District; 	
	local array<string> RewardsBodyStrings;
	local string ScreenTitle, TempString, UnavailableTipString, actionButtonLabel, missionDifficulty;
	local int i, Unrest, iDistrictCamera;

	History = `XCOMHISTORY;
	m_HUD.RefreshAll();
	bCanStartAction = false;
	ScreenTitle = m_MissionTitle; // default

	Worker = XComGameState_DioWorker(History.GetGameStateForObjectID(m_WorkerRef.ObjectID));
	if (Worker == none)
	{
		return;
	}

	District = Worker.GetDistrict();

	`XEVENTMGR.TriggerEvent('UIEvent_InspectDistrictBegin', Worker, District);

	if (!Worker.IsPlayerControlled() && !Worker.bMasked)
	{
		Action = Worker.GetStrategyAction();
		if (Action != none)
		{
			// Rewards
			for (i = 0; i < Action.RewardRefs.Length; ++i)
			{
				Reward = XComGameState_Reward(History.GetGameStateForObjectID(Action.RewardRefs[i].ObjectID));
				if (!Reward.IsRewardHidden(true, District.GetReference()))
				{
					TempString = Reward.GetRewardPreviewString();
					if (TempString != "")
					{
						RewardsBodyStrings.AddItem(TempString);
					}
				}
			}			

			// Action Button
			bCanStartAction = Worker.CanRespondNow(UnavailableTipString);
			
			if (!bCanStartAction)
			{
				actionButtonLabel = UnavailableTipString;
			}
			else
			{
				if (Action.GetMyTemplate().Type == eStrategyAction_Mission)
				{
					ScreenTitle = m_MissionTitle;
					//actionButtonLabel = `DIO_UI.default.strTerm_RunMission;
				}
				else
				{
					ScreenTitle = m_SituationTitle;
					//actionButtonLabel = `DIO_UI.default.strTerm_SendAPC;
				}
				actionButtonLabel = `DIO_UI.default.strTerm_SendAPC;
			}

			MissionAction = XComGameState_StrategyAction_Mission(Action);
			if(MissionAction != none)
			{
				Mission = MissionAction.GetMission();
				if(Mission != none)
				{
					missionDifficulty = Mission.GetMissionDifficultyLabel();
				}
			}
		}
	}
	
	Unrest = class'DioStrategyTutorialHelper'.static.IsUnrestTutorialLocked() ? -1 : District.Unrest;

	UpdateButtonText(`MAKECAPS(actionButtonLabel));
	
	UpdateRegionInfo(ScreenTitle, District.GetMyTemplate().DisplayName, Unrest);

	UpdateDifficulty(missionDifficulty); 

	UpdateActionInfo( `MAKECAPS(Worker.GetPlayerVisibleName()),
					 Worker.GetResourceString(18, true),
					 "img:///UILibrary_Common.CityMapIcon_Mission2", //TEMP HARDCODED 
					 class'UIUtilities_Colors'.static.GetHexColorFromState(Worker.GetAlignmentUIState()),
					 `MAKECAPS(`DIO_UI.default.strTerm_Rewards $":"),
					 `MAKECAPS(actionButtonLabel));

	UpdateRewards(class'UIUtilities_Text'.static.StringArrayToNewLineList(RewardsBodyStrings));
	
	RefreshNarrativeInfo();
	UpdateActionButton(bCanStartAction);

	iDistrictCamera = FindDistrictCamera(District.GetReference());
	if( iDistrictCamera != -1 )
	{
		// HELIOS BEGIN
		// Move the referesh camera function to presentation base
		`PRESBASE.RefreshCamera(name("StrategyMap_Region_" $ iDistrictCamera));
		// HELIOS END
	}

	`XSTRATEGYSOUNDMGR.UpdateDistrictAudio(District, iDistrictCamera);

	MC.FunctionVoid("RefreshLayout");
}

//---------------------------------------------------------------------------------------
simulated function RefreshNarrativeInfo()
{
	local XComGameStateHistory History;
	local XComGameState_DioWorker Worker;
	local XComGameState_StrategyAction Action;
	local XComGameState_Investigation Investigation;
	local string Title, Description, BriefingImage, FactionImagePath, darkEventDescription, threatsdescription; 
	local array<string> DarkEventTitle, DarkEventDesc, ThreatStrings;
	local int i;

	History = `XCOMHISTORY;

	Worker = XComGameState_DioWorker(History.GetGameStateForObjectID(m_WorkerRef.ObjectID));
	if( Worker == none )
	{
		return;
	}

	Title = `MAKECAPS(Worker.GetPlayerVisibleSummary());

	if (!Worker.bMasked)
	{
		BriefingImage = Worker.GetMissionBriefingImage();
	}

	Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(`DIOHQ.CurrentInvestigation.ObjectID));
	FactionImagePath = "img:///UILibrary_Common." $ Investigation.GetMyTemplate().DisplayIcon;
	
	// Description
	Description = class'UIUtilities_Text'.static.ConvertStylingToFontFace("<i>" $ Worker.GetPlayerVisibleDescription() $"<\i>");

	// Threats (append to Description)
	if (Worker.GetThreatDescriptions(ThreatStrings))
	{
		for (i = 0; i < ThreatStrings.Length; i++)
		{
			threatsdescription $= "\n"$ class'UIUtilities_Text'.static.GetColoredText(ThreatStrings[i], eUIState_Bad);
		}
	}
	UpdateThreat(m_ThreatsString, threatsdescription);

	Action = Worker.GetStrategyAction();
	if (Action.GetMyTemplate().Type == eStrategyAction_Mission && Worker.CanRespondNow())
	{
		// Dark Events (append to Description)
		Action.GetActiveDarkEventStrings(DarkEventTitle, DarkEventDesc);
		if (DarkEventTitle.Length > 0 && DarkEventDesc.Length > 0)
		{
			for (i = 0; i < DarkEventTitle.Length; i++)
			{
				if( darkEventDescription != "" )
				{
					darkEventDescription $= "\n";
				}
				darkEventDescription $= class'UIUtilities_Text'.static.GetColoredText(DarkEventTitle[i] $ ": " $ DarkEventDesc[i], eUIState_Bad);
			}
		}
	}

	UpdateDarkEvents(m_DarkEventsString, darkEventDescription);
	
	UpdateHeaderInfo(Title, FactionImagePath, m_RewardsString);
	UpdateNarrativeInfo(Title, Description, BriefingImage, FactionImagePath);

	MC.FunctionVoid("RefreshLayout");
}

//---------------------------------------------------------------------------------------
//				NAVIGATION
//---------------------------------------------------------------------------------------

function UpdateNavHelp()
{
	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.AddBackButton(OnCancel);
	// mmg_aaron.lee (06/05/19) BEGIN - added select NavHelp
	//NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE; // We have the NavHelp horizontal here because it'll overlay with the UIScreen if vertical.
	m_HUD.NavHelp.AddSelectNavHelp();
	// mmg_aaron.lee (06/05/19) END
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if ((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0)
	{
		return false;
	}

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		OnAction(none);
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
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------
function EventListenerReturn OnWorkerMaskChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	Refresh();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnAPCRosterChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	Refresh();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnReviewComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	CloseScreen();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
//				INPUT HANDLER
//---------------------------------------------------------------------------------------
function OnCancel()
{
	CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	`XSTRATEGYSOUNDMGR.StopDistrictAudio();
	UnRegisterForEvents();
	`XEVENTMGR.TriggerEvent('UIEvent_InspectDistrictEnd');
	super.CloseScreen();
}

simulated function ShowCityMapVisuals()
{
	local UIDIOStrategyMapFlash Map;
	
	Map = UIDIOStrategyMapFlash(`SCREENSTACK.GetScreen(class'UIDIOStrategyMapFlash'));
	Map.Show();
}

//---------------------------------------------------------------------------------------
function OnAction(UIButton Button)
{
	local XComGameStateHistory History;
	local XComGameState_DioWorker Worker;
	local XComGameState_StrategyAction Action;
	local XComGameState_Investigation Investigation;

	History = `XCOMHISTORY;
	Investigation = class'DioStrategyAI'.static.GetCurrentInvestigation();

	// mmg_john.hawley (11/19/19) - Prevent all missions after initial critical mission while installing 
	if (!class'GameEngine'.static.GetOnlineSubsystem().IsGameDownloaded() && Investigation.Stage != eStage_Groundwork)
	// if (!class'GameEngine'.static.GetOnlineSubsystem().IsGameDownloaded())
	{
		`StratPres.DIOStrategy.BlockUntilStreamingInstallComplete();
		return;
	}

	Worker = XComGameState_DioWorker(History.GetGameStateForObjectID(m_WorkerRef.ObjectID));
	if (Worker == none)
	{
		CloseScreen();
		return;
	}

	if (Worker.IsPlayerControlled())
	{
		CloseScreen();
	}
	else
	{	
		if (!bCanStartAction)
		{
			CloseScreen();
			return;
		}

		Action = Worker.GetStrategyAction();
		if (Action != none)
		{			
			// If any HQ activities are required, block access to completing the action
			if (CheckForRequiredActivities())
			{
				PlayNegativeMouseClickSound();
				CloseScreen();
			}
			// If any HQ activities are idle and player needs to be warned
			else if (CheckForIdleWarning())
			{
				PlayMouseClickSound();
				PromptIdleWarningBeforeAction();
			}
			// If it's a Situation and player needs to confirm to end the day
			else if (Action.GetMyTemplate().Type == eStrategyAction_Situation)
			{
				PlayMouseClickSound();
				PromptConfirmExecuteSituation();
			}
			else
			{
				BeginAction();
			}
		}
	}	
}

//---------------------------------------------------------------------------------------
function BeginAction()
{
	local XComGameState_DioWorker Worker;
	local XComGameState_StrategyAction Action;
	local XComGameState_DialogueManager DialogueManager;

	Worker = XComGameState_DioWorker(`XCOMHISTORY.GetGameStateForObjectID(m_WorkerRef.ObjectID));
	Action = Worker.GetStrategyAction();
	if (Action != none)
	{
		// Mission actions: go to Squad Select
		if (Action.GetMyTemplate().Type == eStrategyAction_Mission)
		{
			PlayMouseClickSound();
			CloseScreen();
			`STRATPRES.UIMissionSquadSelect(Worker.ActionRef);
		}
		// Situations
		else
		{
			PlayConfirmSound();
			CloseScreen();

			`XEVENTMGR.TriggerEvent('OnConfirmExecuteSituation', Action, self);
			`STRATEGYRULES.ExecuteSingleStrategyAction(Worker.ActionRef);

			DialogueManager = XComGameState_DialogueManager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
			DialogueManager.StopCurrentConversation();
		}
	}
}

//---------------------------------------------------------------------------------------
//				FLASH INTERFACE
//---------------------------------------------------------------------------------------

function UpdateDifficulty(string label)
{
	MC.BeginFunctionOp("UpdateDifficulty");
	MC.QueueString((label == "") ? "" : (m_DifficultyLabel @ label));
	MC.EndOp();
}

function UpdateRegionInfo(string ScreenTitle, string Subtitle, int rating)
{
	MC.BeginFunctionOp("UpdateRegionInfo");
	MC.QueueString(ScreenTitle);
	MC.QueueString(`MAKECAPS(Subtitle));
	MC.QueueNumber(rating);
	MC.EndOp();
}
function UpdateActionInfo(string title, string subtitle, string icon, string actionColor, string rewardsTitle, string buttonHelp)
{
	MC.BeginFunctionOp("UpdateActionInfo");
	MC.QueueString(title);
	MC.QueueString(subtitle);
	MC.QueueString(icon);
	MC.QueueString(actionColor);
	MC.QueueString(rewardsTitle);
	MC.QueueString(buttonHelp);
	MC.EndOp();
}
function UpdateNarrativeInfo(string title, string desc, string narrativeImagePath, string factionImagePath)
{
	MC.BeginFunctionOp("UpdateNarrativeInfo");
	MC.QueueString(title);
	MC.QueueString(desc);
	MC.QueueString(narrativeImagePath);
	MC.QueueString(factionImagePath);
	MC.EndOp();
}

function UpdateRewards(string rewardDesc)
{
	MC.FunctionString("UpdateRewards", rewardDesc);
}

function UpdateHeaderInfo(string title, string factionIcon, string rewardsTitle)
{
	MC.BeginFunctionOp("UpdateHeaderInfo");
	MC.QueueString(title);
	MC.QueueString(factionIcon);
	MC.QueueString(rewardsTitle);
	MC.EndOp();
}

function UpdateDarkEvents(string title, string description)
{
	MC.BeginFunctionOp("UpdateDarkEvents");
	MC.QueueString(title);
	MC.QueueString(description);
	MC.EndOp();
}

function UpdateThreat(string title, string description)
{
	MC.BeginFunctionOp("UpdateThreat");
	MC.QueueString(title);
	MC.QueueString(description);
	MC.EndOp();
}

function UpdateButtonText(string text)
{
	MC.BeginFunctionOp("UpdateButtonText");
	MC.QueueString(text);
	MC.EndOp();
}

function UpdateActionButton(bool bEnabled)
{
	if (bEnabled)
	{
		m_ContinueButton.Show();
	}
	else
	{
		m_ContinueButton.Hide();
	}
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	if( cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_UP )
	{
		OnAction(none);
		return; 
	}
	else
	{
		super.OnMouseEvent(cmd, args);
	}
}

function bool CheckForRequiredActivities()
{
	// All games: must complete agent recruitment
	if (`DIOHQ.PendingSquadUnlocks > 0)
	{
		PromptActivityRequiredBeforeMission(m_MustUnlockNewAgentTitle, m_MustUnlockNewAgentDesc);
		return true;
	}

	// Tutorial: must visit certain screens as they are introduced
	if (`TutorialEnabled)
	{
		if (class'DioStrategyTutorialHelper'.static.RequireVisitAssembly())
		{
			PromptActivityRequiredBeforeMission(m_MustVisitAssemblyTitle, m_MustVisitAssemblyDesc);
			return true;
		}
		if (class'DioStrategyTutorialHelper'.static.RequireVisitSpecOps())
		{
			PromptActivityRequiredBeforeMission(m_MustVisitSpecOpsTitle, m_MustVisitSpecOpsDesc);
			return true;
		}
		if (class'DioStrategyTutorialHelper'.static.RequireVisitTraining())
		{
			PromptActivityRequiredBeforeMission(m_MustVisitTrainingTitle, m_MustVisitTrainingDesc);
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
// Check conditions to see if player should be warned about idle activities before starting the action
function bool CheckForIdleWarning()
{
	local XComGameState_HeadquartersDio DioHQ;
	local int i;

	DioHQ = `DIOHQ;
	PendingIdleActivityStrings.Length = 0;
	
	// Idle Agents?
	for (i = 0; i < DioHQ.Squad.Length; ++i)
	{
		if (class'DioStrategyAI'.static.IsAgentIdle(DioHQ.Squad[i]))
		{
			// Found an Idle Agent, but only warn if there's a place to put them
			if (class'DioStrategyAI'.static.CountAvailableDutySlots())
			{
				PendingIdleActivityStrings.AddItem(m_ConfirmIdleWarningAgent);
				break;
			}
		}
	}
	
	// Unvisited Scavenger Market
	if (DioHQ.IsScavengerMarketAvailable() && `STRATPRES.ScavengerMarketAttentionCount > 0)
	{
		PendingIdleActivityStrings.AddItem(m_ConfirmIdleWarningScavenger);
	}

	return PendingIdleActivityStrings.Length > 0;
}

function PromptConfirmExecuteSituation()
{
	local TDialogueBoxData DialogData;

	DialogData.eType = eDialog_Alert;
	DialogData.strTitle = m_ConfirmSituationTitle;
	DialogData.strText = m_ConfirmSituationDesc;
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNo;
	DialogData.fnCallback = OnConfirmExecuteSituation;
	DialogData.bMuteAcceptSound = true;

	Movie.Pres.UIRaiseDialog(DialogData);
}

simulated function OnConfirmExecuteSituation(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		BeginAction();
	}
}

//---------------------------------------------------------------------------------------
function PromptActivityRequiredBeforeMission(string Title, string Body)
{
	local TDialogueBoxData DialogData;

	DialogData.eType = eDialog_Alert;
	DialogData.strTitle = Title;
	DialogData.strText = Body;
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericAccept;

	Movie.Pres.UIRaiseDialog(DialogData);
}

//---------------------------------------------------------------------------------------
function PromptIdleWarningBeforeAction()
{
	local TDialogueBoxData DialogData;
	local string Title, Body;

	Title = m_ConfirmIdleWarningTitle;
	Body = m_ConfirmIdleWarningBodyStart $ "\n\n";
	Body $= class'UIUtilities_Text'.static.StringArrayToNewLineList(PendingIdleActivityStrings, true);
	Body $= "\n\n" $ m_ConfirmIdleWarningBodyEnd;

	DialogData.eType = eDialog_Alert;
	DialogData.strTitle = Title;
	DialogData.strText = Body;
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNo;
	DialogData.fnCallback = OnConfirmIdleWarning;
	DialogData.bMuteAcceptSound = true;

	Movie.Pres.UIRaiseDialog(DialogData);
}

simulated function OnConfirmIdleWarning(name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		BeginAction();
	}
}

//---------------------------------------------------------------------------------------
function int FindDistrictCamera(StateObjectReference DistrictRef)
{
	local UIDIOStrategyMapFlash StrategyMapScreen;
	
	StrategyMapScreen = UIDIOStrategyMapFlash(`SCREENSTACK.GetScreen(class'UIDIOStrategyMapFlash'));
	if( StrategyMapScreen == none )	return -1;

	return StrategyMapScreen.GetDistrictIndex(DistrictRef);
}

//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{
	OnAction(none);
	return true;
}

simulated function OnReceiveFocus()
{
	local int iDistrictCamera;
	local XComGameStateHistory History;
	local XComGameState_DioWorker Worker;
	local XComGameState_DioCityDistrict District;

	History = `XCOMHISTORY;

	Worker = XComGameState_DioWorker(History.GetGameStateForObjectID(m_WorkerRef.ObjectID));
	if (Worker == none)
	{
		return;
	}

	District = Worker.GetDistrict();

	super.OnReceiveFocus();
	m_HUD.UpdateResources(self);
	
	iDistrictCamera = FindDistrictCamera(District.GetReference());
	if (iDistrictCamera != -1)
	{
		`STRATPRES.RefreshCamera(name("StrategyMap_Region_" $ iDistrictCamera));
	}
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	Package = "/ package/gfxSitRepPopup/SitRepPopup"
	bHideOnLoseFocus = false
}