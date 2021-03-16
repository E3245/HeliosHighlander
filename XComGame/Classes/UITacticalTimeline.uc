//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UITacticalTimeline.uc
//
//--------------------------------------------------------------------------------------- 

class UITacticalTimeline extends UIScreen dependson(X2GameRuleset);

enum ETimeLineEntryType
{
	eTimeLineEntryType_Group,
	eTimeLineEntryType_Tickable,
	eTimeLineEntryType_MoveEffect,
	eTimeLineEntryType_GenericMarker
};
struct gfxMarkerEntry
{
	var int	ObjectID;
	var int TimelineInstanceID;
	var bool bIsUnit;
};
struct GroupTimelineEntry
{
	var ETimeLineEntryType Type;
	var XComGameState_AIGroup SourceGroupState;
	var XComGameState_AIGroup TickGroupState;
	var int	EffectObjectID;
	var bool bIsClaymore;
	var XComDestructibleActor DestructibleActor;
	var int NumberOfRelativePlacesToMove;
	var int iTurnsRemaining;
	var int iTurnsTicked;
	var bool PastRoundEnd;
	var bool bTicksBeforeGroup;
	var string SpawnedDestructibleLocName;
};

var GFxObject                   RootMC;
var int	                        LastSelectedObjectID;
var XGUnit                      highlightedEnemy;
var UITacticalTimeline_Tooltips Tooltips; 
var AvailableAction				LastAvailableActionPreview;
var int							LastPreviewTargetIndex;
var bool						IsPreviewDisplayed;
var bool						bPendingReinforcements;
var int							NumScampering;
var array<GroupTimelineEntry>	LastTimelinePreviewEntries;
var array<Actor>				PreviewDamageActors;
var string						CurrentUnitPath;

var array<gfxMarkerEntry>		LastNonPreviewMarkerEntries;
var array<gfxMarkerEntry>		LastSubmittedMarkerEntries;
var int							LastMissionTurnCounter;

var int							NumActiveUnits;

var localized string m_strTimelineHeader;
var localized string m_strOneMoreUnit;
var localized string m_strNumMoreUnits;
var localized string m_strEnemy;
var localized string m_strEnemyReinforcement;
var localized string m_strReinforcementsHeader;
var localized string m_strReinforcementsBody;
var localized string m_strReinforcementsImminentHeader;
var localized string m_strReinforcementsImminentBody;
var localized string m_strEndTurnLabel;
var localized string m_strAvailableUnits;
var localized string m_strDefaultGrenade;

simulated function OnInit()
{
	super.OnInit();
	RootMC = Movie.GetVariableObject(MCPath $ "");
	RegisterForEvents();

	CurrentUnitPath = string(UITacticalTimeline(Movie.Stack.GetScreen(class'UITacticalTimeline')).MCPath) $".unitCurrent";

	//Tooltip Container
	Tooltips = new class'UITacticalTimeline_Tooltips';
	Tooltips.InitTooltips(Movie.Pres.m_kTooltipMgr);
	IsPreviewDisplayed = false;
	LastPreviewTargetIndex = -1;

	MC.FunctionString("setHeaderString", m_strTimelineHeader);
	MC.FunctionString("setEnemyReinforcementLabel", m_strEnemyReinforcement);
	MC.FunctionString("setAvailableUnitsLabel", m_strAvailableUnits);

	MC.FunctionString("setOneMoreUnitTemplate", m_strOneMoreUnit);
	MC.FunctionString("setNumMoreUnitsTemplate", m_strNumMoreUnits);

	RefreshHealth();
}

function RefreshHealth()
{
	MC.FunctionBool("showEnemyHealth", `XPROFILESETTINGS.Data.m_bShowEnemyHealth); // Profile is set to hide enemy health 
}

function RegisterForEvents()
{
	local Object SelfObject;

	SelfObject = self;
	`XEVENTMGR.RegisterForEvent(SelfObject, 'ActiveUnitChanged', OnActiveUnitChanged, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(SelfObject, 'AbilityActivated', OnAbilityActivated, ELD_OnVisualizationBlockStarted);

	`XEVENTMGR.RegisterForEvent(SelfObject, 'UnitDied',			OnUpdateInitiativeOrder, ELD_OnVisualizationBlockCompleted, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'UnitBleedingOut',	OnUpdateInitiativeOrder, ELD_OnVisualizationBlockCompleted, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'UnitUnconscious',	OnUpdateInitiativeOrder, ELD_OnVisualizationBlockCompleted, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'UnitCaptured',		OnUpdateInitiativeOrder, ELD_OnVisualizationBlockCompleted, , );

	`XEVENTMGR.RegisterForEvent(SelfObject, 'ScamperBegin', OnScamperBeginEvent, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(SelfObject, 'ScamperEnd', OnScamperEndEvent, ELD_OnVisualizationBlockCompleted);
	`XEVENTMGR.RegisterForEvent(SelfObject, 'UnitGroupTurnEnded', OnGroupTurnEnded, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(SelfObject, class'X2Effect_PendingReinforcements'.default.EventRemovedTriggerName, OnPendingReinforcements, ELD_OnStateSubmitted);

	`XEVENTMGR.RegisterForEvent(SelfObject, 'BreachCachedPointInfoUpdated', OnBreachPointUpdated, ELD_OnVisualizationBlockCompleted);

	WorldInfo.MyWatchVariableMgr.RegisterWatchVariable(`TACTICALRULES, 'CachedUnitActionInitiativeRef', self, WatchUpdateInitiativeOrder);
}

event Destroyed()
{
	local Object SelfObject;

	SelfObject = self;
	`XEVENTMGR.UnRegisterFromEvent(SelfObject,'ActiveUnitChanged');

	super.Destroyed();
}

function EventListenerReturn OnActiveUnitChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local array<XComGameState_Unit> EligibleUnits;
	local bool bActionsAvailable;
	local int i, NumGroupMembers, MemberIndex;
	local XComTacticalGRI TacticalGRI;
	local XGBattle_SP Battle;
	local XGPlayer HumanPlayer;
	local GFxObject Units, gfxUnitTemp;
	local XComGameState_Unit UnitState, EligibleUnitState;
	
	UnitState = XComGameState_Unit(EventData);
	LastSelectedObjectID = UnitState.ObjectID;
	Units = Movie.CreateArray();

	TacticalGRI = `TACTICALGRI;
	Battle = (TacticalGRI != none) ? XGBattle_SP(TacticalGRI.m_kBattle) : none;
	HumanPlayer = (Battle != none) ? Battle.GetHumanPlayer() : none;
	if (HumanPlayer != none)
	{
		HumanPlayer.GetUnits(EligibleUnits, , true);
		
		if (EligibleUnits.Length > 0)
		{
			NumGroupMembers = EligibleUnits.Length;
			for (MemberIndex = NumGroupMembers - 1; MemberIndex >= 0; --MemberIndex)
			{
				EligibleUnitState = EligibleUnits[MemberIndex];
				bActionsAvailable = `TACTICALRULES.UnitHasActionsAvailable(EligibleUnits[MemberIndex]);

				if (!bActionsAvailable && EligibleUnitState.ObjectID != LastSelectedObjectID)
				{
					EligibleUnits.Remove(MemberIndex, 1);
				}
				else if (EligibleUnitState.GetMyTemplate().bIsVIP)
				{
					EligibleUnits.Remove(MemberIndex, 1);
				}
			}
		}
				
		for(i = 0; i < EligibleUnits.Length; ++i)
		{
			gfxUnitTemp = `XCOMHISTORY.GetUIVisualizer(EligibleUnits[i].ObjectID, Movie, LastSelectedObjectID);
			gfxUnitTemp.SetBool("isSelected", EligibleUnits[i].ObjectID == LastSelectedObjectID);
			gfxUnitTemp.SetBool("isPlayer", EligibleUnits[i].GetTeam() == eTeam_XCom);

			Units.SetElementObject(i, gfxUnitTemp);
		}
	}
	else
	{		
		Units.SetElementObject(0, `XCOMHISTORY.GetUIVisualizer(UnitState.ObjectID, Movie, LastSelectedObjectID));
	}

	UpdateCurrentUnitData(Units);
	
	NumActiveUnits = EligibleUnits.Length;
	`PRES.m_kTacticalHUD.UpdateNavHelp();
	
	return ELR_NoInterrupt;
}

function EventListenerReturn OnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit UnitState;
	local GFxObject Units, gfxUnit;

	if (!`BATTLE.GetDesc().bInBreachPhase)
	{
		Units = Movie.CreateArray();

		UnitState = XComGameState_Unit(EventSource);
		
		if (!UnitState.GetMyTemplate().bIsCosmetic && !UnitState.bRemovedFromPlay) // don't try to show gremlins or rescued civilians
		{
			gfxUnit = `XCOMHISTORY.GetUIVisualizer(UnitState.ObjectID, Movie, );
			gfxUnit.SetBool("isPlayer", UnitState.GetTeam() == eTeam_XCom);

			Units.SetElementObject(0, gfxUnit);
			UpdateCurrentUnitData(Units);

			NumActiveUnits = 1;
			`PRES.m_kTacticalHUD.UpdateNavHelp();
		}
	}
	
	return ELR_NoInterrupt;
}

