//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_MissionSite.uc
//  AUTHOR:  Ryan McFall  --  02/18/2014
//  PURPOSE: This object represents the instance data for a mission site on the world map
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameState_MissionSite extends XComGameState_GeoscapeEntity
	native(Core);



var() name Source;
var() int RoundSpawned;		// Round this mission was spawned (counted from campaign start)
var() StateObjectReference ActionRef;	// Reference to the StrategyAction_Mission object that gates this mission
var() GeneratedMissionData GeneratedMission;
var() array<StateObjectReference> Rewards;
var() array<DarkEventStrategyData> DarkEvents;

var() string FlavorText;
var() string SuccessText;
var() string PartialSuccessText;
var() string FailureText;
var() array<MissionPerformanceResultData> PerformanceResults;	// DIO: data for UI to communicate rewards/penalties from gameplay (captures, civilian deaths)
var int ManualDifficultySetting;
var bool bUsePartialSuccessText;
var bool bHasSeenSkipPopup;
var bool bHasSeenLaunchMissionWarning;
var bool bHasPlayedSITREPNarrative;

var() array<Name> TacticalGameplayTags;	// A list of Tags representing modifiers to the tactical game rules

var array <String> AdditionalRequiredPlotObjectiveTags; // Additional Plot Objective Tags
var array <String> ExcludeMissionTypes; // Need to manually exclude these mission types
var array <String> ExcludeMissionFamilies; // Need to manually exclude these mission families
var bool bForceNoSitRep; // No sitreps from mission type, still allow forced plot-type sitreps

var public localized String m_strEnemyUnknown;

//---------------------------------------------------------------------------------------
// Mission Pre-Selection information

struct native X2SelectedEncounterData
{
	// The Encounter Id to be used
	var() Name SelectedEncounterName;

	// The spawning info generated for this encounter
	var() PodSpawnInfo EncounterSpawnInfo;
};

// DIO DEPRECATED Missions do not use a schedule in Dio [2/1/2019 dmcdonough]
struct native X2SelectedMissionData
{
	// The Alert Level for which this mission data is valid
	var() int AlertLevel;

	// The Force Level for which this mission data is valid
	var() int ForceLevel;

	// The name of the mission schedule which has been selected for this mission
	var() Name SelectedMissionScheduleName;

	// The list of encounters which have been selected for this mission
	var() array<X2SelectedEncounterData> SelectedEncounters;
};

// Mission data that has been selected for this Mission Site.
var() X2SelectedMissionData SelectedMissionData;
// END DIO DEPRECATED

// Interpreted data from campaign & strategy game state that drives mission difficulty
var() DioMissionDifficultyParams MissionDifficultyParams;
var() array<EnemyFactionSpawnInfo> FactionSpawnRatios;
var() array<EnemyFactionForceLevelInfo> FactionForceLevels;

var array<X2BackupUnitData> BackUpUnits;

