//---------------------------------------------------------------------------------------
//  FILE:    XComGameStateContext_TacticalGameRule.uc
//  AUTHOR:  Ryan McFall  --  11/21/2013
//  PURPOSE: XComGameStateContexts for game rule state changes in the tactical game. Examples
//           of this sort of state change are: Units added, changes in turn phase, etc.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameStateContext_TacticalGameRule extends XComGameStateContext native(Core);

enum GameRuleStateChange
{
	eGameRule_TacticalGameStart,
	eGameRule_RulesEngineStateChange,   //Called when the turn changes over to a new phase. See X2TacticalGameRuleset and its states.
	eGameRule_UnitAdded,
	eGameRule_UnitChangedTeams,
	eGameRule_ReplaySync,               //This informs the system sync all visualizers to an arbitrary state
	eGameRule_SkipTurn,
	eGameRule_SkipUnit,
	eGameRule_PlayerTurnBegin,
	eGameRule_PlayerTurnEnd,
	eGameRule_TacticalGameEnd,
	eGameRule_DemoStart,
	eGameRule_ClaimCover,
	eGameRule_UpdateAIPlayerData,
	eGameRule_UpdateAIRemoveAlertTile,
	eGameRule_UnitGroupTurnBegin,
	eGameRule_UnitGroupTurnEnd,
	eGameRule_BeginBreachMode,			//DIO - performs game state updates relating to entering the next breach phase of a mission
	eGameRule_MarkCorpseSeen,
	eGameRule_UseActionPoint,
	eGameRule_AIRevealWait,				// On AI patrol unit's move, Patroller is alerted to an XCom unit.   Waits for other group members to catch up before reveal.
	eGameRule_SyncTileLocationToCorpse, // Special handling for XCOM units. The only case where a visualizer sequence can push data to the game state
	eGameRule_EndBreachMode,			//DIO - game state cleanup for breach mode
	eGameRule_ForceSyncVisualizers,
	eGameRule_RoomCleared,				//DIO - indicates that a room has been cleared and that XCOM should proceed to the next room
	eGameRule_RoundBegin,				//DIO - interleaved turns beginning of round
	eGameRule_BreachSequencCommence,	//DIO - player presseed 'breach' button and their decisions are confirmed, modify anything after confirmation of xcom placement
};

enum PersistentEffectWatchRule
{
	eWatchRule_TacticalGameStart,

	eWatchRule_UnitTurnBegin,		//Start of a timeline turn for the affected unit
	eWatchRule_UnitTurnEnd,			//End of a timeline turn for the affected unit
	eWatchRule_SourceUnitTurnBegin, //Start of timeline turn for the source unit of the effect 
	eWatchRule_AnyTurnEnd,			//End of every single timeline turn
	eWatchRule_RoomCleared,			//End of an encounter
	eWatchRule_RoundBegin,			//Start of each round, first trigger post breach
	eWatchRule_AnyTurnStart,		//start of every single timeline turn, slightly more useful that turn end, as round-begin will have triggered beforehand
};

var GameRuleStateChange     GameRuleType;
var StateObjectReference    PlayerRef;      //Player associated with this game rule state change, if any
var StateObjectReference    UnitRef;		//Unit associated with this game rule state change, if any
var StateObjectReference    AIRef;			//AI associated with this game rule state chance, if any
var name RuleEngineNextState;               //The name of the new state that the rules engine is entering. Can be used for error checking or actually implementing GotoState
var bool bSkipVisualization;				// if true, the context still needs to build for event processing, but the special viaulization associated with this state change should be skipped
var bool bAborted;							// True if the mission was aborted

											
//XComGameStateContext interface
//***************************************************
/// <summary>
/// Should return true if ContextBuildGameState can return a game state, false if not. Used internally and externally to determine whether a given context is
/// valid or not.
/// </summary>
function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

