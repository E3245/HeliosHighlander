
class UICharacterUnlock extends UIScreen implements(UIDioAutotestInterface) native(UI);

var UIDIOHUD m_HUD;
var UIButton m_ContinueButton;
var UIButton m_BiographyButton;
var UIButton m_MetaContentButton;

var array<name>	RawDataOptions;
var array<name> m_UnlockCharacters;
var name UnlockCharacter;

var localized string TitleText;
var localized string DirectionsText;
var localized string ToggleBiography;
var localized string ToggleAbilities;

var int iCurrentSelection;
var int iMaxUnits;
var bool bIsShowingBiography;

var const int MaxAbilitiesToShow; //NOTE: WE ONLY SHOW MAX 3 ABILITIES IN THIS VIEW 


simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END
	m_HUD.UpdateResources(self);

	MC.BeginFunctionOp("SetCharacterUnlockTitle");
	MC.QueueString(TitleText);
	MC.QueueString(DirectionsText);
	MC.EndOp();

	if( `ISCONTROLLERACTIVE)
	{
		// mmg_aaron.lee (11/22/19) - add gamepad icon prefix.  
		m_ContinueButton = Spawn(class'UIButton', self).InitButton('unlockConfirmButton', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE, 20, 20, 0) @ class'UIUtilities_Text'.default.m_strGenericConfirm,
																   OnConfirm);
		m_BiographyButton = Spawn(class'UIButton', self).InitButton('unlockBiographyButton', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RB_R1, 20, 20, 0) @ `MAKECAPS(ToggleBiography),
																	OnToggleBiography);
		SelectCharacter(0);
	}
	else
	{
		m_ContinueButton = Spawn(class'UIButton', self).InitButton('unlockConfirmButton',
																   class'UIUtilities_Text'.default.m_strGenericConfirm,
																   OnConfirm);
		m_BiographyButton = Spawn(class'UIButton', self).InitButton('unlockBiographyButton', 
																	`MAKECAPS(ToggleBiography),
																	OnToggleBiography);
	}
	m_ContinueButton.SetWidth(400);
	m_ContinueButton.SetGood(true);

	m_BiographyButton.SetWidth(400);
}

simulated function OnInit()
{
	super.OnInit();
}

function RefreshData(array<name> InData)
{
	local X2SoldierClassTemplateManager CharacterTemplateManager;
	local X2SoldierClassTemplate CharacterTemplate;
	local ConfigurableSoldier SoldierConfig;
	local int i, FoundIndex, iSlotIndex;

	RawDataOptions = InData; 

	m_UnlockCharacters.length = 0;

	CharacterTemplateManager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();
	
	iSlotIndex = 0;
	for(i = 0; i < RawDataOptions.length; i++ )
	{
		FoundIndex = class'UITacticalQuickLaunch_MapData'.static.GetConfigurableSoldierSpec(RawDataOptions[i], SoldierConfig);
		if( FoundIndex >= 0 )
		{
			CharacterTemplate = CharacterTemplateManager.FindSoldierClassTemplate(SoldierConfig.SoldierClassTemplate);
		}
		if( CharacterTemplate != none )
		{
			m_UnlockCharacters.AddItem(RawDataOptions[i]);
			SetUnitData(iSlotIndex, CharacterTemplate);
			SetUnitAbilities(iSlotIndex, CharacterTemplate);
			SetSoldierStats(iSlotIndex, CharacterTemplate);

			MC.BeginFunctionOp("SetBiographyText");
			MC.QueueNumber(iSlotIndex);
			MC.QueueString(class'UIBiographyScreen'.static.FormatText(CharacterTemplate.ClassLongBio, false));
			MC.EndOp();

			iSlotIndex++;
		}
	}

	UpdateNavHelp();

	if( `ISCONTROLLERACTIVE && UnlockCharacter == '' )
	{
		SelectCharacter(0);
	}
}

