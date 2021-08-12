//---------------------------------------------------------------------------------------
//  FILE:    	HSTacticalVisualizationTemplate
//  AUTHOR:  	E3245 -- HELIOS Highlander Team
//  PURPOSE: 	Immutable data that modifies visualizers in specific areas where it's
//				difficult to get to (e.g. XComGameStateContext_TacticalGameRule.uc)		
//           
//---------------------------------------------------------------------------------------

class HSTacticalVisualizationTemplate extends X2TacticalElementTemplate;

// Begin HELIOS Issue #52
var localized string    DialogBoxPopup_Title;
var localized string    DialogBoxPopup_Desc;
var string              MissionType;

// Add priority so that other mods that insert their own templates can order themselves to trigger before/after
var int                 Priority;

var delegate<BuildVisualization_BeginBreach> PreBuildVisualizationBeginBreach;
var delegate<BuildVisualization_BeginBreach> PostBuildVisualizationBeginBreach;
var delegate<BuildVisualization_BeginBreach> BuildVisualizationRoomCleared;
var delegate<BuildVisualization_BeginBreach> BuildVisualizationBreachEnd;
// End HELIOS Issue #52

// Begin HELIOS Issue #52
delegate EHLDInterruptReturn BuildVisualization_BeginBreach(XComGameStateContext Context, XComGameState_BattleData BattleData, out VisualizationActionMetadata ActionMetadata);
// End HELIOS Issue #52

defaultproperties
{
    Priority = 50
}