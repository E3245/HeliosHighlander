//---------------------------------------------------------------------------------------
//  FILE:    	UITutorialArchive
//  AUTHOR:  	Brit Steiner 2/21/2020
//  PURPOSE: 	Review tutorial popup infos
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2020 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UITutorialArchive extends UIScreen implements(UIDIOIconSwap);

struct UITutorialArchivePOD
{
	var name DataName;
	var string Title;
	var string Body;
	var string Image;
};

var UIDIOHUD							DioHUD;
var UIList								OptionsList;
var array<name>							RawDataOptions;
var array<UITabIconButton>				Tabs;
var int									SelectedTab;
var int									iSelectedOption;

var array<UITutorialArchivePOD>		m_TacticalTutorialData;
var array<UITutorialArchivePOD>		m_StrategyTutorialData;

var localized string ScreenTitle;
var localized string CategoryLabel_Strategy;
var localized string CategoryLabel_Tactical;
var localized string TooltipDescOfArchives;

// New tutorial entries
var localized string strResourcesTitle;
var localized string strResourcesBody;
var localized string strVigilanceTitle;
var localized string strVigilanceBody;
var localized string strQuarantineTitle;
var localized string strQuarantineBody;
var localized string strDragnetTitle;
var localized string strDragnetBody;
var localized string strMajorCrimesTitle;
var localized string strMajorCrimesBody;
var localized string strUnlockingSlotsTitle;
var localized string strUnlockingSlotsBody;
var localized string strMentalEffectsTitle;
var localized string strMentalEffectsBody;
var localized string strEnvEffectsTitle;
var localized string strEnvEffectsBody;
var localized string strMiscEffectsTitle;
var localized string strMiscEffectsBody;
var localized string strIncapEffectsTitle;
var localized string strIncapEffectsBody;

//---------------------------------------------------------------------------------------


//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	
	OptionsList = Spawn(class'UIList', self).InitList('TutorialArchiveListMC', 88, 363, 489, 603); //forcing location and size, to try to combat weird squishing items. 
	OptionsList.bLoopSelection = true;
	OptionsList.bStickyClickyHighlight = true;
	OptionsList.ItemPadding = 20;
	OptionsList.OnSelectionChanged = OnSelectionChanged;
	OptionsList.OnItemClicked = OnItemClicked;
	OptionsList.bSelectFirstAvailable = true;
	OptionsList.OnSetSelectedIndex = OnSelectedIndexChanged;
	OptionsList.SetSelectedNavigation();

	PopulateTacticalTutorialData();
	PopulateStrategyTutorialData();

	BuildTabs();
	UpdateNavHelp();
	DisplayOptions();

	MC.FunctionString("SetCategoryLabel", CategoryLabel_Strategy);
	SelectTabByIndex(0);
}

//---------------------------------------------------------------------------------------
simulated function BuildOption(name DataName, name Category, bool bCurrentSelection)
{
	local UITutorialArchiveListItem ListItem;

	ListItem = GetListItemByData(DataName);
	ListItem.SetData(DataName, Category);
}

simulated function UITutorialArchiveListItem GetListItemByData(name DataName)
{
	local UITutorialArchiveListItem ListItem, NewListItem;

	ListItem = UITutorialArchiveListItem(OptionsList.GetItemMCNamed(name("ListItem_" $ DataName)));
	if( ListItem != none ) return ListItem;

	NewListItem = UITutorialArchiveListItem(OptionsList.CreateItem(class'UITutorialArchiveListItem'));
	NewListItem.InitTutorialArchiveListItem(name("ListItem_" $ DataName));
	NewListItem.OnMouseEventDelegate = OptionsList.OnChildMouseEvent;

	return NewListItem;
}

//---------------------------------------------------------------------------------------
simulated function array<name> RefreshDataOptions(optional name UICategory)
{
	local array<name> ResultData;
	local int i;

	if (UICategory == 'Strategy')
	{
		for (i = 0; i < m_StrategyTutorialData.Length; ++i)
		{
			ResultData.AddItem(m_StrategyTutorialData[i].DataName);
		}
	}
	else if (UICategory == 'Tactical')
	{
		for (i = 0; i < m_TacticalTutorialData.Length; ++i)
		{
			ResultData.AddItem(m_TacticalTutorialData[i].DataName);
		}
	}

	return ResultData;
}