function EventListenerReturn OnScamperBeginEvent(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	if( bPendingReinforcements )
	{
		NumScampering += 1;
	}

	return ELR_NoInterrupt;
}
function EventListenerReturn OnScamperEndEvent( Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData )
{
	if( bPendingReinforcements )
	{
		if( NumScampering > 0 )
		{
			NumScampering -= 1;
			if( NumScampering == 0 )
			{
				UpdateInitiativeOrder();
			}
		}
	}
	else
	{
		NumScampering = 0;
	}
	return ELR_NoInterrupt;
}

function EventListenerReturn OnPendingReinforcements(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	bPendingReinforcements = true;
	return ELR_NoInterrupt;
}

function EventListenerReturn OnGroupTurnEnded(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	bPendingReinforcements = false;
	NumScampering = 0;
	return ELR_NoInterrupt;
}


function GatherBreachTimelineEntries( out array<GroupTimelineEntry> TimelineEntries )
{
	local int Index;
	local XComGameState_AIGroup GroupState;
	local array<GroupTimelineEntry> TickableEntries;
	local array<XComGameState_AIGroup> SortedGroupList;

	`TACTICALRULES.GetXComBreachGroupOrderList( SortedGroupList );
	TickableEntries.Length = 0;

	for( Index = 0; Index < SortedGroupList.Length; ++Index )
	{
		GroupState = SortedGroupList[Index];
		if( GroupState != None )
		{
			AddTimelineEntriesForTickGroup( GroupState, false, TickableEntries, TimelineEntries );
		}
	}
}

simulated function UpdateBreachInitiativeOrder(optional bool bForceUpdate = false)
{
	local GFxObject gfxTimelineData, gfxInitiativeTurns, gfxRemovedIndices;
	local array<GroupTimelineEntry> TimelineEntries;
	local array<gfxMarkerEntry> MarkerEntries;
	
	if( !`BATTLE.GetDesc().bInBreachPhase )
	{
		return;
	}

	IsPreviewDisplayed = false;
	PreviewDamageActors.Length = 0;

	LastSelectedObjectID = -1;

	GatherBreachTimelineEntries( TimelineEntries );
	gfxInitiativeTurns = Movie.CreateArray();
	AddEntriesToGFXList( TimelineEntries, gfxInitiativeTurns, MarkerEntries );

	if( !bForceUpdate && HasTimelineChanged(MarkerEntries) == false )
	{
		return;
	}

	gfxRemovedIndices = Movie.CreateArray();
	AddIndicesToGFXRemoved( MarkerEntries, gfxRemovedIndices );

	gfxTimelineData = Movie.CreateObject("Object");
	gfxTimelineData.SetObject("turns", gfxInitiativeTurns);
	gfxTimelineData.SetObject("removed", gfxRemovedIndices);

	gfxTimelineData.SetBool("inBreachPhase", `BATTLE.GetDesc().bInBreachPhase);

	updateInitiativeTurns(gfxTimelineData);
	LastSubmittedMarkerEntries = MarkerEntries;
	LastNonPreviewMarkerEntries = MarkerEntries;
}

function EventListenerReturn OnBreachPointUpdated( Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData )
{
	UpdateBreachInitiativeOrder();
	return ELR_NoInterrupt;
}

function ShowTimeline(bool showTimeline)
{
	if (showTimeline)
	{
		Show();
	}
	else
	{
		Hide();
	}
}

function EventListenerReturn OnUpdateInitiativeOrder(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateInitiativeOrder();

	return ELR_NoInterrupt;
}
function WatchUpdateInitiativeOrder()
{
	UpdateInitiativeOrder();
}
simulated function UpdateInitiativeOrder(optional bool bForceUpdate = false)
{
	local GFxObject gfxTimelineData, gfxInitiativeTurns, gfxRemovedIndices, Units, gfxUnit;
	local array<GroupTimelineEntry> TimelineEntries;
	local array<gfxMarkerEntry> MarkerEntries;
	local XComGameState_Unit UnitState;
	
	if(!class'X2TacticalGameRuleset'.default.bInterleaveInitiativeTurns || `BATTLE.GetDesc().bInBreachPhase )
	{
		return;
	}

	IsPreviewDisplayed = false;
	PreviewDamageActors.Length = 0;

	LastSelectedObjectID = -1;
	
	GatherTimelineEntries( TimelineEntries );
	gfxInitiativeTurns = Movie.CreateArray();
	AddEntriesToGFXList( TimelineEntries, gfxInitiativeTurns, MarkerEntries );

	if( !bForceUpdate && HasTimelineChanged(MarkerEntries) == false )
	{
		return;
	}

	if (LastSelectedObjectID != -1)
	{
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(LastSelectedObjectID));

		Units = Movie.CreateArray();

		gfxUnit = `XCOMHISTORY.GetUIVisualizer(UnitState.ObjectID, Movie, LastSelectedObjectID);
		gfxUnit.SetBool("isPlayer", UnitState.GetTeam() == eTeam_XCom);
		Units.SetElementObject(0, gfxUnit);

		UpdateCurrentUnitData(Units);

		NumActiveUnits = 1;
		`PRES.m_kTacticalHUD.UpdateNavHelp();
	}

	gfxRemovedIndices = Movie.CreateArray();
	AddIndicesToGFXRemoved( MarkerEntries, gfxRemovedIndices );

	gfxTimelineData = Movie.CreateObject("Object");
	gfxTimelineData.SetObject("turns", gfxInitiativeTurns);
	gfxTimelineData.SetObject("removed", gfxRemovedIndices);

	gfxTimelineData.SetBool("inBreachPhase", `BATTLE.GetDesc().bInBreachPhase);

	updateInitiativeTurns(gfxTimelineData);
	LastSubmittedMarkerEntries = MarkerEntries;
	LastNonPreviewMarkerEntries = MarkerEntries;
	LastMissionTurnCounter = GetMissionTurnCounter();
}

function bool HasTimelineChanged(const array<gfxMarkerEntry> MarkerEntries )
{
	local int Index, FoundIndex;

	if( MarkerEntries.Length != LastSubmittedMarkerEntries.Length )
	{
		return true;
	}
	for( Index = 0; Index < LastSubmittedMarkerEntries.Length; ++Index )
	{
		FoundIndex = FindTurnMarkerInList( LastSubmittedMarkerEntries[Index], MarkerEntries );
		if( FoundIndex != Index )
		{
			return true;
		}
	}
	if( LastMissionTurnCounter != GetMissionTurnCounter() )
	{
		return true;
	}

	return false;
}
simulated function UpdateInitiativePreviewOrder(AvailableAction AvailableActionInfo, int TargetIndex )
{
	local GFxObject gfxTimelineData, gfxInitiativeTurns, gfxRemovedIndices;
	local array<GroupTimelineEntry> TimelineEntries;
	local array<GroupTimelineEntry> TickableEntries;
	local array<GroupTimelineEntry> MoveEffectEntries;
	local array<gfxMarkerEntry> MarkerEntries;

	if(!class'X2TacticalGameRuleset'.default.bInterleaveInitiativeTurns || `BATTLE.GetDesc().bInBreachPhase )
	{
		return;
	}
	if( LastAvailableActionPreview == AvailableActionInfo && LastPreviewTargetIndex == TargetIndex && IsPreviewDisplayed == true )
	{
		return;
	}
	
	LastAvailableActionPreview = AvailableActionInfo;
	LastPreviewTargetIndex = TargetIndex;
	PreviewDamageActors.Length = 0;
	IsPreviewDisplayed = true;

	//add all the tickables and move changes from the ability
	GetTickablesAndMoveEffectsFromAvailableActionInfo( AvailableActionInfo, TargetIndex, TickableEntries, MoveEffectEntries );

	//get all the tickable and move effect entries
	GatherAllTickAndMoveEffectsForTimeline( TickableEntries, MoveEffectEntries );

	//add them by tick group initiative into the list
	AddTimelineEntriesByInitiativeOrder( TickableEntries, MoveEffectEntries, TimelineEntries );
	//add extra move effect entries
	AddExtraTimelineEntriesForMoveEffects( TimelineEntries );
	AdjustTimelineEntriesForEffectsThatGoFirst( TimelineEntries );

	gfxInitiativeTurns = Movie.CreateArray();

	AddEntriesToGFXList( TimelineEntries, gfxInitiativeTurns, MarkerEntries );

	gfxRemovedIndices = Movie.CreateArray();
	AddIndicesToGFXRemoved( MarkerEntries, gfxRemovedIndices );

	gfxTimelineData = Movie.CreateObject("Object");
	gfxTimelineData.SetObject("turns", gfxInitiativeTurns);
	gfxTimelineData.SetObject("removed", gfxRemovedIndices);

	gfxTimelineData.SetBool("inBreachPhase", `BATTLE.GetDesc().bInBreachPhase);

	updateInitiativeTurns(gfxTimelineData);
	LastSubmittedMarkerEntries = MarkerEntries;

	//save the last preview so that damage targets can be updated from the targeting method
	LastTimelinePreviewEntries = TimelineEntries;
}

function bool HaveDamageActorsChanged( array<Actor> DamageActors )
{
	local int Index;
	if(PreviewDamageActors.Length != DamageActors.Length )
	{
		return true;
	}
	for( Index=0; Index < DamageActors.Length; ++Index)
	{
		if( PreviewDamageActors.Find( DamageActors[Index] ) == INDEX_NONE )
		{
			return true;
		}
	}
	return false;
}

function ClearTimelineTargetsLastPreviewList()
{
	local GroupTimelineEntry TimelineEntry;
	local XComGameState_AIGroup GroupState;
	local array<int> LivingUnitIDs;
	local array<XComGameState_Unit> LivingMemberStates;
	local int LivingMemberID;

	foreach LastTimelinePreviewEntries( TimelineEntry )
	{
		if( TimelineEntry.Type == eTimeLineEntryType_Group || TimelineEntry.Type == eTimeLineEntryType_MoveEffect )
		{
			GroupState = TimelineEntry.SourceGroupState;
			if( GroupState != None )
			{
				LivingUnitIDs.Length = 0;
				LivingMemberStates.Length = 0;

				if( GroupState.GetLivingMembers( LivingUnitIDs, LivingMemberStates ) )
				{
					foreach LivingUnitIDs( LivingMemberID )
					{
						ClearTimelineTarget( LivingMemberID );
					}
				}
			}
		}
	}
}

function HighlightDamageActorUnits( array<Actor> DamageActors )
{
	local int Index;
	local XGUnit Unit;

	if( PreviewDamageActors.Length == 0 )
	{
		ClearTimelineTargetsLastPreviewList();
	}

	for( Index=0; Index < DamageActors.Length; ++Index)
	{
		if( PreviewDamageActors.Find( DamageActors[Index] ) == INDEX_NONE )
		{
			//set the highlight
			Unit = XGUnit( DamageActors[Index] );
			if( Unit != None )
			{
				SetTimelineTarget( Unit.ObjectID );
			}
		}
	}
	for( Index=0; Index < PreviewDamageActors.Length; ++Index)
	{
		if( DamageActors.Find( PreviewDamageActors[Index] ) == INDEX_NONE )
		{
			//clear the highlight
			Unit = XGUnit( PreviewDamageActors[Index] );
			if( Unit != None )
			{
				ClearTimelineTarget( Unit.ObjectID );
			}
		}
	}
}
simulated function UpdateInitiativeOrderTargetingDamagePreview(array<Actor> DamageActors )
{
	local array<Actor> UnitActors;
	local int Index;

	if( LastTimelinePreviewEntries.Length == 0  || !IsPreviewDisplayed || !class'X2TacticalGameRuleset'.default.bInterleaveInitiativeTurns || `BATTLE.GetDesc().bInBreachPhase )
	{
		return;
	}
	for( Index=0; Index < DamageActors.Length; ++Index )
	{
		if( XGUnit( DamageActors[Index] ) != None )
		{
			UnitActors.AddItem( DamageActors[Index] );
		}
	}

	if( HaveDamageActorsChanged(UnitActors) == false )
	{
		return;
	}

	HighlightDamageActorUnits( UnitActors );

	PreviewDamageActors = UnitActors;

}


