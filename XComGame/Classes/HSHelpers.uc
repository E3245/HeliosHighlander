//
// Mirros purpose of CHHelpers in X2WOTCCommunityHighlander
// https://github.com/X2CommunityCore/X2WOTCCommunityHighlander/blob/56d19fe92ebf073fbba704a1d5bd6e4721f2dbab/X2WOTCCommunityHighlander/Src/XComGame/Classes/CHHelpers.uc
//
class HSHelpers extends Object config(Game);

// Start Issue WOTC CHL #123
// List of AbilityTemplateNames that have associated XComPerkContent
var config array<name> AbilityTemplatePerksToLoad;
// End Issue WOTC CHL #123

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