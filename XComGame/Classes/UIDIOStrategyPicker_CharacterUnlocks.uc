//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategyPicker_Character
//  AUTHOR:  	David McDonough  --  3/27/2019
//  PURPOSE: 	View options to unlock a new squad character. Occurs mid-campaign and adds
//				the choice to the squad as well as unlocking it at the meta level for
//				future campaigns.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOStrategyPicker_CharacterUnlocks extends UIScreen implements(UIDioAutotestInterface)
	config(GameCore);

var UIPanel SoldierListContainer;
var UIList m_SoldierList;
var int	   m_NumSoldiersToUnlock;
var bool   m_bNewCampaign;
var UIButton m_ContinueButton;
var UIButton m_ViewBiographyButton;
var X2SoldierClassTemplate ViewingInfoOnCharTemplate;

var UIDIOHUD m_HUD;

var array<name>	RawDataOptions;
var array<name> m_UnlockCharacters;

var config bool bDisplayAllCharacters;

var localized string ScreenTitle;
var localized string SoldierInfoHeader;
var localized string SquadPanelTitle;
var localized string ErrorNeedAdditionalUnit;
var localized string ConfirmSelection;

var private transient string MouseClickSoundCached; // Prevent mouse click on confirm

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	

	m_HUD.UpdateResources(self);

	SoldierListContainer = Spawn(class'UIPanel', self);
	SoldierListContainer.bAnimateOnInit = false;
	SoldierListContainer.InitPanel('leftMenu');
	// SoldierListContainer should play generic UI audio events

	m_SoldierList = Spawn(class'UIList', SoldierListContainer).InitList('theUnitList');
	m_SoldierList.SetSize(420, 875);
	//m_SoldierList.SetPosition(10, 110);
	m_SoldierList.OnSelectionChanged = OnSelectionChanged;
	m_SoldierList.bStickyHighlight = true;
	m_SoldierList.bAutosizeItems = true;
	m_SoldierList.bAnimateOnInit = false;
	m_SoldierList.bShouldPlayGenericUIAudioEvents = false;
	
	if (`ISCONTROLLERACTIVE)
	{
		m_ContinueButton = Spawn(class'UIButton', self).InitButton('rosterConfirmButton', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE, 24, 20, 0) @ ConfirmSelection, OnConfirm); // mmg_aaron.lee (11/24/19) - HACK the icon size since it's squeezed. 
		m_ContinueButton.SetTextAlign("center");
		m_ContinueButton.MoveToHighestDepth();
	}
	else
	{
		m_ContinueButton = Spawn(class'UIButton', self).InitButton('rosterConfirmButton', ConfirmSelection, OnConfirm);
	}
	m_ContinueButton.SetTextAlign("center");
	m_ContinueButton.SetGood(true);
	m_ContinueButton.bShouldPlayGenericUIAudioEvents = false;


	if(`ISCONTROLLERACTIVE)
	{
		m_ViewBiographyButton = Spawn(class'UIButton', self).InitButton('bioBtn', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LSCLICK_L3, 24, 20, 0) @ class'UIArmory_MainMenu'.default.m_strBiography, ViewBiography);
		m_ViewBiographyButton.SetTextAlign("center");
		m_ViewBiographyButton.MoveToHighestDepth();
	}
	else
	{
		m_ViewBiographyButton = Spawn(class'UIButton', self).InitButton('bioBtn', class'UIArmory_MainMenu'.default.m_strBiography, ViewBiography);
	}
	m_ViewBiographyButton.SetTextAlign("center");
	m_ViewBiographyButton.SetGood(false);
	m_ViewBiographyButton.bShouldPlayGenericUIAudioEvents = true;
	m_ViewBiographyButton.SetPosition(750, 510);
	m_ViewBiographyButton.SetWidth(525);
}

simulated function OnInit()
{	
	local X2SoldierClassTemplateManager CharacterTemplateManager;
	local X2SoldierClassTemplate CharacterTemplate;
	local ConfigurableSoldier SoldierConfig;
	local int Index;

	CharacterTemplateManager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();

	super.OnInit();

	MC.FunctionVoid("ShowLeftList");

	MC.FunctionString("setTitle", SoldierInfoHeader);

	if (RawDataOptions.Length > 0)
	{
		Index = class'UITacticalQuickLaunch_MapData'.static.GetConfigurableSoldierSpec(RawDataOptions[0], SoldierConfig);
		if (Index >= 0)
		{
			CharacterTemplate = CharacterTemplateManager.FindSoldierClassTemplate(SoldierConfig.SoldierClassTemplate);
		}
	}

	if (CharacterTemplate != none)
	{
		SetLargePanelData(CharacterTemplate);
	}

	UpdateNavHelp();
}

