//---------------------------------------------------------------------------------------
//  FILE:    	UIMetaContentScreen
//  AUTHOR:  	David McDonough  --  2/14/2020
//  PURPOSE: 	Show information on game content not yet experienced across any playthrough.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2020 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIMetaContentScreen extends UIScreen;

var UIDIOHUD	DioHUD;
var UIButton	ContinueButton;

var localized string m_ScreenTitle;
var localized string m_ScreenSubtitle;
var localized string m_SubheaderAgents;
var localized string m_SubheaderAgentsComplete;
var localized string m_SubheaderAgentsCompleteDesc;
var localized string m_SubheaderFactions;
var localized string m_SubheaderWeapons;
var localized string m_SubheaderWeaponsComplete;
var localized string m_SubheaderWeaponsCompleteDesc;

var private transient string m_CachedMouseClickSound;

const NUM_EPIC_WEAPON_ITEMS = 8;

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
	DioHUD.UpdateResources(self);

	if (`ISCONTROLLERACTIVE)
	{
		ContinueButton = Spawn(class'UIButton', self).InitButton('MetaContentContinueButton', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_A_X, 20, 20, 0) @ class'UIUtilities_Text'.default.m_strGenericContinue, OnContinue);
	}
	else
	{
		ContinueButton = Spawn(class'UIButton', self).InitButton('MetaContentContinueButton', class'UIUtilities_Text'.default.m_strGenericContinue, OnContinue);
	}
	ContinueButton.Hide();
	ContinueButton.SetGood(true);
	ContinueButton.bShouldPlayGenericUIAudioEvents = false;

	m_CachedMouseClickSound = m_MouseClickSound;
	m_MouseClickSound = "";

	UpdateNavHelp();
	UpdateData();
}

simulated function UpdateData()
{
	local X2SoldierClassTemplateManager CharacterTemplateManager;
	local X2StrategyElementTemplateManager StratMgr;
	local X2ItemTemplateManager ItemTemplateManager;
	local X2DataTemplate DataTemplate;
	local X2WeaponTemplate WeaponTemplate;
	local array<X2WeaponTemplate> UnseenWeaponTemplates;
	local X2DioInvestigationTemplate InvestigationTemplate;
	local XComOnlineProfileSettings ProfileSettings;
	//local ConfigurableSoldier SoldierConfig;
	local X2SoldierClassTemplate CharacterTemplate;
	//local array<name> SoldierIDs;
	local array<X2SoldierClassTemplate> SoldierTemplates, UnseenSoldierIDs;
	local float Completion, CompletedOps;
	local string CompletionPctStr;
	local int i, k;


	// Header / Subheader

	AS_UpdateHeader(m_ScreenTitle, m_ScreenSubtitle, class'UIUtilities_Image'.const.MetaContentIcon);

	// Agents

	ProfileSettings = `XPROFILESETTINGS;
	CharacterTemplateManager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();

	SoldierTemplates = CharacterTemplateManager.GetAllSoldierClassTemplates();
	//class'UITacticalQuickLaunch_MapData'.static.GetSquadMemberNames(class'DioStrategyAI'.default.FullCastSquadName, SoldierIDs);
	for (i = 0; i < SoldierTemplates.Length; ++i)
	{
		if (ProfileSettings.HasUsedAgent(SoldierTemplates[i].DataName) || SoldierTemplates[i].ScarTemplates.Length == 0)
		{
			continue;
		}

		UnseenSoldierIDs.AddItem(SoldierTemplates[i]);
	}

	if (UnseenSoldierIDs.Length > 0)
	{
		AS_UpdateSubheader(0, m_SubheaderAgents, "", class'UIUtilities_Image'.const.MetaContentIcon);
		
		for (i = 0; i < UnseenSoldierIDs.Length; ++i)
		{
			//class'UITacticalQuickLaunch_MapData'.static.GetConfigurableSoldierSpec(, SoldierConfig);
			CharacterTemplate = UnseenSoldierIDs[i];// CharacterTemplateManager.FindSoldierClassTemplate(SoldierConfig.SoldierClassTemplate);
			if (CharacterTemplate == none)
			{
				continue;
			}

			AS_UpdateAgent(i, CharacterTemplate.Nickname, CharacterTemplate.WorkerIconImage);
		}
	}
	else
	{
		i = 0;
		AS_UpdateSubheader(0, m_SubheaderAgentsComplete, m_SubheaderAgentsCompleteDesc, class'UIUtilities_Image'.const.MetaContentIcon);
	}

	for (i = i; i < 3; ++i)//blank out any extra unused slots
	{
		AS_UpdateAgent(i, "", "");
	}

	// Faction Completion

	AS_UpdateSubheader(1, m_SubheaderFactions, "", class'UIUtilities_Image'.const.MetaContentIcon);
	StratMgr = `STRAT_TEMPLATE_MGR;
	i = 0;
	foreach StratMgr.IterateTemplates(DataTemplate)
	{
		CompletedOps = 0;
		InvestigationTemplate = X2DioInvestigationTemplate(DataTemplate);
		if (InvestigationTemplate == none || !InvestigationTemplate.bMainCampaign)
		{
			continue;
		}

		for (k = 0; k < InvestigationTemplate.OperationTemplates.Length; ++k)
		{
			if (ProfileSettings.HasCompletedOperation(InvestigationTemplate.OperationTemplates[k]))
			{
				CompletedOps += 1.0;
			}
		}
		Completion = CompletedOps / float(InvestigationTemplate.OperationTemplates.Length);
		// Make into percentage
		Completion *= 100.0;
		CompletionPctStr = string(FFloor(Completion)) $ "%";
		AS_UpdateFaction(i, InvestigationTemplate.DisplayName, CompletionPctStr, InvestigationTemplate.InvestigationLogoPath, InvestigationTemplate.DisplayColor);
		i++;
	}

	// Unseen Epic Weapons
	
	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach ItemTemplateManager.IterateTemplates(DataTemplate)
	{
		WeaponTemplate = X2WeaponTemplate(DataTemplate);
		if (WeaponTemplate == none || !WeaponTemplate.bIsEpic)
		{
			continue;
		}

		if (!ProfileSettings.HasUsedEpicWeapon(WeaponTemplate.DataName))
		{
			UnseenWeaponTemplates.AddItem(WeaponTemplate);
		}
	}

	if (UnseenWeaponTemplates.Length > 0)
	{
		AS_UpdateSubheader(2, m_SubheaderWeapons, "", class'UIUtilities_Image'.const.MetaContentIcon);

		// Populate or hide epic weapon grid items
		for (i = 0; i < NUM_EPIC_WEAPON_ITEMS; ++i)
		{
			if (i < UnseenWeaponTemplates.Length)
			{
				AS_UpdateWeapon(i, UnseenWeaponTemplates[i].GetItemFriendlyName(), UnseenWeaponTemplates[i].strImage);
			}
			else
			{
				AS_UpdateWeapon(i, "", ""); // Hide in flash
			}
		}
	}
	else
	{
		AS_UpdateSubheader(2, m_SubheaderWeaponsComplete, m_SubheaderWeaponsCompleteDesc, class'UIUtilities_Image'.const.MetaContentIcon);
	}
}

//---------------------------------------------------------------------------------------
function UpdateNavHelp()
{
	DioHUD.NavHelp.ClearButtonHelp();
	DioHUD.NavHelp.AddBackButton(OnClose);
}

//---------------------------------------------------------------------------------------
//				FLASH HOOKS
//---------------------------------------------------------------------------------------
function AS_UpdateHeader(string Title, string Desc, string IconImage)
{
	MC.BeginFunctionOp("UpdateHeaderInfo");
	MC.QueueString(Title);
	MC.QueueString(IconImage);
	MC.QueueString(Desc);
	MC.EndOp();
}

function AS_UpdateSubheader(int Index, string Title, string Desc, string IconImage)
{
	MC.BeginFunctionOp("UpdateSubHeader");
	MC.QueueNumber(Index);
	MC.QueueString(Title);
	MC.QueueString(Desc);
	MC.QueueString(IconImage);
	MC.EndOp();
}

function AS_UpdateAgent(int Index, string AgentName, string IconImage)
{
	MC.BeginFunctionOp("UpdateAgent");
	MC.QueueNumber(Index);
	MC.QueueString(AgentName);
	MC.QueueString(IconImage);
	MC.EndOp();
}

function AS_UpdateFaction(int Index, string FactionName, string CompletedAmount, string IconImage, string FactionColor)
{
	MC.BeginFunctionOp("UpdateFaction");
	MC.QueueNumber(Index);
	MC.QueueString(FactionName);
	MC.QueueString(CompletedAmount);
	MC.QueueString(IconImage);
	MC.QueueString(FactionColor);
	MC.EndOp();
}

function AS_UpdateWeapon(int Index, string WeaponName, string IconImage)
{
	MC.BeginFunctionOp("UpdateWeapon");
	MC.QueueNumber(Index);
	MC.QueueString(WeaponName);
	MC.QueueString(IconImage);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
function OnContinue(UIButton Button)
{
	OnClose();
}

function OnClose()
{
	DioHUD.NavHelp.ClearButtonHelp();
	CloseScreen();
}


//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bInputConsumed;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		m_MouseClickSound = m_CachedMouseClickSound;
		PlayMouseClickSound();
		m_MouseClickSound = "";
		OnClose();
		bInputConsumed = true;
		break;
	default:
		break;
	}

	if (!bInputConsumed)
	{
		return Super.OnUnrealCommand(cmd, arg);
	}

	return bInputConsumed;
}

// ===========================================================================
//  DEFAULTS:
// ===========================================================================
defaultproperties
{
	Package = "/ package/gfxMetaContentScreen/MetaContentScreen";
	MCName = "theScreen";
}