function GatherTimelineEntries(out array<GroupTimelineEntry> TimelineEntries )
{
	local array<GroupTimelineEntry> TickableEntries;
	local array<GroupTimelineEntry> MoveEffectEntries;

	//add any scampering reinforcmnet markers
	AddScamperingReinforcements( TimelineEntries );

	//get all the tickable and move effect entries
	GatherAllTickAndMoveEffectsForTimeline( TickableEntries, MoveEffectEntries );
	//add them by tick group initiative into the list
	AddTimelineEntriesByInitiativeOrder( TickableEntries, MoveEffectEntries, TimelineEntries );
	//add extra move effect entries
	AddExtraTimelineEntriesForMoveEffects( TimelineEntries );
	AdjustTimelineEntriesForEffectsThatGoFirst( TimelineEntries );
}

function AddEntriesToGFXList(array<GroupTimelineEntry> TimelineEntries, out GFxObject gfxInitiativeTurns, out array<gfxMarkerEntry> MarkerEntries )
{
	local array<GfxObject> GFXTurns;
	local GroupTimelineEntry TimelineEntry;
	local int i, RoundMarkerInsertIndex;

	RoundMarkerInsertIndex = -1;
	if( TimelineEntries.Length > 0 )
	{
		foreach TimelineEntries( TimelineEntry )
		{
			if( RoundMarkerInsertIndex == -1 && TimelineEntry.PastRoundEnd )
			{
				RoundMarkerInsertIndex = (GFXTurns.Length -1);
			}
			AddTimelineEntryToGFX( TimelineEntry, GFXTurns, MarkerEntries);
		}
		if( RoundMarkerInsertIndex < 0  )
		{
			RoundMarkerInsertIndex = (GFXTurns.Length -1);
		}
		if( RoundMarkerInsertIndex >= 0 && !`BATTLE.GetDesc().bInBreachPhase )
		{
			GFXTurns[RoundMarkerInsertIndex].SetBool("endRound", true);
			GFXTurns[RoundMarkerInsertIndex].SetFloat("endRoundCount", GetMissionTurnCounter());
			GFXTurns[RoundMarkerInsertIndex].SetString("turnLabel", m_strEndTurnLabel);
		}
	}

	for (i = 0; i < GFXTurns.Length; i++)
	{
		gfxInitiativeTurns.SetElementObject(i, GFXTurns[i]);
	}
}

function GatherAllTickAndMoveEffectsForTimeline(out array<GroupTimelineEntry> TickableEntries, out array<GroupTimelineEntry> MoveEffectEntries)
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local int InitiativeIndex;
	local XComGameState_AIGroup GroupState;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	for( InitiativeIndex = 0; InitiativeIndex < BattleData.PlayerTurnOrder.Length; ++InitiativeIndex )
	{
		//is this entry a group?
		GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
		if( GroupState != None )
		{
			GetTickablesAndMoveEffectsAttachedToGroup( GroupState, TickableEntries, MoveEffectEntries );
		}
	}
}

function bool AnyPendingScamperGroups()
{
	local XComGameState_AIGroup GroupState;
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local int InitiativeIndex;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	for( InitiativeIndex = 0; InitiativeIndex < BattleData.PlayerTurnOrder.Length; ++InitiativeIndex )
	{
		//is this entry a group
		GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
		if( GroupState != None && GroupState.bPendingScamper )
		{
			return true;
		}
	}
	return false;
}

function AddScamperingReinforcements( out array<GroupTimelineEntry> TimelineEntries )
{
	local XComGameState_AIGroup GroupState;
	local GroupTimelineEntry TimelineEntry;

	if( bPendingReinforcements && ( NumScampering > 0 || AnyPendingScamperGroups() ) )
	{
		GroupState = `TACTICALRULES.GetCurrentInitiativeGroup();
		if( GroupState != None )
		{
			TimelineEntry.Type = eTimeLineEntryType_GenericMarker;
			TimelineEntry.EffectObjectID = 0;
			TimelineEntry.iTurnsRemaining = 1;
			TimelineEntry.iTurnsTicked = 0;
			TimelineEntry.SourceGroupState = GroupState;
			TimelineEntry.TickGroupState = GroupState;
			TimelineEntry.bTicksBeforeGroup = true;
			TimelineEntries.AddItem( TimelineEntry );
		}
	}
}

function AddTimelineEntriesByInitiativeOrder(array<GroupTimelineEntry> TickableEntries, array<GroupTimelineEntry> MoveEffectEntries, out array<GroupTimelineEntry> TimelineEntries)
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local X2TacticalGameRuleset TacticalRuleset;
	local int InitiativeIndex, NumSearched;
	local XComGameState_AIGroup GroupState;
	local bool PastRoundEnd;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	TacticalRuleset = `TACTICALRULES;
	InitiativeIndex = TacticalRuleset.FindInitiativeGroupIndex( TacticalRuleset.GetCurrentInitiativeGroup() );
	if( InitiativeIndex != INDEX_NONE )
	{
		for( NumSearched = 0; NumSearched < BattleData.PlayerTurnOrder.Length; ++NumSearched )
		{
			//wrap index
			if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length )
			{
				InitiativeIndex = 0;
				PastRoundEnd = true;
			}
			//is this entry a group
			GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
			if( GroupState != None )
			{
				AddTimelineEntriesForTickGroup( GroupState, PastRoundEnd, TickableEntries, TimelineEntries );
			}
			InitiativeIndex += 1;
		}
	}

	AddMoveEntriesToTimeline( MoveEffectEntries, TimelineEntries );
}

function AddMoveEntriesToTimeline(array<GroupTimelineEntry> MoveEffectEntries, out array<GroupTimelineEntry> TimelineEntries)
{
	local GroupTimelineEntry TimelineEntry;
	foreach MoveEffectEntries( TimelineEntry )
	{
		if( TimelineEntry.Type == eTimeLineEntryType_MoveEffect )
		{
			AddMoveEntryToTimeline( TimelineEntry, TimelineEntries );
		}
	}
}

function AddMoveEntryToTimeline(GroupTimelineEntry TimelineEntry, out array<GroupTimelineEntry> TimelineEntries)
{
	local int TickGroupIndex;
	local int ForwardMoveIndex;
	local int ForwardTickIndex;
	local int NumGroupsToSkip;
	local GroupTimelineEntry NewMoveEntry;
	local GroupTimelineEntry TempEntry;

	//find the index of the group in the timeline thatof the tick group
	for( TickGroupIndex = 0; TickGroupIndex < TimelineEntries.Length; ++TickGroupIndex )
	{
		if( TimelineEntries[TickGroupIndex].Type == eTimeLineEntryType_Group && 
			TimelineEntries[TickGroupIndex].TickGroupState == TimelineEntry.TickGroupState )
		{
			//found the index - now insert and move all the tickables
			NumGroupsToSkip = TimelineEntry.NumberOfRelativePlacesToMove;
			for( ForwardMoveIndex = TickGroupIndex + 1; ForwardMoveIndex < TimelineEntries.Length; ++ForwardMoveIndex )
			{
				if( TimelineEntries[ForwardMoveIndex].Type == eTimeLineEntryType_MoveEffect ||
					TimelineEntries[ForwardMoveIndex].Type == eTimeLineEntryType_Group)
				{
					NumGroupsToSkip -= 1;
					if( NumGroupsToSkip <= 0 )
					{
						//make a new move effect entry and insert it at the forward move location
						NewMoveEntry = TimelineEntry; //copy the values from the original
						NewMoveEntry.iTurnsRemaining -= 1; //one less turn
														   //set the PastRoundEnd based on the entry you are moving into
						NewMoveEntry.PastRoundEnd = TimelineEntries[ForwardMoveIndex].PastRoundEnd;
						TimelineEntries.InsertItem( ForwardMoveIndex, NewMoveEntry );
						//now move any tick entries BACK one group ( which should only require back one index since groups and moves are added before ticks )
						for( ForwardTickIndex = ForwardMoveIndex + 1; ForwardTickIndex < TimelineEntries.Length; ++ForwardTickIndex)
						{
							if( TimelineEntries[ForwardTickIndex].Type == eTimeLineEntryType_Tickable )
							{
								//swap places with the immediately preceding group
								TempEntry = TimelineEntries[ForwardTickIndex - 1];
								TimelineEntries[ForwardTickIndex - 1] = TimelineEntries[ForwardTickIndex];
								TimelineEntries[ForwardTickIndex] = TempEntry;
							}
						}
						break;
					}
				}
			}
			if( NumGroupsToSkip > 0 )
			{
				//make a new move effect entry and insert it at the end location
				NewMoveEntry = TimelineEntry; //copy the values from the original
				NewMoveEntry.iTurnsRemaining -= 1; //one less turn
												   //set the PastRoundEnd based on the last entry
				NewMoveEntry.PastRoundEnd = TimelineEntries[TimelineEntries.Length -1].PastRoundEnd;
				TimelineEntries.AddItem( NewMoveEntry );
			}
			return;
		}
	}
}
function AddExtraTimelineEntriesForMoveEffects( out array<GroupTimelineEntry> TimelineEntries )
{
	local int Index;
	local int ForwardMoveIndex;
	local int ForwardTickIndex;
	local int NumGroupsToSkip;
	local GroupTimelineEntry NewMoveEntry;
	local GroupTimelineEntry TempEntry;

	//staring from the beginning of the timeline, insert any "extra" moves for a group as they are encountered
	//any tickables that come after the "extra" moves needs to be moved back one group - so they are consistent with when they will actually trigger
	for( Index = 0; Index < TimelineEntries.Length; ++Index)
	{
		if( TimelineEntries[Index].Type == eTimeLineEntryType_MoveEffect && TimelineEntries[Index].iTurnsRemaining > 0)
		{
			NumGroupsToSkip = TimelineEntries[Index].NumberOfRelativePlacesToMove;
			for( ForwardMoveIndex = Index + 1; ForwardMoveIndex < TimelineEntries.Length; ++ForwardMoveIndex )
			{
				if( TimelineEntries[ForwardMoveIndex].Type == eTimeLineEntryType_MoveEffect ||
					TimelineEntries[ForwardMoveIndex].Type == eTimeLineEntryType_Group)
				{
					NumGroupsToSkip -= 1;
					if( NumGroupsToSkip <= 0 )
					{
						//make a new move effect entry and insert it at the forward move location
						NewMoveEntry = TimelineEntries[Index]; //copy the values from the original
						NewMoveEntry.iTurnsRemaining -= 1; //one less turn
														   //set the PastRoundEnd based on the entry you are moving into
						NewMoveEntry.PastRoundEnd = TimelineEntries[ForwardMoveIndex].PastRoundEnd;
						TimelineEntries.InsertItem( ForwardMoveIndex, NewMoveEntry );
						//now move any tick entries BACK one group ( which should only require back one index since groups and moves are added before ticks )
						for( ForwardTickIndex = ForwardMoveIndex + 1; ForwardTickIndex < TimelineEntries.Length; ++ForwardTickIndex)
						{
							if( TimelineEntries[ForwardTickIndex].Type == eTimeLineEntryType_Tickable )
							{
								//swap places with the immediately preceding group
								TempEntry = TimelineEntries[ForwardTickIndex - 1];
								TimelineEntries[ForwardTickIndex - 1] = TimelineEntries[ForwardTickIndex];
								TimelineEntries[ForwardTickIndex] = TempEntry;
							}
						}
						break;
					}
				}
			}
		}
	}
}

function AdjustTimelineEntriesForEffectsThatGoFirst( out array<GroupTimelineEntry> TimelineEntries )
{
	local int GroupIndex;
	local int ForwardTickIndex;
	local int TickMoveIndex;
	local GroupTimelineEntry TempEntry;
	local bool bGroupFound;

	for( GroupIndex = 0; GroupIndex < TimelineEntries.Length; ++GroupIndex)
	{
		if( TimelineEntries[GroupIndex].Type == eTimeLineEntryType_MoveEffect ||
			TimelineEntries[GroupIndex].Type == eTimeLineEntryType_Group )
		{
			bGroupFound = true;
			//find any tickables that tick with this group and need to be displayed before the group
			for( ForwardTickIndex = GroupIndex + 1; ForwardTickIndex < TimelineEntries.Length; ++ForwardTickIndex )
			{
				if( TimelineEntries[ForwardTickIndex].Type == eTimeLineEntryType_Tickable && TimelineEntries[ForwardTickIndex].TickGroupState.ObjectID == TimelineEntries[GroupIndex].TickGroupState.ObjectID )
				{
					if( TimelineEntries[ForwardTickIndex].bTicksBeforeGroup )
					{
						//move it back to where the Index is - move all in between as well
						for( TickMoveIndex = ForwardTickIndex; TickMoveIndex > GroupIndex ; --TickMoveIndex)
						{
							//swap places with the immediately preceding entry
							TempEntry = TimelineEntries[TickMoveIndex - 1];
							TimelineEntries[TickMoveIndex - 1] = TimelineEntries[TickMoveIndex];
							TimelineEntries[TickMoveIndex] = TempEntry;
						}
					}
				}
				else
				{
					//either next group or next movegroup or new tickgroup- either way no more to check for current group
					break;
				}
			}
		}
	}
	// handle the case where any tickables are before the first group in the timeline - put them at the end
	if( bGroupFound )
	{
		while( TimelineEntries[0].Type == eTimeLineEntryType_Tickable )
		{
			TempEntry = TimelineEntries[0];
			//delete it
			TimelineEntries.Remove( 0, 1);
			//add it at the end
			TimelineEntries.AddItem( TempEntry );
		}
	}
}
function int GetUnitIndexInNonPreviewMarkerEntries( int UnitObjectID )
{
	return GetUnitIndexInMarkerEntries( UnitObjectID, LastNonPreviewMarkerEntries );
}
function int GetUnitIndexInMarkerEntries( int UnitObjectID, const array<gfxMarkerEntry> MarkerEntries )
{
	local int Index;
	local int TimelineIndex;

	TimelineIndex = -1;
	for( Index = 0; Index < MarkerEntries.Length; ++Index )
	{
		if( MarkerEntries[Index].bIsUnit )
		{
			TimelineIndex += 1;
			if( UnitObjectID == MarkerEntries[Index].ObjectID )
			{
				return TimelineIndex;
			}
		}
	}

	return INDEX_NONE;
}

function int FindTurnMarkerInList( gfxMarkerEntry MarkerID, const array<gfxMarkerEntry> MarkerEntries )
{
	local int Index;

	for( Index =0 ; Index < MarkerEntries.Length; ++Index)
	{
		if( MarkerID.ObjectID == MarkerEntries[Index].ObjectID && MarkerID.TimelineInstanceID == MarkerEntries[Index].TimelineInstanceID )
		{
			return Index;
		}
	}

	return INDEX_NONE;
}
function AddIndicesToGFXRemoved( const array<gfxMarkerEntry> MarkerEntries, out GFxObject gfxRemoved )
{
	local int Index, FoundIndex;
	local int RemovedIndex;
	local float fValue;

	RemovedIndex = 0;
	for( Index = 0; Index < LastSubmittedMarkerEntries.Length; ++Index )
	{
		FoundIndex = FindTurnMarkerInList( LastSubmittedMarkerEntries[Index], MarkerEntries );
		if( FoundIndex == INDEX_NONE )
		{
			fValue = float( Index );
			gfxRemoved.SetElementFloat( RemovedIndex, fValue );
			RemovedIndex += 1;
		}
	}
}


function GetTickablesAndMoveEffectsAttachedToGroup( XComGameState_AIGroup GroupState, out array<GroupTimelineEntry> TickableEntries, out array<GroupTimelineEntry> MoveEffectEntries )
{
	local XComGameStateHistory History;
	local StateObjectReference UnitStateObjRef;
	local XComGameState_Unit UnitState;
	local XComGameState_Effect EffectState;
	local StateObjectReference EffectRef;
	local X2Effect_SpawnDestructible DestructibleEffect;
	local XComGameState_Destructible DestructibleState;
	local XComDestructibleActor DestructibleActor;
	local XComGameState_AIGroup TickGroupState;
	local X2Effect_Claymore ClaymoreState;
	local X2Effect_PendingReinforcements PendingReinforcements;
	local GroupTimelineEntry TimelineEntry, EmptyEntry;
	local X2Effect_GroupTimelineMove MoveEffect;

	History = `XCOMHISTORY;
	if( GroupState != None )
	{
		foreach GroupState.m_arrMembers( UnitStateObjRef )
		{
			UnitState = XComGameState_Unit( History.GetGameStateForObjectID( UnitStateObjRef.ObjectID ) );
			if( UnitState != None )
			{
				foreach UnitState.AppliedEffects( EffectRef )
				{
					EffectState = XComGameState_Effect( History.GetGameStateForObjectID( EffectRef.ObjectID ) );
					if( EffectState != None )
					{
						//find any destructibles that tick during this group update
						DestructibleEffect = X2Effect_SpawnDestructible( EffectState.GetX2Effect() );
						if( DestructibleEffect != None )
						{
							DestructibleState = XComGameState_Destructible( History.GetGameStateForObjectID( EffectState.CreatedObjectReference.ObjectID ) );
							if( DestructibleState != None && DestructibleState.Health > 0 )
							{
								DestructibleActor = XComDestructibleActor( DestructibleState.GetVisualizer() );
								if( DestructibleActor != None )
								{
									TickGroupState = GroupState;
									ClaymoreState = X2Effect_Claymore( DestructibleEffect );
									if( ClaymoreState != None && EffectState.TickGroupOverrideID > 0)
									{
										TickGroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( EffectState.TickGroupOverrideID ) );
										if( TickGroupState == None )
										{
											TickGroupState = GroupState;
										}
									}
									TimelineEntry = EmptyEntry;	//set default values
									TimelineEntry.Type = eTimeLineEntryType_Tickable;
									TimelineEntry.DestructibleActor = DestructibleActor;
									TimelineEntry.SpawnedDestructibleLocName = DestructibleState.SpawnedDestructibleLocName;
									TimelineEntry.EffectObjectID = EffectState.ObjectID;
									TimelineEntry.iTurnsRemaining = EffectState.iTurnsRemaining;
									TimelineEntry.iTurnsTicked = EffectState.FullTurnsTicked;
									TimelineEntry.SourceGroupState = GroupState;
									TimelineEntry.TickGroupState = TickGroupState;
									TickableEntries.AddItem( TimelineEntry);
								}
							}
						}
						PendingReinforcements = X2Effect_PendingReinforcements( EffectState.GetX2Effect() );
						if( PendingReinforcements != None )
						{
							TickGroupState = GroupState;
							if( EffectState.TickGroupOverrideID > 0)
							{
								TickGroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( EffectState.TickGroupOverrideID ) );
								if( TickGroupState == None )
								{
									TickGroupState = GroupState;
								}
							}

							TimelineEntry = EmptyEntry;	//set default values
							TimelineEntry.Type = eTimeLineEntryType_Tickable;
							TimelineEntry.EffectObjectID = EffectState.ObjectID;
							TimelineEntry.iTurnsRemaining = EffectState.iTurnsRemaining;
							TimelineEntry.iTurnsTicked = EffectState.FullTurnsTicked;
							TimelineEntry.SourceGroupState = GroupState;
							TimelineEntry.TickGroupState = TickGroupState;
							TimelineEntry.bTicksBeforeGroup = !PendingReinforcements.bTriggerOnRemoved;
							TickableEntries.AddItem( TimelineEntry );
						}

						MoveEffect = X2Effect_GroupTimelineMove( EffectState.GetX2Effect() );
						if( MoveEffect != None && MoveEffect.NumberOfRelativePlacesToMove > 0 && ( MoveEffect.bApplyMoveOnEffectRemoved || MoveEffect.bApplyMoveOnEffectTicked) ) 
						{
							TimelineEntry = EmptyEntry;	//set default values
							TimelineEntry.Type = eTimeLineEntryType_MoveEffect;
							TimelineEntry.EffectObjectID = EffectState.ObjectID;
							TimelineEntry.iTurnsRemaining = EffectState.iTurnsRemaining;
							TimelineEntry.iTurnsTicked = EffectState.FullTurnsTicked;
							TimelineEntry.TickGroupState = GroupState;
							TimelineEntry.SourceGroupState = GroupState;
							TimelineEntry.iTurnsRemaining = ( MoveEffect.bApplyMoveOnEffectTicked ) ? EffectState.iTurnsRemaining : 1;
							TimelineEntry.NumberOfRelativePlacesToMove = MoveEffect.NumberOfRelativePlacesToMove;
							MoveEffectEntries.AddItem( TimelineEntry );
						}
					}
				}
			}
		}
	}
}

