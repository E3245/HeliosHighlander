class X2DialogueTagTemplate extends X2DialogueElementTemplate
	native (Core);

enum EDialogTagEvalOpCode
{
	TOP_GreaterThan,
	TOP_LessThan,
	TOP_Equal,
	TOP_NotEqual
};

// these variables are used as variant params
var int	IntValue;
var string StringValue;
var name NameValue;
var bool BoolValue;
var array<name> NameArrayValue;
var byte EnumValue;
var bool bCheckSourceUnit; // validate against source or target unit
var bool bFlipCondition; // if true, flip validation logic.  (== => !=)
var EDialogTagEvalOpCode CompareOp;

var Delegate<IsMetDelegate> IsConditionMetFn;
delegate bool IsMetDelegate(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue);

native function bool IsConditionMet(const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, XComGameState_DialogueManager DialogueManager);

// dummy condition check for testing purposes
static function bool AlwaysTrue(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	return true;
}

static function bool CheckEventSourceSoldierClassName(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local bool Result;

	UnitState = GetEventSourceUnitState(EventSource);
	if (UnitState != none && (UnitState.GetMyTemplate().bTreatAsSoldier || UnitState.IsSoldier()))
	{
		ActualValue = string(UnitState.GetSoldierClassTemplateName());

		Result = UnitState.GetSoldierClassTemplateName() == Template.NameValue;
	}

	ExpectedValue = string(Template.NameValue);

	return Result;
}

static function bool CheckMissionName(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComStrategyPresentationLayer StrategyPres;
	local UIScreen CurrentScreen;
	local XComGameState_StrategyAction_Mission Action;
	local XComGameState_MissionSite Mission;
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local UIDIOSquadSelect SquadSelectScreen;

	History = `XCOMHISTORY;
	StrategyPres = `STRATPRES;
	if (StrategyPres != none)
	{
		CurrentScreen = StrategyPres.ScreenStack.GetCurrentScreen();
		ActualValue = string(CurrentScreen.Class.Name);
		// HELIOS BEGIN
		if (CurrentScreen.Class.Name == `PRESBASE.SquadSelect.Name)
		// HELIOS END
		{
			SquadSelectScreen = UIDIOSquadSelect(CurrentScreen);
			Action = XComGameState_StrategyAction_Mission(History.GetGameStateForObjectID(SquadSelectScreen.MissionAction.ObjectID));
			Mission = Action.GetMission();

			ExpectedValue = string(Template.NameValue);
			ActualValue = string(Mission.GeneratedMission.Mission.MissionTypeName);

			return Template.NameValue == Mission.GeneratedMission.Mission.MissionTypeName;
		}
	}
	else
	{
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		ExpectedValue = string(Template.NameValue);
		ActualValue = string(BattleData.MapData.ActiveMission.MissionTypeName);
		return Template.NameValue == BattleData.MapData.ActiveMission.MissionTypeName;
	}

	return false;
}

static function bool CheckMissionTier(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	// todo: use a better check
	ExpectedValue = Template.StringValue;
	ActualValue = `TACTICALMISSIONMGR.ActiveMission.sType;

	return InStr(ActualValue, ExpectedValue) != INDEX_NONE;
}

static function bool CheckMissionCategory(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local UIDIOWorkerReviewScreen WorkerReviewScreen;
	local XComGameState_DioWorker MissionWorker;
	local X2DioStrategyScheduleSourceTemplate StrategySourceTemplate;
	local XComStrategyPresentationLayer StrategyPres;
	local UIScreen CurrentScreen;
	local bool bResult;

	StrategyPres = `STRATPRES;
	History = `XCOMHISTORY;

	CurrentScreen = StrategyPres.ScreenStack.GetCurrentScreen();

	ExpectedValue = "UIDIOWorkerReviewScreen";
	ActualValue = string(CurrentScreen.Class.Name);

	if (CurrentScreen.Class.Name == class'UIDIOWorkerReviewScreen'.Name)
	{
		WorkerReviewScreen = UIDIOWorkerReviewScreen(CurrentScreen);
		if (WorkerReviewScreen.m_WorkerRef.ObjectID > 0)
		{
			MissionWorker = XComGameState_DioWorker(History.GetGameStateForObjectID(WorkerReviewScreen.m_WorkerRef.ObjectID));
			StrategySourceTemplate = MissionWorker.GetMissionStrategySource();

			bResult = (StrategySourceTemplate.DataName == Template.NameValue);
			ActualValue = string(StrategySourceTemplate.DataName);
			ExpectedValue = string(Template.NameValue);
		}
	}

	return bResult;
}

static function bool CheckIsLeadMission(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_MissionSite Mission;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameStateHistory History;
	local XComGameState_StrategyAction_Mission Action;
	local bool bResult;

	History = `XCOMHISTORY;
	DioHQ = `DioHQ;
	Mission = XComGameState_MissionSite(History.GetGameStateForObjectID(DioHQ.MissionRef.ObjectID));
	Action = XComGameState_StrategyAction_Mission(History.GetGameStateForObjectID(Mission.ActionRef.ObjectID));

	bResult = Action.IsLeadMission();

	ActualValue = string(bResult);
	ExpectedValue = string(!Template.bFlipCondition);

	return bResult;
}
static function bool CheckCharacterTemplateName(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local bool Result;

	UnitState = Template.bCheckSourceUnit ? GetEventSourceUnitState(EventSource) : GetTargetUnitStateFromContext(GameState);
	if (UnitState != none)
	{
		Result = Template.NameValue == UnitState.GetMyTemplateName();
		ActualValue = string(UnitState.GetMyTemplateName());
	}

	ExpectedValue = string(Template.NameValue);

	return Result;
}

static function bool CheckCharacterIsInitiallySelectedSquadMember(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit UnitState;
	local bool Result;
	local int i;
	local bool isNewSquadMember;

	DioHQ = `DIOHQ;
	History = `XCOMHISTORY;

	ExpectedValue = string(Template.NameValue);

	for (i = 0; i < DioHQ.Squad.Length; i++)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Squad[i].ObjectID));

		ActualValue @= string(UnitState.GetMyTemplateName());

		if (UnitState.GetMyTemplateName() == Template.NameValue)
		{
			if (i >= 4)
			{
				isNewSquadMember = true;
			}
			break;
		}
	}

	Result = !isNewSquadMember;
	if (Template.bFlipCondition)
	{
		Result = !Result;
	}

	return Result;
}