/// <summary>
/// Override in concrete classes to converts the InputContext into an XComGameState
/// </summary>
function XComGameState ContextBuildGameState()
{
	local XComGameState_Unit UnitState;
	local XComGameState_Unit UpdatedUnitState;
	local array<XComGameState_Unit> XComUnitStates;
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_Player PlayerState;
	local XComGameState_Effect EffectState;
	local X2Effect_Persistent  PersistentEffect;
	local XComGameState_AIPlayerData AIState, UpdatedAIState;
	local XComGameState_AIUnitData AIUnitState;
	local bool bHadActionPoints;
	local int iComponentID;
	//local bool bClaimCoverAnyChanges;		//True if the claim cover game state contains meaningful changes
	local XComGameState_Player CurrentPlayer;
	local XComGameState_BattleData BattleData;
	local XComGameState_BreachData BreachDataState;
	local XComGameState_AIGroup GroupState;
	local XGUnit UnitVisualizer;
	local Vector TestLocation;
	local TTile FloorTile;
	local XComGameState_CampaignSettings CampaignSettings;
	local XComGameState_Ability NewAbilityState;

	//Breach mode support vars
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit XComSquadMemberState, NewUnitState;
	local XComGameState_Item WeaponState;
	local array<XComGameState_Item> DemoExpertUtilityItems;
	local XComGameState_Item UtilityItem;
	local int NumActionPoints;
	local int i;
	local name TacticalTagName;

	// Enemy clearing support vars
	local StateObjectReference EffectRef;
	local int EffectIndex, NumEffects;
	local StateObjectReference EnemyRef;

	local X2EventManager EventManager;

	local bool bUnitHealed;
	local int OldHP, NewHP;

	History = `XCOMHISTORY;
	NewGameState = none;
	EventManager = `XEVENTMGR;
	CampaignSettings = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));

	switch(GameRuleType)
	{
	case eGameRule_SkipTurn : 
		`assert(PlayerRef.ObjectID > 0);
		NewGameState = History.CreateNewGameState(true, self);
		//Clear all action points for this player's units
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if( UnitState.ControllingPlayer.ObjectID == PlayerRef.ObjectID )
			{					
				UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			
				// if the unit was skipped, the SkippedActionPoints would have been already set, 
				// just use that value because the action points would have been cleared.  line 153
				// some abilities, EverVigilant for example are dependent on this value to function correctly
				// the value gets reset when the group turn starts
				if (UpdatedUnitState.SkippedActionPoints.length < 1)
				{
					UpdatedUnitState.SkippedActionPoints = UpdatedUnitState.ActionPoints;
				}

				UpdatedUnitState.ActionPoints.Length = 0;
			}
		}
		break;
	case eGameRule_SkipUnit : 
		`assert(UnitRef.ObjectID > 0);
		NewGameState = History.CreateNewGameState(true, self);		
		UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
		bHadActionPoints = UpdatedUnitState.ActionPoints.Length > 0;
		UpdatedUnitState.SkippedActionPoints = UpdatedUnitState.ActionPoints;
		UpdatedUnitState.ActionPoints.Length = 0;//Clear all action points for this unit
		if( bHadActionPoints )
		{
			`XEVENTMGR.TriggerEvent('ExhaustedActionPoints', UpdatedUnitState, UpdatedUnitState, NewGameState);
		}
		else
		{
			`XEVENTMGR.TriggerEvent('NoActionPointsAvailable', UpdatedUnitState, UpdatedUnitState, NewGameState);
		}

		foreach UpdatedUnitState.ComponentObjectIds(iComponentID)
		{
			if (History.GetGameStateForObjectID(iComponentID).IsA('XComGameState_Unit'))
			{
				UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', iComponentID));
				if (UpdatedUnitState != None)
				{
					UpdatedUnitState.ActionPoints.Length = 0;//Clear all action points for this unit
				}
			}
		}
		break;
	case eGameRule_UseActionPoint:
		`assert(UnitRef.ObjectID > 0);
		NewGameState = History.CreateNewGameState(true, self);		
		UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
		if (UpdatedUnitState.ActionPoints.Length > 0)
			UpdatedUnitState.ActionPoints.Remove(0, 1);
		break;

	case eGameRule_ClaimCover:
		//  jbouscher: new reflex system does not want to do this
		//NewGameState = History.CreateNewGameState(true, self);		
		//
		//UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));		
		//		
		//if( UpdatedUnitState.GetTeam() == eTeam_XCom )
		//{
		//	//This game state rule is used as an end cap for movement, so it is here that we manipulate the
		//	//reflex triggering state for AI units. Red-alert units need to have their reflex trigger flag cleared
		//	//but this needs to happen after any X-Com moves are complete
		//	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		//	{
		//		if( UnitState.GetCurrentStat(eStat_AlertLevel) > 1 && UnitState.bTriggersReflex )
		//		{				
		//			bClaimCoverAnyChanges = true;
		//			UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
		//			UpdatedUnitState.bTriggersReflex = false;
		//		}
		//	}
		//}
		//
		//if( !bClaimCoverAnyChanges )
		//{
		//	History.CleanupPendingGameState(NewGameState);
		//	NewGameState = none;
		//}
		break;
	case eGameRule_UpdateAIPlayerData:
		`assert(PlayerRef.ObjectID > 0);
		NewGameState = History.CreateNewGameState(true, self);
		foreach History.IterateByClassType(class'XComGameState_AIPlayerData', AIState)
		{
			if ( AIState.m_iPlayerObjectID == PlayerRef.ObjectID )
			{
				UpdatedAIState = XComGameState_AIPlayerData(NewGameState.ModifyStateObject(class'XComGameState_AIPlayerData', AIState.ObjectID));
				UpdatedAIState.UpdateData(PlayerRef.ObjectID);
				break;
			}
		}
	break;
	case eGameRule_UpdateAIRemoveAlertTile:
		// deprecated game rule
		`RedScreen("Called deprecated game rule:eGameRule_UpdateAIRemoveAlertTile. This should not happen.");
		//`assert(AIRef.ObjectID > 0);
		//NewGameState = History.CreateNewGameState(true, self);
		//AIUnitState = XComGameState_AIUnitData(NewGameState.ModifyStateObject(class'XComGameState_AIUnitData', AIRef.ObjectID));
		//if (AIUnitState.m_arrAlertTiles.Length > 0)
		//	AIUnitState.m_arrAlertTiles.Remove(0,1);
		break;
	case eGameRule_PlayerTurnBegin:
		NewGameState = History.CreateNewGameState(true, self);

		// Update this player's turn counter
		CurrentPlayer = XComGameState_Player(NewGameState.ModifyStateObject(class'XComGameState_Player', PlayerRef.ObjectID));

		//only update the PlayerTurnCount if it is the first time in the playerturnOrder
		if( `TACTICALRULES.GetNumberOfInitiativeTurnsTakenThisRound(CurrentPlayer.ObjectID) == 0 )
		{
			CurrentPlayer.PlayerTurnCount += 1;
		}

		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', false));
		BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
		BattleData.UnitActionPlayerRef = CurrentPlayer.GetReference();
		BattleData.UnitActionInitiativeRef = BattleData.UnitActionPlayerRef;

		break;
	case eGameRule_PlayerTurnEnd:
		// simple placeholder states
		NewGameState = History.CreateNewGameState(true, self);
		CurrentPlayer = XComGameState_Player(NewGameState.ModifyStateObject(class'XComGameState_Player', PlayerRef.ObjectID));
		CurrentPlayer.ChosenActivationsThisTurn = 0;
		CurrentPlayer.ActionsTakenThisTurn = 0;
		break;

	case eGameRule_UnitGroupTurnBegin:
		NewGameState = History.CreateNewGameState(true, self);
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if (UnitState.ControllingPlayer.ObjectID == PlayerRef.ObjectID)
			{
				UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				UpdatedUnitState.SkippedActionPoints.Length = 0;
			}
		}
		break;
	case eGameRule_UnitGroupTurnEnd:
		// simple placeholder states
		NewGameState = History.CreateNewGameState(true, self);
		GroupState = XComGameState_AIGroup(History.GetGameStateForObjectID(UnitRef.ObjectID)); // Unit ref is actually the group ref here
		if( GroupState != None && GroupState.m_arrMembers.Length > 0 )
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(GroupState.m_arrMembers[0].ObjectID));
			if( UnitState != None && UnitState.IsChosen() )
			{
				UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				UnitState.ActivationLevel = 0;
			}
		}
		// If the ability is cooling down AND it only has 1 turn left - zero it now
		foreach History.IterateByClassType(class'XComGameState_Ability', NewAbilityState)
		{				
			if (NewAbilityState.IsCoolingDown() && NewAbilityState.iCooldown == 1 && !NewAbilityState.HasTickedSinceCooldownStarted)
			{
				// update the cooldown on the ability itself
				NewAbilityState = XComGameState_Ability(NewGameState.ModifyStateObject(class'XComGameState_Ability', NewAbilityState.ObjectID));
				NewAbilityState.iCooldown = 0;
				NewAbilityState.HasTickedSinceCooldownStarted = true;
			}
		}
		break;
	case eGameRule_BeginBreachMode:		
		//Update the battle data's state with the current breach situation
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', false));			
		if (BattleData.MapData.RoomIDs.Length == 0) //If there are zero room IDs, the breach state is undefined
		{
			`RedScreen("eGameRule_BeginBreachMode could not configure the battle data breach state variables because the map (" @ BattleData.MapData.PlotMapName @ ") does not contain RoomVolumes! This will cause issues with objectives / mission completion. @leveldesign");
		}
		else
		{
			NewGameState = History.CreateNewGameState(true, self);
			BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

			if (`TACTICALRULES.bAllowKismetBreachControl)
			{
				// Find the list index with the correct breach room in it
				BattleData.BreachingRoomListIndex = BattleData.MapData.RoomIDs.Find(BattleData.BreachingRoomID);
				BattleData.bNextRoomSet = false;
			}
			//Increment the encounter ID we are facing. Default value is -1 so the first breach will increment this to 0.
			else
			{
				// Auto advance to the next room in the sequence
				++BattleData.BreachingRoomListIndex;
			}

			//Let the battle data know we are in breach selection mode
			BattleData.BreachSubPhase = eBreachSubPhase_Selection;

			//Indicate that we are in the breach phase of the ruleset - cleared by eGameRule_EndBreachMode
			BattleData.bInBreachPhase = true;

			//Make sure there are enough rooms, otherwise a mission scripting error has occurred.
			if (BattleData.BreachingRoomListIndex < BattleData.MapData.RoomIDs.Length)
			{	
				// BreachingRoomID is set by mission scripting
				// kismet will activate BeginBreach node which will create and submit XComGameStateContext_SelectBreachRoom 
				if (!`TACTICALRULES.bAllowKismetBreachControl)
				{
					BattleData.BreachingRoomID = BattleData.MapData.RoomIDs[BattleData.BreachingRoomListIndex];
				}
				BattleData.bRoomCleared = false; //Starting a new room, set the room cleared flag appropriately
			}
			else
			{
				`RedScreen("eGameRule_BeginBreachMode was called despite the player finishing all rooms on map (" @ BattleData.MapData.PlotMapName @ "). The mission scripting should have prevented this. @gameplay");
			}
		}

		//Breach currently requires action points to function, so grant each of the player's units a bunch at the start. Only attempt this if the above block succeeded.
		if (NewGameState != none)
		{
			NumActionPoints = 10;
			foreach History.IterateByClassType(class'XComGameState_Unit', XComSquadMemberState)
			{
				if (XComSquadMemberState == None || XComSquadMemberState.GetTeam() != eTeam_XCom || XComSquadMemberState.bRemovedFromPlay || XComSquadMemberState.GetMyTemplate().bIsCosmetic)
					continue;
				if (XComSquadMemberState.IsAlive() && !XComSquadMemberState.IsUnconscious())
				{
					XComSquadMemberState = XComGameState_Unit(NewGameState.ModifyStateObject(XComSquadMemberState.Class, XComSquadMemberState.ObjectID));
					XComSquadMemberState.ActionPoints.Length = 0;//Clear the action point list initially
					for (i = 0; i < NumActionPoints; ++i)
					{
						XComSquadMemberState.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.StandardActionPoint);
					}

					XComSquadMemberState.bCanTraverseRooms = true;
					XComSquadMemberState.AssignedToRoomID = BattleData.BreachingRoomID;
				}
			}
		}

		//DIOTUTORIAL: Manage tutorial tactical tag state, so we track which breach is active
		DioHQ = XComGameState_HeadquartersDio(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));
		if (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive') != INDEX_NONE)
		{
			DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive_Room_-1');//in case of an index_none lookup later
			DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive_Room_0');
			DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive_Room_1');
			DioHQ.TacticalGameplayTags.RemoveItem('DioTutorialMissionActive_Room_2');

			switch (BattleData.BreachingRoomListIndex)
			{
			case 0:
				TacticalTagName = 'DioTutorialMissionActive_Room_0';
				break;
			case 1:
				TacticalTagName = 'DioTutorialMissionActive_Room_1';
				break;
			case 2:
				TacticalTagName = 'DioTutorialMissionActive_Room_2';
				break;
			default:
				TacticalTagName = 'DioTutorialMissionActive_Room_-1';
			}
			DioHQ.TacticalGameplayTags.AddItem(TacticalTagName);
		}

		class'XComBreachHelpers'.static.RefreshBreachPointAndSlotInfos(NewGameState);

		// Currently we assume the breach phase is nested inside of an encounter so make sure to trigger the encounter start first
		EventManager.TriggerEvent( 'EncounterBegin', BattleData);
		EventManager.TriggerEvent( 'BreachPhaseBegin' );
		break;
	case eGameRule_EndBreachMode:
		NewGameState = History.CreateNewGameState(true, self);
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if (UnitState.IsAlive())
			{
				NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
				NewUnitState.ActionPoints.Length = 0;//Clear the action point list - should start with a clean slate after breaching ( for now )
				NewUnitState.bCanTraverseRooms = false; //Established as a baseline. Enable selectively by game logic after this.
			}
		}

		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', false));
		BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
		BattleData.bInBreachPhase = false;
		
		if (`TACTICALRULES.bAllowKismetBreachControl &&
			BattleData.BreachingRoomID == BattleData.MapData.RoomIDs[BattleData.BreachingRoomListIndex])//Only reset belowIf this expression is true, otherwise it means that the player won the room encounter during the breach phase
		{
			//Ensure this is false in case the level kismet set it true after the breach phase started. Otherwise the breach phase will start over
			//after first unit actions phase / round is over.
			BattleData.bNextRoomSet = false;		
		}
	
		`TACTICALRULES.BuildInitiativeOrder(NewGameState);

		`TACTICALRULES.FireUnitBreachEndTriggers( NewGameState );
		`XEVENTMGR.TriggerEvent( 'BreachPhaseEnd',,NewGameState);
		break;
	case eGameRule_UnitAdded:
		// simple placeholder states
		NewGameState = History.CreateNewGameState(true, self);
		break;

	case eGameRule_TacticalGameEnd:
		NewGameState = BuildTacticalGameEndGameState();
		break;

	case eGameRule_UnitChangedTeams:
		NewGameState = BuildUnitChangedTeamGameState();
		break;

	case eGameRule_MarkCorpseSeen:
		`assert( AIRef.ObjectID > 0 && UnitRef.ObjectID > 0);
		NewGameState = History.CreateNewGameState(true, self);
		AIUnitState = XComGameState_AIUnitData(NewGameState.ModifyStateObject(class'XComGameState_AIUnitData', AIRef.ObjectID));
		AIUnitState.MarkCorpseSeen(UnitRef.ObjectID);
		break;

	case eGameRule_AIRevealWait:
		`assert(AIRef.ObjectID > 0 && UnitRef.ObjectID > 0);
		NewGameState = History.CreateNewGameState(true, self);		
		UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
		UpdatedUnitState.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.StandardActionPoint);//Add action point for this unit
		break;

	case eGameRule_DemoStart:
		// simple placeholder states
		NewGameState = History.CreateNewGameState(true, self);
		break;

	case eGameRule_ForceSyncVisualizers:
		NewGameState = History.CreateNewGameState(true, self);
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
		}
		break;
	case eGameRule_SyncTileLocationToCorpse:
		NewGameState = History.CreateNewGameState(true, self);
		UnitVisualizer = XGUnit(History.GetVisualizer(UnitRef.ObjectID));
		if (UnitVisualizer != none)
		{
			TestLocation = UnitVisualizer.Location + vect(0, 0, 64);
			if (`XWORLD.GetFloorTileForPosition(TestLocation, FloorTile))
			{
				UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
				UpdatedUnitState.SetVisibilityLocation(FloorTile);
			}
		}
		break;	
	case eGameRule_RoomCleared:

		//We must play after the visualization of the event that triggered us ( avoids this accidentally visualizing as part of an interrupt sequence )
		SetAssociatedPlayTiming(SPT_AfterSequential);

		// simple placeholder states
		NewGameState = History.CreateNewGameState(true, self);
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
		BattleData.bRoomCleared = true;
		bUnitHealed = false;

		// re-enable CoordinatedAssault
		if (`TACTICALRULES.bResetCoordinatedAssaultCooldownEachBreach)
		{
			class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('CoordinatedAssault', true, NewGameState);
		}

		// reload all active soldier weapons
		foreach History.IterateByClassType(class'XComGameState_Unit', XComSquadMemberState)
		{
			if (XComSquadMemberState == None || XComSquadMemberState.GetTeam() != eTeam_XCom || XComSquadMemberState.bRemovedFromPlay || XComSquadMemberState.GetMyTemplate().bIsCosmetic)
				continue;
			if (XComSquadMemberState.IsAlive() && !XComSquadMemberState.IsUnconscious())
			{
				// reload all weapons
				WeaponState = XComSquadMemberState.GetPrimaryWeapon();
				if (WeaponState != none)
				{
					WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', WeaponState.ObjectID));
					WeaponState.Ammo = WeaponState.GetClipSize();
				}
				WeaponState = XComSquadMemberState.GetSecondaryWeapon();
				if (WeaponState != none)
				{
					WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', WeaponState.ObjectID));
					WeaponState.Ammo = WeaponState.GetClipSize();
				}

				if (XComSquadMemberState.HasSoldierAbility('ImprovisedExplosives'))
				{
					DemoExpertUtilityItems = XComSquadMemberState.GetAllItemsInSlot(eInvSlot_Utility);
					foreach DemoExpertUtilityItems(UtilityItem)
					{
						if (UtilityItem.GetMyTemplate().ItemCat == 'grenade' && UtilityItem.Ammo == 0)
						{
							UtilityItem = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', UtilityItem.ObjectID));
							UtilityItem.Ammo = 1;
						}
					}
				}

				// heal XCOM units to half HP after each encounter
				UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', XComSquadMemberState.ObjectID));
				OldHP = UpdatedUnitState.GetCurrentStat(eStat_HP);
				NewHP = OldHP;
				if (CampaignSettings.bFullHealSquadPostEncounter)
				{
					NewHP = UpdatedUnitState.GetMaxStat(eStat_HP);
					UpdatedUnitState.SetCurrentStat(eStat_HP, NewHP);
				}
				else if (CampaignSettings.bHalfHealSquadPostEncounter)
				{
					NewHP = Max(UpdatedUnitState.GetCurrentStat(eStat_HP), UpdatedUnitState.GetMaxStat(eStat_HP) / 2);
					UpdatedUnitState.SetCurrentStat(eStat_HP, NewHP);
				}
				bUnitHealed = (bUnitHealed || (OldHP != NewHP));

				XComUnitStates.AddItem(UpdatedUnitState);
			}
			else
			{
				// remove dead and unconscious units from play
				UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', XComSquadMemberState.ObjectID));
				UpdatedUnitState.RemoveStateFromPlay();
			}
		}

		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState, eReturnType_Reference)
		{
			PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID, eReturnType_Reference));
			
			//Need to consider MindControlled units when finding enemies
			if (PlayerState != None)
			{
				if ((!UnitState.IsMindControlled() && PlayerState.TeamFlag == ETeam.eTeam_XCom) || (UnitState.IsMindControlled() && PlayerState.TeamFlag != ETeam.eTeam_XCom))
				{
					if (UnitState.GhostSourceUnit.ObjectID == 0) //ghosts are always destroyed
					{
						continue;
					}
				}
			}
			// Kill all enemies in the current room
			if (UnitState.AssignedToRoomID == BattleData.BreachingRoomID)
			{
				UpdatedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));

				// If unconscious, capture for possible reward
				if (UpdatedUnitState.IsUnconscious())
				{
					EnemyRef.ObjectID = UnitState.ObjectID;
					if (BattleData.CapturedUnconsciousUnits.Find('ObjectID', UnitState.ObjectID) == INDEX_NONE)
					{
						BattleData.CapturedUnconsciousUnits.AddItem(EnemyRef);
					}
				}
				// If a dead civilian, track count for possible Unrest penalty
				if (UpdatedUnitState.IsCivilian() && !UpdatedUnitState.IsAlive())
				{
					BattleData.NumKilledCivilians++;
					`XEVENTMGR.TriggerEvent('CivilianKilled', UpdatedUnitState, UpdatedUnitState, NewGameState);
				}

				NumEffects = UpdatedUnitState.AffectedByEffects.Length;
				for (EffectIndex = NumEffects - 1; EffectIndex >= 0; --EffectIndex)
				{
					EffectRef = UpdatedUnitState.AffectedByEffects[EffectIndex];
					EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
					EffectState.RemoveEffect(NewGameState, NewGameState, true); //Cleansed
				}
				UpdatedUnitState.RemoveStateFromPlay();
				`XWORLD.ClearTileBlockedByUnitFlag(UpdatedUnitState);
			}
		}

		BreachDataState = XComGameState_BreachData(History.GetSingleGameStateObjectForClass(class'XComGameState_BreachData', false));
		BreachDataState = XComGameState_BreachData(NewGameState.ModifyStateObject(BreachDataState.Class, BreachDataState.ObjectID));
		BreachDataState.CachedBreachPointInfos.Length = 0;	// Clear breach information
		BreachDataState.BreachGroupIDSequence.Length = 0;	// Clear breach information

		DioHQ = XComGameState_HeadquartersDio(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio'));
		if (DioHQ.TacticalGameplayTags.Find(class'XComGameStateContext_LaunchTutorialMission'.default.TutorialMissionGamePlayTag) != INDEX_NONE)
		{
			class'XComGameStateContext_LaunchTutorialMission'.static.FillOutGameState_RoomCleared(NewGameState, BattleData);
		}

		// spawn units in the next encounter
		if (BattleData.HasRemainingRoomsToBreach())
		{
			`SPAWNMGR.SpawnEncounterInRoom(NewGameState, BattleData.MapData.RoomIDs[BattleData.BreachingRoomListIndex+1]);
		}

		foreach XComUnitStates(XComSquadMemberState)
		{
			NumEffects = XComSquadMemberState.AffectedByEffects.Length;
			for (EffectIndex = NumEffects - 1; EffectIndex >= 0; --EffectIndex)
			{
				EffectRef = XComSquadMemberState.AffectedByEffects[EffectIndex];
				EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
				PersistentEffect = EffectState.GetX2Effect();
				if (PersistentEffect != none && PersistentEffect.WatchRule != eWatchRule_TacticalGameStart
					&& PersistentEffect.WatchRule != eWatchRule_RoomCleared && !PersistentEffect.bInfiniteDuration && !PersistentEffect.bPersistThroughRoomClear && !EffectState.bRemoved)
				{
					EffectState.RemoveEffect(NewGameState, NewGameState, true); //Cleansed
				}
			}
		}

		`XEVENTMGR.TriggerEvent('EncounterEnd',,NewGameState);
		if( bUnitHealed )
		{
			`XEVENTMGR.TriggerEvent('UnitHealedDuringEncounterEnd',,NewGameState);
		}

		break;
	case eGameRule_RoundBegin:
		NewGameState = History.CreateNewGameState(true, self);
		break;

	case eGameRule_BreachSequencCommence:
		//Finalize enemy intents based upon XCom Breach Point Assignment
		NewGameState = History.CreateNewGameState(true, self);
		class'XComBreachHelpers'.static.RecalculateEnemyIntentsAfterXComAssignment(NewGameState);
		break;
	}

	return NewGameState;
}

