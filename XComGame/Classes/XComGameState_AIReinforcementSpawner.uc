
//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    XComGameState_AIReinforcementSpawner.uc    
//  AUTHOR:  Dan Kaplan  --  2/16/2015
//  PURPOSE: Holds all state data relevant to a pending spawn of a reinforcement group of AIs.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameState_AIReinforcementSpawner extends XComGameState_BaseObject
	implements(X2VisualizedInterface)
	native(AI);

// The list of unit IDs that were spawned from this spawner
var array<int> SpawnedUnitIDs;

// Tthe type of spawn visulaization to perform on this reinforcements group
var Name SpawnVisualizationType;

// If true, this Reinforcement spawner will not spawn units in LOS of XCom units
var bool bDontSpawnInLOSOfXCOM;

// If true, this Reinforcement spawner will only spawn units in LOS of XCom units
var bool bMustSpawnInLOSOfXCOM;

// If true, this Reinforcement spawner will not spawn units in hazards
var bool bDontSpawnInHazards;

// If true, this Reinforcement spawner will force the resulting group to scamper after spawning even though they may not be in LOS
var bool bForceScamper;

// The SpawnInfo for the group that will be created by this spawner
var PodSpawnInfo SpawnInfo;

// If using an ATT, this is the ref to the ATT unit that is created
var StateObjectReference TroopTransportRef;

// The number of AI turns remaining until the reinforcements are spawned
var int Countdown;

// If true, these reinforcements were initiated from kismet
var bool bKismetInitiatedReinforcements;

// If true, the reinforcements were canceled
var bool bReinforcementsCanceled;

// The spawn point group tag specified when the reinforcement is called
var name SpawnPointGroupTag;

var EReinforcementInboundTimelinePlacementType InboundTimelinePlacementType;

// wrappers for the string literals on the spawn's change container contexts. Allows us to easily ensure that 
// the names don't get out of sync from the various systems that need to use them.
var const string SpawnReinforcementsChangeDesc;
var const string SpawnReinforcementsCompleteChangeDesc;

var array<int> ReinforcementEntryPointsIndicatorIds;

const ReinforcementIndicatorIconPath = "img:///UILibrary_Common.objective_reinforcementSpawnPoint";
const CommandoReinforcementIndicatorIconPath = "img:///UILibrary_Common.objective_reinforcementSpawnPoint";

function OnBeginTacticalPlay(XComGameState NewGameState)
{
	local X2EventManager EventManager;
	local Object ThisObj;

	super.OnBeginTacticalPlay(NewGameState);

	EventManager = `XEVENTMGR;
	ThisObj = self;
	EventManager.RegisterForEvent(ThisObj, 'ReinforcementSpawnerCreated', OnReinforcementSpawnerCreated, ELD_OnStateSubmitted, , ThisObj);
	EventManager.TriggerEvent('ReinforcementSpawnerCreated', ThisObj, ThisObj, NewGameState);
	EventManager.RegisterForEvent(ThisObj, 'PendingReinforcements_Canceled', OnSpawnReinforcementsCanceled, ELD_OnStateSubmitted);
}

function OnEndTacticalPlay(XComGameState NewGameState)
{
	local X2EventManager EventManager;
	local Object ThisObj;

	super.OnEndTacticalPlay(NewGameState);

	EventManager = `XEVENTMGR;
	ThisObj = self;
	EventManager.UnRegisterFromEvent(ThisObj, 'ReinforcementSpawnerCreated');
	EventManager.UnRegisterFromEvent(ThisObj, 'PlayerTurnBegun');
	EventManager.UnRegisterFromEvent(ThisObj, 'SpawnReinforcementsComplete');
	EventManager.UnRegisterFromEvent(ThisObj, 'RoundBegun');
	EventManager.UnRegisterFromEvent(ThisObj, 'PendingReinforcements_Canceled');
}

