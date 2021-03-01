//---------------------------------------------------------------------------------------
//  FILE:    	DioStrategyNotificationsHelper
//  AUTHOR:  	David McDonough  --  10/11/2019
//  PURPOSE: 	Static object to handle analyzing and building Notifications.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

//
// HELIOS CHANGE: Allow mods to change everything about the notifications by using XComLWTuple and HSStrategyNotificationObject
//
class DioStrategyNotificationsHelper extends Object
	config(GameData);

var config int NotificationTypeSortPriorities[EStrategyNotificationType.EnumCount]<BoundEnum = EStrategyNotificationType>;



var localized string CriticalMissionTitle;
var localized string CriticalMissionBody;
var localized string UnassignedAgentsTitle;
var localized string UnassignedAgentsBody;
var localized string UnlockAgentTitle;
var localized string UnlockAgentBody;
var localized string PromotionsWaitingTitle;
var localized string PromotionsWaitingBody;
var localized string ScarsEarnedTitle;
var localized string LeftBehindScarsEarnedTitle;
var localized string LeftBehindScarsEarnedBody;
var localized string AssemblyCompleteTitle;
var localized string AssemblyIdleTitle;
var localized string AssemblyIdleBody;
var localized string TrainingCompleteTitle;
var localized string TrainingCompleteBody;
var localized string SpecOpsCompleteTitle;
var localized string SpecOpsCompleteBody;
var localized string NewSupplyItemsTitle;
var localized string NewSupplyItemsBody;
var localized string NewSpecOpsTitle;
var localized string NewSpecOpsBody;
var localized string ScavengerMarketOpenTitle;
var localized string ScavengerMarketOpenBody;
var localized string TagStr_ScavengerMarketFreeBuy;
var localized string TagStr_ScavengerMarketFreeBuyPlural;
var localized string PassiveIncomeTitle;
var localized string TagStr_PassiveIncomeBody;
var localized string AnarchyUnrestChangedTitle;
var localized string PaceCheckSpecOpsTitle;
var localized string PaceCheckSpecOpsBody;
var localized string PaceCheckTrainingTitle;
var localized string PaceCheckTrainingBody;
var localized string PaceCheckFieldTeamsTitle;
var localized string PaceCheckFieldTeamsBody;
var localized string PaceCheckFieldTeamAbilitiesTitle;
var localized string PaceCheckFieldTeamAbilitiesBody;

// Tutorial-based notifications
var localized string TutorialAssemblyAvailableTitle;
var localized string TutorialAssemblyAvailableBody;
var localized string TutorialSpecOpsAvailableTitle;
var localized string TutorialSpecOpsAvailableBody;
var localized string TutorialTrainingAvailableTitle;
var localized string TutorialTrainingAvailableBody;
var localized string TutorialNewAndroidTitle;

//---------------------------------------------------------------------------------------
static function XComGameState_HeadquartersDio ModDioHQ(XComGameState ModifyGameState)
{
	return XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));
}

//---------------------------------------------------------------------------------------
//				CRITICAL MISSION
//---------------------------------------------------------------------------------------
static function RefreshCriticalMissionNotification(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	DioHQ = ModDioHQ(ModifyGameState);

	// Tutorial Act, Day (Director's Call): don't show this notification
	if (`TutorialEnabled && DioHQ.CurrentTurn <= 0)
	{
		DioHQ.RemoveNotificationByType(eSNT_CriticalMissionAlert);
		return;
	}

	NotifObj = new class'HSStrategyNotificationObject';
	NotifObj.NotificationData.Type 				= eSNT_CriticalMissionAlert;
	NotifObj.NotificationData.Title 			= default.CriticalMissionTitle;
	NotifObj.NotificationData.Body 				= default.CriticalMissionBody;
	NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_CriticalMissionOnMap;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'CriticalMissionNotificationObject';
	Tuple.Data.Add(1);
	Tuple.Data[0].kind = XComLWTVObject;
	Tuple.Data[0].o = NotifObj;

	`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateCriticalMissionNotif', Tuple, Tuple, ModifyGameState);

	// Retrieve edited data from tuple
	NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

	if (class'DioStrategyAI'.static.GetCriticalMissionWorker(ModifyGameState) != none)
	{
		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
								NotifObj.NotificationData.OnItemSelectedFn, 
								NotifObj.NotificationData.Title, 
								NotifObj.NotificationData.Body,
								NotifObj.NotificationData.UnitRefs,
								NotifObj.NotificationData.ImagePath,
								NotifObj.NotificationData.UIColor								
								);
	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}
}