function XComGameState BuildTacticalGameEndGameState()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_Unit IterateUnitState;
	local XComGameState_Unit NewUnitState;
	local XComGameState_Player VictoriousPlayer;
	local XComGameState_BattleData BattleData, NewBattleData;
	local StateObjectReference LocalPlayerRef;
	local bool bLastTutorialEncounter;

	History = `XCOMHISTORY;

	NewGameState = History.CreateNewGameState(true, self);

	VictoriousPlayer = XComGameState_Player(History.GetGameStateForObjectID(PlayerRef.ObjectID));
	if (VictoriousPlayer == none && bAborted == false)
	{
		`RedScreen("Battle ended without a winner. This should not happen.");
	}

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`assert(BattleData != none);
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	LocalPlayerRef = XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController()).ControllingPlayer;
	NewBattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(BattleData.Class, BattleData.ObjectID));
	NewBattleData.bMissionAborted = bAborted;	
	NewBattleData.SetVictoriousPlayer(VictoriousPlayer, VictoriousPlayer.ObjectID == LocalPlayerRef.ObjectID);
	NewBattleData.AwardTacticalGameEndBonuses(NewGameState);
	++NewBattleData.EndBattleRuns;

	bLastTutorialEncounter = `DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive_Room_2') != INDEX_NONE;

	// Skip all turns 
	foreach History.IterateByClassType(class'XComGameState_Unit', IterateUnitState)
	{
		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', IterateUnitState.ObjectID));
        NewUnitState.ActionPoints.Length = 0;

		// Capture leftover unconscious enemies
		if (NewUnitState.IsCapturedOnEndBattle())
		{
			if (BattleData.CapturedUnconsciousUnits.Find('ObjectID', NewUnitState.ObjectID) == INDEX_NONE)
			{
				BattleData.CapturedUnconsciousUnits.AddItem(NewUnitState.GetReference());
			}
		}

		// 
		// in the last encounter of the tutorial mission, 
		// Cherub will be bleeding out but we need him to talk at the end of the encounter
		if (bLastTutorialEncounter)
		{
			if (NewUnitState.GetMyTemplateName() == 'XcomWarden'
				|| NewUnitState.GetMyTemplateName() == 'XcomMedic'
				|| NewUnitState.GetMyTemplateName() == 'XcomRanger'
				|| NewUnitState.GetMyTemplateName() == 'XcomEnvoy'
				|| NewUnitState.GetMyTemplateName() == 'Mayor')
			{
				NewUnitState.bForceValidSpeaker = true;
			}
		}
	}

	// notify of end game state
	`XEVENTMGR.TriggerEvent('TacticalGameEnd',,NewGameState);

	return NewGameState;
}

function XComGameState BuildUnitChangedTeamGameState()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState;
	local XComGameState_AIGroup OldGroupState, NewGroupState;
	local X2TacticalGameRuleset Rules;
	local XComGameState_BattleData BattleData;
	local ETeam OldTeam, NewTeam;
	local XComGameState_Player PlayerState;
	local XComGameState_AIPlayerData kAIData;
	local int iAIDataID, i;
	local bool bWasNeutral, bIsNeutral;

	History = `XCOMHISTORY;

	NewGameState = History.CreateNewGameState(true, self);
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
	//save the previous Group
	iAIDataID = UnitState.GetAIPlayerDataID(true);
	OldGroupState = UnitState.GetGroupMembership();
	OldTeam = OldGroupState.TeamName;

	UnitState.SetControllingPlayer(PlayerRef);
	UnitState.OnSwappedTeams(PlayerRef);

	//make a new group if going from Neutral to xcom or alien
	PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID, eReturnType_Reference));
	NewTeam = PlayerState.TeamFlag;

	bWasNeutral = ( OldTeam != eTeam_XCom && OldTeam != eTeam_Alien );
	bIsNeutral = ( NewTeam != eTeam_XCom && NewTeam != eTeam_Alien );

	Rules = `TACTICALRULES;
	//handle a civilian going to a xcom or alien team using interleaved turns
	if( Rules != None && Rules.bInterleaveInitiativeTurns && bWasNeutral != bIsNeutral )
	{
		kAIData = XComGameState_AIPlayerData(NewGameState.ModifyStateObject(class'XComGameState_AIPlayerData', iAIDataID));
		kAIData.RemoveFromCurrentGroup( UnitState.GetReference(), NewGameState );
			
		NewGroupState = XComGameState_AIGroup(NewGameState.CreateNewStateObject(class'XComGameState_AIGroup'));
		NewGroupState.AddUnitToGroup(UnitState.ObjectID, NewGameState);
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		if( BattleData.PlayerTurnOrder.Find('ObjectID', NewGroupState.ObjectID) == INDEX_NONE )
		{
			Rules.AddGroupToInitiativeOrder(NewGroupState, NewGameState, true); //this handles groups already in InitativeOrder
		}
		//dakota.lemaster (9.5.19) Grant an action point to civilians the turn they are given to xcom
		if (NewTeam == eTeam_XCom)
		{
			for (i = 0; i < class'X2TacticalGameRuleset'.default.NumActionsToGrantVIPJoiningXCom; ++i)
			{
				UnitState.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.StandardActionPoint);
			}
			if (class'X2TacticalGameRuleset'.default.NumActionsToGrantVIPJoiningXCom > 0)
			{
				UnitState.SetUnitFloatValue('MovesThisTurn', 0, eCleanup_BeginTurn);
				UnitState.SetUnitFloatValue('MetersMovedThisTurn', 0, eCleanup_BeginTurn);
			}
		}
	}

	return NewGameState;
}

/// <summary>
/// Convert the ResultContext and AssociatedState into a set of visualization tracks
/// </summary>
protected function ContextBuildVisualization()
{	
	local XComGameState_BattleData BattleState;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;
	local X2Action_UpdateUI UpdateBreachUIAction;

	if( bSkipVisualization )
	{
		return;
	}

	History = `XCOMHISTORY;

	//Process Units
	switch(GameRuleType)
	{			
	case eGameRule_TacticalGameStart :
		SyncAllVisualizers();

		BattleState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		
		//Use the battle state object for the following actions:
		ActionMetadata.StateObject_OldState = BattleState;
		ActionMetadata.StateObject_NewState = BattleState;
		ActionMetadata.VisualizeActor = none;

		class'X2Action_SyncMapVisualizers'.static.AddToVisualizationTree(ActionMetadata, self);
		class'X2Action_InitCamera'.static.AddToVisualizationTree(ActionMetadata, self);		
		class'X2Action_InitFOW'.static.AddToVisualizationTree(ActionMetadata, self);		
		class'X2Action_InitUI'.static.AddToVisualizationTree(ActionMetadata, self);
		class'X2Action_StartMissionSoundtrack'.static.AddToVisualizationTree(ActionMetadata, self);				

		// only run the mission intro in single player.
		//	we'll probably want an MP mission intro at some point...
		if( `XENGINE.IsSinglePlayerGame() && !class'X2TacticalGameRulesetDataStructures'.static.TacticalOnlyGameMode( ) && !`DIO_SKIP_MISSION_INTRO)
		{
			//Only add the intro track(s) if this start state is current ( ie. we are not visualizing a saved game load )
			if( AssociatedState == History.GetStartState() && 
				BattleState.MapData.PlotMapName != "" &&
				`XWORLDINFO.IsPlayInEditor() != true &&
				BattleState.bIntendedForReloadLevel == false)
			{	
				class'X2Action_HideLoadingScreen'.static.AddToVisualizationTree(ActionMetadata, self);

				if(`TACTICALMISSIONMGR.GetActiveMissionIntroDefinition().MatineePackage != "")
				{
					class'X2Action_DropshipIntro'.static.AddToVisualizationTree(ActionMetadata, self);
					class'X2Action_UnstreamDropshipIntro'.static.AddToVisualizationTree(ActionMetadata, self);
				}
				else
				{
					// if there is no dropship intro, we need to manually clear the camera fade
					class'X2Action_ClearCameraFade'.static.AddToVisualizationTree(ActionMetadata, self);
				}
			}
		}
		else
		{			
			class'X2Action_HideLoadingScreen'.static.AddToVisualizationTree(ActionMetadata, self);
			class'X2Action_ClearCameraFade'.static.AddToVisualizationTree(ActionMetadata, self);
		}

		

		break;
	case eGameRule_ReplaySync:		
		SyncAllVisualizers();
		break;
	case eGameRule_UnitAdded:
		BuildUnitAddedVisualization();
		break;
	case eGameRule_UnitChangedTeams:
		BuildUnitChangedTeamVisualization();
		break;

	case eGameRule_PlayerTurnEnd:
		BuildPlayerTurnEndVisualization();
		break;
	case eGameRule_PlayerTurnBegin:
		BuildPlayerTurnBeginVisualization();
		break;
	case eGameRule_UnitGroupTurnEnd:
		BuildGroupTurnEndVisualization();
		break;
	case eGameRule_UnitGroupTurnBegin:
		BuildGroupTurnBeginVisualization();
		break;

	case eGameRule_ForceSyncVisualizers:
		SyncAllVisualizers();
		break;

	case eGameRule_RoomCleared:
		BuildRoomClearedVisualizer();
		break;

	case eGameRule_BeginBreachMode:
		BuildBeginBreachModeVisualizer();
		break;
	case eGameRule_EndBreachMode:
		BuildEndBreachModeVisualizer();
		break;
	case eGameRule_BreachSequencCommence:
		BattleState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

		//Use the battle state object for the following actions:
		ActionMetadata.StateObject_OldState = BattleState;
		ActionMetadata.StateObject_NewState = BattleState;
		ActionMetadata.VisualizeActor = none;
		// Hide the breach ui for the sequence
		UpdateBreachUIAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self));
		UpdateBreachUIAction.UpdateType = EUIUT_BeginBreachSequence;
		break;
	}
}