// This is called after this reinforcement spawner has finished construction
function EventListenerReturn OnReinforcementSpawnerCreated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;
	local XComGameState_AIReinforcementSpawner NewSpawnerState;
	local X2EventManager EventManager;
	local Object ThisObj;
	local X2CharacterTemplate SelectedTemplate;
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local Name CharTemplateName;
	local X2CharacterTemplateManager CharTemplateManager;
	local X2TacticalGameRuleset TacRuleset;
	local XComGameState_Unit ActiveUnitState;
	local XComGameState_Ability AbilityState;
	local XComGameStateContext_Ability AbilityContext;
	local XComWorldData WorldData;
	local XComGameState_IndicatorArrow IndicatorArrowState;
	local TargetPoint ReinforcementEntryPoint;
	local array<TargetPoint> MissionReinforcementEntryPoints, CommandoReinforcementEntryPoints, ReinforcementEntryPoints;
	local bool bCommandoReinforcement;
	local array<XComGameState_Unit> BreachUnits;

	CharTemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();

	History = `XCOMHISTORY;
	TacRuleset = `TACTICALRULES;
	WorldData = `XWORLD;

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	// Select the spawning visualization mechanism and build the persistent in-world visualization for this spawner
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));

	NewSpawnerState = XComGameState_AIReinforcementSpawner(NewGameState.ModifyStateObject(class'XComGameState_AIReinforcementSpawner', ObjectID));

	NewSpawnerState.SpawnInfo.Team = eTeam_Alien;

	// explicitly disabled all timed loot from reinforcement groups
	NewSpawnerState.SpawnInfo.bGroupDoesNotAwardLoot = true;

	NewSpawnerState.bReinforcementsCanceled = false;

	// collect reinforcement entry points 
	foreach class'WorldInfo'.static.GetWorldInfo().AllActors(class'TargetPoint', ReinforcementEntryPoint)
	{
		if (ReinforcementEntryPoint.Tag == 'Reinforcements')
		{
			if (WorldData.GetRoomIDByLocationNative(ReinforcementEntryPoint.Location) == BattleData.BreachingRoomID)
			{
				MissionReinforcementEntryPoints.AddItem(ReinforcementEntryPoint);
			}
		}
		else if (ReinforcementEntryPoint.Tag == 'CommandoReinforcements')
		{
			if (WorldData.GetRoomIDByLocationNative(ReinforcementEntryPoint.Location) == BattleData.BreachingRoomID)
			{
				CommandoReinforcementEntryPoints.AddItem(ReinforcementEntryPoint);
			}
		}
	}

	// create UI indicators
	// we use untagged spawners for commando reinforcements. 
	// LDs are still in the process of placing target points for these generic spawners. 
	// so fallback to using mission spawners if there isn't any targetpoints for commando reinforcements
	bCommandoReinforcement = NewSpawnerState.SpawnPointGroupTag == '';
	ReinforcementEntryPoints = (bCommandoReinforcement && CommandoReinforcementEntryPoints.length > 0) ? CommandoReinforcementEntryPoints : MissionReinforcementEntryPoints;

	foreach ReinforcementEntryPoints(ReinforcementEntryPoint)
	{
		IndicatorArrowState = class'XComGameState_IndicatorArrow'.static.CreateArrowPointingAtLocation(ReinforcementEntryPoint.Location, 0, eUIState_Bad, , bCommandoReinforcement ? CommandoReinforcementIndicatorIconPath: ReinforcementIndicatorIconPath, NewGameState);
		NewSpawnerState.ReinforcementEntryPointsIndicatorIds.AddItem(IndicatorArrowState.ObjectID);
	}

	// fallback to 'PsiGate' visualization if the requested visualization is using 'ATT' but that cannot be supported
	if( NewSpawnerState.SpawnVisualizationType == 'ATT' )
	{
		// determine if the spawning mechanism will be via ATT or PsiGate
		//  A) ATT requires open sky above the reinforcement location
		//  B) ATT requires that none of the selected units are oversized (and thus don't make sense to be spawning from ATT)
		if( DoesLocationSupportATT(NewSpawnerState.SpawnInfo.SpawnLocation) )
		{
			// determine if we are going to be using psi gates or the ATT based on if the selected templates support it
			foreach NewSpawnerState.SpawnInfo.SelectedCharacterTemplateNames(CharTemplateName)
			{
				SelectedTemplate = CharTemplateManager.FindCharacterTemplate(CharTemplateName);

				if( !SelectedTemplate.bAllowSpawnFromATT )
				{
					NewSpawnerState.SpawnVisualizationType = 'PsiGate';
					break;
				}
			}
		}
		else
		{
			NewSpawnerState.SpawnVisualizationType = 'PsiGate';
		}
	}

	if( NewSpawnerState.SpawnVisualizationType != '' && 
	   NewSpawnerState.SpawnVisualizationType != 'TheLostSwarm' && 
	   NewSpawnerState.SpawnVisualizationType != 'ChosenSpecialNoReveal' &&
	   NewSpawnerState.SpawnVisualizationType != 'ChosenSpecialTopDownReveal' )
	{
		XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = NewSpawnerState.BuildVisualizationForSpawnerCreation;
		NewGameState.GetContext().SetAssociatedPlayTiming(SPT_AfterSequential);
	}

	TacRuleset.SubmitGameState(NewGameState);

	// no countdown specified, spawn reinforcements immediately
	if( Countdown <= 0 )
	{
		NewSpawnerState.SpawnReinforcements();
	}
	// countdown is active, need to listen for AI Turn Begun in order to tick down the countdown
	else
	{
		TacRuleset.GetCurrentInitiativeGroup(ActiveUnitState);
		if (ActiveUnitState == None)
		{
			class'XComBreachHelpers'.static.GatherXComBreachUnits(BreachUnits);
			ActiveUnitState = BreachUnits[0];
		}
		if (ActiveUnitState != none)
		{
			AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(ActiveUnitState.FindAbility('CallReinforcement').ObjectID));
			if (AbilityState != none)
			{
				EventManager = `XEVENTMGR;
				ThisObj = self;
				EventManager.RegisterForEvent(ThisObj, class'X2Effect_PendingReinforcements'.default.EventRemovedTriggerName, OnReinforcementTimerComplete, ELD_OnStateSubmitted);
				EventManager.RegisterForEvent(ThisObj, class'X2Effect_PendingReinforcements'.default.EventTickedTriggerName, OnReinforcementTimerTick, ELD_PreStateSubmitted);

				AbilityContext = class'XComGameStateContext_Ability'.static.BuildContextFromAbility(AbilityState, ActiveUnitState.ObjectID);
				// using item object here to store this reinforcement state object
				// so that X2Effect_PendingReinforcements can query vars such as countdown
				AbilityContext.InputContext.ItemObject = GetReference(); 
				TacRuleset.SubmitGameStateContext(AbilityContext);
			}
		}
	}

	return ELR_NoInterrupt;
}

