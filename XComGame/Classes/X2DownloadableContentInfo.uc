//---------------------------------------------------------------------------------------
//  FILE:    X2DownloadableContentInfo.uc
//  AUTHOR:  Ryan McFall
//           
//	Mods and DLC derive from this class to define their behavior with respect to 
//  certain in-game activities like loading a saved game. Should the DLC be installed
//  to a campaign that was already started?
//
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo extends Object	
	Config(Game)
	native(Core);

//Backwards compatibility for mods
enum EUIAction
{
	eUIAction_Accept,   // User initiated
	eUIAction_Cancel,   // User initiated
	eUIAction_Closed    // Automatically closed by system
};

var config string DLCIdentifier; //The directory name that the DLC resides in
var config bool bHasOptionalNarrativeContent; // Does this DLC have optional narrative content, generates a checkbox in pre-campaign menu
var config array<string> AdditionalDLCResources;    // Resource paths for objects the game will load at startup and be synchronously accessible at runtime

var localized string PartContentLabel; // Label for use in the game play options menu allowing users to decide how this content pack is applied to new soldiers
var localized string PartContentSummary; // Tooltip for the part content slider

var localized string NarrativeContentLabel; // Label next to the checkbox in pre-campaign menu
var localized string NarrativeContentSummary; // Longer description of narrative content for pre-campaign menu

var localized string EnableContentLabel;
var localized string EnableContentSummary;
var localized string EnableContentAcceptLabel;
var localized string EnableContentCancelLabel;

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the 
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{

}

/// <summary>
/// This method is run when the player loads a saved game directly into Strategy while this DLC is installed
/// </summary>
static event OnLoadedSavedGameToStrategy()
{

}

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed. When a new campaign is started the initial state of the world
/// is contained in a strategy start state. Never add additional history frames inside of InstallNewCampaign, add new state objects to the start state
/// or directly modify start state objects
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{

}

/// <summary>
/// Called just before the player launches into a tactical a mission while this DLC / Mod is installed.
/// Allows dlcs/mods to modify the start state before launching into the mission
/// </summary>
static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{

}

/// <summary>
/// Called when the player completes a mission while this DLC / Mod is installed.
/// </summary>
static event OnPostMission()
{

}

/// <summary>
/// Called when the player is doing a direct tactical->tactical mission transfer. Allows mods to modify the
/// start state of the new transfer mission if needed
/// </summary>
static event ModifyTacticalTransferStartState(XComGameState TransferStartState)
{

}

/// <summary>
/// Called after the player exits the post-mission sequence while this DLC / Mod is installed.
/// </summary>
static event OnExitPostMissionSequence()
{

}

/// <summary>
/// Called after the Templates have been created (but before they are validated) while this DLC / Mod is installed.
/// </summary>
static event OnPostTemplatesCreated()
{

}

/// <summary>
/// Called when the difficulty changes and this DLC is active
/// </summary>
static event OnDifficultyChanged()
{

}

/// <summary>
/// Called by the Geoscape tick
/// </summary>
static event UpdateDLC()
{

}

/// <summary>
/// Called after HeadquartersAlien builds a Facility
/// </summary>
static event OnPostAlienFacilityCreated(XComGameState NewGameState, StateObjectReference MissionRef)
{

}

/// <summary>
/// Called after a new Alien Facility's doom generation display is completed
/// </summary>
static event OnPostFacilityDoomVisualization()
{

}

/// <summary>
/// Called when viewing mission blades with the Shadow Chamber panel, used primarily to modify tactical tags for spawning
/// Returns true when the mission's spawning info needs to be updated
/// </summary>
static function bool UpdateShadowChamberMissionInfo(StateObjectReference MissionRef)
{
	return false;
}

