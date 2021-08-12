// Visualization Template for Helios
// This allows mods to preform their own visualization on certain hardcoded or difficult to edit without having to go through a lot of hoops visualizations
class HSTacticalVisualizationTemplate extends X2TacticalElementTemplate;

var localized string    DialogBoxPopup_Title;
var localized string    DialogBoxPopup_Desc;
var string              MissionType;

// Add priority so that other mods that insert their own templates can order themselves to trigger before/after
var int                 Priority;

var delegate<BuildVisualization_BeginBreach> PreBuildVisualizationBeginBreach;
var delegate<BuildVisualization_BeginBreach> PostBuildVisualizationBeginBreach;
var delegate<BuildVisualization_BeginBreach> BuildVisualizationRoomCleared;
var delegate<BuildVisualization_BeginBreach> BuildVisualizationBreachEnd;

delegate EHLDInterruptReturn BuildVisualization_BeginBreach(XComGameStateContext Context, XComGameState_BattleData BattleData, out VisualizationActionMetadata ActionMetadata);

defaultproperties
{
    Priority = 50
}