// TODO: update this function to better consider the space that an ATT requires
private function bool DoesLocationSupportATT(Vector TargetLocation)
{
	local TTile TargetLocationTile;
	local TTile AirCheckTile;
	local VoxelRaytraceCheckResult CheckResult;
	local XComWorldData WorldData;

	WorldData = `XWORLD;

		TargetLocationTile = WorldData.GetTileCoordinatesFromPosition(TargetLocation);
	AirCheckTile = TargetLocationTile;
	AirCheckTile.Z = WorldData.NumZ - 1;

	// the space is free if the raytrace hits nothing
	return (WorldData.VoxelRaytrace_Tiles(TargetLocationTile, AirCheckTile, CheckResult) == false);
}


function EventListenerReturn OnReinforcementTimerTick(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_AIReinforcementSpawner NewSpawnerState;

	if (Countdown > 0)
	{
		NewSpawnerState = XComGameState_AIReinforcementSpawner(GameState.ModifyStateObject(class'XComGameState_AIReinforcementSpawner', ObjectID));
		--NewSpawnerState.Countdown;
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn OnReinforcementTimerComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Effect EffectState;

	EffectState = XComGameState_Effect(EventSource);
	if (EffectState.ApplyEffectParameters.AbilityInputContext.ItemObject.ObjectID == ObjectID)
	{
		SpawnReinforcements();
	}

	return ELR_NoInterrupt;
}

function SpawnReinforcements()
{
	local XComGameState NewGameState;
	local XComGameState_AIReinforcementSpawner NewSpawnerState;
	local X2EventManager EventManager;
	local Object ThisObj;
	local XComAISpawnManager SpawnManager;
	local XGAIGroup SpawnedGroup;
	local X2GameRuleset Ruleset;

	if( bReinforcementsCanceled )
	{
		return;
	}

	EventManager = `XEVENTMGR;
	SpawnManager = `SPAWNMGR;
	Ruleset = `XCOMGAME.GameRuleset;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(default.SpawnReinforcementsChangeDesc);
	XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = BuildVisualizationForUnitSpawning;

	NewSpawnerState = XComGameState_AIReinforcementSpawner(NewGameState.ModifyStateObject(class'XComGameState_AIReinforcementSpawner', ObjectID));

	// set the group tag
	NewSpawnerState.SpawnInfo.SpawnPointGroupTag = SpawnPointGroupTag;

	// limit the size based on the number of available spawn points
	LimitReinforcementSpawnCount(NewSpawnerState.SpawnInfo);

	// spawn the units
	SpawnedGroup = SpawnManager.SpawnPodAtLocation(
		NewGameState,
		NewSpawnerState.SpawnInfo,
		bMustSpawnInLOSOfXCOM,
		bDontSpawnInLOSOfXCOM,
		bDontSpawnInHazards);

	// clear the ref to this actor to prevent unnecessarily rooting the level
	SpawnInfo.SpawnedPod = None;
	NewSpawnerState.SpawnInfo.SpawnedPod = None;

	// cache off the spawned unit IDs
	NewSpawnerState.SpawnedUnitIDs = SpawnedGroup.m_arrUnitIDs;

	ThisObj = self;
	EventManager.RegisterForEvent(ThisObj, 'SpawnReinforcementsComplete', OnSpawnReinforcementsComplete, ELD_OnStateSubmitted,, ThisObj);
	EventManager.TriggerEvent('SpawnReinforcementsComplete', ThisObj, ThisObj, NewGameState);

	NewGameState.GetContext().SetAssociatedPlayTiming(SPT_AfterSequential);

	Ruleset.SubmitGameState(NewGameState);
}

// This is called after the reinforcement spawned
function EventListenerReturn OnSpawnReinforcementsComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local array<XComGameState_Unit> AffectedUnits;
	local XComGameState_Unit AffectedUnit;
	local int i;
	local array<TTile> SpawnPointTiles;
	local array<XComReinforcementSpawnPointMarker> SpawnPointMarkers;
	local XComReinforcementSpawnPointMarker SpawnPoint;
	local XComWorldData WorldData;
	local XComGameState_BattleData BattleData;
	if( bReinforcementsCanceled )
	{
		return ELR_NoInterrupt;
	}
	History = `XCOMHISTORY;
	WorldData = `XWORLD;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(default.SpawnReinforcementsCompleteChangeDesc);

	if( SpawnVisualizationType != '' && 
	   SpawnVisualizationType != 'TheLostSwarm' &&
	   SpawnVisualizationType != 'ChosenSpecialNoReveal' &&
	   SpawnVisualizationType != 'ChosenSpecialTopDownReveal' )
	{
		XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = BuildVisualizationForSpawnerDestruction;
	}

	for( i = 0; i < SpawnedUnitIDs.Length; ++i )
	{
		AffectedUnits.AddItem(XComGameState_Unit(History.GetGameStateForObjectID(SpawnedUnitIDs[i])));
		AffectedUnit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', SpawnedUnitIDs[i]));

		// allow room traversal for units that spawned outside of a room volume
		// will be disabled during scamper clean up: XComGameState_AIGroup::ClearScamperData()
		AffectedUnit.bCanTraverseRooms = true;
		// force set the unit's room id, even if they are spawned outside
		AffectedUnit.AssignedToRoomID = BattleData.BreachingRoomID;
	}

	// if there was an ATT, remove it now
	if( TroopTransportRef.ObjectID > 0 )
	{
		NewGameState.RemoveStateObject(TroopTransportRef.ObjectID);
	}

	// remove entry point UI indicators
	for (i = 0; i < ReinforcementEntryPointsIndicatorIds.Length; ++i)
	{
		NewGameState.RemoveStateObject(ReinforcementEntryPointsIndicatorIds[i]);
	}

	// remove this state object, now that we are done with it
	NewGameState.RemoveStateObject(ObjectID);

	NewGameState.GetContext().SetAssociatedPlayTiming(SPT_AfterSequential);

	AlertAndScamperUnits(NewGameState, AffectedUnits, bForceScamper, GameState.HistoryIndex, SpawnVisualizationType);

	// reset spawn points
	WorldData.CollectReinforcementSpawnPoints(SpawnPointTiles, -1, SpawnPointMarkers);
	for (i = 0; i < SpawnPointMarkers.length; i++)
	{
		SpawnPoint = SpawnPointMarkers[i];
		SpawnPoint.bOccupied = false;
	}

	return ELR_NoInterrupt;
}

