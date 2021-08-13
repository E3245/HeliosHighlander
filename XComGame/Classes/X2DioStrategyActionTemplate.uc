//---------------------------------------------------------------------------------------
//  FILE:    	X2DioStrategyActionTemplate
//  AUTHOR:  	David McDonough  --  3/11/2019
//  PURPOSE: 	Immutable data for creating Strategy Action in Dio. These include Situations
//				and Missions.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class X2DioStrategyActionTemplate extends X2StrategyElementTemplate
	config(StrategyActions)
	native(Core);

var EStrategyActionType		Type;					// Enum category of strategy action
var config int				TurnDuration;			// Number of turns required to complete the action. Default value 0 means the action completes immediately.
var config array<name>		RequiredUnitClasses;	// X2SoldierClassTemplate names of units required
var config array<StrategyActionRewardData>	BonusRewardsData;	// (Optional) addition rewards to add to this action

// UI
var config string			DisplayImage;

// Base visualization
var config string			HeadquartersAreaTag;	// If units performing this action should go to a specific visual location in the base (XComCrewPositionVisualizer actors), designate it with this field.
													// This overrides all other logic for placement.
// Situation generation params
var config bool				bNoSpecialties;			// Block auto selection of specialty unlocks for this situation

// Mission generation params
var config name				MissionSourceName;		// Default Mission Source Template name to use when generating mission sites
var config bool				bCritical;				// (Optional) Critical missions *must* be resolved on the last day they are available
var config string			MissionFamily;			// (Optional) Mission Family string to use when generating mission sites
var config int				RoomLimit;				// (Optional) If set, limit the rooms in the generated mission

// Text
var localized string		Category;				// One-word term grouping this situation
var localized string		Summary;				// Short, one-sentence statement of the situation
var localized string		BriefingDescription;	// Full narrative description of the situation prior to action
var localized string		SuccessSummary;
var localized string		SuccessDescription;
var localized string		SuccessLore;
var localized string		FailureSummary;
var localized string		FailureDescription;

// Delegates
var Delegate<ActivityDelegate> OnStartAction;
var Delegate<ActivityDelegate> OnTurnUpdateAction;
var Delegate<ActivityDelegate> OnCompleteAction;
var Delegate<ActivityDelegate> OnCancelAction;
var Delegate<CanStartActionDelegate> OnCanStart;
var Delegate<GetIntDelegate> OnGetCreditsCost;
var Delegate<GetIntDelegate> OnGetIntelCost;
// UI delegates
var Delegate<BuildUnavailableStringDelegate> BuildUnavailableStringFn;
var Delegate<BuildStringDelegate> BuildStatusStringFn;
var Delegate<BuildStringDelegate> BuildResultHeaderFn;
var Delegate<BuildStringDelegate> BuildResultSummaryFn;
var Delegate<BuildStringArrayDelegate> OnBuildRewardPreviewStrings;
var Delegate<BuildStringArrayDelegate> OnBuildRewardResultStrings;

delegate ActivityDelegate(XComGameState ModifyGameState, X2DioStrategyActionTemplate ActionTemplate, StateObjectReference ActionRef, optional StateObjectReference DataRef);
delegate bool CanStartActionDelegate(optional StateObjectReference DataRef);
delegate int GetIntDelegate(StateObjectReference ActionRef, optional XComGameState ModifyGameState);
delegate BuildUnavailableStringDelegate(StateObjectReference ActionRef, out array<string> OutStrings);
delegate string BuildStringDelegate(StateObjectReference ActionRef, optional bool bSuccess = true);
delegate array<string> BuildStringArrayDelegate(StateObjectReference ActionRef, optional bool bSuccess = true);

//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
function InitOnCreation()
{
	// Unused [5/16/2019 dmcdonough]
}

//---------------------------------------------------------------------------------------
//				ACTION BUILDERS
//---------------------------------------------------------------------------------------

