//---------------------------------------------------------------------------------------
//  FILE:    	XComGameStateContext_StrategyEquipItem
//  AUTHOR:  	dmcdonough  --  2/7/2019
//  PURPOSE: 	Context for assigning an item to a squad unit.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameStateContext_StrategyEquipItem extends XComGameStateContext;

var() StateObjectReference UnitRef;
var() StateObjectReference ItemRef;
var() EInventorySlot InventorySlot;

//---------------------------------------------------------------------------------------
//				GameState Interface
//---------------------------------------------------------------------------------------
function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

//---------------------------------------------------------------------------------------
function XComGameState ContextBuildGameState()
{
	local XComGameStateHistory History;
	local X2EventManager EventManager;
	local XComGameState_StrategyInventory HQInventory;
	local XComGameState_Unit Unit;
	local XComGameState_Item Item, PrevItem, UpgradeItem;
	local array<XComGameState_Item> PrevItems;
	local array<X2WeaponUpgradeTemplate> PrevItemUpgrades;
	local XComGameState NewGameState;
	local X2ItemTemplateManager ItemTemplateManager;
	local X2ItemTemplate ItemTemplate;
	local X2EquipmentTemplate EquipmentTemplate;
	local bool bEquipSucceeded;
	local int i, SlotMax, SlotsToClear;

	EventManager = `XEVENTMGR;
	History = `XCOMHISTORY;
	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	NewGameState = History.CreateNewGameState(true, self);
	Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
	Item = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ItemRef.ObjectID));
	ItemTemplate = Item.GetMyTemplate();
	HQInventory = XComGameState_StrategyInventory(NewGameState.ModifyStateObject(class'XComGameState_StrategyInventory', `DIOHQ.Inventory.ObjectID));
	EquipmentTemplate = X2EquipmentTemplate(Item.GetMyTemplate());

	if (InventorySlot == eInvSlot_Unknown)
	{
		InventorySlot = EquipmentTemplate != none ? EquipmentTemplate.InventorySlot : Item.InventorySlot;
	}
	if (InventorySlot == eInvSlot_Utility)
	{
		SlotMax = Unit.GetCurrentStat(eStat_UtilityItems);
	}
	else
	{
		SlotMax = 1;
	}

	PrevItems = class'UIUtilities_Strategy'.static.GetEquippedItemsInSlot(Unit, InventorySlot, NewGameState);

	// This item is a unique equip? Remove all items of the same category	
	if (ItemTemplateManager.ItemCategoryIsUniqueEquip(ItemTemplate.ItemCat))
	{
		for (i = PrevItems.Length - 1; i >= 0; i--)
		{
			if (PrevItems[i].GetMyTemplate().ItemCat == ItemTemplate.ItemCat)
			{
				Unit.RemoveItemFromInventory(PrevItems[i], NewGameState);
				HQInventory.AddItem(NewGameState, PrevItems[i].GetReference());
				PrevItems.Remove(i, 1);
			}
		}
	}

	// Get max items in the slot
	SlotsToClear = (PrevItems.Length + 1) - SlotMax;
	// If more items are in this slot then allowed, remove items starting with the oldest
	if (SlotsToClear > 0)
	{
		for (i = 0; i < SlotsToClear; ++i)
		{
			PrevItem = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', PrevItems[PrevItems.Length - 1].ObjectID));

			// Weapon: cache prev weapon's upgrades to re-apply
			if (InventorySlot == eInvSlot_PrimaryWeapon)
			{
				PrevItemUpgrades = PrevItem.GetMyWeaponUpgradeTemplates();
			}
			PrevItem.WipeUpgradeTemplates();

			Unit.RemoveItemFromInventory(PrevItem, NewGameState);
			HQInventory.AddItem(NewGameState, PrevItem.GetReference());
		}
	}

	// Quantity > 1? Split off into new item
	// Start HELIOS Issue #??
	// This code cannot handle custom weapon quantities so the following either happens:
	// 1) It would end up in a void somewhere and cannot be retrieved again
	// 2) Duplicate the item as a separate enitity (Duplication Glitch found by Grobobobo)
	//
	// So we must remove the Primary Weapon check so it properly stacks back, with exceptions to Linked Primaries.
	//
	// Only Linked Primary weapons should be except from this check instead of a blanket check on any primary weapon. 
	// Other primary weapons should stack back into the inventory
	//
	if (Item.Quantity > 1 && Item.LinkedEntity.ObjectID == 0)
	{
		Item = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
		Item.Quantity = 1;
	}

	// Re-apply upgrades to weapon (if applicable)
	if (InventorySlot == eInvSlot_PrimaryWeapon && PrevItemUpgrades.Length > 0)
	{
		for (i = 0; i < PrevItemUpgrades.Length; ++i)
		{
			if (PrevItemUpgrades[i] == none)
			{
				continue;
			}

			if (PrevItemUpgrades[i].CanApplyUpgradeToWeapon(Item))
			{
				Item.ApplyWeaponUpgradeTemplate(PrevItemUpgrades[i]);
			}
			else
			{
				UpgradeItem = PrevItemUpgrades[i].CreateInstanceFromTemplate(NewGameState);
				HQInventory.AddItem(NewGameState, UpgradeItem.GetReference());
			}
		}
	}

	// Add new item to unit
	bEquipSucceeded = Unit.AddItemToInventory(Item, InventorySlot, NewGameState, true);
	if (bEquipSucceeded)
	{
		// Remove item from HQ if equip succeeded		
		HQInventory.RemoveItem(NewGameState, ItemRef);
		EventManager.TriggerEvent('STRATEGY_UnitLoadoutChange_Submitted', Unit, Item, NewGameState);
	}

	return NewGameState;
}

//---------------------------------------------------------------------------------------
protected function ContextBuildVisualization()
{
}

//---------------------------------------------------------------------------------------
function string SummaryString()
{
	return "XComGameStateContext_StrategyEquipItem";
}
