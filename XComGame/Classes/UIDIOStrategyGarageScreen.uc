//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategyGarageScreen
//  AUTHOR:  	David McDonough  --  3/22/2019
//  PURPOSE: 	Subscreen accessed through HQ (UIDIOStrategy). Contains entry points for
//				managing Androids and APC upgrades.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOStrategyGarageScreen extends UIScreen;

struct APCUpgradeData
{
	var name APCUpgradeTemplateName;
	var UITextContainer DescContainer;
	var UIButton Button;
};

var UIDIOHUD m_HUD;

var UIList	AndroidStatusList;
var UIList	APCStatusList;
var array<UIButton> AndroidButtons;
var array<APCUpgradeData> APCUpgradeOptions;

var float ColumnPadding;
var float ColumnWidth;
var float ColumnHeight;

var localized string NoAndroidsHelp;
var localized string UpgradesAvailable;

//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	AndroidStatusList = Spawn(class'UIList', self).InitList('AndroidStatusList', , , , , false, true);
	AndroidStatusList.AnchorTopLeft();
	AndroidStatusList.SetSize(ColumnWidth, ColumnHeight);
	AndroidStatusList.SetPosition(ColumnPadding, ColumnPadding);
	AndroidStatusList.ItemPadding = 10;

	APCStatusList = Spawn(class'UIList', self).InitList('APCStatusList', , , , , false, true);
	APCStatusList.AnchorTopLeft();
	APCStatusList.SetSize(ColumnWidth, ColumnHeight);
	APCStatusList.SetPosition(ColumnWidth + (ColumnPadding * 2), ColumnPadding);
	APCStatusList.ItemPadding = 10;

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	

	m_HUD.UpdateResources(self);
	UpdateNavHelp();

	RegisterForEvents();
	RefreshAll();
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_APCUpgradeAdded_Submitted', OnUpgradeAdded, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_APCUpgradeAdded_Submitted');
}

//---------------------------------------------------------------------------------------
//				DISPLAY
//---------------------------------------------------------------------------------------

simulated function RefreshAll()
{
	m_HUD.RefreshAll();
	RefreshAndroids();
	RefreshAPC();
}

//---------------------------------------------------------------------------------------
function RefreshAndroids()
{
	local UIText TempText;
	local UITextContainer TempTextContainer;
	local XComGameState_HeadquartersDio DioHQ;
	local string FormattedString;
	local float ContainerHeight;
	local int i;

	DioHQ = `DIOHQ;
	AndroidStatusList.ClearItems();

	// Label
	FormattedString = class'UIUtilities_Text'.static.GetColoredText(`DIO_UI.default.strTerm_Androids, eUIState_Good, 36);
	FormattedString = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(FormattedString);
	TempText = UIText(AndroidStatusList.CreateItem(class'UIText')).InitText('AndroidStatusLabel');
	TempText.SetHtmlText(FormattedString, OnTextRealized);

	AndroidButtons.Length = 0;
	if (DioHQ.Androids.Length > 0)
	{
		for (i = 0; i < DioHQ.Androids.Length; ++i)
		{
			RefreshAndroidButton(i);
		}
	}
	else
	{
		// 'No Androids' help text
		FormattedString = `DIO_UI.static.FormatBody(NoAndroidsHelp);
		ContainerHeight = 512.0f;
		TempTextContainer = UITextContainer(AndroidStatusList.CreateItem(class'UITextContainer')).InitTextContainer('AndroidFPOInfo', , , , ColumnWidth, ContainerHeight);
		TempTextContainer.SetHtmlText(FormattedString);
	}
}

//---------------------------------------------------------------------------------------
function RefreshAndroidButton(int AndroidIndex)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit AndroidUnit;
	local UIButton AndroidButton;
	local string FormattedString;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;
	
	AndroidUnit = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Androids[AndroidIndex].ObjectID));
	if (AndroidUnit == none)
	{
		return;
	}

	AndroidButton = UIButton(AndroidStatusList.CreateItem(class'UIButton')).InitButton(, , OnAndroidButton);
	AndroidButton.SetWidth(ColumnWidth);
	AndroidButton.SetHeight(64);
	
	FormattedString = `DIO_UI.static.FormatSubheader(AndroidUnit.GetName(eNameType_Full) @ "\n" @ AndroidUnit.GetName(eNameType_Nick), , 24);
	AndroidButton.SetText(FormattedString);

	AndroidButtons.AddItem(AndroidButton);
}

