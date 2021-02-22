//---------------------------------------------------------------------------------------
//  FILE:    XComGameModeTransitionHelper.uc
//  AUTHOR:  Ryan McFall  --  11/01/2018
//  PURPOSE: Encapsulates logic to initiate transitions between tactical and strategy
//           game modes.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameModeTransitionHelper extends Actor native(Core);

//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------
/*



				STRATEGY to TACTICAL



*/
//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------
/// <summary>
/// Used to start a tactical battle from strategy.
/// </summary>
function LaunchTacticalMission(XComGameState_MissionSite MissionSiteRef)
{	
	local int RewardIndex;
	local int UnitIndex, ItemIndex, i;
	local XComGameStateHistory History;
	local XComGameState NewStartState;
	local XComGameState_BattleData BattleData;
	local XComGameState_Unit SendSoldierState;
	local XComGameState_Unit ProxySoldierState;
	local StateObjectReference XComPlayerRef;
	local XComGameState_HeadquartersDio DioHQ;
	local XComTacticalMissionManager MissionManager;
	local GeneratedMissionData GeneratedMission;
	local XComGameState_MissionSite MissionState;
	local XComGameState_StrategyAction_Mission MissionAction;
	local XComGameState_GameTime TimeState;
	local XComGameState_DialogueManager DialogueManager;
	local XComGameState_Reward RewardStateObject;
	local Vector2D MissionCoordinates;
	local X2MissionTemplateManager MissionTemplateManager;
	local X2MissionTemplate MissionTemplate;
	local string MissionBriefing;
	local XComOnlineEventMgr EventManager;
	local array<X2DownloadableContentInfo> DLCInfos;
	local array<StateObjectReference> MissionSquad;
	local XComGameState_Analytics AnalyticsState;
	local StateObjectReference AndroidReference;
	local X2BackupUnitData BackupData;
	local XComGameState_EncounterData EncounterData;
	local name SelectedMissionSchedule;

	`XCOMVISUALIZATIONMGR.DisableForShutdown();

	MissionTemplateManager = class'X2MissionTemplateManager'.static.GetMissionTemplateManager();

	History = `XCOMHISTORY;
	MissionManager = `TACTICALMISSIONMGR;
	
	//Create a new game state that will form the start state for the tactical battle. Use this helper method to set up the basics and
	//get a reference to the battle data object
	NewStartState = class'XComGameStateContext_TacticalGameRule'.static.CreateDefaultTacticalStartState_Singleplayer(BattleData);

	// copy the analytics mgr
	AnalyticsState = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics'));
	AnalyticsState = XComGameState_Analytics(NewStartState.ModifyStateObject(class'XComGameState_Analytics', AnalyticsState.ObjectID));
		
	// copy the hq
	DioHQ = XComGameState_HeadquartersDio(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio'));
	DioHQ = XComGameState_HeadquartersDio(NewStartState.ModifyStateObject(class'XComGameState_HeadquartersDio', DioHQ.ObjectID));
	DioHQ.MissionRef = MissionSiteRef.GetReference();

	//Copy time state into the new start state
	TimeState = XComGameState_GameTime(History.GetSingleGameStateObjectForClass(class'XComGameState_GameTime'));
	TimeState = XComGameState_GameTime(NewStartState.ModifyStateObject(class'XComGameState_GameTime', TimeState.ObjectID));

	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
	DialogueManager = XComGameState_DialogueManager(NewStartState.ModifyStateObject(class'XComGameState_DialogueManager', DialogueManager.ObjectID));

	//Copy data that was previously prepared into the battle data
	`assert(!BattleData.bReadOnly);

	// not sure why exactly, but sometimes the MarkupDef data gets wiped.
	if (MissionSiteRef.GeneratedMission.MarkupDef.MarkupMapname == "")
	{
		if (!MissionSiteRef.SelectMarkupMap(MissionSiteRef.GeneratedMission))
		{
			return;
		}
	}

	//Cache values that will be referred to for the rest of this launch sequence
	MissionState = MissionSiteRef;
	GeneratedMission = MissionSiteRef.GeneratedMission;	

	MissionTemplate = MissionTemplateManager.FindMissionTemplate(GeneratedMission.Mission.MissionName);
	if (MissionTemplate != none)
	{
		MissionBriefing = MissionTemplate.Briefing;
	}
	else
	{
		MissionBriefing = "NO LOCALIZED BRIEFING TEXT!";
	}

	BattleData.m_bIsFirstMission = false; //DIO - replace with logic to determine whether this is the tutorial or not
	BattleData.iLevelSeed = GeneratedMission.LevelSeed;
	BattleData.m_strDesc = MissionBriefing;
	BattleData.m_strOpName = GeneratedMission.BattleOpName;
	BattleData.MapData.PlotMapName = GeneratedMission.Plot.MapName;
	BattleData.MapData.Biome = GeneratedMission.Biome.strType;

	if (GeneratedMission.RoomLimit > 0)
	{
		BattleData.SetRoomLimit(GeneratedMission.RoomLimit);
	}


	//Update the BattleData with the room sequence from the markup definition
	class'XComGameState_MissionSite'.static.ResolveRoomSequenceIntoStoredMapData(BattleData, GeneratedMission.MarkupDef);

	DioHQ.AddMissionTacticalTags(MissionState);

	// Make the map command based on whether we are riding the dropship to the mission or not
	class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().ClientSetCameraFade(true, MakeColor(0, 0, 0), vect2d(0, 1), 0.0);
	`HQPRES.HideUIForCinematics();
	if (MissionState.GetMissionSource().bRequiresVehicleTravel)
	{
		`XENGINE.PlaySpecificLoadingMovie("1080_Black.bik");
		`XENGINE.PlayLoadMapMovie(-1);
		BattleData.m_strMapCommand = "open" @ GeneratedMission.Plot.MapName $ "?game=XComGame.XComTacticalGame";
	}
	else
	{
		if (MissionState.GetMissionSource().CustomLoadingMovieName_Intro != "")
		{
			`XENGINE.PlaySpecificLoadingMovie(MissionState.GetMissionSource().CustomLoadingMovieName_Intro, MissionState.GetMissionSource().CustomLoadingMovieName_IntroSound);
			`XENGINE.PlayLoadMapMovie(-1);
		}
		BattleData.m_strMapCommand = "open" @ GeneratedMission.Plot.MapName $ "?game=XComGame.XComTacticalGame";
	}

	// For civilian behavior (may be deprecated)
	BattleData.SetPopularSupport(0);
	BattleData.SetMaxPopularSupport(1000);

	BattleData.LocalTime = TimeState.CurrentTime;
	MissionCoordinates.X = MissionState.Location.X;
	MissionCoordinates.Y = MissionState.Location.Y;
	class'X2StrategyGameRulesetDataStructures'.static.GetLocalizedTime(MissionCoordinates, BattleData.LocalTime);
	BattleData.m_strLocation = MissionState.GetLocationDescription();

	BattleData.m_iMissionID = MissionState.ObjectID;
	BattleData.bRainIfPossible = FRand() < class'XGStrategy'.default.RainPctChance; // if true, doesn't guarantee rain, map must be able to support raining.

	BattleData.MapData.bMonolithic = GeneratedMission.Plot.bMonolithic;

	MissionManager.ForceMission = GeneratedMission.Mission; // do we need to set this?
	MissionManager.ActiveMission = GeneratedMission.Mission; // needed for schedule selection
	MissionManager.MissionQuestItemTemplate = GeneratedMission.MissionQuestItemTemplate;

	XComPlayerRef = BattleData.PlayerTurnOrder[0];

	// Retrieve Mission Action
	MissionAction = MissionState.GetMissionAction(NewStartState);

	// Mission Squad is the units assigned to the Mission Action
	MissionSquad = MissionAction.AssignedUnitRefs;

	//Add starting units and their inventory items
	//Assume that the squad limits were followed correctly in the HQ UI
	for (UnitIndex = 0; UnitIndex < MissionSquad.Length; ++UnitIndex)
	{
		if (MissionSquad[UnitIndex].ObjectID <= 0)
			continue;

		SendSoldierState = XComGameState_Unit(History.GetGameStateForObjectID(MissionSquad[UnitIndex].ObjectID));

		if (!SendSoldierState.IsSoldier() && !SendSoldierState.GetMyTemplate().bTreatAsSoldier) { `HQPRES.PopupDebugDialog("ERROR", "Attempting to send a non-soldier unit to battle."); continue; }
		if (!SendSoldierState.IsAlive()) { `HQPRES.PopupDebugDialog("ERROR", "Attempting to send a dead soldier to battle."); continue; }

		SendSoldierState = XComGameState_Unit(NewStartState.ModifyStateObject(class'XComGameState_Unit', SendSoldierState.ObjectID));

		//Add this soldier's items to the start state
		for (ItemIndex = 0; ItemIndex < SendSoldierState.InventoryItems.Length; ++ItemIndex)
		{
			NewStartState.ModifyStateObject(class'XComGameState_Item', SendSoldierState.InventoryItems[ItemIndex].ObjectID);
		}

		SendSoldierState.SetControllingPlayer(XComPlayerRef);
		SendSoldierState.SetHQLocation(eSoldierLoc_Dropship);
		SendSoldierState.ClearRemovedFromPlayFlag();
	}

	// Add any backup units to the BattleData/State
	foreach MissionState.BackUpUnits(BackupData)
	{
		SendSoldierState = XComGameState_Unit(NewStartState.ModifyStateObject(class'XComGameState_Unit', BackupData.UnitRef.ObjectID));
		SendSoldierState.SetControllingPlayer(XComPlayerRef);
		SendSoldierState.RemoveStateFromPlay();

		BattleData.BackupUnitRefs.AddItem(BackupData.UnitRef);

		//Add this android's items to the start state
		for (ItemIndex = 0; ItemIndex < SendSoldierState.InventoryItems.Length; ++ItemIndex)
		{
			NewStartState.ModifyStateObject(class'XComGameState_Item', SendSoldierState.InventoryItems[ItemIndex].ObjectID);
		}
	}

	// Add any reserve androids to the BattleData/State
	BattleData.StartingAndroidReserves.Length = 0;
	BattleData.SpentAndroidReserves.Length = 0;
	foreach DioHQ.Androids(AndroidReference)
	{
		// androids sent on missions as part of the squad are NOT counted in the reserves
		if (MissionSquad.Find('ObjectID', AndroidReference.ObjectID) != INDEX_NONE)
		{
			continue;
		}

		// Only alive androids can be used in reserve
		SendSoldierState = XComGameState_Unit(History.GetGameStateForObjectID(AndroidReference.ObjectID));
		if (!SendSoldierState.IsAndroid() || !SendSoldierState.IsAlive())
		{
			continue;
		}

		SendSoldierState = XComGameState_Unit(NewStartState.ModifyStateObject(class'XComGameState_Unit', SendSoldierState.ObjectID));

		//Add this android's items to the start state
		for (ItemIndex = 0; ItemIndex < SendSoldierState.InventoryItems.Length; ++ItemIndex)
		{
			NewStartState.ModifyStateObject(class'XComGameState_Item', SendSoldierState.InventoryItems[ItemIndex].ObjectID);
		}

		SendSoldierState.SetControllingPlayer(XComPlayerRef);
		//SendSoldierState.SetHQLocation(eSoldierLoc_Dropship); //TODO: Where should reserve androids appear??
		SendSoldierState.RemoveStateFromPlay(); //dakota.lemaster: SUPER IMPORTANT that reserve androids start removed from play. If this interferes with HQ visualizers then we can move this check elsewhere potentially

		BattleData.StartingAndroidReserves.AddItem(AndroidReference); //dakota.lemaster: IMPORTANT to log this android in the battledata as a reserve unit, so it knows how to be called from the reserves later
	}

	//Add any reward personnel to the battlefield
	for (RewardIndex = 0; RewardIndex < MissionState.Rewards.Length; ++RewardIndex)
	{
		RewardStateObject = XComGameState_Reward(History.GetGameStateForObjectID(MissionState.Rewards[RewardIndex].ObjectID));
		SendSoldierState = XComGameState_Unit(History.GetGameStateForObjectID(RewardStateObject.RewardObjectReference.ObjectID));
		if (MissionState.IsVIPMission() && SendSoldierState != none)
		{
			//Add the reward unit to the battle

			// create a proxy if needed. This allows the artists and LDs to create simpler standin versions of units,
			// for example soldiers without weapons.
			// Unless the reward is a soldier with a tactical tag to be specifically passed into the mission
			ProxySoldierState = none;
			if (RewardStateObject.GetMyTemplateName() != 'Reward_Soldier' || SendSoldierState.TacticalTag == '')
			{
				ProxySoldierState = class'XComTacticalMissionManager'.static.CreateProxyRewardUnitIfNeeded(SendSoldierState, NewStartState);
			}

			if (ProxySoldierState == none)
			{
				// no proxy needed, so just send the original
				ProxySoldierState = SendSoldierState;
			}

			// all reward units start on the neutral team
			ProxySoldierState.SetControllingPlayer(BattleData.CivilianPlayerRef);

			//Track which units the battle is considering to be rewards ( used later when spawning objectives ).
			BattleData.RewardUnits.AddItem(ProxySoldierState.GetReference());

			// Also keep track of what the original unit was that the proxy was spawned from. If no proxy was made,
			// then just insert a null so we know there was no original
			BattleData.RewardUnitOriginals.AddItem(SendSoldierState.GetReference());
		}
	}

	// allow sitreps to modify the battle data state before we transition to tactical
	class'X2SitRepTemplate'.static.ModifyPreMissionBattleDataState(BattleData, MissionState.GeneratedMission.SitReps);

	// DLC and mod support
	EventManager = `ONLINEEVENTMGR;
	DLCInfos = EventManager.GetDLCInfos(false);
	for (i = 0; i < DLCInfos.Length; ++i)
	{
		DLCInfos[i].OnPreMission(NewStartState, MissionState);
	}

	if (BattleData.m_iMissionID > 0 && !BattleData.bIsTacticalQuickLaunch)
	{
		BattleData.SetAlertLevel(MissionManager.CalculateAlertLevelFromDifficultyParams(MissionState.MissionDifficultyParams));
		BattleData.SetForceLevel(MissionState.MissionDifficultyParams.Act);
	}

	SelectedMissionSchedule = MissionManager.ChooseMissionSchedule(MissionManager);
	MissionManager.SetActiveMissionScheduleIndex(SelectedMissionSchedule);
	
	class'XComGameState_BattleData'.static.MarkBattleLaunchedTime();	

	EncounterData = XComGameState_EncounterData(History.GetSingleGameStateObjectForClass(class'XComGameState_EncounterData'));
	if (EncounterData != none)
	{
		EncounterData = XComGameState_EncounterData(NewStartState.ModifyStateObject(class'XComGameState_EncounterData', EncounterData.ObjectID));
	}
	else
	{
		EncounterData = XComGameState_EncounterData(NewStartState.CreateNewStateObject(class'XComGameState_EncounterData'));
	}
	`SPAWNMGR.BuildEncountersSimple(EncounterData, DioHQ, BattleData);

	//Tell the content manager to build its list of required content based on the game state that we just built and added.
	`CONTENT.RequestContent(NewStartState);

	// at the end of the session, the event listener needs to be cleared of all events and listeners; reset it
	`XEVENTMGR.ResetToDefaults(false);

	`XENGINE.m_kPhotoManager.CleanupUnusedTextures();

	`XEVENTMGR.TriggerEvent('Analytics_LaunchTacticalMission', self, self);

	//Launch into the tactical map - the start state is automatically submitted by the map loading process.
	ConsoleCommand(BattleData.m_strMapCommand);	
}

//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------
/*



				TACTICAL to STRATEGY



*/
//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------

/// <summary>
/// Used to create a strategy game start state from a tactical battle
/// </summary>
static function XComGameState CreateStrategyGameStartFromTactical()
{
	local XComGameStateHistory History;
	local XComGameState StartState;
	local XComGameStateContext_DioStrategyStart StrategyStartContext;
	local XComGameState PriorStrategyState;
	local int PreStartStateIndex;
	local XComGameState_BaseObject StateObject;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_ObjectivesList ObjectivesList;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	//Build a game state that contains the full state of every object that existed in the strategy
	//game session prior to the current tactical match
	PreStartStateIndex = History.FindStartStateIndex() - 1;
	PriorStrategyState = History.GetGameStateFromHistory(PreStartStateIndex, eReturnType_Copy, false);

	//Now create the strategy start state and add it to the history
	StrategyStartContext = XComGameStateContext_DioStrategyStart(class'XComGameStateContext_DioStrategyStart'.static.CreateXComGameStateContext());
	StrategyStartContext.InputStartType = eStrategyStartType_FromTactical;
	StartState = History.CreateNewGameState(false, StrategyStartContext);


	//Iterate all the game states in the strategy game state built above and create a new entry in the 
	//start state we are building for each one. If any of the state objects were changed / updated in the
	//tactical battle, their changes are automatically picked up by this process.
	//
	//Caveat: Currently this assumes that the only objects that can return from tactical to strategy are those 
	//which were created in the strategy game. Additional logic will be necessary to transfer NEW objects 
	//created within tactical.
	foreach PriorStrategyState.IterateByClassType(class'XComGameState_BaseObject', StateObject)
	{
		StartState.ModifyStateObject(StateObject.Class, StateObject.ObjectID);
	}

	foreach StartState.IterateByClassType(class'XComGameState_HeadquartersDio', DioHQ)
	{
		break;
	}

	`assert(BattleData.m_iMissionID == DioHQ.MissionRef.ObjectID);
	BattleData = XComGameState_BattleData(StartState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	ObjectivesList = XComGameState_ObjectivesList(History.GetSingleGameStateObjectForClass(class'XComGameState_ObjectivesList'));
	ObjectivesList = XComGameState_ObjectivesList(StartState.ModifyStateObject(class'XComGameState_ObjectivesList', ObjectivesList.ObjectID));

	// clear completed & failed objectives on transition back to strategy
	ObjectivesList.ClearTacticalObjectives();

	//The start state is automatically submitted by the map loading process.

	return StartState;
}

//---------------------------------------------------------------------------------------
static function CompleteStrategyFromTacticalTransfer()
{
	//HELIOS BEGIN
	local XComOnlineEventMgr EventManager;
	local array<X2DownloadableContentInfo> DLCInfos;
	local int i;
	//HELIOS END

	local bool bWasTutorialMission;

	bWasTutorialMission = ProcessMissionResults();
	TacticalToStrategySquadCleanup(bWasTutorialMission);
	TacticalToStrategyGradeMission();

	//HELIOS BEGIN
	EventManager = `ONLINEEVENTMGR;
	DLCInfos = EventManager.GetDLCInfos(false);
	for (i = 0; i < DLCInfos.Length; ++i)
	{
		DLCInfos[i].OnPostMission();
	}
	//HELIOS END
}

//---------------------------------------------------------------------------------------
/// <summary>
/// Removes mission and handles rewards
/// </summary>
static function bool ProcessMissionResults()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_MissionSite MissionState;
	local XComGameState_StrategyAction_Mission MissionAction;
	local X2MissionSourceTemplate MissionSource;
	local X2StrategyGameRuleset StratRules;
	local bool bMissionSuccess;
	local bool bWasTutorialMission;

	History = `XCOMHISTORY;
	StratRules = `STRATEGYRULES;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Mission Results");

	DioHQ = XComGameState_HeadquartersDio(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));
	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(DioHQ.MissionRef.ObjectID));

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`assert(BattleData.m_iMissionID == MissionState.ObjectID);

	MissionAction = MissionState.GetMissionAction(NewGameState);
	`assert(MissionAction != none);

	bWasTutorialMission = (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive') != INDEX_NONE);

	// Main objective success/failure hooks
	bMissionSuccess = BattleData.bLocalPlayerWon;

	// Award XP: Mission + per-Unit kills
	class'X2ExperienceConfig'.static.AwardMissionXP(NewGameState, MissionAction, BattleData.bMissionAborted);

	if (bMissionSuccess)
	{
		// Action Completion! Give rewards, build result
		MissionAction.CompleteAction(NewGameState);
	}
	else if (BattleData.bMissionAborted)
	{
		MissionAction.AbortAction(NewGameState);
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		return false;
	}

	// Apply effects
	MissionSource = MissionState.GetMissionSource();
	if (bMissionSuccess)
	{
		// Global success effects
		if (!bWasTutorialMission)
		{
			StratRules.ApplyMissionSuccessResults(NewGameState, DioHQ.MissionRef);
		}

		// Mission-specific success effects
		if (MissionSource.OnSuccessFn != none)
		{
			MissionSource.OnSuccessFn(NewGameState, MissionState);
		}
	}
	else
	{
		// Global fail effects
		StratRules.ApplyMissionFailResults(NewGameState, DioHQ.MissionRef);

		// Mission-specific fail effects
		if (MissionSource.OnFailureFn != none)
		{
			MissionSource.OnFailureFn(NewGameState, MissionState);
		}
	}

	DioHQ.OnMissionActionComplete(NewGameState, MissionAction.GetMyTemplateName());
	
	// Clear tactical tags
	DioHQ.RemoveMissionTacticalTags(MissionState);
	//DIOTUTORIAL: clear tutorial mission tag
	DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive'); // clear tutorial mission tag
	DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive_Room_-1');//in case of an index_none lookup later
	DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive_Room_0');
	DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive_Room_1');
	DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive_Room_2');

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	return bWasTutorialMission;
}

//---------------------------------------------------------------------------------------
/// <summary>
/// Modify the squad and related items as they come into strategy from tactical
/// e.g. Move backpack items into storage, roll for scars, etc.
/// </summary>
static function TacticalToStrategySquadCleanup(bool bWasTutorialMission)
{
	local XComGameState NewGameState;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit UnitState;
	local XComGameState_MissionSite MissionState;
	local XComGameState_StrategyAction_Mission MissionAction;
	local XComGameStateHistory History;
	local X2EventManager EventManager;
	local XComGameState_BattleData BattleData;	
	local array<StateObjectReference> MissionSquad;
	local array<StateObjectReference> SoldiersToTransfer;
	local array<ScarCandidateData> ScarCandidates;
	local ScarCandidateData TempCandidateData;
	local float RandRoll, ScarChance;
	local int idx, idx2, MaxScars;

	EventManager = `XEVENTMGR;
	History = `XCOMHISTORY;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Post Mission Squad Cleanup");
	DioHQ = XComGameState_HeadquartersDio(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(DioHQ.MissionRef.ObjectID));
	MissionAction = MissionState.GetMissionAction(NewGameState);
	MissionSquad = MissionAction.AssignedUnitRefs;

	// Handle transfer of units back to strategy
	SoldiersToTransfer = MissionSquad;
	ScarCandidates.Length = 0;
	for (idx = 0; idx < SoldiersToTransfer.Length; idx++)
	{
		if (SoldiersToTransfer[idx].ObjectID != 0)
		{
			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', SoldiersToTransfer[idx].ObjectID));
			UnitState.iNumMissions++;

			UnitState.ClearRemovedFromPlayFlag();

			// First remove any units provided by the mission
			if (UnitState.bMissionProvided)
			{
				idx2 = MissionSquad.Find('ObjectID', UnitState.ObjectID);
				if (idx2 != INDEX_NONE)
					MissionSquad.Remove(idx2, 1);

				continue; // Skip the rest of the transfer processing for the mission provided unit, since they shouldn't return to strategy
			}

			// Handle any additional unit transfers events (e.g. Analytics)
			EventManager.TriggerEvent('SoldierTacticalToStrategy', UnitState, UnitState, NewGameState);

			//  Unload backpack (loot) items from any live or recovered soldiers, and retrieve inventory for dead soldiers
			PostMissionUpdateSoldierItems(NewGameState, BattleData, UnitState);

			// Check for Rank Ups ready
			if (UnitState.CanRankUpSoldier())
			{
				UnitState.RankUpSoldier(NewGameState, UnitState.GetSoldierClassTemplateName());
				class'XComGameState_UnitPromotionResult'.static.BuildPromotionResult(NewGameState, SoldiersToTransfer[idx]);
			}

			// Collect Scar Candidates (apply scars below)
			if (!bWasTutorialMission)
			{
				TempCandidateData.UnitReference = UnitState.GetReference();
				ScarChance = class'DioStrategyAI'.static.CalculateUnitScarChance(UnitState, TempCandidateData.ScarSource);
				if (ScarChance > 0.0)
				{
					RandRoll = `SYNC_RAND_STATIC(100);
					if (RandRoll <= ScarChance)
					{
						ScarCandidates.AddItem(TempCandidateData);
					}
				}
			}
			UnitState.ResetScarChanceFlags(NewGameState);

			// Reset assignment status for Android units
			if (UnitState.IsAndroid())
			{
				UnitState.SetAssignment(eAssignment_Unassigned);
			}
		}
	}

	if (ScarCandidates.Length > 0)
	{
		// How many scars can be earned on a single mission?
		MaxScars = class'DioStrategyAI'.static.GetMaxScarsPerMission();

		// If more candidates than cap, sort
		if (ScarCandidates.Length > MaxScars)
		{
			ScarCandidates.Sort(class'DioStrategyAI'.static.SortScarCandidateUnits);
		}

		// Apply scars
		for (idx = 0; idx < MaxScars; ++idx)
		{ 
			if (idx >= ScarCandidates.Length)
			{
				break;
			}

			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', ScarCandidates[idx].UnitReference.ObjectID));
			UnitState.ProgressScars(NewGameState, ScarCandidates[idx].ScarSource, MissionState.ObjectID);
		}
	}

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

