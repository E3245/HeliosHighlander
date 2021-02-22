//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UISquadSelect_ListItem
//  AUTHOR:  Sam Batista -- 5/1/14
//  PURPOSE: Displays information pertaining to a single soldier in the Squad Select screen
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIDIOSquadSelect_ListItem extends UIPanel;

var int SlotIndex;

var localized string m_strChangeAgentLabel;
var localized string m_strChangeLoadoutLabel;
var localized string m_strPromote;
var localized string m_strEdit;
var localized string m_strDismiss;
var localized string m_strNeedsMediumArmor;
var localized string m_strNoUtilitySlots;
var localized string m_strIncreaseSquadSize;
var localized string m_strTiredTooltip;

var localized string m_strReinforcements;
var localized string m_strEquipmentTooltip;
var localized string m_strScarTooltipLabel;
var localized string m_strEmptyWeaponMod;
var localized string m_strEmptyArmorMod;
var localized string m_strEmptyBreachSlot;
var localized string m_strEmptyUtilitySlot;

var UIDIOStrategyMap_WorkerTray WorkerTray;

var UIDIOStrategyMap_WorkerSlot SquadSelectItem;


simulated function UIPanel InitPanel(optional name InitName, optional name InitLibID)
{
	super.InitPanel(InitName, InitLibID);

	SquadSelectItem = Spawn(class'UIDIOStrategyMap_WorkerSlot', self);
	SquadSelectItem.InitWorkerSlot('workerSlot', 0);
	SquadSelectItem.OnClickedDelegate = OnClickedChangeSelection;
	SquadSelectItem.SetPosition(230, -34);
	SquadSelectItem.SetPanelScale(1.28); 

	return self;
}

simulated function OnClickedChangeSelection(int Index)
{
	local XComGameState_Unit Unit;

	WorkerTray = `STRATPRES.DIOHUD.m_WorkerTray;
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(GetUnitRef().ObjectID));

	if (Unit.IsAndroid())
	{
		Screen.PlayNegativeMouseClickSound();
		return;
	}

	if (`SCREENSTACK.IsInStack(class'UIArmoryLandingArea'))
	{
		`STRATPRES.UIClearToStrategyHUD();
	}

	WorkerTray.CanWorkerBeAssignedDelegate = CanAssignUnitToSlot;
	
	WorkerTray.bShowHeader = false;
	WorkerTray.UpdateData(SquadSelectItem);
	WorkerTray.AttachToSquadSelectPanel(self, index);

	WorkerTray.SetVisible(true);
	
	WorkerTray.OnWorkerClickedDelegate = OnWorkerTrayItemClicked;
}

function bool CanAssignUnitToSlot(XComGameState_Unit Unit)
{
	local int findIndex;

	findIndex = `DIOHQ.APCRoster.Find('ObjectID', Unit.GetReference().ObjectID);

	return findIndex == -1;
}

