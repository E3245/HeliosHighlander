class XComParcelManager extends Object
	native(Core)
	dependson(XComTacticalMissionManager)
	config(Parcels);

const SMALLEST_PARCEL_SIZE = 16;



cpptext
{
	void Init();

	// helper struct allow us to sort the parcels without recomputing the priority indices
	// on every comparison
	struct FPlotSortHelper
	{
		FPlotDefinition PlotDef;
		INT PlotTypeIndex;
		INT PlotIndex;

		FPlotSortHelper()
		{
			appMemzero(this, sizeof(FPlotSortHelper));
		}

		FPlotSortHelper(EEventParm)
		{
			appMemzero(this, sizeof(FPlotSortHelper));
		}
	};

private:

#if XCOM_RETAIL
	void RemoveNonRetailPlots();
#endif

}

// START HELIOS Issue #39
// Un-const these variables so we can edit them
var config(Plots) array<PlotDefinition> arrPlots;
var config array<ParcelDefinition> arrAllParcelDefinitions;
var config(Plots) array<EntranceDefinition> arrAllEntranceDefinitions;
var config(Plots) array<PlotTypeDefinition> arrPlotTypes;
var config(Plots) array<BiomeDefinition> arrBiomes;
var config array<string> arrParcelTypes;
// END HELIOS Issue #39
var config(Plots) const float MaxDegreesToSpawnExit;
var config(Plots) const float MaxDistanceBetweenParcelToPlotPatrolLinks;
var config(Plots) const float SoldierSpawnSlush;

var privatewrite array<EntranceDefinition> arrEntranceDefinitions;

var privatewrite PlotTypeDefinition PlotType;

var int iLevelSeed;

var privatewrite array<XComParcel> arrParcels;
var XComParcel ObjectiveParcel;

var privatewrite XComPlotCoverParcelManager kPCPManager;

//Used by the editor to force certain maps to load
var EPIEForceInclude    ForceIncludeType; //Set to a value other than eForceInclude_None prior to running generate map.
var PlotDefinition      ForceIncludePlot;
var ParcelDefinition    ForceIncludeParcel;

var array<string> arrLayers;

var bool bToggleChaos;

var string ForceBiome;
var string ForceLighting;

var privatewrite XComGroupSpawn SoldierSpawn;
var privatewrite XComGroupSpawn LevelExit;

var bool bBlockingLoadParcels;

var privatewrite bool bGeneratingMap;
var privatewrite string GeneratingMapPhaseText;
var privatewrite int GeneratingMapPhase;
var bool bFinishedGeneratingMap;

//A start state object that is cached in InitParcels. Before using, always check for bReadonly to ensure that the start state it is a part of is still writable
var XComGameState_BattleData BattleDataState;

// the backtrack stack for the layout algorithm
var private array<ParcelBacktrackStackEntry> BacktrackStack;

var XComEnvLightingManager      EnvLightingManager;
var XComTacticalMissionManager  TacticalMissionManager;

// DIO
var private bool HasCachedCards; // Allows us to only cache the deck cards once per run

var transient array<object> SwappedObjectsToClear;

// delegate hook to allow rerouting of error output to an arbitrary receiever.
delegate ParcelGenerationAssertDelegate(string FullErrorMessage);

