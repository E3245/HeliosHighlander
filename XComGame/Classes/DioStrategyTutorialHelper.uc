//---------------------------------------------------------------------------------------
//  FILE:    	DioStrategyTutorialHelper
//  AUTHOR:  	David McDonough  --  8/14/2019
//  PURPOSE: 	Functions and analysis to help execute the Strategy-layer tutorial.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class DioStrategyTutorialHelper extends Object
	config(StrategyTutorial);

var config int AssemblyUnlockedTurn;
var config int TrainingUnlockedTurn;
var config int UnrestUnlockedTurn;
var config int FieldTeamsUnlockedTurn;

//---------------------------------------------------------------------------------------
//				VO SELECTION
//---------------------------------------------------------------------------------------
static function name GetNextScreenVO(UIScreen Screen)
{
	switch (Screen.Class)
	{
	// HELIOS BEGIN
	// Reference the class that is set in the Presentation Base
	case `PRESBASE.UIPrimaryStrategyLayer :
		return GetNextLandingScreenVO();
	// HELIOS END
	case class'UIDIOStrategyMapFlash' :
		return GetNextMapScreenVO();
	case class'UICharacterUnlock' :
		return GetNextCharacterUnlockScreenVO();
	case class'UIDIOStrategyInvestigationChooserSimple' :
		return GetNextInvestigationChooserVO();
	case class'UIDebriefScreen':
		return GetNextDebriefScreenVO();
	// HELIOS BEGIN
	// Reference the class that is set in the Presentation Base
	case `PRESBASE.ArmoryLandingArea :
	case `PRESBASE.Armory_MainMenu:
	// HELIOS END
		return GetNextArmoryScreenVO(Screen);
	case class'UIDIOAssemblyScreen' :
		return GetNextAssemblyScreenVO();
	case class'UIDebriefScreen' :
		return GetNextInvestigationStatusScreenVO();
	case class'UIBlackMarket_Buy' :
		return GetNextMarketScreenVO(Screen);
	case class'UIScavengerMarket' :
		return GetNextScavengerMarketScreenVO(Screen);
	case class'UIDIOTrainingScreen' :
		return GetNextTrainingScreenVO();
	case class'UISpecOpsScreen' :
		return GetNextSpecOpsScreenVO();
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextLandingScreenVO()
{
	local XComStrategyPresentationLayer StratPres;
	local XComGameState_Investigation CurrentInvestigation;
	local int ThisTurn;

	StratPres = `STRATPRES;
	ThisTurn = `THIS_TURN;
	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();

	// Tutorial Act, Day 1: Director's Call
	if (`TutorialEnabled && ThisTurn <= 0)
	{
		return 'StratTutorial_DirectorCall';
	}
	// Act 1+ first Investigation
	if (CurrentInvestigation.Act == 1)
	{
		// - Now occurs on Debrief Screen below [1/28/2020 dmcdonough]
		//// On Groundwork, just started
		//if (CurrentInvestigation.Stage == eStage_Groundwork)
		//{
		//	return 'CoreXChooseFaction';
		//}
	}
	// Act 1+ First instance of elevated Unrest
	if (IsElevatedDistrictUnrest() && !StratPres.HasSeenVOEvent('StratTutorial_FirstUnrest'))
	{
		return 'StratTutorial_FirstUnrest';
	}
	// Act 1+ Field Teams can be built
	if (AreFieldTeamsAvailable() && !StratPres.HasSeenVOEvent('StratTutorial_FieldTeam'))
	{
		return 'StratTutorial_FieldTeam';
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextMapScreenVO()
{
	local XComGameState_Investigation CurrentInvestigation;
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;
	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();

	// First Investigation: intel about first Faction
	if (!StratPres.HasSeenVOEvent('StratTutorial_FirstMap'))
	{
		if (CurrentInvestigation.Act <= 1)
		{
			return 'StratTutorial_FirstMap';
		}
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextCharacterUnlockScreenVO()
{
	return 'StratTutorial_NewAgent';
}

//---------------------------------------------------------------------------------------
static function name GetNextInvestigationChooserVO()
{
	local XComStrategyPresentationLayer StratPres;
	local XComGameState_Investigation CurrentInvestigation;

	StratPres = `STRATPRES;
	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();

	// Tutorial Investigation is over, choosing next (first) Investigation
	if (CurrentInvestigation.Act <= 0)
	{
		// Director's call first and once
		if (!StratPres.HasSeenVOEvent('StratTutorial_DirectorCall'))
		{
			return 'StratTutorial_DirectorCall';
		}

		// Faction intro
		return 'StratTutorial_Factions';
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextDebriefScreenVO()
{
	local XComGameState_Investigation CurrentInvestigation;

	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();

	// New investigation just chosen, talk about faction
	if (CurrentInvestigation.Stage == eStage_Groundwork)
	{
		return 'CoreXChooseFaction';
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextArmoryScreenVO(UIScreen Screen)
{
	local UIArmory_MainMenu ArmoryMainMenu;
	local XComGameState_Unit ViewingUnit;

	// Act 1+ first time you view the Armory locker for a unit with ready promotions
	ArmoryMainMenu = UIArmory_MainMenu(Screen);
	if (ArmoryMainMenu != none)
	{
		ViewingUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ArmoryMainMenu.UnitReference.ObjectID));
		if (ViewingUnit.HasAvailablePerksToAssign())
		{
			return 'StratTutorial_FirstPromotion';
		}
	}

	return 'EvntStratScreen';
}

//---------------------------------------------------------------------------------------
static function name GetNextAssemblyScreenVO()
{
	return 'StratTutorial_FirstAssembly';
}

//---------------------------------------------------------------------------------------
static function name GetNextTrainingScreenVO()
{
	return 'StratTutorial_FirstScar';
}

//---------------------------------------------------------------------------------------
static function name GetNextSpecOpsScreenVO()
{
	if (!`STRATPRES.HasSeenVOEvent('StratTutorial_SpecOps'))
	{
		return 'StratTutorial_SpecOps';
	}
}

//---------------------------------------------------------------------------------------
static function name GetNextInvestigationStatusScreenVO()
{
	return 'StratTutorial_InvestigationStatus';
}

//---------------------------------------------------------------------------------------
static function name GetNextMarketScreenVO(UIScreen Screen)
{
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;
	return (!StratPres.HasSeenVOEvent('StratTutorial_FirstSupply')) ? 'StratTutorial_FirstSupply' : '';
}

//---------------------------------------------------------------------------------------
static function name GetNextScavengerMarketScreenVO(UIScreen Screen)
{
	return 'EvntStratScreen';
}

//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------
//
//				TUTORIAL SELECTION
//
//---------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------

static function name GetNextScreenTutorial(UIScreen Screen)
{
	if (Screen == none)
	{
		return '';
	}
	if (`TutorialEnabled == false)
	{
		return '';
	}

	switch (Screen.Class)
	{
	// HELIOS BEGIN
	// Reference the class that is set in the Presentation Base
	case `PRESBASE.UIPrimaryStrategyLayer :
		return GetNextLandingScreenTutorial();
	// HELIOS END
	case class'UIDIOStrategyMapFlash' :
		return GetNextMapScreenTutorial();
	case class'UIDIOAssemblyScreen' :
		return GetNextAssemblyScreenTutorial();
	// HELIOS BEGIN
	// Reference the class that is set in the Presentation Base		
	case `PRESBASE.ArmoryLandingArea :
	// HELIOS END
		return GetNextArmoryScreenTutorial(Screen);
	case class'UIArmory_AndroidUpgrades':
		return GetNextAndroidUpgradeScreenTutorial(Screen);
	// HELIOS BEGIN
	// Reference the class that is set in the Presentation Base
	case `PRESBASE.Armory_MainMenu:
	// HELIOS END
		return GetNextArmoryMainMenuTutorial(Screen);
	case class'UIArmory_Promotion' :
		return GetNextArmoryPromotionScreenTutorial(Screen);
	case class'UIDIOWorkerReviewScreen' :
	case class'UIDIOSituationReviewScreen' :
		return GetNextMissionReviewScreenTutorial(Screen);
	case class'UIDebriefScreen' :
		return GetNextDebriefScreenTutorial();
	case class'UIDIOStrategyInvestigationChooserSimple' :
		return GetNextInvestigationSelectionScreenTutorial();
	case class'UICharacterUnlock' :
		return GetNextCharacterUnlockScreenTutorial();
	case class'UIDIOTrainingScreen' :
		return GetNextTrainingScreenTutorial();
	case class'UISpecOpsScreen' :
		return GetNextSpecOpsScreenTutorial();
	case class'UIBlackMarket_Buy' :
		return GetNextMarketScreenTutorial(Screen);
	case class'UIScavengerMarket' :
		return GetNextScavengerMarketTutorial(Screen);
	case class'UIDIOFieldTeamScreen':
		return GetNextFieldTeamScreenTutorial(Screen);
	}

	// No tutorial for this screen
	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextLandingScreenTutorial()
{
	local XComStrategyPresentationLayer StratPres;
	local int ThisTurn, ClassTraining, ScarTraining;

	StratPres = `STRATPRES;
	ThisTurn = `THIS_TURN;

	// Act 0 Scheduled Tutorials

	// Day 1, Act 0: Visit Map
	if (ThisTurn <= 0)
	{
		return 'StrategyTutorial_Act0MapWaiting';
	}

	// Promotion waiting
	if (class'DioStrategyAI'.static.CountUnitsReadyForPromotion() > 0 && !StratPres.HasSeenTutorial('StrategyTutorial_DiscoverPromotions'))
	{
		return 'StrategyTutorial_PromotionWaiting';
	}
	// Any Day (Discovery)
	if (NeedsAssemblyReminder())
	{
		return 'StrategyTutorial_Act0AssemblyWaiting';
	}
	// Training waiting
	if (IsAssignmentAvailable('Train'))
	{
		CountAllTrainingAvailable(ClassTraining, ScarTraining);
		if (ClassTraining > 0 && !StratPres.HasSeenTutorial('StrategyTutorial_DiscoverTraining'))
		{
			return 'StrategyTutorial_ClassTrainingWaiting';
		}
		if (ScarTraining > 0 && !StratPres.HasSeenTutorial('StrategyTutorial_DiscoverTraining'))
		{
			return 'StrategyTutorial_ScarTrainingWaiting';
		}
	}
	// Spec Ops waiting
	if (NeedsSpecOpReminder())
	{
		return 'StrategyTutorial_Act0SpecOpsWaiting';
	}
	// Unrest elevated
	if (IsElevatedDistrictUnrest() && !StratPres.HasSeenTutorial('StrategyTutorial_DiscoverUnrest'))
	{
		return 'StrategyTutorial_Act1UnrestRising';
	}

	// No tutorials at this time
	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextMapScreenTutorial()
{	
	local XComGameState_Investigation Investigation;
	local XComStrategyPresentationLayer StratPres;
	local XComGameState_HeadquartersDio DioHQ;

	StratPres = `STRATPRES;
	DioHQ = `DIOHQ;
	Investigation = class'DioStrategyAI'.static.GetCurrentInvestigation();	

	// Map intro
	if (Investigation.Act <= 0)
	{
		if (!StratPres.HasSeenTutorial('StrategyTutorial_Act0CityMap'))
		{
			return 'StrategyTutorial_Act0CityMap';
		}
		else
		{
			return 'StrategyTutorial_Act0FirstSituation';
		}
	}

	// First Investigation
	if (Investigation.Act == 1)
	{
		// Groundwork reminder
		if (Investigation.Stage == eStage_Groundwork)
		{
			return 'StrategyTutorial_Act1FirstMission';
		}
		
		// Operations: intro to mission types		
		if (Investigation.Stage == eStage_Operations)
		{
			if (!StratPres.HasSeenTutorial('StrategyTutorial_DiscoverMissionTypes'))
			{
				return 'StrategyTutorial_DiscoverMissionTypes';
			}
		}
	}

	// Field Ability active
	if (StratPres.DIOHUD.FieldTeamHUD != none)
	{
		if (StratPres.DIOHUD.FieldTeamHUD.bTargetingActive &&
			!StratPres.HasSeenTutorialBlade('StrategyTutorial_FieldAbilityTargetingReminder'))
		{
			return 'StrategyTutorial_FieldAbilityTargetingReminder';
		}
	}

	// Unrest
	if (IsElevatedDistrictUnrest())
	{
		if (!StratPres.HasSeenTutorial('StrategyTutorial_DiscoverUnrest'))
		{
			return 'StrategyTutorial_DiscoverUnrest';
		}
	}
	if (IsElevatedCityUnrest())
	{
		if (!StratPres.HasSeenTutorial('StrategyTutorial_DiscoverUnrest'))
		{
			return 'StrategyTutorial_CityUnrest';
		}
	}

	// Field Teams unlocked
	if (!IsFieldTeamsTutorialLocked())
	{
		if (!StratPres.HasSeenTutorial('StrategyTutorial_DiscoverFieldTeams'))
		{
			return 'StrategyTutorial_DiscoverFieldTeams';
		}
		else
		{
			if (CountFieldTeams() == 0)
			{
				return 'StrategyTutorial_PlaceFirstFieldTeamReminder';
			}
			// Field Team Abilities intro
			else if (!StratPres.HasSeenTutorial('StrategyTutorial_FieldTeamAbilities'))
			{
				return 'StrategyTutorial_FieldTeamAbilities';
			}
			// Just finished Expert Field Teams research
			else if (DioHQ.HasCompletedResearchByName('DioResearch_ExpertFieldTeams') &&
				!StratPres.HasSeenTutorialBlade('StrategyTutorial_ExpertFieldTeamUpgradeReminder'))
			{
				return 'StrategyTutorial_ExpertFieldTeamUpgradeReminder';
			}
			// Just finished Improved Field Teams research
			else if (DioHQ.HasCompletedResearchByName('DioResearch_ImprovedFieldTeams') &&
				!StratPres.HasSeenTutorialBlade('StrategyTutorial_ImprovedFieldTeamUpgradeReminder'))
			{
				return 'StrategyTutorial_ImprovedFieldTeamUpgradeReminder';
			}
			// Just unlocked a Field Ability
			else if (!StratPres.HasSeenTutorialBlade('StrategyTutorial_FieldAbilityUnlockedVigilance') &&
				class'X2FieldTeamEffectTemplate'.static.AreEffectTemplatePrereqsMet('FieldTeamEffect_Vigilance'))
			{
				return 'StrategyTutorial_FieldAbilityUnlockedVigilance';
			}
			else if (!StratPres.HasSeenTutorialBlade('StrategyTutorial_FieldAbilityUnlockedQuarantine') &&
				class'X2FieldTeamEffectTemplate'.static.AreEffectTemplatePrereqsMet('FieldTeamEffect_Quarantine'))
			{
				return 'StrategyTutorial_FieldAbilityUnlockedQuarantine';
			}
			else if (!StratPres.HasSeenTutorialBlade('StrategyTutorial_FieldAbilityUnlockedDragnet') &&
				class'X2FieldTeamEffectTemplate'.static.AreEffectTemplatePrereqsMet('FieldTeamEffect_Dragnet'))
			{
				return 'StrategyTutorial_FieldAbilityUnlockedDragnet';
			}
			else if (!StratPres.HasSeenTutorialBlade('StrategyTutorial_FieldAbilityUnlockedTaskForce') &&
				class'X2FieldTeamEffectTemplate'.static.AreEffectTemplatePrereqsMet('FieldTeamEffect_TaskForce'))
			{
				return 'StrategyTutorial_FieldAbilityUnlockedTaskForce';
			}
		}
	}

	// Unlock Scavenger Market worker active
	if (!DioHQ.IsScavengerMarketUnlocked() &&
		IsScavengerUnlockWorkerActive() && 
		!StratPres.HasSeenTutorial('StrategyTutorial_DiscoverScavenger'))
	{
		return 'StrategyTutorial_ScavengerUnlockWaiting';
	}

	// No tutorials at this time
	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextAssemblyScreenTutorial()
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComStrategyPresentationLayer StratPres;

	DioHQ = `DIOHQ;
	StratPres = `STRATPRES;

	if (!StratPres.HasSeenTutorial('StrategyTutorial_Act0Assembly'))
	{
		return 'StrategyTutorial_Act0Assembly';
	}
	else if (!StratPres.HasSeenTutorial('StrategyTutorial_EleriumResource'))
	{
		return 'StrategyTutorial_EleriumResource';
	}
	else if (DioHQ.ActiveResearchRef.ObjectID == 0 && DioHQ.CompletedResearchRefs.Length == 0)
	{
		return 'StrategyTutorial_FirstAssemblyWaiting';
	}
	else if (DioHQ.UnlockedResearchNames.Find('DioResearch_ExpertFieldTeams') != INDEX_NONE)
	{
		if (!StratPres.HasSeenTutorialBlade('StrategyTutorial_ExpertFieldTeamAssemblyReminder'))
		{
			return 'StrategyTutorial_ExpertFieldTeamAssemblyReminder';
		}
	}
	else if (DioHQ.UnlockedResearchNames.Find('DioResearch_ImprovedFieldTeams') != INDEX_NONE)
	{
		if (!StratPres.HasSeenTutorialBlade('StrategyTutorial_ImprovedFieldTeamAssemblyReminder'))
		{
			return 'StrategyTutorial_ImprovedFieldTeamAssemblyReminder';
		}
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextMissionReviewScreenTutorial(UIScreen Screen)
{
	local UIDIOWorkerReviewScreen WorkerScreen;
	local XComGameState_DioWorker Worker;
	local XComGameState_Investigation Investigation;
	local XComGameState_StrategyAction_Mission MissionAction;
	local XComGameState_MissionSite Mission;
	local name ResourceTutorialName;
	
	Investigation = class'DioStrategyAI'.static.GetCurrentInvestigation();
	if (Investigation == none)
	{
		return '';
	}

	WorkerScreen = UIDIOWorkerReviewScreen(Screen);
	if (WorkerScreen == none)
	{
		return '';
	}

	Worker = class'DioWorkerAI'.static.GetWorker(WorkerScreen.m_WorkerRef);

	if (Investigation.Stage == eStage_Operations)
	{
		// First Masked worker mission
		if (Worker != none && Worker.bMasked)
		{
			if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_Act1FirstOperation'))
			{
				return 'StrategyTutorial_Act1FirstOperation';
			}
		}
	}

	// First Lead
	MissionAction = XComGameState_StrategyAction_Mission(Worker.GetStrategyAction());
	if (MissionAction != none)
	{
		if (MissionAction.IsLeadMission() && !`STRATPRES.HasSeenTutorial('StrategyTutorial_Act1LeadMissions'))
		{
			return 'StrategyTutorial_Act1LeadMissions';
		}
	}

	// First Dark Event mission
	Mission = MissionAction.GetMission();
	if (Mission.DarkEvents.Length > 0 && !`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverDarkEvents'))
	{
		return 'StrategyTutorial_DiscoverDarkEvents';
	}


	// Unlock Scavenger Market Worker
	if (Worker.GetMyTemplateName() == class'XComGameState_DioStrategyScheduler'.default.DefaultUnlockScavengerMarketWorker)
	{
		if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverScavenger'))
		{
			return 'StrategyTutorial_DiscoverScavenger';
		}
	}

	// Resource tutorials, if any
	ResourceTutorialName = CheckWorkerRewardResourceTutorial(Worker);
	if (ResourceTutorialName != '')
	{
		return ResourceTutorialName;
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextArmoryScreenTutorial(UIScreen Screen)
{
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;

	// Discover
	if (!StratPres.HasSeenTutorial('StrategyTutorial_DiscoverArmory'))
	{
		return 'StrategyTutorial_DiscoverArmory';
	}
	else if (!StratPres.HasVisitedScreen('UIArmory_MainMenu'))
	{
		return 'StrategyTutorial_ArmoryMenuWaiting';
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextAndroidUpgradeScreenTutorial(UIScreen Screen)
{
	if (!`DIOHQ.HasCompletedResearchByName('DioResearch_ModularAndroids'))
	{
		return '';
	}

	if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverAndroidUpgrades'))
	{
		return 'StrategyTutorial_DiscoverAndroidUpgrades';
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextArmoryMainMenuTutorial(UIScreen Screen)
{
	local XComGameState_HeadquartersDio DioHQ;
	local UIArmory_MainMenu ArmoryMainMenu;
	local XComGameState_Unit ViewingUnit;

	DioHQ = `DIOHQ;
	ArmoryMainMenu = UIArmory_MainMenu(Screen);
	if (ArmoryMainMenu != none)
	{
		ViewingUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ArmoryMainMenu.UnitReference.ObjectID));
	}

	// DIO DEPRECATED [1/31/2020 dmcdonough]
	//// Equipping
	//if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_ArmoryEquipping'))
	//{
	//	return 'StrategyTutorial_ArmoryEquipping';
	//}

	// Scars
	if (ViewingUnit.Scars.Length > 0)	
	{
		if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverScars'))
		{
			return 'StrategyTutorial_DiscoverScars';
		}
	}

	// Androids
	if (DioHQ.Androids.Length > 0)
	{
		if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverAndroids'))
		{
			if (ViewingUnit.IsAndroid())
			{
				return 'StrategyTutorial_DiscoverAndroids';
			}
		}
	}

	// DIO DEPRECATED [1/31/2020 dmcdonough]
	//// Mods
	//if (DioHQ.HasCompletedResearchByName('DioResearch_ModularWeapons') || 
	//	DioHQ.HasCompletedResearchByName('DioResearch_ModularArmor'))
	//{
	//	if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverWeaponArmorMods'))
	//	{
	//		return 'StrategyTutorial_DiscoverWeaponArmorMods';
	//	}
	//}

	// Android Upgrades
	if (DioHQ.HasCompletedResearchByName('DioResearch_ModularAndroids') &&
		DioHQ.Androids.Length > 0)
	{
		if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverAndroidUpgrades'))
		{
			return 'StrategyTutorial_DiscoverAndroidUpgrades';
		}
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextArmoryPromotionScreenTutorial(UIScreen Screen)
{
	local UIArmory_Promotion PromotionScreen;
	local XComGameState_Unit Unit;

	if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverPromotions'))
	{
		return 'StrategyTutorial_DiscoverPromotions';
	}

	PromotionScreen = UIArmory_Promotion(Screen);
	if (PromotionScreen != none)
	{
		Unit = class'DioStrategyAI'.static.GetUnit(PromotionScreen.UnitReference);
		if (Unit != none && Unit.HasAvailablePerksToAssign())
		{
			if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverPromotions'))
			{
				return 'StrategyTutorial_ConfirmPromotionWaiting';
			}
		}
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextInvestigationSelectionScreenTutorial()
{
	return 'StrategyTutorial_Act1InvestigationsWaiting';
}

//---------------------------------------------------------------------------------------
static function name GetNextDebriefScreenTutorial()
{
	local XComGameState_Investigation Investigation;

	Investigation = class'DioStrategyAI'.static.GetCurrentInvestigation();

	// First Groundwork: Investigation Structure
	if (Investigation.Act >= 1 && Investigation.Stage == eStage_Groundwork)
	{
		if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_Act1InvestigationStructure'))
		{
			return 'StrategyTutorial_Act1InvestigationStructure';
		}
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextCharacterUnlockScreenTutorial()
{
	return 'StrategyTutorial_Act0NewAgentWaiting';
}

//---------------------------------------------------------------------------------------
static function name GetNextSpecOpsScreenTutorial()
{
	if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverSpecOps'))
	{
		return 'StrategyTutorial_DiscoverSpecOps';
	}
	else if (`DIOHQ.HasCompletedResearchByName('DioResearch_ImprovedFieldTeams'))
	{
		if (!`STRATPRES.HasSeenTutorialBlade('StrategyTutorial_FieldTeamSpecOpReminder'))
		{
			return 'StrategyTutorial_FieldTeamSpecOpReminder';
		}
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextTrainingScreenTutorial()
{
	if (!`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverTraining'))
	{
		return 'StrategyTutorial_DiscoverTraining';
	}
	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextMarketScreenTutorial(UIScreen Screen)
{
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;

	if (!StratPres.HasSeenTutorial('StrategyTutorial_Act0Supply'))
	{
		return 'StrategyTutorial_Act0Supply';
	}
	else if (!StratPres.HasSeenTutorial('StrategyTutorial_CreditsResource'))
	{
		return 'StrategyTutorial_CreditsResource';
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextScavengerMarketTutorial(UIScreen Screen)
{
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;

	if (!StratPres.HasSeenTutorial('StrategyTutorial_DiscoverScavenger'))
	{
		return 'StrategyTutorial_DiscoverScavenger';
	}
	else if (!StratPres.HasSeenTutorial('StrategyTutorial_IntelResource'))
	{
		return 'StrategyTutorial_IntelResource';
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function name GetNextFieldTeamScreenTutorial(UIScreen Screen)
{
	local UIDIOFieldTeamScreen FieldTeamScreen;
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;

	// Rank Up/Combining Field Teams
	if (!StratPres.HasSeenTutorial('StrategyTutorial_ManagingFieldTeams'))
	{
		return 'StrategyTutorial_ManagingFieldTeams';
	}
	else
	{
		FieldTeamScreen = UIDIOFieldTeamScreen(Screen);
		if (FieldTeamScreen != none)
		{
			if (FieldTeamScreen.m_FieldTeamRef.ObjectID <= 0)
			{
				return 'StrategyTutorial_BuildFirstFieldTeamReminder';
			}
			else if (!StratPres.HasSeenTutorialBlade('StrategyTutorial_FieldTeamRankUnlocksReminder'))
			{
				return 'StrategyTutorial_FieldTeamRankUnlocksReminder';
			}
			else if (!StratPres.HasSeenTutorial('StrategyTutorial_IntelResource'))
			{
				return 'StrategyTutorial_IntelResource';
			}
		}
	}

	return '';
}

//---------------------------------------------------------------------------------------
//				CONDITION HELPERS
//---------------------------------------------------------------------------------------
static function bool IsElevatedDistrictUnrest()
{
	local XComGameStateHistory History;
	local XComGameState_DioCityDistrict District;
	local int UnrestThreshold;

	// System not on yet
	if (IsUnrestTutorialLocked())
	{
		return false;
	}

	History = `XCOMHISTORY;
	UnrestThreshold = Min(`MIN_UNREST + 2, `MAX_UNREST);

	foreach History.IterateByClassType(class'XComGameState_DioCityDistrict', District)
	{
		if (District.Unrest > UnrestThreshold)
		{
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
static function bool IsElevatedCityUnrest()
{
	local XComGameState_CampaignGoal Goal;

	// System not on yet
	if (IsUnrestTutorialLocked())
	{
		return false;
	}

	Goal = `DIOHQ.GetCampaignGoal();
	if (Goal.OverallCityUnrest > 4)
	{
		return true;
	}

	return false;
}

//---------------------------------------------------------------------------------------
static function bool NeedsAssemblyReminder()
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = `DIOHQ;

	if (!IsAssignmentAvailable('Research'))
	{
		return false;
	}

	// True if no active research and never done any research
	return (DioHQ.ActiveResearchRef.ObjectID <= 0 && DioHQ.CompletedResearchRefs.Length == 0);
}

//---------------------------------------------------------------------------------------
static function bool NeedsSpecOpReminder()
{
	if (!IsAssignmentAvailable('SpecOps'))
	{
		return false;
	}
	if (`DIOHQ.Squad.Length <= 4)
	{
		return false;
	}
	if (`STRATPRES.HasSeenTutorial('StrategyTutorial_DiscoverSpecOps'))
	{
		return false;
	}
	if (class'DioStrategyAI'.static.CountStrategyActionsByTemplateName('HQAction_SpecOps') > 0)
	{
		return false;
	}

	return true;
}

//---------------------------------------------------------------------------------------
static function bool NeedsFieldTeamsReminder()
{
	local XComGameState_CampaignSettings SettingsState;
	local int Index, TurnSinceLastReminder;

	if (!AreFieldTeamsAvailable())
	{
		return false;
	}

	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	Index = SettingsState.SeenTutorialBlades.Find('DataName', 'StrategyTutorial_FieldTeamReminder');
	if (Index == INDEX_NONE)
	{
		TurnSinceLastReminder = 999;
	}
	else
	{
		TurnSinceLastReminder = `THIS_TURN - SettingsState.SeenTutorialBlades[Index].Weight;
	}

	// Show the reminder every 6 turns until the player has built at least 3 Field Teams
	if (TurnSinceLastReminder < 6)
	{
		return false;
	}	
	if (CountFieldTeams() >= 3)
	{
		return false;
	}

	return true;
}

//---------------------------------------------------------------------------------------
static function CountAllTrainingAvailable(optional out int ClassTraining, optional out int ScarTraining)
{
	local XComGameStateHistory History;
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_Unit Unit;
	local X2DioTrainingProgramTemplate Training;
	local int i;

	History = `XCOMHISTORY;
	StratMgr = `STRAT_TEMPLATE_MGR;

	foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		if (Unit.AvailableTrainingPrograms.Length <= 0)
		{
			continue;
		}

		for (i = 0; i < Unit.AvailableTrainingPrograms.Length; ++i)
		{
			Training = X2DioTrainingProgramTemplate(StratMgr.FindStrategyElementTemplate(Unit.AvailableTrainingPrograms[i]));
			if (Training.Category == 'Scar')
			{
				ScarTraining++;
			}
			else if (Training.Category == 'Class')
			{
				ClassTraining++;
			}
		}
	}
}

//---------------------------------------------------------------------------------------
static function bool IsHiddenOperationActive()
{
	local XComGameState_InvestigationOperation CurrentOp;

	CurrentOp = class'DioStrategyAI'.static.GetCurrentOperation();
	if (CurrentOp != none)
	{
		return CurrentOp.Stage == eOpStage_Casework || CurrentOp.Stage == eOpStage_LeadActive;
	}

	return false;
}

//---------------------------------------------------------------------------------------
static function bool IsScavengerUnlockWorkerActive()
{
	return class'DioStrategyAI'.static.FindWorkerByName(class'XComGameState_DioStrategyScheduler'.default.DefaultUnlockScavengerMarketWorker) != none;
}

//---------------------------------------------------------------------------------------
static function name CheckWorkerRewardResourceTutorial(XComGameState_DioWorker Worker)
{
	local XComGameStateHistory History;
	local XComStrategyPresentationLayer StratPres;
	local XComGameState_StrategyAction WorkerAction;
	local XComGameState_Reward Reward;
	local int i;

	History = `XCOMHISTORY;
	StratPres = `STRATPRES;
	WorkerAction = Worker.GetStrategyAction();

	for (i = 0; i < WorkerAction.RewardRefs.Length; ++i)
	{
		Reward = XComGameState_Reward(History.GetGameStateForObjectID(WorkerAction.RewardRefs[i].ObjectID));
		switch (Reward.GetMyTemplateName())
		{
		case 'Reward_Credits':
			if (!StratPres.HasSeenTutorial('StrategyTutorial_CreditsResource'))
			{
				return 'StrategyTutorial_CreditsResource';
			}
			break;
		case 'Reward_Intel':
			if (!IsIntelResourceTutorialLocked() && !StratPres.HasSeenTutorial('StrategyTutorial_IntelResource'))
			{
				return 'StrategyTutorial_IntelResource';
			}
			break;
		case 'Reward_Elerium':
			if (!IsEleriumResourceTutorialLocked() && !StratPres.HasSeenTutorial('StrategyTutorial_EleriumResource'))
			{
				return 'StrategyTutorial_EleriumResource';
			}
			break;
		}
	}

	return '';
}

//---------------------------------------------------------------------------------------
static function int CountFieldTeams()
{
	local XComGameStateHistory History;
	local XComGameState_DioCityDistrict District;
	local int FieldTeams;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_DioCityDistrict', District)
	{
		if (District.FieldTeamRef.ObjectID > 0)
		{
			FieldTeams++;
		}
	}

	return FieldTeams;
}

//---------------------------------------------------------------------------------------
static function bool AreFieldTeamsAvailable()
{
	// System not on yet
	if (IsFieldTeamsTutorialLocked())
	{
		return false;
	}

	return true;
}

//---------------------------------------------------------------------------------------
//				GAME SYSTEM ACTIVATION CHECKS
//---------------------------------------------------------------------------------------

static function bool IsIntelResourceTutorialLocked()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}

	if (`DIOHQ.IsScavengerMarketUnlocked())
	{
		return false;
	}

	return IsFieldTeamsTutorialLocked();
}

//---------------------------------------------------------------------------------------
static function bool IsEleriumResourceTutorialLocked()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}

	return IsAssemblyTutorialLocked();
}

//---------------------------------------------------------------------------------------
static function bool IsUnrestTutorialLocked()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}
	
	return `THIS_TURN < default.UnrestUnlockedTurn;
}

//---------------------------------------------------------------------------------------
static function bool IsFieldTeamsTutorialLocked()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}

	return `THIS_TURN < default.FieldTeamsUnlockedTurn;
}

//---------------------------------------------------------------------------------------
static function bool IsSpecOpsTutorialLocked()
{
	local XComGameState_Investigation CurrentInvestigation;

	if (`TutorialEnabled == false)
	{
		return false;
	}

	CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();
	
	// Spec Ops unlocks with Act 1 Investigation Groundwork appearance
	if (CurrentInvestigation.Act <= 0)
	{
		return true;
	}
	else if (CurrentInvestigation.Act == 1)
	{
		return CurrentInvestigation.Stage == eStage_Groundwork;
	}	

	return false;
}

//---------------------------------------------------------------------------------------
static function bool RequireVisitSpecOps()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}

	return !IsSpecOpsTutorialLocked() && `STRATPRES.HasVisitedScreen('UISpecOpsScreen') == false;
}

//---------------------------------------------------------------------------------------
static function bool IsTrainingTutorialLocked()
{
	local XComGameState_Unit Unit;
	local bool bAnyUnitTraining;

	if (`TutorialEnabled == false)
	{
		return false;
	}

	// Not before Day 4
	if (`THIS_TURN < default.TrainingUnlockedTurn)
	{
		return true;
	}

	// After Day 4: as soon as any agent has scar or class training
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		if (Unit.AvailableTrainingPrograms.Length > 0 || 
			Unit.CompletedTrainingPrograms.Length > 0)
		{
			bAnyUnitTraining = true;
			break;
		}
	}
	if (!bAnyUnitTraining)
	{
		return true;
	}

	return false;
}

//---------------------------------------------------------------------------------------
static function bool RequireVisitTraining()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}

	return !IsTrainingTutorialLocked() && `STRATPRES.HasVisitedScreen('UIDIOTrainingScreen') == false;
}

//---------------------------------------------------------------------------------------
static function bool IsAssemblyTutorialLocked()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}

	// Not before Day 2
	return `THIS_TURN < default.AssemblyUnlockedTurn;
}

//---------------------------------------------------------------------------------------
static function bool RequireVisitAssembly()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}

	return !IsAssemblyTutorialLocked() && `STRATPRES.HasVisitedScreen('UIDIOAssemblyScreen') == false;
}

//---------------------------------------------------------------------------------------
// Tutorial gates for agent assignments
static function bool IsAssignmentAvailable(name AssignmentName)
{
	switch( AssignmentName )
	{
	case 'APC':				return true; 
	case 'Research':		return !IsAssemblyTutorialLocked();
	case 'SpecOps':			return !IsSpecOpsTutorialLocked();
	case 'Train':			return !IsTrainingTutorialLocked();
	case 'Armory':			return !IsArmoryTutorialLocked();
	case 'Supply':			return !IsSupplyTutorialLocked();
	case 'Investigation':	return !IsInvestigationStatusTutorialLocked();
	case 'ScavengerMarket': return `DIOHQ.IsScavengerMarketAvailable();
	case 'Test':			return false; // Used only as needed for dev/debugging [1/17/2020 dmcdonough]

	default:
		`RedScreen("DioStrategyTutorialHelper.IsAssignmentAvailable: unhandled assignment name:" @ string(AssignmentName) @ "@gameplay");
		
		// HELIOS BEGIN
		// Fix warning with reaching end of non-void function with missing Assignment name
		return false;
		// HELIOS END
	}
}

//---------------------------------------------------------------------------------------
static function bool IsArmoryTutorialLocked()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}
	return class'DioStrategyAI'.static.GetNextActIndex() <= 0;
}

//---------------------------------------------------------------------------------------
static function bool IsSupplyTutorialLocked()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}
	return class'DioStrategyAI'.static.GetNextActIndex() <= 0;
}

//---------------------------------------------------------------------------------------
static function bool IsInvestigationStatusTutorialLocked()
{
	if (`TutorialEnabled == false)
	{
		return false;
	}
	return class'DioStrategyAI'.static.GetNextActIndex() <= 0;
}