//---------------------------------------------------------------------------------------
//				IDLE AGENTS
//---------------------------------------------------------------------------------------
static function RefreshUnassignedAgentsNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local array<StateObjectReference> UnassignedUnitRefs;
	local name Assignment;
	local int i;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	DioHQ = ModDioHQ(ModifyGameState);
	for (i = 0; i < DioHQ.Squad.Length; ++i)
	{
		Assignment = class'DioStrategyAI'.static.GetAgentAssignment(DioHQ.Squad[i], ModifyGameState);
		if (Assignment == 'None')
		{
			UnassignedUnitRefs.AddItem(DioHQ.Squad[i]);
		}
	}

	NotifObj = new class'HSStrategyNotificationObject';
	NotifObj.NotificationData.Type 				= eSNT_UnassignedUnits;
	NotifObj.NotificationData.Title 			= default.UnassignedAgentsTitle;
	NotifObj.NotificationData.UnitRefs 			= UnassignedUnitRefs;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'UnassignedAgentsNotificationObject';
	Tuple.Data.Add(1);
	Tuple.Data[0].kind = XComLWTVObject;
	Tuple.Data[0].o = NotifObj;

	`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateUnassignedAgentsNotif', Tuple, Tuple, ModifyGameState);

	// Retrieve edited data from tuple
	NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

	if (UnassignedUnitRefs.Length > 0)
	{
		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
								NotifObj.NotificationData.OnItemSelectedFn, 
								NotifObj.NotificationData.Title, 
								NotifObj.NotificationData.Body,
								NotifObj.NotificationData.UnitRefs,
								NotifObj.NotificationData.ImagePath,
								NotifObj.NotificationData.UIColor								
								);
	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}
}

//---------------------------------------------------------------------------------------
//				UNLOCK NEW AGENT
//---------------------------------------------------------------------------------------
static function RefreshUnlockAgentNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	DioHQ = ModDioHQ(ModifyGameState);
	
	// HELIOS BEGIN
	NotifObj = new class'HSStrategyNotificationObject';
	NotifObj.NotificationData.Type 				= eSNT_UnlockAgent;
	NotifObj.NotificationData.Title 			= default.UnlockAgentTitle;
	NotifObj.NotificationData.Body 				= default.UnlockAgentBody;
	NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_UnlockAgent;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'UnlockAgentNotificationObject';
	Tuple.Data.Add(1);
	Tuple.Data[0].kind = XComLWTVObject;
	Tuple.Data[0].o = NotifObj;

	`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateUnlockAgentNotif', Tuple, Tuple, ModifyGameState);

	// Retrieve edited data from tuple
	NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

	if (DioHQ.PendingSquadUnlocks > 0)
	{
		// HELIOS: Moved to Presentation Base
		`PRESBASE.ArmoryAttentionCount++;

		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
								NotifObj.NotificationData.OnItemSelectedFn, 
								NotifObj.NotificationData.Title, 
								NotifObj.NotificationData.Body,
								NotifObj.NotificationData.UnitRefs,
								NotifObj.NotificationData.ImagePath,
								NotifObj.NotificationData.UIColor								
								);
	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}
	// HELIOS END
}

//---------------------------------------------------------------------------------------
//				PROMOTIONS
//---------------------------------------------------------------------------------------
static function RefreshPromotionNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local array<StateObjectReference> PromotableUnitRefs;
	local int i;
	local XComGameStateHistory History;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	History = `XCOMHISTORY;

	DioHQ = ModDioHQ(ModifyGameState);
	for (i = 0; i < DioHQ.Squad.Length; ++i)
	{
		Unit = XComGameState_Unit(ModifyGameState.GetGameStateForObjectID(DioHQ.Squad[i].ObjectID));
		if (Unit == None)
			Unit = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Squad[i].ObjectID));

		//Unit = XComGameState_Unit(ModifyGameState.ModifyStateObject(class'XComGameState_Unit', DioHQ.Squad[i].ObjectID));
		if (Unit.HasAvailablePerksToAssign())
		{
			PromotableUnitRefs.AddItem(DioHQ.Squad[i]);
		}
	}

	// HELIOS BEGIN
	NotifObj = new class'HSStrategyNotificationObject';
	NotifObj.NotificationData.Type 				= eSNT_Promotions;
	NotifObj.NotificationData.Title 			= default.PromotionsWaitingTitle;
	NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_ArmoryUnit;
	NotifObj.NotificationData.UnitRefs 			= PromotableUnitRefs;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'PromotionNotificationObject';
	Tuple.Data.Add(1);
	Tuple.Data[0].kind = XComLWTVObject;
	Tuple.Data[0].o = NotifObj;

	`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreatePromotionNotif', Tuple, Tuple, ModifyGameState);

	// Retrieve edited data from tuple
	NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

	if (PromotableUnitRefs.Length > 0)
	{
		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
								NotifObj.NotificationData.OnItemSelectedFn, 
								NotifObj.NotificationData.Title, 
								NotifObj.NotificationData.Body,
								NotifObj.NotificationData.UnitRefs,
								NotifObj.NotificationData.ImagePath,
								NotifObj.NotificationData.UIColor								
								);
	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}
	// HELIOS END
}

//---------------------------------------------------------------------------------------
//				SCARS
//---------------------------------------------------------------------------------------
static function RefreshScarNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local XComGameState_UnitScar UnitScar;
	local ScarHistoryData LatestScarHistory;
	local array<StateObjectReference> NormalScarUnitRefs;
	local array<StateObjectReference> LeftBehindScarUnitRefs;
	local int i, k;
	local XComGameStateHistory History;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	History = `XCOMHISTORY;

	DioHQ = ModDioHQ(ModifyGameState);
	for (i = 0; i < DioHQ.Squad.Length; ++i)
	{
		Unit = XComGameState_Unit(ModifyGameState.GetGameStateForObjectID(DioHQ.Squad[i].ObjectID));
		if (Unit == None)
		{
			Unit = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Squad[i].ObjectID));
		}

		for (k = 0; k < Unit.Scars.Length; ++k)
		{
			UnitScar = XComGameState_UnitScar(ModifyGameState.GetGameStateForObjectID(Unit.Scars[k].ObjectID));
			if (UnitScar == none)
			{
				UnitScar = XComGameState_UnitScar(History.GetGameStateForObjectID(Unit.Scars[k].ObjectID));
			}

			if (UnitScar.TurnApplied == DioHQ.CurrentTurn || UnitScar.TurnLastDeepened == DioHQ.CurrentTurn)
			{
				UnitScar.GetLatestScarHistory(LatestScarHistory);
				if (LatestScarHistory.Source == eScarSource_LeftBehind)
				{
					LeftBehindScarUnitRefs.AddItem(Unit.GetReference());
				}
				else
				{
					NormalScarUnitRefs.AddItem(Unit.GetReference());
				}
			}
		}
	}
	
	// HELIOS BEGIN
	NotifObj = new class'HSStrategyNotificationObject';

	NotifObj.NotificationData.Type 				= eSNT_NormalScar;
	NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_ArmoryUnit;


	if (NormalScarUnitRefs.Length > 0)
	{
		NotifObj.NotificationData.Title 			= default.ScarsEarnedTitle;
		NotifObj.NotificationData.UnitRefs 			= NormalScarUnitRefs;

		Tuple = new class'XComLWTuple';
		Tuple.Id = 'NormalScarNotificationObject';
		Tuple.Data.Add(1);
		Tuple.Data[0].kind = XComLWTVObject;
		Tuple.Data[0].o = NotifObj;

		`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateNormalScarNotif', Tuple, Tuple, ModifyGameState);

		// Retrieve edited data from tuple
		NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
								NotifObj.NotificationData.OnItemSelectedFn, 
								NotifObj.NotificationData.Title, 
								NotifObj.NotificationData.Body,
								NotifObj.NotificationData.UnitRefs,
								NotifObj.NotificationData.ImagePath,
								NotifObj.NotificationData.UIColor								
								);

	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}

	NotifObj.NotificationData.Type 				= eSNT_LeftBehindScar;

	if (LeftBehindScarUnitRefs.Length > 0)
	{
		// HELIOS BEGIN
		NotifObj.NotificationData.Title 			= default.LeftBehindScarsEarnedTitle;
		NotifObj.NotificationData.Body 				= default.LeftBehindScarsEarnedBody;
		NotifObj.NotificationData.UnitRefs 			= LeftBehindScarUnitRefs;

		Tuple = new class'XComLWTuple';
		Tuple.Id 				= 'LeftBehindScarNotificationObject';
		Tuple.Data.Add(1);
		Tuple.Data[0].kind 		= XComLWTVObject;
		Tuple.Data[0].o 		= NotifObj;

		`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateLeftBehindScarNotif', Tuple, Tuple, ModifyGameState);

		// Retrieve edited data from tuple
		NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
								NotifObj.NotificationData.OnItemSelectedFn, 
								NotifObj.NotificationData.Title, 
								NotifObj.NotificationData.Body,
								NotifObj.NotificationData.UnitRefs,
								NotifObj.NotificationData.ImagePath,
								NotifObj.NotificationData.UIColor								
								);
	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}
	// HELIOS END
}