static function bool CheckCharacterVoiceID(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local bool Result;

	UnitState = Template.bCheckSourceUnit ? GetEventSourceUnitState(EventSource) : GetTargetUnitStateFromContext(GameState);
	if (UnitState != none)
	{
		Result = Template.NameValue == UnitState.AssignedVoiceID;
		ActualValue = string(UnitState.AssignedVoiceID);
	}

	ExpectedValue = string(Template.NameValue);

	return Result;
}

static function bool CheckIsOnTacticalMission(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	ExpectedValue = "valid tactical presentation layer";
	ActualValue = string (XComPresentationLayer(`PRESBASE));

	// todo: use a better check
	return (XComPresentationLayer(`PRESBASE) != none);
}

static function bool CheckIsInStrategyGame(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	ExpectedValue = "valid strategy presentation layer";
	ActualValue = string(`STRATPRES);

	// todo: use a better check
	return (`STRATPRES != none);
}

static function bool CheckIsOnInvestigation(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation;
	local X2DioInvestigationTemplate InvestigationTemplate;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));
	InvestigationTemplate = Investigation.GetMyTemplate();

	ExpectedValue = string(Template.NameValue);
	ActualValue = string(InvestigationTemplate.DataName);

	return InvestigationTemplate.DataName == Template.NameValue;
}

static function bool CheckIsOperationActive(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation;
	local XComGameState_InvestigationOperation Operation;
	local bool Result;
	local int i;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));

	for (i = 0; i < Investigation.ActiveOperationRefs.Length; ++i)
	{
		Operation = XComGameState_InvestigationOperation(History.GetGameStateForObjectID(Investigation.ActiveOperationRefs[i].ObjectID));
		
		if (Operation.GetMyTemplateName() == Template.NameValue)
		{
			Result = true;
			break;
		}
	}

	return Result;
}

static function bool CheckIsOperationCompleted(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation;
	local bool Result;
	local int i;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));

	for (i = 0; i < Investigation.CompletedOperationHistory.Length; ++i)
	{
		if (Investigation.CompletedOperationHistory[i].OperationTemplateName == Template.NameValue)
		{
			Result = true;
			break;
		}
	}

	ExpectedValue = string(Template.NameValue);

	return Result;
}

static function bool CheckStageCompletedForInvestigation(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation;
	local bool Result;
	local array<StateObjectReference> ActiveAndCompletedInvestigations;
	local StateObjectReference InvestigationRef;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	ActiveAndCompletedInvestigations.AddItem(DioHQ.CurrentInvestigation);
	foreach DioHQ.CompletedInvestigations(InvestigationRef)
	{
		ActiveAndCompletedInvestigations.AddItem(InvestigationRef);
	}

	foreach ActiveAndCompletedInvestigations(InvestigationRef)
	{
		Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(InvestigationRef.ObjectID));

		if (Investigation.GetMyTemplateName() == Template.NameValue)
		{
			ActualValue = string(Investigation.Stage);

			if (Investigation.Stage > Template.IntValue)
			{
				Result = true;
				break;
			}
		}
	}

	ExpectedValue = string(Template.IntValue);

	return Result;
}

static function bool CheckCompletedOperationCountInCurrentInvestigation(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation;
	local X2DioInvestigationOperationTemplate OpTemplate;
	local int i, CompletedOpsCount;
	local bool Result;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));
	
	for (i = 0; i < Investigation.CompletedOperationHistory.Length; ++i)
	{
		OpTemplate = X2DioInvestigationOperationTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Investigation.CompletedOperationHistory[i].OperationTemplateName));
		if (OpTemplate.Stage == Template.EnumValue)
		{
			CompletedOpsCount++;
		}
	}

	ActualValue = string(CompletedOpsCount);
	ExpectedValue = string(Template.IntValue);

	Result = CompletedOpsCount >= Template.IntValue;

	return Result;
}

static function bool CheckActiveOperationTier(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation;
	local XComGameState_InvestigationOperation Operation;
	local bool Result;
	local int i;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	ExpectedValue = Template.StringValue;

	Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));
	
	if (Investigation.Stage != eStage_Operations)
	{
		ActualValue = "not yet at operation stage";
	}
	else
	{
		for (i = 0; i < Investigation.ActiveOperationRefs.Length; ++i)
		{
			Operation = XComGameState_InvestigationOperation(History.GetGameStateForObjectID(Investigation.ActiveOperationRefs[i].ObjectID));

			ActualValue = string(Operation.GetMyTemplateName());

			if (InStr(ActualValue, ExpectedValue) != INDEX_NONE)
			{
				Result = true;
				break;
			}
		}
	}

	return Result;
}

static function bool CheckIsOnInvestigationStage(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));

	ExpectedValue = string(Template.IntValue);
	ActualValue = string(Investigation.Stage);

	return Investigation.Stage == Template.IntValue;
}

static function bool CheckIsOnInvestigationAct(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation Investigation;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;

	Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));

	ExpectedValue = string(Template.IntValue);
	ActualValue = string(Investigation.Act);

	return Investigation.Act == Template.IntValue;
}

static function bool CheckCompletedInvestigationCount(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_HeadquartersDio DioHQ;
	local int CompletedCount;
	DioHQ = `DIOHQ;
	CompletedCount = DioHQ.CompletedInvestigations.length;
	if (`TutorialEnabled) CompletedCount -= 1;  // don't consider tutorial investigation when counting

	return CompareInt(CompletedCount, Template.IntValue, Template.CompareOp, ExpectedValue, ActualValue);
}

