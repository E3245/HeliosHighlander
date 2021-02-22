//---------------------------------------------------------------------------------------
//  FILE:    	UIUtilities_DioStrategy
//  AUTHOR:  	dmcdonough  --  10/12/2018
//  PURPOSE: 	Static helper functions for Dio Strategy Layer.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIUtilities_DioStrategy extends Object
	dependson(UIDialogueBox);

// Universal loc strings
var localized string strTerm_Abilities;
var localized string strTerm_Actions;
var localized string strTerm_Ammo;
var localized string strTerm_Ammunition;
var localized string strTerm_Androids;
var localized string strTerm_APC;
var localized string strTerm_APCBusy;
var localized string strTerm_APCShort;
var localized string strTerm_APC_Long;
var localized string strTerm_Armor;
var localized string strTerm_Assign;
var localized string strTerm_Available;
var localized string strTerm_Breach;
var localized string strTerm_BuildFieldTeam;
var localized string strTerm_Buy;
var localized string strTerm_Cancel;
var localized string strTerm_City;
var localized string strTerm_City31;
var localized string strTerm_Complete;
var localized string strTerm_Conditions;
var localized string strTerm_Confirm;
var localized string strTerm_Continue;
var localized string strTerm_Cooldown;
var localized string strTerm_Cost;
var localized string strTerm_Credits;
var localized string strTerm_Critical;
var localized string strTerm_Day;
var localized string strTerm_Days;
var localized string strTerm_DayProper;
var localized string strTerm_DaysProper;
var localized string strTerm_DayRemaining;
var localized string strTerm_DaysRemaining;
var localized string strTerm_Districts;
var localized string strTerm_Edit;
var localized string strTerm_Effects;
var localized string strTerm_Elerium;
var localized string strTerm_Emergency;
var localized string strTerm_Expired;
var localized string strTerm_Free;
var localized string strTerm_FreeFieldTeam;
var localized string strTerm_FreeFieldTeamPlural;
var localized string strTerm_Funding;
var localized string strTerm_Grenade;
var localized string strTerm_InProgress;
var localized string strTerm_Intel;
var localized string strTerm_Inventory;
var localized string strTerm_Investigate;
var localized string strTerm_Item;
var localized string strTerm_ItemPlural;
var localized string strTerm_LeadMission;
var localized string strTerm_Legend;
var localized string strTerm_Loadout;
var localized string strTerm_Locked;
var localized string strTerm_Lost;
var localized string strTerm_Leverage;
var localized string strTerm_Manage;
var localized string strTerm_Mission;
var localized string strTerm_Missions;
var localized string strTerm_New;
var localized string strTerm_Network;
var localized string strTerm_None;
var localized string strTerm_OnAPC;
var localized string strTerm_OnScene;
var localized string strTerm_Operation;
var localized string strTerm_Operative;
var localized string strTerm_Operatives;
var localized string strTerm_Opinion;
var localized string strTerm_Owned;
var localized string strTerm_Promotions;
var localized string strTerm_Rank;
var localized string strTerm_Ready;
var localized string strTerm_Recommended;
var localized string strTerm_Reassign;
var localized string strTerm_Remove;
var localized string strTerm_Required;
var localized string strTerm_Respond;
var localized string strTerm_ReturnHome;
var localized string strTerm_Rewards;
var localized string strTerm_Roster;
var localized string strTerm_RunMission;
var localized string strTerm_SendAPC;
var localized string strTerm_Scars;
var localized string strTerm_Scar;
var localized string strTerm_Shifts;
var localized string strTerm_ShiftsRemaining;
var localized string strTerm_Situation;
var localized string strTerm_Situations;
var localized string strTerm_Squad;
var localized string strTerm_Start;
var localized string strTerm_Stats;
var localized string strTerm_Status;
var localized string strTerm_Targets;
var localized string strTerm_Tier;
var localized string strTerm_Train;
var localized string strTerm_Trust;
var localized string strTerm_Unassigned;
var localized string strTerm_Units;
var localized string strTerm_Unknown;
var localized string strTerm_UnknownSymbols;
var localized string strTerm_Unlock;
var localized string strTerm_Unmask;
var localized string strTerm_Unrest;
var localized string strTerm_Utility;
var localized string strTerm_Weapons;
var localized string strTerm_XCOM;

// Status strings
var localized string strStatus_NotEnoughCredits;
var localized string strStatus_NotEnoughIntel;
var localized string strStatus_NotEnoughElerium;
var localized string strStatus_NotEnoughResourcesGeneric;
var localized string strStatus_WorkerSlotsFull;
var localized string strStatus_NotStarted;
var localized string strStatus_APCFull;
var localized string strStatus_CurrentlyOnDuty;
var localized string strStatus_CurrentlyOnAPC;
var localized string strStatus_ActionAlreadyStarted;
var localized string strStatus_TargetMasked;
var localized string strStatus_APCBusy;
var localized string strStatus_APCShorthanded;
var localized string strStatus_NeedToSelectUnit;
var localized string strStatus_ItemUnavailableTo;

var localized string EmptyAndroidBayLabel;
var localized string DestroyedAndroidLabel;
var localized string DestroyedAndroidDesc;
var localized string AllFieldTeamsPrereq;
var localized string ViewMetaContentLabel;

// Unrest/Anarchy Report strings
var localized string UnrestAnarchyPopupTitle;
var localized string TagStr_CityAnarchyRaised;
var localized string TagStr_CityAnarchyLowered;
var localized string CityAnarchyRaiseDesc;

// LocParam strings
var localized string TagString_APLabel;
var localized string TagString_APAvailableLabel;
var localized string TagString_AndroidModelName;
var localized string TagStr_APCRespondingStatus;
var localized string TagStr_APCShorthandedStatus;
var localized string TagStr_APCOnMissionStatus;
var localized string TagStr_Status;
var localized string TagStr_TrainStatus;
var localized string TagStr_AbridgedTrainStatus;
var localized string TagStr_UnitCompletedTraining;
var localized string TagStr_TrainLimit;
var localized string TagStr_SpecOpsStatus;
var localized string TagStr_AbridgedSpecOpsStatus;
var localized string TagStr_UnitCompletedSpecOps;
var localized string TagStr_SpecOpsLimit;
var localized string TagStr_ResearchStatus;
var localized string TagStr_AbridgedResearchStatus;
var localized string TagStr_AbridgedEmptyResearchStatus;
var localized string TagStr_ResearchEmptyStatus;
var localized string TagStr_AssemblyComplete;
var localized string TagStr_ResearchLimit;
var localized string TagStr_DurationTurns;
var localized string TagStr_AvailableTurns;
var localized string TagStr_PausedTurns;
var localized string TagStr_InProgressTurns;
var localized string TagStr_FundingStatus;
var localized string TagStr_DistrictFullStats;
var localized string TagStr_WorkerSlots;
var localized string TagStr_MissionDifficulty;
var localized string TagStr_DefaultPrereq;
var localized string TagStr_ResearchPrereq;
var localized string TagStr_NewStoreItem;
var localized string TagStr_UpgradeItemTemplate;
var localized string TagStr_RegionBonus;
var localized string TagStr_RegionMembers;
var localized string TagStr_MarketDiscountFromSpecOp;
var localized string TagStr_CapturedEnemyRewardInfo;
var localized string TagStr_CivilianDeathsPenaltyInfo;
var localized string TagStr_TotalFieldTeamsPrereq;
var localized string TagStr_FieldTeamsAtRankPrereq;
var localized string TagStr_AllFieldTeamsAtRankPrereq;
var localized string TagStr_FieldTeamTypesAtRankPrereq;
var localized string TagStr_CaptureConspiratorSubobjectiveRewardDesc;
var localized string TagStr_RescueHostageSubobjectiveRewardDesc;
var localized string TagStr_CollectEvidenceSubobjectiveRewardDesc;
var localized string TagStr_StatIncrease;

//Misc Localization
var localized string DefaultAbilityTrainingEffectString;
var localized string DefaultClassStatTrainingDisplayName;
var localized string DefaultClassStatTrainingDescription;

var localized array<string> FieldTeamNicknames;

delegate static bool IsSoldierEligible(XComGameState_Unit Soldier);

