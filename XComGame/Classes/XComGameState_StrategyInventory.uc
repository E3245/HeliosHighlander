//---------------------------------------------------------------------------------------
//  FILE:    	XComGameState_StrategyInventory
//  AUTHOR:  	dmcdonough  --  10/24/2018
//  PURPOSE: 	Instance data for the collection of Items held by a strategy-layer entity
//				such as the HQ or a Vendor.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameState_StrategyInventory extends XComGameState_BaseObject
	native(Core);

var() privatewrite array<StateObjectReference> Items; // Stores all XComGameState_Item refs.

//---------------------------------------------------------------------------------------
simulated function XComGameState_Item GetItemAtIndex(int Index, optional XComGameState ModifyGameState)
{
	local XComGameState_BaseObject InvObject;

	if (Index < 0 || Index >= Items.Length)
	{
		return none;
	}

	if (Items[Index].ObjectID <= 0)
	{
		return none;
	}

	InvObject = `XCOMHISTORY.GetGameStateForObjectID(Items[Index].ObjectID);
	if (InvObject == none)
	{
		return none;
	}

	if (ClassIsChildOf(InvObject.Class, class'XComGameState_Item'))
	{
		if (ModifyGameState != none)
		{
			return XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', Items[Index].ObjectID));
		}
		return XComGameState_Item(InvObject);
	}

	return none;
}

//---------------------------------------------------------------------------------------
simulated function XComGameState_Item AddItem(XComGameState ModifyGameState, StateObjectReference ItemRef)
{
	local XComGameState_HeadquartersDio DioHQ;
	local X2ItemTemplate UpgradedItemTemplate;
	local XComGameState_Item Item, CurItem;
	local X2ItemTemplate ItemTemplate;
	local X2WeaponTemplate WeaponTemplate;
	local XComGameState_StrategyInventory Inventory;
	local bool bPrimaryWeapon;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));
	Inventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', ObjectID));
	Item = XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', ItemRef.ObjectID));

	// If this item has an unlocked upgrade, replace it here	
	UpgradedItemTemplate = Item.GetMyTemplate();
	DioHQ.GetUpgradedItemTemplate(UpgradedItemTemplate);
	if (UpgradedItemTemplate != Item.GetMyTemplate())
	{
		ModifyGameState.RemoveStateObject(Item.ObjectID);
		Item = UpgradedItemTemplate.CreateInstanceFromTemplate(ModifyGameState);
	}

	ItemTemplate = Item.GetMyTemplate();
	// If Item has On Acquired override that returns false, that means it shouldn't be added to the inventory after all
	if (ItemTemplate.OnAcquiredFn != None)
	{
		// Item indicates it should not be kept
		if (!ItemTemplate.OnAcquiredFn(ModifyGameState, Item))
		{
			return none;
		}
	}

	// Weapons: check for upgrades, place without stacking
	WeaponTemplate = X2WeaponTemplate(ItemTemplate);
	if (WeaponTemplate != none && WeaponTemplate.InventorySlot == eInvSlot_PrimaryWeapon)
	{
		bPrimaryWeapon = true;
	}

	//
	// Non-weapons: Stack up with any existing item found
	// Start HELIOS Issue #??
	// This code cannot handle custom weapon quantities so the following either happens:
	// 1) It would end up in a void somewhere and cannot be retrieved again
	// 2) Duplicate the item as a separate enitity (Duplication Glitch found by Grobobobo)
	//
	// So we must remove the Primary Weapon check and replace it with a check if it's a linked weapon
	//
	CurItem = Inventory.GetFirstItemByName(ItemTemplate.DataName, ModifyGameState);
	if (CurItem != none && CurItem.LinkedEntity.ObjectID == 0)
	{
		CurItem.Quantity += Item.Quantity;
		ModifyGameState.RemoveStateObject(Item.ObjectID);
		`XEVENTMGR.TriggerEvent('InventoryItemQuantityChanged', CurItem, Inventory, ModifyGameState);
	}
	// This is a new item or a linked instance of the same item
	else
	{
		// First time acquiring an item of this template
		Inventory.Items.AddItem(Item.GetReference());

		// Apply any owned universal upgrades
		DioHQ.ApplyUniversalUpgradesToItem(Item.GetReference(), ModifyGameState);

		// If this item is *itself* an upgrade, refresh upgrades all all owned items
		if (ItemTemplate.ItemCat == 'upgrade')
		{
			DioHQ.RefreshAllUpgradedItems(ModifyGameState);
		}

		`XEVENTMGR.TriggerEvent('InventoryItemAdded', Item, Inventory, ModifyGameState);
	}
	// End HELIOS Issue #??

	return Item;
}

//---------------------------------------------------------------------------------------
simulated function XComGameState_Item AddItemByName(XComGameState ModifyGameState, name TemplateName, optional int Quantity = 1)
{
	local X2ItemTemplate ItemTemplate;

	ItemTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate(TemplateName);
	if (ItemTemplate != none && Quantity > 0)
	{
		return AddItemByTemplate(ModifyGameState, ItemTemplate, Quantity);
	}
}

//---------------------------------------------------------------------------------------
// Given an Item template, create an Item object and add Quantity of it to the inventory
simulated function XComGameState_Item AddItemByTemplate(XComGameState ModifyGameState, X2ItemTemplate ItemTemplate, optional int Quantity = 1)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Item Item;

	DioHQ = XComGameState_HeadquartersDio(ModifyGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));

	// Ensure min
	Quantity = Max(Quantity, 1);

	// Check/replace the item template with its upgrade, if any
	DioHQ.GetUpgradedItemTemplate(ItemTemplate);

	Item = ItemTemplate.CreateInstanceFromTemplate(ModifyGameState);
	Item.Quantity = Quantity;

	return AddItem(ModifyGameState, Item.GetReference());
}

//---------------------------------------------------------------------------------------
simulated function AddLootDataItem(XComGameState ModifyGameState, LootData InLootData)
{
	local X2ItemTemplate ItemTemplate;
	
	if (InLootData.ItemTemplateName != '' && InLootData.Quantity > 0)
	{
		ItemTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate(InLootData.ItemTemplateName);
		if (ItemTemplate != none)
		{
			AddItemByTemplate(ModifyGameState, ItemTemplate, InLootData.Quantity);
		}
	}
}

//---------------------------------------------------------------------------------------
simulated function RemoveItem(XComGameState ModifyGameState, StateObjectReference ItemRef)
{
	local XComGameState_Item Item;
	local XComGameState_StrategyInventory Inventory;
	
	Item = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ItemRef.ObjectID));

	// If quantity would be reduced to zero by this change, remove the item entirely
	if (Item.Quantity <= 1)
	{
		Inventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', ObjectID));
		Inventory.Items.RemoveItem(ItemRef);
		`XEVENTMGR.TriggerEvent('InventoryItemRemoved', Item, Inventory, ModifyGameState);
	}
	else
	{
		Item = XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', ItemRef.ObjectID));
		Item.Quantity -= 1;
		`XEVENTMGR.TriggerEvent('InventoryItemQuantityChanged', Item, Inventory, ModifyGameState);
	}
}

//---------------------------------------------------------------------------------------
simulated function RemoveItemAtIndex(XComGameState ModifyGameState, int ItemIndex)
{
	local XComGameState_StrategyInventory Inventory;

	Inventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', ObjectID));
	if (ItemIndex >= 0 && ItemIndex < Inventory.Items.Length)
	{
		Inventory.Items.Remove(ItemIndex, 1);
	}
}

//---------------------------------------------------------------------------------------
simulated function RemoveItemByName(XComGameState ModifyGameState, name TemplateName, optional int Quantity = 1)
{
	local X2ItemTemplate ItemTemplate;

	ItemTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate(TemplateName);
	if (ItemTemplate != none && Quantity > 0)
	{
		RemoveItemByTemplate(ModifyGameState, ItemTemplate, Quantity);
	}
}

//---------------------------------------------------------------------------------------
simulated function XComGameState_Item RemoveItemByTemplate(XComGameState ModifyGameState, X2ItemTemplate ItemTemplate, optional int Quantity = 1, optional bool RemoveAll = false)
{
	local XComGameStateHistory History;
	local XComGameState_Item Item;
	local XComGameState_StrategyInventory Inventory;
	local int i;

	// Early outs
	if (Quantity <= 0 && RemoveAll == false)
		return None;

	History = `XCOMHISTORY;
	Inventory = XComGameState_StrategyInventory(ModifyGameState.ModifyStateObject(class'XComGameState_StrategyInventory', ObjectID));

	for (i = 0; i < Items.Length; ++i)
	{
		Item = XComGameState_Item(History.GetGameStateForObjectID(Items[i].ObjectID));
		if (Item.GetMyTemplateName() == ItemTemplate.DataName)
		{
			// Remove all
			if (Quantity >= Item.Quantity || RemoveAll)
			{
				Inventory.Items.Remove(i, 1);
				`XEVENTMGR.TriggerEvent('InventoryItemRemoved', Item, Inventory, ModifyGameState);
			}
			else
			{
				Item = XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', Item.ObjectID));
				Item.Quantity -= Quantity;
				`XEVENTMGR.TriggerEvent('InventoryItemQuantityChanged', Item, Inventory, ModifyGameState);
			}
			return Item;
		}
	}

	return None;
}