// This is called if Kismet cancels the spawn
function EventListenerReturn OnSpawnReinforcementsCanceled(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;
	local int i;
	local array<TTile> SpawnPointTiles;
	local array<XComReinforcementSpawnPointMarker> SpawnPointMarkers;
	local XComReinforcementSpawnPointMarker SpawnPoint;
	local XComWorldData WorldData;
	local XComGameState_Effect EffectStateObject;
	local X2Effect_PendingReinforcements kEffect;
	local XComGameStateHistory History;

	if( bReinforcementsCanceled )
	{
		return ELR_NoInterrupt;
	}

	WorldData = `XWORLD;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("OnSpawnReinforcementsCanceled");
	
	//mark this as canceled
	bReinforcementsCanceled = true;

	//remove the pending reinforcements effect
	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_Effect', EffectStateObject)
	{
		kEffect = X2Effect_PendingReinforcements( EffectStateObject.GetX2Effect() );
		if( kEffect != None && EffectStateObject.ApplyEffectParameters.AbilityInputContext.ItemObject.ObjectID == ObjectID )
		{
			EffectStateObject.RemoveEffect(NewGameState, NewGameState);
		}
	}

	// if there was an ATT, remove it now
	if( TroopTransportRef.ObjectID > 0 )
	{
		NewGameState.RemoveStateObject(TroopTransportRef.ObjectID);
	}

	// remove entry point UI indicators
	for (i = 0; i < ReinforcementEntryPointsIndicatorIds.Length; ++i)
	{
		NewGameState.RemoveStateObject(ReinforcementEntryPointsIndicatorIds[i]);
	}

	// remove this state object, now that we are done with it
	NewGameState.RemoveStateObject(ObjectID);

	NewGameState.GetContext().SetAssociatedPlayTiming(SPT_AfterSequential);

	// reset spawn points
	WorldData.CollectReinforcementSpawnPoints(SpawnPointTiles, -1, SpawnPointMarkers);
	for (i = 0; i < SpawnPointMarkers.length; i++)
	{
		SpawnPoint = SpawnPointMarkers[i];
		SpawnPoint.bOccupied = false;
	}

	`TACTICALRULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}