// Entry point: given this template and all possible parameters, build the Strategy Action and any associated state objects (e.g. MissionSite)
function XComGameState_StrategyAction BuildStrategyAction(XComGameState ModifyGameState,
	optional StateObjectReference DistrictRef,
	optional XComGameState_Reward PrimaryReward,
	optional float BonusRewardScalar=1.0f)
{
	local XComGameState_StrategyAction Action;
	local XComGameState_Reward Reward;
	local int i;

	if (Type == eStrategyAction_Mission)
	{
		Action = BuildMissionStrategyAction(ModifyGameState, DistrictRef, PrimaryReward, BonusRewardScalar);

		// Alert for new Missions
		`STRATPRES.CityMapAttentionCount++;
	}
	else if (Type == eStrategyAction_HQ)
	{
		Action = BuildHQStrategyAction(ModifyGameState, DistrictRef, PrimaryReward, BonusRewardScalar);
	}
	else
	{
		Action = BuildSituationStrategyAction(ModifyGameState, DistrictRef, PrimaryReward, BonusRewardScalar);
	}

	if (Action == none)
	{
		`RedScreen("X2DioStrategyActionTemplate.BuildStrategyAction: unhandled Type, no action created. @gameplay");
		return none;
	}

	// References
	for (i = 0; i < Action.RewardRefs.Length; ++i)
	{
		Reward = XComGameState_Reward(ModifyGameState.ModifyStateObject(class'XComGameState_Reward', Action.RewardRefs[i].ObjectID));
		Reward.ActionRef = Action.GetReference();
	}
	Action.DistrictRef = DistrictRef;

	// Duration
	Action.TurnDuration = TurnDuration;

	// UI
	Action.DisplayImage = DisplayImage;

	// Append currency costs from delegates, if able
	if (OnGetCreditsCost != none)
	{
		Action.CreditsCost += OnGetCreditsCost(Action.GetReference());
	}
	if (OnGetIntelCost != none)
	{
		Action.IntelCost += OnGetIntelCost(Action.GetReference());
	}

	return Action;
}

//---------------------------------------------------------------------------------------
// Begin HELIOS Issue #62
// Remove protected keyword so that childs can override it
function XComGameState_StrategyAction_Situation BuildSituationStrategyAction(XComGameState ModifyGameState, 
	optional StateObjectReference DistrictRef, 
	optional XComGameState_Reward PrimaryReward,
	optional float BonusRewardScalar=1.0f)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_StrategyAction_Situation NewAction;
	local XComGameState_Reward BonusReward;
	local name TemplateName;
	local int i;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	// Warn if no district passed in
	if (DistrictRef.ObjectID <= 0)
	{
		`log("X2DioStrategyActionTemplate.BuildSituationStrategyAction: no District reference provided, choosing one at random @gameplay");
		DistrictRef = class'DioStrategyAI'.static.SelectNextWorkerDistrict(ModifyGameState);
	}

	NewAction = XComGameState_StrategyAction_Situation(ModifyGameState.CreateNewStateObject(class'XComGameState_StrategyAction_Situation', self));
	NewAction.TurnCreated = `THIS_TURN;
	NewAction.SetDistrict(ModifyGameState, DistrictRef);

	NewAction.Category = Category;
	NewAction.Summary = Summary;
	NewAction.BriefingDescription = BriefingDescription;

	// Set Primary Reward, if any
	if (PrimaryReward != none)
	{
		NewAction.RewardRefs.AddItem(PrimaryReward.GetReference());
	}

	// Setup Specialty-gated rewards
	if (!bNoSpecialties)
	{
		BuildSituationActionFieldTeamRewardMods(ModifyGameState, NewAction, PrimaryReward);
	}

	// Bonus rewards, if any
	for (i = 0; i < BonusRewardsData.Length; ++i)
	{
		BonusReward = StratMgr.BuildRewardFromData(ModifyGameState, BonusRewardsData[i], DistrictRef);
		NewAction.RewardRefs.AddItem(BonusReward.GetReference());
	}

	// Update access constraints, if necessary
	if (RequiredUnitClasses.Length > 0)
	{
		foreach RequiredUnitClasses(TemplateName)
		{
			if (NewAction.AccessConstraints.RequiredSoldierClassNames.Find(TemplateName) == INDEX_NONE)
			{
				NewAction.AccessConstraints.RequiredSoldierClassNames.AddItem(TemplateName);
			}
		}
	}

	return NewAction;
}