function OnWorkerTrayItemClicked(UIDIOStrategyMap_WorkerSlot WorkerSlot, int WorkerObjectID)
{
	local StateObjectReference UnitRef;

	`log("Clicked on worker: " @ WorkerObjectID, , 'uixcom');
	if (WorkerObjectID <= 0)
	{
		return;
	}
	
	UnitRef.ObjectID = WorkerObjectID;
	UIDIOSquadSelect(Screen).SwapAssignedUnits(GetUnitRef(), UnitRef);
	WorkerTray.Hide();	
}
 
simulated function UpdateData(optional int Index = -1, optional bool bDisableEdit, optional bool bDisableDismiss, optional bool bDisableLoadout, optional array<EInventorySlot> CannotEditSlotsList)
{
	local array<XComGameState_Item> UtilityItems;
	local XComGameState_Unit Unit;
	local XComGameState_Item PrimaryWeapon, ArmorMod, BreachItem;
	local array<X2WeaponUpgradeTemplate> weaponMods;
	local X2WeaponTemplate PrimaryWeaponTemplate;
	local String NameStr;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local int i, k;
	local string EmptyTag, WeaponName, SlotLabel0, SlotLabel1, SlotLabel2, SlotLabel3, SlotLabel4, SlotLabel5, HiddenTag, SlotLabel6;
	//local XComGameState_Item Armor;

	// -------------------------------------------------------------------------------------------------------------
	SlotIndex = Index != -1 ? Index : SlotIndex;
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(GetUnitRef().ObjectID));

		
	UtilityItems = class'UIUtilities_Strategy'.static.GetEquippedItemsInSlot(Unit, eInvSlot_Utility);
	BreachItem = Unit.GetItemInSlot(eInvSlot_Breach);
	ArmorMod = Unit.GetItemInSlot(eInvSlot_ArmorMod);
	//Armor = Unit.GetItemInSlot(eInvSlot_Armor);

	PrimaryWeapon = Unit.GetItemInSlot(eInvSlot_PrimaryWeapon);
	if (PrimaryWeapon != none)
	{
		PrimaryWeaponTemplate = X2WeaponTemplate(PrimaryWeapon.GetMyTemplate());
		WeaponName = `DIO_UI.static.GetUnitWeaponFriendlyNameNoStats(PrimaryWeapon);
		//scarsTooltip $= WeaponName $ "\n";
	
		weaponMods = PrimaryWeapon.GetMyWeaponUpgradeTemplates();
	}
	

	NameStr = `MAKECAPS(Unit.GetNickName(true));
	SoldierClassTemplate = Unit.GetSoldierClassTemplate();

	if (Unit.IsAndroid())
	{
		MC.BeginFunctionOp("ActivateAndroidHighlights");
		MC.QueueString(m_strReinforcements);
		MC.QueueBoolean(true);
		MC.EndOp();
	}

	SquadSelectItem.SetObjectID(GetUnitRef().ObjectID);

	// -------------------------------
	// Build labels 
	EmptyTag = "EMPTY_SLOT_MC"; 
	HiddenTag = "INTENTIONALLY_HIDE";
	
	// WEAPON MODS  -----
	k = 0;
	SlotLabel0 = HiddenTag;
	SlotLabel1 = SlotLabel0;
	if ((`DIOHQ.HasCompletedResearchByName('DioResearch_ModularWeapons') || `CheatStart))
	{
		for (i = 0; i < PrimaryWeaponTemplate.NumUpgradeSlots; ++i)
		{
			while (weaponMods.length > k && weaponMods[k].Universal)
			{
				k++;
			}


			if (SlotLabel0 == HiddenTag && weaponMods[k] != none)
			{
				SlotLabel0 = weaponMods[k].strImage;
				if (SlotLabel0 == "") SlotLabel0 = EmptyTag;
			}
			else if (SlotLabel1 == HiddenTag && weaponMods[k] != none)
			{
				SlotLabel1 = weaponMods[k].strImage;
				if (SlotLabel1 == "") SlotLabel1 = EmptyTag;
			}

			k++;
		}

		if (PrimaryWeaponTemplate.NumUpgradeSlots > 0 && SlotLabel0 == HiddenTag)
		{
			SlotLabel0 = EmptyTag;
		}

		if (PrimaryWeaponTemplate.NumUpgradeSlots > 1 && SlotLabel1 == HiddenTag)
		{
			SlotLabel1 = EmptyTag;
		}
	}

	// ARMOR MOD ----- 
	SlotLabel2 = `DIOHQ.HasCompletedResearchByName('DioResearch_ModularArmor') ? EmptyTag : HiddenTag;
	if( ArmorMod != none )
	{
		SlotLabel2 = ArmorMod.GetMyTemplate().strImage;
		if( SlotLabel2 == "" ) SlotLabel2 = EmptyTag;
	}
	
	// UTILITY ITEMS ----- 
	SlotLabel3 = HiddenTag;
	SlotLabel4 = EmptyTag; //Available at the start of the game. 
	if(Unit.GetCurrentStat(eStat_UtilityItems) > 0 )
	{
		SlotLabel4 = UtilityItems[0].GetMyTemplate().strImage;
		if( SlotLabel4 == "" ) SlotLabel4 = EmptyTag; 

		if(Unit.GetCurrentStat(eStat_UtilityItems) > 1 )
		{
			SlotLabel3 = UtilityItems[1].GetMyTemplate().strImage;
			if( SlotLabel3 == "" ) SlotLabel3 = EmptyTag;
		}
	}

	SlotLabel6 = HiddenTag;
	if (Unit.GetCurrentStat(eStat_UtilityItems) > 2)
	{
		SlotLabel6 = UtilityItems[2].GetMyTemplate().strImage;
		if (SlotLabel6 == "") SlotLabel6 = EmptyTag;

		MC.BeginFunctionOp("ActivateExtraUtilitySlot");
		MC.QueueString(SlotLabel6);
		MC.EndOp();
	}
	else
	{
		MC.FunctionVoid("DeactivateExtraUtilitySlot");
	}

	// BREACH ITEM -----
	SlotLabel5 = EmptyTag;  //Always available 
	if( BreachItem != none )
	{
		SlotLabel5 = BreachItem.GetMyTemplate().strImage;
		if( SlotLabel5 == "" ) SlotLabel5 = EmptyTag;
	}
	// -------------

	AS_SetFilled( NameStr, SoldierClassTemplate.WorkerIconImage, 
				 WeaponName,
				 PrimaryWeaponTemplate.strImage, 
				 PrimaryWeaponTemplate.bIsEpic,
				 SlotLabel0,
				 SlotLabel1,
				 SlotLabel2, 
				 SlotLabel3, 
				 SlotLabel4,
				 SlotLabel5,
				 class'UIUtilities_Strategy'.static.GetUnitMaxHealth(Unit), 
				 class'UIUtilities_Strategy'.static.GetUnitCurrentHealth(Unit), 
				 Unit.GetCurrentStat(eStat_ArmorMitigation), Unit.Scars.Length);
		
	AS_SetUnitHealth(class'UIUtilities_Strategy'.static.GetUnitCurrentHealth(Unit), class'UIUtilities_Strategy'.static.GetUnitMaxHealth(Unit));
}

