//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIArmory_CompactLoadout
//  AUTHOR:  Joe Cortese
//  PURPOSE: UI for viewing and modifying a Soldiers equipment - added for DIO
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIArmory_CompactLoadout extends UIArmory
	dependson(UIArmory_Loadout);

var UIDIOHUD DioHUD;
var UIPanel EquippedListContainer;

var UIPanel LockerListContainer;
var UIList  LockerList;
var int		m_WeaponUpgradeSlotIndex;
var int		m_ArmorUpgradeSlotIndex;

var UIArmory_CompactLoadoutItem LockedContainerItem;
var int							SelectedItem;

var UIArmory_CompactLoadoutInfoPanel CompactInfoPanel;

var UIArmory_CompactLoadoutList WeaponList;
var UIArmory_CompactLoadoutList ArmorList;
var UIArmory_CompactLoadoutList BreachList;
var UIArmory_CompactLoadoutList UtilityList;
var array<UIArmory_CompactLoadoutList> AllLists;


var bool IsInSubmenu;

var UIArmory_CompactLoadoutItem EquippedSelection;
var UIArmory_CompactLoadoutItem TooltipSelectedItem;
//var StateObjectReference SelectedRef;
var X2WeaponUpgradeTemplate SelectedUpgradeTemplate;

var XGParamTag LocTag; // optimization
var bool bGearStripped;
var bool bItemsStripped;
var bool bComingFromSquadSelect;

simulated function InitArmory(StateObjectReference UnitRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	Movie.PreventCacheRecycling();

	super.InitArmory(UnitRef, DispEvent, SoldSpawnEvent, NavBackEvent, HideEvent, RemoveEvent, bInstant, InitCheckGameState);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

	IsInSubmenu = false;
	// mmg_john.hawley - mod slot indices need to be greater than 0 or it will select the wrong equipment slot. IE attempting to select the armor slot with armor index -1 will open the weapon mod slot
	m_WeaponUpgradeSlotIndex = 0;
	m_ArmorUpgradeSlotIndex = 0;

	MC.FunctionString("setLeftPanelTitle", class'UIArmory_MainMenu'.default.m_strLoadout);

	EquippedListContainer = Spawn(class'UIPanel', self);
	EquippedListContainer.bAnimateOnInit = false;
	//EquippedListContainer.bIsNavigable = false;
	EquippedListContainer.InitPanel('leftPanel');

	LockerListContainer = Spawn(class'UIPanel', self);
	LockerListContainer.bAnimateOnInit = false;
	//LockerListContainer.bIsNavigable = false;
	LockerListContainer.InitPanel('rightPanel');
	
	LockerList = CreateList(LockerListContainer);
	LockerList.OnSelectionChanged = OnSelectionChanged;
	LockerList.OnSetSelectedIndex = OnSelectionChanged;
	LockerList.OnItemClicked = OnItemClicked;
	LockerList.OnItemDoubleClicked = OnItemClicked;
	HideLockerList();

	CompactInfoPanel = Spawn(class'UIArmory_CompactLoadoutInfoPanel', self);
	CompactInfoPanel.InitLoadoutInfoPanel();
	CompactInfoPanel.Hide();
	
	RegisterForEvents();
	CreateLists();
}

simulated function CreateLists()
{
	local int i;
	local UIList TargetList;

	WeaponList = Spawn(class'UIArmory_CompactLoadoutList',	EquippedListContainer);
	ArmorList = Spawn(class'UIArmory_CompactLoadoutList',	EquippedListContainer);
	BreachList = Spawn(class'UIArmory_CompactLoadoutList',	EquippedListContainer);
	UtilityList = Spawn(class'UIArmory_CompactLoadoutList', EquippedListContainer);

	AllLists.AddItem(WeaponList);
	AllLists.AddItem(ArmorList);
	AllLists.AddItem(BreachList);
	AllLists.AddItem(UtilityList);

	for( i = 0; i < AllLists.length; i++ )
	{
		TargetList = AllLists[i]; 

		TargetList.OnItemSizeChangedFn = OnItemSizeChanged;
		TargetList.OnSetSelectedIndex = OnSelectionChanged;
		TargetList.OnItemClicked = OnItemClicked;
		TargetList.OnItemDoubleClicked = OnItemClicked;
	}

	InitializeLists();
	OnItemSizeChanged(WeaponList);
}

simulated function InitializeLists()
{
	//Note: Override in android upgrade class version of this screen. 

	WeaponList.InitLoadoutList(UnitReference, eInvSlot_PrimaryWeapon, 'section0');
	ArmorList.InitLoadoutList(UnitReference, eInvSlot_Armor, 'section1');
	BreachList.InitLoadoutList(UnitReference, eInvSlot_Breach, 'section3');
	UtilityList.InitLoadoutList(UnitReference, eInvSlot_Utility, 'section4');
}

simulated function PopulateData()
{
	if (!bComingFromSquadSelect)
	{
		CreateSoldierPawn();
	}
	UpdateEquippedList();
}

simulated function OnInit()
{
	super.OnInit();
	
	EquippedListContainer.ParentPanel = none;
	LockerListContainer.ParentPanel = none;
	PopulateData();
	Navigator.SelectFirstAvailable();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_UnitLoadoutChange_Submitted', OnLoadoutChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'WeaponUpgraded', OnLoadoutChanged, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_UnitLoadoutChange_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'WeaponUpgraded');
}

/*simulated function bool CanCancel()
{
	if (!Movie.Pres.ScreenStack.HasInstanceOf(class'UISquadSelect') ||
		class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T0_M5_EquipMedikit') != eObjectiveState_InProgress)
	{
		return true;
	}

	return false;
}*/