//---------------------------------------------------------------------------------------
simulated function bool HasItem(X2ItemTemplate ItemTemplate, optional int Quantity = 1, optional XComGameState ModifyGameState)
{
	local XComGameState_Item InvItem;
	local int i;

	for (i = 0; i < Items.Length; i++)
	{
		InvItem = GetItemAtIndex(i, ModifyGameState);
		if (InvItem != none)
		{
			if (InvItem.GetMyTemplateName() == ItemTemplate.DataName && InvItem.Quantity >= Quantity)
			{
				return true;
			}
		}
	}

	return false;
}

//---------------------------------------------------------------------------------------
simulated function bool HasItemByName(name ItemTemplateName)
{
	local X2ItemTemplate ItemTemplate;

	ItemTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate(ItemTemplateName);

	if (ItemTemplate != none)
	{
		return HasItem(ItemTemplate);
	}

	return false;
}

//---------------------------------------------------------------------------------------
simulated function XComGameState_Item GetFirstItemByName(name ItemTemplateName, optional XComGameState ModifyGameState)
{
	local XComGameState_Item InvItem;
	local int i;

	for (i = 0; i < Items.Length; i++)
	{
		InvItem = GetItemAtIndex(i, ModifyGameState);
		if (InvItem != none && InvItem.GetMyTemplateName() == ItemTemplateName)
		{
			return InvItem;
		}
	}

	return none;
}