static function bool CheckIsOnXBreach(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	ExpectedValue = string(Template.IntValue);
	ActualValue = string(BattleData.BreachingRoomListIndex);

	return BattleData.BreachingRoomListIndex == Template.IntValue;
}

static function bool CheckIsBreachingRoomX(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(History.GetGameStateForObjectID(BattleData.ObjectID,, GameState.HistoryIndex));

	ExpectedValue = string(Template.IntValue);
	ActualValue = string(BattleData.BreachingRoomID);

	return BattleData.BreachingRoomID == Template.IntValue;
}


static function bool CheckIsOnBreachPointTypeX(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local BreachPointInfo PointInfo;
	local BreachSlotInfo SlotInfo;
	local bool Result;
	local XComGameState_BreachData BreachDataState;

	BreachDataState = XComGameState_BreachData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BreachData'));

	UnitState = GetEventSourceUnitState(EventSource);
		
	if (UnitState != none && BreachDataState != None)
	{
		foreach BreachDataState.CachedBreachPointInfos(PointInfo)
		{
			foreach PointInfo.BreachSlots(SlotInfo)
			{
				if (SlotInfo.BreachUnitObjectRef.ObjectID == UnitState.ObjectID
					&& SlotInfo.bIsMainSlot)
				{
					Result = PointInfo.EntryPointActor.GetTypeTemplate().Type == Template.IntValue;

					ActualValue = string(PointInfo.EntryPointActor.GetTypeTemplate().Type);
					break;
				}
			}
		}
	}

	ExpectedValue = string(Template.IntValue);

	return Result;
}

static function bool CheckHitResult(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local bool Result;
	local XComGameStateContext_Ability AbilityContext;
	local EAbilityHitResult ExpectedHitResult;

	if (GameState == none)
	{
		ExpectedValue = "valid game state";
		return false;
	}

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	if (AbilityContext == none)
	{
		ExpectedValue = "valid ability context";
		return false;
	}
	
	ExpectedHitResult = EAbilityHitResult(Template.IntValue);
	Result = (AbilityContext.ResultContext.HitResult == ExpectedHitResult);
	
	ActualValue = string(AbilityContext.ResultContext.HitResult);
	ExpectedValue = string(ExpectedHitResult);

	return Result;
}

static function bool CheckEventSourceIsAbilityTarget(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local bool Result, bSpeakerIsAbilityTarget;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Unit SpeakingUnitState;

	if (GameState == none)
	{
		ExpectedValue = "valid game state";
		return false;
	}

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());

	if (AbilityContext == none)
	{
		ExpectedValue = "valid ability context";
		return false;
	}

	SpeakingUnitState = GetEventSourceUnitState(EventSource);
	bSpeakerIsAbilityTarget = AbilityContext.InputContext.PrimaryTarget.ObjectID == SpeakingUnitState.ObjectID;
	
	Result = (Template.BoolValue == bSpeakerIsAbilityTarget);

	ActualValue = string(Template.BoolValue);
	ExpectedValue = string(bSpeakerIsAbilityTarget);

	return Result;
}

static function bool CheckKilledTargetCount(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateContext_Ability AbilityContext;
	local int KilledUnitCount;
	local bool bResult;

	if (GameState == none)
	{
		ExpectedValue = "valid game state";
		return false;
	}

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	if (AbilityContext == none)
	{
		ExpectedValue = "valid ability context";
		return false;
	}

	KilledUnitCount = GetNumTargetsKilledInThisHistoryFrame(AbilityContext);

	ActualValue = string(KilledUnitCount);
	if (Template.CompareOp == TOP_GreaterThan)
	{
		ExpectedValue = ">" @ string(Template.IntValue);
		bResult = KilledUnitCount > Template.IntValue;
	}
	else if (Template.CompareOp == TOP_Equal)
	{
		ExpectedValue = "==" @ string(Template.IntValue);
		bResult = KilledUnitCount == Template.IntValue;
	}

	return bResult;
}

static function bool CheckMultiTargetCount(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateContext_Ability AbilityContext;
	local int AbilityTargetCount;
	local bool bResult;

	if (GameState == none)
	{
		ExpectedValue = "valid game state";
		return false;
	}

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	if (AbilityContext == none)
	{
		ExpectedValue = "valid ability context";
		return false;
	}

	AbilityTargetCount += AbilityContext.InputContext.MultiTargets.length;

	ActualValue = string(AbilityTargetCount);
	if (Template.CompareOp == TOP_GreaterThan)
	{
		ExpectedValue = ">" @ string(Template.IntValue);
		bResult = AbilityTargetCount > Template.IntValue;
	}
	else if (Template.CompareOp == TOP_Equal)
	{
		ExpectedValue = "==" @ string(Template.IntValue);
		bResult = AbilityTargetCount == Template.IntValue;
	}


	return bResult;
}

static function bool CheckHasGameplayTag(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_HeadquartersDio DioHQ;
	local name GameplayTag;
	local bool Result;

	DioHQ = `DioHQ;

	foreach DioHQ.TacticalGameplayTags(GameplayTag)
	{
		ActualValue @= (string(GameplayTag));
		
		if(GameplayTag == Template.NameValue)
		{
			Result = true;
		}
	}

	ExpectedValue = string(Template.NameValue);

	return Result;
}

static function bool CheckIsTargetFriendly(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState, TargetUnitState;
	local XComGameStateHistory History;
	local XComGameStateContext_Ability AbilityContext;

	History = `XCOMHISTORY;
	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	UnitState = GetEventSourceUnitState(EventSource);
	TargetUnitState = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.PrimaryTarget.ObjectID));

	ExpectedValue = string(UnitState.GetTeam());
	ActualValue = string(TargetUnitState.GetTeam());

	return UnitState.IsFriendlyUnit(TargetUnitState);
}

