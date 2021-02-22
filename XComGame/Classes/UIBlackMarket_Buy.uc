//---------------------------------------------------------------------------------------
//  FILE:    	UIBlackMarket_Buy
//  AUTHOR:  	Updated for DIO by: David McDonough  --  3/18/2019
//  PURPOSE: 	UI for handling display and purchasing of items from an 
//				XComGameState_StrategyMarket object.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIBlackMarket_Buy extends UISimpleCommodityScreen;

// DIO
var StateObjectReference	MarketRef;
var array<UITabIconButton>	Tabs;
var bool					m_bIsSupplyMarket;
var bool					m_bIsInventory;
var int						m_CurrentTab;

var localized String	m_strBuyConfirmTitle;
var localized String	m_strBuyConfirmText;
var localized String	m_strHQXcomStoreTitle;
var localized string	m_strHQXcomStoreSubTitle;
var localized String	m_strSupplyStoreTitle;
var localized string	m_strSupplyStoreSubTitle;
var localized String	m_strNextCategory;
var localized String	m_strPreviousCategory;
var localized String	m_strToggleSupply;
var localized String	m_strToggleInventory;
var localized string	m_strInventoryStoreTitle;
var localized string	m_strInventoryStoreSubTitle;

var delegate<OnItemSelectedCallback> OnItemClicked;

delegate OnItemSelectedCallback(UIList ContainerList, int ItemIndex);

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	m_strTitle = m_bIsSupplyMarket ? m_strSupplyStoreTitle : m_strHQXcomStoreTitle; 
	m_strSubTitleTitle = m_bIsSupplyMarket ? m_strSupplyStoreSubTitle : m_strHQXcomStoreSubTitle;
	super.InitScreen(InitController, InitMovie, InitName);
	RegisterForEvents();
	SetBlackMarketLayout(m_bIsSupplyMarket);
	BuildTabs();

	// mmg_aaron.lee (11/1/19) BEGIN - align to the left. Can't use SAFEZONEHORIZONTAL due to a weird margin. 
	AnchorTopLeft();
	SetPanelScale(`INVESTIGATIONSCALER);
	SetPosition(-`SUPPLYXOFFSET, `SUPPLYYOFFSET);
	// mmg_aaron.lee (11/1/19) END

	// HELIOS BEGIN
	`PRESBASE.RefreshCamera(class'XComStrategyPresentationLayer'.const.SupplyAreaTag);
	// HELIOS END

	if (List.OnItemClicked != none)
	{
		OnItemClicked = List.OnItemClicked;
	}
	List.OnItemClicked = OnListItemClicked;
}