//---------------------------------------------------------------------------------------
//				ASSEMBLY
//---------------------------------------------------------------------------------------
static function RefreshAssemblyNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_DioResearch FirstUnseenResearch;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	DioHQ = ModDioHQ(ModifyGameState);

	// Early clear: Assembly not available or just appeared
	if (!class'DioStrategyTutorialHelper'.static.IsAssignmentAvailable('Research') ||
		DioHQ.HasNotificationOfType(eSNT_TutorialAssemblyAvailable))
	{
		DioHQ.RemoveNotificationByType(eSNT_AssemblyComplete);
		DioHQ.RemoveNotificationByType(eSNT_AssemblyIdle);
		return;
	}

	// First notify if unseen completed Assembly projects
	if (DioHQ.UnseenCompletedResearch.Length > 0)
	{
		`STRATPRES.ResearchAttentionCount++;
		FirstUnseenResearch = XComGameState_DioResearch(`XCOMHISTORY.GetGameStateForObjectID(DioHQ.UnseenCompletedResearch[0].ObjectID));
		
		// HELIOS BEGIN
		NotifObj = new class'HSStrategyNotificationObject';
		NotifObj.NotificationData.Type 				= eSNT_AssemblyComplete;
		NotifObj.NotificationData.Title 			= default.AssemblyCompleteTitle;
		NotifObj.NotificationData.Body 				= FirstUnseenResearch.GetMyTemplate().DisplayName;
		NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_Research;

		Tuple = new class'XComLWTuple';
		Tuple.Id = 'AssemblyCompleteNotificationObject';
		Tuple.Data.Add(1);
		Tuple.Data[0].kind = XComLWTVObject;
		Tuple.Data[0].o = NotifObj;

		`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateAssemblyCompleteNotif', Tuple, Tuple, ModifyGameState);

		// Retrieve edited data from tuple
		NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
						NotifObj.NotificationData.OnItemSelectedFn, 
						NotifObj.NotificationData.Title, 
						NotifObj.NotificationData.Body,
						NotifObj.NotificationData.UnitRefs,
						NotifObj.NotificationData.ImagePath,
						NotifObj.NotificationData.UIColor								
						);

		// HELIOS END
	}
	// Second notify if no active research
	else
	{
		DioHQ.RemoveNotificationByType(eSNT_AssemblyComplete);

		if (DioHQ.ActiveResearchRef.ObjectID <= 0)
		{
			`STRATPRES.ResearchAttentionCount++;

			// HELIOS BEGIN
			NotifObj = new class'HSStrategyNotificationObject';
			NotifObj.NotificationData.Type 				= eSNT_AssemblyIdle;
			NotifObj.NotificationData.Title 			= default.AssemblyIdleTitle;
			NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_Research;

			Tuple = new class'XComLWTuple';
			Tuple.Id = 'AssemblyIdleNotificationObject';
			Tuple.Data.Add(1);
			Tuple.Data[0].kind = XComLWTVObject;
			Tuple.Data[0].o = NotifObj;

			`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateAssemblyIdleNotif', Tuple, Tuple, ModifyGameState);

			// Retrieve edited data from tuple
			NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

			DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
							NotifObj.NotificationData.OnItemSelectedFn, 
							NotifObj.NotificationData.Title, 
							NotifObj.NotificationData.Body,
							NotifObj.NotificationData.UnitRefs,
							NotifObj.NotificationData.ImagePath,
							NotifObj.NotificationData.UIColor								
							);
			// HELIOS END
		}
		else
		{
			DioHQ.RemoveNotificationByType(eSNT_AssemblyIdle);
		}
	}
}

//---------------------------------------------------------------------------------------
//				TRAINING
//---------------------------------------------------------------------------------------
static function RefreshTrainingNotifications(XComGameState ModifyGameState)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local StateObjectReference UnitRef;
	local array<StateObjectReference> UnitRefs;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	History = `XCOMHISTORY;
	DioHQ = ModDioHQ(ModifyGameState);
	DioHQ.RemoveNotificationByType(eSNT_TrainingComplete);
	UnitRefs.Length = 0;

	foreach DioHQ.Squad(UnitRef)
	{
		Unit = XComGameState_Unit(ModifyGameState.GetGameStateForObjectID(UnitRef.ObjectID));
		if (Unit == None)
		{
			Unit = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		}

		if (Unit.UnseenCompletedTrainingActions.Length > 0)
		{
			UnitRefs.AddItem(UnitRef);

			// HELIOS BEGIN
			NotifObj = new class'HSStrategyNotificationObject';
			NotifObj.NotificationData.Type 				= eSNT_TrainingComplete;
			NotifObj.NotificationData.Title 			= default.TrainingCompleteTitle;
			NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_Training;
			NotifObj.NotificationData.UnitRefs 			= UnitRefs;

			Tuple = new class'XComLWTuple';
			Tuple.Id = 'TrainingCompleteNotificationObject';
			Tuple.Data.Add(1);
			Tuple.Data[0].kind = XComLWTVObject;
			Tuple.Data[0].o = NotifObj;

			`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateTrainingCompleteNotif', Tuple, Tuple, ModifyGameState);

			// Retrieve edited data from tuple
			NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

			DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
									NotifObj.NotificationData.OnItemSelectedFn, 
									NotifObj.NotificationData.Title, 
									NotifObj.NotificationData.Body,
									NotifObj.NotificationData.UnitRefs,
									NotifObj.NotificationData.ImagePath,
									NotifObj.NotificationData.UIColor								
									);
			// HELIOS END
		}
	}
}

//---------------------------------------------------------------------------------------
static function SubmitClearUnseenTrainingPrograms(StateObjectReference UnitRef)
{
	local XComGameState UpdateState;
	local XComGameState_Unit Unit;
	local XComGameStateContext_ChangeContainer ChangeContainer;

	if (UnitRef.ObjectID <= 0)
	{
		return;
	}
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (Unit.UnseenCompletedTrainingActions.Length == 0)
	{
		return;
	}

	ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Clear Unseen Training Programs");
	UpdateState = `XCOMHISTORY.CreateNewGameState(true, ChangeContainer);

	Unit = XComGameState_Unit(UpdateState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
	Unit.UnseenCompletedTrainingActions.Length = 0;

	`GAMERULES.SubmitGameState(UpdateState);
}

//---------------------------------------------------------------------------------------
//				SPEC OPS
//---------------------------------------------------------------------------------------
static function RefreshSpecOpsCompleteNotification(XComGameState ModifyGameState)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local StateObjectReference UnitRef;
	local array<StateObjectReference> UnitRefs;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	History = `XCOMHISTORY;
	DioHQ = ModDioHQ(ModifyGameState);
	DioHQ.RemoveNotificationByType(eSNT_SpecOpsComplete);
	UnitRefs.Length = 0;

	foreach DioHQ.Squad(UnitRef)
	{
		Unit = XComGameState_Unit(ModifyGameState.GetGameStateForObjectID(UnitRef.ObjectID));
		if (Unit == None)
		{
			Unit = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		}

		if (Unit.UnseenCompletedSpecOpsActions.Length > 0)
		{
			UnitRefs.AddItem(UnitRef);

			// HELIOS BEGIN
			NotifObj = new class'HSStrategyNotificationObject';
			NotifObj.NotificationData.Type 				= eSNT_SpecOpsComplete;
			NotifObj.NotificationData.Title 			= default.SpecOpsCompleteTitle;
			NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_SpecOps;
			NotifObj.NotificationData.UnitRefs 			= UnitRefs;

			Tuple = new class'XComLWTuple';
			Tuple.Id = 'SpecOpsCompleteNotificationObject';
			Tuple.Data.Add(1);
			Tuple.Data[0].kind = XComLWTVObject;
			Tuple.Data[0].o = NotifObj;

			`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateSpecOpsCompleteNotif', Tuple, Tuple, ModifyGameState);

			// Retrieve edited data from tuple
			NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

			DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
									NotifObj.NotificationData.OnItemSelectedFn, 
									NotifObj.NotificationData.Title, 
									NotifObj.NotificationData.Body,
									NotifObj.NotificationData.UnitRefs,
									NotifObj.NotificationData.ImagePath,
									NotifObj.NotificationData.UIColor								
									);

			// HELIOS END
		}
	}
}

//---------------------------------------------------------------------------------------
static function SubmitClearUnseenSpecOpsPrograms(StateObjectReference UnitRef)
{
	local XComGameState UpdateState;
	local XComGameState_Unit Unit;
	local XComGameStateContext_ChangeContainer ChangeContainer;

	if (UnitRef.ObjectID <= 0)
	{
		return;
	}
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (Unit.UnseenCompletedSpecOpsActions.Length == 0)
	{
		return;
	}

	ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Clear Unseen Spec Ops Actions");
	UpdateState = `XCOMHISTORY.CreateNewGameState(true, ChangeContainer);

	Unit = XComGameState_Unit(UpdateState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
	Unit.UnseenCompletedSpecOpsActions.Length = 0;

	`GAMERULES.SubmitGameState(UpdateState);
}

//---------------------------------------------------------------------------------------
//				SUPPLY
//---------------------------------------------------------------------------------------
static function RefreshSupplyNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyMarket XCOMStore;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	DioHQ = ModDioHQ(ModifyGameState);
	XCOMStore = XComGameState_StrategyMarket(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyMarket', DioHQ.XCOMStoreRef.ObjectID));

	// HELIOS BEGIN
	NotifObj = new class'HSStrategyNotificationObject';
	NotifObj.NotificationData.Type 				= eSNT_SupplyNewItems;
	NotifObj.NotificationData.Title 			= default.NewSupplyItemsTitle;
	NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_Supply;

	Tuple = new class'XComLWTuple';
	Tuple.Id = 'NewSupplyNotificationObject';
	Tuple.Data.Add(1);
	Tuple.Data[0].kind = XComLWTVObject;
	Tuple.Data[0].o = NotifObj;

	`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateNewSupplyNotif', Tuple, Tuple, ModifyGameState);

	// Retrieve edited data from tuple
	NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

	if (XCOMStore.UnseenItemNames.Length > 0)
	{
		`STRATPRES.ResearchAttentionCount++;

		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
								NotifObj.NotificationData.OnItemSelectedFn, 
								NotifObj.NotificationData.Title, 
								NotifObj.NotificationData.Body,
								NotifObj.NotificationData.UnitRefs,
								NotifObj.NotificationData.ImagePath,
								NotifObj.NotificationData.UIColor								
								);
	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}
	// HELIOS END
}

//---------------------------------------------------------------------------------------
//				SCAVENGER MARKET
//---------------------------------------------------------------------------------------
static function RefreshScavengerMarketNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XGParamTag LocTag;
	local string Title, Body;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	DioHQ = ModDioHQ(ModifyGameState);

	// HELIOS BEGIN
	NotifObj = new class'HSStrategyNotificationObject';
	NotifObj.NotificationData.Type 				= eSNT_ScavengerMarketOpen;
	
	if (DioHQ.IsScavengerMarketAvailable(ModifyGameState))
	{
		Title = default.ScavengerMarketOpenTitle;

		// Body text only if the player has free buys to indicate
		if (DioHQ.ScavengerMarketCredits > 0)
		{
			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.IntValue0 = DioHQ.ScavengerMarketCredits;
			Body = `XEXPAND.ExpandString(DioHQ.ScavengerMarketCredits == 1 ? default.TagStr_ScavengerMarketFreeBuy : default.TagStr_ScavengerMarketFreeBuyPlural);
		}

		NotifObj.NotificationData.Title 			= Title;
		NotifObj.NotificationData.Body 				= Body;
		NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_ScavengerMarket;

		Tuple = new class'XComLWTuple';
		Tuple.Id = 'ScavengerMarketAvaliableNotificationObject';
		Tuple.Data.Add(1);
		Tuple.Data[0].kind = XComLWTVObject;
		Tuple.Data[0].o = NotifObj;

		`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateScavengerMarketAvaliableNotif', Tuple, Tuple, ModifyGameState);

		// Retrieve edited data from tuple
		NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
								NotifObj.NotificationData.OnItemSelectedFn, 
								NotifObj.NotificationData.Title, 
								NotifObj.NotificationData.Body,
								NotifObj.NotificationData.UnitRefs,
								NotifObj.NotificationData.ImagePath,
								NotifObj.NotificationData.UIColor								
								);
	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}
}

//---------------------------------------------------------------------------------------
//				PASSIVE INCOME
//---------------------------------------------------------------------------------------
static function RefreshPassiveIncomeNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XGParamTag LocTag;
	local string PassiveIncomeString;
	local int CreditsIncome, IntelIncome, EleriumIncome;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	// HELIOS BEGIN
	NotifObj = new class'HSStrategyNotificationObject';
	NotifObj.NotificationData.Type 				= eSNT_ScavengerMarketOpen;

	DioHQ = ModDioHQ(ModifyGameState);
	if (class'DioStrategyAI'.static.GetDaysUntilPassiveIncome() == 0)
	{
		class'DioStrategyAI'.static.CalculatePassiveIncome(CreditsIncome, IntelIncome, EleriumIncome);
		if (CreditsIncome > 0 || IntelIncome > 0 || EleriumIncome > 0)
		{
			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.StrValue0 = class'UIUtilities_DioStrategy'.static.FormatMultiResourceValues(CreditsIncome, IntelIncome, EleriumIncome);
			PassiveIncomeString = `XEXPAND.ExpandString(default.TagStr_PassiveIncomeBody);

			NotifObj.NotificationData.Title 			= default.PassiveIncomeTitle;
			NotifObj.NotificationData.Body 				= PassiveIncomeString;

			Tuple = new class'XComLWTuple';
			Tuple.Id = 'PassiveIncomeNotificationObject';
			Tuple.Data.Add(1);
			Tuple.Data[0].kind = XComLWTVObject;
			Tuple.Data[0].o = NotifObj;

			`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreatePassiveIncomeNotif', Tuple, Tuple, ModifyGameState);

			// Retrieve edited data from tuple
			NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

			DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
						NotifObj.NotificationData.OnItemSelectedFn, 
						NotifObj.NotificationData.Title, 
						NotifObj.NotificationData.Body,
						NotifObj.NotificationData.UnitRefs,
						NotifObj.NotificationData.ImagePath,
						NotifObj.NotificationData.UIColor								
						);
			return;
		}
	}
	
	DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	// HELIOS END
}

//---------------------------------------------------------------------------------------
//				UNREST / ANARCHY CHANGE
//---------------------------------------------------------------------------------------
static function RefreshUnrestAnarchyChangedNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_CampaignGoal Goal;
	local XComGameState_DioCityDistrict District;
	local bool bAnyResultsToShow;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	DioHQ = ModDioHQ(ModifyGameState);
	Goal = DioHQ.GetCampaignGoal(ModifyGameState);

	// Show if anarchy changed
	bAnyResultsToShow = Goal.OverallCityUnrest != Goal.PrevTurnOverallCityUnrest;
	
	// Show if anarchy results were recorded
	if (!bAnyResultsToShow)
	{
		bAnyResultsToShow = DioHQ.PrevTurnAnarchyUnrestResults.Length > 0;
	}

	// Show if any District recorded unrest results
	if (!bAnyResultsToShow)
	{
		foreach ModifyGameState.IterateByClassType(class'XComGameState_DioCityDistrict', District)
		{
			if (District.PrevTurnUnrestResults.Length > 0)
			{
				bAnyResultsToShow = true;
				break;
			}
		}
	}

	// HELIOS BEGIN
	NotifObj = new class'HSStrategyNotificationObject';
	NotifObj.NotificationData.Type 				= eSNT_UnrestAnarchyChange;

	if (bAnyResultsToShow)
	{
		NotifObj.NotificationData.Title 			= default.AnarchyUnrestChangedTitle;
		NotifObj.NotificationData.Body 				= "";
		NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.PresentAnarchyUnrestChangePopup;

		Tuple = new class'XComLWTuple';
		Tuple.Id = 'UnrestAnarchyChanged_NotificationObject';
		Tuple.Data.Add(1);
		Tuple.Data[0].kind = XComLWTVObject;
		Tuple.Data[0].o = NotifObj;

		`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateUnrestAnarchyChangedNotif', Tuple, Tuple, ModifyGameState);

		// Retrieve edited data from tuple
		NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

		DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
			NotifObj.NotificationData.OnItemSelectedFn, 
			NotifObj.NotificationData.Title, 
			NotifObj.NotificationData.Body,
			NotifObj.NotificationData.UnitRefs,
			NotifObj.NotificationData.ImagePath,
			NotifObj.NotificationData.UIColor								
			);
	}
	else
	{
		DioHQ.RemoveNotificationByType(NotifObj.NotificationData.Type);
	}
	// HELIOS END
}

//---------------------------------------------------------------------------------------
//				PACE CHECKS
//---------------------------------------------------------------------------------------
static function RefreshPaceCheckNotifications(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation CurrentInvestigation;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	DioHQ = ModDioHQ(ModifyGameState);

	// HELIOS BEGIN
	NotifObj = new class'HSStrategyNotificationObject';

	// Check 1: engage with Spec Ops and Training within 10 turns
	if (DioHQ.CurrentTurn > 10)
	{
		if (!DioHQ.HasBlackboardFlag(class'DioStrategyAI'.const.PaceCheckFlag_SpecOps))
		{
			NotifObj.NotificationData.Type 				= eSNT_PaceWarningSpecOps;
			NotifObj.NotificationData.Title 			= default.PaceCheckSpecOpsTitle;
			NotifObj.NotificationData.Body 				= default.PaceCheckSpecOpsBody;
			NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_SpecOps;

			Tuple = new class'XComLWTuple';
			Tuple.Id = 'PaceWarning_SpecOps_NotificationObject';
			Tuple.Data.Add(1);
			Tuple.Data[0].kind = XComLWTVObject;
			Tuple.Data[0].o = NotifObj;

			`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreatePaceWarning_SpecOps_Notif', Tuple, Tuple, ModifyGameState);

			// Retrieve edited data from tuple
			NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

			DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
									NotifObj.NotificationData.OnItemSelectedFn, 
									NotifObj.NotificationData.Title, 
									NotifObj.NotificationData.Body,
									NotifObj.NotificationData.UnitRefs,
									NotifObj.NotificationData.ImagePath,
									NotifObj.NotificationData.UIColor								
									);
		}
		else
		{
			DioHQ.RemoveNotificationByType(eSNT_PaceWarningSpecOps);
		}

		if (!DioHQ.HasBlackboardFlag(class'DioStrategyAI'.const.PaceCheckFlag_Training))
		{
			NotifObj.NotificationData.Type 				= eSNT_PaceWarningTraining;
			NotifObj.NotificationData.Title 			= default.PaceCheckTrainingTitle;
			NotifObj.NotificationData.Body 				= default.PaceCheckTrainingBody;
			NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_Training;

			Tuple = new class'XComLWTuple';
			Tuple.Id = 'PaceWarning_Training_NotificationObject';
			Tuple.Data.Add(1);
			Tuple.Data[0].kind = XComLWTVObject;
			Tuple.Data[0].o = NotifObj;

			`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreatePaceWarning_SpecOps_Notif', Tuple, Tuple, ModifyGameState);

			// Retrieve edited data from tuple
			NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

			DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
									NotifObj.NotificationData.OnItemSelectedFn, 
									NotifObj.NotificationData.Title, 
									NotifObj.NotificationData.Body,
									NotifObj.NotificationData.UnitRefs,
									NotifObj.NotificationData.ImagePath,
									NotifObj.NotificationData.UIColor								
									);
		}
		else
		{
			DioHQ.RemoveNotificationByType(eSNT_PaceWarningTraining);
		}
	}

	// Check 2: Engage with Field Teams and Field Abilities before 2nd operation is complete
	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation(ModifyGameState);
	if (CurrentInvestigation.Act >= 1 && CurrentInvestigation.CompletedOperationHistory.Length >= 2)
	{
		if (!DioHQ.HasBlackboardFlag(class'DioStrategyAI'.const.PaceCheckFlag_FieldTeam))
		{
			NotifObj.NotificationData.Type 				= eSNT_PaceWarningFieldTeams;
			NotifObj.NotificationData.Title 			= default.PaceCheckFieldTeamsTitle;
			NotifObj.NotificationData.Body 				= default.PaceCheckFieldTeamsBody;
			NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_CityMap;

			Tuple = new class'XComLWTuple';
			Tuple.Id = 'PaceWarning_FieldTeamBuild_NotificationObject';
			Tuple.Data.Add(1);
			Tuple.Data[0].kind = XComLWTVObject;
			Tuple.Data[0].o = NotifObj;

			`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreatePaceWarning_FieldTeamBuild_Notif', Tuple, Tuple, ModifyGameState);

			// Retrieve edited data from tuple
			NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

			DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
									NotifObj.NotificationData.OnItemSelectedFn, 
									NotifObj.NotificationData.Title, 
									NotifObj.NotificationData.Body,
									NotifObj.NotificationData.UnitRefs,
									NotifObj.NotificationData.ImagePath,
									NotifObj.NotificationData.UIColor								
									);
		}
		else
		{
			DioHQ.RemoveNotificationByType(eSNT_PaceWarningFieldTeams);
		}

		if (!DioHQ.HasBlackboardFlag(class'DioStrategyAI'.const.PaceCheckFlag_FieldTeamAbility))
		{
			NotifObj.NotificationData.Type 				= eSNT_PaceWarningFieldTeamAbilities;
			NotifObj.NotificationData.Title 			= default.PaceCheckFieldTeamAbilitiesTitle;
			NotifObj.NotificationData.Body 				= default.PaceCheckFieldTeamAbilitiesBody;
			NotifObj.NotificationData.OnItemSelectedFn = class'UIUtilities_DioStrategy'.static.Hotlink_CityMap;

			Tuple = new class'XComLWTuple';
			Tuple.Id = 'PaceWarning_FieldTeamAbility_NotificationObject';
			Tuple.Data.Add(1);
			Tuple.Data[0].kind = XComLWTVObject;
			Tuple.Data[0].o = NotifObj;

			`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreatePaceWarning_FieldTeamAbility_Notif', Tuple, Tuple, ModifyGameState);

			// Retrieve edited data from tuple
			NotifObj = HSStrategyNotificationObject(Tuple.Data[0].o);

			DioHQ.AddNotification(	NotifObj.NotificationData.Type, 
									NotifObj.NotificationData.OnItemSelectedFn, 
									NotifObj.NotificationData.Title, 
									NotifObj.NotificationData.Body,
									NotifObj.NotificationData.UnitRefs,
									NotifObj.NotificationData.ImagePath,
									NotifObj.NotificationData.UIColor								
									);
		}
		else
		{
			DioHQ.RemoveNotificationByType(eSNT_PaceWarningFieldTeamAbilities);
		}
		// HELIOS END
	}
}

//---------------------------------------------------------------------------------------
//				HUD ATTENTION CHECKS
//---------------------------------------------------------------------------------------
static function bool APCNeedsAttention()
{
	if (`STRATPRES.CityMapAttentionCount > 0)
	{
		return true;
	}

	return class'DioStrategyAI'.static.GetCriticalMissionWorker() != none;
}

//---------------------------------------------------------------------------------------
static function bool AssemblyNeedsAttention()
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = `DIOHQ;

	if (`STRATPRES.ResearchAttentionCount > 0)
	{
		return true;
	}

	return DioHQ.HasNotificationOfType(eSNT_AssemblyIdle) ||
		DioHQ.HasNotificationOfType(eSNT_AssemblyComplete) ||
		DioHQ.HasNotificationOfType(eSNT_TutorialAssemblyAvailable);
}

//---------------------------------------------------------------------------------------
static function bool SpecOpsNeedsAttention()
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = `DIOHQ;

	return DioHQ.HasNotificationOfType(eSNT_SpecOpsComplete) ||
		DioHQ.HasNotificationOfType(eSNT_SpecOpsUnlocked) ||
		DioHQ.HasNotificationOfType(eSNT_TutorialSpecOpsAvailable);
}

//---------------------------------------------------------------------------------------
static function bool TrainingNeedsAttention()
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = `DIOHQ;

	return DioHQ.HasNotificationOfType(eSNT_TrainingComplete) ||
		DioHQ.HasNotificationOfType(eSNT_TutorialTrainingAvailable);
}

//---------------------------------------------------------------------------------------
//				TUTORIAL NOTIFICATIONS (all)
//---------------------------------------------------------------------------------------
// EVALUATE: Should we allow mods to change the tutorial notifications too?
static function RefreshTutorialNotifications(XComGameState ModifyGameState)
{
	local XComGameStateHistory History;
	local XComGameState_CampaignSettings SettingsState;
	local XComGameState_HeadquartersDio DioHQ;

	History = `XCOMHISTORY;
	SettingsState = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	if (SettingsState == none)
	{
		return;
	}

	SettingsState = XComGameState_CampaignSettings(ModifyGameState.ModifyStateObject(class'XComGameState_CampaignSettings', SettingsState.ObjectID));
	DioHQ = ModDioHQ(ModifyGameState);

	if (`TutorialEnabled == false)
	{
		DioHQ.RemoveNotificationByType(eSNT_TutorialAssemblyAvailable);
		DioHQ.RemoveNotificationByType(eSNT_TutorialSpecOpsAvailable);
		DioHQ.RemoveNotificationByType(eSNT_TutorialTrainingAvailable);
		DioHQ.RemoveNotificationByType(eSNT_NormalScar);
		DioHQ.RemoveNotificationByType(eSNT_TutorialNewAndroid);
		return;
	}

	// Assembly now online
	if (!class'DioStrategyTutorialHelper'.static.IsAssemblyTutorialLocked() && 
		SettingsState.VisitedScreens.Find('UIDIOAssemblyScreen') == INDEX_NONE)
	{
		DioHQ.RemoveNotificationByType(eSNT_AssemblyIdle);
		DioHQ.AddNotification(eSNT_TutorialAssemblyAvailable, class'UIUtilities_DioStrategy'.static.Hotlink_Research, default.TutorialAssemblyAvailableTitle, default.TutorialAssemblyAvailableBody);
	}
	else
	{
		DioHQ.RemoveNotificationByType(eSNT_TutorialAssemblyAvailable);
	}

	// Spec Ops now online
	if (!class'DioStrategyTutorialHelper'.static.IsSpecOpsTutorialLocked() &&
		SettingsState.VisitedScreens.Find('UISpecOpsScreen') == INDEX_NONE)
	{
		DioHQ.AddNotification(eSNT_TutorialSpecOpsAvailable, class'UIUtilities_DioStrategy'.static.Hotlink_SpecOps, default.TutorialSpecOpsAvailableTitle, default.TutorialSpecOpsAvailableBody);
	}
	else
	{
		DioHQ.RemoveNotificationByType(eSNT_TutorialSpecOpsAvailable);
	}

	// Training now online
	if (!class'DioStrategyTutorialHelper'.static.IsTrainingTutorialLocked() &&
		SettingsState.VisitedScreens.Find('UIDIOTrainingScreen') == INDEX_NONE)
	{
		DioHQ.AddNotification(eSNT_TutorialTrainingAvailable, class'UIUtilities_DioStrategy'.static.Hotlink_Training, default.TutorialTrainingAvailableTitle, default.TutorialTrainingAvailableBody);
	}
	else
	{
		DioHQ.RemoveNotificationByType(eSNT_TutorialTrainingAvailable);
	}

	// First Android
	if (SettingsState.SeenTutorials.Find('StrategyTutorial_DiscoverAndroids') == INDEX_NONE &&
		DioHQ.Androids.Length > 0)
	{

		DioHQ.AddNotification(eSNT_TutorialNewAndroid, class'UIUtilities_DioStrategy'.static.Hotlink_ArmoryUnit, default.TutorialNewAndroidTitle, , DioHQ.Androids);
	}
	else
	{
		DioHQ.RemoveNotificationByType(eSNT_TutorialNewAndroid);
	}
}