simulated function UpdateNavHelp()
{
	// bsg-jrebar (4/26/17): Armory UI consistency changes, centering buttons, fixing overlaps
	// Adding super class nav help calls to this class so help can be made vertical

	if(bUseNavHelp)
	{
		m_HUD.NavHelp.ClearButtonHelp();
		//m_HUD.NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
		m_HUD.NavHelp.bIsVerticalHelp = false; // mmg_john.hawley (11/7/19) - Updating NavHelp

		m_HUD.NavHelp.AddBackButton(OnCancel);
		m_HUD.NavHelp.AddSelectNavHelp();

		if (`ISCONTROLLERACTIVE)
		{
			if (EquippedSelection.ShouldShowClearButton())
			{
				m_HUD.NavHelp.AddLeftHelp(Caps(class'UIArmory_Loadout'.default.m_strMakeAvailable), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);
			}
			
			m_HUD.NavHelp.AddLeftHelp(Caps(class'UIArmory'.default.ChangeSoldierLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1);
			m_HUD.NavHelp.AddLeftHelp(Caps(class'UIManageEquipmentMenu'.default.m_strTitleLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LT_L2);
		}
		else
		{
			
			m_HUD.NavHelp.AddCenterHelp(class'UISquadSelect'.default.m_strStripItems, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $class'UIUtilities_Input'.const.ICON_LT_L2, OnStripItems, false, class'UIArmory_Loadout'.default.m_strTooltipStripItems, class'UIUtilities'.const.ANCHOR_BOTTOM_CENTER);
		}
	}
}

//This function handles Item-specific NavHelp, based on the currently selected item
/*simulated function UpdateNavHelp_LoadoutItem()
{
	local UIArmory_LoadoutItem Item;

	if(m_HUD.NavHelp != None && bUseNavHelp && EquippedList != None) // bsg-dforrest (7.15.16): null access warnings
	{
		Item = UIArmory_LoadoutItem(EquippedList.GetSelectedItem());
		if(Item != None && Item.bCanBeCleared)
		{
			m_HUD.NavHelp.AddLeftHelp(class'UIArmory_Loadout'.default.m_strMakeAvailable,class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);
		}
	}
}*/

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bInputConsumed;
	local UIArmory_CompactLoadoutList selectedList;

	// Only pay attention to presses or repeats; ignoring other input types
	// NOTE: Ensure repeats only occur with arrow keys
	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	//bsg-jedwards (3.21.17) : Set conditional to differ between console and PC for Manage Equipment Menu

	switch (cmd)
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER :
		case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER :
			return super.OnUnrealCommand(cmd, arg);
		break;

		case class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER :
			if (!bItemsStripped)
			{
				OnStripItems();
				bInputConsumed = true;
			}	
			break;

		case class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER :
			OnManageEquipmentPressed();
			bInputConsumed = true;
			break;

		case class'UIUtilities_Input'.const.FXS_BUTTON_X :
			PlayConfirmSound();
			if (EquippedSelection.ShouldShowClearButton())
			{
				EquippedSelection.OnDropItemClicked(EquippedSelection.DropItemButton);
				bInputConsumed = true;
			}
			break;

		case class'UIUtilities_Input'.const.FXS_BUTTON_A :
			PlayMouseClickSound();
			if (!IsInSubmenu)
			{
				selectedList = UIArmory_CompactLoadoutList(Navigator.GetSelected());
				ConfirmSelection(UIArmory_CompactLoadoutItem(selectedList.GetSelectedItem()), selectedList.SelectedIndex);
				bInputConsumed = true;
			}
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_B :
			PlayMouseClickSound();
			if (IsInSubmenu)
			{
				LockerList.ClearItems();
				LockerListContainer.Hide();
				UpdateEquippedList();

				selectedList = UIArmory_CompactLoadoutList(Navigator.GetSelected());
				selectedList.SetSelectedIndex(SelectedItem, true);

				IsInSubmenu = false;
			}
			else
			{
				CloseScreen();
			}
			bInputConsumed = true;
			break;
			
		case class'UIUtilities_Input'.const.FXS_DPAD_UP:
		case class'UIUtilities_Input'.const.FXS_DPAD_DOWN:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN:
		case class'UIUtilities_Input'.const.FXS_KEY_W:
		case class'UIUtilities_Input'.const.FXS_KEY_S:
		case class'UIUtilities_Input'.const.FXS_ARROW_UP:
		case class'UIUtilities_Input'.const.FXS_ARROW_DOWN:
			PlayMouseOverSound();
			bInputConsumed = false;
			break;

		default:
			bInputConsumed = false;
			break;
	}

	return bInputConsumed || super.OnUnrealCommand(cmd, arg);
}

simulated function PrevSoldier()
{
	local StateObjectReference NewUnitRef;
	if (!bComingFromSquadSelect)
	{
		if (class'UIUtilities_DioStrategy'.static.CycleSoldiers(-1, UnitReference, CanCycleTo, NewUnitRef))
			CycleToSoldier(NewUnitRef);
	}
	else
	{
		if (class'UIUtilities_DioStrategy'.static.CycleAPC(-1, UnitReference, CanCycleTo, NewUnitRef))
			CycleToSoldier(NewUnitRef);
	}
}

simulated function NextSoldier()
{
	local StateObjectReference NewUnitRef;
	if (!bComingFromSquadSelect)
	{
		if (class'UIUtilities_DioStrategy'.static.CycleSoldiers(1, UnitReference, CanCycleTo, NewUnitRef))
			CycleToSoldier(NewUnitRef);
	}
	else
	{
		if (class'UIUtilities_DioStrategy'.static.CycleAPC(1, UnitReference, CanCycleTo, NewUnitRef))
			CycleToSoldier(NewUnitRef);
	}
}

simulated function CloseScreen()
{
	super.CloseScreen();

	UnRegisterForEvents();

	// HELIOS BEGIN
	// Redirection to Presentation Base
	if (`SCREENSTACK.IsInStack(`PRESBASE.SquadSelect))
	{
		`SCREENSTACK.GetScreen(`PRESBASE.SquadSelect).OnReceiveFocus();
	}
	// HELIOS END
}

// override for custom behavior
simulated function OnAccept()
{
	local UIList selectedList;

	selectedList = UIList(Navigator.GetSelected());
	if (selectedList != none && selectedList.SelectedIndex >= 0)
	{
		OnItemClicked(selectedList, selectedList.SelectedIndex);
	}
}

//bsg-jedwards (3.21.17) : Function added to create the Manage Equipment Menu
simulated function OnManageEquipmentPressed()
{
	local UIManageEquipmentMenu TempScreen;
	local UISquadSelect SquadSelect;

	SquadSelect = UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect'));
	if(SquadSelect != none)
	{
		SquadSelect.OnManageEquipmentPressed();
	}
	else
	{
		TempScreen = Spawn(class'UIManageEquipmentMenu', Movie.Pres);
		TempScreen.AddItem(class'UISquadSelect'.default.m_strStripItems, OnStripItems);

		if(Movie != none)
		{
			Movie.Pres.ScreenStack.Push(TempScreen);
		}
		else
		{
			`SCREENSTACK.Push(TempScreen);
		}
	}
}

// Used when selecting utility items directly from Squad Select
simulated function SelectItemSlot(EInventorySlot ItemSlot, int ItemIndex)
{

}

simulated function SelectWeapon(EInventorySlot WeaponSlot)
{
	
}

simulated function OnStripItems()
{
	local TDialogueBoxData DialogData;

	PlayMouseClickSound();

	DialogData.eType = eDialog_Normal;
	DialogData.strTitle = class'UISquadSelect'.default.m_strStripItemsConfirm;
	DialogData.strText = class'UISquadSelect'.default.m_strStripItemsConfirmDesc;
	DialogData.fnCallback = OnStripItemsDialogCallback;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	
	Movie.Pres.UIRaiseDialog(DialogData);
}
simulated function OnStripItemsDialogCallback(Name eAction)
{
	local XComGameState_Unit UnitState;
	local array<EInventorySlot> RelevantSlots;
	local array<XComGameState_Unit> Soldiers;
	local XComGameState NewGameState;
	local XComGameState_Item UnitWeaponItem;
	local int idx;

	if(eAction == 'eUIAction_Accept')
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Strip Gear");
		Soldiers = GetSoldiersToStrip();

		RelevantSlots.AddItem(eInvSlot_Utility);
		RelevantSlots.AddItem(eInvSlot_GrenadePocket);
		RelevantSlots.AddItem(eInvSlot_AmmoPocket);
		RelevantSlots.AddItem(eInvSlot_Breach);
		RelevantSlots.AddItem(eInvSlot_ArmorMod);

		for(idx = 0; idx < Soldiers.Length; idx++)
		{
			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Soldiers[idx].ObjectID));
			// Remove weapon mods
			UnitWeaponItem = UnitState.GetPrimaryWeapon();
			UnitWeaponItem.ReturnWeaponUpgradesToHQ(NewGameState);
			// Remove inv items
			UnitState.MakeItemsAvailable(NewGameState, true, RelevantSlots);
		}

		`GAMERULES.SubmitGameState(NewGameState);

		bItemsStripped = true;
	}

	if (bItemsStripped)
	{
		UpdateData();
	}
	UpdateNavHelp();
}

simulated function ResetAvailableEquipment()
{
	bGearStripped = false;

	UpdateNavHelp();
}

simulated static function CycleToSoldier(StateObjectReference NewRef)
{
	local UIArmory_CompactLoadout LoadoutScreen;
	local UIArmory_AndroidUpgrades AndroidScreen;
	local UIScreenStack ScreenStack;
	local XComEventObject_EnterHeadquartersArea EnterAreaMessage;
	local int SlotIndex;
	
	ScreenStack = `SCREENSTACK;
	LoadoutScreen = UIArmory_CompactLoadout(ScreenStack.GetScreen(class'UIArmory_CompactLoadout'));
	if (LoadoutScreen != none)
	{
		LoadoutScreen.IsInSubmenu = false;
		LoadoutScreen.ResetAvailableEquipment();
		LoadoutScreen.WeaponList.UpdateUnitRef(NewRef);
		LoadoutScreen.ArmorList.UpdateUnitRef(NewRef);
		LoadoutScreen.BreachList.UpdateUnitRef(NewRef);
		LoadoutScreen.UtilityList.UpdateUnitRef(NewRef);
		LoadoutScreen.HideLockerList();
		LoadoutScreen.CompactInfoPanel.HideTooltip();
	}
	else
	{
		AndroidScreen = UIArmory_AndroidUpgrades(ScreenStack.GetScreen(class'UIArmory_AndroidUpgrades'));
		if (AndroidScreen != none)
		{
			AndroidScreen.IsInSubmenu = false;
			AndroidScreen.ResetAvailableEquipment();
			AndroidScreen.WeaponList.UpdateUnitRef(NewRef);
			AndroidScreen.ArmorList.UpdateUnitRef(NewRef);
			AndroidScreen.BreachList.UpdateUnitRef(NewRef);
			AndroidScreen.UtilityList.UpdateUnitRef(NewRef);
			AndroidScreen.HideLockerList();
			AndroidScreen.CompactInfoPanel.HideTooltip();
		}
	}

	if (!LoadoutScreen.bComingFromSquadSelect)
	{
		super.CycleToSoldier(NewRef);
	}
	else
	{
		EnterAreaMessage = new class'XComEventObject_EnterHeadquartersArea';
		for (SlotIndex = 0; SlotIndex < LoadoutScreen.DioHQ.APCRoster.Length; SlotIndex++)
		{
			if (LoadoutScreen.DioHQ.APCRoster[SlotIndex] == NewRef)
			{
				EnterAreaMessage.AreaTag = name("APC_0" $(SlotIndex + 1));
			}
		}

		for (SlotIndex = 0; SlotIndex < LoadoutScreen.DioHQ.Androids.Length; SlotIndex++)
		{
			if (LoadoutScreen.DioHQ.Androids[SlotIndex] == NewRef)
			{
				EnterAreaMessage.AreaTag = name("APC_0" $ (SlotIndex + 5));
			}
		}
		
		`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', EnterAreaMessage, LoadoutScreen, none);

		LoadoutScreen.SetUnitReference(NewRef);
		LoadoutScreen.PopulateData();

		LoadoutScreen.Header.UnitRef = NewRef;
		LoadoutScreen.Header.PopulateData(LoadoutScreen.GetUnit());
	}
}

simulated function array<XComGameState_Unit> GetSoldiersToStrip()
{
	local XComGameStateHistory History;
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit UnitState;
	local int idx;

	History = `XCOMHISTORY;
	
	for (idx = 0; idx < DioHQ.Squad.Length; idx++)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Squad[idx].ObjectID));
		if (DioHQ.APCRoster.Find('ObjectID', UnitState.ObjectID) == INDEX_NONE)
		{
			Soldiers.AddItem(UnitState);
		}
	}

	return Soldiers;
}