//---------------------------------------------------------------------------------------
//
//
//				DIO FEATURES
//
//
//---------------------------------------------------------------------------------------
function XComGameState_StrategyAction_Mission GetMissionAction(optional XComGameState ModifyGameState)
{
	if (ModifyGameState != none)
	{
		return XComGameState_StrategyAction_Mission(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyAction_Mission', ActionRef.ObjectID));
	}

	return XComGameState_StrategyAction_Mission(`XCOMHISTORY.GetGameStateForObjectID(ActionRef.ObjectID));
}

//---------------------------------------------------------------------------------------
function GetMissionSquad(out array<StateObjectReference> OutUnitRefs, optional XComGameState ModifyGameState)
{
	local XComGameState_StrategyAction_Mission MissionAction;

	MissionAction = GetMissionAction(ModifyGameState);
	OutUnitRefs = MissionAction.AssignedUnitRefs;
}

//---------------------------------------------------------------------------------------
simulated function bool IsInvestigationMission()
{
	return GetMissionSource().DataName == 'MissionSource_InvestigationMission';
}

//---------------------------------------------------------------------------------------
// Return template from the first InvestigationOperation reward object associated with this mission (if any exists)
simulated function X2DioInvestigationOperationTemplate GetFirstInvestigationOperationTemplate()
{
	local XComGameStateHistory History;
	local X2StrategyElementTemplateManager StratMgr;
	local X2DioInvestigationOperationTemplate InvestigationOpTemplate;
	local XComGameState_Reward Reward;
	local StateObjectReference RewardRef;

	if (!IsInvestigationMission())
	{
		return none;
	}

	History = `XCOMHISTORY;
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	foreach Rewards(RewardRef)
	{
		Reward = XComGameState_Reward(History.GetGameStateForObjectID(RewardRef.ObjectID));
		InvestigationOpTemplate = X2DioInvestigationOperationTemplate(StratMgr.FindStrategyElementTemplate(Reward.RewardObjectTemplateName));
		if (InvestigationOpTemplate != none)
		{
			return InvestigationOpTemplate;
		}
	}

	return none;
}

//---------------------------------------------------------------------------------------
// Analyzes board state and populates MissionDifficultyParams data
simulated function InitMissionDifficulty()
{
	local XComGameStateHistory History;
	local XComGameState_DioCityDistrict CityDistrict;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_StrategyAction_Mission MissionAction;
	local XComGameState_DioWorker MissionWorker;
	local X2DioStrategyScheduleSourceTemplate StrategySourceTemplate;
	local XComGameState_Investigation CurrentInvestigation;
	local X2DioInvestigationTemplate InvestigationTemplate;
	local EnemyFactionForceLevelInfo FactionForceLevel;
	local EnemyFactionSpawnInfo FactionSpawnRatio;
	local int i;
	local XComGameState_InvestigationOperation CurrentOperation;
	local bool bOperationMission;

	// Early out: data mismatch
	if (GeneratedMission.MissionID != ObjectID)
	{
		`warn("XComGameState_MissionSite.InitMissionDifficulty: Generated Mission ID does not match this site");
		return;
	}

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;
	CityDistrict = XComGameState_DioCityDistrict(History.GetGameStateForObjectID(Region.ObjectID));
	CurrentInvestigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));
	InvestigationTemplate = CurrentInvestigation.GetMyTemplate();

	MissionAction = GetMissionAction();
	MissionWorker = MissionAction.GetWorker();

	CurrentOperation = class'DioStrategyAI'.static.GetCurrentOperation();
	bOperationMission = CurrentOperation.MissionWorkerRef.ObjectID == MissionWorker.ObjectID;

	MissionDifficultyParams.Act = CurrentInvestigation.Act;
	MissionDifficultyParams.Stage = CurrentInvestigation.CalcStageDifficultyValue();
	MissionDifficultyParams.District = (bOperationMission) ? 100 : CityDistrict.CalcDistrictDifficultyValue(self);
		
	StrategySourceTemplate = MissionWorker.GetMissionStrategySource();
	if (StrategySourceTemplate != none)
	{
		FactionSpawnRatios = StrategySourceTemplate.FactionSpawnRatios;
	}
	else 
	{
		FactionSpawnRatios.Length = 0;
		// No source? Faction mission, give them 100%
		if (InvestigationTemplate.FactionID != '')
		{
			FactionSpawnRatio.FactionID = InvestigationTemplate.FactionID;
			FactionSpawnRatio.Weight = 100;
			FactionSpawnRatios.AddItem(FactionSpawnRatio);
		}		
	}

	// Fallback case: assume 100% conspiracy since that is safe at any time in the campaign
	if (FactionSpawnRatios.Length == 0)
	{
		`warn("InitMissionDifficulty: no spawn ratios provided, defaulting to 100% Conspiracy spawns @gameplay");
		FactionSpawnRatio.FactionID = 'Conspiracy';
		FactionSpawnRatio.Weight = 100;
		FactionSpawnRatios.AddItem(FactionSpawnRatio);
	}

	// Convert strategy-side faction ratio into Investigation-accurate data
	for (i = 0; i < FactionSpawnRatios.Length; ++i)
	{ 
		if (FactionSpawnRatios[i].FactionID == 'Faction')
		{
			FactionSpawnRatios[i].FactionID = InvestigationTemplate.FactionID;
		}
	}

	// Apply forces levels for all entities included in spawn ratios
	FactionForceLevels.Length = 0;
	for (i = 0; i < FactionSpawnRatios.Length; ++i)
	{
		FactionForceLevel.FactionID = FactionSpawnRatios[i].FactionID;
		FactionForceLevel.ForceLevel = class'XComGameState_Investigation'.static.CalculateForceLevel(CurrentInvestigation, FactionForceLevel.FactionID);
		FactionForceLevels.AddItem(FactionForceLevel);
	}
}

//---------------------------------------------------------------------------------------
//
//
//				X2
//
//
//---------------------------------------------------------------------------------------

// If the mission cannot be started, returns the localized reason why
function bool CanLaunchMission(optional out string FailReason)
{
	local X2MissionSourceTemplate MissionSource;

	// check mission source requirements
	MissionSource = GetMissionSource();
	if(MissionSource.CanLaunchMissionFn != none && !MissionSource.CanLaunchMissionFn(self))
	{
		FailReason = MissionSource.CannotLaunchMissionTooltip;
		return false;
	}

	// check sitrep requirement
	if(!class'X2SitRepTemplate'.static.CanLaunchMission(self, FailReason))
	{
		return false;
	}

	return true;
}

//---------------------------------------------------------------------------------------
// Set all relevant values for the mission and start expiration timer (if applicable)
function BuildMission(X2MissionSourceTemplate MissionSource, 
	StateObjectReference DistrictRef, 
	XComGameState_Reward PrimaryReward,
	optional string MissionFamily,
	optional Vector2D v2Loc,
	optional bool bUseSpecifiedLevelSeed=false, 
	optional int LevelSeedOverride=0, 
	optional bool bSetMissionData=true)
{	
	Source = MissionSource.DataName;
	Location.x = v2Loc.x;
	Location.y = v2Loc.y;
	Region = DistrictRef;
	RoundSpawned = `THIS_TURN;
	
	if (bSetMissionData)
	{
		SetMissionData(bUseSpecifiedLevelSeed, LevelSeedOverride, PrimaryReward, MissionFamily);
	}
}

//---------------------------------------------------------------------------------------
// Called if the mission is ignored and allowed to expire
function IgnoreMission(XComGameState ModifyGameState)
{
	local X2MissionSourceTemplate MissionSource;
	local XComGameState_MissionSite MissionState;
	
	// Apply mission template failure effects
	MissionState = XComGameState_MissionSite(ModifyGameState.ModifyStateObject(class'XComGameState_MissionSite', ObjectID));
	MissionSource = MissionState.GetMissionSource();
	if (MissionSource.OnFailureFn != none)
	{
		MissionSource.OnFailureFn(ModifyGameState, MissionState);
	}

	`XEVENTMGR.TriggerEvent('STRATEGY_MissionIgnored_Immediate', MissionState, MissionState, ModifyGameState);
	RemoveEntity(ModifyGameState);
}

//---------------------------------------------------------------------------------------
simulated function string GetUIButtonTooltipTitle()
{
	return class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(GetMissionSource().MissionPinLabel);
}

//---------------------------------------------------------------------------------------
simulated function string GetUIButtonTooltipBody()
{
	// DIO DEPRECATED [6/6/2019 dmcdonough]
	return "";
}

//---------------------------------------------------------------------------------------
function SetMissionData(bool bUseSpecifiedLevelSeed, int LevelSeedOverride, XComGameState_Reward MissionReward, optional string MissionFamily="", optional array<string> ExcludeFamilies)
{
	local XComHeadquartersCheatManager CheatManager;
	local GeneratedMissionData EmptyData;
	local XComTacticalMissionManager MissionMgr;
	local XComParcelManager ParcelMgr;
	local string Biome;
	local X2MissionSourceTemplate MissionSource;
	local array<name> SourceSitReps;
	local name RewardName, SitRepName;
	local array<name> SitRepNames;
	local PlotTypeDefinition PlotTypeDef;
	local PlotDefinition SelectedDef;
	local String AdditionalTag;
	// HELIOS VARIABLES
	local array<X2DownloadableContentInfo> DLCInfos; 
	local int i; 
	// HELIOS VARIABLES

	MissionMgr = `TACTICALMISSIONMGR;
	ParcelMgr = `PARCELMGR;

	GeneratedMission = EmptyData;
	GeneratedMission.MissionID = ObjectID;

	// If a Mission Family was provided, find a def based on that
	if (MissionFamily != "")
	{
		MissionMgr.GetMissionDefinitionForFamily(MissionFamily, GeneratedMission.Mission, MissionReward);
	}
	else if (MissionReward != none)
	{
		// If any reward has been specified, use it to inform mission family selection
		RewardName = class'X2StrategyElement_DioMissionSources'.static.GetMissionRewardName(MissionReward);
		GeneratedMission.Mission = MissionMgr.GetMissionDefinitionForSource(Source, RewardName, ExcludeMissionFamilies, ExcludeMissionTypes);
	}
	
	GeneratedMission.LevelSeed = (bUseSpecifiedLevelSeed) ? LevelSeedOverride : class'Engine'.static.GetEngine().GetSyncSeed();
	GeneratedMission.SitReps.Length = 0;
	SitRepNames.Length = 0;

	// Add additional required plot objective tags
	foreach AdditionalRequiredPlotObjectiveTags(AdditionalTag)
	{
		GeneratedMission.Mission.RequiredPlotObjectiveTags.AddItem(AdditionalTag);
	}

	GeneratedMission.SitReps = GeneratedMission.Mission.ForcedSitreps;
	SitRepNames = GeneratedMission.Mission.ForcedSitreps;

	// Add Forced SitReps from Cheats
	CheatManager = XComHeadquartersCheatManager(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().CheatManager);
	if (CheatManager != none && CheatManager.ForceSitRepTemplate != '')
	{
		GeneratedMission.SitReps.AddItem(CheatManager.ForceSitRepTemplate);
		SitRepNames.AddItem(CheatManager.ForceSitRepTemplate);
		CheatManager.ForceSitRepTemplate = '';
	}
	else if (!bForceNoSitRep)
	{
		// No cheats, add SitReps from the Mission Source
		MissionSource = GetMissionSource();

		if(MissionSource.GetSitrepsFn != none)
		{
			SourceSitReps = MissionSource.GetSitrepsFn(self);

			foreach SourceSitReps(SitRepName)
			{
				if(GeneratedMission.SitReps.Find(SitRepName) == INDEX_NONE)
				{
					GeneratedMission.SitReps.AddItem(SitRepName);
					SitRepNames.AddItem(SitRepName);
				}
			}
		}
	}

	if (MissionReward != none)
	{
		GeneratedMission.MissionQuestItemTemplate = MissionMgr.ChooseQuestItemTemplate(Source, MissionReward.GetMyTemplate(), GeneratedMission.Mission);
	}

	if(GeneratedMission.Mission.sType == "")
	{
		`Redscreen("GetMissionDataForSourceReward() failed to generate a mission with: \n"
						$ " Source: " $ Source $ "\n RewardName: " $ RewardName);
	}

	// find a plot that supports the biome and the mission
	SelectBiomeAndPlotDefinition(GeneratedMission.Mission, Biome, SelectedDef, SitRepNames);

	// do a weighted selection of our plot
	GeneratedMission.Plot = SelectedDef;

	// find and assign our breach markup map
	SelectMarkupMap(GeneratedMission);

	// Add SitReps forced by Plot Type
	PlotTypeDef = ParcelMgr.GetPlotTypeDefinition(GeneratedMission.Plot.strType);

	foreach PlotTypeDef.ForcedSitReps(SitRepName)
	{
		if(GeneratedMission.SitReps.Find(SitRepName) == INDEX_NONE && 
			(SitRepName != 'TheLost' || GeneratedMission.SitReps.Find('TheHorde') == INDEX_NONE))
		{
			GeneratedMission.SitReps.AddItem(SitRepName);
		}
	}

	// the plot we find should either have no defined biomes, or the requested biome type
	//`assert( (GeneratedMission.Plot.ValidBiomes.Length == 0) || (GeneratedMission.Plot.ValidBiomes.Find( Biome ) != -1) );
	if (GeneratedMission.Plot.ValidBiomes.Length > 0)
	{
		GeneratedMission.Biome = ParcelMgr.GetBiomeDefinition(Biome);
	}

	// Battle Op Name
	GeneratedMission.BattleOpName = class'X2StrategyElement_DioMissionSources'.static.GetMissionBattleOpName(MissionSource, MissionReward);

	// Battle Description
	GeneratedMission.BattleDesc = class'X2StrategyElement_DioMissionSources'.static.GetMissionBattleDescription(MissionSource, MissionReward);

	if (GeneratedMission.Mission.MissionTypeName == '')
	{
		GeneratedMission.Mission.MissionTypeName = MissionMgr.GetMissionTypeName(GeneratedMission.Mission);
	}

	// HELIOS BEGIN
	// WotC CHL Issue #157
	// Sitreps don't exist in Dio, so call the function PostMissionCreation instead
	DLCInfos = `ONLINEEVENTMGR.GetDLCInfos(false);
	for(i = 0; i < DLCInfos.Length; ++i)
	{
		DLCInfos[i].PostMissionCreation(GeneratedMission, self);
	}
	// End Issue #157
}

//Run at a point where there is a battle data ready to go for the tactical mission - this will use the markup definition 
//to properly order the breach room encounters
static function ResolveRoomSequenceIntoStoredMapData(XComGameState_BattleData ModifyBattleData, MissionBreachMarkupDefinition MarkupDef)
{
	//Rooms handling
	local int NumAuthoredRooms;
	local int RoomLimit;
	local int RoomIndex;
	local int SubRoomIndex;
	local int RoomID;

	// override the default ascending room clearing order with the order defined in the mark up def
	NumAuthoredRooms = MarkupDef.RoomSequence.Length;
	RoomLimit = Max(0, Min(NumAuthoredRooms, ModifyBattleData.GetRoomLimit()));
	RoomIndex = 0;
	foreach MarkupDef.RoomSequence(RoomID)
	{
		for (SubRoomIndex = RoomIndex + 1; SubRoomIndex < NumAuthoredRooms; SubRoomIndex++)
		{
			if (RoomID == MarkupDef.RoomSequence[SubRoomIndex])
			{
				`RedscreenOnce(MarkupDef.MarkupMapname @ "has an invalid room sequence,RoomID:" @ RoomID @ "is present more than once. @leveldesign @dakota");
			}
		}
		if (RoomLimit <= 0 || (NumAuthoredRooms - RoomIndex <= RoomLimit))
		{
			ModifyBattleData.MapData.RoomIDs.AddItem(RoomID);
		}
		++RoomIndex;
	}

	//Copy the markup def over - as the battle map data is what the tactical game mostly uses to look this up
	ModifyBattleData.MapData.BreachMarkupDef = MarkupDef;
}

