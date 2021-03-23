//
// Mirros purpose of CHHelpers in X2WOTCCommunityHighlander
// https://github.com/X2CommunityCore/X2WOTCCommunityHighlander/blob/56d19fe92ebf073fbba704a1d5bd6e4721f2dbab/X2WOTCCommunityHighlander/Src/XComGame/Classes/CHHelpers.uc
//
class HSHelpers extends Object config(Game);

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