// helper accessors for uci calls (to avoid spamming logs with tons of none references when casts fail)
//---------------------------------------------------------------------------------------
static function XComStrategyPresentationLayer GetStrategyPres()
{
	local XComHeadquartersGame HeadquartersGame;

	HeadquartersGame = XComHeadquartersGame(class'XComEngine'.static.GetCurrentWorldInfo().Game);
	return HeadquartersGame != none ? XComStrategyPresentationLayer(XComHeadquartersController(HeadquartersGame.PlayerController).Pres) : none;
}

//---------------------------------------------------------------------------------------
static function XComGameState_HeadquartersDio GetDioHQ(optional bool AllowNULL)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	DioHQ = XComGameState_HeadquartersDio(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio', AllowNULL));
	return DioHQ;
}

//---------------------------------------------------------------------------------------
static function XComGameState_DioCity GetDioCity(optional bool AllowNULL)
{
	local XComGameState_DioCity DioCity;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	DioCity = XComGameState_DioCity(History.GetSingleGameStateObjectForClass(class'XComGameState_DioCity', AllowNULL));
	return DioCity;
}

//---------------------------------------------------------------------------------------
static function XComGameState_MissionSite GetCurrentMission()
{
	return XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(`DIOHQ.MissionRef.ObjectID));
}

//---------------------------------------------------------------------------------------
static function GeneratedMissionData GetCurrentGeneratedMission()
{
	return GetCurrentMission().GeneratedMission;
}

//---------------------------------------------------------------------------------------
simulated static function bool CycleSoldiers(int Direction, StateObjectReference SoldierRef, delegate<IsSoldierEligible> CheckEligibilityFunc, out StateObjectReference NewSoldier)
{
	local int Index, Counter, i;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local array<StateObjectReference> squadList, androidList;

	DioHQ = GetDioHQ();
	History = `XCOMHISTORY;
	squadList = DioHQ.Squad;
	squadList.Sort(SortSquadList);
	androidList = DioHQ.Androids;

	for (i = 0; i < squadList.Length + androidList.Length; i++)
	{
		if (i < squadList.Length)
		{
			if (squadList[i] == SoldierRef)
			{
				Index = i;
			}
		}
		else
		{
			if (androidList[i - squadList.Length] == SoldierRef)
			{
				Index = i;
			}
		}
	}	

	// Loop through the crew array looking for the next suitable soldier
	while (Counter < squadList.Length + androidList.Length)
	{
		Index += Direction;
		Counter++;

		if (Index >= squadList.Length + androidList.Length)
			Index = 0;
		else if (Index < 0)
			Index = squadList.Length + androidList.Length - 1;

		if (Index < squadList.Length)
		{
			Unit = XComGameState_Unit(History.GetGameStateForObjectID(squadList[Index].ObjectID));
		}
		else
		{
			Unit = XComGameState_Unit(History.GetGameStateForObjectID(androidList[Index - squadList.Length].ObjectID));
		}

		// If we've looped around to the same unit as the one passed in, that means we have no valid soldiers to switch to, return false
		if (Unit.ObjectID == SoldierRef.ObjectID)
		{
			return false;
		}
		else if (CheckEligibilityFunc(Unit))
		{
			NewSoldier = Unit.GetReference();
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
simulated static function bool CycleAPC(int Direction, StateObjectReference SoldierRef, delegate<IsSoldierEligible> CheckEligibilityFunc, out StateObjectReference NewSoldier)
{
	local int Index, Counter, i;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local array<StateObjectReference> squadList, androidList;

	DioHQ = GetDioHQ();
	History = `XCOMHISTORY;
	squadList = DioHQ.APCRoster;
	androidList = DioHQ.Androids;

	for (i = 0; i < squadList.Length + androidList.Length; i++)
	{
		if (i < squadList.Length)
		{
			if (squadList[i] == SoldierRef)
			{
				Index = i;
			}
		}
		else
		{
			if (androidList[i - squadList.Length] == SoldierRef)
			{
				Index = i;
			}
		}
	}

	// Loop through the crew array looking for the next suitable soldier
	while (Counter < squadList.Length + androidList.Length)
	{
		Index += Direction;
		Counter++;

		if (Index >= squadList.Length + androidList.Length)
			Index = 0;
		else if (Index < 0)
			Index = squadList.Length + androidList.Length - 1;

		if (Index < squadList.Length)
		{
			Unit = XComGameState_Unit(History.GetGameStateForObjectID(squadList[Index].ObjectID));
		}
		else
		{
			Unit = XComGameState_Unit(History.GetGameStateForObjectID(androidList[Index - squadList.Length].ObjectID));
		}

		// If we've looped around to the same unit as the one passed in, that means we have no valid soldiers to switch to, return false
		if (Unit.ObjectID == SoldierRef.ObjectID)
		{
			return false;
		}
		else if (CheckEligibilityFunc(Unit))
		{
			NewSoldier = Unit.GetReference();
			return true;
		}
	}

	return false;
}

simulated function int SortSquadList(StateObjectReference TargetA, StateObjectReference TargetB)
{
	local XComGameStateHistory History;
	local XComGameState_Unit WorkerA, WorkerB;
	local int				cameraA, cameraB;

	History = `XCOMHISTORY;
	WorkerA = XComGameState_Unit(History.GetGameStateForObjectID(TargetA.ObjectID));
	WorkerB = XComGameState_Unit(History.GetGameStateForObjectID(TargetB.ObjectID));

	cameraA = GetCameraValue(WorkerA.GetSoldierClassTemplate().RequiredCharacterClass);
	cameraB = GetCameraValue(WorkerB.GetSoldierClassTemplate().RequiredCharacterClass);

	return cameraB - cameraA;
}

simulated function int GetCameraValue(name CharacterClass)
{
	switch (CharacterClass)
	{
	case 'XComInquisitor':
		return 1;
	case 'XComDemoExpert':
		return 2;
	case 'XComPsion':
		return 3;
	case 'XComRanger':
		return 4;
	case 'XComMedic':
		return 5;
	case 'XComWarden':
		return 6;
	case 'XComEnvoy':
		return 7;
	case 'XComGunslinger':
		return 8;
	case 'XComOperator':
		return 9;
	case 'XComHellion':
		return 10;
	case 'XComBreaker':
		return 11;
	}

	return 99;
}

//---------------------------------------------------------------------------------------
// Gets name of weapon or its upgrade, if any exist
static function string GetUnitWeaponFriendlyNameNoStats(XComGameState_Item WeaponItem)
{
	local X2WeaponTemplate WeaponTemplate;
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local X2WeaponUpgradeTemplate UpgradeTemplate;

	WeaponUpgrades = WeaponItem.GetMyWeaponUpgradeTemplates();
	WeaponTemplate = X2WeaponTemplate(WeaponItem.GetMyTemplate());
	if (!WeaponTemplate.bIsEpic)
	{
		foreach WeaponUpgrades(UpgradeTemplate)
		{
			switch (UpgradeTemplate.DataName)
			{
			case 'EnhancedARsUpgrade':
			case 'MastercraftedARsUpgrade':
			case 'EnhancedSMGsUpgrade':
			case 'MastercraftedSMGsUpgrade':
			case 'EnhancedShotgunsUpgrade':
			case 'MastercraftedShotgunsUpgrade':
			case 'EnhancedPistolsUpgrade':
			case 'MastercraftedPistolsUpgrade':
				return UpgradeTemplate.GetItemFriendlyNameNoStats();
			}
		}
	}

	// No upgrades, base weapon name
	return WeaponTemplate.GetItemFriendlyNameNoStats();
}

//---------------------------------------------------------------------------------------
static function string GetUnitDutyStatusString(XComGameState_Unit Unit, optional out EUIState UIState)
{
	local XComGameState_StrategyAction UnitAssignedAction;
	local XGParamTag LocTag;
	local string FormattedString;

	if (Unit == none)
	{
		return "ERROR: Unit not valid";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

	// Assigned to an action
	UnitAssignedAction = Unit.GetAssignedAction();
	if (UnitAssignedAction != none)
	{
		UIState = eUIState_Good;
		if (UnitAssignedAction.GetMyTemplateName() == 'HQAction_Train')
		{
			LocTag.StrValue0 = BuildStatusString_Training(UnitAssignedAction.GetReference());
		}
		else if (UnitAssignedAction.GetMyTemplateName() == 'HQAction_SpecOps')
		{
			LocTag.StrValue0 = BuildStatusString_SpecOps(UnitAssignedAction.GetReference());
		}
		else if (UnitAssignedAction.GetMyTemplateName() == 'HQAction_Research')
		{
			LocTag.StrValue0 = BuildStatusString_Research(UnitAssignedAction.GetReference());
		}
	}
	else
	{
		// On APC
		if (`DIOHQ.APCRoster.Find('ObjectID', Unit.ObjectID) != INDEX_NONE)
		{
			UIState = eUIState_Good;
			LocTag.StrValue0 = default.strTerm_OnAPC;
		}
		else
		{
			// Unit not assigned to anything
			UIState = eUIState_Warning;
			LocTag.StrValue0 = default.strTerm_Unassigned;
		}
	}

	FormattedString = `XEXPAND.ExpandString(`DIO_UI.default.TagStr_Status);
	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string GetAbridgedUnitStatusString(XComGameState_Unit Unit, optional out EUIState UIState)
{
	local XComGameState_StrategyAction UnitAssignedAction;

	if (Unit == none)
	{
		return "ERROR: Unit not valid";
	}

	// Assigned to an action
	UnitAssignedAction = Unit.GetAssignedAction();
	if (UnitAssignedAction != none)
	{
		UIState = eUIState_Good;
		if (UnitAssignedAction.GetMyTemplateName() == 'HQAction_Train')
		{
			return BuildAbridgedStatusString_Training(UnitAssignedAction.GetReference());
		}
		else if (UnitAssignedAction.GetMyTemplateName() == 'HQAction_SpecOps')
		{
			return BuildAbridgedStatusString_SpecOps(UnitAssignedAction.GetReference());
		}
		else if (UnitAssignedAction.GetMyTemplateName() == 'HQAction_Research')
		{
			return BuildAbridgedStatusString_Research(UnitAssignedAction.GetReference());
		}
	}
	else
	{
		// On APC
		if (`DIOHQ.APCRoster.Find('ObjectID', Unit.ObjectID) != INDEX_NONE)
		{
			UIState = eUIState_Good;
			return default.strTerm_OnAPC;
		}
		else
		{
			// Unit not assigned to anything
			UIState = eUIState_Warning;
			return default.strTerm_Unassigned;
		}
	}

	return default.strTerm_Unassigned;
}

//---------------------------------------------------------------------------------------
// Short title of a duty assignment
static function string GetDutyNameString(name DutyAssignment)
{
	local X2DioStrategyActionTemplate ActionTemplate;

	switch (DutyAssignment)
	{
	case 'APC':
		return default.strTerm_APC;
		break;
	case 'SpecOps':
	case 'Train':
	case 'Research':
		ActionTemplate = class'DioStrategyAI'.static.GetAssignmentActionTemplate(DutyAssignment);
		if (ActionTemplate != none)
		{
			return ActionTemplate.Summary;
			break;
		}
	}

	return default.strTerm_Unassigned;
}

//---------------------------------------------------------------------------------------
static function bool IsUnitAssignedAnyDuty(XComGameState_Unit Unit)
{
	local XComGameState_StrategyAction UnitAssignedAction;

	if( Unit == none )
	{
		return false;
	}

	UnitAssignedAction = Unit.GetAssignedAction();
	if( UnitAssignedAction != none )
	{
		return true;
	}
	else
	{
		// On APC
		if( `DIOHQ.APCRoster.Find('ObjectID', Unit.ObjectID) != INDEX_NONE )
		{
			return true;
		}
	}
	return false; 
}

//---------------------------------------------------------------------------------------
static function int GetUnitDutyPriority(XComGameState_Unit Unit)
{
	local XComGameState_StrategyAction UnitAssignedAction;

	if( Unit == none )
	{
		return -1; 
	}
	// Assigned to an action
	UnitAssignedAction = Unit.GetAssignedAction();
	if( UnitAssignedAction != none )
	{
		if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_Train' )
		{
			return 40;
		}
		else if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_SpecOps' )
		{
			return 30; 
		}
		else if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_Research' )
		{
			return 20;
		}
	}
	else
	{
		// On APC
		if( `DIOHQ.APCRoster.Find('ObjectID', Unit.ObjectID) != INDEX_NONE )
		{
			return 10;
		}
		else
		{
			// Unit not assigned to anything
			return 0; 
		}
	}
	return -1;
}

//---------------------------------------------------------------------------------------
static function string GetUnitDutyIconString(XComGameState_Unit Unit)
{
	local XComGameState_StrategyAction UnitAssignedAction;

	if( Unit == none )
	{
		return "ERROR: Unit not valid";
	}
	// Assigned to an action
	UnitAssignedAction = Unit.GetAssignedAction();
	if( UnitAssignedAction != none )
	{
		if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_Train' )
		{
			return class'UIUtilities_Image'.const.CityMapAssignment_Training;
		}
		else if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_SpecOps' )
		{
			return class'UIUtilities_Image'.const.CityMapAssignment_SpecOps;
		}
		else if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_Research' )
		{
			return class'UIUtilities_Image'.const.CityMapAssignment_Assembly;
		}
	}
	else
	{
		// On APC
		if( `DIOHQ.APCRoster.Find('ObjectID', Unit.ObjectID) != INDEX_NONE )
		{
			return class'UIUtilities_Image'.const.CityMapAssignment_City; 
		}
		else
		{
			// Unit not assigned to anything
			return ""; 
		}
	}
	return "";
}
//---------------------------------------------------------------------------------------
static function string GetUnitDutyIconColor(XComGameState_Unit Unit)
{
	local XComGameState_StrategyAction UnitAssignedAction;

	if( Unit == none )
	{
		return class'UIUtilities_Colors'.const.INTERACTIVE_SELECTED_BLUE_BRIGHT_HTML_COLOR;
	}
	// Assigned to an action
	UnitAssignedAction = Unit.GetAssignedAction();
	if( UnitAssignedAction != none )
	{
		if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_Train' )
		{
			return class'UIUtilities_Colors'.const.DIO_GREEN_LIGHT_TRAINING;
		}
		else if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_SpecOps' )
		{
			return class'UIUtilities_Colors'.const.DIO_YELLOW_LIGHT_SPEC_OPS;
		}
		else if( UnitAssignedAction.GetMyTemplateName() == 'HQAction_Research' )
		{
			return class'UIUtilities_Colors'.const.DIO_BLUE_LIGHT_ASSEMBLY;
		}
	}
	else
	{
		// On APC
		if( `DIOHQ.APCRoster.Find('ObjectID', Unit.ObjectID) != INDEX_NONE )
		{
			return class'UIUtilities_Colors'.const.DIO_PURPLE_LIGHT_CITY_MAP;
		}
		else
		{
			// Unit not assigned to anything
			return class'UIUtilities_Colors'.const.INTERACTIVE_SELECTED_BLUE_BRIGHT_HTML_COLOR;
		}
	}
	return class'UIUtilities_Colors'.const.DARK_GRAY_HTML_COLOR;
}

//---------------------------------------------------------------------------------------
static function string BuildUnitCompletedTrainingString(XComGameState_Unit Unit, StateObjectReference TrainingActionRef)
{
	local string FormattedString;
	local XComGameState_StrategyAction Action;
	local X2DioTrainingProgramTemplate TrainingTemplate;
	local XGParamTag LocTag;

	if (Unit == none)
	{
		return "";
	}
	Action = XComGameState_StrategyAction(`XCOMHISTORY.GetGameStateForObjectID(TrainingActionRef.ObjectID));
	if (Action == none)
	{
		return "";
	}
	TrainingTemplate = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Action.TargetName));
	if (TrainingTemplate == none)
	{
		return "";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = Unit.GetNickName(true);
	LocTag.StrValue1 = TrainingTemplate.GetDisplayNameString();
	FormattedString = `XEXPAND.ExpandString(default.TagStr_UnitCompletedTraining);

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string BuildUnitCompletedSpecOpsString(XComGameState_Unit Unit, StateObjectReference TrainingActionRef)
{
	local string FormattedString;
	local XComGameState_StrategyAction Action;
	local X2DioSpecOpsTemplate SpecOpsTemplate;
	local XGParamTag LocTag;

	if (Unit == none)
	{
		return "";
	}
	Action = XComGameState_StrategyAction(`XCOMHISTORY.GetGameStateForObjectID(TrainingActionRef.ObjectID));
	if (Action == none)
	{
		return "";
	}
	SpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Action.TargetName));
	if (SpecOpsTemplate == none)
	{
		return "";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = Unit.GetNickName(true);
	LocTag.StrValue1 = SpecOpsTemplate.DisplayName;
	FormattedString = `XEXPAND.ExpandString(default.TagStr_UnitCompletedSpecOps);

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string BuildStatusString_SpecOps(StateObjectReference ActionRef, optional bool bSuccess = true)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyAction Action;
	local X2DioSpecOpsTemplate SpecOpsTemplate;
	local string FinalString;
	local XGParamTag LocTag;

	History = `XCOMHISTORY;

	Action = XComGameState_StrategyAction(History.GetGameStateForObjectID(ActionRef.ObjectID));
	`assert(Action != none);

	SpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Action.TargetName));
	if (SpecOpsTemplate == none)
	{
		return "UNKNOWN SPEC OPS";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = SpecOpsTemplate.DisplayName;
	LocTag.StrValue1 = FormatTimeIcon(Action.GetTurnsUntilComplete(), 24, -3);
	FinalString = `XEXPAND.ExpandString(`DIO_UI.default.TagStr_SpecOpsStatus);

	return FinalString;
}

//---------------------------------------------------------------------------------------
static function string BuildAbridgedStatusString_SpecOps(StateObjectReference ActionRef, optional bool bSuccess = true)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyAction Action;
	local X2DioSpecOpsTemplate SpecOpsTemplate;
	local string FinalString;
	local XGParamTag LocTag;

	History = `XCOMHISTORY;

	Action = XComGameState_StrategyAction(History.GetGameStateForObjectID(ActionRef.ObjectID));
	`assert(Action != none);

	SpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Action.TargetName));
	if (SpecOpsTemplate == none)
	{
		return "UNKNOWN SPEC OPS";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FormatTimeIcon(Action.GetTurnsUntilComplete(), 24, -3);
	FinalString = `XEXPAND.ExpandString(`DIO_UI.default.TagStr_AbridgedSpecOpsStatus);

	return FinalString;
}

//---------------------------------------------------------------------------------------
static function string BuildStatusString_Training(StateObjectReference ActionRef, optional bool bSuccess = true)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyAction Action;
	local X2DioTrainingProgramTemplate TrainingProgram;
	local string FinalString;
	local XGParamTag LocTag;

	History = `XCOMHISTORY;
	
	Action = XComGameState_StrategyAction(History.GetGameStateForObjectID(ActionRef.ObjectID));
	`assert(Action != none);

	TrainingProgram = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Action.TargetName));
	if (TrainingProgram == none)
	{
		return class'UIDIOTrainingScreen'.default.ScreenTitle;
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = TrainingProgram.DisplayName;
	LocTag.StrValue1 = FormatTimeIcon(Action.GetTurnsUntilComplete(), 24, -3);
	FinalString = `XEXPAND.ExpandString(`DIO_UI.default.TagStr_TrainStatus);

	return FinalString;
}

//---------------------------------------------------------------------------------------
static function string BuildAbridgedStatusString_Training(StateObjectReference ActionRef, optional bool bSuccess = true)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyAction Action;
	local X2DioTrainingProgramTemplate TrainingProgram;
	local string FinalString;
	local XGParamTag LocTag;

	History = `XCOMHISTORY;

	Action = XComGameState_StrategyAction(History.GetGameStateForObjectID(ActionRef.ObjectID));
	`assert(Action != none);

	TrainingProgram = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Action.TargetName));
	if (TrainingProgram == none)
	{
		return class'UIDIOTrainingScreen'.default.ScreenTitle;
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FormatTimeIcon(Action.GetTurnsUntilComplete(), 24, -3);
	FinalString = `XEXPAND.ExpandString(`DIO_UI.default.TagStr_AbridgedTrainStatus);

	return FinalString;
}