static function AlertAndScamperUnits(XComGameState NewGameState, out array<XComGameState_Unit> AffectedUnits, bool bMustScamper, int HistoryIndex, optional name InSpawnVisualizationType)
{
	local XComWorldData World;
	local XComGameState_Unit ReinforcementUnit, InstigatingUnit;
	local XComGameState_AIUnitData NewAIUnitData;
	local int i;
	local AlertAbilityInfo AlertInfo;
	local XComGameStateHistory History;
	local XComAISpawnManager SpawnManager;
	local Vector PingLocation;
	local array<StateObjectReference> VisibleUnits;
	local XComGameState_AIGroup AIGroupState;
	local bool bDataChanged;
	local XGAIGroup Group;

	World = `XWORLD;
		History = `XCOMHISTORY;
		SpawnManager = `SPAWNMGR;

	PingLocation = SpawnManager.GetCurrentXComLocation();
	AlertInfo.AlertTileLocation = World.GetTileCoordinatesFromPosition(PingLocation);
	AlertInfo.AlertRadius = 500;
	AlertInfo.AlertUnitSourceID = 0;
	AlertInfo.AnalyzingHistoryIndex = HistoryIndex;

	// update the alert pings on all the spawned units
	for( i = 0; i < AffectedUnits.Length; ++i )
	{
		bDataChanged = false;
		ReinforcementUnit = AffectedUnits[i];

		if( !bMustScamper )
		{
			class'X2TacticalVisibilityHelpers'.static.GetAllVisibleEnemyUnitsForUnit(ReinforcementUnit.ObjectID, VisibleUnits, class'X2TacticalVisibilityHelpers'.default.GameplayVisibleFilter);
		}

		if( ReinforcementUnit.GetAIUnitDataID() < 0 )
		{
			NewAIUnitData = XComGameState_AIUnitData(NewGameState.CreateNewStateObject(class'XComGameState_AIUnitData'));
		}
		else
		{
			NewAIUnitData = XComGameState_AIUnitData(NewGameState.ModifyStateObject(class'XComGameState_AIUnitData', ReinforcementUnit.GetAIUnitDataID()));
		}

		if( NewAIUnitData.m_iUnitObjectID != ReinforcementUnit.ObjectID )
		{
			NewAIUnitData.Init(ReinforcementUnit.ObjectID);
			bDataChanged = true;
		}
		if( NewAIUnitData.AddAlertData(ReinforcementUnit.ObjectID, eAC_SeesSpottedUnit, AlertInfo, NewGameState) )
		{
			bDataChanged = true;
		}

		if( !bDataChanged )
		{
			NewGameState.PurgeGameStateForObjectID(NewAIUnitData.ObjectID);
		}
	}

	`TACTICALRULES.SubmitGameState(NewGameState);

	if( bMustScamper /*&& VisibleUnits.Length == 0*/ )
	{
		for (i = 0; i < AffectedUnits.Length; ++i)
		{
			ReinforcementUnit = XComGameState_Unit(History.GetGameStateForObjectID(AffectedUnits[i].ObjectID));
			AIGroupState = ReinforcementUnit.GetGroupMembership();
			AIGroupState.InitiateReflexMoveActivate(ReinforcementUnit, eAC_MapwideAlert_Hostile, InSpawnVisualizationType, string(ReinforcementUnit.GetMyTemplate().strReinforcementScamperBT));
		}
	}
	else if( VisibleUnits.Length > 0 )
	{
		InstigatingUnit = XComGameState_Unit(History.GetGameStateForObjectID(VisibleUnits[0].ObjectID));
		AIGroupState = ReinforcementUnit.GetGroupMembership();
		AIGroupState.InitiateReflexMoveActivate(InstigatingUnit, eAC_SeesSpottedUnit, InSpawnVisualizationType);
	}
	else
	{
		// If this group isn't starting out scampering, we need to initialize the group turn so it can move properly.
		XGAIPlayer(`BATTLE.GetAIPlayer()).m_kNav.GetGroupInfo(AffectedUnits[0].ObjectID, Group);
		Group.InitTurn();
	}
}

function BuildVisualizationForUnitSpawning(XComGameState VisualizeGameState)
{
	local XComGameState_AIReinforcementSpawner AISpawnerState;
	local XComGameState_Unit SpawnedUnit;
	local TTile SpawnedUnitTile;
	local int i;
	local VisualizationActionMetadata ActionMetadata, EmptyBuildTrack;
	local X2Action_PlayAnimation SpawnEffectAnimation;
	local X2Action_PlayEffect SpawnEffectAction;
	local XComWorldData World;
	local XComContentManager ContentManager;
	local XComGameStateHistory History;
	local X2Action_ShowSpawnedUnit ShowSpawnedUnitAction;
	local X2Action_ATT ATTAction;
	local float ShowSpawnedUnitActionTimeout;
	local X2Action_Delay RandomDelay;
	local X2Action_MarkerNamed SyncAction;
	local XComGameStateContext Context;
	local float OffsetVisDuration;
	local X2Action_CameraLookAt LookAtAction;
	local XComGameStateVisualizationMgr VisualizationMgr;
	local array<X2Action>					LeafNodes;

	OffsetVisDuration = 0.0;
	VisualizationMgr = `XCOMVISUALIZATIONMGR;
	History = `XCOMHISTORY;
	ContentManager = `CONTENT;
	World = `XWORLD;
	AISpawnerState = XComGameState_AIReinforcementSpawner(VisualizeGameState.GetGameStateForObjectID(ObjectID));

	Context = VisualizeGameState.GetContext();
	ActionMetadata.StateObject_OldState = AISpawnerState;
	ActionMetadata.StateObject_NewState = AISpawnerState;

	if( AISpawnerState.SpawnVisualizationType != 'TheLostSwarm' )
	{
		LookAtAction = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		LookAtAction.LookAtLocation = AISpawnerState.SpawnInfo.SpawnLocation;
		LookAtAction.BlockUntilActorOnScreen = true;
		LookAtAction.LookAtDuration = -1.0;
		LookAtAction.CameraTag = 'ReinforcementSpawningCamera';
	}

	ShowSpawnedUnitActionTimeout = 10.0f;
	if (AISpawnerState.SpawnVisualizationType == 'ATT' )
	{
		ATTAction = X2Action_ATT(class'X2Action_ATT'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		ShowSpawnedUnitActionTimeout = ATTAction.TimeoutSeconds;
	}

	if( AISpawnerState.SpawnVisualizationType == 'Dropdown' )
	{
		SpawnEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		SpawnEffectAction.EffectName = ContentManager.ReinforcementDropdownWarningEffectPathName;
		SpawnEffectAction.EffectLocation = AISpawnerState.SpawnInfo.SpawnLocation;
		SpawnEffectAction.bStopEffect = true;
	}

	SyncAction = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
	SyncAction.SetName("SpawningStart");

	for( i = AISpawnerState.SpawnedUnitIDs.Length - 1; i >= 0; --i )
	{
		SpawnedUnit = XComGameState_Unit(VisualizeGameState.GetGameStateForObjectID(AISpawnerState.SpawnedUnitIDs[i]));

		if( SpawnedUnit.GetVisualizer() == none )
		{
			SpawnedUnit.FindOrCreateVisualizer();
			SpawnedUnit.SyncVisualizer();

			//Make sure they're hidden until ShowSpawnedUnit makes them visible (SyncVisualizer unhides them)
			XGUnit(SpawnedUnit.GetVisualizer()).m_bForceHidden = true;
		}

		if( AISpawnerState.SpawnVisualizationType != 'TheLostSwarm' )
		{
			ActionMetadata = EmptyBuildTrack;
			ActionMetadata.StateObject_OldState = SpawnedUnit;
			ActionMetadata.StateObject_NewState = SpawnedUnit;
			ActionMetadata.VisualizeActor = History.GetVisualizer(SpawnedUnit.ObjectID);

			// if multiple units are spawning, apply small random delays between each
			if( i > 0 )
			{
				RandomDelay = X2Action_Delay(class'X2Action_Delay'.static.AddToVisualizationTree(ActionMetadata, Context, false, SyncAction));
				OffsetVisDuration += `SYNC_FRAND() * 0.5f;
				RandomDelay.Duration = OffsetVisDuration;
			}

			if( (SpawnVisualizationType != 'Dropdown') /*&& (SpawnVisualizationType != '')*/ )
			{
				ShowSpawnedUnitAction = X2Action_ShowSpawnedUnit(class'X2Action_ShowSpawnedUnit'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
				ShowSpawnedUnitAction.ChangeTimeoutLength(ShowSpawnedUnitActionTimeout + ShowSpawnedUnitAction.TimeoutSeconds);
			}

			// if spawning from PsiGates, need a warp in effect to play at each of the unit spawn locations
			if( SpawnVisualizationType == 'PsiGate' )
			{
				SpawnedUnit.GetKeystoneVisibilityLocation(SpawnedUnitTile);

				SpawnEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
				SpawnEffectAction.EffectName = ContentManager.PsiWarpInEffectPathName;
				SpawnEffectAction.EffectLocation = World.GetPositionFromTileCoordinates(SpawnedUnitTile);
				SpawnEffectAction.bStopEffect = false;

				SpawnEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
				SpawnEffectAction.EffectName = ContentManager.PsiGateEffectPathName;
				SpawnEffectAction.EffectLocation = World.GetPositionFromTileCoordinates(SpawnedUnitTile);
				SpawnEffectAction.bStopEffect = true;
			}

			// if spawning from PsiGates, need a warp in effect to play at each of the unit spawn locations
			if( SpawnVisualizationType == 'Dropdown' )
			{
				SpawnedUnit.GetKeystoneVisibilityLocation(SpawnedUnitTile);

				SpawnEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
				SpawnEffectAction.EffectName = ContentManager.ReinforcementDropdownEffectPathName;
				SpawnEffectAction.EffectLocation = World.GetPositionFromTileCoordinates(SpawnedUnitTile);
				SpawnEffectAction.bStopEffect = false;

				RandomDelay = X2Action_Delay(class'X2Action_Delay'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
				RandomDelay.Duration = 1.0f;

				ShowSpawnedUnitAction = X2Action_ShowSpawnedUnit(class'X2Action_ShowSpawnedUnit'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
				ShowSpawnedUnitAction.ChangeTimeoutLength(ShowSpawnedUnitActionTimeout + ShowSpawnedUnitAction.TimeoutSeconds);

				SpawnEffectAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
				SpawnEffectAnimation.Params.AnimName = 'MV_ClimbDropHigh_StartA';
				SpawnEffectAnimation.Params.BlendTime = 0.0f;
				SpawnEffectAnimation.bFinishAnimationWait = true;
				SpawnEffectAnimation.bOffsetRMA = true;

				SpawnEffectAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, SpawnEffectAnimation));
				SpawnEffectAnimation.Params.AnimName = 'MV_ClimbDropHigh_StopA';
				SpawnEffectAnimation.bFinishAnimationWait = true;
				SpawnEffectAnimation.bOffsetRMA = true;
			}
		}
	}

	//Add a join so that all hit reactions and other actions will complete before the visualization sequence moves on. In the case
	// of fire but no enter cover then we need to make sure to wait for the fire since it isn't a leaf node
	VisualizationMgr.GetAllLeafNodes(VisualizationMgr.BuildVisTree, LeafNodes);

	LookAtAction = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, Context, false, none, LeafNodes));
	LookAtAction.CameraTag = 'ReinforcementSpawningCamera';
	LookAtAction.bRemoveTaggedCamera = true;
}