private function BuildPlayerTurnEndVisualization()
{
	local X2Action_UpdateUI UIUpdateAction;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;
	//local XComGameState_Player TurnEndingPlayer;

	History = `XCOMHISTORY;

	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(PlayerRef.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex);
	ActionMetadata.StateObject_NewState = ActionMetadata.StateObject_OldState;
	ActionMetadata.VisualizeActor = History.GetVisualizer(PlayerRef.ObjectID);

	// Try to do a soldier reaction, and if nothing to react to, check if there is any hidden movement
	//if(!class'X2Action_EndOfTurnSoldierReaction'.static.AddReactionToBlock(self))
	//{
	//	TurnEndingPlayer = XComGameState_Player(History.GetGameStateForObjectID(PlayerRef.ObjectID));
	//	if(TurnEndingPlayer != none 
	//		&& TurnEndingPlayer.GetTeam() == eTeam_XCom
	//		&& TurnEndingPlayer.TurnsSinceEnemySeen >= class'X2Action_HiddenMovement'.default.TurnsUntilIndicator)
	//	{
	//		class'X2Action_HiddenMovement'.static.AddHiddenMovementActionToBlock(AssociatedState);
	//	}
	//}
	//
	UIUpdateAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self));
	UIUpdateAction.SpecificID = PlayerRef.ObjectID;
	UIUpdateAction.UpdateType = EUIUT_EndTurn;
}

private function BuildPlayerTurnBeginVisualization()
{
	local X2Action_UpdateUI UIUpdateAction;
	//local VisualizationActionMetadata EmptyTrack;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;

	//local XComGameState_Unit IterateUnitState;
	//local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
	//local X2Action_WaitForAbilityEffect WaitAction;
	//local XComGameState_Player TurnStartingPlayer;
	//local float Radius;
	//local float WaitDuration;


	History = `XCOMHISTORY;

	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(PlayerRef.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex);
	ActionMetadata.StateObject_NewState = ActionMetadata.StateObject_OldState;
	ActionMetadata.VisualizeActor = History.GetVisualizer(PlayerRef.ObjectID);

	UIUpdateAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self));
	UIUpdateAction.SpecificID = PlayerRef.ObjectID;
	UIUpdateAction.UpdateType = EUIUT_BeginTurn;


	// For each unit on the current player's team, test if that unit is next to a tile
	// that is on fire, and if so, show a flyover for that unit.  mdomowicz 2015_07_20
	//TurnStartingPlayer = XComGameState_Player(History.GetGameStateForObjectID(PlayerRef.ObjectID));
	//if ( TurnStartingPlayer != none && TurnStartingPlayer.GetTeam() == eTeam_XCom )
	//{
	//	WaitDuration = 0.1f;
	//
	//	foreach History.IterateByClassType(class'XComGameState_Unit', IterateUnitState)
	//	{
	//		if (IterateUnitState.IsImmuneToDamage('Fire') || IterateUnitState.bRemovedFromPlay)
	//			continue;
	//
	//		if ( IterateUnitState.GetTeam() == eTeam_XCom )
	//		{
	//			Radius = 2.0;
	//			if ( IsFireInRadiusOfUnit( Radius, XGUnit(IterateUnitState.GetVisualizer())) )
	//			{
	//				// Setup a new track for the unit
	//				ActionMetadata = EmptyTrack;
	//				ActionMetadata.StateObject_OldState = IterateUnitState;
	//				ActionMetadata.StateObject_NewState = IterateUnitState;
	//				ActionMetadata.VisualizeActor = IterateUnitState.GetVisualizer();
	//
	//				// Add a wait action to the Metadata.
	//				WaitAction = X2Action_WaitForAbilityEffect(class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetadata, self));
	//				WaitAction.ChangeTimeoutLength(WaitDuration);
	//				WaitDuration += 2.0f;
	//
	//				// Then add a flyover to the Metadata.
	//				SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, self));
	//				SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", 'ObjectFireSpreading', eColor_Bad, "", 1.0f, true, eTeam_None);
	//
	//
	//				// Then submit the Metadata.
	//				
	//			}
	//		}
	//	}
	//}
}