//---------------------------------------------------------------------------------------
simulated function int GetNumItemInInventory(name ItemTemplateName)
{
	local XComGameStateHistory History;
	local XComGameState_Item ItemState;
	local int i, Count;

	History = `XCOMHISTORY;

	for (i = 0; i < Items.Length; ++i)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(Items[i].ObjectId));
		if (ItemState.GetMyTemplateName() == ItemTemplateName)
		{
			Count++;
		}
	}

	return Count;
}

//---------------------------------------------------------------------------------------
function bool BuildItemCommodity(StateObjectReference ItemRef, 
	out Commodity OutCommodity, 
	optional delegate<X2ItemTemplate.ValidationDelegate> Validator,
	optional XComGameState ModifyGameState)
{
	local XComGameState_Item Item;
	local X2ItemTemplate ItemTemplate;
	local Commodity EmptyCommodity;

	OutCommodity = EmptyCommodity;

	if (ItemRef.ObjectID <= 0)
	{
		return false;
	}

	if (ModifyGameState != none)
	{
		Item = XComGameState_Item(ModifyGameState.ModifyStateObject(class'XComGameState_Item', ItemRef.ObjectID));
	}
	else
	{
		Item = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ItemRef.ObjectID));
	}
	if (Item == none)
	{
		return false;
	}

	ItemTemplate = Item.GetMyTemplate();

	if (ItemTemplate.HideInInventory)
	{
		return false;
	}

	if (Validator != none)
	{
		if (!Validator(ItemTemplate))
		{
			return false;
		}
	}

	OutCommodity.ItemRef = ItemRef;
	OutCommodity.TemplateName = Item.GetMyTemplateName();
	OutCommodity.Title = ItemTemplate.GetItemFriendlyName();
	OutCommodity.Desc = ItemTemplate.GetItemBriefSummary();
	OutCommodity.Image = ItemTemplate.strImage;
	// No cost data for pre-existing items

	return true;
}

//---------------------------------------------------------------------------------------
simulated function ClearInventory()
{
	Items.Length = 0;
}

defaultproperties
{
}