//---------------------------------------------------------------------------------------
//  FILE:    XComGameStateContext_DioStrategyStart
//  AUTHOR:  dmcdonough  --  10/11/2018
//  PURPOSE: Context for starting strategy game sessions, either as a new game or 
//			 when returning from Tactical.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class XComGameStateContext_DioStrategyStart extends XComGameStateContext
	native(Core);

struct native UserCampaignSettings
{
	var int Difficulty;
	var float TacticalDifficulty;
	var float StrategicDifficulty;
	var float GameLength;
	var bool bIronmanEnabled;			// TRUE indicates that this campaign was started with Ironman enabled
	var bool bHardcoreEnabled;
	var bool bExtendCityUnrestMeter;	// ExtraCityUnrestMeterAmount
	var bool bFullHealSquadPostEncounter; // if true, will enable squad healing during breach. will be forced off on impossible difficulty
	var bool bHalfHealSquadPostEncounter;
	var bool bSuppressFirstTimeNarrative; // TRUE, the tutorial narrative moments will be skipped
	
	structdefaultproperties
	{
		Difficulty = 1;
		TacticalDifficulty = 25.0f;
		StrategicDifficulty = 25.0f;
		GameLength = 33.0f;
		bIronmanEnabled = false;
		bHardcoreEnabled = false;
		bExtendCityUnrestMeter = false;
		bFullHealSquadPostEncounter = false;
		bHalfHealSquadPostEncounter = true; //default to half heal
		bSuppressFirstTimeNarrative = false;
	}
};

var StrategyStartType	InputStartType;
var bool				bDebugStart; // If set, enables various parts of the Strategy layer to provide accelerated start

var UserCampaignSettings UserSettings;

/// <summary>
/// Override to return TRUE for the XComGameStateContext object to show that the associated state is a start state
/// </summary>
event bool IsStartState()
{
	return true;
}

native function bool NativeIsStartState();

