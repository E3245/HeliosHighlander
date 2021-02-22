//---------------------------------------------------------------------------------------
//  FILE:		XComGameState_HeadquartersDio
//  AUTHOR:		dmcdonough  --  10/12/2018
//  PURPOSE:	This object represents the instance data for the player's Headquarters in
//				the Strategy Layer. The HQ is the entry point for all strategy resources
//				and actions.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameState_HeadquartersDio extends XComGameState_BaseObject
	native(Core)
	config(GameData)
	dependson(XComGameState_StrategyInventory);

var() privatewrite int		Credits;		// Total current Credits
var() privatewrite int		Intel;			// Total current Intel
var() privatewrite int		Elerium;		// Total current Elerium
var() StateObjectReference	Inventory;		// Ref to the HQ's current, available inventory of items.

// New Game config params
var() config name					StartingSquadName;	// The TQL squad list name to use when initializing the personnel for the headquarters

// Base
var() array<StateObjectReference>	Personnel;			// Non-squad, non-android base personnel
var() array<StateObjectReference>	Squad;				// All full unit characters
var() array<StateObjectReference>	APCRoster;			// Units assigned to the APC
var() array<StateObjectReference>	Androids;			// All Android units
var() StateObjectReference			Workers;			// DioWorkerCollection ref
var() StateObjectReference			SchedulerRef;		// Ref to the DioStrategyScheduler servicing the whole campaign
var() array<name>					APCUpgrades;		// Template names of all owned APC upgrades
var() array<name>					RandomizedUnlockableSoldierIDs;	// Pre-generated order of unlockable soldier IDs to choose from
var() int							PendingSquadUnlocks;		// Tracks if/how many Agents the player can unlock (in case they miss/dismiss the UI)

// Notifications
var() array<TStrategyNotificationData> Notifications;	// Collects the notification data objects to display on the HUD 

// Investigations
var() StateObjectReference	CurrentInvestigation;	// Current Investigation state object, tracking investigation progress and game effects in play.
var() int					CurrentTurn;			// Current campaign turn. Counts up from 1.

// XCOM HQ 
var() StateObjectReference	XCOMStoreRef;	// Ref to the SupplyMarket object used to supply the XCOM HQ marketplace
var() privatewrite array<StateObjectReference> AltMarketRefs;	// Refs to 0+ alternative markets currently available (e.g. Black Market, Skunkworks)
var() int								LastScavengerUnlockMissionTurn;		// Last campaign turn the Scavenger Unlock worker appeared
var() int								LastScavengerMarketTurn;			// Last campaign turn the Scavenger Market appeared
var() int								NextScavengerMarketTurn;			// Next campaign turn the Scavenger Market should appear (rolled each time it appears)
var() privatewrite int					ScavengerMarketCredits;				// Free buys remaining for use in the Scavenger Market
var() array<DioStrategyMarketCostMod>	MarketGroupDiscounts;		// Active discount to apply to items in various market groups

// Missions/Actions
var() StateObjectReference			MissionRef;		// Object reference to the currently selected mission. Used during squad selection and while the the mission is running
var() StateObjectReference			PrevTurnAPCActionRef;	// Ref to the APC-based action completed on the previous turn (if any)
var() StateObjectReference			APCDistrictRef;	// Dio City District where the APC (aka squad) is presently deployed (if any)
var() privatewrite array<name>		CompletedMissionActions;	// All X2DioStrategyActionTemplate names of all missions completed so far

// Research
var() privatewrite StateObjectReference			ActiveResearchRef;		// DioResearch projects currently in progress
var() privatewrite array<StateObjectReference>	InactiveResearchRefs;	// DioResearch projects currently in paused, ready to resume
var() privatewrite array<StateObjectReference>	CompletedResearchRefs;	// DioResearch projects completed
var() privatewrite array<name>					UnlockedResearchNames;	// Research templates available to start
var() privatewrite array<name>					UnlockedPrereqsNames;	// Prereq templates that have been met
var() array<StateObjectReference>				UnseenCompletedResearch;	// Refs to Assembly objects not yet seen by the player, source of notification
var() int							ResearchTurnsMod;			// Days Mod on how many turns are required for research
var() int							ResearchEleriumCostMod;		// % mod on Elerium cost to start research

// Training (universal)
var() privatewrite array<name>		UnlockedUniversalTraining;	// X2DioTrainingProgramTemplates available to be trained by any Agent

// Spec Ops
var() privatewrite array<name>		UnlockedSpecOps;			// X2DioSpecOpsTemplates available
var() privatewrite array<name>		UnseenUnlockedSpecOps;		// Temp tracking of Spec Ops as they are unlocked to highlight in UI

// Field Teams
var() privatewrite int				FreeFieldTeamBuilds;		// Num of free Field Team builds available
var() privatewrite array<IntWeightedDataName>	FieldTeamEffectNextAvailableTurn;	// Tracks when FT effects on cooldown will become available

// Campaign tracking
var() StateObjectReference			CampaignGoalRef;			// The active win/lose condition template
var() array<StateObjectReference>	CompletedInvestigations;	// Track references to completed Investigations, in the order they were completed
var() array<name>					CompletedActionTemplates;	// Track all scripted action templates completed during the campaign
var() array<StateObjectReference>	PrevTurnAnarchyUnrestResults;	// Track all changes to city anarchy or district unrest
var() privatewrite array<name>		Blackboard;					// Open-ended list of flags for tracking arbitrary game conditions

// Init Params
var config name				DefaultAndroidID;		// ID of Android soldier config to use by default when creating new Android units
var config int				StartingAndroids;		// Number of Androids to generate at campaign start
var config array<LootData>	StartingInventoryItems_Normal;		// Template names for items to be added to HQ inventory at campaign start for a non-tutorial game
var config array<LootData>	StartingInventoryItems_Tutorial;	// Template names for items to be added to HQ inventory at campaign start for a tutorial game
var config name				XCOMStoreTemplateName;	// X2DioStrategyMarketTemplate for XCOM Store

var init array<Name>		TacticalGameplayTags;	// A list of Tags representing modifiers to the tactical game rules

delegate OnItemSelectedCallback(optional int ItemObjectID = -1);