function BuildVisualizationForSpawnerCreation(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata EmptyTrack;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;
	local XComGameState_AIReinforcementSpawner AISpawnerState;
	local X2Action_PlayEffect ReinforcementSpawnerEffectAction;
	local X2Action_RevealArea RevealAreaAction;
	local XComContentManager ContentManager;
	local XComGameState_Unit UnitIterator;
	local XGUnit TempXGUnit;
	local bool bUnitHasSpokenVeryRecently;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyOver;

	ContentManager = `CONTENT;
	History = `XCOMHISTORY;
	AISpawnerState = XComGameState_AIReinforcementSpawner(History.GetGameStateForObjectID(ObjectID));

	RevealAreaAction = X2Action_RevealArea(class'X2Action_RevealArea'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
	RevealAreaAction.TargetLocation = AISpawnerState.SpawnInfo.SpawnLocation;
	RevealAreaAction.AssociatedObjectID = ObjectID;
	RevealAreaAction.bDestroyViewer = false;

	ReinforcementSpawnerEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));

	if( SpawnVisualizationType == 'PsiGate' )
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.PsiGateEffectPathName;
	}
	else if( SpawnVisualizationType == 'ATT' )
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.ATTFlareEffectPathName;
	}
	else if( SpawnVisualizationType == 'Dropdown' )
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.ReinforcementDropdownWarningEffectPathName;
	}

	ReinforcementSpawnerEffectAction.EffectLocation = AISpawnerState.SpawnInfo.SpawnLocation;
	ReinforcementSpawnerEffectAction.CenterCameraOnEffectDuration = ContentManager.LookAtCamDuration;
	ReinforcementSpawnerEffectAction.bStopEffect = false;

	ActionMetadata.StateObject_OldState = AISpawnerState;
	ActionMetadata.StateObject_NewState = AISpawnerState;
	

	// Add a track to one of the x-com soldiers, to say a line of VO (e.g. "Alien reinforcements inbound!").
	foreach History.IterateByClassType( class'XComGameState_Unit', UnitIterator )
	{
		TempXGUnit = XGUnit(UnitIterator.GetVisualizer());
		bUnitHasSpokenVeryRecently = ( TempXGUnit != none && TempXGUnit.m_fTimeSinceLastUnitSpeak < 3.0f );

		if (UnitIterator.GetTeam() == eTeam_XCom && !bUnitHasSpokenVeryRecently && !AISpawnerState.SpawnInfo.SkipSoldierVO)
		{
			ActionMetadata = EmptyTrack;
			ActionMetadata.StateObject_OldState = UnitIterator;
			ActionMetadata.StateObject_NewState = UnitIterator;
			ActionMetadata.VisualizeActor = UnitIterator.GetVisualizer();

			SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
			SoundAndFlyOver.SetSoundAndFlyOverParameters(none, "", 'AlienReinforcements', eColor_Bad);

			break;
		}
	}

}

function BuildVisualizationForSpawnerDestruction(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;
	local XComGameState_AIReinforcementSpawner AISpawnerState;
	local X2Action_PlayEffect ReinforcementSpawnerEffectAction;
	local X2Action_RevealArea RevealAreaAction;
	local XComContentManager ContentManager;

	ContentManager = `CONTENT;
	History = `XCOMHISTORY;
	AISpawnerState = XComGameState_AIReinforcementSpawner(History.GetGameStateForObjectID(ObjectID));

	RevealAreaAction = X2Action_RevealArea(class'X2Action_RevealArea'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
	RevealAreaAction.AssociatedObjectID = ObjectID;
	RevealAreaAction.bDestroyViewer = true;

	ReinforcementSpawnerEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));

	if( SpawnVisualizationType == 'PsiGate' )
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.PsiGateEffectPathName;
	}
	else if( SpawnVisualizationType == 'ATT' )
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.ATTFlareEffectPathName;
	}
	else if (SpawnVisualizationType == 'Dropdown')
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.ReinforcementDropdownWarningEffectPathName;
	}

	ReinforcementSpawnerEffectAction.EffectLocation = AISpawnerState.SpawnInfo.SpawnLocation;
	ReinforcementSpawnerEffectAction.bStopEffect = true;

	ActionMetadata.StateObject_OldState = AISpawnerState;
	ActionMetadata.StateObject_NewState = AISpawnerState;
	}