//---------------------------------------------------------------------------------------
//				ENTRY POINTS
//---------------------------------------------------------------------------------------
static function SubmitStrategyStart(const StrategyStartType UseStartType, optional UserCampaignSettings InUserSettings, optional bool InDebugStart=false)
{
	local XComGameStateContext_DioStrategyStart NewStartContext;
	local XComGameState NewGameState;
	local X2StrategyGameRuleset StrategyRules;
	local array<X2DownloadableContentInfo> DLCInfos;
	local int i;

	NewStartContext = XComGameStateContext_DioStrategyStart(class'XComGameStateContext_DioStrategyStart'.static.CreateXComGameStateContext());
	NewStartContext.InputStartType = UseStartType;
	NewStartContext.bDebugStart = InDebugStart;
	NewStartContext.UserSettings = InUserSettings;
	NewGameState = NewStartContext.ContextBuildGameState();

	if (UseStartType == eStrategyStartType_Tutorial)
	{
		// Build the local state object cache for the strategy ruleset in the tutorial loading path, as we'll need this data w.o loading into strategy proper
		StrategyRules = X2StrategyGameRuleset(`GAMERULES);
		StrategyRules.BuildLocalStateObjectCache();
	}
		
	//Let mods hook new campaign creation
	DLCInfos = `ONLINEEVENTMGR.GetDLCInfos(false);
	if(UseStartType == eStrategyStartType_Tutorial || UseStartType == eStrategyStartType_NewCampaign)
	{
		for (i = 0; i < DLCInfos.Length; ++i)
		{
			DLCInfos[i].InstallNewCampaign(NewGameState);
		}
	}

	StrategyRules.SubmitGameState(NewGameState);
}

//---------------------------------------------------------------------------------------
//				GameState Interface
//---------------------------------------------------------------------------------------
function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

//---------------------------------------------------------------------------------------
function XComGameState ContextBuildGameState()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;

	// Make the new game state
	NewGameState = History.CreateNewGameState(false, self);

	switch (InputStartType)
	{
	case eStrategyStartType_Tutorial:
		BuildNewCampaignState( NewGameState, UserSettings, true );
		break;
	case eStrategyStartType_NewCampaign:
		BuildNewCampaignState(NewGameState, UserSettings,  false);
		break;
	case eStrategyStartType_LoadCampaign:
		BuildLoadCampaignState(NewGameState);
		break;
	}

	return NewGameState;
}

//---------------------------------------------------------------------------------------
protected function ContextBuildVisualization()
{
	local XComGameState_HeadquartersDio HQObject;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	HQObject = XComGameState_HeadquartersDio(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio'));

	//Use the HQObject object for the following actions:
	ActionMetadata.StateObject_OldState = HQObject;
	ActionMetadata.StateObject_NewState = HQObject;
	ActionMetadata.VisualizeActor = none;

	class'X2Action_InitStrategySession'.static.AddToVisualizationTree(ActionMetadata, self);
}

//---------------------------------------------------------------------------------------
function string SummaryString()
{
	return string(InputStartType);
}

//---------------------------------------------------------------------------------------
//				HELPERS
//---------------------------------------------------------------------------------------
protected function BuildNewCampaignState(XComGameState ModifyGameState, UserCampaignSettings InUserSettings, bool bTutorial)
{
	local XComGameState_CampaignSettings Settings;

	// Start Issue WOTC CHL #869
	//
	// Register campaign-start listeners after the start state has been created
	// but before any campaign initialization has occurred.
	class'X2EventListenerTemplateManager'.static.RegisterCampaignStartListeners();
	// End Issue WOTC CHL #869

	Settings = class'XComGameState_CampaignSettings'.static.CreateCampaignSettings(ModifyGameState, 
		bTutorial, 
		false /*InXPackNarrativeEnabled*/, 
		false /*InIntegratedDLCEnabled*/,
		InUserSettings.Difficulty,
		InUserSettings.TacticalDifficulty, 
		InUserSettings.StrategicDifficulty, 
		InUserSettings.GameLength, 
		InUserSettings.bSuppressFirstTimeNarrative/*InSuppressFirstTimeVO*/); //Several optional params skipped

	Settings.SetStartTime(class'XComCheatManager'.static.GetCampaignStartTime());
	Settings.bCheatStart = bDebugStart;

	Settings.SetIronmanEnabled( InUserSettings.bIronmanEnabled );
	Settings.SetHarcoreEnabled( InUserSettings.bHardcoreEnabled );
	Settings.SetExtendCityUnrestMeter( InUserSettings.bExtendCityUnrestMeter );
	Settings.SetHealSquadFullPreBreach( InUserSettings.bFullHealSquadPostEncounter );
	Settings.SetHealSquadHalfPreBreach( InUserSettings.bHalfHealSquadPostEncounter );

	//DIO EVALUATE - many systems look to a set of strategy / campaign objectives
	class'XComGameState_Objective'.static.SetUpObjectives(ModifyGameState);

	//Create start time
	class'XComGameState_GameTime'.static.CreateGameStartTime(ModifyGameState);
	
	//DIO EVALUATE - many systems look to a mission calendar
	class'XComGameState_MissionCalendar'.static.SetupCalendar(ModifyGameState);

	// Populate common card decks
	class'DioStrategyAI'.static.InitCardDecks();

	// Setup Dio HQ 
	class'XComGameState_HeadquartersDio'.static.SetupHeadquarters(ModifyGameState, bTutorial, InUserSettings.Difficulty);

	// Setup Dio City
	class'XComGameState_DioCity'.static.SetupCity(ModifyGameState);

	//Create analytics object
	class'XComGameState_Analytics'.static.CreateAnalytics(ModifyGameState, InUserSettings.Difficulty);
	class'XComGameState_DialogueManager'.static.SetUpDialogueManager(ModifyGameState);

	// init achievement tracker
	class'X2AchievementTracker'.static.CreateAchievementData(ModifyGameState);
}

//---------------------------------------------------------------------------------------
protected function BuildLoadCampaignState(XComGameState ModifyGameState)
{
	//TODO-DIO-STRATEGY  [10/11/2018 dmcdonough]
}