private function BuildGroupTurnEndVisualization()
{
	local X2Action_UpdateUI UIUpdateAction;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(PlayerRef.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex);
	ActionMetadata.StateObject_NewState = ActionMetadata.StateObject_OldState;
	ActionMetadata.VisualizeActor = History.GetVisualizer(PlayerRef.ObjectID);

	UIUpdateAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self));
	UIUpdateAction.SpecificID = PlayerRef.ObjectID;
	UIUpdateAction.UpdateType = EUIUT_EndTurn;
}

private function BuildGroupTurnBeginVisualization()
{
	local X2Action_UpdateUI UIUpdateAction;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;
	local X2Action_PlaySoundAndFlyOver VOAction;
	local XComGameState_Unit OutActiveUnit;

	History = `XCOMHISTORY;

	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(PlayerRef.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex);
	ActionMetadata.StateObject_NewState = ActionMetadata.StateObject_OldState;
	ActionMetadata.VisualizeActor = History.GetVisualizer(PlayerRef.ObjectID);

	UIUpdateAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self));
	UIUpdateAction.SpecificID = PlayerRef.ObjectID;
	UIUpdateAction.UpdateType = EUIUT_BeginTurn;

	`TACTICALRULES.GetCurrentInitiativeGroup(OutActiveUnit);
	if (OutActiveUnit != none)
	{
		ActionMetadata.StateObject_OldState = OutActiveUnit;
		ActionMetadata.StateObject_NewState = OutActiveUnit;
		ActionMetadata.VisualizeActor = OutActiveUnit.GetVisualizer();

		VOAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, self));
		VOAction.SetSoundAndFlyOverParameters(None, "", 'StatTurnBegin', eColor_Xcom);
	}
}