/// <summary>
/// A dialogue popup used for players to confirm or deny whether new gameplay content should be installed for this DLC / Mod.
/// </summary>
static function EnableDLCContentPopup()
{
	local TDialogueBoxData kDialogData;

	kDialogData.eType = eDialog_Normal;
	kDialogData.strTitle = default.EnableContentLabel;
	kDialogData.strText = default.EnableContentSummary;
	kDialogData.strAccept = default.EnableContentAcceptLabel;
	kDialogData.strCancel = default.EnableContentCancelLabel;

	kDialogData.fnCallback = EnableDLCContentPopupCallback_Ex;
	`HQPRES.UIRaiseDialog(kDialogData);
}

simulated function EnableDLCContentPopupCallback(eUIAction eAction)
{
}

simulated function EnableDLCContentPopupCallback_Ex(Name eAction)
{	
	switch (eAction)
	{
	case 'eUIAction_Accept':
		EnableDLCContentPopupCallback(eUIAction_Accept);
		break;
	case 'eUIAction_Cancel':
		EnableDLCContentPopupCallback(eUIAction_Cancel);
		break;
	case 'eUIAction_Closed':
		EnableDLCContentPopupCallback(eUIAction_Closed);
		break;
	}
}

/// <summary>
/// Called when viewing mission blades, used primarily to modify tactical tags for spawning
/// Returns true when the mission's spawning info needs to be updated
/// </summary>
static function bool ShouldUpdateMissionSpawningInfo(StateObjectReference MissionRef)
{
	return false;
}

/// <summary>
/// Called when viewing mission blades, used primarily to modify tactical tags for spawning
/// Returns true when the mission's spawning info needs to be updated
/// </summary>
static function bool UpdateMissionSpawningInfo(StateObjectReference MissionRef)
{
	return false;
}

/// <summary>
/// Called when viewing mission blades, used to add any additional text to the mission description
/// </summary>
static function string GetAdditionalMissionDesc(StateObjectReference MissionRef)
{
	return "";
}

/// <summary>
/// Called from X2AbilityTag:ExpandHandler after processing the base game tags. Return true (and fill OutString correctly)
/// to indicate the tag has been expanded properly and no further processing is needed.
/// </summary>
static function bool AbilityTagExpandHandler(string InString, out string OutString)
{
	return false;
}

/// <summary>
/// Called from XComGameState_Unit:GatherUnitAbilitiesForInit after the game has built what it believes is the full list of
/// abilities for the unit based on character, class, equipment, et cetera. You can add or remove abilities in SetupData.
/// </summary>
static function FinalizeUnitAbilitiesForInit(XComGameState_Unit UnitState, out array<AbilitySetupData> SetupData, optional XComGameState StartState, optional XComGameState_Player PlayerState, optional bool bMultiplayerDisplay)
{

}

/// <summary>
/// Calls DLC specific popup handlers to route messages to correct display functions
/// </summary>
static function bool DisplayQueuedDynamicPopup(DynamicPropertySet PropertySet)
{

}


// -------------------------------------------------------------
// ------------ Chimera Squad Highlander  Additions ------------
// -------------------------------------------------------------

/// Start Issue #7 (WOTC CHL #245)
/// Called from XGWeapon:Init.
/// This function gets called when the weapon archetype is initialized.
static function WeaponInitialized(XGWeapon WeaponArchetype, XComWeapon Weapon, optional XComGameState_Item ItemState=none)
{}

/// (WOTC CHL #246)
/// Called from XGWeapon:UpdateWeaponMaterial.
/// This function gets called when the weapon material is updated.
static function UpdateWeaponMaterial(XGWeapon WeaponArchetype, MeshComponent MeshComp, MaterialInstanceConstant MIC)
{}
/// End Issue #7


/// Start Issue #6 (WOTC CHL #21)
/// <summary>
/// Called from XComUnitPawn.DLCAppendSockets
/// Allows DLC/Mods to append sockets to units
/// </summary>
static function string DLCAppendSockets(XComUnitPawn Pawn)
{
	return "";
}
/// End Issue #6

/// Start Issue #5 (WOTC CHL #24)
/// <summary>
/// Called from XComUnitPawn.UpdateAnimations
/// CustomAnimSets will be added to the pawns animsets
/// </summary>
static function UpdateAnimations(out array<AnimSet> CustomAnimSets, XComGameState_Unit UnitState, XComUnitPawn Pawn)
{

}
/// End Issue #5 (WOTC #24)

// -------------------------------------------------------------
// ---------------- HELIOS Highlander Additions ----------------
// -------------------------------------------------------------

/// <summary>
/// Called from XComGameInfo::SetGameType
/// lets mods override the game info class for a given map
/// Credit goes to robojumper's End of the Cycle mod
/// </summary>
static function OverrideGameInfoClass(string MapName, string Options, string Portal, out class<GameInfo> GameInfoClass)
{

}

/// <summary>
/// WOTC CHL ADDITION (Issue #157)
/// Called from XComGameState_Missionsite:SetMissionData
/// Lets mods adjust the MissionData post creation instead of during the Sitrep phase (Sitrep functionality is deprecated in Dio). 
/// Advice: Check for present Strategy game if you dont want this to affect TQL/Multiplayer/Main Menu 
/// Example: If (`HQGAME  != none && `HQPC != None && `STRATPRES != none) ...
/// </summary>
static function PostMissionCreation(out GeneratedMissionData GeneratedMission, optional XComGameState_BaseObject SourceObject)
{
	
}

/// <summary>
/// HELIOS ADDITION
/// Called from X2TacticalGameRuleset::NextSessionCommand()
/// Returns true if OutSessionCommand was resolved. Mods must manually use this to switch out session commands since it's not stored anywhere.
/// </summary>
static function bool RetrieveStrategySessionCommand(out string OutSessionCommand)
{
	return false;
}

/// <summary>
/// HELIOS ADDITION
/// Called from SeqAct_EndBattle::Activated()
/// Returns true if EndBattle was resolved within this function. Return false to process normal EndBattle logic within SeqAct_EndBattle.uc.
///	We exploit the fact that a specific context, `XComGameStateContext_TacticalGameRule.uc`, containing a enumerated type, 
///	`eGameRule_TacticalGameEnd`, is needed to end the tactical battle. As long as that context is not submitted, the executing state 'TurnRounds_Action' in `X2TacticalGameRuleset.uc` continues the tactical battle as if EndBattle() was never called.
///	Check out X2TacticalGameRuleset::EndBattle() for more information on how the EndBattle function works.
/// </summary>
static function bool OnMissionEndBattle(XGPlayer VictoriousPlayer, 
										UICombatLoseType UILoseType, 
										bool GenerateReplaySave)
{
	return false;
}

/// <summary>
/// Begin HELIOS Issue #37 / WOTC CHL ADDITION (Issue #419)
/// Called from X2AbilityTag.ExpandHandler
/// Expands vanilla AbilityTagExpandHandler to allow reflection
/// </summary>
static function bool AbilityTagExpandHandler_CH(string InString, out string OutString, Object ParseObj, Object StrategyParseOb, XComGameState GameState)
{
	return false;
}
/// End HELIOS Issue #37