function GetTickablesAndMoveEffectsFromAvailableActionInfo( AvailableAction AvailableActionInfo, int TargetIndex,  out array<GroupTimelineEntry> TickableEntries, out array<GroupTimelineEntry> MoveEffectEntries )
{
	local XComGameState_AIGroup SourceGroupState, TargetGroupState, CurrentGroupState, TickGroupState;
	local X2Effect_Claymore ClaymoreState;
	local X2Effect_PendingReinforcements PendingReinforcements;
	local GroupTimelineEntry TimelineEntry, EmptyEntry;
	local X2Effect_GroupTimelineMove MoveEffect;
	local X2AbilityTemplate AbilityTemplate;
	local X2Effect Effect;
	local X2TacticalGameRuleset TacticalRuleset;
	local XComGameState_Unit SourceUnit, TargetUnit;
	local XComGameState_Ability AbilityState;
	local AvailableTarget Target;

	TacticalRuleset = `TACTICALRULES;
	AbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(AvailableActionInfo.AbilityObjectRef.ObjectID));
	AbilityTemplate = AbilityState != None ? AbilityState.GetMyTemplate() : None;
	if( AbilityTemplate == None )
	{
		return;
	}

	SourceUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
	SourceGroupState = SourceUnit != None ? SourceUnit.GetGroupMembership() : None;

	if( TargetIndex >= 0 && TargetIndex < AvailableActionInfo.AvailableTargets.Length )
	{
		Target = AvailableActionInfo.AvailableTargets[TargetIndex];
		TargetUnit = XComGameState_Unit( `XCOMHISTORY.GetGameStateForObjectID( Target.PrimaryTarget.ObjectID ) );
	}
	TargetGroupState = TargetUnit != None ? TargetUnit.GetGroupMembership() : None;

	CurrentGroupState = TacticalRuleset.GetCurrentInitiativeGroup();
	//handle the source effects
	if( SourceGroupState != None )
	{
		foreach AbilityTemplate.AbilityShooterEffects( Effect )
		{
			if( Effect.TargetIsValidForAbility( SourceUnit, SourceUnit, AbilityState ) )
			{
				if( ClaymoreState == None ) //only care about the first one
				{
					ClaymoreState = X2Effect_Claymore( Effect );
					if( ClaymoreState != None )
					{
						if( CurrentGroupState != None )
						{
							TickGroupState = TacticalRuleset.FindInitiativeGroupNumPlacesPastThisGroup( CurrentGroupState, ClaymoreState.DelayedDestructiblesSlotDelay);
							if( TickGroupState != None )
							{

								TimelineEntry = EmptyEntry;	//set default values
								TimelineEntry.Type = eTimeLineEntryType_Tickable;
								TimelineEntry.bIsClaymore = true;
								TimelineEntry.DestructibleActor = None;
								TimelineEntry.EffectObjectID = 0;
								TimelineEntry.iTurnsRemaining = 1;
								TimelineEntry.iTurnsTicked = 0;
								TimelineEntry.SourceGroupState = SourceGroupState;
								TimelineEntry.TickGroupState = TickGroupState;
								TickableEntries.AddItem( TimelineEntry );
							}
						}
					}
				}
				if( PendingReinforcements == None )
				{
					PendingReinforcements = X2Effect_PendingReinforcements( Effect );
					if( PendingReinforcements != None )
					{
						TickGroupState = `TACTICALRULES.FindInitiativeGroupNumPlacesPastThisGroup(SourceGroupState, -1);
						if( TickGroupState != None )
						{
							TimelineEntry = EmptyEntry;	//set default values
							TimelineEntry.Type = eTimeLineEntryType_Tickable;
							TimelineEntry.EffectObjectID = 0;
							TimelineEntry.iTurnsRemaining = 2;
							TimelineEntry.iTurnsTicked = 0;
							TimelineEntry.SourceGroupState = SourceGroupState;
							TimelineEntry.TickGroupState = TickGroupState;
							TimelineEntry.bTicksBeforeGroup = !PendingReinforcements.bTriggerOnRemoved;
							TickableEntries.AddItem( TimelineEntry );
						}
					}
				}
				MoveEffect = X2Effect_GroupTimelineMove( Effect );
				if( MoveEffect != None && MoveEffect.NumberOfRelativePlacesToMove > 0  ) 
				{
					TimelineEntry = EmptyEntry;	//set default values
					TimelineEntry.Type = eTimeLineEntryType_MoveEffect;
					TimelineEntry.EffectObjectID = 0;
					TimelineEntry.iTurnsRemaining = 1; //check for tempo surge
					TimelineEntry.iTurnsTicked = 0;
					TimelineEntry.TickGroupState = SourceGroupState;
					TimelineEntry.SourceGroupState = SourceGroupState;
					TimelineEntry.NumberOfRelativePlacesToMove = MoveEffect.NumberOfRelativePlacesToMove;
					MoveEffectEntries.AddItem( TimelineEntry );
				}
			}
		}
	}
	//add any move effects on the target of the ability
	if( TargetGroupState != None )
	{
		foreach AbilityTemplate.AbilityTargetEffects( Effect )
		{
			if( Effect.TargetIsValidForAbility( TargetUnit, SourceUnit, AbilityState ) )
			{
				MoveEffect = X2Effect_GroupTimelineMove( Effect );
				if( MoveEffect != None && MoveEffect.NumberOfRelativePlacesToMove > 0  ) 
				{
					TimelineEntry = EmptyEntry;	//set default values
					TimelineEntry.Type = eTimeLineEntryType_MoveEffect;
					TimelineEntry.EffectObjectID = 0;
					TimelineEntry.iTurnsTicked = 0;
					TimelineEntry.iTurnsRemaining = 1;
					if( MoveEffect.bMoveRelativeToCurrentGroup )
					{
						TimelineEntry.TickGroupState = CurrentGroupState;
					}
					else if ( MoveEffect.bMoveRelativeToTarget )
					{
						TimelineEntry.TickGroupState = TargetGroupState;
					}
					else
					{
						TimelineEntry.TickGroupState = SourceGroupState;
					}
					TimelineEntry.SourceGroupState = TargetGroupState;
					TimelineEntry.NumberOfRelativePlacesToMove = MoveEffect.NumberOfRelativePlacesToMove;
					MoveEffectEntries.AddItem( TimelineEntry );
				}
			}
		}
	}
}

function AddTimelineEntriesForTickGroup( XComGameState_AIGroup GroupState, bool PastRoundEnd, array<GroupTimelineEntry> TickableEntries, out array<GroupTimelineEntry> TimelineEntries )
{
	local GroupTimelineEntry TimelineEntry, EmptyEntry;
	local X2TacticalGameRuleset TacticalRuleset;

	if( GroupState != None )
	{
		TacticalRuleset = `TACTICALRULES;
		if( TacticalRuleset.IsValidInitiativeGroup( GroupState ) ) //group needs to be valid for correct counting of move effect places in the timeline
		{
			TimelineEntry = EmptyEntry;	//set default values
			TimelineEntry.Type = eTimeLineEntryType_Group;
			TimelineEntry.TickGroupState = GroupState;
			TimelineEntry.SourceGroupState = GroupState;
			TimelineEntry.iTurnsRemaining = 0;
			TimelineEntry.iTurnsTicked = 0;
			TimelineEntry.PastRoundEnd = PastRoundEnd;
			TimelineEntries.AddItem( TimelineEntry );
		}
		foreach TickableEntries( TimelineEntry )	// but non valid groups still need to add any effects that tick with the group
		{
			if( TimelineEntry.TickGroupState.ObjectID == GroupState.ObjectID )
			{
				TimelineEntry.PastRoundEnd = PastRoundEnd;
				TimelineEntries.AddItem( TimelineEntry );
			}
		}
	}
}

function AddTimelineEntryToGFX( GroupTimelineEntry TimelineEntry, out array<GfxObject> GFXTurns, out array<gfxMarkerEntry> MarkerEntries)
{
	local XComGameState_AIGroup GroupState;
	local GFxObject gfxTurn;

	local X2TacticalGameRuleset TacticalRuleset;
	local int VisualizedHistoryIndex;
	local array<int> LivingUnitIDs;
	local array<XComGameState_Unit> LivingMemberStates;
	local StateObjectReference LivingUnitRef;
	local XComGameState_Unit UnitState;
	local bool isActive, isActiveFound, isSick, isPlayer, isFlanked;
	local string HudIconStr;
	local array<XComGameState_Effect> gameStateEffects;
	local XComGameState_Effect stateEffect;
	local int DownedTurnsRemaining;
	local bool bIsCaptured;
	local array<StateObjectReference> NetworkedEnemyRefs;
	local StateObjectReference CurrentObjectRef;
	local name EffectName;
	local string ReinforcementsInfo;
	local gfxMarkerEntry MarkerEntry;
	local float fValue;
	local int MarkerIndex, TurnNumber;
	local array<string> StatusIcons;
	local XComGameState_Destructible DestructibleState;
	local XComGameState_Item DestructibleSourceItemState;
	local X2ItemTemplate DestructibleSourceItemTemplate;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	TacticalRuleset = `TACTICALRULES;
	VisualizedHistoryIndex = `XCOMVISUALIZATIONMGR.LastStateHistoryVisualized;

	isActiveFound = true;

	if( TimelineEntry.Type == eTimeLineEntryType_Group || TimelineEntry.Type == eTimeLineEntryType_MoveEffect )
	{
		GroupState = TimelineEntry.SourceGroupState;
		if( GroupState != None )
		{
			LivingUnitIDs.Length = 0;
			LivingMemberStates.Length = 0;

			if( GroupState.GetLivingMembers( LivingUnitIDs, LivingMemberStates ) )
			{
				foreach LivingMemberStates( UnitState )
				{
					LivingUnitRef.ObjectID = UnitState.ObjectID;
					DownedTurnsRemaining = 0;
					bIsCaptured = false;
					gameStateEffects = UnitState.GetUISummary_GameStateEffects();
					foreach gameStateEffects( stateEffect )
					{
						EffectName = stateEffect.GetX2Effect().EffectName;
						if( EffectName == class'X2AbilityTemplateManager'.default.CapturedName )
						{
							bIsCaptured = true;
						}
						if( EffectName == class'X2AbilityTemplateManager'.default.DownedName )
						{
							DownedTurnsRemaining = stateEffect.iTurnsRemaining;
						}
						if( EffectName == class'X2StatusEffects'.default.BleedingOutName )
						{
							DownedTurnsRemaining = stateEffect.iTurnsRemaining;
						}
						
						// Begin HELIOS Issue #10
						// Allow custom effects to mask units from the timeline
						if (class'HSHelpers' != none)
						{
							// Hijack this boolean to cancel our unit from being shown on the timeline
							if (class'HSHelpers'.default.EffectsToExcludeFromTimeline.Find(EffectName) != INDEX_NONE)
								bIsCaptured = true;
						}
						// End HELIOS Issue #10
					}
					if( !bIsCaptured && 
						!UnitState.IsUnconscious() && 
						!UnitState.bRemovedFromPlay && 
						UnitState.HasAssignedRoomBeenBreached() &&
						!UnitState.GetCharacterTemplate().bExcludeFromTimeline )
					{
						isActive = GroupState.ObjectID == TacticalRuleset.CachedUnitActionInitiativeRef.ObjectID;
						isSick = !GroupState.bSummoningSicknessCleared;
						isPlayer = UnitState.GetTeam() == eTeam_XCom;
						
						isFlanked = UnitState.IsFlanked( CurrentObjectRef, true, VisualizedHistoryIndex ) && !( UnitState.ControllingPlayerIsAI() && UnitState.GetCurrentStat( eStat_AlertLevel ) == 0 );
						class'X2Effect_NeuralNetwork'.static.GatherEnemiesInNeuralNetwork( LivingUnitRef, NetworkedEnemyRefs, VisualizedHistoryIndex );
						isActiveFound = ( isActiveFound || isActive );

						gfxTurn = Movie.CreateObject( "Object" );
						gfxTurn.SetBool( "isPlayer", isPlayer );
						gfxTurn.SetBool( "isActive", isActive && !isSick );
						gfxTurn.SetBool( "isPending", isActiveFound && !isSick );
						gfxTurn.SetBool( "isSick", isSick );
						gfxTurn.SetBool( "isFlanked", isFlanked );
						gfxTurn.SetFloat( "objectID", UnitState.ObjectID );
						gfxTurn.SetString( "specialIcon", "" );
						gfxTurn.SetFloat( "specialCount", NetworkedEnemyRefs.Length );
						gfxTurn.SetFloat( "turnsRemaining", DownedTurnsRemaining );
//						if( IsPreviewDisplayed && PreviewDamageActors.Find( UnitState.GetVisualizer() ) != INDEX_NONE )
//						{
//							gfxTurn.SetString( "name", "OUCH!! " $ UnitState.GetName( eNameType_Full ) );
//						}
//						else
//						{
							gfxTurn.SetString("name", UnitState.GetName(eNameType_First));
//						}

						gfxTurn.SetString( "icon", UnitState.GetWorkerIcon() );
						gfxTurn.SetString( "factionIcon", class'UIUtilities_Image'.static.GetFactionIcon( EFaction(UnitState.GetCharacterTemplate().UnitFaction)) );
						gfxTurn.SetFloat( "currentHP", UnitState.GetCurrentStat( eStat_HP ) );
						gfxTurn.SetFloat( "maxHP", UnitState.GetMaxStat( eStat_HP ) );
						gfxTurn.SetFloat( "previewDamage", 0 );
						gfxTurn.SetFloat( "currentShield", UnitState.GetCurrentStat( eStat_ShieldHP ) );
						gfxTurn.SetFloat( "maxShield", UnitState.GetMaxStat( eStat_ShieldHP ) );
						gfxTurn.SetFloat( "currentArmor", UnitState.GetArmorMitigationForUnitFlag() );
						gfxTurn.SetFloat( "maxArmor", UnitState.GetMaxArmor() );
						gfxTurn.SetFloat( "shreddedArmor", UnitState.Shredded );
						gfxTurn.SetString( "coverStatus", UnitState.GetCoverStatusLabel() );
						gfxTurn.SetFloat( "coverIndex", 0 ); //dakota.lemaster: Only show cover armor pips in shot previews //UnitState.GetCoverTypeFromLocation() ); //WILL NEED TO USE: class'X2Effect_ApplyWeaponDamage'.static.CalculateCoverMitigationForAbility(ShooterUnitState, UnitState, SelectedAbilityTemplate, CoverPoints);
						gfxTurn.SetFloat( "previewCoverDamage", 0 );

						StatusIcons = UnitState.GetUISummary_UnitStatusIcons( true ); //bOnlyUITimelineIcons = true
						gfxTurn.SetString("statusIcon" , StatusIcons.length == 0 ? "" : StatusIcons[0]);

						//add a marker entry
						MarkerEntry.ObjectID = UnitState.ObjectID;
						MarkerEntry.TimelineInstanceID = ( TimelineEntry.iTurnsRemaining + TimelineEntry.iTurnsTicked );
						MarkerEntry.bIsUnit = true;
						MarkerEntries.AddItem( MarkerEntry );
						fValue = float(FindTurnMarkerInList( MarkerEntry, LastSubmittedMarkerEntries ));
						gfxTurn.SetFloat( "lastPosition", fValue );

						if (LastSelectedObjectID == -1)
						{
							LastSelectedObjectID = UnitState.ObjectID;
						}

						gfxTurn.SetBool( "endRound", false );
						TurnNumber = 0;
						for( MarkerIndex = 0; MarkerIndex < MarkerEntries.Length; ++MarkerIndex )
						{
							if( MarkerEntries[MarkerIndex].bIsUnit )
							{
								TurnNumber += 1;
							}
						}
						if( !`BATTLE.GetDesc().bInBreachPhase && TurnNumber > 0 )
						{
							gfxTurn.SetString( "turnCountDisplay", string( TurnNumber ) );
						}
						else
						{
							gfxTurn.SetString( "turnCountDisplay", "" );
						}

						GFXTurns.AddItem( gfxTurn );
						//only ever add one units picture from a group to the timeline display
						break;
					}
				}
			}
		}
	}
	if( TimelineEntry.Type == eTimeLineEntryType_Tickable )
	{
		//add it to the list here
		gfxTurn = Movie.CreateObject( "Object" );
		gfxTurn.SetBool( "isPlayer", false );
		gfxTurn.SetBool( "isActive", false );
		gfxTurn.SetBool( "isPending", isActiveFound );
		gfxTurn.SetBool( "isSick", false );
		gfxTurn.SetFloat( "objectID", TimelineEntry.EffectObjectID );
		gfxTurn.SetString("turnCountDisplay", "");

		HudIconStr = "";
		if( TimelineEntry.DestructibleActor != None || TimelineEntry.bIsClaymore )
		{
			gfxTurn.SetFloat( "turnsRemaining", TimelineEntry.iTurnsRemaining );
			gfxTurn.SetString("factionIcon", "img:///UILibrary_Common.faction_grenade");

			if( TimelineEntry.SpawnedDestructibleLocName != "")
			{
				gfxTurn.SetString("name", TimelineEntry.SpawnedDestructibleLocName);
			}
			else
			{
				gfxTurn.SetString("name", default.m_strDefaultGrenade);
			}

			DestructibleState = XComGameState_Destructible(History.GetGameStateForObjectID(TimelineEntry.DestructibleActor.ObjectID));
			DestructibleSourceItemState = XComGameState_Item(History.GetGameStateForObjectID(DestructibleState.SourceItemRef.ObjectID));
			DestructibleSourceItemTemplate = DestructibleSourceItemState.GetMyTemplate();

			if (DestructibleSourceItemTemplate != none &&
				DestructibleSourceItemTemplate.strTimelineIcon != "")
			{
				HudIconStr = DestructibleSourceItemTemplate.strTimelineIcon;
			}
			else
			{
				HudIconStr = "img:///UILibrary_DioPortraits.Timeline.XCOM_Grenade";
			}
		}
		else
		{
			gfxTurn.SetBool("isReinforcements", true);
			HudIconStr = "img:///" $ class'UIUtilities_Image'.const.TargetIcon_Attention;

			if( TimelineEntry.iTurnsRemaining > 1 )
			{
				gfxTurn.SetString("reinforcementsHeader", m_strReinforcementsHeader);
				ReinforcementsInfo = Repl(m_strReinforcementsBody, "%NUMTURNS", TimelineEntry.iTurnsRemaining);
				gfxTurn.SetString("reinforcementsBody", ReinforcementsInfo);
			}
			else
			{
				gfxTurn.SetString("reinforcementsHeader", m_strReinforcementsImminentHeader);
				gfxTurn.SetString("reinforcementsBody", m_strReinforcementsImminentBody);
			}
		}
		gfxTurn.SetString( "icon", HudIconStr );
		gfxTurn.SetBool( "endRound", false );

		//add a marker entry
		MarkerEntry.ObjectID = TimelineEntry.EffectObjectID;
		MarkerEntry.TimelineInstanceID = ( TimelineEntry.iTurnsRemaining + TimelineEntry.iTurnsTicked );
		MarkerEntry.bIsUnit = false;
		MarkerEntries.AddItem( MarkerEntry );
		fValue = float(FindTurnMarkerInList( MarkerEntry, LastSubmittedMarkerEntries ));
		gfxTurn.SetFloat( "lastPosition", fValue );

		GFXTurns.AddItem( gfxTurn );
	}

	if( TimelineEntry.Type == eTimeLineEntryType_GenericMarker )
	{
		//add it to the list here
		gfxTurn = Movie.CreateObject( "Object" );
		gfxTurn.SetBool( "isPlayer", false );
		gfxTurn.SetBool( "isActive", false );
		gfxTurn.SetBool( "isPending", isActiveFound );
		gfxTurn.SetBool( "isSick", false );
		gfxTurn.SetFloat( "objectID", TimelineEntry.EffectObjectID );
		gfxTurn.SetString("turnCountDisplay", "");

		HudIconStr = "";
		gfxTurn.SetBool("isReinforcements", true);
		HudIconStr = "img:///" $ class'UIUtilities_Image'.const.TargetIcon_Attention;

			gfxTurn.SetString("reinforcementsHeader", m_strReinforcementsImminentHeader);
			gfxTurn.SetString("reinforcementsBody", m_strReinforcementsImminentBody);

		gfxTurn.SetString( "icon", HudIconStr );
		gfxTurn.SetBool( "endRound", false );

		//add a marker entry
		MarkerEntry.ObjectID = -2;
		MarkerEntry.TimelineInstanceID = 0;
		MarkerEntry.bIsUnit = false;
		MarkerEntries.AddItem( MarkerEntry );
		fValue = GFXTurns.Length;
		gfxTurn.SetFloat( "lastPosition", fValue );

		GFXTurns.AddItem( gfxTurn );
	}

	
}

simulated function OnCommand(string cmd, string arg)
{
	local int objectID;
	local bool mouseIn;
	local array<string> args;
	
	args = SplitString(arg, ",");

	// TODO: clean up this logic
	if (cmd == "turnItem" || cmd == "currentItem")
	{
		mouseIn = int(args[0]) == 1 ? true : false;
		objectID = int(args[1]);

		if (mouseIn)
		{
			if (cmd == "turnItem")
			{
				MC.FunctionNum("showTimelineTooltip", objectID);

				if (!Movie.IsMouseActive()) // if we got here with the mouse inactive, that means it was controller input and needs to be handled slightly differently
				{
					TryLookAtUnit(ObjectID);
				}
			}

			`SOUNDMGR.PlayLoadedAkEvent("UI_Tactical_Timeline_Mouseover", self);
		}
		else
		{
			MC.FunctionNum("hideTimelineTooltip", objectID);
			Tooltips.TooltipMgr.HideAllTooltips();
			RemoveHighlight();
			`SOUNDMGR.PlayLoadedAkEvent("UI_Tactical_Timeline_MouseOff", self);
		}
	}
	else if (cmd == "currentItemClicked")
	{
		objectID = int(args[0]);
		if (objectID == LastSelectedObjectID)
		{
			XComTacticalInput(XComTacticalController(PC).PlayerInput).Stick_L3(class'UIUtilities_Input'.const.FXS_ACTION_RELEASE);
		}
		else
		{
			XComTacticalController(PC).Visualizer_SelectUnit(XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(objectID)));
		}
		`SOUNDMGR.PlayLoadedAkEvent("UI_Tactical_Timeline_Click", self);
	}
	else if (cmd == "turnItemClicked")
	{
		objectID = int(args[0]);

		if (`PRES.m_kTacticalHUD.m_isMenuRaised)
		{
			`PRES.m_kTacticalHUD.m_kAbilityHUD.DirectTargetObject(objectID);
		}
		else
		{
			TryLookAtUnit(ObjectID);
		}

		`SOUNDMGR.PlayLoadedAkEvent("UI_Tactical_Timeline_Click", self);
	}
	else if (cmd == "PlayAppearSound")
	{
		`SOUNDMGR.PlayLoadedAkEvent("UI_Tactical_Timeline_Appear", self);
	}
	else if (cmd == "PlayFirstRetractSound")
	{
		`SOUNDMGR.PlayLoadedAkEvent("UI_Tactical_Timeline_Retract", self);
	}
	else if (cmd == "PlayLastRetractSound")
	{
		`SOUNDMGR.PlayLoadedAkEvent("UI_Tactical_Timeline_Stop", self);
	}
}

simulated function SetShotSelection(bool show)
{
	MC.FunctionBool("setShotSelection", show);
}

simulated function SetTimelineTarget(int objectID)
{
	MC.FunctionNum("setTimelineTarget", objectID);
}

simulated function ClearTimelineTarget(int objectID)
{
	MC.FunctionNum("clearTimelineTarget", objectID);
}

simulated function ClearTimelineTargets()
{
	MC.FunctionVoid("clearTimelineTargets");
}

simulated function HighlightTarget(int objectID)
{
	MC.FunctionNum("highlightTarget", objectID);
}

simulated function TryLookAtUnit(int ObjectID)
{
	local Actor LookAtActor;
	local XGUnit UnitVisualizer;
	local XComGameState_BaseObject TargetedObject;

	TargetedObject = `XCOMHISTORY.GetGameStateForObjectID(ObjectID);
	if (TargetedObject != None)
	{
		LookAtActor = TargetedObject.GetVisualizer();
		if (LookAtActor != None)
		{
			UnitVisualizer = XGUnit(LookAtActor);
			if (UnitVisualizer != None)
			{
				HighlightUnit(UnitVisualizer);
			}

			if (!XComPresentationLayer(screen.Owner).Get2DMovie().HasModalScreens())
			{
				`XEVENTMGR.TriggerEvent('TimelineRequestCameraFocusOfUnit', TargetedObject, TargetedObject, None);
			}
		}
	}
}

simulated function HighlightUnit(XGUnit UnitToHighlight)
{
	local XComGameState_Unit UnitState;
	local bool isPlayer;
	
	highlightedEnemy = UnitToHighlight;
	if (highlightedEnemy != none)
	{
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitToHighlight.ObjectID));
		isPlayer = UnitState.GetTeam() == eTeam_XCom;

		highlightedEnemy.ShowSelectionBox(true, !isPlayer);
	}
}

simulated function RemoveHighlight()
{
	if (highlightedEnemy != none)
	{
		highlightedEnemy.ShowSelectionBox(false);
	}
}

simulated function bool UnitContainerItemClicked(int ObjectID)
{
	local XComGameState_Unit UnitState;
	local bool bChangeUnitSuccess;
	local XGUnit UnitVisualizer;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ObjectID));
	UnitVisualizer = XGUnit(UnitState.GetVisualizer());

	// e.g. MineSpike
	if (!UnitVisualizer.IsFriendly(PC))
		return false;

	bChangeUnitSuccess = (UnitState != none) && XComTacticalController(PC).Visualizer_SelectUnit(UnitState);
	
	return bChangeUnitSuccess;
}

public function TargetTurnItem(int objectID)
{
	RootMC.ActionScriptVoid("TargetTurnItem");
}

function updateInitiativeTurns(GFxObject initiativeTurns)
{
	RootMC.ActionScriptVoid("updateInitiativeTurns");
}

function UpdateCurrentUnitData(GFxObject Units)
{
	RootMC.ActionScriptVoid("updateCurrentUnitData");
}

function int GetMissionTurnCounter()
{
	local XComGameStateHistory History;
	local XComGameState_UITimer UITimer;

	History = `XCOMHISTORY;
	UITimer = XComGameState_UITimer(History.GetSingleGameStateObjectForClass(class'XComGameState_UITimer', true));
	if (UITimer != none && UITimer.ShouldShow)
	{
		return UITimer.TimerValue;
	}

	return 0;
}

// ===========================================================================
//  DEFAULTS:
// ===========================================================================
defaultproperties
{
	Package = "/ package/gfxTacticalTimeline/TacticalTimeline";
	MCName = "theTacticalTimeline";

	bHideOnLoseFocus = false;
	bAnimateOnInit = false;
	bProcessMouseEventsIfNotFocused = false;

	m_bVisible = false;
}
