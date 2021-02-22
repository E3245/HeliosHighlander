class XComGameState_Effect_TemplarFocus extends XComGameState_Effect
	native(Core)
	config(GameData_SoldierSkills);

var int FocusLevel;
var config int StartingFocus;
var config int StartingMaxFocus;
var config array<name> IncreaseFocusAbilities;

function bool SetFocusLevel(int SetFocus, XComGameState_Unit TargetUnit, XComGameState NewGameState, optional bool SkipVisualization)
{
	local X2Effect_TemplarFocus FocusEffect;
	local XComGameState_Effect SelfObject;
	local int MaxFocus, NewFocus;

	FocusEffect = X2Effect_TemplarFocus(GetX2Effect());
	`assert(FocusEffect != none);

	MaxFocus = GetMaxFocus(TargetUnit);
	if (SetFocus > MaxFocus)
		NewFocus = MaxFocus;
	else
		NewFocus = SetFocus;

	if (NewFocus < 0)
		NewFocus = 0;

	if (NewFocus == FocusLevel)
		return false;

	if (StatChanges.Length > 0)
	{
		SelfObject = self;
		TargetUnit.UnApplyEffectFromStats(SelfObject, NewGameState);
		StatChanges.Length = 0;
	}	
	StatChanges = FocusEffect.GetFocusModifiersForLevel(NewFocus).StatChanges;
	FocusLevel = NewFocus;
	SelfObject = self;
	if (StatChanges.Length > 0)
	{
		TargetUnit.ApplyEffectToStats(SelfObject, NewGameState);
	}

	if (!SkipVisualization)
		NewGameState.GetContext().PostBuildVisualizationFn.AddItem(FocusChangeVisualization);

	`XEVENTMGR.TriggerEvent('FocusLevelChanged', self, TargetUnit, NewGameState);

	if( TargetUnit.GhostSourceUnit.ObjectID > 0 && FocusLevel == 0 )
	{
		`XEVENTMGR.TriggerEvent('GhostKill', self, TargetUnit);
	}

	return true;
}

simulated function FocusChangeVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local VisualizationActionMetadata Metadata;
	local XComGameState_Effect_TemplarFocus OldFocus;
	local XComGameState_Effect_TemplarFocus NewFocus;
	local XComGameState_Effect_TemplarFocus EndFocus;
	local XComGameState_Effect_TemplarFocus IterateFocus;
	local StateObjectReference UnitRef;
	local int FocusObjectID;

	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Effect_TemplarFocus', IterateFocus)
	{
		UnitRef = IterateFocus.ApplyEffectParameters.TargetStateObjectRef;
		Metadata.StateObject_OldState = History.GetGameStateForObjectID(UnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
		Metadata.StateObject_NewState = History.GetGameStateForObjectID(UnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex);
		Metadata.VisualizeActor = History.GetVisualizer(UnitRef.ObjectID);

		FocusObjectID = XComGameState_Unit(Metadata.StateObject_OldState).GetTemplarFocusEffectState().ObjectID;
		OldFocus = XComGameState_Effect_TemplarFocus(History.GetGameStateForObjectID(FocusObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1));
		NewFocus = XComGameState_Effect_TemplarFocus(History.GetGameStateForObjectID(FocusObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex));
		EndFocus = XComGameState_Effect_TemplarFocus(History.GetGameStateForObjectID(FocusObjectID));

		if( OldFocus != None && NewFocus != None && EndFocus != None )
		{
			FocusChangeVisualizationHelper(VisualizeGameState, Metadata, NewFocus.FocusLevel, OldFocus.FocusLevel, EndFocus.FocusLevel, FocusObjectID);
		}
	}
}

simulated function FocusChangeVisualizationHelper(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, int NewFocusLevel, int OldFocusLevel, int EndFocusLevel, int FocusObjectID)
{
	local XComGameStateHistory History;
	local X2Action_PlaySoundAndFlyOver FlyOverAction;
	local string ModifyDisplay, NumberDisplay;
	local X2Action_CameraLookAt LookAtCamera;
	local X2Action_PlayAnimation PlayAnim;
	local Array<X2Action> ParentActions;
	local XComGameStateVisualizationMgr VisMgr;
	local X2Action_MarkerTreeInsertEnd EndNode;
	local X2Action_MarkerNamed MarkerNamed;
	local int ModifyValue;
	local bool PlayAnimation, bIsLifted, bSkipCamera, bSkipAnimation, bSkipFlyover;
	local XComGameState_BattleData BattleData;
	local XComGameState_Unit UnitState;
	local name ActivationSpeech;
	local XComGameStateContext_Ability LoopContext;
	local XComGameState LoopGameState;

	History = `XCOMHISTORY;
	VisMgr = `XCOMVISUALIZATIONMGR;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BreachData'));
	BattleData = XComGameState_BattleData(History.GetGameStateForObjectID(BattleData.ObjectID, , VisualizeGameState.HistoryIndex));
	
	ModifyValue = NewFocusLevel - OldFocusLevel;
	UnitState = XComGameState_Unit(ActionMetadata.StateObject_NewState);
	
	if( UnitState != None && ModifyValue != 0 )
	{
		//dakota: dont flyover, animate, or move cameras in breach phase
		bSkipCamera = BattleData.bInBreachPhase;
		bSkipAnimation = BattleData.bInBreachPhase;
		bSkipFlyover = BattleData.bInBreachPhase;

		LoopGameState = VisualizeGameState;
		while (LoopGameState.ParentGameState != None)
		{
			LoopContext = XComGameStateContext_Ability(LoopGameState.ParentGameState.GetContext());
			if (LoopContext != None)
			{
				if (LoopContext.InterruptionStatus == eInterruptionStatus_Interrupt)
				{
					//dakota: skip the animation and camera if there is an interruption in the game state chain
					bSkipAnimation = true;
					bSkipCamera = true;
				}				
			}
			LoopGameState = LoopGameState.ParentGameState;
		}

		// Jwats: Play the anim and the flyover at the same time.
		if( ModifyValue != 0 && !bSkipCamera)
		{
			EndNode = X2Action_MarkerTreeInsertEnd(VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_MarkerTreeInsertEnd'));
			if( EndNode != None )
			{
				ParentActions = EndNode.ParentActions;
			}
			else
			{
				VisMgr.GetAllLeafNodes(VisMgr.BuildVisTree, ParentActions);
			}

			LookAtCamera = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), true, , ParentActions));
			LookAtCamera.LookAtActor = ActionMetadata.VisualizeActor;
			ParentActions.Length = 0;
		}

		class'X2Ability_TemplarAbilitySet'.static.PlayFocusFX(VisualizeGameState, ActionMetadata, "ADD_StopFocus", OldFocusLevel);
		class'X2Ability_TemplarAbilitySet'.static.PlayFocusFX(VisualizeGameState, ActionMetadata, "ADD_StartFocus", NewFocusLevel);
		class'X2Ability_TemplarAbilitySet'.static.UpdateFocusUI(VisualizeGameState, ActionMetadata);

		if ( ModifyValue != 0 && !BattleData.bInBreachPhase) //dakota: dont flyover, animate, or move cameras in breach phase)
		{
			// Jwats: Only the final focus result should play an animation
			//only play gaining animation if you are gaining
			PlayAnimation = ( ModifyValue > 0 ) && (NewFocusLevel == EndFocusLevel);
			bIsLifted = UnitState.IsUnitAffectedByEffectName( class'X2AbilityTemplateManager'.default.LiftedName );
			if(!bSkipAnimation && PlayAnimation && !bIsLifted )
			{
				PlayAnim = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, LookAtCamera));
				PlayAnim.Params.AnimName = 'HL_GainingFocus';
				ParentActions.AddItem(PlayAnim);
			}

			if( ModifyValue > 0 )
				NumberDisplay = "+" $ ModifyValue;

			//dakota.lemaster: Breaker has a different flyover string
			if (UnitState.GetSoldierClassTemplateName() == 'SoldierClass_Breaker')
			{
				if(NewFocusLevel == 0)
				{
					ModifyDisplay = class'X2Effect_ModifyTemplarFocus'.default.BreakerRemoveFocusText;
				}
				else
				{
					ModifyDisplay = Repl(class'X2Effect_ModifyTemplarFocus'.default.BreakerFlyoverText, "<FocusAmount/>", NumberDisplay);
				}
			}
			else if ( NewFocusLevel == 0 )
			{
				ModifyDisplay = class'X2Effect_ModifyTemplarFocus'.default.FocusDepletedText;
			}
			else if( ModifyValue > 0 )
			{
				ModifyDisplay = Repl(class'X2Effect_ModifyTemplarFocus'.default.FlyoverText, "<FocusAmount/>", NumberDisplay);
			}

			if (NewFocusLevel == GetMaxFocus(UnitState))
			{
				ActivationSpeech = 'StatChargeMax';
			}

			if (!bSkipFlyover)
			{
				if (NewFocusLevel == 0 ||
					ModifyValue > 0 ||
					UnitState.GetSoldierClassTemplateName() == 'SoldierClass_Breaker')
				{
					FlyOverAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, LookAtCamera));
					FlyOverAction.SetSoundAndFlyOverParameters(None, ModifyDisplay, ActivationSpeech, ModifyValue > 0 ? eColor_Good : eColor_Bad, , 0.5f, true);
					ParentActions.AddItem(FlyOverAction);
				}
			}

			MarkerNamed = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, , ParentActions));
			MarkerNamed.SetName("Join");
		}

		if( EndNode != None )
		{
			VisMgr.DisconnectAction(EndNode);
			VisMgr.ConnectAction(EndNode, VisMgr.BuildVisTree, false, ActionMetadata.LastActionAdded);
		}
	}
}

static function int GetMaxFocus(XComGameState_Unit UnitState)
{
	local int Max, i;

	if (`CHEATMGR != none && `CHEATMGR.CheatMaxFocus > 1)
		return `CHEATMGR.CheatMaxFocus;

	Max = default.StartingMaxFocus;

	//dakota.lemaster: Breaker starts with a different amount of max focus
	if (UnitState.GetSoldierClassTemplateName() == 'SoldierClass_Breaker')
	{
		Max = class'X2Ability_Breaker'.default.BREAKER_MAXFOCUS;
	}

	for (i = 0; i < default.IncreaseFocusAbilities.Length; ++i)
	{
		if (UnitState.HasSoldierAbility(default.IncreaseFocusAbilities[i]))
			Max++;
	}	

	return Max;
}

function int GetStartingFocus(XComGameState_Unit UnitState)
{
	local XComGameState_Unit SourceUnit;
	local int ReturnFocus;
	local bool bHasJumpstartAbility;
	bHasJumpstartAbility = UnitState.HasSoldierAbility('Jumpstart');
	ReturnFocus = default.StartingFocus;
	if (UnitState.GhostSourceUnit.ObjectID > 0)
	{
		SourceUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitState.GhostSourceUnit.ObjectID));
		ReturnFocus = SourceUnit.GetTemplarFocusLevel() + class'X2Ability_TemplarAbilitySet'.default.GhostFocusCost - 1; // Jwats: Starting focus is the cost before ghost - 1
	}
	if (bHasJumpstartAbility)
	{
		ReturnFocus = GetMaxFocus(UnitState);
	}
	return ReturnFocus;
}

function FocusLevelModifiers GetCurrentFocusModifiers()
{
	return GetFocusModifiersForLevel(FocusLevel);
}

function FocusLevelModifiers GetFocusModifiersForLevel(int Level)
{
	return X2Effect_TemplarFocus(GetX2Effect()).GetFocusModifiersForLevel(Level);
}

// HELIOS BEGIN
// Methods that allow modders to display their own images and count for Focus UI
function string GetImageForGFX(XComGameState_Unit UnitState) {return ""; }
function float	GetValueForGFX(XComGameState_Unit UnitState) {return 0; }
// HELIOS END