// also gets used by UIWeaponList, and UIArmory_WeaponUpgrade
simulated static function UIList CreateList(UIPanel Container)
{
	local UIList ReturnList;

	ReturnList = Container.Spawn(class'UIList', Container);
	ReturnList.bStickyHighlight = false;
	ReturnList.bAutosizeItems = false;
	ReturnList.bAnimateOnInit = false;
	ReturnList.bSelectFirstAvailable = false;
	ReturnList.ItemPadding = 5;
	ReturnList.InitList('loadoutList');

	return ReturnList;
}

simulated function UpdateEquippedList()
{
	local UIArmory_CompactLoadoutList selectedList;

	WeaponList.PopulateData();
	ArmorList.PopulateData();
	BreachList.PopulateData();
	UtilityList.PopulateData();

	Navigator = EquippedListContainer.Navigator;
	Navigator.SelectFirstAvailableIfNoCurrentSelection();
	selectedList = UIArmory_CompactLoadoutList(Navigator.GetSelected());
	if (SelectedItem < 0)
	{
		selectedList.SetSelectedIndex(0, true);
	}
	else
	{
		selectedList.SetSelectedIndex(SelectedItem, true);
	}

	RefreshAbilitySummary();
}

function int GetNumAllowedUtilityItems()
{
	// units can have multiple utility items
	return GetUnit().GetCurrentStat(eStat_UtilityItems);
}