simulated function SetLargePanelData(X2SoldierClassTemplate CharacterTemplate)
{
	ViewingInfoOnCharTemplate = CharacterTemplate; 
	SetUnitData(CharacterTemplate);
	SetSoldierStats(CharacterTemplate);
	SetSoldierAbilities(CharacterTemplate);
}

simulated function SetUnitData(X2SoldierClassTemplate CharacterTemplate)
{
	MC.BeginFunctionOp("SetUnitData");
	MC.QueueString(CharacterTemplate.FirstName); //Soldier Name
	MC.QueueString(CharacterTemplate.IconImage); //Class Icon
	MC.QueueString(class'UIUtilities_Text'.static.ConvertStylingToFontFace(CharacterTemplate.ClassSummary $ "\n" $ CharacterTemplate.ClassBio $ "\n<i>" $ CharacterTemplate.ClassQuote $"</i>")); // Gameplay, Bio, Quote
	MC.EndOp();

	MC.FunctionString("SetLargeImage", CharacterTemplate.WorkerIconImage $"_LG");
}

function AS_SetRightListTitle(string strTitle, string strInfoMessage)
{
	MC.BeginFunctionOp("setRightListTitle");
	MC.QueueString(strTitle);
	MC.QueueString(strInfoMessage);
	MC.EndOp();
}

simulated function SetSoldierStats(X2SoldierClassTemplate CharacterTemplate)
{
	local int TempVal;
	local string Will, Aim, Health, Mobility, Crit, Dodge, Psi;
	local X2CharacterTemplate BaseCharacterTemplate;
	
	BaseCharacterTemplate = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager().FindCharacterTemplate(CharacterTemplate.GetRequiredCharTemplateName());
	TempVal = int(BaseCharacterTemplate.CharacterBaseStats[eStat_Will]);
	Will = string(TempVal);
	TempVal = int(BaseCharacterTemplate.CharacterBaseStats[eStat_Offense]);
	Aim = string(TempVal);
	TempVal = int(BaseCharacterTemplate.CharacterBaseStats[eStat_HP]);
	Health = string(TempVal);
	TempVal = int(BaseCharacterTemplate.CharacterBaseStats[eStat_Mobility]);
	Mobility = string(TempVal);
	TempVal = int(BaseCharacterTemplate.CharacterBaseStats[eStat_CritChance]);
	Crit = string(TempVal);
	TempVal = int(BaseCharacterTemplate.CharacterBaseStats[eStat_Dodge]);
	Dodge = string(TempVal);
	TempVal = int(BaseCharacterTemplate.CharacterBaseStats[eStat_PsiOffense]);
	Psi = string(TempVal);

	MC.BeginFunctionOp("setSoldierStats");

	MC.QueueString(class'UISoldierHeader'.default.m_strHealthLabel);
	MC.QueueString(Health);

	MC.QueueString(class'UISoldierHeader'.default.m_strMobilityLabel);
	MC.QueueString(Mobility);

	MC.QueueString(class'UISoldierHeader'.default.m_strAimLabel);
	MC.QueueString(Aim);

	MC.QueueString(class'UISoldierHeader'.default.m_strWillLabel);
	MC.QueueString(Will);

	MC.QueueString(class'UISoldierHeader'.default.m_strDodgeLabel);
	MC.QueueString(Dodge);

	MC.QueueString(class'UISoldierHeader'.default.m_strCritLabel);
	MC.QueueString(Crit);

	MC.QueueString(class'UISoldierHeader'.default.m_strPsiLabel);
	MC.QueueString(Psi);

	MC.QueueString("");
	MC.QueueString("");

	MC.EndOp();
}

simulated function SetSoldierAbilities(X2SoldierClassTemplate CharacterTemplate)
{
	local array<SoldierClassAbilityType> AllPossibleAbilities;
	local int i;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

	AllPossibleAbilities = CharacterTemplate.GetAllPossibleAbilities();
	
	MC.BeginFunctionOp("setSoldierAbilities");
	for (i = 0; i < 4; i++)
	{
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AllPossibleAbilities[i].AbilityName);

		// Only show abilities explicitly flagged to be featured in this UI popup
		if (!AbilityTemplate.bFeatureInCharacterUnlock && !AbilityTemplate.bFeatureInStartingSquadUnlock)
			continue;
		
		MC.QueueString(AbilityTemplate.LocFriendlyName);
		MC.QueueString(AbilityTemplate.GetMyLongDescription());
		MC.QueueString(AbilityTemplate.IconImage);
	}

	MC.EndOp();
}