//---------------------------------------------------------------------------------------
simulated function DisplayOptions()
{
	RawDataOptions = RefreshDataOptions();
	Refresh();
}

//---------------------------------------------------------------------------------------
simulated function Refresh()
{
	local name OptionName, CurrentTopicName, CurrentCategory;

	DioHUD.UpdateResources(self);

	AS_SetScreenInfo(ScreenTitle);

	//OptionsList.ClearItems(); //DO NOT NUKE LIST. We're refreshing current ones in the build option sequence. 
	CurrentCategory = GetTabCategory(SelectedTab);
	CurrentTopicName = UITutorialArchiveListItem(OptionsList.GetSelectedItem()).DataName;

	foreach RawDataOptions(OptionName)
	{
		BuildOption(OptionName, CurrentCategory, CurrentTopicName == OptionName);
	}

	RefreshDescription();
}


//---------------------------------------------------------------------------------------
function RefreshDescription()
{
	local name CurrentCategory;
	local int Idx;

	// Clear out the subheader infos 
	MC.FunctionVoid("ClearInfo");

	if (OptionsList.SelectedIndex < 0)
	{
		return;
	}

	UITutorialArchiveListItem(OptionsList.GetSelectedItem()).RefreshSelectionState(false);
	iSelectedOption = OptionsList.SelectedIndex;
	UITutorialArchiveListItem(OptionsList.GetSelectedItem()).RefreshSelectionState(true);
	
	CurrentCategory = GetTabCategory(SelectedTab);
	if (CurrentCategory == 'Strategy')
	{
		Idx = m_StrategyTutorialData.Find('DataName', UITutorialArchiveListItem(OptionsList.GetSelectedItem()).DataName);
		if (Idx != INDEX_NONE)
		{
			AS_UpdateInfoPanel(m_StrategyTutorialData[Idx].Title, m_StrategyTutorialData[Idx].Body, m_StrategyTutorialData[Idx].Image);
		}
		else
		{
			AS_UpdateInfoPanel("", "", "");
		}
	}
	else if (CurrentCategory == 'Tactical')
	{
		Idx = m_TacticalTutorialData.Find('DataName', UITutorialArchiveListItem(OptionsList.GetSelectedItem()).DataName);
		if (Idx != INDEX_NONE)
		{
			AS_UpdateInfoPanel(m_TacticalTutorialData[Idx].Title, m_TacticalTutorialData[Idx].Body, m_TacticalTutorialData[Idx].Image);
		}
		else
		{
			AS_UpdateInfoPanel("", "", "");
		}
	}
	else
	{
		AS_UpdateInfoPanel("", "", "");
	}
}

function AS_UpdateInfoPanel(string title, string body, string imagePath = "")
{
	MC.BeginFunctionOp("UpdateInfoPanel");
	MC.QueueString(title);
	MC.QueueString(body);
	MC.QueueString(imagePath);
	MC.EndOp();
}