//---------------------------------------------------------------------------------------
static function string BuildCompletedResearchString(StateObjectReference ResearchRef)
{
	local XComGameState_DioResearch Research;
	local string FormattedString;
	local XGParamTag LocTag;

	Research = XComGameState_DioResearch(`XCOMHISTORY.GetGameStateForObjectID(ResearchRef.ObjectID));
	if (Research == none)
	{
		return "";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = Research.GetMyTemplate().DisplayName;
	FormattedString = `XEXPAND.ExpandString(default.TagStr_AssemblyComplete);

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string BuildStatusString_Research(StateObjectReference ActionRef, optional bool bSuccess = true)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyAction Action;
	local XComGameState_DioResearch Research;
	local string FinalString;
	local XGParamTag LocTag;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;
	
	Action = XComGameState_StrategyAction(History.GetGameStateForObjectID(ActionRef.ObjectID));
	`assert(Action != none);

	if (DioHQ.ActiveResearchRef.ObjectID <= 0)
	{
		return default.TagStr_ResearchEmptyStatus;
	}
	else
	{
		Research = XComGameState_DioResearch(History.GetGameStateForObjectID(DioHQ.ActiveResearchRef.ObjectID));
		if (Research == none)
		{
			`RedScreen("BuildStatusString_Research: DioHQ.ActiveResearchRef a DioResearch object @gameplay");
			return FinalString;
		}

		LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		LocTag.StrValue0 = Research.GetMyTemplate().DisplayName;
		LocTag.StrValue1 = FormatTimeIcon(Research.GetTurnsRemaining(), 24, -3);
		FinalString = `XEXPAND.ExpandString(default.TagStr_ResearchStatus);

		return FinalString;
	}
}

//---------------------------------------------------------------------------------------
static function string BuildAbridgedStatusString_Research(StateObjectReference ActionRef, optional bool bSuccess = true)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyAction Action;
	local XComGameState_DioResearch Research;
	local string FinalString;
	local XGParamTag LocTag;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	Action = XComGameState_StrategyAction(History.GetGameStateForObjectID(ActionRef.ObjectID));
	`assert(Action != none);

	if (DioHQ.ActiveResearchRef.ObjectID <= 0)
	{
		return default.TagStr_AbridgedEmptyResearchStatus;
	}
	else
	{
		Research = XComGameState_DioResearch(History.GetGameStateForObjectID(DioHQ.ActiveResearchRef.ObjectID));
		if (Research == none)
		{
			`RedScreen("BuildStatusString_Research: DioHQ.ActiveResearchRef a DioResearch object @gameplay");
			return FinalString;
		}

		LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		LocTag.StrValue0 = FormatTimeIcon(Research.GetTurnsRemaining(), 24, -3);
		FinalString = `XEXPAND.ExpandString(default.TagStr_AbridgedResearchStatus);

		return FinalString;
	}
}

//---------------------------------------------------------------------------------------
//				ARMORY & ITEMS
//---------------------------------------------------------------------------------------
static function string GetItemUnavailableToClassesString(X2ItemTemplate ItemTemplate)
{
	local XComGameStateHistory History;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local XComGameState_Unit Unit;
	local array<StateObjectReference> AllUnitRefs;
	local array<string> ExcludingSoldierClassNames;
	local string FullString, ClassListString;
	local int i;

	History = `XCOMHISTORY;
	`DIOHQ.GetAllUnitRefs(AllUnitRefs);

	for (i = 0; i < AllUnitRefs.Length; ++i)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(AllUnitRefs[i].ObjectID));
		SoldierClassTemplate = Unit.GetSoldierClassTemplate();
		if (SoldierClassTemplate.ExcludedEquipment.Find(ItemTemplate.DataName) != INDEX_NONE)
		{
			ExcludingSoldierClassNames.AddItem(Unit.GetNickName(true));
		}
	}

	if (ExcludingSoldierClassNames.Length > 0)
	{
		ClassListString = class'UIUtilities_Text'.static.StringArrayToCommaSeparatedLine(ExcludingSoldierClassNames);
		FullString = default.strStatus_ItemUnavailableTo $ ":" @ ClassListString;
	}

	return FullString;
}