static function bool CheckIsTargetArmored(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local bool Result;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Unit TargetUnitState;
	local int UnitArmorValue, MitigationAmount;
	local DamageResult DmgResult;

	if (GameState == none)
	{
		ExpectedValue = "valid game state";
		return false;
	}

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	if (AbilityContext == none)
	{
		ExpectedValue = "valid ability context";
		return false;
	}


	TargetUnitState = XComGameState_Unit(GameState.GetGameStateForObjectID(AbilityContext.InputContext.PrimaryTarget.ObjectID));
	UnitArmorValue = TargetUnitState.GetMaxArmor();
	
	DmgResult = TargetUnitState.DamageResults[TargetUnitState.DamageResults.length - 1];
	MitigationAmount = DmgResult.MitigationAmount;

	ActualValue = string(UnitArmorValue) @ string(MitigationAmount);
	ExpectedValue = Template.BoolValue ? "UnitArmorValue > 0 MitigationAmount > 0" : "UnitArmorValue <= 0 MitigationAmount <=0";

	Result = Template.BoolValue ? UnitArmorValue > 0 && MitigationAmount > 0 : UnitArmorValue <= 0 && MitigationAmount <= 0;

	return Result;
}

static function bool CheckPreviousSpeakersCharacterName(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local name CharacterTemplateName;

	UnitState = GetPreviousSpeakersUnitState();

	CharacterTemplateName = UnitState.GetMyTemplateName();

	ActualValue = string(CharacterTemplateName);
	ExpectedValue = string(Template.NameValue);

	return (CharacterTemplateName == Template.NameValue);
}

static function bool CheckSpeakerFactionName(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local name SpeakerFactionName;

	UnitState = GetEventSourceUnitState(EventSource);
	SpeakerFactionName = UnitState.GetMyTemplate().SpawnData.FactionID;

	ActualValue = string(SpeakerFactionName);
	ExpectedValue = string(Template.NameValue);

	return (SpeakerFactionName == Template.NameValue);
}

static function bool CheckUnitOnSquad(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local array<XComGameState_Unit> UnitStates;
	local XComGameState_Unit UnitState;
	local X2CharacterTemplate CharTemplate;
	local bool bResult;
	local name CheckUnitName;

	CheckUnitName = Template.bCheckSourceUnit ? GetEventSourceUnitState(EventSource).GetMyTemplateName() : Template.NameValue;

	GetXComSquadMembersOnMission(UnitStates);

	foreach UnitStates(UnitState)
	{
		CharTemplate = UnitState.GetMyTemplate();

		if (CharTemplate.DataName == CheckUnitName)
		{
			bResult = true;
		}

		ActualValue @= string(CharTemplate.DataName);
	}

	ExpectedValue = string(CheckUnitName);

	return bResult;
}

static function bool CheckUnitHasPromotion(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local bool Result;

	UnitState = GetEventSourceUnitState(EventSource);
	if (UnitState == none)
	{
		return false;
	}

	Result = UnitState.HasAvailablePerksToAssign();

	ExpectedValue = string(true);
	ActualValue = string(Result);

	return Result;
}

static function bool CheckUnitsOnSquad(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local array<XComGameState_Unit> UnitStates;
	local XComGameState_Unit UnitState;
	local bool bResult;
	local name CharName;
	local array<name> CharsOnSquad;
	local int UnitsOnSquadCount;

	GetXComSquadMembersOnMission(UnitStates);
	foreach UnitStates(UnitState)
	{
		CharsOnSquad.AddItem(UnitState.GetMyTemplateName());
	}

	foreach Template.NameArrayValue(CharName)
	{
		if (CharsOnSquad.Find(CharName) != INDEX_NONE)
		{
			UnitsOnSquadCount++;
		}
	}

	ActualValue = string(UnitsOnSquadCount);
	ExpectedValue = string(Template.IntValue);
	bResult = UnitsOnSquadCount >= Template.IntValue;
	return bResult;
}

static function bool CheckAbilityTargetStyle(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local X2AbilityTemplate AbilityTemplate;
	local bool bResult;

	AbilityTemplate = GetAbilityTemplateFromContext(GameState);

	ActualValue = string(AbilityTemplate.AbilityTargetStyle.Class.Name);
	ExpectedValue = string(Template.NameValue);

	bResult = AbilityTemplate.AbilityTargetStyle.Class.IsA(Template.NameValue);
	if (Template.bFlipCondition)
	{
		bResult = !bResult;
	}

	return bResult;
}


static function bool CheckAbilityMultiTargetStyle(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local X2AbilityTemplate AbilityTemplate;
	local bool bResult;

	AbilityTemplate = GetAbilityTemplateFromContext(GameState);

	bResult = AbilityTemplate.AbilityMultiTargetStyle.Class.IsA(Template.NameValue);

	ActualValue = string(bResult);
	ExpectedValue = string(Template.NameValue);

	if (Template.bFlipCondition)
	{
		bResult = !bResult;
	}

	return bResult;
}

static function bool CheckAbilityTargetSelf(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local bool Result;
	local XComGameStateContext_Ability AbilityContext;

	if (GameState == none)
	{
		ExpectedValue = "valid game state";
		return false;
	}

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	if (AbilityContext == none)
	{
		ExpectedValue = "valid ability context";
		return false;
	}

	Result = AbilityContext.InputContext.PrimaryTarget == AbilityContext.InputContext.SourceObject;
	if (Template.bFlipCondition)
	{
		Result = !Result;
	}

	ActualValue = string(AbilityContext.InputContext.PrimaryTarget.ObjectID);
	ExpectedValue = Template.bFlipCondition ? "!" $ string(AbilityContext.InputContext.SourceObject.ObjectID) : string(AbilityContext.InputContext.SourceObject.ObjectID);

	return Result;
}