simulated function SelectCharacter(name SoldierTemplate)
{
	if (m_UnlockCharacters.Length < m_NumSoldiersToUnlock && m_UnlockCharacters.Find(SoldierTemplate) == -1)
	{
		m_UnlockCharacters.AddItem(SoldierTemplate);
		RefreshData();
	}
	else if (m_UnlockCharacters.Find(SoldierTemplate) != -1)
	{
		if (m_UnlockCharacters.Length >= m_NumSoldiersToUnlock && MouseClickSoundCached != "")
		{
			`SOUNDMGR.PlayLoadedAkEvent(MouseClickSoundCached, self);
		}
		m_UnlockCharacters.RemoveItem(SoldierTemplate);
		RefreshData();
	}
	else
	{
		PlayNegativeMouseClickSound();
	}
}

simulated function RefreshData()
{
	local X2SoldierClassTemplateManager CharacterTemplateManager;
	local X2SoldierClassTemplate CharacterTemplate;
	local ConfigurableSoldier SoldierConfig;
	local UICharacterUnlockListItem newListItem;
	local int Index, i;
	local string AppendedTitle; 
	
	AppendedTitle = ScreenTitle; 
	AppendedTitle @= "(" $ string(m_UnlockCharacters.length) $"/4)";
		
	MC.FunctionString("setLeftListTitle", AppendedTitle);

	CharacterTemplateManager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();
	for (i = 0; i < RawDataOptions.Length; ++i)
	{
		//Extract the config data for this soldier / squad member
		Index = class'UITacticalQuickLaunch_MapData'.static.GetConfigurableSoldierSpec(RawDataOptions[i], SoldierConfig);
		if (Index < 0)
		{
			continue;
		}

		CharacterTemplate = CharacterTemplateManager.FindSoldierClassTemplate(SoldierConfig.SoldierClassTemplate);
		if (i >= m_SoldierList.ItemCount)
			newListItem = UICharacterUnlockListItem(m_SoldierList.CreateItem(class'UICharacterUnlockListItem')).InitCharacterUnlockItem(CharacterTemplate, RawDataOptions[i]);
		else
			newListItem = UICharacterUnlockListItem(m_SoldierList.GetItem(i));
			
		if (m_UnlockCharacters.Find(RawDataOptions[i]) != -1)
		{
			newListItem.SetDisabled(true);
		}
		else
		{
			newListItem.SetDisabled(false);
		}
	}

	RefreshUnitPlacards();
	UpdateNavHelp();
}

simulated function RefreshUnitPlacards()
{
	local array<SoldierClassAbilityType> AllPossibleAbilities;
	local X2SoldierClassTemplateManager CharacterTemplateManager;
	local int i, j, Index;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2SoldierClassTemplate CharacterTemplate;
	local ConfigurableSoldier SoldierConfig;

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	CharacterTemplateManager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();

	for (i = 0; i < 4; i++)
	{
		if (i < m_UnlockCharacters.Length)
		{
			Index = class'UITacticalQuickLaunch_MapData'.static.GetConfigurableSoldierSpec(m_UnlockCharacters[i], SoldierConfig);
			if (Index < 0)
			{
				continue;
			}

			CharacterTemplate = CharacterTemplateManager.FindSoldierClassTemplate(SoldierConfig.SoldierClassTemplate);

			MC.BeginFunctionOp("PopulateUnitPlacard");
			MC.QueueNumber(i);
			MC.QueueString(CharacterTemplate.FirstName);//unit name
			MC.QueueString(CharacterTemplate.DisplayName);//class name
			MC.QueueString("");//blank
			MC.QueueString(CharacterTemplate.WorkerIconImage);//portrait
			
			AllPossibleAbilities = CharacterTemplate.GetAllPossibleAbilities();

			for (j = 0; j < 4; j++)
			{
				AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AllPossibleAbilities[j].AbilityName);

				MC.QueueString(AbilityTemplate.IconImage);
			}

			MC.EndOp();
		}
		else
		{
			MC.FunctionNum("HideUnitPlacard", i);
		}
	}
}

simulated function DisplayOptions(array<name> InOptions)
{
	if (!bDisplayAllCharacters)
	{
		RawDataOptions = InOptions;
	}
	else
	{
		class'UITacticalQuickLaunch_MapData'.static.GetSquadMemberNames(class'DioStrategyAI'.default.FullCastSquadName, RawDataOptions);
	}

	RefreshData();
}


//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	return (m_UnlockCharacters.Length == m_NumSoldiersToUnlock ); //TODO: what do we evaluate here? -bsteiner 
}

function ViewBiography(UIButton Button)
{
	if(bIsFocused)
	{
		`STRATPRES.UIBiographyScreen();
	}
}

function OnConfirm(UIButton Button)
{
	local X2StrategyGameRuleset StratRules;
	local XComStrategyPresentationLayer StratPres;
	local CampaignStartData NewStartData;
	local int i;

	StratRules = `STRATEGYRULES;
	StratPres = `STRATPRES;

	if (m_UnlockCharacters.Length == m_NumSoldiersToUnlock)
	{
		PlayConfirmSound();
		CloseScreen();

		// New Campaign: populate Data and flow to select first Investigation
		if (m_bNewCampaign)
		{
			NewStartData.InitialSquadIDs = m_UnlockCharacters;
			StratPres.UINewCampaignInvestigationChooser(NewStartData);
		}
		else
		{
			// Proceed to direct unlock
			for (i = 0; i < m_UnlockCharacters.Length; i++)
			{
				StratRules.SubmitUnlockCharacter(m_UnlockCharacters[i]);
			}
		}
	}
	else
	{
		PlayNegativeMouseClickSound();
	}
}

function OnCancel()
{
	local XComStrategyPresentationLayer StratPres;

	StratPres = `STRATPRES;

	PlayNegativeMouseClickSound();
	if (m_bNewCampaign)
	{
		StratPres.QuitToShell();
	}
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	local int NumArg;

	switch( cmd )
	{
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_UP:
		if( InStr(args[args.length-1], "Placard") != -1 ) // we clicked on a unit placard
		{
			NumArg = int(GetRightMost(args[args.length - 1]));
			
			if( NumArg < m_UnlockCharacters.length )
			{
				SelectCharacter(m_UnlockCharacters[NumArg]);
			}
		}
		break;
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!bIsFocused)
	{
		return false;
	}

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	bHandled = true;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_START :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
		bHandled = true; // fallthrough
		break;
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
	case class'UIUtilities_Input'.const.FXS_BUTTON_X :
		OnConfirm(m_ContinueButton);
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_Y :
	case class'UIUtilities_Input'.const.FXS_KEY_Y :
		`STRATPRES.UIMetaContentScreen();
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_L3 :
	case class'UIUtilities_Input'.const.FXS_KEY_F1 :
		ViewBiography(none); 
		break;


	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
		PlayMouseClickSound();
		bHandled = false; // Just play the sound; let super handle the input
		break;

	default:
		bHandled = false;
		break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

function OnSelectionChanged(UIList ContainerList, int ItemIndex)
{
	if (`ISCONTROLLERACTIVE)
	{
		SetLargePanelData(UICharacterUnlockListItem(m_SoldierList.GetItem(ItemIndex)).m_SoldierTemplate);
	}
}

simulated function UpdateNavHelp()
{
	if (!bIsFocused)
		return; 

	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.AddBackButton(OnCancel);

	if( CanConfirm() )
	{
		MC.FunctionBool("HighlightRightList", true);
		m_ContinueButton.EnableButton();
		m_ContinueButton.bShouldPlayGenericUIAudioEvents = true;
		if (MouseClickSoundCached == "")
		{
			MouseClickSoundCached = m_MouseClickSound;
		}
		m_MouseClickSound = "";
		AS_SetRightListTitle(SquadPanelTitle, "");
	}
	else
	{
		MC.FunctionBool("HighlightRightList", false);
		m_ContinueButton.DisableButton();
		m_ContinueButton.bShouldPlayGenericUIAudioEvents = false;
		if (MouseClickSoundCached != "")
		{
			m_MouseClickSound = MouseClickSoundCached;
		}
		AS_SetRightListTitle(SquadPanelTitle, ErrorNeedAdditionalUnit);
	}

	if( class'UIUtilities_DioStrategy'.static.ShouldShowMetaContentTags() )
	{
		if( `ISCONTROLLERACTIVE)
		{
			m_HUD.NavHelp.AddRightHelp(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
		}
		else
		{
			m_HUD.NavHelp.AddRightHelp(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel, , XComStrategyPresentationLayer(Movie.Pres).ViewMetaContent);
		}
	}
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
	m_HUD.UpdateResources(self);
	m_ViewBiographyButton.Show();
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	m_ViewBiographyButton.Hide();
}

function bool SimulateScreenInteraction()
{
	local X2SoldierClassTemplate CharacterTemplate;
	local int index;
	local ConfigurableSoldier SoldierConfig;
	local X2SoldierClassTemplateManager CharacterTemplateManager;

	CharacterTemplateManager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();

	if (RawDataOptions.Length > 0)
	{
		Index = class'UITacticalQuickLaunch_MapData'.static.GetConfigurableSoldierSpec(RawDataOptions[0], SoldierConfig);
		if (Index >= 0)
		{
			CharacterTemplate = CharacterTemplateManager.FindSoldierClassTemplate(SoldierConfig.SoldierClassTemplate);
			SelectCharacter(CharacterTemplate.DataName);
			OnConfirm(m_ContinueButton);
			return true;
		}
	}

	return true;
}

defaultproperties
{
	MCName = "theCharacterUnlockScreen";
	Package = "/ package/gfxRosterUnlock/RosterUnlock";

	m_NumSoldiersToUnlock = 1;
	m_bNewCampaign = false;
	bAnimateOnInit = false;
	bHideOnLoseFocus = false; 
}