static function bool InitiateReinforcements(
	Name EncounterID,
	optional int OverrideCountdown = -1,
	optional bool OverrideTargetLocation,
	optional const out Vector TargetLocationOverride,
	optional int IdealSpawnTilesOffset,
	optional XComGameState IncomingGameState,
	optional bool InKismetInitiatedReinforcements,
	optional Name InSpawnVisualizationType = 'ATT',
	optional bool InDontSpawnInLOSOfXCOM,
	optional bool InMustSpawnInLOSOfXCOM,
	optional bool InDontSpawnInHazards,
	optional bool InForceScamper,
	optional bool bAlwaysOrientAlongLOP,
	optional bool bIgnoreUnitCap,
	optional bool bUseSpawnPoints,
	optional name InSpawnPointsGroupTag,
	optional EReinforcementInboundTimelinePlacementType InboundTimelinePlacement = eTimelinePlacement_Last,
	optional bool InRequestHarderReinforcement = false
	)
{
	local XComGameState_AIReinforcementSpawner NewAIReinforcementSpawnerState;
	local XComGameState NewGameState;
	local XComTacticalMissionManager MissionManager;
	local ConfigurableEncounter Encounter;
	local array<ConfigurableEncounter> OutAllValidEncounter;
	local XComAISpawnManager SpawnManager;
	local Vector DesiredSpawnLocation;
	local X2TacticalGameRuleset TacRuleset;
	local XComReinforcementSpawnPointMarker SpawnPoint;
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_EncounterData EncounterData;
	local bool bRequestHarderReinforcement;
	local MissionSchedule OutMissionScheduleDef;
	local int EncounterIndex;

	// HELIOS Variables #57
	local XComLWTuple Tuple;

	if( !bIgnoreUnitCap && LivingUnitCapReached(InSpawnVisualizationType == 'TheLostSwarm') )
	{
		return false;
	}

	SpawnManager = `SPAWNMGR;
	TacRuleset = `TACTICALRULES;
	MissionManager = `TACTICALMISSIONMGR;
	History = `XCOMHISTORY;

	if (bUseSpawnPoints)
	{
		SpawnPoint = FindSpawnerByName(InSpawnPointsGroupTag);

		if (SpawnPoint == none)
		{
			`RedScreen("[XComGameState_AIReinforcementSpawner::InitiateReinforcements]: could not find a reinforcement spawn group with tag" @ InSpawnPointsGroupTag);
			return false;
		}
	}

	if (IncomingGameState == none)
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating Reinforcement Spawner");
	else
		NewGameState = IncomingGameState;

	EncounterData = XComGameState_EncounterData(History.GetSingleGameStateObjectForClass(class'XComGameState_EncounterData'));

	// Update AIPlayerData with CallReinforcements data.
	NewAIReinforcementSpawnerState = XComGameState_AIReinforcementSpawner(NewGameState.CreateNewStateObject(class'XComGameState_AIReinforcementSpawner'));

	NewAIReinforcementSpawnerState.SpawnVisualizationType = InSpawnVisualizationType;
	NewAIReinforcementSpawnerState.bDontSpawnInLOSOfXCOM = InDontSpawnInLOSOfXCOM;
	NewAIReinforcementSpawnerState.bMustSpawnInLOSOfXCOM = InMustSpawnInLOSOfXCOM;
	NewAIReinforcementSpawnerState.bDontSpawnInHazards = InDontSpawnInHazards;
	NewAIReinforcementSpawnerState.bForceScamper = InForceScamper;

	bRequestHarderReinforcement = InRequestHarderReinforcement;

	if (InKismetInitiatedReinforcements)
	{
		MissionManager.GetActiveMissionSchedule(OutMissionScheduleDef);
		bRequestHarderReinforcement = bRequestHarderReinforcement || EncounterData.KismetReinforcementRequestCount >= OutMissionScheduleDef.EscalateReinforcementThreshold;
	}

	if (EncounterID == '')
	{
		// if not specified, use pre-configured or procedurally built encounter
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		EncounterID = SpawnManager.GetReinforcementEncounterListForRoom(BattleData.BreachingRoomID, /*out*/NewAIReinforcementSpawnerState.SpawnInfo.SelectedCharacterTemplateNames, bRequestHarderReinforcement);
	}
	else
	{
		MissionManager.GetConfigurableEncounter(EncounterID, Encounter,,,`DIOHQ,OutAllValidEncounter);
		if (Encounter.EncounterID == '')
		{
			`RedScreen("[XComGameState_AIReinforcementSpawner::InitiateReinforcements]: could not find an encounter with name [" @ EncounterID @ "]");
			return false;
		}
		else if (InKismetInitiatedReinforcements && OutAllValidEncounter.length > 0 )
		{
			EncounterIndex = EncounterData.KismetReinforcementRequestCount % OutAllValidEncounter.length;
			NewAIReinforcementSpawnerState.SpawnInfo.SelectedCharacterTemplateNames = OutAllValidEncounter[EncounterIndex].ForceSpawnTemplateNames;
			EncounterID = OutAllValidEncounter[EncounterIndex].EncounterID;
		}
		else
		{
			NewAIReinforcementSpawnerState.SpawnInfo.SelectedCharacterTemplateNames = Encounter.ForceSpawnTemplateNames;
		}
	}
	NewAIReinforcementSpawnerState.SpawnInfo.EncounterID = EncounterID;

	if( OverrideCountdown >= 0 )
	{
		NewAIReinforcementSpawnerState.Countdown = OverrideCountdown;
	}
	else
	{
		NewAIReinforcementSpawnerState.Countdown = Encounter.ReinforcementCountdown;
	}

	// if tactical hasn't started (still in breach mode) inflate the countdown by 1
	if (TacRuleset.LastBreachStartHistoryIndex > TacRuleset.LastRoundStartHistoryIndex)
	{
		NewAIReinforcementSpawnerState.Countdown++;
	}

	if( OverrideTargetLocation )
	{
		DesiredSpawnLocation = TargetLocationOverride;
	}
	else
	{
		DesiredSpawnLocation = SpawnManager.GetCurrentXComLocation();
	}

	if (bUseSpawnPoints)
	{
		NewAIReinforcementSpawnerState.SpawnPointGroupTag = InSpawnPointsGroupTag;
		NewAIReinforcementSpawnerState.SpawnInfo.SpawnLocation = SpawnPoint.Location;
	}
	else
	{
		NewAIReinforcementSpawnerState.SpawnInfo.SpawnLocation = SpawnManager.SelectReinforcementsLocation(
			NewAIReinforcementSpawnerState,
			DesiredSpawnLocation,
			IdealSpawnTilesOffset,
			InMustSpawnInLOSOfXCOM,
			InDontSpawnInLOSOfXCOM,
			InSpawnVisualizationType == 'ATT',
			bAlwaysOrientAlongLOP); // ATT vis type requires vertical clearance at the spawn location
	}

	NewAIReinforcementSpawnerState.bKismetInitiatedReinforcements = InKismetInitiatedReinforcements;
	NewAIReinforcementSpawnerState.InboundTimelinePlacementType = InboundTimelinePlacement;

	if (InKismetInitiatedReinforcements)
	{
		EncounterData = XComGameState_EncounterData(NewGameState.ModifyStateObject(class'XComGameState_EncounterData', EncounterData.ObjectID));
		EncounterData.KismetReinforcementRequestCount++;
	}

	// BEGIN HELIOS Issue #57
	// Allow mods to change information about the newly created reinforcement gamestate before submission (if no prior gamestate exists or Kismet-bound), including spawning information.
	// Event Listeners should be set to ELD_Immediate to not cause problems down the line with submitting duplicate Gamestates.
	
	// Generate a tuple to store variables pertaining to the reinforcement gamestate
	Tuple = new class'XComLWTuple';
    Tuple.Id = 'HELIOS_Tuple_RNFInfo';
    Tuple.Data.Add(1);
    Tuple.Data[0].kind  = XComLWTVName;
    Tuple.Data[0].n     = EncounterID;

	`XEVENTMGR.TriggerEvent('HELIOS_TACTICAL_ReinforcementStateCreated_Submitted', Tuple, NewAIReinforcementSpawnerState, (IncomingGameState != none) ? IncomingGameState : NewGameState);
	// END HELIOS Issue #57

	if (IncomingGameState == none)
		TacRuleset.SubmitGameState(NewGameState);

	return true;
}

// When called, the visualized object must create it's visualizer if needed, 
function Actor FindOrCreateVisualizer( optional XComGameState Gamestate = none )
{
	return none;
}

// Ensure that the visualizer visual state is an accurate reflection of the state of this object.
function SyncVisualizer( optional XComGameState GameState = none )
{
}

function AppendAdditionalSyncActions( out VisualizationActionMetadata ActionMetadata, const XComGameStateContext Context)
{
	local XComContentManager ContentManager;
	local X2Action_PlayEffect ReinforcementSpawnerEffectAction;
	local X2Action_RevealArea RevealAreaAction;

	if (Countdown <= 0)
	{
		return; // we've completed the reinforcement and the effect was stopped
	}

	RevealAreaAction = X2Action_RevealArea(class'X2Action_RevealArea'.static.AddToVisualizationTree(ActionMetadata, GetParentGameState().GetContext() ) );
	RevealAreaAction.TargetLocation = SpawnInfo.SpawnLocation;
	RevealAreaAction.AssociatedObjectID = ObjectID;
	RevealAreaAction.bDestroyViewer = false;

	ContentManager = `CONTENT;

	ReinforcementSpawnerEffectAction = X2Action_PlayEffect( class'X2Action_PlayEffect'.static.AddToVisualizationTree( ActionMetadata, GetParentGameState().GetContext() ) );

	if( SpawnVisualizationType == 'PsiGate' )
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.PsiGateEffectPathName;
	}
	else if( SpawnVisualizationType == 'ATT' )
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.ATTFlareEffectPathName;
	}
	else if (SpawnVisualizationType == 'Dropdown')
	{
		ReinforcementSpawnerEffectAction.EffectName = ContentManager.ReinforcementDropdownWarningEffectPathName;
	}

	ReinforcementSpawnerEffectAction.EffectLocation = SpawnInfo.SpawnLocation;
	ReinforcementSpawnerEffectAction.CenterCameraOnEffectDuration = 0;
	ReinforcementSpawnerEffectAction.bStopEffect = false;
}

static function bool LivingUnitCapReached(bool bOnlyConsiderTheLost)
{
	local XComGameStateHistory History;
	local XComGameState_Unit kUnitState;
	local int LivingUnitCount;

	LivingUnitCount = 0;

	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_Unit', kUnitState)
	{
		if( kUnitState.IsAlive() && !kUnitState.bRemovedFromPlay )
		{
			if( !bOnlyConsiderTheLost || kUnitState.GetTeam() == eTeam_TheLost )
			{
				++LivingUnitCount;
			}
		}
	}

	if( bOnlyConsiderTheLost )
	{
		return LivingUnitCount >= class'XComAISpawnManager'.default.LostUnitCap;  // max lost units permitted to be alive at one time; can only spawn additional lost if below this number
	}

	return LivingUnitCount >= class'XComAISpawnManager'.default.UnitCap;
}

native static function GetAvailableSpawners(out array<XComReinforcementSpawnPointMarker> SpawnPointMarkers, int RoomID = -1);
native static function XComReinforcementSpawnPointMarker FindSpawnerByName(const out name GroupTagName);
native function LimitReinforcementSpawnCount(out PodSpawnInfo OutSpawnInfo);


cpptext
{
	// UObject interface
	virtual void Serialize(FArchive& Ar);
}

defaultproperties
{
	bTacticalTransient=true
	SpawnReinforcementsChangeDesc="SpawnReinforcements"
	SpawnReinforcementsCompleteChangeDesc="OnSpawnReinforcementsComplete"
	Countdown = -1
	SpawnVisualizationType="ATT"
}

