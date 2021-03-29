//---------------------------------------------------------------------------------------
//  FILE:    X2Effect_Claymore.uc
//  AUTHOR:  Joshua Bouscher  --  7/18/2016
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class X2Effect_Claymore extends X2Effect_SpawnDestructible config(GameData)
	native(Core);

var config int DelayedDestructiblesSlotDelay; //delayed bombs and grenades are delayed this many timeline slots

simulated protected function OnEffectAdded( const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState )
{
	local Object ThisObj;
	local X2EventManager EventMgr;
	local X2TacticalGameRuleset TacticalRuleset;
	local XComGameState_Unit SourceUnitState;
	local XComGameState_AIGroup CurrentGroupState;
	local XComGameState_AIGroup TickGroupState;
	local XComGameState_Item SourceItemState;
	local X2ItemTemplate SourceItemTemplate;
	local XComGameState_Destructible DestructibleState;

	// HELIOS #31 Variables
	local XComLWTuple Tuple;

	super.OnEffectAdded( ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
	
	if( class'X2TacticalGameRuleset'.default.bInterleaveInitiativeTurns)
	{
		EventMgr = `XEVENTMGR;
		TacticalRuleset = `TACTICALRULES;
		//get the future timeline event group
		SourceUnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
		if( SourceUnitState != None )
		{
			CurrentGroupState = TacticalRuleset.GetCurrentInitiativeGroup();
			if(CurrentGroupState != None )
			{
				TickGroupState = TacticalRuleset.FindInitiativeGroupNumPlacesPastThisGroup(CurrentGroupState, default.DelayedDestructiblesSlotDelay);
				if( TickGroupState != None )
				{
					ThisObj = NewEffectState;
					EventMgr.UnRegisterFromEvent( ThisObj, 'UnitGroupTurnBegun' );
					NewEffectState.TickGroupOverrideID = TickGroupState.ObjectID;
					EventMgr.RegisterForEvent( ThisObj, 'UnitGroupTurnEnded', NewEffectState.OnGroupTurnTicked, ELD_OnStateSubmitted,, TickGroupState );
					EventMgr.RegisterForEvent( ThisObj, 'TickGroupChanged', NewEffectState.OnTickGroupChanged, ELD_OnStateSubmitted, , TickGroupState );
				}
			}
		}
	}

	// pass some source item info down to the newly created destructible state object
	foreach NewGameState.IterateByClassType(class'XComGameState_Destructible', DestructibleState)
	{
		SourceItemState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.AbilityInputContext.ItemObject.ObjectID));
		if (SourceItemState != None)
		{
			SourceItemTemplate = X2GrenadeTemplate(SourceItemState.GetMyTemplate());
			DestructibleState.SourceItemRef = SourceItemState.GetReference();
			DestructibleState.SpawnedDestructibleLocName = SourceItemTemplate.GetItemFriendlyName(SourceItemState.ObjectID);
		}
		DestructibleState.ClaymoreEffectRef = NewEffectState.GetReference();
		DestructibleState.SourceAbilityRef = ApplyEffectParameters.AbilityInputContext.AbilityRef;

		// Start HELIOS Issue #31
		// Allow mods and other gameplay elements to modify the spawned destructible gamestate and item via Event Listener
		// EventData: 	XComGameState_Destructible, newly spawned item
		// EventSource: ApplyEffectParameters encapsulated as an Tuple, which contains data pertaining to the spawned destructible (AbilityState, ItemState, etc.)

		Tuple = new class'XComLWTuple';
		Tuple.Id = 'HELIOS_Data_SpawnClaymore_AEP';
		Tuple.Data.Add(3);
		Tuple.Data[0].Kind 	= XComLWTVObject;
		Tuple.Data[0].o 	= SourceUnitState;
		Tuple.Data[1].Kind 	= XComLWTVObject;
		Tuple.Data[1].o 	= SourceItemState;
		Tuple.Data[2].Kind 	= XComLWTVInt;
		Tuple.Data[2].i 	= ApplyEffectParameters.AbilityStateObjectRef.ObjectID;

		`XEVENTMGR.TriggerEvent('HELIOS_TACTICAL_Claymore_EffectAdded_SpawnedDestructible', DestructibleState, Tuple, NewGameState);
		// End HELIOS Issue #31

		break;
	}
}

simulated function OnEffectRemoved( const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState )
{
	local X2EventManager EventMan;
	local XComGameState_Unit SourceUnitState;
	local XComGameState_Destructible DestructibleState;

	super.OnEffectRemoved( ApplyEffectParameters, NewGameState, bCleansed, RemovedEffectState );

	DestructibleState = XComGameState_Destructible(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.ItemStateObjectRef.ObjectID));
	if( DestructibleState != None )
	{
		SourceUnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
		EventMan = `XEVENTMGR;
		if( bCleansed )
		{
			EventMan.TriggerEvent('Claymore_EffectRemoved_Cleansed', DestructibleState, SourceUnitState, NewGameState);
		}
		else
		{
			EventMan.TriggerEvent('Claymore_EffectRemoved', DestructibleState, SourceUnitState, NewGameState);
		}
	}
}
simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local X2Action_UpdateUI UpdateUIAction;
	local XComGameState_Destructible DestructibleState;

	UpdateUIAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
	UpdateUIAction.SpecificID = ActionMetadata.StateObject_NewState.ObjectID;
	UpdateUIAction.UpdateType = EUIUT_GroupInitiative;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Destructible', DestructibleState)
	{
		`PRES.m_kUnitFlagManager.AddFlag(DestructibleState.GetReference());
		break;
	}
}
DefaultProperties
{
	EffectName = "Claymore"
	DuplicateResponse = eDupe_Allow
	TargetingIcon=Texture2D'UILibrary_XPACK_Common.target_claymore'
	bTargetableBySpawnedTeamOnly = true
	bPersistThroughEvacAndFlee = true
}