function bool SelectMarkupMap(out GeneratedMissionData OutGeneratedMission)
{
	local MissionBreachMarkupDefinition MissionMarkupDef;
	local bool bFoundMarkup;

	//Find a markup def that matches us
	foreach OutGeneratedMission.Plot.arrMarkUpMaps(MissionMarkupDef)
	{
		// look for markup maps with matching objective tag
		if (OutGeneratedMission.Mission.RequiredParcelObjectiveTags.Find(MissionMarkupDef.ObjectiveTag) != INDEX_NONE)
		{
			bFoundMarkup = true;
			OutGeneratedMission.MarkupDef = MissionMarkupDef;
			break;
		}
	}

	//Warn if we cannot find one
	if (!bFoundMarkup)
	{
		`redscreen("Map generation could not find an appropriate markup map for (Plot Map=" $ OutGeneratedMission.Plot.MapName $ " ObjectiveTag=" $ MissionMarkupDef.ObjectiveTag $ "). This will result in a non-functional mission. Fix the issue by specifying a valid markup map for this objective type in the the relevant plot map entry (DefaultPlots.ini)");
	}

	return bFoundMarkup;
}

static function bool FindMarkupMapForMissionType(string MissionType, out MissionBreachMarkupDefinition OutMissionMarkupDef)
{
	local XComTacticalMissionManager MissionManager;
	local MissionDefinition MissionDef;
	local XComParcelManager ParcelManager;
	local array<PlotDefinition> ValidPlots;
	local PlotDefinition Plot;
	local MissionBreachMarkupDefinition MissionMarkupDef;

	MissionManager = `TACTICALMISSIONMGR;
	if (MissionManager.GetMissionDefinitionForType(MissionType, MissionDef))
	{
		ParcelManager = `PARCELMGR;
		ParcelManager.GetValidPlotsForMission(ValidPlots, MissionDef);
		if (ValidPlots.Length > 0)
		{
			Plot = ValidPlots[0];

			//Find a markup def that matches us
			foreach Plot.arrMarkUpMaps(MissionMarkupDef)
			{
				// look for markup maps with matching objective tag
				if (MissionDef.RequiredParcelObjectiveTags.Find(MissionMarkupDef.ObjectiveTag) != INDEX_NONE)
				{
					OutMissionMarkupDef = MissionMarkupDef;
					return true;
				}
			}
		}
	}

	return false;
}


//---------------------------------------------------------------------------------------
private function SelectBiomeAndPlotDefinition(MissionDefinition MissionDef, out string Biome, out PlotDefinition SelectedDef, optional array<name> SitRepNames)
{	
	local array<string> ExcludeBiomes;
	
	ExcludeBiomes.Length = 0;
	
	SelectPlotDefinition(MissionDef, Biome, SelectedDef, ExcludeBiomes, SitRepNames);
}

//---------------------------------------------------------------------------------------
//Deprecated, but still left here for modding or other reference purposes
private function string SelectBiome(MissionDefinition MissionDef, out array<string> ExcludeBiomes)
{
	local string Biome;
	local int TotalValue, RollValue, CurrentValue, idx, BiomeIndex;
	local array<BiomeChance> BiomeChances;
	local string TestBiome;

	if(MissionDef.ForcedBiome != "")
	{
		return MissionDef.ForcedBiome;
	}

	// Grab Biome from location
	Biome = class'X2StrategyGameRulesetDataStructures'.static.GetBiome(Get2DLocation());

	if(ExcludeBiomes.Find(Biome) != INDEX_NONE)
	{
		Biome = "";
	}

	// Grab "extra" biomes which we could potentially swap too (used for Xenoform)
	BiomeChances = class'X2StrategyGameRulesetDataStructures'.default.m_arrBiomeChances;

	// Not all plots support these "extra" biomes, check if excluded
	foreach ExcludeBiomes(TestBiome)
	{
		BiomeIndex = BiomeChances.Find('BiomeName', TestBiome);

		if(BiomeIndex != INDEX_NONE)
		{
			BiomeChances.Remove(BiomeIndex, 1);
		}
	}

	// If no "extra" biomes just return the world map biome
	if(BiomeChances.Length == 0)
	{
		return Biome;
	}

	// Calculate total value of roll to see if we want to swap to another biome
	TotalValue = 0;

	for(idx = 0; idx < BiomeChances.Length; idx++)
	{
		TotalValue += BiomeChances[idx].Chance;
	}

	// Chance to use location biome is remainder of 100
	if(TotalValue < 100)
	{
		TotalValue = 100;
	}

	// Do the roll
	RollValue = `SYNC_RAND(TotalValue);
	CurrentValue = 0;

	for(idx = 0; idx < BiomeChances.Length; idx++)
	{
		CurrentValue += BiomeChances[idx].Chance;

		if(RollValue < CurrentValue)
		{
			Biome = BiomeChances[idx].BiomeName;
			break;
		}
	}

	return Biome;
}

//---------------------------------------------------------------------------------------
private function bool SelectPlotDefinition(MissionDefinition MissionDef, string Biome, out PlotDefinition SelectedDef, out array<string> ExcludeBiomes, optional array<name> SitRepNames)
{
	local XComParcelManager ParcelMgr;
	local X2CardManager CardManager;
	local XComValidationObject_MissionSelection ValidationObject;
	local string CardLabel;
	
	CardManager = class'X2CardManager'.static.GetCardManager();
	ParcelMgr = `PARCELMGR;
	ParcelMgr.SeedMissionFamilyPlotDecks();

	ValidationObject = new class'XComValidationObject_MissionSelection';
	ValidationObject.MissionName = MissionDef.MissionName;
	ValidationObject.MissionFamily = MissionDef.MissionFamily;
	ValidationObject.RequiredPlotObjectiveTags = MissionDef.RequiredPlotObjectiveTags;
	ValidationObject.SitRepNames = SitRepNames;

	if (CardManager.SelectNextCardFromDeck('PlotMapNames', CardLabel, ParcelMgr.ValidatePlotForMissionDef, ValidationObject))
	{
		if (ParcelMgr.GetPlotDefinitionForMapname(CardLabel, SelectedDef))
		{
			return true;
		}
	}

	// Biome deprecated [8/28/2019]
	Biome = "";

	return false;
}

//---------------------------------------------------------------------------------------
function X2MissionSourceTemplate GetMissionSource()
{
	local X2StrategyElementTemplateManager StratMgr;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	return X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate(Source));
}

//---------------------------------------------------------------------------------------
//Returns a string describing the goal / facility
function string GetMissionDescription()
{
	return class'X2MissionTemplateManager'.static.GetMissionTemplateManager().GetMissionDisplayName(GeneratedMission.Mission.MissionName);
}

//---------------------------------------------------------------------------------------
//Returns a string describing the geographic location of the mission site
function string GetLocationDescription()
{
	local X2StrategyElementTemplateManager StrategyElementTemplateManager;
	local X2MissionSiteDescriptionTemplate MissionSiteDescriptionTemplate;
	local XComParcelManager ParcelManager;
	local int Index;
	local string DescriptionString;

	ParcelManager = `PARCELMGR;
	StrategyElementTemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	for( Index = 0; Index < ParcelManager.arrPlotTypes.Length; ++Index )
	{
		if( ParcelManager.arrPlotTypes[Index].strType == GeneratedMission.Plot.strType )
		{
			MissionSiteDescriptionTemplate = X2MissionSiteDescriptionTemplate(StrategyElementTemplateManager.FindStrategyElementTemplate(ParcelManager.arrPlotTypes[Index].MissionSiteDescriptionTemplate));
			break;
		}
	}

	if( MissionSiteDescriptionTemplate != none )
	{
		DescriptionString = MissionSiteDescriptionTemplate.GetMissionSiteDescriptionFn(MissionSiteDescriptionTemplate.DescriptionString, self);
	}

	return DescriptionString;
}

//---------------------------------------------------------------------------------------
function X2RewardTemplate GetRewardType()
{
	local XComGameState_Reward RewardState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	RewardState = XComGameState_Reward(History.GetGameStateForObjectID(Rewards[0].ObjectID));

	return RewardState.GetMyTemplate();
}

//---------------------------------------------------------------------------------------
function string GetMissionTypeString()
{
	return GetRewardType().DisplayName;
}

//---------------------------------------------------------------------------------------
function string GetRewardAmountString()
{
	local XComGameState_Reward RewardState;
	local XComGameStateHistory History;
	local int idx;
	local string strTemp;

	History = `XCOMHISTORY;
	strTemp = "";
	
	for(idx = 0; idx < Rewards.Length; idx++)
	{
		RewardState = XComGameState_Reward(History.GetGameStateForObjectID(Rewards[idx].ObjectID));

		if(RewardState != none)
		{
			strTemp $= RewardState.GetRewardString();
			
			if(idx < (Rewards.Length - 1))
			{
				strTemp $= ", ";
			}
		}
	}

	return class'UIUtilities_Text'.static.FormatCommaSeparatedNouns(strTemp);
}

//---------------------------------------------------------------------------------------
function array<string> GetRewardAmountStringArray()
{
	local XComGameStateHistory History;
	local XComGameState_Reward RewardState;
	local array<string> arrRewards;
	local int idx;

	History = `XCOMHISTORY;

	for (idx = 0; idx < Rewards.Length; idx++)
	{
		RewardState = XComGameState_Reward(History.GetGameStateForObjectID(Rewards[idx].ObjectID));

		if (RewardState != none)
		{
			arrRewards.AddItem(RewardState.GetRewardString());
		}
	}

	return arrRewards;
}

//---------------------------------------------------------------------------------------
function string GetRewardIcon()
{
	local XComGameState_Reward RewardState;
	local XComGameStateHistory History;
	local int idx;

	History = `XCOMHISTORY;
	for(idx = 0; idx < Rewards.Length; idx++)
	{
		RewardState = XComGameState_Reward(History.GetGameStateForObjectID(Rewards[idx].ObjectID));

		if(RewardState != none)
		{
			return RewardState.GetRewardIcon();
		}
	}

	return "";
}

//---------------------------------------------------------------------------------------
function CleanUpRewards(XComGameState NewGameState)
{
	local XComGameState_Reward RewardState;
	local XComGameStateHistory History;
	local int idx;
	local bool bStartState;

	bStartState = (NewGameState.GetContext().IsStartState());
	History = `XCOMHISTORY;

	for(idx = 0; idx < Rewards.Length; idx++)
	{
		if(bStartState)
		{
			RewardState = XComGameState_Reward(NewGameState.GetGameStateForObjectID(Rewards[idx].ObjectID));
		}
		else
		{
			RewardState = XComGameState_Reward(History.GetGameStateForObjectID(Rewards[idx].ObjectID));
		}

		if(RewardState != none)
		{
			RewardState.CleanUpReward(NewGameState);
		}
	}
}

function name GetMissionSuccessEventID()
{
	return name(GeneratedMission.Mission.sType $ "_Success");
}

function name GetMissionFailureEventID()
{
	return name(GeneratedMission.Mission.sType $ "_Failure");
}

//---------------------------------------------------------------------------------------
function int GetMissionDifficulty(optional bool bDisplayOnly = false)
{
	local X2MissionSourceTemplate MissionSource;
	local int Difficulty;

	MissionSource = GetMissionSource();

	if (ManualDifficultySetting > 0)
	{
		Difficulty = ManualDifficultySetting;
	}
	else
	{
		if (MissionSource != none && MissionSource.GetMissionDifficultyFn != none)
		{
			Difficulty = MissionSource.GetMissionDifficultyFn(self);
		}
		else
		{
			// TODO: Ratio this against assessment of squad power? [12/18/2019 dmcdonough]
			Difficulty = class'XComTacticalMissionManager'.static.CalculateAlertLevelFromDifficultyParams(MissionDifficultyParams);
		}
	}

	Difficulty = Clamp(Difficulty, class'X2StrategyGameRulesetDataStructures'.default.MinMissionDifficulty,
		class'X2StrategyGameRulesetDataStructures'.default.MaxMissionDifficulty);

	return Difficulty;
}

//---------------------------------------------------------------------------------------
function string GetMissionDifficultyLabel(optional bool bNoColor = false)
{
	local string Text;
	local eUIState ColorState;
	local int Difficulty, LabelIdx;

	Difficulty = GetMissionDifficulty(true);

	LabelIdx = Clamp(Difficulty, 0, class'X2StrategyGameRulesetDataStructures'.default.MissionDifficultyLabels.Length - 1);
	Text = class'X2StrategyGameRulesetDataStructures'.default.MissionDifficultyLabels[LabelIdx];

	switch(Difficulty)
	{
	case 1: ColorState = eUIState_Good;     break;
	case 2: ColorState = eUIState_Normal;   break;
	case 3: ColorState = eUIState_Warning;  break;
	case 4: ColorState = eUIState_Bad;      break;
	}

	if (bNoColor)
	{
		return Text;
	}
	else
	{
		return class'UIUtilities_Text'.static.GetColoredText(Text, ColorState);
	}
}

//---------------------------------------------------------------------------------------
function string GetMissionBreachOptionsString()
{
	local XComMapManager MapManager;
	local X2UnitActionTemplate BreachActionTemplate;
	local X2TacticalElementTemplateManager TetManager;
	local X2BreachPointTypeTemplate BreachPointTypeTemplate;
	local array<X2BreachPointTypeTemplate> OutBreachPointTypeTemplates;
	local array<string> BreachPointStrings;
	local string FormattedString;
	local name BreachActionName;
	local int NumEncounters, i;
	local array<int> RoomIds;

	MapManager = `MAPS;
	TetManager = class'X2TacticalElementTemplateManager'.static.GetTacticalElementTemplateManager();

	NumEncounters = GetMissionUINumEncounters();
	for (i = GeneratedMission.MarkupDef.RoomSequence.length - NumEncounters; i < GeneratedMission.MarkupDef.RoomSequence.length; i++)
	{
		RoomIds.AddItem(GeneratedMission.MarkupDef.RoomSequence[i]);
	}
	MapManager.GetUniqueBreachPointTypeTemplatesInMarkupMap(name(GeneratedMission.MarkupDef.MarkupMapname), RoomIds, OutBreachPointTypeTemplates);
	foreach OutBreachPointTypeTemplates(BreachPointTypeTemplate)
	{
		BreachActionName = class'XComBreachHelpers'.static.GetDefaultActionNameForBreachEntryType(BreachPointTypeTemplate.Type);
		if (BreachActionName == '')
		{
			continue;
		}

		BreachActionTemplate = X2UnitActionTemplate(TetManager.FindTacticalElementTemplate(BreachActionName));
		if (BreachActionTemplate == none)
		{
			continue;
		}

		if (BreachPointStrings.Find(BreachActionTemplate.LocFriendlyName) == INDEX_NONE)
		{
			BreachPointStrings.AddItem(BreachActionTemplate.LocFriendlyName);
		}
	}

	FormattedString = class'UIUtilities_Text'.static.StringArrayToCommaSeparatedLine(BreachPointStrings);
	return FormattedString;
}


//---------------------------------------------------------------------------------------
function int GetMissionUINumEncounters()
{
	local int NumEncounters;

	// Use override if set (for missions that include level loads that confuse true room count)
	if (GeneratedMission.MarkupDef.RoomCountUIOverride > 0)
	{
		NumEncounters = GeneratedMission.MarkupDef.RoomCountUIOverride;
	}
	else
	{
		NumEncounters = GeneratedMission.MarkupDef.RoomSequence.Length;
	}
	
	// Clamp if the mission's room count has been truncated during generation
	if (GeneratedMission.RoomLimit > 0)
	{
		NumEncounters = Min(NumEncounters, GeneratedMission.RoomLimit);
	}

	return NumEncounters;
}

// DIO: Does this mission's generated map script end in an Evac encounter?
// HELIOS TODO: Use a configurable array type instead
function bool IsEvacMission()
{
	local int i;

	for (i = 0; i < GeneratedMission.Mission.MapNames.Length; ++i)
	{
		switch (GeneratedMission.Mission.MapNames[i])
		{
		case "Obj_ExtractVIP":
		case "Obj_FinaleConspiracy_A":
		case "Obj_RecoverObject":
		case "Obj_RescueVIP":
		case "Obj_Takedown_Progeny_A":
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
//----------- XComGameState_GeoscapeEntity Implementation -------------------------------
//---------------------------------------------------------------------------------------

protected function bool CanInteract()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
	return true;
}

function class<UIStrategyMapItem> GetUIClass()
{
	return class'UIStrategyMapItem_Mission';
}

function string GetUIWidgetFlashLibraryName()
{
	//return "MI_region"; // bsg-jneal (7.22.16): reusing region button for missions
	return "SimpleHint";
}

function string GetUIPinImagePath()
{
	return "";
}

// The static mesh for this entities 3D UI
function StaticMesh GetStaticMesh()
{
	local X2MissionSourceTemplate MissionSource;
	local string OverworldMeshPath;
	local Object MeshObject;

	MissionSource = GetMissionSource();
	OverworldMeshPath = "";

	if(MissionSource.GetOverworldMeshPathFn != none)
	{
		OverworldMeshPath = MissionSource.GetOverworldMeshPathFn(self);
	}

	if(OverworldMeshPath == "" && MissionSource.OverworldMeshPath != "")
	{
		OverworldMeshPath = MissionSource.OverworldMeshPath;
	}

	if(OverworldMeshPath != "")
	{
		MeshObject = `CONTENT.RequestGameArchetype(OverworldMeshPath);

		if(MeshObject != none && MeshObject.IsA('StaticMesh'))
		{
			return StaticMesh(MeshObject);
		}
	}

	return none;
}

// Scale adjustment for the 3D UI static mesh
function vector GetMeshScale()
{
	local vector ScaleVector;

	ScaleVector.X = 0.8;
	ScaleVector.Y = 0.8;
	ScaleVector.Z = 0.8;

	return ScaleVector;
}

function Rotator GetMeshRotator()
{
	local Rotator MeshRotation;

	MeshRotation.Roll = 0;
	MeshRotation.Pitch = 0;
	MeshRotation.Yaw = 0;

	return MeshRotation;
}

function bool ShouldBeVisible()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
	return true;
}