event ParcelGenerationAssert(bool Condition, string ErrorMessage)
{
	local string FullErrorMessage;

	if(!Condition)
	{
		FullErrorMessage = "Error in Parcel/Mission Generation!\n";
		FullErrorMessage $= ErrorMessage $ "\n";

		FullErrorMessage $= "Using:\n";

		FullErrorMessage $= " Mission: " $ TacticalMissionManager.ActiveMission.MissionName $ "\n";
		FullErrorMessage $= " Plot Map: " $ BattleDataState.MapData.PlotMapName $ "\n";
	
		if(ObjectiveParcel != none)
		{
			FullErrorMessage $= " Objective Map:" $ ObjectiveParcel.ParcelDef.MapName $ "\n";
		}
	
		if(ParcelGenerationAssertDelegate != none)
		{
			ParcelGenerationAssertDelegate(FullErrorMessage);
		}
		else
		{
			`Redscreen(FullErrorMessage);
		}
	}
}

// Normally, evac zones are spawned by xcom as part of mission flow, however, it is also possible for the LDs to
// hand place them in the level.
function InitPlacedEvacZone()
{
	local XComGameStateHistory History;
	local XComWorldData WorldData;
	local X2TacticalGameRuleset Rules;
	local X2Actor_EvacZone EvacZone;
	local XComGameState NewGameState;
	local XComGameState_EvacZone EvacZoneState;
	local bool SubmitState;
	local int EvacZoneCount;

	foreach `BATTLE.AllActors(class'X2Actor_EvacZone', EvacZone)
	{
		// catch more than one evac zone in the world errors
		EvacZoneCount++;
		if(EvacZoneCount > 1)
		{
			`Redscreen("More than one evac zone placed in the world, this is unsupported.");
			break;
		}

		History = `XCOMHISTORY;
		WorldData = `XWORLD;

		//Build the new game state data
		NewGameState = History.GetStartState();
		if(NewGameState == none)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding placed evac zone state");
			SubmitState = true;
		}

		EvacZoneState = XComGameState_EvacZone(NewGameState.CreateNewStateObject(class'XComGameState_EvacZone'));
		EvacZoneState.SetCenterLocation(WorldData.GetTileCoordinatesFromPosition(EvacZone.Location));

		// submit if needed
		if(SubmitState)
		{
			Rules = `TACTICALRULES;
			if(Rules == none || !Rules.SubmitGameState(NewGameState))
			{
				`Redscreen("Unable to submit evac zone state!");
			}
		}

		// and init the actor
		EvacZone.InitEvacZone(EvacZoneState);
	}
}

function XComGroupSpawn SpawnLevelExit()
{
	local array<XComGroupSpawn> arrAllExits;
	local XComGroupSpawn kExit;
	local XComGameState NewState;

	foreach class'WorldInfo'.static.GetWorldInfo().AllActors(class'XComGroupSpawn', kExit)
	{
		arrAllExits.AddItem(kExit);
	}

	ParcelGenerationAssert(arrAllExits.Length > 0, "No Exit could be spawned, no XComGroupSpawn Actors were found!");

	arrAllExits.RandomizeOrder();
	
	// sort is stable so all exits that are equally "good" will be chosen from randomly
	arrAllExits.Sort(SortLevelExits);

	assert(ScoreLevelExit(arrAllExits[0]) >= ScoreLevelExit(arrAllExits[arrAllExits.Length - 1]));

	// all of the highest score are at the front, so just pull the first one. We randomized the input.
	LevelExit = arrAllExits[0];
	LevelExit.SetVisible(true);

	LevelExit.TriggerGlobalEventClass(class'SeqEvent_OnTacticalExitCreated', LevelExit, 0);

	// save it to the history
	NewState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Level Exit Spawned");
	BattleDataState = XComGameState_BattleData(NewState.ModifyStateObject(class'XComGameState_BattleData', BattleDataState.ObjectID));
	BattleDataState.MapData.SoldierExitLocation = LevelExit.Location;
	`TACTICALRULES.SubmitGameState(NewState);

	return LevelExit;
}

private function int ScoreLevelExit(XComGroupSpawn Exit)
{
	local Vector ObjectiveToSpawn;
	local Vector ObjectivetoExit;
	local float DistanceFromObjective;
	local float Score;
	local float Cosine;

	ObjectiveToExit = Exit.Location - BattleDataState.MapData.ObjectiveLocation;
	DistanceFromObjective = VSize(ObjectiveToSpawn);

	// most important thing, are we a minimum distance away?
	if(DistanceFromObjective > TacticalMissionManager.ActiveMission.iExitFromObjectiveMinTiles)
	{
		Score += 4;
	}

	// second most important thing, are we within a certain range of angles away from the 
	// spawn to objective vector? This discourages backtracking
	ObjectiveToSpawn = SoldierSpawn.Location - BattleDataState.MapData.ObjectiveLocation;
	Cosine = Normal(ObjectiveToExit) dot Normal(ObjectiveToSpawn);
	if(Cosine > cos(MaxDegreesToSpawnExit * DegToRad))
	{
		Score += 2;
	}

	// lastly, try to stay below a certain distance
	if(DistanceFromObjective < TacticalMissionManager.ActiveMission.iExitFromObjectiveMaxTiles)
	{
		Score += 1;
	}

	return Score;
}

private function int SortLevelExits(XComGroupSpawn Exit1, XComGroupSpawn Exit2)
{
	local int ExitScore1;
	local int ExitScore2;

	ExitScore1 = ScoreLevelExit(Exit1);
	ExitScore2 = ScoreLevelExit(Exit2);

	if(ExitScore1 == ExitScore2)
	{
		return 0;
	}
	else
	{
		return ExitScore1 > ExitScore2 ? 1 : -1;
	}
}

native function CleanupLevelReferences();
native function PlotDefinition GetPlotDefinition(string strMapName, string strBiome="");
native function int GetMinimumCivilianCount();

function OutputParcelInfo(optional bool DarkLines = false)
{
	local XComParcel kParcel;
	local XComPlotCoverParcel kPCP;
	local XComWorldData WorldData;
	local BoxSphereBounds Bounds;
	local string strTemp;
	local int iRotXDegrees;
	local int iRotYDegrees;
	local int iRotZDegrees;
	local int ColorIntensity;

	ColorIntensity = DarkLines ? 25 : 255;

	WorldData = `XWORLD;
	foreach `XWORLDINFO.AllActors(class'XComParcel', kParcel)
	{
		if (kParcel.bDeleteMe == false && kParcel.bPendingDelete == false)
		{
			iRotXDegrees = (((kParcel.Rotation.Pitch%65536)/16384)*90);
			iRotYDegrees = (((kParcel.Rotation.Yaw%65536)/16384)*90);
			iRotZDegrees = (((kParcel.Rotation.Roll%65536)/16384)*90);
			
			// draw a box that shows the extend of what is contained in the parcel. Note that it is adjusted slightly to be taller and
			// slightly smaller so that adjacent boxes don't overlap.
			Bounds = kParcel.ParcelMesh.Bounds;
			Bounds.Origin.Z = 37 + WorldData.GetFloorZForPosition(Bounds.Origin); // 32 units up (half the extent), plus a bit extra to avoid ground clipping
			Bounds.BoxExtent.Z = 64;
			kParcel.DrawDebugBox(Bounds.Origin, Bounds.BoxExtent, ColorIntensity, 0, ColorIntensity, true);

			strTemp = "LevelSeed:"@`BATTLE.iLevelSeed@"\nParcel:"@kParcel.ParcelDef.MapName@" Rot:"$iRotXDegrees@","@iRotYDegrees@","@iRotZDegrees;
			`log(strTemp,,'XCom_ParcelOutput');
			kParcel.DrawDebugString(Bounds.Origin, strTemp, none, MakeColor(ColorIntensity, 0, ColorIntensity, 255));
		}
	}

	foreach `XWORLDINFO.AllActors(class'XComPlotCoverParcel', kPCP)
	{
		if (kParcel.bDeleteMe == false && kParcel.bPendingDelete == false)
		{
			iRotXDegrees = (((kPCP.Rotation.Pitch%65536)/16384)*90);
			iRotYDegrees = (((kPCP.Rotation.Yaw%65536)/16384)*90);
			iRotZDegrees = (((kPCP.Rotation.Roll%65536)/16384)*90);

			Bounds = kPCP.ParcelMesh.Bounds;
			Bounds.Origin.Z = 37 + WorldData.GetFloorZForPosition(Bounds.Origin);
			Bounds.BoxExtent.Z = 64;
			kPCP.DrawDebugBox(Bounds.Origin, Bounds.BoxExtent, ColorIntensity, ColorIntensity, 0, true);

			strTemp = "PCP:"@kPCP.strLevelName@" Rot:"$iRotXDegrees@","@iRotYDegrees@","@iRotZDegrees@"\n";
			`log(strTemp,,'XCom_ParcelOutput');
			kPCP.DrawDebugString(Bounds.Origin, strTemp, none, MakeColor(ColorIntensity, ColorIntensity, 0, 255));
		}
	}	
}

native function LinkParcelPatrolPathsToPlotPaths();
native function ClearLinksFromParcelPatrolPathsToPlotPaths();

private function CacheParcels()
{
	local XComParcel Parcel;

	arrParcels.Length = 0;

	foreach `XWORLDINFO.AllActors(class'XComParcel', Parcel)
	{
		if (Parcel.bDeleteMe == false && Parcel.bPendingDelete == false)
		{
			arrParcels.AddItem(Parcel);
		}
	}

	
	// sort the parcels. This ensures that load order doesn't change their location in
	// the array from run to run
	arrParcels.Sort(SortParcels);
}

// We need to sort the parcel actors before filling them out so that we guarantee
// that they are in a consistent order. They do not always load in the same order, and this will
// prevent the layout algorithm from coming up with the same solution when given the
// same seed
private function int SortParcels(XComParcel Parcel1, XComParcel Parcel2)
{
	if(Parcel1.Location.X == Parcel2.Location.X)
	{
		return Parcel1.Location.Y > Parcel2.Location.Y ? 1 : -1;
	}
	else
	{
		return Parcel1.Location.X > Parcel2.Location.X ? 1 : -1;
	}
}


// get the current priority list of parcel definitions from the card manager based on how recently they were seen
// by the player.
private function array<ParcelDefinition> GetRandomizedParcelDefinitions()
{
	local X2CardManager CardManager;
	local array<string> ParcelMapNames;
	local string ParcelMapName;
	local array<ParcelDefinition> Result;
	local ParcelDefinition ParcelDef;
	local int PlotTypeIndex;
	local XComMapManager MapManager;

	CardManager = class'X2CardManager'.static.GetCardManager();
	MapManager = `MAPS;

	// add cards for all parcel definitions that are of the correct plot type
	// it's possible that parcels were added since the last time the game was run, so this needs to happen every
	// time we generate a map
	foreach arrAllParcelDefinitions(ParcelDef)
	{
		PlotTypeIndex = ParcelDef.arrPlotTypes.Find('strPlotType', PlotType.strType);
		if(PlotTypeIndex != INDEX_NONE) // only need to add cards for parcels we will actually check
		{
			CardManager.AddCardToDeck('Parcels', ParcelDef.MapName, ParcelDef.arrPlotTypes[PlotTypeIndex].fWeight);
		}
	}

	// Get the current priority order of maps. Most recently seen maps will be at the end of the array
	CardManager.GetAllCardsInDeck('Parcels', ParcelMapNames);

	// and get the parcel def for each map
	foreach ParcelMapNames(ParcelMapName)
	{
		if (!MapManager.DoesMapPackageExist(ParcelMapName))
		{
			`Redscreen("ERROR: UXComParcelManager::GetRandomizedParcelDefinitions - Excluding Parcel Map: '"@ParcelMapName@"', Unable to find associated package");
			CardManager.RemoveCardFromDeck('Parcels', ParcelMapName);
			continue;
		}

		if(GetParcelDefinitionForMapname(ParcelMapName, ParcelDef))
		{
			if(ParcelDef.arrPlotTypes.Find('strPlotType', PlotType.strType) != INDEX_NONE) // could be other plot type cards from previous missions in the deck
			{
				Result.AddItem(ParcelDef);
			}
		}
	}

	// and return
	return Result;
}

private function GenerateParcelLayout(optional bool bMonolithic=false)
{
	local array<ParcelDefinition> RandomizedParcelDefinitions;
	local PlotDefinition PlotDef;
	local MissionBreachMarkupDefinition MissionMarkupDef;
	local string PlotMapPeriphName;

	//Sentinel values
	local bool bUsesPeriphMap;
	local bool bFoundMarkup;

	//Rooms handling
	local int NumAuthoredRooms;
	local int RoomLimit;
	local int RoomIndex;
	local int SubRoomIndex;
	local int RoomID;
	
	
	//Clear out the battle data object
	BattleDataState.MapData.ActiveLayers.Length = 0;
	BattleDataState.MapData.ParcelData.Length = 0;
	BattleDataState.MapData.PlotCoverParcelData.Length = 0;

	ComputePlotType();

	// grab all parcels on the map
	CacheParcels();

	// Do periph map
	if(!bMonolithic)
	{
		PlotMapPeriphName = BattleDataState.MapData.PlotMapName $ "_periph";
		bUsesPeriphMap = false;
		if (`MAPS.DoesMapPackageExist(PlotMapPeriphName))
		{
			`MAPS.AddStreamingMap(PlotMapPeriphName, vect(0, 0, 0), rot(0, 0, 0), false, true);
			bUsesPeriphMap = true;
		}
	}	

	// this needs to be initalized in case we need to inspect the pcp definitons to
	// choose an objective PCP
	kPCPManager = new class'XComPlotCoverParcelManager';
	kPCPManager.InitPlotCoverParcels(PlotType.strType, BattleDataState);

	// get a randomized array of parcel definitions. Since the layout algorithm is deterministic, we
	// randomize the input data to get a random output
	RandomizedParcelDefinitions = GetRandomizedParcelDefinitions();

	// now choose our parcels
	if(TacticalMissionManager.ActiveMission.ObjectiveSpawnsOnPCP)
	{
		ChooseObjectivePCP();
	}
	else
	{
		ChooseObjectiveParcel(RandomizedParcelDefinitions);
	}

	ChooseNonObjectiveParcels(RandomizedParcelDefinitions);

	// fill out the pcps first and start them loading
	if (!bMonolithic && !bUsesPeriphMap)
	{
		kPCPManager.bBlockingLoadParcels = bBlockingLoadParcels;
		kPCPManager.ChoosePCPs();
		kPCPManager.InitPeripheryPCPs();
	}

	// also load markup map if it's specified
	PlotDef = GetPlotDefinition(BattleDataState.MapData.PlotMapName);
	foreach PlotDef.arrMarkUpMaps(MissionMarkupDef)
	{
		// look for markup maps with matching objective tag
		if (BattleDataState.MapData.ActiveMission.RequiredParcelObjectiveTags.Find(MissionMarkupDef.ObjectiveTag) != INDEX_NONE)
		{
			// add the markup map to level streaming list
			`MAPS.AddStreamingMap(MissionMarkupDef.MarkupMapname, vect(0, 0, 0), rot(0, 0, 0), bBlockingLoadParcels, true, true);

			BattleDataState.MapData.BreachMarkupDef = MissionMarkupDef;

			// override the default ascending room clearing order
			// with the order defined in the mark up def
			NumAuthoredRooms = MissionMarkupDef.RoomSequence.Length;
			RoomLimit = Max(0, Min(NumAuthoredRooms, BattleDataState.GetRoomLimit()));
			RoomIndex = 0;
			foreach MissionMarkupDef.RoomSequence(RoomID)
			{
				for (SubRoomIndex = RoomIndex + 1; SubRoomIndex < NumAuthoredRooms; SubRoomIndex++)
				{
					if (RoomID == MissionMarkupDef.RoomSequence[SubRoomIndex])
					{
						`RedscreenOnce(MissionMarkupDef.MarkupMapname @ "has an invalid room sequence,RoomID:" @ RoomID @ "is present more than once. @leveldesign @dakota");
					}
				}
				if (RoomLimit <= 0 || (NumAuthoredRooms - RoomIndex <= RoomLimit))
				{
					BattleDataState.MapData.RoomIDs.AddItem(RoomID);
				}
				++RoomIndex;
			}

			// currently there is only one markup map for a specific mission on a parcel
			bFoundMarkup = true;
			break;
		}
	}

	//Warn if we canno
	if (!bFoundMarkup)
	{
		`redscreen("Map generation could not find an appropriate markup map for (Plot Map=" $ BattleDataState.MapData.PlotMapName $ " ObjectiveTag=" $ MissionMarkupDef.ObjectiveTag $ "). This will result in a non-functional mission. Fix the issue by specifying a valid markup map for this objective type in the the relevant plot map entry (DefaultPlots.ini)");
	}
}

//PARCEL MGR REFACTOR REMOVE
private function ChooseNonObjectiveParcels(array<ParcelDefinition> RandomizedParcelDefinitions)
{
	
}

// this is only meant to be called from layout algorithm. It is not a general purpose function 
private function bool IsParcelDefinitionValidForLayout(ParcelDefinition ParcelDef, 
														XComParcel Parcel, 
														out Rotator Rotation,
														optional array<ParcelDefinition> RandomizedParcelDefinitions)
{
	local int Index;

	// check if we fit here
	if(ParcelDef.eSize != Parcel.GetSizeType())
	{
		return false;
	}

	// don't allow definitions that are locked to being objective parcels
	if(ParcelDef.ObjectiveTags.Length > 0 && !ParcelDef.bAllowNonObjectiveOverride)
	{
		return false;
	}

	// don't dupe the parcel map for the objective parcel
	if(ParcelDef.MapName == ObjectiveParcel.ParcelDef.MapName)
	{
		return false;
	}

	// now check to see if it collides with any previously placed parcel definitions
	for(Index = 0; Index < BacktrackStack.Length - 1; Index++) // length minus 1, since this parcel is on top of the stack
	{
		if(RandomizedParcelDefinitions[BacktrackStack[Index].CurrentParcelIndex].MapName == ParcelDef.MapName)
		{
			// a previous parcel has already claimed this parcel definition, let's not duplicate it
			return false;
		}
	};

	// Check general requirements. Do this last as these tests are more expensive
	if(!MeetsFacingAndEntranceRequirements(ParcelDef, Parcel, Rotation))
	{
		return false;
	}

	if(!MeetsZoningRequirements(Parcel, ParcelDef.arrZoneTypes))
	{
		return false;
	}

	//if(!MeetsLayerRequirements(Parcel, ParcelDef))
	//{
	//	return false;
	//}

	return true;
}

//PARCEL MGR REFACTOR REMOVE
private function ChooseObjectiveParcel(array<ParcelDefinition> RandomizedParcelDefinitions)
{
	local array<ParcelDefinition> ValidDefinitions;
	local ParcelDefinition ParcelDef;
	local int ParcelIndex;
	local XComParcel Parcel;
	local Rotator Rotation;
	local XComPlayerController PlayerController;

	// get all valid objective definitions
	GetValidParcelDefinitionsForObjective(RandomizedParcelDefinitions,
										  ValidDefinitions);

	ParcelGenerationAssert(ValidDefinitions.Length > 0, "No valid objective definitions were found"); // no parcel definition that we can use as the objective exists!
	ParcelGenerationAssert(arrParcels.Length > 0, "No parcels were found, was a plot map not loaded?"); // no parcels, did we load a map?
	
	//Inform the briefing screen that we have chosen the objective parcel
	foreach class'WorldInfo'.static.GetWorldInfo().AllActors(class'XComPlayerController', PlayerController)
	{
		break;
	}

	// Find the parcel def that matches our plot ( temporary while parcels are still a thing )
	foreach ValidDefinitions(ParcelDef)
	{
		for (ParcelIndex = 0; ParcelIndex < arrParcels.Length; ParcelIndex++)
		{
			Parcel = arrParcels[ParcelIndex];
			if (Parcel.CanBeObjectiveParcel				
				&& ParcelDef.MapName == BattleDataState.MapData.PlotMapName)
			{
				ObjectiveParcel = Parcel;
				BattleDataState.MapData.ObjectiveParcelIndex = ParcelIndex;
				if (BattleDataState.MapData.bMonolithic)
				{
					Rotation = rotator(vect(0, 0, 0));
				}
				InitParcelWithDef(Parcel, ParcelDef, Rotation, false);
				PlayerController.UpdateUIBriefingScreen(ParcelDef.MapName);
				return;
			}
		}
	}

	// safety fallback in case we can't find a valid place to put an objective parcel. Just put it anywhere it will
	// generally fit.
	ParcelGenerationAssert(false, "Could not find a valid objective parcel.");
	foreach ValidDefinitions(ParcelDef)
	{
		ParcelDef.bForceEntranceCount = 0; // ignore entrances
		for(ParcelIndex = 0; ParcelIndex < arrParcels.Length; ParcelIndex++)
		{
			Parcel = arrParcels[ParcelIndex];
			if(Parcel.GetSizeType() == ParcelDef.eSize
				&& MeetsFacingAndEntranceRequirements(ParcelDef, Parcel, Rotation))
			{
				ObjectiveParcel = Parcel;
				InitParcelWithDef(Parcel, ParcelDef, Rotation, false);
				PlayerController.UpdateUIBriefingScreen(ParcelDef.MapName);
				return;
			}
		}
	}
}

// Filters the provided list of parcels down to only objective parcels valid for the current mission.
native function GetValidParcelDefinitionsForObjective(array<ParcelDefinition> Definitions, out array<ParcelDefinition> ValidDefinitions);

// returns true if the given plot can be used with the given mission
native function bool IsPlotValidForMission(const out PlotDefinition PlotDef, const out MissionDefinition MissionDef) const;

// Gets all plot that are valid for the specified mission, in priority order
native function GetValidPlotsForMission(out array<PlotDefinition> ValidPlots, const out MissionDefinition Mission, optional string Biome = "");

//-------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------

//PARCEL MGR REFACTOR REMOVE
private function ChooseObjectivePCP()
{
	local WorldInfo World;
	local XComPlotCoverParcel ObjectivePCP;
	local XComPlotCoverParcel PCP;
	local array<PCPDefinition> ValidPCPDefinitons;
	local PCPDefinition ObjectivePCPDefiniton;
	local int TotalValid;
	local XComPlayerController PlayerController;

	World = `XWORLDINFO;

	// pick a valid objectivePCP at random
	foreach World.AllActors(class'XComPlotCoverParcel', PCP)
	{
		if(PCP.bCanBeObjective)
		{
			TotalValid++;
			if(ObjectivePCP == none || `SYNC_RAND(TotalValid) == 0)
			{
				ObjectivePCP = PCP;
			}
		}
	}
	
	if(ObjectivePCP == none)
	{
		ParcelGenerationAssert(false, "No XComPlotCoverParcel actor on this map is marked bCanBeObjective == true.");
		foreach World.AllActors(class'XComPlotCoverParcel', ObjectivePCP)
		{
			break; // just use the first one as a fallback, better to spawn an objective somewhere than not at all
		}
	}

	BattleDataState.MapData.ObjectiveParcelIndex = -1;

	// Spawn a parcel at this location
	ObjectiveParcel = World.Spawn(class'XComParcel', World,, ObjectivePCP.Location, ObjectivePCP.Rotation);
	arrParcels.AddItem(ObjectiveParcel);

	// and fill out the objective parcel parcel def with all the information it needs to
	// load in the pcp map
	ValidPCPDefinitons = kPCPManager.GetValidObjectivePCPDefs(ObjectivePCP, TacticalMissionManager.ActiveMission);
	ParcelGenerationAssert(ValidPCPDefinitons.Length > 0, "No valid PCPDefinition found for the objective PCP actor");
	ObjectivePCPDefiniton = ValidPCPDefinitons[`SYNC_RAND(ValidPCPDefinitons.Length)];

	//Inform the briefing screen that we have chosen the objective parcel
	foreach class'WorldInfo'.static.GetWorldInfo().AllActors(class'XComPlayerController', PlayerController)
	{
		break;
	}		
	PlayerController.UpdateUIBriefingScreen(ObjectivePCPDefiniton.MapName);

	ObjectiveParcel.ParcelDef.MapName = ObjectivePCPDefiniton.MapName;
	ObjectiveParcel.ParcelDef.arrAvailableLayers = ObjectivePCPDefiniton.arrAvailableLayers;
	InitParcelWithDef(ObjectiveParcel, ObjectiveParcel.ParcelDef, ObjectivePCP.Rotation, false);

	// remove the PCP actor
	ObjectivePCP.Destroy();

	// remove any linked PCP actors
	foreach ObjectivePCP.arrPCPsToBlockOnObjectiveSpawn(PCP)
	{
		PCP.Destroy();
	}
}

function ConfigureRooms()
{	
	local PlotDefinition PlotDef;
	local MissionBreachMarkupDefinition MissionMarkupDef;	

	//Sentinel values	
	local bool bFoundMarkup;

	//Rooms handling
	local int NumAuthoredRooms;
	local int RoomLimit;
	local int RoomIndex;
	local int SubRoomIndex;
	local int RoomID;

	if (BattleDataState == none)
	{

	}

	// also load markup map if it's specified
	PlotDef = GetPlotDefinition(BattleDataState.MapData.PlotMapName);
	foreach PlotDef.arrMarkUpMaps(MissionMarkupDef)
	{
		// look for markup maps with matching objective tag
		if (BattleDataState.MapData.ActiveMission.RequiredParcelObjectiveTags.Find(MissionMarkupDef.ObjectiveTag) != INDEX_NONE)
		{
			// add the markup map to level streaming list
			`MAPS.AddStreamingMap(MissionMarkupDef.MarkupMapname, vect(0, 0, 0), rot(0, 0, 0), bBlockingLoadParcels, true, true);

			BattleDataState.MapData.BreachMarkupDef = MissionMarkupDef;

			// override the default ascending room clearing order
			// with the order defined in the mark up def
			NumAuthoredRooms = MissionMarkupDef.RoomSequence.Length;
			RoomLimit = Max(0, Min(NumAuthoredRooms, BattleDataState.GetRoomLimit()));
			RoomIndex = 0;
			foreach MissionMarkupDef.RoomSequence(RoomID)
			{
				for (SubRoomIndex = RoomIndex + 1; SubRoomIndex < NumAuthoredRooms; SubRoomIndex++)
				{
					if (RoomID == MissionMarkupDef.RoomSequence[SubRoomIndex])
					{
						`RedscreenOnce(MissionMarkupDef.MarkupMapname @ "has an invalid room sequence,RoomID:" @ RoomID @ "is present more than once. @leveldesign @dakota");
					}
				}
				if (RoomLimit <= 0 || (NumAuthoredRooms - RoomIndex <= RoomLimit))
				{
					BattleDataState.MapData.RoomIDs.AddItem(RoomID);
				}
				++RoomIndex;
			}

			// currently there is only one markup map for a specific mission on a parcel
			bFoundMarkup = true;
			break;
		}
	}

	//Warn if we canno
	if (!bFoundMarkup)
	{
		`redscreen("Map generation could not find an appropriate markup map for (Plot Map=" $ BattleDataState.MapData.PlotMapName $ " ObjectiveTag=" $ MissionMarkupDef.ObjectiveTag $ "). This will result in a non-functional mission. Fix the issue by specifying a valid markup map for this objective type in the the relevant plot map entry (DefaultPlots.ini)");
	}
}

function SilenceDestruction()
{
	local XComDestructibleActor kDestructible;
	local XComDestructibleActor_Action_RadialDamage kRadialDamage;
	local int idx;

	foreach `XWORLDINFO.AllActors(class'XComDestructibleActor', kDestructible)
	{
		for (idx = 0; idx < kDestructible.DamagedEvents.Length; idx++)
		{
			if (kDestructible.DamagedEvents[idx].Action.IsA(Name("XComDestructibleActor_Action_PlaySoundCue")))
			{
				if(kDestructible.DamagedEvents[idx].Action.bActivated)
				{
					kDestructible.DamagedEvents[idx].Action.Deactivate();
				}
			}
		}

		for (idx = 0; idx < kDestructible.DestroyedEvents.Length; idx++)
		{
			if (kDestructible.DestroyedEvents[idx].Action.IsA(Name("XComDestructibleActor_Action_PlaySoundCue")) ||
				kDestructible.DestroyedEvents[idx].Action.IsA(Name("XComDestructibleActor_Action_PlayEffectCue")))
			{
				if(kDestructible.DestroyedEvents[idx].Action.bActivated)
				{
					kDestructible.DestroyedEvents[idx].Action.Deactivate();
				}
			}
			if (kDestructible.DestroyedEvents[idx].Action.IsA(Name("XComDestructibleActor_Action_RadialDamage")))
			{
				if(kDestructible.DestroyedEvents[idx].Action.bActivated)
				{
					kRadialDamage = XComDestructibleActor_Action_RadialDamage(kDestructible.DestroyedEvents[idx].Action);
					kRadialDamage.EnvironmentalDamage = 0;
					kRadialDamage.UnitDamage = 0;
				}
			}
		}

		for (idx = 0; idx < kDestructible.AnnihilatedEvents.Length; idx++)
		{
			if (kDestructible.AnnihilatedEvents[idx].Action.IsA(Name("XComDestructibleActor_Action_PlaySoundCue")) ||
				kDestructible.AnnihilatedEvents[idx].Action.IsA(Name("XComDestructibleActor_Action_PlayEffectCue")))
			{
				if(kDestructible.AnnihilatedEvents[idx].Action.bActivated)
				{
					kDestructible.AnnihilatedEvents[idx].Action.Deactivate();
				}
			}
			if (kDestructible.AnnihilatedEvents[idx].Action.IsA(Name("XComDestructibleActor_Action_RadialDamage")))
			{
				if(kDestructible.AnnihilatedEvents[idx].Action.bActivated)
				{
					kRadialDamage = XComDestructibleActor_Action_RadialDamage(kDestructible.AnnihilatedEvents[idx].Action);
					kRadialDamage.EnvironmentalDamage = 0;
					kRadialDamage.UnitDamage = 0;
				}
			}
		}
	}
}

function ScoreSoldierSpawn(XComGroupSpawn Spawn)
{
	local float SpawnDistanceSq;
	local MissionSchedule ActiveSchedule;
	local int MinSpawnDistance, IdealSpawnDistance;
	local XComGameState_BattleData LocalBattleStateData;
	local X2SitRepEffect_ModifyXComSpawn SitRepEffect;
	local int BreachingRoomID;

	TacticalMissionManager.GetActiveMissionSchedule(ActiveSchedule);

	SpawnDistanceSq = (BattleDataState != None) ? VSizeSq(Spawn.Location - BattleDataState.MapData.ObjectiveLocation) : 0.0f;

	MinSpawnDistance = ActiveSchedule.MinXComSpawnDistance;
	IdealSpawnDistance = ActiveSchedule.IdealXComSpawnDistance;

	BreachingRoomID = -1;
	LocalBattleStateData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (LocalBattleStateData != none)
	{
		foreach class'X2SitreptemplateManager'.static.IterateEffects(class'X2SitRepEffect_ModifyXComSpawn', SitRepEffect, LocalBattleStateData.ActiveSitReps)
		{
			SitRepEffect.ModifyLocations( IdealSpawnDistance, MinSpawnDistance );
		}

		BreachingRoomID = LocalBattleStateData.BreachingRoomID;
		
		if (BreachingRoomID < 0 && LocalBattleStateData.MapData.RoomIDs.Length > 0)
		{
			// BreachingRoomID is unset, so we must choose the first room
			BreachingRoomID = LocalBattleStateData.MapData.RoomIDs[0];
		}
	}

	//Dio: if a breach is occurring our weight is based on a matching roomID
	if (BreachingRoomID >= 0)
	{
		if (Spawn.BreachRoomID != BreachingRoomID)
		{
			Spawn.Score = 0;
		}
		else
		{
			Spawn.Score = 1.0f;
		}
	}	
	// no weight to spawn locations inside the minimum required distance
	else if( SpawnDistanceSq < Square(MinSpawnDistance * class'XComWorldData'.const.WORLD_StepSize) )
	{
		Spawn.Score = 0;
	}
	else
	{
		// weight equal to inverse of abs of the diff between actual and ideal + some random slush
		Spawn.Score = (SpawnDistanceSq / (SpawnDistanceSq + Abs(SpawnDistanceSq - Square(IdealSpawnDistance * class'XComWorldData'.const.WORLD_StepSize)))) + (`SYNC_FRAND * SoldierSpawnSlush);
	}
}

function int SoldierSpawnSort(XComGroupSpawn Spawn1, XComGroupSpawn Spawn2)
{
	if(Spawn1.Score == Spawn2.Score)
	{
		return 0;
	}
	else
	{
		return Spawn1.Score > Spawn2.Score ? 1 : -1;
	}
}

// Finds all spawns that are valid for selection for this mission, and returns them sorted by suitability
function GetValidSpawns(out array<XComGroupSpawn> arrSpawns)
{
	//local array<XComFalconVolume> arrFalconVolumes;
	//local XComFalconVolume kFalconVolume;
	local XComGroupSpawn kSpawn;

	// look for falcon volumes (soldier spawn limiters). If found, only spawns within a falcon volume will
	// be considered
	//foreach `XWORLDINFO.AllActors(class'XComFalconVolume', kFalconVolume)
	//{
	//	arrFalconVolumes.AddItem(kFalconVolume);
	//}

	// collect all spawns
	foreach `XWORLDINFO.AllActors(class'XComGroupSpawn', kSpawn)
	{
		//if(arrFalconVolumes.Length == 0)
		//{
			ScoreSoldierSpawn(kSpawn);
			if( kSpawn.Score > 0.0 )
			{
				arrSpawns.AddItem(kSpawn);
			}
		//}
		//else
		//{
		//	// if falcon volumes exist, only accept spawns that lie within them
		//	foreach arrFalconVolumes(kFalconVolume)
		//	{
		//		if(kFalconVolume.ContainsPoint(kSpawn.Location))
		//		{
		//			ScoreSoldierSpawn(kSpawn);
		//			if( kSpawn.Score > 0.0 )
		//			{
		//				arrSpawns.AddItem(kSpawn);
		//			}
		//			break;
		//		}
		//	}
		//}

		kSpawn.SetVisible(false);
	}

	// now randomize them
	arrSpawns.RandomizeOrder();

	// sort them into groups based on suitability. Since the random order is preserved for all spawns with the same
	// suitability, we can just grab the first one off the list.
	arrSpawns.Sort(SoldierSpawnSort);
}


function GetValidBreachPoints(out array<XComDeploymentSpawn> OutBreachPoints)
{
	local XComDeploymentSpawn BreachPoint;

	foreach `XWORLDINFO.AllActors(class'XComDeploymentSpawn', BreachPoint)
	{
		// @todo: can add tagging, linking etc here to only select certain group of breach points based on the mission
		OutBreachPoints.AddItem(BreachPoint);
	}
}

function XComGroupSpawn FindValidSoldierSpawn(int SquadSize)
{
	local XComGroupSpawn ValidSpawn;
	local array<XComGroupSpawn> arrSpawns;
	local int SpawnIndex;
	
	GetValidSpawns(arrSpawns);

	// since these are sorted by suitability (but still random within a given suitability),
	// keep taking the spawns off the top until we find a spawn that has valid spawn locations
	ValidSpawn = none;
	for (SpawnIndex = 0; SpawnIndex < arrSpawns.Length && ValidSpawn == none; SpawnIndex++)
	{
		ValidSpawn = arrSpawns[SpawnIndex];		
		if (!ValidSpawn.HasValidFloorLocations(SquadSize))
		{
			// this spawn has been blocked by spawned geometry or is otherwise invalid, skip it
			ValidSpawn = none;
		}
	}
	return ValidSpawn;
}

function ChooseSoldierSpawn()
{
	local XComGameState_BattleData BattleData;
	local int SquadSize;
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	SquadSize = (BattleDataState != None) ? BattleDataState.MapData.ActiveMission.SquadSpawnSizeOverride : (BattleData != None) ? BattleData.MapData.ActiveMission.SquadSpawnSizeOverride : 0;
	SoldierSpawn = FindValidSoldierSpawn(SquadSize);
	if (SoldierSpawn != none && BattleDataState != none)
	{
		BattleDataState.MapData.SoldierSpawnLocation = SoldierSpawn.Location;
	}
}

function RebuildWorldData(optional bool bIsMonolithic=false)
{
	local XComLevelVolume LevelVolume;

	//Only rebuild the world data if the level volume exists
	LevelVolume = XComLevelVolume(`XWORLD.Outer);
	if(LevelVolume != none && LevelVolume.IsValid() )
	{
		FinalizeRoomClearingOrder();
		`XWORLD.bEnableRebuildTileData = true; //World data should not be processed prior to this point during load
		if(bIsMonolithic)
		{
			`XWORLD.FixupMonolithicWorldData(none);
		}
		else
		{
			`XWORLD.BuildWorldData(none);
		}
		`XWORLD.RebuildDestructionData();
	}
	else
	{
		class'X2TacticalGameRuleset'.static.ReleaseScriptLog( "Loading Map Phase 3: XComWorldData.NumX already set!" );
	}
}

function OnParcelLoadCompleted(Name LevelPackageName, optional LevelStreaming LevelStreamedIn = new class'LevelStreaming')
{
	LinkParcelPatrolPathsToPlotPaths();
}

// Adding light clipping and environment maps to the TQL requires world data to be rebuilt when a parcel is changed
// This function needs to be set when a parcel is selected
function OnParcelLoadCompletedAfterParcelSelection(Name LevelPackageName, optional LevelStreaming LevelStreamedIn = new class'LevelStreaming')
{
	LinkParcelPatrolPathsToPlotPaths();

	RebuildWorldData();

	// if this is the new objective parcel, then respawn objectives
	if(ObjectiveParcel != None && ObjectiveParcel.ParcelDef.MapName == string(LevelPackageName))
	{
		TacticalMissionManager.SpawnMissionObjectives();
	}

	`XWORLDINFO.MyLightClippingManager.BuildFromScript();
	`XWORLDINFO.MyLocalEnvMapManager.ResetCaptures();
}

// Alternate initialization to init with a specific parcel definition
function InitParcelWithDef(XComParcel kParcel, ParcelDefinition ParcelDef, Rotator rRot, bool bFromParcelSelection)
{
	local StoredMapData_Parcel		ParcelData;
	local XComGameState_BattleData	LocalBattleStateData;
	local XComMapManager			MapManager;
	local PlotDefinition PlotDef;
	local PlotLightingDefinition PlotLightingDef;

	MapManager = `MAPS;

	// mark this parcel card as used so it doesn't come up again in the near future. Don't mark objective PCPs though,
	// as they aren't in the deck and will redscreen
	if(!TacticalMissionManager.ActiveMission.ObjectiveSpawnsOnPCP || kParcel != ObjectiveParcel)
	{
		class'X2CardManager'.static.GetCardManager().MarkCardUsed('Parcels', ParcelDef.MapName);
	}

	kParcel.ParcelDef = GetParcelDefinitionWithTransformedEntrances(ParcelDef, rRot);

	kParcel.FixupEntrances(PlotType.bUseEmptyClosedEntrances, arrEntranceDefinitions);

	// Choose OnParcelLoadCompleted function based on whether this parcel load is coming from the TQL parcel selection or not
	if (!BattleDataState.MapData.bMonolithic)
	{
		MapManager.AddStreamingMap(kParcel.ParcelDef.MapName, kParcel.Location, rRot, bBlockingLoadParcels, true, true, bFromParcelSelection ? OnParcelLoadCompletedAfterParcelSelection : OnParcelLoadCompleted);
	}

	// save main parcel data
	ParcelData.Location = kParcel.Location;
	ParcelData.Rotation = rRot;
	ParcelData.MapName = kParcel.ParcelDef.MapName;
	ParcelData.ParcelArrayIndex = arrParcels.Find(kParcel);
	ParcelData.BrandIndex = class'XComBrandManager'.static.GetRandomBrandForMap(ParcelData.MapName);
	kParcel.SaveEntrances(ParcelData);

	// add to the save data store
	LocalBattleStateData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	LocalBattleStateData.MapData.ParcelData.AddItem(ParcelData);

	if(!BattleDataState.MapData.bMonolithic)
	{
		foreach arrPlots(PlotDef)
		{
			foreach PlotDef.arrLightingDefinitions(PlotLightingDef)
			{
				if (LocalBattleStateData.MapData.PlotMapName == PlotDef.MapName &&
					PlotLightingDef.LightingMapType == LocalBattleStateData.MapData.PlotLightingMapType)
				{
					MapManager.AddStreamingMap(PlotLightingDef.LightingMapName, kParcel.Location, rRot, bBlockingLoadParcels, true, true);
				}
			}
		}
	}
}

function ComputePlotType()
{
	local int idx;
	local string strMapName;
	
	arrEntranceDefinitions.Remove(0, arrEntranceDefinitions.Length);

	//First, attempt to get the plot map name from the battle data. If this fails, fall beck to using the world info
	strMapName = BattleDataState.MapData.PlotMapName;

	//RAM - deprecated - backwards compatibility support
	if( strMapName == "" )
	{
		strMapName = class'Engine'.static.GetCurrentWorldInfo().GetMapName();
	}
	for (idx=0; idx < arrPlots.Length; idx++)
	{
		if (Locs(arrPlots[idx].MapName) == Locs(strMapName))
		{
			PlotType = GetPlotTypeDefinition(arrPlots[idx].strType);
			break;
		}
	}

	// Narrow down entrances to ones with the correct plot type
	for (idx = 0; idx < arrAllEntranceDefinitions.Length; idx++)
	{
		if(arrAllEntranceDefinitions[idx].strPlotType == PlotType.strType || Len(arrAllEntranceDefinitions[idx].strPlotType) == 0)
		{
			arrEntranceDefinitions.AddItem(arrAllEntranceDefinitions[idx]);
		}
	}
}

function AssignLayerDistribution()
{
	local XComParcel kParcel;
	local string strLayerName;
	local int iSpawnChance;

	// 50% across the board until we figure out how this is controlled
	iSpawnChance = 50;

	foreach `XWORLDINFO.AllActors(class'XComParcel', kParcel)
	{
		foreach arrLayers(strLayerName)
		{
			if(`SYNC_RAND_TYPED(100) > iSpawnChance)
			{
				kParcel.arrRequiredLayers.AddItem(strLayerName);
			}
		}
	}
}

native function PlotTypeDefinition GetPlotTypeDefinition(string strType);

function BiomeDefinition GetBiomeDefinition(string strType)
{
	local int Index;	

	//If the biome has been forced, make it so	
	if(ForceBiome != "")
	{
		strType = ForceBiome;
	}

	Index = arrBiomes.Find('strType', strType);

	return (Index != INDEX_NONE) ? arrBiomes[Index] : arrBiomes[0];
}

function bool MeetsZoningRequirements(XComParcel kParcel, array<string> arrZoneTypes)
{
	local int idx;
	local int i;

	if (kParcel.arrForceZoneTypes.Length == 0 || arrZoneTypes.Length == 0)
	{
		return true;
	}

	for (idx = 0; idx < arrZoneTypes.Length; idx++)
	{
		for (i = 0; i < kParcel.arrForceZoneTypes.Length; i++)
		{
			if(kParcel.arrForceZoneTypes[i] == arrZoneTypes[idx])
			{
				return true;
			}
		}
	}

	return false;
}

// Returns true if the parcel actor originally had one or more facing set, false otherwise
function FillParcelFacingArray(XComParcel kParcel, out array<EParcelFacingType> arrParcelFacings)
{
	if(kParcel.bFacingNorth)
	{
		arrParcelFacings.AddItem(EParcelFacingType_N);
	}
	if(kParcel.bFacingEast)
	{
		arrParcelFacings.AddItem(EParcelFacingType_E);
	}
	if(kParcel.bFacingSouth)
	{
		arrParcelFacings.AddItem(EParcelFacingType_S);
	}
	if(kParcel.bFacingWest)
	{
		arrParcelFacings.AddItem(EParcelFacingType_W);
	}
	if(!kParcel.bFacingNorth && !kParcel.bFacingEast && !kParcel.bFacingSouth && ! kParcel.bFacingWest)
	{
		arrParcelFacings.AddItem(EParcelFacingType_N);
		arrParcelFacings.AddItem(EParcelFacingType_E);
		arrParcelFacings.AddItem(EParcelFacingType_S);
		arrParcelFacings.AddItem(EParcelFacingType_W);
	}
}

function bool FoundMatchingFacing(ParcelDefinition ParcelDef, XComParcel kParcel, out Rotator rRot)
{
	local ParcelDefinition TransformedParcelDef;

	// Validate entrance counts
	if (ParcelDef.eFacing != EParcelFacingType_None)
	{
		if(kParcel.eFacing == EParcelFacingType_None)
		{
			// parceldefs with a facing require a parcel with a facing!
			return false;
		}

		// transform to match facing
		rRot = ComputeRotationToMatchFacing(ParcelDef.eFacing, kParcel.eFacing);
		TransformedParcelDef = GetParcelDefinitionWithTransformedEntrances(ParcelDef, rRot);

		return MeetsForceEntrancesRequirements(TransformedParcelDef, kParcel) && MeetsParcelAlignment(ParcelDef.eFacing, kParcel, rRot);
	}
	else
	{
		// no facing requirement so try all options
		ParcelDef.eFacing = EParcelFacingType_N;
		rRot = ComputeRotationToMatchFacing(ParcelDef.eFacing, kParcel.eFacing);
		TransformedParcelDef = GetParcelDefinitionWithTransformedEntrances(ParcelDef, rRot);
		if(MeetsForceEntrancesRequirements(TransformedParcelDef, kParcel) && MeetsParcelAlignment(ParcelDef.eFacing, kParcel, rRot))
		{
			return true;
		}

		ParcelDef.eFacing = EParcelFacingType_E;
		rRot = ComputeRotationToMatchFacing(ParcelDef.eFacing, kParcel.eFacing);
		TransformedParcelDef = GetParcelDefinitionWithTransformedEntrances(ParcelDef, rRot);
		if(MeetsForceEntrancesRequirements(TransformedParcelDef, kParcel) && MeetsParcelAlignment(ParcelDef.eFacing, kParcel, rRot))
		{
			return true;
		}

		ParcelDef.eFacing = EParcelFacingType_S;
		rRot = ComputeRotationToMatchFacing(ParcelDef.eFacing, kParcel.eFacing);
		TransformedParcelDef = GetParcelDefinitionWithTransformedEntrances(ParcelDef, rRot);
		if(MeetsForceEntrancesRequirements(TransformedParcelDef, kParcel) && MeetsParcelAlignment(ParcelDef.eFacing, kParcel, rRot))
		{
			return true;
		}

		ParcelDef.eFacing = EParcelFacingType_W;
		rRot = ComputeRotationToMatchFacing(ParcelDef.eFacing, kParcel.eFacing);
		TransformedParcelDef = GetParcelDefinitionWithTransformedEntrances(ParcelDef, rRot);
		if(MeetsForceEntrancesRequirements(TransformedParcelDef, kParcel) && MeetsParcelAlignment(ParcelDef.eFacing, kParcel, rRot))
		{
			return true;
		}
					
		return false;
	}	
}

function bool MeetsFacingAndEntranceRequirements(ParcelDefinition ParcelDef, XComParcel Parcel, out Rotator Rot)
{
	local array<EParcelFacingType> arrParcelFacings;
	local int Index;

	FillParcelFacingArray(Parcel, arrParcelFacings);
	
	while (arrParcelFacings.Length > 0)
	{
		Index = `SYNC_RAND_TYPED(arrParcelFacings.Length);
		Parcel.eFacing = arrParcelFacings[Index];
		if(FoundMatchingFacing(ParcelDef, Parcel, Rot))
		{
			return true;
		}
			
		arrParcelFacings.RemoveItem(arrParcelFacings[Index]);
	}

	return false;
}

function bool MeetsParcelAlignment(EParcelFacingType eSourceFacing, XComParcel kParcel, out Rotator rRot)
{
	local int iMultiplesOf90;

	if(kParcel.SizeX == kParcel.SizeY)
	{
		// square parcels always align regards of which way they are facing.
		return true;
	}

	rRot = ComputeRotationToMatchFacing(eSourceFacing, kParcel.eFacing);
	iMultiplesOf90 = abs(rRot.Yaw/16384);

	if (kParcel.Rotation.Yaw == 0)
	{
		// Only 0 and 180 rotations acceptable
		return (iMultiplesOf90 == 0 || iMultiplesOf90 == 2);
	}
	else
	{
		// Only 90 and 270 rotations acceptable
		return (iMultiplesOf90 == 1 || iMultiplesOf90 == 3);
	}
}

function bool MeetsForceEntrancesRequirements(ParcelDefinition ParcelDef, XComParcel kParcel)
{
	local int EntranceCount;

	if(ParcelDef.bHasEntranceN1 && kParcel.bHasEntranceN1) EntranceCount++;
	if(ParcelDef.bHasEntranceN2 && kParcel.bHasEntranceN2) EntranceCount++;
	if(ParcelDef.bHasEntranceS1 && kParcel.bHasEntranceS1) EntranceCount++;
	if(ParcelDef.bHasEntranceS2 && kParcel.bHasEntranceS2) EntranceCount++;

	if(ParcelDef.bHasEntranceE1 && kParcel.bHasEntranceE1) EntranceCount++;
	if(ParcelDef.bHasEntranceE2 && kParcel.bHasEntranceE2) EntranceCount++;
	if(ParcelDef.bHasEntranceW1 && kParcel.bHasEntranceW1) EntranceCount++;
	if(ParcelDef.bHasEntranceW2 && kParcel.bHasEntranceW2) EntranceCount++;

	return EntranceCount >= ParcelDef.bForceEntranceCount;
}

function Rotator ComputeRotationToMatchFacing(EParcelFacingType eSourceFacing, EParcelFacingType eTargetFacing)
{
	local int iFacingDiff;
	local Rotator rRot;

	iFacingDiff = eSourceFacing - eTargetFacing;

	rRot.Yaw = iFacingDiff*-16384;

	return rRot;

}

function ParcelDefinition GetParcelDefinitionWithTransformedEntrances(ParcelDefinition ParcelDef, Rotator r)
{
	local ParcelDefinition TransformedParcelDef;

	TransformedParcelDef = ParcelDef;

	if (r.Yaw == 16384 || r.Yaw == -49142)
	{
		TransformedParcelDef.bHasEntranceE1 = ParcelDef.bHasEntranceN1;
		TransformedParcelDef.bHasEntranceE2 = ParcelDef.bHasEntranceN2;
		TransformedParcelDef.bHasEntranceS1 = ParcelDef.bHasEntranceE1;
		TransformedParcelDef.bHasEntranceS2 = ParcelDef.bHasEntranceE2;
		TransformedParcelDef.bHasEntranceW1 = ParcelDef.bHasEntranceS1;
		TransformedParcelDef.bHasEntranceW2 = ParcelDef.bHasEntranceS2;
		TransformedParcelDef.bHasEntranceN1 = ParcelDef.bHasEntranceW1;
		TransformedParcelDef.bHasEntranceN2 = ParcelDef.bHasEntranceW2;
	}
	else if(r.Yaw == 32768 || r.Yaw == -32768)
	{
		TransformedParcelDef.bHasEntranceS1 = ParcelDef.bHasEntranceN1;
		TransformedParcelDef.bHasEntranceS2 = ParcelDef.bHasEntranceN2;
		TransformedParcelDef.bHasEntranceW1 = ParcelDef.bHasEntranceE1;
		TransformedParcelDef.bHasEntranceW2 = ParcelDef.bHasEntranceE2;
		TransformedParcelDef.bHasEntranceN1 = ParcelDef.bHasEntranceS1;
		TransformedParcelDef.bHasEntranceN2 = ParcelDef.bHasEntranceS2;
		TransformedParcelDef.bHasEntranceE1 = ParcelDef.bHasEntranceW1;
		TransformedParcelDef.bHasEntranceE2 = ParcelDef.bHasEntranceW2;
	}
	else if(r.Yaw == 49152 || r.Yaw == -16384)
	{
		TransformedParcelDef.bHasEntranceW1 = ParcelDef.bHasEntranceN1;
		TransformedParcelDef.bHasEntranceW2 = ParcelDef.bHasEntranceN2;
		TransformedParcelDef.bHasEntranceN1 = ParcelDef.bHasEntranceE1;
		TransformedParcelDef.bHasEntranceN2 = ParcelDef.bHasEntranceE2;
		TransformedParcelDef.bHasEntranceE1 = ParcelDef.bHasEntranceS1;
		TransformedParcelDef.bHasEntranceE2 = ParcelDef.bHasEntranceS2;
		TransformedParcelDef.bHasEntranceS1 = ParcelDef.bHasEntranceW1;
		TransformedParcelDef.bHasEntranceS2 = ParcelDef.bHasEntranceW2;
	}

	return TransformedParcelDef;
}

native function XComParcel GetContainingParcel( const out vector vLoc );

//====================================================
// ParcelMgr Utilities

/// <summary>
/// Searches the parcel list for a definition with a MapName that matches the argument, and assigns it into the
/// out parameter. Returns TRUE if a match was found, FALSE if not.
/// </summary>
/// <param name="MapName">The map name for the parcel to match</param>
function bool GetParcelDefinitionForMapname(string MapName, out ParcelDefinition OutParcelDefinition)
{
	local int Index;

	for( Index = 0; Index < arrAllParcelDefinitions.Length; ++Index )
	{
		if( arrAllParcelDefinitions[Index].MapName == MapName )
		{
			OutParcelDefinition = arrAllParcelDefinitions[Index];
			return true;
		}
	}

	return false;
}

/// <summary>
/// Searches the plot list for a definition with a MapName that matches the argument, and assigns it into the
/// out parameter. Returns TRUE if a match was found, FALSE if not.
/// </summary>
/// <param name="MapName">The map name for the plot to match</param>
function bool GetPlotDefinitionForMapname(string MapName, out PlotDefinition OutPlotDef)
{
	local int Index;

	for (Index = 0; Index < arrPlots.Length; ++Index)
	{
		if (arrPlots[Index].MapName == MapName)
		{
			OutPlotDef = arrPlots[Index];
			return true;
		}
	}

	return false;
}

/// <summary>
/// Removes any plot definitions that are not valid for use with the given mission data
/// </summary>
function RemovePlotDefinitionsThatAreInvalidForMission(out array<PlotDefinition> PlotDefinitions, MissionDefinition Mission)
{
	local array<PlotDefinition> ValidMissionPlots;
	local array<string> ValidPlotMaps;
	local PlotDefinition PlotDef;
	local int Index;

	GetValidPlotsForMission(ValidMissionPlots, Mission);
	foreach ValidMissionPlots(PlotDef)
	{
		ValidPlotMaps.AddItem(PlotDef.MapName);
	}

	for(Index = PlotDefinitions.Length - 1; Index >= 0; Index--)
	{
		PlotDef = PlotDefinitions[Index];
		if(ValidPlotMaps.Find(PlotDef.MapName) == INDEX_NONE)
		{
			PlotDefinitions.Remove(Index, 1);
		}
	}
}

/// <summary>
/// Searches the plot list for a definition with a strType that matches the argument, and fills the out parameter
/// array with the results.
/// </summary>
/// <param name="PlotType">The plot type string to match when searching for plots</param>
function GetPlotDefinitionsForPlotType(string InPlotType, string strBiome, out array<PlotDefinition> OutPlotDefinitions)
{
	local int Index;

	for( Index = 0; Index < arrPlots.Length; ++Index )
	{
		if( arrPlots[Index].strType == InPlotType &&
			(strBiome == "" || arrPlots[Index].ValidBiomes.Find(strBiome) != INDEX_NONE) )
		{
			OutPlotDefinitions.AddItem(arrPlots[Index]);
		}
	}
}

function SeedMissionFamilyPlotDecks()
{
	local X2CardManager CardManager;
	local PlotDefinition PlotDef;

	if (HasCachedCards)
	{
		return;
	}

	// add all plots to decks by objective tag, which corresponds to mission family
	CardManager = class'X2CardManager'.static.GetCardManager();
	foreach arrPlots(PlotDef)
	{
		CardManager.AddCardToDeck('PlotMapNames', PlotDef.MapName);
	}
}

function bool ValidatePlotForMissionDef(string CardLabel, Object ValidationData)
{
	local XComValidationObject_MissionSelection MissionSelectionData;
	local X2SitRepTemplateManager SitRepMgr;
	local PlotDefinition PlotDef;
	local X2SitRepTemplate SitRep;
	local string RequiredPlotObjective;
	local name SitRepName;

	MissionSelectionData = XComValidationObject_MissionSelection(ValidationData);
	SitRepMgr = class'X2SitRepTemplateManager'.static.GetSitRepTemplateManager();

	if (GetPlotDefinitionForMapname(CardLabel, PlotDef))
	{
		foreach MissionSelectionData.RequiredPlotObjectiveTags(RequiredPlotObjective)
		{
			if (PlotDef.ObjectiveTags.Find(RequiredPlotObjective) != INDEX_NONE)
			{
				if (PlotDef.ExcludeFromStrategy)
				{
					continue;
				}

				foreach MissionSelectionData.SitRepNames(SitRepName)
				{
					SitRep = SitRepMgr.FindSitRepTemplate(SitRepName);

					if (SitRep != none && SitRep.ExcludePlotTypes.Find(PlotDef.strType) != INDEX_NONE)
					{
						return false;
					}
				}

				return true;
			}
		}
	}

	return false;
}

//DIO - room based gameplay set up
/// <summary>
/// Searches for room volumes, makes a list, and then sets the room clearing schedule into the battle data
/// </summary>
native function FinalizeRoomClearingOrder();

//====================================================

native final function bool IsStreamingComplete();

function DebugSoldierSpawns()
{
	local XGBattle Battle;
	local array<XComFalconVolume> FalconVolumes;
	local XComFalconVolume FalconVolume;
	local XComGroupSpawn GroupSpawn;
	local string GroupSpawnDebugText;
	local int MinimumSpawnDistance;
	local int IdealSpawnDistance;
	local Color TextColor;
	local float SoldierSpawnScore;
	local float SpawnScore;
	local bool IsOutsideFalconVolumes;
	local MissionSchedule ActiveSchedule;
	local XComGameState_BattleData LocalBattleStateData;
	local int SchMinSpawnDistance, SchIdealSpawnDistance;
	local X2SitRepEffect_ModifyXComSpawn SitRepEffect;

	Battle = `BATTLE;

	if(SoldierSpawn != none)
	{
		SoldierSpawnScore = SoldierSpawn.Score;
	}

	// collect the falcon volumes on the map and visualize them
	foreach Battle.AllActors(class'XComFalconVolume', FalconVolume)
	{
		FalconVolumes.AddItem(FalconVolume);
		Battle.DrawDebugBox(FalconVolume.BrushComponent.Bounds.Origin, FalconVolume.BrushComponent.Bounds.BoxExtent, 255, 255, 255, true);
	}

	// add debug strings above each of the group spawns with info about their scoring
	foreach Battle.AllActors(class'XComGroupSpawn', GroupSpawn)
	{
		if(GroupSpawn == SoldierSpawn)
		{
			GroupSpawnDebugText = "SelectedSpawn";
		}
		else
		{
			GroupSpawnDebugText = "Spawn";
		}

		if(!GroupSpawn.HasValidFloorLocations())
		{
			GroupSpawnDebugText $= ", Not enough valid floor locations";
		}

		// check for being outside of falcon volume spawn limiters
		IsOutsideFalconVolumes = true;
		foreach FalconVolumes(FalconVolume)
		{
			if(FalconVolume.ContainsPoint(GroupSpawn.Location))
			{
				IsOutsideFalconVolumes = false;
				break;
			}
		}

		if(IsOutsideFalconVolumes)
		{
			GroupSpawnDebugText $= ", Outside Falcon Volumes";
		}

		SpawnScore = GroupSpawn.Score;
		GroupSpawnDebugText $= ", Score: " $ string(SpawnScore);

		// determine the text color
		if(SoldierSpawn == GroupSpawn) // this is the selected soldier spawn
		{
			TextColor.R = 255;
			TextColor.G = 255;
			TextColor.B = 255;
			TextColor.A = 255;
		}
		else if(IsOutsideFalconVolumes || SoldierSpawnScore != SpawnScore)
		{
			TextColor.R = 255;
			TextColor.G = 128;
			TextColor.B = 128;
			TextColor.A = 255;
		}
		else // this could have been a soldier spawn, but was not selected
		{
			TextColor.R = 128;
			TextColor.G = 255;
			TextColor.B = 128;
			TextColor.A = 255;
		}

		Battle.DrawDebugString(vect(0, 0, 64), GroupSpawnDebugText, GroupSpawn, TextColor);
		Battle.DrawDebugBox(GroupSpawn.StaticMesh.Bounds.Origin, GroupSpawn.StaticMesh.Bounds.BoxExtent, TextColor.R, TextColor.G, TextColor.B, true);
	}

	// add discs to show the minimum and maximum spawn distances from the objective parcel
	TacticalMissionManager.GetActiveMissionSchedule(ActiveSchedule);

	SchMinSpawnDistance = ActiveSchedule.MinXComSpawnDistance;
	SchIdealSpawnDistance = ActiveSchedule.IdealXComSpawnDistance;

	LocalBattleStateData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (LocalBattleStateData != none)
	{
		foreach class'X2SitreptemplateManager'.static.IterateEffects(class'X2SitRepEffect_ModifyXComSpawn', SitRepEffect, LocalBattleStateData.ActiveSitReps)
		{
			SitRepEffect.ModifyLocations( SchIdealSpawnDistance, SchMinSpawnDistance );
		}
	}

	MinimumSpawnDistance = SchMinSpawnDistance * class'XComWorldData'.const.WORLD_StepSize;
	Battle.DrawDebugCylinder(BattleDataState.MapData.ObjectiveLocation, BattleDataState.MapData.ObjectiveLocation + vect(0, 0, 256), MinimumSpawnDistance, 32, 255, 128, 128, true);

	IdealSpawnDistance = SchIdealSpawnDistance * class'XComWorldData'.const.WORLD_StepSize;
	Battle.DrawDebugCylinder(BattleDataState.MapData.ObjectiveLocation, BattleDataState.MapData.ObjectiveLocation + vect(0, 0, 256), IdealSpawnDistance, 32, 128, 128, 256, true);
}

// START HELIOS Issue #39
// Allow mods to inject information into the Parcels or Plots
// Mostly this is basic information such as Markup Maps
// Adds new MarkupMaps to the Plot array
function bool PlotData_AddMarkupMaps(string PlotName, array<MissionBreachMarkupDefinition> MarkupMaps)
{
	local int 							Index;
	local MissionBreachMarkupDefinition	MarkupDef;

	Index = arrPlots.Find('MapName', PlotName);

	if (Index == INDEX_NONE)
		return false;

	foreach MarkupMaps(MarkupDef)
	{	
		// Append to the end of the Objective Tag, they need to be in alignment
		arrPlots[Index].ObjectiveTags.AddItem(MarkupDef.ObjectiveTag);
		arrPlots[Index].arrMarkUpMaps.AddItem(MarkupDef);
		return true;
	}

	return false;
}

function bool ParcelData_AddMarkupMaps(string PlotName, array<MissionBreachMarkupDefinition> MarkupMaps)
{
	local int 							Index;
	local MissionBreachMarkupDefinition	MarkupDef;

	Index = arrAllParcelDefinitions.Find('MapName', PlotName);

	if (Index == INDEX_NONE)
		return false;

	foreach MarkupMaps(MarkupDef)
	{
		// Append to the end of the Objective Tag, they need to be in alignment
		arrAllParcelDefinitions[Index].ObjectiveTags.AddItem(MarkupDef.ObjectiveTag);
		arrAllParcelDefinitions[Index].arrMarkUpMaps.AddItem(MarkupDef);
		return true;
	}

	return false;
}

// Removes the MarkupMapName associated with the ObjectiveName, but only the first instance
function bool PlotData_RemoveMarkupMaps(string PlotName, string ObjectiveName)
{
	local int 							Index, ObjectiveIdx;
	local MissionBreachMarkupDefinition	MarkupDef;

	Index = arrPlots.Find('MapName', PlotName);

	if (Index == INDEX_NONE)
		return false;

	ObjectiveIdx = arrPlots[Index].arrMarkUpMaps.Find('ObjectiveTag', ObjectiveName);

	if (ObjectiveIdx != INDEX_NONE)
	{
		arrPlots[Index].ObjectiveTags.Remove(ObjectiveIdx, 1);
		arrPlots[Index].arrMarkUpMaps.Remove(ObjectiveIdx, 1);
		return true;
	}

	return false;
}

// Removes the MarkupMapName associated with the ObjectiveName, but only the first instance
function bool ParcelData_RemoveMarkupMaps(string PlotName, string ObjectiveName)
{
	local int 							Index, ObjectiveIdx;
	local MissionBreachMarkupDefinition	MarkupDef;

	Index = arrPlots.Find('MapName', PlotName);

	if (Index == INDEX_NONE)
		return false;

	ObjectiveIdx = arrAllParcelDefinitions[Index].arrMarkUpMaps.Find('ObjectiveTag', ObjectiveName);

	if (ObjectiveIdx != INDEX_NONE)
	{
		arrAllParcelDefinitions[Index].ObjectiveTags.Remove(ObjectiveIdx, 1);
		arrAllParcelDefinitions[Index].arrMarkUpMaps.Remove(ObjectiveIdx, 1);
		return true;
	}

	return false;
}
// END HELIOS Issue #39

defaultproperties
{
	bBlockingLoadParcels = true
	bGeneratingMap=false
	bFinishedGeneratingMap=false
}