// This function is based off the implementation of TeamInRadiusOfUnit() in 
// XComWorlData.uc   mdomowicz 2015_07_20
function bool IsFireInRadiusOfUnit( int tile_radius, XGUnit Unit)
{
	local XComWorldData WorldData;
	local array<TilePosPair> OutTiles;
	local float Radius;
	local vector Location;
	local TilePosPair TilePair;
	local TTile TileLocation;

	WorldData = `XWORLD;

	Radius = tile_radius * WorldData.WORLD_StepSize;

	Location = Unit.Location;
	Location.Z += tile_radius * WorldData.WORLD_FloorHeight;

	TileLocation = WorldData.GetTileCoordinatesFromPosition( Unit.Location );

	WorldData.CollectFloorTilesBelowDisc( OutTiles, Location, Radius );

	foreach OutTiles( TilePair )
	{
		if (abs( TilePair.Tile.Z - TileLocation.Z ) > tile_radius)
		{
			continue;
		}

		if ( WorldData.TileContainsFire( TilePair.Tile ) )
		{
			return true;
		}
	}

	return false;
}

private function BuildUnitAddedVisualization()
{
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;
	
	History = `XCOMHISTORY;

	if( UnitRef.ObjectID != 0 )
	{
		ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(UnitRef.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex);
		ActionMetadata.StateObject_NewState = ActionMetadata.StateObject_OldState;
		ActionMetadata.VisualizeActor = History.GetVisualizer(UnitRef.ObjectID);
		class'X2Action_ShowSpawnedUnit'.static.AddToVisualizationTree(ActionMetadata, self);
		
	}
	else
	{
		`Redscreen("Added unit but no unit state specified! Talk to David B.");
	}
}

private function BuildUnitChangedTeamVisualization()
{
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;
	local X2Action_SelectNextActiveUnit	SelectUnitAction;
	local XComGameState_Unit OldUnitState, NewUnitState;
	local ETeam OldTeam, NewTeam;
	local XComGameState_Player OldPlayerState, NewPlayerState;
	local X2TacticalGameRuleset Rules;
	local bool bWasNeutral, bIsNeutral;
	
	History = `XCOMHISTORY;
	Rules = `TACTICALRULES;

	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(UnitRef.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex - 1);
	ActionMetadata.StateObject_NewState = History.GetGameStateForObjectID(UnitRef.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex);
	OldUnitState = XComGameState_Unit(ActionMetadata.StateObject_OldState);
	NewUnitState = XComGameState_Unit(ActionMetadata.StateObject_NewState);
	OldPlayerState = XComGameState_Player(History.GetGameStateForObjectID(OldUnitState.ControllingPlayer.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex - 1));
	OldTeam = OldPlayerState.TeamFlag;
	NewPlayerState = XComGameState_Player(History.GetGameStateForObjectID(NewUnitState.ControllingPlayer.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex));
	NewTeam = NewPlayerState.TeamFlag;
	bWasNeutral = (OldTeam != eTeam_XCom && OldTeam != eTeam_Alien);
	bIsNeutral = (NewTeam != eTeam_XCom && NewTeam != eTeam_Alien);

	SetAssociatedPlayTiming(SPT_AfterSequential);

	class'X2Action_SwapTeams'.static.AddToVisualizationTree(ActionMetadata, self);
		
	//dakota.lemaster (9.5.19): Grant an action points to civilians joining xcom, select immediately
	if (Rules != None && Rules.bInterleaveInitiativeTurns && bWasNeutral != bIsNeutral && class'X2TacticalGameRuleset'.default.NumActionsToGrantVIPJoiningXCom > 0)
	{
		if (NewTeam == eTeam_XCom)
		{
			SelectUnitAction = X2Action_SelectNextActiveUnit(class'X2Action_SelectNextActiveUnit'.static.AddToVisualizationTree(ActionMetadata, self));
			SelectUnitAction.TargetID = ActionMetadata.StateObject_NewState.ObjectID;
		}
	}
}

private function SyncAllVisualizers()
{
	local VisualizationActionMetadata EmptyTrack;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameState_BaseObject VisualizedObject;
	local XComGameStateHistory History;
	local XComGameState_AIPlayerData AIPlayerDataState;
	local XGAIPlayer kAIPlayer;
	local X2Action_SyncMapVisualizers MapVisualizer;
	local XComGameState_BattleData BattleState;

	History = `XCOMHISTORY;

	// Sync the map first so that the tile data is in the proper state for all the individual SyncVisualizer calls
	BattleState = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	ActionMetadata = EmptyTrack;
	ActionMetadata.StateObject_OldState = BattleState;
	ActionMetadata.StateObject_NewState = BattleState;
	MapVisualizer = X2Action_SyncMapVisualizers( class'X2Action_SyncMapVisualizers'.static.AddToVisualizationTree( ActionMetadata, self ) );
	
	MapVisualizer.Syncing = true;

	// Jwats: First create all the visualizers so the sync actions have access to them for metadata
	foreach AssociatedState.IterateByClassType(class'XComGameState_BaseObject', VisualizedObject)
	{
		if( X2VisualizedInterface(VisualizedObject) != none )
		{
			X2VisualizedInterface(VisualizedObject).FindOrCreateVisualizer();
		}
	}

	foreach AssociatedState.IterateByClassType(class'XComGameState_BaseObject', VisualizedObject)
	{
		if(X2VisualizedInterface(VisualizedObject) != none)
		{
			ActionMetadata = EmptyTrack;
			ActionMetadata.StateObject_OldState = VisualizedObject;
			ActionMetadata.StateObject_NewState = ActionMetadata.StateObject_OldState;
			ActionMetadata.VisualizeActor = History.GetVisualizer(ActionMetadata.StateObject_NewState.ObjectID);
			class'X2Action_SyncVisualizer'.static.AddToVisualizationTree(ActionMetadata, self).ForceImmediateTimeout();
		}
	}

	// Jwats: Once all the visualizers are in their default state allow the additional sync actions run to manipulate them
	foreach AssociatedState.IterateByClassType(class'XComGameState_BaseObject', VisualizedObject)
	{
		if( X2VisualizedInterface(VisualizedObject) != none )
		{
			ActionMetadata = EmptyTrack;
			ActionMetadata.StateObject_OldState = VisualizedObject;
			ActionMetadata.StateObject_NewState = ActionMetadata.StateObject_OldState;
			ActionMetadata.VisualizeActor = History.GetVisualizer(ActionMetadata.StateObject_NewState.ObjectID);
			X2VisualizedInterface(VisualizedObject).AppendAdditionalSyncActions(ActionMetadata, self);
		}
	}

	kAIPlayer = XGAIPlayer(`BATTLE.GetAIPlayer());
	if (kAIPlayer.m_iDataID == 0)
	{
		foreach AssociatedState.IterateByClassType(class'XComGameState_AIPlayerData', AIPlayerDataState)
		{
			kAIPlayer.m_iDataID = AIPlayerDataState.ObjectID;
			break;
		}
	}
}

private function BuildRoomClearedVisualizer()
{
	local VisualizationActionMetadata EmptyTrack;
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateHistory History;
	local XComGameState_MissionSite Mission;

	local XComGameState_Unit XComSquadMemberState;
	local XComGameState_Unit UnitState, OldUnitState;
	local XComGameState_BattleData BattleData;

	local X2Action_PlayAnimation PlayAnimAction;
	local X2Action BeginMarker;
	local X2Action_Delay DelayAction;
	local X2Action_MarkerNamed JoinAction;
	local array<X2Action> LeafNodes;

	local XComWeapon WeaponArchetype;
	local XComGameState_Item SourceWeaponState;
	local XComGameState_HeadquartersDio DioHQ;

	// narrative moments at the end of an encounter
	local X2Action_PlayNarrative NarrativeAction;
	local int NarrativeMomentIndex;
	local XComTacticalMissionManager MissionManager;
	local X2MissionNarrativeTemplateManager NarrativeTemplateManager;
	local X2MissionNarrativeTemplate NarrativeTemplate;
	local string NarrativeMomentPath;

	// vo at the end of an encounter
	local X2Action EncounterEndDialogParentAction;
	local X2Action_PlaySoundAndFlyOver VOAction;
	local int i;
	local X2BackUpUnitData BackupUnitData;

	local X2Action_YawCamera OrientBreachCameraAction;
	local int NextRoomID;

	local X2Action_UpdateUI UpdateUIAction;	
	local X2Action_CameraFramePOIs LookAtAgentsAction;

	History = `XCOMHISTORY;
	DioHQ = XComGameState_HeadquartersDio(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio', true));
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	Mission = XComGameState_MissionSite(History.GetGameStateForObjectID(DioHQ.MissionRef.ObjectID));
	
	`XCOMVISUALIZATIONMGR.GetAllLeafNodes(`XCOMVISUALIZATIONMGR.VisualizationTree, LeafNodes);
	BeginMarker = class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, self, , ,LeafNodes);

	NextRoomID = BattleData.GetNextRoomIDInSequence();

	if (NextRoomID != -1)
	{
		OrientBreachCameraAction = X2Action_YawCamera(class'X2Action_YawCamera'.static.AddToVisualizationTree(ActionMetadata, self, false, BeginMarker));
		// can make this into its own action, just make sure the rotation calculation is done when the action is actually executing
		// otherwise might pick up some random camera that's currently active for target rot calculation
		//OrientBreachCameraAction.RotInDeg = class'X2Action_InitBreachCamera'.static.GetBreachCameraYawForRoom(NextRoomID);
		OrientBreachCameraAction.bOrientForBreach = true;
		OrientBreachCameraAction.BreachingRoomID = NextRoomID;
	}

	UpdateUIAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self, false, BeginMarker));
	UpdateUIAction.UpdateType = EUIUT_BreachHideTacticalHUD;

	LookAtAgentsAction = X2Action_CameraFramePOIs(class'X2Action_CameraFramePOIs'.static.AddToVisualizationTree(ActionMetadata, self, false, BeginMarker));
	// duration set to infinite here because we need this camera to stay active until we start the preview transition
	// otherwise, the FollowCursor cam can take over and look at some werid spots because it gets clamp within the encounter
	LookAtAgentsAction.LookAtDuration = -1; 

	LookAtAgentsAction.CameraTag = 'PostBreachFrameSquadCam';

	foreach History.IterateByClassType(class'XComGameState_Unit', XComSquadMemberState)
	{
		if (XComSquadMemberState == None || XComSquadMemberState.GetTeam() != eTeam_XCom || XComSquadMemberState.bRemovedFromPlay || XComSquadMemberState.GetMyTemplate().bIsCosmetic)
			continue;
		if (XComSquadMemberState.IsAlive() && !XComSquadMemberState.IsUnconscious())
		{
			// insert reload anim node
			ActionMetadata = EmptyTrack;
			ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(XComSquadMemberState.ObjectID, eReturnType_Reference, AssociatedState.HistoryIndex - 1);
			ActionMetadata.StateObject_NewState = XComSquadMemberState;
			ActionMetadata.VisualizeActor = History.GetVisualizer(XComSquadMemberState.ObjectID);

			PlayAnimAction = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, self, false, OrientBreachCameraAction != none ? OrientBreachCameraAction : BeginMarker));
			PlayAnimAction.Params.AnimName = 'HL_Reload';

			//Assign the reload animation from the weapon archetype if possible
			SourceWeaponState = XComSquadMemberState.GetPrimaryWeapon();
			SourceWeaponState = XComGameState_Item(History.GetGameStateForObjectID(SourceWeaponState.ObjectID));
			if (SourceWeaponState != none)
			{	
				WeaponArchetype = XComWeapon(XGUnitNativeBase(ActionMetadata.VisualizeActor).GetPawn().Weapon);
				if (WeaponArchetype != none && WeaponArchetype.WeaponReloadAnimSequenceName != '')
				{
					PlayAnimAction.Params.AnimName = WeaponArchetype.WeaponReloadAnimSequenceName;
				}
			}

			// add to POI framing
			LookAtAgentsAction.FocusActors.AddItem(XComSquadMemberState.GetVisualizer());
		}
	}

	// we spawn enemy units for the next encounter during room clear context change 
	// make sure their vis are ready
	foreach AssociatedState.IterateByClassType(class'XComGameState_Unit', UnitState, eReturnType_Reference)
	{
		// making sure to only sync the newly spawned units
		// otherwise syncvis could trigger visibility update for units that are currently getting shot and make them disappear too soon
		if (UnitState.AssignedToRoomID == BattleData.GetNextRoomIDInSequence())
		{
			ActionMetadata = EmptyTrack;
			ActionMetadata.StateObject_OldState = UnitState;
			ActionMetadata.StateObject_NewState = UnitState;
			class'X2Action_SyncVisualizer'.static.AddToVisualizationTree(ActionMetadata, self);
		}
	}

	class'X2Action_WaitForVO'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded);

	// add a join for all leaf nodes, then add a delay	
	`XCOMVISUALIZATIONMGR.GetAllLeafNodes(BeginMarker, LeafNodes);

	LeafNodes.RemoveItem(LookAtAgentsAction); // no need to wait for this node, will be removed during breach begin vis

	// Add Named Marker so we can identify this in the visualization tree
	JoinAction = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, self, false, none, LeafNodes));
	JoinAction.SetName("RoomClearedJoin");

	DelayAction = X2Action_Delay(class'X2Action_Delay'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
	DelayAction.Duration = class'X2TacticalGameRuleset'.default.RoomClearedPostReloadDelay;

	EncounterEndDialogParentAction = DelayAction;

	//DIOTUTORIAL: See if any narrative moments should be played
	if (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive') != INDEX_NONE)
	{
		NarrativeMomentIndex = -1;
		if (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive_Room_0') != INDEX_NONE)
		{
			NarrativeMomentIndex = 0;
		}
		else if (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive_Room_1') != INDEX_NONE)
		{
			//NarrativeMomentIndex = 1; //dakota.lemaster (8.16.19) Current script calls for no movie between second and third breaches
		}
		if (NarrativeMomentIndex >= 0)
		{
			MissionManager = `TACTICALMISSIONMGR;
			NarrativeTemplateManager = class'X2MissionNarrativeTemplateManager'.static.GetMissionNarrativeTemplateManager();
			NarrativeTemplate = NarrativeTemplateManager.FindMissionNarrativeTemplate(MissionManager.ActiveMission.sType, MissionManager.MissionQuestItemTemplate);

			if (NarrativeTemplate != none && NarrativeMomentIndex < NarrativeTemplate.NarrativeMoments.Length)
			{
				NarrativeMomentPath = NarrativeTemplate.NarrativeMoments[NarrativeMomentIndex];
				
				NarrativeAction = X2Action_PlayNarrative(class'X2Action_PlayNarrative'.static.AddToVisualizationTree(ActionMetadata, self));
				NarrativeAction.Moment = XComNarrativeMoment(DynamicLoadObject(NarrativeMomentPath, class'XComNarrativeMoment'));
				NarrativeAction.WaitForCompletion = true;
				NarrativeAction.StopExistingNarrative = true;

				EncounterEndDialogParentAction = NarrativeAction;
			}
		}

		// Trigger any COPS post matinee
		if (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive_Room_0') != INDEX_NONE)
		{
			// always try to trigger whisper VO first. if there is a valid line, will stop the following squad member VO from triggering
			ActionMetadata = EmptyTrack;
			VOAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, self, false, EncounterEndDialogParentAction));
			VOAction.SetSoundAndFlyOverParameters(None, "", 'EvntTutorialVerge', eColor_Xcom);

			for (i = 0; i < Mission.BackUpUnits.length; i++)
			{
				BackupUnitData = Mission.BackUpUnits[i];
				if (BackupUnitData.AvailableAtEncounterIndex == BattleData.BreachingRoomListIndex + 1) //+1 to look ahead and find Verge since he is a backup for the next encounter
				{
					OldUnitState = XComGameState_Unit(History.GetGameStateForObjectID(BackupUnitData.UnitRef.ObjectID, , AssociatedState.HistoryIndex - 1));
					UnitState = XComGameState_Unit(History.GetGameStateForObjectID(BackupUnitData.UnitRef.ObjectID));
					ActionMetadata.StateObject_OldState = OldUnitState;
					ActionMetadata.StateObject_NewState = UnitState;
				}
			}
		}
	}
	else
	{
		ActionMetadata = EmptyTrack;
		VOAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, self, false, EncounterEndDialogParentAction));
		VOAction.SetSoundAndFlyOverParameters(None, "", 'EvntEncounterEnded', eColor_Xcom);

		class'X2Action_WaitForVO'.static.AddToVisualizationTree(ActionMetadata, self, false, VOAction);
	}
}