static function bool CheckIsAbilityTargetRobotic(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit TargetUnitState;
	local bool bResult;
	local bool bUnitIsRobotic;

	TargetUnitState = GetTargetUnitStateFromContext(GameState);
	bUnitIsRobotic = TargetUnitState.IsRobotic();

	ActualValue = string(bUnitIsRobotic);
	ExpectedValue = string(Template.bFlipCondition ? false : true);

	bResult = Template.bFlipCondition ? !bUnitIsRobotic : bUnitIsRobotic;

	return bResult;
}

static function bool CheckIsAbilityTargetSquadMember(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit TargetUnitState, SquadMemberState;
	local array<XComGameState_Unit> SquadMemberStates;
	local bool bResult;

	TargetUnitState = GetTargetUnitStateFromContext(GameState);
	GetXComSquadMembersOnMission(SquadMemberStates);

	foreach SquadMemberStates(SquadMemberState)
	{
		if (SquadMemberState.ObjectID == TargetUnitState.ObjectID)
		{
			bResult = true;
			break;
		}
	}

	ActualValue = string(bResult);
	ExpectedValue = string(Template.bFlipCondition ? false: true);

	if (Template.bFlipCondition) 
	{
		bResult = !bResult;
	}

	return bResult;
}

static function bool CheckAbilityTargetPresistentEffects(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local X2AbilityTemplate AbilityTemplate;
	local X2Effect Effect;
	local X2Effect_Persistent PersistentEffect;
	local bool bResult;

	AbilityTemplate = GetAbilityTemplateFromContext(GameState);

	foreach AbilityTemplate.AbilityTargetEffects(Effect)
	{
		if (Effect.IsA(class'X2Effect_Persistent'.Name))
		{
			PersistentEffect = X2Effect_Persistent(Effect);

			if (PersistentEffect.EffectName == Template.NameValue)
			{
				bResult = true;
			}

			ActualValue @= PersistentEffect.EffectName;
		}
	}

	ExpectedValue = string(Template.NameValue);

	return bResult;
}

static function bool CheckAbilityTargetEffects(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local X2AbilityTemplate AbilityTemplate;
	local X2Effect Effect;
	local bool bResult;

	AbilityTemplate = GetAbilityTemplateFromContext(GameState);

	foreach AbilityTemplate.AbilityTargetEffects(Effect)
	{
		if (Effect.IsA(Template.NameValue))
		{
			bResult = true;
		}

		ActualValue @= Effect.Class.Name;
	}

	ExpectedValue = string(Template.NameValue);

	return bResult;
}

static function bool CheckAbilityWeaponDamageValue(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local X2AbilityTemplate AbilityTemplate;
	local bool bResult;
	local int CheckValue;
	local X2Effect_ApplyWeaponDamage ApplyDmgEffect;
	local X2Effect Effect;

	AbilityTemplate = GetAbilityTemplateFromContext(GameState);

	foreach AbilityTemplate.AbilityTargetEffects(Effect)
	{
		if (Effect.IsA(class'X2Effect_ApplyWeaponDamage'.Name))
		{
			ApplyDmgEffect = X2Effect_ApplyWeaponDamage(Effect);

			switch (Template.NameValue)
			{
				case 'Rupture':
					CheckValue = ApplyDmgEffect.EffectDamageValue.Rupture;
					break;
				case 'Damage':
					CheckValue = ApplyDmgEffect.EffectDamageValue.Damage;
					break;
				case 'Spread':
					CheckValue = ApplyDmgEffect.EffectDamageValue.Spread;
					break;
				case 'PlusOne':
					CheckValue = ApplyDmgEffect.EffectDamageValue.PlusOne;
					break;
				case 'Crit':
					CheckValue = ApplyDmgEffect.EffectDamageValue.Crit;
					break;
				case 'Pierce':
					CheckValue = ApplyDmgEffect.EffectDamageValue.Pierce;
					break;
				case 'Rupture':
					CheckValue = ApplyDmgEffect.EffectDamageValue.Rupture;
					break;
				case 'Shred':
					CheckValue = ApplyDmgEffect.EffectDamageValue.Shred;
					break;
				case 'Luck':
					CheckValue = ApplyDmgEffect.EffectDamageValue.Luck;
					break;
			}

			if (CheckValue > 0)
			{
				ActualValue = string(CheckValue);
				bResult = true;
				break;
			}
		}
	}

	ExpectedValue = string(Template.NameValue) @ "> 0";

	return bResult;
}

static function bool CheckAbilityItemObjectTemplate(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local X2ItemTemplate ItemTemplate;

	ItemTemplate = GetItemTemplateFromAbilityContext(GameState);

	ActualValue = string(ItemTemplate.DataName);
	ExpectedValue = string(Template.NameValue);

	return ItemTemplate.DataName == Template.NameValue;
}

static function bool CheckUnitIsNearHazardTiles(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local array<TTile> Tiles;
	local TTile Tile;
	local name OutHazardEffectName;
	local bool bResult;

	UnitState = GetEventSourceUnitState(EventSource);
	if (UnitState == none)
	{
		return false;
	}

	GetSideAndCornerTiles(Tiles, UnitState.TileLocation, /*TileRadius*/3);
	foreach Tiles(Tile)
	{
		if (class'XComPath'.static.TileContainsHazard(UnitState, UnitState.TileLocation, OutHazardEffectName))
		{
			ActualValue = string(OutHazardEffectName);
		
			if (OutHazardEffectName == Template.NameValue)
			{
				bResult = true;
				break;
			}
		}
	}

	ExpectedValue = string(Template.NameValue);

	return bResult;
}

static function bool CheckUnitIsNearExplosives(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local bool bResult;
	local XComGameState_Unit UnitState;
	local Vector UnitWorldPos;
	local XComWorldData WorldData;

	WorldData = `XWORLD;

	UnitState = GetEventSourceUnitState(EventSource);
	UnitWorldPos = WorldData.GetPositionFromTileCoordinates(UnitState.TileLocation);

	bResult = IsPositionInExplosiveRange(UnitWorldPos);

	ActualValue = string(bResult);
	ExpectedValue = string(true);

	return bResult;
}

static function bool CheckCurrentUIScreen(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComPresentationlayerBase Pres;
	local UIScreen CurrentScreen;
	local bool bResult;

	Pres = `PRESBASE;
	CurrentScreen = Pres.ScreenStack.GetCurrentScreen();
	bResult = (CurrentScreen.Class.Name == Template.NameValue);

	ExpectedValue = string(Template.NameValue);
	ActualValue = string(CurrentScreen.Class.Name);

	return bResult;
}

