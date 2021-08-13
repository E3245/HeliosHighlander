//  FILE:    SeqAct_PutItemInGameObject.uc
//  AUTHOR:  David Burchanowski  --  11/06/2016
//  PURPOSE: Action to add loot from either 
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class SeqAct_PutItemInGameObject extends SequenceAction;

var protected XComGameState_InteractiveObject InteractiveObject;
var() protected string ItemTemplate;
var() protected string LootTable;

event Activated()
{
	local XComGameState NewGameState;
	local name LootTableName;
	local array<name> RolledLoot;
	local name RolledTemplate;

	if(InteractiveObject == none)
	{
		`PARCELMGR.ParcelGenerationAssert(false, "SeqAct_PutItemInGameObject: InteractiveObject is none! Bailing out... ");
		return;
	}

	if(ItemTemplate == "" && LootTable == "")
	{
		`PARCELMGR.ParcelGenerationAssert(false, "SeqAct_PutItemInGameObject: No ItemTemplate or LootTable was specified!");
		return;
	}

	// create a new game state
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SeqAct_PutItemInGameObject");
	
	// create a new version of the interactive object to hold the modified loot
	InteractiveObject = XComGameState_InteractiveObject(NewGameState.ModifyStateObject(class'XComGameState_InteractiveObject', InteractiveObject.ObjectID));

	// add any explicitly defined loot
	if(ItemTemplate != "")
	{
		AddLootItem(NewGameState, ItemTemplate);
	}

	// add any loot from the specified loot table
	if(LootTable != "")
	{
		LootTableName= name(LootTable);
		class'X2LootTableManager'.static.GetLootTableManager().RollForLootTable(LootTableName, RolledLoot);
		foreach RolledLoot(RolledTemplate)
		{
			AddLootItem(NewGameState, RolledTemplate);
		}
	}

	// and submit
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

protected function AddLootItem(XComGameState NewGameState, coerce name Template)
{
	local X2ItemTemplateManager ItemMgr;
	local X2ItemTemplate Item;
	local XComGameState_Item ItemState;
    
	// HELIOS Issue #61 Variables
    local StateObjectReference  ItemRef;

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	Item = ItemMgr.FindItemTemplate(Template);
	if(Item == none)
	{
		`PARCELMGR.ParcelGenerationAssert(false, "SeqAct_PutItemInGameObject:AddLootItem() Item template " $ string(Template) $ " not found. Using fallback RecoverObject instead.");
		
		Item = ItemMgr.FindItemTemplate(class'X2StrategyElement_DioRewards'.default.DefaultLootItemName);
		if (Item == none)
		{
			`PARCELMGR.ParcelGenerationAssert(false, "SeqAct_PutItemInGameObject:AddLootItem() No fallback Item template found.");
			return;
		}
	}

	// create a new instance of the item template and add it to the object
	ItemState = Item.CreateInstanceFromTemplate(NewGameState);

    // Begin HELIOS Issue #61
    // If we have an item bundle, iterate through each item reference and add it to the interactive object's loot table. Most DIO missions will not be using the loot table API, and Sub-Objectives only support item templates.
	// Unfortunately, the contained items must be built when CreateInstanceFromTemplate() is called. Of course, we could put an event listener in the XCGS_BaseObject's `event OnCreation()` but I'm pretty sure that would cause significant side-effects.
	// So a new child X2ItemTemplate is necessary if anyone is planning on adding bundled items for interactive quest items, which is an acceptable alternative (suggestions are welcomed).
    if (ItemState.ContainedItems.Length > 0)
    {
        foreach ItemState.ContainedItems(ItemRef)
        {
	        // add the loot
	        InteractiveObject.AddLoot(ItemRef, NewGameState);
        }

		// Erase the lingering item since it's not added to the interactive object and it's not yet added to history
		NewGameState.PurgeGameStateForObjectID(ItemState.ObjectID);
    }
    else
    {
	    // add the loot
	    InteractiveObject.AddLoot(ItemState.GetReference(), NewGameState);
    }
    // End HELIOS Issue #61
}

defaultproperties
{
	ObjName="Put Items In Game Object"
	ObjCategory="Procedural Missions"
	bCallHandler=false
	bAutoActivateOutputLinks=true

	bConvertedForReplaySystem=true
	bCanBeUsedForGameplaySequence=true

	VariableLinks.Empty;
	VariableLinks(0)=(ExpectedType=class'SeqVar_InteractiveObject', LinkDesc="Interactive Object", PropertyName=InteractiveObject, bWriteable=true)
	VariableLinks(1)=(ExpectedType=class'SeqVar_String', LinkDesc="Item Template", PropertyName=ItemTemplate)
	VariableLinks(2)=(ExpectedType=class'SeqVar_String', LinkDesc="Loot Table", PropertyName=LootTable)
}