simulated function UpdateLockerList(EInventorySlot slotEnum)
{
	local XComGameState_Item CurrrentSlotItem, Item, PrimaryWeapon;
	local array<XComGameState_Item> CurrentUtilityItems;
	local StateObjectReference ItemRef;
	local array<TUILockerItem> LockerItems;
	local TUILockerItem LockerItem, EmptyLockerItem;
	local XComGameState_StrategyInventory Inventory;
	local bool bStackItem, bDupeItem, bShow;
	local int i, NextWeaponUpgradeSlotIdx;
	local string DisabledReason;
	local UIArmory_CompactLoadoutItem loadoutItem;
		
	LockerItems.Length = 0;
	LockerListContainer.Show();

	// set title according to selected slot
	LocTag.StrValue0 = class'UIArmory_Loadout'.default.m_strInventoryLabels[slotEnum];
	MC.FunctionString("setRightPanelTitle", `XEXPAND.ExpandString(class'UIArmory_Loadout'.default.m_strLockerTitle));

	if (slotEnum == eInvSlot_Utility)
	{
		CurrentUtilityItems = GetUnit().GetAllItemsInSlot(slotEnum);
	}
	else
	{
		CurrrentSlotItem = GetUnit().GetItemInSlot(slotEnum);
	}

	GetInventory(Inventory);
	foreach Inventory.Items(ItemRef)
	{
		Item = GetItemFromHistory(ItemRef.ObjectID);

		// Don't show dupes of an item already in the slot(s)
		if (CurrrentSlotItem != none)
		{
			if (CurrrentSlotItem.GetMyTemplateName() == Item.GetMyTemplateName())
			{
				continue;
			}
		}
		else if (CurrentUtilityItems.Length > 0)
		{
			bDupeItem = false;
			foreach CurrentUtilityItems(CurrrentSlotItem)
			{
				if (CurrrentSlotItem.GetMyTemplateName() == Item.GetMyTemplateName())
				{
					bDupeItem = true;
					break;
				}
			}
			if (bDupeItem)
			{
				continue;
			}
		}

		// Try to stack before creating a new entry
		bStackItem = false;
		if (!Item.HasBeenModified())
		{
			for (i = 0; i < LockerItems.Length; ++i)
			{
				if (CanItemsStack(Item, LockerItems[i].Item))
				{
					LockerItems[i].Quantity++;
					bStackItem = true;
				}
			}
		}
		if (bStackItem)
		{
			continue;
		}

		if (ShowInLockerList(Item, slotEnum))
		{
			bShow = CheckShowDisabled(Item, slotEnum, DisabledReason);			
			if (bShow)
			{
				LockerItem = EmptyLockerItem; // Clear all data
				LockerItem.Item = Item;
				LockerItem.Quantity = 1;
				LockerItem.CanBeEquipped = LockerItem.DisabledReason == ""; // sorting optimization
				LockerItem.DisabledReason = DisabledReason;
				LockerItems.AddItem(LockerItem);
			}
		}
	}

	LockerList.ClearItems();

	LockerItems.Sort(SortLockerListByUpgrades);
	LockerItems.Sort(SortLockerListByTier);
	LockerItems.Sort(SortLockerListByEquip);

	ShowNoItemMessage(false);	
	
	if (LockerItems.Length == 0)
	{
		//loadoutItem = UIArmory_CompactLoadoutItem(LockerList.CreateItem(class'UIArmory_CompactLoadoutItem')).InitLoadoutItem(none, slotEnum, class'UIArmory_Loadout'.default.m_strNoItems);
		//loadoutItem.IsEmptyList = true;
		ShowNoItemMessage(true);
	}
	
	i = 0;
	PrimaryWeapon = GetUnit().GetPrimaryWeapon();
	foreach LockerItems(LockerItem)
	{
		if (slotEnum == eInvSlot_Unknown)
		{
			NextWeaponUpgradeSlotIdx = PrimaryWeapon.IncrementToNextReplaceableSlotIndex(m_WeaponUpgradeSlotIndex);
			loadoutItem = UIArmory_CompactLoadoutItem(LockerList.CreateItem(class'UIArmory_CompactLoadoutItem')).InitLoadoutWeaponUpgrade(X2WeaponUpgradeTemplate(LockerItem.Item.GetMyTemplate()), NextWeaponUpgradeSlotIdx, LockerItem.DisabledReason);
		}
		else
		{
			loadoutItem = UIArmory_CompactLoadoutItem(LockerList.CreateItem(class'UIArmory_CompactLoadoutItem')).InitLoadoutItem(LockerItem.Item, slotEnum, LockerItem.DisabledReason);
			loadoutItem.SlotIndex = i++;
		}

		loadoutItem.bLockerList = true;
	}
	
	RefreshAbilitySummary();

	Navigator = LockerListContainer.Navigator;
	Navigator.SelectFirstAvailable();
	
	OnSelectionChanged(LockerList, LockerList.SelectedIndex);
	
	RefreshSelectorFormatting(LockerItems.length, (LockedContainerItem != none ) ? string(LockedContainerItem.MCPath) : "");

}

function RefreshSelectorFormatting(int numItems, string selectedEquipmentPath)
{
	LockerListContainer.MC.BeginFunctionOp("RefreshFormatting");
	LockerListContainer.MC.QueueNumber(numItems);
	LockerListContainer.MC.QueueString(selectedEquipmentPath);
	LockerListContainer.MC.EndOp();
}

function ShowNoItemMessage(bool bShow)
{
	MC.FunctionString("setRightPanelMessage", bShow ? class'UIArmory_Loadout'.default.m_strNoItems : "");
}

function GetInventory(out XComGameState_StrategyInventory Inventory)
{
	Inventory = XComGameState_StrategyInventory(`XCOMHISTORY.GetGameStateForObjectID(DioHQ.Inventory.ObjectID));
}