private function BuildBeginBreachModeVisualizer()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_BreachData BreachData;
	local BreachPointInfo PointInfo;
	local XComWorldData WorldData;
	local array<BreachEntryPointMarker> BreachPoints;
	local BreachEntryPointMarker BreachPoint, BestBreachPointToLookAt;

	local X2Action_CameraFramePOIs PreviewBreachPointsAction;
	local VisualizationActionMetadata ActionMetadata, EmptyActionData;

	local X2Action VisAction;
	local X2Action_PlaySoundAndFlyOver VOAction;
	local X2Action_InitUIScreen InitAndroidReinforcementMenuUIAction;
	local X2Action_UpdateUI		UpdateBreachUIAction;
	local array<XComRoomVolume> RoomVolumes;

	local X2Action_MarkerNamed NamedMarkerAction;
	local X2Action_MarkerNamed JoinAction;
	local array<X2Action> LeafNodes;
	local name PreBreachUIVoiceoverEventName;

	local X2Action_CameraLookAt 			LookAtBreachPointAction, RemovePostBreachFrameCam;

	// HELIOS Issue #50 Variables
	local array<HSTacticalVisualizationTemplate>	CachedBreachVisTemplates;	
	local HSTacticalVisualizationTemplate			HSVisTemplate;
	local EHLDInterruptReturn						InterruptReturn;

	History = `XCOMHISTORY;
	DioHQ = `DioHQ;
	WorldData = `XWORLD;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BreachData = XComGameState_BreachData(History.GetSingleGameStateObjectForClass(class'XComGameState_BreachData'));
	BreachData = XComGameState_BreachData(AssociatedState.GetGameStateForObjectID(BreachData.ObjectID));

	//Sync the visibility of backup units (Verge) in the tutorial
	if (DioHQ.TacticalGameplayTags.Find(class'XComGameStateContext_LaunchTutorialMission'.default.TutorialMissionGamePlayTag) != INDEX_NONE)
	{
		class'XComGameStateContext_LaunchTutorialMission'.static.BuildVisualization_BeginBreach(self, BattleData);
	}

	ActionMetadata = EmptyActionData;

	NamedMarkerAction = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, self));
	NamedMarkerAction.SetName("BeginBreachModeMarker");

	RemovePostBreachFrameCam = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, self, false, NamedMarkerAction));
	RemovePostBreachFrameCam.CameraTag = 'PostBreachFrameSquadCam';
	RemovePostBreachFrameCam.bRemoveTaggedCamera = true;

	// First breach, go directly into breach cam. On latter breaches, preview the room and show android reinforcements
	ActionMetadata = EmptyActionData;

	// Begin HELIOS Issue #50
	// Allow mods to intercept and insert into the BeginBreach Visualization. Pre Begin Breach Visualization.
	// This is a tough visualizer to break into since there's no event listeners that are close enough to edit this or require some very hacky workarounds, and also require intimate knowledge with the visualizer, which very few do know.
	// This will execute in the priority order set in the visualizer templates and higher priority (100) order templates will execute before lower priority (1)

	// Grab every HSTacticalVisualizerElementTemplate and iterate through them, then start visualizing after the BeginBreachModeMarker
	CachedBreachVisTemplates = class'HSHelpers'.static.GatherPreBreachBeginVisualizationTemplates();
	
	// Begin visualizing if possible
	foreach CachedBreachVisTemplates(HSVisTemplate)
	{
		// Any interrupts? Stop processing the rest of the delegates.
		if (HSVisTemplate.PreBuildVisualizationBeginBreach(self, BattleData, ActionMetadata) == EHLD_Interrupt)
			break;
	}
	// End HELIOS Issue #50

	foreach BreachData.CachedBreachPointInfos(PointInfo)
	{
		BreachPoints.AddItem(PointInfo.EntryPointActor);
	}

	if (BattleData.BreachingRoomListIndex != 0)
	{
		// preview next breach
		if (BreachPoints.length > 0)
		{
			LookAtBreachPointAction = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, self, false, RemovePostBreachFrameCam));

			foreach BreachPoints(BreachPoint)
			{
				if (BreachPoint.bBestBreachCamera)
				{
					BestBreachPointToLookAt = BreachPoint;
					break;
				}
			}

			LookAtBreachPointAction.LookAtLocation = BestBreachPointToLookAt != none ? BestBreachPointToLookAt.Location : BreachPoints[0].Location;
			LookAtBreachPointAction.BlockUntilFinished = true;
			LookAtBreachPointAction.CameraTag = 'BreachPreviewCam';
		}

		if (BreachPoints.length > 0 && `TACTICALRULES.bPreviewNextRoomPreBreach)
		{
			PreviewBreachPointsAction = X2Action_CameraFramePOIs(class'X2Action_CameraFramePOIs'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));

			PreviewBreachPointsAction.LookAtDuration = BattleData.BreachingRoomListIndex > 0 ? class'X2TacticalGameRuleset'.default.PreviewBreachPointDuration : 0.0f;

			// frame breach points && room volume
			foreach BreachPoints(BreachPoint)
			{
				PreviewBreachPointsAction.FocusPoints.AddItem(BreachPoint.Location);
			}

			WorldData.GetRoomVolumesByRoomID(BattleData.BreachingRoomID, RoomVolumes);
			PreviewBreachPointsAction.FocusPoints.AddItem(RoomVolumes[0].Location);
		}
	}

	if (BattleData.BreachingRoomListIndex != 0 || BattleData.DirectTransferInfo.IsDirectMissionTransfer)
	{
		// show android reinforcements menu if needed
		if (`TACTICALRULES.HasAndroidReserve() && `TACTICALRULES.GetRequiredAndroidReinforcementCount() > 0)
		{
			InitAndroidReinforcementMenuUIAction = X2Action_InitUIScreen(class'X2Action_InitUIScreen'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
			InitAndroidReinforcementMenuUIAction.ScreenClass = class'UIBreachAndroidReinforcementMenu';
		}
	}

	VisAction = class'X2Action_InitBreachCamera'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded);

	// trigger pre-breach VO
	PreBreachUIVoiceoverEventName = 'EvntBreach';
	if (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive_Room_0') != INDEX_NONE)
	{
		// todo: use tag isTutorialEnabled
		PreBreachUIVoiceoverEventName = 'EvntTutorialOpen';
	}

	ActionMetadata = EmptyActionData;
	VOAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, self, false, VisAction));
	VOAction.SetSoundAndFlyOverParameters(None, "", PreBreachUIVoiceoverEventName, eColor_Xcom);

	//TODO: This needs to have a sequenceable x2 action, currently happens immediately
	foreach BreachPoints(BreachPoint)
	{
		BreachPoint.ToggleMeshIcon(true);
	}

	// Begin HELIOS Issue #50
	// Allow mods to intercept and insert into the BeginBreach Visualization. Post Begin Breach Visualization.
	// This is a tough visualizer to break into since there's no event listeners that are close enough to edit this or require some very hacky workarounds, and also require intimate knowledge with the visualizer, which very few do know.
	// This will execute in the priority order set in the visualizer templates and higher priority (100) order templates will execute before lower priority (1)
	CachedBreachVisTemplates.Length = 0;
	CachedBreachVisTemplates = class'HSHelpers'.static.GatherPostBeginBreachVisualizationTemplates();
	
	// Begin visualizing if possible
	foreach CachedBreachVisTemplates(HSVisTemplate)
	{
		// Any interrupts? Stop processing the rest of the delegates.
		if (HSVisTemplate.PostBuildVisualizationBeginBreach(self, BattleData, ActionMetadata) == EHLD_Interrupt)
			break;
	}
	// End HELIOS Issue #50

	// add a join for all leaf nodes
	`XCOMVISUALIZATIONMGR.GetAllLeafNodes(NamedMarkerAction, LeafNodes);

	// Add Named Marker so we can identify this in the visualization tree
	JoinAction = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, self, false, none, LeafNodes));
	JoinAction.SetName("BeginBreachModeJoin");

	// Show the Breach Banner
	UpdateBreachUIAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
	UpdateBreachUIAction.UpdateType = EUIUT_BreachBanner;

	// Show the Breach UI
	UpdateBreachUIAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
	UpdateBreachUIAction.UpdateType = EUIUT_BeginBreachPhase;
}

private function BuildEndBreachModeVisualizer()
{
	local X2Action_UpdateUI UIUpdateAction;
	local VisualizationActionMetadata ActionMetadata, EmptyActionData;
	local X2Action_PlaySoundAndFlyOver VOAction;
	local name PostBreachVoiceoverEventName;
	local XComGameState_HeadquartersDio DioHQ;

	local X2Action_MarkerNamed NamedMarkerAction;
	local X2Action_MarkerNamed JoinAction;
	local array<X2Action> LeafNodes;

	DioHQ = `DioHQ;

	NamedMarkerAction = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, self));
	NamedMarkerAction.SetName("EndBreachModeMarker");

	//Trigger any breach-end VO
	PostBreachVoiceoverEventName = 'EvntBreachStop';
	if (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive_Room_0') != INDEX_NONE)
	{
		// todo: use tutorial tag
		PostBreachVoiceoverEventName = 'EvntTutorialMayorIntro';
	}

	ActionMetadata = EmptyActionData;
	VOAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, self, false, NamedMarkerAction));
	VOAction.SetSoundAndFlyOverParameters(None, "", PostBreachVoiceoverEventName, eColor_Xcom);

	// add a join for all leaf nodes
	`XCOMVISUALIZATIONMGR.GetAllLeafNodes(NamedMarkerAction, LeafNodes);

	// Add Named Marker so we can identify this in the visualization tree
	JoinAction = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, self, false, none, LeafNodes));
	JoinAction.SetName("EndBreachModeJoin");

	//Update the UI to reflect the end of breach
	UIUpdateAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, self));
	UIUpdateAction.UpdateType = EUIUT_EndBreachPhase;

	
}

/// <summary>
/// Override to return TRUE for the XComGameStateContexts to show that the associated state is a start state
/// </summary>
event bool IsStartState()
{
	return GameRuleType == eGameRule_TacticalGameStart;
}

native function bool NativeIsStartState();


/// <summary>
/// Returns a short description of this context object
/// </summary>
function string SummaryString()
{
	local XComGameStateHistory History;
	local XComGameState_Player PlayerState;
	local XComGameState_Unit UnitState;
	local XComGameState_AIUnitData AIState;
	local string GameRuleString;

	History = `XCOMHISTORY;

	GameRuleString = string(GameRuleType);
	if( RuleEngineNextState != '' )
	{
		GameRuleString = string(RuleEngineNextState);
	}

	if( PlayerRef.ObjectID > 0 )
	{
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(PlayerRef.ObjectID));
		GameRuleString @= "'"$PlayerState.GetGameStatePlayerName()$"' ("$PlayerRef.ObjectID$")";
	}

	if( UnitRef.ObjectID > 0 )
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if(UnitState != none)
		{
			GameRuleString @= "'"$UnitState.GetFullName()$"' ("$UnitRef.ObjectID$")";
		}
	}

	if( AIRef.ObjectID > 0 )
	{
		AIState = XComGameState_AIUnitData(History.GetGameStateForObjectID(AIRef.ObjectID));
		if( AIState.m_iUnitObjectID > 0 )
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(AIState.m_iUnitObjectID));
			GameRuleString @= "'"$UnitState.GetFullName()$"'["$UnitState.ObjectID$"] ("$AIRef.ObjectID$")";
		}
	}

	return GameRuleString;
}