//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
static function SetupHeadquarters(XComGameState StartState, optional bool bTutorialEnabled = false, optional int Difficulty=1)
{
	local XComGameState_HeadquartersDio DioHQ;
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_DioStrategyScheduler Scheduler;
	local XComGameState_StrategyInventory NewInventory;
	local X2DioStrategyMarketTemplate XCOMStoreTemplate;
	local XComGameState_StrategyMarket SupplyMarket;
	local X2DioCampaignGoalTemplate GoalTemplate;
	local XComGameState_CampaignGoal NewCampaignGoal;
	local XComGameState_DioWorkerCollection WorkerCollection;	
	local LootData LootEntry;
	local name TempTemplateName;
	
	`log("XComGameState_HeadquartersDio: SetupHeadquarters Start",,'XCom_Strategy');
	StratMgr = `STRAT_TEMPLATE_MGR;

	// Create the HQ state object
	DioHQ = XComGameState_HeadquartersDio(StartState.CreateNewStateObject(class'XComGameState_HeadquartersDio'));

	// Create Inventories
	
	// Active
	NewInventory = XComGameState_StrategyInventory(StartState.CreateNewStateObject(class'XComGameState_StrategyInventory'));
	DioHQ.Inventory = NewInventory.GetReference();

	// Populate active Inventory with starting Items
	if (`TutorialEnabled)
	{
		foreach default.StartingInventoryItems_Tutorial(LootEntry)
		{
			NewInventory.AddLootDataItem(StartState, LootEntry);
		}
	}
	else
	{
		foreach default.StartingInventoryItems_Normal(LootEntry)
		{
			NewInventory.AddLootDataItem(StartState, LootEntry);
		}
	}

	// Create scheduler
	Scheduler = XComGameState_DioStrategyScheduler(StartState.CreateNewStateObject(class'XComGameState_DioStrategyScheduler'));
	DioHQ.SchedulerRef = Scheduler.GetReference();
	Scheduler.InitSchedule(StartState, Scheduler.DefaultStartingSchedule);

	// Create Worker Collection
	WorkerCollection = XComGameState_DioWorkerCollection(StartState.CreateNewStateObject(class'XComGameState_DioWorkerCollection'));
	DioHQ.Workers = WorkerCollection.GetReference();
	WorkerCollection.Init(StartState, DioHQ.GetReference());

	// Create XCOM Store
	XCOMStoreTemplate = X2DioStrategyMarketTemplate(StratMgr.FindStrategyElementTemplate(default.XCOMStoreTemplateName));
	if (XCOMStoreTemplate != none)
	{
		SupplyMarket = XCOMStoreTemplate.BuildStrategyMarket(StartState);
		DioHQ.XCOMStoreRef = SupplyMarket.GetReference();
	}

	// Campaign goal
	TempTemplateName = class'DioStrategyAI'.static.GetCampaignGoalTemplateName();
	GoalTemplate = X2DioCampaignGoalTemplate(StratMgr.FindStrategyElementTemplate(TempTemplateName));
	`assert(GoalTemplate != none);
	NewCampaignGoal = XComGameState_CampaignGoal(StartState.CreateNewStateObject(class'XComGameState_CampaignGoal', GoalTemplate));
	NewCampaignGoal.SetOverallCityUnrest(StartState, class'DioStrategyAI'.static.GetStartingCityAnarchy());
	DioHQ.CampaignGoalRef = NewCampaignGoal.GetReference();

	// Init resources
	DioHQ.Credits = class'DioStrategyAI'.static.GetStartingCredits();
	DioHQ.Intel = class'DioStrategyAI'.static.GetStartingIntel();
	DioHQ.Elerium = class'DioStrategyAI'.static.GetStartingElerium();

	// Init tutorial-only resources
	if (bTutorialEnabled)
	{
		DioHQ.FreeFieldTeamBuilds = 1;
	}

	`log("XComGameState_HeadquartersDio: SetupHeadquarters Complete",,'XCom_Strategy');
}

//---------------------------------------------------------------------------------------
// Set initial stats and build associated objects for a new campaign
// * Place code here that depends on the entire strategy game state being present (city, HQ, investigation, etc)
// * should only be called from XComGameStateContext_NewCampaignSetup
function SetupForNewCampaign(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local int i;

	`log("XComGameState_HeadquartersDio: SetupForNewCampaign",,'XCom_Strategy');
	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	// Create starting Androids
	for (i = 0; i < DioHQ.StartingAndroids; ++i)
	{
		DioHQ.CreateNewAndroid(ModifyGameState);
	}

	// Unlock access to research, spec ops for game start
	RefreshAllResearchUnlocks(ModifyGameState, true);
	RefreshAllSpecOpsUnlocks(ModifyGameState, true);

	// Generate unit unlock order
	class'DioStrategyAI'.static.GenerateRandomizedCharacterUnlockOptions(ModifyGameState, DioHQ.RandomizedUnlockableSoldierIDs);
}

//---------------------------------------------------------------------------------------
// Common check for whether all parts of starting a new campaign are completed
// Used for navigating in and out of tutorial phases
function bool IsCampaignSetupComplete()
{
	// Must have active Investigation
	if (CurrentInvestigation.ObjectID <= 0)
	{
		return false;
	}
	// Must have squad
	if (Squad.Length <= 0)
	{
		return false;
	}

	// All conditions passed
	return true;
}

//---------------------------------------------------------------------------------------
//				UPDATE
//---------------------------------------------------------------------------------------

// Apply all changes that occur when a new strategy turn begins
simulated function DoTurnUpkeep(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_DioResearch Research;
	local XComGameState_CampaignGoal CampaignGoal;
	local XComGameState_AnarchyUnrestResult AnarcyUnrestResult;
	local int i, CityUnrestChange;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	
	DioHQ.ClearAPCDistrict(ModifyGameState);
	DioHQ.RefreshAndroidPurchaseItems(ModifyGameState);

	// Active Research
	if (DioHQ.ActiveResearchRef.ObjectID > 0)
	{
		Research = XComGameState_DioResearch(ModifyGameState.ModifyStateObject(class'XComGameState_DioResearch', DioHQ.ActiveResearchRef.ObjectID));
		Research.DoTurnUpkeep(ModifyGameState);
		if (Research.IsComplete())
		{
			DioHQ.CompleteResearch(ModifyGameState, Research.GetReference());
		}
	}

	// Spec Ops updates
	DioHQ.UnseenUnlockedSpecOps.Length = 0;
	RefreshAllSpecOpsUnlocks(ModifyGameState);

	// Scavenger Market updates
	// If the scavenger market is active, check duration and remove
	if (IsScavengerMarketAvailable())
	{
		if (DioHQ.CurrentTurn >= DioHQ.LastScavengerMarketTurn + class'DioStrategyAI'.default.ScavengerMarketDuration)
		{
			DioHQ.RemoveScavengerMarket(ModifyGameState);
		}
	}
	// If scavenger market not active but unlocked and the cooldown has elapsed, spawn it
	else if (IsScavengerMarketUnlocked() && DioHQ.CurrentTurn >= DioHQ.NextScavengerMarketTurn)
	{
		class'DioStrategyAI'.static.CreateAndStartScavengerMarket(ModifyGameState);
	}

	// Campaign Goal upkeep
	CampaignGoal = DioHQ.GetCampaignGoal(ModifyGameState);
	if (CampaignGoal != none)
	{
		CampaignGoal.DoTurnUpkeep(ModifyGameState, CityUnrestChange);
	}

	// Clear all Anarchy/Unrest results not for the current turn
	for (i = DioHQ.PrevTurnAnarchyUnrestResults.Length - 1; i >= 0; i--)
	{
		if (DioHQ.PrevTurnAnarchyUnrestResults[i].ObjectID == 0)
		{
			DioHQ.PrevTurnAnarchyUnrestResults.Remove(i, 1);
		}
		else
		{
			AnarcyUnrestResult = XComGameState_AnarchyUnrestResult(ModifyGameState.ModifyStateObject(class'XComGameState_AnarchyUnrestResult', DioHQ.PrevTurnAnarchyUnrestResults[i].ObjectID));
			if (AnarcyUnrestResult == none || AnarcyUnrestResult.Turn != CurrentTurn)
			{
				DioHQ.PrevTurnAnarchyUnrestResults.Remove(i, 1);
			}
		}
	}
}

//---------------------------------------------------------------------------------------
//				INVENTORY
//---------------------------------------------------------------------------------------
function bool PutItemInInventory(XComGameState ModifyGameState, XComGameState_Item Item)
{
	local X2ItemTemplate ItemTemplate;
	local bool HQModified;

	ItemTemplate = Item.GetMyTemplate();

	if (ItemTemplate.OnAcquiredFn != None)
	{
		// Item indicates it should not be kept
		if (!ItemTemplate.OnAcquiredFn(ModifyGameState, Item))
		{
			return false;
		}
	}
	
	HQModified = true;
	AddItemToHQInventory(ModifyGameState, Item);

	// this item awards other items when acquired
	if (ItemTemplate.ResourceTemplateName != '' && ItemTemplate.ResourceQuantity > 0)
	{
		ItemTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate(ItemTemplate.ResourceTemplateName);
		Item = ItemTemplate.CreateInstanceFromTemplate(ModifyGameState);
		Item.Quantity = ItemTemplate.ResourceQuantity;

		if (Item != none)
		{
			HQModified = PutItemInInventory(ModifyGameState, Item);
		}
	}

	// Refresh all upgrades in case this new item affects them
	RefreshAllUpgradedItems(ModifyGameState);

	return HQModified;
}

//---------------------------------------------------------------------------------------
function AddItemToHQInventory(XComGameState ModifyGameState, XComGameState_Item ItemState)
{
	local XComGameState_StrategyInventory StratInventory;
	local int i;

	StratInventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', Inventory.ObjectID));

	// Scrub any empty items for cleanliness
	for (i = StratInventory.Items.Length - 1; i >= 0; i--)
	{
		if (StratInventory.Items[i].ObjectID == 0)
		{
			StratInventory.RemoveItemAtIndex(ModifyGameState, i);
		}
	}

	StratInventory.AddItem(ModifyGameState, ItemState.GetReference());
}

//---------------------------------------------------------------------------------------
// Populate a Commodity array of all inventory items for UI
function array<Commodity> GetInventoryItemCommodities(optional bool bIncludeEquippedItems = false, optional delegate<X2ItemTemplate.ValidationDelegate> Validator)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyInventory StratInventory;
	//local XComGameState_Unit Unit;
	//local array<StateObjectReference> AllUnits;
	local array<Commodity> AllItemCommodities;
	local Commodity TempCommodity;
	local StateObjectReference ItemRef;

	History = `XCOMHISTORY;
	StratInventory = XComGameState_StrategyInventory(History.GetGameStateForObjectID(Inventory.ObjectID));
	foreach StratInventory.Items(ItemRef)
	{
		if (StratInventory.BuildItemCommodity(ItemRef, TempCommodity, Validator))
		{
			AllItemCommodities.AddItem(TempCommodity);
		}
	}

	if (bIncludeEquippedItems)
	{
		// TODO figure out which items can be displayed in overall inventory:
		// - i.e. don't show unique, unequippable weapons (Zephyr's Gauntlets)
		// - don't show kevlar armor

		//GetAllUnitRefs(AllUnits);
		//for (i = 0; i < AllUnits.Length; ++i)
		//{
		//	Unit = XComGameState_Unit(History.GetGameStateForObjectID(AllUnits[i].ObjectID));
		//	foreach Unit.InventoryItems(ItemRef)
		//	{
		//		if (StratInventory.BuildItemCommodity(ItemRef, TempCommodity, Validator))
		//		{
		//			AllItemCommodities.AddItem(TempCommodity);
		//		}
		//	}
		//}
	}

	return AllItemCommodities;
}

//---------------------------------------------------------------------------------------
// Update availability of Android Unit Items in XCOM store
function RefreshAndroidPurchaseItems(XComGameState ModifyGameState)
{
	local XComGameState_StrategyMarket SupplyMarket;
	local X2ItemTemplate AndroidUnitItemTemplate;
	local int i, NumToOffer, CreditsCost;
	local bool bFirstAndroid;

	AndroidUnitItemTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate('AndroidUnitItem');
	if (AndroidUnitItemTemplate == none)
	{
		`RedScreen("XComGameState_HeadquartersDio.RefreshAndroidPurchaseItems: AndroidUnitItem template not found! @gameplay");
		return;
	}

	// Early out: androids not offered until research is complete
	if (HasCompletedResearchByName('DioResearch_AndroidUnits') == false)
	{
		NumToOffer = 0;
	}
	else
	{
		bFirstAndroid = Androids.Length == 0;
		CreditsCost = class'DioStrategyAI'.static.GetAndroidUnitPurchaseCreditsCost(bFirstAndroid);
		// Offer 0-1 at a time
		NumToOffer = class'DioStrategyAI'.default.MaxAndroids > Androids.Length ? 1 : 0;
	}

	SupplyMarket = XComGameState_StrategyMarket(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyMarket', XCOMStoreRef.ObjectID));
	for (i = SupplyMarket.ForSaleCommodities.Length - 1; i >= 0; i--)
	{
		if (SupplyMarket.ForSaleCommodities[i].TemplateName == 'AndroidUnitItem')
		{
			// If offering any, update first android found with proper price
			if (NumToOffer > 0)
			{
				SupplyMarket.ForSaleCommodities[i].Cost = CreditsCost;
				NumToOffer--;
			}
			else
			{
				SupplyMarket.ForSaleCommodities.Remove(i, 1);
			}
		}
	}

	// If no Android purchase was found, create one	
	if (NumToOffer > 0)
	{
		SupplyMarket.BuildForSaleItem(ModifyGameState, AndroidUnitItemTemplate, CreditsCost, , true);
		SupplyMarket.RefreshSort(ModifyGameState);
	}
}

//---------------------------------------------------------------------------------------
//				CAMPAIGN
//---------------------------------------------------------------------------------------

simulated function XComGameState_CampaignGoal GetCampaignGoal(optional XComGameState ModifyGameState=none)
{
	`assert(CampaignGoalRef.ObjectID > 0);

	if (ModifyGameState != none)
	{
		return XComGameState_CampaignGoal(ModifyGameState.ModifyStateObject(class'XComGameState_CampaignGoal', CampaignGoalRef.ObjectID));
	}

	return XComGameState_CampaignGoal(`XCOMHISTORY.GetGameStateForObjectID(CampaignGoalRef.ObjectID));
}

//---------------------------------------------------------------------------------------
function bool HasCompletedInvestigation(name InvestigationTemplateName)
{
	local XComGameStateHistory History;
	local XComGameState_Investigation CompletedInv;
	local int i;

	History = `XCOMHISTORY;
	for (i = 0; i < CompletedInvestigations.Length; ++i)
	{
		CompletedInv = XComGameState_Investigation(History.GetGameStateForObjectID(CompletedInvestigations[i].ObjectID));
		if (CompletedInv.GetMyTemplateName() == InvestigationTemplateName)
		{
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
function OnMissionActionComplete(XComGameState ModifyGameState, name MissionActionTemplateName)
{
	local XComGameState_HeadquartersDio DioHQ;
	local int NumMissionsComplete;
	local bool bUnlock;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	
	DioHQ.CompletedMissionActions.AddItem(MissionActionTemplateName);
	NumMissionsComplete = DioHQ.CompletedMissionActions.Length;
	
	// Check for mission-count thresholds to unlock new Agents
	if (`TutorialEnabled)
	{
		NumMissionsComplete--; // Drop count by 1 to account for tutorial mission, it doesn't count for Agent unlocks
	}
	// #6 Agent: on completing 4th mission
	if (DioHQ.Squad.Length <= 5)
	{
		if (NumMissionsComplete >= 4)
		{
			bUnlock = true;
		}
	}

	if (bUnlock)
	{
		DioHQ.GrantSquadUnitUnlock(ModifyGameState);
	}
}