//---------------------------------------------------------------------------------------
static function TacticalToStrategyGradeMission()
{
	local XComGameState NewGameState;
	local XComGameState_BattleData BattleData;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Post Mission Set Grade");
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
	BattleData.SetPostMissionGrade();

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

//---------------------------------------------------------------------------------------
private static function PostMissionUpdateSoldierItems(XComGameState NewGameState, XComGameState_BattleData BattleData, XComGameState_Unit UnitState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyInventory Inventory;
	local XComGameState_Item ItemState;
	local bool bRemoveItemStatus;
	local int ItemIndex;

	DioHQ = XComGameState_HeadquartersDio(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));
	Inventory = XComGameState_StrategyInventory(NewGameState.ModifyStateObject(class'XComGameState_StrategyInventory', DioHQ.Inventory.ObjectID));

	//  Transfer all inventory items
	if (!UnitState.IsDead())
	{
		//Add this soldier's items to the start state
		for (ItemIndex = 0; ItemIndex < UnitState.InventoryItems.Length; ++ItemIndex)
		{
			ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', UnitState.InventoryItems[ItemIndex].ObjectID));

			// Move items in the backpack (loot) slot into HQ inventory
			if (ItemState.InventorySlot == eInvSlot_Backpack)
			{
				bRemoveItemStatus = UnitState.RemoveItemFromInventory(ItemState, NewGameState);
				`assert(bRemoveItemStatus);

				ItemState.OwnerStateObject = DioHQ.GetReference();
				Inventory.AddItem(NewGameState, ItemState.GetReference());

				BattleData.CarriedOutLootBucket.AddItem(ItemState.GetMyTemplateName());
			}
		}
	}
}