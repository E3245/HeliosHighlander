//---------------------------------------------------------------------------------------
//  FILE:    X2TacticalGameRuleset.uc
//  AUTHOR:  Ryan McFall  --  10/9/2013
//  PURPOSE: This actor extends X2GameRuleset to provide special logic and behavior for
//			 the tactical game mode in X-Com 2.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class X2TacticalGameRuleset extends X2GameRuleset 
	dependson(X2GameRulesetVisibilityManager, X2TacticalGameRulesetDataStructures, XComGameState_BattleData, XComGameStateContext_Ability)
	config(GameCore)
	native(Core);

// Moved this here from UICombatLose.uc because of dependency issues
enum UICombatLoseType
{
	eUICombatLose_UnfailableGeneric,
	eUICombatLose_UnfailableHQAssault,							//Repurposed to handle campaign loss
	eUICombatLose_UnfailableObjective,
	eUICombatLose_UnfailableCommanderKilled,
};

//******** General Purpose Variables **********
var protected XComTacticalController TacticalController;        //Cache the local player controller. Used primarily during the unit actions phase
var protected XComParcelManager ParcelManager;                  //Cached copy of the parcel mgr
var protected XComPresentationLayer Pres;						//Cached copy of the presentation layer (UI)
var protected bool bShowDropshipInteriorWhileGeneratingMap;		//TRUE if we should show the dropship interior while the map is created for this battle
var protected vector DropshipLocation;
var protected Rotator DropshipRotation;
var protected array<GameRulesCache_Unit> UnitsCache;            //Book-keeping for which abilities are available / not available
var protected StateObjectReference CachedBattleDataRef;         //Reference to the singleton BattleData state for this battle
var protected StateObjectReference CachedXpManagerRef;          //Reference to the singleton XpManager state for this battle
var protected X2UnitRadiusManager UnitRadiusManager;
var protected string BeginBlockWaitingLocation;                 //Debug text relating to where the current code is executing
var protectedwrite array<StateObjectReference> CachedDeadUnits;
`define SETLOC(LocationString) BeginBlockWaitingLocation = DEBUG_SetLocationString(GetStateName() $ ":" @ `LocationString);
var private string NextSessionCommandString;
var XComNarrativeMoment TutorialIntro;
var privatewrite bool bRain; //Records TRUE/FALSE whether there is rain in this map
var EReInterleaveInitiativeType ReInterleaveInitiativeType;		//Used by ReInterleaveSelectedInitiativeGroups
var privatewrite EMovementMethod DioMovementMethod;				//Action economy for movement, used in GetMobilityInfo and settable by cheats
var bool bKismetActivatingAbility;								//True while a SeqAct_ActivateAbility is running. Enables a fix for DIO bug HLX 3802
//****************************************

//******** TurnPhase_Breach State Variables **********
var protected bool bWaitingForBreachConfirm;
var bool bWaitingForBreachCameraInit;
var protectedwrite transient array<X2Camera_Fixed> FixedBreachCameras;
var protected transient X2Camera_Breach TopDownBreachCamera;
var privatewrite transient int CurrentBreachCameraIndex;
var privatewrite init array<BreachActionData> BreachActions;	//List of breach actions being taken in TurnPhase_Breach 
var privatewrite int CurrentBreachActionIndex;					//Index into BreachActions for the current action
var privatewrite int BreachSequenceCheckpointHistoryIndex;		//History index of the last breach sequence checkpoint - used to parallelize breach actions
var privatewrite init array<PathingInputData> PathInput;		//Used by the perform breach auto-submit code
var privatewrite X2Camera_KeepLastView KeepLastViewCamera;		//For the duration of a breach action sequence, this camera the "top" camera on the stack
var privatewrite bool bBlendingTargetingCamera;					//TRUE while the camera is moving between breach initial move and the targeting camera of the first move fire shot
var privatewrite XGUnit BlendingTargetCameraShooter;			//Set with the visualizer for the unit that is the shooter for the blending target camera
var int LastBreachStartHistoryIndex;
var bool bBlockProjectileCreation;
//****************************************

//******** TurnPhase_UnitActions State Variables **********
var protected int UnitActionInitiativeIndex;	                //Index into BattleData.PlayerTurnOrder that keeps track of which player in the list is currently taking unit actions
var StateObjectReference CachedUnitActionInitiativeRef;			//Reference to the XComGameState_Player or XComGameState_AIGroup that is currently taking unit actions
var StateObjectReference CachedUnitActionPlayerRef;				//Reference to the XComGameState_Player that is currently taking unit actions
var StateObjectReference InterruptingUnitActionPlayerRef;		// Ref to the player of the currently interrupting group
var protected StateObjectReference UnitActionUnitRef;           //Reference to the XComGameState_Unit that the player has currently selected
var protected float WaitingForNewStatesTime;                    //Keeps track of how long the unit actions phase has been waiting for a decision from the player.
var privatewrite bool bLoadingSavedGame;						//This variable is true for the duration of TurnPhase_UnitActions::BeginState if the previous state was loading
var protected bool bSkipAutosaveAfterLoad;                        //If loading a game, this flag is set to indicate that we don't want to autosave until the next turn starts
var protected bool bAlienActivity;                                //Used to give UI indication to player it is the alien's turn
var protected bool bSkipRemainingTurnActivty;						//Used to end a player's turn regardless of action availability
var protected bool bSkipRemainingUnitActivity;						// Used to end a unit's turn regardless of action availability, won't end the actual turn if there are other units with actions
var float EarliestTurnSwitchTime;  // The current turn should not end until this time has passed
var config float MinimumTurnTime;  // Each turn should not end until this amount of time has passed
var private bool bInitiativeInterruptingInitialGroup;			// true if the initiative group for the current player is starting out interrupted
var int LastRoundStartHistoryIndex;
//****************************************

//******** DIO EndRoom Support Variables **********
var int LastRoomClearedHistoryIndex;
var bool bRequestHeadshots;
//****************************************

//******** EndTacticalGame State Variables **********
var bool bWaitingForMissionSummary;                             //Set to true when we show the mission summary, cleared on pressing accept in that screen
var protected bool bTacticalGameInPlay;							// True from the CreateTacticalGame::EndState() -> EndTacticalGame::BeginState(), query using TacticalGameIsInPlay()
var UICombatLoseType LoseType;									// If the mission is lost, this is the type of UI that should be used
var bool bPromptForRestart;
var int TacticalGameEndIndex;
//****************************************

//******** Config Values **********
var config int UnitHeightAdvantage;                             //Unit's location must be >= this many tiles over another unit to have height advantage against it
var config int UnitHeightAdvantageBonus;                        //Amount of additional Aim granted to a unit with height advantage
var config int UnitHeightDisadvantagePenalty;                   //Amount of Aim lost when firing against a unit with height advantage
var config int XComIndestructibleCoverMaxDifficulty;			//The highest difficulty at which to give xcom the advantage of indestructible cover (from missed shots).
var config float HighCoverDetectionModifier;					// The detection modifier to apply to units when they enter a tile with high cover.
var config float NoCoverDetectionModifier;						// The detection modifier to apply to units when they enter a tile with no high cover.
var config array<string> ForceLoadCinematicMaps;                // Any maps required for Cinematic purposes that may not otherwise be loaded.
var config array<string> arrHeightFogAdjustedPlots;				// any maps required to adjust heightfog actor properties through a remote event.
var config float DepletedAvatarHealthMod;                       // the health mod applied to the first avatar spawned in as a result of skulljacking the codex
var config bool ActionsBlockAbilityActivation;					// the default setting for whether or not X2Actions block ability activation (can be overridden on a per-action basis)
var config bool AllowDashedMovement;                            // set to true to allow dashed movement
var config float ZipModeMoveSpeed;								// in zip mode, all movement related animations are played at this speed
var config float ZipModeTrivialAnimSpeed;						// in zip mode, all trivial animations (like step outs) are played at this speed
var config float ZipModeDelayModifier;							// in zip mode, all action delays are modified by this value
var config float ZipModeDoomVisModifier;						// in zip mode, the doom visualization timers are modified by this value
var config array<string> PlayerTurnOrder;						// defines the order in which players act
var config array<float> MissionTimerDifficultyAdjustment;			// defines the number of additional turns players get per difficulty
var config float SecondWaveExtendedTimerScalar;					// scales the number of turns on mission timers (for ExtendedMissionTimers)
var config float SecondWaveBetaStrikeTimerScalar;				// scales the number of turns on mission timers (for BetaStrike)
var config float RoomClearedPostReloadDelay;				// how long post mass-reload we should delay before continuing any post-encounter visualization or the next breach
var config float PreviewBreachPointDuration;
var config float ReadyCheckNoAnimationVODelay;					// how long to delay for VO to finish, since we're not playing an animation choose an equivalent duration
//****************************************
var config bool bAutoAssignToBreachStarts;						// should units be auto-assigned to breach points at mission start
var config bool bAutoAssignGoWide;                              // only takes affect if bAutoAssignToBreachStarts is TRUE, spreads the XCOM units out among all available breach points.
var config bool bAutoActivateBreachSequence;					// for automatic testing, bAutoAssignToBreachStarts must be TRUE for this setting to operate. Instructs the game to automatically click through the breach placement UI.
var config bool bAutoFireDuringBreach;							// should we skip player input and do auto-targeting during the breach, useful for devs mostly
var config bool bUseTopDownBreachCamera;						// This controls whether we use the breach-specific top-down camera
var config bool bUseStagedBreachCamera;							// This controls whether we use the authored breach camera
var config bool bAllowSwitchBreachCamera;						// This controls whether we want players to be able to switch between staged camera and top down camera
var config bool bBlendBreachCamera;								// Should the initial move camera blend into a targeting camera?
var config string BreachReadyCheckCinescript_Call;				// The tag corresponding to the cinescript to use for the ready check call out
var config string BreachReadyCheckCinescript_Response;			// The tag corresponding to the cinescript to use for the ready check responses
var config bool bDrawDebugBreachPointSlotInfo;					// should debug rendering be enabled for breach points and slots
var config bool bAllowBreachFireAtAllRoomEnemies;				// should breach fire be limited to the enemies at the breach point, or all enemies in the encounter
var config bool bEnableEnemyBarrage;							// if true, use the barrage during the breach, instead of individual react fire
var config bool bForceEnemyReactFireAction;						// if true, enemies will always perform the reaction fire during the breach sequence
var config bool bForceEnemyAlertAction;							// if true, enemies will always perform their alert behavior during the breach sequence
var config bool bAllowEnemyReactMoveAction;						// Should surprised enemy units during the breach move after xcom enters the room?
var config bool bAllowEnemyBreachScamper;						// Whether enemies will run their breach specific 'scamper' trees at the end of the breach sequence; these do things like overwatch/suppression post-breach
var config bool bAllowSpawnScrambling;							// Whether unit spawners can scramble their units to randomize enemy locations
var config bool	bAllowManualBreachMovement;						// Whether players can control breach movement destinations
var config bool bEnableBreachMode;								// Whether the game is EVER allowed to enter breach mode
var config bool bAllowKismetBreachControl;						// Whether game-rules or kismet should advance to the breach phase
var int LastNeutralReactionEventChainIndex; // Last event chain index to prevent multiple civilian reactions from same event. Also used for simultaneous civilian movement.
var config bool bInterleaveInitiativeTurns;						// should inititive groups use the interleaved turns
var config string BreachFireCameraPreference;					// a string indicating which OTS camera the breach move fire action prefers, if any
var config bool bPureArmorMitigation;							// if true, armor will be pure damage mitigation. unit must take more damage than the armor value for any damage to get through
var config bool bCoverMitigation;								// if true, cover provides damage mitigation. In addition, if a shot hits the unit in cover, at least 1 damage gets through
var config int NumActionsToGrantVIPJoiningXCom;					// number of action points to grant a vip who is joining xcom team through mission scripting
var config int ConsecutiveGroupInitiativePenalty;				// in interleaved initiative mode, this penalty is applied to the calculation for each consecutive group of the same team
var config name bDebugMemberNameInitiativeBonus;				// this is a DEBUG name to match for a huge initiative bonus

var config float DIO_CIVILIAN_NEAR_ALIEN_REACT_RADIUS;
var config int DIO_CIVILIAN_FLEE_ALIEN_CHANCE;

var config bool bShowBreachPointIcon;
var config bool bBlendBetweenGameAndBreachCamera;
var config bool bPreviewNextRoomPreBreach;						// preview next room before entering breach phase

var config bool bResetCoordinatedAssaultCooldownEachBreach;

var array<int> VisualizerActivationHistoryFrames; // set of history frames where the visualizer was kicked off from actions being taken.

//******** Ladder Photobooth Variables **********
var X2Photobooth_StrategyAutoGen m_kPhotoboothAutoGen;
var int m_HeadshotsPending;
var X2Photobooth_TacticalLocationController m_kTacticalLocation;
var bool bStudioReady;
//****************************************

//******** Delegates **********
delegate SetupStateChange(XComGameState SetupState);
delegate BuildVisualizationDelegate(XComGameState VisualizeGameState);
//****************************************

function string DEBUG_SetLocationString(string LocationString)
{
	if (LocationString != BeginBlockWaitingLocation)
		ReleaseScriptLog( self @ LocationString );

	return LocationString;
}

simulated native function int GetLocalClientPlayerObjectID();

// Added for debugging specific ability availability. Called only from cheat manager.
function UpdateUnitAbility( XComGameState_Unit kUnit, name strAbilityName )
{
	local XComGameState_Ability kAbility;
	local StateObjectReference AbilityRef;
	local AvailableAction kAction;

	AbilityRef = kUnit.FindAbility(strAbilityName);
	if (AbilityRef.ObjectID > 0)
	{
		kAbility = XComGameState_Ability(CachedHistory.GetGameStateForObjectID(AbilityRef.ObjectID));
		kAbility.UpdateAbilityAvailability(kAction);
	}
}

native function UpdateAndAddUnitAbilities(out GameRulesCache_Unit kUnitCache, XComGameState_Unit kUnit, out array<int> CheckAvailableAbility, out array<int> UpdateAvailableIcon);

/// <summary>
/// The local player surrenders from the match, mark as a loss.
/// </summary>
function LocalPlayerForfeitMatch();

simulated function FailBattle()
{
	local XComGameState_Player PlayerState;
	local XComGameState_TimerData TimerState;
	local XGPlayer Player;

	foreach CachedHistory.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		Player = XGPlayer(PlayerState.GetVisualizer());
		if (Player != none && !Player.IsHumanPlayer())
		{
			EndBattle(Player);

			TimerState = XComGameState_TimerData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_TimerData'));
			TimerState.bStopTime = true;
			return;
		}
	}
	`RedScreen("Failed to EndBattle properly! @ttalley");
}

private simulated function bool SquadDead( )
{
	local StateObjectReference SquadMemberRef;
	local XComGameState_Unit SquadMemberState;

	foreach `DIOHQ.Squad(SquadMemberRef)
	{
		if (SquadMemberRef.ObjectID != 0)
		{
			SquadMemberState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SquadMemberRef.ObjectID));
			if (SquadMemberState != None && SquadMemberState.IsAlive())
			{
				return false;
			}
		}
	}

	return true;
}

/// <summary>
/// Will add a game state to the history marking that the battle is over
/// </summary>
simulated function EndBattle(XGPlayer VictoriousPlayer, optional UICombatLoseType UILoseType = eUICombatLose_UnfailableGeneric, optional bool GenerateReplaySave = false)
{
	local XComGameStateContext_TacticalGameRule Context;
	local XComGameState NewGameState;
	local int ReplaySaveID;
	local XComGameState_CampaignSettings CampaignSettingsStateObject;
	local XComOnlineEventMgr XComEventMgr;
	local array<string> OutCampaignSaveFilenames;
	
	XComEventMgr = `ONLINEEVENTMGR;

	`log(`location @ `ShowVar(VictoriousPlayer) @ `ShowEnum(UICombatLoseType, UILoseType) @ `ShowVar(GenerateReplaySave));
	
	// Check for the End of Tactical Game ...
	// Make sure to not end the battle multiple times.
	foreach CachedHistory.IterateContextsByClassType(class'XComGameStateContext_TacticalGameRule', Context)
	{
		if (Context.GameRuleType == eGameRule_TacticalGameEnd)
		{
			TacticalGameEndIndex = Context.AssociatedState.HistoryIndex;
			`log(`location @ "eGameRule_TacticalGameEnd Found @" @ `ShowVar(TacticalGameEndIndex));
			return; 
		}
	}

	LoseType = UILoseType;
	bPromptForRestart = !VictoriousPlayer.IsHumanPlayer();

	if (!VictoriousPlayer.IsHumanPlayer())
	{
		CampaignSettingsStateObject = XComGameState_CampaignSettings(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings', true));
		if (CampaignSettingsStateObject != none && CampaignSettingsStateObject.bHardcoreEnabled)
		{
			LoseType = eUICombatLose_UnfailableHQAssault;

			// delete all saves of current campaign
			XComEventMgr.FindSavesForCampaign(CampaignSettingsStateObject.StartTime, OutCampaignSaveFilenames);
			XComEventMgr.DeleteMultipleSameGames(OutCampaignSaveFilenames);
		}
	}

	// Don't end battles in PIE, at least not for now
	if(WorldInfo.IsPlayInEditor()) return;

	Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_TacticalGameEnd);
	Context.PlayerRef.ObjectID = VictoriousPlayer.ObjectID;
	NewGameState = Context.ContextBuildGameState();
	SubmitGameState(NewGameState);

	if(GenerateReplaySave)
	{
		ReplaySaveID = `ONLINEEVENTMGR.GetNextSaveID();
		`ONLINEEVENTMGR.SaveGame(ReplaySaveID, "ReplaySave", "", none);
	}

	`XEVENTMGR.TriggerEvent('EndBattle');
}

simulated function AbortBattle()
{
	local XComGameStateContext_TacticalGameRule Context;
	local XComGameState NewGameState;

	Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_TacticalGameEnd);
	Context.bAborted = true;
	NewGameState = Context.ContextBuildGameState();
	SubmitGameState(NewGameState);

	`XEVENTMGR.TriggerEvent('EndBattle');
}

simulated function bool CanAbortBattle()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_MissionSite MissionSiteState;
	local XComGameState_StrategyAction_Mission MissionAction;
	local XComGameState_DioWorker Worker;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	MissionSiteState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));
	MissionAction = MissionSiteState.GetMissionAction();
	Worker = MissionAction.GetWorker();
	if (Worker == none)
	{
		return false;
	}
	
	if(MissionAction.IsOperationAction())
	{
		return false;
	}

	return !Worker.IsCriticalThisTurn();
}

static function XComGameStateContext_Ability BuildAbilityContextFromRoomClearedAbility(XComGameState_Ability AbilityState)
{
	local XComGameStateHistory History;
	local XComGameStateContext OldContext;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Unit SourceUnitState;
	local XComGameState_Item SourceItemState;
	local X2AbilityTemplate AbilityTemplate;
	local X2TargetingMethod TargetingMethod;
	local int Index;

	local array<AvailableTarget> AvailableTargetList;
	local AvailableTarget AvailableTargets;
	
	History = `XCOMHISTORY;

	`assert(AbilityState != none);
	AbilityContext = XComGameStateContext_Ability(class'XComGameStateContext_Ability'.static.CreateXComGameStateContext());
	OldContext = AbilityState.GetParentGameState().GetContext();
	if (OldContext != none && OldContext.bSendGameState)
	{
		AbilityContext.SetSendGameState(true);
	}

	AbilityContext.InputContext.AbilityRef = AbilityState.GetReference();
	AbilityContext.InputContext.AbilityTemplateName = AbilityState.GetMyTemplateName();

	//Set data that informs the rules engine / visualizer which unit is performing the ability
	SourceUnitState = XComGameState_Unit(History.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
	AbilityContext.InputContext.SourceObject = SourceUnitState.GetReference();

	//Set data that informs the rules engine / visualizer what item was used to perform the ability, if any	
	SourceItemState = AbilityState.GetSourceWeapon();
	if (SourceItemState != none)
	{
		AbilityContext.InputContext.ItemObject = SourceItemState.GetReference();
	}

	AbilityTemplate = AbilityState.GetMyTemplate();
	TargetingMethod = new AbilityTemplate.TargetingMethod;
	TargetingMethod.InitFromState(AbilityState);
	
	// set ability targets 
	AbilityState.GatherAbilityTargets(AvailableTargetList);
	if (AvailableTargetList.length > 0)
	{
		AvailableTargets = AvailableTargetList[0];
		AbilityContext.InputContext.PrimaryTarget = AvailableTargets.PrimaryTarget;
		// set ability target location
		AbilityContext.InputContext.TargetLocations.AddItem(AvailableTargets.TargetLocation);
	}

	// set the multitargets
	for (Index = 0; Index < AvailableTargets.AdditionalTargets.length; Index++)
	{
		AbilityContext.InputContext.MultiTargets.AddItem(AvailableTargets.AdditionalTargets[Index]);
		AbilityContext.InputContext.MultiTargetsNotified.AddItem(false);
	}

	//Calculate the chance to hit here - earliest use after this point is NoGameStateOnMiss
	if (AbilityTemplate.AbilityToHitCalc != none)
	{
		AbilityTemplate.AbilityToHitCalc.RollForAbilityHit(AbilityState, AvailableTargets, AbilityContext.ResultContext);
		class'XComGameStateContext_Ability'.static.CheckTargetForHitModification(AvailableTargets, AbilityContext, AbilityTemplate, AbilityState);
	}

	//Now that we know the hit result, generate target locations
	class'X2Ability'.static.UpdateTargetLocationsFromContext(AbilityContext);

	if ((AbilityTemplate.TargetEffectsDealDamage(SourceItemState, AbilityState) && (AbilityState.GetEnvironmentDamagePreview() > 0)) ||
		AbilityTemplate.bUseLaunchedGrenadeEffects || AbilityTemplate.bUseThrownGrenadeEffects || AbilityTemplate.bForceProjectileTouchEvents)
	{
		TargetingMethod.GetProjectileTouchEvents(AbilityContext.InputContext.PrimaryTarget, AbilityContext.ResultContext.ProjectileHitLocations, AbilityContext.InputContext.ProjectileEvents, AbilityContext.InputContext.ProjectileTouchStart, AbilityContext.InputContext.ProjectileTouchEnd, AbilityTemplate.IsMelee());
	}

	if (AbilityTemplate.AssociatedPlayTiming != SPT_None)
	{
		AbilityContext.SetAssociatedPlayTiming(AbilityTemplate.AssociatedPlayTiming);
	}

	return AbilityContext;
}

/// <summary>
/// DIO - Battles are comprised of a series of room encounters that begin with a breach ambush by XCOM. This method allows script to make the current room encounter complete and initiate the next room encounter
/// </summary>
simulated function EndRoomEncounter()
{
	local XComGameStateHistory History;
	local XComGameStateContext_ChangeContainer ChangeContainerContext;
	local XComGameStateContext_EffectRemoved EffectRemovedContext;
	local XComGameStateContext TacticalRuleContext;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState NewGameState;
	local XComGameState_Unit OldUnitState, NewUnitState;
	local XComGameState_Effect EffectState;
	local XComGameState_Ability AbilityState;
	local array<XComGameState_Unit> XComSoldierUnits, EnemyUnits;
	local array<name> EffectNamesToRemove;
	local StateObjectReference EffectRef;	
	local int EffectIndex, NumEffects;
	local bool bSuccessfullyClearedStatuses;
	local XComGameState_BattleData BattleData;
	local XComGameState_AIGroup GroupState;
	local XComGameState_Unit UnitState;
	local array<XComGameState_Unit> LivingMemberStates;
	local array<int> LivingMemberIds;
	local X2Effect_ApplyWeaponDamage DamageEffect;
	local EffectAppliedData ApplyData;

	History = `XCOMHISTORY;

	// Create a visualizer node that will ensure all units come to rest before visualizing
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("EndRoomEncounter");
	ChangeContainerContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	ChangeContainerContext.BuildVisualizationFn = None;// BreachEndEncounterBuildVisualization;
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		
	EnemyUnits.Length = 0;
	class'XComBreachHelpers'.static.GatherBreachEnemies(EnemyUnits);

	//kill any enemies that need smiting, like bound ones
	NewGameState = `XCOMHISTORY.CreateNewGameState(true, class'XComGameStateContext_AreaDamage'.static.CreateXComGameStateContext());
	foreach EnemyUnits( OldUnitState )
	{
		if( OldUnitState != None &&
			OldUnitState.GetTeam() != eTeam_XCom &&
			OldUnitState.IsAlive() &&
			OldUnitState.IsBound() )
		{
			NewUnitState = XComGameState_Unit( NewGameState.ModifyStateObject( class'XComGameState_Unit', OldUnitState.ObjectID ) );

			DamageEffect = new class'X2Effect_ApplyWeaponDamage';
			DamageEffect.EffectDamageValue.Damage = 1000;
			DamageEffect.bHideDeathWorldMessage = true;

			ApplyData.AbilityResultContext.HitResult = eHit_Success;
			ApplyData.TargetStateObjectRef = NewUnitState.GetReference();

			DamageEffect.ApplyEffect( ApplyData, NewUnitState, NewGameState );
		}
	}
	`TACTICALRULES.SubmitGameState(NewGameState);

	//Gather the XCom Soldiers
	XComSoldierUnits.Length = 0;
	class'XComBreachHelpers'.static.GatherXComBreachUnits(XComSoldierUnits);

	// Have the first surviving XCom member cast an ability that clears certain statuses for all squadmates
	foreach XComSoldierUnits(OldUnitState)
	{
		if (!(OldUnitState.FindAbility('DioSoldierEncounterCleanup').ObjectID > 0))
		{
			continue;
		}
		AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(OldUnitState.FindAbility('DioSoldierEncounterCleanup').ObjectID));
		if (AbilityState == None)
		{
			continue;
		}
		AbilityContext = BuildAbilityContextFromRoomClearedAbility(AbilityState);
		if (AbilityContext.Validate())
		{
			`XCOMGAME.GameRuleset.SubmitGameStateContext(AbilityContext);
			bSuccessfullyClearedStatuses = true;
			break;
		}
	}
	if (!bSuccessfullyClearedStatuses)
	{
		`Redscreen("FAILED to clear status of XCom soldiers an encounter end, please (Shift+R) generate a report and send to @dakota");
	}

	// Clear specific statuses from all encounter enemies, that need to be cleaned with visualizations
	EffectRemovedContext = XComGameStateContext_EffectRemoved(class'XComGameStateContext_EffectRemoved'.static.CreateXComGameStateContext());
	NewGameState = History.CreateNewGameState(true, EffectRemovedContext);	
	EffectNamesToRemove.Length = 0;
	EffectNamesToRemove.AddItem(class'X2Effect_NeuralNetwork'.default.EffectName);
	EffectNamesToRemove.AddItem(class'X2Effect_MindControl'.default.EffectName);
	EffectNamesToRemove.AddItem(class'X2Effect_Claymore'.default.EffectName);
	EffectNamesToRemove.AddItem(class'X2Effect_PendingReinforcements'.default.EffectName);
	foreach EnemyUnits(OldUnitState)
	{
		NumEffects = OldUnitState.AffectedByEffects.Length;
		if (NumEffects <= 0)
		{
			continue;
		}
		for (EffectIndex = NumEffects - 1; EffectIndex >= 0; --EffectIndex)
		{
			EffectRef = OldUnitState.AffectedByEffects[EffectIndex];
			EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
			if (EffectState != None && EffectState.bRemoved == false && EffectNamesToRemove.Find(EffectState.GetX2Effect().EffectName) != INDEX_NONE)
			{
				EffectState.RemoveEffect(NewGameState, NewGameState, true); //Cleansed
				EffectRemovedContext.RemovedEffects.AddItem(EffectRef);
			}
		}
	}
	SubmitGameState(NewGameState);

	//clean up any current group turn
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	if( UnitActionInitiativeIndex >= 0 && UnitActionInitiativeIndex < BattleData.PlayerTurnOrder.Length )
	{
		GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[UnitActionInitiativeIndex].ObjectID ) );
		if( GroupState != None )
		{
			TacticalRuleContext = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule( eGameRule_UnitGroupTurnEnd );
			NewGameState = TacticalRuleContext.ContextBuildGameState();
			`XEVENTMGR.TriggerEvent( 'UnitGroupTurnEnded', GroupState, GroupState, NewGameState );
			GroupState.GetLivingMembers( LivingMemberIds, LivingMemberStates );
			foreach LivingMemberStates( UnitState )
			{
				`XEVENTMGR.TriggerEvent( 'UnitTurnEnded', UnitState, UnitState, NewGameState );
			}
			SubmitGameState( NewGameState );
		}
	}

	// Create the room-cleared context, which can do things like reload all weapons for xcom
	TacticalRuleContext = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_RoomCleared);
	NewGameState = TacticalRuleContext.ContextBuildGameState();
	SubmitGameState(NewGameState); //The OnNewGameState event handler will update the room cleared index because of this game rule context

	// Triggern RoomCleared, to tick any necessary effects or trigger abilities
	`XEVENTMGR.TriggerEvent('RoomCleared');
	
	//DO-LAST: This resets unitstate variables that would be needed for other operations
	XComSoldierUnits.Length = 0;
	class'XComBreachHelpers'.static.GatherXComBreachUnits(XComSoldierUnits);
	// Clear end of encounter effects for the xcom soldiers
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("ClearXComUnitStatuses");
	foreach XComSoldierUnits(OldUnitState)
	{
		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(OldUnitState.Class, OldUnitState.ObjectID));
		NewUnitState.ClearEffectsBetweenBreaches(NewGameState);
	}
	SubmitGameState(NewGameState);

	`AIJobMgr.RevokeAllKismetJobs();
}

/// <summary>
/// DIO - Operates in a manner similar to HasRoomEncounterEnded, except that it is specific to the room encounter mechanics of DIO.
/// </summary>
simulated function bool HasRoomEncounterEnded()
{
	return XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData')).bRoomCleared;
}

function bool HasNextBreachRoomSet()
{
	return XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData')).bNextRoomSet;
}

/// <summary>
/// DIO - return true if the is the first entry in to this tactical session
/// </summary>
simulated function bool IsFirstTacticalTurnCount()
{
	return XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData')).TacticalTurnCount == 0;
}

simulated function bool IsFinalRoomEncounter()
{
	local XComGameState_BattleData BattleData;

	BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	if (BattleData.MapData.RoomIDs.Length > 0)
	{
		return BattleData.MapData.RoomIDs[BattleData.MapData.RoomIDs.Length - 1] == BattleData.BreachingRoomID;
	}
	
	//If there are no room IDs, then just assume yes
	return true;
}

simulated function bool IsFinalMission()
{
	//local XComGameState_MissionSite MissionState;
	//local XComGameState_HeadquartersDio DioHQ;

	//DioHQ = XComGameState_HeadquartersDio(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio'));
	//MissionState = XComGameState_MissionSite(CachedHistory.GetGameStateForObjectID(DioHQ.MissionRef.ObjectID));

	//if (MissionState.GetMissionSource().DataName == 'MissionSource_Final')
	//{
	//	return true;
	//}

	return false;
}

/// <summary>
/// </summary>
simulated function bool HasTacticalGameEnded()
{
	local XComGameStateHistory History;
	local int StartStateIndex;
	local XComGameState StartState, EndState;
	local XComGameStateContext_TacticalGameRule StartContext, EndContext;

	//XComTutorialMgr will end the tactical game when appropriate
	if (`REPLAY.bInTutorial)
	{
		return false;
	}

	History = `XCOMHISTORY;

	StartStateIndex = History.FindStartStateIndex( );

	StartState = History.GetGameStateFromHistory( StartStateIndex );
	EndState = History.GetGameStateFromHistory( TacticalGameEndIndex );
	
	if (EndState != none)
	{
		EndContext = XComGameStateContext_TacticalGameRule( EndState.GetContext() );

		if ((EndContext != none) && (EndContext.GameRuleType == eGameRule_TacticalGameEnd))
			return true;
	}

	if (StartState != none)
	{
		StartContext = XComGameStateContext_TacticalGameRule( StartState.GetContext() );

		if ((StartContext != none) && (StartContext.GameRuleType == eGameRule_TacticalGameStart))
			return false;
	}

	return HasTimeExpired();
}

// todo: nativize
event bool NativeAccess_HasTacticalGameEnded()
{
	return HasTacticalGameEnded();
}

simulated function bool HasTimeExpired()
{
	local XComGameState_TimerData Timer;

	Timer = XComGameState_TimerData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_TimerData', true));

	return Timer != none && Timer.GetCurrentTime() <= 0;
}

/// <summary>
/// This method builds a local list of state object references for objects that are relatively static, and that we 
/// may need to access frequently. Using the cached ObjectID from a game state object reference is much faster than
/// searching for it each time we need to use it.
/// </summary>
simulated function BuildLocalStateObjectCache()
{	
	local XComGameState_XpManager XpManager;	
	local XComWorldData WorldData;	
	local XComGameState_BattleData BattleDataState;

	super.BuildLocalStateObjectCache();

	//Get a reference to the BattleData for this tactical game
	BattleDataState = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	CachedBattleDataRef = BattleDataState.GetReference();

	foreach CachedHistory.IterateByClassType(class'XComGameState_XpManager', XpManager, eReturnType_Reference)
	{
		CachedXpManagerRef = XpManager.GetReference();
		break;
	}

	TacticalController = XComTacticalController(GetALocalPlayerController());	
	TacticalController.m_kPathingPawn.InitEvents();
	ParcelManager = `PARCELMGR;
	Pres = XComPresentationLayer(XComPlayerController(GetALocalPlayerController()).Pres);	

	//Make sure that the world's OnNewGameState delegate is called prior to the visibility systems, as the vis system is dependent on the
	//world data. Unregistering these delegates is handled natively
	WorldData = `XWORLD;
	WorldData.RegisterForNewGameState();
	WorldData.RegisterForObliterate();

	WorldInfo.RemoteEventListeners.AddItem(self);

	VisibilityMgr = Spawn(class'X2GameRulesetVisibilityManager', self);
	VisibilityMgr.RegisterForNewGameStateEvent();

	if (BattleDataState.MapData.ActiveMission.sType == "Terror")
	{
		UnitRadiusManager = Spawn( class'X2UnitRadiusManager', self );
	}

	CachedHistory.RegisterOnObliteratedGameStateDelegate(OnObliterateGameState);
	CachedHistory.RegisterOnNewGameStateDelegate(OnNewGameState);
		
	class'XComTacticalGRI'.static.GetBreachActionSequencer().RegisterForEvents();
}

function OnObliterateGameState(XComGameState ObliteratedGameState)
{
	local int i, CurrentHistoryIndex;
	CurrentHistoryIndex = CachedHistory.GetCurrentHistoryIndex();
	for( i = 0; i < UnitsCache.Length; i++ )
	{
		if( UnitsCache[i].LastUpdateHistoryIndex > CurrentHistoryIndex )
		{
			UnitsCache[i].LastUpdateHistoryIndex = INDEX_NONE; // Force this to get updated next time.
		}
	}
}

function OnNewGameState(XComGameState NewGameState)
{
	local XComGameStateContext_TacticalGameRule TacticalContext;
	TacticalContext = XComGameStateContext_TacticalGameRule( NewGameState.GetContext() );

	if (IsInState( 'TurnPhase_UnitActions' ) && (TacticalContext != none) && (TacticalContext.GameRuleType == eGameRule_SkipTurn))
	{
		bSkipRemainingTurnActivty = true;
	}
	else if (IsInState('TurnPhase_UnitActions') && (TacticalContext != none) && (TacticalContext.GameRuleType == eGameRule_SkipUnit))
	{
		bSkipRemainingUnitActivity = true;
	}
	else if ((TacticalContext != none) && (TacticalContext.GameRuleType == eGameRule_TacticalGameEnd))
	{
		TacticalGameEndIndex = NewGameState.HistoryIndex;
	}
	else if ((TacticalContext != none) && (TacticalContext.GameRuleType == eGameRule_RoomCleared))
	{
		LastRoomClearedHistoryIndex = NewGameState.HistoryIndex;
	}
	else if ((TacticalContext != none) && (TacticalContext.GameRuleType == eGameRule_BeginBreachMode))
	{
		LastBreachStartHistoryIndex = NewGameState.HistoryIndex;
	}
	else if ((TacticalContext != none) && (TacticalContext.GameRuleType == eGameRule_RoundBegin))
	{
		LastRoundStartHistoryIndex = NewGameState.HistoryIndex;
	}
}

/// <summary>
/// Return a state object reference to the static/global battle data state
/// </summary>
simulated function StateObjectReference GetCachedBattleDataRef()
{
	return CachedBattleDataRef;
}

/// <summary>
/// Called by the tactical game start up process when a new battle is starting
/// </summary>
simulated function StartNewGame()
{
	BuildLocalStateObjectCache();

	GotoState('CreateTacticalGame');
}

/// <summary>
/// Called by the tactical game start up process the player is resuming a previously created battle
/// </summary>
simulated function LoadGame()
{
	//Build a local cache of useful state object references
	BuildLocalStateObjectCache();

	GotoState('LoadTacticalGame');
}

function SwitchBreachCameraMode()
{
	bUseStagedBreachCamera = !bUseStagedBreachCamera;
	bUseTopDownBreachCamera = !bUseTopDownBreachCamera;

	`XEVENTMGR.TriggerEvent('BreachCameraModeSwitched');

	ActivateBreachCamera(CurrentBreachCameraIndex);
}

function ActivateNextBreachCamera(optional int Delta = 1)
{
	ActivateBreachCamera(CurrentBreachCameraIndex + Delta);
}

function ActivateBreachCameraByGroupID(int BreachGroupID)
{
	local X2Camera_Fixed BreachCamera;
	local int BreachCameraIndex, NewBreachCameraIndex;
	local X2CameraStack CameraStack;

	CameraStack = `CAMERASTACK;
	NewBreachCameraIndex = -1;

	if (!bUseStagedBreachCamera)
	{
		SwitchBreachCameraMode();
	}

	for (BreachCameraIndex = 0; BreachCameraIndex < FixedBreachCameras.Length; ++BreachCameraIndex)
	{
		BreachCamera = FixedBreachCameras[BreachCameraIndex];
		if (BreachCamera.BreachGroupID == BreachGroupID)
		{
			NewBreachCameraIndex = BreachCameraIndex;
			break;
		}
	}

	if (NewBreachCameraIndex < 0)
	{
		`log("Unable to switch breach cameras, breach camera not found for breach group id"@BreachGroupID,, 'XCom_Breach');
		return;
	}

	if (NewBreachCameraIndex == CurrentBreachCameraIndex)
	{
		//`log("No need to switch cameras, camera is current for breach group id:"@BreachGroupID,, 'XCom_Breach');
		return;
	}
	else
	{
		DeactivateBreachCamera();
	}

	`XTACTICALSOUNDMGR.PlayLoadedAkEvent("UI_Camera_Rotate_AnyDirection_45");

	if (!CameraStack.IsCameraInStack(BreachCamera))
	{
		BreachCamera = FixedBreachCameras[NewBreachCameraIndex];
		CameraStack.AddCamera(BreachCamera);
		CurrentBreachCameraIndex = NewBreachCameraIndex;
		//`log("Switching to camera for breach group id:"@BreachGroupID,, 'XCom_Breach');
	}
	else
	{
		//`log("No need to switch cameras, camera is current and in the stack for breach group id:"@BreachGroupID,, 'XCom_Breach');
	}
}

function ActivateBreachCamera(optional int BreachCameraIndex = 0, optional bool bUseBestBreachCamera = false, optional bool bNoBlendFromPreviousCamera = false, optional bool bNoArcBlendFromPreviousCamera = false)
{
	local XComGameState_BattleData BattleData;
	local array<XComDeploymentSpawn> BreachPoints;
	local XComDeploymentSpawn BreachPoint;
	local XComGameStateHistory History;
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
	local XComWorldData XComWorld;
	local X2CameraStack CameraStack;	
	local X2Camera_Fixed FixedBreachCamera;
	local int CameraIndex;
	local BreachPointInfo PointInfo;

	History = `XCOMHISTORY;
	XComWorld = `XWORLD;
	CameraStack = `CAMERASTACK;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', false));
	
	DeactivateBreachCamera();

	if (bAllowSwitchBreachCamera)
	{
		`PRES.UISwitchBreachCameraHUD();
	}

	if (bUseStagedBreachCamera)
	{
		if (FixedBreachCameras.length < 1)
		{
			`RedScreen("Camera is not set up for breach entry point @LD");
			return;
		}

		if (BreachCameraIndex >= FixedBreachCameras.Length)
		{
			BreachCameraIndex = BreachCameraIndex % FixedBreachCameras.Length;
		}
		else if (BreachCameraIndex < 0)
		{
			BreachCameraIndex = FixedBreachCameras.Length - 1;
		}

		if (bUseBestBreachCamera)
		{
			CameraIndex = 0;
			foreach FixedBreachCameras(FixedBreachCamera)
			{
				PointInfo = class'XComBreachHelpers'.static.GetBreachPointInfoForGroupID(FixedBreachCamera.BreachGroupID);
				if (PointInfo.EntryPointActor.bBestBreachCamera)
				{
					BreachCameraIndex = CameraIndex;
					break;
				}
				++CameraIndex;
			}
		}

		FixedBreachCamera = FixedBreachCameras[BreachCameraIndex];

		//Disable blending if requested
		if (bNoBlendFromPreviousCamera)
		{
			FixedBreachCamera.bBlend = false;
		}

		//Disable behavior to sweep the camera through an arc, if requested
		if (bNoArcBlendFromPreviousCamera)
		{
			FixedBreachCamera.bRequireLOStoBlend = false;
		}

		if (BreachCameraIndex != CurrentBreachCameraIndex || !CameraStack.IsCameraInStack(FixedBreachCamera))
		{
			CameraStack.AddCamera(FixedBreachCamera);
			CurrentBreachCameraIndex = BreachCameraIndex;
		}
	}
	else if (bUseTopDownBreachCamera)
	{
		if (TopDownBreachCamera == none)
		{
			TopDownBreachCamera = new class 'X2Camera_Breach';
		}

		// this is a timed midpoint camera that will zoom out and frame POIs
		// after it has done its job, we pop it to give player back the mouse control
		TopDownBreachCamera.LookAtDuration = 1;
		TopDownBreachCamera.ClearFocusActors();
		TopDownBreachCamera.ClearFocusPoints();

		XComWorld.GetDeploymentSpawnActors(BreachPoints, BattleData.BreachingRoomID);
		foreach BreachPoints(BreachPoint)
		{
			TopDownBreachCamera.AddFocusPoint(BreachPoint.Location);
		}

		foreach `DIOHQ.Squad(UnitRef)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
			if (UnitState != none && !UnitState.IsDead())
			{
				TopDownBreachCamera.AddFocusActor(UnitState.GetVisualizer());
			}
		}

		CameraStack.AddCamera(TopDownBreachCamera);
	}
}


private function DeactivateBreachCamera()
{
	local X2Camera_Fixed FixedBreachCamera;
	local X2CameraStack CameraStack;

	CameraStack = `CAMERASTACK;


	if (TopDownBreachCamera != none && CameraStack.IsCameraInStack(TopDownBreachCamera))
	{
		CameraStack.RemoveCamera(TopDownBreachCamera);
	}

	foreach FixedBreachCameras(FixedBreachCamera)
	{
		if (CameraStack.IsCameraInStack(FixedBreachCamera))
		{
			CameraStack.RemoveCamera(FixedBreachCamera);
		}
	}
}

private function ActivateKeepLastViewCamera()
{		
	KeepLastViewCamera = new class 'X2Camera_KeepLastView';
	KeepLastViewCamera.Priority = eCameraPriority_Default; //Override the default camera, but not others
	`CAMERASTACK.AddCamera(KeepLastViewCamera);
}

function DeactivateKeepLastViewCamera()
{
	if (KeepLastViewCamera != none)
	{
		`CAMERASTACK.RemoveCamera(KeepLastViewCamera);
		KeepLastViewCamera = none;
	}
}

/// <summary>
/// Returns true if the visualizer is currently in the process of showing the last game state change
/// </summary>
simulated function bool WaitingForVisualizer()
{
	local bool bVisualizerBusy, bVisualizationTreePresent;
	bVisualizerBusy = class'XComGameStateVisualizationMgr'.static.VisualizerBusy();
	bVisualizationTreePresent = (`XCOMVISUALIZATIONMGR.VisualizationTree != none);
	return bVisualizerBusy || bVisualizationTreePresent;
}

/// <summary>
/// Expanded version of WaitingForVisualizer designed for the end of a unit turn. WaitingForVisualizer and EndOfTurnWaitingForVisualizer would ideally be consolidated, but
/// the potential for knock-on would be high as WaitingForVisualizer is used in many places for many different purposes.
/// </summary>
simulated function bool EndOfTurnWaitingForVisualizer()
{
	return !class'XComGameStateVisualizationMgr'.static.VisualizerIdleAndUpToDateWithHistory() || (`XCOMVISUALIZATIONMGR.VisualizationTree != none);
}

simulated function bool IsSavingAllowed()
{
	if( IsDoingLatentSubmission() )
	{
		return false;
	}

	if( !bTacticalGameInPlay || bWaitingForMissionSummary || HasTacticalGameEnded() || HasRoomEncounterEnded() || GetStateName() == 'TurnPhase_Breach' )
	{
		return false;
	}

	return true;
}

/// <summary>
/// Returns true if the current game time has not yet exceeded the Minimum time that must be elapsed before visualizing the next turn
/// </summary>
simulated function bool WaitingForMinimumTurnTimeElapsed()
{
	return (WorldInfo.TimeSeconds < EarliestTurnSwitchTime);
}

simulated function ResetMinimumTurnTime()
{
	EarliestTurnSwitchTime = WorldInfo.TimeSeconds + MinimumTurnTime;
}

simulated function AddDefaultPathingCamera()
{
	local XComPlayerController Controller;	

	Controller = XComPlayerController(GetALocalPlayerController());

	// mmg_john.hawley (8/16/19) REMOVE Collapsing controller camera follow class into mouse class to support input device swapping
	XComCamera(Controller.PlayerCamera).CameraStack.AddCamera(new class'X2Camera_FollowMouseCursor');
}

/// <summary>
/// Returns cached information about the unit such as what actions are available
/// </summary>
simulated function bool GetGameRulesCache_Unit(StateObjectReference UnitStateRef, out GameRulesCache_Unit OutCacheData)
{
	local AvailableAction kAction;	
	local XComGameState_Unit kUnit;
	local int CurrentHistoryIndex;
	local int ExistingCacheIndex;
	local int i;
	local array<int> CheckAvailableAbility;
	local array<int> UpdateAvailableIcon;
	local GameRulesCache_Unit EmptyCacheData;
	local XComGameState_BaseObject StateObject;

	//Correct us of this method does not 'accumulate' information, so reset the output 
	OutCacheData = EmptyCacheData;

	if (UnitStateRef.ObjectID < 1) //Caller passed in an invalid state object ID
	{
		return false;
	}

	kUnit = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitStateRef.ObjectID));

	if (kUnit == none) //The state object isn't a unit!
	{
		StateObject = CachedHistory.GetGameStateForObjectID(UnitStateRef.ObjectID);
		`redscreen("WARNING! Tried to get cached abilities for non unit game state object:\n"$StateObject.ToString());
		return false;
	}

	if (kUnit.m_bSubsystem) // Subsystem abilities are added to base unit's abilities.
	{
		return false;
	}

	if(kUnit.bDisabled			||          // skip disabled units
	   kUnit.bRemovedFromPlay	||			// removed from play ( ie. exited level )
	   kUnit.GetMyTemplate().bIsCosmetic )	// unit is visual flair, like the gremlin and should not have actions
	{
		return false;
	}

	CurrentHistoryIndex = CachedHistory.GetCurrentHistoryIndex();

	// find our cache data, if any (UnitsCache should be converted to a Map_Mirror when this file is nativized, for faster lookup)
	ExistingCacheIndex = -1;
	for(i = 0; i < UnitsCache.Length; i++)
	{
		if(UnitsCache[i].UnitObjectRef == UnitStateRef)
		{
			if(UnitsCache[i].LastUpdateHistoryIndex == CurrentHistoryIndex)
			{
				// the cached data is still current, so nothing to do
				OutCacheData = UnitsCache[i];
				return true;
			}
			else
			{
				// this cache is outdated, update
				ExistingCacheIndex = i;
				break;
			}
		}
	}

	// build the cache data
	OutCacheData.UnitObjectRef = kUnit.GetReference();
	OutCacheData.LastUpdateHistoryIndex = CurrentHistoryIndex;
	OutCacheData.AvailableActions.Length = 0;
	OutCacheData.bAnyActionsAvailable = false;

	UpdateAndAddUnitAbilities(OutCacheData, kUnit, CheckAvailableAbility, UpdateAvailableIcon);
	for (i = 0; i < CheckAvailableAbility.Length; ++i)
	{
		foreach OutCacheData.AvailableActions(kAction)
		{
			if (kAction.AbilityObjectRef.ObjectID == CheckAvailableAbility[i])
			{
				if (kAction.AvailableCode == 'AA_Success' || kAction.AvailableCode == 'AA_NoTargets')
					OutCacheData.AvailableActions[UpdateAvailableIcon[i]].eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
				else
					OutCacheData.AvailableActions[UpdateAvailableIcon[i]].eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
						
				break;
			}
		}
	}

	if(ExistingCacheIndex == -1)
	{
		UnitsCache.AddItem(OutCacheData);
	}
	else
	{
		UnitsCache[ExistingCacheIndex] = OutCacheData;
	}

	return true;
}

simulated function ETeam GetUnitActionTeam()
{
	local XComGameState_Player PlayerState;
	
	//Only XCOM can be in the breach phase
	if (GetStateName() == 'TurnPhase_Breach')
	{
		return eTeam_XCom;
	}

	PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(GetCachedUnitActionPlayerRef().ObjectID));
	if( PlayerState != none )
	{
		return PlayerState.TeamFlag;
	}

	return eTeam_None;
}

simulated function bool UnitActionPlayerIsAI()
{
	local XComGameState_Player PlayerState;

	PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(GetCachedUnitActionPlayerRef().ObjectID));
	if( PlayerState != none )
	{
		return PlayerState.GetVisualizer().IsA('XGAIPlayer');
	}

	return false;
}

/// <summary>
/// This event is called after a system adds a gamestate to the history, perhaps circumventing the ruleset itself.
/// </summary>
simulated function OnSubmitGameState()
{
	bWaitingForNewStates = false;
}

/// <summary>
/// Overridden per State - determines whether SubmitGameStates can add new states to the history or not. During some 
/// turn phases new state need to be added only at certain times.
/// </summary>
simulated function bool AddNewStatesAllowed()
{
	local bool bAddNewStatesAllowed;	
		
	bAddNewStatesAllowed = super.AddNewStatesAllowed();
	
	//Do not permit new states to be added while we are performing a replay
	bAddNewStatesAllowed = bAddNewStatesAllowed && !XComTacticalGRI(class'WorldInfo'.static.GetWorldInfo().GRI).ReplayMgr.bInReplay;

	return bAddNewStatesAllowed;
}

/// <summary>
/// Overridden per state. Allows states to specify that unit visualizers should not be selectable (and human controlled) at the current time
/// </summary>
simulated function bool AllowVisualizerSelection()
{
	return true;
}

/// <summary>
/// Called whenever the rules authority changes state in the rule engine. This creates a rules engine sate change 
/// history frame that directs non-rules authority instances to change their rule engine state.
/// </summary>
function BeginState_RulesAuthority( delegate<SetupStateChange> SetupStateDelegate )
{
	local XComGameState EnteredNewPhaseGameState;
	local XComGameStateContext_TacticalGameRule NewStateContext;

	NewStateContext = XComGameStateContext_TacticalGameRule(class'XComGameStateContext_TacticalGameRule'.static.CreateXComGameStateContext());	
	NewStateContext.GameRuleType = eGameRule_RulesEngineStateChange;
	NewStateContext.RuleEngineNextState = GetStateName();
	NewStateContext.SetContextRandSeedFromEngine();
	
	EnteredNewPhaseGameState = CachedHistory.CreateNewGameState(true, NewStateContext);

	if( SetupStateDelegate != none )
	{
		SetupStateDelegate(EnteredNewPhaseGameState);	
	}

	CachedHistory.AddGameStateToHistory(EnteredNewPhaseGameState);
}

/// <summary>
/// Called whenever a non-rules authority receives a rules engine state change history frame.
/// </summary>
simulated function BeginState_NonRulesAuthority(name DestinationState)
{
	local name NextTurnPhase;
	
	//Validate that this state change is legal
	NextTurnPhase = GetNextTurnPhase(GetStateName());
	`assert(DestinationState == NextTurnPhase);

	GotoState(DestinationState);
}

simulated function string GetStateDebugString();

simulated function DrawDebugLabel(Canvas kCanvas)
{
	local string kStr;
	local int iX, iY;
	local XComCheatManager LocalCheatManager;
	
	LocalCheatManager = XComCheatManager(GetALocalPlayerController().CheatManager);

	if( LocalCheatManager != None && LocalCheatManager.bDebugRuleset )
	{
		iX=250;
		iY=50;

		kStr =      "=========================================================================================\n";
		kStr = kStr$"Rules Engine (State"@GetStateName()@")\n";
		kStr = kStr$"=========================================================================================\n";	
		kStr = kStr$GetStateDebugString();
		kStr = kStr$"\n";

		kCanvas.SetPos(iX, iY);
		kCanvas.SetDrawColor(0,255,0);
		kCanvas.DrawText(kStr);
	}
}

private static function Object GetEventFilterObject(AbilityEventFilter eventFilter, XComGameState_Unit FilterUnit, XComGameState_Player FilterPlayerState)
{
	local Object FilterObj;

	switch(eventFilter)
	{
	case eFilter_None:
		FilterObj = none;
		break;
	case eFilter_Unit:
		FilterObj = FilterUnit;
		break;
	case eFilter_Player:
		FilterObj = FilterPlayerState;
		break;
	}

	return FilterObj;
}

//  THIS SHOULD ALMOST NEVER BE CALLED OUTSIDE OF NORMAL TACTICAL INIT SEQUENCE. USE WITH EXTREME CAUTION.
static simulated function StateObjectReference InitAbilityForUnit(X2AbilityTemplate AbilityTemplate, XComGameState_Unit Unit, XComGameState StartState, optional StateObjectReference ItemRef, optional StateObjectReference AmmoRef)
{
	local X2EventManager EventManager;
	local XComGameState_Ability kAbility;
	local XComGameState_Player PlayerState;
	local Object FilterObj, SourceObj;
	local AbilityEventListener kListener;
	local X2AbilityTrigger Trigger;
	local X2AbilityTrigger_EventListener AbilityTriggerEventListener;
	local XGUnit UnitVisualizer;
	local StateObjectReference AbilityReference;

	`assert(AbilityTemplate != none);

	//Add a new ability state to StartState
	kAbility = AbilityTemplate.CreateInstanceFromTemplate(StartState);

	if( kAbility != none )
	{
		//Set source weapon as the iterated item
		kAbility.SourceWeapon = ItemRef;
		kAbility.SourceAmmo = AmmoRef;

		//Give the iterated unit state the new ability
		`assert(Unit.bReadOnly == false);
		Unit.Abilities.AddItem(kAbility.GetReference());
		kAbility.InitAbilityForUnit(Unit, StartState);
		AbilityReference = kAbility.GetReference();

		EventManager = `XEVENTMGR;
		PlayerState = XComGameState_Player(StartState.GetGameStateForObjectID(Unit.ControllingPlayer.ObjectID));
		if (PlayerState == none)
			PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(Unit.ControllingPlayer.ObjectID));

		foreach AbilityTemplate.AbilityEventListeners(kListener)
		{
			SourceObj = kAbility;
			
			FilterObj = GetEventFilterObject(kListener.Filter, Unit, PlayerState);
			EventManager.RegisterForEvent(SourceObj, kListener.EventID, kListener.EventFn, kListener.Deferral, /*priority*/, FilterObj);
		}
		foreach AbilityTemplate.AbilityTriggers(Trigger)
		{
			if (Trigger.IsA('X2AbilityTrigger_EventListener'))
			{
				AbilityTriggerEventListener = X2AbilityTrigger_EventListener(Trigger);

				FilterObj = GetEventFilterObject(AbilityTriggerEventListener.ListenerData.Filter, Unit, PlayerState);
				AbilityTriggerEventListener.RegisterListener(kAbility, FilterObj);
			}
		}

		// In the case of Aliens, they're spawned with no abilities so we add their perks when we add their ability
		UnitVisualizer = XGUnit(Unit.GetVisualizer());
		if (UnitVisualizer != none)
		{
			UnitVisualizer.GetPawn().AppendAbilityPerks( AbilityTemplate.DataName, AbilityTemplate.GetPerkAssociationName() );
			UnitVisualizer.GetPawn().StartPersistentPawnPerkFX( AbilityTemplate.DataName );
		}
	}
	else
	{
		`log("WARNING! AbilityTemplate.CreateInstanceFromTemplate FAILED for ability"@AbilityTemplate.DataName);
	}
	return AbilityReference;
}

static simulated function ReRegisterAbilityListenersForUnit(XComGameState_Unit Unit)
{
	local X2EventManager EventManager;
	local XComGameState_Ability kAbility;
	local XComGameState_Player PlayerState;
	local Object SourceObj, FilterObj, AbilityObj;
	local AbilityEventListener kListener;
	local X2AbilityTrigger Trigger;
	local X2AbilityTrigger_EventListener AbilityTriggerEventListener;
	local StateObjectReference AbilityReference;
	local X2AbilityTemplate AbilityTemplate;
	local int Index;

	EventManager = `XEVENTMGR;
	PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(Unit.ControllingPlayer.ObjectID));
	if( PlayerState == none )
	{
		PlayerState = XComGameState_Player( `XCOMHISTORY.GetGameStateForObjectID( Unit.ControllingPlayer.ObjectID ) );
	}

	for( Index = 0; Index < Unit.Abilities.Length; ++Index )
	{
		AbilityReference = Unit.Abilities[Index];
		kAbility = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(AbilityReference.ObjectID));
		if( kAbility != None )
		{
			AbilityTemplate = kAbility.GetMyTemplate();
			if( AbilityTemplate != None )
			{
				foreach AbilityTemplate.AbilityEventListeners(kListener)
				{
					SourceObj = kAbility;
					if( !EventManager.IsRegistered( SourceObj, kListener.EventID, kListener.Deferral, kListener.EventFn ) )
					{
						FilterObj = GetEventFilterObject(kListener.Filter, Unit, PlayerState);
						EventManager.RegisterForEvent(SourceObj, kListener.EventID, kListener.EventFn, kListener.Deferral, /*priority*/, FilterObj);
					}
				}
				foreach AbilityTemplate.AbilityTriggers(Trigger)
				{
					if (Trigger.IsA('X2AbilityTrigger_EventListener'))
					{
						AbilityTriggerEventListener = X2AbilityTrigger_EventListener(Trigger);
						if( AbilityTriggerEventListener.ListenerData.OverrideListenerSource != none )
						{
							AbilityObj = AbilityTriggerEventListener.ListenerData.OverrideListenerSource;
						}
						else
						{
							AbilityObj = kAbility;
						}

						if( !EventManager.IsRegistered( AbilityObj, AbilityTriggerEventListener.ListenerData.EventID, AbilityTriggerEventListener.ListenerData.Deferral, AbilityTriggerEventListener.ListenerData.EventFn ) )
						{
							FilterObj = GetEventFilterObject(AbilityTriggerEventListener.ListenerData.Filter, Unit, PlayerState);
							AbilityTriggerEventListener.RegisterListener(kAbility, FilterObj);
						}
					}
				}
			}
		}
	}
}


// todo: remove after nativazing
event StateObjectReference NativeAccess_InitAbilityForUnit(X2AbilityTemplate AbilityTemplate, XComGameState_Unit Unit, XComGameState GameState, optional StateObjectReference ItemRef, optional StateObjectReference AmmoRef)
{
	return InitAbilityForUnit(AbilityTemplate, Unit, GameState, ItemRef, AmmoRef);
}

static simulated function InitializeUnitAbilities(XComGameState NewGameState, XComGameState_Unit NewUnit)
{		
	local XComGameState_Player kPlayer;
	local int i;
	local array<AbilitySetupData> AbilityData;
	local bool bIsMultiplayer;
	local X2AbilityTemplate AbilityTemplate;

	`assert(NewGameState != none);
	`assert(NewUnit != None);

	bIsMultiplayer = class'Engine'.static.GetEngine().IsMultiPlayerGame();

	kPlayer = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(NewUnit.ControllingPlayer.ObjectID));			

	AbilityData = NewUnit.GatherUnitAbilitiesForInit(NewGameState, kPlayer);
	for (i = 0; i < AbilityData.Length; ++i)
	{
		AbilityTemplate = AbilityData[i].Template;

		if( !AbilityTemplate.IsTemplateAvailableToAnyArea(AbilityTemplate.BITFIELD_GAMEAREA_Tactical) )
		{
			`log(`staticlocation @ "WARNING!! Ability:"@ AbilityTemplate.DataName@" is not available in tactical!");
		}
		else if( bIsMultiplayer && !AbilityTemplate.IsTemplateAvailableToAnyArea(AbilityTemplate.BITFIELD_GAMEAREA_Multiplayer) )
		{
			`log(`staticlocation @ "WARNING!! Ability:"@ AbilityTemplate.DataName@" is not available in multiplayer!");
		}
		else
		{
			InitAbilityForUnit(AbilityTemplate, NewUnit, NewGameState, AbilityData[i].SourceWeaponRef, AbilityData[i].SourceAmmoRef);			
		}
	}
}

static simulated function MultipartMissionFixupUnitAbilities(XComGameState StartState, XComGameState_Unit Unit)
{
	local XComGameStateHistory History;
	local XComGameState_Player PlayerState;
	local int i;
	local array<AbilitySetupData> AbilityData;	
	local X2EventManager EventManager;
	local StateObjectReference StateRef;
	local XComGameState_Ability AbilityState;
	local AbilityEventListener kListener;
	local X2AbilityTrigger Trigger;
	local Object FilterObj, SourceObj;	
	local X2AbilityTrigger_EventListener AbilityTriggerEventListener;

	`assert(StartState != none);
	`assert(Unit != None);

	EventManager = `XEVENTMGR;
	History = `XCOMHISTORY;	
	StateRef.ObjectID = Unit.GetAssociatedPlayerID();
	PlayerState = XComGameState_Player(History.GetGameStateForObjectID(StateRef.ObjectID));
	AbilityData = Unit.GatherUnitAbilitiesForInit(StartState, PlayerState, false);
	for (i = 0; i < AbilityData.Length; ++i)
	{		
		StateRef = Unit.FindAbility(AbilityData[i].TemplateName);
		AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(StateRef.ObjectID));
				
		if (AbilityState == none)
		{
			//Handle the case where the ability is missing somehow			
			class'X2TacticalGameRuleset'.static.InitAbilityForUnit(AbilityData[i].Template, Unit, StartState, AbilityData[i].SourceWeaponRef, AbilityData[i].SourceAmmoRef);
		}
		else
		{
			SourceObj = AbilityState;

			foreach AbilityData[i].Template.AbilityEventListeners(kListener)
			{
				FilterObj = GetEventFilterObject(kListener.Filter, Unit, PlayerState);
				if (!EventManager.IsRegistered(SourceObj, kListener.EventID, kListener.Deferral, kListener.EventFn))
				{	
					EventManager.RegisterForEvent(SourceObj, kListener.EventID, kListener.EventFn, kListener.Deferral, /*priority*/, FilterObj);
				}
			}

			foreach AbilityData[i].Template.AbilityTriggers(Trigger)
			{
				if (Trigger.IsA('X2AbilityTrigger_EventListener'))
				{
					AbilityTriggerEventListener = X2AbilityTrigger_EventListener(Trigger);
					FilterObj = GetEventFilterObject(AbilityTriggerEventListener.ListenerData.Filter, Unit, PlayerState);
					AbilityTriggerEventListener.FixupRegisterListener(AbilityState, FilterObj);
				}
			}
		}
	}
}

static simulated function StartStateInitializeUnitAbilities(XComGameState StartState)
{	
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_Unit UnitState;
	local X2ItemTemplate MissionItemTemplate;	

	History = `XCOMHISTORY;	
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	// Select the mission item for the current mission (may be None)
	MissionItemTemplate = GetMissionItemTemplate();

	`assert(StartState != none);

	foreach StartState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if( UnitState.GetTeam() == eTeam_XCom )
		{
			if(BattleData.DirectTransferInfo.IsDirectMissionTransfer 
				&& !UnitState.GetMyTemplate().bIsCosmetic
				&& UnitState.Abilities.Length > 0)
			{
				// XCom's abilities will have also transferred over, and do not need to be reapplied. However, we do need to do
				// re-register listeners that may have been removed by the level transition
				MultipartMissionFixupUnitAbilities(StartState, UnitState);

				continue;
			}

			// update the mission items for this XCom unit
			UpdateMissionItemsForUnit(MissionItemTemplate, UnitState, StartState);
		}

		// initialize the abilities for this unit
		InitializeUnitAbilities(StartState, UnitState);
	}
}

static simulated function X2ItemTemplate GetMissionItemTemplate()
{
	if (`TACTICALMISSIONMGR.ActiveMission.RequiredMissionItem.Length > 0)
	{
		return class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate(name(`TACTICALMISSIONMGR.ActiveMission.RequiredMissionItem[0]));
	}
	
	return none;
}

static simulated function UpdateMissionItemsForUnit(X2ItemTemplate MissionItemTemplate, XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_Item MissionItemState;
	local StateObjectReference ItemStateRef;

	History = `XCOMHISTORY;

	// remove the existing mission item
	foreach UnitState.InventoryItems(ItemStateRef)
	{
		MissionItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemStateRef.ObjectID));

		if( MissionItemState != None && MissionItemState.InventorySlot == eInvSlot_Mission )
		{
			UnitState.RemoveItemFromInventory(MissionItemState, NewGameState);
		}
	}

	// award the new mission item
	if( MissionItemTemplate != None )
	{
		MissionItemState = MissionItemTemplate.CreateInstanceFromTemplate(NewGameState);
		UnitState.AddItemToInventory(MissionItemState, eInvSlot_Mission, NewGameState);
	}
}

simulated function StartStateCreateXpManager(XComGameState StartState)
{
	local XComGameState_XpManager XpManager;

	XpManager = XComGameState_XpManager(StartState.CreateNewStateObject(class'XComGameState_XpManager'));
	CachedXpManagerRef = XpManager.GetReference();
	XpManager.Init(XComGameState_BattleData(StartState.GetGameStateForObjectID(CachedBattleDataRef.ObjectID)));
}

simulated function StartStateInitializeSquads(XComGameState StartState)
{
	local XComGameState_Unit UnitState;
	local XComGameState_AIGroup PlayerGroup;

	if( !default.bInterleaveInitiativeTurns )
	{
		PlayerGroup = XComGameState_AIGroup(StartState.CreateNewStateObject(class'XComGameState_AIGroup'));
		PlayerGroup.bProcessedScamper = true;
	}

	foreach StartState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if( UnitState.GetTeam() == eTeam_XCom )
		{
			if( default.bInterleaveInitiativeTurns )
			{
				PlayerGroup = XComGameState_AIGroup( StartState.CreateNewStateObject( class'XComGameState_AIGroup' ) );
				PlayerGroup.bProcessedScamper = true;
			}
			PlayerGroup.AddUnitToGroup(UnitState.ObjectID, StartState);

			UnitState.SetBaseMaxStat(eStat_DetectionModifier, HighCoverDetectionModifier);

			// clear out the current hack reward on mission start
			UnitState.CurrentHackRewards.Remove(0, UnitState.CurrentHackRewards.Length);
		}
	}
}

function bool GetLivingBreachGroupMembers(XComGameState_AIGroup Group, optional out array<XComGameState_Unit> LivingMemberStates)
{
	local XComGameStateHistory History;
	local XComGameState_Unit Member;
	local StateObjectReference Ref;

	History = `XCOMHISTORY;
	foreach Group.m_arrMembers(Ref)
	{
		Member = XComGameState_Unit(History.GetGameStateForObjectID(Ref.ObjectID));
		if (Member != None && Member.IsAlive() && Member.HasAssignedRoomBeenBreached() && !Member.bRemovedFromPlay)
		{
			LivingMemberStates.AddItem(Member);
		}
	}
	return LivingMemberStates.Length > 0;
}
function int GetGroupInitiativeBonusBasedOnMembers( array<XComGameState_Unit> LivingMemberStates )
{
	local int Bonus;
	local XComGameState_Unit Member;

	Bonus = 0;
	foreach LivingMemberStates(Member)
	{
		if( Member != None )
		{
			//for now, this just gives a bonus base on if the template name matches the debug name in the config
			if( Member.GetMyTemplateName() == bDebugMemberNameInitiativeBonus )
			{
				Bonus += 1000;
			}
			Bonus += Member.GetCurrentStat( eStat_Initiative );
		}
	}
	return Bonus;
}
function int GetAlternatingInitiativePenalty( array<XComGameState_AIGroup> PreviouslyAddedGroups, eTeam GroupTeam, int PenaltyAmountPerGroup )
{
	local int Penalty;
	local int Index;
	local XComGameState_AIGroup OtherGroup;
	Penalty = 0;
	for( Index = PreviouslyAddedGroups.Length - 1; Index >= 0; --Index )
	{
		OtherGroup = PreviouslyAddedGroups[Index];
		if( OtherGroup != None )
		{
			if( OtherGroup.TeamName == GroupTeam )
			{
				Penalty += PenaltyAmountPerGroup;
			}
			else
			{
				break;
			}
		}
	}
	return Penalty;
}
function int FindBestInitiativeGroup(array<XComGameState_AIGroup> GroupsToConsider, array<XComGameState_AIGroup> PreviouslyAddedGroups, optional bool bIgnoreConsecutivePenalty = false)
{
	local XComGameState_AIGroup Group;
	local int BestGroupIndex;
	local int BestGroupInititive;
	local int Index;
	local int GroupInititive;
	local int WorstPossibleScore;
	local array<XComGameState_Unit> LivingMemberStates;

	WorstPossibleScore = -100000;
	BestGroupInititive = WorstPossibleScore;
	BestGroupIndex = INDEX_NONE;
	for( Index = 0; Index < GroupsToConsider.Length; ++Index )
	{
		GroupInititive = WorstPossibleScore;
		LivingMemberStates.Length = 0;
		Group = GroupsToConsider[Index];
		if( GetLivingBreachGroupMembers(Group, LivingMemberStates) )
		{
			// ignore the template value
			GroupInititive = 0; // Group.InitiativePriority;
			if( !bIgnoreConsecutivePenalty )
			{
				GroupInititive -= GetAlternatingInitiativePenalty( PreviouslyAddedGroups, Group.TeamName, ConsecutiveGroupInitiativePenalty );
			}
			GroupInititive += GetGroupInitiativeBonusBasedOnMembers( LivingMemberStates );
		}
		if( GroupInititive > BestGroupInititive )
		{
			BestGroupInititive = GroupInititive;
			BestGroupIndex = Index;
		}
	}
	return BestGroupIndex;
}

static function bool IsGroupInList(array<XComGameState_AIGroup> GroupList, XComGameState_AIGroup Group )
{
	local int SearchIndex;
	if( Group != None )
	{
		for( SearchIndex = 0; SearchIndex < GroupList.Length; ++SearchIndex )
		{
			if( GroupList[SearchIndex].ObjectID == Group.ObjectID )
			{
				return true;
			}
		}
	}
	return false;
}
static function AddUniqueGroupToList( XComGameState_AIGroup Group,  out array<XComGameState_AIGroup> GroupList )
{
	if( !IsGroupInList( GroupList, Group) )
	{
		GroupList.AddItem( Group );
	}
}
function GetXComBreachGroupOrderList( out array<XComGameState_AIGroup> SortedGroupList )
{
	local array<StateObjectReference> UnitReferences;
	local int RefScan;
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local XComGameState_AIGroup GroupState;
	local array<XComGameState_Unit> XComUnitStates;

	History = `XCOMHISTORY;
	if (bEnableBreachMode)
	{
		class'XComBreachHelpers'.static.GetXComRelativeTurnOrder(UnitReferences);
	}
	else
	{
		// breach point cache data is not populated in non-breach mode.
		// so manully look for xcom units
		class'Helpers'.static.GatherUnitStates(XComUnitStates, eTeam_XCom);
		foreach XComUnitStates(UnitState)
		{
			UnitReferences.AddItem(UnitState.GetReference());
		}
	}

	for (RefScan = 0; RefScan < UnitReferences.Length; ++RefScan)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitReferences[RefScan].ObjectID, eReturnType_Reference));
		GroupState = ( UnitState != None ) ? UnitState.GetGroupMembership() : None;
		if( IsValidInitiativeGroup( GroupState ) )
		{
			AddUniqueGroupToList( GroupState, SortedGroupList );
		}
	}
}
function InterleaveInitiativeGroups(array<XComGameState_AIGroup> XComGroups, array<XComGameState_AIGroup> OtherGroups, out array<XComGameState_AIGroup> InterleavedGroups )
{
	local int NumXcom, NumOther, NumTotal;
	local int XComIndex, OtherIndex, LoopIndex;
	local float error, dr, dx, dy;
	local bool bPlaceXCom;

	NumXcom = XComGroups.Length;
	NumOther = OtherGroups.Length;
	NumTotal = NumXcom + NumOther;
	if( NumTotal > 0 )
	{
		dx = NumTotal;
		dy = NumXcom;
		XComIndex = 0;
		OtherIndex = 0;
		bPlaceXCom = ( NumXcom > 0 );
		dr = (NumXcom > 0) ? (dx / dy) : dx;
		error = 0.0f;
		for( LoopIndex = 0; LoopIndex < NumTotal; ++LoopIndex )
		{
			if( bPlaceXCom )
			{
				`assert( XComIndex < XComGroups.Length );
				InterleavedGroups.AddItem( XComGroups[XComIndex] );
				XComIndex += 1;
			}
			else
			{
				`assert( OtherIndex < OtherGroups.Length );
				InterleavedGroups.AddItem( OtherGroups[OtherIndex] );
				OtherIndex += 1;
			}
			bPlaceXCom = false;
			error += 1.0f;
			if( error >= dr )
			{
				error -= dr;
				bPlaceXCom = true;
			}
		}
	}
}

private function bool IsOtherwiseValidInitiativeGroup( XComGameState_AIGroup Group)
{
	local array<int> LivingUnitIDs;
	local array<XComGameState_Unit> LivingMemberStates;
	local XComGameState_Unit UnitState;

	LivingUnitIDs.Length = 0;
	LivingMemberStates.Length = 0;
	if( Group != None && Group.GetLivingMembers( LivingUnitIDs, LivingMemberStates ) )
	{
		//see if any are valid
		foreach LivingMemberStates( UnitState )
		{
			if( !UnitState.IsCaptured() && 
				!UnitState.IsUnconscious() && 
				!UnitState.bRemovedFromPlay && 
				UnitState.HasAssignedRoomBeenBreached() )
			{
				return true;
			}
		}
	}
	return false;
}
private function AddOtherGroupsToInitativeList(array<XComGameState_AIGroup> GroupsToConsider, out array<XComGameState_AIGroup> InterleavedGroupList)
{
	local int Index;
	local XComGameState_AIGroup Group;

	//get all the other groups
	for( Index = 0; Index < GroupsToConsider.Length; ++Index )
	{
		Group = GroupsToConsider[Index];
		if( !IsValidInitiativeGroup( Group ) && IsOtherwiseValidInitiativeGroup( Group ) )
		{
			AddUniqueGroupToList( Group, InterleavedGroupList );
		}
	}
}
function MakeInitativeGroupList(array<XComGameState_AIGroup> GroupsToConsider, out array<XComGameState_AIGroup> InterleavedGroupList)
{
	local XComGameState_AIGroup Group;
	local array<XComGameState_AIGroup> XComBreachGroups;
	local array<XComGameState_AIGroup> AllOtherGroups;
	local array<XComGameState_AIGroup> SortedOtherGroups;
	local int Index;

	local array<XComGameState_AIGroup> TestXComGroups;
	local array<XComGameState_AIGroup> TestOtherGroups;
	local array<XComGameState_AIGroup> TestInterleavedGroups;
	local int TestNumXCom, TestNumOther, TestIndex;
	local bool bRunTests;

	//get all the xcom breach groups in the order of the breach
	GetXComBreachGroupOrderList( XComBreachGroups );
	//get all the other groups
	for( Index = 0; Index < GroupsToConsider.Length; ++Index )
	{
		Group = GroupsToConsider[Index];
		if( IsValidInitiativeGroup( Group ) && Group.TeamName != eTeam_XCom )
		{
			AddUniqueGroupToList( Group, AllOtherGroups );
		}
	}
	//sort the other groups by initiative priority - ignoring alternating teams
	SortedOtherGroups.Length = 0;
	while( true )
	{
		Index = FindBestInitiativeGroup( AllOtherGroups, SortedOtherGroups, true );
		if( Index == INDEX_NONE )
		{
			break;
		}
		Group = AllOtherGroups[Index];
		SortedOtherGroups.AddItem( Group );
		//remove it from further consideration
		AllOtherGroups.Remove( Index, 1 );
	}

	bRunTests = false;	//if you change the InterleaveInitiativeGroups functions, be sure to run the tests to check for any asserts
	if( bRunTests && XComBreachGroups.Length > 0 && SortedOtherGroups.Length > 0 )
	{
		for( TestNumXCom = 0; TestNumXCom < 40; ++TestNumXCom )
		{
			for( TestNumOther = 0; TestNumOther < 40; ++TestNumOther )
			{
				TestXComGroups.Length = 0;
				for( TestIndex = 0; TestIndex < TestNumXCom; ++TestIndex )
				{
					TestXComGroups.AddItem( XComBreachGroups[0] );
				}
				TestOtherGroups.Length = 0;
				for( TestIndex = 0; TestIndex < TestNumOther; ++TestIndex )
				{
					TestOtherGroups.AddItem( SortedOtherGroups[0] );
				}
				TestInterleavedGroups.Length = 0;
				InterleaveInitiativeGroups( TestXComGroups, TestOtherGroups, TestInterleavedGroups );
				`assert( ( TestXComGroups.Length + TestOtherGroups.Length ) == TestInterleavedGroups.Length );
			}
		}
	}

	//interleave the two groups
	InterleaveInitiativeGroups( XComBreachGroups, SortedOtherGroups, InterleavedGroupList );

	//add any groups that need to tick, but shouldn't show up in the timeline
	AddOtherGroupsToInitativeList( GroupsToConsider, InterleavedGroupList );
}

function bool IsValidInitiativeGroup( XComGameState_AIGroup Group, optional out XComGameState_Unit FirstValidUnitState)
{
	local array<int> LivingUnitIDs;
	local array<XComGameState_Unit> LivingMemberStates;
	local XComGameState_Unit UnitState;

	LivingUnitIDs.Length = 0;
	LivingMemberStates.Length = 0;
	FirstValidUnitState = None;
	if( Group != None && Group.GetLivingMembers( LivingUnitIDs, LivingMemberStates ) && (Group.TeamName == eTeam_XCom || Group.TeamName == eTeam_Alien) )
	{
		//see if any are valid
		foreach LivingMemberStates( UnitState )
		{
			if( !UnitState.IsCaptured() && 
				!UnitState.IsUnconscious() && 
				!UnitState.bRemovedFromPlay && 
				UnitState.HasAssignedRoomBeenBreached() &&
				!UnitState.GetCharacterTemplate().bExcludeFromTimeline )
			{
				FirstValidUnitState = UnitState;
				return true;
			}
		}
	}
	return false;
}
function bool IsLaterGroupInSamePlayerInitiative( XComGameState_AIGroup GroupA, XComGameState_AIGroup GroupB )
{
	local int InitiativeIndex, NumSearched;
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local XComGameState_AIGroup GroupState;

	if( GroupA != None && GroupB != None && GroupA.TeamName == GroupB.TeamName )
	{
		History = `XCOMHISTORY;
		BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
		InitiativeIndex = FindInitiativeGroupIndex( GroupA );
		if( InitiativeIndex != INDEX_NONE )
		{
			for( NumSearched = 0; NumSearched < (BattleData.PlayerTurnOrder.Length-1); ++NumSearched )
			{
				InitiativeIndex += 1;
				if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length || InitiativeIndex < 0 )
				{
					InitiativeIndex = 0;
				}
				//is this entry a valid group
				GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
				if( IsValidInitiativeGroup( GroupState ) )
				{
					if( GroupState.TeamName != GroupA.TeamName )
					{
						return false;
					}
					if( GroupState.ObjectID == GroupB.ObjectID )
					{
						return true;
					}
				}
			}
		}
	}
	return false;
}
function XComGameState_AIGroup GetFirstXComInitiative()
{
	local int InitiativeIndex, NumSearched;
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local XComGameState_AIGroup GroupState;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	NumSearched = 0;
	for( InitiativeIndex = UnitActionInitiativeIndex; NumSearched < BattleData.PlayerTurnOrder.Length; ++NumSearched )
	{
		//wrap index
		if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length || InitiativeIndex < 0 )
		{
			InitiativeIndex = 0;
		}
		//is this entry a valid group
		GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
		if( IsValidInitiativeGroup( GroupState ) && GroupState.TeamName == eTeam_XCom)
		{
			return GroupState;
		}
		InitiativeIndex += 1;
	}

	return None;
}
function bool IsNextXComInitiativeGroup( XComGameState_AIGroup ThisGroup )
{
	local int InitiativeIndex, NumSearched;
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local XComGameState_AIGroup GroupState;

	if( ThisGroup != None && ThisGroup.TeamName == eTeam_XCom )
	{
		History = `XCOMHISTORY;
		BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
		NumSearched = 0;
		for( InitiativeIndex = UnitActionInitiativeIndex; NumSearched < BattleData.PlayerTurnOrder.Length; ++NumSearched )
		{
			//wrap index
			if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length || InitiativeIndex < 0 )
			{
				InitiativeIndex = 0;
			}
			//is this entry a valid group
			GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
			if( IsValidInitiativeGroup( GroupState ) )
			{
				return ( GroupState.ObjectID == ThisGroup.ObjectID );
			}
			InitiativeIndex += 1;
		}
	}
	return false;
}
function XComGameState_AIGroup GetLastInitiativeGroup()
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local int InitiativeIndex, NumSearched;
	local XComGameState_AIGroup GroupState, LastGroupState;

	LastGroupState = None;
	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );	

	//find the last valid 
	NumSearched = 0;
	for( InitiativeIndex = UnitActionInitiativeIndex; NumSearched < BattleData.PlayerTurnOrder.Length; ++NumSearched )
	{
		//wrap index
		if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length )
		{
			InitiativeIndex = 0;
		}
		//is this entry a valid group
		GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
		if( IsValidInitiativeGroup( GroupState ) )
		{
			LastGroupState = GroupState;
		}
		InitiativeIndex += 1;
	}

	return LastGroupState;
}
function XComGameState_AIGroup GetCurrentInitiativeGroup( optional out XComGameState_Unit CurrentUnitState)
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local int InitiativeIndex, ThisGroupIniativeIndex, NumSearched;
	local XComGameState_AIGroup GroupState;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	ThisGroupIniativeIndex = UnitActionInitiativeIndex;

	if( ThisGroupIniativeIndex != INDEX_NONE )
	{
		//find the first valid 
		NumSearched = 0;
		for( InitiativeIndex = ThisGroupIniativeIndex; NumSearched < BattleData.PlayerTurnOrder.Length; ++NumSearched )
		{
			//wrap index
			if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length )
			{
				InitiativeIndex = 0;
			}
			//is this entry a valid group
			GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
			if( IsValidInitiativeGroup( GroupState, CurrentUnitState ) )
			{
				return GroupState;
			}
			InitiativeIndex += 1;
		}
	}
	CurrentUnitState = None;
	GroupState = None;

	return GroupState;
}
function CalculateRelativeGroupInitiative( XComGameState_AIGroup TargetGroup, XComGameState_AIGroup SourceGroup, out int ValidPlacesAhead, out int ValidPlacesBehind, out int ValidTeamPlacesAhead )
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local int InitiativeIndex, ThisGroupIniativeIndex, NumSearched;
	local XComGameState_AIGroup GroupState;
	local int NumValidGroups, NumTeamValidGroups;

	ValidPlacesAhead = -1;
	ValidPlacesBehind = -1;
	ValidTeamPlacesAhead = -1;

	if( SourceGroup != None && TargetGroup != None )
	{
		//find the index of the source
		ThisGroupIniativeIndex = FindInitiativeGroupIndex( SourceGroup );
		if( ThisGroupIniativeIndex != INDEX_NONE )
		{
			History = `XCOMHISTORY;
			BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
			NumSearched = 0;
			NumValidGroups = 0;
			NumTeamValidGroups = 0;
			for( InitiativeIndex = ThisGroupIniativeIndex; NumSearched < BattleData.PlayerTurnOrder.Length; ++NumSearched )
			{
				if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length )
				{
					InitiativeIndex = 0;
				}
				if( InitiativeIndex < 0 )
				{
					InitiativeIndex = BattleData.PlayerTurnOrder.Length - 1;
				}
				GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
				//is this entry a valid group
				if( IsValidInitiativeGroup( GroupState ) )
				{
					if( GroupState.ObjectID == TargetGroup.ObjectID )
					{
						ValidPlacesAhead = NumValidGroups;
						ValidTeamPlacesAhead = NumTeamValidGroups;
					}
					NumValidGroups += 1;
					if (GroupState.TeamName == TargetGroup.TeamName)
					{
						NumTeamValidGroups += 1;
					}
				}
				InitiativeIndex += 1;
			}
			if( ValidPlacesAhead != INDEX_NONE )
			{
				ValidPlacesBehind = ( ValidPlacesAhead > 0 ) ? ( NumValidGroups - ValidPlacesAhead ) : 0;
			}
		}
	}
}
function XComGameState_AIGroup FindInitiativeGroupNumPlacesPastThisGroup(XComGameState_AIGroup ThisGroup, int NumPlaces, optional bool bAllowWrap=true, optional bool bMustBeSameTeam = false, optional XComGameState_AIGroup DoNotMovePastThisGroup=None)
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local XComGameState_AIGroup GroupState;
	local XComGameState_AIGroup LastValidGroupState;
	local int InitiativeIndex, ThisGroupIniativeIndex, NumValidPlacesPastThisGroup, NumSearched;

	LastValidGroupState = ThisGroup;
	if( ThisGroup != None && NumPlaces != 0 )
	{
		History = `XCOMHISTORY;
		BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
		//find the index of this group
		ThisGroupIniativeIndex = INDEX_NONE;
		for( InitiativeIndex = 0; InitiativeIndex < BattleData.PlayerTurnOrder.Length; ++InitiativeIndex )
		{
			if( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID == ThisGroup.ObjectID )
			{
				ThisGroupIniativeIndex = InitiativeIndex;
				break;
			}
		}
		if( ThisGroupIniativeIndex != INDEX_NONE )
		{
			//find a valid group NumPlacesPast this group
			NumValidPlacesPastThisGroup = 0;
			NumSearched = 0;
			for( InitiativeIndex = ThisGroupIniativeIndex; NumSearched < BattleData.PlayerTurnOrder.Length; ++NumSearched )
			{
				//wrap index
				if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length )
				{
					if( !bAllowWrap )
					{
						break;
					}
					InitiativeIndex = 0;
				}
				if( InitiativeIndex < 0 )
				{
					if( !bAllowWrap )
					{
						break;
					}
					InitiativeIndex = BattleData.PlayerTurnOrder.Length -1;
				}

				GroupState = XComGameState_AIGroup(History.GetGameStateForObjectID(BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID));
				//is this entry a valid group
				if( IsValidInitiativeGroup( GroupState ) && ( !bMustBeSameTeam || ( GroupState.TeamName == ThisGroup.TeamName ) ) )
				{
					if( NumValidPlacesPastThisGroup == NumPlaces )
					{
						return GroupState;
					}
					NumValidPlacesPastThisGroup += ( NumPlaces > 0 ) ? 1 : -1;
					LastValidGroupState = GroupState;
				}
				InitiativeIndex += ( NumPlaces > 0 ) ? 1 : -1;
				if( DoNotMovePastThisGroup != None && DoNotMovePastThisGroup == GroupState && DoNotMovePastThisGroup != ThisGroup )
				{
					break;
				}
			}
		}
	}
	return LastValidGroupState;
}

function int GetNumberOfInitiativeTurnsTakenThisRound( int InitiativeObjectID )
{
	local XComGameState_BattleData BattleData;
	local int Index, NumTurns;

	NumTurns = 0;
	BattleData = XComGameState_BattleData( `XCOMHISTORY.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	for( Index = 0; (Index < UnitActionInitiativeIndex && Index < BattleData.PlayerTurnOrder.Length); ++Index )
	{
		if( BattleData.PlayerTurnOrder[Index].ObjectID == InitiativeObjectID )
		{
			NumTurns += 1;
		}
	}
	return NumTurns;
}
function FireUnitBreachEndTriggers(XComGameState NewGameState)
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local int InitiativeIndex, UnitIndex;
	local XComGameState_AIGroup GroupState;
	local XComGameState_Unit UnitState;

		History = `XCOMHISTORY;
		BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	for( InitiativeIndex = 0; InitiativeIndex < BattleData.PlayerTurnOrder.Length; ++InitiativeIndex )
	{
		GroupState = XComGameState_AIGroup(History.GetGameStateForObjectID(BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID));
//		GroupState = XComGameState_AIGroup( NewGameState.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
		if( IsValidInitiativeGroup( GroupState ) )
		{
			for( UnitIndex = 0; UnitIndex < GroupState.m_arrMembers.Length; ++UnitIndex )
			{
				UnitState = XComGameState_Unit( NewGameState.GetGameStateForObjectID( GroupState.m_arrMembers[UnitIndex].ObjectID ) );
				if( UnitState != None && UnitState.IsAlive() )
				{
					`XEVENTMGR.TriggerEvent('UnitBreachPhaseEnd', UnitState, UnitState, NewGameState);
				}
			}
		}
	}
}

simulated function BuildInitiativeOrder(XComGameState NewGameState)
{
	local XComGameState_BattleData BattleData;
	local string PlayerTurnName, CompareTeamName;
	local ETeam PlayerTurnTeam, CompareTurnTeam;
	local int TeamIndex;
	local XComGameState_Player PlayerState;
	local XComGameState_AIGroup PlayerGroup;
	local int InitiativeIndex;
	local array<XComGameState_AIGroup> UnsortedGroupsForPlayer;
	local array<XComGameState_Player> AllPlayers;
	local array<XComGameState_AIGroup> AllPlayerGroups;
	local int GroupIndex;
	local XComGameState_Player LastPlayerState;
	local XComGameState_AIGroup LoopGroup;
	local array<XComGameState_AIGroup> SortedGroupList;

	BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	BattleData.PlayerTurnOrder.Remove(0, BattleData.PlayerTurnOrder.Length);

	// iterate over player order
	foreach PlayerTurnOrder(PlayerTurnName)
	{
		PlayerTurnTeam = eTeam_None;
		for( TeamIndex = eTeam_Neutral; PlayerTurnTeam == eTeam_None && TeamIndex < eTeam_All; TeamIndex *= 2 )
		{
			CompareTurnTeam = ETeam(TeamIndex);
			CompareTeamName = string(CompareTurnTeam);
			if( PlayerTurnName == CompareTeamName )
			{
				PlayerTurnTeam = CompareTurnTeam;
			}
		}

		// add all players
		foreach NewGameState.IterateByClassType(class'XComGameState_Player', PlayerState)
		{
			if( PlayerState.GetTeam() == PlayerTurnTeam )
			{
				BattleData.PlayerTurnOrder.AddItem(PlayerState.GetReference());
				AllPlayers.Additem( PlayerState );
			}
		}

		foreach CachedHistory.IterateByClassType(class'XComGameState_Player', PlayerState)
		{
			if( PlayerState.GetTeam() == PlayerTurnTeam &&
			   BattleData.PlayerTurnOrder.Find('ObjectID', PlayerState.ObjectID) == INDEX_NONE )
			{
				BattleData.PlayerTurnOrder.AddItem(PlayerState.GetReference());
				AllPlayers.Additem( PlayerState );
			}
		}

		InitiativeIndex = BattleData.PlayerTurnOrder.Length;
		UnsortedGroupsForPlayer.Length = 0;

		// add all groups who should be in initiative
		foreach NewGameState.IterateByClassType(class'XComGameState_AIGroup', PlayerGroup)
		{
			if( PlayerGroup.TeamName == PlayerTurnTeam &&
			   !PlayerGroup.bShouldRemoveFromInitiativeOrder )
			{
				UnsortedGroupsForPlayer.AddItem(PlayerGroup);
				AllPlayerGroups.AddItem( PlayerGroup );
			}
		}

		// add all groups who should be in initiative
		foreach CachedHistory.IterateByClassType(class'XComGameState_AIGroup', PlayerGroup)
		{
			if( PlayerGroup.TeamName == PlayerTurnTeam &&
			   !PlayerGroup.bShouldRemoveFromInitiativeOrder &&
			   UnsortedGroupsForPlayer.Find(PlayerGroup) == INDEX_NONE )
			{
				UnsortedGroupsForPlayer.AddItem(PlayerGroup);
				AllPlayerGroups.AddItem( PlayerGroup );
			}
		}

		foreach UnsortedGroupsForPlayer(PlayerGroup)
		{
			InsertGroupByInitiativePriority(InitiativeIndex, PlayerGroup, BattleData);
		}
	}

	if( default.bInterleaveInitiativeTurns )
	{
		//now ignore all the previous work and sort the groups by initiative, and add them to the list
		BattleData.PlayerTurnOrder.Remove(0, BattleData.PlayerTurnOrder.Length);
		LastPlayerState = None;

		MakeInitativeGroupList( AllPlayerGroups, SortedGroupList );

		//always jam an xcom player in the list - even if there are no xcom groups
		foreach AllPlayers(PlayerState)
		{
			if( PlayerState.TeamFlag == eTeam_XCom )
			{
				BattleData.PlayerTurnOrder.AddItem( PlayerState.GetReference() );
				LastPlayerState = PlayerState;
				break;
			}
		}

		for( GroupIndex = 0; GroupIndex < SortedGroupList.Length; ++GroupIndex )
		{
			LoopGroup = SortedGroupList[GroupIndex];
			foreach AllPlayers(PlayerState)
			{
				if( PlayerState.TeamFlag == LoopGroup.TeamName )
				{
					if( PlayerState != LastPlayerState )
					{
						BattleData.PlayerTurnOrder.AddItem( PlayerState.GetReference() );
						LastPlayerState = PlayerState;
					}
					break;
				}
			}
			//add the group 
			BattleData.PlayerTurnOrder.AddItem( LoopGroup.GetReference() );
		}
	}
	if( BattleData.PlayerTurnOrder.Length > 0 )
	{
		UnitActionInitiativeIndex = 0;
		CachedUnitActionInitiativeRef = BattleData.PlayerTurnOrder[UnitActionInitiativeIndex];
	}
}
function int FindInitiativeGroupIndex(  XComGameState_AIGroup GroupState )
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local int InitiativeIndex, ThisGroupIniativeIndex;

	ThisGroupIniativeIndex = INDEX_NONE;
	if( GroupState != None )
	{
		History = `XCOMHISTORY;
		BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
		for( InitiativeIndex = 0; InitiativeIndex < BattleData.PlayerTurnOrder.Length; ++InitiativeIndex )
		{
			if( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID == GroupState.ObjectID )
			{
				ThisGroupIniativeIndex = InitiativeIndex;
				break;
			}
		}
	}
	return ThisGroupIniativeIndex;
}
function MoveInitiativeGroup( XComGameState_AIGroup GroupState, int NewInitiativeIndex, optional bool bPlaceAfter = false, optional bool bForceNewInitiativeGroup = false )
{
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local bool bGroupAdded, bWantsToPlaceGroup;
	local int InitiativeIndex, GroupIndex, NumTurns;
	local XComGameState_AIGroup MoveGroupState;
	local array<XComGameState_AIGroup> OldGroups;
	local array<XComGameState_AIGroup> NewGroups;
	local array<XComGameState_Player> AllPlayers;
	local XComGameState_Player LastPlayerState;
	local XComGameState_AIGroup LoopGroup;
	local XComGameState_Player PlayerState, InitiativePlayerState;
	local XComGameState_AIGroup OldInitiativeGroupState, NextInitiativeGroupState, NewInitiativeGroupState;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	if( default.bInterleaveInitiativeTurns &&
		GroupState != None &&
		NewInitiativeIndex != INDEX_NONE && 
		NewInitiativeIndex < BattleData.PlayerTurnOrder.Length )
	{
		bGroupAdded = false;
		//see if the initiative is a player
		if( UnitActionInitiativeIndex >= 0 && UnitActionInitiativeIndex < BattleData.PlayerTurnOrder.Length )
		{
			InitiativePlayerState = XComGameState_Player( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[UnitActionInitiativeIndex].ObjectID ) );
			//find the current group, and the next group to go
			NumTurns = BattleData.PlayerTurnOrder.Length;
			for( InitiativeIndex = UnitActionInitiativeIndex; NumTurns > 0 && NextInitiativeGroupState == None; --NumTurns )
			{
				if( InitiativeIndex < 0 || InitiativeIndex >= BattleData.PlayerTurnOrder.Length )
				{
					InitiativeIndex = 0;
				}
				if( OldInitiativeGroupState == None )
				{
					OldInitiativeGroupState = XComGameState_AIGroup(History.GetGameStateForObjectID(BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID));
				}
				else
				{
					NextInitiativeGroupState = XComGameState_AIGroup(History.GetGameStateForObjectID(BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID));
				}
				InitiativeIndex += 1;
			}

		}
		//find all the groups and add them to a list
		for( InitiativeIndex = 0; InitiativeIndex < BattleData.PlayerTurnOrder.Length; ++InitiativeIndex )
		{
			bWantsToPlaceGroup = ( !bGroupAdded && InitiativeIndex >= NewInitiativeIndex );
			MoveGroupState = XComGameState_AIGroup(History.GetGameStateForObjectID(BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID));
			if( MoveGroupState != None )
			{
				OldGroups.AddItem( MoveGroupState ); //save the old group order
				if( bWantsToPlaceGroup && bPlaceAfter == false )
				{
					NewGroups.AddItem( GroupState );
					bGroupAdded = true;
				}
				if( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID != GroupState.ObjectID )
				{
					NewGroups.AddItem( MoveGroupState );
				}
				if( bWantsToPlaceGroup && bPlaceAfter == true )
				{
					NewGroups.AddItem( GroupState );
					bGroupAdded = true;
				}
			}
			//if it is a player - add it to the players
			PlayerState = XComGameState_Player(History.GetGameStateForObjectID(BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID));
			if( PlayerState != None )
			{
				AllPlayers.AddItem( PlayerState ); //this will add multiples, but that's ok
			}
		}
		//if the group has been added, proceed with a rebuild of the PlayerTurnOrder
		if( bGroupAdded )
		{
			LastPlayerState = None;
			BattleData.PlayerTurnOrder.Remove(0, BattleData.PlayerTurnOrder.Length);
			//always jam an xcom player in the list - even if there are no xcom groups
			foreach AllPlayers(PlayerState)
			{
				if( PlayerState.TeamFlag == eTeam_XCom )
				{
					BattleData.PlayerTurnOrder.AddItem( PlayerState.GetReference() );
					LastPlayerState = PlayerState;
					break;
				}
			}
			for( GroupIndex = 0; GroupIndex < NewGroups.Length; ++GroupIndex )
			{
				//add the player if it has changed
				LoopGroup = NewGroups[GroupIndex];
				foreach AllPlayers(PlayerState)
				{
					if( PlayerState.TeamFlag == LoopGroup.TeamName )
					{
						if( PlayerState != LastPlayerState )
						{
							BattleData.PlayerTurnOrder.AddItem( PlayerState.GetReference() );
							LastPlayerState = PlayerState;
						}
						break;
					}
				}
				//add the group 
				BattleData.PlayerTurnOrder.AddItem( LoopGroup.GetReference() );
			}
			//set the new initiative reference to the old group - UNLESS the old group was the group to move and it has moved
			NewInitiativeGroupState = OldInitiativeGroupState;
			if( OldInitiativeGroupState == GroupState && NextInitiativeGroupState != None)
			{
				for( InitiativeIndex = 0; InitiativeIndex < BattleData.PlayerTurnOrder.Length; ++InitiativeIndex )
				{
					if( OldGroups[InitiativeIndex] == GroupState )
					{
						if( NewGroups[InitiativeIndex] != GroupState )
						{
							NewInitiativeGroupState = NextInitiativeGroupState;
						}
						break;
					}
				}
			}
			if( bForceNewInitiativeGroup )
			{
				NewInitiativeGroupState = GroupState;
			}
			//set the new initiative ref
			if( NewInitiativeGroupState != None )
			{
				// the new initiative index is equal to the new group index
				//one less if the InitiativePlayerState is valid and the InitiativeIndex > 0 && there is a valid player at that location ( InitiativeIndex -1 )
				InitiativeIndex = FindInitiativeGroupIndex( NewInitiativeGroupState );
				if( (InitiativePlayerState != None || bForceNewInitiativeGroup)  && InitiativeIndex > 0 )
				{
					PlayerState = XComGameState_Player( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex - 1].ObjectID ) );
					if( PlayerState != None )
					{
						InitiativeIndex -= 1;
					}
				}
				CachedUnitActionInitiativeRef.ObjectID = BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID;
				UnitActionInitiativeIndex = InitiativeIndex;
			}
//			else
//			{
//				RefreshInitiativeIndex(BattleData);
//			}
			// add a GroupTickChanged event for any groups that have moved later - relative to the old initiative group
			SendTickGroupChanges( OldGroups, NewGroups, OldInitiativeGroupState, NewInitiativeGroupState );
		}
	}
}

function MakeRelativeGroupList( const array<XComGameState_AIGroup> GroupList, out array<XComGameState_AIGroup> RelativeGroupList, const XComGameState_AIGroup RelativeGroup )
{
	local int RelativeIndex, NumGroups;

	RelativeIndex = GroupList.Find( RelativeGroup );
	for( NumGroups = 0; NumGroups < GroupList.Length; ++NumGroups )
	{
		if( RelativeIndex >= GroupList.Length || RelativeIndex < 0 )
		{
			RelativeIndex = 0;
		}
		RelativeGroupList.AddItem( GroupList[RelativeIndex] );
		RelativeIndex += 1;
	}
}

function SendTickGroupChanges( const array<XComGameState_AIGroup> OldGroups, const array<XComGameState_AIGroup> NewGroups, const XComGameState_AIGroup OldInitiativeGroup, const XComGameState_AIGroup NewInitiativeGroup )
{
	local array<XComGameState_AIGroup> OldGroupsRelative;
	local array<XComGameState_AIGroup> NewGroupsRelative;
	local int Index, NewIndex, MoveAmount;
	local X2EventManager EventManager;

	EventManager = `XEVENTMGR;

	MakeRelativeGroupList( OldGroups, OldGroupsRelative, OldInitiativeGroup );
	MakeRelativeGroupList( NewGroups, NewGroupsRelative, NewInitiativeGroup );
	for( Index = 0; Index < OldGroupsRelative.Length && Index < NewGroupsRelative.Length; ++Index )
	{
		NewIndex = NewGroupsRelative.Find( OldGroupsRelative[Index] );
		if( NewIndex >= 0 )
		{
			MoveAmount = NewIndex - Index;
			//did the group move down, OR up more than one
			if( MoveAmount > 0 || MoveAmount < -1 )
			{
				EventManager.TriggerEvent('TickGroupChanged', NewGroupsRelative[Index], OldGroupsRelative[Index]);
			}
		}
	}
}

function MoveInitiativeGroupRelative( XComGameState_AIGroup GroupToMoveState, XComGameState_AIGroup GroupBaseState, int NumPlaces )
{
	local XComGameState_AIGroup GroupState;
	local int GroupStateInitiativeIndex;
	local bool bPlaceAfter;

	bPlaceAfter = ( NumPlaces < 0 );
	if( NumPlaces == -1 && ( GroupBaseState.ObjectID == GetCurrentInitiativeGroup().ObjectID ) )
	{
		//this is a special case move where we want to move to the "Last" spot in the timeline
		GroupState = GetLastInitiativeGroup();
		bPlaceAfter = true;
	}
	else
	{
		GroupState = FindInitiativeGroupNumPlacesPastThisGroup( GroupBaseState, NumPlaces);
	}
	if( GroupState != None )
	{
		GroupStateInitiativeIndex = FindInitiativeGroupIndex( GroupState );
		if( GroupStateInitiativeIndex != INDEX_NONE )
		{
			MoveInitiativeGroup( GroupToMoveState, GroupStateInitiativeIndex, bPlaceAfter );
		}
	}
}

event ReInterleaveSelectedInitiativeGroups( array<XComGameState_AIGroup> SelectedGroups )
{
	local array<XComGameState_AIGroup> ValidNonSelectedGroups, TempNonSelectedGroups, InterleavedGroups;
	local XComGameState_BattleData BattleData;
	local XComGameStateHistory History;
	local int InitiativeIndex, CurrentGroupIniativeIndex, NumSearched, NumValidNonSelectedGroups;
	local XComGameState_AIGroup GroupState, CurrentGroupState;
	local int ValidNonSelectedStartIndex;
	local XComGameState_AIGroup TargetGroup;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	CurrentGroupState = GetCurrentInitiativeGroup();
	if( CurrentGroupState != None && SelectedGroups.Length > 0 )
	{
		//gather all the groups starting with the current that are not in the SelectedGroups
		NumValidNonSelectedGroups = 0;
		NumSearched = 0;

		if( ReInterleaveInitiativeType == eReInterleaveInitiativeType_TimelineAfterXCom ) //after first xcom
		{
			GroupState = GetFirstXComInitiative();
			if( GroupState != None )
			{
				CurrentGroupState = GroupState;
			}
		}

		CurrentGroupIniativeIndex = FindInitiativeGroupIndex( CurrentGroupState );
		for( InitiativeIndex = CurrentGroupIniativeIndex; NumSearched < BattleData.PlayerTurnOrder.Length; ++NumSearched )
		{
			//wrap index
			if( InitiativeIndex >= BattleData.PlayerTurnOrder.Length )
			{
				InitiativeIndex = 0;
			}
			GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID ) );
			if( IsValidInitiativeGroup( GroupState ) && !IsGroupInList( SelectedGroups, GroupState ) )
			{
				ValidNonSelectedGroups.AddItem( GroupState );
				NumValidNonSelectedGroups += 1;
			}
			InitiativeIndex += 1;
		}
		//if there are any, decide where to start the interleave
		if( NumValidNonSelectedGroups > 1 )
		{
			if( ReInterleaveInitiativeType == eReInterleaveInitiativeType_TimelineAfterXCom || ReInterleaveInitiativeType == eReInterleaveInitiativeType_TimelineNext )
			{
				ValidNonSelectedStartIndex = 0; //spread all
			}
			else if( ReInterleaveInitiativeType == eReInterleaveInitiativeType_TimelineMid )
			{
				ValidNonSelectedStartIndex = Max( ( NumValidNonSelectedGroups / 2 ) - 1, 0 ); // spread back half
			}
			else
			{
				ValidNonSelectedStartIndex = Max( NumValidNonSelectedGroups - 1, 0 ); //end of timeline
			}

			// copy the groups past the start into a temp list
			for( InitiativeIndex = ValidNonSelectedStartIndex; InitiativeIndex < ValidNonSelectedGroups.Length; ++InitiativeIndex )
			{
				TempNonSelectedGroups.AddItem( ValidNonSelectedGroups[InitiativeIndex] );
			}
			InterleaveInitiativeGroups( TempNonSelectedGroups, SelectedGroups, InterleavedGroups );
			TargetGroup = InterleavedGroups[0]; // InterleaveInitiativeGroups ALWAYS places the first entry of the first array first in the ouptput list
			//move the interleaved groups into the appropriate place relative to the target group
			for( InitiativeIndex = 1; InitiativeIndex < InterleavedGroups.Length; ++InitiativeIndex )
			{
				GroupState = FindInitiativeGroupNumPlacesPastThisGroup( TargetGroup, InitiativeIndex );
				if( GroupState != None )
				{
					MoveInitiativeGroup( InterleavedGroups[InitiativeIndex], FindInitiativeGroupIndex( GroupState ) );
				}
			}
		}
	}
}
function RefreshInitiativeIndex(XComGameState_BattleData BattleData)
{
	local int InitiativeIndex;

	// update the index to match the current initiative ref
	if( CachedUnitActionInitiativeRef.ObjectID > 0 )
	{
		for( InitiativeIndex = 0; InitiativeIndex < BattleData.PlayerTurnOrder.Length; ++InitiativeIndex )
		{
			if( CachedUnitActionInitiativeRef.ObjectID == BattleData.PlayerTurnOrder[InitiativeIndex].ObjectID )
			{
				UnitActionInitiativeIndex = InitiativeIndex;
				return;
			}
		}
		UnitActionInitiativeIndex = 0;
	}
}

private function InsertGroupByInitiativePriority(int MinInitiativeIndex, XComGameState_AIGroup GroupState, XComGameState_BattleData BattleData)
{
	local int Index;
	local XComGameState_AIGroup OtherGroup;
	local XComGameStateHistory History;

	// do not add if the group is already in the initiative order
	if( BattleData.PlayerTurnOrder.Find('ObjectID', GroupState.ObjectID) != INDEX_NONE )
	{
		return;
	}

	History = `XCOMHISTORY;

	for( Index = MinInitiativeIndex; Index < BattleData.PlayerTurnOrder.Length; ++Index )
	{
		OtherGroup = XComGameState_AIGroup(History.GetGameStateForObjectID(BattleData.PlayerTurnOrder[Index].ObjectID));
		if( OtherGroup == None || GroupState.InitiativePriority < OtherGroup.InitiativePriority )
		{
			break;
		}
	}

	BattleData.PlayerTurnOrder.InsertItem(Index, GroupState.GetReference());
}

simulated function AddGroupToInitiativeOrder(XComGameState_AIGroup NewGroup, XComGameState NewGameState, optional bool bUseSpawnPlacement=false)
{
	local XComGameState_BattleData BattleData;
	local int OrderIndex;
	local XComGameState_Player PlayerState;
	local XComGameState_AIGroup LastGroup;

	BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	// do not add if the group is already in the initiative order
	if( BattleData.PlayerTurnOrder.Find('ObjectID', NewGroup.ObjectID) != INDEX_NONE )
	{
		return;
	}
		
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	if( bUseSpawnPlacement )
	{
		LastGroup = GetLastInitiativeGroup();
		BattleData.PlayerTurnOrder.AddItem(NewGroup.GetReference()); //add it at the end
		NewGroup.bShouldRemoveFromInitiativeOrder = false;
		if( LastGroup != None )
		{
			MoveInitiativeGroup( NewGroup, FindInitiativeGroupIndex( LastGroup ), true ); //place after the last group
		}
		else
		{
			MoveInitiativeGroup( NewGroup, FindInitiativeGroupIndex( NewGroup ) ); //bogus way to update the turn order with proper player markers
		}
		return;
	}
	// Look for the new group's team in the order list.  
	for( OrderIndex = 0; OrderIndex < BattleData.PlayerTurnOrder.Length; ++OrderIndex )
	{
		PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(BattleData.PlayerTurnOrder[OrderIndex].ObjectID));
		if ( PlayerState != None )
		{
			// Looking for our team.
			if( PlayerState.GetTeam() == NewGroup.TeamName )
			{
				InsertGroupByInitiativePriority(OrderIndex + 1, NewGroup, BattleData);
				NewGroup.bShouldRemoveFromInitiativeOrder = false;

				RefreshInitiativeIndex(BattleData);

				return;
			}
		}
	}

	// Player not yet in the list.  Add the player at the end.
	foreach NewGameState.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if( PlayerState.GetTeam() == NewGroup.TeamName )
		{
			BattleData.PlayerTurnOrder.AddItem(PlayerState.GetReference());
		}
	}
	// Add the new group to the end of the list.
	BattleData.PlayerTurnOrder.AddItem(NewGroup.GetReference());
	NewGroup.bShouldRemoveFromInitiativeOrder = false;

	RefreshInitiativeIndex(BattleData);
}

simulated function RemoveGroupFromInitiativeOrder(XComGameState_AIGroup NewGroup, XComGameState NewGameState)
{
	local XComGameState_BattleData BattleData;
	local int OrderIndex;
	local XComGameState_AIGroup GroupState;

	if( NewGroup.TeamName == eTeam_XCom && NewGroup.m_arrMembers.Length > 1 )
	{
		`redscreen("WARNING! It looks like the primary XCom group is being removed from the Initiative order.  THIS IS A VERY BAD THING. @dkaplan");
	}

	BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	// Look for the new group's team in the order list.  
	for( OrderIndex = 0; OrderIndex < BattleData.PlayerTurnOrder.Length; ++OrderIndex )
	{
		GroupState = XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(BattleData.PlayerTurnOrder[OrderIndex].ObjectID));
		if( GroupState != None && GroupState.ObjectID == NewGroup.ObjectID )
		{
			BattleData.PlayerTurnOrder.Remove(OrderIndex, 1);
			break;
		}
	}

	NewGroup.bShouldRemoveFromInitiativeOrder = true;

	RefreshInitiativeIndex(BattleData);
}

function ApplyStartOfMatchConditions()
{
	
}

simulated function LoadMap()
{

		
	//Check whether the map has been generated already
	if( ParcelManager.arrParcels.Length == 0 )
	{	
		`MAPS.RemoveAllStreamingMaps(); //Generate map requires there to be NO streaming maps when it starts



	}
	else
	{
		ReleaseScriptLog( "Tactical Load Debug: Skipping Load Map due to ParcelManager parcel length "@ParcelManager.arrParcels.Length );
	}
}

private function AddCharacterStreamingCinematicMaps(bool bBlockOnLoad = false)
{
	local X2CharacterTemplateManager TemplateManager;
	local XComGameStateHistory History;
	local X2CharacterTemplate CharacterTemplate;
	local XComGameState_Unit UnitState;
	local array<string> MapNames;
	local string MapName;

	History = `XCOMHISTORY;
	TemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();

	// Force load any specified maps
	MapNames = ForceLoadCinematicMaps;

	// iterate each unit on the map and add it's cinematic maps to the list of maps
	// we need to load
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		CharacterTemplate = TemplateManager.FindCharacterTemplate(UnitState.GetMyTemplateName());
		if (CharacterTemplate != None)
		{
			foreach CharacterTemplate.strMatineePackages(MapName)
			{
				if(MapName != "" && MapNames.Find(MapName) == INDEX_NONE)
				{
					MapNames.AddItem(MapName);
				}
			}
		}
	}

	// and then queue the maps for streaming
	foreach MapNames(MapName)
	{
		`log( "Adding matinee map" $ MapName,,'XCom_Content' );
		`MAPS.AddStreamingMap(MapName, , , bBlockOnLoad).bForceNoDupe = true;
	}
}

private function AddBreachStreamingCinematicMaps(bool bBlockOnLoad = false)
{
	local int Index;
	local LevelStreaming LvlStreaming;

	for (Index = 0; Index < class'X2CinematicShotLibrary'.default.AbilityShotDefinitions.Length; ++Index)
	{
		LvlStreaming = `MAPS.AddStreamingMap(class'X2CinematicShotLibrary'.default.AbilityShotDefinitions[Index].MatineePackage, , , bBlockOnLoad);

		if (LvlStreaming != None)
		{
			LvlStreaming.bForceNoDupe = true;
		}
		else
		{
			`RedScreen("Can not load Breach Cinematic Map "$class'X2CinematicShotLibrary'.default.AbilityShotDefinitions[Index].MatineePackage$" @Brian Twoomey");
		}
		
	}
}

function EndReplay()
{

}

// Used in Tutorial mode to put the state back into 'PerformingReplay'
function ResumeReplay()
{
	GotoState('PerformingReplay');
}
function EventListenerReturn HandleNeutralReactionsOnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	// Kick off civilian movement when an enemy unit takes a shot nearby.
	local XComGameState_Ability ActivatedAbilityState;
	local XComGameStateContext_Ability ActivatedAbilityStateContext;
	local XComGameState_Unit SourceUnitState;
	local XComGameState_Item WeaponState;
	local int SoundRange;
	local float SoundRangeUnitsSq;
	local TTile SoundTileLocation;
	local Vector SoundLocation;
	local XComGameStateHistory History;
	local StateObjectReference CivilianPlayerRef;
	local array<GameRulesCache_VisibilityInfo> VisInfoList;
	local GameRulesCache_VisibilityInfo VisInfo;
	local XComGameState_Unit CivilianState;
	local array<XComGameState_Unit> Civilians;
	local XComGameState_BattleData Battle;
	local bool bAIAttacksCivilians;
	local XGUnit Civilian;
	local XGAIPlayer_Civilian CivilianPlayer;
	local XGAIBehavior_Civilian CivilianBehavior;

	History = `XCOMHISTORY;
	Battle = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	bAIAttacksCivilians = Battle.AreCiviliansAlienTargets();
	if( bAIAttacksCivilians )
	{
		ActivatedAbilityStateContext = XComGameStateContext_Ability(GameState.GetContext());
		SourceUnitState = XComGameState_Unit(History.GetGameStateForObjectID(ActivatedAbilityStateContext.InputContext.SourceObject.ObjectID));
		ActivatedAbilityState = XComGameState_Ability(EventData);
		if( SourceUnitState.ControllingPlayerIsAI() && ActivatedAbilityState.DoesAbilityCauseSound() )
		{
			if( ActivatedAbilityStateContext != None && ActivatedAbilityStateContext.InputContext.ItemObject.ObjectID > 0 )
			{
				WeaponState = XComGameState_Item(GameState.GetGameStateForObjectID(ActivatedAbilityStateContext.InputContext.ItemObject.ObjectID));
				if( WeaponState != None )
				{
					SoundRange = WeaponState.GetItemSoundRange();
					SoundRangeUnitsSq = Square(`METERSTOUNITS(SoundRange));
					// Find civilians within sound range of the source and target, and add them to the list of civilians to react.
					if( SoundRange > 0 )
					{
						CivilianPlayerRef = class'X2TacticalVisibilityHelpers'.static.GetPlayerFromTeamEnum(eTeam_Neutral);
						// Find civilians in range of the source location.
						SoundTileLocation = SourceUnitState.TileLocation;
						class'X2TacticalVisibilityHelpers'.static.GetAllTeamUnitsForTileLocation(SoundTileLocation, CivilianPlayerRef.ObjectID, eTeam_Neutral, VisInfoList);
						foreach VisInfoList(VisInfo)
						{
							if( VisInfo.DefaultTargetDist < SoundRangeUnitsSq )
							{
								CivilianState = XComGameState_Unit(History.GetGameStateForObjectID(VisInfo.SourceID));
								if( !CivilianState.bRemovedFromPlay && Civilians.Find(CivilianState) == INDEX_NONE )
								{
									Civilians.AddItem(CivilianState);
								}
							}
						}

						// Also find civilians in range of the target location.
						if( ActivatedAbilityStateContext.InputContext.TargetLocations.Length > 0 )
						{
							VisInfoList.Length = 0;
							SoundLocation = ActivatedAbilityStateContext.InputContext.TargetLocations[0];
							class'X2TacticalVisibilityHelpers'.static.GetAllTeamUnitsForLocation(SoundLocation, CivilianPlayerRef.ObjectID, eTeam_Neutral, VisInfoList);
							foreach VisInfoList(VisInfo)
							{
								if( VisInfo.DefaultTargetDist < SoundRangeUnitsSq )
								{
									CivilianState = XComGameState_Unit(History.GetGameStateForObjectID(VisInfo.SourceID));
									if( !CivilianState.bRemovedFromPlay && Civilians.Find(CivilianState) == INDEX_NONE )
									{
										Civilians.AddItem(CivilianState);
									}
								}
							}
						}

						// Adding civilian target unit if not dead.  
						CivilianState = XComGameState_Unit(History.GetGameStateForObjectID(ActivatedAbilityStateContext.InputContext.PrimaryTarget.ObjectID));
						if(CivilianState != none
						   && CivilianState.GetTeam() == eTeam_Neutral 
						   && CivilianState.IsAlive() 
						   && !CivilianState.bRemovedFromPlay 
						   && Civilians.Find(CivilianState) == INDEX_NONE )
						{
							Civilians.AddItem(CivilianState);
						}

						LastNeutralReactionEventChainIndex = History.GetEventChainStartIndex();
						CivilianPlayer = XGBattle_SP(`BATTLE).GetCivilianPlayer();
						CivilianPlayer.InitTurn();

						// Any civilians we've found in range will now run away.
						foreach Civilians(CivilianState)
						{
							Civilian = XGUnit(CivilianState.GetVisualizer());

							CivilianBehavior = XGAIBehavior_Civilian(Civilian.m_kBehavior);
							if (CivilianBehavior != none)
							{
								CivilianBehavior.InitActivate();
								CivilianState.AutoRunBehaviorTree();
								CivilianPlayer.AddToMoveList(Civilian);
							}
						}
					}
				}
			}
		}
	}
	return ELR_NoInterrupt;
}

function EventListenerReturn HandleNeutralReactionsOnMovement(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) 
{
	local XComGameState_Unit MovedUnit, CivilianState;
	local array<XComGameState_Unit> Civilians;
	local XComGameState_Player PlayerState;
	local XComGameStateHistory History;
	local XComGameState_BattleData Battle;
	local XGAIPlayer_Civilian CivilianPlayer;
	local XGUnit Civilian;
	local bool bAIAttacksCivilians, bCiviliansRunFromXCom;
	local int EventChainIndex;
	local TTile MovedToTile;
	local float MaxTileDistSq;
	local GameRulesCache_VisibilityInfo OutVisInfo;
	local ETeam MoverTeam;
	local XGAIBehavior_Civilian CivilianBehavior;

	MovedUnit = XComGameState_Unit( EventData );
	MoverTeam = MovedUnit.GetTeam();
	if( MovedUnit.IsMindControlled() )
	{
		MoverTeam = MovedUnit.GetPreviousTeam();
	}
	if( (MovedUnit == none) || MovedUnit.GetMyTemplate().bIsCosmetic || (XGUnit(MovedUnit.GetVisualizer()).m_eTeam == eTeam_Neutral) )
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;
	Battle = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	bCiviliansRunFromXCom = Battle.CiviliansAreHostile();
	bAIAttacksCivilians = Battle.AreCiviliansAlienTargets();

	if (!bCiviliansRunFromXCom && MoverTeam == eTeam_XCom)
	{
		return ELR_NoInterrupt;
	}

	// In missions where AI doesn't attack civilians, do nothing if the player or the mover is concealed.
	if(!bAIAttacksCivilians )
	{
		// If XCom is in squad concealment, don't move.
		foreach History.IterateByClassType(class'XComGameState_Player', PlayerState, eReturnType_Reference)
		{
			if( PlayerState.PlayerClassName == Name("XGPlayer") )
			{
				if( PlayerState.bSquadIsConcealed )
				{
					return ELR_NoInterrupt; // Do not move if squad concealment is active.
				}
				break;
			}
		}

		if( MovedUnit.IsConcealed() && bCiviliansRunFromXCom )
		{
			return ELR_NoInterrupt;
		}
	}
	else
	{
		// Addendum from Brian - only move civilians from Aliens when the alien that moves is out of action points.
		if( (MoverTeam == eTeam_Alien || MoverTeam == eTeam_TheLost) && MovedUnit.NumAllActionPoints() > 0 && MovedUnit.IsMeleeOnly() )
		{
			return ELR_NoInterrupt;
		}
	}

	// Only kick off civilian behavior once per event chain.
	EventChainIndex = History.GetEventChainStartIndex();
	if( EventChainIndex == LastNeutralReactionEventChainIndex )
	{
		return ELR_NoInterrupt;
	}
	LastNeutralReactionEventChainIndex = EventChainIndex;

	// All civilians in range now update.
	CivilianPlayer = XGBattle_SP(`BATTLE).GetCivilianPlayer();
	CivilianPlayer.InitTurn();
	CivilianPlayer.GetPlayableUnits(Civilians);

	MovedToTile = MovedUnit.TileLocation;
	MaxTileDistSq = Square(class'XGAIBehavior_Civilian'.default.CIVILIAN_NEAR_STANDARD_REACT_RADIUS);

	// Kick off civilian behavior tree if it is in range of the enemy.
	foreach Civilians(CivilianState)
	{
		if (CivilianState.bTriggerRevealAI == false) 
		{
			continue;
		}
		// Let kismet handle XCom rescue behavior.
		if( bAIAttacksCivilians && !CivilianState.IsAlien() && MoverTeam == eTeam_XCom )
		{
			continue;
		}
		// Let the Ability trigger system handle Faceless units when XCom moves into range. 
		if( CivilianState.IsAlien() && MoverTeam == eTeam_XCom )
		{
			continue;
		}

		// Non-rescue behavior is kicked off here.
		if( class'Helpers'.static.IsTileInRange(CivilianState.TileLocation, MovedToTile, MaxTileDistSq) 
		   && VisibilityMgr.GetVisibilityInfo(MovedUnit.ObjectID, CivilianState.ObjectID, OutVisInfo)
			&& OutVisInfo.bVisibleGameplay )
		{
			Civilian = XGUnit(CivilianState.GetVisualizer());
			
			CivilianBehavior = XGAIBehavior_Civilian(Civilian.m_kBehavior);
			if (CivilianBehavior != none)
			{
				CivilianBehavior.InitActivate();
				CivilianState.AutoRunBehaviorTree();
				CivilianPlayer.AddToMoveList(Civilian);
			}
		}
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn DIO_HandleNeutralReactionsOnMovement(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) 
{
	local XComGameState_Unit MovedUnit, CivilianState;
	local array<XComGameState_Unit> Civilians;
	local XComGameStateHistory History;
	local XGAIPlayer_Civilian CivilianPlayer;
	local XGUnit Civilian;
	local int EventChainIndex;
	local TTile MovedToTile;
	local float MaxTileDistSqToXCom, MaxTileDistSqToAlien;
	local GameRulesCache_VisibilityInfo OutVisInfo;
	local ETeam MoverTeam;
	local XGAIBehavior_Civilian CivilianBehavior;

	local array<XComGameState_Unit> XComUnits;
	local XComGameState_Unit XComUnit;
	local XGPlayer XComPlayer;

	MovedUnit = XComGameState_Unit( EventData );
	MoverTeam = MovedUnit.GetTeam();
	if( MovedUnit.IsMindControlled() )
	{
		MoverTeam = MovedUnit.GetPreviousTeam();
	}
	if( `BATTLE.GetDesc().bInBreachPhase || (MovedUnit == none) || MovedUnit.GetMyTemplate().bIsCosmetic ) //|| (XGUnit(MovedUnit.GetVisualizer()).m_eTeam == eTeam_Neutral) )
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;


	if( (MoverTeam == eTeam_Alien || MoverTeam == eTeam_TheLost) && MovedUnit.NumAllActionPoints() > 0 && MovedUnit.IsMeleeOnly() )
	{
		return ELR_NoInterrupt;
	}

	// Only kick off civilian behavior once per event chain.
	EventChainIndex = History.GetEventChainStartIndex();
	if( EventChainIndex == LastNeutralReactionEventChainIndex )
	{
		return ELR_NoInterrupt;
	}
	LastNeutralReactionEventChainIndex = EventChainIndex;

	// All civilians in range now update.
	CivilianPlayer = XGBattle_SP(`BATTLE).GetCivilianPlayer();
	CivilianPlayer.InitTurn();
	CivilianPlayer.GetPlayableUnits(Civilians);

	MovedToTile = MovedUnit.TileLocation;
	MaxTileDistSqToXCom = Square(1.5f);	//xcom must be adjacent or diagonal to rescue civilian
	MaxTileDistSqToAlien = Square( default.DIO_CIVILIAN_NEAR_ALIEN_REACT_RADIUS );

	if( MovedUnit.IsCivilian() )
	{
		CivilianState = MovedUnit;
		if( !CivilianState.GetMyTemplate().bIsVIP && CivilianState.bTriggerRevealAI )
		{
			XComPlayer = XGBattle_SP(`BATTLE).GetHumanPlayer();
			XComPlayer.GetPlayableUnits(XComUnits, true);
			foreach XComUnits( XComUnit )
			{
				if( class'Helpers'.static.IsTileInRange( XComUnit.TileLocation, MovedToTile, MaxTileDistSqToXCom )
					&& VisibilityMgr.GetVisibilityInfo( XComUnit.ObjectID, CivilianState.ObjectID, OutVisInfo )
					&& OutVisInfo.bVisibleGameplay )
				{
					// Kick off civilian exit behavior.
					Civilian = XGUnit(CivilianState.GetVisualizer());
					XGAIBehavior_Civilian( Civilian.m_kBehavior ).InitActivate(); // Give action points before attempting to move.
					Civilian.m_kBehavior.InitTurn( false );
					class'X2AIBTDefaultActions'.static.RunCivilianExitMap( CivilianState, XComUnit );
					CivilianPlayer = XGAIPlayer_Civilian( Civilian.GetPlayer() );
					CivilianPlayer.AddToMoveList( Civilian );
					break;
				}
			}
		}
	}
	else if ( XGUnit(MovedUnit.GetVisualizer()).m_eTeam != eTeam_Neutral )
	{
		// Kick off civilian behavior tree if it is in range of the enemy.
		foreach Civilians(CivilianState)
		{
			if (CivilianState.bTriggerRevealAI == false || CivilianState.GetMyTemplate().bIsVIP) 
			{
				continue;
			}
			//auto rescue if the mover is xcom, and unit is not VIP
			if( MoverTeam == eTeam_XCom && !CivilianState.GetMyTemplate().bIsVIP )
			{
				if( class'Helpers'.static.IsTileInRange( CivilianState.TileLocation, MovedToTile, MaxTileDistSqToXCom )
					&& VisibilityMgr.GetVisibilityInfo( MovedUnit.ObjectID, CivilianState.ObjectID, OutVisInfo )
					&& OutVisInfo.bVisibleGameplay )
				{
					// Kick off civilian exit behavior.
					Civilian = XGUnit(CivilianState.GetVisualizer());
					XGAIBehavior_Civilian( Civilian.m_kBehavior ).InitActivate(); // Give action points before attempting to move.
					Civilian.m_kBehavior.InitTurn( false );
					class'X2AIBTDefaultActions'.static.RunCivilianExitMap( CivilianState, MovedUnit );
					CivilianPlayer = XGAIPlayer_Civilian( Civilian.GetPlayer() );
					CivilianPlayer.AddToMoveList( Civilian );
				}
			}
			else if ( MoverTeam == eTeam_Alien )
			{
				if( class'Helpers'.static.IsTileInRange(CivilianState.TileLocation, MovedToTile, MaxTileDistSqToAlien) &&
					VisibilityMgr.GetVisibilityInfo(MovedUnit.ObjectID, CivilianState.ObjectID, OutVisInfo) &&
					OutVisInfo.bVisibleGameplay &&
					(`SYNC_RAND(100) < default.DIO_CIVILIAN_FLEE_ALIEN_CHANCE) )
				{
					Civilian = XGUnit(CivilianState.GetVisualizer());

					CivilianBehavior = XGAIBehavior_Civilian(Civilian.m_kBehavior);
					if (CivilianBehavior != none)
					{
						CivilianBehavior.InitActivate();
						CivilianState.AutoRunBehaviorTree();
						CivilianPlayer.AddToMoveList(Civilian);
					}
				}
			}
		}
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn HandleUnitDiedCache(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) 
{
	local XComGameState_Unit DeadUnit;

	DeadUnit = XComGameState_Unit( EventData );

	if( (DeadUnit == none) || DeadUnit.GetMyTemplate().bIsCosmetic )
	{
		return ELR_NoInterrupt;
	}

	CachedDeadUnits.AddItem(DeadUnit.GetReference());

	return ELR_NoInterrupt;
}

function EventListenerReturn HandleCivilianRescued(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;
	local XComGameState_BattleData BattleData;

	// Track count for Strategy-side rewards
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Count Civilians Rescued");
	
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
	BattleData.NumRescuedCivilians++;

	SubmitGameState(NewGameState);
	return ELR_NoInterrupt;
}

function EventListenerReturn HandleCivilianRescuedVisCompleted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	// trigger rescue VO,  EventSource is the civilian,  EventData is rescuer
	`XEVENTMGR.TriggerEvent('AbilRescueCivilian', EventSource, EventData, GameState);

	return ELR_NoInterrupt;
}

simulated function bool CanToggleWetness()
{
	local XComGameState_BattleData BattleDataState;
	local PlotDefinition PlotDef;
	local bool bWet;
	local string strMissionType;	

	BattleDataState = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	bWet = false;
	strMissionType = "";
	if (BattleDataState != none)
	{
		PlotDef = `PARCELMGR.GetPlotDefinition(BattleDataState.MapData.PlotMapName);

		// much hackery follows...
		// using LightRain for precipitation without sound effects and lightning, and LightStorm for precipitation with sounds effects and lightning
		switch (PlotDef.strType)
		{
		case "Shanty":
			// This could be cleaner without all the calls to XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(),
			// but attempting to use a variable required modifying what this class depends on. That resulted in some unreal weirdness that changed some headers
			// and functions that I never touched, which I wasn't comfortable with.
			XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(LightRain, 0, 0, 0);			
			break;
		case "Facility":
		case "DerelictFacility":
		case "LostTower":
		case "Tunnels_Sewer":
		case "Tunnels_Subway":
			XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(NoStorm, 0, 0, 0);
			break;
		default:
			// PsiGate acts like Shanty above, but it's a mission, not a plotType
			strMissionType = BattleDataState.MapData.ActiveMission.sType;
			if (strMissionType == "GP_PsiGate")
			{
				XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(LightRain, 0, 0, 0);
			}
			else if (BattleDataState.bRainIfPossible)
			{
				// Nothing for Arid. Tundra gets snow only. Temperate gets wetness, precipitation, sound effects and lightning.
				if (BattleDataState.MapData.Biome == "" || BattleDataState.MapData.Biome == "Temperate" || PlotDef.strType == "CityCenter" || PlotDef.strType == "Slums")
				{					
					XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(LightStorm, 0, 0, 0);
					bWet = true;
				}
				else if (BattleDataState.MapData.Biome == "Tundra")
				{
					XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(LightRain, 0, 0, 0);
				}
				else
				{
					XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(NoStorm, 0, 0, 0);
				}
			}
			else
			{
				XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(NoStorm, 0, 0, 0);
			}
			break;
		}
	}
	else
	{
		XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().SetStormIntensity(NoStorm, 0, 0, 0);
	}

	return bWet;
}

// Do any specific remote events related to environment lighting
simulated function EnvironmentLightingRemoteEvents()
{
	local XComGameState_BattleData BattleDataState;

	BattleDataState = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	// Forge only check to change the height fog actors to mask out the underneath of forge parcel that can be seen through glass floors (yay run on sentence)
	if (BattleDataState.MapData.PlotMapName != "" && arrHeightFogAdjustedPlots.Find(BattleDataState.MapData.PlotMapName) != INDEX_NONE)
	{
		`XCOMGRI.DoRemoteEvent('ModifyHeightFogActorProperties');
	}
}

// Call after abilities are initialized in post begin play, which may adjust stats.
// This function restores all transferred units' stats to their pre-transfer values, 
// to help maintain the illusion of one continuous mission
simulated private function RestoreDirectTransferUnitStats()
{
	local XComGameState NewGameState;
	local XComGameState_BattleData BattleData;
	local DirectTransferInformation_UnitStats UnitStats;
	local XComGameState_Unit UnitState;
	local XComGameState_Effect_TemplarFocus FocusEffect;
	local XComGameState_Item ItemState;
	local int ItemIndex;

	BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if(!BattleData.DirectTransferInfo.IsDirectMissionTransfer)
	{
		return;
	}

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Restore Transfer Unit Stats");

	foreach BattleData.DirectTransferInfo.TransferredUnitStats(UnitStats)
	{
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitStats.UnitStateRef.ObjectID));
		UnitState.SetCurrentStat(eStat_HP, UnitStats.HP);
		UnitState.AddShreddedValue(UnitStats.ArmorShred);
		UnitState.LowestHP = UnitStats.LowestHP;
		UnitState.HighestHP = UnitStats.HighestHP;
		UnitState.MissingHP = UnitStats.MissingHP;

		if (UnitStats.FocusAmount > 0)
		{
			FocusEffect = UnitState.GetTemplarFocusEffectState();
			if (FocusEffect != none)
			{
				FocusEffect = XComGameState_Effect_TemplarFocus(NewGameState.ModifyStateObject(FocusEffect.Class, FocusEffect.ObjectID));
				FocusEffect.SetFocusLevel(UnitStats.FocusAmount, UnitState, NewGameState, true);
			}
		}
		if( UnitStats.WeaponAmmo.Length == UnitState.InventoryItems.Length )
		{
			for( ItemIndex = 0; ItemIndex < UnitStats.WeaponAmmo.Length; ++ItemIndex )
			{
				ItemState = XComGameState_Item( NewGameState.ModifyStateObject(class'XComGameState_Item', UnitState.InventoryItems[ItemIndex].ObjectID) );
				ItemState.Ammo = UnitStats.WeaponAmmo[ItemIndex];
			}
		}
	}

	SubmitGameState(NewGameState);
}

simulated function BeginTacticalPlay()
{
	local XComGameState_BaseObject ObjectState, NewObjectState;
	local XComGameState_Ability AbilityState;
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Begin Tactical Play");

	foreach CachedHistory.IterateByClassType(class'XComGameState_BaseObject', ObjectState)
	{
		NewObjectState = NewGameState.ModifyStateObject(ObjectState.Class, ObjectState.ObjectID);
		NewObjectState.bInPlay = false;
	}

	bTacticalGameInPlay = true;

	// have any abilities that are post play activated start up
	foreach CachedHistory.IterateByClassType(class'XComGameState_Ability', AbilityState)
	{
		if(AbilityState.OwnerStateObject.ObjectID > 0)
		{
			AbilityState.CheckForPostBeginPlayActivation( NewGameState );
		}
	}

	// iterate through all existing state objects and call BeginTacticalPlay on them
	foreach NewGameState.IterateByClassType(class'XComGameState_BaseObject', ObjectState)
	{
		ObjectState.BeginTacticalPlay(NewGameState);
	}

	// if we're playing a challenge, don't do much encounter vo
	if (CachedHistory.GetSingleGameStateObjectForClass( class'XComGameState_ChallengeData', true ) != none)
	{
		`CHEATMGR.DisableFirstEncounterVO = true;
	}

	class'XComGameState_BattleData'.static.MarkBattlePlayableTime();
	`XEVENTMGR.TriggerEvent('OnTacticalBeginPlay', self, , NewGameState);

	SubmitGameState(NewGameState);

	RestoreDirectTransferUnitStats();
}

simulated function EndTacticalPlay()
{
	local XComGameState_BaseObject ObjectState, NewObjectState;
	local XComGameState NewGameState;
	local X2EventManager EventManager;
	local Object ThisObject;

	bTacticalGameInPlay = false;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("End Tactical Play");

	// iterate through all existing state objects and call EndTacticalPlay on them
	foreach CachedHistory.IterateByClassType(class'XComGameState_BaseObject', ObjectState)
	{
		if (!ObjectState.bTacticalTransient)
		{
			NewObjectState = NewGameState.ModifyStateObject( ObjectState.Class, ObjectState.ObjectID );
			NewObjectState.EndTacticalPlay( NewGameState );
		}
		else
		{
			ObjectState.EndTacticalPlay( NewGameState );
		}		
	}

	EventManager = `XEVENTMGR;
		ThisObject = self;

	EventManager.UnRegisterFromEvent(ThisObject, 'UnitMoveFinished');
	EventManager.UnRegisterFromEvent(ThisObject, 'UnitDied');

	SubmitGameState(NewGameState);
}

static function name GetObjectiveLootTable(MissionObjectiveDefinition MissionObj)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;
	local name LootTableName;
	local int CurrentForceLevel, HighestValidForceLevel, idx;

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	CurrentForceLevel = AlienHQ.GetForceLevel();

	if (MissionObj.SuccessLootTables.Length == 0)
	{
		return ''; 
	}

	HighestValidForceLevel = -1;

	for(idx = 0; idx < MissionObj.SuccessLootTables.Length; idx++)
	{
		if(CurrentForceLevel >= MissionObj.SuccessLootTables[idx].ForceLevel &&
		   MissionObj.SuccessLootTables[idx].ForceLevel > HighestValidForceLevel)
		{
			HighestValidForceLevel = MissionObj.SuccessLootTables[idx].ForceLevel;
			LootTableName = MissionObj.SuccessLootTables[idx].LootTableName;
		}
	}

	return LootTableName;
}
function SetupBuildingVisForEncounter( )
{
	local XComBuildingVisManager VisMgr;
	local XComGameState_BattleData BattleData;

	BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

	foreach `XWORLDINFO.AllActors(class'XComBuildingVisManager', VisMgr) { VisMgr.ResetEncounter(); VisMgr.AddEncounter(BattleData.BreachingRoomID); }
}

function SetupBuildingVisForBreach( )
{
	local XComBuildingVisManager VisMgr;
	local XComGameState_BattleData BattleData;
	local int iPreviousEncounterIdx;

	BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

	// When setting up breach, we want the previous encounter that we just 'left' to remain Seen until breach is confirmed
	iPreviousEncounterIdx = Clamp(BattleData.BreachingRoomListIndex-1, 0, BattleData.MapData.RoomIDs.Length-1);

	foreach `XWORLDINFO.AllActors(class'XComBuildingVisManager', VisMgr) { VisMgr.ResetEncounter(); VisMgr.AddEncounter(BattleData.MapData.RoomIDs[iPreviousEncounterIdx]); VisMgr.AddEncounter(BattleData.BreachingRoomID); }
}

function HideDeploymentSpawns()
{
	local array<XComDeploymentSpawn> DeploymentSpawnActors;
	local XComDeploymentSpawn DeploySpawn;

	// Set rooms to never have seen, hide deployment spawners
	`XWORLD.GetDeploymentSpawnActors(DeploymentSpawnActors, -1);
	foreach DeploymentSpawnActors(DeploySpawn)
	{
		DeploySpawn.SetVisible(false);
	}
}

function SetupFOWStatus_Breach()
{
	local XComGameState_BattleData BattleData;
	local int i;
	local int iPreviousEncounterIdx;
	local int RoomIndexBeforeTruncation;
	BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

	`XWORLD.InitializeRoomFOWStatus(eFOWTileStatus_NeverSeen);

	// Update the FOW
	if (`DIO_DEBUG_ALL_ROOMS_VISIBLE)
	{
		for (i = 0; i < BattleData.MapData.RoomIDs.Length; i++)
		{
			`XWORLD.RevealRoomByID(BattleData.MapData.RoomIDs[i], eFOWTileStatus_Seen);
		}
	}
	else
	{				
		// BreachMarkupDef contains the original room sequence before encounter truncation happens
		RoomIndexBeforeTruncation = BattleData.MapData.BreachMarkupDef.RoomSequence.Find(BattleData.BreachingRoomID);

		// When setting up breach, we want the previous encounter that we just 'left' to remain Seen until breach is confirmed
		iPreviousEncounterIdx = Clamp(RoomIndexBeforeTruncation - 1, 0, BattleData.MapData.BreachMarkupDef.RoomSequence.Length-1);
		for (i = 0; i < iPreviousEncounterIdx; i++)
		{
			`XWORLD.RevealRoomByID(BattleData.MapData.BreachMarkupDef.RoomSequence[i], eFOWTileStatus_HaveSeen);
		}

		`XWORLD.RevealRoomByID(BattleData.MapData.BreachMarkupDef.RoomSequence[iPreviousEncounterIdx], eFOWTileStatus_Seen);
	   	`XWORLD.RevealRoomByID(BattleData.MapData.RoomIDs[BattleData.BreachingRoomListIndex], eFOWTileStatus_Seen);
	}
}

function SetupFOWStatus_Encounter()
{
	local XComGameState_BattleData BattleData;
	local int i;
	BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));


   	`XWORLD.InitializeRoomFOWStatus(eFOWTileStatus_NeverSeen);

	// Update the FOW
	if (`DIO_DEBUG_ALL_ROOMS_VISIBLE)
	{
		for (i = 0; i < BattleData.MapData.RoomIDs.Length; i++)
		{
			`XWORLD.RevealRoomByID(BattleData.MapData.RoomIDs[i], eFOWTileStatus_Seen);
		}
	}
	else
	{
		// We have in breach placement mode but haven't breached yet. We want to keep the previous 
		for (i = 0; i < BattleData.MapData.RoomIDs.Length && BattleData.MapData.RoomIDs[i] != BattleData.BreachingRoomID; i++)
		{
			`XWORLD.RevealRoomByID(BattleData.MapData.RoomIDs[i], eFOWTileStatus_HaveSeen);
		}

		`XWORLD.RevealRoomByID(BattleData.BreachingRoomID, eFOWTileStatus_Seen);
	}
}

function StartStatePositionUnits()
{
	local XComGameState StartState;		
	local XComGameState_Player PlayerState;
	local XComGameState_Unit UnitState;
	local array<XComGameState_Unit> UnitStates;
	local XComGameState_BattleData BattleData;
	
	local vector vSpawnLoc;
	local XComGroupSpawn kSoldierSpawn;
	local array<vector> FloorPoints;

	local array<BreachEntryPointMarker> BreachEntryPoints;
	local BreachEntryPointMarker BreachEntryPoint;
	local XComWorldData WorldData;
	local XGUnit UnitVisualizer;

	StartState = CachedHistory.GetStartState();
	ParcelManager = `PARCELMGR; // make sure this is cached
	WorldData = `XWORLD;
	foreach StartState.IterateByClassType(class'XComGameState_BattleData', BattleData) { break; }

	//If this is a start state, we need to additional processing. Place the player's
	//units. Create and place the AI player units.
	//======================================================================
	if( StartState != none )
	{
		if (bEnableBreachMode)
		{
			WorldData.GetBreachEntryPointActors(BreachEntryPoints);
			`assert(BreachEntryPoints.length > 0);
			BreachEntryPoint = BreachEntryPoints[0];

			// stack all xcom units on the breach entry point tile
			foreach StartState.IterateByClassType(class'XComGameState_Unit', UnitState, eReturnType_Reference)
			{
				`assert(UnitState.bReadOnly == false);
				PlayerState = XComGameState_Player(StartState.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID, eReturnType_Reference));
				if (PlayerState != None && PlayerState.TeamFlag == ETeam.eTeam_XCom && UnitState.ControllingPlayer.ObjectID == PlayerState.ObjectID)
				{
					UnitState.bRequiresVisibilityUpdate = true;
					UnitState.SetVisibilityLocationFromVector(BreachEntryPoint.Location);
					UnitVisualizer = XGUnit(UnitState.GetVisualizer());
					UnitVisualizer.SetForceVisibility(eForceNotVisible);
					UnitVisualizer.GetPawn().UpdatePawnVisibility();
					UnitState.AssignedToRoomID = BattleData.MapData.RoomIDs[0]; // assign room to the first breaching room
				}
			}
		}
		else
		{
			// some missions can disable breach mode, in which case we use XComGroupSpawn for spawning xcom units
			foreach `XWORLDINFO.AllActors(class'XComGroupSpawn', kSoldierSpawn) 
			{
				if (kSoldierSpawn.BreachRoomID == BattleData.MapData.RoomIDs[0])
				{
					break;
				}
			}

			ParcelManager.ParcelGenerationAssert(kSoldierSpawn != none, "No Soldier Spawn found when positioning units!");
			kSoldierSpawn.GetValidFloorLocations(FloorPoints, BattleData.MapData.ActiveMission.SquadSpawnSizeOverride);
			ParcelManager.ParcelGenerationAssert(FloorPoints.Length > 0, "No valid floor points for spawn: " $ kSoldierSpawn);

			//Updating the positions of the units
			class'Helpers'.static.GatherUnitStates(UnitStates, eTeam_XCom, StartState);
			foreach UnitStates(UnitState)
			{
				`assert(UnitState.bReadOnly == false);

				vSpawnLoc = FloorPoints[`SYNC_RAND_TYPED(FloorPoints.Length)];
				FloorPoints.RemoveItem(vSpawnLoc);

				UnitState.SetVisibilityLocationFromVector(vSpawnLoc);
				`XWORLD.SetTileBlockedByUnitFlag(UnitState);
				UnitState.AssignedToRoomID = BattleData.MapData.RoomIDs[0];
			}
		}
	}
}

native function AddKismetSpawnedUnitPackages();

/// <summary>
/// Cycles through building volumes and update children floor volumes and extents. Needs to happen early in loading, before units spawn.
/// </summary>
simulated function InitVolumes()
{
	local XComBuildingVolume kVolume;
	local XComMegaBuildingVolume kMegaVolume;

	foreach WorldInfo.AllActors(class 'XComBuildingVolume', kVolume)
	{
		if (kVolume != none)   // Hack to eliminate tree break
		{
			kVolume.CacheBuildingVolumeInChildrenFloorVolumes();
			kVolume.CacheFloorCenterAndExtent();
		}
	}

	foreach WorldInfo.AllActors(class 'XComMegaBuildingVolume', kMegaVolume)
	{
		if (kMegaVolume != none)
		{
			kMegaVolume.InitInLevel();
			kMegaVolume.CacheBuildingVolumeInChildrenFloorVolumes();
			kMegaVolume.CacheFloorCenterAndExtent();
		}
	}
}

simulated function bool ShowUnitFlags( )
{
	return true;
}


/// <summary>
/// This state is entered if the tactical game being played need to be set up first. Setup handles placing units, creating scenario
/// specific game states, processing any scenario kismet logic, etc.
/// </summary>
simulated state CreateTacticalGame
{
	simulated event BeginState(name PreviousStateName)
	{
		local X2EventManager EventManager;
		local Object ThisObject;

		`SETLOC("BeginState");

		// the start state has been added by this point
		//	nothing in this state should be adding anything that is not added to the start state itself
		CachedHistory.AddHistoryLock();

		EventManager = `XEVENTMGR;
		ThisObject = self;

		EventManager.RegisterForEvent(ThisObject, 'UnitMoveFinished', DIO_HandleNeutralReactionsOnMovement, ELD_OnStateSubmitted);
		EventManager.RegisterForEvent(ThisObject, 'AbilityActivated', HandleNeutralReactionsOnAbilityActivated, ELD_OnStateSubmitted);
		EventManager.RegisterForEvent(ThisObject, 'UnitDied', HandleUnitDiedCache, ELD_OnStateSubmitted);		
		EventManager.RegisterForEvent(ThisObject, 'CivilianRescued', HandleCivilianRescued, ELD_OnStateSubmitted);
		EventManager.RegisterForEvent(ThisObject, 'CivilianRescued', HandleCivilianRescuedVisCompleted, ELD_OnVisualizationBlockCompleted);

		// allow templated event handlers to register themselves
		class'X2EventListenerTemplateManager'.static.RegisterTacticalListeners();

		`XANALYTICS.bReportedTacticalSessionEnd = false;
	}
	
	simulated function StartStateSpawnAliens(XComGameState StartState)
	{
		local XComGameState_Player IteratePlayerState;
		local XComGameState_BattleData BattleData;
		local XComGameState_MissionSite MissionSiteState;
		local XComAISpawnManager SpawnManager;
		local int AlertLevel, ForceLevel;

		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
		BattleData.EndBattleRuns = 0; //Initialize this value while we are starting

		ForceLevel = BattleData.GetForceLevel();
		AlertLevel = BattleData.GetAlertLevel();

		if( BattleData.m_iMissionID > 0 )
		{
			MissionSiteState = XComGameState_MissionSite(CachedHistory.GetGameStateForObjectID(BattleData.m_iMissionID));

			if( MissionSiteState != None && MissionSiteState.SelectedMissionData.SelectedMissionScheduleName != '' )
			{
				AlertLevel = MissionSiteState.SelectedMissionData.AlertLevel;
				ForceLevel = MissionSiteState.SelectedMissionData.ForceLevel;
			}
		}

		SpawnManager = `SPAWNMGR;
		SpawnManager.ClearCachedFireTiles();
		SpawnManager.SpawnAllAliens(ForceLevel, AlertLevel, StartState, MissionSiteState);

		// After spawning, the AI player still needs to sync the data
		foreach StartState.IterateByClassType(class'XComGameState_Player', IteratePlayerState)
		{
			if( IteratePlayerState.TeamFlag == eTeam_Alien || IteratePlayerState.TeamFlag == eTeam_TheLost )
			{				
				XGAIPlayer( CachedHistory.GetVisualizer(IteratePlayerState.ObjectID) ).UpdateDataToAIGameState(true);
				break;
			}
		}
	}

	simulated function StartStateSpawnCosmeticUnits(XComGameState StartState)
	{
		local XComGameState_Item IterateItemState;
				
		foreach StartState.IterateByClassType(class'XComGameState_Item', IterateItemState)
		{
			IterateItemState.CreateCosmeticItemUnit(StartState);
		}
	}

	function SetupPIEGame()
	{
		local XComParcel FakeObjectiveParcel;
		local MissionDefinition MissionDef;

		local Sequence GameSequence;
		local Sequence LoadedSequence;
		local array<string> KismetMaps;

		local X2DataTemplate ItemTemplate;
		local X2QuestItemTemplate QuestItemTemplate;

		// Since loading a map in PIE just gives you a single parcel and possibly a mission map, we need to
		// infer the mission type and create a fake objective parcel so that the LDs can test the game in PIE

		// This would normally be set when generating a map
		ParcelManager.TacticalMissionManager = `TACTICALMISSIONMGR;

		// Get the map name for all loaded kismet sequences
		GameSequence = class'WorldInfo'.static.GetWorldInfo().GetGameSequence();
		foreach GameSequence.NestedSequences(LoadedSequence)
		{
			// when playing in PIE, maps names begin with "UEDPIE". Strip that off.
			KismetMaps.AddItem(split(LoadedSequence.GetLevelName(), "UEDPIE", true));
		}

		// determine the mission 
		foreach ParcelManager.TacticalMissionManager.arrMissions(MissionDef)
		{
			if(KismetMaps.Find(MissionDef.MapNames[0]) != INDEX_NONE)
			{
				ParcelManager.TacticalMissionManager.ActiveMission = MissionDef;
				break;
			}
		}

		// Add a quest item in case the mission needs one. we don't care which one, just grab the first
		foreach class'X2ItemTemplateManager'.static.GetItemTemplateManager().IterateTemplates(ItemTemplate, none)
		{
			QuestItemTemplate = X2QuestItemTemplate(ItemTemplate);

			if(QuestItemTemplate != none)
			{
				ParcelManager.TacticalMissionManager.MissionQuestItemTemplate = QuestItemTemplate.DataName;
				break;
			}
		}
		
		// create a fake objective parcel at the origin
		FakeObjectiveParcel = Spawn(class'XComParcel');
		ParcelManager.ObjectiveParcel = FakeObjectiveParcel;
		ParcelManager.FinalizeRoomClearingOrder();
	}

	function bool ShowDropshipInterior()
	{
		local XComGameState_BattleData BattleData;
		local XComGameState_HeadquartersDio DioHQ;
		local XComGameState_MissionSite MissionState;
		local bool bValidMapLaunchType;
		local bool bSkyrangerTravel;

		//bsg-crobinson (7.31.17): Don't show the dropship when signing out whilst loading into a multiplayer match on console.
		if(X2TacticalMPGameRuleset(`TACTICALRULES) != none && `ISCONSOLE)
		{
			if(!`XENGINE.IsAnyMoviePlaying())
			{
				`XENGINE.PlayLoadMapMovie(0);
			}
			
			return false; 
		}
		//bsg-crobinson (7.31.17): end

		DioHQ = XComGameState_HeadquartersDio(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio'));
		if(DioHQ != none)
		{
			MissionState = XComGameState_MissionSite(CachedHistory.GetGameStateForObjectID(DioHQ.MissionRef.ObjectID));
		}

		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

		//Not TQL, test map, PIE, etc.
		bValidMapLaunchType = `XENGINE.IsSinglePlayerGame() && BattleData.MapData.PlotMapName != "" && BattleData.MapData.ParcelData.Length == 0 && !BattleData.MapData.bMonolithic;

		// bsg-dforrest (5.1.17): for missions that want skyranger travel without a dropship interior during load
		// bsg-dforrest (5.3.17): need for PC in console branch as well to load maps
		//True if we didn't seamless travel here, and the mission type wanted a skyranger travel ( ie. no avenger defense or other special mission type ), and if no loading movie is playing
		bSkyrangerTravel =	!`XCOMGAME.m_bSeamlessTraveled 
							&& (MissionState == None || MissionState.GetMissionSource().bRequiresVehicleTravel)
							&& (!MissionState.GetMissionSource().bSkyrangerTravelWithoutDropshipInterior || !class'XComEngine'.static.IsAnyMoviePlaying()); // both true block the interior
		// bsg-dforrest (5.1.17):end

		return bValidMapLaunchType && bSkyrangerTravel && !BattleData.DirectTransferInfo.IsDirectMissionTransfer;
	}

	simulated function CreateMapActorGameStates()
	{
		local XComDestructibleActor DestructibleActor;
		local X2SquadVisiblePoint SquadVisiblePoint;

		local XComGameState StartState;
		local int StartStateIndex;

		StartState = CachedHistory.GetStartState();
		if (StartState == none)
		{
			StartStateIndex = CachedHistory.FindStartStateIndex();

			StartState = CachedHistory.GetGameStateFromHistory(StartStateIndex);

			`assert(StartState != none);

		}

		foreach `BATTLE.AllActors(class'XComDestructibleActor', DestructibleActor)
		{
			DestructibleActor.GetState(StartState);
		}

		foreach `BATTLE.AllActors(class'X2SquadVisiblePoint', SquadVisiblePoint)
		{
			SquadVisiblePoint.CreateState(StartState);
		}
	}

	simulated function BuildVisualizationForStartState()
	{
		local int StartStateIndex;		
		local array<X2Action> NewlyStartedActions;

		StartStateIndex = CachedHistory.FindStartStateIndex();
		//Make sure this is a tactical game start state
		`assert( StartStateIndex > -1 );
		`assert( XComGameStateContext_TacticalGameRule(CachedHistory.GetGameStateFromHistory(StartStateIndex).GetContext()) != none );
		
		//Bootstrap the visualization mgr. Enabling processing of new game states, and making sure it knows which state index we are at.
		VisualizationMgr.EnableBuildVisualization();
		VisualizationMgr.SetCurrentHistoryFrame(StartStateIndex);

		//This will set up the visualizers that init the camera, XGBattle, etc.
		VisualizationMgr.BuildVisualizationFrame(StartStateIndex, NewlyStartedActions);
		VisualizationMgr.CheckStartBuildTree();
	}

	simulated function SetupFirstStartTurnSeed()
	{
		local XComGameState_BattleData BattleData;
		
		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
		if (BattleData.bUseFirstStartTurnSeed)
		{
			class'Engine'.static.GetEngine().SetRandomSeeds(BattleData.iFirstStartTurnSeed);
		}
	}

	simulated function SetupUnits()
	{
		local XComGameState StartState;
		local int StartStateIndex;

		StartState = CachedHistory.GetStartState();
		if (StartState == none)
		{
			StartStateIndex = CachedHistory.FindStartStateIndex();
		
			StartState = CachedHistory.GetGameStateFromHistory(StartStateIndex);

			`assert(StartState != none);

		}

		// the xcom squad needs to be initialized before alien spawning
		StartStateInitializeSquads(StartState);

		// only spawn AIs in SinglePlayer...
		if (`XENGINE.IsSinglePlayerGame())
			StartStateSpawnAliens(StartState);

		// Spawn additional units ( such as cosmetic units like the Gremlin )
		StartStateSpawnCosmeticUnits(StartState);

		//Add new game object states to the start state.
		//*************************************************************************	
		StartStateCreateXpManager(StartState);
		StartStateInitializeUnitAbilities(StartState);      //Examine each unit's start state, and add ability state objects as needed
		//*************************************************************************


		// build the initiative order
		BuildInitiativeOrder(StartState);
	}

	//Used by the system if we are coming from strategy and did not use seamless travel ( which handles this internally )
	function MarkPlotUsed()
	{
		local XComGameState_BattleData BattleDataState;

		BattleDataState = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

		// notify the deck manager that we have used this plot
		class'X2CardManager'.static.GetCardManager().MarkCardUsed('Plots', BattleDataState.MapData.PlotMapName);
		class'X2CardManager'.static.GetCardManager().MarkCardUsed('PlotTypes', ParcelManager.GetPlotDefinition(BattleDataState.MapData.PlotMapName).strType);
	}

	simulated function bool AllowVisualizerSelection()
	{
		return false;
	}

	simulated function ApplyResistancePoliciesToStartState( )
	{
		// DIO DEPRECATED [11/27/2018 dmcdonough]
	}

	simulated function ApplyDarkEventsToStartState( )
	{
		// DIO DEPRECATED [11/27/2018 dmcdonough]
	}

	simulated function bool ShowUnitFlags( )
	{
		return false;
	}

	private simulated function OnStudioLoaded( )
	{
		bStudioReady = true;
	}

	private simulated function HeadshotReceived(StateObjectReference UnitRef)
	{
		--m_HeadshotsPending;
	}

	simulated function RequestHeadshots( )
	{
		local XComGameState_Unit UnitState;

		m_HeadshotsPending = 0;

		foreach CachedHistory.IterateByClassType( class'XComGameState_Unit', UnitState )
		{
			if (UnitState.GetTeam() != eTeam_XCom) // only headshots of XCom
				continue;
			if (UnitState.GetMyTemplate().bIsCosmetic) // no Gremlins
				continue;
			if (UnitState.bMissionProvided) // no VIPs
				continue;

			m_kPhotoboothAutoGen.AddHeadShotRequest( UnitState.GetReference( ), 512, 512, HeadshotReceived );
			++m_HeadshotsPending;
		}

		m_kPhotoboothAutoGen.RequestPhotos();
	}

	function InitNonBreachMode()
	{
		local int Index;
		local XComGameState_BattleData BattleData;
		local XComGameState StartState;
		local XComGameState_Unit UnitState;
		local array<XComGameState_Unit> EnemyUnitStates;

		`assert(!bEnableBreachMode);

		StartState = CachedHistory.GetStartState();
		foreach StartState.IterateByClassType(class'XComGameState_BattleData', BattleData) { break; }
		BattleData.BreachingRoomID = BattleData.MapData.RoomIDs[0];

		if (BattleData.MapData.RoomIDs.length > 1)
		{
			`RedScreenOnce("[InitNonBreachMode]: multi-room encounter sequence is not allowed for non-breach mode");
		}

		// reveal all rooms
		for (Index = 0; Index < BattleData.MapData.RoomIDs.Length; Index++)
		{
			`XWORLD.RevealRoomByID(BattleData.MapData.RoomIDs[Index], eFOWTileStatus_Seen);
		}

		// Update all enemies to Red Alert
		class'Helpers'.static.GatherUnitStates(EnemyUnitStates, eTeam_Alien, StartState);
		foreach EnemyUnitStates(UnitState)
		{
			UnitState.ApplyAlertAbilityForNewAlertData(eAC_SeesSpottedUnit);
			UnitState.GetGroupMembership().InitiateReflexMoveActivate(UnitState, eAC_MapwideAlert_Hostile, , , StartState);
		}
	}

Begin:
	`SETLOC("Start of Begin Block");

	class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().ClientSetCameraFade(true, MakeColor(0, 0, 0), vect2d(0, 1), 0.0);

	//Wait for the UI to initialize
	`assert(Pres != none); //Reaching this point without a valid presentation layer is an error
	
	while( Pres.UIIsBusy() )
	{
		Sleep(0.0f);
	}
		
	bShowDropshipInteriorWhileGeneratingMap = ShowDropshipInterior();
	if(bShowDropshipInteriorWhileGeneratingMap)
	{		
		// bsg-dforrest (5.3.17): on console there is a transition screen so this can be a blocking load
		if(`ISCONSOLE)
		{
			`MAPS.AddStreamingMap(`MAPS.GetTransitionMap(), DropshipLocation, DropshipRotation, true);
		}
		else
		{
			`MAPS.AddStreamingMap(`MAPS.GetTransitionMap(), DropshipLocation, DropshipRotation, false);
		}
		// bsg-dforrest (5.3.17):
		
		while(!`MAPS.IsStreamingComplete())
		{
			sleep(0.0f);
		}

		MarkPlotUsed();
				
		XComPlayerController(Pres.Owner).NotifyStartTacticalSeamlessLoad();

		WorldInfo.MyLocalEnvMapManager.SetEnableCaptures(TRUE);

		//Let the dropship settle in
		Sleep(1.0f);

		//Stop any movies playing. HideLoadingScreen also re-enables rendering
		Pres.UIStopMovie();
		Pres.HideLoadingScreen();
		class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().ClientSetCameraFade(false);

		WorldInfo.MyLocalEnvMapManager.SetEnableCaptures(FALSE);

		// bsg-dforrest (4.19.17): additional load timer step info
		`MAPS.LoadTimer_Check("Dropship Entered");
		// bsg-dforrest (4.19.17): end
	}
	else
	{
		//Will stop the HQ launch music if it is still playing ( which it should be, if we seamless traveled )
		`XTACTICALSOUNDMGR.StopHQMusicEvent();
		`XTACTICALSOUNDMGR.StopHQAmbienceEvent();
	}

	`MAPS.InstantiateAllRequiredMaps();

	if(`XWORLDINFO.IsPlayInEditor())
	{
		`XWORLD.InitializeRoomFOWStatus(eFOWTileStatus_Seen);
		TacticalController = XComTacticalController(WorldInfo.GetALocalPlayerController());
		if (TacticalController != none)
		{
			TacticalController.ClientSetCameraFade(false);
			TacticalController.SetInputState('Multiplayer_Inactive');
		}
	}

	//Wait for the drop ship and all other maps to stream in
	while (!`MAPS.IsStreamingComplete())
	{
		sleep(0.0f);
	}

	// Do anything that generate maps would have done and wasn't able to be made into an offline process at save-time in th editor or cook
	`MAPS.PerformPostLoadFixups();

	while (!`MAPS.IsStreamingComplete())
	{
		sleep(0.0f);
	}

	if(bShowDropshipInteriorWhileGeneratingMap)
	{
		// bsg-dforrest (4.19.17): additional load timer step info
		`MAPS.LoadTimer_Check("Dropship Done");
		// bsg-dforrest (4.19.17): end

		WorldInfo.bContinueToSeamlessTravelDestination = false;
		XComPlayerController(Pres.Owner).NotifyLoadedDestinationMap('');
		while(!WorldInfo.bContinueToSeamlessTravelDestination)
		{
			Sleep(0.0f);
		}

		`XTACTICALSOUNDMGR.StopHQMusicEvent();	
		`XTACTICALSOUNDMGR.StopHQAmbienceEvent();
				
		`MAPS.RemoveStreamingMapByName(`MAPS.GetTransitionMap(), false);
	}
	//bsg-crobinson (7.31.17): If we are on console and MP exists, refresh login status to see if we need to hide the loading screen
	else if(X2TacticalMPGameRuleset(`TACTICALRULES) != none && `ISCONSOLE)
	{
		`ONLINEEVENTMGR.RefreshLoginStatus(); //Refresh the login status, in case we somehow entered this loop on accident (dont want to risk clearing the load screen too early)

		if(`ONLINEEVENTMGR.LoginStatus == LS_NotLoggedIn) //Make sure we aren't logged in, then hide the load screen
		{
			Pres.HideLoadingScreen();
		}
	}
	//bsg-crobinson (7.31.17): end

	TacticalStreamingMapsPostLoad();

	if( XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl() != none )
	{
		// Need to rerender static depth texture for the current weather actor in case a different parcel was selected in TQL
		XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().UpdateStaticRainDepth();
		
		bRain = CanToggleWetness();
		class'XComWeatherControl'.static.SetAllAsWet(bRain);
	}
	else
	{
		bRain = false;
		class'XComWeatherControl'.static.SetAllAsWet(false);
	}
	EnvironmentLightingRemoteEvents();

	if (WorldInfo.m_kDominantDirectionalLight != none &&
		WorldInfo.m_kDominantDirectionalLight.LightComponent != none &&
		DominantDirectionalLightComponent(WorldInfo.m_kDominantDirectionalLight.LightComponent) != none)
	{
		DominantDirectionalLightComponent(WorldInfo.m_kDominantDirectionalLight.LightComponent).SetToDEmissionOnAll();
	}
	else
	{
		class'DominantDirectionalLightComponent'.static.SetToDEmissionOnAll();
	}
	
	InitVolumes();

	WorldInfo.MyLightClippingManager.BuildFromScript();

	class'XComEngine'.static.BlendVertexPaintForTerrain();

	if (XComTacticalController(WorldInfo.GetALocalPlayerController()).TerrainCaptureControl() != none)
	{
		XComTacticalController(WorldInfo.GetALocalPlayerController()).TerrainCaptureControl().ResetCapturesNative();
	}

	class'XComEngine'.static.ConsolidateVisGroupData((XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID))).MapData.bMonolithic);

	class'XComEngine'.static.TriggerTileDestruction();

	class'XComEngine'.static.AddEffectsToStartState();

	class'XComEngine'.static.UpdateGI();

	class'XComEngine'.static.ClearLPV();

	WorldInfo.MyLocalEnvMapManager.SetEnableCaptures(TRUE);

	`log("X2TacticalGameRuleset: Finished Generating Map", , 'XCom_GameStates');

	ApplyResistancePoliciesToStartState( );
	ApplyDarkEventsToStartState( );

	//determine deployment spawners breach roomids
	`XWORLD.UpdateDeploymentSpawnActorRoomIDs();

	// "spawn"/prespawn player and ai units
	SetupUnits();

	//Position units already in the start state
	//*************************************************************************
	StartStatePositionUnits();
	//*************************************************************************

	// load cinematic maps for units
	AddCharacterStreamingCinematicMaps();

	// load cinematic maps for breach
	AddBreachStreamingCinematicMaps();

	//Wait for any loading movie to finish playing
	`XENGINE.SetAllowMovieInput(true); //Allow the user to skip the movie ( if it is skippable )
	while(class'XComEngine'.static.IsAnyMoviePlaying() && !class'XComEngine'.static.IsLoadingMoviePlaying())
	{
		Sleep(0.0f);
	}

	// Add the default camera
	AddDefaultPathingCamera();

	if (UnitRadiusManager != none)
	{
		UnitRadiusManager.SetEnabled( true );
	}

	//Create game states for actors in the map
	CreateMapActorGameStates();

	if (!bEnableBreachMode)
	{
		InitNonBreachMode();
	}

	// bsg-dforrest (5.2.17): don't do this here on console! BuildVisualizationForStartState below lasts >30s!
	if(!`ISCONSOLE)
	{
		//Unveil scene - should be playing an intro if there is one
		if (class'XComEngine'.static.IsLoadingMoviePlaying())
		{
			Pres.HideLoadingScreen();
		}
	}

	// Create all soldier portraits right now for ladder mode
	if (CachedHistory.GetSingleGameStateObjectForClass( class'XComGameState_LadderProgress', true ) != none || bRequestHeadshots)
	{
		bStudioReady = false;

		m_kTacticalLocation = new class'X2Photobooth_TacticalLocationController';
		m_kTacticalLocation.Init( OnStudioLoaded );

		while (!bStudioReady)
		{
			Sleep( 0.0f );
		}

		m_kPhotoboothAutoGen = Spawn(class'X2Photobooth_StrategyAutoGen', self);
		m_kPhotoboothAutoGen.Init( );

		`log("X2TacticalGameRuleset: Starting Headshot Captures", , 'XCom_GameStates');

		RequestHeadshots( );

		while (m_HeadshotsPending > 0)
		{
			Sleep( 0.0f );
		}

		m_kPhotoboothAutoGen.Destroy( );
		m_kTacticalLocation.Cleanup( );
		m_kTacticalLocation = none;
	}
	// bsg-dforrest (5.2.17): end

	// bsg-dforrest (4.18.17): resolved Gnm submitdone errors while building visualization for start state
	if(`ISCONSOLE)
	{
		`XENGINE.PlayLoadMapMovie(0); // bsg-dforrest (5.23.17): play the black bink with rotating logo
	}
	// bsg-dforrest (4.18.17): end

	// bsg-dforrest (6.22.17): preload audio banks
	if(`ISCONSOLE)
	{
		`CONTENT.PreloadAudioBanksForTactical();
	}
	// bsg-dforrest (6.22.17): end

	//Visualize the start state - in the most basic case this will create pawns, etc. and position the camera.
	BuildVisualizationForStartState();

	// bsg-dforrest (4.18.17): resolved Gnm submitdone errors while building visualization for start state
	if(`ISCONSOLE)
	{
		Pres.HideLoadingScreen(); // bsg-dforrest (5.23.17): hide loading screen
	}
	// bsg-dforrest (4.18.17): end
	
	`MAPS.LoadTimer_Stop();
	//`log("Ending level load at " @ class'Engine'.static.GetEngine().seconds @ "s. Loading took" @ (WorldInfo.RealTimeSeconds - LevelLoadStartTime) @ "s.", , 'DevLoad');

	//Let the visualization blocks accumulated so far run their course ( which may include intro movies, etc. ) before continuing. 
	while( WaitingForVisualizer() )
	{
		sleep(0.0);
	}

	//This needs to be called after CreateMapActorGameStates, to make sure Destructibles have their state objects ready.
	`PRES.m_kUnitFlagManager.AddFlags();

	//Bootstrap the visibility mgr with the start state
	VisibilityMgr.InitialUpdate();

	// For things like Challenge Mode that require a level seed for all the level generation and a differing seed for each player that enters, set the 
	// specific seed for all random actions hereafter. Additionally, do this before the BeginState_rulesAuthority submits its state context so that the
	// seed is baked into the first context.
	SetupFirstStartTurnSeed();

	// remove the lock that was added in CreateTacticalGame.BeginState
	//	the history is fair game again...
	CachedHistory.RemoveHistoryLock();

	//Have the event manager check for errors
	`XEVENTMGR.ValidateEventManager("while entering a tactical battle! This WILL result in buggy behavior during game play continued with this save.");

	//After this point, the start state is committed
	BeginState_RulesAuthority(none);

	//This is guarded internally from redundantly starting. Various different ways of entering the mission may have called this earlier.
	`XTACTICALSOUNDMGR.StartAllAmbience();

	//Initialization continues in the PostCreateTacticalGame state.
	//Further changes are not part of the Tactical Game start state.
	
	// bsg-dforrest (5.2.17): if we have to wait on this on console do it after everything else had loaded
	if(`ISCONSOLE)
	{
		// bsg-dforrest (7.6.17): wait on any async loading audio banks now also
		while(`ONLINEEVENTMGR.WaitForAudioRetryQueue())
		{
			sleep(0.0);
		}
		// bsg-dforrest (7.6.17): end

		//Unveil scene - should be playing an intro if there is one
		if (class'XComEngine'.static.IsLoadingMoviePlaying())
		{
			Pres.HideLoadingScreen();
		}

		//Wait for environmental captures to complete now that we have hidden any loading screens ( the loading screen will inhibit scene capture )
		while (!WorldInfo.MyLocalEnvMapManager.AreCapturesComplete())
		{
			Sleep(0.0f);
		}
	}
	// bsg-dforrest (5.2.17): end	

	// get packages for an units that might be spawned from kismet
	AddKismetSpawnedUnitPackages();

	`SETLOC("End of Begin Block");
	GotoState(GetNextTurnPhase(GetStateName()));
}

/// <summary>
/// This state is entered if the tactical game being played is resuming a previously saved game state. LoadTacticalGame handles resuming from a previous
/// game state as well initiating a replay of previous moves.
/// </summary>
simulated state LoadTacticalGame
{
	simulated event BeginState(name PreviousStateName)
	{
		local X2EventManager EventManager;
		local Object ThisObject;
		local XComGameState_ChallengeData ChallengeData;
		local XComGameState_TimerData Timer;
		local XComGameState_DialogueManager DialogueManager;

		`SETLOC("BeginState");

		EventManager = `XEVENTMGR;
		ThisObject = self;

		EventManager.RegisterForEvent(ThisObject, 'UnitMoveFinished', DIO_HandleNeutralReactionsOnMovement, ELD_OnStateSubmitted);
		EventManager.RegisterForEvent(ThisObject, 'AbilityActivated', HandleNeutralReactionsOnAbilityActivated, ELD_OnStateSubmitted);
		EventManager.RegisterForEvent(ThisObject, 'UnitDied', HandleUnitDiedCache, ELD_OnStateSubmitted);		
		EventManager.RegisterForEvent(ThisObject, 'CivilianRescued', HandleCivilianRescued, ELD_OnStateSubmitted);

		// allow templated event handlers to register themselves
		class'X2EventListenerTemplateManager'.static.RegisterTacticalListeners();

		// update our templates with the correct difficulty modifiers
		class'X2DataTemplateManager'.static.RebuildAllTemplateGameCaches();

		bTacticalGameInPlay = true;
		bProcessingLoad = true;

		`XANALYTICS.bReportedTacticalSessionEnd = false;

		// Technically a player can't ever actually load a challenge mode save so resetting the timer shouldn't be exploitable.
		// However, devs should/need to be able to load a challenge error report save and in order for those saves to be useful,
		// we need to reset the timer.  Otherwise loading the error save immediately triggers the 'timer expires' end condition.
		ChallengeData = XComGameState_ChallengeData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_ChallengeData', true));
		if (ChallengeData != none)
		{
			Timer = XComGameState_TimerData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_TimerData', true));
			Timer.ResetTimer();
		}

		DialogueManager = XComGameState_DialogueManager(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
		DialogueManager.RegisterForEvents();

		ReRegisterUnitAbilityListeners();

		CachedHistory.AddHistoryLock(); // Lock the history here, because there should be no gamestate submissions while doing the initial sync
	}

	function ReRegisterUnitAbilityListeners()
	{	
		local XComGameStateHistory History;
		local XComGameState_Unit UnitState;
	
		History = `XCOMHISTORY;	

		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			// make sure the ability listeners are still registered
			ReRegisterAbilityListenersForUnit( UnitState );
		}
	}

	function BuildVisualizationForStartState()
	{
		local int StartStateIndex;
		local array<X2Action> NewlyStartedActions;

		VisualizationMgr = `XCOMVISUALIZATIONMGR;

		StartStateIndex = CachedHistory.FindStartStateIndex();
		//Make sure this is a tactical game start state
		`assert( StartStateIndex > -1);
		`assert( XComGameStateContext_TacticalGameRule(CachedHistory.GetGameStateFromHistory(StartStateIndex).GetContext()) != none);

	//This will set up the visualizers that init the camera, XGBattle, etc.
	VisualizationMgr.BuildVisualizationFrame(StartStateIndex, NewlyStartedActions);
	VisualizationMgr.CheckStartBuildTree();
}

	//Set up the visualization mgr to run from the correct frame
	function SyncVisualizationMgr()
	{
		local XComGameState FullGameState;
		local int StartStateIndex;
		local array<X2Action> NewlyStartedActions;

		if (`ONLINEEVENTMGR.bInitiateReplayAfterLoad)
		{
			//Start the replay from the most recent start state
			StartStateIndex = CachedHistory.FindStartStateIndex();
			FullGameState = CachedHistory.GetGameStateFromHistory(StartStateIndex, eReturnType_Copy, false);

			// init the UI before StartReplay() because if its the Tutorial, Start replay will hide the UI which needs to have been created already
			XComPlayerController(GetALocalPlayerController()).Pres.UIReplayScreen(`ONLINEEVENTMGR.m_sReplayUserID);

			XComTacticalGRI(class'WorldInfo'.static.GetWorldInfo().GRI).ReplayMgr.StartReplay(StartStateIndex);

			`ONLINEEVENTMGR.bInitiateReplayAfterLoad = false;
		}
		else
		{
			//Continue the playthrough from the latest frame
			FullGameState = CachedHistory.GetGameStateFromHistory(-1, eReturnType_Copy, false);


		}

		VisualizationMgr.SetCurrentHistoryFrame(FullGameState.HistoryIndex);
		if (!XComTacticalGRI(class'WorldInfo'.static.GetWorldInfo().GRI).ReplayMgr.bInReplay)
		{
			//If we are loading a saved game to play, sync all the visualizers to the current state and enable passive visualizer building
			VisualizationMgr.EnableBuildVisualization();
			VisualizationMgr.OnJumpForwardInHistory();
			VisualizationMgr.BuildVisualizationFrame(FullGameState.HistoryIndex, NewlyStartedActions, true);
			VisualizationMgr.CheckStartBuildTree();
		}
	}

	simulated function SetupFirstStartTurnSeed()
	{
		local XComGameState_BattleData BattleData;

		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
		if (BattleData.bUseFirstStartTurnSeed)
		{
			class'Engine'.static.GetEngine().SetRandomSeeds(BattleData.iFirstStartTurnSeed);
		}
	}

	function SetupDeadUnitCache()
	{
		local XComGameState_Unit Unit;
		local XComGameState FullGameState;
		local int CurrentStateIndex;

		CachedDeadUnits.Length = 0;

		CurrentStateIndex = CachedHistory.GetCurrentHistoryIndex();
		FullGameState = CachedHistory.GetGameStateFromHistory(CurrentStateIndex, eReturnType_Copy, false);

		foreach FullGameState.IterateByClassType(class'XComGameState_Unit', Unit)
		{
			if (Unit.IsDead())
			{
				CachedDeadUnits.AddItem(Unit.GetReference());
			}
		}
	}

	// legacy save game support to rebuild the initiative order using the new model
	function RebuildInitiativeOrderIfNeccessary()
	{
		local XComGameState_BattleData BattleData;
		local StateObjectReference InitiativeRef;
		local bool AnyGroupsFound;
		local XComGameState NewGameState;
		local XComGameState_Player PlayerState;
		local XComGameState_HeadquartersDio DioHQ;
		local StateObjectReference SquadMemberRef;
		local XComGameState_AIGroup PlayerGroup;


		AnyGroupsFound = false;
		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
		foreach BattleData.PlayerTurnOrder(InitiativeRef)
		{
			if (XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(InitiativeRef.ObjectID)) != None)
			{
				AnyGroupsFound = true;
				break;
			}
		}

		// if no groups were found then this save game has not yet built initiative (it is a legacy save)
		// in this case, we need to build a partial representation of the start state as needed to rebuild initiative
		if (!AnyGroupsFound)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Rebuilding Initiative Order");

			if( !default.bInterleaveInitiativeTurns )
			{
				PlayerGroup = XComGameState_AIGroup(NewGameState.CreateNewStateObject(class'XComGameState_AIGroup'));
				PlayerGroup.bProcessedScamper = true;

				DioHQ = `DIOHQ;

					foreach DioHQ.Squad(SquadMemberRef)
				{
					PlayerGroup.AddUnitToGroup(SquadMemberRef.ObjectID, NewGameState);
				}

				foreach CachedHistory.IterateByClassType(class'XComGameState_Player', PlayerState)
				{
					PlayerState = XComGameState_Player(NewGameState.ModifyStateObject(class'XComGameState_Player', PlayerState.ObjectID));
				}

				// add all groups who should be in initiative
				foreach CachedHistory.IterateByClassType(class'XComGameState_AIGroup', PlayerGroup)
				{
					PlayerGroup = XComGameState_AIGroup(NewGameState.ModifyStateObject(class'XComGameState_AIGroup', PlayerGroup.ObjectID));

					foreach PlayerGroup.m_arrMembers(SquadMemberRef)
					{
						PlayerGroup.AddUnitToGroup(SquadMemberRef.ObjectID, NewGameState);
					}
				}
			}

			BuildInitiativeOrder(NewGameState);
			SubmitGameState(NewGameState);
		}
	}

	simulated function CreateMapActorGameStates()
	{
		local XComDestructibleActor DestructibleActor;
		local XComGameState_CampaignSettings SettingsState;
		local XComGameState StartState;
		local int StartStateIndex;

		StartState = CachedHistory.GetStartState();
		if (StartState == none)
		{
			StartStateIndex = CachedHistory.FindStartStateIndex();

			StartState = CachedHistory.GetGameStateFromHistory(StartStateIndex);

			`assert(StartState != none);

		}

		// only make start states for destructible actors that have not been created by the load
		//	this can happen if parcels/doors change between when the save was created and when the save was loaded
		foreach `BATTLE.AllActors(class'XComDestructibleActor', DestructibleActor)
		{
			DestructibleActor.GetState(StartState);
		}

		SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
		`XENGINE.m_kPhotoManager.FillPropagandaTextureArray(ePWM_Campaign, SettingsState.GameIndex);
	}

	//Wait for ragdolls to finish moving
	function bool AnyUnitsRagdolling()
	{
		local XComUnitPawn UnitPawn;

		foreach AllActors(class'XComUnitPawn', UnitPawn)
		{
			if (UnitPawn.IsInState('RagdollBlend'))
			{
				return true;
			}
		}

		return false;
	}

	simulated function bool AllowVisualizerSelection()
	{
		return false;
	}

	function RefreshEventManagerUnitRegistration()
	{
		local XComGameState_Unit UnitState;

		foreach CachedHistory.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			UnitState.RefreshEventManagerRegistrationOnLoad();
		}
	}

	simulated function bool ShowUnitFlags()
	{
		return false;
	}

	function PostLoadFixupInteractiveObjects()
	{
		local XComGameState_InteractiveObject InteractiveObject;

		// Run through interactive objects and let them fix up their internal state if it needs it
		foreach CachedHistory.IterateByClassType(class'XComGameState_InteractiveObject', InteractiveObject)
		{
			InteractiveObject.PostLoadFixupEvents();
		}
	}

Begin:
	`SETLOC("Start of Begin Block");
		
	`MAPS.RemoveStreamingMapByName(`MAPS.GetTransitionMap(), false);

	`CURSOR.ResetPlotValueCache( );

	`MAPS.InstantiateAllRequiredMaps();

	AddCharacterStreamingCinematicMaps(true);
	AddBreachStreamingCinematicMaps(true);	

	TacticalStreamingMapsPostLoad();

	// remove all the replacement actors that have been replaced
	`SPAWNMGR.CleanupReplacementActorsOnLevelLoad();

	// Cleanup may have made blueprint requests, wait for those
	while (!`MAPS.IsStreamingComplete())
	{
		sleep(0.0f);
	}

	`MAPS.LoadTimer_Check("Streaming Maps");

	// Do anything that generate maps would have done and wasn't able to be made into an offline process at save-time in th editor or cook
	`MAPS.PerformPostLoadFixups(true);

	if(XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl() != none)
	{
		// Need to rerender static depth texture for the current weather actor in case a different parcel was selected in TQL
		XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl().UpdateStaticRainDepth();

		bRain = CanToggleWetness();
		class'XComWeatherControl'.static.SetAllAsWet(bRain);
	}
	else
	{
		bRain = false;
		class'XComWeatherControl'.static.SetAllAsWet(false);
	}
	EnvironmentLightingRemoteEvents();

	if (WorldInfo.m_kDominantDirectionalLight != none &&
		WorldInfo.m_kDominantDirectionalLight.LightComponent != none &&
		DominantDirectionalLightComponent(WorldInfo.m_kDominantDirectionalLight.LightComponent) != none)
	{
		DominantDirectionalLightComponent(WorldInfo.m_kDominantDirectionalLight.LightComponent).SetToDEmissionOnAll();
	}
	else
	{
		class'DominantDirectionalLightComponent'.static.SetToDEmissionOnAll();
	}

	InitVolumes();

	WorldInfo.MyLightClippingManager.BuildFromScript();

	class'XComEngine'.static.BlendVertexPaintForTerrain();

	if (XComTacticalController(WorldInfo.GetALocalPlayerController()).TerrainCaptureControl() != none)
	{
		XComTacticalController(WorldInfo.GetALocalPlayerController()).TerrainCaptureControl().ResetCapturesNative();
	}

	class'XComEngine'.static.ConsolidateVisGroupData((XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID))).MapData.bMonolithic);

	class'XComEngine'.static.UpdateGI();

	class'XComEngine'.static.ClearLPV();

	// Clear stale data from previous map that could affect placement of reinforcements in this game.
	`SPAWNMGR.ClearCachedFireTiles();

	//determine deployment spawners breach roomids
	`XWORLD.UpdateDeploymentSpawnActorRoomIDs();

	WorldInfo.MyLocalEnvMapManager.SetEnableCaptures(TRUE);

	`MAPS.LoadTimer_Check("Post-loda graphics init");

	RefreshEventManagerUnitRegistration();

	//Have the event manager check for errors
	`XEVENTMGR.ValidateEventManager("while loading a saved game! This WILL result in buggy behavior during game play continued with this save.");

	//If the load occurred from UnitActions, mark the ruleset as loading which will instigate the loading procedure for 
	//mid-UnitAction save (suppresses player turn events). This will be false for MP loads, and true for singleplayer saves.
	// raasland - except it wasn't being set to true for SP and breaking turn start tick effects
	bLoadingSavedGame = true;

	//Wait for the presentation layer to be ready
	while(Pres.UIIsBusy())
	{
		Sleep(0.0f);
	}
	
	`MAPS.LoadTimer_Check("Wait for presentation layer");

	// Add the default camera
	AddDefaultPathingCamera( );

	Sleep(0.1f);

	//Create game states for actors in the map
	CreateMapActorGameStates();

	//Re-register any interactive objects that might need it
	PostLoadFixupInteractiveObjects();

	// bsg-dforrest (6.22.17): preload sounds loading a save game into tactical	
	if(`REPLAY.bInTutorial)
	{
		`CONTENT.PreloadAudioBanksForTutorial();
	}
	else
	{
		`CONTENT.PreloadAudioBanksForTactical();
	}
	// bsg-dforrest (6.22.17): end

	`MAPS.LoadTimer_Check("Audio bank loads");

	BuildVisualizationForStartState();
	
	while( WaitingForVisualizer() )
	{
		sleep(0.0);
	}

	//Sync visualizers to the proper state ( variable depending on whether we are performing a replay or loading a save game to play )
	SyncVisualizationMgr();

	`XTACTICALSOUNDMGR.SilenceCacophony();

	while( WaitingForVisualizer() )
	{
		sleep(0.0);
	}

	`XTACTICALSOUNDMGR.UnsilenceCacophony();

	`MAPS.LoadTimer_Check("Visualizer initialization");

	class'SeqEvent_OnPlayerLoadedFromSave'.static.FireEvent( );

	CachedHistory.RemoveHistoryLock( ); // initial sync is done, unlock the history for playing

	//This needs to be called after CreateMapActorGameStates, to make sure Destructibles have their state objects ready.
	Pres.m_kUnitFlagManager.AddFlags();

	//Flush cached visibility data now that the visualizers are correct for all the viewers and the cached visibility system uses visualizers as its inputs
	`XWORLD.FlushCachedVisibility();
	`XWORLD.ForceUpdateAllFOWViewers();
	if (bEnableBreachMode)
	{		
		HideDeploymentSpawns();
		SetupFOWStatus_Encounter();
	}
	
	SetupBuildingVisForEncounter();

	`MAPS.LoadTimer_Check("Init building vis system");

	//Flush cached unit rules, because they can be affected by not having visualizers ready (pre-SyncVisualizationMgr)
	UnitsCache.Length = 0;

	if (UnitRadiusManager != none)
	{
		UnitRadiusManager.SetEnabled( true );
	}

	CachedHistory.CheckNoPendingGameStates();

	SetupDeadUnitCache();

	//Signal that we are done
	bProcessingLoad = false; 

	RebuildInitiativeOrderIfNeccessary();

	// Now that the game is in the updated state, we can build the initial game visibility data
	VisibilityMgr.InitialUpdate();
	VisibilityMgr.ActorVisibilityMgr.OnVisualizationIdle(); //Force all visualizers to update their visualization state

	`MAPS.LoadTimer_Check("Update visibility mgr");

	Pres.m_kTacticalHUD.ForceUpdate(-1);

	if (`ONLINEEVENTMGR.bIsChallengeModeGame)
	{
		SetupFirstStartTurnSeed();
	}

	//Achievement event listeners do not survive the serialization process. Adding them here.
	`XACHIEVEMENT_TRACKER.Init();

	//Movie handline - for both the tutorial and normal loading
	while(class'XComEngine'.static.IsAnyMoviePlaying() && !class'XComEngine'.static.IsLoadingMoviePlaying())
	{
		Sleep(0.0f);
	}

	`MAPS.LoadTimer_Check("Wait for movie");

	// bsg-dforrest (7.6.17): requesting ambience and waiting on it before loading screen ends on consoles	
	`XTACTICALSOUNDMGR.StartAllAmbience();

	if(`ONLINEEVENTMGR.WaitForAudioRetryQueue())
	{
		Sleep(0.0f);
	}
	// bsg-dforrest (7.6.17): end

	// get packages for an units that might be spawned from kismet. Must wait for all maps to stream
	AddKismetSpawnedUnitPackages();

	if(class'XComEngine'.static.IsLoadingMoviePlaying())
	{
		ReleaseScriptLog( "Tactical Load Debug: Detected loading movie" );

		//Set the screen to black - when the loading move is stopped the renderer and game will be initializing lots of structures so is not quite ready
		WorldInfo.GetALocalPlayerController().ClientSetCameraFade(true, MakeColor(0, 0, 0), vect2d(0, 1), 0.0);
		Pres.HideLoadingScreen();		

		ReleaseScriptLog( "Tactical Load Debug: Requested loading movie stop" );

		//Allow the game time to finish setting up following the loading screen being popped. Among other things, this lets ragdoll rigid bodies finish moving.
		Sleep(4.0f);

		`MAPS.LoadTimer_Check("Wait for movie again?");
	}

	ReleaseScriptLog( "Tactical Load Debug: Post loading movie check" );

	// once all loading and intro screens clear, we can start the actual tutorial
	if(`REPLAY.bInTutorial)
	{
		`TUTORIAL.StartDemoSequenceDeferred();
	}
	
	//Clear the camera fade if it is still set
	XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController()).ClientSetCameraFade(false, , , 1.0f);	

	`ONLINEEVENTMGR.bCanPlayTogether = true; //bsg-fchen (8/22/16): Update Play Together to handle single player cases

	class'XComGameState_BattleData'.static.MarkBattlePlayableTime();
	`XEVENTMGR.TriggerEvent('Analytics_LoadTacticalMission', self, self);

	`AUTOSAVEMGR.LastAutosaveHistorySize = CachedHistory.GetNumGameStates();

	//Clear out pending event windows on load. If there are events in here it means that the event mgr
	//was serialized after an event trigger but before the window elapsed. The game is not setup to 
	//operate in this manner, so just clear the pending.
	`XEVENTMGR.Clear(true);

	`MAPS.LoadTimer_Stop();
	`SETLOC("End of Begin Block");
	GotoState(GetNextTurnPhase(GetStateName()));
}

// hacky function to get a few script logs that are needed for a low repro bug with tactical load
static native function ReleaseScriptLog( string log );

private simulated native function PostCreateTacticalModifyKismetVariables_Internal(XComGameState NewGameState);
private simulated native function SecondWaveModifyKismetVariables_Internal(XComGameState NewGameState, float Scalar);

/// <summary>
/// This state is entered after CreateTacticalGame, to handle any manipulations that are not rolled into the start state.
/// It can be entered after LoadTacticalGame as well, if needed (i.e. if we're loading to a start state).
/// </summary>
simulated state PostCreateTacticalGame
{
	simulated function StartStateCheckAndBattleDataCleanup()
	{
		local XComGameState_BattleData BattleData;
		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

		if ((BattleData == none) ||
			(BattleData != none &&
			BattleData.bIntendedForReloadLevel == false))
			`assert( CachedHistory.GetStartState() == none );

			if (BattleData != none)
			{
				BattleData.bIntendedForReloadLevel = false;				
			}
	}

	simulated function BeginState(name PreviousStateName)
	{
		`SETLOC("BeginState");
	}

	simulated event EndState(Name NextStateName)
	{
		VisibilityMgr.ActorVisibilityMgr.OnVisualizationIdle(); //Force all visualizers to update their visualization state
	}

	simulated function bool AllowVisualizerSelection()
	{
		return false;
	}

	simulated function PostCreateTacticalModifyKismetVariables( )
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;

		History = `XCOMHISTORY;

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("PostCreateTacticalGame::ModifyKismetVariables");
		PostCreateTacticalModifyKismetVariables_Internal( NewGameState );

		if(NewGameState.GetNumGameStateObjects() > 0)
		{
			SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}

	simulated function SecondWaveModifyKismetVariables( )
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local float TotalScalar;

		TotalScalar = 0;

		if (`SecondWaveEnabled('ExtendedMissionTimers') && (SecondWaveExtendedTimerScalar > 0))
			TotalScalar += SecondWaveExtendedTimerScalar;

		if (`SecondWaveEnabled('BetaStrike') && (SecondWaveBetaStrikeTimerScalar > 0))
			TotalScalar += SecondWaveBetaStrikeTimerScalar;

		if (TotalScalar <= 0)
			return;

		History = `XCOMHISTORY;

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("PostCreateTacticalGame::SecondWaveModifyKismetVariables");
		SecondWaveModifyKismetVariables_Internal( NewGameState, TotalScalar );

		if(NewGameState.GetNumGameStateObjects() > 0)
		{
			SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}

	simulated function bool ShowUnitFlags( )
	{
		return false;
	}

Begin:
	`SETLOC("Start of Begin Block");

	//Posts a game state updating all state objects that they are in play
	BeginTacticalPlay();

	//Let kismet know everything is ready
	`XCOMGRI.DoRemoteEvent('XGBattle_Running_BeginBlockFinished');

	`CURSOR.ResetPlotValueCache( );

	CachedHistory.CheckNoPendingGameStates();

	// immediately before running kismet, allow sitreps to modify values on the kismet canvas
	PostCreateTacticalModifyKismetVariables( );
	class'X2SitRepEffect_ModifyKismetVariable'.static.ModifyKismetVariables();
	SecondWaveModifyKismetVariables( );

	// kick off the mission intro kismet, and wait for it to complete all latent actions
	WorldInfo.TriggerGlobalEventClass(class'SeqEvent_OnTacticalMissionStartBlocking', WorldInfo);

	// set up start of match special conditions, including squad concealment
	ApplyStartOfMatchConditions();

	// kick off the gameplay start kismet, do not wait for it to complete latent actions
	WorldInfo.TriggerGlobalEventClass(class'SeqEvent_OnTacticalMissionStartNonBlocking', WorldInfo);

	StartStateCheckAndBattleDataCleanup();
		
	`ONLINEEVENTMGR.bCanPlayTogether = true; //bsg-fchen (8/22/16): Update Play Together to handle single player cases

	GotoState(GetNextTurnPhase(GetStateName()));
}

function BeginBreachSequence();

function ResetSoldierForBreachPlacement(int UnitObjectID, optional bool bRefreshInfos = true, optional bool bCascadeUnslotting = true);

function AssignSoldierBreachPlacement(int PlacingUnitObjectID, int BreachGroupID, int BreachSlotIndex);

function SwapSoldierBreachPlacement(int UnitObjectID, int OtherObjectID);

function ControlUnitVisibilityForBreach( XComGameState_Unit SelectedUnitState );

// Sets bEnableBreachMode
native function EnableDisableBreachmode(bool bEnable);

// Takes a breach action and derives a priority base on several factors: the ActionPriority of the BreachData, which breach point, and which stage of breaching ( ie. entering, targeting, enemy reactions, game camera )
native static function int GetAggregateBreachActionPriority(const out BreachActionData BreachData, out string DebugString);

// Decide on a priority value for the given breach data and breach group ID. Used to decide how to sort the associated breach action
native static function int GetBreachGroupIDPriority(const out BreachActionData BreachData, int BreachGroupID);

static function int SortBreachActionsByBarragePriority(BreachActionData BreachDataA, BreachActionData BreachDataB)
{
	if (BreachDataA.BreachBarragePriority > BreachDataB.BreachBarragePriority)
	{
		return 1;
	}
	else if (BreachDataA.BreachBarragePriority < BreachDataB.BreachBarragePriority)
	{
		return -1;
	}
	return 0;
}

static function int SortBreachActionsByActionPriority(BreachActionData BreachDataA, BreachActionData BreachDataB)
{
	local int PriorityA;
	local int PriorityB;

	//Get an adjusted priority from the breach data
	PriorityA = BreachDataA.AggregatePriority;
	PriorityB = BreachDataB.AggregatePriority;

	if (PriorityA > PriorityB)
	{
		return -1;
	}
	else if (PriorityA < PriorityB)
	{
		return 1;
	}
	else
	{
		//Tie breaker uses team (xcom first), then movement priority
		if (BreachDataA.ObjectTeam != eTeam_XCom && BreachDataB.ObjectTeam == eTeam_XCom)
		{
			return -1;
		}
		else if (BreachDataA.ObjectTeam == eTeam_XCom && BreachDataB.ObjectTeam != eTeam_XCom)
		{
			return 1;
		}

		if (BreachDataA.MovementPriority > BreachDataB.MovementPriority)
		{
			return -1;
		}
		else if (BreachDataA.MovementPriority < BreachDataB.MovementPriority)
		{
			return 1;
		}
		if (BreachDataA.BreachBarragePriority > BreachDataB.BreachBarragePriority)
		{
			return 1;
		}
		else if (BreachDataA.BreachBarragePriority < BreachDataB.BreachBarragePriority)
		{
			return -1;
		}

		return 0;
	}
}

static function BreachChangeContainerBuildVisualization(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_MarkerNamed MarkerNamed;

	// Add Named Marker so we can identify this in the visualization tree
	MarkerNamed = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
	MarkerNamed.SetName("BreachCheckpoint");
	//make the breach units visible
	class'X2Action_BreachUnitVisibility'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext());
}

static function bool ShouldPlayReadyCheckAnimForBreachPointType(EBreachPointType BreachPointTemplateType)
{
	local bool bPlayAnim;

	bPlayAnim = BreachPointTemplateType != eBreachPointType_eGrappleSummit;
	bPlayAnim = bPlayAnim && BreachPointTemplateType != eBreachPointType_eRopeSwing;

	return bPlayAnim;
}

static function BreachReadyCheckBuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local VisualizationActionMetadata ActionMetadata;
	local VisualizationActionMetadata EmptyMetadata;
	local X2Action_MarkerNamed MarkerNamed;
	//local XComGameStateVisualizationMgr VisMgr;
	local X2TacticalGameRuleset TacticalRules;

	local int BreachActionIndex;
	local BreachActionData ActionData;
	local X2Camera_Cinescript ReadyCheckCameraBehavior;	
	local XComGameStateContext Context;

	local X2Action_PlayAnimation PlayAnim;
	local X2Action_PlaySoundAndFlyOver Speak;
	local X2Action_StartCinescriptCamera StartCinescript;
	local X2Action_EndCinescriptCamera EndCinescript;
	local X2Action_Delay				DelayAction;

	local StateObjectReference SourceRef;
	local StateObjectReference TargetRef;
	local X2BreachPointTypeTemplate BreachPointTypeTemplate;

	local int LeaderActionIndex;
	local int FirstActionIndex;
	local bool bPlayCall, bPlayCallAnim, bPlayResponse, bPlayResponseAnim;


	History = `XCOMHISTORY;
	//VisMgr = `XCOMVISUALIZATIONMGR;
	TacticalRules = `TACTICALRULES;

	Context = VisualizeGameState.GetContext();

	ActionMetadata = EmptyMetadata;
	Speak = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, Context));
	Speak.CharSpeech = 'EvntBreachGo';

	class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);

	// Add Named Marker so we can identify this in the visualization tree
	MarkerNamed = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, Context));
	MarkerNamed.SetName("BreachCheckpoint");

	//The breach actions are sorted at this point. Per discussion with the animators, the ready check sequence should be:
	// 1. Leader calls out ready check
	// 2. Camera cuts to the breach point that is going in first.	
	// 3. First breach point calls ready and then the entrance sequence starts
	LeaderActionIndex = -1;
	FirstActionIndex = -1;
	EndCinescript = none;
	for (BreachActionIndex = 0; BreachActionIndex < TacticalRules.BreachActions.Length; ++BreachActionIndex)
	{
		ActionData = TacticalRules.BreachActions[BreachActionIndex];
		if (ActionData.bIsInitialMove)
		{	
			if (ActionData.bIsLastBreachpoint && LeaderActionIndex < 0)
			{
				LeaderActionIndex = BreachActionIndex;
			}
			if (ActionData.bIsFirstBreachpoint && FirstActionIndex < 0)
			{
				FirstActionIndex = BreachActionIndex;
			}			
		}
	}

	if (LeaderActionIndex > -1 && FirstActionIndex > -1)
	{
		//Leader / Call
		ActionData = TacticalRules.BreachActions[LeaderActionIndex];
		bPlayCall = LeaderActionIndex != FirstActionIndex;
		bPlayCallAnim = ActionData.AbilityName != 'BreachRopeSwingMove';
		BreachPointTypeTemplate = class'XComBreachHelpers'.static.GetBreachPointInfoForGroupID(ActionData.BreachGroupID).EntryPointActor.GetTypeTemplate();
		bPlayCallAnim = ShouldPlayReadyCheckAnimForBreachPointType(BreachPointTypeTemplate.Type);

		if (bPlayCall)
		{
			ActionMetadata = EmptyMetadata;
			ActionMetadata.StateObject_NewState = History.GetGameStateForObjectID(ActionData.ObjectID, , VisualizeGameState.HistoryIndex);
			SourceRef.ObjectID = ActionData.ObjectID;
			TargetRef.ObjectID = ActionData.SpecificTargetID;

			ReadyCheckCameraBehavior = class'X2Camera_Cinescript'.static.CreateCinescriptCameraCustom(class'X2TacticalGameRuleset'.default.BreachReadyCheckCinescript_Call, VisualizeGameState, SourceRef, TargetRef, ActionData);
			ReadyCheckCameraBehavior.bDisableFOW = true;

			StartCinescript = X2Action_StartCinescriptCamera(class'X2Action_StartCinescriptCamera'.static.AddToVisualizationTree(ActionMetadata, Context, false, EndCinescript));
			StartCinescript.CinescriptCamera = ReadyCheckCameraBehavior;

			Speak = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, Context, false, StartCinescript));
			Speak.CharSpeech = 'StatBreaching';

			if (bPlayCallAnim)
			{
				PlayAnim = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, StartCinescript));
				PlayAnim.Params.AnimName = 'HL_ReadyCheck_CallA';
			}
			else
			{
				DelayAction = X2Action_Delay(class'X2Action_Delay'.static.AddToVisualizationTree(ActionMetadata, Context, false, Speak));
				DelayAction.Duration = default.ReadyCheckNoAnimationVODelay;
			}

			EndCinescript = X2Action_EndCinescriptCamera(class'X2Action_EndCinescriptCamera'.static.AddToVisualizationTree(ActionMetadata, Context, false, bPlayCallAnim ? PlayAnim : DelayAction));
			EndCinescript.CinescriptCamera = ReadyCheckCameraBehavior;
		}

		//Response
		ActionData = TacticalRules.BreachActions[FirstActionIndex];
		bPlayResponse = true;
		BreachPointTypeTemplate = class'XComBreachHelpers'.static.GetBreachPointInfoForGroupID(ActionData.BreachGroupID).EntryPointActor.GetTypeTemplate();
		bPlayResponseAnim = ShouldPlayReadyCheckAnimForBreachPointType(BreachPointTypeTemplate.Type);

		if (bPlayResponse)
		{
			ActionMetadata = EmptyMetadata;
			ActionMetadata.StateObject_NewState = History.GetGameStateForObjectID(ActionData.ObjectID, , VisualizeGameState.HistoryIndex);
			SourceRef.ObjectID = ActionData.ObjectID;
			TargetRef.ObjectID = ActionData.SpecificTargetID;

			ReadyCheckCameraBehavior = class'X2Camera_Cinescript'.static.CreateCinescriptCameraCustom(class'X2TacticalGameRuleset'.default.BreachReadyCheckCinescript_Response, VisualizeGameState, SourceRef, TargetRef, ActionData);
			ReadyCheckCameraBehavior.bDisableFOW = true;

			StartCinescript = X2Action_StartCinescriptCamera(class'X2Action_StartCinescriptCamera'.static.AddToVisualizationTree(ActionMetadata, Context, false, EndCinescript));
			StartCinescript.CinescriptCamera = ReadyCheckCameraBehavior;

			Speak = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, Context, false, StartCinescript));
			Speak.CharSpeech = 'StatBreaching';

			if (bPlayResponseAnim)
			{
				PlayAnim = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, StartCinescript));
				PlayAnim.Params.AnimName = 'HL_ReadyCheck_ResponseA';
			}
			else
			{
				DelayAction = X2Action_Delay(class'X2Action_Delay'.static.AddToVisualizationTree(ActionMetadata, Context, false, Speak));
				DelayAction.Duration = default.ReadyCheckNoAnimationVODelay;
			}

			EndCinescript = X2Action_EndCinescriptCamera(class'X2Action_EndCinescriptCamera'.static.AddToVisualizationTree(ActionMetadata, Context, false, bPlayResponseAnim ? PlayAnim : DelayAction));
			EndCinescript.CinescriptCamera = ReadyCheckCameraBehavior;
		}
	}
}

static function BreachEndEncounterBuildVisualization(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_MarkerNamed MarkerNamed;
	local XComGameStateVisualizationMgr VisMgr;
	local array<X2Action> LeafNodes;

	VisMgr = `XCOMVISUALIZATIONMGR;
	VisMgr.GetAllLeafNodes(VisMgr.BuildVisTree, LeafNodes);

	// Add Named Marker so we can identify this in the visualization tree
	MarkerNamed = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, none, LeafNodes));
	MarkerNamed.SetName("BreachResetUnits");
}

static function BreachResetUnitsBuildVisualization(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_MarkerNamed MarkerNamed;
	local XComGameStateVisualizationMgr VisMgr;
	local array<X2Action> LeafNodes;

	VisMgr = `XCOMVISUALIZATIONMGR;
	VisMgr.GetAllLeafNodes(VisMgr.VisualizationTree, LeafNodes);
	
	// Add Named Marker so we can identify this in the visualization tree
	MarkerNamed = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, none, LeafNodes));
	MarkerNamed.SetName("BreachResetUnits");
}

static function BreachAutoAssignUnitsBuildVisualization(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata ActionMetadata;
	local XComGameStateVisualizationMgr VisMgr;
	local X2Action_MarkerNamed MarkerNamed;
	local array<X2Action> LeafNodes;

	// Add Named Marker so we can identify this in the visualization tree
	VisMgr = `XCOMVISUALIZATIONMGR;
	VisMgr.GetAllLeafNodes(VisMgr.VisualizationTree, LeafNodes);
	MarkerNamed = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, none, LeafNodes));
	MarkerNamed.SetName("BreachAutoAssign");
}

static function BreachMovementFailureTeleport_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local VisualizationActionMetadata BuildTrack;
	local X2Action_UpdateFOW FOWAction;

	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		BuildTrack.StateObject_NewState = UnitState;
		BuildTrack.StateObject_OldState = History.GetPreviousGameStateForObject(UnitState);
		BuildTrack.VisualizeActor = UnitState.GetVisualizer();

		class'X2Action_SyncVisualizer'.static.AddToVisualizationTree(BuildTrack, VisualizeGameState.GetContext());

		FOWAction = X2Action_UpdateFOW(class'X2Action_UpdateFOW'.static.AddToVisualizationTree(BuildTrack, VisualizeGameState.GetContext()));
		FOWAction.ForceUpdate = true;
	}
}

static function int SortBreachCamerasByGroupID(X2Camera_Fixed CameraA, X2Camera_Fixed CameraB)
{
	if (CameraA.BreachGroupID == CameraB.BreachGroupID)
	{
		return 0;
	}
	return (CameraA.BreachGroupID < CameraB.BreachGroupID) ? 1 : -1;
}

function OnBlendToTargetingCamera()
{	
}

// Given a BreachActionData, fills target information. If the breach action has not yet been committed to the history, the target information is speculative and based on the cached
// ability info in UnitsCache. If the breach action has already been committed to the history, then the target information is extracted from the history and OutNextAbilityContext is
// filled out with the relevant history context.
native function bool GetBreachAbilityTarget(const out BreachActionData CurrentAction, out StateObjectReference OutNextTargetRef, out XComGameStateContext_Ability OutNextAbilityContext);

// Given a BreachActionData representing the "current" breach action for a given game state object, returns a NextBreachAction based on CurrentAction's associated objectID 
native function bool GetNextBreachAction(BreachActionData CurrentAction, out BreachActionData NextBreachAction, out XComGameStateContext_Ability OutNextAbilityContext);

function bool IsBlendingToTargetingCameraForUnit(XGUnit Unit)
{
	return bBlendingTargetingCamera && Unit == BlendingTargetCameraShooter;
}

event OnRemoteEvent(name RemoteEventName)
{
	super.OnRemoteEvent(RemoteEventName);

	if (RemoteEventName == 'BlendToNextShot')
	{	
		//Start the blend to the targeting camera
		OnBlendToTargetingCamera();
	}
}

/// <summary>
/// Breach phase is a new phase of the tactical game where the player may coordinate their units for an ambush into the next tactical encounter
/// </summary>
simulated state TurnPhase_Breach
{
	simulated event BeginState(name PreviousStateName)
	{
		`SETLOC("BeginState");
		BeginState_RulesAuthority(none);

		bWaitingForBreachConfirm = true;
		bBlendingTargetingCamera = false;
		bWaitingForBreachCameraInit = true;
	}
	
	event EndState(name NextStateName)
	{
		local X2EventManager EventMgr;
		local Object ThisObj;

		ThisObj = self;
		EventMgr = `XEVENTMGR;
		EventMgr.UnRegisterFromEvent(ThisObj,'ActiveUnitChanged');
		EventMgr.UnRegisterFromEvent(ThisObj, 'UI_UnitDeployedToBreachPoint_OnVisBlockCompleted');
		EventMgr.UnRegisterFromEvent(ThisObj, 'UI_UnitDeployedToBreachPoint_OnActionSelected');
	}

	//Called from the Breach mode UI, game state modification is routed through through the tactical controller for now.
	function BeginBreachSequence()
	{
		local XComGameStateHistory History;
		local XComGameState_BattleData BattleData;
		local XComGameState NewGameState;
		local XComGameState_Unit NewUnitState, LoopUnitState;
		local array<XComGameState_Unit> BreachEnemies;
		local XComGameState_Player PlayerState;				
		local bool bIsXComSoldier, bIsPlayerControlled, bEnemyIntentNeedsActions;
		local X2CameraStack CameraStack;
		local BreachActionData ActionData;
		local int ActionDataIndex;
		local eBreachEnemyIntent EnemyIntent;
		local int LastBreachPointPriority;
		local int FirstBreachPointPriority;
		local XGUnit UnitPawn;
		local XComGameStateContext_TacticalGameRule TacticalRuleContext;
		
		History = `XCOMHISTORY;
		CameraStack = `CAMERASTACK;
		LastBreachPointPriority = 1000000;
		FirstBreachPointPriority = 0;

		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		if (!BattleData.IsInBreachSelection() || CameraStack.ContainsCameraOfClass(class'X2Camera_Breach'.Name))
		{
			// breach camera will stay on for a second then release the control back to the player. 
			// when it's still active, we don't want to start breaching just yet, since it will pass its top-down POV down to the next game camera
			return;
		}

		`log("**** BEGIN BREACH SEQUENCE ****", , 'XCom_Breach');

		LogRelativeTurnOrder();

		// Allow the UI/Controller to handle the transition
		TacticalController.BeginBreachSequence();

		// turn off breach selection phase
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breach: Initiate");
		BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
		BattleData.BreachSubPhase = eBreachSubPhase_SequenceCamera;
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		`BATTLE.RefreshDesc();

		// Update enemy intents based upon the positioning of XCom units
		TacticalRuleContext = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_BreachSequencCommence);
		NewGameState = TacticalRuleContext.ContextBuildGameState();
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		// Reset actions for all breach units, including enemies based upon their intent
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breach: Reset Actions");
		foreach History.IterateByClassType(class'XComGameState_Unit', LoopUnitState, eReturnType_Reference)
		{
			NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', LoopUnitState.ObjectID));

			PlayerState = XComGameState_Player(History.GetGameStateForObjectID(LoopUnitState.ControllingPlayer.ObjectID, eReturnType_Reference));
			bIsXComSoldier = (LoopUnitState.GetMyTemplate().bTreatAsSoldier && PlayerState != None && PlayerState.TeamFlag == eTeam_XCom);
			bIsPlayerControlled = (PlayerState != None && LoopUnitState.ControllingPlayer.ObjectID == PlayerState.ObjectID);
			EnemyIntent = class'XComBreachHelpers'.static.GetEnemyIntent(LoopUnitState.ObjectID);
			bEnemyIntentNeedsActions = (EnemyIntent == eBreachEnemyIntent_Behavior || EnemyIntent == eBreachEnemyIntent_Reposition);

			if ((bIsXComSoldier && bIsPlayerControlled) || (!bIsXComSoldier && bEnemyIntentNeedsActions && LoopUnitState.HasAssignedRoomBeenBreached()))
			{
				//`log("Giving action points to object" @ LoopUnitState.ObjectID @ LoopUnitState.SafeGetCharacterNickName() @ LoopUnitState.GetMyTemplateName() @ "intent:" @ EnemyIntent, , 'XCom_Breach');
				NewUnitState.SetupActionsForBeginTurn();
			}
			else
			{
				//`log("Removing action points from object" @ LoopUnitState.ObjectID @ LoopUnitState.SafeGetCharacterNickName() @ LoopUnitState.GetMyTemplateName() @ "intent:" @ EnemyIntent, , 'XCom_Breach');
				NewUnitState.ActionPoints.Length = 0;
			}
		}
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		`CHEATMGR.ToggleUnlimitedActions();

		`log("** Gathering all breach actions", , 'XCom_Breach');
		BreachActions.Length = 0;
		//Gather all Soldier units that can breach, and all the abilities they'll use
		GatherBreachData(BreachActions);
		//Gather all Enemy units that can react to the breach, and the abilities they'll use
		GatherEnemyReactionData(BreachActions);

		//set any barrage action priorities
		//SetBreachBarragePriorities( BreachActions );

		// Calculate aggregated priority for breach actions, log breach actions
		//`log("** UNSORTED breach actions:", , 'XCom_Breach');		
		for (ActionDataIndex = 0; ActionDataIndex < BreachActions.Length; ++ActionDataIndex)
		{
			ActionData = BreachActions[ActionDataIndex]; //Can't pass array element into const ref below, so cache this into a passable value
			BreachActions[ActionDataIndex].AggregatePriority = GetAggregateBreachActionPriority(ActionData, ActionData.AggregatePriorityDebugInfo);
			BreachActions[ActionDataIndex].AggregatePriorityDebugInfo = ActionData.AggregatePriorityDebugInfo;

			//LoopUnitState = XComGameState_Unit(History.GetGameStateForObjectID(ActionData.ObjectID));
			//`log( "Unit: " $ Format_Width(string(LoopUnitState.GetMyTemplate().bTreatAsSoldier ? LoopUnitState.GetSoldierClassTemplate().DataName : LoopUnitState.GetMyTemplateName()), 30) @ " Ability:" @ Format_Width(string(ActionData.AbilityName),30) @ " Action:" @ Format_Width(string(ActionData.ActionTemplateName),26) @ Format_Width(ActionData.AggregatePriorityDebugInfo, 110), , 'XCom_Breach');
		}

		// Update all enemies to Red Alert
		class'XComBreachHelpers'.static.GatherBreachEnemies(BreachEnemies);
		foreach BreachEnemies(LoopUnitState)
		{
			LoopUnitState.ApplyAlertAbilityForNewAlertData(eAC_SeesSpottedUnit);

			LoopUnitState.SetCurrentStat(eStat_AlertLevel, `ALERT_LEVEL_RED /*2, but GetAlertLevel will +1*/);
			UnitPawn = XGUnit(LoopUnitState.GetVisualizer());
			UnitPawn.VisualizedAlertLevel = UnitPawn.GetAlertLevel(LoopUnitState);
		}

		//Sort breach units by their ability priority and perform breach actions.
		BreachActions.Sort(SortBreachActionsByActionPriority);

		//Figure out which action is the last initial move
		for (ActionDataIndex = 0; ActionDataIndex < BreachActions.Length; ++ActionDataIndex)
		{
			if (LastBreachPointPriority > BreachActions[ActionDataIndex].BreachPointPriority)
			{
				LastBreachPointPriority = BreachActions[ActionDataIndex].BreachPointPriority;
			}

			if (FirstBreachPointPriority < BreachActions[ActionDataIndex].BreachPointPriority)
			{
				FirstBreachPointPriority = BreachActions[ActionDataIndex].BreachPointPriority;
			}
		}

		// Add checkpoint to the history for use as a VisualizationStartIndex
		BreachSequenceCheckpointHistoryIndex = SubmitBreachSequenceCheckpoint(-1, BreachReadyCheckBuildVisualization);

		`log("** SORTED breach actions:", , 'XCom_Breach');		
		ActionDataIndex = 0;
		foreach BreachActions(ActionData)
		{
			if (BreachActions[ActionDataIndex].BreachPointPriority == LastBreachPointPriority)
			{
				BreachActions[ActionDataIndex].bIsLastBreachpoint = true;
			}

			if (BreachActions[ActionDataIndex].BreachPointPriority == FirstBreachPointPriority)
			{
				BreachActions[ActionDataIndex].bIsFirstBreachpoint = true;
			}

			LoopUnitState = XComGameState_Unit(History.GetGameStateForObjectID(ActionData.ObjectID));
			`log( "Unit: " $ Format_Width(string(LoopUnitState.GetMyTemplate().bTreatAsSoldier ? LoopUnitState.GetSoldierClassTemplate().DataName : LoopUnitState.GetMyTemplateName()), 30) @ " Ability:" @ Format_Width(string(ActionData.AbilityName),30) @ " Action:" @ Format_Width(string(ActionData.ActionTemplateName),26) @ Format_Width(ActionData.AggregatePriorityDebugInfo, 110), , 'XCom_Breach');

			++ActionDataIndex;
		}

		//Set the first breach action as the one we are running
		CurrentBreachActionIndex = -1;
		
		//Let the latent wait below know that the user has confirmed breach start
		bWaitingForBreachConfirm = false; 
	}

	//Returns TRUE if the next breach priority requires a shift to game camera
	function bool ShouldSwitchToGameCameraForRestOfSequence()
	{
		local int NextActionPriority;

		if (KeepLastViewCamera == none)
		{
			// We have already switched to Game Camera, we shouldnt switch again during the sequence
			return false;
		}

		if (CurrentBreachActionIndex + 1 < BreachActions.Length)
		{
			NextActionPriority = BreachActions[CurrentBreachActionIndex + 1].ActionPriority;
			if (NextActionPriority >= class'X2TacticalElement_DefaultUnitAction'.default.ACTION_PRIORITY_SWITCH_SUBPHASE_TO_GAMECAMERA)
			{
				return true;
			}
		}

		return false;
	}
	
	//Returns TRUE if there is another breach action sequence to run.
	function bool ContinueBreachSequence()
	{
		local bool bAddCheckpoint;

		//Get the next breach action to run
		++CurrentBreachActionIndex;

		//Out of breach actions or not?
		if (CurrentBreachActionIndex < BreachActions.Length)
		{
			bAddCheckpoint = CurrentBreachActionIndex == 0;
			bAddCheckpoint = bAddCheckpoint || (CurrentBreachActionIndex > 0 && BreachActions[CurrentBreachActionIndex].ActionPriority != BreachActions[CurrentBreachActionIndex - 1].ActionPriority);
			bAddCheckpoint = bAddCheckpoint || (CurrentBreachActionIndex > 0 && BreachActions[CurrentBreachActionIndex].ActionPriority < class'X2TacticalElement_DefaultUnitAction'.default.ACTION_PRIORITY_MOVING_FIRE && BreachActions[CurrentBreachActionIndex].BreachPointPriority != BreachActions[CurrentBreachActionIndex - 1].BreachPointPriority);
			// Every time the ability priority changes, update our checkpoint 
			if (bAddCheckpoint)
			{
				// Add checkpoint to the history for use as a VisualizationStartIndex
				BreachSequenceCheckpointHistoryIndex = SubmitBreachSequenceCheckpoint(BreachActions[CurrentBreachActionIndex].ActionPriority);				
			}

			//Yes, there is another breach action to run
			return true;
		}

		//Required by legacy XCOM code and systems
		`CHEATMGR.ToggleUnlimitedActions();
		`BATTLE.RefreshDesc();

		//Submit a checkpoint when we are done.
		BreachSequenceCheckpointHistoryIndex = SubmitBreachSequenceCheckpoint();

		//Done with breach actions
		return false;
	}

	function bool GetXComRefsAssignedToSamePointAsGuardingUnitID( int GuardingUnitID, out array<StateObjectReference> OutXComRefsAssignedToThisPoint )
	{
		local XComGameState_BreachData BreachDataState;
		local BreachPointInfo PointInfo;
		local int Index;

		BreachDataState = XComGameState_BreachData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BreachData'));
		foreach BreachDataState.CachedBreachPointInfos( PointInfo )
		{
			for( Index = 0; Index < PointInfo.UnitRefsGuardingThisPoint.Length; ++Index )
			{
				if( PointInfo.UnitRefsGuardingThisPoint[Index].ObjectID == GuardingUnitID )
				{
					OutXComRefsAssignedToThisPoint = PointInfo.XComRefsAssignedToThisPoint;
					return true;
				}
			}
		}
		return false;
	}

	//function SetBreachBarragePriorities( out array<BreachActionData> Actions )
	//{
	//	local BreachActionData ActionData, TestActionData;
	//	local array<BreachActionData> BarrageActionData;
	//	local array<BreachActionData> SortedBreachActions;
	//	local GameRulesCache_VisibilityInfo VisInfo;
	//	local Vector UpVector, UnitPosition, UnitToTargetDir, UnitToTestDir, OTSPosition, OTSOffset;
	//	local XComWorldData WorldData;
	//	local TTile TargetTile, UnitTile, OTSTile;
	//	local XComGameState_Unit TargetUnit;
	//	local int Index, BreachActionIndex, BarrageActionDataIndex, OffsetIndex, BarragePriority;
	//	local float OffsetScale;
	//	local array<StateObjectReference> XComRefsAssignedToThisPoint;
	//	local array<int> XComUnitIDsInOrderOfPriority;
	//
	//	//get the actions in sequence order
	//	SortedBreachActions = Actions;
	//	SortedBreachActions.Sort(SortBreachActionsByActionPriority);
	//
	//	//get the xcom unit ids in order of who goes first
	//	for( BreachActionIndex = 0; BreachActionIndex < SortedBreachActions.Length; ++BreachActionIndex )
	//	{
	//		ActionData = SortedBreachActions[BreachActionIndex];
	//		if( ActionData.ObjectTeam == eTeam_XCom )
	//		{
	//			if( XComUnitIDsInOrderOfPriority.Find( ActionData.ObjectID ) == INDEX_NONE )
	//			{
	//				XComUnitIDsInOrderOfPriority.AddItem( ActionData.ObjectID );
	//			}
	//		}
	//	}
	//
	//	//get all the barrage units
	//	foreach BreachActions( ActionData )
	//	{
	//		if( ActionData.AbilityName == class'X2Ability_BreachAbilities'.default.BreachEnemyBarrageAbilityName )
	//		{
	//			BarrageActionData.AddItem( ActionData );
	//		}
	//	}
	//
	//	// score them based on clear camera vis ( unit to best target ), most in fov( unit to best target )
	//	WorldData = `XWORLD;
	//	UpVector = vect( 0, 0, 1 );
	//	for( BarrageActionDataIndex = 0; BarrageActionDataIndex < BarrageActionData.Length; ++BarrageActionDataIndex )
	//	{
	//		BarrageActionData[BarrageActionDataIndex].BreachBarragePriority = 0;
	//		//get the possible targets for the barrage unit
	//		TargetUnit = None;
	//		XComRefsAssignedToThisPoint.Length = 0;
	//		if( GetXComRefsAssignedToSamePointAsGuardingUnitID( BarrageActionData[BarrageActionDataIndex].ObjectID, XComRefsAssignedToThisPoint ) )
	//		{
	//			//find the best one
	//			for( Index = 0; Index < XComUnitIDsInOrderOfPriority.Length && TargetUnit == None; ++Index )
	//			{
	//				for( OffsetIndex = 0; OffsetIndex < XComRefsAssignedToThisPoint.Length; ++OffsetIndex )
	//				{
	//					if( XComUnitIDsInOrderOfPriority[Index] == XComRefsAssignedToThisPoint[OffsetIndex].ObjectID )
	//					{
	//						TargetUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(XComUnitIDsInOrderOfPriority[Index], eReturnType_Reference));
	//						break;
	//					}
	//				}
	//			}
	//		}
	//		if( TargetUnit != None )
	//		{
	//			class'XComBreachHelpers'.static.GetUnitBreachFormationLOSTile( TargetUnit, TargetTile );
	//			UnitTile = BarrageActionData[BarrageActionDataIndex].UnitTile;
	//			UnitPosition = WorldData.GetPositionFromTileCoordinates( UnitTile );
	//			UnitToTargetDir = WorldData.GetPositionFromTileCoordinates( TargetTile ) - UnitPosition;
	//			UnitToTargetDir = Normal( UnitToTargetDir );
	//			OTSOffset = UnitToTargetDir cross UpVector;
	//			OTSOffset *= WorldData.const.WORLD_StepSize;
	//			OffsetScale = 1.0f;
	//			//score for three LOS to target tile, unit tile to target, adjacent tile to left and right
	//			for( OffsetIndex = 0; OffsetIndex < 3; ++OffsetIndex )
	//			{
	//				OTSPosition = UnitPosition + ( ( OffsetIndex > 0 ) ? OffsetScale : 0.0f ) * OTSOffset;
	//				OTSTile = WorldData.GetTileCoordinatesFromPosition( OTSPosition );
	//				if( WorldData.CanSeeTileToTile( OTSTile, TargetTile, VisInfo ) )
	//				{
	//					BarrageActionData[BarrageActionDataIndex].BreachBarragePriority += 500;
	//				}
	//				OffsetScale *= -1.0f;
	//			}
	//			//score for number of barrage allies in FOV ( +- 30 degrees )
	//			foreach BarrageActionData( TestActionData )
	//			{
	//				if( TestActionData.ObjectID != BarrageActionData[BarrageActionDataIndex].ObjectID )
	//				{
	//					UnitToTestDir =  WorldData.GetPositionFromTileCoordinates( TestActionData.UnitTile ) - WorldData.GetPositionFromTileCoordinates( UnitTile );
	//					UnitToTestDir = Normal( UnitToTestDir );
	//					if( ( UnitToTargetDir Dot UnitToTestDir ) > 0.5f ) //0.5f = cos( 30 degrees )
	//					{
	//						BarrageActionData[BarrageActionDataIndex].BreachBarragePriority += 10;
	//					}
	//				}
	//			}
	//			//maybe add some for length of shot animation time - or maybe not
	//		}
	//	}
	//	//sort them by highest BreachBarragePriority
	//	BarrageActionData.Sort( SortBreachActionsByBarragePriority );
	//	//set the actual priority in the Actions input array
	//	BarragePriority = BarrageActionData.Length;
	//	for( BarrageActionDataIndex = 0; BarrageActionDataIndex < BarrageActionData.Length; ++BarrageActionDataIndex )
	//	{
	//		for( BreachActionIndex = 0; BreachActionIndex < BreachActions.Length; ++BreachActionIndex )
	//		{
	//			if( Actions[BreachActionIndex].ObjectID == BarrageActionData[BarrageActionDataIndex].ObjectID )
	//			{
	//				Actions[BreachActionIndex].BreachBarragePriority = BarragePriority;
	//				break;
	//			}
	//		}
	//		BarragePriority -= 1;
	//	}
	//}

	function GatherBreachData(out array<BreachActionData> BreachUnits)
	{
		local XComGameStateHistory History;
		local XComWorldData WorldData;
		local XComGameState_BattleData BattleData;
		local XComGameState_Unit LoopUnitState;
		local XComGameState_Player PlayerState;
		local array<XComDeploymentSpawn> DeploymentSpawns;
		local XComDeploymentSpawn UnitDeploySpawn;
		local BreachActionData NewBreachData;
		local X2UnitActionTemplate BreachActionTemplate, BreachMoveActionTemplate;
		local array<name> BreachAbilities;
		local bool bIsXComSoldier, bIsPlayerControlled, bUnitAlreadyHasAbility;
		local int ExtraIndex;
		local BreachEntryPointMarker BreachEntryPoint;
		local X2AbilityTemplate AbilityTemplate;
		local X2AbilityTemplateManager AbilityTemplateMgr;
		local BreachSlotInfo SlotInfo;
		local name BreachMoveActionAbilityName;
		
		History = `XCOMHISTORY;
		WorldData = `XWORLD;
		AbilityTemplateMgr = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		WorldData.GetDeploymentSpawnActors(DeploymentSpawns, BattleData.BreachingRoomID);
		BreachMoveActionTemplate = X2UnitActionTemplate(class'X2TacticalElementTemplateManager'.static.GetTacticalElementTemplateManager().FindTacticalElementTemplate((bAllowManualBreachMovement) ? 'BreachManualMove' : 'BreachMove'));
		BreachMoveActionAbilityName = (BreachMoveActionTemplate.AbilityNames.length > 0) ? BreachMoveActionTemplate.AbilityNames[0] : '';

		// Find the breaching units and add breach actions from their deploy spawn
		foreach History.IterateByClassType(class'XComGameState_Unit', LoopUnitState, eReturnType_Reference)
		{
			PlayerState = XComGameState_Player(History.GetGameStateForObjectID(LoopUnitState.ControllingPlayer.ObjectID, eReturnType_Reference));
			bIsXComSoldier = (LoopUnitState.IsSoldier() || LoopUnitState.GetMyTemplate().bTreatAsSoldier) && (PlayerState != None && PlayerState.TeamFlag == eTeam_XCom);
			bIsPlayerControlled = (PlayerState != None && LoopUnitState.ControllingPlayer.ObjectID == PlayerState.ObjectID);
			// Only player controlled xcom soldiers can breach
			if (!bIsXComSoldier || !bIsPlayerControlled)
			{
				continue;
			}

			// Find the correct deployment spawn for this unit
			UnitDeploySpawn = class'XComBreachHelpers'.static.GetUnitDeploymentSpawn(LoopUnitState);

			// ignore units that have not been deployed yet
			if (UnitDeploySpawn == none)
			{
				continue;
			}

			BreachAbilities.length = 0;
			BreachActionTemplate = UnitDeploySpawn.GetActionTemplate();			
			if (BreachActionTemplate != none)
			{
				BreachAbilities = BreachActionTemplate.AbilityNames;
			}

			BreachEntryPoint = WorldData.GetEntryPointMarker(UnitDeploySpawn.BreachGroupID);
			SlotInfo = class'XComBreachHelpers'.static.GetDeploymentSpawnBreachSlotInfo(UnitDeploySpawn);
			NewBreachData.AbilityName = (BreachAbilities.Length > 0) ? BreachAbilities[0] : '';
			AbilityTemplate = AbilityTemplateMgr.FindAbilityTemplate(NewBreachData.AbilityName);

			//Add Breach Data
			NewBreachData.ActionTemplateName = (BreachActionTemplate != None) ? BreachActionTemplate.DataName : '';
			NewBreachData.DeploymentSpawn = UnitDeploySpawn;
			NewBreachData.ObjectID = LoopUnitState.ObjectID;
			NewBreachData.ObjectTeam = LoopUnitState.GetTeam();
			NewBreachData.UnitTile = LoopUnitState.TileLocation;
			NewBreachData.BreachTile = UnitDeploySpawn.GetTile();
			NewBreachData.BreachPointTile = BreachEntryPoint.GetTileLocation();
			NewBreachData.FoundDestinationTile = BreachEntryPoint.GetBreachDestinationTile(SlotInfo.BreachSlotIndex, NewBreachData.DestinationTile); // gradually transition into using breach entry point && group IDs to associate destination markers
			NewBreachData.bIsPostAbilityMove = false;
			NewBreachData.bIsInitialMove = AbilityTemplate.bIsBreachInitialMove; //This is potentially an initial move, so record that if so
			NewBreachData.MovementPriority = SlotInfo.BreachSlotIndex;
			NewBreachData.ActionPriority = (BreachActionTemplate != none) ? BreachActionTemplate.ActionPriority : 1;
			NewBreachData.BreachPointPriority = GetBreachGroupIDPriority(NewBreachData, SlotInfo.BreachGroupID); //This value is not updated below as the breach group ID is invariant with respect to those additional actions
			NewBreachData.BreachBarragePriority = 0;
			NewBreachData.BreachGroupID = SlotInfo.BreachGroupID;

			if (!NewBreachData.FoundDestinationTile)
			{
				`Log("Could not find destination tile for breach slot, groupId:" @ SlotInfo.BreachGroupID @ " slotindex:" @ SlotInfo.BreachSlotIndex, , 'XCom_Breach');
				// fall back to using destination actor  
				NewBreachData.DestinationTile = UnitDeploySpawn.GetTile();
				NewBreachData.FoundDestinationTile = true;
			}
			BreachUnits.AddItem(NewBreachData);

			//Clear state for subsequence additions
			NewBreachData.bIsInitialMove = false;

			// If this breach action has extra ability to add (at its own priority), do it now
			if (BreachActionTemplate != None && BreachActionTemplate.ExtraAbilityInfos.Length > 0)
			{
				for (ExtraIndex = 0; ExtraIndex < BreachActionTemplate.ExtraAbilityInfos.Length; ++ExtraIndex)
				{
					NewBreachData.AbilityName = BreachActionTemplate.ExtraAbilityInfos[ExtraIndex].AbilityName;
					NewBreachData.ActionPriority = BreachActionTemplate.ExtraAbilityInfos[ExtraIndex].ActionPriority;

					bUnitAlreadyHasAbility = (LoopUnitState.FindAbility(NewBreachData.AbilityName).ObjectID > 0);
					// Extra abilities aren't validated during placement on deploy spawns, so must be validated when attempting to add as a breach action
					if (bUnitAlreadyHasAbility)
					{ 
						BreachUnits.AddItem(NewBreachData);
					}
				}
			}

			// Each breach action will have initial movement, to get through the breach
			if (BreachActionTemplate != none && !BreachActionTemplate.bSkipInitialMovement)
			{
				NewBreachData.AbilityName = 'BreachInitialMove';
				NewBreachData.bIsInitialMove = true;
				NewBreachData.ActionPriority = class'X2TacticalElement_DefaultUnitAction'.default.ACTION_PRIORITY_INITIAL_MOVE;
				BreachUnits.AddItem(NewBreachData);
			}

			// Each breach action will have follow-up movement to get from the formation position to the final destination
			if (BreachActionTemplate != none && BreachMoveActionTemplate != none)
			{
				NewBreachData.bIsPostAbilityMove = true;
				NewBreachData.bIsInitialMove = false;
				NewBreachData.AbilityName = BreachMoveActionAbilityName;

				NewBreachData.ActionPriority = BreachMoveActionTemplate.ActionPriority;
				BreachUnits.AddItem(NewBreachData);
			}
		}
	}

	function GatherEnemyReactionData(out array<BreachActionData> BreachUnits)
	{
		local XComGameState_Unit LoopUnitState;
		local X2UnitActionTemplate ReactFireActionTemplate;
		local X2UnitActionTemplate ReactMoveActionTemplate;
		local X2UnitActionTemplate ResonatorBuffActionTemplate;
		local BreachActionData NewBreachData;
		local array<XComGameState_Unit> BreachEnemies;
		local eBreachEnemyIntent EnemyIntent;
		local int BreachGroupID;

		ReactMoveActionTemplate = X2UnitActionTemplate(class'X2TacticalElementTemplateManager'.static.GetTacticalElementTemplateManager().FindTacticalElementTemplate('ReactMove'));
		ReactFireActionTemplate = X2UnitActionTemplate(class'X2TacticalElementTemplateManager'.static.GetTacticalElementTemplateManager().FindTacticalElementTemplate('ReactFire'));
		ResonatorBuffActionTemplate = X2UnitActionTemplate(class'X2TacticalElementTemplateManager'.static.GetTacticalElementTemplateManager().FindTacticalElementTemplate('BreachResonatorBuff'));
		class'XComBreachHelpers'.static.GatherBreachEnemies( BreachEnemies );

		// Check each enemy's intent and add the appropriate breach action if necessary
		foreach BreachEnemies(LoopUnitState)
		{
			BreachGroupID = class'XComBreachHelpers'.static.GetUnitBreachGroupID(LoopUnitState);
			NewBreachData.ObjectID = LoopUnitState.ObjectID;
			NewBreachData.UnitTile = LoopUnitState.TileLocation;
			NewBreachData.ObjectTeam = LoopUnitState.GetTeam();
			NewBreachData.BreachGroupID = BreachGroupID;
			if( LoopUnitState.GetMyTemplateName() == 'PsionicResonator' )
			{
				NewBreachData.ActionTemplateName = ResonatorBuffActionTemplate.DataName;
				NewBreachData.FoundDestinationTile = false;
				NewBreachData.AbilityName = ResonatorBuffActionTemplate.AbilityNames.Length > 0 ? ResonatorBuffActionTemplate.AbilityNames[0] : '';
				NewBreachData.MovementPriority = 0;
				NewBreachData.ActionPriority = ResonatorBuffActionTemplate.ActionPriority;
				NewBreachData.BreachPointPriority = GetBreachGroupIDPriority(NewBreachData, BreachGroupID);
				BreachUnits.AddItem(NewBreachData);
			}
			else
			{
				EnemyIntent = class'XComBreachHelpers'.static.GetEnemyIntent(LoopUnitState.ObjectID);
				`log("Enemy" @ LoopUnitState.ObjectID @ "Intent:" @ EnemyIntent @ LoopUnitState.SafeGetCharacterNickName() @ LoopUnitState.GetMyTemplateName(), , 'XCom_Breach');
				switch (EnemyIntent)
				{
				case eBreachEnemyIntent_Surprise:
					break; // do nothing, the unit will perform no reaction
				case eBreachEnemyIntent_Reposition:
					NewBreachData.ActionTemplateName = ReactMoveActionTemplate.DataName;
					NewBreachData.FoundDestinationTile = false;
					NewBreachData.AbilityName = ReactMoveActionTemplate.AbilityNames.Length > 0 ? ReactMoveActionTemplate.AbilityNames[0] : '';
					NewBreachData.MovementPriority = 0;
					NewBreachData.BreachBarragePriority = 0;
					NewBreachData.ActionPriority = ReactMoveActionTemplate.ActionPriority;
					NewBreachData.BreachPointPriority = GetBreachGroupIDPriority(NewBreachData, BreachGroupID);
					NewBreachData.SpecificTargetID = 0;
					BreachUnits.AddItem(NewBreachData);
					break;
				case eBreachEnemyIntent_Behavior:
					break; // do nothing, this is also checked elsewhere to give the unit an action point, which naturally lets its breach scamper behaviors run
				case eBreachEnemyIntent_Fire:
					NewBreachData.ActionTemplateName = ReactFireActionTemplate.DataName;
					NewBreachData.FoundDestinationTile = false;
					NewBreachData.AbilityName = ReactFireActionTemplate.AbilityNames.Length > 0 ? ReactFireActionTemplate.AbilityNames[0] : '';
					NewBreachData.MovementPriority = 0;
					NewBreachData.ActionPriority = ReactFireActionTemplate.ActionPriority;
					NewBreachData.BreachPointPriority = GetBreachGroupIDPriority(NewBreachData, BreachGroupID);
					BreachUnits.AddItem(NewBreachData);
					break;
				default:
					`log("Enemy Intent type IS NOT handled @dakota", , 'XCom_Breach');
					break;
				}			
			}
		}
	}
	
	function int SubmitBreachSequenceCheckpoint(int CheckpointAbilityPriority = -1, Delegate<BuildVisualizationDelegate> VisualizationFn = none)
	{
		local XComGameStateContext_ChangeContainer ChangeContainerContext;
		local XComGameState NewGameState;
		local XComGameStateHistory History;
		
		History = `XCOMHISTORY;

		// Add a ChangeContainer with a visualization so a VisualizationStartIndex can reference it
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breach New Pri: "@CheckpointAbilityPriority);
		ChangeContainerContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
		ChangeContainerContext.BuildVisualizationFn = VisualizationFn != none ? VisualizationFn : BreachChangeContainerBuildVisualization;
		ChangeContainerContext.bMergeIntoVisualizationTreeWithAllLeafParents = true;
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		//`log("*** Checkpoint - AbilityPriority:" @ CheckpointAbilityPriority @ "HistoryIdx:" @ History.GetCurrentHistoryIndex(), , 'XCom_Breach');

		// return the history index of the change we just submitted
		return History.GetCurrentHistoryIndex();
	}

	function bool IsManuallyTargetedBreachAbility(BreachActionData BreachData)
	{
		local XComGameStateHistory History;
		local name AbilityName;
		local X2AbilityTemplate AbilityTemplate;
		local X2AbilityTemplateManager AbilityTemplateManager;
		local XComGameState_Unit OldUnitState;
		local XComGameState_Ability ExistingAbility;
		local bool UnitAlreadyHasAbility;
		local array<AvailableTarget> PotentialTargets;

		History = `XCOMHISTORY;

		// Find the ability associated with the breach action
		AbilityName = BreachData.AbilityName;
		AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityName);
		if (AbilityTemplate == None)
		{
			return false; //Unable to find the specified breach ability
		}

		if (!AbilityTemplate.bManualBreachTargeting)
		{
			return false;
		}

		OldUnitState = XComGameState_Unit(History.GetGameStateForObjectID(BreachData.ObjectID, eReturnType_Reference));
		UnitAlreadyHasAbility = (OldUnitState.FindAbility(AbilityName).ObjectID > 0);
		`assert(UnitAlreadyHasAbility);

		ExistingAbility = XComGameState_Ability(History.GetGameStateForObjectID(OldUnitState.FindAbility(AbilityName).ObjectID));
		ExistingAbility.GatherAbilityTargets(PotentialTargets);

		if (AbilityTemplate.bUsesFiringCamera && PotentialTargets.Length < 1)
		{
			return false; // Do not target manually, there are no targets
		}

		return true;
	}
	
	function bool ManuallyTargetBreachAbility(BreachActionData BreachData)
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_Unit OldUnitState;
		local XComGameStateContext_BreachSequence BreachTargetingContext;
		local XComGameState_Ability ExistingAbility;
		local bool UnitAlreadyHasAbility;
		local array<AvailableTarget> PotentialTargets;
		
		History = `XCOMHISTORY;

		OldUnitState = XComGameState_Unit(History.GetGameStateForObjectID(BreachData.ObjectID, eReturnType_Reference));
		UnitAlreadyHasAbility = (OldUnitState.FindAbility(BreachData.AbilityName).ObjectID > 0);
		`assert(UnitAlreadyHasAbility);
		ExistingAbility = XComGameState_Ability(History.GetGameStateForObjectID(OldUnitState.FindAbility(BreachData.AbilityName).ObjectID));

		ExistingAbility.GatherAbilityTargets(PotentialTargets);
		if (ExistingAbility.GetMyTemplate().bUsesFiringCamera && PotentialTargets.Length == 0)
		{
			return false;
		}
		
		// Set the unit as targeting a specific ability
		BreachTargetingContext = class'XComGameStateContext_BreachSequence'.static.CreateBreachTargetingContext();
		BreachTargetingContext.UnitRef.ObjectID = BreachData.ObjectID;
		BreachTargetingContext.AbilityName = BreachData.AbilityName;
		NewGameState = BreachTargetingContext.ContextBuildGameState();
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		return true;
	}

	function SelectUnitForManualTargeting(BreachActionData BreachData)
	{
		local XComTacticalController Controller;
		local XComGameState_Unit UnitState;
		local X2BreachActionSequencer BreachActionSequencer;

		Controller = XComTacticalController(GetALocalPlayerController());
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BreachData.ObjectID));
		if (UnitState != None)
		{
			Controller.Visualizer_SelectUnit(UnitState, true);

		   	//Make sure the unit targeting is at full speed
			BreachActionSequencer = class'XComTacticalGRI'.static.GetBreachActionSequencer();

			//Update the visible states of the xcom squad based on who is shooting
			ControlUnitVisibilityForBreach(UnitState);

			//Allow the unit to change its aim
			XGUnit(UnitState.GetVisualizer()).GetPawn().LockAimEnableDisable(false);

			if (BreachActionSequencer.ShouldApplyBreachFireSlomo() && VisualizationMgr.IsPartOfSlomoGroup(UnitState.GetVisualizer()) != INDEX_NONE )
			{
				BreachActionSequencer.UpdateTimeForSlomoGroupObject(UnitState.GetVisualizer(), BreachActionSequencer.SlomoGroupHandle_ShooterPawns, 1.0f);				
			}
		}
	}

	//Control the visibility of XCOM units during breach. Prevents them from blocking the camera until we have a better looking solution. Passing a value of none for the selected unit state will put the units back to their default state.
	function ControlUnitVisibilityForBreach(XComGameState_Unit SelectedUnitState)
	{
		local XComGameState_Unit LoopUnitState;
		local XComGameState_Player PlayerState;
	   	local X2BreachActionSequencer BreachActionSequencer;
		local Actor Visualizer;
		local TTile CurrentTile;
		local bool bIsPlayerControlled, bIsXComSoldier;
		local int SelectedUnitBreachGroupID;

		SelectedUnitBreachGroupID = -1;
		if (SelectedUnitState != none)
		{
			SelectedUnitBreachGroupID = class'XComBreachHelpers'.static.GetUnitBreachGroupID(SelectedUnitState);
		}

		//Make sure the unit targeting is at full speed
		BreachActionSequencer = class'XComTacticalGRI'.static.GetBreachActionSequencer();


		foreach CachedHistory.IterateByClassType(class'XComGameState_Unit', LoopUnitState, eReturnType_Reference)
		{
			PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(LoopUnitState.ControllingPlayer.ObjectID, eReturnType_Reference));
			bIsXComSoldier = (LoopUnitState.IsSoldier() || LoopUnitState.GetMyTemplate().bTreatAsSoldier) && (PlayerState != None && PlayerState.TeamFlag == eTeam_XCom);
			bIsPlayerControlled = (PlayerState != None && LoopUnitState.ControllingPlayer.ObjectID == PlayerState.ObjectID);
			
			// Only player controlled xcom soldiers can breach
			if (!bIsXComSoldier || !bIsPlayerControlled)
			{
				continue;
			}

			if (SelectedUnitState == none || SelectedUnitState.ObjectID == LoopUnitState.ObjectID || BreachActionSequencer.ShouldApplyHiddenOutlines() )
			{				
				Visualizer = LoopUnitState.GetVisualizer();
				XGUnit(Visualizer).SetForceVisibility(eForceVisible);
				VisibilityMgr.ActorVisibilityMgr.VisualizerUpdateVisibility(Visualizer, CurrentTile);
			}
			else if( SelectedUnitState == none || SelectedUnitBreachGroupID == class'XComBreachHelpers'.static.GetUnitBreachGroupID(LoopUnitState) )
			{
				Visualizer = LoopUnitState.GetVisualizer();
				XGUnit(Visualizer).SetForceVisibility(eForceNotVisible);
				VisibilityMgr.ActorVisibilityMgr.VisualizerUpdateVisibility(Visualizer, CurrentTile);
			}
		}
	}

	function OpenHUDForManualTargeting(BreachActionData BreachData)
	{
		local XComGameState_Unit UnitState;
		local X2AbilityTemplate AbilityTemplate;
		local X2AbilityTemplateManager AbilityTemplateManager;
		
		// Find the ability associated with the breach action
		AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(BreachData.AbilityName);

		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BreachData.ObjectID));
		if (UnitState != None && AbilityTemplate.bUsesFiringCamera)
		{
			// Open the targeting hud
			`PRES.m_kTacticalHUD.RaiseTargetSystem(true, true);

			`XEVENTMGR.TriggerEvent('BreachSequence_BeginManualTargeting');
		}

		//Done transitioning to targeting camera
		bBlendingTargetingCamera = false;
	}

	function CloseHUDForManualTargeting(BreachActionData BreachData)
	{
		local XComTacticalController Controller;
		local XComGameState_Unit UnitState;
		local X2AbilityTemplate AbilityTemplate;
		local X2AbilityTemplateManager AbilityTemplateManager;

		// Find the ability associated with the breach action
		AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(BreachData.AbilityName);

		Controller = XComTacticalController(GetALocalPlayerController());
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BreachData.ObjectID));
		if (UnitState != None && AbilityTemplate.bUsesFiringCamera)
		{
			Controller.Visualizer_ReleaseControl();
		}
	}

	function ClearManualTargetBreachAbility(BreachActionData BreachData)
	{
		local XComGameState NewGameState;
		local XComGameStateContext_BreachSequence BreachTargetingContext;

		// Set the unit as targeting a specific ability
		BreachTargetingContext = class'XComGameStateContext_BreachSequence'.static.CreateBreachTargetingContext();
		BreachTargetingContext.UnitRef.ObjectID = BreachData.ObjectID;
		BreachTargetingContext.AbilityName = '';
		NewGameState = BreachTargetingContext.ContextBuildGameState();
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	function CullPostAbilityMovementForBreachHellionRushAbility()
	{
		local XComGameStateHistory History;
		local BreachActionData HellionActionData, ActionData;
		local XComGameState GameState;
		local XComGameStateContext Context;
		local XComGameStateContext_Ability AbilityContext;
		local XComGameStateContext_TacticalGameRule RuleContext;
		local bool bCullPostAbilityMovment;
		local int BreachActionIndex;
		local name BreachHellionRushAbilityName;

		BreachHellionRushAbilityName = class'X2Ability_BreachAbilities'.default.BreachHellionRushAbilityName;

		History = `XCOMHISTORY;

			HellionActionData = BreachActions[CurrentBreachActionIndex];
		if (HellionActionData.AbilityName != BreachHellionRushAbilityName)
		{
			return;
		}

		`log("BreachHellionRushAbility is the current breach action, check for movement to cull", , 'XCom_Breach');

		// Look through and see if we submitted an ability with the same name, if so, cull some actions now
		GameState = History.GetGameStateFromHistory();
		while (!bCullPostAbilityMovment && GameState != None)
		{
			Context = GameState.GetContext();
			AbilityContext = XComGameStateContext_Ability(Context);
			RuleContext = XComGameStateContext_TacticalGameRule(Context);
			if (AbilityContext != None)
			{
				if (AbilityContext.InputContext.AbilityTemplateName == BreachHellionRushAbilityName)
				{
					`log("BreachHellionRushAbility context was submitted, requesting cull.", , 'XCom_Breach');
					bCullPostAbilityMovment = true;
					break;
				}
			}
			
			if (RuleContext != None)
			{
				if (RuleContext.GameRuleType == eGameRule_BeginBreachMode)
				{
					`log("BreachHellionRushAbility context was not found, beginning of breach mode encountered. No need to cull movement", , 'XCom_Breach');
					break;
				}
			}

			GameState = History.GetPreviousGameStateFromHistory(GameState);
		}

		if (bCullPostAbilityMovment)
		{
			for (BreachActionIndex = BreachActions.Length - 1;  BreachActionIndex > CurrentBreachActionIndex; --BreachActionIndex)
			{
				ActionData = BreachActions[BreachActionIndex];
				if (ActionData.bIsPostAbilityMove && ActionData.ObjectID == HellionActionData.ObjectID)
				{
					`log("BreachHellionRushAbility found a bIsPostAbilityMove breach action data to cull.", , 'XCom_Breach');
					BreachActions.Remove(BreachActionIndex, 1);
				}
			}
		}
	}

	function PerformBreachAbility(BreachActionData BreachData, out XComPathingPawn kPathingPawn, out array<PathingInputData> OutPathInput, int AssociatedHistoryIndex)
	{
		local XComGameStateHistory History;
		local XComGameStateContext_Ability AbilityContext;
		local XComGameState_Ability ExistingAbility;
		local XComGameState_Unit OldUnitState;
		local name AbilityName;
		local X2AbilityTemplate AbilityTemplate;
		local X2AbilityTemplateManager AbilityTemplateManager;
		local bool UnitAlreadyHasAbility;
		local int AssociatedHistoryIndexInternal;
		local bool bForceParallel; // Breach action sequencer requires parallel, should we force it?
		local XComGameState_BattleData BattleData;
		
		History = `XCOMHISTORY;
		BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		OldUnitState = XComGameState_Unit(History.GetGameStateForObjectID(BreachData.ObjectID, eReturnType_Reference));

		`log("*** PerformBreachAbility - ObjID:" $ BreachData.ObjectID @ BreachData.AbilityName @ "(" $ BreachData.ActionTemplateName $ ") Nickname:" @ OldUnitState.SafeGetCharacterNickName() @ "CharTemplate:" @ OldUnitState.GetMyTemplateName(), , 'XCom_Breach');

		if (OldUnitState == None)
		{
			`log("Unable to find XComGameState_Unit for ObjectID:" @ BreachData.ObjectID, , 'XCom_Breach');
			return; // Invalid object at this point in the breach sequence
		}

		// Find the ability associated with the breach action
		AbilityName = BreachData.AbilityName;
		AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityName);
		if (AbilityTemplate == None)
		{
			`log("Ability template not found, cannot perform", , 'XCom_Breach');
			return; //Unable to find the specified breach ability
		}

		UnitAlreadyHasAbility = (OldUnitState.FindAbility(AbilityName).ObjectID > 0);
		if (!UnitAlreadyHasAbility)
		{
			`RedScreen("Object"$BreachData.ObjectID$" cannot perform breach ability, does not have "$AbilityName$" @dakota.lemaster");
			return;
		}
		ExistingAbility = XComGameState_Ability(History.GetGameStateForObjectID(OldUnitState.FindAbility(AbilityName).ObjectID));

		if (AssociatedHistoryIndex == -1)
		{
			`log("Invalid history index passed to PerformBreachAbility, this is unexpected but safe. Notify @dakota if encountered", , 'XCom_Breach');
		}

		//Copy the history index so we have the option to use it in logic throughout the method
		AssociatedHistoryIndexInternal = AssociatedHistoryIndex;

		// Decide whether to run in series or parallel based on the visualization systems that this ability will use
		if (class'X2Ability'.static.AbilityCanUseMatineeVisualizer(AbilityName) || !class'XComTacticalGRI'.static.GetBreachActionSequencer().BreachActionSequencerEnabled)
		{			
			AssociatedHistoryIndexInternal = -1; // Setting an invalid history index guarantees sequential
		}
		
		if (BattleData.IsInBreachSubPhaseSequenceCamera())
		{
			// If the breach action sequence camera should be active during this sub-phase
			// we need to parallelize all actions if possible, provided there is a history frame of reference (breach checkpoint)
			bForceParallel = (AssociatedHistoryIndexInternal != -1);
		}

		if (BreachData.bIsInitialMove)
		{
			AssociatedHistoryIndexInternal = AssociatedHistoryIndex; //Override the settings above, this movement should always occur in parallel
			PerformBreachInitialMove(BreachData, kPathingPawn, OutPathInput, AssociatedHistoryIndexInternal);
		}		
		else if (BreachData.bIsPostAbilityMove)
		{
			AssociatedHistoryIndexInternal = AssociatedHistoryIndex; //Override the settings above, this movement should always occur in parallel
			PerformBreachMovement(BreachData, kPathingPawn, OutPathInput, AssociatedHistoryIndexInternal);
		}
		else if (AbilityName == 'BreachEnemyReactMove')
		{
			`log("SPECIAL Case: PerformEnemyReactionMove", , 'XCom_Breach');
			PerformEnemyReactionMove(BreachData, kPathingPawn, OutPathInput, AssociatedHistoryIndexInternal);
		}
		else if (AbilityName == 'BreachEnemyReactSurprise')
		{
			`log("SPECIAL Case: Perform Enemy Surprised", , 'XCom_Breach');
			AbilityContext = class'XComGameStateContext_Ability'.static.BuildContextFromBreachAbility(ExistingAbility);			
			if (AbilityContext != None)
			{
				AbilityContext.InputContext.AssociatedBreachData = BreachData;
				if (bForceParallel)
				{
					AbilityContext.SetVisualizationStartIndex(AssociatedHistoryIndexInternal, SPT_AfterParallel);
				}
				`XCOMGAME.GameRuleset.SubmitGameStateContext(AbilityContext);
			}
		}
		else if (AbilityName == class'X2Ability_BreachAbilities'.default.BreachBreachingChargeAbilityName 
			  || AbilityName == 'BreachDemoExpertAbility')
		{
			`log("SPECIAL Case: PerformBreachingChargeAbility", , 'XCom_Breach');
			PerformBreachingChargeAbility(BreachData, kPathingPawn, OutPathInput, AssociatedHistoryIndexInternal);
		}
		else
		{
			//`log("Default Case: Breach Ability Context.", , 'XCom_Breach');
			AbilityContext = class'XComGameStateContext_Ability'.static.BuildContextFromBreachAbility(ExistingAbility);
			if (AbilityContext != None)
			{
				AbilityContext.InputContext.AssociatedBreachData = BreachData;
				if (bForceParallel)
				{
					AbilityContext.SetVisualizationStartIndex(AssociatedHistoryIndexInternal, SPT_AfterParallel);
				}
				//`log("AssociatedHistoryIndexInternal:" @ AssociatedHistoryIndexInternal @ "VisStartIndex" @ AbilityContext.VisualizationStartIndex, , 'XCom_Breach');
				`XCOMGAME.GameRuleset.SubmitGameStateContext(AbilityContext);
				//`log("Submitted Breach Ability Context against target ID:" @ AbilityContext.InputContext.PrimaryTarget.ObjectID, , 'XCom_Breach');
			}
			else
			{
				`log("DID NOT create Breach Ability Context, sometimes expected (such as potential targets dying from previous actions).", , 'XCom_Breach');
			}
		}

		//`log("**", , 'XCom_Breach');
	}

	function BreachRedScreenUnitPathFail(BreachActionData BreachData, XComGameState_Unit UnitState, TTile DestinationTile, name ErrorName)
	{
		`if(`notdefined(FINAL_RELEASE))
		local vector DebugSourceLocation, DebugDestinationLocation;
		local float DebugSize;
		`endif
		if( UnitState != None )
		{
			`RedScreen(ErrorName
				$ " ObjectID [" @ UnitState.ObjectID @ "]"
				$ " had no valid breach move for ability [" @ BreachData.AbilityName @ "]"
				$ "\nBreach move priority: [" @ BreachData.MovementPriority @ "]"
				$ "\nDestination Tile: (" @ DestinationTile.X @ DestinationTile.Y @ DestinationTile.Z $ ")."
				$ "\nUnit failed to resolve a path to its destination, check for blocking objects and pathing in level."
				$ " Incorrectly assigned breach movement order can also cause this. Also ensure correct Z values for the breach point, slots, and destinations"
				$ " @level.design @dakota @scott.spanburg ");

			`if(`notdefined(FINAL_RELEASE))
			DebugSourceLocation = `XWORLD.GetPositionFromTileCoordinates(UnitState.TileLocation);
			DebugDestinationLocation = `XWORLD.GetPositionFromTileCoordinates(DestinationTile);
			DebugSize = 20.0f;
			DrawDebugSphere(DebugSourceLocation, DebugSize, 10, 255, 255, 255 , true);
			DrawDebugLine(DebugDestinationLocation + DebugSize * vect(-1,1,0), DebugDestinationLocation + DebugSize * vect(1,-1,0), 255, 0, 0, true);
			DrawDebugLine(DebugDestinationLocation + DebugSize * vect(1,1,0), DebugDestinationLocation + DebugSize * vect(-1,-1,0), 255, 0, 0, true);
			DrawDebugLine(DebugSourceLocation, DebugDestinationLocation, 255, 0, 0, true);
			`endif
		}
	}

	function DrawDebugBreachInitialMovePathInfo(BreachActionData BreachData, XComGameState_Unit UnitState, TTile FormationTile, PathingInputData PathData)
	{
		//`if(`notdefined(FINAL_RELEASE))
		local vector UnitLocation, WaypointLocation, FormationLocation;
		local vector PreviousLocation, DestinationLocation;
		local TTile WaypointTile, DestinationTile;
		local BreachPointInfo PointInfo;
		local BreachSlotInfo SlotInfo;
		local float DebugSize;

		DebugSize = 20.0f;
		
		if (UnitState != None)
		{		
			UnitLocation = `XWORLD.GetPositionFromTileCoordinates(UnitState.TileLocation);
			FormationLocation = `XWORLD.GetPositionFromTileCoordinates(FormationTile);
			DrawDebugSphere(UnitLocation, DebugSize + 10, 10, 255, 255, 255, true);
			PreviousLocation = UnitLocation;
			foreach PathData.WaypointTiles(WaypointTile)
			{
				WaypointLocation = `XWORLD.GetPositionFromTileCoordinates(WaypointTile);
				DrawDebugSphere(WaypointLocation, DebugSize, 10, 255, 255, 255, true);
				DrawDebugLine(PreviousLocation, WaypointLocation, 255, 0, 0, true);
				PreviousLocation = WaypointLocation;
			}
			DrawDebugSphere(FormationLocation, DebugSize + 5, 10, 255, 255, 255, true);
			DrawDebugLine(PreviousLocation, FormationLocation, 255, 0, 0, true);
			PreviousLocation = FormationLocation;

			PointInfo = class'XComBreachHelpers'.static.GetBreachPointInfoForGroupID(BreachData.BreachGroupID);
			SlotInfo = class'XComBreachHelpers'.static.GetUnitBreachSlotInfo(UnitState.ObjectID);
			if (PointInfo.EntryPointActor.GetBreachDestinationTile(SlotInfo.BreachSlotIndex, DestinationTile))
			{
				DestinationLocation = `XWORLD.GetPositionFromTileCoordinates(DestinationTile);
				DrawDebugSphere(DestinationLocation, DebugSize + 10, 10, 255, 255, 255, true);
				DrawDebugLine(PreviousLocation, DestinationLocation, 255, 0, 0, true);
			}
			
		}
		//`endif
	}

	function MoveAttachedUnits(XComGameState_Unit UnitState, array<TTile> MovementPathTiles, out array<PathingInputData> OutPathInput)
	{
		local array<XComGameState_Unit> AttachedUnits;
		local XGUnit CosmeticUnitVisualizer;
		local int Index;
		local TTile Destination, AttachedDestination;
		local PathingInputData PathData;
		local array<TTile> AttachedMovementPathTiles;

		if (UnitState == None || MovementPathTiles.Length == 0)
		{
			return;
		}

		// Move gremlin if we have one (or two, specialist receiving aid protocol) attached to us 
		UnitState.GetAttachedUnits(AttachedUnits);		
		Destination = MovementPathTiles[MovementPathTiles.Length - 1];
		for (Index = 0; Index < AttachedUnits.Length; Index++)
		{
			if (AttachedUnits[Index] != none)
			{
				CosmeticUnitVisualizer = XGUnit(AttachedUnits[Index].GetVisualizer());
				CosmeticUnitVisualizer.bNextMoveIsFollow = true;
				AttachedDestination = Destination;
				AttachedDestination.Z += UnitState.GetDesiredZTileOffsetForAttachedCosmeticUnit();

				AttachedMovementPathTiles.Length = 0;
				CosmeticUnitVisualizer.m_kReachableTilesCache.BuildPathToTile(AttachedDestination, AttachedMovementPathTiles);

				if (AttachedMovementPathTiles.Length == 0)
				{
					class'X2PathSolver'.static.BuildPath(AttachedUnits[Index], AttachedUnits[Index].TileLocation, AttachedDestination, AttachedMovementPathTiles);
				}
				if (AttachedMovementPathTiles.Length <= 0)
				{
					continue; // Unable to move the attached unit
				}

				PathData.MovementTiles = AttachedMovementPathTiles;
				PathData.MovingUnitRef.ObjectID = AttachedUnits[Index].ObjectID;
				OutPathInput.AddItem(PathData);
			}
		}
	}

	function PerformBreachInitialMove(BreachActionData BreachData, out XComPathingPawn kPathingPawn, out array<PathingInputData> OutPathInput, int AssociatedHistoryIndex)
	{
		local XComGameStateHistory History;
		local XComGameStateContext_Ability BreachMoveContext;
		local XComGameState_Unit OldUnitState;
		local StateObjectReference MovingUnitRef;
		local PathingInputData PathData;
		local array<TTile> MovementPathTiles, WaypointTiles;
		local bool UnitAlreadyHasAbility;
		local TTile PathDestinationTile;
		local int OutFormationSlotIndex;
		local X2AbilityTemplate AbilityTemplate;

		History = `XCOMHISTORY;

		OldUnitState = XComGameState_Unit(History.GetGameStateForObjectID(BreachData.ObjectID, eReturnType_Reference));
		UnitAlreadyHasAbility = (OldUnitState.FindAbility(BreachData.AbilityName).ObjectID > 0);
		`assert(UnitAlreadyHasAbility);

		OutPathInput.Length = 0;

		AbilityTemplate = class'XComGameState_Ability'.static.GetMyTemplateManager().FindAbilityTemplate(BreachData.AbilityName);
		if (AbilityTemplate.BreachInitialMoveBuildPathFn != none)
		{
			// pathing for some breach abilities, rope swing for example,
			// need to be built differently
			AbilityTemplate.BreachInitialMoveBuildPathFn(OldUnitState, BreachData, OutPathInput);
			PathData = OutPathInput[0];
		}
		else
		{
			//Find the formation destination
			PathDestinationTile = class'XComBreachHelpers'.static.FindBreachFormationTileForBreachActionData(BreachData, OutFormationSlotIndex);

			//Calculate a path to the destination
			MovementPathTiles.Length = 0;
			OldUnitState = XComGameState_Unit(History.GetGameStateForObjectID(BreachData.ObjectID, eReturnType_Reference));
			class'XComBreachHelpers'.static.BuildBreachInitialMovePathToTile(OldUnitState, PathDestinationTile, MovementPathTiles, WaypointTiles);
			MovingUnitRef.ObjectID = BreachData.ObjectID;
			PathData.MovingUnitRef = MovingUnitRef;
			PathData.MovementTiles = MovementPathTiles;
			PathData.WaypointTiles = WaypointTiles;

		//DrawDebugBreachInitialMovePathInfo(BreachData, OldUnitState, PathDestinationTile, PathData);
			OutPathInput.AddItem(PathData);

			// Move attached units as well
			MoveAttachedUnits(OldUnitState, MovementPathTiles, OutPathInput);
		}
	
		//BreachInitialMove the soldier to the destination
		if (PathData.MovementTiles.Length > 0)
		{
			BreachMoveContext = InternalCreateBreachMoveContext(BreachData.ObjectID, OutPathInput, BreachData.AbilityName);
			BreachMoveContext.InputContext.AssociatedBreachData = BreachData;
			if (AssociatedHistoryIndex >= 0)
			{
				BreachMoveContext.SetVisualizationStartIndex(AssociatedHistoryIndex, AssociatedHistoryIndex == -1 ? SPT_Template : SPT_AfterParallel);
			}
			`XCOMGAME.GameRuleset.SubmitGameStateContext(BreachMoveContext);
			`XWORLD.ClearTileBlockedByUnitFlag( OldUnitState );
		}
		else
		{
			BreachRedScreenUnitPathFail(BreachData, OldUnitState, PathDestinationTile, BreachData.AbilityName);
		}
	}
	
	function PerformBreachMovement(BreachActionData BreachData, out XComPathingPawn kPathingPawn, out array<PathingInputData> OutPathInput, int AssociatedHistoryIndex)
	{
		local XComGameState NewGameState;
		local XComGameStateContext_Ability BreachMoveContext;
		local XComGameState_Unit OldUnitState;
		local StateObjectReference MovingUnitRef;
		local PathingInputData InitialPathData;
		local array<TTile> MovementPathTiles;
		local XComGameState_Unit NewUnitState;
		
		if (!BreachData.FoundDestinationTile)
		{
			return; //Need a destination to perform breach movement
		}

		//Move/Teleport depending upon the path to our destination
		MovementPathTiles.Length = 0;
		OldUnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BreachData.ObjectID, eReturnType_Reference));
		if( OldUnitState.TileLocation == BreachData.DestinationTile )
		{
			return;	//already there
		}
		class'XComBreachHelpers'.static.BuildBreachUnitPathToTile( OldUnitState, BreachData.DestinationTile, MovementPathTiles );
		if (MovementPathTiles.Length > 1)
		{
			// Construct the path
			OutPathInput.Length = 0;
			MovingUnitRef.ObjectID = BreachData.ObjectID;
			InitialPathData.MovingUnitRef = MovingUnitRef;
			InitialPathData.MovementTiles = MovementPathTiles;
			kPathingPawn.GetWaypointTiles(InitialPathData.WaypointTiles);
			OutPathInput.AddItem(InitialPathData);

			// Move attached units as well
			MoveAttachedUnits(OldUnitState, MovementPathTiles, OutPathInput);

			// Submit the move ability context
			BreachMoveContext = InternalCreateBreachMoveContext(BreachData.ObjectID, OutPathInput);
			BreachMoveContext.InputContext.AssociatedBreachData = BreachData;
			if (AssociatedHistoryIndex >= 0)
			{
				BreachMoveContext.SetVisualizationStartIndex(AssociatedHistoryIndex, AssociatedHistoryIndex == -1 ? SPT_Template : SPT_AfterParallel);
			}
			`XCOMGAME.GameRuleset.SubmitGameStateContext(BreachMoveContext);
		}
		else
		{
			BreachRedScreenUnitPathFail(BreachData, OldUnitState, BreachData.DestinationTile, 'PerformBreachMovement' );
			//Teleport all soldiers to the end point of their breach markers
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("BreachSequence: Teleport Unit");
			XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = BreachMovementFailureTeleport_BuildVisualization;
			NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', BreachData.ObjectID));
			NewUnitState.bRequiresVisibilityUpdate = true;
			NewUnitState.SetVisibilityLocation(BreachData.DestinationTile);
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
	}
	
	function PerformEnemyReactionMove(BreachActionData BreachData, out XComPathingPawn kPathingPawn, out array<PathingInputData> OutPathInput, int AssociatedHistoryIndex)
	{
		local XComGameStateContext_Ability StandardMoveContext;
		local XComGameState_BattleData BattleData;
		local XComGameState_Unit OldUnitState;
		local X2AbilityTemplateManager AbilityTemplateManager;
		local StateObjectReference MovingUnitRef;
		local XGUnit UnitVisualizer;
		local PathingInputData InitialPathData;
		local array<TTile> MovementPathTiles;
		local TTile MoveDestinationTile;
		local name MoveProfileName;
		local bool bFoundMoveDestination;

		AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
		`assert(AbilityTemplateManager != None);
		BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		`assert(BattleData != None);
		
		OldUnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BreachData.ObjectID, eReturnType_Reference));
		if (OldUnitState == None || OldUnitState.IsDead() || OldUnitState.IsIncapacitatedCapturedOrDowned())
		{
			`log("Unit is invalid, dead, or incapacitated. No need to perform reaction move.", , 'XCom_Breach');
			return;
		}

		UnitVisualizer = XGUnit(OldUnitState.GetVisualizer());
		MoveProfileName = OldUnitState.GetMyTemplate().BreachReactionMovementProfile;
		// Only move visualizer units with a move profile
		if (UnitVisualizer == None || UnitVisualizer.m_kBehavior == None || MoveProfileName == '')
		{
			`log("FAILED, no valid move profile, visualizer, or behavior.", , 'XCom_Breach');
			return;
		}

		// Perform a reaction move if we can
		bFoundMoveDestination = UnitVisualizer.m_kBehavior.BT_FindDestinationForBreachReactionMovement(MoveProfileName, MoveDestinationTile);
		if (bFoundMoveDestination)
		{
			MovementPathTiles.Length = 0;
			UnitVisualizer.m_kReachableTilesCache.BuildPathToTile(MoveDestinationTile, MovementPathTiles);
			if (MovementPathTiles.Length > 1)
			{
				`log("SUCCESS, built path to valid destination", , 'XCom_Breach');
				// Construct the path
				OutPathInput.Length = 0;
				MovingUnitRef.ObjectID = OldUnitState.ObjectID;
				InitialPathData.MovingUnitRef = MovingUnitRef;
				InitialPathData.MovementTiles = MovementPathTiles;
				kPathingPawn.GetWaypointTiles(InitialPathData.WaypointTiles);
				OutPathInput.AddItem(InitialPathData);
				// Submit the move ability context
				StandardMoveContext = InternalCreateBreachMoveContext(OldUnitState.ObjectID, OutPathInput, 'BreachMove');
				StandardMoveContext.InputContext.AssociatedBreachData = BreachData;
				if (AssociatedHistoryIndex >= 0)
				{
					StandardMoveContext.SetVisualizationStartIndex(AssociatedHistoryIndex, AssociatedHistoryIndex == -1 ? SPT_Template : SPT_AfterParallel);
				}
				`XCOMGAME.GameRuleset.SubmitGameStateContext(StandardMoveContext);
			}
			else
			{
				`log("FAILED, could not build path to valid destination", , 'XCom_Breach');
			}
		}
		else
		{
			`log("FAILED, found no valid destination", , 'XCom_Breach');
		}
	}

	function RunPostBreachEnemyBehaviors()
	{
		local array<XComGameState_Unit> BreachXComUnits;
		local array<XComGameState_Unit> BreachEnemies;
		local XComGameState_Unit LoopUnitState;
		local XComGameState_Unit FirstXComUnit;
		
		`log("**** POST BREACH ENEMY BEHAVIORS ****", , 'XCom_Breach');

		class'XComBreachHelpers'.static.GatherXComBreachUnits( BreachXComUnits );
		if( BreachXComUnits.Length > 0 )
		{
			FirstXComUnit = BreachXComUnits.Length > 0 ? BreachXComUnits[0] : None;
		}

		// Run post-breach behavior trees
		class'XComBreachHelpers'.static.GatherBreachEnemies(BreachEnemies);
		foreach BreachEnemies(LoopUnitState)
		{
			if (LoopUnitState.ActionPoints.Length > 0)
			{
				`log(LoopUnitState.ObjectID @ LoopUnitState.GetName(eNameType_Nick) @ "performing breach scamper",,'XCom_Breach');
			}
			//`log(LoopUnitState.ObjectID @ "initiating reflex move for its group (scamper behavior trees). ActionPoints:" @ LoopUnitState.ActionPoints.Length, , 'XCom_Breach');
			LoopUnitState.GetGroupMembership().InitiateReflexMoveActivate(FirstXComUnit, eAC_MapwideAlert_Hostile);
		}
	}
		
	function PerformBreachingChargeAbility(BreachActionData BreachData, out XComPathingPawn kPathingPawn, out array<PathingInputData> OutPathInput, int AssociatedHistoryIndex)
	{
		local XComWorldData WorldData;
		local array<XComDeploymentSpawn> DeploymentSpawns;
		local array<BreachEntryPointMarker> BreachEntryPoints;
		local BreachEntryPointMarker EntryPoint;
		local XComDeploymentSpawn DeploySpawn;
		local XComGameStateHistory History;
		local XComGameState_BattleData BattleData;
		local XComGameStateContext_Ability AbilityContext;
		local XComGameState_Ability ExistingAbility;
		local XComGameState_Unit OldUnitState;
		local TTile TargetTile;
		local vector TargetLocation;
		local array<vector> TargetLocations;
		local bool bUnitAlreadyHasAbility;
		local AvailableTarget Targets;
		local array<int> AdditionalTargetIDS;
		local int Index;

		History = `XCOMHISTORY;
		WorldData = `XWORLD;
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

		OldUnitState = XComGameState_Unit(History.GetGameStateForObjectID(BreachData.ObjectID, eReturnType_Reference));
		bUnitAlreadyHasAbility = (OldUnitState.FindAbility(BreachData.AbilityName).ObjectID > 0);
		`assert(bUnitAlreadyHasAbility);
		ExistingAbility = XComGameState_Ability(History.GetGameStateForObjectID(OldUnitState.FindAbility(BreachData.AbilityName).ObjectID));
		
		// Gather all deploy spawns, stuff into breach point and slot infos
		WorldData.GetDeploymentSpawnActors(DeploymentSpawns, BattleData.BreachingRoomID);
		WorldData.GetBreachEntryPointActors(BreachEntryPoints);

		foreach DeploymentSpawns(DeploySpawn)
		{
			if (DeploySpawn.GetTile() == BreachData.BreachTile)
			{
				foreach BreachEntryPoints(EntryPoint)
				{
					if (EntryPoint.BreachGroupID == DeploySpawn.BreachGroupID)
					{
						TargetLocation = EntryPoint.Location;
						TargetTile = WorldData.GetTileCoordinatesFromPosition(TargetLocation);
						TargetLocation = WorldData.GetPositionFromTileCoordinates(TargetTile);
						TargetLocations.AddItem(TargetLocation);
		
						// set the multitargets
 						ExistingAbility.GatherAdditionalAbilityTargetsForLocation(TargetLocation, Targets);
						for( Index = 0; Index < Targets.AdditionalTargets.length; Index++ )
						{
							AdditionalTargetIDS.AddItem( Targets.AdditionalTargets[Index].ObjectID );
						}

						// Perform the ability at the breach entry point
						AbilityContext = class'XComGameStateContext_Ability'.static.BuildContextFromAbility(ExistingAbility, BreachData.ObjectID, AdditionalTargetIDS, TargetLocations);
						AbilityContext.InputContext.AssociatedBreachData = BreachData;						
						AbilityContext.SetVisualizationStartIndex(AssociatedHistoryIndex, AssociatedHistoryIndex == -1 ? SPT_Template : SPT_AfterParallel);
						`XCOMGAME.GameRuleset.SubmitGameStateContext(AbilityContext);
		
						return;
					}
				}
			}
		}

		// If we didn't find an entry point to target, just perform it basically
		AbilityContext = class'XComGameStateContext_Ability'.static.BuildContextFromBreachAbility(ExistingAbility);
		if (AbilityContext != None)
		{
			AbilityContext.InputContext.AssociatedBreachData = BreachData;
			AbilityContext.SetVisualizationStartIndex(AssociatedHistoryIndex, AssociatedHistoryIndex == -1 ? SPT_Template : SPT_AfterParallel);
			`XCOMGAME.GameRuleset.SubmitGameStateContext(AbilityContext);
		}
	}

	function XComGameStateContext_Ability InternalCreateBreachMoveContext(int BreachUnitObjectID,
		array<PathingInputData> OutPathInput,
		optional name MoveAbilityTemplateName = 'BreachMove')
	{
		local XComGameStateContext_Ability BreachMoveContext;
		local XComGameState_Unit OldUnitState;
		local XComGameState_Ability UnitAbility;
		local StateObjectReference AbilityRef;
		local PathingInputData PathData;
		local PathingResultData PathResultData;
		local int PathIndex;
		
		OldUnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BreachUnitObjectID, eReturnType_Reference));

		AbilityRef = OldUnitState.FindAbility(MoveAbilityTemplateName);
		UnitAbility = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(AbilityRef.ObjectID));
		`assert(UnitAbility != none);

		//Build the context for the move ability
		BreachMoveContext = XComGameStateContext_Ability(class'XComGameStateContext_Ability'.static.CreateXComGameStateContext());
		BreachMoveContext.InputContext.AbilityRef = UnitAbility.GetReference();
		BreachMoveContext.InputContext.AbilityTemplateName = UnitAbility.GetMyTemplateName();
		BreachMoveContext.InputContext.SourceObject = OldUnitState.GetReference();

		for (PathIndex = 0; PathIndex < OutPathInput.Length; ++PathIndex)
		{
			//Copy to temp to satisfy UC reference rules		
			PathData = OutPathInput[PathIndex];

			// fill out extra input data
			class'XComTacticalController'.static.CreatePathDataForPathTiles(PathData);
			BreachMoveContext.InputContext.MovementPaths.AddItem(PathData);

			// fill out the result context for each movement path
			class'X2TacticalVisibilityHelpers'.static.FillPathTileData(OutPathInput[PathIndex].MovingUnitRef.ObjectID, OutPathInput[PathIndex].MovementTiles, PathResultData.PathTileData);
			BreachMoveContext.ResultContext.PathResults.AddItem(PathResultData);
		}

		return BreachMoveContext;
	}
		
	function OrientCameraForBreach(int BreachRoomID)
	{
		local float Yaw;

		Yaw = class'X2Action_InitBreachCamera'.static.GetBreachCameraYawForRoom(BreachRoomID);
		`CAMERASTACK.YawCameras(Yaw);
	}
		
	function AdvanceBreachSubPhaseToGameCamera()
	{
		local XComGameState NewGameState;
		local XComGameState_BattleData BattleData;
		local XComGameStateHistory History;
		local X2UnifiedProjectile Projectile;

		History = `XCOMHISTORY;
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', false));

		// destroy existing projectiles, their time is over
		foreach WorldInfo.AllActors(class'X2UnifiedProjectile', Projectile)
		{
			Projectile.Destroy();
		}
		bBlockProjectileCreation = true;

		// Only transition cameras once, later phases may be added after this one
		if (BattleData.BreachSubPhase < eBreachSubPhase_GameCamera)
		{
			class'XComTacticalGRI'.static.GetBreachActionSequencer().EndBreachFireSlomoBlock();

			//Put the xcom squad back into regular visibility mode
			ControlUnitVisibilityForBreach(none);

			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breach: Switch to Game Camera");
			BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
			BattleData.BreachSubPhase = eBreachSubPhase_GameCamera;
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

			`log("**** BREACH SEQ SWITCH TO GAME CAMERA ****", , 'XCom_Breach');

			`XEVENTMGR.TriggerEvent('BreachSequence_SwitchToGameCamera');

			DeactivateKeepLastViewCamera(); // Calls to this function expect visualizers to have finished before swapping cameras
		}
	}

	function int SubmitResetUnitsCheckpoint(string Label)
	{
		local XComGameStateContext_ChangeContainer ChangeContainerContext;
		local XComGameState NewGameState;
		local XComGameStateHistory History;

		History = `XCOMHISTORY;

		// Add a ChangeContainer with a visualization so a VisualizationStartIndex can reference it
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("ResetUnits: "$Label);
		ChangeContainerContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
		ChangeContainerContext.BuildVisualizationFn = BreachResetUnitsBuildVisualization;
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		// return the history index of the change we just submitted
		return History.GetCurrentHistoryIndex();
	}

	function ResetUnitsForBreach()
	{
		//local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_BattleData BattleData;
		local XComGameState_Unit UnitState, NewUnitState, AttachedUnitState, NewAttachedUnitState;
		local array<XComGameState_Unit> AttachedUnits;
		local XComWorldData WorldData;		
		local array<XComGameState_Unit> XComSoldierUnits;
		local array<int> XComSoldierIDs;
		local int UnitObjectID;
		local XGUnit UnitVisualizer;
		local array<BreachEntryPointMarker> BreachEntryPoints;
		local BreachEntryPointMarker BreachEntryPoint;

		//History = `XCOMHISTORY;
		WorldData = `XWORLD;
		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

		// On multi-breach missions, subsequent breaches need a round of cleanup
		if (BattleData.BreachingRoomListIndex <= 0)
		{
			return; // First breach in the mission, don't reset anything
		}

		//Gather the XCom Soldiers
		XComSoldierIDs.Length = 0;
		class'XComBreachHelpers'.static.GatherXComBreachUnits( XComSoldierUnits );
		foreach XComSoldierUnits(UnitState)
		{
			//`assert(UnitState.bReadOnly == false);
			if (UnitState.bReadOnly)
			{
				`Redscreen("ResetUnitsForBreach: UnitState bReadOnly is true, objectID" @ UnitState.ObjectID @ "@dakota.lemaster");
				`log("ResetUnitsForBreach: UnitState bReadOnly is true, objectID" @ UnitState.ObjectID, , 'XCom_Breach');
				continue;
			}
			XComSoldierIDs.AddItem(UnitState.ObjectID);
		}

		// Position units in front of the breaching room, ready to be assigned spots
		if (ParcelManager == None)
		{
			`Redscreen("No valid Parcel Manager found when trying to reset breach units @dakota.lemaster");
			return; // Need the parcel manager to find a soldier spawn
		}

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("BreachResetUnits: NewGroupSpawnChosen");
		WorldData.GetBreachEntryPointActors(BreachEntryPoints, BattleData.BreachingRoomID);
		//`assert(BreachEntryPoints.length > 0);
		if (BreachEntryPoints.length <= 0)
		{
			`Redscreen("ResetUnitsForBreach: BreachEntryPoints length is zero. Room ID" @ BattleData.BreachingRoomID @ "@level.design @dakota.lemaster");
			`log("ResetUnitsForBreach: BreachEntryPoints length is zero", , 'XCom_Breach');
		}
		else
		{
			BreachEntryPoint = BreachEntryPoints[0];
			foreach XComSoldierIDs(UnitObjectID)
			{
				NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitObjectID));
				NewUnitState.bRequiresVisibilityUpdate = true;
				NewUnitState.SetVisibilityLocationFromVector(BreachEntryPoint.Location);
				UnitVisualizer = XGUnit(NewUnitState.GetVisualizer());
				if (UnitVisualizer != None)
				{
					UnitVisualizer.SetForceVisibility(eForceNotVisible);
					UnitVisualizer.GetPawn().UpdatePawnVisibility();
				}
				NewUnitState.GetAttachedUnits(AttachedUnits);
				foreach AttachedUnits(AttachedUnitState)
				{
					NewAttachedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AttachedUnitState.ObjectID));
					NewAttachedUnitState.bRequiresVisibilityUpdate = true;
					NewAttachedUnitState.SetVisibilityLocationFromVector(BreachEntryPoint.Location);
					UnitVisualizer = XGUnit(`XCOMHISTORY.GetVisualizer(NewAttachedUnitState.ObjectID));
					if (UnitVisualizer != None)
					{
						UnitVisualizer.SetForceVisibility(eForceNotVisible);
						UnitVisualizer.GetPawn().UpdatePawnVisibility();
					}
				}
			}
		}
		SubmitGameState(NewGameState);
		return;
	}

	function ResetSoldierForBreachPlacement(int UnitObjectID, optional bool bRefreshInfos = true, optional bool bCascadeUnslotting = true)
	{
		local XComGameStateHistory History;
		local XComWorldData WorldData;
		local XComGameState_BreachData BreachDataState;
		local XComGameState NewGameState;		
		local XComGameState_Unit AttachedUnitState, NewUnitState, NewAttachedUnitState;
		local array<XComGameState_Unit> AttachedUnits;
		local TTile DestinationTile;
		local bool bUnslotSequentialUnits;
		local BreachPointInfo PointInfo;
		local BreachSlotInfo SlotInfo;
		local array<int> CascadeObjectIDs;		
		local int CascadeObjectID;
		//local XGUnit UnitVisualizer;

		History = `XCOMHISTORY;
		WorldData = `XWORLD;
		BreachDataState = XComGameState_BreachData(History.GetSingleGameStateObjectForClass(class'XComGameState_BreachData', false));
		if (UnitObjectID <= 0)
		{
			return;
		}
		
		if (ParcelManager == None)
		{
			`Redscreen("No valid Parcel Manager found when trying to reset breach units @dakota.lemaster");
			return; // Need the parcel manager to find a soldier spawn
		}

		// Find all units that would also need to be ejected from their breach slots based upon order dependency
		if (bCascadeUnslotting)
		{
			bUnslotSequentialUnits = false;
			foreach BreachDataState.CachedBreachPointInfos(PointInfo)
			{
				foreach PointInfo.BreachSlots(SlotInfo)
				{
					if (SlotInfo.BreachUnitObjectRef.ObjectID == UnitObjectID)
					{
						bUnslotSequentialUnits = true;
					}
					else if (bUnslotSequentialUnits && SlotInfo.BreachUnitObjectRef.ObjectID > 0)
					{
						CascadeObjectIDs.AddItem(SlotInfo.BreachUnitObjectRef.ObjectID);
					}
				}
				if (bUnslotSequentialUnits)
				{
					break; // only unslot sequential units at the same breach point, we're done here
				}
			}
		}

		// Build a game state to move the unit to its new location
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breach: Set Unit");
		XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = class'XComTacticalInput'.static.BreachSetUnit_BuildVisualization;
		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitObjectID));
		NewUnitState.bRequiresVisibilityUpdate = true;
		NewUnitState.bBreachAssigned = false;

		// Move the unit to the closest breach point
		PointInfo = class'XComBreachHelpers'.static.GetUnitBreachPointInfo(NewUnitState);
		WorldData.GetFloorTileForPosition(PointInfo.BreachPointLocation, DestinationTile);
		NewUnitState.SetVisibilityLocation(DestinationTile);
		NewUnitState.GetAttachedUnits(AttachedUnits);
		foreach AttachedUnits(AttachedUnitState)
		{
			NewAttachedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AttachedUnitState.ObjectID));
			NewAttachedUnitState.bRequiresVisibilityUpdate = true;
			NewAttachedUnitState.SetVisibilityLocation(DestinationTile);
		}
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		`XTACTICALSOUNDMGR.PreBreachUnitUnplaced();

		foreach CascadeObjectIDs(CascadeObjectID)
		{
			ResetSoldierForBreachPlacement(CascadeObjectID, false, false);
		}

		if (bRefreshInfos)
		{
			class'XComBreachHelpers'.static.RefreshBreachPointAndSlotInfos();
			//LogRelativeTurnOrder();
		}
	}

	function AssignSoldierBreachPlacement(int PlacingUnitObjectID, int BreachGroupID, int BreachSlotIndex)
	{
		local XComDeploymentSpawn ClickedDeploySpawn;
		local XComGameStateHistory History;
		local XComDeploymentSpawn PreviousDeploySpawn;
		local XComGameState NewGameState;
		local XComGameState_Unit UnitState, AttachedUnitState, NewUnitState, NewAttachedUnitState;
		local Object EventData, EventSource;
		local string DebugString;
		local array<XComGameState_Unit> AttachedUnits;
		local BreachSlotInfo SlotInfo;
		local Name DefaultActionName;
		local array<name> AllowedTemplateNames;
		local array<int> CascadeObjectIDs;
		local int CascadeObjectID;
		local bool bUnslotSequentialUnits;
		local BreachSlotInfo CascadeSlotInfo;
		local BreachPointInfo PointInfo;
		local XComGameState_BreachData BreachDataState;

		History = `XCOMHISTORY;
		ClickedDeploySpawn = class'XComBreachHelpers'.static.GetDeploymentSpawnByGroupSlotIDs(BreachGroupID, BreachSlotIndex);
		if (ClickedDeploySpawn == None)
		{
			return; // Didn't click on a breach tile
		}
		
		SlotInfo = class'XComBreachHelpers'.static.GetDeploymentSpawnBreachSlotInfo(ClickedDeploySpawn);
		if (SlotInfo.BreachUnitObjectRef.ObjectID > 0)
		{
			return; // This function is responsible for assignment to empty slots, not swapping of units
		}
		
		if (SlotInfo.bIsSlotLocked)
		{
			return; //Validate unit was placed sequentially, this is enforced by the UI currently
		}

		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(PlacingUnitObjectID));
				
		// validate breach ability
		DefaultActionName = class'XComBreachHelpers'.static.GetDefaultActionNameForDeploymentSpawn(ClickedDeploySpawn);
		class'XComBreachHelpers'.static.GetAllowableBreachActionTemplateNames(ClickedDeploySpawn, DefaultActionName, PlacingUnitObjectID, AllowedTemplateNames, false);
		if (AllowedTemplateNames.Length <= 0)
		{
			DebugString = "AssignBreachPosition failed to assign unit"
				@ PlacingUnitObjectID
				@ ","
				@ UnitState.SafeGetCharacterFirstName()
				@ "to deploy spawn"
				@ ClickedDeploySpawn.Name
				@ ","
				@ "with action"
				@ ClickedDeploySpawn.SelectedBreachActionTemplateName
				@ ". This should have been validated and prevented before this point. @dakota";
		
			`log(DebugString, , 'XCom_Breach');
			return;
		}

		// Check to see if we're already on a breach tile, find our previous deploy spawn
		PreviousDeploySpawn = class'XComBreachHelpers'.static.GetUnitDeploymentSpawn(UnitState);
		if (PreviousDeploySpawn != None)
		{
			BreachDataState = XComGameState_BreachData(History.GetSingleGameStateObjectForClass(class'XComGameState_BreachData', false));
			PointInfo = class'XComBreachHelpers'.static.GetDeploymentSpawnBreachPointInfo(ClickedDeploySpawn);
			// Find all units that would also need to be ejected from their breach slots based upon order dependency
			bUnslotSequentialUnits = false;
			foreach BreachDataState.CachedBreachPointInfos(PointInfo)
			{
				foreach PointInfo.BreachSlots(CascadeSlotInfo)
				{
					if (CascadeSlotInfo.BreachUnitObjectRef.ObjectID == PlacingUnitObjectID)
					{
						bUnslotSequentialUnits = true;
					}
					else if (bUnslotSequentialUnits && CascadeSlotInfo.BreachUnitObjectRef.ObjectID > 0)
					{
						CascadeObjectIDs.AddItem(CascadeSlotInfo.BreachUnitObjectRef.ObjectID);
					}
				}
				if (bUnslotSequentialUnits)
				{
					break; // only unslot sequential units at the same breach point, we're done here
				}
			}
		}
		
		// Select the newly placed unit
		//XComTacticalController(GetALocalPlayerController()).Visualizer_SelectUnit(UnitState);
		//TODO: @dakota STILL NECESSARY??

		// Build a game state to move the unit to its new location
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breach: Set Unit");
		XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = class'XComTacticalInput'.static.BreachSetUnit_BuildVisualization;
		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', PlacingUnitObjectID));
		NewUnitState.bRequiresVisibilityUpdate = true;
		NewUnitState.bBreachAssigned = true;
		NewUnitState.SetVisibilityLocation(SlotInfo.BreachSlotTileLocation);
		NewUnitState.GetAttachedUnits(AttachedUnits);
		foreach AttachedUnits(AttachedUnitState)
		{
			NewAttachedUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AttachedUnitState.ObjectID));
			NewAttachedUnitState.bRequiresVisibilityUpdate = true;
			NewAttachedUnitState.bBreachAssigned = true;
			NewAttachedUnitState.SetVisibilityLocation(SlotInfo.BreachSlotTileLocation);
		}

		EventData = NewUnitState;
		EventSource = ClickedDeploySpawn;

		`XEVENTMGR.TriggerEvent('UnitDeployedToBreachPoint_StateTrigger', EventData, EventSource, NewGameState);
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		// Play a sound when assigning a unit to a breach point from the pool
		if (PreviousDeploySpawn == None)
		{
			`XTACTICALSOUNDMGR.PreBreachUnitPlaced();
		}

		// When placing a unit, reset the breach action to the first allowed template
		ClickedDeploySpawn.ResetActionTemplateNameToUnitDefault(NewUnitState.ObjectID);

		// If previously assigned, reset the previous action template and the selected breach point groups
		if (PreviousDeploySpawn != None)
		{
			PreviousDeploySpawn.ResetActionTemplateName();

			foreach CascadeObjectIDs(CascadeObjectID)
			{
				ResetSoldierForBreachPlacement(CascadeObjectID, false, false);
			}
		}

		// Notify other game systems that a breach slot assignment has occurred
		`XEVENTMGR.TriggerEvent('UI_UnitDeployedToBreachPoint_OnVisBlockCompleted', EventData, EventSource);
		
		class'XComBreachHelpers'.static.RefreshBreachPointAndSlotInfos();
		//LogRelativeTurnOrder();
	}

	function SwapSoldierBreachPlacement(int UnitObjectID, int OtherObjectID)
	{
		local XComGameState NewGameState;
		local XComGameState_Unit NewUnitState, NewOtherState, AttachedUnitState, NewAttachedState;
		local array<XComGameState_Unit> AttachedUnits;
		local TTile UnitTile, OtherTile;
		local XComDeploymentSpawn UnitSpawn, OtherSpawn;
		local Object EventData, EventSource;
		local bool UnitBreachAssigned, OtherBreachAssigned;
		
		if (UnitObjectID <= 0 || OtherObjectID <= 0)
		{
			return;
		}

		// Build a game state to swap the units locations
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breach: Set Unit");
		XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = class'XComTacticalInput'.static.BreachSetUnit_BuildVisualization;
		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitObjectID));
		NewOtherState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', OtherObjectID));
		
		//cache data from unit
		UnitTile = NewUnitState.TileLocation;
		UnitBreachAssigned = NewUnitState.bBreachAssigned;
		UnitSpawn = class'XComBreachHelpers'.static.GetUnitDeploymentSpawn(NewUnitState);

		//cache data from other unit
		OtherTile = NewOtherState.TileLocation;
		OtherBreachAssigned = NewOtherState.bBreachAssigned;		
		OtherSpawn = class'XComBreachHelpers'.static.GetUnitDeploymentSpawn(NewOtherState);

		// Move the unit + attached
		NewUnitState.bRequiresVisibilityUpdate = true;
		NewUnitState.bBreachAssigned = OtherBreachAssigned;
		NewUnitState.SetVisibilityLocation(OtherTile);
		NewUnitState.GetAttachedUnits(AttachedUnits);
		foreach AttachedUnits(AttachedUnitState)
		{
			NewAttachedState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AttachedUnitState.ObjectID));
			NewAttachedState.bRequiresVisibilityUpdate = true;
			NewAttachedState.bBreachAssigned = OtherBreachAssigned;
			NewAttachedState.SetVisibilityLocation(OtherTile);
		}
		// Move the other + attached
		NewOtherState.bRequiresVisibilityUpdate = true;
		NewOtherState.bBreachAssigned = UnitBreachAssigned;
		NewOtherState.SetVisibilityLocation(UnitTile);
		AttachedUnits.Length = 0;
		NewOtherState.GetAttachedUnits(AttachedUnits);
		foreach AttachedUnits(AttachedUnitState)
		{
			NewAttachedState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AttachedUnitState.ObjectID));
			NewAttachedState.bRequiresVisibilityUpdate = true;
			NewAttachedState.bBreachAssigned = UnitBreachAssigned;
			NewAttachedState.SetVisibilityLocation(UnitTile);
		}
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		// Sound is played elsewhere. Breach unit count remains the same.
		
		UnitSpawn.ResetActionTemplateNameToUnitDefault(OtherObjectID);
		OtherSpawn.ResetActionTemplateNameToUnitDefault(UnitObjectID);

		// Notify other game systems that a breach slot assignment has occurred
		EventData = NewUnitState;
		EventSource = OtherSpawn;
		`XEVENTMGR.TriggerEvent('UI_UnitDeployedToBreachPoint_OnVisBlockCompleted', EventData, EventSource);

		class'XComBreachHelpers'.static.RefreshBreachPointAndSlotInfos();
		//LogRelativeTurnOrder();
	}
	

	function PrepareBreachUnitsFogAndCamera()
	{
		local XComGameState_BattleData BattleData;
		local int BreachIndex;

		// fixed camera vars
		local BreachEntryPointMarker BreachEntryPoint;
		local X2Camera_Fixed FixedBreachCamera;
		local TPOV BreachCameraPOV;
		local CameraActor CameraActor;
		local XComGameState_BreachData BreachDataState;
		local BreachPointInfo PointInfo;
		
		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

		HideDeploymentSpawns();
		SetupFOWStatus_Breach();		

		// Update all XCom Soldier units to get ready for breach phase
		ResetUnitsForBreach();

		// init breach cameras
		// in order to support switching camera modes, we need to initialize these cameras
		// even if we are not in 'staged camera mode' at the moment
		FixedBreachCameras.length = 0;
		CurrentBreachCameraIndex = -1;
		
		BreachDataState = XComGameState_BreachData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BreachData'));
		foreach BreachDataState.CachedBreachPointInfos(PointInfo)
		{
			BreachEntryPoint = PointInfo.EntryPointActor;
			if (BreachEntryPoint.BreachCamera == none)
			{
				continue;
			}

			BreachCameraPOV.Location = BreachEntryPoint.BreachCamera.Location;
			BreachCameraPOV.Rotation = BreachEntryPoint.BreachCamera.Rotation;
			CameraActor = CameraActor(BreachEntryPoint.BreachCamera);
			if (CameraActor != none)
			{
				BreachCameraPOV.FOV = CameraActor.FOVAngle;
			}

			FixedBreachCamera = new class 'X2Camera_Fixed';
			FixedBreachCamera.bBlend = bBlendBreachCamera;
			FixedBreachCamera.bRequireLOStoBlend = true;
			FixedBreachCamera.bDisableFOW = true;
			FixedBreachCamera.bPlayAnim = true;
			FixedBreachCamera.BreachGroupID = BreachEntryPoint.BreachGroupID;
			FixedBreachCamera.SetCameraView(BreachCameraPOV);
			FixedBreachCameras.AddItem(FixedBreachCamera);
		}
		FixedBreachCameras.Sort(SortBreachCamerasByGroupID);

		//Activate a breach camera right away if this is the first breach encounter, and disable blending
		BreachIndex = BattleData.MapData.RoomIDs.Find(BattleData.BreachingRoomID);
		if (BreachIndex == 0)
		{
			ActivateBreachCamera(,true,true);
		}		
	}

	//After the initial cut, we want the cameras to blend again
	function RestoreCameraBlends()
	{
		local X2Camera_Fixed Camera;

		foreach FixedBreachCameras(Camera)
		{
			Camera.bBlend = bBlendBreachCamera;
		}
	}

	function AutoAssignToBreachStarts()
	{
		local BreachPointInfo PointInfo;
		local BreachSlotInfo SlotInfo;
		local XComGameState NewGameState;
		local XComGameState_Unit UnitState, NewUnitState, AttachedUnitState;
		local XComGameStateContext_ChangeContainer ChangeContainerContext;
		local array<XComGameState_Unit> AttachedUnits;
		local array<XComGameState_Unit> XComSoldierUnits;
		local TTile DeployTile;
		local int FoundIndex;
		local int PlacementAttemptCount;
		local bool bAssignedUnit;
		local array<int> AssignedBreachGroupIDs;
		local XComGameState_BreachData BreachDataState;

		BreachDataState = XComGameState_BreachData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BreachData'));

		if (BreachDataState != None)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("AutoAssignUnits");
			ChangeContainerContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
			ChangeContainerContext.BuildVisualizationFn = BreachAutoAssignUnitsBuildVisualization;
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

			//Gather the XCom Soldiers
			class'XComBreachHelpers'.static.GatherXComBreachUnits(XComSoldierUnits);
			foreach XComSoldierUnits(UnitState)
			{
				bAssignedUnit = false;
				PlacementAttemptCount = 0;
				while (PlacementAttemptCount < 2 && !bAssignedUnit)
				{
					foreach BreachDataState.CachedBreachPointInfos(PointInfo)
					{
						// if bAutoAssignGoWide, then skip over this breach point if a soldier is already assigned to it. If PlacementAttemptCount is greater than 0,
						// skip this logic and assign them to whatever breach points will take them.
						if (AssignedBreachGroupIDs.Find(PointInfo.BreachGroupID) > -1 && bAutoAssignGoWide && PlacementAttemptCount < 1)
						{
							break;
						}

						if (PointInfo.EntryPointActor.bIgnoreDuringAutoAssignment)
							continue;

						foreach PointInfo.BreachSlots(SlotInfo)
						{
							if (SlotInfo.DeploySpawn.bIgnoreDuringAutoAssignment)
								continue;
							if (SlotInfo.BreachUnitObjectRef.ObjectID > 0)
								continue;
							if (SlotInfo.BreachSlotIndex > PointInfo.NumXComSoldiersAssignedSequentially)
								continue;

							FoundIndex = SlotInfo.PerUnitAssignmentInfos.Find('UnitObjectID', UnitState.ObjectID);
							if (FoundIndex == INDEX_NONE)
								continue;

							if (!SlotInfo.PerUnitAssignmentInfos[FoundIndex].bIsAllowed)
								continue;

							// Build a game state to move the unit to its new location
							DeployTile = SlotInfo.DeploySpawn.GetTile();
							NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breach: Set Unit");
							XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = class'XComTacticalInput'.static.BreachSetUnit_BuildVisualization;
							NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
							NewUnitState.bBreachAssigned = true;
							NewUnitState.bRequiresVisibilityUpdate = true;
							NewUnitState.SetVisibilityLocation(DeployTile);
							AttachedUnits.Length = 0;
							NewUnitState.GetAttachedUnits(AttachedUnits);
							foreach AttachedUnits(AttachedUnitState)
							{
								NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AttachedUnitState.ObjectID));
								NewUnitState.bRequiresVisibilityUpdate = true;
								NewUnitState.SetVisibilityLocation(DeployTile);
							}
							`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

							// Play a sound when assigning a unit to a breach point from the pool
							`XTACTICALSOUNDMGR.PreBreachUnitPlaced();

							// When placing a unit, reset the breach action to the first allowed template
							SlotInfo.DeploySpawn.ResetActionTemplateNameToUnitDefault(UnitState.ObjectID);

							class'XComBreachHelpers'.static.RefreshBreachPointAndSlotInfos();
							bAssignedUnit = true;
							break;
						}

						if (bAssignedUnit)
						{
							AssignedBreachGroupIDs.AddItem(PointInfo.BreachGroupID);
							break;
						}
					}

					++PlacementAttemptCount;
				}
				// If we assign the unit we'll need to grab the latest breach data
				BreachDataState = XComGameState_BreachData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BreachData'));
			}
		}

		LogRelativeTurnOrder();
	}

	function LogRelativeTurnOrder()
	{
		local array<StateObjectReference> UnitReferences;
		local int RefScan;
		local XComGameStateHistory History;
		local XComGameState_Unit OldUnitState;
		
		History = `XCOMHISTORY;
		
		class'XComBreachHelpers'.static.GetXComRelativeTurnOrder(UnitReferences);
		`log("XCom Turn Order (objIds):", , 'XCom_Breach');
		for (RefScan = 0; RefScan < UnitReferences.Length; ++RefScan)
		{
			OldUnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitReferences[RefScan].ObjectID, eReturnType_Reference));
			`log(RefScan $ ":" @ UnitReferences[RefScan].ObjectID @ "Nickname:" @ OldUnitState.SafeGetCharacterNickName() @ "CharTemplate:" @ OldUnitState.GetMyTemplateName(), , 'XCom_Breach');
		}
	}
	
	

	function RegisterForEvents()
	{
		local X2EventManager EventMgr;
		local Object ThisObj;

		ThisObj = self;
		EventMgr = `XEVENTMGR;
		EventMgr.RegisterForEvent(ThisObj, 'ActiveUnitChanged', OnActiveUnitChanged, ELD_Immediate);

		EventMgr.RegisterForEvent(ThisObj, 'UI_UnitDeployedToBreachPoint_OnVisBlockCompleted', OnUnitDeployedToBreachPoint_VisBlockCompleted, ELD_Immediate);
		EventMgr.RegisterForEvent(ThisObj, 'UI_UnitDeployedToBreachPoint_OnActionSelected', OnUnitDeployedToBreachPoint_ActionSelected, ELD_Immediate);
	}

	/// <summary>
	/// Overridden per state. Allows states to specify that unit visualizers should not be selectable (and human controlled) at the current time
	/// </summary>
	simulated function bool AllowVisualizerSelection()
	{
		return bWaitingForBreachConfirm;
	}

	function EventListenerReturn OnActiveUnitChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
	{
		//no longer need to update breach point data when active units are changed
		return ELR_NoInterrupt;
	}

	function EventListenerReturn OnUnitDeployedToBreachPoint_VisBlockCompleted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
	{
		class'XComBreachHelpers'.static.RefreshBreachPointAndSlotInfos();
		//LogRelativeTurnOrder();
		return ELR_NoInterrupt;
	}

	function EventListenerReturn OnUnitDeployedToBreachPoint_ActionSelected(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
	{
		class'XComBreachHelpers'.static.RefreshBreachPointAndSlotInfos();
		//LogRelativeTurnOrder();
		return ELR_NoInterrupt;
	}

	//This event is called from the matinee for breach initial move
	function OnBlendToTargetingCamera()
	{
		local BreachActionData BreachAction;
		local X2Camera_OTSTargeting OTSCamera;
		local XComGameState_Unit FiringUnitState;
		local X2AbilityTemplate AbilityTemplate;
		local XGUnit FiringUnitVisualizer;
		local Actor TargetVisualizer;
		local StateObjectReference OutTargetRef;
		local XComGameStateContext_Ability OutNextBreachActionAbilityContext;		
		local XComGameStateVisualizationMgr VisMgr;
		local X2Action_Move MoveAction;
		local X2Action_PlayAnimation AnimAction;

		//`Log("OnBlendToTargetingCamera", , 'XCom_Breach');

		BreachAction = BreachActions[CurrentBreachActionIndex];
		if (GetBreachAbilityTarget(BreachAction, OutTargetRef, OutNextBreachActionAbilityContext))
		{
			//`Log("OnBlendToTargetingCamera - GetBreachAbilityTarget passed", , 'XCom_Breach');
			//Can only have a targeting camera for manually targeted abilities - so skip if there is a context in the history already
			if (OutNextBreachActionAbilityContext == none)
			{
				AbilityTemplate = class'XComGameState_Ability'.static.GetMyTemplateManager().FindAbilityTemplate(BreachAction.AbilityName);
			}
			else
			{
				AbilityTemplate = class'XComGameState_Ability'.static.GetMyTemplateManager().FindAbilityTemplate(OutNextBreachActionAbilityContext.InputContext.AbilityTemplateName);
			}

			//Only set up an OTS camera for abilities that we anticipate will use an OTS camera
			if (AbilityTemplate.TargetingMethod == class'X2TargetingMethod_OverTheShoulder' || AbilityTemplate.TargetingMethod == class'X2TargetingMethod_OTSMeleePath')
			{
				//`Log("OnBlendToTargetingCamera - TargetingMethod passed", , 'XCom_Breach');
				//Get the visualizer for the firing unit
				FiringUnitVisualizer = XGUnit(CachedHistory.GetVisualizer(BreachAction.ObjectID));
					
				//Make sure that the shooter is in motion before doing anything. Prevents this blending logic from running until the appropriate breach
				//entry / initial move is going in the case where there is more than one breach point
				VisMgr = `XCOMVISUALIZATIONMGR;
				MoveAction = X2Action_Move(VisMgr.GetCurrentActionForVisualizer(FiringUnitVisualizer));
				AnimAction = X2Action_PlayAnimation(VisMgr.GetCurrentActionForVisualizer(FiringUnitVisualizer));

				if (FiringUnitVisualizer != none && FiringUnitVisualizer.TargetingCamera == none && (MoveAction != none || AnimAction != none)) //Prevent re-entrance since this can be triggered by data
				{
					`Log("OnBlendToTargetingCamera - MoveAction/AnimAction and FiringUnitVisualizer passed", , 'XCom_Breach');
					//Make a new targeting camera for the firing unit - it will use this when blending out from the matinee
					FiringUnitVisualizer.TargetingCamera = new class'X2Camera_OTSTargetingBreachMode';
					FiringUnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(BreachAction.ObjectID));

					OTSCamera = X2Camera_OTSTargeting(FiringUnitVisualizer.TargetingCamera);
					OTSCamera.FiringUnit = FiringUnitVisualizer;
					OTSCamera.CandidateMatineeCommentPrefix = FiringUnitState.GetMatineeCommentPrefix();
					OTSCamera.ShouldBlend = class'X2Camera_LookAt'.default.UseSwoopyCam;
					OTSCamera.ShouldHideUI = false;
					OTSCamera.Priority = eCameraPriority_CinematicBlend; //We will be blending from a cinematic, so need to be at least as high in priority
					OTSCamera.bDisableProximityDither = true;
					OTSCamera.BlendDuration = 1.0f; //Tuned based on the matinee swoop speed			
					OTSCamera.LookAtBackPenalty = 0;
					//OTSCamera.bDrawDebugInfo = true;
					//OTSCamera.PreselectedMatineeComment = BreachFireCameraPreference;// Force a selection if one is preferred "StartPos_R_2";

					//Retrieve the list of available targets for this ability
					if (OutTargetRef.ObjectID > 0)
					{
						// have the camera look at the target
						TargetVisualizer = CachedHistory.GetVisualizer(OutTargetRef.ObjectID);
						OTSCamera.SetTarget(TargetVisualizer);
					}

					`CAMERASTACK.AddCamera(FiringUnitVisualizer.TargetingCamera);

					bBlendingTargetingCamera = true;
					BlendingTargetCameraShooter = FiringUnitVisualizer;
					`XTACTICALSOUNDMGR.PlayBreachTransitionToTargeting();							
					class'XComTacticalGRI'.static.GetBreachActionSequencer().StartBreachFireSlomoBlock( true );
				}
			}			
		}
	}

	function RequestEncounterStartAutosave()
	{
		local AutosaveParameters AutosaveParams;
		local XComGameState_BattleData BattleData;

		//Prevent autosaving after loading an autosave
		if (bSkipAutosaveAfterLoad)
		{
			bSkipAutosaveAfterLoad = false; // clear the flag so that the next autosave goes through
		}
		else
		{
			BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
			if (BattleData.BreachingRoomListIndex == 0)
			{
				AutosaveParams.AutosaveType = 'TactSessionStart'; //If this is the first encounter, then the auto save type is TactSessionStart
			}
			else
			{
				AutosaveParams.AutosaveType = 'TactEncounterStart';
			}

			`AUTOSAVEMGR.DoAutosave(AutosaveParams);
		}
	}

Begin:
	//Submit game state changes activating breach mode
	SubmitGameStateContext(class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_BeginBreachMode));

	// Register for events only after the state has been submitted.
	// RoomID is set during the state submission. OnActiveUnitChanged depends on RoomID 
	RegisterForEvents();

	SetupBuildingVisForBreach();
	PrepareBreachUnitsFogAndCamera();

	// Lift the camera fade if there is one
	XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController()).ClientSetCameraFade(true, , , 1.0f);

	while (WaitingForVisualizer())
	{
		sleep(0.0);
	}

	// Fade must be off during gameplay, as it is tied to "cinematic" mode
	XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController()).ClientSetCameraFade(false, , , 0.0f);

	class'XComBreachHelpers'.static.RefreshBreachPointAndSlotInfos();

	//Auto-assign
	if (default.bAutoAssignToBreachStarts)
	{
		`log("*** AUTO-ASSIGN xcom to breach slots ***", , 'XCom_Breach');
		AutoAssignToBreachStarts();
	}

	//Set the input mode & show 2d + 3d ui elements.
	TacticalController.ActivateBreachUI();

	// Set audio before autosave so that autosave sees current music state
	`XTACTICALSOUNDMGR.BeginPreBreachAudio();

	//Create the encounter start autosave
	RequestEncounterStartAutosave();

	while (bWaitingForBreachCameraInit)
	{
		`SETLOC("Waiting for breach camera");
		sleep(0.0);
	}

	//Blends are turned off for the initial breach camera switch. Re-enable them now.
	RestoreCameraBlends();

	//Wait for the UI to confirm breach is starting
	while (bWaitingForBreachConfirm)
	{
		`SETLOC("Waiting for breach mode confirm");
		sleep(0.0);

		if (HasTacticalGameEnded())
		{
			GotoState('EndTacticalGame');
		}

		//Auto activate breach
		if (default.bAutoAssignToBreachStarts && default.bAutoActivateBreachSequence)
		{
			`log("*** AUTO-ACTIVATE breach ***", , 'XCom_Breach');
			BeginBreachSequence();
		}
	}

	SetupFOWStatus_Encounter();

	if (!bUseStagedBreachCamera)
	{
		SwitchBreachCameraMode();
	}
	DeactivateBreachCamera();

	`XEVENTMGR.TriggerEvent( 'BreachConfirmed' );

	ActivateKeepLastViewCamera();

	//Hide action icons while breach is visually occurring
	`PRES.GetActionIconMgr().ShowIcons(false);

	//Begin our breach action processing
	while (ContinueBreachSequence()) 
	{
		//ContinueBreachSequence says there is another breach action to perform. Flag us as waiting for new game states, and then run PerformBreachAction.		
		if (IsManuallyTargetedBreachAbility(BreachActions[CurrentBreachActionIndex]))
		{
			`log("*** Manual Target Breach Ability - ObjID:" $ BreachActions[CurrentBreachActionIndex].ObjectID @ BreachActions[CurrentBreachActionIndex].AbilityName @ "(" $ BreachActions[CurrentBreachActionIndex].ActionTemplateName $ ")", , 'XCom_Breach');
			while (class'XComTacticalGRI'.static.GetBreachActionSequencer().GetActionSequenceLength() > 0 )
			{
				`SETLOC("Waiting for GetBreachActionSequencer");
				sleep( 0.0f );
			}
			
			// Setup game state data so that the correct ability is the one manually targeted
			bWaitingForNewStates = ManuallyTargetBreachAbility(BreachActions[CurrentBreachActionIndex]);
			if (bWaitingForNewStates)
			{
				//`log("can be targeted, waiting on visualizers", , 'XCom_Breach');
				while (`XCOMVISUALIZATIONMGR.VisualizerBlockingAbilityActivation() || class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().bCinematicMode)
				{
					`SETLOC("Waiting for Visualizer");
					sleep(0.1);
				}

				while (class'XComTacticalGRI'.static.GetBreachActionSequencer().GetActionSequenceLength() > 0 )
				{
					`SETLOC("Waiting for GetBreachActionSequencer");
					sleep( 0.0f );
				}

				//This operates as a failsafe, as normally this transition should occur in OnBlendToTargetingCamera. However, if there is no targeting camera to blend to
				//(ie. no valid targets for the "first" breach group) then this is what kicks off the breach action sequencer's slomo block.
				if (CurrentBreachActionIndex > 0 &&
					BreachActions[CurrentBreachActionIndex].ActionPriority == BreachActions[CurrentBreachActionIndex - 1].ActionPriority &&
					!class'XComTacticalGRI'.static.GetBreachActionSequencer().bInXComBreachFireSequence)
				{
					class'XComTacticalGRI'.static.GetBreachActionSequencer().StartBreachFireSlomoBlock(true);					
				}

				//Lower the slomorate back down for targeting
				class'XComTacticalGRI'.static.GetBreachActionSequencer().PermanentAdjustRateDuringBreachFireSlomoBlock(class'XComTacticalGRI'.static.GetBreachActionSequencer().BreachMoveFireTargetSloMoRate, 0.5f);

				// Make sure the HUD is visible. Somewhat fragile, this should be made cleaner following the first playable
				`PRES.ShowUIForCinematics();

				// bring up an action targeting UI that will submit new states.
				`log("Selecting Unit", , 'XCom_BreachActionSequencer');
				SelectUnitForManualTargeting(BreachActions[CurrentBreachActionIndex]);
				sleep(0.1f);
				`log("Opening HUD", , 'XCom_BreachActionSequencer');
				OpenHUDForManualTargeting(BreachActions[CurrentBreachActionIndex]);
				`log("Waiting for UI Confirmation", , 'XCom_BreachActionSequencer');

				`XTACTICALSOUNDMGR.OnWaitForBreachAction();

				if( class'XComTacticalGRI'.static.GetBreachActionSequencer().ShouldApplyBreachFireSlomoEffect() )
				{
					`PRES.SetSloMoEnabled(true);
				}
				`XTACTICALSOUNDMGR.PlayBreachSlomoOn();

				if (default.bAutoFireDuringBreach && `PRES.m_kTacticalHUD.m_kAbilityHUD != None)
				{
					`log("Auto Fire during Breach, simulating input", , 'XCom_Breach');
					Sleep(0.3f);
					//simulate input
					`PRES.m_kTacticalHUD.m_kAbilityHUD.DirectConfirmAbility(0);
				}
								
				//Waits for the UI to submit, since the UI activates an ability this causes us to build game state latently
				while (bWaitingForNewStates || BuildingLatentGameState)
				{
					Sleep(0.0f);
				}

				// Clear the manual-targeting
				`log("Confirmation received, closing HUD", , 'XCom_BreachActionSequencer');
				CloseHUDForManualTargeting(BreachActions[CurrentBreachActionIndex]);
				ClearManualTargetBreachAbility(BreachActions[CurrentBreachActionIndex]);

				//Sleep for a frame to give the visualizer a chance to activate for the ability that was just started. Only necessary when running release scripts, as debug scripts
				//must run single-threaded and therefore alter the visualizationmgr's behavior somewhat.
				Sleep(0.0f);
			}
			else
			{
				bBlendingTargetingCamera = false; //normally set in OpenHUDForManualTargeting, fallback here
				`log("cannot be targeted, unable to manually target breach ability", , 'XCom_Breach');
			}
		}
		else
		{
			bBlendingTargetingCamera = false; //normally set in OpenHUDForManualTargeting, fallback here
			//Submits game states
			PerformBreachAbility(BreachActions[CurrentBreachActionIndex], TacticalController.m_kPathingPawn, PathInput, BreachSequenceCheckpointHistoryIndex);
			CullPostAbilityMovementForBreachHellionRushAbility();
		}

		// Restore global time to 1.0f after the user confirms, and keep it at 1.0 until we are back in targeting
		class'XComTacticalGRI'.static.GetBreachActionSequencer().PermanentAdjustRateDuringBreachFireSlomoBlock(1.0f, 0.33f);

		`XTACTICALSOUNDMGR.PlayBreachSlomoOff();

		//Once the priority eclipses a certain point, switch to the game camera phase to finish
		if (ShouldSwitchToGameCameraForRestOfSequence())
		{
			//Sleep for a frame to give the visualizer a chance to activate for the ability that was just started. Only necessary when running release scripts, as debug scripts
			//must run single-threaded and therefore alter the visualizationmgr's behavior somewhat.
			Sleep(0.0f);

			while (WaitingForVisualizer() && `XCOMVISUALIZATIONMGR.VisualizerBlockingAbilityActivation())
			{
				`SETLOC("Waiting for Visualizer");
				sleep(0.0);
			}
			while (class'XComTacticalGRI'.static.GetBreachActionSequencer().GetActionSequenceLength() > 0 )
			{
				`SETLOC("Waiting for GetBreachActionSequencer");
				sleep( 0.0f );
			}

			if (class'XComTacticalGRI'.static.GetBreachActionSequencer().ShouldApplyBreachFireSlomoEffect() )
			{
				`PRES.SetSloMoEnabled(false);
			}

			// Switch to game camera, deactivate the keep last view camera
			AdvanceBreachSubPhaseToGameCamera();

			`XTACTICALSOUNDMGR.EnsureCombatAudioBegun();
		}
	}

	//Wait for the visualization of the breach to complete before entering the core turn loop
	while (WaitingForVisualizer() && `XCOMVISUALIZATIONMGR.VisualizerBlockingAbilityActivation())
	{
		`SETLOC("Waiting for Visualizer");
		sleep(0.0);
	}
	while (class'XComTacticalGRI'.static.GetBreachActionSequencer().GetActionSequenceLength() > 0 )
	{
		`SETLOC("Waiting for GetBreachActionSequencer");
		sleep( 0.0f );
	}

	//Release the keep last view camera and advance the breach phase, if it didn't occur above.
	AdvanceBreachSubPhaseToGameCamera();

	`XTACTICALSOUNDMGR.EnsureCombatAudioBegun();
		
	// Enemies should breach 'scamper', if the breach sequence above granted them action points, their AI will spend them
	RunPostBreachEnemyBehaviors();

	// Sleep long enough for behaviors to have started submitting game state
	sleep(2.5);

	//Wait for the visualization of the breach to complete before entering the core turn loop
	while (WaitingForVisualizer())
	{
		`SETLOC("Waiting for Visualizer");
		sleep(0.0);
	}

	//Submit game state changes ending breach mode
	SubmitGameStateContext(class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_EndBreachMode));
	`BATTLE.RefreshDesc();

	`log("**** END BREACH SEQUENCE ****", , 'XCom_Breach');

	//Make sure all camera shakes have shaken out when we exit breach mode
	GetALocalPlayerController().PlayerCamera.ClearAllCameraShakes();

	//Allow action icons again
	`PRES.GetActionIconMgr().ShowIcons(true);

	bBlockProjectileCreation = false;

	//Move on into the normal game loop ( begin turn -> unit actions -> end turn )
	`SETLOC("End of Begin Block");
	GotoState(GetNextTurnPhase(GetStateName()));
}

function EventListenerReturn OnChallengeObjectiveFailed( Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData )
{
	FailBattle();
	return ELR_InterruptEventAndListeners;
}

simulated state TurnPhase_WaitForKismetBreach
{
Begin:

	if (bAllowKismetBreachControl)
	{
		while (!HasNextBreachRoomSet())
		{
			sleep(0.0f);
		}
	}

	GotoState(GetNextTurnPhase(GetStateName()));
}

/// <summary>
/// This turn phase is entered at the start of each turn and handles any start-of-turn scenario events. Unit/Terrain specific effects occur in subsequent phases.
/// </summary>
simulated state TurnPhase_Begin
{
	simulated event BeginState(name PreviousStateName)
	{
		`SETLOC("BeginState");

		BeginState_RulesAuthority(UpdateAbilityCooldowns);
	}

	simulated function UpdateAbilityCooldowns(XComGameState NewPhaseState)
	{
		local XComGameState_Ability AbilityState, NewAbilityState;
		local XComGameState_Player  PlayerState, NewPlayerState;
		local XComGameState_Unit UnitState, NewUnitState;
		local bool TickCooldown;
		local XComGameState_BattleData BattleData;

		if (!bLoadingSavedGame)
		{
			BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
			BattleData = XComGameState_BattleData(NewPhaseState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
			BattleData.TacticalTurnCount++;

			foreach CachedHistory.IterateByClassType(class'XComGameState_Ability', AbilityState)
			{
				// some units tick their cooldowns per action instead of per turn, skip them.
				UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
				`assert(UnitState != none);
				TickCooldown = AbilityState.iCooldown > 0 && !UnitState.GetMyTemplate().bManualCooldownTick;

				if( TickCooldown || AbilityState.TurnsUntilAbilityExpires > 0 )
				{
					NewAbilityState = XComGameState_Ability(NewPhaseState.ModifyStateObject(class'XComGameState_Ability', AbilityState.ObjectID));//Create a new state object on NewPhaseState for AbilityState

					if( TickCooldown )
					{
						NewAbilityState.iCooldown--;
						NewAbilityState.HasTickedSinceCooldownStarted = true;
					}

					if( NewAbilityState.TurnsUntilAbilityExpires > 0 )
					{
						NewAbilityState.TurnsUntilAbilityExpires--;
						if( NewAbilityState.TurnsUntilAbilityExpires == 0 )
						{
							NewUnitState = XComGameState_Unit(NewPhaseState.ModifyStateObject(class'XComGameState_Unit', NewAbilityState.OwnerStateObject.ObjectID));
							NewUnitState.Abilities.RemoveItem(NewAbilityState.GetReference());
						}
					}
				}
			}

			foreach CachedHistory.IterateByClassType(class'XComGameState_Player', PlayerState)
			{
				if (PlayerState.HasCooldownAbilities() || PlayerState.SquadCohesion > 0)
				{
					NewPlayerState = XComGameState_Player(NewPhaseState.ModifyStateObject(class'XComGameState_Player', PlayerState.ObjectID));
					NewPlayerState.UpdateCooldownAbilities();
					if (PlayerState.SquadCohesion > 0)
						NewPlayerState.TurnsSinceCohesion++;
				}
			}
		}
	}

Begin:
	`SETLOC("Start of Begin Block");

	CachedHistory.CheckNoPendingGameStates();

	`SETLOC("End of Begin Block");
	GotoState(GetNextTurnPhase(GetStateName()));
}

function UpdateAIActivity(bool bActive)
{
	bAlienActivity = bActive;
}

simulated function bool UnitActionPlayerIsRemote()
{
	local XComGameState_Player PlayerState;
	local XGPlayer Player;

	PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(GetCachedUnitActionPlayerRef().ObjectID));
	if( PlayerState != none )
	{
		Player = XGPlayer(PlayerState.GetVisualizer());
	}

	`assert(PlayerState != none);
	`assert(Player != none);

	return (PlayerState != none) && (Player != none) && Player.IsRemote();
}

function bool RulesetShouldAutosave()
{
	local XComGameState_Player PlayerState;
	local XComGameState_BattleData BattleData;

	PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(GetCachedUnitActionPlayerRef().ObjectID));
	BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	if (BattleData.m_strDesc == "BenchmarkTest")
		return false;

	if (class'X2TacticalGameRulesetDataStructures'.static.TacticalOnlyGameMode( ))
		return false;

	return !bSkipAutosaveAfterLoad && !HasTacticalGameEnded() && !HasRoomEncounterEnded() &&!PlayerState.IsAIPlayer() && !`REPLAY.bInReplay && `TUTORIAL == none && !BattleData.IsInBreachSelection();
}

simulated function InterruptInitiativeTurn(XComGameState NewGameState, StateObjectReference InterruptingAIGroupRef)
{
	local XComGameState_BattleData NewBattleData;
	local XComGameState_AIGroup InterruptedAIGroup, InterruptingAIGroup;

	NewBattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', CachedBattleDataRef.ObjectID));
	NewBattleData.InterruptingGroupRef = InterruptingAIGroupRef;
	NewBattleData.InterruptedUnitRef = TacticalController.GetActiveUnitStateRef();

	InterruptedAIGroup = XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(CachedUnitActionInitiativeRef.ObjectID));
	if( InterruptedAIGroup != None )
	{
		InterruptedAIGroup = XComGameState_AIGroup(NewGameState.ModifyStateObject(class'XComGameState_AIGroup', CachedUnitActionInitiativeRef.ObjectID));
		InterruptedAIGroup.bInitiativeInterrupted = true;
	}

	InterruptingAIGroup = XComGameState_AIGroup(NewGameState.ModifyStateObject(class'XComGameState_AIGroup', InterruptingAIGroupRef.ObjectID));
	RemoveGroupFromInitiativeOrder(InterruptingAIGroup, NewGameState);
}

simulated function bool UnitHasActionsAvailable(XComGameState_Unit UnitState)
{
	local GameRulesCache_Unit UnitCache;
	local AvailableAction Action;

	if( UnitState == none )
		return false;

	if (UnitState.bPanicked) //Panicked units are not allowed to be selected
		return false;

	//Dead, unconscious, and bleeding-out units should not be selectable.
	if( UnitState.IsDead() ||
		UnitState.IsIncapacitatedCapturedOrDowned() ||
		!UnitState.HasAssignedRoomBeenBreached() ||
		UnitState.GetCharacterTemplate().bExcludeFromTimeline )
	{
		return false;
	}

	if( !UnitState.GetMyTemplate().bIsCosmetic &&
	   !UnitState.IsPanicked() &&
	   (UnitState.AffectedByEffectNames.Find(class'X2Ability_Viper'.default.BindSustainedEffectName) == INDEX_NONE) )
	{
		GetGameRulesCache_Unit(UnitState.GetReference(), UnitCache);
		foreach UnitCache.AvailableActions(Action)
		{
			if( Action.bInputTriggered && Action.AvailableCode == 'AA_Success' )
			{
				return true;
			}
		}
	}

	return false;
}

/// <summary>
/// This turn phase forms the bulk of the X-Com 2 turn and represents the phase of the battle where players are allowed to 
/// select what actions they will perform with their units
/// </summary>
simulated state TurnPhase_UnitActions
{
	simulated event BeginState(name PreviousStateName)
	{
		local XComGameState_BattleData BattleData;
		local XComGameState_AIGroup OtherGroup;
		local int Index;

		`SETLOC("BeginState");

		if( !bLoadingSavedGame )
		{
			BeginState_RulesAuthority(SetupUnitActionsState);
		}

		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
		`assert(BattleData.PlayerTurnOrder.Length > 0);

		ResetInitiativeOrder();

		`XTACTICALSOUNDMGR.EnsureCombatMusic();

		if( bLoadingSavedGame )
		{
			//Skip to the current player			
			CachedUnitActionInitiativeRef = BattleData.UnitActionInitiativeRef;
			CachedUnitActionPlayerRef = BattleData.UnitActionPlayerRef;

			UnitActionInitiativeIndex = BattleData.PlayerTurnOrder.Find( 'ObjectID', CachedUnitActionInitiativeRef.ObjectID );

			// if the currently active group is not in the initiative order, we have to find the group that is being interrupted to mark the current index
			if( UnitActionInitiativeIndex == INDEX_NONE && BattleData.InterruptingGroupRef.ObjectID == CachedUnitActionInitiativeRef.ObjectID )
			{
				for( Index = 0; Index < BattleData.PlayerTurnOrder.Length; ++Index )
				{
					OtherGroup = XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(BattleData.PlayerTurnOrder[Index].ObjectID));
					if( OtherGroup != None && OtherGroup.bInitiativeInterrupted )
					{
						UnitActionInitiativeIndex = Index;
						break;
					}
				}

				bInitiativeInterruptingInitialGroup = true;
			}

			RefreshInitiativeReferences();

			BeginInitiativeTurn( false, false );

			class'Engine'.static.GetEngine().ReinitializeValueOnLoadComplete();

			//Clear the loading flag - it is only relevant during the 'next player' determination
			bSkipAutosaveAfterLoad = (CachedUnitActionInitiativeRef == CachedUnitActionPlayerRef);
			bLoadingSavedGame = false;
		}
		else
		{
			NextInitiativeGroup();
		}

		bSkipRemainingTurnActivty = false;
	}

	simulated function ResetInitiativeOrder()
	{
		UnitActionInitiativeIndex = -1;
	}

	simulated function SetupUnitActionsState(XComGameState NewPhaseState)
	{
		//  This code has been moved to the player turn observer, as units need to reset their actions
		//  only when their player turn changes, not when the over all game turn changes over.
		//  Leaving this function hook for future implementation needs. -jbouscher
	}

	simulated function ResetHitCountersOnPlayerTurnBegin()
	{
		local XComGameState_Player NewPlayerState;
		local XComGameState NewGameState;
		local XComGameState_AIGroup GroupState;

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("ResetHitCountersOnPlayerTurnBegin");

		// clear the streak counters on this player
		NewPlayerState = XComGameState_Player(NewGameState.ModifyStateObject(class'XComGameState_Player', GetCachedUnitActionPlayerRef().ObjectID));
		NewPlayerState.MissStreak = 0;
		NewPlayerState.HitStreak = 0;

		// clear summoning sickness on any groups of this player's team
		foreach CachedHistory.IterateByClassType(class'XComGameState_AIGroup', GroupState)
		{
			if( GroupState.TeamName == NewPlayerState.TeamFlag )
			{
				GroupState = XComGameState_AIGroup(NewGameState.ModifyStateObject(class'XComGameState_AIGroup', GroupState.ObjectID));
				GroupState.bSummoningSicknessCleared = true;
			}
		}

		SubmitGameState(NewGameState);
	}

	simulated function SetupUnitActionsForGroupTurnBegin(bool bReturningFromInterruptedTurn)
	{
		local XComGameState_AIGroup GroupState;
		local StateObjectReference UnitRef;
		local XComGameState_Unit NewUnitState;
		local XComGameStateContext_TacticalGameRule Context;
		local XComGameState NewGameState;
		local XComGameState_BattleData BattleData;
		local X2EventManager EventManager;

		EventManager = `XEVENTMGR;

		// build a gamestate to mark this end of this players turn
		Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_UnitGroupTurnBegin);
		Context.PlayerRef = InterruptingUnitActionPlayerRef.ObjectID >= 0 ? InterruptingUnitActionPlayerRef : CachedUnitActionPlayerRef;
		NewGameState = Context.ContextBuildGameState();

		GroupState = XComGameState_AIGroup(NewGameState.ModifyStateObject(class'XComGameState_AIGroup', CachedUnitActionInitiativeRef.ObjectID));
		GroupState.bInitiativeInterrupted = false;

		BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', CachedBattleDataRef.ObjectID));
		BattleData.UnitActionInitiativeRef = GroupState.GetReference();

		if( !bReturningFromInterruptedTurn )
		{
			foreach GroupState.m_arrMembers(UnitRef)
			{
				// Create a new state object on NewPhaseState for UnitState
				NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
				NewUnitState.SetupActionsForBeginTurn();
				EventManager.TriggerEvent('UnitTurnBegun', NewUnitState, NewUnitState, NewGameState);
			}

			// Trigger the UnitGroupTurnBegun event
			EventManager.TriggerEvent('UnitGroupTurnBegun', GroupState, GroupState, NewGameState);
		}

		SubmitGameState(NewGameState);
	}

	simulated function bool NextInitiativeGroup()
	{
		local XComGameState NewGameState;
		local XComGameState_BattleData NewBattleData;
		local bool bResumeFromInterruptedInitiative, bBeginInterruptedInitiative;
		local StateObjectReference PreviousPlayerRef, PreviousUnitActionRef;
		local bool bForceNewTurn;

		NewBattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

		PreviousPlayerRef = GetCachedUnitActionPlayerRef();
		PreviousUnitActionRef = CachedUnitActionInitiativeRef;

		bResumeFromInterruptedInitiative = false;
		bBeginInterruptedInitiative = false;

		// select the interrupting group if there is one
		if( NewBattleData.InterruptingGroupRef.ObjectID > 0 )
		{
			// if the interrupting group is already the active group, we are resuming from interruption; else we are starting the interruption
			if( CachedUnitActionInitiativeRef.ObjectID == NewBattleData.InterruptingGroupRef.ObjectID )
			{
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("RemoveInterruptingInitiativeGroup");
				NewBattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', CachedBattleDataRef.ObjectID));
				NewBattleData.InterruptingGroupRef.ObjectID = -1;
				SubmitGameState(NewGameState);

				bResumeFromInterruptedInitiative = true;

				UnitActionUnitRef = NewBattleData.InterruptedUnitRef;
				NewBattleData.InterruptedUnitRef.ObjectID = -1;
			}
			else
			{
				bBeginInterruptedInitiative = true;
			}
		}

		// advance initiative, unless we are starting an interruption or resuming an initiative that was previously interrupted
		if( !bResumeFromInterruptedInitiative && !bBeginInterruptedInitiative )
		{
			++UnitActionInitiativeIndex;
		}
		bForceNewTurn = ( UnitActionInitiativeIndex < 0 || UnitActionInitiativeIndex >= NewBattleData.PlayerTurnOrder.Length );

		RefreshInitiativeReferences();

		EndInitiativeTurn(PreviousPlayerRef, PreviousUnitActionRef, bBeginInterruptedInitiative, bResumeFromInterruptedInitiative);

		if( bForceNewTurn || HasTacticalGameEnded() || HasRoomEncounterEnded() || (bAllowKismetBreachControl && HasNextBreachRoomSet()))
		{
			// if the tactical game has already completed, then we need to bail before
			// initializing the next player, as we do not want any more actions to be taken.
			return false;
		}

		return ( BeginInitiativeTurn( bBeginInterruptedInitiative, bResumeFromInterruptedInitiative ));
	}

	simulated function RefreshInitiativeReferences()
	{
		local XComGameState_Player PlayerState;
		local XComGameState_BattleData BattleData;
		local XComGameState_AIGroup AIGroupState;
		local XComGameState_Unit GroupLeadUnitState;

		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
		`assert(BattleData.PlayerTurnOrder.Length > 0);

		InterruptingUnitActionPlayerRef.ObjectID = -1;
		if( UnitActionInitiativeIndex < 0 || UnitActionInitiativeIndex >= BattleData.PlayerTurnOrder.Length )
		{
			UnitActionInitiativeIndex = 0;
		}
		if( BattleData.InterruptingGroupRef.ObjectID > 0 )
		{
			CachedUnitActionInitiativeRef = BattleData.InterruptingGroupRef;

			AIGroupState = XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(CachedUnitActionInitiativeRef.ObjectID));
			GroupLeadUnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(AIGroupState.m_arrMembers[0].ObjectID));
			InterruptingUnitActionPlayerRef = GroupLeadUnitState.ControllingPlayer;
		}
		else if( UnitActionInitiativeIndex >= 0 && UnitActionInitiativeIndex < BattleData.PlayerTurnOrder.Length )
		{
			CachedUnitActionInitiativeRef = BattleData.PlayerTurnOrder[UnitActionInitiativeIndex];
			PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(CachedUnitActionInitiativeRef.ObjectID));
			if( PlayerState != None )
			{
				CachedUnitActionPlayerRef = CachedUnitActionInitiativeRef;
			}
		}
		else
		{
			CachedUnitActionInitiativeRef.ObjectID = -1;
			CachedUnitActionPlayerRef.ObjectID = -1;
		}
	}

	simulated function bool BeginInitiativeTurn(bool bBeginInterruptedInitiative, bool bResumeFromInterruptedInitiative)
	{
		local XComGameStateContext_TacticalGameRule Context;
		local XComGameState NewGameState;
		local XComGameState_Player PlayerState;
		local X2EventManager EventManager;
		local XGPlayer PlayerStateVisualizer;
		local XComGameState_ChallengeData ChallengeData;
		local XComGameState_TimerData TimerState;
		local XComGameState_AIGroup AIGroupState;
		local bool bReturningFromInterruptedTurn;
		local XComGameState_BattleData BattleData;

		if( CachedUnitActionInitiativeRef.ObjectID >= 0 )
		{
			//Don't process turn begin/end events if we are loading from a save
			if( !bLoadingSavedGame )
			{
				if( CachedUnitActionPlayerRef.ObjectID == CachedUnitActionInitiativeRef.ObjectID )
				{
					ResetHitCountersOnPlayerTurnBegin();

					PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(CachedUnitActionPlayerRef.ObjectID));
					`assert( PlayerState != None );
					PlayerStateVisualizer = XGPlayer(PlayerState.GetVisualizer());

					PlayerStateVisualizer.OnUnitActionPhaseBegun_NextPlayer();  // This initializes the AI turn 

					if( !bResumeFromInterruptedInitiative && !bBeginInterruptedInitiative )
					{
						EventManager = `XEVENTMGR;
						if( UnitActionInitiativeIndex == 0 )
						{
							// build a gamestate to mark the beginning of the round
							Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_RoundBegin);
							Context.PlayerRef = CachedUnitActionPlayerRef;
							NewGameState = Context.ContextBuildGameState();
							SubmitGameState(NewGameState);
							EventManager.TriggerEvent('RoundBegun');
						}
						// Trigger the PlayerTurnBegun event

							// build a gamestate to mark this beginning of this players turn
							Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnBegin);
						Context.PlayerRef = CachedUnitActionPlayerRef;

						BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
						if( UnitActionInitiativeIndex >= BattleData.PlayerTurnOrder.Length ||
						   XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(BattleData.PlayerTurnOrder[UnitActionInitiativeIndex + 1].ObjectID)) == None )
						{
							Context.bSkipVisualization = true;
						}

						NewGameState = Context.ContextBuildGameState();

						EventManager.TriggerEvent('PlayerTurnBegun', PlayerState, PlayerState, NewGameState);

						SubmitGameState(NewGameState);
					}

					ChallengeData = XComGameState_ChallengeData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_ChallengeData', true));
					if( (ChallengeData != none) && !UnitActionPlayerIsAI() )
					{
						TimerState = XComGameState_TimerData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_TimerData'));
						TimerState.bStopTime = false;
					}
				}
				else
				{
					AIGroupState = XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(CachedUnitActionInitiativeRef.ObjectID));
					`assert( AIGroupState != None );

					bReturningFromInterruptedTurn =
						( bResumeFromInterruptedInitiative && AIGroupState.bInitiativeInterrupted );

					// before the start of each player's turn, submit a game state resetting that player's units' per-turn values (like action points remaining)
					SetupUnitActionsForGroupTurnBegin(bReturningFromInterruptedTurn);

					if( !bReturningFromInterruptedTurn || bInitiativeInterruptingInitialGroup )
					{
						PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(GetCachedUnitActionPlayerRef().ObjectID));
						`assert( PlayerState != None );
						PlayerStateVisualizer = XGPlayer(PlayerState.GetVisualizer());

						PlayerStateVisualizer.OnUnitActionPhase_NextGroup(CachedUnitActionInitiativeRef);

						bInitiativeInterruptingInitialGroup = false;
					}
				}
			}

			//Uncomment if there are persistent lines you want to refresh each turn
			//WorldInfo.FlushPersistentDebugLines();

			return true;
		}
		return false;
	}

	simulated function EndInitiativeTurn(StateObjectReference PreviousPlayerRef, StateObjectReference PreviousUnitActionRef, bool bBeginInterruptedInitiative, bool bResumeFromInterruptedInitiative)
	{
		local XComGameStateContext_TacticalGameRule Context;
		local XComGameState_Player PlayerState;
		local X2EventManager EventManager;
		local XComGameState_ChallengeData ChallengeData;
		local XComGameState_TimerData TimerState;
		local XComGameState_AIGroup GroupState;
		local XComGameState NewGameState;
		local XComGameState_Unit UnitState;
		local array<XComGameState_Unit> LivingMemberStates;
		local array<int> LivingMemberIds;

		EventManager = `XEVENTMGR;

		if( PreviousPlayerRef.ObjectID > 0 )
		{
			if( CachedUnitActionPlayerRef.ObjectID != PreviousPlayerRef.ObjectID )
			{
				//Notify the player state's visualizer that they are no longer the unit action player
				PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(PreviousPlayerRef.ObjectID));
				`assert( PlayerState != None );
				XGPlayer(PlayerState.GetVisualizer()).OnUnitActionPhaseFinished_NextPlayer();

				//Don't process turn begin/end events if we are loading from a save
				if( !bLoadingSavedGame && !bResumeFromInterruptedInitiative && !bBeginInterruptedInitiative )
				{
					// build a gamestate to mark this end of this players turn
					Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnEnd);
					Context.PlayerRef = PreviousPlayerRef;

					NewGameState = Context.ContextBuildGameState();
					EventManager.TriggerEvent('PlayerTurnEnded', PlayerState, PlayerState, NewGameState);

					SubmitGameState(NewGameState);
				}

				ChallengeData = XComGameState_ChallengeData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_ChallengeData', true));
				if( (ChallengeData != none) && !UnitActionPlayerIsAI() )
				{
					TimerState = XComGameState_TimerData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_TimerData'));
					TimerState.bStopTime = true;
				}
			}

			//If we switched away from a unit initiative group, trigger an event
			//Don't process turn begin/end events if we are loading from a save
			if( (PreviousUnitActionRef.ObjectID != PreviousPlayerRef.ObjectID) && !bLoadingSavedGame && !bBeginInterruptedInitiative )
			{
				GroupState = XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(PreviousUnitActionRef.ObjectID));

				// build a gamestate to mark this end of this players turn
				Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_UnitGroupTurnEnd);
				Context.PlayerRef = PreviousPlayerRef;
				Context.UnitRef = PreviousUnitActionRef;
				NewGameState = Context.ContextBuildGameState( );

				EventManager.TriggerEvent('UnitGroupTurnEnded', GroupState, GroupState, NewGameState);
				
				GroupState.GetLivingMembers(LivingMemberIds, LivingMemberStates);
				foreach LivingMemberStates(UnitState)
				{
					EventManager.TriggerEvent('UnitTurnEnded', UnitState, UnitState, NewGameState);
				}

				SubmitGameState(NewGameState);
			}
		}
	}

	simulated function bool ActionsAvailable()
	{
		local XComGameState_Unit UnitState;
		local XComGameState_Player PlayerState;
		local bool bActionsAvailable;
		local XComGameState_AIGroup GroupState;
		local StateObjectReference UnitRef;
		local XComGameState_BattleData BattleData;
		local int NumGroupMembers, MemberIndex, CurrentUnitIndex;

		// no units act when a player has initiative; they only act when their group has initiative
		if( CachedUnitActionInitiativeRef.ObjectID == CachedUnitActionPlayerRef.ObjectID )
		{
			return false;
		}

		// if there is an interrupting group specified and that is not the currently active group, this group needs interruption
		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
		if( BattleData.InterruptingGroupRef.ObjectID > 0 && CachedUnitActionInitiativeRef.ObjectID != BattleData.InterruptingGroupRef.ObjectID )
		{
			return false;
		}

		// Turn was skipped, no more actions
		if (bSkipRemainingTurnActivty)
		{
			return false;
		}

		bActionsAvailable = false;

		GroupState = XComGameState_AIGroup(CachedHistory.GetGameStateForObjectID(CachedUnitActionInitiativeRef.ObjectID));

		// handle interrupting unit
		if (UnitActionUnitRef.ObjectID > 0)
		{
			UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitActionUnitRef.ObjectID));
			if ((UnitState.GetGroupMembership().ObjectID == GroupState.ObjectID) && UnitHasActionsAvailable(UnitState))
			{
				bActionsAvailable = true;
				UnitActionUnitRef.ObjectID = -1;
			}
		}

		// handle restoring the previous unit if possible
		UnitRef = TacticalController.GetActiveUnitStateRef();
		if( UnitRef.ObjectID > 0 
			&& !bSkipRemainingUnitActivity) // this unit was skipped and no longer has any action points, 
			//but free action abilities will prevent us from switching to the next dude
		{
			UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitRef.ObjectID));
			if( (UnitState.ControllingPlayer.ObjectID == CachedUnitActionPlayerRef.ObjectID) && UnitHasActionsAvailable(UnitState) )
			{
				bActionsAvailable = true;
			}
		}
		bSkipRemainingUnitActivity = false;

		// select the *next* available group member that has any actions
		if( !bActionsAvailable )
		{
			NumGroupMembers = GroupState.m_arrMembers.Length;

			CurrentUnitIndex = Clamp(GroupState.m_arrMembers.Find('ObjectID', UnitRef.ObjectID), 0, NumGroupMembers - 1);

			for( MemberIndex = 1; !bActionsAvailable && MemberIndex < NumGroupMembers; ++MemberIndex )
			{
				UnitRef = GroupState.m_arrMembers[(CurrentUnitIndex + MemberIndex) % NumGroupMembers];
			
				UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitRef.ObjectID));

				bActionsAvailable = UnitHasActionsAvailable(UnitState);
				if (bActionsAvailable)
				{
					break;
				}
			}
		}

		//dakota.lemaster: With interleaved turns, we need to see if any same-team units have actions
		if (!bActionsAvailable && bInterleaveInitiativeTurns)
		{
			foreach CachedHistory.IterateByClassType(class'XComGameState_Unit', UnitState)
			{
				if (UnitState != None 
					&& CachedUnitActionPlayerRef.ObjectID > 0 
					&& UnitState.ControllingPlayer.ObjectID == CachedUnitActionPlayerRef.ObjectID)
				{
					bActionsAvailable = UnitState.NumAllActionPoints() > 0 && UnitHasActionsAvailable(UnitState);
					if (bActionsAvailable)
					{
						break;
					}
				}
			}
		}

		if( bActionsAvailable )
		{
			bWaitingForNewStates = true;	//If there are actions available, indicate that we are waiting for a decision on which one to take

			if( !UnitActionPlayerIsRemote() )
			{				
				PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID));
				`assert(PlayerState != none);
				XGPlayer(PlayerState.GetVisualizer()).OnUnitActionPhase_ActionsAvailable(UnitState);
			}
		}

		return bActionsAvailable;
	}

	simulated function EndPhase()
	{
		local X2AIBTBehaviorTree BehaviorTree;

		BehaviorTree = `BEHAVIORTREEMGR;

		//Safety measure, make sure all AI BT queues are clear. This should have been taken care of during the 
		//AI turn. If this becomes a problem, a redscreen here might be appropriate.
		BehaviorTree.ClearQueue();

		if (HasTacticalGameEnded())
		{
			GotoState( 'EndTacticalGame' );
		}
		else if (!bAllowKismetBreachControl && HasRoomEncounterEnded() && !IsFinalRoomEncounter()) //DIO - see if we should enter the breach phase.
		{
			GotoState('TurnPhase_Breach');
		}
		else if (bAllowKismetBreachControl && HasNextBreachRoomSet())
		{
			GotoState('TurnPhase_Breach');
		}
		else
		{
			GotoState( GetNextTurnPhase( GetStateName() ) );
		}
	}

	simulated function string GetStateDebugString()
	{
		local string DebugString;
		local XComGameState_Player PlayerState;
		local int UnitCacheIndex;
		local int ActionIndex;
		local XComGameState_Unit UnitState;				
		local XComGameState_Ability AbilityState;
		local AvailableAction AvailableActionData;
		local string EnumString;

		PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(CachedUnitActionPlayerRef.ObjectID));

		DebugString = "Unit Action Player  :"@((PlayerState != none) ? string(PlayerState.GetVisualizer()) : "PlayerState_None")@" ("@CachedUnitActionPlayerRef.ObjectID@") ("@ (UnitActionPlayerIsRemote() ? "REMOTE" : "") @")\n";
		DebugString = DebugString$"Begin Block Location: " @ BeginBlockWaitingLocation @ "\n\n";
		DebugString = DebugString$"Internal State:"@ (bWaitingForNewStates ? "Waiting For Player Decision" : "Waiting for Visualizer") @ "\n\n";
		DebugString = DebugString$"Unit Cache Info For Unit Action Player:\n";

		for( UnitCacheIndex = 0; UnitCacheIndex < UnitsCache.Length; ++UnitCacheIndex )
		{
			UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitsCache[UnitCacheIndex].UnitObjectRef.ObjectID));

			//Check whether this unit is controlled by the UnitActionPlayer
			if( UnitState.ControllingPlayer.ObjectID == GetCachedUnitActionPlayerRef().ObjectID )
			{			
				DebugString = DebugString$"Unit: "@((UnitState != none) ? string(UnitState.GetVisualizer()) : "UnitState_None")@"("@UnitState.ObjectID@") [HI:"@UnitsCache[UnitCacheIndex].LastUpdateHistoryIndex$"] ActionPoints:"@UnitState.NumAllActionPoints()@" (Reserve:" @ UnitState.NumAllReserveActionPoints() $") - ";
				for( ActionIndex = 0; ActionIndex < UnitsCache[UnitCacheIndex].AvailableActions.Length; ++ActionIndex )
				{
					AvailableActionData = UnitsCache[UnitCacheIndex].AvailableActions[ActionIndex];

					AbilityState = XComGameState_Ability(CachedHistory.GetGameStateForObjectID(AvailableActionData.AbilityObjectRef.ObjectID));
					EnumString = string(AvailableActionData.AvailableCode);
					
					DebugString = DebugString$"("@AbilityState.GetMyTemplateName()@"-"@EnumString@") ";
				}
				DebugString = DebugString$"\n";
			}
		}

		return DebugString;
	}

	event Tick(float DeltaTime)
	{		
		local XComGameState_Player PlayerState;
		local XGAIPlayer AIPlayer;
		local int fTimeOut;
		local XComGameState_ChallengeData ChallengeData;
		local XComGameState_TimerData TimerState;

		super.Tick(DeltaTime);

		//rmcfall - if the AI player takes longer than 25 seconds to make a decision a blocking error has occurred in its logic. Skip its turn to avoid a hang.
		//This logic is redundant to turn skipping logic in the behaviors, and is intended as a last resort
		if( UnitActionPlayerIsAI() && bWaitingForNewStates && !(`CHEATMGR != None && `CHEATMGR.bAllowSelectAll) )
		{
			PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(GetCachedUnitActionPlayerRef().ObjectID));
			AIPlayer = XGAIPlayer(PlayerState.GetVisualizer());

			if (AIPlayer.m_eTeam == eTeam_Neutral)
			{
				fTimeOut = 5.0f;
			}
			else
			{
				fTimeOut = 25.0f;
			}
			WaitingForNewStatesTime += DeltaTime;
			if (WaitingForNewStatesTime > fTimeOut && !`REPLAY.bInReplay)
			{
				`LogAIActions("Exceeded WaitingForNewStates TimeLimit"@WaitingForNewStatesTime$"s!  Calling AIPlayer.EndTurn()");
				AIPlayer.OnTimedOut();
				class'XGAIPlayer'.static.DumpAILog();
				AIPlayer.EndTurn(ePlayerEndTurnType_AI);
			}
		}

		ChallengeData = XComGameState_ChallengeData( CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_ChallengeData', true) );
		if ((ChallengeData != none) && !UnitActionPlayerIsAI() && !WaitingForVisualizer())
		{
			TimerState = XComGameState_TimerData( CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_TimerData') );
			if (TimerState.GetCurrentTime() <= 0)
			{
				FailBattle();
			}
		}
	}

	function StateObjectReference GetCachedUnitActionPlayerRef()
	{
		if( InterruptingUnitActionPlayerRef.ObjectID > 0 )
		{
			return InterruptingUnitActionPlayerRef;
		}
		return CachedUnitActionPlayerRef;
	}
		
	function RequestAutosave()
	{
		local AutosaveParameters AutosaveParams;

		if(bSkipAutosaveAfterLoad)
		{
			bSkipAutosaveAfterLoad = false; // clear the flag so that the next autosave goes through
		}
		else if (RulesetShouldAutosave())
		{	
			AutosaveParams.AutosaveType = 'Autosave';
			`AUTOSAVEMGR.DoAutosave(AutosaveParams);			
		}
	}

Begin:
	`SETLOC("Start of Begin Block");
	CachedHistory.CheckNoPendingGameStates();

	//Loop through the players, allowing each to perform actions with their units
	do
	{	
		sleep(0.0); // Wait a tick for the game states to be updated before switching the sending
		
		//Before switching players, wait for the current player's last action to be fully visualized
		while( WaitingForVisualizer() )
		{
			`SETLOC("Waiting for Visualizer: 1");
			sleep(0.0);
		}

		// bsg-dforrest (7.2.17): wait on any latent states at the start of each turn
		while(IsDoingLatentSubmission())
		{
			`SETLOC("Waiting for Latent Submission: 0");
			sleep(0.0);
		}
		// bsg-dforrest (7.2.17): end

		// bsg-dforrest (7.6.17): if there are any sounds async loading after a units turn let them finish
		if(`ISCONSOLE)
		{
			while(`ONLINEEVENTMGR.WaitForAudioRetryQueue())
			{
				`SETLOC("Waiting for async audio bank loading: 1");
				sleep(0.0);
			}
		}
		// bsg-dforrest (7.6.17): end
			

		`SETLOC("Check for Available Actions");
		while( ActionsAvailable() && (!HasTacticalGameEnded() && !HasRoomEncounterEnded()) && !(bAllowKismetBreachControl && HasNextBreachRoomSet()) )
		{
			CachedHistory.CheckNoPendingGameStates();

			if(bWaitingForNewStates) //Will be true if the player can take actions
			{
				while (IsDoingLatentSubmission())
				{
					`SETLOC("Waiting for Latent Submission: 1");
					sleep(0.0);
				}
			}

			if (RulesetShouldAutosave())
			{
				VisualizerActivationHistoryFrames.AddItem(CachedHistory.GetNumGameStates());
			}

			WaitingForNewStatesTime = 0.0f;

			//Wait for new states created by the player / AI / remote player. Manipulated by the SubmitGameStateXXX methods
			while( (bWaitingForNewStates && !HasTimeExpired()) || BuildingLatentGameState)
			{
				`SETLOC("Available Actions");
				sleep(0.0);
			}
			`SETLOC("Available Actions: Done waiting for New States");
				
			sleep(0.0); //Must sleep for a frame to ensure the visualizer / latent state processing has processed the previous command
			while( WaitingForVisualizer() || IsDoingLatentSubmission() )
			{
				`SETLOC("Waiting for Visualizer: 1.5");
				sleep(0.0);
			}

			// Autosave upon the complete visualization of the input action, as this is when the player will have seen visualization for all the state frames that will be saved.
			RequestAutosave();			
			sleep(0.0);

			// bsg-dforrest (7.3.17): if this cheat is used we still need to wait on saves to finish
			if (`ISCONSOLE)
			{
				while (`ONLINEEVENTMGR.IsConsoleSaveInProgress())
				{
					`SETLOC("Waiting for cheat save to complete: 1");
					sleep(0.0);
				}
			}
			// bsg-dforrest (7.3.17): end

			sleep(0.0);
		}

		while( WaitingForVisualizer() || WaitingForMinimumTurnTimeElapsed() )
		{
			`SETLOC("Waiting for Visualizer: 2");
			sleep(0.0);
		}

		// Moved to clear the SkipRemainingTurnActivty flag until after the visualizer finishes.  Prevents an exploit where
		// the end/back button is spammed during the player's final action. Previously the Skip flag was set to true 
		// while visualizing the action, after the flag was already cleared, causing the subsequent AI turn to get skipped.
		bSkipRemainingTurnActivty = false;
		`SETLOC("Going to the Next Player");
	}
	until(!NextInitiativeGroup()); //NextInitiativeGroup returns false when the UnitActionInitiativeIndex has reached the end of PlayerTurnOrder in the BattleData state.
	
	//Wait for the visualizer to perform the visualization steps for all states before we permit the rules engine to proceed to the next phase
	while( EndOfTurnWaitingForVisualizer() )
	{
		`SETLOC("Waiting for Visualizer: 3");
		sleep(0.0);
	}
	
	// bsg-dforrest (7.6.17): if there are any sounds async loading dont go to the next phase
	if(`ISCONSOLE)
	{
		while(`ONLINEEVENTMGR.WaitForAudioRetryQueue())
		{
			`SETLOC("Waiting for async audio bank loading: 3");
			sleep(0.0);
		}
	}
	// bsg-dforrest (7.6.17): end

	// Failsafe. Make sure there are no active camera anims "stuck" on
	GetALocalPlayerController().PlayerCamera.StopAllCameraAnims(TRUE);

	`SETLOC("Updating AI Activity");
	UpdateAIActivity(false);

	CachedHistory.CheckNoPendingGameStates();

	`SETLOC("Ending the Phase");
	EndPhase();
	`SETLOC("End of Begin Block");
}

/// <summary>
/// This turn phase is entered at the end of each turn and handles any end-of-turn scenario events.
/// </summary>
simulated state TurnPhase_End
{
	simulated event BeginState(name PreviousStateName)
	{
		`SETLOC("BeginState");

		BeginState_RulesAuthority(none);
	}

Begin:
	`SETLOC("Start of Begin Block");

	////Wait for all players to reach this point in their rules engine
	//while( WaitingForPlayerSync() )
	//{
	//	sleep(0.0);
	//}

	CachedHistory.CheckNoPendingGameStates();

	`SETLOC("End of Begin Block");
	GotoState(GetNextTurnPhase(GetStateName()));
}

/// <summary>
/// This turn phase is entered at the end of each turn and handles any end-of-turn scenario events.
/// </summary>
simulated state TurnPhase_WaitForTutorialInput
{
	simulated event BeginState(name PreviousStateName)
	{
		`SETLOC("BeginState");

		BeginState_RulesAuthority(none);
	}

Begin:
	//We wait here forever until put back into PerformingReplay by XComTutorialMgr
	while (true)
	{
		sleep(0.f);
	}
}

/// <summary>
/// This phase is entered following the successful load of a replay. Turn logic is not intended to be applied to replays by default, but may be activated and
/// used to perform unit tests / validation of correct operation within this state.
/// </summary>
simulated state PerformingReplay
{
	simulated event BeginState(name PreviousStateName)
	{
		local UIReplay ReplayUI;
		`SETLOC("BeginState");

		bTacticalGameInPlay = true;

		//Auto-start the replay, but not if we are in the tutorial
		if (!`REPLAY.bInTutorial)
		{	
			ReplayUI = UIReplay(`PRES.ScreenStack.GetCurrentScreen());
			if (ReplayUI != none)
			{
				ReplayUI.OnPlayClicked();
			}
		}
	}

	function EndReplay()
	{
		GotoState(GetNextTurnPhase(GetStateName()));
	}

Begin:
	`SETLOC("End of Begin Block");
}

function ExecuteNextSessionCommand()
{
	//Tell the content manager to build its list of required content based on the game state that we just built and added.
	`CONTENT.RequestContent();
	ConsoleCommand(NextSessionCommandString);
}

static function ShowMissionSummaryVisualizationFn(XComGameState VisualizeGameState)
{
	local X2Action_UpdateUI UIUpdateAction;
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_PlaySoundAndFlyOver VOAction;
	local name VoiceoverEventName;
	local XComGameState_HeadquartersDio DioHQ;
	
	local X2Action_MarkerNamed NamedMarkerAction;
	local X2Action_MarkerNamed JoinAction;
	local array<X2Action> LeafNodes;
	local X2Action_WaitForVO WaitForBarksAction;
	local XComGameState_Unit MayorUnitState;

	DioHQ = `DioHQ;


	NamedMarkerAction = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
	NamedMarkerAction.SetName("PreVOMarker");

	// wait for active barks to complete
	WaitForBarksAction = X2Action_WaitForVO(class'X2Action_WaitForVO'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, NamedMarkerAction));

	//Trigger any VO
	if (DioHQ.TacticalGameplayTags.Find('DioTutorialMissionActive_Room_2') != INDEX_NONE)
	{
		MayorUnitState = class'XComGameState_DialogueManager'.static.StaticGetObjectiveUnitByCharacterName('Mayor');
		VoiceoverEventName = (MayorUnitState.WasInjuredOnMission() || MayorUnitState.IsInjured() || MayorUnitState.IsBleedingOut() || MayorUnitState.IsUnconscious()) ? 'EvntTutorialMayorInjured' : 'EvntTutorialMayorFine';
		
		VOAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, WaitForBarksAction));
		VOAction.SetSoundAndFlyOverParameters(None, "", VoiceoverEventName, eColor_Xcom);
		
		// todo: general mission end VO
	}

	// add a join for all leaf nodes
	`XCOMVISUALIZATIONMGR.GetAllLeafNodes(NamedMarkerAction, LeafNodes);
	JoinAction = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, none, LeafNodes));
	JoinAction.SetName("VOJoin");

	//UpdateUI 
	UIUpdateAction = X2Action_UpdateUI(class'X2Action_UpdateUI'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, JoinAction));
	UIUpdateAction.UpdateType = EUIUT_MissionSummary;
}

/// <summary>
/// This state is entered when a tactical game ended state is pushed onto the history
/// </summary>
simulated state EndTacticalGame
{
	simulated event BeginState(name PreviousStateName)
	{
		local XGPlayer ActivePlayer;
		local XComGameState_ChallengeData ChallengeData;

		`SETLOC("BeginState");

		ChallengeData = XComGameState_ChallengeData( CachedHistory.GetSingleGameStateObjectForClass( class'XComGameState_ChallengeData', true ) );

		if (PreviousStateName != 'PerformingReplay')
		{
			SubmitChallengeMode();
		}

		// make sure that no controllers are active
		if( GetCachedUnitActionPlayerRef().ObjectID > 0)
		{
			ActivePlayer = XGPlayer(CachedHistory.GetVisualizer(GetCachedUnitActionPlayerRef().ObjectID));
			ActivePlayer.m_kPlayerController.Visualizer_ReleaseControl();
		}

		//Show the UI summary screen before we clean up the tactical game
		if(!bPromptForRestart && !`REPLAY.bInTutorial && !IsFinalMission()/* && !IsLostAndAbandonedMission()*/)
		{
			if (ChallengeData == none)
			{
				SubmitShowMissionSummary();
				
				// Vertical Slice: don't show baked backend screen [2/6/2019 dmcdonough]
				//`PRES.UIMissionBackendScreen();
			}
			else
			{
				`PRES.UIChallengeModeSummaryScreen( );
			}

			`XTACTICALSOUNDMGR.StartEndBattleMusic();
		}

		//Disable visibility updates
		`XWORLD.bDisableVisibilityUpdates = true;
	}

	simulated function CleanupAndClearTacticalPlayFlags()
	{
		//The tutorial is just a replay that the player clicks through by performing the actions in the replay. 
		if( !`REPLAY.bInTutorial /*&& (ChallengeData == none) */)
		{
			EndTacticalPlay();
		}
		else
		{
			bTacticalGameInPlay = false;
		}
	}

	simulated function SubmitShowMissionSummary()
	{
		local XComGameState NewGameState;
		local XComGameStateContext_ChangeContainer NewContext;

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("EndTacticalGame: ShowMissionSummary");
		NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
		NewContext.BuildVisualizationFn = ShowMissionSummaryVisualizationFn;
		SubmitGameState(NewGameState);
	}

	simulated function SubmitChallengeMode()
	{
		local XComGameState_TimerData Timer;
		local XComGameState_ChallengeData ChallengeData;
		local XComGameState_BattleData BattleData;
		local XComGameState NewGameState;
		local X2ChallengeModeInterface ChallengeModeInterface;
		local XComChallengeModeManager ChallengeModeManager;
		local X2TacticalChallengeModeManager TacticalChallengeModeManager;

		ChallengeModeManager = `CHALLENGEMODE_MGR;
		ChallengeModeInterface = `CHALLENGEMODE_INTERFACE;
		BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		TacticalChallengeModeManager = `TACTICALGRI.ChallengeModeManager;
		TacticalChallengeModeManager.OnEventTriggered((BattleData.bLocalPlayerWon) ? ECME_CompletedMission : ECME_FailedMission);
		`log(`location @ "Triggered Event on Tactical Challenge Mode Manager: " @ `ShowVar(BattleData.bLocalPlayerWon));

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("EndTacticalGame: SubmitChallengeMode");

		Timer = XComGameState_TimerData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_TimerData', true));
		if (Timer != none)
		{
			ChallengeData = XComGameState_ChallengeData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_ChallengeData', true));
			ChallengeData = XComGameState_ChallengeData(NewGameState.ModifyStateObject(class'XComGameState_ChallengeData', ChallengeData.ObjectID));
			if (ChallengeData != none)
			{
				ChallengeData.SeedData.EndTime.A = Timer.GetUTCTimeInSeconds();
				ChallengeData.SeedData.VerifiedCount = Timer.GetElapsedTime();
				ChallengeData.SeedData.GameScore = ChallengeModeManager.GetTotalScore();
			}
		}

		SubmitGameState(NewGameState);

		if (ChallengeData != none && ChallengeModeInterface != none)
		{
			ChallengeModeInterface.PerformChallengeModePostGameSave();
			ChallengeModeInterface.PerformChallengeModePostEventMapData();
		}

		ChallengeModeManager.SetTempScoreData(CachedHistory);
	}

	simulated function NextSessionCommand()
	{	
		local XComGameState_BattleData BattleData;
		local XComGameState_MissionSite MissionState;
		local X2MissionSourceTemplate MissionSource;
		local XComGameState_HeadquartersDio DioHQ;		
		local bool bLoadingMovieOnReturn;
		
		// at the end of the session, the event listener needs to be cleared of all events and listeners; reset it
		`XEVENTMGR.ResetToDefaults(false);

		//Determine whether we were playing a one-off tactical battle or if we are in a campaign.
		BattleData = XComGameState_BattleData(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		if (BattleData.m_strDesc ~= "Challenge Mode")
		{
			`ONLINEEVENTMGR.SetShuttleToChallengeMenu();
			ConsoleCommand("disconnect");
		}		
		else if(BattleData.bIsTacticalQuickLaunch && !`REPLAY.bInTutorial) //Due to the way the tutorial was made, the battle data in it may record that it is a TQL match
		{
			ConsoleCommand("disconnect");
		}
		else
		{	
			DioHQ = XComGameState_HeadquartersDio(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio'));
			MissionState = XComGameState_MissionSite(CachedHistory.GetGameStateForObjectID(DioHQ.MissionRef.ObjectID));
			
			// HELIOS BEGIN
			// TODO: Unhardcode this for custom Strategy Game Ruleset
			//Figure out whether we need to go to a loading screen or not

			if ( !DLCFindStrategySessionCommand(NextSessionCommandString) )
				// Fallback
				NextSessionCommandString = class'XComGameStateContext_StrategyGameRule'.static.GetStrategyMapCommand();
				
			// HELIOS END
			bLoadingMovieOnReturn = true;

			// Complete tutorial
			if ("Prologue" == BattleData.MapData.ActiveMission.sType)
			{
				`DNA.TelemetryTutorial(true);
			}

			class'XComGameModeTransitionHelper'.static.CreateStrategyGameStartFromTactical();

			if (IsFinalMission())
			{
				`XENGINE.WaitForMovie();
				`XENGINE.StopCurrentMovie();
			}			

			//Change the session command based on whether we want to use a loading screen or seamless travel
			if(bLoadingMovieOnReturn)
			{
				MissionSource = MissionState.GetMissionSource();
				if (MissionSource.CustomLoadingMovieName_Outro != "")
				{
					`XENGINE.PlayMovie(false, MissionSource.CustomLoadingMovieName_Outro, MissionSource.CustomLoadingMovieName_OutroSound);
					`XENGINE.WaitForMovie();
					`XENGINE.StopCurrentMovie();
				}

				ReplaceText(NextSessionCommandString, "servertravel", "open");

				`XENGINE.PlayLoadMapMovie(-1);
				SetTimer(0.5f, false, nameof(ExecuteNextSessionCommand));
			}
			else
			{
				ExecuteNextSessionCommand();
			}
		}
	}

	simulated function PromptForRestart()
	{
		`PRES.UICombatLoseScreen(LoseType);
		`XTACTICALSOUNDMGR.StartEndBattleMusic();
	}

Begin:
	`SETLOC("Start of Begin Block");

	if (bPromptForRestart)
	{
		CleanupAndClearTacticalPlayFlags();
		PromptForRestart();
	}
	else
	{
		//This variable is cleared by the mission summary screen accept button
		bWaitingForMissionSummary = !`REPLAY.bInTutorial && !IsFinalMission();
		while (bWaitingForMissionSummary)
		{
			Sleep(0.0f);
		}

		// once the Mission summary UI's have cleared, it is then safe to cleanup the rest of the mission game state
		CleanupAndClearTacticalPlayFlags();

		//Turn the visualization mgr off while the map shuts down / seamless travel starts
		VisibilityMgr.UnRegisterForNewGameStateEvent();
		VisualizationMgr.DisableForShutdown();

		//Schedule a 1/2 second fade to black, and wait a moment. Only if the camera is not already faded
		if(!WorldInfo.GetALocalPlayerController().PlayerCamera.bEnableFading)
		{
			`PRES.HUDHide();
			WorldInfo.GetALocalPlayerController().ClientSetCameraFade(true, MakeColor(0, 0, 0), vect2d(0, 1), 0.75);			
			Sleep(1.0f);
		}

		//Trigger the launch of the next session
		NextSessionCommand();
	}
	`SETLOC("End of Begin Block");
}

simulated function name GetLastStateNameFromHistory(name DefaultName='')
{
	local int HistoryIndex;
	local XComGameStateContext_TacticalGameRule Rule;
	local name StateName;

	StateName = DefaultName;
	for( HistoryIndex = CachedHistory.GetCurrentHistoryIndex(); HistoryIndex > 0; --HistoryIndex )
	{
		Rule = XComGameStateContext_TacticalGameRule(CachedHistory.GetGameStateFromHistory(HistoryIndex).GetContext());
		if( Rule != none && Rule.GameRuleType == eGameRule_RulesEngineStateChange)
		{
			StateName = Rule.RuleEngineNextState;
			break;
		}
	}
	return StateName;
}

simulated function bool LoadedGameNeedsPostCreate()
{
	local XComGameState_BattleData BattleData;
	BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));

	if (BattleData == None)
		return false;

	if (BattleData.bInPlay)
		return false;

	if (!BattleData.bIntendedForReloadLevel)
		return false;

	return true;
}

simulated function name GetNextTurnPhase(name CurrentState, optional name DefaultPhaseName='TurnPhase_End')
{
	local name LastState;
	
	switch (CurrentState)
	{
	case 'CreateTacticalGame':
		return 'PostCreateTacticalGame';

	case 'LoadTacticalGame':
		if( XComTacticalGRI(class'WorldInfo'.static.GetWorldInfo().GRI).ReplayMgr.bInReplay )
		{
			return 'PerformingReplay';
		}
		if (LoadedGameNeedsPostCreate())
		{
			bLoadingSavedGame = false;
			return 'PostCreateTacticalGame';
		}
		LastState = GetLastStateNameFromHistory();
		if (LastState == 'TurnPhase_Breach')
		{
			bLoadingSavedGame = false;		// make sure the first player gets its turn
			return 'TurnPhase_Breach';
		}
		else if (LastState == '' || CurrentState == 'LoadTacticalGame')
		{
			return 'TurnPhase_UnitActions';
		}
		else
		{
			return GetNextTurnPhase(LastState, 'TurnPhase_UnitActions');
		}

	case 'PostCreateTacticalGame':
		return  bEnableBreachMode ? ((!bAllowKismetBreachControl) ? 'TurnPhase_Breach':'TurnPhase_WaitForKismetBreach') : 'TurnPhase_Begin';

	case 'TurnPhase_Breach':
		return 'TurnPhase_Begin';

	case 'TurnPhase_Begin':		
		if (XComTacticalGRI(class'WorldInfo'.static.GetWorldInfo().GRI).ReplayMgr.bInTutorial)
		{
			return 'TurnPhase_WaitForTutorialInput';
		}
		else
		{
			return 'TurnPhase_UnitActions';
		}
	case 'TurnPhase_UnitActions':
		return 'TurnPhase_End';

	case 'TurnPhase_End':
		return 'TurnPhase_Begin';

	case 'PerformingReplay':
		if (!XComTacticalGRI(class'WorldInfo'.static.GetWorldInfo().GRI).ReplayMgr.bInReplay || XComTacticalGRI(class'WorldInfo'.static.GetWorldInfo().GRI).ReplayMgr.bInTutorial)
		{
			//Used when resuming from a replay, or in the tutorial and control has "returned" to the player
			return 'TurnPhase_Begin';
		}

	case 'TurnPhase_WaitForKismetBreach':
		return bEnableBreachMode ? 'TurnPhase_Breach' : 'TurnPhase_Begin';
	}

	`assert(false);
	return DefaultPhaseName;
}

function StateObjectReference GetCachedUnitActionPlayerRef()
{
	local StateObjectReference EmptyRef;
	// This should generally not be called outside of the TurnPhase_UnitActions
	// state, except when applying an effect that has bIgnorePlayerCheckOnTick
	// set
	return EmptyRef;
}

final function bool TacticalGameIsInPlay()
{
	return bTacticalGameInPlay;
}

function bool IsWaitingForNewStates()
{
	return bWaitingForNewStates;
}

native function TacticalStreamingMapsPostLoad();

function int GetRequiredAndroidReinforcementCount()
{
	local array<XComGameState_Unit> UnitStates;
	local XComGameState_Unit UnitState;
	local int LivingUnitCount;

	class'XComBreachHelpers'.static.GatherXComBreachUnits(UnitStates);
	foreach UnitStates(UnitState)
	{
		if (UnitState.IsAlive() && !UnitState.IsUnconscious())
		{
			LivingUnitCount++;
		}
	}

	return (class'XComBreachHelpers'.default.NormalSquadSize - LivingUnitCount);
}

function bool HasAndroidReserve()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', false));

	return BattleData.SpentAndroidReserves.length < BattleData.StartingAndroidReserves.length;
}

function CallInXComAndroidReinforcement(XComGameState NewGameState, const out array<StateObjectReference> AndroidRefs)
{
	local XComGameStateHistory		History;
	local StateObjectReference		AndroidRef, AbilityRef;
	local XComGameState_BattleData	BattleData;
	local int						AvaliableAndroidCount, i, NumActionPoints;
	local XComGameState_Unit		AndroidState;
	local XComGameState_Ability		AbilityState;
	local XComGameState_MissionSite MissionSiteState;
	local XComGameState_StrategyAction_Mission MissionAction;

	History = `XCOMHISTORY;

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', false));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	MissionSiteState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));
	MissionAction = MissionSiteState.GetMissionAction();

	AvaliableAndroidCount = BattleData.StartingAndroidReserves.length - BattleData.SpentAndroidReserves.length;
	`assert(AndroidRefs.length <= AvaliableAndroidCount);

	NumActionPoints = 10;

	foreach AndroidRefs(AndroidRef)
	{
		AndroidState = XComGameState_Unit(History.GetGameStateForObjectID(AndroidRef.ObjectID));
		AndroidState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AndroidState.ObjectID));

		AndroidState.ClearRemovedFromPlayFlag();
		AndroidState.bCanTraverseRooms = true;

		AndroidState.ActionPoints.Length = 0;
		for (i = 0; i < NumActionPoints; ++i)
		{
			AndroidState.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.StandardActionPoint);
		}

		// init & register for UnitPostBeginPlayTrigger 
		foreach AndroidState.Abilities(AbilityRef)
		{
			AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(AbilityRef.ObjectID));
			AbilityState.CheckForPostBeginPlayActivation(NewGameState);
		}

		// lot of systems expect XCOM units to be in the AssignedUnitRefs array
		MissionAction.AssignUnit(NewGameState, AndroidRef);

		BattleData.SpentAndroidReserves.AddItem(AndroidRef);

		// init & register for unit specific events
		AndroidState.OnBeginTacticalPlay(NewGameState);
	}

	`XEVENTMGR.TriggerEvent('RequestXComAndroidReinforcement', self, BattleData, NewGameState);

}

static function CallInXComAndroidReinforcementVisualization(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata ActionMetadata;
	local XComGameState_Unit UnitState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(UnitState.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
		ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(UnitState.ObjectID);
		ActionMetadata.VisualizeActor = History.GetVisualizer(UnitState.ObjectID);

		class'X2Action_SyncVisualizer'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext());
	}
}

function LogPlayerTurnOrder()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local int Index;
	local XComGameState_Unit UnitState;
	local XComGameState_AIGroup GroupState;
	local XComGameState_Player PlayerState;
	local StateObjectReference Ref;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	`Log("PlayerTurnOrder");
	for( Index = 0; Index < BattleData.PlayerTurnOrder.Length; ++Index )
	{
		GroupState = XComGameState_AIGroup( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[Index].ObjectID ) );
		if( GroupState != None )
		{
			`Log("    Group:" @ GroupState.TeamName @ GroupState.ObjectID);

			foreach GroupState.m_arrMembers(Ref)
			{
				UnitState = XComGameState_Unit(History.GetGameStateForObjectID(Ref.ObjectID));
				if( UnitState != None )
				{
					`Log("        Unit" @ UnitState.GetMyTemplateName() @ UnitState.ObjectID @ ( UnitState.IsAlive() ? "" : "Dead" ) );
				}
			}
		}
		PlayerState = XComGameState_Player( History.GetGameStateForObjectID( BattleData.PlayerTurnOrder[Index].ObjectID ) );
		if( PlayerState != None )
		{
			`Log(" Player:" @ PlayerState.GetTeam() @ PlayerState.ObjectID);
		}
	}
}

// HELIOS BEGIN
// 
static function bool DLCFindStrategySessionCommand(out string SessionCommand)
{
	local array<X2DownloadableContentInfo> DLCInfos; 
	local int i; 

	DLCInfos = `ONLINEEVENTMGR.GetDLCInfos(false);
	for(i = 0; i < DLCInfos.Length; ++i)
	{
		if ( DLCInfos[i].RetrieveStrategySessionCommand(SessionCommand) )
			return true;
	}

	return false;
}
// HELIOS END

DefaultProperties
{
	EventObserverClasses[0] = class'X2TacticalGameRuleset_MovementObserver'
	EventObserverClasses[1] = class'X2TacticalGameRuleset_AttackObserver'
	EventObserverClasses[2] = class'KismetGameRulesetEventObserver'

	ContextBuildDepth = 0
	DioMovementMethod = eMoveMethod_DioDashing;

	// use -2 so that passing it to GetGameStateFromHistory will return NULL. -1 would return the latest gamestate
	TacticalGameEndIndex = -2
	LastRoomClearedHistoryIndex = -2

	CurrentBreachCameraIndex = -1;
	CurrentBreachActionIndex = -1;

	bRequestHeadshots = false;

	ReInterleaveInitiativeType= eReInterleaveInitiativeType_TimelineMid
}