simulated function SetUnitData(int Index, X2SoldierClassTemplate CharacterTemplate)
{
	local string Label; 

	Label = CharacterTemplate.FirstName; 
	if( class'UIUtilities_DioStrategy'.static.ShouldShowMetaContentTags() )
	{
		if(`XPROFILESETTINGS.HasUsedAgent(CharacterTemplate.DataName) == false)
		{
			Label = `META_TAG $ Label;
		}
		else
		{
			Label = `META_TAG_SEEN $ Label;
		}
	}

	MC.BeginFunctionOp("SetUnitDataLarge");
	MC.QueueNumber(Index);
	MC.QueueString(Label); //Soldier Name
	MC.QueueString(CharacterTemplate.WorkerIconImage $"_LG"); // Image, special large size for this screen 
	MC.QueueString(class'UIUtilities_Text'.static.ConvertStylingToFontFace(CharacterTemplate.ClassSummary $ "\n<i>" $ CharacterTemplate.ClassQuote $"<\i>")); // Gameplay, Quote
	MC.EndOp();
}

simulated function SetUnitAbilities(int Index, X2SoldierClassTemplate CharacterTemplate)
{
	local array<SoldierClassAbilityType> AllPossibleAbilities;
	local int i;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local string tooltipPath, Prefix, AbilityName;
	
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

	AllPossibleAbilities = CharacterTemplate.GetAllPossibleAbilities();

	MC.BeginFunctionOp("setSoldierAbilities");
	MC.QueueNumber(Index);

	for( i = 0; i < MaxAbilitiesToShow; i++ )
	{
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AllPossibleAbilities[i].AbilityName);

		// Only show abilities explicitly flagged to be featured in this UI popup
		if (!AbilityTemplate.bFeatureInCharacterUnlock)
		{
			continue;
		}

		AbilityName = AbilityTemplate.LocFriendlyName;
		// Include "Locked" prefix for abilities that come at ranks greater than 0
		if (CharacterTemplate.GetAbilityUnlockRank(AbilityTemplate.DataName) > 0)
		{
			Prefix = class'UIUtilities_Text'.static.GetColoredText(`MAKECAPS(`DIO_UI.default.strTerm_Locked), eUIState_Warning);
			AbilityName = Prefix $ ":" @ AbilityName;
		}

		MC.QueueString(AbilityName);
		MC.QueueString(AbilityTemplate.GetMyLongDescription());
		MC.QueueString(AbilityTemplate.IconImage);

		//Tooltip 
		//_level0.theInterfaceMgr.UICharacterUnlock_0.theScreen.item_2.abilityIcon_0
		tooltipPath = string(MCPath) $ ".item_" $ index $".abilityIcon_" $ i ;

		Movie.Pres.m_kTooltipMgr.AddNewTooltipTextBox(AbilityTemplate.GetMyLongDescription(),
													  0,
													  -10,
													  tooltipPath,
													  AbilityTemplate.LocFriendlyName,
													  true,,true);


	}

	MC.EndOp();
}

simulated function SetSoldierStats(int Index, X2SoldierClassTemplate CharacterTemplate)
{
	local int TempVal;
	local string Will, Aim, Health, Mobility, Crit, Dodge, Psi;
	local X2CharacterTemplate BaseCharacterTemplate;
	local bool bIncludePsi;

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
	bIncludePsi = TempVal > 0;
	Psi = string(TempVal);

	MC.BeginFunctionOp("setSoldierStats");
	MC.QueueNumber(Index);

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

	if (bIncludePsi)
	{
		MC.QueueString(class'UISoldierHeader'.default.m_strPsiLabel);
		MC.QueueString(Psi);
	}
	else
	{
		MC.QueueString("");
		MC.QueueString("");
	}

	MC.EndOp();
}

simulated function SelectCharacter(int TargetIndex)
{
	PlayMouseClickSound();

	//Cap the ends 
	if( TargetIndex < 0 )
	{
		iCurrentSelection = 0; 
	}
	else if( TargetIndex >= iMaxUnits )
	{
		iCurrentSelection = iMaxUnits - 1;
	}
	else
	{
		iCurrentSelection = TargetIndex;
	}

	if( m_UnlockCharacters.Length > 0 && TargetIndex > -1 && TargetIndex < m_UnlockCharacters.Length )
	{
		UnlockCharacter = m_UnlockCharacters[TargetIndex];
		MC.FunctionNum("HighlightSlot", TargetIndex);
	}
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	return UnlockCharacter != '';
}

function OnConfirm(UIButton Button)
{
	local X2StrategyGameRuleset StratRules;

	PlayConfirmSound();

	`XEVENTMGR.TriggerEvent('Analytics_SquadTeamMemberSelected', self, self, none);

	StratRules = `STRATEGYRULES;
	StratRules.SubmitUnlockCharacter(UnlockCharacter);
	CloseScreen();
}

function OnToggleBiography(UIButton Button)
{
	local string toggleString;

	PlayMouseClickSound();
	if (bIsShowingBiography)
	{
		MC.FunctionVoid("ShowAbilities");
		toggleString = ToggleBiography;
	}
	else
	{
		MC.FunctionVoid("ShowBiographies");
		toggleString = ToggleAbilities;
	}

	bIsShowingBiography = !bIsShowingBiography;
	toggleString = `MAKECAPS(toggleString);

	if (`ISCONTROLLERACTIVE)
	{
		m_BiographyButton.SetText(class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RB_R1, 20, 20, 0) @ toggleString);
	}
	else
	{
		m_BiographyButton.SetText(toggleString);
	}
}

function OnViewMetaContent(UIButton Button)
{
	`STRATPRES.UIMetaContentScreen();
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	local int NumArg;
	if( cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_UP )
	{
		if( InStr(args[args.length - 3], "unitInfoPanel_") != -1 ) 
		{
			NumArg = int(GetRightMost(args[args.length - 3]));
			SelectCharacter(NumArg);
		}
	}
	else
	{
		switch (cmd)
		{
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER:
		case class'UIUtilities_input'.const.FXS_L_MOUSE_DRAG_OVER:
			PlayMouseoverSound();
			break;
		}
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	// Only allow releases through past this point.
	if ((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0)
	{
		return false;
	}

	bHandled = true;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
	case class'UIUtilities_Input'.const.FXS_ARROW_LEFT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
	case class'UIUtilities_Input'.const.FXS_KEY_A :
		if( UnlockCharacter == '' )
			SelectCharacter(0);
		else
			SelectCharacter(iCurrentSelection - 1);
		break;

	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
	case class'UIUtilities_Input'.const.FXS_ARROW_RIGHT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT :
	case class'UIUtilities_Input'.const.FXS_KEY_D :
		if( UnlockCharacter == '' )
			SelectCharacter(0);
		else
			SelectCharacter(iCurrentSelection + 1);
		break;

	case class'UIUtilities_Input'.const.FXS_DPAD_UP :
	case class'UIUtilities_Input'.const.FXS_ARROW_UP :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP :
	case class'UIUtilities_Input'.const.FXS_KEY_W :
		RequestScroll(iCurrentSelection, 3);
		break; 

	case class'UIUtilities_Input'.const.FXS_DPAD_DOWN :
	case class'UIUtilities_Input'.const.FXS_ARROW_DOWN :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN :
	case class'UIUtilities_Input'.const.FXS_KEY_S :
		RequestScroll(iCurrentSelection, -3);
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
		MC.FunctionVoid("ToggleSelection");
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER :
		OnToggleBiography(m_BiographyButton);
		break;

	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
	case class'UIUtilities_Input'.const.FXS_BUTTON_X :
		OnConfirm(m_ContinueButton);
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_Y :
	case class'UIUtilities_Input'.const.FXS_KEY_Y :
		`STRATPRES.UIMetaContentScreen();
		break;

	default:
		break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

function RequestScroll(int Index, int iDirection) // -1 = up ; 1 = down 
{
	MC.BeginFunctionOp("OnChildMouseScrollEvent");
	MC.QueueNumber(Index);
	MC.QueueNumber(iDirection);
	MC.EndOp();
}

simulated function UpdateNavHelp()
{
	if( !bIsFocused )
		return;

	m_HUD.NavHelp.ClearButtonHelp();

	if( CanConfirm() )
	{
		m_ContinueButton.EnableButton();
	}
	else
	{
		m_ContinueButton.DisableButton();
	}
	
	if( m_MetaContentButton == none )
	{
		m_MetaContentButton = Spawn(class'UIButton', self).InitButton('viewMetaContentBtn',
																		(`ISCONTROLLERACTIVE ? class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE : "") @ `META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel,
																		OnViewMetaContent);
		m_MetaContentButton.SetWidth(400); 
	}

	if( `ISCONTROLLERACTIVE)
	{
		m_BiographyButton.SetText(class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RB_R1, 30, 20, 0) @ ToggleBiography);
		m_ContinueButton.SetText(class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE, 20, 20, 0) @ class'UIUtilities_Text'.default.m_strGenericConfirm);

		m_MetaContentButton.SetText(class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE, 20, 20, 0) @ `META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel);
	}
	else
	{
		m_BiographyButton.SetText(`MAKECAPS(ToggleBiography));
		m_ContinueButton.SetText(class'UIUtilities_Text'.default.m_strGenericConfirm);
		m_MetaContentButton.SetText(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel);
	}
	
	m_MetaContentButton.SetVisible(class'UIUtilities_DioStrategy'.static.ShouldShowMetaContentTags());

	/*if( class'UIUtilities_DioStrategy'.static.ShouldShowMetaContentTags() )
	{

		
		if( `ISCONTROLLERACTIVE)
		{
			m_HUD.NavHelp.AddRightHelp(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
		}
		else
		{
			m_HUD.NavHelp.AddRightHelp(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel, , XComStrategyPresentationLayer(Movie.Pres).UIMetaContentScreen);
		}
	}*/
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
	m_HUD.UpdateResources(self);
}

function bool SimulateScreenInteraction()
{
	if( m_UnlockCharacters.Length > 0 )
	{
		SelectCharacter(0);
		OnConfirm(m_ContinueButton);
		return true;
	}

	return true;
}

defaultproperties
{
	Package = "/ package/gfxCharacterUnlock/CharacterUnlock";
	MCName = "theScreen";

	bConsumeMouseEvents = true;
	iCurrentSelection = 0;
	iMaxUnits = 3;

	MaxAbilitiesToShow = 3 //NOTE: WE ONLY SHOW MAX 3 ABILITIES IN THIS VIEW 
	bIsShowingBiography = false
}