simulated function bool ShowInLockerList(XComGameState_Item Item, EInventorySlot SelectedSlot)
{
	local X2ItemTemplate ItemTemplate;
	local X2GrenadeTemplate GrenadeTemplate;
	local X2EquipmentTemplate EquipmentTemplate;
	local X2WeaponUpgradeTemplate WeaponUpgradeTemplate;
	local XComGameState_Item equippedWeapon;

	ItemTemplate = Item.GetMyTemplate();
	
	if (ItemTemplate.HideInInventory)
	{
		return false;
	}

	switch(SelectedSlot)
	{
	case eInvSlot_PrimaryWeapon:
	case eInvSlot_SecondaryWeapon:
		if (GetUnit().CanSquadUnitEquipWeapon(Item) == false)
			return false;
		else
			break;
	case eInvSlot_Unknown:
		equippedWeapon = GetUnit().GetItemInSlot(eInvSlot_PrimaryWeapon);
		WeaponUpgradeTemplate = X2WeaponUpgradeTemplate(ItemTemplate);
		return WeaponUpgradeTemplate != none && !WeaponUpgradeTemplate.Universal && WeaponUpgradeTemplate.CanApplyUpgradeToWeapon(equippedWeapon);
	case eInvSlot_GrenadePocket:
		GrenadeTemplate = X2GrenadeTemplate(ItemTemplate);
		return GrenadeTemplate != none;
	case eInvSlot_AmmoPocket:
		return ItemTemplate.ItemCat == 'ammo';
	}

	EquipmentTemplate = X2EquipmentTemplate(ItemTemplate);
	// xpad is only item with size 0, that is always equipped
	return (EquipmentTemplate != none && EquipmentTemplate.iItemSize > 0 && EquipmentTemplate.InventorySlot == SelectedSlot);
}

