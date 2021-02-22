//---------------------------------------------------------------------------------------
//  FILE:    	XComGameState_DioStrategyScheduler
//  AUTHOR:  	David McDonough  --  5/27/2019
//  PURPOSE: 	Object that injects Dio Strategy-layer entities or events based on 
//				campaign turn.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameState_DioStrategyScheduler extends XComGameState_BaseObject
	dependson(X2DioStrategyScheduleTemplate)
	config(StrategyTuning);

var name CurrentScheduleName;
// Indices into the 'Items' array of the current X2DioStrategyScheduleTemplate. Scheduler advances from the top.
var array<int> ScheduleIndices;

// Config
var config array<DioStrategyNameCollection> SourceDecks;
var config name DefaultStartingSchedule;
var config name	DefaultUnlockScavengerMarketWorker;

// HELIOS BEGIN
// Convert important functions into simulated functions, and private functions into protected functions for better Object Inheritance

//---------------------------------------------------------------------------------------
//				INIT
//---------------------------------------------------------------------------------------
// Process items from the given schedule template and extend the scheduler's internal
simulated function InitSchedule(XComGameState ModifyGameState, name ScheduleName)
{
	local XComGameState_DioStrategyScheduler Scheduler;
	local X2DioStrategyScheduleTemplate ScheduleTemplate;	
	local int i, k, Turns;

	ScheduleTemplate = X2DioStrategyScheduleTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(ScheduleName));
	if (ScheduleTemplate == none)
	{
		return;
	}

	Scheduler = XComGameState_DioStrategyScheduler(ModifyGameState.ModifyStateObject(class'XComGameState_DioStrategyScheduler', ObjectID));
	`log("Strategy Scheduler -- INIT: Schedule name: " @ string(ScheduleName), , 'Dio_StratSchedule');

	// Clear old schedule
	ScheduleIndices.Length = 0;

	// Set up new schedule
	Scheduler.CurrentScheduleName = ScheduleTemplate.DataName;
	for (i = 0; i < ScheduleTemplate.Items.Length; ++i)
	{
		Turns = ScheduleTemplate.RollItemDuration(ScheduleTemplate.Items[i]);
		
		// Calc duration could be zero, indicating skip this element
		if (Turns <= 0)
		{
			continue;
		}

		// Append this index into internal collection
		Scheduler.ScheduleIndices.AddItem(i);
		
		// For turn durations higher than 1, add blank entries for each turn after the first
		for (k = 1; k < Turns; ++k)
		{
			// Blank entry
			Scheduler.ScheduleIndices.AddItem(-1);
		}
	}
}

//---------------------------------------------------------------------------------------
function VerifySchedule(XComGameState ModifyGameState)
{
	local X2DioStrategyScheduleTemplate ScheduleTemplate;
	local XComGameState_DioStrategyScheduler Scheduler;

	Scheduler = XComGameState_DioStrategyScheduler(ModifyGameState.ModifyStateObject(class'XComGameState_DioStrategyScheduler', ObjectID));

	// Assuming the current template is valid, verify indices
	ScheduleTemplate = X2DioStrategyScheduleTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Scheduler.CurrentScheduleName));
	if (ScheduleTemplate != none)
	{
		// If the schedule indices are now empty, advance to linked schedule or restart
		if (Scheduler.ScheduleIndices.Length <= 0)
		{
			`log("Strategy Scheduler -- VERIFYING: ScheduleIndices are empty, initing next schedule", , 'Dio_StratSchedule');
			if (ScheduleTemplate.LinkedSchedule != '')
			{
				Scheduler.InitSchedule(ModifyGameState, ScheduleTemplate.LinkedSchedule);
			}
			else if (ScheduleTemplate.DataName != '')
			{
				Scheduler.InitSchedule(ModifyGameState, ScheduleTemplate.DataName);
			}
		}
		else
		{
			`log("Strategy Scheduler -- VERIFYING: ScheduleIndices remaining:" @ Scheduler.ScheduleIndices.Length, , 'Dio_StratSchedule');
		}
	}

	// If something got missed, re-init using failsafe option
	if (ScheduleTemplate == none || Scheduler.ScheduleIndices.Length == 0)
	{
		`log("Strategy Scheduler -- VERIFYING: failsafe reached! Initing default schedule", , 'Dio_StratSchedule');
		Scheduler.InitSchedule(ModifyGameState, 'StrategySchedule_EarlyCampaign');
	}
}