simulated function AnimateIn(optional float AnimationIndex = -1.0)
{
	MC.FunctionNum("animateIn", AnimationIndex);
}

function StateObjectReference GetUnitRef()
{
	local XComGameState_HeadquartersDio DioHQ;

	DioHQ = `DIOHQ;

	if (SlotIndex >= DioHQ.APCRoster.Length)
		return DioHQ.Androids[SlotIndex - DioHQ.APCRoster.Length];
	else
		return DioHQ.APCRoster[SlotIndex];
}

simulated function GoToLoadoutScreen()
{
	local UIArmory_CompactLoadout ArmoryScreen;
	local array<SequenceObject> DIOArmoryEvents;
	local X2StrategyGameRuleset StratRules;

	// Validate agent equipment any time player enters Armory
	StratRules = `STRATEGYRULES;
	StratRules.SubmitValidateAgentEquipment();

	Screen.PlayMouseClickSound();

	class'Engine'.static.GetCurrentWorldInfo().GetGameSequence().FindSeqObjectsByClass(class'SeqEvent_DIOArmoryCameraZoom', true, DIOArmoryEvents);

	// HELIOS BEGIN
	// Move the refresh camera function to presentation base
	`PRESBASE.RefreshCamera(name("APC_0" $(SlotIndex + 1)));
	// HELIOS END

	if (Movie.Stack.IsNotInStack(class'UIArmory_CompactLoadout'))
	{
		ArmoryScreen = UIArmory_CompactLoadout(Movie.Stack.Push(Spawn(class'UIArmory_CompactLoadout', self)));
		ArmoryScreen.bComingFromSquadSelect = true;
		ArmoryScreen.InitArmory(GetUnitRef());
	}
}

function UpdateNavHelp()
{
	local UIDIOHUD HUD;

	if (`ISCONTROLLERACTIVE)
	{
		// HELIOS BEGIN
		// Replace the hard reference with a reference to the main HUD	
		HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
		// HELIOS END		

		if (WorkerTray != none && WorkerTray.bIsVisible)
		{
			HUD.NavHelp.ClearButtonHelp();
			HUD.NavHelp.bIsVerticalHelp = true;
			HUD.NavHelp.AddBackButton();
			HUD.NavHelp.AddSelectNavHelp();
		}
		else
		{
			HUD.NavHelp.AddLeftHelp(m_strChangeAgentLabel, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
			HUD.NavHelp.AddLeftHelp(m_strChangeLoadoutLabel, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_A_X);
		}
	}
}