simulated function bool CheckShowDisabled(XComGameState_Item Item, EInventorySlot SelectedSlot, optional out string DisabledReason)
{
	//local int EquippedObjectID;
	local X2ItemTemplate ItemTemplate;
	local X2AmmoTemplate AmmoTemplate;
	local X2WeaponTemplate WeaponTemplate;
	local X2ArmorTemplate ArmorTemplate;
	local X2SoldierClassTemplate SoldierClassTemplate, AllowedSoldierClassTemplate;
	local XComGameState_Unit UpdatedUnit;

	ItemTemplate = Item.GetMyTemplate();
	UpdatedUnit = GetUnit();
	SoldierClassTemplate = UpdatedUnit.GetSoldierClassTemplate();
	DisabledReason = "";

	// Disable if the item is excluded from the soldier class specifically
	if (SoldierClassTemplate != none && SoldierClassTemplate.ExcludedEquipment.Find(ItemTemplate.DataName) != INDEX_NONE)
	{
		DisabledReason = `MAKECAPS(class'UIArmory_Loadout'.default.m_strUnavailableDefault);
		return true;
	}

	// Disable the weapon cannot be equipped by the current soldier class
	WeaponTemplate = X2WeaponTemplate(ItemTemplate);
	if (WeaponTemplate != none)
	{
		if(SoldierClassTemplate != none && !SoldierClassTemplate.IsWeaponAllowedByClass(WeaponTemplate))
		{
			AllowedSoldierClassTemplate = class'UIUtilities_Strategy'.static.GetAllowedClassForWeapon(WeaponTemplate);
			if(AllowedSoldierClassTemplate == none)
			{
				DisabledReason = class'UIArmory_Loadout'.default.m_strMissingAllowedClass;
			}
			else if(AllowedSoldierClassTemplate.DataName == class'X2SoldierClassTemplateManager'.default.DefaultSoldierClass)
			{
				LocTag.StrValue0 = SoldierClassTemplate.DisplayName;
				DisabledReason = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(`XEXPAND.ExpandString(class'UIArmory_Loadout'.default.m_strUnavailableToClass));
			}
			else
			{
				LocTag.StrValue0 = AllowedSoldierClassTemplate.DisplayName;
				DisabledReason = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(`XEXPAND.ExpandString(class'UIArmory_Loadout'.default.m_strNeedsSoldierClass));
			}
		}
	}

	ArmorTemplate = X2ArmorTemplate(ItemTemplate);
	if (ArmorTemplate != none)
	{
		SoldierClassTemplate = UpdatedUnit.GetSoldierClassTemplate();
		if (SoldierClassTemplate != none && !SoldierClassTemplate.IsArmorAllowedByClass(ArmorTemplate))
		{
			AllowedSoldierClassTemplate = class'UIUtilities_Strategy'.static.GetAllowedClassForArmor(ArmorTemplate);
			if (AllowedSoldierClassTemplate == none)
			{
				DisabledReason = class'UIArmory_Loadout'.default.m_strMissingAllowedClass;
			}
			else if (AllowedSoldierClassTemplate.DataName == class'X2SoldierClassTemplateManager'.default.DefaultSoldierClass)
			{
				LocTag.StrValue0 = SoldierClassTemplate.DisplayName;
				DisabledReason = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(`XEXPAND.ExpandString(class'UIArmory_Loadout'.default.m_strUnavailableToClass));
			}
			else
			{
				LocTag.StrValue0 = AllowedSoldierClassTemplate.DisplayName;
				DisabledReason = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(`XEXPAND.ExpandString(class'UIArmory_Loadout'.default.m_strNeedsSoldierClass));
			}
		}
	}

	// Disable if the ammo is incompatible with the current primary weapon
	AmmoTemplate = X2AmmoTemplate(ItemTemplate);
	if(AmmoTemplate != none)
	{
		WeaponTemplate = X2WeaponTemplate(UpdatedUnit.GetItemInSlot(eInvSlot_PrimaryWeapon, CheckGameState).GetMyTemplate());
		if (WeaponTemplate != none && !X2AmmoTemplate(ItemTemplate).IsWeaponValidForAmmo(WeaponTemplate))
		{
			LocTag.StrValue0 = UpdatedUnit.GetPrimaryWeapon().GetMyTemplate().GetItemFriendlyName();
			DisabledReason = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(`XEXPAND.ExpandString(class'UIArmory_Loadout'.default.m_strAmmoIncompatible));
		}
	}

	// If this is a utility item, and cannot be equipped, it must be disabled because of one item per category restriction
	/*if(DisabledReason == "" && SelectedSlot == eInvSlot_Utility)
	{
		EquippedObjectID = UIArmory_LoadoutItem(EquippedList.GetSelectedItem()).ItemRef.ObjectID;
		if(!UpdatedUnit.RespectsUniqueRule(ItemTemplate, SelectedSlot, , EquippedObjectID))
		{
			LocTag.StrValue0 = ItemTemplate.GetLocalizedCategory();
			DisabledReason = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(`XEXPAND.ExpandString(m_strCategoryRestricted));
		}
	}*/
	
	return DisabledReason == "";
}

simulated function int SortLockerListByEquip(TUILockerItem A, TUILockerItem B)
{
	if (A.CanBeEquipped && !B.CanBeEquipped) return 1;
	else if (!A.CanBeEquipped && B.CanBeEquipped) return -1;
	else return 0;
}

simulated function int SortLockerListByTier(TUILockerItem A, TUILockerItem B)
{
	local int TierA, TierB;

	TierA = A.Item.GetMyTemplate().Tier;
	TierB = B.Item.GetMyTemplate().Tier;

	if (TierA > TierB) return 1;
	else if (TierA < TierB) return -1;
	else return 0;
}

