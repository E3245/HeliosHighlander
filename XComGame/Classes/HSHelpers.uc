//
// Mirros purpose of CHHelpers in X2WOTCCommunityHighlander
// https://github.com/X2CommunityCore/X2WOTCCommunityHighlander/blob/56d19fe92ebf073fbba704a1d5bd6e4721f2dbab/X2WOTCCommunityHighlander/Src/XComGame/Classes/CHHelpers.uc
//
class HSHelpers extends Object config(Game);

// GLOBAL DATA STRUCTURES AND VARS
// ------------------------------------------------------------------------------------------------

// Interruption returns that allow mods to stop subsequent processing of delegates if set
// Initially created for CoverMitigationCalculationCallbackFn but will be used for other delegates and templates from now on
enum EHLDInterruptReturn
{
	EHLD_NoInterrupt,	// Continue processing subsequent delegates
	EHLD_Interrupt,		// Stop processing subsequent delegates
};

// Start Issue WOTC CHL #123
// List of AbilityTemplateNames that have associated XComPerkContent
var config array<name> AbilityTemplatePerksToLoad;
// End Issue WOTC CHL #123

// ABILITY VARS
// ------------------------------------------------------------------------------------------------

// Begin HELIOS Issue #10
// Allow custom effects to mask units from the timeline
// Will search this array for the exact EffectName, case-sensitive
var config array<name> EffectsToExcludeFromTimeline;
// End HELIOS Issue #10

// Begin HELIOS Issue #50
// Add a method of changing the Cover Mitigation value via Delegates
struct CoverMitigationChanges
{
	var delegate<CoverMitigationCalculationCallbackFn> CoverMitigationFn;
	var int Priority;

	structdefaultproperties
	{
		Priority = 50;
	}
};

var privatewrite array<CoverMitigationChanges>	arrModifyCoverMitigationCalculations;
// End HELIOS Issue #50

// BREACH VARS
// ------------------------------------------------------------------------------------------------

// Begin HELIOS Issue #51
// Allow mods to insert custom Dark Event modifiers based on current tactical tags.
// Right now, High Response is the only dark event set up for this.
var config array<ConditionalBreachModifier> ModifiersAdditionalByDarkEvent;
// End HELIOS Issue #51

// MAP AND WORLD-RELATED VARS
// ------------------------------------------------------------------------------------------------

// BEGIN HELIOS Issue #39
// Mods that need to add new Markup Maps to existing maps should use this to avoid having to manage config files.
struct HeliosMarkupMapDefinitionData
{
	var string 									MapName;
	var array<MissionBreachMarkupDefinition> 	arrMarkUpMaps;
};

var config array<HeliosMarkupMapDefinitionData> AdditionalMarkupMaps;
// END HELIOS Issue #39

// Any new delegates should be initialized here
// Begin HELIOS Issue #50
delegate EHLDInterruptReturn CoverMitigationCalculationCallbackFn(XComGameState_Unit SourceUnit, XComGameState_Unit TargetUnit, X2AbilityTemplate AbilityTemplate, GameRulesCache_VisibilityInfo PickedVisInfo, out int CoverMitigation);
// End HELIOS Issue #50

// Start Issue WOTC CHL #123
simulated static function RebuildPerkContentCache() {
	local XComContentManager		Content;
	local name						AbilityTemplateName;

	Content = `CONTENT;
	Content.BuildPerkPackageCache();
	foreach default.AbilityTemplatePerksToLoad(AbilityTemplateName) {
		Content.CachePerkContent(AbilityTemplateName);
	}
}
// End Issue WOTC CHL #123

// Begin HELIOS Issue #16
// General function that searches for a specific tactical tag from the DioHQ state and returns true if exists, false otherwise.
function bool CheckDarkEventTags(name TagName)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;

	History = `XCOMHISTORY;
	DioHQ = XComGameState_HeadquartersDio(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio', true));

	if (TagName != '' && DioHQ.TacticalGameplayTags.Find(TagName) != INDEX_NONE)
	{
		return true;
	}

	return false;
}
// End HELIOS Issue #16

// Begin HELIOS Issue #39
// General function that searches for a specific tactical tag from the DioHQ state and returns true if exists, false otherwise.
static function GenerateMarkupMapCompatibility()
{
	local HeliosMarkupMapDefinitionData MarkupMapDef;
	local XComParcelManager				ParcelManager;

	ParcelManager = `PARCELMGR;

	foreach default.AdditionalMarkupMaps(MarkupMapDef)
	{
		// Discard any blank map names
		if (MarkupMapDef.MapName == "")
			continue;

		// Skip over any empty ObjectiveTags because it will cause alignment issues in the future
		if (MarkupMapDef.arrMarkUpMaps.Find('ObjectiveTag', "") != INDEX_NONE)
			continue;

		// This usually gets synced up together
		ParcelManager.PlotData_AddMarkupMaps(MarkupMapDef.MapName, 	MarkupMapDef.arrMarkUpMaps);
		ParcelManager.ParcelData_AddMarkupMaps(MarkupMapDef.MapName, 	MarkupMapDef.arrMarkUpMaps);
	}
}
// End HELIOS Issue #39

// Begin HELIOS Issue #50
// Introduced with this issue.
// Helper function to get this class default object
// Use with caution!
static function HSHelpers GetCDO()
{
	// This is hot code, so use an optimized function here
	return HSHelpers(FindObject("XComGame.Default__HSHelpers", class'HSHelpers'));
}

// If a mod wants to modify the cover mitigation post-calculation, then add the delegate here
// Delegates must exist in a default object *that's accessible in Tactical*, the best place would be in any X2DownloadableContentInfo extended class
// Even though the struct supports priority, we probably aren't going to use it a lot, yet.
simulated function Effect_AddCoverMitigationChange(delegate<CoverMitigationCalculationCallbackFn> NewCoverMitigationFn)
{
	local CoverMitigationChanges CoverChanges;
	local int i;

	// No blank delegates!
	if (NewCoverMitigationFn == none)
		return;

	CoverChanges.CoverMitigationFn 	= NewCoverMitigationFn;

	arrModifyCoverMitigationCalculations.AddItem(CoverChanges);
}

simulated function Effect_TriggerCheckCoverMitigationChanges(XComGameState_Unit SourceUnit, XComGameState_Unit TargetUnit, X2AbilityTemplate AbilityTemplate, GameRulesCache_VisibilityInfo PickedVisInfo, out int CoverMitigation)
{
	local CoverMitigationChanges CoverChanges;
	local delegate<CoverMitigationCalculationCallbackFn> CurrentCoverMitigationFn;

	foreach arrModifyCoverMitigationCalculations(CoverChanges)
	{
		CurrentCoverMitigationFn = CoverChanges.CoverMitigationFn;
		
		// Stop processing events if a delegate returns EHLD_Interrupt
		if ( CurrentCoverMitigationFn(SourceUnit, TargetUnit, AbilityTemplate, PickedVisInfo, CoverMitigation) == EHLD_Interrupt )
			break;
	}
}
// End HELIOS Issue #50