simulated function OnMouseEvent(int Cmd, array<string> Args)
{
	local String tooltipStr, mouseoverObject;

	local array<XComGameState_Item> UtilityItems;
	local XComGameState_Unit Unit;
	local XComGameState_Item PrimaryWeapon, ArmorMod, BreachItem;
	local array<X2WeaponUpgradeTemplate> weaponMods;
	local X2WeaponTemplate PrimaryWeaponTemplate;
	//local XComGameState_UnitScar Scar;
	local int k;
	
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(GetUnitRef().ObjectID));

	super.OnMouseEvent(Cmd, Args);

	if (Cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_UP)
	{
		GoToLoadoutScreen();
	}

	if (Cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_IN)
	{
		mouseoverObject = Args[Args.Length - 1];

		UtilityItems = class'UIUtilities_Strategy'.static.GetEquippedItemsInSlot(Unit, eInvSlot_Utility);
		
		PrimaryWeapon = Unit.GetItemInSlot(eInvSlot_PrimaryWeapon);
		PrimaryWeaponTemplate = X2WeaponTemplate(PrimaryWeapon.GetMyTemplate());
		
		if (mouseoverObject == "primaryWeaponImageControl" && PrimaryWeapon != none)
		{
			tooltipStr = PrimaryWeaponTemplate.GetItemFriendlyName() @ "\n" @ PrimaryWeaponTemplate.GetItemTacticalText();
		} 
		else if (mouseoverObject == "weaponMod1" || mouseoverObject == "weaponMod2")
		{
			weaponMods = PrimaryWeapon.GetMyWeaponUpgradeTemplates();

			k = 0;
			while (weaponMods.length > k && weaponMods[k].Universal)
			{
				k++;
			}

			// need to find next available weapon mod
			if (mouseoverObject == "weaponMod2")
			{
				k++;
				while (weaponMods.length > k && weaponMods[k].Universal)
				{
					k++;
				}
			}

			if (k < weaponMods.length && weaponMods[k] != none)
			{
				tooltipStr = weaponMods[k].GetItemFriendlyName() @ "\n" @ weaponMods[k].GetItemTacticalText();
			}
		}
		else if (mouseoverObject == "armorMod")
		{
			ArmorMod = Unit.GetItemInSlot(eInvSlot_ArmorMod);
			tooltipStr = ArmorMod.GetMyTemplate().GetItemFriendlyName() @ "\n" @ ArmorMod.GetMyTemplate().GetItemTacticalText();
		}
		else if (mouseoverObject == "breachItem")
		{
			BreachItem = Unit.GetItemInSlot(eInvSlot_Breach);
			tooltipStr = BreachItem.GetMyTemplate().GetItemFriendlyName() @ "\n" @ BreachItem.GetMyTemplate().GetItemTacticalText();
		}
		else if (mouseoverObject == "utilItem1")
		{
			tooltipStr = UtilityItems[1].GetMyTemplate().GetItemFriendlyName() @ "\n" @ UtilityItems[1].GetMyTemplate().GetItemTacticalText();
		}
		else if (mouseoverObject == "utilItem2")
		{
			tooltipStr = UtilityItems[0].GetMyTemplate().GetItemFriendlyName() @ "\n" @ UtilityItems[0].GetMyTemplate().GetItemTacticalText();
		}
		else if (mouseoverObject == "utilItem3")
		{
			tooltipStr = UtilityItems[2].GetMyTemplate().GetItemFriendlyName() @ "\n" @ UtilityItems[2].GetMyTemplate().GetItemTacticalText();
		}

		SetTooltipText(tooltipStr);
		Movie.Pres.m_kTooltipMgr.ActivateTooltip(Movie.Pres.m_kTooltipMgr.GetTooltipByID(CachedTooltipId));
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if ((cmd == class'UIUtilities_Input'.const.FXS_KEY_ENTER ||
		cmd == class'UIUtilities_Input'.const.FXS_BUTTON_A ||
		cmd == class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR) )
	{
		if (WorkerTray != none && WorkerTray.bIsVisible)
		{
			return WorkerTray.OnUnrealCommand(cmd, arg);
		}

		GoToLoadoutScreen();
		return true;
	}

	if (cmd == class'UIUtilities_Input'.const.FXS_BUTTON_Y )
	{
		OnClickedChangeSelection(0);
		return true;
	}

	return false;
}


simulated function AS_SetFilled(string firstName, string headIcon, string primaryWeaponLabel,
	string primaryWeaponImage, bool isLegendary, string weaponMod1, string weaponMod2,
	string armorMod, string utilItem1, string utilItem2, string breachIcon,
	int maxHealth, int currentHealth, int armorPips, int numScars)
{
	mc.BeginFunctionOp("setFilledSlot");
	mc.QueueString(firstName);
	mc.QueueString(""/*headIcon*/);
	mc.QueueString(primaryWeaponLabel);
	mc.QueueString(primaryWeaponImage);
	mc.QueueBoolean(isLegendary);
	mc.QueueString(weaponMod1);
	mc.QueueString(weaponMod2);
	mc.QueueString(armorMod);
	mc.QueueString(utilItem1);
	mc.QueueString(utilItem2);
	mc.QueueString(breachIcon);
	mc.QueueNumber(maxHealth);
	mc.QueueNumber(currentHealth);
	mc.QueueNumber(armorPips);
	mc.QueueNumber(numScars);
	mc.EndOp();
}



simulated function AS_SetUnitHealth(int CurrentHP, int MaxHP)
{
	mc.BeginFunctionOp("setUnitHealth");
	mc.QueueNumber(CurrentHP);
	mc.QueueNumber(MaxHP);
	mc.EndOp();
}


// Don't propagate focus changes to children
simulated function OnReceiveFocus()
{
	if (!bIsFocused)
	{
		MC.FunctionVoid("onReceiveFocus");
		bIsFocused = true;
		
		if (`STRATPRES.DIOHUD.m_WorkerTray.bIsVisible)
		{
			`STRATPRES.DIOHUD.m_WorkerTray.Hide();
		}
	}
}

simulated function OnLoseFocus()
{
	if (bIsFocused)
	{
		MC.FunctionVoid("onLoseFocus");
		bIsFocused = false;
	}
}

defaultproperties
{
	LibID = "DioSquadSelectListItem";
	width = 304;
	bIsNavigable = true;
	bCascadeFocus = false;
}
//------------------------------------------------------