//---------------------------------------------------------------------------------------
function XComGameState_StrategyAction GetPreviousTurnAction(optional XComGameState ModifyGameState)
{
	if (PrevTurnAPCActionRef.ObjectID <= 0)
	{
		return none;
	}

	if (ModifyGameState != none)
	{
		return XComGameState_StrategyAction(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyAction', PrevTurnAPCActionRef.ObjectID));
	}
	return XComGameState_StrategyAction(`XCOMHISTORY.GetGameStateForObjectID(PrevTurnAPCActionRef.ObjectID));
}

//---------------------------------------------------------------------------------------
//				RESOURCES
//---------------------------------------------------------------------------------------
simulated function ChangeCredits(XComGameState ModifyGameState, int Delta)
{
	local XComGameState_HeadquartersDio DioHQ;

	if (Delta != 0)
	{
		DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
		DioHQ.Credits = Clamp(Credits + Delta, 0, Credits + Abs(Delta));
		`XEVENTMGR.TriggerEvent('STRATEGY_CreditsChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
		`XEVENTMGR.TriggerEvent('STRATEGY_AnyResourceChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
	}
}

//---------------------------------------------------------------------------------------
simulated function ChangeIntel(XComGameState ModifyGameState, int Delta)
{
	local XComGameState_HeadquartersDio DioHQ;

	if (Delta != 0)
	{
		DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
		DioHQ.Intel = Clamp(Intel + Delta, 0, Intel + Abs(Delta));
		`XEVENTMGR.TriggerEvent('STRATEGY_IntelChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
		`XEVENTMGR.TriggerEvent('STRATEGY_AnyResourceChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
	}
}

//---------------------------------------------------------------------------------------
simulated function ChangeElerium(XComGameState ModifyGameState, int Delta)
{
	local XComGameState_HeadquartersDio DioHQ;

	if (Delta != 0)
	{
		DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
		DioHQ.Elerium = Clamp(Elerium + Delta, 0, Elerium + Abs(Delta));
		`XEVENTMGR.TriggerEvent('STRATEGY_EleriumChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
		`XEVENTMGR.TriggerEvent('STRATEGY_AnyResourceChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
	}
}

//---------------------------------------------------------------------------------------
simulated function ChangeResources(XComGameState ModifyGameState, optional int CreditsDelta, optional int IntelDelta, optional int EleriumDelta)
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	if (CreditsDelta != 0)
	{
		DioHQ.Credits = Clamp(Credits + CreditsDelta, 0, Credits + Abs(CreditsDelta));
		`XEVENTMGR.TriggerEvent('STRATEGY_CreditsChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
	}
	if (IntelDelta != 0)
	{
		DioHQ.Intel = Clamp(Intel + IntelDelta, 0, Intel + Abs(IntelDelta));
		`XEVENTMGR.TriggerEvent('STRATEGY_IntelChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
	}
	if (EleriumDelta != 0)
	{
		DioHQ.Elerium = Clamp(Elerium + EleriumDelta, 0, Elerium + Abs(EleriumDelta));
		`XEVENTMGR.TriggerEvent('STRATEGY_EleriumChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
	}

	`XEVENTMGR.TriggerEvent('STRATEGY_AnyResourceChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
//				SQUAD
//---------------------------------------------------------------------------------------

// Instantiate a new full unit and add it to the HQ squad
simulated function XComGameState_Unit CreateSquadUnit(XComGameState ModifyGameState, name SoldierIDName)
{
	local X2CharacterTemplateManager CharMgr;
	local XComGameState_HeadquartersDio DioHQ;
	local X2CharacterTemplate CharacterTemplate;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local XComGameState_Unit Unit;
	local ConfigurableSoldier SoldierConfig;
	local int i, TQLIndex, index; // Temp

	if (SoldierIDName == '')
	{
		return none;
	}

	CharMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	//Extract the config data for this soldier / squad member
	TQLIndex = class'UITacticalQuickLaunch_MapData'.static.GetConfigurableSoldierSpec(SoldierIDName, SoldierConfig);
	if (TQLIndex < 0)
	{
		`warn("XComGameState_HeadquartersDio.CreateSquadCharacter: could not find a ConfigurableSoldierSpec with name '" $ SoldierIDName $ "'. Check the UITacticalQuickLaunch_MapData.Soldiers INI file array. @gameplay");
		return none;
	}

	// Early out: no dupe units of the same class
	for (index = 0; index < DioHQ.Squad.Length; ++index)
	{
		Unit = XComGameState_Unit(ModifyGameState.ModifyStateObject(class'XComGameState_Unit', DioHQ.Squad[index].ObjectID));
		if (Unit.GetSoldierClassTemplateName() == SoldierConfig.SoldierClassTemplate)
		{
			return none;
		}
	}

	// Pivot: separate path to create Androids
	if (SoldierConfig.SoldierClassTemplate == 'SoldierClass_Android')
	{
		return DioHQ.CreateNewAndroid(ModifyGameState, SoldierIDName);
	}

	//Locate the associated character template
	CharacterTemplate = CharMgr.FindCharacterTemplate(SoldierConfig.CharacterTemplate);
	if (CharacterTemplate == none)
	{
		`warn("XComGameState_HeadquartersDio.CreateSquadCharacter: '" $ SoldierConfig.CharacterTemplate $ "' is not a valid template. @gameplay");
		return none;
	}

	//Instantiate a unit state object based on the template
	Unit = CharacterTemplate.CreateInstanceFromTemplate(ModifyGameState);
	if (Unit == none)
	{
		`warn("XComGameState_HeadquartersDio.CreateSquadCharacter: failed to instantiate a unit from character template '" $ CharacterTemplate.DataName $ "'. @gameplay");
		return none;
	}

	//Assign the unit its soldier class
	Unit.SetSoldierClassTemplate(SoldierConfig.SoldierClassTemplate); //Inventory needs this to work	

	// Init Scars deck from soldier class		
	SoldierClassTemplate = Unit.GetSoldierClassTemplate();
	if (SoldierClassTemplate != none)
	{
		SoldierClassTemplate.InitUnitScarsDeck(Unit);
	}

	//dakota.lemaster: Setup the character for the campaign, beginning at rank 0
	Unit.StartingRank = 0;
	Unit.ResetSoldierRank(true);
	Unit.ApplyInventoryLoadout(ModifyGameState);
	
	// Apply any already-owned universal upgrades to the new unit's loadout
	for (i = 0; i < Unit.InventoryItems.Length; ++i)
	{
		DioHQ.ApplyUniversalUpgradesToItem(Unit.InventoryItems[i], ModifyGameState);
	}
	
	// Give the soldier their starting abilities
	for (index = 0; index < Unit.GetRankAbilities(0).Length; ++index)
	{
		Unit.BuySoldierProgressionAbility(ModifyGameState, 0, index);
	}
	// Unlock starting training
	Unit.UnlockTrainingAtRank(0);

	// Set soldier info and appearance
	Unit.SetSoldierDataFromClassTemplate();

	// Add to Squad
	DioHQ.Squad.AddItem(Unit.GetReference());

	// Also add to APC Roster if not yet full
	if (DioHQ.APCRoster.Length < 4)
	{
		SetUnitOnAPC(ModifyGameState, Unit.GetReference());
	}

	// Track for meta content
	`XPROFILESETTINGS.HasUsedAgent(SoldierClassTemplate.DataName, true);

	`XEVENTMGR.TriggerEvent('STRATEGY_SquadUnitCreated_Submitted', Unit, DioHQ, ModifyGameState);

	return Unit;
}

//---------------------------------------------------------------------------------------
// Set whether a unit is on the APC roster or not
function SetUnitOnAPC(XComGameState ModifyGameState, StateObjectReference UnitRef, optional bool bOnAPC=true, optional int SlotIndex=INDEX_NONE)
{
	local XComGameState_HeadquartersDio DioHQ;
	local int Index;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	// Add to APC
	if (bOnAPC)
	{
		if (DioHQ.APCRoster.Find('ObjectID', UnitRef.ObjectID) == INDEX_NONE)
		{
			if (SlotIndex != INDEX_NONE)
			{
				SlotIndex = Clamp(SlotIndex, 0, APCRoster.Length - 1);
				DioHQ.APCRoster.InsertItem(SlotIndex, UnitRef);
			}
			else
			{
				DioHQ.APCRoster.AddItem(UnitRef);
			}

			if (DioHQ.APCRoster.Length > 4)
			{
				`RedScreen("DioHQ warning: APC roster should not contain more than 4 entries! @gameplay");
			}

			`XEVENTMGR.TriggerEvent('STRATEGY_APCRosterChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
			return;
		}
	}
	// Remove from APC
	else
	{
		Index = DioHQ.APCRoster.Find('ObjectID', UnitRef.ObjectID);
		if (Index != INDEX_NONE)
		{
			DioHQ.APCRoster.Remove(Index, 1);
			`XEVENTMGR.TriggerEvent('STRATEGY_APCRosterChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
			return;
		}
	}
}

//---------------------------------------------------------------------------------------
function bool IsUnitOnAPC(StateObjectReference UnitRef, optional out int RosterIndex)
{
	RosterIndex = APCRoster.Find('ObjectID', UnitRef.ObjectID);
	return RosterIndex != INDEX_NONE;
}

//---------------------------------------------------------------------------------------
function GetNonAPCRosterUnits(out array<StateObjectReference> OutUnitRefs)
{
	local int i;

	OutUnitRefs.Length = 0;
	for (i = 0; i < Squad.Length; ++i)
	{
		if (APCRoster.Find('ObjectID', Squad[i].ObjectID) == INDEX_NONE)
		{
			OutUnitRefs.AddItem(Squad[i]);
		}
	}
}

//---------------------------------------------------------------------------------------
function GrantSquadUnitUnlock(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	DioHQ.PendingSquadUnlocks++;

	`XEVENTMGR.TriggerEvent('STRATEGY_SquadUnitUnlockReady_Submitted', DioHQ, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
function ResolveSquadUnitUnlock(XComGameState ModifyGameState, optional bool bClear=true)
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	
	if (bClear)
	{
		DioHQ.PendingSquadUnlocks = 0;
	}
	else
	{
		DioHQ.PendingSquadUnlocks--;
	}

	`XEVENTMGR.TriggerEvent('STRATEGY_SquadUnitUnlockResolved_Submitted', DioHQ, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
// Compose an array of refs to all units including Agents and Androids
function GetAllUnitRefs(out array<StateObjectReference> OutRefs)
{
	local StateObjectReference Ref;
	OutRefs.Length = 0;
	foreach Squad(Ref)
	{
		OutRefs.AddItem(Ref);
	}
	foreach Androids(Ref)
	{
		OutRefs.AddItem(Ref);
	}
}

//---------------------------------------------------------------------------------------
//				ANDROIDS
//---------------------------------------------------------------------------------------

simulated function XComGameState_Unit CreateNewAndroid(XComGameState ModifyGameState, optional name AndroidIDName)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyInventory StratInventory;
	local X2ItemTemplateManager ItemTemplateManager;
	local XComGameState_Unit AndroidUnit;
	local ConfigurableSoldier SoldierConfig;
	local X2CharacterTemplate CharacterTemplate;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local array<name> StartingEquipmentTemplateNames;
	local XComGameState_Item ItemInstance;
	local X2EquipmentTemplate EquipmentTemplate;
	local name EquipmentName;
	local int i, TQLIndex;	// Temp

	if (AndroidIDName == '')
	{
		AndroidIDName = default.DefaultAndroidID;
	}

	//Extract the config data for this soldier / squad member
	TQLIndex = class'UITacticalQuickLaunch_MapData'.static.GetConfigurableSoldierSpec(AndroidIDName, SoldierConfig);
	if (TQLIndex < 0)
	{
		`warn("XComGameState_HeadquartersDio.CreateNewAndroid: could not find a ConfigurableSoldierSpec with name '" $ AndroidIDName $ "'. Check the UITacticalQuickLaunch_MapData.Soldiers INI file array. @gameplay");
		return none;
	}

	//Locate the associated character template
	CharacterTemplate = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager().FindCharacterTemplate(SoldierConfig.CharacterTemplate);
	if (CharacterTemplate == none)
	{
		`warn("XComGameState_HeadquartersDio.CreateNewAndroid: '" $ SoldierConfig.CharacterTemplate $ "' is not a valid template. @gameplay");
		return none;
	}

	//Instantiate a unit state object based on the template
	AndroidUnit = CharacterTemplate.CreateInstanceFromTemplate(ModifyGameState);
	if (AndroidUnit == none)
	{
		`warn("XComGameState_HeadquartersDio.CreateNewAndroid: failed to instantiate a unit from character template '" $ CharacterTemplate.DataName $ "'. @gameplay");
		return none;
	}

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	StratInventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', DioHQ.Inventory.ObjectID));

	// Assign the unit its soldier class. Inventory needs this to work	
	AndroidUnit.SetSoldierClassTemplate(SoldierConfig.SoldierClassTemplate); 

	// Helper method that should configure this unit
	class'UITacticalQuickLaunch_MapData'.static.UpdateUnit(TQLIndex, AndroidUnit, ModifyGameState, false, false);

	// Create standard weapons of every type linked to the Android (for equip changing)
	for (i = 0; i <  class'X2SoldierClassTemplateManager'.default.AndroidWeaponTemplates.Length; ++i)
	{
		EquipmentTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate(class'X2SoldierClassTemplateManager'.default.AndroidWeaponTemplates[i]));
		if (EquipmentTemplate == none)
		{
			continue;
		}

		ItemInstance = EquipmentTemplate.CreateInstanceFromTemplate(ModifyGameState);
		ItemInstance.LinkedEntity = AndroidUnit.GetReference();
		// Equip the first weapon in the list of possibles, otherwise put in HQ inventory for option to equip
		if (i == 0) 
		{
			AndroidUnit.AddItemToInventory(ItemInstance, EquipmentTemplate.InventorySlot, ModifyGameState);
		}
		else
		{
			StratInventory.AddItem(ModifyGameState, ItemInstance.GetReference());
		}
	}

	// Apply starting equipment, checking for upgrades first
	StartingEquipmentTemplateNames.AddItem(class'UITacticalQuickLaunch_MapData'.default.Soldiers[TQLIndex].ArmorTemplate);
	StartingEquipmentTemplateNames.AddItem(class'UITacticalQuickLaunch_MapData'.default.Soldiers[TQLIndex].BreachItemTemplate);
	StartingEquipmentTemplateNames.AddItem(class'UITacticalQuickLaunch_MapData'.default.Soldiers[TQLIndex].UtilityItem1Template);
	StartingEquipmentTemplateNames.AddItem(class'UITacticalQuickLaunch_MapData'.default.Soldiers[TQLIndex].UtilityItem2Template);
	
	foreach StartingEquipmentTemplateNames(EquipmentName)
	{
		EquipmentTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate(EquipmentName));
		DioHQ.GetUpgradedEquipmentTemplate(EquipmentTemplate, ModifyGameState);
		ItemInstance = EquipmentTemplate.CreateInstanceFromTemplate(ModifyGameState);
		AndroidUnit.AddItemToInventory(ItemInstance, EquipmentTemplate.InventorySlot, ModifyGameState);
	}

	// Apply any already-owned universal upgrades to the new unit's loadout
	for (i = 0; i < AndroidUnit.InventoryItems.Length; ++i)
	{
		DioHQ.ApplyUniversalUpgradesToItem(AndroidUnit.InventoryItems[i], ModifyGameState);
	}
	
	// Generate name
	SoldierClassTemplate = AndroidUnit.GetSoldierClassTemplate();
	SoldierClassTemplate.SetAndroidCharacterAppearance(AndroidUnit);

	// Add to HQ
	DioHQ.Androids.AddItem(AndroidUnit.GetReference());

	`XEVENTMGR.TriggerEvent('STRATEGY_NewAndroidUnit_Submitted', AndroidUnit, DioHQ, ModifyGameState);

	return AndroidUnit;
}

//---------------------------------------------------------------------------------------
//				APC (ARMORED PERSONNEL CARRIER)
//---------------------------------------------------------------------------------------

// Is the APC available to assign to a strategy action at this time?
simulated function bool IsAPCReady()
{
	return APCDistrictRef.ObjectID <= 0;
}

//---------------------------------------------------------------------------------------
simulated function SetAPCDistrict(XComGameState ModifyGameState, StateObjectReference InAPCDistrict)
{
	local XComGameState_HeadquartersDio DioHQ;

	if (InAPCDistrict.ObjectID > 0)
	{
		DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
		DioHQ.APCDistrictRef = InAPCDistrict;
		`XEVENTMGR.TriggerEvent('STRATEGY_APCDistrictChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
	}
}

//---------------------------------------------------------------------------------------
simulated function ClearAPCDistrict(XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	DioHQ.APCDistrictRef.ObjectID = 0;
	`XEVENTMGR.TriggerEvent('STRATEGY_APCDistrictChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
simulated function bool GetAPCDistrict(out XComGameState_DioCityDistrict OutDistrict, optional XComGameState ModifyGameState)
{
	if (APCDistrictRef.ObjectID <= 0)
	{
		return false;
	}

	if (ModifyGameState != none)
	{
		OutDistrict = XComGameState_DioCityDistrict(ModifyGameState.ModifyStateObject(class'XComGameState_DioCityDistrict', APCDistrictRef.ObjectID));
	}
	else
	{
		OutDistrict = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(APCDistrictRef.ObjectID));
	}
	return true;
}

//---------------------------------------------------------------------------------------
function bool HasAPCUpgrade(name APCUpgradeTemplateName)
{
	return APCUpgrades.Find(APCUpgradeTemplateName) != INDEX_NONE;
}

//---------------------------------------------------------------------------------------
function int CountOwnedAPCUpgrades(name APCUpgradeTemplateName)
{
	local name OwnedUpgradeName;
	local int NumOwned;

	foreach APCUpgrades(OwnedUpgradeName)
	{
		if (OwnedUpgradeName == APCUpgradeTemplateName)
		{
			NumOwned++;
		}
	}

	return NumOwned;
}

//---------------------------------------------------------------------------------------
// Checks blocking/pereq conditions only, not cost
function bool CanAddAPCUpgrade(name APCUpgradeTemplateName)
{
	local X2DioAPCUpgradeTemplate UpgradeTemplate;
	local int NumOwned;

	UpgradeTemplate = X2DioAPCUpgradeTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(APCUpgradeTemplateName));
	if (UpgradeTemplate == none)
	{
		return false;
	}

	NumOwned = CountOwnedAPCUpgrades(APCUpgradeTemplateName);

	// Already own max number of these
	if (NumOwned >= UpgradeTemplate.NumAllowed)
	{
		return false;
	}
	
	return true;
}

//---------------------------------------------------------------------------------------
function bool CanAffordCommodity(Commodity InCommodity)
{
	return (Credits >= InCommodity.Cost && Intel >= InCommodity.IntelCost && Elerium >= InCommodity.EleriumCost);
}

//---------------------------------------------------------------------------------------
//				WORKERS
//---------------------------------------------------------------------------------------

simulated function XComGameState_DioWorkerCollection GetWorkers(optional XComGameState ModifyGameState)
{
	if (ModifyGameState != none)
	{
		return XComGameState_DioWorkerCollection(ModifyGameState.ModifyStateObject(class'XComGameState_DioWorkerCollection', Workers.ObjectID));
	}

	return XComGameState_DioWorkerCollection(`XCOMHISTORY.GetGameStateForObjectID(Workers.ObjectID));
}

//---------------------------------------------------------------------------------------
//				MARKETS
//---------------------------------------------------------------------------------------
function XComGameState_StrategyMarket AddAlternativeStrategyMarket(XComGameState ModifyGameState, StateObjectReference MarketRef)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyMarket Market;

	Market = XComGameState_StrategyMarket(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyMarket', MarketRef.ObjectID));
	if (Market == none)
	{
		`RedScreen("XComGameState_HeadquartersDio.AddStrategyMarket: MarketRef invalid. @gameplay");
		return none;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	DioHQ.AltMarketRefs.AddItem(MarketRef);

	`XEVENTMGR.TriggerEvent('STRATEGY_AltStrategyMarketAdded_Submitted', Market, DioHQ, ModifyGameState);

	return Market;
}

function XComGameState_StrategyMarket BuildAndAddAlternativeStrategyMarket(XComGameState ModifyGameState, name MarketTemplateName)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyMarket Market;
	local X2DioStrategyMarketTemplate MarketTemplate;

	MarketTemplate = X2DioStrategyMarketTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(MarketTemplateName));

	if (MarketTemplate == none)
	{
		`RedScreen("XComGameState_HeadquartersDio.BuildAndAddStrategyMarket: MarketTemplateName invalid. @gameplay");
		return none;
	}

	Market = MarketTemplate.BuildStrategyMarket(ModifyGameState);
	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	DioHQ.AltMarketRefs.AddItem(Market.GetReference());

	`XEVENTMGR.TriggerEvent('STRATEGY_AltStrategyMarketAdded_Submitted', Market, DioHQ, ModifyGameState);

	return Market;
}


//---------------------------------------------------------------------------------------
function RemoveAlternativeStrategyMarket(XComGameState ModifyGameState, StateObjectReference MarketRef, optional bool bDestroyMarketObject=true)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyMarket Market;
	local int Idx;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	Idx = DioHQ.AltMarketRefs.Find('ObjectID', MarketRef.ObjectID);
	
	// Safe exit: market not found
	if (Idx == INDEX_NONE)
	{
		return;
	}

	// Remove from HQ collection
	DioHQ.AltMarketRefs.Remove(Idx, 1);

	Market = XComGameState_StrategyMarket(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyMarket', MarketRef.ObjectID));
	`XEVENTMGR.TriggerEvent('STRATEGY_AltStrategyMarketRemoved_Submitted', Market, DioHQ, ModifyGameState);

	// Remove from history (if applicable)
	if (bDestroyMarketObject)
	{
		ModifyGameState.RemoveStateObject(MarketRef.ObjectID);
	}
}

//---------------------------------------------------------------------------------------
function XComGameState_StrategyMarket GetScavengerMarket(optional XComGameState ModifyGameState)
{
	local XComGameState_StrategyMarket Market;

	Market = FindAlternativeMarketByName('Market_ScavengerMarket_Act1', ModifyGameState);

	if (Market == none)
	{
		Market = FindAlternativeMarketByName('Market_ScavengerMarket_Act2', ModifyGameState);
	}

	if (Market == none)
	{
		Market = FindAlternativeMarketByName('Market_ScavengerMarket_Act3', ModifyGameState);
	}

	return Market;
}

//---------------------------------------------------------------------------------------
private function RemoveScavengerMarket(XComGameState ModifyGameState)
{
	local XComGameState_StrategyMarket Market;

	Market = FindAlternativeMarketByName('Market_ScavengerMarket_Act1');
	if (Market != none)
	{
		RemoveAlternativeStrategyMarket(ModifyGameState, Market.GetReference(), true);
	}

	Market = FindAlternativeMarketByName('Market_ScavengerMarket_Act2');
	if (Market != none)
	{
		RemoveAlternativeStrategyMarket(ModifyGameState, Market.GetReference(), true);
	}

	Market = FindAlternativeMarketByName('Market_ScavengerMarket_Act3');
	if (Market != none)
	{
		RemoveAlternativeStrategyMarket(ModifyGameState, Market.GetReference(), true);
	}

	RemoveNotificationByType(eSNT_ScavengerMarketOpen);
	`STRATPRES.ScavengerMarketAttentionCount = 0;
}

//---------------------------------------------------------------------------------------
function bool CanSpawnScavengerMarketWorker()
{
	// Early out: already did it!
	if (IsScavengerMarketUnlocked())
	{
		return false;
	}

	if (CurrentTurn < class'DioStrategyAI'.default.MinTurnsUntilScavengerMarket)
	{
		return false;
	}

	if (CurrentTurn - LastScavengerUnlockMissionTurn < class'DioStrategyAI'.default.ScavengerMarketUnlockMissionInterval)
	{
		return false;
	}

	return true;
}

//---------------------------------------------------------------------------------------
function bool IsScavengerMarketUnlocked()
{
	return LastScavengerMarketTurn >= 0;
}

//---------------------------------------------------------------------------------------
function bool IsScavengerMarketAvailable(optional XComGameState ModifyGameState)
{
	return (GetScavengerMarket(ModifyGameState) != none);
}

//---------------------------------------------------------------------------------------
function ChangeScavengerMarketCredits(XComGameState ModifyGameState, int Quantity)
{
	local XComGameState_HeadquartersDio DioHQ;

	if (Quantity == 0)
	{
		return;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	DioHQ.ScavengerMarketCredits += Quantity;

	`XEVENTMGR.TriggerEvent('STRATEGY_ScavengerMarketCreditsChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
// Searches AltMarkets for one with the matching template, or returns none if not found
function XComGameState_StrategyMarket FindAlternativeMarketByName(name MarketTemplateName, optional XComGameState ModifyGameState)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyMarket Market;
	local int i;

	History = `XCOMHISTORY;
	
	for (i = 0; i < AltMarketRefs.Length; ++i)
	{
		// Find market
		if (ModifyGameState != none)
		{
			Market = XComGameState_StrategyMarket(ModifyGameState.GetGameStateForObjectID(AltMarketRefs[i].ObjectID));
		}
		if (Market == none)
		{
			Market = XComGameState_StrategyMarket(History.GetGameStateForObjectID(AltMarketRefs[i].ObjectID));
		}

		if (Market.GetMyTemplateName() != MarketTemplateName)
		{
			continue;
		}

		if (ModifyGameState != none)
		{
			return XComGameState_StrategyMarket(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyMarket', Market.ObjectID));
		}
		else
		{
			return Market;
		}
	}

	return none;
}

//---------------------------------------------------------------------------------------
function AddMarketGroupDiscount(XComGameState ModifyGameState, name MarketGroup, int Discount, optional string SourceString)
{
	local XComGameState_HeadquartersDio DioHQ;
	local DioStrategyMarketCostMod NewDiscount;
	local int Index;

	if (MarketGroup == '')
	{
		return;
	}

	if (Discount <= 0)
	{
		return;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	Index = DioHQ.MarketGroupDiscounts.Find('MarketGroupID', MarketGroup);
	if (Index != INDEX_NONE)
	{
		DioHQ.MarketGroupDiscounts[Index].CostMod += Discount;
	}
	else
	{
		NewDiscount.MarketGroupID = MarketGroup;
		NewDiscount.CostMod = Discount;
		NewDiscount.SourceDisplaySummary = SourceString;
		DioHQ.MarketGroupDiscounts.AddItem(NewDiscount);
	}

	`XEVENTMGR.TriggerEvent('STRATEGY_MarketGroupDiscountAdded_Submitted', DioHQ, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
function RemoveMarketGroupDiscount(XComGameState ModifyGameState, name MarketGroup)
{
	local XComGameState_HeadquartersDio DioHQ;
	local int Index;

	if (MarketGroup == '')
	{
		return;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	Index = DioHQ.MarketGroupDiscounts.Find('MarketGroupID', MarketGroup);
	if (Index != INDEX_NONE)
	{
		DioHQ.MarketGroupDiscounts.Remove(Index, 1);
	}

	`XEVENTMGR.TriggerEvent('STRATEGY_MarketGroupDiscountRemoved_Submitted', DioHQ, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
function bool FindMarketGroupDiscount(name MarketGroup, optional out int Discount, optional out string SourceString)
{
	local int Index;

	if (MarketGroup == '')
	{
		return false;
	}

	Index = MarketGroupDiscounts.Find('MarketGroupID', MarketGroup);
	if (Index == INDEX_NONE)
	{
		return false;
	}

	Discount = MarketGroupDiscounts[Index].CostMod;
	SourceString = MarketGroupDiscounts[Index].SourceDisplaySummary;
	return true;
}

//---------------------------------------------------------------------------------------
//				RESEARCH
//---------------------------------------------------------------------------------------

function XComGameState_DioResearch StartResearch(XComGameState ModifyGameState, X2DioResearchTemplate ResearchTemplate)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_DioResearch Research;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	// Early out: can't start this now
	if (DioHQ.CanStartResearch(ResearchTemplate) == false)
	{
		return none;
	}

	// Cancel existing research
	if (DioHQ.ActiveResearchRef.ObjectID > 0)
	{
		Research = XComGameState_DioResearch(ModifyGameState.ModifyStateObject(class'XComGameState_DioResearch', DioHQ.ActiveResearchRef.ObjectID));
		Research.CancelResearch(ModifyGameState);
		DioHQ.ActiveResearchRef.ObjectID = 0;
	}
	
	// Create and start new project
	Research = ResearchTemplate.CreateInstanceFromTemplate(ModifyGameState);
	DioHQ.ActiveResearchRef = Research.GetReference();
	Research.StartResearch(ModifyGameState);

	// Refresh Assembly notifications
	class'DioStrategyNotificationsHelper'.static.RefreshAssemblyNotifications(ModifyGameState);

	`XEVENTMGR.TriggerEvent('STRATEGY_ResearchStarted_Submitted', Research, DioHQ, ModifyGameState);
	return Research;
}

//---------------------------------------------------------------------------------------
function bool CanStartResearch(X2DioResearchTemplate ResearchTemplate)
{
	local XComGameStateHistory History;
	local XComGameState_DioResearch Research;
	local StateObjectReference ResearchRef;

	if (ResearchTemplate == none)
	{
		return false;
	}

	History = `XCOMHISTORY;

	// Research not unlocked
	if (UnlockedResearchNames.Find(ResearchTemplate.DataName) == INDEX_NONE)
	{
		return false;
	}

	// Already completed this
	foreach CompletedResearchRefs(ResearchRef)
	{
		Research = XComGameState_DioResearch(History.GetGameStateForObjectID(ResearchRef.ObjectID));
		if (Research.GetMyTemplate() == ResearchTemplate)
		{
			return false;
		}
	}

	// Currently in progress on this
	Research = XComGameState_DioResearch(History.GetGameStateForObjectID(ActiveResearchRef.ObjectID));
	if (Research.GetMyTemplate() == ResearchTemplate)
	{
		return false;
	}

	// All conditions passed
	return true;
}

//---------------------------------------------------------------------------------------
function CompleteResearch(XComGameState ModifyGameState, StateObjectReference ResearchRef)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_DioResearch Research;
	local StateObjectReference EmptyRef;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	if (DioHQ.ActiveResearchRef == ResearchRef)
	{
		DioHQ.ActiveResearchRef = EmptyRef;
	}

	DioHQ.CompletedResearchRefs.AddItem(ResearchRef);

	Research = XComGameState_DioResearch(ModifyGameState.ModifyStateObject(class'XComGameState_DioResearch', ResearchRef.ObjectID));
	Research.CompleteResearch(ModifyGameState);
}

//---------------------------------------------------------------------------------------
function bool HasCompletedResearchByName(name ResearchName)
{
	local XComGameStateHistory History;
	local XComGameState_DioResearch Research;
	local StateObjectReference ResearchRef;

	History = `XCOMHISTORY;

	foreach CompletedResearchRefs(ResearchRef)
	{
		Research = XComGameState_DioResearch(History.GetGameStateForObjectID(ResearchRef.ObjectID));
		if (Research.GetMyTemplateName() == ResearchName)
		{
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
// Returns all unlocked research that has not been completed (including in progress)
function array<name> GetAvailableResearchNames(optional name UICategory='')
{
	local array<name> Results;
	local X2StrategyElementTemplateManager StratMgr;
	local X2DioResearchTemplate ResearchTemplate;
	local name ResearchName;

	StratMgr = `STRAT_TEMPLATE_MGR;

	foreach UnlockedResearchNames(ResearchName)
	{
		if (HasCompletedResearchByName(ResearchName))
		{
			continue;
		}

		if (UICategory != '')
		{
			ResearchTemplate = X2DioResearchTemplate(StratMgr.FindStrategyElementTemplate(ResearchName));
			if (ResearchTemplate.UICategory != UICategory)
			{
				continue;
			}
		}

		Results.AddItem(ResearchName);
	}

	return Results;
}

//---------------------------------------------------------------------------------------
function bool CanAffordResearch(X2DioResearchTemplate ResearchTemplate, optional out string UnavailableTipString)
{
	local int NumLowResources;

	UnavailableTipString = "";

	if (Credits < ResearchTemplate.CreditsCost)
	{
		NumLowResources++;
		UnavailableTipString = `DIO_UI.static.FormatNotEnoughCredits();
	}
	if (Intel < ResearchTemplate.IntelCost)
	{
		NumLowResources++;
		UnavailableTipString = `DIO_UI.static.FormatNotEnoughIntel();
	}
	if (Elerium < ResearchTemplate.GetEleriumCost())
	{
		NumLowResources++;
		UnavailableTipString = `DIO_UI.static.FormatNotEnoughElerium();
	}

	if (NumLowResources > 1)
	{
		UnavailableTipString = `DIO_UI.default.strStatus_NotEnoughResourcesGeneric;
	}

	return NumLowResources == 0;
}

//---------------------------------------------------------------------------------------
function XComGameState_DioResearch GetActiveResearch(optional XComGameState ModifyGameState)
{
	if (ActiveResearchRef.ObjectID <= 0)
	{
		return none;
	}

	if (ModifyGameState != none)
	{
		return XComGameState_DioResearch(ModifyGameState.ModifyStateObject(class'XComGameState_DioResearch', ActiveResearchRef.ObjectID));
	}
	return XComGameState_DioResearch(`XCOMHISTORY.GetGameStateForObjectID(ActiveResearchRef.ObjectID));
}

//---------------------------------------------------------------------------------------
// Given a research template, populate info on its current status
function GetResearchStatuses(X2DioResearchTemplate ResearchTemplate, out EResearchState ResearchState, optional out XComGameState_DioResearch Research)
{
	local XComGameStateHistory History;
	local int i;

	History = `XCOMHISTORY;
	ResearchState = eResearch_Locked;
	Research = none;

	if (ResearchTemplate == none)
	{
		return;
	}

	if (UnlockedResearchNames.Find(ResearchTemplate.DataName) != INDEX_NONE)
	{
		ResearchState = eResearch_Available;
	}

	// Check active first
	Research = XComGameState_DioResearch(History.GetGameStateForObjectID(ActiveResearchRef.ObjectID));
	if (Research.GetMyTemplate() == ResearchTemplate)
	{
		ResearchState = eResearch_InProgress;
		return;
	}

	// Check completed third
	for (i = 0; i < CompletedResearchRefs.Length; ++i)
	{
		Research = XComGameState_DioResearch(History.GetGameStateForObjectID(CompletedResearchRefs[i].ObjectID));
		if (Research.GetMyTemplate() == ResearchTemplate)
		{
			ResearchState = eResearch_Complete;
			return;
		}
	}
}

//---------------------------------------------------------------------------------------
// Have all conditions to unlock this research been met?
function bool CheckResearchPrereqs(X2DioResearchTemplate ResearchTemplate)
{
	local XComGameStateHistory History;
	local X2StrategyElementTemplateManager StratMgr;
	local X2DioResearchPrereqTemplate PrereqTemplate;
	local XComGameState_DioResearch CompletedResearch;
	local array<name> CopiedPrereqResearch;
	local name TempName;
	local int i, Idx;

	History = `XCOMHISTORY;
	StratMgr = `STRAT_TEMPLATE_MGR;
	
	// Early out: direct unlocks technically are always locked
	if (ResearchTemplate.bDirectUnlock)
	{
		return false;
	}

	// Check for *all* prereqs
	// For Prereq Templates, simply check membership
	foreach ResearchTemplate.PrereqTemplates(TempName)
	{
		PrereqTemplate = X2DioResearchPrereqTemplate(StratMgr.FindStrategyElementTemplate(TempName));
		if (PrereqTemplate == none)
		{
			continue;
		}
		if (UnlockedPrereqsNames.Find(PrereqTemplate.DataName) == INDEX_NONE)
		{
			return false;
		}
	}

	// For research, check all completed research objects against template's list
	if (ResearchTemplate.PrereqResearch.Length > 0)
	{
		CopiedPrereqResearch = ResearchTemplate.PrereqResearch;
		for (i = 0; i < CompletedResearchRefs.Length; ++i)
		{
			CompletedResearch = XComGameState_DioResearch(History.GetGameStateForObjectID(CompletedResearchRefs[i].ObjectID));
			Idx = CopiedPrereqResearch.Find(CompletedResearch.GetMyTemplateName());
			if (Idx != INDEX_NONE)
			{
				CopiedPrereqResearch.Remove(Idx, 1);
			}
		}
		// Some prereq research was not found among completed research
		if (CopiedPrereqResearch.Length > 0)
		{
			return false;
		}
	}

	// All conditions passed
	return true;
}

//---------------------------------------------------------------------------------------
// Directly unlock a research template. Assumes explicit unlock or prereqs met!
function bool UnlockResearch(XComGameState ModifyGameState, X2DioResearchTemplate ResearchTemplate, optional bool bGameStart = false)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;
	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	
	// Early out: already unlocked
	if (DioHQ.UnlockedResearchNames.Find(ResearchTemplate.DataName) != INDEX_NONE)
	{
		return false;
	}

	DioHQ.UnlockedResearchNames.AddItem(ResearchTemplate.DataName);

	class'XComGameState_ResearchResult'.static.BuildUnlockedResult(ModifyGameState, ResearchTemplate);

	`XEVENTMGR.TriggerEvent('STRATEGY_ResearchUnlocked_Submitted', ResearchTemplate, DioHQ, ModifyGameState);

	if (!bGameStart)
	{
		StratPres.UIHQEnqueueUnlockedResearch(ResearchTemplate);
	}

	return true;
}

//---------------------------------------------------------------------------------------
function bool UnlockResearchByName(XComGameState ModifyGameState, name ResearchTemplateName)
{
	local X2DioResearchTemplate ResearchTemplate;

	ResearchTemplate = X2DioResearchTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(ResearchTemplateName));
	if (ResearchTemplate == none)
	{
		return false;
	}

	return UnlockResearch(ModifyGameState, ResearchTemplate);
}

//---------------------------------------------------------------------------------------
function bool UnlockResearchPrereq(XComGameState ModifyGameState, name PrereqTemplateName)
{
	local X2DioResearchPrereqTemplate PrereqTemplate;
	local XComGameState_HeadquartersDio DioHQ;

	PrereqTemplate = X2DioResearchPrereqTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(PrereqTemplateName));
	if (PrereqTemplate == none)
	{
		return false;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	
	// Early out: already unlocked
	if (DioHQ.UnlockedPrereqsNames.Find(PrereqTemplateName) != INDEX_NONE)
	{
		return false;
	}

	// Unlock prereq
	DioHQ.UnlockedPrereqsNames.AddItem(PrereqTemplateName);

	// Refresh unlock status for all templates
	RefreshAllResearchUnlocks(ModifyGameState);

	`XEVENTMGR.TriggerEvent('STRATEGY_ResearchUnlocked_Submitted', PrereqTemplate, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
// Apply the current research turns mod, if any
function int ApplyResearchTurnsMod(int InTurns)
{
	return Max(InTurns + ResearchTurnsMod, 1); // Can't go to 0 turns
}

//---------------------------------------------------------------------------------------
// Apply the current research Elerium cost mod, if any
function int ApplyResearchEleriumCostMod(int InCost)
{
	local float fCost, fModCost;

	fCost = float(InCost);

	if (ResearchEleriumCostMod != 0.0)
	{
		fModCost = (float(ResearchEleriumCostMod) * fCost) / 100.0;
		fCost += fModCost;
	}

	// Cost can't be negative but can be reduced to 0
	return Max(FFloor(fCost), 0);
}

//---------------------------------------------------------------------------------------
// Check all X2DioResearch templates and unlock any that merit it
function RefreshAllResearchUnlocks(XComGameState ModifyGameState, optional bool bGameStart = false)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_HeadquartersDio DioHQ;
	local array<X2StrategyElementTemplate> ResearchTemplates;
	local X2DioResearchTemplate ResearchTemplate;
	local int i;

	StratMgr = `STRAT_TEMPLATE_MGR;
	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	// Add Research that starts unlocked
	ResearchTemplates = StratMgr.GetAllTemplatesOfClass(class'X2DioResearchTemplate');
	for (i = 0; i < ResearchTemplates.Length; ++i)
	{
		ResearchTemplate = X2DioResearchTemplate(ResearchTemplates[i]);

		if (DioHQ.CheckResearchPrereqs(ResearchTemplate))
		{
			DioHQ.UnlockResearch(ModifyGameState, ResearchTemplate, bGameStart);
		}
	}
}

//---------------------------------------------------------------------------------------
function RemoveUnseenCompletedResearch(XComGameState ModifyGameState, optional StateObjectReference ResearchRef)
{
	local XComGameState_HeadquartersDio DioHQ;
	local int Idx;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	Idx = DioHQ.UnseenCompletedResearch.Find('ObjectID', ResearchRef.ObjectID);
	if (Idx != INDEX_NONE)
	{
		DioHQ.UnseenCompletedResearch.Remove(Idx, 1);
	}
	else
	{
		// If no specific research passed in, just remove all to clear out the notification
		DioHQ.UnseenCompletedResearch.Length = 0;
	}

	class'DioStrategyNotificationsHelper'.static.RefreshAssemblyNotifications(ModifyGameState);
}

//---------------------------------------------------------------------------------------
// Check all X2DioSpecOpsTemplate templates and unlock any that can
function RefreshAllSpecOpsUnlocks(XComGameState ModifyGameState, optional bool bGameStart = false)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_HeadquartersDio DioHQ;
	local array<X2StrategyElementTemplate> SpecOpsTemplates;
	local X2DioSpecOpsTemplate SpecOpsTemplate;
	local int i, NumUnlocked;

	local XComLWTuple					Tuple;		// HELIOS VARIABLES
	local HSStrategyNotificationObject	NotifObj;	// HELIOS VARIABLES

	StratMgr = `STRAT_TEMPLATE_MGR;
	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	SpecOpsTemplates = StratMgr.GetAllTemplatesOfClass(class'X2DioSpecOpsTemplate');
	for (i = 0; i < SpecOpsTemplates.Length; ++i)
	{
		SpecOpsTemplate = X2DioSpecOpsTemplate(SpecOpsTemplates[i]);

		if (DioHQ.UnlockedSpecOps.Find(SpecOpsTemplate.DataName) != INDEX_NONE)
		{
			continue;
		}

		if (SpecOpsTemplate.ArePrereqsMet(true))
		{
			if (DioHQ.UnlockSpecOps(ModifyGameState, SpecOpsTemplate, bGameStart))
			{
				NumUnlocked++;
			}
		}
	}

	if (!bGameStart && NumUnlocked > 0)
	{
		// HELIOS BEGIN
		// New Notification model that allows mods to change their behavior and text
		NotifObj = new class'HSStrategyNotificationObject';
		NotifObj.NotificationData.Type 				= eSNT_SpecOpsUnlocked;
		NotifObj.NotificationData.Title 			= class'DioStrategyNotificationsHelper'.default.NewSpecOpsTitle;
		NotifObj.NotificationData.Body 				= class'DioStrategyNotificationsHelper'.default.NewSpecOpsBody;
		NotifObj.NotificationData.OnItemSelectedFn 	= class'UIUtilities_DioStrategy'.static.Hotlink_SpecOps;

		Tuple = new class'XComLWTuple';
		Tuple.Id = 'NewSpecOpsNotificationObject';
		Tuple.Data.Add(1);
		Tuple.Data[0].kind = XComLWTVObject;
		Tuple.Data[0].o = NotifObj;

		`XEVENTMGR.TriggerEvent('HELIOS_STRATEGY_Notification_CreateNewSpecOpsNotif', Tuple, Tuple);
		
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
		DioHQ.RemoveNotificationByType(eSNT_SpecOpsUnlocked);
	}
}

//---------------------------------------------------------------------------------------
// Scan every item in all inventories to see if they now have accessible upgrade templates, and replace any found
function RefreshAllUpgradedItems(XComGameState ModifyGameState)
{
	local X2ItemTemplateManager ItemTemplateManager;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyInventory StratInventory;
	local XComGameState_StrategyMarket StratMarket;
	local X2ItemTemplate OldItemTemplate, UpgradedItemTemplate;
	local array<StateObjectReference> AllUnitRefs;
	local XComGameState_Unit Unit;
	local array<XComGameState_Item> InventoryItems;
	local XComGameState_Item Item, UpgradedItem;
	local EInventorySlot ItemSlot;
	local int i;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	// Squad items
	DioHQ.GetAllUnitRefs(AllUnitRefs);
	for (i = 0; i < AllUnitRefs.Length; ++i)
	{
		Unit = XComGameState_Unit(ModifyGameState.ModifyStateObject(class'XComGameState_Unit', AllUnitRefs[i].ObjectID));
		InventoryItems = Unit.GetAllInventoryItems(ModifyGameState);
		foreach InventoryItems(Item)
		{
			UpgradedItemTemplate = Item.GetMyTemplate();
			DioHQ.GetUpgradedItemTemplate(UpgradedItemTemplate, ModifyGameState);
			if (UpgradedItemTemplate != Item.GetMyTemplate())
			{
				ItemSlot = Item.InventorySlot;
				Unit.RemoveItemFromInventory(Item, ModifyGameState);				

				UpgradedItem = UpgradedItemTemplate.CreateInstanceFromTemplate(ModifyGameState);
				Unit.AddItemToInventory(UpgradedItem, ItemSlot, ModifyGameState, true);

				ModifyGameState.RemoveStateObject(Item.ObjectID);
			}
		}
	}

	// Strategy Inventories
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_StrategyInventory', StratInventory)
	{
		StratInventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', StratInventory.ObjectID));
		for (i = 0; i < StratInventory.Items.Length; ++i)
		{
			// Bug failsafe: skip dead entries
			if (StratInventory.Items[i].ObjectID == 0)
			{
				continue;
			}

			Item = XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', StratInventory.Items[i].ObjectID));
			UpgradedItemTemplate = Item.GetMyTemplate();
			DioHQ.GetUpgradedItemTemplate(UpgradedItemTemplate, ModifyGameState);
			if (UpgradedItemTemplate != Item.GetMyTemplate())
			{
				StratInventory.RemoveItem(ModifyGameState, Item.GetReference());
				ModifyGameState.RemoveStateObject(Item.ObjectID);

				StratInventory.AddItemByTemplate(ModifyGameState, UpgradedItemTemplate);
			}
		}
	}

	// Markets
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_StrategyMarket', StratMarket)
	{
		StratMarket = XComGameState_StrategyMarket(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyMarket', StratMarket.ObjectID));
		for (i = 0; i < StratMarket.ForSaleCommodities.Length; ++i)
		{
			OldItemTemplate = ItemTemplateManager.FindItemTemplate(StratMarket.ForSaleCommodities[i].TemplateName);
			if (OldItemTemplate == none)
			{
				continue;
			}

			UpgradedItemTemplate = OldItemTemplate;
			DioHQ.GetUpgradedItemTemplate(UpgradedItemTemplate, ModifyGameState);
			if (UpgradedItemTemplate != OldItemTemplate)
			{
				// Update Commodity
				StratMarket.ForSaleCommodities[i].TemplateName = UpgradedItemTemplate.DataName;
				StratMarket.ForSaleCommodities[i].Title = UpgradedItemTemplate.GetItemFriendlyName();
				StratMarket.ForSaleCommodities[i].Desc = UpgradedItemTemplate.GetItemBriefSummary();
				StratMarket.ForSaleCommodities[i].Image = UpgradedItemTemplate.strImage;
			}
		}
	}
}

//---------------------------------------------------------------------------------------
// Given an item template, return the template that replaces it at the highest current upgrade level (if any)
function GetUpgradedItemTemplate(out X2ItemTemplate ItemTemplate, optional XComGameState ModifyGameState)
{
	local XComGameStateHistory History;
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_HeadquartersDio DioHQ;
	local X2ItemTemplateManager ItemTemplateManager;
	local X2ItemTemplate CreatorItemTemplate, UpgradedItemTemplate;
	local X2DioResearchTemplate CreatorAssemblyTemplate;
	local XComGameState_StrategyInventory StratInventory;
	local XComGameState_Item InvItem;
	local bool bUpgradeAllowed;
	local int i, InfCheck;

	History = `XCOMHISTORY;
	DioHQ = self;
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	if (ModifyGameState != none)
	{
		DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
		StratInventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', DioHQ.Inventory.ObjectID));
	}
	else
	{
		StratInventory = XComGameState_StrategyInventory(History.GetGameStateForObjectID(DioHQ.Inventory.ObjectID));
	}

	// Get the item template which has this item as a base (should be only one)
	UpgradedItemTemplate = ItemTemplateManager.GetUpgradedItemTemplateFromBase(ItemTemplate.DataName);
	while (UpgradedItemTemplate != none)
	{
		bUpgradeAllowed = false;

		// If the upgrade's creator template is owned, update the OUT param
		if (UpgradedItemTemplate.CreatorTemplateName != '')
		{
			// Upgrade permitted by an Item?
			CreatorItemTemplate = ItemTemplateManager.FindItemTemplate(UpgradedItemTemplate.CreatorTemplateName);
			if (CreatorItemTemplate != none)
			{
				for (i = 0; i < StratInventory.Items.Length; ++i)
				{
					InvItem = StratInventory.GetItemAtIndex(i, ModifyGameState);
					if (InvItem == none)
					{
						continue;
					}

					if (CreatorItemTemplate == InvItem.GetMyTemplate())
					{
						bUpgradeAllowed = true;
						break;
					}
				}
			}

			// Upgrade permitted by Assembly?
			if (!bUpgradeAllowed)
			{
				CreatorAssemblyTemplate = X2DioResearchTemplate(StratMgr.FindStrategyElementTemplate(UpgradedItemTemplate.CreatorTemplateName));
				if (CreatorAssemblyTemplate != none && DioHQ.HasCompletedResearchByName(CreatorAssemblyTemplate.DataName))
				{
					bUpgradeAllowed = true;
				}
			}
		}

		// This upgrade is allowed to take effect now -- update OUT param
		if (bUpgradeAllowed)
		{
			ItemTemplate = UpgradedItemTemplate;
		}

		// Try the next upgrade up, if any
		UpgradedItemTemplate = ItemTemplateManager.GetUpgradedItemTemplateFromBase(UpgradedItemTemplate.DataName);

		if (++InfCheck >= 9)
		{
			break;
		}
	}
}

//---------------------------------------------------------------------------------------
// Specialization for EquipmentTemplates
function GetUpgradedEquipmentTemplate(out X2EquipmentTemplate ItemTemplate, optional XComGameState ModifyGameState)
{
	local X2ItemTemplate ResultTemplate;

	ResultTemplate = ItemTemplate;
	GetUpgradedItemTemplate(ResultTemplate, ModifyGameState);
	ItemTemplate = X2EquipmentTemplate(ResultTemplate);
}

//---------------------------------------------------------------------------------------
// Given a weapon upgrade template, apply it to all items in the inventory and agent loadouts
function ApplyWeaponUpgradeToAllValidItems(X2WeaponUpgradeTemplate UpgradeTemplate, XComGameState ModifyGameState)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyInventory StratInventory;
	local array<XComGameState_Item> InventoryItems;
	local array<StateObjectReference> AllUnitRefs;
	local XComGameState_Unit Unit;
	local XComGameState_Item Item;
	local int i;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));

	// HQ Inventory
	StratInventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', DioHQ.Inventory.ObjectID));
	for (i = 0; i < StratInventory.Items.Length; ++i)
	{
		Item = XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', StratInventory.Items[i].ObjectID));
		if (UpgradeTemplate.CanApplyUpgradeToWeapon(Item))
		{
			Item.ApplyWeaponUpgradeTemplate(UpgradeTemplate);
		}
	}

	// Squad items
	DioHQ.GetAllUnitRefs(AllUnitRefs);
	for (i = 0; i < AllUnitRefs.Length; ++i)
	{
		Unit = XComGameState_Unit(ModifyGameState.ModifyStateObject(class'XComGameState_Unit', AllUnitRefs[i].ObjectID));
		InventoryItems = Unit.GetAllInventoryItems(ModifyGameState);
		foreach InventoryItems(Item)
		{
			if (UpgradeTemplate.CanApplyUpgradeToWeapon(Item))
			{
				Item = XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', Item.ObjectID));
				Item.ApplyWeaponUpgradeTemplate(UpgradeTemplate);
			}
		}
	}
}

//---------------------------------------------------------------------------------------
// Given an item, search inventory for all upgrade items and apply all valid ones found
function ApplyUniversalUpgradesToItem(StateObjectReference ItemRef, XComGameState ModifyGameState)
{
	local XComGameState_StrategyInventory StratInventory;
	local X2WeaponUpgradeTemplate UpgradeTemplate;
	local XComGameState_Item Item, UpgradeItem;
	local int i;

	Item = XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', ItemRef.ObjectID));

	// HQ Inventory
	StratInventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', Inventory.ObjectID));
	for (i = 0; i < StratInventory.Items.Length; ++i)
	{
		UpgradeItem = StratInventory.GetItemAtIndex(i, ModifyGameState);
		if (UpgradeItem == none)
		{
			continue;
		}
		UpgradeTemplate = X2WeaponUpgradeTemplate(UpgradeItem.GetMyTemplate());
		if (UpgradeTemplate == none)
		{
			continue;
		}

		if (UpgradeTemplate.Universal && UpgradeTemplate.CanApplyUpgradeToWeapon(Item))
		{
			Item.ApplyWeaponUpgradeTemplate(UpgradeTemplate);
		}
	}
}

//---------------------------------------------------------------------------------------
// Checks all unit and HQ inventories for the item
function bool IsItemOwnedAnywhere(name ItemTemplateName, optional out StateObjectReference OutOwnerRef)
{
	local XComGameStateHistory History;
	local XComGameState_StrategyInventory StratInventory;
	local array<XComGameState_Item> InventoryItems;
	local array<StateObjectReference> AllUnitRefs;
	local XComGameState_Unit Unit;
	local XComGameState_Item Item;
	local int i;

	History = `XCOMHISTORY;
	OutOwnerRef.ObjectID = 0;

	// HQ Inventory
	StratInventory = XComGameState_StrategyInventory(History.GetGameStateForObjectID(Inventory.ObjectID));
	for (i = 0; i < StratInventory.Items.Length; ++i)
	{
		Item = XComGameState_Item(History.GetGameStateForObjectID(StratInventory.Items[i].ObjectID));
		if (Item.GetMyTemplateName() == ItemTemplateName)
		{
			OutOwnerRef = Inventory;
			return true;
		}
	}

	// Squad items
	GetAllUnitRefs(AllUnitRefs);
	for (i = 0; i < AllUnitRefs.Length; ++i)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(AllUnitRefs[i].ObjectID));
		InventoryItems = Unit.GetAllInventoryItems();
		foreach InventoryItems(Item)
		{
			if (Item.GetMyTemplateName() == ItemTemplateName)
			{
				OutOwnerRef = Unit.GetReference();
				return true;
			}
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
//				SPEC OPS
//---------------------------------------------------------------------------------------
function bool UnlockSpecOpsByName(XComGameState ModifyGameState, name SpecOpsTemplateName)
{
	local X2DioSpecOpsTemplate SpecOpsTemplate;

	if (SpecOpsTemplateName == '')
	{
		return false;
	}

	SpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(SpecOpsTemplateName));
	if (SpecOpsTemplate == none)
	{
		return false;
	}

	return UnlockSpecOps(ModifyGameState, SpecOpsTemplate);
}

//---------------------------------------------------------------------------------------
function bool UnlockSpecOps(XComGameState ModifyGameState, X2DioSpecOpsTemplate SpecOpsTemplate, optional bool bGameStart=false)
{
	local XComGameState_HeadquartersDio DioHQ;

	if (SpecOpsTemplate == none)
	{
		return false;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	if (DioHQ.UnlockedSpecOps.Find(SpecOpsTemplate.DataName) != INDEX_NONE)
	{
		return false;
	}

	DioHQ.UnlockedSpecOps.AddItem(SpecOpsTemplate.DataName);
	DioHQ.UnseenUnlockedSpecOps.AddItem(SpecOpsTemplate.DataName);
	`XEVENTMGR.TriggerEvent('STRATEGY_SpecOpsUnlocked_Submitted', SpecOpsTemplate, DioHQ, ModifyGameState);
	return true;
}

//---------------------------------------------------------------------------------------
//				TRAINING (Universal data)
//---------------------------------------------------------------------------------------

function UnlockUniversalTrainingByName(XComGameState ModifyGameState, name TrainingTemplateName)
{
	local X2DioTrainingProgramTemplate TrainingTemplate;

	if (TrainingTemplateName == '')
	{
		return;
	}

	TrainingTemplate = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(TrainingTemplateName));
	if (TrainingTemplate == none)
	{
		return;
	}

	UnlockUniversalTraining(ModifyGameState, TrainingTemplate);
}

//---------------------------------------------------------------------------------------
function UnlockUniversalTraining(XComGameState ModifyGameState, X2DioTrainingProgramTemplate TrainingTemplate)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;

	if (TrainingTemplate == none)
	{
		return;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	if (DioHQ.UnlockedUniversalTraining.Find(TrainingTemplate.DataName) == INDEX_NONE)
	{
		DioHQ.UnlockedUniversalTraining.AddItem(TrainingTemplate.DataName);
		`XEVENTMGR.TriggerEvent('STRATEGY_UniversalTrainingUnlocked_Submitted', TrainingTemplate, DioHQ, ModifyGameState);

		StratPres.UIHQEnqueueUnlockedTraining(TrainingTemplate);
	}
}

//---------------------------------------------------------------------------------------
//				FIELD TEAMS (UNIVERSAL)
//---------------------------------------------------------------------------------------
function ChangeFreeFieldTeamBuilds(XComGameState ModifyGameState, int Quantity)
{
	local XComGameState_HeadquartersDio DioHQ;

	if (Quantity == 0)
	{
		return;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	DioHQ.FreeFieldTeamBuilds += Quantity;

	`XEVENTMGR.TriggerEvent('STRATEGY_FreeFieldTeamBuildsChanged_Submitted', DioHQ, DioHQ, ModifyGameState);
}

//---------------------------------------------------------------------------------------
function int GetFieldTeamEffectCooldownRemaining(X2FieldTeamEffectTemplate Effect)
{
	local int Index, TurnsRemaining;

	if (Effect == none)
	{
		return 0;
	}

	Index = FieldTeamEffectNextAvailableTurn.Find('DataName', Effect.DataName);
	if (Index == INDEX_NONE)
	{
		return 0;
	}

	TurnsRemaining = FieldTeamEffectNextAvailableTurn[Index].Weight - CurrentTurn;
	return Max(0, TurnsRemaining);
}

//---------------------------------------------------------------------------------------
function OnFieldTeamEffectActivated(XComGameState ModifyGameState, X2FieldTeamEffectTemplate Effect)
{
	local XComGameState_HeadquartersDio DioHQ;
	local IntWeightedDataName NewData;
	local int Index, Cooldown;

	if (Effect == none)
	{
		return;
	}
	Cooldown = Effect.GetCooldown();

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	Index = DioHQ.FieldTeamEffectNextAvailableTurn.Find('DataName', Effect.DataName);
	if (Index != INDEX_NONE)
	{
		DioHQ.FieldTeamEffectNextAvailableTurn[Index].Weight = DioHQ.CurrentTurn + Cooldown;
	}
	else
	{
		NewData.DataName = Effect.DataName;
		NewData.Weight = DioHQ.CurrentTurn + Cooldown;
		DioHQ.FieldTeamEffectNextAvailableTurn.AddItem(NewData);
	}
}

//---------------------------------------------------------------------------------------
//				BLACKBOARD
//---------------------------------------------------------------------------------------

function bool HasBlackboardFlag(name FlagName)
{
	if (FlagName == '')
	{
		return true;
	}

	return Blackboard.Find(FlagName) != INDEX_NONE;
}

//---------------------------------------------------------------------------------------
function AddBlackboardFlag(XComGameState ModifyGameState, name FlagName)
{
	local XComGameState_HeadquartersDio DioHQ;

	if (HasBlackboardFlag(FlagName))
	{
		return;
	}

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	DioHQ.Blackboard.AddItem(FlagName);
}

//---------------------------------------------------------------------------------------
function RemoveBlackboardFlag(XComGameState ModifyGameState, name FlagName)
{
	local XComGameState_HeadquartersDio DioHQ;
	local int index;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', ObjectID));
	index = DioHQ.Blackboard.Find(FlagName);
	if (index != INDEX_NONE)
	{
		DioHQ.Blackboard.Remove(index, 1);
	}
}

//---------------------------------------------------------------------------------------
//				Gameplay Tags
//---------------------------------------------------------------------------------------
function AddMissionTacticalTags(XComGameState_MissionSite MissionState)
{
	local name GameplayTag;
	local int i;

	if (MissionState != none)
	{
		foreach MissionState.TacticalGameplayTags(GameplayTag)
		{
			if (TacticalGameplayTags.Find(GameplayTag) == INDEX_NONE)
			{
				TacticalGameplayTags.AddItem(GameplayTag);
			}
		}

		foreach MissionState.GeneratedMission.Mission.ForcedTacticalTags(GameplayTag)
		{
			if (TacticalGameplayTags.Find(GameplayTag) == INDEX_NONE)
			{
				TacticalGameplayTags.AddItem(GameplayTag);
			}
		}

		for (i = 0; i < MissionState.DarkEvents.Length; ++i)
		{
			GameplayTag = MissionState.DarkEvents[i].TacticalTag;
			if (TacticalGameplayTags.Find(GameplayTag) == INDEX_NONE)
			{
				TacticalGameplayTags.AddItem(GameplayTag);
			}
		}
	}
}

//---------------------------------------------------------------------------------------
function RemoveMissionTacticalTags(XComGameState_MissionSite MissionState)
{
	local name GameplayTag;
	local int i;

	if (MissionState != none)
	{
		foreach MissionState.TacticalGameplayTags(GameplayTag)
		{
			TacticalGameplayTags.RemoveItem(GameplayTag);
		}

		// these two are both structs and cannot be none
		foreach MissionState.GeneratedMission.Mission.ForcedTacticalTags(GameplayTag)
		{
			TacticalGameplayTags.RemoveItem(GameplayTag);
		}

		for (i = 0; i < MissionState.DarkEvents.Length; ++i)
		{
			TacticalGameplayTags.RemoveItem(MissionState.DarkEvents[i].TacticalTag);
		}
	}
}

//---------------------------------------------------------------------------------------
// Remove dupes and sort tactical tags
function CleanUpTacticalTags()
{
	local array<name> SortedTacticalTags;
	local int idx;

	// Store old tactical tags for comparison, remove dupes
	for (idx = 0; idx < TacticalGameplayTags.Length; idx++)
	{
		if (SortedTacticalTags.Find(TacticalGameplayTags[idx]) == INDEX_NONE)
		{
			SortedTacticalTags.AddItem(TacticalGameplayTags[idx]);
		}
	}

	SortedTacticalTags.Sort(SortTacticalTags);
	TacticalGameplayTags = SortedTacticalTags;
}

//---------------------------------------------------------------------------------------
private function int SortTacticalTags(name NameA, name NameB)
{
	local string StringA, StringB;

	StringA = string(NameA);
	StringB = string(NameB);

	if (StringA < StringB)
	{
		return 1;
	}
	else if (StringA > StringB)
	{
		return -1;
	}
	else
	{
		return 0;
	}
}


//---------------------------------------------------------------------------------------
//				NOTIFICATIONS 
//---------------------------------------------------------------------------------------

function AddNotification(EStrategyNotificationType eType,
						delegate<OnItemSelectedCallback> OnItemSelectedFn,
						optional string Title = "",
						optional string Body = "",
						optional array<StateObjectReference> UnitRefs,
						optional string ImagePath = "",
						optional string UIColor = "")
{
	local TStrategyNotificationData Data;
	local int Idx;

	Data.Type = eType;
	Data.OnItemSelectedFn = OnItemSelectedFn;
	Data.Title = Title;
	Data.Body = Body;
	Data.UIColor = UIColor;
	Data.ImagePath = ImagePath;
	Data.UnitRefs = UnitRefs;

	Idx = Notifications.Find('Type', eType);
	if (Idx != INDEX_NONE)
	{
		//Get rid of the old data
		Notifications.Remove(Idx, 1);
	}

	Notifications.AddItem(Data);
	Notifications.Sort(SortNotifications);

	`XEVENTMGR.TriggerEvent('STRATEGY_NotificationAdded');
}

//---------------------------------------------------------------------------------------
function RemoveNotificationByType(EStrategyNotificationType eType)
{
	local int Idx;

	Idx = Notifications.Find('Type', eType);
	if (Idx != -1)
	{
		Notifications.Remove(Idx, 1);
		Notifications.Sort(SortNotifications);
		`XEVENTMGR.TriggerEvent('STRATEGY_NotificationRemoved');
	}
}

//---------------------------------------------------------------------------------------
function AddUnitsToNotification(EStrategyNotificationType eType, array<StateObjectReference> UnitsToAdd)
{
	local int i, Idx;
	local bool bTriggerEvent;

	Idx = Notifications.Find('Type', eType);
	if (Idx != INDEX_NONE)
	{
		for (i = 0; i < UnitsToAdd.Length; ++i)
		{
			if (Notifications[Idx].UnitRefs.Find('ObjectID', UnitsToAdd[i].ObjectID) == INDEX_NONE)
			{
				Notifications[Idx].UnitRefs.AddItem(UnitsToAdd[i]);
				bTriggerEvent = true;
			}
		}
	}

	if (bTriggerEvent)
	{
		`XEVENTMGR.TriggerEvent('STRATEGY_NotificationChanged');
	}
}

//---------------------------------------------------------------------------------------
function RemoveUnitsFromNotification(EStrategyNotificationType eType, array<StateObjectReference> UnitsToRemove)
{
	local int i, Idx, UnitIdx;
	local bool bTriggerEvent;

	Idx = Notifications.Find('Type', eType);
	if (Idx != INDEX_NONE)
	{
		for (i = 0; i < UnitsToRemove.Length; ++i)
		{
			UnitIdx = Notifications[Idx].UnitRefs.Find('ObjectID', UnitsToRemove[i].ObjectID);
			if (UnitIdx != INDEX_NONE)
			{
				Notifications[Idx].UnitRefs.Remove(UnitIdx, 1);
				bTriggerEvent = true;
			}
		}

		// If all units were removed from the notification, remove it entirely
		if (Notifications[Idx].UnitRefs.Length == 0)
		{
			RemoveNotificationByType(eType);
		}
	}

	if (bTriggerEvent)
	{
		`XEVENTMGR.TriggerEvent('STRATEGY_NotificationChanged');
	}
}

//---------------------------------------------------------------------------------------
function bool HasNotificationOfType(EStrategyNotificationType eType)
{
	return Notifications.Find('Type', eType) != INDEX_NONE;
}

//---------------------------------------------------------------------------------------
function int SortNotifications(TStrategyNotificationData DataA, TStrategyNotificationData DataB)
{
	local int PriA, PriB;

	PriA = class'DioStrategyNotificationsHelper'.default.NotificationTypeSortPriorities[DataA.Type];
	PriB = class'DioStrategyNotificationsHelper'.default.NotificationTypeSortPriorities[DataB.Type];
	return PriA <= PriB ? 1 : -1;
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	LastScavengerMarketTurn=-1
}