static function bool CheckCompletedResearch(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_HeadquartersDio DioHQ;
	local bool bResult;

	DioHQ = `DioHQ;

	bResult = DioHQ.UnlockedResearchNames.Find(Template.NameValue) != INDEX_NONE;

	ExpectedValue = string(Template.NameValue);
	ActualValue = NameListToString(DioHQ.UnlockedResearchNames);

	return bResult;
}

static function bool CheckOwnedAnroidNum(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = `DioHQ;

	return CompareInt(DioHQ.Androids.length, Template.IntValue, Template.CompareOp, ExpectedValue, ActualValue);
}

static function bool CheckCanAffordAndroid(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_HeadquartersDio DioHQ;
	local int Cost;
	local bool bFirst;

	DioHQ = `DioHQ;
	bFirst = DioHQ.Androids.Length == 0;
	Cost = class'DioStrategyAI'.static.GetAndroidUnitPurchaseCreditsCost(bFirst);

	ActualValue = string(DioHQ.Credits);
	ExpectedValue = string(Cost);

	return DioHQ.Credits >= Cost;
}

static function bool CheckArmoryUnitRef(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComPresentationlayerBase Pres;
	local bool bResult;
	local XComGameState_Unit UnitState;
	local UIArmory ArmoryScreen;

	Pres = `PRESBASE;
	ArmoryScreen = UIArmory(Pres.ScreenStack.GetFirstInstanceOf(class'UIArmory'));
	UnitState = GetEventSourceUnitState(EventSource);

	bResult = ArmoryScreen != none && ArmoryScreen.UnitReference == UnitState.GetReference();
	
	ExpectedValue = "UIArmory:" @ string(UnitState.ObjectID);
	if (ArmoryScreen != none)
	{
		ActualValue $=  "UIArmory:" @ string(ArmoryScreen.UnitReference.ObjectID);
	}

	return bResult;
}

static function bool CheckUnitIsAtBase(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_HeadquartersDio DioHQ;
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
	local XComGameStateHistory History;
	local bool bResult;
	local XComGameState_StrategyAction Action;
	local name UnitNameToCheck;

	History = `XCOMHISTORY;
	DioHQ = `DioHQ;

	UnitNameToCheck = Template.bCheckSourceUnit ? GetEventSourceUnitState(EventSource).GetMyTemplateName() : Template.NameValue;

	foreach DioHQ.Squad(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (UnitState.GetMyTemplateName() == UnitNameToCheck)
		{
			Action = UnitState.GetAssignedAction();
			bResult = (Action == none);
			break;
		}
	}

	if (Template.bFlipCondition)
	{
		bResult = !bResult;
	}

	ActualValue = string(UnitState.GetMyTemplateName()) @ string(Action.GetMyTemplateName());
	ExpectedValue = Template.bFlipCondition ? string(false) : string(true);

	return bResult;
}

static function bool CheckDamageResultValueOfTypeGreaterThanX(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local DamageResult DmgResult, LoopDmgResult;
	local bool bResult;
	local int DamageAmountOfType, i;

	UnitState = GetTargetUnitStateFromContext(GameState);

	for (i = UnitState.DamageResults.Length - 1; i >= 0; i--)
	{
		LoopDmgResult = UnitState.DamageResults[i];
		if (LoopDmgResult.Context == GameState.GetContext())
		{
			DmgResult = LoopDmgResult;
			break;
		}
	}

	switch (Template.NameValue)
	{
		case 'Shred':
			DamageAmountOfType = DmgResult.Shred;
			bResult = (DamageAmountOfType >= Template.IntValue);
			break;
		default:
			break;
	}

	ActualValue = string(DamageAmountOfType);
	ExpectedValue = string(Template.IntValue);

	return bResult;
}

static function bool CheckHasConversationEnded(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_DialogueManager DialogueManager;
	local bool bResult;
	local name CheckRuleName;

	History = `XCOMHISTORY;
	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));

	CheckRuleName = Template.bCheckSourceUnit ? Rule.BaseRuleName : Template.NameValue;

	bResult = (DialogueManager.PlayedBaseRules.Find(CheckRuleName) != INDEX_NONE);
	if (Template.bFlipCondition)
	{
		bResult = !bResult;
	}

	ExpectedValue = string(CheckRuleName) @ string(!Template.bFlipCondition);
	ActualValue = string(bResult);
	return bResult;
}

static function bool CheckOncePerDay(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateHistory History;
	local XComGameState_DialogueManager DialogueManager;
	local bool bResult;

	History = `XCOMHISTORY;
	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));

	bResult = (DialogueManager.PlayedThisStrategyDay.Find(Rule.Name) == INDEX_NONE);
	if (Template.bFlipCondition)
	{
		bResult = !bResult;
	}

	return bResult;
}

static function bool CheckUnitStatusEffect(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local bool Result;

	UnitState = GetEventSourceUnitState(EventSource);

	Result = UnitState.GetUnitAffectedByEffectState(Template.NameValue) != none;
	
	ExpectedValue = string(Template.NameValue);
	ActualValue = string(Result);

	return Result;
}

static function bool CheckUnitScars(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local bool Result;

	UnitState = GetEventSourceUnitState(EventSource);
	Result = UnitState.Scars.length > 0;

	ExpectedValue = " > 0";
	ActualValue = string(UnitState.Scars.length);

	return Result;
}

