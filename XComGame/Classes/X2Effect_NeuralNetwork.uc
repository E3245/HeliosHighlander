class X2Effect_NeuralNetwork extends X2Effect_PersistentStatChange config(GameCore);

var name NeuralNetworkReactAnim;
var localized string NeuralNetworkEffectAcquiredString;

// HELIOS Issue #23 Variables
var name NeuralNetworkRemovedTriggerName;

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local Object EffectObj;
	local XComGameState_Unit SourceUnitState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);

	EffectObj = NewEffectState;
	SourceUnitState = XComGameState_Unit(History.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));

	//Remove NeuralNetwork is the source is impaired.
	`XEVENTMGR.RegisterForEvent(EffectObj, 'ImpairingEffect', NewEffectState.OnNeuralNetworkSourceSourceBecameImpaired, ELD_OnStateSubmitted, , SourceUnitState);
}

simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	super.OnEffectRemoved(ApplyEffectParameters, NewGameState, bCleansed, RemovedEffectState);
}

simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata BuildTrack, name EffectApplyResult)
{
	local XComGameState_Unit UnitState;
	local X2Action_MindControlled MindControlAction;

	super.AddX2ActionsForVisualization(VisualizeGameState, BuildTrack, EffectApplyResult);

	if (EffectApplyResult != 'AA_Success')
	{
		return;
	}

	UnitState = XComGameState_Unit(BuildTrack.StateObject_NewState);
	if (UnitState == None)
	{
		return;
	}

	// play a react animation and update the unit flag
	MindControlAction = X2Action_MindControlled(class'X2Action_MindControlled'.static.AddToVisualizationTree(BuildTrack, VisualizeGameState.GetContext(), false, BuildTrack.LastActionAdded));
	MindControlAction.MindControlledAnim = NeuralNetworkReactAnim;
	
	// pan to the networked unit
	//class'X2StatusEffects'.static.AddEffectCameraPanToAffectedUnitToTrack(BuildTrack, VisualizeGameState.GetContext());
	class'X2StatusEffects'.static.AddEffectSoundAndFlyOverToTrack(BuildTrack, VisualizeGameState.GetContext(), FriendlyName, '', eColor_Bad,,8.0f);
	class'X2StatusEffects'.static.AddEffectMessageToTrack(
		BuildTrack,
		default.NeuralNetworkEffectAcquiredString,
		VisualizeGameState.GetContext(),
		FriendlyName,
		"img:///UILibrary_PerkIcons.UIPerk_domination",
		eUIState_Good);
}

simulated function AddX2ActionsForVisualization_Tick(XComGameState VisualizeGameState, out VisualizationActionMetadata BuildTrack, const int TickIndex, XComGameState_Effect EffectState)
{
	local XComGameState_Unit UnitState;

	super.AddX2ActionsForVisualization_Tick(VisualizeGameState, BuildTrack, TickIndex, EffectState);

	UnitState = XComGameState_Unit(BuildTrack.StateObject_NewState);
	if (UnitState == None || !UnitState.IsAlive())
	{
		return; // dead units should not be reported
	}

	class'X2StatusEffects'.static.UpdateUnitFlag(BuildTrack, VisualizeGameState.GetContext());
}

simulated function AddX2ActionsForVisualization_Removed(XComGameState VisualizeGameState, out VisualizationActionMetadata BuildTrack, const name EffectApplyResult, XComGameState_Effect RemovedEffect)
{
	local XComGameState_Unit UnitState;

	super.AddX2ActionsForVisualization_Removed(VisualizeGameState, BuildTrack, EffectApplyResult, RemovedEffect);

	UnitState = XComGameState_Unit(BuildTrack.StateObject_NewState);
	if (UnitState == None || !UnitState.IsAlive() || UnitState.IsUnconscious() || UnitState.bRemovedFromPlay)
	{
		return; // dead units should not be reported
	}

	class'X2StatusEffects'.static.UpdateUnitFlag(BuildTrack, VisualizeGameState.GetContext());
}

static function GatherEnemiesInNeuralNetwork(StateObjectReference CasterUnitRef, out array<StateObjectReference> NetworkedEnemyRefs, optional int HistoryIndex = -1)
{
	local XComGameStateHistory History;
	local StateObjectReference EffectRef, TargetObjectRef;
	local XComGameState_Unit CasterUnitState, TargetUnitState;
	local XComGameState_Effect EffectState;

	History = `XCOMHISTORY;
	NetworkedEnemyRefs.Length = 0;

	CasterUnitState = XComGameState_Unit(History.GetGameStateForObjectID(CasterUnitRef.ObjectID, eReturnType_Reference, HistoryIndex));
	if (CasterUnitState == None)
	{
		return;
	}
	
	// Find all applied Neural Networks by this caster
	foreach CasterUnitState.AppliedEffects(EffectRef)
	{
		EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID, eReturnType_Reference, HistoryIndex));
		if (EffectState != None && EffectState.GetX2Effect().EffectName == default.EffectName)
		{
			TargetObjectRef = EffectState.ApplyEffectParameters.TargetStateObjectRef;

			TargetUnitState = XComGameState_Unit(History.GetGameStateForObjectID(TargetObjectRef.ObjectID, eReturnType_Reference, HistoryIndex));
			if (TargetUnitState != None && !TargetUnitState.IsCaptured() && !TargetUnitState.IsDead())
			{
				if (NetworkedEnemyRefs.Find('ObjectID', TargetObjectRef.ObjectID) == INDEX_NONE)
				{
					NetworkedEnemyRefs.AddItem(TargetObjectRef);
				}
			}
		}
	}
}

// Begin HELIOS Issue #23
// Trigger an event when Neural Network is removed
// This is quicker than looping through every caster's applied effects after any ability triggers
static function NeuralNetworkEffect_Removed(X2Effect_Persistent PersistentEffect, const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed)
{
	local XComGameState_Unit UnitState;

	if (!bCleansed)
	{
		UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
		if (UnitState == none)
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
			if (UnitState == none)
			{
				`RedScreen("NeuralNetworkEffect_Removed could not find source unit. @gameplay");
				return;
			}
		}

		// Trigger the removal of Neural Network and send the Caster as the Data and Source of this event
		`XEVENTMGR.TriggerEvent(default.NeuralNetworkRemovedTriggerName, UnitState, UnitState, NewGameState);
	}
}
// End HELIOS Issue #23

defaultproperties
{
	NeuralNetworkReactAnim="HL_Psi_NeuralNetwork_Target"
	EffectName="NeuralNetworkEffect"
	bPerkPersistOnTargetPawnDeath=true
	bRemoveWhenTargetDies=true
	bRemoveWhenTargetUnconscious=false
	// HELIOS #23 Variables
	EffectRemovedFn=NeuralNetworkEffect_Removed
	NeuralNetworkRemovedTriggerName="HELIOS_NeuralNetworkRemovalTrigger"
}