simulated function int SortLockerListByUpgrades(TUILockerItem A, TUILockerItem B)
{
	local int UpgradesA, UpgradesB;

	UpgradesA = A.Item.GetMyWeaponUpgradeTemplates().Length;
	UpgradesB = B.Item.GetMyWeaponUpgradeTemplates().Length;

	if (UpgradesA > UpgradesB)
	{
		return 1;
	}
	else if (UpgradesA < UpgradesB)
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

simulated function OnSelectionChanged(UIList ContainerList, int ItemIndex)
{
	local UIArmory_CompactLoadoutItem ContainerSelection;
	local StateObjectReference EmptyRef, ContainerRef, EquippedRef;
	local UIArmory_CompactLoadoutList EquippedList;

	SelectedUpgradeTemplate = none;
	EquippedList = GetEquippedList(UIArmory_CompactLoadoutList(ContainerList).listSlot);

	ContainerSelection = UIArmory_CompactLoadoutItem(ContainerList.GetSelectedItem());
	EquippedSelection = UIArmory_CompactLoadoutItem(EquippedList.GetSelectedItem());

	ContainerRef = ContainerSelection != none ? ContainerSelection.ItemRef : EmptyRef;
	EquippedRef = EquippedSelection != none ? EquippedSelection.ItemRef : EmptyRef;

	TooltipSelectedItem = ContainerSelection;

	//SelectedRef = ContainerRef;

	//if (SelectedRef.ObjectID == 0)
	//{
	//	SelectedUpgradeTemplate = ContainerSelection.UpgradeTemplate;
	//}

	if ((ContainerSelection != none) && !ContainerSelection.IsDisabled)
	{
		Header.PopulateData(GetUnit(), ContainerRef, EquippedRef);
	}

	CompactInfoPanel.HideTooltip();
	if (`ISCONTROLLERACTIVE)
	{
		ClearTimer(nameof(DelayedShowTooltip));
		SetTimer(0.21f, false, nameof(DelayedShowTooltip));
	}
	else
	{
		DelayedShowTooltip();
	}
	UpdateNavHelp();
}

simulated function UIArmory_CompactLoadoutList GetEquippedList(EInventorySlot slotEnum)
{
	if (slotEnum == WeaponList.listSlot)
		return WeaponList;
	if (slotEnum == ArmorList.listSlot)
		return ArmorList;

	if (slotEnum == BreachList.listSlot)
		return BreachList;
	if (slotEnum == UtilityList.listSlot)
		return UtilityList;

	return none; 
}

simulated function DelayedShowTooltip()
{
	if (TooltipSelectedItem != none)
	{
		CompactInfoPanel.PopulateLoadoutItemData(TooltipSelectedItem);
	}

}

simulated function OnItemClicked(UIList ContainerList, int ItemIndex)
{
	local UIArmory_CompactLoadoutItem ContainerItem;

	ContainerItem = UIArmory_CompactLoadoutItem(ContainerList.GetItem(ItemIndex));
	ClearAllLocked();
	LockedContainerItem = none;  
	SelectedItem = -1;

	if(ContainerItem.IsDisabled)
	{
		PlayNegativeMouseClickSound();
		if (ContainerItem.IsEmptyList)
		{
			HideLockerList();
			UpdateEquippedList();
		}
		return;
	}

	PlayMouseClickSound();

	if(LockerList == ContainerList)
	{
		EquipItem(UIArmory_CompactLoadoutItem(LockerList.GetSelectedItem()));
	}
	else
	{
		if (ContainerList == WeaponList)
		{
			m_WeaponUpgradeSlotIndex = ContainerItem.SlotIndex;
		}
		ContainerItem.AS_SetLocked(true);
		LockedContainerItem = ContainerItem; 
		SelectedItem = ItemIndex;
		UpdateLockerList(ContainerItem.EquipmentSlot);
	}
}

simulated function bool SelectItemCategory(UIList ContainerList, int ItemIndex)
{
	local UIArmory_CompactLoadoutItem ContainerItem;

	ContainerItem = UIArmory_CompactLoadoutItem(ContainerList.GetItem(ItemIndex));

	// Check if the loadout button we are trying to select exists. Some need to be unlocked
	if (!ContainerItem.bIsVisible)
	{
		return false;
	}

	ClearAllLocked();
	LockedContainerItem = none;
	SelectedItem = -1;

	if (ContainerItem.IsDisabled)
	{
		`SOUNDMGR.PlaySoundEvent(m_NegativeMouseClickSound);
		if (ContainerItem.IsEmptyList)
		{
			HideLockerList();
			UpdateEquippedList();
		}
		return false;
	}

	// TODO mmg_john.hawley Insert correct SFX
	ContainerItem.AS_SetLocked(true);
	LockedContainerItem = ContainerItem;
	SelectedItem = ItemIndex;

	return true;
}

function ConfirmSelection(UIArmory_CompactLoadoutItem ContainerItem, optional int SelectionIndex = -1)
{
	if (ContainerItem.EquipmentSlot == eInvSlot_Unknown)
	{
		m_WeaponUpgradeSlotIndex = ContainerItem.SlotIndex;
	}
	else if (ContainerItem.EquipmentSlot == eInvSlot_ArmorMod)
	{
		m_ArmorUpgradeSlotIndex = ContainerItem.SlotIndex;
	}
	LockedContainerItem = ContainerItem;
	SelectedItem = SelectionIndex;
	UpdateLockerList(ContainerItem.EquipmentSlot);
	`SOUNDMGR.PlayLoadedAkEvent(m_MouseClickSound, self);
	IsInSubmenu = true;
}

function OnItemSizeChanged(UIList List)
{
	local UIList TargetList; 
	local int i, currentY; 

	currentY = 110; // SItting on the stage in flash.  

	for( i = 0; i < AllLists.length; i++ )
	{
		TargetList = AllLists[i];
		TargetList.SetY(currentY);
		currentY += TargetList.GetTotalHeight();
	}
}

function ClearAllLocked()
{
	local int i; 

	for( i = 0; i < AllLists.length; i++ )
	{
		AllLists[i].ClearLocked();
	}
}

simulated function HideLockerList()
{
	LockerListContainer.Hide();
}

simulated function UpdateData(optional bool bRefreshPawn)
{
	UpdateEquippedList();

	Header.PopulateData(GetUnit());
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	if( `ISCONTROLLERACTIVE )
	{
		DelayedShowTooltip();
	}

	super.OnReceiveFocus();
	Movie.PreventCacheRecycling();
}

simulated function SetUnitReference(StateObjectReference NewUnit)
{
	super.SetUnitReference(NewUnit);
	MC.FunctionVoid("animateIn");
}