//---------------------------------------------------------------------------------------
//				MISSION RESULTS
//---------------------------------------------------------------------------------------
static function GetMissionSuccessStrings(XComGameState_StrategyAction_Mission MissionAction, out string Summary, out string Description)
{
	local XComGameState_DioWorker Worker;
	local X2DioStrategyActionTemplate ActionTemplate;

	Worker = MissionAction.GetWorker();
	if (Worker != none)
	{
		Summary = Worker.GetSuccessSummary();
		Description = Worker.GetSuccessDescription();
	}
	else
	{
		ActionTemplate = MissionAction.GetMyTemplate();
		Summary = ActionTemplate.SuccessSummary;
		Description = ActionTemplate.SuccessDescription;
	}
}

//---------------------------------------------------------------------------------------
static function string GetMissionSuccessLoreString(XComGameState_StrategyAction_Mission MissionAction)
{
	local XComGameState_DioWorker Worker;
	local X2DioStrategyActionTemplate ActionTemplate;
	local string ResultString;

	ActionTemplate = MissionAction.GetMyTemplate();
	Worker = MissionAction.GetWorker();
	if (Worker != none)
	{
		ResultString = Worker.GetSuccessLore();
	}
	else
	{
		ResultString = ActionTemplate.SuccessLore;
	}

	// No Lore text from worker or action? Try using description instead
	if (ResultString == "")
	{
		ResultString = (Worker != none) ? Worker.GetSuccessDescription() : ActionTemplate.SuccessDescription;
	}

	return ResultString;
}