/// <summary>
/// Returns a string representation of this object.
/// </summary>
native function string ToString() const;
//***************************************************

static function XComGameStateContext_TacticalGameRule BuildContextFromGameRule(GameRuleStateChange GameRule)
{
	local XComGameStateContext_TacticalGameRule StateChangeContext;

	StateChangeContext = XComGameStateContext_TacticalGameRule(class'XComGameStateContext_TacticalGameRule'.static.CreateXComGameStateContext());
	StateChangeContext.GameRuleType = GameRule;

	return StateChangeContext;
}

/// <summary>
/// This creates a minimal start state with a battle data object and three players - one Human and two AI(aliens, civilians). Returns the new game state
/// and also provides an optional out param for the battle data for use by the caller
/// </summary>
static function XComGameState CreateDefaultTacticalStartState_Singleplayer(optional out XComGameState_BattleData CreatedBattleDataObject)
{
	local XComGameStateHistory History;
	local XComGameState StartState;
	local XComGameStateContext_TacticalGameRule TacticalStartContext;
	local XComGameState_BattleData BattleDataState;
	local XComGameState_Player XComPlayerState;
	local XComGameState_Player EnemyPlayerState;
	local XComGameState_Player CivilianPlayerState;
	local XComGameState_Player TheLostPlayerState;
	local XComGameState_Player ResistancePlayerState;

	`log("XComGameStateContext_TacticalGameRule::CreateDefaultTacticalStartState_Singleplayer() : WARNING: This function may not work as intended due to the removal of Firaxis Live.", , 'DNADeprecated');
	History = `XCOMHISTORY;

	TacticalStartContext = XComGameStateContext_TacticalGameRule(class'XComGameStateContext_TacticalGameRule'.static.CreateXComGameStateContext());
	TacticalStartContext.GameRuleType = eGameRule_TacticalGameStart;
	StartState = History.CreateNewGameState(false, TacticalStartContext);

	StartState.CreateNewStateObject(class'XComGameState_BreachData'); // Create BreachData singleton

	BattleDataState = XComGameState_BattleData(StartState.CreateNewStateObject(class'XComGameState_BattleData'));
	BattleDataState.BizAnalyticsMissionID = `XANALYTICS.NativeGetMissionID();
	
	XComPlayerState = class'XComGameState_Player'.static.CreatePlayer(StartState, eTeam_XCom);
	XComPlayerState.bPlayerReady = true; // Single Player game, this will be synchronized out of the gate!
	BattleDataState.PlayerTurnOrder.AddItem(XComPlayerState.GetReference());

	EnemyPlayerState = class'XComGameState_Player'.static.CreatePlayer(StartState, eTeam_Alien);
	EnemyPlayerState.bPlayerReady = true; // Single Player game, this will be synchronized out of the gate!
	BattleDataState.PlayerTurnOrder.AddItem(EnemyPlayerState.GetReference());

	CivilianPlayerState = class'XComGameState_Player'.static.CreatePlayer(StartState, eTeam_Neutral);
	CivilianPlayerState.bPlayerReady = true; // Single Player game, this will be synchronized out of the gate!
	BattleDataState.CivilianPlayerRef = CivilianPlayerState.GetReference();

	TheLostPlayerState = class'XComGameState_Player'.static.CreatePlayer(StartState, eTeam_TheLost);
	TheLostPlayerState.bPlayerReady = true; // Single Player game, this will be synchronized out of the gate!
	BattleDataState.PlayerTurnOrder.AddItem(TheLostPlayerState.GetReference());

	ResistancePlayerState = class'XComGameState_Player'.static.CreatePlayer(StartState, eTeam_Resistance);
	ResistancePlayerState.bPlayerReady = true; // Single Player game, this will be synchronized out of the gate!
	BattleDataState.PlayerTurnOrder.AddItem(ResistancePlayerState.GetReference());

	// create a default cheats object
	StartState.CreateNewStateObject(class'XComGameState_Cheats');

	CreatedBattleDataObject = BattleDataState;
	return StartState;
}

/// <summary>
/// This creates a minimal start state with a battle data object and two players. Returns the new game state
/// and also provides an optional out param for the battle data for use by the caller
/// </summary>
static function XComGameState CreateDefaultTacticalStartState_Multiplayer(optional out XComGameState_BattleDataMP CreatedBattleDataObject)
{
	local XComGameStateHistory History;
	local XComGameState StartState;
	local XComGameStateContext_TacticalGameRule TacticalStartContext;
	local XComGameState_BattleDataMP BattleDataState;
	local XComGameState_Player XComPlayerState;

	`log("XComGameStateContext_TacticalGameRule::CreateDefaultTacticalStartState_Multiplayer() : WARNING: This function may not work as intended due to the removal of Firaxis Live.", , 'DNADeprecated');
	History = `XCOMHISTORY;

	TacticalStartContext = XComGameStateContext_TacticalGameRule(class'XComGameStateContext_TacticalGameRule'.static.CreateXComGameStateContext());
	TacticalStartContext.GameRuleType = eGameRule_TacticalGameStart;
	StartState = History.CreateNewGameState(false, TacticalStartContext);

	StartState.CreateNewStateObject(class'XComGameState_BreachData'); // Create BreachData singleton

	BattleDataState = XComGameState_BattleDataMP(StartState.CreateNewStateObject(class'XComGameState_BattleDataMP'));
	// mmg_mike.anstine (12/20/19) - Firaxis Live removal means another ID will be needed if multiplayer is ever re-enabled
	//BattleDataState.BizAnalyticsSessionID = `FXSLIVE.GetGUID( );
	BattleDataState.BizAnalyticsSessionID = "temphardcodedstring";
	
	XComPlayerState = XComGameState_Player(StartState.CreateNewStateObject(class'XComGameState_Player'));
	XComPlayerState.PlayerClassName = Name( "XGPlayer" );
	XComPlayerState.TeamFlag = eTeam_One;
	BattleDataState.PlayerTurnOrder.AddItem(XComPlayerState.GetReference());

	XComPlayerState = XComGameState_Player(StartState.CreateNewStateObject(class'XComGameState_Player'));
	XComPlayerState.PlayerClassName = Name( "XGPlayer" );
	XComPlayerState.TeamFlag = eTeam_Two;
	BattleDataState.PlayerTurnOrder.AddItem(XComPlayerState.GetReference());

	// create a default cheats object
	StartState.CreateNewStateObject(class'XComGameState_Cheats');
	
	CreatedBattleDataObject = BattleDataState;
	return StartState;
}

function OnSubmittedToReplay(XComGameState SubmittedGameState)
{
	local XComGameState_Unit UnitState;

	if (GameRuleType == eGameRule_ReplaySync)
	{
		foreach SubmittedGameState.IterateByClassType(class'XComGameState_Unit', UnitState, eReturnType_Reference)
		{
			UnitState.SetVisibilityLocation(UnitState.TileLocation);

			if (!UnitState.GetMyTemplate( ).bIsCosmetic && !UnitState.bRemovedFromPlay)
			{
				`XWORLD.SetTileBlockedByUnitFlag(UnitState);
			}
		}
	}
}

// Debug-only function used in X2DebugHistory screen.
function bool HasAssociatedObjectID(int ID)
{
	return UnitRef.ObjectID == ID;
}

function int GetPrimaryObjectRef()
{
	return ((UnitRef.ObjectID > 0) ? UnitRef.ObjectID : PlayerRef.ObjectID);
}