simulated function UpdateNavHelp()
{
	local string toggleLabel;

	super.UpdateNavHelp();
	
	toggleLabel = (m_bIsInventory ? m_strToggleInventory : m_strToggleSupply);

	// mmg_john.hawley (11/7/19) - Updating NavHelp
	if (`ISCONTROLLERACTIVE)
	{
		m_HUD.NavHelp.ClearButtonHelp();
		m_HUD.NavHelp.AddBackButton(CloseScreen);
		if (`ISCONTROLLERACTIVE && CanAffordItem(iSelectedItem) && !IsItemPurchased(iSelectedItem))
			m_HUD.NavHelp.AddSelectNavHelp(); // mmg_john.hawley (11/5/19) - Updating NavHelp for new controls
		m_HUD.NavHelp.AddLeftHelp(Caps(toggleLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
		m_HUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyScreenNavigation'.default.CategoryLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LTRT_L2R2);
		//m_HUD.NavHelp.AddCenterHelp(Caps(toggleLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
	}
	else
	{
		m_HUD.NavHelp.AddCenterHelp(Caps(toggleLabel),, ToggleInventorySupply);
	}

}

simulated function ToggleInventorySupply()
{
	PlayMouseClickSound();

	m_bIsInventory = !m_bIsInventory;

	if (m_bIsInventory)
	{
		m_eStyle = eUIConfirmButtonStyle_None;
	}
	else
	{
		m_eStyle = eUIConfirmButtonStyle_Default;
	}

	SetHeader(m_bIsInventory ? m_strInventoryStoreTitle : m_strTitle, m_bIsInventory ? m_strInventoryStoreSubTitle : m_strSubTitleTitle);
	GetItems();
	PopulateData(); 
	UpdateNavHelp();
}

simulated function PopulateData()
{
	local int ItemIdx;
	local UIListItemString Item;

	super.PopulateData();

	for (ItemIdx = 0; ItemIdx < List.ItemCount; ++ItemIdx)
	{
		Item = UIListItemString(List.GetItem(ItemIdx));
		if (Item != none)
		{
			Item.bShouldPlayGenericUIAudioEvents = false;
			if (Item.ButtonBG != none)
			{
				Item.ButtonBG.bShouldPlayGenericUIAudioEvents = false;
			}
		}
	}
}

function BuildTabs()
{
	local UITabIconButton Tab;

	Tabs.AddItem(CreateTab(0, class'UIUtilities_Image'.const.CategoryIcon_Gun, class'UIDIOAssemblyScreen'.default.CategoryLabel_Gun));
	Tabs.AddItem(CreateTab(1, class'UIUtilities_Image'.const.CategoryIcon_Armor, class'UIDIOAssemblyScreen'.default.CategoryLabel_Armor));
	Tabs.AddItem(CreateTab(2, class'UIUtilities_Image'.const.CategoryIcon_CheckMark, class'UIDIOAssemblyScreen'.default.CategoryLabel_CheckMark));
	Tabs.AddItem(CreateTab(3, class'UIUtilities_Image'.const.CategoryIcon_Grenade, class'UIDIOAssemblyScreen'.default.CategoryLabel_Grenade));
	Tabs.AddItem(CreateTab(4, class'UIUtilities_Image'.const.CategoryIcon_Breach, class'UIDIOAssemblyScreen'.default.CategoryLabel_Breach));
	Tabs.AddItem(CreateTab(5, class'UIUtilities_Image'.const.CategoryIcon_Robot, class'UIDIOAssemblyScreen'.default.CategoryLabel_Robot));
	Tabs.AddItem(CreateTab(6, class'UIUtilities_Image'.const.CategoryIcon_All, class'UIDIOAssemblyScreen'.default.CategoryLabel_Default));

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
	SelectTabByIndex((m_CurrentTab + 1) % Tabs.length);
}

function PreviousTab()
{
	SelectTabByIndex((m_CurrentTab + Tabs.length - 1) % Tabs.length);
}

function OnClickedTab(UIButton Button)
{
	// Wait to set m_CurrentTab in SelectTabByIndex so that changes can be detected
	SelectTabByIndex(int(GetRightMost(Button.MCName)));
}

function SelectTabByIndex(int newIndex)
{
	local UITabIconButton Tab;
	local int i;

	if (newIndex != m_CurrentTab)
	{
		PlayMouseClickSound();
	}

	m_CurrentTab = newIndex;

	GetItems();
	PopulateData();

	for (i = 0; i < Tabs.length; i++)
	{
		Tab = Tabs[i];
		Tab.SetSelected(m_CurrentTab == i);
	}

	GetMarket().HandleSeenItems(arrItems);
	MC.FunctionString("setItemCategory", Tabs[m_CurrentTab].metadataString);//should send the category label over!
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_MarketTransactionComplete_Submitted', OnTransactionComplete, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_MarketTransactionComplete_Submitted');
}