//---------------------------------------------------------------------------------------
static function string GetMissionBriefingImageString(XComGameState_StrategyAction_Mission MissionAction)
{
	local XComGameState_DioWorker Worker;

	Worker = MissionAction.GetWorker();
	if (Worker != none)
	{
		return Worker.GetMissionBriefingImage();
	}
	
	return MissionAction.GetMyTemplate().DisplayImage;
}

//---------------------------------------------------------------------------------------
//				MISSION PERFORMANCE REWARDS
//---------------------------------------------------------------------------------------
static function string FormatCapturedEnemiesIntelString(int IntelReward)
{
	local XGParamTag LocTag;
	local string FormattedString;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.IntValue0 = IntelReward;
	FormattedString = `XEXPAND.ExpandString(default.TagStr_CapturedEnemyRewardInfo);

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string FormatCivilianPenaltyUnrestString(int NumKills, int Penalty)
{
	local XGParamTag LocTag;
	local string FormattedString;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.IntValue0 = Penalty;
	LocTag.IntValue1 = NumKills;
	FormattedString = `XEXPAND.ExpandString(default.TagStr_CivilianDeathsPenaltyInfo);

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function bool PopulateSubobjectiveRewardStrings(out array<string> OutStrings)
{
	local XComGameState_BattleData BattleData;
	local string TempString;

	OutStrings.Length = 0;
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleData.IsObjectiveCompleted('CaptureConspirator'))
	{
		TempString = FormatCaptureConspiratorRewardString();
		if (TempString != "")
		{
			OutStrings.AddItem(TempString);
		}
	}
	if (BattleData.IsObjectiveCompleted('RescueHostage'))
	{
		TempString = FormatRescueHostageRewardString();
		if (TempString != "")
		{
			OutStrings.AddItem(TempString);
		}
	}
	if (BattleData.IsObjectiveCompleted('CollectEvidence'))
	{
		TempString = FormatCollectEvidenceRewardString();
		if (TempString != "")
		{
			OutStrings.AddItem(TempString);
		}
	}

	return OutStrings.Length > 0;
}

//---------------------------------------------------------------------------------------
static function string FormatCaptureConspiratorRewardString()
{
	local XGParamTag LocTag;
	local string FormattedString;
	local int RewardValue;

	RewardValue = class'DioStrategyAI'.static.GetCapturedConspiratorIntelRewardForMission();
	if (RewardValue <= 0)
	{
		return "";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FormatIntelValue(RewardValue);
	FormattedString = `XEXPAND.ExpandString(default.TagStr_CaptureConspiratorSubobjectiveRewardDesc);

	return class'UIUtilities_Text'.static.GetColoredText(FormattedString, eUIState_Good);
}

//---------------------------------------------------------------------------------------
static function string FormatRescueHostageRewardString()
{
	local XGParamTag LocTag;
	local string FormattedString;
	local int RewardValue;

	RewardValue = class'DioStrategyAI'.static.GetRescueHostageCreditsReward();
	if (RewardValue <= 0)
	{
		return "";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FormatCreditsValue(RewardValue);
	FormattedString = `XEXPAND.ExpandString(default.TagStr_RescueHostageSubobjectiveRewardDesc);

	return class'UIUtilities_Text'.static.GetColoredText(FormattedString, eUIState_Good);
}

//---------------------------------------------------------------------------------------
static function string FormatCollectEvidenceRewardString()
{
	local XGParamTag LocTag;
	local string FormattedString;
	local int RewardValue;

	RewardValue = class'DioStrategyAI'.static.GetCollectEvidenceEleriumReward();
	if (RewardValue <= 0)
	{
		return "";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FormatEleriumValue(RewardValue);
	FormattedString = `XEXPAND.ExpandString(default.TagStr_CollectEvidenceSubobjectiveRewardDesc);

	return class'UIUtilities_Text'.static.GetColoredText(FormattedString, eUIState_Good);
}

//---------------------------------------------------------------------------------------
//				DIO ANDROIDS
//---------------------------------------------------------------------------------------

simulated static function bool CycleAndroids(int Direction, StateObjectReference AndroidRef, delegate<IsSoldierEligible> CheckEligibilityFunc, out StateObjectReference NewAndroid)
{
	local int Index, Counter;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = GetDioHQ();
	History = `XCOMHISTORY;
	Index = GetAndroidIndex(AndroidRef, DioHQ);

	// Loop through the crew array looking for the next suitable soldier
	while (Counter < DioHQ.Androids.Length)
	{
		Index += Direction;
		Counter++;

		if (Index >= DioHQ.Androids.Length)
			Index = 0;
		else if (Index < 0)
			Index = DioHQ.Androids.Length - 1;

		Unit = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Androids[Index].ObjectID));

		// If we've looped around to the same unit as the one passed in, that means we have no valid androids to switch to, return false
		if (Unit.ObjectID == AndroidRef.ObjectID)
		{
			return false;
		}
		else if (CheckEligibilityFunc(Unit))
		{
			NewAndroid = Unit.GetReference();
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
simulated static function int GetAndroidIndex(StateObjectReference AndroidRef, XComGameState_HeadquartersDio DioHQ)
{
	local int i;
	for (i = 0; i < DioHQ.Androids.Length; i++)
	{
		if (DioHQ.Androids[i] == AndroidRef)
			return i;
	}
}

//---------------------------------------------------------------------------------------
// Androids come from a template but all need a unique 'name' based on their make and model
static function GenerateAndroidName(XComGameState_Unit AndroidUnit, out string FirstName, out string LastName, out string NickName)
{
	local string Alphabet, Numerals, TempString;
	local XGParamTag LocTag;
	local int i;

	Numerals = "1234567890";
	Alphabet = "abcdefghijklmnopqrstuvwxyz";

	// First name is from class template
	FirstName = AndroidUnit.GetSoldierClassTemplate().FirstName;

	// Last name is random sequence of numbers and letters, aka 'Model Number'
	for (i = 0; i < 2; ++i)
	{
		TempString $= Mid(Numerals, `SYNC_RAND_STATIC(Len(Numerals)), 1);
	}
	for (i = 0; i < 2; ++i)
	{
		TempString $= Mid(Alphabet, `SYNC_RAND_STATIC(Len(Alphabet)), 1);
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = Caps(TempString);
	LastName = `XEXPAND.ExpandString(default.TagString_AndroidModelName);

	// Nickname chosen at random from X2SoldierClassTemplate collection
	Nickname = class'X2SoldierClassTemplate'.default.RandomNickNames_Android[`SYNC_RAND_STATIC(class'X2SoldierClassTemplate'.default.RandomNickNames_Android.Length)];
}

//---------------------------------------------------------------------------------------
static function string GetAndroidUnitButtonString(XComGameState_Unit AndroidUnit)
{
	return AndroidUnit.GetName(eNameType_First) @ AndroidUnit.GetName(eNameType_Nick);
}

//---------------------------------------------------------------------------------------
// Used in UIArmory_Garage
simulated static function bool PopulateAndroidBays(UIScreen Screen, optional XComGameState CheckGameState)
{
	local int i, NumAndroidBays;
	local XComGameState_HeadquartersDio DioHQ;
	local X2DioAPCUpgradeTemplate UpgradeTemplate;
	local XComGameState_Unit AndroidUnit;
	local X2SoldierClassTemplate SoldierClass;
	local XComGameStateHistory History;
	local string TmpStr;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	NumAndroidBays = DioHQ.CountOwnedAPCUpgrades('APCUpgrade_AndroidBay');

	if (DioHQ.APCUpgrades.Length == 0)
	{
		Screen.MC.FunctionVoid("hideScarList");
	}

	if (NumAndroidBays == 0)
	{
		Screen.MC.FunctionVoid("hideAbilityList");
		return false;
	}

	Screen.Movie.Pres.m_kTooltipMgr.RemoveTooltipsByPartialPath(string(Screen.MCPath) $ ".abilitySummaryList");
	Screen.Movie.Pres.m_kTooltipMgr.RemoveTooltipsByPartialPath(string(Screen.MCPath) $ ".scarSummaryList");

	Screen.MC.FunctionString("setSummaryTitle", "Android Bays");
	Screen.MC.FunctionString("setScarTitle", "Equipped Upgrades");

	Screen.MC.BeginFunctionOp("setScarSummaryList");

	for (i = 0; i < DioHQ.APCUpgrades.Length; ++i)
	{
		UpgradeTemplate = X2DioAPCUpgradeTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(DioHQ.APCUpgrades[i]));

		Screen.MC.QueueString(""/*UpgradeTemplate.IconImage*/);

		// Ability Name
		TmpStr = UpgradeTemplate.DisplayName != "" ? UpgradeTemplate.DisplayName : ("Missing 'DisplayName' for '" $ UpgradeTemplate.DataName $ "'");
		Screen.MC.QueueString(TmpStr);

		// Ability Description
		TmpStr = UpgradeTemplate.Description != "" ? UpgradeTemplate.Description : ("Missing 'Description' for '" $ UpgradeTemplate.DataName $ "'");
		Screen.MC.QueueString(TmpStr);

		Screen.Movie.Pres.m_kTooltipMgr.AddNewTooltipTextBox(TmpStr, 0, 0,
			string(Screen.MCPath) $ ".scarSummaryList.theObject.ScarSummaryItem" $ i, ,
			false, class'UIUtilities'.const.ANCHOR_TOP_RIGHT, true, , , , , , 0);
	}

	Screen.MC.EndOp();

	// Populate ability list (multiple param function call: image then title then description)
	Screen.MC.BeginFunctionOp("setAbilitySummaryList");
	for (i = 0; i < NumAndroidBays; ++i)
	{
		if (i < DioHQ.Androids.Length)
		{
			AndroidUnit = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Androids[i].ObjectID));
			SoldierClass = AndroidUnit.GetSoldierClassTemplate();

			Screen.MC.QueueString(SoldierClass.IconImage);

			Screen.MC.QueueString(Caps(AndroidUnit.GetName(eNameType_FullNick)));

			Screen.MC.QueueString("Android Unit");

			class'UIUtilities_Strategy'.static.AddAbilitySummaryTooltip(Screen, Caps(AndroidUnit.GetName(eNameType_FullNick)), i);
		}
		else
		{
			Screen.MC.QueueString("" /*Destroyed Icon*/);

			Screen.MC.QueueString(Caps(default.EmptyAndroidBayLabel));
			
			Screen.MC.QueueString(default.DestroyedAndroidDesc);

			class'UIUtilities_Strategy'.static.AddAbilitySummaryTooltip(Screen, default.DestroyedAndroidDesc, i);
		}
	}

	Screen.MC.EndOp();

	return true;
}