simulated function RefreshAbilitySummary()
{
	local XComGameState_Unit Unit; 

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
	class'UIUtilities_Strategy'.static.PopulateAbilitySummary(self, Unit, true);
}

//==============================================================================
simulated function bool EquipItem(UIArmory_CompactLoadoutItem Item)
{
	local X2StrategyGameRuleset StratRules;
	local XComGameStateContext_ChangeContainer ChangeContainer;
	local XComGameState_StrategyInventory stratInventory;
	local XComGameState ChangeState;
	local XComGameState_Item Weapon, weaponMod, UpgradeItem;
	local X2WeaponUpgradeTemplate OldUpgradeTemplate;
	local array<X2WeaponUpgradeTemplate> RemovedExclusiveUpgrades;
	local int i;
	local XComGameState_Unit UnitState;
	local XComUnitPawnNativeBase UnitPawn;

	StratRules = `STRATEGYRULES;
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
	if (Item.EquipmentSlot == eInvSlot_Unknown)
	{
		ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Weapon Upgrade");
		ChangeState = `XCOMHISTORY.CreateNewGameState(true, ChangeContainer);
		stratInventory = XComGameState_StrategyInventory(`XCOMHISTORY.GetGameStateForObjectID(`DIOHQ.Inventory.ObjectID));

		weaponMod = stratInventory.RemoveItemByTemplate(ChangeState, Item.UpgradeTemplate);

		Weapon = XComGameState_Item(ChangeState.ModifyStateObject(class'XComGameState_Item', GetUnit().GetItemInSlot(eInvSlot_PrimaryWeapon).ObjectID));
		
		// Remove upgrade in the same slot and return to HQ inventory
		OldUpgradeTemplate = Weapon.DeleteWeaponUpgradeTemplate(m_WeaponUpgradeSlotIndex);
		if (OldUpgradeTemplate != none)
		{
			UpgradeItem = OldUpgradeTemplate.CreateInstanceFromTemplate(ChangeState);
			DioHQ.PutItemInInventory(ChangeState, UpgradeItem);
		}

		// Remove all mutually-exclusive upgrades and return them as well
		Weapon.RemoveMutuallyExclusiveWeaponUpgrades(Item.UpgradeTemplate, RemovedExclusiveUpgrades);
		for (i = 0; i < RemovedExclusiveUpgrades.Length; ++i)
		{
			UpgradeItem = RemovedExclusiveUpgrades[i].CreateInstanceFromTemplate(ChangeState);
			DioHQ.PutItemInInventory(ChangeState, UpgradeItem);
		}
		
		// Apply upgrade to weapon
		Weapon.ApplyWeaponUpgradeTemplate(Item.UpgradeTemplate, m_WeaponUpgradeSlotIndex);

		`XEVENTMGR.TriggerEvent('WeaponUpgraded', Weapon, weaponMod, ChangeState);
		`GAMERULES.SubmitGameState(ChangeState);
		`XSTRATEGYSOUNDMGR.PlaySoundEvent(Item.UpgradeTemplate.EquipSound);

		`XEVENTMGR.TriggerEvent('STRATEGY_UnitLoadoutChange_Submitted', UnitState, Item, ChangeState);
	}
	else
	{
		StratRules.SubmitLoadoutChange(GetUnitRef(), Item.ItemRef);
		`XSTRATEGYSOUNDMGR.PlaySoundEvent(X2EquipmentTemplate(Item.ItemTemplate).EquipSound);
		
		// GetPawnFromPawnMgr will take care of creating/updating InventoryAttachments
		StratRules.CrewMgr.GetPawnFromPawnMgr(UnitState, UnitPawn, UnitPawn); 
	}
	
	return true;
}

simulated function XComGameState_Item GetEquippedItem(EInventorySlot eSlot)
{
	return GetUnit().GetItemInSlot(eSlot, CheckGameState);
}

simulated function EInventorySlot GetSelectedSlot()
{
	/*local UIArmory_LoadoutItem Item;

	Item = UIArmory_CompactLoadoutItem(EquippedList.GetSelectedItem());

	return Item != none ? Item.EquipmentSlot : eInvSlot_Unknown;*/
	return eInvSlot_Unknown;
}

function bool GetItemFromInventory(XComGameState AddToGameState, StateObjectReference ItemRef, out XComGameState_Item ItemState)
{
	return class'UIUtilities_Strategy'.static.GetXComHQ().GetItemFromInventory(AddToGameState, ItemRef, ItemState);
}

function XComGameState_Item GetItemFromHistory(int ObjectID)
{
	return XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ObjectID));
}

function XComGameState_Unit GetUnitFromHistory(int ObjectID)
{
	return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ObjectID));
}

function bool CanItemsStack(XComGameState_Item ItemA, XComGameState_Item ItemB)
{
	if (ItemA.GetMyTemplateName() != ItemB.GetMyTemplateName())
	{
		return false;
	}

	if (ItemA.HasBeenModified() || ItemB.HasBeenModified())
	{
		return false;
	}

	return true;
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	Movie.AllowCacheRecycling();
}

event Destroyed()
{
	Movie.AllowCacheRecycling();
	super.Destroyed();
}

// override for custom behavior
simulated function OnCancel()
{
	if (LockerListContainer.bIsVisible)
	{
		HideLockerList();
		UpdateEquippedList();
	}
	else
	{
		super.OnCancel();
	}
}

//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------

function EventListenerReturn OnLoadoutChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	HideLockerList();
	UpdateEquippedList();
	UpdateData(true);
	UpdateNavHelp();

	return ELR_NoInterrupt;
}

//==============================================================================

defaultproperties
{
	LibID = "CompactLoadoutScreen";
	bComingFromSquadSelect = false;
	bAutoSelectFirstNavigable = false;
	bHideOnLoseFocus = false;
}