static function bool CheckScarredSquadMembers(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local array<XComGameState_Unit> SquadMemberStates;
	local int ScarredUnitCount;

	GetXComSquadMembersOnMission(SquadMemberStates);
	foreach SquadMemberStates(UnitState)
	{
		if (UnitState.Scars.length > 0)
		{
			ScarredUnitCount++;
		}
	}

	return CompareInt(ScarredUnitCount, Template.IntValue, Template.CompareOp, ExpectedValue, ActualValue);
}

static function bool CheckUnitMissionCount(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;

	UnitState = GetEventSourceUnitState(EventSource);

	return CompareInt(UnitState.iNumMissions, Template.IntValue, Template.CompareOp, ExpectedValue, ActualValue);
}

static function bool CheckMovementDistance(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameStateContext_Ability AbilityContext;
	local bool Result;
	local int ActualDistance;

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());

	if (AbilityContext.InputContext.MovementPaths.Length > 0)
	{
		ActualDistance = AbilityContext.InputContext.MovementPaths[0].MovementTiles.Length;
		Result = (ActualDistance >= Template.IntValue);
	}

	ExpectedValue = string(Template.IntValue);
	ActualValue = string(ActualDistance);

	return Result;
}

static function bool CheckTutorialEnabled(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local bool Result;

	Result = `TutorialEnabled;

	if (Template.bFlipCondition)
	{
		Result = !Result;
	}

	ExpectedValue = string(!Template.bFlipCondition);
	ActualValue = string(Result);

	return Result;
}

static function bool CheckBeginnerVOEnabled(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_CampaignSettings SettingsState;

	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));

	ExpectedValue = string(true);

	if (SettingsState == none)
	{
		return false;
	}

	ActualValue = string(!SettingsState.bSuppressFirstTimeNarrative);

	return !SettingsState.bSuppressFirstTimeNarrative;
}

static function bool CheckReadyForTutorial(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_CampaignSettings SettingsState;
	local X2DioStrategyTutorialTemplate TutorialTemplate;
	local bool Result;

	if (`TutorialEnabled == false)
	{
		return false;
	}

	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	if (SettingsState == none)
	{
		return false;
	}
	
	TutorialTemplate = X2DioStrategyTutorialTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Template.NameValue));
	if (TutorialTemplate == none)
	{
		return false;
	}

	// Valid if this tutorial is not yet seen
	Result = (SettingsState.SeenTutorials.Find(TutorialTemplate.DataName) == INDEX_NONE);

	if (Template.bFlipCondition)
	{
		Result = !Result;
	}	

	return Result;
}


static function bool CheckUnitAmmoCountGreaterThan(X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local bool Result;
	local XComGameState_Item Weapon;

	UnitState = GetEventSourceUnitState(EventSource);
	Weapon = UnitState.GetPrimaryWeapon();

	if (Weapon != None)
	{
		ActualValue = string(Weapon.Ammo);

		Result = Template.bFlipCondition ? (Weapon.Ammo > 0 && Weapon.Ammo < Template.IntValue) : Weapon.Ammo >= Template.IntValue;
	}

	ExpectedValue = Template.bFlipCondition ? "less than" @ string(Template.IntValue) : "more than" @ string(Template.IntValue);

	return Result;
}

static function bool CheckUnitAmmoCountEquals (X2DialogueTagTemplate Template, const out RuleTemplateData Rule, Object EventData, Object EventSource, XComGameState GameState, out String ExpectedValue, out String ActualValue)
{
	local XComGameState_Unit UnitState;
	local bool Result;
	local XComGameState_Item Weapon;

	UnitState = GetEventSourceUnitState(EventSource);
	Weapon = UnitState.GetPrimaryWeapon();

	if (Weapon != None)
	{
		ActualValue = string(Weapon.Ammo);

		Result = (Weapon.Ammo == Template.IntValue);
	}

	ExpectedValue = string(Template.IntValue);

	return Result;
}

// ============================================
// ================= Helpers ================= 
// ============================================
static function XComGameState_Unit GetEventSourceUnitState(Object EventSource)
{
	local XComGameState_Unit UnitState;
	local XComGameState_AIGroup GroupState;

	UnitState = XComGameState_Unit(EventSource);

	// if the event specifies a group instead of a unit, use the group leader as the unit
	if (UnitState == None)
	{
		GroupState = XComGameState_AIGroup(EventSource);
		if (GroupState != None)
		{
			UnitState = GroupState.GetGroupLeader();
		}
	}

	return UnitState;
}

static function X2AbilityTemplate GetAbilityTemplateFromContext(XComGameState AssociatedGameState)
{
	local XComGameStateContext_Ability AbilityContext;

	AbilityContext = XComGameStateContext_Ability(AssociatedGameState.GetContext());

	return class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(AbilityContext.InputContext.AbilityTemplateName);
}

static function X2ItemTemplate GetItemTemplateFromAbilityContext(XComGameState AssociatedGameState)
{
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Item ItemState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	AbilityContext = XComGameStateContext_Ability(AssociatedGameState.GetContext());
	ItemState = XComGameState_Item(History.GetGameStateForObjectID(AbilityContext.InputContext.ItemObject.ObjectID));
	return ItemState.GetMyTemplate();
}

static function XComGameState_Unit GetTargetUnitStateFromContext(XComGameState AssociatedGameState)
{
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Unit UnitState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	AbilityContext = XComGameStateContext_Ability(AssociatedGameState.GetContext());
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.PrimaryTarget.ObjectID));

	return UnitState;
}