//---------------------------------------------------------------------------------------
function RefreshAPC()
{
	local X2StrategyElementTemplateManager TemplateMgr;
	local array<X2StrategyElementTemplate> TemplateCollection;
	local XComGameState_HeadquartersDio DioHQ;
	local X2DioAPCUpgradeTemplate UpgradeTemplate;
	local APCUpgradeData UpgradeOption;
	local UIText TempText;
	local UITextContainer TempTextContainer;
	local UIButton UpgradeButton;
	local EUIState UIState;
	local string FormattedString, TempString;
	local float ContainerHeight;
	local name OwnedUpgradeName;
	local bool bUpgradeAvailable, bCanAfford;
	local int i, Cost;

	TemplateMgr = `STRAT_TEMPLATE_MGR;
	DioHQ = `DIOHQ;
	APCStatusList.ClearItems();
	ContainerHeight = 160.0f;

	// Label
	FormattedString = class'UIUtilities_Text'.static.GetColoredText(`DIO_UI.default.strTerm_APC_Long, eUIState_Good, 36);
	FormattedString = `MAKECAPS(FormattedString);
	TempText = UIText(APCStatusList.CreateItem(class'UIText')).InitText('APCStatusLabel');
	TempText.SetHtmlText(FormattedString, OnTextRealized);

	// New Upgrade options
	APCUpgradeOptions.Length = 0;

	// Section heading
	FormattedString = `DIO_UI.static.FormatSubheader(UpgradesAvailable);
	TempText = UIText(APCStatusList.CreateItem(class'UIText')).InitText('AvailableSectionHeader');
	TempText.SetHtmlText(FormattedString, OnTextRealized);

	TemplateCollection = TemplateMgr.GetAllTemplatesOfClass(class'X2DioAPCUpgradeTemplate');
	if (TemplateCollection.Length > 0)
	{
		for (i = 0; i < TemplateCollection.Length; ++i)
		{
			UpgradeTemplate = X2DioAPCUpgradeTemplate(TemplateCollection[i]);
			Cost = UpgradeTemplate.GetCost();

			bUpgradeAvailable = DioHQ.CanAddAPCUpgrade(UpgradeTemplate.DataName);
			bCanAfford = DioHQ.Credits >= Cost;

			if (bUpgradeAvailable)
			{
				UIState = bCanAfford ? eUIState_Good : eUIState_Bad;
			}
			else
			{
				UIState = eUIState_Normal;
			}

			// Name
			FormattedString = `DIO_UI.static.FormatSubheader(UpgradeTemplate.DisplayName, , 24);
			// Desc
			TempString = `DIO_UI.static.FormatBody(UpgradeTemplate.Description, , 18);
			FormattedString $= "\n" $ TempString;

			// Cost
			TempString = `DIO_UI.static.FormatSubheader(`DIO_UI.static.FormatCreditsValue(Cost), UIState, 24);
			FormattedString $= "\n" $ TempString;

			TempTextContainer = UITextContainer(APCStatusList.CreateItem(class'UITextContainer')).InitTextContainer(, , , , ColumnWidth, ContainerHeight);
			TempTextContainer.SetCenteredText(FormattedString);

			// Buy Button
			FormattedString = `DIO_UI.static.FormatSubheader(`DIO_UI.default.strTerm_Buy, , 24);
			UpgradeButton = UIButton(APCStatusList.CreateItem(class'UIButton')).InitButton(, FormattedString, OnAPCUpgradeButton);
			UpgradeButton.SetWidth(ColumnWidth);
			UpgradeButton.SetHeight(48);
			UpgradeButton.SetDisabled(!(bUpgradeAvailable && bCanAfford));

			UpgradeOption.APCUpgradeTemplateName = UpgradeTemplate.DataName;
			UpgradeOption.DescContainer = TempTextContainer;
			UpgradeOption.Button = UpgradeButton;
			APCUpgradeOptions.AddItem(UpgradeOption);
		}
	}
	else
	{
		FormattedString = `DIO_UI.static.FormatSubheader(`DIO_UI.default.strTerm_None, , 18);
		TempText = UIText(APCStatusList.CreateItem(class'UIText')).InitText();
		TempText.SetHtmlText(FormattedString, OnTextRealized);
	}

	// Owned upgrades
	
	// Section heading
	FormattedString = `DIO_UI.static.FormatSubheader(`DIO_UI.default.strTerm_Owned);
	TempText = UIText(APCStatusList.CreateItem(class'UIText')).InitText('OwnedSectionHeader');
	TempText.SetHtmlText(FormattedString, OnTextRealized);
	
	if (DioHQ.APCUpgrades.Length > 0)
	{
		foreach DioHQ.APCUpgrades(OwnedUpgradeName)
		{
			UpgradeTemplate = X2DioAPCUpgradeTemplate(TemplateMgr.FindStrategyElementTemplate(OwnedUpgradeName));

			// Owned
			FormattedString = `DIO_UI.static.FormatSubheader(`DIO_UI.default.strTerm_Owned $ ":" @ string(DioHQ.CountOwnedAPCUpgrades(OwnedUpgradeName)), , 24);
			// Name
			TempString = `DIO_UI.static.FormatSubheader(UpgradeTemplate.DisplayName, , 24);
			FormattedString $= "\n" $ TempString;
			// Desc
			TempString = `DIO_UI.static.FormatBody(UpgradeTemplate.Description, , 18);
			FormattedString $= "\n" $ TempString;

			TempTextContainer = UITextContainer(APCStatusList.CreateItem(class'UITextContainer')).InitTextContainer(, , , , ColumnWidth, ContainerHeight);
			TempTextContainer.SetCenteredText(FormattedString);
		}
	}
	else
	{
		FormattedString = `DIO_UI.static.FormatSubheader(`DIO_UI.default.strTerm_None, , 18);
		TempText = UIText(APCStatusList.CreateItem(class'UIText')).InitText();
		TempText.SetHtmlText(FormattedString, OnTextRealized);
	}
}

//---------------------------------------------------------------------------------------
simulated function OnTextRealized()
{
	AndroidStatusList.RealizeItems();
	APCStatusList.RealizeItems();
}

//---------------------------------------------------------------------------------------
//				INPUT HANDLER
//---------------------------------------------------------------------------------------

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
		PlayMouseClickSound();
		CloseScreen();
		break;
	default:
		break;
	}

	return true;
}

//---------------------------------------------------------------------------------------
function OnAndroidButton(UIButton Button)
{
	local XComStrategyPresentationLayer Pres;
	local int i;

	Pres = `STRATPRES;

	for (i = 0; i < AndroidButtons.Length; ++i)
	{
		if (AndroidButtons[i] == Button)
		{
			Pres.UIHQArmory_Androids(i);
		}
	}
}

//---------------------------------------------------------------------------------------
function OnAPCUpgradeButton(UIButton Button)
{
	local int i;


	for (i = 0; i < APCUpgradeOptions.Length; ++i)
	{
		if (APCUpgradeOptions[i].Button == Button)
		{
			// DIO DEPRECATED [10/11/2019 dmcdonough]
		}
	}
}

//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------

function EventListenerReturn OnUpgradeAdded(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
//				NAVIGATION
//---------------------------------------------------------------------------------------

function UpdateNavHelp()
{
	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.AddBackButton(OnCancel);
}

//---------------------------------------------------------------------------------------
// override in child classes to provide custom behavior
simulated function OnCancel()
{
	CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	UnRegisterForEvents();
	//Return to the HQ overview area ( none for event data )
	`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', none, self, none);
	super.CloseScreen();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	m_HUD.UpdateResources(self);
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	ColumnPadding=64
	ColumnWidth=512
	ColumnHeight=720
}