//---------------------------------------------------------------------------------------
static function string FormatCreditsValue(int Value)
{
	local string FormattedString;

	if (Value < 0)
	{
		FormattedString = "-" $ class'UIUtilities_Strategy'.default.m_strCreditsPrefix $ string(Abs(Value));
	}
	else
	{
		FormattedString = class'UIUtilities_Strategy'.default.m_strCreditsPrefix $ string(Value);
	}

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string FormatNotEnoughCredits()
{
	local XGParamTag LocTag;
	local string FormattedString;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = class'UIUtilities_Strategy'.default.m_strCreditsPrefix;
	FormattedString = `XEXPAND.ExpandString(default.strStatus_NotEnoughCredits);

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string FormatIntelValue(int Value)
{
	local string FormattedString;

	FormattedString = string(Value) @ class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_IntelIcon, 32, 32, -7) `NBSPACE default.strTerm_Intel;

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string FormatNotEnoughIntel()
{
	local XGParamTag LocTag;
	local string FormattedString;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_IntelIcon, 32, 32, -7) `NBSPACE default.strTerm_Intel;
	FormattedString = `XEXPAND.ExpandString(default.strStatus_NotEnoughIntel);

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string FormatEleriumValue(int Value)
{
	local string FormattedString;

	FormattedString = string(Value) @ class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_EleriumIcon, 32, 32, -7) `NBSPACE default.strTerm_Elerium;

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string FormatNotEnoughElerium()
{
	local XGParamTag LocTag;
	local string FormattedString;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_EleriumIcon, 32, 32, -7);
	FormattedString = `XEXPAND.ExpandString(default.strStatus_NotEnoughElerium);

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string FormatMultiResourceValues(optional int Credits, optional int Intel, optional int Elerium)
{
	local array<string> CostStrings;

	if (Credits != 0)
	{
		CostStrings.AddItem(class'UIUtilities_Strategy'.default.m_strCreditsPrefix $ string(Credits));
	}
	if (Intel != 0)
	{
		CostStrings.AddItem(string(Intel) `NBSPACE class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_IntelIcon, 32, 32, -7));
	}
	if (Elerium != 0)
	{
		CostStrings.AddItem(string(Elerium) `NBSPACE class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_EleriumIcon, 32, 32, -7));
	}

	return class'UIUtilities_Text'.static.StringArrayToCommaSeparatedLine(CostStrings);
}

//---------------------------------------------------------------------------------------
static function string FormatTurn(int TurnNum)
{
	return class'UIDIOResourceHeader'.default.TurnLabel @ string(TurnNum);
}

//---------------------------------------------------------------------------------------
static function string FormatFreeFieldTeamValue(int NumFreeFieldTeams)
{
	if (NumFreeFieldTeams == 1 || NumFreeFieldTeams == -1)
	{
		return string(NumFreeFieldTeams) @ default.strTerm_FreeFieldTeam;
	}
	return string(NumFreeFieldTeams) @ default.strTerm_FreeFieldTeamPlural;
}

//---------------------------------------------------------------------------------------
static function string FormatDays(int NumDays, optional bool bProper=true)
{
	// DIO DEPRECATED Using Clock Icon presentation [1/22/2020 dmcdonough]
	//if (NumDays == 1 || NumDays == -1)
	//{
	//	return string(NumDays) @ bProper ? default.strTerm_DayProper : default.strTerm_Day;
	//}
	//return string(NumDays) @ bProper ? default.strTerm_DaysProper : default.strTerm_Days;

	return FormatTimeIcon(NumDays);
}

//---------------------------------------------------------------------------------------
static function string FormatDaysRemaining(int NumDays)
{
	// DIO DEPRECATED Using Clock Icon presentation [1/22/2020 dmcdonough]
	//if (NumDays == 1 || NumDays == -1)
	//{
	//	return string(NumDays) @ default.strTerm_DayRemaining;
	//}
	//return string(NumDays) @ default.strTerm_DaysRemaining;

	return FormatTimeIcon(NumDays);
}

//---------------------------------------------------------------------------------------
// Formats a time/duration value as a string with the "clock" icon
static function string FormatTimeIcon(int TimeValue, optional int IconSize=32, optional int VOffset=-4)
{
	return string(TimeValue) $ class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_ClockIcon, IconSize, IconSize, VOffset);
}

//---------------------------------------------------------------------------------------
// Formats the behind pace flag icon 
static function string FormatBehindPaceIcon(optional int IconSize = 24, optional int VOffset = -7)
{
	return class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_BehindPace, IconSize, IconSize, VOffset);
}