static function XComGameState_Unit GetPreviousSpeakersUnitState()
{
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local XComGameState_DialogueManager DialogueManager;
	
	History = `XCOMHISTORY;
	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(DialogueManager.lastPlayedLineRuntimeInfo.SpeakerObjectID));

	return UnitState;
}

static function bool IsTargetKilledInThisHistoryFrame(  XComGameStateContext_Ability AbilityContext, int iTargetObjectId )
{
	local XComGameStateHistory History;
	local XComGameState_BaseObject CurrTargetGameStateObj;
	local XComGameState_BaseObject PrevTargetGameStateObj;
	local XComGameState_Unit CurrTargetGameStateUnit;
	local XComGameState_Unit PrevTargetGameStateUnit;
	local bool bCurrIsDead;
	local bool bPrevIsDead;

	History = `XCOMHISTORY;

	History.GetCurrentAndPreviousGameStatesForObjectID(iTargetObjectId, PrevTargetGameStateObj, CurrTargetGameStateObj, , AbilityContext.AssociatedState.HistoryIndex);

	CurrTargetGameStateUnit = XComGameState_Unit(CurrTargetGameStateObj);
	PrevTargetGameStateUnit = XComGameState_Unit(PrevTargetGameStateObj);
	bCurrIsDead = (CurrTargetGameStateUnit != None && (CurrTargetGameStateUnit.IsDead() || CurrTargetGameStateUnit.IsUnconscious() || CurrTargetGameStateUnit.bLifelined));
	bPrevIsDead = (PrevTargetGameStateUnit != None && (PrevTargetGameStateUnit.IsDead() || PrevTargetGameStateUnit.IsUnconscious() || PrevTargetGameStateUnit.bLifelined));

	return (!bPrevIsDead && bCurrIsDead);
}

static function int GetNumTargetsKilledInThisHistoryFrame(XComGameStateContext_Ability AbilityContext)
{
	local StateObjectReference Target;
	local int iNumTargetsKilled;
	local int Index;
	local int DupeCheckIndex;
	local bool bDupeFound;

	iNumTargetsKilled = 0;

	if (IsTargetKilledInThisHistoryFrame(AbilityContext, AbilityContext.InputContext.PrimaryTarget.ObjectID))
	{
		iNumTargetsKilled++;
	}

	for (Index = 0; Index < AbilityContext.InputContext.MultiTargets.Length; Index++)
	{
		Target = AbilityContext.InputContext.MultiTargets[Index];

		// Check to see if the target is duplicated as the primary target
		if (Target == AbilityContext.InputContext.PrimaryTarget)
		{
			bDupeFound = true;
		}
		else
		{
			bDupeFound = false;
		}
		
		// Check to see if the target is duplicated earlier in the multitarget list
		for (DupeCheckIndex = 0; DupeCheckIndex <= Index - 1 && !bDupeFound; DupeCheckIndex++)
		{
			if (AbilityContext.InputContext.MultiTargets[DupeCheckIndex] == Target)
			{
				bDupeFound = true;
			}
		}

		if (!bDupeFound && IsTargetKilledInThisHistoryFrame(AbilityContext, Target.ObjectID))
		{
			iNumTargetsKilled++;
		}
	}

	return iNumTargetsKilled;
}

static function GetXComSquadMembersOnMission(out array<XComGameState_Unit> UnitStates)
{
	local XComGameState_Unit UnitState;
	local XComGameState_MissionSite Mission;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameStateHistory History;
	local XComGameState_StrategyAction_Mission Action;
	local StateObjectReference UnitRef;

	History = `XCOMHISTORY;
	DioHQ = `DioHQ;
	Mission = XComGameState_MissionSite(History.GetGameStateForObjectID(DioHQ.MissionRef.ObjectID));
	Action = XComGameState_StrategyAction_Mission(History.GetGameStateForObjectID(Mission.ActionRef.ObjectID));

	foreach Action.AssignedUnitRefs(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		UnitStates.AddItem(UnitState);
	}
}

// copied from X2Helpers_DLC_Day60, nativize
// Return unvalidated corner tiles around a given tile, with a given distance in tiles
static function GetSideAndCornerTiles(out array<TTile> CornerTiles_Out, TTile CenterTile, int TileDistance, int ExtraSideOffset = -1)
{
	local TTile Tile;
	local int XOffset, yOffset, i;

	// Pick corner points.  
	for (i = 0; i < 4; i++)
	{
		// Add Corner Tiles			//  0,  1,  2,  3
		XOffset = (i % 2) * 2 - 1;	// -1,  1, -1,  1
		yOffset = (i / 2) * 2 - 1;	// -1, -1,  1,  1
		Tile = CenterTile;
		Tile.X += XOffset * TileDistance;
		Tile.Y += yOffset * TileDistance;
		CornerTiles_Out.AddItem(Tile);

		if (ExtraSideOffset >= 0)
		{
			// Add Side tiles - XOffset =  -1,  1,  0,  0
			//					YOffest =   0,  0, -1,  1
			if (i < 2)
			{
				yOffset = 0;
			}
			else
			{
				yOffset = XOffset;
				XOffset = 0;
			}
			Tile = CenterTile;
			Tile.X += XOffset * (TileDistance + ExtraSideOffset);
			Tile.Y += yOffset * (TileDistance + ExtraSideOffset);
			CornerTiles_Out.AddItem(Tile);
		}
	}

}

static function bool CompareInt(int Source, int Target, EDialogTagEvalOpCode Op, out string ExpectedValue, out string ActualValue)
{
	local bool bResult;

	ActualValue = string(Source);

	if (Op == TOP_GreaterThan)
	{
		ExpectedValue = ">" @ string(Target);
		bResult = Source > Target;
	}
	else if (Op == TOP_Equal)
	{
		ExpectedValue = "==" @ string(Target);
		bResult = Source == Target;
	}
	else if (Op == TOP_LessThan)
	{
		ExpectedValue = "<" @ string(Target);
		bResult = Source < Target;
	}
	else if (Op == TOP_NotEqual)
	{
		ExpectedValue = "!=" @ string(Target);
		bResult = Source != Target;
	}

	return bResult;
}

// copied over from XGAIPlayer and nativized. maybe should move to worlddata
native static function bool IsPositionInExplosiveRange(const out Vector Pos);


static function string NameListToString(const array<name> Names)
{
	local string str;
	local Name n;

	foreach Names(n)
	{
		str @= string(n);
	}

	return str;
}
// ============================================