//-------------- EVENT HANDLING --------------------------------------------------------
simulated function OnPurchaseClicked(UIList kList, int itemIndex)
{
	// Early out: can't buy items you already own
	// todo @bsteiner: handle the "Unequip" interaction for items assigned to units
	if (m_bIsInventory)
	{
		return;
	}

	if (itemIndex != iSelectedItem)
	{
		iSelectedItem = itemIndex;
	}

	if( CanAffordItem(iSelectedItem) )
	{
		// mmg_john.hawley - (11/19/19) - Display confirmation prompt for mouse AND controller
		PlayMouseClickSound();
		//DisplayConfirmBuyDialog();

		OnDisplayConfirmBuyDialogAction('eUIAction_Accept');
		return;
	}
	else
	{
		PlayNegativeMouseClickSound();
	}
}

//---------------------------------------------------------------------------------------
function DisplayConfirmBuyDialog()
{
	local TDialogueBoxData kConfirmData;
	local Commodity ItemCommodity;
	local String ItemCost;

	ItemCommodity = arrItems[iSelectedItem];
	ItemCost = class'UIUtilities_DioStrategy'.static.GetCommodityCostString(ItemCommodity);

	kConfirmData.eType = eDialog_Warning;
	kConfirmData.strTitle = m_strBuyConfirmTitle;
	kConfirmData.strText = Repl(m_strBuyConfirmText,"<amount>",Caps(ItemCost));
	kConfirmData.strAccept = class'UIUtilities_Text'.default.m_strGenericConfirm;
	kConfirmData.strCancel = class'UIUtilities_Text'.default.m_strGenericCancel;
	kConfirmData.bMuteAcceptSound = true;
	kConfirmData.bMuteCancelSound = true;

	kConfirmData.fnCallback = OnDisplayConfirmBuyDialogAction;

	Movie.Pres.UIRaiseDialog(kConfirmData);
}

//---------------------------------------------------------------------------------------
function OnDisplayConfirmBuyDialogAction(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		GetMarket().PurchaseItem(arrItems[iSelectedItem]);
	}
	else
	{
		PlayMouseClickSound();
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	// Only pay attention to presses or repeats; ignoring other input types
	// NOTE: Ensure repeats only occur with arrow keys
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	bHandled = true;
	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER :
		PreviousTab();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER :
		NextTab();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_Y :
		ToggleInventorySupply();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		PlayMouseClickSound();
		bHandled = false; // Play the sound without cutting off super
		break;
	default:
		bHandled = false;
		break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnTransactionComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	GetSupplyItems();
	PopulateData();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	local XComGameState_StrategyMarket Market;

	UnRegisterForEvents();

	Market = GetMarket();
	if (Market.UnseenItemNames.Length > 0)
	{
		`STRATEGYRULES.SubmitClearUnseenMarketItems(Market.GetReference());
	}

	super.CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function OnListItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIInventory_ListItem ListItem;

	if (OnItemClicked != none)
	{
		OnItemClicked(ContainerList, ItemIndex);
	}

	ListItem = UIInventory_ListItem(ContainerList.GetItem(ItemIndex));
	if (ListItem != none && ListItem.bIsBad)
	{
		PlayNegativeMouseClickSound();
	}
}

//-------------- GAME DATA HOOKUP --------------------------------------------------------
simulated function XComGameState_StrategyMarket GetMarket()
{
	return XComGameState_StrategyMarket(`XCOMHISTORY.GetGameStateForObjectID(MarketRef.ObjectID));
}


simulated function GetItems()
{
	if(m_bIsInventory)
		GetInventoryItems();
	else
		GetSupplyItems();
}

//---------------------------------------------------------------------------------------
simulated function GetSupplyItems()
{
	local delegate<X2ItemTemplate.ValidationDelegate> CategoryValidator;

	GetTabValidator(m_CurrentTab, CategoryValidator);
	arrItems = GetMarket().PrepareForSaleItemsValidated(CategoryValidator);
}