//---------------------------------------------------------------------------------------
// Formats the meta content marker icon 
static function string FormatMetaContentIcon(optional bool bSeen = false, optional int IconSize = 24, optional int VOffset = -7)
{
	if( bSeen ) 
		return class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_MetaContent_Seen, IconSize, IconSize, VOffset);
	else
		return class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_MetaContent, IconSize, IconSize, VOffset);
}

//---------------------------------------------------------------------------------------
static function string GetCommodityCostString(Commodity InCommodity)
{
	if (InCommodity.Cost == 0 && InCommodity.IntelCost == 0 && InCommodity.EleriumCost == 0)
	{
		return default.strTerm_Free;
	}

	return FormatMultiResourceValues(InCommodity.Cost, InCommodity.IntelCost, InCommodity.EleriumCost);
}

//---------------------------------------------------------------------------------------
// Backwards compatibility [3/18/2019 dmcdonough]
static function string GetStrategyCostString(StrategyCost StratCost)
{
	local int iResource, Quantity;
	local string FullString, ResourceString;

	for (iResource = 0; iResource < StratCost.ResourceCosts.Length; iResource++)
	{
		Quantity = StratCost.ResourceCosts[iResource].Quantity;
		ResourceString = class'UIUtilities_Strategy'.default.m_strCreditsPrefix $ string(Quantity);

		if (`DIOHQ.Credits < Quantity)
		{
			ResourceString = class'UIUtilities_Text'.static.GetColoredText(ResourceString, eUIState_Bad);
		}
		else
		{
			ResourceString = class'UIUtilities_Text'.static.GetColoredText(ResourceString, eUIState_Good);
		}

		if (iResource < StratCost.ResourceCosts.Length - 1)
		{
			ResourceString $= ",";
		}

		if (FullString == "")
		{
			FullString $= ResourceString;
		}
		else
		{
			FullString @= ResourceString;
		}
	}

	return class'UIUtilities_Text'.static.FormatCommaSeparatedNouns(FullString);
}

static function int SortStrategyActions(StateObjectReference ActionRefA, StateObjectReference ActionRefB)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyAction ActionA, ActionB;
	local int PriorityA, PriorityB;

	History = `XCOMHISTORY;
	ActionA = XComGameState_StrategyAction(History.GetGameStateForObjectID(ActionRefA.ObjectID));
	ActionB = XComGameState_StrategyAction(History.GetGameStateForObjectID(ActionRefB.ObjectID));

	if (ActionA != none && ActionB == none)
	{
		return 1;
	}
	if (ActionA == none && ActionB != none)
	{
		return -1;
	}

	PriorityA = ActionA.GetSortPriority();
	PriorityB = ActionB.GetSortPriority();
	
	if (PriorityA < PriorityB)
	{
		return 1;
	}
	else if (PriorityA > PriorityB)
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

//---------------------------------------------------------------------------------------
//				FORMATTING
//---------------------------------------------------------------------------------------

static function string FormatSubheader(string InString, optional EUIState UIState = eUIState_Warning, optional int FontSize=32)
{
	return class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(class'UIUtilities_Text'.static.GetColoredText(InString, UIState, FontSize));
}

//---------------------------------------------------------------------------------------
static function string FormatBody(string InString, optional EUIState UIState = eUIState_Normal, optional int FontSize=24)
{
	return class'UIUtilities_Text'.static.GetColoredText(InString, UIState, FontSize);
}

//---------------------------------------------------------------------------------------
static function string FormatNumericalDelta(int InDelta, int FontSize, optional bool bParenthesis=true, optional bool bInvertColoring=false)
{
	local string FormattedString;
	local EUIState UIState;

	if (InDelta >= 0)
	{
		FormattedString = "+" $ string(InDelta);
		UIState = bInvertColoring ? eUIState_Bad : eUIState_Good;
	}
	else
	{
		FormattedString = string(InDelta);
		UIState = bInvertColoring ? eUIState_Good : eUIState_Bad;
	}

	if (bParenthesis)
	{
		FormattedString = "(" $ FormattedString $ ")";
	}

	return class'UIUtilities_Text'.static.GetColoredText(FormattedString, UIState, FontSize);
}

//---------------------------------------------------------------------------------------
// Searches the History for all Action Result objects keyed to a given round (optional, defaults to current round).
static function FindActionResultsForRound(out array<StateObjectReference> OutActionResultRefs, optional int RoundNum = -1)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyActionResult ActionResult;

	History = `XCOMHISTORY;
	OutActionResultRefs.Length = 0;

	if (RoundNum < 0)
	{
		RoundNum = `THIS_TURN;
	}

	foreach History.IterateByClassType(class'XComGameState_StrategyActionResult', ActionResult)
	{
		if (ActionResult.Round == RoundNum)
		{
			OutActionResultRefs.AddItem(ActionResult.GetReference());
		}
	}
}

//---------------------------------------------------------------------------------------
// Searches the History for all Strategy Actions newly spawned for the given round (optional, defaults to current round).
static function FindNewActionsForRound(out array<StateObjectReference> OutActionRefs, optional int RoundNum=-1)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyAction Action;
	
	if (RoundNum < 0)
	{
		RoundNum = `THIS_TURN;
	}

	History = `XCOMHISTORY;
	OutActionRefs.Length = 0;

	foreach History.IterateByClassType(class'XComGameState_StrategyAction', Action)
	{
		if (Action.TurnCreated == RoundNum)
		{
			OutActionRefs.AddItem(Action.GetReference());
		}
	}
}

//---------------------------------------------------------------------------------------
// Searches the History for all Promotion Result objects keyed to a given round (optional, defaults to current round).
static function FindPromotionResultsForRound(out array<StateObjectReference> OutResultRefs, optional int RoundNum = -1)
{
	local XComGameStateHistory History;
	local XComGameState_UnitPromotionResult PromotionResult;

	History = `XCOMHISTORY;
	OutResultRefs.Length = 0;

	if (RoundNum < 0)
	{
		RoundNum = `THIS_TURN;
	}

	foreach History.IterateByClassType(class'XComGameState_UnitPromotionResult', PromotionResult)
	{
		if (PromotionResult.Round == RoundNum)
		{
			OutResultRefs.AddItem(PromotionResult.GetReference());
		}
	}
}

//---------------------------------------------------------------------------------------
// Search the History for all Scar Result objects keyed to a given round (optional, defaults to current round).
static function FindScarResultsForRound(out array<StateObjectReference> OutResultRefs, optional int RoundNum = -1)
{
	local XComGameStateHistory History;
	local XComGameState_UnitScarResult ScarResult;

	History = `XCOMHISTORY;
	OutResultRefs.Length = 0;

	if (RoundNum < 0)
	{
		RoundNum = `THIS_TURN;
	}

	foreach History.IterateByClassType(class'XComGameState_UnitScarResult', ScarResult)
	{
		if (ScarResult.Round == RoundNum)
		{
			OutResultRefs.AddItem(ScarResult.GetReference());
		}
	}
}