function bool RequiresSquad()
{
	return true;
}

function SelectSquad()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
}

// Complete the squad select interaction; the mission will not begin until this destination has been reached
function SquadSelectionCompleted()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
}

function SquadSelectionCancelled()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
}

function DestinationReached()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
}

function ConfirmMission()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
}

function RemoveEntity(XComGameState ModifyGameState)
{
	local bool SubmitLocally;

	// clean up the rewards for this mission
	CleanUpRewards(ModifyGameState);

	`XEVENTMGR.TriggerEvent('STRATEGY_MissionRemoved_Immediate', self, self, ModifyGameState);

	// remove this mission from the history
	ModifyGameState.RemoveStateObject(ObjectID);

	if( SubmitLocally )
	{
		`XCOMGAME.GameRuleset.SubmitGameState(ModifyGameState);
	}
}

function AttemptSelectionCheckInterruption()
{
	// Mission sites should never trigger interruption states since they are so important, so just
	// jump straight to the selection
	AttemptSelection();
}

protected function bool DisplaySelectionPrompt()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
	return true;
}

function MissionSelected()
{
	// DIO DEPRECATED [11/28/2018 dmcdonough]
}

simulated function string GetMissionObjectiveText()
{
	return class'X2MissionTemplateManager'.static.GetMissionTemplateManager().GetMissionDisplayName(GeneratedMission.Mission.MissionName);
}

simulated function bool IsVIPMission()
{
	return (class'XComTacticalMissionManager'.default.VIPMissionFamilies.Find(GeneratedMission.Mission.MissionFamily) != INDEX_NONE);
}

function string GetUIButtonIcon()
{
	// DIO DEPRECATED [9/18/2019 dmcdonough]
	return "img:///UILibrary_StrategyImages.X2StrategyMap.MissionIcon_GoldenPath";
}

//----------------------------------------------------------------
//----------------------------------------------------------------
//---------------------------------------------------------------------------------------
DefaultProperties
{    
}