//---------------------------------------------------------------------------------------
simulated function GetInventoryItems()
{
	local bool bIncludeEquippedItems;
	local delegate<X2ItemTemplate.ValidationDelegate> CategoryValidator;

	GetTabValidator(m_CurrentTab, CategoryValidator);
	bIncludeEquippedItems = true; // exposed in case this ends up being a setting
	arrItems = `DIOHQ.GetInventoryItemCommodities(bIncludeEquippedItems, CategoryValidator);
}

function GetTabValidator (int Index, out delegate<X2ItemTemplate.ValidationDelegate> OutValidationFn)
{
	switch (Index)
	{
	case 0:	
		OutValidationFn = ValidateTab_AmmoWeapons;
		break;
	case 1:
		OutValidationFn = ValidateTab_ArmorDefense;
		break;
	case 2:
		OutValidationFn = ValidateTab_Misc;
		break;
	case 3:
		OutValidationFn = ValidateTab_Grenades;
		break;
	case 4:
		OutValidationFn = ValidateTab_Breach;
		break;
	case 5:
		OutValidationFn = ValidateTab_Androids;
		break;
	case 6:
		OutValidationFn = ValidateTab_All;
		break;
	}
}
//---------------------------------------------------------------------------------------
static function bool ValidateTab_All(X2ItemTemplate ItemTemplate)
{
	switch (ItemTemplate.ItemCat)
	{
	case 'ammo':
	case 'weapon':
	case 'defense':
	case 'psidefense':
	case 'armor':
	case 'grenade':
	case 'utility':
	case 'heal':
	case 'tech':
	case 'breachthrowable':
	case 'breachutility':
	case 'androidunit':
	case 'androidupgrade':
	case 'upgrade':
		return true;
	}
	return false;
}
//---------------------------------------------------------------------------------------
static function bool ValidateTab_AmmoWeapons(X2ItemTemplate ItemTemplate)
{
	switch (ItemTemplate.ItemCat)
	{
	case 'ammo':
	case 'weapon':
		return true;
	}

	if (ItemTemplate.ItemCat == 'upgrade')
	{
		if (ClassIsChildOf(ItemTemplate.Class, class'X2WeaponUpgradeTemplate'))
		{
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
static function bool ValidateTab_ArmorDefense(X2ItemTemplate ItemTemplate)
{
	switch (ItemTemplate.ItemCat)
	{
	case 'defense':
	case 'psidefense':
	case 'armor':
		return true;
	}

	// Armor mods count, specific ones
	if (ItemTemplate.ItemCat == 'upgrade')
	{
		if (ItemTemplate.DataName == 'EnhancedArmorUpgradeItem' ||
			ItemTemplate.DataName == 'MastercraftedArmorUpgradeItem')
		{
			return true;
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
static function bool ValidateTab_Grenades(X2ItemTemplate ItemTemplate)
{
	switch (ItemTemplate.ItemCat)
	{
	case 'grenade':	
		return true;
	}
	return false;
}

//---------------------------------------------------------------------------------------
static function bool ValidateTab_Breach(X2ItemTemplate ItemTemplate)
{
	switch (ItemTemplate.ItemCat)
	{
	case 'breachutility':
	case 'breachthrowable':
		return true;
	}
	return false;
}

//---------------------------------------------------------------------------------------
static function bool ValidateTab_Androids(X2ItemTemplate ItemTemplate)
{
	switch (ItemTemplate.ItemCat)
	{
	case 'androidunit':
	case 'androidupgrade':
		return true;
	}
	return false;
}

//---------------------------------------------------------------------------------------
static function bool ValidateTab_Misc(X2ItemTemplate ItemTemplate)
{
	switch (ItemTemplate.ItemCat)
	{
	case 'utility':
	case 'heal':
		return true;
	}

	// Brute-force exclusion for any fallthrough items
	if (!ValidateTab_AmmoWeapons(ItemTemplate) &&
		!ValidateTab_ArmorDefense(ItemTemplate) &&
		!ValidateTab_Grenades(ItemTemplate) &&
		!ValidateTab_Breach(ItemTemplate) &&
		!ValidateTab_Androids(ItemTemplate))
	{
		return true;
	}

	return false;
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	m_CurrentTab = -1
	m_bIsInventory = false; 
}