//---------------------------------------------------------------------------------------
function XComGameState_StrategyAction_Mission BuildMissionStrategyAction(XComGameState ModifyGameState,
	optional StateObjectReference DistrictRef,
	optional XComGameState_Reward PrimaryReward,
	optional float BonusRewardScalar=1.0f)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_StrategyAction_Mission NewAction;
	local X2MissionSourceTemplate MissionSource;
	local XComGameState_MissionSite Mission;
	local XComGameState_Reward Reward;
	local array<XComGameState_Reward> AllBuiltRewards;
	local X2RewardTemplate RewardTemplate;
	local name TemplateName;
	local bool bUnrestReward;
	local int i;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	// Warn if no district passed in
	if (DistrictRef.ObjectID <= 0)
	{
		`log("X2DioStrategyActionTemplate.BuildMissionStrategyAction: no District reference provided, choosing one at random @gameplay");
		DistrictRef = class'DioStrategyAI'.static.SelectNextWorkerDistrict(ModifyGameState);
	}

	// Build Action
	NewAction = XComGameState_StrategyAction_Mission(ModifyGameState.CreateNewStateObject(class'XComGameState_StrategyAction_Mission', self));	
	NewAction.TurnCreated = `THIS_TURN;
	NewAction.SetDistrict(ModifyGameState, DistrictRef);

	// Set Primary Reward, if any
	if (PrimaryReward != none)
	{
		AllBuiltRewards.AddItem(PrimaryReward);
		NewAction.RewardRefs.AddItem(PrimaryReward.GetReference());
	}

	// Add'l Bonus rewards, if any
	for (i = 0; i < BonusRewardsData.Length; ++i)
	{
		Reward = StratMgr.BuildRewardFromData(ModifyGameState, BonusRewardsData[i], DistrictRef);
		AllBuiltRewards.AddItem(Reward);
		NewAction.RewardRefs.AddItem(Reward.GetReference());
	}

	// Always ensure DistrictUnrest reward on mission actions
	foreach AllBuiltRewards(Reward)
	{
		if (Reward.GetMyTemplateName() == 'Reward_DistrictUnrest')
		{
			bUnrestReward = true;
			break;
		}
	}
	if (!bUnrestReward)
	{
		RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_DistrictUnrest'));
		Reward = RewardTemplate.CreateInstanceFromTemplate(ModifyGameState);
		Reward.GenerateReward(ModifyGameState, , DistrictRef);
		NewAction.RewardRefs.AddItem(Reward.GetReference());
	}

	// Build Mission Site
	MissionSource = X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate(MissionSourceName));
	if (MissionSource == none)
	{
		`RedScreen("X2DioStrategyActionTemplate.BuildMissionStrategyAction: invalid MissionSourceTemplate name. @dmcdonough");
		return none;
	}

	Mission = XComGameState_MissionSite(ModifyGameState.CreateNewStateObject(class'XComGameState_MissionSite'));
	Mission.ActionRef = NewAction.GetReference();
	NewAction.MissionRef = Mission.GetReference();
	Mission.BuildMission(MissionSource, DistrictRef, PrimaryReward, MissionFamily);

	// Update access constraints, if necessary
	if (RequiredUnitClasses.Length > 0)
	{
		foreach RequiredUnitClasses(TemplateName)
		{
			if (NewAction.AccessConstraints.RequiredSoldierClassNames.Find(TemplateName) == INDEX_NONE)
			{
				NewAction.AccessConstraints.RequiredSoldierClassNames.AddItem(TemplateName);
			}
		}
	}

	// Select mission subobjectives & dark events
	class'DioStrategyAI'.static.SelectMissionSubobjectives(Mission, ModifyGameState);
	class'DioStrategyAI'.static.SelectMissionDarkEvents(Mission, ModifyGameState);

	// Populate text for mission action
	NewAction.Category = Category != "" ? Category : MissionSource.MissionCategory;
	NewAction.Summary = Summary;
	NewAction.BriefingDescription = BriefingDescription;
	NewAction.DefaultSuccessResultSummary = SuccessSummary;
	NewAction.DefaultSuccessResultDescription = SuccessDescription;

	return NewAction;
}

//---------------------------------------------------------------------------------------
function XComGameState_StrategyAction_Situation BuildHQStrategyAction(XComGameState ModifyGameState, 
	optional StateObjectReference DistrictRef, 
	optional XComGameState_Reward PrimaryReward,
	optional float BonusRewardScalar=1.0f)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_StrategyAction_Situation NewAction;
	local XComGameState_Reward Reward;
	local name TemplateName;
	local int i;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	NewAction = XComGameState_StrategyAction_Situation(ModifyGameState.CreateNewStateObject(class' XComGameState_StrategyAction_Situation', self));
	NewAction.TurnCreated = `THIS_TURN;
	NewAction.SetDistrict(ModifyGameState, DistrictRef);

	NewAction.Category = Category;
	NewAction.Summary = Summary;
	NewAction.BriefingDescription = BriefingDescription;

	// Set Primary Reward, if any
	if (PrimaryReward != none)
	{
		NewAction.RewardRefs.AddItem(PrimaryReward.GetReference());
	}

	// Bonus rewards, if any
	for (i = 0; i < BonusRewardsData.Length; ++i)
	{
		Reward = StratMgr.BuildRewardFromData(ModifyGameState, BonusRewardsData[i], DistrictRef);
		NewAction.RewardRefs.AddItem(Reward.GetReference());
	}

	// Update access constraints, if necessary
	if (RequiredUnitClasses.Length > 0)
	{
		foreach RequiredUnitClasses(TemplateName)
		{
			if (NewAction.AccessConstraints.RequiredSoldierClassNames.Find(TemplateName) == INDEX_NONE)
			{
				NewAction.AccessConstraints.RequiredSoldierClassNames.AddItem(TemplateName);
			}
		}
	}

	return NewAction;
}
// End HELIOS Issue #62