//---------------------------------------------------------------------------------------
//				EXECUTION
//---------------------------------------------------------------------------------------
simulated function DoTurnUpkeep(XComGameState ModifyGameState)
{
	local XComGameState_DioStrategyScheduler Scheduler;
	local X2DioStrategyScheduleTemplate ScheduleTemplate;
	local StrategyScheduleItemData ScheduleItem;
	local XComGameState_Investigation CurrentInvestigation;
	local XComGameState_InvestigationOperation CurrentOperation;
	local XComGameState_DioWorker OpWorker;
	local XComGameState_DioCity City;
	local array<StateObjectReference> EmergencyDistrictRefs;
	local int ScheduleIndex, RandIdx, TargetsBuilt;
	local bool bOpRevealDay;

	Scheduler = XComGameState_DioStrategyScheduler(ModifyGameState.ModifyStateObject(class'XComGameState_DioStrategyScheduler', ObjectID));
	`log("Strategy Scheduler *** START Day" @ `THIS_TURN @ "***", , 'Dio_StratSchedule');
	// Skip advancing the schedule if the current Investigation is in a certain state
	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();	

	// No investigation active
	if (CurrentInvestigation == none)
	{
		`log("Strategy Scheduler -- UPKEEP: Exiting: no Investigation", , 'Dio_StratSchedule');
		return;
	}
	else
	{
		// Tutorial Act has its own sequence
		if (CurrentInvestigation.GetMyTemplateName() == 'Investigation_Tutorial')
		{
			`log("Strategy Scheduler -- UPKEEP: Exiting: on Tutorial Investigation", , 'Dio_StratSchedule');
			return;
		}
		// Finale has custom sequence
		if (CurrentInvestigation.GetMyTemplateName() == 'Investigation_FinaleConspiracy')
		{
			`log("Strategy Scheduler -- UPKEEP: Exiting: on Finale Investigation", , 'Dio_StratSchedule');
			return;
		}
		// Investigation is complete: the player is about to choose a new one that will spawn its Groundwork
		if (CurrentInvestigation.Stage >= eStage_Completed)
		{
			`log("Strategy Scheduler -- UPKEEP: Exiting: Investigation Completed", , 'Dio_StratSchedule');
			return;
		}
	}

	// Critical missions can't be skipped, so don't let the schedule spawn any new ones this turn
	if (class'DioStrategyAI'.static.GetCriticalMissionWorker(ModifyGameState) != none)
	{
		`log("Strategy Scheduler -- UPKEEP: Exiting: Critical Mission worker present today", , 'Dio_StratSchedule');
		// Ignore and remove all non-critical workers
		class'DioStrategyAI'.static.IgnoreAllNonCriticalMissions(ModifyGameState);
		return;
	}

	TargetsBuilt = 0;

	// Count masked operation mission as a target the day it is first revealed
	CurrentOperation = class'DioStrategyAI'.static.GetCurrentOperation(ModifyGameState);
	if (CurrentOperation != none)
	{
		OpWorker = CurrentOperation.GetActiveMissionWorker(ModifyGameState);
		if (OpWorker != none)
		{
			if (OpWorker.IsRevealedThisTurn())
			{
				`log("Strategy Scheduler -- UPKEEP: Operation revealed today counts as 1 target", , 'Dio_StratSchedule');
				bOpRevealDay = true;
				TargetsBuilt++;
			}
		}
	}

	// If an Emergency is called for anywhere, try to spawn that instead of advancing the schedule
	// - No Emergencies on Operation Reveal Days
	if (!bOpRevealDay)
	{
		City = XComGameState_DioCity(ModifyGameState.ModifyStateObject(class'XComGameState_DioCity', `DIOCITY.ObjectID));
		if (City.FindEmergencyReadyDistrict(ModifyGameState, EmergencyDistrictRefs))
		{
			// Choose a ready district for the emergency
			RandIdx = `SYNC_RAND(EmergencyDistrictRefs.Length);
			if (BuildEmergencyWorker(ModifyGameState, EmergencyDistrictRefs[RandIdx]))
			{
				`log("Strategy Scheduler -- UPKEEP: Emergency worker built", , 'Dio_StratSchedule');
				TargetsBuilt++;
			}
		}
	}

	// All exceptions passed, perform the next regularly scheduled item
	Scheduler.VerifySchedule(ModifyGameState);
	ScheduleTemplate = X2DioStrategyScheduleTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(Scheduler.CurrentScheduleName));
	`log("Strategy Scheduler -- UPKEEP: Executing Schedule Template" @ string(ScheduleTemplate.DataName));

	// Process top element
	if (Scheduler.ScheduleIndices.Length > 0)
	{
		ScheduleIndex = Scheduler.ScheduleIndices[0];

		// Blank?
		if (ScheduleIndex == -1)
		{
			`log("Strategy Scheduler -- UPKEEP: Schedule Index = -1, skipping day", , 'Dio_StratSchedule');
			// Skip
		}
		else
		{
			if (ScheduleTemplate.GetItemAtIndex(ScheduleIndex, ScheduleItem))
			{
				if (ScheduleItem.Source != 'Blank')
				{
					`log("Strategy Scheduler -- UPKEEP: Executing Schedule Index =" @ string(ScheduleIndex), , 'Dio_StratSchedule');
					ExecuteScheduleItem(ModifyGameState, ScheduleItem, TargetsBuilt);
				}
				else
				{
					`log("Strategy Scheduler -- UPKEEP: Schedule item at index is Blank, skipping day", , 'Dio_StratSchedule');
				}
			}
			else
			{
				`log("Strategy Scheduler -- UPKEEP: ERROR, No Schedule item found at index =" @ string(ScheduleIndex), , 'Dio_StratSchedule');
			}
		}

		// Remove top
		Scheduler.ScheduleIndices.Remove(0, 1);
	}
	else
	{
		`log("Strategy Scheduler -- UPKEEP: ERROR, ScheduleIndices is empty!", , 'Dio_StratSchedule');
	}

	`log("Strategy Scheduler *** END ***", , 'Dio_StratSchedule');
}

//---------------------------------------------------------------------------------------
protected function ExecuteScheduleItem(XComGameState ModifyGameState, StrategyScheduleItemData InItemData, const int MissionsBuilt)
{
	local X2CardManager CardManager;
	local X2StrategyElementTemplateManager StratMgr;
	local X2DioStrategyScheduleSourceTemplate ScheduleSourceTemplate;
	local X2DioWorkerTemplate WorkerTemplate;
	local XComGameState_DioWorker Worker;
	local XComGameState_DioCityDistrict District;
	local XComGameState_InvestigationOperation CurrentOperation;
	local StateObjectReference DistrictRef;
	local StateObjectReference TargetCollectionRef;
	local StrategyActionRewardData PrimaryRewardData, BonusRewardData, EmptyRewardData;
	local name SourceTemplateName;
	local string CardString;
	local int NumTargets, i, loopCheck;

	StratMgr = `STRAT_TEMPLATE_MGR;	
		
	// Resolve Schedule Source template
	if (InItemData.Source != '')
	{
		SourceTemplateName = InItemData.Source;
	}
	else if (InItemData.SourceDeck != '')
	{
		CardManager = class'X2CardManager'.static.GetCardManager();
		if (CardManager.SelectNextCardFromDeck(InItemData.SourceDeck, CardString))
		{
			SourceTemplateName = name(CardString);
		}
	}

	ScheduleSourceTemplate = X2DioStrategyScheduleSourceTemplate(StratMgr.FindStrategyElementTemplate(SourceTemplateName));
	`log("Strategy Scheduler -- EXECUTE: Schedule Source =" @ ScheduleSourceTemplate.DisplayName, , 'Dio_StratSchedule');
	if (ScheduleSourceTemplate == none)
	{
		`RedScreen("XComGameState_DioStrategyScheduler.ExecuteScheduleItem: invalid source template name" @ string(SourceTemplateName) @ "@gameplay");
		return;
	}

	// Get the number of targets this source should build
	NumTargets = ScheduleSourceTemplate.GetNumChoices(ModifyGameState);
	`log("Strategy Scheduler -- EXECUTE: NumTargets =" @ NumTargets @ ", MissionsBuilt =" @ MissionsBuilt, , 'Dio_StratSchedule');

	// Subtract the number of targets already made from upkeep (e.g. emergency missions)
	NumTargets -= MissionsBuilt;

	// Time to build a Lead mission?
	if (ScheduleSourceTemplate.bSpawnLeadMissions)
	{
		CurrentOperation = class'DioStrategyAI'.static.GetCurrentOperation(ModifyGameState);
		if (CurrentOperation.CanStartLeadMission(ModifyGameState))
		{
			Worker = CurrentOperation.BuildLeadMissionWorker(ModifyGameState);			
			if (Worker != none)
			{
				`log("Strategy Scheduler -- EXECUTE: Spawning Lead Mission:" @ Worker.GetMyTemplate().DisplayName, , 'Dio_StratSchedule');
				// Place Lead worker
				DistrictRef = class'DioStrategyAI'.static.SelectNextWorkerDistrict(ModifyGameState);
				if (DistrictRef.ObjectID > 0)
				{
					District = XComGameState_DioCityDistrict(ModifyGameState.ModifyStateObject(class'XComGameState_DioCityDistrict', DistrictRef.ObjectID));
					class'XComGameState_DioWorker'.static.PlaceWorker(ModifyGameState, Worker.GetReference(), District.EnemyWorkers);
				}
			}
		}
	}

	// Build mission workers up to the source's desired num choices
	InItemData.RewardOptions.RandomizeOrder();
	for (i = 0; i < NumTargets; ++i)
	{
		// Clear reward vars
		PrimaryRewardData = EmptyRewardData;
		BonusRewardData = EmptyRewardData;

		// Select district target for worker
		DistrictRef = class'DioStrategyAI'.static.SelectNextWorkerDistrict(ModifyGameState);
		if (DistrictRef.ObjectID <= 0)
		{
			`log("Strategy Scheduler -- EXECUTE: ERROR, could not select district", , 'Dio_StratSchedule');
			`RedScreen("XComGameState_DioStrategyScheduler.ExecuteScheduleItem: could not find district to place new worker @gameplay");
			continue;
		}

		// Get Worker template from source
		WorkerTemplate = ScheduleSourceTemplate.SelectNextWorker(ModifyGameState, DistrictRef);
		if (WorkerTemplate == none)
		{
			`log("Strategy Scheduler -- EXECUTE: ERROR, could not select next worker", , 'Dio_StratSchedule');
			continue;
		}

		`log("Strategy Scheduler -- EXECUTE: Spawning Worker:" @ WorkerTemplate.DisplayName, , 'Dio_StratSchedule');

		// Build worker in its aligned home
		TargetCollectionRef = class'DioWorkerAI'.static.GetWorkerAlignedHomeCollection(WorkerTemplate);
		Worker = WorkerTemplate.CreateInstanceFromTemplate(ModifyGameState, TargetCollectionRef);

		// Update primary reward from worker template
		PrimaryRewardData = WorkerTemplate.PrimaryRewardData;

		// If no Primary Reward came from worker template, populate it from reward set or schedule source
		if (PrimaryRewardData.TemplateName == '')
		{
			// If this schedule item has Reward Sets included, try to populate one to use as primary
			while (InItemData.RewardOptions.Length > 0)
			{
				// Attempt the top reward in the list
				if (TryPopulateRewardFromRewardSet(ModifyGameState, InItemData.RewardOptions[0], PrimaryRewardData))
				{
					// If successful, also apply bonus rewards if any, then break
					if (InItemData.RewardOptions[0].BonusRewardData.TemplateName != '')
					{
						Worker.AddBonusRewardData(ModifyGameState, InItemData.RewardOptions[0].BonusRewardData);
					}

					InItemData.RewardOptions.Remove(0, 1);
					break;
				}
				else
				{
					InItemData.RewardOptions.Remove(0, 1);
				}

				// Infinite loop safety
				if (++loopCheck >= 10)
				{
					break;
				}
			}

			// If no override reward gotten from Reward Set list, see if the source has a preferred set of rewards to use
			if (PrimaryRewardData.TemplateName == '')
			{
				ScheduleSourceTemplate.SelectPrimaryReward(ModifyGameState, PrimaryRewardData);				
			}
		}

		// If no Bonus Reward came from reward set, try applying from source
		if (BonusRewardData.TemplateName == '')
		{
			ScheduleSourceTemplate.SelectBonusReward(ModifyGameState, BonusRewardData);
		}

		// Apply populated rewards, if any
		if (PrimaryRewardData.TemplateName != '')
		{
			Worker.PrimaryRewardData = PrimaryRewardData;
		}
		if (BonusRewardData.TemplateName != '')
		{
			Worker.AddBonusRewardData(ModifyGameState, BonusRewardData);
		}

		// Place in District
		District = XComGameState_DioCityDistrict(ModifyGameState.ModifyStateObject(class'XComGameState_DioCityDistrict', DistrictRef.ObjectID));
		class'XComGameState_DioWorker'.static.PlaceWorker(ModifyGameState, Worker.GetReference(), District.EnemyWorkers);
		`log("Strategy Scheduler -- EXECUTE: Placing in District:" @ District.GetMyTemplate().DisplayName, , 'Dio_StratSchedule');
	}

	// Post-execution custom behavior, if any
	if (ScheduleSourceTemplate.OnPostExecute != none)
	{
		ScheduleSourceTemplate.OnPostExecute(ModifyGameState, ScheduleSourceTemplate);
	}
}

//---------------------------------------------------------------------------------------
// Given a reward set, try to validate and populate Reward data to override a worker's default reward
protected function bool TryPopulateRewardFromRewardSet(XComGameState ModifyGameState, const StrategyScheduleItemRewardSet RewardSet, out StrategyActionRewardData RewardData)
{
	local X2RewardTemplate RewardTemplate;

	RewardTemplate = X2RewardTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(RewardSet.PrimaryRewardName));
	if (RewardTemplate == none)
	{
		return false;
	}

	if (RewardTemplate.IsRewardAvailableFn != none)
	{
		if (RewardTemplate.IsRewardAvailableFn(ModifyGameState) == false)
		{
			return false;
		}
	}

	// Reward is OK, populate data
	if (RewardTemplate.GenerateRewardDataFn != none)
	{
		RewardTemplate.GenerateRewardDataFn(ModifyGameState, RewardData);
	}
	else
	{
		RewardData.TemplateName = RewardTemplate.DataName;
		RewardData.RewardScalar = 1.0; //TODO-DIO-STRATEGY  [7/18/2019 dmcdonough]
	}
	return true;
}

//---------------------------------------------------------------------------------------
//				MISSION BUILDERS
//				For special-case mission workers
//---------------------------------------------------------------------------------------

// Select and spawn an Emergency-mission Worker in the given district
static function bool BuildEmergencyWorker(XComGameState ModifyGameState, StateObjectReference DistrictRef)
{
	local X2DioStrategyScheduleSourceTemplate EmergencySourceTemplate;
	local StateObjectReference TargetCollectionRef;
	local XComGameState_DioCityDistrict District;
	local X2DioWorkerTemplate WorkerTemplate;
	local XComGameState_DioWorker Worker;
	local StrategyActionRewardData BonusRewardData;

	EmergencySourceTemplate = X2DioStrategyScheduleSourceTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate('ScheduleSource_Emergencies'));
	if (EmergencySourceTemplate == none)
	{
		`RedScreen("XComGameState_DioStrategyScheduler.BuildEmergencyWorker: invalid source template @gameplay");
		return false;
	}

	WorkerTemplate = EmergencySourceTemplate.SelectNextWorker(ModifyGameState);
	if (WorkerTemplate == none)
	{
		`RedScreen("XComGameState_DioStrategyScheduler.BuildEmergencyWorker: no WorkerTemplate selected from emergency source template @gameplay");
		return false;
	}

	TargetCollectionRef = class'DioWorkerAI'.static.GetWorkerAlignedHomeCollection(WorkerTemplate);
	Worker = WorkerTemplate.CreateInstanceFromTemplate(ModifyGameState, TargetCollectionRef);

	// Bonus rewards, if any
	if (EmergencySourceTemplate.SelectBonusReward(ModifyGameState, BonusRewardData))
	{
		Worker.AddBonusRewardData(ModifyGameState, BonusRewardData);
	}

	District = XComGameState_DioCityDistrict(ModifyGameState.ModifyStateObject(class'XComGameState_DioCityDistrict', DistrictRef.ObjectID));
	class'XComGameState_DioWorker'.static.PlaceWorker(ModifyGameState, Worker.GetReference(), District.EnemyWorkers);

	// Update district emergency tracking
	District.EmergencyStartTurn = `THIS_TURN;

	// Update City emergency tracking
	`DIOCITY.HandleEmergencyStarted(ModifyGameState);

	`XEVENTMGR.TriggerEvent('STRATEGY_DistrictEmergencyWorkerAdded_Submitted', Worker, District, ModifyGameState);
	return true;
}

//---------------------------------------------------------------------------------------
// Spawn a situation to unlock the Scavenger Market in a random district
static function bool BuildUnlockScavengerWorker(XComGameState ModifyGameState)
{
	local StateObjectReference DistrictRef;
	local XComGameState_DioCityDistrict District;
	local XComGameState_DioWorker Worker;

	// Build worker
	Worker = class'DioWorkerAI'.static.CreateWorkerByTemplateName(ModifyGameState, default.DefaultUnlockScavengerMarketWorker);
	if (Worker == none)
	{
		`RedScreen("XComGameState_DioStrategyScheduler.BuildUnlockScavengerWorker: could not build Worker @gameplay");
		return false;
	}


	DistrictRef = class'DioStrategyAI'.static.SelectNextWorkerDistrict(ModifyGameState);
	if (DistrictRef.ObjectID > 0)
	{
		District = XComGameState_DioCityDistrict(ModifyGameState.ModifyStateObject(class'XComGameState_DioCityDistrict', DistrictRef.ObjectID));
		if (District == none)
		{
			`RedScreen("XComGameState_DioStrategyScheduler.BuildUnlockScavengerWorker: could not find district to place new worker @gameplay");
			return false;
		}

		class'XComGameState_DioWorker'.static.PlaceWorker(ModifyGameState, Worker.GetReference(), District.EnemyWorkers);
	}

	`XEVENTMGR.TriggerEvent('STRATEGY_UnlockScavengerMarketWorkerSpawned_Submitted', Worker, District, ModifyGameState);
	return true;
}

//---------------------------------------------------------------------------------------
defaultproperties
{
}

// HELIOS END