function AS_SetScreenInfo(string title)
{
	MC.BeginFunctionOp("SetScreenInfo");
	MC.QueueString(title);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------

simulated function OnSelectedIndexChanged(UIList ContainerList, int ItemIndex)
{
	RefreshDescription();
}

function OnSelectionChanged(UIList ContainerList, int ItemIndex)
{
	if( `ISCONTROLLERACTIVE)
	{
		RefreshDescription();
	}
}

function OnItemClicked(UIList ContainerList, int ItemIndex)
{
	RefreshDescription();
}

//---------------------------------------------------------------------------------------
function UpdateNavHelp()
{
	DioHUD.NavHelp.ClearButtonHelp();
	DioHUD.NavHelp.AddBackButton(CloseScreen);

	if( `ISCONTROLLERACTIVE)
	{
		DioHUD.NavHelp.AddSelectNavHelp(); 
		DioHUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyScreenNavigation'.default.CategoryLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LTRT_L2R2);
	}
}

function BuildTabs()
{
	local UITabIconButton Tab;

	Tabs.AddItem(CreateTab(0, class'UIUtilities_Image'.const.CategoryIcon_TutorialStrategy, CategoryLabel_Strategy));
	Tabs.AddItem(CreateTab(1, class'UIUtilities_Image'.const.CategoryIcon_TutorialTactical, CategoryLabel_Tactical));

	// mmg_john.hawley (11/25/19) - Do not let dpad input navigate tabs.
	foreach Tabs(Tab)
	{
		Tab.DisableNavigation();
	}
}

function UITabIconButton CreateTab(int index, string iconPath, string Label)
{
	local UITabIconButton Tab;

	Tab = Spawn(class'UITabIconButton', self);
	Tab.InitButton(Name("IconTabMC_" $ index));
	Tab.SetIcon(iconPath);
	Tab.OnClickedDelegate = OnClickedTab;
	Tab.metadataString = Label;

	return Tab;
}

function NextTab()
{
	SelectTabByIndex((SelectedTab + 1) % Tabs.length);
}

function PreviousTab()
{
	SelectTabByIndex((SelectedTab + Tabs.length - 1) % Tabs.length);
}

function OnClickedTab(UIButton Button)
{
	// Wait to set SelectedTab in SelectTabByIndex so that changes can be detected
	SelectTabByIndex(int(GetRightMost(Button.MCName)));
}

function SelectTabByIndex(int newIndex)
{
	local UITabIconButton Tab;
	local int i;

	if( newIndex != SelectedTab )
	{
		PlayMouseClickSound();
	}

	SelectedTab = newIndex;

	RawDataOptions = RefreshDataOptions(GetTabCategory(SelectedTab));
	OptionsList.ClearItems();
	Refresh();

	for( i = 0; i < Tabs.length; i++ )
	{
		Tab = Tabs[i];
		Tab.SetSelected(SelectedTab == i);
	}

	MC.FunctionString("SetImage", "");
	MC.FunctionString("SetCategoryLabel", Tabs[SelectedTab].metadataString);
}

function name GetTabCategory(int Index)
{
	switch( Index )
	{
	case 0:	return 'Strategy';
	case 1:	return 'Tactical';
	}

	return 'Base';
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bInputConsumed;

	// Only pay attention to presses or repeats; ignoring other input types
	if( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	if( DioHUD.m_WorkerTray.bIsVisible )
	{
		return DioHUD.m_WorkerTray.OnUnrealCommand(cmd, arg);
	}

	switch( cmd )
	{
	case class'UIUtilities_Input'.const.FXS_MOUSE_5 :
	case class'UIUtilities_Input'.const.FXS_KEY_TAB :
		//case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER :
		NextTab();
		break;

	case class'UIUtilities_Input'.const.FXS_MOUSE_4 :
	case class'UIUtilities_Input'.const.FXS_KEY_LEFT_SHIFT :
		//case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER :
		PreviousTab();
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		bInputConsumed = true;
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		PlayMouseClickSound();
		CloseScreen();
		bInputConsumed = true;
		break;

	default:
		bInputConsumed = bInputConsumed || false;
		break;
	}

	if( !bInputConsumed )
	{
		return OptionsList.OnUnrealCommand(cmd, arg);
	}

	return bInputConsumed;
}


//---------------------------------------------------------------------------------------

function bool SimulateScreenInteraction()
{
	CloseScreen();
	return true;
}

// mmg_john.hawley (11/13/19) - Update NavHelp when player swaps input device
simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	Refresh();

	UpdateNavHelp();
}

// mmg_john.hawley (12/9/19) - Update NavHelp ++ 
function IconSwapPlus(bool IsMouse)
{
	if (`SCREENSTACK.IsTopScreen(self))
	{
		UpdateNavHelp();
	}
}

//---------------------------------------------------------------------------------------
//				TACTICAL TUTORIAL PREP
//---------------------------------------------------------------------------------------
// Since tactical tutorials are just disconnected, hard-coded strings, here's a brute-force
// function to add them

function PopulateTacticalTutorialData()
{
	local UITutorialArchivePOD TutData;
	local XComGameState_CampaignSettings CampaignSettings;

	CampaignSettings = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings', true));
	m_TacticalTutorialData.Length = 0;

	// Breach
	TutData.DataName = 'Tutorial_Breach';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Breach_Title1;
	TutData.Body = class'DioTacticalTutorial'.default.m_Tutorial_Breach_Body1;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Breach_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	// Turns & Moving
	TutData.DataName = 'Tutorial_Combat_Moving';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Combat_Moving_Title0;
	TutData.Body = class'DioTacticalTutorial'.default.m_Tutorial_Combat_Moving_Body0;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Combat_Moving_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	// Multiple Breaching
	TutData.DataName = 'Tutorial_Breach_Multiple';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Breach_Multiple_Title0;
	TutData.Body = class'DioTacticalTutorial'.default.m_Tutorial_Breach_Multiple_Body0;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Breach_Multiple_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	// Special Breach Points
	TutData.DataName = 'Tutorial_Breach_Equip';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Breach_Equip_Title0;
	TutData.Body = class'DioTacticalTutorial'.default.m_Tutorial_Breach_Equip_Body0;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Breach_Equip_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	// At Will Overview
	TutData.DataName = 'Tutorial_Combat_AtWillOverview';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Combat_AtWillOverview_Title0;
	TutData.Body = class'DioTacticalTutorial'.default.m_Tutorial_Combat_AtWillOverview_Body0;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Combat_AtWillOverview_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	// Bleeding Out
	TutData.DataName = 'Tutorial_Combat_Bleedout';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Combat_Bleedout_Title0;
	TutData.Body = class'DioTacticalTutorial'.default.m_Tutorial_Combat_Bleedout_Body0;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Combat_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	//Team Up
	TutData.DataName = 'Tutorial_Combat_TeamUp';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Combat_TeamUp_Title0;
	TutData.Body = class'DioTacticalTutorial'.default.m_Tutorial_Combat_TeamUp_Body0;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Combat_TeamUp_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	// Preparation
	TutData.DataName = 'Tutorial_Combat_Preparation';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Combat_Preparation_Title0;
	TutData.Body = class'DioTacticalTutorial'.default.m_Tutorial_Combat_Preparation_Body0;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Combat_Preparation_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	// Encounter End Heal
	TutData.DataName = 'Tutorial_Combat_EncounterEndUnitHeal';
	TutData.Title = class'DioTacticalTutorial'.default.m_Tutorial_Combat_EncounterEndUnitHeal_Title0;
	TutData.Body = CampaignSettings.bFullHealSquadPostEncounter ? class'DioTacticalTutorial'.default.m_Tutorial_Combat_EncounterEndUnitFullHeal_Body0 : class'DioTacticalTutorial'.default.m_Tutorial_Combat_EncounterEndUnitHeal_Body0;
	TutData.Image = class'DioTacticalTutorial'.const.Tutorial_Combat_EncounterEndHealUnit_Image0;
	m_TacticalTutorialData.AddItem(TutData);

	// Mental Status Effects
	TutData.DataName = 'Tutorial_MentalEffects';
	TutData.Title = strMentalEffectsTitle;
	TutData.Body = strMentalEffectsBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_status_mental";
	m_TacticalTutorialData.AddItem(TutData);

	// Environmental Status Effects
	TutData.DataName = 'Tutorial_EnvEffects';
	TutData.Title = strEnvEffectsTitle;
	TutData.Body = strEnvEffectsBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_status_environmental";
	m_TacticalTutorialData.AddItem(TutData);

	// Misc Status Effects
	TutData.DataName = 'Tutorial_MiscEffects';
	TutData.Title = strMiscEffectsTitle;
	TutData.Body = strMiscEffectsBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_status_misc";
	m_TacticalTutorialData.AddItem(TutData);

	// Incapacitating Status Effects
	TutData.DataName = 'Tutorial_IncapEffects';
	TutData.Title = strIncapEffectsTitle;
	TutData.Body = strIncapEffectsBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_status_incap";
	m_TacticalTutorialData.AddItem(TutData);

	m_TacticalTutorialData.sort(SortTutorialPod);
}

//---------------------------------------------------------------------------------------
//				STRATEGY TUTORIAL PREP
//---------------------------------------------------------------------------------------
// Make the strategy tutorials use the same data structure as the tactical ones even
// though they mostly have their own templates

function PopulateStrategyTutorialData()
{
	local X2StrategyElementTemplateManager StratMgr;
	local X2DataTemplate DataTemplate;
	local X2DioStrategyTutorialTemplate TutorialTemplate;
	local UITutorialArchivePOD TutData;

	m_StrategyTutorialData.Length = 0;

	StratMgr = `STRAT_TEMPLATE_MGR;
	foreach StratMgr.IterateTemplates(DataTemplate)
	{
		TutorialTemplate = X2DioStrategyTutorialTemplate(DataTemplate);
		if (TutorialTemplate == none || TutorialTemplate.bHideInArchive || TutorialTemplate.Type == "Blade" || TutorialTemplate.Header == "")
		{
			continue;
		}

		TutData.DataName = TutorialTemplate.DataName;
		TutData.Title = TutorialTemplate.GetArchiveTitle();
		TutData.Body = TutorialTemplate.GetArchiveBody();
		TutData.Image = TutorialTemplate.Image;
		m_StrategyTutorialData.AddItem(TutData);
	}

	// Resources
	TutData.DataName = 'Tutorial_Resources';
	TutData.Title = strResourcesTitle;
	TutData.Body = strResourcesBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_Currency_Credits";
	m_StrategyTutorialData.AddItem(TutData);

	// Vigilance
	TutData.DataName = 'Tutorial_Vigilance';
	TutData.Title = strVigilanceTitle;
	TutData.Body = strVigilanceBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_fieldTeamAbility_Vigilance";
	m_StrategyTutorialData.AddItem(TutData);

	// Quarantine
	TutData.DataName = 'Tutorial_Quarantine';
	TutData.Title = strQuarantineTitle;
	TutData.Body = strQuarantineBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_fieldTeamAbility_Quarantine";
	m_StrategyTutorialData.AddItem(TutData);

	// Dragnet
	TutData.DataName = 'Tutorial_Dragnet';
	TutData.Title = strDragnetTitle;
	TutData.Body = strDragnetBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_fieldTeamAbility_Dragnet";
	m_StrategyTutorialData.AddItem(TutData);

	// Major Crimes Task Force
	TutData.DataName = 'Tutorial_MajorCrimes';
	TutData.Title = strMajorCrimesTitle;
	TutData.Body = strMajorCrimesBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_fieldTeamAbility_MajorCrimes";
	m_StrategyTutorialData.AddItem(TutData);

	// Unlocking Agent Assignment Slots
	TutData.DataName = 'Tutorial_UnlockingSlots';
	TutData.Title = strUnlockingSlotsTitle;
	TutData.Body = strUnlockingSlotsBody;
	TutData.Image = "img:///UILibrary_Common.Tutorial_ExtraSlots";
	m_StrategyTutorialData.AddItem(TutData);

	m_StrategyTutorialData.sort(SortTutorialPod);
}

//---------------------------------------------------------------------------------------
function int SortTutorialPod(UITutorialArchivePOD A, UITutorialArchivePOD B)
{
	if (A.Title < B.Title)
	{
		return 1;
	}
	else if (A.Title > B.Title)
	{
		return -1;
	}

	return 0;
}

// ===========================================================================
//  DEFAULTS:
// ===========================================================================
defaultproperties
{
	Package = "/ package/gfxTutorialArchive/TutorialArchive";
MCName = "theScreen";

bHideOnLoseFocus = false;
bAnimateOnInit = true;
bProcessMouseEventsIfNotFocused = false;
}