//---------------------------------------------------------------------------------------
static function PresentAnarchyUnrestChangePopup(optional int objectID = -1)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_DioCityDistrict District;
	local XComGameState_AnarchyUnrestResult ResultState;
	local array<string> AnarchyStrings, DistrictUnrestStrings;
	local string TempHeader, TempSummary, PopupTitle, PopupText;
	local int i, AnarchyDelta, UnrestDelta;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	// Title
	PopupTitle = `MAKECAPS(default.UnrestAnarchyPopupTitle);

	// Block 1: Anarchy

	// Insert City Anarchy summary line if that value changed at all
	TempHeader = GetCityAnarchyChangeSummary(AnarchyDelta);
	if (AnarchyDelta > 0)
	{
		TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatWarningHeader(TempHeader);
		if( TempHeader != "" ) AnarchyStrings.AddItem(TempHeader);
		// Add help desc when anarchy rises
		if( TempHeader != "" ) AnarchyStrings.AddItem(default.CityAnarchyRaiseDesc);
	}
	else
	{
		TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatGoodHeader(TempHeader);
		if( TempHeader != "" ) AnarchyStrings.AddItem(TempHeader);
	}

	// Add Anarchy line items
	for (i = 0; i < DioHQ.PrevTurnAnarchyUnrestResults.Length; ++i)
	{
		ResultState = XComGameState_AnarchyUnrestResult(History.GetGameStateForObjectID(DioHQ.PrevTurnAnarchyUnrestResults[i].ObjectID));
		if (ResultState.GetStrings(, TempSummary))
		{
			if( TempSummary != "" ) AnarchyStrings.AddItem(`XEXPAND.ExpandString("<Bullet/>" @ TempSummary));
		}
	}

	if (AnarchyStrings.Length > 0)
	{
		TempSummary = class'UIUtilities_Text'.static.StringArrayToNewLineList(AnarchyStrings);
		PopupText $= TempSummary;
	}

	// Block 2: District Unrest

	// Get all Districts that need to show
	foreach History.IterateByClassType(class'XComGameState_DioCityDistrict', District)
	{
		UnrestDelta = District.GetUnrestChangeSinceLastTurn();
		// Nothing changed
		if (UnrestDelta == 0 && District.PrevTurnUnrestResults.Length == 0)
		{
			continue;
		}

		DistrictUnrestStrings.Length = 0;

		// Something changed, process results		
		for (i = 0; i < District.PrevTurnUnrestResults.Length; ++i)
		{
			ResultState = XComGameState_AnarchyUnrestResult(History.GetGameStateForObjectID(District.PrevTurnUnrestResults[i].ObjectID));
			if (ResultState.GetStrings(TempHeader, TempSummary))
			{
				if( TempSummary != "" ) DistrictUnrestStrings.AddItem(`XEXPAND.ExpandString("<Bullet/>" @ TempSummary));
			}
		}

		// Add Header once at the top
		if (UnrestDelta > 0)
		{
			TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatWarningHeader(TempHeader);
		}
		else
		{
			TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatGoodHeader(TempHeader);
		}
		DistrictUnrestStrings.InsertItem(0, TempHeader);

		// Add the strings to the final
		if (DistrictUnrestStrings.Length > 0)
		{
			TempSummary = class'UIUtilities_Text'.static.StringArrayToNewLineList(DistrictUnrestStrings);
			if (PopupText != "")
			{
				PopupText $= "\n\n";
			}
			PopupText $= TempSummary;
		}
	}

	`STRATPRES.UIWarningDialog(PopupTitle, PopupText, eDialog_Normal);
}

//---------------------------------------------------------------------------------------
static function string GetCityAnarchyChangeSummary(optional out int AnarchyDelta)
{
	local XComGameState_CampaignGoal Goal;
	local XGParamTag LocTag;
	local string FormattedString;

	Goal = `DIOHQ.GetCampaignGoal();
	AnarchyDelta = Goal.OverallCityUnrest - Goal.PrevTurnOverallCityUnrest;
	if (AnarchyDelta != 0)
	{
		LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		LocTag.IntValue0 = Goal.OverallCityUnrest;
		if (AnarchyDelta > 0)
		{
			FormattedString = `XEXPAND.ExpandString(default.TagStr_CityAnarchyRaised);
		}
		else
		{
			FormattedString = `XEXPAND.ExpandString(default.TagStr_CityAnarchyLowered);
		}
	}

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function Hotlink_ArmoryUnit(optional int objectID = -1)
{
	local StateObjectReference UnitRef;
	local XComStrategyPresentationLayer Pres;

	Pres = GetStrategyPres();
	if (Pres == none) return;

	Pres.ClearUIToHUD();

	// If the Armory tutorial is needed, route to the top screen first [1/28/2020 dmcdonough]
	if (`TutorialEnabled && !Pres.HasSeenTutorial('StrategyTutorial_DiscoverArmory'))
	{
		// HELIOS BEGIN
		`PRESBASE.UIHQArmoryScreen();
		// HELIOS END
	}
	else
	{
		UnitRef.ObjectID = objectID;
		`PRESBASE.UIArmorySelectUnit(UnitRef);
	}
}

static function Hotlink_UnlockAgent(optional int objectID = -1)
{
	local XComStrategyPresentationLayer Pres;
	Pres = GetStrategyPres();
	if (Pres == none) return;

	Pres.ClearUIToHUD();
	// Route to Armory screen: we always want unlocking to occur in the context of this area
	// HELIOS BEGIN
	`PRESBASE.UIHQArmoryScreen();
	// HELIOS END
}

static function Hotlink_Research(optional int objectID = -1)
{
	local XComStrategyPresentationLayer Pres;
	local XComGameState UpdateState;
	local XComGameStateContext_ChangeContainer ChangeContainer;
	local StateObjectReference ResearchRef;

	Pres = GetStrategyPres(); 
	if( Pres == none ) return; 
	
	//TEMP for @bsteiner: if there will be a "Research Complete" interstitial, route here using objectID
	// Then this state clearing should occur in that screen
	ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Update Unseen Completed Research");
	UpdateState = `XCOMHISTORY.CreateNewGameState(true, ChangeContainer);
	ResearchRef.ObjectID = objectID;
	`DIOHQ.RemoveUnseenCompletedResearch(UpdateState, ResearchRef);		
	`GAMERULES.SubmitGameState(UpdateState);

	Pres.ClearUIToHUD();
	Pres.UIHQResearchScreen();
}

static function Hotlink_SpecOps(optional int objectID = -1)
{
	local XComStrategyPresentationLayer Pres;
	local StateObjectReference UnitRef;
	Pres = GetStrategyPres();
	if (Pres == none) return;

	//UnitRef.ObjectID = objectID;
	Pres.ClearUIToHUD();
	Pres.UISpecOpsActionPicker(UnitRef);
}

static function Hotlink_Training(optional int objectID = -1)
{
	local XComStrategyPresentationLayer Pres;
	local StateObjectReference UnitRef;
	Pres = GetStrategyPres();
	if (Pres == none) return;

	//UnitRef.ObjectID = objectID;
	Pres.ClearUIToHUD();
	Pres.UITrainingActionPicker(UnitRef);
}


static function Hotlink_Supply(optional int objectID = -1)
{
	local XComStrategyPresentationLayer Pres;
	Pres = GetStrategyPres();
	if (Pres == none) return;

	Pres.ClearUIToHUD();
	Pres.UIHQXCOMStoreScreen();
}

static function Hotlink_ScavengerMarket(optional int objectID = -1)
{
	local XComStrategyPresentationLayer Pres;
	Pres = GetStrategyPres();
	if( Pres == none ) return;

	Pres.ClearUIToHUD();
	Pres.UIScavengerMarketScreen();
}

static function Hotlink_CityMap(optional int objectID = -1)
{
	local XComStrategyPresentationLayer Pres;
	Pres = GetStrategyPres();
	if( Pres == none ) return;

	Pres.ClearUIToHUD();
	Pres.UIHQCityMapScreen();
}

static function Hotlink_CriticalMissionOnMap(optional int objectID = -1)
{
	local XComStrategyPresentationLayer Pres;
	local XComGameState_DioWorker CriticalWorker;

	Pres = GetStrategyPres();
	if (Pres == none) 
	{
		return;
	}

	CriticalWorker = class'DioStrategyAI'.static.GetCriticalMissionWorker();
	if (CriticalWorker == none)
	{
		return;
	}

	Pres.ClearUIToHUD();
	Pres.UIHQCityMapScreen();
	Pres.UIWorkerReview(CriticalWorker.GetReference());
}

static function bool ShouldShowMetaContentTags()
{
	if (`TutorialEnabled)
	{
		return false;
	}

	return `XPROFILESETTINGS.Data.GetGamesStarted() > 0;
}

// HELIOS BEGIN
// Test if the Ruleset element is a subclass of the Strategy Ruleset
static function bool IsInStrategy()
{
    local X2GameRuleset GameRuleset;
    // Get the current ruleset and test if it's a strategy level class.
    GameRuleset = `GAMERULES;

    return GameRuleset.ClassIsChildOf(GameRuleset.class, class'X2StrategyGameRuleset');
}

// This should return the actual strategy ruleset
static function X2StrategyGameRuleset GetCurrentStrategyRuleset()
{
    local X2GameRuleset GameRuleset;
    // Get the current ruleset and test if it's a strategy level class.
    GameRuleset = `GAMERULES;

    if (GameRuleset.ClassIsChildOf(GameRuleset.class, class'X2StrategyGameRuleset'))
        return X2StrategyGameRuleset(GameRuleset);
    
    // GameInfo isn't a strategy ruleset
    return none; 
}
// HELIOS END