//---------------------------------------------------------------------------------------
//				UI
//---------------------------------------------------------------------------------------

//	Headers and Summaries can be authored with a common set of log tags, if necessary. The association is like so:
//
//	StrValue0 = DistrictName	[3/31/2019 dmcdonough]

function string DefaultBuildResultHeaderString(StateObjectReference ActionRef, bool bSuccess)
{
	local XComGameState_StrategyAction Action;
	local XComGameState_DioCityDistrict District;
	local XGParamTag LocTag;
	local string FormattedString;

	Action = XComGameState_StrategyAction(`XCOMHISTORY.GetGameStateForObjectID(ActionRef.ObjectID));
	`assert(Action != none);
	District = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(Action.DistrictRef.ObjectID));

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = District.GetMyTemplate().DisplayName;

	if (bSuccess)
	{
		FormattedString = `XEXPAND.ExpandString(SuccessSummary);
	}
	else
	{
		FormattedString = `XEXPAND.ExpandString(FailureSummary);
	}

	return FormattedString;
}

//---------------------------------------------------------------------------------------
function string DefaultBuildResultSummaryString(StateObjectReference ActionRef, bool bSuccess)
{
	local XComGameState_StrategyAction Action;
	local XComGameState_DioCityDistrict District;
	local XGParamTag LocTag;
	local string FormattedString;

	Action = XComGameState_StrategyAction(`XCOMHISTORY.GetGameStateForObjectID(ActionRef.ObjectID));
	`assert(Action != none);
	District = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(Action.DistrictRef.ObjectID));

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = District.GetMyTemplate().DisplayName;

	if (bSuccess)
	{
		FormattedString = `XEXPAND.ExpandString(SuccessDescription);
	}
	else
	{
		FormattedString = `XEXPAND.ExpandString(FailureDescription);
	}

	return FormattedString;
}

//---------------------------------------------------------------------------------------
function bool IsHUDHighlight()
{
	switch (Type)
	{
	case eStrategyAction_Mission:
	case eStrategyAction_Situation:
		return true;
	}

	return false;
}

//---------------------------------------------------------------------------------------
//				UTILS
//---------------------------------------------------------------------------------------
function BuildSituationActionFieldTeamRewardMods(XComGameState ModifyGameState, XComGameState_StrategyAction Action, XComGameState_Reward PrimaryReward)
{
	// DIO DEPRECATED [10/8/2019 dmcdonough]
}

//---------------------------------------------------------------------------------------
static function bool ValidateBonusReward(string CardLabel, Object ValidationData)
{
	local X2RewardTemplate RewardTemplate;
	RewardTemplate = X2RewardTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(name(CardLabel)));
	if (RewardTemplate == none)
		return false;
	if (RewardTemplate.IsRewardAvailableFn != none)
	{
		return RewardTemplate.IsRewardAvailableFn();
	}
	return true;
}

//---------------------------------------------------------------------------------------
defaultproperties
{
}